--!nocheck
-- R152 Void Pack giveaway on the REAL player data (the R123 world, like R151's hub hook suite): the real PlayerDataService (AddChest, the Bag limit, Premium, Save / Load),
-- Config, SeedPackRules, SecurityGate, with the real VoidGiveaway152 / VoidGiveawayStore152 / VoidGiveawayArt152 on top (a recording ChestService stand-in and notice feed). Checks:
--  1. the pack the claim gives is a REAL Void Pack: Kind Pack, stage 7, EclipseReliquary, the current odds version, size 1, no coat, NOT TestGrant, no chip-bag shape (a Void pack has none);
--  2. it is what Verity takes (PlayerDataService:CheckVoidPack / ConvertVoidPack), and opening it counts as a real open (OnPackOpened with Test false: it announces like any pack);
--  3. the Bag limit is the game's own (R155: 200 items held, PlayerDataService:HeldItemCap; it was Config.MaxSavedChests = 1000): a full Bag reserves nothing; 199 + 1 is fine;
--  4. the profile flag lives in the saved Premium table: it survives Save and Load on another server, a profile without it (an old save) is simply not flagged, and the profile
--     version is unchanged (22): an older server copies the field it does not know (PremiumProgress.Decode keeps it);
--  5. a profile that cannot save is refused (a pack that cannot be saved would be lost); a reservation whose pack was lost with an unsaved profile is given again, once.
--  7. R158c (a claim needs a finished tutorial; the R157 20 minutes of play time are gone): a brand-new profile (TutorialDone false) is refused without a trace; the Skip request or finishing it the
--     normal way opens the claim with no play time; the Replay request is refused (TutorialDone stays true); one pack per player; a returning player is done at once; a player reserved earlier is not
--     held up; the play-time counter (Premium.PlaySeconds157, ProfileVersion still 22) is kept: saved, loaded across visits, junk reads as 0, in memory when the profile cannot save.
local W=require('./world');local R=W.R;local E=require('./announce_env')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS;local V3,CF=R.Vector3.new,R.CFrame.new
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
-- one backend for the player profiles AND the giveaway key (the same DataStoreService on every "server")
local stores={};local DS=W.service('DataStoreService')
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},Version={},
  UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v;self.Version[key]=(self.Version[key]or 0)+1 end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
