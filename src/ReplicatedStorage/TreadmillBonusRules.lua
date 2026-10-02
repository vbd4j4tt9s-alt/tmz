-- R123: treadmill bonus rolls (owner request, final spec). Pure rules shared by TreadmillBonusService (server,
-- authoritative) and TreadmillBonusClient (roll button, crate-style strip, progress bar over the player).
--
-- Earning: only time on a treadmill counts (the server's own BaseService.TrainingSessions lock). Every 10 minutes of
-- treadmill time makes one roll READY. Progress is SAVED (profile Premium.TreadmillBonusProgress, seconds): 5 minutes,
-- get off, rejoin tomorrow -> still 5 minutes. READY rolls stack to 2 and are NOT saved (leaving the game loses them);
-- while 2 are ready the timer pauses (time beyond the cap is lost).
--
-- What a roll gives: one ordinary world seed pack (PackSize 1, no coat, no weather, current odds version), granted
-- with PlayerData:AddChest + ChestService:SyncTools (the ChestService:Bank path for a stolen pack), so opening it uses the normal seed odds and boot luck as usual.
--  * Pack rarity = the pack's tier (SeedPackRules.GetPackTier) at the game's existing world spawn weights
--    (SeedPackRules.Variants[*].SpawnWeight <- BalanceValues81/RouteBalance83.SpawnWeights), unchanged:
--      Common (Pack01) 38%   Uncommon (Pack02) 25%   Rare (Pack03) 15%   Epic (Pack04) 7%
--      Legendary (Pack05) 10%   Mythic (Pack06) 5%
--  * Biome = evenly among the biomes the player's best owned treadmill unlocks, cumulative in machine order:
--      1 Trail Runner -> Forest | 2 Vine Runner +Jungle | 3 Dune Runner +Desert | 4 Glacier Runner +Snow
--      5 Magma Runner +Lava | 6 Prism Runner +Crystal | 7 Thunder Runner +Storm (= every biome pack)
--    The Void pack (EclipseReliquary) and the paid Mech pack are never in the pool.
local PackRules=require(script.Parent.SeedPackRules)
local B={Version=123,IntervalSeconds=600,MaxReady=2,SaveEvery=10,RollCooldown=1,RemoteName='TreadmillBonusRoll'}
B.VariantOrder={'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'}
B.Special={Legendary=true,Mythic=true} -- flash + glow + fanfare on the result
-- Player attributes the server publishes (client reads only).
B.Attr={Ready='TreadmillBonusReady',DueAt='TreadmillBonusDueAt',Left='TreadmillBonusLeft',Interval='TreadmillBonusInterval',Pool='TreadmillBonusPool'}
function B.ReadyCount(v)
 if type(v)~='number'or v~=v or math.abs(v)==math.huge then return 0 end
 return math.clamp(math.floor(v),0,B.MaxReady)
end
function B.Progress(v)
 if type(v)~='number'or v~=v or math.abs(v)==math.huge then return 0 end
 return math.clamp(v,0,B.IntervalSeconds)
end
-- Pool stages for a treadmill level (cumulative over Config.TreadmillTiers, in machine order).
function B.PoolStages(tiers,level)
 local out={};level=math.clamp(math.floor(tonumber(level)or 1),1,#tiers)
 for i=1,level do local st=tiers[i].Stage;if st and st>=1 and st<=7 then table.insert(out,st)end end
 return out
end
function B.EncodePool(stages)local t={};for i,s in ipairs(stages)do t[i]=tostring(s)end;return table.concat(t,',')end
function B.DecodePool(text)
 local out={};if type(text)~='string'then return out end
 for n in text:gmatch('%d+')do local s=tonumber(n);if s and s>=1 and s<=7 and #out<7 then table.insert(out,s)end end
 return out
end
function B.Tier(variant)local tier=PackRules.GetPackTier(variant);return tier.Name,tier.Color end
-- {variant = probability} from the live world spawn weights.
function B.VariantOdds()
 local total=0;for _,k in ipairs(B.VariantOrder)do total+=PackRules.Variants[k].SpawnWeight end
 local out={};for _,k in ipairs(B.VariantOrder)do out[k]=PackRules.Variants[k].SpawnWeight/total end;return out
end
-- draw(): uniform [0,1). Returns {Stage=, Variant=}.
function B.RollPack(stages,draw)
 if #stages==0 then return nil end
 local u=draw();u=type(u)=='number'and u==u and math.clamp(u,0,1-1e-12)or 0
 local stage=stages[math.floor(u*#stages)+1]
 local v=draw();v=type(v)=='number'and v==v and math.clamp(v,0,1-1e-12)or 0
 local odds=B.VariantOdds();local variant=B.VariantOrder[#B.VariantOrder]
 for _,k in ipairs(B.VariantOrder)do v-=odds[k];if v<0 then variant=k;break end end
 return {Stage=stage,Variant=variant}
end
function B.Percent(p)
 local v=p*100
 if v>=1 then return(string.format('%.1f',v):gsub('%.0$',''))..'%'end
 return(string.format('%.2f',v):gsub('%.?0+$',''))..'%'
end
-- Rows for the odds panel: {Name, Color, Percent text} per pack rarity, plus the biome count.
function B.OddsRows()
 local odds=B.VariantOdds();local rows={}
 for _,k in ipairs(B.VariantOrder)do local name,color=B.Tier(k);table.insert(rows,{Variant=k,Name=name,Color=color,Chance=odds[k],Text=B.Percent(odds[k])})end
 return rows
end
-- Roll strip (crate style) -------------------------------------------------------------------------------------
B.Strip={Count=46,Win=40,Pitch=112,CardWidth=104,Duration=5,ReducedDuration=1.2,ReducedLead=4,MaxTicksPerSecond=30}
-- Fillers are cosmetic and drawn from the same pool and odds; the winning card is the server's result.
function B.BuildStrip(stages,result,draw,count,win)
 count=count or B.Strip.Count;win=win or B.Strip.Win;local cards={}
 for i=1,count do cards[i]=i==win and result or B.RollPack(stages,draw)or result end
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
 local detail=m.HotbarDetails~=false and 44 or 0
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
