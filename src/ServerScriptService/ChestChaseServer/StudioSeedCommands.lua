-- Chest Chase testing commands v1, for V138/V139. No published-server commands.
-- TextChatCommand reference: https://create.roblox.com/docs/reference/engine/classes/TextChatCommand
local Commands={}
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Rules=require(game:GetService("ReplicatedStorage"):WaitForChild("SeedPackRules"))
local function key(value)return (value:lower():gsub("[^%w]",""))end

function Commands.Execute(config,data,chests,chase,player,text)
 if not RunService:IsStudio()then return false,"Studio testing only."end
 if not player or player.Parent~=Players then return false,"Player unavailable."end
 if not data:IsLoaded(player)then return false,"Wait for your inventory to load."end
 if type(text)~="string"or #text>180 then return false,"Invalid command."end
 local args={};for word in text:gmatch("%S+")do table.insert(args,word)end
 local action=(args[1]or ""):lower()
 if action~="/seed"and action~="/seeds"and action~="/clearinventory"then return false,"Unknown seed command."end
 if chase:IsPlayerBusy(player)or player:GetAttribute("ChestChaseRunActive")or player:GetAttribute("ChestChaseSeedCarrying")then
  return false,"Finish your chase first."
 end
 if chests:IsOpening(player)then return false,"Wait for your pack to finish opening."end
 local records=data:GetChestRecords(player)
 if action=="/clearinventory"then
  if #args~=1 then return false,"Use /clearinventory"end
  chests:_finishOpening(player,chests.Openings[player],true)
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if humanoid then humanoid:UnequipTools()end
  local count=#records;table.clear(records)
  data:_notifySeedInventory(player);data:MarkDirty(player);chests:SyncTools(player);data:QueueGardenSave(player)
  return true,"Cleared "..count.." seeds/packs."
 end
 local size=1
 if #args>=3 and tonumber(args[#args])then size=tonumber(table.remove(args))end
 if size~=size or size<.35 or size>Rules.MaxSeedScale then return false,"Seed size must be 0.35 to "..Rules.MaxSeedScale.."."end
 size=Rules.SanitizeSeedScale(size)
 local chosen={}
 local selector=key(table.concat(args," ",2))
 if action=="/seeds"then
  if #args~=2 then return false,"Use /seeds all or /seeds forest"end
  for _,spec in ipairs(Rules.SeedDesigns)do
   if selector=="all"or selector==key(spec.biome)then table.insert(chosen,spec)end
  end
 else
  -- Prefer stable exact IDs; otherwise accept the plant's name, with or without spaces.
  for _,spec in ipairs(Rules.SeedDesigns)do if selector==key(spec.id)then chosen={spec};break end end
  if #chosen==0 then for _,spec in ipairs(Rules.SeedDesigns)do if selector==key(spec.name)then chosen={spec};break end end end
 end
 if #chosen==0 then return false,action=="/seeds"and "Biomes: forest, jungle, desert, snow, lava, crystal, storm."or "Seed not found. Try /seed StormSovereignSeed"end
 if #records+#chosen>config.MaxSavedChests then return false,"Inventory full. Use /clearinventory first."end
 -- Prepare the complete batch before committing; no yielding or duplicate IDs.
 local pending={};local serial=player:GetAttribute("ChestInventorySerial")or 0
 for _,spec in ipairs(chosen)do
  local seed=config.GetSeedById(spec.id);if not seed then return false,"Seed catalog needs an update."end
  serial+=1
  table.insert(pending,{Id=string.format("%d_%d",player.UserId,serial),Kind="Seed",ChestNumber=serial,
   ChestName=seed.Name,Stage=spec.stage,SeedId=seed.Id,SeedName=seed.Name,SeedEmoji=seed.Emoji,
   AccentColor=seed.Color,Rarity=spec.rarity,SeedScale=size,BagVariant="Pack03",PackSize=1,PackMutation="None",TestGrant=true}) -- R152: a Studio-granted seed is a TEST seed
 end
 player:SetAttribute("ChestInventorySerial",serial)
 for _,record in ipairs(pending)do table.insert(records,record);data:MarkSeedDiscovered(player,record.SeedId,true)end
 data:_notifySeedInventory(player);data:MarkDirty(player);chests:SyncTools(player);data:QueueGardenSave(player)
 return true,"Added "..#pending.." seed"..(#pending==1 and ""or "s").." ("..size.."x)."
end

function Commands.Start(config,data,chests,chase,notifications)
 if not RunService:IsStudio()then return end
 if Commands.Running then return end
 local chat=game:GetService("TextChatService")
 local aliases={"/seed","/seeds","/clearinventory"}
 for _,item in ipairs(chat:GetDescendants())do
  if item:IsA("TextChatCommand")then for _,alias in ipairs(aliases)do
   assert(item.PrimaryAlias~=alias and item.SecondaryAlias~=alias,"Seed test command alias already in use: "..alias)
  end end
 end
 local connections,instances,last={},{},{}
 local controller={}
 function controller:Destroy()
  for _,c in ipairs(connections)do c:Disconnect()end
  for _,item in ipairs(instances)do item:Destroy()end
  table.clear(last);Commands.Running=nil
 end
 local function execute(player,text)
  if not RunService:IsStudio()or not player or player.Parent~=Players then return false,"Studio testing only."end
  local now=os.clock();if now-(last[player]or -math.huge)<.5 then return false,"Wait a moment."end
  last[player]=now
  local okay,success,message=pcall(Commands.Execute,config,data,chests,chase,player,text)
  if not okay then warn("[Seed Test] "..tostring(success));success=false;message="Command failed. Check Studio Output."end
  notifications:Show(player,message,success and Color3.fromRGB(117,236,164)or Color3.fromRGB(255,163,118),3)
  print("[Seed Test] "..player.Name..": "..message)
  return success,message
 end
 local okay,why=pcall(function()
  for index,alias in ipairs(aliases)do
   local command=Instance.new("TextChatCommand");table.insert(instances,command)
   command.Name="ChestChaseSeedTest"..index;command.PrimaryAlias=alias;command.AutocompleteVisible=true
   table.insert(connections,command.Triggered:Connect(function(source,text)
    if source then execute(Players:GetPlayerByUserId(source.UserId),text)end
   end))
   command.Parent=chat
  end
  -- Optional server Command Bar access if chat is unavailable; this is not a RemoteFunction.
  local bind=Instance.new("BindableFunction");table.insert(instances,bind)
  bind.Name="ChestChaseSeedTest";bind.OnInvoke=execute;bind.Parent=game:GetService("ServerStorage")
  table.insert(connections,Players.PlayerRemoving:Connect(function(player)last[player]=nil end))
  table.insert(connections,script.Destroying:Connect(function()controller:Destroy()end))
 end)
 if not okay then controller:Destroy();error(why)end
 Commands.Running=controller
 print("[Seed Test] Ready: /seeds all | /seeds forest | /seed StormSovereignSeed | /clearinventory")
 return controller
end
return Commands
