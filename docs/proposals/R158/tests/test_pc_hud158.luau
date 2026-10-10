--!nocheck
-- R158 PC HUD lock (owner, 10 Oct): the computer HUD (every window, consoles too) is the 1920 x 1080 arrangement of the owner's screenshot, laid out as a window and drawn shrunk to
-- fit (scale s = min(1, w / 1920, h / 720)); MENU sits a third of the way down ("A") and keeps close to its size (never under 85% of its 1920 x 1080 look: scale ms = max(s, .85)).
-- For one window w x h (the HUD area under Roblox's 52 px top bar; run_hud158.sh runs the five owner sizes and more, a process each) the REAL scripts of this checkout (the Hotbar, GardenWallet,
-- WorldStatusHud, PityBars155, the five-option wheel, TravelButtons) are built on the Roblox mock and the rect of every GUI object is taken from a layout emulation that knows
-- AnchorPoint and UIScale (hud_world158.luau). Checked, in real screen px:
--  1. scale     - s, ms, the laid-out window (1920 x 1080 for 16:9, 1920 wide for 4:3, 720 tall when the window is wider than 8:3), the MENU's centre and the wheel's numbers
--  2. same      - every HUD piece, divided by s, is where it is on a 1920 x 1080 window: the hotbar (10 slots + Bag, 82 px slots, 12 px up, centred), the balances (290 x 56 rows, 7 px
--                 apart, 12 px from the left, 16 px from the bottom), the status stack (337 x 125, 12 px from the right, 16 up), the bars (230 x 24 pairs, 8 px over the slots), the name rows,
--                 BASE / TRACK in Roblox's top bar row (their real size)
--  3. objects   - what is drawn is what HudLayout says: the real rect of the dock, each balance row, the status stack, the bars, the name rows, the MENU button and each wheel option equals the
--                 layout's own box (HudBoxes / PityBars155)
--  4. MENU      - hub and options are 64 x ms px (at least 54.4 = 85%), the hub's centre is h / 3 (or higher up where the wheel would not clear the balances), 8 x ms px between boxes
--  5. clear     - with the wheel open nothing overlaps: the five options, the hub, the balances, the hotbar and its name rows, the bars, the status stack, the BONUS ROLL button, the SKIP pill,
--                 BASE / TRACK, Roblox's top-left buttons and the closed wheel's friend chip; the reveal card's band ends over the bars
-- Usage: luau test_pc_hud158.luau -a <w> <h>     (-a golden <w> <h> prints the fingerprints, -a dump <w> <h> the texts)    "R158 PC HUD <w>x<h>: N checks, fails 0".
local args={...}
local golden=args[1]=='golden';local dump=args[1]=='dump'
if golden or dump then table.remove(args,1)end
local w,h=tonumber(args[1]),tonumber(args[2])
local TOP=52 -- Roblox's top bar (the HUD is laid out under it: CoreUISafeInsets)
local Scene=require('./hud_world158')
local W,R=Scene.W,Scene.R;local V2=R.Vector2.new
local fmt=string.format
local S=Scene.build({w=w,h=h,touch=false,ix=0,iy=TOP,vw=w,vh=h+TOP,bar=TOP})
local pg,Hud,B=S.pg,S.Hud,S.Bars
local Card=W.module('RarePullCard');local Rules=W.module('RarePullRules');local TBR=W.module('TreadmillBonusRules');local Notice=W.module('HudNoticeLayout')
local checks,fails=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,t)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(t or .01)end
local function nearRect(a,b,t,what)
 local ok=near(a.X,b.X,t)and near(a.Y,b.Y,t)and near(a.W,b.W,t)and near(a.H,b.H,t)
 return check(ok,fmt('%dx%d: %s: %s is at (%.2f,%.2f %.2fx%.2f), the layout says (%.2f,%.2f %.2fx%.2f)',w,h,what,what,a.X,a.Y,a.W,a.H,b.X,b.Y,b.W,b.H))
