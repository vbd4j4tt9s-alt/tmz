--!nocheck
-- R151: the DAILY button's and DAILY tabs' red badges are the SAME component as the Index's (NotifyBadge151; DailyRewardsClient carried an identical copy of the R138 badge). The real TravelButtons +
-- DailyRewardsClient on the Roblox mock with the layout engine of layout_indexpacks.luau (the fake server of the R140 client test): the badge counts what is waiting ("3", "9+"), is the polished badge
-- (revision 151, circle, gradient, ring, shadow, centred count), is not clipped by anything on nine screens, the tab dots sit inside their tabs, and Reduced Motion stops the pulse.
local W=require('./world');local F=require('./fixtures');local R=W.R
local L=require('./layout_indexpacks')(R)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
F.packAssets(W)
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end,Transaction=function()end})
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
for _,n in ipairs({'RequestBaseTeleport','RequestTrackTeleport'})do local e=R.new('RemoteEvent');e.Name=n;e.Parent=remotes end
local Badge=W.module('NotifyBadge151')
local srv={Step=0,Ready=true,Quests={{Key='Steal',Text='Steal 3 packs',Icon='🎒',Goal=3,Progress=3,Claimed=false,Gems=2},{Key='Plant',Text='Plant 3 seeds',Icon='🌱',Goal=3,Progress=1,Claimed=false,Gems=2},{Key='Sell',Text='Sell 5 fruit',Icon='💰',Goal=5,Progress=0,Claimed=false,Gems=2}}}
local request=R.new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
function request.InvokeServer(_,action,value)
 if action~='Daily'then return {Success=false}end
 return {Success=true,Login={Ready=srv.Ready,Next=srv.Ready and srv.Step+1 or srv.Step,Claimed=srv.Step},Quests=srv.Quests,ResetIn=5*3600+12*60,Day=1}
