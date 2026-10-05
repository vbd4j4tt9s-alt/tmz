-- R151 (owner: "serverwide messages saying who pulled what and so on and a in server announcement"): the shared rules of the pull announcements.
-- Pure functions only (no Instances, no remotes): PullAnnouncer (server) decides and sends, PullAnnouncerClient (client) draws; both read this.
--  * Thresholds   InServerMinRarity (default Legendary: a banner + chat line for everyone in the server) and GlobalMinRarity (default Secret:
--                 Secret, Cosmic, King and anything above, also sent to the other servers). Change either in Studio without touching code: set the
--                 attribute of the same name on this ModuleScript (a rarity name). The other tunables below work the same way (numbers).
--  * Event        one sanitised table {Kind,Id,UserId,Name,SeedId,SeedName,Rarity,Odds,Size,Mutation,Record,At}. The rarity is ALWAYS read from the
--                 seed catalog, never from a message, and the name is cleaned (no markup, no control or direction characters).
--  * Text         the banner line, the chat line, the small line under it, the colours.
--  * Layout       banner sizes for every screen, and where it sits under the notice rows (HudNoticeLayout) clear of the HUD boxes (HudLayout).
--  * Queue        at most MaxWaiting banners wait; when flooded the lowest rarity (then the oldest) goes and the best waiting banner counts "+N more".
--  * Payload      the compact form sent through MessagingService (1 kB limit) and its freshness rule.
local Packs=require(script.Parent.SeedPackRules)
local Names=require(script.Parent.GardenDisplayNames)
local Verity=require(script.Parent.VerityCatalog)
local Odds=require(script.Parent.OddsText85)
local Notice=require(script.Parent.HudNoticeLayout)
local R={Version='R151',Topic='PullAnnounce151',RemoteName='PullAnnounce151'}

-- Tunables ---------------------------------------------------------------------------------------------------------------------------------
R.Defaults={
 InServerMinRarity='Legendary',GlobalMinRarity='Secret',
 BannerSeconds=4,        -- one banner, slide in to slide out
 MaxWaiting=3,           -- banners that may wait behind the one on screen
 WaitSeconds=20,         -- a banner that waited this long is dropped instead of showing late
 ChatBurst=8,ChatWindow=10, -- at most 8 chat lines per 10 seconds on one client
 PublishGapSeconds=5,    -- at most one MessagingService publish per this many seconds per server
 MaxPending=6,           -- global pulls waiting for the next publish
 MaxBytes=900,           -- one message (the Roblox limit is 1,000 bytes)
 StaleSeconds=60,FutureSeconds=30, -- a message older than this, or from this far in the future, is dropped
 ReceiveMaxPerMinute=10, -- global pulls one server will show per minute
 SeenMax=256,SeenSeconds=300, -- remembered message ids (dedupe)
 SubscribeRetrySeconds=5,SubscribeRetryMax=120,
 MaxNameLength=24,
}
R.Limits={BannerSeconds={2,10},MaxWaiting={0,6},WaitSeconds={2,60},ChatBurst={1,30},ChatWindow={1,60},PublishGapSeconds={1,60},MaxPending={1,20},MaxBytes={200,980},
 StaleSeconds={5,600},FutureSeconds={0,300},ReceiveMaxPerMinute={1,60},SeenMax={16,2048},SeenSeconds={30,3600},SubscribeRetrySeconds={1,60},SubscribeRetryMax={5,600},MaxNameLength={8,40}}
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
R.Gold=Color3.fromRGB(255,213,74)   -- other servers (banner frame and chat line)
R.Amber=Color3.fromRGB(255,184,48)  -- records
function R.Hex(color)
 return string.format('#%02X%02X%02X',math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5))
end

-- Seeds and names -----------------------------------------------------------------------------------------------------------------------------
-- {Id,Name,Rarity,Stage} for a seed of the catalog (every roster seed, the Mech seeds and the Verity seed), else nil.
function R.SeedInfo(seedId)
 if type(seedId)~='string'or#seedId>60 then return nil end
 local spec=Packs.SeedDesignById[seedId];if not spec then return nil end
 local rarity=Packs.GetRarity(seedId)
 local name=Verity.Is(seedId)and Verity.SeedName or Names.Plant(seedId,spec.name)
 return {Id=seedId,Name=name,Rarity=rarity,Stage=spec.stage}
