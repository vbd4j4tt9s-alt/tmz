--!nocheck
-- R153 follow-up: a press that skips or closes a pull reveal's card is the reveal's, never also the held tool's (coordinator: "a click / tap
-- that skips or closes a card also activates the newly equipped seed tool: in a garden that could plant the seed, or the shovel could remove
-- a plant"). On the Roblox mock with the REAL RarePullCinematic (card, sounds) and RarePullRules.ClaimPress, the REAL GardenShovel,
-- TrackHoleClient and FruitGiftClient, and EconomyClient's planting routes run from its own source (that script does not run on the mock):
--  1. planting, a seed in hand: no reveal: a click / tap / R2 plants, as before. A card up: the click / tap / R2 that skips it, and the one
--     that closes it, plant nothing; a press the card does not take (before it can be skipped) still plants; once the card is gone the
--     next press plants. (The planting routes connect BEFORE the card's listener: the tool's route asks first and the card still skips.)
--  2. the shovel, a plant aimed at: the press that skips / closes opens no removal and asks the server nothing; after the card it does.
--     (GardenShovel connects AFTER the card's listener: the card asks first.)
--  3. digging on the track with the shovel, and 4. giving a held seed to a nearby player: the same.
--  5. tools the engine activates on a click (a pack, the bat): ManualActivationOnly on this client exactly while a press would be the
--     reveal's (a card that would take it; the whole story scene), put back as soon as a press would be the tool's again, on a tool swap
--     and when the reveal ends; a tool that is manual already (a seed, the shovel) is never touched.
--  6. a story scene owns every press: R2 through the garden's action plants nothing, the gift's R2 opens nothing.
-- R154 (owner: "... the seed stays on the player's screen until they click and the seed goes to their inventory"): the press after the result
-- now COLLECTS it (R153: closed it) and is just as much the reveal's; while the result WAITS (as long as it takes) every press is the reveal's:
-- the first one collects it, none reaches the tool; the pack / the bat stay manual the whole wait; once collected the tools work at once.
--  7. the seed of the pull is not "in the hand" for planting until it has flown in (EconomyClient: equippedGardenSeed, from its source).
-- R155 (owner: "for some cutscenes u can skip it by spam clicking disable this feature and u can only skip at the bottom right of the
-- screen"): a click / tap never skips; it is the reveal's from the card's FIRST frame (nothing plants, digs, gives or swings until it is
-- collected), the SKIP button skips (and R2 / B: through a tool's own R2 action too), the pack / the bat stay manual the whole card.
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local noop=function()end
local UIS=W.UIS;local UT,KC=R.Enum.UserInputType,R.Enum.KeyCode
do local mt=getmetatable(R.Vector2.new(0,0)) -- (the scripts aim gamepad presses at the screen centre: ViewportSize / 2, * .5)
 mt.__div=mt.__div or function(a,k)return R.Vector2.new(a.X/k,a.Y/k)end;mt.__mul=mt.__mul or function(a,k)return R.Vector2.new(a.X*k,a.Y*k)end end
UIS.TouchTapInWorld=UIS.TouchTapInWorld or R.signal()
function UIS.GetMouseLocation()return R.Vector2.new(640,360)end
UIS.GamepadEnabled=false
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Visuals=W.module('SeedPackVisuals');local Collect=W.module('SeedCollect154')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
local Players=W.service('Players')
-- the CAS actions the tool scripts bind (the mock keeps only the function)
local CAS=W.service('ContextActionService');function CAS.BindActionAtPriority(_,name,fn)W.actions[name]=fn end
-- remotes
local remotes=W.RS:FindFirstChild('ChestChaseRemotes')
local garden=R.Instance.new('RemoteFunction');garden.Name='GardenInteract';garden.Parent=remotes
local removes=0;function garden.InvokeServer(_,action)if action=='Remove'then removes+=1 end;return {Success=true}end
local digs=0;local holeRemote=R.Instance.new('RemoteEvent');holeRemote.Name='TrackHole';holeRemote.OnClientEvent=R.signal();holeRemote.FireServer=function()digs+=1 end;holeRemote.Parent=remotes
local gifts=0;local giftRemote=R.Instance.new('RemoteEvent');giftRemote.Name='FruitGift';giftRemote.OnClientEvent=R.signal();giftRemote.FireServer=function()gifts+=1 end;giftRemote.Parent=remotes
W.stub('NoticeFeed83',{Gift=noop,Push=noop,Plain=noop})
-- what the camera ray hits: soil, my plant, another player, the track ground
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local soil=R.new('Part');soil.Name='Soil';soil:SetAttribute('GardenSoil',true);soil.CFrame=CF(0,0,104);soil.Parent=W.workspace
local Catalog=W.module('PlantCatalog');local seedId='SunflowerSeed'
local plant=R.new('Model');plant.Name='Plant_1';plant:SetAttribute('GardenPlantV141',true);plant:SetAttribute('GardenOwnerId',X.player.UserId)
plant:SetAttribute('SeedId',seedId);plant:SetAttribute('CropId','crop-1');plant.Parent=map
local stem=R.new('Part');stem.Name='Stem';stem.Size=V3(1,2,1);stem.CFrame=CF(3,2,100);stem.LocalTransparencyModifier=0;stem.Parent=plant;plant:PivotTo(CF(3,0,100))
local friend=R.new('Player');friend.Name='Friend';friend.DisplayName='Friend';friend.UserId=99;friend.Parent=Players
local fchar=R.new('Model');fchar.Name='Friend';fchar.Parent=W.workspace;friend.Character=fchar
local froot=R.new('Part');froot.Name='HumanoidRootPart';froot.CFrame=CF(6,3,100);froot.Parent=fchar
function Players.GetPlayerFromCharacter(_,c)if c==X.char then return X.player end;if c==fchar then return friend end;return nil end
local aim='soil'
function W.workspace.Raycast()
 if aim=='plant'then return {Instance=stem,Position=V3(3,1,100),Normal=V3(0,1,0)}end
 if aim=='friend'then return {Instance=froot,Position=froot.Position,Normal=V3(0,0,1)}end
 return {Instance=soil,Position=V3(0,0,104),Normal=V3(0,1,0)}
end
cam.ViewportPointToRay=function()return {Origin=V3(0,10,90),Direction=V3(0,-.5,1).Unit}end
cam.WorldToViewportPoint=function()return V3(640,360,10),true end
W.env.RaycastParams={new=function()return {}end}
-- tools in the hand (one at a time, as the hotbar does)
local function tool(name,attrs,manual)
 local t=R.new('Tool');t.Name=name;t.Enabled=true;t.ManualActivationOnly=manual;for k,v in pairs(attrs)do t:SetAttribute(k,v)end;t.Parent=E.bag;return t
end
local function hold(t)for _,c in ipairs(X.char:GetChildren())do if c:IsA('Tool')then c.Parent=E.bag end end;if t then t.Parent=X.char end end
local seed=tool('Sunflower Seed',{GardenSeed=true,SeedInventoryId='seed-1'},true)
local shovel=tool('Shovel',{GardenShovel=true},true)
local packTool=tool('Seed Pack',{SeedPackTool=true,SeedInventoryId='pack-2'},false)
local bat=tool('Bat',{ChestChaseBat=true},false)
-- 1a. EconomyClient's planting routes, from its source, connected BEFORE the card's listener --------------------------------------------------
local placed=0
do
 local src=W.B.EconomyClient
 local a=src:find('local function revealPress',1,true)
 local tail='UserInputService.TouchTapInWorld:Connect(function(position, processed)\n\tif not processed then placeAt(position, false) end\nend)'
 local _,b=src:find(tail,a,true)
 check(a and b,'EconomyClient: the planting routes are found in its source (revealPress, placeAt, mouse / R2 / tap)')
 local env=setmetatable({gardenBusy=false,playerGui=X.pg,UserInputService=UIS,ContextActionService=CAS,Players=Players,
  equippedGardenSeed=function()return seed.Parent==X.char and seed or nil end,rayAt=function()return W.workspace:Raycast()end,
  gardenToast=noop,sendGarden=function(action)if action=='Place'then placed+=1 end end},{__index=W.env})
 local f=loadstring(src:sub(a,b),'=EconomyClient planting');setfenv(f,env);f()
 local placeAt=src:sub(a,b):match('local function placeAt%b()(.-)\nend')
 check(placeAt and placeAt:find('if not seed or revealPress() then return end',1,true)and placeAt:find('revealPress',1,true)<placeAt:find('sendGarden',1,true),'EconomyClient: placeAt asks RarePullRules.ClaimPress before it plants')
end
-- the card's listener (the director, bound as PackOpeningFeedback binds it), then the other tool scripts
local holder=R.new('LocalScript');holder.Name='PackOpeningFeedback';M.Bind(holder)
for _,n in ipairs({'GardenShovel','TrackHoleClient','FruitGiftClient'})do
 local s=R.new('LocalScript');s.Name=n;local ok,err=pcall(W.load,n,s);check(ok,'the real '..n..' loads: '..tostring(err))
end
local shovelBox;do local g=X.pg:FindFirstChild('GardenShovelUI');shovelBox=g and g:FindFirstChildOfClass('Frame')end
local giftDialog;do local g=X.pg:FindFirstChild('FruitGifts');giftDialog=g and g:FindFirstChild('GiftConfirm')end
-- presses
local function click()UIS.InputBegan:Fire({UserInputType=UT.MouseButton1,KeyCode=KC.Unknown,Position=V3(640,360,0)},false)end
local function tap()
 local input={UserInputType=UT.Touch,KeyCode=KC.Unknown,Position=V3(300,200,0)}
 UIS.InputBegan:Fire(input,false);UIS.InputEnded:Fire(input,false);UIS.TouchTapInWorld:Fire(R.Vector2.new(300,200),false)
end
-- R2: the engine runs the top CAS action for it and tells UserInputService the input was processed (R155: and R2 is down meanwhile)
local r2Down=false
function UIS.IsGamepadButtonDown(_,pad,k)return r2Down and pad==UT.Gamepad1 and k==KC.ButtonR2 end
local function r2(action)
 r2Down=true
 local fn=action and W.actions[action];local r=fn and fn(action,R.Enum.UserInputState.Begin,{KeyCode=KC.ButtonR2})
 UIS.InputBegan:Fire({UserInputType=UT.Gamepad1,KeyCode=KC.ButtonR2,Position=V3(0,0,0)},fn~=nil and r==R.Enum.ContextActionResult.Sink)
 r2Down=false
end
-- R155: the SKIP button at the bottom right
local function skipButton()local b=X.find(X.pg,'Skip button');if b and b.Visible then b.Activated:Fire()end end
-- (a press during the animation: R2 is the SKIP button's key and skips; a click / tap does nothing, then the SKIP button skips)
local function skipWith(run,how,press,tag,what)
 press()
 if run.TL.SkipFrom==nil then
  -- R157 (owner: "the skip button only appears for secret and above"): a Common..Mythic card has no SKIP button: R2 / a click / a tap skip nothing, and the press is
  -- still the reveal's (the tool does nothing)
  X.run(.15);skipButton()
  check(not run.Skipped and X.find(X.pg,'Skip button')==nil and what(),tag..': R157: a '..how..' during the animation neither skips (no SKIP button on a Common..Mythic card) nor reaches the tool')
  return
 end
 if how=='R2'then check(run.Skipped==1 and what(),tag..': R2 (the SKIP button\'s key, through the tool\'s own action) skips the card, '..'and the tool does nothing')
 else
  check(not run.Skipped and what(),tag..': R155: a '..how..' during the animation neither skips nor reaches the tool')
  X.run(.15);skipButton();check(run.Skipped==1 and what(),tag..': the SKIP button skips it, the tool does nothing')
 end
end
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear()
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.CameraSubject=X.hum
 X.root.CFrame=CF(0,3,100);X.state=R.Enum.HumanoidStateType.Running;X.hum.Health=100;W.Gui.ReducedMotionEnabled=false
 X.pg:SetAttribute('SeedMenu',nil)
 X.run(1)
end
local function start(rank)
 local seedId=X.byRank[rank];local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local run=M.Start({Rank=rank,SeedId=seedId,At=W.workspace:GetServerTimeNow(),Bag=bag,Mutation='None'});X.run(1/30)
 return run,bag
end
local function untilClock(run,t)local g=0;while not run.Done and run.Clock()<t and g<2000 do X.run(1/30);g+=1 end end
local function gone(run,bag)local g=0;while(M.Active()==run or Collect.Flying()>0)and g<400 do X.run(1/30);g+=1 end;bag:Destroy();X.run(.4)end

-- 1. planting ---------------------------------------------------------------------------------------------------------------------------------
for _,how in ipairs({'click','tap','R2'})do
 reset();hold(seed);aim='soil'
 local press=how=='click'and click or how=='tap'and tap or function()r2('GardenPlaceSeed')end
 local p0=placed;press();check(placed==p0+1,'planting ('..how..'): no reveal on screen: it plants, as before')
 X.run(.5)
 local run,bag=start(4);local tl=run.TL;local tag='planting ('..how..') under a Legendary card'
 X.run(.1);p0=placed;press()
 check(placed==p0 and not run.Skipped,tag..': R155: from the card\'s first frame a press is the reveal\'s: it plants nothing, nor skips (before '..(tl.SkipFrom or L.CardSkipFrom)..' s)')
 untilClock(run,(tl.SkipFrom or L.CardSkipFrom)+.1);p0=placed -- (R157: where R153's card skip began)
 skipWith(run,how,press,tag,function()return placed==p0 end)
 untilClock(run,L.ShownAt(tl)+.1);p0=placed;press()
 check(not run.Collected and placed==p0,tag..': a press as the result lands (it only lands: R154) plants nothing either')
 untilClock(run,tl.Length+20) -- (R154: the result waits, however long)
 check(M.Active()==run and M.Waiting(),tag..': 20 s after its length the result still waits')
 X.run(.3);p0=placed;press()
 check(run.Collected and placed==p0,tag..': the press that collects it (R154; R153 closed it) plants nothing')
 gone(run,bag)
 p0=placed;press();check(placed==p0+1,tag..': the card gone, the next press plants as before')
end
-- (R157: a card that can still be skipped - Secret opened in place, a keeper near - R2 through the seed's own action skips it, and plants nothing)
do
 reset();hold(seed);aim='soil';X.keeper(V3(25,3,100),{})
 local press=function()r2('GardenPlaceSeed')end
 local run,bag=start(6);local tl=run.TL;local tag='planting (R2) under a Secret card in place'
 check(run.Kind=='InPlace'and tl.SkipFrom~=nil,tag..': (the compact card, skippable)')
 untilClock(run,tl.SkipFrom+.1);local p0=placed
 skipWith(run,'R2',press,tag,function()return placed==p0 end)
 untilClock(run,L.ShownAt(tl)+.3);press()
 check(run.Collected and placed==p0,tag..': the press that collects it plants nothing either')
 gone(run,bag)
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
end
-- 2. the shovel ---------------------------------------------------------------------------------------------------------------------------------
local function shovelOpen()return shovelBox~=nil and shovelBox.Visible==true end
local function shovelClose()X.pg:SetAttribute('SeedMenu',nil);X.run(.1)end
check(shovelBox~=nil,'the shovel\'s removal dialog exists')
for _,how in ipairs({'click','tap','R2'})do
 reset();hold(shovel);aim='plant';X.run(.3)
 local press=how=='click'and click or how=='tap'and tap or function()r2('GardenShovelRemove')end
 press();check(shovelOpen(),'shovel ('..how..'): no reveal: a press on my plant opens the removal dialog, as before');shovelClose()
 local run,bag=start(3);local tl=run.TL;local tag='shovel ('..how..') under a Rare card'
 untilClock(run,(tl.SkipFrom or L.CardSkipFrom)+.1);local r0=removes
 skipWith(run,how,press,tag,function()return not shovelOpen()and X.pg:GetAttribute('SeedMenu')==nil end)
 untilClock(run,L.ShownAt(tl)+.3);press()
 check(run.Collected and not shovelOpen()and removes==r0,tag..': the press that collects it (R154) opens none either, and nothing is removed')
 gone(run,bag)
 press();check(shovelOpen(),tag..': the card gone, the next press opens it as before');shovelClose()
end
-- 3. digging on the track ------------------------------------------------------------------------------------------------------------------------
do
 local motion=W.RS:FindFirstChild('RunnerMotion');motion:SetAttribute('TrackBoundaryZ',0);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114)
 for _,how in ipairs({'click','tap','R2'})do
  reset();hold(shovel);aim='soil'
  local press=how=='click'and click or how=='tap'and tap or function()r2('TrackHoleDig')end
  local d0=digs;press();check(digs==d0+1,'digging ('..how..'): no reveal: a press on the track digs, as before')
  X.run(.5)
  local run,bag=start(2);local tl=run.TL;local tag='digging ('..how..') under an Uncommon card'
  untilClock(run,(tl.SkipFrom or L.CardSkipFrom)+.1);d0=digs
  skipWith(run,how,press,tag,function()return digs==d0 end)
  untilClock(run,L.ShownAt(tl)+.3);press()
  check(run.Collected and digs==d0,tag..': nor the one that collects it (R154)')
  gone(run,bag)
  press();check(digs==d0+1,tag..': the card gone, the next press digs')
 end
 motion:SetAttribute('TrackBoundaryZ',nil);motion:SetAttribute('TrackCenterX',nil);motion:SetAttribute('TrackHalfWidth',nil)
end
-- 4. giving a held seed --------------------------------------------------------------------------------------------------------------------------
check(giftDialog~=nil,'the gift dialog exists')
local function giftOpen()return giftDialog~=nil and giftDialog.Visible==true end
local function giftClose()local c=giftDialog and giftDialog:FindFirstChild('Cancel');if c then c.Activated:Fire()end;X.run(.8)end
for _,how in ipairs({'click','tap'})do
 reset();hold(seed);aim='friend';X.run(.8)
 local press=how=='click'and click or tap
 press();check(giftOpen(),'giving ('..how..'): no reveal: a press on a nearby player asks to give, as before');giftClose()
 local run,bag=start(5);local tl=run.TL;local tag='giving ('..how..') under a Mythic card'
 untilClock(run,(tl.SkipFrom or L.CardSkipFrom)+.1)
 skipWith(run,how,press,tag,function()return not giftOpen()end)
 untilClock(run,L.ShownAt(tl)+.3);press()
 check(run.Collected and not giftOpen()and gifts==0,tag..': nor the one that collects it (R154); nothing is given')
 gone(run,bag);X.run(.7)
 press();check(giftOpen(),tag..': the card gone, the next press asks again');giftClose()
end
aim='soil'
-- 5. tools the engine activates on a click (a pack, the bat) --------------------------------------------------------------------------------------
for _,t in ipairs({packTool,bat})do
 reset();hold(t)
 local run,bag=start(5);local tl=run.TL;local hit=tl.Burst;local tag=t.Name..' in hand, a Mythic card'
 local log={}
 local function sample(label)log[label]=t.ManualActivationOnly end
 X.run(.1);sample('early')
 untilClock(run,(tl.SkipFrom or L.CardSkipFrom)+.1);sample('armed')
 click();X.run(1/30);sample('justClicked') -- (R155: a click never skips; the card keeps every press until it is collected)
 untilClock(run,hit+.1);sample('hitToResult')
 untilClock(run,L.ShownAt(tl)+.3);sample('closeable')
 untilClock(run,tl.Length+15);sample('waiting') -- (R154: the result waits)
 hold(seed);X.run(1/30)
 local swapped=t.ManualActivationOnly==false and seed.ManualActivationOnly==true
 hold(t);X.run(1/30);sample('back')
 click();gone(run,bag)
 check(log.early==true,tag..': R155: from the card\'s first frame its clicks are the reveal\'s, not the tool\'s (ManualActivationOnly on, this client only)')
 check(log.armed==true,tag..': past where R153\'s card skip began too (R157: a Mythic card has no SKIP button; the press is still the reveal\'s)')
 check(log.justClicked==true and not run.Skipped,tag..': a click on the world skips nothing and still does not reach the tool')
 check(log.hitToResult==true,tag..': between the hit and the result too')
 check(log.closeable==true,tag..': once the result is shown (a click collects it) held again')
 check(log.waiting==true,tag..': and for as long as the result waits (R154: 15 s after its length)')
 check(swapped and log.back==true,tag..': swapping tools puts the old one back; a manual tool (the seed) is never touched; the tool taken out again is held again')
 check(t.ManualActivationOnly==false,tag..': the card gone: put back')
end
do -- a story scene holds the tool the whole time
 reset();hold(packTool)
 local run,bag=start(6);local tl=run.TL;local all=true
 check(run.Kind=='Scene','(King / Secret story scene)')
 local g=0
 while M.Active()==run and g<2000 do
  X.run(1/30);g+=1;if M.Active()==run and packTool.ManualActivationOnly~=true then all=false end
  if not run.Collected and run.Clock()>=tl.Length+5 then local b=X.find(X.pg,'Backdrop');if b then b.Activated:Fire()end end -- (R154: it waits; the tap collects it)
 end
 bag:Destroy();X.run(.3)
 check(all and packTool.ManualActivationOnly==false,'a story scene: the held pack does not activate for its whole length, and is put back after')
 M.Abort('test');hold(nil)
end
-- 6. a story scene owns every press ----------------------------------------------------------------------------------------------------------------
do
 reset();hold(seed);aim='soil'
 local run,bag=start(6);untilClock(run,run.TL.SceneIn+.5)
 local p0=placed;r2('GardenPlaceSeed')
 check(placed==p0,'a story scene: R2 through the garden\'s action plants nothing')
 aim='friend';r2(nil)
 check(not giftOpen(),'a story scene: the gift\'s R2 asks nothing')
 M.Abort('test');bag:Destroy();aim='soil';X.run(.5)
 p0=placed;r2('GardenPlaceSeed');check(placed==p0+1,'after it: R2 plants again')
end
do -- one answer per press: the routes of one press (the card's listener, the tool's) ask within PressWindow; the reveal acts once
 local calls=0;local saved=L.PressTaker;L.PressTaker=function()calls+=1;return true end
 X.run(.5);local a,b,c=L.ClaimPress(),L.ClaimPress(),L.ClaimPress()
 X.run(.2);local d=L.ClaimPress()
 L.PressTaker=nil;X.run(.2);local e=L.ClaimPress()
 L.PressTaker=saved
 check(a and b and c and calls==2 and d,'one press asked by three routes: one answer, the reveal asked once; the next press is asked again ('..calls..' asks)')
 check(e==false,'nobody to take it (no director): no press is ever the reveal\'s')
end
-- 7. R154: the seed of a pull is not in the hand for planting until it has flown in (EconomyClient's equippedGardenSeed, from its source)
do
 local src=W.B.EconomyClient
 local a=src:find('local function collectHeld',1,true);local b=select(2,src:find('\nlocal function sendGarden',a,true))
 check(a and b,'EconomyClient: collectHeld and equippedGardenSeed are found in its source')
 local env=setmetatable({player=X.player,ReplicatedStorage=W.RS},{__index=W.env})
 local f=loadstring(src:sub(a,b-#'\nlocal function sendGarden')..'\nreturn equippedGardenSeed','=EconomyClient seed in hand');setfenv(f,env);local equipped=f()
 reset();hold(seed);check(equipped()==seed,'a seed in the hand is the planting seed, as before')
 Collect.Hold('seed-1');check(equipped()==nil,'R154: the same seed held back (its pull\'s result waits) is not: no planting, no aim')
 Collect.Land('seed-1');check(equipped()==seed,'R154: once it has flown in it is')
 hold(nil)
end
-- the source: every tool route asks before it acts
do
 local function has(name,needle)local s=W.B[name];return s and s:find(needle,1,true)~=nil end
 check(has('GardenShovel',' if busy or not equipped()or revealPress()then return end'),'GardenShovel: prompt asks RarePullRules.ClaimPress first')
 check(has('TrackHoleClient',' if revealPress()then return true end'),'TrackHoleClient: dig asks it first')
 check(has('FruitGiftClient','if not held or revealPress()then return end'),'FruitGiftClient: give asks it first')
end
print(('R153 press checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
