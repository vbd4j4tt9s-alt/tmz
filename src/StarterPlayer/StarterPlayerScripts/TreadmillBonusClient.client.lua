do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R123: treadmill bonus rolls (client view only). The server (TreadmillBonusService) counts treadmill time, owns the
-- READY count, decides every result and grants the pack before this script animates anything.
--  * BONUS ROLL button placed clear of every HUD box (TreadmillBonusRules.Place over HudLayout): a chunky candy pill that is
--    cheerful when a roll is READY (the pack wiggles, shine sweeps, count badge pops) and calm while charging on the treadmill
--    (it shows the progress and the countdown itself).
--  * Roll screen: gift-wrap panel with a bow on the ribbon header, crate-style strip of rarity-framed pack cards (click per
--    card under the bouncing pointers, pitch rises as it slows, eases to the server's result), rays behind the winner, a
--    rarity-scaled reveal word, confetti, border light-up and fanfare for Legendary / Mythic / Secret.
-- R150 (owner: "polish the bonus roll button, the bonus gift timer and the bonus roll screen with design and personality"):
-- looks and copy only. Timing, ticks, results, odds, placement and the server are unchanged. Shapes: BonusGiftArt; copy and
-- states: TreadmillBonusStyle. Motion: one on-demand RenderStepped (only while something is moving, nothing while idle);
-- ReducedMotion = no ambient motion and a short spin; FastMode / low quality = no sweeps, rotating rays or twinkles and
-- fewer pieces.
-- R153 (owner): no bag hint line under the spin text (it is centred now), a Secret pack card flies by on the reel on every
-- roll (TreadmillBonusStyle.Tease, a few cards before the winner; presentation only: odds and the awarded pack are the server's, unchanged)
-- and no gift timer pill over the player's head any more (the HUD button's charging look carries the countdown).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local GuiService=game:GetService('GuiService');local Tween=game:GetService('TweenService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local Rules=require(RS:WaitForChild('TreadmillBonusRules'));local PackRules=require(RS:WaitForChild('SeedPackRules'))
local Layout=require(RS:WaitForChild('HudLayout'))
local Style=require(RS:WaitForChild('TreadmillBonusStyle'));local Art=require(RS:WaitForChild('BonusGiftArt'))
local remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild(Rules.RemoteName)
local function optional(name)
 local module=RS:FindFirstChild(name);if not module then return nil end
 local ok,value=pcall(require,module);return ok and value or nil
end
local Pictures=optional('ItemPictures');local Audio=optional('InteractionAudio');local Reveal=optional('RarityRevealAudio')
local Mixer=optional('AudioMixer');local Timing=optional('SoundTiming');local Notices=optional('HudNoticeLayout');local Budget=optional('ClientFxBudget')
local RareAudio=optional('RarePullAudio') -- R151: the Secret pull sting (RarePullSounds.SecretGlitch) under a Secret result's fanfare
local RGB=Color3.fromRGB;local INK=Art.INK;local GOLD=Art.GOLD;local WHITE=Art.WHITE
-- R153: the owner's pack picture (embedded data drawn with an EditableImage, one shared copy) in place of the gift icon; the plain drawn pack until / unless it can be drawn.
local EmbeddedImage=optional('EmbeddedImage153');local PackData=optional('BonusPackImage153')
local function showPack(icon)
 if not(EmbeddedImage and PackData)then return end
 EmbeddedImage.Show(icon.Picture,PackData,function(route)
  if route=='image'then icon.Picture.Visible=true;if icon.Drawn.Parent then icon.Drawn:Destroy()end else icon.Picture.Visible=false end
 end)
end
local connections={};local dead=false
local function connect(signal,fn)local c=signal:Connect(fn);table.insert(connections,c);return c end
local make,round,pill,stroke,text=Art.make,Art.round,Art.pill,Art.stroke,Art.text
local function biomeName(stage)return PackRules.DesignBiomes[stage]or'Biome'end
local function reduced()
 local ok,value=pcall(function()return GuiService.ReducedMotionEnabled end)
 return ok and value==true
end
-- FastMode / low graphics: keep the look, drop the extras (sweeps, rotating rays, twinkles) and thin out the pieces.
local function lite()
 if player:GetAttribute('FastMode')==true then return true end
 local mode=player:GetAttribute('StudioPlantEffects');if mode=='off'or mode=='low'then return true end
 if Budget then local ok,tier=pcall(Budget.Get);if ok and tier==1 then return true end end
 return false
end
-- One animator: a single RenderStepped connection that exists only while at least one effect is running. An effect is a
-- function(dt) that returns true when it is finished.
local addEffect,cancelEffect,spawnBurst,clearBursts,clearEffects
do
 local effects={};local effectConnection;local liveBursts={}
 local function stepEffects(dt)
  dt=math.min(dt,.1)
  for i=#effects,1,-1 do
   local ok,done=pcall(effects[i],dt)
   if not ok or done then table.remove(effects,i)end
  end
  if #effects==0 and effectConnection then effectConnection:Disconnect();effectConnection=nil end
 end
 addEffect=function(fn)
  if dead then return fn end
  table.insert(effects,fn)
  if not effectConnection then effectConnection=Run.RenderStepped:Connect(stepEffects)end
  return fn
 end
 cancelEffect=function(fn)
  local i=table.find(effects,fn);if i then table.remove(effects,i)end
  if #effects==0 and effectConnection then effectConnection:Disconnect();effectConnection=nil end
 end
 clearEffects=function()
  table.clear(effects);if effectConnection then effectConnection:Disconnect();effectConnection=nil end
 end
 -- Sparkle / confetti bursts (pieces are destroyed when the burst ends; a handful alive at most).
 spawnBurst=function(layer,x,y,opts)
  if dead or #liveBursts>=4 or opts.Count<=0 then return end
  local burst=Art.Burst(layer,x,y,opts);burst.Layer=layer;table.insert(liveBursts,burst)
  addEffect(function(dt)
   if burst.Dead then return true end
   if burst:Step(dt)then
    burst:Destroy();local i=table.find(liveBursts,burst);if i then table.remove(liveBursts,i)end
    return true
   end
   return false
  end)
 end
 clearBursts=function(layer)
  for i=#liveBursts,1,-1 do
   local burst=liveBursts[i]
   if layer==nil or burst.Layer==layer then burst.Dead=true;burst:Destroy();table.remove(liveBursts,i)end
  end
 end
end
local function sparkleOpts(color,count)
 return {Count=lite()and math.min(count,3)or count,Shape='Star',Size=13,Life=.8,Speed={50,150},Colors={color,WHITE,GOLD},Drag=2.2}
end
-- Sounds. Ticks: an existing short UI click (InteractionAudio MenuClick id) in a small local pool (Interface group, like the other
-- UI clicks) so the pitch can rise. R150: the pool is built and preloaded at script start (it used to be built at the first tick,
-- which was still loading, so the very first tick of the first roll was dropped).
local tickVoices,tickIndex={},0
do
 local id=Audio and Audio.Asset and Audio.Asset('MenuClick')
 if id then
  for i=1,4 do
   local s=Instance.new('Sound');s.Name='Interaction_BonusTick'..i;s.SoundId=id;s.Volume=.22
   if Mixer then pcall(Mixer.Route,s,'Interface')end;s.Parent=game:GetService('SoundService');tickVoices[i]=s
  end
  task.spawn(function()pcall(function()game:GetService('ContentProvider'):PreloadAsync(tickVoices)end)end)
 end
end
local function tickSound(pitch)
 if #tickVoices==0 then return end
 tickIndex=tickIndex%#tickVoices+1;local s=tickVoices[tickIndex]
 if not s.IsLoaded then return end -- a cold voice is dropped, never played late
 s:Stop();s.PlaybackSpeed=pitch
 if Timing then Timing.Play(s)else s:Play()end
end
-- Cues for the new pops (a roll becoming ready): RarityRevealAudio's preloaded voices (AudioMixer Effects group: Effects = 0 mutes
-- them), played in the same call as the visual, never queued (a cold voice is dropped) and at most one per 0.25 s so a burst of
-- ready rolls cannot stack. Button clicks stay with ButtonHighlights (Bubble04, de-duplicated by InteractionAudio).
local lastCue=-math.huge
if Reveal then pcall(Reveal.Preload)end
local function cue(name,pitch)
 if not Reveal or dead then return end
 local now=os.clock();if now-lastCue<.25 then return end
 lastCue=now;pcall(Reveal.Play,name,pitch)
end
local function tween(object,seconds,style,props)
 local t=Tween:Create(object,TweenInfo.new(seconds,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props);t:Play();return t
end
local function ready()return Rules.ReadyCount(player:GetAttribute(Rules.Attr.Ready))end
local function training()return player:GetAttribute('TreadmillTraining')==true end
local function interval()return tonumber(player:GetAttribute(Rules.Attr.Interval))or Rules.IntervalSeconds end
-- The timer as the server published it (DueAt counts down on this client; nothing is requested).
local function timerNow()
 local left=Style.LeftSeconds(player:GetAttribute(Rules.Attr.DueAt),player:GetAttribute(Rules.Attr.Left),interval(),workspace:GetServerTimeNow())
 return Style.Timer(ready(),Rules.MaxReady,interval(),left)
end
-- HUD button ---------------------------------------------------------------------------------------------------
-- A chunky candy pill: a darker lip underneath, a gradient face with a top gloss, the pack picture, the title and a status line.
-- READY = bright green, the pack wiggles and a shine sweeps every few seconds. CHARGING (on the treadmill, nothing ready) = calm
-- deep green that fills with the pack's yellow as the next roll nears and counts down on the button (R153: ALMOST THERE! in the last 30 s).
local LIP=4
-- R153 (owner: "replace that gift icon with the pack and make the colour of the button pair with the image"): the pack picture's own colours: a rich green body (bright
-- when a roll is READY, deeper while it charges), gold outline and accents, the yellow of the pack's "?" for the charge fill, white text with a dark green stroke.
local READY_COLOR,CHARGE_COLOR=RGB(46,172,66),RGB(26,122,46)
do local old=pg:FindFirstChild('TreadmillBonusHud');if old then old:Destroy()end end
local hud=make('ScreenGui',{Name='TreadmillBonusHud',ResetOnSpawn=false,IgnoreGuiInset=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,
 DisplayOrder=26,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
local button=Art.Candy(hud,'BonusRollButton',READY_COLOR,'',{Lip=LIP,Stroke=3,Z=10,NoLabel=true,Outline=Art.Pack.Outline,LipOutline=Art.Pack.OutlineDark});button.Visible=false
button:SetAttribute('AccessibleLabel','Treadmill bonus roll')
local pulse=make('UIScale',{Name='Pulse'},button)
local face=button.Face
-- R153 (owner: "the yellow fill must cover the whole button"): the fill lives in a CanvasGroup with the face's own pill corner, so it is clipped to the same
-- rounded shape: flush with the rounded left end at any progress, edge to edge at 100%, never past the outline (the old inset pill left a gap at the left end).
local FILLS={charging={Art.Pack.Gold,Art.Pack.GoldDark},almost={RGB(255,132,70),RGB(222,60,34)}} -- the pack's yellow; the last 30 s turn orange / red, like the bar of the old gift pill
local fillClip=make('CanvasGroup',{Name='FillClip',BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Visible=false,ZIndex=12},face)
pill(fillClip)
local fill=make('Frame',{Name='Fill',BackgroundColor3=WHITE,BorderSizePixel=0,Size=UDim2.fromScale(0,1),ZIndex=12},fillClip)
local fillGradient=Art.gradient(fill,FILLS.charging[1],FILLS.charging[2])
local meter=make('Frame',{Name='Meter',BackgroundColor3=INK,BackgroundTransparency=.45,BorderSizePixel=0,Visible=false,ZIndex=14},face)
pill(meter)
do
 local fillBar=make('Frame',{Name='Bar',BackgroundColor3=WHITE,BorderSizePixel=0,Position=UDim2.fromOffset(1,1),Size=UDim2.new(0,0,1,-2),ZIndex=15},meter)
 pill(fillBar);Art.gradient(fillBar,RGB(255,250,200),RGB(255,200,70))
end
local packIcon=Art.PackIcon(face,'Icon',34);packIcon.Root.ZIndex=14;showPack(packIcon) -- R153: the owner's pack picture (drawn by EmbeddedImage153; the plain pack until / unless it can be)
local title=Art.fitText(face,'Title','BONUS ROLL',20,9);title.ZIndex=15;title.TextWrapped=false -- R153: ALMOST THERE! / BONUS READY! share the line: it shrinks (never below 9 px) instead of wrapping
local sub=Art.fitText(face,'Sub','READY!',13,8,WHITE);sub.ZIndex=15
for _,label in ipairs({title,sub})do label.TextStrokeColor3=Art.Pack.Edge;label.TextStrokeTransparency=0 end -- white on the green and on the yellow fill: a dark green stroke keeps it readable
local shine=Art.Shine(face,6,6,.6,16)
local badge=Art.Badge(button,'CountBadge',20,12);badge.Position=UDim2.new(1,-5,0,6);badge.Visible=false
local mode,lastMode='hidden','hidden'
local busy,rolling,messageUntil=false,false,0
local lastReady=ready();local lastCount
local readyPopUntil=0 -- R153: "BONUS READY! / OPEN IT!" on the button for Style.ReadyHold seconds after a roll completes
local textLeft=12
-- Title / sub line: full width, or narrower while the count badge sits at the right end.
local function layoutText()
 local fh=button.Size.Y.Offset-LIP;local right=(badge.Visible and not packIcon.Root.Visible)and 24 or 12 -- the badge sits on the gift; without the gift it takes the corner
 title.Position=UDim2.fromOffset(textLeft,math.floor(fh*.05));title.Size=UDim2.new(1,-textLeft-right,0,math.floor(fh*.5))
 sub.Position=UDim2.fromOffset(textLeft,math.floor(fh*.55));sub.Size=UDim2.new(1,-textLeft-right,0,math.floor(fh*.28))
 meter.Position=UDim2.new(0,textLeft,0,fh-9);meter.Size=UDim2.new(1,-textLeft-14,0,5)
end
local lastPaint,lastPhase
local applyPhase
local function paintButton()
 if mode=='hidden'then return end
 local n=ready();local t=timerNow();local popping=os.clock()<readyPopUntil
 local titleLine,subLine=Style.ButtonLines(mode,t,busy,popping)
 local phase=Style.ButtonPhase(mode,t)
 -- Only touch the GUI when something it shows has changed (the 4 Hz tick changes the clock once a second).
 local key=mode..'|'..tostring(busy)..'|'..tostring(popping)..'|'..titleLine..'|'..subLine..'|'..math.floor(t.Fraction*360+.5)..'|'..n
 if key==lastPaint then return end
 lastPaint=key
 if phase~=lastPhase then lastPhase=phase;applyPhase(phase)end
 if title.Text~=titleLine then title.Text=titleLine end
 if os.clock()>=messageUntil and sub.Text~=subLine then sub.Text=subLine end
 local charging=mode=='charging'
 if charging then
  fillClip.Visible=t.Fraction>.005
  fill.Size=UDim2.fromScale(t.Fraction,1)
  meter.Visible=false
 else
  fillClip.Visible=false
  meter.Visible=n<Rules.MaxReady
  meter.Bar.Size=UDim2.new(t.Fraction,-2*t.Fraction,1,-2)
 end
end
local function recolor()
 Art.Recolor(button,mode=='charging'and CHARGE_COLOR or READY_COLOR)
 sub.TextColor3=WHITE
end
local attnToken=0
local function playAttention()
 if reduced()or mode~='ready'or not button.Visible then return end
 local t=0;local plain=lite()
 addEffect(function(dt)
  t+=dt
  packIcon.Root.Rotation=Style.Wiggle(t,.7,12)
  pulse.Scale=1+.05*math.sin(math.clamp(t/.7,0,1)*math.pi)
  if not plain then Art.SetShine(shine,(t-.3)/.85)end
  if t>=1.2 then packIcon.Root.Rotation=0;pulse.Scale=1;Art.SetShine(shine,0);return true end
  return false
 end)
end
local function stopAttention()attnToken+=1;packIcon.Root.Rotation=0;Art.SetShine(shine,0)end
local function startAttention()
 attnToken+=1;local mine=attnToken
 local function loop()
  if mine~=attnToken or dead then return end
  if mode=='ready'then playAttention()end
  task.delay(Style.AttentionPeriod,loop)
 end
 task.delay(1.4,loop)
end
-- R153: the last 30 s (ALMOST THERE!): the pack wiggles and the button pulses every Style.AlmostPeriod s, like the gift pill over the head did. Bursts of ~0.75 s; nothing
-- runs between them, and ReducedMotion keeps only the words and the colours.
-- (client bug review, finding 10: the burst in flight is kept, and leaving ALMOST THERE! cancels it and puts the rotation and the scale back at once, BEFORE the ready pop
--  starts. It used to run to its end, writing pulse.Scale every frame over the BONUS ROLL button's ready pop.)
local almostToken=0
local almostEffect
local function playAlmost()
 if reduced()or mode~='charging'or not button.Visible then return end
 local t=0
 almostEffect=addEffect(function(dt)
  t+=dt
  packIcon.Root.Rotation=Style.Wiggle(t,.7,12);pulse.Scale=1+.06*math.sin(math.clamp(t/.7,0,1)*math.pi)
  if t>=.75 then packIcon.Root.Rotation=0;pulse.Scale=1;almostEffect=nil;return true end
  return false
 end)
end
local function stopAlmost()
 almostToken+=1
 if almostEffect then cancelEffect(almostEffect);almostEffect=nil;packIcon.Root.Rotation=0;pulse.Scale=1 end
end
local function startAlmost()
 almostToken+=1;local mine=almostToken
 local function loop()
  if mine~=almostToken or dead or mode~='charging'then return end
  playAlmost();task.delay(Style.AlmostPeriod,loop)
 end
 loop()
end
-- What changes with the phase: the fill colours, the title colour (ALMOST THERE! is pink) and the pulse.
applyPhase=function(phase)
 local colors=FILLS[phase=='almost'and'almost'or'charging']
 fillGradient.Color=ColorSequence.new(colors[1],colors[2])
 if phase=='almost'then startAlmost()else stopAlmost()end
end
local function buttonCenter() -- the pack icon middle, in screen pixels (the button is anchored at its centre)
 return button.Position.X.Offset-button.Size.X.Offset/2+26,button.Position.Y.Offset-button.Size.Y.Offset/2+(button.Size.Y.Offset-LIP)/2
end
-- Sparkle layer: an empty 0 x 0 frame at the corner (pieces are placed in screen pixels from it), so no full-screen box sits over the game.
make('Frame',{Name='Fx',BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(0,0),Active=false,ZIndex=40},hud)
local function popButton()
 if reduced()then return end
 pulse.Scale=.72;tween(pulse,.42,Enum.EasingStyle.Back,{Scale=1})
end
local function popBadge()
 if reduced()then return end
 badge.Pop.Scale=1.28;tween(badge.Pop,.3,Enum.EasingStyle.Back,{Scale=1})
end
local function readyMoment(n)
 if reduced()or mode~='ready'then return end
 local x,y=buttonCenter();spawnBurst(hud.Fx,x,y,sparkleOpts(GOLD,8))
 if n>=2 then popBadge()else popButton()end
end
local function refreshButton()
 local n=ready()
 mode=Style.ButtonMode(n,training(),pg:GetAttribute('TitleActive')==true,rolling)
 button.Visible=mode~='hidden'
 if mode~=lastMode then
  local was=lastMode;lastMode=mode
  recolor();lastPaint=nil;lastPhase=nil
  if mode=='ready'then startAttention()else stopAttention()end
  if was=='hidden'and mode~='hidden'then popButton()end
 end
 if os.clock()>=messageUntil then button:SetAttribute('AccessibleLabel',mode=='ready'and'Treadmill bonus roll, ready'or mode=='charging'and(timerNow().State=='almost'and'Treadmill bonus roll, almost ready'or'Treadmill bonus roll, charging')or'Treadmill bonus roll')end
 if n~=lastCount then
  lastCount=n;badge.Visible=n>=2;badge.Count.Text=tostring(n);layoutText()
  if n>=2 then popBadge()end
 end
 if mode~='hidden'then
  paintButton()
 end
end
local function layoutButton()
 local view=Layout.Viewport(hud);local w,h=view.X,view.Y
 local m=Layout.Read(view,game:GetService('UserInputService').TouchEnabled,Layout.Controls(hud))
 local extra={}
 if Notices then
  local inset=GuiService.TopbarInset;local top=typeof(inset)=='Rect'and inset.Height>0 and inset.Max.Y or 36
  local ok,rows=pcall(Notices.Calculate,w,h,top,Rules.NoticeFlags)
  if ok then for name,row in pairs(rows)do if type(row)=='table'then table.insert(extra,{N=name,X=row.X-row.Width/2,Y=row.Y,W=row.Width,H=row.Height})end end end
 end
 local boxes=Layout.HudBoxes(m,w,h,true)
 -- R155 review: the pity bars (PityBars155, always on the HUD) take the place just above the hotbar this button wants: it sits above them (the module knows where
 -- they are; no module = the place it always had)
 local okBars,r=pcall(function()return require(RS:FindFirstChild('PityBars155')).ButtonSpot(Rules,m,w,h,boxes,extra)end)
 if not(okBars and type(r)=='table')then r=Rules.Place(Layout.RulesView(m),w,h,boxes,extra)end -- (R158: in screen px; RulesView: the rules' fixed 44 px for the name rows are the scaled rows' 44 x scale)
 button.AnchorPoint=Vector2.new(.5,.5);button.Position=UDim2.fromOffset(r.X+r.W/2,r.Y+r.H/2);button.Size=UDim2.fromOffset(r.W,r.H) -- R150 review: the ready pop and the pulse scale about the button's centre
 local fh=r.H-LIP
 -- Narrow phones get the text-only size: drop the pack icon and use the full width for the caption.
 local icon=r.W>=140;packIcon.Root.Visible=icon
 local iconSize=math.min(fh-6,36);packIcon.Root.Size=UDim2.fromOffset(iconSize,iconSize);packIcon.Root.Position=UDim2.fromOffset(8+iconSize/2,fh/2)
 badge.Position=icon and UDim2.fromOffset(8+iconSize-5,8)or UDim2.new(1,-5,0,6)
 textLeft=icon and 8+iconSize+6 or 12
 title:FindFirstChildOfClass('UITextSizeConstraint').MaxTextSize=r.H>=50 and 20 or 17
 layoutText()
end
connect(hud:GetPropertyChangedSignal('AbsoluteSize'),layoutButton);task.defer(layoutButton)
-- (R155 review: where it goes depends on the pity bars, which follow the thumb controls, the touch setting and the camera too: laid out again whenever HudLayout says
-- the HUD changed, as the bars do - a pair that agree on every frame)
table.insert(connections,{Disconnect=Layout.Watch(hud,function()task.defer(layoutButton)end)})
local function nudge()
 if reduced()then return end
 local t=0
 addEffect(function(dt)
  t+=dt;local k=math.max(0,1-t/.3)
  face.Position=UDim2.fromOffset(math.sin(t*60)*4*k,0)
  if t>=.3 then face.Position=UDim2.fromOffset(0,0);return true end
  return false
 end)
end
local function flashMessage(message)
 if Audio then pcall(Audio.Play,'Denied')end -- R150 review: every flash is a refusal (charging tap, server refusal, no / bad reply); a roll that starts never flashes
 -- Short copy on the button (the full text goes to the accessibility label).
 messageUntil=os.clock()+2.5;sub.Text=Style.Flash(message);button:SetAttribute('AccessibleLabel','Treadmill bonus roll: '..tostring(message));refreshButton();nudge()
 task.delay(2.6,function()if not dead then lastPaint=nil;refreshButton()end end)
end
-- Roll overlay ---------------------------------------------------------------------------------------------------
-- R124: framed panel (gold ribbon header, inner gold line, corner studs, twinkling dots), strip window with soft side
-- fades and a glowing marker; Legendary / Mythic / Secret cards carry their own designs; the result lights up the
-- BORDERS (card + panel), never a full-panel flash; rows and buttons are stacked so nothing overlaps.
-- R150: wrapping-paper stripes and a bow on the ribbon header, bouncing gem pointers, rarity plaques on every card (a soft gloss on the special ones),
-- a playful status line while it spins, a reveal word that pops, light rays and confetti behind the winner (the confetti flies under the ribbon header), candy buttons.
do local o=pg:FindFirstChild('TreadmillBonusRoll');if o then o:Destroy()end end
local overlay=make('ScreenGui',{Name='TreadmillBonusRoll',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=60,Enabled=false,
 ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
make('Frame',{Name='Backdrop',BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,Size=UDim2.fromScale(1,1),Active=true},overlay)
local panel=make('Frame',{Name='Panel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=WHITE,ZIndex=2},overlay) -- colour comes from the gradient
round(panel,16);local panelStroke=stroke(panel,GOLD,3)
make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(70,60,160)),ColorSequenceKeypoint.new(.55,RGB(36,30,92)),ColorSequenceKeypoint.new(1,RGB(18,16,46))}),Rotation=70},panel)
local panelPop=make('UIScale',{Name='Pop'},panel)
round(Art.Stripes(panel,4,35,.93,2),16)
local function diamond(parent,name,size,color,z)
 local d=make('Frame',{Name=name,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(size,size),Rotation=45,BackgroundColor3=color,BorderSizePixel=0,ZIndex=z},parent)
 stroke(d,INK,1);return d
end
do
 local inner=make('Frame',{Name='InnerLine',BackgroundTransparency=1,Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-12,1,-12),ZIndex=2},panel)
 round(inner,11);make('UIStroke',{Color=GOLD,Thickness=1,Transparency=.55},inner)
 for i,c in ipairs({{0,0},{1,0},{0,1},{1,1}})do local d=diamond(inner,'Stud'..i,8,GOLD,3);d.Position=UDim2.fromScale(c[1],c[2])end
end
local twinkles={}
for i,c in ipairs({{.06,.2},{.94,.17},{.12,.62},{.9,.6},{.04,.86},{.97,.88},{.3,.08},{.72,.07}})do -- R150 review: none along the bottom, where the odds fine print sits
 twinkles[i]=make('Frame',{Name='Twinkle'..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(c[1],c[2]),Size=UDim2.fromOffset(3,3),Rotation=45,
  BackgroundColor3=RGB(255,240,190),BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=2},panel)
end
local ribbon=make('Frame',{Name='Ribbon',AnchorPoint=Vector2.new(.5,0),BackgroundColor3=WHITE,ZIndex=5},panel) -- R150 review: above the reveal effect layer (4), so confetti never crosses the header
round(ribbon,9);stroke(ribbon,INK,2)
make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(255,236,140)),ColorSequenceKeypoint.new(.5,RGB(255,200,70)),ColorSequenceKeypoint.new(1,RGB(232,140,36))}),Rotation=90},ribbon)
for i,x in ipairs({0,1})do local tail=diamond(ribbon,'Tail'..i,14,RGB(214,128,30),2);tail.Position=UDim2.new(x,x==0 and 2 or-2,.5,0)end
local ribbonTitle,headerPack
do
 ribbonTitle=Art.fitText(ribbon,'Title','TREADMILL BONUS ROLL',19,9,INK);ribbonTitle.ZIndex=4 -- R153: the pack picture on the left takes the place of the gift emoji (layoutOverlay places both)
 ribbonTitle.TextStrokeColor3=RGB(255,248,220);ribbonTitle.TextStrokeTransparency=.4
 headerPack=Art.PackIcon(ribbon,'Pack',30);headerPack.Root.ZIndex=6;showPack(headerPack)
