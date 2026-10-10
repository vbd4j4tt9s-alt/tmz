-- R155 (owner): the pack pity's two bars, always on the HUD, slightly above the hotbar. Owner: "upon holding a pack a bar would show on the players screen
-- slightly above the hot bar 1/10 pity" -> "there can be 2 separate bars above the hot bar one coloured gold the other coloured purple" -> "make it so that
-- they are always visible and they are polished properly". The counts are the server's (PackPity155 attributes on the player); this only shows them.
--  * NORMAL pity on the left ("3/10 pity"), EVENT pity (Void / Verity / Mech) on the right ("3/10 event pity"). The fill moves in ten
--    steps and eases to a new count; ten ticks mark the steps. (R157: NORMAL clover green, EVENT gold with a clover-green rim, the clover at the left end;
--    R155 had them gold and purple with a diamond.)
--  * 9/10: the bar glows (a soft pulse) and says "9/10 next one's lucky!".
--  * The bar of the group of the pack in your hand is brighter and slightly larger; the other one stays, a little dimmer.
--  * A lucky pack: its reveal tells you and the bar pops (full, a flash, a shine across, a ring, "LUCKY PACK! x1.5 luck", then it drains back to 0/10).
--    With the reveal card (Common..Mythic, the usual case) a "LUCKY PACK! x1.5 luck" TAG sits on the card, in the free band between the seed and its "1 in N"
--    (its own ScreenGui just above the card: RarePullCinematic / RarePullCard are not touched); the card's words sit where the bars are, so the bars step
--    aside (fade out) while it is up and come back with the collect, popping. The compact card (in place / skip animations) gets the tag under it and the
--    bars pop at once. A story scene (Secret+) hides the whole HUD: the notice and the pop wait for it to end. No reveal at all: the top notice and the pop.
--  * Reduced Motion: no shine sweep, no pop / highlight scaling, no pulse, no ring; counts change at once; the lucky moment is the words and a steady glow.
--  * Placement: its own ScreenGui (DisplayOrder 23, like the status HUD it never overlaps: under the hotbar / Bag (25), the tutorial (25 / 26), BASE / TRACK and the
--    plant indicators (24), the reveal cards (96) and the notices (100)), centred on the hotbar
--    (ChestToolHotbar.Dock, found by name at every layout change; the same HudLayout metrics when it is not there), just over its slots (R157; the held item's
--    name rows sit above the bars, R155 had the bars above them). It keeps
--    clear of every other HUD box (HudLayout.HudBoxes: menu, balances, status, thumb / jump zones, owner tools) and of the SKIP button of an
--    opening (the bottom-right corner, SkipZone); the SKIP button in turn keeps clear of the bars' extent (B.Reserved, taken by RarePullCard.SkipRect as a box:
--    on a phone the thumb controls push the button left of the corner, up to where the bars are); hidden while a menu covers the HUD (SeedMenu), like the status HUD.
--  * The treadmill BONUS ROLL button also wants the place just above the hotbar: it takes the bars' extent as a box and sits above them (B.ButtonSpot, which
--    TreadmillBonusClient asks; TreadmillBonusRules itself is unchanged), so the bars never move when the button comes and goes.
--  * Cost: a bar at rest costs nothing; a bar at 9/10 only writes its glow's transparency each frame (the rest is painted when something changes); nothing
--    is drawn while the HUD is hidden.
local Run=game:GetService('RunService');local GuiService=game:GetService('GuiService')
local Pity=require(script.Parent.PackPity155)
local Hud=require(script.Parent.HudLayout)
-- R157 (the R156 preview "pity bars v2", owner: "the pity bar is too high up and should be closer to the hot bar like really close but with a small gap"): the bars
-- used to sit 6 px above the held item's name and traits rows, which are 44 px tall (Hotbar.client: SelectedName -44 .. -18, SelectedTraits -18 .. -2 above the slots), so the
-- gap to the slots was 44 + 6 = 50 px. Now they sit B.Gap(...) px above the slots (8 on a PC, 6 / 5 on a phone) and the name / traits rows sit ABOVE them (B.NameRow: how far
-- up the Hotbar puts them, published as the PlayerGui attribute PityBarsRow). The clover (CloverIcon153) replaces the diamond; the fill starts after it (B.Lead). The numbers
-- live in HudLayout (PityGap, PityBarHeight, NameClear / NameBand / NameWidth), which tells from them whether the rows can show on a screen.
local B={Name='PackPityBars155',TagName='PackPityLuckyTag155',TagOrder=97,DisplayOrder=23,Pad=2,Glow=5,HeldScale=1.06,MaxRise=60,PopSeconds=1.7,DrainAt=1.05,Settle=.3,MaxWait=180}
B.NameClear=Hud.NameClear -- the held item's name / traits rows end this far above the bars' top edge (the 9/10 glow is a soft halo and may touch them)
B.NameBand=Hud.NameBand -- their height (SelectedName 26 + SelectedTraits 16)
B.NameWidth=Hud.NameWidth -- at most this wide, centred on the hotbar (their text is centred)
-- The gap between the bars' bottom edge and the slots' top: 8 px on a PC (the held bar's 2 px rim and the selected slot's 2 px ring sit in it), 6 px on a phone, 5 on a thin phone bar.
B.Gap=Hud.PityGap
-- The clover's disc takes the left end (barH wide); the fill runs from there to the right end.
function B.Lead(barH)return math.floor(barH*.92)end
B.Font=Enum.Font.FredokaOne
local RGB=Color3.fromRGB
local WHITE=Color3.new(1,1,1)
local TRACK=RGB(18,14,30)
-- The bottom-right corner the R155 SKIP button uses while a pack opens (it sits there on every device): the bars never go there.
function B.SkipZone(w,h)
 local zh=math.max(80,math.floor(h*.16))
 return {N='Skip',X=math.floor(w*.75),Y=h-zh,W=w-math.floor(w*.75),H=zh}
end
-- R158: a computer's HUD is the 1920 x 1080 arrangement drawn at m.Scale (HudLayout): its pieces are laid out in HUD px (the window m.VW x m.VH) and shrunk by m.Scale, and the
-- bars live in that space too (their root is a UIScale'd frame of that size). The public functions below keep working in REAL screen px - w, h, the dock, the answers (Place's Pair /
-- Centers / Bar, Reserved, NameRows, ButtonSpot) - as they always did, so every caller (RarePullCard, TreadmillBonusClient, the tests) is right at any scale; each does its work in HUD
-- px and scales the answer by m.Scale. A real Place answer also carries `Hud`, the same answer in HUD px (what the bars are drawn from); both are the same table at scale 1 (no Hud).
-- B.NameRow is the one HUD-px number (how far up inside the scaled dock the rows end: the Hotbar's own units). m.Scale is nil / 1 on a phone and on a window of 1920 x 720 or more.
local function sc(r,s)return {X=r.X*s,Y=r.Y*s,W=r.W*s,H=r.H*s}end
-- HudLayout's boxes in HUD px (w, h: the window's size in HUD px)
local function boxesHud(m,w,h)
 local s=m.Scale or 1
 if s==1 then return Hud.HudBoxes(m,w,h,false)end
 local out=Hud.HudBoxes(m,w*s,h*s,false)
 for _,b in ipairs(out)do b.X,b.Y,b.W,b.H=b.X/s,b.Y/s,b.W/s,b.H/s end
 return out
