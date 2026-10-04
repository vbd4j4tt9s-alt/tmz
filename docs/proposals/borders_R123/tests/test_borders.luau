--!nocheck
-- R123: rarity emblems removed; each rarity has its own card border (GardenCardMotion.Rarity).
-- Run with run.sh (R113 inventory mock world + fixtures).
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local ORDER={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local EMBLEMS={RarityDecoration=true,RarityBadge=true}
local function emblems(root)local n=0;for _,d in ipairs(root:GetDescendants())do if EMBLEMS[d.Name]then n+=1 end end;return n end

-- 1. Source: no emblem calls left in the game code (ReplicatedStorage + client scripts that show rarity).
for name,src in pairs(W.B)do
 for _,pat in ipairs({'Theme%.Icon%(','Theme%.Badge%(','T%.Icon%(','T%.Badge%(','RarityDecoration','RarityBadge'})do
  check(not src:find(pat),name..' has no emblem call/instance ('..pat..')')
 end
end
local Theme=W.module('GardenTheme');local Borders=W.module('GardenCardMotion')
check(Theme.Icon==nil and Theme.Badge==nil,'GardenTheme.Icon/Badge removed (no remaining callers)')
check(W.B.PlantInspection:find('Theme.CardBorder(harvest,rarity)',1,true)~=nil,'plant inspection harvest panel uses the rarity border')
check(W.B.ChestIndex:find('Bright.Card(card,Theme.Rarity(rarity).Accent,stage==8,rarity)',1,true)~=nil,'index cards use the rarity border') -- (R148: stage==8, the Mech seeds, keep their limited card inside the LIMITED tab)

-- 2. Each rarity gets its own, distinct border.
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local sheet=R.Instance.new('ScreenGui');sheet.Name='BorderSheet';sheet.Parent=pg
local function card(r)local f=R.Instance.new('Frame');f.Name=r;f.Size=R.UDim2.fromOffset(104,104);Theme.Corner(f,8);f.Parent=sheet;Theme.CardBorder(f,r);return f end
local sig={};local cards={}
local function signature(f)
 local s=f.AnimatedBorder;local parts={tostring(s.Color.R)..','..tostring(s.Color.G)..','..tostring(s.Color.B),s.Thickness,s:FindFirstChild('BorderShine')and'grad'or'-'}
 local o=f:FindFirstChild('RarityBorder');if o then local names={};for _,c in ipairs(o:GetChildren())do names[#names+1]=c.Name end;table.sort(names);parts[#parts+1]=table.concat(names,'+')end
 return table.concat(parts,'|')
end
for _,r in ipairs(ORDER)do
 local f=card(r);cards[r]=f
 check(f:GetAttribute('BorderRarity')==r,r..' border applied')
 local n=0;for _,c in ipairs(f:GetChildren())do if c:IsA('UIStroke')then n+=1 end end;check(n==1,r..': one stroke on the card itself ('..n..')')
 local k=signature(f);check(sig[k]==nil,r..' border is distinct (same as '..tostring(sig[k])..')');sig[k]=r
end
local function has(r,path)local x=cards[r];for part in path:gmatch('[^%.]+')do x=x and x:FindFirstChild(part)end;return x~=nil end
check(not has('Common','RarityBorder')and cards.Common.AnimatedBorder.Thickness<=1,'Common: plain thin line, no extras')
check(not has('Uncommon','RarityBorder')and cards.Uncommon.AnimatedBorder.Color.G>cards.Uncommon.AnimatedBorder.Color.R,'Uncommon: green line, no extras')
check(has('Rare','RarityBorder.InnerLine.Line')and cards.Rare.AnimatedBorder.Color.B>cards.Rare.AnimatedBorder.Color.R,'Rare: blue double line')
check(has('Legendary','AnimatedBorder.BorderShine'),'Legendary: gold line with a shine gradient')
check(has('Mythic','RarityBorder.Glow.Line'),'Mythic: crimson line with a glow ring')
check(has('Secret','RarityBorder.InnerLine.Line.Shimmer')and cards.Secret.AnimatedBorder.Color.R<.1,'Secret: black line + white inner line with silver shimmer')
local sparkles=0;for _,c in ipairs(cards.Cosmic.RarityBorder:GetChildren())do if c.Name:find('^Sparkle')then sparkles+=1 end end
check(has('Cosmic','AnimatedBorder.BorderShine')and sparkles==6,'Cosmic: violet gradient line + 6 edge sparkles ('..sparkles..')')
local gems=0;for _,c in ipairs(cards.King.RarityBorder:GetChildren())do if c.Name:find('^CrownGem')then gems+=1 end end
check(gems==4 and has('King','RarityBorder.Glow.Line')and has('King','AnimatedBorder.BorderShine'),'King: gold line + 4 crown-gem corners + radiant glow')
-- Unknown rarity / tools read as Common; reapplying never stacks.
local tool=card('');check(tool:GetAttribute('BorderRarity')=='Common','no rarity -> Common border')
Theme.CardBorder(cards.King,'King');Theme.CardBorder(cards.King,'Cosmic');Theme.CardBorder(cards.King,'King')
local strokes,overlays=0,0;for _,c in ipairs(cards.King:GetChildren())do if c:IsA('UIStroke')then strokes+=1 end;if c.Name=='RarityBorder'then overlays+=1 end end
check(strokes==1 and overlays==1,'re-applying rarities never stacks strokes/overlays')
Theme.CardBorder(tool,'Mythic');Theme.CardBorder(tool,'Common');check(tool:FindFirstChild('RarityBorder')==nil and tool.AnimatedBorder:FindFirstChild('BorderShine')==nil,'downgrade removes extras')

-- 3. Budgets: only Legendary+ animate; visible only; capped; static under FastMode / ReducedMotion / low effects.
for _,r in ipairs({'Common','Uncommon','Rare'})do Theme.CardBorder(tool,r)end
check(Borders.Count()==5,'only Legendary, Mythic, Secret, Cosmic, King animate ('..Borders.Count()..')')
local many={};for i=1,60 do many[i]=card('Legendary')end
check(Borders.Tick()==Borders.MaxAnimated,'per-tick cap respected: '..Borders.Tick()..' <= '..Borders.MaxAnimated)
sheet.Enabled=false;check(Borders.Tick()==0,'hidden cards are not animated');sheet.Enabled=true
-- Clipped by a scrolling frame: off-screen cards are skipped.
local scroll=R.Instance.new('ScrollingFrame');scroll.AbsolutePosition=R.Vector2.new(0,0);scroll.AbsoluteSize=R.Vector2.new(200,200);scroll.Parent=sheet
for _,f in ipairs(many)do f.Parent=scroll;f.AbsolutePosition=R.Vector2.new(0,5000);f.AbsoluteSize=R.Vector2.new(104,104)end
for _,r in ipairs(ORDER)do cards[r].Parent=scroll;cards[r].AbsolutePosition=R.Vector2.new(0,0);cards[r].AbsoluteSize=R.Vector2.new(104,104)end
tool.Parent=scroll;tool.AbsolutePosition=R.Vector2.new(0,5000)
check(Borders.Tick()==5,'only the visible animated cards are updated ('..Borders.Tick()..')')
local g=cards.Legendary.AnimatedBorder.BorderShine;W.frames(30);local o1=g.Offset.X;W.frames(7);check(g.Offset.X~=o1,'Legendary shine sweeps on the scheduler')
local glow=cards.Mythic.RarityBorder.Glow.Line;local t1=glow.Transparency;W.frames(9);check(glow.Transparency~=t1,'Mythic glow pulses')
local function frozen(label)
 local before={};for _,r in ipairs(ORDER)do before[r]=signature(cards[r])..(cards[r].AnimatedBorder:FindFirstChild('BorderShine')and tostring(cards[r].AnimatedBorder.BorderShine.Offset and cards[r].AnimatedBorder.BorderShine.Offset.X)..tostring(cards[r].AnimatedBorder.BorderShine.Rotation)or'')end
 local gl=glow.Transparency;W.frames(40);check(Borders.Tick()==0,label..': no animated work')
 local same=gl==glow.Transparency;for _,r in ipairs(ORDER)do local s=cards[r].AnimatedBorder:FindFirstChild('BorderShine');if before[r]~=signature(cards[r])..(s and tostring(s.Offset and s.Offset.X)..tostring(s.Rotation)or'')then same=false end end
 check(same,label..': borders hold a static pose')
end
player:SetAttribute('FastMode',true);W.frames(10);frozen('FastMode');player:SetAttribute('FastMode',nil)
W.Gui.ReducedMotionEnabled=true;W.frames(10);frozen('ReducedMotion');W.Gui.ReducedMotionEnabled=false
player:SetAttribute('StudioPlantEffects','low');W.frames(10);frozen('low effects');player:SetAttribute('StudioPlantEffects',nil)
check(Borders.Tick()>0,'motion resumes when allowed')
sheet:Destroy();W.frames(3);check(Borders.Count()==0 and not Borders.Running(),'destroying cards stops the scheduler')

-- 4. Real UIs: inventory cards + hotbar slots, sell menu rows. No emblem instances; each card's border matches its rarity.
F.packAssets(W)
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
local char=R.new('Model');char.Name='Tester';char.Parent=W.workspace;player.Character=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
hum.EquipTool=function(_,t)for _,x in ipairs(char:GetChildren())do if x:IsA('Tool')then x.Parent=bag end end;t.Parent=char end
hum.UnequipTools=function()for _,x in ipairs(char:GetChildren())do if x:IsA('Tool')then x.Parent=bag end end end
player.CharacterAdded=R.signal()
F.shovel(W,bag)
local ids={'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed','CocoaSeed','IceberrySeed','FirePepperSeed','SnowdropSeed'}
local fruitOf={}
for i,r in ipairs(ORDER)do local t=F.fruit(W,bag,ids[i],1+i,'None',100*i);t:SetAttribute('Rarity',r);fruitOf[r]=t end
local scriptInst=R.new('LocalScript');scriptInst.Name='Hotbar'
local ok,err=pcall(W.load,'Hotbar',scriptInst);check(ok,'Hotbar loads: '..tostring(err))
W.frames(30)
local gui=pg.ChestToolHotbar;local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local slotsChecked=0
for i=1,10 do local s=gui.Dock['Slot'..i]
 for r,t in pairs(fruitOf)do if s.Visible and s.ItemName.Text==Names.Tool(t,Catalog)then slotsChecked+=1;check(s:GetAttribute('BorderRarity')==r,'hotbar slot '..i..' border = '..r..' (got '..tostring(s:GetAttribute('BorderRarity'))..')')end end
end
check(slotsChecked==8,'all 8 rarity fruits are on the hotbar ('..slotsChecked..')')
check(gui.Dock.Slot1:GetAttribute('BorderRarity')=='Common','shovel slot: plain Common border')
W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode.B,UserInputType=R.Enum.UserInputType.Keyboard},false);W.frames(30)
local panel=gui.Inventory;check(panel.Visible,'inventory open')
local seen={}
-- The grid is virtualized under the mock's default sizes, so walk it one rarity filter at a time.
for _,want in ipairs(ORDER)do
 panel.RarityOptions[want].Activated:Fire();W.frames(10)
 for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'then
  local r=c:GetAttribute('NameRarity')or'';if r==want then seen[r]=true end
  check(r==want and c:GetAttribute('BorderRarity')==r,'inventory card border = '..want..' (got '..tostring(c:GetAttribute('BorderRarity'))..')')
 end end
