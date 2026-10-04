-- R141 (owner: "a pedestal with a mystery pack, the pack will be a black silhouette, after 15 minutes of staying in the
-- game they unlock the pack, this refreshes every day, the pack will be based on the treadmill they have"): the numbers
-- and pure rules shared by MysteryPackService (server) and MysteryPackClient.
--  * Time in the game today counts (UTC days, like the DAILY window), across rejoins; 15 minutes unlocks today's pack.
--  * The biome is the player's best treadmill's biome (Trail Runner = Forest ... Thunder Runner = Storm), decided when
--    it unlocks. The rarity is never Common (it is a daily treat): the odds below, rolled at the same moment.
--  * An unlocked pack that was not taken before midnight is added to the Bag on the next visit (never lost). If the Bag is
--    full then, it waits in a small saved "owed" list (MaxOwed) and goes in as soon as there is room; today's pack and its
--    15 minutes start fresh either way.
--  * UnlockAt (server time) is published again when the countdown the client shows drifts more than DriftSeconds from the
--    real one (a server hitch counts at most 5 s per tick).
local M={UnlockSeconds=15*60,SaveEvery=15,Version=141,MaxOwed=3,DriftSeconds=2}
M.Order={'Pack02','Pack03','Pack04','Pack05','Pack06','EclipseReliquary'}
M.Odds={Pack02=.45,Pack03=.30,Pack04=.17,Pack05=.06,Pack06=.019,EclipseReliquary=.001}
M.Void={Variant='EclipseReliquary',Stage=7}
-- Where it stands in each base (pad space): the empty entrance corner opposite the treadmill (which is at X -34).
M.Offset=Vector3.new(34,0,75)
local valid={}for _,v in ipairs(M.Order)do valid[v]=true end
local function integer(n,lo,hi)return type(n)=='number'and n==n and n%1==0 and n>=lo and n<=hi end
function M.Day(t)return math.floor((t or os.time())/86400)end
function M.NextDay(t)return(M.Day(t)+1)*86400 end
-- The biome of the best treadmill owned (Config.TreadmillTiers in machine order).
function M.Stage(tiers,level)
 level=tonumber(level)or 1;if level~=level then level=1 end
 level=math.clamp(math.floor(level),1,#tiers)
 local st=tiers[level].Stage;return integer(st,1,7)and st or 1
end
function M.Roll(stage,draw)
 local u=draw();u=type(u)=='number'and u==u and math.clamp(u,0,1-1e-12)or 0
 local total=0;for _,k in ipairs(M.Order)do total+=M.Odds[k]end
 local variant=M.Order[1];local acc=0
 for _,k in ipairs(M.Order)do acc+=M.Odds[k]/total;if u<acc then variant=k;break end end
 if variant==M.Void.Variant then stage=M.Void.Stage end
 return {Stage=stage,Variant=variant}
end
-- Saved state: Day (UTC day it is for), Seconds (time in game that day), Stage / Variant (set when it unlocks),
-- Claimed, and Owed: up to MaxOwed unlocked packs from earlier days that did not fit in a full Bag, oldest first, each
-- {Day, Stage, Variant} (one per day). Saves from before Owed existed read with an empty list. Anything odd resets to a
-- fresh, empty state (a bad Owed entry is dropped); it never pays out.
function M.Read(v)
 local out={Day=-1,Seconds=0,Claimed=false,Owed={}}
 if type(v)~='table'then return out end
 if integer(v.Day,-1,1e7)then out.Day=v.Day end
 if type(v.Seconds)=='number'and v.Seconds==v.Seconds then out.Seconds=math.clamp(v.Seconds,0,M.UnlockSeconds)end
 if integer(v.Stage,1,7)and valid[v.Variant]then out.Stage=v.Stage;out.Variant=v.Variant end
 out.Claimed=v.Claimed==true and out.Stage~=nil
 if type(v.Owed)=='table'then
  local seen={}
  for i=1,math.min(#v.Owed,16)do -- (the oldest MaxOwed good ones are kept)
   local e=v.Owed[i]
   if type(e)=='table'and integer(e.Day,-1,1e7)and integer(e.Stage,1,7)and valid[e.Variant]and not seen[e.Day]then
    seen[e.Day]=true;out.Owed[#out.Owed+1]={Day=e.Day,Stage=e.Stage,Variant=e.Variant}
    if #out.Owed>=M.MaxOwed then break end
   end
  end
 end
 return out
end
function M.Unlocked(state)return state.Seconds>=M.UnlockSeconds and state.Stage~=nil end
function M.Left(state)return math.max(0,M.UnlockSeconds-state.Seconds)end
function M.Clock(seconds)
 seconds=math.max(0,math.ceil(seconds));return string.format('%d:%02d',math.floor(seconds/60),seconds%60)
end
return M
