-- R123: treadmill bonus rolls (client view only). The server (TreadmillBonusService) counts treadmill time, owns the
-- READY count, decides every result and grants the pack before this script animates anything.
--  * "Next roll 6:12" progress bar above the player while on the treadmill (BillboardGui, local only).
--  * BONUS ROLL button (count badge at 2) placed clear of every HUD box (TreadmillBonusRules.Place over HudLayout).
--  * Crate-style strip: pack cards slide, click per card under the marker (max 30/s, pitch rises as it slows), ease to
--    a stop on the server's result; Legendary / Mythic get a flash, glow and fanfare. ReducedMotion: short spin.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local GuiService=game:GetService('GuiService');local Tween=game:GetService('TweenService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local Rules=require(RS:WaitForChild('TreadmillBonusRules'));local PackRules=require(RS:WaitForChild('SeedPackRules'))
local Layout=require(RS:WaitForChild('HudLayout'))
local remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild(Rules.RemoteName)
local function optional(name)
 local module=RS:FindFirstChild(name);if not module then return nil end
 local ok,value=pcall(require,module);return ok and value or nil
end
local Pictures=optional('ItemPictures');local Audio=optional('InteractionAudio');local Reveal=optional('RarityRevealAudio')
local Mixer=optional('AudioMixer');local Timing=optional('SoundTiming')
local RGB=Color3.fromRGB;local INK=RGB(10,14,28);local GOLD=RGB(255,206,72)
local connections={}
local function connect(signal,fn)local c=signal:Connect(fn);table.insert(connections,c);return c end
local function make(class,props,parent)
 local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o
