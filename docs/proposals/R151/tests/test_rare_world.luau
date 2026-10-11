--!nocheck
-- R151 pull reveals, part 3: the REAL SeedPackClient and PackOpeningFeedback (with RevealFlourish, PackSuspense, RarePullWorld,
-- RarePullCinematic, RarityRevealAudio, InteractionAudio, LocalSfx) on the Roblox mock - what the opener and the people watching see.
-- R154: the opener's result waits for a press now (it collects it: the seed flies home); the checks that saw it end by itself press first.
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local noop=function()end
function R.Inst:Play()local own=rawget(self,'_props').Play;if own then return own(self)end end
function R.Inst:Stop()local own=rawget(self,'_props').Stop;if own then return own(self)end end
function R.Inst:Pause()end
local Players=W.service('Players')
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
local Mixer=W.module('AudioMixer');Mixer.Start()
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules');local Seq=W.module('RarityRevealSequence')
local World=W.module('RarePullWorld');local M=W.module('RarePullCinematic')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
local others={}
function Players.GetPlayers()local out={X.player};for _,p in ipairs(others)do if p.Parent then out[#out+1]=p end end;return out end
local function otherPlayer(name,x,z)
 local p=R.new('Player');p.Name=name;p.UserId=100+#others;p.Parent=Players;others[#others+1]=p
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace;p.Character=c
 local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(x,5,z);t.Parent=c
 local h=R.new('Part');h.Name='HumanoidRootPart';h.Size=V3(2,2,1);h.CFrame=CF(x,4,z);h.Parent=c
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=c
 return p,c
end
function Players.GetPlayerFromCharacter(_,c)if c==X.char then return X.player end;for _,p in ipairs(others)do if p.Character==c then return p end end;return nil end
-- load the real scripts
local spc=R.new('LocalScript');spc.Name='SeedPackClient'
local okc,errc=pcall(W.load,'SeedPackClient',spc);check(okc,'the real SeedPackClient loads: '..tostring(errc))
local pof=R.new('LocalScript');pof.Name='PackOpeningFeedback'
local okp,errp=pcall(W.load,'PackOpeningFeedback',pof);check(okp,'the real PackOpeningFeedback loads: '..tostring(errp))
local function effects()return W.workspace:FindFirstChild('_LocalSeedPackEffects')end
local function opening()local e=effects();local r=e and e:FindFirstChild('SeedReveal');return r end
local function reveal(char,rank,opts)
 opts=opts or{}
 local bag=Visuals.CarryBag(char,2,opts.Variant or'Pack02',1,opts.Size or 1,'None')
 local seedId=X.byRank[rank]
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealDuration',Rules.GetRevealDuration(names[rank]));bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow()-(opts.late or 0))
 return bag
end
local function reset()
 M.Abort('test');World.Clear();R.advance(5)
 cam=W.workspace.CurrentCamera;cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112)
 for _,c in ipairs(X.char:GetChildren())do if c:IsA('Tool')or c.Name=='CarriedSeed'then c:Destroy()end end
