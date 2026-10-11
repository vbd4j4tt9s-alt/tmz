-- R158l (owner: "I can make them rain from the sky"): /test packrain. Owner-only (OwnerParty158l checks); this module is the rain itself. Session only, nothing is saved but what a player picks up.
--  * Where     random spots all over the map: 40% around a random player (10-55 studs), the rest on the hub floor, the track and the bases (PartyRules158l.Rain). Each spot is found by a
--              ray from the sky (no water, no invisible wall tops); a spot without ground is tried again (6 times), then that pack is skipped.
--  * When      the packs are spread over the rain's seconds at random times, a random pack each (any biome, common .. mythic, the odds in Rain.TierWeights) unless the owner named a
--              biome and / or a rarity. At most Rain.MaxAtOnce (100) exist at once (falling + lying); a pack that does not fit yet waits for room (the rest is dropped 30 s after the end).
--  * Look      a pack is built like every world pack (ChestService:BuildSeedPacket, the R158b highlight / marker / beam read it: the host model has DroppedChest = true) at a random size
--              of 0.6x - 2x (the look only). It is made at its landing spot; the screens draw the fall (PackRainFx158l: 90-140 studs, a spin, a trail) from the attributes RainLandAt /
--              RainFall / RainHeight / RainSpin, so the server moves nothing.
--  * Taking    TOUCH: the first player whose character touches the pack's box gets it straight into the Bag (PlayerData:AddChest, TestGrant = true: never announced, no BEST PULL), no
--              prompt, no keeper. Once only (pack.Taken). The box is up Rain.TouchLead (.2 s) before the pack lands; one overlap query at that moment catches a player standing still
--              on the spot. A full Bag leaves the pack where it is (a notice, at most one every 2 s per player; the game owner's Bag has no cap).
--  * Leaving   an untouched pack is removed Rain.LingerSeconds (10) after it LANDS (the screens shrink it away in the last .5 s). /test packrain off removes every pack at once.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService');local Run=game:GetService('RunService')
local Rules=require(RS:WaitForChild('PartyRules158l'));local Cfg=Rules.Rain
local Packs=require(RS:WaitForChild('SeedPackRules'))
local Access=require(script.Parent.OwnerCommandAccess)
local M={State=nil,Last=nil}
local function isOwner(p)local f=Access.IsOwner;return type(f)=='function'and f(p)==true end
local function folder()
 local f=workspace:FindFirstChild(Cfg.Folder)
 if not f then f=Instance.new('Folder');f.Name=Cfg.Folder;f.Parent=workspace end
 return f
end
local function notify(ctx,player,text,color,seconds)
 local n=(ctx.Chase and ctx.Chase.Notifications)or(ctx.Data and ctx.Data.Notifications)
 if n and n.Show then pcall(n.Show,n,player,text,color or Color3.fromRGB(255,214,90),seconds or 3)end
end
local function randomTier()
 local total=0;for _,w in ipairs(Cfg.TierWeights)do total+=w end
 local roll=math.random()*total
 for i,w in ipairs(Cfg.TierWeights)do roll-=w;if roll<=0 then return i end end
 return 1
end
-- Where packs may land ----------------------------------------------------------------------------------------------------------------------------------------
local function regions(ctx)
 local map=ctx.Map;local out={Hub=nil,Track=nil,Bases={}}
 local lobby=map and map.LobbyFolder;local floor=lobby and lobby:FindFirstChild('LobbyFloor')
 if floor then out.Hub={X=floor.Position.X,Z=floor.Position.Z,HX=floor.Size.X/2,HZ=floor.Size.Z/2}end
 local line=map and map.BaseBoundaryLine
 if line and ctx.Config then
  local half=math.max(90,line.Size.X/2)+24;local z0=math.min(ctx.Config.BiomeTrackStartZ or line.Position.Z,line.Position.Z);local z1=ctx.Config.BiomeTrackEndZ or 1445
  out.Track={X=line.Position.X,Z=(z0+z1)/2,HX=half,HZ=math.max(1,(z1-z0)/2)}
 end
 for _,record in ipairs(map and map.BaseRecords or{})do
  local spawn=record.Spawn;if spawn and spawn.Position then out.Bases[#out.Bases+1]={X=spawn.Position.X,Z=spawn.Position.Z,HX=45,HZ=45}end
 end
 return out
end
local function refreshParams(ctx)
 local p=M.Params;if not p then p=RaycastParams.new();M.Params=p end
 p.FilterType=Enum.RaycastFilterType.Exclude;p.RespectCanCollide=true;p.IgnoreWater=false
 local list={folder()};local runtime=ctx.Map and ctx.Map.RuntimeFolder;if runtime then list[#list+1]=runtime end
 for _,pl in ipairs(Players:GetPlayers())do if pl.Character then list[#list+1]=pl.Character end end
 p.FilterDescendantsInstances=list
end
local function ground(x,z)
 local top=600
 local hit=workspace:Raycast(Vector3.new(x,top,z),Vector3.new(0,-(top+300),0),M.Params)
 if not hit or hit.Normal.Y<=.7 or hit.Material==Enum.Material.Water then return nil end
 local part=hit.Instance;if part and part.Transparency>=.95 then return nil end -- (the top of an invisible wall)
 return hit.Position
end
local function inRegion(r)return r.X+(math.random()*2-1)*r.HX,r.Z+(math.random()*2-1)*r.HZ end
local function pickSpot(ctx,roots,areas)
 for _=1,6 do
  local x,z
  if math.random()<Cfg.NearPlayers and#roots>0 then
   local at=roots[math.random(1,#roots)].Position;local angle=math.random()*math.pi*2;local d=Cfg.NearMin+math.random()*(Cfg.NearMax-Cfg.NearMin)
   x,z=at.X+math.cos(angle)*d,at.Z+math.sin(angle)*d
  else
   local list,weights={},{}
   if areas.Hub then list[#list+1]=areas.Hub;weights[#weights+1]=.35 end
   if areas.Track then list[#list+1]=areas.Track;weights[#weights+1]=.45 end
   if#areas.Bases>0 then list[#list+1]={Bases=areas.Bases};weights[#weights+1]=.20 end
   if#list==0 then return nil end
   local total=0;for _,w in ipairs(weights)do total+=w end
   local roll=math.random()*total;local choice=list[#list]
   for i,w in ipairs(weights)do roll-=w;if roll<=0 then choice=list[i];break end end
   if choice.Bases then choice=choice.Bases[math.random(1,#choice.Bases)]end
   x,z=inRegion(choice)
  end
  local g=ground(x,z);if g then return g end
 end
 return nil
end
-- One pack ------------------------------------------------------------------------------------------------------------------------------------------------------
local function remove(st,pack)
 if pack.Gone then return end
 pack.Gone=true;st.Packs[pack.Host]=nil;st.Alive-=1
 if pack.Host.Parent then pack.Host:Destroy()end
end
local function playerOf(hit)
 local model=hit and hit.FindFirstAncestorWhichIsA and hit:FindFirstAncestorWhichIsA('Model')
 return model and Players:GetPlayerFromCharacter(model)or nil
end
local function take(ctx,st,pack,player)
 if pack.Taken or pack.Gone or not player or player.Parent~=Players then return false end
 local now=os.clock();if now<pack.ActiveAt then return false end
 local data=ctx.Data;if not data or not data:IsLoaded(player)then return false end
 local character=player.Character;local humanoid=character and character:FindFirstChildOfClass('Humanoid');if not humanoid or humanoid.Health<=0 then return false end
 pack.Taken=true -- (first come, once: nothing yields from here to the end of the grant)
 local ok,record,why=pcall(function()
  return data:AddChest(player,{Stage=pack.Stage,BagVariant=pack.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Packs.OddsVersion},{TestGrant=true,Owner=isOwner(player)})
 end)
 if not ok or not record then
  pack.Taken=false
  if not ok then warn('[R158l] Pack rain grant failed: '..tostring(record))end
  if now-(st.Warned[player]or-9)>2 then st.Warned[player]=now;notify(ctx,player,ok and tostring(why or'BAG FULL - MAKE ROOM IN YOUR BAG FIRST')or'PACK COULD NOT BE STORED',Color3.fromRGB(255,187,91),3)end
  return false
 end
 pcall(function()ctx.Chests:SyncTools(player)end)
 pcall(function()if data.QueueGardenSave then data:QueueGardenSave(player)end end)
 st.Taken+=1;st.Takers[player]=(st.Takers[player]or 0)+1
 notify(ctx,player,'\u{1F4E6} '..pack.Label..' pack!',Color3.fromRGB(255,214,90),3)
 remove(st,pack)
 return true
end
local function overlapCheck(ctx,st,pack) -- a player already standing on the spot when the box comes up (Touched only fires when something starts to overlap)
 local characters={};for _,pl in ipairs(Players:GetPlayers())do if pl.Character then characters[#characters+1]=pl.Character end end
 if#characters==0 then return end
 local ok,parts=pcall(function()
  local params=OverlapParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=characters
  return workspace:GetPartBoundsInBox(pack.Touch.CFrame,pack.Touch.Size,params)
 end)
 if ok and type(parts)=='table'then for _,part in ipairs(parts)do if take(ctx,st,pack,playerOf(part))then return end end end
end
local function spawnOne(ctx,st,roots,areas)
 local stage=st.Stage or math.random(1,7);local tier=st.Tier or randomTier()
 local at=pickSpot(ctx,roots,areas);if not at then return false end
 local variant=string.format('Pack%02d',tier)
 local scale=Cfg.ScaleMin+math.random()*(Cfg.ScaleMax-Cfg.ScaleMin)
 local bounds=ctx.Chests:GetPackBounds(stage,variant,1)
 local position=Vector3.new(at.X,at.Y+.6-(bounds.MinY or 0)*scale,at.Z)
 local fall=Cfg.FallMin+math.random()*(Cfg.FallMax-Cfg.FallMin)
 local now,serverNow=os.clock(),workspace:GetServerTimeNow()
 local host=Instance.new('Model');host.Name=string.format('RainPack_Stage%d',stage)
 host:SetAttribute('DroppedChest',true) -- (the R158b outline, marker and beam: DroppedPackLook158b.Attribute)
 host:SetAttribute('Stage',stage);host:SetAttribute('BagVariant',variant);host:SetAttribute('PackSize',1);host:SetAttribute('PackMutation','None')
 host:SetAttribute('RainScale',scale);host:SetAttribute('RainFall',fall);host:SetAttribute('RainLandAt',serverNow+fall)
 host:SetAttribute('RainHeight',Cfg.HeightMin+math.random()*(Cfg.HeightMax-Cfg.HeightMin))
 host:SetAttribute('RainSpin',(Cfg.SpinMin+math.random()*(Cfg.SpinMax-Cfg.SpinMin))*(math.random()<.5 and-1 or 1))
 host:SetAttribute('RainEndAt',serverNow+fall+Cfg.LingerSeconds)
 host.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 host.Parent=folder()
 local body=Instance.new('Part');body.Name='Body';body.Size=Vector3.new(.2,.2,.2);body.Transparency=1;body.Anchored=true;body.CanCollide=false;body.CanTouch=false;body.CanQuery=false
 body.CFrame=CFrame.new(position);body.Parent=host;host.PrimaryPart=body
 local Shapes=require(RS:WaitForChild('PackShapes151'))
 local built=pcall(function()
  ctx.Chests:BuildSeedPacket(nil,body.CFrame,host,scale,body,stage,variant,Packs.NewSeedScale(stage,variant,1),1,'None',Shapes.Applies(variant)and Shapes.Roll(variant)or nil)
 end)
 if not built then host:Destroy();return false end
 local radius=math.min(12,(bounds.Radius or 2)*scale)
 local touch=Instance.new('Part');touch.Name='TouchBox';touch.Transparency=1;touch.Anchored=true;touch.CanCollide=false;touch.CanTouch=true;touch.CanQuery=false;touch.CastShadow=false
 touch.Size=Vector3.new(radius*2+3,9,radius*2+3);touch.CFrame=CFrame.new(at.X,at.Y+4.5,at.Z);touch.Parent=host
 local pack={Host=host,Touch=touch,Stage=stage,Variant=variant,Label=Rules.TierNames[tier]..' '..Rules.BiomeNames[stage],
  ActiveAt=now+fall-Cfg.TouchLead,ExpireAt=now+fall+Cfg.LingerSeconds,Taken=false,Checked=false}
 touch.Touched:Connect(function(hit)if not pack.Taken and not pack.Gone and os.clock()>=pack.ActiveAt then take(ctx,st,pack,playerOf(hit))end end)
 CS:AddTag(host,Cfg.Tag)
 st.Packs[host]=pack;st.Alive+=1
 return true
end
-- The rain ----------------------------------------------------------------------------------------------------------------------------------------------------------
local function finish(st)
 if st.Connection then st.Connection:Disconnect();st.Connection=nil end
 M.Last={Spawned=st.Spawned,Missed=st.Missed,Taken=st.Taken,Wanted=st.Wanted};if M.State==st then M.State=nil end
end
local function step(ctx,st)
 local now=os.clock()
 local list={};for _,pack in pairs(st.Packs)do list[#list+1]=pack end
 for _,pack in ipairs(list)do
  if not pack.Host.Parent then pack.Gone=true;st.Packs[pack.Host]=nil;st.Alive-=1
  elseif now>=pack.ExpireAt then remove(st,pack);st.Expired+=1
  elseif not pack.Checked and now>=pack.ActiveAt then pack.Checked=true;overlapCheck(ctx,st,pack)end
 end
 if st.Next<=#st.Due then
  if now>st.Deadline then st.Next=#st.Due+1
  elseif now>=st.Start+st.Due[st.Next]then
   refreshParams(ctx)
   local roots={};for _,pl in ipairs(Players:GetPlayers())do local c=pl.Character;local r=c and c:FindFirstChild('HumanoidRootPart');if r then roots[#roots+1]=r end end
   local areas=regions(ctx);local made=0
   while st.Next<=#st.Due and now>=st.Start+st.Due[st.Next]and st.Alive<Cfg.MaxAtOnce and made<Cfg.PerStep do
    st.Next+=1;made+=1
    if spawnOne(ctx,st,roots,areas)then st.Spawned+=1 else st.Missed+=1 end
   end
  end
 end
 if st.Next>#st.Due and st.Alive<=0 then finish(st)end
end
-- opts = PartyRules158l.ParseRain's {Count,Seconds,Stage,Tier}. A second rain keeps the packs already lying and starts a new schedule.
function M.Start(ctx,opts)
 if not ctx.Chests or type(ctx.Chests.BuildSeedPacket)~='function'then return false,'Packs are not running in this server.'end
 local st=M.State
 if not st then st={Packs={},Alive=0,Warned=setmetatable({},{__mode='k'}),Takers=setmetatable({},{__mode='k'}),Taken=0,Expired=0};M.State=st end
 local due={};for i=1,opts.Count do due[i]=math.random()*opts.Seconds end
 table.sort(due)
 st.Due,st.Next,st.Start,st.Seconds=due,1,os.clock(),opts.Seconds;st.Deadline=st.Start+opts.Seconds+30
 st.Stage,st.Tier,st.Wanted=opts.Stage,opts.Tier,opts.Count;st.Spawned,st.Missed=0,0
 if not st.Connection then
  local acc=0
  st.Connection=Run.Heartbeat:Connect(function(dt)
   acc+=dt;if acc<Cfg.StepSeconds then return end;acc=0
   local ok,err=pcall(step,ctx,st);if not ok then warn('[R158l] Pack rain step: '..tostring(err))end
  end)
 end
 for _,pl in ipairs(Players:GetPlayers())do notify(ctx,pl,Cfg.Notice,Color3.fromRGB(255,214,90),4)end
 local what=(opts.Tier and Rules.TierNames[opts.Tier]..' 'or'')..(opts.Stage and Rules.BiomeNames[opts.Stage]..' 'or'')
 return true,string.format('%s %d %spacks fall over %d s, anywhere on the map (at most %d at once). Touch one to take it; an untouched pack is gone %d s after it lands. /test packrain off stops it.',Cfg.Notice,opts.Count,what==''and'random 'or what,opts.Seconds,Cfg.MaxAtOnce,Cfg.LingerSeconds)
end
-- Stops the rain and removes every pack at once. Returns ok, text.
function M.Stop()
 local st=M.State;local removed=0
 if st then
  local list={};for _,pack in pairs(st.Packs)do list[#list+1]=pack end
  for _,pack in ipairs(list)do remove(st,pack);removed+=1 end
  finish(st)
 end
 local f=workspace:FindFirstChild(Cfg.Folder);if f then f:ClearAllChildren()end
 return true,st and('The pack rain is off ('..removed..' packs removed).')or'No pack rain is running.'
end
function M.Status()
 local st=M.State
 if not st then local l=M.Last;return true,l and string.format('No pack rain is running. The last one: %d of %d packs fell, %d taken, %d could not find ground.',l.Spawned,l.Wanted,l.Taken,l.Missed)or'No pack rain is running.'end
 return true,string.format('Pack rain running: %d of %d packs fell, %d lying or falling now (cap %d), %d taken, %d expired.',st.Spawned,st.Wanted,st.Alive,Cfg.MaxAtOnce,st.Taken,st.Expired)
end
return M
