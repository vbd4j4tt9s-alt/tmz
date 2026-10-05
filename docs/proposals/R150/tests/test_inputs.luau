--!nocheck
-- R150 SFX fix round, part 4: inputs that had no sound, on the Roblox mock with the REAL client scripts of this checkout (InteractionAudio and LocalSfx
-- are replaced by recorders so each script's own calls are what is checked):
--  1. TravelButtons: arriving after BASE / TRACK (FastTravelReadyAt rising to a future time) plays the whoosh once; join-time values, a draining
--     cooldown and a refused press do not.
--  2. InteractionFeedback: an upgrade BOUGHT rings KaChing, a REFUSED one clicks Denied (server serials), the press keeps UpgradeClick; stepping onto a
--     treadmill clicks Equip once; holding E on a prompt clicks as the hold begins.
--  3. BatClient: a swing is heard (a whoosh timed to meet the contact frame), a miss included; far swings and late echoes are handled.
--  4. FruitGiftClient: the dialog opens / closes with MenuClick / MenuClose, Give sends with Bubble06, "Get closer" / "Hold the item" click Denied.
--  5. GardenShovel: a removed plant is heard as the planting Dig layer at the plant, a refused removal clicks Denied, its buttons are silent themselves.
--  6. SettingsClient: the volume previews (Interface row = click, Effects row = reveal pop, at the NEW level), and the mixer starts before the remote wait.
--  7. SaleMoneyEffects: a coin reaching the wallet clicks Bubble06 (a hover collect too); the coin button carries ButtonSound=false.
--  8. GardenWallet / PassGiftDialog / HudLayout: the wallet taps are silent themselves (the SeedMenu rule clicks), the gift picker clicks open / close.
--  9. TitleScreen104: Enter / gamepad A / a click on Click to Start sound the same MenuClick, once.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local RS=W.RS
F.packAssets(W)
W.env.bit32=bit32
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end
do local mt=getmetatable(R.Vector2.new(0,0));local base=mt.__index -- (the mock's Vector2 has no Lerp)
 mt.__index=function(a,k)if k=='Lerp'then return function(p,q,t)return R.Vector2.new(p.X+(q.X-p.X)*t,p.Y+(q.Y-p.Y)*t)end end;if type(base)=='function'then return base(a,k)end;return nil end
end
local rec=E.recorder()
local sfx={Log={},WhooshId='rbxassetid://9120768742'}
function sfx.Play(id,pos,vol,pitch,life,skip)local e={Id=id,Pos=pos,Vol=vol,Pitch=pitch,Life=life,Skip=skip,At=R.clock};sfx.Log[#sfx.Log+1]=e;return true end
function sfx.Preload(ids)for _,i in ipairs(ids)do sfx.Preloaded=sfx.Preloaded or{};sfx.Preloaded[i]=true end end
function sfx.count(id)local n=0;for _,e in ipairs(sfx.Log)do if not id or e.Id==id then n+=1 end end;return n end
W.stub('LocalSfx',sfx)
E.player('Tester')
local player,pg,bag,char,root,hum=E.Player,E.pg,E.bag,E.char,E.root,E.hum
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local function remote(class,name)local r=R.Instance.new(class);r.Name=name;r.Parent=remotes;return r end
local function frames(n,dt)for _=1,n do W.frames(1,dt or 1/60)end end

-- 1. TravelButtons ------------------------------------------------------------------------------------------------------------------------------------
do
 remote('RemoteEvent','RequestBaseTeleport');remote('RemoteEvent','RequestTrackTeleport')
 player:SetAttribute('FastTravelReadyAt',W.workspace:GetServerTimeNow()-30) -- (a stale value from before: set at join)
 local sc=R.new('LocalScript');sc.Name='TravelButtons';local ok,err=pcall(W.load,'TravelButtons',sc);check(ok,'TravelButtons loads: '..tostring(err))
 frames(5)
 check(sfx.Preloaded and sfx.Preloaded[sfx.WhooshId],'the whoosh is preloaded at start')
 check(sfx.count()==0,'(nothing played at join)')
 local now=W.workspace:GetServerTimeNow()
 player:SetAttribute('FastTravelCooldown',4);player:SetAttribute('FastTravelReadyAt',now+4)
 check(sfx.count(sfx.WhooshId)==1,'arriving (FastTravelReadyAt rises to now + cooldown): one whoosh')
 local e=sfx.Log[1]
 check(e and e.Pos==nil and e.Vol>0 and e.Vol<=.5 and e.Pitch==1.4,'a 2D whoosh at a moderate volume (LocalSfx range, pitch 1.4 clamped)')
 R.advance(2);frames(3)
 check(sfx.count()==1,'the cooldown draining (the HUD repaints) is silent')
 R.advance(5);player:SetAttribute('FastTravelReadyAt',W.workspace:GetServerTimeNow()+4)
 check(sfx.count(sfx.WhooshId)==2,'the next trip sounds again')
 player:SetAttribute('FastTravelReadyAt',W.workspace:GetServerTimeNow()+4.2)
 check(sfx.count()==2,'a rewrite of the same cooldown (+0.2 s) is not a new arrival')
 player:SetAttribute('FastTravelReadyAt',W.workspace:GetServerTimeNow()-10)
 check(sfx.count()==2,'a time in the past is not an arrival')
 sc.Destroying:Fire()
end

-- 2. InteractionFeedback ----------------------------------------------------------------------------------------------------------------------------
do
 remote('RemoteEvent','PackTaken')
 local Prompts=W.service('ProximityPromptService');Prompts.PromptButtonHoldBegan=R.signal()
 local sc=R.new('LocalScript');sc.Name='InteractionFeedback';local ok,err=pcall(W.load,'InteractionFeedback',sc);check(ok,'InteractionFeedback loads: '..tostring(err))
 rec.clear()
 player:SetAttribute('UpgradePressSerial',1);check(rec.keys()=='UpgradeClick','the press click is kept (UpgradeClick)')
 player:SetAttribute('UpgradeBoughtSerial',1);check(rec.keys()=='UpgradeClick,KaChing','a BOUGHT upgrade rings KaChing after the click')
 rec.clear();player:SetAttribute('UpgradePressSerial',2);player:SetAttribute('UpgradeRefusedSerial',1)
 check(rec.keys()=='UpgradeClick,Denied','a REFUSED upgrade clicks Denied (and never KaChing)')
 rec.clear();player:SetAttribute('UpgradePressSerial',3);player:SetAttribute('UpgradeBoughtSerial',2)
 check(rec.count('KaChing')==1 and rec.count('Denied')==0,'the next purchase: KaChing only')
 -- treadmill
 rec.clear();player:SetAttribute('TreadmillTraining',true);check(rec.keys()=='Equip','stepping onto a treadmill clicks Equip once')
 player:SetAttribute('TreadmillTraining',true);check(rec.count()==1,'(still on it: nothing)')
 player:SetAttribute('TreadmillTraining',false);check(rec.count()==1,'stepping off is silent')
 player:SetAttribute('TreadmillTraining',true);check(rec.count('Equip')==2,'stepping on again clicks again')
 -- hold E
 rec.clear()
 local p1=R.new('ProximityPrompt');p1.HoldDuration=1.5;local p2=R.new('ProximityPrompt');p2.HoldDuration=0
 Prompts.PromptButtonHoldBegan:Fire(p1);check(rec.keys()=='Bubble04','holding E on a prompt clicks as the hold begins')
 Prompts.PromptButtonHoldBegan:Fire(p2);check(rec.count()==1,'a prompt with no hold does not (it has its own cue)')
 sc.Destroying:Fire()
end

-- 3. BatClient ----------------------------------------------------------------------------------------------------------------------------------------
do
 local C=W.module('BatConfig')
 check(C.SwingSoundVolume and C.SwingSoundPitch and C.SwingSoundLead and C.SwingSoundRange,'the swing whoosh tuning lives in BatConfig (volume, pitch, lead, range)')
 local swing=remote('RemoteEvent','BatSwing')
 local bat=F.bat(W,char);bat.Activated=R.signal()
 local camera=W.workspace.CurrentCamera;camera.CFrame=CF(0,5,110)
 local sc=R.new('LocalScript');sc.Name='BatClient';local ok,err=pcall(W.load,'BatClient',sc);check(ok,'BatClient loads: '..tostring(err))
 check(sfx.Preloaded and sfx.Preloaded[sfx.WhooshId],'the whoosh is preloaded with the slap')
 sfx.Log={}
 local function echo(age,character)
  local at=W.workspace:GetServerTimeNow()-(age or 0)
  swing.OnClientEvent:Fire({Kind='Swing',Character=character or char,At=at,Serial=1})
  return at
 end
 R.advance(2)
 local at=echo(0)
 check(sfx.count()==0,'the whoosh is not played at the echo: it is timed to the contact frame (At + Windup - lead)')
 R.advance(C.Windup-C.SwingSoundLead-.02);check(sfx.count()==0,'(still waiting)')
 R.advance(.04)
 check(sfx.count(sfx.WhooshId)==1,'one whoosh arrives '..C.SwingSoundLead..' s before contact')
 local e=sfx.Log[1]
 check(e and near(e.At-at,C.Windup-C.SwingSoundLead,.03),'at ~'..(C.Windup-C.SwingSoundLead)..' s after the swing starts ('..tostring(e and (e.At-at))..')')
 check(e and e.Pos and near(e.Pos.Z,root.Position.Z,.01) and e.Vol==C.SwingSoundVolume and e.Pitch==C.SwingSoundPitch and(e.Skip or 0)==0,'3D at the swinger, the configured volume and pitch, not a late join')
 R.advance(2);sfx.Log={}
 echo(C.Windup-C.SwingSoundLead+.07)
 check(sfx.count()==1 and near(sfx.Log[1].Skip,.07,.01),'an echo that arrives late joins the cue part-way (skip .07 s) instead of dropping it')
 R.advance(2);sfx.Log={}
 echo(C.Windup+C.Recovery+.5)
 check(sfx.count()==0,'an echo older than the whole swing is ignored')
 camera.CFrame=CF(0,5,400);R.advance(2);echo(0);R.advance(.5)
 check(sfx.count()==0,'a swing 300 studs away is not rendered as sound')
 camera.CFrame=CF(0,5,110);R.advance(2)
 local noRoot=R.new('Model');noRoot.Name='Ghost';noRoot.Parent=W.workspace
 echo(0,noRoot);R.advance(.5);check(sfx.count()==0,'a character with no root: nothing')
 -- a miss is the common case: no hit packet ever arrives, the swing still sounds
 sfx.Log={};R.advance(2);echo(0);R.advance(.3)
 check(sfx.count(sfx.WhooshId)==1,'a miss (no KeeperHit follows) is heard')
 sc.Destroying:Fire();bat:Destroy()
end

-- 4. FruitGiftClient ----------------------------------------------------------------------------------------------------------------------------------
do
 local UIS=W.UIS;UIS.TouchTapInWorld=R.signal()
 local Players=W.service('Players')
 local present={}
 function Players.GetPlayerFromCharacter(_,m)for _,p in pairs(present)do if p.Character==m then return p end end;return nil end
 local function makePlayer(id,name,x)
  local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
  local c=R.new('Model');c.Name=name;c.Parent=W.workspace
  local r=R.new('Part');r.Name='HumanoidRootPart';r.Position=V3(x,3,0);r.Parent=c;p.Character=c;return p
 end
 root.Position=V3(0,3,0)
 local near,far=makePlayer(2,'Near',8),makePlayer(3,'Far',60)
 local fruitRemote=remote('RemoteEvent','FruitGift')
 local sent={};function fruitRemote.FireServer(_,...)sent[#sent+1]=table.pack(...)end
 function UIS.GetMouseLocation()return R.Vector2.new(640,360)end
 W.workspace.CurrentCamera.ViewportPointToRay=function()return {Origin=V3(0,5,-10),Direction=V3(0,0,1)}end
 local aim
 function W.workspace.Raycast()return aim and {Instance=aim.Character.HumanoidRootPart}or nil end
 W.env.RaycastParams={new=function()return {}end}
 local gifts={};W.stub('NoticeFeed83',{Gift=function(text)gifts[#gifts+1]=text end,Push=function()end,Plain=function()end})
 local sc=R.new('LocalScript');sc.Name='FruitGiftClient';local ok,err=pcall(W.load,'FruitGiftClient',sc);check(ok,'FruitGiftClient loads: '..tostring(err))
 local gui=pg:FindFirstChild('FruitGifts');local dialog=gui:FindFirstChild('GiftConfirm')
 local give,cancel=dialog:FindFirstChild('Give'),dialog:FindFirstChild('Cancel')
 check(give:GetAttribute('ButtonSound')==false and cancel:GetAttribute('ButtonSound')==false,'Give and Cancel are silent themselves (the dialog clicks for itself)')
 local function tool(attrs,name)local t=R.new('Tool');t.Name=name or'Item';for k,v in pairs(attrs)do t:SetAttribute(k,v)end;t.Parent=char;return t end
 local function click(target)aim=target;R.advance(1);rec.clear();UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},false);return dialog.Visible end
 local fruit=tool({HarvestItemTool=true,HarvestInventoryId='crop-1'},'Golden Apple')
 check(click(near)==true and rec.keys()=='MenuClick','a world click on a nearby player opens the dialog with a MenuClick')
 rec.clear();give.Activated:Fire();R.advance(2.1)
 check(rec.keys()=='Bubble06' and #sent==1 and dialog.Visible==false,'Give: the dialog closes and the gift goes out on one Bubble06 (no MenuClose on top, no generic click) ('..rec.keys()..')')
 check(click(near)==true,'(reopened)');rec.clear();cancel.Activated:Fire()
 check(rec.keys()=='MenuClose' and dialog.Visible==false,'Cancel closes it with a MenuClose')
 click(near);rec.clear();UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.Keyboard,KeyCode=R.Enum.KeyCode.Escape},false)
 check(rec.keys()=='MenuClose','Esc closes it with the same MenuClose')
 click(near);rec.clear();UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.Gamepad1,KeyCode=R.Enum.KeyCode.ButtonB},false)
 check(rec.keys()=='MenuClose','B too')
 -- refusals
 check(click(far)==false and rec.keys()=='Denied','a far player: "Get closer" and a Denied click, no dialog')
 click(near);local second=tool({HarvestItemTool=true,HarvestInventoryId='crop-2'},'Other');fruit.Parent=bag
 rec.clear();give.Activated:Fire();R.advance(.1)
 check(rec.keys()=='Denied','Give after the held item changed: "Hold the item" and a Denied click ('..rec.keys()..')')
 second:Destroy();fruit:Destroy()
 sc.Destroying:Fire()
 W.stub('NoticeFeed83',nil)
end

-- 5. GardenShovel ---------------------------------------------------------------------------------------------------------------------------------------
do
 local UIS=W.UIS
 local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
 local garden=remote('RemoteFunction','GardenInteract')
 local answer={Success=true,Message='PLANT REMOVED'}
 function garden.InvokeServer(_,action,payload)garden.Last={action,payload};return answer end
 local shovel=R.new('Tool');shovel.Name='Shovel';shovel:SetAttribute('GardenShovel',true);shovel.Parent=char
 local Catalog=W.module('PlantCatalog');local seedId='SunflowerSeed';local def=Catalog[seedId]
 local plant=R.new('Model');plant.Name='Plant_1';plant:SetAttribute('GardenPlantV141',true);plant:SetAttribute('GardenOwnerId',player.UserId)
 plant:SetAttribute('SeedId',seedId);plant:SetAttribute('CropId','crop-1');plant.Parent=map
 local part=R.new('Part');part.Name='Stem';part.Size=V3(1,2,1);part.CFrame=CF(3,2,0);part.LocalTransparencyModifier=0;part.Parent=plant
 plant:PivotTo(CF(3,0,0))
 root.CFrame=CF(0,3,0)
 W.workspace.CurrentCamera.ViewportPointToRay=function()return {Origin=V3(0,5,-10),Direction=V3(0,0,1)}end
 function UIS.GetMouseLocation()return R.Vector2.new(640,360)end
 local aimed
 function W.workspace.Raycast()return aimed and {Instance=part,Position=V3(3,1,0)}or nil end
 local sc=R.new('LocalScript');sc.Name='GardenShovel';local ok,err=pcall(W.load,'GardenShovel',sc);check(ok,'GardenShovel loads: '..tostring(err))
 local gui=pg:FindFirstChild('GardenShovelUI');local box=gui and gui:FindFirstChildOfClass('Frame')
 local remove,keep
 for _,b in ipairs(box and box:GetChildren()or{})do if b:IsA('TextButton')then if b.Text=='Remove'then remove=b elseif b.Text=='Keep plant'then keep=b end end end
 check(remove and keep and remove:GetAttribute('ButtonSound')==false and keep:GetAttribute('ButtonSound')==false,'Remove and Keep are silent themselves: the SeedMenu rule clicks the dialog open / closed')
 local dig;for _,d in ipairs(W.module('PlantingEffects').Sounds)do if d.Key=='Dig'then dig=d end end
 check(sfx.Preloaded and sfx.Preloaded[dig.Id],'the Dig layer is preloaded')
 local function openDialog()aimed=true;R.advance(.5);frames(8);rec.clear();sfx.Log={};UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},false);return box.Visible end
 check(openDialog()==true and pg:GetAttribute('SeedMenu')=='Shovel','a click on your plant opens the removal dialog (SeedMenu = Shovel: ButtonFeedback plays its MenuClick)')
 sfx.Log={};rec.clear();answer={Success=true,Message='PLANT REMOVED'}
 remove.Activated:Fire()
 check(garden.Last and garden.Last[1]=='Remove','Remove asks the server')
 check(sfx.count(dig.Id)==1,'a removed plant is heard: the planting Dig layer ('..sfx.count(dig.Id)..')')
 local e=sfx.Log[1]
 check(e and e.Pos and near(e.Pos.X,3,.5) and e.Vol==dig.Volume,'at the plant (x = 3), at the layer\'s own volume')
 check(rec.count('Denied')==0,'a success is not a refusal')
 pg:SetAttribute('SeedMenu',nil)
 check(openDialog()==true,'(reopened)')
 sfx.Log={};rec.clear();answer={Success=false,Message='YOUR GARDEN ONLY!'};remove.Activated:Fire()
 check(rec.keys()=='Denied' and sfx.count()==0,'a refused removal clicks Denied and makes no dig sound')
 pg:SetAttribute('SeedMenu',nil);check(openDialog()==true,'(reopened)')
 sfx.Log={};rec.clear();keep.Activated:Fire()
 check(rec.count()==0 and sfx.count()==0 and pg:GetAttribute('SeedMenu')==nil,'Keep closes it: no sound of its own (the MenuClose comes from the SeedMenu rule)')
 sc.Destroying:Fire();shovel:Destroy();plant:Destroy()
