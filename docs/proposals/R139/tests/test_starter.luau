--!nocheck
-- R139 (owner: "make it so the pack is a 1 time thing and also make it so that players dont know that the pack is 2x
-- luck"): the real PlayerDataService (GrantStarterPack, gifts in and out, save rows), ChestService (the pack tool and
-- its hold tooltip) and FruitGiftService (receiving a gift). The free tutorial pack is still 2x on the server, but
-- nothing a player can see says so; it is given once per account; a gift of it arrives as a normal pack.
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
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end -- (mock gap)
 return o end end
local Config=server('Config')
local Rules=W.module('SeedPackRules');local Guide=W.module('BeginnerGuide')
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local shown={}
local Data=server('PlayerDataService').new(Config,Map,{Show=function(_,p,text)shown[#shown+1]=text end})
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local A=makePlayer(401,'Ava');local B=makePlayer(402,'Ben')
local function finishTutorial(p)
 local s=Data:GetPremium(p).Tutorial or Guide.Read();Data:GetPremium(p).Tutorial=s
 s.Mask=bit32.bor(s.Mask,Guide.Bits.Pack,Guide.Bits.Seed,Guide.Bits.Plant);Data:PublishTutorial(p)
 if Data:TutorialAction(p,'TreadmillInfo')then Data:PublishTutorial(p)end
 return p:GetAttribute('TutorialDone')==true and Data:GrantStarterPack(p)or nil
end
local function boosted(p)local n,rec=0,nil;for _,r in ipairs(Data:GetChestRecords(p))do if r.Kind=='Pack'and r.RateBoost then n+=1;rec=r end end;return n,rec end
-- 1. Still 2x on the server.
local gift=finishTutorial(A)
check(gift and gift.RateBoost==2 and gift.Stage==1 and gift.BagVariant=='Pack01','finishing the tutorial gives the Forest pack, still 2x on the server')
-- 2. Nothing a player sees mentions luck.
local normal=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',Weather='None',OddsVersion=Rules.OddsVersion})
check(gift and normal and gift.ChestName==normal.ChestName,('named like any pack ("%s" / "%s")'):format(tostring(gift and gift.ChestName),tostring(normal and normal.ChestName)))
local words={}
local function scan(v,path)
 if type(v)=='string'then local l=v:lower();if l:find('luck',1,true)or l:find('2x',1,true)or v:find('🍀',1,true)then words[#words+1]=path..' = '..v end
 elseif type(v)=='table'then for k,x in pairs(v)do scan(x,path..'.'..tostring(k))end end
end
scan(Guide,'BeginnerGuide')
check(#words==0,'no tutorial text mentions luck or 2x'..(#words>0 and(': '..table.concat(words,' | '))or''))
check(Guide.Finished.Chip.Label=='🎁 FREE PACK!','the finish card says 🎁 FREE PACK!')
check(Guide.StarterPack.Notice=='🎁 FREE Forest Seed Pack! Check your Bag!','the notice: '..Guide.StarterPack.Notice)
-- The pack tool and its hold tooltip (ChestService) read exactly like a normal Forest pack's.
local Chests=server('ChestService')
local fake=setmetatable({PlayerData=Data,Config=Config,Openings={}},{__index=Chests})
local bp=A:FindFirstChildOfClass('Backpack')
local tLucky=Chests._createPackTool(fake,gift,bp);local tNormal=Chests._createPackTool(fake,normal,bp)
check(tLucky and tNormal and tLucky.Name==tNormal.Name and tLucky.ToolTip==tNormal.ToolTip,'the pack tool looks like a normal Forest pack ('..tostring(tLucky and tLucky.Name)..')')
local attrs={};for k,v in pairs(tLucky and tLucky:GetAttributes()or{})do if tostring(k):lower():find('boost')or tostring(k):lower():find('luck')then attrs[#attrs+1]=k end end
check(#attrs==0,'no boost / luck attribute on the tool'..(#attrs>0 and(': '..table.concat(attrs,', '))or''))
fake.Openings[A]=true -- (an opening in progress: _holdPack only writes the tooltip)
Chests._holdPack(fake,A,tLucky);Chests._holdPack(fake,A,tNormal)
check(tLucky.ToolTip==tNormal.ToolTip,'holding it shows the same tooltip as a normal Forest pack')
check(not tLucky.ToolTip:lower():find('luck',1,true)and not tLucky.ToolTip:find('🍀',1,true),'no LUCK row')
local plain=Rules.SeedOdds(Config,1,'Pack01',A:GetAttribute('ChestLuckMultiplier'),Rules.OddsVersion)
local Odds=W.module('OddsText85');local listed=0
for _,seed in ipairs(Rules.RewardPool(Config,1,'Pack01')or{})do if(plain[seed.Id]or 0)>0 then
 if tLucky.ToolTip:find(seed.Name..': '..Odds.Format(plain[seed.Id]),1,true)then listed+=1 end end end
local legendary;for id,p in pairs(plain)do if Rules.GetRarity(id)=='Legendary'then legendary=p end end
check(listed>=4,'it lists the normal Forest odds ('..listed..' seeds)')
check(legendary and tLucky.ToolTip:find(Odds.Format(legendary),1,true),'Legendary shows the normal '..tostring(legendary and Odds.Format(legendary))..', not the doubled chance')
-- The new pack glows in the hotbar (it is numbered after the save loaded).
check(type(A:GetAttribute('PackSerialAtJoin'))=='number'and gift.ChestNumber>A:GetAttribute('PackSerialAtJoin')and tLucky:GetAttribute('PackNumber')==gift.ChestNumber,
 'the free pack is stamped as new (PackNumber '..tostring(tLucky:GetAttribute('PackNumber'))..' > PackSerialAtJoin '..tostring(A:GetAttribute('PackSerialAtJoin'))..')')
fake.Openings[A]=nil;tLucky:Destroy();tNormal:Destroy()
-- 3. A one-time thing: once per account, and its luck stays with the player who earned it.
local before=boosted(A)
Data:TutorialAction(A,'Replay');check(finishTutorial(A)==nil and boosted(A)==before,'replaying the tutorial never gives another')
local saved=Data:_buildSaveData(A);check(saved.Premium and saved.Premium.StarterPack==true,'the "given" flag is saved with the account')
local row=Data:SerializeSeedRecord(gift)
check(row.RateBoost==2,'(its own save row keeps the 2x)')
local decoded=Data:DecodeGiftedSeed(B,row)
check(decoded and decoded.Kind=='Pack'and decoded.Stage==1 and decoded.RateBoost==nil,'gifted, it is decoded as a normal Forest pack')
local src=W.B.FruitGiftService
check(src:find('local row=self.Data:SerializeSeedRecord(record)\n row.RateBoost=nil',1,true)~=nil,'the gift staged by the sender carries no boost')
-- Receiving a gift staged before R139 (with the boost still in the row) also gives a normal pack.
local Gifts=server('FruitGiftService')
local synced=0
local giver={Data=Data,Chests={SyncTools=function()synced+=1 end}}
local staged=table.clone(row);staged.Id='gift-pack-1'
local ok,res=pcall(Gifts._receiveSeed,giver,B,Data.Gardens[B]or{},{},'gift-1',{Seed=staged})
local got;for _,r in ipairs(Data:GetChestRecords(B))do if r.Id=='gift-pack-1'then got=r end end
check(ok and res==true and got~=nil and got.RateBoost==nil and synced==1,'Ben receives it as a normal Forest pack ('..tostring(ok and res or res)..')')
check(got and got.ChestNumber>B:GetAttribute('PackSerialAtJoin'),'and it is new for him too (glows in his hotbar)')
-- Ben finishing his own tutorial still gets his own one.
local bens=finishTutorial(B);check(bens and bens.RateBoost==2 and select(1,boosted(B))==1,'Ben still gets his own free pack, once')
check(finishTutorial(B)==nil,'and only once')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
