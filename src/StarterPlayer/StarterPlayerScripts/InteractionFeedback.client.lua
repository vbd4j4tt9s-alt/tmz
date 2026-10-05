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
-- R150: stepping onto a treadmill (TreadmillTraining false -> true) clicks Equip; the speed-gain popups stay silent (too frequent).
local training=player:GetAttribute('TreadmillTraining')==true
table.insert(connections,player:GetAttributeChangedSignal('TreadmillTraining'):Connect(function()
 local now=player:GetAttribute('TreadmillTraining')==true
 if now and not training then Audio.Play('Equip')end
 training=now
end))
-- R150: holding E on a prompt (take a pack, harvest, take the mystery pack...) clicks as the hold begins; the finish has its own cue.
-- ProximityPromptService.PromptButtonHoldBegan only fires for this player's own prompt use.
pcall(function()
 local Prompts=game:GetService('ProximityPromptService')
 table.insert(connections,Prompts.PromptButtonHoldBegan:Connect(function(prompt)
  if prompt.HoldDuration>0 then Audio.Play('Bubble04')end
 end))
end)
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end end)
