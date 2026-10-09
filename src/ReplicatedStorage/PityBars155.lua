-- R155 (owner): the pack pity's two bars, always on the HUD, slightly above the hotbar. Owner: "upon holding a pack a bar would show on the players screen
-- slightly above the hot bar 1/10 pity" -> "there can be 2 separate bars above the hot bar one coloured gold the other coloured purple" -> "make it so that
-- they are always visible and they are polished properly". The counts are the server's (PackPity155 attributes on the player); this only shows them.
--  * NORMAL pity in GOLD on the left ("3/10 pity"), EVENT pity (Void / Verity / Mech) in PURPLE on the right ("3/10 event pity"). The fill moves in ten
--    steps and eases to a new count; ten ticks mark the steps.
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
--    (ChestToolHotbar.Dock, found by name at every layout change; the same HudLayout metrics when it is not there), above the held item's name. It keeps
--    clear of every other HUD box (HudLayout.HudBoxes: menu, balances, status, thumb / jump zones, owner tools, BASE / TRACK) and of the SKIP button of an
--    opening (the bottom-right corner, SkipZone); the SKIP button in turn keeps clear of the bars' extent (B.Reserved, taken by RarePullCard.SkipRect as a box:
--    on a phone the thumb controls push the button left of the corner, up to where the bars are); hidden while a menu covers the HUD (SeedMenu), like the status HUD.
--  * The treadmill BONUS ROLL button also wants the place just above the hotbar: it takes the bars' extent as a box and sits above them (B.ButtonSpot, which
--    TreadmillBonusClient asks; TreadmillBonusRules itself is unchanged), so the bars never move when the button comes and goes.
--  * Cost: a bar at rest costs nothing; a bar at 9/10 only writes its glow's transparency each frame (the rest is painted when something changes); nothing
--    is drawn while the HUD is hidden.
local Run=game:GetService('RunService');local GuiService=game:GetService('GuiService')
local Pity=require(script.Parent.PackPity155)
local Hud=require(script.Parent.HudLayout)
local B={Name='PackPityBars155',TagName='PackPityLuckyTag155',TagOrder=97,DisplayOrder=23,Lift=6,Pad=2,Glow=5,HeldScale=1.06,MaxRise=60,PopSeconds=1.7,DrainAt=1.05,Settle=.3,MaxWait=180}
B.Font=Enum.Font.FredokaOne
local RGB=Color3.fromRGB
local WHITE=Color3.new(1,1,1)
local TRACK=RGB(18,14,30)
-- The bottom-right corner the R155 SKIP button uses while a pack opens (it sits there on every device): the bars never go there.
function B.SkipZone(w,h)
 local zh=math.max(80,math.floor(h*.16))
 return {N='Skip',X=math.floor(w*.75),Y=h-zh,W=w-math.floor(w*.75),H=zh}
