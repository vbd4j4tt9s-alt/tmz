--!nocheck
-- R128: weather/Mech effects on an item someone carries follow it every frame (real ItemCosmetics + ItemVisualEffects);
-- items lying in the world keep the 20 Hz animation. Plus source checks for the pack aura, Void Pack and held fruit loops.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
local char=R.new('Model');char.Name='Me';local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(0,5,20);hrp.Parent=char;char.Parent=W.workspace;me.Character=char
local cam=W.workspace.CurrentCamera;cam.CFrame=R.CFrame.lookAt(V3(25,10,-10),V3(25,5,20));cam.FieldOfView=70
local function item(parent,x,name)
 local p=R.new('Part');p.Name=name;p.Size=V3(1,1,1);p.CFrame=CF(x,5,20);p.Parent=parent
 p:SetAttribute('WeatherTrait','Frosted');p:SetAttribute('EffectRadius',1.2);p:SetAttribute('EffectHeight',2)
 W.CS:AddTag(p,'GardenItemFX');return p
end
local tool=R.new('Tool');tool.Name='Seed';tool.Parent=char
local held=item(tool,0,'Handle')
local world=item(W.workspace,50,'WorldPacket')
W.load('ItemCosmetics',R.new('LocalScript'))
W.frames(40)
local folder=W.workspace:FindFirstChild('_ItemCosmeticsR59')
local sets=folder and folder:GetChildren()or{}
check(#sets==2,'two effect sets made ('..#sets..')')
local heldSet,worldSet
for _,f in ipairs(sets)do local first=f:GetChildren()[1];if first then
 if math.abs(first.CFrame.Position.X)<10 then heldSet=f else worldSet=f end end end
check(heldSet and worldSet,'effect sets found for the carried and the world item')
local function probe(f)return f:GetChildren()[1].CFrame.Position end
-- Run: both items move 0.5 studs per frame (the world one stands for an unusual moving loose item).
local heldMoves,worldMoves,lastH,lastW=0,0,probe(heldSet),probe(worldSet);local worst=0
for i=1,30 do
 held.CFrame=CF(i*.5,5,20);world.CFrame=CF(50+i*.5,5,20);W.frames(1)
 local h,w=probe(heldSet),probe(worldSet)
 if (h-lastH).Magnitude>1e-6 then heldMoves+=1 end;if (w-lastW).Magnitude>1e-6 then worldMoves+=1 end
 lastH,lastW=h,w
 worst=math.max(worst,math.abs((h.X-held.CFrame.Position.X)))
end
check(heldMoves>=29,'carried item effect follows every frame ('..heldMoves..'/30)')
check(worst<=1.2*1.1+.05,('carried effect never trails the item (worst sideways gap %.2f studs)'):format(worst))
check(worldMoves<=12,'world item keeps the cheaper 20 Hz animation ('..worldMoves..'/30)')
-- Source checks for the other three held-effect loops (their worlds are too large for this mock).
local function has(name,text)return W.B[name]and W.B[name]:find(text,1,true)~=nil end
check(has('SeedPackRender','if fx and(polish or carried)then'),'pack aura/orbit frames follow a carried pack every frame')
check(has('SeedPackRender','if r.MechMotion and(worldMoved or carried or'),'carried Mech pack rig steps every frame')
check(has('HeldHarvestRig','function Rig.Follow(r,t)'),'held fruit effects have a per-frame follow')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
