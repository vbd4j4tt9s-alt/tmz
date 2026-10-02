-- V148. Owner tools with explicit server inventory/garden clear jobs.
local Commands={}
local PlayerCommands=require(script.Parent:WaitForChild('OwnerPlayerCommands'))
local ServerClear=require(script.Parent:WaitForChild('ServerClearService'))
local Access=require(script.Parent:WaitForChild('OwnerCommandAccess'))
local Targeting=require(script.Parent.OwnerCommandTargets82)
local TestState=require(script.Parent.OwnerTestState82)
local UpdateCommands=require(script.Parent.OwnerUpdateCommands82)
local Layout=require(script.Parent:WaitForChild('GardenShowcaseLayout'))
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Rules=require(RS:WaitForChild('PlantRules'))
local Packs=require(RS:WaitForChild('SeedPackRules'))
local Names=require(RS:WaitForChild('GardenDisplayNames'))
local Help=require(RS:WaitForChild('StudioTestHelp'))
local biomeIDs={forest=1,jungle=6,desert=2,snow=3,lava=4,crystal=5,storm=7}
local function key(v)return tostring(v or''):lower():gsub('[^%w]','')end
local function number(s,default,minimum,maximum,integer)
 local n=s==nil and default or tonumber(s)
 if type(n)~='number'or n~=n or math.abs(n)==math.huge or n<minimum or n>maximum or(integer and n%1~=0)then return nil end
 return n
end
local function mutation(s)
 local v=key(s or'none');return v=='none'and'None'or v=='gold'and'Gold'or v=='diamond'and'Diamond'or nil
end
local function choose(selector,many)
 selector=key(selector);local list={}
 for _,spec in ipairs(Packs.SeedDesigns)do
  if (many and(selector=='all'or selector==key(spec.biome)))or(not many and(selector==key(spec.id)or selector==key(spec.name)or selector==key(Names.Plant(spec.id,spec.name))))then table.insert(list,spec)end
 end
 return list
end
local function crops(data,player)
 local result={};local garden=data.Gardens[player]
 for slot=1,data.Config.GardenPlotCount do for _,crop in ipairs(garden and garden.Plots[tostring(slot)]or{})do table.insert(result,{Slot=slot,Crop=crop})end end
 return result
end
local function changed(ctx,player,inventory)
 if inventory then ctx.Data:_notifySeedInventory(player);ctx.Chests:SyncTools(player)end
 ctx.Data:MarkDirty(player);ctx.Data:_gardenChanged(player);ctx.Data:QueueGardenSave(player)
 local base=ctx.Bases:GetPlayerBase(player);if base then ctx.Chests:RenderGarden(base,player)end
end
local function character(player)
 local c=player.Character;return c,c and c:FindFirstChildOfClass('Humanoid'),c and c:FindFirstChild('HumanoidRootPart')
end
local function teleport(ctx,player,at)
 local c,h,root=character(player);if not c or not h or not root or h.Health<=0 then return false,'Wait for your character.'end
 ctx.Bases:StopTraining(player,false)
 TestState.ClearMovement(player)
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero;c:PivotTo(at);require(script.Parent.MovementGuard).Reset(player)
 return true,'Teleported.'