end
local bow=Art.Bow(panel,56,'Bow',Art.Pink);bow.ZIndex=10;bow.AnchorPoint=Vector2.new(.5,0)
local window=make('Frame',{Name='StripWindow',BackgroundColor3=WHITE,ClipsDescendants=true,ZIndex=3},panel) -- colour comes from the gradient
round(window,10);stroke(window,RGB(120,110,200),2)
make('UIGradient',{Color=ColorSequence.new(RGB(30,30,62),RGB(8,10,24)),Rotation=90},window)
local strip=make('Frame',{Name='Strip',BackgroundTransparency=1,ZIndex=4},window)
for i,x in ipairs({0,1})do
 local side=make('Frame',{Name=i==1 and'FadeLeft'or'FadeRight',AnchorPoint=Vector2.new(x,0),Position=UDim2.fromScale(x,0),Size=UDim2.new(0,64,1,0),
  BackgroundColor3=RGB(10,12,28),BorderSizePixel=0,ZIndex=7},window)
 make('UIGradient',{Transparency=NumberSequence.new(x==0 and 0 or 1,x==0 and 1 or 0)},side)
end
do
 local glow=make('Frame',{Name='MarkerGlow',BackgroundColor3=GOLD,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),
  Size=UDim2.new(0,18,1,0),BackgroundTransparency=.55,ZIndex=8},window)
 make('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.2),NumberSequenceKeypoint.new(1,1)})},glow)
end
make('Frame',{Name='Marker',BackgroundColor3=GOLD,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),
 Size=UDim2.new(0,4,1,0),ZIndex=8},window)
