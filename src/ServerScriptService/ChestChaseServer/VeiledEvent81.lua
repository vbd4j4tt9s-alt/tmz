-- R122: The Veiled One guards TWO Void Packs (the "secret / cosmic pack", variant EclipseReliquary).
-- Lifetime rules (server-authoritative; ConcurrentKeeperService calls these hooks):
--  * Start: only at the end of a scheduled refresh (PackSchedule81.Event) while no event is active,
--    or by an owner/Studio command. While active, no second keeper or event can spawn.
--  * Track refreshes never despawn the keeper or its packs. A refresh ends every chase (the existing
--    rules bank an evacuated carrier and return dropped/abandoned packs to their slot), then
--    AfterRefresh reopens the remaining slots.
--  * A pack counts as STOLEN only when it is banked: ConcurrentKeeperService:Finish -> Chests:Bank
--    succeeded -> Captured(chest). That is how a steal is counted today (pickup alone, a drop, a death
--    or leaving mid-carry all return the pack to its slot). The keeper keeps guarding while at least
--    one pack is left and despawns right after the LAST pack is banked.
--  * Three completed refreshes in a row with no steal reroll every remaining pack in place to a
--    different variation (pack size / coat; the tier stays Void). The keeper stays. The counter resets
--    after a reroll and whenever a pack is stolen.
--  * Never lost / never duplicated: a slot is reopened only when no carried or dropped copy of it
--    exists, and a slot whose copy vanished without banking is restored after the next refresh, so the
--    keeper can never be left guarding nothing. A server restart starts with no event (not persisted),
--    exactly like before; banked packs live in player data.
local RS=game:GetService('ReplicatedStorage')
local Art=require(RS.VeiledKeeper81)
local Balance=require(RS.RouteBalance83)
local PackRules=require(RS.SeedPackRules)
local E={};E.__index=E
E.PackCount=2
E.RerollAfterRefreshes=3
E.SlotOffsets={-7,7}  -- studs across the track from the old single pack position
E.VariationTries=24
function E.new(chase)
 local remotes=RS:WaitForChild('ChestChaseRemotes')
 local remote=remotes:FindFirstChild('VeiledArrival81')or Instance.new('RemoteEvent')
 remote.Name='VeiledArrival81';remote.Parent=remotes
 local self=setmetatable({Chase=chase,Remote=remote,Slots={},Unstolen=0,StolenSinceRefresh=false,RerollSerial=0},E)
 chase.Map.MapRoot:SetAttribute('VeiledEventActive',false)
 return self
end
function E:Active()return self.Folder~=nil and self.Folder.Parent~=nil end
-- Slots that still hold (or will get back) a pack; stolen slots are removed from the list.
function E:LiveSlots()
 local out={};for _,slot in ipairs(self.Slots)do if not slot.Stolen then table.insert(out,slot)end end;return out
