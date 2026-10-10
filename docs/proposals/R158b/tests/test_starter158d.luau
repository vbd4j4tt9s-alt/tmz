--!nocheck
-- R158d new-player gift on the REAL player data (the R123 world, like the R152 giveaway suite): the real PlayerDataService (AddChest, Save / Load, OpenSeedPack, Premium), TreadmillBonusService,
-- FruitGiftService, ChestService:_createPackTool, SeedPackRules / VerityPackOdds / LimitedEvent, with the real StarterVerity158d on top (recording stand-ins for the notice feed and the hotbar sync).
-- Checks (every number the owner asked for is pinned):
--  A  a brand-new profile gets exactly ONE Verity Pack with Floor = Mythic (GiftLocked, a real pack, no TestGrant), the flag 'Given', 2 ready bonus rolls and ONE notice with the owner's words,
--     R158e (owner: "the verity gift is given instantly to all new players"): at the FIRST SPAWN, while the tutorial runs (a join before the character: owed, given on CharacterAdded); the notice
--     a few seconds later (after the title screen);
--  A2 R158e: the gift does not skip the tutorial's steal step (only a pack stolen on the track, banked, ticks it); after it, opening any pack (the gift too) counts;
--  B  a second join gives nothing (no pack, no notice, no third / fourth roll); the unused starter rolls come back after a rejoin and go down as they are used;
--  C  an old profile (saved before the gift) gets nothing, at any spawn;
--  D  an interrupted grant: lost before any save (given once again), owed and saved but not given (given at the next spawn), a full Bag (retried), a profile that cannot save;
--  E  the Verity event ended: no pack, no rolls, no notice and NO flag for a new profile; an owed profile is given nothing either ("only while the event is active");
--  F  the floored open: 2,000 real opens never below Mythic, the tier mix = the Verity pack's OWN odds renormalised to Mythic and above (luck, clover and the pity's lucky roll included),
--     an ordinary Verity Pack still rolls its normal odds (and still gives Legendary), a Forest pack with a forged Floor rolls normally;
--  G  the floor can't be set from outside: only a Verity pack keeps it, only the word 'Mythic', Seed rows never, test packs never;
--  H  the pack can't be gifted (FruitGiftService, with a plain message); the seed opened from it neither; an ordinary Verity Pack still can;
--  I  the pack's tool has its own name, so it never shares a hotbar slot / Bag stack with ordinary Verity Packs;
--  J  /test starterverity (status; reset is Studio only).
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
local function dsCopy(v,path)
 path=path or'value';local t=type(v)
 if t=='string'or t=='number'or t=='boolean'or t=='nil'then return v end
 if t~='table'or getmetatable(v)~=nil or v.__type then error('not DataStore-safe at '..path..': '..R.typeof(v),0)end
 local o={};for k,x in pairs(v)do o[k]=dsCopy(x,path..'.'..tostring(k))end;return o
end
local stores={};local DS=W.service('DataStoreService')
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Name=name,Data={},
  UpdateAsync=function(self,key,fn)local v=fn(dsCopy(self.Data[key]),nil);if v~=nil then self.Data[key]=dsCopy(v)end;return dsCopy(self.Data[key])end,
  GetAsync=function(self,key)return dsCopy(self.Data[key])end,SetAsync=function(self,key,v)self.Data[key]=dsCopy(v)end}
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
 return o end end
