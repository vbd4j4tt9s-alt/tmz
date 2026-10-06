--!nocheck
-- R150 layout of the treadmill bonus UI on every screen of the R123 layout test (26 screens, touch with and without on-screen controls):
--  * HUD button: its parts sit inside it, title / status line / icon / badge / meter never overlap, text fits (conservative Montserrat Black
--    widths), badge and rest-pose bounds stay clear of every HudLayout box and the notice rows (the Place rule, 6 px, with the badge's few px).
--  * Roll screen: panel inside the screen, rows stacked without overlap, bow / pointers clear of neighbours, cards inside the strip window,
--    buttons centred and inside, every text line fits (all status lines, all seven reveal words, long result sentences, the odds line).
--  * R153: the yellow fill is clipped to the button's rounded shape at 0 / 50 / 100% on every screen; the almost / ready texts fit; the header pack picture sits on the ribbon.
--    (The gift pill over the player's head is gone: no billboard.)
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local C=UW.boot({})
local Rules,me,pg=C.Rules,C.Me,C.PG
local Style=W.module('TreadmillBonusStyle');local L=W.module('HudLayout');local Notice=W.module('HudNoticeLayout')
local hud,overlay,button=C.Hud,C.Overlay,C.Button
local panel=overlay.Panel
UW.frames(3,1/60)
local function controls(w,h)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
-- A TouchGui the way HudLayout.Controls reads it.
local touchGui=R.new('ScreenGui');touchGui.Name='TouchGui';touchGui.Enabled=false;touchGui.Parent=pg
local thumb=R.new('Frame');thumb.Name='ThumbstickFrame';thumb.Parent=touchGui
local jump=R.new('Frame');jump.Name='JumpButton';jump.Parent=touchGui
local function placeControls(ctl)
 touchGui.Enabled=ctl~=nil
 if ctl then
  thumb.AbsolutePosition=R.Vector2.new(ctl.Joystick.X,ctl.Joystick.Y);thumb.AbsoluteSize=R.Vector2.new(ctl.Joystick.W,ctl.Joystick.H)
  jump.AbsolutePosition=R.Vector2.new(ctl.Jump.X,ctl.Jump.Y);jump.AbsoluteSize=R.Vector2.new(ctl.Jump.W,ctl.Jump.H)
 end
end
local views={}
for _,v in ipairs({{1920,1080},{1366,768},{1280,720},{1024,768},{800,600},{1280,540},{960,480},{700,400}})do views[#views+1]={v[1],v[2],false}end
for _,v in ipairs({{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{800,360},{1024,768},{1180,820},{1366,1024},{320,568},{375,667},{390,844},{430,932},{360,740},{768,1024},{820,1180}})do views[#views+1]={v[1],v[2],true}end
local function settle()UW.seconds(.6,1/60);for _=1,500 do if UW.frameListeners()==0 then break end;UW.frames(1,1/60)end end
local function box(e)return {X=e.X,Y=e.Y,W=e.W,H=e.H}end
local function ov(a,b,pad)return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
local function labelRect(e)return {W=e.RW,H=e.RH}end
local function visibleKids(list,prefix)
 local out={};for _,e in ipairs(list)do if e.Visible and e.Path:sub(1,#prefix)==prefix and e.Path~=prefix then out[#out+1]=e end end;return out
end
local function fitsText(label,e,text,tag,minSize)
 local old=label.Text;label.Text=text
 local ok,size,lines=UW.fit(label,labelRect(e))
 label.Text=old
 check(ok and size>=(minSize or 8),tag..': "'..text..'" fits '..string.format('%.0fx%.0f',e.RW,e.RH)..' (size '..size..', '..lines..' line(s))')
end
-- =====================================================================================================================
-- 1. The HUD button on every screen
-- =====================================================================================================================
local SUBS={'READY!','NEXT 6:00','NEXT 0:01','0:24','0:02','OPEN IT!','2 ROLLS READY!','NEXT IN 5:59','BAG FULL!','ONE SEC...','NOT YET!','LOADING...','TRY AGAIN!','ROLLING...','TRY LATER'}
local sizesSeen={}
for _,v in ipairs(views)do
 local w,h,touch=v[1],v[2],v[3]
 for _,ctl in ipairs(touch and{false,true}or{false})do
  W.UIS.TouchEnabled=touch;placeControls(ctl and controls(w,h)or nil)
  me:SetAttribute('TreadmillBonusReady',nil)
  C.set('Interval',360);C.set('Ready',2);C.set('DueAt',nil);C.set('Left',200)
  C.size(w,h);UW.frames(2,1/60);settle() -- pop-ins and wiggles settle
  local tag=string.format('%s %dx%d%s',touch and'TOUCH'or'PC',w,h,ctl and' ctl'or'')
  local list,by=UW.rects(hud,w,h)
  local b=by['TreadmillBonusHud.BonusRollButton']
  if check(b and b.Visible,tag..': the button shows (two ready)')then
   sizesSeen[string.format('%dx%d',b.RW,b.RH)]=true
   -- the same rule as Place: clear of every box, with the badge's few px on top
   local m=L.Read(R.Vector2.new(w,h),touch,ctl and controls(w,h)or nil)
   local boxes=L.HudBoxes(m,w,h,true)
   local rows=Notice.Calculate(w,h,36,Rules.NoticeFlags);local extra={}
   for name,row in pairs(rows)do if type(row)=='table'then extra[#extra+1]={N=name,X=row.X-row.Width/2,Y=row.Y,W=row.Width,H=row.Height}end end
   local union={X=b.RX,Y=b.RY,W=b.RW,H=b.RH}
   local badge=by['TreadmillBonusHud.BonusRollButton.CountBadge']
   check(badge and badge.Visible,tag..': the count badge shows')
   if badge then
    local iconOn=by['TreadmillBonusHud.BonusRollButton.Face.Icon'].Visible
    local px,py,pr=b.RX-badge.X,b.RY-badge.Y,badge.X+badge.W-(b.RX+b.RW)
    if iconOn then
     -- on the gift: inside the button (a hair above its top edge), overlapping the icon
     local gift=by['TreadmillBonusHud.BonusRollButton.Face.Icon']
     check(py<=2.5 and pr<=0 and px<=0,tag..string.format(': the badge sits on the gift icon (%.1f px above the button)',py))
     check(badge.X<gift.X+gift.W and badge.X+badge.W>gift.X+gift.W*.5 and badge.Y<gift.Y+gift.H*.5,tag..': the badge overlaps the gift icon corner')
    else
     check(badge.X>=b.RX+b.RW/2 and badge.Y<=b.RY+10,tag..': without the gift the badge sits on the top-right corner')
     check(py<=5.5 and pr<=5.5,tag..string.format(': the badge protrudes %.1f px up, %.1f px right (at most 5.5)',py,pr))
    end
    local x0,y0=math.min(b.RX,badge.X),math.min(b.RY,badge.Y)
    union={X=x0,Y=y0,W=math.max(b.RX+b.RW,badge.X+badge.W)-x0,H=math.max(b.RY+b.RH,badge.Y+badge.H)-y0}
    local scaledW=badge.W*1.28;local grow=(scaledW-badge.W)/2
    check(badge.Y-grow>=b.RY-9,tag..': the badge pop (x1.28) stays within 9 px above the button')
   end
   check(b.RX>=8 and b.RY>=8 and b.RX+b.RW<=w-8 and b.RY+b.RH<=h-8,tag..': the button keeps the 8 px screen margin')
   -- R150 review: the button is anchored at its centre (its pop and pulse scale about it); its placement is exactly the one TreadmillBonusRules.Place gives
   local want=Rules.Place(m,w,h,boxes,extra)
   check(button.AnchorPoint.X==.5 and button.AnchorPoint.Y==.5 and want and math.abs(b.RX-want.X)<.01 and math.abs(b.RY-want.Y)<.01 and math.abs(b.RW-want.W)<.01 and math.abs(b.RH-want.H)<.01,
    tag..string.format(': R150 review: the centre-anchored button sits exactly where Place puts its top-left corner (%.1f,%.1f vs %.1f,%.1f)',b.RX,b.RY,want and want.X or-1,want and want.Y or-1))
   check(union.X>=2 and union.Y>=2 and union.X+union.W<=w-2 and union.Y+union.H<=h-2,tag..': button and badge are on screen')
   for _,bx in ipairs(boxes)do check(not ov(union,bx,0),tag..': button + badge clear of '..bx.N)end
   for _,bx in ipairs(extra)do check(not ov(union,bx,0),tag..': button + badge clear of notice row '..bx.N)end
   check(not ov(union,{X=w/2-140,Y=0,W=280,H=60},0),tag..': clear of the top-bar travel row')
   check(b.RH>=44 and b.RW>=124,tag..': touch-sized')
   -- parts inside the button
   local face=by['TreadmillBonusHud.BonusRollButton.Face']
   check(face and face.RW==b.RW and face.RH==b.RH-4,tag..string.format(': the face is the button minus the 4 px lip (button %.1fx%.1f, face %.1fx%.1f, scale %.3f)',b.RW,b.RH,face and face.RW or 0,face and face.RH or 0,b.Scale))
   local kids=visibleKids(list,'TreadmillBonusHud.BonusRollButton.Face.')
   local function direct(name)return by['TreadmillBonusHud.BonusRollButton.Face.'..name]end
   for _,e in ipairs(kids)do
    local top=e.Path:match('%.Face%.([^%.]+)$') -- only direct children of the face
    if top then
     local inside=e.X>=face.RX-.5 and e.Y>=face.RY-.5 and e.X+e.W<=face.RX+face.RW+.5 and e.Y+e.H<=face.RY+face.RH+.5
     check(inside,tag..': Face.'..top..' stays inside the face')
    end
   end
   local title,sub,icon,meter=direct('Title'),direct('Sub'),direct('Icon'),direct('Meter')
   check(title.RY+title.RH<=sub.RY+.5,tag..': title above the status line')
   check(not meter.Visible or sub.RY+sub.RH<=meter.RY+.5,tag..': status line above the meter')
   if icon.Visible then
    check(icon.X+icon.W<=title.RX+.5 and icon.X+icon.W<=sub.RX+.5,tag..': the gift icon is left of the text')
    check(icon.RW>=26 and icon.RH>=26,tag..': the gift icon is big enough ('..icon.RW..')')
   end
   check(title.RX+title.RW<=badge.X+.5 or title.RX>=badge.X+badge.W-.5,tag..': the title does not run under the badge')
   -- texts
   fitsText(face.Obj.Title,title,'BONUS ROLL',tag..': title',10)
   fitsText(face.Obj.Title,title,'BONUS READY!',tag..': R153: the ready pop title (with the count badge, the narrowest case)',9)
   for _,line in ipairs(SUBS)do fitsText(face.Obj.Sub,sub,line,tag..': status line',8)end
   -- narrow: no icon below 140 wide
   check((b.RW>=140)==icon.Visible,tag..': the gift icon only on buttons 140+ wide')
   -- the other states keep the same geometry (charging, one ready)
   C.set('Ready',0);C.set('DueAt',R.clock+200);me:SetAttribute('TreadmillTraining',true);UW.frames(3,1/60);settle()
   local list2,by2=UW.rects(hud,w,h)
   local b2=by2['TreadmillBonusHud.BonusRollButton']
   check(b2.Visible and b2.RW==b.RW and b2.RH==b.RH and b2.RX==b.RX and b2.RY==b.RY,tag..string.format(': charging: same place and size (%.1fx%.1f at %.1f,%.1f vs %.1fx%.1f at %.1f,%.1f)',b2.RW,b2.RH,b2.RX,b2.RY,b.RW,b.RH,b.RX,b.RY))
   -- R153 (owner: "the yellow fill must cover the whole button"): the fill is clipped to the face's own rounded shape: at 0 / 50 / 100% it stays inside the face, at 100% it covers the
   -- face edge to edge, it grows from the left, and its clip has the face's corner radius. Measured with the button's pulse UIScale in the way (the rects follow it).
   local faceObj=face.Obj;local faceCorner=faceObj:FindFirstChildOfClass('UICorner')
   local clipObj=faceObj.FillClip;local clipCorner=clipObj:FindFirstChildOfClass('UICorner')
   check(clipObj._class=='CanvasGroup' and faceCorner and clipCorner and clipCorner.CornerRadius.Scale==faceCorner.CornerRadius.Scale and clipCorner.CornerRadius.Offset==faceCorner.CornerRadius.Offset,
    tag..': R153: the fill sits in a CanvasGroup with the face\'s corner radius ('..tostring(clipCorner and clipCorner.CornerRadius.Scale)..' vs '..tostring(faceCorner and faceCorner.CornerRadius.Scale)..')')
   check(clipObj.Parent==faceObj and clipObj.Fill.Parent==clipObj and clipObj.Fill:FindFirstChildOfClass('UICorner')==nil,tag..': R153: Face > FillClip > Fill, and the fill has no corner of its own (the group rounds it)')
   local lastW=-1
   for _,pct in ipairs({0,50,100})do
    local left=360*(1-pct/100)
    C.set('DueAt',R.clock+left);C.set('Left',left);UW.frames(8,1/60);settle()
    local _,by4=UW.rects(hud,w,h)
    local face4=by4['TreadmillBonusHud.BonusRollButton.Face']
    local clip4=by4['TreadmillBonusHud.BonusRollButton.Face.FillClip'];local fill4=by4['TreadmillBonusHud.BonusRollButton.Face.FillClip.Fill']
    local want=face4.RW*pct/100
    check(math.abs(clip4.RX-face4.RX)<.01 and math.abs(clip4.RY-face4.RY)<.01 and math.abs(clip4.RW-face4.RW)<.01 and math.abs(clip4.RH-face4.RH)<.01,tag..': R153: '..pct..'%: the clip is exactly the face')
    check(pct==0 and not clip4.Visible or(clip4.Visible and fill4.Visible),tag..': R153: '..pct..'%: the fill shows when there is progress, not at 0%')
    if pct>0 then
     check(fill4.RX>=face4.RX-.01 and fill4.RY>=face4.RY-.01 and fill4.RX+fill4.RW<=face4.RX+face4.RW+.01 and fill4.RY+fill4.RH<=face4.RY+face4.RH+.01,tag..': R153: '..pct..'%: the fill is inside the face')
     check(math.abs(fill4.RX-face4.RX)<.01 and math.abs(fill4.RY-face4.RY)<.01 and math.abs(fill4.RH-face4.RH)<.01,tag..': R153: '..pct..'%: it starts at the very left edge and is as tall as the face')
     check(math.abs(fill4.RW-want)<=.5,tag..string.format(': R153: %d%%: the fill is %.1f of %.1f px wide (want %.1f)',pct,fill4.RW,face4.RW,want))
     check(fill4.RW>lastW,tag..': R153: the fill grows with the progress')
     lastW=fill4.RW
    end
    if pct==100 then check(math.abs(fill4.RW-face4.RW)<.01,tag..': R153: 100%: the fill covers the face edge to edge ('..fill4.RW..' of '..face4.RW..' px)')end
   end
   C.set('DueAt',R.clock+200);C.set('Left',200);UW.frames(3,1/60);settle()
   list2,by2=UW.rects(hud,w,h)
   local gift0=icon.Visible
   local t2,s2=by2['TreadmillBonusHud.BonusRollButton.Face.Title'],by2['TreadmillBonusHud.BonusRollButton.Face.Sub']
   fitsText(face.Obj.Title,t2,'ALMOST THERE!',tag..': R153: the almost title (no badge while charging) is readable (10 px or more; 9 px on the very narrowest box, under 90 px)',t2.RW<90 and 9 or 10)
   for _,line in ipairs({'0:24','0:02','NEXT 5:41'})do fitsText(face.Obj.Sub,s2,line,tag..': R153: the clock line',8)end
   check(t2.RW>=title.RW and s2.RX==title.RX and t2.RX==title.RX and (not gift0 or t2.RW==title.RW),tag..': charging (no badge): the text keeps its place (and gets the corner room back without the gift)')
   C.set('Ready',1);UW.frames(3,1/60);settle()
   local list3,by3=UW.rects(hud,w,h)
   local m3=by3['TreadmillBonusHud.BonusRollButton.Face.Meter']
   check(m3.Visible and m3.RX>=face.RX and m3.RX+m3.RW<=face.RX+face.RW and m3.RY+m3.RH<=face.RY+face.RH,tag..': ready: the meter strip is inside the face, below the text')
   me:SetAttribute('TreadmillTraining',nil);C.set('Ready',0);C.set('DueAt',nil);UW.frames(3,1/60)
  end
 end
end
local count=0;for _ in pairs(sizesSeen)do count+=1 end
check(count>=3,'the screens produced several button sizes ('..count..')')
-- =====================================================================================================================
-- 2. The roll screen on every screen size
-- =====================================================================================================================
local cases={
 {Rarity='Common',Variant='Pack01',Stage=1,Label='Forest Seed Pack'},{Rarity='Uncommon',Variant='Pack02',Stage=6,Label='Jungle Seed Pack'},
 {Rarity='Rare',Variant='Pack03',Stage=2,Label='Desert Seed Pack'},{Rarity='Epic',Variant='Pack04',Stage=3,Label='Snow Seed Pack'},
 {Rarity='Legendary',Variant='Pack05',Stage=4,Label='Giant Lava Seed Pack'},{Rarity='Mythic',Variant='Pack06',Stage=5,Label='Giant Crystal Seed Pack'},
 {Rarity='Secret',Variant='EclipseReliquary',Stage=7,Label='Void Pack'},
}
local function open(case,ready)
 C.Reply={Ok=true,Stage=case.Stage,Variant=case.Variant,Rarity=case.Rarity,Label=case.Label,Pool='1,6,2,3,4,5,7',Ready=ready or 0}
 C.set('Ready',1);UW.frames(1,1/60)
 button.Activated:Fire()
end
local seen={}
-- Rest geometry is measured with ReducedMotion on (nothing bounces, pops or turns); the motion only ever moves parts inwards or scales them
-- up for a moment, so the rest pose is the tight case.
W.Gui.ReducedMotionEnabled=true
for _,v in ipairs(views)do
 local w,h=v[1],v[2];local key=w..'x'..h
 if not seen[key]then
  seen[key]=true
  W.UIS.TouchEnabled=v[3];placeControls(nil);C.size(w,h);UW.frames(2,1/60)
  local tag='roll '..key
  open(cases[5],1)
  local P=panel.Size
  panel.StripWindow.AbsoluteSize=R.Vector2.new(P.X.Offset-28,panel.StripWindow.Size.Y.Offset)
  UW.frames(10,1/60)
  -- spinning state
  local list,by=UW.rects(overlay,w,h)
  local function E(path)return by['TreadmillBonusRoll.Panel.'..path]end
  local pe=by['TreadmillBonusRoll.Panel']
  check(pe.X>=6 and pe.Y>=6 and pe.X+pe.W<=w-6 and pe.Y+pe.H<=h-6,tag..string.format(': the panel is on screen (%.0fx%.0f at %.0f,%.0f)',pe.W,pe.H,pe.X,pe.Y))
  -- R153: while it spins the Result row is hidden (no "already in ur bag" line) and the Status box spans the Status + Result rows, so the spin text is centred
  local rows={'Ribbon','StripWindow','Status','Actions','Odds'}
  local minGap={Ribbon=8,StripWindow=7,Status=6,Actions=6}
  for i=1,#rows-1 do
   local a,b=E(rows[i]),E(rows[i+1])
   check(a.Y+a.H<=b.Y+.01,tag..': '..rows[i]..' ends above '..rows[i+1]..string.format(' (%.1f vs %.1f)',a.Y+a.H,b.Y))
   check(b.Y-(a.Y+a.H)>=minGap[rows[i]]-.01,tag..': at least '..minGap[rows[i]]..' px between '..rows[i]..' and '..rows[i+1]..string.format(' (%.1f)',b.Y-(a.Y+a.H)))
  end
  local odds=E('Odds');check(odds.Y+odds.H<=pe.Y+pe.H-4,tag..string.format(': the odds line ends %.1f px above the panel bottom',pe.Y+pe.H-odds.Y-odds.H))
  for _,name in ipairs(rows)do local e=E(name);check(e.X>=pe.X and e.X+e.W<=pe.X+pe.W,tag..': '..name..' within the panel width')end
  -- bow and pointers
  local bow,ribbon,window=E('Bow'),E('Ribbon'),E('StripWindow')
  local bowKids=visibleKids(list,'TreadmillBonusRoll.Panel.Bow.');local bx0,by0,bx1,by1=math.huge,math.huge,-math.huge,-math.huge
  for _,e in ipairs(bowKids)do bx0=math.min(bx0,e.X);by0=math.min(by0,e.Y);bx1=math.max(bx1,e.X+e.W);by1=math.max(by1,e.Y+e.H)end
  check(by0>=pe.Y-.5 and bx0>=pe.X and bx1<=pe.X+pe.W,tag..string.format(': the bow stays inside the panel (top %.1f px below its edge)',by0-pe.Y))
  check(by1<=ribbon.Y+8 and by1<=window.Y,tag..': the bow only dips onto the ribbon top, clear of the title letters and the strip')
  check(math.abs((bx0+bx1)/2-(ribbon.X+ribbon.W/2))<1.5,tag..': the bow is centred on the ribbon')
  for _,name in ipairs({'PointerTop','PointerBottom'})do
   local p=E(name);check(p.X>=window.X and p.X+p.W<=window.X+window.W and p.Y>=ribbon.Y+ribbon.H-.5 and p.Y+p.H<=E('Status').Y+2.5,tag..': '..name..' sits on the strip edge without touching the rows around it')
  end
  -- the ribbon title
  local heading=E('Ribbon.Title');fitsText(panel.Ribbon.Title,heading,'TREADMILL BONUS ROLL',tag..': ribbon title',9)
  local pack=E('Ribbon.Pack')
  check(pack and pack.Visible and pack.X>=ribbon.X-.5 and pack.X+pack.W<=heading.X+.5 and pack.Y>=ribbon.Y-4 and pack.Y+pack.H<=ribbon.Y+ribbon.H+4,tag..': R153: the header pack picture sits on the left of the ribbon, left of the title, at most 4 px past its edges')
  check(heading.X>=ribbon.X and heading.X+heading.W<=ribbon.X+ribbon.W,tag..': the title is inside the ribbon')
  -- status lines and the hint
  for _,line in ipairs(Style.SpinLines)do fitsText(panel.Status,E('Status'),line,tag..': status line',10)end
  check(not E('Result').Visible and panel.Result.Text=='','R153: '..tag..': no hint line under the spin text (the result row is hidden)')
  local gapMid=(window.Y+window.H+E('Actions').Y)/2
  check(math.abs(E('Status').Y+E('Status').H/2-gapMid)<=1,'R153: '..tag..string.format(': the spin text is centred between the strip and the buttons (%.1f vs %.1f)',E('Status').Y+E('Status').H/2,gapMid))
  -- odds
  fitsText(panel.Odds,E('Odds'),panel.Odds.Text,tag..': odds',9)
  -- cards inside the window
  local cardsOk=true;local picked=0
  for i=Rules.Strip.Win-2,Rules.Strip.Win+2 do
   local card=by['TreadmillBonusRoll.Panel.StripWindow.Strip.Card'..i]
   if card then
    picked+=1
    cardsOk=cardsOk and card.RY>=window.RY and card.RY+card.RH<=window.RY+window.RH
    local plaque,rar,bio=by[card.Path..'.Plaque'],by[card.Path..'.Rarity'],by[card.Path..'.Biome']
    cardsOk=cardsOk and plaque.RY+plaque.RH<=card.RY+card.RH and rar.RY>=plaque.RY and rar.RY+rar.RH<=bio.RY+.5 and bio.RY+bio.RH<=plaque.RY+plaque.RH+1
   end
  end
  check(picked==5 and cardsOk,tag..': cards, plaques and their two text lines sit inside the strip window')
  local pic=by['TreadmillBonusRoll.Panel.StripWindow.Strip.Card'..Rules.Strip.Win..'.Picture']
  check(pic.RH>=44,tag..': the pack picture has room ('..pic.RH..' px)')
  -- revealed state with both buttons, for each rarity
  panel.Actions.Skip.Activated:Fire();UW.frames(2,1/60)
  for _,case in ipairs(cases)do
   panel.Actions.Close.Activated:Fire()
   open(case,1);panel.StripWindow.AbsoluteSize=R.Vector2.new(panel.Size.X.Offset-28,panel.StripWindow.Size.Y.Offset)
   panel.Actions.Skip.Activated:Fire();UW.frames(2,1/60)
   local l2,b2=UW.rects(overlay,w,h)
   local function E2(path)return b2['TreadmillBonusRoll.Panel.'..path]end
   local style=Style.Reveal(case.Rarity)
   local word=E2('Word');local result=E2('Result')
   check(word.Visible and result.Visible,tag..' '..case.Rarity..': word and result are showing')
   fitsText(panel.Word,word,style.Word,tag..' '..case.Rarity..': reveal word',12)
   fitsText(panel.Result,result,panel.Result.Text,tag..' '..case.Rarity..': result sentence',9)
   check(word.RY+word.RH<=result.RY+.01,tag..' '..case.Rarity..': the word is above the result line')
   local close,again=E2('Actions.Close'),E2('Actions.Again');local actions=E2('Actions')
   check(close.Visible and again.Visible,tag..' '..case.Rarity..': CLOSE and ROLL AGAIN both show')
   check(close.X>=actions.X-.01 and again.X+again.W<=actions.X+actions.W+.01 and close.X+close.W<=again.X+.01,tag..' '..case.Rarity..': the two buttons are inside the row and apart')
   check(math.abs((close.X+again.X+again.W)/2-(actions.X+actions.W/2))<1,tag..' '..case.Rarity..': the pair is centred')
   check(close.RH==actions.H and again.RH==actions.H,tag..' '..case.Rarity..': buttons fill the row height')
   fitsText(panel.Actions.Close.Face.Label,E2('Actions.Close.Face.Label'),style.Close,tag..' '..case.Rarity..': close caption',10)
   fitsText(panel.Actions.Again.Face.Label,E2('Actions.Again.Face.Label'),'ROLL AGAIN (2)',tag..' '..case.Rarity..': again caption',10)
   local rays=E2('StripWindow.Strip.Rays')
   check(rays and rays.Visible,tag..' '..case.Rarity..': the rays show ('..tostring(rays and rays.Path)..' '..tostring(panel.StripWindow.Strip:FindFirstChild('Rays'))..' revealed='..tostring(panel.Word.Visible)..')')
   -- R150 review: the reveal pieces fly inside the panel (over the strip window, under the ribbon header, the pointers and the bow)
   local fxLayer=b2['TreadmillBonusRoll.Panel.Fx'];local pan=b2['TreadmillBonusRoll.Panel']
   check(fxLayer and math.abs(fxLayer.W-pan.W)<.01 and math.abs(fxLayer.H-pan.H)<.01 and math.abs(fxLayer.X-pan.X)<.01 and math.abs(fxLayer.Y-pan.Y)<.01,tag..' '..case.Rarity..': the effect layer covers the panel')
   check(fxLayer.Obj.ZIndex>b2['TreadmillBonusRoll.Panel.StripWindow'].Obj.ZIndex and fxLayer.Obj.ZIndex<E2('Ribbon').Obj.ZIndex and fxLayer.Obj.ZIndex<E2('PointerTop').Obj.ZIndex and fxLayer.Obj.ZIndex<E2('Bow').Obj.ZIndex,tag..' '..case.Rarity..': the effect layer is over the strip window and under the ribbon, the pointers and the bow')
  end
  panel.Actions.Close.Activated:Fire()
  -- the spinning state shows SKIP centred
  open(cases[1],0);panel.StripWindow.AbsoluteSize=R.Vector2.new(panel.Size.X.Offset-28,panel.StripWindow.Size.Y.Offset);UW.frames(2,1/60)
  local l3,b3=UW.rects(overlay,w,h)
  local skip=b3['TreadmillBonusRoll.Panel.Actions.Skip'];local actions=b3['TreadmillBonusRoll.Panel.Actions']
  check(skip.Visible and math.abs(skip.X+skip.W/2-(actions.X+actions.W/2))<1 and skip.RW>=100,tag..': SKIP is centred and wide enough ('..skip.RW..')')
  fitsText(panel.Actions.Skip.Face.Label,b3['TreadmillBonusRoll.Panel.Actions.Skip.Face.Label'],'SKIP',tag..': skip caption',10)
  panel.Actions.Skip.Activated:Fire();panel.Actions.Close.Activated:Fire()
 end
end
W.Gui.ReducedMotionEnabled=false
-- =====================================================================================================================
-- 3. R153: the gift pill over the player's head is gone
-- =====================================================================================================================
me:SetAttribute('TreadmillTraining',true);C.set('Interval',360);C.set('Ready',0);C.set('DueAt',R.clock+222);C.set('Left',222);UW.frames(20,1/60);C.set('Ready',1);UW.frames(40,1/60)
check(UW.made.BillboardGui==nil and pg:FindFirstChild('TreadmillBonusProgress')==nil,'R153: standing on the treadmill, charging and ready: no BillboardGui is ever built')
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
