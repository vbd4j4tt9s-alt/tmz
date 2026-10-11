-- R158l (owner: "give me a command that can make me giant and I can give packs and I can make them rain from the sky and disco all over"): the shared rules of the owner's party
-- commands. Plain data and pure functions: no Instances are made here. Used by OwnerParty158l / PackRain158l (server), PackRainFx158l / DiscoClient158l (client) and the tests.
--   giant    /test giant [1-20|off] [@name]               scales a character (Model:ScaleTo), session only
--   packrain /test packrain [count] [biome|rarity] [seconds] | off     packs fall everywhere on the map, taken by touch, gone 10 s after they land
--   disco    /test disco [on|off|seconds]                 server-wide party, drawn by each client from one workspace attribute
--   sound    /test sound <id> [volume 0-10] [loop] | stop   one server-wide sound
--   givepack /test givepack <biome|rarity|pack name> [count] [@name|@all]   (parsed here, granted by StudioTestCommands through the normal /test pack code)
local R={Version='158l'}
R.Giant={Min=1,Max=20,Default=5,Attribute='Giant158l',ZoomDefault=100} -- ZoomDefault: the game's own CameraMaxZoomDistance (GiantVisualSafety)
R.Rain={
 Default=30,MaxCount=500,MaxAtOnce=100,         -- packs in one rain / packs that exist at once (falling + lying): the server's lag cap
 DefaultSeconds=20,MinSeconds=5,MaxSeconds=120, -- how long the rain lasts (packs are spread over it at random times)
 LingerSeconds=10,ShrinkSeconds=.5,             -- a pack nobody touched goes 10 s after it LANDS (it shrinks away in the last half second on the screens)
 ScaleMin=.6,ScaleMax=2,                        -- the look only: each falling pack gets a random size; the pack it gives is a normal pack
 FallMin=2.2,FallMax=3.2,HeightMin=90,HeightMax=140,SpinMin=4,SpinMax=9, -- seconds, studs, radians of spin over the fall
 TouchLead=.2,                                  -- a pack can be taken from this long before it lands (the touch box is up from then)
 PerStep=6,StepSeconds=.1,                      -- at most this many packs are made per step; the step runs 10 times a second
 NearPlayers=.4,NearMin=10,NearMax=55,          -- the share of packs that land around a random player (the rest: hub, track and bases at random)
 TierWeights={30,25,20,13,8,4},                 -- a random pack: how likely common .. mythic are (any biome, all seven equally)
 Tag='PackRain158l',Folder='PackRain158l',Notice='\u{1F4E6} PACK RAIN!',
}
R.Disco={Attribute='Disco158l',CenterAttribute='DiscoCenter158l',Forever=-1,MinSeconds=5,MaxSeconds=3600}
R.Sound={Name='OwnerSound158l',DefaultVolume=1,MaxVolume=10,LoadTicks=80,LoadTick=.1,
 FailText="That sound couldn't load (it may be private or not allowed in this game)."}
R.Biomes={forest=1,desert=2,snow=3,lava=4,crystal=5,jungle=6,storm=7,stormpeaks=7}
R.BiomeNames={'Forest','Desert','Snow','Lava','Crystal','Jungle','Storm'}
R.Tiers={common=1,uncommon=2,rare=3,epic=4,legendary=5,mythic=6}
R.TierNames={'Common','Uncommon','Rare','Epic','Legendary','Mythic'}
R.RareWords={secret=true,cosmic=true,king=true,mech=true,roster=true} -- /test rarepacks <word>: packs that reveal that rarity
local function num(s)local n=tonumber(s);if n and n==n and math.abs(n)~=math.huge then return n end;return nil end
local function whole(n)return n~=nil and n%1==0 end
-- giant: returns a scale 1.01-20, or 'off' (also scale 1); nil, usage text when it is not understood.
function R.ParseGiant(a)
 local g=R.Giant;local usage='Use giant ['..g.Min..'-'..g.Max..'|off] [@username].'
 if#a==0 then return g.Default end
 if#a>1 then return nil,usage end
 local w=tostring(a[1]):lower()
 if w=='off'then return'off'end
 if w=='on'then return g.Default end
 local n=num(w);if not n or n<g.Min or n>g.Max then return nil,usage end
 if n==1 then return'off'end
 return n