end
-- The hotbar's rect as HudLayout gives it (the hotbar's own layout): {X, Y, W, H}.
local function dockHud(m,w,h)
 local side=m.SlotSize;local width=(m.Slots+1)*side+m.Slots*6
 return {X=w/2+(m.HotbarShiftX or 0)-width/2,Y=h-m.HotbarBottom-side,W=width,H=side}
end
function B.DefaultDock(m,w,h)
 local s=m.Scale or 1
 if s==1 then return dockHud(m,w,h)end
 return sc(dockHud(m,m.VW,m.VH),s)
end
local function overlaps(a,b,pad)
 return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad
end
-- Where the two bars go. w, h: the screen (the safe area the HUD uses); m: HudLayout.Read; dock: the hotbar's rect (nil = DefaultDock).
-- Side by side, centred just above the hotbar and its item name, is the first choice. When a HUD box is in the way (a small window lifts the balances
-- and the status beside the hotbar; a short portrait phone has the MENU button and BASE / TRACK on the left) it slides sideways a little, then tries a
-- narrower pair, then the two bars one above the other, then a little higher (never more than MaxRise); the first that is clear of everything wins.
-- Returns {Bar = {W, H}, Gap, Stacked, Pair = {X, Y, W, H} (the room both take), Centers = {Normal = {X, Y}, Event = {X, Y}}, Clear = nothing in the way}.
B.MinText=9
local function placeHud(w,h,m,dock)
 dock=dock or dockHud(m,w,h)
 local phone=m.Phone==true
 local barH=Hud.PityBarHeight(phone,h)
 local gap=phone and 8 or 12;local rowGap=4
 local boxes={}
 for _,b in ipairs(boxesHud(m,w,h))do if b.N~='Hotbar'then boxes[#boxes+1]=b end end
 boxes[#boxes+1]=B.SkipZone(w,h)
 local below={N='Dock',X=dock.X,Y=dock.Y,W=dock.W,H=dock.H} -- the hotbar's slots: the bars sit just above (R157: the item's name and traits rows are above the bars now)
 local cx=dock.X+dock.W/2
 local half=math.floor((dock.W-gap)/2)
 local wide=phone and math.clamp(math.floor(half*.8),130,200)or math.clamp(math.floor(dock.W*.25),150,230)
 wide=math.max(96,math.min(wide,half))
 -- what a pair can cover: the bars, their 9/10 glow and the held bar's 1.06 scale (B.Extent); B.Pad more around that
 local function fits(r,barW,bh)
  local e=B.Extent(r,barW,bh)
  if e.X<2 or e.X+e.W>w-2 or e.Y<2 or overlaps(r,below,0)then return false end
  for _,b in ipairs(boxes)do if overlaps(e,b,B.Pad)then return false end end
  return true
 end
 local function readable(barW,bh)return B.TextSize(B.Words('Normal',Pity.Every-1,barW,bh),barW,bh)>=B.MinText and B.TextSize(B.Words('Event',0,barW,bh),barW,bh)>=B.MinText end
 local narrow=math.max(96,math.floor(wide*.85))
 local shapes={{W=wide,H=barH},{W=narrow,H=barH}}
 -- (phones: a thinner pair first, where the MENU button / BASE / TRACK sit just above the hotbar's item name, then the two bars one above the other)
 if phone and barH>16 then shapes[#shapes+1]={W=wide,H=16};shapes[#shapes+1]={W=narrow,H=16}end
 shapes[#shapes+1]={W=math.min(math.floor(dock.W*.8),math.max(wide,math.floor(wide*1.25))),H=barH,Stacked=true}
 local maxShift=math.floor(dock.W*.35)
 local found
 -- (first just above the hotbar, every shape; only then higher up)
 for _,band in ipairs({{0,12},{18,B.MaxRise}})do for rise=band[1],band[2],6 do
  for _,shape in ipairs(shapes)do
   if readable(shape.W,shape.H)then
    local r=shape.Stacked and{W=shape.W,H=shape.H*2+rowGap}or{W=shape.W*2+gap,H=shape.H}
    for step=0,maxShift,4 do
     for _,dx in ipairs(step==0 and{0}or{step,-step})do
      local pair={X=cx-r.W/2+dx,Y=dock.Y-B.Gap(phone,shape.H)-r.H-rise,W=r.W,H=r.H}
      if fits(pair,shape.W,shape.H)then found={Pair=pair,W=shape.W,H=shape.H,Stacked=shape.Stacked==true};break end
     end
     if found then break end
    end
   end
   if found then break end
  end
  if found then break end
 end if found then break end end
 local clear=found~=nil
 if not found then found={Pair={X=cx-wide-gap/2,Y=dock.Y-B.Gap(phone,barH)-barH,W=wide*2+gap,H=barH},W=wide,H=barH,Stacked=false}end
 local pair,barW=found.Pair,found.W;barH=found.H
 local centers
 if found.Stacked then centers={Normal={X=pair.X+barW/2,Y=pair.Y+barH/2},Event={X=pair.X+barW/2,Y=pair.Y+barH+rowGap+barH/2}}
 else centers={Normal={X=pair.X+barW/2,Y=pair.Y+barH/2},Event={X=pair.X+barW+gap+barW/2,Y=pair.Y+barH/2}}end
 return {Bar={W=barW,H=barH},Gap=gap,Stacked=found.Stacked,Pair=pair,Clear=clear,Phone=phone,Centers=centers}
end
function B.Place(w,h,m,dock)
 local s=m.Scale or 1
 if s==1 then return placeHud(w,h,m,dock)end
 local p=placeHud(m.VW,m.VH,m,dock and sc(dock,1/s)or nil)
 return {Bar={W=p.Bar.W*s,H=p.Bar.H*s},Gap=p.Gap*s,Stacked=p.Stacked,Pair=sc(p.Pair,s),Clear=p.Clear,Phone=p.Phone,Scale=s,Hud=p,
  Centers={Normal={X=p.Centers.Normal.X*s,Y=p.Centers.Normal.Y*s},Event={X=p.Centers.Event.X*s,Y=p.Centers.Event.Y*s}}}
end
-- The room a pair {X, Y, W, H} of bars (each barW x barH) can cover: its glow (B.Glow px) and the held bar's scale. k: the scale the numbers are in (a real Place answer: its
-- m.Scale; the glow is B.Glow HUD px), 1 by default.
function B.Extent(r,barW,barH,k)
 k=k or 1
 local gx=B.Glow*k+barW*(B.HeldScale-1)/2;local gy=B.Glow*k+barH*(B.HeldScale-1)/2
 return {X=r.X-gx,Y=r.Y-gy,W=r.W+gx*2,H=r.H+gy*2}
end
-- The room the bars take on a screen (their extent: the glow and the held bar's scale included) as a HUD box, from the same inputs they are placed with. The SKIP
-- button of an opening (RarePullCard.SkipRect), the BONUS ROLL button (B.ButtonSpot) and the reveal card (RarePullCard.FitBand) keep clear of it; dock: the hotbar's
-- rect (nil = HudLayout's default). R157: the held item's name / traits rows sit right above the bars now (B.NameRows), so the box takes them in too where they show.
local nameRowsHud
local function reservedHud(w,h,m,dock)
 local d=dock or dockHud(m,w,h)
 local place=placeHud(w,h,m,d)
 local e=B.Extent(place.Pair,place.Bar.W,place.Bar.H)
 local x0,y0,x1,y1=e.X,e.Y,e.X+e.W,e.Y+e.H
 if m.HotbarDetails~=false then
  local r=nameRowsHud(w,h,m,d,place)
  x0=math.min(x0,r.X);x1=math.max(x1,r.X+r.W);y0=math.min(y0,r.Y)
 end
 return {N='PityBars',X=x0,Y=y0,W=x1-x0,H=y1-y0}
end
function B.Reserved(w,h,m,dock)
 local s=m.Scale or 1
 if s==1 then return reservedHud(w,h,m,dock)end
 local box=sc(reservedHud(m.VW,m.VH,m,dock and sc(dock,1/s)or nil),s);box.N='PityBars'
 return box
end
-- R157: how far above the slots the held item's name / traits rows end: Hotbar.client puts SelectedTraits' bottom edge this far above the dock's top (it was a fixed 2 px) and
-- SelectedName above it (-> SelectedTraits.Y = -(row + 16), SelectedName.Y = -(row + 42); with no traits line the name drops into its row: -(row + 26)); just over the bars'
-- top edge, wherever Place put them. The Hotbar reads it from the PlayerGui attribute PityBarsRow, which the bars write whenever they are placed (like ChestHotbarReserve).
-- dock: the hotbar's rect (nil = DefaultDock); place: B.Place's answer when the caller has it.
local function nameRowHud(w,h,m,dock,place)
 local d=dock or dockHud(m,w,h)
 return math.ceil(d.Y-(place or placeHud(w,h,m,d)).Pair.Y)+B.NameClear
end
nameRowsHud=function(w,h,m,dock,place)
 local d=dock or dockHud(m,w,h)
 local width=math.min(d.W,B.NameWidth)
 return {N='NameRows',X=d.X+d.W/2-width/2,Y=d.Y-nameRowHud(w,h,m,d,place)-B.NameBand,W=width,H=B.NameBand}
end
-- (R158: at a scale under 1 the answer is in HUD px - the units inside the scaled dock, which is where the Hotbar puts the rows - and place is B.Place's real answer or nil)
function B.NameRow(w,h,m,dock,place)
 local s=m.Scale or 1
 if s==1 then return nameRowHud(w,h,m,dock,place)end
 return nameRowHud(m.VW,m.VH,m,dock and sc(dock,1/s)or nil,place and place.Hud or nil)
end
-- R157: the rows' box {N, X, Y, W, H} (the Hotbar's labels: NameBand tall, at most NameWidth wide, centred on the hotbar), whether or not this screen shows them (real screen px).
function B.NameRows(w,h,m,dock,place)
 local s=m.Scale or 1
 if s==1 then return nameRowsHud(w,h,m,dock,place)end
 local box=sc(nameRowsHud(m.VW,m.VH,m,dock and sc(dock,1/s)or nil,place and place.Hud or nil),s);box.N='NameRows'
 return box
end
-- The treadmill BONUS ROLL button (TreadmillBonusClient) wants the same place, just above the hotbar. It takes the bars' extent as one more box and lifts its
-- preferred spot above it: TreadmillBonusRules.Place measures that spot from m.HotbarBottom, so it gets a copy of m with the bars' height added to it; every
-- other spot Rules.Place tries is tested against the bars too. The answer is the same whether the button shows or not (the bars are always there), so nothing
-- flickers when it comes and goes. rules: TreadmillBonusRules; boxes, extra: what the client gives Rules.Place; returns its rect {X, Y, W, H}.
-- R157: the menu wheel's two new lower options (DAILY, INVITE) stand just over the bars on a portrait phone, so the place right above them is often taken by an option of
-- the open wheel (boxes): before the rules send the button to the screen's edge, it slides sideways along that row (8 px steps, up to a third of the screen), clear of
-- every box by the rules' own 6 px and 8 px from the edges. (TreadmillBonusRules itself is frozen: its preferred rect is asked of it, with nothing in the way.)
function B.ButtonSpot(rules,m,w,h,boxes,extra,dock)
 local e=B.Reserved(w,h,m,dock)
 m=Hud.Real(m) -- (R158: the button works in screen px; a scaled computer layout becomes one in real px - a phone's is returned as it is)
 local more={e}
 for _,b in ipairs(extra or{})do more[#more+1]=b end
 local detail=m.HotbarDetails~=false and 44 or 0
 local rise=math.max(0,h-m.HotbarBottom-m.SlotSize-detail-(e.Y+3)) -- (the button's bottom edge ends up 7 px above the box: its own 10 px gap less 3; R157: the box includes the name rows)
 local lifted=setmetatable({HotbarBottom=m.HotbarBottom+rise},{__index=m})
 local r=rules.Place(lifted,w,h,boxes,more)
 local want=rules.Place(lifted,w,h,{},{})
 if r.X==want.X and r.Y==want.Y and r.W==want.W then return r end
 local function clear(x)
  if x<8 or want.Y<8 or x+want.W>w-8 or want.Y+want.H>h-8 then return false end
  local test={X=x,Y=want.Y,W=want.W,H=want.H}
  for _,list in ipairs({boxes,more})do for _,b in ipairs(list)do if overlaps(test,b,6)then return false end end end
  return true
 end
 for dx=8,math.floor(w/3),8 do
  for _,x in ipairs({want.X+dx,want.X-dx})do if clear(x)then return {X=x,Y=want.Y,W=want.W,H=want.H}end end
 end
 return r
end
-- The label's size for a text in a bar (FredokaOne is about .52 em a letter): as big as the bar allows, at least 8.
function B.TextSize(text,barW,barH)
 local byHeight=math.floor(barH*.66)
 local byWidth=math.floor((barW-math.floor(barH*1.3))/math.max(1,utf8.len(text)or#text)/.52)
 return math.max(8,math.min(byHeight,byWidth))
end
-- The words a bar shows: the full ones ("9/10 next one's lucky!", "LUCKY PACK! x1.5 luck") or, on a bar too small for them, the short ones.
function B.Words(group,count,barW,barH,pop)
 local long=pop and Pity.PopText or Pity.Text(group,count)
 if B.TextSize(long,barW,barH)>=10 then return long end
 local short=pop and Pity.PopShort or Pity.ShortText(group,count)
 if B.TextSize(short,barW,barH)>B.TextSize(long,barW,barH)then return short end
 return long
end
-- The lucky TAG on the opener's reveal card (kind = the RarePullCinematic attribute): {Y = its centre in screen px, H = its height}. R157: the card is fitted to the
-- screen now (RarePullRules.FitLayout), so it publishes where its rows are (RarePullCard.Rows: the seed at rest, "1 in N", the name and the collect hint under it, px
-- of the full screen) and the tag follows them: rows = that table (nil: the card's unfitted layout, RarePullRules.Layout). The full card ('Ladder') has it in the gap
-- between the seed and its "1 in N" line; where the fit left that gap too small for a readable tag (a small phone) it sits on the lower edge of the seed's square, never
-- over "1 in N". The compact card ('InPlace' / 'Result', the upper part of the screen) gets it just under its collect hint, which is under the name.
B.TagMin=14
function B.TagPlace(kind,phone,w,h,rows)
 local th=phone and 22 or math.clamp(math.floor(h*.034),26,40)
 if not rows then
  local ok,Rules=pcall(require,script.Parent.RarePullRules)
  local L=ok and Rules.Layout(phone,kind~='Ladder',5)or{Seed={Y=.5,H=.38},Odds={Y=.775,H=.08},Hint={Y=.4325,H=.03}}
  local seedH=kind=='Ladder'and(ok and Rules.Tier(5).SeedSize or .38)or L.Seed.H
  rows={SeedTop=(L.Seed.Y-seedH/2)*h,SeedBottom=(L.Seed.Y+seedH/2)*h,OddsTop=(L.Odds.Y-L.Odds.H/2)*h,HintBottom=(L.Hint.Y+L.Hint.H/2)*h}
 end
 if kind=='Ladder'then
  local gap=rows.OddsTop-rows.SeedBottom
  if gap>=B.TagMin then
   local size=math.max(B.TagMin,math.min(th,math.floor(gap*.9)))
   return {Y=(rows.SeedBottom+rows.OddsTop)/2,H=size}
  end
  local size=math.max(B.TagMin,math.min(th,math.floor((rows.SeedBottom-rows.SeedTop)*.24)))
  return {Y=rows.SeedBottom-size/2-1,H=size}
 end
 return {Y=rows.HintBottom+th/2+6,H=th}
end
-- Building ---------------------------------------------------------------------------------------------------------------------------------------------
-- R157: the lucky pop's shine sweep and flash in the group's own colours (c: PackPity155.Colors[group]): a near-white tint of its Light / Glow, not plain white.
function B.ShineColor(c)return c.Light:Lerp(WHITE,.6)end
function B.FlashColor(c)return c.Glow:Lerp(WHITE,.35)end
local function new(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props)do o[k]=v end
 if o:IsA('GuiObject')then o.BorderSizePixel=0;o.Active=false end
 o.Parent=parent;return o
end
local function round(o)new('UICorner',{CornerRadius=UDim.new(.5,0)},o)end
local function buildBar(root,group)
 local c=Pity.Colors[group]
 local bar=new('Frame',{Name=group..'Pity',AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,ZIndex=1},root)
 local scale=new('UIScale',{Name='Scale',Scale=1},bar)
 local glow=new('Frame',{Name='Glow',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,10,1,10),BackgroundColor3=c.Glow,BackgroundTransparency=1,ZIndex=1},bar);round(glow)
 local ring=new('Frame',{Name='Ring',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,ZIndex=1},bar);round(ring)
 local ringStroke=new('UIStroke',{Name='Line',Color=c.Light,Thickness=3,Transparency=1},ring)
 local track=new('Frame',{Name='Track',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundColor3=c.Track or TRACK,BackgroundTransparency=.22,ZIndex=2},bar);round(track)
 local edge=new('UIStroke',{Name='Edge',Color=c.Rim or c.Deep,Thickness=1.5,Transparency=.1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},track)
 local fill=new('Frame',{Name='Fill',BackgroundColor3=WHITE,BackgroundTransparency=0,ZIndex=3},track);round(fill)
 local fillGradient=new('UIGradient',{Name='Shade',Rotation=90,Color=ColorSequence.new(c.Light,c.Deep)},fill)
 -- (R157: the lucky pop's shine and flash are light tints of the bar's own colours, B.ShineColor / B.FlashColor, so they follow the clover-green / gold palette)
 local shine=new('Frame',{Name='Shine',Size=UDim2.fromScale(1,1),BackgroundColor3=B.ShineColor(c),BackgroundTransparency=.15,Visible=false,ZIndex=4},fill);round(shine)
 local band=new('UIGradient',{Name='Band',Rotation=20,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.42,1),NumberSequenceKeypoint.new(.5,.05),NumberSequenceKeypoint.new(.58,1),NumberSequenceKeypoint.new(1,1)}),Offset=Vector2.new(-1,0)},shine)
 local flash=new('Frame',{Name='Flash',Size=UDim2.fromScale(1,1),BackgroundColor3=B.FlashColor(c),BackgroundTransparency=1,ZIndex=5},track);round(flash)
 local ticks={}
 for i=1,Pity.Every-1 do ticks[i]=new('Frame',{Name='Tick'..i,AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=WHITE,BackgroundTransparency=.72,ZIndex=4},track)end
 -- R157: the clover (CloverIcon153: the uploaded picture, the drawn copy, or the plain shapes) on a dark disc in the group's rim colour; the disc keeps it readable over the fill. The
 -- icon sits in a CanvasGroup so the HUD's dim / the other bar's dimming (GroupTransparency) reaches the picture too.
 local badge=new('Frame',{Name='Badge',AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=c.Badge or c.Ink,ZIndex=6},bar);round(badge)
 local badgeRim=new('UIStroke',{Name='Rim',Color=c.Rim or c.Deep,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},badge)
 local icon=new('CanvasGroup',{Name='Clover',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.86,.86),BackgroundTransparency=1,ZIndex=2},badge)
 pcall(function()require(script.Parent.CloverIcon153).Attach(icon)end)
 local label=new('TextLabel',{Name='Label',AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Font=B.Font,Text='',TextColor3=WHITE,TextScaled=false,TextWrapped=false,ZIndex=7},bar)
 local stroke=new('UIStroke',{Name='Outline',Color=c.Ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual},label)
 return {Group=group,Colors=c,Root=bar,Scale=scale,Glow=glow,Ring=ring,RingStroke=ringStroke,Track=track,Edge=edge,Fill=fill,FillGradient=fillGradient,Shine=shine,Band=band,
  Flash=flash,Ticks=ticks,Badge=badge,BadgeRim=badgeRim,Icon=icon,Label=label,Outline=stroke,
  Count=0,Shown=0,Held=false,Pending=0,PopAt=nil,Lucky=nil,HeldScale=1,PopScale=1}
end
local function buildTag(gui)
 local tag=new('Frame',{Name='LuckyTag',AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=WHITE,Visible=false,ZIndex=2},gui);round(tag)
 local scale=new('UIScale',{Name='Scale',Scale=1},tag)
 local shade=new('UIGradient',{Name='Shade',Rotation=90},tag)
 local edge=new('UIStroke',{Name='Edge',Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},tag)
 local shine=new('Frame',{Name='Shine',Size=UDim2.fromScale(1,1),BackgroundColor3=WHITE,BackgroundTransparency=.1,Visible=false,ZIndex=3},tag);round(shine)
 local band=new('UIGradient',{Name='Band',Rotation=20,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.42,1),NumberSequenceKeypoint.new(.5,.1),NumberSequenceKeypoint.new(.58,1),NumberSequenceKeypoint.new(1,1)}),Offset=Vector2.new(-1,0)},shine)
 local label=new('TextLabel',{Name='Label',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Font=B.Font,Text='',TextColor3=WHITE,ZIndex=4},tag)
 local outline=new('UIStroke',{Name='Outline',Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual},label)
 return {Root=tag,Scale=scale,Shade=shade,Edge=edge,Shine=shine,Band=band,Label=label,Outline=outline}
end
-- (R152's PropCache152: a property is written only when its value changes, so a bar at rest, or one only pulsing at 9/10, costs a few writes a frame)
local function setter()
 local ok,Cache=pcall(require,script.Parent.PropCache152)
 if ok and Cache then return Cache.new().Set end
 return function(o,k,v)if o[k]~=v then o[k]=v end end
end
-- R157: where the opener's reveal card has its rows right now (RarePullCard publishes them as shares of the screen's height: the attributes Card.RowKeys of the Folder
-- 'FitRows' under its root frame), in px of a
-- screen h tall; nil when no card is up or it published nothing (B.TagPlace then uses the unfitted layout).
B.CardRowKeys={SeedTop='FitSeedTop',SeedBottom='FitSeedBottom',OddsTop='FitOddsTop',NameBottom='FitNameBottom',HintTop='FitHintTop',HintBottom='FitHintBottom'}
function B.CardRows(pg,h)
 local reveal=pg and pg:FindFirstChild('RarePullReveal');local root=reveal and reveal:FindFirstChild('RarePull');root=root and root:FindFirstChild('FitRows')
 if not root then return nil end
 local rows={}
 for key,attr in pairs(B.CardRowKeys)do local v=root:GetAttribute(attr);if type(v)~='number'then return nil end;rows[key]=v*h end
 return rows
end
-- The tag at this moment: pops in (x0.6 -> x1.1 -> x1), one shine across, fades out when the card goes (Reduced Motion: no pop, no shine). Returns true while it moves.
local function paintTag(s,now)
 local t,st,S=s.Tag,s.TagState,s.Set
 if not t then return false end
 if not st then if t.Root.Visible then S(t.Root,'Visible',false)end;return false end -- (no tag up: nothing to do, not even a write)
 local hide=st.HideAt and now-st.HideAt or nil
 if hide and hide>=.25 then s.TagState=nil;S(t.Root,'Visible',false);return false end
 local age=now-st.At;local view=Hud.Viewport(s.TagGui);local phone=s.Metrics and s.Metrics.Phone==true
 local place=B.TagPlace(st.Kind,phone,view.X,view.Y,B.CardRows(s.TagGui.Parent,view.Y));local c=Pity.Colors[st.Group]
 local text=Pity.TagText(st.Group);local size=math.max(9,math.floor(place.H*.6))
 S(t.Root,'Visible',true);S(t.Root,'Position',UDim2.fromOffset(math.floor(view.X/2+.5),math.floor(place.Y+.5)))
 S(t.Root,'Size',UDim2.fromOffset(math.min(math.floor(view.X*.9),math.floor((utf8.len(text)or#text)*size*.56+place.H*1.4)),place.H))
 S(t.Label,'Text',text);S(t.Label,'TextSize',size);S(t.Outline,'Color',c.Ink);S(t.Edge,'Color',c.Light:Lerp(WHITE,.4))
 if t.Group~=st.Group then t.Group=st.Group;t.Shade.Color=ColorSequence.new(c.Light,c.Deep);t.Shine.BackgroundColor3=B.ShineColor(c)end
 local a=hide and math.clamp(hide/.25,0,1)or 0
 S(t.Root,'BackgroundTransparency',a);S(t.Label,'TextTransparency',a);S(t.Outline,'Transparency',a);S(t.Edge,'Transparency',a)
 local pop=1
 if not s.Reduced then
  if age<.18 then pop=.6+.5*(age/.18)elseif age<.36 then pop=1.1-.1*((age-.18)/.18)end
 end
 S(t.Scale,'Scale',pop)
 local sweep=not s.Reduced and not hide and age>=.3 and age<=1
 S(t.Shine,'Visible',sweep);if sweep then t.Band.Offset=Vector2.new(-1+2*(age-.3)/.7,0)end
 return age<1.05 or hide~=nil
end
-- A value's transparency once the HUD's dim and the other bar's dimming are applied: k = (1-dim)*(1-base) (one function for all, no closure per frame).
local function fade(t,k)return 1-(1-t)*k end
-- One bar's look at this moment (no state change): the fill from bar.Shown, the rest from the bar's and the HUD's state. Everything that is not time
-- (the geometry, the words, the fill's size) is worked out again only when its inputs change: a bar sitting at 9/10 costs the glow alone (Pulse).
local function paint(s,bar,now)
 local placement=s.Placement;if not placement then return end -- (not placed yet: a layout comes first and paints it)
 placement=placement.Hud or placement -- (R158: the bars are drawn in HUD px inside their scaled root; at scale 1 the answer is its own)
 local reduced,S=s.Reduced,s.Set
 local w,h=placement.Bar.W,placement.Bar.H
 local dim=s.Dim
 local popAge=bar.PopAt and now-bar.PopAt or nil
 local popping=popAge~=nil and popAge<B.PopSeconds
 if popping then dim=0 end
 local held=s.Held==bar.Group
 local other=s.Held~=nil and not held
 local k=(1-dim)*(other and .85 or 1);bar.K=k -- (R157: the other bar dims less, .85 not .75: a dimmed gold fill over grass turns olive and stops reading as gold)
 -- size and place (written again only when the layout changes)
 local center=placement.Centers[bar.Group]
 local cx,cy=math.floor(center.X+.5),math.floor(center.Y+.5)
 if bar.GeoW~=w or bar.GeoH~=h or bar.GeoX~=cx or bar.GeoY~=cy then
  bar.GeoW,bar.GeoH,bar.GeoX,bar.GeoY=w,h,cx,cy
  bar.Root.Position=UDim2.fromOffset(cx,cy);bar.Root.Size=UDim2.fromOffset(w,h)
  local lead=B.Lead(h) -- (R157: the clover's disc is the bar's left end; the fill and its ten steps run from there to the right end; 6 px of the fill's start hide under the disc)
  bar.Fill.Position=UDim2.fromOffset(lead-6,2)
  for i,t in ipairs(bar.Ticks)do t.Position=UDim2.fromOffset(math.floor(lead+(w-2-lead)*i/Pity.Every+.5),math.floor(h/2));t.Size=UDim2.fromOffset(1,math.max(2,h-10))end
  bar.Badge.Size=UDim2.fromOffset(h,h);bar.Badge.Position=UDim2.fromOffset(math.floor(h/2),math.floor(h/2))
  local room=w-lead-2-math.floor(h*.35)
  bar.Label.Position=UDim2.fromOffset(lead+2+math.floor(room/2),math.floor(h/2));bar.Label.Size=UDim2.fromOffset(room,h)
 end
 local fillW=0
 if bar.Shown>.004 then fillW=6+math.floor((w-2-B.Lead(h))*math.clamp(bar.Shown,0,1)+.5)end
 if bar.FillW~=fillW or bar.FillH~=h then bar.FillW,bar.FillH=fillW,h;S(bar.Fill,'Size',UDim2.fromOffset(fillW,h-4))end
 S(bar.Fill,'Visible',fillW>=2)
 local tickA=fade(.72,k);for _,t in ipairs(bar.Ticks)do S(t,'BackgroundTransparency',tickA)end
 -- words (cached by group, count, size and whether the pop's words show)
 local pop=bar.Pending>0 or(popping and popAge<B.DrainAt+.35)
 if bar.WordCount~=bar.Count or bar.WordPop~=pop or bar.WordW~=w or bar.WordH~=h then
  bar.WordCount,bar.WordPop,bar.WordW,bar.WordH=bar.Count,pop,w,h
  local text=B.Words(bar.Group,bar.Count,w,h,pop);bar.Words=text;bar.WordSize=B.TextSize(text,w,h)
 end
 S(bar.Label,'Text',bar.Words);S(bar.Label,'TextSize',bar.WordSize)
 -- glow: 9/10 (a pulse; steady with Reduced Motion), a lucky pack waiting, the pop
 local glow=1
 if bar.Pending>0 then glow=.45
 elseif popping then glow=reduced and .45 or .25+.6*math.clamp(popAge/B.PopSeconds,0,1)
 elseif Pity.IsLucky(bar.Count)then glow=reduced and .55 or .58+.17*math.sin(now*4.2)end
 S(bar.Glow,'BackgroundTransparency',fade(glow,k))
 -- the bar itself: brighter when its group is in your hand or it is about to be lucky
 local hot=held or Pity.IsLucky(bar.Count)or bar.Pending>0 or popping
 S(bar.Track,'BackgroundTransparency',fade(held and .05 or .12,k)) -- (R157: the track keeps its tint over any backdrop: .12, not .22)
 local rim=hot and(bar.Colors.RimHot or bar.Colors.Light)or(bar.Colors.Rim or bar.Colors.Deep)
 S(bar.Edge,'Color',rim);S(bar.Edge,'Thickness',held and 2.2 or 1.5);S(bar.Edge,'Transparency',fade(held and 0 or .1,k))
 S(bar.BadgeRim,'Color',rim);S(bar.BadgeRim,'Thickness',held and 2 or 1.5);S(bar.BadgeRim,'Transparency',fade(0,k))
 S(bar.Fill,'BackgroundTransparency',fade(0,k))
 if bar.GradHeld~=held then
  bar.GradHeld=held
  bar.FillGradient.Color=ColorSequence.new(held and bar.Colors.Light:Lerp(WHITE,.25)or bar.Colors.Light,held and bar.Colors.Deep:Lerp(bar.Colors.Light,.2)or bar.Colors.Deep)
 end
 S(bar.Badge,'BackgroundTransparency',fade(0,k));S(bar.Icon,'GroupTransparency',fade(0,k))
 S(bar.Label,'TextTransparency',fade(0,k));S(bar.Outline,'Transparency',fade(0,k))
 -- the pop: flash, shine sweep, ring, scale (the last three never with Reduced Motion)
 local flash=1
 if popping then flash=popAge<.5 and(reduced and .7 or .2+.8*math.clamp(popAge/.5,0,1))or 1 end
 S(bar.Flash,'BackgroundTransparency',flash)
 local sweep=popping and not reduced and popAge>=.08 and popAge<=.78
 S(bar.Shine,'Visible',sweep)
 if sweep then bar.Band.Offset=Vector2.new(-1+2*(popAge-.08)/.7,0)end
 local ring=popping and not reduced and popAge<.7
 S(bar.Ring,'Visible',ring)
 if ring then local r=popAge/.7;bar.Ring.Size=UDim2.new(1,math.floor(28*r),1,math.floor(22*r));bar.RingStroke.Transparency=.15+.85*r end
 local scale=1
 if popping and not reduced then
  if popAge<.12 then scale=1+.2*(popAge/.12)
  elseif popAge<.5 then local r=(popAge-.12)/.38;scale=1+.2*(1-r)^2*math.cos(r*math.pi*1.5)
  end
 end
 S(bar.Scale,'Scale',(reduced and 1 or bar.HeldScale)*scale)
end
-- A bar at rest on 9/10 (nothing else changes): the glow's pulse is the only thing that moves, and it is the only thing written (paint's own glow, same value).
local function pulse(s,bar,now)
 s.Set(bar.Glow,'BackgroundTransparency',fade(.58+.17*math.sin(now*4.2),bar.K))
end
-- the state: a display step (eases the fill and the highlight); returns true while something still moves. A frame where nothing changed since the last paint
-- (s.Rev: bumped by every wake) paints nothing, or only the 9/10 glow; a hidden HUD (a menu over it) draws nothing: the next wake paints it.
local function step(s,dt,now)
 local moving=false
 if s.Placement and s.Root.Visible then
  local dimmed=s.Dim>=1
  for _,bar in pairs(s.Bars)do
   local popAge=bar.PopAt and now-bar.PopAt or nil
   local changed=bar.Rev~=s.Rev
   local target=bar.Count/Pity.Every
   if bar.Pending>0 or(popAge and popAge<B.DrainAt)then target=1 end
   if popAge and popAge>=B.PopSeconds then bar.PopAt=nil;popAge=nil;changed=true;if bar.Read then bar.Count=bar.Read()end end
   local shown=bar.Shown
   if s.Reduced then bar.Shown=target
   else
    local d=target-shown
    if math.abs(d)<.002 then bar.Shown=target else bar.Shown+=d*(1-math.exp(-dt*(d<0 and 7 or 11)));moving=true end
   end
   local heldScale=s.Held==bar.Group and B.HeldScale or 1
   local scaled=bar.HeldScale
   if s.Reduced then bar.HeldScale=heldScale
   else
    local d=heldScale-scaled
    if math.abs(d)<.002 then bar.HeldScale=heldScale else bar.HeldScale+=d*(1-math.exp(-dt*14));moving=true end
   end
   if popAge then moving=true;changed=true end
   if bar.Shown~=shown or bar.HeldScale~=scaled then changed=true end
   -- (a bar nobody can see - the whole HUD dimmed out under a reveal card - does not pulse)
   local pulsing=Pity.IsLucky(bar.Count)and not s.Reduced and not dimmed and bar.Pending==0 and not popAge
   if changed then paint(s,bar,now);bar.Rev=s.Rev
   elseif pulsing then pulse(s,bar,now)end
   if pulsing then moving=true end
  end
 end
 if paintTag(s,now)then moving=true end
 return moving
end
B.Step=step
-- Starting it on the client ----------------------------------------------------------------------------------------------------------------------------
-- opts (tests / the preview): Clock = function()->seconds, Notice = function(text, color) (default: the top notices, NoticeFeed83).
function B.Start(player,opts)
 opts=opts or{}
 local pg=player:WaitForChild('PlayerGui')
 for _,name in ipairs({B.Name,B.TagName})do local old=pg:FindFirstChild(name);if old then old:Destroy()end end
 local gui=Instance.new('ScreenGui');gui.Name=B.Name;gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=B.DisplayOrder
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
 local root=new('Frame',{Name='PityBars',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=1},gui)
 local clock=opts.Clock or os.clock
 local s={Gui=gui,Root=root,Player=player,Bars={},Held=nil,Dim=0,Reduced=GuiService.ReducedMotionEnabled==true,Connections={},Dead=false,Set=setter(),Rev=0}
 for _,group in ipairs(Pity.Groups)do s.Bars[group]=buildBar(root,group)end
 pcall(function()require(script.Parent.CloverIcon153).Ensure()end) -- (R157: the clover picture the bars show; the HUD luck row and the shop share it)
 -- the lucky tag's own layer, just above the reveal card (RarePullReveal, 96) and under the notices (100); full screen like the card
 local tagGui=Instance.new('ScreenGui');tagGui.Name=B.TagName;tagGui.ResetOnSpawn=false;tagGui.IgnoreGuiInset=true;tagGui.DisplayOrder=B.TagOrder
 tagGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;pcall(function()tagGui.ScreenInsets=Enum.ScreenInsets.None end);tagGui.Parent=pg
 s.TagGui=tagGui;s.Tag=buildTag(tagGui)
 local stepConn
 local function con(signal,fn)local c=signal:Connect(fn);s.Connections[#s.Connections+1]=c;return c end
 local function frame(dt)
  if s.Dead then return end
  local moving=s.Placement~=nil and step(s,dt or 1/60,clock()) -- (before its first layout there is nothing to draw: the layout wakes it)
  if not moving and stepConn then stepConn:Disconnect();stepConn=nil end
 end
 local function wake()
  if s.Dead then return end
  s.Rev+=1 -- (something changed: every bar is painted afresh on this frame)
  frame(0)
  if not stepConn then stepConn=Run.RenderStepped:Connect(frame)end
 end
 s.Wake=wake
 -- layout: the hotbar's dock (by name, each time), else the HudLayout default
 local dockConns={}
 local function dockRect(view,m)
  local hot=pg:FindFirstChild('ChestToolHotbar');local dock=hot and hot:FindFirstChild('Dock')
  if dock and dock:IsA('GuiObject')then
   local size,pos=dock.AbsoluteSize,dock.AbsolutePosition;local origin=gui.AbsolutePosition
   local r={X=pos.X-origin.X,Y=pos.Y-origin.Y,W=size.X,H=size.Y}
   local want=B.DefaultDock(m,view.X,view.Y)
   -- trust it when it is the hotbar's shape (a frame between layouts, or a mock, can report anything else)
   if r.W>=40 and r.H>=20 and r.X>=-2 and r.Y>=0 and r.X+r.W<=view.X+2 and r.Y+r.H<=view.Y+2 and math.abs(r.H-want.H)<=4 and math.abs(r.W-want.W)<=8 then return r,dock end
   return want,dock
  end
  return B.DefaultDock(m,view.X,view.Y),nil
 end
 local function visible()
  local hot=pg:FindFirstChild('ChestToolHotbar');local dock=hot and hot:FindFirstChild('Dock')
  return pg:GetAttribute('SeedMenu')==nil and(dock==nil or dock.Visible)
 end
 local watchedDock
 local function layout(m)
  if s.Dead then return end
  local view=Hud.Viewport(gui)
  m=m or Hud.Read(view,game:GetService('UserInputService').TouchEnabled,Hud.Controls(gui))
  local r,dock=dockRect(view,m)
  s.Metrics=m;s.View=view;s.Dock=r
  s.Placement=B.Place(view.X,view.Y,m,r)
  -- R158: a computer's HUD is drawn at m.Scale (HudLayout): the bars' root is a frame of the laid-out window's size (m.VW x m.VH) with a UIScale of it, so the bars, their words, the
  -- glow and the clover are placed in HUD px and shrink with the hotbar; at scale 1 it is the whole screen, as before
  local hudScale=m.Scale or 1
  root.Size=hudScale==1 and UDim2.fromScale(1,1)or UDim2.fromOffset(m.VW,m.VH);Hud.ApplyScale(root,hudScale)
  -- R157: the held item's name / traits rows (Hotbar.client) sit above the bars: it reads how far up from this attribute (B.NameRow) and lays them out again when it changes
  local row=B.NameRow(view.X,view.Y,m,r,s.Placement)
  if pg:GetAttribute('PityBarsRow')~=row then pg:SetAttribute('PityBarsRow',row)end
  if dock~=watchedDock then
   for _,c in ipairs(dockConns)do c:Disconnect()end;table.clear(dockConns);watchedDock=dock
   if dock then for _,p in ipairs({'AbsolutePosition','AbsoluteSize','Visible'})do dockConns[#dockConns+1]=dock:GetPropertyChangedSignal(p):Connect(function()task.defer(function()if s.Relayout then s.Relayout()end end)end)end end
  end
  root.Visible=visible()
  wake()
 end
 s.Relayout=function()layout(nil)end
 -- counts, lucky packs, the held pack
 local function readCount(group)return Pity.Count(player:GetAttribute(Pity.Attribute[group]))end
 local function accessible()
  root:SetAttribute('AccessibleLabel',Pity.Text('Normal',s.Bars.Normal.Count)..', '..Pity.Text('Event',s.Bars.Event.Count))
 end
 local function blocked(kinds)
  local kind=player:GetAttribute('RarePullCinematic')
  return kind~=nil and kinds[kind]==true
 end
 local BAR_WAIT={Ladder=true,Scene=true} -- (the reveal card and the story scene cover the bars; the compact card sits in the upper third)
 local CARD={Ladder=true,InPlace=true,Result=true}
 local function notice(group)
  local text=Pity.NoticeText(group)
  if opts.Notice then opts.Notice(text,Pity.Colors[group].Glow)return end
  pcall(function()
   local RS=game:GetService('ReplicatedStorage')
   require(RS.NoticeFeed83).Push(require(RS.NoticeCopy83).Color(text,Pity.Colors[group].Light),3.5,nil,true)
  end)
 end
 local function pop(bar,group)
  if bar.Pending<=0 then return end
  bar.Pending=math.max(0,bar.Pending-1);bar.PopAt=clock();bar.Count=readCount(group);accessible();wake()
 end
 -- a lucky pack of this group (a short settle first: the reveal starts on the same server frame). With a reveal card: the tag on it (until it goes), the bar
 -- pops when it goes (the compact card: at once). A story scene: the notice and the pop when it ends. No reveal: the notice and the pop now.
 local function lucky(group)
  local bar=s.Bars[group];bar.Pending+=1;s.LuckyCount=(s.LuckyCount or 0)+1;wake()
  local started=clock();local cardKind=nil
  local function poll()
   if s.Dead then return end
   local kind=player:GetAttribute('RarePullCinematic');local late=clock()-started>=B.MaxWait
   if cardKind then
    if kind==cardKind and not late then task.delay(.1,poll);return end
    if s.TagState and s.TagState.Group==group and not s.TagState.HideAt then s.TagState.HideAt=clock()end
    pop(bar,group);return
   end
   if CARD[kind]and not late then
    cardKind=kind;s.TagState={Group=group,Kind=kind,At=clock()};s.Tags=(s.Tags or 0)+1
    if kind~='Ladder'then pop(bar,group)end
    wake();task.delay(.1,poll);return
   end
   if kind=='Scene'and not late then task.delay(.1,poll);return end
   notice(group);pop(bar,group)
  end
  task.delay(B.Settle,poll)
 end
 local seen={}
 for _,group in ipairs(Pity.Groups)do
  local bar=s.Bars[group];bar.Read=function()return readCount(group)end;bar.Count=readCount(group);bar.Shown=bar.Count/Pity.Every
  seen[group]=tonumber(player:GetAttribute(Pity.LuckyAttribute[group]))or 0
  con(player:GetAttributeChangedSignal(Pity.Attribute[group]),function()
   local n=readCount(group)
   -- a count that went down waits a moment: the lucky pack's own signal may come right after it (then the bar shows the pop first)
   if n<bar.Count and bar.Pending==0 then task.delay(B.Settle*.5,function()if not s.Dead and bar.Pending==0 and not bar.PopAt then bar.Count=readCount(group);accessible();wake()end end);return end
   if bar.Pending==0 and not bar.PopAt then bar.Count=n end
   accessible();wake()
  end)
  con(player:GetAttributeChangedSignal(Pity.LuckyAttribute[group]),function()
   local n=tonumber(player:GetAttribute(Pity.LuckyAttribute[group]))or 0
   local more=n-seen[group];seen[group]=n
   if more>0 then lucky(group)end
  end)
 end
 accessible()
 -- placed first (Hud.Watch lays out at once): everything below that wakes the bars - the hand, the tutorial card - finds a placement to draw in (joining mid-tutorial or
 -- with a pack in hand used to paint before the first layout: "attempt to index nil with 'Bar'")
 local stopLayout=Hud.Watch(gui,layout)
 local charConns={}
 local function heldGroup()
  local c=player.Character;if not c then return nil end
  for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')and t:GetAttribute('SeedPackTool')then return Pity.Group(t:GetAttribute('BagVariant'))end end
  return nil
 end
 local function held()local g=heldGroup();if g~=s.Held then s.Held=g;wake()end end
 local function character(c)
  for _,x in ipairs(charConns)do x:Disconnect()end;table.clear(charConns)
  if c then charConns[1]=c.ChildAdded:Connect(held);charConns[2]=c.ChildRemoved:Connect(held)end
  held()
 end
 con(player.CharacterAdded,character);character(player.Character)
 -- out of the way under the opener's reveal card (its seed name and "1 in N" sit right where the bars are) and its story scene (the HUD is hidden then);
 -- dimmed while the tutorial card is up (the tutorial draws over them)
 local function dim()
  local d=blocked(BAR_WAIT)and 1 or pg:GetAttribute('TutorialCardBottom')~=nil and .35 or 0
  if d~=s.Dim then s.Dim=d;wake()end
 end
 con(player:GetAttributeChangedSignal('RarePullCinematic'),dim);con(pg:GetAttributeChangedSignal('TutorialCardBottom'),dim);dim()
 con(pg:GetAttributeChangedSignal('SeedMenu'),function()root.Visible=visible();wake()end)
 con(GuiService:GetPropertyChangedSignal('ReducedMotionEnabled'),function()s.Reduced=GuiService.ReducedMotionEnabled==true;wake()end)
 con(pg.ChildAdded,function(c)if c.Name=='ChestToolHotbar'then task.defer(function()if s.Relayout then s.Relayout()end end)end end)
 function s:Destroy()
  if s.Dead then return end;s.Dead=true
  if stepConn then stepConn:Disconnect();stepConn=nil end
  pcall(stopLayout)
  for _,c in ipairs(s.Connections)do c:Disconnect()end
  for _,c in ipairs(charConns)do c:Disconnect()end
  for _,c in ipairs(dockConns)do c:Disconnect()end
  pg:SetAttribute('PityBarsRow',nil)
  if gui.Parent then gui:Destroy()end
  if tagGui.Parent then tagGui:Destroy()end
 end
 con(gui.Destroying,function()s:Destroy()end)
 return s
end
return B
