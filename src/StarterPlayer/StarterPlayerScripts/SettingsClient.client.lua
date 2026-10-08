do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R63: saved audio mixing and client-only cosmetic quality.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local Config=require(RS.SettingsConfig);local Mixer=require(RS.AudioMixer)
-- R150: the mixer starts FIRST (it used to wait for the PremiumRequest remote below), so every sound already made, and the saved mix the
-- server publishes on the Player (AudioMixer reads it), is routed and set before anything else here can wait.
Mixer.Start();local Audio=require(RS.InteractionAudio);Audio.Preload();local RevealAudio=require(RS.RarityRevealAudio);RevealAudio.Preload()
local request=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')
local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI)
local previous=pg:FindFirstChild('GardenSettings');if previous then previous:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='GardenSettings';gui.ResetOnSpawn=false;gui.DisplayOrder=55;gui.Parent=pg
local function text(parent,name,value,pos,size,font)
 local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.TextXAlignment=Enum.TextXAlignment.Left;Bright.Text(t,font or 17);t.Parent=parent;return t
end
local function button(parent,name,value,pos,size,color)
 local b=Instance.new('TextButton');b.Name=name;b.Text=value;b.Position=pos;b.Size=size;b.BorderSizePixel=0;b.TextSize=26;b.Parent=parent;Bright.Button(b,color or Color3.fromRGB(83,160,231));return b
end
local toggle=button(gui,'SettingsButton','',UDim2.new(),UDim2.fromOffset(64,64),Color3.fromRGB(93,127,177))
local gear=Instance.new('Frame');gear.Name='Gear';gear.Size=UDim2.fromScale(.52,.52);gear.Position=UDim2.fromScale(.24,.12);gear.BackgroundTransparency=1;gear.Parent=toggle
for i=0,7 do local tooth=Instance.new('Frame');tooth.Size=UDim2.fromScale(.24,.96);tooth.AnchorPoint=Vector2.new(.5,.5);tooth.Position=UDim2.fromScale(.5,.5);tooth.Rotation=i*45;tooth.BackgroundColor3=Color3.fromRGB(219,242,255);tooth.BorderSizePixel=0;tooth.Parent=gear;Theme.Corner(tooth,3)end
local center=Instance.new('Frame');center.Size=UDim2.fromScale(.47,.47);center.Position=UDim2.fromScale(.265,.265);center.BackgroundColor3=Color3.fromRGB(60,91,137);center.BorderSizePixel=0;center.Parent=gear;Theme.Corner(center,30)
local caption=text(toggle,'Caption','SETTINGS',UDim2.new(0,1,1,-18),UDim2.new(1,-2,0,16),11);caption.TextXAlignment=Enum.TextXAlignment.Center
require(RS.HudLayout).Navigation(toggle,1)
local shade=button(gui,'Shade','',UDim2.new(),UDim2.fromScale(1,1));shade.BackgroundColor3=Color3.new();shade.BackgroundTransparency=.48;shade.Visible=false
for _,child in ipairs(shade:GetChildren())do child:Destroy()end
require(RS.MenuBackdrop).Attach(gui,shade,false)
local panel=Instance.new('Frame');panel.Name='SettingsPanel';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.new(.9,0,.86,0);panel.BorderSizePixel=0;panel.Visible=false;panel.Parent=gui;Bright.Panel(panel)
local cap=Instance.new('UISizeConstraint');cap.MaxSize=Vector2.new(520,470);cap.Parent=panel
text(panel,'Title','SETTINGS',UDim2.fromOffset(16,7),UDim2.new(1,-78,0,37),26)
local close=button(panel,'Close','X',UDim2.new(1,-49,0,8),UDim2.fromOffset(36,36),Color3.fromRGB(239,76,99))
local scroll=Instance.new('ScrollingFrame');scroll.Name='Controls';scroll.Position=UDim2.fromOffset(12,57);scroll.Size=UDim2.new(1,-24,1,-89);scroll.CanvasSize=UDim2.fromOffset(0,497);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=4;scroll.Parent=panel
local status=text(panel,'SaveStatus','',UDim2.new(0,16,1,-27),UDim2.new(1,-32,0,22),13)
local values=Config.Read();local controls={};local dirty={};local touched={};local serial=0;local saving=false;local dead=false;local connections={}
local function apply(key,value)
 values[key]=value;if not Config.Toggles[key]then Mixer.Set(key,value)end
 if key=='Quality'then player:SetAttribute('QualityChoice',value)end -- R113b: the player's own choice (Auto/Low/...)
 if key=='Quality'and value~='Auto'then player:SetAttribute('FastMode',value=='Low')end
 local attribute=Config.ToggleAttributes and Config.ToggleAttributes[key];if attribute then player:SetAttribute(attribute,value)end -- R153: the reveal reads it
 local row=controls[key];if row then row.Value.Text=type(value)=='number'and value..'%'or type(value)=='boolean'and(value and'On'or'Off')or value;if row.Fill then row.Fill.Size=UDim2.fromScale(value/100,1)end end
