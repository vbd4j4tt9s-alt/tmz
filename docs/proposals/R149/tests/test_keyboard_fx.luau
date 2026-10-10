--!nocheck
-- R149 (the new keyboard's resting key tops stand above the floor - 0.55 in R149, 1.2 since R151's deeper press - and the real floor is hidden locally): effects that were authored at
-- floor level must show ON TOP of the keyboard. The real KeyboardTrack.client.lua next to the real StormWeather.client.lua (lightning warning
-- ring, impact ring, ground flash, bolt end), the real TrackHoleClient.client.lua (shovel dirt bursts: Dig / Cover / Trap) and the real
-- ReplicatedStorage.KeyboardSurface149 helper, on the Roblox mock:
--  * on the keyboard: every effect sits at or above the top of the key under it (measured on the dressed key parts), exactly the key rise
--    above where it was authored (a ring authored 0.12 above the floor is 0.12 above the key tops);
--  * where there is no keyboard: exactly the old height (The Darkened's arena past the last row, beside the 180-wide field, a floor already
--    above the key tops, the keyboard script gone, the helper module missing).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return a~=nil and b~=nil and math.abs(a-b)<=(e or 1e-6)end
local RS,workspace=W.RS,W.workspace
local abs,floor,max,min=math.abs,math.floor,math.max,math.min
local K=W.module('KeyboardTrack');local C=K.Config;local F=C.FloorTop
local KS=W.module('KeyboardSurface149');local SC=W.module('StormConfig');local HC=W.module('TrackHoleConfig')
local ATTR={BiomeTrackEndZ=5980,BiomeStartZ_1=-100,BiomeEndZ_1=80,BiomeStartZ_6=80,BiomeEndZ_6=530,BiomeStartZ_2=530,BiomeEndZ_2=1180,
 BiomeStartZ_3=1180,BiomeEndZ_3=2030,BiomeStartZ_4=2030,BiomeEndZ_4=3080,BiomeStartZ_5=3080,BiomeEndZ_5=4380,BiomeStartZ_7=4380,BiomeEndZ_7=5980}
local KEYEND=5980-C.EndMargin                -- the last key row ends here; the Storm floor runs on into The Darkened's arena
local function frames(sec)W.frames(floor(sec*60+.5),1/60)end

-- mock gaps ---------------------------------------------------------------------------------------------------------------------------
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=7;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
function Players.GetPlayers()return {player}end
function workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play()end;function R.Inst.Stop()end
W.service('ContentProvider').PreloadAsync=function()end
W.service('Debris').AddItem=function()end
W.UIS.TouchTapInWorld=R.signal();W.UIS.GamepadEnabled=false
W.service('ContextActionService').BindActionAtPriority=function()end
local tier=3
W.stub('ClientFxBudget',{Get=function()return tier end,Low=function()return tier==1 end})
W.stub('LocalSfx',{Preload=function()end,Play=function()end})
W.stub('DigSoundVariants',{new=function()return {Play=function()end}end})
-- dirt: record where each HoleDirt part starts and the two places its tweens send it (up to the peak, down to the landing spot)
local starts,goals={}, {}
local Tween=W.service('TweenService')
function Tween.Create(_,obj,_,props)
 if obj.Name=='HoleDirt'and props.CFrame then
  if not starts[obj]then starts[obj]=obj.CFrame.Position;goals[obj]={}end
  table.insert(goals[obj],props.CFrame.Position)
 end
 return {Play=function()end,Cancel=function()end,Completed=R.signal()}
