-- Client cosmetic transforms only. One final transform per part per animation tick.
local Batch={};Batch.__index=Batch
function Batch.new(root)
 return setmetatable({Root=root,Parts={},Frames={},Index={},Requested=0},Batch)
end
function Batch:Set(part,frame)
 if not part.Parent then return end
 self.Requested+=1
 local index=self.Index[part]
 if index then self.Frames[index]=frame else
  index=#self.Parts+1;self.Index[part]=index;self.Parts[index]=part;self.Frames[index]=frame
 end
end
function Batch:Get(part)
 local index=self.Index[part];return index and self.Frames[index]or part.CFrame
end
function Batch:Flush()
 local count=#self.Parts;local requested=self.Requested
 -- Tiny sets avoid bulk-call overhead. These are uncollidable local visual parts.
 if count>=32 then self.Root:BulkMoveTo(self.Parts,self.Frames,Enum.BulkMoveMode.FireCFrameChanged)
 else for i,part in ipairs(self.Parts)do part.CFrame=self.Frames[i]end end
 table.clear(self.Parts);table.clear(self.Frames);table.clear(self.Index);self.Requested=0
 return count,requested
end
-- R149: `skip` (optional, a set of parts) leaves out the parts another system poses (a growing plant's parts, which PlantGrowth.Place moves).
function Batch.Capture(model,origin,skip)
 local parts={}
 for _,part in ipairs(model:GetDescendants())do
  if part:IsA('BasePart')and part.Name~='Effect anchor'and not(skip and skip[part])and not part:FindFirstAncestor('ApprovedFruitEffects')then
   table.insert(parts,{Part=part,Frame=origin:ToObjectSpace(part.CFrame)})
  end
 end
 return parts
end
function Batch:Pose(parts,origin,fillOnly)
 for _,p in ipairs(parts)do
  if not fillOnly or not self.Index[p.Part]then self:Set(p.Part,origin*p.Frame)end
 end
end
return Batch
