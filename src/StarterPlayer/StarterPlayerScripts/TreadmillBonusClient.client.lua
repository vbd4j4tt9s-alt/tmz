-- R123: treadmill bonus rolls (client view only). The server (TreadmillBonusService) counts treadmill time, owns the
-- READY count, decides every result and grants the pack before this script animates anything.
--  * "Next roll 6:12" progress bar above the player while on the treadmill (BillboardGui, local only).
--  * BONUS ROLL button (count badge at 2) placed clear of every HUD box (TreadmillBonusRules.Place over HudLayout).
--  * Crate-style strip: pack cards slide, click per card under the marker (max 30/s, pitch rises as it slows), ease to
--    a stop on the server's result; Legendary / Mythic / Secret light up the card and panel borders, with a fanfare.
--    ReducedMotion: short spin, no ambient motion.
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
local Mixer=optional('AudioMixer');local Timing=optional('SoundTiming');local Notices=optional('HudNoticeLayout')
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
 local extra={}
 if Notices then
  local inset=GuiService.TopbarInset;local top=typeof(inset)=='Rect'and inset.Height>0 and inset.Max.Y or 36
  local ok,rows=pcall(Notices.Calculate,w,h,top,Rules.NoticeFlags)
  if ok then for name,row in pairs(rows)do if type(row)=='table'then table.insert(extra,{N=name,X=row.X-row.Width/2,Y=row.Y,W=row.Width,H=row.Height})end end end
 end
 local r=Rules.Place(m,w,h,Layout.HudBoxes(m,w,h,true),extra)
 button.Position=UDim2.fromOffset(r.X,r.Y);button.Size=UDim2.fromOffset(r.W,r.H)
 title.TextSize=r.H>=50 and 20 or 17
 -- Narrow phones get the text-only size: drop the gift icon and use the full width for the caption.
 local icon=r.W>=140;gift.Visible=icon;local left=icon and 46 or 8
 title.Position=UDim2.fromOffset(left,2);title.Size=UDim2.new(1,-left-8,.58,0)
 sub.Position=UDim2.new(0,left,.58,-2);sub.Size=UDim2.new(1,-left-8,.36,0)
end
connect(hud:GetPropertyChangedSignal('AbsoluteSize'),layoutButton);task.defer(layoutButton)
local function flashMessage(message)
 messageUntil=os.clock()+2.5;sub.Text=message;refreshButton()
 task.delay(2.6,refreshButton)
end
-- Roll overlay ---------------------------------------------------------------------------------------------------
-- R124: framed panel (gold ribbon header, inner gold line, corner studs, twinkling dots), strip window with soft side
-- fades and a glowing marker; Legendary / Mythic / Secret cards carry their own designs; the result lights up the
-- BORDERS (card + panel), never a full-panel flash; rows and buttons are stacked so nothing overlaps.
local oldRoll=pg:FindFirstChild('TreadmillBonusRoll');if oldRoll then oldRoll:Destroy()end
local overlay=make('ScreenGui',{Name='TreadmillBonusRoll',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=60,Enabled=false,
 ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
make('Frame',{Name='Backdrop',BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,Size=UDim2.fromScale(1,1),Active=true},overlay)
local panel=make('Frame',{Name='Panel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=Color3.new(1,1,1),ZIndex=2},overlay) -- colour comes from the gradient
round(panel,16);local panelStroke=stroke(panel,GOLD,3)
make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(66,58,150)),ColorSequenceKeypoint.new(.55,RGB(34,30,86)),ColorSequenceKeypoint.new(1,RGB(18,16,46))}),Rotation=70},panel)
local function diamond(parent,name,size,color,z)
 local d=make('Frame',{Name=name,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(size,size),Rotation=45,BackgroundColor3=color,BorderSizePixel=0,ZIndex=z},parent)
 stroke(d,INK,1);return d
