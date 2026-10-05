-- R38: approved native replacements for Forest, Crystal and Storm; other templates retained.
-- R152: every stage is built from the baked rev 6 model (KeeperMeshes152: BeastBody VisualVersion 152, KeeperMeshVariant 'R152') once its
-- template is ready; until then, if it cannot be baked, or with /test keepermodels off, today's keeper exactly as before. A keeper dressed
-- before its template was ready is swapped to the wanted model when it is next idle (GUARDING / SLEEPING, no chase): Keep() checks every
-- KeepSeconds without ever waiting for the bake. The model's KeeperMeshVariant attribute says which one it shows ('R152' / 'Legacy').
local Storage=game:GetService('ServerStorage')
local Config=require(game:GetService('ReplicatedStorage').KeeperRigConfig)
local Upgrades=require(script.Parent.KeeperUpgradeArt)
local Meshes=require(script.Parent.KeeperMeshes152)
local function version(stage)return (stage==1 or stage==5 or stage==7)and 59 or 99 end
local Art={Version=152,KeepSeconds=2}

function Art.Build(stage,variant)
 if variant=='R152'then local rig=Meshes.BuildRig(stage);if rig then return rig end end
 local replacement=Upgrades.Build(stage);if replacement then return replacement end
 local templates=assert(Storage:FindFirstChild('KeeperTemplatesV100'),'Install V100 keeper templates first')
 local template=assert(templates:FindFirstChild('Stage'..stage),'Missing imported keeper stage '..stage)
 assert(template:GetAttribute('VisualVersion')==99,'Wrong keeper template version')
 return template:Clone()
end

-- The variant a dressed body shows: 'R152' or nil (today's).
function Art.Variant(rig)return rig and rig:GetAttribute('KeeperMeshVariant')=='R152'and 'R152'or nil end
local function place(rig,root,stage,variant)
 local initial=stage==5 and require(game:GetService('ReplicatedStorage').KeeperUpgradePose).Frames(5,0,0,0,0,0,0,0,variant)
 for _,part in ipairs(rig:GetDescendants()) do
  if part:IsA('BasePart') then part.CFrame=root.CFrame*(initial and initial[part:GetAttribute('BeastGroup')]or CFrame.new())*(part:GetAttribute('TreeRestCFrame')or part:GetAttribute('IdleRestCFrame')or part:GetAttribute('RestCFrame')) end
 end
end
-- A new rig of the wanted variant; a failed new build falls back to today's (logged once).
local warned=false
local function build(stage,variant)
 if variant then
  local ok,rig=pcall(Art.Build,stage,variant)
  if ok and rig and Art.Variant(rig)==variant then return rig,variant end
  if not warned then warned=true;warn('[R152 keeper models] stage '..stage..' keeps today\'s model: '..tostring(rig))end
 end
 return Art.Build(stage),nil
end

function Art.Dress(model,stage)
 Meshes.Start()
 local want=Meshes.Wanted(stage)
 local existing=model:FindFirstChild('BeastBody')
 if model:GetAttribute('GardenerArtVersion')==99 and model:GetAttribute('KeeperClientAnimated')==true and existing then
  if want and Art.Variant(existing)==want then model:SetAttribute('KeeperMeshVariant',want);Art.Keep();return model end
  if not want and not Art.Variant(existing)and existing:GetAttribute('VisualVersion')==version(stage) then
   Upgrades.Refinish(existing,stage);model:SetAttribute('KeeperMeshVariant','Legacy');Art.Keep();return model
  end
 end
 local root=assert(model:FindFirstChild('HumanoidRootPart') or model.PrimaryPart,'Keeper root missing')
 local rig,variant=build(stage,want);rig.Name='BeastBody'
 place(rig,root,stage,variant)
 -- Match the existing dresser's replacement boundary; build succeeds before old art goes.
 for _,child in ipairs(model:GetChildren()) do if child~=root then child:Destroy() end end
 rig.Parent=model
 root.Transparency=1;root.Anchored=true;root.CanCollide=false;root.CanTouch=false;root.CanQuery=false
 root:SetAttribute('PersistentGuardianTransparency',1)
 model.PrimaryPart=root;model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 model:SetAttribute('CreatureStage',stage);model:SetAttribute('GardenerName',Config[stage].Name)
 model:SetAttribute('GardenerTitle',Config[stage].Name);model:SetAttribute('GardenerArtVersion',99)
 model:SetAttribute('KeeperClientAnimated',true)
 model:SetAttribute('KeeperUpgradeVersion',variant and Meshes.Revision or version(stage))
 model:SetAttribute('KeeperMeshVariant',variant or 'Legacy')
 Art.Keep()
 return model
end

-- Swaps an idle dressed keeper's body to the wanted variant; true when it did. Only BeastBody changes (root, attributes, tags stay).
local IDLE={GUARDING=true,SLEEPING=true}
function Art.Swap(model,stage)
 local body=model:FindFirstChild('BeastBody');local root=model:FindFirstChild('HumanoidRootPart')or model.PrimaryPart
 if not body or not root or model:GetAttribute('GardenerArtVersion')~=99 then return false end
 local want=Meshes.Wanted(stage)
 if Art.Variant(body)==want then return false end
 if not IDLE[model:GetAttribute('GuardianBehavior')or'GUARDING']or(tonumber(model:GetAttribute('GuardianLeaseToken'))or 0)~=0 then return false end
 local rig,variant=build(stage,want);rig.Name='BeastBody'
 if Art.Variant(body)==variant then rig:Destroy();return false end
 place(rig,root,stage,variant)
 body:Destroy();rig.Parent=model
 model:SetAttribute('KeeperUpgradeVersion',variant and Meshes.Revision or version(stage))
 model:SetAttribute('KeeperMeshVariant',variant or 'Legacy')
 return true
end
-- Every dressed biome keeper of this server (the persistent guardians, also ones restored from a blueprint).
function Art.Keepers()
 local out={}
 for _,model in ipairs(game:GetService('CollectionService'):GetTagged('BiomeKeeper'))do
  local stage=model:GetAttribute('CreatureStage')
  if model:IsA('Model')and not model:GetAttribute('VeiledKeeper81')and type(stage)=='number'and Config[stage]and model:IsDescendantOf(workspace)then out[#out+1]=model end
 end
 return out
end
-- One check now (returns how many keepers were swapped), then again every KeepSeconds (one timer per server).
local keeping=false
function Art.Step()
 local swapped=0
 for _,model in ipairs(Art.Keepers())do
  local ok,did=pcall(Art.Swap,model,model:GetAttribute('CreatureStage'))
  if ok and did then swapped+=1 elseif not ok then warn('[R152 keeper models] '..tostring(did))end
 end
 return swapped
end
function Art.Keep()
 if keeping then return end
 keeping=true
 local function tick()Art.Step();task.delay(Art.KeepSeconds,tick)end
 task.delay(Art.KeepSeconds,tick)
end
return Art