end
local flush
flush=function()
 if saving or dead or not next(dirty)then return end;saving=true
 task.spawn(function()
  local failed=false
  while not dead and next(dirty)do
   local key,value=next(dirty);local ok,result=pcall(request.InvokeServer,request,'SetSetting',{Key=key,Value=value})
   if not(ok and type(result)=='table'and result.Success)then failed=true;break end
   if dirty[key]==value then dirty[key]=nil end
   task.wait(.16)
  end
  saving=false;if dead then return end
  status.Text=failed and 'Can\'t save yet. Retrying…'or 'Saved'
  if failed then task.delay(3,flush)end
 end)
end
-- R150: hear the new level. The Interface row previews a button click, the Effects row a reveal pop (each through its own group, AFTER the
-- group has the new volume, so 0 is silent and the preview is as loud as the setting). Music / Chase / Ambience change audibly by themselves;
-- they get a plain click so the control is never silent.
local function preview(key)
 if key=='Effects'then RevealAudio.Play('Pop',1.08)else Audio.Play('Bubble04')end
end
local function change(key,value)
 if not Config.Valid(key,value)then return end
 touched[key]=true;dirty[key]=value;apply(key,value);status.Text='Saving…';serial+=1;local token=serial
 if key~='Quality'then preview(key)end
 task.delay(.3,function()if not dead and token==serial then flush()end end)
end
for i,pair in ipairs({{'Music','Background music'},{'Chase','Chase music'},{'Ambience','Ambience'},{'Effects','Sound effects'},{'Interface','Button sounds'}})do
 local key,name=pair[1],pair[2];local row=Instance.new('Frame');row.Name=key;row.Position=UDim2.fromOffset(0,(i-1)*56);row.Size=UDim2.new(1,-7,0,50);row.BackgroundTransparency=1;row.Parent=scroll
 text(row,'Label',name,UDim2.fromOffset(3,0),UDim2.new(1,-135,0,24),17)
 local value=text(row,'Value','100%',UDim2.new(1,-86,0,4),UDim2.fromOffset(46,30),15);value.TextXAlignment=Enum.TextXAlignment.Center
 local minus=button(row,'Quieter','−',UDim2.new(1,-127,0,4),UDim2.fromOffset(34,34));local plus=button(row,'Louder','+',UDim2.new(1,-34,0,4),UDim2.fromOffset(34,34))
 minus:SetAttribute('ButtonSound',false);plus:SetAttribute('ButtonSound',false) -- R150: change() previews the NEW level instead of a click at the old one
 local rail=button(row,'Volume','',UDim2.fromOffset(4,29),UDim2.new(1,-145,0,15),Color3.fromRGB(39,63,94));rail:SetAttribute('ButtonSound',false)
 local fill=Instance.new('Frame');fill.Name='Level';fill.Size=UDim2.fromScale(1,1);fill.BorderSizePixel=0;fill.BackgroundColor3=Color3.fromRGB(122,229,255);fill.Parent=rail;Theme.Corner(fill,6)
 controls[key]={Value=value,Fill=fill}
 minus.Activated:Connect(function()change(key,math.max(0,values[key]-10))end);plus.Activated:Connect(function()change(key,math.min(100,values[key]+10))end)
 rail.Activated:Connect(function(input)
  if input and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1)then
   local fraction=math.clamp((input.Position.X-rail.AbsolutePosition.X)/math.max(1,rail.AbsoluteSize.X),0,1);change(key,math.floor(fraction*10+.5)*10)
  else change(key,values[key]>=100 and 0 or values[key]+10)end
 end)