-- Gem pointers (drawn shapes: no glyph that a font could lack) bounce into the strip and flick on every card that passes.
local pointerTop,pointerBottom
do
 local function pointer(name)
  local d=make('Frame',{Name=name,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(11,11),Rotation=45,BackgroundColor3=WHITE,BorderSizePixel=0,ZIndex=9},panel)
  stroke(d,INK,2);Art.gradient(d,RGB(255,244,170),RGB(255,184,44),45);return d
 end
 pointerTop,pointerBottom=pointer('PointerTop'),pointer('PointerBottom')
end
local status=Art.fitText(panel,'Status','',16,10,RGB(214,206,255),Enum.Font.GothamBold);status.ZIndex=3
local word=Art.fitText(panel,'Word','',28,12);word.ZIndex=3;word.Visible=false
local wordScale=make('UIScale',{Name='Pop'},word)
local oddsLine=make('TextLabel',{Name='Odds',RichText=true,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),
 TextStrokeColor3=INK,TextStrokeTransparency=.3,TextWrapped=true,TextScaled=true,ZIndex=3},panel)
make('UITextSizeConstraint',{MaxTextSize=14,MinTextSize=9},oddsLine)
local result=text(panel,'Result','',18);result.ZIndex=3;result.TextScaled=true
make('UITextSizeConstraint',{MaxTextSize=18,MinTextSize=10},result)
local actions=make('Frame',{Name='Actions',BackgroundTransparency=1,ZIndex=3},panel)
local skipButton,closeButton,againButton
do
 local function action(name,caption,color)
  local b=Art.Candy(actions,name,color,caption,{Lip=4,Stroke=2.5,Z=4,TextSize=16,MinTextSize=10});b.Visible=false;return b
 end
 skipButton=action('Skip','SKIP',RGB(120,130,232));closeButton=action('Close','COLLECT',RGB(92,208,104));againButton=action('Again','ROLL AGAIN',RGB(255,152,48))
