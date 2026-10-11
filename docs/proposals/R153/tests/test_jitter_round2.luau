--!nocheck
-- R153 jitter, round 2 (owner, again: "reduce jitter in effects"), on the mock with the REAL scripts / modules:
--  1. SpeedGainPopup: the popup field hangs on the HumanoidRootPart at the head's height (the head bobs with the treadmill run; the fan shook with it);
--  2. the treadmill's belt arrows (the V134 block of SpeedGainPopup) move on every drawn frame on a near belt in view (a 1/30 s tick before); a belt out of
--     view keeps the tick (no new per-frame work there) and its arrows are where the clock says when it comes back;
--  3. TreadmillFx: the belt's pattern (texture offsets) and the spinning pieces move on every drawn frame (a 1/30 s tick, 1/20 below tier 3, before);
--  4. RarePullFx: a sky beam's fade has no visible steps (its layers' transparency was quantised to 1/32: a jump of ~.03 at a time);
--  5. RarePullWorld: the charge motes sit on the bag's mouth of THIS frame even when its RenderStepped runs before SeedPackClient's (they trailed a moving
--     bag by a frame);
--  6. static: the cheer of a posed hub avatar is written every frame in view (HubDisplayClient; measured in R151 test_hub_client), SeedPackClient hands
--     RarePullWorld the bag's part.
local J=require('./jitter_world');local W,R=J.W,J.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local me=J.player('Me',7,true);local char=J.character(me,V3(0,3,0))
local root=char.HumanoidRootPart

-- the treadmill (one base): the belt, the TreadmillFx art (a pattern layer, a spinning piece) and the V134 arrows, as the server leaves them -------------------
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
local base=R.new('Model');base.Name='Base1';base.Parent=bases
local belt=R.new('Part');belt.Name='Treadmill';belt.Size=V3(8,1,20);belt.CFrame=CF(0,.5,40);belt.Anchored=true;belt.Parent=base
belt:SetAttribute('TreadmillTrainingBelt',true);belt:SetAttribute('TrainingActive',true)
local art=R.new('Folder');art.Name='TreadmillArtV131';art:SetAttribute('TreadmillTrackVersion',133);art:SetAttribute('TreadmillFxVersion',117);art.Parent=base
local layer2=R.new('Texture');layer2.Name='Belt pattern';layer2.StudsPerTileU=4;layer2.StudsPerTileV=4;layer2.OffsetStudsU=0;layer2.OffsetStudsV=0
layer2:SetAttribute('BeltImage',true);layer2:SetAttribute('TreadmillScroll',1);layer2.Parent=art
local spin=R.new('Part');spin.Name='Orbiter';spin.Size=V3(.5,.5,.5);spin.Anchored=true;spin.Parent=art
spin:SetAttribute('TreadmillSpin',2);spin:SetAttribute('TreadmillSpinPivot',CF(0,2,0));spin:SetAttribute('TreadmillSpinRest',CF(1.5,2,0))
local arrow=R.new('Part');arrow.Name='Arrow';arrow.Size=V3(2,.1,1);arrow.Anchored=true;arrow.Parent=art
arrow:SetAttribute('TrackMotion',true);arrow:SetAttribute('TrackRest',CF(0,.6,0));arrow:SetAttribute('TrackPhase',.25);arrow:SetAttribute('TrackRate',1)
arrow:SetAttribute('TrackTravel',10.8);arrow:SetAttribute('TrackAlpha',.5)
local function lookAtBelt()J.look(V3(10,12,20),belt.Position)end
local function lookAway()J.look(V3(0,12,-30),V3(0,12,-90))end -- (the belt 70 studs behind the camera: near, out of view)

