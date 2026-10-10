--!nocheck
-- R151 Cloudy sky, part 2: the look and how it reaches the world. "It just dims the lighting": no rain, no particles; thicker, greyer clouds, a darker
-- sky, a gentle haze, a cooler and slightly desaturated ambient - and still bright enough to play. Everything goes through the one mechanism the weather
-- and the biome moods already use (BiomeMood.Palette -> EnvironmentLighting), so nothing fights over Lighting.
--  A. BiomeMood: the Cloudy palette for every biome (dimmer, cooler, hazier, never darker than a storm), monotonic in the level, event weather ignores it,
--     The Darkened's blackout and the track-refresh sky compose with it, FastMode keeps its savings, no shared table is touched.
--  B. EnvironmentLighting (the one writer): a 30 s fade is smooth (no pops, few writes, none once settled, exact return to Clear), The Darkened's lights-out
--     while it is cloudy returns to the Cloudy look, not Clear.
--  C. the REAL BiomePresentation.client on a mock Lighting: follows the server state, event weather takes priority and the sky returns, the track keeps its
--     mood, a rare-pull story scene is lit as authored, a track refresh keeps its night sky, FastMode, a late joiner, teardown restores the place's values.
--  D. the REAL WorldEvents.client's Terrain clouds: thicker and greyer under Cloudy (authored layer restored exactly, or a temporary one added and removed),
--     the storms still take them over and give them back.
--  E. static ownership: nothing else in the Cloudy code writes Lighting / Atmosphere / ColorCorrection; R149's rain / snow never sees Cloudy.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local C3=R.Color3.fromRGB
local floor,abs,max,min=math.floor,math.abs,math.max,math.min
local Mood=W.module('BiomeMood');local Cycle=W.module('WeatherCycle151');local Env=W.module('EnvironmentLighting')
local function lum(c)return c.R*.3+c.G*.59+c.B*.11 end
local function colorEq(a,b,e)return abs(a.R-b.R)<=(e or 1e-9)and abs(a.G-b.G)<=(e or 1e-9)and abs(a.B-b.B)<=(e or 1e-9)end
local function same(a,b,e)
 if type(a)=='table'and a.__type=='Color3'then return type(b)=='table'and colorEq(a,b,e)end
 if type(a)=='table'then for k,v in pairs(a)do if not same(v,b and b[k],e)then return false end end;for k in pairs(b or{})do if a[k]==nil then return false end end;return true end
 if type(a)=='number'then return type(b)=='number'and abs(a-b)<=(e or 1e-9)end
 return a==b
end

-- ======================================================================================================================
-- A. The palette
-- ======================================================================================================================
print('-- palette')
local clearP=Mood.Palette(0,'Clear',false,false);local rainP=Mood.Palette(0,'Rain',false,false);local stormP=Mood.Palette(0,'Thunderstorm',false,false)
-- untouched at level 0 / nil, for every stage, weather and flag
do
 local ok=true;local n=0
 for stage=0,7 do for _,w in ipairs({'Clear','Rain','Thunderstorm','Blizzard'})do for _,low in ipairs({false,true})do for _,refresh in ipairs({false,true})do
  local a=Mood.Palette(stage,w,low,refresh);local b=Mood.Palette(stage,w,low,refresh,0);local c=Mood.Palette(stage,w,low,refresh,nil)
  n+=1;if not(same(a,b)and same(a,c))then ok=false;print('  differs:',stage,w,low,refresh)end
 end end end end
 check(ok,('level 0 or nil leaves every palette exactly as it was (%d combinations)'):format(n))
end
-- event weather ignores the level (it takes priority and looks exactly as before)
do
 local ok=true
 for stage=0,7 do for _,w in ipairs({'Rain','Thunderstorm','Blizzard'})do for _,k in ipairs({.3,1})do
  if not same(Mood.Palette(stage,w,false,false,k),Mood.Palette(stage,w,false,false,0))then ok=false end
 end end end
 check(ok,'Rain / Thunderstorm / Blizzard palettes are identical with any Cloudy level')