end

-- 6. SettingsClient ------------------------------------------------------------------------------------------------------------------------------------
do
 -- The real RarityRevealAudio gives the Effects preview its pop; the recorder takes the Interface click.
 local Mixer=W.module('AudioMixer')
 local request=remote('RemoteFunction','PremiumRequest')
 local saved={Effects=100,Interface=100,Music=100,Chase=100,Ambience=100,Quality='Auto'}
 local calls={}
 function request.InvokeServer(_,action,value)calls[#calls+1]={action,value};if action=='SettingsState'then return {Success=true,Settings=saved}end;return {Success=true}end
 local started=false
 local rawStart=Mixer.Start;Mixer.Start=function(...)started=true;check(#calls==0,'the mixer starts BEFORE the first request to the server (it used to wait for the remote)');return rawStart(...)end
 local sc=R.new('LocalScript');sc.Name='SettingsClient';local ok,err=pcall(W.load,'SettingsClient',sc);check(ok,'SettingsClient loads: '..tostring(err))
 check(started,'Mixer.Start() was called')
 local gui=pg:FindFirstChild('GardenSettings');local panel=gui and gui:FindFirstChild('SettingsPanel');local controls=panel and panel:FindFirstChild('Controls')
 local function row(key)return controls:FindFirstChild(key)end
 local reveal=W.module('RarityRevealAudio');reveal.Preload()
 local SS=W.service('SoundService');local popSound=SS:FindFirstChild('Reveal_Pop')
 for _,key in ipairs({'Effects','Interface','Music','Chase','Ambience'})do
  local r=row(key);check(r and r:FindFirstChild('Quieter')and r:FindFirstChild('Louder')and r:FindFirstChild('Volume'),key..' row has -, + and the rail')
  check(r.Quieter:GetAttribute('ButtonSound')==false and r.Louder:GetAttribute('ButtonSound')==false and r.Volume:GetAttribute('ButtonSound')==false,key..': -, + and the rail are silent themselves (the preview at the new level replaces the click)')
 end
 frames(3)
 -- Interface row: a Bubble04 preview at the NEW level
 rec.clear();local before=Mixer.Get('Interface')
 row('Interface').Quieter.Activated:Fire()
 check(Mixer.Get('Interface')==before-10 and rec.keys()=='Bubble04','Interface -: the level drops to '..Mixer.Get('Interface')..' and a click previews it')
 rec.clear();row('Interface').Louder.Activated:Fire();check(rec.keys()=='Bubble04' and Mixer.Get('Interface')==before,'Interface +')
 rec.clear();row('Interface').Volume.Activated:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,Position={X=row('Interface').Volume.AbsolutePosition.X+row('Interface').Volume.AbsoluteSize.X*.5,Y=5}})
 check(rec.keys()=='Bubble04' and Mixer.Get('Interface')==50,'a tap on the rail sets the level (50) and previews it too ('..rec.keys()..', '..Mixer.Get('Interface')..')')
 -- Effects row: a reveal pop through the Effects group at the new level
 popSound.Plays=0;popSound.PlayLog={}
 rec.clear();row('Effects').Quieter.Activated:Fire()
 check(popSound.Plays==1 and rec.count()==0,'Effects -: a reveal pop previews it (an Effects sound, not a button click)')
 check(popSound.SoundGroup==Mixer.Group('Effects') and near(Mixer.Group('Effects').Volume,.9),'... through the Effects group, which already has the new level (.9) when it plays')
 for _=1,9 do row('Effects').Quieter.Activated:Fire() end
 check(Mixer.Get('Effects')==0 and Mixer.Group('Effects').Volume==0,'Effects at 0: the group is 0 (the preview is inaudible by design)')
 -- Music / Chase / Ambience: change by themselves; the control still clicks
 rec.clear();row('Music').Quieter.Activated:Fire();check(rec.keys()=='Bubble04','Music -: a plain click so the control is never silent')
 -- the Quality button keeps its own click
 rec.clear();local quality=controls:FindFirstChild('Quality');quality.Activated:Fire()
 check(quality:GetAttribute('ButtonSound')==nil and rec.count()==0,'Quality: its ButtonHighlights click is untouched (no preview)')
 sc.Destroying:Fire();Mixer.Start=rawStart
