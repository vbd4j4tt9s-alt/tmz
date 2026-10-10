-- R43. The client requests a swing; the server chooses and validates its victim.
-- R158 (docs/proposals/R158/bats/hitbox.md, owner-approved: "improve hitbox consistency especially with fast moving players"): the swing starts on the
-- swinger's screen at the click and the request carries its start time; the swinger's client sweeps the strike on what its screen shows and claims the
-- first victim it saw. The server keeps every player's position ~1 s back (BatLagComp ring buffers, filled in Step) and re-checks each claim:
-- once per swing, rate limited (SecurityGate 'BatHit'), the moment inside the strike and fresh, the swinger where its own server path was, the victim
-- where it was when the swinger's screen showed it (rewound, capped), in reach, in front, no wall. Then today's HitByBat, unchanged (knockback, stun,
-- a carried pack drops or the secret pack goes back, the effects packet). Who can hit / be hit (_eligible, Ragdoll:CanHit) and the cooldown are as before.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local C=require(RS:WaitForChild('BatConfig'))
local Hitbox=require(RS:WaitForChild('BatHitbox'))
local Art=require(script.Parent.BatArt)
local Lag=require(script.Parent.BatLagComp)
local M={};M.__index=M
function M.new(chase)
 return setmetatable({Chase=chase,Tools={},Characters={},Connections={},Swings={},NextSwing={},NextRequest={},LastStart={},StartHeld={},StartEarly={},SpawnAt={},Serial=0,
  History={},LastRecord=-math.huge,Counts={},Check={}},M)
end
-- R158 review: the swinger's lag as the SERVER measures it (Player:GetNetworkPing; 0 when it is missing or fails), never under PingFloor, + PingSlack,
-- at most StartBack. Everything the client says about time is held to it (the swing's start, a claim's travel time, how far back the victim is looked up).
local function networkPing(player)return player:GetNetworkPing()end
function M.LagOf(player)
 local ok,ping=pcall(networkPing,player)
 if not ok or type(ping)~='number'or ping~=ping or ping<0 then ping=0 end
 return math.min(C.StartBack,math.max(C.PingFloor,ping)+C.PingSlack)
end
-- the walk speed the server gave this player (its humanoid's WalkSpeed on the server, set from the earned speed points; PhysicalWalkSpeed is the same
-- earned speed before a zone slows it): a client cannot raise either. How far a swinger can get from where the server had it at the request: today's rule.
local function walkSpeed(player,hum)return math.max(hum and hum.WalkSpeed or 0,tonumber(player:GetAttribute('PhysicalWalkSpeed'))or 0)end
local function maxDrift(speed)return math.max(18,speed*C.Windup*1.8)end
function M:_eligible(player,swingOnly)
 local character,hum,root=self.Chase:_validCharacter(player)
 if not character or root.Anchored or hum.PlatformStand or self.Chase.Map.Refreshing
  or player:GetAttribute('GuardianRagdollActive')or player:GetAttribute('GuardianFlingActive')then return nil end
 if not swingOnly then
  if character:FindFirstChildOfClass('ForceField')or os.clock()-(self.SpawnAt[player]or os.clock())<C.SpawnGrace then return nil end
  if C.RequireBiome and (not self.Chase.Map:IsInsideBiomeTrack(root.Position)
   or root.Position.Z<=self.Chase.Map.BaseBoundaryLine.Position.Z+C.SafeLineMargin)then return nil end
 end
 return character,hum,root
