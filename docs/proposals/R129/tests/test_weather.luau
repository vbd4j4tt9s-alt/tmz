--!nocheck
-- R129 (owner): weather is a base-area thing. Real WorldEvents (global rain / snow / storm), BiomeMood palette,
-- BiomeWeather (biome particles) and BiomePresentation source on the Roblox mock:
--  * in the base the rain keeps falling whatever the camera does (no "roof" cut) and the clouds turn dark;
--  * on the track there is no weather effect at all, and the biome's own particles keep running;
--  * clouds and lighting come back exactly when the weather ends.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RGB=R.Color3.fromRGB
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
local terrain=R.new('Terrain');terrain.Name='Terrain';terrain.Parent=W.workspace
function W.workspace.FindFirstChildOfClass(self,c)for _,x in ipairs(self:GetChildren())do if x.ClassName==c then return x end end end
local clouds=R.new('Clouds');clouds.Cover=.35;clouds.Density=.25;clouds.Color=RGB(255,255,255);clouds.Enabled=true;clouds.Parent=terrain
function terrain.FindFirstChildOfClass(self,c)for _,x in ipairs(self:GetChildren())do if x.ClassName==c then return x end end end
W.service('ContentProvider').PreloadAsync=function()end
local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,14,-75)
W.RS:SetAttribute('GlobalWeather','Clear')
W.load('WorldEvents',R.new('LocalScript'))
local folder=W.workspace:FindFirstChild('_GlobalWeatherR59');local rain=folder and folder:FindFirstChildWhichIsA('Part',true)
local emitter;for _,d in ipairs(folder:GetDescendants())do if d.ClassName=='ParticleEmitter'and d.Name=='Precipitation'then emitter=d end end
check(emitter~=nil,'precipitation emitter exists')
local function frames(sec)W.frames(math.floor(sec*60+.5),1/60)end
-- 1. Rain in the base: falling, world-space, clouds darken
W.RS:SetAttribute('GlobalWeather','Rain');frames(.5)
check(emitter.Enabled==true and emitter.LockedToPart==false,'rain falls in the base (world-space)')
-- Camera passes under a roof: the rain keeps falling (the old camera roof check is gone)
local roof=R.new('Part');roof.Size=V3(200,2,200);roof.CFrame=CF(0,40,-75);roof.Anchored=true;roof.Parent=W.workspace
for i=1,40 do cam.CFrame=CF(math.sin(i)*8,14,-75+i*.2);W.frames(1,1/60)end
check(emitter.Enabled==true,'turning the camera / passing under things never stops the rain')
frames(6)
check(clouds.Cover>.8 and clouds.Density>.75,('clouds thicken (%.2f cover, %.2f density)'):format(clouds.Cover,clouds.Density))
check(clouds.Color.R<.5 and clouds.Color.G<.5,'clouds turn dark grey')
check(clouds.Enabled==true,'cloud Enabled left to RefreshSky')
-- 2. On the track: no weather effect at all
hrp.CFrame=CF(0,5,120);cam.CFrame=CF(0,14,105);frames(.5)
check(emitter.Enabled==false,'no rain on the track')
frames(8)
check(math.abs(clouds.Cover-.35)<.01 and math.abs(clouds.Density-.25)<.01,'clouds clear while on the track')
-- Back to the base: rain again
hrp.CFrame=CF(0,5,-60);cam.CFrame=CF(0,14,-75);frames(.5)
check(emitter.Enabled==true,'rain again back in the base')
-- 3. Thunderstorm lightning only in the base
W.RS:SetAttribute('GlobalWeather','Thunderstorm');frames(1)
check(emitter.Enabled==true,'storm rain in the base')
hrp.CFrame=CF(0,5,120);frames(1)
local flash=W.service('Lighting'):FindFirstChild('DistantThunderGlow')
check(emitter.Enabled==false and(not flash or flash.Enabled==false),'no storm rain or lightning flash on the track')
-- 4. Weather ends: clouds back exactly
hrp.CFrame=CF(0,5,-60);frames(4)
W.RS:SetAttribute('GlobalWeather','Clear');frames(10)
check(clouds.Cover==.35 and clouds.Density==.25 and clouds.Color.R==1,'clouds restored exactly after the weather')
check(emitter.Enabled==false,'no precipitation when clear')
-- 5. A place without clouds gets a temporary cloud layer, removed afterwards
clouds:Destroy();W.RS:SetAttribute('GlobalWeather','Blizzard');frames(6)
local made=terrain:FindFirstChild('WeatherClouds')
check(made~=nil and made.Cover>.8,'no authored clouds: a weather cloud layer appears')
W.RS:SetAttribute('GlobalWeather','Clear');frames(10)
check(terrain:FindFirstChild('WeatherClouds')==nil,'and is removed when the weather ends')
-- 6. Palette: the sky darkens in the base; the track keeps its biome look
local Mood=W.module('BiomeMood')
local clear,rainy,storm=Mood.Palette(0,'Clear',false,false),Mood.Palette(0,'Rain',false,false),Mood.Palette(0,'Thunderstorm',false,false)
check(rainy.Light.Brightness<clear.Light.Brightness*.7 and storm.Light.Brightness<rainy.Light.Brightness,'rain/storm light is clearly darker')
local function lum(c)return c.R*.3+c.G*.59+c.B*.11 end
check(lum(rainy.Air.Color)<lum(clear.Air.Color)*.6 and rainy.Air.Density>clear.Air.Density,'dark grey, thicker sky')
check(W.B.WorldEvents:find('Raycast(p,Vector3.new(0,80,0)',1,true)==nil and W.B.WorldEvents:find('indoors',1,true)==nil,'the camera roof check is gone (it switched the rain off)')
-- BiomePresentation passes Clear on the track; BiomeWeather no longer switches off for weather.
check(W.B.BiomePresentation:find("stage==0 and(RS:GetAttribute('GlobalWeather')or'Clear')or'Clear'",1,true)~=nil,'track (stage > 0) gets no weather palette')
check(W.B.BiomeWeather:find("GlobalWeather",1,true)==nil,'biome particles keep running on the track during weather')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
