--!nocheck
-- R155 preview (not a test): the REAL Hotbar / Bag / discard popup on the Roblox mock, driven through R153's engine model (engine153.luau with the screen size of
-- the view), printed as SCENE lines (dump_tree153.luau) for render_gui153.mjs. VIEW = 'pc' (1280 x 720, mouse) or 'phone' (844 x 390, touch).
-- Item pictures: the game draws each item's 3D picture (a ViewportFrame the renderer can not draw); here each slot / card shows a stand-in emoji of its kind.
-- The last scenes show the item's ToolTip (review): a pack's odds, the pity lines and the Mech coat line, hovered (mouse), picked (phone) or just held (phone), with the
-- real pity bars above the hotbar.
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
-- the items: a shovel, three Apple Seeds (one stack), fruit, the bat, packs; more in the Bag
local emoji={}
local function fruit(seed,scale,icon,mutation)local t=F.fruit(W,nil,seed,scale,mutation or'None',700,1);t:SetAttribute('SourceCropId','plant-'..seed..scale);t.Parent=bag();emoji[t]=icon;return t end
local shovel=F.shovel(W,bag());emoji[shovel]='⛏'
local apples={};for i=1,3 do apples[i]=F.seed(W,bag(),'AppleSeed',1,'None');emoji[apples[i]]='🌱'end
local blue=fruit('BluebellSeed',1,'🫐')
local bat=F.bat(W,bag());emoji[bat]='🏏'
-- (the pack tooltips are what ChestService:_holdPack writes: the label, the lucky line, the odds, the Mech coat line, the pity rule)
local Mech=W.module('MechCatalog');local Pity=W.module('PackPity155');local Odds=W.module('OddsText85')
local function serverTip(label,lucky,seeds,coat)
 local rows={label};if lucky then rows[#rows+1]=Pity.LuckyLine end
 for _,sd in ipairs(seeds)do rows[#rows+1]=sd.Name..': '..Odds.Format(sd.Chance)end
 if coat then rows[#rows+1]=Mech.CoatLine()end
 rows[#rows+1]=Pity.Disclosure
 return table.concat(rows,'\n')
end
local forest=F.pack(W,bag(),1,'Pack01',1,'None');emoji[forest]='📦'
forest.ToolTip=serverTip(forest.Name,false,{{Name='Sunflower Seed',Chance=30},{Name='Daisy Seed',Chance=24},{Name='Bluebell Seed',Chance=18},{Name='Apple Seed',Chance=12},{Name='Clover Seed',Chance=9},{Name='Golden Acorn Seed',Chance=4},{Name='Moon Fern Seed',Chance=2.5},{Name='Dragon Fig Seed',Chance=.5}},false)
local desert=F.pack(W,bag(),8,'MechLimited',1,'Gold','Gold Limited Mech Pack');emoji[desert]='📦'
desert.ToolTip=serverTip('Gold Limited Mech Pack',true,Mech.Seeds,true)
local bagMech=F.pack(W,bag(),8,'MechLimited',1,'Diamond','Diamond Limited Mech Pack');emoji[bagMech]='📦'
bagMech.ToolTip=serverTip('Diamond Limited Mech Pack',false,Mech.Seeds,true)
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
 local roots={};for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')and g.Enabled~=false and(g.Name=='ChestToolHotbar'or g.Name=='DiscardConfirm'or g.Name=='PackPityBars155')then roots[#roots+1]=g end end
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
if not PHONE then
 -- 1. drag from the Bag onto an empty slot (mid-drag: the item under the pointer, the slot it would land on lit green)
 openBag();local card=cardOf(kiwi);local target=slot(9)
 local a,b=X.center(card),X.center(target);X.down('mouse',a)
 for i=1,5 do X.move(R.Vector2.new(a.X+(b.X-a.X)*i/6,a.Y+(b.Y-a.Y)*i/6));X.frames(1)end;X.move(b);X.frames(1)
 scene('pc_drag','Drag a Bag card onto a hotbar slot (every slot it can go to is outlined, the one under the pointer lights up; a taken slot = swap, that item goes to the Bag)')
 X.up(b);X.frames(3)
 -- 2. a hotbar item dragged into the Bag: its slot stays blank
 X.drag('mouse',slotOf(blue),panel.Items);X.frames(3)
 scene('pc_to_bag','Hotbar -> Bag: the item is a Bag card now and slot 3 stays BLANK (new items skip it)')
 -- 3. search
 panel.Search.Text='mango';X.frames(3)
 scene('pc_search','Search: the Bag filters, hotbar slots that do not match dim')
 panel.Search.Text='';X.frames(3)
 -- 4. the full state
 player:SetAttribute('HeldItemCount',200);X.frames(2)
 scene('pc_full','200/200 FULL: the count turns red, FULL on the Bag button; every way of getting an item says "BAG FULL - MAKE ROOM IN UR BAG FIRST"')
 player:SetAttribute('HeldItemCount',143);X.frames(2)
 -- 5. discard a stack: drop it on the Trash
 X.drag('mouse',slotOf(apples[1]),panel.BagBar.Trash);X.frames(2)
 local ui=Dialog.UI();X.tap('mouse',ui.Row.More);X.frames(1)
 scene('pc_discard','Discard: drop it on the Trash; a stack picks 1, a number or All; "u sure? it\'s gone forever"; the button says "hold to discard"')
 X.tap('mouse',ui.Keep);X.frames(2)
 -- 6. every item: hold to discard (a plain one here)
 X.drag('mouse',slotOf(kiwi)or cardOf(kiwi),panel.BagBar.Trash);X.frames(2)
 local p=X.center(ui.Confirm);X.down('mouse',p);X.wait(.6)
 scene('pc_hold','Every item: HOLD the button ~1 s (its bar fills; a tap or letting go early throws nothing away)')
 X.up(p);X.frames(2);X.tap('mouse',ui.Keep);X.frames(2)
 -- 7. a fully blank hotbar
 for i=1,10 do local s=slot(i);if s.ItemName.Text~=''then X.drag('mouse',s,panel.Items);X.frames(2)end end
 closeBag();X.frames(3)
 scene('pc_blank','A fully blank hotbar: everything in the Bag; new items go to the Bag until u put something on it')
 openBag();player:SetAttribute('HeldItemCount',143);X.frames(2)
 scene('pc_count','The Bag with everything in it: 143/200 (amber from 180)')
  -- 8. the item's ToolTip (review): hover a hotbar slot, then a Bag card
  closeBag()
  openBag()
  local function tidy()for i=1,10 do local s=slot(i);if s.ItemName.Text~=''then X.drag('mouse',s,panel.Items);X.frames(2)end end end
  tidy();closeBag()
  local want={shovel,apples[1],blue,bat,desert,forest,mango,plum,orange}
  openBag();for k,t in ipairs(want)do local c=cardOf(t);if c then X.drag('mouse',c,slot(k));X.frames(2);openBag()end end;closeBag();X.frames(3)
  local Bars=W.module('PityBars155').Start(player)
  player:SetAttribute('PackPityNormal',4);player:SetAttribute('PackPityEvent',9);X.wait(2)
  local s6=slotOf(desert);s6.MouseEnter:Fire();X.frames(3)
  scene('pc_tooltip','Hover a hotbar slot: the item\'s ToolTip like Roblox\'s backpack: the Mech pack\'s odds, the coat line, the pity rule (above the pity bars, never over them)')
  s6.MouseLeave:Fire();X.frames(2)
  openBag();local mc=cardOf(bagMech);if not mc then panel.Search.Text='diamond';X.frames(3);mc=cardOf(bagMech)end
  if mc then mc.MouseEnter:Fire();X.frames(3)
   scene('pc_tooltip_card','... and a Bag card: the paid-random odds of a Mech pack are one hover away');mc.MouseLeave:Fire()end
  panel.Search.Text='';X.frames(2);closeBag()
else
 -- phone: tap-tap
 local s=slotOf(blue);local p=X.center(s);X.down('touch',p);X.wait(.55);X.up(p);X.frames(3)
 scene('phone_picked','Phone tap-tap: hold an item and let go: it is picked (the Bag opens, every slot it can go to is outlined, the bar says what to do)')
 X.tap('touch',slot(5));X.frames(3)
 scene('phone_placed','... then tap a slot: it is there (a taken slot swaps; "To Bag" or a Bag card puts it in the Bag, the Trash throws it away)')
 -- hold and drag with clear drop targets
 openBag();local card=cardOf(mango);local a=X.center(card);local b=X.center(slot(4));X.down('touch',a);X.wait(.5)
 for i=1,5 do X.move(R.Vector2.new(a.X+(b.X-a.X)*i/6,a.Y+(b.Y-a.Y)*i/6));X.frames(1)end;X.move(b);X.frames(1)
 scene('phone_drag','Phone hold-and-drag: hold 0.4 s, drag; every slot it can go to is outlined, the one under the finger lights up')
 X.up(b);X.frames(3);closeBag()
 for i=1,10 do local s2=slot(i);if s2.Visible and s2.ItemName.Text~=''then openBag();X.drag('touch',s2,open,.5);X.frames(2)end end
 closeBag();X.frames(3)
 scene('phone_blank','Phone: a blank hotbar (everything in the Bag)')
 -- the item's ToolTip (review): a picked pack, a pack just held
 openBag();for k,t in ipairs({shovel,apples[1],blue,bat,desert})do local c=cardOf(t);if c then X.drag('touch',c,slot(k),.5);X.frames(2);openBag()end end;closeBag();X.frames(3)
 local Bars=W.module('PityBars155').Start(player)
 player:SetAttribute('PackPityNormal',4);player:SetAttribute('PackPityEvent',9);X.wait(2)
 local d=slotOf(desert)
 if d then
  X.tap('touch',d);X.wait(.6)
  scene('phone_tooltip_held','Phone: tap a pack\'s slot to hold it and its odds show for a few seconds (above the pity bars and its name)')
  hum:UnequipTools();X.wait(5.6)
  local p2=X.center(slotOf(desert));X.down('touch',p2);X.wait(.55);X.up(p2);X.frames(4)
  scene('phone_tooltip_pick','Phone tap-tap: hold a pack and let go (picked): its ToolTip shows for as long as it is picked, clear of the Bag bar\'s buttons')
  X.tap('touch',panel.BagBar.PickBar.PickCancel);X.frames(2)
 end
end
