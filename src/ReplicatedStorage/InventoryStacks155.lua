-- R155 (owner: "make it function like the normal inventory ... make the max amount of items a person can hold 200", then "allow people to discard
-- items"): what one inventory item IS, shared by the Hotbar / Bag (client) and the server's discard (InventoryService155), so both see the same stacks.
--  * Key(tool)   the stack an item joins: identical packs, seeds and fruit share one hotbar slot / Bag card with a count (R112; the exact key the
--                Hotbar used from R112 to R154, so a layout saved by R155 matches what every client shows). Tools that never stack (the bat, a legacy
--                loot item) and the shovel have no stack key.
--  * Kind(tool)  'Pack' | 'Seed' | 'Fruit' | 'Loot' (an item: it counts toward the 200 cap and can be discarded) | 'Shovel' | 'Tool' (gear: the bat ...).
--  * Id(tool)    the saved record behind an item (SeedInventoryId, HarvestInventoryId, LootInstanceName).
--  * Hash(key)   8 hex characters for a stack key: the saved hotbar layout (Hotbar155) stores these, never the long keys.
-- A stack of N counts N toward the cap: the server and the save hold N separate records (each with its own id, size, weight and traits; each is opened,
-- planted, gifted and sold on its own); a stack is only how the inventory DRAWS identical records.
local S={}
-- The cap: items a player can hold (packs + seeds + fruit + loot items). The server's PlayerDataService:HeldItemCap() reads it (a Config.MaxHeldItems would
-- override it; Config.lua itself is left as it was: older suites keep it byte-identical), the Bag shows it before the server's own count arrives.
S.Cap=200
S.Fields={Pack={'Stage','BagVariant','PackSize','PackMutation','Weather','SeedScale','PackShape'}, -- (R151: packs of different chip-bag shapes never share a card)
 Seed={'SeedId','SeedScale','Mutation','Weather','Rarity'},
 Fruit={'SeedId','FruitScale','Mutation','Weather','SellValue','FruitName','FruitIndex','Rarity'}}
local function attr(tool,name)local ok,v=pcall(tool.GetAttribute,tool,name);if ok then return v end;return nil end
function S.Group(tool)
 if attr(tool,'SeedPackTool')then return'Pack'end
 if attr(tool,'GardenSeed')then return'Seed'end
 if attr(tool,'HarvestItemTool')then return'Fruit'end
 return nil
end
function S.Key(tool)
 local group=S.Group(tool);if not group then return nil end
 local parts={group,tool.Name};for _,field in ipairs(S.Fields[group])do parts[#parts+1]=tostring(attr(tool,field))end
 return 'stack|'..table.concat(parts,'|')
end
function S.Kind(tool)
 local group=S.Group(tool);if group then return group end
 if attr(tool,'LootItemTool')then return'Loot'end
 if attr(tool,'GardenShovel')then return'Shovel'end
 return'Tool'
end
local counted={Pack=true,Seed=true,Fruit=true,Loot=true}
function S.Counts(tool)return counted[S.Kind(tool)]==true end
function S.Id(tool)
 local kind=S.Kind(tool)
 if kind=='Pack'or kind=='Seed'then return attr(tool,'SeedInventoryId')end
 if kind=='Fruit'then return attr(tool,'HarvestInventoryId')end
 if kind=='Loot'then return attr(tool,'LootInstanceName')end
 return nil
end
-- (sdbm over the bytes, 32 bits: a few hundred keys never meet; a clash would only put one item on the wrong slot when the layout is restored)
function S.Hash(key)
 local h=0;key=tostring(key)
 for i=1,#key do h=(string.byte(key,i)+h*65599)%4294967296 end
 return string.format('%08x',h)
end
return S
