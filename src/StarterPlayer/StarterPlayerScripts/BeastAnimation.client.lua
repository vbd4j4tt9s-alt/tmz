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
local Combat=require(Storage.KeeperCombat)
-- R113: client-only polish (look-at, wake roar, weight, follow-through, taunt), effects and accent parts.
local Polish=require(Storage:WaitForChild('KeeperPolish'));local KFx=require(Storage:WaitForChild('KeeperFx'));local Accents=require(Storage:WaitForChild('KeeperAccents'))
local Players=game:GetService('Players')
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
 if record then if record.Surge then Surge.Destroy(record.Surge)end;KFx.Destroy(record.Fx);Accents.Destroy(record.Accents);record.Sound:Destroy();record.Sleep:Destroy();records[model]=nil end
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
  Surge=stage==7 and Surge.New(model)or nil,Motion=Motion.new(root.CFrame,awake),Sleep=Sleep.new(root,stage,Config[stage]),
  Polish=Polish.new(),Fx=KFx.new(root,stage),Accents=Accents.new(model,stage),PoseDt=0}
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
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local own=character and character:FindFirstChild('HumanoidRootPart');local low=Fx.Low()
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
  local rootFrame=r.Root.CFrame;local frame=Dash.VisualFrame(model,now,rootFrame)
  local motion=Motion.Update(r.Motion,frame,speed,asleep,state=='ALERTED'or state=='ATTACKING',dt,r.Stage,state=='CHASING'or state=='DASHING',frame~=rootFrame)
  local distance=(camera.CFrame.Position-r.Root.Position).Magnitude
  local voiceReady=now-(model:GetAttribute('KeeperLastHitAt')or -100)>1.1
  -- R121: Stop only a sound that is playing (was a Stop call per keeper per frame).
  if not voiceReady and r.Sound.Playing then r.Sound:Stop() end
  -- R121: resolve the voice when the override changes (and twice a second for live module attributes),
  -- not every frame; Sound properties are written only when they differ.
  local override=model:GetAttribute('KeeperVoiceId')
  if not r.VoiceAt or override~=r.VoiceKey or now>=r.VoiceAt then
   r.VoiceKey=override;r.VoiceAt=now+.5
   local id,volume,pitch=Audio.Voice(r.Stage,'Alert',override);r.VoiceId=id
   if r.Sound.SoundId~=(id or '')then r.Sound.SoundId=id or ''end
   if r.Sound.Volume~=volume then r.Sound.Volume=volume end
   if r.Sound.PlaybackSpeed~=pitch then r.Sound.PlaybackSpeed=pitch end
  end
  local voiceId=r.VoiceId
  if voiceId and voiceReady and distance<110 and (state=='ALERTED' or state=='CHASING')
   and (state~=r.State or now-r.LastVoice>(Voices[r.Stage].Gap or 6)) and now-r.LastVoice>2 then
   if not r.Sound.IsPlaying then Timing.Play(r.Sound);r.LastVoice=now end
  elseif (asleep or state=='RETURNING' or distance>=110) and r.Sound.Playing then r.Sound:Stop() end
  -- R113: wake roar starts when a sleeping keeper is first seen alerted.
  local wasAsleep=r.State=='GUARDING'or r.State=='SLEEPING'
  if wasAsleep and(state=='ALERTED'or state=='CHASING'or state=='DASHING')then r.WakeAt=now end
  r.State=state
  -- R112: when this client first saw the attack; the wind-back restarts there instead of popping in.
  local seenAttack=model:GetAttribute('KeeperAttackAt');if seenAttack~=r.AttackAt then r.AttackAt=seenAttack;r.AttackSeen=now end
  -- R113: effects run every frame (footfall phase), culled by distance inside KeeperFx.
  local localDistance=own and(own.Position-r.Root.Position).Magnitude or distance
  local hunting=state=='CHASING'or state=='DASHING'or state=='ALERTED'or state=='ATTACKING'
  -- R121: one reusable effect context per keeper (was a new 12-field table per keeper per frame).
  local fxc=r.FxContext;if not fxc then fxc={};r.FxContext=fxc end
  fxc.Now=now;fxc.Distance=distance;fxc.LocalDistance=localDistance;fxc.Asleep=asleep;fxc.Awake=motion.Awake;fxc.Moving=motion.Moving
  fxc.Cycle=motion.Cycle;fxc.Urgency=motion.Urgency;fxc.Chasing=hunting;fxc.Frame=motion.Frame;fxc.Frames=r.LastTarget;fxc.Low=low
  KFx.Step(r.Fx,fxc)
  r.PoseDt+=dt
  local onScreen=true
  if distance>160 then local _,seen=camera:WorldToViewportPoint(r.Root.Position);onScreen=seen end
  if not Budget.KeeperDue(distance,asleep,motion.Awake,onScreen,now,r.LastPose,Fx.Low())then continue end
  r.LastPose=now
  local target=Pose.Frames(r.Stage,motion.Time,motion.Awake,motion.Moving,motion.Cycle,motion.Urgency,motion.Speed,motion.Turn)
  target=AttackPose.Apply(r.Stage,target,now,model:GetAttribute('KeeperAttackAt'))
  local attackAt=model:GetAttribute('KeeperAttackAt')
  -- R110: strike pose only while it is live. KeeperAttackAt outlives a miss, and the old 1.5 s
  -- window slid a chasing keeper in its idle pose on the raw, packet-stepped root.
  local windup=Combat.Get(r.Stage).Windup;local striking=false
  if attackAt and now>=attackAt and now-attackAt<windup+Combat.Recovery then
   target=Strike.Frames(r.Stage,now,attackAt,r.AttackSeen and r.AttackSeen-attackAt);motion.Awake=1;striking=true
  end
  -- R113: taunt once after a landed catch; slam dust at the visual impact.
  local lastHit=model:GetAttribute('KeeperLastHitAt')
  if attackAt and type(lastHit)=='number'and lastHit>=attackAt and r.TauntFor~=attackAt then r.TauntFor=attackAt;r.TauntAt=attackAt+windup+Combat.Recovery end
  if attackAt and now>=attackAt+windup and r.SlamFor~=attackAt then
   r.SlamFor=attackAt;if now-attackAt-windup<.2 then fxc.Frames=target;KFx.Slam(r.Fx,fxc)end
  end
  local look
  if not asleep then
   local id=model:GetAttribute('TargetUserId');local who=type(id)=='number'and id>0 and Players:GetPlayerByUserId(id)
   local body=who and who.Character and who.Character:FindFirstChild('HumanoidRootPart')
   if body and (body.Position-r.Root.Position).Magnitude<90 then look=body.Position end
  end
  target=Polish.Apply(r.Polish,r.Stage,target,{Now=now,Dt=r.PoseDt,Awake=motion.Awake,Moving=motion.Moving,Speed=motion.Speed,
   Frame=motion.Frame,Asleep=asleep,Look=look,Stir=asleep and localDistance<24,Strike=striking,
   Impact=attackAt and attackAt+windup,WakeAt=r.WakeAt,TauntAt=r.TauntAt})
  r.PoseDt=0;r.LastTarget=target
  if r.WakeAt and r.WakeFxFor~=r.WakeAt then r.WakeFxFor=r.WakeAt;fxc.Frames=target;KFx.Wake(r.Fx,fxc)end
  if r.Surge then Surge.Step(r.Surge,motion.Frame,target,now,distance<190 and math.max(.25,motion.Awake)or 0)end
  r.Sleep:Update(asleep and motion.Awake<.15,distance,now,motion.Frame*target.Head,low)
  -- R78: full-rate nearby combat; distant geometry updates use bounded LOD.
  for _,p in ipairs(r.Parts)do if p.Part.Parent then
   local pose,size=UpgradePose.PartPose(p.Rest,p.TreeRest or p.IdleRest,p.Size,p.TreeSize or p.IdleSize,target[p.Group],motion.Awake)
   table.insert(moveParts,p.Part);table.insert(moveFrames,motion.Frame*pose)
   if (p.TreeRest or p.IdleRest)and p.Part.Size~=size then p.Part.Size=size end
   if p.Eye and p.LastEyeAwake~=motion.Awake then eyes(p.Part,p.EyeColor,motion.Awake,p.TreeRest~=nil);p.LastEyeAwake=motion.Awake end
  end end
  Accents.Pose(r.Accents,target,motion.Frame,motion.Awake,now,hunting and not asleep,moveParts,moveFrames)
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
