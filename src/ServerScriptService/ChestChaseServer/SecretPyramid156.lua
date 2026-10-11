-- R156: the Desert's secret pyramid (the numbers and the rules: ReplicatedStorage.PyramidRules156; the floating pack and the prompt per player: SecretPyramidClient156).
--  * Apply(map)  a MAP PASS (MapService.new, after TrackExpansion83 has moved the scenery and before the keyboard scan and the pack-placement cache): measures the
--                Sunscar Pyramid (MythicLandmarks.Biome2_Landmark: its bottom tier's centre and foot), builds the owner's Classic Pyramid there (hollow, 60 anchored
--                Limestone parts and one invisible part at the pack's centre) and only then removes the old one. Same folder and name, so everything that looks for
--                the Desert landmark finds the new one; walk-through like every landmark (WalkthroughProps90, R95). A pass that fails leaves the old pyramid.
--  * new(...)    the SERVICE (ChestChaseServerMain, inside a pcall: a failure means no secret pack, never a broken server):
--      Trigger   "Hold E" (the steal prompt: same text, key and hold as a world pack; RequiresLineOfSight off; reach = PyramidRules156.Reach). The server checks every
--                trigger: not claimed, not carrying (this pack or any), inside the zone (+ Slack), not spammed (Cooldown + SecurityGate), then the NORMAL steal checks
--                (ConcurrentKeeperService._canTake: the refresh closure, a chase or a reveal, a ragdoll, the data, the base, the 200 cap with its BAG FULL message).
--                Then the normal carry: _acceptSeed with a Desert Mythic world-pack record (Stage 2, Pack06, size 1, coat PyramidRules156.Mutation, the odds of
--                today's world packs): the Sand Snake (the Desert keeper, stage 2) chases it exactly as it chases a stolen Desert pack, FIFO with the other carriers.
--      Banked    ChestService:Bank calls it in the same step that put the pack in the Bag: Premium.Secrets156.Pyramid = true, saved soon, 'Claimed'. Bank is the
--                normal one ({Luck = true, Banked = true}): the hidden pack-size pity and the pack pity count it like any world pack.
--      Returned  the chase hooks (HookChase) call it when the carry ends without a bank: caught by the snake (the hit lands as usual; the pack does NOT drop on
--                the track: it goes straight back into the pyramid for that player), a bat / lightning / a hole, a fall, a death, leaving. The player can try again.
--      HookChase Start puts three small wrappers on the chase service OBJECT (_dropChestAfterCatch, _returnPackToOrigin, _beginBiomeRefresh), so
--                ConcurrentKeeperService itself stays as it is (R149 freezes it). They act on a secret pack only; every other pack goes straight to the normal code.
--      Refresh   (R157 review fix) the biome refresh banks every carrier it finds (_evacuateBiomePlayers, the stale-runs loop: Finish(true)), and its time is public,
--                so a pyramid carrier would get the one-time pack with no chase. _beginBiomeRefresh is wrapped: BEFORE the original, every secret carry is ended with
--                Finish(false,false,run) (not banked, not caught: nothing drops on the track) and goes back into the pyramid ('Refresh' notice). Trigger also refuses
--                while the refresh runs and in the Rules.RefreshGuard seconds before it, so a run is not wasted.
--      Each player has their own pack: the state is per player (Out / the saved claim), published as the Player attribute PyramidRules156.Attr.
--  * Command     /test pyramid [@username] (status), /test pyramid @username reset (clears the claim; saved). OwnerUpdateCommands82 dispatches here.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Rules=require(RS:WaitForChild('PyramidRules156'))
local PackRules=require(RS:WaitForChild('SeedPackRules'))
local M={Version=156};M.__index=M
local RGB=Color3.fromRGB
local SAND,GOLD,AMBER=RGB(255,222,83),RGB(255,205,120),RGB(255,130,92)

-- Map pass -------------------------------------------------------------------------------------------------------------------------------------------------
-- The base of an existing landmark: centre (X, Z) and foot (Y) of its widest part (the Sunscar Pyramid's bottom tier). nil when it has no part.
function M.Measure(old)
 if not old then return nil end
 local best,area
 for _,d in ipairs(old:GetDescendants())do
  if d:IsA('BasePart')then local a=d.Size.X*d.Size.Z;if not area or a>area then best,area=d,a end end
 end
 if not best then return nil end
 local cf,s=best.CFrame,best.Size
 local up=math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z -- (its height in the world)
 return Vector3.new(cf.Position.X,cf.Position.Y-up/2,cf.Position.Z),math.max(s.X,s.Z)
end
-- Builds the pyramid with its base centre (on the ground) at `spot`. Returns the model (not parented).
function M.Build(spot)
 local model=Instance.new('Model');model.Name=Rules.ModelName;model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 model:SetAttribute('Stage',Rules.Pack.Stage);model:SetAttribute('LandmarkName',Rules.LandmarkName)
 model:SetAttribute('PyramidVersion',Rules.Version);model:SetAttribute('PyramidScale',Rules.Scale)
 model:SetAttribute('KeyboardClear',true) -- (KeyboardSkip152: every key under it is left out, not only the buried ones)
 local color=RGB(Rules.Color[1],Rules.Color[2],Rules.Color[3]);local material=Enum.Material[Rules.Material]
 local floor
 for _,spec in ipairs(Rules.Plan(Rules.Scale))do
  local p=Instance.new('Part');p.Name=spec.Name
  p.Size=Vector3.new(spec.Size[1],spec.Size[2],spec.Size[3])
  p.CFrame=CFrame.new(spot.X+spec.Pos[1],spot.Y+spec.Pos[2],spot.Z+spec.Pos[3])
  p.Color=color;p.Material=material;p.Transparency=0
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=true -- (walk-through like every landmark: WalkthroughProps90)
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p:SetAttribute('PyramidSlab',spec.Slab)
  p.Parent=model
  if spec.Kind=='Floor'then floor=p end
 end
 model.PrimaryPart=floor
 local g=Rules.Geometry(Rules.Scale)
 local anchor=Instance.new('Part');anchor.Name=Rules.AnchorName;anchor.Size=Vector3.new(1,1,1)
 anchor.CFrame=CFrame.new(spot.X,spot.Y+g.PackY,spot.Z);anchor.Transparency=1
 anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false
 Rules.WriteZone(anchor,Rules.Zone(spot,Rules.Scale))
 anchor.Parent=model
 CS:AddTag(anchor,Rules.Tag)
 return model
end
function M.Apply(map)
 local folder=map:FindFirstChild('MythicLandmarks')
 if not folder then folder=Instance.new('Folder');folder.Name='MythicLandmarks';folder.Parent=map end
 local old=folder:FindFirstChild(Rules.ModelName)
 if old and old:GetAttribute('PyramidVersion')==Rules.Version then return old end -- (built already)
 local spot,width=M.Measure(old)
 local from=spot and'the Sunscar Pyramid'or'the fallback spot'
 spot=spot or Vector3.new(Rules.Fallback.X,Rules.Fallback.Y,Rules.Fallback.Z)
 local model=M.Build(spot)
 model:SetAttribute('OldWidth',width)
 model.Parent=folder
 if old then old:Destroy()end
 local g=Rules.Geometry(Rules.Scale)
 print(string.format('[R156] Desert pyramid: the Classic Pyramid (%d parts, scale %.4f, %.2f wide, %.2f tall) stands on %s at (%.2f, %.2f, %.2f).',
  g.Parts,g.Scale,g.Width,g.Top,from,spot.X,spot.Y,spot.Z))
 return model
end

-- Service --------------------------------------------------------------------------------------------------------------------------------------------------
-- config, data (PlayerDataService), chests (ChestService), chase (ChaseService / ConcurrentKeeperService), notes (NotificationService), map (MapService).
-- opts (tests): Clock, NoLoop.
function M.new(config,data,chests,chase,notes,map,opts)
 opts=opts or{}
 local self=setmetatable({Config=config,Data=data,Chests=chests,Chase=chase,Notes=notes,Map=map,Opts=opts,Clock=opts.Clock or os.clock,
  Out=setmetatable({},{__mode='k'}),Last=setmetatable({},{__mode='k'}),Hooked=setmetatable({},{__mode='k'}),Connections={},
  Taken=0,Banks=0,Returns=0,Refused={}},M)
 return self
end
local function say(self,player,text,color)
 if self.Notes and player.Parent then pcall(function()self.Notes:Show(player,text,color or SAND,3)end)end
end
-- The player's state: 'Claimed' (saved), 'Out' (carrying it now) or 'Open'.
function M:Claimed(player)return Rules.Claimed(self.Data:GetPremium(player))end
function M:StateOf(player)
 if self:Claimed(player)then return Rules.State.Claimed end
 if self.Out[player]then return Rules.State.Out end
 return Rules.State.Open
end
function M:_publish(player)
 if not player or not player.Parent or not self.Data:IsLoaded(player)then return end
 local state=self:StateOf(player)
 if player:GetAttribute(Rules.Attr)~=state then player:SetAttribute(Rules.Attr,state)end
end
-- A profile has loaded: a broken saved field is dropped (never a reason to refuse a save), then the state goes out.
function M:_setup(player)
 local premium=self.Data:GetPremium(player)
 if premium[Rules.Flag]~=nil and type(premium[Rules.Flag])~='table'then premium[Rules.Flag]=nil end
 self:_publish(player)
end
function M:_hook(player)
 if self.Hooked[player]then return end
 self.Hooked[player]=player:GetAttributeChangedSignal('DataStatus'):Connect(function()
  if player:GetAttribute('DataStatus')=='Loaded'then task.defer(function()if self.Data:IsLoaded(player)then self:_setup(player)end end)end
 end)
 if self.Data:IsLoaded(player)then self:_setup(player)end
end
function M:_unhook(player)
 local c=self.Hooked[player];if c then c:Disconnect()end
 self.Hooked[player]=nil;self.Last[player]=nil
end
-- The record the carry takes: a Desert Mythic world pack (fresh each time; the carry clones it), marked with its owner's UserId.
function M:Pack(player)
 local p=Rules.Pack
 return{Kind='Pack',SeedName='Seed Pack',Stage=p.Stage,BagVariant=p.BagVariant,PackSize=PackRules.SanitizePackSize(p.PackSize),PackMutation=PackRules.MutationKey(Rules.Mutation),
  PackShape=0,Weather='None',OddsVersion=PackRules.OddsVersion,SeedScale=PackRules.NewSeedScale(p.Stage,p.BagVariant,p.PackSize), -- (PackShape 0: the default chip-bag shape for life, on the float, the carry and in the Bag; absent would make the Bag roll one)
  Body=self.Anchor,Model=self.Model,Pyramid156=player.UserId}
end
-- The biome refresh (ConcurrentKeeperService): running (Map.Refreshing / RefreshEndsAt) or due within Rules.RefreshGuard seconds. NextRefreshAt is on the chase's
-- own clock (os.clock, the same as this service's Clock). Overdue (negative) counts as near: the next heartbeat starts it.
function M:RefreshNear(now)
 local chase=self.Chase;local map=chase and chase.Map or self.Map
 if(map and map.Refreshing==true)or(chase and chase.RefreshEndsAt~=nil)then return true end
 local due=chase and chase.NextRefreshAt
 return type(due)=='number'and due-(now or self.Clock())<=Rules.RefreshGuard
end
local function refuse(self,why)self.Refused[why]=(self.Refused[why]or 0)+1;return false,why end
-- "Hold E" finished. Returns true, or false and why (every refusal leaves nothing changed).
function M:Trigger(player)
 if not player or not player.Parent or not self.Anchor then return refuse(self,'gone')end
 local now=self.Clock()
 if now-(self.Last[player]or -math.huge)<Rules.Cooldown then return refuse(self,'spam')end
 self.Last[player]=now
 if not require(script.Parent.SecurityGate).Allow(player,'Pyramid156')then return refuse(self,'rate')end
 if not self.Data:IsLoaded(player)then return refuse(self,'loading')end
 if self:Claimed(player)then self:_publish(player);return refuse(self,'claimed')end
 if self.Out[player]then return refuse(self,'out')end
 local chase=self.Chase
 if chase:IsPlayerBusy(player)or player:GetAttribute('ChestChaseSeedCarrying')then return refuse(self,'busy')end
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 if not root then return refuse(self,'nobody')end
 local inside,where=Rules.InZone(self.Zone,root.Position,Rules.Slack)
 if not inside then return refuse(self,'far:'..tostring(where))end
 if self:RefreshNear(now)then say(self,player,Rules.Text.RefreshSoon,AMBER);return refuse(self,'refresh')end -- (R157 review fix: the biomes refresh now or within Rules.RefreshGuard s)
 -- the normal steal checks; the pyramid's own reach replaced the world packs' 26 studs above, so they are asked at the player's own spot
 local c,h,r=chase:_canTake(player,root.Position)
 if not c then return refuse(self,'steal rules')end
 self.Out[player]=true;self:_publish(player)
 chase.Starting[player]=true
 local ok,err=pcall(chase._acceptSeed,chase,player,self:Pack(player),c,h,r)
 chase.Starting[player]=nil
 local run=chase.Runs[player]
 if not(run and run.Chest and run.Chest.Pyramid156==player.UserId)then
  if not ok then warn('[R156] The pyramid pack could not be taken: '..tostring(err))end
  self.Out[player]=nil;self:_publish(player);return refuse(self,'carry')
 end
 self.Taken+=1
 if chase.KeeperTargets[run.KeeperKey]==run then say(self,player,Rules.Text.Taken,GOLD)end -- (a queued carrier already hears KEEPER IS BUSY)
 return true
end
-- ChestService:Bank put the pack in the Bag (same step, no yield in between): the claim, saved soon.
function M:Banked(player,chest,record)
 if type(chest)~='table'or chest.Pyramid156==nil then return false end
 local premium=self.Data:GetPremium(player)
 local saved=premium[Rules.Flag];if type(saved)~='table'then saved={};premium[Rules.Flag]=saved end
 saved[Rules.Key]=true -- (first: nothing below can undo the claim)
 self.Out[player]=nil;self.Banks+=1
 self.Data:MarkDirty(player);pcall(function()self.Data:QueueGardenSave(player)end)
 self:_publish(player)
 say(self,player,Rules.Text.Claimed,GOLD)
 return true
end
local CAUSES={Keeper='Caught',Bat='Bat',Lightning='Lightning',Refresh='Refresh'} -- (anything else, a hole too, is 'Lost': a hole's own notice says the pack dropped; this one says where it went)
-- The carry ended without a bank (the chase hooks below). cause: 'Keeper' / 'Bat' / 'Lightning' / 'Hole' (caught) or nil (lost; 'Refresh' when RefreshReturns ended it:
-- Finish calls _returnPackToOrigin(chest) with no cause, so that one rides on the record).
function M:Returned(chest,cause)
 if type(chest)~='table'or chest.Pyramid156==nil then return false end
 cause=cause or chest.Pyramid156End
 local player=Players:GetPlayerByUserId(chest.Pyramid156)
 self.Returns+=1
 if player then
  self.Out[player]=nil;self:_publish(player)
  say(self,player,Rules.Text[CAUSES[cause]or'Lost'],AMBER)
 end
 return true
end
-- A biome refresh is about to start (the hook below calls this BEFORE ConcurrentKeeperService:_beginBiomeRefresh). That code banks every carrier it finds (Finish(true) in
-- _evacuateBiomePlayers for a player in the biome track, and again in its stale-runs loop for any run with a valid character), and its time is public. So every secret carry
-- is ended here, first, with Finish(false,false,run): not banked (no Bag, no claim), not caught (no fling, nothing dropped on the track). Finish then does exactly what it does
-- for a fall or leaving: the keeper lease, the queue slot, the carrying / queued attributes, the speed, the held pack and the keeper's alert are all cleaned, and it calls
-- _returnPackToOrigin(run.Chest), which the hook below sends to Returned (the pack is back in the pyramid, the 'Refresh' notice). Returns how many went back.
function M:RefreshReturns()
 local chase=self.Chase;local ended={}
 for _,run in pairs(chase.Runs or{})do
  if type(run)=='table'and type(run.Chest)=='table'and run.Chest.Pyramid156~=nil then ended[#ended+1]=run end
 end
 for _,run in ipairs(ended)do
  run.Chest.Pyramid156End='Refresh'
  local ok,err=pcall(chase.Finish,chase,false,false,run)
  if not ok then warn('[R157] A pyramid pack could not be sent back before the refresh: '..tostring(err))end
  if chase.Runs[run.Player]==run then run.Chest.Pyramid156End=nil end -- (Finish refused: the refresh code will meet this run as it always did)
 end
 return #ended
end
-- The chase hooks: wrappers on the chase service object (once per object; the class, ConcurrentKeeperService, is not changed). A secret pack has no world slot
-- and never drops on the track. Caught (snake / bat / lightning / hole): the hit lands with the same fling code as a normal catch, then the pack goes back into
-- the pyramid for its player. Any other end without a bank (a fall, a death, leaving, a failed bank): back too ('lost'). Other packs: the normal code.
-- A biome refresh (R157 review fix): RefreshReturns sends every secret carry back first, so the refresh never banks one.
function M.HookChase(chase)
 if type(chase)~='table'or rawget(chase,'Pyramid156Hooks')then return false end
 local drop,back,refresh=chase._dropChestAfterCatch,chase._returnPackToOrigin,chase._beginBiomeRefresh
 assert(type(drop)=='function'and type(back)=='function'and type(refresh)=='function','[R156] the chase service has no catch / return / refresh code to hook')
 chase.Pyramid156Hooks=true
 chase._beginBiomeRefresh=function(self,now)
  if self.Pyramid156 then
   local ok,err=pcall(self.Pyramid156.RefreshReturns,self.Pyramid156)
   if not ok then warn('[R157] The pyramid packs could not be sent back before the refresh: '..tostring(err))end
  end
  return refresh(self,now)
 end
 chase._returnPackToOrigin=function(self,chest,cause)
  if type(chest)=='table'and chest.Pyramid156~=nil then return self.Pyramid156~=nil and self.Pyramid156:Returned(chest,cause)==true end
  return back(self,chest,cause)
 end
 chase._dropChestAfterCatch=function(self,run,hit)
  if not(run and type(run.Chest)=='table'and run.Chest.Pyramid156~=nil)then return drop(self,run,hit)end
  if hit and hit.ImpactApplied then -- (a bat hit already landed)
  elseif hit and hit.Cause=='Lightning'then self:_applyLightningFling(run.Player,hit.Center,run.Character)
  else self:_applyGuardianFling(run)end
  self:_returnPackToOrigin(run.Chest,hit and hit.Cause or'Keeper')
 end
 return true
end
-- Every 2 s: profiles that loaded without a signal, and an 'Out' that no carry backs any more (a safety net: the hooks above clear it).
function M:Step()
 for _,player in ipairs(Players:GetPlayers())do
  if self.Data:IsLoaded(player)then
   if self.Out[player]then
    local run=self.Chase.Runs and self.Chase.Runs[player]
    if not(run and run.Chest and run.Chest.Pyramid156~=nil)and not(self.Chase.Starting and self.Chase.Starting[player])then self.Out[player]=nil end
   end
   if player:GetAttribute(Rules.Attr)==nil then self:_setup(player)else self:_publish(player)end
  end
 end
end
function M:Start()
 if self.Started then return self end
 local root=assert(self.Map and self.Map.MapRoot,'[R156] the map is missing')
 local folder=root:FindFirstChild('MythicLandmarks')
 local model=folder and folder:FindFirstChild(Rules.ModelName)
 if not model or model:GetAttribute('PyramidVersion')~=Rules.Version then model=M.Apply(root)end -- (the map pass did not run: build it now)
 self.Model=model;self.Anchor=assert(model:FindFirstChild(Rules.AnchorName),'[R156] the pack anchor is missing')
 self.Zone=assert(Rules.ReadZone(self.Anchor),'[R156] the pyramid zone is missing')
 local prompt=self.Anchor:FindFirstChild('Steal')or Instance.new('ProximityPrompt')
 prompt.Name='Steal';prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.HoldDuration=self.Config.StealHoldSeconds or 1 -- R125: hold E, as on a world pack
 prompt.ActionText='STEAL';prompt.ObjectText='';prompt.MaxActivationDistance=self.Zone.Reach;prompt.RequiresLineOfSight=false
 prompt.Enabled=true;prompt.Parent=self.Anchor -- (each client turns it off for itself: claimed, carrying, or not next to the pyramid)
 self.Prompt=prompt
 table.insert(self.Connections,prompt.Triggered:Connect(function(player)self:Trigger(player)end))
 self.Chase.Pyramid156=self;self.Chests.Pyramid156=self;M.HookChase(self.Chase)
 for _,player in ipairs(Players:GetPlayers())do self:_hook(player)end
 table.insert(self.Connections,Players.PlayerAdded:Connect(function(player)self:_hook(player)end))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(player)self:_unhook(player)end))
 self.Started=true;M.Current=self
 if not self.Opts.NoLoop then
  task.spawn(function()
   while self.Started do
    task.wait(2)
    if not self.Started then break end
    local ok,err=pcall(self.Step,self);if not ok then warn('[R156] Secret pyramid step: '..tostring(err))end
   end
  end)
 end
 return self
end
function M:Destroy()
 self.Started=false
 for _,c in ipairs(self.Connections)do c:Disconnect()end;self.Connections={}
 local hooked={};for player in pairs(self.Hooked)do hooked[#hooked+1]=player end;for _,player in ipairs(hooked)do self:_unhook(player)end
 if self.Chase and self.Chase.Pyramid156==self then self.Chase.Pyramid156=nil end
 if self.Chests and self.Chests.Pyramid156==self then self.Chests.Pyramid156=nil end
 if M.Current==self then M.Current=nil end
end

-- Owner tools ----------------------------------------------------------------------------------------------------------------------------------------------
function M:StatusText(player)
 local g=Rules.Geometry(Rules.Scale);local z=self.Zone;local state=self:StateOf(player)
 local mine=state==Rules.State.Claimed and'has the secret pack (saved). The pack is gone from the pyramid for them.'
  or state==Rules.State.Out and'is carrying the secret pack right now.'
  or'does not have the secret pack yet. It is in the pyramid for them.'
 return table.concat({
  '@'..player.Name..' '..mine..' (attribute: '..tostring(player:GetAttribute(Rules.Attr))..')',
  string.format('The pack: the Desert Mythic pack (%s), size %s, coat %s, odds version %s.',Rules.Pack.BagVariant,tostring(Rules.Pack.PackSize),PackRules.MutationKey(Rules.Mutation),tostring(PackRules.OddsVersion)),
  string.format('The pyramid: %.2f wide, %.2f tall (scale %.4f), %d parts, base centre (%.2f, %.2f, %.2f). Hold E reaches %.1f studs from the pack.',g.Width,g.Top,g.Scale,g.Parts,z.Center.X,z.Center.Y,z.Center.Z,z.Reach),
  string.format('This server: %d taken, %d banked, %d went back.',self.Taken,self.Banks,self.Returns),
  'Use pyramid @username reset to let them get it again.',
 },'\n')
end
function M:Reset(player)
 local premium=self.Data:GetPremium(player)
 local saved=premium[Rules.Flag];local had=Rules.Claimed(premium)
 if type(saved)=='table'then saved[Rules.Key]=nil;if next(saved)==nil then premium[Rules.Flag]=nil end elseif saved~=nil then premium[Rules.Flag]=nil end
 self.Data:MarkDirty(player);pcall(function()self.Data:QueueGardenSave(player)end)
 self:_publish(player)
 return true,had and('@'..player.Name..' can get the secret pyramid pack again. The packs they already have stay in their Bag.')
  or('@'..player.Name..' did not have the secret pack. Nothing to reset.')
end
-- OwnerUpdateCommands82 -> here (`pyramid`): the service running in this server.
function M.Command(_,player,a)
 local self=M.Current
 if not self then return false,'The secret pyramid is not running in this server.'end
 local sub=a and a[1]and tostring(a[1]):lower()
 if sub==nil or sub=='status'then return true,self:StatusText(player)end
 if sub=='reset'and #a==1 then return self:Reset(player)end
 return false,'Use pyramid @username, or pyramid @username reset.'
end
return M
