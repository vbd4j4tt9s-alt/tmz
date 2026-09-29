-- R38: local native parts; no external mesh or model imports.
local Data=require(game:GetService('ReplicatedStorage'):WaitForChild('KeeperUpgradeData'))
local Art={}
function Art.Build(stage)
 local data=Data[stage];if not data then return nil end
 local rig=Instance.new('Model');rig.Name='BeastBody';rig:SetAttribute('VisualVersion',59)
 for _,s in ipairs(data.Parts)do
  local p=Instance.new(s.Shape=='Wedge'and 'WedgePart'or s.Shape=='Corner'and 'CornerWedgePart'or 'Part')
  p.Name=s.Name;p.Size=Vector3.new(table.unpack(s.Size));p.CFrame=CFrame.new(table.unpack(s.Rest))
  if s.Shape=='CylinderX'then p.Shape=Enum.PartType.Cylinder elseif s.Shape=='Ellipsoid'then p.Shape=Enum.PartType.Ball end
  p.Color=Color3.new(table.unpack(s.Color));p.Material=Enum.Material[s.Material]
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