end
-- English commands are exact aliases, never executable user code. Default scope is the caller.
function Commands.Normalize(text)
 if type(text)~='string'or #text>220 then return nil end
 local phrase=text:lower():gsub('^%s*',''):gsub('%s*$',''):gsub('%s+',' ')
 phrase=phrase:gsub('^/cctest%s*',''):gsub('^/test%s*',''):gsub('[.!?]+$','')
 phrase=phrase:gsub('^please ','')
 local aliases={
  ['clear my inventory']='clear inventory',['clear inventory']='clear inventory',
  ['clear my seeds']='clear seeds',['clear seeds']='clear seeds',['clear my packs']='clear packs',
  ['clear my garden']='clear plants',['clear garden']='clear plants',['clear my plants']='clear plants',
  ['clear my harvests']='clear harvests',['clear harvests']='clear harvests',
  ['clear everything']='clear all',['clear all my stuff']='clear all',
  ['give me rare packs']='rarepacks',['give rare packs']='rarepacks',['give me all seeds']='seeds all',['give all seeds']='seeds all',['get all seeds']='seeds all',['obtain all seeds']='seeds all',['all seeds']='seeds all',
  ['plant all seeds']='plants all',['plant everything']='plants all',['show all plants']='plants all',
  ['grow my garden']='growall',['grow everything']='growall',['grow all plants']='growall',['finish growing']='growall',
  ['regrow all fruit']='regrow',['regrow fruit']='regrow',['make fruit ready']='regrow',
  ['harvest my garden']='harvestall',['harvest everything']='harvestall',['harvest all']='harvestall',
  ['sell my harvests']='sellall',['sell everything']='sellall',['sell all']='sellall',
  ['go home']='base',['go to my garden']='base',['teleport home']='base',
  ['start flying']='fly',['stop flying']='unfly',['walk through walls']='noclip',['normal collisions']='clip',
  ['heal me']='heal',['respawn me']='respawn',['refresh packs']='refreshpacks',
  ['show my stats']='stats',['show performance']='perf',['show commands']='help',['help me']='help',
  ['give me money']='cash add 100000',['give money']='cash add 100000',['reset my money']='cash set 0',
  ['make me faster']='movespeed 1000',['reset my speed']='speed 0',['upgrade my treadmill']='treadmill 7',
  ['turn effects off']='effects off',['turn effects on']='effects normal',['reduce effects']='effects low',
  ['restart growth']='growth 0',['show baby plants']='growth 0',['grow halfway']='growth 50',['almost grown']='growth 90',
  ['grow quickly']='growtime 30',['list seeds']='catalog all',
  ['clear everyone inventory']='clearinventory all',['clear everyone garden']='cleargarden all',
 }
 if aliases[phrase]then return '/test '..aliases[phrase]end
 -- Multiword plant names work without internal IDs or numeric arguments.
 local selector=phrase:match('^give me (.+) seeds$')or phrase:match('^give (.+) seeds$')or phrase:match('^get (.+) seeds$')
 local single=phrase:match('^give me (.+) seed$')or phrase:match('^give (.+) seed$')or phrase:match('^get (.+) seed$')
 local plant=phrase:match('^plant (.+)$')
 local where=phrase:match('^go to (.+)$')
 if where and biomeIDs[key(where)]then return '/test tp '..key(where)end
 if selector and biomeIDs[key(selector)]then return '/test seeds '..key(selector)end
 for _,spec in ipairs(Packs.SeedDesigns)do
  local alias=key(Names.Plant(spec.id,spec.name))
  if(single and(key(single)==key(spec.name)or key(single)==alias))or(selector and(key(selector)==key(spec.name)or key(selector)==alias))then return '/test seed '..spec.id end
  if plant and(key(plant)==key(spec.name)or key(plant)==alias)then return '/test plant '..spec.id end
 end
 return '/test '..phrase
end

