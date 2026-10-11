do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R151 (owner: "for the offline text when players press esc just make it a simple big rainbow text that says 'Plants grow
-- offline'"): replaces the R125 card. While the Roblox menu is open (Esc, the Roblox button, the console menu button) one line
-- of big chunky text, "🌱 Plants grow offline", sits outside the menu panel: no card, no panel, a dark outline for contrast and
-- a rainbow that slides along the letters (a still rainbow with Reduced Motion). Nothing runs while the menu is closed.
-- Where: Roblox draws its menu above every game GUI, so the line goes in the biggest free band above or below the menu panel,
-- worked out from the panel's size on this screen (CoreScripts Settings/SettingsHub + Theme, 2026):
--  * computer / tablet: a panel centred 10 px below the middle, min(600, 90% of the height - 120) of page + 134 px of bars and
--    padding (on 1920x1080 that leaves ~160 px below it);
--  * console: min(800, 86% - 200) of page + 214 px;
--  * phones (touch and under 500 tall or 700 wide): a sheet over the whole height, so the line sits at the bottom edge and
--    shows through the sheet's see-through background;
--  * no band of at least 34 px (a 768 px tall laptop): the bottom edge too.
-- Inside the device safe area (notch, home bar, TV edges), scaled to the band and to the screen width.
local Players=game:GetService('Players');local GuiService=game:GetService('GuiService');local Run=game:GetService('RunService')
local UIS=game:GetService('UserInputService');local TextService=game:GetService('TextService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local Audio=require(game:GetService('ReplicatedStorage'):WaitForChild('InteractionAudio'))
local TEXT,SPROUT='Plants grow offline','🌱'
local FONT=Enum.Font.FredokaOne
local MIN_BAND,MIN_SIZE,MAX_SIZE=34,22,100 -- (TextSize stops at 100)
local old=pg:FindFirstChild('OfflineGrowthNotice');if old then old:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='OfflineGrowthNotice';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets
gui.DisplayOrder=10001 -- above every game GUI (the title screen is 10000); Roblox's own menu is drawn above all of them
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false;gui.Parent=pg
local line=Instance.new('Frame');line.Name='Line';line.AnchorPoint=Vector2.new(.5,.5);line.BackgroundTransparency=1;line.BorderSizePixel=0;line.Parent=gui
local sprout=Instance.new('TextLabel');sprout.Name='Sprout';sprout.BackgroundTransparency=1;sprout.Text=SPROUT;sprout.Font=FONT
sprout.TextColor3=Color3.new(1,1,1);sprout.AnchorPoint=Vector2.new(0,.5);sprout.Parent=line
local title=Instance.new('TextLabel');title.Name='Title';title.BackgroundTransparency=1;title.Text=TEXT;title.Font=FONT
title.TextColor3=Color3.new(1,1,1);title.TextXAlignment=Enum.TextXAlignment.Left;title.AnchorPoint=Vector2.new(0,.5);title.Parent=line
local edge=Instance.new('UIStroke');edge.Name='Outline';edge.Color=Color3.fromRGB(22,14,38);edge.LineJoinMode=Enum.LineJoinMode.Round;edge.Parent=title
local rainbow=Instance.new('UIGradient');rainbow.Name='Rainbow';rainbow.Parent=title
-- Rainbow: 7 stops over the whole spectrum (the first and last are the same hue, so sliding the phase loops seamlessly).
local function hsv(h,s,v)
 h=(h%1)*6;local i=math.floor(h);local f=h-i;local p,q,t=v*(1-s),v*(1-s*f),v*(1-s*(1-f))
 if i==0 then return Color3.new(v,t,p)elseif i==1 then return Color3.new(q,v,p)elseif i==2 then return Color3.new(p,v,t)
 elseif i==3 then return Color3.new(p,q,v)elseif i==4 then return Color3.new(t,p,v)end;return Color3.new(v,p,q)
end
local function paint(phase)
 local keys={};for i=0,6 do keys[#keys+1]=ColorSequenceKeypoint.new(i/6,hsv(i/6-phase,.7,1))end
 rainbow.Color=ColorSequence.new(keys)
end
paint(0)
-- The Roblox menu panel's top and bottom (screen pixels) on a w x h screen.
local function menuPanel(w,h,touch,tenFoot)
 if tenFoot then local ph=math.max(150,math.min(800,h*.86-200))+214;return h/2+10-ph/2,h/2+10+ph/2 end
 if touch and(h<500 or w<700)then return 0,h end
 local ph=math.max(150,math.min(600,h*.9-120))+134;return h/2+10-ph/2,h/2+10+ph/2
end
local function width(size)
 local ok,bounds=pcall(function()return TextService:GetTextSize(TEXT,size,FONT,Vector2.new(4000,400))end)
 return (ok and bounds and bounds.X or size*9.2)+size*1.32+size*.16 -- title (Fredoka One: ~9.2 x the size) + sprout + gap and outline
end
local function place()
 local cam=workspace.CurrentCamera;local view=cam and cam.ViewportSize or gui.AbsoluteSize
 local at,room=gui.AbsolutePosition,gui.AbsoluteSize -- the device safe area, in screen pixels
 local okTv,tenFoot=pcall(function()return GuiService:IsTenFootInterface()end)
 local top,bottom=menuPanel(view.X,view.Y,UIS.TouchEnabled,okTv and tenFoot==true)
 local okInset,inset=pcall(function()return GuiService:GetGuiInset()end)
 local barBottom=math.max(at.Y,okInset and typeof(inset)=='Vector2'and inset.Y or 58) -- (below Roblox's top bar)
 local safeBottom=at.Y+room.Y
 local below,above=safeBottom-bottom,top-barBottom
 local size,centre
 if math.max(below,above)>=MIN_BAND then
  local band=math.max(below,above);size=math.clamp(math.floor(band*.78),MIN_SIZE,MAX_SIZE)
  centre=below>=above and(bottom+below/2)or(barBottom+above/2)
 else
  size=math.clamp(math.floor(view.Y*.1),30,56);centre=safeBottom-12-size/2
 end
 local fit=room.X*.92;local w=width(size)
 if w>fit then size=math.max(MIN_SIZE,math.floor(size*fit/w));w=width(size)end
 local thick=math.max(2,math.floor(size/13+.5))
 line.Position=UDim2.fromOffset(math.floor(room.X/2),math.floor(centre-at.Y));line.Size=UDim2.fromOffset(math.ceil(w),math.ceil(size*1.25))
 sprout.TextSize=size;sprout.Size=UDim2.fromOffset(math.ceil(size*1.32),math.ceil(size*1.25));sprout.Position=UDim2.new(0,0,.5,0)
 title.TextSize=size;title.Size=UDim2.new(1,-math.ceil(size*1.48),1,0);title.Position=UDim2.new(0,math.ceil(size*1.48),.5,0)
 edge.Thickness=thick
 gui:SetAttribute('TextSize',size);gui:SetAttribute('Placement',math.max(below,above)>=MIN_BAND and(below>=above and'below'or'above')or'edge')
end
local live={};local phase=0
local function stop()for _,c in ipairs(live)do c:Disconnect()end;table.clear(live)end
local function setOpen(open,quiet)
 if open==gui.Enabled then return end
 if not quiet then Audio.Play(open and'MenuClick'or'MenuClose')end -- R150: it clicks open / closed like the other pop-ups
 stop()
 if not open then gui.Enabled=false;return end
 place();gui.Enabled=true
 live[#live+1]=gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(place) -- (turning the phone, resizing the window)
 if GuiService.ReducedMotionEnabled then paint(0);return end
 live[#live+1]=Run.RenderStepped:Connect(function(dt) -- R153: the rainbow slides every frame (was 30 Hz: it stepped on a 60 Hz screen)
  phase=(phase+dt*.22)%1;paint(phase)
 end)
end
local conns={GuiService.MenuOpened:Connect(function()setOpen(true)end),GuiService.MenuClosed:Connect(function()setOpen(false)end),
 GuiService:GetPropertyChangedSignal('MenuIsOpen'):Connect(function()setOpen(GuiService.MenuIsOpen==true)end)} -- (either one is enough)
setOpen(GuiService.MenuIsOpen==true,true) -- (the menu was already open when this script started: shown, without a click)
local function quit()for _,c in ipairs(conns)do c:Disconnect()end;stop()end
gui.Destroying:Connect(quit) -- (a newer copy replaced this GUI)
script.Destroying:Connect(function()quit();gui:Destroy()end)
