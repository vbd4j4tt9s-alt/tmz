-- R151 (owner: "look at Sol's RNG for the pull animation ... secret, cosmic or king ... doesn't have that impactful feel"; then "the seed should
-- be the main focus"; "the seed pack and seed have to go hand in hand" (no avatar); "rework legendary, uncommon, common, mythic ... so there
-- isn't a gigantic quality gap"; "add more suspense to opening the pack in general").
-- ONE escalating reveal ladder for every rarity. Pure data and maths only (no instances): the timelines, the pack suspense (wobble, tear,
-- rarity-hint colour), the Secret / Cosmic / King story scenes (where the pack and the seed are, where the camera is), the card layout, the
-- safety rule, the "1 in N" odds and the sound cue sheets. RarePullCinematic / RarePullCard / RarePullScenes / RarePullWorld / PackSuspense
-- and SeedPackClient draw what this module says, so the tests and the preview read exactly the same numbers.
-- The server timeline is NOT changed: RarityRevealSequence.SeedAt (and so RevealDuration) is what it was. The new suspense of Common..Mythic
-- happens inside the same window (the seed comes out later and hovers shorter), so opening a pack takes exactly as long as before.
local RS=game:GetService('ReplicatedStorage')
local Sequence=require(script.Parent.RarityRevealSequence)
local L={}
local V=Vector3.new
local C=Color3.fromRGB
-- Tiers ----------------------------------------------------------------------------------------------------------------------------------
-- Hint: the colour that flickers through the pack's cracks (the game's rarity colour). Suspense / Quick: seconds from the 5th click to the
-- burst (Quick = opening packs in quick succession). Card: how long the seed card stays after the burst. SeedSize: share of the screen height
-- the seed's card takes. TitleSize: share of the screen height of the rarity word.
L.Tiers={
 [1]={Key='Common',Title='COMMON',Hint=C(223,236,242),Glow=C(255,255,255),Deep=C(40,46,52),Font=Enum.Font.FredokaOne,Suspense=.6,Quick=.35,Card=.6,QuickCard=.45,SeedSize=.26,TitleSize=.07,Pulses=1,Heartbeats=0,Push=0,Grade=.12},
 [2]={Key='Uncommon',Title='UNCOMMON',Hint=C(98,235,130),Glow=C(214,255,200),Deep=C(14,52,26),Font=Enum.Font.FredokaOne,Suspense=.7,Quick=.4,Card=.8,QuickCard=.5,SeedSize=.28,TitleSize=.08,Pulses=2,Heartbeats=1,Push=0,Grade=.18},
 [3]={Key='Rare',Title='RARE',Hint=C(91,173,255),Glow=C(214,240,255),Deep=C(10,30,62),Font=Enum.Font.FredokaOne,Suspense=.85,Quick=.5,Card=1.15,QuickCard=.6,SeedSize=.31,TitleSize=.09,Pulses=2,Heartbeats=1,Push=0,Grade=.25},
 [4]={Key='Legendary',Title='LEGENDARY',Hint=C(255,207,89),Glow=C(255,244,190),Deep=C(60,36,4),Font=Enum.Font.LuckiestGuy,Suspense=1.1,Quick=.62,Card=2.4,QuickCard=.9,SeedSize=.35,TitleSize=.105,Pulses=3,Heartbeats=2,Push=5,Grade=.4,Rays=true},
 [5]={Key='Mythic',Title='MYTHIC',Hint=C(230,125,255),Glow=C(150,210,255),Deep=C(40,10,56),Font=Enum.Font.LuckiestGuy,Suspense=1.3,Quick=.75,Card=3.2,QuickCard=1.1,SeedSize=.38,TitleSize=.12,Pulses=4,Heartbeats=3,Push=7,Grade=.55,Rays=true,Shock=true,Letterbox=true},
 [6]={Key='Secret',Title='SECRET',Hint=C(255,119,160),Glow=C(214,170,255),Deep=C(14,4,26),Theme=C(176,112,255),Font=Enum.Font.Sarpanch,SeedSize=.34,TitleSize=.15,Pulses=4,Heartbeats=3,Push=6,Grade=.7,AuraSeconds=15},
 [7]={Key='Cosmic',Title='COSMIC',Hint=C(159,178,255),Glow=C(214,232,255),Deep=C(6,8,30),Theme=C(120,160,255),Font=Enum.Font.Michroma,SeedSize=.34,TitleSize=.15,Pulses=5,Heartbeats=4,Push=6,Grade=.75,AuraSeconds=20},
 [8]={Key='King',Title='KING',Hint=C(255,236,161),Glow=C(255,246,214),Deep=C(48,24,4),Theme=C(255,205,84),Font=Enum.Font.GrenzeGotisch,SeedSize=.34,TitleSize=.16,Pulses=6,Heartbeats=5,Push=6,Grade=.8,AuraSeconds=25},
}
L.Neutral=C(255,248,232)
L.QuickWindow=3 -- a pack opened within this many seconds after the previous reveal ended is a "quick" reveal (shorter suspense and card)
L.StageOrigin=V(0,2600,0) -- the hidden stage for the Secret / Cosmic / King scenes: far above the map, client-only, built on demand
L.SeedHeroSize=1.8 -- studs: the seed's biggest VISIBLE side in the scenes (RarePullRules.VisibleBounds)
-- The seed is the hero of every scene's ending (owner: "the seed should be the main focus"): from the hit on, the camera keeps the shot's
-- angle but frames the seed itself - centred, growing from HeroDiameter.From to .To of the screen height as it floats down (the same share on
-- desktop and phone: the field of view is vertical). ReducedMotion: one still shot at .Calm.
L.HeroDiameter={From=.33,To=.39,Calm=.37}
L.HeroAim=.04 -- the camera aims this share of the seed's size below it, so the seed sits in the middle of the band between title and odds
function L.HeroDistance(diameter,fov)return L.SeedHeroSize/(diameter*2*math.tan(math.rad(fov)/2))end
-- The visible box of a model: a part with a Sphere / Brick / Cylinder SpecialMesh shows Size x Scale (+ Offset), not its Size (the seed art is
-- made of such parts, so GetBoundingBox is ~1.4x too big); other parts their Size. Returns centre (world) and size (world axes), or nil.
function L.VisibleBounds(model)
 local lo,hi
 local corners={V(-1,-1,-1),V(1,-1,-1),V(-1,1,-1),V(1,1,-1),V(-1,-1,1),V(1,-1,1),V(-1,1,1),V(1,1,1)}
 for _,d in ipairs(model:GetDescendants())do
  if d:IsA('BasePart')and(d.Transparency or 0)<.99 then
   local size=d.Size;local cf=d.CFrame
   local mesh=d:FindFirstChildWhichIsA('SpecialMesh')
   if mesh then
    local kind=mesh.MeshType and mesh.MeshType.Name
    local sc=mesh.Scale
    if(kind=='Sphere'or kind=='Brick'or kind=='Cylinder')and typeof(sc)=='Vector3'then size=V(size.X*sc.X,size.Y*sc.Y,size.Z*sc.Z)end
    local off=mesh.Offset;if typeof(off)=='Vector3'then cf=cf*CFrame.new(off)end
   end
   local h=size*.5
   for _,c in ipairs(corners)do
    local p=cf*V(h.X*c.X,h.Y*c.Y,h.Z*c.Z)
    lo=lo and V(math.min(lo.X,p.X),math.min(lo.Y,p.Y),math.min(lo.Z,p.Z))or p
    hi=hi and V(math.max(hi.X,p.X),math.max(hi.Y,p.Y),math.max(hi.Z,p.Z))or p
   end
  end
 end
 if not lo then return nil end
 return(lo+hi)*.5,hi-lo
