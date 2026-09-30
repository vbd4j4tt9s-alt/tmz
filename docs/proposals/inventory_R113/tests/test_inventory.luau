--!nocheck
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
F.packAssets(W)
W.Run.IsStudio=function()return true end
-- Approved plant meshes are baked by the server in the real game; hand the client ready parts.
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
local char=R.new('Model');char.Name='Tester';char.Parent=W.workspace;player.Character=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
hum.EquipTool=function(_,tool)for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=bag end end;tool.Parent=char end
hum.UnequipTools=function()for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=bag end end end
player.CharacterAdded=R.signal()
-- Inventory of every kind, including stacks and 120 unique fruit for scrolling.
local shovel=F.shovel(W,bag);local bat=F.bat(W,bag);local loot=F.loot(W,bag)
local packs={};for i=1,3 do packs[i]=F.pack(W,bag,1,'Pack01',1,'None')end
F.pack(W,bag,2,'Pack05',2.5,'Gold');F.pack(W,bag,7,'EclipseReliquary',1,'None','Void Pack')
local seeds={F.seed(W,bag,'SunflowerSeed',1,'None','Watermelon Seed'),F.seed(W,bag,'SunflowerSeed',1,'None','Watermelon Seed'),F.seed(W,bag,'BluebellSeed',2,'Gold','Gold Blueberry Seed')}
local melons={};for i=1,3 do melons[i]=F.fruit(W,bag,'SunflowerSeed',1,'None',500)end
F.fruit(W,bag,'AppleSeed',2.5,'Gold',9000);F.fruit(W,bag,'HoloMelonSeed',1,'None',700,1,'None','Holo Melon')
local ids={'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed','CocoaSeed','IceberrySeed','FirePepperSeed','SnowdropSeed'}
for i=1,120 do F.fruit(W,bag,ids[i%#ids+1],1+i*.5,i%9==0 and'Gold'or'None',1000+i)end
local total=0;for _,t in ipairs(bag:GetChildren())do if t:IsA('Tool')then total+=1 end end
-- Layout emulation: absolute rects from UDim2 + AnchorPoint + canvas offsets.
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph,cx,cy)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
  local x=px+p.X.Scale*pw+p.X.Offset-a.X*w-cx;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h-cy
  set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
  local ox,oy=0,0;if c._class=='ScrollingFrame'then local cp=c._props.CanvasPosition or R.Vector2.new(0,0);ox,oy=cp.X,cp.Y end
  lay(c,x,y,w,h,ox,oy)
 end end
end
local function frames(n)for _=1,n do local gui=pg:FindFirstChild('ChestToolHotbar');if gui then lay(gui,0,0,1280,720,0,0)end;W.frames(1)end end
local key=function(code)W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[code],UserInputType=R.Enum.UserInputType.Keyboard},false)end
-- Run the real script.
local scriptInst=R.new('LocalScript');scriptInst.Name='Hotbar'
local ok,err=pcall(W.load,'Hotbar',scriptInst);check(ok,'Hotbar loads: '..tostring(err))
frames(30)
local P=W.module('ItemPictures');local Weight=W.module('ItemWeight');local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local gui=pg.ChestToolHotbar;local dock=gui.Dock;local panel=gui.Inventory;local scroll=panel.Items
-- Hotbar slots.
local function slotFor(tool)for i=1,10 do local s=dock['Slot'..i];if s.Visible and s.ItemName.Text==Names.Tool(tool,Catalog)then return s,i end end end
check(dock.Slot1.ItemName.Text=='Shovel','slot 1 is the shovel')
for i=1,10 do local s=dock['Slot'..i];check(s:FindFirstChild('Picture')and s:FindFirstChild('ItemName')and s:FindFirstChild('ItemWeight')and s:FindFirstChild('Count')and s:FindFirstChild('Number'),'slot '..i..' parts')end
local packSlot=slotFor(packs[1]);check(packSlot~=nil,'tutorial pointer finds the pack slot by exact ItemName text')
check(packSlot and packSlot.Count.Visible and packSlot.Count.Text=='x3','pack stack shows x3')
check(packSlot and packSlot.ItemWeight.Text=='1kg','pack slot weight 1kg: '..tostring(packSlot and packSlot.ItemWeight.Text))
local melonSlot=slotFor(melons[1]);check(melonSlot and melonSlot.Count.Text=='x3','watermelon fruit stack x3')
check(melonSlot and melonSlot.ItemWeight.Text==Weight.ToolText(melons[1]),'fruit slot weight')
local batSlot=slotFor(bat);check(batSlot~=nil and batSlot.ItemWeight.Text=='','bat slot, no weight')
local views=0;for i=1,10 do if dock['Slot'..i].Picture:FindFirstChild('ItemViewport')then views+=1 end end
check(views==10,'all 10 hotbar slots render 3D pictures: '..views)
check(batSlot and batSlot.Picture:FindFirstChild('ItemViewport')~=nil,'bat has a 3D picture in its slot')
-- Open inventory.
key('B');frames(60)
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Inventory','B opens inventory')
local function cards()local out={};for _,c in ipairs(scroll:GetChildren())do if c.Name=='Item'then out[#out+1]=c end end;return out end
local list=cards();check(#list>0 and #list<80,'grid is virtualized: '..#list..' of '..total..' tools')
local withKg,picture=0,0
for _,c in ipairs(list)do if c.ItemName:GetAttribute('FullText'):find('kg%)$')then withKg+=1 end;if c.Picture:FindFirstChild('ItemViewport')then picture+=1 end end
check(withKg>=#list-3,'cards show "Name (Xkg)": '..withKg..'/'..#list)
local s=P.Stats();check(s.Views>10 and s.Views<=P.MaxViews+P.MaxWarm,'views within budget: '..s.Views);check(s.Parts<=P.MaxParts,'parts within budget '..s.Parts)
-- R113: category cards are outside the sheet and show 3D pictures of a pack, seed, fruit and the shovel.
for _,name in ipairs({'All','Seeds','Fruit','Tools'})do
 local b=panel.Categories[name];local a,z=b.AbsolutePosition,b.AbsolutePosition+b.AbsoluteSize;local p,q=panel.AbsolutePosition,panel.AbsolutePosition+panel.AbsoluteSize
 check(z.X<=p.X or a.X>=q.X or z.Y<=p.Y or a.Y>=q.Y,name..' tab sits outside the inventory sheet')
 check(b.Picture:FindFirstChild('ItemViewport')~=nil,name..' tab shows a 3D picture')
end
check(panel.Categories.All:GetAttribute('Selected')==true,'All tab selected')
local stackCard;for _,c in ipairs(list)do if c.Count.Visible then stackCard=c end end;check(stackCard~=nil,'a stack card shows a count badge')
-- Filters.
local function names()local t={};for _,c in ipairs(cards())do t[#t+1]=c.ItemName:GetAttribute('FullText')end;return t end
panel.Categories.Tools.Activated:Fire();frames(20)
local tl=names();check(#tl==3,'Tools filter: shovel, bat, loot ('..#tl..')')
local batCard;for _,c in ipairs(cards())do if c.ItemName:GetAttribute('FullText')=='Bat'then batCard=c end end
check(batCard and batCard.Picture:FindFirstChild('ItemViewport')~=nil,'bat card has a 3D picture')
panel.Categories.Seeds.Activated:Fire();frames(20);check(#cards()==5,'Seeds filter: 3 pack stacks + 2 seed stacks, got '..#cards())
panel.Categories.Fruit.Activated:Fire();frames(20);check(#cards()>10,'Fruit filter')
panel.Categories.All.Activated:Fire();frames(5)
panel.Search.Text='holo';frames(20);check(#cards()==1,'search "holo" -> 1 card, got '..#cards())
panel.Search.Text='';frames(5)
panel.RarityOptions.Rare.Activated:Fire();frames(10);for _,c in ipairs(cards())do check(c:GetAttribute('NameRarity')=='Rare','rarity filter Rare')end
panel.RarityOptions.All.Activated:Fire();frames(10)
-- Scroll to the bottom and back; cells and pictures stay bounded.
local peak=0
local fallback=0
local function blank()local n=0;local a,z=scroll.AbsolutePosition,scroll.AbsolutePosition+scroll.AbsoluteSize
 for _,c in ipairs(cards())do local p,q=c.AbsolutePosition,c.AbsolutePosition+c.AbsoluteSize
  if q.Y>a.Y and p.Y<z.Y and not c.Picture:FindFirstChild('ItemViewport')then n+=1 end end;return n end
for step=0,40 do scroll.CanvasPosition=R.Vector2.new(0,step*120);frames(1);fallback+=blank();frames(3);peak=math.max(peak,#cards(),P.Stats().Views)end
for step=40,0,-1 do scroll.CanvasPosition=R.Vector2.new(0,step*120);frames(1);fallback+=blank()end
print('fast scroll fallback card-frames',fallback);check(fallback==0,'fast scroll (120 px/frame) never shows a flat icon: '..fallback)
check(peak<100,'cells/views bounded while scrolling: '..peak)
local st=P.Stats();check(st.Templates<=P.MaxTemplates,'templates bounded '..st.Templates);check(st.Records<=#cards()+10+4+32,'records bounded (cards, slots, tabs, recycled cards) '..st.Records)
scroll.CanvasPosition=R.Vector2.new(0,0);frames(30)
-- Equip from a card; panel closes, slot selected.
local melonCard;for _,c in ipairs(cards())do if c:GetAttribute('InventoryKey'):find('^stack|Fruit')and c.ItemName:GetAttribute('FullText'):find('^Watermelon')and c.Count.Visible then melonCard=c end end
check(melonCard~=nil,'watermelon stack card found')
if melonCard then melonCard.Activated:Fire();frames(10)end
local held=char:FindFirstChildOfClass('Tool');check(held and held:GetAttribute('SeedId')=='SunflowerSeed','card click equips a watermelon')
check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'equip closes panel')
melonSlot=slotFor(melons[1]);check(melonSlot and melonSlot:GetAttribute('Selected')==true,'stack slot selected while one copy is equipped')
check(gui.Dock.SelectedName:GetAttribute('FullText')==Names.Tool(held,Catalog)..' ('..Weight.ToolText(held)..')','selected name shows weight')
if melonSlot then melonSlot.Activated:Fire();frames(5)end;check(char:FindFirstChildOfClass('Tool')==nil,'clicking the slot again unequips')
key('One');frames(5);check(shovel.Parent==char,'key 1 equips the shovel')
key('Two');frames(5);check(char:FindFirstChildOfClass('Tool')~=shovel,'key 2 swaps tool')
hum:UnequipTools();frames(5)
-- Consuming one copy of a stack keeps the slot with x2.
packs[1]:Destroy();frames(5);packSlot=slotFor(packs[2]);check(packSlot and packSlot.Count.Text=='x2','stack shrinks to x2')
-- Drag a card onto slot 5.
key('B');frames(20)
local lootCard;panel.Categories.Tools.Activated:Fire();frames(10);for _,c in ipairs(cards())do if c.ItemName:GetAttribute('FullText')=='Golden Idol'then lootCard=c end end
local target=dock.Slot5;local tp=R.Vector2.new(target.AbsolutePosition.X+target.AbsoluteSize.X*.5,target.AbsolutePosition.Y+target.AbsoluteSize.Y*.5)
lootCard.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,Position=R.Vector3.new(lootCard.AbsolutePosition.X+5,lootCard.AbsolutePosition.Y+5,0)})
W.UIS.InputChanged:Fire({UserInputType=R.Enum.UserInputType.MouseMovement,Position=R.Vector3.new(tp.X,tp.Y,0)})
W.UIS.InputEnded:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,Position=R.Vector3.new(tp.X,tp.Y,0)});frames(5)
check(dock.Slot5.ItemName.Text=='Golden Idol','drag places item on slot 5')
panel.Categories.All.Activated:Fire();frames(5)
-- R113b: the automatic frame-rate mode (FastMode) keeps the pictures; only the player's own Low setting flattens them.
player:SetAttribute('FastMode',true);frames(30);check(P.Stats().Views>10,'auto fast mode keeps pictures ('..P.Stats().Views..')')
player:SetAttribute('FastMode',false);player:SetAttribute('QualityChoice','Low');frames(30)
check(P.Stats().Views==0,'low graphics: no viewports ('..P.Stats().Views..')')
local flatShown=0;for i=1,10 do local p=dock['Slot'..i].Picture;if p:FindFirstChild('FlatIcon')and p.FlatIcon.Visible then flatShown+=1 end end
check(flatShown==10,'low graphics: flat icons in every slot '..flatShown)
player:SetAttribute('QualityChoice','Auto');frames(60);check(P.Stats().Views>10,'pictures come back')
-- Close; hidden pictures are released after the grace period.
key('Escape');frames(20);check(not panel.Visible,'Esc closes');frames(60*4)
check(P.Stats().Views<=10,'hidden grid releases views: '..P.Stats().Views);check(P.Stats().Spare<=P.MaxSpare,'parked views bounded '..P.Stats().Spare)
-- Open/close cycles do not grow live instances.
local function live()local n=0;for _,d in ipairs(pg:GetDescendants())do local v=d:FindFirstAncestor('ItemViewport');if not v then n+=1 end end;return n end
key('B');frames(30);key('B');frames(30);local base=live()
for _=1,10 do key('B');frames(15);scroll.CanvasPosition=R.Vector2.new(0,600);frames(10);scroll.CanvasPosition=R.Vector2.new(0,0);frames(10);key('B');frames(15)end
local function classes()local t={};for _,d in ipairs(pg:GetDescendants())do t[d._class]=(t[d._class]or 0)+1 end;return t end
local c2=classes();print('views',P.Stats().Views,'cards',#cards())
for _=1,3 do key('B');frames(15);scroll.CanvasPosition=R.Vector2.new(0,600);frames(10);scroll.CanvasPosition=R.Vector2.new(0,0);frames(10);key('B');frames(15)end
local c3=classes();for k,v in pairs(c3)do if v~=(c2[k]or 0)then print('delta',k,c2[k],v)end end;print('views',P.Stats().Views,'cards',#cards())
check(live()<=base+5,'no GUI instance growth over 13 cycles (viewport contents excluded): '..base..' -> '..live());check(P.Stats().Views<=P.MaxViews+P.MaxWarm,'views still capped')
-- No CollectionService tags leak into the GUI.
local tagged=0;for _,d in ipairs(pg:GetDescendants())do if d._tags and next(d._tags)then tagged+=1 end end;check(tagged==0,'no tagged instances in GUI')
-- Teardown.
scriptInst.Destroying:Fire();frames(5)
check(pg:FindFirstChild('ChestToolHotbar')==nil,'gui removed');local sf=P.Stats();P.Reset();sf=P.Stats();check(sf.Records==0 and sf.Views==0 and sf.Spare==0,'picture records cleaned: '..sf.Records)
frames(5);check(not P.Stats().Connected,'heartbeat disconnected when idle')
print('warns',W.warns or 0);print(('%d checks, %d failures'):format(checks,fails))
