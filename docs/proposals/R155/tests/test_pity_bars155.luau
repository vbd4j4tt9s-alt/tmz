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
--  7. layout         - 36 screens (PC, landscape / portrait phones, tablets): inside the screen, above the hotbar and its item name, clear of every HUD box (menu,
--                      balances, status, jump / thumb zones, owner tools, BASE / TRACK) and of the SKIP corner, text fits; the real gui matches; it follows the hotbar's
--                      frame found by name (and its moves), with HudLayout's default without it
--  8. SKIP button    - R155 review: the SKIP pill of an opening (RarePullCard.SkipRect with the boxes the card gives it) never touches the bars on any of the screens, with and
--                      without the phone's thumb controls, and stays at the bottom right, inside the margins, clear of every HUD box
--  9. BONUS button   - R155 review: the treadmill BONUS ROLL button (PityBars155.ButtonSpot, what TreadmillBonusClient asks) sits above the bars, never over them, on the same
--                      screens; near the hotbar where there is room; the answer depends on the screen alone (nothing flickers when the button comes and goes)
-- 10. starting       - R155 review: the bars start with the tutorial card up, with a pack in hand, under a reveal card, hidden, with a story scene: no error, placed and drawn;
--                      a step before the first layout is harmless
-- 11. cost           - R155 review: a bar at 9/10 writes its glow and nothing else (no UDim2, no words); a bar nobody can see (dimmed out, hidden) costs nothing and the
--                      frame loop stops
-- R157 (the owner-approved R156 preview "pity bars v2": "closer to the hot bar like really close but with a small gap", the clover, NORMAL clover green, EVENT gold with a
-- clover-green rim, shade "Fresh"): every expectation above that named gold / purple, the diamond, "above the item name" or the 44 px rows now names the new look and place:
-- the green normal bar and the gold event bar, the clover disc at the left end (the fill starts after it, B.Lead), the bars B.Gap px over the slots (8 / 6 / 5) with the
-- held item's name rows ABOVE them (B.NameRows; part of B.Reserved), the SKIP pill 14 px in, the lucky tag following the fitted card's published rows.
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
-- (R157: the fill runs from under the clover's disc to the right end: 6 px under the disc + (W - 2 - B.Lead(H)) * share; empty = none)
local function hudOf(p)return p.Hud or p end -- (R158: what the bars are drawn from: HUD px; the same table at scale 1)
local function fillFor(k)if k<=.004 then return 0 end;local P=hudOf(s.Placement).Bar;return 6+math.floor((P.W-2-B.Lead(P.H))*k+.5)end
-- 1. always there -------------------------------------------------------------------------------------------------------------------------------
check(gui and gui:IsA('ScreenGui')and gui.DisplayOrder==23 and gui.ResetOnSpawn==false and gui.ScreenInsets==R.Enum.ScreenInsets.CoreUISafeInsets,'its own ScreenGui, DisplayOrder 23 (under the hotbar / Bag 25, the tutorial 25 / 26, BASE / TRACK and the plant indicators 24), the HUD\'s safe area, kept on respawn')
frames(2)
check(s.Root.Visible and bar('Normal').Root.Parent==s.Root and bar('Event').Root.Parent==s.Root,'both bars are on the HUD from the start, nothing in hand')
check(bar('Normal').Label.Text=='0/10 pity'and bar('Event').Label.Text=='0/10 event pity'and fillW('Normal')==0,'before any count arrives: "0/10 pity" and "0/10 event pity", empty')
check(bar('Normal').Root.Position.X.Offset<bar('Event').Root.Position.X.Offset and bar('Normal').Root.Position.Y.Offset==bar('Event').Root.Position.Y.Offset,'green (normal) on the left, gold (event) on the right, side by side')
local green,gold=Pity.Colors.Normal,Pity.Colors.Event
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function is(c,r,g,b)local x,y,z=rgb(c);return x==r and y==g and z==b end
check(bar('Normal').FillGradient.Color.A==green.Light and bar('Normal').FillGradient.Color.B==green.Deep and bar('Event').FillGradient.Color.A==gold.Light and bar('Event').FillGradient.Color.B==gold.Deep,'R157: the normal bar fills clover GREEN, the event bar GOLD')
check(is(green.Light,0x6E,0xD7,0x46)and is(green.Deep,0x0A,0x78,0x24)and is(green.Rim,0x60,0xCE,0x3C)and is(green.RimHot,0xD6,0xFF,0xA0)and is(green.Glow,0xAA,0xFF,0x6E)and is(green.Track,0x08,0x24,0x10)and is(green.Ink,0x06,0x34,0x12)
 and is(gold.Light,0xFF,0xF2,0x96)and is(gold.Deep,0xFF,0xC0,0x2C)and is(gold.Rim,0x46,0xC4,0x34)and is(gold.RimHot,0x96,0xF4,0x50)and is(gold.Track,0x28,0x1E,0x08)and is(gold.Glow,0xFF,0xD6,0x46)and is(gold.Ink,0x42,0x2A,0x02)
 and is(green.Badge,0x06,0x2E,0x12)and is(gold.Badge,0x06,0x2E,0x12)and Pity.Palettes==nil and Pity.Use==nil,'R157: shade 1 "Fresh" exactly (NORMAL #6ED746 -> #0A7824, rim #60CE3C; EVENT #FFF296 -> #FFC02C with the clover-green rim #46C434; clover disc #062E12); no second shade left')
check(bar('Normal').Edge.Color==green.Rim and bar('Event').Edge.Color==gold.Rim and bar('Event').Track.BackgroundColor3==gold.Track and bar('Normal').Track.BackgroundColor3==green.Track,'R157: the event bar\'s rim is clover green; each track is tinted (green-black / warm-black)')
do
 local b=bar('Normal');local icon=b.Badge and b.Badge:FindFirstChild('Clover')
 check(b.Root:FindFirstChild('Mark')==nil and b.Badge and icon and icon.ClassName=='CanvasGroup'and b.Badge.BackgroundColor3==green.Badge and b.BadgeRim.Color==green.Rim,'R157: the clover (CloverIcon153 in a CanvasGroup, on a dark disc with a rim in the bar\'s colour) replaces the diamond at the left end of each bar')
 check(b.Badge.Position.X.Offset==math.floor(hudOf(s.Placement).Bar.H/2)and b.Badge.Size.X.Offset==hudOf(s.Placement).Bar.H and b.Fill.Position.X.Offset==B.Lead(hudOf(s.Placement).Bar.H)-6,'R157: the disc is the bar\'s left end (H x H) and the fill starts under it (B.Lead - 6 px)')
end
check(#bar('Normal').Ticks==9 and #bar('Event').Ticks==9,'ten steps: nine ticks on each bar')
-- 2. values ------------------------------------------------------------------------------------------------------------------------------------
player:SetAttribute('PackPityNormal',3);player:SetAttribute('PackPityEvent',3)
frames(1)
local w1=fillW('Normal');local want=fillFor(.3)
check(bar('Normal').Label.Text=='3/10 pity'and bar('Event').Label.Text=='3/10 event pity','"3/10 pity" and "3/10 event pity"')
check(w1>0 and w1<want,'the fill eases to the new count (one frame in: '..w1..' of '..want..' px)')
frames(90)
check(fillW('Normal')==want and fillW('Event')==want,'... and lands on 3 of 10 steps ('..fillW('Normal')..' px)')
check(s.Root:GetAttribute('AccessibleLabel')=='3/10 pity, 3/10 event pity','the accessible label reads both')
player:SetAttribute('PackPityEvent',7);frames(90)
check(fillW('Event')==fillFor(.7)and fillW('Normal')==want,'each bar moves on its own (event 7/10, normal still 3/10)')
-- 3. 9/10 ---------------------------------------------------------------------------------------------------------------------------------------
player:SetAttribute('PackPityNormal',9);frames(60)
local g1=bar('Normal').Glow.BackgroundTransparency;frames(12);local g2=bar('Normal').Glow.BackgroundTransparency
check(bar('Normal').Label.Text=='9/10 next one\'s lucky!','9/10: "9/10 next one\'s lucky!"')
check(g1<.8 and g2<.8 and math.abs(g1-g2)>.01,'9/10: the bar glows, a soft pulse ('..string.format('%.2f -> %.2f',g1,g2)..')')
check(bar('Event').Glow.BackgroundTransparency>=.999,'... only the bar at 9/10 glows')
check(bar('Normal').Edge.Color==green.RimHot and bar('Normal').BadgeRim.Color==green.RimHot,'... its edge (and the clover disc\'s rim) lights up (R157: RimHot)')
-- 4. held pack ------------------------------------------------------------------------------------------------------------------------------------
local char=R.new('Model');char.Name='Ann';player.Character=char;player.CharacterAdded:Fire(char)
local function hold(variant)
 for _,t in ipairs(char:GetChildren())do t.Parent=nil end
 if variant then local t=R.new('Tool');t.Name='Pack';t:SetAttribute('SeedPackTool',true);t:SetAttribute('BagVariant',variant);t.Parent=char end
 frames(60)
end
player:SetAttribute('PackPityNormal',4);frames(60)
hold('Pack03')
check(s.Held=='Normal'and math.abs(bar('Normal').Scale.Scale-1.06)<.01 and bar('Event').Scale.Scale==1,'holding a world pack: the GREEN bar is slightly larger (x1.06)')
check(bar('Normal').Edge.Thickness>bar('Event').Edge.Thickness and bar('Normal').Track.BackgroundTransparency<bar('Event').Track.BackgroundTransparency,'... brighter (thicker edge, solid track); the gold event one stays, a little dimmer')
check(math.abs(bar('Event').K-.85)<1e-6,'R157: the bar not in hand dims to .85 (was .75: a dimmed gold over grass turned olive)')
check(bar('Event').Label.TextTransparency>0 and bar('Event').Label.TextTransparency<.5 and bar('Normal').Label.TextTransparency==0,'... the other bar is still readable (dimmed, not hidden)')
for _,v in ipairs({'MechLimited','EclipseReliquary','VerityReliquary'})do hold(v);check(s.Held=='Event'and math.abs(bar('Event').Scale.Scale-1.06)<.01 and math.abs(bar('Normal').Scale.Scale-1)<.01,'holding a '..v..' pack: the GOLD event bar is highlighted')end
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
 if b.PopAt and R.clock-b.PopAt<.9 and fillW('Normal')<fillFor(1)-2 then full=false end
end
check(#notices==before+1 and notices[#notices].Text==Pity.NoticeText('Normal')and notices[#notices].Text:find('LUCKY PACK! x1.5 luck',1,true),'the notice: "'..tostring(notices[#notices]and notices[#notices].Text)..'"')
check(popAt~=nil and bar('Normal').Pending==0,'the bar pops')
check(sawScale>1.15,'... a pop: it scales up (to x'..string.format('%.2f',sawScale)..') and settles back')
check(sawShine and sawRing and sawFlash,'... a flash, a ring and a shine sweeping across')
local function same(a,b)return math.abs(a.R-b.R)<1e-6 and math.abs(a.G-b.G)<1e-6 and math.abs(a.B-b.B)<1e-6 end
local white=R.Color3.new(1,1,1)
check(same(bar('Normal').Shine.BackgroundColor3,B.ShineColor(green))and same(bar('Normal').Flash.BackgroundColor3,B.FlashColor(green))and same(bar('Normal').RingStroke.Color,green.Light)
 and same(bar('Event').Shine.BackgroundColor3,B.ShineColor(gold))and same(bar('Event').Flash.BackgroundColor3,B.FlashColor(gold))and same(bar('Event').RingStroke.Color,gold.Light)and same(bar('Normal').Glow.BackgroundColor3,green.Glow)
 and not same(B.ShineColor(green),white)and not same(B.FlashColor(gold),white)and same(B.ShineColor(green),green.Light:Lerp(white,.6))and same(B.FlashColor(gold),gold.Glow:Lerp(white,.35)),
 'R157: the lucky pop\'s shine, flash, ring and glow are in the bar\'s own new colours (light green tints on the normal bar, light gold on the event bar), not plain white')
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
check(bar('Normal').Label.Text=='2/10 pity'and bar('Normal').PopAt==nil and fillW('Normal')==fillFor(.2),'a count set lower (/test pity set): the bar moves down, no pop')
-- the reveal card: its words sit where the bars are, so the bars step aside; a lucky pack gets a TAG on the card (between the seed and its "1 in N"), the bar pops
-- once the seed is collected; the compact card gets the tag under it and the bar pops at once; a story scene holds the notice and the pop; no reveal: the notice
local tagGui=pg:FindFirstChild(B.TagName)
check(tagGui and tagGui.DisplayOrder==97 and tagGui.IgnoreGuiInset==true,'the lucky tag has its own full-screen layer just above the reveal card (96) and under the notices (100)')
local function tag()return tagGui:FindFirstChild('LuckyTag')end
local function tagShown()local t=tag();return t and t.Visible and t.BackgroundTransparency<.5 end
-- (R157: a REAL reveal card, fitted to this 1280 x 720 screen, publishes where its rows are; the tag follows them)
tagGui.AbsoluteSize=V2(1280,720);W.workspace.CurrentCamera.ViewportSize=V2(1280,720)
local Card=W.module('RarePullCard')
local function realCard(kind,rank)
 local old=pg:FindFirstChild('RarePullReveal');if old then old:Destroy()end
 local cg=R.new('ScreenGui');cg.Name='RarePullReveal';cg.DisplayOrder=96;cg.IgnoreGuiInset=true;cg.AbsoluteSize=V2(1280,720);cg.Parent=pg
 return Card.Create(cg,kind,{Rank=rank,Phone=false,SeedName='Sand Fruit Seed',Odds=90})
end
local function rowsPx(c)local out={};for k,v in pairs(Card.Rows(c.Layout))do out[k]=v*720 end;return out end
player:SetAttribute('PackPityNormal',9);frames(30)
local ladder=realCard('Ladder',5)
player:SetAttribute('RarePullCinematic','Ladder');frames(5)
check(s.Dim==1 and bar('Normal').Track.BackgroundTransparency>=.999 and bar('Normal').Label.TextTransparency>=.999,'under the reveal card the bars step aside (its seed name and "1 in N" sit right there)')
local n0=#notices;luckyOpen('Normal',false);local sawTagPop=0
for _=1,40 do frames(1);local t=tag();if t and t.Visible then sawTagPop=math.max(sawTagPop,t:FindFirstChild('Scale').Scale)end end
check(tagShown()and tag().Label.Text==Pity.TagText('Normal')and #notices==n0,'a lucky pack with its reveal card up: the card gets the tag "'..Pity.TagText('Normal')..'" (no notice over the card\'s title)')
do
 -- R157: the card is fitted to the screen (RarePullRules.FitLayout); it publishes its rows and the tag sits in the gap between the seed and "1 in N" (or, where the fit left
 -- no readable gap, on the seed square's lower edge), never over "1 in N"
 local t=tag();local rows=rowsPx(ladder);local pub=B.CardRows(pg,720)
 local same=pub~=nil;if pub then for k,v in pairs(rows)do if math.abs(pub[k]-v)>.01 then same=false end end end
 check(ladder.Layout.Fit~=nil and same,'R157: the fitted card publishes its rows (a Folder under its root frame: B.CardRows reads the same seed / "1 in N" / name / hint rows as RarePullCard.Rows)')
 local top,bottom=rows.SeedBottom,rows.OddsTop
 local y=t.Position.Y.Offset;local th=t.Size.Y.Offset
 local inGap=bottom-top>=B.TagMin and y-th/2>=top-.5 and y+th/2<=bottom+.5
 local onEdge=bottom-top<B.TagMin and y+th/2<=top+.5 and y-th/2>=rows.SeedTop
 check((inGap or onEdge)and y+th/2<=bottom+.5 and math.abs(t.Position.X.Offset-tagGui.AbsoluteSize.X/2)<=1,('... in the free band of the fitted card: between the seed (to %.0f px) and the "1 in N" line (from %.0f px): %d..%d px, centred'):format(top,bottom,y-th/2,y+th/2))
end
check(sawTagPop>1.05 and tag():FindFirstChild('Scale').Scale==1,'... it pops in (to x'..string.format('%.2f',sawTagPop)..') and settles')
check(bar('Normal').Pending==1 and bar('Normal').PopAt==nil,'... the bar holds "'..Pity.PopText..'" (full, out of sight) and waits for the card')
frames(120);check(tagShown(),'... the tag stays while the result waits to be collected')
player:SetAttribute('RarePullCinematic',nil);frames(20)
check(bar('Normal').PopAt~=nil and s.Dim==0 and not tagShown(),'the seed is collected: the card and its tag go, the bars come back and the green one pops')
ladder:Destroy()
frames(150)
player:SetAttribute('PackPityEvent',9);frames(30)
local compact=realCard('InPlace',6)
player:SetAttribute('RarePullCinematic','InPlace');frames(5)
check(s.Dim==0,'the compact card (upper third, "skip pack animations"): the bars stay')
local n2=#notices;luckyOpen('Event',false);frames(40)
local crow=rowsPx(compact)
check(tagShown()and tag().Label.Text==Pity.TagText('Event')and bar('Event').PopAt~=nil and #notices==n2 and tag().Position.Y.Offset-tag().Size.Y.Offset/2>=crow.HintBottom-.5 and crow.HintTop>=crow.NameBottom-.5,
 'a lucky event pack with the compact card: "'..Pity.TagText('Event')..'" under the card (R157: under its collect hint, which is under the name), the gold event bar pops at once')
check(Pity.TagText('Event'):sub(1,3)=='⭐'and Pity.NoticeText('Event'):sub(1,3)=='⭐'and Pity.TagText('Normal'):sub(1,4)=='🍀','R157: the event tag and notice carry a gold star (the purple heart no longer matches); the normal ones keep the clover')
player:SetAttribute('RarePullCinematic',nil);frames(20);check(not tagShown(),'... the tag goes with the card')
compact:Destroy();pg.RarePullReveal:Destroy()
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
check(fillW('Event')==fillFor(.4),'Reduced Motion: a count change shows at once (no easing)')
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
 {1280,540,false,'short PC window'},{960,480,false,'narrow short window'},{700,400,false,'tiny landscape window'},{812,375,true,'iPhone X landscape'},{430,932,true,'iPhone Pro Max portrait'},{360,740,true,'Android portrait 740'},
}
local WORDS={{'Normal',0},{'Normal',9},{'Event',3},{'Event',9},{'Normal',0,true}}
local layoutFails=0
for _,sc in ipairs(SCREENS)do
 local w,h,touch,name=sc[1],sc[2],sc[3],sc[4]
 local m=Hud.Read(V2(w,h),touch,nil)
 local place=B.Place(w,h,m,nil)
 -- R158: a computer's HUD is drawn at m.Scale: Place's answer is in screen px (place.Hud has it in HUD px, the bars' own numbers: 24 px bars, 8 px gap, 5 px glow, 3 px name clearance ...),
 -- so each fixed number below is times k, and the words / sizes are the HUD px ones. k is 1 on a phone and on a window of 1920 x 720 or more: nothing changes there.
 local k=m.Scale or 1;local hudBar=(place.Hud or place).Bar
 local pair=place.Pair;local bad={}
 if not place.Clear then bad[#bad+1]='no clear spot'end
 if pair.X<0 or pair.Y<0 or pair.X+pair.W>w or pair.Y+pair.H>h then bad[#bad+1]='off screen'end
 local dock=B.DefaultDock(m,w,h)
 -- R157 (owner: "closer to the hot bar like really close but with a small gap"): exactly B.Gap px over the slots (8 on a computer, 6 on a phone, 5 under a thin phone bar),
 -- never on them; the held item's name rows ABOVE the bars, B.NameClear px over their top edge, where this screen shows them
 local gap=(dock.Y-(pair.Y+pair.H))/k;local want=B.Gap(m.Phone==true,hudBar.H)
 if math.abs(gap-want)>1e-6 then bad[#bad+1]=('not %d px over the slots (%d)'):format(want,gap)end
 if want~=(m.Phone and(hudBar.H<=16 and 5 or 6)or 8)then bad[#bad+1]='the gap is not 8 px on a computer / 6 on a phone'end
 if pair.X+pair.W<dock.X+8 or pair.X>dock.X+dock.W-8 then bad[#bad+1]='not over the hotbar'end
 if overlaps(pair,dock,0)then bad[#bad+1]='on the slots'end
 -- what the bars can cover: the bar, its glow (5 px) and the held bar's 1.06 scale
 local gx,gy=5*k+place.Bar.W*.03,5*k+place.Bar.H*.03;local ext={X=pair.X-gx,Y=pair.Y-gy,W=pair.W+gx*2,H=pair.H+gy*2}
 -- (HudLayout's Hotbar box is the slots and the 44 px over them: the bars' own place since R157, checked above against the slots themselves)
 for _,b in ipairs(Hud.HudBoxes(m,w,h,false))do if b.N~='Hotbar'and overlaps(ext,b,0)then bad[#bad+1]='covers '..tostring(b.N)end end
 if m.Travel~=nil then bad[#bad+1]='R113\'s BASE / TRACK spot (m.Travel) is back'end
 local zone=B.SkipZone(w/k,h/k);zone={X=zone.X*k,Y=zone.Y*k,W=zone.W*k,H=zone.H*k}
 if overlaps(ext,zone,0)then bad[#bad+1]='in the SKIP corner'end
 if m.HotbarDetails~=false then
  local rows=B.NameRows(w,h,m,dock,place)
  if rows.Y+rows.H>pair.Y-B.NameClear*k+.5 or rows.Y+rows.H<pair.Y-B.NameClear*k-.5 then bad[#bad+1]='the name rows are not right above the bars'end
  if rows.W>B.NameWidth*k+1e-6 or math.abs(rows.X+rows.W/2-(dock.X+dock.W/2))>.5 then bad[#bad+1]='the name rows are not centred on the hotbar'end
  for _,b in ipairs(Hud.HudBoxes(m,w,h,false))do if b.N~='Hotbar'and b.N~='Status'and overlaps(rows,b,0)then bad[#bad+1]='the name rows cover '..tostring(b.N)end end
 end
 local shown={}
 for _,wd in ipairs(WORDS)do
  local t=B.Words(wd[1],wd[2],hudBar.W,hudBar.H,wd[3]);shown[#shown+1]=t
  local size=B.TextSize(t,hudBar.W,hudBar.H);local width=utf8.len(t)*size*.52
  if size<B.MinText or width>hudBar.W-math.floor(hudBar.H*1.3)then bad[#bad+1]='"'..t..'" does not fit ('..size..' px)'end
 end
 if hudBar.H<(touch and 16 or 20) or hudBar.W<96 then bad[#bad+1]='bars too small'end
 if #bad>0 then layoutFails+=1;print(('FAIL: %s %dx%d%s: %s'):format(name,w,h,touch and' touch'or'',table.concat(bad,'; ')))end
 print(('LAYOUT %s %dx%d%s bars %dx%d%s at %d,%d (pair %dx%d, %+d px off centre) above the slots by %d px, name rows %s; text %d px "%s"'):format(name,w,h,touch and' touch'or'',place.Bar.W,place.Bar.H,place.Stacked and' stacked'or'',math.floor(pair.X),math.floor(pair.Y),math.floor(pair.W),pair.H,math.floor(pair.X+pair.W/2-(dock.X+dock.W/2)),gap,m.HotbarDetails~=false and'above them'or'hidden',B.TextSize(shown[2],place.Bar.W,place.Bar.H),shown[2]))
end
check(layoutFails==0,#SCREENS..' screens: inside the screen, R157: 8 px (computer) / 6 px (phone) over the slots (centred on them) with the item name rows above, clear of the menu, balances, status, jump / thumb zones, owner tools and the SKIP corner; every text fits ('..layoutFails..' failing)')
-- the real gui follows the screen
for _,sc in ipairs({{844,390,true},{390,844,true},{1920,1080,false}})do
 W.UIS.TouchEnabled=sc[3];gui.AbsoluteSize=V2(sc[1],sc[2]);frames(2)
 local m=Hud.Read(V2(sc[1],sc[2]),sc[3],nil);local place=B.Place(sc[1],sc[2],m,nil)
 local p=bar('Event').Root.Position;local z=bar('Event').Root.Size
 local hudPlace=place.Hud or place -- (R158: the bars are drawn in HUD px inside their scaled root)
 check(p.X.Offset==math.floor(hudPlace.Centers.Event.X+.5)and p.Y.Offset==math.floor(hudPlace.Centers.Event.Y+.5)and z.X.Offset==hudPlace.Bar.W and z.Y.Offset==hudPlace.Bar.H,('the real bars sit where the layout says on %dx%d'):format(sc[1],sc[2]))
end
W.UIS.TouchEnabled=false;gui.AbsoluteSize=V2(1280,720);frames(2)
-- the hotbar's frame, found by name: the bars centre on it and follow it
do
 local m=Hud.Read(V2(1280,720),false,nil);local d=B.DefaultDock(m,1280,720);local k=m.Scale or 1 -- (R158: the bars' root is drawn at k: their offsets are HUD px)
 local hot=R.new('ScreenGui');hot.Name='ChestToolHotbar';hot.AbsolutePosition=V2(0,0);hot.AbsoluteSize=V2(1280,720);hot.Parent=pg
 local dock=R.new('Frame');dock.Name='Dock';dock.AbsoluteSize=V2(d.W,d.H);dock.AbsolutePosition=V2(d.X-20,d.Y);dock.Parent=hot
 frames(2);s.Relayout();frames(2)
 local cx=(bar('Normal').Root.Position.X.Offset+bar('Event').Root.Position.X.Offset)/2
 check(math.abs(cx*k-(d.X-20+d.W/2))<=1,'the hotbar frame (ChestToolHotbar.Dock) is found by name: the bars centre on it ('..cx..')')
 dock.AbsolutePosition=V2(d.X-40,d.Y);frames(3)
 cx=(bar('Normal').Root.Position.X.Offset+bar('Event').Root.Position.X.Offset)/2
 check(math.abs(cx*k-(d.X-40+d.W/2))<=1,'... and follow it when it moves')
 dock.AbsoluteSize=V2(30,10);frames(3)
 cx=(bar('Normal').Root.Position.X.Offset+bar('Event').Root.Position.X.Offset)/2
 check(math.abs(cx*k-(d.X+d.W/2))<=1,'a frame that is not the hotbar\'s shape (mid-layout) is not trusted: HudLayout\'s default place')
 dock.Visible=false;frames(3);check(not s.Root.Visible,'the hotbar hidden: the bars hide with it')
 dock.Visible=true;frames(3);check(s.Root.Visible,'... and come back with it')
 hot:Destroy();s.Relayout();frames(2)
end
-- 8. the SKIP button of an opening (R155 review: on a phone it sat on the bars during the in-place and result cards) ---------------------------------------------------
local Card=W.module('RarePullCard');local TB=W.module('TreadmillBonusRules');local Notice=W.module('HudNoticeLayout')
local function controls(w,h) -- the phone's thumb controls the way Roblox puts them (the hud harness's)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local function noticeRows(w,h)
 local rows=Notice.Calculate(w,h,36,TB.NoticeFlags);local extra={}
 for name,row in pairs(rows)do if type(row)=='table'then extra[#extra+1]={N=name,X=row.X-row.Width/2,Y=row.Y,W=row.Width,H=row.Height}end end
 return extra
end
local skipFails,skipChecked=0,0
local bonusFails,bonusChecked,bonusFar,bonusWheel=0,0,{},{}
for _,sc in ipairs(SCREENS)do
 local w,h,touch,name=sc[1],sc[2],sc[3],sc[4]
 for _,ctl in ipairs(touch and{false,true}or{false})do
  local c=ctl and controls(w,h)or nil
  local m=Hud.Read(V2(w,h),touch,c)
  local tag=('%s %dx%d%s%s'):format(name,w,h,touch and' touch'or'',ctl and' with thumb controls'or'')
  local place=B.Place(w,h,m,nil);local ext=B.Reserved(w,h,m,nil)
  -- the boxes the card gives SkipRect: HudLayout's and the bars' extent
  local boxes=Card.SkipBoxes(w,h,touch,c)
  local hasBars=false;for _,b in ipairs(boxes)do if b.N=='PityBars'and b.X==ext.X and b.Y==ext.Y and b.W==ext.W and b.H==ext.H then hasBars=true end end
  local x,y,bw,bh=Card.SkipRect(w,h,touch,boxes);local skip={X=x,Y=y,W=bw,H=bh}
  local bad={}
  if not hasBars then bad[#bad+1]='the card does not give SkipRect the bars\' extent'end
  if overlaps(skip,ext,0)then bad[#bad+1]='the SKIP button covers the bars'end
  if not place.Clear then bad[#bad+1]='the bars have no clear spot'end
  if not(x>=14 and y>=14 and x+bw<=w-14 and y+bh<=h-14)then bad[#bad+1]='the SKIP button is not 14 px inside the screen (R157: was 12)'end
  if not(x+bw/2>=w*.5 and y>=h*.45)then bad[#bad+1]='the SKIP button is not at the bottom right'end
  for _,b in ipairs(Hud.HudBoxes(m,w,h,false))do if overlaps(skip,b,8)then bad[#bad+1]='the SKIP button is within 8 px of '..tostring(b.N)end end
  if m.Travel~=nil then bad[#bad+1]='R113\'s BASE / TRACK spot (m.Travel) is back'end
  skipChecked+=1
  if #bad>0 then skipFails+=1;print(('FAIL: SKIP %s: %s'):format(tag,table.concat(bad,'; ')))end
  -- 9. the BONUS ROLL button, with the notice rows the client gives Place as well
  local extra=noticeRows(w,h);local wheel=Hud.HudBoxes(m,w,h,true)
  local btn=B.ButtonSpot(TB,m,w,h,wheel,extra)
  local old=TB.Place(m,w,h,wheel,extra)
  local bb={}
  if overlaps(btn,ext,0)then bb[#bb+1]='the BONUS button covers the bars'end
  if overlaps(btn,ext,6)then bb[#bb+1]='... with less than the 6 px of air every other box gets'end
  if btn.X<8 or btn.Y<8 or btn.X+btn.W>w-8 or btn.Y+btn.H>h-8 then bb[#bb+1]='off the 8 px margin'end
  for _,b in ipairs(wheel)do if overlaps(btn,b,6)then bb[#bb+1]='covers '..tostring(b.N)end end
  for _,b in ipairs(extra)do if overlaps(btn,b,6)then bb[#bb+1]='covers the '..tostring(b.N)..' notice row'end end
  local detail=m.HotbarDetails~=false and 44 or 0;local top=h-m.HotbarBottom-m.SlotSize-detail
  -- (R157: the bars sit right over the slots and the item name rows above them: B.Reserved holds both, and the button sits above all of it)
  local up=ext.Y-(btn.Y+btn.H) -- how far above the bars and the item name rows the button ends
  if up<0 and btn.X<ext.X+ext.W and btn.X+btn.W>ext.X then bb[#bb+1]='the BONUS button is beside or under the bars / the item name rows'end
  -- where there was room (the old place was just above the hotbar) it stays near it: just above the bars and the rows, as it was above R155's stack
  local oldUp=top-(old.Y+old.H)
  if oldUp<=60 and up>oldUp+24 then
   -- (a portrait phone as narrow as 360 px has its menu wheel's third option right over that spot when the wheel is open: the button then takes the next clear place)
   if touch and w<380 then bonusWheel[#bonusWheel+1]=('%s (%d px up, was %d)'):format(tag,up,oldUp)
   else bonusFar[#bonusFar+1]=('%s (%d px up, was %d)'):format(tag,up,oldUp)end
  end
  -- the same rect every time: it depends on the screen alone, not on whether the button shows (nothing flickers when it comes and goes)
  local again=B.ButtonSpot(TB,m,w,h,wheel,extra)
  if again.X~=btn.X or again.Y~=btn.Y or again.W~=btn.W or again.H~=btn.H then bb[#bb+1]='not the same twice'end
  bonusChecked+=1
  if #bb>0 then bonusFails+=1;print(('FAIL: BONUS %s: %s'):format(tag,table.concat(bb,'; ')))end
  print(('SKIPBONUS %s skip %d,%d %dx%d bonus %d,%d %dx%d (%d px above the bars and the item name rows)'):format(tag,x,y,bw,bh,btn.X,btn.Y,btn.W,btn.H,up))
 end
end
check(skipFails==0,('the SKIP button of an opening never touches the bars (R157: nor the name rows above them): %d screens (with and without thumb controls), at the bottom right, 14 px inside the screen, 8 px clear of every HUD box (%d failing)'):format(skipChecked,skipFails))
check(bonusFails==0,('the BONUS ROLL button sits above the bars, never over them (6 px of air), clear of the wheel, the notice rows and the margins, on %d screens, always at the same place (%d failing)'):format(bonusChecked,bonusFails))
check(#bonusFar==0,'... and near the hotbar wherever it was before: '..(#bonusFar==0 and'all of them'or table.concat(bonusFar,'; ')))
if #bonusWheel>0 then print('(the menu wheel keeps the button further up on: '..table.concat(bonusWheel,'; ')..')')end
-- the client without the module keeps the place the rules give (TreadmillBonusClient's fallback is TreadmillBonusRules.Place itself)
do
 local m=Hud.Read(V2(1280,720),false,nil);local wheel=Hud.HudBoxes(m,1280,720,true)
 local want=TB.Place(Hud.Real(m),1280,720,wheel,{});local lifted=B.ButtonSpot(TB,m,1280,720,wheel,{}) -- (R158: the rules work in screen px: Hud.Real(m), as TreadmillBonusClient's fallback does)
 check(want.Y>lifted.Y and want.X==lifted.X and want.W==lifted.W,('1280x720: the rules alone put the button at y=%d; with the bars it sits at y=%d, same column and size'):format(want.Y,lifted.Y))
end

-- 10. starting in the middle of things (R155 review: "attempt to index nil with 'Bar'" killed the client script when the tutorial card was up or a pack was in hand) ----------
local function fresh(name,setup)
 local p=R.new('Player');p.Name=name;p.UserId=2;p.Parent=Players
 p.CharacterAdded=R.signal()
 local g=R.new('PlayerGui');g.Name='PlayerGui';g.Parent=p
 local state={Player=p,PG=g}
 if setup then setup(p,g)end
 local ok,res=pcall(B.Start,p,{Notice=function()end})
 state.OK,state.S=ok,ok and res or nil;state.Err=ok and nil or res
 return state
end
do
 local function packIn(p,variant)
  local char=R.new('Model');char.Name=p.Name;p.Character=char
  local t=R.new('Tool');t.Name='Pack';t:SetAttribute('SeedPackTool',true);t:SetAttribute('BagVariant',variant);t.Parent=char
 end
 local cases={
  {'the tutorial card up',function(p,g)g:SetAttribute('TutorialCardBottom',140)end,function(r)return r.S.Dim==.35 and r.S.Bars.Normal.Label.TextTransparency>0 and r.S.Bars.Normal.Label.TextTransparency<1 end},
  {'a Mech pack in hand',function(p)packIn(p,'MechLimited')end,function(r)return r.S.Held=='Event' and math.abs(r.S.Bars.Event.Scale.Scale-1.06)<.01 end},
  {'a world pack in hand',function(p)packIn(p,'Pack03')end,function(r)return r.S.Held=='Normal' and math.abs(r.S.Bars.Normal.Scale.Scale-1.06)<.01 end},
  {'the tutorial card up and a pack in hand',function(p,g)g:SetAttribute('TutorialCardBottom',140);packIn(p,'Pack01')end,function(r)return r.S.Dim==.35 and r.S.Held=='Normal' end},
  {'a reveal card up (the bars step aside)',function(p)p:SetAttribute('RarePullCinematic','Ladder')end,function(r)return r.S.Dim==1 and r.S.Bars.Normal.Track.BackgroundTransparency>=.999 end},
  {'a story scene running',function(p)p:SetAttribute('RarePullCinematic','Scene')end,function(r)return r.S.Dim==1 end},
  {'a menu open (SeedMenu)',function(p,g)g:SetAttribute('SeedMenu','Shop')end,function(r)return not r.S.Root.Visible end},
  {'counts of 9 and 4 saved on the player',function(p)p:SetAttribute('PackPityNormal',9);p:SetAttribute('PackPityEvent',4)end,function(r)return r.S.Bars.Normal.Label.Text=="9/10 next one's lucky!" and r.S.Bars.Event.Label.Text=='4/10 event pity' end},
  {'everything at once',function(p,g)g:SetAttribute('TutorialCardBottom',140);g:SetAttribute('SeedMenu','Inventory');packIn(p,'EclipseReliquary');p:SetAttribute('RarePullCinematic','InPlace');p:SetAttribute('PackPityNormal',9)end,function(r)return r.S.Held=='Event' end},
 }
 for _,case in ipairs(cases)do
  local r=fresh('Joiner',case[2])
  if check(r.OK,'starting with '..case[1]..': no error'..(r.OK and''or(' ('..tostring(r.Err)..')')))then
   frames(60)
   local s2=r.S
   check(s2.Placement~=nil and s2.Placement.Bar.W>0 and(not s2.Root.Visible or s2.Bars.Normal.Root.Size.X.Offset==hudOf(s2.Placement).Bar.W),'... ('..case[1]..') placed, and drawn unless a menu hides it (bars '..s2.Placement.Bar.W..'x'..s2.Placement.Bar.H..')')
   check(case[3](r),'... ('..case[1]..') and in the state that case needs')
   -- later changes reach the running script (the HUD wakes): a count arrives and is drawn
   r.Player:SetAttribute('PackPityNormal',3);r.PG:SetAttribute('SeedMenu',nil);r.Player:SetAttribute('RarePullCinematic',nil);frames(120)
   check(r.S.Bars.Normal.Label.Text=='3/10 pity'and r.S.Root.Visible,'... and it keeps running: a count of 3 arrives and is drawn once the cards and menus are gone')
   r.S:Destroy();r.Player:Destroy()
  end
 end
 -- a step before the first layout (nothing placed yet) draws nothing and does not fail; the layout that follows draws everything
 local r=fresh('Early',nil)
 local s2=r.S
 s2.Placement=nil
 local ok1=pcall(B.Step,s2,1/60,R.clock)
 local ok2=pcall(s2.Wake)
 r.Player:SetAttribute('PackPityNormal',5)
 local ok3=pcall(function()frames(3)end)
 check(ok1 and ok2 and ok3,'a step / a wake / the frames before the first layout (no placement): nothing to draw, no error')
 s2.Relayout();frames(3)
 check(s2.Placement~=nil and s2.Bars.Normal.Label.Text=='5/10 pity'and s2.Bars.Normal.Root.Size.X.Offset==hudOf(s2.Placement).Bar.W,'... and the layout that follows draws the bars with what changed meanwhile')
 s2:Destroy();r.Player:Destroy()
end

-- 11. cost (R155 review: a bar at 9/10 allocated a closure, a UDim2, its words and a geometry string every frame, even while hidden) ---------------------------------------
do
 local function measure(n)
  local c={writes=0,glow=0,other={},udim=0,words=0,text=0,seq=0,sets=0}
  local mt=R.instMeta;local orig=mt.__newindex
  mt.__newindex=function(o,k,v)
   c.writes+=1
   if k=='BackgroundTransparency'and(o==bar('Normal').Glow or o==bar('Event').Glow)then c.glow+=1 else c.other[#c.other+1]=tostring(o:GetFullName())..'.'..tostring(k)end
   return orig(o,k,v)
  end
  local saved={}
  for _,k in ipairs({'fromOffset','new','fromScale'})do local f=R.UDim2[k];saved[k]=f;R.UDim2[k]=function(...)c.udim+=1;return f(...)end end
  local seqNew=R.ColorSequence.new;R.ColorSequence.new=function(...)c.seq+=1;return seqNew(...)end
  local words,text=B.Words,Pity.Text
  B.Words=function(...)c.words+=1;return words(...)end
  Pity.Text=function(...)c.text+=1;return text(...)end
  local set=s.Set;s.Set=function(...)c.sets+=1;return set(...)end -- (every property a frame looks at goes through it)
  frames(n)
  s.Set=set;mt.__newindex=orig;for k,f in pairs(saved)do R.UDim2[k]=f end;R.ColorSequence.new=seqNew;B.Words=words;Pity.Text=text
  return c
 end
 local function steppers()local n=0;for _,c in ipairs(W.Run.RenderStepped._c)do if c.Connected then n+=1 end end;return n end
 -- Normal at 9/10, nothing in hand, nothing over the HUD; the event bar rests at 7/10
 hold(nil);player:SetAttribute('PackPityEvent',7);player:SetAttribute('PackPityNormal',9);frames(120)
 check(s.Held==nil and s.Dim==0 and s.Root.Visible and bar('Normal').Label.Text=="9/10 next one's lucky!",'(a bar at 9/10, nothing in hand, the HUD shown)')
 local c=measure(60)
 check(c.writes==60 and c.glow==60,('9/10 at rest: 60 frames write exactly the glow of the bar at 9/10 once each (%d writes, %d of them on a glow%s)'):format(c.writes,c.glow,#c.other>0 and'; also '..table.concat(c.other,', ',1,math.min(#c.other,4))or''))
 check(c.udim==0 and c.seq==0 and c.words==0 and c.text==0,('... no UDim2, no ColorSequence, no words made or formatted (%d / %d / %d / %d)'):format(c.udim,c.seq,c.words,c.text))
 check(c.sets==60,('... and it looks at nothing else: one property a frame (the glow), not the forty of a full paint (%d in 60 frames)'):format(c.sets))
 check(steppers()>=1,'... the frame loop runs (the glow pulses)')
 -- the pulse is the glow the full paint gives (a wake paints everything afresh; the frames after it only pulse)
 s.Wake();local full=bar('Normal').Glow.BackgroundTransparency
 check(math.abs(full-(1-(1-(.58+.17*math.sin(R.clock*4.2)))))<1e-9,('... and it is the very value the full paint writes (%.4f)'):format(full))
 -- the words are made when the count changes, not on the frames after
 do
  local words=B.Words;local n=0;B.Words=function(...)n+=1;return words(...)end
  player:SetAttribute('PackPityEvent',8);frames(30);local afterChange=n
  frames(60);B.Words=words
  check(afterChange>=1 and afterChange<=3 and n==afterChange,('the words are made when the count changes (%d times) and not on the 60 frames after (%d more)'):format(afterChange,n-afterChange))
 end
 -- a bar nobody can see costs nothing: the HUD dimmed out under a reveal card; hidden under a menu
 player:SetAttribute('RarePullCinematic','Ladder');frames(10)
 local d=measure(60)
 check(d.writes==0 and d.sets==0 and steppers()==0,('under a reveal card (dimmed out): 60 frames, %d writes, %d properties looked at, %d frame loops running'):format(d.writes,d.sets,steppers()))
 player:SetAttribute('RarePullCinematic',nil);frames(10)
 check(s.Dim==0 and steppers()>=1 and bar('Normal').Glow.BackgroundTransparency<.9,'... and it comes back, pulsing')
 pg:SetAttribute('SeedMenu','Shop');frames(10)
 local hd=measure(60)
 check(hd.writes==0 and hd.sets==0 and steppers()==0 and not s.Root.Visible,('hidden under a menu: 60 frames, %d writes, %d properties looked at, %d frame loops running'):format(hd.writes,hd.sets,steppers()))
 pg:SetAttribute('SeedMenu',nil);frames(10)
 check(s.Root.Visible and steppers()>=1 and bar('Normal').Glow.BackgroundTransparency<.9,'... and drawn again, pulsing, when the menu closes')
 -- a count that changes while the HUD is hidden shows right after it comes back
 pg:SetAttribute('SeedMenu','Shop');frames(5);player:SetAttribute('PackPityEvent',2);frames(30);pg:SetAttribute('SeedMenu',nil);frames(120)
 check(bar('Event').Label.Text=='2/10 event pity'and fillW('Event')==fillFor(.2),'a count that changed while a menu hid the bars is shown right after (2/10)')
 -- Reduced Motion: a steady glow, no loop at all once it is drawn
 W.Gui.ReducedMotionEnabled=true;frames(5);local rm=measure(30)
 check(rm.writes==0 and steppers()==0,('Reduced Motion at 9/10: the glow is steady, 30 frames, %d writes, %d frame loops'):format(rm.writes,steppers()))
 W.Gui.ReducedMotionEnabled=false;frames(10)
 player:SetAttribute('PackPityNormal',0);player:SetAttribute('PackPityEvent',0);frames(120)
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
