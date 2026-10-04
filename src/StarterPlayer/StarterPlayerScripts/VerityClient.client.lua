-- R147 (owner: "Verity NPC is a quest giver: it tells players to steal a pack from The Darkened one and give it to the
-- Verity NPC. The Verity NPC will be behind the market and it will be big."): the client half of VerityService.
-- R148 (owner's play test, "Verity should be a big yellow sphere", and her greeting voice):
--  * Her Body (a big yellow ball with her smiley as a Decal) turns to face the camera on this client, bobs a little, and swells
--    while she talks (all of it cosmetic and local; none with ReducedMotion).
--  * A marker over her head, in the same sign as her name: a "!" normally, a bouncing gold "?" while you carry a Void Pack
--    (a Backpack / Character Tool with SeedPackTool and BagVariant 'EclipseReliquary').
--  * Her greeting (VerityConfig.GreetingSoundId) plays from her body, 3D, through the Effects volume setting: when you open her
--    dialog with Talk, and once when you first come within GreetingDistance of her (at most once a minute; a Talk greeting counts).
--    Never two copies at once; an asset that fails to load is warned about once and skipped.
--  * Talk to her (the server answers the prompt with 'Open') and a window shows her quest, her picture, how many Void Packs you
--    have, how many you handed in, when The Darkened is here / comes, the exchange as pictures (Void Pack -> Verity Pack, the
--    game's own 3D pack pictures, like the hotbar) and the GIVE VOID PACK button (only with a Void Pack).
--    'Done' = thanks + a sound, 'Refused' = the reason. PlayerGui.SeedMenu = 'Verity' while it is open.
-- The server owns every rule; this only sends 'Give' (no arguments) and shows what it is told.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local Tween=game:GetService('TweenService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local remotes=RS:WaitForChild('ChestChaseRemotes')
local C=require(RS:WaitForChild('VerityConfig'));local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI);local Audio=require(RS.InteractionAudio)
local Pictures;pcall(function()Pictures=require(RS.ItemPictures)end)
local Mixer;pcall(function()Mixer=require(RS.AudioMixer)end)
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
local function wrap(angle)return(angle+math.pi)%(math.pi*2)-math.pi end
-- Her voice -------------------------------------------------------------------------------------------------------------------
-- One Sound on her body (3D, rolled off by distance, routed to the Effects group so the player's Effects volume applies).
local voice={Playing=false,Until=0,LastAt=-math.huge,Failed=false,Warned=false,Sound=nil,Checked=false,Plays=0}
local entry=nil
local function failVoice(why)
 voice.Failed=true
 if not voice.Warned then voice.Warned=true;warn('[R148] Verity\'s greeting could not be loaded ('..tostring(C.GreetingSoundId)..'): '..tostring(why))end
end
local function voiceSound(e)
 local s=voice.Sound
 if s and s.Parent==e.Body then return s end
 if s then s:Destroy();voice.Sound=nil;voice.Checked=false end
 s=new('Sound',{Name='VerityGreeting',SoundId=C.GreetingSoundId,Volume=C.GreetingVolume,Looped=false,RollOffMode=Enum.RollOffMode.InverseTapered,
  RollOffMinDistance=C.GreetingRollOffMin,RollOffMaxDistance=C.GreetingRollOffMax},e.Body)
 if Mixer then pcall(Mixer.Route,s,'Effects')end
 watch(s.Ended,function()voice.Playing=false end)
 voice.Sound=s
 -- Ask for the asset now so a bad id is found (and warned about once) before anyone waits for her to speak.
 if not voice.Checked then
  voice.Checked=true
  task.spawn(function()
   local okService,content=pcall(game.GetService,game,'ContentProvider')
   if not okService or not content or type(content.PreloadAsync)~='function'then return end
   pcall(content.PreloadAsync,content,{s},function(id,status)
    if status~=nil and status~=Enum.AssetFetchStatus.Success then failVoice('asset fetch '..tostring(status.Name or status))end
   end)
  end)
 end
 return s
end
-- True while a greeting is playing (the Sound's Ended clears it; a copy that never ends is given up on after its length + .5 s, or 8 s).
local function speaking()return voice.Playing and os.clock()<voice.Until end
-- kind: 'talk' (her dialog opened) or 'near' (you came close). Returns true when she started speaking.
local function greet(kind)
 local e=entry;if not e or not e.Body.Parent or voice.Failed then return false end
 if Mixer and Mixer.Get('Effects')==0 then return false end -- the player turned effects off: no voice, no swelling
 local now=os.clock()
 if speaking()then return false end -- never two copies at once
 local s=voiceSound(e);if not s or voice.Failed then return false end
 local ok=pcall(function()s.TimePosition=0;s:Play()end)
 if not ok then failVoice('Play failed');return false end
 voice.Playing=true;voice.Until=now+((s.TimeLength or 0)>0 and s.TimeLength+.5 or 8);voice.LastAt=now;voice.Plays+=1;voice.Kind=kind
 return true
end
-- Her body and the marker ---------------------------------------------------------------------------------------------------------
local MARK_REST=UDim2.fromScale(.5,.27)
local function refreshMarker()
 local e=entry;if not e or not e.Mark.Parent then return end
 local has=countVoidTools()>0
 e.Mark.Text=has and'?'or'!';e.Mark.TextColor3=has and GOLD or Color3.new(1,1,1)
 e.Sign:SetAttribute('Bounce',has);e.Sign:SetAttribute('HasVoidPack',has);e.Has=has
 if not has then e.Mark.Position=MARK_REST end
end
local function build(model,body)
 local sign=body:FindFirstChild('NameSign')
 if not sign then
  local waiting;waiting=body.ChildAdded:Connect(function(child)if child.Name=='NameSign'then waiting:Disconnect();if model.Parent and not entry then build(model,body)end end end)
  connections[#connections+1]=waiting;return
 end
 local mark=new('TextLabel',{Name='Mark',BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=MARK_REST,Size=UDim2.fromScale(.5,.54),Font=Enum.Font.FredokaOne,TextScaled=true,
  Text='!',TextColor3=Color3.new(1,1,1),TextStrokeColor3=RGB(40,22,70),TextStrokeTransparency=0},sign)
 local look=body.CFrame.LookVector;local yaw=math.atan2(-look.X,-look.Z)
 entry={Model=model,Body=body,Sign=sign,Mark=mark,Home=body.CFrame,Base=body.Position,Size=body.Size.X,Yaw=yaw,Yaw0=yaw,Has=false,Moved=false,Talk=0,Scale=1,Poll=1,Near=nil}
 refreshMarker()
end
local function attach(model)
 if entry and entry.Model==model then return end
 if not model:IsA('Model')then return end
 local body=model:FindFirstChild('Body')
 if body then build(model,body);return end
 local waiting;waiting=model.ChildAdded:Connect(function(child)if child.Name=='Body'then waiting:Disconnect();if model.Parent and not entry then build(model,child)end end end)
 connections[#connections+1]=waiting
end
local function detach(model)
 if entry and entry.Model==model then
  if entry.Mark then entry.Mark:Destroy()end
  if voice.Sound then voice.Sound:Destroy();voice.Sound=nil;voice.Checked=false;voice.Playing=false end
  entry=nil
 end
end
for _,model in ipairs(CS:GetTagged(C.Tag))do attach(model)end
watch(CS:GetInstanceAddedSignal(C.Tag),attach);watch(CS:GetInstanceRemovedSignal(C.Tag),detach)
do -- (the model may already be in the map without the tag having replicated yet)
 local map=workspace:FindFirstChild('ChestChaseMap');local hub=map and map:FindFirstChild('EconomyHub');local model=hub and hub:FindFirstChild(C.ModelName)
 if model then attach(model)end
end
-- Each frame: turn to the camera, bob, swell while she talks, bounce the "?"; four times a second, greet whoever came close.
local function playerRoot()
 local character=player.Character;return character and character:FindFirstChild('HumanoidRootPart')
end
watch(Run.RenderStepped,function(dt)
 local e=entry;if not e or not e.Body.Parent then return end
 dt=math.min(dt or 1/60,.1)
 -- Proximity greeting: only on coming within range (not while standing there), at most once a GreetingCooldown.
 e.Poll+=dt
 if e.Poll>=.25 then
  e.Poll=0
  local root=playerRoot()
  if root then
   local near=(root.Position-e.Base).Magnitude<=C.GreetingDistance
   if near and e.Near~=true and os.clock()-voice.LastAt>=C.GreetingCooldown then greet('near')end
   e.Near=near
  end
 end
 if GuiService.ReducedMotionEnabled then
  if e.Moved then -- back to how the server placed her
   e.Moved=false;e.Yaw=e.Yaw0;e.Talk=0;e.Scale=1;e.Body.Size=Vector3.new(e.Size,e.Size,e.Size);e.Body.CFrame=e.Home
   if e.Mark.Parent then e.Mark.Position=MARK_REST end
  end
  return
 end
 local now=os.clock()
 local camera=workspace.CurrentCamera
 if camera then
  local to=camera.CFrame.Position-e.Base;local flat=math.sqrt(to.X*to.X+to.Z*to.Z)
  if flat>1 then
   local target=math.atan2(-to.X,-to.Z);e.Yaw=e.Yaw+wrap(target-e.Yaw)*(1-math.exp(-8*dt))
  end
 end
 -- Swelling while the voice plays (smoothed in and out); she grows upward from the dais.
 local want=speaking()and 1 or 0
 e.Talk+=(want-e.Talk)*(1-math.exp(-10*dt));if want==0 and e.Talk<.002 then e.Talk=0 end
 local scale=1+C.TalkPulse*e.Talk*(.5+.5*math.sin(now*C.TalkPulseRate))
 if scale~=e.Scale then e.Scale=scale;local d=e.Size*scale;e.Body.Size=Vector3.new(d,d,d)end
 local lift=e.Size*(scale-1)/2
 e.Body.CFrame=CFrame.new(e.Base+Vector3.new(0,math.sin(now*1.4)*C.FootOffset+lift,0))*CFrame.Angles(0,e.Yaw,0);e.Moved=true
 if e.Has and e.Mark.Parent then e.Mark.Position=UDim2.new(.5,0,.27,-math.abs(math.sin(now*4.2))*14)end
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
-- Verity herself: a big yellow ball with her smiley, standing on a little gold dais (a round frame with the picture on top).
local portrait=new('Frame',{Name='Portrait',BackgroundColor3=Theme.Colors.Inset,BorderSizePixel=0},panel);Theme.Corner(portrait,12);stroke(portrait,GOLD,2)
local daisShadow=new('Frame',{Name='Dais',AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=GOLD,BackgroundTransparency=.35,BorderSizePixel=0},portrait);Theme.Corner(daisShadow,40)
local ball=new('Frame',{Name='Ball',AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},portrait);new('UICorner',{CornerRadius=UDim.new(.5,0)},ball)
Bright.Gradient(ball,RGB(255,255,170),RGB(255,232,0),55);ball.BackgroundColor3=Color3.new(1,1,1);stroke(ball,RGB(255,180,40),3)
new('ImageLabel',{Name='Picture',BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.86,.86),Image=C.Image,ScaleType=Enum.ScaleType.Fit},ball)
local quest=text(panel,'QuestText',C.Quest,20);quest.TextXAlignment=Enum.TextXAlignment.Left;quest.TextYAlignment=Enum.TextYAlignment.Center
local eventLine=text(panel,'EventLine','',16,VIOLET)
local function chip(name,color)
 local f=new('Frame',{Name=name,BackgroundColor3=Theme.Colors.Card,BorderSizePixel=0},panel);Theme.Corner(f,10);stroke(f,color,2)
 local caption=text(f,'Caption','',13,Theme.Colors.Muted);local value=text(f,'Count','0',22,color);return f,caption,value
end
local voidChip,voidCaption,voidCount=chip('VoidChip',VIOLET);voidCaption.Text='VOID PACKS YOU HAVE'
local doneChip,doneCaption,doneCount=chip('DeliveredChip',GOLD);doneCaption.Text='HANDED IN'
-- The exchange as pictures: [Void Pack] -> [Verity Pack] and "1 VOID PACK = 1 VERITY PACK" (real 3D pack pictures, like the hotbar).
local exchange=new('Frame',{Name='Exchange',BackgroundTransparency=1,BorderSizePixel=0},panel)
local function packHolder(name,color)
 local h=new('Frame',{Name=name,BackgroundColor3=Theme.Colors.Inset,BorderSizePixel=0},exchange);Theme.Corner(h,10);stroke(h,color,2);return h
end
local voidHolder=packHolder('VoidPack',VIOLET);local verityHolder=packHolder('VerityPack',GOLD)
local arrow=text(exchange,'Arrow','➜',30,GOLD);arrow.TextWrapped=false
local rewardLine=text(exchange,'RewardLine',C.RewardText,16,GOLD)
local function showPack(holder,variant,fallback)
 local shown=false
 if Pictures then
  local proxy=Instance.new('Folder');proxy:SetAttribute('SeedPackTool',true);proxy:SetAttribute('Stage',C.PackStage);proxy:SetAttribute('BagVariant',variant);proxy:SetAttribute('PackMutation','None')
  shown=pcall(Pictures.Show,holder,proxy,1)
 end
 if not shown then local e=text(holder,'Emoji',fallback,28);e.Size=UDim2.fromScale(1,1);e.TextScaled=true end
end
showPack(voidHolder,C.VoidVariant,'🌑');showPack(verityHolder,C.VerityVariant,'🌟')
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
 local pw=showPortrait and math.min(bodyH,math.floor(W*.34))or 0
 portrait.Visible=showPortrait;portrait.Position=UDim2.fromOffset(pad,top);portrait.Size=UDim2.fromOffset(pw,bodyH)
 local ballSize=math.max(0,pw-24);ball.Size=UDim2.fromOffset(ballSize,ballSize);ball.Position=UDim2.new(.5,0,.5,-math.floor(ballSize*.04))
 daisShadow.Size=UDim2.fromOffset(math.floor(ballSize*.8),math.max(8,math.floor(ballSize*.12)));daisShadow.Position=UDim2.new(.5,0,.5,math.floor(ballSize*.5))
 local cx=pad+(showPortrait and pw+pad or 0);local cw=W-cx-pad
 local gap=short and 6 or 10
 local eventH=short and 20 or 24;local chipH=short and 34 or 54;local exH=short and 46 or 66;local statusH=short and 18 or 24;local buttonH=short and 38 or 52
 local questH=math.max(40,bodyH-(eventH+chipH+exH+statusH+buttonH)-gap*5)
 local y=top
 quest.Position=UDim2.fromOffset(cx,y);quest.Size=UDim2.fromOffset(cw,questH);quest.TextSize=short and 16 or 20;y+=questH+gap
 eventLine.Position=UDim2.fromOffset(cx,y);eventLine.Size=UDim2.fromOffset(cw,eventH);eventLine.TextSize=short and 13 or 16;y+=eventH+gap
 local chipW=math.floor((cw-gap)/2)
 for i,spec in ipairs({{voidChip,voidCaption,voidCount},{doneChip,doneCaption,doneCount}})do
  spec[1].Position=UDim2.fromOffset(cx+(i-1)*(chipW+gap),y);spec[1].Size=UDim2.fromOffset(chipW,chipH)
  spec[2].Position=UDim2.fromOffset(4,2);spec[2].Size=UDim2.new(1,-8,0,math.floor(chipH*.38));spec[2].TextSize=short and 10 or 12
  spec[3].Position=UDim2.fromOffset(4,math.floor(chipH*.4));spec[3].Size=UDim2.new(1,-8,0,math.floor(chipH*.58));spec[3].TextSize=short and 16 or 24
 end
 y+=chipH+gap
 -- The exchange row: two square pack pictures with an arrow between, then the rule in words.
 exchange.Position=UDim2.fromOffset(cx,y);exchange.Size=UDim2.fromOffset(cw,exH)
 local arrowW=math.max(28,math.floor(exH*.5));local pic=math.min(exH,math.floor((cw-arrowW-12-90)/2))
 voidHolder.Position=UDim2.fromOffset(0,math.floor((exH-pic)/2));voidHolder.Size=UDim2.fromOffset(pic,pic)
 arrow.Position=UDim2.fromOffset(pic+4,0);arrow.Size=UDim2.fromOffset(arrowW,exH);arrow.TextSize=short and 22 or 30
 verityHolder.Position=UDim2.fromOffset(pic+arrowW+8,math.floor((exH-pic)/2));verityHolder.Size=UDim2.fromOffset(pic,pic)
 local rx=pic*2+arrowW+8+10
 rewardLine.Position=UDim2.fromOffset(rx,0);rewardLine.Size=UDim2.fromOffset(math.max(10,cw-rx),exH);rewardLine.TextSize=short and 13 or 16
 y+=exH+gap
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
  greet('talk')
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
 if Pictures then pcall(Pictures.Clear,voidHolder);pcall(Pictures.Clear,verityHolder)end
 if entry then
  if entry.Mark then entry.Mark:Destroy()end
  if entry.Moved and entry.Body.Parent then entry.Body.Size=Vector3.new(entry.Size,entry.Size,entry.Size);entry.Body.CFrame=entry.Home end -- leave her as the server placed her
  if voice.Sound then voice.Sound:Destroy();voice.Sound=nil end
  entry=nil
 end
end)
