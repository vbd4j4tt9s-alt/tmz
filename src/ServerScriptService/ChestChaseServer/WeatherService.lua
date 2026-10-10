-- R98: deterministic direct rolls per object, with saved stacking weather.
-- R131 (owner): one roll per object per MINUTE of weather at 0.2% (WeatherTraits chances), instead of one 2% roll per
-- event. The minute is counted down from the event's end, so each minute of a 3-minute event is its own roll.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local Run=game:GetService('RunService')
local W=require(RS.WeatherTraits);local Rules=require(RS.PlantRules);local Catalog=require(RS.PlantCatalog)
local FX=require(RS.ItemEffectAnchor)
-- R151: the default sky alternates Clear <-> Cloudy (WeatherCycle151). Ambient only: no mutation roll, GlobalWeather stays 'Clear' while it is cloudy.
local Cycle=require(RS.WeatherCycle151)
-- R127: a pack that adopts weather glows for everyone; plant/fruit notices carry which plant changed (MutationGlow127).
local Glow=require(RS.MutationGlow127);local CS=game:GetService('CollectionService')
local Service={};Service.__index=Service
local function eventKey(kind,cycle)
 local trait=W.Events[kind];if not trait then return nil end
 return tostring(cycle)..':'..trait,trait
end
function Service.new(data,chests)
 local remotes=RS:WaitForChild(chests.Config and chests.Config.RemoteFolderName or 'ChestChaseRemotes')
 local notice=remotes:FindFirstChild('WeatherAdopted')or Instance.new('RemoteEvent')
 notice.Name='WeatherAdopted';notice.Parent=remotes
 return setmetatable({Data=data,Chests=chests,Notice=notice,PackSeen=setmetatable({},{__mode='k'}),FruitSeen=setmetatable({},{__mode='k'}),PendingPacks={},Glows=setmetatable({},{__mode='k'}),NoticeSerial=0,Cycle=nil,Kind='Clear',Clock=0,SkyClock=0,SkyShift=0,SkySerial=0},Service)
end
function Service:Minute(now)
 local _,_,ends=self:State(now)
 return math.max(0,math.ceil(((ends or now)-now)/60)-1)
end
function Service:State(now)
 if self.Override and now<self.Override.Until then return self.Override.Kind,self.Override.Cycle,self.Override.Until,self.Override.Until end
 return W.Schedule(now)
end
-- One Highlight per pack, on the pack art itself (SeedPacket / the carried bag), so a respawn or a drop removes it.
function Service:GlowPack(owner,target,trait,seed)
 if not target or not target.Parent then return nil end
 local old=self.Glows[owner];if old and old.Highlight then old.Highlight:Destroy();self.Glows[owner]=nil end
 -- Roblox draws at most 31 highlights per screen: packs keep to MaxPackGlows, leaving room for owner plant outlines.
 local n=0;for _ in pairs(self.Glows)do n+=1 end;if n>=Glow.MaxPackGlows then return nil end
 local h=Instance.new('Highlight');h.Name=Glow.Name;h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
 h.FillColor=Glow.Color(trait);h.OutlineColor=Color3.new(1,1,1);h.FillTransparency=.45;h.OutlineTransparency=0
 h:SetAttribute('Trait',trait);h:SetAttribute('Until',workspace:GetServerTimeNow()+Glow.PackSeconds)
 h.Adornee=target;h.Parent=target;CS:AddTag(h,Glow.Tag)
 self.Glows[owner]={Highlight=h,Until=os.clock()+Glow.PackSeconds,Seed=seed,Generation=seed and seed.Generation}
 return h
end
function Service:ExpireGlows()
 local now=os.clock()
 for owner,g in pairs(self.Glows)do
  local gone=not g.Highlight.Parent or now>=g.Until
  if g.Seed and(not g.Seed.Available or g.Seed.Generation~=g.Generation)then gone=true end
  if gone then g.Highlight:Destroy();self.Glows[owner]=nil end
 end