end
-- 1. the opener's own Common..Mythic pack: suspense in the world, the seed card on screen -------------------------------------------------
for rank=1,5 do
 reset();E.resetPlays()
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='p'..rank,Stage=2},nil);tool.Activated=R.signal();tool.Enabled=false;tool.Parent=X.char
 local bag=reveal(X.char,rank);local t0=R.clock;local burst=L.BurstAt(rank);local dur=Rules.GetRevealDuration(names[rank])
 W.frames(2,1/30)
 local run=M.Active()
 check(run and run.Kind=='Ladder'and run.Rank==rank,names[rank]..': opening it starts the seed card')
 local glowSeen,hintEnd,seedEarly,seedOut,wobble,peelMid,lastPos=false,nil,false,false,false,nil,nil
 local lowPop,lowPopEarly=false,false
 W.frames(1,1/30)
 while R.clock-t0<dur-.05 do
  W.frames(1,1/30);local t=R.clock-t0
  local o=opening();local glow=o and o:FindFirstChild('Pack seam glow')
  if glow and t<burst and glow.Transparency<1 then glowSeen=true end
  if glow and t>burst-.07 and t<burst-.01 then hintEnd=glow.Color end
  local seed=o and o:FindFirstChild('RewardSeed');local part
  if seed then for _,d in ipairs(seed:GetDescendants())do if d:IsA('BasePart')and d~=seed.PrimaryPart then part=d;break end end end
  if part and t<burst-.05 and part.LocalTransparencyModifier<1 then seedEarly=true end
  if part and t>burst+.1 and t<burst+.3 and part.LocalTransparencyModifier<1 then seedOut=true end
  local copy=o and o:FindFirstChild('OpeningBag');local body=copy and copy:FindFirstChild('BottomSeal')
  if body and t>burst*.4 and t<burst*.95 then if lastPos and(body.CFrame.Position-lastPos).Magnitude>1e-4 then wobble=true end;lastPos=body.CFrame.Position end
  if copy and t>burst*.5 and t<burst*.6 and not peelMid then
   local open=0;for i=1,8 do local s=copy:FindFirstChild('TearStrip'..i);if s and s.Transparency>.5 then open+=1 end end;peelMid=open
  end
  local gui=X.pg:FindFirstChild('PackOpeningEffects');local node=gui and X.find(gui,'Rarity light 1')
  if rank<=3 and node and node.Visible then if t<burst-.02 then lowPopEarly=true else lowPop=true end end
 end
 check(glowSeen,names[rank]..': the pack\'s seam glows while it builds')
 check(hintEnd and math.abs(hintEnd.R-L.Tiers[rank].Hint.R)<.02 and math.abs(hintEnd.G-L.Tiers[rank].Hint.G)<.02 and math.abs(hintEnd.B-L.Tiers[rank].Hint.B)<.02,names[rank]..': the hint in the cracks ends on the tier colour')
 check(not seedEarly and seedOut,names[rank]..': the seed bursts out at the end of the suspense ('..burst..' s), not before')
 check(wobble,names[rank]..': the pack wobbles while it builds')
 check(peelMid and peelMid>=1 and peelMid<8,names[rank]..': it tears a bit at a time ('..tostring(peelMid)..' strips open half way)')
 if rank<=3 then check(lowPop and not lowPopEarly,names[rank]..': the small 2D pop comes with the burst')end
 -- the burst sound (RarityRevealAudio, existing) and the ladder's own PackBurst on the burst
 local burstVoice;for _,s in ipairs(E.sounds)do if s.Name=='RarePull_PackBurst_1'then burstVoice=s end end
 local log=burstVoice and burstVoice.PlayLog[#burstVoice.PlayLog]
 check(log and near(log.At-t0,burst,.06),names[rank]..': PackBurst on the burst')
 if rank<=3 then
  local low=({'Reveal_Pop','Reveal_Pop','Reveal_Spark'})[rank];local v;for _,s in ipairs(E.sounds)do if s.Name==low then v=s end end
  local l=v and v.PlayLog[#v.PlayLog];check(l and near(l.At-t0,burst,.06),names[rank]..': the R138 pull sound still plays, now on the burst')
 end
 -- the server ends the opening; the card waits for its collect (R154), then everything goes
 bag:Destroy();tool:Destroy();W.frames(3,1/30)
 check(opening()==nil,names[rank]..': the world reveal is released with the pack')
 X.run(5)
 check(M.Active()==run and M.Waiting(),names[rank]..': the card waits for the player (R154)')
 W.UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,KeyCode=R.Enum.KeyCode.Unknown,Position=V3(400,300,0)},false)
 X.run(1.5)
 check(run.Collected and M.Active()==nil and X.pg:FindFirstChild('RarePullReveal')==nil,names[rank]..': a click collects it and the card goes')
