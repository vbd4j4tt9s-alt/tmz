-- V106: weighted chase poses; existing root smoothing and server catches remain authoritative.
local Run=game:GetService('RunService')
local Storage=game:GetService('ReplicatedStorage')
local Pose=require(Storage:WaitForChild('BeastPose'))
local Config=require(Storage:WaitForChild('KeeperRigConfig'))
local AttackPose=require(Storage:WaitForChild('KeeperAttackPose'))
local Audio=require(Storage:WaitForChild('KeeperAudio'))
local Timing=require(Storage:WaitForChild('SoundTiming'))
local Voices=require(Storage:WaitForChild('KeeperVoices'))
local Motion=require(Storage:WaitForChild('KeeperMotion'))
local Dash=require(Storage:WaitForChild('KeeperRecoveryDash'))
local UpgradePose=require(Storage:WaitForChild('KeeperUpgradePose'))
local Sleep=require(Storage:WaitForChild('KeeperSleep'))
local Surge=require(Storage:WaitForChild('KeeperSurge'))
local Budget=require(Storage.CosmeticBudget);local Fx=require(Storage.ClientFxBudget);local Strike=require(Storage.KeeperStrikeFrames)
local records,watchers,pending={},{},{}
local BLACK=Color3.new(0,0,0)
local destroyed=false
local function eyes(part,color,awake,tree)
 part.LocalTransparencyModifier=tree and 1-awake or 0
 part.Color=BLACK:Lerp(color,awake)
 part.Material=awake>.5 and Enum.Material.Neon or Enum.Material.SmoothPlastic
end

local function clear(model)
 local record=records[model]
 if record then if record.Surge then Surge.Destroy(record.Surge)end;record.Sound:Destroy();record.Sleep:Destroy();records[model]=nil end
end
local function bind(model)
 if destroyed then return end
 if not model:IsDescendantOf(workspace) or model:GetAttribute('GardenerArtVersion')~=99 then return end
 local root=model:FindFirstChild('HumanoidRootPart');local rig=model:FindFirstChild('BeastBody')
 local stage=model:GetAttribute('CreatureStage') or model:GetAttribute('Stage')
 if not root or not rig or not Config[stage] or not Voices[stage] then return end
 local expectedVersion=(stage==1 or stage==5 or stage==7)and 59 or 99
 if rig:GetAttribute('VisualVersion')~=expectedVersion then return end
 if records[model] and records[model].Rig==rig then return end
 local parts={};local eyeColor
 for _,spec in ipairs(Config[stage].Parts) do
  if spec.EyeGlow then eyeColor=Color3.new(table.unpack(spec.Color));break end
 end
 for _,part in ipairs(rig:GetDescendants()) do
  if part:IsA('BasePart') and part:GetAttribute('RestCFrame') then
   table.insert(parts,{Part=part,Rest=part:GetAttribute('RestCFrame'),Group=part:GetAttribute('BeastGroup'),Size=part.Size,TreeRest=part:GetAttribute('TreeRestCFrame'),TreeSize=part:GetAttribute('TreeRestSize'),IdleRest=part:GetAttribute('IdleRestCFrame'),IdleSize=part:GetAttribute('IdleRestSize'),Eye=part:GetAttribute('KeeperEyeGlow')==true,EyeColor=eyeColor})
  end
 end
 if #parts~=#Config[stage].Parts then return end -- wait for a complete streamed rig
 clear(model)
 local voice=Voices[stage];local sound=Instance.new('Sound');sound.Name='KeeperVoiceLocal'
 local id,volume,pitch=Audio.Voice(stage,'Alert',model:GetAttribute('KeeperVoiceId'))
 sound.SoundId=id or '';sound.Volume=volume
 sound.PlaybackSpeed=pitch;sound.RollOffMode=Enum.RollOffMode.InverseTapered
 sound.RollOffMinDistance=12;sound.RollOffMaxDistance=110;sound.Parent=root
 local state=model:GetAttribute('GuardianBehavior') or 'GUARDING'
 local awake=(state=='GUARDING' or state=='SLEEPING') and 0 or 1
 for _,p in ipairs(parts) do if p.Eye then eyes(p.Part,p.EyeColor,awake,p.TreeRest~=nil) end end
 records[model]={Root=root,Rig=rig,Parts=parts,Stage=stage,Awake=awake,
  Last=root.Position,SampleTime=0,SampleTravel=0,ObservedSpeed=0,LastVoice=-100,Sound=sound,State=state,
  Surge=stage==7 and Surge.New(model)or nil,Motion=Motion.new(root.CFrame,awake),Sleep=Sleep.new(root,stage,Config[stage])}
end
local function schedule(model)
 if pending[model] then return end
 pending[model]=true;task.defer(function() pending[model]=nil;bind(model) end)
end
local function watch(model)
 if not model or not model:IsA('Model') then return end
 if not watchers[model] then
  local signals={};watchers[model]=signals
  table.insert(signals,model:GetAttributeChangedSignal('GardenerArtVersion'):Connect(function() schedule(model) end))
  table.insert(signals,model:GetAttributeChangedSignal('CreatureStage'):Connect(function() schedule(model) end))
  table.insert(signals,model.ChildRemoved:Connect(function(child)
   if child.Name=='BeastBody' or child.Name=='HumanoidRootPart' then clear(model) end
  end))
  table.insert(signals,model.AncestryChanged:Connect(function()
   if model:IsDescendantOf(workspace) then return end
   clear(model);pending[model]=nil
   for _,signal in ipairs(signals) do signal:Disconnect() end
   watchers[model]=nil
  end))
 end
 schedule(model)
