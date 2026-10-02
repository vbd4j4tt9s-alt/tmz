-- R122: Veiled One arrival - one sound for every player plus a "lights out".
-- R127 (owner): the lights-out is a real view-distance cut, like someone switching the lights off. The lights flicker
-- out, then the air goes black a short way from the camera: nearby things stay visible, everything further away is
-- black. A soft lantern glow (local only) lights the ground right around your own character. After a few seconds
-- the lights come back. The world is darkened only through EnvironmentLighting.SetBlackout (the one biome palette
-- blend), which writes the normal palette back exactly at level 0, on Stop, on teardown and on respawn.
-- Reduced Motion: no flicker, a slower and slightly lighter fade. Triggered by the server remote with its server
-- timestamp; replays are ignored, and a late delivery joins the darkness part-way instead of restarting it.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local F={}
F.SoundId='rbxassetid://113339179211972'
F.Volume=.8
F.Flicker=.45          -- seconds the lights stutter before going out
F.Hold=7               -- seconds fully dark
F.Return=2.5           -- seconds for the lights to come back
F.Duration=F.Flicker+F.Hold+F.Return
F.MaxAge=F.Flicker+F.Hold  -- a delivery later than this is ignored (the darkness is nearly over)
F.SoundMaxAge=1.5      -- the arrival sound only plays for a fresh delivery
F.ReducedLevel=.85     -- Reduced Motion: slightly lighter darkness
F.LanternRange=22      -- studs of soft light around the local character
F.LanternBrightness=1.6
F.LanternColor=Color3.fromRGB(255,214,170)
-- Flicker pattern (time share of F.Flicker, level): off, half back on, off, flutter, off.
F.FlickerKeys={{0,0},{.16,1},{.29,.35},{.49,1},{.64,.55},{.8,1},{1,1}}
local played={}        -- serial -> true (one sound / one darkness per arrival)
local current          -- active handle
local sound
local function env()return require(script.Parent.EnvironmentLighting)end
local function smooth(k)k=math.clamp(k,0,1);return k*k*(3-2*k)end
-- Darkness level 0..1 at time t since the arrival.
function F.Level(t,reduced)
 if type(t)~='number'or t<0 or t>=F.Duration then return 0 end
 local top=reduced and F.ReducedLevel or 1
 if t<F.Flicker then
  if reduced then return top*smooth(t/F.Flicker)end
  local u=t/F.Flicker;local keys=F.FlickerKeys
  for i=2,#keys do local a,b=keys[i-1],keys[i]
   if u<=b[1]then return a[2]+(b[2]-a[2])*(u-a[1])/math.max(1e-6,b[1]-a[1])end
  end
  return 1
 end
 if t<F.Flicker+F.Hold then return top end
 return top*smooth((F.Duration-t)/F.Return)
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
-- Stop at once and give the lights back (safe to call any time).
function F.Stop()
 local h=current;current=nil
 if h then
  if h.Connection then h.Connection:Disconnect()end
  if h.Lantern then h.Lantern:Destroy()end
 end
 if h or env().Level>0 then env().SetBlackout(0)end
end
function F.Active()return current~=nil end
-- The lantern lives on the local character's root (a client-made light other players never see).
local function lantern(h,level)
 local player=Players.LocalPlayer;local character=player and player.Character
 local root=character and(character:FindFirstChild('HumanoidRootPart')or character:FindFirstChild('Head'))
 if h.Lantern and(not root or h.Lantern.Parent~=root)then h.Lantern:Destroy();h.Lantern=nil end
 if not root then return end
 if not h.Lantern then
  local light=Instance.new('PointLight');light.Name='VeiledLantern';light.Range=F.LanternRange;light.Color=F.LanternColor
  light.Shadows=false;light.Brightness=0;light.Parent=root;h.Lantern=light
 end
 h.Lantern.Brightness=F.LanternBrightness*level
end
-- Start the darkness. `clock` defaults to os.clock (tests pass their own); `offset` skips ahead (late delivery).
function F.LightsOut(clock,offset)
 F.Stop()
 clock=clock or os.clock
 local h={Started=clock()-math.max(0,tonumber(offset)or 0),Reduced=Gui.ReducedMotionEnabled==true}
 current=h
 local function step()
  if current~=h then return end
  local t=clock()-h.Started
  if t>=F.Duration then F.Stop();return end
  local level=F.Level(t,h.Reduced)
  env().SetBlackout(level);lantern(h,level)
 end
 h.Step=step
 h.Connection=Run.RenderStepped:Connect(step)
 step()
 -- Safety net: even if rendering stops, the lights come back shortly after the effect ends.
 task.delay(F.Duration+.25-math.max(0,tonumber(offset)or 0),function()if current==h then F.Stop()end end)
 return h
end
-- Remote handler: (serial, serverAt). Returns true when the arrival effects started.
function F.Arrive(serial,at,now)
 if type(serial)~='number'or type(at)~='number'or played[serial]then return false end
 now=now or workspace:GetServerTimeNow()
 local age=now-at
 if age<-2 or age>F.MaxAge then return false end -- stale: late joiner or very delayed delivery
 played[serial]=true
 if age<=F.SoundMaxAge then F.PlaySound()end
 F.LightsOut(nil,math.max(0,age))
 return true
end
function F._Reset()played={};F.Stop()end
return F
