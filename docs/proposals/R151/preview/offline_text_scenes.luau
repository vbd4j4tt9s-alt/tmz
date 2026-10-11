--!nocheck
-- R151 preview helper (not a test): runs the REAL OfflineGrowthNotice under the Roblox mock (polish_R124 world), opens the Roblox menu on a
-- 1920x1080 computer, an 844x390 landscape phone and a 390x844 portrait phone (with their safe-area insets), lets the rainbow move for a
-- moment and prints each GUI tree (R150's dump_tree.luau): SCENE <name> <screen w> <screen h> <safe x> <safe y> <json>.
-- The text width follows Fredoka One as measured in Chromium ("Plants grow offline" = 9.16 x the text size).
local W=require('./world');local R=W.R;local dump=require('./dump_tree')
local Players=W.service('Players');local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.Gui.MenuOpened=R.signal();W.Gui.MenuClosed=R.signal();W.Gui.MenuIsOpen=false
function W.Gui.GetGuiInset()return R.Vector2.new(0,58),R.Vector2.new(0,0)end
local TS=W.service('TextService');function TS.GetTextSize(_,text,size,_,bounds)return R.Vector2.new(math.min(bounds.X,utf8.len(text)/19*9.16*size),size*1.2)end
W.load('OfflineGrowthNotice',R.new('LocalScript'))
local gui=pg.OfflineGrowthNotice;local cam=W.workspace.CurrentCamera
for _,l in ipairs({gui.Line.Title,gui.Line.Sprout})do l.TextStrokeColor3=R.Color3.new(0,0,0)end -- (dump_tree reads it; unused: TextStrokeTransparency stays 1)
for _,sc in ipairs({{'desktop',1920,1080,false,0,0,0,0},{'phone',844,390,true,47,0,47,21},{'portrait',390,844,true,0,47,0,34}})do
 local name,w,h,touch,l,t,r,b=table.unpack(sc)
 cam.ViewportSize=R.Vector2.new(w,h);W.UIS.TouchEnabled=touch
 gui.AbsolutePosition=R.Vector2.new(l,t);gui.AbsoluteSize=R.Vector2.new(w-l-r,h-t-b)
 W.Gui.MenuOpened:Fire();W.frames(20)
 print('SCENE '..name..' '..w..' '..h..' '..l..' '..t..' '..dump(gui,w-l-r,h-t-b))
 print('INFO '..name..' size='..tostring(gui:GetAttribute('TextSize'))..' placement='..tostring(gui:GetAttribute('Placement')))
 W.Gui.MenuClosed:Fire()
end