end
L.PackHeroHeight=2.6 -- studs: the pack's height in the scenes
L.OddsPrefix='1 in '
L.SceneCountDelay=.3 -- the story scenes: "1 in N" starts counting this long after the hit (the seed has risen clear of it)
function L.Tier(rank)return L.Tiers[math.clamp(math.floor(tonumber(rank)or 1),1,8)]end
local function clamp01(x)return math.clamp(x,0,1)end
local function smooth(x)x=clamp01(x);return x*x*(3-2*x)end
local function easeOut(x)x=clamp01(x);return 1-(1-x)^3 end
local function easeIn(x)x=clamp01(x);return x*x end
L.Smooth,L.EaseOut,L.EaseIn=smooth,easeOut,easeIn
-- The world timeline ----------------------------------------------------------------------------------------------------------------------
-- Seconds after RevealAt when the seed bursts out of the pack, for every viewer. Secret / Cosmic / King keep the server's SeedAt (their own
-- story scenes run on the opener's screen); Common..Mythic get a real suspense inside the unchanged RevealDuration.
function L.BurstAt(rank,quick)
 rank=math.clamp(math.floor(tonumber(rank)or 1),1,8)
 if rank>=6 then return Sequence.SeedAt(rank)end
 local tier=L.Tiers[rank];return quick and tier.Quick or tier.Suspense
end
-- The seed's rise / hover / slide after it bursts out. The hover shrinks by the extra suspense so the slide still ends with the server's
-- RevealDuration (for Secret+ and for the old timing this is exactly BalanceRules.SeedPhase).
function L.Hover(rank,burstAt,duration)
 local b=require(script.Parent.BalanceRules)
 if not duration then return b.SeedHoverSeconds end
 return math.max(.12,duration-burstAt-b.SeedRiseSeconds-b.SeedSlideSeconds)
end
function L.SeedPhase(age,hover)
 local b=require(script.Parent.BalanceRules)
 hover=hover or b.SeedHoverSeconds
 local rise=clamp01(age/b.SeedRiseSeconds)
 local slide=clamp01((age-b.SeedRiseSeconds-hover)/b.SeedSlideSeconds)
 return rise,slide
end
-- Quick reveals are decided by the opener's client only (its own presentation); a weak table so nothing leaks.
L.QuickBags=setmetatable({},{__mode='k'})
function L.MarkQuick(bag,quick)if bag then L.QuickBags[bag]=quick==true end end
function L.IsQuick(bag)return bag~=nil and L.QuickBags[bag]==true end
-- R152: decided ONCE per bag by whichever asks first, the director (PackOpeningFeedback) or the world pack (SeedPackClient): they run in
-- either order within a frame, and the world used to keep the normal timing when it asked first, so the seed burst out of the pack at a
-- different moment than the card and its sounds. A reveal still running, or one that ended under QuickWindow ago, makes it quick.
L.LastRevealEnd=-math.huge;L.RevealRunning=false -- (RarePullCinematic keeps these)
function L.QuickFor(bag)
 if bag~=nil and L.QuickBags[bag]~=nil then return L.QuickBags[bag]end
 local q=L.RevealRunning==true or(os.clock()-L.LastRevealEnd)<L.QuickWindow
 if bag~=nil then L.QuickBags[bag]=q end
 return q
