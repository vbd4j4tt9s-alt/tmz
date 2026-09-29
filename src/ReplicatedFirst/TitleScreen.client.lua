-- R104. One title sequence per connection, independent of character respawns. R111: skipped for brand-new players.
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
-- R111: brand-new players go straight into the tutorial. For them the title only covers loading:
-- it closes by itself (after at least 1.2 s) as soon as their save says the tutorial has not started.
local shownAt=os.clock();local watchers={}
local function newPlayer()return player:GetAttribute('TutorialDone')==false and(player:GetAttribute('TutorialMask')or 0)<=1 end
local function checkNew()
 if finished or not newPlayer()then return end
 for _,c in ipairs(watchers)do c:Disconnect()end;table.clear(watchers)
 task.delay(math.max(0,1.2-(os.clock()-shownAt)),release)
end
for _,name in ipairs({'TutorialDone','TutorialMask'})do watchers[#watchers+1]=player:GetAttributeChangedSignal(name):Connect(checkNew)end
checkNew()
local ok,why=xpcall(function()
 local module=game:GetService('ReplicatedStorage'):WaitForChild('TitleScreen104',20)
 if finished then return end
 assert(module,'Title screen did not replicate')
 stop=require(module).Start(player,pg)
 if finished then stop()end
end,debug.traceback)
if not ok then release();warn('[Title] '..tostring(why))end
