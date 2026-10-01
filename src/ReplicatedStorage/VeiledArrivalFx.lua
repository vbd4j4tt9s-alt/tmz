-- R122: Veiled One arrival - one sound for every player plus a one-second "lights out".
-- The darkness is a local ScreenGui drawn BELOW the HUD (DisplayOrder < 0): the 3D world goes dark
-- except a soft circle of visibility around the local character. Lighting is never modified, so
-- nothing has to be restored and nothing can be left dark (respawn, interruption, a second arrival,
-- or a script reload simply destroy the overlay). Reduced Motion: softer, slower fade, no hard snap.
-- Triggered by the server remote with its server timestamp; stale or replayed arrivals are ignored.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local F={}
F.SoundId='rbxassetid://113339179211972'
F.Volume=.8
F.Duration=1           -- seconds of lights-out
F.MaxAge=1.5           -- ignore an arrival older than this (late joiners / delayed delivery)
F.BubbleStuds=7        -- visibility radius around the character
F.Darkest=.04          -- overlay GroupTransparency at full dark (normal)
F.DarkestReduced=.35   -- gentler darkness under Reduced Motion
local played={}        -- serial -> true (one sound / one darkness per arrival)
local current           -- active overlay handle
local sound
-- Overlay transparency at time t (0..Duration). 1 = invisible.
function F.Darkness(t,reduced)
 local d=F.Duration
 if t<0 or t>=d then return 1 end
 local dark=reduced and F.DarkestReduced or F.Darkest
 local rise=reduced and .3 or .1;local fall=reduced and .4 or .3
 local k
 if t<rise then k=t/rise elseif t>d-fall then k=(d-t)/fall else k=1 end
 k=k*k*(3-2*k) -- smoothstep: no hard flash
 return 1-(1-dark)*k
end
-- Screen radius (px) of a world-space sphere; clamped for tiny / huge screens.
function F.HoleRadius(camera,worldPos,studs)
 local cf=camera.CFrame;local depth=(worldPos-cf.Position):Dot(cf.LookVector)
 local vp=camera.ViewportSize;local short=math.min(vp.X,vp.Y)
 if depth<=.5 then return short*.45 end
 local px=studs/(depth*math.tan(math.rad(camera.FieldOfView)/2))*vp.Y/2
 return math.clamp(px,48,short*.45)
end
function F.Preload()
 if sound then return sound end
 sound=Instance.new('Sound');sound.Name='VeiledArrivalSound';sound.SoundId=F.SoundId;sound.Volume=F.Volume;sound.Looped=false
 sound.Parent=game:GetService('SoundService')
 require(script.Parent.AudioMixer).Route(sound,'Effects')
 task.spawn(function()pcall(function()game:GetService('ContentProvider'):PreloadAsync({sound})end)end)
 return sound
end
function F.PlaySound()
 local s=F.Preload()
 s:Stop();require(script.Parent.SoundTiming).Play(s)
 return s
end
local function frame(parent,name)
 local f=Instance.new('Frame');f.Name=name;f.BorderSizePixel=0;f.BackgroundColor3=Color3.new(0,0,0);f.BackgroundTransparency=0;f.Parent=parent;return f
end
-- Stop and remove the overlay immediately (safe to call any time).
function F.Stop()
 local h=current;current=nil
 if h then
  if h.Connection then h.Connection:Disconnect()end
  if h.Gui then h.Gui:Destroy()end
 end