W.stub('OwnerCommandAccess',{IsAllowed=function()return false end,Publish=function()return false end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 return o end end
local warns=0;W.env.warn=function()warns+=1 end
local Config=server('Config');local Packs=W.module('SeedPackRules');local Rules=W.module('VoidGiveawayRules152')
local PDS=server('PlayerDataService');local Svc=server('VoidGiveaway152');local Store=server('VoidGiveawayStore152')
local Map={GetStageAccent=function(_,s)return R.Color3.new(.5,.5,s/10)end}
local told={};local Notes={Show=function(_,p,text,color,secs,kind)told[#told+1]={P=p,Text=text,Kind=kind}end}
local function lastText(p)for i=#told,1,-1 do if told[i].P==p then return told[i].Text end end end
local synced=0;local Chests={SyncTools=function()synced+=1 end}
R.clock=20727*86400+3600*5
local function dataServer()return PDS.new(Config,Map,Notes)end
-- tutorial (R158c): the default is a player who has finished the tutorial (the real 'Skip' request, which also publishes TutorialDone = true); false = leave what the profile loaded (a brand-new profile starts at step 1)
local function makePlayer(Data,id,name,tutorial)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 if tutorial~=false then assert(Data:TutorialAction(p,'Skip'),'skip '..name)end
 local m=R.new('Model');m.Name=name;local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(0,5,-380);root.Parent=m;m.PrimaryPart=root
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=m;m.Parent=W.workspace;p.Character=m
 return p
end
local function leave(Data,p)
 Data:FinalizePlayer(p,'PlayerRemoving');present[p.UserId]=nil;p.Parent=nil
end
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local clock={t=1000}
local function giveaway(Data,o)
 o=o or{}
 local store=Store.new({Studio=false,Clock=function()return clock.t end,Time=function()return 1760000000 end,Wait=function()end,Random={NextNumber=function()return 0 end}})
 local root=R.new('Folder');root.Name='ChestChaseMap_'..tostring(#W.workspace:GetChildren());root.Parent=W.workspace
 local svc=Svc.new(Config,Data,Chests,Notes,{MapRoot=root},{Clock=function()return clock.t end,Time=function()return 1760000000 end,Store=store,Studio=false,NoLoop=true,
  Random={NextNumber=function()return 0 end}})
 svc:Start();return svc
end

-- 1. The pack is a real Void Pack ---------------------------------------------------------------------------------------------------------------------------------
local D1=dataServer();local svc1=giveaway(D1)
local A=makePlayer(D1,2001,'Ava');svc1:Step()
check(D1:HeldItemCap()==200,'the game\'s Bag limit is 200 items (R155: PlayerDataService:HeldItemCap; it was 1000 packs, Config.MaxSavedChests)')
local ok,record=svc1:Claim(A)
check(ok==true and record,'the claim works on the real player data ('..tostring(record)..')')
check(record.Kind=='Pack'and record.Stage==7 and record.BagVariant=='EclipseReliquary','a Void Pack: Kind Pack, stage 7, EclipseReliquary')
check(record.OddsVersion==Packs.OddsVersion and record.PackSize==1 and record.PackMutation=='None','the current odds version, 1x, no coat')
check(record.TestGrant==nil,'NOT a TestGrant pack: it announces when opened, like the track\'s')
check(record.PackShape==nil,'a Void pack has no chip-bag shape')
check(type(record.Id)=='string'and record.Id:match('^2001_%d+$')~=nil and record.ChestNumber==1,'a normal inventory id')
local records=D1:GetChestRecords(A);check(#records==1 and records[1]==record,'it is in the Bag, once')
check(D1:GetPremium(A).VoidGift152==true,'Premium.VoidGift152 = true')
check(A:GetAttribute('SeedInventoryCount')==1,'the inventory count the HUD shows is 1')
check(synced==1,'the hotbar was synced')
check(lastText(A):find('FREE VOID PACK',1,true)~=nil,'the notice')
check(svc1:Claim(A)==false and #D1:GetChestRecords(A)==1,'a second claim gives nothing')

-- 2. What Verity and the opening see -------------------------------------------------------------------------------------------------------------------------------
do
 local got,why=D1:CheckVoidPack(A,record.Id);check(got==record,'Verity accepts it (PlayerDataService:CheckVoidPack)')
 local verity=W.module('VerityConfig');check(verity.VoidVariant==record.BagVariant and record.Stage==7,'the variant and stage Verity looks for')
 -- opening: a real open (the hook the announcer and the hub read says Test false)
 local calls={};D1.OnPackOpened=function(p,r,i)calls[#calls+1]={R=r,I=i}end
 local B=makePlayer(D1,2002,'Bo');svc1:Step();svc1:Claim(B)
 local rec=D1:GetChestRecords(B)[1]
 local reward=D1:OpenSeedPack(B,rec.Id,function()return .5 end)
 check(reward and reward.Kind=='Seed'and #calls==1,'it opens like any Void Pack')
 check(calls[1].I.Variant=='EclipseReliquary'and calls[1].I.Stage==7 and calls[1].I.Test==false,'the open hook sees a real Void pack (Test false): it counts for the hub and announces')
 D1.OnPackOpened=nil
 local C=makePlayer(D1,2003,'Cy');svc1:Step();svc1:Claim(C)
 local cr=D1:GetChestRecords(C)[1]
 local converted=D1:ConvertVoidPack(C,cr.Id)
 check(converted and converted.BagVariant==W.module('VerityCatalog').Variant and converted.TestGrant==nil,'Verity can turn it into a Verity Pack (a real one: no TestGrant)')
end

-- 3. The Bag limit is the game's own ----------------------------------------------------------------------------------------------------------------------------------
do
 local F=makePlayer(D1,2010,'Full');svc1:Step()
 for i=1,D1:HeldItemCap() do assert(D1:AddChest(F,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion}),'fill '..i)end
 local before=stores['VoidGiveaway152']and stores['VoidGiveaway152'].Version.Claims
 local ok2,why=svc1:Claim(F)
 check(ok2==false and why=='room'and #D1:GetChestRecords(F)==D1:HeldItemCap(),'a full Bag (200 packs): refused, nothing added')
 check((stores['VoidGiveaway152']and stores['VoidGiveaway152'].Version.Claims)==before and not(stores['VoidGiveaway152'].Data.Claims.Users['2010']),'nothing reserved: the shared list does not have them and was not written')
 check(D1:GetPremium(F).VoidGift152==nil,'no flag')
 table.remove(D1:GetChestRecords(F));D1:_notifySeedInventory(F)
 check(svc1:Claim(F)==true and #D1:GetChestRecords(F)==D1:HeldItemCap(),'199 packs + 1 = exactly 200: allowed')
 check(lastText(F):find('FREE VOID PACK',1,true)~=nil,'and told')
end

-- 4. The flag is saved with the profile ---------------------------------------------------------------------------------------------------------------------------------
do
 check(Config.ProfileVersion==22,'ProfileVersion is still 22')
 D1:Save(A,'test',true);local profile=stores[Config.GetDataStoreName(false)].Data[tostring(2001)]or stores[Config.GetDataStoreName(false)].Data[next(stores[Config.GetDataStoreName(false)].Data)]
 local saved;for k,v in pairs(stores[Config.GetDataStoreName(false)].Data)do if type(v)=='table'and v.Premium and v.Premium.VoidGift152==true then saved=v end end
 check(saved~=nil,'the saved profile holds Premium.VoidGift152 = true')
 -- another server loads the profile: flag and pack are there
 leave(D1,A)
 local D2=dataServer();local svc2=giveaway(D2)
 local A2=makePlayer(D2,2001,'Ava');svc2:Step()
 check(D2:GetPremium(A2).VoidGift152==true and #D2:GetChestRecords(A2)==1 and D2:GetChestRecords(A2)[1].BagVariant=='EclipseReliquary','on another server the loaded profile has the flag and the Void Pack')
 check(A2:GetAttribute('VoidGift152')=='Claimed','the player is Claimed there')
 check(svc2:Claim(A2)==false and #D2:GetChestRecords(A2)==1,'a second claim on another server gives nothing')
 -- the save is by the existing Premium table: an older server (which knows no such field) keeps it
 local P=server('PremiumProgress');local decoded=P.Decode({Version=2,Gems=0,Entitlements={},Biomes={},Receipts={},Plants={},SeedRewards={},BalanceVersion81=81,IndexRewardVersion=104,VoidGift152=true})
 check(decoded and decoded.VoidGift152==true,'PremiumProgress.Decode (every server since R57) keeps an optional field it does not know')
 -- an old save, from before the giveaway: no flag, so the player is simply not flagged
 local old=makePlayer(D2,2020,'Old');svc2:Step()
 check(D2:GetPremium(old).VoidGift152==nil and old:GetAttribute('VoidGift152')=='Open','a profile without the field is not flagged and may claim')
 check(svc2:Claim(old)==true and D2:GetPremium(old).VoidGift152==true,'and does')
 -- a track-stolen Void Pack in the Bag does not stop the claim (the flag, not the Bag, decides)
 local owner=makePlayer(D2,2021,'Thief');svc2:Step()
 D2:AddChest(owner,{Stage=7,BagVariant='EclipseReliquary',PackSize=2,PackMutation='None',OddsVersion=Packs.OddsVersion},{Luck=true})
 check(svc2:Claim(owner)==true and #D2:GetChestRecords(owner)==2,'a player who already owns a Void Pack from the track can still claim the free one')
end

-- 5. A profile that cannot save; a pack lost with an unsaved profile ----------------------------------------------------------------------------------------------------
do
 local D3=dataServer();local svc3=giveaway(D3)
 local N=makePlayer(D3,2030,'NoSave');D3.CanSave[N]=false;svc3:Step()
 local ok3,why3=svc3:Claim(N);check(ok3==false and why3=='cannotsave'and #D3:GetChestRecords(N)==0,'a profile that cannot save: refused, nothing reserved')
 check(not(stores['VoidGiveaway152'].Data.Claims.Users['2030']),'... not in the shared list')
 -- reserved, the pack granted, then the server dies before the save: the next session has neither pack nor flag, and the list still has them: given once
 local L=makePlayer(D3,2031,'Lost');svc3:Step();svc3:Claim(L)
 check(#D3:GetChestRecords(L)==1 and stores['VoidGiveaway152'].Data.Claims.Users['2031']~=nil,'granted and listed (never saved)')
 present[2031]=nil;L.Parent=nil -- (the server crashed: no FinalizePlayer, no save)
 local D4=dataServer();local svc4=giveaway(D4)
 local L2=makePlayer(D4,2031,'Lost');check(#D4:GetChestRecords(L2)==0 and D4:GetPremium(L2).VoidGift152==nil,'the new session has neither the pack nor the flag')
 svc4:Step();check(#D4:GetChestRecords(L2)==1 and D4:GetPremium(L2).VoidGift152==true,'the server gives it (it is owed): one pack and the flag')
 svc4:Step();svc4:Claim(L2);check(#D4:GetChestRecords(L2)==1,'never twice')
 check(stores['VoidGiveaway152'].Data.Claims.Users['2031']~=nil,'(and still listed)')
 local n=0;for _ in pairs(stores['VoidGiveaway152'].Data.Claims.Users)do n+=1 end
 check(stores['VoidGiveaway152'].Data.Claims.Count==n,'Count equals the number of listed users ('..n..')')
end

-- 6. GiftLocked: a free giveaway pack can't be gifted; the lock is an OPTIONAL record field (like PackShape) -----------------------------------------------------------------
do
 local profileStore=stores[Config.GetDataStoreName(false)]
 local function savedRow(id)for _,v in pairs(profileStore.Data)do if type(v)=='table'then for _,r in ipairs(v.Seeds or{})do if r.Id==id then return r end end end end end
 local function recOf(D,p,id)for _,r in ipairs(D:GetChestRecords(p))do if r.Id==id then return r end end end
 local D=dataServer();local svc=giveaway(D)
 local P=makePlayer(D,2040,'Locked');svc:Step();local ok,rec=svc:Claim(P)
 check(ok==true and rec.GiftLocked==true,'A1: the giveaway pack is GiftLocked (the real AddChest keeps the field)')
 local row=D:SerializeSeedRecord(rec);check(row.GiftLocked==true and row.Kind=='Pack','A1: it is serialised (SerializeSeedRecord: the same row a save and a gift use)')
 local plain=D:AddChest(P,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})
 check(plain.GiftLocked==nil and D:SerializeSeedRecord(plain).GiftLocked==nil,'A1: an ordinary Void pack (the track\'s) carries no lock')
 local shaped=D:AddChest(P,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion,GiftLocked=true})
 check(shaped.GiftLocked==true,'A1: any pack added with GiftLocked=true keeps it')
 table.remove(D:GetChestRecords(P))
 -- decode: exactly true, packs only
 local function decode(extra)
  local r={Id='d1',Kind='Pack',ChestNumber=9,ChestName='P',Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',SeedScale=1};for k,v in pairs(extra)do r[k]=v end
  return D:_decodeSavedSeedRecord(P,r,9)
 end
 check(decode({GiftLocked=true}).GiftLocked==true,'A1: a saved GiftLocked=true reads as locked')
 check(decode({GiftLocked='yes'}).GiftLocked==nil and decode({GiftLocked=1}).GiftLocked==nil and decode({}).GiftLocked==nil,'A1: anything but exactly true (and an old row without the field) reads as not locked')
 check(decode({Kind='Seed',GiftLocked=true,SeedId='SunflowerSeed'}).GiftLocked==true and decode({Kind='Seed',GiftLocked='yes',SeedId='SunflowerSeed'}).GiftLocked==nil,'A1: a Seed row carries the lock too (R153 review M2: the seed of a locked pack stays locked), exactly true only')
 local gifted=D:DecodeGiftedSeed(P,row);check(gifted and gifted.GiftLocked==true,'A1: a row that reached the gift decoder keeps its lock (it cannot be shed by a gift)')
 -- saved with the profile; another server loads it
 local plainId=plain.Id;D:Save(P,'test',true)
 local saved=savedRow(rec.Id);check(saved and saved.GiftLocked==true and savedRow(plainId).GiftLocked==nil,'A1: the saved profile row has GiftLocked = true (the plain Void pack\'s row has none)')
 check(Config.ProfileVersion==22,'A1: ProfileVersion is still 22 (an optional field)')
 leave(D,P)
 local D2=dataServer();local svc2=giveaway(D2);local P2=makePlayer(D2,2040,'Locked');svc2:Step()
 local back=recOf(D2,P2,rec.Id);local backPlain=recOf(D2,P2,plainId)
 check(back and back.GiftLocked==true and backPlain and backPlain.GiftLocked==nil,'A1: on another server the loaded pack is still locked (and the other one is not)')
 -- Verity: the Verity Pack you get for a locked Void Pack is locked too; an ordinary one is not
 local c1=D2:ConvertVoidPack(P2,rec.Id);local c2=D2:ConvertVoidPack(P2,plainId);local VC=W.module('VerityCatalog')
 check(c1 and c1.BagVariant==VC.Variant and c1.GiftLocked==true,'A1: ConvertVoidPack carries the lock to the Verity Pack')
 check(c2 and c2.BagVariant==VC.Variant and c2.GiftLocked==nil,'A1: ... and an ordinary Void pack gives an unlocked Verity Pack')
 check(D2:SerializeSeedRecord(c1).GiftLocked==true,'A1: the Verity Pack\'s saved row keeps it')
 -- opening a locked pack: the seed that comes out is a Seed that keeps the lock (R153 review M2; it was lost at the open before)
 local P3=makePlayer(D2,2041,'Opener');svc2:Step();svc2:Claim(P3);local lp=D2:GetChestRecords(P3)[1]
 local seed=D2:OpenSeedPack(P3,lp.Id,function()return .5 end)
 check(seed and seed.Kind=='Seed'and seed.GiftLocked==true and D2:SerializeSeedRecord(seed).GiftLocked==true,'A1: an opened pack is a Seed record WITH the lock (and its saved row has it)')
 -- an R151 server (git history) loads a profile with the field, ignores it, and saves the row without it; everything else in the row is identical
 local old=RS:FindFirstChild('PlayerDataServiceR151')
 if not old then print('SKIP: the R151 PlayerDataService is not in the repository history, so the older-server check did not run')
 else
  old.Parent=folder
  local D151=W.require(old).new(Config,Map,Notes)
  -- (the locked pack is in a Verity Pack and a Void Pack now: give the profile a fresh locked Void Pack to read)
  local P4=makePlayer(D2,2042,'Old151');svc2:Step();svc2:Claim(P4);local lockedId=D2:GetChestRecords(P4)[1].Id;D2:Save(P4,'test',true);leave(D2,P4)
  local before=savedRow(lockedId);local copy={};for k,v in pairs(before)do copy[k]=v end
  local P151=makePlayer(D151,2042,'Old151')
  local found=recOf(D151,P151,lockedId)
  check(found and found.Kind=='Pack'and found.BagVariant=='EclipseReliquary'and found.Stage==7,'A1: an R151 server loads a save with a locked pack: the pack is there, unchanged')
  check(found and found.GiftLocked==nil,'A1: ... it does not know the field: nothing breaks, the lock is not carried (R151 has no gifting of it to protect)')
  D151:Save(P151,'test',true)
  local after=savedRow(lockedId);local same=after~=nil
  if after then for k,v in pairs(copy)do if k~='GiftLocked'and after[k]~=v then same=false;print('differs after an R151 save:',k,tostring(v),tostring(after[k]))end end
   for k in pairs(after)do if copy[k]==nil then same=false;print('new key after an R151 save:',k)end end end
  check(same and after.GiftLocked==nil and copy.GiftLocked==true,'A1: the R151 server writes the pack back WITHOUT the field and every other saved field is identical')
  leave(D151,P151)
  local D3=dataServer();local P5=makePlayer(D3,2042,'Old151');local again=recOf(D3,P5,lockedId)
  check(again and again.Kind=='Pack'and again.BagVariant=='EclipseReliquary','A1: an R152 server reads what the R151 server wrote (the pack is a normal Void pack)')
 end
end

-- 7. R158c (owner: "for the void pack there isn't a 20 minute lock anymore and requirement is just finishing the tutorial"): the tutorial rule on the REAL player data ------------------------
-- (makePlayer(Data, id, name, tutorial): the default is a player who has finished the tutorial (the real 'Skip' request); false leaves what the profile loaded: a brand-new profile starts at step 1)
do
 local REFUSAL='finish the tutorial to get your free void pack!'
 local profileStore=stores[Config.GetDataStoreName(false)]
 local function savedPremium(id)local v=profileStore.Data['Player_'..id];return v and v.Premium end
 local function played(D,p)return D:GetPremium(p)[Rules.PlayField]end
 local function tick(svc,seconds)for _=1,math.floor(seconds/2+.5)do clock.t+=2;svc:Step()end end
 local function claims()return stores['VoidGiveaway152']and stores['VoidGiveaway152'].Data.Claims end
 check(Config.ProfileVersion==22,'R158c: ProfileVersion is still 22 (the play-time counter is an optional field of the saved Premium table)')
 -- a brand-new profile has not finished the tutorial: the real data says so, and the claim is refused without a trace
 local D1=dataServer();local svc1=giveaway(D1)
 local P=makePlayer(D1,2101,'Fresh',false);svc1:Step()
 check(P:GetAttribute('TutorialDone')==false and D1:GetPremium(P).Tutorial.Done==false,'R158c: a brand-new profile: the real player data publishes TutorialDone = false')
 local before=claims()and claims().Count or 0
 local ok,why=svc1:Claim(P)
 check(ok==false and why=='tutorial'and lastText(P)==REFUSAL,'R158c: ... and it cannot claim yet: "finish the tutorial to get your free void pack!"')
 check(#D1:GetChestRecords(P)==0 and D1:GetPremium(P).VoidGift152==nil and(claims()and claims().Count or 0)==before and not(claims()and claims().Users['2101']),'R158c: ... nothing reserved, no pack, no flag')
 check(P:GetAttribute('VoidGift152')=='Open'and P:GetAttribute('VoidPlayLeft157')==nil,'R158c: ... the player stays Open, and there is no play-time attribute')
 -- the Replay request is refused: nothing changes (here the tutorial is not finished yet, so it cannot be "reset" either)
 local mask0=D1:GetPremium(P).Tutorial.Mask
 check(D1:TutorialAction(P,'Replay')==false and P:GetAttribute('TutorialDone')==false and D1:GetPremium(P).Tutorial.Mask==mask0,'R158c: the Replay request is refused on a new profile too (nothing changes)')
 -- skipping the tutorial counts as finished (the real 'Skip' request: TutorialAction): the claim goes through with 0 minutes played
 local played0=played(D1,P)
 check(D1:TutorialAction(P,'Skip')==true and P:GetAttribute('TutorialDone')==true,'R158c: the Skip request finishes the tutorial (TutorialDone = true)')
 local ok2,rec=svc1:Claim(P)
 check(ok2==true and rec and rec.BagVariant=='EclipseReliquary'and #D1:GetChestRecords(P)==1 and D1:GetPremium(P).VoidGift152==true and(played0==nil or played0<60),'R158c: ... the claim works at once with no play time: one real Void Pack and the flag')
 -- the Replay request: refused, and TutorialDone stays true (an old client's button, or an exploit)
 local state=D1:GetPremium(P).Tutorial;local maskDone=state.Mask
 check(D1:TutorialAction(P,'Replay')==false and P:GetAttribute('TutorialDone')==true and state.Done==true and state.Mask==maskDone and D1:GetPremium(P).Tutorial==state,'R158c: the Replay request is refused: TutorialDone stays true, the state is the same table, mask and Done unchanged')
 check(P:GetAttribute('TutorialStep')==0,'R158c: ... and the step stays 0 (nothing restarted)')
 -- one pack per player, with the real data: a second claim is refused as "claimed"
 local ok2b,why2b=svc1:Claim(P);check(ok2b==false and why2b=='claimed'and #D1:GetChestRecords(P)==1 and lastText(P):find('already grabbed',1,true)~=nil,'R158c: a second claim is refused ("already grabbed"): still one pack')
 -- finishing the tutorial the normal way (the three steps, then the treadmill slide) opens it too
 local P7=makePlayer(D1,2107,'Walker',false);svc1:Step()
 local st=D1:GetPremium(P7).Tutorial;local Guide=W.module('BeginnerGuide');st.Mask=bit32.bor(st.Mask,Guide.Bits.Pack,Guide.Bits.Seed,Guide.Bits.Plant);D1:PublishTutorial(P7)
 check(svc1:Claim(P7)==false and lastText(P7)==REFUSAL,'R158c: on the last slide but not finished: refused')
 check(D1:TutorialAction(P7,'TreadmillInfo')==true and P7:GetAttribute('TutorialDone')==true and svc1:Claim(P7)==true and #D1:GetChestRecords(P7)>=1,'R158c: finishing it the normal way (the treadmill slide) opens the claim')
 -- the play-time counter is kept: the real server counts it, marks the profile dirty, a save writes it (a harmless field; no rule reads it)
 local P8=makePlayer(D1,2108,'Counter');svc1:Step();D1.Dirty[P8]=false
 tick(svc1,600)
 check(played(D1,P8)==600 and D1.Dirty[P8]==true,'R158c: 10 minutes of looks: 600 s in the profile, marked dirty (the counter still counts)')
 check(D1:Save(P8,'test',true)==true and(savedPremium(2108)or{})[Rules.PlayField]==600,'R158c: a save writes Premium.PlaySeconds157 = 600')
 leave(D1,P8)
 local D2=dataServer();local svc2=giveaway(D2)
 local P82=makePlayer(D2,2108,'Counter');svc2:Step()
 check(played(D2,P82)==600 and svc2:_played(P82)==600,'R158c: the next visit loads 600 s (the counter is saved across visits)')
 tick(svc2,310);check(played(D2,P82)==910,'R158c: 310 s more: 910')
 leave(D2,P82)
 check((savedPremium(2108)or{})[Rules.PlayField]==910,'R158c: leaving saves the last seconds too (the final save is forced: 910)')
 -- 910 s played is still a claim like any other for a finished tutorial, 19 min 59 s or 0 s the same: play time is never a reason
 local D3=dataServer();local svc3=giveaway(D3)
 local P83=makePlayer(D3,2108,'Counter');svc3:Step()
 check(svc3:Claim(P83)==true and lastText(P83):find('play ',1,true)==nil and #D3:GetChestRecords(P83)==1,'R158c: with 910 s played and a finished tutorial: the claim goes through, no "play" line')
 leave(D3,P83)
 -- a Premium table keeps the field through Decode (any server since R57 copies a field it does not know), clean or not
 local PP=server('PremiumProgress');local base={Version=2,Gems=0,Entitlements={},Biomes={},Receipts={},Plants={},SeedRewards={},BalanceVersion81=81,IndexRewardVersion=104}
 local function decode(v)local t={};for k,x in pairs(base)do t[k]=x end;t[Rules.PlayField]=v;return PP.Decode(t)end
 check(decode(300)and decode(300)[Rules.PlayField]==300,'R158c: PremiumProgress.Decode keeps Premium.PlaySeconds157 (saved data stays compatible; an older server copies it back unchanged)')
 check(PP.Decode(base)and PP.Decode(base)[Rules.PlayField]==nil,'R158c: a saved Premium without it loads without it (no field is invented)')
 -- junk in the field: read as 0, written over by the next count
 local J=makePlayer(D3,2105,'Junk');D3:Save(J,'test',true);leave(D3,J)
 profileStore.Data['Player_2105'].Premium[Rules.PlayField]='abc'
 local D4=dataServer();local svc4=giveaway(D4);local J2=makePlayer(D4,2105,'Junk');svc4:Step()
 check(svc4:_played(J2)==0,'R158c: a saved value that is not a number reads as 0')
 tick(svc4,4);check(played(D4,J2)==4,'R158c: ... and the next count writes a number over it')
 -- the owner's command sets it on real data, Studio only (this server is a live one: refused)
 local okC,tC=Svc.PlaytimeCommand(nil,J2,{'30'});check(okC==false and tC:find('Studio only',1,true)and played(D4,J2)==4,'R158c: /test playtime on a live server is refused and changes nothing')
 -- a profile that cannot save (Studio without API access): counted in memory, nothing written
 local N=makePlayer(D4,2102,'Memory');D4.CanSave[N]=false;svc4:Step();local v0=profileStore.Version['Player_2102']
 tick(svc4,60);check(played(D4,N)==60,'R158c: a profile that cannot save still counts, in memory (60 s)')
 check(D4:Save(N,'test',true)==false and profileStore.Version['Player_2102']==v0 and profileStore.Data['Player_2102']==nil,'R158c: ... and nothing is written for it')
 -- a returning player (a save from before the tutorial existed) has no tutorial to finish: done at once, so the claim is open
 do
  local old=D4:_buildSaveData(J2);old.Premium=old.Premium or{};old.Premium.Tutorial=nil
  profileStore.Data['Player_2106']=old
  local D8=dataServer();local svc8=giveaway(D8);local R8=makePlayer(D8,2106,'Returning',false);svc8:Step()
  check(R8:GetAttribute('TutorialDone')==true,'R158c: a returning player (a save with no tutorial state) is done (TutorialDone = true)')
  check(svc8:Claim(R8)==true and #D8:GetChestRecords(R8)==1,'R158c: ... and can claim')
 end
 -- a player who was RESERVED earlier (the grant never saved): loads with a tutorial that is not finished, and is still given the pack
 local D5=dataServer();local svc5=giveaway(D5);local L=makePlayer(D5,2110,'Reserved');svc5:Step();svc5:Claim(L)
 check(#D5:GetChestRecords(L)==1 and claims().Users['2110']~=nil,'(granted, listed, never saved)')
 present[2110]=nil;L.Parent=nil -- (the server crashed: no save)
 local D6=dataServer();local svc6=giveaway(D6);local L2=makePlayer(D6,2110,'Reserved',false)
 check(L2:GetAttribute('TutorialDone')==false and #D6:GetChestRecords(L2)==0,'(the new session: no pack, the tutorial is not finished)')
 svc6:Step();check(#D6:GetChestRecords(L2)==1 and D6:GetPremium(L2).VoidGift152==true and lastText(L2):find('tutorial',1,true)==nil,'R158c: a player the giveaway already reserved for is given the pack with the tutorial not finished (the rule does not hold them up)')
 svc6:Step();svc6:Claim(L2);check(#D6:GetChestRecords(L2)==1,'... once')
end

print(string.format('giveaway real data: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