end
-- the lightning bolt: record where each strike ends
local strikes={}
do local WL=W.module('WeatherLightning');local orig=WL.Strike
 WL.Strike=function(self,top,bottom,...)strikes[#strikes+1]={Top=top,Bottom=bottom};return orig(self,top,bottom,...)end end

-- the world: the track's Storm floor (top at the keyboard's floor height, running into the arena), the keycap, the runner, the remotes -----
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace
for k,v in pairs(ATTR)do map:SetAttribute(k,v)end
local obby=R.new('Folder');obby.Name='Obby';obby.Parent=map
local biomes=R.new('Folder');biomes.Name='Biomes';biomes.Parent=obby
local stormModel=R.new('Model');stormModel.Name='Storm Peaks';stormModel:SetAttribute('Stage',SC.Stage);stormModel.Parent=biomes
local ground=R.new('Part');ground.Name='BiomeGround_'..SC.Stage;ground.Size=V3(180,4,1600);ground.CFrame=CF(0,2,5180);ground.Anchored=true;ground.Archivable=true;ground.Parent=stormModel
local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55)
local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=RS
local model=R.new('Model');model.Name='Tester'
local rootPart=R.new('Part');rootPart.Name='HumanoidRootPart';rootPart.Size=V3(2,2,1);rootPart.CFrame=CF(0,F+3,5000);rootPart.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.Parent=model;model.PrimaryPart=rootPart;model.Parent=workspace;player.Character=model
local camera=workspace.CurrentCamera
local function lookFrom(z)camera.CFrame=R.CFrame.lookAt(V3(0,20,z),V3(0,20,z+100))end   -- the camera looks down the track (+Z)
lookFrom(5000)
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local state=R.new('RemoteEvent');state.Name='StormState';state.Parent=remotes
local holeRemote=R.new('RemoteEvent');holeRemote.Name='TrackHole';holeRemote.OnClientEvent=R.signal();holeRemote.FireServer=function()end;holeRemote.Parent=remotes
local assets=R.new('Folder');assets.Name='ChestChaseVisualAssets';assets.Parent=RS
local cloudModel=R.new('Model');cloudModel.Name='DarkCloud';cloudModel.Parent=assets
local puff=R.new('Part');puff.Name='Puff';puff.Size=V3(30,10,30);puff.Parent=cloudModel
local host=R.new('Folder');host.Name='StarterPlayerScripts';host.Parent=W.service('StarterPlayer')
local function load(name,key)local s=R.new('LocalScript');s.Name=name;s.Parent=host;W.load(key,s);return s end
local kb=load('KeyboardTrack','KeyboardTrackClient')
frames(1.5)
local sw=load('StormWeather','StormWeather')
local th=load('TrackHoleClient','TrackHoleClient')
frames(1)

-- helpers ---------------------------------------------------------------------------------------------------------------------------------
local function keyTopNear(x,z)       -- the highest top among the dressed keys within a pitch of (x, z)
 local vis=workspace:FindFirstChild('KeyboardTrackVisuals');local keysF=vis and vis:FindFirstChild('Keys');if not keysF then return nil end
 local top=nil
 for _,p in ipairs(keysF:GetChildren())do
  local q=p.CFrame.Position
  if p.Name=='Key'and p.Transparency==0 and q.Y>0 and abs(q.X-x)<=C.Pitch and abs(q.Z-z)<=C.Pitch then
   local t=q.Y+p.Size.Y/2;if not top or t>top then top=t end
  end
 end
 return top