end
function Service:ApplyPack(seed,kind,cycle,minute)
 local event,trait=eventKey(kind,cycle);if not event then return false end
 if not seed.Available or not seed.Model or not seed.Model.Parent then return false end
 minute=minute or self:Minute(workspace:GetServerTimeNow())
 local round=event..':m'..minute
 local key=round..':'..tostring(seed.Generation);if self.PackSeen[seed]==key then return false end;self.PackSeen[seed]=key
 seed.WeatherCheckedEvent=round
 if W.Has(seed.Weather,trait)or (not self.ForceAll and W.Roll(seed.Model.Name..':'..seed.Stage..':'..seed.Generation,'pack-weather:'..cycle..':m'..minute)>=W.PackChance)then return false end
 local weather=W.Merge(seed.Weather,trait)
 seed.Weather=weather;seed.Model:SetAttribute('WeatherTrait',weather)
 local packet=seed.Model:FindFirstChild('SeedPacket');if packet then FX.Set(packet,weather,nil,1.18*seed.PackSize,2.36*seed.PackSize);self:GlowPack(seed,packet,trait,seed)end
 local group=event..':'..tostring(seed.Stage);local pending=self.PendingPacks[group]
 if not pending then pending={Event=event,Trait=trait,Stage=seed.Stage,Count=0};self.PendingPacks[group]=pending end
 pending.Count+=1
 return true
end
-- Equipped sealed packs remain exposed across weather events; stored inventory is sheltered.
function Service:ApplyHeldPack(player,kind,cycle,minute)
 local event,trait=eventKey(kind,cycle);if not event or not self.Data:IsLoaded(player)then return false end
 minute=minute or self:Minute(workspace:GetServerTimeNow());local round=event..':m'..minute
 local opening=self.Chests.Openings and self.Chests.Openings[player]
 local character=player.Character
 if not opening or opening.Committed or not character or opening.Character~=character then return false end
 local tool,bag=opening.Tool,opening.Bag
 if not tool or tool.Parent~=character or not bag or bag.Parent~=character or not self.Chests:_canOpenPack(player,tool)then return false end
 local id=tool:GetAttribute('SeedInventoryId');local record
 for _,candidate in ipairs(self.Data:GetChestRecords(player))do if candidate.Id==id and candidate.Kind=='Pack'then record=candidate;break end end
 if not record or record.WeatherCheckedEvent==round then return false end
 -- The roll uses persisted identity, never equip count or the transient carry model.
 record.WeatherCheckedEvent=round
 if W.Has(record.Weather,trait)or (not self.ForceAll and W.Roll(record.Id,'owned-pack-weather:'..cycle..':m'..minute)>=W.PackChance)then return false,true end
 local weather=W.Merge(record.Weather,trait)
 record.Weather=weather;tool:SetAttribute('Weather',weather);bag:SetAttribute('Weather',weather)
 local size=record.PackSize or 1;FX.Set(bag,weather,nil,size,2*size);self:GlowPack(player,bag,trait)
 return true,true
