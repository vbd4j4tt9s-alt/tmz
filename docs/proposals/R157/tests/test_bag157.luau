--!nocheck
-- R157 (owner: "dont make this green and remove that text saying click to hold and so on"; Option 2 of docs/proposals/R156/bag_look.md: no green at all). The REAL Hotbar + InventoryPanel155 +
-- DiscardDialog155 through R153's engine model (engine153 with this view's screen), in VIEW = 'pc' (1280 x 720, a mouse), 'phone' (844 x 390, touch) or 'portrait' (390 x 844, touch: the only
-- sheet that ever showed the phone hint):
--  1. no hint line   - the Bag has no `Hint` label, no text on it tells you how to use it, the bottom bar is the count and Discard (and the pick bar while an item is picked); the count stays
--                      where it was, 8 px left of Discard
--  2. the new colours - sheet, header band / rule / rim, search box, count, cards, tabs (selected and not), rarity button and dropdown, Hold / To Bag / x, the drag ghost, the discard popup (panel, rim,
--                      picture box, amount buttons, count box, Keep it); the Discard bin and the popup's Discard stay red
--  3. the lit colour - the drop highlight (sheet, a slot, the Bag button) is the light rim: #EAF0FF, a 2 px rim and a faint brighten (not the .55 flood and the 3 px rim); the slot outlines, the picked
--                      ring and the "Moving ..." text are #EAF0FF; the Discard bin's highlight is red
--  4. no lime        - after every state (rest, a drag over the sheet / a slot / the Bag button / the bin, search + dropdown, picked, the popup) no Color3 property on the Hotbar GUI or the popup is #93FF45
--                      (Theme.Colors.Mint), nor one of the old green panel colours, even hidden ones
--  5. nothing shared changed - GardenTheme's colours and GardenMenuStyle.Panel (every other menu's green trim, header band, rule) are as they were
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
VIEW=VIEW or'pc'
local PHONE=VIEW~='pc'
local SW,SH=VIEW=='pc'and 1280 or VIEW=='phone'and 844 or 390,VIEW=='pc'and 720 or VIEW=='phone'and 390 or 844
F.packAssets(W);W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
E.recorder()
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class:find('Button')then o.MouseButton2Click=R.signal()end;return o end end
W.service('TextService').GetTextSize=function(_,text,size,_,bounds)
 local per=math.max(1,math.floor(bounds.X/(size*.5)));local lines,widest=0,0
 for l in(text..'\n'):gmatch('(.-)\n')do lines+=math.max(1,math.ceil(#l/per));widest=math.max(widest,#l)end
 return R.Vector2.new(math.min(bounds.X,widest*size*.5),lines*size*1.15)
end
W.UIS.TouchEnabled=PHONE;W.UIS.MouseEnabled=not PHONE;W.workspace.CurrentCamera.ViewportSize=R.Vector2.new(SW,SH)
E.player('Tester')
local player,pg=E.Player,E.pg
local X=require('./engine155p')(W,E,F,{Variant='began',Order='release first',Handoff='empty',Screen=R.Vector2.new(SW,SH),Inset=PHONE and 0 or 58})
local hum=E.hum
local bag=function()return player:FindFirstChildOfClass('Backpack')end
print(('bag look test: %s %dx%d'):format(VIEW,SW,SH))
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local layoutRemote=R.new('RemoteEvent');layoutRemote.Name='HotbarLayout155';layoutRemote.Parent=remotes;layoutRemote.FireServer=function()end
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog');local Inv=W.module('InventoryPanel155');local Dialog=W.module('DiscardDialog155')
local Theme=W.module('GardenTheme');local Style=W.module('GardenMenuStyle')

-- the items: the same hotbar as the preview (a shovel, a stack of 3 Apple Seeds, a Watermelon Seed, fruit, a bat, packs); the last four go to the Bag, so it lists cards
local function fruit(seed,scale)local t=F.fruit(W,nil,seed,scale,'None',700,1);t:SetAttribute('SourceCropId','plant-'..seed..scale);t.Parent=bag();return t end
local shovel=F.shovel(W,bag())
local apples={};for i=1,3 do apples[i]=F.seed(W,bag(),'AppleSeed',1,'None')end
local melon=F.seed(W,bag(),'SunflowerSeed',1,'None')
local blue=fruit('BluebellSeed',1)
local bat=F.bat(W,bag())
local forest=F.pack(W,bag(),1,'Pack01',1,'None')
local mechPack=F.pack(W,bag(),8,'MechLimited',1,'Gold','Gold Limited Mech Pack')
local mango=fruit('MangoSeed',1.2);local plum=fruit('PlumSeed',1.1);local orange=fruit('OrangeSeed',1)
local lime=fruit('LimeSeed',1.3);local fig=fruit('FigSeed',1);local kiwi=fruit('KiwiSeed',1.1)
local sc=R.new('LocalScript');sc.Name='Hotbar';local okLoad,errLoad=pcall(W.load,'Hotbar',sc);check(okLoad,'Hotbar loads: '..tostring(errLoad))
X.frames(30)
local gui,dock,panel,open
local function grab()gui=pg.ChestToolHotbar;dock=gui.Dock;panel=gui.Inventory;open=dock.OpenInventory end;grab()
local function slot(i)return dock['Slot'..i]end
local function slotOf(tool)local n=Names.Tool(tool,Catalog);for i=1,10 do local s=slot(i);if s.Visible and s.ItemName.Text==n then return s,i end end end
local kind=PHONE and'touch'or'mouse'
local function openBag()if not panel.Visible then X.tap(kind,open);X.frames(5)end end
local function closeBag()if panel.Visible then X.tap(kind,panel.Close);X.frames(5)end end
player:SetAttribute('HeldItemCap',200);player:SetAttribute('HeldItemCount',143)
X.wait(10) -- (the join ends: new items are placed as new)
local FAR=R.Vector2.new(6,6) -- (a point over neither the Bag nor the hotbar: letting go there changes nothing)
local function hold()if PHONE then X.wait(.5)end end -- (a phone lifts an item after a 0.4 s hold)
local function carry(t,b) -- lift `t` from its hotbar slot and carry it to the point b; the press stays down until release()
 local a=X.center((slotOf(t)))
 X.down(kind,a);hold()
 for i=1,5 do X.move(R.Vector2.new(a.X+(b.X-a.X)*i/6,a.Y+(b.Y-a.Y)*i/6));X.frames(1)end;X.move(b);X.frames(2)
end
local function release()X.up(FAR);X.frames(3)end
openBag()
for i=10,7,-1 do local s=slot(i);if s.ItemName.Text~=''then X.drag(kind,s,panel.Items,PHONE and .5 or nil);X.frames(2);openBag()end end
X.frames(3)
check(panel.Visible,'(the Bag is open)')

-- helpers -------------------------------------------------------------------------------------------------------------------------------------------------------------
local function hex(c)return string.format('%02X%02X%02X',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function isColor(v)return type(v)=='table'and v.__type=='Color3'end
local function bg(o,want,what)check(o~=nil and hex(o.BackgroundColor3)==want,what..' is #'..want..' (is '..(o and'#'..hex(o.BackgroundColor3)or'missing')..')')end
local function text(o,want,what)check(o~=nil and hex(o.TextColor3)==want,what..' text is #'..want..' (is '..(o and'#'..hex(o.TextColor3)or'missing')..')')end
local function rim(o)return o and o:FindFirstChildOfClass('UIStroke')end
local function rimIs(o,want,thickness,what)
 local s=rim(o);check(s~=nil and hex(s.Color)==want and s.Thickness==thickness,what..' rim is #'..want..', '..thickness..' px (is '..(s and'#'..hex(s.Color)..', '..tostring(s.Thickness)..' px'or'missing')..')')
 return s
end
-- the colours that must not be anywhere on the Bag: the lime (Theme.Colors.Mint) and the old green panel colours (the sheet, cards, selected tab, wells, header band, Keep it)
local BANNED={['93FF45']='the lime #93FF45',['142E23']='the old green sheet #142E23',['254C39']='the old green card #254C39',['41784C']='the old green selected tab #41784C',['0E2119']='the old green well #0E2119',
 ['41634D']='the old green header band #41634D',['466E56']='the old green Keep it #466E56'}
local function noLime(label)
 local bad={};local seen=0
 for _,root in ipairs({pg:FindFirstChild('ChestToolHotbar'),pg:FindFirstChild('DiscardConfirm')})do
  if root then
   for _,o in ipairs(root:GetDescendants())do
    seen+=1
    for k,v in pairs(o._props)do
     if isColor(v)then local why=BANNED[hex(v)];if why then bad[#bad+1]=tostring(o._props.Name)..'.'..k..' is '..why end end
    end
   end
  end
 end
 check(seen>100 and#bad==0,label..': no lime and no old green on the Bag ('..seen..' objects)'..(#bad>0 and' - '..table.concat(bad,'; ',1,math.min(#bad,5))or''))
end
local function hintText(t)local l=t:lower();return l:find('info',1,true)or l:find('hover',1,true)or l:find('click to hold',1,true)or l:find('tap to hold',1,true)or l:find('drag it onto',1,true)or l:find('drag to move',1,true)or l:find('right-click',1,true)or l:find('hold to move',1,true)end
local function noHint(label)
 check(panel:FindFirstChild('Hint')==nil,label..': the Bag has no Hint label')
 local bad
 for _,o in ipairs(panel:GetDescendants())do
  if o:IsA('TextLabel')or o:IsA('TextButton')then local t=(o.Text:gsub('%s+',' '));if hintText(t)then bad=t end end
 end
 check(bad==nil,label..': no text on the Bag tells you how to use it'..(bad and' ("'..bad..'")'or''))
end

-- 1 + 2. at rest ------------------------------------------------------------------------------------------------------------------------------------------------------
X.layout()
noHint('at rest')
do
 local bar=panel.BagBar
 local count,trash=bar.HeldCount,bar.Trash
 local visibleLabels={};for _,c in ipairs(bar:GetChildren())do if c:IsA('TextLabel')and c.Visible then visibleLabels[#visibleLabels+1]=c.Name end end
 check(#visibleLabels==1 and visibleLabels[1]=='HeldCount','the bottom bar shows only the count next to Discard ('..table.concat(visibleLabels,', ')..')')
 check(count.Visible and trash.Visible and count.Text=='143/200','the count (143/200) and Discard are both shown ("'..count.Text..'")')
 local function x0(o,pw)return o.Position.X.Scale*pw+o.Position.X.Offset end
 local function w0(o,pw)return o.Size.X.Scale*pw+o.Size.X.Offset end
 local pw=1000
 check(x0(count,pw)+w0(count,pw)+8==x0(trash,pw)and x0(trash,pw)+w0(trash,pw)==pw,'the count stays where it was: right of the bar\'s middle, 8 px left of Discard ('..x0(count,pw)..' + '..w0(count,pw)..' | '..x0(trash,pw)..')')
 -- the colours
 bg(panel,'1F2246','the sheet');check(math.abs(panel.BackgroundTransparency-.1)<1e-6,'the sheet stays 10% see-through')
 local trim=panel:FindFirstChild('GardenTrim');check(trim~=nil and hex(trim.Color)=='6A90E1'and math.abs(trim.Transparency-.48)<1e-6,'the sheet rim is #6A90E1 at 48% see-through (is '..(trim and'#'..hex(trim.Color)or'missing')..')')
 bg(panel:FindFirstChild('GardenHeader'),'424A80','the header band');bg(panel:FindFirstChild('HeaderRule'),'6A90E1','the header rule')
 bg(panel.Search,'192041','the search box');bg(count,'192041','the count')
 bg(panel.RarityFilter,'30366A','the rarity button');bg(panel.RarityOptions,'1F2246','the rarity dropdown panel')
 local tabs,selected=0,0
 for _,b in ipairs(panel.Categories:GetChildren())do
  if b:IsA('TextButton')then tabs+=1
   local on=b:GetAttribute('Selected')==true;if on then selected+=1 end
   bg(b,on and'4A5599'or'30366A',(on and'the selected tab "'or'the tab "')..b.Name..'"')
  end
 end
 check(tabs>=4 and selected==1,'the category tabs are there, one selected ('..tabs..' / '..selected..')')
 local cardCount=0
 for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then cardCount+=1;bg(c,'30366A','a Bag card')end end
 check(cardCount>=4,'the Bag lists cards ('..cardCount..')')
 bg(panel.Close,'30366A','the close button')
 bg(panel.BagBar.PickBar.PickHold,'4A5599','the Hold button');bg(panel.BagBar.PickBar.PickStash,'30366A','the To Bag button');bg(panel.BagBar.PickBar.PickCancel,'30366A','the x button')
 text(panel.BagBar.PickBar.PickName,'EAF0FF','the "Moving ..." line')
 bg(trash,'7A2C34','the Discard bin (stays red)')
 local target=trash:FindFirstChild('DropTarget');bg(target,'FF6060','the Discard bin highlight (stays red)')
 check(target and math.abs(target.BackgroundTransparency-.55)<1e-6,'the Discard bin highlight is as before (45% opaque)')
 rimIs(target,'FF6060',3,'the Discard bin highlight')
 -- the hotbar's own slots and the Bag button were never green: unchanged
 bg(slot(1),'30366A','a hotbar slot');bg(open,'30366A','the Bag button')
end
noLime('at rest')

-- 3. the drop highlight: a drag over the sheet, a slot, the Bag button and the bin ----------------------------------------------------------------------------------------
local function dropTarget(o)return o:FindFirstChild('DropTarget')end
local function lightRim(o,fill,what)
 local t=dropTarget(o)
 if not check(t~=nil and t.Visible,what..' is highlighted')then return end
 check(hex(t.BackgroundColor3)=='EAF0FF','the '..what..' highlight is the light colour #EAF0FF (is #'..hex(t.BackgroundColor3)..')')
 check(math.abs(t.BackgroundTransparency-fill)<1e-6,'the '..what..' highlight is a faint brighten ('..t.BackgroundTransparency..', not the .55 flood)')
 local s=rimIs(t,'EAF0FF',2,'the '..what..' highlight')
 check(s~=nil and s.Transparency>=0 and s.Transparency<=.2,'the '..what..' rim is a little see-through, not solid ('..tostring(s and s.Transparency)..')')
end
do
 local sheet=R.Vector2.new(panel.AbsolutePosition.X+panel.AbsoluteSize.X*.55,panel.AbsolutePosition.Y+panel.AbsoluteSize.Y*.45)
 carry(melon,sheet)
 lightRim(panel,.92,'sheet')
 check(not(dropTarget(panel.BagBar.Trash)and dropTarget(panel.BagBar.Trash).Visible),'the Discard bin is not lit while the sheet is the target')
 local ghost=gui:FindFirstChild('DragGhost');bg(ghost,'4A5599','the drag ghost')
 local other,outlined=nil,0
 for i=1,10 do local s=slot(i);local h=s:FindFirstChild('DropHint');if h and h.Visible then outlined+=1;other=other or h end end
 check(outlined>=1 and hex(rim(other).Color)=='EAF0FF'and rim(other).Thickness==2,'the slots it can go to are outlined with a thin light line ('..outlined..' slots)')
 noHint('dragging over the sheet');noLime('a drag over the sheet')
 release()
 check(not dropTarget(panel).Visible,'the highlight goes away when the item is let go')
end
do
 local _,at=slotOf(shovel);carry(melon,X.center(slot(at)))
 lightRim(slot(at),.86,'slot')
 noLime('a drag over a slot')
 release()
end
do
 carry(melon,X.center(open))
 lightRim(open,.86,'Bag button')
 release()
end
do
 local tr=panel.BagBar.Trash;carry(melon,R.Vector2.new(tr.AbsolutePosition.X+tr.AbsoluteSize.X+3,tr.AbsolutePosition.Y+tr.AbsoluteSize.Y/2))
 local t=dropTarget(tr)
 check(t~=nil and t.Visible and hex(t.BackgroundColor3)=='FF6060','the Discard bin lights red when an item is dragged to it')
 check(dropTarget(panel)==nil or not dropTarget(panel).Visible,'... and the sheet is not lit then')
 noLime('a drag over the Discard bin')
 release()
 check(slotOf(melon)~=nil,'(the dragged item stayed on its slot)')
end

-- search + the rarity dropdown --------------------------------------------------------------------------------------------------------------------------------------------
do
 panel.Search.Text='seed';X.frames(3)
 X.tap(kind,panel.RarityFilter);X.frames(3)
 check(panel.RarityOptions.Visible,'(the rarity dropdown is open)')
 bg(panel.RarityOptions,'1F2246','the open rarity dropdown panel');bg(panel.Search,'192041','the search box with text')
 noHint('search + dropdown');noLime('search + dropdown')
 X.tap(kind,panel.RarityFilter);X.frames(3);panel.Search.Text='';X.frames(3)
end

-- the discard popup -----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 X.drag(kind,slotOf(apples[1]),panel.BagBar.Trash,PHONE and .5 or nil);X.frames(2)
 local ui=Dialog.UI()
 if check(ui~=nil and ui.Gui.Enabled,'(the discard popup is open)')then
  X.tap(kind,ui.Row.More);X.frames(1)
  bg(ui.Frame,'1F2246','the popup panel');rimIs(ui.Frame,'6A90E1',1.5,'the popup')
  bg(ui.Picture,'30366A','the popup picture box')
  for _,n in ipairs({'One','Less','More','All'})do bg(ui.Row[n],'30366A','the popup "'..n..'" button')end
  bg(ui.Box,'192041','the popup count box');bg(ui.Keep,'424C8A','the Keep it button')
  bg(ui.Confirm,'C44048','the popup Discard button (stays red)')
  text(ui.Warning,'FFD68C','the popup warning (stays amber)')
  noLime('the discard popup')
  X.tap(kind,ui.Keep);X.frames(2)
  check(not ui.Gui.Enabled,'(Keep it closes the popup)')
 end
end

-- picked (tap-tap): the ring, the "Moving ..." line, the outlines, Hold ----------------------------------------------------------------------------------------------------
do
 hum:UnequipTools();X.wait(.5);closeBag()
 local w=R.Vector2.new(SW*.5,SH*.3);X.down('touch',w);X.up(w);X.frames(2)
 local s=slotOf(blue);local p=X.center(s);X.down('touch',p);X.wait(.55);X.up(p);X.frames(3)
 if check(Inv.Picked()~=nil and panel.Visible,'(a held item is picked: the Bag opened)')then
  local ring=s:FindFirstChild('PickedRing')
  check(ring~=nil and ring.Visible and hex(ring.BackgroundColor3)=='EAF0FF','the picked ring is the light colour (#'..(ring and hex(ring.BackgroundColor3)or'none')..')')
  local pick=panel.BagBar.PickBar
  check(pick.Visible and pick.PickName.Text:find('Moving',1,true)~=nil,'the "Moving ..." line is shown ("'..tostring(pick.PickName.Text)..'")')
  text(pick.PickName,'EAF0FF','the "Moving ..." line');bg(pick.PickHold,'4A5599','the Hold button')
  bg(pick.PickStash,'30366A','the To Bag button');bg(pick.PickCancel,'30366A','the x button')
  local outlined,wrong=0,0
  for i=1,10 do local h=slot(i):FindFirstChild('DropHint');if h and h.Visible then outlined+=1;if hex(rim(h).Color)~='EAF0FF'then wrong+=1 end end end
  check(outlined>=1 and wrong==0,'every slot it can go to is outlined in the light colour ('..outlined..' slots, '..wrong..' other colour)')
  noHint('an item picked');noLime('an item picked')
  X.tap('touch',pick.PickCancel);X.frames(3);check(Inv.Picked()==nil,'the x puts it down')
 end
 closeBag()
 noHint('Bag closed');noLime('the end')
end

-- 5. nothing shared changed ---------------------------------------------------------------------------------------------------------------------------------------------------
do
 local c=Theme.Colors
 check(hex(c.Mint)=='93FF45'and hex(c.Panel)=='1F2246'and hex(c.Card)=='30366A'and hex(c.Inset)=='192041'and hex(c.Line)=='6A90E1'and hex(c.Gold)=='FFE547','GardenTheme\'s colours are as they were (Mint stays the game\'s green)')
 local f=R.Instance.new('Frame');local header=Style.Panel(f,46)
 check(hex(f.GardenTrim.Color)=='93FF45'and hex(header.BackgroundColor3)=='41634D'and hex(f.HeaderRule.BackgroundColor3)=='93FF45','GardenMenuStyle.Panel still paints every other menu\'s trim, header band and rule green')
 check(hex(f.GardenTrim.Color)~=hex(panel.GardenTrim.Color),'(the Bag recolours its own: its rim is not the shared one)')
end
print(('R157 bag look checks %d, fails %d (%s)'):format(checks,fails,VIEW))
if fails>0 then error('failures')end
