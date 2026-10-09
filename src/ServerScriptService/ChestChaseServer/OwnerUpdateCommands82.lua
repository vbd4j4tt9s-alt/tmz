-- R82 extension. Only the server-authorized command dispatcher calls Execute.
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Packs=require(RS.SeedPackRules);local T=require(RS.BalanceValues81)
local State=require(script.Parent.OwnerTestState82);local TestPacks=setmetatable({},{__index=function(_,k)return require(script.Parent.OwnerTestPacks)[k]end}) -- R151: packs these commands make never announce (loaded when first used)
local X={Actions={cashoffers=true,economy=true,collisions=true,weather=true,mechshop=true,voidcheck=true,fence=true,eventpack=true,gardenbonus=true,keepersmack=true,notice=true,routes=true,spawnodds=true,void=true,event=true,eclipse=true,packset=true,odds=true,pity=true,packluck=true,refreshcycle=true,movespeed=true,animrate=true,training=true,gems=true,bundle=true,boots=true,trail=true,indexinfo=true,claimindex=true,fling=true,ragdoll=true,holes=true,dig=true,gifts=true,admins=true,bonus=true,daily=true,mystery=true,verity=true,verityvoice=true,announce=true,bestpull=true,bigfruit=true,hubdisplays=true}}
local biomes={forest=1,jungle=6,desert=2,snow=3,lava=4,crystal=5,storm=7,stormpeaks=7,mech=8,verity=9}
local tiers={common='Pack01',uncommon='Pack02',rare='Pack03',epic='Pack04',legendary='Pack05',mythic='Pack06',event='EclipseReliquary',eclipse='EclipseReliquary',verity='VerityReliquary'}
local function integer(s,lo,hi)local n=tonumber(s);return n and n==n and n%1==0 and n>=lo and n<=hi and n or nil end
local function stage(s)return biomes[tostring(s or''):lower()]or integer(s,1,9)end
local function variant(s)return tiers[tostring(s or''):lower()]or (integer(s,1,6)and string.format('Pack%02d',tonumber(s)))end
local function seedId(s)
 local query=tostring(s or''):lower()
 for _,spec in ipairs(Packs.SeedDesigns)do if spec.id:lower()==query then return spec.id end end
end
local function safe(ctx,p)
 if p:GetAttribute('ChestChaseRunActive')or ctx.Chase:IsPlayerBusy(p)or ctx.Chests:IsOpening(p)or p:GetAttribute('ChestChaseSeedCarrying')then return false,'Finish the target’s chase or pack opening first.'end
 return true
end
local function applySpeed(ctx,p)
 local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid')
 if h then ctx.Bases:_applyPhysicalSpeed(p,h,ctx.Data:GetOrCreateSpeedValue(p).Value)end
 require(script.Parent.MovementGuard).Reset(p)