end
local function setCaption(b,value)b.Face.Label.Text=value end
local buttonW=170
-- R150 review: the reveal pieces fly INSIDE the panel: over the strip window (3), the word and the rows, under the ribbon header (5), the pointers (9) and the bow (10). The panel does not clip, so they still leave it.
local revealFx=make('Frame',{Name='Fx',BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Active=false,ZIndex=4},panel)
-- The visible buttons sit side by side, centred as a group (CLOSE alone is centred too).
local function arrangeActions()
 local shown={};for _,b in ipairs({skipButton,closeButton,againButton})do if b.Visible then shown[#shown+1]=b end end
 local gap=12;local total=#shown*buttonW+math.max(0,#shown-1)*gap
 for i,b in ipairs(shown)do b.Size=UDim2.fromOffset(buttonW,actions.Size.Y.Offset);b.Position=UDim2.new(.5,-total/2+(i-1)*(buttonW+gap),0,0)end
end
local function oddsText()
 local parts={}
 for _,row in ipairs(Rules.OddsRows())do
  local c=row.Color;table.insert(parts,string.format('<font color="#%02X%02X%02X">%s %s</font>',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5),row.Name,row.Text))
 end
 return table.concat(parts,'  ·  ')
end
local panelW,cardH,cardY=600,128,10
local windowY,windowH=0,148
local pointerTopY,pointerBottomY=0,0
local function layoutOverlay()
 local view=overlay.AbsoluteSize;local w,h=view.X>0 and view.X or 1280,view.Y>0 and view.Y or 720
 panelW=math.floor(math.min(w-24,660));local short=h<420
 cardH=short and 100 or 128;cardY=short and 8 or 10
 -- Rows top to bottom; each starts below the previous one, so text and buttons never overlap:
 -- ribbon / strip window / status or reveal word / result / buttons / odds (fine print).
 local ribbonY=short and 18 or 24;local ribbonH=short and 26 or 30;local gap=short and 8 or 10
 local wordH=short and 24 or 32;local resultH=short and 18 or 24;local actionH=short and 36 or 44;local oddsH=short and 24 or 32
 local rowGap=8;local pad=short and 6 or 12
 local y=ribbonY
 ribbon.Position=UDim2.new(.5,0,0,y);ribbon.Size=UDim2.fromOffset(math.min(380,panelW-90),ribbonH);y+=ribbonH+gap
 local packSize=ribbonH+6 -- R153: the pack sticks out 3 px above and below the ribbon, on its left; the title takes the rest
 headerPack.Root.Size=UDim2.fromOffset(packSize,packSize);headerPack.Root.Position=UDim2.fromOffset(12+packSize/2,ribbonH/2)
 ribbonTitle.Position=UDim2.fromOffset(18+packSize,0);ribbonTitle.Size=UDim2.new(1,-(18+packSize)-22,1,0)
 -- The bow sits on the ribbon's top edge, above the title (its loops dip a few px onto the ribbon, clear of the letters).
 local bowSize=short and 44 or 56
 bow.Size=UDim2.fromOffset(bowSize,math.floor(bowSize*.62+.5));bow.Position=UDim2.new(.5,0,0,ribbonY-(short and 19 or 25))
 window.Position=UDim2.fromOffset(14,y);windowY=y;windowH=cardH+2*cardY;window.Size=UDim2.new(1,-28,0,windowH);y+=windowH+rowGap
 status.Position=UDim2.fromOffset(16,y);status.Size=UDim2.new(1,-32,0,wordH+resultH) -- R153: nothing under the spin line, so it is centred between the strip and the buttons (the result row stays for the reveal)
 word.AnchorPoint=Vector2.new(.5,.5);word.Position=UDim2.new(.5,0,0,y+wordH/2);word.Size=UDim2.new(1,-32,0,wordH);y+=wordH -- R150 review: the pop scales about its centre (UIScale pivots at the AnchorPoint)
 result.Position=UDim2.fromOffset(16,y);result.Size=UDim2.new(1,-32,0,resultH);y+=resultH+rowGap
 actions.Position=UDim2.fromOffset(16,y);actions.Size=UDim2.new(1,-32,0,actionH);y+=actionH+rowGap
 oddsLine.Position=UDim2.fromOffset(16,y);oddsLine.Size=UDim2.new(1,-32,0,oddsH);y+=oddsH+pad
 panel.Size=UDim2.fromOffset(panelW,math.min(h-16,y))
 pointerTopY=windowY;pointerBottomY=windowY+windowH
 pointerTop.Position=UDim2.fromOffset(panelW/2,pointerTopY);pointerBottom.Position=UDim2.fromOffset(panelW/2,pointerBottomY)
 buttonW=math.floor(math.min(180,(panelW-32-24)/2))
 arrangeActions()
