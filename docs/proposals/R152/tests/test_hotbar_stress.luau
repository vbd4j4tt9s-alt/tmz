--!nocheck
-- R152 hotbar reliability: a seeded random STRESS run on the Roblox mock with the REAL Hotbar. Hundreds of random clicks and taps (clean and rolled, in every
-- engine event order), number keys, L1 / R1, slot moves, Bag opens / card clicks / card drops, items added and removed in between (also the very frame before
-- a click: stale slots), the held item destroyed, press-without-release, and respawns (new character, new Backpack, tools rebuilt a moment later).
-- Every single action must take effect EXACTLY ONCE, the hotbar must match a model of what the player did, and nothing may get stuck:
--   * a click / tap / key on a slot with an item: exactly one EquipTool or UnequipTools call (toggle), on a live tool, and the hand ends as the model says;
--   * on an empty slot, or a stack whose last copy just vanished: no call at all;
--   * a drop on another slot: the model's swap, never an equip; a card drop likewise;
--   * the slots, the stacks and their counts always equal the tools that exist (no ghost, none missing); a probe click every 20 actions still works first try.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;if fails<=25 then print('FAIL: '..msg)end end;return c end
F.packAssets(W)
W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
local rec=E.recorder()
E.player('Tester')
local player,pg=E.Player,E.pg
local bag,char,hum=E.bag,E.char,E.hum
local acts,dead,log=0,0,{}
local function wrap(h)
 local eq,un=h.EquipTool,h.UnequipTools
 h.EquipTool=function(self,tool)acts+=1;if tool.Parent==nil then dead+=1 end;log[#log+1]='equip '..tostring(tool.Name);return eq(self,tool)end
 h.UnequipTools=function(self)acts+=1;log[#log+1]='unequip';return un(self)end
end
wrap(hum)
local shovel=F.shovel(W,bag)
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
local function frames(n,dt)for _=1,n do local gui=pg:FindFirstChild('ChestToolHotbar');if gui then lay(gui,0,0,1280,720,0,0)end;W.frames(1,dt)end end
local scriptInst=R.new('LocalScript');scriptInst.Name='Hotbar'
local ok,err=pcall(W.load,'Hotbar',scriptInst);check(ok,'Hotbar loads: '..tostring(err))
frames(30)
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local gui=pg.ChestToolHotbar;local dock=gui.Dock;local panel=gui.Inventory
local MB,TOUCH,MOVE=R.Enum.UserInputType.MouseButton1,R.Enum.UserInputType.Touch,R.Enum.UserInputType.MouseMovement
local NUM={'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero'}

-- a seeded generator --------------------------------------------------------------------------------------------------------------------------------
local okCfg,cfg=pcall(require,'./stress_cfg');cfg=okCfg and type(cfg)=='table'and cfg or{} -- (an optional stress_cfg.luau returning {Seed=,N=} runs other seeds / longer)
local state=cfg.Seed or 20261005
local function rnd(n)state=(state*16807)%2147483647;return state%n+1 end
local function chance(p)return rnd(1000)<=p*1000 end

-- the world: the tools that exist (by display name) --------------------------------------------------------------------------------------------------
local SEEDS={'AppleSeed','BluebellSeed','CloverSeed','MangoSeed','PlumSeed','OrangeSeed','PeachSeed','LimeSeed'}
local tools={} -- display name -> list of live tool instances
local serial=0
local function newTool(seedId)
 serial+=1
 local t=F.fruit(W,nil,seedId,1,'None',700,1);t:SetAttribute('SourceCropId','crop-'..serial);t:SetAttribute('FruitIndex',1);t:SetAttribute('HarvestCycle',0)
 return t,Names.Tool(t,Catalog)
end
local function stacks()local n=0;for _,l in pairs(tools)do if #l>0 then n+=1 end end;return n end
local function addTool(seedId,parent)
 local t,name=newTool(seedId);t.Parent=parent or bag;tools[name]=tools[name]or{};table.insert(tools[name],t);return t,name
end
local function liveTools(name)local out={};for _,t in ipairs(tools[name]or{})do if t.Parent~=nil then out[#out+1]=t end end;tools[name]=out;return out end

-- the model of the hotbar: slot -> display name ('' = empty) ---------------------------------------------------------------------------------------
local M={slots={},held=nil}
local function display()local out={};for i=1,10 do out[i]=dock['Slot'..i].ItemName.Text end;return out end
local function resync()M.slots=display()end
local function emptySlot()for i=2,10 do if M.slots[i]==''then return i end end end
local function heldTool()for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then return t end end end
local function heldName()local t=heldTool();if not t then return nil end;if t:GetAttribute('GardenShovel')then return'Shovel'end;return Names.Tool(t,Catalog)end
local function slotHas(name)for i=1,10 do if M.slots[i]==name then return i end end end

-- gestures (as in test_hotbar_click) -----------------------------------------------------------------------------------------------------------------
local function at(b,dx,dy)return {X=b.AbsolutePosition.X+b.AbsoluteSize.X/2+(dx or 0),Y=b.AbsolutePosition.Y+b.AbsoluteSize.Y/2+(dy or 0)}end
local function inside(b,p)local a,z=b.AbsolutePosition,b.AbsoluteSize;return p.X>=a.X and p.Y>=a.Y and p.X<=a.X+z.X and p.Y<=a.Y+z.Y end
local ORDERS={'activated first','release first','none'}
local function gesture(b,path,order,kind)
 if #path==2 and not path.flick and math.abs(path[1].X-path[2].X)+math.abs(path[1].Y-path[2].Y)>12 then path={path[1],{X=(path[1].X+path[2].X)/2,Y=(path[1].Y+path[2].Y)/2},path[2]}end
 local first,last=path[1],path[#path]
 local input={UserInputType=kind=='touch'and TOUCH or MB,Position=first}
 b.InputBegan:Fire(input)
 for i=2,#path-1 do if kind=='touch'then input.Position=path[i];W.UIS.InputChanged:Fire(input)else W.UIS.InputChanged:Fire({UserInputType=MOVE,Position=path[i]})end end
 if kind=='touch'then input.Position=last end
 local ended=kind=='touch'and input or{UserInputType=MB,Position=last}
 local activated=inside(b,last)
 if order=='activated first'then if activated then b.Activated:Fire()end;W.UIS.InputEnded:Fire(ended)
 elseif order=='release first'then W.UIS.InputEnded:Fire(ended);if activated then b.Activated:Fire()end
 else W.UIS.InputEnded:Fire(ended)end
end
local function key(code)W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[code],UserInputType=R.Enum.UserInputType.Keyboard},false)end
local function slotBtn(i)return dock['Slot'..i]end
local function wobble(b)return chance(.5)and{at(b)}or{at(b,rnd(13)-7,rnd(9)-5),at(b,rnd(25)-4,rnd(17)-9),at(b,rnd(9)-5,rnd(7)-4)}end

-- expectations ---------------------------------------------------------------------------------------------------------------------------------------
-- toggle(name): what ONE press on an item called `name` must do. Returns the expected number of calls (1) or 0 when there is nothing to equip.
local function expectToggle(name)
 if name==''or not name then return 0 end
 if name=='Shovel'then if M.held=='Shovel'then M.held=nil else M.held='Shovel'end;return 1 end
 if#liveTools(name)==0 then return 0 end
 if M.held==name then M.held=nil else M.held=name end;return 1
end
local function verify(label,expectActs,closesBag)
 frames(3)
 check(acts==expectActs,('%s: exactly %d equip call(s), got %d  [%s]'):format(label,expectActs,acts,table.concat(log,';')))
 check(dead==0,label..': never equips a destroyed tool ('..dead..')')
 local hn=heldName()
 check(hn==M.held,('%s: in hand "%s", model says "%s"'):format(label,tostring(hn),tostring(M.held)))
 local d=display()
 for i=1,10 do if d[i]~=M.slots[i]then check(false,('%s: slot %d shows "%s", model says "%s"'):format(label,i,d[i],M.slots[i]));M.slots[i]=d[i]end end
 local n=0;for _,b in ipairs({bag,char})do for _,t in ipairs(b:GetChildren())do if t:IsA('Tool')then n+=1 end end end
 local want=1;for _,l in pairs(tools)do want+=#liveTools(_)end
 check(n==want,('%s: %d tools exist, model says %d'):format(label,n,want))
 if closesBag then check(not panel.Visible,label..': the Bag closed') end
 acts=0;dead=0;table.clear(log)
end
local function reset()acts=0;dead=0;table.clear(log)end

-- start: shovel + three types, one of them twice ------------------------------------------------------------------------------------------------------
for i=1,3 do addTool(SEEDS[i])end;addTool(SEEDS[1]);frames(10);resync()
check(slotBtn(1).ItemName.Text~=''and M.slots[2]~=''and M.slots[3]~=''and M.slots[4]~='','(the start: shovel + 3 stacks on the hotbar)')
local shovelName=slotBtn(1).ItemName.Text

-- the actions -----------------------------------------------------------------------------------------------------------------------------------------
local counts={}
local function count(k)counts[k]=(counts[k]or 0)+1 end
local function pickFilled()local c={};for i=1,10 do if M.slots[i]~=''then c[#c+1]=i end end;return c[rnd(#c)]end
local actions={}
function actions.click()
 local i=chance(.15)and rnd(10)or pickFilled();local b=slotBtn(i);local name=M.slots[i]
 local kind=chance(.5)and'touch'or'mouse';local order=ORDERS[rnd(3)]
 reset();local e=expectToggle(name==shovelName and'Shovel'or name);if name==''then e=0 end
 -- (the Bag may be open: a slot click equips and closes it)
 local wasOpen=panel.Visible
 gesture(b,wobble(b),order,kind);verify(('click slot %d (%s, %s, "%s")'):format(i,kind,order,name),e,wasOpen and e==1)
 count('click')
end
function actions.key()
 local i=rnd(10);local name=M.slots[i]
 reset();local e=expectToggle(name==shovelName and'Shovel'or name);if name==''then e=0 end
 local wasOpen=panel.Visible
 key(NUM[i]);verify(('key %d ("%s")'):format(i,name),e,wasOpen and e==1);count('key')
end
function actions.doubleclick()
 local i=pickFilled();local b=slotBtn(i);local name=M.slots[i];reset()
 local e=0;local n=name==shovelName and'Shovel'or name
 for _=1,2 do e+=expectToggle(n)end
 gesture(b,{at(b)},ORDERS[rnd(3)]);gesture(b,{at(b)},ORDERS[rnd(3)]);verify('double click slot '..i,e,false);count('double')
end
function actions.drag()
 local i,j=rnd(10),rnd(10);local from,to=slotBtn(i),slotBtn(j);local name=M.slots[i]
 reset();local kind=chance(.5)and'touch'or'mouse'
 local e=0
 if i==j then e=expectToggle(name==shovelName and'Shovel'or name);if name==''then e=0 end -- a drag that comes back to its own slot is a click
 elseif name~=''and i>=2 and j>=2 then M.slots[i],M.slots[j]=M.slots[j],M.slots[i]end
 local path={at(from),at(from,rnd(13)-7,rnd(7)-4),at(to),at(to,rnd(9)-5,rnd(9)-5)}
 if chance(.25)then path={at(from),at(to,rnd(9)-5,rnd(9)-5),flick=true}end -- a fast flick: the engine reports only the press and the release
 gesture(from,path,ORDERS[rnd(3)],kind)
 verify(('drag slot %d -> %d (%s, "%s", %d points)'):format(i,j,kind,name,#path),e,false);count('drag')
end
function actions.bagOpenClick()
 if not panel.Visible then dock.OpenInventory.Activated:Fire();frames(10);check(panel.Visible,'the Bag opens');count('open')end
 local cards={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then cards[#cards+1]=c end end
 if#cards==0 then return end
 local card=cards[rnd(#cards)];local text=card.ItemName.Text
 local name;for n in pairs(tools)do if text==n or text:sub(1,#n+2)==n..' ('then name=n end end
 local shov=(text==shovelName or text:sub(1,#shovelName+2)==shovelName..' (')
 if not name and not shov then return end
 reset();local e=expectToggle(shov and'Shovel'or name);if not shov and#liveTools(name)==0 then e=0 end
 gesture(card,wobble(card),ORDERS[rnd(3)],chance(.5)and'touch'or'mouse');verify('Bag card "'..text..'"',e,e==1);count('card')
end
function actions.bagDrag()
 if not panel.Visible then return end
 local cards={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then cards[#cards+1]=c end end
 if#cards==0 then return end
 local card=cards[rnd(#cards)];local text=card.ItemName.Text;local name
 for n in pairs(tools)do if text==n or text:sub(1,#n+2)==n..' ('then name=n end end
 local j=rnd(9)+1;local to=slotBtn(j);reset()
 if name and#liveTools(name)>0 then local i=slotHas(name);if i and i~=j then M.slots[i],M.slots[j]=M.slots[j],M.slots[i]end end
 gesture(card,chance(.25)and{at(card),at(to,rnd(7)-3,rnd(7)-3),flick=true}or{at(card),at(card,20,10),at(to),at(to,rnd(7)-3,rnd(7)-3)},ORDERS[rnd(3)],chance(.5)and'touch'or'mouse')
 verify('Bag card "'..text..'" dragged to slot '..j,0,false);count('carddrag')
end
function actions.closeBag()
 if not panel.Visible then return end
 local how=rnd(3);reset()
 if how==1 then key('B')elseif how==2 then key('Escape')else panel.Close.Activated:Fire()end
 verify('close the Bag',0,true);count('close')
end
function actions.add()
 if stacks()>=8 and chance(.7)then return end
 local seedId=SEEDS[rnd(#SEEDS)];local _,name=newTool(seedId)
 reset();local isNew=#liveTools(name)==0
 local t=addTool(seedId)
 if isNew then local s=emptySlot();if s then M.slots[s]=name end end
 verify('add "'..name..'"',0,false);count('add')
end
function actions.remove()
 local names={};for n,l in pairs(tools)do if#liveTools(n)>0 then names[#names+1]=n end end
 if#names==0 then return end
 local n=names[rnd(#names)];local list=liveTools(n);local t=table.remove(list,rnd(#list));tools[n]=list
 reset()
 if heldTool()==t then M.held=nil end
 t:Destroy()
 if#list==0 then local i=slotHas(n);if i then M.slots[i]='' end;if M.held==n then M.held=nil end end
 verify('remove "'..n..'"',0,false);count('remove')
end
function actions.removeThenClick() -- the stale slot: the tool is gone, the hotbar has not refreshed yet, the slot is clicked in the same frame
 local names={};for n,l in pairs(tools)do if#liveTools(n)>0 then names[#names+1]=n end end
 if#names==0 then return end
 local n=names[rnd(#names)];local list=liveTools(n);local i=slotHas(n);if not i then return end
 -- the representative of a stack is the equipped copy, else the OLDEST one: remove that one
 local rep;for _,t in ipairs(list)do if t.Parent==char then rep=t end end;rep=rep or list[1]
 for k,t in ipairs(list)do if t==rep then table.remove(list,k);break end end;tools[n]=list
 reset()
 if heldTool()==rep then M.held=nil end
 rep:Destroy()
 local e=0
 if#list>0 then e=1;if M.held==n then M.held=nil else M.held=n end else local s=slotHas(n);if s then M.slots[s]='' end;if M.held==n then M.held=nil end end
 local b=slotBtn(i);gesture(b,{at(b)},ORDERS[rnd(3)],chance(.5)and'touch'or'mouse')
 verify(('remove "%s" then click its slot before the refresh'):format(n),e,false);count('stale')
end
function actions.cycle()
 local cyc=W.actions['GardenHotbarCycle'];if not cyc or panel.Visible then return end
 reset();local before=heldName()
 -- the expected target: the next filled slot after the held one in the direction (visible slots 1..10 here)
 local dirBack=chance(.5);local cur=0
 if before then for i=1,10 do if M.slots[i]==before or(before=='Shovel'and M.slots[i]==shovelName)then cur=i end end end
 local target;for off=1,10 do local idx=(cur-1+off*(dirBack and-1 or 1))%10+1;if M.slots[idx]~=''then target=idx;break end end
 local e=0;if target then e=expectToggle(M.slots[target]==shovelName and'Shovel'or M.slots[target])end
 cyc('GardenHotbarCycle',R.Enum.UserInputState.Begin,{KeyCode=dirBack and R.Enum.KeyCode.ButtonL1 or R.Enum.KeyCode.ButtonR1})
 verify('gamepad '..(dirBack and'L1'or'R1'),e,false);count('cycle')
end
function actions.cancelledPress() -- a touch that never ends (cancelled by the system) must not break the next click
 local i=pickFilled();local b=slotBtn(i)
 local input={UserInputType=TOUCH,Position=at(b)};b.InputBegan:Fire(input);input.Position=at(b,30,0);W.UIS.InputChanged:Fire(input)
 frames(1);reset();count('cancel')
end
function actions.respawn()
 reset();count('respawn')
 local old,oldBag=player.Character,player:FindFirstChildOfClass('Backpack')
 player.CharacterRemoving:Fire(old)
 for _,t in ipairs(old:GetChildren())do if t:IsA('Tool')then t:Destroy()end end
 for _,t in ipairs(oldBag:GetChildren())do t:Destroy()end
 oldBag:Destroy();old:Destroy()
 local nc=R.new('Model');nc.Name=player.Name;nc.Parent=W.workspace;player.Character=nc
 local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=R.CFrame.new(0,3,100);root.Parent=nc
 local nh=R.new('Humanoid');nh.Health=100;nh.Parent=nc
 local nb=R.new('Backpack');nb.Name='Backpack'
 nh.EquipTool=function(_,tool)for _,t in ipairs(nc:GetChildren())do if t:IsA('Tool')then t.Parent=nb end end;tool.Parent=nc end
 nh.UnequipTools=function()for _,t in ipairs(nc:GetChildren())do if t:IsA('Tool')then t.Parent=nb end end end
 wrap(nh);hum=nh;char=nc;bag=nb
 nb.Parent=player;player.CharacterAdded:Fire(nc)
 frames(2)
 -- a click in the window before the server has rebuilt the tools: nothing to equip, nothing may break
 local i=rnd(10);gesture(slotBtn(i),{at(slotBtn(i))},ORDERS[rnd(3)]);frames(2)
 check(acts==0 and dead==0,'a click while the backpack is empty (respawn) does nothing ('..acts..')');reset()
 -- the server rebuilds the tools (same items, new instances)
 F.shovel(W,nb)
 local old2={};for n,l in pairs(tools)do old2[n]=#l end
 tools={}
 for n,c in pairs(old2)do for _=1,c do for _,s in ipairs(SEEDS)do local t,name=newTool(s);if name==n then t.Parent=nb;tools[name]=tools[name]or{};table.insert(tools[name],t);break else t:Destroy()end end end end
 frames(10);M.held=nil;resync()
 -- the same stacks, no ghosts, no duplicates
 local d=display();local seen={}
 for i=1,10 do if d[i]~=''then check(not seen[d[i]],'respawn: "'..d[i]..'" is on the hotbar once');seen[d[i]]=true end end
 for n,l in pairs(tools)do if#l>0 then check(seen[n]==true,'respawn: "'..n..'" is back on the hotbar') end end
 check(seen[shovelName]==true,'respawn: the shovel is back')
 verify('after the respawn',0,false)
end
local weighted={{'click',30},{'key',14},{'drag',12},{'bagOpenClick',8},{'bagDrag',4},{'closeBag',3},{'add',9},{'remove',6},{'removeThenClick',6},{'cycle',3},{'doubleclick',3},{'cancelledPress',2},{'respawn',2}}
local total=0;for _,w in ipairs(weighted)do total+=w[2]end
local function pick()local r=rnd(total);for _,w in ipairs(weighted)do r-=w[2];if r<=0 then return w[1]end end end

local N=cfg.N or 600
for step=1,N do
 local name=pick()
 local okA,errA=pcall(actions[name])
 if not okA then check(false,'step '..step..' ('..name..') raised: '..tostring(errA));break end
 if step%20==0 then -- the probe: a clean click on a filled slot still works first try (nothing is stuck)
  if panel.Visible then dock.OpenInventory.Activated:Fire();frames(8);M.slots=display()end
  local i=pickFilled();local b=slotBtn(i);local nm=M.slots[i];reset()
  local e=expectToggle(nm==shovelName and'Shovel'or nm)
  gesture(b,{at(b)},'activated first');verify('probe click slot '..i,e,false)
 end
 if fails>25 then break end
end
-- the end: nothing is stuck, a click still equips
do
 if panel.Visible then dock.OpenInventory.Activated:Fire();frames(8)end
 hum:UnequipTools();frames(3);M.held=nil;reset();M.slots=display()
 local i=pickFilled();local b=slotBtn(i);local nm=M.slots[i]
 local e=expectToggle(nm==shovelName and'Shovel'or nm)
 gesture(b,{at(b,5,3),at(b,16,6),at(b,2,1)},'none','touch');verify('final rolled tap, no Activated',e,false)
end
local summary={};for k,v in pairs(counts)do summary[#summary+1]=k..'='..v end;table.sort(summary)
print('actions: '..table.concat(summary,' '))
check(rec.count()==0,'the whole run was silent ('..rec.keys()..')')
print(('R152 hotbar stress checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
