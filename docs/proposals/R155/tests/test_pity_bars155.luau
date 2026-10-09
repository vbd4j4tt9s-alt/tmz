--!nocheck
-- R155 pack pity bars (owner: "2 separate bars above the hot bar one coloured gold the other coloured purple", "always visible and polished properly") on the Roblox mock
-- with the REAL PityBars155 / PackPity155 / HudLayout / NoticeFeed83 of this checkout:
--  1. always there   - its own ScreenGui (DisplayOrder 23: under the hotbar / Bag 25, the tutorial 25 / 26, BASE / TRACK 24), both bars from the start (0/10), gold left, purple right
--  2. values         - "3/10 pity" / "3/10 event pity", the fill in ten steps easing to the new count (Reduced Motion: at once), the accessible label
--  3. 9/10           - "9/10 next one's lucky!", a glow that pulses (steady with Reduced Motion), only on that bar
--  4. held pack      - the bar of the held pack's group brighter and 1.06x, the other dimmer; Mech / Void / Verity = the purple one; nothing held = both plain
--  5. lucky pack     - the notice ("LUCKY PACK! x1.5 luck"), the pop (full, flash, ring, shine, scale), then back to 0/10; whichever of the two signals comes first;
--                      waits for the reveal card / story scene (the notice waits only for a scene); Reduced Motion: no scale / shine / ring
--  6. hidden / dim   - hidden under a menu (SeedMenu, the Bag) or when the hotbar is hidden; dimmed under a reveal card and while the tutorial card is up
--  7. layout         - 30 screens (PC, landscape / portrait phones, tablets): inside the screen, above the hotbar and its item name, clear of every HUD box (menu,
--                      balances, status, jump / thumb zones, owner tools, BASE / TRACK) and of the SKIP corner, text fits; the real gui matches; it follows the hotbar's
--                      frame found by name (and its moves), with HudLayout's default without it
local W=require('./world');local R=W.R
local checks,fails=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end;return c end
local V2=R.Vector2.new
local Players=W.service('Players')
local player=R.new('Player');player.Name='Ann';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local Pity=W.module('PackPity155');local B=W.module('PityBars155');local Hud=W.module('HudLayout')
local notices={}
local s=B.Start(player,{Notice=function(text,color)notices[#notices+1]={Text=text,Color=color,At=R.clock}end})
local gui=pg:FindFirstChild(B.Name)
local function frames(n,dt)W.frames(n,dt or 1/60)end
local function bar(g)return s.Bars[g]end
local function fillW(g)local f=bar(g).Fill;return f.Visible and f.Size.X.Offset or 0 end
local function innerW()return s.Placement.Bar.W-4 end
-- 1. always there -------------------------------------------------------------------------------------------------------------------------------
check(gui and gui:IsA('ScreenGui')and gui.DisplayOrder==23 and gui.ResetOnSpawn==false and gui.ScreenInsets==R.Enum.ScreenInsets.CoreUISafeInsets,'its own ScreenGui, DisplayOrder 23 (under the hotbar / Bag 25, the tutorial 25 / 26, BASE / TRACK and the plant indicators 24), the HUD\'s safe area, kept on respawn')
frames(2)
check(s.Root.Visible and bar('Normal').Root.Parent==s.Root and bar('Event').Root.Parent==s.Root,'both bars are on the HUD from the start, nothing in hand')
check(bar('Normal').Label.Text=='0/10 pity'and bar('Event').Label.Text=='0/10 event pity'and fillW('Normal')==0,'before any count arrives: "0/10 pity" and "0/10 event pity", empty')
check(bar('Normal').Root.Position.X.Offset<bar('Event').Root.Position.X.Offset and bar('Normal').Root.Position.Y.Offset==bar('Event').Root.Position.Y.Offset,'gold (normal) on the left, purple (event) on the right, side by side')
local gold,purple=Pity.Colors.Normal,Pity.Colors.Event
check(bar('Normal').FillGradient.Color.A==gold.Light and bar('Normal').FillGradient.Color.B==gold.Deep and bar('Event').FillGradient.Color.A==purple.Light and bar('Event').FillGradient.Color.B==purple.Deep,'the normal bar fills GOLD, the event bar PURPLE')
check(#bar('Normal').Ticks==9 and #bar('Event').Ticks==9,'ten steps: nine ticks on each bar')
-- 2. values ------------------------------------------------------------------------------------------------------------------------------------
player:SetAttribute('PackPityNormal',3);player:SetAttribute('PackPityEvent',3)
frames(1)
local w1=fillW('Normal');local want=math.floor(innerW()*.3+.5)
check(bar('Normal').Label.Text=='3/10 pity'and bar('Event').Label.Text=='3/10 event pity','"3/10 pity" and "3/10 event pity"')
check(w1>0 and w1<want,'the fill eases to the new count (one frame in: '..w1..' of '..want..' px)')
frames(90)
check(fillW('Normal')==want and fillW('Event')==want,'... and lands on 3 of 10 steps ('..fillW('Normal')..' px)')
check(s.Root:GetAttribute('AccessibleLabel')=='3/10 pity, 3/10 event pity','the accessible label reads both')
player:SetAttribute('PackPityEvent',7);frames(90)
check(fillW('Event')==math.floor(innerW()*.7+.5)and fillW('Normal')==want,'each bar moves on its own (event 7/10, normal still 3/10)')
-- 3. 9/10 ---------------------------------------------------------------------------------------------------------------------------------------
player:SetAttribute('PackPityNormal',9);frames(60)
local g1=bar('Normal').Glow.BackgroundTransparency;frames(12);local g2=bar('Normal').Glow.BackgroundTransparency
check(bar('Normal').Label.Text=='9/10 next one\'s lucky!','9/10: "9/10 next one\'s lucky!"')
check(g1<.8 and g2<.8 and math.abs(g1-g2)>.01,'9/10: the bar glows, a soft pulse ('..string.format('%.2f -> %.2f',g1,g2)..')')
check(bar('Event').Glow.BackgroundTransparency>=.999,'... only the bar at 9/10 glows')
check(bar('Normal').Edge.Color==gold.Light,'... its edge lights up')
-- 4. held pack ------------------------------------------------------------------------------------------------------------------------------------
local char=R.new('Model');char.Name='Ann';player.Character=char;player.CharacterAdded:Fire(char)
local function hold(variant)
 for _,t in ipairs(char:GetChildren())do t.Parent=nil end
 if variant then local t=R.new('Tool');t.Name='Pack';t:SetAttribute('SeedPackTool',true);t:SetAttribute('BagVariant',variant);t.Parent=char end
 frames(60)
end
player:SetAttribute('PackPityNormal',4);frames(60)
hold('Pack03')
check(s.Held=='Normal'and math.abs(bar('Normal').Scale.Scale-1.06)<.01 and bar('Event').Scale.Scale==1,'holding a world pack: the GOLD bar is slightly larger (x1.06)')
check(bar('Normal').Edge.Thickness>bar('Event').Edge.Thickness and bar('Normal').Track.BackgroundTransparency<bar('Event').Track.BackgroundTransparency,'... brighter (thicker edge, solid track); the purple one stays, a little dimmer')
check(bar('Event').Label.TextTransparency>0 and bar('Event').Label.TextTransparency<.5 and bar('Normal').Label.TextTransparency==0,'... the other bar is still readable (dimmed, not hidden)')
for _,v in ipairs({'MechLimited','EclipseReliquary','VerityReliquary'})do hold(v);check(s.Held=='Event'and math.abs(bar('Event').Scale.Scale-1.06)<.01 and math.abs(bar('Normal').Scale.Scale-1)<.01,'holding a '..v..' pack: the PURPLE bar is highlighted')end
hold(nil)
check(s.Held==nil and math.abs(bar('Normal').Scale.Scale-1)<.01 and math.abs(bar('Event').Scale.Scale-1)<.01 and bar('Event').Label.TextTransparency==0,'nothing in hand: both plain, both fully visible')
-- 5. lucky pack ----------------------------------------------------------------------------------------------------------------------------------
local function luckyOpen(group,countFirst)
 local key,attr=Pity.LuckyAttribute[group],Pity.Attribute[group]
 if countFirst then player:SetAttribute(attr,0);frames(3)end
 player:SetAttribute(key,(player:GetAttribute(key)or 0)+1)
 if not countFirst then frames(2);player:SetAttribute(attr,0)end
end
player:SetAttribute('PackPityNormal',9);frames(30)
local before=#notices
luckyOpen('Normal',false)
frames(3)
check(bar('Normal').Pending==1 and bar('Normal').Label.Text==Pity.PopText,'a lucky normal pack: at once the bar says "'..Pity.PopText..'" and fills up')
local sawScale,sawShine,sawRing,sawFlash,full,popAt=0,false,false,false,true,nil
for _=1,80 do
 frames(1);local b=bar('Normal');popAt=popAt or b.PopAt
 sawScale=math.max(sawScale,b.Scale.Scale);sawShine=sawShine or b.Shine.Visible;sawRing=sawRing or b.Ring.Visible;sawFlash=sawFlash or b.Flash.BackgroundTransparency<.5
 if b.PopAt and R.clock-b.PopAt<.9 and fillW('Normal')<innerW()-2 then full=false end
end
check(#notices==before+1 and notices[#notices].Text==Pity.NoticeText('Normal')and notices[#notices].Text:find('LUCKY PACK! x1.5 luck',1,true),'the notice: "'..tostring(notices[#notices]and notices[#notices].Text)..'"')
check(popAt~=nil and bar('Normal').Pending==0,'the bar pops')
check(sawScale>1.15,'... a pop: it scales up (to x'..string.format('%.2f',sawScale)..') and settles back')
check(sawShine and sawRing and sawFlash,'... a white flash, a ring and a shine sweeping across')
check(full,'... the fill stays full while it pops')
frames(120)
check(bar('Normal').PopAt==nil and bar('Normal').Label.Text=='0/10 pity'and fillW('Normal')==0 and math.abs(bar('Normal').Scale.Scale-1)<.001 and not bar('Normal').Shine.Visible,'... then it drains back to "0/10 pity" and rests')
check(player:GetAttribute('PackPityLuckyNormal')==1 and bar('Event').PopAt==nil,'(the event bar did not pop)')
-- the count arrives first, the lucky signal right after: no flash of "0/10" before the pop
player:SetAttribute('PackPityEvent',9);frames(30)
player:SetAttribute('PackPityEvent',0);frames(2)
local mid=bar('Event').Label.Text
player:SetAttribute('PackPityLuckyEvent',1);frames(40)
check(mid~='0/10 event pity'and bar('Event').PopAt~=nil and notices[#notices].Text==Pity.NoticeText('Event'),'the count can come first: the bar waits a moment instead of dropping to 0 ("'..mid..'"), then pops; the notice says "'..Pity.NoticeText('Event')..'"')
frames(150)
check(bar('Event').Label.Text=='0/10 event pity'and fillW('Event')==0,'... and rests at "0/10 event pity"')
-- an owner command dropping a count (no lucky pack): the bar just moves after the short wait, no pop
player:SetAttribute('PackPityNormal',6);frames(90);player:SetAttribute('PackPityNormal',2);frames(90)
check(bar('Normal').Label.Text=='2/10 pity'and bar('Normal').PopAt==nil and fillW('Normal')==math.floor(innerW()*.2+.5),'a count set lower (/test pity set): the bar moves down, no pop')
-- the reveal card: its words sit where the bars are, so the bars step aside; a lucky pack gets a TAG on the card (between the seed and its "1 in N"), the bar pops
-- once the seed is collected; the compact card gets the tag under it and the bar pops at once; a story scene holds the notice and the pop; no reveal: the notice
local tagGui=pg:FindFirstChild(B.TagName)
check(tagGui and tagGui.DisplayOrder==97 and tagGui.IgnoreGuiInset==true,'the lucky tag has its own full-screen layer just above the reveal card (96) and under the notices (100)')
local function tag()return tagGui:FindFirstChild('LuckyTag')end
local function tagShown()local t=tag();return t and t.Visible and t.BackgroundTransparency<.5 end
player:SetAttribute('PackPityNormal',9);frames(30)
player:SetAttribute('RarePullCinematic','Ladder');frames(5)
check(s.Dim==1 and bar('Normal').Track.BackgroundTransparency>=.999 and bar('Normal').Label.TextTransparency>=.999,'under the reveal card the bars step aside (its seed name and "1 in N" sit right there)')
local n0=#notices;luckyOpen('Normal',false);local sawTagPop=0
for _=1,40 do frames(1);local t=tag();if t and t.Visible then sawTagPop=math.max(sawTagPop,t:FindFirstChild('Scale').Scale)end end
check(tagShown()and tag().Label.Text==Pity.TagText('Normal')and #notices==n0,'a lucky pack with its reveal card up: the card gets the tag "'..Pity.TagText('Normal')..'" (no notice over the card\'s title)')
do
 local t=tag();local h=tagGui.AbsoluteSize.Y;local Rules=W.module('RarePullRules');local L=Rules.Layout(false,false,5)
 local top=(.5+Rules.Tier(5).SeedSize/2)*h;local bottom=(L.Odds.Y-L.Odds.H/2)*h
 local y=t.Position.Y.Offset;local th=t.Size.Y.Offset
 check(y-th/2>=top-.5 and y+th/2<=bottom+.5 and math.abs(t.Position.X.Offset-tagGui.AbsoluteSize.X/2)<=1,('... in the free band of the card: between the seed (to %.0f px) and the "1 in N" line (from %.0f px): %d..%d px, centred'):format(top,bottom,y-th/2,y+th/2))
end
check(sawTagPop>1.05 and tag():FindFirstChild('Scale').Scale==1,'... it pops in (to x'..string.format('%.2f',sawTagPop)..') and settles')
check(bar('Normal').Pending==1 and bar('Normal').PopAt==nil,'... the bar holds "'..Pity.PopText..'" (full, out of sight) and waits for the card')
frames(120);check(tagShown(),'... the tag stays while the result waits to be collected')
player:SetAttribute('RarePullCinematic',nil);frames(20)
check(bar('Normal').PopAt~=nil and s.Dim==0 and not tagShown(),'the seed is collected: the card and its tag go, the bars come back and the gold one pops')
frames(150)
player:SetAttribute('PackPityEvent',9);frames(30)
player:SetAttribute('RarePullCinematic','InPlace');frames(5)
check(s.Dim==0,'the compact card (upper third, "skip pack animations"): the bars stay')
local n2=#notices;luckyOpen('Event',false);frames(40)
local h2=tagGui.AbsoluteSize.Y;local Lc=W.module('RarePullRules').Layout(false,true,5)
check(tagShown()and tag().Label.Text==Pity.TagText('Event')and bar('Event').PopAt~=nil and #notices==n2 and tag().Position.Y.Offset-tag().Size.Y.Offset/2>=(Lc.Name.Y+Lc.Name.H/2)*h2,'a lucky event pack with the compact card: "'..Pity.TagText('Event')..'" under the card, the purple bar pops at once')
player:SetAttribute('RarePullCinematic',nil);frames(20);check(not tagShown(),'... the tag goes with the card')
frames(150)
player:SetAttribute('PackPityNormal',9);frames(30)
player:SetAttribute('RarePullCinematic','Scene');local n1=#notices;luckyOpen('Normal',false);frames(120)
check(#notices==n1 and bar('Normal').PopAt==nil and not tagShown(),'a story scene (it hides the HUD): the notice and the pop both wait')
player:SetAttribute('RarePullCinematic',nil);frames(20)
check(#notices==n1+1 and bar('Normal').PopAt~=nil,'... and both come when it ends')
frames(150)
-- Reduced Motion
W.Gui.ReducedMotionEnabled=true;frames(2)
player:SetAttribute('PackPityEvent',4);frames(1)
check(fillW('Event')==math.floor(innerW()*.4+.5),'Reduced Motion: a count change shows at once (no easing)')
player:SetAttribute('PackPityEvent',9);frames(2)
local r1=bar('Event').Glow.BackgroundTransparency;frames(15);local r2=bar('Event').Glow.BackgroundTransparency
check(r1<.8 and r1==r2,'Reduced Motion: the 9/10 glow is steady (no pulse)')
hold('MechLimited')
check(bar('Event').Scale.Scale==1 and bar('Event').Edge.Thickness>bar('Normal').Edge.Thickness,'Reduced Motion: the held bar is highlighted by colour, not size')
luckyOpen('Event',false);frames(25)
local maxScale,shine,ring=1,false,false
for _=1,120 do frames(1);maxScale=math.max(maxScale,bar('Event').Scale.Scale);shine=shine or bar('Event').Shine.Visible;ring=ring or bar('Event').Ring.Visible end
check(maxScale==1 and not shine and not ring,'Reduced Motion: a lucky pack has no pop scale, no shine sweep, no ring')
player:SetAttribute('PackPityNormal',9);frames(5);player:SetAttribute('RarePullCinematic','Ladder');luckyOpen('Normal',false)
local tagMax,tagShine=0,false;for _=1,60 do frames(1);local t=tag();if t.Visible then tagMax=math.max(tagMax,t:FindFirstChild('Scale').Scale);tagShine=tagShine or t:FindFirstChild('Shine').Visible end end
check(tagShown()and tagMax==1 and not tagShine,'Reduced Motion: the card\'s tag appears without a pop or a shine')
player:SetAttribute('RarePullCinematic',nil);frames(200)
check(notices[#notices].Text==Pity.NoticeText('Event')and bar('Event').Label.Text=='0/10 event pity'and fillW('Event')==0,'... it still tells you (the notice, "'..Pity.PopText..'", a steady glow) and goes back to 0/10')
hold(nil);W.Gui.ReducedMotionEnabled=false;frames(30)
-- 6. hidden / dimmed ---------------------------------------------------------------------------------------------------------------------------
pg:SetAttribute('SeedMenu','Shop');check(not s.Root.Visible,'a menu over the HUD (SeedMenu): hidden, like the status HUD')
pg:SetAttribute('SeedMenu','Inventory');check(not s.Root.Visible,'the Bag sheet open: hidden (never over the Bag)')
pg:SetAttribute('SeedMenu',nil);check(s.Root.Visible,'menu closed: back')
pg:SetAttribute('TutorialCardBottom',140);frames(30)
check(s.Dim>0 and s.Root.Visible and bar('Normal').Label.TextTransparency>0 and bar('Normal').Label.TextTransparency<1,'the tutorial card is up: still there, dimmed (the tutorial draws above it)')
pg:SetAttribute('TutorialCardBottom',nil);frames(30);check(s.Dim==0,'... and full again after it')
-- 7. layout -------------------------------------------------------------------------------------------------------------------------------------
local function overlaps(a,b,pad)pad=pad or 0;return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
local SCREENS={
 {1920,1080,false,'PC 1080p'},{2560,1440,false,'PC 1440p'},{1366,768,false,'laptop'},{1280,720,false,'PC 720p'},{1024,768,false,'small window'},{800,600,false,'tiny window'},{1600,900,false,'PC 900p'},
 {844,390,true,'iPhone 14 landscape'},{932,430,true,'iPhone Pro Max landscape'},{667,375,true,'iPhone 8 landscape'},{568,320,true,'iPhone SE landscape'},{740,360,true,'Android landscape'},{800,360,true,'Android wide'},{896,414,true,'iPhone 11 landscape'},
 {390,844,true,'iPhone 14 portrait'},{375,667,true,'iPhone 8 portrait'},{360,640,true,'Android portrait'},{414,896,true,'iPhone 11 portrait'},{320,568,true,'iPhone SE portrait'},{360,800,true,'Android tall'},
 {1024,768,true,'iPad landscape'},{768,1024,true,'iPad portrait'},{1180,820,true,'iPad Air landscape'},{820,1180,true,'iPad Air portrait'},{1366,1024,true,'iPad Pro landscape'},
 {1280,800,true,'Android tablet'},{800,1280,true,'Android tablet portrait'},{1920,1080,true,'touch PC'},{1440,900,false,'MacBook'},{1280,1024,false,'5:4 monitor'},
}
local WORDS={{'Normal',0},{'Normal',9},{'Event',3},{'Event',9},{'Normal',0,true}}
local layoutFails=0
for _,sc in ipairs(SCREENS)do
 local w,h,touch,name=sc[1],sc[2],sc[3],sc[4]
 local m=Hud.Read(V2(w,h),touch,nil)
 local place=B.Place(w,h,m,nil)
 local pair=place.Pair;local bad={}
 if not place.Clear then bad[#bad+1]='no clear spot'end
 if pair.X<0 or pair.Y<0 or pair.X+pair.W>w or pair.Y+pair.H>h then bad[#bad+1]='off screen'end
 local dock=B.DefaultDock(m,w,h);local detail=m.HotbarDetails~=false and 44 or 0
 if pair.Y+pair.H>dock.Y-detail-4 then bad[#bad+1]='not above the hotbar + item name'end
 if pair.X+pair.W<dock.X+8 or pair.X>dock.X+dock.W-8 then bad[#bad+1]='not over the hotbar'end
 if pair.Y+pair.H<dock.Y-detail-80 then bad[#bad+1]='not slightly above the hotbar ('..math.floor(dock.Y-detail-pair.Y-pair.H)..' px up)'end
 -- what the bars can cover: the bar, its glow (5 px) and the held bar's 1.06 scale
 local gx,gy=5+place.Bar.W*.03,5+place.Bar.H*.03;local ext={X=pair.X-gx,Y=pair.Y-gy,W=pair.W+gx*2,H=pair.H+gy*2}
 for _,b in ipairs(Hud.HudBoxes(m,w,h,false))do if overlaps(ext,b,0)then bad[#bad+1]='covers '..tostring(b.N)end end
 if m.Travel and overlaps(ext,{X=m.Travel.X,Y=m.Travel.Y,W=m.Travel.W,H=m.Travel.H},0)then bad[#bad+1]='covers BASE / TRACK'end
 if overlaps(ext,B.SkipZone(w,h),0)then bad[#bad+1]='in the SKIP corner'end
 local shown={}
 for _,wd in ipairs(WORDS)do
  local t=B.Words(wd[1],wd[2],place.Bar.W,place.Bar.H,wd[3]);shown[#shown+1]=t
  local size=B.TextSize(t,place.Bar.W,place.Bar.H);local width=utf8.len(t)*size*.52
  if size<B.MinText or width>place.Bar.W-math.floor(place.Bar.H*1.3)then bad[#bad+1]='"'..t..'" does not fit ('..size..' px)'end
 end
 if place.Bar.H<(touch and 16 or 20) or place.Bar.W<96 then bad[#bad+1]='bars too small'end
 if #bad>0 then layoutFails+=1;print(('FAIL: %s %dx%d%s: %s'):format(name,w,h,touch and' touch'or'',table.concat(bad,'; ')))end
 print(('LAYOUT %s %dx%d%s bars %dx%d%s at %d,%d (pair %dx%d, %+d px off centre) above the hotbar by %d px; text %d px "%s"'):format(name,w,h,touch and' touch'or'',place.Bar.W,place.Bar.H,place.Stacked and' stacked'or'',math.floor(pair.X),math.floor(pair.Y),math.floor(pair.W),pair.H,math.floor(pair.X+pair.W/2-(dock.X+dock.W/2)),math.floor(dock.Y-detail-pair.Y-pair.H),B.TextSize(shown[2],place.Bar.W,place.Bar.H),shown[2]))
end
check(layoutFails==0,#SCREENS..' screens: inside the screen, slightly above the hotbar and its item name (centred on it), clear of the menu, balances, status, jump / thumb zones, owner tools, BASE / TRACK and the SKIP corner; every text fits ('..layoutFails..' failing)')
-- the real gui follows the screen
for _,sc in ipairs({{844,390,true},{390,844,true},{1920,1080,false}})do
 W.UIS.TouchEnabled=sc[3];gui.AbsoluteSize=V2(sc[1],sc[2]);frames(2)
 local m=Hud.Read(V2(sc[1],sc[2]),sc[3],nil);local place=B.Place(sc[1],sc[2],m,nil)
 local p=bar('Event').Root.Position;local z=bar('Event').Root.Size
 check(p.X.Offset==math.floor(place.Centers.Event.X+.5)and p.Y.Offset==math.floor(place.Centers.Event.Y+.5)and z.X.Offset==place.Bar.W and z.Y.Offset==place.Bar.H,('the real bars sit where the layout says on %dx%d'):format(sc[1],sc[2]))
end
W.UIS.TouchEnabled=false;gui.AbsoluteSize=V2(1280,720);frames(2)
-- the hotbar's frame, found by name: the bars centre on it and follow it
do
 local m=Hud.Read(V2(1280,720),false,nil);local d=B.DefaultDock(m,1280,720)
 local hot=R.new('ScreenGui');hot.Name='ChestToolHotbar';hot.AbsolutePosition=V2(0,0);hot.AbsoluteSize=V2(1280,720);hot.Parent=pg
 local dock=R.new('Frame');dock.Name='Dock';dock.AbsoluteSize=V2(d.W,d.H);dock.AbsolutePosition=V2(d.X-20,d.Y);dock.Parent=hot
 frames(2);s.Relayout();frames(2)
 local cx=(bar('Normal').Root.Position.X.Offset+bar('Event').Root.Position.X.Offset)/2
 check(math.abs(cx-(d.X-20+d.W/2))<=1,'the hotbar frame (ChestToolHotbar.Dock) is found by name: the bars centre on it ('..cx..')')
 dock.AbsolutePosition=V2(d.X-40,d.Y);frames(3)
 cx=(bar('Normal').Root.Position.X.Offset+bar('Event').Root.Position.X.Offset)/2
 check(math.abs(cx-(d.X-40+d.W/2))<=1,'... and follow it when it moves')
 dock.AbsoluteSize=V2(30,10);frames(3)
 cx=(bar('Normal').Root.Position.X.Offset+bar('Event').Root.Position.X.Offset)/2
 check(math.abs(cx-(d.X+d.W/2))<=1,'a frame that is not the hotbar\'s shape (mid-layout) is not trusted: HudLayout\'s default place')
 dock.Visible=false;frames(3);check(not s.Root.Visible,'the hotbar hidden: the bars hide with it')
 dock.Visible=true;frames(3);check(s.Root.Visible,'... and come back with it')
 hot:Destroy();s.Relayout();frames(2)
end
-- the default notice path: the top notices (NoticeFeed83)
do
 local s2=B.Start(player,{})
 local key=Pity.LuckyAttribute.Normal;player:SetAttribute('PackPityNormal',9);player:SetAttribute(key,(player:GetAttribute(key)or 0)+1);player:SetAttribute('PackPityNormal',0)
 frames(40)
 local root=pg:FindFirstChild('ChestChaseNotices83');local found=false
 if root then for _,d in ipairs(root:GetDescendants())do if d:IsA('TextLabel')and tostring(d.Text):find('LUCKY PACK! x1.5 luck',1,true)then found=true end end end
 check(found,'without a test hook the lucky notice goes to the game\'s top notices (NoticeFeed83), in the bar\'s colour')
 s2:Destroy()
 check(pg:FindFirstChild(B.Name)==nil,'Destroy removes the gui')
 local ok=pcall(function()player:SetAttribute('PackPityNormal',5);player:SetAttribute(key,99);frames(40)end)
 check(ok,'nothing runs after Destroy (attribute changes do no harm)')
end
print(('R155 pity bars: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