end
connect(overlay:GetPropertyChangedSignal('AbsoluteSize'),layoutOverlay);layoutOverlay()
local cards={};local spin,spinConn,current
local glowTweens={}
local function clearCards()
 for _,c in ipairs(cards)do if Pictures then pcall(Pictures.Clear,c.Holder)end;c.Frame:Destroy()end;table.clear(cards)
end
-- Card designs for the special tiers. Static frames; the only motion (sweep / pulse / twinkle) runs in the animator
-- and only for these few cards.
local animateDesign,buildCard
do
local function corners(parent,color,z)
 for i,c in ipairs({{0,0},{1,0},{0,1},{1,1}})do
  local d=diamond(parent,'Stud'..i,7,color,z);d.Position=UDim2.new(c[1],c[1]==0 and 7 or-7,c[2],c[2]==0 and 7 or-7)
 end
end
local function design(f,tierName,color)
 local z=5;local deco=make('Frame',{Name='Design',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=z},f)
 local motion={Kind=tierName}
 local innerLine=make('Frame',{Name='InnerLine',BackgroundTransparency=1,Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),ZIndex=z},deco)
 round(innerLine,6)
 if tierName=='Legendary'then
  -- Sunburst behind the pack, gold double border with a moving shine, gold corner studs.
  for i=0,5 do
   local ray=make('Frame',{Name='Ray'..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,(cardH-40)/2+4),Size=UDim2.fromOffset(3,math.min(92,cardH-30)),
    Rotation=i*30,BackgroundColor3=RGB(255,226,120),BackgroundTransparency=.35,BorderSizePixel=0,ZIndex=z},deco)
   make('UIGradient',{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.1),NumberSequenceKeypoint.new(1,1)})},ray)
  end
  local line=make('UIStroke',{Color=Color3.new(1,1,1),Thickness=1.5,Transparency=0},innerLine)
  motion.Shine=make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(236,168,30)),ColorSequenceKeypoint.new(.42,RGB(236,168,30)),ColorSequenceKeypoint.new(.5,RGB(255,252,226)),ColorSequenceKeypoint.new(.58,RGB(236,168,30)),ColorSequenceKeypoint.new(1,RGB(236,168,30))}),Rotation=25},line)
  corners(deco,RGB(255,214,92),z+2)
 elseif tierName=='Mythic'then
  -- Flame tongues along the top, a pulsing hot inner border, rose studs.
  for i=1,5 do
   local flame=make('Frame',{Name='Flame'..i,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(i/6,0,0,3),Size=UDim2.fromOffset(12,18+(i%2)*8),
    BackgroundColor3=RGB(255,96,150),BackgroundTransparency=.25,BorderSizePixel=0,ZIndex=z},deco)
   round(flame,6);make('UIGradient',{Rotation=90,Transparency=NumberSequence.new(.1,1)},flame)
  end
  motion.Line=make('UIStroke',{Color=RGB(255,170,210),Thickness=2,Transparency=.2},innerLine)
  corners(deco,RGB(255,120,170),z+2)
 elseif tierName=='Secret'then
  -- Nebula wash, a starfield, a silver shimmering inner border and silver studs.
  local neb=make('Frame',{Name='Nebula',BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.45,Size=UDim2.fromScale(1,1),ZIndex=z},deco)
  round(neb,9);make('UIGradient',{Rotation=60,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(70,40,170)),ColorSequenceKeypoint.new(.5,RGB(150,80,220)),ColorSequenceKeypoint.new(1,RGB(20,30,90))})},neb)
  motion.Stars={}
  for i,c in ipairs({{.15,.12},{.8,.1},{.3,.32},{.88,.4},{.1,.5},{.65,.22},{.45,.08},{.92,.66},{.2,.7},{.75,.55}})do
   motion.Stars[i]=make('Frame',{Name='Star'..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(c[1],c[2]),Size=UDim2.fromOffset(i%3==0 and 3 or 2,i%3==0 and 3 or 2),
    BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=z},deco)
  end
  local line=make('UIStroke',{Color=Color3.new(1,1,1),Thickness=1.5,Transparency=0},innerLine)
  motion.Shine=make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(150,154,170)),ColorSequenceKeypoint.new(.45,RGB(150,154,170)),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.55,RGB(150,154,170)),ColorSequenceKeypoint.new(1,RGB(150,154,170))}),Rotation=35},line)
  corners(deco,RGB(225,228,240),z+2)
 end
 return motion