end
local quality=button(scroll,'Quality','',UDim2.fromOffset(3,287),UDim2.new(1,-12,0,43),Color3.fromRGB(93,97,173))
text(quality,'Label','Effects quality',UDim2.fromOffset(10,0),UDim2.new(.65,-10,1,0),17)
controls.Quality={Value=text(quality,'Value','Auto',UDim2.fromScale(.66,0),UDim2.fromScale(.32,1),17)}
quality.Activated:Connect(function()change('Quality',values.Quality=='Auto'and'High'or values.Quality=='High'and'Low'or'Auto')end)
-- R151: "Announcements from other servers" (on by default): a Secret+ pull in another server is a 🌐 chat line. Pulls in THIS server always show.
local announce=button(scroll,'GlobalAnnouncements','',UDim2.fromOffset(3,340),UDim2.new(1,-12,0,43),Color3.fromRGB(93,97,173))
text(announce,'Label','Announcements from other servers',UDim2.fromOffset(10,0),UDim2.new(.74,-10,1,0),17)
local announceValue=text(announce,'Value','On',UDim2.fromScale(.76,0),UDim2.fromScale(.22,1),17);announceValue.TextXAlignment=Enum.TextXAlignment.Center;controls.GlobalAnnouncements={Value=announceValue}
announce.Activated:Connect(function()change('GlobalAnnouncements',not values.GlobalAnnouncements)end)
-- R153 (owner: "they can skip if they want or we can add a skip cutscene option in the settings"): "Skip pack animations" (off by default):
-- on, every pack opens the short way (quick suspense, the result card, no story scene). Off, every opening plays in full.
local skip=button(scroll,'SkipCutscenes','',UDim2.fromOffset(3,393),UDim2.new(1,-12,0,43),Color3.fromRGB(93,97,173))
text(skip,'Label','Skip pack animations',UDim2.fromOffset(10,0),UDim2.new(.74,-10,1,0),17)
local skipValue=text(skip,'Value','Off',UDim2.fromScale(.76,0),UDim2.fromScale(.22,1),17);skipValue.TextXAlignment=Enum.TextXAlignment.Center;controls.SkipCutscenes={Value=skipValue}
skip.Activated:Connect(function()change('SkipCutscenes',not values.SkipCutscenes)end)
local loading=false
local function loadSettings()
 if loading or dead then return end;loading=true
 task.spawn(function()
  local ok,result=pcall(request.InvokeServer,request,'SettingsState');loading=false;if dead then return end
  if ok and type(result)=='table'and result.Success and result.Settings then
   for key,value in pairs(Config.Read(result.Settings))do if not touched[key]then apply(key,value)end end
  else task.delay(3,loadSettings)end
 end)
end
local function open(value)
 panel.Visible=value;shade.Visible=value
 if value then if pg:GetAttribute('SeedMenu')~='Settings'then pg:SetAttribute('SeedMenu','Settings')end;loadSettings()
 elseif pg:GetAttribute('SeedMenu')=='Settings'then pg:SetAttribute('SeedMenu',nil)end
 -- The shared navigation wheel owns its option visibility.
end
local replay=button(scroll,'ReplayTutorial','Replay tutorial',UDim2.fromOffset(3,446),UDim2.new(1,-12,0,43),Color3.fromRGB(55,168,135))
replay.TextSize=19;Bright.Button(replay,Color3.fromRGB(55,168,135))
replay.Activated:Connect(function()
 task.spawn(function()local ok,result=pcall(request.InvokeServer,request,'Tutorial','Replay');if ok and result and result.Success then open(false)end end)
end)
toggle.Activated:Connect(function()open(not panel.Visible)end);close.Activated:Connect(function()open(false)end);shade.Activated:Connect(function()open(false)end)
connections[#connections+1]=pg:GetAttributeChangedSignal('SeedMenu'):Connect(function()open(pg:GetAttribute('SeedMenu')=='Settings')end)
local slow,healthy=0,0
-- R153 perf (one quality signal): the 3 s frame-rate windows come from ClientFxBudget, which measures the frame rate for the quality tier anyway
-- (this script counted them on its own Heartbeat); the rule is unchanged: under 38 fps for 2 windows -> FastMode, over 53 fps for 4 -> off.
local function judge(fps)
 if values.Quality~='Auto'then return end
 slow=fps<38 and slow+1 or 0;healthy=fps>53 and healthy+1 or 0
 if slow>=2 and player:GetAttribute('FastMode')~=true then player:SetAttribute('FastMode',true)elseif healthy>=4 and player:GetAttribute('FastMode')~=false then player:SetAttribute('FastMode',false)end
end
do local ok,FxBudget=pcall(function()return require(RS:WaitForChild('ClientFxBudget',10))end)
 if ok and FxBudget and FxBudget.OnWindow then connections[#connections+1]=FxBudget.OnWindow(judge)
 else -- (the budget module missing: count the windows here, as before)
  local window,frames=0,0
  connections[#connections+1]=Run.Heartbeat:Connect(function(dt)
   if values.Quality~='Auto'then return end
   window+=math.min(dt,.25);frames+=1;if window<3 then return end
   local fps=frames/window;window=0;frames=0;judge(fps)
  end)
 end
end
gui.Destroying:Connect(function()dead=true;for _,c in ipairs(connections)do c:Disconnect()end end)
loadSettings()