end
function Service:ApplyCrop(crop,kind,cycle,minute)
 local event,trait=eventKey(kind,cycle);if not event or crop._DetachedHarvest then return false end
 local def=Catalog[crop.SeedId];if not def then return false end
 minute=minute or self:Minute(workspace:GetServerTimeNow());local round=event..':m'..minute
 local seen=self.FruitSeen[crop];if not seen or seen.Event~=round then seen={Event=round,Slots={},Plant=false};self.FruitSeen[crop]=seen end
 local plants,fruits=0,0
 if not seen.Plant then
  seen.Plant=true
  if not W.Has(crop.Weather,trait)and (self.ForceAll or W.Roll(crop.Id,'plant-weather:'..cycle..':m'..minute)<W.PlantChance)then
   crop.Weather=W.Merge(crop.Weather,trait);plants=1
  end
 end
 local changedFruits={}
 -- A whole-plant harvest is the same exposed object and must never receive a second roll.
 if def.Mode~='whole'then for index=1,def.FruitCount do
  local fruitCycle=Rules.FruitCycle(crop,index)
  if not Rules.IsPicked(crop,index)and seen.Slots[index]~=fruitCycle then
   seen.Slots[index]=fruitCycle
   local before=W.Fruit(crop,index,fruitCycle)
   if not W.Has(before,trait)and (self.ForceAll or W.Roll(crop.Id,'event-weather:'..cycle..':m'..minute..':'..fruitCycle..':'..index)<W.FruitChance)then
    crop.FruitWeather=crop.FruitWeather or{}
    local previous=crop.FruitWeather[tostring(index)]
    -- Save only direct fruit layers. Inheritance stays tied to the plant and stable roll.
    local direct=previous and previous.Cycle==fruitCycle and previous.Kind or'None'
    crop.FruitWeather[tostring(index)]={Kind=W.Merge(direct,trait),Cycle=fruitCycle,Event=cycle};fruits+=1;table.insert(changedFruits,index)
   end
  end
 end end
 local item=plants+fruits>0 and{CropId=crop.Id,SeedId=crop.SeedId,Plant=plants>0,Fruits=changedFruits}or nil
 return plants+fruits>0,{Plants=plants,Fruits=fruits,Count=plants+fruits,Trait=trait,Event=event,Item=item}
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
 -- R127: owner test 'weather rain all' makes every exposed pack, plant and fruit change during that event.
 self.ForceAll=self.Override~=nil and self.Override.All==true and now<self.Override.Until
 if self.Kind~=kind or self.Cycle~=cycle then
  self.Kind=kind;self.Cycle=cycle;RS:SetAttribute('GlobalWeather',kind);RS:SetAttribute('WeatherEndsAt',ends);RS:SetAttribute('NextWeatherAt',nextAt);RS:SetAttribute('WeatherEvent',cycle)
 end
 if W.Events[kind]then
  local minute=math.max(0,math.ceil((ends-now)/60)-1)
  for _,seed in ipairs(self.Chests.Map.Chests)do self:ApplyPack(seed,kind,cycle,minute)end
  for _,player in ipairs(Players:GetPlayers())do if self.Data:IsLoaded(player)then
   local garden=self.Data.Gardens[player];local plants,fruits,items=0,0,{}
   local packChanged,packChecked=self:ApplyHeldPack(player,kind,cycle,minute);local packs=packChanged and 1 or 0
   for _,crops in pairs(garden and garden.Plots or{})do for _,crop in ipairs(crops)do
    local changed,counts=self:ApplyCrop(crop,kind,cycle,minute)
    if changed then plants+=counts.Plants;fruits+=counts.Fruits;if counts.Item and #items<Glow.MaxItems then table.insert(items,counts.Item)end end
   end end
   if plants+fruits+packs>0 or packChecked then
    if plants+fruits>0 then self.Data:_gardenChanged(player)end
    if packs>0 then self.Data:_notifySeedInventory(player)end
    self.Data:MarkDirty(player);self.Data:QueueGardenSave(player)
    if plants+fruits>0 then self.Chests:RenderGarden(self.Chests.Bases:GetPlayerBase(player),player)end
    if plants+fruits+packs>0 then self:SendNotice(player,{Trait=W.Events[kind],Count=plants+fruits+packs,Plants=plants,Fruits=fruits,Packs=packs,Scope='Owned',Items=#items>0 and items or nil},eventKey(kind,cycle))end
   end
  end end
 end
 self:FlushPacks();self:ExpireGlows()
end
-- R151 the default sky ---------------------------------------------------------------------------------------------------------------------
-- The server owns the state: self.Sky = {Key, Kind, Since, Fade, From, Ends, Hold}, published as ReplicatedStorage.AmbientSkyState (one atomic string,
-- WeatherCycle151.Pack) and the plain kind in AmbientSky. Clients turn it into a smooth level with the server clock (a late joiner is right, a skip or a
-- test hold starts from the level the old state had reached, so nothing jumps). The schedule is WeatherCycle151.Segment(now + SkyShift): SkyShift is
-- only ever set by '/test weather cycle skip'. Event weather is not consulted here: it takes priority on the client and the cycle keeps running.
function Service:SkyWant(now)
 local hold=self.SkyHold
 if hold and now>=hold.Until then self.SkyHold=nil;hold=nil end
 if hold then return'hold:'..hold.Serial,hold.Kind,hold.Start,hold.Until,hold.Fade,hold.From,true end
 local shift=self.SkyShift or 0
 local n,kind,start,finish,fade=Cycle.Segment(now+shift,self.SkyConfig)
 return n..'@'..shift,kind,start-shift,finish-shift,fade,nil,false
end
local function publishSky(self,state)
 self.Sky=state
 RS:SetAttribute(Cycle.Attribute,Cycle.Pack(state.Kind,state.Since,state.Fade,state.From,state.Ends))
 RS:SetAttribute(Cycle.KindAttribute,state.Kind)
 RS:SetAttribute('AmbientSkyEndsAt',state.Ends)
end
-- Called every half second (Start): one pure schedule lookup, a write only when the segment changed. Returns true when it published a new state.
function Service:StepSky(now)
 now=now or workspace:GetServerTimeNow()
 local key,kind,start,ends,fade,from,hold=self:SkyWant(now)
 local cur=self.Sky
 if cur and cur.Key==key then return false end
 -- the new sky starts at its own boundary when that was just crossed (polling lag), else now (a hold began or ended, a skip, the schedule was shifted)
 local since=start
 if cur and(cur.Hold or not(start>cur.Since and start<=now and now-start<=5))then since=now end
 if from==nil then from=cur and Cycle.LevelOf(cur,since)or(kind=='Cloudy'and 0 or 1)end
 publishSky(self,{Key=key,Kind=kind,Since=since,Fade=fade,From=from,Ends=ends,Hold=hold})
 return true
end
-- Owner test: keep the sky Clear / Cloudy for `seconds` (default Config.TestHold), arriving over `fade` seconds (default Config.TestFade).
function Service:HoldSky(kind,now,seconds,fade)
 if kind~='Clear'and kind~='Cloudy'then return false end
 now=now or workspace:GetServerTimeNow()
 local cfg=self.SkyConfig or Cycle.Config
 self:StepSky(now)
 self.SkySerial+=1
 local cur=self.Sky
 self.SkyHold={Serial=self.SkySerial,Kind=kind,Start=now,Until=now+(seconds or cfg.TestHold),Fade=fade or cfg.TestFade,From=cur and Cycle.LevelOf(cur,now)or(kind=='Cloudy'and 0 or 1)}
 return self:StepSky(now)
end
-- Owner test: end the current phase now - the other sky starts (its real fade length), then the cycle goes on from there (a time shift on this server).
function Service:SkipSky(now)
 now=now or workspace:GetServerTimeNow()
 self:StepSky(now)
 local shown=self.Sky and self.Sky.Kind or'Clear'
 self.SkyHold=nil
 local n=Cycle.Segment(now+(self.SkyShift or 0),self.SkyConfig)
 if Cycle.KindOf(n)==shown then n+=1 end -- (the natural phase is the one on show: the next one is the other sky)
 self.SkyShift=Cycle.Boundary(n,self.SkyConfig)-now
 self:StepSky(now)
 return self.Sky
end
-- Owner test: back to the real schedule.
function Service:ReleaseSky(now)
 now=now or workspace:GetServerTimeNow()
 self.SkyHold=nil;self.SkyShift=0
 self:StepSky(now)
 return self.Sky
end
local function minutes(seconds)seconds=math.max(0,math.floor(seconds+.5));return string.format('%d:%02d',math.floor(seconds/60),seconds%60)end
-- A few lines for '/test weather cycle'.
function Service:SkyReport(now)
 now=now or workspace:GetServerTimeNow();self:StepSky(now)
 local s=self.Sky
 if not s then return{'The default sky has not started.'}end
 local lines={};local level=Cycle.LevelOf(s,now);local fading=now-s.Since<s.Fade
 local other=s.Kind=='Cloudy'and'Clear'or'Cloudy'
 lines[#lines+1]=string.format('Default sky: %s%s, level %.2f (0 = Clear .. 1 = Cloudy); it started %s ago.',s.Kind,fading and string.format(' (fading in, %.0f s left)',s.Since+s.Fade-now)or'',level,minutes(now-s.Since))
 lines[#lines+1]=string.format('%s: %s more, then %s%s.',s.Hold and'Held by a test'or'The cycle',minutes(s.Ends-now),other,s.Hold and' (then the cycle goes on)'or'')
 local cfg=self.SkyConfig or Cycle.Config
 lines[#lines+1]=string.format('Cycle: Clear about %s, Cloudy about %s, fades %d to %d s%s (ReplicatedStorage.WeatherCycle151.Config).',minutes(cfg.Clear.Seconds),minutes(cfg.Cloudy.Seconds),cfg.Fade[1],cfg.Fade[2],(self.SkyShift or 0)~=0 and', shifted by a skip'or'')
 local kind,_,ends,nextAt=self:State(now)
 lines[#lines+1]=W.Events[kind]and string.format('Event weather: %s, ends in %s (it takes priority: Cloudy is not applied meanwhile).',kind,minutes(ends-now))or string.format('Event weather: none, the next one in %s.',minutes(nextAt-now))
 return lines
end

function Service:Start()
 self.Chests.Weather=self;self:Step(workspace:GetServerTimeNow());self:StepSky(workspace:GetServerTimeNow())
 self.Connection=Run.Heartbeat:Connect(function(dt)
  self.Clock+=dt;if self.Clock>=5 then self.Clock=0;self:Step(workspace:GetServerTimeNow())end
  self.SkyClock+=dt;if self.SkyClock>=.5 then self.SkyClock=0;self:StepSky(workspace:GetServerTimeNow())end -- R151: one schedule lookup twice a second
 end)
 -- Weather test requests pass through the owner/admin dispatcher in Studio and public servers.
end
return Service