end
local function check(node)
 if node.Name=='BeastBody' or node.Name=='HumanoidRootPart' then watch(node.Parent)
 elseif node:IsA('BasePart') and node.Parent and node.Parent.Name=='BeastBody' then watch(node.Parent.Parent) end
end
for _,node in ipairs(workspace:GetDescendants()) do check(node) end
local added=workspace.DescendantAdded:Connect(check)

local moveParts,moveFrames={},{}
local render=Run.RenderStepped:Connect(function(dt)
 table.clear(moveParts);table.clear(moveFrames)
 local camera=workspace.CurrentCamera
 if not camera then
  for _,r in pairs(records)do r.Sleep:Update(false,math.huge,0,r.Root.CFrame)end
  return
 end
 local now=workspace:GetServerTimeNow()
 for model,r in pairs(records) do
  if not model:IsDescendantOf(workspace) or r.Rig.Parent~=model or not r.Root.Parent then clear(model);continue end
  local state=model:GetAttribute('GuardianBehavior') or 'GUARDING'
  local asleep=state=='GUARDING' or state=='SLEEPING'
  local delta=r.Root.Position-r.Last;r.Last=r.Root.Position
  local travel=Vector3.new(delta.X,0,delta.Z).Magnitude
  r.SampleTime+=dt;r.SampleTravel+=travel<40 and travel or 0
  if r.SampleTime>=.10 then
   r.ObservedSpeed=r.SampleTravel/r.SampleTime;r.SampleTime=0;r.SampleTravel=0
  end
  local speed=model:GetAttribute('KeeperTravelSpeed')
  if type(speed)~='number' or speed~=speed then speed=r.ObservedSpeed end
  local frame=Dash.VisualFrame(model,now,r.Root.CFrame)
  local motion=Motion.Update(r.Motion,frame,speed,asleep,state=='ALERTED'or state=='ATTACKING',dt,r.Stage,state=='CHASING'or state=='DASHING')
  local distance=(camera.CFrame.Position-r.Root.Position).Magnitude
  local voiceReady=now-(model:GetAttribute('KeeperLastHitAt')or -100)>1.1
  if not voiceReady then r.Sound:Stop() end
  local voiceId,volume,pitch=Audio.Voice(r.Stage,'Alert',model:GetAttribute('KeeperVoiceId'))
  if r.Sound.SoundId~=(voiceId or '')then r.Sound.SoundId=voiceId or ''end
  r.Sound.Volume=volume;r.Sound.PlaybackSpeed=pitch
  if voiceId and voiceReady and distance<110 and (state=='ALERTED' or state=='CHASING')
   and (state~=r.State or now-r.LastVoice>(Voices[r.Stage].Gap or 6)) and now-r.LastVoice>2 then
   if not r.Sound.IsPlaying then Timing.Play(r.Sound);r.LastVoice=now end
  elseif asleep or state=='RETURNING' or distance>=110 then r.Sound:Stop() end
  r.State=state
  local onScreen=true
  if distance>160 then local _,seen=camera:WorldToViewportPoint(r.Root.Position);onScreen=seen end
  if not Budget.KeeperDue(distance,asleep,motion.Awake,onScreen,now,r.LastPose,Fx.Low())then continue end
  r.LastPose=now
  local target=Pose.Frames(r.Stage,motion.Time,motion.Awake,motion.Moving,motion.Cycle,motion.Urgency,motion.Speed,motion.Turn)
  target=AttackPose.Apply(r.Stage,target,now,model:GetAttribute('KeeperAttackAt'))
  local attackAt=model:GetAttribute('KeeperAttackAt')
  if attackAt and now>=attackAt and now-attackAt<1.5 then
   target=Strike.Frames(r.Stage,now,attackAt);motion.Frame=r.Root.CFrame;motion.Awake=1
  end
  if r.Surge then Surge.Step(r.Surge,motion.Frame,target,now,distance<190 and math.max(.25,motion.Awake)or 0)end
  r.Sleep:Update(asleep and motion.Awake<.15,distance,now,motion.Frame*target.Head)
  -- R78: full-rate nearby combat; distant geometry updates use bounded LOD.
  for _,p in ipairs(r.Parts)do if p.Part.Parent then
   local pose,size=UpgradePose.PartPose(p.Rest,p.TreeRest or p.IdleRest,p.Size,p.TreeSize or p.IdleSize,target[p.Group],motion.Awake)
   table.insert(moveParts,p.Part);table.insert(moveFrames,motion.Frame*pose)
   if (p.TreeRest or p.IdleRest)and p.Part.Size~=size then p.Part.Size=size end
   if p.Eye and p.LastEyeAwake~=motion.Awake then eyes(p.Part,p.EyeColor,motion.Awake,p.TreeRest~=nil);p.LastEyeAwake=motion.Awake end
  end end
 end
 if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveFrames,Enum.BulkMoveMode.FireCFrameChanged)end
end)
script.Destroying:Connect(function()
 destroyed=true
 render:Disconnect();added:Disconnect()
 for model in pairs(records)do clear(model)end
 for _,signals in pairs(watchers)do for _,signal in ipairs(signals)do signal:Disconnect()end end
 table.clear(watchers);table.clear(pending)
end)