end
function E:_publish()
 local map=self.Chase.Map.MapRoot;local live=self:LiveSlots()
 -- Back-compat alias for owner commands (eventpack / go): the first pack that is still guarded.
 self.Seed=live[1]
 map:SetAttribute('VeiledPacksLeft',self:Active()and #live or 0)
 map:SetAttribute('VeiledUnstolenRefreshes',self:Active()and self.Unstolen or 0)
end
function E:EnsureGuardian()
 if not self.Home or not self.Folder or not self.Folder.Parent then return nil end
 if not self.Guardian or not self.Guardian.Parent then self.Guardian=Art.Build(self.Home,self.Folder)end
 return self.Guardian
end
function E:_dropSlot(slot)
 if slot.Connection then slot.Connection:Disconnect();slot.Connection=nil end
 self.Chase.KnownSeeds[slot]=nil
 if slot.Model and slot.Model.Parent then slot.Model:Destroy()end
end
function E:Clear()
 local chase=self.Chase
 local runs={};for _,run in pairs(chase.Runs)do if run.Chest.EventKeeper then table.insert(runs,run)end end
 for _,run in ipairs(runs)do chase:Finish(false,false,run)end
 for _,slot in ipairs(self.Slots)do self:_dropSlot(slot)end
 if self.Folder then self.Folder:Destroy()end
 self.Slots={};self.Folder=nil;self.Guardian=nil;self.Seed=nil;self.Returning=false
 self.Unstolen=0;self.StolenSinceRefresh=false
 chase.KeeperTargets.Veiled=nil;chase.KeeperQueues.Veiled=nil
 chase.Map.MapRoot:SetAttribute('VeiledEventActive',false)
 self:_publish()
end
local function slotOf(self,chest)
 local origin=chest and chest.OriginSlot
 for _,slot in ipairs(self.Slots)do if slot==origin then return slot end end
 return nil
end
-- Called once per banked event pack (the only thing that counts as a steal).
function E:Captured(chest)
 local slot=slotOf(self,chest)
 if not slot or slot.Stolen then return false end
 slot.Stolen=true;self:_dropSlot(slot)
 self.Unstolen=0;self.StolenSinceRefresh=true
 if #self:LiveSlots()==0 then
  -- Last pack gone: the Veiled One leaves.
  self:Clear();self.Chase.Map.MapRoot:SetAttribute('VeiledEventClaimed',true)
 else self:_publish()end
 return true
end
-- Is a copy of this slot's pack currently carried or lying dropped on the track?
function E:Outstanding(slot)
 local chase=self.Chase
 for _,run in pairs(chase.Runs)do if run.Chest and run.Chest.OriginSlot==slot and not run.Finishing then return true end end
 for _,drop in pairs(chase.Drops)do if drop.Chest and drop.Chest.OriginSlot==slot and not drop.Claimed then return true end end
 return false
end
function E:_makeSlot(index,cycle,ground,floorY,endZ)
 local chase=self.Chase
 local model=Instance.new('Model');model.Name='EclipseReliquarySlot'..index;model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 model:SetAttribute('VeiledSlot',index)
 local body=Instance.new('Part');body.Name='Body';body.Size=Vector3.new(.3,.3,.3);body.Anchored=true;body.Transparency=1
 body.CanCollide=false;body.CanQuery=false;body.CanTouch=false
 body.CFrame=CFrame.new(ground.Position.X+(E.SlotOffsets[index]or 0),floorY+5,endZ-48);body.Parent=model;model.PrimaryPart=body
 local prompt=Instance.new('ProximityPrompt');prompt.Name='Steal';prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.HoldDuration=0
 prompt.MaxActivationDistance=24;prompt.RequiresLineOfSight=false;prompt.ActionText='STEAL';prompt.ObjectText='Void Pack';prompt.Parent=body
 local billboard=Instance.new('BillboardGui');billboard.Enabled=false;billboard.Parent=body
 local glow=Instance.new('PointLight');glow.Enabled=false;glow.Parent=body
 model.Parent=self.Folder
 local seed={Model=model,Body=body,Prompt=prompt,Billboard=billboard,Glow=glow,Stage=7,EventKeeper=true,SlotIndex=index,
  Kind='Pack',SeedName='Void Pack',Available=false,Generation=cycle,PartState={},PackHome=body.Position,OddsVersion=PackRules.OddsVersion}
 chase.KnownSeeds[seed]=true
 chase.Chests:RefreshWorldPack(seed,'EclipseReliquary')
 seed.Connection=prompt.Triggered:Connect(function(player)chase:Begin(player,seed)end)
 return seed
end
-- force=true: owner command / Studio test (replaces the current event, ignores the schedule).
function E:Spawn(cycle,force)
 if self:Active()and not force then return false end
 if not force and not require(RS.PackSchedule81).Event(cycle)then return false end
 self:Clear()
 local chase=self.Chase;local ground=chase.Chests:_packGround(7)
 if not ground then warn('[R81] Storm event ground is missing');return false end
 local endZ=chase.Map.MapRoot:GetAttribute('BiomeTrackEndZ')or(ground.Position.Z+ground.Size.Z*.5)
 local floorY=ground.Position.Y+ground.Size.Y*.5
 self.Home=CFrame.new(ground.Position.X,floorY+5,endZ-22)
 local folder=Instance.new('Folder');folder.Name='VeiledEvent81';folder.Parent=chase.Map.RuntimeFolder;self.Folder=folder
 self.Ground,self.FloorY,self.EndZ=ground,floorY,endZ
 self:EnsureGuardian()
 for index=1,E.PackCount do self.Slots[index]=self:_makeSlot(index,cycle,ground,floorY,endZ)end
 self.Unstolen=0;self.StolenSinceRefresh=false
 local map=chase.Map.MapRoot;map:SetAttribute('VeiledEventActive',true);map:SetAttribute('VeiledEventCycle',cycle)
 self.Serial=(self.Serial or 0)+1
 local at=workspace:GetServerTimeNow()
 map:SetAttribute('VeiledArrivalSerial83',self.Serial);map:SetAttribute('VeiledArrivalAt',at);map:SetAttribute('VeiledEventClaimed',false)
 self:_publish()
 -- Clients play the arrival sound + one-second lights-out only for a fresh server timestamp.
 self.Remote:FireAllClients(cycle,self.Serial,at)
 return true
end
-- Hide / show the event packs together with the regular packs while the track is closed.
function E:RefreshVisibility()
 for _,slot in ipairs(self:LiveSlots())do
  if slot.Model and slot.Model.Parent then self.Chase.Chests:SetWorldPackAvailable(slot,slot.Available)end
 end
end
local function variationKey(slot)
 return tostring(PackRules.SanitizePackSize(slot.PackSize))..'|'..PackRules.MutationKey(slot.PackMutation)
end
function E.VariationKey(slot)return variationKey(slot)end
-- Pick a size/coat roll that differs from the current one (natural odds; forced fallback).
function E:_rollVariation(slot)
 local random=self.Chase.Chests.PackRandom or Random.new()
 local old=variationKey(slot)
 for _=1,E.VariationTries do
  local size=PackRules.RollPackSize(random:NextNumber());local coat=PackRules.RollMutation(random:NextNumber())
  if tostring(PackRules.SanitizePackSize(size))..'|'..coat~=old then return size,coat end
 end
 local size=PackRules.SanitizePackSize(slot.PackSize)
 return size==1 and 1.5 or 1,PackRules.MutationKey(slot.PackMutation)
end
function E:Reroll()
 local changed=0
 for _,slot in ipairs(self:LiveSlots())do
  if slot.Available and not self:Outstanding(slot)and slot.Model.Parent then
   local size,coat=self:_rollVariation(slot)
   self.Chase.Chests:RefreshWorldPack(slot,'EclipseReliquary',size,coat)
   changed+=1
  end
 end
 self.RerollSerial+=1
 self.Chase.Map.MapRoot:SetAttribute('VeiledRerollSerial',self.RerollSerial)
 return changed
end
-- Called by ConcurrentKeeperService after every completed track refresh (replaces the old Spawn call).
function E:AfterRefresh(cycle)
 if not self:Active()then return self:Spawn(cycle)end
 local chase=self.Chase
 for index,slot in ipairs(self.Slots)do
  if not slot.Stolen and not self:Outstanding(slot)then
   if not slot.Model or not slot.Model.Parent then
    self:_dropSlot(slot);self.Slots[index]=self:_makeSlot(index,cycle,self.Ground,self.FloorY,self.EndZ)
   elseif not slot.Available then
    -- Its copy vanished without being banked: restore it (never leave the keeper guarding nothing).
    chase.Chests:SetWorldPackAvailable(slot,true)
   end
  end
 end
 if #self:LiveSlots()==0 then self:Clear();return false end
 if self.StolenSinceRefresh then self.Unstolen=0 else self.Unstolen+=1 end
 self.StolenSinceRefresh=false
 if self.Unstolen>=E.RerollAfterRefreshes then self:Reroll();self.Unstolen=0 end
 self:RefreshVisibility()
 -- Back on guard at home for the reopened track (only when nobody is being chased).
 local keeper=self:EnsureGuardian()
 if keeper and keeper.PrimaryPart and not chase.KeeperTargets.Veiled then
  self.Returning=false;keeper.PrimaryPart.CFrame=self.Home
  keeper:SetAttribute('TargetUserId',0);keeper:SetAttribute('ActiveGuardianChaser',false)
  keeper:SetAttribute('GuardianBehavior','GUARDING');keeper:SetAttribute('KeeperTravelSpeed',0);keeper:SetAttribute('VeiledAwakeAt',nil)
  Art.Apply(keeper,workspace:GetServerTimeNow())
 end
 self:_publish()
 return false
end
function E:Return(keeper)
 if keeper and keeper.Parent then
  self.Returning=true;keeper:SetAttribute('TargetUserId',0);keeper:SetAttribute('ActiveGuardianChaser',false)
  keeper:SetAttribute('GuardianBehavior','RETURNING');keeper:SetAttribute('KeeperTravelSpeed',Balance.EventReturnSpeed)
 end
end
function E:Step(dt)
 local keeper=self.Guardian
 if not self.Returning or not keeper or not keeper.Parent or not self.Home then return end
 local root=keeper.PrimaryPart;local delta=self.Home.Position-root.Position
 if delta.Magnitude<=math.max(1,Balance.EventReturnSpeed*math.min(dt,.1))then
  root.CFrame=self.Home;self.Returning=false;keeper:SetAttribute('GuardianBehavior','GUARDING')
  keeper:SetAttribute('KeeperTravelSpeed',0);keeper:SetAttribute('VeiledAwakeAt',nil);Art.Apply(keeper,workspace:GetServerTimeNow())
 else root.CFrame=CFrame.lookAt(root.Position+delta.Unit*Balance.EventReturnSpeed*math.min(dt,.1),self.Home.Position)end
end
return E