end
local inner=make('Frame',{Name='InnerLine',BackgroundTransparency=1,Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-12,1,-12),ZIndex=2},panel)
round(inner,11);make('UIStroke',{Color=GOLD,Thickness=1,Transparency=.55},inner)
for i,c in ipairs({{0,0},{1,0},{0,1},{1,1}})do local d=diamond(inner,'Stud'..i,8,GOLD,3);d.Position=UDim2.fromScale(c[1],c[2])end
local twinkles={}
for i,c in ipairs({{.06,.2},{.94,.17},{.12,.62},{.9,.6},{.04,.86},{.97,.88},{.3,.08},{.72,.07},{.5,.95},{.2,.95},{.8,.95},{.62,.9}})do
 twinkles[i]=make('Frame',{Name='Twinkle'..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(c[1],c[2]),Size=UDim2.fromOffset(3,3),Rotation=45,
  BackgroundColor3=RGB(255,240,190),BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=2},panel)
end
local ribbon=make('Frame',{Name='Ribbon',AnchorPoint=Vector2.new(.5,0),BackgroundColor3=Color3.new(1,1,1),ZIndex=3},panel)
round(ribbon,9);stroke(ribbon,INK,2)
make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(255,236,140)),ColorSequenceKeypoint.new(.5,RGB(255,200,70)),ColorSequenceKeypoint.new(1,RGB(232,140,36))}),Rotation=90},ribbon)
for i,x in ipairs({0,1})do local tail=diamond(ribbon,'Tail'..i,14,RGB(214,128,30),2);tail.Position=UDim2.new(x,x==0 and 2 or-2,.5,0)end
local heading=text(ribbon,'Title','🎁 TREADMILL BONUS ROLL',19,INK);heading.ZIndex=4;heading.Size=UDim2.fromScale(1,1)
heading.TextStrokeColor3=RGB(255,248,220);heading.TextStrokeTransparency=.4
local window=make('Frame',{Name='StripWindow',BackgroundColor3=Color3.new(1,1,1),ClipsDescendants=true,ZIndex=3},panel) -- colour comes from the gradient
round(window,10);stroke(window,RGB(120,110,200),2)
make('UIGradient',{Color=ColorSequence.new(RGB(30,30,62),RGB(8,10,24)),Rotation=90},window)
local strip=make('Frame',{Name='Strip',BackgroundTransparency=1,ZIndex=4},window)
for i,x in ipairs({0,1})do
 local side=make('Frame',{Name=i==1 and'FadeLeft'or'FadeRight',AnchorPoint=Vector2.new(x,0),Position=UDim2.fromScale(x,0),Size=UDim2.new(0,64,1,0),
  BackgroundColor3=RGB(10,12,28),BorderSizePixel=0,ZIndex=7},window)
 make('UIGradient',{Transparency=NumberSequence.new(x==0 and 0 or 1,x==0 and 1 or 0)},side)
end
local markerGlow=make('Frame',{Name='MarkerGlow',BackgroundColor3=GOLD,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),
 Size=UDim2.new(0,18,1,0),BackgroundTransparency=.55,ZIndex=8},window)
make('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.2),NumberSequenceKeypoint.new(1,1)})},markerGlow)
make('Frame',{Name='Marker',BackgroundColor3=GOLD,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),
 Size=UDim2.new(0,4,1,0),ZIndex=8},window)
local arrowTop=text(window,'MarkerTop','▼',18,GOLD);arrowTop.ZIndex=9;arrowTop.AnchorPoint=Vector2.new(.5,0);arrowTop.Position=UDim2.new(.5,0,0,-4);arrowTop.Size=UDim2.fromOffset(24,20)
local arrowBottom=text(window,'MarkerBottom','▲',18,GOLD);arrowBottom.ZIndex=9;arrowBottom.AnchorPoint=Vector2.new(.5,1);arrowBottom.Position=UDim2.new(.5,0,1,4);arrowBottom.Size=UDim2.fromOffset(24,20)
local oddsLine=make('TextLabel',{Name='Odds',RichText=true,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),
 TextStrokeColor3=INK,TextStrokeTransparency=.3,TextWrapped=true,TextScaled=true,ZIndex=3},panel)
