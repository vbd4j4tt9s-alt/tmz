-- R155 (owner): the pack pity. Pure rules shared by the server (PackPityData155: the saved counts and the open), the odds clamps (PackOdds112 / 137,
-- PackLuck154: Ceiling) and the client (PityBars155: the two bars above the hotbar). Owner, in order: "for mech packs a 10 pity system can work but we have a
-- 1.5x luck boost at the 10th pack" -> "Every 10th pack" -> "make the pity separate an event pity and a normal pity the event pity only counts for void, verity
-- and mech all other packs have separate pity".
--  * Two counts per player, both saved: Normal = every pack that is not a Void / Verity / Mech pack (world, stolen and banked packs, bonus rolls, daily /
--    login / mystery packs, the starter pack ...); Event = the Void, Verity and Mech packs, one count between them.
--  * Opening a pack adds 1 to its group's count. The 10th open of a group is a LUCKY pack: its roll takes x Boost (1.5) on top of everything it already
--    takes (boots x clover; Void / Verity / Mech: the clover only), and for that roll alone the luck cap is x Boost too (Ceiling: the x50M ceiling becomes
--    x75M). Then the count goes back to 0: 1..9 normal, the 10th lucky, again.
--  * An owner / Studio TEST open (a TestGrant pack, a /test rarepacks reveal, luck from owner-given boots) neither counts nor is lucky.
--  * The per-tier ceilings inside a pack (King 1% ...), the 80% rule and every shown fixed number (RawSeedOdds: Index, cards, chat) are unchanged.
local T=require(script.Parent.BalanceValues81)
local Verity=require(script.Parent.VerityCatalog)
local P={Version=155,Every=10,Groups={'Normal','Event'}}
P.Boost=tonumber(T.LuckyPackBoost)or 1.5
-- what the client reads (player attributes, set by the server): the count of each group (0..Every-1) and how many lucky packs each group gave this visit
P.Attribute={Normal='PackPityNormal',Event='PackPityEvent'}
P.LuckyAttribute={Normal='PackPityLuckyNormal',Event='PackPityLuckyEvent'}
P.EventVariants={EclipseReliquary=true,MechLimited=true,[Verity.Variant]=true}
-- A pack's group, by its bag variant: 'Event' for a Void, Verity or Mech pack, 'Normal' for any other pack.
function P.Group(variant)
 return P.EventVariants[variant]and'Event'or'Normal'
end
-- A saved / typed count: a whole number 0..Every-1 (anything else is 0).
function P.Count(n)
 n=tonumber(n)
 if not n or n~=n or n==math.huge or n==-math.huge then return 0 end
 n=math.floor(n)
 if n<0 or n>=P.Every then return 0 end
 return n
end
function P.State(saved)
 saved=type(saved)=='table'and saved or{}
 return {Normal=P.Count(saved.Normal),Event=P.Count(saved.Event)}
end
-- True when the NEXT open of a group at this count is its lucky 10th.
function P.IsLucky(count)return P.Count(count)>=P.Every-1 end
-- The count after one open.
function P.After(count)
 local n=P.Count(count)+1
 return n>=P.Every and 0 or n
end
-- Opens left until the lucky one (1 = the next open is lucky).
function P.Left(count)return P.Every-P.Count(count)end
-- The luck a roll takes: x Boost on a lucky roll (applied ONCE, where the roll is asked for), as it is otherwise. Junk stays junk (the clamps make it 1).
function P.Luck(luck,lucky)
 if lucky~=true or type(luck)~='number'or luck~=luck then return luck end
 return luck*P.Boost
end
-- The lucky ceiling: while a lucky roll (or its odds) is worked out, every luck clamp takes x Boost more (PackOdds112 / 137: x50M -> x75M; PackLuck154: the
-- clover's x2 -> x3). Scoped: only inside P.Scoped(true, ...), which never yields (the odds code is pure).
local depth=0
function P.Lucky()return depth>0 end
function P.Ceiling(base)
 if depth>0 and type(base)=='number'then return base*P.Boost end
 return base
end
-- fn(...) with the lucky ceiling on when lucky is true (plainly otherwise). An error inside still turns the ceiling back off.
function P.Scoped(lucky,fn,...)
 if lucky~=true then return fn(...)end
 depth+=1
 local result=table.pack(pcall(fn,...))
 depth-=1
 if not result[1]then error(result[2],0)end
 return table.unpack(result,2,result.n)
end
-- Packs banked before R112 map the luck to the old boots (x1.15 ... x2: PackOdds112.LegacyLuck). On a lucky roll the mapping reads the luck before the x Boost
-- and the old multiplier gets the x Boost once.
function P.Legacy(map,luck)
 if depth>0 and type(luck)=='number'and luck==luck then return map(luck/P.Boost)*P.Boost end
 return map(luck)
end
-- Text (the owner's voice) ------------------------------------------------------------------------------------------------------------------------
-- The rule, listed with the odds (the hold tooltip, /test odds; the Mech shop card has the event one).
P.Disclosure='every 10th pack you open is lucky: x1.5 luck (event packs count separately)'
P.EventDisclosure='every 10th event pack you open (Void, Verity, Mech) is lucky: x1.5 luck'
P.LuckyLine='LUCKY PACK: x1.5 luck on this one!'
P.Name={Normal='pity',Event='event pity'}
-- The bar's words for a count: "3/10 pity", "3/10 event pity"; at 9/10 "9/10 next one's lucky!".
function P.Text(group,count)
 count=P.Count(count)
 if P.IsLucky(count)then return ('%d/%d next one\'s lucky!'):format(count,P.Every)end
 return ('%d/%d %s'):format(count,P.Every,P.Name[group]or P.Name.Normal)
end
-- The same, short, for a small bar: "3/10 pity", "3/10 event", "next one's lucky!".
function P.ShortText(group,count)
 count=P.Count(count)
 if P.IsLucky(count)then return 'next one\'s lucky!'end
 return ('%d/%d %s'):format(count,P.Every,group=='Event'and'event'or P.Name.Normal)
end
function P.NoticeText(group)
 return group=='Event'and'💜 LUCKY EVENT PACK! x1.5 luck on this one!'or'🍀 LUCKY PACK! x1.5 luck on this one!'
end
-- the tag on the reveal card of a lucky pack
function P.TagText(group)return group=='Event'and'💜 LUCKY EVENT PACK! x1.5 luck'or'🍀 LUCKY PACK! x1.5 luck'end
P.PopText='LUCKY PACK! x1.5 luck'
P.PopShort='LUCKY! x1.5'
-- Colours: NORMAL pity gold, EVENT pity purple ({Light, Deep, Glow, Ink}).
local RGB=Color3.fromRGB
P.Colors={
 Normal={Light=RGB(255,232,120),Deep=RGB(236,152,22),Glow=RGB(255,206,64),Ink=RGB(92,52,4)},
 Event={Light=RGB(214,162,255),Deep=RGB(122,56,224),Glow=RGB(186,110,255),Ink=RGB(44,12,84)},
}
return P
