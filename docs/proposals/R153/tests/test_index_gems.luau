--!nocheck
-- R153 (owner: "index gem gain is halved"; "7 day login reward gem gain stays the same"): the Index's Gems on the Roblox mock with the real PlayerDataService (PremiumProgress):
-- halfway 10 -> 5, completion 20 -> 10 (Mech set and Verity 100 -> 50); whole gems, halves round up, at least 1; a pending pre-R81 backpay pays (and shows) half; a reward already claimed
-- stays claimed and pays nothing again; the Index's cash and everything else in BalanceValues81 are the R152 values (compared with the R152 file, BalanceValues81Base, that run.sh adds to the bundle).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local sentRequests={};local httpOk=true
function Http.GetSecret(_,name)return {Secret=name}end
function Http.JSONEncode(_,t)return t end -- (the test reads the table back)
function Http.RequestAsync(_,req)sentRequests[#sentRequests+1]=req;return {Success=httpOk,StatusCode=httpOk and 200 or 500,Body=httpOk and'{}'or'boom'}end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
-- A shared fake MemoryStore (every SocialService instance = another server).
local MS=W.service('MemoryStoreService');local maps={};local msCalls=0
function MS.GetSortedMap(_,name)
 if maps[name]then return maps[name]end
 local m={Items={}}
 function m.SetAsync(self,key,value,ttl,sortKey)msCalls+=1;self.Items[key]={Value=value,Sort=sortKey,Expires=R.clock+ttl};return true end
 function m.GetAsync(self,key)msCalls+=1;local it=self.Items[key];return it and it.Expires>R.clock and it.Value or nil end
 function m.RemoveAsync(self,key)msCalls+=1;self.Items[key]=nil end
 function m.UpdateAsync(self,key,fn,ttl)msCalls+=1;local it=self.Items[key];local v,s=fn(it and it.Value,it and it.Sort);if v==nil then return nil end;self.Items[key]={Value=v,Sort=s,Expires=R.clock+ttl};return v end
 function m.GetRangeAsync(self,dir,count,lower,upper)msCalls+=1
  local out={};for k,it in pairs(self.Items)do if it.Expires>R.clock and(not upper or upper.sortKey==nil or(it.Sort or 0)<upper.sortKey)then out[#out+1]={key=k,value=it.Value,sortKey=it.Sort}end end
  table.sort(out,function(a,b)return(a.sortKey or 0)<(b.sortKey or 0)end);while #out>count do table.remove(out)end;return out
 end
 maps[name]=m;return m
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local D=W.module('DailyRewards');local Rules=W.module('SeedPackRules')
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local shown={}
local Notes={Show=function(_,p,text)shown[#shown+1]={P=p,Text=text}end}
local Data=server('PlayerDataService').new(Config,Map,Notes)
R.clock=20000*86400+3600 -- a Tuesday-ish UTC day, 01:00
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local function pendingGems(p)local t={};for _,r in ipairs(Data.Gardens[p].PendingSales or{})do if r.Currency=='Gems'then t[#t+1]=r.Amount end end;return t end
local function clearReceipts(p)Data.Gardens[p].PendingSales={}end
local T=W.module('BalanceValues81');local Verity=W.module('VerityCatalog');local Catalog=W.module('MechCatalog')
-- 1. The numbers --------------------------------------------------------------------------------------------------------------------------------------------
check(T.HalfwayGems==5,'halfway Gems: 10 -> 5')
local want={[1]=10,[2]=10,[3]=10,[4]=10,[5]=10,[6]=10,[7]=10,[8]=50,[9]=50}
local same=true;for k,v in pairs(want)do if T.CompletionGems[k]~=v then same=false end end
check(same,'completion Gems: categories 1-7 20 -> 10, Mech set (8) 100 -> 50, Verity (9) 100 -> 50')
check(Verity.HalfwayGems==5 and Verity.CompletionGems==50 and T.CompletionGems[Verity.Stage]==Verity.CompletionGems,'the Verity catalog says the same numbers (5 / 50), BalanceValues81 reads its completion Gems from it')
local cases={{0,0},{-3,0},{1,1},{2,1},{3,2},{4,2},{5,3},{9,5},{10,5},{15,8},{20,10},{25,13},{30,15},{35,18},{45,23},{50,25},{100,50}}
local halves=true;for _,c in ipairs(cases)do if T.HalveGems(c[1])~=c[2]then halves=false;print('  HalveGems('..c[1]..') = '..tostring(T.HalveGems(c[1]))..', want '..c[2])end end
check(halves and T.HalveGems('x')==0 and T.HalveGems(nil)==0,'whole gems, halves round up, at least 1 (5 -> 3, 15 -> 8, 1 -> 1); nothing -> 0')
-- the old numbers are kept where the migration needs them: the pre-R81 table (backpay) is untouched
local legacy={[1]=5,[6]=10,[2]=15,[3]=20,[4]=25,[5]=30,[7]=40,[8]=50};local legacySame=true;for k,v in pairs(legacy)do if T.LegacyCompletionGems[k]~=v then legacySame=false end end
check(legacySame,'T.LegacyCompletionGems (the pre-R81 table the backpay is figured from) is untouched')
-- 2. The server pays the halved Gems, once -------------------------------------------------------------------------------------------------------------------
local A=makePlayer(601,'Ada')
Data.IndexMilestone=function()return true end;Data.BiomeComplete=function()return true end -- (the milestone rules are not what is tested here: the amounts are)
local premium=Data:GetPremium(A);local bank=premium.Gems
local expectHalf,expectFull=5,{[1]=10,[2]=10,[3]=10,[4]=10,[5]=10,[6]=10,[7]=10,[8]=50,[9]=50}
local total=0;local allOk=true
for stage=1,9 do
 clearReceipts(A)
 local okH,whyH=Data:ClaimIndexBiomeHalf(A,stage);local g1=pendingGems(A)
 local okC,whyC=Data:ClaimIndexBiome(A,stage);local g2=pendingGems(A)
 local fine=okH and okC and #g1==1 and g1[1]==expectHalf and #g2==2 and g2[2]==expectFull[stage]
 if not fine then allOk=false;print('  category '..stage..': '..tostring(okH)..' '..tostring(whyH)..' / '..tostring(okC)..' '..tostring(whyC)..' gems '..table.concat(g2,','))end
 -- collected by the R152 money effect (CollectSaleCash): exactly these Gems arrive
 for _,receipt in ipairs(table.clone(Data.Gardens[A].PendingSales))do for i=1,receipt.Count do Data:CollectSaleCash(A,receipt.Id,i)end end
 total+=expectHalf+expectFull[stage]
 -- once: a second claim of either pays nothing
 local again1,again2=Data:ClaimIndexBiomeHalf(A,stage),Data:ClaimIndexBiome(A,stage)
 if again1 or again2 or #pendingGems(A)~=0 then allOk=false;print('  category '..stage..': a second claim paid')end
end
check(allOk,'every category (1-9): halfway 5, completion 10 (Mech set and Verity 50), once each')
check(premium.Gems==bank+total and total==9*5+7*10+2*50,'collected through CollectSaleCash: '..total..' Gems in all (it was 9 x 10 + 7 x 20 + 2 x 100 = 430)')
check(A:GetAttribute('IndexBiomeReward9')==true and A:GetAttribute('IndexBiomeHalfReward9')==true and Data:GetPremium(A).Biomes['9']==true and Data:GetPremium(A).BiomeHalfRewards['9']==true,'the claimed flags follow as before')
-- 3. A pending backpay (a save from before R81 that was never claimed) pays half, shown and claimed alike ---------------------------------------------------
local B=makePlayer(602,'Bo')
local pb=Data:GetPremium(B);pb.BiomeBackpay81={};pb.Biomes={}
local pending={[1]=5,[2]=10,[3]=15,[4]=20,[5]=25,[6]=30,[7]=35,[8]=45};local shown={[1]=3,[2]=5,[3]=8,[4]=10,[5]=13,[6]=15,[7]=18,[8]=23}
for stage,v in pairs(pending)do pb.BiomeBackpay81[tostring(stage)]=v;pb.Biomes[tostring(stage)]=true end
Data:PublishPremium(B)
local attrOk=true;for stage,v in pairs(shown)do if B:GetAttribute('IndexBiomeBackpay'..stage)~=v then attrOk=false;print('  IndexBiomeBackpay'..stage..' = '..tostring(B:GetAttribute('IndexBiomeBackpay'..stage))..', want '..v)end end
check(attrOk and B:GetAttribute('IndexBiomeBackpay9')==0,'the Index shows the halved backpay (5 -> 3, 10 -> 5, 15 -> 8, 20 -> 10, 25 -> 13, 30 -> 15, 35 -> 18, 45 -> 23); none where none is owed')
local saved=Data:GetPremium(B).BiomeBackpay81;local keptOld=true;for stage,v in pairs(pending)do if saved[tostring(stage)]~=v then keptOld=false end end
check(keptOld,'(the saved amounts stay what they were until claimed: only what is shown and paid is halved)')
local paidOk=true
for stage=1,8 do
 clearReceipts(B);local ok=Data:ClaimIndexBiome(B,stage);local g=pendingGems(B)
 if not(ok and #g==1 and g[1]==shown[stage])then paidOk=false;print('  backpay '..stage..': '..tostring(ok)..' gems '..table.concat(g,','))end
 if(Data:GetPremium(B).BiomeBackpay81[tostring(stage)]or 0)~=0 or B:GetAttribute('IndexBiomeBackpay'..stage)~=0 or not B:GetAttribute('IndexBiomeReward'..stage)then paidOk=false;print('  backpay '..stage..' not cleared')end
 if Data:ClaimIndexBiome(B,stage)then paidOk=false end
end
check(paidOk,'each backpay claim pays exactly the halved amount shown, once, then clears')
-- the migration of an old save: Decode still figures the old amounts (nothing is lost), the claim halves them
local P=server('PremiumProgress')
local oldSave={Version=2,Gems=0,Entitlements={},Biomes={['2']=true,['5']=true},Receipts={},Plants={},SeedRewards={},BiomeHalfRewards={}} -- (no BalanceVersion81: a save from before R81)
local dec=P.Decode(oldSave)
check(dec and dec.BiomeBackpay81['2']==10 and dec.BiomeBackpay81['5']==25 and dec.BalanceVersion81==81,'a pre-R81 save still decodes to the old backpay (Desert 10, Crystal 25) ...')
local C=makePlayer(603,'Cy');Data.Premium[C]=dec;Data:PublishPremium(C)
check(C:GetAttribute('IndexBiomeBackpay2')==5 and C:GetAttribute('IndexBiomeBackpay5')==13,'... and shows them halved (5 and 13)')
-- 4. A reward already claimed stays claimed, nothing is paid again ----------------------------------------------------------------------------------------------
local E=makePlayer(604,'Eve');local pe=Data:GetPremium(E);pe.Biomes['3']=true;pe.BiomeHalfRewards['3']=true;Data:PublishPremium(E)
local e1,e1why=Data:ClaimIndexBiomeHalf(E,3);local e2,e2why=Data:ClaimIndexBiome(E,3)
check(not e1 and e1why=='U ALREADY CLAIMED THIS!'and not e2 and e2why=='U ALREADY CLAIMED THIS!'and #pendingGems(E)==0 and E:GetAttribute('IndexBiomeReward3')==true and E:GetAttribute('IndexBiomeHalfReward3')==true,'a player who claimed before the change: both stay claimed, nothing paid again')
-- 5. Nothing else in the Index changed ----------------------------------------------------------------------------------------------------------------------------
local D=W.module('DailyRewards')
check(Data:SeedCollectReward(E,'SunflowerSeed')==T.IndexFirst.SunflowerSeed,'seed cash: the first-find reward is still T.IndexFirst (cash is not gems)')
check(Catalog.MaxGems==1000000 and Catalog.BiomeGemReward==5,'(the gem cap and MechCatalog are untouched)')
local base;do local okB,mB=pcall(W.module,'BalanceValues81Base');if okB then base=mB end end
if base then
 local diffs={}
 local function walk(a,b,path)
  if type(a)=='function'or type(b)=='function'then return end
  if type(a)~='table'or type(b)~='table'then if a~=b then diffs[#diffs+1]=path end;return end
  local seen={};for k,v in pairs(a)do seen[k]=true;walk(v,b[k],path..'.'..tostring(k))end
  for k,v in pairs(b)do if not seen[k]then walk(nil,v,path..'.'..tostring(k))end end
 end
 for _,k in ipairs({'IndexFirst','IndexRepeat','LegacyCompletionGems','HalfwayGems','CompletionGems'})do walk(base[k],T[k],'T.'..k)end -- (the Index's own numbers; other balance tables are other rounds' business)
 table.sort(diffs)
 local expected={'T.CompletionGems.1','T.CompletionGems.2','T.CompletionGems.3','T.CompletionGems.4','T.CompletionGems.5','T.CompletionGems.6','T.CompletionGems.7','T.CompletionGems.8','T.HalfwayGems'}
 table.sort(expected)
 local gotSet,wantSet={},{};for _,x in ipairs(diffs)do gotSet[x]=true end;for _,x in ipairs(expected)do wantSet[x]=true end
 local extra,missing={},{};for x in pairs(gotSet)do if not wantSet[x]then extra[#extra+1]=x end end;for x in pairs(wantSet)do if not gotSet[x]then missing[#missing+1]=x end end
 check(#extra==0 and #missing==0,'the Index numbers of BalanceValues81 against the R152 file (first / repeat cash, the legacy table): only the halfway and the completion Gems differ ('..table.concat(diffs,', ')..(#extra>0 and' | UNEXPECTED: '..table.concat(extra,', ')or'')..')')
 check(base.HalfwayGems==10 and base.CompletionGems[1]==20 and base.CompletionGems[8]==100,'(the R152 numbers it is compared with: 10 / 20 / 100)')
else print('(no R152 BalanceValues81 to compare with: skipped)')end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
