do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R122: shovel holes on the track (client). Sends only an optional aim point; the server decides everything.
-- Click / tap / R2 with the Shovel equipped while on the track: dig a hole there (or cover your own hole).
-- Also plays the dig / cover / fall effects for everyone. R124: a short tip fades in and out when the shovel comes out
-- (no permanent hint line any more). R153: it also says the shovel removes plants, and shows on the first HintTimes pull-outs of a session.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Input=game:GetService('UserInputService');local Run=game:GetService('RunService');local CAS=game:GetService('ContextActionService')
local Tween=game:GetService('TweenService');local Debris=game:GetService('Debris')
local C=require(RS:WaitForChild('TrackHoleConfig'))
local Sfx=require(RS:WaitForChild('LocalSfx'))
local Planting=require(RS:WaitForChild('PlantingEffects'))
local DigSound=require(RS:WaitForChild('DigSoundVariants'))
local Motion=RS:WaitForChild('RunnerMotion')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('TrackHole')
local V3=Vector3.new
local sounds={};for _,s in ipairs(Planting.Sounds)do sounds[s.Key]=s.Id end
-- R123: the trap thud (planting 'Land' layer) is preloaded with the dig recording so the first fall is not silent / late.
local digSound=DigSound.new();Sfx.Preload({C.DigSound.Id,sounds.Land})
local Fx=require(RS:WaitForChild('ClientFxBudget'));local Gui=game:GetService('GuiService')
local Feed=require(RS:WaitForChild('NoticeFeed83'))
local conns={};local lastSend=-math.huge;local wasHeld=false;local hintAt,hintShown=-math.huge,0;local elapsed=0

local function shovel()
 local char=player.Character;local hum=char and char:FindFirstChildOfClass('Humanoid');local tool=char and char:FindFirstChildOfClass('Tool')
 if hum and hum.Health>0 and tool and tool.Enabled and tool:GetAttribute('GardenShovel')then return char end
 return nil
end
local function onTrack(char)
 local root=char and char:FindFirstChild('HumanoidRootPart');if not root then return nil end
 local lineZ,centerX,half=Motion:GetAttribute('TrackBoundaryZ'),Motion:GetAttribute('TrackCenterX'),Motion:GetAttribute('TrackHalfWidth')
 if type(lineZ)~='number'or type(centerX)~='number'or type(half)~='number'then return nil end
 local p=root.Position
 if p.Z>lineZ and math.abs(p.X-centerX)<=half then return root end
 return nil
end
local function busy()
 return pg:GetAttribute('SeedMenu')~=nil or Input:GetFocusedTextBox()~=nil
  or player:GetAttribute('ChestChaseSeedCarrying')==true or player:GetAttribute('GuardianRagdollActive')==true
