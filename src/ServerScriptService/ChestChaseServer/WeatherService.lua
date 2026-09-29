-- R98: one deterministic 2% direct roll per object/event, with saved stacking weather.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local Run=game:GetService('RunService')
local W=require(RS.WeatherTraits);local Rules=require(RS.PlantRules);local Catalog=require(RS.PlantCatalog)
local FX=require(RS.ItemEffectAnchor)
local Service={};Service.__index=Service
local function eventKey(kind,cycle)
 local trait=W.Events[kind];if not trait then return nil end
 return tostring(cycle)..':'..trait,trait
end
function Service.new(data,chests)
 local remotes=RS:WaitForChild(chests.Config and chests.Config.RemoteFolderName or 'ChestChaseRemotes')
 local notice=remotes:FindFirstChild('WeatherAdopted')or Instance.new('RemoteEvent')
 notice.Name='WeatherAdopted';notice.Parent=remotes
 return setmetatable({Data=data,Chests=chests,Notice=notice,PackSeen=setmetatable({},{__mode='k'}),FruitSeen=setmetatable({},{__mode='k'}),PendingPacks={},NoticeSerial=0,Cycle=nil,Kind='Clear',Clock=0},Service)
end
function Service:State(now)
 if self.Override and now<self.Override.Until then return self.Override.Kind,self.Override.Cycle,self.Override.Until,self.Override.Until end
 return W.Schedule(now)
end
function Service:ApplyPack(seed,kind,cycle)
 local event,trait=eventKey(kind,cycle);if not event then return false end
 if not seed.Available or not seed.Model or not seed.Model.Parent then return false end
 local key=event..':'..tostring(seed.Generation);if self.PackSeen[seed]==key then return false end;self.PackSeen[seed]=key
 seed.WeatherCheckedEvent=event
 if W.Has(seed.Weather,trait)or W.Roll(seed.Model.Name..':'..seed.Stage..':'..seed.Generation,'pack-weather:'..cycle)>=W.PackChance then return false end
 local weather=W.Merge(seed.Weather,trait)
 seed.Weather=weather;seed.Model:SetAttribute('WeatherTrait',weather)
 local packet=seed.Model:FindFirstChild('SeedPacket');if packet then FX.Set(packet,weather,nil,1.18*seed.PackSize,2.36*seed.PackSize)end
 local group=event..':'..tostring(seed.Stage);local pending=self.PendingPacks[group]
 if not pending then pending={Event=event,Trait=trait,Stage=seed.Stage,Count=0};self.PendingPacks[group]=pending end
 pending.Count+=1
 return true
end
-- Equipped sealed packs remain exposed across weather events; stored inventory is sheltered.
function Service:ApplyHeldPack(player,kind,cycle)
 local event,trait=eventKey(kind,cycle);if not event or not self.Data:IsLoaded(player)then return false end
 local opening=self.Chests.Openings and self.Chests.Openings[player]
 local character=player.Character
 if not opening or opening.Committed or not character or opening.Character~=character then return false end
 local tool,bag=opening.Tool,opening.Bag
 if not tool or tool.Parent~=character or not bag or bag.Parent~=character or not self.Chests:_canOpenPack(player,tool)then return false end
 local id=tool:GetAttribute('SeedInventoryId');local record
 for _,candidate in ipairs(self.Data:GetChestRecords(player))do if candidate.Id==id and candidate.Kind=='Pack'then record=candidate;break end end
 if not record or record.WeatherCheckedEvent==event then return false end
 -- The roll uses persisted identity, never equip count or the transient carry model.
 record.WeatherCheckedEvent=event
 if W.Has(record.Weather,trait)or W.Roll(record.Id,'owned-pack-weather:'..cycle)>=W.PackChance then return false,true end
 local weather=W.Merge(record.Weather,trait)
 record.Weather=weather;tool:SetAttribute('Weather',weather);bag:SetAttribute('Weather',weather)
 local size=record.PackSize or 1;FX.Set(bag,weather,nil,size,2*size)
 return true,true
