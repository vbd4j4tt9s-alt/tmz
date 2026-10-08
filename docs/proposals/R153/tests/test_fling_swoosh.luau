--!nocheck
-- R153 fling swoosh (owner: "102531686500130 this fast swoosh sound effect also plays when players get hit and fly through the air"):
-- the REAL FlingSwoosh153 module + client script, with the REAL KeeperHitEffects beside it (its impact sound must come first), AudioMixer,
-- SoundTiming and LocalSfx on the Roblox mock. A packet is what the server sends on a keeper's accepted knockback (ChaseService:_applyGuardianFling).
--  1. config: the id, Volume under the cap and under every hit, the cap 8 dB under the impact
--  2. a keeper launch: once, id, Effects group, volume, 2D for the flung player, after the impact, swell on the fastest moment
--  3. everyone else: 3D from the flung body (travels with it), roll-off, in range only, a streamed-out body falls back to a point; never both
--  4. lead-in (SoundTiming / Start), late packets, a cold file, the Studio attributes, the volume cap holding
--  5. NOT a jump, the trampoline, a track-hole fall, a bat hit, lightning, a stale or malformed packet
--  6. the voice cap (many players flung at once), the same player twice, the Effects slider
local W=require('./world');local E=require('./sfx_env')(W);local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
-- time moves in 2 ms steps: the mock runs a delayed call at the END of the step that reaches it, so coarse steps would blur the timing checks
local function adv(s)local n=math.max(1,math.floor(s/.002+.5));for _=1,n do R.advance(s/n)end end
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(e or 1e-6)end
local RS=W.RS;local Players=W.service('Players');local SS=W.service('SoundService')
E.player('Me');local me,pg=E.Player,E.pg
function Players.GetPlayerByUserId(_,uid)for _,p in ipairs(Players:GetPlayers())do if p.UserId==uid then return p end end;return nil end
local ID='rbxassetid://102531686500130';local SNAP='rbxassetid://138131702183716'
-- the world the packet travels in: the remotes folder with the KeeperHit event (and a TrackHole one for the fall) ------------------------------
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local hitRemote=R.Instance.new('RemoteEvent');hitRemote.Name='KeeperHit';hitRemote.Parent=remotes
local holeRemote=R.Instance.new('RemoteEvent');holeRemote.Name='TrackHole';holeRemote.Parent=remotes
local trampolineRemote=R.Instance.new('RemoteEvent');trampolineRemote.Name='Trampoline';trampolineRemote.Parent=remotes
W.workspace.CurrentCamera.CFrame=CF(0,10,-20)
local Swoosh=W.module('FlingSwoosh153');local Mixer=W.module('AudioMixer');local Timing=W.module('SoundTiming');local Audio=W.module('KeeperAudio')
local KFx=W.module('KeeperFx');local Bat=W.module('BatConfig')
Mixer.Start()
-- scripts: KeeperHitEffects (the impact sound), then the swoosh script (the bundle names it FlingSwoosh153Client: the module keeps FlingSwoosh153) -------------------------------------------------------------------------
W.load('KeeperHitEffects',R.new('LocalScript'))
local script153=R.new('LocalScript');W.load('FlingSwoosh153Client',script153)
-- helpers -------------------------------------------------------------------------------------------------------------------------------------
local serial=0
local function packet(t)serial+=1;t.Id=t.Id or serial;if t.At==nil then t.At=W.workspace:GetServerTimeNow()end;return t end
local function keeperHit(victim,pos,stage,extra)local t={Position=pos or V3(0,3,0),Stage=stage or 2,VictimUserId=victim or 7,Direction=V3(0,0,1)};for k,v in pairs(extra or{})do t[k]=v end;return packet(t)end
local function fire(t)hitRemote.OnClientEvent:Fire(t)end
local function swooshes()return E.named('KeeperFlingSwoosh')end
local function played()local n=0;for _,s in ipairs(swooshes())do n+=s.Plays end;return n end
local function live()local n=0;for _,s in ipairs(swooshes())do if s.Parent~=nil then n+=1 end end;return n end
local function reset()Swoosh.Clear();for _,s in ipairs(E.sounds)do if s.Parent~=nil and(s.Name=='KeeperFlingSwoosh'or s.Name=='ChestChaseOneShot')then s:Destroy()end end;E.resetPlays();table.clear(E.sounds);adv(2) end
local function other(name,uid,pos)
 local p=R.new('Player');p.Name=name;p.UserId=uid;p.Parent=Players
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace;p.Character=c
 local r=R.new('Part');r.Name='HumanoidRootPart';r.CFrame=CF(pos.X,pos.Y,pos.Z);r.Parent=c
 return p,r