make('UITextSizeConstraint',{MaxTextSize=14,MinTextSize=9},oddsLine)
local poolLine=text(panel,'Pool','',12,RGB(200,210,255));poolLine.ZIndex=3;poolLine.Font=Enum.Font.GothamBold;poolLine.TextScaled=true
make('UITextSizeConstraint',{MaxTextSize=12,MinTextSize=8},poolLine)
local result=text(panel,'Result','',18);result.ZIndex=3;result.TextScaled=true
make('UITextSizeConstraint',{MaxTextSize=18,MinTextSize=11},result)
local actions=make('Frame',{Name='Actions',BackgroundTransparency=1,ZIndex=3},panel)
local function action(name,caption,color)
 local b=make('TextButton',{Name=name,Text=caption,TextSize=16,Font=Enum.Font.GothamBlack,TextColor3=Color3.new(1,1,1),TextStrokeColor3=INK,
  TextStrokeTransparency=.2,BackgroundColor3=color,AutoButtonColor=true,ZIndex=4,Visible=false},actions)
 round(b,10);stroke(b,INK,2)
 make('UIGradient',{Color=ColorSequence.new(Color3.new(1,1,1),RGB(190,190,205)),Rotation=90},b)
 return b
end
local skipButton=action('Skip','SKIP',RGB(96,106,168));local closeButton=action('Close','CLOSE',RGB(96,106,168))
local againButton=action('Again','ROLL AGAIN',RGB(244,146,40))
local buttonW=170
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
local function poolText(stages)
 local names={};for _,s in ipairs(stages)do table.insert(names,biomeName(s))end
 return 'Packs from: '..table.concat(names,', ')..(#stages>1 and(' (each '..Rules.Percent(1/#stages)..')')or'')..'  ·  Secret = '..Rules.Void.Label
end
local panelW,cardH=600,128
local CARD_Y=10 -- room above/below the cards for the border light-up
local function layoutOverlay()
 local view=overlay.AbsoluteSize;local w,h=view.X>0 and view.X or 1280,view.Y>0 and view.Y or 720
 panelW=math.floor(math.min(w-24,660));local short=h<420
 cardH=short and 104 or 128
 -- Rows top to bottom; each starts below the previous one, so text and buttons never overlap.
 local ribbonH=short and 26 or 30;local oddsH=short and 28 or 34;local poolH=short and 14 or 16;local resultH=short and 22 or 26;local actionH=short and 38 or 42
 local y=10
 ribbon.Position=UDim2.new(.5,0,0,y);ribbon.Size=UDim2.fromOffset(math.min(380,panelW-90),ribbonH);y+=ribbonH+8
 window.Position=UDim2.fromOffset(14,y);window.Size=UDim2.new(1,-28,0,cardH+2*CARD_Y);y+=cardH+2*CARD_Y+6
 oddsLine.Position=UDim2.fromOffset(16,y);oddsLine.Size=UDim2.new(1,-32,0,oddsH);y+=oddsH+2
 poolLine.Position=UDim2.fromOffset(16,y);poolLine.Size=UDim2.new(1,-32,0,poolH);y+=poolH+4
 result.Position=UDim2.fromOffset(16,y);result.Size=UDim2.new(1,-32,0,resultH);y+=resultH+8
 actions.Position=UDim2.fromOffset(16,y);actions.Size=UDim2.new(1,-32,0,actionH);y+=actionH+14
 panel.Size=UDim2.fromOffset(panelW,math.min(h-16,y))
 buttonW=math.floor(math.min(180,(panelW-32-24)/2))
 arrangeActions()
end
connect(overlay:GetPropertyChangedSignal('AbsoluteSize'),layoutOverlay);layoutOverlay()
local cards={};local spin,spinConn,current
local glowTweens={}
local function clearCards()
 for _,c in ipairs(cards)do if Pictures then pcall(Pictures.Clear,c.Holder)end;c.Frame:Destroy()end;table.clear(cards)
end
-- Card designs for the special tiers. Static frames; the only motion (sweep / pulse / twinkle) runs in the strip's
-- RenderStepped and only for these few cards.
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
local function animateDesign(entry,t)
 local m=entry.Motion;if not m then return end
 if m.Shine then m.Shine.Offset=Vector2.new(((t*.45)%1)*2.4-1.2,0)end
 if m.Line then m.Line.Transparency=.15+.45*(.5+.5*math.sin(t*5))end
 if m.Stars then for i,star in ipairs(m.Stars)do star.BackgroundTransparency=.1+.8*math.max(0,math.sin(t*3+i*1.7))end end
end
local function buildCard(i,pack)
 local tierName,color=Rules.Tier(pack.Variant)
 local f=make('Frame',{Name='Card'..i,BackgroundColor3=color:Lerp(RGB(16,20,44),.62),Position=UDim2.fromOffset((i-1)*Rules.Strip.Pitch,CARD_Y),
  Size=UDim2.fromOffset(Rules.Strip.CardWidth,cardH),ZIndex=5},strip)
 round(f,9);local edge=stroke(f,color,3)
 make('UIGradient',{Color=ColorSequence.new(Color3.new(1,1,1),RGB(150,150,170)),Rotation=90},f)
 local motion=Rules.Special[tierName]and design(f,tierName,color)or nil
 local holder=make('Frame',{Name='Picture',BackgroundTransparency=1,Position=UDim2.fromOffset(6,4),Size=UDim2.new(1,-12,1,-40),ZIndex=6},f)
 if Pictures then
  local proxy=Instance.new('Folder');proxy:SetAttribute('SeedPackTool',true);proxy:SetAttribute('Stage',pack.Stage)
  proxy:SetAttribute('BagVariant',pack.Variant);proxy:SetAttribute('PackMutation','None')
  pcall(Pictures.Show,holder,proxy,2)
 else
  local icon=text(holder,'Icon','🎒',34);icon.Size=UDim2.fromScale(1,1);icon.ZIndex=6
 end
 local name=text(f,'Rarity',string.upper(tierName),13,color);name.ZIndex=7;name.Size=UDim2.new(1,-6,0,16);name.Position=UDim2.new(0,3,1,-35)
 local biome=text(f,'Biome',pack.Variant==Rules.Void.Variant and Rules.Void.Label or biomeName(pack.Stage),11,RGB(225,230,255));biome.ZIndex=7;biome.Font=Enum.Font.GothamBold
 biome.Size=UDim2.new(1,-6,0,14);biome.Position=UDim2.new(0,3,1,-18)
 local entry={Frame=f,Holder=holder,Stroke=edge,Pack=pack,Tier=tierName,Color=color,Motion=motion};cards[i]=entry;return entry
end
local function place(offset)
 local center=window.AbsoluteSize.X>0 and window.AbsoluteSize.X/2 or(panelW-28)/2
 strip.Position=UDim2.fromOffset(math.floor(center-Rules.Strip.CardWidth/2-offset+.5),0)
end
local finish
local function stopSpin()if spinConn then spinConn:Disconnect();spinConn=nil end end
local function stopGlow()for _,t in ipairs(glowTweens)do t:Cancel()end;table.clear(glowTweens);panelStroke.Color=GOLD;panelStroke.Thickness=3 end
local function play(tween)table.insert(glowTweens,tween);tween:Play();return tween end
local function celebrate(entry,res)
 local special=Rules.Special[res.Rarity]==true
 result.Text=(special and'✨ 'or'')..'You got a '..string.upper(res.Rarity)..' '..(res.Label or'pack')..'!'
 result.TextColor3=entry.Color
 if Audio then pcall(Audio.Play,special and'GemClaim'or'KaChing')end
 local reduced=GuiService.ReducedMotionEnabled
 if not reduced then
  local grow=make('UIScale',{Scale=1},entry.Frame);Tween:Create(grow,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.05}):Play()
 end
 if special then
  local big=res.Rarity~='Legendary'
  if Reveal then pcall(function()Reveal.Preload();Reveal.Play(big and'Impact'or'Chime',big and 1.1 or .8)
   if big then Reveal.Play('Chime',.7)end end)end
  -- Light-up on the borders: the card's own border flashes white then settles in its colour and pulses inside a
  -- glow ring; the panel border takes the colour and pulses with it.
  entry.Stroke.Thickness=5;entry.Stroke.Color=Color3.new(1,1,1)
  play(Tween:Create(entry.Stroke,TweenInfo.new(reduced and .2 or .6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Color=entry.Color}))
  local ring=make('Frame',{Name='BorderGlow',BackgroundTransparency=1,Position=UDim2.fromOffset(-4,-4),Size=UDim2.new(1,8,1,8),ZIndex=4},entry.Frame)
  round(ring,12);local glow=make('UIStroke',{Name='Glow',Color=entry.Color:Lerp(Color3.new(1,1,1),.25),Thickness=4,Transparency=reduced and .35 or .05},ring)
  panelStroke.Color=entry.Color;panelStroke.Thickness=4
  if not reduced then
   play(Tween:Create(glow,TweenInfo.new(.55,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.7}))
   play(Tween:Create(panelStroke,TweenInfo.new(.55,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Thickness=6}))
  end
 end
