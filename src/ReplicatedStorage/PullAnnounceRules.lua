-- R151 (owner: "serverwide messages saying who pulled what and so on and a in server announcement"; then: "pull announcement should only be said in chat"): the shared rules
-- of the pull announcements. They are CHAT LINES only: no banner, no sound, no picture. Pure functions only (no Instances, no remotes): PullAnnouncer (server) decides
-- and sends, PullAnnouncerClient (client) writes the chat line; both read this.
--  * Thresholds   InServerMinRarity (default Legendary: a chat line for everyone in the server) and GlobalMinRarity (default Secret: Secret, Cosmic, King and anything
--                 above, also sent to the other servers). Change either in Studio without touching code: set the attribute of the same name on this ModuleScript (a
--                 rarity name). The other tunables below work the same way (numbers).
--  * Event        one sanitised table {Kind,Id,UserId,Name,SeedId,SeedName,Rarity,Odds,Record,At}. The rarity is ALWAYS read from the seed catalog, never from a
--                 message, and the name is cleaned (no markup, control or direction characters; at most MaxNameLength characters, a longer one ends with an
--                 ellipsis). On top of that every part of a line (name, seed, record title) is ESCAPED when it is written as rich text (R.Escape).
--  * Text         the three chat lines (a pull here, a pull in another server, a record) and their colours.
--  * Chat limit   at most ChatBurst lines per ChatWindow seconds on one client.
--  * Payload      the compact form sent through MessagingService (1 kB limit) and its freshness rule.
--  * Timing       RevealDelay: when a line about a pull may go out, so it never reaches the puller before THEIR reveal has shown the seed (derived from RarePullRules, the
--                 tables the puller's client plays: one source of truth). RecordScope: who hears a hub record (this server, every server, or nobody).
local Packs=require(script.Parent.SeedPackRules)
local Names=require(script.Parent.GardenDisplayNames)
local Verity=require(script.Parent.VerityCatalog)
local Odds=require(script.Parent.OddsText85)
local R={Version='R151',Topic='PullAnnounce151',RemoteName='PullAnnounce151'}

-- Tunables ---------------------------------------------------------------------------------------------------------------------------------
R.Defaults={
 InServerMinRarity='Legendary',GlobalMinRarity='Secret',
 ChatBurst=8,ChatWindow=10, -- at most 8 chat lines per 10 seconds on one client
 PublishGapSeconds=5,    -- at most one MessagingService publish per this many seconds per server
 MaxPending=6,           -- global pulls waiting for the next publish
 MaxBytes=900,           -- one message (the Roblox limit is 1,000 bytes)
 StaleSeconds=60,FutureSeconds=30, -- a message older than this, or from this far in the future, is dropped
 ReceiveMaxPerMinute=10, -- global pulls one server will show per minute
 SeenMax=256,SeenSeconds=300, -- remembered message ids (dedupe)
 SubscribeRetrySeconds=5,SubscribeRetryMax=120,
 MaxNameLength=24,
 RevealMargin=.5,        -- seconds after the puller's reveal has shown the seed before the line goes out (network jitter, a frame or two, time to read the card)
 RecordLag=.4,           -- a record line follows the pull line of the same pull by this much (the pull line first)
}
R.Limits={ChatBurst={1,30},ChatWindow={1,60},PublishGapSeconds={1,60},MaxPending={1,20},MaxBytes={200,980},
 StaleSeconds={5,600},FutureSeconds={0,300},ReceiveMaxPerMinute={1,60},SeenMax={16,2048},SeenSeconds={30,3600},SubscribeRetrySeconds={1,60},SubscribeRetryMax={5,600},MaxNameLength={8,40},
 RevealMargin={0,5},RecordLag={0,5}}
function R.Setting(name)
 local default=R.Defaults[name];local value=script:GetAttribute(name)
 if type(default)=='string'then return(type(value)=='string'and Packs.Rarities[value]~=nil)and value or default end
 local limit=R.Limits[name]
 if type(value)=='number'and value==value and(not limit or(value>=limit[1]and value<=limit[2]))then return value end
 return default
end

-- Rarity ------------------------------------------------------------------------------------------------------------------------------------
function R.Rank(rarity)local r=type(rarity)=='string'and Packs.Rarities[rarity];return r and r.Rank or 0 end
-- scope 'InServer' | 'Global'. Unknown rarities never qualify; a rarity above King (a future one) does, because only its Rank counts.
function R.Qualifies(scope,rarity)
 local rank=R.Rank(rarity);if rank<=0 then return false end
 return rank>=R.Rank(R.Setting(scope=='Global'and'GlobalMinRarity'or'InServerMinRarity'))
end
function R.RarityColor(rarity)
 local r=type(rarity)=='string'and Packs.Rarities[rarity]
 return r and r.Color or Color3.fromRGB(223,236,242)
end
R.Gold=Color3.fromRGB(255,213,74)   -- other servers (the chat line)
R.Amber=Color3.fromRGB(255,184,48)  -- records
function R.Hex(color)
 return string.format('#%02X%02X%02X',math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5))
