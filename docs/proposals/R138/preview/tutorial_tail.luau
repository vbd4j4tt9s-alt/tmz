-- Appended (by run.sh) to the setup part of tools/tests/test_tutorial.luau: plays the tutorial on the mock and prints
-- one GUI dump per moment ('JSON <name> {...}') for render_gui138.py. Works with the R137 tutorial too (fewer shots).
local dump=require('./dump_gui')
player:SetAttribute('TutorialMask',0);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',1)
local scriptInst=new('LocalScript');scriptInst.Name='BeginnerTutorial'
local ok,err=pcall(load,'BeginnerTutorial',scriptInst);if not ok then error(err)end
frames(60)
local gui=pg:FindFirstChild('BeginnerTutorial')
local function shot(name)print('JSON '..name..' '..dump(gui,1280,720))end
shot('welcome')
gui.Welcome.Go.Activated:Fire();frames(200);shot('step1')
serverStep={Kind='Safety',Target=V3(0,3,-20)};player:SetAttribute('ChestChaseSeedCarrying',true);frames(200);shot('step2')
player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind=nil,Target=nil}
local tool=new('Tool');tool.Name='Forest Pack';tool:SetAttribute('SeedPackTool',true);tool.Parent=backpack
dock.Slot2.ItemName.Text='Forest Pack';player:SetAttribute('TutorialStep',3);frames(200);shot('step3')
tool.Parent=character;player:SetAttribute('ChestChaseSeedCarrying',false)
local bag=new('Model');bag.Name='CarriedSeed';bag:SetAttribute('SeedPackCarry',true);bag:SetAttribute('PackClicksRequired',5);bag:SetAttribute('PackClickCount',2)
local part=new('Part');part.CFrame=CF(-30,4,10);part.Parent=bag;bag.PrimaryPart=part;bag.Parent=character
frames(200)
for _=1,60 do frames(1);local h=gui:FindFirstChild('ClickHint');if not h or h.Hand.UIScale.Scale<.86 then break end end
shot('click')
bag:Destroy()
player:SetAttribute('TutorialStep',4);serverStep={Kind='Garden',Target=V3(-20,3,10)};frames(200);shot('step4')
serverStep={Kind=nil,Target=nil};player:SetAttribute('TutorialStep',5);frames(30);shot('slide1')
for _=1,60*30 do frames(1);if player:GetAttribute('TutorialDone')then break end end
frames(20);shot('finish')
