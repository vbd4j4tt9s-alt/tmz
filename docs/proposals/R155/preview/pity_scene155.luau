--!nocheck
-- R155 preview data (not a test): the REAL pack pity bars (PityBars155) on the Roblox mock, driven into the states the owner asked about, and their GUI trees printed as
-- SCENE lines for render_gui155.mjs (headless Chromium). The real top notices (NoticeFeed83, the lucky pack's "LUCKY PACK! x1.5 luck") and the real reveal card
-- (RarePullCard, Legendary) are in the same scenes. The rest of the HUD (hotbar slots, the held item's name, balances, status, MENU, BASE / TRACK, jump / stick) is a
-- STAND-IN drawn from HudLayout's own metrics (the boxes every HUD script places itself by), so the bars are seen where they sit among them.
-- VIEW (set by run_pity_preview155.sh): 'pc' (1920 x 1080), 'land' (844 x 390 phone), 'port' (390 x 844 phone).
-- Prints: SCENE <name> <cropX> <cropY> <cropW> <cropH> <scale> <json>
local W=require('./world');local R=W.R
local dump=require('./dump_tree153')
local V2=R.Vector2.new;local RGB=R.Color3.fromRGB
local VIEWS={pc={1920,1080,false},land={844,390,true},port={390,844,true}}
local view=VIEWS[VIEW or'pc'];local SW,SH,TOUCH=view[1],view[2],view[3]
W.UIS.TouchEnabled=TOUCH
W.workspace.CurrentCamera.ViewportSize=V2(SW,SH)
local Players=W.service('Players')
local player=R.new('Player');player.Name='Ann';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player;player.CharacterAdded=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local char=R.new('Model');char.Name='Ann';player.Character=char
local Pity=W.module('PackPity155');local B=W.module('PityBars155');local Hud=W.module('HudLayout')
local m=Hud.Read(V2(SW,SH),TOUCH,nil)
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
local dock=B.DefaultDock(m,SW,SH)
local slotNames={'Desert Common','Lava Rare','Limited Mech','Void Pack','Shovel','Bat','Fire Pepper','Aloe','Ember Rose','Sand Fruit'}
local side=m.SlotSize
for i=1,m.Slots do box('Slot'..i,dock.X+(i-1)*(side+6),dock.Y,side,side,RGB(48,54,106),.15,8,slotNames[i],math.max(9,math.floor(side*.16)))end
box('Bag',dock.X+m.Slots*(side+6),dock.Y,side,side,RGB(48,54,106),.15,8,'Bag',14)
local held=nil
if m.HotbarDetails~=false then held=box('SelectedName',dock.X,dock.Y-44,dock.W,26,nil,1,0,'',14,RGB(255,255,255));held:FindFirstChildOfClass('UIStroke').Enabled=false end
for _,k in ipairs({'Speed','Cash','Gem'})do box('Wallet'..k,m[k..'X']or m.WalletX,m[k..'Y'],m.WalletWidth,m.WalletHeight,RGB(20,26,48),.3,6,k=='Gem'and'Gems'or k,math.max(10,math.floor(m.WalletHeight*.42)))end
for _,b in ipairs(Hud.HudBoxes(m,SW,SH,false))do
 if b.N=='Hub'then box('Menu',b.X,b.Y,b.W,b.H,RGB(74,125,184),.1,10,'MENU',12)
 elseif b.N=='Status'then box('Status',b.X,b.Y,b.W,b.H,RGB(20,26,48),.45,8,'weather / track / boosts',11)
 elseif b.N=='OwnerTools'then box('Tools',b.X,b.Y,b.W,b.H,RGB(40,46,80),.3,8,'TOOLS',10)
 elseif b.N=='Jump'or b.N=='ThumbR'then local j=box('Jump',b.X+b.W/2-35,b.Y+b.H/2-35,70,70,RGB(255,255,255),.75,35,'jump',12)
 elseif b.N=='ThumbL'then box('Stick',b.X+b.W/2-45,b.Y+b.H/2-45,90,90,RGB(255,255,255),.82,45,'',12)end
end
if m.Travel then local t=m.Travel;box('Base',t.X,t.Y,t.Horizontal and t.Size or t.W,t.Horizontal and t.H or t.Size,RGB(70,170,90),.15,8,'BASE',11);box('Track',t.Horizontal and t.X+t.Size+t.Gap or t.X,t.Horizontal and t.Y or t.Y+t.Size+t.Gap,t.Horizontal and t.Size or t.W,t.Horizontal and t.H or t.Size,RGB(220,120,60),.15,8,'TRACK',11)end
-- the real bars -------------------------------------------------------------------------------------------------------------------------------------
local s=B.Start(player,{})
local gui=pg:FindFirstChild(B.Name);gui.AbsoluteSize=V2(SW,SH)
local tagGui=pg:FindFirstChild(B.TagName);tagGui.AbsoluteSize=V2(SW,SH)
pg.ChildAdded:Connect(function(c)if c.ClassName=='ScreenGui'then c.AbsoluteSize=V2(SW,SH)end end) -- (the notices' layer sizes itself from its AbsoluteSize: the mock's is 1280 x 720)
local function frames(n)W.frames(n,1/60)end
frames(3)
local function holdPack(name,variant)
 for _,t in ipairs(char:GetChildren())do t.Parent=nil end
 if held then held:FindFirstChild('Text').Text=name or''end
 if variant then local t=R.new('Tool');t.Name=name;t:SetAttribute('SeedPackTool',true);t:SetAttribute('BagVariant',variant);t.Parent=char end
 frames(40)
end
local function set(n,e)player:SetAttribute('PackPityNormal',n);player:SetAttribute('PackPityEvent',e);frames(80)end
local notices,card
local function noticeGui()local g=pg:FindFirstChild('ChestChaseNotices83');if g then g.AbsoluteSize=V2(SW,SH)end;return g end
local function emit(name,crop,scale)
 local roots={ctx,gui}
 if card then roots[#roots+1]=card end
 roots[#roots+1]=tagGui
 local ng=noticeGui();if ng then roots[#roots+1]=ng end
 local kids={}
 -- (Roblox gives every label a black text stroke colour; the mock leaves it nil, and dump_tree153 has no Color3 of its own to fall back on)
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
local function reveal(phone)
 local cg=R.Instance.new('ScreenGui');cg.Name='RarePullReveal';cg.DisplayOrder=96;cg.Parent=pg;cg.AbsoluteSize=V2(SW,SH)
 local Card=W.module('RarePullCard');local Rules=W.module('RarePullRules')
 local okC,c=pcall(Card.Create,cg,'Ladder',{Rank=4,Phone=phone,SeedName='Sand Fruit Seed',Odds=90})
 if okC then
  local tl=Rules.CardTimeline(4,false);local beats=table.clone(tl);beats.Wait=true;beats.Out=1e6;beats.Length=1e6
  pcall(c.UpdateLadder,c,Rules.ShownAt(tl)+.6,beats);card=cg
 else print('CARD failed: '..tostring(c))end
end
local function untilPop(group)for _=1,120 do frames(1);if s.Bars[group].PopAt then return end end end
local function toAge(group,age)local at=s.Bars[group].PopAt;while R.clock-at<age-1e-6 do frames(1)end end
local function clearNotices()local g=pg:FindFirstChild('ChestChaseNotices83');if g then local host=g:FindFirstChild('NoticeStack');if host then for _,c in ipairs(host:GetChildren())do c.Visible=false end end end end
-- the bars' own region (crop) and the whole screen
local P=s.Placement.Pair
local barsCrop={math.max(0,math.floor(dock.X-16)),math.max(0,math.floor(P.Y-(TOUCH and 40 or 64))),0,0}
barsCrop[3]=math.min(SW-barsCrop[1],math.floor(dock.W+32));barsCrop[4]=SH-barsCrop[2]
print(('PLACE %s bars %dx%d pair %d,%d %dx%d stacked=%s clear=%s'):format(VIEW or'pc',s.Placement.Bar.W,s.Placement.Bar.H,P.X,P.Y,P.W,P.H,tostring(s.Placement.Stacked),tostring(s.Placement.Clear)))
if VIEW=='pc'or VIEW==nil then
 set(3,3);emit('pc_33',barsCrop,1)
 holdPack('Desert Common Pack','Pack01');set(9,3);emit('pc_held9',barsCrop,1)
 holdPack(nil,nil);set(9,9);emit('pc_99',barsCrop,1)
 -- the lucky pop, as a strip of the normal bar: the pop, the shine, the words, back to 0/10
 set(9,3);lucky('Normal');untilPop('Normal')
 for _,age in ipairs({.13,.42,1.2,2.4})do toAge('Normal',age);emit(('pc_pop_%03d'):format(math.floor(age*100+.5)),barsCrop,1)end
 frames(200)
 -- the full screen: the notice at the top while the bar pops
 set(9,4);lucky('Normal');untilPop('Normal');toAge('Normal',.2);emit('pc_full_pop',nil,.5)
 frames(240);clearNotices();frames(30)
 -- the reveal moment: a lucky pack opens to a Legendary: the tag on the real card, the bars out of the way under it
 set(9,4);reveal(false)
 holdPack(nil,nil);player:SetAttribute('RarePullCinematic','Ladder');frames(10);lucky('Normal');frames(80)
 emit('pc_reveal',nil,.5)
 -- collected: the card goes, the bar pops
 if card then card:Destroy();card=nil end
 player:SetAttribute('RarePullCinematic',nil);untilPop('Normal');toAge('Normal',.14);emit('pc_after_collect',barsCrop,1)
 frames(240);clearNotices();frames(30)
 -- Reduced Motion: the same pop without the scale / shine / ring
 W.Gui.ReducedMotionEnabled=true;set(9,4);lucky('Normal');untilPop('Normal');toAge('Normal',.42);emit('pc_reduced',barsCrop,1);W.Gui.ReducedMotionEnabled=false
 frames(240)
elseif VIEW=='land'then
 set(3,3);emit('land_33',nil,1)
 holdPack('Limited Mech Pack','MechLimited');set(3,9);emit('land_held9',nil,1)
 holdPack(nil,nil);set(3,9);lucky('Event');untilPop('Event');toAge('Event',.14);emit('land_pop',nil,1)
 frames(240);clearNotices();frames(30)
 set(9,3);reveal(true);player:SetAttribute('RarePullCinematic','Ladder');frames(10);lucky('Normal');frames(80);emit('land_reveal',nil,1)
else
 set(3,3);emit('port_33',nil,1)
 holdPack('Desert Common Pack','Pack01');set(9,3);emit('port_held9',nil,1)
end
