--!nocheck
-- R130 (owner): "when the track refreshes the sky turns dark too". Real RefreshSky, TrackRefreshSky and WorldEvents on
-- the Roblox mock:
--  * with the black-sky image: black sky, clear air (as before);
--  * without it (no image API on that client): no texture-less Sky (that showed a light day sky), midnight clock and
--    black air, so the sky and the far distance go dark while the base stays readable;
--  * everything comes back exactly when the refresh ends; no weather clouds are made or thickened during a refresh.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RGB=R.Color3.fromRGB
local function same(a,b)return typeof(a)==typeof(b)and(type(a)~='table'or(math.abs(a.R-b.R)<1e-9 and math.abs(a.G-b.G)<1e-9 and math.abs(a.B-b.B)<1e-9))and(type(a)=='table'or a==b)end
do local base=R.new;R.new=function(class,...)local o=base(class,...)
 if class=='Sound'then o._props.Loaded=R.signal();o._props.Ended=R.signal();o._props.IsLoaded=true;o._props.TimeLength=3 end
 return o end end
R.Inst.Play=function(self)self._props.IsPlaying=true end;R.Inst.Stop=function(self)self._props.IsPlaying=false end
local Lighting=W.service('Lighting')
function Lighting.FindFirstChildOfClass(self,c)for _,x in ipairs(self:GetChildren())do if x.ClassName==c then return x end end end
local terrain=R.new('Terrain');terrain.Name='Terrain';terrain.Parent=W.workspace
function W.workspace.FindFirstChildOfClass(self,c)for _,x in ipairs(self:GetChildren())do if x.ClassName==c then return x end end end
local clouds=R.new('Clouds');clouds.Cover=.35;clouds.Density=.25;clouds.Color=RGB(255,255,255);clouds.Enabled=true;clouds.Parent=terrain
local authored=R.new('Sky');authored.Name='Sky';authored.StarCount=3000;authored.Parent=Lighting
local air=R.new('Atmosphere');air.Name='ChestChaseAtmosphere';air.Density=.14;air.Offset=.18;air.Haze=.4;air.Glare=.025
air.Color=RGB(217,234,255);air.Decay=RGB(159,180,210);air.Parent=Lighting
Lighting.ClockTime=14.2;Lighting.Ambient=RGB(137,145,166);Lighting.OutdoorAmbient=RGB(185,195,214)
local Sky=W.module('RefreshSky')
local function skies()local out={};for _,c in ipairs(Lighting:GetChildren())do if c:IsA('Sky')then out[#out+1]=c end end;return out end
local function lum(c)return c.R*.3+c.G*.59+c.B*.11 end
local saved={Density=air.Density,Offset=air.Offset,Haze=air.Haze,Glare=air.Glare,Color=air.Color,Decay=air.Decay}
local function airBack(label)
 local ok=true;for k,v in pairs(saved)do if not same(air[k],v)then ok=false;print('  air '..k..' '..tostring(air[k])..' ~= '..tostring(v))end end
 check(ok,label..': air exactly as before')
end
local function lightBack(label)
 check(Lighting.ClockTime==14.2 and same(Lighting.Ambient,RGB(137,145,166))and same(Lighting.OutdoorAmbient,RGB(185,195,214)),label..': clock and ambient back')
 check(authored.Parent==Lighting and #skies()==1,label..': authored sky back, nothing extra')
 check(clouds.Enabled==true,label..': clouds back on')
 check(Lighting:GetAttribute('TrackRefreshActive')==nil,label..': refresh flag cleared')
end
-- 1. No image API on this client (the mock AssetService has no CreateEditableImage).
local restore=Sky.Begin()
check(Lighting:GetAttribute('TrackRefreshActive')==true,'refresh flag set')
check(#skies()==0,'no texture-less Sky left showing a light day sky ('..#skies()..' skies)')
check(Lighting.ClockTime==0,'midnight')
check(same(air.Color,RGB(0,0,0))and same(air.Decay,RGB(0,0,0))and air.Haze==0 and air.Glare==0 and air.Offset==0,'air turns black (sky and far distance go dark)')
check(air.Density>=Sky.NightDensity and air.Density<.5,('black air at about the usual view distance (density %.2f; lights-out uses .7)'):format(air.Density))
check(lum(Lighting.Ambient)>=.55 and lum(Lighting.OutdoorAmbient)>=.55,'the base stays readable')
check(clouds.Enabled==false,'clouds hidden')
restore();lightBack('no image');airBack('no image')
restore();check(#skies()==1 and air.Density==saved.Density,'restoring twice is harmless')
-- 1b. A place without any Atmosphere gets a temporary black one, removed afterwards.
air.Parent=nil;restore=Sky.Begin()
local night=Lighting:FindFirstChild('TrackRefreshNightAir')
check(night and same(night.Color,RGB(0,0,0))and night.Density>=Sky.NightDensity,'no Atmosphere: a temporary black one')
restore();check(Lighting:FindFirstChild('TrackRefreshNightAir')==nil,'and it is removed afterwards');air.Parent=Lighting
-- 2. With the black-sky image (as before).
Sky.Destroy()
local images=0
W.service('AssetService').CreateEditableImage=function()images+=1;return {WritePixelsBuffer=function()end,Destroy=function()end}end
W.env.Content={fromObject=function(e)return {Object=e}end}
restore=Sky.Begin()
local black=Lighting:FindFirstChild('TrackRefreshBlackSky')
check(images==1 and black and black.SkyboxBackContent and black.SkyboxUpContent,'black sky image on every face')
check(#skies()==1 and authored.Parent==nil,'only the black sky shows')
check(black.StarCount==0 and black.CelestialBodiesShown==false,'no stars, sun or moon')
check(air.Density==0 and air.Haze==0 and air.Glare==0,'air cleared so the black shows')
check(Lighting.ClockTime==14.2,'clock untouched with the image')
restore();lightBack('image');airBack('image')
check(Lighting:FindFirstChild('TrackRefreshBlackSky')==nil,'black sky removed')
restore=Sky.Begin();check(images==1,'the image is made once and reused');restore()
-- 3. Through the real TrackRefreshSky client: the map flag starts and ends it.
Sky.Destroy();W.service('AssetService').CreateEditableImage=nil
local Players=W.service('Players');local player=R.new('Player');player.Name='P';player.UserId=3;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
player.CharacterAdded=R.signal();player.CharacterRemoving=R.signal()
local char=R.new('Model');char.Name='P';local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(0,5,-60);hrp.Parent=char;char.Parent=W.workspace;player.Character=char
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace;map:SetAttribute('FieldWidth',180)
map:SetAttribute('BiomeStartZ_1',0);map:SetAttribute('BiomeEndZ_1',400)
W.service('ContentProvider').PreloadAsync=function()end
local client=R.new('LocalScript');W.load('TrackRefreshSky',client)
map:SetAttribute('BiomeRefreshEndsAt',R.clock+10);map:SetAttribute('BiomesRefreshing',true)
check(Lighting.ClockTime==0 and same(air.Color,RGB(0,0,0))and #skies()==0,'refresh starts: dark sky')
W.frames(30)
map:SetAttribute('BiomesRefreshing',false)
lightBack('after the refresh');airBack('after the refresh')
-- 4. Weather during a refresh: WorldEvents makes no cloud layer and does not thicken clouds.
local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,14,-75)
W.RS:SetAttribute('GlobalWeather','Clear');W.load('WorldEvents',R.new('LocalScript'))
clouds:Destroy()
map:SetAttribute('BiomeRefreshEndsAt',R.clock+20);map:SetAttribute('BiomesRefreshing',true)
W.RS:SetAttribute('GlobalWeather','Rain');W.frames(6*60)
check(terrain:FindFirstChild('WeatherClouds')==nil,'no weather cloud layer during the refresh (the sky stays dark)')
map:SetAttribute('BiomesRefreshing',false);W.frames(6*60)
local made=terrain:FindFirstChild('WeatherClouds')
check(made~=nil and made.Cover>.8,'rain clouds come back after the refresh')
local own=R.new('Clouds');own.Cover=.35;own.Density=.25;own.Color=RGB(255,255,255);own.Enabled=true
W.RS:SetAttribute('GlobalWeather','Clear');W.frames(10*60);own.Parent=terrain
W.RS:SetAttribute('GlobalWeather','Rain');W.frames(6*60);check(own.Cover>.8,'authored clouds thicken in rain (as R129)')
map:SetAttribute('BiomesRefreshing',true);W.frames(10*60)
check(own.Enabled==false and math.abs(own.Cover-.35)<.01,'during a refresh: clouds off and back to their own values')
map:SetAttribute('BiomesRefreshing',false);W.frames(2)
check(own.Enabled==true,'clouds on again after the refresh')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