end
animateDesign=function(entry,t)
 local m=entry.Motion;if not m then return end
 if m.Shine then m.Shine.Offset=Vector2.new(((t*.45)%1)*2.4-1.2,0)end
 if m.Line then m.Line.Transparency=.15+.45*(.5+.5*math.sin(t*5))end
 if m.Stars then for i,star in ipairs(m.Stars)do star.BackgroundTransparency=.1+.8*math.max(0,math.sin(t*3+i*1.7))end end
end
-- Every card: rarity-coloured frame, a plaque behind the rarity / biome lines, a soft gloss over the top.
buildCard=function(i,pack)
 local tierName,color=Rules.Tier(pack.Variant)
 local f=make('Frame',{Name='Card'..i,BackgroundColor3=color:Lerp(RGB(16,20,44),.62),Position=UDim2.fromOffset((i-1)*Rules.Strip.Pitch,cardY),
  Size=UDim2.fromOffset(Rules.Strip.CardWidth,cardH),ZIndex=5},strip)
 round(f,9);local edge=stroke(f,color,3)
 make('UIGradient',{Color=ColorSequence.new(Color3.new(1,1,1),RGB(150,150,170)),Rotation=90},f)
 local motion=Rules.Special[tierName]and design(f,tierName,color)or nil
 local plaque=make('Frame',{Name='Plaque',BackgroundColor3=color:Lerp(INK,.74),BackgroundTransparency=.2,BorderSizePixel=0,Position=UDim2.new(0,4,1,-39),Size=UDim2.new(1,-8,0,35),ZIndex=6},f)
 round(plaque,7)
 local holder=make('Frame',{Name='Picture',BackgroundTransparency=1,Position=UDim2.fromOffset(6,4),Size=UDim2.new(1,-12,1,-44),ZIndex=6},f)
 local proxy
 if Pictures then
  proxy=Instance.new('Folder');proxy:SetAttribute('SeedPackTool',true);proxy:SetAttribute('Stage',pack.Stage)
  proxy:SetAttribute('BagVariant',pack.Variant);proxy:SetAttribute('PackMutation','None')
  pcall(Pictures.Show,holder,proxy,2)
 else
  local icon=text(holder,'Icon','🎒',34);icon.Size=UDim2.fromScale(1,1);icon.ZIndex=6
 end
 local name=text(f,'Rarity',string.upper(tierName),13,color);name.ZIndex=7;name.Size=UDim2.new(1,-6,0,16);name.Position=UDim2.new(0,3,1,-36)
 local biome=text(f,'Biome',pack.Variant==Rules.Void.Variant and Rules.Void.Label or biomeName(pack.Stage),11,RGB(225,230,255));biome.ZIndex=7;biome.Font=Enum.Font.GothamBold
 biome.Size=UDim2.new(1,-6,0,14);biome.Position=UDim2.new(0,3,1,-19)
 if motion then -- R150 review: the soft gloss only on the special tiers (46 plain cards under the card gradient barely show it: -138 instances when the roll opens)
  local gloss=make('Frame',{Name='Gloss',BackgroundColor3=WHITE,BorderSizePixel=0,Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,.34,0),ZIndex=8},f)
  round(gloss,7);make('UIGradient',{Rotation=90,Transparency=NumberSequence.new(.78,1)},gloss)
 end
 local entry={Frame=f,Holder=holder,Stroke=edge,Pack=pack,Tier=tierName,Color=color,Motion=motion,Proxy=proxy};cards[i]=entry;return entry