end
-- the look, biome by biome
local names={[0]='Garden','Forest','Desert','Snow','Lava','Crystal','Jungle','Storm Peaks'}
do
 local worstBright,worstAmb,worstOut=9,9,9
 for _,stage in ipairs({0,1,2,3,4,5,6,7})do
  local a=Mood.Palette(stage,'Clear',false,false,0);local b=Mood.Palette(stage,'Clear',false,false,1)
  local who=names[stage]or tostring(stage)
  local ratio=b.Light.Brightness/a.Light.Brightness
  check(ratio>.66 and ratio<.70,('%s: Brightness %.2f -> %.2f (x%.2f): dimmer'):format(who,a.Light.Brightness,b.Light.Brightness,ratio))
  check(b.Light.Brightness>=1.5 and b.Light.Brightness>rainP.Light.Brightness and b.Light.Brightness>stormP.Light.Brightness,who..': still brighter than a rainy day (1.45) and a storm: playable')
  check(near(b.Light.ExposureCompensation-a.Light.ExposureCompensation,-.135,1e-9)and b.Light.ExposureCompensation>stormP.Light.ExposureCompensation,who..': exposure lowered, not below a storm\'s')
  check(lum(b.Light.Ambient)<lum(a.Light.Ambient)and lum(b.Light.OutdoorAmbient)<lum(a.Light.OutdoorAmbient),who..': ambient dimmer')
  check((b.Light.Ambient.B-b.Light.Ambient.R)>(a.Light.Ambient.B-a.Light.Ambient.R)and(b.Light.OutdoorAmbient.B-b.Light.OutdoorAmbient.R)>(a.Light.OutdoorAmbient.B-a.Light.OutdoorAmbient.R),who..': ambient cooler (bluer against red)')
  check(lum(b.Light.Ambient)>lum(rainP.Light.Ambient)and lum(b.Light.OutdoorAmbient)>lum(rainP.Light.OutdoorAmbient),who..': ambient brighter than the rain\'s (readable)')
  worstBright=min(worstBright,b.Light.Brightness);worstAmb=min(worstAmb,lum(b.Light.Ambient));worstOut=min(worstOut,lum(b.Light.OutdoorAmbient))
  check(b.Grade.Saturation<a.Grade.Saturation and b.Grade.Saturation>=-.14 and b.Grade.Saturation>stormP.Grade.Saturation,who..': slightly desaturated (not as grey as rain)')
  check(b.Grade.Brightness>=-.03 and b.Grade.Contrast>=0 and lum(b.Grade.TintColor)<=lum(a.Grade.TintColor)+1e-9 and(b.Grade.TintColor.B-b.Grade.TintColor.R)>(a.Grade.TintColor.B-a.Grade.TintColor.R),who..': the colour grade is a cooler tint, no crushed contrast')
  check(lum(b.Air.Color)<lum(a.Air.Color)and lum(b.Air.Decay)<lum(a.Air.Decay),who..': a darker, greyer sky')
  check(b.Air.Haze>a.Air.Haze+.5 and b.Air.Density>a.Air.Density and b.Air.Density<=max(a.Air.Density,.3)+1e-9 and b.Air.Glare==0,who..': a gentle haze (denser, never over .3), no glare')
  check(b.Sun==0 and b.Bloom>a.Bloom,who..': no sun rays, a little more bloom for the lamps')
  check(near(b.Light.ColorShift_Top.R,a.Light.ColorShift_Top.R)and near(b.Light.ColorShift_Bottom.B,a.Light.ColorShift_Bottom.B),who..': the biome\'s own colour shift is kept')
 end
 print(('  (the dimmest Cloudy biome: Brightness %.2f, ambient luminance %.2f, outdoor %.2f; the rain: %.2f / %.2f / %.2f)'):format(worstBright,worstAmb,worstOut,rainP.Light.Brightness,lum(rainP.Light.Ambient),lum(rainP.Light.OutdoorAmbient)))
end
-- monotonic in the level
do
 local ok=true;local prev
 for _,stage in ipairs({0,2,4,7})do
  prev=nil
  for i=0,20 do
   local p=Mood.Palette(stage,'Clear',false,false,i/20)
   local cur={p.Light.Brightness,-p.Light.ExposureCompensation,-lum(p.Light.Ambient),-lum(p.Light.OutdoorAmbient),-p.Grade.Saturation,p.Air.Haze,p.Air.Density,-lum(p.Air.Color),-p.Sun,p.Bloom}
   if prev then for j=1,#cur do local want=j==1 and-1 or 1
    -- Brightness goes down, everything else (negated where it falls) goes up
    local d=(cur[j]-prev[j])*(j==1 and-1 or 1);if d<-1e-9 then ok=false end end end
   prev=cur
  end
 end
 check(ok,'every part of the look moves one way only as the level rises (no overshoot, no kink)')
 local half=Mood.Palette(0,'Clear',false,false,.5)
 check(half.Light.Brightness<clearP.Light.Brightness and half.Light.Brightness>Mood.Palette(0,'Clear',false,false,1).Light.Brightness,'half way is half way')