end
-- 2. the opener's own King pull: the story scene owns the camera (even for a giant pack) --------------------------------------------------
do
 reset()
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='k',Stage=2},nil);tool.Activated=R.signal();tool.Enabled=false;tool.Parent=X.char
 local bag=reveal(X.char,8,{Size=12})
 W.frames(2,1/30)
 local run=M.Active();check(run and run.Kind=='Scene'and run.Rank==8,'King: the opener gets the story scene')
 X.run(run.TL.SceneIn+.3)
 check(cam.CameraType==R.Enum.CameraType.Scriptable and(cam.CFrame.Position-L.StageOrigin).Magnitude<120,'a giant pack does not take the camera from the story scene')
 local w=World.Get(X.player);check(w~=nil,'the opener\'s own pillar / aura run in the world too (seen by others, and by them when the camera is back)')
 bag:Destroy();tool:Destroy()
 X.run(run.TL.Length)
 check(M.Active()==run and M.Waiting()and cam.CameraType==R.Enum.CameraType.Scriptable,'King: the result waits on the hero shot (R154)')
 local b=X.find(X.pg,'Backdrop');if b then b.Activated:Fire()end
 X.run(M.SceneExit+(run.TL.Length-run.TL.Back)+1)
 check(M.Active()==nil and cam.CameraType==R.Enum.CameraType.Custom,'King: collected, the scene ends with the camera back')
 local aura=X.root:FindFirstChild('RarePullAura');check(aura~=nil,'back in the world, the King aura is around the player')
end
-- 3. someone else's Secret / Cosmic / King pull: the world effects only --------------------------------------------------------------------
cam.CFrame=CF(0,6,20)
local _,oc=otherPlayer('Other',0,0)
for rank=6,8 do
 reset();cam.CFrame=CF(0,6,20)
 local bag=reveal(oc,rank);local t0=R.clock;local tl=L.WorldTimeline(rank);local dur=Rules.GetRevealDuration(names[rank])
 local who=Players:GetPlayerFromCharacter(oc)
 local early,pillar,ring,aura,stageSeen,cinematic=false,false,false,false,false,false;local landedAt
 local camMoved=false;local cf0,fov0=tostring(cam.CFrame.Position)..tostring(cam.CFrame.LookVector),cam.FieldOfView -- (R155)
 X.run(dur-.05,1/30,function(now)
  local t=now-t0;local e=World.Get(who)
  if tostring(cam.CFrame.Position)..tostring(cam.CFrame.LookVector)~=cf0 or cam.FieldOfView~=fov0 or cam.CameraType~=R.Enum.CameraType.Custom or cam:FindFirstChild('RarePullDof')then camMoved=true end
  if W.workspace:FindFirstChild('_RarePullStage')then stageSeen=true end
  if M.Active()then cinematic=true end
  if e then
   -- (R152: the pillar is the sky beam of RarePullFx: it slams down in its last Descent seconds and lands on the burst)
   if t<tl.Burst-e.Beam.Descent-.03 and e.Beam:Visible()then early=true end
   if e.Beam.Landed and not landedAt then landedAt=t end
   if t>tl.Burst+.3 and t<tl.Burst+1 and e.Beam:Visible()then pillar=true end
   if t>tl.Burst+.3 and t<tl.Burst+.8 and e.Beam:RingShown()then ring=true end
  end
 end)
 local e=World.Get(who)
 check(e~=nil,names[rank]..': onlookers get the world effect')
 check(not early and pillar,names[rank]..': the sky beam comes down for the burst ('..tl.Burst..' s), not before')
 check(landedAt and landedAt>=tl.Burst-.001 and landedAt<tl.Burst+1/30+.001,names[rank]..': and lands on it ('..tostring(landedAt)..' s)')
 check(ring,names[rank]..': a shockwave ring on the ground')
 check(not stageSeen and not cinematic,names[rank]..': onlookers never get the story scene (no hidden stage, no camera)')
 check(not camMoved,names[rank]..': R155: an onlooker\'s camera is never written (CFrame, FieldOfView, type; no depth of field)')
 bag:Destroy();X.run(1)
 local root=oc:FindFirstChild('HumanoidRootPart')
 check(World.Get(who)~=nil and root:FindFirstChild('RarePullAura')~=nil,names[rank]..': the afterglow aura stays after the reveal ends')
 local hum=root:FindFirstChild('RarePullAura'):FindFirstChildOfClass('Sound')
 check(hum and hum.Looped and hum.SoundGroup==Mixer.Group('Effects'),names[rank]..': a quiet aura hum on the Effects group')
 X.run(tl.AuraEnd-(R.clock-t0)+.5)
 check(World.Get(who)==nil and root:FindFirstChild('RarePullAura')==nil,names[rank]..': the aura ends after '..L.Tiers[rank].AuraSeconds..' s')
 check(not World.Connected(),names[rank]..': and no per-frame work is left')
