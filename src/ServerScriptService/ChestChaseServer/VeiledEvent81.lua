local RS=game:GetService('ReplicatedStorage')
local Art=require(RS.VeiledKeeper81)
local Balance=require(RS.RouteBalance83)
local E={};E.__index=E
function E.new(chase)
 local remotes=RS:WaitForChild('ChestChaseRemotes')
 local remote=remotes:FindFirstChild('VeiledArrival81')or Instance.new('RemoteEvent')
 remote.Name='VeiledArrival81';remote.Parent=remotes
 local self=setmetatable({Chase=chase,Remote=remote},E)
 chase.Map.MapRoot:SetAttribute('VeiledEventActive',false)
 return self
end
function E:EnsureGuardian()
 if not self.Home or not self.Folder or not self.Folder.Parent then return nil end
 if not self.Guardian or not self.Guardian.Parent then self.Guardian=Art.Build(self.Home,self.Folder)end
 return self.Guardian
end
function E:Clear()
 local chase=self.Chase
 local runs={};for _,run in pairs(chase.Runs)do if run.Chest.EventKeeper then table.insert(runs,run)end end
 for _,run in ipairs(runs)do chase:Finish(false,false,run)end
 if self.Connection then self.Connection:Disconnect();self.Connection=nil end
 if self.Seed then chase.KnownSeeds[self.Seed]=nil end
 if self.Folder then self.Folder:Destroy()end
 self.Folder=nil;self.Guardian=nil;self.Seed=nil;self.Returning=false
 chase.KeeperTargets.Veiled=nil;chase.KeeperQueues.Veiled=nil
 chase.Map.MapRoot:SetAttribute('VeiledEventActive',false)
end
function E:Captured(chest)
 if not self.Seed or chest.OriginSlot~=self.Seed then return false end
 self:Clear();self.Chase.Map.MapRoot:SetAttribute('VeiledEventClaimed',true)
 return true
end
function E:Spawn(cycle)
 self:Clear()
 if not require(RS.PackSchedule81).Event(cycle)then return end
 local chase=self.Chase;local ground=chase.Chests:_packGround(7)
 if not ground then warn('[R81] Storm event ground is missing');return end
 local endZ=chase.Map.MapRoot:GetAttribute('BiomeTrackEndZ')or(ground.Position.Z+ground.Size.Z*.5)
 local floorY=ground.Position.Y+ground.Size.Y*.5
 self.Home=CFrame.new(ground.Position.X,floorY+5,endZ-22)
 local folder=Instance.new('Folder');folder.Name='VeiledEvent81';folder.Parent=chase.Map.RuntimeFolder;self.Folder=folder
 self:EnsureGuardian()
 local model=Instance.new('Model');model.Name='EclipseReliquarySlot';model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 local body=Instance.new('Part');body.Name='Body';body.Size=Vector3.new(.3,.3,.3);body.Anchored=true;body.Transparency=1
 body.CanCollide=false;body.CanQuery=false;body.CanTouch=false;body.CFrame=CFrame.new(ground.Position.X,floorY+5,endZ-48);body.Parent=model;model.PrimaryPart=body
 local prompt=Instance.new('ProximityPrompt');prompt.Name='Steal';prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.HoldDuration=0
 prompt.MaxActivationDistance=24;prompt.RequiresLineOfSight=false;prompt.ActionText='STEAL';prompt.ObjectText='Void Pack';prompt.Parent=body
 local billboard=Instance.new('BillboardGui');billboard.Enabled=false;billboard.Parent=body
 local glow=Instance.new('PointLight');glow.Enabled=false;glow.Parent=body
 model.Parent=folder
 local seed={Model=model,Body=body,Prompt=prompt,Billboard=billboard,Glow=glow,Stage=7,EventKeeper=true,
  Kind='Pack',SeedName='Void Pack',Available=false,Generation=cycle,PartState={},PackHome=body.Position,OddsVersion=81}
 self.Seed=seed;chase.KnownSeeds[seed]=true
 chase.Chests:RefreshWorldPack(seed,'EclipseReliquary')
 self.Connection=prompt.Triggered:Connect(function(player)chase:Begin(player,seed)end)
 local map=chase.Map.MapRoot;map:SetAttribute('VeiledEventActive',true);map:SetAttribute('VeiledEventCycle',cycle)
 self.Serial=(self.Serial or 0)+1
 map:SetAttribute('VeiledArrivalSerial83',self.Serial);map:SetAttribute('VeiledEventClaimed',false)
 self.Remote:FireAllClients(cycle,self.Serial)
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
