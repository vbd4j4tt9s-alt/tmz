-- R52. A keeper can commit its strike only while visible body geometry overlaps
-- a real character body part. Accessories, tools and invisible roots cannot hit.
local Contact={}
local RS=game:GetService('ReplicatedStorage');local Strike=require(RS:WaitForChild('KeeperStrikeFrames'));local PartPose=require(RS:WaitForChild('KeeperUpgradePose'))
local bodies={Head=true,Torso=true,UpperTorso=true,LowerTorso=true,
 ['Left Arm']=true,['Right Arm']=true,['Left Leg']=true,['Right Leg']=true,
 LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,RightUpperArm=true,RightLowerArm=true,RightHand=true,
 LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,RightUpperLeg=true,RightLowerLeg=true,RightFoot=true}
local cache=setmetatable({},{__mode='k'})
function Contact.Parts(keeper)
 local parts=cache[keeper];if parts then return parts end
 parts={};for _,part in ipairs(keeper:GetDescendants())do
  if part:IsA('BasePart')and part~=keeper.PrimaryPart and part.Transparency<.95 and part.Size.Magnitude>.15 and not part:GetAttribute('VeiledCosmetic')and not part:FindFirstAncestor('ColossusSurges')then table.insert(parts,part)end
 end
 cache[keeper]=parts;return parts
end
function Contact.Touching(keeper,character)
 local root=character and character:FindFirstChild('HumanoidRootPart')
 if not keeper or not keeper.Parent or not root then return false end
 local special=keeper:GetAttribute('VeiledKeeper81')
 local virtual=special and require(RS.VeiledKeeper81).Frames(keeper,workspace:GetServerTimeNow())or nil
 local params=OverlapParams.new();params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={character};params.RespectCanCollide=false;params.MaxParts=0
 local stage=keeper:GetAttribute('CreatureStage')or keeper:GetAttribute('Stage')
 local frame=keeper.PrimaryPart and keeper.PrimaryPart.CFrame
 local targets=not special and stage and Strike.Frames(stage,workspace:GetServerTimeNow(),keeper:GetAttribute('KeeperAttackAt'))
 if not special and frame and targets then
  for _,part in ipairs(Contact.Parts(keeper))do
   local rest=part:GetAttribute('RestCFrame');local group=part:GetAttribute('BeastGroup')
   if part.Parent and rest and targets[group]then part.CFrame=frame*targets[group]*rest end
  end
 end
 local radius=0
 for _,body in ipairs(character:GetChildren())do
  if body:IsA('BasePart')and bodies[body.Name]then radius=math.max(radius,(body.Position-root.Position).Magnitude+body.Size.Magnitude*.5)end
 end
 for _,part in ipairs(Contact.Parts(keeper))do
  if not part.Parent or part.Transparency>=.95 then continue end
  -- Cheap rejection avoids full geometry queries for distant limbs/ornaments.
  local group=virtual and part:GetAttribute('VeiledGroup')
  local at=group and virtual[group]*part:GetAttribute('VeiledFrame')or part.CFrame
  local p=at:PointToObjectSpace(root.Position);local h=part.Size*.5
  local outside=Vector3.new(math.max(0,math.abs(p.X)-h.X),math.max(0,math.abs(p.Y)-h.Y),math.max(0,math.abs(p.Z)-h.Z))
  if outside.Magnitude>radius then continue end
  local overlaps=virtual and workspace:GetPartBoundsInBox(at,part.Size,params)or workspace:GetPartsInPart(part,params)
  for _,hit in ipairs(overlaps)do
   if hit.Parent==character and bodies[hit.Name]and hit.Transparency<.95 then return true end
  end
 end
 return false
end
return Contact
