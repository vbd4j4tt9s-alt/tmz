do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Audio=require(RS:WaitForChild('InteractionAudio'));local player=Players.LocalPlayer
local connections={};local lastToken=0;local pending
local function tryPickup()
 if not pending or player.Character~=pending.Character then return end
 local model=pending.Character:FindFirstChild('CarriedSeed')
 if model and model:GetAttribute('PickupToken')==pending.Token and player:GetAttribute('ChestChaseSeedCarrying')then
  if pending.Token>lastToken then lastToken=pending.Token;Audio.Play('Bubble06')end;pending=nil
 end
end
-- Both stealing and retrieving use the same accepted pickup and visible carry model.
table.insert(connections,RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PackTaken').OnClientEvent:Connect(function(token,character)
 if type(token)~='number'or token<=lastToken or character~=player.Character then return end
 pending={Token=token,Character=character,At=os.clock()};tryPickup()
end))
local elapsed=0
table.insert(connections,game:GetService('RunService').Heartbeat:Connect(function(dt)
 if not pending then return end;elapsed+=dt;if elapsed<.03 then return end;elapsed=0
 if os.clock()-pending.At>2 or pending.Character~=player.Character then pending=nil else tryPickup()end
end))
table.insert(connections,player:GetAttributeChangedSignal('UpgradePressSerial'):Connect(function()Audio.Play('UpgradeClick')end))
-- R150: the server says how the press ended (GardenUpgradeService, same replication as the tier / price change): bought = KaChing, refused = Denied.
table.insert(connections,player:GetAttributeChangedSignal('UpgradeBoughtSerial'):Connect(function()Audio.Play('KaChing')end))
table.insert(connections,player:GetAttributeChangedSignal('UpgradeRefusedSerial'):Connect(function()Audio.Play('Denied')end))
-- R152 (owner: "the treadmill, no sound effects ... remove that whirring sound"): treadmills are silent. R150 clicked Equip when you stepped onto one
-- (the same cue as the hotbar's); the speed-gain popups are silent too. Also gone: the click as a prompt's hold begins (the finish has its own cue).
-- R153 (owner: "fix all jittery type effects"): the garden upgrade buttons' press, drawn here every frame (the server stamps PressedAt153; it used to
-- tween the cap itself, replicated in network-rate steps): the cap sinks .35 studs in .10 s (quad out), holds, and comes back in .16 s from .12 s.
-- One RenderStepped only while a press plays near the camera (200 studs); the server's cap never moves.
local CS=game:GetService('CollectionService');local Run=game:GetService('RunService')
local presses,capLinks,pressConn={},{},nil
local function out(u)u=math.clamp(u,0,1);return 1-(1-u)*(1-u)end
local function pressDepth(t)return t<.12 and .35*out(t/.10)or .35*(1-out((t-.12)/.16))end
local function pressStep()
 local now=workspace:GetServerTimeNow()
 for cap,at in pairs(presses)do
  local home=cap:GetAttribute('PressHome153');local t=now-at
  if not cap.Parent or typeof(home)~='CFrame'or t>=.28 or t<-.5 then
   presses[cap]=nil;if cap.Parent and typeof(home)=='CFrame'then cap.CFrame=home end
  else cap.CFrame=home*CFrame.new(0,-pressDepth(math.max(0,t)),0)end
 end
 if not next(presses)and pressConn then pressConn:Disconnect();pressConn=nil end
end
local function watchCap(cap)
 if capLinks[cap]then return end
 capLinks[cap]=cap:GetAttributeChangedSignal('PressedAt153'):Connect(function()
  local at=cap:GetAttribute('PressedAt153');local camera=workspace.CurrentCamera
  if type(at)~='number'or(camera and(camera.CFrame.Position-cap.Position).Magnitude>200)then return end
  presses[cap]=at;if not pressConn then pressConn=Run.RenderStepped:Connect(pressStep)end
 end)
end
for _,cap in ipairs(CS:GetTagged('GardenUpgradeCap153'))do watchCap(cap)end
table.insert(connections,CS:GetInstanceAddedSignal('GardenUpgradeCap153'):Connect(watchCap))
table.insert(connections,CS:GetInstanceRemovedSignal('GardenUpgradeCap153'):Connect(function(cap)local c=capLinks[cap];if c then c:Disconnect();capLinks[cap]=nil end;presses[cap]=nil end))
script.Destroying:Connect(function()
 for _,c in ipairs(connections)do c:Disconnect()end
 for _,c in pairs(capLinks)do c:Disconnect()end;table.clear(capLinks)
 if pressConn then pressConn:Disconnect();pressConn=nil end
end)