end
function F.Active()return current~=nil end
-- Lights-out overlay. `clock` defaults to os.clock (tests pass their own).
function F.LightsOut(clock)
 F.Stop()
 local player=Players.LocalPlayer;local pg=player and player:FindFirstChildOfClass('PlayerGui')
 if not pg then return nil end
 clock=clock or os.clock
 local reduced=Gui.ReducedMotionEnabled==true
 local screen=Instance.new('ScreenGui');screen.Name='VeiledLightsOut';screen.ResetOnSpawn=false;screen.IgnoreGuiInset=true
 screen.DisplayOrder=-20;screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 -- One CanvasGroup fades everything uniformly, so overlapping dark pieces never band.
 local group=Instance.new('CanvasGroup');group.Name='Darkness';group.BackgroundTransparency=1;group.Size=UDim2.fromScale(1,1);group.GroupTransparency=1;group.Parent=screen
 local top,bottom,left,right=frame(group,'Top'),frame(group,'Bottom'),frame(group,'Left'),frame(group,'Right')
 -- Round edge of the visibility bubble: an opaque thick ring plus three soft inner rings.
 local rings={}
 for i,alpha in ipairs({0,.45,.7,.88})do
  local ring=Instance.new('Frame');ring.Name='BubbleEdge'..i;ring.BackgroundTransparency=1;ring.AnchorPoint=Vector2.new(.5,.5);ring.Parent=group
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.5,0);corner.Parent=ring
  local stroke=Instance.new('UIStroke');stroke.Color=Color3.new(0,0,0);stroke.Transparency=alpha;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=ring
  rings[i]={Frame=ring,Stroke=stroke}
 end
 screen.Parent=pg
 local h={Gui=screen,Group=group,Started=clock(),Reduced=reduced}
 current=h
 local function layout()
  local camera=workspace.CurrentCamera;if not camera then return end
  local vp=camera.ViewportSize
  local character=player.Character;local root=character and(character:FindFirstChild('Head')or character:FindFirstChild('HumanoidRootPart'))
  local cx,cy,r=vp.X/2,vp.Y/2,0
  if root then
   local point,onScreen=camera:WorldToViewportPoint(root.Position)
   if onScreen then cx,cy=point.X,point.Y;r=F.HoleRadius(camera,root.Position,F.BubbleStuds)end
  end
  local soft=math.max(6,r*.08)
  local outer=r+r*.5 -- ring of width .5r covers the corners of the square hole
  local half=r>0 and outer/math.sqrt(2)-1 or 0
  top.Position=UDim2.fromOffset(0,0);top.Size=UDim2.new(1,0,0,math.max(0,cy-half))
  bottom.Position=UDim2.fromOffset(0,cy+half);bottom.Size=UDim2.new(1,0,0,math.max(0,vp.Y-cy-half))
  left.Position=UDim2.fromOffset(0,cy-half);left.Size=UDim2.fromOffset(math.max(0,cx-half),half*2)
  right.Position=UDim2.fromOffset(cx+half,cy-half);right.Size=UDim2.fromOffset(math.max(0,vp.X-cx-half),half*2)
  for i,ring in ipairs(rings)do
   local inner=i==1 and r or r-soft*(i-1)
   ring.Frame.Visible=r>0 and inner>0
   ring.Frame.Position=UDim2.fromOffset(cx,cy);ring.Frame.Size=UDim2.fromOffset(inner*2,inner*2)
   ring.Stroke.Thickness=i==1 and r*.5+2 or soft
  end
 end
 local function step()
  if current~=h then return end
  local t=clock()-h.Started
  if t>=F.Duration then F.Stop();return end
  group.GroupTransparency=F.Darkness(t,reduced)
  layout()
 end
 h.Step=step
 h.Connection=Run.RenderStepped:Connect(step)
 step()
 -- Safety net: even if rendering stops, the overlay is gone shortly after one second.
 task.delay(F.Duration+.25,function()if current==h then F.Stop()end end)
 return h
end
-- Remote handler: (cycle, serial, serverAt). Returns true when the arrival effects started.
function F.Arrive(serial,at,now)
 if type(serial)~='number'or type(at)~='number'or played[serial]then return false end
 now=now or workspace:GetServerTimeNow()
 if math.abs(now-at)>F.MaxAge then return false end -- stale: late joiner or delayed delivery
 played[serial]=true
 F.PlaySound()
 F.LightsOut()
 return true
end
function F._Reset()played={};F.Stop()end
return F
