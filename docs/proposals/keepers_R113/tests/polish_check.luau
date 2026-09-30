--!nocheck
-- KeeperPolish adds nothing inside the server contact window, and its strike fade-in ends before impact.
local W=require('./world');local Mx=W.Mx;local CF,V=Mx.CFrame,Mx.Vector3.new
local world=W.new(require('./bundle_new'),{})
local P=world.require('KeeperPolish');local Strike=world.require('KeeperStrikeFrames');local Pose=world.require('BeastPose');local C=world.require('KeeperCombat')
local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local function same(a,b)for g,f in pairs(a)do if b[g]~=f then return false end end;for g in pairs(b)do if a[g]==nil then return false end end;return true end
math.randomseed(7)
for stage=1,7 do
 local Wd=C.Get(stage).Windup
 for trial=1,40 do
  local s=P.new();local now=50;local seenLate=math.random()*Wd*1.2 -- when this client first sees the attack
  local frame=CF.new(0,4,0)
  -- a chase before the attack, with wake + taunt timers live and a look target
  for i=1,30 do now+=1/60
   Pose.Frames(stage,now,1,1,now*6,1,90,0)
   P.Apply(s,stage,Pose.Frames(stage,now,1,1,now*6,1,90,.3),{Now=now,Dt=1/60,Awake=1,Moving=1,Speed=90+i,Frame=frame*CF.Angles(0,i*.03,0),Look=V(10,4,-30),WakeAt=now-.5,TauntAt=now-.2})
  end
  local at=now-seenLate+1/60;local maxIn=0
  for i=0,60 do
   now=at+seenLate+i/240
   local tgt=Strike.Frames(stage,now,at,seenLate)
   local inWin=now-at<Wd+C.Recovery
   local out=P.Apply(s,stage,tgt,{Now=now,Dt=1/240,Awake=1,Moving=0,Speed=0,Frame=frame,Look=V(10,4,-30),Strike=inWin,Impact=at+Wd,WakeAt=now-.9,TauntAt=nil})
   if now>=at+Wd and now<=at+Wd+C.HitHold then check(same(out,tgt),('stage %d trial %d: polished frames differ inside contact window t=%.3f'):format(stage,trial,now-at))end
  end
 end
end
print(('polish window checks %d, fails %d'):format(checks,fails))