end
-- Suspense: the pack's rarity hint, wobble and tear -------------------------------------------------------------------------------------
-- The hint starts neutral and walks up the ladder (Common, Uncommon, ...) to the real tier, flickering between neighbours like Sol's RNG
-- "it could be...": higher tiers pass through every lower colour. The last quarter holds the real colour.
function L.HintSequence(rank)
 local out={L.Neutral}
 for r=1,math.clamp(rank,1,8)do out[#out+1]=L.Tiers[r].Hint end
 return out
end
function L.Hint(rank,q)
 q=clamp01(q);local seq=L.HintSequence(rank);local n=#seq
 local walk=.75
 if q>=walk then return seq[n],.55+.45*clamp01((q-walk)/(1-walk))end
 local x=q/walk*(n-1);local i=math.floor(x)+1;local f=x-(i-1)
 local a,b=seq[i],seq[math.min(n,i+1)]
 -- flicker: in the last 40% of a step the colour strobes between the two neighbours (deterministic in q)
 local color=a
 if f>.6 then local strobe=math.floor(q*90)%2==0;color=strobe and b or a end
 return color,.18+.5*q
end
-- Wobble pulses (the opener also hears PackShake on each): evenly through the suspense, denser at the end.
function L.Pulses(rank,quick)
 local tier=L.Tier(rank);local at=L.BurstAt(rank,quick);local n=quick and math.max(1,tier.Pulses-1)or tier.Pulses
 local out={}
 for i=1,n do local k=i/(n+1);out[i]=at*(1-(1-k)^1.4)end
 return out
end
-- The wobble of the pack (a CFrame offset in the bag's own frame, scaled by its visual scale): rising sway plus a kick on every pulse.
-- R152 (owner: "animation must be smooth"): each kick swells in over 40 ms instead of jumping on (up to 7 degrees in one frame), and after
-- the burst the pack settles out over SettleSeconds instead of snapping straight (it jumped back by the whole sway on the burst frame).
L.SettleSeconds=.3
local function kickEnvelope(a)if a<0 or a>=.26 then return 0 elseif a<.04 then return smooth(a/.04)end;return(1-(a-.04)/.22)^2 end
function L.Wobble(rank,t,quick,reduced)
 local at=L.BurstAt(rank,quick);if t<0 or t>=at+L.SettleSeconds or reduced then return CFrame.new()end
 local settle=t>=at and 1-smooth((t-at)/L.SettleSeconds)or 1
 local q=clamp01(t/at)
 local amp=(.025+.012*rank)*(.25+.75*q*q)*settle
 local kick=0
 for _,p in ipairs(L.Pulses(rank,quick))do kick=math.max(kick,kickEnvelope(t-p))end
 kick*=settle
 local w=t*(14+rank*1.5)
 return CFrame.new(math.sin(w)*amp*.6+math.sin(w*2.3)*kick*.05,math.abs(math.sin(w*.5))*amp*.4+kick*.04,0)
  *CFrame.Angles(math.sin(w*.8)*amp*.5,math.sin(w*1.1)*amp*.35,math.sin(w)*amp*1.6+math.sin(w*2.7)*kick*.12)
end
-- The opener's heartbeats (seconds after RevealAt; none on a quick reveal): the LadderCues sound them, the screen edges and the seam glow
-- throb on them (R152: they used to pulse on a free-running sine, so the thump you heard never matched the throb you saw).
function L.Heartbeats(rank,quick)
 local tier=L.Tier(rank);local burst=L.BurstAt(rank,quick);local beats=quick and 0 or tier.Heartbeats;local out={}
 for i=1,beats do out[i]=burst*(i/(beats+1))^.8 end
 return out
end
-- 0..1 envelope of one throb a seconds after its beat: a 25 ms swell, then it dies away
local function throb(a)if a<0 then return 0 elseif a<.025 then return a/.025 end;return math.exp(-(a-.025)/.14)end
L.ThrobEnvelope=throb
-- The suspense's visible beat at t: a throb on every heartbeat, a slightly smaller one on every wobble pulse (PackShake), 0..1. The throbs
-- add up (screen blend), so a heartbeat right after a pulse still shows as a new throb on its own frame.
function L.Beat(rank,t,quick)
 local keep=1
 for _,h in ipairs(L.Heartbeats(rank,quick))do keep*=1-throb(t-h)end
 for _,p in ipairs(L.Pulses(rank,quick))do keep*=1-.8*throb(t-p)end
 return 1-keep
end
-- Glow of the pack's seams: builds, flares on every wobble pulse and throbs on every heartbeat (a faint free pulse under it).
function L.Glow(rank,t,quick)
 local at=L.BurstAt(rank,quick);if t<0 then return 0 end
 if t>=at then return math.max(0,1-(t-at)/.25)end
 local q=clamp01(t/at);local beat=.5+.5*math.sin(t*(6+10*q))
 local flare=0
 for _,p in ipairs(L.Pulses(rank,quick))do local a=t-p;if a>=0 and a<.25 then flare=math.max(flare,1-a/.25)end end
 local heart=0;for _,h in ipairs(L.Heartbeats(rank,quick))do heart=1-(1-heart)*(1-throb(t-h))end
 return clamp01(.12+.55*q*q+.06*beat*q+.35*flare+.3*heart)
end
-- The tear: the 8 strips peel a few at a time (2, then 3, then 3) instead of all at once, so the pack rips open bit by bit.
L.TearGroups={{1,2,At=0},{3,4,5,At=.38},{6,7,8,At=.72}}
function L.StripPeel(rank,t,index,quick)
 local at=L.BurstAt(rank,quick)
 for _,g in ipairs(L.TearGroups)do
  for j,i in ipairs(g)do
   if i==index then local start=g.At*at+(j-1)*.03;return clamp01((t-start)/.09)end
  end
 end
 return clamp01(t/.1)
end
function L.StripStart(rank,index,quick)
 local at=L.BurstAt(rank,quick)
 for _,g in ipairs(L.TearGroups)do for j,i in ipairs(g)do if i==index then return g.At*at+(j-1)*.03 end end end
 return 0
end
function L.TearTicks(rank,quick)local at=L.BurstAt(rank,quick);local out={};for i,g in ipairs(L.TearGroups)do out[i]=g.At*at end;return out end
-- The opener's screen for Common..Mythic: the seed card --------------------------------------------------------------------------------
-- Times on the reveal's server clock (seconds after RevealAt).
function L.CardTimeline(rank,quick)
 local tier=L.Tier(rank);local burst=L.BurstAt(rank,quick);local card=quick and tier.QuickCard or tier.Card
 local slam=burst+math.min(.6,.25+.08*rank)*(quick and .7 or 1)
 return {Burst=burst,TitleIn=burst,Count=burst+.06,Odds=slam,FloatEnd=burst+card,Out=burst+card,Length=burst+card+.2,
  Letterbox=tier.Letterbox==true,Quick=quick==true}
end
-- Secret / Cosmic / King story scenes ------------------------------------------------------------------------------------------------------
-- Beats in seconds after the cinematic starts (the opener's clock). Dim: the world darkens; Cut: fade to black; SceneIn: the hidden stage;
-- Silence: everything drops out; Climax: the pack bursts and the seed is revealed; Rise: the seed is up, framed big; Odds: "1 in N" slams;
-- FloatEnd: the seed has floated down to the camera; Back: the world again (HUD back); Length: the colour grading has eased back (done).
L.Scenes={
 [6]={Full={Dim=0,Cut=.45,SceneIn=.70,Glitch1=1.30,Glitch2=1.90,Lock=2.40,Unlock=2.90,SuckIn=3.05,Shudder=3.25,Silence=3.45,Climax=3.55,Rise=3.95,Odds=4.15,FloatEnd=5.10,Back=5.60,Length=6.40,SkipFrom=1.5},
      Calm={Dim=0,Cut=.35,SceneIn=.55,Glitch1=.80,Glitch2=.95,Lock=.90,Unlock=1.20,SuckIn=1.35,Shudder=1.50,Silence=1.75,Climax=1.85,Rise=1.86,Odds=2.40,FloatEnd=3.40,Back=3.75,Length=4.35,SkipFrom=1.0}},
 [7]={Full={Dim=0,Cut=.50,SceneIn=.80,Drift=2.40,Align1=1.60,Align2=2.10,Align3=2.60,SpinUp=2.60,Implode=3.90,SuckIn=3.95,Silence=4.35,Climax=4.45,StarIn=5.30,Rise=5.30,Odds=5.05,FloatEnd=6.60,Back=7.20,Length=8.00,SkipFrom=1.8},
      Calm={Dim=0,Cut=.40,SceneIn=.60,Drift=.60,Align1=.90,Align2=1.10,Align3=1.30,SpinUp=1.30,Implode=1.80,SuckIn=1.85,Silence=2.20,Climax=2.30,StarIn=2.80,Rise=2.80,Odds=2.85,FloatEnd=4.00,Back=4.35,Length=4.95,SkipFrom=1.0}},
 [8]={Full={Dim=0,Cut=.55,SceneIn=.85,Glide=3.00,Land=3.20,CrownStart=3.40,CrownOn=4.55,Fanfare=4.55,SuckIn=5.05,Silence=5.45,Climax=5.55,Rise=6.00,Odds=6.15,FloatEnd=8.70,Back=9.40,Length=10.20,SkipFrom=2.0},
      Calm={Dim=0,Cut=.45,SceneIn=.70,Glide=.70,Land=.70,CrownStart=1.00,CrownOn=2.20,Fanfare=2.20,SuckIn=2.35,Silence=2.75,Climax=2.85,Rise=2.86,Odds=3.45,FloatEnd=4.90,Back=5.30,Length=5.90,SkipFrom=1.0}},
}
-- In place (no camera, no hidden stage, HUD stays: a keeper is near, the player is on the track, a menu is open ...): on the reveal's server
-- clock, the climax on the world seed's burst. ResultOnly: a cinematic that had to stop early shows the result card at once.
function L.InPlace(rank,resultOnly)
 if resultOnly then return {Dim=0,Climax=0,Rise=0,Odds=.35,FloatEnd=1.6,Back=1.6,Length=2.1,SkipFrom=math.huge,InPlace=true,ResultOnly=true}end
 local c=Sequence.SeedAt(rank)
 return {Dim=0,SuckIn=math.max(0,c-.45),Silence=math.max(0,c-.08),Climax=c,Rise=c,Odds=c+.55,FloatEnd=c+1.9,Back=c+1.9,Length=c+2.5,SkipFrom=math.huge,InPlace=true}
end
function L.Timeline(rank,variant)
 rank=math.clamp(math.floor(tonumber(rank)or 6),6,8)
 if variant=='InPlace'then return L.InPlace(rank)elseif variant=='Result'then return L.InPlace(rank,true)end
 local base=L.Scenes[rank][variant=='Calm'and'Calm'or'Full'];local out=table.clone(base);out.Variant=variant=='Calm'and'Calm'or'Full';return out
end
L.LockTurns={0,.22,.44} -- Secret: the ring of lock plates turns (and clicks) this long after Lock, unless the unlock has begun
-- R152: when THIS presentation has shown the seed (its clock): the title on, the seed on screen and "1 in N" slammed. The director publishes
-- it (RarePullSeedShownAt) so the puller's own chat line about the pull waits for it, also on a slow device.
function L.ShownAt(tl)return math.max(tl.Climax or tl.Burst or 0,tl.Rise or 0,tl.Odds or 0)end
-- R152: how far the game's music is ducked under a reveal (0..1 of RarePullAudio.DuckDb), on the presentation's clock: it starts with the
-- reveal (the bed fades in at 0), is down by the cut (the story scenes) or half way through the suspense (the ladder), holds, and comes
-- back over the way out so it is fully back on Length. Common / Uncommon do not duck.
L.LadderDuck={0,0,.15,.35,.5}
function L.Duck(kind,rank,tl,t)
 local depth,inEnd,hold
 if kind=='Ladder'then depth=L.LadderDuck[math.clamp(rank,1,5)]or 0;inEnd=math.max(.2,tl.Burst*.6);hold=tl.Out
 elseif kind=='Scene'then depth=1;inEnd=math.max(.1,tl.Cut);hold=tl.Back
 elseif kind=='InPlace'then depth=.6;inEnd=.5;hold=tl.FloatEnd
 else depth=.4;inEnd=.2;hold=tl.FloatEnd end
 if depth<=0 or t<0 or t>=tl.Length then return 0 end
 if t<inEnd then return depth*smooth(t/inEnd)end
 if t<hold then return depth end
 return depth*(1-smooth((t-hold)/math.max(.05,tl.Length-hold)))
end
-- When the opener's own screen has SHOWN the seed -------------------------------------------------------------------------------------------
-- For the pull announcements (PullAnnounceRules.RevealDelay, used by the server): seconds after the server's RevealAt at which the opener's reveal has shown the seed - its
-- rarity title and the seed on screen AND "1 in N" slammed, the card's last beat. Common..Mythic (the ladder): the card's Odds slam; the story scenes: the latest of Climax, Rise
-- and Odds of the variant. A chat line about the pull must not reach the puller before this. Every presentation reads the tables above, so this follows them by itself.
L.StoryVariants={'Full','Calm','InPlace'} -- the three presentations that run on the reveal's clock ('Result' is a cut-short scene: its card starts at the cut, see below)
function L.SeedShown(rank,variant,quick)
 rank=math.clamp(math.floor(tonumber(rank)or 1),1,8)
 if rank<=5 then local card=L.CardTimeline(rank,quick==true);return math.max(card.Burst,card.Odds)end
 local tl=L.Timeline(rank,variant)
 return math.max(tl.Climax,tl.Rise or 0,tl.Odds or 0)
end
-- What a SERVER can rely on. It never sees which presentation the opener's client chose (that depends on a safety snapshot only the client has: a keeper near, a menu, reduced
-- motion ...) nor whether the reveal was quick (packs opened back to back), nor a skip (a skip only brings the hit EARLIER), so it takes the latest of them: the normal ladder card,
-- and for the story scenes the latest of Full / Calm / InPlace. A story scene that is cut short ('Result': danger, moved, camera) shows its result card at the cut, which is before
-- the scene's hit, plus the card's own .35 s: never later than the Full scene's own seed-shown time.
function L.LatestSeedShown(rank)
 rank=math.clamp(math.floor(tonumber(rank)or 1),1,8)
 if rank<=5 then return L.SeedShown(rank,nil,false)end
 local latest=0
 for _,variant in ipairs(L.StoryVariants)do latest=math.max(latest,L.SeedShown(rank,variant))end
 return latest
end
-- Camera keys per scene (stage-local, studs; FieldOfView is vertical, like Roblox). A key's time is a beat name plus an offset; Cut=true
-- switches at that time instead of blending (ReducedMotion uses cuts only: no camera moves).
local K=function(beat,offset,eye,target,fov,cut)return {Beat=beat,Offset=offset,Eye=eye,Target=target,Fov=fov,Cut=cut}end
L.Shots={
 [6]={Full={K('SceneIn',0,V(2.6,6.9,10.5),V(0,6,0),46),K('Lock',0,V(1.0,6.4,7.0),V(0,6,0),44),K('Silence',0,V(.2,6.25,5.4),V(0,6.1,0),42),
   K('Climax',0,V(0,6.3,5.6),V(0,6.3,0),46),K('Rise',0,V(0,7.1,6.0),V(0,7.0,0),50),K('FloatEnd',0,V(0,6.4,7.6),V(0,6.2,2.2),50)},
  Calm={K('SceneIn',0,V(.6,6.4,6.8),V(0,6.0,0),46,true),K('Climax',0,V(0,6.75,7.6),V(0,6.6,.9),50,true)}},
 [7]={Full={K('SceneIn',0,V(-7,10,13),V(3,7,-4),56),K('Align3',0,V(-3,8,8.5),V(0,6.6,-3),50),K('Implode',0,V(-.6,6.9,5.4),V(0,6.5,-3),46),
   K('Climax',0,V(0,6.8,5.2),V(0,6.6,-3),48),K('StarIn',0,V(0,7.1,6.0),V(0,7.0,0),50),K('FloatEnd',0,V(0,6.4,7.6),V(0,6.2,2.2),50)},
  Calm={K('SceneIn',0,V(-1.5,7.4,6.5),V(0,6.6,-3),50,true),K('Climax',0,V(0,6.9,7.6),V(0,6.6,-.5),50,true)}},
 [8]={Full={K('SceneIn',0,V(6,10,32),V(0,5,12),62),K('SceneIn',1.35,V(4,7.2,15),V(0,5.4,3),56),K('Land',0,V(2.6,6.2,3.8),V(0,4.8,-4.6),50),
   K('CrownStart',.05,V(1.4,3.4,2.2),V(0,7.0,-4.6),54),K('CrownOn',0,V(1.0,3.8,1.8),V(0,6.0,-4.6),52),K('Silence',0,V(0,5.6,1.6),V(0,5.0,-4.6),46),
   K('Climax',0,V(0,6.0,1.4),V(0,5.2,-4.6),48),K('Rise',0,V(0,7.6,1.2),V(0,7.4,-4.6),50),K('FloatEnd',0,V(0,6.5,4.4),V(0,6.3,-1.0),50)},
  Calm={K('SceneIn',0,V(2.2,6.4,4.2),V(0,5.2,-4.6),52,true),K('Climax',0,V(0,7.1,4.0),V(0,6.9,-2.8),50,true)}},
}
local function keyTime(tl,k)return(tl[k.Beat]or 0)+(k.Offset or 0)end
-- Eye, target (stage-local Vector3) and FieldOfView at time t.
local function keyedShot(rank,tl,t)
 local keys=L.Shots[rank][tl.Variant=='Calm'and'Calm'or'Full']
 local first=keys[1]
 if t<=keyTime(tl,first)then return first.Eye,first.Target,first.Fov end
 for i=1,#keys-1 do
  local a,b=keys[i],keys[i+1];local ta,tb=keyTime(tl,a),keyTime(tl,b)
  if t<tb then
   if b.Cut then return a.Eye,a.Target,a.Fov end
   local u=smooth((t-ta)/math.max(1e-3,tb-ta))
   return a.Eye:Lerp(b.Eye,u),a.Target:Lerp(b.Target,u),a.Fov+(b.Fov-a.Fov)*u
  end
 end
 local last=keys[#keys];return last.Eye,last.Target,last.Fov
end
function L.Shot(rank,variant,t,tl)
 tl=tl or L.Timeline(rank,variant)
 local eye,target,fov=keyedShot(rank,tl,t)
 if t<tl.Climax then return eye,target,fov end
 -- the hero shot: the keyed angle, the seed framed (Full: blends in over .3 s and follows it down; Calm: one still shot from the hit)
 local dir=(eye-target).Unit
 if tl.Variant=='Calm'then
  local rest=L.Points[rank].Seed0-V(0,L.SeedHeroSize*L.HeroAim,0)
  return rest+dir*L.HeroDistance(L.HeroDiameter.Calm,fov),rest,fov
 end
 local seed=L.SeedPose(rank,tl,t,true)-V(0,L.SeedHeroSize*L.HeroAim,0)
 local k=smooth((t-tl.Climax)/math.max(.01,tl.FloatEnd-tl.Climax))
 local dia=L.HeroDiameter.From+(L.HeroDiameter.To-L.HeroDiameter.From)*k
 local w=smooth((t-tl.Climax)/.3)
 local heroEye=seed+dir*L.HeroDistance(dia,fov)
 return eye:Lerp(heroEye,w),target:Lerp(seed,w),fov
end
-- Where the stars are: the pack (centre, stage-local), its spin (radians), its visibility; the seed; the King's crown; the Cosmic star.
L.Points={
 [6]={Pack=V(0,6,0),Seed0=V(0,7.0,0),Seed1=V(0,6.2,2.2)},
 [7]={Pack=V(0,6.5,-3),Drift=V(9,7.6,-7),Seed0=V(0,7.0,0),Seed1=V(0,6.2,2.2)},
 [8]={Pack=V(0,4.6,-4.6),Enter=V(0,5.6,22),Seed0=V(0,7.4,-4.6),Seed1=V(0,6.3,-1.0)},
}
local function jitter(t,seed)return math.sin(t*61+seed)*math.sin(t*23+seed*2.3)end
-- Returns position, yaw, roll, alpha (1 = visible) and a shake amount for the pack.
function L.PackPose(rank,tl,t)
 local P=L.Points[rank];local pos=P.Pack;local yaw=0;local roll=0;local alpha=1;local shake=0
 local burst=clamp01((t-tl.Climax)/.12);alpha=1-burst
 if rank==6 then
  pos=pos+V(0,.08*math.sin(t*1.6),0);yaw=math.sin(t*.45)*.3
  for _,g in ipairs({'Glitch1','Glitch2'})do local a=t-(tl[g]or -9);if a>=0 and a<.22 then pos=pos+V(jitter(t,1)*.14,jitter(t,2)*.06,0);roll=jitter(t,3)*.08 end end
  if t>=tl.Unlock and t<tl.Silence then shake=.03+.07*clamp01((t-tl.Unlock)/(tl.Silence-tl.Unlock))end
 elseif rank==7 then
  local d=easeOut((t-tl.SceneIn)/math.max(.01,tl.Drift-tl.SceneIn))
  pos=(P.Drift and tl.Drift>tl.SceneIn)and P.Drift:Lerp(P.Pack,d)or P.Pack
  local spin=.5+13.5*easeIn((t-tl.SpinUp)/math.max(.01,tl.Implode-tl.SpinUp))
  yaw=t*.5+(t>tl.SpinUp and(t-tl.SpinUp)*spin*.5 or 0);roll=math.sin(t*.3)*.3
  if t>=tl.Implode then alpha=math.min(alpha,1-clamp01((t-tl.Implode)/math.max(.01,tl.Silence-tl.Implode)))end
  if t>=tl.SpinUp and t<tl.Silence then shake=.02+.05*clamp01((t-tl.SpinUp)/(tl.Silence-tl.SpinUp))end
 else
  if tl.Land>tl.SceneIn then
   local g=smooth((t-tl.SceneIn)/math.max(.01,tl.Glide-tl.SceneIn))
   local above=P.Pack+V(0,.8,0)
   pos=P.Enter:Lerp(above,g)+V(0,.12*math.sin(t*2.4)*(1-g),0)
   -- (R152: set down with a smooth curve; the ease-out started at full speed the frame the glide had stopped)
   if t>=tl.Glide then pos=above:Lerp(P.Pack,smooth((t-tl.Glide)/math.max(.01,tl.Land-tl.Glide)))end
  end
  if t>=tl.CrownOn and t<tl.Silence then shake=.02+.09*easeIn((t-tl.CrownOn)/(tl.Silence-tl.CrownOn))end
 end
 return pos,yaw,roll,alpha,shake
end
-- The seed: position, alpha (0 before the climax) and glow (the Cosmic star around it, 1 = all star).
-- (still=true: without the little bob, for the camera that follows the seed)
function L.SeedPose(rank,tl,t,still)
 local P=L.Points[rank]
 if t<tl.Climax then return P.Seed0,0,0 end
 local calm=tl.Variant=='Calm'
 local pos;local glow=0
 if rank==7 then
  local k=clamp01((t-tl.Climax)/math.max(.01,tl.StarIn-tl.Climax))
  if t<tl.StarIn then
   local e=smooth(k);pos=P.Pack:Lerp(P.Seed0,e)+V(0,math.sin(k*math.pi)*.25,0);glow=1-e
  else pos=P.Seed0 end
 else
  local from=P.Pack
  if calm then pos=P.Seed0 else pos=from:Lerp(P.Seed0,smooth((t-tl.Climax)/math.max(.01,tl.Rise-tl.Climax)))end
 end
 local start=rank==7 and tl.StarIn or tl.Rise
 if t>start then
  -- (ReducedMotion: the seed rests where the still hero shot frames it)
  local f=smooth((t-start)/math.max(.01,tl.FloatEnd-start))*(calm and 0 or 1)
  pos=P.Seed0:Lerp(P.Seed1,f)
 end
 if not calm and not still then pos=pos+V(0,.05*math.sin(t*2.1),0)end
 return pos,clamp01((t-tl.Climax)/.08),glow
end
function L.SeedYaw(t,reduced)return reduced and math.sin(t*.4)*.25 or t*.75 end
-- King: the crown (centre of its band) and its scale.
function L.CrownPose(tl,t)
 local P=L.Points[8];local top=P.Pack+V(0,L.PackHeroHeight*.5+.32,0)
 if t<tl.CrownStart then return top+V(0,9,0),1,0 end
 if t<tl.Climax then
  -- (R152: it comes down on a smooth curve and touches the pack ON CrownOn, pressing in a little as the fanfare and the bell sound; the
  -- ease-out it had was 99.8 % down a sixth of a second early, so the landing seemed to come before its sound)
  local k=smooth((t-tl.CrownStart)/math.max(.01,tl.CrownOn-tl.CrownStart))
  local press=t>=tl.CrownOn and .06*math.sin(math.pi*clamp01((t-tl.CrownOn)/.28))or 0
  return(top+V(0,9,0)):Lerp(top,k)-V(0,press,0),1,clamp01((t-tl.CrownStart)/.3)
 end
 -- after the burst the crown lifts with the seed, shrinks and fades into the seed's own coronation ring
 local seed=L.SeedPose(8,tl,t);local k=clamp01((t-tl.Climax)/.9)
 return top:Lerp(seed+V(0,1.15,0),easeOut(k)),1-.45*k,1-clamp01((t-tl.Climax-.5)/.7)
end
-- Safety: the full story scene (camera, hidden stage, HUD hidden, controls held) only when nothing can hurt the player. s = a snapshot:
--  {Alive, OnTrack, KeeperDistance, KeeperChasing, Ragdoll, Running, Menu, CameraType, Grounded}
L.KeeperSafeDistance=60
function L.Decide(s)
 if type(s)~='table'or s.Alive==false then return 'InPlace','not alive'end
 if s.Ragdoll then return 'InPlace','ragdoll / fling'end
 if s.Running then return 'InPlace','carrying / queued run'end
 if s.KeeperChasing then return 'InPlace','a keeper is chasing'end
 if (tonumber(s.KeeperDistance)or math.huge)<L.KeeperSafeDistance then return 'InPlace','a keeper is near'end
 if s.OnTrack then return 'InPlace','on the track'end
 if s.Menu then return 'InPlace','a menu is open'end
 if s.CameraType~=nil and s.CameraType~='Custom'and s.CameraType~='Follow'then return 'InPlace','the camera is not the player\'s'end
 if s.Grounded==false then return 'InPlace','in the air / swimming / seated'end
 return 'Full','safe'
end
-- Odds -------------------------------------------------------------------------------------------------------------------------------------
local suffix={K=1e3,M=1e6,B=1e9,T=1e12,QA=1e15}
-- "12K" / "1.67B" / "1,250" -> number (the inverse of OddsText85.Count, near enough for the count-up)
function L.ParseCount(s)
 if type(s)~='string'then return nil end
 local num,suf=s:gsub(',',''):match('^%s*([%d%.]+)%s*(%a*)%s*$')
 local n=tonumber(num);if not n then return nil end
 if suf~=''then local m=suffix[suf:upper()];if not m then return nil end;n*=m end
 return n
end
-- The tooltip the server writes on a held pack ("Name: 1/N" rows) -> "1/N" for that seed.
function L.TooltipOdds(tooltip,displayName)
 if type(tooltip)~='string'or type(displayName)~='string'or displayName==''then return nil end
 for line in tooltip:gmatch('[^\n]+')do
  local name,count=line:match('^(.-):%s*1/(%S+)%s*$')
  if name==displayName and L.ParseCount(count)then return count end
 end
 return nil
end
-- "1 in N" text while counting up (k 0..1) and at the end (exact text, as OddsText85 printed it).
function L.CountText(final,k)
 if not final then return''end
 local n=L.ParseCount(final);if not n or k>=1 then return L.OddsPrefix..final end
 local Odds=require(script.Parent.OddsText85)
 local v=math.max(1,math.exp(math.log(math.max(1,n))*easeOut(k)))
 return L.OddsPrefix..Odds.Count(v)
end
-- Layout (shares of the screen; the same for the cards and the scenes). phone: smaller letterbox. compact: the in-place card in the upper
-- third, so the middle of the screen (the player, a keeper) stays clear.
function L.Layout(phone,compact,rank)
 local tier=L.Tier(rank or 6)
 if compact then
  return {Bar=0,Title={Y=.115,H=.075},Seed={Y=.235,H=.15},Odds={Y=.345,H=.05},Name={Y=.39,H=.035},Compact=true}
 end
 local bar=phone and .07 or .085
 local th=tier.TitleSize;local sh=tier.SeedSize
 -- the title just under the letterbox, "1 in N" and the name low: the middle band (about .25-.74 of the height) is the seed's
 return {Bar=bar,Title={Y=bar+th/2+.012,H=th},Seed={Y=.5,H=sh},Odds={Y=.78,H=.08},Name={Y=.85,H=.045}}
end
-- Projection of a stage point for a camera (eye, target, vertical fov in degrees, aspect = width / height) -> screen x, y (0..1), depth.
function L.Project(eye,target,fov,aspect,point)
 local f=(target-eye).Unit;local r=f:Cross(V(0,1,0)).Unit;local u=r:Cross(f)
 local d=point-eye;local z=d:Dot(f);if z<=.01 then return nil end
 local h=math.tan(math.rad(fov)/2)
 return .5+d:Dot(r)/(z*h*aspect)*.5,.5-d:Dot(u)/(z*h)*.5,z
end
-- Half height of a sphere of radius rho at depth z, in screen heights.
function L.ProjectedRadius(fov,z,rho)return rho/(z*math.tan(math.rad(fov)/2))*.5 end
-- Sound cue sheets ---------------------------------------------------------------------------------------------------------------------
-- {At, Slot, Pitch, Volume (x), Until, FadeIn, FadeOut}: At on the clock of the presentation (Common..Mythic and in place: the reveal's
-- server clock; the story scenes: the cinematic's clock). Loops play from At to Until. All on the Effects group.
local function cue(at,slot,o)o=o or{};o.At=at;o.Slot=slot;return o end
-- R152 (owner: "whoosh for the flying"): every flight of a presentation, {Name, From, To, Peak = its fastest moment (from the curve that
-- moves it: smoothstep peaks half way, an ease-out at its start), Pitch, Volume}. Each gets a soft whoosh (slot Flight) whose swell peaks on
-- Peak; each its own pitch, so repeats do not sound the same. ReducedMotion (Calm) has no flights but the planets.
function L.Flights(kind,rank,tl)
 local out={}
 local function fly(name,from,to,peak,pitch,volume)if from and to and to>from+.05 then out[#out+1]={Name=name,From=from,To=to,Peak=peak or(from+to)/2,Pitch=pitch,Volume=volume}end end
 if kind=='Ladder'then
  fly('Card float',tl.Burst,tl.FloatEnd,nil,1.55+.04*rank,.55)
 elseif kind=='InPlace'or kind=='Result'then
  fly('Card float',tl.Climax,tl.FloatEnd,nil,1.5,.55)
 elseif tl.Variant=='Calm'then
  if rank==7 then for i,p in ipairs({1.38,1.46,1.55})do local at=tl['Align'..i];fly('Planet '..i,at-.6,at,at-.3,p,.45)end end
 else
  if rank==7 then
   fly('Pack drift',tl.SceneIn,tl.Drift,tl.SceneIn+.03,1.2,.8) -- (ease-out: fastest as it comes in)
   for i,p in ipairs({1.38,1.46,1.55})do local at=tl['Align'..i];fly('Planet '..i,at-.6,at,at-.3,p,.45)end
   fly('Seed float',tl.StarIn,tl.FloatEnd,nil,1.3,.6)
  else
   if rank==8 and tl.Glide>tl.SceneIn then fly('Pack carry',tl.SceneIn,tl.Glide,nil,1.05,.7)end
   fly('Seed rise',tl.Climax,tl.Rise,nil,1.7,.6)
   fly('Seed float',tl.Rise,tl.FloatEnd,nil,1.3,.6)
  end
 end
 return out
end
-- The world seed's flight into the opener's hand (SeedPackClient; everyone near hears its whoosh at the seed): seconds after RevealAt.
function L.HandFlight(burstAt,hover)
 local b=require(script.Parent.BalanceRules);local from=burstAt+b.SeedRiseSeconds+(hover or b.SeedHoverSeconds)
 return {Name='Seed to hand',From=from,To=from+b.SeedSlideSeconds,Peak=from+b.SeedSlideSeconds/2,Pitch=1.6,Volume=.5}
end
local function flights(out,kind,rank,tl)
 for _,f in ipairs(L.Flights(kind,rank,tl))do
  out[#out+1]=cue(f.From,'Flight',{PeakAt=f.Peak,Pitch=f.Pitch/1.45,Volume=f.Volume,Until=math.min(tl.Length,f.To+.45),FadeOut=.35,Flight=f.Name})
 end
end
function L.LadderCues(rank,quick)
 local burst=L.BurstAt(rank,quick);local card=L.CardTimeline(rank,quick);local out={}
 local hearts=L.Heartbeats(rank,quick)
 for i,h in ipairs(hearts)do out[#out+1]=cue(h,'Heartbeat',{Pitch=.9+.06*i,Volume=.6+.4*i/#hearts})end
 for i,p in ipairs(L.Pulses(rank,quick))do out[#out+1]=cue(p,'PackShake',{Pitch=.95+.07*i+.02*rank,Volume=.5+.5*i/#L.Pulses(rank,quick)})end
 if rank>=4 then out[#out+1]=cue(burst*.25,'Riser',{Until=burst-.08,Volume=rank==4 and .7 or .85})end
 if rank>=5 and not quick then out[#out+1]=cue(burst-.42,'SuckIn',{Until=burst-.08,Volume=.75})end
 out[#out+1]=cue(burst,'PackBurst',{Pitch=1.15-.05*rank,Volume=.55+.07*rank})
 if rank>=4 then out[#out+1]=cue(burst,'GroundImpact',{Volume=rank==4 and .8 or .65})end -- the smaller hit (Legendary), under the big one (Mythic)
 if rank>=5 then out[#out+1]=cue(burst,'Impact',{Volume=.6})end
 out[#out+1]=cue(card.Odds,'TitleSlam',{Pitch=1.15-.04*rank,Volume=.45+.08*rank})
 if rank>=2 then out[#out+1]=cue(card.Odds+.12,'Sparkle',{Pitch=1+.05*rank,Volume=.5+.07*rank})end
 flights(out,'Ladder',rank,card)
 table.sort(out,function(a,b)return a.At<b.At end)
 return out
end
function L.SceneCues(rank,tl)
 local out={}
 local function add(at,slot,o)if at then out[#out+1]=cue(at,slot,o)end end
 local inPlace=tl.InPlace
 if inPlace then
  if not tl.ResultOnly then
   add(0,rank==8 and'KingChoir'or rank==7 and'CosmicPad'or'SecretDrone',{Until=tl.Silence,FadeIn=.3,FadeOut=.08,Volume=.7})
   add(math.max(0,tl.Climax-1.1),'Riser',{Until=tl.Silence,Volume=.8});add(tl.SuckIn,'SuckIn',{Until=tl.Silence,Volume=.7})
  end
  add(tl.Climax,'PackBurst');if rank~=7 then add(tl.Climax,'Impact')end;add(tl.Climax,'GroundImpact',{Volume=.6})
  add(tl.Climax,rank==8 and'KingFanfare'or rank==7 and'CosmicBoom'or'SecretGlitch',rank==6 and{Until=tl.Climax+1.2,FadeOut=.3}or nil)
  add(tl.Odds,'TitleSlam');add(tl.Odds+.15,'Sparkle')
 elseif rank==6 then
  add(0,'SecretDrone',{Until=tl.Silence,FadeIn=.4,FadeOut=.06})
  add(tl.SceneIn,'SecretWhisper',{Until=tl.Silence,FadeIn=.6,FadeOut=.1})
  -- each glitch beat is a short burst of the glitch sound; the vault door is cut (faded) by the silence
  add(.25,'SecretGlitch',{Pitch=1.1,Volume=.6,Until=.25+.4,FadeOut=.08});add(tl.Glitch1,'SecretGlitch',{Until=tl.Glitch1+.45,FadeOut=.08})
  add(tl.Glitch2,'SecretGlitch',{Pitch=.85,Volume=1.2,Until=tl.Glitch2+.5,FadeOut=.1})
  -- one click per turn of the lock ring (R152: the third turn had no click); a turn that would fall after the unlock does not happen
  for i,k in ipairs(L.LockTurns)do if tl.Lock+k<tl.Unlock then add(tl.Lock+k,'PackShake',{Pitch=.65+.05*i})end end
  add(tl.Unlock,'SecretVault',{Until=tl.Silence,FadeOut=.12})
  add(tl.Shudder,'PackShake',{Pitch=1.1});add(tl.Lock,'Riser',{Until=tl.Silence});add(tl.SuckIn,'SuckIn',{Until=tl.Silence})
  add(tl.Climax,'Impact');add(tl.Climax,'GroundImpact',{Volume=.6});add(tl.Climax,'PackBurst');add(tl.Climax,'SecretGlitch',{Pitch=.7,Volume=1.3,Until=tl.Climax+1.2,FadeOut=.3})
  add(tl.Odds,'TitleSlam');add(tl.Rise+.1,'Sparkle');add((tl.Rise+tl.FloatEnd)/2,'Sparkle',{Pitch=.9})
  add(tl.FloatEnd,'Sparkle',{Pitch=.75,Volume=.7}) -- (R152) the seed has floated down and settles
 elseif rank==7 then
  add(0,'CosmicPad',{Until=tl.Silence,FadeIn=.6,FadeOut=.3});add(tl.Climax+.15,'CosmicPad',{Until=tl.Back,FadeIn=.8,FadeOut=.5,Volume=.55})
  -- each planet locks into line with a short twinkle (rising)
  for i,p in ipairs({.9,1.06,1.26})do local at=tl['Align'..i];add(at,'CosmicStar',{Pitch=p,Volume=.7,Until=at+.6,FadeOut=.25})end
  add(tl.SpinUp,'CosmicWhoosh',{Until=tl.Implode+.2,FadeOut=.3});add(tl.SpinUp+.35,'PackShake',{Pitch=1.2});add(tl.SpinUp,'Riser',{Until=tl.Silence})
  add(tl.SuckIn,'SuckIn',{Until=tl.Silence})
  -- the supernova: CosmicBoom is the big hit here (instead of Impact), its tail rings under the seed
  add(tl.Climax,'CosmicBoom',{Until=tl.Back+.6,FadeOut=.6});add(tl.Climax,'GroundImpact',{Volume=.6});add(tl.Climax,'PackBurst',{Volume=.7})
  -- (R152: the falling star's whoosh swells at the star's fastest moment, half way; it was cut by StarIn before its swell)
  add(tl.Climax,'CosmicWhoosh',{Pitch=1.15,Volume=.8,PeakAt=(tl.Climax+tl.StarIn)/2,Until=tl.StarIn+.15,FadeOut=.3})
  -- (R152: on the frame the star resolves into the seed; it sounded .1 s early)
  add(tl.StarIn,'CosmicStar',{Pitch=1.15,Until=tl.FloatEnd,FadeOut=.4})
  add(tl.Odds,'TitleSlam');add((tl.StarIn+tl.FloatEnd)/2,'Sparkle',{Pitch=.9})
  add(tl.FloatEnd,'CosmicStar',{Pitch=1.3,Volume=.5,Until=tl.Length,FadeOut=.5}) -- (R152) the seed settles
 else
  add(0,'KingChoir',{Until=tl.Silence,FadeIn=.5,FadeOut=.06});add(tl.Climax+.2,'KingChoir',{Until=tl.Back,FadeIn=.6,FadeOut=.5,Volume=.65})
  -- R152 (owner: "for the king everything is synced up"): the low toll as the throne room opens (it rang on the fade to black), a soft
  -- landing as the pack is set on the cushion, a shimmer as the crown appears in its beam; the heralds' fanfare and the bell as the crown
  -- lands on the pack (the fanfare cut by the silence); the hit; a high bell as the seed settles at the end of its float
  add(tl.SceneIn,'KingBell',{Pitch=.7,Volume=.8})
  if tl.Land>tl.SceneIn+.1 then add(tl.Land,'PackShake',{Pitch=.62,Volume=.55})end
  add(tl.CrownStart,'Sparkle',{Pitch=.8,Volume=.7})
  add(tl.Fanfare,'KingFanfare',{Until=tl.Silence,FadeOut=.08});add(tl.CrownOn,'KingBell')
  add(tl.CrownOn+.05,'PackShake',{Pitch=.9});add(tl.CrownOn+.25,'PackShake',{Pitch=1.05});add(math.max(tl.CrownStart,tl.Silence-1.45),'Riser',{Until=tl.Silence})
  add(tl.SuckIn,'SuckIn',{Until=tl.Silence})
  add(tl.Climax,'Impact');add(tl.Climax,'GroundImpact',{Volume=.6});add(tl.Climax,'PackBurst');add(tl.Climax,'KingFanfare',{Until=tl.Back,FadeOut=.6})
  add(tl.Odds,'TitleSlam');add(tl.Rise+.25,'Sparkle');add((tl.Rise+tl.FloatEnd)/2,'Sparkle',{Pitch=.9})
  add(tl.FloatEnd,'KingBell',{Pitch=1.5,Volume=.4})
 end
 flights(out,inPlace and(tl.ResultOnly and'Result'or'InPlace')or'Scene',rank,tl)
 table.sort(out,function(a,b)return a.At<b.At end)
 return out
end
-- The light pillar / afterglow everyone nearby sees around a Secret / Cosmic / King puller (seconds after RevealAt).
function L.WorldTimeline(rank)
 local burst=Sequence.SeedAt(rank)
 return {Burst=burst,PillarEnd=burst+2.6,AuraEnd=burst+(L.Tier(rank).AuraSeconds or 15)}
end
return L
