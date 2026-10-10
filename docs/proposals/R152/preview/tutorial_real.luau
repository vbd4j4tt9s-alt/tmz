-- R152 tutorial preview (not a test): appended by run_tutorial_preview.sh to the setup part of tools/tests/test_tutorial.luau.
-- Plays the REAL BeginnerTutorial through every step on the mock (VIEW_NAME = 'pc' 1280x720 mouse, 'phone' 844x390 touch) and
-- prints one line per moment: SCENE <moment> <layer> <x> <y> <json> (layers: hud = stand-in top bar + hotbar, tut = the
-- tutorial's ScreenGui, tap = its pressing-hand layer (no insets), goal / spot = its world billboards, placed at the mock camera's projection of the goal). Like the game, the
-- tutorial's ScreenGui (CoreUISafeInsets) starts below Roblox's top bar row, where BASE / TRACK sit (INSET px).
local dump=require('./dump_tree')
modules[RS.GardenTheme].Corner=function(p,r)local c=new('UICorner');c.CornerRadius=R.UDim.new(0,r or 4);c.Parent=p;return c end
local phone=VIEW_NAME=='phone'
local W,H=phone and 844 or 1280,phone and 390 or 720;local INSET=phone and 44 or 58
VIEW=R.Vector2.new(W,H-INSET)
if phone then UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch end
function camera.WorldToViewportPoint(_,p)if phone then return V3(422+p.X*2.6,250-p.Z*1.6,5),true end;return V3(640+p.X*4,470-p.Z*3,5),true end
-- Stand-in HUD: BASE / TRACK in the top bar row, the hotbar, the MENU button (the real scripts are not run here).
local hud=new('ScreenGui');hud.Name='PreviewHud';hud.Parent=pg
local function box(name,x,y,w,h,color,label,parent)
 local f=new(label and'TextLabel'or'Frame');f.Name=name;f.Position=R.UDim2.fromOffset(x,y);f.Size=R.UDim2.fromOffset(w,h);f.BackgroundColor3=color;f.BackgroundTransparency=.05;f.Parent=parent or hud
 local c=new('UICorner');c.CornerRadius=R.UDim.new(0,9);c.Parent=f
 if label then f.Text=label;f.TextSize=phone and 15 or 17;f.TextColor3=R.Color3.new(1,1,1);f.TextStrokeColor3=R.Color3.new(0,0,0);f.TextStrokeTransparency=.4;f.Font=R.Enum.Font.FredokaOne end
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
local function shot(moment)
 local gui=pg.BeginnerTutorial
 print('SCENE '..moment..' hud 0 0 '..dump(hud,W,H))
 print('SCENE '..moment..' tut 0 '..INSET..' '..dump(gui,W,H-INSET))
 print('SCENE '..moment..' tap 0 0 '..dump(pg.BeginnerTutorialTap,W,H))
 for _,name in ipairs({'Goal','TapSpot'})do
  local bb=gui[name]
  if bb.Enabled and bb.Adornee then
   local at=camera:WorldToViewportPoint(bb.Adornee.CFrame.Position+V3(0,bb.StudsOffsetWorldSpace.Y,0))
   print('SCENE '..moment..' '..(name=='Goal'and'goal'or'spot')..' '..math.floor(at.X-bb.Size.X.Offset/2)..' '..math.floor(at.Y-bb.Size.Y.Offset*.85)..' '..dump(bb,bb.Size.X.Offset,bb.Size.Y.Offset))
  end
 end
end
player:SetAttribute('TutorialMask',0);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',1)
root.CFrame=CF(0,3,0);serverStep={Kind='Pack',Target=V3(phone and 70 or 70,3,95)}
local scriptInst=new('LocalScript');scriptInst.Name='BeginnerTutorial'
local ok,err=pcall(load,'BeginnerTutorial',scriptInst);if not ok then error(err)end
pg.BeginnerTutorial.AbsolutePosition=R.Vector2.new(0,INSET)
local function settle(n)frames(n or 120)end
local function pressed()for _=1,40 do frames(1);local g=pg.BeginnerTutorialTap.TapHand;if not g.Visible or g.Hand.Press.Scale<.9 then return end end end
settle();pressed();shot('1_offtrack')
root.CFrame=CF(0,3,60);frames(8);shot('2_nice')
settle(90);shot('3_grab')
serverStep={Kind='Safety',Target=V3(-60,3,38)};player:SetAttribute('ChestChaseSeedCarrying',true);settle();shot('4_home')
player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind=nil,Target=nil};root.CFrame=CF(0,3,20)
local tool=new('Tool');tool.Name='Forest Pack';tool:SetAttribute('SeedPackTool',true);tool.Parent=backpack
dock.Slot1.ItemName.Text='Forest Pack';slotLabels[1].Text='1   🎁';player:SetAttribute('TutorialStep',3);settle();pressed();shot('5_open')
tool.Parent=character
local bag=new('Model');bag.Name='CarriedSeed';bag:SetAttribute('SeedPackCarry',true);bag:SetAttribute('PackClicksRequired',5);bag:SetAttribute('PackClickCount',2)
local part=new('Part');part.CFrame=CF(-8,4,-20);part.Parent=bag;bag.PrimaryPart=part;bag.Parent=character
settle();for _=1,60 do frames(1);local h=pg.BeginnerTutorial.ClickHint;if not h.Visible or h.Hand.UIScale.Scale<.86 then break end end;shot('6_tap')
bag:Destroy();tool:Destroy();slotLabels[1].Text='1'
local seed=new('Tool');seed.Name='Carrot Seed';seed:SetAttribute('GardenSeed',true);seed.Parent=character
serverStep={Kind='Garden',Target=V3(60,3,40)};player:SetAttribute('TutorialStep',4);settle(240);shot('7_plant')
root.CFrame=CF(0,3,80);settle();pressed();shot('8_gohome')
root.CFrame=CF(0,3,20);settle();seed:Destroy()
serverStep={Kind='Treadmill',Target=V3(-50,3,45)};player:SetAttribute('TutorialStep',5);settle();shot('9_faster')
player:SetAttribute('StarterPackClaimed',false);player:SetAttribute('TreadmillTraining',true);frames(20);shot('10_finish')
