--!nocheck
-- R156 preview data (not a test): the REAL pack pity bars on the Roblox mock, driven into the states the owner asked about, and their GUI trees printed as SCENE lines for
-- render_gui155.mjs (R155's renderer, headless Chromium). Adapted from R155's pity_scene155.luau.
-- VIEW (set by run_pity_v2_preview156.sh): 'pc' (1920 x 1080), 'land' (844 x 390 phone), 'port' (390 x 844 phone).
-- MODE: 'current' = the bars as R155 has them (src untouched: gold / purple, diamond, 50 px above the slots); 'fresh' / 'deep' = the proposal (pity_bars_v2.patch applied to a scratch
-- copy of PityBars155 / PackPity155: the owner's pick, in its two shades) - 8 / 6 px above the slots, the clover, the item's name rows moved above the bars.
-- The rest of the HUD (hotbar slots, the held item's name and traits rows, the item tooltip, balances, status, MENU, jump / stick, BONUS ROLL) is a STAND-IN drawn from HudLayout's
-- own metrics, PityBars155's own answers (NameRow, ButtonSpot) and ItemTooltip155's own rule for where the tooltip goes (above the bars and the name rows), so the bars are seen where they sit.
-- Prints: SCENE <name> <cropX> <cropY> <cropW> <cropH> <scale> <json>, and CHECK lines (gaps, overlaps) for the write-up.
local W=require('./world');local R=W.R
local dump=require('./dump_tree153')
local V2=R.Vector2.new;local RGB=R.Color3.fromRGB
local VIEWS={pc={1920,1080,false},land={844,390,true},port={390,844,true}}
local view=VIEWS[VIEW or'pc'];local SW,SH,TOUCH=view[1],view[2],view[3]
MODE=MODE or'fresh'
W.UIS.TouchEnabled=TOUCH;W.UIS.KeyboardEnabled=not TOUCH;W.UIS.GamepadEnabled=false
W.Gui.GetInsetArea=function()return{Min=V2(0,0),Width=SW,Height=SH}end -- (the mock's safe area is always 1280 x 720)
W.workspace.CurrentCamera.ViewportSize=V2(SW,SH)
local Players=W.service('Players')
local player=R.new('Player');player.Name='Ann';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player;player.CharacterAdded=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local char=R.new('Model');char.Name='Ann';player.Character=char
local Pity=W.module('PackPity155');local B=W.module('PityBars155');local Hud=W.module('HudLayout')
if MODE=='deep'then Pity.Use('Deep')elseif MODE=='fresh'then Pity.Use('Fresh')end
local NEW=MODE~='current'
local m=Hud.Read(V2(SW,SH),TOUCH,nil)
local dock=B.DefaultDock(m,SW,SH)
local details=m.HotbarDetails~=false
-- how far above the slots the name / traits rows end (R155: a fixed 2 px; the proposal: just over the bars' top edge)
local row=NEW and B.NameRow(SW,SH,m,dock)or 2
local function overlaps(a,b,pad)pad=pad or 0;return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
-- the stand-in HUD ---------------------------------------------------------------------------------------------------------------------------------
local ctx=R.Instance.new('ScreenGui');ctx.Name='HudStandIn';ctx.DisplayOrder=20;ctx.Parent=pg
local function box(name,x,y,w,h,color,alpha,radius,text,textSize,textColor)
 local f=R.Instance.new('Frame');f.Name=name;f.Position=R.UDim2.fromOffset(x,y);f.Size=R.UDim2.fromOffset(w,h);f.BackgroundColor3=color or RGB(24,30,52);f.BackgroundTransparency=alpha or .35;f.ZIndex=1;f.Parent=ctx
 local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(0,radius or 8);c.Parent=f
 local s=R.Instance.new('UIStroke');s.Color=RGB(12,17,38);s.Thickness=2;s.Transparency=.3;s.ApplyStrokeMode=R.Enum.ApplyStrokeMode.Border;s.Parent=f
 if text then
  local t=R.Instance.new('TextLabel');t.Name='Text';t.Size=R.UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=text;t.TextSize=textSize or 12;t.Font=R.Enum.Font.FredokaOne
  t.TextColor3=textColor or RGB(214,226,255);t.TextStrokeTransparency=.3;t.TextStrokeColor3=RGB(8,13,24);t.TextWrapped=true;t.ZIndex=2;t.Parent=f
 end
 return f
end
local slotNames={'Desert Common','Lava Rare','Limited Mech','Void Pack','Shovel','Bat','Fire Pepper','Aloe','Ember Rose','Sand Fruit'}
local side=m.SlotSize
local slotBoxes={}
for i=1,m.Slots do slotBoxes[i]=box('Slot'..i,dock.X+(i-1)*(side+6),dock.Y,side,side,RGB(48,54,106),.15,8,slotNames[i],math.max(9,math.floor(side*.16)))end
box('Bag',dock.X+m.Slots*(side+6),dock.Y,side,side,RGB(48,54,106),.15,8,'Bag',14)
-- the held item's name (SelectedName: 26 px, 14 px text) and traits (SelectedTraits: 16 px, 11 px muted text) above the slots: the Hotbar's own rows, here -(row+42) and -(row+16)
local heldName,heldTraits
if details then
 local function plain(name,y,h,size,color)
  local f=box(name,dock.X,y,dock.W,h,nil,1,0,'',size,color);f:FindFirstChildOfClass('UIStroke').Enabled=false;return f
 end
 heldName=plain('SelectedName',dock.Y-row-42,26,14,RGB(255,255,255))
 heldTraits=plain('SelectedTraits',dock.Y-row-16,16,11,RGB(170,196,184))
end
local function selectSlot(i)
 for k,b in ipairs(slotBoxes)do
  local st=b:FindFirstChildOfClass('UIStroke');st.Color=k==i and RGB(255,255,255)or RGB(12,17,38);st.Transparency=k==i and 0 or .3
 end
end
for _,k in ipairs({'Speed','Cash','Gem'})do box('Wallet'..k,m[k..'X']or m.WalletX,m[k..'Y'],m.WalletWidth,m.WalletHeight,RGB(20,26,48),.3,6,k=='Gem'and'Gems'or k,math.max(10,math.floor(m.WalletHeight*.42)))end
for _,b in ipairs(Hud.HudBoxes(m,SW,SH,false))do
 if b.N=='Hub'then box('Menu',b.X,b.Y,b.W,b.H,RGB(74,125,184),.1,10,'MENU',12)
 elseif b.N=='Status'then box('Status',b.X,b.Y,b.W,b.H,RGB(20,26,48),.45,8,'weather / track / boosts',11)
 elseif b.N=='OwnerTools'then box('Tools',b.X,b.Y,b.W,b.H,RGB(40,46,80),.3,8,'TOOLS',10)
 elseif b.N=='Jump'or b.N=='ThumbR'then box('Jump',b.X+b.W/2-35,b.Y+b.H/2-35,70,70,RGB(255,255,255),.75,35,'jump',12)
 elseif b.N=='ThumbL'then box('Stick',b.X+b.W/2-45,b.Y+b.H/2-45,90,90,RGB(255,255,255),.82,45,'',12)end
end
-- the BONUS ROLL button: a stand-in drawn where TreadmillBonusClient puts the real one (PityBars155.ButtonSpot with the same boxes and notice rows)
local TB=W.module('TreadmillBonusRules');local Notice=W.module('HudNoticeLayout')
local function bonusRect()
 local rows=Notice.Calculate(SW,SH,36,TB.NoticeFlags);local extra={}
 for name,r in pairs(rows)do if type(r)=='table'then extra[#extra+1]={N=name,X=r.X-r.Width/2,Y=r.Y,W=r.Width,H=r.Height}end end
 return B.ButtonSpot(TB,m,SW,SH,Hud.HudBoxes(m,SW,SH,true),extra)
end
local bonus
local function showBonus(on)
 if bonus then bonus:Destroy();bonus=nil end
 if on then local r=bonusRect();bonus=box('BonusRoll',r.X,r.Y,r.W,r.H,RGB(255,176,38),.05,14,'BONUS ROLL  NEXT 3:12',math.max(11,math.floor(r.H*.3)),RGB(70,30,4));return r end
end
-- the held item's name label as it is now (ItemTooltip155 keeps clear of the label and, when it has text, the traits row): nil when nothing is held
local function nameRect()
 if not(details and heldName and heldName:FindFirstChild('Text').Text~='')then return nil end
 local ny=heldName.Position.Y.Offset
 local bottom=heldTraits:FindFirstChild('Text').Text~=''and dock.Y-row or ny+26
 return {X=dock.X,Y=ny,W=dock.W,H=bottom-ny}
end
-- the item tooltip (ItemTooltip155): a stand-in panel at the rect its own rule gives: its bottom 6 px above the highest of: the slot, the bars' rects less 8 px, the held name rows
local tip
local function showTip(on,slotIndex,title)
 if tip then tip:Destroy();tip=nil end
 if not on then return nil end
 local slot={X=dock.X+(slotIndex-1)*(side+6),Y=dock.Y,W=side,H=side}
 local tw=math.min(math.clamp(math.floor(SW*.34),210,300),SW-16);local th=172
 local x=math.clamp(slot.X+slot.W/2-tw/2,8,SW-tw-8)
 local bottom=slot.Y-6
 local P=s and s.Placement
 if P then
  local avoid={}
  avoid[#avoid+1]={X=P.Pair.X-8,Y=P.Pair.Y-8,W=P.Pair.W+16,H=P.Pair.H+16}
  local nr=nameRect();if nr then avoid[#avoid+1]=nr end
  for _,a in ipairs(avoid)do if a.Y<slot.Y and x<a.X+a.W and x+tw>a.X then bottom=math.min(bottom,a.Y-6)end end
 end
 tip=box('Tooltip',x,bottom-th,tw,th,RGB(14,33,25),.04,10,nil)
 local function line(y,text,size,color)
  local t=R.Instance.new('TextLabel');t.Size=R.UDim2.fromOffset(tw-24,size+4);t.Position=R.UDim2.fromOffset(12,y);t.BackgroundTransparency=1;t.Text=text;t.TextSize=size;t.Font=R.Enum.Font.FredokaOne
  t.TextColor3=color;t.TextXAlignment=R.Enum.TextXAlignment.Left;t.ZIndex=3;t.TextWrapped=false;t.Parent=tip
 end
 line(10,title or'Desert Common Pack',15,RGB(255,255,255))
 for i=1,4 do line(10+22*i,'(its odds rows)',13,RGB(180,210,196))end
 line(10+22*5,'LUCKY PACK: x1.5 luck on this one!',13,RGB(255,214,140))
 line(10+22*6+2,'every 10th pack u open is lucky ...',12,RGB(140,168,156))
 return {X=x,Y=bottom-th,W=tw,H=th}
end
-- the real bars -------------------------------------------------------------------------------------------------------------------------------------
s=B.Start(player,{})
local gui=pg:FindFirstChild(B.Name);gui.AbsoluteSize=V2(SW,SH)
local tagGui=pg:FindFirstChild(B.TagName);tagGui.AbsoluteSize=V2(SW,SH)
pg.ChildAdded:Connect(function(c)if c.ClassName=='ScreenGui'then c.AbsoluteSize=V2(SW,SH)end end)
local function frames(n)W.frames(n,1/60)end
frames(3)
-- the clover: in game CloverIcon153 shows the uploaded picture, else the drawn copy (CloverPassImage153 through EmbeddedImage153); the mock has no EditableImage, so the drawn copy's route is set here
-- by hand (the renderer draws the decoded CloverPassImage153 picture in every ImageLabel marked as having an image)
local function showClover()
 for _,d in ipairs(gui:GetDescendants())do
  if d.Name=='Embedded'and d.ClassName=='ImageLabel'then d.Visible=true;d.ImageContent='clover'
  elseif d.Name=='Fallback'then d.Visible=false end
 end
end
if NEW then showClover()end
local function holdPack(name,variant,traits,slot)
 for _,t in ipairs(char:GetChildren())do t.Parent=nil end
 if heldName then
  heldName:FindFirstChild('Text').Text=name or'';heldTraits:FindFirstChild('Text').Text=traits or''
  -- (R156: with no traits line the name drops into its row, so it sits right over the bars; R155 keeps the name where it was, 44 px up)
  heldName.Position=R.UDim2.fromOffset(dock.X,NEW and dock.Y-row-((traits or'')~=''and 42 or 26)or dock.Y-44)
 end
 selectSlot(name and(slot or 1)or nil)
 if variant then local t=R.new('Tool');t.Name=name;t:SetAttribute('SeedPackTool',true);t:SetAttribute('BagVariant',variant);t.Parent=char end
 frames(40)
end
local function set(n,e)player:SetAttribute('PackPityNormal',n);player:SetAttribute('PackPityEvent',e);frames(80)end
local notices,card
local function noticeGui()local g=pg:FindFirstChild('ChestChaseNotices83');if g then g.AbsoluteSize=V2(SW,SH)end;return g end
local function emit(name,crop,scale)
 if NEW then showClover()end
 local roots={ctx,gui}
 if card then roots[#roots+1]=card end
 roots[#roots+1]=tagGui
 local ng=noticeGui();if ng then roots[#roots+1]=ng end
 local kids={}
 for _,r in ipairs(roots)do for _,d in ipairs(r:GetDescendants())do if(d.ClassName=='TextLabel'or d.ClassName=='TextButton')then if d.TextStrokeColor3==nil then d.TextStrokeColor3=RGB(0,0,0)end;if d.TextColor3==nil then d.TextColor3=RGB(0,0,0)end end end end
 for _,r in ipairs(roots)do
  local j=dump(r,SW,SH);local inner=j:match('"kids":%[(.*)%]}$')
  if inner and inner~=''then kids[#kids+1]=inner end
 end
 crop=crop or{0,0,SW,SH}
 print(('SCENE %s %d %d %d %d %s {"canvas":[%d,%d],"kids":[%s]}'):format(name,crop[1],crop[2],crop[3],crop[4],tostring(scale or 1),SW,SH,table.concat(kids,',')))
end
local function lucky(group)
 local key=Pity.LuckyAttribute[group]
 player:SetAttribute(key,(player:GetAttribute(key)or 0)+1);player:SetAttribute(Pity.Attribute[group],0)
end
local function untilPop(group)for _=1,120 do frames(1);if s.Bars[group].PopAt then return end end end
local function toAge(group,age)local at=s.Bars[group].PopAt;while R.clock-at<age-1e-6 do frames(1)end end
local function clearNotices()local g=pg:FindFirstChild('ChestChaseNotices83');if g then local host=g:FindFirstChild('NoticeStack');if host then for _,c in ipairs(host:GetChildren())do c.Visible=false end end end end
local function skipCard(kind,rank,phone)
 local cg=R.Instance.new('ScreenGui');cg.Name='RarePullReveal';cg.DisplayOrder=96;cg.Parent=pg;cg.AbsoluteSize=V2(SW,SH)
 local Card=W.module('RarePullCard');local Rules=W.module('RarePullRules')
 local okC,c=pcall(Card.Create,cg,kind,{Rank=rank,Phone=phone,SeedName='Sand Fruit Seed',Odds=90,Skip=true})
 if not okC then print('CARD failed: '..tostring(c));return nil end
 if kind=='Ladder'then local tl=Rules.CardTimeline(rank,false);c:UpdateLadder(tl.Burst*.6,tl)
 else local tl=Rules.Timeline(rank,'InPlace');c:UpdateInPlace(math.max(tl.SkipFrom+.6,tl.Climax-1),tl)end
 card=cg;local b=cg:FindFirstChild('Skip button',true)
 if b then return {X=b.Position.X.Offset,Y=b.Position.Y.Offset,W=b.Size.X.Offset,H=b.Size.Y.Offset}end
end
local function dropCard()if card then card:Destroy();card=nil end end
-- numbers for the write-up ---------------------------------------------------------------------------------------------------------------------------
local P=s.Placement.Pair
local band={X=dock.X,Y=dock.Y-row-42,W=dock.W,H=42}
local others={}
for _,b in ipairs(Hud.HudBoxes(m,SW,SH,false))do if b.N~='Hotbar'then others[#others+1]=b end end
local hit={}
if details then for _,b in ipairs(others)do if overlaps(band,b,4)then hit[#hit+1]=b.N end end end
print(('PLACE %s %s bars %dx%d pair %d,%d %dx%d stacked=%s clear=%s | gap to the slots %d px | name rows end %d px above the slots, start %d px above | name rows %s, in the way of: %s'):format(
 VIEW or'pc',MODE,s.Placement.Bar.W,s.Placement.Bar.H,P.X,P.Y,P.W,P.H,tostring(s.Placement.Stacked),tostring(s.Placement.Clear),dock.Y-(P.Y+P.H),row,row+42,details and'shown'or'hidden (this screen has no room)',#hit>0 and table.concat(hit,', ')or'nothing'))
local barsCrop,boxCrop
do
 local x0=math.max(0,math.floor(dock.X-16));local y0=math.max(0,math.floor(dock.Y-(TOUCH and 120 or 330)))
 barsCrop={x0,y0,math.min(SW-x0,math.floor(dock.W+32)),SH-y0}
end
print(('BAND %s %s dock %d,%d %dx%d band %d,%d %dx%d'):format(VIEW or'pc',MODE,dock.X,dock.Y,dock.W,dock.H,band.X,band.Y,band.W,band.H))
local lastTip,lastBonus,lastPill
local function rectsClear(name,r,actualName)
 local bad={}
 local e=B.Extent(P,s.Placement.Bar.W,s.Placement.Bar.H)
 if overlaps(r,e,0)then bad[#bad+1]='bars'end
 local nr=actualName and nameRect()or(details and band or nil)
 if nr and overlaps(r,nr,0)then bad[#bad+1]='name rows'end
 if overlaps(r,{X=dock.X,Y=dock.Y,W=dock.W,H=dock.H},0)then bad[#bad+1]='slots'end
 print(('CHECK %s %s %s %d,%d %dx%d: %s'):format(VIEW or'pc',MODE,name,r.X,r.Y,r.W,r.H,#bad==0 and'clear of the bars, the name rows and the slots'or('OVERLAPS '..table.concat(bad,', '))))
end
if VIEW=='pc'or VIEW==nil then
 -- 3/10 and 3/10, nothing held
 set(3,3);holdPack(nil,nil);emit('pc_33',barsCrop,1)
 -- the held pack's highlight with its group at 9/10
 holdPack('Desert Common Pack','Pack01',nil,1);set(9,3);emit('pc_held9',barsCrop,1)
 holdPack('Limited Mech Pack','MechLimited',nil,3);set(3,9);emit('pc_evheld',barsCrop,1)
 holdPack(nil,nil);set(9,9);emit('pc_99',barsCrop,1)
 -- worst case for the name rows: a fruit with a name and a traits line
 set(3,3);holdPack('Sand Fruit (4.2 kg)',nil,'Gold   Wet',10);emit('pc_name',barsCrop,1)
 -- the item tooltip of a hovered pack (a slot's tooltip takes one baseline along the hotbar: above the bars and the name rows)
 holdPack('Void Pack','EclipseReliquary',nil,4);set(3,9);local t=showTip(true,4,'Void Pack');lastTip=t;emit('pc_tip',{barsCrop[1]-130,barsCrop[2]-60,barsCrop[3]+130,barsCrop[4]+60},1);if t then rectsClear('tooltip',{X=t.X,Y=t.Y,W=t.W,H=t.H+5},true);print(('CHECK pc %s tooltip bottom edge %d px above the slots'):format(MODE,dock.Y-(t.Y+t.H)))end;showTip(false)
 -- the lucky pop (0.42 s, the shine across) of each bar
 holdPack(nil,nil);set(9,9);lucky('Normal');untilPop('Normal');toAge('Normal',.42);emit('pc_pop_n',barsCrop,1);frames(240);clearNotices()
 set(9,9);lucky('Event');untilPop('Event');toAge('Event',.42);emit('pc_pop_e',barsCrop,1);frames(240);clearNotices();frames(30)
 -- the close-up of the pair (the clover, the rims), 3/10 and 9/10 with the normal pack in hand
 local zoom={math.floor(P.X-10),math.floor(P.Y-34),math.floor(P.W+20),math.floor(P.H+48)}
 holdPack(nil,nil);set(3,3);emit('pc_zoom_33',zoom,3)
 holdPack('Desert Common Pack','Pack01',nil,1);set(9,9);emit('pc_zoom_99',zoom,3)
 -- the BONUS ROLL button (a treadmill; a roll is ready) and the SKIP pill (an opening)
 holdPack(nil,nil);set(3,3);local br=showBonus(true);lastBonus=br;emit('pc_bonus',{barsCrop[1]-60,math.max(0,math.floor(br.Y-24)),barsCrop[3]+120,SH-math.max(0,math.floor(br.Y-24))},1);rectsClear('BONUS ROLL button',br);showBonus(false)
 local pill=skipCard('Ladder',4,false);emit('pc_skip',{0,math.floor(SH*.55),SW,math.floor(SH*.45)},1);if pill then rectsClear('SKIP pill',pill)end;dropCard()
elseif VIEW=='land'then
 set(3,3);holdPack(nil,nil);emit('land_33',nil,1)
 holdPack('Desert Common Pack','Pack01',nil,1);set(9,3);emit('land_held9',nil,1)
 holdPack('Limited Mech Pack','MechLimited',nil,3);set(3,9);emit('land_evheld',nil,1)
 holdPack(nil,nil);set(3,3);local br=showBonus(true);emit('land_bonus',nil,1);rectsClear('BONUS ROLL button',br);showBonus(false)
 player:SetAttribute('RarePullCinematic','InPlace');frames(10)
 local pill=skipCard('InPlace',6,true);emit('land_skip',nil,1);if pill then rectsClear('SKIP pill',pill)end;dropCard();player:SetAttribute('RarePullCinematic',nil)
else
 local crop={0,math.floor(dock.Y-140),SW,SH-math.floor(dock.Y-140)}
 set(3,3);holdPack(nil,nil);emit('port_33',crop,1)
 holdPack('Desert Common Pack','Pack01',nil,1);set(9,3);emit('port_held9',crop,1)
 holdPack('Limited Mech Pack','MechLimited',nil,3);set(3,9);emit('port_evheld',crop,1)
 holdPack(nil,nil);set(3,3);local br=showBonus(true);emit('port_bonus',crop,1);rectsClear('BONUS ROLL button',br);showBonus(false)
 local pill=skipCard('Ladder',4,true);emit('port_skip',crop,1);if pill then rectsClear('SKIP pill',pill)end;dropCard()
end
