-- R83: one client text stack; avoid constructing replicated GUIs for every toast.
local RS=game:GetService('ReplicatedStorage');local SimpleText=require(RS:WaitForChild('SimpleGameText'))
local N={Version='R83'};N.__index=N
function N.new()
 local folder=RS:FindFirstChild('ChestChaseRemotes')or Instance.new('Folder');folder.Name='ChestChaseRemotes';folder.Parent=RS
 local remote=folder:FindFirstChild('Notice83')or Instance.new('RemoteEvent');assert(remote:IsA('RemoteEvent'));remote.Name='Notice83';remote.Parent=folder
 return setmetatable({Remote=remote,Last=setmetatable({},{__mode='k'})},N)
end
function N:Show(player,message,accent,duration)
 local short,color=SimpleText.Format(message);if short==''or not player or not player.Parent then return end
 local now=os.clock();local last=self.Last[player];if last and last.Text==short and now-last.At<.7 then return end
 self.Last[player]={Text=short,At=now}
 local seconds=type(duration)=='number'and duration==duration and math.clamp(duration,.8,5)or 2.5
 self.Remote:FireClient(player,short,color or accent or SimpleText.Blue,seconds)
end
return N