end
function Service:ApplyCrop(crop,kind,cycle)
 local event,trait=eventKey(kind,cycle);if not event or crop._DetachedHarvest then return false end
 local def=Catalog[crop.SeedId];if not def then return false end
 local seen=self.FruitSeen[crop];if not seen or seen.Event~=event then seen={Event=event,Slots={},Plant=false};self.FruitSeen[crop]=seen end
 local plants,fruits=0,0
 if not seen.Plant then
  seen.Plant=true
  if not W.Has(crop.Weather,trait)and W.Roll(crop.Id,'plant-weather:'..cycle)<W.PlantChance then
   crop.Weather=W.Merge(crop.Weather,trait);plants=1
  end
 end
 -- A whole-plant harvest is the same exposed object and must never receive a second roll.
 if def.Mode~='whole'then for index=1,def.FruitCount do
  local fruitCycle=Rules.FruitCycle(crop,index)
  if not Rules.IsPicked(crop,index)and seen.Slots[index]~=fruitCycle then
   seen.Slots[index]=fruitCycle
   local before=W.Fruit(crop,index,fruitCycle)
   if not W.Has(before,trait)and W.Roll(crop.Id,'event-weather:'..cycle..':'..fruitCycle..':'..index)<W.FruitChance then
    crop.FruitWeather=crop.FruitWeather or{}
    local previous=crop.FruitWeather[tostring(index)]
    -- Save only direct fruit layers. Inheritance stays tied to the plant and stable roll.
    local direct=previous and previous.Cycle==fruitCycle and previous.Kind or'None'
    crop.FruitWeather[tostring(index)]={Kind=W.Merge(direct,trait),Cycle=fruitCycle,Event=cycle};fruits+=1
   end
  end
 end end
 return plants+fruits>0,{Plants=plants,Fruits=fruits,Count=plants+fruits,Trait=trait,Event=event}
end
function Service:SendNotice(player,packet,event)
 self.NoticeSerial+=1
 packet.Kind='WeatherAdopted';packet.EventId=event..':'..(player and tostring(player.UserId)or'world')..':'..self.NoticeSerial
 if player then self.Notice:FireClient(player,packet)else self.Notice:FireAllClients(packet)end
end
function Service:FlushPacks()
 local pending=self.PendingPacks;self.PendingPacks={}
 for _,packet in pairs(pending)do
  self:SendNotice(nil,{Trait=packet.Trait,Count=packet.Count,Plants=0,Fruits=0,Packs=packet.Count,Stage=packet.Stage,Scope='World'},packet.Event)
 end
end
function Service:Step(now)
 local kind,cycle,ends,nextAt=self:State(now)
 if self.Kind~=kind or self.Cycle~=cycle then
  self.Kind=kind;self.Cycle=cycle;RS:SetAttribute('GlobalWeather',kind);RS:SetAttribute('WeatherEndsAt',ends);RS:SetAttribute('NextWeatherAt',nextAt);RS:SetAttribute('WeatherEvent',cycle)
 end
 if W.Events[kind]then
  for _,seed in ipairs(self.Chests.Map.Chests)do self:ApplyPack(seed,kind,cycle)end
  for _,player in ipairs(Players:GetPlayers())do if self.Data:IsLoaded(player)then
   local garden=self.Data.Gardens[player];local plants,fruits=0,0
   local packChanged,packChecked=self:ApplyHeldPack(player,kind,cycle);local packs=packChanged and 1 or 0
   for _,crops in pairs(garden and garden.Plots or{})do for _,crop in ipairs(crops)do
    local changed,counts=self:ApplyCrop(crop,kind,cycle)
    if changed then plants+=counts.Plants;fruits+=counts.Fruits end
   end end
   if plants+fruits+packs>0 or packChecked then
    if plants+fruits>0 then self.Data:_gardenChanged(player)end
    if packs>0 then self.Data:_notifySeedInventory(player)end
    self.Data:MarkDirty(player);self.Data:QueueGardenSave(player)
    if plants+fruits>0 then self.Chests:RenderGarden(self.Chests.Bases:GetPlayerBase(player),player)end
    if plants+fruits+packs>0 then self:SendNotice(player,{Trait=W.Events[kind],Count=plants+fruits+packs,Plants=plants,Fruits=fruits,Packs=packs,Scope='Owned'},eventKey(kind,cycle))end
   end
  end end
 end
 self:FlushPacks()
end
function Service:Start()
 self.Chests.Weather=self;self:Step(workspace:GetServerTimeNow())
 self.Connection=Run.Heartbeat:Connect(function(dt)self.Clock+=dt;if self.Clock>=5 then self.Clock=0;self:Step(workspace:GetServerTimeNow())end end)
 -- Weather test requests pass through the owner/admin dispatcher in Studio and public servers.
end
return Service