end
-- composes with The Darkened's blackout, the refresh sky, FastMode; shares nothing
do
 local d0=Mood.Blackout(Mood.Palette(0,'Clear',false,false,0),1);local d1=Mood.Blackout(Mood.Palette(0,'Clear',false,false,1),1)
 check(same(d0,d1,1e-9),'full blackout = The Darkened\'s look whatever the sky was (the dark wins)')
 local h0=Mood.Blackout(Mood.Palette(0,'Clear',false,false,0),.5);local h1=Mood.Blackout(Mood.Palette(0,'Clear',false,false,1),.5)
 check(h1.Light.Brightness<h0.Light.Brightness and h1.Light.Brightness>0,'half a blackout over a cloudy sky is darker than over a clear one')
 local r0=Mood.Palette(0,'Clear',false,true,0);local r1=Mood.Palette(0,'Clear',false,true,1)
 check(same(r0.Grade,r1.Grade)and r0.Bloom==r1.Bloom and r0.Sun==r1.Sun,'the track-refresh sky: its grade, bloom and sun are RefreshSky\'s whatever the sky (the refresh owns the light and air)')
 local l1=Mood.Palette(0,'Clear',true,false,1)
 check(l1.Bloom==0 and l1.Sun==0 and near(l1.Air.Glare,0)and l1.Air.Density<=Mood.Palette(0,'Clear',false,false,1).Air.Density*.75+1e-9,'FastMode keeps its savings (no bloom, no rays, thinner air) under Cloudy')
 Mood.Palette(0,'Clear',false,false,1)
 check(same(Mood.Palette(0,'Clear',false,false,0),clearP),'the profile tables are not touched by a Cloudy palette')
end

-- ======================================================================================================================
-- B. EnvironmentLighting: the one writer
-- ======================================================================================================================
print('-- EnvironmentLighting')
local Lighting=W.service('Lighting')
for k,v in pairs({Brightness=2,ExposureCompensation=0,Ambient=C3(70,70,80),OutdoorAmbient=C3(120,120,130),ClockTime=14,ColorShift_Top=C3(0,0,0),ColorShift_Bottom=C3(0,0,0),
 ShadowSoftness=.2,EnvironmentDiffuseScale=1,EnvironmentSpecularScale=1})do Lighting[k]=v end