end

-- Timing ------------------------------------------------------------------------------------------------------------------------------------------
-- A line about a pull must not reach the PULLER before their own reveal has shown the seed, and nobody else gets it earlier than that either. RevealDelay(rarity) = seconds from
-- the moment the server opens the pack (PlayerDataService:OpenSeedPack, the same moment as RevealAt: no yield lies between) until the line may go out:
-- RarePullRules.LatestSeedShown(rank) (the ladder card for Common..Mythic, the story scene for Secret / Cosmic / King, whichever presentation the puller's client picks: those are
-- the very tables the client plays) plus RevealMargin. A skipped reveal only shows the seed sooner, so the normal time is still after it. If RarePullRules cannot load, the old
-- reveal length (SeedPackRules.GetRevealDuration) is what the client plays too (its fallback presentation), so that is used.
local okReveal,Reveal=pcall(require,script.Parent.RarePullRules)
function R.RevealDelay(rarity)
 local style=type(rarity)=='string'and Packs.Rarities[rarity]
 local rank=style and style.Rank or 1 -- (an unknown rarity is never announced; this only keeps the function total)
 local shown
 if okReveal and type(Reveal)=='table'and Reveal.LatestSeedShown then
  local ok,t=pcall(Reveal.LatestSeedShown,rank);shown=ok and type(t)=='number'and t==t and t or nil
 end
 if not shown then local ok,t=pcall(Packs.GetRevealDuration,rarity);shown=ok and type(t)=='number'and t or 5 end
 return shown+R.Setting('RevealMargin')
end

