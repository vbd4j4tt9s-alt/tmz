--!nocheck
-- R139 (owner: "new packs will be highlighted temporarily in the person's inventory, the highlight will be like a
-- rainbow border, it's temporary and fades after a while"): the real Hotbar on the mock. Packs you joined with never
-- glow; a pack numbered after your save loaded gets a spinning rainbow ring on its hotbar slot and Bag card. The ring
-- waits until you can see it, stays 4 s, fades over 2 s and is gone; the same pack never glows twice (respawn / sync).
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
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
-- The save loaded with packs numbered up to 40 (the server stamps PackNumber on every pack tool).
player:SetAttribute('DataStatus','Loaded');player:SetAttribute('PackSerialAtJoin',40)
local number=0
local function pack(stage,variant,size,mutation,n)local t=F.pack(W,bag,stage,variant,size,mutation);number+=1;t:SetAttribute('PackNumber',n or number);return t end
F.shovel(W,bag)
local old={pack(1,'Pack01',1,'None'),pack(1,'Pack01',1,'None'),pack(2,'Pack05',2.5,'Gold')}
F.seed(W,bag,'SunflowerSeed',1,'None','Watermelon Seed')
-- Layout emulation (as the R113 inventory test): absolute rects from UDim2 + AnchorPoint + canvas offsets.
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
local function seconds(s)frames(math.floor(s*60+.5))end
local key=function(code)W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[code],UserInputType=R.Enum.UserInputType.Keyboard},false)end
local renderConns=function()local n=0;for _,c in ipairs(W.Run.RenderStepped._c)do if c.Connected then n+=1 end end;return n end
local scriptInst=R.new('LocalScript');scriptInst.Name='Hotbar'
local ok,err=pcall(W.load,'Hotbar',scriptInst);check(ok,'Hotbar loads: '..tostring(err))
frames(30)
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local gui=pg.ChestToolHotbar;local dock=gui.Dock;local panel=gui.Inventory;local scroll=panel.Items
local function slotFor(tool)for i=1,10 do local s=dock['Slot'..i];if s.Visible and s.ItemName.Text==Names.Tool(tool,Catalog)then return s,i end end end
local function glow(b)local g=b and b:FindFirstChild('NewGlow');return g and g.Visible and g or nil end
local function glowCount()local n=0;for _,d in ipairs(gui:GetDescendants())do if d.Name=='NewGlow'and d.Visible then n+=1 end end;return n end
local function cards()local out={};for _,c in ipairs(scroll:GetChildren())do if c.Name=='Item'and c.Visible then out[#out+1]=c end end;return out end
local function cardFor(tool)local want=Names.Tool(tool,Catalog);for _,c in ipairs(cards())do if(c.ItemName:GetAttribute('FullText')or''):find(want,1,true)==1 then return c end end end
-- 1. The packs you joined with stay plain.
check(slotFor(old[1])~=nil and slotFor(old[3])~=nil,'the packs you joined with are on the hotbar')
check(glowCount()==0,'nothing glows on join ('..glowCount()..')')
-- 2. A new pack arrives (a steal, a gift, the free tutorial pack...).
local snow=pack(3,'Pack02',1,'None',41);frames(3)
local slot=slotFor(snow);local g=glow(slot)
check(g~=nil,'the new pack\'s hotbar slot gets the NewGlow ring')
local stroke=g and g:FindFirstChild('Rainbow');local grad=stroke and stroke:FindFirstChildOfClass('UIGradient')
check(stroke and stroke:IsA('UIStroke')and stroke.Thickness>=3 and stroke.ApplyStrokeMode==R.Enum.ApplyStrokeMode.Border,'it is a thick border (UIStroke)')
local kp=grad and grad.Color and(grad.Color.Keypoints or grad.Color.A) -- (the mock keeps the keypoints in A, each colour in V)
local hues={}
if kp then for _,k in ipairs(kp)do local c=k.Value or k.V;local mx,mn=math.max(c.R,c.G,c.B),math.min(c.R,c.G,c.B);local h=0
 if mx>mn then if mx==c.R then h=((c.G-c.B)/(mx-mn))%6 elseif mx==c.G then h=(c.B-c.R)/(mx-mn)+2 else h=(c.R-c.G)/(mx-mn)+4 end end
 hues[#hues+1]=math.floor(h*60+.5)end end
check(#hues>=7 and hues[1]==hues[#hues],'rainbow colours that loop round ('..table.concat(hues,',')..')')
local bands={{0,15,'red'},{20,70,'orange/yellow'},{90,150,'green'},{180,230,'blue'},{240,290,'violet'}};local missing={}
for _,b in ipairs(bands)do local hit=false;for _,h in ipairs(hues)do if h>=b[1]and h<=b[2]then hit=true end end;if not hit then missing[#missing+1]=b[3]end end
check(#missing==0,'red, orange/yellow, green, blue and violet are all there'..(#missing>0 and(' (missing '..table.concat(missing,', ')..')')or''))
check(g and g.ZIndex>(slot.ZIndex or 1) and g.Size.X.Scale==1 and g.Size.Y.Scale==1 and g.Rainbow.Thickness<4,'it sits on top, on the slot edge (inside the Bag\'s 4 px margin)')
check(stroke and stroke.Transparency==0,'fully visible at first')
local r1=grad and grad.Rotation;frames(10);local r2=grad and grad.Rotation
check(r1~=nil and r2~=nil and r1~=r2,('the colours spin round the border (%s -> %s)'):format(tostring(r1),tostring(r2)))
check(glowCount()==1,'only the new pack glows')
-- 3. It holds ~4 s, fades over 2 s, then is gone.
seconds(3.5);check(glow(slot)and stroke.Transparency==0,'still bright after 3.5 s')
seconds(1.5);local mid=stroke.Transparency;check(mid>.2 and mid<.8,('fading at 5 s (transparency %.2f)'):format(mid))
seconds(1.2);check(glow(slot)==nil,'gone after ~6 s')
check(glowCount()==0,'nothing left glowing')
local conns=renderConns();frames(5);check(renderConns()==conns,'the per-frame update stops when nothing glows')
-- 4. The same pack rebuilt (respawn / server sync) does not glow again.
local id=snow:GetAttribute('SeedInventoryId');snow:Destroy();frames(3)
local again=F.tool(W,'Snow Seed Pack',{SeedPackTool=true,SeedInventoryId=id,PackSize=1,PackMutation='None',Weather='None',Stage=3,BagVariant='Pack02',SeedScale=1,PackNumber=41},bag);frames(5)
check(slotFor(again)~=nil and glow(slotFor(again))==nil,'a rebuilt tool of the same pack does not glow again')
-- 5. A new copy joining a stack lights up the stack.
local forest=pack(1,'Pack01',1,'None',42);frames(3)
local fslot=slotFor(forest);check(fslot and fslot.Count.Text=='x3' and glow(fslot)~=nil,'a new Forest pack on the x3 stack lights the stack')
seconds(6.5);check(glow(fslot)==nil,'and fades like the others')
-- 6. A pack that only fits in the Bag waits until you open it.
for i=1,8 do F.fruit(W,bag,({'AppleSeed','MooncapSeed','CocoaSeed','IceberrySeed','FirePepperSeed','SnowdropSeed','BluebellSeed','HoloMelonSeed'})[i],1+i,'None',100+i)end
frames(5)
local lava=pack(4,'Pack03',1,'None',43);frames(3)
check(slotFor(lava)==nil,'the hotbar is full, so the new pack is only in the Bag')
seconds(20);check(glowCount()==0,'nothing glows while you cannot see it')
key('B');frames(20)
check(panel.Visible,'B opens the Bag')
local card=cardFor(lava);local cg=glow(card)
check(cg~=nil,'its Bag card has the rainbow ring when you open the Bag')
check(cg and cg.Rainbow.Transparency==0,'bright, even 20 s after it arrived (the 4 s start when you see it)')
check(glowCount()==1,'only that card glows')
seconds(3.5);check(glow(card)~=nil,'still there 3.5 s after opening')
seconds(3);check(glow(cardFor(lava))==nil,'then it fades away')
-- 7. A card recycled for another item never carries the ring.
local mech=pack(5,'Pack04',1,'None',44);frames(5)
local mc=cardFor(mech);check(mc and glow(mc)~=nil,'a pack that arrives with the Bag open glows at once')
panel.Search.Text='apple';frames(10)
local leaked=0;for _,c in ipairs(cards())do if glow(c)then leaked+=1 end end
check(leaked==0,'filtering it away hands its card to another item without the ring')
panel.Search.Text='';frames(10);check(glow(cardFor(mech))~=nil,'clearing the search shows it glowing again')
-- 8. Reduced Motion: a still ring (no spinning).
W.Gui.ReducedMotionEnabled=true;frames(1);local still=cardFor(mech);local a=still.NewGlow.Rainbow.UIGradient.Rotation;frames(10)
check(still.NewGlow.Rainbow.UIGradient.Rotation==a,'Reduced Motion keeps the colours still')
W.Gui.ReducedMotionEnabled=false
-- 9. No PackSerialAtJoin (an older server) means nothing glows rather than everything.
player:SetAttribute('PackSerialAtJoin',nil);local stray=pack(6,'Pack01',1,'None',45);frames(5)
check(glow(cardFor(stray))==nil,'without the join number nothing glows')
scriptInst.Destroying:Fire();frames(3)
check(pg:FindFirstChild('ChestToolHotbar')==nil,'teardown removes the GUI')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
