--!nocheck
-- R156 preview (not a test): the REAL Hotbar / Bag / discard popup of a src tree (the checkout's, or the scratch copy with the Option 2 look applied) on the Roblox mock,
-- driven through R153's engine model (engine153.luau patched for the view's screen size), printed as SCENE lines (dump_tree153.luau) for render_gui155.mjs.
-- VIEW = 'pc' (1280 x 720, mouse) or 'phone' (844 x 390, touch, landscape). A copy of R155's inventory_scenes155.luau with the scenes of the Bag look change:
--   rest | an item dragged over the sheet | an item dragged over the Discard bin | search text + the rarity dropdown | the discard popup | (phone) an item picked (tap-tap bar)
-- Item pictures: the game draws each item's 3D picture (a ViewportFrame the renderer can not draw); here each slot / card shows a stand-in emoji of its kind.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local dump=require('./dump_tree153')
F.packAssets(W);W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
E.recorder()
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class:find('Button')then o.MouseButton2Click=R.signal()end;return o end end
W.service('TextService').GetTextSize=function(_,text,size,_,bounds)
 local per=math.max(1,math.floor(bounds.X/(size*.56)));local lines,widest=0,0
 for l in(text..'\n'):gmatch('(.-)\n')do lines+=math.max(1,math.ceil(#l/per));widest=math.max(widest,#l)end
 return R.Vector2.new(math.min(bounds.X,widest*size*.56),lines*size*1.2)
end
local PHONE=VIEW=='phone'
local SW,SH=PHONE and 844 or 1280,PHONE and 390 or 720
W.UIS.TouchEnabled=PHONE;W.UIS.MouseEnabled=not PHONE;W.workspace.CurrentCamera.ViewportSize=R.Vector2.new(SW,SH)
E.player('Tester')
local player,pg=E.Player,E.pg
local hum=E.hum
local X=require('./engine155p')(W,E,F,{Variant='began',Order='release first',Handoff='empty',Screen=R.Vector2.new(SW,SH),Inset=PHONE and 0 or 58})
local bag=function()return player:FindFirstChildOfClass('Backpack')end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local layoutRemote=R.new('RemoteEvent');layoutRemote.Name='HotbarLayout155';layoutRemote.Parent=remotes;layoutRemote.FireServer=function()end
-- the items: the hotbar starts with a shovel, a stack of Apple Seeds, a Watermelon Seed (the one the owner dragged), a fruit, the bat and a pack; the rest is in the Bag
local emoji={}
local function fruit(seed,scale,icon,mutation)local t=F.fruit(W,nil,seed,scale,mutation or'None',700,1);t:SetAttribute('SourceCropId','plant-'..seed..scale);t.Parent=bag();emoji[t]=icon;return t end
local shovel=F.shovel(W,bag());emoji[shovel]='⛏'
local apples={};for i=1,3 do apples[i]=F.seed(W,bag(),'AppleSeed',1,'None');emoji[apples[i]]='🌱'end
local melon=F.seed(W,bag(),'SunflowerSeed',1,'None');emoji[melon]='🌱' -- (the catalog calls SunflowerSeed "Watermelon")
local blue=fruit('BluebellSeed',1,'🫐')
local bat=F.bat(W,bag());emoji[bat]='🏏'
local forest=F.pack(W,bag(),1,'Pack01',1,'None');emoji[forest]='📦'
local desert=F.pack(W,bag(),8,'MechLimited',1,'Gold','Gold Limited Mech Pack');emoji[desert]='📦'
local bagMech=F.pack(W,bag(),8,'MechLimited',1,'Diamond','Diamond Limited Mech Pack');emoji[bagMech]='📦'
local mango=fruit('MangoSeed',1.2,'🥭');local plum=fruit('PlumSeed',1.1,'🍑');local orange=fruit('OrangeSeed',1,'🍊')
local lime=fruit('LimeSeed',1.3,'🍋');local fig=fruit('FigSeed',1,'🍇');local kiwi=fruit('KiwiSeed',1.1,'🥝')
local straw=F.seed(W,bag(),'CloverSeed',1,'None');emoji[straw]='🌱'
local gold=F.seed(W,bag(),'MangoSeed',1,'Gold');gold:SetAttribute('Rarity','Legendary');emoji[gold]='🌟'
local sc=R.new('LocalScript');sc.Name='Hotbar';assert(pcall(W.load,'Hotbar',sc))
X.frames(30)
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog');local Inv=W.module('InventoryPanel155');local Dialog=W.module('DiscardDialog155')
local gui=pg.ChestToolHotbar;local dock=gui.Dock;local panel=gui.Inventory;local open=dock.OpenInventory
local function slot(i)return dock['Slot'..i]end
local function nameOf(t)return Names.Tool(t,Catalog)end
local function flat(text)return(text:gsub('%s+',' '))end -- (a long name wraps on a card: "Gold Limited Mech\nPack (3kg)")
local function toolNamed(text)if text==''then return nil end;text=flat(text);for t in pairs(emoji)do if t.Parent and text:sub(1,#nameOf(t))==nameOf(t)then return t end end end
local function slotOf(t)for i=1,10 do local s=slot(i);if s.Visible and s.ItemName.Text==nameOf(t)then return s,i end end end
local function cardOf(t)for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible and flat(c.ItemName.Text):sub(1,#nameOf(t))==nameOf(t)then return c end end end
-- stand-in pictures
local function standIn(holder,t)
 if not holder then return end
 local l=holder:FindFirstChild('StandIn')
 if not t then if l then l.Visible=false end;return end
 if not l then l=R.Instance.new('TextLabel');l.Name='StandIn';l.BackgroundTransparency=1;l.Size=R.UDim2.fromScale(1,1);l.TextScaled=true;l.Font=R.Enum.Font.FredokaOne;l.ZIndex=2;l.Parent=holder
  local fit=R.Instance.new('UITextSizeConstraint');fit.MaxTextSize=64;fit.MinTextSize=8;fit.Parent=l end
 l.Text=emoji[t]or'❔';l.Visible=true;l.TextColor3=R.Color3.new(1,1,1)
end
local function icons()
 for i=1,10 do local s=slot(i);standIn(s:FindFirstChild('Picture'),toolNamed(s.ItemName.Text))end
 for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then standIn(c:FindFirstChild('Picture'),toolNamed(c.ItemName.Text))end end
 local g=gui:FindFirstChild('DragGhost');if g and g.Visible then standIn(g:FindFirstChild('Picture'),toolNamed(g.ItemName.Text))end
 local ui=Dialog.UI();if ui and ui.Gui.Enabled then standIn(ui.Picture,toolNamed(ui.Name.Text))end
end
local function scene(name,caption)
 X.layout();icons()
 -- (the renderer's approximations of two engine defaults: a ScrollingFrame clips its cards; a Contextual UIStroke outlines text only, so an empty label shows nothing)
 panel.Items.ClipsDescendants=true
 for _,l in ipairs({dock.SelectedName,dock.SelectedTraits})do local st=l:FindFirstChild('RarityOutline');if st then st.Enabled=l.Text~=''end end
 local roots={};for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')and g.Enabled~=false and(g.Name=='ChestToolHotbar'or g.Name=='DiscardConfirm')then roots[#roots+1]=g end end
 table.sort(roots,function(a,b)return(a.DisplayOrder or 0)<(b.DisplayOrder or 0)end)
 local kids={};for _,g in ipairs(roots)do for _,c in ipairs(g:GetChildren())do kids[#kids+1]=c end end
 print(('SCENE %s 0 0 %d %d 1 %s'):format(name,SW,SH,dump({GetChildren=function()return kids end},SW,SH)))
 print(('CAPTION %s %s'):format(name,caption))
end
local function openBag()if not panel.Visible then X.tap(PHONE and'touch'or'mouse',open);X.frames(5)end end
local function closeBag()if panel.Visible then X.tap(PHONE and'touch'or'mouse',panel.Close);X.frames(5)end end
player:SetAttribute('HeldItemCap',200);player:SetAttribute('HeldItemCount',143)
X.wait(10) -- (the join ends: new items are placed as new)
local kind=PHONE and'touch'or'mouse'
local function hold()if PHONE then X.wait(.5)end end -- (a phone lifts an item after a 0.4 s hold)
local FAR=R.Vector2.new(6,6) -- (a point over neither the Bag nor the hotbar: letting go there changes nothing)
-- lift `t` from its hotbar slot and carry it to the point b; the press stays down: scene() then release()
local function carry(t,b)
 local from=select(1,slotOf(t));local a=X.center(from)
 X.down(kind,a);hold()
 for i=1,5 do X.move(R.Vector2.new(a.X+(b.X-a.X)*i/6,a.Y+(b.Y-a.Y)*i/6));X.frames(1)end;X.move(b);X.frames(2)
end
local function release()X.up(FAR);X.frames(3)end
-- the hotbar keeps its first six items; the rest of the 10 slots goes to the Bag, so the Bag lists a grid of cards
openBag()
for i=10,7,-1 do local s=slot(i);if s.ItemName.Text~=''then X.drag(kind,s,panel.Items,PHONE and .5 or nil);X.frames(2);openBag()end end
X.frames(3)
local where=PHONE and'the landscape phone (844x390, touch)'or'the PC (1280x720, mouse)'
-- 1. at rest
scene(VIEW..'_rest','The Bag at rest, '..where)
-- 2. a hotbar item dragged over the sheet (the owner's Watermelon Seed): the sheet is the drop target
do
 local sheet=R.Vector2.new(panel.AbsolutePosition.X+panel.AbsoluteSize.X*.55,panel.AbsolutePosition.Y+panel.AbsoluteSize.Y*.45)
 carry(melon,sheet)
 scene(VIEW..'_drag','A hotbar item (Watermelon Seed) dragged over the sheet: the sheet is the drop target')
 release()
 assert(slotOf(melon),'the dragged item stayed on its slot')
end
-- 3. the same item over the Discard bin
do
 local tr=panel.BagBar.Trash;carry(melon,R.Vector2.new(tr.AbsolutePosition.X+tr.AbsoluteSize.X+3,tr.AbsolutePosition.Y+tr.AbsoluteSize.Y/2)) -- (at the bin's right edge: the item under the pointer hides less of the bin and not the count)
 scene(VIEW..'_trash','The same item over the Discard bin: the bin is the target (red)')
 release()
 assert(slotOf(melon),'the dragged item stayed on its slot')
end
-- 4. search text + the rarity dropdown
do
 panel.Search.Text='seed';X.frames(3)
 X.tap(kind,panel.RarityFilter);X.frames(3)
 assert(panel.RarityOptions.Visible,'the rarity dropdown is open')
 scene(VIEW..'_search','Search ("seed") and the rarity dropdown open')
 X.tap(kind,panel.RarityFilter);X.frames(3);panel.Search.Text='';X.frames(3)
end
-- 5. the discard popup (a stack: 1 / a number / All)
do
 X.drag(kind,slotOf(apples[1]),panel.BagBar.Trash,PHONE and .5 or nil);X.frames(2)
 local ui=Dialog.UI();assert(ui and ui.Gui.Enabled,'the discard popup is open')
 X.tap(kind,ui.Row.More);X.frames(1)
 scene(VIEW..'_popup','The discard popup (a stack of 3: pick how many, then hold Discard)')
 X.tap(kind,ui.Keep);X.frames(2)
end
-- 6. (phone, where the Bag is tap-tap) an item picked: its bar replaces the count; (pc: the same bar, shown once)
if PHONE then
 local s=slotOf(blue);local p=X.center(s);X.down('touch',p);X.wait(.55);X.up(p);X.frames(3)
 scene(VIEW..'_picked','An item picked (tap-tap): the bar says what to do, every slot it can go to is outlined')
 X.tap('touch',panel.BagBar.PickBar.PickCancel);X.frames(2)
end
