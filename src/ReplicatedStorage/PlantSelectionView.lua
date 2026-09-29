-- Two reusable highlights: a whole-plant outline plus a nearby visible surface.
-- A giant model's outer silhouette can be offscreen when the camera is inside its canopy.
local Cache=require(game:GetService('ReplicatedStorage'):WaitForChild('PlantPartCache'))
local S={};S.__index=S
local function visible(p)
 return p and p.Parent and p:IsA('BasePart')and p.Transparency<.95 and p.LocalTransparencyModifier<.95
  and not p:FindFirstAncestor('PlantRarityEffects')and not p:FindFirstAncestor('ApprovedFruitEffects')
end
local function distance(p,position)
 local q=p.CFrame:PointToObjectSpace(position);local h=p.Size*.5
 local nearest=p.CFrame:PointToWorldSpace(Vector3.new(math.clamp(q.X,-h.X,h.X),math.clamp(q.Y,-h.Y,h.Y),math.clamp(q.Z,-h.Z,h.Z)))
 return (position-nearest).Magnitude,nearest
end
function S.new(name,color,fill,outline)
 local self=setmetatable({},S)
 for _,key in ipairs({'Whole','Focus'})do
  local h=Instance.new('Highlight');h.Name=name..(key=='Focus'and'Surface'or'');h.FillColor=color;h.OutlineColor=color
  h.FillTransparency=key=='Whole'and fill or math.max(.65,fill-.12);h.OutlineTransparency=outline
  h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;h.Enabled=false;h.Parent=workspace;self[key]=h
 end
 return self
end
function S:Clear()
 if self.Cache then self.Cache:Destroy();self.Cache=nil end
 for _,key in ipairs({'Whole','Focus'})do self[key].Enabled=false;self[key].Adornee=nil end
 if self.Aura and self.Aura.Parent then self.Aura.Enabled=true end;self.Aura=nil;self.Model=nil;self.Part=nil
end
function S:Set(model,preferred,camera)
 if self.Model~=model then self:Clear();self.Model=model end
 if not model or not model.Parent then self:Clear();return end
 local art=model:FindFirstChild('LocalPlantArt');local subject=art or model
 if not self.Cache or self.Cache.Dead or self.Cache.Root~=subject then if self.Cache then self.Cache:Destroy()end;self.Cache=Cache.new(subject)end
 if self.Whole.Adornee~=subject then self.Whole.Adornee=subject end;if not self.Whole.Enabled then self.Whole.Enabled=true end
 local effects=model:FindFirstChild('PlantRarityEffects');local aura=effects and effects:FindFirstChild('Rarity aura')
 if aura then aura.Enabled=false;self.Aura=aura end
 local point=camera and camera.CFrame.Position or model:GetPivot().Position
 local best,near=nil,math.huge
 -- At close range prefer a surface actually in the view, including the clicked fruit.
 for _,p in ipairs(self.Cache:List())do if visible(p)then
  local gap,surface=distance(p,point)
  local on=gap<29;if on and camera then
   local projected,inside=camera:WorldToViewportPoint(surface);on=inside and projected.Z>0
  end
  if on or gap<=3 then
   local score=gap-(p==preferred and 1 or 0)
   if score<near then best=p;near=score end
  end
 end end
 self.Part=best;if self.Focus.Adornee~=best then self.Focus.Adornee=best end;local enabled=best~=nil and near<28;if self.Focus.Enabled~=enabled then self.Focus.Enabled=enabled end
end
function S:Destroy()self:Clear();self.Whole:Destroy();self.Focus:Destroy()end
return S
