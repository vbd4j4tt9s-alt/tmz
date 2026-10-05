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
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end end)