-- Who hears a hub record (BEST PULL / BIGGEST FRUIT) ----------------------------------------------------------------------------------------------
-- Returns 'Global' (this server and every other), 'InServer' (this server), or nil (nobody: the hub display changes, the chat says nothing). rarity = the rarity of the seed
-- the record is about (nil when it names none).
--  * BestPull is a pull: the pull's own rarity decides with the same thresholds as the pull line: GlobalMinRarity and above everywhere (Secret, Cosmic, King), InServerMinRarity and
--    above in this server (Legendary, Mythic), below that nothing (the first Commons of a day only move the display).
--  * any other record (BiggestFruit): this server, never the others; a fruit's weight has no pull rarity.
--  * a BestPull that names no seed (the owner's `announce record`): this server.
function R.RecordScope(record,rarity)
 if record~='BestPull'then return'InServer'end
 if rarity==nil then return'InServer'end
 if R.Qualifies('Global',rarity)then return'Global'end
 if R.Qualifies('InServer',rarity)then return'InServer'end
 return nil
end

-- Seeds and names -----------------------------------------------------------------------------------------------------------------------------
-- {Id,Name,Rarity} for a seed of the catalog (every roster seed, the Mech seeds and the Verity seed), else nil.
function R.SeedInfo(seedId)
 if type(seedId)~='string'or#seedId>60 then return nil end
 local spec=Packs.SeedDesignById[seedId];if not spec then return nil end
 local rarity=Packs.GetRarity(seedId)
 local name=Verity.Is(seedId)and Verity.SeedName or Names.Plant(seedId,spec.name)
 return {Id=seedId,Name=name,Rarity=rarity}
end
-- Display names come from Roblox (already filtered); this only makes one safe to print: no markup characters, no control, zero-width or
-- text-direction characters, spaces collapsed, at most MaxNameLength characters (a longer name is cut and ends with an ellipsis). nil when nothing printable is left.
local function hidden(cp)
 return cp<32 or cp==127 or(cp>=0x80 and cp<=0x9F)or(cp>=0x200B and cp<=0x200F)or(cp>=0x202A and cp<=0x202E)or(cp>=0x2060 and cp<=0x2069)or cp==0xFEFF or cp==0xFFFC
end
function R.Clean(name,limit)
 if type(name)~='string'or#name>200 or not utf8.len(name)then return nil end
 limit=limit or R.Setting('MaxNameLength')
 local out={}
 for _,cp in utf8.codes(name)do
  if cp==60 or cp==62 or cp==38 or cp==34 or cp==39 then -- < > & " '
  elseif hidden(cp)then out[#out+1]=' '
  else out[#out+1]=utf8.char(cp)end
 end
 local text=table.concat(out):gsub('%s+',' ');text=text:match('^%s*(.-)%s*$')
 if text==''then return nil end
 local count=utf8.len(text)
 if count>limit then
  text=text:sub(1,utf8.offset(text,limit)-1):gsub('%s+$','')..'…' -- (limit-1 characters, then the ellipsis: `limit` in all; a space before the cut is dropped)
 end
 return text
end
function R.Escape(text)
 return(tostring(text):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'):gsub("'",'&apos;'))
end

-- Events ----------------------------------------------------------------------------------------------------------------------------------------
R.Kinds={Pull=true,Global=true,Record=true}
local function number(value,lo,hi)
 if type(value)~='number'or value~=value or value<lo or value>hi then return nil end
 return value
end
-- kind: 'Pull' (a pull in this server), 'Global' (a pull in another server), 'Record' (a hub record taken). fields: Name (required), UserId, Id,
-- SeedId (required for Pull / Global, optional for Record), Odds (the N of "1/N"), Record (a key such as BestPull), At.
-- Returns the event, or nil and the reason. The rarity and the seed name are always derived here.
function R.Event(kind,fields)
 if not R.Kinds[kind]then return nil,'kind'end
 if type(fields)~='table'then return nil,'fields'end
 local name=R.Clean(fields.Name);if not name then return nil,'name'end
 local e={Kind=kind,Name=name,UserId=0}
 local uid=number(fields.UserId,0,2^53);if uid and uid%1==0 then e.UserId=uid end
 local id=fields.Id;if type(id)=='string'and#id>=1 and#id<=48 and id:match('^[%w%-_:]+$')then e.Id=id end
 if fields.SeedId~=nil then
  local info=R.SeedInfo(fields.SeedId);if not info then return nil,'seed'end
  e.SeedId,e.SeedName,e.Rarity=info.Id,info.Name,info.Rarity
 elseif kind~='Record'then return nil,'seed'end
 local odds=number(fields.Odds,1,1e15);if odds then e.Odds=odds end
 if kind=='Record'then
  local key=fields.Record
  e.Record=(type(key)=='string'and#key>=1 and#key<=24 and key:match('^%a+$'))and key or'Record'
 end
 local at=number(fields.At,0,2^40);if at then e.At=math.floor(at)end
 return e
end

-- Text --------------------------------------------------------------------------------------------------------------------------------------------
R.Records={BestPull='BEST PULL TODAY',BiggestFruit='BIGGEST FRUIT TODAY',Record='A NEW RECORD'}
function R.RecordTitle(key)
 if R.Records[key]then return R.Records[key]end
 return string.upper((tostring(key):gsub('(%l)(%u)','%1 %2')))
end
function R.Article(word)return tostring(word):match('^[AEIOUaeiou]')and'an'or'a'end
function R.OddsLabel(odds)
 if type(odds)~='number'or odds~=odds or odds<1 then return nil end
 return '1/'..Odds.Count(odds)
end
-- The sentence: the emoji, then who and what. rich = for rich text (every part escaped, the rarity word in bold); otherwise plain text.
--   a pull in this server   🌟 Ann pulled a MYTHIC Fire Pepper! (1/800)
--   a pull in another one   🌐 Ann pulled a SECRET Obsidian Maw (1/1,000)!
--   a record                🏆 Ann took BEST PULL TODAY!
function R.Line(e,rich)
 local function esc(text)return rich and R.Escape(text)or tostring(text)end
 local who=esc(e.Name)
 if e.Kind=='Record'then
  return '🏆 '..who..' took '..esc(R.RecordTitle(e.Record))..'!'
 end
 local word=string.upper(e.Rarity or'')
 local shown=rich and('<b>'..esc(word)..'</b>')or word
 local seed=esc(e.SeedName or'seed')
 local odds=R.OddsLabel(e.Odds)
 if e.Kind=='Global'then
  return '🌐 '..who..' pulled '..R.Article(word)..' '..shown..' '..seed..(odds and' ('..odds..')'or'')..'!'
 end
 return '🌟 '..who..' pulled '..R.Article(word)..' '..shown..' '..seed..'!'..(odds and' ('..odds..')'or'')
end
-- The colour of the whole line: the rarity's own for a pull in this server, gold for a pull in another server, amber for a record.
function R.ChatColor(e)return e.Kind=='Pull'and R.RarityColor(e.Rarity)or e.Kind=='Record'and R.Amber or R.Gold end
-- The chat line as rich text: one colour run around the escaped sentence (TextChatService: RBXGeneral:DisplaySystemMessage).
function R.Chat(e)
 return '<font color="'..R.Hex(R.ChatColor(e))..'">'..R.Line(e,true)..'</font>'
end
-- The same line for the old chat (plain text, coloured by the message itself). Nothing in it can be read as markup: < and > are dropped.
function R.Plain(e)
 return(R.Line(e,false):gsub('[<>]',''))
end

-- Chat rate limit (pure): log = a list of times, returns true when another line may be posted at now.
function R.ChatAllowed(log,now)
 local window,burst=R.Setting('ChatWindow'),R.Setting('ChatBurst')
 for i=#log,1,-1 do if now-log[i]>window then table.remove(log,i)end end
 if#log>=burst then return false end
 log[#log+1]=now;return true
end

-- Payload (MessagingService) ---------------------------------------------------------------------------------------------------------------------------
-- A pull (or a record) as it travels: short keys. Odds go as a whole number (the N of 1/N). (The rarity travels as a label only; a receiver always re-reads it from its own
-- catalog.) k = the record key of a Record (BestPull ...): present only for a record, so a receiver tells the two apart.
function R.Compact(e)
 return {i=e.Id,u=e.UserId,n=e.Name,s=e.SeedId,r=e.Rarity,o=e.Odds and math.floor(e.Odds+.5)or nil,k=e.Kind=='Record'and e.Record or nil}
end
-- The fields table for R.Event('Global' | 'Record', ...) from one compact entry (nil when it is not a table). A Record key is read as a string only.
function R.Expand(t)
 if type(t)~='table'then return nil end
 return {Id=t.i,UserId=t.u,Name=t.n,SeedId=t.s,Odds=t.o,Record=type(t.k)=='string'and t.k or nil}
end
-- The longest prefix of list (events) whose message fits MaxBytes. encode = HttpService.JSONEncode (a function taking the table).
-- Returns the message text and how many events it carries (0 when even one does not fit).
function R.Batch(list,jobId,now,encode)
 local limit=R.Setting('MaxBytes');local used=0;local entries={};local best,bestCount
 for i,e in ipairs(list)do
  entries[i]=R.Compact(e)
  local ok,text=pcall(encode,{v=1,j=jobId,t=now,p=entries})
  if not ok or type(text)~='string'or#text>limit then entries[i]=nil;break end
  best,bestCount=text,i
 end
 return best,bestCount or 0
end
-- Is a message sent at 'sent' (unix seconds) still worth showing at 'now'?
function R.Fresh(sent,now)
 if type(sent)~='number'or sent~=sent then return false end
 local age=now-sent
 return age<=R.Setting('StaleSeconds')and age>=-R.Setting('FutureSeconds')
end
return R
