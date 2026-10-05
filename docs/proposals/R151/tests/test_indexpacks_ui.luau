--!nocheck
-- R151 (owner: "add a pack index in the index and state rate of spawn and drop rates, shapes ... can just use the default pack shape"): the Index's PACKS tab on the Roblox mock with the REAL
-- ChestIndex, IndexPacksView151, IndexPackData151, ItemPictures, SeedPackVisuals, HudLayout and a layout engine (layout_indexpacks.luau) that places every GuiObject.
--  1. the tab        a ninth, first tab with a pack picture and its own colour; the same tab ring as every tab; opening it swaps the seed cards for the pack list, hides the reward bar,
--                    the seed counts and every reward; nothing about the other eight tabs changes (their own suites: R137, R138, R148 index_limited)
--  2. the cards      47 cards under 8 headers and a PACK SIZES card: the name, the pack tier, the biome, SPAWN or FROM, the how-to lines or the also-from line, a chip per seed rarity with
--                    its 1/N; the picture of every card is asked for with DefaultPackShape
--  3. every size     phones in portrait and landscape, tablets and computers (360x640 .. 1920x1080): the list fits the panel, no card overlaps another, nothing in a card overlaps anything
--                    else or leaves the card, every chip is wide enough for its text, the card list is as long as the sum of its cards
--  4. lazy           only the cards near what is on screen have their contents, a few per frame; the rest are empty shells until the list scrolls to them; pictures are drawn only for what
--                    is on screen (ItemPictures) and the same look is one template
--  5. a tap          opens EVERY SEED (each seed's own 1/N), the cards below move, a second tap closes it; a card with no seeds (the mystery pack) does nothing
--  6. tabs           leaving and coming back keeps the list (no rebuild) and its scroll position; a new width rebuilds it once
--  7. the mystery pack is a black silhouette while it is on screen, and the picture goes back to normal when ItemPictures re-uses it
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3=R.Vector3.new;local Vector2=R.Vector2
local L=require('./layout_indexpacks')(R)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
-- mock gaps for the pack builders (as in the R148 / R151 pack tests)
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
F.packAssets(W) -- the pack templates every picture is built from
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=151;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
function req.InvokeServer()return {Success=true,Message='Claimed!'}end
local Rules=W.module('SeedPackRules');local Fmt=W.module('OddsText85');local Data=W.module('IndexPackData151');local View=W.module('IndexPacksView151')
local Pic=W.module('ItemPictures')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local index=0
for _,stage in ipairs({1,6,2,3,5,4,7})do
 local odds=Rules.SeedOdds(config,stage,'Pack01',1)
 for _,seed in ipairs(Rules.ObtainablePool(config,stage))do
  index+=1;local e=R.new('Folder');e.Name=seed.Id
  e:SetAttribute('SeedId',seed.Id);e:SetAttribute('DisplayName',seed.Name);e:SetAttribute('Rarity',(Rules.GetRarity(seed.Id)))
  e:SetAttribute('Stage',stage);e:SetAttribute('SeedIndex',index);e:SetAttribute('BaseChance',odds[seed.Id]);e.Parent=catalog
 end
end
local seeds=R.new('Folder');seeds.Name='DiscoveredSeeds';seeds.Parent=player
local plants=R.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player
local function found(folder,id,cash)local v=R.new('BoolValue');v.Name=id;v.Value=true;if cash then v:SetAttribute('RewardCash',cash)end;v.Parent=folder end
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed'})do found(seeds,id,id=='MooncapSeed'and 240000 or nil)end
for _,id in ipairs({'SunflowerSeed','BluebellSeed'})do found(plants,id)end
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end})
-- spy on ItemPictures.Show: what the Index asks for
local shown={}
do local base=Pic.Show;Pic.Show=function(holder,tool,priority)shown[#shown+1]={Holder=holder,Tool=tool,Priority=priority};return base(holder,tool,priority)end end
local s=R.new('LocalScript');s.Name='ChestIndex';W.load('ChestIndex',s)
W.frames(10)
local gui=pg:FindFirstChild('ChestIndexGui');local nav=pg:FindFirstChild('GardenNavigation')
local screen={1280,720}
local function relay()L.lay(nav,screen[1],screen[2]);L.lay(gui,screen[1],screen[2]);W.frames(1);L.lay(gui,screen[1],screen[2])end
local function frames(n)for _=1,n do relay()end end
local function resize(w,h)screen={w,h};frames(4)end
pg:SetAttribute('SeedMenu','Index');frames(20)
local panel=gui:FindFirstChild('IndexPanel');local tabs=gui:FindFirstChild('BiomeProgress',true)
local seedList=gui:FindFirstChild('SeedCards',true);local packList=gui:FindFirstChild('PackCards',true)
local function tabOf(key)return gui:FindFirstChild('Biome'..key,true)end
local function builtCards()local out={};for _,c in ipairs(packList:GetChildren())do if c:IsA('TextButton')and c:FindFirstChild('Name')then out[#out+1]=c end end;return out end
local function allCards()local out={};for _,c in ipairs(packList:GetChildren())do if c:IsA('TextButton')then out[#out+1]=c end end;table.sort(out,function(a,b)return a.LayoutOrder<b.LayoutOrder end);return out end
local function selectPacks()tabOf('Packs').Activated:Fire();frames(6)end
local function textOf(card,name)local o=card:FindFirstChild(name);return o and o.Text end
-- (a child called Name is not reachable as `.Name`: that is the Instance's own property)
local function nameText(o)local n=o:FindFirstChild('Name');return n and n.Text end
-- 1. the tab ---------------------------------------------------------------------------------------------------------------------------------------------
local data=Data.Build{Order={1,6,2,3,5,4,7}}
local byKey={};for _,e in ipairs(data.Entries)do byKey[e.Key]=e end
do
 local t=tabOf('Packs')
 check(t and t:IsA('TextButton')and packList and seedList,'the PACKS tab (BiomePacks) and the pack list (PackCards) are built')
 local row={};for _,c in ipairs(tabs:GetChildren())do if c:IsA('TextButton')then row[#row+1]=c end end
 check(#row==9,'nine tabs in the row: the eight seed tabs and PACKS ('..#row..')')
 table.sort(row,function(a,b)return a.LayoutOrder<b.LayoutOrder end)
 check(row[1]==t and t.LayoutOrder==0,'PACKS is FIRST in the row (the row scrolls sideways: a tab at its far end would not be found)')
 local others={};for i=2,#row do others[#others+1]=row[i].Name end
 check(table.concat(others,',')=='Biome1,Biome6,Biome2,Biome3,Biome5,Biome4,Biome7,BiomeLimited','the other eight tabs keep their order ('..table.concat(others,',')..')')
 check(t:GetAttribute('BiomeName')=='PACKS'and t:FindFirstChild('Count').Text=='PACKS','the tab says PACKS')
 local logo=t:FindFirstChild('BiomeLogo');check(logo and logo._class=='Frame'and logo:FindFirstChild('SmoothFallback')==nil,'its icon is a pack picture holder (no biome logo)')
 check(t.Size.X.Offset==122 and t.Size.Y.Offset==58 and tabOf(1).Size.X.Offset==122,'it is the size of every other tab (122 x 58)')
 local fill=t:FindFirstChild('Fill');check(fill and fill.Visible==false,'it has no progress bar (there is nothing to find)')
 check(t:FindFirstChild('RewardDot')==nil,'no reward dot: a pack list has no rewards')
 local colors={};for _,c in ipairs(row)do local g=c:FindFirstChild('BrightFill');colors[#colors+1]=c.Name end
 check(not packList.Visible and seedList.Visible,'before it is chosen, the seed list shows and the pack list does not')
 local before=#seedList:GetChildren()
 selectPacks()
 check(packList.Visible and not seedList.Visible,'PACKS chosen: the pack list shows, the seed list hides')
 local ring=t:FindFirstChild('BrightOutline');check(ring and ring.Color.R==1 and ring.Thickness==3,'PACKS gets the white ring of the chosen tab (BrightOutline 3)')
 local ring1=tabOf(1):FindFirstChild('BrightOutline');check(ring1 and ring1.Thickness==2,'... and the Forest tab loses it')
 local bar=gui:FindFirstChild('CompletionBar',true);local progress=gui:FindFirstChild('Progress',true)
 check(not bar.Visible and progress.Visible and progress.Text:find('SPAWN',1,true)and progress.Text:find('DROPS',1,true),'the reward bar is gone and the line says what SPAWN and DROPS mean ('..progress.Text..')')
 check(not gui:FindFirstChild('LimitedRewards',true).Visible,'no LIMITED reward rows')
 local mid,gem=gui:FindFirstChild('MiddleGem',true),gui:FindFirstChild('GemReward',true)
 check(mid.Active==false and gem.Active==false and mid:GetAttribute('RewardReady')==false and gem:GetAttribute('RewardReady')==false,'the two milestone gems are inert on this tab (nothing to claim)')
 check(gui:FindFirstChild('TotalFound',true):FindFirstChild('Count').Text:find('FOUND 6 / ',1,true)~=nil,'the FOUND total at the top is unchanged by the tab ('..gui:FindFirstChild('TotalFound',true):FindFirstChild('Count').Text..')')
 check(#seedList:GetChildren()<=before,'(the seed cards of the old tab are gone: '..#seedList:GetChildren()..' children left)')
 local pos=packList.Position;check(near(pos.Y.Offset,progress.Position.Y.Offset+progress.Size.Y.Offset+8)and packList.AbsoluteSize.Y>100,'the pack list starts right under the key line and has room ('..pos.Y.Offset..', '..packList.AbsoluteSize.Y..' px high)')
end
-- 2. the cards ---------------------------------------------------------------------------------------------------------------------------------------------
-- build everything once, at desktop size, to read every card
do
 resize(1280,720)
 packList.CanvasPosition=Vector2.new(0,0)
 -- scroll through the whole list so every card is built
 local total=packList.CanvasSize.Y.Offset
 for y=0,total,300 do packList.CanvasPosition=Vector2.new(0,y);frames(3)end
 packList.CanvasPosition=Vector2.new(0,0);frames(3)
 local cards=allCards()
 check(#cards==47,'47 pack cards ('..#cards..')')
 local headers=0;for _,c in ipairs(packList:GetChildren())do if c.Name:find('^Header')then headers+=1 end end
 check(headers==8 and packList:FindFirstChild('Sizes')~=nil,'8 headers (7 biomes + SPECIAL PACKS) and the PACK SIZES card')
 local missing={};for _,e in ipairs(data.Entries)do if not packList:FindFirstChild(e.Key)then missing[#missing+1]=e.Key end end
 check(#missing==0,'every pack of the data has its card ('..table.concat(missing,',')..')')
 -- what a card says
 local bad=0
 for _,e in ipairs(data.Entries)do
  local c=packList:FindFirstChild(e.Key)
  if c and c:FindFirstChild('Name')then
   local ok=textOf(c,'Name')==e.Name and c.TierChip.Label.Text==string.upper(e.Tier.Name)and c.BiomeChip.Label.Text==string.upper(e.Biome)
   if e.Spawn then ok=ok and textOf(c,'SpawnValue')==e.Spawn.Text and textOf(c,'SpawnCaption')=='SPAWN'and c:FindFirstChild('SourceValue')==nil
   else ok=ok and textOf(c,'SourceCaption')=='FROM'and textOf(c,'SourceValue')==e.How[1].Source and c:FindFirstChild('SpawnValue')==nil end
   for i,g in ipairs(e.Drops)do
    local chip=c:FindFirstChild('Chip'..g.Key);ok=ok and chip and chip.Odds.Text==g.Text and nameText(chip)==g.Label..(g.Count>1 and(' x'..g.Count)or'')
   end
   local n=0;for _,ch in ipairs(c:GetChildren())do if ch.Name:find('^Chip')then n+=1 end end;ok=ok and n==#e.Drops
   if not ok then bad+=1;print('   card '..e.Key..' does not show its data')end
  else bad+=1;print('   card '..e.Key..' is empty')end
 end
 check(bad==0,'every card shows its name, tier, biome, spawn rate (or FROM + source), and one chip per drop group with its 1/N exactly as the data says')
 -- the how-to lines, the also-from line
 local f1=packList.Forest_05;check(f1:FindFirstChild('Also')and f1.Also.Text:find('Bonus roll 1/50',1,true)and f1.Also.Text:find('Daily reward',1,true)and f1.Also.Text:find('Mystery pedestal 1/17',1,true),'Forest_05: "'..tostring(f1.Also and f1.Also.Text)..'"')
 local v=packList.Void;check(v.How1 and v.HowTitle.Text=='HOW YOU GET IT'and v.How1.Text:find('The Darkened event',1,true)and v.How2.Text=='Bonus roll: 1/1,000'and v.How3.Text:find('Mystery pedestal',1,true),'Void: how you get it: '..tostring(v.How1 and v.How1.Text)..' / '..tostring(v.How2 and v.How2.Text))
 check(packList.Mech.How1.Text=='Shop (Robux)'and packList.Mech.How2.Text=='Daily reward: day 7'and packList.Verity.How1.Text:find('Verity quest',1,true)and packList.Starter.How1.Text=='Free tutorial gift'and packList.Mystery.How1.Text:find('Mystery pedestal',1,true),'Mech / Verity / Starter / Mystery say how you get them')
 check(packList.Mystery.DropTitle.Text=='IT TURNS OUT TO BE'and packList.Forest_01.DropTitle.Text=='DROPS','the mystery card\'s chips are titled IT TURNS OUT TO BE, the others DROPS')
 check(packList.Mystery.DropHint.Text==''and packList.Forest_03.DropHint.Text=='TAP FOR EVERY SEED','only a card with seeds invites a tap')
 local sizes=packList.Sizes;local n=0;for _,ch in ipairs(sizes:GetChildren())do if ch.Name:find('^Size%d')then n+=1 end end
 check(n==#data.Sizes and nameText(sizes.Size1)=='0.5x'and sizes.Size1.Odds.Text=='1/50'and nameText(sizes.Size5)=='5x'and sizes.Size5.Odds.Text=='1/100','PACK SIZES: '..n..' chips from the size table (0.5x 1/50 ... 25x 1/25K)')
 -- 3. the pictures of every card are asked for with DefaultPackShape
 local wrong=0;local byHolder={}
 for _,r in ipairs(shown)do
  local c=r.Holder.Parent;local e=c and byKey[c.Name]
  if e then
   byHolder[c.Name]=r
   local t=r.Tool
   if not(t:GetAttribute('DefaultPackShape')==true and t:GetAttribute('SeedPackTool')==true and t:GetAttribute('Stage')==e.Stage and t:GetAttribute('BagVariant')==e.Variant and t:GetAttribute('PackMutation')=='None')then wrong+=1 end
  end
 end
 local asked=0;for _ in pairs(byHolder)do asked+=1 end
 check(asked==47 and wrong==0,'every card\'s picture is asked for with a DefaultPackShape proxy of its own stage and variant ('..asked..' cards asked, '..wrong..' wrong)')
 local k1=Pic.Key(byHolder.Forest_03.Tool);local k2=Pic.Key(byHolder.Void.Tool);local k3=Pic.Key(byHolder.Mech.Tool);local k4=Pic.Key(byHolder.Verity.Tool)
 check(k1=='Pack|1|Pack03|None|Plain'and k2=='Pack|7|EclipseReliquary|None'and k3=='Pack|8|MechLimited|None'and k4=='Pack|7|VerityReliquary|None|Plain','picture keys: ordinary and Verity packs have their own |Plain look; the Void and the Mech pack (no shape variation) share the ordinary one ('..tostring(k1)..' / '..tostring(k2)..' / '..tostring(k3)..' / '..tostring(k4)..')')
 -- the tab's icon too
 local tabShown;for _,r in ipairs(shown)do if r.Holder==tabOf('Packs'):FindFirstChild('BiomeLogo')then tabShown=r end end
 check(tabShown and tabShown.Tool:GetAttribute('DefaultPackShape')==true and tabShown.Priority==0,'the tab\'s own icon asks for the default pouch as well')
end
-- 3b. the sizes of screens -------------------------------------------------------------------------------------------------------------------------------------
local SIZES={{360,640},{390,844},{412,915},{640,360},{844,390},{768,1024},{1024,768},{1280,720},{1366,768},{1920,1080}}
local function overlap(a,b)return a.x<b.x+b.w-1e-6 and b.x<a.x+a.w-1e-6 and a.y<b.y+b.h-1e-6 and b.y<a.y+a.h-1e-6 end
local function listRects(R,list)
 local out={}
 for k,v in pairs(R)do if k~='Chips'and k~='Seeds'and k~='How'then out[#out+1]={Name=k,Rect=v}end end
 for i,v in ipairs(R.How or{})do out[#out+1]={Name='How'..i,Rect=v}end
 for i,v in ipairs(R.Chips or{})do out[#out+1]={Name='Chip'..i,Rect=v}end
 for i,v in ipairs(R.Seeds or{})do out[#out+1]={Name='Seed'..i,Rect=v}end
 return out
end
print('PACKS tab by screen: panel x list (list width x height), card width, columns of chips, tallest / shortest card, canvas height, cards that fit one screen:')
for _,sz in ipairs(SIZES)do
 resize(sz[1],sz[2]);selectPacks();frames(2)
 local lw,lh=packList.AbsoluteSize.X,packList.AbsoluteSize.Y
 local cards=allCards();local w=cards[1].Size.X.Offset;local m=View.Metrics(w)
 -- the plan of every pack at this width, closed and open: every part inside its card, no two parts over each other
 local worst,tall,short,openTall=0,0,1e9,0;local problems={}
 for _,e in ipairs(data.Entries)do
  for _,open in ipairs({false,true})do
   local plan=View.Plan(e,m,open);local rects=listRects(plan.Rects,e)
   if not open then tall=math.max(tall,plan.Height);short=math.min(short,plan.Height)else openTall=math.max(openTall,plan.Height)end
   for _,x in ipairs(rects)do
    local r=x.Rect
    if r.x<0 or r.y<0 or r.x+r.w>m.Width+1e-6 or r.y+r.h>plan.Height+1e-6 then problems[#problems+1]=e.Key..' '..x.Name..' leaves its card' end
   end
   for i=1,#rects do for j=i+1,#rects do
    local a,b=rects[i],rects[j]
    -- the DropHint shares a row with the DropTitle and the Biome chip a row with the Tier chip: they are beside each other, not over each other
    if overlap(a.Rect,b.Rect)then problems[#problems+1]=e.Key..(open and' (open)'or'')..': '..a.Name..' overlaps '..b.Name end
   end end
   -- a chip is wide enough for its text (the longest name and the longest odds that can appear: "LEGENDARY x2" + "1/16.7B")
   for i,g in ipairs(e.Drops)do
    local need=(#g.Label+(g.Count>1 and 3 or 0))*7.2+#g.Text*7.8+6+11
    if plan.Rects.Chips[i].w<need*.8 then problems[#problems+1]=e.Key..' chip '..g.Key..' is '..plan.Rects.Chips[i].w..' wide, its text needs about '..math.floor(need)end
   end
  end
 end
 check(#problems==0,sz[1]..'x'..sz[2]..': every part of every one of the 47 cards (closed and open) is inside its card and over nothing else ('..#problems..' problems; '..tostring(problems[1])..')')
 -- the real shells: widths, order, no overlap, canvas
 local fit=true;local last=0;local prevBottom=-1;local ok=true
 for _,c in ipairs(allCards())do
  local y,h=c.Position.Y.Offset,c.Size.Y.Offset
  if c.Size.X.Offset~=w then ok=false end
  last=math.max(last,y+h)
 end
 local items={}
 for _,c in ipairs(packList:GetChildren())do if c:IsA('GuiObject')then items[#items+1]={Y=c.Position.Y.Offset,H=c.Size.Y.Offset,Name=c.Name}end end
 table.sort(items,function(a,b)return a.Y<b.Y end)
 for i=2,#items do if items[i].Y<items[i-1].Y+items[i-1].H-1e-6 then ok=false;print('   '..items[i].Name..' overlaps '..items[i-1].Name)end end
 check(ok and #items==56,sz[1]..'x'..sz[2]..': 56 items (47 cards, 8 headers, the sizes card) one under the other, none over another, every card '..w..' wide')
 check(near(packList.CanvasSize.Y.Offset,last,1)and w<=lw+1e-6 and w>=100,sz[1]..'x'..sz[2]..': the canvas ends where the last card does ('..packList.CanvasSize.Y.Offset..' / '..last..'); the cards fit the list ('..w..' <= '..lw..')')
 check(lh>=(sz[2]<420 and 60 or 150),sz[1]..'x'..sz[2]..': the list has room ('..lh..' px high)')
 local fitOne=0;for _,c in ipairs(allCards())do if c.Size.Y.Offset<=lh then fitOne+=1 end end
 print(string.format('   %4dx%-4d  list %4dx%-4d  card %4d wide  cols %d  closed cards %3d..%3d px (open: up to %3d)  canvas %5d  %d/47 fit the list',sz[1],sz[2],lw,lh,w,m.Cols,short,tall,openTall,packList.CanvasSize.Y.Offset,fitOne))
end
-- 4. lazy building ----------------------------------------------------------------------------------------------------------------------------------------
do
 resize(390,844);selectPacks()
 -- a new width rebuilt the shells: nothing but the first screen is built
 packList.CanvasPosition=Vector2.new(0,0);frames(6)
 local b0=#builtCards();local h=packList.AbsoluteSize.Y
 check(b0>=1 and b0<=8,'390x844: only the first screen of cards is built ('..b0..' of 47)')
 local first=allCards()[1]
 do -- every card that lies inside the list's window is built (the window's own size is read, not a guess)
  local h2=packList.AbsoluteSize.Y;local missing={}
  for _,c in ipairs(allCards())do if c.Position.Y.Offset<h2 and not c:FindFirstChild('Name')then missing[#missing+1]=c.Name end end
  check(#missing==0,'390x844: every card inside the list window ('..h2..' px) has its contents ('..table.concat(missing,',')..')')
  resize(390,1400);frames(6);local h3=packList.AbsoluteSize.Y;local missing3={}
  for _,c in ipairs(allCards())do if c.Position.Y.Offset<h3 and not c:FindFirstChild('Name')then missing3[#missing3+1]=c.Name end end
  check(h3>h2 and #missing3==0,'a taller window ('..h2..' -> '..h3..' px) builds the cards it newly shows ('..table.concat(missing3,',')..')')
  resize(390,844);frames(6)
 end
 check(packList:FindFirstChild('Forest_01')and packList.Forest_01:FindFirstChild('Name')and not(packList.Storm_06:FindFirstChild('Name')),'Forest_01 (on screen) has its contents; Storm_06 (at the far end) is an empty shell')
 -- scrolling builds what comes near, at most PerPass cards per call and per frame
 local maxStep=0;local prev=b0;local steps=0
 for y=0,packList.CanvasSize.Y.Offset,150 do
  packList.CanvasPosition=Vector2.new(0,y)
  local now=#builtCards();maxStep=math.max(maxStep,now-prev);prev=now;steps+=1
  frames(1);now=#builtCards();maxStep=math.max(maxStep,now-prev);prev=now
 end
 check(maxStep<=View.PerPass,'while scrolling, at most '..View.PerPass..' cards are built at a time ('..maxStep..')')
 check(#builtCards()==47,'scrolled to the end, every card has been built exactly once ('..#builtCards()..')')
 -- a jump to the middle builds the cards around it before the rest
 packList.CanvasPosition=Vector2.new(0,0);resize(360,640);selectPacks();packList.CanvasPosition=Vector2.new(0,0);frames(4)
 local mid=packList.CanvasSize.Y.Offset*.5;packList.CanvasPosition=Vector2.new(0,mid);frames(4)
 local near={};for _,c in ipairs(builtCards())do local y=c.Position.Y.Offset;if y>mid-1200 and y<mid+1200 then near[#near+1]=c.Name end end
 local farBuilt=0;for _,c in ipairs(builtCards())do local y=c.Position.Y.Offset;if y>mid+2500 then farBuilt+=1 end end
 check(#near>=1 and farBuilt==0,'360x640: jumping to the middle builds the cards around it ('..#near..') and none of the far end ('..farBuilt..')')
 -- instances: opening the tab costs a fraction of the whole list
 resize(412,915);selectPacks();packList.CanvasPosition=Vector2.new(0,0);frames(3)
 local before=#R.created;resize(360,640);packList.CanvasPosition=Vector2.new(0,0);frames(6);local firstScreen=#R.created-before
 for y=0,packList.CanvasSize.Y.Offset,200 do packList.CanvasPosition=Vector2.new(0,y);frames(2)end
 local everything=#R.created-before
 check(firstScreen<everything*.45,'360x640: the first screen of the tab makes '..firstScreen..' Gui objects, the whole list '..everything..' (the rest is only built when it is scrolled to)')
end
-- pictures: only what is on screen (or just beside it) is drawn
do
 resize(360,640);selectPacks();packList.CanvasPosition=Vector2.new(0,0);frames(10);R.advance(5);frames(30) -- (ItemPictures keeps a picture a few seconds after its holder left the screen: let that pass)
 local Stats=Pic.Stats();local views=0
 for _,c in ipairs(builtCards())do local p=c:FindFirstChild('Picture');if p and p:FindFirstChild('ItemViewport')then views+=1 end end
 local onScreen=0;local lo=packList.AbsolutePosition.Y;local hi=lo+packList.AbsoluteSize.Y
 for _,c in ipairs(builtCards())do local p=c.Picture;local y=p.AbsolutePosition.Y;if y+p.AbsoluteSize.Y>lo and y<hi then onScreen+=1 end end
 check(views>=1 and views<=onScreen+4,'360x640: pictures are drawn for the cards on screen and just beside it ('..views..' views, '..onScreen..' cards on screen)')
 local ids={};for _,c in ipairs(builtCards())do local p=c.Picture;local v=p:FindFirstChild('ItemViewport');if v then ids[#ids+1]=c.Name end end
 check(Stats.Templates>=1 and Stats.Templates<=47,'one template per look ('..Stats.Templates..' built)')
end
-- 5. a tap ---------------------------------------------------------------------------------------------------------------------------------------------------
do
 resize(390,844);selectPacks();packList.CanvasPosition=Vector2.new(0,0);frames(6)
 local card=packList.Forest_03;local below=packList.Forest_04
 local h0,y0=card.Size.Y.Offset,below.Position.Y.Offset;local canvas0=packList.CanvasSize.Y.Offset
 local built0=#builtCards()
 check(card:FindFirstChild('Seeds')==nil and card.DropHint.Text=='TAP FOR EVERY SEED','closed: no seed list, the hint says TAP FOR EVERY SEED')
 card.Activated:Fire();frames(3)
 local e=byKey.Forest_03;local nSeeds=0;for _,g in ipairs(e.Drops)do nSeeds+=#g.Seeds end
 local block=card:FindFirstChild('Seeds');local rows=0;if block then for _,r in ipairs(block:GetChildren())do if r.Name:find('^Seed')and r.Name~='SeedsTitle'then rows+=1 end end end
 check(block and block.Visible and rows==nSeeds,'a tap opens the seed list: one row per seed ('..rows..' of '..nSeeds..')')
 check(card.Size.Y.Offset>h0 and near(below.Position.Y.Offset-y0,card.Size.Y.Offset-h0,1e-6)and near(packList.CanvasSize.Y.Offset-canvas0,card.Size.Y.Offset-h0,1e-6),'the card grows by '..(card.Size.Y.Offset-h0)..' px, every card below moves down by as much and the canvas follows')
 check(card.DropHint.Text=='TAP TO CLOSE'and card:GetAttribute('Open')==true,'the hint says TAP TO CLOSE')
 local firstRow=block:FindFirstChild('Seed'..e.Drops[1].Seeds[1].Id)
 check(firstRow and nameText(firstRow)==e.Drops[1].Seeds[1].Name and firstRow.Odds.Text==e.Drops[1].Seeds[1].Text,'a seed row shows the seed\'s name and its own 1/N ('..tostring(firstRow and nameText(firstRow))..' '..tostring(firstRow and firstRow.Odds.Text)..')')
 check(#builtCards()>=built0,'(no other card was rebuilt or lost its contents)')
 local m=View.Metrics(card.Size.X.Offset);local plan=View.Plan(e,m,true)
 local inside=true;for _,r in ipairs(plan.Rects.Seeds)do if r.x<0 or r.x+r.w>m.Width or r.y+r.h>plan.Height then inside=false end end
 check(inside and card.Size.Y.Offset==plan.Height,'the open card is as tall as its plan ('..plan.Height..')')
 card.Activated:Fire();frames(3)
 check(near(card.Size.Y.Offset,h0)and near(below.Position.Y.Offset,y0)and not block.Visible and card.DropHint.Text=='TAP FOR EVERY SEED','a second tap closes it: the card and everything below go back')
 card.Activated:Fire();frames(2);check(card:FindFirstChild('Seeds')==block,'... and it opens again from the same list (built once)')
 card.Activated:Fire();frames(2)
 -- a card with no seeds does nothing
 local mystery=packList.Mystery;local hm=mystery.Size.Y.Offset
 for y=0,packList.CanvasSize.Y.Offset,200 do packList.CanvasPosition=Vector2.new(0,y);frames(1)end
 mystery.Activated:Fire();frames(2);check(near(mystery.Size.Y.Offset,hm)and mystery:FindFirstChild('Seeds')==nil,'the mystery pack has no seeds: a tap does nothing')
 -- an open card stays open when its width changes? (a new width makes new shells: closed ones are rebuilt closed, open ones open)
 packList.Forest_03.Activated:Fire();frames(2)
 resize(1280,720);frames(4)
 local c2=packList.Forest_03;check(c2:GetAttribute('Open')==nil or c2:GetAttribute('Open')==true,'(a new width keeps the open state in the plan)')
 local m2=View.Metrics(c2.Size.X.Offset);check(near(c2.Size.Y.Offset,View.Plan(e,m2,true).Height),'... an open card is still planned open after a resize')
 c2.Activated:Fire();frames(2)
end
-- 6. tabs --------------------------------------------------------------------------------------------------------------------------------------------------------
do
 resize(1280,720);selectPacks();packList.CanvasPosition=Vector2.new(0,0);frames(3)
 for y=0,600,100 do packList.CanvasPosition=Vector2.new(0,y);frames(1)end
 local card=packList.Forest_01;local keep=#packList:GetChildren()
 tabOf(1).Activated:Fire();frames(6)
 check(seedList.Visible and not packList.Visible and #seedList:GetChildren()>=5,'back on FOREST: the seed cards show ('..#seedList:GetChildren()..' children) and the pack list hides')
 check(gui:FindFirstChild('CompletionBar',true).Visible and gui:FindFirstChild('Progress',true).Text:find('SEEDS',1,true)~=nil,'... with its progress bar and its own counts')
 tabOf('Limited').Activated:Fire();frames(4)
 check(gui:FindFirstChild('LimitedRewards',true).Visible and not packList.Visible,'LIMITED still shows its reward rows and the timer')
 tabOf('Packs').Activated:Fire();frames(4)
 check(packList.Forest_01==card and #packList:GetChildren()==keep,'back on PACKS: the same list, not rebuilt ('..#packList:GetChildren()..' children)')
 check(packList.CanvasPosition.Y==600,'... at the scroll position it was left at ('..packList.CanvasPosition.Y..')')
 -- and the seed tab selection does not disturb pack building when the panel closes and opens again
 pg:SetAttribute('SeedMenu',nil);frames(3);pg:SetAttribute('SeedMenu','Index');frames(6)
 check(packList.Visible and #packList:GetChildren()==keep,'closing and opening the Index keeps the PACKS tab as it was')
end
-- 7. a new width rebuilds once ---------------------------------------------------------------------------------------------------------------------------------
do
 resize(1280,720);selectPacks();local before=packList.Forest_01
 resize(1280,720);frames(3)
 check(packList.Forest_01==before,'the same width does not rebuild anything')
 resize(390,844);frames(3)
 check(packList.Forest_01~=before and #packList:GetChildren()==56,'a new width makes new shells once ('..#packList:GetChildren()..' children, no leftovers)')
end
-- 8. the mystery pack is a silhouette ---------------------------------------------------------------------------------------------------------------------------
do
 resize(1280,720);selectPacks()
 for y=0,packList.CanvasSize.Y.Offset,150 do packList.CanvasPosition=Vector2.new(0,y);frames(2)end
 local mystery=packList.Mystery;packList.CanvasPosition=Vector2.new(0,mystery.Position.Y.Offset-20);frames(40)
 local holder=mystery.Picture;local v=holder:FindFirstChild('ItemViewport')
 if check(v~=nil,'the mystery card\'s picture is drawn while it is on screen')then
  check(v.ImageColor3.R<.1 and v.ImageColor3.G<.1 and v.ImageColor3.B<.2,'... as a black silhouette (ImageColor3 '..string.format('%.2f,%.2f,%.2f',v.ImageColor3.R,v.ImageColor3.G,v.ImageColor3.B)..')')
  packList.CanvasPosition=Vector2.new(0,0);frames(10);R.advance(5);frames(30)
  check(holder:FindFirstChild('ItemViewport')==nil,'scrolled away, the picture is released')
 end
 local other=packList.Forest_03;local ov=other.Picture:FindFirstChild('ItemViewport')
 -- the silhouette must not stay on a view that ItemPictures parks and re-uses for a normal card of the same look (Pack03 of Forest is the mystery's picture too)
 packList.CanvasPosition=Vector2.new(0,0);frames(30)
 local ok=true;for _,c in ipairs(builtCards())do local p=c:FindFirstChild('Picture');local pv=p and p:FindFirstChild('ItemViewport');if pv and c.Name~='Mystery'and pv.ImageColor3 and pv.ImageColor3.R<.9 then ok=false;print('   a dark picture on '..c.Name)end end
 check(ok,'no ordinary card ever shows a silhouette-tinted picture')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
