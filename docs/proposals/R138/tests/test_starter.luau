--!nocheck
-- R138 (owner: "after the tutorial is done a free pack is given to them, a forest pack, its rates will be 2x luckier"):
-- the real PlayerDataService (TutorialProgress.GrantStarterPack, AddChest, OpenSeedPack, save/load), PremiumService's
-- Tutorial request and SeedPackRules / PackOdds137 with the 2x rate boost.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end;return o end end
local Config=server('Config')
local Rules=W.module('SeedPackRules');local Guide=W.module('BeginnerGuide')
local function tiers(odds)local t={};for id,p in pairs(odds or{})do local r=Rules.GetRarity(id);t[r]=(t[r]or 0)+p/100 end;return t end
-- 1. The 2x rates.
local plain,lucky=tiers(Rules.SeedOdds(Config,1,'Pack01',1)),tiers(Rules.SeedOdds(Config,1,'Pack01',1,nil,2))
check(math.abs(1/lucky.Legendary-30)<1e-6 and math.abs(1/lucky.Mythic-200)<1e-6,('2x pack: Legendary 1/%.0f, Mythic 1/%.0f (normal 1/60, 1/400)'):format(1/lucky.Legendary,1/lucky.Mythic))
check(math.abs(lucky.Uncommon-2*plain.Uncommon)<1e-9 and math.abs(lucky.Rare-2*plain.Rare)<1e-9 and lucky.Common<plain.Common,'every tier above Common is twice as likely')
local sum=0;for _,p in pairs(lucky)do sum+=p end;check(math.abs(sum-1)<1e-9,'the odds still add up to 100%')
check(Rules.SanitizeRateBoost(2)==2 and Rules.SanitizeRateBoost(50)==nil and Rules.SanitizeRateBoost('2')==nil,'only the 2x boost is accepted (no other values from saves)')
local same=true;for k,v in pairs(tiers(Rules.SeedOdds(Config,1,'Pack01',1,137,nil)))do if math.abs(v-(plain[k]or 0))>1e-12 then same=false end end
check(same,'packs without the boost are unchanged')
-- 2. The grant, with the real PlayerDataService.
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local shownNotes={}
local Data=server('PlayerDataService').new(Config,Map,{Show=function(_,p,text)shownNotes[#shownNotes+1]=text end})
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local A=makePlayer(301,'Ava')
local function packs(p)local n,lucky=0,nil;for _,r in ipairs(Data:GetChestRecords(p))do if r.Kind=='Pack'then n+=1;if r.RateBoost then lucky=r end end end;return n,lucky end
check(Data:GrantStarterPack(A)==nil,'nothing before the tutorial is finished')
Data:TutorialAction(A,'Skip');check(Data:GrantStarterPack(A)==nil and select(2,packs(A))==nil,'skipping the tutorial at the start gives nothing')
Data:TutorialAction(A,'Replay')
-- Finish the tutorial as PremiumService's Tutorial request does (PremiumService.new itself starts product loaders
-- that never settle on the mock, so its Tutorial branch is checked from source below).
local synced=0
local state=Data:GetPremium(A).Tutorial;state.Mask=bit32.bor(state.Mask,Guide.Bits.Pack,Guide.Bits.Seed,Guide.Bits.Plant);Data:PublishTutorial(A)
check(A:GetAttribute('TutorialStep')==5,'on the last (slides) step')
local function finish()
 if Data:TutorialAction(A,'TreadmillInfo')then Data:PublishTutorial(A)end
 if A:GetAttribute('TutorialDone')==true then local gift=Data:GrantStarterPack(A);if gift then synced+=1;Data.Notifications:Show(A,Guide.StarterPack.Notice)end end
end
finish()
local src=W.B.PremiumService
check(src:find("if(value=='TreadmillInfo'or value=='Skip')and p:GetAttribute('TutorialDone')==true then",1,true)and src:find('data:GrantStarterPack(p)',1,true)and src:find('chests:SyncTools(p)',1,true)and src:find('StarterPack.Notice',1,true),'the Tutorial request grants it, refreshes the hotbar and shows the notice')
local n,gift=packs(A)
check(A:GetAttribute('TutorialDone')==true and gift~=nil,'finishing the tutorial gives the pack ('..tostring(ok and'service up'or svc)..')')
check(gift and gift.Stage==1 and gift.BagVariant=='Pack01'and gift.RateBoost==2 and gift.OddsVersion==Rules.OddsVersion,'a Forest pack with 2x rates')
check(gift and gift.ChestName==Guide.StarterPack.Name,'named '..tostring(gift and gift.ChestName))
check(synced>=1 and shownNotes[#shownNotes]==Guide.StarterPack.Notice,'it shows up in the hotbar and a notice says so')
-- Once per account.
Data:TutorialAction(A,'Replay');local s2=Data:GetPremium(A).Tutorial;s2.Mask=bit32.bor(s2.Mask,Guide.Bits.Pack,Guide.Bits.Seed,Guide.Bits.Plant);Data:PublishTutorial(A)
finish()
check(select(1,packs(A))==n,'replaying the tutorial does not give another')
-- Saved and loaded with its boost.
local saved=Data:_buildSaveData(A)
local row;for _,r in ipairs(saved.Seeds or{})do if r.RateBoost then row=r end end
check(row and row.RateBoost==2 and saved.Premium and saved.Premium.StarterPack==true,'the boost and the "given" flag are saved')
local back=Data:_decodeSavedSeedRecord(A,row,1);check(back.RateBoost==2,'and load back')
local forged=Data:_decodeSavedSeedRecord(A,{Id='x',Kind='Pack',Stage=1,BagVariant='Pack01',RateBoost=1000,ChestNumber=5},5);check(forged.RateBoost==nil,'a forged boost in a save is dropped')
-- Opening it rolls the 2x odds.
local legend,total=0,0
for i=1,4000 do
 local rec=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion,RateBoost=2})
 local reward=rec and Data:OpenSeedPack(A,rec.Id,math.random)
 if reward then total+=1;if reward.Rarity=='Legendary'then legend+=1 end;Data:RemoveChest(A,reward.Id)end
end
check(total>3900 and math.abs(legend/total-1/30)<.012,('opening rolls the 2x odds: %.1f%% Legendary (1/30 = 3.3%%)'):format(legend/total*100))
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
