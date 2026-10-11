--!nocheck
-- R153 server fixes (review: bug_review_server.md M1, M2, L4 and architecture_review.md hardening), SERVER half, on the Roblox mock with the REAL PlayerDataService, DailyProgress,
-- OwnerTestPacks, StudioTestCommands + OwnerUpdateCommands82 (the owner's /test commands), FruitGiftService, HubDisplayService, PullAnnouncer, Config and ChestService of the tree
-- under test. Every check is tagged; run_fixes_server.sh runs this file on the tree BEFORE the fixes (every tag must fail there) and on this checkout (nothing may fail).
--  [M1] owner `daily` commands make TEST packs: daily done / next / week / reset, in any claim order (a quest claimed before the day-7 Void Pack), for the whole test day, never announced,
--       never counted for BEST PULL; a real player's claims (and a real player next to the owner) are unchanged
--  [M2] the giveaway lock follows the value: pack -> seed -> plant -> fruit, saved and loaded, refused by FruitGiftService at every step; an unlocked pack is unchanged (optional field)
--  [L4] the day-7 login Void Pack is GiftLocked, DailyRewards.LockDay7Void = false allows gifting it; the other daily packs stay giftable
--  [H6] the BEST PULL window loop survives a bad pass
--  [A3] the two gameplay test hooks (walk speed, RarePackTests.Expected at the pack open and at the pack tool) can fail without breaking the game
-- It prints a PROFILE line (a save with a locked pack, seed, plant and fruit) that run_fixes_server.sh feeds to an R152 server (test_fixes_r152.luau).
local E=require('./clover_env');local W,R,check=E.W,E.R,E.check
local RS=E.RS;local Config=E.Config;local Data=E.Data;local Players=E.Players
local function T(tag)return function(c,msg)return check(c,'['..tag..'] '..msg)end end
local function section(tag,fn)
 local ok,err=xpcall(fn,debug.traceback)
 if not ok then check(false,'['..tag..'] the section crashed: '..tostring(err))end
end
local warns={}
W.env.warn=function(...)local t={};for i=1,select('#',...)do t[#t+1]=tostring((select(i,...)))end;warns[#warns+1]=table.concat(t,' ')end
local function warned(text)for _,w in ipairs(warns)do if w:find(text,1,true)then return true end end;return false end
local Rules=W.module('SeedPackRules');local D=W.module('DailyRewards');local PlantRules=W.module('PlantRules')
local TestPacks=E.server('OwnerTestPacks');local Cmd=E.server('StudioTestCommands');local HubSvc=E.server('HubDisplayService');local Announcer=E.server('PullAnnouncer')
local VC=W.module('VerityCatalog')
R.clock=20727*86400+3600*5
local function unix()return math.floor(R.clock)end
local function today()return D.Day(unix())end
local function drawConstant(x)return function()return x end end
local function emptyBag(p)local records=Data:GetChestRecords(p);for i=#records,1,-1 do table.remove(records,i)end end
local function packsOf(p)local out={};for _,r in ipairs(Data:GetChestRecords(p))do if r.Kind=='Pack'then out[#out+1]=r end end;return out end
local function find(p,id)for _,r in ipairs(Data:GetChestRecords(p))do if r.Id==id then return r end end end
-- the hub (BEST PULL) on the real data, with recording stand-ins for its art (as the R151 hook suite does)
local function art()
 local A={ItemBuilds={}}
 function A.BuildFrame(parent,kind)local m=R.new('Model');m.Name=kind;m.Parent=parent;local d={Kind=kind,Model=m,FeetAt=R.CFrame.new(0,0,0)};A[kind]=d;return d end
 function A.SetSign(d,t)d.Text=t end;function A.Tint()end
 function A.BuildItem(d,spec)A.ItemBuilds[#A.ItemBuilds+1]=spec;return R.new('Model'),{Parts=1}end
 function A.SetItem()end;function A.SetAvatar()end;function A.Counts()return{Frame=1,Item=1,Avatar=1}end
 return A
end
local avatars={Build=function()return R.new('Model'),'avatar'end,Place=function()return true end}
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap'
local hubClock={t=1000}
local function newHub(noLoop)
 return HubSvc.new(Config,Data,E.Notes,{MapRoot=mapRoot},{Clock=function()return hubClock.t end,Time=unix,Art=art(),Avatars=avatars,NoLoop=noLoop,Store=E.server('HubDisplayStore').new({Disabled=true})})
end
local hub=newHub(true);hub:Start()
Data.OnPackOpened=function(p,r,i)hub:NotePull(p,r,i)end
local ctx={Config=Config,Data=Data,Map={MapRoot=mapRoot},Chase={IsPlayerBusy=function()return false end,HubDisplays=hub},Bases={GetPlayerBase=function()return nil end,StopTraining=function()end},
 Chests=setmetatable({IsOpening=function()return false end,SyncTools=function()end,RenderGarden=function()end},{__index=E.server('ChestService')})}
local function command(p,text)return Cmd.Execute(ctx,p,text)end
local function openAll(p)
 local n=0
 for _,pack in ipairs(packsOf(p))do local reward=Data:OpenSeedPack(p,pack.Id,drawConstant(.5));if reward then n+=1 end end
 return n
end
local function finishQuests(p) -- the quests done by hand (no command): what a real player's day looks like
 local daily,quests=Data:DailyData(p)
 for i,q in ipairs(quests.Keys)do daily.Quests.Progress[i]=D.Quests[q].Goal end
 Data:PublishDaily(p)
end
local function setDay7(p) -- the login week is on day 6: the next claim is the day-7 Void Pack (what `daily week` sets, without arming anything)
 local daily=Data:DailyData(p);daily.Login={Step=#D.Login-1,Day=today()-1};Data:PublishDaily(p)
end

-- [M1] owner daily commands -------------------------------------------------------------------------------------------------------------------------------------------------
section('M1',function()
 local t=T('M1')
 local Ann=E.makePlayer(1001,'Ann');local Bob=E.makePlayer(1002,'Bob')
 -- 1. `daily done`, then the three quest claims: three TEST packs (the review's case 1: they were real packs, announced and counted)
 hub:Reset()
 local ok,msg=command(Ann,'/test daily done');t(ok==true,'/test daily done works ('..tostring(msg)..')')
 t(TestPacks.Armed(Ann,'DailyQuest'),'it arms the quest packs (their own source: DailyQuest)')
 local claimed=0;for i=1,3 do local c=Data:ClaimDailyQuest(Ann,i);if c then claimed+=1 end end
 t(claimed==3,'the three quest claims work')
 local packs=packsOf(Ann)
 t(#packs==3,'three quest packs in the bag ('..#packs..')')
 local allTest=#packs>0;for _,p in ipairs(packs)do if p.TestGrant~=true then allTest=false end end
 t(allTest,'every quest pack made after `daily done` is a TEST pack (TestGrant=true)')
 t(not TestPacks.Armed(Ann,'DailyQuest'),'the arms are used up by the three claims')
 -- never announced, never BEST PULL
 local announced=false
 for _,p in ipairs(packs)do local okA,sched,why=pcall(Announcer.Pulled,{Data=Data},Ann,p,{Rarity='King',SeedId='x'},false);if not(okA and sched==false and why=='test pack')then announced=true end end
 t(not announced,'the announcer refuses every one of them as a "test pack" (never announced)')
 local opened=openAll(Ann)
 t(opened==3 and hub:Snapshot().Pull.Record==nil,'opening them puts nothing on the BEST PULL board')
 -- a real pack of the same owner later in the session does not count either (the owner was given packs by a command: tainted for the session, like /test pack)
 emptyBag(Ann)
 local real=Data:AddChest(Ann,{Stage=4,BagVariant='Pack03',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
 Data:OpenSeedPack(Ann,real.Id,drawConstant(.5))
 t(hub:Snapshot().Pull.Record==nil,'the owner is tainted for the BEST PULL board after a daily command (a later real pack does not count)')
 -- 2. the review's case 2: next, week, done, then a QUEST claim first and the day-7 login claim after it: both stay TEST packs
 local Cy=E.makePlayer(1003,'Cy')
 command(Cy,'/test daily next');command(Cy,'/test daily week');command(Cy,'/test daily done')
 t(TestPacks.Armed(Cy,'Daily')and TestPacks.Armed(Cy,'DailyQuest'),'next + week + done: the login pack and the quest packs are armed apart')
 local q1=Data:ClaimDailyQuest(Cy,1)
 local l7,lmsg,info=Data:ClaimDailyLogin(Cy)
 t(q1==true and l7==true,'a quest claim, then the login claim work ('..tostring(lmsg)..')')
 t(info and info.Day==7,'the login claim is day 7')
 local byVariant={};for _,p in ipairs(packsOf(Cy))do byVariant[p.BagVariant]=p end
 local void=byVariant.EclipseReliquary
 t(void~=nil and void.TestGrant==true,'the day-7 Void Pack stays a TEST pack although a quest was claimed first')
 local quest;for _,p in ipairs(packsOf(Cy))do if p.BagVariant~='EclipseReliquary'then quest=p end end
 t(quest~=nil and quest.TestGrant==true,'... and so is the quest pack')
 -- the other order
 local Di=E.makePlayer(1004,'Di')
 command(Di,'/test daily week');command(Di,'/test daily done')
 Data:ClaimDailyLogin(Di);Data:ClaimDailyQuest(Di,1)
 local flags={};for _,p in ipairs(packsOf(Di))do flags[#flags+1]=p.TestGrant==true end
 t(#flags==2 and flags[1]and flags[2],'login first, then a quest: both TEST packs')
 -- 3. daily next / reset: the login pack and the quests of the test day, claimed an hour later
 local Ed=E.makePlayer(1005,'Ed')
 Data:ClaimDailyLogin(Ed);emptyBag(Ed) -- (the login of the day is used up: next brings it back)
 command(Ed,'/test daily next')
 R.clock+=3600
 t(TestPacks.Armed(Ed,'Daily')and TestPacks.Armed(Ed,'DailyQuest'),'`daily next` is still a test day an hour later (the arms last until UTC midnight, not 15 minutes)')
 local lok=Data:ClaimDailyLogin(Ed);finishQuests(Ed);local qok=Data:ClaimDailyQuest(Ed,2)
 local ps=packsOf(Ed);t(lok and qok and #ps==2 and ps[1].TestGrant==true and ps[2].TestGrant==true,'the login pack and a quest pack of the test day are TEST packs ('..#ps..' packs)')
 -- ... and the next UTC day is a normal day again
 R.clock=(today()+1)*86400+120
 E.advance(1)
 emptyBag(Ed);t(not TestPacks.Armed(Ed,'Daily')and not TestPacks.Armed(Ed,'DailyQuest'),'after UTC midnight nothing is armed any more')
 finishQuests(Ed);Data:ClaimDailyQuest(Ed,1);Data:ClaimDailyLogin(Ed)
 local after=packsOf(Ed);local allReal=#after==2;for _,p in ipairs(after)do if p.TestGrant~=nil then allReal=false end end
 t(allReal,'the next day\'s login and quest packs are normal packs')
 -- 4. `daily reset`
 local Flo=E.makePlayer(1006,'Flo')
 command(Flo,'/test daily reset');finishQuests(Flo)
 Data:ClaimDailyLogin(Flo);Data:ClaimDailyQuest(Flo,1)
 local fl=packsOf(Flo);t(#fl==2 and fl[1].TestGrant==true and fl[2].TestGrant==true,'`daily reset`: the login pack and a quest pack are TEST packs')
 -- 5. status only (no sub-command) arms and taints nothing
 local Gus=E.makePlayer(1007,'Gus')
 local okS,stat=command(Gus,'/test daily');t(okS==true and not TestPacks.Armed(Gus,'Daily')and not TestPacks.Armed(Gus,'DailyQuest'),'`daily` alone only shows the state: nothing armed')
 finishQuests(Gus);Data:ClaimDailyQuest(Gus,1)
 t(packsOf(Gus)[1].TestGrant==nil,'... so a quest pack after it is a normal pack')
 -- 6. real players are unchanged: Bob never had a command (and the owner's arms are per player)
 finishQuests(Bob);for i=1,3 do Data:ClaimDailyQuest(Bob,i)end
 setDay7(Bob);Data:ClaimDailyLogin(Bob)
 local bp=packsOf(Bob);local bobReal=#bp==4;for _,p in ipairs(bp)do if p.TestGrant~=nil then bobReal=false end end
 t(bobReal,'a player who never had a command: 3 quest packs + the day-7 Void Pack, none of them TEST ('..#bp..')')
 hub:Reset();openAll(Bob)
 t(hub:Snapshot().Pull.Record~=nil and hub:Snapshot().Pull.Record.Name=='Bob','... and their pulls count for BEST PULL')
 -- the claim of a real player is announced as before: the announcer does not refuse it as a test pack
 local refused=false;for _,p in ipairs(bp)do if p.TestGrant==true then refused=true end end
 t(not refused,'(a real daily pack carries no TestGrant, so the announcer treats it like any pack)')
end)

-- helpers for M2 / L4: the gifting harness (FruitGiftService on the real data) ---------------------------------------------------------------------------------------------
local Chase={Busy={}};function Chase:IsPlayerBusy(p)return self.Busy[p]==true end
local Chests={Openings={}}
function Chests:SyncTools(p)
 local ids={};for _,r in ipairs(Data:GetChestRecords(p))do ids[r.Id]=r end
 local crops={};for _,c in ipairs(Data.Gardens[p].Harvests)do crops[c.Id]=true end
 for _,container in ipairs({p:FindFirstChildOfClass('Backpack'),p.Character})do
  for _,tool in ipairs(container and container:GetChildren()or{})do if tool:IsA('Tool')then
   local sid=tool:GetAttribute('SeedInventoryId');local hid=tool:GetAttribute('HarvestInventoryId')
   if(sid and not ids[sid])or(hid and not crops[hid])then tool:Destroy()end
  end end
 end
end
W.env.RaycastParams={new=function()return {}end}
function W.workspace.Raycast()return nil end
local Gifts=E.server('FruitGiftService').new(Data,Chests,Chase,nil)
local function withBody(p,x)
 local c=R.new('Model');c.Name=p.Name;c.Parent=W.workspace
 local h=R.new('Humanoid');h.Health=100;h.Parent=c
 function h.UnequipTools()for _,tool in ipairs(c:GetChildren())do if tool:IsA('Tool')then tool.Parent=p:FindFirstChildOfClass('Backpack')end end end
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=R.Vector3.new(x,3,0);root.Parent=c
 p.Character=c
 p:SetAttribute('PaidTradingAllowed',true);p:SetAttribute('PaidRandomAllowed',true)
 Data:GetPremium(p).Tutorial.Done=true;Data:PublishTutorial(p)
 return p
end
local function hold(p,record)
 local tool=R.new('Tool');tool.Name=record.Kind=='Pack'and'Test Pack'or'Test Seed'
 if record.Kind=='Pack'then tool:SetAttribute('SeedPackTool',true)else tool:SetAttribute('GardenSeed',true)end
 tool:SetAttribute('SeedInventoryId',record.Id);tool.Parent=p.Character;return tool
end
local function holdFruit(p,crop)local tool=R.new('Tool');tool.Name='Golden Apple';tool:SetAttribute('HarvestItemTool',true);tool:SetAttribute('HarvestInventoryId',crop.Id);tool.Parent=p.Character;return tool end
local function statusSince(p,n)for i=#E.sent,n+1,-1 do local s=E.sent[i];if s.Remote=='FruitGift'and s.P==p and s.Args[1]=='Status'then return s.Args[2]end end end
local function tick()E.advance(3)end -- (the give click has a 2 s gap per player)
local function offerSeed(from,to,id)tick();local n=#E.sent;Gifts:OfferSeed(from,to.UserId,id);return statusSince(from,n)end
local function offerFruit(from,to,id)tick();local n=#E.sent;Gifts:Offer(from,to.UserId,id);return statusSince(from,n)end
-- open `pack` until its seed can be planted (not every seed has a plant yet); returns the seed record
local function openPlantable(p,make)
 for _,roll in ipairs({.5,.2,.8,.05,.95,.35,.65,.5001})do
  local pack=make()
  local seed=Data:OpenSeedPack(p,pack.Id,drawConstant(roll))
  if seed and Config.GardenPlants[seed.SeedId]then return seed,pack end
  if seed then local r=Data:GetChestRecords(p);for i=#r,1,-1 do if r[i].Id==seed.Id then table.remove(r,i)end end end
 end
end
local function voidPack(p,locked,extra)
 local chest={Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion,GiftLocked=locked or nil}
 return Data:AddChest(p,chest,extra)
end
local profileOut

-- [M2] the lock follows the value ------------------------------------------------------------------------------------------------------------------------------------------
section('M2',function()
 local t=T('M2')
 local Amy=withBody(E.makePlayer(1101,'Amy'),0);local Ben=withBody(E.makePlayer(1102,'Ben'),6)
 -- the giveaway pack -> the seed
 local lockedPack=voidPack(Amy,true)
 t(lockedPack.GiftLocked==true,'(the giveaway pack is GiftLocked)')
 local seed=Data:OpenSeedPack(Amy,lockedPack.Id,drawConstant(.5))
 t(seed and seed.Kind=='Seed','the pack opens ('..tostring(seed)..')')
 t(seed and seed.GiftLocked==true,'the seed opened from a GiftLocked pack is GiftLocked (review M2: the lock was lost at the open)')
 -- saved and loaded: an optional field of the seed row
 local row=seed and Data:SerializeSeedRecord(seed)
 t(row and row.GiftLocked==true and row.Kind=='Seed','SerializeSeedRecord keeps the lock on a Seed row')
 local saved=Data:_buildSaveData(Amy)
 local savedRow;for _,r in ipairs(saved.Chests or saved.Items or{})do if seed and r.Id==seed.Id then savedRow=r end end
 if not savedRow then for k,v in pairs(saved)do if type(v)=='table'then for _,r in pairs(v)do if type(r)=='table'and seed and r.Id==seed.Id and r.Kind=='Seed'then savedRow=r end end end end end
 t(savedRow~=nil and savedRow.GiftLocked==true,'the saved profile row of the seed has GiftLocked = true')
 local d2=E.newData();d2.Store.Data[d2:_getKey({UserId=1103,Name='Amy2'})]=E.deep(saved)
 local back=E.makePlayer(1103,'Amy2',d2)
 local backSeed;for _,r in ipairs(d2:GetChestRecords(back))do if seed and r.Id==seed.Id then backSeed=r end end
 t(backSeed~=nil and backSeed.GiftLocked==true,'... and after a load on another server the seed is still locked')
 -- an ordinary Void pack: no lock anywhere (the field is optional)
 local plainPack=voidPack(Ben,false)
 local plainSeed=Data:OpenSeedPack(Ben,plainPack.Id,drawConstant(.5))
 t(plainSeed and plainSeed.GiftLocked==nil and Data:SerializeSeedRecord(plainSeed).GiftLocked==nil,'an ordinary pack opens into an unlocked seed, and its row has no GiftLocked key')
 -- the Verity conversion keeps the lock to the seed
 local vp=voidPack(Amy,true);local conv=Data:ConvertVoidPack(Amy,vp.Id)
 t(conv and conv.BagVariant==VC.Variant and conv.GiftLocked==true,'(the Verity Pack made from a locked Void Pack is locked)')
 local vseed=conv and Data:OpenSeedPack(Amy,conv.Id,drawConstant(.5))
 t(vseed and vseed.GiftLocked==true,'... and its seed is locked too')
 -- the plant and its fruit
 local seedL,packL=openPlantable(Amy,function()return voidPack(Amy,true)end)
 t(seedL~=nil,'(a plantable locked seed)')
 local okP,crop=Data:PlantSeed(Amy,1,seedL.Id,{OffsetX=0,OffsetZ=0},unix())
 t(okP==true and crop and crop.GiftLocked==true,'the plant grown from a locked seed is locked (PlantRules.NewCrop)')
 local stored;for _,c in ipairs(Data.Gardens[Amy].Plots['1'])do if crop and c.Id==crop.Id then stored=c end end
 t(stored and stored.GiftLocked==true,'... in the garden too')
 local readyAt=crop and crop.ReadyAt or 0
 local okH,fruit=Data:HarvestPlant(Amy,1,crop.Id,readyAt+1,nil)
 t(okH==true and fruit and fruit.GiftLocked==true,'the fruit harvested from it is locked')
 local keptFruit;for _,c in ipairs(Data.Gardens[Amy].Harvests)do if fruit and c.Id==fruit.Id then keptFruit=c end end
 t(keptFruit and keptFruit.GiftLocked==true,'... in the harvest bag')
 -- an unlocked seed grows unlocked fruit
 local seedU=openPlantable(Ben,function()return voidPack(Ben,false)end)
 local okPu,cropU=Data:PlantSeed(Ben,1,seedU.Id,{OffsetX=0,OffsetZ=0},unix())
 local okHu,fruitU=Data:HarvestPlant(Ben,1,cropU.Id,cropU.ReadyAt+1,nil)
 t(okPu and okHu and cropU.GiftLocked==nil and fruitU.GiftLocked==nil,'a plant and fruit from an unlocked seed carry no lock')
 -- a saved + loaded garden keeps the lock on plant and fruit (the garden keeps unknown fields) -- and an R152 server will keep them too (test_fixes_r152)
 local save2=Data:_buildSaveData(Amy)
 local d3=E.newData();d3.Store.Data[d3:_getKey({UserId=1104,Name='Amy3'})]=E.deep(save2)
 local back3=E.makePlayer(1104,'Amy3',d3)
 local lockedHarvests=0;for _,c in ipairs(d3.Gardens[back3].Harvests)do if c.GiftLocked==true then lockedHarvests+=1 end end
 t(lockedHarvests>=1,'a saved and loaded harvest bag keeps the lock on the fruit')
 -- plant a second locked seed to have a plant AND a harvest AND a locked seed AND a locked pack in one profile
 local seed2=openPlantable(Amy,function()return voidPack(Amy,true)end)
 Data:PlantSeed(Amy,2,seed2.Id,{OffsetX=0,OffsetZ=0},unix())
 voidPack(Amy,true);local seed3=Data:OpenSeedPack(Amy,voidPack(Amy,true).Id,drawConstant(.5))
 voidPack(Amy,true)
 profileOut=Data:_buildSaveData(Amy)
 -- gifting: FruitGiftService refuses every step ---------------------------------------------------------------------------------------------------------------------
 local giftPack=voidPack(Amy,true);local toolP=hold(Amy,giftPack)
 local said=offerSeed(Amy,Ben,giftPack.Id)
 t(find(Amy,giftPack.Id)~=nil and find(Ben,giftPack.Id)==nil and said==Gifts.LockedText,'a locked PACK is refused ('..tostring(said)..')')
 toolP:Destroy()
 local giftSeed=Data:OpenSeedPack(Amy,voidPack(Amy,true).Id,drawConstant(.5));local toolS=hold(Amy,giftSeed)
 said=offerSeed(Amy,Ben,giftSeed.Id)
 t(find(Amy,giftSeed.Id)~=nil and find(Ben,giftSeed.Id)==nil,'a locked SEED (opened from a locked pack) is not gifted: the giver keeps it, the receiver gets nothing (review M2)')
 t(said==Gifts.LockedSeedText,'... with a short clear notice ('..tostring(said)..')')
 toolS:Destroy()
 local toolF=holdFruit(Amy,fruit)
 said=offerFruit(Amy,Ben,fruit.Id)
 local stillMine=false;for _,c in ipairs(Data.Gardens[Amy].Harvests)do if c.Id==fruit.Id then stillMine=true end end
 local theirs=false;for _,c in ipairs(Data.Gardens[Ben].Harvests)do if c.Id==fruit.Id then theirs=true end end
 t(stillMine and not theirs,'locked FRUIT (harvested from a locked seed\'s plant) is not gifted either')
 t(said==Gifts.LockedFruitText,'... with a short clear notice ('..tostring(said)..')')
 toolF:Destroy()
 -- the same refusal if an offer reaches Accept directly (a stale offer)
 local toolF2=holdFruit(Amy,fruit)
 local gid='stale-fruit';Gifts.Offers[gid]={From=Amy,To=Ben,CropId=fruit.Id,Expires=R.clock+25}
 Gifts:Accept(Ben,gid)
 stillMine=false;for _,c in ipairs(Data.Gardens[Amy].Harvests)do if c.Id==fruit.Id then stillMine=true end end
 t(stillMine,'an offer that reaches Accept for locked fruit changes nothing')
 toolF2:Destroy()
 -- controls: unlocked items still travel (the fix locks the giveaway\'s value, nothing else)
 local freePack=voidPack(Amy,false);local toolC=hold(Amy,freePack)
 offerSeed(Amy,Ben,freePack.Id);E.advance(5)
 t(find(Ben,freePack.Id)~=nil and find(Amy,freePack.Id)==nil,'control: an ordinary Void pack is still gifted')
 toolC:Destroy()
 local toolU=holdFruit(Ben,fruitU)
 said=offerFruit(Ben,Amy,fruitU.Id);E.advance(5)
 local sent=true;for _,c in ipairs(Data.Gardens[Ben].Harvests)do if c.Id==fruitU.Id then sent=false end end
 t(sent and said~=Gifts.LockedFruitText,'control: fruit from an unlocked seed is still gifted ('..tostring(said)..')')
 toolU:Destroy()
end)

-- [L4] the day-7 login Void Pack ----------------------------------------------------------------------------------------------------------------------------------------------
section('L4',function()
 local t=T('L4')
 local Hal=withBody(E.makePlayer(1201,'Hal'),0);local Ivy=withBody(E.makePlayer(1202,'Ivy'),6)
 t(D.LockDay7Void==true,'DailyRewards.LockDay7Void exists and is true by default')
 setDay7(Hal)
 local ok,msg,info=Data:ClaimDailyLogin(Hal)
 local pack=packsOf(Hal)[1]
 t(ok==true and info and info.Day==7 and pack and pack.BagVariant=='EclipseReliquary'and pack.Stage==7,'the day-7 login claim gives a Void Pack ('..tostring(msg)..')')
 t(pack and pack.GiftLocked==true and pack.TestGrant==nil,'it is GiftLocked (review L4: an alt could gift it unopened) and a real pack')
 local row=pack and Data:SerializeSeedRecord(pack)
 t(row and row.GiftLocked==true,'the lock is saved with it')
 -- it can't be gifted
 local tool=hold(Hal,pack);local said=offerSeed(Hal,Ivy,pack.Id)
 t(find(Hal,pack.Id)~=nil and find(Ivy,pack.Id)==nil and said==Gifts.LockedText,'FruitGiftService refuses it ('..tostring(said)..')')
 tool:Destroy()
 -- opened: the seed is locked too (M2)
 local seed=Data:OpenSeedPack(Hal,pack.Id,drawConstant(.5))
 t(seed and seed.GiftLocked==true,'its seed stays locked')
 -- the switch: false allows gifting
 D.LockDay7Void=false
 local Jo=withBody(E.makePlayer(1203,'Jo'),12);setDay7(Jo);Data:ClaimDailyLogin(Jo)
 local open=packsOf(Jo)[1]
 t(open and open.BagVariant=='EclipseReliquary'and open.GiftLocked==nil,'with LockDay7Void = false the day-7 Void Pack carries no lock')
 local tool2=hold(Jo,open);local Kai=withBody(E.makePlayer(1204,'Kai'),18)
 offerSeed(Jo,Kai,open.Id);E.advance(5)
 t(find(Kai,open.Id)~=nil and find(Jo,open.Id)==nil,'... and it can be gifted')
 tool2:Destroy()
 -- missing / junk values lock (only an exact false opens it)
 for _,junk in ipairs({'no',0,'false'})do
  D.LockDay7Void=junk
  local x=withBody(E.makePlayer(1210+_,'Lu'..tostring(_)),0);setDay7(x);Data:ClaimDailyLogin(x)
  t(packsOf(x)[1] and packsOf(x)[1].GiftLocked==true,'a switch of '..tostring(junk)..' (not exactly false) keeps the lock')
 end
 D.LockDay7Void=nil
 local Mo=withBody(E.makePlayer(1220,'Mo'),0);setDay7(Mo);Data:ClaimDailyLogin(Mo)
 t(packsOf(Mo)[1] and packsOf(Mo)[1].GiftLocked==true,'a missing switch keeps the lock (safe by default)')
 D.LockDay7Void=true
 -- the other daily packs are not locked: login days 1-4 and quest packs stay giftable
 local Ned=withBody(E.makePlayer(1230,'Ned'),0)
 Data:ClaimDailyLogin(Ned);finishQuests(Ned);Data:ClaimDailyQuest(Ned,1)
 local plain=true;local n=0;for _,p in ipairs(packsOf(Ned))do n+=1;if p.GiftLocked~=nil then plain=false end end
 t(n==2 and plain,'a day-1 login pack and a quest pack are not locked ('..n..' packs)')
end)

-- [H6] the BEST PULL window loop -------------------------------------------------------------------------------------------------------------------------------------------
section('H6',function()
 local t=T('H6')
 local looping=newHub(false)
 looping:Start()
 local passes,failuresLeft=0,2
 local realSync=looping._syncWindow
 looping._syncWindow=function(self)
  passes+=1
  if failuresLeft>0 then failuresLeft-=1;error('bad value in the pull window')end
  return realSync(self)
 end
 local before=#warns
 local ok,err=pcall(E.advance,200)
 t(ok,'the loop does not take the scheduler down with it ('..tostring(err)..')')
 t(passes>=4,'the loop kept running after two failed passes ('..passes..' passes in 200 s)')
 t(warned('[R153] Hub displays'),'a failed pass is warned')
 t(#warns-before<=3,'... once, not on every pass ('..(#warns-before)..' warnings)')
 looping:Destroy()
 local pAfter=passes;pcall(E.advance,200)
 t(passes==pAfter,'a destroyed service stops its loop')
 -- a bad sleep value is survived too
 local bad=newHub(false);bad:Start()
 local flip=true;local realSleep=bad.SleepSeconds
 local n2=0
 bad.SleepSeconds=function(self)n2+=1;if flip then flip=false;error('bad sleep')end;return realSleep(self)end
 local ok2=pcall(E.advance,100)
 t(ok2 and n2>=3,'a pass whose sleep value is bad is survived ('..n2..' sleeps)')
 bad:Destroy()
end)

-- [A3] test hooks inside gameplay --------------------------------------------------------------------------------------------------------------------------------------------
section('A3',function()
 local t=T('A3')
 local Pam=withBody(E.makePlayer(1301,'Pam'),0)
 -- the walk speed asks OwnerTestState82 (Config.GetPlayerWalkSpeed)
 local State=E.server('OwnerTestState82');local realGet=State.GetSpeed
 local expected=Config.GetWalkSpeed(0)
 State.GetSpeed=function()error('test state exploded')end
 local ok,speed=pcall(Config.GetPlayerWalkSpeed,Pam,0)
 t(ok and speed==expected,'a failing OwnerTestState82 means "no override": the real walk speed ('..tostring(speed)..' / '..tostring(expected)..')')
 State.GetSpeed=realGet
 State.SetSpeed(Pam,77);local okO,speedO=pcall(Config.GetPlayerWalkSpeed,Pam,0)
 t(okO and speedO==77,'control: a working override still wins ('..tostring(speedO)..')')
 State.SetSpeed(Pam,nil)
 -- the pack open asks RarePackTests.Expected (PlayerDataService:OpenSeedPack)
 local Rare=E.server('RarePackTests');local realExpected=Rare.Expected
 Rare.Expected=function()error('rare pack tests exploded')end
 local pack=Data:AddChest(Pam,{Stage=4,BagVariant='Pack03',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
 local okOpen,reward=pcall(Data.OpenSeedPack,Data,Pam,pack.Id,drawConstant(.5))
 t(okOpen and type(reward)=='table'and reward.Kind=='Seed','a pack still opens when RarePackTests.Expected fails ('..tostring(reward)..')')
 t(warned('RarePackTests.Expected failed'),'... and the failure is warned')
 -- the pack tool (ChestService:_createPackTool)
 local pack2=Data:AddChest(Pam,{Stage=4,BagVariant='Pack03',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
 local backpack=Pam:FindFirstChildOfClass('Backpack')
 local CS=E.server('ChestService')
 local okTool,tool=pcall(CS._createPackTool,{PlayerData=Data,Openings={}},pack2,backpack)
 t(okTool and tool~=nil and tool:GetAttribute('SeedInventoryId')==pack2.Id,'the pack tool is still made when RarePackTests.Expected fails ('..tostring(tool)..')')
 Rare.Expected=realExpected
 -- control: the hook still works when it works (a guaranteed TEST reveal)
 local seedId;for _,spec in ipairs(Rules.SeedDesigns)do if spec.id~='VeritySeed'and Rules.GetRarity(spec.id)=='King'then seedId=spec.id;break end end
 Rare.Expected=function(_,_,id)if id==pack2.Id then return seedId end end
 local okT2,tool2=pcall(CS._createPackTool,{PlayerData=Data,Openings={}},pack2,backpack)
 t(okT2 and tool2 and tool2.Name:find('TEST',1,true)~=nil,'control: a working hook still names a TEST pack ('..tostring(tool2 and tool2.Name)..')')
 Rare.Expected=realExpected
end)

if profileOut then print('PROFILE locked '..E.ser(profileOut))end
E.finish('R153 server fixes')
