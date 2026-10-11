--!nocheck
-- R157 HUD (the owner-approved R156 previews, built together): the pity bars v2, the reveal fixes and DAILY / INVITE in the menu wheel, on the Roblox mock with the REAL
-- HudLayout / PityBars155 / PackPity155 / RarePullCard / RarePullRules / TreadmillBonusRules / HudNoticeLayout of this checkout. The layout half (no client script runs here;
-- test_hud157_client.luau drives the real scripts):
--  1. bars      - the gap to the slots on every screen (8 px on a computer, 6 on a phone, 5 under a thin 16 px phone bar), shade 1 "Fresh" exactly, the clover instead of the
--                 diamond, the held item's name rows ABOVE the bars (and hidden on 320 x 568, 360 x 640 and 360 x 740, as approved), the event notice's gold star
--  2. SKIP      - only Secret / Cosmic / King: no SkipFrom and no pill for Common..Mythic; a story scene's pill in the safe area's corner, 14 px in, stepping left only of a thumb
--                 control that is really on screen; the in-place card's pill clear of the HUD, the bars and the name rows
--  3. card      - Common..Mythic and the compact card fitted between BASE / TRACK (HudLayout.TravelBottom, the same row TravelButtons draws by) and the NEW top of the bars and
--                 the name rows, with the .md's margin rule; five rows in order; the collect hint directly under the name (the story result too); the lucky tag follows the rows
--  4. wheel     - the five-option half circle per screen: the .md table (MENU centre, radius up / down, offsets), DAILY down-right and INVITE straight down; the tight fan on the
--                 short landscape; smaller buttons under ~280 px; DAILY / INVITE in a row beyond SHOP under ~230 px; R113's phantom m.Travel gone
--  5. overlaps  - on the R155 36-screen set and the previews' sets (the R156 sweep, the fit check's 19, the pity preview's 3): bars vs the slots / name rows / BONUS ROLL / SKIP /
--                 card / HUD boxes; the name rows vs the HUD; the open wheel vs the balances / timers / hotbar / jump / the top of the HUD area / the bars / the name rows; the
--                 closed wheel's friend chip vs everything
-- Prints a WHEEL / SCREEN / FIT line per screen; "R157 HUD layout checks N, fails 0".
-- R158 (on purpose; the computer rows of this test): a computer's HUD is the 1920 x 1080 arrangement drawn at m.Scale = min(1, w / 1920, h / 720) and its MENU button a third of the way down at
-- m.MenuScale = max(Scale, .85) (HudLayout). The public layout functions still answer in real screen px; the bars' own fixed numbers (8 px gap, 3 px name clearance, 5 px glow, 24 px bars) are
-- HUD px, so they are times k = m.Scale below (1 on a phone and on a window of 1920 x 720 or more: nothing changes there). What is not true any more, and goes: the balances' R157 rule
-- (shorter rows under the wheel), the 640 x 360 ring and its pull-in off the owner tools tile (the tile hides while the wheel is open and the wheel fits at every window), the PC
-- rows of the .md's wheel table (MENU in the middle: now a third down).
local W=require('./world');local R=W.R
local V2=R.Vector2.new
local checks,fails=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end;return c end
local function near(a,b,t)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(t or 1e-6)end
local function ov(a,b,pad)pad=pad or 0;return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
local fmt=string.format
local Hud=W.module('HudLayout');local B=W.module('PityBars155');local Pity=W.module('PackPity155')
local Card=W.module('RarePullCard');local Rules=W.module('RarePullRules');local TB=W.module('TreadmillBonusRules');local Notice=W.module('HudNoticeLayout')
local function setScreen(w,h,touch)
 W.UIS.TouchEnabled=touch;W.UIS.KeyboardEnabled=not touch
 W.workspace.CurrentCamera.ViewportSize=V2(w,h)
 W.Gui.GetInsetArea=function()return{Min=V2(0,0),Width=w,Height=h}end
end
-- the screen sets ----------------------------------------------------------------------------------------------------------------------------------------------------
local R155={ -- R155's 36 screens (test_pity_bars155.luau)
 {1920,1080,false,'PC 1080p'},{2560,1440,false,'PC 1440p'},{1366,768,false,'laptop'},{1280,720,false,'PC 720p'},{1024,768,false,'small window'},{800,600,false,'tiny window'},{1600,900,false,'PC 900p'},
 {844,390,true,'iPhone 14 landscape'},{932,430,true,'iPhone Pro Max landscape'},{667,375,true,'iPhone 8 landscape'},{568,320,true,'iPhone SE landscape'},{740,360,true,'Android landscape'},{800,360,true,'Android wide'},{896,414,true,'iPhone 11 landscape'},
 {390,844,true,'iPhone 14 portrait'},{375,667,true,'iPhone 8 portrait'},{360,640,true,'Android portrait'},{414,896,true,'iPhone 11 portrait'},{320,568,true,'iPhone SE portrait'},{360,800,true,'Android tall'},
 {1024,768,true,'iPad landscape'},{768,1024,true,'iPad portrait'},{1180,820,true,'iPad Air landscape'},{820,1180,true,'iPad Air portrait'},{1366,1024,true,'iPad Pro landscape'},
 {1280,800,true,'Android tablet'},{800,1280,true,'Android tablet portrait'},{1920,1080,true,'touch PC'},{1440,900,false,'MacBook'},{1280,1024,false,'5:4 monitor'},
 {1280,540,false,'short PC window'},{960,480,false,'narrow short window'},{700,400,false,'tiny landscape window'},{812,375,true,'iPhone X landscape'},{430,932,true,'iPhone Pro Max portrait'},{360,740,true,'Android portrait 740'},
}
local SWEEP={ -- the menu wheel preview's 20 (menu_wheel_daily.md)
 {1920,1080,false},{1366,768,false},{1280,720,false},{1024,768,false},{800,600,false},{640,360,false},{932,430,true},{844,390,true},{740,360,true},{667,375,true},
 {750,311,true},{568,320,true},{640,280,true},{600,250,true},{560,220,true},{430,932,true},{390,844,true},{375,667,true},{360,640,true},{320,568,true}}
