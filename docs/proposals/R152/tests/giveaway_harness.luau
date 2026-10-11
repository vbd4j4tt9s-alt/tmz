--!nocheck
-- R152 Void Pack giveaway test harness (shared by the suites and the preview): the R150 pedestal harness (R149 zfight_world mock: Model pivots, bounding boxes, real tweens, sounds
-- recorded, ClientFxBudget stubbed) plus
--  * a DataStoreService mock that behaves like Roblox's where it matters here: UpdateAsync is a compare-and-set (its transform runs AGAIN on the fresh value when another server
--    wrote between its read and its commit; `backend.Race` lets a test write exactly then), returning nil from the transform cancels, values must be plain data (string keys, finite
--    numbers), every request is counted, any call can fail with any message (`backend.Fail`);
--  * the MessagingService bus of R151's announce_env (a subscriber hears every server's messages on the topic, the publisher's own included; calls can fail);
--  * a fake PlayerDataService (the inventory limit, the Premium table, the save calls, AddChest as the real one builds a record) so a test controls the player's data exactly
--    (R158c: a player has finished the tutorial the claim needs unless the test passes Tutorial=false; Played = the R157 play-time counter, which no rule uses now);
--  * servers: a VoidGiveaway152 on a shared backend / bus with its own fake data, a fake clock and a recorded wait.
-- The real PlayerDataService / ChestService / VerityService are used by test_giveaway_real.luau.
local H=require('./pedestal_harness');local E=require('./announce_env')
local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local G={H=H,W=W,R=R,E=E}
local RS=W.RS
-- BulkMoveTo really moves (the client moves a pack and its effects in one batch).
function W.workspace.BulkMoveTo(_,parts,frames)for i,p in ipairs(parts)do if p.Parent then p.CFrame=frames[i]end end end
-- Destroying a tagged instance fires CollectionService's InstanceRemoved signal, as on Roblox (the mock only fires it for RemoveTag).
do
 local raw=R.Inst.Destroy
 function R.Inst.Destroy(self)
  if self._destroyed then return end
  if self:IsDescendantOf(W.game)then
   local function walk(o)
    if o._tags then for tag in pairs(o._tags)do W.CS:GetInstanceRemovedSignal(tag):Fire(o)end end
    for _,c in ipairs(o._children)do walk(c)end
   end
   walk(self)
  end
  return raw(self)
 end
end
local function deepcopy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=deepcopy(x)end;return o end
G.deepcopy=deepcopy
local function plain(v,path)
 local t=type(v)
 if t=='number'then assert(v==v and math.abs(v)<math.huge,'cannot store '..tostring(v)..' at '..path);return end
 if t=='string'or t=='boolean'then return end
 assert(t=='table','cannot store a '..t..' at '..path)
 for k,x in pairs(v)do assert(type(k)=='string'or type(k)=='number','cannot store key '..tostring(k)..' at '..path);plain(x,path..'.'..tostring(k))end
end
-- DataStore ----------------------------------------------------------------------------------------------------------------------------------------------------
function G.backend()
 return{Data={},Version={},Calls={Get=0,Update=0,Transforms=0,Writes=0},Race=nil,Fail=nil,Log={}}
end
-- A DataStoreService for one server on the backend. backend.Fail(kind, store, key) -> an error message or nil.
function G.dataStoreService(b)
 local svc={}
 function svc:GetDataStore(name)
  local store={Name=name}
  local function k(key)return name..'/'..tostring(key)end
  function store:GetAsync(key)
   b.Calls.Get+=1;table.insert(b.Log,'Get '..k(key))
   local f=b.Fail and b.Fail('Get',name,key);if f then error(f,0)end
   return deepcopy(b.Data[k(key)])
  end
  function store:UpdateAsync(key,fn)
   b.Calls.Update+=1;table.insert(b.Log,'Update '..k(key))
   local f=b.Fail and b.Fail('Update',name,key);if f then error(f,0)end
   for _=1,25 do
    local seen=b.Version[k(key)]or 0
    local old=deepcopy(b.Data[k(key)])
    b.Calls.Transforms+=1
    local new=fn(old)
    if b.Race then local race=b.Race;b.Race=nil;race()end -- another server writes between our read and our commit
    if(b.Version[k(key)]or 0)==seen then
     if new==nil then return nil end -- cancelled: nothing is written
     plain(new,k(key))
     b.Data[k(key)]=deepcopy(new);b.Version[k(key)]=seen+1;b.Calls.Writes+=1
     return deepcopy(new)
    end
   end
   error('too many conflicts on '..k(key),0)
  end
  return store
 end
 return svc
