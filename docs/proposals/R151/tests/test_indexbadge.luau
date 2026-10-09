--!nocheck
-- R151 (owner: "the notification for the index, the red circle and the +, has to be polished as it looks really low quality and cut out wrongly"): the Index's red
-- notification badge on the Roblox mock, with the REAL ChestIndex, HudLayout, NotifyBadge151 and DailyRewardsClient of this checkout (MODE 'after') or the R150 ChestIndex +
-- HudLayout from git (MODE 'before': proves the root cause, the old badge IS cut by the wheel's CanvasGroup and by the tab row). run_badges.sh runs both.
--  1. the polished badge: a square holder (UIAspectRatioConstraint 1) with a PERFECT circle (UICorner 1,0) in a bright red gradient with a white ring that stays inside the holder,
--     a soft two-layer drop shadow behind it, and the count (FredokaOne, white, at an explicit size since R154, centred on the disc): "!", the count, "9+" past nine, nothing for a dot
--  2. NOT CLIPPED: on every screen from a 360 px phone to 1920x1080 the badge's outermost reach (ring, shadow, the pop's biggest size, the pulse's halo) stays inside every ancestor that
--     clips (the wheel's CanvasGroup, the tab row's ScrollingFrame, any ClipsDescendants frame); the tab dots sit inside their tab
--  3. the ROOT CAUSE, measured on the R150 code: the INDEX badge overhangs the button's corner by 8 px (ring included) and the CanvasGroup gave it 4 px; the tab dot hung out of the tab by 3 px
--     and the tab row clips at its top
--  4. one component: the INDEX count, the MENU "!", the tab dots and the DAILY badges are all NotifyBadge151; the old badge code is gone from both scripts
--  5. motion: a pop-in when it appears, a short pop when the count goes up, a gentle pulse while it shows; none of it with Reduced Motion (also when that is switched on mid-pulse)
local W=require('./world');local R=W.R
local L=require('./layout_badges')(R)
local after=MODE~='before'
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=5;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
function req.InvokeServer()return {Success=true,Message='Claimed!'}end
local Rules=W.module('SeedPackRules');local Badge=W.module('NotifyBadge151')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local index=0;local ids={}
for _,stage in ipairs({1,6,2,3,4,5,7})do
 local odds=Rules.SeedOdds(config,stage,'Pack01',1)
 for _,seed in ipairs(Rules.ObtainablePool(config,stage))do
  index+=1;local e=R.new('Folder');e.Name=seed.Id;ids[#ids+1]=seed.Id
  e:SetAttribute('SeedId',seed.Id);e:SetAttribute('DisplayName',seed.Name);e:SetAttribute('Rarity',(Rules.GetRarity(seed.Id)))
  e:SetAttribute('Stage',stage);e:SetAttribute('SeedIndex',index);e:SetAttribute('BaseChance',odds[seed.Id]);e.Parent=catalog
 end
end
local seeds=R.new('Folder');seeds.Name='DiscoveredSeeds';seeds.Parent=player
local plants=R.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player
local function found(folder,id,cash)local v=R.new('BoolValue');v.Name=id;v.Value=true;if cash then v:SetAttribute('RewardCash',cash)end;v.Parent=folder end
-- two rewards waiting: the Mooncap cash + Forest's half-way gems (as test_index_alerts does)
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed'})do found(seeds,id,id=='MooncapSeed'and 240000 or nil)end
for _,id in ipairs({'SunflowerSeed','BluebellSeed'})do found(plants,id)end
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end})
-- spy on TweenService:Create (the mock plays a tween at once; the spy keeps what each one was asked to do and the value it started from)
local tweens={}
do local TS=W.service('TweenService');local base=TS.Create
 TS.Create=function(self,obj,info,props)local rec={Obj=obj,Info=info,Props=props,From={}};for k in pairs(props)do rec.From[k]=obj[k]end;tweens[#tweens+1]=rec;return base(self,obj,info,props)end end
local s=R.new('LocalScript');s.Name='ChestIndex';W.load('ChestIndex',s)
W.frames(10)
local gui=pg:FindFirstChild('ChestIndexGui');local nav=pg:FindFirstChild('GardenNavigation')
local toggle=pg:FindFirstChild('IndexButton',true);local hub=nav and nav:FindFirstChild('MenuButton')
check(gui and nav and toggle and hub,'the Index, the INDEX button (in the wheel) and the MENU button are built')
local function relay(w,h)L.lay(nav,w,h);L.lay(gui,w,h);W.frames(2);L.lay(nav,w,h);L.lay(gui,w,h)end
local function indexBadge()return toggle:FindFirstChild('RewardBadge')end
local function alertBadge()return hub:FindFirstChild('IndexRewardAlert')end
local function dotOf(key)local t=gui:FindFirstChild('Biome'..key,true);return t and t:FindFirstChild('RewardDot'),t end
local function visibleText(b)return b and b.Visible and b.Count.Text or nil end
check(visibleText(indexBadge())=='2'and visibleText(alertBadge())=='!','the INDEX button counts 2 and the MENU button shows "!" ('..tostring(visibleText(indexBadge()))..' / '..tostring(visibleText(alertBadge()))..')')
-- Geometry of what a badge draws (layout_badges.luau: the holder, the soft shadow and the shadow at the pop's biggest scale, or at rest with the pulse's halo at its biggest; the R150
-- badge: its frame plus its UIStroke ring)
local function reach(b)return L.badgeReach(Badge,b)end
local overshoot=L.overshoot
-- The worst cut of a badge by what clips it, and which ancestor did it.
local function cut(b)
 local worst,who=0,nil;local a=reach(b)
 for _,c in ipairs(L.clippers(b))do local o=overshoot(a,L.rect(c));if o>worst then worst,who=o,c.Name end end
 return worst,who
end
local SIZES={{360,640},{390,844},{412,915},{640,360},{768,1024},{1024,768},{1280,720},{1920,1080}}
local function openWheel()if not nav:GetAttribute('Opened')then hub.Activated:Fire();nav:SetAttribute('Opened',true)end end
-- 1. the polished badge -------------------------------------------------------------------------------------------------------------------------------
if after then
 relay(390,844);openWheel();relay(390,844)
 local b=indexBadge()
 check(b and b._class=='Frame'and b:GetAttribute('NotifyBadge')==151,'the INDEX count is a NotifyBadge151 (revision attribute)')
 local ratio=b:FindFirstChildOfClass('UIAspectRatioConstraint')
 check(ratio and ratio.AspectRatio==1,'the holder has a UIAspectRatioConstraint of 1 (it stays square)')
 local r=L.rect(b);check(near(r.x1-r.x0,r.y1-r.y0)and near(r.x1-r.x0,Badge.Sizes.Count),'the holder is a '..Badge.Sizes.Count..' x '..Badge.Sizes.Count..' square (R153: 1.5x the R151 24 px) ('..(r.x1-r.x0)..' x '..(r.y1-r.y0)..')')
 check(b.ClipsDescendants==false or b.ClipsDescendants==nil,'the holder itself does not clip')
 local disc=b:FindFirstChild('Disc');local dr=disc and L.rect(disc)
 check(disc and near(dr.x1-dr.x0,dr.y1-dr.y0),'the disc is square')
 local corner=disc and disc:FindFirstChildOfClass('UICorner')
 check(corner and corner.CornerRadius.Scale==1 and corner.CornerRadius.Offset==0,'the disc is a perfect circle: UICorner CornerRadius (1, 0)')
 local ring=disc and disc:FindFirstChildOfClass('UIStroke')
 check(ring and ring.Color.R==1 and ring.Color.G==1 and ring.Color.B==1 and ring.Thickness>=1.5 and ring.Thickness<=3 and ring.ApplyStrokeMode.Name=='Border','a white UIStroke ring, 1.5 to 3 px, around the disc (Border mode)')
 check(dr.x0>=r.x0-1e-6 and dr.y0>=r.y0-1e-6 and dr.x1<=r.x1+1e-6 and dr.y1<=r.y1+1e-6 and near(dr.x0-r.x0,ring and ring.Thickness or 0),'the ring stays INSIDE the holder (the disc is inset by the ring: the holder is the outer diameter)')
 local grad=disc and disc:FindFirstChildOfClass('UIGradient')
 local top,bottom=grad and grad.Color.A,grad and grad.Color.B
 check(top and top.R>=.95 and top.G<=.5 and top.B<=.5 and bottom.R>=.75 and bottom.G<=.2 and bottom.B<=.3 and top.G>bottom.G and grad.Rotation==90,'a bright red gradient, lighter at the top (255,104,116 to 214,24,54)')
 local soft,tight=b:FindFirstChild('ShadowSoft'),b:FindFirstChild('Shadow')
 check(soft and tight and soft.BackgroundTransparency>=.5 and soft.BackgroundTransparency<=.95 and tight.BackgroundTransparency>=.4 and tight.BackgroundTransparency<=.9 and soft.BackgroundTransparency>tight.BackgroundTransparency,'a soft drop shadow: two dark circles, the wide one fainter')
 local sr,tr=L.rect(soft),L.rect(tight)
 check(sr.y1>r.y1 and tr.y1>r.y1 and sr.y1-r.y1<=5*Badge.Grow and(sr.x1-sr.x0)>(r.x1-r.x0)and(sr.y0+sr.y1)/2>(r.y0+r.y1)/2,'... dropped a little below the badge (the shadow is lower and a touch wider)')
 local label=b:FindFirstChild('Count');local lr=L.rect(label)
 check(label and label._class=='TextLabel'and label.Font.Name=='FredokaOne'and label.TextColor3.R==1 and label.TextColor3.G==1 and label.TextColor3.B==1,'the count is FredokaOne and white')
 -- R154: the size is explicit (the engine's TextScaled fit left the digits a third of the bubble): no TextScaled, no UITextSizeConstraint, the size is Badge.TextSize
 check(label.TextScaled==false and label:FindFirstChildOfClass('UITextSizeConstraint')==nil and label.TextSize==Badge.TextSize(Badge.Sizes.Count,label.Text),'R154: ... at an explicit TextSize ('..tostring(label.TextSize)..', TextScaled off, no size constraint to shrink it)')
 check(label.TextStrokeTransparency<=.5 and label.TextStrokeColor3.R<.6 and label.TextStrokeColor3.G<.2,'... with its dark red edge')
 check(label.TextXAlignment.Name=='Center'and label.TextYAlignment.Name=='Center','the text is centred both ways')
 local lcx,lcy,dcx,dcy=(lr.x0+lr.x1)/2,(lr.y0+lr.y1)/2,(dr.x0+dr.x1)/2,(dr.y0+dr.y1)/2
 check(near(lcx,dcx,.01)and near(lcy,dcy,.01),'the label is centred on the disc ('..string.format('%.2f,%.2f vs %.2f,%.2f',lcx,lcy,dcx,dcy)..')')
 check(lr.x0>=dr.x0-1e-6 and lr.x1<=dr.x1+1e-6 and lr.y0>=dr.y0-1e-6 and lr.y1<=dr.y1+1e-6,'the label box lies inside the disc')
 check(Badge.Text(0)==''and Badge.Text(1)=='1'and Badge.Text(9)=='9'and Badge.Text(10)=='9+'and Badge.Text(250)=='9+'and Badge.Text(-3)==''and Badge.Text(nil)==''and Badge.Text(0/0)=='','Badge.Text: "" for nothing, the count to 9, "9+" past nine')
 -- the overflow on the real button: eleven rewards waiting
 local fresh={};for _,id in ipairs(ids)do if not seeds:FindFirstChild(id)and #fresh<9 then fresh[#fresh+1]=id end end
 for _,id in ipairs(fresh)do found(seeds,id,1000)end
 W.frames(5)
 check(visibleText(indexBadge())=='9+','eleven rewards waiting: the INDEX badge reads "9+" ('..tostring(visibleText(indexBadge()))..')')
 local lr2=L.rect(indexBadge().Count)
 check(near((lr2.x0+lr2.x1)/2,dcx,.01)and lr2.x1<=dr.x1+1e-6,'... and "9+" stays centred and inside the disc')
 for _,id in ipairs(fresh)do seeds[id]:Destroy()end
 W.frames(5)
 check(visibleText(indexBadge())=='2','back to two: "2" ('..tostring(visibleText(indexBadge()))..')')
 local dot,tab=dotOf(1)
 check(dot and dot.Visible and dot.Count.Text==''and dot:GetAttribute('NotifyBadge')==151,'a tab dot is the same badge with no text')
 local dr1,tr1=L.rect(dot),L.rect(tab)
 check(dr1.x0>=tr1.x0-1e-6 and dr1.y0>=tr1.y0-1e-6 and dr1.x1<=tr1.x1+1e-6 and dr1.y1<=tr1.y1+1e-6,'the dot sits fully inside its tab (the tab row is a ScrollingFrame)')
 local al=alertBadge()
 check(al and al:GetAttribute('NotifyBadge')==151 and al.Count.Text=='!','the MENU button\'s alert is the same badge, with "!"')
end
-- 2 / 3. clipping on every screen ------------------------------------------------------------------------------------------------------------------------
print((after and'AFTER'or'BEFORE (R150 code)')..': worst cut of each badge by what clips it, px (INDEX count / Forest tab dot / MENU alert), the clipper:')
local anyCut={Index=0,Dot=0,Alert=0}
for _,sz in ipairs(SIZES)do
 relay(sz[1],sz[2]);openWheel();relay(sz[1],sz[2])
 local bi,wi=cut(indexBadge());local dot,tab=dotOf(1);local bd,wd=cut(dot);local ba,wa=cut(alertBadge())
 anyCut.Index=math.max(anyCut.Index,bi);anyCut.Dot=math.max(anyCut.Dot,bd);anyCut.Alert=math.max(anyCut.Alert,ba)
 print(string.format('   %4dx%-4d  INDEX %.1f (%s)   dot %.1f (%s)   alert %.1f (%s)',sz[1],sz[2],bi,tostring(wi),bd,tostring(wd),ba,tostring(wa)))
 if after then
  check(bi<=1e-6,sz[1]..'x'..sz[2]..': the INDEX badge is not clipped (cut '..bi..' px by '..tostring(wi)..')')
  check(bd<=1e-6,sz[1]..'x'..sz[2]..': the tab dot is not clipped (cut '..bd..' px by '..tostring(wd)..')')
  check(ba<=1e-6,sz[1]..'x'..sz[2]..': the MENU alert is not clipped (cut '..ba..' px by '..tostring(wa)..')')
  local sc=L.rect(gui);local a=reach(indexBadge());local screen={x0=0,y0=0,x1=sz[1],y1=sz[2]};check(overshoot(a,screen)==0,sz[1]..'x'..sz[2]..': the badge is on screen')
  -- R153 (the badges are 1.5x): every badge's whole reach (ring, shadow, pop, halo) is on screen too, the MENU alert on its button's corner and the tab dot in its tab
  local oa,od=overshoot(reach(alertBadge()),screen),overshoot(reach(dot),screen)
  check(oa==0,sz[1]..'x'..sz[2]..': the MENU alert is on screen (reach past the screen: '..oa..' px)')
  check(od==0,sz[1]..'x'..sz[2]..': the tab dot is on screen (reach past the screen: '..od..' px)')
  local grp=L.rect(toggle.Parent);check(toggle.Parent._class=='CanvasGroup'and near(grp.x1-grp.x0,toggle.AbsoluteSize.X+2*Badge.Margin)and near(grp.y1-grp.y0,toggle.AbsoluteSize.Y+2*Badge.Margin),sz[1]..'x'..sz[2]..': the wheel\'s CanvasGroup keeps '..Badge.Margin..' px around the button')
 end
end
if after then
 check(Badge.Extent(Badge.Sizes.Count,Badge.Overhang.Count)<=Badge.Margin and Badge.Extent(Badge.Sizes.Alert,Badge.Overhang.Alert)<=Badge.Margin and Badge.Extent(Badge.Sizes.Dot,Badge.Overhang.Dot)==0,'Badge.Extent: the INDEX count ('..Badge.Extent(Badge.Sizes.Count,Badge.Overhang.Count)..') and the MENU alert ('..Badge.Extent(Badge.Sizes.Alert,Badge.Overhang.Alert)..') fit the wheel\'s '..Badge.Margin..' px margin; a dot reaches nothing out of its tab')
else
 -- the ROOT CAUSE, measured: the old badge is cut by the wheel's CanvasGroup (and its dot by the tab row)
 check(anyCut.Index>=3.5,'ROOT CAUSE: the R150 INDEX badge overhangs its CanvasGroup by '..anyCut.Index..' px (the top and right of the circle are sliced off flat)')
 check(anyCut.Dot>=2.5,'ROOT CAUSE: the R150 tab dot overhangs the tab row\'s ScrollingFrame by '..anyCut.Dot..' px')
 check(anyCut.Alert==0,'(the MENU alert was never clipped: its button sits straight in a ScreenGui)')
 local group=toggle.Parent
 check(group and group._class=='CanvasGroup','the INDEX button is inside a CanvasGroup (HudLayout.Navigation), which clips its descendants')
end
-- R153: the badges are 1.5x --------------------------------------------------------------------------------------------------------------------------------
if after then
 relay(390,844);openWheel();relay(390,844)
 -- (the R151 sizes were 24 / 20 / 20 / 14 px: the owner asked for a bigger bubble, "about 1.5x")
 -- (R155, owner: "reposition these bubbles make them slightly smaller as they are obscuring the image": 30 / 26 / 24, out on the corner (DAILY out to the right only); the dots stay 21)
 -- (R157: DAILY is a menu wheel option: its badge is the INDEX count's, 30 px on the corner; R155's DAILY-only size and its top-edge rule are gone)
 check(Badge.Sizes.Count==30 and Badge.Sizes.Alert==26 and Badge.Sizes.Daily==nil and Badge.Overhang.Daily==nil and Badge.OverhangTop==nil and Badge.Sizes.Dot==21,'R155 / R157: the badges are INDEX (and DAILY) count 30, MENU alert 26, dots 21; no DAILY-only size or top overhang')
 for _,k in ipairs({'Count','Alert'})do
  local size,o=Badge.Sizes[k],Badge.Overhang[k]
  check(size/2-o+size/2<=20 and o>=size/2-6,'R155: the '..k..' badge sits out on the corner: it covers '..(size-o)..' px of the button (at most 20), centre '..(size/2-o)..' px in')
  check(Badge.Extent(size,o)<=Badge.Margin-1,'R155: ... and stays a px inside the '..Badge.Margin..' px margin (extent '..Badge.Extent(size,o)..')')
 end
 for _,pair in ipairs({{indexBadge(),Badge.Sizes.Count,'INDEX count'},{alertBadge(),Badge.Sizes.Alert,'MENU alert'},{(dotOf(1)),Badge.Sizes.Dot,'tab dot'}})do
  local b,size,name=pair[1],pair[2],pair[3];local r=L.rect(b)
  check(near(r.x1-r.x0,size)and near(r.y1-r.y0,size)and b:GetAttribute('BadgeSize')==size,'R153: the '..name..' is '..size..' px ('..(r.x1-r.x0)..')')
  local ring=b.Disc:FindFirstChildOfClass('UIStroke').Thickness
  check(ring>=size*.07 and ring<=size*.1,'R153: its white ring grows with it ('..ring..' px on '..size..')')
  check(b.Count.TextSize==Badge.TextSize(size,b.Count.Text)and b.Count.TextSize>=size*.6,'R153 / R154: its count grows with it (text size '..b.Count.TextSize..' on '..size..')')
 end
 check(Badge.Extent(Badge.Sizes.Count,Badge.Overhang.Count)==15 and Badge.Margin==16,'R153: the INDEX count reaches 15 px past its corner and the wheel keeps '..Badge.Margin..' px round a button')
end
-- R154 (owner, after R153: "the number and signs in the notification bubble is also too small"; the digits were about a third of the bubble) ---------------------------------------------------
-- The text FILLS the bubble: for every text a badge shows ("2", "9+", "!") on a computer and on phones, the text size is >= 60% of the badge, the digits are >= 55% of the red disc's height (one character:
-- 58% of the badge, "9+": 50%) and no more than 72% of it, the glyphs stay within the badge (not into the shadow, the ring only at the ink box's empty corners), the width stays between the ring's
-- inner edges, and the text is centred on the disc. Measured with FredokaOne's real advance widths and digit height (layout_badges.luau L.textFill).
if after then
 local function fillRow(tag,b)
  local f=L.textFill(b);local text=b.Count.Text
  check(f.FillEm>=.6 and f.FillEm<=.8,string.format('%s "%s": the text size is %.0f%% of the badge (%d px on %d; 60..80%%)',tag,text,f.FillEm*100,f.Em,f.Size))
  check(f.FillDisc>=.55 and f.FillDisc<=.72 and f.FillInk>=.45,string.format('%s "%s": the digits are %.0f%% of the red disc and %.0f%% of the badge tall (>= 55%% of the disc, <= 72%%, >= 45%% of the badge)',tag,text,f.FillDisc*100,f.FillInk*100))
  check(f.InkW<=f.Disc-2 and f.Corner<=f.Radius-1,string.format('%s "%s": the glyphs stay inside the badge (%.1f px wide in a %.0f px disc, corner %.1f of radius %.1f)',tag,text,f.InkW,f.Disc,f.Corner,f.Radius))
  check(f.Centred,tag..' "'..text..'": the text is centred on the disc')
  return f
 end
 local rows={}
 for _,sz in ipairs({{1920,1080},{1280,720},{390,844},{844,390},{360,640}})do
  relay(sz[1],sz[2]);openWheel();relay(sz[1],sz[2])
  local tag=sz[1]..'x'..sz[2]..(math.min(sz[1],sz[2])<=500 and' (phone)'or' (computer)')
  local one=fillRow(tag..' INDEX count',indexBadge());fillRow(tag..' MENU alert',alertBadge())
  check(indexBadge().Count.Text=='2'and alertBadge().Count.Text=='!','('..tag..': the badges read "2" and "!")')
  rows[#rows+1]=string.format('   %-20s "2" text %d px = %.0f%% of the badge, digits %.0f%% of the disc',tag,one.Em,one.FillEm*100,one.FillDisc*100)
  -- the longest text: "9+" (eleven rewards waiting), then back
  local fresh={};for _,id in ipairs(ids)do if not seeds:FindFirstChild(id)and #fresh<9 then fresh[#fresh+1]=id end end
  for _,id in ipairs(fresh)do found(seeds,id,1000)end
  W.frames(5);relay(sz[1],sz[2])
  local nine=fillRow(tag..' INDEX count',indexBadge())
  check(indexBadge().Count.Text=='9+'and nine.Chars==2,tag..': the longest text, "9+", was measured')
  check(nine.Em<one.Em and nine.Em>=Badge.Sizes.Count*.6,string.format('%s: "9+" is set smaller than one character (%d px < %d px) so it stays in the disc, still >= 60%% of the badge',tag,nine.Em,one.Em))
  for _,id in ipairs(fresh)do seeds[id]:Destroy()end
  W.frames(5);relay(sz[1],sz[2])
  check(indexBadge().Count.TextSize==one.Em,tag..': back to one character, back to its size')
  -- the text is never clipped: no ancestor that clips cuts the holder (the text is inside it), on this screen
  local worst=cut(indexBadge());check(worst<=1e-6,tag..': nothing clips the INDEX count and its text (cut '..worst..' px)')
 end
 print('R154 badge text (FredokaOne metrics):');for _,r in ipairs(rows)do print(r)end
 -- the sizes themselves: one character 78%, two 68% (R157: no DAILY-only size any more: DAILY is a Count badge)
 for _,k in ipairs({'Count','Alert'})do
  local d=Badge.Sizes[k]
  check(Badge.TextSize(d,'2')>=d*.75 and Badge.TextSize(d,'!')==Badge.TextSize(d,'2')and Badge.TextSize(d,'9+')>=d*.65 and Badge.TextSize(d,'9+')<Badge.TextSize(d,'2'),'Badge.TextSize for the '..k..' badge ('..d..' px): one character '..Badge.TextSize(d,'2')..', two '..Badge.TextSize(d,'9+'))
 end
end
-- 3b. R153 client bug review, finding 7: the 1.5x tab dot never covers the count --------------------------------------------------------------------------------
-- The dot (21 px) used to sit on the tab's top-right corner and covered the end of the count text ("18 / 40") on a PC tab (122 x 58) and on a phone's compact tab (106 x 40). It must clear the
-- count's label (whole box, so any count), the text itself (the mock's width rule: utf8.len * size * .52) and the LIMITED tab's note, on a PC and on phones, and stay 21 px inside its tab. The
-- INDEX count, the MENU alert and the DAILY badges are untouched (top-right, 1.5x).
if after then
 local function meets(a,b)return a.x0<b.x1-1e-6 and b.x0<a.x1-1e-6 and a.y0<b.y1-1e-6 and b.y0<a.y1-1e-6 end
 local checkedTabs,compactSeen,wideSeen=0,false,false
 for _,sz in ipairs({{667,375},{375,667},{390,844},{844,390},{360,640},{1280,720},{1920,1080}})do
  relay(sz[1],sz[2])
  local tag=sz[1]..'x'..sz[2]
  local overCount,overText,overNote,notLeft,wrongSize,outside,n,tabW=0,0,0,0,0,0,0,nil
  for _,t in ipairs(gui:GetDescendants())do
   local dot=t._class=='TextButton'and t.Name:sub(1,5)=='Biome'and t:FindFirstChild('RewardDot')
   if dot then
    n+=1;tabW=t.AbsoluteSize.X
    local dr,tr,label=L.rect(dot),L.rect(t),t:FindFirstChild('Count');local lr=L.rect(label)
    local width=math.max(utf8.len(label.Text),9)*label.TextSize*.52 -- (the text as it is, or a longer count: 9 characters)
    local cx,cy=(lr.x0+lr.x1)/2,(lr.y0+lr.y1)/2;local text={x0=cx-width/2,x1=cx+width/2,y0=cy-label.TextSize/2,y1=cy+label.TextSize/2}
    if meets(dr,lr)then overCount+=1 end
    if meets(dr,text)then overText+=1 end
    local note=t:FindFirstChild('TabNote');if note and note.Visible and meets(dr,L.rect(note))then overNote+=1 end
    if dot:GetAttribute('BadgeLeft')~=true or(dr.x0+dr.x1)/2>=(tr.x0+tr.x1)/2 then notLeft+=1 end
    if not near(dr.x1-dr.x0,Badge.Sizes.Dot)or Badge.Sizes.Dot~=21 then wrongSize+=1 end
    if not(dr.x0>=tr.x0-1e-6 and dr.y0>=tr.y0-1e-6 and dr.x1<=tr.x1+1e-6 and dr.y1<=tr.y1+1e-6)then outside+=1 end
   end
  end
  checkedTabs+=n;if tabW and tabW<110 then compactSeen=true else wideSeen=true end
  check(n>=8,tag..': the Index has its biome tabs ('..n..', tab '..tostring(tabW)..' px wide)')
  check(overCount==0,tag..': no tab dot touches its count label ('..overCount..' of '..n..' do)')
  check(overText==0,tag..': no tab dot covers its count text ('..overText..' of '..n..' do)')
  check(overNote==0,tag..': no tab dot covers the LIMITED tab\'s note')
  check(notLeft==0,tag..': the tab dots sit on the tabs\' top-left corner, clear of the count')
  check(wrongSize==0 and outside==0,tag..': ...still the 1.5x dot (21 px) and fully inside its tab')
  check(indexBadge():GetAttribute('BadgeLeft')==false and alertBadge():GetAttribute('BadgeLeft')==false and near(L.rect(indexBadge()).x1-L.rect(indexBadge()).x0,Badge.Sizes.Count)and near(L.rect(alertBadge()).x1-L.rect(alertBadge()).x0,Badge.Sizes.Alert),tag..': the INDEX count ('..Badge.Sizes.Count..' px) and the MENU alert ('..Badge.Sizes.Alert..' px, R155) stay on their buttons\' top-right corners')
 end
 check(compactSeen and wideSeen and checkedTabs>=56,'both tab sizes were measured: the phone\'s compact tab and the PC tab ('..checkedTabs..' tab dots in all)')
 relay(390,844)
end
-- 4. one component --------------------------------------------------------------------------------------------------------------------------------------
local function source(name)return require('./rs_bundle')[name]end
if after then
 local idx,daily=source('ChestIndex'),source('DailyRewardsClient')
 check(not idx:find('local function badge%('),'ChestIndex no longer builds its own badge')
 check(not daily:find('local function badge%('),'DailyRewardsClient no longer carries a copy of the badge')
 local _,nIndex=idx:gsub('Badge%.Make%(','');local _,nDaily=daily:gsub('Badge%.Make%(','')
 -- (R157: the MENU button's "!" is HudLayout's own now - it adds up the Index and DAILY rewards that ChestIndex / DailyRewardsClient publish - so ChestIndex makes two)
 local hud=source('HudLayout');local _,nHud=hud:gsub('NotifyBadge%.Make%(hub,\'IndexRewardAlert\'','')
 check(nIndex==2 and nDaily==3 and nHud==1 and idx:find("pg:SetAttribute('MenuAlertIndex',total)",1,true)~=nil,'every Index badge (count, tab dots: '..nIndex..'; the MENU alert: HudLayout '..nHud..') and every DAILY badge (button, two tabs: '..nDaily..') is made by NotifyBadge151.Make')
 local nb=source('NotifyBadge151')
 local _,uses=nb:gsub("UIStroke",'')
 check(not nb:find('TextStrokeTransparency=1'),'(no hidden text stroke switch)')
end
-- 5. motion -----------------------------------------------------------------------------------------------------------------------------------------------
if after then
 relay(390,844)
 -- a visible badge pulses, a hidden one does not
 check(Badge.Pulsing(indexBadge())and Badge.Pulsing(alertBadge())and Badge.Pulsing((dotOf(1))),'a visible badge pulses (the INDEX count, the MENU alert, the Forest dot)')
 local hidden=dotOf(6);check(hidden and not hidden.Visible and not Badge.Pulsing(hidden),'a hidden badge (the Jungle dot) does not')
 local pulsing=0;for _,o in ipairs(R.created)do if o._class=='Frame'and o:GetAttribute('NotifyBadge')and Badge.Pulsing(o)then pulsing+=1 end end
 local visible=0;for _,o in ipairs(R.created)do if o._class=='Frame'and o:GetAttribute('NotifyBadge')and o.Visible and o:IsDescendantOf(W.game)then visible+=1 end end
 check(pulsing==visible,'one pulse per VISIBLE badge ('..pulsing..' pulses, '..visible..' visible)')
 -- a new reward: the count goes up and the badge pops (scale PopScale -> 1), never bigger than the margin allows
 tweens={};found(seeds,'CactusSeed',5000);W.frames(5)
 local popped=false;for _,t in ipairs(tweens)do if t.Obj._class=='UIScale'and t.Props.Scale==1 and t.From.Scale==Badge.PopScale then popped=true end end
 check(popped and Badge.PopScale<=1.3,'a new reward pops the INDEX count (scale '..Badge.PopScale..' -> 1)')
 -- one that was hidden appears with a pop-in
 local gone=indexBadge();seeds.CactusSeed:SetAttribute('RewardCash',nil);for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed'})do local v=seeds:FindFirstChild(id);if v then v:SetAttribute('RewardCash',nil)end end
 player:SetAttribute('IndexBiomeHalfReward1',true);W.frames(5)
 check(not indexBadge().Visible and not Badge.Pulsing(indexBadge()),'no reward left: the badge hides and its pulse stops')
 tweens={};seeds.MooncapSeed:SetAttribute('RewardCash',1000);W.frames(5)
 local appear=false;for _,t in ipairs(tweens)do if t.Obj._class=='UIScale'and t.Obj.Parent==indexBadge()and t.Props.Scale==1 and t.From.Scale<1 then appear=true end end
 check(indexBadge().Visible and appear and Badge.Pulsing(indexBadge()),'it comes back with a pop-in (from a smaller scale) and pulses again')
 -- Reduced Motion: no pop, no pulse; switched on while it pulses, the pulse stops
 W.Gui.ReducedMotionEnabled=true;W.frames(2)
 check(not Badge.Pulsing(indexBadge())and not Badge.Pulsing(alertBadge()),'Reduced Motion switched on: every pulse stops')
 tweens={};seeds.MooncapSeed:SetAttribute('RewardCash',nil);W.frames(5)
 tweens={};seeds.MooncapSeed:SetAttribute('RewardCash',2000);W.frames(5)
 local any=false;for _,t in ipairs(tweens)do if t.Obj._class=='UIScale'and(t.Obj.Parent==indexBadge()or t.Obj.Parent==alertBadge())then any=true end end
 check(indexBadge().Visible and not any and not Badge.Pulsing(indexBadge())and indexBadge():FindFirstChildOfClass('UIScale').Scale==1,'with Reduced Motion the badge just appears: no pop tween, no pulse, scale 1')
 W.Gui.ReducedMotionEnabled=false;W.frames(2)
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
