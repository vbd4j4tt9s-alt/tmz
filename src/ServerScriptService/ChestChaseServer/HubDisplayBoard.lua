-- R151: what one server knows about the two hub boards (BEST PULL and BIGGEST FRUIT). Pure bookkeeping, no Roblox services: the Service feeds
-- it events and MemoryStore reads and writes, and builds the displays from what it says.
-- For each board (kind 'Pull' | 'Fruit') three slots, each a record or nil:
--    Remote  the best the shared store last told us (everyone's; only BIGGEST FRUIT has one);
--    Local   the best real pull / harvest this server saw (today for the fruit, in this window for the pull);
--    Test    an owner-injected one (/test bestpull, /test bigfruit): shown on this server only, never sent anywhere.
-- Best(kind) = the best of the three, by HubDisplayRules ordering. A FRUIT board needs a shared write while its Local record is better than the Remote one (Unsynced): the
-- Service writes it (compare-and-set: the store only takes it when it is better than what is there) and, whatever the answer, reads the winner back with MergeRemote.
-- R152: Foreign = the shared fruit is of ANOTHER type than this server's fruit of the day (servers on different plant lists, around an update that adds plants): that board has nothing to
-- write (the store holds another list's fruit, which is never replaced) so it is not Unsynced.
-- R153 (owner: the best pull is "a local server only thing" that "refresh every 10 minutes"): the PULL board is this server's alone. It has no Remote (MergeRemote ignores it) and is never
-- Unsynced, so nothing about it can reach a store. It has its own clock: Window (HubDisplayRules.PullWindowIndex: wall-clock 10-minute windows); a new window empties it (SetWindow), all three
-- slots, as on a fresh server. A new day (SetDay) empties the FRUIT board only. Nothing here can throw on bad input: records are cleaned by the caller (HubDisplayRules.CleanPull / CleanFruit).
local Rules=require(game:GetService('ReplicatedStorage'):WaitForChild('HubDisplayRules'))
local B={};B.__index=B
local KINDS={'Pull','Fruit'}
B.Kinds=KINDS
local function fresh()return{Remote=nil,Local=nil,Test=nil,Foreign=false}end
function B.new()
 return setmetatable({Day=nil,FruitId=nil,Window=nil,Boards={Pull=fresh(),Fruit=fresh()}},B)
end
-- Starts a day (a new day number, or the same day with another fruit): clears the FRUIT board (R153: the pull board has its own clock). Returns true when anything changed.
function B:SetDay(day,fruitId)
 if self.Day==day and self.FruitId==fruitId then return false end
 self.Day=day;self.FruitId=fruitId;self.Boards.Fruit=fresh()
 return true
end
-- R153: starts a pull window (HubDisplayRules.PullWindowIndex): clears the PULL board, whatever it held (this server's best, an injected test pull). Returns true when the window changed.
function B:SetWindow(window)
 if self.Window==window then return false end
 self.Window=window;self.Boards.Pull=fresh()
 return true
end
local function valid(kind)return kind=='Pull'or kind=='Fruit'end
-- The champion of a board and where it came from ('Remote' | 'Local' | 'Test'), or nil.
function B:Best(kind)
 if not valid(kind)then return nil end
 local b=self.Boards[kind];local best,source
 for _,slot in ipairs({'Remote','Local','Test'})do
  local rec=b[slot]
  if rec and Rules.Better(kind,rec,best)then best,source=rec,slot end
 end
 return best,source
end
-- The best of what this server saw itself (the record a shared write carries).
function B:LocalBest(kind)
 if not valid(kind)then return nil end
 return self.Boards[kind].Local
end
-- An event of this server. Returns 'took' (it is now the champion), 'kept' (it was recorded as this server's best but someone's is better), or 'ignored' (worse than
-- this server's own best, or not a record).
function B:Offer(kind,rec)
 if not valid(kind)or type(rec)~='table'then return'ignored'end
 if kind=='Fruit'and self.FruitId~=nil and rec.Id~=self.FruitId then return'ignored'end -- (not today's fruit)
 local b=self.Boards[kind];local slot=rec.Test and'Test'or'Local'
 if not Rules.Better(kind,rec,b[slot])then return'ignored'end
 b[slot]=rec
 return self:Best(kind)==rec and'took'or'kept'
end
-- What the shared store says (a clean record or nil). Replaces the Remote slot. A fruit of another type than today's is not today's board: ignored (and the board is Foreign).
-- R153: only the fruit board has a shared record; whatever is offered for the pull board is ignored (a pull is this server's own).
function B:MergeRemote(kind,rec)
 if kind~='Fruit'then return false end
 local b=self.Boards[kind]
 b.Foreign=rec~=nil and kind=='Fruit'and self.FruitId~=nil and rec.Id~=self.FruitId
 if b.Foreign then rec=nil end
 local before=Rules.Key(b.Remote)
 b.Remote=rec
 return Rules.Key(rec)~=before
end
-- R152: the store refused to take our record because it holds another list's fruit (HubDisplayStore:Merge answered Foreign): this board stays on this server until a read says otherwise.
function B:SetForeign(kind)
 if valid(kind)and kind=='Fruit'then self.Boards[kind].Foreign=true end
end
-- Local is better than what the store holds: it needs writing (not while the store holds another list's fruit: nothing can be written there). R153: never for the pull board.
function B:Unsynced(kind)
 if kind~='Fruit'then return false end
 local b=self.Boards[kind]
 return b.Local~=nil and not b.Foreign and Rules.Better(kind,b.Local,b.Remote)
end
-- Forgets this server's own records and the owner's injected ones (the shared store's answer stays).
function B:ClearLocal()
 for _,kind in ipairs(KINDS)do local b=self.Boards[kind];b.Local=nil;b.Test=nil end
end
function B:Clear()
 self.Boards={Pull=fresh(),Fruit=fresh()}
end
return B
