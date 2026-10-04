-- R147 (owner: "Verity NPC is a quest giver: it tells players to steal a pack from The Darkened one and give it to the
-- Verity NPC. The Verity NPC will be behind the market and it will be big."): the client half of VerityService.
--  * Her card turns to face the camera (around Y only, on this client; a gentle bob; none with ReducedMotion).
--  * A marker over her head: a "!" normally, a bouncing gold "?" while you carry a Void Pack (a Backpack / Character Tool
--    with SeedPackTool and BagVariant 'EclipseReliquary').
--  * Talk to her (the server answers the prompt with 'Open') and a window shows her quest, how many Void Packs you have,
--    how many you handed in, when The Darkened is here / comes, and the GIVE VOID PACK button (only with a Void Pack).
--    'Done' = thanks + a sound, 'Refused' = the reason. PlayerGui.SeedMenu = 'Verity' while it is open.
-- The server owns every rule; this only sends 'Give' (no arguments) and shows what it is told.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local Tween=game:GetService('TweenService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local remotes=RS:WaitForChild('ChestChaseRemotes')
local C=require(RS:WaitForChild('VerityConfig'));local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI);local Audio=require(RS.InteractionAudio)
local RGB=Color3.fromRGB
local GOLD,MINT,SKY,RED,VIOLET=RGB(255,206,64),RGB(110,226,96),RGB(86,182,255),RGB(255,96,96),RGB(190,140,255)
local connections={};local function watch(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
local function new(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function text(parent,name,value,size,color)
 local t=new('TextLabel',{Name=name,Text=value,BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center},parent)
 Bright.Text(t,size or 16,color);return t
end
local function stroke(parent,color,thickness)return new('UIStroke',{Color=color,Thickness=thickness or 2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent)end
local function countdown(seconds)
 seconds=math.max(0,math.floor(seconds));local h=math.floor(seconds/3600);local m=math.floor(seconds%3600/60)
 if h>0 then return h..'h '..m..'m'end;if m>0 then return m..'m '..seconds%60 ..'s'end;return seconds..'s'
end
-- Void Packs in your hands or Bag (Tools): the marker's "?" and nothing else (the window uses the server's count).
local function isVoidTool(tool)
 return tool:IsA('Tool')and tool:GetAttribute('SeedPackTool')==true and tool:GetAttribute('BagVariant')==C.VoidVariant
end
local function countVoidTools()
 local n=0
 for _,container in ipairs({player:FindFirstChildOfClass('Backpack'),player.Character})do
  if container then for _,child in ipairs(container:GetChildren())do if isVoidTool(child)then n+=1 end end end
 end
 return n
end
-- Her card and the marker ----------------------------------------------------------------------------------------------------
local entry=nil
local function wrap(angle)return(angle+math.pi)%(math.pi*2)-math.pi end
local function refreshMarker()
 local e=entry;if not e or not e.Mark.Parent then return end
 local has=countVoidTools()>0
 e.Mark.Text=has and'?'or'!';e.Mark.TextColor3=has and GOLD or Color3.new(1,1,1)
 e.Marker:SetAttribute('Bounce',has);e.Marker:SetAttribute('HasVoidPack',has);e.Has=has
 if not has then e.Marker.StudsOffsetWorldSpace=e.MarkerBase end
end
local function build(model,card)
 local base=card.CFrame;local look=base.LookVector
 local marker=new('BillboardGui',{Name='VerityMarker',Adornee=card,Size=UDim2.fromOffset(90,90),StudsOffsetWorldSpace=Vector3.new(0,card.Size.Y/2+C.MarkerHeight,0),
  AlwaysOnTop=false,MaxDistance=C.MarkerMaxDistance,LightInfluence=0,ResetOnSpawn=false},model)
 local mark=new('TextLabel',{Name='Mark',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,TextScaled=true,Text='!',TextColor3=Color3.new(1,1,1),
  TextStrokeColor3=RGB(40,22,70),TextStrokeTransparency=0},marker)
 local yaw=math.atan2(-look.X,-look.Z)
 entry={Model=model,Card=card,Marker=marker,Mark=mark,Base=base.Position,Yaw=yaw,Yaw0=yaw,MarkerBase=marker.StudsOffsetWorldSpace,Has=false,Moved=false}
 refreshMarker()
end
local function attach(model)
 if entry and entry.Model==model then return end
 if not model:IsA('Model')then return end
 local card=model:FindFirstChild('Card')
 if card then build(model,card);return end
 local waiting;waiting=model.ChildAdded:Connect(function(child)if child.Name=='Card'then waiting:Disconnect();if model.Parent then build(model,child)end end end)
 connections[#connections+1]=waiting
end
local function detach(model)
 if entry and entry.Model==model then if entry.Marker then entry.Marker:Destroy()end;entry=nil end
end
for _,model in ipairs(CS:GetTagged(C.Tag))do attach(model)end
watch(CS:GetInstanceAddedSignal(C.Tag),attach);watch(CS:GetInstanceRemovedSignal(C.Tag),detach)
do -- (the model may already be in the map without the tag having replicated yet)
 local map=workspace:FindFirstChild('ChestChaseMap');local hub=map and map:FindFirstChild('EconomyHub');local model=hub and hub:FindFirstChild(C.ModelName)
 if model then attach(model)end
end
-- Each frame: turn to the camera (yaw only), bob, bounce the "?".
watch(Run.RenderStepped,function(dt)
 local e=entry;if not e or not e.Card.Parent then return end
 if GuiService.ReducedMotionEnabled then
  if e.Moved then -- back to how the server placed her
   e.Moved=false;e.Yaw=e.Yaw0;e.Card.CFrame=CFrame.new(e.Base)*CFrame.Angles(0,e.Yaw0,0);e.Marker.StudsOffsetWorldSpace=e.MarkerBase
  end
  return
 end
 local now=os.clock()
 local camera=workspace.CurrentCamera
 if camera then
  local to=camera.CFrame.Position-e.Base;local flat=math.sqrt(to.X*to.X+to.Z*to.Z)
  if flat>1 then
   local target=math.atan2(-to.X,-to.Z);e.Yaw=e.Yaw+wrap(target-e.Yaw)*(1-math.exp(-8*math.min(dt or 1/60,.1)))
  end
 end
 e.Card.CFrame=CFrame.new(e.Base+Vector3.new(0,math.sin(now*1.4)*.35,0))*CFrame.Angles(0,e.Yaw,0);e.Moved=true
 if e.Has then e.Marker.StudsOffsetWorldSpace=e.MarkerBase+Vector3.new(0,math.abs(math.sin(now*4.2))*1.6,0)end
end)
-- Re-count the Void Tools whenever Tools come and go in the Backpack or the Character (and once a second, in case an
-- attribute arrives late). A new Backpack / Character (respawn) is picked up as it appears.
local function watchContainer(container)
 if not container then return end
 watch(container.ChildAdded,refreshMarker);watch(container.ChildRemoved,refreshMarker)
end
watchContainer(player:FindFirstChildOfClass('Backpack'));watchContainer(player.Character)
watch(player.ChildAdded,function(child)if child:IsA('Backpack')then watchContainer(child);refreshMarker()end end)
watch(player.CharacterAdded,function(character)watchContainer(character);refreshMarker()end)
local alive=true
local function recount()if not alive then return end;refreshMarker();task.delay(1,recount)end
task.delay(1,recount)
-- The window ---------------------------------------------------------------------------------------------------------------------
local old=pg:FindFirstChild('VerityGui');if old then old:Destroy()end
local gui=new('ScreenGui',{Name='VerityGui',ResetOnSpawn=false,DisplayOrder=41,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
local shade=new('TextButton',{Name='Shade',Text='',AutoButtonColor=false,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=.48,BorderSizePixel=0,Visible=false},gui)
shade:SetAttribute('ButtonSound',false)
pcall(function()require(RS.MenuBackdrop).Attach(gui,shade,false)end)
local panel=new('Frame',{Name='VerityPanel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.94,.88),Visible=false,BorderSizePixel=0},gui);Bright.Panel(panel)
new('UISizeConstraint',{MaxSize=Vector2.new(660,450)},panel)
local header=new('Frame',{Name='Header',Size=UDim2.new(1,0,0,56),BorderSizePixel=0},panel);Bright.Header(header)
local title=text(header,'Title','🌟 VERITY',28);title.TextXAlignment=Enum.TextXAlignment.Left;title.Position=UDim2.fromOffset(18,2);title.Size=UDim2.new(1,-84,1,-4)
local closeX=new('TextButton',{Name='Close',Text='X',Position=UDim2.new(1,-52,0,7),Size=UDim2.fromOffset(42,42),BorderSizePixel=0,TextSize=20},header);Bright.Button(closeX,RGB(255,61,85))
-- Her picture (Fit keeps its own aspect), on the left when there is room.
local portrait=new('Frame',{Name='Portrait',BackgroundColor3=Theme.Colors.Inset,BorderSizePixel=0},panel);Theme.Corner(portrait,12);stroke(portrait,GOLD,2)
new('ImageLabel',{Name='Picture',BackgroundTransparency=1,Size=UDim2.new(1,-8,1,-8),Position=UDim2.fromOffset(4,4),Image=C.Image,ScaleType=Enum.ScaleType.Fit},portrait)
local quest=text(panel,'QuestText',C.Quest,20);quest.TextXAlignment=Enum.TextXAlignment.Left;quest.TextYAlignment=Enum.TextYAlignment.Center
local eventLine=text(panel,'EventLine','',16,VIOLET)
local function chip(name,color)
 local f=new('Frame',{Name=name,BackgroundColor3=Theme.Colors.Card,BorderSizePixel=0},panel);Theme.Corner(f,10);stroke(f,color,2)
 local caption=text(f,'Caption','',13,Theme.Colors.Muted);local value=text(f,'Count','0',22,color);return f,caption,value
end
local voidChip,voidCaption,voidCount=chip('VoidChip',VIOLET);voidCaption.Text='VOID PACKS YOU HAVE'
local doneChip,doneCaption,doneCount=chip('DeliveredChip',GOLD);doneCaption.Text='HANDED IN'
local rewardLine=text(panel,'RewardLine',C.RewardText,16,GOLD)
local status=text(panel,'Status','',16,MINT)
local give=new('TextButton',{Name='GiveButton',Text='',BorderSizePixel=0},panel);Bright.Button(give,GOLD)
local giveCaption=text(give,'Caption','GIVE VOID PACK',22);giveCaption.Size=UDim2.new(1,-16,1,0);giveCaption.Position=UDim2.fromOffset(8,0);giveCaption.ZIndex=12
new('UIScale',{Name='Pulse'},give)
local closeButton=new('TextButton',{Name='CloseButton',Text='',BorderSizePixel=0},panel);Bright.Button(closeButton,RGB(92,128,255))
local closeCaption=text(closeButton,'Caption','CLOSE',20);closeCaption.Size=UDim2.new(1,-8,1,0);closeCaption.Position=UDim2.fromOffset(4,0);closeCaption.ZIndex=12
local function tint(button,color)Bright.Gradient(button,color:Lerp(Color3.new(1,1,1),.24),color:Lerp(Color3.new(),.12),90)end
-- Layout (pixels from the panel's real size, so phones and computers both fit) ---------------------------------------------------
local function layout()
 local size=panel.AbsoluteSize;local W,H=size.X,size.Y;if W<=0 or H<=0 then return end
 local short=H<380
 local headH=short and 46 or 56;header.Size=UDim2.new(1,0,0,headH);title.TextSize=short and 22 or 28
 closeX.Position=UDim2.new(1,-(headH-6)-6,0,3);closeX.Size=UDim2.fromOffset(headH-6,headH-6)
 local pad=12;local top=headH+pad;local bodyH=H-top-pad
 local showPortrait=W>=560 and H>=330
 local pw=showPortrait and math.min(math.floor(bodyH*C.CardWidth/C.CardHeight),math.floor(W*.34))or 0
 portrait.Visible=showPortrait;portrait.Position=UDim2.fromOffset(pad,top);portrait.Size=UDim2.fromOffset(pw,bodyH)
 local cx=pad+(showPortrait and pw+pad or 0);local cw=W-cx-pad
 local gap=short and 6 or 10
 local eventH=short and 20 or 24;local chipH=short and 40 or 54;local rewardH=short and 20 or 24;local statusH=short and 20 or 24;local buttonH=short and 40 or 52
 local questH=math.max(40,bodyH-(eventH+chipH+rewardH+statusH+buttonH)-gap*5)
 local y=top
 quest.Position=UDim2.fromOffset(cx,y);quest.Size=UDim2.fromOffset(cw,questH);quest.TextSize=short and 16 or 20;y+=questH+gap
 eventLine.Position=UDim2.fromOffset(cx,y);eventLine.Size=UDim2.fromOffset(cw,eventH);eventLine.TextSize=short and 13 or 16;y+=eventH+gap
 local chipW=math.floor((cw-gap)/2)
 for i,spec in ipairs({{voidChip,voidCaption,voidCount},{doneChip,doneCaption,doneCount}})do
  spec[1].Position=UDim2.fromOffset(cx+(i-1)*(chipW+gap),y);spec[1].Size=UDim2.fromOffset(chipW,chipH)
  spec[2].Position=UDim2.fromOffset(4,2);spec[2].Size=UDim2.new(1,-8,0,math.floor(chipH*.38));spec[2].TextSize=short and 10 or 12
  spec[3].Position=UDim2.fromOffset(4,math.floor(chipH*.4));spec[3].Size=UDim2.new(1,-8,0,math.floor(chipH*.58));spec[3].TextSize=short and 18 or 24
 end
 y+=chipH+gap
 rewardLine.Position=UDim2.fromOffset(cx,y);rewardLine.Size=UDim2.fromOffset(cw,rewardH);rewardLine.TextSize=short and 13 or 16;y+=rewardH+gap
 status.Position=UDim2.fromOffset(cx,y);status.Size=UDim2.fromOffset(cw,statusH);status.TextSize=short and 13 or 16;y+=statusH+gap
 local giveW=math.floor((cw-gap)*.62)
 give.Position=UDim2.fromOffset(cx,y);give.Size=UDim2.fromOffset(giveW,buttonH);giveCaption.TextSize=short and 16 or 22
 closeButton.Position=UDim2.fromOffset(cx+giveW+gap,y);closeButton.Size=UDim2.fromOffset(cw-giveW-gap,buttonH);closeCaption.TextSize=short and 15 or 20
end
watch(panel:GetPropertyChangedSignal('AbsoluteSize'),layout)
-- State ------------------------------------------------------------------------------------------------------------------------
local state={Known=false,VoidPacks=0,Delivered=0}
local busy=false;local busySerial=0
local pulse
local function number(v)return type(v)=='number'and v==v and v>=0 and math.min(math.floor(v),1e9)or nil end
local function eventText()
 if state.EventActive==true then return'🌑 THE DARKENED IS HERE NOW!',VIOLET end
 if state.NextAt then
  local left=state.NextAt-workspace:GetServerTimeNow()
  if left>0 then return'🌑 THE DARKENED ARRIVES IN '..countdown(left),SKY end
  return'🌑 THE DARKENED IS ARRIVING...',SKY
 end
 return'',VIOLET
end
local function render()
 if pulse then pulse:Cancel();pulse=nil end;give.Pulse.Scale=1
 voidCount.Text=state.Known and tostring(state.VoidPacks)or'-';doneCount.Text=state.Known and tostring(state.Delivered)or'-'
 rewardLine.Text=state.RewardText or C.RewardText
 local line,color=eventText();eventLine.Text=line;eventLine.TextColor3=color;eventLine.Visible=line~=''
 local can=state.Known and state.VoidPacks>0 and not busy
 give.Active=can;give.Interactable=can;give.AutoButtonColor=can;give:SetAttribute('Enabled',can)
 tint(give,can and GOLD or RGB(96,104,140))
 giveCaption.Text=busy and'HANDING IT OVER...'or'GIVE VOID PACK'
 if can and not GuiService.ReducedMotionEnabled then
  pulse=Tween:Create(give.Pulse,TweenInfo.new(.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Scale=1.05});pulse:Play()
 end
 layout()
end
local function say(message,good)
 status.Text=message or'';status.TextColor3=good and MINT or RED
end
local function setBusy(value)
 busy=value;busySerial+=1
 if value then local serial=busySerial -- (a dropped request must not leave the button locked)
  task.delay(4,function()if busy and busySerial==serial then busy=false;render()end end)
 end
end
local ticking=false
local function open()
 panel.Visible=true;shade.Visible=true
 if pg:GetAttribute('SeedMenu')~='Verity'then pg:SetAttribute('SeedMenu','Verity')end
 render()
 if not ticking then ticking=true
  local function tick()
   if not panel.Visible or not gui.Parent then ticking=false;return end
   local line,color=eventText();eventLine.Text=line;eventLine.TextColor3=color;eventLine.Visible=line~=''
   task.delay(1,tick)
  end
  task.delay(1,tick)
 end
end
local function close()
 panel.Visible=false;shade.Visible=false;if pulse then pulse:Cancel();pulse=nil end
 if pg:GetAttribute('SeedMenu')=='Verity'then pg:SetAttribute('SeedMenu',nil)end
end
local function onServer(kind,payload)
 if type(payload)~='table'then payload={}end
 if kind=='Open'then
  state.Known=true;state.VoidPacks=number(payload.VoidPacks)or 0;state.Delivered=number(payload.Delivered)or 0
  state.RewardText=type(payload.RewardText)=='string'and payload.RewardText:sub(1,80)or nil
  state.EventActive=type(payload.EventActive)=='boolean'and payload.EventActive or nil
  state.NextAt=type(payload.NextAt)=='number'and payload.NextAt==payload.NextAt and payload.NextAt or nil
  setBusy(false);say('')
  open()
 elseif kind=='Done'then
  setBusy(false)
  state.Delivered=number(payload.Delivered)or state.Delivered+1;state.VoidPacks=math.max(0,state.VoidPacks-1)
  say(C.Thanks,true);Audio.Play('GemClaim')
  render()
  if not panel.Visible then open()end
 elseif kind=='Refused'then
  setBusy(false)
  say(type(payload.Reason)=='string'and payload.Reason:sub(1,90)or C.Reasons.Failed,false)
  if not panel.Visible then open()else render()end
 end
end
task.spawn(function()
 local remote=remotes:WaitForChild(C.RemoteName,60);if not remote or not gui.Parent then return end
 watch(remote.OnClientEvent,onServer)
 give.Activated:Connect(function()
  if not give.Active or busy then return end
  setBusy(true);say('');render()
  remote:FireServer('Give')
 end)
end)
closeX.Activated:Connect(close);closeButton.Activated:Connect(close);shade.Activated:Connect(close)
watch(pg:GetAttributeChangedSignal('SeedMenu'),function()
 if panel.Visible and pg:GetAttribute('SeedMenu')~='Verity'then panel.Visible=false;shade.Visible=false;if pulse then pulse:Cancel();pulse=nil end end
end)
render()
gui.Destroying:Connect(function()
 alive=false;if pulse then pulse:Cancel()end
 for _,c in ipairs(connections)do c:Disconnect()end
 if entry then if entry.Marker then entry.Marker:Destroy()end;entry=nil end
end)
