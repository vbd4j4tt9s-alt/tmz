--!nocheck
-- R149 preview dump (not a test): runs the REAL WeatherWorld149.client.lua, SnowBiome149.client.lua and KeyboardTrack.client.lua on the
-- Roblox mock and prints three scenes as JSON lines ("SCENE name {json}") for render_weather.mjs:
--   rain      the base in the rain: every emitting tile (rectangle, height, rate, speeds, lifetimes, acceleration, spread), the ground splash
--             emitters, the garden beds, the track rectangle and the keyboard rows near the border (nothing falls on the track)
--   blizzard  the same base 35 s into a blizzard: snow tiles + the snow patches (faded in) and the beds they leave alone
--   snowbiome the Snow biome with the keyboard: the permanent patches (edge drifts, border patches, dust) above the key tops
-- The renderer simulates the particles from those numbers (a design preview: no Roblox lighting, textures or fonts).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local workspace=W.workspace;local RS=W.RS
local WW=W.module('WeatherWorld149');local K=W.module('KeyboardTrack');local C=K.Config;local F=C.FloorTop
local floor,abs=math.floor,math.abs
local ATTR={BiomeTrackEndZ=5980,BiomeStartZ_1=-100,BiomeEndZ_1=80,BiomeStartZ_6=80,BiomeEndZ_6=530,BiomeStartZ_2=530,BiomeEndZ_2=1180,
 BiomeStartZ_3=1180,BiomeEndZ_3=2030,BiomeStartZ_4=2030,BiomeEndZ_4=3080,BiomeStartZ_5=3080,BiomeEndZ_5=4380,BiomeStartZ_7=4380,BiomeEndZ_7=5980}
local function frames(sec)W.frames(floor(sec*60+.5),1/60)end
do local base=R.new;R.new=function(class,...)local o=base(class,...)
 if class=='Sound'then o._props.Loaded=R.signal();o._props.Ended=R.signal();o._props.IsLoaded=true;o._props.TimeLength=3 end
 return o end end