end
local function stormParts(name)
 local out={};local f=workspace:FindFirstChild('_StormVisualsV103');if not f then return out end
 for _,p in ipairs(f:GetChildren())do if p.Name==name then out[#out+1]=p end end
 return out
end
local strikeId=0
local function warn(center)          -- a new strike in its warning phase; returns the ring
 strikeId+=1;local now=workspace:GetServerTimeNow()
 state:SetAttribute('StrikeId',strikeId);state:SetAttribute('Center',center);state:SetAttribute('Radius',SC.Radius)
 state:SetAttribute('StartAt',now);state:SetAttribute('HitAt',now+SC.WarningSeconds);state:SetAttribute('Phase','Warning')
 frames(.3)
 local rings=stormParts('Lightning warning')
 return rings[#rings],#rings
end
local function impact()              -- the same strike lands: returns the impact ring, the flash and where the bolt ended
 local now=workspace:GetServerTimeNow()
 state:SetAttribute('HitAt',now);state:SetAttribute('StartAt',now-SC.WarningSeconds);state:SetAttribute('Phase','Impact')
 local before=#strikes
 frames(.1)
 local rings,flashes=stormParts('Impact ring'),stormParts('Ground flash')
 return rings[#rings],flashes[#flashes],#strikes>before and strikes[#strikes].Bottom or nil
end
local function clearStorm()state:SetAttribute('Phase','Idle');frames(1.8)end   -- the impact effects fade (ImpactSeconds .65)
local function dirt(kind,pos)        -- a hole fx event: the dirt parts with where they start / peak / land
 for _,p in ipairs(workspace:GetChildren())do if p.Name=='HoleDirt'then p:Destroy()end end
 starts,goals={}, {}
 holeRemote.OnClientEvent:Fire({Kind=kind,Id=1,Position=pos,OwnerUserId=7})
 local out={}
 for _,p in ipairs(workspace:GetChildren())do if p.Name=='HoleDirt'and starts[p]then out[#out+1]={Start=starts[p],Peak=goals[p][1],Land=goals[p][2]}end end
 return out
end
local function lowest(list)          -- lowest centre of every dirt part's start / peak / landing spot
 local lo=math.huge;for _,d in ipairs(list)do lo=min(lo,d.Start.Y,d.Peak.Y,d.Land.Y)end;return lo
end
local function dirtAt(list,base,tol) -- every part starts .2 above `base` and lands s*.4 (.072 .. .184) above it, whatever the kind
 local ok=#list>0
 for _,d in ipairs(list)do
  if not near(d.Start.Y,base+.2,tol or 1e-6)or d.Land.Y<base+.072-1e-6 or d.Land.Y>base+.184+1e-6 or d.Peak.Y<base+.5 then ok=false end
 end
 return ok
end

-- 0. the keyboard is built and the helper reads it ---------------------------------------------------------------------------------------------
local vis=workspace:FindFirstChild('KeyboardTrackVisuals')
check(vis~=nil and vis:FindFirstChild('Keys')~=nil and ground.LocalTransparencyModifier==1,'the keyboard is up around the runner and the real Storm floor is hidden')
local RISE=K.KeyTop(0)-F
check(near(RISE,C.RestRise)and near(RISE,1.2),'the resting key tops are '..string.format('%.2f',RISE)..' above the floor (R151: 1.2, a press travels 1.15; effects lift by whatever the rise is)')
local X,Z=10,5030
local keyTop=keyTopNear(X,Z)
check(keyTop~=nil and near(keyTop,K.KeyTop(0)),'the dressed key under the test spot has its top at K.KeyTop(0) ('..tostring(keyTop)..')')
check(near(KS.TopY(X,Z),keyTop)and near(KS.Lift(X,Z,F),RISE),'KeyboardSurface149 reads the key top live: Lift = key top - floor = '..string.format('%.2f',KS.Lift(X,Z,F)))
local x0,x1,z0,z1=KS.Rect()
check(near(x0,-90)and near(x1,90)and near(z0,-100)and near(z1,KEYEND),'it covers the 180-wide field from the first biome to the last row (z '..tostring(z0)..' .. '..tostring(z1)..')')
check(KS.Lift(100,Z,F)==0 and KS.Lift(-91,Z,F)==0 and KS.Lift(X,KEYEND+10,F)==0 and KS.Lift(X,-120,F)==0 and KS.TopY(X,KEYEND+10)==nil,'no lift beside the field, in the arena past the last row, or before the first biome')
check(KS.Lift(X,Z,K.KeyTop(0)+2)==0 and near(KS.Lift(X,Z,K.KeyTop(0)-.2),.2),'it never lowers a surface that is already above the key tops, and tops up one just below them')

-- 1. Storm warning ring, impact ring, flash and bolt on the keyboard ---------------------------------------------------------------------------
local OLD=F+.12                      -- where the server authors a strike centre (StormArea.Choose: .12 above the floor)
local ring,rings=warn(V3(X,OLD,Z))
check(ring~=nil and rings==1,'the warning ring is drawn ('..rings..')')
check(near(ring.CFrame.Position.Y,OLD+RISE)and near(ring.CFrame.Position.X,X)and near(ring.CFrame.Position.Z,Z),
 'on the keyboard the warning ring is lifted by the key rise: y '..string.format('%.3f',ring.CFrame.Position.Y)..' (was '..OLD..' at floor level)')
check(ring.CFrame.Position.Y-ring.Size.Y/2>=keyTop-1e-6,'its underside is at or above the top of the key under it ('..string.format('%.3f',ring.CFrame.Position.Y-ring.Size.Y/2)..' >= '..string.format('%.3f',keyTop)..')')
check(ring.Size.X==SC.Radius*2 and ring.Transparency==1 and ring:FindFirstChild('Strike area')~=nil,'...same ring: radius, SurfaceGui on its top face')
local iring,flash,bottom=impact()
check(iring~=nil and flash~=nil and bottom~=nil,'the impact draws a ring, a ground flash and a bolt')
check(near(iring.CFrame.Position.Y,OLD+.06+RISE)and iring.CFrame.Position.Y-iring.Size.Y/2>=keyTop-1e-6,'the impact ring is on the key tops (y '..string.format('%.3f',iring.CFrame.Position.Y)..')')
check(near(flash.CFrame.Position.Y,OLD+.08+RISE)and flash.CFrame.Position.Y-flash.Size.X/2>=keyTop-1e-6,'the ground flash is on the key tops (y '..string.format('%.3f',flash.CFrame.Position.Y)..')')
check(near(bottom.Y,OLD+RISE)and bottom.Y>=keyTop,'the bolt ends on the key tops, not under them (y '..string.format('%.3f',bottom.Y)..')')
clearStorm()
-- a second spot, near the +X edge of the field and 600 studs from the runner: the same key rise
lookFrom(5500)
local ring2=warn(V3(80,OLD,5560));local top2=keyTopNear(80,5560)
check(ring2~=nil and near(ring2.CFrame.Position.Y,OLD+RISE)and(top2==nil or ring2.CFrame.Position.Y-ring2.Size.Y/2>=top2-1e-6),'the same at the +X edge of the field, 560 studs ahead of the runner')
clearStorm();lookFrom(5000)

-- 2. shovel dirt on the keyboard ------------------------------------------------------------------------------------------------------------
local FLOOR=V3(X,F,Z)                -- the server's hole position: the floor surface
for _,case in ipairs({{'Dig',8},{'Cover',6},{'Trap',10}})do
 local list=dirt(case[1],FLOOR)
 check(#list==case[2],case[1]..': '..#list..' dirt chunks ('..case[2]..' expected at tier 3)')
 check(lowest(list)>=keyTop-1e-6,case[1]..': every chunk starts, peaks and lands at or above the key top (lowest centre '..string.format('%.3f',lowest(list))..' >= '..string.format('%.3f',keyTop)..')')
 check(dirtAt(list,F+RISE),case[1]..': the burst is the old burst moved up by the key rise (start .2, landing .07 .. .18 above the key tops)')
end
-- a hole at the +X edge of the keyboard
check(lowest(dirt('Dig',V3(88,F,Z)))>=keyTopNear(88,Z)-1e-6,'a hole at the +X edge of the keys is lifted too')
local tossOk=true;for _,d in ipairs(dirt('Dig',FLOOR))do local h=d.Peak.Y-d.Start.Y;if h<1.99 or h>3.01 then tossOk=false end end
check(tossOk,'the toss height is unchanged: the peak is 2.2 - .2 + 0 .. 1 studs above where a chunk starts')

-- 3. no keyboard under the effect: the old height, exactly -------------------------------------------------------------------------------------
-- 3a. beside the field (the track is wider than the 180-wide keyboard): a hole at x = 100
check(dirtAt(dirt('Dig',V3(100,F,Z)),F),'a hole beside the keyboard (x = 100): dirt at the old height')
-- 3b. The Darkened's arena: the Storm floor runs past the last key row
lookFrom(5850)
local arenaZ=KEYEND+30
local ringA=warn(V3(X,OLD,arenaZ))
check(ringA~=nil and near(ringA.CFrame.Position.Y,OLD),'in the arena (past the last key row, z '..arenaZ..') the warning ring stays at the old height ('..string.format('%.3f',ringA.CFrame.Position.Y)..')')
local iringA,flashA,bottomA=impact()
check(iringA~=nil and near(iringA.CFrame.Position.Y,OLD+.06)and near(flashA.CFrame.Position.Y,OLD+.08)and near(bottomA.Y,OLD),'...and so do the impact ring, the flash and the bolt end')
check(dirtAt(dirt('Dig',V3(X,F,arenaZ)),F)and dirtAt(dirt('Trap',V3(X,F,arenaZ)),F),'...and the dirt of a hole in the arena')
clearStorm();lookFrom(5000)
-- 3c. a floor that is already above the key tops is not lowered
check(dirtAt(dirt('Dig',V3(X,keyTop+1,Z)),keyTop+1),'a surface above the key tops (y '..string.format('%.2f',keyTop+1)..') is not lowered')
-- 3d. the lift is exact at the edges of the covered rectangle
check(KS.Lift(90,Z,F)>0 and KS.Lift(90.01,Z,F)==0 and KS.Lift(X,KEYEND-.01,F)>0 and KS.Lift(X,KEYEND,F)==0,'the covered rectangle ends where the keys do (x 90, z '..KEYEND..')')

-- 4. the helper missing (a partial install): the effects keep working at the old height, no error ----------------------------------------
do
 local helper=RS:FindFirstChild('KeyboardSurface149');helper.Parent=nil
 local ringM=warn(V3(X,OLD,Z))
 check(ringM~=nil and near(ringM.CFrame.Position.Y,OLD),'without the helper module the ring is drawn at the old height')
 local iM,fM=impact()
 check(iM~=nil and fM~=nil,'...the impact too')
 check(dirtAt(dirt('Dig',FLOOR),F),'...and the dirt burst')
 helper.Parent=RS;clearStorm()
end

-- 5. the keyboard goes (its script is destroyed): the effects are back at floor level ----------------------------------------------------------
kb.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil and KS.Lift(X,Z,F)==0 and KS.TopY(X,Z)==nil,'the keyboard folder is gone and the helper gives no lift')
local ringG=warn(V3(X,OLD,Z))
check(ringG~=nil and near(ringG.CFrame.Position.Y,OLD),'without the keyboard the warning ring is at the old height again ('..string.format('%.3f',ringG.CFrame.Position.Y)..')')
local iG,fG,bG=impact()
check(iG~=nil and near(iG.CFrame.Position.Y,OLD+.06)and near(fG.CFrame.Position.Y,OLD+.08)and near(bG.Y,OLD),'...and so are the impact ring, the flash and the bolt end')
check(dirtAt(dirt('Dig',FLOOR),F),'...and the dirt burst')
check((W.warns or 0)==0,'no warnings from any script ('..tostring(W.warns)..')')

print(string.format('%s: %d checks, %d failures',fails==0 and'PASS'or'FAIL',checks,fails))
if fails>0 then error('failures',0)end