local air=R.new('Atmosphere');air.Name='ChestChaseAtmosphere';for k,v in pairs({Color=C3(199,199,199),Decay=C3(106,112,125),Density=.3,Offset=.25,Haze=0,Glare=0})do air[k]=v end;air.Parent=Lighting
local grade=R.new('ColorCorrectionEffect');grade.Name='ChestChaseColor';for k,v in pairs({TintColor=C3(255,255,255),Brightness=0,Contrast=0,Saturation=0,Enabled=false})do grade[k]=v end;grade.Parent=Lighting
local bloom=R.new('BloomEffect');bloom.Name='Bloom';for k,v in pairs({Intensity=1,Size=24,Threshold=2,Enabled=true})do bloom[k]=v end;bloom.Parent=Lighting
local sun=R.new('SunRaysEffect');sun.Name='SunRays';for k,v in pairs({Intensity=.25,Spread=1,Enabled=true})do sun[k]=v end;sun.Parent=Lighting
local watched={Lighting,air,grade,bloom,sun}
local writeCount=0
for _,o in ipairs(watched)do o.Changed:Connect(function()writeCount+=1 end)end
local function snapshot()
 local out={}
 local function add(o,keys)for _,k in ipairs(keys)do local v=o[k];out[#out+1]=type(v)=='table'and(v.R..'/'..v.G..'/'..v.B)or tostring(v)end end
 add(Lighting,{'Brightness','ExposureCompensation','Ambient','OutdoorAmbient','ColorShift_Top','ClockTime'});add(air,{'Density','Offset','Haze','Glare','Color','Decay'})
 add(grade,{'Brightness','Contrast','Saturation','TintColor','Enabled'});add(bloom,{'Intensity','Enabled'});add(sun,{'Intensity','Enabled'})
 return table.concat(out,',')
end
local renderer=Env.new(Lighting)
local function settle(stage,weather,low,refresh,cloud)for _=1,300 do renderer:Step(stage,weather,low,refresh,.05,cloud)end end
settle(0,'Clear',false,false,0)
local clearSnap=snapshot();check(renderer.Settled==true,'settled on the Clear palette')
local clearBright=Lighting.Brightness
check(near(clearBright,clearP.Light.Brightness,1e-3),'the Clear look is the palette\'s (Brightness '..clearBright..')')
-- a 30 s fade as the clients drive it: level from the server state, 20 steps a second
do
 local worst,prev,mono,keys,lastKey=0,Lighting.Brightness,true,0,renderer.Key
 writeCount=0
 for i=1,600 do
  local level=Cycle.LevelAt('Cloudy',0,30,0,i*.05)
  renderer:Step(0,'Clear',false,false,.05,level)
  local b=Lighting.Brightness;worst=max(worst,abs(b-prev));if b>prev+1e-9 then mono=false end;prev=b
  if renderer.Key~=lastKey then keys+=1;lastKey=renderer.Key end
 end
 for _=1,100 do renderer:Step(0,'Clear',false,false,.05,1)end
 local target=Mood.Palette(0,'Clear',false,false,1)
 check(near(Lighting.Brightness,target.Light.Brightness,1e-3)and near(air.Haze,target.Air.Haze,1e-3)and near(grade.Saturation,target.Grade.Saturation,1e-3),('the fade ends on the Cloudy palette (Brightness %.3f, Haze %.2f)'):format(Lighting.Brightness,air.Haze))
 check(sun.Enabled==false and bloom.Enabled==true,'no sun rays under cloud, bloom on')
 check(mono,'Brightness only ever falls during the fade')
 check(worst<=.02,('the biggest Brightness step in 50 ms is %.4f (the whole dim is %.2f, 2.5 %% of Brightness is .06): no pop'):format(worst,clearBright-Lighting.Brightness))
 check(keys<=Env.CloudSteps+1,('the palette target is rebuilt %d times over the fade (at most %d)'):format(keys,Env.CloudSteps+1))
 check(writeCount<=Env.CloudSteps*22,('%d property writes over the whole 30 s fade (at most %d: %d steps of ~20 properties; the old easing would have written ~10,000)'):format(writeCount,Env.CloudSteps*22,Env.CloudSteps))
 local before=writeCount
 for _=1,400 do renderer:Step(0,'Clear',false,false,.05,1)end
 check(writeCount==before,'settled and cloudy: not one write in 20 s')
 -- back to Clear
 for i=1,600 do renderer:Step(0,'Clear',false,false,.05,Cycle.LevelAt('Clear',0,30,1,i*.05))end
 for _=1,100 do renderer:Step(0,'Clear',false,false,.05,0)end
 check(snapshot()==clearSnap,'fading back to Clear restores the Clear look exactly (every value)')
end
-- the other lights-out / weather writers go through the same renderer: no fights
do
 settle(0,'Clear',false,false,1);local cloudy=snapshot();local cloudyBright=Lighting.Brightness
 -- The Darkened arrives while it is cloudy
 Env.SetBlackout(1);renderer:Step(0,'Clear',false,false,.05,1)
 check(near(Lighting.Brightness,0,1e-6)and near(air.Density,Mood.Dark.Air.Density,1e-6),'The Darkened (full blackout): the lights are out whatever the sky')
 Env.SetBlackout(.5);renderer:Step(0,'Clear',false,false,.05,1)
 check(Lighting.Brightness>0 and Lighting.Brightness<cloudyBright,'half-way through the blackout the cloudy brightness is blended down')
 Env.SetBlackout(0);renderer:Step(0,'Clear',false,false,.05,1)
 check(snapshot()==cloudy,'the lights come back to the CLOUDY look exactly (not to Clear)')
 -- a storm arrives while it is cloudy, and ends
 settle(0,'Rain',false,false,0)
 check(near(Lighting.Brightness,rainP.Light.Brightness,1e-3),'Rain during a cloudy sky: the rain\'s own look ('..Lighting.Brightness..')')
 settle(0,'Clear',false,false,1)
 check(snapshot()==cloudy,'when the rain ends the sky is Cloudy again, exactly as it was')
 -- the track keeps its biome mood
 settle(3,'Clear',false,false,0)
 check(near(Lighting.Brightness,Mood.Palette(3,'Clear',false,false,0).Light.Brightness,1e-3),'on the track (Snow) the biome look: Brightness '..Lighting.Brightness)
 settle(0,'Clear',false,false,1)
 -- the track-refresh sky: Lighting and Atmosphere are RefreshSky's; only the grade is ours
 local before=snapshot()
 for _=1,40 do renderer:Step(0,'Clear',false,true,.05,1)end
 local lightingSame=Lighting.Brightness==cloudyBright and air.Haze==Mood.Palette(0,'Clear',false,false,1).Air.Haze
 check(lightingSame,'during a track refresh Cloudy does not write Lighting or the Atmosphere')
 settle(0,'Clear',false,false,1)
 -- FastMode
 settle(0,'Clear',true,false,1)
 check(bloom.Enabled==false and sun.Enabled==false,'FastMode: no bloom, no rays under cloud')
 check(Lighting.Brightness<clearBright*.75,'FastMode still dims')
 settle(0,'Clear',false,false,0)
 check(snapshot()==clearSnap,'and back to the exact Clear look again')
end
-- renderer teardown restores the place's own values
renderer:Destroy()
check(near(Lighting.Brightness,2,1e-9)and near(air.Density,.3,1e-9)and near(grade.Saturation,0,1e-9),'Destroy() gives the place\'s authored values back after all that')

-- ======================================================================================================================
-- C. BiomePresentation.client (the real script)
-- ======================================================================================================================
print('-- BiomePresentation')
do local base=R.new;R.new=function(class,...)local o=base(class,...)
 if class=='Sound'then o._props.Loaded=R.signal();o._props.Ended=R.signal();o._props.IsLoaded=true;o._props.TimeLength=3 end
 return o end end
R.Inst.Play=function(self)self._props.IsPlaying=true end;R.Inst.Stop=function(self)self._props.IsPlaying=false end
local Players=W.service('Players');local player=R.new('Player');player.Name='P';player.UserId=3;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal();player.CharacterRemoving=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local char=R.new('Model');char.Name='P';local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(0,5,-60);hrp.Parent=char;char.Parent=W.workspace;player.Character=char
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace;map:SetAttribute('FieldWidth',180)
map:SetAttribute('BiomeStartZ_1',0);map:SetAttribute('BiomeEndZ_1',400);map:SetAttribute('BiomeStartZ_6',400);map:SetAttribute('BiomeEndZ_6',900)
local RS=W.RS
-- the place's own lighting again (the previous renderer put it back)
for k,v in pairs({Brightness=2.55,ExposureCompensation=.015,Ambient=C3(137,145,166),OutdoorAmbient=C3(185,195,214),ClockTime=14,ColorShift_Top=C3(17,9,2),ColorShift_Bottom=C3(0,1,4)})do Lighting[k]=v end
local function frames(sec)W.frames(floor(sec*60+.5),1/60)end
local function state(kind,since,fade,from)RS:SetAttribute(Cycle.Attribute,Cycle.Pack(kind,since,fade,from or(kind=='Cloudy'and 0 or 1),since+360))end
RS:SetAttribute('GlobalWeather','Clear')
local bp=W.load('BiomePresentation',R.new('LocalScript'))
frames(8)
local base0=Lighting.Brightness
check(near(base0,Mood.Palette(0,'Clear',false,false,0).Light.Brightness,.01),'no server state yet (an old server): the Clear look ('..Lighting.Brightness..')')
-- Cloudy arrives over 30 s
local t0=R.clock;state('Cloudy',t0,30)
frames(15);local mid=Lighting.Brightness
check(mid<base0-.15 and mid>1.8,('half way through the fade: Brightness %.2f (Clear %.2f, Cloudy 1.73)'):format(mid,base0))
frames(25);local cloudyB=Lighting.Brightness
check(near(cloudyB,Mood.Palette(0,'Clear',false,false,1).Light.Brightness,.01),('after the fade: the Cloudy look (%.3f)'):format(cloudyB))
local airCloudy=Lighting:FindFirstChild('ChestChaseAtmosphere');check(airCloudy.Haze>.9,'the haze is up (Haze '..airCloudy.Haze..')')
-- a player who joins in the middle of it: same state, same look, at once
-- (the renderer follows the level: a new client reading the same attribute lands on the same palette)
-- event weather takes priority; returns afterwards
RS:SetAttribute('GlobalWeather','Rain');frames(6)
check(near(Lighting.Brightness,rainP.Light.Brightness,.02),('Rain during a Cloudy sky: the rain\'s look (%.2f), the cycle does not add to it'):format(Lighting.Brightness))
RS:SetAttribute('GlobalWeather','Thunderstorm');frames(6)
check(near(Lighting.Brightness,stormP.Light.Brightness,.02),'Thunderstorm: its own look ('..Lighting.Brightness..')')
RS:SetAttribute('GlobalWeather','Blizzard');frames(6)
check(near(Lighting.Brightness,Mood.Palette(0,'Blizzard',false,false).Light.Brightness,.02),'Blizzard: its own look')
do -- R154 review: the lamps glow in every dim weather, so the Blizzard has to be one: it dims the world (HubLife151.isDark follows this)
 local clearP,snowP=Mood.Palette(0,'Clear',false,false,0),Mood.Palette(0,'Blizzard',false,false)
 check(snowP.Light.Brightness<=clearP.Light.Brightness*.8 and snowP.Light.ExposureCompensation<clearP.Light.ExposureCompensation and snowP.Sun==0 and snowP.Air.Haze>clearP.Air.Haze and snowP.Air.Density>clearP.Air.Density,
  ('Blizzard dims the world against Clear: Brightness %.2f -> %.2f, exposure %.3f -> %.3f, no sun rays, Haze %.2f -> %.2f, Density %.2f -> %.2f'):format(clearP.Light.Brightness,snowP.Light.Brightness,clearP.Light.ExposureCompensation,snowP.Light.ExposureCompensation,clearP.Air.Haze,snowP.Air.Haze,clearP.Air.Density,snowP.Air.Density))
end
RS:SetAttribute('GlobalWeather','Clear');frames(8)
check(near(Lighting.Brightness,cloudyB,.01),'the event ends: back to the Cloudy look, not to Clear ('..Lighting.Brightness..')')
-- on the track: the biome's own mood; back in the base: cloudy again
hrp.CFrame=CF(0,5,120);frames(8)
check(near(Lighting.Brightness,Mood.Palette(1,'Clear',false,false,0).Light.Brightness,.02),'on the track the biome keeps its mood while the sky is Cloudy ('..Lighting.Brightness..')')
hrp.CFrame=CF(0,5,-60);frames(8)
check(near(Lighting.Brightness,cloudyB,.01),'back in the base: Cloudy')
-- a rare-pull story scene is lit as authored (the dimming eases out over a second or two: it never jumps while the world is still on screen)
player:SetAttribute('RarePullCinematic','Scene')
do local prev,worst=Lighting.Brightness,0
 for i=1,60 do frames(.05);worst=max(worst,abs(Lighting.Brightness-prev));prev=Lighting.Brightness end
 check(worst<.2,('the story scene starts: Brightness eases from Cloudy to the authored look, the biggest 50 ms step is %.3f of the %.2f it moves'):format(worst,base0-cloudyB))
end
frames(6)
check(near(Lighting.Brightness,base0,.02),'a rare-pull story scene (Secret / Cosmic / King): lit as authored, no Cloudy dimming ('..Lighting.Brightness..')')
player:SetAttribute('RarePullCinematic','Ladder');frames(8)
check(near(Lighting.Brightness,cloudyB,.01),'the in-world reveals (Common .. Mythic) keep the sky')
player:SetAttribute('RarePullCinematic',nil);frames(4)
-- the track-refresh sky
Lighting:SetAttribute('TrackRefreshActive',true);Lighting.Brightness=.4;frames(6)
check(near(Lighting.Brightness,.4,1e-9),'a track refresh owns the light: Cloudy writes nothing')
Lighting:SetAttribute('TrackRefreshActive',nil);Lighting.Brightness=cloudyB;frames(4)
-- The Darkened
local F2=W.module('VeiledArrivalFx')
Env.SetBlackout(1);frames(1)
check(Lighting.Brightness<.05,'The Darkened\'s lights-out while cloudy: dark')
Env.SetBlackout(0);frames(2)
check(near(Lighting.Brightness,cloudyB,.01),'... and the lights come back to Cloudy')
-- FastMode
player:SetAttribute('FastMode',true);frames(8)
check(near(Lighting.Brightness,cloudyB,.01),'FastMode dims too (same light, thinner air)')
check(Lighting:FindFirstChild('Bloom').Enabled==false,'FastMode: bloom off')
player:SetAttribute('FastMode',nil);frames(4)
-- Clear again
state('Clear',R.clock,30,1);frames(40)
check(near(Lighting.Brightness,base0,.01),('Clear again after a 30 s fade: Brightness %.3f'):format(Lighting.Brightness))
-- a held test sky arrives fast (the owner's /test weather cloudy)
state('Cloudy',R.clock,6);frames(10)
check(near(Lighting.Brightness,cloudyB,.01),'a 6 s test fade is followed')
-- Track share (the owner's knob)
do
 local Cfg=Cycle.Config;Cfg.Track=1;hrp.CFrame=CF(0,5,120);frames(8)
 check(near(Lighting.Brightness,Mood.Palette(1,'Clear',false,false,1).Light.Brightness,.02),'Config.Track = 1: the biome mood is dimmed too ('..Lighting.Brightness..')')
 Cfg.Track=0;hrp.CFrame=CF(0,5,-60);frames(8)
end
-- teardown
bp=nil
frames(1)

-- ======================================================================================================================
-- D. WorldEvents.client: the Terrain clouds
-- ======================================================================================================================
print('-- clouds')
local terrain=R.new('Terrain');terrain.Name='Terrain';terrain.Parent=W.workspace
function terrain.FindFirstChildOfClass(self,c)for _,x in ipairs(self:GetChildren())do if x.ClassName==c then return x end end end
function W.workspace.FindFirstChildOfClass(self,c)for _,x in ipairs(self:GetChildren())do if x.ClassName==c then return x end end end
local clouds=R.new('Clouds');clouds.Cover=.35;clouds.Density=.25;clouds.Color=C3(255,255,255);clouds.Enabled=true;clouds.Parent=terrain
W.service('ContentProvider').PreloadAsync=function()end
local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,14,-75)
RS:SetAttribute('GlobalWeather','Clear');state('Clear',R.clock-100,30,1)
W.load('WorldEvents',R.new('LocalScript'));W.load('WeatherWorld',R.new('LocalScript'))
hrp.CFrame=CF(0,5,-60);frames(2)
check(clouds.Cover==.35 and clouds.Density==.25 and clouds.Color.R==1,'a Clear sky leaves the authored clouds alone')
local look=Mood.CloudyLook.Clouds
state('Cloudy',R.clock,30);frames(10)
check(clouds.Cover>.35 and clouds.Cover<look.Cover,('during the fade the clouds thicken (Cover %.2f)'):format(clouds.Cover))
frames(40)
check(near(clouds.Cover,look.Cover,.02)and near(clouds.Density,look.Density,.02)and near(clouds.Color.R,look.Color.R,.02),('Cloudy: thicker (Cover %.2f, Density %.2f) and greyer (%.2f)'):format(clouds.Cover,clouds.Density,clouds.Color.R))
check(look.Cover<.86 and look.Density<.82 and look.Color.R>.5,'... but lighter than the storm\'s clouds (.86 / .82, dark grey)')
check(clouds.Enabled==true,'Enabled stays with RefreshSky')
local cloudyCover=clouds.Cover
-- the storms take them over, and give them back
RS:SetAttribute('GlobalWeather','Thunderstorm');frames(8)
check(clouds.Cover>.9 and clouds.Color.R<.3,('a thunderstorm over a Cloudy sky: its own dark clouds (Cover %.2f)'):format(clouds.Cover))
RS:SetAttribute('GlobalWeather','Clear');frames(14)
check(near(clouds.Cover,cloudyCover,.02),'when it ends: the Cloudy clouds again ('..clouds.Cover..')')
-- the track: no weather clouds
hrp.CFrame=CF(0,5,120);frames(10)
check(near(clouds.Cover,.35,.02)and near(clouds.Density,.25,.02),'on the track the clouds are the place\'s own')
hrp.CFrame=CF(0,5,-60);frames(10)
check(clouds.Cover>.7,'back in the base: Cloudy clouds')
player:SetAttribute('RarePullCinematic','Scene');frames(10)
check(near(clouds.Cover,.35,.02),'a story scene: the place\'s own clouds')
player:SetAttribute('RarePullCinematic',nil);frames(10)
Lighting:SetAttribute('TrackRefreshActive',true);frames(10)
check(near(clouds.Cover,.35,.02),'a track refresh: no cloud layer (R130)')
Lighting:SetAttribute('TrackRefreshActive',nil);frames(10)
-- Clear: restored EXACTLY
state('Clear',R.clock,30,1);frames(45)
check(clouds.Cover==.35 and clouds.Density==.25 and clouds.Color.R==1 and clouds.Color.G==1,'Clear again: the authored clouds exactly')
-- a place with no cloud layer: one is made for the weather and removed
clouds:Destroy()
state('Cloudy',R.clock,30);frames(40)
local made=terrain:FindFirstChild('WeatherClouds')
check(made~=nil and made.Cover>.7,'no authored clouds: a cloud layer appears for the Cloudy sky')
state('Clear',R.clock,30,1);frames(45)
check(terrain:FindFirstChild('WeatherClouds')==nil,'... and is removed when it clears')
-- a clear sky costs nothing in the cloud code: no layer, no writes
local writesBefore=#terrain:GetChildren();frames(5);check(#terrain:GetChildren()==writesBefore and terrain:FindFirstChild('WeatherClouds')==nil,'(nothing created while clear)')

-- ======================================================================================================================
-- E. ownership
-- ======================================================================================================================
print('-- ownership')
local function writesLighting(src)
 for _,pat in ipairs({'Lighting%.Brightness','Lighting%.Ambient','Lighting%.OutdoorAmbient','Lighting%.ExposureCompensation','ChestChaseColor','ChestChaseAtmosphere','Lighting%.ClockTime',':FindFirstChildOfClass%(.Atmosphere.%)',':FindFirstChildOfClass%(.Sky.%)'})do
  if src:find(pat)then return pat end
 end
 return nil
end
for _,name in ipairs({'WeatherCycle151','HubLife151Client','HubLifeArt151','WeatherService','WeatherSkyCommand151'})do
 check(writesLighting(W.B[name])==nil,name..' never touches Lighting / Atmosphere / ColorCorrection ('..tostring(writesLighting(W.B[name]))..')')
end
check(W.B.WorldEvents:find('Lighting%.Brightness')==nil and W.B.WorldEvents:find('ChestChaseColor')==nil,'WorldEvents (clouds, lightning flash) writes no biome lighting property')
check(W.B.BiomePresentation:find("stage==0 and(RS:GetAttribute('GlobalWeather')or'Clear')or'Clear'",1,true)~=nil,'the track still gets no event-weather palette (R129)')
check(W.B.WeatherWorld:find('Cloudy')==nil and W.B.BiomeAmbience:find('Cloudy')==nil,'the R149 rain / snow world and the biome sounds never see Cloudy')
check(W.B.EnvironmentLighting:find('Lighting%.Brightness')==nil,'(EnvironmentLighting stays generic)')
-- the R149 world weather ignores the default sky: no precipitation under Cloudy
do
 local function emitting()
  local n=0;local f=W.workspace:FindFirstChild('_WeatherWorldR149')
  if f then for _,d in ipairs(f:GetDescendants())do if d._class=='ParticleEmitter'and d.Enabled==true and(d.Rate or 0)>0 then n+=1 end end end
  return n
 end
 check(W.workspace:FindFirstChild('_WeatherWorldR149')~=nil,'(the R149 weather world is running)')
 RS:SetAttribute('GlobalWeather','Clear');state('Cloudy',R.clock-100,30);hrp.CFrame=CF(0,5,-60);frames(4)
 check(emitting()==0,'no rain or snow particles under the Cloudy sky')
 RS:SetAttribute('GlobalWeather','Rain');frames(3)
 check(emitting()>0,'rain still falls in an event (the R149 weather is unchanged)')
 RS:SetAttribute('GlobalWeather','Clear');frames(6)
 check(emitting()==0,'... and stops')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
