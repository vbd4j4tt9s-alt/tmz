do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R132 (owner): a 🏠 floats over the middle of your own garden (above the centre aisle, clear of the beds) so you always
-- know which base is yours. Only you see it. Sized in studs with a small pixel floor so it stays findable from the track
-- without covering the garden up close; it bobs gently and follows you if the server moves you to another base.
local Players=game:GetService('Players');local Run=game:GetService('RunService')
local player=Players.LocalPlayer
local Marker={Height=10,Studs=6.5,Floor=22,Bob=.45,MaxDistance=900}
local gui,pad,elapsed,clock=nil,nil,1,0
local function ownBase()
 local map=workspace:FindFirstChild('ChestChaseMap');local bases=map and map:FindFirstChild('Bases')
 if not bases then return nil end
 for _,base in ipairs(bases:GetChildren())do
  local p=base:FindFirstChild('Pad')
  if p and p:IsA('BasePart')and base:GetAttribute('BaseOwnerUserId')==player.UserId then return p end
 end
 return nil
end
local function build()
 local g=Instance.new('BillboardGui');g.Name='HomeMarker';g.Size=UDim2.new(Marker.Studs,Marker.Floor,Marker.Studs,Marker.Floor)
 g.LightInfluence=0;g.AlwaysOnTop=false;g.MaxDistance=Marker.MaxDistance;g.ResetOnSpawn=false;g.ClipsDescendants=false
 local icon=Instance.new('TextLabel');icon.Name='Icon';icon.BackgroundTransparency=1;icon.Size=UDim2.fromScale(1,1);icon.Text='🏠'
 icon.TextScaled=true;icon.Font=Enum.Font.GothamBold;icon.TextColor3=Color3.new(1,1,1);icon.Parent=g
 return g
end
local function place(now)
 if not gui or not pad then return end
 gui.StudsOffsetWorldSpace=pad.CFrame.UpVector*(pad.Size.Y/2+Marker.Height+math.sin(now*1.4)*Marker.Bob)
end
local function refresh()
 local found=ownBase()
 if found==pad and(not found or gui and gui.Parent)then return end
 pad=found
 if not pad then if gui then gui:Destroy();gui=nil end;return end
 local holder=player:FindFirstChildOfClass('PlayerGui');if not holder then pad=nil;return end
 if not gui or not gui.Parent then gui=build()end
 gui.Adornee=pad;gui.Parent=holder;place(clock)
end
local connection=Run.Heartbeat:Connect(function(dt)
 clock+=dt;elapsed+=dt
 if elapsed>=1 then elapsed=0;refresh()end
 place(clock)
end)
script.Destroying:Connect(function()connection:Disconnect();if gui then gui:Destroy()end end)
