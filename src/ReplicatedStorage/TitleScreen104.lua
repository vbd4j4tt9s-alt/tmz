-- R105. Logo art: set this ModuleScript's TitleLogoAssetId attribute to the
-- uploaded approved STEAL A PACK image. A native title stays visible if it is
-- still loading or unavailable; image loading never blocks Click to Start.
local T={}
local RGB=Color3.fromRGB
function T.Ease(value)
 local x=math.clamp(value,0,1);return x*x*(3-2*x)
end
function T.Layout(width,height)
 width=math.max(width,1);height=math.max(height,1)
 local buttonHeight=math.min(58,math.max(48,height*.085))
 local bottom=math.max(20,math.min(46,height*.06))
 local buttonY=height-bottom-buttonHeight/2
 -- R157: the tip line floats in the middle of the gap between the logo (with the pack) and the button: one line on a PC / landscape phone, two on a portrait phone.
 -- The gap is kept at least tipGap = the line's height + 20 px (10 px of air each side: the pulse and the bob stay inside it). Where the gap was already that big (a
 -- 1920 x 1080 PC, a portrait phone) the logo, the pack and the button do not move; where it was not, the logo gets a little smaller (844 x 390: 443 px wide, was 477).
 local tipSize=math.clamp(math.floor(height*.03),16,32)
 local tipHeight=math.ceil(tipSize*1.15*(width<520 and 2 or 1))+4
 local tipGap=tipHeight+20
 local buttonTop=buttonY-buttonHeight/2
 local logoWidth=math.min(1160,width*.91,(height-bottom-buttonHeight-26-tipGap)*1.7768)
 logoWidth=math.max(1,logoWidth)
 local logoHeight=logoWidth/1.7768
 local logoY=math.min(height*.43,buttonTop-tipGap-logoHeight/2)
 logoY=math.max(logoHeight/2+8,logoY)
 return {LogoWidth=logoWidth,LogoHeight=logoHeight,LogoY=logoY,ButtonY=buttonY,
  ButtonWidth=math.max(1,math.min(300,width-40)),ButtonHeight=buttonHeight,
  TipY=(logoY+logoHeight/2+buttonTop)/2,TipWidth=math.max(1,math.min(780,width-48)),TipHeight=tipHeight,TipSize=tipSize}
end
function T.Image(value)
 if type(value)=='number'and value==value and value>0 and value%1==0 and value<9e15 then return 'rbxassetid://'..string.format('%.0f',value)end
 if type(value)=='string'then
  local digits=value:match('^rbxassetid://(%d+)$')or value:match('^(%d+)$')
  if digits then return T.Image(tonumber(digits))end
 end
 return ''
end
function T.PreviewDistance(size,aspect)
 local tangent=math.tan(math.rad(34)/2)
 return math.max(size.Y*.56/tangent,size.X*.56/(tangent*math.max(.1,aspect)))+size.Z/2
