--!nocheck
-- R153 test environment: the Roblox mock with the REAL server modules of whatever tree rs_bundle.luau was made from (this checkout, or the R152 release for the old-server
-- test): a scheduler where task.wait really yields (PassGiftService runs a `while task.wait(60)` loop), RunService / Players / DataStoreService / HttpService /
-- MarketplaceService stand-ins, the real PlayerDataService, a table serialiser (profiles travel between the R153 and the R152 world as text) and a check counter.
-- require('./clover_env') builds the world once; the test files use what it returns.
local W=require('./world');local R=W.R
local E={W=W,R=R,Fails=0,Checks=0}
function E.check(c,msg)E.Checks+=1;if not c then E.Fails+=1;print('FAIL: '..msg)end;return c end
-- scheduler ------------------------------------------------------------------------------------------------------------------------------------
local sleeping={}
local task2=table.clone(R.task)
task2.spawn=function(f,...)local co=type(f)=='thread'and f or coroutine.create(f);local ok,e=coroutine.resume(co,...);if not ok then error(debug.traceback(co,tostring(e)),0)end;return co end
task2.wait=function(t)
 t=t or 0
 if not coroutine.isyieldable()then return t end
 table.insert(sleeping,{At=R.clock+t,Co=coroutine.running()});coroutine.yield();return t
end
W.env.task=task2
function E.advance(dt)
 local target=R.clock+dt
 while true do
  local nextAt;for _,s in ipairs(sleeping)do if not nextAt or s.At<nextAt then nextAt=s.At end end
  if not nextAt or nextAt>target then break end
  R.advance(math.max(0,nextAt-R.clock))
  local due,keep={},{}
  for _,s in ipairs(sleeping)do if s.At<=R.clock then due[#due+1]=s else keep[#keep+1]=s end end
  sleeping=keep
  for _,s in ipairs(due)do local ok,e=coroutine.resume(s.Co);if not ok then error(debug.traceback(s.Co,tostring(e)),0)end end
 end
 R.advance(math.max(0,target-R.clock))
end
-- services -------------------------------------------------------------------------------------------------------------------------------------
local RS=W.RS;E.RS=RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();E.Players=Players
local present,order={},{}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return string.format('00000000-0000-4000-8000-%012d',guid)end
local stores={}
local DS=W.service('DataStoreService')
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
W.service('PolicyService').GetPolicyInfoForPlayerAsync=function()return {ArePaidRandomItemsRestricted=false,IsPaidItemTradingAllowed=true}end
local Market=W.service('MarketplaceService');E.Market=Market
Market.PromptGamePassPurchaseFinished=R.signal()
Market.UserOwnsGamePassAsync=function()return false end
Market.GetProductInfoAsync=function()return nil end
Market.GetUsersPriceLevelsAsync=function(_,ids)local out={};for _,id in ipairs(ids)do out[#out+1]={UserId=id,PriceLevel=100}end;return out end
Market.PromptProductPurchase=function()end
-- every RemoteEvent the server fires at a client is recorded; Tools get the events the mock lacks
E.sent={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function(self,p,...)E.sent[#E.sent+1]={Remote=self.Name,P=p,Args={...}}end end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS;E.Remotes=remotes
W.stub('OwnerCommandAccess',{IsAllowed=function(p)return p~=nil end,Publish=function()return true end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService');E.Folder=folder
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
W.env.bit32=bit32
function E.server(n)return W.require(folder[n])end
E.Config=E.server('Config')
-- the real PlayerDataService --------------------------------------------------------------------------------------------------------------------
E.Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
E.Notes={Show=function(_,p,msg,color,seconds)E.notes[#E.notes+1]={P=p,Text=msg,Color=color,Seconds=seconds}end};E.notes={}
local PDS=E.server('PlayerDataService')
function E.newData()return PDS.new(E.Config,E.Map,E.Notes)end
E.Data=E.newData()
-- makePlayer(id, name, data): a joined, loaded player. opts.Kick = true: the load may kick (returns nil, the kick reason).
function E.makePlayer(id,name,data,opts)
 data=data or E.Data
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 local kicked
 function p.Kick(_,why)kicked=tostring(why);error('kicked',0)end
 R.new('Backpack').Parent=p
 data:PreparePlayer(p)
 local ok,loaded=pcall(function()return data:Load(p)end)
 if kicked then if opts and opts.Kick then return nil,kicked,p end;error('kicked '..name..': '..kicked,0)end
 assert(ok and loaded,'load '..name..': '..tostring(loaded))
 return p
end
function E.leave(p,data)present[p.UserId]=nil;p.Parent=nil;if data then pcall(function()data:Cleanup(p)end)end end
-- text <-> table (profiles travel between worlds as text) ----------------------------------------------------------------------------------------
local function ser(v)
 local t=type(v)
 if t=='number'then
  assert(v==v and v~=math.huge and v~=-math.huge,'cannot serialise '..tostring(v))
  if v%1==0 and math.abs(v)<1e15 then return string.format('%d',v)end
  return string.format('%.17g',v)
 elseif t=='boolean'then return tostring(v)
 elseif t=='string'then return string.format('%q',v)
 elseif t=='table'then
  local keys={};for k in pairs(v)do keys[#keys+1]=k end
  table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)=='number'end)
  local out={};for _,k in ipairs(keys)do out[#out+1]='['..ser(k)..']='..ser(v[k])end
  return '{'..table.concat(out,',')..'}'
 end
 error('cannot serialise a '..t)
end
E.ser=ser
function E.deep(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=E.deep(x)end;return o end
function E.count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
function E.finish(name)
 print(string.format('%s: %d checks, %d failures',name,E.Checks,E.Fails))
 if E.Fails>0 then error('failed')end
end
return E
