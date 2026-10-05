--!nocheck
-- R140 (updated for the live R141 numbers: days 1-4 RANDOM PACK, day 5 +2, day 6 +3, day 7 MECH PACK; quests 2 Gems
-- each, "DAILY LIMIT" for blocked ones): the real TravelButtons + DailyRewardsClient on the mock. The 🎁 DAILY and 👥 INVITE squares sit right of
-- TRACK in the top bar row on every screen (or just under it on very narrow ones), never over BASE / TRACK or off
-- screen; the badge counts what is waiting; the DAILY window shows the week and the quests, claims through
-- PremiumRequest 'Daily' (a fake server here), fits phones and computers; it opens by itself once when a login reward
-- waits (after the tutorial); INVITE prompts Roblox's invite; the friend chip shows the boost (R149: a speed GAIN boost, not a walk speed one); the plant-ready opt-in
-- is asked once, after planting, only when the owner has set notifications up.
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
-- R150: a recorder in place of InteractionAudio: the DAILY button names MenuClick (the SeedMenu rule's click is the same cue), a success clicks GemClaim, a refused claim clicks Denied.
local audioLog={};W.stub('InteractionAudio',{Play=function(k)audioLog[#audioLog+1]=k;return true end,Preload=function()end,Transaction=function()end})
local function audioHas(k)for _,x in ipairs(audioLog)do if x==k then return true end end;return false end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
for _,n in ipairs({'RequestBaseTeleport','RequestTrackTeleport'})do local e=R.new('RemoteEvent');e.Name=n;e.Parent=remotes end
local D=W.module('DailyRewards')
-- A fake server for PremiumRequest 'Daily' (the real one is tested in test_daily.luau).
local srv={Step=0,Ready=true,Quests={{Key='Steal',Text='Steal 3 packs',Icon='🎒',Goal=3,Progress=3,Claimed=false,Gems=2},{Key='Plant',Text='Plant 3 seeds',Icon='🌱',Goal=3,Progress=1,Claimed=false,Gems=2},{Key='Sell',Text='Sell 5 fruit',Icon='💰',Goal=5,Progress=0,Claimed=false,Gems=2}}}
local calls={}
local function stateNow()
 return {Success=true,Login={Ready=srv.Ready,Next=srv.Ready and srv.Step+1 or srv.Step,Claimed=srv.Step},Quests=srv.Quests,ResetIn=5*3600+12*60,Day=1}
end
local request=R.new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
function request.InvokeServer(_,action,value)
 calls[#calls+1]={action,value}
 if action~='Daily'then return {Success=false}end
 if value=='State'then return stateNow()end
 if value=='ClaimLogin'then
  if not srv.Ready then local s=stateNow();s.Success=false;s.Message='COME BACK TOMORROW';return s end
  srv.Step+=1;srv.Ready=false;local s=stateNow();s.Message='Collect your Gems.';return s
 end
 if type(value)=='table'then local q=srv.Quests[value.Quest];if q and q.Progress>=q.Goal and not q.Claimed then q.Claimed=true;local s=stateNow();s.Message='Collect your Gems.';return s end end
 local s=stateNow();s.Success=false;s.Message='NO';return s
end
-- Roblox services the script uses.
local invites={};local canInvite=true
local Social=W.service('SocialService')
function Social.CanSendGameInviteAsync()return canInvite end
function Social.PromptGameInvite(_,p,options)invites[#invites+1]=options or'default'end
local optIns={};local ENS=W.service('ExperienceNotificationService')
function ENS.CanPromptOptInAsync()return true end
function ENS.PromptOptIn()optIns[#optIns+1]=true end
local Gui=W.Gui
local function inset(l,r,top,rowH)Gui.TopbarInset={__type='Rect',Min=R.Vector2.new(l,top),Max=R.Vector2.new(r,top+rowH),Width=r-l,Height=rowH}end
inset(120,1280,0,52)
-- Layout emulation (absolute rects from UDim2 + AnchorPoint + UISizeConstraint, as the R113 inventory test).
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  if s and p then
   local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
   local lim=c:FindFirstChildOfClass('UISizeConstraint');if lim and lim.MaxSize then w=math.min(w,lim.MaxSize.X);h=math.min(h,lim.MaxSize.Y)end
   local x=px+p.X.Scale*pw+p.X.Offset-a.X*w;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h
   set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
   lay(c,x,y,w,h)
  end
 end end
end
local screen=R.Vector2.new(1280,720)
local function frames(n)
 for _=1,n do
  for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')then if g.AbsoluteSize~=screen then g.AbsoluteSize=screen end;lay(g,0,0,screen.X,screen.Y)end end
  W.frames(1)
 end
end
local function resize(w,h)screen=R.Vector2.new(w,h);frames(3)end
player:SetAttribute('TutorialDone',false)
local tb=R.new('LocalScript');tb.Name='TravelButtons';local okT,errT=pcall(W.load,'TravelButtons',tb);check(okT,'TravelButtons loads: '..tostring(errT))
local sc=R.new('LocalScript');sc.Name='DailyRewardsClient';local okD,errD=pcall(W.load,'DailyRewardsClient',sc);check(okD,'DailyRewardsClient loads: '..tostring(errD))
frames(10)
local travel=pg.TravelButtons;local icons=travel.TopIcons;local pair=travel.TravelPair
local daily=icons.Daily:FindFirstChild('DailyButton');local invite=icons.Invite:FindFirstChild('InviteButton')
check(daily and invite,'🎁 DAILY and 👥 INVITE sit in the top bar slots')
check(daily and daily.Icon.Text=='🎁'and daily.Caption.Text=='DAILY'and invite.Icon.Text=='👥'and invite.Caption.Text=='INVITE','icons and captions')
-- 1. The top bar row on many screens.
local function rect(o)return {X=o.AbsolutePosition.X,Y=o.AbsolutePosition.Y,W=o.AbsoluteSize.X,H=o.AbsoluteSize.Y}end
local function overlap(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local screens={{1920,1080,140,1920,'desktop 1080p'},{1280,720,120,1280,'desktop 720p'},{1024,768,120,1024,'tablet'},{844,390,150,800,'phone landscape'},
 {667,375,140,667,'small phone landscape'},{430,932,120,430,'big phone portrait'},{390,844,110,390,'phone portrait'},{375,667,110,375,'small phone portrait'},{360,640,110,360,'tiny phone portrait'}}
for _,s in ipairs(screens)do
 inset(s[3],s[4],0,s[2]>500 and 52 or 44);resize(s[1],s[2])
 local base,track,row=rect(pair.BaseButton),rect(pair.TrackButton),rect(icons)
 local d,i=rect(daily),rect(invite)
 local same=math.abs((d.Y+d.H/2)-(track.Y+track.H/2))<2
 local ok=not overlap(d,base)and not overlap(d,track)and not overlap(i,base)and not overlap(i,track)and not overlap(d,i)
 local inside=d.X>=0 and i.X+i.W<=s[1]and d.Y>=0 and d.W>=30 and d.W==d.H
 local right=same and d.X>=track.X+track.W+4 and i.X+i.W<=s[4]-8
 local under=not same and d.Y>=track.Y+track.H and d.X>=s[3]
 check(ok and inside and(right or under),('%s %dx%d: %s (DAILY at %d,%d size %d; TRACK ends %d; Roblox buttons from %d)'):format(s[5],s[1],s[2],same and'right of TRACK'or'under the row',d.X,d.Y,d.W,track.X+track.W,s[4]))
end
inset(120,1280,0,52);resize(1280,720)
-- 2. The badge.
player:SetAttribute('DailyLoginReady',true);player:SetAttribute('DailyQuestsReady',1);frames(2)
local b=daily:FindFirstChild('RewardBadge')
check(b and b.Visible and b.Count.Text=='2','badge: login + 1 quest = 2')
-- 3. The window.
daily.Activated:Fire();frames(5)
local gui=pg.DailyRewardsGui;local panel=gui.DailyPanel
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Daily','DAILY opens the window (SeedMenu = Daily)')
check(daily:GetAttribute('ButtonSound')=='MenuClick','R150: the DAILY button clicks MenuClick (it opens a menu), not the generic Bubble04')
check(not icons.Visible,'the top bar buttons hide while it is open (like the other menus)')
local login=panel.LoginPage;local quests=panel.QuestsPage
check(login.Visible and not quests.Visible,'the LOGIN tab first (a login reward is waiting)')
local cards={};for d=1,7 do cards[d]=login:FindFirstChild('Day'..d)end
check(#cards==7,'seven day cards')
check(cards[1].Today.Visible and not cards[2].Today.Visible,'day 1 is marked TODAY')
check(cards[7].Amount.Text=='MECH PACK'and cards[1].Amount.Text=='RANDOM PACK'and cards[4].Amount.Text=='RANDOM PACK'and cards[5].Amount.Text=='+2'and cards[6].Amount.Text=='+3','rewards: days 1-4 RANDOM PACK, +2, +3 Gems, day 7 MECH PACK')
check(cards[2].Amount.Text=='RANDOM PACK'and cards[3].Amount.Text=='RANDOM PACK','(days 2 and 3 too)')
check(login.Note.Text:find('MECH',1,true)and login.Note.Text:find('random packs',1,true)and login.Note.Text:find('2 + 3 gems',1,true),'the note: 4 random packs, then 2 + 3 gems, day 7 = MECH: '..login.Note.Text)
check(login.ClaimButton.Caption.Text=='CLAIM DAY 1!','the big button: CLAIM DAY 1!')
audioLog={}
login.ClaimButton.Activated:Fire();frames(5)
check(calls[#calls][1]=='Daily'and calls[#calls][2]=='ClaimLogin','claiming asks the server')
check(audioHas('GemClaim')and not audioHas('Denied'),'R150: a successful claim clicks GemClaim and never Denied')
check(cards[1].Check.Visible and not cards[1].Today.Visible,'day 1 gets a ✓')
check(login.ClaimButton.Caption.Text:find('NEXT REWARD IN 5h',1,true),'then the button counts down: '..login.ClaimButton.Caption.Text)
check(panel.Status.Text=='Collect your Gems.','the server message shows')
-- Day 7 wording.
srv.Step=6;srv.Ready=true;panel.QuestsTab.Activated:Fire();panel.LoginTab.Activated:Fire();player:SetAttribute('DailyRevision',5);frames(5)
check(login.ClaimButton.Caption.Text:find('MECH PACK',1,true)and cards[7].Today.Visible,'day 7: CLAIM YOUR MECH PACK!')
-- Quests.
panel.QuestsTab.Activated:Fire();frames(3)
check(quests.Visible and not login.Visible,'QUESTS tab')
local rows={};for i=1,3 do rows[i]=quests:FindFirstChild('Quest'..i)end
check(rows[1].Task.Text=='Steal 3 packs'and rows[1].IconBack.Icon.Text=='🎒'and rows[1].Bar.Count.Text=='3 / 3','quest 1: 🎒 Steal 3 packs 3 / 3')
check(rows[2].Bar.Count.Text=='1 / 3'and math.abs(rows[2].Bar.Fill.Size.X.Scale-1/3)<1e-6,'quest 2 shows 1 / 3 with a third of the bar')
check(rows[1].Claim.Visible and not rows[2].Claim.Visible and not rows[3].Claim.Visible,'only finished quests have CLAIM')
check(rows[1].Reward.Amount.Text=='2'and rows[2].Reward.Amount.Text=='2'and rows[3].Reward.Amount.Text=='2','each pays 💎 2')
check(quests.Reset.Text:find('NEW QUESTS IN 5h',1,true),'the reset countdown: '..quests.Reset.Text)
-- R150: the server refuses a claim (it was already taken elsewhere): the press clicks Denied, not GemClaim.
srv.Quests[1].Claimed=true;audioLog={};rows[1].Claim.Activated:Fire();frames(5)
check(audioHas('Denied')and not audioHas('GemClaim'),'R150: a refused quest claim clicks Denied (and never GemClaim) ('..table.concat(audioLog,',')..')')
srv.Quests[1].Claimed=false;player:SetAttribute('DailyRevision',6);frames(5)
check(rows[1].Claim.Visible,'(the window is back to the claimable quest after a refresh)')
rows[1].Claim.Activated:Fire();frames(5)
check(type(calls[#calls][2])=='table'and calls[#calls][2].Quest==1,'claiming quest 1')
check(not rows[1].Claim.Visible and rows[1].Done.Visible,'then it says ✓ DONE')
-- The daily Gem cap: a finished quest that would go over it shows DAILY LIMIT instead of CLAIM.
srv.Quests[2].Progress=3;srv.Quests[2].Blocked=true;srv.Quests[3].Progress=2;srv.Quests[3].Blocked=true
player:SetAttribute('DailyRevision',(player:GetAttribute('DailyRevision')or 0)+1);panel.LoginTab.Activated:Fire();panel.QuestsTab.Activated:Fire();frames(5)
check(not rows[2].Claim.Visible and rows[2].Done.Visible and rows[2].Done.Text=='DAILY LIMIT','a finished but blocked quest: no CLAIM, DAILY LIMIT')
check(not rows[3].Claim.Visible and rows[3].Done.Visible and rows[3].Done.Text=='DAILY LIMIT','a blocked quest that is not finished yet says DAILY LIMIT too (no more Gems today)')
check(rows[1].Done.Visible and rows[1].Done.Text=='✓ DONE','a claimed quest still says ✓ DONE')
srv.Quests[2].Blocked=nil;srv.Quests[3].Blocked=nil;srv.Quests[2].Progress=1;srv.Quests[3].Progress=0
player:SetAttribute('DailyRevision',(player:GetAttribute('DailyRevision')or 0)+1);panel.LoginTab.Activated:Fire();panel.QuestsTab.Activated:Fire();frames(5)
check(not rows[3].Done.Visible and not rows[3].Claim.Visible and not rows[2].Done.Visible and not rows[2].Claim.Visible,'without the limit an unfinished quest shows neither CLAIM nor DONE')
-- Close.
panel.Header.Close.Activated:Fire();frames(3)
check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil and icons.Visible,'X closes it and the top bar buttons come back')
-- Another menu opening closes it.
daily.Activated:Fire();frames(2);pg:SetAttribute('SeedMenu','Index');frames(2)
check(not panel.Visible,'opening another menu closes DAILY');pg:SetAttribute('SeedMenu',nil);frames(2)
-- 4. Fits phones and computers.
for _,s in ipairs({{1280,720},{1920,1080},{780,360},{667,340},{390,760},{360,600}})do
 resize(s[1],s[2]);daily.Activated:Fire();frames(3)
 local P=rect(panel);local good,why=true,''
 for _,tab in ipairs({'LoginTab','QuestsTab'})do
  panel[tab].Activated:Fire();frames(3)
  local page=tab=='LoginTab'and login or quests;local pr=rect(page)
  if pr.Y+pr.H>P.Y+P.H+1 or pr.X+pr.W>P.X+P.W+1 then good=false;why=why..' page outside panel'end
  local items={}
  if tab=='LoginTab'then for d=1,7 do items[#items+1]=rect(cards[d])end;items[#items+1]=rect(login.ClaimButton)
  else for i=1,3 do items[#items+1]=rect(rows[i])end end
  for i,a in ipairs(items)do
   if a.X<pr.X-1 or a.Y<pr.Y-1 or a.X+a.W>pr.X+pr.W+1 or a.Y+a.H>pr.Y+pr.H+1 then good=false;why=why..(' item %d outside (%d,%d %dx%d in %d,%d %dx%d)'):format(i,a.X,a.Y,a.W,a.H,pr.X,pr.Y,pr.W,pr.H)end
   if a.W<30 or a.H<30 then good=false;why=why..' item '..i..' too small'end
   for j=i+1,#items do if overlap(a,items[j])then good=false;why=why..' items '..i..'/'..j..' overlap'end end
  end
 end
 check(good,('window fits %dx%d (panel %dx%d)%s'):format(s[1],s[2],P.W,P.H,why))
 panel.Header.Close.Activated:Fire();frames(2)
end
resize(1280,720)
-- 5. Opens by itself once when a login reward waits, after the tutorial.
srv.Ready=true;player:SetAttribute('DailyLoginReady',false);frames(2)
player:SetAttribute('DailyLoginReady',true);R.advance(4);frames(2)
check(not panel.Visible,'not during the tutorial')
player:SetAttribute('TutorialDone',true);R.advance(3.2);frames(3)
check(panel.Visible and login.Visible,'after the tutorial the week opens by itself')
panel.Header.Close.Activated:Fire();frames(2)
player:SetAttribute('DailyLoginReady',false);frames(1);player:SetAttribute('DailyLoginReady',true);R.advance(4);frames(2)
check(not panel.Visible,'only once a session')
-- 6. Invite.
invite.Activated:Fire();R.advance(.1);frames(1)
check(#invites==1 and type(invites[1])~='string'and invites[1].PromptMessage~=nil,'INVITE opens Roblox\'s invite prompt (with our message)')
check(type(invites[1])~='string'and invites[1].PromptMessage:find('speed gain',1,true)and not invites[1].PromptMessage:lower():find('faster',1,true)and #invites[1].PromptMessage<=60,'(R149: the message is about faster speed gains, short: '..tostring(invites[1].PromptMessage)..')')
check(tostring(invite:GetAttribute('AccessibleLabel')):find('+10% speed gain',1,true)~=nil,'(and so is the INVITE tooltip: '..tostring(invite:GetAttribute('AccessibleLabel'))..')')
canInvite=false;invite.Activated:Fire();R.advance(.1);frames(1)
check(#invites==1 and invite.InviteHint.Visible and invite.InviteHint.Text:find('not available',1,true),'where invites are off it says so')
R.advance(3);frames(1);check(not invite.InviteHint.Visible,'(the hint goes away)')
-- 7. Friend chip.
player:SetAttribute('FriendsInServer',2);player:SetAttribute('FriendSpeedBoost',1.2);frames(2)
local chip=invite:FindFirstChild('Boost')
check(chip and chip.Visible and chip.Text=='+20%','2 friends here: a +20% chip on INVITE')
check(tostring(invite:GetAttribute('AccessibleLabel')):find('2 here: +20% speed gain',1,true)~=nil,'(the tooltip says "+20% speed gain": '..tostring(invite:GetAttribute('AccessibleLabel'))..')')
player:SetAttribute('FriendsInServer',0);player:SetAttribute('FriendSpeedBoost',1);frames(2)
check(not chip.Visible,'no friends: no chip')
-- 8. Plant-ready opt-in.
player:SetAttribute('PlantReadyAlerts',false);player:SetAttribute('SeedsPlanted',1);R.advance(3);frames(1)
check(#optIns==0,'not asked while notifications are not set up')
player:SetAttribute('PlantReadyAlerts',true);player:SetAttribute('SeedsPlanted',2);R.advance(1);frames(1)
check(#optIns==0,'asked a moment after planting, not at once')
R.advance(2);frames(1);check(#optIns==1,'then Roblox\'s notification opt-in is shown')
player:SetAttribute('SeedsPlanted',3);R.advance(3);frames(1);check(#optIns==1,'only once a session')
-- 9. Teardown.
sc.Destroying:Fire();gui:Destroy();frames(2)
check(daily.Parent==nil and invite.Parent==nil,'the buttons go with the script')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