end
local function aimPoint(screen,root)
 local camera=workspace.CurrentCamera;if not camera or not screen then return nil end
 local ray=camera:ViewportPointToRay(screen.X,screen.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={player.Character};params.IgnoreWater=true
 local hit=workspace:Raycast(ray.Origin,ray.Direction*300,params)
 if hit and hit.Normal.Y>.7 and V3(hit.Position.X-root.Position.X,0,hit.Position.Z-root.Position.Z).Magnitude<=C.DigRange then return hit.Position end
 return nil -- server digs at the feet
end
-- Returns true when this input was a dig/cover request (the caller sinks it).
local function revealPress()local ok,taken=pcall(function()return require(game:GetService('ReplicatedStorage').RarePullRules).ClaimPress()end);return ok and taken==true end -- R153: a press that skips / closes a pull reveal's card is not the tool's
local function dig(screen)
 local char=shovel();local root=char and onTrack(char)
 if not root or busy()then return false end
 if revealPress()then return true end
 local now=os.clock();if now-lastSend<.25 then return true end;lastSend=now
 remote:FireServer(aimPoint(screen,root))
 return true
end

-- Effects ------------------------------------------------------------------------------------------------
local function near(position,range)
 local camera=workspace.CurrentCamera
 return camera and(camera.CFrame.Position-position).Magnitude<=range
end
-- R153: every dirt chunk in flight, with the time it was tossed. A chunk lives about a second (Debris takes it at 1.4 s); sweepDirt takes any that is still there after
-- 2 s (a tween or Debris that never finished) so no dirt is left hanging in the air.
local dirt={}
local function sweepDirt(all)
 local now=os.clock();local keep=0
 for i=1,#dirt do
  local rec=dirt[i];local p=rec.Part
  if p.Parent and not all and now-rec.At<2 then keep+=1;dirt[keep]=rec
  elseif p.Parent then p:Destroy()end
 end
 for i=#dirt,keep+1,-1 do dirt[i]=nil end
end
local function burst(position,count,color,height)
 -- R149: the keyboard's key tops stand above the (hidden) floor: dirt tossed from floor height would be under the keys, so it starts and lands on them.
 local okKeys,lift=pcall(function()return require(RS.KeyboardSurface149).Lift(position.X,position.Z,position.Y)end)
 if okKeys and lift>0 then position+=V3(0,lift,0)end
 -- R123: dirt chunks follow the shared FX budget (FastMode / low tier: half) and Reduced Motion (lower toss).
 local tier=Fx.Get();count=math.max(3,math.floor(count*(tier==1 and .5 or tier==2 and .75 or 1)+.5))
 if Gui.ReducedMotionEnabled==true then height*=.5 end
 for i=1,count do
  local p=Instance.new('Part');p.Name='HoleDirt';local s=.18+math.random()*.28;p.Size=V3(s,s,s)
  p.Color=color;p.Material=Enum.Material.Ground;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  local angle=i/count*math.pi*2+math.random()*.5;local r=C.Diameter*.5+math.random()*1.4
  p.CFrame=CFrame.new(position+V3(0,.2,0));p.Parent=workspace
  local peak=position+V3(math.cos(angle)*r*.6,height+math.random(),math.sin(angle)*r*.6)
  local land=position+V3(math.cos(angle)*r,s*.4,math.sin(angle)*r)
  local up=Tween:Create(p,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=CFrame.new(peak)*CFrame.Angles(math.random()*3,math.random()*3,0)})
  local down=Tween:Create(p,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=CFrame.new(land)})
  up.Completed:Connect(function()if p.Parent then down:Play()end end)
  down.Completed:Connect(function()if p.Parent then Tween:Create(p,TweenInfo.new(.5),{Transparency=1}):Play()end end)
  up:Play();Debris:AddItem(p,1.4);dirt[#dirt+1]={Part=p,At=os.clock()}
 end
end
local function holeModel(id)
 local folder=workspace:FindFirstChild('ChestChaseMap')and workspace.ChestChaseMap:FindFirstChild('TrackHoles',true)
 return folder and folder:FindFirstChild('TrackHole_'..tostring(id))
end
local function grow(model)
 -- Local-only: the replicated circle opens from small to full size (a short dig animation).
 for _,part in ipairs(model:GetChildren())do if part:IsA('BasePart')then
  local size=part.Size;local frame=part.CFrame
  if part.Name=='Crumb'then
   local center=model.PrimaryPart and model.PrimaryPart.Position or frame.Position
   part.CFrame=CFrame.new(center)*frame.Rotation
   Tween:Create(part,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{CFrame=frame}):Play()
  else
   part.Size=V3(size.X,size.Y*.25,size.Z*.25)
   Tween:Create(part,TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=size}):Play()
  end
 end end
end
table.insert(conns,remote.OnClientEvent:Connect(function(fx)
 if type(fx)~='table'or typeof(fx.Position)~='Vector3'then return end
 if not near(fx.Position,220)then return end
 local soil=Color3.fromRGB(104,69,41)
 if fx.Kind=='Dig'then
  local model=holeModel(fx.Id);if model then grow(model)end
  burst(fx.Position,8,soil,2.2);digSound:Play(fx.Position)
 elseif fx.Kind=='Cover'then
  burst(fx.Position,6,soil,1);digSound:Play(fx.Position,C.DigSound.CoverPitch)
 elseif fx.Kind=='Trap'then
  burst(fx.Position,10,soil,3);Sfx.Play(sounds.Land,fx.Position,.5,.9,2)
 end
end))

-- Input: same activation as the garden shovel (mouse click, touch tap, gamepad R2).
table.insert(conns,Input.InputBegan:Connect(function(input,processed)
 if processed then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then dig(Input:GetMouseLocation())end
end))
table.insert(conns,Input.TouchTapInWorld:Connect(function(position,processed)if not processed then dig(position)end end))
CAS:BindActionAtPriority('TrackHoleDig',function(_,state)
 local char=shovel();if not char or not onTrack(char)then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then local camera=workspace.CurrentCamera;dig(camera and Vector2.new(camera.ViewportSize.X/2,camera.ViewportSize.Y/2))end
 return Enum.ContextActionResult.Sink
end,false,2101,Enum.KeyCode.ButtonR2)

-- R124 / R153: the tip when the shovel is pulled out (garden or track); it fades by itself (NoticeFeed). The first C.HintTimes pull-outs of a session
-- (a pull-out while the last tip is still on screen is not counted).
table.insert(conns,Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.25 then return end;elapsed=0
 if #dirt>0 then sweepDirt()end
 local held=shovel()~=nil
 if held and not wasHeld and hintShown<C.HintTimes and os.clock()-hintAt>=C.HintRepeatSeconds then
  hintShown+=1;hintAt=os.clock();Feed.Plain(C.Hint,Color3.fromRGB(255,187,91),C.HintSeconds)
 end
 wasHeld=held
end))
script.Destroying:Connect(function()
 for _,c in ipairs(conns)do c:Disconnect()end;CAS:UnbindAction('TrackHoleDig');sweepDirt(true)
end)
