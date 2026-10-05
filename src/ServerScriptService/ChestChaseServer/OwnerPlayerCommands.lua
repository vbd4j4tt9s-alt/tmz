-- Explicit server-owned administration of online players; no client-supplied authority.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Http=game:GetService('HttpService')
local Access=require(script.Parent:WaitForChild('OwnerCommandAccess'))
local Packs=require(RS:WaitForChild('SeedPackRules'))
local Names=require(RS:WaitForChild('GardenDisplayNames'))
local Admin={}
local function key(v)return tostring(v or''):lower():gsub('[^%w]','')end
local function clean(v)return v:lower():gsub('^%s*',''):gsub('%s*$',''):gsub('%s+',' '):gsub('[.!?]+$','')end
function Admin.Parse(text)
 if type(text)~='string'or #text>220 then return nil end
 local s=clean(text):gsub('^/cctest%s+',''):gsub('^/test%s+',''):gsub('^please ',''):gsub('^take away ','take ')
 local item,target=s:match('^give (.+) to (.+)$');local op='give'
 if not item then item,target=s:match('^take (.+) from (.+)$');op='take'end
 if not item then local verb,who,what=s:match('^(%a+) (@?[%w_]+) (.+)$');if verb=='give'or verb=='take'then op=verb;target=who;item=what end end
 if item and item:match(' seeds?$')then return {Operation=op,Target=target,Item=item}end
 local what,who=s:match('^clear (inventory) of (.+)$')
 if not what then what,who=s:match('^clear (garden) of (.+)$')end
 if not what then what,who=s:match('^clear (seeds) of (.+)$')end
 if not what then what,who=s:match('^clear (harvests) of (.+)$')end
 if not what then
  who,what=s:match('^clear (.+) (%a+)$')
  if who then who=who:gsub("'s$",''):gsub('s’$','')end
 end
 if not who then what=s:match('^clear (%a+)$');who=what and'me'or nil end
 if what and({inventory=true,garden=true,plants=true,seeds=true,packs=true,harvests=true})[what]and who then
  return {Operation='clear',Target=who,Item=what=='plants'and'garden'or what}
 end
 return nil
