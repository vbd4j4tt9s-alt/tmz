-- R158d (owner: "make it so that new players receive a [Verity] pack, every new player, and it's notified to them; the pack is guaranteed Mythic or above"; "this will only last till the Verity
-- event ends"; "every brand-new player also gets 2 bonus rolls"): the numbers, texts and the one roll rule shared by StarterVerity158d (the server service that gives the gift),
-- PlayerDataService (the save / load / open of the marked pack), ChestService (the pack's name) and TreadmillBonusService (the 2 rolls come back after a rejoin). No Instances: pure.
--  * The gift (one time per player, ever): ONE real Verity Pack marked Floor = 'Mythic' (a new OPTIONAL field of the pack's inventory record, next to GiftLocked) and 2 treadmill bonus rolls.
--    Saved state: Premium.StarterVerity158d = absent (not set: every older save, every player who was not new while the event ran) / 'Owed' (a brand-new profile while the event runs:
--    R158e: given at the first spawn, at once) / 'Given' (the pack is in the Bag). Premium.StarterRolls158d = the starter rolls not used yet (0 - 2; absent = none). ProfileVersion stays 22.
--  * The floor is decided by the server only: it lives in the saved record (set by StarterVerity158d through AddChest) and PlayerDataService:OpenSeedPack reads it. Nothing a client sends
--    can set or change it. Only a Verity pack (stage 7) can carry it; a seed made from it does not.
--  * On open: the pack's OWN odds for that open (SeedPackRules.SeedOdds: the Verity pack's table, the 4 Leaf Clover, the pity's lucky x1.5, the 80% rule) keep only the seeds of the floor's rarity
--    and above (Mythic, Secret, Cosmic, King), and are rolled again over what is left (each weight divided by the kept total). Luck can only move chance between those seeds.
local Verity=require(script.Parent.VerityCatalog)
local R={Version='158d'}
R.Flag='StarterVerity158d';R.Owed='Owed';R.Given='Given'
R.RollsField='StarterRolls158d';R.Rolls=2
R.Floor='Mythic'
-- The owner's words, exactly (one notice, shown once, a moment after the gift is given).
R.Notice="Thanks for playing! Here's a gift"
-- R158e (owner: "the verity gift is given instantly to all new players"): the gift comes at the first spawn; its notice a few seconds later, so it is read after the title screen (a brand-new
-- player's title closes about 1.2 s after it shows, TitleScreen.client.lua).
R.NoticeSeconds=5;R.NoticeDelay=4
R.ToolName='Gift Verity Pack' -- the hotbar / Bag name: a different name is a different stack (InventoryStacks155.Key), so the gift pack never joins a stack of ordinary Verity Packs
R.ToolTip='Guaranteed Mythic or better • Click / tap / RT 5 times to open'
R.TooltipLine='Guaranteed Mythic or better'
-- Gifting: the pack is saved GiftLocked (FruitGiftService refuses; the seed, plant and fruit made from it stay locked).
R.Locked=true
R.RetryEvery=5;R.Retries=6 -- a refused grant (a full Bag, data that cannot save) is tried again every 5 s, 6 times; the next join tries again
R.LoadWait=.5;R.LoadTries=240 -- waiting for a joined player's profile: every .5 s for up to 2 minutes
-- A saved / given floor, made clean: only the one word we know. Anything else reads as "no floor".
function R.CleanFloor(v)return v==R.Floor and v or nil end
-- The floor a pack record really has: only a Verity pack (stage 7) carries one. Returns 'Mythic' or nil.
function R.PackFloor(record)
 if type(record)~='table'or record.Kind~='Pack'then return nil end
 if record.BagVariant~=Verity.Variant or record.Stage~=Verity.PackStage then return nil end
 return R.CleanFloor(record.Floor)
end
-- The saved state, made clean.
function R.CleanState(v)if v==R.Owed or v==R.Given then return v end;return nil end
-- Starter rolls not used yet: a whole number from 0 to R.Rolls (anything else reads as 0).
function R.CleanRolls(v)
 if type(v)~='number'or v~=v or math.abs(v)==math.huge then return 0 end
 return math.clamp(math.floor(v),0,R.Rolls)
end
-- The pack the gift gives, as the record AddChest takes it: a plain Verity Pack (stage 7, 1x, no coat, no weather, the current odds version) that can't be gifted and has the floor.
function R.Pack(packRules)
 return{Stage=Verity.PackStage,BagVariant=Verity.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=packRules.OddsVersion,GiftLocked=R.Locked or nil,Floor=R.Floor}
end
local function rank(rules,rarity)
 for i,name in ipairs(rules.RarityOrder)do if name==rarity then return i end end
 return 0
end
function R.RarityRank(rules,rarity)return rank(rules,rarity)end
-- odds = {seedId = chance} (any scale). Returns the seeds at the floor or above, sorted by id, with their weights, and the total weight.
function R.Kept(rules,floor,odds)
 local need=rank(rules,floor);local ids,total={},0
 if need<1 or type(odds)~='table'then return ids,total end
 for id,p in pairs(odds)do
  if type(p)=='number'and p==p and p>0 and p<math.huge and rank(rules,rules.GetRarity(id))>=need then ids[#ids+1]=id;total+=p end
 end
 table.sort(ids)
 return ids,total
end
local function unit(draw)
 local u=type(draw)=='function'and draw()or draw
 return type(u)=='number'and u==u and math.clamp(u,0,1-1e-12)or 0
end
-- The floored roll: the same arguments SeedPackRules.Roll takes (draw = a function returning [0,1), or a number), with the rules and the floor in front. Returns seed, rarity (nil when the
-- pack has no seed at the floor or above: the open is refused, never a lower seed).
function R.RollFloored(rules,floor,config,stage,draw,luck,variant,version,boost,passLuck)
 if R.CleanFloor(floor)==nil then return nil end
 local odds=rules.SeedOdds(config,stage,variant,luck,version,boost,passLuck)
 local ids,total=R.Kept(rules,floor,odds)
 if #ids==0 or not(total>0)then return nil end
 local ticket=unit(draw)*total
 local pick=ids[#ids]
 for _,id in ipairs(ids)do
  if ticket<odds[id]then pick=id;break end
  ticket-=odds[id]
 end
 local seed=config.GetSeedById(pick)
 if not seed then return nil end
 return seed,rules.GetRarity(pick)
end
return R