end
finish=function()
 if not spin or not current then return end
 local offset=spin:Skip();place(offset);stopSpin()
 local entry=cards[spin.Win];if entry then celebrate(entry,current)end
 skipButton.Visible=false;closeButton.Visible=true;againButton.Visible=ready()>0
 againButton.Text='ROLL AGAIN ('..ready()..')'
 arrangeActions()
end
local function startRoll(res)
 rolling=true;refreshButton();clearCards();stopSpin()
 current=res;overlay.Enabled=true;layoutOverlay()
 stopGlow();result.Text='';result.TextColor3=Color3.new(1,1,1)
 local stages=Rules.DecodePool(res.Pool);if #stages==0 then stages={res.Stage}end
 oddsLine.Text=oddsText();poolLine.Text=poolText(stages)
 local winner={Stage=res.Stage,Variant=res.Variant}
 local rng=Random.new()
 for i,pack in ipairs(Rules.BuildStrip(stages,winner,function()return rng:NextNumber()end))do buildCard(i,pack)end
 strip.Size=UDim2.fromOffset(#cards*Rules.Strip.Pitch,cardH+2*CARD_Y)
 spin=Rules.NewSpin({Reduced=GuiService.ReducedMotionEnabled,Jitter=rng:NextNumber(-.3,.3)})
 place(spin.Offset)
 skipButton.Visible=true;closeButton.Visible=false;againButton.Visible=false;arrangeActions()
 spinConn=Run.RenderStepped:Connect(function(dt)
  local offset,tick,pitch,done=spin:Step(dt);place(offset)
  if tick then tickSound(pitch)end
  if done then finish()end
 end)
end
local function close()
 stopSpin();if spin and not spin.Done then finish()end
 stopGlow();overlay.Enabled=false;rolling=false;clearCards();current=nil;spin=nil;refreshButton()
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
-- R124: ambient motion while the roll window is open (twinkles, special-card designs); nothing when closed or with
-- ReducedMotion.
local ambient=0
connect(Run.RenderStepped,function(dt)
 if not overlay.Enabled or GuiService.ReducedMotionEnabled then return end
 ambient+=dt
 for i,d in ipairs(twinkles)do d.BackgroundTransparency=.25+.7*(.5+.5*math.sin(ambient*2.2+i*1.3))end
 for _,entry in ipairs(cards)do if entry.Motion then animateDesign(entry,ambient)end end
end)
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
