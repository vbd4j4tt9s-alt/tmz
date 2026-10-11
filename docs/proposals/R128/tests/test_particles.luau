--!nocheck
-- R128: biome particles live in the world (real BiomeWeather + AmbientParticleField128). Particles are not locked to
-- the moving box, the box follows every frame and leads a runner, fast running never wipes the field, a teleport does,
-- and the emission rates are the same as before (no extra particles).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local clears=0;R.Inst.Clear=function(self)if self:IsA('ParticleEmitter')then clears+=1 end end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
me.CharacterRemoving=R.signal();me.CharacterAdded=R.signal()
local char=R.new('Model');char.Name='Me';local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(0,5,20);hrp.Parent=char;char.Parent=W.workspace;me.Character=char
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace;map:SetAttribute('FieldWidth',180)
local bounds={[1]={0,400},[6]={400,900},[3]={900,1400}}
for id,b in pairs(bounds)do map:SetAttribute('BiomeStartZ_'..id,b[1]);map:SetAttribute('BiomeEndZ_'..id,b[2])end
local cam=W.workspace.CurrentCamera
local Styles=W.module('BiomeWeatherConfig');local Field=W.module('AmbientParticleField128')
local sc=R.new('LocalScript');W.load('BiomeWeather',sc)
local folder=W.workspace:FindFirstChild('_BiomeWeatherV105');local anchor=folder and folder:FindFirstChild('Weather around camera')
check(anchor~=nil,'weather box exists')
local function at(z,look)hrp.CFrame=CF(0,5,z);cam.CFrame=R.CFrame.lookAt(V3(0,12,z-14),V3(0,12,z-14)+(look or V3(0,0,1)))end
local function emitter()for _,c in ipairs(anchor:GetChildren())do if c:IsA('ParticleEmitter')and c.Name~='Jungle mist'then return c end end end
local function mist()return anchor:FindFirstChild('Jungle mist')end
-- Forest, standing
at(100);W.frames(20)
local e=emitter()
check(e and e.Name==Styles[1].Name,'Forest pollen running ('..tostring(e and e.Name)..')')
check(e and e.LockedToPart==false,'pollen is NOT locked to the moving box: particles stay where they are born')
check(e and e.VelocityInheritance==0,'box motion adds no speed to particles')
W.frames(60);check(e.Rate==Styles[1].Rate,'same emission rate as before ('..tostring(e.Rate)..')')
-- The box follows every frame, not 20 times a second.
local moved,last=0,anchor.CFrame.Position
for i=1,12 do at(100+i*.5);W.frames(1);local p=anchor.CFrame.Position;if (p-last).Magnitude>1e-6 then moved+=1 end;last=p end
check(moved>=11,'box moves every frame while walking ('..moved..'/12)')
-- Walking forward at 30 studs/s: the box leads ahead of the camera (particles appear ahead, you walk through them).
local z=110;for _=1,90 do z+=30/60;at(z);W.frames(1)end
local camPos=cam.CFrame.Position;local lead=anchor.CFrame.Position.Z-(camPos.Z+9)
check(lead>12 and lead<=Field.FloatMaxLead+1e-6,('runner lead %.1f studs (~0.6 s ahead)'):format(lead))
-- Very fast running (400 studs/s) never wipes the field; a teleport does.
z=100;at(z);W.frames(12);clears=0;for _=1,40 do z+=400/60;at(z);W.frames(1)end -- 100 -> ~367, all Forest
check(clears==0,'fast running does not clear the particles ('..clears..' clears)')
local lead2=anchor.CFrame.Position.Z-(cam.CFrame.Position.Z+9);check(lead2<=Field.FloatMaxLead+1e-6,('lead capped at %d studs (%.1f)'):format(Field.FloatMaxLead,lead2))
at(380);W.frames(12);clears=0;at(60);W.frames(12)
check(clears>=1,'a teleport (BASE/TRACK) drops the old field')
-- Jungle: fireflies + mist, both world-space
at(600);W.frames(30)
e=emitter();check(e and e.Name==Styles[6].Name and e.LockedToPart==false,'Jungle fireflies world-space')
check(mist()and mist().LockedToPart==false and mist().VelocityInheritance==0,'Jungle mist world-space')
-- Snow: falling, led by its fall time so a runner cannot outrun it
at(1000);W.frames(30);for _=1,90 do at(1000+_*20/60);W.frames(1)end
e=emitter();check(e and e.Name==Styles[3].Name and e.LockedToPart==false,'snow world-space')
local fall=Styles[3].Height/Styles[3].Speed;local snowLead=anchor.CFrame.Position.Z-(cam.CFrame.Position.Z+9)
check(math.abs(snowLead-20*fall)<4,('snow led by its fall time (%.1f studs, want ~%.1f)'):format(snowLead,20*fall))
check(math.abs(anchor.CFrame.Position.Y-(cam.CFrame.Position.Y+Styles[3].Height))<1e-6,'snow born '..Styles[3].Height..' studs above')
-- Pure helper checks
local s=Field.new();Field.Track(s,V3(0,0,0),1/60);local v=Field.Track(s,V3(0,0,1),1/60)
check(v.Z>0 and v.Z<60,'velocity smoothed ('..v.Z..')')
Field.Track(s,V3(0,0,500),1/60);check(s.Velocity.Magnitude==0,'teleport resets the velocity')
local l1,c1=Field.Lead(24,55,true);check(math.abs(l1-24/55)<1e-9 and c1==Field.FallMaxLead,'rain lead = fall time')
sc.Destroying:Fire();check(W.workspace:FindFirstChild('_BiomeWeatherV105')==nil,'teardown removes the box')
-- Global rain / blizzard: R149 replaced WorldEvents' camera-following box with world-fixed tiles (WeatherWorld149.client.lua, tests in
-- docs/proposals/R149/tests); the R128 rule (not locked, nothing dragged along) holds there, checked in the source.
do local text=W.B.WeatherWorld149
 check(text:find('e.LockedToPart=false',1,true)~=nil and text:find('LockedToPart=true',1,true)==nil,'global rain/snow tiles are not locked to their part')
 check(W.B.WorldEvents:find('Field.Target',1,true)==nil and text:find('RenderStepped',1,true)==nil and text:find('Field.Target',1,true)==nil,'no camera-following precipitation box any more (R149: tiles are fixed in the world)')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
