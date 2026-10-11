-- R151: the shared half of the hub displays. One MemoryStore hash map (HubDisplayRules.StoreName), one key per UTC day ('d20001'), holding that day's record
-- {v=1, fruit=...}. Every server reads the day's key about once a minute and writes only when it has something better (UpdateAsync is a compare-and-set:
-- the transform runs again if another server wrote in between, and it keeps whichever record HubDisplayRules ranks higher, so two servers that finish at the same
-- moment cannot overwrite each other with a worse one). Keys expire after two days.
--  * Every call is pcall'd. A failure never throws: the caller gets (false, reason) and the store backs off (5, 10, 20 ... s up to 5 minutes; 90 s or more after a
--    "throttled / quota / 429" answer) before it lets another request through, so a sick MemoryStore costs nothing but a timer.
--  * This server's own request budget (HubDisplayRules.RequestsPerMinute) is a sliding minute; over it, a call is refused with 'budget' without touching MemoryStore. The
--    experience's quota is 1000 + 100 per player a minute: a poll (1 read) every ~50 s and the occasional write use a few of them.
--  * `service` and `clock` are injectable (the tests pass a mock MemoryStoreService and a fake clock).
-- R153 (owner: the best pull is "a local server only thing"): this store is BIGGEST FRUIT's alone. BEST PULL never goes through it: Merge refuses a pull before it counts a request or touches
-- MemoryStore, and a `pull` field that an older server left in the document is ignored (HubDisplayRules.CleanDoc: not read, not kept, not written back).
local Rules=require(game:GetService('ReplicatedStorage'):WaitForChild('HubDisplayRules'))
local S={};S.__index=S
function S.new(opts)
 opts=opts or{}
 local self=setmetatable({Service=opts.Service,Clock=opts.Clock or os.clock,Name=opts.Name or Rules.StoreName,Expiry=opts.Expiry or Rules.ExpirySeconds,
  Failures=0,NextTryAt=0,LastOk=nil,LastError=nil,Throttled=false,Calls={},Requests=0,Disabled=opts.Disabled==true},S)
 return self
end
function S:_service()
 if self.Service then return self.Service end
 local ok,service=pcall(function()return game:GetService('MemoryStoreService')end)
 if ok then self.Service=service end
 return self.Service
end
function S:_map()
 if self.Map then return self.Map end
 local service=self:_service();if not service then return nil,'no MemoryStoreService'end
 local ok,map=pcall(function()return service:GetHashMap(self.Name)end)
 if not ok or not map then return nil,tostring(map)end
 self.Map=map;return map
end
function S.Key(day)return'd'..tostring(math.floor(day))end
-- Whether a request may go out now (not backing off, inside this server's own budget). Returns true, or false and why.
function S:Allowed()
 if self.Disabled then return false,'disabled'end
 local now=self.Clock()
 if now<self.NextTryAt then return false,'backoff'end
 local keep={};for _,at in ipairs(self.Calls)do if now-at<60 then keep[#keep+1]=at end end;self.Calls=keep
 if #self.Calls>=Rules.RequestsPerMinute then return false,'budget'end
 return true
end
function S:_ok()
 self.Failures=0;self.NextTryAt=0;self.LastOk=self.Clock();self.LastError=nil;self.Throttled=false
end
local function throttled(message)
 local s=tostring(message):lower()
 return s:find('throttl',1,true)~=nil or s:find('quota',1,true)~=nil or s:find('429',1,true)~=nil or s:find('too many',1,true)~=nil
end
function S:_fail(message)
 self.Failures+=1;self.LastError=tostring(message):sub(1,160)
 local wait=math.min(Rules.RetryMax,Rules.RetryBase*2^(self.Failures-1))
 self.Throttled=throttled(message)
 if self.Throttled then wait=math.max(wait,Rules.ThrottledWait)end
 self.NextTryAt=self.Clock()+wait
end
local function request(self,fn)
 local allowed,why=self:Allowed();if not allowed then return false,why end
 self.Calls[#self.Calls+1]=self.Clock();self.Requests+=1
 local map,reason=self:_map()
 if not map then self:_fail(reason);return false,reason end
 local ok,a,b=pcall(fn,map)
 if not ok then self:_fail(a);return false,tostring(a)end
 self:_ok();return true,a,b
end
-- Reads a day's document. Returns true, doc (clean: {fruit=?}, empty when the key is missing) or false, reason.
function S:Read(day)
 local ok,value=request(self,function(map)return map:GetAsync(S.Key(day))end)
 if not ok then return false,value end
 return true,Rules.CleanDoc(value)
end
-- Offers a record to the day's document (kind 'Fruit'; R153: a 'Pull' is refused, false 'local only': no request is made; rec = a clean record). The stored one is replaced only when rec is better (checked inside the
-- transform, on the freshest stored value). Returns true, doc, took, foreign  (doc = the document as it is now, took = our record is the stored one, foreign = the stored fruit is of
-- another type than ours: R152, servers on different plant lists have different fruits of the day; neither may replace the other's, so ours is not written) or false, reason.
function S:Merge(day,kind,rec,fruitId)
 if kind~='Fruit'then return false,'local only'end -- (R153: BEST PULL is this server's alone)
 local field='fruit'
 local result
 local ok,final=request(self,function(map)
  local took,foreign=false,false
  local value=map:UpdateAsync(S.Key(day),function(old)
   local doc=Rules.CleanDoc(old)
   local current=doc[field]
   -- a stored fruit of another type than ours is another list's day (R152): never compared (a kg of one fruit says nothing about another) and never replaced; ours stays on this server
   foreign=kind=='Fruit'and current~=nil and current.Id~=rec.Id
   if foreign then took=false;return nil end
   if current and not Rules.Better(kind,rec,current)then took=false;return nil end
   doc[field]=rec;took=true
   return Rules.StoreDoc(doc)
  end,self.Expiry)
  return{Value=value,Took=took,Foreign=foreign}
 end)
 if not ok then return false,final end
 result=final
 if result.Value==nil then return true,nil,false,result.Foreign end -- (cancelled: someone's record is better, or another list's fruit is there; the caller reads it back)
 return true,Rules.CleanDoc(result.Value),result.Took,false
end
-- Deletes a day's document (the owner's `hubdisplays reset`).
function S:Remove(day)
 local ok,value=request(self,function(map)return map:RemoveAsync(S.Key(day))end)
 if not ok then return false,value end
 return true
end
function S:Status()
 return{Disabled=self.Disabled,Failures=self.Failures,LastOk=self.LastOk,LastError=self.LastError,Throttled=self.Throttled,Requests=self.Requests,
  RetryIn=math.max(0,self.NextTryAt-self.Clock())}
end
return S
