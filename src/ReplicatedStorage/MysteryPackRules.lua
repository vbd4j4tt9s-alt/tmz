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
-- R150 (owner: "polish the pack pedestal that players have in base"): the look, shared by the server's pedestal art (MysteryPedestalArt) and the
-- client's fx (MysteryPedestalFx, MysteryPackClient) so the two can never drift. Numbers only: no gameplay, timing or odds here.
--  * AnchorHeight: the pack hovers this high over the pad (the pedestal's own height is built to it).
--  * Palette: the pedestal wears the biome of the pack (the best treadmill's), in the treadmill's own theme colours (BiomeVisuals.treadmillThemes:
--    Body / Trim / Glow / Ink), found by the biome Stage. Material is the body's surface: the theme's own material, except Crystal, whose theme says Glass
--    (the treadmill never draws its body in Glass; a solid glass column would look see-through): that one stays SmoothPlastic. Tune it here if a biome's
--    surface looks wrong in Studio. Without an owner it wears the violet "mystery" colours.
--  * StateLook: the lit parts (glow pad, four gems, light) per state. Locked is calm violet, Ready lights up gold, Claimed is a dim mint ember.
M.AnchorHeight=9.3
M.PadTop=6.41 -- the top of the glowing pad under the pack (pedestal space) and the column's radius: where the client's light shaft and padlock sit
M.ColumnRadius=2.1
M.Palette={
 [1]={Body={191,135,75},Trim={106,195,101},Glow={225,253,153},Ink={54,106,68},Material='Wood'},        -- Forest (Trail Runner)
 [6]={Body={236,201,108},Trim={51,190,127},Glow={255,222,109},Ink={40,110,88},Material='Wood'},        -- Jungle (Vine Runner)
 [2]={Body={251,202,130},Trim={232,141,90},Glow={255,241,167},Ink={145,87,66},Material='Sandstone'},   -- Desert (Dune Runner)
 [3]={Body={135,203,234},Trim={195,245,255},Glow={235,255,255},Ink={58,113,157},Material='Ice'},       -- Snow (Glacier Runner)
 [4]={Body={96,88,111},Trim={255,143,74},Glow={255,216,99},Ink={82,62,89},Material='Basalt'},          -- Lava (Magma Runner)
 [5]={Body={217,181,250},Trim={124,228,222},Glow={250,223,255},Ink={119,80,155},Material='SmoothPlastic'},     -- Crystal (Prism Runner)
 [7]={Body={111,155,237},Trim={255,224,96},Glow={255,247,193},Ink={56,82,153},Material='Metal'},      -- Storm (Thunder Runner)
}
M.DefaultPalette={Body={104,82,168},Trim={176,118,255},Glow={226,200,255},Ink={62,55,88},Material='Marble'}
M.Gold={255,198,72}
M.StateLook={
 Empty={Color={74,66,102},Neon=false,Transparency=0,Light=nil},
 Locked={Color={176,118,255},Neon=true,Transparency=.35,Light={Color={170,110,255},Brightness=1,Range=12}},
 Ready={Color={255,214,90},Neon=true,Transparency=0,Light={Color={255,220,120},Brightness=2.4,Range=20}},
 Claimed={Color={64,112,92},Neon=false,Transparency=0,Light={Color={110,220,160},Brightness=.35,Range=9}},
}
function M.Theme(stage)return M.Palette[stage]or M.DefaultPalette end
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