end
-- Display names come from Roblox (already filtered); this only makes one safe to print: no markup characters, no control, zero-width or
-- text-direction characters, spaces collapsed, at most MaxNameLength characters. nil when nothing printable is left.
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
 if count>limit then text=text:sub(1,utf8.offset(text,limit+1)-1)end
 return text
end
function R.Escape(text)
 return(tostring(text):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'):gsub("'",'&apos;'))
end

-- Events ----------------------------------------------------------------------------------------------------------------------------------------
R.Kinds={Pull=true,Global=true,Record=true}
R.Mutations={None=true,Gold=true,Diamond=true}
local function number(value,lo,hi)
 if type(value)~='number'or value~=value or value<lo or value>hi then return nil end
 return value
end
-- kind: 'Pull' (a pull in this server), 'Global' (a pull in another server), 'Record' (a hub record taken). fields: Name (required), UserId, Id,
-- SeedId (required for Pull / Global, optional for Record), Odds (the N of "1/N"), Size, Mutation, Record (a key such as BestPull), At.
-- Returns the event, or nil and the reason. The rarity, seed name and mutation key are always derived here.
function R.Event(kind,fields)
 if not R.Kinds[kind]then return nil,'kind'end
 if type(fields)~='table'then return nil,'fields'end
 local name=R.Clean(fields.Name);if not name then return nil,'name'end
 local e={Kind=kind,Name=name,UserId=0,Mutation='None'}
 local uid=number(fields.UserId,0,2^53);if uid and uid%1==0 then e.UserId=uid end
 local id=fields.Id;if type(id)=='string'and#id>=1 and#id<=48 and id:match('^[%w%-_:]+$')then e.Id=id end
 if fields.SeedId~=nil then
  local info=R.SeedInfo(fields.SeedId);if not info then return nil,'seed'end
  e.SeedId,e.SeedName,e.Rarity,e.Stage=info.Id,info.Name,info.Rarity,info.Stage
 elseif kind~='Record'then return nil,'seed'end
 local odds=number(fields.Odds,1,1e15);if odds then e.Odds=odds end
 local size=number(fields.Size,.001,1000);if size then e.Size=math.floor(size*1000+.5)/1000 end
 if type(fields.Mutation)=='string'and R.Mutations[fields.Mutation]then e.Mutation=fields.Mutation end
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
-- A name cut to `limit` characters with an ellipsis (the banner has little room on a phone; the chat line keeps the whole name).
function R.ShortName(name,limit)
 if type(limit)~='number'or utf8.len(name)<=limit then return name end
 return name:sub(1,utf8.offset(name,limit)-1)..'…'
end
-- The emoji, then the sentence. rich = the rarity word in its colour and every part escaped (banner); otherwise plain text. nameLimit (optional) shortens the name.
function R.Line(e,rich,nameLimit)
 local function esc(text)return rich and R.Escape(text)or text end
 local who=R.ShortName(e.Name,nameLimit)
 if e.Kind=='Record'then
  return '🏆 '..esc(who)..' took '..R.RecordTitle(e.Record)..'!'
 end
 local word=string.upper(e.Rarity or'')
 local shown=rich and('<font color="'..R.Hex(R.RarityColor(e.Rarity))..'">'..word..'</font>')or word
 local odds=R.OddsLabel(e.Odds)
 if e.Kind=='Global'then
  return '🌐 '..esc(who)..' pulled '..R.Article(word)..' '..shown..' '..esc(e.SeedName or'seed')..(odds and' ('..odds..')'or'')..'!'
 end
 return '🌟 '..esc(who)..' pulled '..R.Article(word)..' '..shown..' '..esc(e.SeedName or'seed')..'!'..(odds and' ('..odds..')'or'')
end
-- The chat line: rich text. A pull in this server is in its rarity colour, a pull in another server and a record are gold.
function R.Chat(e)
 local color=e.Kind=='Pull'and R.RarityColor(e.Rarity)or e.Kind=='Record'and R.Amber or R.Gold
 return '<font color="'..R.Hex(color)..'">'..R.Line(e,true):gsub('<font color="#%x+">',''):gsub('</font>','')..'</font>'
end
function R.ChatColor(e)return e.Kind=='Pull'and R.RarityColor(e.Rarity)or e.Kind=='Record'and R.Amber or R.Gold end
-- The small line under the sentence (plain text). more = banners that were merged into this one while the queue was flooded. short = leave the biome out (phones).
function R.Subline(e,more,short)
 local parts={};local merged=type(more)=='number'and more>=1 -- (a banner that merged others keeps its small line short)
 if e.Kind=='Global'then parts[#parts+1]='in another server'
 elseif e.Kind=='Record'then
  if e.Rarity then parts[#parts+1]=string.upper(e.Rarity)..' '..(e.SeedName or'')end
  if e.Size and not merged then local ok,text=pcall(function()return require(script.Parent.ItemWeight).Format(e.Size)end);if ok and text~=''then parts[#parts+1]=text end end
  if#parts==0 then parts[1]='congratulations!'end
 else
  local biome=Packs.DesignBiomes[e.Stage or 0]
  if biome and not short then parts[#parts+1]=biome..' seed'end
 end
 if e.Kind~='Record'and e.Mutation and e.Mutation~='None'then parts[#parts+1]=string.upper(e.Mutation)end
 if e.Kind~='Record'and e.Size and e.SeedId and not merged then
  local ok,text=pcall(function()return require(script.Parent.ItemWeight).Text('Seed',e.SeedId,e.Size)end)
  if ok and text~=''then parts[#parts+1]=text end
 end
 if merged then parts[#parts+1]='+'..math.floor(more)..' more'end
 return table.concat(parts,' · ')
end
R.Headlines={[4]='LEGENDARY PULL!',[5]='MYTHIC PULL!!',[6]='SECRET PULL!!!',[7]='COSMIC PULL!!!',[8]='KING PULL!!!!'}
function R.Headline(e)
 if e.Kind=='Record'then return '🏆 NEW RECORD!'end
 local rank=R.Rank(e.Rarity)
 return R.Headlines[rank]or(string.upper(tostring(e.Rarity or'RARE'))..' PULL!')
end
-- Sparkles and the shine sweep by rarity (the banner stays plain for the lower ones); records get the Mythic treatment.
R.Sparkles={[4]=4,[5]=8,[6]=12,[7]=14,[8]=18}
function R.Fx(e)
 local rank=e.Kind=='Record'and 5 or R.Rank(e.Rarity)
 if e.Kind=='Global'then rank=math.min(rank,6)end
 return {Sparkles=R.Sparkles[math.min(rank,8)]or(rank>8 and 18 or 0),Shine=rank>=5,Rank=rank}
end
-- The colour of the frame (and of the studs, the ribbon, the seed tile).
function R.Accent(e)
 if e.Kind=='Pull'then return R.RarityColor(e.Rarity)end
 if e.Kind=='Record'then return R.Amber end
 return R.Gold
end
-- 'Full' for a pull in this server and a record, 'Small' for a pull in another server.
function R.Variant(e)return e.Kind=='Global'and'Small'or'Full'end
function R.Cue(e)
 if e.Kind=='Global'then return {Key='Chime',Pitch=.9,Volume=.09}end
 return {Rank=e.Kind=='Record'and 5 or math.max(4,R.Rank(e.Rarity))}
end

-- Queue -----------------------------------------------------------------------------------------------------------------------------------------
function R.Priority(e)
 if e.Kind=='Record'then return 100 end
 return R.Rank(e.Rarity)+(e.Kind=='Pull'and .5 or 0)
end
function R.NewQueue()return {Items={},Dropped=0,Serial=0}end
-- Returns true when the new banner is waiting (false when it was the one dropped).
function R.Enqueue(q,e,now)
 local max=R.Setting('MaxWaiting')
 q.Serial+=1;local item={Event=e,At=now or 0,Serial=q.Serial,More=0}
 if max<=0 then q.Dropped+=1;return false end
 table.insert(q.Items,item)
 if#q.Items<=max then return true end
 local worst=1
 for i=2,#q.Items do
  local a,b=q.Items[i],q.Items[worst];local pa,pb=R.Priority(a.Event),R.Priority(b.Event)
  if pa<pb or(pa==pb and a.Serial<b.Serial)then worst=i end
 end
 local gone=table.remove(q.Items,worst);q.Dropped+=1
 local best
 for _,it in ipairs(q.Items)do if not best or R.Priority(it.Event)>R.Priority(best.Event)then best=it end end
 if best then best.More+=1+gone.More end
 return gone~=item
end
-- The next banner that is still worth showing (one that waited longer than WaitSeconds is dropped).
function R.Dequeue(q,now)
 local limit=R.Setting('WaitSeconds')
 while#q.Items>0 do
  local item=table.remove(q.Items,1)
  if now==nil or now-item.At<=limit then return item end
  q.Dropped+=1
 end
 return nil
end
-- Slide in, hold, slide out: BannerSeconds in all (4 s). A backlog shortens the hold; ReducedMotion has no slide, so it holds the whole time.
function R.Timing(waiting,reduced)
 local total=R.Setting('BannerSeconds')
 local slideIn,slideOut=.38,.3;if reduced then slideIn,slideOut=0,0 end
 local hold=math.max(1.2,total-slideIn-slideOut)
 if waiting>=2 then hold=math.max(1.2,hold*.6)elseif waiting==1 then hold=math.max(1.5,hold*.8)end
 return {In=slideIn,Hold=hold,Out=slideOut,Gap=.12}
end

-- Chat rate limit (pure): log = a list of times, returns true when another line may be posted at now.
function R.ChatAllowed(log,now)
 local window,burst=R.Setting('ChatWindow'),R.Setting('ChatBurst')
 for i=#log,1,-1 do if now-log[i]>window then table.remove(log,i)end end
 if#log>=burst then return false end
 log[#log+1]=now;return true
end

-- Layout ----------------------------------------------------------------------------------------------------------------------------------------
-- Sizes in pixels for a w x h screen (the CoreUISafeInsets area). variant 'Full' (ribbon, avatar, seed picture) or 'Small' (other servers).
-- Overhang = the part of the ribbon above the panel; Pad = the panel's inner margin. A banner is never wider than the notice rows (HudNoticeLayout:
-- the screen minus 24, or 44% on short landscape screens).
function R.Metrics(w,h,variant)
 local compact=h<480;local narrow=w<460
 local maxW=compact and math.max(200,w*.44)or w-24
 local m={Variant=variant,Compact=compact,Narrow=narrow}
 if variant=='Small'then
  m.Width=math.floor(math.min(compact and 360 or 460,maxW))
  m.Height=compact and 46 or 58
  m.Overhang,m.RibbonH,m.RibbonW=0,0,0
  m.Pad=compact and 5 or 8
  m.Avatar=compact and 28 or narrow and 34 or 40;m.Pic=compact and 30 or narrow and 38 or 44
  m.L1Max=compact and 11 or narrow and 13 or 15;m.L1Min=9;m.L2Size=compact and 9 or 11
  m.L2H=compact and 11 or 14
  m.NameChars=(compact or narrow)and 14 or 20
 else
  m.Width=math.floor(math.min(compact and 420 or 560,maxW))
  m.Height=compact and 62 or narrow and 78 or 86
  m.Overhang=compact and 8 or 12;m.RibbonH=compact and 16 or 24
  m.RibbonW=math.floor(math.min(compact and 150 or 230,m.Width-(compact and 70 or 110)))
  m.Pad=compact and 6 or narrow and 8 or 10
  m.Avatar=compact and 34 or narrow and 46 or 56;m.Pic=compact and 38 or narrow and 54 or 66
  m.L1Max=compact and 12 or narrow and 15 or 18;m.L1Min=compact and 9 or 11;m.L2Size=compact and 9 or narrow and 11 or 13
  m.L2H=compact and 11 or narrow and 14 or 16
  m.NameChars=(compact or narrow)and 14 or 20
 end
 if m.Width<320 then m.Avatar=0 end -- very narrow: the headshot goes, the sentence keeps the room
 m.Short=compact or narrow -- the small line leaves the biome out
 m.Box=4 -- breathing room around the panel for its outline (the root frame is the panel plus this on every side)
 return m
end
-- Panel-relative rectangles of the parts: Avatar, Text (line 1 + line 2), Pic, Ribbon (relative to the panel; Y may be negative).
function R.Inner(m)
 local pad,gap=m.Pad,m.Compact and 5 or 8
 local inside=m.RibbonH-m.Overhang -- the ribbon's part inside the panel
 local top=inside>0 and inside+(m.Compact and 2 or 3)or pad
 local r={Panel={X=0,Y=0,W=m.Width,H=m.Height}}
 local left=pad
 if m.Avatar>0 then r.Avatar={X=pad,Y=math.floor((m.Height-m.Avatar)/2+.5),W=m.Avatar,H=m.Avatar};left=pad+m.Avatar+gap end
 local right=m.Width-pad
 if m.Pic>0 then r.Pic={X=m.Width-pad-m.Pic,Y=math.floor((m.Height-m.Pic)/2+.5),W=m.Pic,H=m.Pic};right=r.Pic.X-gap end
 local avail=m.Height-top-pad-m.L2H-2
 r.Line1={X=left,Y=top,W=math.max(1,right-left),H=math.max(8,avail)}
 r.Line2={X=left,Y=top+r.Line1.H+2,W=r.Line1.W,H=m.L2H}
 if m.RibbonH>0 then r.Ribbon={X=math.floor((m.Width-m.RibbonW)/2),Y=-m.Overhang,W=m.RibbonW,H=m.RibbonH}end
 return r
end
-- Where the banner goes: below the first notice row (HudNoticeLayout, given top = the bottom of the top bar / tutorial card) and clear of the HUD boxes. On a portrait phone the
-- balances and the status stack fill the top right; dodging them would put a full-width banner a third of the way down, so then it sits at the top over those readouts for its
-- 4 seconds (as the notice rows already do) and only keeps clear of the boxes that are buttons or controls. Returns the PANEL rectangle {X,Y,W,H} plus Top / Bottom of the whole
-- banner (the ribbon overhang included). boxes = HudLayout.HudBoxes(...) (may be nil).
R.SoftBoxes={WalletSpeed=true,WalletCash=true,WalletGem=true,Status=true}
function R.Place(w,h,top,boxes,m)
 local first=Notice.Calculate(w,h,top or 0,{}).Bottom
 local x=math.floor((w-m.Width)/2)
 local function run(list)
  local y=first+m.Overhang
  for _=1,#list+1 do
   local moved=false
   for _,b in ipairs(list)do
    if b.Y+b.H<=h*.6 and x<b.X+b.W+4 and x+m.Width>b.X-4 and y-m.Overhang<b.Y+b.H+4 and y+m.Height>b.Y-4 then y=b.Y+b.H+6+m.Overhang;moved=true end
   end
   if not moved then break end
  end
  return y
 end
 local all=boxes or{};local hard={}
 for _,b in ipairs(all)do if not R.SoftBoxes[b.N]then hard[#hard+1]=b end end
 local y=run(all)
 if y+m.Height>math.max(h*.3,first+m.Overhang+m.Height+48)then y=run(hard)end
 y=math.min(y,math.max(m.Overhang,h-m.Height-8))
 return {X=x,Y=y,W=m.Width,H=m.Height,Top=y-m.Overhang,Bottom=y+m.Height}
end

-- Payload (MessagingService) ---------------------------------------------------------------------------------------------------------------------------
-- A pull as it travels: short keys. Odds go as a whole number (the N of 1/N), the size to 3 decimals.
function R.Compact(e)
 return {i=e.Id,u=e.UserId,n=e.Name,s=e.SeedId,r=e.Rarity,o=e.Odds and math.floor(e.Odds+.5)or nil,z=e.Size,m=(e.Mutation~='None')and e.Mutation or nil}
end
-- The fields table for R.Event('Global', ...) from one compact entry (nil when it is not a table).
function R.Expand(t)
 if type(t)~='table'then return nil end
 return {Id=t.i,UserId=t.u,Name=t.n,SeedId=t.s,Odds=t.o,Size=t.z,Mutation=t.m}
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
