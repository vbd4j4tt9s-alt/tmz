--!nocheck
-- R155 review: the item's ToolTip (a pack's odds, the pity lines, the Mech coat line) was written by the server and drawn by nobody, because the Hotbar switches
-- Roblox's backpack off. The REAL Hotbar + InventoryPanel155 + ItemTooltip155 + the real pity bars through R153's engine model (engine153 with this view's screen):
-- VIEW = 'pc' (1280 x 720, a mouse), 'phone' (844 x 390, touch) or 'portrait' (390 x 844, touch).
--  1. hover (mouse)  - a hotbar slot or a Bag card shows the item's ToolTip: its name (rarity colour), the odds as a name / odds column, the lucky line, the coat line, the
--                      pity rule; nothing for an item without a ToolTip or an empty slot; leaving hides it; a drag hides it; a changed ToolTip redraws it; a gone item hides it
--  2. the place      - inside the screen, above the slot / card (else below), one baseline along the hotbar above the pity bars and the held item's name (never over either),
--                      never over the Bag's bottom bar; a tall tooltip on a small screen drops odds rows ("+N more") and keeps the coat and the rule; it takes no input
--  3. touch          - a finger is no hover; a PICKED item (hold 0.4 s and let go) shows it until it is put down, a Bag card too; a pack that is just held shows it for a few
--                      seconds once the server has written its odds (nothing for the short line a pack has before that)
--  4. gamepad        - moving the selection onto a slot / card shows it; leaving hides it; a held pack announces itself as on a phone
--  5. the pure parts - Parse (the row kinds, the title line dropped) and Fit (rows dropped from the end of the odds, the rest kept)
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
-- a TextService that wraps (the shared mock measures one line only)
W.service('TextService').GetTextSize=function(_,text,size,_,bounds)
 local per=math.max(1,math.floor(bounds.X/(size*.5)));local lines,widest=0,0
 for l in(text..'\n'):gmatch('(.-)\n')do lines+=math.max(1,math.ceil(#l/per));widest=math.max(widest,#l)end
 return R.Vector2.new(math.min(bounds.X,widest*size*.5),lines*size*1.15)
end
W.UIS.TouchEnabled=PHONE;W.UIS.MouseEnabled=not PHONE;W.workspace.CurrentCamera.ViewportSize=R.Vector2.new(SW,SH)
E.player('Tester')
local player,pg=E.Player,E.pg
local X=require('./engine155p')(W,E,F,{Variant='began',Order='activated first',Handoff='empty',Screen=R.Vector2.new(SW,SH),Inset=PHONE and 0 or 58})
local hum=E.hum
local bag=function()return player:FindFirstChildOfClass('Backpack')end
local char=function()return player.Character end
print(('tooltip test: %s %dx%d'):format(VIEW,SW,SH))
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local layoutRemote=R.new('RemoteEvent');layoutRemote.Name='HotbarLayout155';layoutRemote.Parent=remotes;layoutRemote.FireServer=function()end
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog');local Inv=W.module('InventoryPanel155');local Tip=W.module('ItemTooltip155')
local Mech=W.module('MechCatalog');local Pity=W.module('PackPity155');local Odds=W.module('OddsText85')
-- the text ChestService:_holdPack writes into a pack's ToolTip: the label, the lucky line, the odds, (the Mech coat line), the rule
local function serverTip(label,lucky,seeds,coat)
 local rows={label};if lucky then rows[#rows+1]=Pity.LuckyLine end
 for _,s in ipairs(seeds)do rows[#rows+1]=s.Name..': '..Odds.Format(s.Chance)end
 if coat then rows[#rows+1]=Mech.CoatLine()end
 rows[#rows+1]=Pity.Disclosure
 return table.concat(rows,'\n')
end
local worldSeeds={};for i=1,14 do worldSeeds[i]={Name='Test Seed '..i,Chance=100/(i*7+3)}end
-- the items: the shovel, a seed with a short tooltip, a seed with none, a Mech pack and a world pack with the long server tooltip, then fruit to fill the hotbar
local shovel=F.shovel(W,bag());shovel.ToolTip='Remove a plant • Dig holes on the track to trap players'
local apple=F.seed(W,bag(),'AppleSeed',1,'None');apple.ToolTip='Common | Click or tap the soil to plant! Controller: RT'
local plain=F.seed(W,bag(),'CloverSeed',1,'None')
local mech=F.pack(W,bag(),8,'MechLimited',1,'Gold','Gold Limited Mech Pack');mech.ToolTip=serverTip('Gold Limited Mech Pack',true,Mech.Seeds,true)
local world=F.pack(W,bag(),2,'Pack03',1,'None');world.ToolTip=serverTip(world.Name,false,worldSeeds,false)
local fruit={}
for k,s in ipairs({'BluebellSeed','MangoSeed','PlumSeed','OrangeSeed','LimeSeed'})do
 local t=F.fruit(W,nil,s,1,'None',700,1);t:SetAttribute('SourceCropId','plant-'..k);t:SetAttribute('FruitIndex',1);t:SetAttribute('HarvestCycle',0);t.Parent=bag();fruit[k]=t
end
-- two more in the Bag: a Mech pack (long tooltip) and a plain fruit
local bagMech=F.pack(W,bag(),8,'MechLimited',1,'Diamond','Diamond Limited Mech Pack');bagMech.ToolTip=serverTip('Diamond Limited Mech Pack',false,Mech.Seeds,true)
local bagPlain=F.fruit(W,nil,'KiwiSeed',1,'None',700,1);bagPlain:SetAttribute('SourceCropId','plant-kiwi');bagPlain:SetAttribute('FruitIndex',1);bagPlain:SetAttribute('HarvestCycle',0);bagPlain.Parent=bag()
local sc=R.new('LocalScript');sc.Name='Hotbar';local okLoad,errLoad=pcall(W.load,'Hotbar',sc);check(okLoad,'Hotbar loads: '..tostring(errLoad))
X.frames(30)
-- the real pity bars above the hotbar
local Bars=W.module('PityBars155').Start(player)
player:SetAttribute('PackPityNormal',4);player:SetAttribute('PackPityEvent',9);X.wait(2)
local gui,dock,panel,open
local function grab()gui=pg.ChestToolHotbar;dock=gui.Dock;panel=gui.Inventory;open=dock.OpenInventory end;grab()
local function slot(i)return dock['Slot'..i]end
local function slotOf(tool)local n=Names.Tool(tool,Catalog);for i=1,10 do local s=slot(i);if s.Visible and s.ItemName.Text==n then return s,i end end end
local function cards()local out={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then out[#out+1]=c end end;return out end
local function cardOf(tool)local n=Names.Tool(tool,Catalog);for _,c in ipairs(cards())do if (c.ItemName.Text:gsub('%s+',' ')):sub(1,#n)==n then return c end end end -- (a long name wraps on the card)
local kind=PHONE and'touch'or'mouse'
local function openBag()if not panel.Visible then X.tap(kind,open);X.frames(5)end end
local function closeBag()if panel.Visible then X.tap(kind,panel.Close);X.frames(5)end end
local function settle()hum:UnequipTools();X.wait(.5)end
local function holdRelease(b)local p=X.center(b);X.down('touch',p);X.wait(.55);X.up(p);X.frames(3)end
local function key(code)W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[code],UserInputType=R.Enum.UserInputType.Keyboard,Position=R.Vector3.new(0,0,0)},false);X.frames(1)end
-- geometry
local function rectOf(o)return {X=o.AbsolutePosition.X,Y=o.AbsolutePosition.Y,W=o.AbsoluteSize.X,H=o.AbsoluteSize.Y}end
local function meets(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local function onScreen(r)return r.X>=0 and r.Y>=0 and r.X+r.W<=SW+.5 and r.Y+r.H<=SH+.5 end
local function tipFrame()local f=gui:FindFirstChild('ItemTooltip');return f and f.Visible and f or nil end
local function shown()X.frames(2);return tipFrame()end
local function lines(f) -- {title, rows = {left, right}} as drawn
 local out={Title=f.Title.Text,Rows={}}
 for _,c in ipairs(f:GetChildren())do if c:IsA('TextLabel')and c.Visible and c.Name:sub(1,3)=='Row'then
  local i=tonumber(c.Name:sub(4));local odds=f:FindFirstChild('Odds'..i);out.Rows[#out.Rows+1]={Y=c.Position.Y.Offset,Left=c.Text,Right=odds and odds.Visible and odds.Text or nil,Label=c}
 end end
 table.sort(out.Rows,function(a,b)return a.Y<b.Y end)
 return out
end
local function has(f,text)local l=lines(f);for _,r in ipairs(l.Rows)do if r.Left==text or r.Left:find(text,1,true)then return r end end;return nil end
local function pityRects() -- the pity bars as drawn (with their glow)
 local out={};local g=pg:FindFirstChild('PackPityBars155');local root=g and g:FindFirstChild('PityBars')
 if root and root.Visible then for _,b in ipairs(root:GetChildren())do if b:IsA('GuiObject')and b.Visible and b.AbsoluteSize.X>0 then
  local r=rectOf(b);out[#out+1]={X=r.X-5,Y=r.Y-5,W=r.W+10,H=r.H+10}
 end end end
 return out
end
local function noPity(f)for _,r in ipairs(pityRects())do if meets(rectOf(f),r)then return false end end;return true end
local function heldStrip()
 local n,t=dock.SelectedName,dock.SelectedTraits
 if n.Visible and n.Text~=''then local a=rectOf(n);local b=rectOf(t);return {X=a.X,Y=a.Y,W=a.W,H=math.max(a.Y+a.H,b.Y+b.H)-a.Y}end
 return nil
end
local function bottomOf(f)return f.AbsolutePosition.Y+f.AbsoluteSize.Y end

-- sanity: the bars are really there
check(#pityRects()==2,'(the real pity bars are on screen: '..#pityRects()..' bars)')
check(slotOf(mech)~=nil and slotOf(world)~=nil and slotOf(plain)~=nil and cardOf~=nil,'(the items are on the hotbar)')

-- 5. the pure parts --------------------------------------------------------------------------------------------------------------------------------------
do
 local rows=Tip.Parse(mech.ToolTip,{'Gold Limited Mech Pack'})
 local kinds={};for _,r in ipairs(rows)do kinds[#kinds+1]=r.Kind end
 check(rows[1].Kind=='lucky'and rows[1].A==Pity.LuckyLine,'Parse: the first line (only the pack\'s name again) is dropped; the lucky line comes first')
 local nOdds=0;for _,r in ipairs(rows)do if r.Kind=='odds'then nOdds+=1 end end
 check(nOdds==#Mech.Seeds and rows[2].Kind=='odds'and rows[2].A==Mech.Seeds[1].Name and rows[2].B==Odds.Format(Mech.Seeds[1].Chance),'Parse: one odds row per seed, the name and the "1/N" apart ('..nOdds..' rows)')
 check(rows[#rows-1].Kind=='coat'and rows[#rows-1].A==Mech.CoatLine()and rows[#rows].Kind=='rule'and rows[#rows].A==Pity.Disclosure,'Parse: the coat line, then the pity rule')
 local plainRows=Tip.Parse('Common | Click or tap the soil to plant! Controller: RT',{'x'})
 check(#plainRows==1 and plainRows[1].Kind=='text','Parse: a one-line tooltip is one text row')
 -- Fit: everything fits in a tall box; in a short one odds rows leave from the end and the coat and the rule stay
 local big=Tip.Fit(rows,260,2000,13,22)
 check(big.Dropped==0 and #big.Items==#rows,'Fit: a tall box keeps every row')
 local small=Tip.Fit(rows,260,big.Height-60,13,22)
 local last=small.Items[#small.Items]
 check(small.Height<=big.Height-60 and small.Dropped>0,'Fit: a shorter box drops odds rows ('..small.Dropped..' dropped, '..small.Height..' px of '..(big.Height-60)..')')
 local keptCoat,keptRule,more=false,false,nil
 for _,it in ipairs(small.Items)do if it.Row.Kind=='coat'then keptCoat=true elseif it.Row.Kind=='rule'and it.Row.A==Pity.Disclosure then keptRule=true end;if it.More then more=it.Row.A end end
 check(keptCoat and keptRule and more=='+'..small.Dropped..' more','Fit: the coat line and the rule stay, and "+N more" stands where the odds were ('..tostring(more)..')')
 local ys={};for i,it in ipairs(small.Items)do if i>1 then check(it.Y>=small.Items[i-1].Y+small.Items[i-1].H,'Fit: rows do not overlap')end end
 -- no odds at all and no room: the lines after the first go from the end (it ends, and fits)
 local text6={};for i=1,6 do text6[i]={Kind='text',A='A line of text '..i}end
 local tiny=Tip.Fit(text6,200,90,13,22)
 check(#tiny.Items<6 and #tiny.Items>=1 and tiny.Height<=90,'Fit: plain lines drop from the end when there is no room ('..#tiny.Items..' of 6 kept, '..tiny.Height..' px of 90)')
end

-- 1. hover (mouse) -----------------------------------------------------------------------------------------------------------------------------------------
if not PHONE then
 local s,i=slotOf(mech)
 check(tipFrame()==nil,'nothing shown before anything is hovered')
 s.MouseEnter:Fire();local f=shown()
 check(f~=nil,'hovering a hotbar slot shows its item\'s ToolTip')
 if f then
  local l=lines(f)
  check(l.Title==Names.Tool(mech,Catalog),'the title is the item\'s name ('..l.Title..')')
  check(has(f,Pity.LuckyLine)~=nil and has(f,Pity.Disclosure)~=nil and has(f,Mech.CoatLine())~=nil,'the lucky line, the coat line ("'..Mech.CoatLine()..'") and the pity rule are all there')
  local allOdds=true;for _,sd in ipairs(Mech.Seeds)do local r=has(f,sd.Name);if not(r and r.Right==Odds.Format(sd.Chance))then allOdds=false end end
  check(allOdds,'every seed\'s odds is a name / odds pair ('..#Mech.Seeds..' rows)')
  local dup=false;for _,r in ipairs(l.Rows)do if r.Left=='Gold Limited Mech Pack'then dup=true end end;check(not dup,'the pack\'s name is not repeated as a row')
  check(f.Active==false,'the panel takes no input')
  local anyActive=false;for _,c in ipairs(f:GetDescendants())do if c:IsA('GuiObject')and c.Active==true then anyActive=true end end;check(not anyActive,'... nor does anything in it')
  local fr=rectOf(f);local sr=rectOf(s)
  check(onScreen(fr),'inside the screen ('..fr.X..','..fr.Y..' '..fr.W..'x'..fr.H..')')
  check(bottomOf(f)<=sr.Y,'above the slot it describes')
  check(noPity(f),'never over the pity bars above the hotbar')
  local strip=heldStrip();check(strip==nil or not meets(fr,strip),'never over the held item\'s name')
 end
 s.MouseLeave:Fire();X.frames(2);check(tipFrame()==nil,'leaving the slot hides it')
 -- the same baseline along the whole hotbar (it does not jump about while the mouse crosses the slots)
 local bottoms={}
 for _,t in ipairs({shovel,apple,mech,world})do local b=slotOf(t);b.MouseEnter:Fire();local g=shown();if g then bottoms[#bottoms+1]=math.floor(bottomOf(g)+.5)end;b.MouseLeave:Fire();X.frames(1)end
 local same=#bottoms==4;for _,v in ipairs(bottoms)do if math.abs(v-bottoms[1])>1 then same=false end end
 check(same,'a hotbar slot\'s tooltip has one baseline along the hotbar ('..table.concat(bottoms,',')..')')
 -- a click on the hovered slot equips it (and shuts the Bag): the cursor is still over it and Roblox keeps the tooltip
 do local cs=slotOf(world);cs.MouseEnter:Fire();shown();local cp=X.center(cs);X.down('mouse',cp);X.up(cp);X.wait(.5)
  check(char():FindFirstChildOfClass('Tool')==world and tipFrame()~=nil,'a click on the hovered slot (it is held now) keeps its tooltip');cs.MouseLeave:Fire();X.frames(1);settle() end
 -- slot 10 and slot 1: clamped inside the screen
 for _,n in ipairs({1,10})do
  local b=slot(n);b.MouseEnter:Fire();local g=shown()
  if g then check(onScreen(rectOf(g)),'slot '..n..': inside the screen ('..rectOf(g).X..' + '..rectOf(g).W..' of '..SW..')')end
  b.MouseLeave:Fire();X.frames(1)
 end
 -- the long tooltip (14 odds rows) and the short ones
 local b=slotOf(world);b.MouseEnter:Fire();local g=shown();check(g~=nil and has(g,'Test Seed 14')~=nil and noPity(g),'a world pack: all 14 odds rows fit on this screen, clear of the pity bars');b.MouseLeave:Fire();X.frames(1)
 b=slotOf(apple);b.MouseEnter:Fire();g=shown();check(g~=nil and has(g,'Common | Click or tap the soil to plant! Controller: RT')~=nil,'a one-line tooltip is one line under the name');b.MouseLeave:Fire();X.frames(1)
 b=slotOf(plain);b.MouseEnter:Fire();check(shown()==nil,'an item without a ToolTip: nothing');b.MouseLeave:Fire();X.frames(1)
 slot(10).MouseEnter:Fire()
 do local empty;for n=1,10 do if slot(n).ItemName.Text==''then empty=slot(n)end end
  if empty then empty.MouseEnter:Fire();check(shown()==nil,'an empty slot: nothing');empty.MouseLeave:Fire()end end
 slot(10).MouseLeave:Fire();X.frames(1)
 -- the text follows the item: a new ToolTip (the server rewrites it when the pack is held again), then the item gone
 b=slotOf(mech);b.MouseEnter:Fire();shown()
 mech.ToolTip=serverTip('Gold Limited Mech Pack',false,Mech.Seeds,true);g=shown()
 check(g~=nil and has(g,Pity.LuckyLine)==nil and has(g,Mech.CoatLine())~=nil,'a changed ToolTip is redrawn (the lucky line left)')
 mech.ToolTip=serverTip('Gold Limited Mech Pack',true,Mech.Seeds,true);X.frames(2)
 -- a drag hides it
 local p=X.center(b);X.down('mouse',p);for k=1,6 do X.move(R.Vector2.new(p.X+k*6,p.Y-k*6));X.frames(1)end
 check(tipFrame()==nil,'a drag in progress hides it')
 local q=R.Vector2.new(640,200);X.move(q);X.up(q);X.frames(3)
 check(slotOf(mech)==b,'(the drag was let go in the world: nothing moved)')
 -- the Bag
 openBag()
 local card=cardOf(bagMech)
 check(card~=nil,'(a Mech pack in the Bag)')
 if card then
  card.MouseEnter:Fire();local h=shown()
  check(h~=nil and has(h,Mech.CoatLine())~=nil,'hovering a Bag card shows its ToolTip too')
  if h then
   local hr=rectOf(h);local cr=rectOf(card);local bar=rectOf(panel.BagBar)
   check(onScreen(hr),'... inside the screen');check(bottomOf(h)<=cr.Y+.5 or hr.Y>=cr.Y+cr.H-.5,'... above (or, with no room, below) the card')
   check(not meets(hr,{X=bar.X,Y=bar.Y,W=bar.W,H=bar.H}),'... never over the Bag\'s bottom bar (count, Trash)')
  end
  card.MouseLeave:Fire();X.frames(1);check(tipFrame()==nil,'leaving the card hides it')
 end
 local c2=cardOf(bagPlain)
 if c2 then c2.MouseEnter:Fire();check(shown()==nil,'a Bag card without a ToolTip: nothing');c2.MouseLeave:Fire()end
 -- hovering a hotbar slot with the Bag open: above the Bag's bottom bar
 local sb=slotOf(mech);sb.MouseEnter:Fire();local k=shown()
 if k then check(not meets(rectOf(k),rectOf(panel.BagBar))and onScreen(rectOf(k)),'a hotbar slot\'s tooltip with the Bag open stays off the Bag\'s bottom bar')end
 sb.MouseLeave:Fire();X.frames(1)
 -- the Bag closing takes a hovered card\'s tooltip with it
 if card then card.MouseEnter:Fire();shown();closeBag();check(tipFrame()==nil,'closing the Bag hides a Bag card\'s tooltip')end
 -- a held item\'s name above the hotbar: the tooltip stays above it
 settle();X.tap('mouse',slotOf(apple));X.wait(.6)
 local strip=heldStrip();check(strip~=nil,'(an item in the hand: its name shows above the hotbar)')
 b=slotOf(world);b.MouseEnter:Fire();g=shown()
 if g and strip then check(not meets(rectOf(g),strip)and noPity(g),'with an item in the hand the tooltip is above its name and the pity bars') end
 -- (without the pity bars the held item's name is what it has to keep clear of)
 Bars.Root.Visible=false;X.frames(1);b.MouseLeave:Fire();b.MouseEnter:Fire();g=shown();strip=heldStrip()
 check(g~=nil and strip~=nil and not meets(rectOf(g),strip)and bottomOf(g)<=strip.Y,'... and with the pity bars hidden it is still above the held item\'s name ('..tostring(g and bottomOf(g))..' vs '..tostring(strip and strip.Y)..')')
 Bars.Root.Visible=true
 b.MouseLeave:Fire();settle()
 -- a gone item
 b=slotOf(apple);b.MouseEnter:Fire();shown();apple.Parent=nil;X.frames(5)
 check(tipFrame()==nil,'the item went (used up): its tooltip is gone');apple.Parent=bag();X.frames(5);b.MouseLeave:Fire()
end

-- 2b. a tall tooltip on this screen: rows leave from the end of the odds, the rest stays ---------------------------------------------------------------------
do
 local many={};for i=1,60 do many[i]={Name='Long Seed '..i,Chance=100/(i+2)}end
 local long=serverTip('Gold Limited Mech Pack',true,many,true)
 mech.ToolTip=long
 local b=slotOf(mech)
 W.Gui.SelectedObject=b;b.SelectionGained:Fire();local g=shown()
 check(g~=nil,'a 60-seed tooltip is drawn')
 if g then
  local gr=rectOf(g)
  check(onScreen(gr),'... inside the screen ('..gr.Y..' + '..gr.H..' of '..SH..')')
  check(noPity(g),'... not over the pity bars')
  local more;for _,r in ipairs(lines(g).Rows)do if r.Left:find(' more',1,true)then more=r.Left end end
  check(more~=nil and has(g,Mech.CoatLine())~=nil and has(g,Pity.Disclosure)~=nil,'... odds rows were left out ("'..tostring(more)..'") but the coat line and the rule are still there')
 end
 b.SelectionLost:Fire();W.Gui.SelectedObject=nil;X.frames(1)
 mech.ToolTip=serverTip('Gold Limited Mech Pack',true,Mech.Seeds,true)
end

-- 3. touch -------------------------------------------------------------------------------------------------------------------------------------------------
do
 settle();closeBag()
 -- a finger is no hover
 local w=R.Vector2.new(SW*.5,SH*.3);X.down('touch',w);X.up(w);X.frames(2)
 local s=slotOf(mech);s.MouseEnter:Fire();check(shown()==nil,'touch: a MouseEnter that comes with a finger shows nothing');s.MouseLeave:Fire()
 -- picked (hold 0.4 s and let go): the tooltip stays while it is picked
 holdRelease(s)
 check(Inv.Picked()~=nil and panel.Visible,'(a held mech pack is picked: the Bag opened)')
 local f=shown()
 check(f~=nil and has(f,Mech.CoatLine())~=nil and has(f,Pity.Disclosure)~=nil,'touch: a picked pack shows its odds, the coat line and the rule')
 if f then
  local fr=rectOf(f);local bar=rectOf(panel.BagBar)
  check(onScreen(fr),'... inside the screen ('..fr.X..','..fr.Y..' '..fr.W..'x'..fr.H..' of '..SW..'x'..SH..')')
  check(not meets(fr,bar),'... clear of the Bag\'s bottom bar (Hold / To Bag / x / Trash stay visible and tappable)')
  check(noPity(f),'... and of the pity bars')
  -- a tap goes through it: the engine gives a press inside the panel to whatever is under it, never to the panel
  local hitTip=false
  for _,r in ipairs(lines(f).Rows)do local c=X.center(r.Label);local top,sunk=X.target(c);if top and top:IsDescendantOf(f)then hitTip=true end end
  check(not hitTip,'... and a tap on it reaches what is under it')
  check(f.Visible and tipFrame()==f,'(still shown a moment later)')
 end
 X.wait(6);check(tipFrame()~=nil,'it stays for as long as the item is picked (not a timed pop-up)')
 X.tap('touch',s);X.frames(3);check(Inv.Picked()==nil and tipFrame()==nil,'put down (a tap on it again): the tooltip goes')
 -- the x button
 holdRelease(slotOf(mech));check(shown()~=nil,'(picked again)');X.tap('touch',panel.BagBar.PickBar.PickCancel);X.frames(3);check(Inv.Picked()==nil and tipFrame()==nil,'the x puts it down: the tooltip goes')
 -- an item without a tooltip
 holdRelease(slotOf(plain));check(Inv.Picked()~=nil and shown()==nil,'picked item without a ToolTip: nothing')
 X.tap('touch',slotOf(plain));X.frames(3)
 -- a Bag card (the search leaves only it, so it sits in the top row of the grid on any screen)
 openBag();panel.Search.Text='diamond';X.frames(3);local card=cardOf(bagMech)
 if card then
  holdRelease(card);local g=shown()
  check(Inv.Picked()~=nil and g~=nil and has(g,Mech.CoatLine())~=nil,'touch: a picked Bag card shows its ToolTip')
  if g then check(onScreen(rectOf(g))and not meets(rectOf(g),rectOf(panel.BagBar)),'... inside the screen, clear of the bottom bar')end
  X.tap('touch',card);X.frames(3)
 end
 panel.Search.Text='';X.frames(2)
 closeBag();X.frames(3);check(tipFrame()==nil,'(nothing left over)')
end

-- 3b. a pack that is just held (touch / gamepad): its odds for a few seconds ---------------------------------------------------------------------------------
do
 settle();closeBag()
 local pack=world;local s=slotOf(pack)
 -- (touch) the pack already has its odds: a tap on the slot holds it and the panel shows
 X.tap('touch',s);X.wait(.4)
 local f=tipFrame()
 check(char():FindFirstChildOfClass('Tool')==pack and f~=nil and has(f,'Test Seed 1')~=nil and has(f,Pity.Disclosure)~=nil,'touch: tapping a pack\'s slot holds it and shows its odds (a few seconds)')
 if f then check(onScreen(rectOf(f))and noPity(f),'... inside the screen, clear of the pity bars'); local strip=heldStrip();check(strip==nil or not meets(rectOf(f),strip),'... and of the held pack\'s name')end
 X.wait(5.3);check(tipFrame()==nil,'... and it goes by itself after about 5 s')
 settle()
 -- (touch) a pack that has only the short line yet (the server writes the odds when it is held): nothing until they come, then the panel
 local fresh=F.pack(W,bag(),3,'Pack02',1,'None');fresh.ToolTip='Snow Seed Pack • Click / tap / RT 5 times to open';X.frames(5)
 local fs=slotOf(fresh)
 if fs then
  X.tap('touch',fs);X.wait(.5)
  check(char():FindFirstChildOfClass('Tool')==fresh and tipFrame()==nil,'touch: a pack with only its short line announces nothing')
  fresh.ToolTip=serverTip('Snow Seed Pack',false,worldSeeds,false);X.wait(.4)
  check(tipFrame()~=nil and has(tipFrame(),'Test Seed 1')~=nil,'... the odds arrive (the server writes them on the hold): now the panel shows')
  X.wait(5.5);check(tipFrame()==nil,'... for about 5 s')
 end
 settle();if fresh then fresh:Destroy()end;X.frames(3)
 -- an apple (not a pack) is not announced
 local as=slotOf(apple)
 if as then X.tap('touch',as);X.wait(.5);check(tipFrame()==nil,'touch: holding a seed shows nothing by itself');settle()end
 -- a mouse user holding a pack gets no pop-up (hover is theirs)
 if not PHONE then
  X.tap('mouse',s);X.wait(.5);check(tipFrame()==nil,'mouse: holding a pack shows nothing by itself (it shows on hover)');settle()
 end
end

-- 4. gamepad -------------------------------------------------------------------------------------------------------------------------------------------------
do
 settle();closeBag()
 local s=slotOf(mech)
 W.Gui.SelectedObject=s;s.SelectionGained:Fire();local f=shown()
 check(f~=nil and has(f,Mech.CoatLine())~=nil,'gamepad: moving the selection onto a slot shows its ToolTip')
 if f then check(onScreen(rectOf(f))and noPity(f),'... inside the screen, clear of the pity bars')end
 s.SelectionLost:Fire();W.Gui.SelectedObject=nil;X.frames(2);check(tipFrame()==nil,'... and off it hides it')
 openBag();panel.Search.Text='diamond';X.frames(3);local card=cardOf(bagMech)
 if card then
  W.Gui.SelectedObject=card;card.SelectionGained:Fire();local g=shown()
  check(g~=nil and has(g,Mech.CoatLine())~=nil and onScreen(rectOf(g)),'gamepad: a Bag card too')
  card.SelectionLost:Fire();W.Gui.SelectedObject=nil;X.frames(1)
 end
 panel.Search.Text='';X.frames(2);closeBag()
 -- Y picks the focused item: the picked item's tooltip
 openBag();panel.Search.Text='diamond';X.frames(3);local c3=cardOf(bagMech)
 if c3 then
  W.Gui.SelectedObject=c3;W.actions.GardenBagPick('GardenBagPick',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonY});X.frames(2)
  check(Inv.Picked()~=nil and shown()~=nil,'gamepad: Y picks it and its tooltip shows')
  W.actions.GardenBagPick('GardenBagPick',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonY});X.frames(2)
  W.Gui.SelectedObject=nil
  check(Inv.Picked()==nil and tipFrame()==nil,'... and Y again puts it down')
 end
 panel.Search.Text='';X.frames(2);closeBag()
 -- a pack held with the gamepad announces itself like on a phone
 settle();local lastInput=W.UIS.GetLastInputType;W.UIS.GetLastInputType=function()return R.Enum.UserInputType.Gamepad1 end
 local ws=slotOf(world);ws.Activated:Fire({UserInputType=R.Enum.UserInputType.Gamepad1,KeyCode=R.Enum.KeyCode.ButtonA});X.wait(.5)
 check(char():FindFirstChildOfClass('Tool')==world and tipFrame()~=nil and has(tipFrame(),'Test Seed 1')~=nil,'gamepad: A on a pack\'s slot holds it and its odds show for a few seconds')
 X.wait(5.5);check(tipFrame()==nil,'... and go by themselves')
 W.UIS.GetLastInputType=lastInput;settle()
end
print(('R155 tooltip checks %d, fails %d (%s)'):format(checks,fails,VIEW))
if fails>0 then error('failures')end
