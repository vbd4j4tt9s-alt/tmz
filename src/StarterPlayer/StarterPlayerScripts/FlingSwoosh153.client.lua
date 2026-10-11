do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R153: the fast swoosh of a keeper launch (owner: "this fast swoosh sound effect also plays when players get hit and fly through the air").
-- Its own listener on the server's KeeperHit packet (sent only after a keeper's knockback was accepted; KeeperHitEffects, the keeper and ragdoll
-- scripts stay as they were). All the rules and the tuning numbers are in FlingSwoosh153 (ReplicatedStorage).
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Swoosh=require(RS:WaitForChild('FlingSwoosh153'))
local Sfx=require(RS:WaitForChild('LocalSfx'))
local player=Players.LocalPlayer
local remotes=RS:WaitForChild('ChestChaseRemotes',20);if not remotes then return end
local remote=remotes:WaitForChild('KeeperHit',20);if not remote then return end
Sfx.Preload({Swoosh.Id})
local lastId,warned=0,false
local connection=remote.OnClientEvent:Connect(function(hit)
 if type(hit)~='table'or type(hit.Id)~='number'or hit.Id<=lastId then return end
 lastId=hit.Id
 local ok,err=pcall(Swoosh.Hit,hit,player)
 if not ok and not warned then warned=true;warn('[R153] fling swoosh: '..tostring(err))end
end)
script.Destroying:Connect(function()connection:Disconnect();Swoosh.Clear()end)
