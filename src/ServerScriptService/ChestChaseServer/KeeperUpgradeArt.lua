-- R38: local native parts; no external mesh or model imports.
local Data=require(game:GetService('ReplicatedStorage'):WaitForChild('KeeperUpgradeData'))
local Art={}
-- R113: surface finish by part name (material, optional colour/reflectance/transparency). Geometry,
-- sizes, rest frames and groups are unchanged, so the server's contact shapes are identical.
local function rgb(r,g,b)return {r/255,g/255,b/255}end
Art.Finish={
 [1]={['Root torso']={'Wood'},['Bark ridge']={'Wood'},['Split bark plate']={'Wood'},['Heavy shoulder']={'Wood'},['Heavy forearm']={'Wood'},
  ['Root leg']={'Wood'},['Root foot']={'Wood'},['Root toe']={'Wood'},['Stump head']={'Wood'},['Heavy brow']={'Wood'},['Jaw']={'Wood'},
  ['Broken crown']={'Wood'},['Shoulder bough']={'Wood'},['Crown branch']={'Wood'},['Crown fork']={'Wood'},['Root knuckle']={'Wood'},
  ['Moss shoulders']={'Grass',rgb(82,140,62)},['Moss plate']={'Grass',rgb(82,140,62)},['Oak shoulder tier']={'LeafyGrass'},
  ['Oak Leaf crown']={'LeafyGrass'},['Oak Leaf base']={'LeafyGrass'},['Oak High leaves']={'LeafyGrass'},['Oak Side leaves']={'LeafyGrass'},['Oak Leaf slope']={'LeafyGrass'}},
 [5]={['Shoulder crystal']={'Glass',nil,.05,.12},['Crest']={'Glass',nil,.05,.12},['Knee plate']={'Glass',nil,.05,.12},
  ['Chest inset']={'Neon',rgb(186,140,242)},['Silver blade']={'Metal',nil,.18},['Chest plate']={'Metal',nil,.08},['Helm brow']={'Metal',nil,.08}},
 [7]={['Thunder prong']={'Metal',rgb(150,160,182),.12},['Face shadow']={'Slate'},['Heavy foot']={'Basalt'},['Heavy fist']={'Basalt'}},
}
function Art.ApplyFinish(part,stage)
 local finish=Art.Finish[stage]and Art.Finish[stage][part.Name];if not finish then return end
 part.Material=Enum.Material[finish[1]]
 if finish[2]then part.Color=Color3.new(table.unpack(finish[2]))end
 if finish[3]then part.Reflectance=finish[3]end
 if finish[4]then part.Transparency=finish[4]end
end
-- Keepers saved already dressed in the place keep their rig; refinish them in place (idempotent).
function Art.Refinish(rig,stage)
 if not Art.Finish[stage]then return end
 for _,part in ipairs(rig:GetDescendants())do if part:IsA('BasePart')then Art.ApplyFinish(part,stage)end end
end
function Art.Build(stage)
 local data=Data[stage];if not data then return nil end
 local rig=Instance.new('Model');rig.Name='BeastBody';rig:SetAttribute('VisualVersion',59)
 for _,s in ipairs(data.Parts)do
  local p=Instance.new(s.Shape=='Wedge'and 'WedgePart'or s.Shape=='Corner'and 'CornerWedgePart'or 'Part')
  p.Name=s.Name;p.Size=Vector3.new(table.unpack(s.Size));p.CFrame=CFrame.new(table.unpack(s.Rest))
  if s.Shape=='CylinderX'then p.Shape=Enum.PartType.Cylinder elseif s.Shape=='Ellipsoid'then p.Shape=Enum.PartType.Ball end
  p.Color=Color3.new(table.unpack(s.Color));p.Material=Enum.Material[s.Material];Art.ApplyFinish(p,stage)
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=s.Material~='Neon'
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p:SetAttribute('RestCFrame',p.CFrame);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow)
  if s.TreeRest then p:SetAttribute('TreeRestCFrame',CFrame.new(table.unpack(s.TreeRest)));p:SetAttribute('TreeRestSize',Vector3.new(table.unpack(s.TreeSize)))end
  if s.IdleRest then p:SetAttribute('IdleRestCFrame',CFrame.new(table.unpack(s.IdleRest)));p:SetAttribute('IdleRestSize',Vector3.new(table.unpack(s.IdleSize)))end
  p.Parent=rig
 end
 return rig
end
return Art
