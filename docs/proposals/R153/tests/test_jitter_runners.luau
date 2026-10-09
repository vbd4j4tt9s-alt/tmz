--!nocheck
-- R153 jitter, runners, on the mock with the REAL scripts (a Storm-booted runner wearing the Aurora trail, sprinting 34 studs/s, then standing):
--  1. RunnerTrailClient: the ground ribbons under the soles move every drawn frame at 30 / 60 / 144 fps (20 Hz before), the Volt coils' glow runs
--     smoothly up the boots (four steps at 20 Hz before), the idle aura's shards orbit every frame (20 Hz before); the ground is still found at most
--     every Rules.Interval per sole (the raycasts per second are what they were); nothing is drawn in the physics half of a frame;
--  2. RunnerTrailAura: the Aurora halo's colour flow and the veil ribbon's palette move every frame (12.5 / 10 Hz before), in RenderStepped;
--  3. SpeedGainPopup: the popups fly every frame (already so; the field on the bobbing Head is left for the popup agent: R153 jitter.md).
local J=require('./jitter_world');local W,R=J.W,J.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local me=J.player('Me',7,true);local char=J.character(me,V3(0,3,0))
J.look(V3(12,8,-12),V3(0,2,10))
-- the cosmetics the server gives: Storm boots (ground ribbons, coils, idle shards) and the Aurora trail (halo, veil)
local folder=R.new('Folder');folder.Name='ChestChaseCosmetics';folder:SetAttribute('CosmeticVersion',91)
local count=W.module('RunnerBootArt').Create(char,folder,'Storm',R.Color3.fromRGB(200,200,200))
folder:SetAttribute('BootCount',count);folder:SetAttribute('BootBiome','Storm')
folder:SetAttribute('TrailId84','AuroraTrail');folder:SetAttribute('TrailLow84',-2.9);folder:SetAttribute('TrailHigh84',2.4)
folder.Parent=char
check(count==2,'two Storm boots are dressed ('..tostring(count)..')')
local root=char.HumanoidRootPart;local hum=char:FindFirstChildOfClass('Humanoid')
local casts=0;local rawCast=W.workspace.Raycast;W.workspace.Raycast=function(...)casts+=1;return rawCast(...)end
local sc=R.new('LocalScript');sc.Name='RunnerTrailClient';W.load('RunnerTrailClient',sc)
local sa=R.new('LocalScript');sa.Name='RunnerTrailAura';W.load('RunnerTrailAura',sa)
-- sprinting: the whole runner moves 34 studs/s; the feet swing (a stride every .4 s)
local feet={char.LeftFoot,char.RightFoot}
local function sprint(_,dt)
 J.move(char,V3(0,0,34*dt),dt)
 local phase=math.sin(R.clock*16)*.5
 for i,f in ipairs(feet)do local p=f.Position;f.CFrame=CF(p.X,root.Position.Y-2.85+math.max(0,(i==1 and phase or -phase))*.3,p.Z)end
end
J.run(.5,60,nil)
for _=1,30 do sprint(nil,1/60);J.frame(1/60)end
local fxFolder=W.workspace:FindFirstChild('RunnerGroundEffects')
local ribbon=fxFolder and fxFolder:FindFirstChild('Ground ribbon anchor')
if check(ribbon~=nil,'RunnerTrailClient: the ground ribbon anchors are made')then
 J.everyFrame(check,'a sprinting runner\'s ground ribbon (was 20 Hz)',1,nil,function()return ribbon.CFrame end,sprint)
 J.tier=1;J.everyFrame(check,'the ground ribbon on the low tier (was every other 20 Hz tick for far runners)',.6,nil,function()return ribbon.CFrame end,sprint);J.tier=3
 -- the raycasts per second are what they were: two soles, at most one cast per Rules.Interval (.05 s) each
 casts=0;for _=1,144 do sprint(nil,1/144);J.frame(1/144)end
 check(casts<=2*22,'RunnerTrailClient: at 144 fps the soles cast for the ground at most 20 times a second each ('..casts..' casts in 1 s)')
 local before=ribbon.CFrame;J.physicsOnly(10);check(J.same(ribbon.CFrame,before),'RunnerTrailClient: nothing is drawn in the physics half of a frame')
end
-- the Volt coils' glow while sprinting
local coils={};for _,d in ipairs(folder:GetDescendants())do if d:IsA('BasePart')and d.Name=='Volt coil'then coils[#coils+1]=d end end
if check(#coils>0,'the Storm boots have Volt coils ('..#coils..')')then
 J.everyFrame(check,'the Volt coils\' glow running up the boots (was four steps at 20 Hz)',1,nil,function()local t={};for i,c in ipairs(coils)do t[i]=c.Color end;return t end,sprint,1e-6)
end
-- the Aurora trail's halo and veil (RunnerTrailAura)
local halo
for _,d in ipairs(char.Head:GetDescendants())do if d:IsA('BasePart')and not halo then halo=d end end
local function haloColors()local t={};for i,d in ipairs(char.Head:GetDescendants())do if d:IsA('BasePart')then t[#t+1]=d.Color end end;return t end
if check(halo~=nil,'RunnerTrailAura: the Aurora halo is on the head')then
 J.everyFrame(check,'the Aurora halo\'s colour flow (was 12.5 Hz)',1,nil,haloColors,sprint,1e-6)
 local before=haloColors();J.physicsOnly(10);check(J.same(haloColors(),before),'RunnerTrailAura: nothing changes in the physics half of a frame (RenderStepped)')
end
local veil
for _,d in ipairs(root:GetDescendants())do if d:IsA('Trail')and d.Name:find('Veil')then veil=d end end
for _,d in ipairs(char:GetDescendants())do if not veil and d:IsA('Trail')and(d.Name:find('Veil')or d.Name:find('veil'))then veil=d end end
if check(veil~=nil,'RunnerTrailAura: the Aurora veil ribbon is on the runner')then
 J.everyFrame(check,'the veil ribbon\'s palette flow (was 10 Hz)',1,nil,function()return veil.Color end,sprint,1e-6)
end
-- standing still: the idle aura fades in and its shards orbit
root.AssemblyLinearVelocity=V3(0,0,0);J.run(2,60)
local shard=fxFolder and fxFolder:FindFirstChild('Boot idle shard')
if check(shard~=nil and shard.Transparency<1,'RunnerTrailClient: standing, the Storm idle aura shows its shards')then
 J.everyFrame(check,'the idle aura\'s orbiting shards (was 20 Hz)',1,nil,function()return shard.CFrame end)
end
sc:Destroy();sa:Destroy()

-- 3. SpeedGainPopup ------------------------------------------------------------------------------------------------------------------------------------------
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
  J.everyFrame(check,'a speed popup flying out',.3,function()ev.OnClientEvent:Fire(me,120,nil,1,.2,char);J.frame(1/60)end,function()
   local f=fieldOf();local p;for _,c in ipairs(f and(f:FindFirstChild('Zoom')or f):GetChildren()or{})do if c.Name=='Popup'and c.Visible and(not p or c.ZIndex>p.ZIndex)then p=c end end
   return p and p.Position end)
 end
 sp:Destroy()
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