end
function Admin.Resolve(requester,query)
 query=clean(query):gsub('^@','')
 if query=='me'or query=='my'then return {requester}end
 if query=='everyone'or query=='everybody'or query=='all'then return Players:GetPlayers()end
 local exactDisplay,prefix={},{}
 for _,p in ipairs(Players:GetPlayers())do
  if p.Name:lower()==query then return {p}end
  if (p.DisplayName or p.Name):lower()==query then table.insert(exactDisplay,p)end
  if p.Name:lower():sub(1,#query)==query then table.insert(prefix,p)end
 end
 local matches=#exactDisplay>0 and exactDisplay or prefix
 if #matches==1 then return matches end
 return nil,#matches>1 and'Ambiguous player name. Use their exact @username.'or'Player not found in this server. Use their @username.'
end
local function selection(text)
 local many=text:match('seeds$')~=nil;local name=text:gsub(' seeds?$','');local size,coat=1,'None'
 -- Optional English modifiers; no numeric arguments are needed.
 local changed=true
 while changed do
  changed=false
  for word,value in pairs({big=3,giant=6,gold='Gold',diamond='Diamond'})do
   if name:sub(1,#word+1)==word..' 'then
    name=name:sub(#word+2);if type(value)=='number'then size=value else coat=value end;changed=true;break
   end
  end
 end
 local list={};local normalized=key(name)
 for _,spec in ipairs(Packs.SeedDesigns)do
  if normalized=='all'or normalized==key(spec.id)or normalized==key(spec.name)or normalized==key(Names.Plant(spec.id,spec.name))or(many and normalized==key(spec.biome))then table.insert(list,spec)end
 end
 return list,size,coat,many
end
local function sync(ctx,p,inventory)
 local data=ctx.Data;data:MarkDirty(p);data:_gardenChanged(p);data:QueueGardenSave(p)
 if inventory then
  local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid');if h then h:UnequipTools()end
  data:_notifySeedInventory(p);ctx.Chests:SyncTools(p)
 end
 local base=ctx.Bases:GetPlayerBase(p);if base then ctx.Chests:RenderGarden(base,p)end
end
function Admin.Execute(ctx,requester,command)
 if not Access.IsAllowed(requester)then return false,'These commands are for the experience owner.'end
 local targets,why=Admin.Resolve(requester,command.Target);if not targets then return false,why end
 local selected,size,coat,many
 if command.Operation~='clear'then
  selected,size,coat,many=selection(command.Item);if #selected==0 then return false,'Unknown seed. Use its full plant name or a biome, e.g. apple seed or snow seeds.'end
 end
 local reports={};local successes=0
 for _,p in ipairs(targets)do
  local data=ctx.Data;local garden=data.Gardens[p];local reason
  if p.Parent~=Players or not data:IsLoaded(p)or not garden then reason='data is not ready'
  elseif ctx.Chests:IsOpening(p)or ctx.Chase:IsPlayerBusy(p)or p:GetAttribute('ChestChaseRunActive')or p:GetAttribute('ChestChaseSeedCarrying')then reason='finish the chase or pack opening first'end
  if reason then table.insert(reports,'@'..p.Name..': skipped — '..reason)
  else
   local records=data:GetChestRecords(p);local count=0;local inventory=command.Item~='garden'
   if command.Operation=='give'then
    if #records+#selected>ctx.Config.MaxSavedChests then reason='seed inventory is full'
    else
     local pending={};local serial=p:GetAttribute('ChestInventorySerial')or 0
     for _,spec in ipairs(selected)do
      local seed=ctx.Config.GetSeedById(spec.id)
      if not seed then reason='seed catalog mismatch';break end
      serial+=1;table.insert(pending,{Id=Http:GenerateGUID(false),Kind='Seed',ChestNumber=serial,ChestName=seed.Name,
       Stage=spec.stage,SeedId=seed.Id,SeedName=seed.Name,SeedEmoji=seed.Emoji,AccentColor=seed.Color,Rarity=spec.rarity,
       SeedScale=Packs.SanitizeSeedScale(size),BagVariant='Pack03',PackSize=1,PackMutation=coat})
     end
     if not reason then
      for _,record in ipairs(pending)do table.insert(records,record);data:MarkSeedDiscovered(p,record.SeedId,true)end
      p:SetAttribute('ChestInventorySerial',serial);count=#pending
      -- R151: seeds an owner gave are not counted for the hub's BIGGEST FRUIT / BEST PULL boards (the rest of this session).
      local hub=ctx.Chase and ctx.Chase.HubDisplays;if hub then pcall(hub.NoteOwnerGrant,hub,p)end
     end
    end
   elseif command.Operation=='take'then
    local ids={};for _,spec in ipairs(selected)do ids[spec.id]=true end
    for i=#records,1,-1 do if records[i].Kind~='Pack'and ids[records[i].SeedId]then
     table.remove(records,i);count+=1;if not many then break end
    end end
   elseif command.Operation=='clear'then
    local what=command.Item
    if what=='garden'then for _,list in pairs(garden.Plots)do count+=#list;table.clear(list)end
    elseif what=='harvests'then count=#garden.Harvests;table.clear(garden.Harvests)
    else
     for i=#records,1,-1 do if what=='inventory'or(what=='packs')==(records[i].Kind=='Pack')then table.remove(records,i);count+=1 end end
     if what=='inventory'then count+=#garden.Harvests;table.clear(garden.Harvests)end
    end
   else return false,'Unknown player command.'end
   if reason then table.insert(reports,'@'..p.Name..': skipped — '..reason)
   else
    sync(ctx,p,inventory);successes+=1
    table.insert(reports,'@'..p.Name..': '..(command.Operation=='give'and'gave 'or command.Operation=='take'and'took 'or'cleared ')..count..' items.')
   end
  end
 end
 return successes>0,table.concat(reports,'\n')
end
return Admin
