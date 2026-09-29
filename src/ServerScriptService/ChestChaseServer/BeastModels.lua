-- R38: approved native replacements for Forest, Crystal and Storm; other templates retained.
local Storage=game:GetService('ServerStorage')
local Config=require(game:GetService('ReplicatedStorage').KeeperRigConfig)
local Upgrades=require(script.Parent.KeeperUpgradeArt)
local function version(stage)return (stage==1 or stage==5 or stage==7)and 59 or 99 end
local Art={Version=139}

function Art.Build(stage)
 local replacement=Upgrades.Build(stage);if replacement then return replacement end
 local templates=assert(Storage:FindFirstChild('KeeperTemplatesV100'),'Install V100 keeper templates first')
 local template=assert(templates:FindFirstChild('Stage'..stage),'Missing imported keeper stage '..stage)
 assert(template:GetAttribute('VisualVersion')==99,'Wrong keeper template version')
 return template:Clone()
end

function Art.Dress(model,stage)
 local existing=model:FindFirstChild('BeastBody')
 if model:GetAttribute('GardenerArtVersion')==99 and model:GetAttribute('KeeperClientAnimated')==true
  and existing and existing:GetAttribute('VisualVersion')==version(stage) then return model end
 local root=assert(model:FindFirstChild('HumanoidRootPart') or model.PrimaryPart,'Keeper root missing')
 local rig=Art.Build(stage);rig.Name='BeastBody'
 local initial=stage==5 and require(game:GetService('ReplicatedStorage').KeeperUpgradePose).Frames(5,0,0,0,0,0,0,0)
 for _,part in ipairs(rig:GetDescendants()) do
  if part:IsA('BasePart') then part.CFrame=root.CFrame*(initial and initial[part:GetAttribute('BeastGroup')]or CFrame.new())*(part:GetAttribute('TreeRestCFrame')or part:GetAttribute('IdleRestCFrame')or part:GetAttribute('RestCFrame')) end
 end
 -- Match the existing dresser's replacement boundary; build succeeds before old art goes.
 for _,child in ipairs(model:GetChildren()) do if child~=root then child:Destroy() end end
 rig.Parent=model
 root.Transparency=1;root.Anchored=true;root.CanCollide=false;root.CanTouch=false;root.CanQuery=false
 root:SetAttribute('PersistentGuardianTransparency',1)
 model.PrimaryPart=root;model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 model:SetAttribute('CreatureStage',stage);model:SetAttribute('GardenerName',Config[stage].Name)
 model:SetAttribute('GardenerTitle',Config[stage].Name);model:SetAttribute('GardenerArtVersion',99)
 model:SetAttribute('KeeperClientAnimated',true)
 model:SetAttribute('KeeperUpgradeVersion',version(stage))
 return model
end
return Art