end
end
local function place(offset)
 local center=window.AbsoluteSize.X>0 and window.AbsoluteSize.X/2 or(panelW-28)/2
 strip.Position=UDim2.fromOffset(math.floor(center-Rules.Strip.CardWidth/2-offset+.5),0)
end
local finish;local revealed=false
local function stopSpin()if spinConn then spinConn:Disconnect();spinConn=nil end end
local function stopGlow()for _,t in ipairs(glowTweens)do t:Cancel()end;table.clear(glowTweens);panelStroke.Color=GOLD;panelStroke.Thickness=3 end
local function play(tween)table.insert(glowTweens,tween);tween:Play();return tween end
-- Light rays behind the winning card (inside the strip: above the other cards, below the winner). They only turn in the
-- ambient effect; with ReducedMotion / low quality they stand still.
local activeRays,raySpeed
local function clearRays()
 if activeRays then activeRays.Root:Destroy();activeRays=nil end
end
local function showRays(entry,style)
 clearRays()
 local length=math.max(260,cardH*2.4)
 local rays=Art.Rays(strip,style.Beams,length,math.max(20,math.floor(cardH*.28)),6)
 rays.Root.Position=UDim2.fromOffset((spin.Win-1)*Rules.Strip.Pitch+Rules.Strip.CardWidth/2,cardY+cardH/2)
 Art.TintRays(rays,entry.Color:Lerp(WHITE,.55),style.Alpha)
 activeRays=rays;raySpeed=style.Speed
end
-- Ambient motion while the roll window is open: pointers bounce, twinkles, special-card designs, rays turn. Nothing runs when
-- the window is closed, and nothing at all with ReducedMotion.
local ambient,kick=nil,0
local function stopAmbient()
 if ambient then cancelEffect(ambient);ambient=nil end
 pointerTop.Position=UDim2.fromOffset(panelW/2,pointerTopY);pointerBottom.Position=UDim2.fromOffset(panelW/2,pointerBottomY)
end
local function startAmbient()
 stopAmbient();if reduced()then return end
 local plain=lite();local clock=0
 ambient=addEffect(function(dt)
  clock+=dt;kick=math.max(0,kick-dt*7)
  local bob=3*(.5+.5*math.sin(clock*6))+4*kick
  pointerTop.Position=UDim2.fromOffset(panelW/2,pointerTopY+bob);pointerBottom.Position=UDim2.fromOffset(panelW/2,pointerBottomY-bob)
  if plain then return false end
  for i,d in ipairs(twinkles)do d.BackgroundTransparency=.25+.7*(.5+.5*math.sin(clock*2.2+i*1.3))end
  local viewW=window.AbsoluteSize.X>0 and window.AbsoluteSize.X or panelW-28;local sx=strip.Position.X.Offset
  for _,entry in ipairs(cards)do -- R153: a special card is only animated while it is inside the window (the Secret tease is off screen most of the spin)
   if entry.Motion then local x=sx+entry.Frame.Position.X.Offset;if x>-Rules.Strip.CardWidth and x<viewW then animateDesign(entry,clock)end end
  end
  if activeRays then activeRays.Root.Rotation=(clock*raySpeed)%360 end
  return false
 end)
end
local function fxOrigin()return panelW/2,windowY+windowH/2 end -- panel-local: the middle of the strip window
local function celebrate(entry,res)
 local special=Rules.Special[res.Rarity]==true
 local style=Style.Reveal(res.Rarity)
 local calm=reduced()
 result.Visible=true;result.Text=(special and'✨ 'or'')..'You got a '..string.upper(res.Rarity)..' '..(res.Label or'pack')..'!'
 result.TextColor3=entry.Color
 status.Visible=false;word.Text=style.Word;word.TextColor3=entry.Color;word.Visible=true
 setCaption(closeButton,style.Close)
 if Audio then pcall(Audio.Play,special and'GemClaim'or'KaChing')end
 entry.Frame.ZIndex=8 -- the winner sits above the rays
 showRays(entry,style)
 if not calm then
  local grow=make('UIScale',{Scale=1},entry.Frame);tween(grow,.35,Enum.EasingStyle.Back,{Scale=1.07})
  wordScale.Scale=math.max(.2,1-style.Pop*3)
  tween(wordScale,style.Elastic and .7 or .45,style.Elastic and Enum.EasingStyle.Elastic or Enum.EasingStyle.Back,{Scale=1})
  local x,y=fxOrigin()
  spawnBurst(revealFx,x,y,sparkleOpts(entry.Color,style.Sparkles))
  if style.Confetti>0 then
   local count=lite()and math.floor(style.Confetti*.3)or style.Confetti
   local colors={entry.Color,Art.Confetti[1],Art.Confetti[3],Art.Confetti[4],Art.Confetti[5],WHITE}
   spawnBurst(revealFx,x,y,{Count=count,Shape='Confetti',Size=7,Life=1.3,Speed={260,620},Arc={-math.pi*.95,-math.pi*.05},Gravity=820,Colors=colors,Drag=1.8})
  end
 else
  wordScale.Scale=1
 end
 if special then
  local big=res.Rarity~='Legendary'
  if Reveal then pcall(function()Reveal.Preload();Reveal.Play(big and'Impact'or'Chime',big and 1.1 or .8)
   if big then Reveal.Play('Chime',.7)end end)end
  if RareAudio and res.Rarity=='Secret'then pcall(RareAudio.Sting,6)end
  -- Light-up on the borders: the card's own border flashes white then settles in its colour and pulses inside a
  -- glow ring; the panel border takes the colour and pulses with it.
  entry.Stroke.Thickness=5;entry.Stroke.Color=Color3.new(1,1,1)
  play(Tween:Create(entry.Stroke,TweenInfo.new(calm and .2 or .6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Color=entry.Color}))
  local ring=make('Frame',{Name='BorderGlow',BackgroundTransparency=1,Position=UDim2.fromOffset(-4,-4),Size=UDim2.new(1,8,1,8),ZIndex=4},entry.Frame)
  round(ring,12);local glow=make('UIStroke',{Name='Glow',Color=entry.Color:Lerp(Color3.new(1,1,1),.25),Thickness=4,Transparency=calm and .35 or .05},ring)
  panelStroke.Color=entry.Color;panelStroke.Thickness=4
  if not calm then
   play(Tween:Create(glow,TweenInfo.new(.55,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.7}))
   play(Tween:Create(panelStroke,TweenInfo.new(.55,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Thickness=6}))
  end
 end
 -- One soft shine across the winner (not with ReducedMotion or low quality).
 if not calm and not lite()then
  local sweep=Art.Shine(entry.Frame,5,5,.55,9);local t=0
  addEffect(function(dt)
   t+=dt;Art.SetShine(sweep,(t-.15)/.7)
   if t>=.9 then sweep.Pane:Destroy();return true end
   return false
  end)
 end