local FIT19={ -- the reveal fixes preview's fit check (check_fit156.luau)
 {1920,1080,false},{1366,768,false},{1280,720,false},{2560,1440,false},{1891,733,false},{1280,400,false},{800,600,false},{530,593,false},{420,420,false},
 {844,390,true},{932,430,true},{667,375,true},{568,320,true},{390,844,true},{375,667,true},{360,640,true},{414,896,true},{768,1024,true},{1024,768,true}}
local ALL,seen={},{}
for _,set in ipairs({R155,SWEEP,FIT19,{{844,390,true},{390,844,true},{1920,1080,false}}})do for _,s in ipairs(set)do
 local key=s[1]..'x'..s[2]..(s[3]and't'or'')
 if not seen[key]then seen[key]=true;ALL[#ALL+1]={s[1],s[2],s[3],s[4]or(s[3]and'touch 'or'PC ')..s[1]..'x'..s[2]}end
end end
-- a card's ScreenGui in a PlayerGui with Roblox's TouchGui holding the thumb controls c (or none): HudLayout.Controls reads them from it, as in the game
local function cardGui(w,h,c)
 local pg=R.new('Folder');local g=R.new('ScreenGui');g.AbsoluteSize=V2(w,h);g.Parent=pg
 if c then
  local t=R.new('ScreenGui');t.Name='TouchGui';t.Enabled=true;t.Parent=pg
  for key,name in pairs({Joystick='ThumbstickFrame',Jump='JumpButton'})do
   local f=R.new('Frame');f.Name=name;f.Parent=t;f.AbsolutePosition=V2(c[key].X,c[key].Y);f.AbsoluteSize=V2(c[key].W,c[key].H)
  end
 end
 return g
end
local function controls(w,h) -- the phone's thumb controls the way Roblox puts them (as R155's tests do)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end