local function executeFor(ctx,player,text,requester)
 if not player or player.Parent~=Players or not ctx.Data:IsLoaded(player)then return false,'Wait for your player data to load.'end
 text=Commands.Normalize(text);if not text then return false,'Invalid command.'end
 local a={};for word in text:gmatch('%S+')do table.insert(a,word)end
 if a[1]~='/test'and a[1]~='/cctest'then return false,'Type help in the F4 command box.'end
 table.remove(a,1);local action=(table.remove(a,1)or'help'):lower()
 if action=='points'then action='speed'elseif action=='tp'then action='biome'end
 if UpdateCommands.Actions[action]then return UpdateCommands.Execute(ctx,player,action,a)end
 local function exact(min,max)return #a>=min and #a<=(max or min)end
 if action=='help'then
  local lines={'OWNER COMMANDS — Public servers: owner / configured admins. Add @username or @all at the end. Inventory, currency and progression changes are saved; movespeed, animrate and flight are temporary.'}
  for _,entry in ipairs(Help)do table.insert(lines,entry[2]==''and entry[1]or entry[1]..' — '..entry[2])end
  return true,table.concat(lines,'\n')
 elseif action=='catalog'then
  if not exact(0,1)then return false,'Use /test catalog [all|biome].'end
  local list=choose(a[1]or'all',true);if #list==0 then return false,'Unknown biome.'end
  local lines={};for _,s in ipairs(list)do table.insert(lines,s.id..' | '..s.biome..' | '..s.rarity..' | '..s.name)end
  return true,table.concat(lines,'\n')
 elseif action=='perf'then
  player:SetAttribute('StudioTestPerf',not player:GetAttribute('StudioTestPerf'));return true,'Performance display toggled.'
 elseif action=='effects'then
  if not exact(1)or(a[1]~='normal'and a[1]~='low'and a[1]~='off')then return false,'Use /test effects normal, low or off.'end
  player:SetAttribute('StudioPlantEffects',a[1]);return true,'Plant effects: '..a[1]
 elseif action=='stats'then
  local records=ctx.Data:GetChestRecords(player);local packs=0
  for _,r in ipairs(records)do if r.Kind=='Pack'then packs+=1 end end
  return true,string.format('Seeds %d | Packs %d | Plants %d | Harvests %d | Cash %.0f | Speed %s',#records-packs,packs,#crops(ctx.Data,player),#ctx.Data.Gardens[player].Harvests,ctx.Data:GetCash(player),ctx.Data:GetOrCreateSpeedValue(player).Value)
 elseif action=='unfly'or action=='clip'then
  player:SetAttribute(action=='unfly'and'StudioTestFlying'or'StudioTestNoclip',false)
  if not player:GetAttribute('StudioTestFlying')and not player:GetAttribute('StudioTestNoclip')then TestState.ClearMovement(player)end
  return true,'Normal '..(action=='unfly'and'movement'or'collisions')..' restored.'
 end
 -- Explicit scope token keeps personal clear commands distinct from server-wide jobs.
 if action=='clearinventory'or action=='cleargarden'then
  if not exact(1)or a[1]~='all'then return false,'Use /test '..action..' all (everyone currently in this server).'end
  if not ctx.ServerClearer then ctx.ServerClearer=ServerClear.new(ctx)end
  return ctx.ServerClearer:Request(requester,action=='clearinventory'and 'inventory'or 'garden')
 end
 -- Mutations wait until normal game transactions are finished.
 if ctx.Chase:IsPlayerBusy(player)or player:GetAttribute('ChestChaseRunActive')or player:GetAttribute('ChestChaseSeedCarrying')then return false,'Finish your chase before using this test command.'end
 if ctx.Chests:IsOpening(player)then return false,'Wait for the pack to finish opening.'end
 local data,config=ctx.Data,ctx.Config
 if action=='fly'or action=='noclip'then
  local speed=number(a[1],60,10,300,false)
  if not exact(0,action=='fly'and 1 or 0)or not speed then return false,'Use /test fly [10–300] or /test noclip.'end
  local _,h,root=character(player);if not h or h.Health<=0 or not root then return false,'Wait for your character.'end
  if player:GetAttribute('GuardianRagdollActive')then return false,'Wait until your ragdoll recovers.'end
  ctx.Bases:StopTraining(player,false)
  TestState.GrantMovement(player)
  if action=='fly'then player:SetAttribute('StudioTestFlySpeed',speed);player:SetAttribute('StudioTestFlying',true)
  else player:SetAttribute('StudioTestNoclip',true)end
  return true,action=='fly'and'Flying: WASD, Space/E up, Ctrl/Q down. /test unfly to stop.'or'Noclip enabled. /test clip to restore collisions.'
 elseif action=='base'then
  local base=ctx.Bases:GetPlayerBase(player);if not base then return false,'Base not ready.'end
  return teleport(ctx,player,base.Spawn.CFrame*CFrame.new(0,4,0))
 elseif action=='biome'then
  local stage=biomeIDs[key(a[1])];if not exact(1)or not stage then return false,'Unknown biome. Use forest, jungle, desert, snow, lava, crystal or storm.'end
  if ctx.Map.Refreshing then return false,'Wait until the biome refresh ends.'end
  local z=config.BiomeTrackStartZ
  for _,id in ipairs(config.BiomeOrder)do if id==stage then break end;z+=config.BiomeRunLengths[id]end
  local at=ctx.Map:GetRefreshReturnCFrame(1);local x=ctx.Map.BaseBoundaryLine.Position.X
  local point=Vector3.new(x,at.Position.Y,z+15)
  return teleport(ctx,player,CFrame.lookAt(point,point+Vector3.new(0,0,1)))
 elseif action=='rarepacks'then
  if not exact(0,1)then return false,'Use /test rarepacks [rarity].'end
  local okay,message=require(script.Parent.RarePackTests).Grant(data,player,a[1],requester)
  if okay then ctx.Chests:SyncTools(player)end
  return okay,message
 elseif action=='seed'or action=='seeds'or action=='pack'then
  local isPack=action=='pack';local many=action=='seeds'
  if not exact(1,isPack and 5 or many and 3 or 4)then return false,'See /test help for grant syntax.'end
  local tier=3;if isPack then tier=number(a[2],3,1,6,true)end
  local size=number(a[isPack and 3 or 2],1,isPack and .5 or .35,25,false)
  local coat=mutation(a[isPack and 4 or 3]);local count=number(a[isPack and 5 or 4],1,1,100,true)
  if not tier or not size or not coat or not count then return false,'Invalid tier, size, mutation or count. See /test help.'end
  local selected=choose(a[1],many or isPack)
  if #selected==0 or(isPack and not biomeIDs[key(a[1])])then return false,'Unknown seed/biome. Use /test catalog.'end
  if isPack then selected={selected[1]}end
  local records=data:GetChestRecords(player);if #records+#selected*count>config.MaxSavedChests then return false,'Inventory full. Clear some seeds or packs first.'end
  local pending={};local serial=player:GetAttribute('ChestInventorySerial')or 0
  for _,spec in ipairs(selected)do
   local seed=config.GetSeedById(spec.id);if not seed then return false,'Seed catalog mismatch.'end
   for _=1,count do
    serial+=1;local variant=string.format('Pack%02d',tier)
    table.insert(pending,{Id=HttpService:GenerateGUID(false),Kind=isPack and'Pack'or'Seed',ChestNumber=serial,ChestName=seed.Name,
     Stage=spec.stage,SeedId=seed.Id,SeedName=seed.Name,SeedEmoji=seed.Emoji,AccentColor=seed.Color,Rarity=spec.rarity,
     SeedScale=isPack and Packs.NewSeedScale(spec.stage,variant,size)or Packs.SanitizeSeedScale(size),
     BagVariant=variant,OddsVersion=isPack and Packs.OddsVersion or nil,PackSize=isPack and size or 1,PackMutation=coat})
   end
  end
  player:SetAttribute('ChestInventorySerial',serial)
  for _,record in ipairs(pending)do table.insert(records,record);if not isPack then data:MarkSeedDiscovered(player,record.SeedId,true)end end
  changed(ctx,player,true);return true,'Added '..#pending..(isPack and' packs.'or' seeds.')
 elseif action=='plant'or action=='plants'then
  if not exact(1,3)then return false,'Use /test plant <SeedId> [size] [mutation].'end
  local selected=choose(a[1],action=='plants');local size=number(a[2],1,.35,25,false);local coat=mutation(a[3])
  if #selected==0 or not size or not coat then return false,'Invalid seed, plant size (.35–25) or mutation.'end
  local base=ctx.Bases:GetPlayerBase(player);if not base then return false,'Base not ready.'end
  local garden=data.Gardens[player];local count=0;local now=os.time()
  for _,spec in ipairs(selected)do
   local definition=Catalog[spec.id];local spot
   spot=Layout.Find(config,garden,spec.id,math.min(size,3),ctx.Chests.GardenPlots and ctx.Chests.GardenPlots[base.Index])
   if not spot then break end
   local crop=Rules.NewCrop({Id=HttpService:GenerateGUID(false),SeedId=spec.id,SeedScale=1,PackMutation=coat},HttpService:GenerateGUID(false),definition,now-definition.Seconds,spot[2],spot[3])
   crop.PlantScale=size;local slot=tostring(spot[1]);garden.Plots[slot]=garden.Plots[slot]or{};table.insert(garden.Plots[slot],crop);count+=1
  end
  if count>0 then changed(ctx,player,false)end
  return count>0,'Added '..count..' of '..#selected..' mature plants. Spacing uses mature plant size. If fewer fit, use another bed or a smaller size.'
 elseif action=='growth'or action=='growall'or action=='growtime'or action=='regrow'then
  local value=100
  if action=='growth'then value=number(a[1],nil,0,100,false)elseif action=='growtime'then value=number(a[1],nil,1,3600,true)end
  if not value or not exact((action=='growth'or action=='growtime')and 1 or 0)then return false,'Use /test growth <0–100>, growall, growtime <1–3600> or regrow.'end
  local now=os.time();local count=0
  for _,entry in ipairs(crops(data,player))do
   local crop=entry.Crop
   if action~='regrow'or now>=crop.MatureAt then
    if action=='regrow'then crop.ReadyAt=now
    elseif action=='growtime'then crop.PlantedAt=now;crop.MatureAt=now+value;crop.ReadyAt=crop.MatureAt
    else crop.PlantedAt=now-math.floor(value*10);crop.MatureAt=crop.PlantedAt+1000;crop.ReadyAt=crop.MatureAt end
    crop.FruitStates=nil;crop.PickedMask=0;crop.HarvestCycle=(crop.HarvestCycle+1)%1000000000;count+=1
   end
  end
  changed(ctx,player,false);return true,'Updated '..count..' plants.'
 elseif action=='harvestall'then
  local count=0;local now=os.time()
  for _,entry in ipairs(crops(data,player))do
   local crop=entry.Crop;local def=Catalog[crop.SeedId]
   if now>=crop.ReadyAt then for index=1,def.FruitCount do
    if not Rules.IsPicked(crop,index)and data:HarvestPlant(player,entry.Slot,crop.Id,now,index)then count+=1 end
   end end
  end
  changed(ctx,player,false);return true,'Harvested '..count..' items. Bag capacity: '..config.MaxSavedHarvests..'.'
 elseif action=='sellall'then
  local items=table.clone(data.Gardens[player].Harvests);local count,total=0,0
  for _,item in ipairs(items)do local ok,value=data:SellHarvest(player,item.Id);if ok then count+=1;total+=value end end
  changed(ctx,player,false);return true,'Sold '..count..' crops for '..total..' coins. Hover over the floating cash to collect.'
 elseif action=='cash'then
  local value=number(a[2],nil,0,require(RS.EconomyBalance90).MaxCash,true)
  if not exact(2)or not value or(a[1]~='set'and a[1]~='add')then return false,'Use /test cash set <amount> or /test cash add <amount>.'end
  if a[1]=='add'then value+=data:GetCash(player)end
  local pending=require(RS.SaleReceiptRules).Total((data.Gardens[player]or{}).PendingSales or{},'Cash')
  if value+pending>require(RS.EconomyBalance90).MaxCash then return false,'Cash cap is 900 trillion including pending rewards.'end
  data:GetOrCreateCashValue(player).Value=value;data:MarkDirty(player);data:QueueGardenSave(player);return true,'Cash: '..value
 elseif action=='speed'then
  local value=a[1];if not exact(1)or not require(game:GetService('ReplicatedStorage').SpeedPoints).Valid(value)then return false,'Use /test speed <nonnegative whole points>.'end
  local speed=data:GetOrCreateSpeedValue(player);speed.Value=config.NormalizeSpeedStat(value)
  local _,h=character(player);if h then ctx.Bases:_applyPhysicalSpeed(player,h,speed.Value)end
  data:MarkDirty(player);data:QueueGardenSave(player);return true,'Trained speed: '..speed.Value
 elseif action=='treadmill'then
  local tier=number(a[1],nil,1,#config.TreadmillTiers,true);if not exact(1)or not tier then return false,'Use /test treadmill <1–7>.'end
  local t=data:GetTreadmillData(player);t.Tier=tier;t.Skin=tier
  for i=1,tier do t.Cleared[tostring(config.TreadmillTiers[i].Stage)]=true end
  data:PublishTreadmillData(player);ctx.Bases:RefreshTreadmill(player);data:MarkDirty(player);data:QueueGardenSave(player)
  return true,'Treadmill: '..config.TreadmillTiers[tier].Name
 elseif action=='clear'then
  local what=key(a[1]);local valid={inventory=true,seeds=true,packs=true,plants=true,harvests=true,all=true}
  if not exact(1)or not valid[what]then return false,'Clear inventory, seeds, packs, plants, harvests or all.'end
  local count=0;local inventory=what=='inventory'or what=='seeds'or what=='packs'or what=='all'
  if inventory then
   local _,h=character(player);if h then h:UnequipTools()end
   local records=data:GetChestRecords(player)
   for i=#records,1,-1 do if what=='inventory'or what=='all'or(what=='packs')==(records[i].Kind=='Pack')then table.remove(records,i);count+=1 end end
  end
  local garden=data.Gardens[player]
  if what=='plants'or what=='all'then for _,list in pairs(garden.Plots)do count+=#list;table.clear(list)end end
  if what=='harvests'or what=='all'then count+=#garden.Harvests;table.clear(garden.Harvests)end
  changed(ctx,player,inventory);return true,'Cleared '..count..' items ('..what..').'
 elseif action=='heal'then
  local _,h=character(player);if not h then return false,'Wait for your character.'end;h.Health=h.MaxHealth;return true,'Healed.'
 elseif action=='respawn'then
  TestState.ClearMovement(player);ctx.Bases:StopTraining(player,false)
  player:LoadCharacterAsync();return true,'Respawned.'
 elseif action=='refreshpacks'then
  if ctx.Map.Refreshing then return false,'Refresh already running.'end
  ctx.Chase:_beginBiomeRefresh(os.clock());return true,'Started this server’s normal biome refresh.'
 end
 return false,'Unknown command. Type help in the F4 command box.'
end
-- Authority is checked on the caller, never on a command's recipient.
function Commands.Execute(ctx,requester,text)
 if not Access.IsAllowed(requester)then return false,'These commands are for the experience owner or configured admins.'end
 if not ctx.Data:IsLoaded(requester)then return false,'Wait for your player data to load.'end
 local body,selector,why=Targeting.Split(text);if not body then return false,why end
 if not selector then
  local english=PlayerCommands.Parse(body)
  if english then return PlayerCommands.Execute(ctx,requester,english)end
 end
 local normalized=Commands.Normalize(body);if not normalized then return false,'Invalid command.'end
 if selector and Targeting.IsGlobal(normalized)then return false,'This command affects the server once; omit @target.'end
 local targets={requester}
 if selector then targets,why=PlayerCommands.Resolve(requester,selector);if not targets then return false,why end end
 ctx.TargetCommandBusy=ctx.TargetCommandBusy or setmetatable({},{__mode='k'})
 local reports,successes={},0
 for _,target in ipairs(targets)do
  local ok,message
  if ctx.TargetCommandBusy[target]then ok=false;message='Another command is updating this player. Try again.'
  else
   ctx.TargetCommandBusy[target]=true
   local safe;safe,ok,message=pcall(executeFor,ctx,target,normalized,requester)
   ctx.TargetCommandBusy[target]=nil
   if not safe then warn('[Owner Command] '..tostring(ok));ok=false;message='Command failed; check server Output.'end
  end
  if not selector then return ok,message end
  if ok then successes+=1 end
  table.insert(reports,'@'..target.Name..': '..(ok and ''or 'Skipped — ')..tostring(message))
 end
 return successes>0,table.concat(reports,'\n')
end
function Commands.Start(config,data,chests,chase,bases,notifications,map)
 if Commands.Running then return end
 local ctx={Config=config,Data=data,Chests=chests,Chase=chase,Bases=bases,Map=map}
 local chat=game:GetService('TextChatService')
 for _,item in ipairs(chat:GetDescendants())do if item:IsA('TextChatCommand')then
  for _,alias in ipairs({'/test','/cctest'})do assert(item.PrimaryAlias~=alias and item.SecondaryAlias~=alias,'Test command alias already used: '..alias)end
 end end
 local connections,instances,last,busy={},{},{},{}
 local folder=Instance.new('Folder');folder.Name='ChestChaseStudioTests';table.insert(instances,folder)
 local feedback=Instance.new('RemoteEvent');feedback.Name='Feedback';feedback.Parent=folder
 ctx.ClearFeedback=function(player,ok,message)feedback:FireClient(player,ok,message)end
 local request=Instance.new('RemoteFunction');request.Name='Execute';request.Parent=folder
 local function execute(player,text)
  if not Access.Publish(player)then return false,'These commands are for the experience owner.'end
  local now=os.clock();if busy[player]or now-(last[player]or-math.huge)<.35 then return false,'Wait a moment.'end
  last[player]=now;busy[player]=true
  local safe,ok,message=pcall(Commands.Execute,ctx,player,text);busy[player]=nil
  if not safe then warn('[Owner Command] '..tostring(ok));ok=false;message='Command failed. Check server Output.'end
  if player.Parent==Players then feedback:FireClient(player,ok,message)end
  print('[Owner Command] '..player.Name..': '..tostring(message));return ok,message
 end
 local controller={}
 function controller:Destroy()
  if ctx.ServerClearer then ctx.ServerClearer:Destroy()end
  for _,c in ipairs(connections)do c:Disconnect()end
  for _,item in ipairs(instances)do item:Destroy()end
  for _,p in ipairs(Players:GetPlayers())do TestState.Clear(p);p:SetAttribute('ChestChaseCommandsAllowed',false)end
  Commands.Running=nil
 end
 request.OnServerInvoke=execute
 local cmd=Instance.new('TextChatCommand');cmd.Name='ChestChaseTests';cmd.PrimaryAlias='/test';cmd.SecondaryAlias='/cctest';cmd.AutocompleteVisible=RunService:IsStudio()
 table.insert(instances,cmd);table.insert(connections,cmd.Triggered:Connect(function(source,text)if source then execute(Players:GetPlayerByUserId(source.UserId),text)end end));cmd.Parent=chat
 local bind=Instance.new('BindableFunction');bind.Name='ChestChaseTestCommands';bind.OnInvoke=execute;bind.Parent=game:GetService('ServerStorage');table.insert(instances,bind)
 local function hook(p)
  task.spawn(function()Access.Publish(p)end)
  table.insert(connections,p.CharacterAdded:Connect(function(character)
   TestState.Clear(p)
   task.spawn(function()local h=character:WaitForChild('Humanoid',10)
    if h and p.Character==character and data:IsLoaded(p)then bases:_applyPhysicalSpeed(p,h,data:GetOrCreateSpeedValue(p).Value)end
   end)
  end))
 end
 for _,p in ipairs(Players:GetPlayers())do hook(p)end
 table.insert(connections,Players.PlayerAdded:Connect(hook));table.insert(connections,Players.PlayerRemoving:Connect(function(p)last[p]=nil;busy[p]=nil;TestState.Clear(p)end))
 table.insert(connections,script.Destroying:Connect(function()controller:Destroy()end))
 folder.Parent=RS;Commands.Running=controller
 task.spawn(function()
  while Commands.Running==controller do
   task.wait(30)
   if Commands.Running~=controller then break end
   for _,p in ipairs(Players:GetPlayers())do Access.Publish(p)end
  end
 end)
 print('[R82] Owner tools ready: /test help or F4. Live changes save to the current profile.')
 return controller
end
return Commands
