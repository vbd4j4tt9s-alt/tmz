--!nocheck
-- R124 performance pass: BiomeEffectGovernor (biome emitters follow the client budget + distance) and GardenLiftPrompts
-- (another player's plant prompts: cached ownership, still kept disabled).
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local function emitterOn(parentPart,name,rate,attach)
 local holder=parentPart
 if attach then local a=R.new('Attachment');a.WorldPosition=parentPart.Position;a.Parent=parentPart;holder=a end
 local e=R.new('ParticleEmitter');e.Name=name;e.Rate=rate;e:SetAttribute('BiomeEffect',true);e.Parent=holder;return e
end
local near=R.new('Part');near.Size=V3(4,4,4);near.CFrame=CF(0,5,20);near.Parent=map
local far=R.new('Part');far.Size=V3(4,4,4);far.CFrame=CF(0,5,900);far.Parent=map
local big=R.new('Part');big.Size=V3(180,10,600);big.CFrame=CF(0,5,500);big.Parent=map -- area emitter: centre far, box reaches us
local plain=R.new('ParticleEmitter');plain.Rate=20;plain.Parent=near -- not a biome effect: never touched
local eNear=emitterOn(near,'CrystalDust',8,true);local eFar=emitterOn(far,'RisingEmbers',11,true);local eBig=emitterOn(big,'WindblownSnow',5,false)
W.workspace.CurrentCamera.CFrame=CF(0,10,0)
W.load('BiomeEffectGovernor',R.new('LocalScript'))
W.frames(80,1/60)
check(eNear.Rate==8,'tier 3, near: built rate ('..eNear.Rate..')')
check(eFar.Rate==0,'far emitter (900 studs) off')
check(eBig.Rate==5,'area emitter whose box reaches the camera stays on (distance to the box, not its centre)')
check(plain.Rate==20,'non-biome emitter untouched')
me:SetAttribute('FastMode',true);W.frames(80,1/60)
check(eNear.Rate==0 and eBig.Rate==0,'FastMode: biome emitters off')
me:SetAttribute('FastMode',false);W.Gui.ReducedMotionEnabled=true;W.frames(80,1/60)
check(eNear.Rate==4 and eBig.Rate==2.5,'ReducedMotion: half rate')
W.Gui.ReducedMotionEnabled=false;W.workspace.CurrentCamera.CFrame=CF(0,10,880);W.frames(80,1/60)
check(eFar.Rate==11 and eNear.Rate==0 and eBig.Rate==5,'moving the camera brings the far one back and drops the now-far one')
local late=emitterOn(far,'CinderSmoke',7,true);W.frames(80,1/60)
check(late.Rate==7,'emitter added later is governed too')
-- GardenLiftPrompts: stub the contact helpers; two gardens.
W.stub('GardenLiftContact',{IsStem=function()return false end,Find=function(model,pos)return model.PrimaryPart.Position+V3(0,2,0)end})
W.stub('PlantPartCache',{new=function(root)return {Root=root,Dead=false,List=function()return {}end,Destroy=function()end}end})
W.stub('PlantCatalog',{Rose={Radius=3}})
me:SetAttribute('DataStatus','Loaded')
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,0);root.Parent=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local function plant(owner,x)
 local m=R.new('Model');m.Name='Plant';m:SetAttribute('GardenOwnerId',owner);m:SetAttribute('SeedId','Rose');m.Parent=map
 local pivot=R.new('Part');pivot.Name='Pivot';pivot.CFrame=CF(x,3,2);pivot.Parent=m;m.PrimaryPart=pivot
 local solid=R.new('Model');solid.Name='SolidPlant';solid.Parent=m
 local a=R.new('Attachment');a.Parent=pivot;local p=R.new('ProximityPrompt');p.Name='PlantTopPrompt';p.Enabled=true;p.Parent=a
 return p
end
local mine=plant(7,0);local theirs=plant(99,1)
W.load('GardenLiftPrompts',R.new('LocalScript'))
W.frames(30,1/60)
check(mine.Enabled==true,'my plant prompt enabled when near')
check(theirs.Enabled==false,'another player\'s prompt disabled')
theirs.Enabled=true;W.frames(12,1/60)
check(theirs.Enabled==false,'another player\'s prompt re-disabled within a tick even between ownership re-checks')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