-- 1 + 2. SpeedGainPopup ------------------------------------------------------------------------------------------------------------------------------------------
do
 local remotes=W.RS:FindFirstChild('ChestChaseRemotes')or R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 local ev=R.new('RemoteEvent');ev.Name='SpeedGainPopup';ev._props.OnClientEvent=R.signal();ev.Parent=remotes
 local stop=R.new('RemoteEvent');stop.Name='StopTreadmillTraining';stop._props.FireServer=function()end;stop.Parent=remotes
 W.UIS.JumpRequest=W.UIS.JumpRequest or R.signal()
 local sp=R.new('LocalScript');sp.Name='SpeedGainPopup';W.load('SpeedGainPopup',sp)
 J.look(root.Position+V3(10,6,-14),root.Position);me:SetAttribute('TreadmillTraining',true)
 local fieldOf=function()for _,g in ipairs(me.PlayerGui:GetChildren())do if g.Name=='SpeedGainField'and g.Enabled then return g end end end
 ev.OnClientEvent:Fire(me,120,nil,1,.2,char);J.frame(1/60)
 local field=fieldOf()
 if check(field~=nil,'SpeedGainPopup: a popup field is shown')then
  check(field.Adornee==root and math.abs(field.StudsOffsetWorldSpace.Y-(char.Head.Position.Y-root.Position.Y))<1e-6,'SpeedGainPopup: the field hangs on the root at the head\'s height (not on the bobbing head)')
  local at=field.Adornee.Position;char.Head.CFrame=char.Head.CFrame+V3(0,.3,0);J.frame(1/60)
  check(field.Adornee.Position==at,'SpeedGainPopup: a head bob (the treadmill run) does not move the field')
  char.Head.CFrame=char.Head.CFrame-V3(0,.3,0)
 end
 -- the arrows: in view every frame; out of view the tick
 lookAtBelt();J.run(1.2,60)
 J.everyFrame(check,'the belt arrows on a near belt in view (a 1/30 s tick before)',.5,lookAtBelt,function()return arrow.CFrame end)
 J.tier=1;J.everyFrame(check,'the belt arrows in view on the low tier',.5,lookAtBelt,function()return arrow.CFrame end);J.tier=3
 lookAway();J.run(.2,60)
 local list=J.sample(60,60,function()return arrow.CFrame end)
 local moves=60-J.stalls(list)
 check(moves>=25 and moves<=35,'out of view the arrows keep the 1/30 s tick (no new per-frame work there): '..moves..' moves in 60 frames')
 -- back in view: moving at once
 local before=arrow.CFrame;lookAtBelt();J.frame(1/60)
 check(arrow.CFrame~=before,'back in view the arrows move on the first frame')
 sp:Destroy()
end