end
-- A clock: t = seconds (the service's Clock), unix = the wall time stored with a claim; Waits = every wait the store asked for.
function G.clock()
 local c={t=1000,unix=1760000000,Waits={}}
 function c.now()return c.t end
 function c.time()return c.unix end
 function c.wait(s)c.Waits[#c.Waits+1]=s end
 function c.advance(s)c.t+=s;c.unix+=s end
 return c
end
-- Fake player data -----------------------------------------------------------------------------------------------------------------------------------------------
function G.fakeData(config)
 local D={Config=config,Records={},Premium={},CanSave={},Loaded={},Dirty={},Saves={},AddCalls=0}
 function D:IsLoaded(p)return self.Loaded[p]==true end
 function D:GetChestRecords(p)self.Records[p]=self.Records[p]or{};return self.Records[p]end
 function D:GetPremium(p)self.Premium[p]=self.Premium[p]or{};return self.Premium[p]end
 function D:AddChest(p,chest,options)
  self.AddCalls+=1
  if self.ThrowAdd then error('AddChest exploded')end
  local records=self:GetChestRecords(p);if #records>=config.MaxSavedChests then return nil,'SEED INVENTORY FULL'end
  local n=(p:GetAttribute('ChestInventorySerial')or 0)+1;p:SetAttribute('ChestInventorySerial',n)
  local record={Id=p.UserId..'_'..n,ChestNumber=n,ChestName='Seed Pack',Kind='Pack',Stage=chest.Stage,BagVariant=chest.BagVariant,OddsVersion=chest.OddsVersion or 81,
   PackSize=chest.PackSize,PackMutation=chest.PackMutation,Weather=chest.Weather,TestGrant=(type(options)=='table'and options.TestGrant==true)or nil,GiftLocked=chest.GiftLocked==true or nil}
  table.insert(records,record)
  if self.ThrowAfterAdd then error('a hook after AddChest exploded')end
  return record
 end
 function D:MarkDirty(p)self.Dirty[p]=(self.Dirty[p]or 0)+1 end
 function D:QueueGardenSave(p)self.Saves[p]=(self.Saves[p]or 0)+1 end
 -- A player whose profile just loaded. o: {Room (extra packs already in the Bag), Flag, CanSave, Tutorial (R158c: false = not finished, 'unset' = no attribute; default finished), Played (R157 counter)}
 function D:load(p,o)
  o=o or{};self.Loaded[p]=true;self.CanSave[p]=o.CanSave~=false
  for i=1,o.Packs or 0 do self:AddChest(p,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',Weather='None'});end
  self.AddCalls=0
  if o.Flag then self:GetPremium(p).VoidGift152=true end
  -- R158c: the claim needs a finished tutorial (the player attribute TutorialDone, set by TutorialProgress). A player here has finished it unless the test says Tutorial=false (not finished) or
  -- Tutorial='unset' (the attribute was never published). Played (R157, a counter only now) = seconds in Premium.PlaySeconds157, or nothing / false = a save with no such field.
  if o.Tutorial=='unset' then p:SetAttribute(G.Rules.TutorialAttr,nil)else p:SetAttribute(G.Rules.TutorialAttr,o.Tutorial~=false)end
  if o.Played then self:GetPremium(p)[G.Rules.PlayField]=o.Played end
  return p
 end
 function D:voidPacks(p)local n=0;for _,r in ipairs(self:GetChestRecords(p))do if r.BagVariant=='EclipseReliquary'then n+=1 end end;return n end
 return D
end
function G.notes()
 local N={Log={}}
 function N:Show(p,text,color,seconds,kind)self.Log[#self.Log+1]={P=p,Text=text,Color=color,Kind=kind}end
 function N:last(p)for i=#self.Log,1,-1 do if self.Log[i].P==p then return self.Log[i]end end;return nil end
 function N:count(p)local n=0;for _,x in ipairs(self.Log)do if x.P==p then n+=1 end end;return n end
 return N
end
function G.chests()
 local C={Syncs=0};function C:SyncTools()self.Syncs+=1 end;return C
end
-- The map: Workspace.ChestChaseMap with the lobby floor (top at y 4).
local maps=0
function G.map(fresh)
 if fresh then local old=W.workspace:FindFirstChild('ChestChaseMap');if old then old:Destroy()end;maps=0 end
 maps+=1
 local root=R.new('Folder');root.Name=maps==1 and'ChestChaseMap'or'ChestChaseMap_'..maps;root.Parent=W.workspace
 local lobby=R.new('Folder');lobby.Name='Lobby';lobby.Parent=root
 local floor=R.new('Part');floor.Name='LobbyFloor';floor.Size=V3(680,4,520);floor.CFrame=CF(0,2,-360);floor.Anchored=true;floor.Parent=lobby
 return root
end
-- Servers --------------------------------------------------------------------------------------------------------------------------------------------------
local Store,Service=H.server('VoidGiveawayStore152'),H.server('VoidGiveaway152')
G.Store,G.Service=Store,Service
G.Rules=W.module('VoidGiveawayRules152')
-- A server on the shared backend and bus. o: {Name, Studio, Memory, Config, Data, Chests, Notes, Clock, Messaging, NoMap}
function G.server(backend,bus,o)
 o=o or{}
 local clock=o.Clock or G.clock()
 local data=o.Data or G.fakeData(o.Config or{MaxSavedChests=40})
 local notes=o.Notes or G.notes();local chests=o.Chests or G.chests()
 local ds=G.dataStoreService(backend)
 local store=Store.new({Service=ds,Clock=clock.now,Time=clock.time,Wait=clock.wait,Studio=o.Studio==true,Memory=o.Memory,Random={NextNumber=function()return 0 end}})
 local messaging=bus and bus:Server(o.Name or'A')or nil
 local root=G.map(o.FreshMap)
 local svc=Service.new(data.Config,data,chests,notes,{MapRoot=root},{Clock=clock.now,Time=clock.time,Store=store,Messaging=messaging,Studio=o.Studio==true,NoLoop=true,
  Random={NextNumber=function()return 0 end}})
 return{Svc=svc,Data=data,Notes=notes,Chests=chests,Clock=clock,Store=store,DS=ds,Messaging=messaging,Root=root,Name=o.Name or'A'}
end
-- A player standing at the pedestal, profile loaded.
function G.player(server,id,name,o)
 o=o or{}
 local p=H.player(id,name,false);server.Data:load(p,o)
 if o.Stand~=false then H.character(p,V3(0,5,-392+(o.Dist or 12)))end
 return p
end
function G.leave(p)
 for i,q in ipairs(H.players)do if q==p then table.remove(H.players,i);break end end
 p.Parent=nil;W.service('Players').PlayerRemoving:Fire(p)
end

-- The client script as the local player `me` (a Player from H.player(id,name,true)); the camera looks at the pedestal from `from`.
function G.loadClient()
 local sc=R.new('LocalScript');sc.Name='VoidGiveawayClient152';W.load('VoidGiveawayClient152',sc);G.client=sc;return sc
end
function G.look(from,at)W.workspace.CurrentCamera.CFrame=R.CFrame.lookAt(from,at)end
-- game time: `seconds` in frames of dt (the render loop and the half-second tick run when connected)
function G.run(seconds,dt)dt=dt or 1/30;for _=1,math.floor(seconds/dt+.5)do W.frames(1,dt)end end
G.RS=RS
return G