end
function T.Start(player,pg)
 local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage')
 local Lighting=game:GetService('Lighting');local Gui=game:GetService('GuiService')
 local CAS=game:GetService('ContextActionService');local StarterGui=game:GetService('StarterGui')
 local Prompts=game:GetService('ProximityPromptService');local Content=game:GetService('ContentProvider')
 local Input=game:GetService('UserInputService')
 local connections,hidden,cameras,core,badges={},{},{},{},{}
 local screen,backdrop,blur,group,logo,visual,button,scale,shade,curtain
 local phase,clock,leaving,dead,cameraReleased='Opening',0,0,false,false
 local desiredScale,currentScale=1,1
 local previewBag,previewRest,previewAmplitude
 local promptBefore=Prompts.Enabled
 -- R150: the start click. Loaded while the title is up (its voices warm in the meantime), so Enter / gamepad A / a click all sound the same.
 local Audio
 task.spawn(function()
  local module=RS:WaitForChild('InteractionAudio',10)
  if module then local ok,loaded=pcall(require,module);if ok then Audio=loaded end end
 end)
 local oldSelected=Gui.SelectedObject
 local binding='StealAPackTitle104'
 local promptConnection
 local function connect(signal,fn)
  local c=signal:Connect(fn);connections[#connections+1]=c;return c
 end
 local function restoreCamera()
  if cameraReleased then return end;cameraReleased=true
  for camera,saved in pairs(cameras)do
   if camera.Parent then
    camera.FieldOfView=saved.FOV
    local char=player.Character;local humanoid=char and char:FindFirstChildOfClass('Humanoid')
    camera.CameraSubject=humanoid or(saved.Subject and saved.Subject.Parent and saved.Subject)or nil
    -- The normal Roblox camera owns gameplay, including a respawn during the title.
    camera.CameraType=humanoid and Enum.CameraType.Custom or saved.Type
    camera.CFrame=saved.Frame;camera.Focus=saved.Focus
   end
  end
 end
 local function cleanup()
  if dead then return end;dead=true;phase='Gone'
  Run:UnbindFromRenderStep(binding);CAS:UnbindAction(binding..'Move');CAS:UnbindAction(binding..'Start')
  for _,c in ipairs(connections)do c:Disconnect()end
  if promptConnection then promptConnection:Disconnect()end
  restoreCamera()
  Prompts.Enabled=promptBefore
  for gui,wasEnabled in pairs(hidden)do if gui.Parent then
   local base=badges[gui]
   -- Ownership can change while the intro is open. Restore the server's
   -- current badge state rather than reviving a departed player's portrait.
   gui.Enabled=base and(base:GetAttribute('BaseOwnerDisplayName')or'')~=''or(not base and wasEnabled)
  end end
  for kind,enabled in pairs(core)do pcall(StarterGui.SetCoreGuiEnabled,StarterGui,kind,enabled)end
  if Gui.SelectedObject==button then Gui.SelectedObject=oldSelected and oldSelected.Parent and oldSelected or nil end
  pg:SetAttribute('TitleActive',nil)
  if blur then blur:Destroy()end
  if screen then screen:Destroy()end
  if backdrop then backdrop:Destroy()end
 end
 local function start()
  if dead or(phase~='Ready'and phase~='Opening')or Gui.MenuIsOpen then return false end
  phase='Leaving';leaving=0;button.Active=false;button.Selectable=false
  if Audio then Audio.Play('MenuClick')end -- R150: Enter / A used to be silent; the button's own click is off (ButtonSound=false) so this is the only one
  return true
 end
 local function guard(fn)
  return function(...)
   if dead then return end
   local ok,why=xpcall(fn,debug.traceback,...)
   if not ok then cleanup();warn('[Title] '..tostring(why))end
  end
 end
 local ok,why=xpcall(function()
  pg:SetAttribute('TitleActive',true)
  local function make(class,parent,properties)
   local item=Instance.new(class)
   for key,value in pairs(properties or{})do item[key]=value end
   item.Parent=parent;return item
  end
  backdrop=make('ScreenGui',pg,{Name='StealAPackTitleBackdrop',DisplayOrder=9999,ResetOnSpawn=false,
   IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
  shade=make('Frame',backdrop,{Name='Shade',Size=UDim2.fromScale(1,1),BackgroundColor3=RGB(10,23,17),BackgroundTransparency=.38,BorderSizePixel=0,Active=true})
  local gradient=make('UIGradient',shade,{Rotation=90})
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(.48,.58),NumberSequenceKeypoint.new(1,0)})
  screen=make('ScreenGui',pg,{Name='StealAPackTitle',DisplayOrder=10000,ResetOnSpawn=false,
   IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
  group=make('CanvasGroup',screen,{Name='TitleContent',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,GroupTransparency=1})
  visual=make('Frame',group,{Name='Logo',BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5)})
  local fallback=make('Frame',visual,{Name='NativeTitle',Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
  local function text(name,value,pos,size,color)
   local label=make('TextLabel',fallback,{Name=name,Text=value,Position=pos,Size=size,BackgroundTransparency=1,
    TextColor3=color,Font=Enum.Font.FredokaOne,TextScaled=true,TextXAlignment=Enum.TextXAlignment.Center})
   make('UIStroke',label,{Thickness=4,Color=RGB(23,37,16),LineJoinMode=Enum.LineJoinMode.Round})
   return label
  end
  text('StealA','STEAL A',UDim2.fromScale(.02,.1),UDim2.fromScale(.59,.31),RGB(255,255,244))
  text('Pack','PACK',UDim2.fromScale(.02,.4),UDim2.fromScale(.59,.49),RGB(119,229,66))
  logo=make('ImageLabel',visual,{Name='ApprovedTitle',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),
   ScaleType=Enum.ScaleType.Fit,Image=T.Image(script:GetAttribute('TitleLogoAssetId')),Visible=false})
  local function loaded()
   if dead then return end
   local ready=logo.Image~=''and logo.IsLoaded
   logo.Visible=ready;fallback.Visible=not ready
  end
  connect(logo:GetPropertyChangedSignal('IsLoaded'),loaded)
  connect(script:GetAttributeChangedSignal('TitleLogoAssetId'),function()
   logo.Image=T.Image(script:GetAttribute('TitleLogoAssetId'));loaded()
  end)
  loaded()
  if logo.Image~=''then task.spawn(function()pcall(Content.PreloadAsync,Content,{logo});loaded()end)end
  button=make('TextButton',group,{Name='ClickToStart',AnchorPoint=Vector2.new(.5,.5),Text='Click to play!',
   Font=Enum.Font.FredokaOne,TextSize=26,TextColor3=RGB(255,255,242),BackgroundColor3=RGB(72,154,51),
   BorderSizePixel=0,AutoButtonColor=false,Selectable=true,Active=true,Modal=true})
  button:SetAttribute('ButtonSound',false)
  make('UICorner',button,{CornerRadius=UDim.new(0,16)})
  make('UIStroke',button,{Thickness=3,Color=RGB(25,68,31)})
  local shine=make('UIGradient',button,{Rotation=90,Color=ColorSequence.new(RGB(157,233,101),RGB(74,164,65))})
  scale=make('UIScale',button,{Scale=1})
  curtain=make('Frame',backdrop,{Name='Transition',Size=UDim2.fromScale(1,1),BackgroundColor3=RGB(9,16,12),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=10,Active=true})
  blur=make('BlurEffect',Lighting,{Name='StealAPackTitleBlur104',Size=0})
  local function hide(gui,base)
   if dead or gui==screen or gui==backdrop or(not gui:IsA('ScreenGui')and not(base and gui:IsA('BillboardGui')))or hidden[gui]~=nil then return end
   if base then badges[gui]=base end
   hidden[gui]=gui.Enabled;gui.Enabled=false
   connect(gui:GetPropertyChangedSignal('Enabled'),function()
    if not dead and gui.Enabled then hidden[gui]=true;gui.Enabled=false end
   end)
  end
  for _,gui in ipairs(pg:GetChildren())do hide(gui)end
  connect(pg.ChildAdded,hide)
  local function hideCore()
   if dead then return end
   -- Hotbar.lua already owns the built-in Backpack's disabled state. Do not
   -- capture its pre-startup default and accidentally re-enable it on exit.
   for _,kind in ipairs({Enum.CoreGuiType.PlayerList,Enum.CoreGuiType.Chat,Enum.CoreGuiType.Health,Enum.CoreGuiType.EmotesMenu})do
    if core[kind]==nil then
     local good,enabled=pcall(StarterGui.GetCoreGuiEnabled,StarterGui,kind)
     if good then core[kind]=enabled;pcall(StarterGui.SetCoreGuiEnabled,StarterGui,kind,false)end
    end
   end
  end
  hideCore();task.delay(.5,hideCore)
  Prompts.Enabled=false
  promptConnection=Prompts:GetPropertyChangedSignal('Enabled'):Connect(function()if not dead and Prompts.Enabled then Prompts.Enabled=false end end)
  local blocked=Enum.PlayerActions:GetEnumItems()
  for _,key in ipairs({'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero','Backquote','B','E','F','Q','ButtonR2','ButtonL2','ButtonL1','ButtonR1','ButtonL3','ButtonX'})do
   blocked[#blocked+1]=Enum.KeyCode[key]
  end
  CAS:BindActionAtPriority(binding..'Move',function()
   return Gui.MenuIsOpen and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
  end,false,10000,table.unpack(blocked))
  CAS:BindActionAtPriority(binding..'Start',function(_,state)
   if Gui.MenuIsOpen then return Enum.ContextActionResult.Pass end
   if state==Enum.UserInputState.Begin then start()end
   return Enum.ContextActionResult.Sink
  end,false,10001,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA)
  connect(button.Activated,start)
  connect(button.MouseEnter,function()desiredScale=1.035 end)
  connect(button.MouseLeave,function()desiredScale=1 end)
  connect(button.MouseButton1Down,function()desiredScale=.97 end)
  connect(button.MouseButton1Up,function()desiredScale=1 end)
  connect(button.SelectionGained,function()desiredScale=1.035 end)
  connect(button.SelectionLost,function()desiredScale=1 end)
  if Input.GamepadEnabled then Gui.SelectedObject=button end
  local layout
  -- R157 (owner: "add tips in the starting screen"; Style B, then "in the middle", "a new tip every 10 s", a small pulse like Minecraft's splash, highlighted words): one tip line
  -- floating between the logo and Click to play!. A new tip every Tips.Interval s (fades out / in), a gentle pulse (+-Tips.PulseAmount in size, a full breath every Tips.PulsePeriod s)
  -- and a very small bob (Tips.BobPixels). Reduced Motion: no fade, no pulse, no bob (the text just changes). The list, its timings and the highlight mini-markup are
  -- ReplicatedStorage.TitleTips156 (one line per tip), required below with WaitForChild + pcall like the title's other modules. A missing / broken list just leaves the line out.
  -- Nothing is allocated per frame: the lines, the order and the bob's positions are built once (the bob walks through TIP_BOB_STEPS ready-made UDim2 values).
  local tipLabel,tipStroke,tipScale,tips,tipLines,tipOrder,tipRandom,tipIndex,tipClock,pulseClock,tipAlpha
  local tipBob,tipRest,tipBobAt={},nil,0
  local TIP_BOB_STEPS=60
  local function resize()
   local size=group.AbsoluteSize;layout=T.Layout(size.X,size.Y)
   visual.Size=UDim2.fromOffset(layout.LogoWidth,layout.LogoHeight)
   button.Size=UDim2.fromOffset(layout.ButtonWidth,layout.ButtonHeight)
   button.Position=UDim2.fromOffset(size.X/2,layout.ButtonY)
   if tipLabel then
    tipLabel.Size=UDim2.fromOffset(layout.TipWidth,layout.TipHeight)
    tipLabel:FindFirstChildOfClass('UITextSizeConstraint').MaxTextSize=layout.TipSize
    tipRest=UDim2.fromOffset(size.X/2,layout.TipY)
    for i=1,TIP_BOB_STEPS do tipBob[i]=UDim2.fromOffset(size.X/2,layout.TipY+tips.BobPixels*math.sin((i-1)*math.pi*2/TIP_BOB_STEPS))end
    tipBobAt=0;tipLabel.Position=tipRest
   end
  end
  connect(group:GetPropertyChangedSignal('AbsoluteSize'),resize);resize()
  task.spawn(function()
   local good,list=pcall(function()return require(RS:WaitForChild('TitleTips156',10))end)
   if dead or not good or type(list)~='table'or type(list.Tips)~='table'or #list.Tips==0 then return end
   local label
   local built,why=pcall(function()
    -- a list with a missing / wrong number or line must not reach the frame step (an error there would close the title): check it once, here
    for _,key in ipairs({'Interval','Fade','PulseAmount','PulsePeriod','BobPixels','BobPeriod'})do assert(type(list[key])=='number'and list[key]==list[key],'Tips.'..key)end
    assert(list.Fade>0 and list.Interval>list.Fade*2 and list.PulsePeriod>0 and list.BobPeriod>0,'Tips timings')
    local lines={};for i=1,#list.Tips do lines[i]=list.Line(i);assert(type(lines[i])=='string','Tips.Line('..i..')')end
    local random=Random.new()
    local order=T.TipOrder and table.clone(T.TipOrder)or list.Order(random) -- (T.TipOrder: a fixed order for the tests and the preview)
    label=make('TextLabel',group,{Name='TipLine',AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Text=lines[order[1]],RichText=true,
     Font=Enum.Font.FredokaOne,TextScaled=true,TextWrapped=true,TextColor3=RGB(255,255,242),TextXAlignment=Enum.TextXAlignment.Center,
     TextTransparency=1,Active=false,Interactable=false,Selectable=false}) -- (no input at all: it never takes the click meant for the button; the first frame step fades it in)
    make('UITextSizeConstraint',label,{MaxTextSize=26,MinTextSize=11})
    tipStroke=make('UIStroke',label,{Thickness=2,Color=RGB(23,37,16),LineJoinMode=Enum.LineJoinMode.Round,Transparency=1})
    tipScale=make('UIScale',label,{Scale=1})
    tips,tipLines,tipOrder,tipRandom,tipIndex,tipClock,pulseClock,tipAlpha=list,lines,order,random,1,0,0,nil
    tipLabel=label;resize()
   end)
   if not built then
    tipLabel=nil;if label then label:Destroy()end
    warn('[Title tips] '..tostring(why))
   end
  end)
  -- Load the real highest forest tier for the temporary native title. No
  -- unrelated shop pack, mesh, design, or world animation is changed.
  task.spawn(function()
   local good,err=pcall(function()
    if not game:IsLoaded()then game.Loaded:Wait()end
    if dead then return end
    local module=RS:WaitForChild('SeedPackVisuals',10)
    if dead or not module then return end
    local assets=RS:WaitForChild('SeedPackMeshAssets',10)
    if dead or not assets then return end
    local template=assets:WaitForChild('Forest_06',10)
    if dead or not template then return end
    local visuals=require(module)
    if dead then return end
    local view=make('ViewportFrame',fallback,{Name='ForestMythicPack',BackgroundTransparency=1,
     Position=UDim2.fromScale(.71,.04),Size=UDim2.fromScale(.29,.92),Ambient=RGB(255,255,255),LightColor=RGB(255,255,255),LightDirection=Vector3.new(-.4,-.5,1)})
    local world=make('WorldModel',view)
    local bag=visuals.Bag(CFrame.Angles(0,.15,-.12),world,1,nil,1,'Pack06',1,1,'None')
    game:GetService('CollectionService'):RemoveTag(bag,'BiomeSeedPackVisual');bag:SetAttribute('WorldPack',false)
    local cf,size=bag:GetBoundingBox()
    local camera=make('Camera',view,{FieldOfView=34})
    -- Fit the rotated silhouette to this narrower viewport, including the
    -- floating margin, rather than clipping the edges with a fixed distance.
    local right,up,look=cf.RightVector,cf.UpVector,cf.LookVector
    local bounds=Vector3.new(
     math.abs(right.X)*size.X+math.abs(up.X)*size.Y+math.abs(look.X)*size.Z,
     math.abs(right.Y)*size.X+math.abs(up.Y)*size.Y+math.abs(look.Y)*size.Z,
     math.abs(right.Z)*size.X+math.abs(up.Z)*size.Y+math.abs(look.Z)*size.Z)
    local function fitPreview()
     if dead then return end
     local pixels=view.AbsoluteSize;local aspect=pixels.Y>0 and pixels.X/pixels.Y or .29*1.7768/.92
     local distance=T.PreviewDistance(bounds,aspect)
     camera.CFrame=CFrame.lookAt(cf.Position+Vector3.new(0,0,-distance),cf.Position)
    end
    connect(view:GetPropertyChangedSignal('AbsoluteSize'),fitPreview);fitPreview()
    view.CurrentCamera=camera
    if dead then view:Destroy()else previewBag=bag;previewRest=bag:GetPivot();previewAmplitude=size.Y*.014 end
   end)
   if not good and not dead then warn('[Title preview] '..tostring(err))end
  end)
  local target,radius,targetClock,desiredTarget,desiredRadius
  local function baseView()
   local map=workspace:FindFirstChild('ChestChaseMap');local bases=map and map:FindFirstChild('Bases')
   local first
   if bases then for _,base in ipairs(bases:GetChildren())do
    local fence=base:FindFirstChild('GardenFence34')
    local badge=fence and fence:FindFirstChild('GardenOwnerBadge',true)
    if badge then hide(badge,base)end
    local pad=base:FindFirstChild('Pad')
    if pad and pad:IsA('BasePart')then
     first=first or pad
     if base:GetAttribute('BaseOwnerUserId')==player.UserId then first=pad end
    end
   end end
   if first then return first.Position,math.clamp(math.max(first.Size.X,first.Size.Z)*.85,95,240)end
   local lobby=map and map:FindFirstChild('Lobby');local spawn=lobby and lobby:FindFirstChild('FallbackSpawn')
   if spawn and spawn:IsA('BasePart')then return spawn.Position,125 end
  end
  -- R157: the tip line's clock (run from frame while the title shows, not while it leaves). It builds no table, closure, string or UDim2: the text, the order and the bob's positions are
  -- ready-made, and a property is only written when its value changes.
  local function stepTip(dt,reduced)
   tipClock+=dt;pulseClock+=dt
   if tipClock>=tips.Interval then
    tipClock-=tips.Interval;tipIndex+=1
    if tipIndex>#tipOrder then tipIndex=1;tips.Order(tipRandom,tipOrder,tipOrder[#tipOrder])end -- every tip has shown: a new shuffle (reshuffled in place), never the same tip twice in a row
    tipLabel.Text=tipLines[tipOrder[tipIndex]]
   end
   -- fade in over Fade s, hold, fade out over the last Fade s (the text changes while it is invisible); Reduced Motion: no fade, the text just changes
   local alpha=reduced and 1 or math.min(1,tipClock/tips.Fade,(tips.Interval-tipClock)/tips.Fade)
   if alpha~=tipAlpha then tipAlpha=alpha;tipLabel.TextTransparency=1-alpha;tipStroke.Transparency=1-alpha end
   if reduced then
    tipScale.Scale=1
    if tipBobAt~=0 then tipBobAt=0;tipLabel.Position=tipRest end
   else
    -- the pulse about the label's centre, and the bob (the nearest of TIP_BOB_STEPS positions along its sine)
    tipScale.Scale=1+tips.PulseAmount*math.sin(pulseClock*math.pi*2/tips.PulsePeriod)
    local step=math.floor(pulseClock/tips.BobPeriod%1*TIP_BOB_STEPS+.5)%TIP_BOB_STEPS+1
    if step~=tipBobAt then tipBobAt=step;tipLabel.Position=tipBob[step]end
   end
  end
  local function frame(dt)
   dt=math.clamp(dt,0,.1);clock+=dt
   local reduced=Gui.ReducedMotionEnabled
   local reveal=T.Ease(clock/(reduced and .18 or .72))
   if phase=='Opening'and reveal>=1 then phase='Ready'end
   if phase~='Leaving'then group.GroupTransparency=1-reveal;blur.Size=18*reveal end
   currentScale+=(desiredScale-currentScale)*(1-math.exp(-dt*16));scale.Scale=currentScale
   -- Keep text on a stable pixel baseline; float the 3D pack inside its own
   -- viewport so sub-pixel GUI rounding cannot make the whole wordmark jitter.
   visual.Position=UDim2.fromOffset(group.AbsoluteSize.X/2,layout.LogoY+(1-reveal)*14)
   if tipLabel and phase~='Leaving'then stepTip(dt,reduced)end
   if previewBag and previewBag.Parent then
    local bob=reduced and 0 or math.sin(clock*.7)*previewAmplitude
    local sway=reduced and 0 or math.sin(clock*.35)*.009
    previewBag:PivotTo(previewRest*CFrame.new(0,bob,0)*CFrame.Angles(0,0,sway))
   end
   if not cameraReleased then
    targetClock=(targetClock or 1)+dt
    if targetClock>=.5 then
     targetClock=0;local found,span=baseView()
     if found then
      desiredTarget,desiredRadius=found,span
      target=target or found;radius=radius or span
     end
    end
    if desiredTarget then
     local blend=1-math.exp(-dt*1.4)
     target=target:Lerp(desiredTarget,blend);radius+=(desiredRadius-radius)*blend
    end
    local camera=workspace.CurrentCamera
    if camera and target then
     if not cameras[camera]then cameras[camera]={FOV=camera.FieldOfView,Frame=camera.CFrame,Focus=camera.Focus,Subject=camera.CameraSubject,Type=camera.CameraType}end
     local angle=.6+(reduced and 0 or clock*.027)
     local eye=target+Vector3.new(math.cos(angle)*radius,radius*.62+20,math.sin(angle)*radius)
     camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=58
     camera.CFrame=CFrame.lookAt(eye,target+Vector3.new(0,8,0));camera.Focus=CFrame.new(target)
    end
   end
   if phase=='Leaving'then
    leaving+=dt;local duration=reduced and .18 or .32
    local out=T.Ease(leaving/duration)
    group.GroupTransparency=out;curtain.BackgroundTransparency=1-out
    if leaving>=duration then
     restoreCamera();blur.Size=0
     local back=T.Ease((leaving-duration-.12)/.42)
     curtain.BackgroundTransparency=back;shade.BackgroundTransparency=.38+.62*back
     if back>=1 then cleanup()end
    end
   end
  end
  Run:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+1,guard(frame))
  connect(screen.Destroying,cleanup)
  connect(backdrop.Destroying,cleanup)
  game:GetService('ReplicatedFirst'):RemoveDefaultLoadingScreen()
 end,debug.traceback)
 if not ok then cleanup();error(why)end
 return cleanup
end
return T
