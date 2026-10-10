do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R69: readable night, anti-peek cover, moon sign and a synchronized starting horn.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local map=workspace:WaitForChild('ChestChaseMap');local player=game:GetService('Players').LocalPlayer
local Sky=require(RS.RefreshSky);local Blackout=require(RS.TrackBlackout);local Countdown=require(RS.RefreshCountdown)
local cover=Instance.new('ScreenGui');cover.Name='TrackPeekCover';cover.ResetOnSpawn=false;cover.ScreenInsets=Enum.ScreenInsets.None;cover.DisplayOrder=-5;cover.Parent=player:WaitForChild('PlayerGui')
local black=Instance.new('Frame');black.Name='InsideCover';black.Size=UDim2.fromScale(1,1);black.BackgroundColor3=Color3.new();black.BorderSizePixel=0;black.Active=false;black.Visible=false;black.Parent=cover
local sound=Instance.new('Sound');sound.Name='TrackRefreshCountdown';sound.SoundId='rbxasset://sounds/electronicpingshort.wav';sound.Volume=.45; sound.Looped=false
sound.SoundGroup=require(RS.AudioMixer).Group('Effects');sound.Parent=game:GetService('SoundService')
local horn=require(RS.RefreshHorn).New();local barrier,paint;local lastPaint=-math.huge
local dead=false
-- Preload well before refresh. Never wait for an audio load when a cue is due.
task.spawn(function()pcall(function()game:GetService('ContentProvider'):PreloadAsync({sound})end)end)
local cameraCheck,restoreSky,bounds,state
local function step()
 local camera=workspace.CurrentCamera
 local inside=camera~=nil and Blackout.InBounds(bounds,camera.CFrame.Position)
 if black.Visible~=inside then black.Visible=inside end
 local now=workspace:GetServerTimeNow();local number=Countdown.Take(state,now)
 if number then
  if sound.IsLoaded then sound:Stop();sound.PlaybackSpeed=({.9,1.06,1.25})[number];sound.TimePosition=0;sound:Play()end
 end
 -- R123: repaint on the cue frame so the wall's 3 / 2 / 1 changes with its beep (the paint is otherwise throttled).
 if number or now-lastPaint>=.1 then
  lastPaint=now
  if not barrier or not barrier.Parent or not paint then
   local runtime=map:FindFirstChild('_GameplayRuntime');barrier=runtime and runtime:FindFirstChild('BiomeRefreshWall')
   paint=barrier and require(RS.RefreshBarrier).Decorate(barrier)or nil
  end
  if paint then paint(now,math.max(0,(tonumber(state.Deadline)or now)-now))end
 end
end
local function restore()
 if cameraCheck then cameraCheck:Disconnect();cameraCheck=nil end
 black.Visible=false;sound:Stop();horn:Stop();state=nil;bounds=nil;barrier=nil;paint=nil;lastPaint=-math.huge
 if restoreSky then restoreSky();restoreSky=nil end
end
local function update()
 if dead then return end
 if map:GetAttribute('BiomesRefreshing')==true then
  if not restoreSky then
   restoreSky=Sky.Begin();bounds=Blackout.Bounds(map)
   state=Countdown.New(map:GetAttribute('BiomeRefreshEndsAt'))
   cameraCheck=Run.RenderStepped:Connect(step)
  end
  step()
 else
  -- The GO cue follows the server reopening the track, not the last countdown tick.
  local go=state and tonumber(state.Deadline)and workspace:GetServerTimeNow()>=(state.Deadline-.15)
  restore()
  if go and not horn:Play()and sound.IsLoaded then sound.PlaybackSpeed=1.5;sound.TimePosition=0;sound:Play()end
 end
end
local connections={map:GetAttributeChangedSignal('BiomesRefreshing'):Connect(update),map:GetAttributeChangedSignal('BiomeRefreshEndsAt'):Connect(function()
 if state then state.Deadline=map:GetAttribute('BiomeRefreshEndsAt')end
end)}
update()
script.Destroying:Connect(function()
 dead=true;for _,c in ipairs(connections)do c:Disconnect()end;restore();Sky.Destroy();horn:Destroy();sound:Destroy();cover:Destroy()
end)
