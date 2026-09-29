-- R82: owner-issued guaranteed reveal overrides live only in this server's memory.
local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage')
local Http=game:GetService('HttpService');local Packs=require(RS.SeedPackRules)
local T={Rarities={'Legendary','Mythic','Secret','Cosmic','King'}}
function T.Grant(data,player,selector,requester)
 if not require(script.Parent.OwnerCommandAccess).IsAllowed(requester or player)then return false,'Owner or configured admin required.'end
 if not data:IsLoaded(player)then return false,'Wait for your data to load.'end
 selector=tostring(selector or'all'):lower();local selected={}
 for _,rarity in ipairs(T.Rarities)do if selector=='all'or selector==rarity:lower()then
  local found
  for _,spec in ipairs(Packs.SeedDesigns)do if spec.rarity==rarity then found=spec;break end end
  if not found then return false,'No active seed for '..rarity end
  table.insert(selected,found)
 end end
 if selector=='mech'then for _,s in ipairs(require(RS.MechCatalog).Seeds)do table.insert(selected,Packs.SeedDesignById[s.Id])end end
 if #selected==0 then return false,'Use /test rarepacks [mech|legendary|mythic|secret|cosmic|king].'end
 local records=data:GetChestRecords(player)
 if #records+#selected>data.Config.MaxSavedChests then return false,'Inventory full. Make space first.'end
 local pending={};local serial=player:GetAttribute('ChestInventorySerial')or 0
 for _,spec in ipairs(selected)do
  local seed=data.Config.GetSeedById(spec.id);if not seed then return false,'Seed catalog mismatch.'end
  serial+=1;table.insert(pending,{Id=Http:GenerateGUID(false),Kind='Pack',ChestNumber=serial,ChestName=seed.Name,
   Stage=spec.stage,SeedId=seed.Id,SeedName=seed.Name,SeedEmoji=seed.Emoji,AccentColor=seed.Color,Rarity=spec.rarity,
   SeedScale=1,OddsVersion=81,BagVariant=spec.stage==8 and'MechLimited'or'Pack06',PackSize=1,PackMutation='None'})
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
