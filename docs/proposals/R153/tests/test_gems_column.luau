--!nocheck
-- R153: the Gems column of the player list, on the REAL PlayerDataService / PremiumProgress / DailyProgress (the R123 world, like R152's giveaway suite).
--  1. the cell: leaderstats.Gems is a StringValue tagged ChestChaseDisplayStat with Priority 0 (Speed 2, Cash 1: the higher number shows first, so the order is Speed, Cash, Gems),
--     formatted by CashNumbers.PlayerList, "0" for a new player, the saved balance after a load; the Speed and Cash cells are exactly as before
--  2. every way gems change follows the balance: R152 money auto-collect (CollectSaleCash), daily quest gems, the Cash -> Gems converter, spending (gem pass, Speed bundle, mech pack,
--     pass gift), the owner command's write; a refused spend changes nothing; an unchanged publish writes nothing
--  3. the display is never the truth: no second saved value (the save has no Gems key but Premium.Gems, a plain number), a rewritten cell is not read back, a stray leaderstats /
--     ChestChaseStats "Gems" cannot become the balance, the Cash legacy migration still works
--  4. clean-up: one attribute connection, none after leaving (or Destroying), nothing writes to the cell afterwards; asking again does not stack links
local W=require('./world');local R=W.R;local E=require('./announce_env')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
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
W.env.warn=function()end
local Config=server('Config');local PDS=server('PlayerDataService');local Numbers=W.module('CashNumbers');local Catalog=W.module('MechCatalog')
local Map={GetStageAccent=function(_,s)return R.Color3.new(.5,.5,s/10)end}
local Notes={Show=function()end}
R.clock=20727*86400+3600*5
local function dataServer()local D=PDS.new(Config,Map,Notes);D.PassOwnership=function()return false end;return D end
local nextId=3000
-- A player the way the server sets one up; before(p) runs between the join and PreparePlayer (to plant stray values).
local function makePlayer(Data,name,before,id)
 id=id or nextId;nextId+=1
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 if before then before(p)end
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local function leave(Data,p)Data:FinalizePlayer(p,'PlayerRemoving');Data:CleanupPlayer(p);present[p.UserId]=nil;p.Parent=nil end -- (the main script: PlayerRemoving -> FinalizePlayer, then CleanupPlayer)
local function cell(p,name)local l=p:FindFirstChild('leaderstats');return l and l:FindFirstChild(name)end
local function shown(p)local c=cell(p,'Gems');return c and c.Value end
local function gems(Data,p)return Data:GetPremium(p).Gems end
local function claimAll(Data,p)
 local owed=table.clone(Data.Gardens[p].PendingSales or{})
 for _,r in ipairs(owed)do for i=1,r.Count do Data:CollectSaleCash(p,r.Id,i)end end
 return #owed
end
local function same(Data,p,msg)
 local want=Numbers.PlayerList(gems(Data,p))
 check(shown(p)==want,msg..': the cell shows '..tostring(shown(p))..' for '..gems(Data,p)..' gems (want '..want..')')
end
local function liveConnections(signal)local n=0;for _,c in ipairs(signal._c)do if c.Connected then n+=1 end end;return n end

-- 1. the cell ---------------------------------------------------------------------------------------------------------------------------------------------------------
local D=dataServer();local P=makePlayer(D,'Ava')
do
 local leader=P:FindFirstChild('leaderstats')
 check(leader~=nil,'leaderstats exists')
 local g,c,s=cell(P,'Gems'),cell(P,'Cash'),cell(P,'Speed')
 check(g and g:IsA('StringValue')and g:GetAttribute('ChestChaseDisplayStat')==true,'Gems is a StringValue tagged ChestChaseDisplayStat')
 check(g and g:FindFirstChild('Priority')and g.Priority:IsA('NumberValue')and g.Priority.Value==0,'its Priority is 0')
 check(c and c.Priority.Value==1 and s and s.Priority.Value==2,'Cash is still Priority 1 and Speed 2')
 local cells={};for _,v in ipairs(leader:GetChildren())do cells[#cells+1]=v end
 table.sort(cells,function(a,b)return a.Priority.Value>b.Priority.Value end) -- the higher number shows first (the owner's screenshot: People, Speed, Cash)
 local names={};for _,v in ipairs(cells)do names[#names+1]=v.Name end
 check(table.concat(names,',')=='Speed,Cash,Gems','the order is Speed, Cash, Gems ('..table.concat(names,',')..')')
 check(#leader:GetChildren()==3,'exactly three cells (no stray column)')
 check(g and g.Value=='0'and gems(D,P)==0,'a new player shows 0')
 check(s:GetAttribute('ChestChaseDisplayStat')==true and c:GetAttribute('ChestChaseDisplayStat')==true,'the Speed and Cash cells are still display cells')
 check(P:FindFirstChild('ChestChaseStats')and not P.ChestChaseStats:FindFirstChild('Gems'),'no raw "Gems" object next to the raw Cash and Speed')
 local want={[0]='0',[47]='47',[999]='999',[1000]='1K',[1500]='1.5K',[12345]='12.3K',[999999]='1M',[1000000]='1M'}
 for amount,text in pairs(want)do check(Numbers.PlayerList(amount)==text,'PlayerList('..amount..') = '..text)end
 for _,amount in ipairs({47,999,1500,12345,999999,Catalog.MaxGems})do
  D:GetPremium(P).Gems=amount;D:PublishPremium(P);same(D,P,'balance '..amount)
 end
 D:GetPremium(P).Gems=1500;D:PublishPremium(P);check(shown(P)=='1.5K','1,500 gems read 1.5K')
 D:GetPremium(P).Gems=0;D:PublishPremium(P);check(shown(P)=='0','back to 0')
end

-- 2. every change follows the balance ------------------------------------------------------------------------------------------------------------------------------------
do
 -- R152 money auto-collect: a gem receipt flies to the balance and is claimed share by share
 local ok,why=D:QueueCurrency(P,47,'Gems');check(ok==true,'a gem receipt is queued ('..tostring(why)..')')
 check(shown(P)=='0','a queued receipt is not gems yet: the cell still shows 0')
 local r=D.Gardens[P].PendingSales[1];local seen={}
 for i=1,r.Count do D:CollectSaleCash(P,r.Id,i);same(D,P,'share '..i);seen[#seen+1]=shown(P)end
 check(gems(D,P)==47 and shown(P)=='47','the claimed receipt: 47 gems, cell 47 ('..table.concat(seen,',')..')')
 D:CollectSaleCash(P,r.Id,1);check(gems(D,P)==47 and shown(P)=='47','a repeated claim changes nothing')
 -- daily quest gems (QueueDailyGems is what the daily quest claim calls)
 check(D:QueueDailyGems(P,5)==true,'daily quest gems queued');claimAll(D,P);check(gems(D,P)==52 and shown(P)=='52','daily quest gems: 52')
 -- the Cash -> Gems converter
 D:GetOrCreateCashValue(P).Value=5*Catalog.CashPerGem
 check(D:ConvertGems(P,3)==true,'the converter takes the cash');check(shown(P)=='52','converted gems are on their way, not in the balance yet');claimAll(D,P)
 check(gems(D,P)==55 and shown(P)=='55','converter: 55 gems, cell 55')
 check(D:ConvertGems(P,9000)==false and shown(P)=='55','a refused conversion changes nothing')
 -- spending: the gem pass (Growth, 500), a Speed bundle, a mech pack
 D:GetPremium(P).Gems=2000;D:PublishPremium(P);same(D,P,'seed 2000')
 local bought,msg=D:BuyGemPerk(P,'Growth');check(bought==true,'the gem pass is bought ('..tostring(msg)..')')
 check(gems(D,P)==1500 and shown(P)=='1.5K','pass spend: 1500 gems, cell 1.5K')
 check(D:BuyGemPerk(P,'Growth')==false and gems(D,P)==1500 and shown(P)=='1.5K','owning it already: refused, nothing changes')
 local quote=D:BundleQuote(P,'SpeedSmall')
 if check(quote~=nil and quote.GemPrice<=1500,'the small Speed bundle has a gem price I can afford')then
  local done,why2=D:BuyPremiumBundle(P,'SpeedSmall')
  check(done==true and gems(D,P)==1500-quote.GemPrice,'the bundle is bought ('..tostring(why2)..')');same(D,P,'bundle spend')
  D:GetPremium(P).Gems=quote.GemPrice-1;D:PublishPremium(P)
  check(D:BuyPremiumBundle(P,'SpeedSmall')==false and gems(D,P)==quote.GemPrice-1 and shown(P)==Numbers.PlayerList(quote.GemPrice-1),'too few gems: refused, nothing changes')
 end
 -- a mech pack (the shop's gem price)
 local offer=Catalog.Offers[1]
 D:GetPremium(P).Gems=offer.GemPrice+10;D:PublishPremium(P);P:SetAttribute('PaidRandomAllowed',true)
 local pack,packWhy=D:BuyMechPack(P,offer.Count)
 if pack==true then check(gems(D,P)==10 and shown(P)==Numbers.PlayerList(10),'mech pack spend: the cell follows')
 else print('NOTE: BuyMechPack was refused in the mock ('..tostring(packWhy)..'): spend covered by the other paths');same(D,P,'after a refused mech pack')end
 -- the pass gift debit (PassGiftService:Send: state.Gems -= price, then PublishPremium) and the owner command (premium.Gems = amount, then PublishPremium)
 local state=D:GetPremium(P);state.Gems=600;D:PublishPremium(P);same(D,P,'600')
 state.Gems-=Catalog.PassGemPrices.Growth;D:PublishPremium(P);check(shown(P)=='100','a gift debit of 500 leaves 100')
 state.Gems=Catalog.MaxGems;D:PublishPremium(P);check(shown(P)==Numbers.PlayerList(Catalog.MaxGems),'the owner command can set the cap')
 -- an unchanged publish (every purchase publishes the premium state) leaves the cell alone
 D:PublishPremium(P);same(D,P,'a publish with no change')
 -- a spy on the cell: it is written only when the text changes
 local writes=0;local c=cell(P,'Gems');local con=c:GetPropertyChangedSignal('Value'):Connect(function()writes+=1 end)
 for _,n in ipairs({10,10,11,1200,1200,0})do state.Gems=n;D:PublishPremium(P);same(D,P,'balance '..n)end
 check(writes==4,'the cell is written only when the text changes ('..writes..' writes for 6 publishes, 4 different texts)')
 con:Disconnect()
end

-- 3. the display is never the truth --------------------------------------------------------------------------------------------------------------------------------------
do
 local D2=dataServer();local A=makePlayer(D2,'Bo')
 D2:GetPremium(A).Gems=1234;D2:PublishPremium(A);D2:MarkDirty(A)
 local data=D2:_buildSaveData(A)
 local top={};for k in pairs(data)do top[#top+1]=k end;table.sort(top)
 check(data.Gems==nil and data.Leaderstats==nil and data.GemsDisplay==nil and data.leaderstats==nil,'no new top-level field in the save ('..table.concat(top,',')..')')
 check(data.Premium.Gems==1234 and type(data.Premium.Gems)=='number','the saved balance is Premium.Gems, a plain number (1234)')
 -- every key named Gems anywhere in the save, and every string equal to the cell text
 local keyed={};local text=shown(A)
 local function walk(t,path,depth)
  if depth>6 then return end
  for k,v in pairs(t)do
   if k=='Gems'then keyed[#keyed+1]=path end
   if v==text and type(v)=='string'then keyed[#keyed+1]='STRING '..path..'.'..tostring(k)end
   if type(v)=='table'then walk(v,path..'.'..tostring(k),depth+1)end
  end
 end
 walk(data,'save',0)
 check(#keyed==1 and keyed[1]=='save.Premium','the only Gems key in the whole save is Premium.Gems ('..table.concat(keyed,' | ')..')')
 -- the same save, whatever the cell says
 local function dump(t)
  local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  local out={}
  for _,k in ipairs(keys)do local v=t[k];if k~='SavedAt'and k~='SeedSaveCommitId'then out[#out+1]=tostring(k)..'='..(type(v)=='table'and'{'..dump(v)..'}'or tostring(v))end end
  return table.concat(out,';')
 end
 local before=dump(data)
 cell(A,'Gems').Value='999T'
 check(dump(D2:_buildSaveData(A))==before,'rewriting the cell changes nothing that is saved')
 check(gems(D2,A)==1234,'... and not the balance')
 -- a cell written by anything else is overwritten by the next change, never read back
 D2:GetPremium(A).Gems=1235;D2:PublishPremium(A);check(shown(A)==Numbers.PlayerList(1235),'the next change rewrites the cell from the balance')
 cell(A,'Gems').Value='1B';D2:Save(A,'test',true)
 local profile;for _,v in pairs(stores[Config.GetDataStoreName(false)].Data)do if type(v)=='table'and v.Premium and v.Premium.Gems==1235 then profile=v end end
 check(profile~=nil and profile.Premium.Gems==1235,'the stored profile holds 1235 gems whatever the cell says')
 local id=A.UserId;leave(D2,A)
 -- a new session of that profile: the cell shows the saved balance
 local D3=dataServer();local A2=makePlayer(D3,'Bo',nil,id)
 check(gems(D3,A2)==1235 and shown(A2)==Numbers.PlayerList(1235),'a later session loads 1235 gems and shows '..tostring(shown(A2)))
 leave(D3,A2)
end
do
 -- stray values named Gems (an old place, a script) can never become the balance: Cash and Speed are the only stats rebuilt from leaderstats
 local D4=dataServer()
 local P1=makePlayer(D4,'Stray1',function(p)
  local l=R.new('Folder');l.Name='leaderstats';l.Parent=p
  local g=R.new('IntValue');g.Name='Gems';g.Value=777777;g.Parent=l
  local st=R.new('Folder');st.Name='ChestChaseStats';st.Parent=p
  local raw=R.new('IntValue');raw.Name='Gems';raw.Value=888888;raw.Parent=st
 end)
 check(gems(D4,P1)==0,'a stray IntValue Gems in leaderstats / ChestChaseStats does not become gems (balance '..gems(D4,P1)..')')
 check(cell(P1,'Gems')and cell(P1,'Gems'):IsA('StringValue')and cell(P1,'Gems'):GetAttribute('ChestChaseDisplayStat')==true and shown(P1)=='0','the stray cell was replaced by the display cell showing 0')
 local P2=makePlayer(D4,'Stray2',function(p)
  local l=R.new('Folder');l.Name='leaderstats';l.Parent=p
  local g=R.new('StringValue');g.Name='Gems';g.Value='999';g.Parent=l
 end)
 check(gems(D4,P2)==0 and shown(P2)=='0'and cell(P2,'Gems'):GetAttribute('ChestChaseDisplayStat')==true,'a stray untagged StringValue Gems shows the real balance, not its own text')
 D4:GetPremium(P2).Gems=5;D4:PublishPremium(P2);check(shown(P2)=='5','... and follows changes')
 -- the old Cash migration (PreparePlayer adopts a raw IntValue left in leaderstats) still works, and never takes a display cell for progress
 local Pre=R.new('Player');Pre.Name='Pre';Pre.UserId=nextId;nextId+=1;Pre.Parent=Players
 local l=R.new('Folder');l.Name='leaderstats';l.Parent=Pre
 local legacy=R.new('IntValue');legacy.Name='Cash';legacy.Value=4321;legacy.Parent=l
 local D5=dataServer();D5:PreparePlayer(Pre)
 check(Pre.ChestChaseStats.Cash==legacy and legacy.Value==4321,'a legacy IntValue Cash in leaderstats is still adopted as the raw cash')
 check(cell(Pre,'Cash'):IsA('StringValue')and cell(Pre,'Cash').Value==Numbers.PlayerList(4321)and cell(Pre,'Cash').Priority.Value==1,'... and the Cash cell is rebuilt as a display cell (Priority 1)')
 check(Pre.leaderstats.Gems.Value=='0'and Pre.leaderstats.Gems.Priority.Value==0,'... with the Gems cell next to it')
 D5:_disconnectStatLinks(Pre)
 leave(D4,P1);leave(D4,P2)
end

-- 4. clean-up ------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local D6=dataServer();local A=makePlayer(D6,'Cy')
 local signal=A:GetAttributeChangedSignal('Gems')
 check(liveConnections(signal)==1,'one live Gems attribute connection after joining ('..liveConnections(signal)..')')
 local display=D6:GetOrCreateGemsDisplay(A);D6:GetOrCreateGemsDisplay(A);D6:PreparePlayer(A)
 check(display==cell(A,'Gems')and liveConnections(signal)==1,'asking again (the getter, PreparePlayer again) stacks no second link ('..liveConnections(signal)..')')
 check(D6.StatLinks[A]~=nil and D6.StatLinks[A].Values.Gems~=nil and D6.StatLinks[A].Values.Gems.Raw==nil,'the link is in StatLinks with the other stats, with no raw object')
 D6:GetPremium(A).Gems=21;D6:PublishPremium(A);check(shown(A)=='21','the live link follows')
 local held=cell(A,'Gems')
 leave(D6,A)
 check(D6.StatLinks[A]==nil,'StatLinks has no entry for a player who left')
 check(liveConnections(signal)==0,'no live Gems connection after leaving ('..liveConnections(signal)..')')
 A:SetAttribute('Gems',99999);check(held.Value=='21','a late attribute change after leaving writes nothing to the cell')
 -- a player who is destroyed without a clean finalize (Destroying) drops the links too
 local B=makePlayer(D6,'Di');local signalB=B:GetAttributeChangedSignal('Gems')
 check(liveConnections(signalB)==1,'second player: one connection')
 B.Destroying:Fire()
 check(D6.StatLinks[B]==nil and liveConnections(signalB)==0,'Player.Destroying disconnects the Gems link as well')
 -- a destroyed cell is not written to, and the getter makes a fresh one (same priority)
 local C=makePlayer(D6,'Ed');local old=cell(C,'Gems');old:Destroy()
 C:SetAttribute('Gems',5);check(old.Value=='0','a destroyed cell is left alone')
 local fresh=D6:GetOrCreateGemsDisplay(C)
 check(fresh~=old and fresh.Parent==C.leaderstats and fresh.Priority.Value==0 and fresh:GetAttribute('ChestChaseDisplayStat')==true and fresh.Value=='5','the getter rebuilds it, tagged, Priority 0, showing the balance')
 leave(D6,C)
end

print(string.format('gems column: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