end
local function save(ctx,p)ctx.Data:MarkDirty(p);ctx.Data:QueueGardenSave(p)end
-- R151: owner previews of the pull reveals and their sound slots (RarePullTestCommands).
X.Actions.rarepull=true;X.Actions.raresound=true
-- R151: plantnotify [status|send|reset]: the offline "your plant is ready" notifier's setup check, a test send to you, your cooldown reset (SocialService).
X.Actions.plantnotify=true
-- R151: owner control of the chip-bag shape variations (PackShapeCommand151): packshape <1-6|off|auto>.
X.Actions.packshape=true
-- R151: hubtrees: the owner's studded tree models (HubTreeLoader151): which load route worked per id, scripts removed, each tier's plan.
X.Actions.hubtrees=true
-- R153: trampoline [status | reload]: which look the two garden-nook trampolines have (the owner's asset 12088629887, a model dropped into ReplicatedStorage.HubTrampolineTemplates153, or the built one) and why (HubTrampoline153).
X.Actions.trampoline=true
-- R152: keepermodels [off|auto]: the baked rev 6 keeper models (KeeperMeshCommand152): bake status, which model each keeper shows, a switch back.
X.Actions.keepermodels=true
-- R152: voidgift [reset me | left <n>]: the free Void Pack pedestal's status; the two edits are Studio only (VoidGiveaway152).
X.Actions.voidgift=true
function X.Execute(ctx,p,action,a)
 if action=='keepermodels'then return require(script.Parent.KeeperMeshCommand152).Execute(ctx,p,a)end
 if action=='hubtrees'then return require(script.Parent.HubTreeLoader151).Command(ctx,p,a)end
 if action=='trampoline'then return require(script.Parent.HubTrampoline153).Command(ctx,p,a)end
 if action=='voidgift'then return require(script.Parent.VoidGiveaway152).Command(ctx,p,a)end
 if action=='rarepull'or action=='raresound'then return require(script.Parent.RarePullTestCommands).Execute(ctx,p,action,a)end
 if action=='plantnotify'then return require(script.Parent.SocialService).Command(ctx,p,a)end
 if action=='packshape'then return require(script.Parent.PackShapeCommand151).Execute(ctx,p,a)end
 local map=ctx.Map.MapRoot;local event=ctx.Chase.Event81;local data=ctx.Data
 if action=='void'then action='eclipse'end
 if action=='announce'then return require(script.Parent.PullAnnouncer).Command(ctx,p,a)end -- R151: announce <seed> | announce global <seed> | announce record
 if action=='cashoffers'then
  if #a~=0 then return false,'Use cashoffers @username.'end
  local lines={};local Cash=require(RS.CashNumbers)
  for _,row in ipairs(require(RS.PremiumPricing).Bundles)do if row.Kind=='Cash'then local quote=data:BundleQuote(p,row.Key);if quote then lines[#lines+1]=row.Tier..': '..Cash.Compact(quote.Amount)..' Cash / '..quote.GemPrice..' Gems'end end end
  return true,table.concat(lines,'\n')
 elseif action=='economy'then
  if #a~=0 then return false,'Use economy.'end
  local E=require(RS.EconomyBalance90);local Cash=require(RS.CashNumbers)
  local function row(name,values)local out={};for _,v in ipairs(values)do out[#out+1]=Cash.Compact(v)end;return name..': '..table.concat(out,' / ')end
  return true,table.concat({row('Treadmills',E.MachineCosts),row('Trails',{E.TrailCosts.MintTrail,E.TrailCosts.ArcTrail,E.TrailCosts.SolarTrail,E.TrailCosts.AuroraTrail,E.TrailCosts.NebulaTrail,E.TrailCosts.RoyalTrail}),row('Boots',E.BootCosts),row('Fences',E.FenceCosts),'Normal fruit up to '..Cash.Compact(E.MaxBaseFruitValue)..'; size/mutation/weather bonuses still apply.','Cash capacity '..Cash.Compact(E.MaxCash)..'; owned upgrades and harvested fruit are retained.'},'\n')
 elseif action=='collisions'then
  if #a~=0 then return false,'Use collisions.'end
  local count=require(RS.WalkthroughProps90).Apply(map)
  return true,'Walk-through props checked: '..count..' parts. Plants, floors and boundaries retained; leaderboard scrolling and market prompts stay active.'
 end
 if action=='verityvoice'then
  -- R149 owner tool: find where "Hello, my name is Verity" ends by ear. verityvoice <end> [start] (seconds into the clip) sets the cut for this
  -- whole server and plays it for you at once (from anywhere); verityvoice alone plays it again with the current values and prints them;
  -- verityvoice reset goes back to VerityConfig. Nothing is saved: copy the numbers into ReplicatedStorage.VerityConfig (GreetingStart / GreetingEnd).
  local svc=ctx.Chase and ctx.Chase.Verity
  if not svc or type(svc.VoiceRegion)~='function'or not svc.Model then return false,'Verity is not in this server.'end
  local Voice=require(RS.VerityVoice)
  local function say(start,stop,custom)
   local function n(v)return tostring(math.floor(v*1000+.5)/1000)end
   return ('Verity\'s greeting plays %.2f s to %.2f s of the clip (%.2f s long)%s. In ReplicatedStorage.VerityConfig set GreetingStart=%s and GreetingEnd=%s once it sounds right.'):format(start,stop,stop-start,custom and' (set by this command, for this server only)'or' (from VerityConfig)',n(start),n(stop))
  end
  if #a==1 and tostring(a[1]):lower()=='reset'then
   svc:SetVoiceRegion(nil,nil);svc:PlayVoice(p);local start,stop,custom=svc:VoiceRegion()
   return true,'Back to VerityConfig. Playing it for you. '..say(start,stop,custom)
  end
  if #a>2 then return false,'Use verityvoice [end seconds] [start seconds], or verityvoice reset.'end
  if #a>=1 then
   local stop=tonumber(a[1]);local start
   if a[2]~=nil then start=tonumber(a[2])else start=(svc:VoiceRegion())end
   if not Voice.Finite(stop)or not Voice.Finite(start)then return false,'Use verityvoice [end seconds] [start seconds]: both are numbers of seconds into the clip (for example verityvoice 2.1, or verityvoice 2.1 0.3).'end
   if start<0 or stop>Voice.MaxSeconds then return false,'The start must be 0 or more and the end at most '..Voice.MaxSeconds..' seconds.'end
   if stop-start<Voice.MinLength-1e-9 then return false,'The end must be at least '..Voice.MinLength..' s after the start (start '..start..' s, end '..stop..' s).'end
   if not svc:SetVoiceRegion(start,stop)then return false,'Verity is not in this server.'end
  end
  svc:PlayVoice(p)
  local start,stop,custom=svc:VoiceRegion()
  return true,'Playing it for you now. '..say(start,stop,custom)
 end
 if action=='weather'then
  -- R151: weather cloudy | weather cycle [skip|auto] (WeatherSkyCommand151); weather clear also holds the default sky Clear (below).
  if a[1]=='cloudy'or a[1]=='cycle'then return require(script.Parent.WeatherSkyCommand151).Execute(ctx,p,a)end
  local kind=({rain='Rain',thunder='Thunderstorm',thunderstorm='Thunderstorm',blizzard='Blizzard',clear='Clear'})[a[1]]
  local all=a[2]=='all'and kind~='Clear'
  if(#a~=1 and not all)or not kind then return false,'Use weather clear/cloudy/rain/thunder/blizzard (add all to change every pack/plant/fruit), or weather cycle [skip|auto] for the default Clear <-> Cloudy sky. For local Snow, visit the Snow biome during clear weather.'end
  local service=ctx.Chests.Weather;if not service then return false,'Weather is loading.'end
  local now=workspace:GetServerTimeNow();service.TestSerial=(service.TestSerial or 0)+1
  service.Override={Kind=kind,Cycle=-service.TestSerial,Until=now+require(RS.WeatherTraits).Duration,All=all};service:Step(now)
  if kind=='Clear'and service.HoldSky then service:HoldSky('Clear',now)end -- R151: the default sky too (Clear, not Cloudy) for a few minutes
  return true,'Server weather: '..kind..(all and' - every exposed pack, plant and fruit changes (R127 highlight test)'or'')..'. Normal weather resumes after this event.'..(kind=='Clear'and' The default sky is held Clear for a few minutes (weather cycle auto ends that).'or'')
 elseif action=='mechshop'then
  if #a~=0 then return false,'Use mechshop.'end
  local C=require(RS.MechCatalog);local lines={'Mech packs: select SINGLE / 5 PACKS / 10 PACKS in SHOP.'}
  for _,offer in ipairs(C.Offers)do lines[#lines+1]=offer.Count..' for '..offer.GemPrice..' Gems | target '..offer.TargetRobuxPrice..' Robux | product '..(C.ProductId(offer.Count)>0 and'configured'or'not configured')end
  lines[#lines+1]=C.CoatLine()..' on every pack u buy (each pack rolls its own; free packs stay plain).' -- R155
  local Limited=require(RS.LimitedEvent);lines[#lines+1]=C.EventOver()and'Limited event: OVER. No new purchase starts (a Robux receipt from before still gets its packs).'or'Limited event: ends in '..Limited.Text(Limited.Left(os.time()))..'.' -- R155
  lines[#lines+1]='Robux buttons use the live Roblox price. This command grants nothing.';return true,table.concat(lines,'\n')
 end
 if action=='voidcheck'then
  if #a~=0 then return false,'Use voidcheck [@username].'end
  local mech=require(RS.MechCatalog);local fmt=require(RS.OddsText85).Format
  local odds=Packs.SeedOdds(ctx.Config,7,'EclipseReliquary',1,Packs.OddsVersion);local total,mechTotal=0,0
  for _,n in pairs(odds)do total+=n end
  local lines={'Void Pack: all regular Secret/Cosmic/King seeds; Mech branch 1/200.','Mech seeds come only from this branch. Conditional / overall odds:'};local ticket=0
  for _,s in ipairs(mech.Seeds)do
   local units,k={0,(ticket+s.Chance/2)/100},0 -- first draw takes the 1/200 Mech branch, second picks the seed
   local seed=Packs.Roll(ctx.Config,7,function()k+=1;return units[k]or 0 end,1,'EclipseReliquary',Packs.OddsVersion);ticket+=s.Chance
   if not seed or seed.Id~=s.Id then return false,'Mech branch check failed for '..s.Name end
   mechTotal+=(odds[s.Id]or 0);table.insert(lines,s.Name..': '..fmt(s.Chance)..' / '..fmt(odds[s.Id]))
  end
  if math.abs(total-100)>1e-7 or math.abs(mechTotal-.5)>1e-7 then return false,'Void odds totals do not match.'end
  table.insert(lines,'PASS: total odds 1/1; Mech branch 1/200; all six nested rolls match. No items granted.')
  return true,table.concat(lines,'\n')
 elseif action=='eventpack'then
  local size=tonumber(a[1]);local coat=({none='None',gold='Gold',diamond='Diamond'})[(a[2]or'none'):lower()]
  if #a<1 or #a>2 or not size or size~=size or size<.5 or size>25 or not coat then return false,'Use eventpack <0.5–25> [none|gold|diamond].'end
  if not event or not event.Seed or not event.Seed.Available or ctx.Map.Refreshing then return false,'Spawn an available event first; finish any event chase or dropped pack.'end
  ctx.Chests:RefreshWorldPack(event.Seed,'EclipseReliquary',size,coat)
  return true,'World Void Pack set to '..event.Seed.PackSize..'x '..coat..'. The normal event and banking flow remain active.'
 elseif action=='gardenbonus'then
  local b=require(RS.GardenBonusRules84).Read(data:GetFenceTier(p),p:GetAttribute('DoubleGrowthOwned')==true)
  return true,'Garden size ×'..b.Size..' | grow time ×'..b.Time..' | fence '..data:GetFenceTier(p)..' | growth pass '..b.Growth..'x'
 elseif action=='keepersmack'then
  if not event or not event.Guardian or not event.Guardian.Parent then return false,'Spawn the event first.'end
  for _,run in pairs(ctx.Chase.Runs)do if run.Chest.EventKeeper then return false,'Wait until the event chase ends.'end end
  local k=event.Guardian;local state=k:GetAttribute('GuardianBehavior');local awake=k:GetAttribute('VeiledAwakeAt')
  local at=workspace:GetServerTimeNow();k:SetAttribute('VeiledAwakeAt',at-1);k:SetAttribute('KeeperAttackAt',at);k:SetAttribute('GuardianBehavior','ATTACKING')
  task.delay(.85,function()if k.Parent and k:GetAttribute('KeeperAttackAt')==at and (k:GetAttribute('TargetUserId')or 0)==0 then k:SetAttribute('KeeperAttackAt',nil);k:SetAttribute('GuardianBehavior',state);k:SetAttribute('VeiledAwakeAt',awake)end end)
  return true,'Smack pose preview. No player is hit.'
 elseif action=='routes'then
  local r=require(RS.RouteBalance83);local lines={'R84 route: '..(r.End-r.Start)..' studs | special keeper '..r.EventSpeed}
  for _,id in ipairs(r.Order)do table.insert(lines,ctx.Config.BiomeNames[id]..': '..r.Lengths[id]..' studs | keeper '..table.concat(r.KeeperSpeeds[id],'/'))end
  return true,table.concat(lines,'\n')
 elseif action=='spawnodds'then
  local lines={'Natural spawn chance per slot (pity can add guarantees):'}
  for i,n in ipairs(require(RS.RouteBalance83).SpawnWeights)do table.insert(lines,Packs.PackTiers[i].Name..': '..n..'%')end
  return true,table.concat(lines,'\n')
 elseif action=='notice'then
  if #a~=1 then return false,'Use notice event/legendary/mythic/giant.'end
  local id='test:'..game:GetService('HttpService'):GenerateGUID(false)
  if a[1]=='event'then if not event then return false,'Event not ready.'end;event.Remote:FireClient(p,0,id);return true,'Arrival notification sent to target.'end
  local key=a[1]=='legendary'and'Pack05'or a[1]=='mythic'and'Pack06'or a[1]=='giant'and'Pack01'
  if not key then return false,'Use notice event/legendary/mythic/giant.'end
  local m=require(RS.RarePackRules).Message(7,key,a[1]=='giant'and 7.5 or 1,key=='Pack05'and'Gold'or'None');if not m then return false,'That pack does not meet the rare notification odds.'end;m.SpawnId=id;ctx.Chests.RarePackSpawn:FireClient(p,m)
  return true,'Spawn notification sent to target; no world pack created.'
 end
 if action=='event'then
  local mode=(a[1]or'spawn'):lower();if #a>1 then return false,'Use event spawn, clear, go or status.'end
  if not event then return false,'Event service is not ready.'end
  if mode=='status'then return true,'Event active: '..tostring(map:GetAttribute('VeiledEventActive'))..' | cycle '..tostring(map:GetAttribute('VeiledEventCycle')or 0)..' | reset '..tostring(map:GetAttribute('BiomeRefreshCycle')or 0)..' | captured '..tostring(map:GetAttribute('VeiledEventClaimed')==true)..' | packs left '..tostring(map:GetAttribute('VeiledPacksLeft')or 0)..' | unstolen refreshes '..tostring(map:GetAttribute('VeiledUnstolenRefreshes')or 0)..'/3'end
  if mode=='spawn'or mode=='clear'then
   if ctx.Map.Refreshing then return false,'Wait until the refresh finishes.'end
   for _,run in pairs(ctx.Chase.Runs)do if run.Chest.EventKeeper then return false,'The event pack is being carried. Finish that chase first.'end end
   for _,drop in pairs(ctx.Chase.Drops)do if drop.Chest.EventKeeper and not drop.Claimed then return false,'Recover the dropped event pack before replacing this event.'end end
   if mode=='clear'then event:Clear();return true,'Event cleared.'end
   local cycle=(math.floor((map:GetAttribute('VeiledEventCycle')or 0)/3)+1)*3
   event:Spawn(cycle,true);return event.Seed~=nil,'Storm Peaks event spawned. Normal reset counter is unchanged.'
  elseif mode=='go'then
   local okay,why=safe(ctx,p);if not okay then return false,why end
   if not event.Seed or not event.Seed.Model.Parent or ctx.Map.Refreshing then return false,'Spawn the event first.'end
   local c=p.Character;local root=c and c:FindFirstChild('HumanoidRootPart');if not root then return false,'Wait for the target’s character.'end
   ctx.Bases:StopTraining(p,false);State.ClearMovement(p)
   root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
   c:PivotTo(event.Seed.Body.CFrame*CFrame.new(0,0,-10));require(script.Parent.MovementGuard).Reset(p)
   return true,'Teleported near the Void Pack.'
  end
  return false,'Use event spawn, clear, go or status.'
 elseif action=='training'then
  if #a~=0 then return false,'Use training [@username].'end
  local points=data:GetOrCreateSpeedValue(p).Value
  return true,'Treadmill only | base '..ctx.Config.TrainingPointsPerSecond..'/s | multiplier '..ctx.Bases:GetTreadmillMultiplier(p)..' | friends x'..string.format('%g',math.floor(ctx.Bases:GetFriendGainMultiplier(p)*100+.5)/100)..' | total '..string.format('%g',math.floor(ctx.Config.TrainingPointsPerSecond*ctx.Bases:GetTreadmillMultiplier(p)*ctx.Bases:GetFriendGainMultiplier(p)*100+.5)/100)..'/s | training '..tostring(p:GetAttribute('TreadmillTraining')==true)..' | physical '..string.format('%.2f',ctx.Config.GetPlayerWalkSpeed(p,points))..' | points '..points
 elseif action=='odds'then
  local st,key,luck,word
  if a[1]=='event'or a[1]=='eclipse'then st=7;key='EclipseReliquary';word=a[2];if #a>2 then return false,'Use odds event [luck|clover].'end
  elseif a[1]=='verity'then st=7;key='VerityReliquary';word=a[2];if #a>2 then return false,'Use odds verity [luck|clover].'end
  else st=stage(a[1]);key=variant(a[2]);word=a[3];if #a>3 then return false,'Use odds <biome> <tier> [luck].'end end
  -- R154: a Void / Verity pack takes ONLY the luck passes' luck (the 4 Leaf Clover's x2; boots never change it): the player's own, or x2 with the word "clover".
  local fixed=Packs.FixedOddsKind(st,key,Packs.OddsVersion)~=nil;local clover=1
  if fixed then
   clover=(word=='clover')and(T.PassLuckCeiling or 2)or(type(data.PassLuck)=='function'and data:PassLuck(p))or 1
   if word=='clover'then word=nil end
  end
  luck=tonumber(word or p:GetAttribute('ChestLuckMultiplier')or 1)
  local ceiling=T.LuckCeiling or T.MaxLuck
  if not st or st>=8 or not key or not luck or luck~=luck or luck<1 or luck>ceiling then return false,'Use odds storm mythic [1–'..ceiling..'], odds event [clover] or odds verity [clover].'end
  local cloverText=' | boots never change this pack; the 4 Leaf Clover '..(clover>1 and'x'..clover..' is on'or'is off (odds event clover shows it)')
  local lines={key=='EclipseReliquary'and 'Void Pack | all regular Secret/Cosmic/King seeds | 1/200 normal Mech roll'..cloverText or key=='VerityReliquary'and 'Verity Pack | Verity seed 1/100, then the Void pack without its King seeds (1/200 Mech roll without the Crowncore Tree)'..cloverText or ctx.Config.BiomeNames[st]..' | '..Packs.GetPackTier(key).Name..' | luck '..luck};local odds=Packs.SeedOdds(ctx.Config,st,key,luck,Packs.OddsVersion,nil,clover)
  for _,seed in ipairs(Packs.OddsRows(ctx.Config,st,key,odds))do table.insert(lines,seed.Name..': '..require(RS.OddsText85).Format(odds[seed.Id]))end -- R148: by rarity rank, then name
  return true,table.concat(lines,'\n')
 elseif action=='pity'then
  local cycle=integer(a[1],0,1000000);if #a~=1 or not cycle then return false,'Use pity <completed reset number>.'end
  local plan=require(RS.PackSchedule81).Plan(cycle,table.create(35,'Pack01'),function(lo)return lo end)
  return true,'Reset '..cycle..': 35 ordinary slots | Legendary guaranteed '..tostring(table.find(plan,'Pack05')~=nil)..' | Mythic guaranteed '..tostring(table.find(plan,'Pack06')~=nil)..' | event '..tostring(require(RS.PackSchedule81).Event(cycle))
 elseif action=='packluck'then
  -- R137 owner check of the hidden pack-size pity (players never see it): packluck @name [5x count] [10x count].
  if #a>2 then return false,'Use packluck @username [packs since a 5x+] [packs since a 10x+].'end
  if #a>=1 then
   local big,giant=integer(a[1],0,1000000),a[2]and integer(a[2],0,1000000)or data:GetPackLuck(p).Giant
   if not big or not giant then return false,'Use packluck @username [packs since a 5x+] [packs since a 10x+].'end
   data:LoadPackLuck(p,{Big=big,Giant=giant});save(ctx,p)
  end
  local mine,track=data:GetPackLuck(p),require(RS.PackSizePity).State(ctx.Chests.TrackLuck)
  return true,p.Name..': '..mine.Big..' packs since a 5x+ (sure by 30), '..mine.Giant..' since a 10x+ (sure by 200) | track: '..track.Big..' refreshes since a 5x+ (sure by 6), '..track.Giant..' since a 10x+ (sure by 12)'
 elseif action=='daily'then
  -- R140 owner test of the login week and daily quests without waiting for midnight UTC:
  -- daily [@name] | daily next (a new day: the login claim and fresh quest progress) | daily done (finish today's
  -- quests) | daily week (the next claim is day 7, the Void Pack) | daily reset. Every pack these make claimable is a TEST pack (below).
  local D=require(RS.DailyRewards);local sub=tostring(a[1]or''):lower()
  if #a>1 or(sub~=''and sub~='next'and sub~='done'and sub~='week'and sub~='reset')then return false,'Use daily [next|done|week|reset] @username.'end
  local daily,quests,day=data:DailyData(p)
  if sub=='next'then
   if daily.Login.Day==day then daily.Login.Day=day-1 end
   daily.Quests={Day=day,Progress={},Claimed={}};for i=1,#quests.Keys do daily.Quests.Progress[i]=0;daily.Quests.Claimed[i]=false end
  elseif sub=='done'then
   for i,q in ipairs(quests.Keys)do daily.Quests.Progress[i]=D.Quests[q].Goal end
  elseif sub=='week'then daily.Login={Step=#D.Login-1,Day=day-1}
  elseif sub=='reset'then data:GetPremium(p).Daily=nil end
  if sub~=''then
   -- R151: the login pack they make claimable is a TEST pack. R153 (review M1): so is every quest pack the command makes claimable (done: the unclaimed quests; next / reset: all
   -- of today's fresh quests), each with its own arm ('Daily' = the login pack, 'DailyQuest' = a quest pack) so one claim can't use up the other's. The arms last until UTC
   -- midnight (a test day), and the target is tainted for the hub boards (BEST PULL / BIGGEST FRUIT) like for every command that gives packs.
   local left=D.SecondsLeft(os.time())
   if sub=='next'or sub=='week'or sub=='reset'then TestPacks.Arm(p,'Daily',1,nil,left)end
   if sub~='week'then
    local _,fresh=data:DailyData(p);local open=0
    for i=1,#fresh.Keys do if not fresh.Claimed[i]then open+=1 end end
    TestPacks.Arm(p,'DailyQuest',open,nil,left)
   end
   local hub=ctx.Chase and ctx.Chase.HubDisplays;if hub then pcall(hub.NoteOwnerGrant,hub,p)end
   data:PublishDaily(p);save(ctx,p)
  end
  local state=data:DailyState(p);local rows={}
  for _,q in ipairs(state.Quests)do rows[#rows+1]=q.Text..' '..q.Progress..'/'..q.Goal..(q.Claimed and' ✓'or'')end
  return true,p.Name..': login day '..state.Login.Claimed..'/7 claimed'..(state.Login.Ready and(', day '..state.Login.Next..' ready')or', next tomorrow')..' | '..table.concat(rows,' | ')..' | new day in '..D.Countdown(state.ResetIn)
 elseif action=='mystery'then
  -- R141 owner test of the base's mystery pack without waiting 15 minutes or for midnight UTC:
  -- mystery [@name] | mystery ready (unlocks in 3 s) | mystery next (a new day) | mystery reset.
  local svc=ctx.Chase and ctx.Chase.Mystery;if not svc then return false,'The mystery pack service is not running.'end
  local M=require(RS.MysteryPackRules);local sub=tostring(a[1]or''):lower()
  if #a>1 or(sub~=''and sub~='ready'and sub~='next'and sub~='reset')then return false,'Use mystery [ready|next|reset] @username.'end
  local premium=data:GetPremium(p)
  if sub=='ready'then local st=svc:State(p);if st.Claimed then st.Claimed=false;st.Stage=nil;st.Variant=nil end;st.Seconds=M.UnlockSeconds-3
  elseif sub=='next'then local st=svc:State(p);st.Day=st.Day-1;premium.Mystery=st
  elseif sub=='reset'then premium.Mystery={Owed=M.Read(premium.Mystery).Owed} end -- (today's pack starts over; packs owed from earlier days are real and stay)
  if sub=='ready'or sub=='next'then TestPacks.Arm(p,'Mystery',1)end -- R151: the pack they make takeable is a TEST pack
  if sub~=''then svc:Publish(p,true);save(ctx,p)end
  if sub=='next'then TestPacks.Disarm(p,'Mystery')end -- (a pack carried over from yesterday was given by that Publish; a new day's pack is a normal one)
  local st=svc:State(p)
  local status=st.Claimed and'taken today'or M.Unlocked(st)and('ready: '..st.Variant..' stage '..st.Stage)or('locked, '..M.Clock(M.Left(st))..' to go')
  return true,p.Name..': mystery pack '..status..(#st.Owed>0 and(' | '..#st.Owed..' owed (Bag was full)')or'')..' | pedestal '..(svc.Owner[p]and'in their base'or'not assigned')
 elseif action=='bestpull'or action=='bigfruit'or action=='hubdisplays'then
  -- R151 owner tools for the hub's two corner displays (HubDisplayService). bestpull <seed id or plant name> [@name] = a test pull for that player (the seed's odds in
  -- its biome's Pack03); R153: it is this server's own and lasts until the 10-minute board resets (BEST PULL is never shared, so `share` is refused for it). bigfruit <kg> [gold|diamond] [share] [@name]
  -- = a test fruit of TODAY's type (this server only unless `share`). hubdisplays = print the state; hubdisplays reset = empty both boards (this server, and the fruit's shared document);
  -- hubdisplays day +1 = preview tomorrow's fruit (this server only; day 0 comes back; BEST PULL does not care).
  local hub=ctx.Chase and ctx.Chase.HubDisplays;if not hub then return false,'The hub displays are not running in this server.'end
  if action=='hubdisplays'then
   local sub=tostring(a[1]or''):lower()
   if sub==''or sub=='status'then if #a>1 then return false,'Use hubdisplays [reset | day +1 | day 0].'end
   elseif sub=='reset'then
    if #a>1 then return false,'Use hubdisplays reset.'end
    local removed=hub:Reset()
    return true,'BEST PULL is empty on this server (it is this server\'s own: nothing else to clear). BIGGEST FRUIT is empty for today on this server'..(removed and' and in the shared store'or'')..'. Other servers keep their own best fruit until they are reset too.\n'..hub:StatusText(p)
   elseif sub=='day'then
    local n=({['0']=0,today=0,['+1']=1,['1']=1,tomorrow=1,['-1']=-1,yesterday=-1,['+2']=2,['2']=2,['+7']=7,['7']=7})[tostring(a[2]or''):lower()]
    if #a~=2 or n==nil then return false,'Use hubdisplays day +1 (tomorrow\'s fruit), +2, +7, -1 or 0 (back to today).'end
    hub:SetDayOffset(n)
    return true,(n==0 and'Back to today.'or'Previewing day '..string.format('%+d',n)..' on this server only (nothing is shared while you preview). hubdisplays day 0 comes back.')..'\n'..hub:StatusText(p)
   else return false,'Use hubdisplays [reset | day +1 | day 0].'end
   return true,hub:StatusText(p)
  end
  local words,share,coat={},false,nil
  for _,w in ipairs(a)do
   local l=tostring(w):lower()
   if l=='share'then share=true
   elseif action=='bigfruit'and(l=='gold'or l=='diamond')then coat=l=='gold'and'Gold'or'Diamond'
   else words[#words+1]=w end
  end
  if action=='bestpull'then
   if share then return false,'BEST PULL is this server only now (it resets every 10 minutes and is never shared). Use bestpull <seed id or plant name> @username.'end
   if #words==0 then return false,'Use bestpull <seed id or plant name> @username.'end
   return hub:InjectPull(p,table.concat(words,' '))
  end
  if #words~=1 then return false,'Use bigfruit <kg> [gold|diamond] [share] @username.'end
  return hub:InjectFruit(p,words[1],coat,share)
 elseif action=='refreshcycle'then
  local cycle=integer(a[1],1,1000000);if #a~=1 or not cycle then return false,'Use refreshcycle <completed reset to test>.'end
  if ctx.Map.Refreshing then return false,'Refresh already running.'end
  map:SetAttribute('BiomeRefreshCycle',cycle-1);ctx.Chase:_beginBiomeRefresh(os.clock())
  return true,'Refreshing in 10s • reset '..cycle
 elseif action=='indexinfo'then
  if #a~=1 then return false,'Use indexinfo <biome|SeedId>.'end
  local st=stage(a[1]);local premium=data:GetPremium(p)
  if st then return true,'Completion reward: '..T.CompletionGems[st]..' Gems | complete '..tostring(data:BiomeComplete(p,st))..' | claimed '..tostring(premium.Biomes[tostring(st)]==true)..' | pending legacy difference '..tostring((premium.BiomeBackpay81 or{})[tostring(st)]or 0)end
  local id=seedId(a[1]);if not id then return false,'Unknown biome or SeedId.'end
  return true,id..' | first '..tostring(T.IndexFirst[id])..' Cash | repeat '..tostring(T.IndexRepeat[id])..' Cash | claimable '..tostring(premium.SeedRewards[id]or 0)
 end
 -- R123 tools: keeper fling / ragdoll previews, track holes, gift recovery and admin access.
 if action=='fling'then
  if #a>1 then return false,'Use fling <biome|darkened> [@username].'end
  local which=(a[1]or'storm'):lower();local dark=which=='dark'or which=='darkened'or which=='event'
  local st=not dark and stage(which);if not dark and(not st or st>=8)then return false,'Use fling forest…storm or fling darkened.'end
  local c=p.Character;local root=c and c:FindFirstChild('HumanoidRootPart');if not root then return false,'Wait for the target’s character.'end
  local K=require(RS.KnockbackConfig);local h,v
  if dark then h,v=K.SpecialKeeper.Horizontal,K.SpecialKeeper.Vertical
  else local settings=ctx.Chase:_getGuardianSettings(st);h,v=settings.FlingHorizontal,settings.FlingVertical end
  local back=-root.CFrame.LookVector;back=Vector3.new(back.X,0,back.Z);back=back.Magnitude>.01 and back.Unit or Vector3.new(0,0,-1)
  if not ctx.Chase.Ragdoll:Apply(p,back*h+Vector3.new(0,v,0),'Keeper')then return false,'Target can’t be flung right now (already ragdolled or no character).'end
  return true,'Flung like the '..(dark and'The Darkened'or ctx.Config.BiomeNames[st])..' keeper: '..h..' sideways / '..v..' up. Nothing dropped.'
 elseif action=='ragdoll'then
  local seconds=tonumber(a[1]or'4');if #a>1 or not seconds or seconds~=seconds or seconds<.5 or seconds>10 then return false,'Use ragdoll [0.5–10 seconds] [@username].'end
  if not ctx.Chase.Ragdoll:Apply(p,Vector3.new(0,12,0),'Hole',seconds)then return false,'Target can’t be ragdolled right now.'end
  return true,'Ragdolled for '..seconds..' s (same as falling in a hole). Nothing dropped.'
 elseif action=='holes'then
  local holes=ctx.Chase.TrackHoles;if not holes then return false,'Track holes are not running.'end
  if a[1]=='clear'and #a==1 then local n=holes.Count;holes:ClearAll();return true,'Removed '..n..' holes from the track.'end
  if #a~=0 then return false,'Use holes (list) or holes clear.'end
  local C=require(RS.TrackHoleConfig);local lines={'Holes on the track: '..holes.Count..'/'..C.MaxPerServer..' | max '..C.MaxPerPlayer..' each | last '..C.LifetimeSeconds..' s'}
  for owner,list in pairs(holes.ByOwner)do local n=0;for _ in pairs(list)do n+=1 end;if n>0 then lines[#lines+1]='@'..owner.Name..': '..n end end
  return true,table.concat(lines,'\n')
 elseif action=='dig'then
  if #a~=0 then return false,'Use dig [@username] (the target must hold the shovel on the track).'end
  local holes=ctx.Chase.TrackHoles;if not holes then return false,'Track holes are not running.'end
  holes.NextDig[p]=nil;pcall(function()require(script.Parent.SecurityGate).Cleanup(p)end)
  local ok,why=holes:Request(p)
  local reasons={Shovel='Equip the shovel first.',OffTrack='Stand on the track.',Carrying='Can’t dig while carrying a pack.',PlayerCap='Already has the maximum number of holes.',Pack='Too close to a pack.',Camp='Too close to a keeper.',Spacing='Too close to another hole.',Entrance='Too close to the entrance.',Ground='No ground here.',Refreshing='The track is refreshing.',Downed='Target is ragdolled.'}
  return ok,ok and(why=='Covered'and'Covered one of the target’s holes.'or'Dug a hole at the target’s feet (cooldown skipped).')or(reasons[why]or tostring(why))
 elseif action=='gifts'then
  local gifts=ctx.Chase.Gifts;if not gifts then return false,'Gift service is not running.'end
  if a[1]=='recover'and #a==1 then task.spawn(function()gifts:Recover(p)end);return true,'Gift recovery started for the target (pending sends and received gifts).'end
  if #a~=0 then return false,'Use gifts [@username] or gifts recover [@username].'end
  local garden=data.Gardens[p]or{};local function count(t)local n=0;for _ in pairs(t or{})do n+=1 end;return n end
  return true,'Waiting to finish: fruit '..count(garden.OutgoingGifts)..' | seeds/packs '..count(garden.OutgoingSeedGifts)..'. These clear within about a minute while both players are online.'
 elseif action=='bonus'then
  local bonus=ctx.Chase.TreadmillBonus;if not bonus then return false,'Treadmill bonus is not running.'end
  local mode=(a[1]or'status'):lower()
  if mode=='ready'then
   local n=integer(a[2]or'1',0,2);if #a>2 or not n then return false,'Use bonus ready <0–2>.'end
   bonus.Ready[p]=0;local ok,ready=bonus:GrantReady(p,n);TestPacks.Arm(p,'Bonus',n);return ok,'Bonus rolls ready: '..tostring(ready) -- R151: those rolls make TEST packs
  elseif mode=='progress'then
   local text=a[2]or'';local m,sec=text:match('^(%d+):(%d%d)$');local seconds=m and tonumber(m)*60+tonumber(sec)or tonumber(text)
   local interval=require(game:GetService('ReplicatedStorage').TreadmillBonusRules).IntervalSeconds -- R124: 360 s (was 600)
   if #a~=2 or not seconds or seconds~=seconds or seconds<0 or seconds>interval then return false,'Use bonus progress <0–'..interval..' seconds or m:ss>, e.g. bonus progress 5:50.'end
   local ok,left=bonus:SetProgress(p,seconds);TestPacks.Arm(p,'Bonus',1);return ok,'Saved treadmill progress: '..math.floor(tonumber(left)or 0)..' / '..interval..' s. Get on the treadmill to see the bar.'
  elseif mode=='roll'then
   if #a~=1 then return false,'Use bonus roll.'end
   TestPacks.Arm(p,'Bonus',1);local result=bonus:Roll(p);TestPacks.Disarm(p,'Bonus');if result.Error then return false,result.Error end -- R151: this roll is a TEST pack
   return true,'Rolled for the target (no animation): '..tostring(result.Label or result.Variant)..' ('..tostring(result.Rarity)..'). Ready left: '..tostring(result.Ready)..'.'
  elseif mode=='status'then
   if #a>1 then return false,'Use bonus, bonus ready <n>, bonus progress <s> or bonus roll.'end
   local names={};for _,st in ipairs(bonus:Pool(p))do names[#names+1]=ctx.Config.BiomeNames[st]end
   return true,'Ready '..bonus:GetReady(p)..'/2 | saved progress '..math.floor(bonus:GetProgress(p))..'/'..require(game:GetService('ReplicatedStorage').TreadmillBonusRules).IntervalSeconds..' s | on treadmill '..tostring(p:GetAttribute('TreadmillTraining')==true)..' | pool: '..table.concat(names,', ')
  end
  return false,'Use bonus, bonus ready <n>, bonus progress <s> or bonus roll.'
 elseif action=='admins'then
  if #a~=0 then return false,'Use admins.'end
  local ids=script.Parent.OwnerCommandAccess:GetAttribute('AdminUserIds')
  local lines={'Owner: '..(game.CreatorType==Enum.CreatorType.Group and('group '..game.CreatorId..' owner')or('user '..game.CreatorId)),'Extra admins (AdminUserIds on ServerScriptService.ChestChaseServer.OwnerCommandAccess): '..((ids and ids~='')and ids or'none')}
  for _,other in ipairs(Players:GetPlayers())do if require(script.Parent.OwnerCommandAccess).IsAllowed(other)then lines[#lines+1]='In this server with access: @'..other.Name end end
  return true,table.concat(lines,'\n')
 end
 local okay,why=safe(ctx,p);if not okay then return false,why end
 if action=='fence'then
  local tier=integer(a[1],1,7);if #a~=1 or not tier then return false,'Use fence <1–7>.'end
  data.Fences=data.Fences or{};data.Fences[p]=tier;data:PublishFenceData(p)
  require(script.Parent.GardenUpgradeService).Refresh(ctx.Bases,p);save(ctx,p)
  return true,'Fence tier '..tier..'. Bonuses apply to new planting and later fruit growth.'
 elseif action=='movespeed'then
  if #a~=1 then return false,'Use movespeed <24–500|off>.'end
  local n=a[1]=='off'and nil or tonumber(a[1])
  if a[1]~='off'and(not n or n~=n or n<24 or n>500)then return false,'Physical test speed must be 24–500.'end
  State.SetSpeed(p,n);p:SetAttribute('StudioMovementSpeedOverride',nil);applySpeed(ctx,p)
  return true,n and('Temporary movement speed: '..n..'. Earned points unchanged.')or'Normal earned movement restored.'
 elseif action=='animrate'then
  if #a~=1 then return false,'Use animrate <0.1–10|off>.'end
  local n=a[1]=='off'and nil or tonumber(a[1]);if a[1]~='off'and(not n or n~=n or n<.1 or n>10)then return false,'Animation rate must be 0.1–10.'end
  p:SetAttribute('OwnerAnimationRate82',n);return true,n and('Temporary run animation rate: '..n..'x')or'Normal animation scaling restored.'
 elseif action=='eclipse'or action=='packset'or action=='verity'then
  -- R147: verity [1-20] = Verity packs, like eclipse = Void packs. (A bad number is refused for verity; eclipse keeps its old
  -- "or 6" fallback, which silently gave 6 Void packs for a bad number.)
  local count,st
  if action=='verity'then count=integer(a[1]or'1',1,20);st=7
  else count=action=='eclipse'and integer(a[1]or'1',1,20)or 6;st=action=='eclipse'and 7 or stage(a[1])end
  if #a>1 or not count or not st or st>=8 then return false,action=='eclipse'and'Use eclipse [1–20].'or action=='verity'and'Use verity [1–20].'or'Use packset <biome>.'end
  if #data:GetChestRecords(p)+count>ctx.Config.MaxSavedChests then return false,'Make space in the target inventory.'end
  for i=1,count do
   local record,reason=data:AddChest(p,{Stage=st,BagVariant=action=='eclipse'and'EclipseReliquary'or action=='verity'and'VerityReliquary'or string.format('Pack%02d',i),PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{TestGrant=true}) -- R151: TEST packs (never announced)
   if not record then return false,'Stopped after '..(i-1)..' packs: '..tostring(reason)end
  end
  ctx.Chests:SyncTools(p);save(ctx,p);return true,'Added '..count..' packs with the current odds.'
 elseif action=='gems'then
  local amount=integer(a[2],0,require(RS.MechCatalog).MaxGems)
  if #a~=2 or(a[1]~='set'and a[1]~='add')or not amount then return false,'Use gems set/add <amount>.'end
  local premium=data:GetPremium(p);if a[1]=='add'then amount+=premium.Gems end
  local pending=require(RS.SaleReceiptRules).Total(data.Gardens[p].PendingSales or{},'Gems')
  if amount+pending>require(RS.MechCatalog).MaxGems then return false,'Gem limit includes pending rewards.'end
  premium.Gems=amount;data:PublishPremium(p);save(ctx,p);return true,'Gems: '..amount
 elseif action=='boots'or action=='trail'then
  local products=action=='boots'and ctx.Config.ShopCatalog.Accessories or ctx.Config.ShopCatalog.Trails
  local i=integer(a[1],1,#products);if #a~=1 or not i then return false,'Use '..action..' <1–'..#products..'>.'end
  local product=products[i];data:AddBoost(p,product.Id,action=='boots'and{TestGrant=true}or nil);data:EquipBoost(p,product.Id);data:RefreshBoostMultipliers(p);save(ctx,p)
  return true,'Unlocked '..product.Name..'. Highest owned upgrade supplies the bonus.'..(action=='boots'and' Pulls with these boots are TEST pulls (never announced, never on the hub boards).'or'')
 elseif action=='bundle'then
  if #a~=1 then return false,'Use bundle <bundle key>.'end
  local found;for _,row in ipairs(require(RS.PremiumPricing).Bundles)do if row.Key:lower()==a[1]:lower()then found=row end end
  if not found then return false,'Unknown bundle key. See help.'end
  local granted,reason=data:GrantPremiumBundle(p,found.Key);if granted then applySpeed(ctx,p);save(ctx,p)end
  return granted,granted and('Test grant: '..found.Name..'. No purchase charged.')or tostring(reason)
 elseif action=='claimindex'then
  if #a~=1 then return false,'Use claimindex <biome|SeedId>.'end
  local st=stage(a[1]);if st then return data:ClaimIndexBiome(p,st)end
  local id=seedId(a[1]);if not id then return false,'Unknown biome or SeedId.'end
  return data:ClaimIndexSeed(p,id)
 end
 return false,'Unknown update command.'
end
return X