end
-- The hotbar's rect as HudLayout gives it (the hotbar's own layout): {X, Y, W, H}.
function B.DefaultDock(m,w,h)
 local side=m.SlotSize;local width=(m.Slots+1)*side+m.Slots*6
 return {X=w/2+(m.HotbarShiftX or 0)-width/2,Y=h-m.HotbarBottom-side,W=width,H=side}
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
function B.Place(w,h,m,dock)
 dock=dock or B.DefaultDock(m,w,h)
 local phone=m.Phone==true
 local barH=phone and(h<380 and 18 or 20)or(h<560 and 20 or 24)
 local gap=phone and 8 or 12;local rowGap=4
 local detail=m.HotbarDetails~=false and 44 or 0
 local bottom=dock.Y-detail-B.Lift
 local boxes={}
 for _,b in ipairs(Hud.HudBoxes(m,w,h,false))do if b.N~='Hotbar'then boxes[#boxes+1]=b end end
 if m.Travel then boxes[#boxes+1]={N='Travel',X=m.Travel.X,Y=m.Travel.Y,W=m.Travel.W,H=m.Travel.H}end
 boxes[#boxes+1]=B.SkipZone(w,h)
 local below={N='Dock',X=dock.X,Y=dock.Y-detail,W=dock.W,H=dock.H+detail} -- the hotbar and its item name: the bars sit just above (their glow may reach its empty top)
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
      local pair={X=cx-r.W/2+dx,Y=bottom-r.H-rise,W=r.W,H=r.H}
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
 if not found then found={Pair={X=cx-wide-gap/2,Y=bottom-barH,W=wide*2+gap,H=barH},W=wide,H=barH,Stacked=false}end
 local pair,barW=found.Pair,found.W;barH=found.H
 local centers
 if found.Stacked then centers={Normal={X=pair.X+barW/2,Y=pair.Y+barH/2},Event={X=pair.X+barW/2,Y=pair.Y+barH+rowGap+barH/2}}
 else centers={Normal={X=pair.X+barW/2,Y=pair.Y+barH/2},Event={X=pair.X+barW+gap+barW/2,Y=pair.Y+barH/2}}end
 return {Bar={W=barW,H=barH},Gap=gap,Stacked=found.Stacked,Pair=pair,Clear=clear,Phone=phone,Centers=centers}
end
-- The room a pair {X, Y, W, H} of bars (each barW x barH) can cover: its glow (B.Glow px) and the held bar's scale.
function B.Extent(r,barW,barH)
 local gx=B.Glow+barW*(B.HeldScale-1)/2;local gy=B.Glow+barH*(B.HeldScale-1)/2
 return {X=r.X-gx,Y=r.Y-gy,W=r.W+gx*2,H=r.H+gy*2}
end
-- The room the bars take on a screen (their extent: the glow and the held bar's scale included) as a HUD box, from the same inputs they are placed with. The SKIP
-- button of an opening (RarePullCard.SkipRect) keeps clear of it; dock: the hotbar's rect (nil = HudLayout's default).
function B.Reserved(w,h,m,dock)
 local place=B.Place(w,h,m,dock)
 local e=B.Extent(place.Pair,place.Bar.W,place.Bar.H)
 return {N='PityBars',X=e.X,Y=e.Y,W=e.W,H=e.H}
end
-- The treadmill BONUS ROLL button (TreadmillBonusClient) wants the same place, just above the hotbar. It takes the bars' extent as one more box and lifts its
-- preferred spot above it: TreadmillBonusRules.Place measures that spot from m.HotbarBottom, so it gets a copy of m with the bars' height added to it; every
-- other spot Rules.Place tries is tested against the bars too. The answer is the same whether the button shows or not (the bars are always there), so nothing
-- flickers when it comes and goes. rules: TreadmillBonusRules; boxes, extra: what the client gives Rules.Place; returns its rect {X, Y, W, H}.
function B.ButtonSpot(rules,m,w,h,boxes,extra,dock)
 local e=B.Reserved(w,h,m,dock)
 local more={e}
 for _,b in ipairs(extra or{})do more[#more+1]=b end
 local detail=m.HotbarDetails~=false and 44 or 0
 local rise=math.max(0,h-m.HotbarBottom-m.SlotSize-detail-(e.Y+3)) -- (the button's bottom edge ends up 7 px above the bars' glow: its own 10 px gap less 3)
 return rules.Place(setmetatable({HotbarBottom=m.HotbarBottom+rise},{__index=m}),w,h,boxes,more)
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
-- The lucky TAG on the opener's reveal card (kind = the RarePullCinematic attribute): {Y = its centre in screen px, H = its height}. The full card ('Ladder')
-- has a free band between the seed (the biggest card seed: Mythic) and its "1 in N" line (RarePullRules.Layout); the compact card ('InPlace' / 'Result', the
-- upper third) gets it just under its name.
function B.TagPlace(kind,phone,w,h)
 local ok,Rules=pcall(require,script.Parent.RarePullRules)
 local th=phone and 22 or math.clamp(math.floor(h*.034),26,40)
 if kind=='Ladder'then
  local L=ok and Rules.Layout(phone,false,5)or{Odds={Y=.78,H=.08}}
  local seed=ok and Rules.Tier(5).SeedSize or .38
  local top,bottom=.5+seed/2,L.Odds.Y-L.Odds.H/2
  th=math.max(14,math.min(th,math.floor((bottom-top)*h*.9)))
  return {Y=(top+bottom)/2*h,H=th}
 end
 local L=ok and Rules.Layout(phone,true,5)or{Name={Y=.39,H=.035}}
 return {Y=(L.Name.Y+L.Name.H/2)*h+th/2+6,H=th}
end
-- Building ---------------------------------------------------------------------------------------------------------------------------------------------
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
 local track=new('Frame',{Name='Track',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundColor3=TRACK,BackgroundTransparency=.22,ZIndex=2},bar);round(track)
 local edge=new('UIStroke',{Name='Edge',Color=c.Deep,Thickness=1.5,Transparency=.1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},track)
 local fill=new('Frame',{Name='Fill',BackgroundColor3=WHITE,BackgroundTransparency=0,ZIndex=3},track);round(fill)
 local fillGradient=new('UIGradient',{Name='Shade',Rotation=90,Color=ColorSequence.new(c.Light,c.Deep)},fill)
 local shine=new('Frame',{Name='Shine',Size=UDim2.fromScale(1,1),BackgroundColor3=WHITE,BackgroundTransparency=.15,Visible=false,ZIndex=4},fill);round(shine)
 local band=new('UIGradient',{Name='Band',Rotation=20,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.42,1),NumberSequenceKeypoint.new(.5,.05),NumberSequenceKeypoint.new(.58,1),NumberSequenceKeypoint.new(1,1)}),Offset=Vector2.new(-1,0)},shine)
 local flash=new('Frame',{Name='Flash',Size=UDim2.fromScale(1,1),BackgroundColor3=WHITE,BackgroundTransparency=1,ZIndex=5},track);round(flash)
 local ticks={}
 for i=1,Pity.Every-1 do ticks[i]=new('Frame',{Name='Tick'..i,AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=WHITE,BackgroundTransparency=.72,ZIndex=4},track)end
 local mark=new('Frame',{Name='Mark',AnchorPoint=Vector2.new(.5,.5),Rotation=45,BackgroundColor3=WHITE,ZIndex=6},bar)
 new('UIGradient',{Rotation=-45,Color=ColorSequence.new(c.Light,c.Deep)},mark)
 local markEdge=new('UIStroke',{Name='Edge',Color=c.Ink,Thickness=1.5},mark)
 new('UICorner',{CornerRadius=UDim.new(0,3)},mark)
 local label=new('TextLabel',{Name='Label',AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Font=B.Font,Text='',TextColor3=WHITE,TextScaled=false,TextWrapped=false,ZIndex=7},bar)
 local stroke=new('UIStroke',{Name='Outline',Color=c.Ink,Thickness=1.6,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual},label)
 return {Group=group,Colors=c,Root=bar,Scale=scale,Glow=glow,Ring=ring,RingStroke=ringStroke,Track=track,Edge=edge,Fill=fill,FillGradient=fillGradient,Shine=shine,Band=band,
  Flash=flash,Ticks=ticks,Mark=mark,MarkEdge=markEdge,Label=label,Outline=stroke,
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
-- The tag at this moment: pops in (x0.6 -> x1.1 -> x1), one shine across, fades out when the card goes (Reduced Motion: no pop, no shine). Returns true while it moves.
local function paintTag(s,now)
 local t,st,S=s.Tag,s.TagState,s.Set
 if not t then return false end
 if not st then if t.Root.Visible then S(t.Root,'Visible',false)end;return false end -- (no tag up: nothing to do, not even a write)
 local hide=st.HideAt and now-st.HideAt or nil
 if hide and hide>=.25 then s.TagState=nil;S(t.Root,'Visible',false);return false end
 local age=now-st.At;local view=Hud.Viewport(s.TagGui);local phone=s.Metrics and s.Metrics.Phone==true
 local place=B.TagPlace(st.Kind,phone,view.X,view.Y);local c=Pity.Colors[st.Group]
 local text=Pity.TagText(st.Group);local size=math.max(9,math.floor(place.H*.6))
 S(t.Root,'Visible',true);S(t.Root,'Position',UDim2.fromOffset(math.floor(view.X/2+.5),math.floor(place.Y+.5)))
 S(t.Root,'Size',UDim2.fromOffset(math.min(math.floor(view.X*.9),math.floor((utf8.len(text)or#text)*size*.56+place.H*1.4)),place.H))
 S(t.Label,'Text',text);S(t.Label,'TextSize',size);S(t.Outline,'Color',c.Ink);S(t.Edge,'Color',c.Light:Lerp(WHITE,.4))
 if t.Group~=st.Group then t.Group=st.Group;t.Shade.Color=ColorSequence.new(c.Light,c.Deep)end
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
 local reduced,S=s.Reduced,s.Set
 local w,h=placement.Bar.W,placement.Bar.H
 local dim=s.Dim
 local popAge=bar.PopAt and now-bar.PopAt or nil
 local popping=popAge~=nil and popAge<B.PopSeconds
 if popping then dim=0 end
 local held=s.Held==bar.Group
 local other=s.Held~=nil and not held
 local k=(1-dim)*(other and .75 or 1);bar.K=k
 -- size and place (written again only when the layout changes)
 local center=placement.Centers[bar.Group]
 local cx,cy=math.floor(center.X+.5),math.floor(center.Y+.5)
 if bar.GeoW~=w or bar.GeoH~=h or bar.GeoX~=cx or bar.GeoY~=cy then
  bar.GeoW,bar.GeoH,bar.GeoX,bar.GeoY=w,h,cx,cy
  bar.Root.Position=UDim2.fromOffset(cx,cy);bar.Root.Size=UDim2.fromOffset(w,h)
  bar.Fill.Position=UDim2.fromOffset(2,2)
  for i,t in ipairs(bar.Ticks)do t.Position=UDim2.fromOffset(math.floor(2+(w-4)*i/Pity.Every+.5),math.floor(h/2));t.Size=UDim2.fromOffset(1,math.max(2,h-10))end
  local mark=math.floor(h*.78)
  bar.Mark.Size=UDim2.fromOffset(mark,mark);bar.Mark.Position=UDim2.fromOffset(math.floor(h*.62),math.floor(h/2))
  bar.Label.Position=UDim2.fromOffset(math.floor(w/2+h*.3),math.floor(h/2));bar.Label.Size=UDim2.fromOffset(w-math.floor(h*1.3),h)
 end
 local fillW=math.floor((w-4)*math.clamp(bar.Shown,0,1)+.5)
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
 S(bar.Track,'BackgroundTransparency',fade(held and .1 or .22,k))
 S(bar.Edge,'Color',hot and bar.Colors.Light or bar.Colors.Deep);S(bar.Edge,'Thickness',held and 2.2 or 1.5);S(bar.Edge,'Transparency',fade(held and 0 or .1,k))
 S(bar.Fill,'BackgroundTransparency',fade(0,k))
 if bar.GradHeld~=held then
  bar.GradHeld=held
  bar.FillGradient.Color=ColorSequence.new(held and bar.Colors.Light:Lerp(WHITE,.25)or bar.Colors.Light,held and bar.Colors.Deep:Lerp(bar.Colors.Light,.2)or bar.Colors.Deep)
 end
 S(bar.Mark,'BackgroundTransparency',fade(0,k));S(bar.MarkEdge,'Transparency',fade(0,k))
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
  if gui.Parent then gui:Destroy()end
  if tagGui.Parent then tagGui:Destroy()end
 end
 con(gui.Destroying,function()s:Destroy()end)
 return s
end
return B