end
panel.RarityOptions.All.Activated:Fire();W.frames(10)
for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and(c:GetAttribute('NameRarity')or'')==''then check(c:GetAttribute('BorderRarity')=='Common','tool card: Common border')end end
local n=0;for _ in pairs(seen)do n+=1 end;check(n==8,'inventory shows a card for each rarity ('..n..')')
-- Selection swaps the main line for the white selection outline; the rarity extras stay.
local kingSlot;for i=1,10 do local s=gui.Dock['Slot'..i];if s:GetAttribute('BorderRarity')=='King'then kingSlot=s end end
if kingSlot then kingSlot:SetAttribute('Selected',true);check(kingSlot.AnimatedBorder.Enabled==false and kingSlot:FindFirstChild('RarityBorder')~=nil,'selected King slot: selection outline replaces the line, crown gems stay');kingSlot:SetAttribute('Selected',false)end
check(Borders.Tick()<=Borders.MaxAnimated,'inventory: animation within budget')
-- Sell menu (3D previews stubbed).
W.stub('HarvestViewport',{Attach=function()end})
local Menu=W.module('HarvestSellMenu');local host=R.Instance.new('ScreenGui');host.Parent=pg;local frame=R.Instance.new('Frame');frame.AbsoluteSize=R.Vector2.new(900,700);frame.Size=R.UDim2.fromOffset(900,700);frame.Parent=host
local menu=Menu.new(frame,function()end);local harvests={}
for i,r in ipairs(ORDER)do harvests[i]={InventoryId='h'..i,SeedId=ids[i],Rarity=r,SellValue=100*i,FruitScale=1,Count=1,Mutation='None',Weather='None',CashMultiplier=1}end
menu:Show({Harvests=harvests,CanSell=true});menu.List.AbsoluteSize=R.Vector2.new(860,8*214);menu:Render(true)
local rows=0
for _,row in ipairs(menu.List:GetChildren())do if row.Name=='Harvest'then rows+=1
 local r=menu.Data[row].Item.Rarity;check(row:GetAttribute('BorderRarity')==r,'sell row border = '..r)
 check(row:FindFirstChild('BrightOutline')==nil,'sell row has no flat outline under the rarity border')
 local word=row:FindFirstChild('RarityName');check(word and word.Text==r and word.Position.X.Offset==row:FindFirstChild('Name').Position.X.Offset,'sell row keeps the rarity name, aligned with the item name')
end end
check(rows==8,'sell menu rows for all 8 rarities ('..rows..')')
check(emblems(pg)==0,'no emblem instances anywhere in the built UIs ('..emblems(pg)..')')
check(Borders.Tick()<=Borders.MaxAnimated,'all UIs: animation within budget ('..Borders.Tick()..')')
print('warns',W.warns or 0);print(('%d checks, %d failures'):format(checks,fails))