R.Inst.Play=function()end;R.Inst.Stop=function()end
W.service('ContentProvider').PreloadAsync=function()end
function workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal();player.CharacterRemoving=R.signal()
function Players.GetPlayers()return {player}end
W.stub('ClientFxBudget',{Get=function()return 3 end,Low=function()return false end})
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace
for k,v in pairs(ATTR)do map:SetAttribute(k,v)end;map:SetAttribute('FieldWidth',180)
local GROUND=F
local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
local plots={}
-- two garden bases: beds in rows (20 x 24 studs, soil), aisles between them
for _,b in ipairs({{-70,-215},{70,-215},{-70,-262},{70,-262}})do for r=0,1 do for c=0,1 do
 local x,z=b[1]-24+c*24,b[2]-14+r*28
 local p=R.new('Part');p.Name='DirtPlot_'..(#plots+1);p.Size=V3(20,.4,24);p.CFrame=CF(x,GROUND+.1,z);p.Anchored=true;p.Parent=bases
 plots[#plots+1]={part=p,x=x,z=z,hx=10,hz=12}
end end end
local floorPart=R.new('Part');floorPart.Name='LobbyFloor'
function workspace.Raycast(_,origin)
 for _,pl in ipairs(plots)do if abs(origin.X-pl.x)<=pl.hx and abs(origin.Z-pl.z)<=pl.hz then return {Position=V3(origin.X,GROUND+.3,origin.Z),Normal=V3(0,1,0),Instance=pl.part}end end
 return {Position=V3(origin.X,GROUND,origin.Z),Normal=V3(0,1,0),Instance=floorPart}
end
local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55)
local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=RS
local model=R.new('Model');model.Name='Tester'
local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.Parent=model;model.PrimaryPart=root;model.Parent=workspace;player.Character=model
local function runnerAt(x,z)root.CFrame=CF(x,F+3,z)end
local function n(v)return string.format('%.3f',v)end
local function col(c)return string.format('[%d,%d,%d]',floor(c.R*255+.5),floor(c.G*255+.5),floor(c.B*255+.5))end

local function keyParts()
 local out={};local vis=workspace:FindFirstChild('KeyboardTrackVisuals')
 if not vis then return out end
 for _,folder in ipairs(vis:GetChildren())do
  if folder.Name=='Bed'or folder.Name=='Keys'or folder.Name:find('^Blocks')then
   for _,p in ipairs(folder:GetChildren())do
    if(folder.Name=='Bed'or p.Transparency==0)and p.CFrame.Position.Y>0 then
     local q=p.CFrame.Position;out[#out+1]=string.format('{"s":[%s,%s,%s],"p":[%s,%s,%s],"c":%s}',n(p.Size.X),n(p.Size.Y),n(p.Size.Z),n(q.X),n(q.Y),n(q.Z),col(p.Color))
    end
   end
  end
 end
 return out
end
local function patchDiscs()
 local out={};local function walk(f)
  for _,d in ipairs(f:GetChildren())do
   if d.Name=='Snow patch'and d.CFrame.Position.Y>0 and d.Transparency<1 then
    local q=d.CFrame.Position;local look=d.CFrame.LookVector;local yaw=math.atan2(-look.X,-look.Z)
    out[#out+1]=string.format('{"p":[%s,%s,%s],"s":[%s,%s,%s],"yaw":%s,"t":%s,"c":%s}',n(q.X),n(q.Y),n(q.Z),n(d.Size.X),n(d.Size.Y),n(d.Size.Z),n(yaw),n(d.Transparency),col(d.Color))
   end
  end
 end
 for _,name in ipairs({'_WeatherWorldR149','_SnowBiomeR149'})do
  local f=workspace:FindFirstChild(name)
  if f then if name=='_SnowBiomeR149'then walk(f)else local pf=f:FindFirstChild('Snow patches');if pf then walk(pf)end end end
 end
 return out
end
local function tiles()
 local out={};local f=workspace:FindFirstChild('_WeatherWorldR149');if not f then return out end
 local sky=f:FindFirstChild('Sky tiles'):GetChildren();local gr=f:FindFirstChild('Ground tiles'):GetChildren()
 for i,t in ipairs(sky)do
  local e=t:FindFirstChildWhichIsA('ParticleEmitter')
  if e.Enabled==true and e.Rate>0 then
   local p,s=t.CFrame.Position,t.Size;local g=gr[i];local spray,ring=g:FindFirstChild('Splash spray'),g:FindFirstChild('Splash ripple')
   out[#out+1]=string.format('{"c":[%s,%s,%s],"s":[%s,%s],"rate":%s,"sp":[%s,%s],"life":[%s,%s],"acc":[%s,%s,%s],"spread":%s,"snow":%s,"gy":%s,"spray":[%s,%s],"ripple":[%s,%s]}',
    n(p.X),n(p.Y),n(p.Z),n(s.X),n(s.Z),n(e.Rate),n(e.Speed.Min),n(e.Speed.Max),n(e.Lifetime.Min),n(e.Lifetime.Max),n(e.Acceleration.X),n(e.Acceleration.Y),n(e.Acceleration.Z),
    n(e.SpreadAngle.X),tostring(e.Orientation.Name=='FacingCamera'),n(g.CFrame.Position.Y),spray.Enabled and n(spray.Rate)or'0',n((spray.Lifetime.Min+spray.Lifetime.Max)/2),ring.Enabled and n(ring.Rate)or'0',n((ring.Lifetime.Min+ring.Lifetime.Max)/2))
  end
 end
 return out
end
local function plotJson()
 local out={};for _,p in ipairs(plots)do out[#out+1]=string.format('[%s,%s,%s,%s]',n(p.x),n(p.z),n(p.hx),n(p.hz))end
 return '['..table.concat(out,',')..']'
end
local area=WW.Area(map)
local function scene(name,player3,extra)
 local p=root.CFrame.Position
 print(string.format('SCENE %s {"tiles":[%s],"patches":[%s],"keys":[%s],"plots":%s,"track":[%s,%s,%s,%s],"ground":%s,"player":[%s,%s,%s]%s}',name,table.concat(tiles(),','),table.concat(patchDiscs(),','),
  table.concat(keyParts(),','),plotJson(),n(area.X0),n(area.X1),n(area.Z0),n(area.Z1),n(GROUND),n(p.X),n(p.Y),n(p.Z),extra or''))
end

runnerAt(20,-140)
-- the camera looks down the track (+Z), as the runner's does: the keyboard turns its long side toward the camera's facing (the mock's default camera
-- looks toward -Z, which would build the rows ahead of the runner toward the base)
workspace.CurrentCamera.CFrame=R.CFrame.lookAt(V3(0,20,0),V3(0,20,100))
RS:SetAttribute('GlobalWeather','Clear')
local kb=R.new('LocalScript');kb.Name='KeyboardTrack';W.load('KeyboardTrackClient',kb)
local ww=R.new('LocalScript');ww.Name='WeatherWorld149';W.load('WeatherWorld',ww)
local sb=R.new('LocalScript');sb.Name='SnowBiome149';W.load('SnowBiome',sb)
frames(2)
RS:SetAttribute('GlobalWeather','Rain');frames(5)
scene('rain')
RS:SetAttribute('GlobalWeather','Blizzard');frames(35)
scene('blizzard')
RS:SetAttribute('GlobalWeather','Clear');frames(60)
runnerAt(0,1228);frames(6)
scene('snowbiome')