end
do -- far away: nothing is moved
 reset();cam.CFrame=CF(0,6,20)
 local bag=reveal(oc,8);local who=Players:GetPlayerFromCharacter(oc);X.run(L.WorldTimeline(8).Burst+.5)
 cam.CFrame=CF(0,6,400);X.run(.2)
 local e=World.Get(who);local shown=0;for _,d in ipairs(e.Folder:GetDescendants())do if d:IsA('BasePart')and d.Transparency<1 then shown+=1 end end
 check(e.Far and shown==0,'far away (160+ studs): the pillar and aura are hidden and not updated')
 bag:Destroy();World.Clear();check(not World.Connected(),'cleared: no per-frame work')
end
do -- phone / low quality: fewer pieces
 reset();cam.CFrame=CF(0,6,20);X.lowFx=true
 local bag=reveal(oc,7);local who=Players:GetPlayerFromCharacter(oc);X.run(.1)
 local e=World.Get(who);check(e.Lite and #e.Motes<=6 and #e.Beam.Ring<=12 and #e.Beam.Streaks<=1 and e.Beam.Haze==nil,'low quality: fewer motes, ring pieces and beam layers')
 bag:Destroy();World.Clear();X.lowFx=false
end
do -- below Secret: no pillar from this module; the R136 / R138 flourish at the new burst
 reset();cam.CFrame=CF(0,6,20)
 local bag=reveal(oc,5);local who=Players:GetPlayerFromCharacter(oc);local t0=R.clock
 local pillarAt
 X.run(2,1/30,function(now)
  local o=opening();local f=o and o:FindFirstChild('RevealFlourish',true);local p=f and f:FindFirstChild('Light pillar');local core=p and p:FindFirstChild('Beam core')
  if core and core.Enabled and not pillarAt then pillarAt=now-t0 end
 end)
 check(World.Get(who)==nil,'Mythic: no Secret+ world effect')
 check(pillarAt and near(pillarAt,L.BurstAt(5)-.12,.07),'Mythic: its beam comes down onto the seed\'s burst at the end of the new suspense ('..tostring(pillarAt)..' s)')
 bag:Destroy()
end
do -- the R150 onlooker impact still plays once for a Secret+ pull
 reset();cam.CFrame=CF(0,6,20);E.resetPlays()
 local Impact=W.module('RevealFlourish').SoundId
 local bag=reveal(oc,6);X.run(4)
 local n=0;for _,s in ipairs(E.sounds)do if s.SoundId==Impact and(s.Name=='ChestChaseOneShot'or s.Name=='Seed burst')then n+=s.Plays end end
 check(n==1,'Secret onlooker: one impact at the bag ('..n..')')
 bag:Destroy();World.Clear()
end
spc.Destroying:Fire();pof.Destroying:Fire()
check(M.Active()==nil,'PackOpeningFeedback destroyed: no presentation left')
print(('R151 world checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