end
local function ov(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local function rect(o)return S.rect(o)end
local function boxOf(list,name)for _,b in ipairs(list)do if b.N==name then return b end end end
local tag=fmt('%dx%d',w,h)
local m=Hud.Read(V2(w,h),false,nil)
local s,ms=m.Scale,m.MenuScale
local out={}
local function put(name,text)out[#out+1]={name,S.hash(text),#text,text}end

-- 1. scale -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
local wantS=math.min(1,w/1920,h/720)
check(near(s,wantS,1e-12)and near(ms,math.max(wantS,.85),1e-12),fmt('%s: scale %.4f (want %.4f), MENU scale %.4f (want %.4f)',tag,s,wantS,ms,math.max(wantS,.85)))
check(near(m.VW*s,w,1e-6)and near(m.VH*s,h,1e-6)and m.VW>=1920-1e-9 and m.VH>=720-1e-9,fmt('%s: the laid-out window %.1f x %.1f is the window over the scale and at least 1920 x 720',tag,m.VW,m.VH))
check(s==1 or(w/1920<=h/720)==(math.abs(m.VW-1920)<1e-6)and(w/1920>=h/720)==(math.abs(m.VH-720)<1e-6 or w/1920==h/720),fmt('%s: laid out exactly 1920 wide (a window up to 8:3) or exactly 720 tall (wider): %.1f x %.1f',tag,m.VW,m.VH))
check(m.Slots==10 and m.SlotSize==82 and m.WalletHeight==56 and m.WalletWidth==290 and m.StatusScale==1 and m.HotbarDetails==true and m.Compact==false and m.Short==false,fmt('%s: ten 82 px slots, 290 x 56 balances, the status stack unscaled, the name rows shown: always the 1920 x 1080 arrangement',tag))
check(m.MenuSize==64 and m.MenuOptionSize==64 and #m.MenuOffsets==5,tag..': MENU px: a 64 px hub and five 64 px options, in MENU px')
check(m.Scale>=1-1e-12 or m.MenuScale>=.85-1e-12,tag..': MENU never under 85% of its size')

-- the real GUI objects ------------------------------------------------------------------------------------------------------------------------------------------------------------
local boxes=Hud.HudBoxes(m,w,h,false);local wheel=Hud.HudBoxes(m,w,h,true)
local hot=pg.ChestToolHotbar;local dock=hot.Dock
local eco=pg.ChestEconomyUI;local stack=pg.WorldStatus.StatusStack
local barsGui=pg.PackPityBars155.PityBars
local dockR=rect(dock)
-- 2. the arrangement of the owner's screenshot, in HUD px (the real rect over the scale) ------------------------------------------------------------------------------------------
local function virtual(r)return {X=r.X/s,Y=r.Y/s,W=r.W/s,H=r.H/s}end
local vw,vh=m.VW,m.VH
do
 local d=virtual(dockR)
 check(near(d.W,962,.02)and near(d.H,82,.02)and near(d.X+d.W/2,vw/2,.02)and near(vh-(d.Y+d.H),12,.02),fmt('%s: the hotbar is 962 x 82 (ten slots and the Bag), centred, 12 px up (got %.1f x %.1f, %.1f up)',tag,d.W,d.H,vh-(d.Y+d.H)))
 local slots={}
 for i=1,10 do local b=dock:FindFirstChild('Slot'..i);slots[i]=b and virtual(rect(b))end
 local okSlots=true
 for i=1,10 do if not(slots[i]and near(slots[i].W,82,.02)and near(slots[i].X-d.X,(i-1)*88,.02))then okSlots=false end end
 check(okSlots,tag..': ten 82 px slots, 6 px apart')
 local bag=virtual(rect(dock.OpenInventory))
 check(near(bag.W,82,.02)and near(bag.X+bag.W,d.X+d.W,.02),tag..': the Bag button is the eleventh 82 px slot, at the right end')
 local rows={}
 for i,name in ipairs({'SpeedHud','CashHud','GemHud'})do
  local r=virtual(rect(eco[name]));rows[i]=r
  check(near(r.X,12,.02)and near(r.W,290,.02)and near(r.H,56,.02)and near(r.Y,vh-16-182+(i-1)*63,.02),fmt('%s: balance row %d: 12 px from the left, 290 x 56, 7 px apart, the last 16 px up (got %.1f,%.1f %.1fx%.1f)',tag,i,r.X,r.Y,r.W,r.H))
 end
 local st=virtual(rect(stack))
 check(near(st.W,337,.02)and near(st.H,125,.02)and near(vw-(st.X+st.W),12,.02)and near(vh-(st.Y+st.H),16,.02),fmt('%s: the status stack is 337 x 125, 12 px from the right and 16 up (got %.1f x %.1f, %.1f / %.1f)',tag,st.W,st.H,vw-(st.X+st.W),vh-(st.Y+st.H)))
 local pair=S.Pity.Placement
 local nb,eb=virtual(rect(barsGui.NormalPity)),virtual(rect(barsGui.EventPity))
 check(near(nb.W,230,.02)and near(nb.H,24,.02)and near(eb.W,230,.02)and near(eb.X-(nb.X+nb.W),12,1.01)and near((nb.X+eb.X+eb.W)/2,vw/2,1.01),fmt('%s: the two bars are 230 x 24, 12 px apart, centred over the hotbar (got %.1f x %.1f)',tag,nb.W,nb.H))
 check(near(d.Y-(nb.Y+nb.H),8,1.01)and near(d.Y-(eb.Y+eb.H),8,1.01),tag..': the bars end 8 px over the slots')
 local nameBox=Hud.HudBoxes(m,w,h,false)
 local sel,traits=virtual(rect(dock.SelectedName)),virtual(rect(dock.SelectedTraits))
 check(near(sel.W,240,.02)and near(sel.X+sel.W/2,vw/2,.02)and near(traits.Y+traits.H,nb.Y-3,1.01)and near(traits.H,16,.02)and near(sel.H,26,.02),fmt('%s: the held item\'s name rows are 240 px wide, centred, 3 px over the bars',tag))
 check(pg:GetAttribute('PityBarsRow')==35,tag..': the bars tell the Hotbar the rows end 35 HUD px over the slots (8 + 24 + 3)')
 -- BASE / TRACK in Roblox's top bar row, their real size (the row is 52 px; the pair is 44 px tall, 3 px of shadow under it)
 local travel=pg.TravelButtons;local baseB,trackB=travel:FindFirstChild('BaseButton',true),travel:FindFirstChild('TrackButton',true)
 local br,tr=baseB and rect(baseB),trackB and rect(trackB)
 check(br and tr and near(br.H,44,.01)and near(tr.H,44,.01)and br.Y+TOP>=0 and br.Y+br.H<=0 and near(br.Y+TOP+br.H/2,TOP/2,.5),fmt('%s: BASE / TRACK keep their real size (44 px tall) in the top bar row, level with it',tag))
end

-- 3. the objects are where the layout says --------------------------------------------------------------------------------------------------------------------------------------
do
 nearRect(dockR,{X=boxOf(boxes,'Hotbar').X,Y=boxOf(boxes,'Hotbar').Y+boxOf(boxes,'Hotbar').H-dockR.H,W=boxOf(boxes,'Hotbar').W,H=dockR.H},.02,'the dock')
 nearRect(rect(eco.SpeedHud),boxOf(boxes,'WalletSpeed'),.02,'the Speed row');nearRect(rect(eco.CashHud),boxOf(boxes,'WalletCash'),.02,'the Cash row');nearRect(rect(eco.GemHud),boxOf(boxes,'WalletGem'),.02,'the Gems row')
 nearRect(rect(stack),boxOf(boxes,'Status'),.02,'the status stack')
 local pl=S.Pity.Placement;local ext=B.Extent(pl.Pair,pl.Bar.W,pl.Bar.H,pl.Scale or 1)
 local nb,eb=rect(barsGui.NormalPity),rect(barsGui.EventPity)
 nearRect({X=math.min(nb.X,eb.X),Y=nb.Y,W=eb.X+eb.W-nb.X,H=nb.H},pl.Pair,1,'the pair of bars (centres are whole HUD px)')
 local hubR=rect(S.hub)
 nearRect(hubR,boxOf(wheel,'Hub'),.02,'the MENU button')
 S.openWheel(true)
 for i=1,5 do nearRect(rect(S.nav['MenuOption'..i]:FindFirstChildWhichIsA('GuiButton')),boxOf(wheel,'Opt'..i),.02,'wheel option '..i)end
 -- 4. MENU ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
 local hub=boxOf(wheel,'Hub')
 check(near(hub.W,64*ms,.01)and near(hub.H,64*ms,.01)and hub.W>=54.4-1e-9,fmt('%s: the MENU button is %.1f px (64 x %.3f; never under 54.4 = 85%%)',tag,hub.W,ms))
 local okOpt=true;for i=1,5 do local o=boxOf(wheel,'Opt'..i);if not(near(o.W,64*ms,.01)and near(o.H,64*ms,.01))then okOpt=false end end
 check(okOpt,fmt('%s: the five options are %.1f px, as big as the MENU button',tag,64*ms))
 local centre=hub.Y+hub.H/2
 -- a third of the way down; on a short window the whole wheel (102 + 32 px up, 111 + 32 down, in MENU px) does not fit there and the hub moves the least it has to
 check(near(centre,h/3,.6)or(h<400 and centre>=h/3-.6),fmt('%s: the MENU button\'s centre is a third of the way down (%.1f of %.1f; want %.1f)',tag,centre,h,h/3))
 local top,bottom=math.huge,0;for i=1,5 do local o=boxOf(wheel,'Opt'..i);top=math.min(top,o.Y);bottom=math.max(bottom,o.Y+o.H)end
 check(top>=8*ms-.01 and bottom<=boxOf(boxes,'WalletSpeed').Y-8*ms+.01,fmt('%s: the open wheel (%.0f..%.0f) stays 8 MENU px under the top edge and 8 over the balances (%.0f)',tag,top,bottom,boxOf(boxes,'WalletSpeed').Y))
 -- 5. nothing overlaps ----------------------------------------------------------------------------------------------------------------------------------------------------------
 local items={}
 local function add(name,r)items[#items+1]={N=name,X=r.X,Y=r.Y,W=r.W,H=r.H}end
 add('Hub',hub);for i=1,5 do add('Opt'..i,boxOf(wheel,'Opt'..i))end
 for _,n in ipairs({'WalletSpeed','WalletCash','WalletGem','Status'})do add(n,boxOf(boxes,n))end
 local dockBox=boxOf(boxes,'Hotbar');add('Slots',{X=dockBox.X,Y=dockBox.Y+dockBox.H-dockR.H,W=dockBox.W,H=dockR.H})
 local res=B.Reserved(w,h,m,nil);add('Bars+rows',res)
 local rows=B.NameRows(w,h,m,nil,pl);add('NameRows',rows)
 -- BASE / TRACK and Roblox's own buttons, in HUD coordinates (the top bar row is above the HUD area: negative y)
 for _,n in ipairs({'BaseButton','TrackButton'})do local b=pg.TravelButtons:FindFirstChild(n,true);local r=rect(b);add('Travel'..n,{X=r.X,Y=r.Y,W=r.W,H=r.H+3})end
 add('RobloxTopLeft',{X=0,Y=-TOP,W=100,H=TOP});add('RobloxTopRight',{X=w-100,Y=-TOP,W=100,H=TOP})
 -- BONUS ROLL (what TreadmillBonusClient asks) and the SKIP pill (a card that leaves the HUD up)
 local notice={}
 for name,r in pairs(Notice.Calculate(w,h,TOP,TBR.NoticeFlags))do if type(r)=='table'then notice[#notice+1]={N=name,X=r.X-r.Width/2,Y=r.Y,W=r.Width,H=r.Height}end end
 local btn=B.ButtonSpot(TBR,m,w,h,wheel,notice);add('BonusRoll',btn)
 local sx,sy,sw,sh=Card.SkipRect(w,h,false,Card.SkipBoxes(w,h,false,nil));add('SkipPill',{X=sx,Y=sy,W=sw,H=sh})
 -- the closed wheel's friend chip (right of the MENU button, scaled with it)
 local bad={}
 local function group(n)return n:match('^Opt')and'wheel'or n=='Hub'and'wheel'or n end
 for i=1,#items do for j=i+1,#items do
  local a,b=items[i],items[j]
  local skip=(group(a.N)=='wheel'and group(b.N)=='wheel')or(a.N:match('^Wallet')and b.N:match('^Wallet'))or(a.N:match('^Travel')and b.N:match('^Travel'))or(a.N=='Bars+rows'and b.N=='NameRows')or(b.N=='Bars+rows'and a.N=='NameRows')or(a.N=='BonusRoll'and b.N=='SkipPill')
  if not skip and ov(a,b)then bad[#bad+1]=a.N..' x '..b.N end
 end end
 check(#bad==0,fmt('%s: nothing overlaps with the wheel open (%d boxes): %s',tag,#items,table.concat(bad,', ')))
 local opts={};for i=1,5 do opts[i]=boxOf(wheel,'Opt'..i)end
 local gapOk=true;local gapMin=math.huge
 for i=1,5 do for j=i+1,5 do
  local dx=math.max(opts[j].X-(opts[i].X+opts[i].W),opts[i].X-(opts[j].X+opts[j].W));local dy=math.max(opts[j].Y-(opts[i].Y+opts[i].H),opts[i].Y-(opts[j].Y+opts[j].H))
  local gap=math.max(dx,dy);gapMin=math.min(gapMin,gap)
  if gap<8*ms-.01 then gapOk=false end
 end end
 check(gapOk,fmt('%s: the options are at least 8 x ms = %.1f px apart (closest %.1f)',tag,8*ms,gapMin))
 -- the card's band ends over the bars and the name rows
 local _,bandBottom=Card.FitBand(pg.ChestToolHotbar,V2(w,h+TOP),1,false,false)
 check(bandBottom<=res.Y+TOP+.01,fmt('%s: the reveal card\'s band ends (%.1f) over the bars and the name rows (%.1f)',tag,bandBottom,res.Y+TOP))
 S.openWheel(false)
 pg:SetAttribute('MenuFriendBoost','+20%');S.frames(2)
 local chip=S.hub:FindFirstChild('FriendBoost')
 if check(chip and chip.Visible,tag..': the friend chip shows beside the closed MENU button')then
  local cr=rect(chip);local hubR2=rect(S.hub)
  check(near(cr.X,hubR2.X+hubR2.W+Hud.ChipSize.Gap*ms,.02)and near(cr.W,Hud.ChipSize.X*ms,.02)and near(cr.Y+cr.H/2,hubR2.Y+hubR2.H/2,.02),fmt('%s: the chip is %.1f x %.1f px, %.1f px right of the MENU button, level with it',tag,cr.W,cr.H,Hud.ChipSize.Gap*ms))
  local clash={}
  for _,it in ipairs(items)do if it.N~='Hub'and not it.N:match('^Opt')and ov(cr,it)then clash[#clash+1]=it.N end end
  check(#clash==0,fmt('%s: the friend chip overlaps nothing: %s',tag,table.concat(clash,', ')))
 end
 pg:SetAttribute('MenuFriendBoost',nil)
end

-- 6. the badges on the scaled wheel and the tutorial's boxes -------------------------------------------------------------------------------------------------------------------------------
do
 local Guide=W.module('BeginnerGuide');local Badge=W.module('NotifyBadge151')
 S.openWheel(true)
 S.player:SetAttribute('DailyLoginReady',true);S.player:SetAttribute('DailyQuestsReady',1);S.frames(4)
 local seen,clipped,wrongSize=0,{},{}
 for i=1,5 do
  local g=S.nav['MenuOption'..i];local gr=rect(g)
  for _,b in ipairs(g:GetDescendants())do if b.Name=='RewardBadge'and b.Visible then
   seen+=1;local br=rect(b)
   if br.X<gr.X-.01 or br.Y<gr.Y-.01 or br.X+br.W>gr.X+gr.W+.01 or br.Y+br.H>gr.Y+gr.H+.01 then clipped[#clipped+1]=g.Name end
   if not near(br.W,Badge.Sizes.Count*ms,.6)then wrongSize[#wrongSize+1]=g.Name..' '..br.W end
  end end
 end
 check(seen>=2 and #clipped==0,fmt('%s: the INDEX and DAILY badges (%d) sit inside their options\' CanvasGroups, so nothing is cut off (%s)',tag,seen,table.concat(clipped,', ')))
 check(#wrongSize==0,fmt('%s: the badges are %.1f px (the Count size %d x the MENU scale %.3f; %s)',tag,Badge.Sizes.Count*ms,Badge.Sizes.Count,ms,table.concat(wrongSize,', ')))
 S.openWheel(false)
 S.pg:SetAttribute('MenuAlertDaily',1);S.frames(3)
 local alert=S.hub:FindFirstChild('IndexRewardAlert')
 check(alert and alert.Visible and near(rect(alert).W,Badge.Sizes.Alert*ms,.6),fmt('%s: the closed MENU button\'s red "!" is %.1f px (the Alert size %d x %.3f)',tag,Badge.Sizes.Alert*ms,Badge.Sizes.Alert,ms))
 S.pg:SetAttribute('MenuAlertDaily',nil);S.player:SetAttribute('DailyLoginReady',false);S.player:SetAttribute('DailyQuestsReady',0);S.frames(2)
 -- the tutorial's obstacles (screen px) cover every HUD box, and its card clears them
 local obs=Guide.Obstacles(m,w,h,nil)
 local missing={}
 local function covered(b)for _,o in ipairs(obs)do if b.X>=o.X-.51 and b.Y>=o.Y-.51 and b.X+b.W<=o.X+o.W+.51 and b.Y+b.H<=o.Y+o.H+.51 then return true end end;return false end
 for _,b in ipairs(boxes)do if b.N~='OwnerTools'and not covered(b)then missing[#missing+1]=b.N end end
 check(#missing==0,fmt('%s: the tutorial card keeps clear of the hub, the balances, the hotbar and its name rows and the status stack (%s not covered)',tag,table.concat(missing,', ')))
 local detail=Guide.HotbarDetail(m,h)
 check(near(detail,math.ceil(77-1e-9)*s,.01)or near(detail,77*s,.01),fmt('%s: the tutorial reserves %.1f px over the slots for the name rows and bars (77 x %.3f)',tag,detail,s))
 local card=Guide.Card(w,h,m,function(width)return 100 end,nil,nil,420)
 local cb={X=card.X-card.Width/2,Y=card.Top,W=card.Width,H=card.Height};local hit={}
 for _,o in ipairs(obs)do if not o.Character and ov(cb,o)then hit[#hit+1]=o.N or'box'end end
 check(card.Clear and #hit==0,fmt('%s: the tutorial card (%.0f x %.0f at %.0f,%.0f) clears every box',tag,card.Width,card.Height,cb.X,cb.Y))
end

-- fingerprints of the PC layout (the hotbar, balances, status, bars, the wheel open and closed, the numbers) -------------------------------------------------------------------------
do
 local function treeOf(name)local g=pg:FindFirstChild(name);return g and S.tree(g)or'(missing '..name..')'end
 S.frames(4)
 put('read',S.ser(m));put('boxes',S.ser(Hud.HudBoxes(m,w,h,false)));put('boxes_open',S.ser(Hud.HudBoxes(m,w,h,true)))
 put('hotbar',treeOf('ChestToolHotbar'));put('wallet',treeOf('ChestEconomyUI'));put('status',treeOf('WorldStatus'));put('bars',treeOf('PackPityBars155'));put('wheel_closed',treeOf('GardenNavigation'))
 S.openWheel(true);put('wheel_open',treeOf('GardenNavigation'));put('daily',treeOf('DailyRewardsGui'));put('travel',treeOf('TravelButtons'))
 S.openWheel(false)
 local pl=S.Pity.Placement
 put('pity',S.ser({Place=pl.Hud and{Bar=pl.Hud.Bar,Pair=pl.Hud.Pair,Centers=pl.Hud.Centers}or{Bar=pl.Bar,Pair=pl.Pair,Centers=pl.Centers},Reserved=B.Reserved(w,h,m,nil),Rows=B.NameRows(w,h,m,nil,pl)}))
end
if golden then
 for _,o in ipairs(out)do print(fmt('GOLDEN\t%s:%s\t%s',tag,o[1],o[2]))end
 return
end
if dump then for _,o in ipairs(out)do print('=== '..o[1]..' '..o[2]);print(o[4])end;return end
-- the owner-size summary (the report's numbers)
do
 local hub=boxOf(wheel,'Hub');local top,bottom=math.huge,0;for i=1,5 do local o=boxOf(wheel,'Opt'..i);top=math.min(top,o.Y);bottom=math.max(bottom,o.Y+o.H)end
 print(fmt('PC %s: HUD scale %.3f (laid out %.0f x %.0f), MENU scale %.3f: hub %.1f px at centre %.0f, options %.1f px, wheel %.0f..%.0f, balances at %.0f; slots %.1f px, balance rows %.1f px',
  tag,s,m.VW,m.VH,ms,hub.W,hub.Y+hub.H/2,boxOf(wheel,'Opt1').W,top,bottom,boxOf(boxes,'WalletSpeed').Y,82*s,56*s))
end
-- the golden fingerprints, taken from the built layout -------------------------------------------------------------------------------------------------------------------------------
local GOLDEN={}
-- GOLDEN-BEGIN
 GOLDEN['1920x1080:read']='f5a08a25' GOLDEN['1920x1080:boxes']='4407256e' GOLDEN['1920x1080:boxes_open']='94c24ef8' GOLDEN['1920x1080:hotbar']='afe03d8d' GOLDEN['1920x1080:wallet']='cff059bb' GOLDEN['1920x1080:status']='52fd2f33' GOLDEN['1920x1080:bars']='215814cb' GOLDEN['1920x1080:wheel_closed']='6ae01816' GOLDEN['1920x1080:wheel_open']='4578bd2c' GOLDEN['1920x1080:daily']='8b3f4ab6' GOLDEN['1920x1080:travel']='2ec3321f' GOLDEN['1920x1080:pity']='83af7408'
 GOLDEN['1366x768:read']='9a1054d6' GOLDEN['1366x768:boxes']='c15031ae' GOLDEN['1366x768:boxes_open']='23ffd80f' GOLDEN['1366x768:hotbar']='7a490638' GOLDEN['1366x768:wallet']='2de34223' GOLDEN['1366x768:status']='41702f5c' GOLDEN['1366x768:bars']='99a1183a' GOLDEN['1366x768:wheel_closed']='7edb72bf' GOLDEN['1366x768:wheel_open']='6909b62a' GOLDEN['1366x768:daily']='f302159e' GOLDEN['1366x768:travel']='2431840d' GOLDEN['1366x768:pity']='e1cf0790'
 GOLDEN['1280x720:read']='d886c604' GOLDEN['1280x720:boxes']='e503d4cc' GOLDEN['1280x720:boxes_open']='c444f112' GOLDEN['1280x720:hotbar']='a9c4405f' GOLDEN['1280x720:wallet']='5b8d0ddb' GOLDEN['1280x720:status']='4998e006' GOLDEN['1280x720:bars']='52f70af5' GOLDEN['1280x720:wheel_closed']='53ae14f0' GOLDEN['1280x720:wheel_open']='6ba3217d' GOLDEN['1280x720:daily']='09d20ac9' GOLDEN['1280x720:travel']='4cbc9bb8' GOLDEN['1280x720:pity']='1735539f'
 GOLDEN['1024x768:read']='4dab5fe9' GOLDEN['1024x768:boxes']='e5b8e1ef' GOLDEN['1024x768:boxes_open']='886214c6' GOLDEN['1024x768:hotbar']='19c7b834' GOLDEN['1024x768:wallet']='5f3fdf86' GOLDEN['1024x768:status']='cb14a75e' GOLDEN['1024x768:bars']='27177393' GOLDEN['1024x768:wheel_closed']='7edb72bf' GOLDEN['1024x768:wheel_open']='6909b62a' GOLDEN['1024x768:daily']='9c767946' GOLDEN['1024x768:travel']='89014fda' GOLDEN['1024x768:pity']='37ab9cf7'
 GOLDEN['800x600:read']='9bfac641' GOLDEN['800x600:boxes']='bf30bf4d' GOLDEN['800x600:boxes_open']='39858ca7' GOLDEN['800x600:hotbar']='79d1746b' GOLDEN['800x600:wallet']='e40987ba' GOLDEN['800x600:status']='a275b612' GOLDEN['800x600:bars']='68c90ec6' GOLDEN['800x600:wheel_closed']='738dc00e' GOLDEN['800x600:wheel_open']='e21c23d8' GOLDEN['800x600:daily']='505298ec' GOLDEN['800x600:travel']='6e8685f2' GOLDEN['800x600:pity']='9d7a97e4'
-- GOLDEN-END
for _,o in ipairs(out)do
 -- (the owner's five windows have fingerprints; the other windows are checked by the numbers above)
 local want=GOLDEN[tag..':'..o[1]]
 if GOLDEN[tag..':read']==nil then break end
 checks+=1
 if want~=o[2]then fails+=1;print(fmt('FAIL: %s %s moved (fingerprint %s, was %s; %d chars)',tag,o[1],o[2],tostring(want),o[3]))end
end
print(fmt('R158 PC HUD %s: %d checks, fails %d',tag,checks,fails))
if fails>0 then error('the PC HUD does not match')end
