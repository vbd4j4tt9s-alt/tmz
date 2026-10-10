-- Appended (by run.sh) to the setup part of ../tests/test_daily_client.luau: prints one GUI dump per moment
-- ('JSON <name> {...}') for render_gui138.py. The 3D Mech pack picture and the gem artwork are images the renderer
-- cannot draw, so this preview shows their emoji stand-ins (🤖 / 💎); the game shows the real pack and gem art.
local dump=require('./dump_gui')
local function shot(name,g,w,h)print('JSON '..name..' '..dump(g,w,h))end
player:SetAttribute('DailyLoginReady',true);player:SetAttribute('DailyQuestsReady',1)
player:SetAttribute('FriendsInServer',2);player:SetAttribute('FriendSpeedBoost',1.2);frames(3)
inset(120,1280,0,52);resize(1280,720);frames(5);shot('top_desktop',pg.TravelButtons,1280,720)
inset(110,390,0,44);resize(390,844);frames(5);shot('top_phone',pg.TravelButtons,390,844)
srv.Step=2;srv.Ready=true
local daily=pg.TravelButtons.TopIcons.Daily.DailyButton
inset(120,1280,0,52);resize(1280,720);daily.Activated:Fire();frames(8)
local panel=pg.DailyRewardsGui.DailyPanel
shot('login_desktop',pg.DailyRewardsGui,1280,720)
panel.QuestsTab.Activated:Fire();frames(5);shot('quests_desktop',pg.DailyRewardsGui,1280,720)
panel.Header.Close.Activated:Fire();frames(3)
resize(390,844);daily.Activated:Fire();frames(8);panel.LoginTab.Activated:Fire();frames(5);shot('login_phone',pg.DailyRewardsGui,390,844)
panel.QuestsTab.Activated:Fire();frames(5);shot('quests_phone',pg.DailyRewardsGui,390,844)
panel.Header.Close.Activated:Fire();frames(3)
resize(844,390);daily.Activated:Fire();frames(8);panel.LoginTab.Activated:Fire();frames(5);shot('login_landscape',pg.DailyRewardsGui,844,390)
srv.Step=6;srv.Ready=true;panel.QuestsTab.Activated:Fire();panel.LoginTab.Activated:Fire();player:SetAttribute('DailyRevision',9);frames(8)
resize(1280,720);frames(5);shot('login_day7',pg.DailyRewardsGui,1280,720)