end
-- payload = {Kind='Swing', Start = the click's server time (workspace:GetServerTimeNow() on the swinger's client), Id = the client's swing number}
function M:Request(player,payload)
 if not require(script.Parent.SecurityGate).Allow(player,'BatSwing',payload)or not require(script.Parent.MovementGuard).Check(player)then return false end
 local now=os.clock()
 if now<(self.NextRequest[player]or 0)then return false end
 self.NextRequest[player]=now+.08
 if now<(self.NextSwing[player]or 0)-C.CooldownSlack then return false end
 local character,_,root=self:_eligible(player,true);local tool=self.Tools[player]
 if not character or not tool or tool.Parent~=character or not tool.Enabled
  or self.Chase.Chests:IsOpening(player)then return false end
 -- R158: the swing starts when the swinger clicked (its own clock, synced to the server's), never earlier than its measured lag before it arrived
 -- (R158 review: it was StartBack, .5 s, for everyone) nor in the future; the cooldown counts between those starts (the swinger's clicks), so network
 -- jitter cannot eat a swing it was allowed. When the server had to hold a start to that window (this one or the last: a client clock a little off),
 -- a start may come early by up to CooldownSlack IN ALL (StartEarly keeps the sum, a later start pays it back), so swings still average one per Cooldown.
 local server=workspace:GetServerTimeNow()
 local asked=type(payload)=='table'and payload.Start
 if type(asked)~='number'or asked~=asked then asked=server end
 local start=math.clamp(asked,server-M.LagOf(player),server+C.StartAhead)
 local held=math.abs(start-asked)>1e-3
 local early=(self.LastStart[player]or-math.huge)+C.Cooldown-start;local owed=self.StartEarly[player]or 0
 if early>1e-3 and not((held or self.StartHeld[player])and owed+early<=C.CooldownSlack)then return false end
 local id=type(payload)=='table'and payload.Id
 if type(id)~='number'or id~=id then id=nil end
 self.NextSwing[player]=now+C.Cooldown;self.LastStart[player]=start;self.StartHeld[player]=held;self.StartEarly[player]=math.max(0,owed+early);self.Serial+=1
 local swing={Character=character,Tool=tool,At=start,Start=start,Id=id,Serial=self.Serial,Origin=root.Position,
  Expires=start+C.HitTo+C.StrikeSlack+C.MaxClaimDelay,Resolved=false}
 self.Swings[player]=swing
 self.Remote:FireAllClients({Kind='Swing',Character=character,At=start,Serial=swing.Serial,Id=id})
 return true
end
-- the wall test of a claim: today's ray filter (both characters excluded, RespectCanCollide); one RaycastParams for every claim
local params,filter
local function blocked(c,ax,ay,az,bx,by,bz)
 if not params then params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.RespectCanCollide=true;filter={}end
 filter[1]=c.SwingerCharacter;filter[2]=c.VictimCharacter;params.FilterDescendantsInstances=filter
 return workspace:Raycast(Vector3.new(ax,ay,az),Vector3.new(bx-ax,by-ay,bz-az),params)~=nil
end
-- every answer to a claim is counted by its reason; live, the counts are attributes of the BatSwing remote (Claims_hit, Claims_out_of_reach, ...):
-- a tolerance that is wrong for honest players shows up as one reason growing
function M:_count(reason)
 local n=(self.Counts[reason]or 0)+1;self.Counts[reason]=n
 if self.Remote then self.Remote:SetAttribute('Claims_'..(reason:gsub('[^%w]+','_')),n)end
 return reason=='hit',reason
end
-- payload = {Kind='Hit', Id (the swing), Victim (a Player), ViewTime (the server time the swinger's screen showed the hit), Own (the swinger's root
-- position at that moment), Look (its flat facing)}. Returns ok, reason (every refusal is counted by reason in self.Counts).
function M:Claim(player,payload)
 if not require(script.Parent.SecurityGate).Allow(player,'BatHit',payload)then return self:_count('refused by SecurityGate')end
 if not require(script.Parent.MovementGuard).Check(player)then return self:_count('movement')end
 local swing=self.Swings[player]
 if type(payload)~='table'or not swing or swing.Id==nil or payload.Id~=swing.Id then return self:_count('no such swing')end
 local resolved=swing.Resolved;swing.Resolved=true -- one claim per swing, whatever it says
 local victim=payload.Victim
 if typeof(victim)~='Instance'or not victim:IsA('Player')or victim==player or victim.Parent~=Players then return self:_count(resolved and'one claim per swing'or'bad victim')end
 local own,look=payload.Own,payload.Look
 if typeof(own)~='Vector3'or typeof(look)~='Vector3'then return self:_count(resolved and'one claim per swing'or'bad numbers')end
 local c=self.Check
 c.Start=swing.Start;c.Resolved=resolved;c.ViewTime=payload.ViewTime
 c.OwnX,c.OwnY,c.OwnZ,c.LookX,c.LookZ=own.X,own.Y,own.Z,look.X,look.Z
 -- R158 review: the lag the server measures, where it had the swinger at the request and how far its earned walk speed carries it in a swing
 local speed=walkSpeed(player,swing.Character:FindFirstChildOfClass('Humanoid'));local origin=swing.Origin
 c.Lag=M.LagOf(player);c.WalkSpeed=speed;c.MaxDrift=maxDrift(speed);c.OriginX,c.OriginY,c.OriginZ=origin.X,origin.Y,origin.Z
 c.Swinger=self.History[player];c.Victim=self.History[victim];c.SwingerCharacter=swing.Character;c.VictimCharacter=victim.Character
 local ok,why=Lag.Validate(c,workspace:GetServerTimeNow(),blocked)
 c.SwingerCharacter=nil;c.VictimCharacter=nil;c.Swinger=nil;c.Victim=nil
 if not ok then return self:_count(why)end
 -- today's rules, now: both may hit / be hit here (the track, past the base line, no ForceField / spawn grace, not knocked down)
 local character=self:_eligible(victim)
 if not self:_eligible(player)or not character or not self.Chase.Ragdoll:CanHit(victim)then return self:_count('cannot be hit')end
 self.Swings[player]=nil
 if not self.Chase:HitByBat(player,victim,character)then return self:_count('cannot be hit')end
 return self:_count('hit')
end
-- R158: everyone's root and flat facing, HistoryHz times a second, into reused ring buffers (one per player, made once)
function M:_record(server)
 if server-self.LastRecord<1/C.HistoryHz-.004 then return end
 self.LastRecord=server
 for player in pairs(self.Characters)do
  local h=self.History[player]
  if not h then h=Lag.History();self.History[player]=h end
  local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
  if root then
   if character~=h.Character then h.Character=character;Lag.Break(h)end
   local frame=root.CFrame;local p=frame.Position;local look=frame.LookVector
   local lx,lz=Hitbox.Flat(look.X,look.Z)
   if not lx then lx,lz=h.LX[h.Head]or 0,h.LZ[h.Head]or 1 end
   Lag.Record(h,server,p.X,p.Y,p.Z,lx,lz,true)
  end
 end
end
function M:Step()
 local server=workspace:GetServerTimeNow()
 self:_record(server)
 for player,swing in pairs(self.Swings)do
  local character,hum,root=self:_eligible(player,true)
  if character~=swing.Character or self.Tools[player]~=swing.Tool or swing.Tool.Parent~=character
   or not swing.Tool.Enabled or not root or server>swing.Expires
   or server<=swing.Start+C.HitTo+C.StrikeSlack and (root.Position-swing.Origin).Magnitude>maxDrift(walkSpeed(player,hum))then
   self.Swings[player]=nil -- (no claim by Expires: a miss)
  end
 end
end
function M:Give(player,character)
 if not character or not player.Parent or player.Character~=character then return end
 self.Swings[player]=nil;self.SpawnAt[player]=os.clock()
 local old=self.Tools[player];if old then old:Destroy()end;self.Tools[player]=nil
 local backpack=player:FindFirstChildOfClass('Backpack')or player:WaitForChild('Backpack',10)
 if not backpack or not player.Parent or player.Character~=character then return end
 local tool=Art.Create();self.Tools[player]=tool;tool.Parent=backpack
end
function M:CleanupPlayer(player)
 self.Swings[player]=nil;self.NextSwing[player]=nil;self.NextRequest[player]=nil;self.SpawnAt[player]=nil;self.LastStart[player]=nil;self.History[player]=nil
 self.StartHeld[player]=nil;self.StartEarly[player]=nil
 local tool=self.Tools[player];self.Tools[player]=nil;if tool then tool:Destroy()end
 local links=self.Characters[player];self.Characters[player]=nil
 for _,link in ipairs(links or{})do link:Disconnect()end
end
function M:Start()
 if self.Started then return end;self.Started=true
 local folder=self.Chase.RunAlertRemote.Parent
 local remote=folder:FindFirstChild('BatSwing')
 if not remote then remote=Instance.new('RemoteEvent');remote.Name='BatSwing';remote.Parent=folder end
 assert(remote:IsA('RemoteEvent'),'BatSwing must be a RemoteEvent');self.Remote=remote
 table.insert(self.Connections,remote.OnServerEvent:Connect(function(player,payload)
  if type(payload)=='table'and payload.Kind=='Hit'then self:Claim(player,payload)else self:Request(player,payload)end
 end))
 table.insert(self.Connections,Run.Heartbeat:Connect(function()self:Step()end))
 local function setup(player)
  if self.Characters[player]then return end
  self.Characters[player]={player.CharacterAdded:Connect(function(character)self:Give(player,character)end),
   player.CharacterRemoving:Connect(function()self.Swings[player]=nil end)}
  local character=player.Character
  if character then task.spawn(function()self:Give(player,character)end)end
 end
 table.insert(self.Connections,Players.PlayerAdded:Connect(setup))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(player)self:CleanupPlayer(player)end))
 for _,player in ipairs(Players:GetPlayers())do setup(player)end
end
return M
