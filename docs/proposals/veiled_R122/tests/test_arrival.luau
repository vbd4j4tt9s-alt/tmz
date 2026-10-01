--!nocheck
-- R122 Veiled One arrival: sound once per spawn (AudioMixer/SoundTiming), 1 s lights-out overlay that always goes
-- away (normal, second spawn, respawn, interrupt, no render frames), Lighting never touched, late joiners and
-- stale timestamps never replay. Real VeiledArrivalFx + real VeiledEventClient81 on the Roblox mock.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- Sound API on the mock: count plays per instance.
do local base=R.new;R.new=function(class,...)local o=base(class,...)
 if class=='Sound'then o._props.Loaded=R.signal();o._props.Ended=R.signal();o._props.IsLoaded=true;o._props.TimeLength=3;o._props.Playing=0 end
 if class=='RemoteEvent'then o._props.OnClientEvent=R.signal()end
 return o end end
local plays=0
R.Inst.Play=function(self)if self.Name=='VeiledArrivalSound'then plays+=1 end;self._props.IsPlaying=true end
R.Inst.Stop=function(self)self._props.IsPlaying=false end
local CP=W.service('ContentProvider');function CP.PreloadAsync()end
local Lighting=W.service('Lighting');Lighting.Brightness=2;Lighting.ExposureCompensation=0;Lighting.Ambient=R.Color3.fromRGB(70,70,80);Lighting.ClockTime=14
local function lightingSnapshot()return table.concat({Lighting.Brightness,Lighting.ExposureCompensation,Lighting.Ambient.R,Lighting.ClockTime},',')end
local lit=lightingSnapshot()
local Players=W.service('Players');local player=R.new('Player');player.Name='Me';player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local function spawnCharacter(x)
 local c=R.new('Model');c.Name='Me';local head=R.new('Part');head.Name='Head';head.CFrame=CF(x,6,20);head.Parent=c
 local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(x,4,20);hrp.Parent=c;c.Parent=W.workspace;player.Character=c;return c
end
spawnCharacter(0)
local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,10,0);cam.FieldOfView=70
function cam.WorldToViewportPoint(_,p)return V3(640+p.X*10,360-(p.Y-10)*10,p.Z),p.Z>0 end
local F=W.module('VeiledArrivalFx')
local function overlay()return pg:FindFirstChild('VeiledLightsOut')end
local function now()return W.workspace.GetServerTimeNow()end
-- Darkness curve.
check(F.Darkness(-.1,false)==1 and F.Darkness(1,false)==1,'overlay invisible outside the 1 s window')
check(math.abs(F.Darkness(.5,false)-F.Darkest)<1e-9,'fully dark mid-way (normal)')
check(F.Darkness(.5,true)>=F.DarkestReduced-1e-9,'Reduced Motion: gentler darkness')
local steepN,steepR=0,0
for i=0,59 do local a,b=i/60,(i+1)/60;steepN=math.max(steepN,math.abs(F.Darkness(b,false)-F.Darkness(a,false)));steepR=math.max(steepR,math.abs(F.Darkness(b,true)-F.Darkness(a,true)))end
check(steepR<steepN and steepR<.12,('Reduced Motion fades slower (max step/frame %.3f vs %.3f), no hard flash'):format(steepR,steepN))
-- 1) One spawn: sound once, dark for ~1 s, then gone; Lighting untouched.
print('-- spawn');local at=now()
check(F.Arrive(1,at)==true,'fresh arrival accepted')
check(plays==1,'arrival sound played once')
local snd=W.service('SoundService'):FindFirstChild('VeiledArrivalSound')
check(snd and snd.SoundId=='rbxassetid://113339179211972','owner sound id')
check(snd and snd.SoundGroup and snd.SoundGroup.Name=='GardenEffects','routed through AudioMixer Effects group')
check(overlay()~=nil and overlay().DisplayOrder<0 and overlay().ResetOnSpawn==false,'lights-out overlay under the HUD, survives respawn')
W.frames(30,1/60)
local g=overlay();check(g and g.Darkness.GroupTransparency<.1,'dark at 0.5 s')
-- The visibility bubble is centred on the character's screen point and no dark rectangle covers it.
local cx,cy=640,360-(6-10)*10
for _,n in ipairs({'Top','Bottom','Left','Right'})do
 local f=g.Darkness[n];local x,y,w,h=f.Position.X.Offset,f.Position.Y.Offset,f.Size.X.Offset+f.Size.X.Scale*1280,f.Size.Y.Offset+f.Size.Y.Scale*720
 check(not(cx>=x and cx<=x+w and cy>=y and cy<=y+h),'bubble clear of '..n)
