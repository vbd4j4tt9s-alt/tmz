local Players=game:GetService('Players');local connections={};local records={}
local function clear(p)local r=records[p];if r then for _,c in ipairs(r)do c:Disconnect()end;records[p]=nil end end
local function bind(p,character)
 clear(p);local r={};records[p]=r
 local function mute(n)
  if n.Name~='Running'and n.Name~='Walking'and n.Name~='Footsteps'then return end
  if n:IsA('Sound')then
   n:Stop();n.Volume=0;n.SoundId=''
   r[#r+1]=n:GetPropertyChangedSignal('SoundId'):Connect(function()if n.SoundId~=''then n.SoundId=''end end)
  elseif n:IsA('AudioPlayer')then
   n:Stop();n.Volume=0
   r[#r+1]=n:GetPropertyChangedSignal('Volume'):Connect(function()if n.Volume~=0 then n.Volume=0 end end)
  end
 end
 for _,n in ipairs(character:GetDescendants())do mute(n)end
 r[#r+1]=character.DescendantAdded:Connect(mute)
end
local watchers={}
local function add(p)
 watchers[p]={p.CharacterAdded:Connect(function(c)bind(p,c)end),p.CharacterRemoving:Connect(function()clear(p)end)}
 if p.Character then bind(p,p.Character)end
end
local function remove(p)clear(p);if watchers[p]then for _,c in ipairs(watchers[p])do c:Disconnect()end;watchers[p]=nil end end
connections[1]=Players.PlayerAdded:Connect(add);connections[2]=Players.PlayerRemoving:Connect(remove)
for _,p in ipairs(Players:GetPlayers())do add(p)end
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end;for p in pairs(watchers)do remove(p)end end)
