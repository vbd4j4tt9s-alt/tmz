-- Rebuild a part list only after structural changes. Animated CFrames and sizes are read live.
local C={};C.__index=C
function C.new(root,accept)
 local self=setmetatable({Root=root,Accept=accept,Dirty=true,Parts={},Connections={},Scans=0},C)
 local function dirty()self.Dirty=true end
 self.Connections[1]=root.DescendantAdded:Connect(dirty)
 self.Connections[2]=root.DescendantRemoving:Connect(dirty)
 self.Connections[3]=root.Destroying:Connect(function()self:Destroy()end)
 return self
end
function C:List()
 if self.Dead then return self.Parts end
 if self.Dirty then
  self.Dirty=false;self.Scans+=1;table.clear(self.Parts)
  for _,p in ipairs(self.Root:GetDescendants())do if p:IsA('BasePart')and(not self.Accept or self.Accept(p))then table.insert(self.Parts,p)end end
 end
 return self.Parts
end
function C:Destroy()
 if self.Dead then return end;self.Dead=true
 for _,c in ipairs(self.Connections)do c:Disconnect()end;table.clear(self.Connections);table.clear(self.Parts);self.Root=nil
end
return C