end
local EFFECTS=Mixer.Group('Effects')

-- 1. config ---------------------------------------------------------------------------------------------------------------------------------
do
 check(Swoosh.Id==ID,'the owner\'s file 102531686500130')
 check(Swoosh.Volume>0 and Swoosh.Volume<=Swoosh.MaxVolume,'Volume is within its own cap')
 check(Swoosh.MaxVolume<=Audio.ImpactVolume*10^(-8/20)+1e-9,'the cap is 8 dB under the generic impact (R152 whoosh rule)')
 check(Swoosh.Volume<Audio.ImpactVolume and Swoosh.Volume<KFx.GroundSound.Volume and Swoosh.Volume<.5 and Swoosh.Volume<Bat.SlapVolume,'quieter than the impact, the ground slam, the Darkened catch (.5) and the bat slap')
 check(Swoosh.MaxVoices>=1 and Swoosh.MaxVoices<=6,'a small voice cap ('..tostring(Swoosh.MaxVoices)..')')
 check(Swoosh.MinGap>0 and Swoosh.Swell>0 and Swoosh.PeakAfter>0 and Swoosh.RollMax>Swoosh.RollMin,'timing and roll-off values exist')
 check(Swoosh.Start==nil,'Start left nil: the lead-in is SoundTiming\'s (Start_102531686500130 / table), 0 until measured')
 check(Timing.Starts['102531686500130']==nil,'SoundTiming has no invented lead-in for the file (unmeasured)')
end

