-- R152: the shared half of the Void Pack giveaway: ONE DataStore key ('VoidGiveaway152' / 'Claims') holding {Count = n, Users = {[tostring(userId)] = unix time}} for every server.
--  * Reserve is UpdateAsync with VoidGiveawayRules152.Reserve as its transform: atomic per key, so two servers racing at 499 can never both get the last pack, and a user who is
--    already in Users (an earlier claim whose pack never arrived) is "already reserved" and costs no write. A failed call is tried again a few times with a growing wait; after
--    that the caller gets (false, reason) and tells the player to try again. A pack is NEVER given without a successful answer from here.
--  * Read is one GetAsync (the service polls it about once a minute). A failed read backs off (5, 10, 20 ... up to 60 s) before another one is let through.
--  * Studio: it uses its own store (VoidGiveaway152_Studio), never the live key. When Studio has no DataStore access (Game Settings > Security > "Enable Studio Access to API Services"
--    is off) Probe switches to an in-memory counter with one warn line, so the owner can still test; it resets when the Studio session ends. A live server never does that.
--  * Every call is pcall'd; nothing throws. `service`, `wait`, `time` and `clock` are injectable (the tests pass a mock DataStoreService and a fake clock).
local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('VoidGiveawayRules152'))
local S={};S.__index=S
S.Attempts=4;S.Waits={.6,1.4,3} -- seconds between the tries of one claim (a little jitter is added)
S.RetryBase,S.RetryMax=5,60      -- a failed read: wait this, doubled each time, up to this long before the next
function S.new(opts)
 opts=opts or{}
 local studio=opts.Studio;if studio==nil then local ok,v=pcall(function()return game:GetService('RunService'):IsStudio()end);studio=ok and v==true end
 return setmetatable({Service=opts.Service,Studio=studio==true,Name=opts.Name or(studio and Rules.StudioStoreName or Rules.StoreName),Key=opts.Key or Rules.Key,
  Wait=opts.Wait or task.wait,Time=opts.Time or os.time,Clock=opts.Clock or os.clock,Random=opts.Random or Random.new(),Mode=opts.Memory and'Memory'or'DataStore',
  Mem=opts.Memory and Rules.Clean(nil)or nil,Failures=0,NextTryAt=0,LastError=nil,LastOk=nil,Calls={Read=0,Reserve=0,Edit=0}},S)
end
function S:_store()
 if self.Store then return self.Store end
 local ok,store=pcall(function()return(self.Service or game:GetService('DataStoreService')):GetDataStore(self.Name)end)
 if not ok or not store then return nil,tostring(store)end
 self.Store=store;return store
end
function S:_ok()self.Failures=0;self.NextTryAt=0;self.LastOk=self.Clock();self.LastError=nil end
function S:_fail(message)
 self.Failures+=1;self.LastError=tostring(message):sub(1,160)
 self.NextTryAt=self.Clock()+math.min(S.RetryMax,S.RetryBase*2^(self.Failures-1))
end
-- Studio without DataStore access: one warn line, then an in-memory counter for the rest of the session. Returns true when it switched.
function S:UseMemory(why)
 if self.Mode=='Memory'then return false end
 self.Mode='Memory';self.Mem=Rules.Clean(nil);self.Why=tostring(why):sub(1,120)
 warn('[R152] Void giveaway: no DataStore in Studio ('..self.Why..') - using an in-memory counter for this session (it resets when you stop). For the real store: Game Settings > Security > "Enable Studio Access to API Services".')
 return true
end
-- Studio only: can the store be read? If not, switch to memory. Returns the mode.
function S:Probe()
 if self.Mode=='Memory'or not self.Studio then return self.Mode end
 local store,why=self:_store()
 if not store then self:UseMemory(why);return self.Mode end
 local ok,err=pcall(function()return store:GetAsync(self.Key)end)
 if not ok then self:UseMemory(err)else self:_ok()end
 return self.Mode
end
-- One read (the poll). Returns true, value (clean) or false, reason. Gated by the backoff after a failure.
function S:Read()
 if self.Mode=='Memory'then return true,Rules.Clean(self.Mem)end
 if self.Clock()<self.NextTryAt then return false,'backoff'end
 local store,why=self:_store();if not store then self:_fail(why);return false,why end
 self.Calls.Read+=1
 local ok,value=pcall(function()return store:GetAsync(self.Key)end)
 if not ok then self:_fail(value);return false,tostring(value)end
 self:_ok();return true,Rules.Clean(value)
end
function S:_reserveOnce(userId)
 local now=self.Time();local seen,outcome
 local function transform(old)local value,o,current=Rules.Reserve(old,userId,now,Rules.Cap);seen,outcome=current,o;return value end -- (runs again on a conflict: it only overwrites)
 self.Calls.Reserve+=1
 if self.Mode=='Memory'then
  local value=transform(self.Mem);if value then self.Mem=value end
  return true,outcome,Rules.Clean(self.Mem)
 end
 local store,why=self:_store();if not store then self:_fail(why);return false,why end
 local ok,err=pcall(function()return store:UpdateAsync(self.Key,transform)end)
 if not ok then self:_fail(err);return false,tostring(err)end
 if outcome==nil then self:_fail('the update did not run');return false,'the update did not run'end
 self:_ok();return true,outcome,seen
end
-- Reserves a place for this user. Returns true, outcome ('new' | 'already' | 'full'), value (the store as it is now: Count and Users) or false, reason (the store could not be
-- reached after S.Attempts tries). Yields (UpdateAsync, the waits).
function S:Reserve(userId)
 local last
 for attempt=1,S.Attempts do
  local ok,outcome,value=self:_reserveOnce(userId)
  if ok then return true,outcome,value end
  last=outcome
  if attempt<S.Attempts then self.Wait((S.Waits[attempt]or 3)*(1+self.Random:NextNumber()*.25))end
 end
 return false,last
end
-- Studio only (live data is never edited from a server): fn(clean value) -> new value, written through the same key. Returns true, value or false, reason.
function S:Edit(fn)
 if not self.Studio then return false,'Studio only'end
 if self.Mode=='Memory'then self.Mem=Rules.Clean(fn(Rules.Clean(self.Mem)));return true,Rules.Clean(self.Mem)end
 local store,why=self:_store();if not store then return false,why end
 local result
 self.Calls.Edit+=1
 local ok,err=pcall(function()return store:UpdateAsync(self.Key,function(old)result=Rules.Clean(fn(Rules.Clean(old)));return result end)end)
 if not ok then return false,tostring(err)end
 return true,Rules.Clean(result)
end
function S:Status()
 return{Mode=self.Mode,Store=self.Name,Key=self.Key,Studio=self.Studio,Failures=self.Failures,LastOk=self.LastOk,LastError=self.LastError,Why=self.Why,
  RetryIn=math.max(0,self.NextTryAt-self.Clock()),Calls=self.Calls}
end
return S
