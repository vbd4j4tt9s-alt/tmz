--!nocheck
-- R153 Mech pack opening (MechPackFx153: the full Mech touch on the R152 reveal's own beats). The REAL SeedPackClient and PackOpeningFeedback (with every
-- reveal module) on the Roblox mock, driven the way ChestService drives them (the carried pack, its clicks, RevealSeedId / RevealDuration / RevealAt, the pack
-- destroyed when the reveal ends):
--  1. clicks    clicks 1-4 each back out one corner bolt (both faces) on the opener's clicking copy, with UpgradeClick's tick at Bubble04's volume instead of
--               Bubble04; click 5 is Bubble04 as before; any other pack clicks Bubble04 five times and has no Mech cue at all
--  2. beats     a Mythic opening at 30 and at 60 fps: a scan line on every wobble pulse (RarePullRules.Pulses), in the hint colour of that moment
--               (RarePullRules.Hint), the core / traces in it; a puff of steam and the hiss on every tear group (the record's TearTicks); the steam ring on
--               the burst (BurstAt); the turbine faster through the suspense and spun down after; the bolts out, the stripes with their strips; every cue
--               within one reveal update (1/30 s) of its beat, the same at both frame rates; the opening is not one frame longer
--  3. sound     at most 2 extra voices (the hiss is one voice, restarted), each quieter than the hit; the hiss <= -30 LUFS (R152's whoosh cap) and >= 8 dB
--               under the hit; the whole mix with it <= -18 LUFS (the files measured: R152 sound_levels.luau)
--  4. calm      ReducedMotion and low quality: no bolt / turbine motion and no steam, just the scan colour
--  5. others    an onlooker sees the cues on someone else's pack (the bolts come out in the reveal's first moment); a Secret story scene skipped: the world
--               cues keep their beats; R157: SKIP only for Secret / Cosmic / King: a Mythic card's skip is ignored (no clock jump, the touch plays in full), the
--               compact in-place Secret / Cosmic / King card keeps its skip (the jump to the hit, no hiss / steam bunched)
--  6. clean     after the reveal, the pack closed mid-reveal, the opener dying mid-reveal: no scan part, steam, hiss or Mech object left
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local noop=function()end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
local Mixer=W.module('AudioMixer');Mixer.Start()
do -- Debris as on Roblox
 local queue={}
 W.service('Debris').AddItem=function(_,item,ttl)queue[#queue+1]={Item=item,At=R.clock+(tonumber(ttl)or 10)}end
 W.Run.Heartbeat:Connect(function()for i=#queue,1,-1 do if R.clock>=queue[i].At then local d=table.remove(queue,i);pcall(function()d.Item:Destroy()end)end end end)
end
local Players=W.service('Players')
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules');local M=W.module('RarePullCinematic')
local Fx=W.module('MechPackFx153');local Mech=W.module('MechCatalog');local IA=W.module('InteractionAudio')
local cam=W.workspace.CurrentCamera
-- the Mech seeds by rank (the Mech pack's own table: Legendary .. King)
local mechByRank={};for _,s in ipairs(Mech.Seeds)do local _,r=Rules.GetRarity(s.Id);if r and not mechByRank[r.Rank]then mechByRank[r.Rank]=s.Id end end
-- every Mech opening object made, and every update it ran: the exact t, and what the cues looked like after it
local opened={}
do
 local make=Fx.Opening
 Fx.Opening=function(copy,record)
  local o=make(copy,record)
  if o then
   o.Log={};opened[#opened+1]=o
   local up=o.Update
   o.Update=function(self,t,wr)
    up(self,t,wr)
    local e={T=t,Emitted=self.Emitted or 0,Hissed=self.Hissed or 0,Rung=self.Rung==true,Scan=false}
    for _,sc in ipairs(self.Scans)do if sc.Part.Transparency<1 then e.Scan=true;e.ScanColor=sc.Part.Color;e.ScanY=(self.Copy.PrimaryPart.CFrame:Inverse()*sc.Part.CFrame).Position.Y end end
    local g=self.Glow[1];e.Glow=g and g.Part.Color
    local b=self.Spin[1]
    if b then local rel=self.Copy.PrimaryPart.CFrame:Inverse()*b.Part.CFrame;local loc=b.Pivot:Inverse()*rel*b.Offset:Inverse();e.Spin=math.atan2(loc.RightVector.Y,loc.RightVector.X)end
    local bolt=self.Bolts[1];if bolt then local rel=self.Copy.PrimaryPart.CFrame:Inverse()*bolt.Part.CFrame;e.BoltOut=(rel.Position-bolt.Rest.Position).Magnitude end
    self.Log[#self.Log+1]=e
   end
  end
  return o
 end
end
-- other players
local others={}
function Players.GetPlayers()local out={X.player};for _,p in ipairs(others)do if p.Parent then out[#out+1]=p end end;return out end
function Players.GetPlayerFromCharacter(_,c)if c==X.char then return X.player end;for _,p in ipairs(others)do if p.Character==c then return p end end;return nil end
local function otherPlayer(name,x,z)
 local p=R.new('Player');p.Name=name;p.UserId=600+#others;p.Parent=Players;others[#others+1]=p
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace;p.Character=c
 local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(x,5,z);t.Parent=c
 local h=R.new('Part');h.Name='HumanoidRootPart';h.Size=V3(2,2,1);h.CFrame=CF(x,3,z);h.Parent=c
 local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.Parent=c
 return p,c
end
local onlooker,onlookerChar=otherPlayer('Onlooker',12,96)
-- the server
local MECHPACK={Stage=8,Variant='MechLimited'};local PLAIN={Stage=2,Variant='Pack06'}
local function serverBag(char,pack)
 local bag=Visuals.CarryBag(char,pack.Stage,pack.Variant,1,1,'None');bag:SetAttribute('PackClickCount',0);bag:SetAttribute('PackClicksRequired',Rules.OpenClicks);return bag
end
local function reveal(bag,seedId)
 local name=Rules.GetRarity(seedId)
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',name);bag:SetAttribute('RevealDuration',Rules.GetRevealDuration(name));bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
end
local function packTool(char,pack)
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='m'..math.floor(R.clock*1000),Stage=pack.Stage},nil);tool.Activated=R.signal();tool.Enabled=true;tool.Parent=char;return tool
end
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear()
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;X.lowFx=false;X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 R.advance(5) -- (no quick reveal: the last one ended long ago)
end
local function effects()return W.workspace:FindFirstChild('_LocalSeedPackEffects')end
local function leftovers()
 local n={}
 for _,d in ipairs(W.workspace:GetDescendants())do if d.Name=='MechScan'or d.Name=='MechSteam'or d.Name=='MechSteamPuff'or d.Name=='MechHiss'then n[#n+1]=d:GetFullName()end end
 return n
end
local function voices(name)local out={};for _,s in ipairs(E.sounds)do if s.Name==name then out[#out+1]=s end end;return out end
local function plays(name)local n=0;for _,s in ipairs(voices(name))do n+=s.Plays end;return n end
-- the scripts
local spc=R.new('LocalScript');spc.Name='SeedPackClient';assert(pcall(W.load,'SeedPackClient',spc))
local pof=R.new('LocalScript');pof.Name='PackOpeningFeedback';assert(pcall(W.load,'PackOpeningFeedback',pof))
W.frames(2,1/30)

-- 1. clicks ---------------------------------------------------------------------------------------------------------------------------------
local function clickCopy()return W.workspace:FindFirstChild('_LocalClickingPack')end
local function boltState(copy)
 -- per bolt index: how many of its 6 blocks (3 per face) sit backed out / at rest in the copy's own frame
 local out={};local s=copy:GetAttribute('VisualScale')or 1
 for _,p in ipairs(copy:GetDescendants())do local i=p:GetAttribute('MechBolt');if i and p:IsA('BasePart')then
  local rel=copy.PrimaryPart.CFrame:Inverse()*p.CFrame;local rest=p:GetAttribute('PackLocalFrame');local outF=Fx.BoltLocal(rest,p:GetAttribute('MechBoltPivot'),1,s)
  out[i]=out[i]or{Out=0,In=0}
  if(rel.Position-outF.Position).Magnitude<1e-4 and(rel.RightVector-outF.RightVector).Magnitude<1e-3 then out[i].Out+=1 elseif(rel.Position-rest.Position).Magnitude<1e-4 then out[i].In+=1 end
 end end
 return out
end
local function clicks(pack,calm)
 reset();E.resetPlays()
 W.Gui.ReducedMotionEnabled=calm=='reduced';X.lowFx=calm=='low'
 local tool=packTool(X.char,pack);local bag=serverBag(X.char,pack)
 local states={}
 for i=1,Rules.OpenClicks do bag:SetAttribute('PackClickCount',i);bag:SetAttribute('PackClickAt',W.workspace:GetServerTimeNow());X.run(.2);local c=clickCopy();states[i]=c and boltState(c)end
 local r={Mech=plays('Interaction_MechClick'),Bubble=plays('Interaction_Bubble04'),States=states,Bag=bag,Tool=tool}
 return r
end
do
 local r=clicks(MECHPACK)
 check(r.Mech==4 and r.Bubble==1,('Mech pack: clicks 1-4 tick (UpgradeClick), click 5 is Bubble04 (%d ticks, %d Bubble04)'):format(r.Mech,r.Bubble))
 local v=voices('Interaction_MechClick')[1];local b=voices('Interaction_Bubble04')[1]
 check(v and b and v.SoundId==IA.Asset('UpgradeClick')and near(v.Volume,b.Volume)and near(v.Volume,.20),'the tick is UpgradeClick\'s file at Bubble04\'s volume (.20)')
 local ok=true
 for i=1,4 do local st=r.States[i]
  for j=1,4 do local s=st and st[j];local want=j<=i
   if not s or(want and s.Out~=6)or(not want and s.In~=6)then ok=false;print(('  after click %d bolt %d: %s out / %s in'):format(i,j,tostring(s and s.Out),tostring(s and s.In)))end
  end
 end
 check(ok,'each of clicks 1-4 backs out one more corner bolt, on both faces (3 blocks each), turned and lifted on its own axis')
 check(r.States[5]and r.States[5][4]and r.States[5][4].Out==6,'click 5: all four bolts are out')
 local lights=0;local c=clickCopy();if c then for _,d in ipairs(c:GetDescendants())do if(d:IsA('Light')or d:IsA('ParticleEmitter'))and d.Enabled then lights+=1 end end end
 check(lights==0,'the clicking copy carries no live hum / sparks (the pack under it keeps its own)')
 r.Bag:Destroy();r.Tool:Destroy();X.run(.3)
 local p=clicks(PLAIN)
 check(p.Mech==0 and p.Bubble==5,('any other pack: five Bubble04 clicks, no tick (%d / %d)'):format(p.Bubble,p.Mech))
 p.Bag:Destroy();p.Tool:Destroy();X.run(.3)
 for _,calm in ipairs({'reduced','low'})do
  local q=clicks(MECHPACK,calm);local still=true
  for i=1,4 do local st=q.States[i];for j=1,4 do if not(st and st[j]and st[j].In==6)then still=false end end end
  check(still and q.Mech==4,calm..': the bolts do not move (no spinning bolts), the tick still sounds')
  q.Bag:Destroy();q.Tool:Destroy();X.run(.3)
 end
end

-- 2. the beats --------------------------------------------------------------------------------------------------------------------------------
-- an opening of `pack` by `who` (own / onlooker) with a seed of `rank`: clicks, the reveal, every frame at dt until the server ends it. Returns the opening's log.
local function open(rank,dt,opts)
 opts=opts or{}
 reset()
 if opts.InPlace then X.state=R.Enum.HumanoidStateType.Freefall end -- (R157: in the air, RarePullRules.Decide: Secret / Cosmic / King play the compact in-place card, not a story scene)
 if opts.Calm=='reduced'then W.Gui.ReducedMotionEnabled=true elseif opts.Calm=='low'then X.lowFx=true end
 local char=opts.Onlooker and onlookerChar or X.char
 local tool=packTool(char,opts.Pack or MECHPACK);local bag=serverBag(char,opts.Pack or MECHPACK)
 for i=1,Rules.OpenClicks do bag:SetAttribute('PackClickCount',i);X.run(.12,dt)end
 local before=#opened
 local seed=mechByRank[rank]or X.byRank[rank]
 reveal(bag,seed);local at=bag:GetAttribute('RevealAt')
 local dur=bag:GetAttribute('RevealDuration')
 local frames={}
 local stopAt=opts.CloseAt and at+opts.CloseAt or nil
 local function frame(now)
  if opts.SkipAt and not opts.Skipped and now-at>=opts.SkipAt then opts.Skipped=true;local ok,res=pcall(M.Skip);opts.SkipAnswer=ok and res;opts.SkipRun=M.Active()end
  if opts.DieAt and not opts.Died and now-at>=opts.DieAt then opts.Died=true;X.hum.Health=0;X.hum.Died:Fire()end
  if stopAt and now>=stopAt and bag.Parent then bag:Destroy()end
  -- every sound heard this frame (the director's and the Mech hiss): file position and gain
  local f={T=now-at,V={}}
  for _,s in ipairs(Y.sounds)do if s.IsPlaying and s.Parent and(s.Name:match('^RarePull_')or s.Name=='MechHiss')then
   f.V[#f.V+1]={Name=s.Name,Id=s.SoundId,Pos=Y.position(s),Gain=(tonumber(s.Volume)or 0)*((s.SoundGroup and tonumber(s.SoundGroup.Volume))or 1)}
  end end
  frames[#frames+1]=f
 end
 X.run(dur+.05,dt,frame)
 if bag.Parent then bag:Destroy()end;tool:Destroy()
 -- (a story scene's climax can come after the world pack's reveal: what is heard is recorded until the director is done)
 -- (R154: its result waits for the player: collected once it is up, the seed flies home)
 local Collect=W.module('SeedCollect154')
 local guard=0;while(M.Active()or Collect.Flying()>0)and guard<200 do local r=M.Active();if r and r.SawResult and not r.Collected and r.Clock()>=L.ShownAt(r.TL)+M.CollectAfter then M.Collect()end;X.run(.2,dt,frame);guard+=1 end
 X.run(.3,dt)
 local o=opened[#opened];if #opened==before then o=nil end
 if opts.Died then X.hum.Health=100 end
 if opts.InPlace then X.state=R.Enum.HumanoidStateType.Running end
 return o,frames,{At=at,Rank=rank,Quick=false,Seed=seed}
end
local function firstAt(log,pred)for _,e in ipairs(log)do if pred(e)then return e.T end end;return nil end
local function beats(o,tag,rank,calm)
 local quick=o.Quick==true -- (the world pack's own decision: SeedPackClient's record.Quick, which its wobble uses too)
 local B=o.BurstAt;local pulses=L.Pulses(rank,quick);local ticks=L.TearTicks(rank,quick);local slack=1/30+1e-6
 if not check(near(B,L.BurstAt(rank,quick))and #o.Pulses==#pulses and #o.Ticks==#ticks,tag..': the cues read the reveal\'s own beats (BurstAt, the pulses, the tear ticks): nothing is added or moved')then
  print(('  BurstAt %s / %s, pulses %d / %d, ticks %d / %d, first update %s'):format(tostring(B),tostring(L.BurstAt(rank,quick)),#o.Pulses,#pulses,#o.Ticks,#ticks,tostring(o.Log[1]and o.Log[1].T)))
 end
 local log=o.Log
 -- the scan line: a sweep on every pulse (the first update at or after it), in the hint colour of that update, top to bottom
 local okScan,okColor,okDir=true,true,true
 for i,p in ipairs(pulses)do
  local t0=firstAt(log,function(e)return e.T>=p-1e-9 end)
  local e0;for _,e in ipairs(log)do if e.T==t0 then e0=e end end
  local nextP=pulses[i+1]or B
  if calm then if e0 and e0.Scan then okScan=false end
  else
   if not(e0 and e0.Scan and t0-p<=slack)then okScan=false end
   if e0 and e0.Scan then local want=L.Hint(rank,math.clamp(e0.T/B,0,1));if not(e0.ScanColor==want or(e0.ScanColor.R==want.R and e0.ScanColor.G==want.G and e0.ScanColor.B==want.B))then okColor=false end end
   local ys={};for _,e in ipairs(log)do if e.T>=p and e.T<math.min(p+Fx.Scan.Seconds,nextP)and e.Scan then ys[#ys+1]=e.ScanY end end
   for k=2,#ys do if ys[k]>ys[k-1]+1e-6 then okDir=false end end
  end
 end
 local stray=false;for _,e in ipairs(log)do if e.Scan then local inWin=false;for _,p in ipairs(pulses)do if e.T>=p and e.T<p+Fx.Scan.Seconds then inWin=true end end;if not inWin or e.T>=B then stray=true end end end
 if calm then check(okScan and not stray,tag..': calm: no scan line sweeps (just the colour)')
 else
  check(okScan and not stray,tag..(': a scan line on each of the %d wobble pulses, within one update (1/30 s) of the pulse, and only then'):format(#pulses))
  check(okColor,tag..': the scan line is the R152 hint colour of its moment (RarePullRules.Hint, the seam glow\'s)')
  check(okDir,tag..': it sweeps the face from the top down')
 end
 -- the core / traces take the hint colour through the suspense (more on each pulse) and are back after the burst
 local tinted,back=0,true
 for _,e in ipairs(log)do
  if e.T>0 and e.T<B then local want=Fx.GlowMix(e.T,B,pulses);if want>.2 then tinted+=1 end end
  if e.T>B+Fx.Glow.After+.05 and e.Glow then local base=W.module('MechPackArt153').Colors.Cyan;if math.abs(e.Glow.R-base.R)+math.abs(e.Glow.G-base.G)+math.abs(e.Glow.B-base.B)>1e-6 then back=false end end
 end
 check(tinted>0 and back,tag..': the core and the traces flash in the hint colour on the pulses and are cyan again after the burst')
 -- steam + hiss on every tear group, the ring on the burst
 local okPuff,okHiss=true,true;local last=0;local lastH=0
 for i,tk in ipairs(ticks)do
  local t0=firstAt(log,function(e)return e.T>=tk-1e-9 end);local e0;for _,e in ipairs(log)do if e.T==t0 then e0=e end end
  if not e0 or t0-tk>slack then okPuff=false;okHiss=false
  else
   local wantPuff=calm and 0 or Fx.Steam.Puff
   if e0.Emitted-last~=wantPuff then okPuff=false end;last=e0.Emitted
   if e0.Hissed-lastH~=1 then okHiss=false end;lastH=e0.Hissed
  end
 end
 check(okPuff,tag..(calm and': calm: no steam'or(': a puff of steam on each of the %d tear groups, on the update of its tick'):format(#ticks)))
 check(okHiss,tag..(': the hiss on each tear group, on the update of its tick (%d)'):format(lastH))
 local tr=firstAt(log,function(e)return e.Rung end)
 if calm then check(tr==nil,tag..': calm: no steam ring')
 else check(tr and tr>=B-1e-9 and tr-B<=slack,tag..(': the steam ring on the burst (%.3f, BurstAt %.3f)'):format(tr or -1,B))end
 -- the turbine: faster through the suspense, spun down after the burst (the clock read back from a blade)
 if calm then
  local same=true;for _,e in ipairs(log)do if e.Spin and math.abs(e.Spin-log[1].Spin)>1e-6 then same=false end end
  check(same,tag..': calm: the turbine stands still')
 else
  local rate=o.Spin[1].Rate;local okT=true;local mid,late=0,0
  for k=2,#log do local a,b=log[k-1],log[k]
   local want=(Fx.TurbineClock(b.T,B)-Fx.TurbineClock(a.T,B))*rate
   local got=(b.Spin-a.Spin+math.pi)%(2*math.pi)-math.pi
   if math.abs(got-want)>1e-3 then okT=false end
   local w=want/(b.T-a.T)
   if b.T>B*.8 and b.T<B then mid=math.max(mid,math.abs(w))end
   if b.T>B+1.4 then late=math.max(late,math.abs(w))end
  end
  check(okT,tag..': the turbine turns by the reveal\'s clock (every update, to 1e-3 rad)')
  check(mid>2*math.abs(rate)and late<.1*mid,tag..(': it spins up through the suspense (%.1f rad/s) and down after the burst (%.2f rad/s 1.4 s later)'):format(mid,late))
 end
 -- the bolts are out
 local outOk=true;for _,e in ipairs(log)do if e.T>Fx.Bolt.Seconds+.05 and e.BoltOut then local want=calm and 0 or Fx.Bolt.Lift*(o.Scale or 1);if math.abs(e.BoltOut-want)>1e-3 then outOk=false end end end
 check(outOk,tag..(calm and': calm: the bolts stay in'or': the bolts stay backed out through the opening'))
 return log
end
local function voicesCheck(frames,tag)
 local hit,whoosh,mix,mechMax,total=-99,-99,-99,0,0
 for _,f in ipairs(frames)do
  local e,mech=0,0
  for _,v in ipairs(f.V)do
   local lv=Y.voiceLoudness(v)
   e+=10^(lv/10)
   if v.Name=='MechHiss'then mech+=1;whoosh=math.max(whoosh,lv)end
   local slot=v.Name:match('^RarePull_(.-)_%d+b?$')
   if slot=='Impact'or slot=='GroundImpact'or slot=='PackBurst'or slot=='CosmicBoom'then hit=math.max(hit,lv)end
  end
  mechMax=math.max(mechMax,mech);total=math.max(total,#f.V)
  if e>0 then mix=math.max(mix,10*math.log10(e))end
 end
 check(mechMax>=1 and mechMax<=2,tag..(': the Mech touch adds at most 2 voices at once (%d)'):format(mechMax))
 check(whoosh<=-30 and whoosh<=hit-8,tag..(': the hiss is %.1f LUFS at its loudest: under the -30 whoosh cap and 8 dB under the hit (%.1f)'):format(whoosh,hit))
 check(mix<=-18,tag..(': the whole mix with it stays <= -18 LUFS (%.1f)'):format(mix))
 check(total<=10,tag..(': at most 10 voices (%d)'):format(total))
 return whoosh,hit,mix
end
local logs={}
for _,dt in ipairs({1/30,1/60})do
 local tag=('own Mythic at %d fps'):format(math.floor(1/dt+.5))
 local o,frames=open(5,dt)
 if check(o~=nil,tag..': the Mech pack\'s opening has its Mech touch')then
  logs[dt]=beats(o,tag,5,false)
  local w,h,m=voicesCheck(frames,tag)
  if dt==1/60 then print(('sound: the hiss at most %.1f LUFS, the hit %.1f, the mix %.1f'):format(w,h,m))end
  check(o.Destroyed==true,tag..': the Mech touch is gone with the reveal');local l=leftovers();check(#l==0,tag..': nothing left ('..table.concat(l,', ')..')')
 end
end
-- (the updates on which a puff / hiss / ring fired)
local function cues(log)local c={};local lastE,lastH,rung=0,0,false
 for _,e in ipairs(log)do if e.Emitted~=lastE or e.Hissed~=lastH or(e.Rung and not rung)then c[#c+1]=e.T;lastE,lastH,rung=e.Emitted,e.Hissed,e.Rung end end;return c end
local function sameCues(a,b)
 local ca,cb=cues(a),cues(b);local ok=#ca==#cb
 for i=1,math.min(#ca,#cb)do if math.abs(ca[i]-cb[i])>1/30+1e-6 then ok=false end end
 return ok,#ca
end
do -- the same cues at 30 and 60 fps (each within one reveal update of the other)
 local a,b=logs[1/30],logs[1/60]
 if a and b then
  local ok,n=sameCues(a,b)
  check(ok,('the steam / hiss / ring cues fire on the same beats at 30 and 60 fps (%d cues)'):format(n))
 end
end
for _,rank in ipairs({4,6,7,8})do
 local o,frames=open(rank,1/30)
 local tag='own '..({[4]='Legendary',[6]='Secret',[7]='Cosmic',[8]='King'})[rank]
 if check(o~=nil,tag..': the Mech touch plays')then beats(o,tag,rank,false);voicesCheck(frames,tag)end
end

-- 4. calm -------------------------------------------------------------------------------------------------------------------------------------
for _,calm in ipairs({'reduced','low'})do
 local o=open(5,1/30,{Calm=calm})
 if check(o~=nil,calm..': the Mech touch still runs (the colour)')then beats(o,calm,5,true)end
end

-- 5. others ---------------------------------------------------------------------------------------------------------------------------------
do
 local o=open(5,1/30,{Onlooker=true})
 if check(o~=nil and not o.Mine,'an onlooker\'s client draws the Mech touch on someone else\'s pack')then
  beats(o,'onlooker Mythic',5,false)
  local early=o.Log[1];check(early and early.BoltOut and early.BoltOut<Fx.Bolt.Lift*.999,'an onlooker sees the bolts come out in the reveal\'s first moment (they never saw the clicks)')
 end
 local s=open(6,1/30,{SkipAt=2.0})
 if check(s~=nil and M.Active()==nil,'a Secret story scene skipped: the world pack goes on')then beats(s,'Secret skipped',6,false)end
 local p=open(5,1/30,{Pack=PLAIN})
 check(p==nil,'any other pack: no Mech touch')
end
-- 5b. R157: SKIP only for Secret / Cosmic / King (owner: "the skip button only appears for secret and above", docs/proposals/R156/reveal_fixes.md, R157/hud157.md item 2).
-- Common..Mythic have no SkipFrom: RarePullCinematic.Skip (the SKIP button's press, Enter / B / R2) answers false before the result shows and the world pack's clock is
-- never jumped (RarePullRules.SetShift is not called); once the result shows a click / tap / Enter / B / R2 only COLLECTS it (open() collects with M.Collect). Secret / Cosmic /
-- King keep their SKIP: in place (the compact card: a keeper near, in the air, "Skip pack animations" ...) it jumps the card to the hit and hands the same seconds to the
-- opener's world pack, which the Mech touch reads (the story scene is never shifted: 5, "a Secret story scene skipped").
do -- 5b-1. a Mythic Mech card, a skip request at .5 s: ignored, the whole touch plays in order, nothing skipped
 local opts={SkipAt=.5}
 local o,frames=open(5,1/30,opts)
 local tag='Mythic, skip request at .5 s'
 if check(o~=nil,tag..': the Mech touch plays')then
  local log=o.Log;local B=o.BurstAt;local last=log[#log]
  check(opts.SkipRun~=nil and opts.SkipRun.Kind=='Ladder'and opts.SkipAnswer==false and not opts.SkipRun.Skipped and M.Active()==nil,
   tag..': R157: Common..Mythic have no SkipFrom: the skip (button / Enter / B / R2) answers false, skips nothing, and the card still ends by being collected')
  local step,at=0,0;for k=2,#log do if log[k].T-log[k-1].T>step then step=log[k].T-log[k-1].T;at=log[k].T end end
  check(step<=.3,('%s: the world pack\'s clock is not jumped (no update moves on by more than .3 s: the largest is %.3f s at %.2f)'):format(tag,step,at))
  -- the whole touch plays in order, as when nobody asked to skip: every pulse / tear group / the ring on the burst, the turbine, the bolts (beats), and the same cues as the plain Mythic above
  beats(o,tag,5,false)
  check(last.Hissed==#o.Ticks and last.Emitted==#o.Ticks*Fx.Steam.Puff+Fx.Steam.Ring,
   ('%s: every tear group hisses and steams once (%d hiss, %d groups) and the ring comes once (%d puffs)'):format(tag,last.Hissed,#o.Ticks,last.Emitted))
  local tr=firstAt(log,function(e)return e.Rung end)
  check(tr and tr>=B-1e-9 and tr-B<=1/30+1e-6,('%s: the steam ring on the burst (%.3f, BurstAt %.3f)'):format(tag,tr or -1,B))
  local stray=false;for _,e in ipairs(log)do if e.Scan and e.T>=B then stray=true end end
  check(not stray,tag..': no scan line after the burst')
  local ref=logs[1/30];local same,n=false,0;if ref then same,n=sameCues(ref,log)end
  check(same and n>0,('%s: the cues fire on the same beats as the plain Mythic opening\'s at 30 fps (%d cues: the request changed nothing)'):format(tag,n))
 end
 voicesCheck(frames,'Mythic skip ignored')
 check(o~=nil and o.Destroyed==true and #leftovers()==0,'Mythic skip ignored: the Mech touch is gone with the reveal, nothing left')
end
-- 5b-2. Secret / Cosmic / King in place (the compact card keeps its SKIP): the jump to the hit shifts the world pack's clock, the Mech touch reads that t
for _,rank in ipairs({6,7,8})do
 local opts={SkipAt=.5,InPlace=true}
 local o,frames=open(rank,1/30,opts)
 local tag=({[6]='Secret',[7]='Cosmic',[8]='King'})[rank]..' in place, skipped at .5 s'
 if check(o~=nil,tag..': the Mech touch plays')then
  local log=o.Log;local B=o.BurstAt;local jump
  check(opts.SkipRun~=nil and opts.SkipRun.Kind=='InPlace'and opts.SkipAnswer==true and opts.SkipRun.Skipped==1,tag..': R157: the compact card keeps its SKIP (the card is the in-place one, the skip is taken)')
  for k=2,#log do if log[k].T-log[k-1].T>.3 then jump=k;break end end
  if check(jump~=nil,tag..': the skip jumps the world pack\'s clock (one update moves on by more than .3 s)')then
   -- (a group jumped by more than Steam.Grace stays silent, like a tick that reaches the client late; one within it plays late, from its own point)
   local a,b=log[jump-1],log[jump];local passed,late=0,0;for _,tk in ipairs(o.Ticks)do if tk>a.T and tk<=b.T then passed+=1;if b.T-tk<=Fx.Steam.Grace then late+=1 end end end
   local ring=(b.Rung and not a.Rung)and Fx.Steam.Ring or 0 -- (the jump can land on the burst itself: its ring is the burst's)
   check(passed>0 and late<=1 and b.Hissed-a.Hissed==late and b.Emitted-a.Emitted==late*Fx.Steam.Puff+ring,
    ('%s: the tear groups jumped over (%d) stay silent, but one under %.2f s late (%d): no hiss / steam bunched on the skip (%d hiss)'):format(tag,passed,Fx.Steam.Grace,late,b.Hissed-a.Hissed))
   local tr=firstAt(log,function(e)return e.Rung end)
   check(tr and tr>=B-1e-9 and tr-B<=1/30+1e-6,('%s: the steam ring still comes on the (earlier) burst (%.3f, BurstAt %.3f)'):format(tag,tr or -1,B))
   local stray=false;for k=jump,#log do if log[k].Scan and log[k].T>=B then stray=true end end
   check(not stray,tag..': no scan line after the burst')
  end
  voicesCheck(frames,tag)
  check(o.Destroyed==true and #leftovers()==0,tag..': the Mech touch is gone with the reveal, nothing left')
 end
end

-- 6. clean ------------------------------------------------------------------------------------------------------------------------------------
do
 local o=open(5,1/30,{CloseAt=.5})
 check(o and o.Destroyed==true and #leftovers()==0,'the pack closed mid-reveal: the Mech touch is gone, nothing left')
 local d=open(5,1/30,{DieAt=.7})
 check(d and d.Destroyed==true and #leftovers()==0,'the opener dies mid-reveal: the Mech touch is gone, nothing left')
 local hiss=0;for _,s in ipairs(Y.sounds)do if s.Name=='MechHiss'and s.Parent and s.IsPlaying then hiss+=1 end end
 check(hiss==0,'no hiss is left playing')
 spc:Destroy();pof:Destroy();W.frames(2,1/30)
 local l=leftovers();check(#l==0,'the scripts destroyed: nothing of the Mech touch left ('..#l..')')
end
print(('%d Mech openings driven'):format(#opened))
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