-- 2. a keeper launch on the local player ---------------------------------------------------------------------------------------------------------
do
 reset();local t0=R.clock
 fire(keeperHit(7,V3(0,3,0),2))
 check(played()==0 and #swooshes()==1,'the swoosh is made at the packet but waits for its moment (after the impact)')
 adv(.01);check(played()==0,'...not yet playing .01 s later (MinGap '..Swoosh.MinGap..')')
 adv(.3)
 local s=swooshes()
 check(#s==1 and s[1].Plays==1,'a keeper launch plays the swoosh exactly once')
 local sw=s[1]
 check(sw and sw.SoundId==ID,'the right id')
 check(sw and sw.SoundGroup==EFFECTS and EFFECTS.Name=='GardenEffects','Effects group (the Effects slider)')
 check(sw and sw.Volume>0 and sw.Volume<=Swoosh.MaxVolume and sw.Volume<Audio.ImpactVolume,'volume under the cap and under the impact: '..tostring(sw and sw.Volume))
 check(sw and sw.Parent==SS,'the flung player hears it 2D (SoundService, no body)')
 local impact=E.named('ChestChaseOneShot',SNAP)
 check(#impact==1 and impact[1].Plays==1,'the existing impact sound still plays once')
 local ia,sa=impact[1] and impact[1].PlayLog[1].At,sw and sw.PlayLog[1].At
 check(ia and sa and sa>ia+Swoosh.MinGap-1e-9,'the swoosh starts after the impact (by at least MinGap): impact '..tostring(ia)..' swoosh '..tostring(sa))
 local log=sw.PlayLog[1]
 check(near(log.At-t0+(Swoosh.Swell-log.TimePosition)/log.Speed,Swoosh.PeakAfter,.003),'its Swell lands on PeakAfter (the fastest moment after the launch)')
 check(log.TimePosition>=0 and log.Speed==1,'file position and speed')
 check(Swoosh.Voices()==0 or Swoosh.Voices()==1,'(voice count is sane)')
 adv(.7);fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 check(played()==2,'a later launch (after the cooldown) plays again: '..played())
end

-- 3. everyone else: 3D from the flung body ----------------------------------------------------------------------------------------------------
do
 reset()
 local p,root=other('Ann',99,V3(10,3,20))
 fire(keeperHit(99,V3(10,3,20),3));adv(.3)
 local s=swooshes()
 check(#s==1 and s[1].Plays==1,'someone else flung: one swoosh')
 local sw=s[1]
 check(sw and sw.Parent==root,'3D: the Sound sits in the flung player\'s HumanoidRootPart (it travels with the body)')
 check(sw and sw.RollOffMode==R.Enum.RollOffMode.InverseTapered and sw.RollOffMaxDistance>sw.RollOffMinDistance and sw.RollOffMaxDistance<=260,'with roll-off')
 check(sw and sw.SoundGroup==EFFECTS and sw.SoundId==ID,'Effects group, right id')
 check(sw and sw.Volume<=Swoosh.MaxVolume,'under the cap')
 local two=0;for _,x in ipairs(swooshes())do if x.Parent==SS then two+=1 end end
 check(two==0,'nobody gets a 2D copy of someone else\'s launch')
 root.CFrame=CF(300,50,20)
 check(sw.Parent==root and sw:IsDescendantOf(W.workspace),'(the body moves, the sound stays on it)')
 -- the flung player herself: exactly one voice and it is the 2D one, however the packet arrives
 reset();fire(keeperHit(7,V3(0,3,0),4));adv(.3)
 local s2=swooshes();local twoD,threeD=0,0
 for _,x in ipairs(s2)do if x.Parent==SS then twoD+=1 else threeD+=1 end end
 check(#s2==1 and twoD==1 and threeD==0,'the flung player: one 2D voice and no 3D one (no double play)')
 -- the same packet twice (a re-send) is one swoosh
 reset();local t=keeperHit(7,V3(0,3,0),4);fire(t);fire(t);adv(.3)
 check(#swooshes()==1 and played()==1,'the same packet twice is one swoosh')
 -- range: far from the camera nobody else hears it; the flung player always does
 reset();local _,far=other('Far',98,V3(0,3,900))
 fire(keeperHit(98,V3(0,3,900),2));adv(.3)
 check(#swooshes()==0,'a launch farther than MaxStuds from the camera is not heard by others')
 reset();fire(keeperHit(7,V3(0,3,900),2));adv(.3)
 check(played()==1,'...but the flung player hears hers wherever the camera is')
 -- a body that is not streamed in: a point at the hit
 reset();fire(keeperHit(555,V3(5,3,5),2));adv(.3)
 local s3=swooshes()
 check(#s3==1 and s3[1].Parent and s3[1].Parent.Name=='ChestChaseSfx' and near(s3[1].Parent.Position.X,5),'a player not streamed in: a 3D point where the hit landed')
 check(s3[1] and s3[1].Plays==1,'...and it plays once')
end

-- 4. lead-in, late packets, cold file, Studio attributes --------------------------------------------------------------------------------------------
do
 -- Plan: pure numbers
 local w,e=Swoosh.Plan(0,0)
 check(w>=Swoosh.MinGap-1e-9 and e>=0,'Plan: never before MinGap, never before the lead-in')
 check(near(w+(Swoosh.Swell-e),Swoosh.PeakAfter),'Plan: the swell lands on PeakAfter')
 local w2,e2=Swoosh.Plan(.2,0);check(w2==0 and e2>e,'a packet .2 s late starts at once and joins further into the file ('..e2..' > '..e..')')
 local w3,e3=Swoosh.Plan(0,.1);check(e3>=.1 and near(w3+(Swoosh.Swell-e3),Swoosh.PeakAfter),'a measured lead-in of .1 s: entered at or after it, swell still on the peak')
 reset();local before=Swoosh.Plan
 -- SoundTiming's attribute is the lead-in when Start is nil (R150's one place)
 RS:FindFirstChild('SoundTiming'):SetAttribute('Start_102531686500130',.15)
 fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 local sw=swooshes()[1]
 check(sw and sw.PlayLog[1].TimePosition>=.15-1e-9,'the file is entered at or after SoundTiming\'s lead-in (Start_102531686500130 = .15): '..tostring(sw and sw.PlayLog[1].TimePosition))
 RS:FindFirstChild('SoundTiming'):SetAttribute('Start_102531686500130',nil)
 -- the module's own Start (attribute on FlingSwoosh153) wins
 reset();local mod=RS:FindFirstChild('FlingSwoosh153');mod:SetAttribute('Start',.3)
 fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 sw=swooshes()[1];check(sw and sw.PlayLog[1].TimePosition>=.3-1e-9,'a Start on FlingSwoosh153 is the lead-in: '..tostring(sw and sw.PlayLog[1].TimePosition))
 mod:SetAttribute('Start',nil)
 -- Volume: attribute wins, but never past the cap
 reset();mod:SetAttribute('Volume',.1);fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 sw=swooshes()[1];check(sw and near(sw.Volume,.1),'a Volume attribute sets the volume')
 reset();mod:SetAttribute('Volume',.9);fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 sw=swooshes()[1];check(sw and sw.Volume<=Swoosh.MaxVolume+1e-9,'...but never past MaxVolume ('..tostring(sw and sw.Volume)..')')
 mod:SetAttribute('Volume',nil)
 -- a late packet
 reset();fire(keeperHit(7,V3(0,3,0),2,{At=W.workspace:GetServerTimeNow()-.2}));adv(.05)
 sw=swooshes()[1];check(sw and sw.Plays==1 and sw.PlayLog[1].TimePosition>Swoosh.Swell-1e-9,'a packet .2 s late: plays at once, joined past the swell')
 reset();fire(keeperHit(7,V3(0,3,0),2,{At=W.workspace:GetServerTimeNow()-Swoosh.MaxAge-.05}));adv(.5)
 check(#swooshes()==0,'a packet older than MaxAge makes no swoosh (the body is already flying)')
 -- a cold file: played if it arrives within ColdAge, dropped after
 reset();E.cold[ID]=true;fire(keeperHit(7,V3(0,3,0),2));adv(.1)
 sw=swooshes()[1];check(sw and sw.IsLoaded==false,'(the cold file is not loaded)')
 adv(.05);E.load(sw);check((sw.Stops or 0)==0 and sw.IsPlaying,'a cold file that arrives soon after its start still plays')
 reset();fire(keeperHit(7,V3(0,3,0),2));adv(.04+Swoosh.ColdAge+.1)
 sw=swooshes()[1];E.load(sw);check((sw.Stops or 0)>=1 and not sw.IsPlaying,'a cold file that arrives later than ColdAge is dropped, never played late')
 E.cold[ID]=nil
end

-- 5. what must NOT swoosh -------------------------------------------------------------------------------------------------------------------------
do
 reset()
 -- a jump: humanoid jumps, the root rises
 E.hum.Jump=true;E.root.AssemblyLinearVelocity=V3(0,50,0);E.root.CFrame=CF(0,9,100);E.hum:SetAttribute('Jumping',true);W.frames(40)
 check(#swooshes()==0,'a jump makes no swoosh')
 -- the track hole's fall: the server ragdolls you (cause Hole): attributes flip, a launch velocity, the TrackHole remote; no KeeperHit packet exists
 E.char:SetAttribute('ChestChaseRagdollActive',true);me:SetAttribute('GuardianRagdollActive',true);me:SetAttribute('GuardianFlingActive',true)
 E.root.AssemblyLinearVelocity=V3(30,70,10);holeRemote.OnClientEvent:Fire({Kind='Fall',Position=V3(0,3,0),UserId=7});W.frames(40)
 check(#swooshes()==0,'a track-hole fall (ragdoll attributes, launch velocity, the TrackHole remote) makes no swoosh')
 E.char:SetAttribute('ChestChaseRagdollActive',false);me:SetAttribute('GuardianRagdollActive',false);me:SetAttribute('GuardianFlingActive',false)
 -- the trampoline (another agent's): a bounce velocity, its own remote, an attribute, and even a packet on the hit channel with a Cause
 E.root.AssemblyLinearVelocity=V3(0,120,0);E.char:SetAttribute('Trampoline',true);trampolineRemote.OnClientEvent:Fire({Position=V3(0,3,0),UserId=7});W.frames(40)
 check(#swooshes()==0,'a trampoline bounce (velocity, attribute, its own remote) makes no swoosh')
 fire(packet({Position=V3(0,3,0),VictimUserId=7,Cause='Trampoline'}));fire(packet({Position=V3(0,3,0),VictimUserId=7,Cause='Trampoline',Stage=3}));adv(.5)
 check(#swooshes()==0,'a hit-channel packet with another Cause (Trampoline) makes no swoosh, with or without a Stage')
 fire(packet({Position=V3(0,3,0),VictimUserId=7}));adv(.5)
 check(#swooshes()==0,'a packet with no keeper Stage makes no swoosh')
 -- a bat hit and lightning (other launches)
 fire(packet({Position=V3(0,3,0),VictimUserId=7,Cause='Bat',Direction=V3(0,0,1)}));fire(packet({Position=V3(0,3,0),VictimUserId=7,Cause='Lightning',Stage=2}));adv(.5)
 check(#swooshes()==0,'a bat hit and lightning are not keeper launches')
 -- malformed / stale packets do not error and make nothing (each is a newer Id than the one before it, so none is dropped by the Id rule)
 local function bad(t)serial+=1;t.Id=serial;return t end
 for _,t in ipairs({{Id='x'},{Stage=2},{Stage=2,VictimUserId=7},{Stage=2,VictimUserId=7,Position=V3(0,3,0)},{Stage=2,VictimUserId='7',Position=V3(0,3,0),At=R.clock},{Stage=2,VictimUserId=7,Position=V3(0,3,0),At=R.clock-5}})do
  fire(bad(t))
 end
 fire('nonsense');fire(nil);fire(42)
 adv(.5);check(#swooshes()==0,'malformed and stale packets make nothing (and do not error)')
 -- an out-of-order older packet is ignored (the same Id rule as the impact script)
 local newer=keeperHit(7,V3(0,3,0),2);local older=keeperHit(7,V3(0,3,0),2);older.Id=newer.Id-1
 fire(newer);adv(.3);local n=played();adv(1);fire(older);adv(.3)
 check(n==1 and played()==1,'an out-of-order older packet is dropped')
 -- and the real keeper packet right after all of the above still works
 reset();fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 check(played()==1,'(after all that, a real keeper launch still swooshes once)')
end

-- 6. voice cap, repeats, the Effects slider -----------------------------------------------------------------------------------------------------
do
 reset();local roots={}
 for i=1,12 do local _,r=other('P'..i,200+i,V3(i*3,3,10));roots[i]=r end
 for i=1,12 do fire(keeperHit(200+i,V3(i*3,3,10),(i%7)+1))end
 check(live()<=Swoosh.MaxVoices and live()==Swoosh.MaxVoices,'12 players flung in one frame: exactly MaxVoices ('..Swoosh.MaxVoices..') swooshes made ('..live()..')')
 adv(.3);local playing=0;for _,s in ipairs(swooshes())do if s.Parent and s.IsPlaying then playing+=1 end end
 check(playing==Swoosh.MaxVoices,'and that many are sounding: '..playing)
 -- yours always sounds: the oldest of someone else's gives way
 fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 local mine=0;for _,s in ipairs(swooshes())do if s.Parent==SS and s.Plays==1 then mine+=1 end end
 check(mine==1,'the flung local player still gets her swoosh when the voices are full')
 check(live()==Swoosh.MaxVoices,'...and the total stays at the cap ('..live()..')')
 -- voices free up
 adv(5);check(Swoosh.Voices()==0,'after the swooshes end, the voices are free')
 reset();for i=1,3 do fire(keeperHit(200+i,V3(i*3,3,10),2))end;adv(.3)
 check(live()==3 and played()==3,'below the cap every launch swooshes')
 -- a stress: 40 launches over 2 s, never more than the cap alive
 reset();local peak=0;local uid=300
 for step=1,40 do
  uid+=1;other('S'..uid,uid,V3((step%9)*4,3,10));fire(keeperHit(uid,V3((step%9)*4,3,10),(step%7)+1));adv(.05)
  peak=math.max(peak,live())
 end
 check(peak<=Swoosh.MaxVoices,'40 launches over 2 s: never more than MaxVoices alive (peak '..peak..')')
 check(peak>=2,'(and several were really sounding)')
 -- the same player twice in quick succession: one swoosh; after the cooldown, another
 reset();local _,rr=other('Twice',400,V3(0,3,10))
 fire(keeperHit(400,V3(0,3,10),2));adv(.2);fire(keeperHit(400,V3(0,3,10),2));adv(.3)
 check(played()==1,'the same player twice within the cooldown: one swoosh')
 adv(Swoosh.Cooldown);fire(keeperHit(400,V3(0,3,10),2));adv(.3)
 check(played()==2,'after the cooldown: another')
 -- the Effects slider mutes it
 reset();Mixer.Set('Effects',0)
 fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 check(#swooshes()==0,'Effects at 0: no swoosh is even made')
 Mixer.Set('Effects',55);adv(1);fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 local sw=swooshes()[1];check(sw and sw.SoundGroup==EFFECTS and near(EFFECTS.Volume,.55),'Effects at 55: it plays on the Effects group at 55% ('..tostring(EFFECTS.Volume)..')')
 Mixer.Set('Effects',100)
 -- the script's own clean-up
 script153.Destroying:Fire();reset();fire(keeperHit(7,V3(0,3,0),2));adv(.3)
 check(played()==0,'after the client script is destroyed nothing is listening')
end

print(('R153 fling swoosh: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