end
local function round(o,r)make('UICorner',{CornerRadius=UDim.new(0,r)},o)end
local function stroke(o,color,width)return make('UIStroke',{Color=color,Thickness=width,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o)end
local function text(parent,name,value,size,color)
 return make('TextLabel',{Name=name,Text=value,TextSize=size,Font=Enum.Font.GothamBlack,TextColor3=color or Color3.new(1,1,1),
  TextStrokeColor3=INK,TextStrokeTransparency=.15,BackgroundTransparency=1,TextWrapped=true},parent)
end
local function fmt(seconds)seconds=math.max(0,math.ceil(seconds));return string.format('%d:%02d',seconds//60,seconds%60)end
local function biomeName(stage)return PackRules.DesignBiomes[stage]or'Biome'end
-- Sounds: an existing short UI click (InteractionAudio MenuClick id) in a small local pool so pitch can rise.
local tickVoices,tickIndex={},0
local function tickSound(pitch)
 local id=Audio and Audio.Asset and Audio.Asset('MenuClick');if not id then return end
 if #tickVoices==0 then
  for i=1,4 do
   local s=Instance.new('Sound');s.Name='Interaction_BonusTick'..i;s.SoundId=id;s.Volume=.22
   if Mixer then pcall(Mixer.Route,s,'Interface')end;s.Parent=game:GetService('SoundService');tickVoices[i]=s
  end
 end
 tickIndex=tickIndex%#tickVoices+1;local s=tickVoices[tickIndex]
 if not s.IsLoaded then return end
 s:Stop();s.PlaybackSpeed=pitch
 if Timing then Timing.Play(s)else s:Play()end
end
-- HUD button ---------------------------------------------------------------------------------------------------
local old=pg:FindFirstChild('TreadmillBonusHud');if old then old:Destroy()end
local hud=make('ScreenGui',{Name='TreadmillBonusHud',ResetOnSpawn=false,IgnoreGuiInset=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,
 DisplayOrder=26,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
local button=make('TextButton',{Name='BonusRollButton',Text='',AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,
 Visible=false,ZIndex=10},hud)
button:SetAttribute('AccessibleLabel','Treadmill bonus roll')
round(button,12);stroke(button,INK,3)
make('UIGradient',{Color=ColorSequence.new(RGB(255,228,110),RGB(255,140,40)),Rotation=90},button)
local pulse=make('UIScale',{Name='Pulse'},button)
local gift=text(button,'Icon','🎁',26);gift.ZIndex=11;gift.Size=UDim2.new(0,40,1,0);gift.Position=UDim2.fromOffset(6,0)
local title=text(button,'Title','BONUS ROLL',20);title.ZIndex=11;title.Size=UDim2.new(1,-54,.58,0);title.Position=UDim2.fromOffset(46,2)
local sub=text(button,'Sub','READY!',13,RGB(255,250,215));sub.ZIndex=11;sub.Size=UDim2.new(1,-54,.36,0);sub.Position=UDim2.new(0,46,.58,-2)
local badge=make('Frame',{Name='CountBadge',BackgroundColor3=RGB(232,48,72),Size=UDim2.fromOffset(30,30),AnchorPoint=Vector2.new(.5,.5),
 Position=UDim2.new(1,-4,0,4),ZIndex=12,Visible=false},button)
round(badge,15);stroke(badge,Color3.new(1,1,1),2)
local badgeText=text(badge,'Count','2',16);badgeText.Size=UDim2.fromScale(1,1);badgeText.ZIndex=13
local busy,rolling,messageUntil=false,false,0
local function ready()return Rules.ReadyCount(player:GetAttribute(Rules.Attr.Ready))end
local function refreshButton()
 local n=ready()
 button.Visible=n>0 and not rolling and pg:GetAttribute('TitleActive')~=true
 badge.Visible=n>=2;badgeText.Text=tostring(n)
 if os.clock()>=messageUntil then sub.Text=busy and'ROLLING...'or'READY!'end
end
local function layoutButton()
 local view=Layout.Viewport(hud);local w,h=view.X,view.Y
 local m=Layout.Read(view,game:GetService('UserInputService').TouchEnabled,Layout.Controls(hud))
 local r=Rules.Place(m,w,h,Layout.HudBoxes(m,w,h,true))
 button.Position=UDim2.fromOffset(r.X,r.Y);button.Size=UDim2.fromOffset(r.W,r.H)
 title.TextSize=r.H>=50 and 20 or 17
end
connect(hud:GetPropertyChangedSignal('AbsoluteSize'),layoutButton);task.defer(layoutButton)
local function flashMessage(message)
 messageUntil=os.clock()+2.5;sub.Text=message;refreshButton()
 task.delay(2.6,refreshButton)
end
-- Roll overlay ---------------------------------------------------------------------------------------------------
local oldRoll=pg:FindFirstChild('TreadmillBonusRoll');if oldRoll then oldRoll:Destroy()end
local overlay=make('ScreenGui',{Name='TreadmillBonusRoll',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=60,Enabled=false,
 ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
make('Frame',{Name='Backdrop',BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,Size=UDim2.fromScale(1,1),Active=true},overlay)
local panel=make('Frame',{Name='Panel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=RGB(30,36,74),ZIndex=2},overlay)
round(panel,14);local panelStroke=stroke(panel,GOLD,3)
make('UIGradient',{Color=ColorSequence.new(RGB(58,68,132),RGB(22,26,58)),Rotation=90},panel)
local heading=text(panel,'Title','🎁 TREADMILL BONUS ROLL',20,GOLD);heading.ZIndex=3;heading.Size=UDim2.new(1,-20,0,28);heading.Position=UDim2.fromOffset(10,8)
local window=make('Frame',{Name='StripWindow',BackgroundColor3=RGB(12,15,32),ClipsDescendants=true,ZIndex=3},panel)
round(window,10);stroke(window,RGB(90,100,170),2)
local strip=make('Frame',{Name='Strip',BackgroundTransparency=1,ZIndex=4},window)
make('Frame',{Name='Marker',BackgroundColor3=GOLD,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),
 Size=UDim2.new(0,4,1,0),ZIndex=8},window)
local arrowTop=text(window,'MarkerTop','▼',18,GOLD);arrowTop.ZIndex=9;arrowTop.AnchorPoint=Vector2.new(.5,0);arrowTop.Position=UDim2.new(.5,0,0,-4);arrowTop.Size=UDim2.fromOffset(24,20)
local arrowBottom=text(window,'MarkerBottom','▲',18,GOLD);arrowBottom.ZIndex=9;arrowBottom.AnchorPoint=Vector2.new(.5,1);arrowBottom.Position=UDim2.new(.5,0,1,4);arrowBottom.Size=UDim2.fromOffset(24,20)
local oddsLine=make('TextLabel',{Name='Odds',RichText=true,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),
 TextStrokeColor3=INK,TextStrokeTransparency=.3,TextWrapped=true,TextScaled=true,ZIndex=3},panel)
make('UITextSizeConstraint',{MaxTextSize=15,MinTextSize=9},oddsLine)
local poolLine=text(panel,'Pool','',12,RGB(200,210,255));poolLine.ZIndex=3;poolLine.Font=Enum.Font.GothamBold
local result=text(panel,'Result','',18);result.ZIndex=3
local actions=make('Frame',{Name='Actions',BackgroundTransparency=1,ZIndex=3},panel)
local function action(name,caption,color)
 local b=make('TextButton',{Name=name,Text=caption,TextSize=16,Font=Enum.Font.GothamBlack,TextColor3=Color3.new(1,1,1),TextStrokeColor3=INK,
  TextStrokeTransparency=.2,BackgroundColor3=color,AutoButtonColor=true,ZIndex=4,Visible=false},actions)
 round(b,8);stroke(b,INK,2);return b
end
local skipButton=action('Skip','SKIP',RGB(90,100,150));local closeButton=action('Close','CLOSE',RGB(90,100,150))
local againButton=action('Again','ROLL AGAIN',RGB(236,140,40))
local flash=make('Frame',{Name='Flash',BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=20,Active=false},panel)
round(flash,14)
local function oddsText()
 local parts={}
 for _,row in ipairs(Rules.OddsRows())do
  local c=row.Color;table.insert(parts,string.format('<font color="#%02X%02X%02X">%s %s</font>',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5),row.Name,row.Text))
 end
 return table.concat(parts,'  ·  ')
end
local function poolText(stages)
 local names={};for _,s in ipairs(stages)do table.insert(names,biomeName(s))end
 return 'Packs from: '..table.concat(names,', ')..(#stages>1 and(' (each '..Rules.Percent(1/#stages)..')')or'')
end
local panelW,cardH=600,128
local function layoutOverlay()
 local view=overlay.AbsoluteSize;local w,h=view.X>0 and view.X or 1280,view.Y>0 and view.Y or 720
 panelW=math.floor(math.min(w-24,640));local short=h<420
 cardH=short and 104 or 128
 local panelH=(short and 248 or 300)
 panel.Size=UDim2.fromOffset(panelW,math.min(h-16,panelH))
 window.Position=UDim2.fromOffset(12,40);window.Size=UDim2.new(1,-24,0,cardH+16)
 oddsLine.Position=UDim2.fromOffset(12,40+cardH+22);oddsLine.Size=UDim2.new(1,-24,0,short and 18 or 22)
 poolLine.Position=UDim2.fromOffset(12,40+cardH+(short and 42 or 46));poolLine.Size=UDim2.new(1,-24,0,16)
 result.Position=UDim2.fromOffset(12,40+cardH+(short and 60 or 66));result.Size=UDim2.new(1,-24,0,24)
 actions.Position=UDim2.new(0,12,1,-(short and 46 or 52));actions.Size=UDim2.new(1,-24,0,short and 38 or 42)
 local bw=math.floor(math.min(170,(panelW-24-16)/3))
 skipButton.Size=UDim2.fromOffset(bw,actions.Size.Y.Offset);skipButton.Position=UDim2.new(.5,-bw/2,0,0)
 closeButton.Size=skipButton.Size;closeButton.Position=UDim2.new(.5,-bw-6,0,0)
 againButton.Size=skipButton.Size;againButton.Position=UDim2.new(.5,6,0,0)
end
connect(overlay:GetPropertyChangedSignal('AbsoluteSize'),layoutOverlay);layoutOverlay()
local cards={};local spin,spinConn,current
local function clearCards()
 for _,c in ipairs(cards)do if Pictures then pcall(Pictures.Clear,c.Holder)end;c.Frame:Destroy()end;table.clear(cards)
end
local function buildCard(i,pack)
 local tierName,color=Rules.Tier(pack.Variant)
 local f=make('Frame',{Name='Card'..i,BackgroundColor3=color:Lerp(RGB(16,20,44),.62),Position=UDim2.fromOffset((i-1)*Rules.Strip.Pitch,8),
  Size=UDim2.fromOffset(Rules.Strip.CardWidth,cardH),ZIndex=5},strip)
 round(f,9);local edge=stroke(f,color,3)
 make('UIGradient',{Color=ColorSequence.new(Color3.new(1,1,1),RGB(150,150,170)),Rotation=90},f)
 local holder=make('Frame',{Name='Picture',BackgroundTransparency=1,Position=UDim2.fromOffset(6,4),Size=UDim2.new(1,-12,1,-40),ZIndex=6},f)
 if Pictures then
  local proxy=Instance.new('Folder');proxy:SetAttribute('SeedPackTool',true);proxy:SetAttribute('Stage',pack.Stage)
  proxy:SetAttribute('BagVariant',pack.Variant);proxy:SetAttribute('PackMutation','None')
  pcall(Pictures.Show,holder,proxy,2)
 else
  local icon=text(holder,'Icon','🎒',34);icon.Size=UDim2.fromScale(1,1);icon.ZIndex=6
 end
 local name=text(f,'Rarity',string.upper(tierName),13,color);name.ZIndex=7;name.Size=UDim2.new(1,-6,0,16);name.Position=UDim2.new(0,3,1,-35)
 local biome=text(f,'Biome',biomeName(pack.Stage),11,RGB(225,230,255));biome.ZIndex=7;biome.Font=Enum.Font.GothamBold
 biome.Size=UDim2.new(1,-6,0,14);biome.Position=UDim2.new(0,3,1,-18)
 local entry={Frame=f,Holder=holder,Stroke=edge,Pack=pack,Tier=tierName,Color=color};cards[i]=entry;return entry
end
local function place(offset)
 local center=window.AbsoluteSize.X>0 and window.AbsoluteSize.X/2 or(panelW-24)/2
 strip.Position=UDim2.fromOffset(math.floor(center-Rules.Strip.CardWidth/2-offset+.5),0)
end
local finish
local function stopSpin()if spinConn then spinConn:Disconnect();spinConn=nil end end
local function celebrate(entry,res)
 local special=Rules.Special[res.Rarity]==true
 result.Text=(special and'✨ 'or'')..'You got a '..string.upper(res.Rarity)..' '..(res.Label or'pack')..'!'
 result.TextColor3=entry.Color
 if Audio then pcall(Audio.Play,special and'GemClaim'or'KaChing')end
 local reduced=GuiService.ReducedMotionEnabled
 if not reduced then
  local grow=make('UIScale',{Scale=1},entry.Frame);Tween:Create(grow,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.08}):Play()
 end
 if special then
  if Reveal then pcall(function()Reveal.Preload();Reveal.Play(res.Rarity=='Mythic'and'Impact'or'Chime',res.Rarity=='Mythic'and 1.1 or .8)
   if res.Rarity=='Mythic'then Reveal.Play('Chime',.7)end end)end
  flash.BackgroundColor3=entry.Color:Lerp(Color3.new(1,1,1),.55);flash.BackgroundTransparency=reduced and .7 or .15
  Tween:Create(flash,TweenInfo.new(reduced and .25 or .7,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1}):Play()
  entry.Stroke.Thickness=5;panelStroke.Color=entry.Color
  if not reduced then
   local glow=make('UIStroke',{Name='Glow',Color=entry.Color,Thickness=10,Transparency=.2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},entry.Holder)
   Tween:Create(glow,TweenInfo.new(.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,3,true),{Transparency=.85}):Play()
  end
 end
end
finish=function()
 if not spin or not current then return end
 local offset=spin:Skip();place(offset);stopSpin()
 local entry=cards[spin.Win];if entry then celebrate(entry,current)end
 skipButton.Visible=false;closeButton.Visible=true;againButton.Visible=ready()>0
 againButton.Text='ROLL AGAIN ('..ready()..')'
end
local function startRoll(res)
 rolling=true;refreshButton();clearCards();stopSpin()
 current=res;overlay.Enabled=true;layoutOverlay()
 panelStroke.Color=GOLD;flash.BackgroundTransparency=1;result.Text='';result.TextColor3=Color3.new(1,1,1)
 local stages=Rules.DecodePool(res.Pool);if #stages==0 then stages={res.Stage}end
 oddsLine.Text=oddsText();poolLine.Text=poolText(stages)
 local winner={Stage=res.Stage,Variant=res.Variant}
 local rng=Random.new()
 for i,pack in ipairs(Rules.BuildStrip(stages,winner,function()return rng:NextNumber()end))do buildCard(i,pack)end
 strip.Size=UDim2.fromOffset(#cards*Rules.Strip.Pitch,cardH+16)
 spin=Rules.NewSpin({Reduced=GuiService.ReducedMotionEnabled,Jitter=rng:NextNumber(-.3,.3)})
 place(spin.Offset)
 skipButton.Visible=true;closeButton.Visible=false;againButton.Visible=false
 spinConn=Run.RenderStepped:Connect(function(dt)
  local offset,tick,pitch,done=spin:Step(dt);place(offset)
  if tick then tickSound(pitch)end
  if done then finish()end
 end)
end
local function close()
 stopSpin();if spin and not spin.Done then finish()end
 overlay.Enabled=false;rolling=false;clearCards();current=nil;spin=nil;refreshButton()
end
local function requestRoll()
 if busy then return end
 busy=true;refreshButton()
 task.spawn(function()
  local ok,res=pcall(function()return remote:InvokeServer()end)
  busy=false
  if not ok or type(res)~='table'then flashMessage('TRY AGAIN!');return end
  if not res.Ok then flashMessage(string.upper(tostring(res.Error or'TRY AGAIN')));return end
  if type(res.Stage)~='number'or type(res.Variant)~='string'or type(res.Rarity)~='string'then flashMessage('TRY AGAIN!');return end
  startRoll(res)
 end)
end
connect(button.Activated,requestRoll)
connect(skipButton.Activated,finish)
connect(closeButton.Activated,close)
connect(againButton.Activated,function()close();requestRoll()end)
-- Progress bar above the player while on the treadmill ------------------------------------------------------------
local oldBar=pg:FindFirstChild('TreadmillBonusProgress');if oldBar then oldBar:Destroy()end
local bar=make('BillboardGui',{Name='TreadmillBonusProgress',Size=UDim2.fromOffset(168,40),AlwaysOnTop=true,LightInfluence=0,MaxDistance=80,
 ResetOnSpawn=false,Enabled=false},pg)
local back=make('Frame',{Name='Back',BackgroundColor3=INK,BackgroundTransparency=.2,Size=UDim2.fromScale(1,1)},bar)
round(back,10);stroke(back,GOLD,2)
local fill=make('Frame',{Name='Fill',BackgroundColor3=RGB(255,170,50),Position=UDim2.fromOffset(3,3),Size=UDim2.new(0,0,1,-6)},back)
round(fill,8);make('UIGradient',{Color=ColorSequence.new(RGB(255,226,110),RGB(255,140,40)),Rotation=90},fill)
local barText=text(back,'Label','',15);barText.Size=UDim2.fromScale(1,1);barText.ZIndex=3
local function barState(now)
 local n=ready();local interval=tonumber(player:GetAttribute(Rules.Attr.Interval))or Rules.IntervalSeconds
 if n>=Rules.MaxReady then return 1,'🎁 '..n..' rolls ready - claim!'end
 local due=tonumber(player:GetAttribute(Rules.Attr.DueAt))
 local left=due and due-now or tonumber(player:GetAttribute(Rules.Attr.Left))or interval
 left=math.clamp(left,0,interval)
 return 1-left/interval,'🎁 Next roll '..fmt(left)
end
local acc=0
local function refreshBar()
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local head=character and character:FindFirstChild('Head')
 local on=player:GetAttribute('TreadmillTraining')==true and root~=nil
 bar.Enabled=on
 if not on then return end
 bar.Adornee=root
 -- Above the head and clear of the rising speed popups (they top out ~4.6 studs over the head).
 bar.StudsOffsetWorldSpace=Vector3.new(0,(head and head.Position.Y-root.Position.Y or 1.5)+5.4,0)
 local fraction,label=barState(workspace:GetServerTimeNow())
 fill.Size=UDim2.new(math.clamp(fraction,0,1),-6*math.clamp(fraction,0,1),1,-6);barText.Text=label
end
connect(Run.Heartbeat,function(dt)acc+=dt;if acc>=.25 then acc=0;refreshBar()end end)
-- Button pulse only while visible (and never with ReducedMotion).
local clock=0
connect(Run.RenderStepped,function(dt)
 if not button.Visible or GuiService.ReducedMotionEnabled then if pulse.Scale~=1 then pulse.Scale=1 end;return end
 clock+=dt;pulse.Scale=1+.04*math.sin(clock*4)
end)
for _,key in ipairs({Rules.Attr.Ready,Rules.Attr.DueAt,Rules.Attr.Left,'TreadmillTraining'})do
 connect(player:GetAttributeChangedSignal(key),function()refreshButton();refreshBar()end)
end
connect(pg:GetAttributeChangedSignal('TitleActive'),refreshButton)
refreshButton();refreshBar()
script.Destroying:Connect(function()
 stopSpin();for _,c in ipairs(connections)do c:Disconnect()end;table.clear(connections)
 hud:Destroy();overlay:Destroy();bar:Destroy()
end)