end
-- packrain: {Off=true} | {Status=true} | {Count,Seconds,Stage,Tier}; nil, usage text when it is not understood.
function R.ParseRain(a)
 local r=R.Rain;local usage='Use packrain [count 1-'..r.MaxCount..'] [forest|desert|snow|lava|crystal|jungle|storm] [common|uncommon|rare|epic|legendary|mythic] [seconds '..r.MinSeconds..'-'..r.MaxSeconds..'], or packrain off.'
 local first=a[1]and tostring(a[1]):lower()
 if first=='off'or first=='stop'then if#a>1 then return nil,usage end;return{Off=true}end
 if first=='status'then if#a>1 then return nil,usage end;return{Status=true}end
 local nums={};local stage,tier
 for _,word in ipairs(a)do
  word=tostring(word):lower();local n=num(word)
  if n then nums[#nums+1]=n
  elseif R.Biomes[word]and not stage then stage=R.Biomes[word]
  elseif R.Tiers[word]and not tier then tier=R.Tiers[word]
  else return nil,usage end
 end
 if#nums>2 then return nil,usage end
 local count=nums[1]or r.Default;local seconds=nums[2]or r.DefaultSeconds
 if not whole(count)or count<1 or count>r.MaxCount or seconds<r.MinSeconds or seconds>r.MaxSeconds then return nil,usage end
 return{Count=count,Seconds=seconds,Stage=stage,Tier=tier}
end
-- disco: {Mode='on'|'off'|'status', Seconds=nil|number}
function R.ParseDisco(a)
 local d=R.Disco;local usage='Use disco [on|off|seconds '..d.MinSeconds..'-'..d.MaxSeconds..'].'
 if#a==0 then return{Mode='on'}end
 if#a>1 then return nil,usage end
 local w=tostring(a[1]):lower()
 if w=='on'or w=='off'or w=='status'then return{Mode=w}end
 local n=num(w);if not n or n<d.MinSeconds or n>d.MaxSeconds then return nil,usage end
 return{Mode='on',Seconds=n}
end
-- A bare number or rbxassetid://N (what the F4 box and chat give once lowered) -> 'rbxassetid://N'; anything else nil.
function R.ParseSoundId(text)
 local s=tostring(text or''):lower();local digits=s:match('^rbxassetid://(%d+)$')or s:match('^(%d+)$')
 if not digits or#digits>19 or tonumber(digits)==0 then return nil end
 return'rbxassetid://'..digits:gsub('^0+','')
end
-- sound: {Stop=true} | {Id,Volume,Loop}; nil, usage text when it is not understood.
function R.ParseSound(a)
 local s=R.Sound;local usage='Use sound <asset id> [volume 0-'..s.MaxVolume..'] [loop], or sound stop.'
 local first=a[1]and tostring(a[1]):lower()
 if first=='stop'or first=='off'then if#a>1 then return nil,usage end;return{Stop=true}end
 local id=R.ParseSoundId(first);if not id then return nil,usage end
 local volume,loop=s.DefaultVolume,false
 for i=2,#a do
  local w=tostring(a[i]):lower();local n=num(w)
  if w=='loop'and not loop then loop=true
  elseif n and i==2 and n>=0 and n<=s.MaxVolume then volume=n
  else return nil,usage end
 end
 return{Id=id,Volume=volume,Loop=loop}
end
-- givepack: what to grant, as normal /test commands (the ones that already give packs, so every pack stays a TEST pack).
--   a = the words after "givepack": a biome (forest ... storm) and / or a rarity (common ... mythic), a count, or a pack name (void, verity, secret, cosmic, king, mech, roster).
--   biome alone = tier 3 (Rare, like /test pack); rarity alone = a random biome for each pack; both = exactly that.
--   Returns {Commands={{Text='pack forest 3 1 none 2',N=2},...},Total=n,Label='...'} or nil, usage text.  rand(lo,hi) picks the random biomes (math.random by default).
function R.GivePlan(a,rand)
 rand=rand or math.random
 local usage='Use givepack <forest|desert|snow|lava|crystal|jungle|storm | common|uncommon|rare|epic|legendary|mythic | void|verity|secret|cosmic|king|mech|roster> [count] [@username|@all].'
 local count,stage,tier,special
 for _,word in ipairs(a)do
  word=tostring(word):lower();local n=num(word)
  if n then if count then return nil,usage end;count=n
  elseif R.Biomes[word]and not stage and not special then stage=R.Biomes[word]
  elseif R.Tiers[word]and not tier and not special then tier=R.Tiers[word]
  elseif(word=='void'or word=='eclipse'or word=='verity'or R.RareWords[word])and not special and not stage and not tier then special=word=='eclipse'and'void'or word
  else return nil,usage end
 end
 count=count or 1
 if not whole(count)or count<1 or count>500 then return nil,usage end
 if special then
  if special=='void'or special=='verity'then return{Commands={{Text=special..' '..count,N=count}},Total=count,Label=special=='void'and'Void'or'Verity'}end
  if count>20 then return nil,'givepack '..special..' gives up to 20 at a time.'end
  local list={};for _=1,count do list[#list+1]={Text='rarepacks '..special,N=1}end
  return{Commands=list,Total=count,Label=special:sub(1,1):upper()..special:sub(2)}
 end
 if not stage and not tier then return nil,usage end
 tier=tier or 3
 local per={}
 if stage then per[stage]=count else for _=1,count do local s=rand(1,7);per[s]=(per[s]or 0)+1 end end
 local list={}
 for s=1,7 do if per[s]then list[#list+1]={Text=string.format('pack %s %d 1 none %d',R.BiomeNames[s]:lower(),tier,per[s]),N=per[s]}end end
 local label=R.TierNames[tier]..(stage and(' '..R.BiomeNames[stage])or' (random biomes)')
 return{Commands=list,Total=count,Label=label}
end
return R
