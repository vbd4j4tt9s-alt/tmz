-- R53: choose the visible fruit nearest the pointer, using its live animated parts.
local Cache=require(script.Parent.PlantPartCache)
local Target={};Target.__index=Target
local function visible(part)
 return part.Transparency<.95 and part.LocalTransparencyModifier<.95 and part.Name~='Effect anchor'
  and not part:FindFirstAncestor('ApprovedFruitEffects')and not part:FindFirstAncestor('PlantRarityEffects')
end
function Target.Score(camera,pointer,frame,size)
 local center=camera:WorldToViewportPoint(frame.Position)
 if center.Z<=0 then return math.huge end
 local loX,loY,hiX,hiY=center.X,center.Y,center.X,center.Y
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
  local p=camera:WorldToViewportPoint(frame:PointToWorldSpace(Vector3.new(size.X*x,size.Y*y,size.Z*z)*.5))
  if p.Z>0 then loX=math.min(loX,p.X);loY=math.min(loY,p.Y);hiX=math.max(hiX,p.X);hiY=math.max(hiY,p.Y)end
 end end end
 local view=camera.ViewportSize
 if hiX<0 or hiY<0 or loX>view.X or loY>view.Y then return math.huge end
 local dx=math.max(loX-pointer.X,0,pointer.X-hiX);local dy=math.max(loY-pointer.Y,0,pointer.Y-hiY)
 local gap=math.sqrt(dx*dx+dy*dy)
 if gap>85 then return math.huge end
 return gap+math.min(10000,(Vector2.new(center.X,center.Y)-pointer).Magnitude)*.001
end
function Target.new()return setmetatable({Caches={}},Target)end
function Target:Clear()for _,c in pairs(self.Caches)do c:Destroy()end;table.clear(self.Caches)end
function Target:Pick(model,camera,pointer,rootPosition,ownerId)
 local prompts=model and model:FindFirstChild('FruitPrompts');if not prompts then self:Clear();return nil end
 local art=model:FindFirstChild('LocalPlantArt');local chosen,part,best=nil,nil,math.huge;local live={}
 for _,group in ipairs(prompts:GetChildren())do
  local prompt=group:FindFirstChild('HarvestPrompt',true);local anchor=prompt and prompt.Parent
  if prompt and prompt:GetAttribute('GardenOwnerId')==ownerId and prompt:GetAttribute('GardenStage')==4
   and prompt:GetAttribute('GardenCropId')==model:GetAttribute('CropId')and(rootPosition-anchor.Position).Magnitude<=prompt.MaxActivationDistance then
   local subject=art and art:FindFirstChild(group.Name)or group
   live[subject]=true;local cache=self.Caches[subject]
   if not cache or cache.Dead then cache=Cache.new(subject);self.Caches[subject]=cache end
   local any=false
   for _,p in ipairs(cache:List())do if visible(p)then
    any=true;local score=Target.Score(camera,pointer,p.CFrame,p.Size)
    if score<best then best=score;chosen=prompt;part=p end
   end end
   if not any then local score=Target.Score(camera,pointer,anchor.CFrame,Vector3.new(.4,.4,.4));if score<best then best=score;chosen=prompt;part=nil end end
  end
 end
 for subject,cache in pairs(self.Caches)do if not live[subject]then cache:Destroy();self.Caches[subject]=nil end end
 return chosen,part
end
Target.Destroy=Target.Clear
return Target