end
local Social=W.service('SocialService');function Social.CanSendGameInviteAsync()return true end;function Social.PromptGameInvite()end
local ENS=W.service('ExperienceNotificationService');function ENS.CanPromptOptInAsync()return true end;function ENS.PromptOptIn()end
local Gui=W.Gui
local function inset(l,r,top,rowH)Gui.TopbarInset={__type='Rect',Min=R.Vector2.new(l,top),Max=R.Vector2.new(r,top+rowH),Width=r-l,Height=rowH}end
inset(120,1280,0,52)
local screen={1280,720}
local function frames(n)for _=1,n do for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')then L.lay(g,screen[1],screen[2])end end;W.frames(1)end end
local function resize(w,h)screen={w,h};frames(3)end
player:SetAttribute('TutorialDone',false)
local tb=R.new('LocalScript');tb.Name='TravelButtons';check(pcall(W.load,'TravelButtons',tb),'TravelButtons loads')
local sc=R.new('LocalScript');sc.Name='DailyRewardsClient';local okD,errD=pcall(W.load,'DailyRewardsClient',sc);check(okD,'DailyRewardsClient loads: '..tostring(errD))
frames(10)
local travel=pg.TravelButtons;local icons=travel.TopIcons
local daily=icons.Daily:FindFirstChild('DailyButton')
check(daily~=nil,'the DAILY button sits in its top bar slot')
local function badge()return daily:FindFirstChild('RewardBadge')end
-- 1. what it counts -------------------------------------------------------------------------------------------------------------------------------------
check(badge()~=nil and not badge().Visible,'nothing waiting: the badge is there and hidden')
player:SetAttribute('DailyLoginReady',true);player:SetAttribute('DailyQuestsReady',2);frames(3)
local b=badge()
check(b and b.Visible and b.Count.Text=='3'and b:GetAttribute('NotifyBadge')==151,'a login reward + 2 quests: the badge shows 3 and is a NotifyBadge151')
player:SetAttribute('DailyQuestsReady',12);frames(3)
check(badge().Count.Text=='9+','thirteen things waiting: "9+"')
player:SetAttribute('DailyQuestsReady',2);frames(3)
check(badge().Count.Text=='3','back to three')
-- 2. the same badge as the Index's (the structure: back to front) --------------------------------------------------------------------------------
do
 local names={};for _,c in ipairs(b:GetChildren())do names[#names+1]=c.Name end
 check(table.concat(names,',')=='UIAspectRatioConstraint,Pop,Glow,ShadowSoft,Shadow,Disc,Count','the badge is built exactly like the Index\'s: '..table.concat(names,','))
 local disc=b:FindFirstChild('Disc');local corner=disc:FindFirstChildOfClass('UICorner')
 check(corner.CornerRadius.Scale==1 and disc:FindFirstChildOfClass('UIGradient')and disc:FindFirstChildOfClass('UIStroke').Color.R==1,'a circle with a gradient and a white ring')
 local src=require('./rs_bundle').DailyRewardsClient
 check(not src:find('local function badge%(')and select(2,src:gsub('Badge%.Make%(',''))==3,'DailyRewardsClient makes its three badges with NotifyBadge151.Make and has no copy of the old one')
end
-- 3. not clipped, on nine screens --------------------------------------------------------------------------------------------------------------------------
local function reach(o)return L.badgeReach(Badge,o)end
local overshoot=L.overshoot
local SCREENS={{1920,1080,140,1920},{1280,720,120,1280},{1024,768,120,1024},{844,390,150,800},{667,375,140,667},{430,932,120,430},{390,844,110,390},{375,667,110,375},{360,640,110,360}}
local worst=0
for _,s in ipairs(SCREENS)do
 inset(s[3],s[4],0,s[2]>500 and 52 or 44);resize(s[1],s[2])
 local o=badge();local a=reach(o);local cut=0
 for _,c in ipairs(L.clippers(o))do cut=math.max(cut,overshoot(a,L.rect(c)))end
 worst=math.max(worst,cut)
 check(cut==0,s[1]..'x'..s[2]..': the DAILY badge is not clipped (cut '..cut..' px)')
 local br=L.rect(daily)
 check(overshoot(a,{x0=0,y0=0,x1=s[1],y1=s[2]})==0,s[1]..'x'..s[2]..': it is on screen (button '..string.format('%.0f,%.0f %.0fx%.0f',br.x0,br.y0,br.x1-br.x0,br.y1-br.y0)..', badge reach '..string.format('%.1f,%.1f..%.1f,%.1f',a.x0,a.y0,a.x1,a.y1)..')')
 local r=L.rect(o);check(near(r.x1-r.x0,r.y1-r.y0)and near(r.x1-r.x0,20),s[1]..'x'..s[2]..': a 20 px square (a circle)')
end
inset(120,1280,0,52);resize(1280,720)
-- 4. the window's tab dots --------------------------------------------------------------------------------------------------------------------------------
daily.Activated:Fire();frames(6)
local panel=pg.DailyRewardsGui.DailyPanel
local loginTab,questTab=panel.LoginTab,panel.QuestsTab
local dl,dq=loginTab:FindFirstChild('RewardDot'),questTab:FindFirstChild('RewardDot')
check(dl and dq and dl.Visible and dq.Visible and dl:GetAttribute('NotifyBadge')==151 and dl.Count.Text==''and dq.Count.Text=='','the LOGIN and QUESTS tabs carry a dot each (a reward waiting, quests ready): the same badge, no text')
for _,pair in ipairs({{dl,loginTab},{dq,questTab}})do
 local d,t=L.rect(pair[1]),L.rect(pair[2])
 check(d.x0>=t.x0-1e-6 and d.y0>=t.y0-1e-6 and d.x1<=t.x1+1e-6 and d.y1<=t.y1+1e-6,'the '..pair[2].Name..' dot sits fully inside its tab')
end
player:SetAttribute('DailyQuestsReady',0);frames(3)
check(not dq.Visible and dl.Visible,'no quest ready: the QUESTS dot goes, the LOGIN dot stays')
-- 5. motion --------------------------------------------------------------------------------------------------------------------------------------------
check(Badge.Pulsing(badge())and Badge.Pulsing(dl)and not Badge.Pulsing(dq),'a visible badge pulses, a hidden one does not')
Gui.ReducedMotionEnabled=true;frames(2)
check(not Badge.Pulsing(badge())and not Badge.Pulsing(dl),'Reduced Motion: the pulses stop')
Gui.ReducedMotionEnabled=false
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
