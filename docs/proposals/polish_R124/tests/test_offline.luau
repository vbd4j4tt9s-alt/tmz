--!nocheck
-- R125: "plants grow offline" card while the Roblox menu is open.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.Gui.MenuOpened=R.signal();W.Gui.MenuClosed=R.signal();W.Gui.MenuIsOpen=false
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local function plot(owner,count)local p=R.new('Part');p:SetAttribute('GardenOwnerId',owner);p:SetAttribute('GardenPlantCount',count);p.Parent=map;return p end
local mine=plot(7,0);plot(99,12)
W.load('OfflineGrowthNotice',R.new('LocalScript'))
local gui=pg:FindFirstChild('OfflineGrowthNotice')
check(gui and gui.Enabled==false,'hidden while the menu is closed')
W.Gui.MenuOpened:Fire();check(gui.Enabled==true,'shown when the Roblox menu opens')
check(gui.Card.Title.Text:find('OFFLINE',1,true)and gui.Card.Detail.Text:find('Plant seeds',1,true),'no plants: tells to plant before leaving ('..gui.Card.Detail.Text..')')
W.Gui.MenuClosed:Fire();check(gui.Enabled==false,'hidden when the menu closes')
mine:SetAttribute('GardenPlantCount',6);W.Gui.MenuOpened:Fire()
check(gui.Card.Detail.Text:find('Your 6 plants keep growing',1,true),'counts only my plants: '..gui.Card.Detail.Text)
W.frames(10);W.Gui.MenuClosed:Fire()
mine:SetAttribute('GardenPlantCount',1);W.Gui.MenuOpened:Fire();check(gui.Card.Detail.Text:find('Your 1 plant keeps growing',1,true),'singular wording')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
