--!nocheck
-- R125 card -> R151 (owner: "for the offline text when players press esc just make it a simple big rainbow text that says
-- 'Plants grow offline'"): the real OfflineGrowthNotice under the Roblox mock. Shown only while the Roblox menu is open (and
-- nothing runs while it is closed), the owner's words, rainbow + outline and no card, the rainbow moves (still with Reduced
-- Motion), and on 12 screens (computers, tablets, phones both ways, console) the line is big, inside the safe area and, where
-- the screen has room, clear of the Roblox menu panel.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.Gui.MenuOpened=R.signal();W.Gui.MenuClosed=R.signal();W.Gui.MenuIsOpen=false
local inset=R.Vector2.new(0,58);function W.Gui.GetGuiInset()return inset,R.Vector2.new(0,0)end
local tenFoot=false;function W.Gui.IsTenFootInterface()return tenFoot end
local Run=W.Run
local function live(sig)local n=0;for _,c in ipairs(sig._c)do if c.Connected then n+=1 end end;return n end
local script1=R.new('LocalScript')
W.load('OfflineGrowthNotice',script1)
local gui=pg:FindFirstChild('OfflineGrowthNotice')
local line=gui and gui:FindFirstChild('Line');local title=line and line:FindFirstChild('Title');local sprout=line and line:FindFirstChild('Sprout')
local rainbow=title and title:FindFirstChild('Rainbow');local outline=title and title:FindFirstChild('Outline')
-- 1. Built once, hidden, idle.
check(gui and gui.Enabled==false and gui.ResetOnSpawn==false,'hidden while the menu is closed, and kept across respawns (ResetOnSpawn off)')
check(gui.ScreenInsets==R.Enum.ScreenInsets.DeviceSafeInsets and gui.DisplayOrder>10000,'inside the device safe area, above every game GUI (DisplayOrder '..tostring(gui.DisplayOrder)..')')
local rs0=live(Run.RenderStepped)
check(rs0==0 and live(gui:GetPropertyChangedSignal('AbsoluteSize'))==0,'nothing runs while the menu is closed (no frame or resize listeners)')
-- 2. The words, the look.
check(title and title.Text=='Plants grow offline'and sprout and sprout.Text=='🌱','the owner\'s words: "Plants grow offline", with a 🌱')
check(title.Font==R.Enum.Font.FredokaOne and sprout.Font==R.Enum.Font.FredokaOne,'chunky FredokaOne')
local panels=0;for _,d in ipairs(gui:GetDescendants())do if d:IsA('GuiObject')and(d.BackgroundTransparency or 0)<1 then panels+=1 end end
check(panels==0 and gui:FindFirstChildOfClass('Frame')==line and not line:FindFirstChildOfClass('UICorner'),'no card or panel: nothing has a background')
check(outline and outline.ClassName=='UIStroke'and outline.Color.R<.15 and outline.Color.G<.15 and outline.Color.B<.2,'a dark outline for contrast')
local function stops()local out={};for _,k in ipairs(rainbow.Color.A)do out[#out+1]={T=k.T,C=k.V}end;return out end
local function hue(c)local mx,mn=math.max(c.R,c.G,c.B),math.min(c.R,c.G,c.B);if mx-mn<1e-6 then return 0 end
 local h;if mx==c.R then h=((c.G-c.B)/(mx-mn))%6 elseif mx==c.G then h=(c.B-c.R)/(mx-mn)+2 else h=(c.R-c.G)/(mx-mn)+4 end;return h/6 end
local s=stops();local hues={};for _,k in ipairs(s)do hues[#hues+1]=hue(k.C)end
local spread=0;for i=1,6 do local d=math.abs(hues[i+1]-hues[i]);d=math.min(d,1-d);spread+=d end
check(#s==7 and s[1].T==0 and s[7].T==1 and spread>.9,'a rainbow: 7 stops round the whole colour wheel ('..string.format('%.2f',spread)..' of a turn)')
check(math.abs(hues[1]-hues[7])<.01 or math.abs(math.abs(hues[1]-hues[7])-1)<.01,'(first and last stop the same hue, so it loops without a seam)')
local white=title.TextColor3;check(white.R==1 and white.G==1 and white.B==1,'(white letters, so the gradient shows its true colours)')
-- 3. Opening, moving, closing.
W.Gui.MenuOpened:Fire()
check(gui.Enabled==true,'shown when the Roblox menu opens')
check(live(Run.RenderStepped)==1,'one frame listener while open')
local before=hue(stops()[1].C);W.frames(30)
local after=hue(stops()[1].C)
check(math.abs(after-before)>.02,'the rainbow slides along the letters while the menu is open ('..string.format('%.3f -> %.3f',before,after)..')')
W.Gui.MenuClosed:Fire()
check(gui.Enabled==false and live(Run.RenderStepped)==0 and live(gui:GetPropertyChangedSignal('AbsoluteSize'))==0,'hidden when it closes, and every listener is gone')
local still=hue(stops()[1].C);W.frames(30);check(hue(stops()[1].C)==still,'(nothing changes while closed)')
for _=1,3 do W.Gui.MenuOpened:Fire();W.Gui.MenuClosed:Fire()end
check(live(Run.RenderStepped)==0,'opening and closing many times leaves nothing behind')
W.Gui.MenuOpened:Fire();W.Gui.MenuOpened:Fire();check(live(Run.RenderStepped)==1,'a second MenuOpened does not add a second listener')
W.Gui.MenuClosed:Fire()
-- 4. Reduced Motion: a still rainbow, no frame work.
W.Gui.ReducedMotionEnabled=true;W.Gui.MenuOpened:Fire()
local a=stops();W.frames(30);local b=stops()
local same=true;for i=1,7 do if hue(a[i].C)~=hue(b[i].C)then same=false end end
check(gui.Enabled and live(Run.RenderStepped)==0 and same,'Reduced Motion: shown with a still rainbow and no frame listener')
check(math.abs(hue(b[1].C))<.02 or math.abs(hue(b[1].C)-1)<.02,'(starting at red)')
W.Gui.MenuClosed:Fire();W.Gui.ReducedMotionEnabled=false
-- 5. If MenuOpened / MenuClosed do not fire, GuiService.MenuIsOpen still drives it.
W.Gui.MenuIsOpen=true;check(gui.Enabled==true,'MenuIsOpen turning true alone shows it (fallback)')
W.Gui.MenuIsOpen=false;check(gui.Enabled==false and live(Run.RenderStepped)==0,'and turning false hides it')
-- 6. The menu was already open when the script started (it loads after the player pressed Esc).
W.Gui.MenuIsOpen=true
local script2=R.new('LocalScript');W.load('OfflineGrowthNotice',script2)
local gui2=pg:FindFirstChild('OfflineGrowthNotice')
check(gui2 and gui2~=gui and gui2.Enabled==true and gui.Parent==nil,'a script that starts with the menu open shows it at once (the old copy is replaced)')
script2:Destroy();check(gui2.Parent==nil and live(Run.RenderStepped)==0,'a destroyed script takes its GUI and listeners with it')
W.Gui.MenuIsOpen=false
local script3=R.new('LocalScript');W.load('OfflineGrowthNotice',script3);gui=pg:FindFirstChild('OfflineGrowthNotice');line=gui.Line;title=line.Title
-- 7. Screens. The panel model is Roblox's own numbers (CoreScripts SettingsHub/Theme) for the screen class.
local cam=W.workspace.CurrentCamera
local function panel(w,h,touch,tv)
 if tv then local ph=math.max(150,math.min(800,h*.86-200))+214;return h/2+10-ph/2,h/2+10+ph/2 end
 if touch and(h<500 or w<700)then return 0,h end
 local ph=math.max(150,math.min(600,h*.9-120))+134;return h/2+10-ph/2,h/2+10+ph/2
end
local screens={
 {'computer 1920x1080',1920,1080,false,{0,0,0,0},'clear',80},
 {'computer 1536x864',1536,864,false,{0,0,0,0},'clear',36},
 {'computer 1440x900',1440,900,false,{0,0,0,0},'clear',44},
 {'computer 2560x1440',2560,1440,false,{0,0,0,0},'clear',90},
 {'laptop 1366x768',1366,768,false,{0,0,0,0},'edge',30},
 {'iPad 1024x768 (landscape)',1024,768,true,{0,0,0,20},'edge',30},
 {'iPad Pro 1366x1024',1366,1024,true,{0,0,0,20},'clear',70},
 {'tablet 800x1280 (portrait)',800,1280,true,{0,24,0,20},'clear',30},
 {'phone 844x390 (landscape)',844,390,true,{47,0,47,21},'edge',26},
 {'phone 390x844 (portrait)',390,844,true,{0,47,0,34},'edge',26},
 {'small phone 360x640',360,640,true,{0,24,0,0},'edge',24},
 {'console 1920x1080',1920,1080,false,{96,54,96,54},'edge',30,true},
}
for _,sc in ipairs(screens)do
 local name,w,h,touch,ins,want,minSize,tv=table.unpack(sc)
 cam.ViewportSize=R.Vector2.new(w,h);W.UIS.TouchEnabled=touch;tenFoot=tv==true
 local at=R.Vector2.new(ins[1],ins[2]);local room=R.Vector2.new(w-ins[1]-ins[3],h-ins[2]-ins[4])
 gui.AbsolutePosition=at;gui.AbsoluteSize=room
 W.Gui.MenuOpened:Fire()
 local size=line.Size;local pos=line.Position
 local cx,cy=at.X+pos.X.Offset,at.Y+pos.Y.Offset;local lw,lh=size.X.Offset,size.Y.Offset
 local left,right,topY,bottomY=cx-lw/2,cx+lw/2,cy-lh/2,cy+lh/2
 local ptop,pbottom=panel(w,h,touch,tv)
 local inside=left>=at.X-.5 and right<=at.X+room.X+.5 and topY>=at.Y-.5 and bottomY<=at.Y+room.Y+.5
 local clear=bottomY<=ptop+.5 or topY>=pbottom-.5
 local ts=gui:GetAttribute('TextSize')
 check(inside,name..': inside the safe area ('..math.floor(left)..','..math.floor(topY)..' to '..math.floor(right)..','..math.floor(bottomY)..')')
 check(lw<=room.X*.92+1,name..': at most 92% of the safe width ('..lw..' of '..room.X..')')
 check(ts and ts>=minSize and title.TextSize==ts,name..': big text, '..tostring(ts)..' px (at least '..minSize..')')
 if want=='clear'then check(clear and gui:GetAttribute('Placement')~='edge',name..': clear of the Roblox menu panel ('..gui:GetAttribute('Placement')..', panel '..math.floor(ptop)..'-'..math.floor(pbottom)..')')
 else check(gui:GetAttribute('Placement')=='edge'and bottomY>=at.Y+room.Y-14-lh,name..': no room around the panel, so it sits on the bottom edge (seen through the menu)')end
 check(math.abs(cx-(at.X+room.X/2))<=1,name..': centred')
 W.Gui.MenuClosed:Fire()
end
-- 8. Turning the phone while the menu is open re-fits it.
cam.ViewportSize=R.Vector2.new(390,844);W.UIS.TouchEnabled=true;gui.AbsolutePosition=R.Vector2.new(0,47);gui.AbsoluteSize=R.Vector2.new(390,763)
W.Gui.MenuOpened:Fire();local portrait=line.Size.X.Offset
cam.ViewportSize=R.Vector2.new(844,390);gui.AbsolutePosition=R.Vector2.new(47,0);gui.AbsoluteSize=R.Vector2.new(750,369)
check(line.Size.X.Offset~=portrait and line.Position.X.Offset==375,'rotating the phone with the menu open re-fits the line ('..portrait..' -> '..line.Size.X.Offset..' px wide)')
W.Gui.MenuClosed:Fire();gui.AbsoluteSize=R.Vector2.new(1280,720);check(live(gui:GetPropertyChangedSignal('AbsoluteSize'))==0,'(and stops listening once closed)')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