-- 1. the bars -----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
 local function hex(c)return fmt('#%02X%02X%02X',rgb(c))end
 local N,E=Pity.Colors.Normal,Pity.Colors.Event
 local want={{N.Light,'#6ED746'},{N.Deep,'#0A7824'},{N.Rim,'#60CE3C'},{N.RimHot,'#D6FFA0'},{N.Glow,'#AAFF6E'},{N.Track,'#082410'},{N.Ink,'#063412'},
  {E.Light,'#FFF296'},{E.Deep,'#FFC02C'},{E.Rim,'#46C434'},{E.RimHot,'#96F450'},{E.Track,'#281E08'},{E.Glow,'#FFD646'},{E.Ink,'#422A02'},{N.Badge,'#062E12'},{E.Badge,'#062E12'}}
 local bad={};for _,p in ipairs(want)do if hex(p[1])~=p[2]then bad[#bad+1]=hex(p[1])..' (want '..p[2]..')'end end
 check(#bad==0 and Pity.Palettes==nil and Pity.Use==nil,'the colours are shade 1 "Fresh" exactly - NORMAL clover green #6ED746 -> #0A7824, EVENT gold #FFF296 -> #FFC02C with the clover-green rim #46C434, the clover disc #062E12 - and the second shade "Deep" is gone'..(#bad>0 and(': '..table.concat(bad,', '))or''))
 check(Pity.NoticeText('Event'):sub(1,3)=='⭐'and Pity.TagText('Event'):sub(1,3)=='⭐'and not Pity.NoticeText('Event'):find('💜',1,true)and Pity.NoticeText('Normal'):sub(1,4)=='🍀','the event notice and tag carry a gold star (no purple heart left); the normal ones the clover')
 check(B.Gap(false,24)==8 and B.Gap(false,20)==8 and B.Gap(true,20)==6 and B.Gap(true,18)==6 and B.Gap(true,16)==5 and B.Gap==Hud.PityGap,'the gap: 8 px on a computer, 6 on a phone, 5 under a thin phone bar (one rule: HudLayout.PityGap)')
 check(B.NameClear==3 and B.NameBand==42 and B.NameWidth==Hud.NameWidth and Hud.NameBand==42,'the name rows end 3 px over the bars, 42 px tall (26 + 16), as wide as the hotbar up to '..Hud.NameWidth..' px')
 local fails0=fails;local hidden={}
 for _,s in ipairs(ALL)do
  local w,h,touch,name=s[1],s[2],s[3],s[4]
  for _,ctl in ipairs(touch and{false,true}or{false})do
   local c=ctl and controls(w,h)or nil;local m=Hud.Read(V2(w,h),touch,c);local dock=B.DefaultDock(m,w,h);local place=B.Place(w,h,m,dock);local pair=place.Pair
   local k=m.Scale or 1;local hudBar=(place.Hud or place).Bar
   local tag=fmt('%s%s',name,ctl and' (thumb controls)'or'')
   local gap=(dock.Y-(pair.Y+pair.H))/k;local wantGap=B.Gap(touch,hudBar.H)
   check(place.Clear and near(gap,wantGap,1e-6),fmt('%s: the bars sit %d px over the slots (want %d), a clear spot',tag,gap,wantGap))
   check(m.Travel==nil,tag..': R113\'s BASE / TRACK spot (m.Travel) is gone')
   local row=B.NameRow(w,h,m,dock,place);local rows=B.NameRows(w,h,m,dock,place)
   check(row==math.ceil((dock.Y-pair.Y)/k-1e-6)+3 and near(rows.Y+rows.H,dock.Y-row*k)and rows.Y+rows.H<=pair.Y-3*k+1e-6 and near(rows.X+rows.W/2,dock.X+dock.W/2)and near(rows.W,math.min(dock.W,Hud.NameWidth*k)),fmt('%s: the name rows end %d HUD px over the slots, right above the bars (%d px), centred, %d px wide',tag,row,gap+hudBar.H,rows.W/k))
   -- HudLayout's own estimate (it tells whether the rows show before the bars exist) is where they really are wherever they show: the bars are never raised there
   -- (a screen whose bars stack - 420 x 420 - hides the rows; section 5 checks the REAL rows against the HUD on every screen that shows them)
   local est=Hud.NameRows({X=dock.X/k,Y=dock.Y/k,W=dock.W/k,H=dock.H/k},touch,h/k) -- (HUD px)
   if m.HotbarDetails~=false then check(near(est.Y*k,rows.Y,.5)and near(est.X*k,rows.X,.5),fmt('%s: HudLayout.NameRows (%d) is where the rows go (%d)',tag,est.Y*k,rows.Y))end
   if m.HotbarDetails==false then hidden[#hidden+1]=fmt('%dx%d',w,h)end
  end
 end
 local list={};local dup={};for _,k in ipairs(hidden)do if not dup[k]then dup[k]=true;list[#list+1]=k end end
 print('NAMEROWS hidden on: '..table.concat(list,' '))
 for _,k in ipairs({'320x568','360x640','360x740'})do check(dup[k],'the held item\'s name rows are hidden on the '..k..' portrait phone (approved: as on 320 x 568)')end
 for _,k in ipairs({'390x844','375x667','414x896','430x932','360x800','1920x1080','1366x768','1280x720','1024x768','844x390','932x430','667x375','750x311','568x320'})do check(not dup[k],'... and shown on '..k)end
 check(fails==fails0,'the bars on '..#ALL..' screens (with and without thumb controls): 8 / 6 / 5 px over the slots, the name rows right above them')
end

-- 2. SKIP ---------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 for rank=1,5 do for _,quick in ipairs({false,true})do
  local tl=Rules.CardTimeline(rank,quick)
  check(tl.SkipFrom==nil,fmt('rank %d%s: the card has no SkipFrom (no SKIP pill: only Secret / Cosmic / King)',rank,quick and' (quick)'or''))
 end end
 for rank=6,8 do
  for _,v in ipairs({'Full','Calm'})do local tl=Rules.Timeline(rank,v);check(tl.SkipFrom and tl.SkipFrom<tl.Climax,fmt('rank %d %s story scene: skippable from %.2f s',rank,v,tl.SkipFrom or -1))end
  for _,v in ipairs({'InPlace','Result'})do local tl=Rules.Timeline(rank,v);check(tl.SkipFrom==Rules.CardSkipFrom,fmt('rank %d %s card: skippable from %.2f s',rank,v,tl.SkipFrom or -1))end
 end
 -- the director builds the pill only for a timeline with a SkipFrom
 local src=require('./rs_bundle').RarePullCinematic
 check(src:find('Skip=run.TL.SkipFrom~=nil and run.TL.SkipFrom<math.huge',1,true)~=nil,'RarePullCinematic builds the SKIP pill only for a timeline with a SkipFrom')
 -- a real Ladder card asked the director's way builds no pill; a story scene card does
 local gui=R.new('ScreenGui');gui.Name='RarePullReveal';gui.AbsoluteSize=V2(1280,720)
 setScreen(1280,720,false)
 for rank=1,5 do
  local tl=Rules.CardTimeline(rank,false);local c=Card.Create(gui,'Ladder',{Rank=rank,SeedName='Probe',Odds=5,Skip=tl.SkipFrom~=nil})
  c:UpdateLadder(tl.Burst*.5,tl)
  check(c.SkipButton==nil and gui:FindFirstChild('Skip button',true)==nil,fmt('rank %d card: no SKIP pill is built',rank))
  c:Destroy()
 end
 -- the corner: a story scene's pill sits 14 px from the right and the bottom edge of the safe area, clear only of a thumb control really on screen
 local cornerFails=0
 for _,s in ipairs(ALL)do
  local w,h,touch=s[1],s[2],s[3]
  local x,y,bw,bh=Card.SkipRect(w,h,touch,Card.ControlBoxes(nil))
  if not(x==w-14-bw and y==h-14-bh and bh>=(touch and 40 or 34)and bh<=48)then cornerFails+=1;print(fmt('FAIL: %s: story scene SKIP at %d,%d %dx%d, not the corner',s[4],x,y,bw,bh))end
  if touch then
   -- a build that leaves the jump button visible: the pill steps left of the REAL button only (the stick, bottom left, is never in its way)
   local c=controls(w,h);local x2,y2=Card.SkipRect(w,h,touch,Card.ControlBoxes(c))
   local box={X=x2,Y=y2,W=bw,H=bh}
   if ov(box,c.Jump,8)or ov(box,c.Joystick,8)or x2+bw/2<w*.5 or y2<h*.45 then cornerFails+=1;print(fmt('FAIL: %s: with the jump button on screen the pill is at %d,%d',s[4],x2,y2))end
  end
 end
 check(cornerFails==0,fmt('a story scene\'s SKIP pill: the safe area\'s corner, 14 px in, on %d screens; with a visible jump button it steps left of it, still bottom right',#ALL))
 -- the real pill of a story scene card, once it shows (the director has hidden the HUD and held the controls)
 for _,s in ipairs({{1920,1080,false},{844,390,true},{390,844,true},{1891,733,false}})do
  local w,h,touch=s[1],s[2],s[3];setScreen(w,h,touch)
  local g=R.new('ScreenGui');g.AbsoluteSize=V2(w,h)
  local tl=Rules.Timeline(7,'Full');local c=Card.Create(g,'Scene',{Rank=7,Phone=touch,SeedName='Mirage Fig Seed',Odds=1e6,Skip=true})
  c:UpdateScene(tl.SkipFrom+.5,tl)
  local b=c.SkipButton;local p,z=b.Position,b.Size
  check(b.Visible and p.X.Offset==w-14-z.X.Offset and p.Y.Offset==h-14-z.Y.Offset,fmt('Cosmic story scene on %dx%d: the pill shows in the corner, 14 px in (%d,%d %dx%d)',w,h,p.X.Offset,p.Y.Offset,z.X.Offset,z.Y.Offset))
  c:Destroy()
 end
end

-- 3. the card -----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 -- BASE / TRACK: TravelButtons draws by HudLayout.TravelRow, the card's top edge measures by it too
 for _,inset in ipairs({nil,{Min=V2(120,0),Max=V2(1280,52),Width=1160,Height=52},{Min=V2(150,0),Max=V2(800,44),Width=650,Height=44},{Min=V2(60,12),Max=V2(700,48),Width=640,Height=36}})do
  local l,r,top,row,hgt=Hud.TravelRow(inset,1280)
  check(near(Hud.TravelBottom(inset),top+row/2+hgt/2+3)and hgt==math.clamp(row-8,30,44),fmt('TravelBottom (%.1f) is the pair TravelRow lays out: its bottom + its 3 px shadow',Hud.TravelBottom(inset)))
 end
 local tb=require('./rs_bundle').TravelButtons
 check(tb and tb:find('.TravelRow(GuiService.TopbarInset,area.X)',1,true)~=nil and not tb:find('TopIcons',1,true),'TravelButtons lays BASE / TRACK out by HudLayout.TravelRow (so the card\'s band cannot drift from it) and has no DAILY / INVITE squares')
 local fitFails,n=0,0;local shrunk={}
 for _,s in ipairs(ALL)do
  local w,h,touch=s[1],s[2],s[3];setScreen(w,h,touch)
  local gui=R.new('ScreenGui');gui.AbsoluteSize=V2(w,h)
  local phone=touch or math.min(w,h)<500
  local m=Hud.Read(V2(w,h),touch,nil);local res=B.Reserved(w,h,m,nil)
  local margin=math.max(8,math.floor(h*.012+.5));local travel=Hud.TravelBottom(nil)
  local cells={}
  for rank=1,8 do
   local compact=rank>=6;n+=1
   local top,bottom=Card.FitBand(gui,V2(w,h),rank,phone,compact)
   local L=Rules.FitLayout(phone,rank,top,bottom,w,h,compact)
   local function span(k)local off=k=='Seed'and Rules.Fit.Float or 0;return(L[k].Y+off)*h-L[k].H*h/2,(L[k].Y+off)*h+L[k].H*h/2 end
   local bad={}
   if top<travel+margin-.5 then bad[#bad+1]='band starts above BASE / TRACK'end
   if bottom>res.Y-margin+.5 then bad[#bad+1]=fmt('band ends below the bars / name rows (%d > %d)',bottom,res.Y-margin)end
   if span('Title')<top-.5 then bad[#bad+1]='title above the band'end
   local _,last=span('Hint');if last>bottom+.5 then bad[#bad+1]='hint below the band'end
   if L.Seed.W*w>Rules.Fit.SeedWidth*w+.5 or math.abs(L.Seed.W*w-L.Seed.H*h)>.5 then bad[#bad+1]='seed not a square within 62% of the width'end
   -- the words keep their readable least (and the seed its least) on every screen 320 px tall or more: every phone and tablet; only a smaller window shrinks past it
   local under=false;for key,v in pairs(Rules.Fit.Least)do if L[key].H*h<v-.5 then under=true end end
   if under then if h>=320 then bad[#bad+1]='a row under its readable least'else shrunk[fmt('%dx%d',w,h)]=true end end
   local prev=-1e9
   for _,k in ipairs({'Title','Seed','Odds','Name','Hint'})do local a,b=span(k);if a<prev-.5 then bad[#bad+1]=k..' overlaps the row above'end;prev=b end
   -- the hint is the row directly under the name
   local _,nameB=span('Name');local hintA=span('Hint')
   if hintA<nameB-.5 or hintA-nameB>Rules.Fit.GapMax*h+.5 then bad[#bad+1]='the hint is not right under the name'end
   if #bad>0 then fitFails+=1;print(fmt('FAIL: card %dx%d rank %d: %s',w,h,rank,table.concat(bad,'; ')))end
   cells[#cells+1]=fmt('%s%d %d..%d k=%.2f',compact and'c'or'r',rank,top,bottom,L.Fit.K)
  end
  print(fmt('FIT %4dx%-4d %s %s',w,h,touch and'touch'or'pc   ',table.concat(cells,' | ')))
 end
 check(fitFails==0,fmt('the Common..Mythic card and the compact Secret+ card fit their band on %d screens (%d fits): under BASE / TRACK, over the NEW bars and the name rows, rows in order, the hint under the name, the words at their readable least or more on every screen 320 px tall or more',#ALL,n))
 local list={};for k in pairs(shrunk)do list[#list+1]=k end;table.sort(list)
 print('FIT under the least (a band shorter than the least stack, 128 px): '..(#list>0 and table.concat(list,' ')or'none'))
 check(#list<=4,'only the wheel sweep\'s windows under 320 px tall shrink the card past its least ('..table.concat(list,' ')..')')
 -- the story result has the same hint under its name, above the bottom letterbox bar
 for _,phone in ipairs({false,true})do for rank=6,8 do
  local L=Rules.Layout(phone,false,rank)
  check(L.Hint and near(L.Hint.Y,.8855)and L.Hint.Y-L.Hint.H/2>=L.Name.Y+L.Name.H/2-1e-9 and L.Hint.Y+L.Hint.H/2<=1-L.Bar+1e-9 and near(L.Odds.Y,.775)and near(L.Name.Y,.842),fmt('rank %d story result%s: the collect hint right under the name, above the letterbox bar',rank,phone and' (phone)'or''))
 end end
 -- the real card: the hint shows under the name ("click to collect!" / "tap to collect!") once the result waits; its rows are published for the lucky tag
 for _,s in ipairs({{1920,1080,false},{844,390,true},{390,844,true}})do
  local w,h,touch=s[1],s[2],s[3];setScreen(w,h,touch)
  local g=R.new('ScreenGui');g.AbsoluteSize=V2(w,h)
  local tl=Rules.CardTimeline(1,false);tl.Wait=true;tl.Out=1e6;tl.Length=1e6 -- (what the director's waitBeats gives a waiting card: nothing goes out)
  local c=Card.Create(g,'Ladder',{Rank=1,Phone=touch,SeedName='Watermelon Seed',Odds=2})
  local t=Rules.ShownAt(tl)+1;c:UpdateLadder(t,tl)
  local hint=c.SkipHint;local L=c.Layout
  check(L.Fit~=nil and c.Lift==0 and hint.Visible and hint.Text==(touch and'tap to collect!'or'click to collect!')and near(hint.Position.Y.Scale,L.Hint.Y)and hint.Position.X.Scale==.5 and hint.AnchorPoint.X==.5,fmt('%dx%d Common card: "%s" centred right under the name (row %.3f; the name ends %.3f)',w,h,hint.Text,L.Hint.Y,L.Name.Y+L.Name.H/2))
  local rows=B.CardRows(R.new('Folder'),h)==nil
  local box=c.Root:FindFirstChild(Card.RowsName);local ok=box~=nil and box.ClassName=='Folder'and c.Root:GetAttribute('FitSeedTop')==nil
  for k,v in pairs(Card.Rows(L))do if not(box and near(box:GetAttribute(Card.RowKeys[k]),v))then ok=false end end
  check(rows and ok,fmt('%dx%d: the card publishes its rows on a Folder under its root frame (never drawn; the lucky tag reads them)',w,h))
  c:Destroy()
 end
 -- the lucky tag follows the fitted card's rows
 for _,s in ipairs(ALL)do
  local w,h,touch=s[1],s[2],s[3];setScreen(w,h,touch)
  local phone=touch or math.min(w,h)<500
  for _,kind in ipairs({'Ladder','InPlace'})do
   local rank=kind=='Ladder'and 5 or 7
   local top,bottom=Card.FitBand(R.new('ScreenGui'),V2(w,h),rank,phone,kind~='Ladder')
   local L=Rules.FitLayout(phone,rank,top,bottom,w,h,kind~='Ladder')
   local rows={};for k,v in pairs(Card.Rows(L))do rows[k]=v*h end
   local p=B.TagPlace(kind,phone,w,h,rows);local a,b=p.Y-p.H/2,p.Y+p.H/2
   local ok
   if kind=='Ladder'then ok=b<=rows.OddsTop+.5 and a>=rows.SeedTop-.5 and p.H>=B.TagMin and(rows.OddsTop-rows.SeedBottom<B.TagMin or(a>=rows.SeedBottom-.5))
   else ok=a>=rows.HintBottom-.5 end
   if not ok then print(fmt('FAIL: %dx%d %s: the lucky tag at %d..%d (seed %d..%d, "1 in N" from %d, hint to %d)',w,h,kind,a,b,rows.SeedTop,rows.SeedBottom,rows.OddsTop,rows.HintBottom))end
   check(ok,fmt('%dx%d %s card: the lucky tag follows its rows',w,h,kind))
  end
 end
end

-- 4. the wheel ----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 -- menu_wheel_daily.md: MENU centre y, option px, radius up / down and the five offsets (the md rounds a diagonal to the px)
 local TABLE={
  -- (R158, on purpose: a computer's MENU a third of the way down - screen px; the offsets are in MENU px, the same half circle at every window, drawn at m.MenuScale)
  ['1920x1080']={false,360,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['1366x768']={false,256,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['1280x720']={false,240,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['1024x768']={false,256,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['800x600']={false,200,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['932x430']={true,173,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['844x390']={true,142,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['740x360']={true,134,64,{{0,-94},{96,-52},{174,0},{96,52},{0,95}}},
  ['667x375']={true,140,64,{{0,-100},{96,-55},{174,0},{96,56},{0,101}}},
  ['750x311']={true,114,64,{{0,-74},{96,-41},{174,0},{96,41},{0,75}}},
  ['568x320']={true,119,64,{{0,-79},{96,-43},{175,0},{96,43},{0,79}}},
  ['640x280']={true,99,48,{{0,-67},{102,-41},{165,0},{102,41},{0,67}}},
  ['430x932']={true,466,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['390x844']={true,399,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['375x667']={true,224,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['360x640']={true,199,64,{{0,-102},{72,-72},{102,0},{72,78},{0,111}}},
  ['320x568']={true,160,48,{{0,-94},{66,-66},{94,0},{66,66},{0,94}}},
 }
 for key,row in pairs(TABLE)do
  local w,h=key:match('(%d+)x(%d+)');w,h=tonumber(w),tonumber(h)
  local m=Hud.Read(V2(w,h),row[1],nil);local o=m.MenuOffsets;local centre=h/2+(m.MenuShiftY or 0)*(m.MenuScale or 1)
  local same=#o==5 and m.MenuOptionSize==row[3]and math.abs(centre-row[2])<=1
  for i=1,5 do if not(o[i]and math.abs(o[i].X-row[4][i][1])<=1 and math.abs(o[i].Y-row[4][i][2])<=1)then same=false end end
  local got={};for i=1,#o do got[i]=fmt('(%.0f,%.0f)',o[i].X,o[i].Y)end
  check(same,fmt('%s%s: the wheel as approved: MENU centre %d, %d px options, %s (got %.0f, %d px, %s)',key,row[1]and' touch'or'',row[2],row[3],'the .md\'s offsets',centre,m.MenuOptionSize,table.concat(got,' ')))
 end
 -- DAILY down-right, INVITE straight down; the lower pair a little lower than the mirror (badge air under SHOP) where the circle is kept
 local m=Hud.Read(V2(1920,1080),false,nil);local o=m.MenuOffsets
 check(o[4].X>0 and o[4].Y>0 and o[5].X==0 and o[5].Y>0 and o[5].Y>-o[1].Y and o[1].X==0 and o[3].Y==0,'1920x1080: SETTINGS up, INDEX up-right, SHOP right (where they were), DAILY down-right, INVITE straight down (111 px, under the 102 px up)')
 -- the fallbacks: under ~280 px smaller buttons, under ~230 px DAILY / INVITE in a row beyond SHOP; nothing overlaps there either (section 5)
 local f1=Hud.Read(V2(640,280),true,nil);local f2=Hud.Read(V2(600,250),true,nil);local f3=Hud.Read(V2(560,220),true,nil)
 check(f1.MenuOptionSize<64 and f1.MenuOffsets[4].X<f1.MenuOffsets[3].X and f1.MenuOffsets[5].Y>0,'640x280 (under ~280 px): smaller buttons ('..f1.MenuOptionSize..' px), still the half circle')
 for _,c in ipairs({{f2,'600x250'},{f3,'560x220'}})do
  local q=c[1].MenuOffsets
  check(q[4].Y==0 and q[5].Y==0 and q[4].X>q[3].X and q[5].X>q[4].X and q[4].X-q[3].X>=c[1].MenuOptionSize+8 and q[5].X-q[4].X>=c[1].MenuOptionSize+8,c[2]..': the fallback - DAILY / INVITE in a row beyond SHOP, 8 px apart')
 end
 -- R158 (on purpose): the balances never move or shrink for the wheel on a computer (R157's "shorter rows under the wheel" rule is gone): the three 56 HUD px rows stay in the bottom-left
 -- corner, 12 px from the left, the last 16 px over the bottom, at every window (the whole HUD is drawn at m.Scale); the MENU button is a third of the way down so the wheel clears them. The 5-option
 -- half circle fits at every one of these windows (no fallback ring), and its first option is not pulled in off the owner tools tile any more (the tile hides while the wheel is open).
 for _,s in ipairs({{1920,1080},{1366,768},{1280,720},{1024,768},{800,600},{1600,900},{1440,900},{1280,1024},{960,480},{1891,733},{640,360},{420,420}})do
  local w,h=s[1],s[2];local m=Hud.Read(V2(w,h),false,nil);local ms=m.MenuScale
  check(m.WalletX==12 and m.WalletHeight==56 and m.WalletWidth==290 and math.abs(m.GemY+m.WalletHeight-(m.VH-m.StatusBottom))<=.5 and m.StatusBottom==16,fmt('PC %dx%d: the balances keep their full size in the bottom-left corner (x %d, rows %d HUD px, ending %d HUD px over the bottom)',w,h,m.WalletX,m.WalletHeight,m.VH-(m.GemY+m.WalletHeight)))
  local o=m.MenuOffsets;local fan=o[4].X>o[3].X
  check(not fan and #o==5 and o[5].X==0 and o[5].Y>0,fmt('PC %dx%d: the five options are the half circle (no fallback ring)',w,h))
  local lowest=h/2+m.MenuShiftY*ms+(o[5].Y+m.MenuOptionSize/2)*ms
  check(lowest<=(m.SpeedY)*m.Scale-8*ms+.5,fmt('PC %dx%d: the open wheel ends (%.0f) 8 px over the balances (%.0f)',w,h,lowest,m.SpeedY*m.Scale))
 end
 local okSlots=pcall(function()local g=R.new('ScreenGui');local b=R.new('TextButton');b.Parent=g;Hud.Navigation(b,6)end)
 check(not okSlots,'Navigation takes slots 1..5 only')
end

-- 5. no overlaps ----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local overlapFails=0
 local function noticeRows(w,h)
  local rows=Notice.Calculate(w,h,36,TB.NoticeFlags);local extra={}
  for name,r in pairs(rows)do if type(r)=='table'then extra[#extra+1]={N=name,X=r.X-r.Width/2,Y=r.Y,W=r.Width,H=r.Height}end end
  return extra
 end
 for _,s in ipairs(ALL)do
  local w,h,touch,name=s[1],s[2],s[3],s[4]
  for _,ctl in ipairs(touch and{false,true}or{false})do
   local c=ctl and controls(w,h)or nil;setScreen(w,h,touch)
   local m=Hud.Read(V2(w,h),touch,c);local tag=name..(ctl and' (thumb controls)'or'')
   local k=m.Scale or 1;local ms=m.MenuScale or 1 -- (R158: the bars' fixed numbers are HUD px, the MENU's are MENU px)
   local dock=B.DefaultDock(m,w,h);local place=B.Place(w,h,m,dock);local ext=(function()local hp=place.Hud or place;local e=B.Extent(hp.Pair,hp.Bar.W,hp.Bar.H);return {X=e.X*k,Y=e.Y*k,W=e.W*k,H=e.H*k}end)() -- (R158 review: B.Extent is in the units it is given: the HUD-px answer, times the scale)
   local rows=m.HotbarDetails~=false and B.NameRows(w,h,m,dock,place)or nil
   local res=B.Reserved(w,h,m,dock)
   local boxes=Hud.HudBoxes(m,w,h,false);local wheel=Hud.HudBoxes(m,w,h,true)
   local opts={};for _,b in ipairs(wheel)do if b.N:sub(1,3)=='Opt'then opts[#opts+1]=b end end
   local bad={}
   -- the bars
   if ov(place.Pair,dock,0)then bad[#bad+1]='bars on the slots'end
   for _,b in ipairs(boxes)do if b.N~='Hotbar'and ov(ext,b,0)then bad[#bad+1]='bars x '..b.N end end
   if rows and ov(rows,ext,0)and rows.Y+rows.H>place.Pair.Y-3*k+1e-6 then bad[#bad+1]='name rows x bars'end
   if rows then for _,b in ipairs(boxes)do if b.N~='Hotbar'and(b.N~='Status'or touch)and ov(rows,b,0)then bad[#bad+1]='name rows x '..b.N end end end
   -- the BONUS ROLL button (what TreadmillBonusClient asks: PityBars155.ButtonSpot with the open wheel's boxes and the notice rows)
   local btn=B.ButtonSpot(TB,m,w,h,wheel,noticeRows(w,h))
   if ov(btn,ext,0)then bad[#bad+1]='BONUS x bars'end
   if rows and ov(btn,rows,0)then bad[#bad+1]='BONUS x name rows'end
   if ov(btn,dock,0)then bad[#bad+1]='BONUS x slots'end
   for _,b in ipairs(wheel)do if b.N~='Hotbar'and ov(btn,b,0)then bad[#bad+1]='BONUS x '..b.N end end
   -- the SKIP pill of a card that leaves the HUD up (Secret+ in place): SkipBoxes = the HUD and the bars + name rows
   local x,y,bw,bh=Card.SkipRect(w,h,touch,Card.SkipBoxes(w,h,touch,c));local pill={X=x,Y=y,W=bw,H=bh}
   if ov(pill,ext,0)then bad[#bad+1]='SKIP x bars'end
   if rows and ov(pill,rows,0)then bad[#bad+1]='SKIP x name rows'end
   if ov(pill,dock,0)then bad[#bad+1]='SKIP x slots'end
   if x<14 or y<14 or x+bw>w-14 or y+bh>h-14 then bad[#bad+1]='SKIP not 14 px in'end
   -- the card's band ends over the bars and the name rows
   local _,bottom=Card.FitBand(cardGui(w,h,c),V2(w,h),1,touch or math.min(w,h)<500,false)
   if bottom>res.Y then bad[#bad+1]='card band over the bars'end
   -- the open wheel
   for i,a in ipairs(opts)do
    if a.X<0 or a.Y<8*ms-1e-6 or a.X+a.W>w or a.Y+a.H>h then bad[#bad+1]=a.N..' off the HUD area'end
    if ov(a,wheel[1],0)then bad[#bad+1]=a.N..' x MENU'end
    for j=i+1,#opts do if ov(a,opts[j],0)then bad[#bad+1]=a.N..' x '..opts[j].N end end
    for _,b in ipairs(boxes)do if b.N~='Hub'and b.N~='OwnerTools'and b.N~='Hotbar'and ov(a,b,0)then bad[#bad+1]=a.N..' x '..b.N end end
    if ov(a,dock,0)then bad[#bad+1]=a.N..' x slots'end
    if ov(a,ext,0)then bad[#bad+1]=a.N..' x bars'end
    if rows and ov(a,rows,0)then bad[#bad+1]=a.N..' x name rows'end
    -- (the owner tools tile hides while the wheel is open: StudioTestClient; R158: a computer's wheel may stand where it is)
    if touch then for _,b in ipairs(boxes)do if b.N=='OwnerTools'and ov(a,b,0)then bad[#bad+1]=a.N..' x OwnerTools'end end end
   end
   if not touch then for _,b in ipairs(boxes)do if b.N=='OwnerTools'and ov(wheel[1],b,0)then bad[#bad+1]='the closed MENU button x OwnerTools'end end end
   -- the closed wheel's friend chip, right of the MENU button
   local hub=wheel[1];local chip={X=hub.X+hub.W+Hud.ChipSize.Gap*ms,Y=hub.Y+hub.H/2-Hud.ChipSize.Y*ms/2,W=Hud.ChipSize.X*ms,H=Hud.ChipSize.Y*ms}
   if chip.X+chip.W>w then bad[#bad+1]='friend chip off screen'end
   for _,b in ipairs(boxes)do if b.N~='Hub'and b.N~='OwnerTools'and ov(chip,b,0)then bad[#bad+1]='friend chip x '..b.N end end
   if ov(chip,ext,0)or(rows and ov(chip,rows,0))then bad[#bad+1]='friend chip x bars / name rows'end
   if #bad>0 then overlapFails+=1;print(fmt('FAIL: %s %dx%d%s: %s',tag,w,h,touch and' touch'or'',table.concat(bad,', ')))end
   print(fmt('SCREEN %s %dx%d%s bars %dx%d gap %d rows %s | MENU %d (%+d) options %d | BONUS %d,%d | SKIP %d,%d | card to %d',tag,w,h,touch and' touch'or'',place.Bar.W,place.Bar.H,dock.Y-(place.Pair.Y+place.Pair.H),rows and'above'or'hidden',h/2+(m.MenuShiftY or 0),m.MenuShiftY or 0,m.MenuOptionSize,btn.X,btn.Y,x,y,bottom))
  end
 end
 check(overlapFails==0,fmt('nothing overlaps on %d screens (with and without thumb controls): the bars / the name rows / the BONUS ROLL button / the SKIP pill / the card / the open wheel / the friend chip / the HUD boxes',#ALL))
end
print(fmt('R157 HUD layout checks %d, fails %d',checks,fails))
if fails>0 then error('failures')end