-- 3. TreadmillFx (the way Fx.Start drives it: a controller stepped from Heartbeat) ----------------------------------------------------------------------------
do
 local Fx=W.module('TreadmillFx')
 local ctl=Fx.new({Map=function()return map end,Camera=function()return J.cam end,Quality=function()return J.tier end,Fast=function()return false end,
  Reduced=function()return false end,Move=function(parts,frames)W.workspace:BulkMoveTo(parts,frames)end})
 local hb=J.Run.Heartbeat:Connect(function(dt)ctl:Step(dt)end)
 lookAtBelt();J.run(.6,60)
 J.everyFrame(check,'TreadmillFx: the belt pattern on a near belt in view (a 1/30 s tick before)',.5,lookAtBelt,function()return layer2.OffsetStudsV end,nil,1e-9)
 J.everyFrame(check,'TreadmillFx: the spinning pieces (a 1/30 s tick before)',.5,lookAtBelt,function()return spin.CFrame end)
 J.tier=2;J.everyFrame(check,'TreadmillFx: the belt pattern on tier 2 (a 1/20 s tick before)',.5,lookAtBelt,function()return layer2.OffsetStudsV end,nil,1e-9);J.tier=3
 -- out of view nothing is stepped (the cull's gate, as before)
 lookAway();J.run(.6,60)
 local v0=layer2.OffsetStudsV;J.run(.5,60)
 check(layer2.OffsetStudsV==v0,'TreadmillFx: a belt out of view is not stepped (no new per-frame work)')
 hb:Disconnect()
end

-- 4. RarePullFx: the sky beam's fade ------------------------------------------------------------------------------------------------------------------------------
do
 local Fx=W.module('RarePullFx')
 local folder=R.new('Folder');folder.Parent=W.workspace
 for _,fps in ipairs({30,60,144})do
  local b=Fx.Beam({Parent=folder,Name='Light beam',Ground=V3(0,0,0),Height=140,Width=3.2,Land=0,Descent=.16,Hold=1.5,Fade=3,Tier=3,Reduced=false,Cracks=false})
  local core=b.Core
  local dt=1/fps;local worst,natural=0,0;local last,lastShade
  for i=0,math.floor(3*fps)do
   local t=1.5+i*dt;b:Update(t)
   local s=core.Transparency;local v=s.A and s.A[2]and s.A[2].V
   local k=math.clamp((t-1.5)/3,0,1);local shade=1-k*k*(3-2*k) -- (smooth(): the beam's own fade curve)
   if last and v then worst=math.max(worst,math.abs(v-last));natural=math.max(natural,math.abs(shade-lastShade)*(1-.25))end
   last,lastShade=v,shade
  end
  check(worst<=natural+1/200,string.format('the sky beam\'s fade at %d fps: the biggest step of its core between two frames is %.4f, the fade itself moves %.4f a frame (1/32 steps before: ~.03)',fps,worst,natural))
  b:Destroy()
 end
end

-- 5. RarePullWorld: the charge motes on this frame's mouth ---------------------------------------------------------------------------------------------------------
do
 local World=W.module('RarePullWorld')
 local other=J.player('Puller',8,false);local oc=J.character(other,V3(20,3,0))
 local bag=R.new('Part');bag.Name='Bag';bag.Size=V3(1,1.4,.4);bag.CFrame=CF(21,4,0);bag.Anchored=true;bag.Parent=oc
 J.look(V3(20,8,-14),V3(20,4,0))
 local e=World.Begin(other,oc,6,R.clock)
 check(e~=nil,'RarePullWorld: a Secret pull\'s world effect starts')
 local lip=CF(0,1.1,0)
 World.SetMouth(other,bag.CFrame*lip,bag);J.frame(1/60)
 -- the puller runs (.6 studs a frame): the bag moves, and this frame RarePullWorld steps BEFORE SeedPackClient tells it the new mouth. Each mote sits on a
 -- circle round the mouth it was drawn from (radius .2 + (1 - k) x 2.6, RarePullWorld's spiral): measured against the mouth of THIS frame
 local worst,seen=0,0
 for _=1,20 do
  bag.CFrame=bag.CFrame+V3(0,0,.6);oc:PivotTo(oc:GetPivot()+V3(0,0,.6))
  J.frame(1/60,function()
   local mouth=(bag.CFrame*lip).Position;local t=W.workspace:GetServerTimeNow()-e.At+(e.Shift or 0);local q=math.clamp(t/e.TL.Burst,0,1)
   for i,m in ipairs(e.Motes)do if m.Transparency<1 then
    local k=(q*1.7+i/#e.Motes)%1;local r=.2+(1-k)*2.6;local d=m.Position-mouth
    worst=math.max(worst,math.abs(math.sqrt(d.X*d.X+d.Z*d.Z)-r));seen+=1
   end end
  end)
  World.SetMouth(other,bag.CFrame*lip,bag) -- (SeedPackClient, later in the frame)
 end
 check(seen>0 and worst<=1e-4,string.format('RarePullWorld: the charge motes circle the bag\'s mouth of THIS frame (%d motes, off by at most %.4f studs; a frame late is .6)',seen,worst))
 World.Clear()
end

-- 6. static ----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local B=W.B
 check(B.HubDisplayClient:find('if(doPose or seen)and entry.Joints and entry.Local==\'pose\'then',1,true)~=nil,'HubDisplayClient: the cheer is written every frame in view (POSE_HZ out of view)')
 check(B.SeedPackClient:find('RareWorld.SetMouth(owner,root*CFrame.new(0,mouth,0),bag.PrimaryPart)',1,true)~=nil,'SeedPackClient hands RarePullWorld the bag\'s part')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