end
check(g.Darkness.BubbleEdge1.Position.X.Offset==cx and g.Darkness.BubbleEdge1.Position.Y.Offset==cy,'bubble centred on the character')
check(F.Arrive(1,at)==false and plays==1,'same arrival never plays twice')
W.frames(32,1/60)
check(overlay()==nil and not F.Active(),'overlay removed after 1 s')
check(lightingSnapshot()==lit,'Lighting unchanged')
-- 2) Second spawn while dark: one overlay, restarts, still ends; one more sound.
print('-- second spawn');F.Arrive(2,now());W.frames(30,1/60);F.Arrive(3,now())
local count=0;for _,c in ipairs(pg:GetChildren())do if c.Name=='VeiledLightsOut'then count+=1 end end
check(count==1 and plays==3,'second arrival restarts a single overlay (sounds '..plays..')')
W.frames(62,1/60);check(overlay()==nil and lightingSnapshot()==lit,'second arrival also ends after 1 s')
-- 3) Respawn mid-effect: overlay follows the new character and still ends.
print('-- respawn');F.Arrive(4,now());W.frames(20,1/60)
player.Character:Destroy();spawnCharacter(12);W.frames(2,1/60)
check(overlay()and overlay().Darkness.BubbleEdge1.Position.X.Offset==640+12*10,'bubble follows the respawned character')
W.frames(50,1/60);check(overlay()==nil,'ends after respawn')
-- 4) Interrupted: script teardown removes it at once; no render frames -> safety timer removes it.
print('-- interrupt');F.Arrive(5,now());W.frames(10,1/60);F.Stop();check(overlay()==nil,'Stop removes the overlay immediately')
F.Arrive(6,now());R.advance(1.3);check(overlay()==nil,'removed even without render frames')
check(lightingSnapshot()==lit,'Lighting still unchanged')
-- 5) Stale / late: old timestamps and joins after the spawn never replay.
print('-- late joiner');local before=plays
check(F.Arrive(7,now()-5)==false and plays==before and overlay()==nil,'stale arrival (5 s old) ignored')
check(F.Arrive(8,nil)==false and overlay()==nil,'arrival without a server time ignored')
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='VeiledArrival81';remote.Parent=remotes
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
map:SetAttribute('VeiledEventActive',true);map:SetAttribute('VeiledEventCycle',3);map:SetAttribute('VeiledArrivalSerial83',9);map:SetAttribute('VeiledArrivalAt',now()-40)
local pushed={};W.stub('NoticeFeed83',{Push=function(text,_,key)pushed[#pushed+1]=key end})
local sc=R.new('LocalScript');sc.Name='VeiledEventClient81';W.load('VeiledEventClient81',sc)
check(#pushed==1 and plays==before and overlay()==nil,'late joiner: notice only, no sound, no lights-out')
remote.OnClientEvent:Fire(12,10,now())
check(plays==before+1 and overlay()~=nil,'live remote with a fresh server time: sound + lights-out')
remote.OnClientEvent:Fire(12,10,now())
check(plays==before+1,'duplicate remote ignored')
sc.Destroying:Fire();check(overlay()==nil,'client teardown removes the overlay')
check(lightingSnapshot()==lit,'Lighting unchanged at the end')
-- Hole radius stays usable on every screen.
for _,vp in ipairs({{1920,1080},{1280,720},{844,390},{667,375},{390,844}})do
 cam.ViewportSize=R.Vector2.new(vp[1],vp[2])
 local r=F.HoleRadius(cam,V3(0,6,20),F.BubbleStuds);local short=math.min(vp[1],vp[2])
 check(r>=48 and r<=short*.45,('hole radius %dx%d = %.0f px'):format(vp[1],vp[2],r))
end
print(('arrival checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
