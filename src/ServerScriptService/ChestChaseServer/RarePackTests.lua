-- R82: owner-issued guaranteed reveal overrides live only in this server's memory.
local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage')
local Http=game:GetService('HttpService');local Packs=require(RS.SeedPackRules)
local T={Rarities={'Legendary','Mythic','Secret','Cosmic','King'},Random=Random.new()}
local Verity=require(RS.VerityCatalog)
-- R154 (owner: "the mythic forest pack can only roll elderbloom"): a rarity pack reveals a RANDOM real seed of that rarity, not the roster's first one (Mythic was always
-- Elderbloom). The command names no biome, so it is any biome: every seed of that rarity a biome pack can roll today (the live pools of stages 1-7: no retired seed, no
-- Mech or Verity seed: those have their own words), evenly; the TEST pack is that seed's biome's pack. Returns {spec, stage} or nil.
function T.Candidates(config,rarity)
 local out={}
 for stage=1,7 do for _,seed in ipairs(Packs.ObtainablePool(config,stage)or{})do
  local spec=Packs.SeedDesignById[seed.Id]
  if spec and Packs.GetRarity(seed.Id)==rarity then out[#out+1]={Spec=spec,Stage=stage}end
 end end
 table.sort(out,function(x,y)return x.Spec.id<y.Spec.id end)
 return out
end
function T.Pick(config,rarity)
 local list=T.Candidates(config,rarity)
 if #list==0 then return nil end
 return list[T.Random:NextInteger(1,#list)]
end
function T.Grant(data,player,selector,requester)
 if not require(script.Parent.OwnerCommandAccess).IsAllowed(requester or player)then return false,'Owner or configured admin required.'end
 if not data:IsLoaded(player)then return false,'Wait for your data to load.'end
 selector=tostring(selector or'all'):lower();local selected={}
 for _,rarity in ipairs(T.Rarities)do if selector=='all'or selector==rarity:lower()then
  local found=T.Pick(data.Config,rarity) -- R154: a random one (was the first in the roster)
  if not found then return false,'No active seed for '..rarity end
  table.insert(selected,{Spec=found.Spec,Stage=found.Stage,Rarity=rarity})
 end end
 if selector=='mech'then for _,s in ipairs(require(RS.MechCatalog).Seeds)do table.insert(selected,Packs.SeedDesignById[s.Id])end end
 -- R147: rarepacks verity = one TEST Verity pack that reveals the Verity seed (a Verity pack, stage 7; the seed lands in Index category 9).
 if selector=='verity'then table.insert(selected,Packs.SeedDesignById[Verity.Id])end
 -- R148: rarepacks roster = four TEST packs that reveal the roster change's seeds (Fire Pepper, Moon Melon, Aloe, Sand Fruit).
 if selector=='roster'then for _,id in ipairs({'FirePepperSeed','MoonflowerSeed','DesertAloeSeed','SandFruitSeed'})do table.insert(selected,Packs.SeedDesignById[id])end end
 if #selected==0 then return false,'Use /test rarepacks [mech|verity|roster|legendary|mythic|secret|cosmic|king].'end
 local records=data:GetChestRecords(player)
 if #records+#selected>data.Config.MaxSavedChests then return false,'Inventory full. Make space first.'end
 local pending={};local serial=player:GetAttribute('ChestInventorySerial')or 0
 for _,pick in ipairs(selected)do
  if pick.Spec==nil then pick={Spec=pick}end -- (mech / verity / roster: a plain spec)
  local spec=pick.Spec
  local seed=data.Config.GetSeedById(spec.id);if not seed then return false,'Seed catalog mismatch.'end
  serial+=1;table.insert(pending,{Id=Http:GenerateGUID(false),Kind='Pack',ChestNumber=serial,ChestName=seed.Name,
   Stage=Verity.Is(spec.id)and Verity.PackStage or pick.Stage or spec.stage,SeedId=seed.Id,SeedName=seed.Name,SeedEmoji=seed.Emoji,AccentColor=seed.Color,Rarity=pick.Rarity or spec.rarity,
   SeedScale=1,OddsVersion=Verity.Is(spec.id)and Packs.OddsVersion or 81,BagVariant=Verity.Is(spec.id)and Verity.Variant or spec.stage==8 and'MechLimited'or'Pack06',PackSize=1,PackMutation='None',TestGrant=true,
   PackShape=require(game:GetService('ReplicatedStorage').PackShapes151).Roll(Verity.Is(spec.id)and Verity.Variant or spec.stage==8 and'MechLimited'or'Pack06')}) -- R151: also marked on the record (never announced); it rolls its chip-bag shape like any pack
 end
 data.StudioPackRewards=data.StudioPackRewards or setmetatable({},{__mode='k'})
 local overrides=data.StudioPackRewards[player]or{};data.StudioPackRewards[player]=overrides
 for _,record in ipairs(pending)do table.insert(records,record);overrides[record.Id]=record.SeedId end
 player:SetAttribute('ChestInventorySerial',serial)
 data:_notifySeedInventory(player);data:MarkDirty(player);data:QueueGardenSave(player)
 return true,'Added '..#pending..' guaranteed reveal packs. Open the TEST packs in this server session; guarantees expire when you leave.'
end
function T.Expected(data,player,id)
 local records=data.StudioPackRewards and data.StudioPackRewards[player]
 return records and records[id]
end
return T