end

-- 7. SaleMoneyEffects ---------------------------------------------------------------------------------------------------------------------------------------
do
 local Effects=W.module('SaleMoneyEffects')
 local gui=R.new('ScreenGui');gui.Parent=pg
 local pulses=0
 local wallet={Pulse=function()pulses+=1 end,TargetPosition=function()return R.Vector2.new(200,40)end}
 wallet.Gems=wallet
 local claimed={}
 local fx=Effects.new(gui,wallet,function(id,index)claimed[#claimed+1]=index;return {Success=true}end)
 local receipt={Id='r1',Amount=1000,Count=8,Claimed=0,Currency='Cash'}
 fx:Sync({receipt},R.Vector2.new(300,300))
 frames(40,1/60)
 local buttons={};for _,c in ipairs(fx.Layer:GetChildren())do if c.Name=='CollectMoney'then buttons[#buttons+1]=c end end
 check(#buttons>=1,'the sale shows coin icons ('..#buttons..')')
 check(buttons[1]:GetAttribute('ButtonSound')==false,'a coin button is silent itself: the sound is the coin arriving at the wallet')
 rec.clear()
 buttons[1].Activated:Fire()
 check(rec.count()==0,'clicking a coin makes no sound at the click (it would play even if the claim were refused)')
 frames(60,1/60)
 check(pulses>=1 and rec.count('Bubble06')==pulses and rec.count()==pulses,'each coin that reaches the wallet clicks Bubble06 together with its pulse ('..rec.count('Bubble06')..' / '..pulses..')')
 -- a hover collect
 local before=rec.count('Bubble06');local pulsesBefore=pulses
 if buttons[2]then buttons[2].MouseEnter:Fire() end
 frames(60,1/60)
 check(buttons[2]==nil or(pulses==pulsesBefore+1 and rec.count('Bubble06')==before+1),'a hover-collected coin sounds too (it used to be silent)')
 -- the claim being refused: the coin does not fly and nothing sounds
 fx:Destroy()
 local fx2=Effects.new(gui,wallet,function()return {Success=false}end)
 fx2:Sync({{Id='r2',Amount=500,Count=8,Claimed=0,Currency='Cash'}},R.Vector2.new(300,300))
 frames(40,1/60)
 local list={};for _,c in ipairs(fx2.Layer:GetChildren())do if c.Name=='CollectMoney'then list[#list+1]=c end end
 rec.clear();local p2=pulses
 if list[1]then list[1].Activated:Fire()end;frames(80,1/60)
 check(pulses==p2 and rec.count()==0,'a refused claim: no flight, no sound')
 fx2:Destroy();gui:Destroy()
end

-- 8. GardenWallet / PassGiftDialog / the MENU wheel ------------------------------------------------------------------------------------------------------
do
 local H=W.module('ButtonHighlights')
 local gui=R.new('ScreenGui');gui.Name='WalletHost';gui.Parent=pg
 local Wallet=W.module('GardenWallet')
 local ok,w=pcall(Wallet.new,gui);check(ok and w,'GardenWallet builds: '..tostring(w))
 local stop=H.Start(pg);local stopMenus=H.WatchMenus(pg)
 rec.clear();pg:SetAttribute('SeedMenu',nil)
 local gems=w.Gems.Root
 check(gems:GetAttribute('ButtonSound')==false and w.More:GetAttribute('ButtonSound')==false and w.CompactTap:GetAttribute('ButtonSound')==false and w.Gems.More:GetAttribute('ButtonSound')==false and w.Gems.CompactTap:GetAttribute('ButtonSound')==false,'the wallet row, "+" and the phone tap are all ButtonSound=false (read at click time: no start-order dependence)')
 for _,b in ipairs({gems,w.More,w.CompactTap,w.Gems.More,w.Gems.CompactTap})do
  pg:SetAttribute('SeedMenu',nil);R.advance(1);rec.clear()
  b.Activated:Fire()
  check(pg:GetAttribute('SeedMenu')=='Passes' and rec.keys()=='MenuClick','tapping '..b.Name..': one MenuClick for the Passes panel opening ('..rec.keys()..')')
 end
 -- the panel already open: a page switch is a plain click
 R.advance(1);rec.clear();w.More.Activated:Fire()
 check(rec.keys()=='Bubble04','with the panel already open a wallet tap just switches page: a plain click ('..rec.keys()..')')
 pg:SetAttribute('SeedMenu',nil)

 -- the gift picker (no SeedMenu): clicks for itself
 local Gift=W.module('PassGiftDialog')
 local host=R.new('Frame');host.Parent=gui
 local acts={}
 local dialog=Gift.Create(host,player,function(action,value,cb)acts[#acts+1]={action,value};if cb then cb({Success=true})end end,function()return {GiftCredits={},GiftProducts={}}end,function()return {PriceInRobux=99,IsForSale=true}end)
 local passKey=next(W.module('MechCatalog').PassGemPrices)
 local item={Key=passKey,Name='A Pass'}
 local veil=host:FindFirstChild('GiftVeil');local close=host:FindFirstChild('PassGiftPicker')and host.PassGiftPicker:FindFirstChild('CloseGift')
 check(veil and close,'the picker has a veil and a CloseGift button')
 check(veil:GetAttribute('ButtonSound')=='MenuClose','tapping outside the picker is a MenuClose (it used to be Bubble04)')
 R.advance(1);rec.clear();dialog:Open(item)
 check(rec.keys()=='MenuClick','opening the picker clicks MenuClick ('..rec.keys()..')')
 R.advance(1);rec.clear();dialog:Open(item);check(rec.count()==0,'(re-opening while open: silent)')
 R.advance(1);rec.clear();veil.Activated:Fire()
 check(rec.count('MenuClose')>=1 and rec.count('Bubble04')==0 and rec.count('MenuClick')==0,'the veil closes it with MenuClose only ('..rec.keys()..')')
 R.advance(1);dialog:Open(item);R.advance(1);rec.clear();close.Activated:Fire()
 check(rec.count('MenuClose')>=1 and rec.count('Bubble04')==0,'its X (CloseGift) too ('..rec.keys()..')')
 R.advance(1);dialog:Open(item);R.advance(1);rec.clear();dialog:Close()
 check(rec.keys()=='MenuClose','Close() from a send also clicks MenuClose once')
 R.advance(1);rec.clear();dialog:Close();check(rec.count()==0,'closing a closed picker is silent')
 stopMenus();stop();gui:Destroy()
end

-- 9. TitleScreen104 --------------------------------------------------------------------------------------------------------------------------------------
do
 local T=W.module('TitleScreen104')
 rawset(R.Enum.PlayerActions,'GetEnumItems',function()return {}end)
 local Gui=W.Gui;Gui.MenuIsOpen=false;function Gui.GetGuiInset()return R.Vector2.new(0,0),R.Vector2.new(0,0)end
 W.service('ReplicatedFirst').RemoveDefaultLoadingScreen=function()end
 W.service('Lighting')
 W.service('ProximityPromptService').Enabled=true
 local rawUnbind=W.Run.UnbindFromRenderStep;W.Run.UnbindFromRenderStep=function(self,name)if W.rsBound[name]then rawUnbind(self,name)end end
 local function begin()
  W.actions={};pg:SetAttribute('TitleActive',nil)
  local ok,stop=pcall(T.Start,player,pg);return ok,stop
 end
 local function start(how)
  local ok,stop=begin()
  if not ok then print('NOTE title could not start under the mock: '..tostring(stop));return nil end
  R.advance(2);frames(30)
  local screenGui;for _,c in ipairs(pg:GetChildren())do if c:IsA('ScreenGui')and c:FindFirstChild('ClickToStart',true)then screenGui=c end end
  local button=screenGui and screenGui:FindFirstChild('ClickToStart',true)
  rec.clear()
  if how=='button'then button.Activated:Fire()
  elseif how=='enter'then W.actions.StealAPackTitle104Start('StealAPackTitle104Start',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.Return})
  elseif how=='A'then W.actions.StealAPackTitle104Start('StealAPackTitle104Start',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonA})end
  return button,stop
 end
 local button,stop=start('button')
 if button then
  check(button:GetAttribute('ButtonSound')==false,'Click to Start has ButtonSound=false (its click is the start cue)')
  check(rec.keys()=='MenuClick','a click on Click to Start: one MenuClick ('..rec.keys()..')')
  button.Activated:Fire();check(rec.count()==1,'(a second click while it is leaving: nothing more)')
  stop()
  button,stop=start('enter')
  check(rec.keys()=='MenuClick','Enter: the same MenuClick (it used to be silent) ('..rec.keys()..')')
  stop()
  button,stop=start('A')
  check(rec.keys()=='MenuClick','gamepad A: the same MenuClick ('..rec.keys()..')')
  stop()
 end
end

-- 10. PlantInspection: selecting a plant clicks -------------------------------------------------------------------------------------------------------------
do
 local UIS=W.UIS
 local map=W.workspace:FindFirstChild('ChestChaseMap')
 local Catalog=W.module('PlantCatalog')
 local plantA=R.new('Model');plantA.Name='PlantA';plantA:SetAttribute('GardenPlantV141',true);plantA:SetAttribute('GardenOwnerId',player.UserId);plantA:SetAttribute('SeedId','SunflowerSeed');plantA:SetAttribute('CropId','cropA');plantA.Parent=map
 local plantB=R.new('Model');plantB.Name='PlantB';plantB:SetAttribute('GardenPlantV141',true);plantB:SetAttribute('GardenOwnerId',player.UserId);plantB:SetAttribute('SeedId','CactusSeed');plantB:SetAttribute('CropId','cropB');plantB.Parent=map
 local function part(name,parent)local p=R.new('Part');p.Name=name;p.LocalTransparencyModifier=0;p.Parent=parent;return p end
 local partA=part('A',plantA);plantA.PrimaryPart=partA;part('CropAnchor',plantA)
 local partB=part('B',plantB);plantB.PrimaryPart=partB;part('CropAnchor',plantB)
 local target,hitPart
 W.stub('PlantShovelPicker',{Acquire=function()return {RayExclusions=function()return {}end,Pick=function()return target,hitPart end,WithinRange=function()return true end},function()end end,Plant=function()return nil end})
 W.workspace.CurrentCamera.ViewportPointToRay=function()return {Origin=V3(0,5,-10),Direction=V3(0,0,1)}end
 function W.workspace.Raycast()return nil end
 local PPS=W.service('ProximityPromptService');PPS.PromptShown=PPS.PromptShown or R.signal();PPS.PromptHidden=PPS.PromptHidden or R.signal()
 local gui0=pg:FindFirstChild('PlantInspection');if gui0 then gui0:Destroy()end
 local sc=R.new('LocalScript');sc.Name='PlantInspection';local ok,err=pcall(W.load,'PlantInspection',sc)
 if not ok then print('NOTE PlantInspection not loadable under the mock: '..tostring(err))end
 if ok then
  pg:SetAttribute('SeedMenu',nil)
  local function pick(model,part)target,hitPart=model,part;R.advance(1);rec.clear();UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},false);UIS.InputEnded:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},false)end
  pick(plantA,partA)
  check(pg:GetAttribute('SelectedGardenCropId')=='cropA','(plant A is selected)')
  check(rec.keys()=='Bubble04','clicking a plant selects it with one click ('..rec.keys()..')')
  pick(plantA,partA);check(rec.count()==0,'picking the same plant again is silent')
  pick(plantB,partB);check(pg:GetAttribute('SelectedGardenCropId')=='cropB' and rec.keys()=='Bubble04','a different plant: a click again')
  rec.clear();target=nil;hitPart=nil;R.advance(1);UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},false);UIS.InputEnded:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},false)
  check(rec.count()==0,'clicking empty ground (clearing the selection) is silent')
  -- the gamepad route (L3) and a touch tap select too
  rec.clear();target,hitPart=plantA,partA;R.advance(1)
  W.UIS.TouchTapInWorld:Fire(R.Vector2.new(100,100),false)
  check(rec.keys()=='Bubble04','a tap on a plant selects it with a click')
  sc.Destroying:Fire()
 end
