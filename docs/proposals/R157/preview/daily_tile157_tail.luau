-- Appended (by daily_tile157.sh) to the setup part of docs/proposals/R140/tests/test_daily_client.luau: prints one GUI dump per window
-- ('JSON <name> {...}') for render_gui138.py. The mystery pack's picture is a ViewportFrame the renderer cannot draw: its slot is dumped as 'VP:Art'
-- (a LOGIN day card) / 'VP:PackTile' (a QUESTS row) and daily_tile157.py pastes a stand-in pack shape there.
local dump=require('./dump_gui')
local function shot(name,g,w,h)print('JSON '..name..' '..dump(g,w,h))end
player:SetAttribute('DailyLoginReady',true);player:SetAttribute('DailyQuestsReady',1);frames(3)
srv.Step=2;srv.Ready=true
inset(120,1280,0,52);resize(1280,720);frames(5)
openWheel(true);daily.Activated:Fire();frames(14)
local panel=pg.DailyRewardsGui.DailyPanel
shot('login',pg.DailyRewardsGui,1280,720)
panel.QuestsTab.Activated:Fire();frames(14);shot('quests',pg.DailyRewardsGui,1280,720)
