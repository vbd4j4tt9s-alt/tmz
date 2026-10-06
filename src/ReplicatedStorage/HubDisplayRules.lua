-- R151 (owner: "a best pull today display onto one of the empty corners of the map and a biggest fruit display on the other side ... that rotates every
-- day, biggest tomato or bigger watermelon and so on, it will be a giant display and the persons avatar will be standing beside it"): the pure rules and
-- numbers of the two hub displays, shared by the server (HubDisplayBoard / Store / Art / Service) and the client (HubDisplayClient). No services, no
-- Instances: everything here can be tested alone.
-- R152 (owner: "make sure that the avatar is sized up and dancing while the seed rotates around and the effects are actually on the seed not behind ... a billboard is not
-- needed ... the same format and look as the fruit of the hour type pedestal"): no sign board any more. A display is the Fruit of the Hour pedestal, built big, with the
-- winning seed / fruit turning over it and the champion's avatar, 25 studs tall and dancing, beside it. Its words are small, in the Fruit of the Hour's own format (see Words).
--  * BEST PULL TODAY: the rarest seed any player pulled from a pack today, across all servers. Order: highest rarity rank (Common ... King, as
--    SeedPackRules.Rarities ranks them), then the smaller chance (the rarer pull), then the heavier seed, then the earlier pull. PullBetter is a strict
--    total order (the last two keys make even identical pulls differ), so every server picks the same winner.
--  * BIGGEST FRUIT TODAY: each UTC day has ONE fruit type (FruitForDay: a fixed walk through the harvestable fruit list, so a type comes back only after
--    the whole list has been through). The heaviest harvested fruit of that type today wins; ties go to the earlier harvest.
--  * Both reset at UTC midnight, with the same day number the daily rewards use (DailyRewards.Day).
-- Records (what is kept in memory and shipped through MemoryStore): flat tables of numbers / strings only. Clean* make an untrusted one safe (a bad field
-- gives nil, nothing is guessed), and recompute rank and weight locally, so a stored value can never claim a rank it does not have.
local P=require(script.Parent.SeedPackRules)
local D=require(script.Parent.DailyRewards)
local Weight=require(script.Parent.ItemWeight)
local R={Version=151}

-- Tuning ---------------------------------------------------------------------------------------------------------------------------------------------
R.StoreName='HubDisplays151'      -- the MemoryStore hash map (one key per UTC day: 'd<day>')
R.ExpirySeconds=2*86400           -- a day's key lives two days (it is never read after its own day; the spare day covers clock skew)
R.PollSeconds=45                  -- a server reads the shared board about this often ...
R.PollJitter=15                   -- ... plus 0..15 s, so the servers do not all ask in the same second
R.WriteGap=3                      -- at most one shared write per server in 3 s (the best of everything since the last write goes in)
R.FirstPollDelay=2                -- the first read, this long after the server starts
R.RetryBase=5                     -- after a failed request the next attempt waits 5, 10, 20 ... s
R.RetryMax=300                    -- ... never longer than this
R.ThrottledWait=90                -- after a "throttled / quota" error the wait is at least this
R.RequestsPerMinute=12            -- this server's own cap (the experience's MemoryStore quota is 1000 + 100 per player a minute)
R.NoticeGap=8                     -- seconds between two record chat lines of one kind in one server (the display still changes; WHICH records get a line is PullAnnounceRules.RecordScope)
R.MaxFruitRank=5                  -- fruit types in the daily rotation: up to Mythic (raise to 8 to include Secret / Cosmic / King plants)
R.MinFruitKg=.5                   -- a plant whose fruit weighs less than this at size 1 has no meaningful weight: never the fruit of the day
R.NameLength=24
R.ItemHeight=12                   -- the showcase item (seed / fruit) is scaled to about this many studs tall
R.ItemParts=150                   -- at most this many parts in one giant model
R.AvatarHeight=25                 -- the champion's avatar stands about this tall (a normal R15 avatar is about 5.3: about 4.7 times; R152)
R.AvatarTurn=-.3                  -- the avatar turns this far (radians) from facing the viewers toward the pedestal beside it
R.AvatarAccessories=10            -- at most this many accessories are worn by the display's avatar
R.AvatarCache=12                  -- humanoid descriptions kept (per user id)
R.Tag='HubDisplay151'

-- Time -----------------------------------------------------------------------------------------------------------------------------------------------
function R.Day(t)return D.Day(t)end
function R.NextAt(day)return(day+1)*86400 end
function R.SecondsLeft(t)return D.SecondsLeft(t)end
-- "5h 12m", "12m 30s", "45s".
function R.Countdown(seconds)
 seconds=type(seconds)=='number'and seconds==seconds and math.max(0,math.floor(seconds))or 0
 if seconds>=3600 then return string.format('%dh %dm',seconds//3600,(seconds%3600)//60)end
 if seconds>=60 then return string.format('%dm %02ds',seconds//60,seconds%60)end
 return string.format('%ds',seconds)
end

-- Fields ---------------------------------------------------------------------------------------------------------------------------------------------
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function integer(n,lo,hi)return finite(n)and n%1==0 and n>=lo and n<=hi end
-- A short, printable name: control characters out, at most NameLength characters (counted as UTF-8 characters).
function R.CleanName(value)
 if type(value)~='string'then return nil end
 local s=value:gsub('[%c]',' '):gsub('%s+',' '):match('^%s*(.-)%s*$')
 if s==''then return nil end
 if utf8.len(s)==nil then return nil end
 if utf8.len(s)>R.NameLength then s=s:sub(1,(utf8.offset(s,R.NameLength+1)or(#s+1))-1)end
 return s
end
local function coat(v)return P.MutationKey(v)end
local function weatherKey(v)return require(script.Parent.WeatherTraits).Key(v)end
function R.RankOf(rarity)local style=P.Rarities[rarity];return style and style.Rank or 0 end
function R.RarityColor(rarity)local style=P.Rarities[rarity]or P.Rarities.Common;local c=style.Color;return{math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)}end
-- The seed's plain name ("Fire Pepper"), as the hotbar and the Index write it.
function R.SeedLabel(id,seedName)
 local ok,name=pcall(function()return require(script.Parent.GardenDisplayNames).Plant(id,seedName)end)
 return ok and type(name)=='string'and name or tostring(seedName or id)
end
function R.FruitLabel(id,harvestName)
 local ok,name=pcall(function()return require(script.Parent.GardenDisplayNames).Fruit(id,harvestName)end)
 return ok and type(name)=='string'and name or tostring(harvestName or id)
end

-- A pull. Uid = who (the Roblox user id), Name = their display name, Id = the seed id, Seed = its plain name, Rarity, Odds = the chance (percent, 0 < odds <= 100)
-- the seed had in the pack that was opened (boots, pack, odds version and rate boost included), Scale = the seed's size, Coat = the pack's coat, At = when (Unix seconds).
-- Kg and Rank are computed here from the other fields. Test = an owner's injected pull (never shipped to MemoryStore).
function R.CleanPull(v)
 if type(v)~='table'then return nil end
 local style=P.Rarities[v.Rarity];if not style then return nil end
 local id=v.Id;if type(id)~='string'or #id<1 or #id>60 then return nil end
 if not finite(v.Odds)or v.Odds<=0 or v.Odds>100 then return nil end
 local at=v.At;if not integer(at,0,1e11)then return nil end
 local uid=v.Uid;if not integer(uid,-1e12,1e13)then return nil end
 local name=R.CleanName(v.Name)or'Player'
 local scale=finite(v.Scale)and math.clamp(v.Scale,.35,P.MaxSeedScale or 25)or 1
 local seed=type(v.Seed)=='string'and v.Seed~=''and #v.Seed<=40 and v.Seed or R.SeedLabel(id,id)
 local rec={Uid=uid,Name=name,Id=id,Seed=seed,Rarity=v.Rarity,Rank=style.Rank,Odds=v.Odds,Scale=scale,Coat=coat(v.Coat),At=at,Test=v.Test==true}
 rec.Kg=Weight.Weight('Seed',id,scale)
 return rec
end
function R.StorePull(rec)
 return {Uid=rec.Uid,Name=rec.Name,Id=rec.Id,Seed=rec.Seed,Rarity=rec.Rarity,Odds=rec.Odds,Scale=rec.Scale,Coat=rec.Coat,At=rec.At}
end
-- A harvested fruit. Id = the plant (seed id), Scale = FruitScale, Coat = Gold / Diamond / None, Weather = its weather key.
function R.CleanFruit(v)
 if type(v)~='table'then return nil end
 local id=v.Id;if type(id)~='string'or #id<1 or #id>60 then return nil end
 local at=v.At;if not integer(at,0,1e11)then return nil end
 local uid=v.Uid;if not integer(uid,-1e12,1e13)then return nil end
 if not finite(v.Scale)or v.Scale<=0 then return nil end
 local scale=math.clamp(v.Scale,.35,50)
 local rec={Uid=uid,Name=R.CleanName(v.Name)or'Player',Id=id,Scale=scale,Coat=coat(v.Coat),Weather=weatherKey(v.Weather),At=at,Test=v.Test==true}
 rec.Kg=Weight.Weight('Fruit',id,scale)
 return rec
end
function R.StoreFruit(rec)
 return {Uid=rec.Uid,Name=rec.Name,Id=rec.Id,Scale=rec.Scale,Coat=rec.Coat,Weather=rec.Weather,At=rec.At}
end
-- One day's shared document: {v=1, pull=<StorePull>, fruit=<StoreFruit>}. Anything that does not clean up is dropped.
function R.CleanDoc(v)
 if type(v)~='table'then return {}end
 local out={}
 if type(v.pull)=='table'then out.pull=R.CleanPull(v.pull)end
 if type(v.fruit)=='table'then out.fruit=R.CleanFruit(v.fruit)end
 return out
end
function R.StoreDoc(doc)
 local out={v=1}
 if doc.pull then out.pull=R.StorePull(doc.pull)end
 if doc.fruit then out.fruit=R.StoreFruit(doc.fruit)end
 return out
end

-- Ranking --------------------------------------------------------------------------------------------------------------------------------------------
local function same(a,b)return a==b or math.abs(a-b)<=1e-9*math.max(math.abs(a),math.abs(b),1e-300)end
-- true when pull a beats pull b (a nil b: any pull wins; a nil a: never). Strict: PullBetter(a,b) and PullBetter(b,a) are never both true.
function R.PullBetter(a,b)
 if not a then return false end
 if not b then return true end
 if a.Rank~=b.Rank then return a.Rank>b.Rank end
 if not same(a.Odds,b.Odds)then return a.Odds<b.Odds end
 if not same(a.Kg,b.Kg)then return a.Kg>b.Kg end
 if a.At~=b.At then return a.At<b.At end
 if a.Uid~=b.Uid then return a.Uid<b.Uid end
 if a.Id~=b.Id then return a.Id<b.Id end
 return false
end
function R.FruitBetter(a,b)
 if not a then return false end
 if not b then return true end
 if not same(a.Kg,b.Kg)then return a.Kg>b.Kg end
 if a.At~=b.At then return a.At<b.At end
 if a.Uid~=b.Uid then return a.Uid<b.Uid end
 if a.Coat~=b.Coat then return a.Coat<b.Coat end
 return false
end
function R.Better(kind,a,b)if kind=='Fruit'then return R.FruitBetter(a,b)end;return R.PullBetter(a,b)end
-- A short identity of a record: two records with the same key are the same pull / fruit (a rebuilt display only happens when this changes).
function R.Key(rec)
 if not rec then return''end
 return table.concat({tostring(rec.Uid),tostring(rec.Id),tostring(rec.At),string.format('%.4f',rec.Kg or 0),tostring(rec.Coat),tostring(rec.Rarity or rec.Weather or'')},'|')
end

-- The fruit of the day ---------------------------------------------------------------------------------------------------------------------------------
-- The plants whose fruit can be today's: harvestable (in the catalog with at least one fruit), not retired, not limited-time (Verity, the Mech plants), no more
-- than MaxFruitRank, and with a meaningful weight (at least MinFruitKg at size 1). env (all optional, for tests): Catalog, IsRetired(id), Excluded(id),
-- Rank(id), Base(id) (kg at size 1), MaxRank, MinKg. Sorted by id (a stable order).
function R.EligibleFruits(env)
 env=env or{}
 local catalog=env.Catalog or require(script.Parent.PlantCatalog)
 local retired=env.IsRetired or function(id)return P.IsRetired(id)end
 local excluded=env.Excluded or function(id)
  local verity=require(script.Parent.VerityCatalog);local mech=require(script.Parent.MechCatalog)
  return verity.Is(id)or mech.Is(id)
 end
 local rank=env.Rank or function(id)local name=P.SeedRarityById[id]or(catalog[id]and catalog[id].Rarity);return R.RankOf(name)end
 local base=env.Base or function(id)return Weight.Base('Fruit',id)end
 local maxRank=env.MaxRank or R.MaxFruitRank;local minKg=env.MinKg or R.MinFruitKg
 local list={}
 for id,def in pairs(catalog)do
  if type(id)=='string'and type(def)=='table'and(tonumber(def.FruitCount)or 0)>=1 and not retired(id)and not excluded(id)then
   local r=rank(id);local kg=base(id)
   if r>=1 and r<=maxRank and finite(kg)and kg>=minKg then list[#list+1]=id end
  end
 end
 table.sort(list)
 return list
end
local function gcd(a,b)while b~=0 do a,b=b,a%b end;return a end
local function hash(s)local h=5381;for i=1,#s do h=(h*33+s:byte(i))%2147483647 end;return h end
-- The order the walk goes through: the ids sorted by a hash of themselves (looks shuffled, never changes for a given list).
function R.FruitOrder(list)
 local order=table.clone(list)
 table.sort(order,function(a,b)local ha,hb=hash(a),hash(b);if ha~=hb then return ha<hb end;return a<b end)
 return order
end
-- The step of the walk: about 0.618 of the list (the golden ratio keeps neighbours far apart), made coprime with the list length so every fruit comes up once
-- per length days, and never 1 or length-1 (a fruit's neighbours in the list would come on consecutive days).
function R.FruitStep(n)
 if n<=2 then return 1 end
 local step=math.max(2,math.floor(n*.618+.5))
 for offset=0,n do
  for _,s in ipairs({step+offset,step-offset})do
   if s>=2 and s<=n-2 and gcd(s,n)==1 then return s end
  end
 end
 return 1
end
-- The fruit id of UTC day `day` (an integer: DailyRewards.Day). A given list always gives the same answer for a day; any `#list` consecutive days
-- are all different; two consecutive days never repeat. nil for an empty list.
function R.FruitForDay(list,day)
 local n=#list;if n==0 or type(day)~='number'or day~=day then return nil end
 local order=R.FruitOrder(list);local step=R.FruitStep(n)
 local index=(math.floor(day)*step)%n+1
 return order[index]
end

-- Texts ----------------------------------------------------------------------------------------------------------------------------------------------
local EMOJI={
 SunflowerSeed='🍉',StrawberrySeed='🍓',CloverSeed='🍓',BluebellSeed='🍇',AppleSeed='🍎',ElderbloomSeed='🍏',MooncapSeed='🍄',SunflowerBloomSeed='🌻',
 CactusSeed='🌵',DesertRoseSeed='🌵',DatePalmSeed='🌸',DesertAloeSeed='🌿',SandFruitSeed='🌵',CrystalLilySeed='🌸',IceberrySeed='❄️',SnowdropSeed='🍈',
 WinterPineSeed='🌷',AshRoseSeed='🍅',EmberBloomSeed='🎃',FirePepperSeed='🌶️',LavaLotusSeed='🔥',AmethystSeed='🍇',PrismOrchidSeed='🌶️',MoonflowerSeed='🍈',
 DiamondVineSeed='💎',AncientWorldrootSeed='🌳',CocoaSeed='🍫',LanternFernSeed='🏮',PineappleSeed='🍍',TigerOrchidSeed='🌺',VenomVineSeed='🌿',
 SparkReedSeed='⚡',ThunderTulipSeed='🌷',VoltOrchidSeed='⚡',TempestLotusSeed='⚡',BananaSeed='🍌',DragonfruitSeed='🐉',MonsteraSeed='🌿',
 StarfruitSeed='⭐',PulsarStarfruitSeed='⭐',SolarStarfruitSeed='⭐',
}
function R.Emoji(id)return EMOJI[id]or'🌱'end
-- "12.4 kg" (one decimal below 1,000; 1,250 kg and up without decimals).
function R.KgText(kg)
 if not finite(kg)or kg<=0 then return''end
 if kg<1000 then return string.format('%.1f kg',kg)end
 local s=string.format('%d',math.floor(kg+.5));while true do local nextText,n=s:gsub('^(%d+)(%d%d%d)','%1,%2');s=nextText;if n==0 then break end end
 return s..' kg'
end
function R.OddsText(percent)return require(script.Parent.OddsText85).Format(percent)end
local COAT={Gold='Gold',Diamond='Diamond'}
function R.PullName(rec)return rec.Rarity..' '..rec.Seed end
-- The words of a fruit's special looks: "Gold", "Diamond", a weather ("Drippy"), both ("Gold · Drippy"), or ''.
function R.FruitTraits(rec)
 local words={}
 if COAT[rec.Coat]then words[#words+1]=COAT[rec.Coat]end
 if rec.Weather and rec.Weather~='None'then words[#words+1]=require(script.Parent.WeatherTraits).Display(rec.Weather)end
 return table.concat(words,' · ')
end

-- The words ---------------------------------------------------------------------------------------------------------------------------------------------
-- Small, in the Fruit of the Hour pedestal's own format (MarketLayout.Pedestal / FruitOfHourDisplay), only bigger: an engraved PLAQUE on the pedestal column's front (a SurfaceGui: a dark plate with gold
-- Fredoka lettering) and a LABEL floating over the showcase item (a BillboardGui sized in studs, its text fills each row). Rows are boxes (X, Y, W, H) with the biggest text size they may use (plaque: pixels
-- on a canvas drawn at PixelsPerStud; label: studs); the text shrinks to fit. Fit() is the conservative width model the tests use (Fredoka One is a chunky face: about 0.62 em per character, an emoji about 1.5).
R.Plaque={W=10,H=5,PixelsPerStud=48,Canvas={W=480,H=240},MaxDistance=300}
R.Plaque.Rows={
 Title={X=20,Y=8,W=440,H=70,Max=56},
 Name={X=20,Y=80,W=440,H=64,Max=52},
 Line={X=20,Y=146,W=440,H=52,Max=40},
 Footer={X=20,Y=200,W=440,H=34,Max=26},
}
R.Label={W=26,H=8,MaxDistance=420}
R.Label.Rows={
 Title={X=.5,Y=0,W=25,H=2.2,Max=2.0},
 Name={X=.5,Y=2.2,W=25,H=3.2,Max=3.0},
 Info={X=.5,Y=5.4,W=25,H=2.6,Max=2.4},
}
function R.TextWidthEm(text)
 local em=0
 for _,cp in utf8.codes(text)do em+=(cp>=0x2190)and 1.5 or .62 end
 return em
end
-- The biggest size (pixels on the plaque, studs on the label) text may be drawn at inside a row: its Max, less when the words are too long for the row's width or the row is not tall enough.
function R.Fit(text,row)
 local em=math.max(R.TextWidthEm(text),.01)
 return math.min(row.Max,row.W/em,row.H*.95)
end
local PLACEHOLDER='Nobody yet'
-- The words of a display. kind 'Pull' | 'Fruit'; rec = the champion's record (nil: nobody yet); fruitId = today's fruit; secondsLeft = to the next board; fruitName = its plain name.
-- Returns {Kind, State, Accent={r,g,b}, Plaque={Title=, Name=, Line=, Footer=}, Label={Title=, Name=, Info=}} (each row {Text, Color={r,g,b}}): the plaque says the title, the winner, a line (a pull's
-- rarity and chance; the fruit of the day) and the countdown; the label says the title, the winner and the seed / the weight.
function R.SignText(kind,rec,fruitId,secondsLeft,fruitName)
 local gold={255,214,90};local white={255,255,255};local soft={206,214,238}
 local out={Kind=kind,Plaque={},Label={}}
 local P,L=out.Plaque,out.Label
 P.Footer={Text=(kind=='Pull'and'New board in 'or'New fruit in ')..R.Countdown(secondsLeft),Color=soft}
 local title=kind=='Pull'and'BEST PULL TODAY'or'BIGGEST FRUIT TODAY'
 P.Title={Text=title,Color=gold};L.Title={Text=title,Color=gold}
 local function winner(text)P.Name={Text=text,Color=white};L.Name={Text=text,Color=white}end
 if kind=='Pull'then
  if rec then
   out.State='Champion';out.Accent=R.RarityColor(rec.Rarity)
   winner(rec.Name);L.Info={Text=rec.Seed,Color=out.Accent}
   P.Line={Text=rec.Rarity..' · '..R.OddsText(rec.Odds)..(COAT[rec.Coat]and(' · '..COAT[rec.Coat])or''),Color=out.Accent}
  else
   out.State='Empty';out.Accent=gold
   winner(PLACEHOLDER);L.Info={Text='Open a pack!',Color=soft}
   P.Line={Text='Open a pack to claim it!',Color=soft}
  end
 else
  local name=fruitName or R.FruitLabel(fruitId,fruitId)
  P.Line={Text='Today: '..R.Emoji(fruitId)..' '..name,Color=white}
  if rec then
   out.State='Champion';out.Accent=gold
   local traits=R.FruitTraits(rec)
   winner(rec.Name);L.Info={Text=R.KgText(rec.Kg)..(traits~=''and(' · '..traits)or''),Color=gold}
  else
   out.State='Empty';out.Accent=gold
   winner(PLACEHOLDER);L.Info={Text='Harvest one to claim it!',Color=soft}
  end
 end
 return out
end

-- Where they stand ---------------------------------------------------------------------------------------------------------------------------------------
-- The hub is a flat 680 x 524 field (floor top y 4, walls 48 high, inner faces at x +-335 and z -618). Bases 3 and 4 end at z -417; Bases 5 and 6 sit at the back between
-- x -133 and 133. So the two back corners (HubDecorKit151.Reserved: x 145 .. 335 and -335 .. -145, z -618 .. -420) are kept empty for the displays. Each stands in one, about 100 studs from both its
-- walls, and faces the market (the players' meeting place), so it reads from the whole hub.
--  Pull : the +X corner (below Base_4, beside Base_6)        Fruit: the -X corner (below Base_3, beside Base_5)
R.Layout={
 FloorTop=4,
 Target=Vector3.new(0,4,-265),
 Pull={Center=Vector3.new(236,4,-516)},
 Fruit={Center=Vector3.new(-236,4,-516)},
 -- the reserved corner (studs, world X / Z) and how far a stand reaches from its centre in its own frame (the pedestal on one side, the dancing avatar's arms on the other)
 Corner={X0=145,X1=335,Z0=-618,Z1=-420},
 Footprint={HalfX=36,HalfZ=24},
}
return R