end
finish=function()
 if not spin or not current or revealed then return end
 revealed=true
 local offset=spin:Skip();place(offset);stopSpin()
 local entry=cards[spin.Win];if entry then celebrate(entry,current)end
 skipButton.Visible=false;closeButton.Visible=true;againButton.Visible=ready()>0
 setCaption(againButton,'ROLL AGAIN ('..ready()..')')
 arrangeActions()
end
local statusIndex=0
local function startRoll(res)
 rolling=true;revealed=false;refreshButton();clearCards();stopSpin()
 current=res;overlay.Enabled=true;layoutOverlay()
 stopGlow();clearRays();clearBursts(revealFx)
 word.Visible=false;wordScale.Scale=1;status.Visible=true;statusIndex=1;status.Text=Style.SpinLines[1]
 result.Visible=false;result.Text='' -- R153: no bag hint line while it spins
 setCaption(closeButton,'COLLECT')
 local stages=Rules.DecodePool(res.Pool);if #stages==0 then stages={res.Stage}end
 oddsLine.Text=oddsText() -- R124: no "Packs from ..." line (owner)
 local winner={Stage=res.Stage,Variant=res.Variant}
 local rng=Random.new()
 local draw=function()return rng:NextNumber()end
 local reel=Rules.BuildStrip(stages,winner,draw)
 Style.Tease(reel,Rules.Strip.Win,Rules.Void,draw) -- R153: a Secret card flies by (never the winner: the server's result stays on Strip.Win)
 for i,pack in ipairs(reel)do buildCard(i,pack)end
 -- R137: every card's real pack picture is built before it scrolls into view (no flat stand-ins any more).
 if Pictures and Pictures.Warm then local proxies={};for _,c in ipairs(cards)do if c.Proxy then proxies[#proxies+1]=c.Proxy end end;pcall(Pictures.Warm,proxies)end
 strip.Size=UDim2.fromOffset(#cards*Rules.Strip.Pitch,cardH+2*cardY)
 spin=Rules.NewSpin({Reduced=reduced(),Jitter=rng:NextNumber(-.3,.3)})
 place(spin.Offset)
 skipButton.Visible=true;closeButton.Visible=false;againButton.Visible=false;arrangeActions()
 if not reduced()then
  panelPop.Scale=.88;tween(panelPop,.28,Enum.EasingStyle.Back,{Scale=1})
 else panelPop.Scale=1 end
 startAmbient()
 spinConn=Run.RenderStepped:Connect(function(dt)
  local offset,tick,pitch,done=spin:Step(dt);place(offset)
  local line,index=Style.SpinLine(spin.T/spin.Duration)
  if index~=statusIndex and not done then statusIndex=index;status.Text=line end
  if tick then kick=1;tickSound(pitch)end
  if done then finish()end
 end)
end
local function close()
 stopSpin();if spin and not revealed then finish()end
 stopGlow();stopAmbient();clearRays();clearBursts(revealFx);overlay.Enabled=false;rolling=false;clearCards();current=nil;spin=nil;refreshButton()
end
local function requestRoll()
 if busy then return end
 if ready()<1 then
  -- Charging: nothing to open yet. Say when, without asking the server.
  local t=timerNow();flashMessage(t.State=='almost'and'ALMOST! '..t.Clock or'NEXT IN '..t.Clock);return
 end
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
-- Candy buttons sink onto their lip while pressed.
local function pressable(b)
 connect(b.InputBegan,function(input)
  local kind=input.UserInputType
  if kind==Enum.UserInputType.MouseButton1 or kind==Enum.UserInputType.Touch then Art.Press(b,true)end
 end)
 connect(b.InputEnded,function()Art.Press(b,false)end)
 connect(b.MouseLeave,function()Art.Press(b,false)end)
end
for _,b in ipairs({button,skipButton,closeButton,againButton})do pressable(b)end
-- R153 (owner): the gift timer pill that floated over the player's head is gone (it is not built at all); the HUD button's charging look carries the countdown.
do local o=pg:FindFirstChild('TreadmillBonusProgress');if o then o:Destroy()end end -- a copy left by an older run of this script
-- A 4 Hz tick, only while on the treadmill (no per-frame work, nothing when off it).
local ticking=false
local function refreshTimers()if mode~='hidden'then paintButton()end end
local function ensureTicker()
 if ticking or dead or not training()then return end
 ticking=true
 local function loop()
  if dead then ticking=false;return end
  refreshTimers()
  if training()then task.delay(.25,loop)else ticking=false end
 end
 task.delay(.25,loop)
end
for _,key in ipairs({Rules.Attr.DueAt,Rules.Attr.Left,Rules.Attr.Interval,'TreadmillTraining'})do
 connect(player:GetAttributeChangedSignal(key),function()refreshButton();ensureTicker()end)
end
connect(player:GetAttributeChangedSignal(Rules.Attr.Ready),function()
 local n=ready();local before=lastReady;lastReady=n
 if n>before then readyPopUntil=os.clock()+Style.ReadyHold;task.delay(Style.ReadyHold+.1,function()if not dead then lastPaint=nil;refreshButton()end end)end
 refreshButton()
 if n>before then
  -- One cue on the frame of the visuals (the first ready is a bright note, the second a higher one).
  if mode=='ready'then cue(n>=2 and'Note2'or'Note',n>=2 and 1.7 or 1.35)end
  readyMoment(n)
 end
 ensureTicker()
end)
connect(pg:GetAttributeChangedSignal('TitleActive'),refreshButton)
refreshButton();ensureTicker()
script.Destroying:Connect(function()
 dead=true;stopSpin();for _,c in ipairs(connections)do c:Disconnect()end;table.clear(connections)
 clearBursts();clearEffects()
 attnToken+=1;almostToken+=1
 for _,t in ipairs(glowTweens)do t:Cancel()end;table.clear(glowTweens)
 for _,s in ipairs(tickVoices)do s:Destroy()end;table.clear(tickVoices)
 if EmbeddedImage then pcall(EmbeddedImage.Release,packIcon.Picture);pcall(EmbeddedImage.Release,headerPack.Picture)end
 hud:Destroy();overlay:Destroy()
end)
