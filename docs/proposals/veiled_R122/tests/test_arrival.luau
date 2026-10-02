--!nocheck
-- R122 Veiled One arrival: sound once per spawn (AudioMixer/SoundTiming); late joiners and stale timestamps never replay.
-- R127 (owner): the lights-out is a view-distance cut. The lights flicker out, the air turns black close in (only nearby
-- things show), a lantern glows around the local character, then the lights come back. Real VeiledArrivalFx +
-- EnvironmentLighting + BiomeMood + VeiledEventClient81 on the Roblox mock: the biome palette is restored exactly
-- (normal end, second spawn, respawn, interrupt, no render frames, renderer torn down).
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
local C3=R.Color3.fromRGB
-- Lighting as the place authors it (the renderer borrows these objects).
local Lighting=W.service('Lighting')
for k,v in pairs({Brightness=2,ExposureCompensation=0,Ambient=C3(70,70,80),OutdoorAmbient=C3(120,120,130),ClockTime=14,ColorShift_Top=C3(0,0,0),ColorShift_Bottom=C3(0,0,0),
 ShadowSoftness=.2,EnvironmentDiffuseScale=1,EnvironmentSpecularScale=1})do Lighting[k]=v end
local air=R.new('Atmosphere');air.Name='ChestChaseAtmosphere';for k,v in pairs({Color=C3(199,199,199),Decay=C3(106,112,125),Density=.3,Offset=.25,Haze=0,Glare=0})do air[k]=v end;air.Parent=Lighting
local grade=R.new('ColorCorrectionEffect');grade.Name='ChestChaseColor';for k,v in pairs({TintColor=C3(255,255,255),Brightness=0,Contrast=0,Saturation=0,Enabled=false})do grade[k]=v end;grade.Parent=Lighting
local bloom=R.new('BloomEffect');bloom.Name='Bloom';for k,v in pairs({Intensity=1,Size=24,Threshold=2,Enabled=true})do bloom[k]=v end;bloom.Parent=Lighting
local Env=W.module('EnvironmentLighting');local Mood=W.module('BiomeMood')
local renderer=Env.new(Lighting)
for _=1,200 do renderer:Step(1,'Clear',false,false,.05)end
local function snapshot()
 local out={}
 for _,k in ipairs({'Brightness','ExposureCompensation','Ambient','OutdoorAmbient','ColorShift_Top'})do local v=Lighting[k];out[#out+1]=type(v)=='table'and(v.R..'/'..v.G..'/'..v.B)or tostring(v)end
 for _,k in ipairs({'Density','Offset','Haze','Color','Decay'})do local v=air[k];out[#out+1]=type(v)=='table'and(v.R..'/'..v.G..'/'..v.B)or tostring(v)end
 for _,k in ipairs({'Brightness','Saturation','TintColor'})do local v=grade[k];out[#out+1]=type(v)=='table'and(v.R..'/'..v.G..'/'..v.B)or tostring(v)end
 return table.concat(out,',')
end
local lit=snapshot();local litDensity=air.Density
check(renderer.Settled==true,'biome palette settled before the arrival')
local Players=W.service('Players');local player=R.new('Player');player.Name='Me';player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local function spawnCharacter(x)
 local c=R.new('Model');c.Name='Me';local head=R.new('Part');head.Name='Head';head.CFrame=CF(x,6,20);head.Parent=c
 local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(x,4,20);hrp.Parent=c;c.Parent=W.workspace;player.Character=c;return c
end
spawnCharacter(0)
local F=W.module('VeiledArrivalFx')
local function now()return W.workspace.GetServerTimeNow()end
local function lantern()local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart');return root and root:FindFirstChild('VeiledLantern')end
local function frames(seconds)W.frames(math.floor(seconds*60+.5),1/60)end
-- Darkness curve ------------------------------------------------------------------------------------------------------
check(F.Level(-.1,false)==0 and F.Level(F.Duration,false)==0,'no darkness outside the effect')
check(F.Level(F.Flicker+1,false)==1 and F.Level(F.Flicker+F.Hold-.01,false)==1,'fully dark during the hold ('..F.Hold..' s)')
check(math.abs(F.Duration-6.95)<1e-9,'lasts '..F.Duration..' s (R128: 3 s shorter than R127)')
local drops=0;local prev,rising=0,true;for i=1,90 do local v=F.Level(i/90*F.Flicker,false);if rising and v<prev-1e-9 then drops+=1;rising=false elseif v>prev+1e-9 then rising=true end;prev=v end
check(drops>=2,'normal: the lights flicker before going out ('..drops..' flickers)')
local mono=true;prev=0;for i=1,90 do local v=F.Level(i/90*F.Flicker,true);if v<prev-1e-9 then mono=false end;prev=v end
check(mono,'Reduced Motion: no flicker')
check(F.Level(F.Flicker+1,true)<=F.ReducedLevel+1e-9,'Reduced Motion: slightly lighter darkness')
local steep=0;for i=0,math.floor(F.Return*60)do local a=F.Flicker+F.Hold+i/60;steep=math.max(steep,math.abs(F.Level(a+1/60,false)-F.Level(a,false)))end
check(steep<.03,('lights come back smoothly (max step/frame %.3f)'):format(steep))
-- Palette blend ---------------------------------------------------------------------------------------------------------
local base=Mood.Palette(1,'Clear',false,false);local dark=Mood.Blackout(Mood.Palette(1,'Clear',false,false),1)
check(dark.Air.Density>=.6 and dark.Air.Color.R==0 and dark.Air.Decay.R==0 and dark.Air.Offset==0,'full dark: thick black air close to the camera')
check(dark.Light.Brightness==0 and dark.Bloom==0 and dark.Sun==0,'full dark: no sun, no bloom')
local same=Mood.Blackout(Mood.Palette(1,'Clear',false,false),0)
check(same.Air.Density==base.Air.Density and same.Light.Brightness==base.Light.Brightness,'level 0 leaves the biome palette untouched')
local half=Mood.Blackout(Mood.Palette(1,'Clear',false,false),.5)
check(math.abs(half.Air.Density-(base.Air.Density+dark.Air.Density)/2)<1e-9,'half level = half way')
-- 1) One spawn: sound once, flicker, dark with a lantern, lights back exactly -------------------------------------------
print('-- spawn');local at=now()
check(F.Arrive(1,at)==true,'fresh arrival accepted')
check(plays==1,'arrival sound played once')
local snd=W.service('SoundService'):FindFirstChild('VeiledArrivalSound')
check(snd and snd.SoundId=='rbxassetid://113339179211972','owner sound id')
check(snd and snd.SoundGroup and snd.SoundGroup.Name=='GardenEffects','routed through AudioMixer Effects group')
check(pg:FindFirstChild('VeiledLightsOut')==nil,'no full-screen overlay any more')
frames(F.Flicker+1)
check(math.abs(air.Density-dark.Air.Density)<1e-6 and air.Color.R==0 and air.Decay.R==0,('dark: black air close in (density %.2f)'):format(air.Density))
check(Lighting.Brightness==0 and Lighting.ExposureCompensation<0,'dark: sun off, exposure down')
local l=lantern();check(l and l:IsA('PointLight')and l.Range==F.LanternRange and math.abs(l.Brightness-F.LanternBrightness)<1e-6,'lantern glows around my character')
check(F.Arrive(1,at)==false and plays==1,'same arrival never plays twice')
frames(F.Hold-1)
check(air.Density>litDensity+.05,'still dark near the end of the hold')
frames(F.Return+.2)
check(not F.Active()and Env.Level==0,'effect over after '..F.Duration..' s')
check(snapshot()==lit,'lights back: biome palette restored exactly')
check(lantern()==nil,'lantern removed')
-- 2) Second spawn while dark: restarts once, one lantern, one more sound, still ends.
print('-- second spawn');F.Arrive(2,now());frames(3);F.Arrive(3,now())
local count=0;for _,c in ipairs(player.Character.HumanoidRootPart:GetChildren())do if c.Name=='VeiledLantern'then count+=1 end end
check(count==1 and plays==3,'second arrival restarts a single effect (sounds '..plays..', lanterns '..count..')')
frames(F.Duration+.2);check(not F.Active()and snapshot()==lit,'second arrival also ends with the lights back')
-- 3) Respawn mid-effect: the lantern follows the new character, the effect still ends.
print('-- respawn');F.Arrive(4,now());frames(2)
player.Character:Destroy();spawnCharacter(12);frames(.1)
check(lantern()~=nil,'lantern follows the respawned character')
frames(F.Duration);check(not F.Active()and lantern()==nil and snapshot()==lit,'ends after respawn, lights back')
-- 4) Interrupted: Stop gives the lights back at once; no render frames -> the safety timer does.
print('-- interrupt');F.Arrive(5,now());frames(2);F.Stop();check(snapshot()==lit and lantern()==nil and Env.Level==0,'Stop restores the lights immediately')
F.Arrive(6,now());R.advance(F.Duration+.5);check(not F.Active()and Env.Level==0,'safety timer ends it even without render frames')
renderer:Step(1,'Clear',false,false,.05);check(snapshot()==lit,'lights back after the safety stop')
-- 5) Late delivery joins part-way (no sound); stale ones are ignored.
print('-- late');local before=plays
check(F.Arrive(7,now()-3)==true and plays==before,'3 s late: no sound, darkness joins part-way')
frames(.1);check(math.abs(air.Density-dark.Air.Density)<1e-6,'late delivery is already fully dark (no flicker replay)')
frames(F.Duration-3+.2);check(not F.Active()and snapshot()==lit,'late delivery ends on the original schedule')
check(F.Arrive(8,now()-(F.MaxAge+1))==false and plays==before and not F.Active(),'stale arrival ignored')
check(F.Arrive(9,nil)==false and not F.Active(),'arrival without a server time ignored')
-- 6) Biome changes during the darkness are honoured once the lights come back.
print('-- biome change');F.Arrive(10,now());frames(1)
for _=1,5 do renderer:Step(6,'Clear',false,false,.05)end
check(math.abs(air.Density-dark.Air.Density)<1e-6,'stays dark while walking into another biome')
frames(F.Duration);for _=1,300 do renderer:Step(6,'Clear',false,false,.05)end
local jungle=Mood.Palette(6,'Clear',false,false)
check(math.abs(air.Density-jungle.Air.Density)<1e-3 and Env.Level==0,'after the lights return the new biome palette settles')
for _=1,300 do renderer:Step(1,'Clear',false,false,.05)end;check(snapshot()==lit,'back in Forest: original palette')
-- 7) Renderer torn down mid-effect (script reload): the place's own lighting comes back, nothing errors.
print('-- teardown');F.Arrive(11,now());frames(1);renderer:Destroy()
check(Lighting.Brightness==2 and air.Density==.3,'renderer teardown restores the authored lighting')
local ok=pcall(function()frames(F.Duration)end);check(ok and not F.Active(),'effect finishes with no renderer')
renderer=Env.new(Lighting);for _=1,300 do renderer:Step(1,'Clear',false,false,.05)end
lit=snapshot()
-- 8) Client script: late joiner gets the notice only; a live remote plays; teardown restores.
print('-- client');before=plays
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='VeiledArrival81';remote.Parent=remotes
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
map:SetAttribute('VeiledEventActive',true);map:SetAttribute('VeiledEventCycle',3);map:SetAttribute('VeiledArrivalSerial83',19);map:SetAttribute('VeiledArrivalAt',now()-40)
local pushed={};W.stub('NoticeFeed83',{Push=function(text,_,key)pushed[#pushed+1]=key end})
local sc=R.new('LocalScript');sc.Name='VeiledEventClient81';W.load('VeiledEventClient81',sc)
check(#pushed==1 and plays==before and not F.Active(),'late joiner: notice only, no sound, no lights-out')
remote.OnClientEvent:Fire(12,20,now())
check(plays==before+1 and F.Active(),'live remote with a fresh server time: sound + lights-out')
remote.OnClientEvent:Fire(12,20,now())
check(plays==before+1,'duplicate remote ignored')
frames(1);sc.Destroying:Fire();check(not F.Active()and snapshot()==lit and lantern()==nil,'client teardown gives the lights back')
print(('arrival checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
