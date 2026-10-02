-- R123: treadmill bonus rolls (owner request). Pure rules shared by TreadmillBonusService (server, authoritative)
-- and TreadmillBonusClient (button + crate-style roll strip). Nothing here reads luck, boots, passes or boosts.
--
-- Earning: every 10 minutes of treadmill training (BaseService.TrainingSessions, server side) makes one bonus roll
-- READY. Leaving the treadmill pauses progress; back on within 60 s keeps it, off for more than 60 s (or leaving the
-- game) resets it to 0. Unspent READY rolls are saved (max 5); training progress is session-only. At 5 ready rolls
-- the timer stops until one is used. Clicking the button asks the server to roll: it picks the rarity, adds the pack
-- to the seed bag at once (never lost if the player leaves mid-animation) and the client only animates the result.
--
-- Bonus roll odds (rarity of the seed inside the pack; no Common; luck-free; same for everyone):
--   Rarity      Bonus roll        Normal Forest pack (PackOdds112 Pack01, no boots), for comparison
--   Uncommon    65%               25%
--   Rare        32.4899%          12.5%
--   Legendary   2%                3.333%   (reduced)
--   Mythic      0.5%              0.5%
--   Secret      0.01%  (1/10K)    0.01%    (kept at the base pack's tiny chance, never boosted)
--   Cosmic      0.0001% (1/1M)    0.0001%
--   King        1e-10% (1/1T)     1e-10%
--   Common      0%                58.66%
-- Rare takes whatever the other rows leave (1 - all others). A biome with no seed of a rolled tier passes that
-- tier's share up to the next tier it has (Uncommon -> Rare -> Legendary -> Mythic, as PackOdds112 does); a missing
-- Secret/Cosmic/King share goes to the biome's lowest bonus tier. The pack's biome is the player's CURRENT treadmill
-- machine (Trail Runner = Forest ... Thunder Runner = Storm). Opening the pack picks one seed of the rolled rarity
-- from that biome, evenly.
local N=require(script.Parent.PackOdds112)
local B={Version=123,IntervalSeconds=600,GraceSeconds=60,MaxReady=5,RollCooldown=1,RemoteName='TreadmillBonusRoll'}
B.Order={'Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
B.Rank={};for i,t in ipairs(B.Order)do B.Rank[t]=i end
B.Odds={Uncommon=.65,Legendary=.02,Mythic=.005,Secret=1e-4,Cosmic=1e-6,King=1e-12}
B.Odds.Rare=1-B.Odds.Uncommon-B.Odds.Legendary-B.Odds.Mythic-B.Odds.Secret-B.Odds.Cosmic-B.Odds.King
-- Pack look per rolled rarity (SeedPackRules.GetPackTier: Design 2 = Uncommon, 3 = Rare, 5 = Legendary, 6 = Mythic).
B.Variants={Uncommon='Pack02',Rare='Pack03',Legendary='Pack05',Mythic='Pack06',Secret='Pack06',Cosmic='Pack06',King='Pack06'}
-- Player attributes the server publishes (client reads only).
B.Attr={Ready='TreadmillBonusReady',DueAt='TreadmillBonusDueAt',Paused='TreadmillBonusPausedLeft',Interval='TreadmillBonusInterval'}
function B.IsTier(t)return type(t)=='string'and B.Rank[t]~=nil end
function B.ReadyCount(v)
 if type(v)~='number'or v~=v or math.abs(v)==math.huge then return 0 end
 return math.clamp(math.floor(v),0,B.MaxReady)
end
-- present: set of rarities that have at least one seed in the biome. Returns {tier = probability}, summing to 1.
function B.TierOdds(present)
 local out={};local leftover=0;local lowest
 for _,t in ipairs(B.Order)do if present[t]then lowest=t;break end end
 if not lowest then return nil end
 for i,t in ipairs(B.Order)do
  local p=B.Odds[t]
  if present[t]then out[t]=(out[t]or 0)+p
  elseif i<=B.Rank.Mythic then
   local moved=false
   for j=i+1,B.Rank.Mythic do local up=B.Order[j];if present[up]then out[up]=(out[up]or 0)+p;moved=true;break end end
   if not moved then leftover+=p end
  else leftover+=p end
 end
 if leftover>0 then out[lowest]=(out[lowest]or 0)+leftover end
 return out
end
function B.Present(pool,getRarity)
 local present={};for _,seed in ipairs(pool or{})do present[(getRarity(seed.Id))]=true end;return present
end
function B.PoolOdds(pool,getRarity)return B.TierOdds(B.Present(pool,getRarity))end
-- Exact staged roll (King is 1 in 1T): draw() returns a uniform number in [0,1).
function B.RollTier(odds,draw)return N.RollTier(odds,draw)end
local function drawFrom(draw)
 if type(draw)=='function'then return draw end
 local n=type(draw)=='number'and draw==draw and draw or .5
 return function()return n end
end
-- Opening a bonus pack: one seed of the rolled tier, evenly. If the biome lost that tier, the nearest tier above
-- (then below) that it has.
function B.RollSeed(pool,getRarity,tier,draw)
 draw=drawFrom(draw);if not B.IsTier(tier)then return nil end
 local by={};for _,seed in ipairs(pool or{})do local t=getRarity(seed.Id);by[t]=by[t]or{};table.insert(by[t],seed)end
 local list=by[tier]
 if not list then for i=B.Rank[tier]+1,#B.Order do list=by[B.Order[i]];if list then break end end end
 if not list then for i=B.Rank[tier]-1,1,-1 do list=by[B.Order[i]];if list then break end end end
 if not list then return nil end
 local u=draw();u=type(u)=='number'and u==u and u or 0
 local seed=list[math.clamp(math.floor(u*#list)+1,1,#list)]
 return seed,(getRarity(seed.Id))
end
-- {seedId = percent} for a bonus pack of this tier (pack tooltip).
function B.SeedOdds(pool,getRarity,tier)
 local list={};for _,seed in ipairs(pool or{})do if getRarity(seed.Id)==tier then table.insert(list,seed)end end
 local out={};for _,seed in ipairs(list)do out[seed.Id]=100/#list end;return out
end
function B.Percent(p)
 local v=p*100
 if v>=1 then return(string.format('%.2f',v):gsub('%.?0+$',''))..'%'end
 if v>=.0001 then return(string.format('%.4f',v):gsub('%.?0+$',''))..'%'end
 return '1 in '..string.format('%.0f',1/p)
end
-- Roll strip (crate style) -------------------------------------------------------------------------------------
B.Strip={Count=46,Win=40,Pitch=112,CardWidth=104,Duration=5,ReducedDuration=1.2,ReducedLead=4,MaxTicksPerSecond=30}
-- Fillers are cosmetic and drawn from the same odds; the winning card is the server's result.
function B.BuildStrip(odds,result,draw,count,win)
 count=count or B.Strip.Count;win=win or B.Strip.Win;local cards={}
 for i=1,count do cards[i]=i==win and result or B.RollTier(odds,draw)or'Uncommon'end
 return cards
end
function B.Ease(a)a=math.clamp(a,0,1);return 1-(1-a)^4 end
-- Index of the card centred under the marker for a strip offset (card 1 sits under the marker at offset 0).
function B.CardAt(offset,pitch)return math.floor(offset/pitch+.5)+1 end
-- One spin. Stops with the winning card under the marker (jitter keeps it inside the card, never on an edge).
function B.NewSpin(opts)
 local pitch=opts.Pitch or B.Strip.Pitch;local win=opts.Win or B.Strip.Win
 local reduced=opts.Reduced==true
 local jitter=math.clamp(tonumber(opts.Jitter)or 0,-.35,.35)
 local stop=((win-1)+jitter)*pitch
 local start=reduced and math.max(0,(win-1-B.Strip.ReducedLead))*pitch or 0
 local s={Pitch=pitch,Win=win,Start=start,Stop=stop,Duration=reduced and B.Strip.ReducedDuration or(opts.Duration or B.Strip.Duration),
  T=0,Offset=start,Card=B.CardAt(start,pitch),LastTick=-math.huge,Ticks=0,Done=false}
 -- Advance dt seconds. Returns offset, tick (true when a new card reached the marker and the tick is not
 -- throttled), pitch for that tick (rises as the strip slows), done.
 function s:Step(dt)
  if self.Done then return self.Offset,false,1,true end
  self.T=math.min(self.Duration,self.T+math.max(0,dt))
  local a=self.T/self.Duration
  self.Offset=self.Start+(self.Stop-self.Start)*B.Ease(a)
  local card=B.CardAt(self.Offset,self.Pitch);local tick=false
  if card~=self.Card then
   self.Card=card
   if self.T-self.LastTick>=1/B.Strip.MaxTicksPerSecond then tick=true;self.LastTick=self.T;self.Ticks+=1 end
  end
  if self.T>=self.Duration then self.Done=true end
  return self.Offset,tick,.9+.35*a,self.Done
 end
 function s:Skip()return self:Step(self.Duration)end
 return s
end
-- Button placement: first spot that clears every HUD box (HudLayout.HudBoxes with the wheel open) by 6 px.
local function overlaps(a,b,pad)return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
function B.Place(m,w,h,boxes)
 local bw,bh=m.Phone and 176 or 212,m.Phone and 46 or 52
 local barW=(m.Slots+1)*m.SlotSize+m.Slots*6;local detail=m.HotbarDetails~=false and 44 or 0
 local barTop=h-m.HotbarBottom-m.SlotSize-detail
 local hubY=h/2+(m.MenuShiftY or 0)-m.MenuSize/2
 local spots={
  {w/2+(m.HotbarShiftX or 0)-bw/2,barTop-10-bh}, -- just above the hotbar, centred
  {w-12-bw,h*.5-bh/2},{w-12-bw,h*.38-bh/2},{w-12-bw,h*.62-bh/2}, -- right edge
  {10,hubY+m.MenuSize+10},{10,hubY-10-bh}, -- under / over the menu hub
 }
 for _,scale in ipairs({1,.85})do
  local sw,sh=math.floor(bw*scale),math.max(44,math.floor(bh*scale))
  for _,s in ipairs(spots)do
   local r={X=math.floor(s[1]+(bw-sw)/2),Y=math.floor(s[2]+(bh-sh)/2),W=sw,H=sh}
   local ok=r.X>=8 and r.Y>=8 and r.X+r.W<=w-8 and r.Y+r.H<=h-8
   if ok then for _,b in ipairs(boxes)do if overlaps(r,b,6)then ok=false;break end end end
   if ok then return r end
  end
 end
 return {X=math.floor(w/2-bw/2),Y=math.floor(h*.3),W=bw,H=bh}
end
return B
