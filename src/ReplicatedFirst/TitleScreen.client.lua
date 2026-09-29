-- R104. One title sequence per connection, independent of character respawns.
local Players=game:GetService('Players')
local player=Players.LocalPlayer
local pg=player:WaitForChild('PlayerGui')
if player:GetAttribute('TitleScreenSeen104')then return end
player:SetAttribute('TitleScreenSeen104',true)
pg:SetAttribute('TitleActive',true)
local stop,finished
local function release()
 if finished then return end;finished=true
 if stop then stop()end
 pg:SetAttribute('TitleActive',nil)
end
script.Destroying:Connect(release)
task.delay(25,function()if not stop then release()end end)
local ok,why=xpcall(function()
 local module=game:GetService('ReplicatedStorage'):WaitForChild('TitleScreen104',20)
 if finished then return end
 assert(module,'Title screen did not replicate')
 stop=require(module).Start(player,pg)
 if finished then stop()end
end,debug.traceback)
if not ok then release();warn('[Title] '..tostring(why))end