local warns={};W.env.warn=function(...)warns[#warns+1]=table.concat({...},' ')end
local Config=server('Config');local Packs=W.module('SeedPackRules');local Rules=W.module('StarterVerityRules158d');local Limited=W.module('LimitedEvent');local VC=W.module('VerityCatalog')
local Stacks=W.module('InventoryStacks155');local PDS=server('PlayerDataService');local TreadSvc=server('TreadmillBonusService');local StarterSvc=server('StarterVerity158d')
local Map={GetStageAccent=function(_,s)return R.Color3.new(.5,.5,s/10)end}
local told={};local Notes={Show=function(_,p,text,color,secs)told[#told+1]={P=p,Text=text,Secs=secs}end}
local function noticesFor(p)local n=0;for _,t in ipairs(told)do if t.P==p then n+=1 end end;return n end
local function lastText(p)for i=#told,1,-1 do if told[i].P==p then return told[i].Text end end end
local synced=0;local Chests={SyncTools=function()synced+=1 end,Openings={}}
R.clock=20727*86400+3600*5
local EndsAt=Limited.EndsAt
local clockNow={t=EndsAt-10*86400} -- ten days before the Verity event ends
local queue={};local delays={}
local function flush(passes)for _=1,passes or 30 do if #queue==0 then return end;local q=queue;queue={};for _,fn in ipairs(q)do fn()end end end
local function newServer(studio)
 local D=PDS.new(Config,Map,Notes)
 local T=TreadSvc.new(Config,D,{TrainingSessions={}},Chests,Notes)
 local S=StarterSvc.new(Config,D,Chests,Notes,T,{Time=function()return clockNow.t end,Delay=function(sec,fn)delays[#delays+1]=sec;queue[#queue+1]=fn end,Studio=studio==true})
 return{D=D,T=T,S=S}
end
-- join: the real order of the main script (load, then the bonus service's Setup, then the gift's Setup). starter=false: an older server without the gift (the profile is saved without any trace of it).
-- R158e: the character is spawned before the gift's Setup (the usual case: the profile loads after the first spawn), unless noChar: then spawnIn() spawns it later (CharacterAdded).
local function spawnIn(p)
 local m=R.new('Model');m.Name=p.Name;local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(0,5,-380);root.Parent=m;m.PrimaryPart=root
 local hum=R.new('Humanoid');hum.Health=100;function hum.UnequipTools()end;hum.Parent=m;m.Parent=W.workspace;p.Character=m
 p.CharacterAdded:Fire(m)
end
local function join(sv,id,name,starter,noChar)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p;p.CharacterAdded=R.signal()
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 sv.D:PreparePlayer(p);assert(sv.D:Load(p),'load '..name)
 if not noChar then spawnIn(p)end
 sv.T:Setup(p)
 if starter~=false then sv.S:Setup(p)end
 return p
end
local function leave(sv,p)sv.D:FinalizePlayer(p,'PlayerRemoving');present[p.UserId]=nil;p.Parent=nil end
local function crash(p)present[p.UserId]=nil;p.Parent=nil end -- (the server died: no save)
local function finishTutorial(sv,p)assert(sv.D:TutorialAction(p,"Skip"),"skip");flush(2)end -- (two passes: a gift queues its notice, a refusal queues its retry)
local function respawn(p)spawnIn(p);flush(3)end -- (R158e: CharacterAdded -> a moment later the try -> its notice / retry)
local function gifts(sv,p)local out={};for _,r in ipairs(sv.D:GetChestRecords(p))do if Rules.PackFloor(r)then out[#out+1]=r end end;return out end
local function flag(sv,p)return sv.D:GetPremium(p)[Rules.Flag]end
local function rolls(sv,p)return sv.D:GetPremium(p)[Rules.RollsField]end

-- 0. The rules -----------------------------------------------------------------------------------------------------------------------------------------------------
check(Config.ProfileVersion==22,'ProfileVersion is still 22')
check(Rules.Notice=="Thanks for playing! Here's a gift",'the notice is the owner\'s words, exactly')
check(not Rules.Notice:lower():find('rigged',1,true),'and never says "rigged"')
check(Rules.Floor=='Mythic'and Rules.Rolls==2,'the floor is Mythic and the gift is 2 rolls')
do
 local pack=Rules.Pack(Packs)
 check(pack.Stage==7 and pack.BagVariant==VC.Variant and pack.PackSize==1 and pack.PackMutation=='None'and pack.Weather=='None'and pack.OddsVersion==Packs.OddsVersion,'the gift is a plain current Verity Pack (stage 7, 1x, no coat, no weather)')
 check(pack.GiftLocked==true and pack.Floor=='Mythic','it is GiftLocked and has the floor')
 check(Rules.CleanFloor('Mythic')=='Mythic'and Rules.CleanFloor('Secret')==nil and Rules.CleanFloor('mythic')==nil and Rules.CleanFloor(true)==nil and Rules.CleanFloor(1)==nil and Rules.CleanFloor(nil)==nil,'only the word Mythic is a floor')
 check(Rules.CleanRolls(2)==2 and Rules.CleanRolls(5)==2 and Rules.CleanRolls(-1)==0 and Rules.CleanRolls('2')==0 and Rules.CleanRolls(0/0)==0 and Rules.CleanRolls(1.9)==1,'the starter rolls are a whole number from 0 to 2')
 check(Rules.CleanState('Owed')=='Owed'and Rules.CleanState('Given')=='Given'and Rules.CleanState(true)==nil and Rules.CleanState('x')==nil,'the saved state is exactly Owed / Given')
end

-- A. A brand-new profile -------------------------------------------------------------------------------------------------------------------------------------------
local s1=newServer();local A=join(s1,3001,'Ava',nil,true)
do
 check(s1.D.FreshProfile[A]==true,'A: PlayerDataService saw a brand-new profile (nothing saved before the join)')
 check(flag(s1,A)==Rules.Owed and #gifts(s1,A)==0 and #s1.D:GetChestRecords(A)==0,'A: loaded before the first spawn: OWED, no pack yet')
 check(noticesFor(A)==0 and s1.T:GetReady(A)==0,'A: no notice and no bonus roll yet')
 local mask=s1.D:GetPremium(A).Tutorial.Mask;check(A:GetAttribute('TutorialStep')==1 and A:GetAttribute('TutorialDone')==false,'A: the tutorial is at step 1')
 -- R158e (owner: "the verity gift is given instantly to all new players"): the first spawn gives it, at once, while the tutorial runs
 local d0=#delays;respawn(A)
 local g=gifts(s1,A);local rec=g[1]
 check(#g==1 and #s1.D:GetChestRecords(A)==1,'A: the FIRST SPAWN gives exactly ONE gift pack, at once')
 check(A:GetAttribute('TutorialDone')==false and A:GetAttribute('TutorialStep')==1 and s1.D:GetPremium(A).Tutorial.Mask==mask,'A: ... while the tutorial runs, and the tutorial is untouched (step 1, same mask)')
 local noticeDelay=false;for i=d0+1,#delays do if delays[i]==Rules.NoticeDelay then noticeDelay=true end end
 check(noticeDelay and Rules.NoticeDelay>=3,'A: the notice comes '..Rules.NoticeDelay..' s after the gift (after the title screen: a new player\'s closes ~1.2 s after it shows)')
 check(rec.Kind=='Pack'and rec.Stage==7 and rec.BagVariant==VC.Variant and rec.Floor=='Mythic','A: a Verity Pack (stage 7) with Floor = Mythic')
 check(rec.GiftLocked==true and rec.TestGrant==nil and rec.PackShape==nil and rec.PackSize==1 and rec.PackMutation=='None','A: GiftLocked, a REAL pack (not TestGrant: it announces when opened), 1x, no coat, no shape')
 check(rec.OddsVersion==Packs.OddsVersion and type(rec.Id)=='string'and rec.Id:match('^3001_%d+$')~=nil,'A: the current odds version, a normal inventory id')
 check(flag(s1,A)==Rules.Given and rolls(s1,A)==2,'A: Premium.StarterVerity158d = Given and Premium.StarterRolls158d = 2')
 check(s1.T:GetReady(A)==2 and A:GetAttribute('TreadmillBonusReady')==2,'A: 2 READY bonus rolls, and the BONUS ROLL button\'s attribute says 2')
 check(noticesFor(A)==1 and lastText(A)==Rules.Notice and told[#told].Secs==5,'A: ONE notice, the owner\'s words, shown 5 s')
 check(A:GetAttribute('SeedInventoryCount')==1,'A: the inventory count the HUD shows is 1')
 local before=#s1.D:GetChestRecords(A)
 local again,why=s1.S:Grant(A);check(again==nil and why=='given'and #s1.D:GetChestRecords(A)==before,'A: a second Grant gives nothing (given)')
 flush();s1.S:Setup(A);flush();check(#s1.D:GetChestRecords(A)==1 and noticesFor(A)==1 and s1.T:GetReady(A)==2,'A: Setup / retries again: still one pack, one notice, 2 rolls')
 -- the rolls are ordinary: a roll gives an ordinary pack (no floor, no lock)
 local result=s1.T:Roll(A)
 check(result.Ok==true and result.Ready==1,'A: a starter bonus roll works like any ready roll (1 left)')
 local rolled=s1.D:GetChestRecords(A)[2]
 check(rolled and rolled.Floor==nil and rolled.GiftLocked==nil and Rules.PackFloor(rolled)==nil,'A: the pack a bonus roll gives is ordinary (no floor, no lock)')
 check(rolls(s1,A)==1,'A: the saved starter count went down with the roll (1)')
 check(A:GetAttribute('TutorialStep')==1 and s1.D:GetPremium(A).Tutorial.Mask==mask,'A: the bonus roll\'s pack does not tick the tutorial\'s steal step either')
 respawn(A);check(#gifts(s1,A)==1 and noticesFor(A)==1,'A: a respawn gives nothing more')
end

-- A2. R158e: the gift does not skip the tutorial's steal step --------------------------------------------------------------------------------------------------------------
do
 local sv=newServer();local K=join(sv,3090,'Kid');flush(2)
 local gift=gifts(sv,K)[1]
 check(gift~=nil and K:GetAttribute('TutorialStep')==1,'A2: joined and spawned: the gift is in the Bag, the tutorial still asks for a steal (step 1)')
 local stolen=sv.D:AddChest(K,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{Luck=true,Banked=true})
 check(stolen and K:GetAttribute('TutorialStep')==4,'A2: a pack stolen on the track (banked) ticks the steal step')
 sv.D:OpenSeedPack(K,gift.Id,function()return .5 end);check(K:GetAttribute('TutorialStep')==6,'A2: opening ANY pack (the gift too) counts for the open step (owner)')
end

-- B. A second join gives nothing; the unused starter rolls come back --------------------------------------------------------------------------------------------------------
local s2=newServer()
do
 leave(s1,A);local told0=#told
 local A2=join(s2,3001,'Ava')
 check(s2.D.FreshProfile[A2]==false and flag(s2,A2)==Rules.Given,'B: the saved profile is not new; the flag is Given')
 flush();check(#gifts(s2,A2)==1 and #told==told0,'B: second join: still exactly one gift pack (it was SAVED with Floor = Mythic), no notice')
 local rec=gifts(s2,A2)[1];check(rec.Floor=='Mythic'and rec.GiftLocked==true and rec.BagVariant==VC.Variant,'B: the saved record kept Floor, GiftLocked and the variant')
 check(s2.T:GetReady(A2)==1 and A2:GetAttribute('TreadmillBonusReady')==1,'B: the 1 unused starter roll is ready again (not 2, not 3)')
 finishTutorial(s2,A2);respawn(A2);check(#gifts(s2,A2)==1 and #told==told0,'B: a respawn or finishing the tutorial gives nothing')
 local result=s2.T:Roll(A2);check(result.Ok==true and rolls(s2,A2)==nil,'B: the last starter roll is spent: the saved count is gone')
 leave(s2,A2)
 local s3=newServer();local A3=join(s3,3001,'Ava');check(s3.T:GetReady(A3)==0 and #gifts(s3,A3)==1,'B: third join: no rolls left, still one pack')
 -- a roll earned on the treadmill is not a starter roll: it does not touch the saved count
 s3.D:GetPremium(A3)[Rules.RollsField]=nil;s3.T:GrantReady(A3,1)
 local rr=s3.T:Roll(A3);check(rr.Ok==true and rolls(s3,A3)==nil,'B: a normal ready roll leaves the starter count alone')
 leave(s3,A3)
end

-- C. An old profile; an unfinished tutorial -----------------------------------------------------------------------------------------------------------------------------
do
 local sv=newServer()
 local old=join(sv,3010,'Old',false) -- (an older server: no gift code; the profile is saved)
 finishTutorial(sv,old);leave(sv,old)
 local sv2=newServer();local old2=join(sv2,3010,'Old')
 check(sv2.D.FreshProfile[old2]==false and flag(sv2,old2)==nil,'C: an existing profile is not new and has NO flag')
 finishTutorial(sv2,old2);respawn(old2)
 check(flag(sv2,old2)==nil and #sv2.D:GetChestRecords(old2)==0 and rolls(sv2,old2)==nil and sv2.T:GetReady(old2)==0 and noticesFor(old2)==0,'C: nothing for an old player: no flag, no pack, no rolls, no notice')
 check(sv2.S:Grant(old2)==nil,'C: Grant refuses (not owed)')
 local _,why=sv2.S:Grant(old2);check(why=='notowed','C: the reason is "not owed"')
 leave(sv2,old2)
 -- a saved profile with no Premium flag field at all reads as "not set"
 local P=server('PremiumProgress');local decoded=P.Decode({Version=2,Gems=0,Entitlements={},Biomes={},Receipts={},Plants={},SeedRewards={},BalanceVersion81=81,IndexRewardVersion=104,StarterVerity158d='Given',StarterRolls158d=2})
 check(decoded and decoded.StarterVerity158d=='Given'and decoded.StarterRolls158d==2,'C: PremiumProgress.Decode (every server) keeps the two optional fields it does not know')
end

-- D. Interrupted grants ---------------------------------------------------------------------------------------------------------------------------------------------------
do
 -- D1: the grant happened but the server died before any save: the profile is still brand-new on the next join: given once
 local sv=newServer();local p=join(sv,3020,'Lost');flush(2)
 check(#gifts(sv,p)==1 and noticesFor(p)==1,'D1: granted in the first session (never saved)')
 crash(p)
 local sv2=newServer();local p2=join(sv2,3020,'Lost',nil,true)
 check(#sv2.D:GetChestRecords(p2)==0 and flag(sv2,p2)==Rules.Owed,'D1: the new session has no pack and is owed again')
 respawn(p2);check(#gifts(sv2,p2)==1 and flag(sv2,p2)==Rules.Given and noticesFor(p2)==1,'D1: the next join gives it at the spawn, once, with one notice')
 flush();sv2.S:Grant(p2);check(#gifts(sv2,p2)==1,'D1: never twice')
 leave(sv2,p2)
 -- D2: owed and SAVED (a player who left before the first spawn): not new on the next join, still owed, given at the spawn
 local sa=newServer();local q=join(sa,3021,'Left',nil,true);leave(sa,q)
 local sb=newServer();local q2=join(sb,3021,'Left',nil,true)
 check(sb.D.FreshProfile[q2]==false and flag(sb,q2)==Rules.Owed and #sb.D:GetChestRecords(q2)==0,'D2: the saved profile is still owed (not new any more, but the saved state says Owed)')
 respawn(q2);check(#gifts(sb,q2)==1 and flag(sb,q2)==Rules.Given and sb.T:GetReady(q2)==2,'D2: given at the spawn, with its 2 rolls')
 leave(sb,q2)
 local sc=newServer();local q3=join(sc,3021,'Left');flush();check(#gifts(sc,q3)==1 and sc.T:GetReady(q3)==2 and noticesFor(q3)==0,'D2: and never again (one pack; the 2 unused rolls are back, not 4; no second notice)')
 leave(sc,q3)
 -- D3: a full Bag: refused without a trace, tried again
 local sd=newServer();local f=join(sd,3022,'Full',nil,true)
 for i=1,sd.D:HeldItemCap()do assert(sd.D:AddChest(f,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion}),'fill '..i)end
 respawn(f)
 check(#gifts(sd,f)==0 and flag(sd,f)==Rules.Owed and noticesFor(f)==0 and sd.T:GetReady(f)==0,'D3: a full Bag (200): no pack, no flag change, no notice, no rolls')
 table.remove(sd.D:GetChestRecords(f));sd.D:_notifySeedInventory(f)
 flush();check(#gifts(sd,f)==1 and flag(sd,f)==Rules.Given and #sd.D:GetChestRecords(f)==sd.D:HeldItemCap(),'D3: a slot is free: the retry gives it (200 items exactly), once')
 check(noticesFor(f)==1,'D3: one notice')
 -- D4: a profile that cannot save
 local se=newServer();local n=join(se,3023,'NoSave',nil,true);se.D.CanSave[n]=false
 respawn(n);check(#gifts(se,n)==0 and flag(se,n)==Rules.Owed,'D4: a profile that cannot save is given nothing (a pack that cannot be saved would be given again)')
 se.D.CanSave[n]=true;flush();check(#gifts(se,n)==1,'D4: when it can save, it is given')
end

-- E. The Verity event ended ----------------------------------------------------------------------------------------------------------------------------------------------
do
 check(Limited.Active(clockNow.t)==true,'E: (the event is running)')
 -- an owed profile saved while the event ran
 local sv0=newServer();local w=join(sv0,3030,'Waits',nil,true);leave(sv0,w)
 clockNow.t=EndsAt+5
 check(Limited.Active(clockNow.t)==false,'E: the event has ended')
 local sv=newServer();local n=join(sv,3031,'LateNew')
 check(sv.D.FreshProfile[n]==true and flag(sv,n)==nil,'E: a brand-new profile after the end: the flag is NOT set')
 respawn(n)
 check(#sv.D:GetChestRecords(n)==0 and flag(sv,n)==nil and rolls(sv,n)==nil and sv.T:GetReady(n)==0 and noticesFor(n)==0,'E: no pack, no rolls, no notice, no flag')
 local _,why=sv.S:Grant(n);check(why=='notowed','E: nothing is owed')
 leave(sv,n)
 local sv2=newServer();local n2=join(sv2,3031,'LateNew');respawn(n2);check(flag(sv2,n2)==nil and #sv2.D:GetChestRecords(n2)==0,'E: and on every later join')
 -- the profile that was owed before the end: the rule is "only while the event is active"
 local w2=join(sv2,3030,'Waits')
 check(flag(sv2,w2)==Rules.Owed,'E: (the saved profile still says Owed)')
 respawn(w2)
 local _,why2=sv2.S:Grant(w2)
 check(why2=='ended'and #sv2.D:GetChestRecords(w2)==0 and sv2.T:GetReady(w2)==0 and noticesFor(w2)==0,'E: an owed profile after the end is given nothing (no pack, no rolls, no notice): the event is over')
 clockNow.t=EndsAt-10*86400
end

-- F. The floored open -------------------------------------------------------------------------------------------------------------------------------------------------------
local function rankOf(rarity)return Rules.RarityRank(Packs,rarity)end
local MYTHIC=rankOf('Mythic')
do
 local state=158158
 local function rng()state=(state*1664525+1013904223)%4294967296;return state/4294967296 end
 local odds=Packs.SeedOdds(Config,7,VC.Variant,1,Packs.OddsVersion,nil,1)
 local ids,total=Rules.Kept(Packs,'Mythic',odds)
 local all=0;for _,p in pairs(odds)do all+=p end
 check(math.abs(all-100)<1e-6,'F: the Verity pack\'s own odds add up to 100 ('..all..')')
 local lost=0;for id,p in pairs(odds)do if rankOf(Packs.GetRarity(id))<MYTHIC then lost+=p end end
 check(lost>0 and lost<1 and math.abs(total-(100-lost))<1e-9,'F: only the seeds below Mythic are dropped (Plasma Pepper, Legendary: '..string.format('%.4f',lost)..'% of the pack), the rest keeps its own weights')
 -- the expected mix per rarity (renormalised)
 local expect={};for _,id in ipairs(ids)do local r=Packs.GetRarity(id);expect[r]=(expect[r]or 0)+odds[id]/total end
 local order={'Mythic','Secret','Cosmic','King'}
 local mix={};for _,r in ipairs(order)do mix[#mix+1]=string.format('%s %.4f%%',r,100*(expect[r]or 0))end
 print('INFO floored Verity pack, tiers inside the floor (luck 1): '..table.concat(mix,', '))
 for id in pairs(odds)do if rankOf(Packs.GetRarity(id))>=MYTHIC then local seen=false;for _,k in ipairs(ids)do if k==id then seen=true end end;check(seen,'F: '..id..' is inside the floor')end end
 check((expect.Secret or 0)>.9 and(expect.King or 0)>.009 and(expect.Cosmic or 0)>.04 and(expect.Mythic or 0)>0,'F: the Verity pack can give Mythic, Secret, Cosmic and King (no tier is invented: nothing else is in the pool)')
 -- 2,000 REAL opens (OpenSeedPack: the pity, the luck and the real roll)
 local sv=newServer();local P=join(sv,3040,'Opener');sv.D:GetPremium(P).Tutorial.Done=true
 local counts={};local below=0;local hookTest=0
 sv.D.OnPackOpened=function(_,_,info)if info.Test then hookTest+=1 end end
 for i=1,2000 do
  local rec=sv.D:AddChest(P,Rules.Pack(Packs))
  local reward=sv.D:OpenSeedPack(P,rec.Id,rng)
  if not reward then below+=1000;break end
  counts[reward.Rarity]=(counts[reward.Rarity]or 0)+1
  if rankOf(reward.Rarity)<MYTHIC then below+=1 end
  if reward.GiftLocked~=true or reward.Floor~=nil then below+=1000 end
  local recs=sv.D:GetChestRecords(P);for j=#recs,1,-1 do table.remove(recs,j)end
 end
 sv.D.OnPackOpened=nil
 check(below==0,'F: 2,000 real opens of the floored pack: NONE below Mythic (below: '..below..')')
 check(hookTest==2000,'F: a floored open is SILENT (owner: no chat announcement, no BEST PULL): the hub hook sees Test = true every time ('..hookTest..')')
 local line={};for _,r in ipairs(order)do line[#line+1]=r..' '..(counts[r]or 0)end
 print('INFO 2,000 real opens: '..table.concat(line,', '))
 for _,r in ipairs(order)do
  local p=expect[r]or 0;local n=2000;local mean=n*p;local sd=math.sqrt(n*p*(1-p))
  check(math.abs((counts[r]or 0)-mean)<=6*sd+3,string.format('F: %s count %d is within 6 sd of the renormalised %.2f',r,counts[r]or 0,mean))
 end
 -- a big direct roll: the mix is exactly the renormalised weights (every seed)
 local per={};local N=200000;local bad=0
 for _=1,N do
  local seed,rarity=Rules.RollFloored(Packs,'Mythic',Config,7,rng,1,VC.Variant,Packs.OddsVersion,nil,1)
  if not seed or rankOf(rarity)<MYTHIC or rarity~=Packs.GetRarity(seed.Id)then bad+=1 else per[seed.Id]=(per[seed.Id]or 0)+1 end
 end
 check(bad==0,'F: 200,000 floored rolls (luck 1): none below Mythic, the rarity is the seed\'s own')
 local worst=0
 for _,id in ipairs(ids)do local p=odds[id]/total;local sd=math.sqrt(N*p*(1-p));local z=sd>0 and math.abs((per[id]or 0)-N*p)/sd or 0;if z>worst then worst=z end end
 check(worst<5,string.format('F: every seed\'s count follows its renormalised weight (worst z = %.2f)',worst))
 -- luck, the clover and the pity's lucky roll only move chance INSIDE the floor
 local Pity=W.module('PackPity155');local lowAt={};local nLuck=0
 for _,pass in ipairs({1,2,3,1e9})do
  for _,boots in ipairs({1,50,1e12})do
   for _,lucky in ipairs({false,true})do
    for _=1,3000 do
     local seed,rarity=Pity.Scoped(lucky,Rules.RollFloored,Packs,'Mythic',Config,7,rng,boots,VC.Variant,Packs.OddsVersion,nil,pass)
     nLuck+=1;if not seed or rankOf(rarity)<MYTHIC then lowAt[#lowAt+1]=pass..'/'..boots..'/'..tostring(lucky)end
    end
   end
  end
 end
 check(#lowAt==0,'F: with luck x1 to x1e9, the clover x1 - x1e9 and the lucky roll, '..nLuck..' floored rolls never gave anything below Mythic')
 -- the same draw from the pack's own table: nothing outside the table
 check(Rules.RollFloored(Packs,'Mythic',Config,7,0,1,VC.Variant,Packs.OddsVersion,nil,1)~=nil and Rules.RollFloored(Packs,'Mythic',Config,7,function()return .9999999999999999 end,1,VC.Variant,Packs.OddsVersion,nil,1)~=nil,'F: the ends of the draw (0 and just under 1) still give a seed')
 check(Rules.RollFloored(Packs,'Secret',Config,7,rng,1,VC.Variant,Packs.OddsVersion,nil,1)==nil,'F: a floor that is not the known word gives no roll (never a lower seed)')
 -- an ordinary Verity Pack: the normal odds, below Mythic still possible
 local ordinaryLow,ordinary=0,6000
 local sv2=newServer();local O=join(sv2,3041,'Ordinary');sv2.D:GetPremium(O).Tutorial.Done=true
 for _=1,ordinary do
  local rec=sv2.D:AddChest(O,{Stage=7,BagVariant=VC.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Packs.OddsVersion})
  if rec.Floor~=nil then ordinaryLow+=1000000 end
  local reward=sv2.D:OpenSeedPack(O,rec.Id,rng)
  if rankOf(reward.Rarity)<MYTHIC then ordinaryLow+=1 end
  local recs=sv2.D:GetChestRecords(O);for j=#recs,1,-1 do table.remove(recs,j)end
 end
 check(ordinaryLow>=1 and ordinaryLow<1000000,'F: an ordinary Verity Pack still rolls its normal odds (it gave '..ordinaryLow..' Legendary seeds in '..ordinary..'; expected about '..string.format('%.0f',ordinary*lost/100)..')')
 -- the odds table the game shows for a Verity pack is untouched by the floor
 local after=Packs.SeedOdds(Config,7,VC.Variant,1,Packs.OddsVersion,nil,1);local same=true;for id,p in pairs(odds)do if after[id]~=p then same=false end end
 check(same and math.abs((after.PlasmaPepperSeed or 0)-lost)<1e-9,'F: SeedOdds for the Verity pack is unchanged (Plasma Pepper still in it)')
 -- a Forest pack with a forged Floor rolls normally (only a Verity pack keeps it)
 local rec=sv2.D:AddChest(O,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion,Floor='Mythic'})
 check(rec.Floor==nil,'F/G: AddChest drops a Floor on a pack that is not a Verity pack')
 rec.Floor='Mythic' -- (forged in memory)
 local common=0
 for _=1,200 do
  local r=sv2.D:AddChest(O,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion});r.Floor='Mythic'
  local reward=sv2.D:OpenSeedPack(O,r.Id,rng);if reward and rankOf(reward.Rarity)<MYTHIC then common+=1 end
  local recs=sv2.D:GetChestRecords(O);for j=#recs,1,-1 do table.remove(recs,j)end
 end
 check(common>100,'F/G: a Forest pack with a forged Floor in memory still rolls normally ('..common..' of 200 below Mythic)')
end

-- G. The floor can't be set from outside -----------------------------------------------------------------------------------------------------------------------------------
do
 local sv=newServer();local P=join(sv,3050,'Forger');sv.D:GetPremium(P).Tutorial.Done=true
 local function add(extra,options)local c={Stage=7,BagVariant=VC.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Packs.OddsVersion};for k,v in pairs(extra)do c[k]=v end;return sv.D:AddChest(P,c,options)end
 check(add({}).Floor==nil,'G: a plain Verity pack has no floor')
 check(add({Floor='Secret'}).Floor==nil and add({Floor=true}).Floor==nil and add({Floor='mythic'}).Floor==nil and add({Floor={}}).Floor==nil,'G: any floor but the word Mythic is dropped by AddChest')
 check(add({Floor='Mythic'}).Floor=='Mythic','G: (server code asking for the floor on a Verity pack gets it)')
 check(sv.D:AddChest(P,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion,Floor='Mythic'}).Floor==nil,'G: a Void Pack never carries it')
 check(add({Floor='Mythic'},{TestGrant=true}).TestGrant==true,'G: (a TEST pack is a test pack even with a floor: the owner\'s reveal wins in OpenSeedPack)')
 -- load: only a Pack row of Verity keeps it as a floor; a Seed row never
 local function decode(extra)
  local r={Id='d1',Kind='Pack',ChestNumber=9,ChestName='P',Stage=7,BagVariant=VC.Variant,PackSize=1,PackMutation='None',SeedScale=1};for k,v in pairs(extra)do r[k]=v end
  return sv.D:_decodeSavedSeedRecord(P,r,9)
 end
 check(decode({Floor='Mythic'}).Floor=='Mythic','G: a saved Floor = Mythic on a Verity Pack row loads')
 check(decode({Floor='Cosmic'}).Floor==nil and decode({Floor=true}).Floor==nil and decode({}).Floor==nil,'G: a saved row with another word, a boolean or no field loads as no floor (an old save)')
 check(decode({Kind='Seed',SeedId='SunflowerSeed',Floor='Mythic'}).Floor==nil,'G: a Seed row never has a floor')
 -- serializer
 local rec=add({Floor='Mythic'});check(sv.D:SerializeSeedRecord(rec).Floor=='Mythic','G: SerializeSeedRecord writes it (saves and gifts use the same row)')
 local plain=add({});check(sv.D:SerializeSeedRecord(plain).Floor==nil,'G: an ordinary pack\'s row has no Floor key')
 -- opening a floored pack: the seed has no floor
 local seed=sv.D:OpenSeedPack(P,rec.Id,function()return .5 end);check(seed and seed.Floor==nil and seed.GiftLocked==nil,'G: the seed made from it carries no floor')
 -- test packs (owner commands) never get a floor: nothing in the owner test code knows the gift
 local tpacks=server('OwnerTestPacks');check(type(tpacks)=='table','G: (OwnerTestPacks loads)')
 -- nothing a client sends can reach AddChest with a Floor: the pack record is made by server code only (checked statically by the run script)
end

-- H. The pack can't be gifted ---------------------------------------------------------------------------------------------------------------------------------------------
do
 W.env.RaycastParams={new=function()return {}end}
 function W.workspace.Raycast()return nil end
 local Chase={IsPlayerBusy=function()return false end}
 local sv=newServer()
 local GChests={Openings={}};function GChests:SyncTools()end
 local realSpawn=R.task.spawn;R.task.spawn=function()return nil end -- (FruitGiftService.new starts a 15 s sweep loop; the mock's task.wait does not yield, so that loop is not started)
 local Gifts=server('FruitGiftService').new(sv.D,GChests,Chase,nil)
 R.task.spawn=realSpawn
 local said={};Gifts.Remote={FireClient=function(_,p,a,msg)if a=='Status'then said[#said+1]={P=p,Msg=msg}end end}
 local function lastSaid(p)for i=#said,1,-1 do if said[i].P==p then return said[i].Msg end end end
 local from=join(sv,3060,'Giver');local to=join(sv,3061,'Taker')
 for _,pl in ipairs({from,to})do pl:SetAttribute('PaidTradingAllowed',true);pl:SetAttribute('PaidRandomAllowed',true);sv.D:GetPremium(pl).Tutorial.Done=true;sv.D:PublishTutorial(pl)end
 from.Character.HumanoidRootPart.Position=V3(0,3,0);to.Character.HumanoidRootPart.Position=V3(5,3,0)
 local function hold(p,rec)local tool=R.new('Tool');tool.Name=rec.Kind=='Pack'and'Test Pack'or'Test Seed';tool:SetAttribute(rec.Kind=='Pack'and'SeedPackTool'or'GardenSeed',true);tool:SetAttribute('SeedInventoryId',rec.Id);tool.Parent=p.Character;return tool end
 local function offer(rec)R.advance(3);Gifts:OfferSeed(from,to.UserId,rec.Id);R.advance(5)end
 local function has(p,id)for _,r in ipairs(sv.D:GetChestRecords(p))do if r.Id==id then return true end end;return false end
 local gift=sv.D:AddChest(from,Rules.Pack(Packs))
 local tool=hold(from,gift);offer(gift)
 check(has(from,gift.Id)and not has(to,gift.Id),'H: the gift pack is NOT gifted: the giver keeps it, the other player gets nothing')
 check(lastSaid(from)==Gifts.LockedVerityText and Gifts.LockedVerityText=="Free Verity Packs can't be gifted",'H: with a plain message ('..tostring(lastSaid(from))..')')
 tool:Destroy()
 -- a stale offer that reaches Accept
 local gid='stale';tool=hold(from,gift);Gifts.Offers[gid]={From=from,To=to,ItemId=gift.Id,Kind='Seed',Expires=R.clock+25};Gifts:Accept(to,gid);check(has(from,gift.Id)and not has(to,gift.Id),'H: an offer that reaches Accept changes nothing');tool:Destroy()
 -- the seed opened from it
 local seed=sv.D:OpenSeedPack(from,gift.Id,function()return .5 end)
 check(seed and seed.GiftLocked==true,'H: the seed opened from it is locked too')
 tool=hold(from,seed);offer(seed);check(has(from,seed.Id)and not has(to,seed.Id)and lastSaid(from)==Gifts.LockedVeritySeedText,'H: the seed is not gifted either ('..tostring(lastSaid(from))..')');tool:Destroy()
 -- controls
 local ordinary=sv.D:AddChest(from,{Stage=7,BagVariant=VC.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Packs.OddsVersion})
 tool=hold(from,ordinary);offer(ordinary);check(has(to,ordinary.Id)and not has(from,ordinary.Id),'H: control: an ordinary Verity Pack can still be gifted');tool:Destroy()
 local void=sv.D:AddChest(from,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion,GiftLocked=true})
 tool=hold(from,void);offer(void);check(has(from,void.Id)and lastSaid(from)==Gifts.LockedText,'H: control: a free Void Pack keeps its own message ('..tostring(lastSaid(from))..')');tool:Destroy()
end

-- I. The tool: its own name, its own stack -------------------------------------------------------------------------------------------------------------------------------
do
 local sv=newServer();local P=join(sv,3070,'Stacker');sv.D:GetPremium(P).Tutorial.Done=true
 local bp=P:FindFirstChildOfClass('Backpack')
 local CS=server('ChestService')
 local self={PlayerData=sv.D,Openings={},Config=Config}
 local gift=sv.D:AddChest(P,Rules.Pack(Packs))
 local plain=sv.D:AddChest(P,{Stage=7,BagVariant=VC.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Packs.OddsVersion})
 local okA,toolG=pcall(CS._createPackTool,self,gift,bp);local okB,toolP=pcall(CS._createPackTool,self,plain,bp)
 check(okA and toolG and okB and toolP,'I: the pack tools are built ('..tostring(toolG)..' / '..tostring(toolP)..')')
 if toolG and toolP then
  check(toolG.Name==Rules.ToolName and toolP.Name~=Rules.ToolName,'I: the gift pack\'s tool has its own name ("'..toolG.Name..'"); the ordinary Verity Pack keeps "'..toolP.Name..'"')
  check(toolG.ToolTip:find('Guaranteed Mythic or better',1,true)~=nil,'I: its tooltip says what it is')
  check(Stacks.Key(toolG)~=Stacks.Key(toolP),'I: the stack keys differ: a gift pack never shares a hotbar slot / Bag stack with ordinary Verity Packs')
  check(toolG:GetAttribute('BagVariant')==VC.Variant and toolG:GetAttribute('Stage')==7,'I: it is still a Verity pack tool (variant, stage)')
  local plain2=sv.D:AddChest(P,{Stage=7,BagVariant=VC.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Packs.OddsVersion})
  local _,toolP2=pcall(CS._createPackTool,self,plain2,bp);check(toolP2 and Stacks.Key(toolP2)==Stacks.Key(toolP),'I: two ordinary Verity Packs still share a stack (unchanged)')
  local gift2=sv.D:AddChest(P,Rules.Pack(Packs));local _,toolG2=pcall(CS._createPackTool,self,gift2,bp);check(toolG2 and Stacks.Key(toolG2)==Stacks.Key(toolG),'I: two gift packs (a reset in Studio) share their own stack')
 end
end

-- J. The owner tool ----------------------------------------------------------------------------------------------------------------------------------------------------
do
 local sv=newServer();local P=join(sv,3080,'Boss',nil,true)
 local ok,text=sv.S:_command(P,{})
 check(ok==true and text:find('OWED',1,true)~=nil and text:find('running',1,true)~=nil,'J: starterverity shows OWED and the running event ('..tostring(text)..')')
 local ok2,why=sv.S:_command(P,{'reset'});check(ok2==false and why:find('Studio only',1,true)~=nil,'J: reset is refused outside Studio')
 check(sv.S:_command(P,{'nonsense'})==false,'J: junk is refused')
 local st=newServer(true);local Q=join(st,3081,'StudioBoss');flush(2)
 check(#gifts(st,Q)==1 and flag(st,Q)==Rules.Given,'J: (Studio: the gift is given)')
 local ok3,msg=st.S:_command(Q,{'reset'})
 check(ok3==true and #gifts(st,Q)==2 and flag(st,Q)==Rules.Given and msg:find('given again',1,true)~=nil,'J: reset in Studio gives it again at once (spawned) ('..tostring(msg)..')')
 check(select(2,st.S:_command(Q,{})):find('GIVEN',1,true)~=nil,'J: and status says GIVEN')
 check(select(1,StarterSvc.Command(nil,Q,{}))==true,'J: the owner command reaches the running service (StarterVerity158d.Command)')
end

check(#warns==0 or true,'(warnings: '..#warns..')')
print(string.format('starter gift 158d: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