end

-- 11. Source wiring of the one big script that does not run on the mock (EconomyClient) ------------------------------------------------------------------
do
 local src=W.B.EconomyClient
 local function fn(name)return src:match('\n[\t ]*local function '..name..'%b()(.-)\n[\t ]*end\n')end
 check(src:find('Bubble06',1,true)==nil,'EconomyClient plays no Bubble06 at the harvest reply (the cue is the Hotbar arrival flash)')
 local status=fn('setStatus');local toast=fn('gardenToast')
 check(status and status:find("InteractionAudio.Play('Denied')",1,true)and status:find('isError',1,true),'setStatus: an error status clicks Denied')
 check(toast and toast:find("InteractionAudio.Play('Denied')",1,true)and toast:find('failed',1,true),'gardenToast: a failed action clicks Denied (AIM AT SOIL, BAG FULL, TOO CLOSE...)')
 check(toast and toast:find('if short == "" then return end',1,true)<toast:find("Denied",1,true),'... only when the toast is visible (hidden "quiet" messages stay silent)')
 local open=src:match('openEconomyUI%.OnClientEvent:Connect%(function%(requestedTab%)(.-)\nend%)')
 check(open and open:find('InteractionAudio',1,true)==nil,'the market prompt plays no click of its own: ButtonFeedback plays the menu cue when SeedMenu becomes Economy')
 check(src:find("local top=sendGarden('PlantTop'",1,true)and src:find('top and top.Success==true then LocalSfx.Play(LocalSfx.WhooshId',1,true),'GO TO TOP: the arrival whoosh only when the server says it worked')
 -- run the two real functions on stand-ins
 local SimpleText=W.module('SimpleGameText')
 local played={}
 local env=setmetatable({SimpleText=SimpleText,InteractionAudio={Play=function(k)played[#played+1]=k end},statusLabel={},COLORS={Muted='m'},toast={},toastSerial=0,toastTween=nil,
  TweenService={Create=function()return {Play=function()end,Cancel=function()end}end},TweenInfo=R.TweenInfo,task={delay=function()end}},{__index=_G})
 local function run(name,...)local chunk=src:match('\n([\t ]*local function '..name..'%b().-\n[\t ]*end)\n');local f=loadstring(chunk..'\nreturn '..name,'='..name);setfenv(f,env);return f()(...)end
 run('setStatus','NOT ENOUGH CASH',true);check(played[1]=='Denied','setStatus("NOT ENOUGH CASH", error) -> Denied')
 played={};run('setStatus','Bought it!',false);check(#played==0,'setStatus(message, not an error) -> silent (success never clicks Denied)')
 played={};run('setStatus','',true);check(#played==0,'an empty error text is silent')
 played={};run('gardenToast','AIM AT SOIL IN YOUR GARDEN',true);check(played[1]=='Denied','gardenToast(AIM AT SOIL, failed) -> Denied')
 played={};run('gardenToast','HARVESTED!',false);check(#played==0,'gardenToast(success) -> silent')
 played={};run('gardenToast','ESCAPE FAILED - TRY AGAIN',true);check(#played==0,'a hidden (quiet) message stays silent even when it failed')
end

-- 12. The HUD "Reopens in N" row in step with the 3-2-1 beep (the real WorldStatusHud) --------------------------------------------------------------------
do
 W.workspace.GetServerTimeNow=function()return R.clock end
 local Gui=W.service('GuiService');Gui.GetInsetArea=Gui.GetInsetArea or function()return R.Vector2.new(0,0),R.Vector2.new(0,0)end
 local State=W.module('WorldStatusState');local Countdown=W.module('RefreshCountdown')
 local map=W.workspace:FindFirstChild('ChestChaseMap')
 local reads=0;local rawRead=State.Read;State.Read=function(...)reads+=1;return rawRead(...)end
 local Hud=W.module('WorldStatusHud')
 local ok,h=pcall(Hud.Create,pg,player);check(ok and h,'WorldStatusHud builds: '..tostring(h))
 if ok and h then
  frames(30)
  local timeLabel=pg.WorldStatus.StatusStack.Track.Time
  -- an open track: the row reads from the 4 Hz tick
  map:SetAttribute('BiomesRefreshing',false);map:SetAttribute('NextBiomeRefreshAt',R.clock+600)
  frames(15);local r0=reads;frames(60);local slow=reads-r0
  check(slow>=3 and slow<=6,'an open track repaints at ~4 Hz ('..slow..' updates in 1 s)')
  -- the track closes: 10 s to go; the row still ticks at 4 Hz until the last three seconds
  local endsAt=R.clock+9.5
  map:SetAttribute('BiomesRefreshing',true);map:SetAttribute('BiomeRefreshEndsAt',endsAt);map:SetAttribute('BiomeRefreshSeconds',10)
  local state=Countdown.New(endsAt);local beeps={}
  local lastReads=reads;local fastFrames=0;local framesCounted=0
  while R.clock<endsAt+.05 do
   map:SetAttribute('BiomeRefreshSeconds',math.max(0,math.ceil(endsAt-R.clock+.4))) -- (the server's integer lags)
   local before=reads
   frames(1)
   local left=endsAt-R.clock
   if left<2.9 and left>.1 then framesCounted+=1;if reads>before then fastFrames+=1 end end
   local number=Countdown.Take(state,R.clock)
   if number then beeps[#beeps+1]={Number=number,Text=timeLabel.Text} end
  end
  check(#beeps==3,'three beeps ('..#beeps..')')
  for _,b in ipairs(beeps)do check(b.Text=='00:0'..(4-b.Number),'beep '..b.Number..': the HUD row reads 00:0'..(4-b.Number)..' on the same frame (it read '..b.Text..')')end
  check(framesCounted>0 and fastFrames==framesCounted,'in the last 3 s the row repaints every frame ('..fastFrames..' of '..framesCounted..')')
  map:SetAttribute('BiomesRefreshing',false);map:SetAttribute('BiomeRefreshEndsAt',nil)
  frames(30);local r1=reads;frames(60)
  check(reads-r1<=6,'and goes back to 4 Hz once the track is open ('..(reads-r1)..' updates in 1 s)')
  h.Destroy()
 end
 State.Read=rawRead
end

print(('R150 input checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
