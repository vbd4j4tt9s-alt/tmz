-- R158e tutorial storyboard (not a test): appended by run_preview158e.sh to the setup part of tools/tests/test_tutorial.luau. Plays the REAL BeginnerTutorial (+ BeginnerGuide,
-- HudLayout, PropCache152) through the ten steps on the mock (VIEW_NAME = 'pc' 1280x720 mouse, 'phone' 844x390 touch) and prints per moment:
--   SCENE <moment> <layer> <x> <y> <json>  hud = a stand-in HUD (the game's own BASE / TRACK, hotbar, MENU, BONUS ROLL, market window), tut = the tutorial's ScreenGui (inside the
--                                          top bar inset, like the game), tap = its button-pointer layer, goal / spot / timer = its world billboards at the camera's projection;
--   WORLD <moment> <json>                  the world as projected, shaded faces: stand-in scenery (grass, the track, the home line, your base, dirt, treadmill, market, packs, the plant,
--                                          you) and the tutorial's OWN 3D pieces as the script placed them (the big red arrow, the chevrons, the ring, the beam).
-- A perspective camera behind the player (70 degrees). Approximate: blocks for the scenery, no lighting but a simple shade.
local dump=require('./dump_tree')
modules[RS.GardenTheme].Corner=function(p,r)local c=new('UICorner');c.CornerRadius=R.UDim.new(0,r or 4);c.Parent=p;return c end
local phone=VIEW_NAME=='phone'
local W,H=phone and 844 or 1280,phone and 390 or 720;local INSET=phone and 44 or 58
VIEW=R.Vector2.new(W,H-INSET)
if phone then UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch end
function Players.GetUserThumbnailAsync()error('offline preview: the sprout stands in for the owner face')end
-- The camera: perspective, full-screen viewport points (as Roblox's WorldToViewportPoint).
local F=(H/2)/math.tan(math.rad(35))
local function toCam(p)local rel=camera.CFrame:Inverse()*p;return rel.X,rel.Y,-rel.Z end
function camera.WorldToViewportPoint(_,p)
 local x,y,z=toCam(p)
 if z<=.1 then return V3(W/2-x*100,H/2+y*100,-1),false end
 local sx,sy=W/2+x/z*F,H/2-y/z*F
 return V3(sx,sy,z),sx>=0 and sx<=W and sy>=0 and sy<=H
end
local function follow(at,toward)
 local d=V3(toward.X-at.X,0,toward.Z-at.Z).Unit
 local from=at-d*15+V3(0,8,0);camera.CFrame=R.CFrame.lookAt(from,at+d*12+V3(0,-1,0))
end
-- Stand-in HUD: BASE / TRACK in the top bar row, the hotbar, the MENU button, BONUS ROLL; the market window when it is open.
local hud=new('ScreenGui');hud.Name='PreviewHud';hud.Parent=pg
local function box(name,x,y,w,h,color,label,parent,size)
 local f=new(label and'TextLabel'or'Frame');f.Name=name;f.Position=R.UDim2.fromOffset(x,y);f.Size=R.UDim2.fromOffset(w,h);f.BackgroundColor3=color;f.BackgroundTransparency=.05;f.Parent=parent or hud
 local c=new('UICorner');c.CornerRadius=R.UDim.new(0,9);c.Parent=f
 if label then f.Text=label;f.TextSize=size or(phone and 15 or 17);f.TextColor3=R.Color3.new(1,1,1);f.TextStrokeColor3=R.Color3.new(0,0,0);f.TextStrokeTransparency=.4;f.Font=R.Enum.Font.FredokaOne end
 return f
end
local bw,bh=phone and 84 or 110,phone and 32 or 38
box('BASE',W/2-bw-4,6,bw,bh,R.Color3.fromRGB(78,168,96),'BASE');box('TRACK',W/2+4,6,bw,bh,R.Color3.fromRGB(226,138,48),'TRACK')
baseB.AbsolutePosition=R.Vector2.new(W/2-bw-4,6);baseB.AbsoluteSize=R.Vector2.new(bw,bh);trackB.AbsolutePosition=R.Vector2.new(W/2+4,6);trackB.AbsoluteSize=R.Vector2.new(bw,bh)
local ss=phone and 50 or 64;local x0=W/2-(6*ss+5*6)/2;local sy=H-(phone and 10 or 16)-ss
for i=1,5 do local s=dock['Slot'..i];s.AbsolutePosition=R.Vector2.new(x0+(i-1)*(ss+6),sy);s.AbsoluteSize=R.Vector2.new(ss,ss)end
local slotLabels={}
for i=1,6 do local f=box('Slot'..i,x0+(i-1)*(ss+6),sy,ss,ss,R.Color3.fromRGB(18,24,44),i<6 and tostring(i)or'🎒');slotLabels[i]=f;f.TextSize=i<6 and 11 or 24;f.TextXAlignment=i<6 and R.Enum.TextXAlignment.Left or nil;f.TextYAlignment=i<6 and R.Enum.TextYAlignment.Top or nil end
box('Menu',phone and 52 or 10,H/2-30,60,60,R.Color3.fromRGB(232,178,40),'MENU')
local brw,brh=phone and 150 or 190,phone and 46 or 58;local brx,bry=W-brw-(phone and 70 or 24),sy-brh-(phone and 12 or 70)
local bonus=box('BonusRoll',brx,bry,brw,brh,R.Color3.fromRGB(46,172,66),'🎁 BONUS ROLL',hud,phone and 14 or 18)
bonusB.AbsolutePosition=R.Vector2.new(brx,bry);bonusB.AbsoluteSize=R.Vector2.new(brw,brh)
local market=box('MarketWindow',W/2-300,H/2-170,600,330,R.Color3.fromRGB(28,40,74),nil,hud);market.Visible=false
box('Title',20,12,300,34,R.Color3.fromRGB(28,40,74),'Market',market,24)
local buyTab=box('BuyTab',20,58,276,36,R.Color3.fromRGB(64,86,154),'Buy',market);local sellTab=box('SellTab',304,58,276,36,R.Color3.fromRGB(64,86,154),'Sell crops',market)
local sellAllB=box('SellAll',440,108,140,40,R.Color3.fromRGB(43,177,106),'Sell all',market);local crate=box('Crop',20,108,410,110,R.Color3.fromRGB(40,56,98),'🍎  x1',market,26)
sellMode.AbsolutePosition=R.Vector2.new(W/2-300+304,H/2-170+58);sellMode.AbsoluteSize=R.Vector2.new(276,36)
sellAll.AbsolutePosition=R.Vector2.new(W/2-300+440,H/2-170+108);sellAll.AbsoluteSize=R.Vector2.new(140,40)
-- The world: stand-in scenery as blocks {name, center, size, colour, layer (0 = ground, always behind)}.
local SCENERY={
 {'Grass',V3(0,-.5,-120),V3(600,1,340),{110,182,86},0},{'Track',V3(0,-.45,260),V3(240,1,420),{214,190,132},0},{'HomeLine',V3(0,.06,50),V3(240,.1,1.6),{250,250,250},0},
 {'BasePad',V3(0,.08,-20),V3(100,.16,100),{150,170,140},0},{'Neighbour1',V3(-125,.08,-20),V3(100,.16,100),{140,150,160},0},{'Neighbour2',V3(125,.08,-20),V3(100,.16,100),{140,150,160},0},
 {'Dirt',V3(-20,.25,10),V3(46,.4,22.6),{120,84,54},0},{'Treadmill',V3(12,.6,-6),V3(6,1.2,12),{70,78,92},1},{'Belt',V3(12,1.25,-6),V3(4.6,.1,11),{30,34,40},1},
 {'Market',V3(0,7,-168),V3(36,14,22),{36,141,144},1},{'Roof',V3(0,15,-168),V3(40,2,26),{247,209,119},1},{'Counter',V3(0,2,-155),V3(26,4,4),{194,137,86},1},
}
local packAt={V3(40,1,90),V3(-60,1,140),V3(70,1,180)}
local plantOn,fruitRipe,charOn=false,false,true
local function plain(name,center,size,color,layer)return {Name=name,CF=CF(center.X,center.Y,center.Z),Size=size,Color=color,Layer=layer,Class='Part'}end
local function sceneParts()
 local out={}
 for _,s in ipairs(SCENERY)do out[#out+1]=plain(s[1],s[2],s[3],s[4],s[5])end
 for i,p in ipairs(packAt)do out[#out+1]=plain('Pack'..i,p,V3(2.2,2.2,1.4),{150,70,210},1)end
 if plantOn then out[#out+1]=plain('Stem',V3(-20,2.2,10),V3(.8,4,.8),{70,150,60},1);out[#out+1]=plain('Leaves',V3(-20,4.4,10),V3(4,2,4),{80,190,80},1)
  out[#out+1]=plain('Fruit',V3(-18.6,3.6,9.4),fruitRipe and V3(1.2,1.2,1.2)or V3(.7,.7,.7),fruitRipe and{230,40,50}or{170,210,120},1)end
 if charOn then local r=root.CFrame.Position;local c={58,110,220}
  out[#out+1]=plain('Torso',r,V3(2,2,1),c,1);out[#out+1]=plain('Head',r+V3(0,1.7,0),V3(1.2,1.2,1.2),{255,214,170},1);out[#out+1]=plain('Legs',r+V3(0,-2,0),V3(2,2,1),{40,60,120},1)
  if player:GetAttribute('ChestChaseSeedCarrying')then out[#out+1]=plain('Carried',r+V3(0,2.9,0),V3(2.2,2.2,1.4),{150,70,210},1)end
 end
 -- the tutorial's own 3D pieces, as placed by the script
 local t=workspace:FindFirstChild('TutorialTrail')
 if t then for _,p in ipairs(t:GetChildren())do
  if p:IsA('BasePart')and p.Transparency<.99 and p.Name~='TutorialTarget'then
   local c=p.Color;out[#out+1]={Name=p.Name,CF=p.CFrame,Size=p.Size,Color={math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255)},Alpha=1-p.Transparency,Layer=p.Name=='GoalSpot'and 0 or 1,
    Class=p.ClassName,Shape=p.Shape and p.Shape.Name or'Block',Neon=p.Material==R.Enum.Material.Neon}
  end
 end end
 return out
end
-- Faces of a part in world space: a block (6), a wedge (5), a cylinder along its X (a 16-sided prism).
local function corner(cf,x,y,z)return cf*V3(x,y,z)end
local function partFaces(p)
 local cf,s=p.CF,p.Size;local hx,hy,hz=s.X/2,s.Y/2,s.Z/2;local f={}
 if p.Class=='WedgePart'then
  local function v(x,y,z)return corner(cf,x,y,z)end
  local a1,a2,a3,b1,b2,b3=v(-hx,-hy,-hz),v(-hx,-hy,hz),v(-hx,hy,hz),v(hx,-hy,-hz),v(hx,-hy,hz),v(hx,hy,hz)
  f={{a1,a2,a3},{b1,b3,b2},{a1,b1,b2,a2},{a2,b2,b3,a3},{a1,a3,b3,b1}}
 elseif p.Shape=='Cylinder'then
  local n=16;local ring1,ring2={}, {}
  for i=1,n do local a=i/n*math.pi*2;local y,z=math.cos(a)*hy,math.sin(a)*hz;ring1[i]=corner(cf,-hx,y,z);ring2[i]=corner(cf,hx,y,z)end
  f[#f+1]=ring1;f[#f+1]=ring2
  for i=1,n do local j=i%n+1;f[#f+1]={ring1[i],ring1[j],ring2[j],ring2[i]}end
 else
  local c={};for i,x in ipairs({-hx,hx})do for j,y in ipairs({-hy,hy})do for k,z in ipairs({-hz,hz})do c[(i-1)*4+(j-1)*2+k]=corner(cf,x,y,z)end end end
  f={{c[1],c[2],c[4],c[3]},{c[5],c[7],c[8],c[6]},{c[1],c[5],c[6],c[2]},{c[3],c[4],c[8],c[7]},{c[1],c[3],c[7],c[5]},{c[2],c[6],c[8],c[4]}}
 end
 return f
end
-- Clip a face to the near plane (camera space z >= NEAR), project it; shade by its normal.
local NEAR=.6;local LIGHT=V3(.35,.85,.4).Unit
local function num(v)return string.format('%.1f',v)end
local function worldJson()
 local items={}
 for _,p in ipairs(sceneParts())do
  for _,face in ipairs(partFaces(p))do
   local cam={}
   for i,w in ipairs(face)do local x,y,z=toCam(w);cam[i]={x,y,z}end
   local clipped={}
   for i=1,#cam do
    local a,b=cam[i],cam[i%#cam+1]
    if a[3]>=NEAR then clipped[#clipped+1]=a end
    if(a[3]>=NEAR)~=(b[3]>=NEAR)then local t=(NEAR-a[3])/(b[3]-a[3]);clipped[#clipped+1]={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,NEAR}end
   end
   if #clipped>=3 then
    local e1,e2=face[2]-face[1],face[3]-face[1];local n=e1:Cross(e2);local mag=n.Magnitude
    local shade=1;if mag>1e-6 then n=n/mag;shade=.62+.38*math.abs(n:Dot(LIGHT))end
    if p.Neon then shade=1 end
    local pts={};local depth=0
    for _,c in ipairs(clipped)do pts[#pts+1]='['..num(W/2+c[1]/c[3]*F)..','..num(H/2-c[2]/c[3]*F)..']';depth+=c[3]end
    local col=p.Color
    items[#items+1]=string.format('{"p":[%s],"c":[%d,%d,%d],"a":%s,"z":%s,"l":%d,"g":%s}',table.concat(pts,','),math.floor(col[1]*shade),math.floor(col[2]*shade),math.floor(col[3]*shade),
     num(p.Alpha or 1),num(depth/#clipped),p.Layer or 1,tostring(p.Neon==true))
   end
  end
 end
 return'['..table.concat(items,',')..']'
end
local function shot(moment)
 local gui=pg.BeginnerTutorial
 print('WORLD '..moment..' '..worldJson())
 print('SCENE '..moment..' hud 0 0 '..dump(hud,W,H))
 print('SCENE '..moment..' tut 0 '..INSET..' '..dump(gui,W,H-INSET))
 print('SCENE '..moment..' tap 0 0 '..dump(pg.BeginnerTutorialTap,W,H))
 for _,name in ipairs({'Goal','TapSpot','GrowTimer'})do
  local bb=gui[name]
  if bb.Enabled and bb.Adornee then
   local at,on=camera:WorldToViewportPoint(bb.Adornee.CFrame.Position+V3(0,bb.StudsOffsetWorldSpace.Y,0))
   if on then print('SCENE '..moment..' '..string.lower(name)..' '..math.floor(at.X-bb.Size.X.Offset/2)..' '..math.floor(at.Y-bb.Size.Y.Offset*.85)..' '..dump(bb,bb.Size.X.Offset,bb.Size.Y.Offset))end
  end
 end
end
local function settle(n)frames(n or 90)end
local function pressed()for _=1,40 do frames(1);local g=pg.BeginnerTutorialTap.TapHand;if not g.Visible or not g.Hand.Visible or g.Hand.Press.Scale<.9 then return end end end
-- 1. Spawn: at your base, the pack far down the track.
player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',1)
root.CFrame=CF(0,3,0);serverStep={Kind='Pack',Target=V3(40,1,90)};follow(V3(0,3,0),V3(40,3,90))
local scriptInst=new('LocalScript');scriptInst.Name='BeginnerTutorial'
local ok,err=pcall(load,'BeginnerTutorial',scriptInst);if not ok then error(err)end
pg.BeginnerTutorial.AbsolutePosition=R.Vector2.new(0,INSET)
settle(70);if not phone then shot('01_spawn')end
settle(60*4);pressed();shot('02_track')
-- 3. On the track, by the pack: the arrow over it, your key.
root.CFrame=CF(30,3,76);follow(V3(30,3,76),V3(40,3,90));settle(20);settle(60);if not phone then shot('03_steal')end
-- 3. Carrying it home.
serverStep={Kind='Safety',Target=V3(0,3,38)};player:SetAttribute('ChestChaseSeedCarrying',true);table.remove(packAt,1);root.CFrame=CF(22,3,82);follow(V3(22,3,82),V3(0,3,38));settle(70);if not phone then shot('04_carry')end
-- 4. Banked by the line: open it (the clicking hand).
player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind=nil,Target=nil};root.CFrame=CF(4,3,40);follow(V3(4,3,40),V3(0,3,-20))
local tool=new('Tool');tool.Name='Forest Pack';tool:SetAttribute('SeedPackTool',true);tool:SetAttribute('SeedInventoryId','1_2');tool.Parent=character
slotLabels[1].Text='1   🎁';player:SetAttribute('TutorialStep',4)
local bag=new('Model');bag.Name='CarriedSeed';bag:SetAttribute('SeedPackCarry',true);bag:SetAttribute('PackClicksRequired',5);bag:SetAttribute('PackClickCount',2)
local part=new('Part');part.CFrame=CF(5,4,38);part.Parent=bag;bag.PrimaryPart=part;bag.Parent=character
settle(90);for _=1,60 do frames(1);local h=pg.BeginnerTutorial.ClickHint;if not h.Visible or h.Hand.UIScale.Scale<.86 then break end end;shot('05_open')
-- 5. Opened, away from home: the BASE button.
bag:Destroy();tool:Destroy();slotLabels[1].Text='1   🌱'
local seed=new('Tool');seed.Name='Apple Seed';seed:SetAttribute('GardenSeed',true);seed:SetAttribute('SeedInventoryId','1_2');seed.Parent=character
serverStep={Kind='Garden',Target=V3(-20,.5,10)};root.CFrame=CF(150,3,40);follow(V3(150,3,40),V3(150,3,-20));player:SetAttribute('TutorialStep',6);settle(60*3+20);pressed();if not phone then shot('06_base')end
-- 6. Home: plant it.
root.CFrame=CF(-6,3,-6);follow(V3(-6,3,-6),V3(-20,3,10));settle(60);for _=1,40 do frames(1);if pg.BeginnerTutorial.TapSpot.Hand.Position.Y.Offset>-10 then break end end;if not phone then shot('07_plant')end
-- 7. Planted: 10 seconds.
seed:Destroy();slotLabels[1].Text='1';plantOn=true
serverStep={Kind='Crop',Target=V3(-20,3,10),ReadyAt=1000010,ReadyIn=10,Ripe=false};player:SetAttribute('TutorialStep',7);settle(60);settle(60*4);if not phone then shot('08_grow')end
-- 8. Ripe: pick it.
fruitRipe=true;settle(60*6+30);if not phone then shot('09_harvest')end
-- 9. Sell it at the market.
serverStep={Kind='Sell',Target=V3(0,3,-150)};root.CFrame=CF(4,3,-118);follow(V3(4,3,-118),V3(0,3,-150));player:SetAttribute('TutorialStep',9);settle(60*2);if not phone then shot('10_market')end
pg:SetAttribute('SeedMenu','Economy');market.Visible=true;harvestMenu.Visible=true;settle(60);pressed();if not phone then shot('11_sell')end
pg:SetAttribute('SeedMenu',nil);market.Visible=false;harvestMenu.Visible=false
-- 10. The treadmill: faster, and a bonus roll every 6:00.
serverStep={Kind='Treadmill',Target=V3(12,1,-6)};plantOn=false;root.CFrame=CF(2,3,-22);follow(V3(2,3,-22),V3(12,3,-6));player:SetAttribute('TutorialStep',10);settle(60*2);shot('12_treadmill')
-- The end: 🏆 + 🎁 (the free pack), confetti.
player:SetAttribute('StarterPackClaimed',false);frames(2);player:SetAttribute('TreadmillTraining',true);frames(24);if not phone then shot('13_finish')end
