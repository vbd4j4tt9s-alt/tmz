--!nocheck
-- R140 (updated for the live R141 numbers: days 1-4 RANDOM PACK, day 5 +2, day 6 +3, day 7 MECH PACK; R153: day 7 is the VOID PACK, each quest pays "+1 PACK", a fourth
-- ALL DONE row pays "+2" Gems once all three are claimed, an unclaimed random pack is a mystery: a near-black pack silhouette on a white tile):
-- the real TravelButtons + DailyRewardsClient (and the real ItemPictures) on the mock. The 🎁 DAILY and 👥 INVITE squares sit right of
-- TRACK in the top bar row on every screen (or just under it on very narrow ones), never over BASE / TRACK or off
-- screen; the badge counts what is waiting; the DAILY window shows the week and the quests, claims through
-- PremiumRequest 'Daily' (a fake server here), fits phones and computers; it opens by itself once when a login reward
-- waits (after the tutorial); INVITE prompts Roblox's invite; the friend chip shows the boost (R149: a speed GAIN boost, not a walk speed one); the plant-ready opt-in
-- is asked once, after planting, only when the owner has set notifications up.
-- R157 (owner: "daily and invite can also be put into the menu wheel"): DAILY and INVITE are options 4 (down-right) and 5 (straight down) of the menu wheel, not squares in the
-- top bar row (BASE / TRACK own that row); their badge, the MENU button's "!", the INVITE hint (on the script's own layer, under the MENU button) and the friend chip (on INVITE,
-- and beside the MENU button while the wheel is closed) follow.
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
local srv={Step=0,Ready=true,BonusClaimed=false,BonusBlocked=false,Quests={{Key='Steal',Text='Steal 3 packs',Icon='🎒',Goal=3,Progress=3,Claimed=false,Packs=1},{Key='Plant',Text='Plant 3 seeds',Icon='🌱',Goal=3,Progress=1,Claimed=false,Packs=1},{Key='Sell',Text='Sell 5 fruit',Icon='💰',Goal=5,Progress=0,Claimed=false,Packs=1}}}
local calls={}
local function bonusNow()
 local n=0;for _,q in ipairs(srv.Quests)do if q.Claimed then n+=1 end end
 return {Gems=2,Done=n,Total=#srv.Quests,Claimed=srv.BonusClaimed,Blocked=srv.BonusBlocked,Ready=n==#srv.Quests and not srv.BonusClaimed and not srv.BonusBlocked}
end
local function stateNow()
 return {Success=true,Login={Ready=srv.Ready,Next=srv.Ready and srv.Step+1 or srv.Step,Claimed=srv.Step},Quests=srv.Quests,Bonus=bonusNow(),ResetIn=5*3600+12*60,Day=1}
end
local request=R.new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
function request.InvokeServer(_,action,value)
 calls[#calls+1]={action,value}
 if action~='Daily'then return {Success=false}end
 if value=='State'then return stateNow()end
 if value=='ClaimLogin'then
  if not srv.Ready then local s=stateNow();s.Success=false;s.Message='COME BACK TOMORROW';return s end
  srv.Step+=1;srv.Ready=false;local s=stateNow();s.Message='Your Gems are on the way!';return s
 end
 if value=='ClaimBonus'then if bonusNow().Ready then srv.BonusClaimed=true;local s=stateNow();s.Message='🎉 ALL DONE! Your Gems are on the way!';return s end end
 if type(value)=='table'then local q=srv.Quests[value.Quest];if q and q.Progress>=q.Goal and not q.Claimed then q.Claimed=true;local s=stateNow();s.Message='🎒 RANDOM SEED PACK! Check your bag!';return s end end
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
-- (R158: the HUD's own UIScale (HudScale: HudLayout.ApplyScale) scales its object - about its AnchorPoint - and everything in it; a child's UDim2 resolves against its parent's unscaled size; ps: the parent's accumulated scale)
local function lay(o,px,py,pw,ph,ps)
 ps=ps or 1
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  if s and p then
   local ui=c:FindFirstChild('HudScale');local k=ui and(ui._props.Scale or 1)or 1
   local w=s.X.Scale*(pw/ps)+s.X.Offset;local h=s.Y.Scale*(ph/ps)+s.Y.Offset
   local lim=c:FindFirstChildOfClass('UISizeConstraint');if lim and lim.MaxSize then w=math.min(w,lim.MaxSize.X);h=math.min(h,lim.MaxSize.Y)end
   w,h=w*ps*k,h*ps*k
   local x=px+(p.X.Scale*(pw/ps)+p.X.Offset)*ps-a.X*w;local y=py+(p.Y.Scale*(ph/ps)+p.Y.Offset)*ps-a.Y*h
   set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
   lay(c,x,y,w,h,ps*k)
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
-- R153: what the script asks ItemPictures for, per holder (the proxies it passes: the attributes decide the look)
local asked={};do local Pic=W.module('ItemPictures');local realShow=Pic.Show
 Pic.Show=function(holder,tool,priority)if tool then asked[holder]={Stage=tool:GetAttribute('Stage'),Variant=tool:GetAttribute('BagVariant'),Silhouette=tool:GetAttribute('Silhouette'),Shape=tool:GetAttribute('PackShape'),Pack=tool:GetAttribute('SeedPackTool')}end;return realShow(holder,tool,priority)end end
local tb=R.new('LocalScript');tb.Name='TravelButtons';local okT,errT=pcall(W.load,'TravelButtons',tb);check(okT,'TravelButtons loads: '..tostring(errT))
local sc=R.new('LocalScript');sc.Name='DailyRewardsClient';local okD,errD=pcall(W.load,'DailyRewardsClient',sc);check(okD,'DailyRewardsClient loads: '..tostring(errD))
frames(10)
local travel=pg.TravelButtons;local pair=travel.TravelPair
local nav=pg:FindFirstChild('GardenNavigation');local hub=nav and nav:FindFirstChild('MenuButton')
local daily=nav and nav:FindFirstChild('MenuOption4')and nav.MenuOption4:FindFirstChild('DailyButton')
local invite=nav and nav:FindFirstChild('MenuOption5')and nav.MenuOption5:FindFirstChild('InviteButton')
check(daily and invite and travel:FindFirstChild('TopIcons')==nil,'R157: 🎁 DAILY and 👥 INVITE are options 4 and 5 of the menu wheel; the top bar row has no DAILY / INVITE slots')
local function openWheel(open)if(hub:GetAttribute('Expanded')==true)~=open then hub.Activated:Fire()end;frames(2)end
check(daily and daily.Icon.Text=='🎁'and daily.Caption.Text=='DAILY'and invite.Icon.Text=='👥'and invite.Caption.Text=='INVITE','icons and captions')
-- 1. R157: BASE / TRACK alone in the top bar row; DAILY / INVITE in the open wheel, on many screens.
local function rect(o)return {X=o.AbsolutePosition.X,Y=o.AbsolutePosition.Y,W=o.AbsoluteSize.X,H=o.AbsoluteSize.Y}end
local function overlap(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local Hud=W.module('HudLayout')
local screens={{1920,1080,140,1920,'desktop 1080p'},{1280,720,120,1280,'desktop 720p'},{1024,768,120,1024,'tablet'},{844,390,150,800,'phone landscape'},
 {667,375,140,667,'small phone landscape'},{430,932,120,430,'big phone portrait'},{390,844,110,390,'phone portrait'},{375,667,110,375,'small phone portrait'},{360,640,110,360,'tiny phone portrait'}}
openWheel(true)
for _,s in ipairs(screens)do
 inset(s[3],s[4],0,s[2]>500 and 52 or 44);resize(s[1],s[2])
 local base,track=rect(pair.BaseButton),rect(pair.TrackButton)
 local d,i,menu=rect(daily),rect(invite),rect(hub)
 local m=Hud.Real(Hud.Read(R.Vector2.new(s[1],s[2]),false,nil));local o4,o5=m.MenuOffsets[4],m.MenuOffsets[5] -- (R158: in screen px; every one of these screens is a computer's)
 local function at(r)return r.X+r.W/2-(menu.X+menu.W/2),r.Y+r.H/2-(menu.Y+menu.H/2)end
 local dx,dy=at(d);local ix,iy=at(i)
 local placed=math.abs(dx-o4.X)<1 and math.abs(dy-o4.Y)<1 and math.abs(ix-o5.X)<1 and math.abs(iy-o5.Y)<1
 local ok=not overlap(d,base)and not overlap(d,track)and not overlap(i,base)and not overlap(i,track)and not overlap(d,i)and not overlap(d,menu)and not overlap(i,menu)
 local inside=d.X>=0 and i.X+i.W<=s[1]and d.Y>=0 and i.Y+i.H<=s[2]and d.W==m.MenuOptionSize and d.W==d.H and i.W==d.W
 local c=(base.X+track.X+track.W)/2;local row=math.abs((base.Y+base.H/2)-(track.Y+track.H/2))<1 and base.X+base.W<=track.X and(math.abs(c-s[1]/2)<=1 or math.abs(c-(s[3]+s[4])/2)<=1)
 check(placed and ok and inside and row,('%s %dx%d: DAILY at the wheel\'s option 4 (%+d,%+d), INVITE at option 5 (%+d,%+d), %d px; BASE / TRACK alone and centred in the top bar row'):format(s[5],s[1],s[2],dx,dy,ix,iy,d.W))
end
openWheel(false)
inset(120,1280,0,52);resize(1280,720)
-- 2. The badge.
player:SetAttribute('DailyLoginReady',true);player:SetAttribute('DailyQuestsReady',1);frames(2)
local b=daily:FindFirstChild('RewardBadge')
check(b and b.Visible and b.Count.Text=='2','badge: login + 1 quest = 2')
-- 3. The window.
openWheel(true);table.clear(audioLog);daily.Activated:Fire();frames(5) -- (R157: DAILY is pressed in the open wheel)
local gui=pg.DailyRewardsGui;local panel=gui.DailyPanel
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Daily','DAILY opens the window (SeedMenu = Daily)')
-- (R157: DAILY is a wheel option: the option itself is silent - ButtonSound false - and the wheel plays MenuClick for it, as for SETTINGS / INDEX / SHOP; INVITE too, no longer Bubble04)
check(daily:GetAttribute('ButtonSound')==false and invite:GetAttribute('ButtonSound')==false and audioHas('MenuClick')and hub:GetAttribute('Expanded')==false,'R150 / R157: the DAILY button clicks MenuClick (the wheel\'s, it opens a menu), not the generic Bubble04; so does INVITE')
check(not pair.Visible and not hub.Visible,'the top bar buttons and the MENU button hide while it is open (like the other menus)')
local login=panel.LoginPage;local quests=panel.QuestsPage
check(login.Visible and not quests.Visible,'the LOGIN tab first (a login reward is waiting)')
local cards={};for d=1,7 do cards[d]=login:FindFirstChild('Day'..d)end
check(#cards==7,'seven day cards')
-- R153: a random pack is a mystery: the default-shape pack in near-black (the real ItemPictures look); the Void day shows the Void pack's own art; the Gem days a gem
-- R157 (owner: "remove the white background"): NO white tile behind it any more (every holder is see-through); the near-black body (10,9,16 is only ~1.8 : 1 against the dark cards) gets a thin
-- light edge instead: a pale copy of every body part, bigger and pushed back from the camera (ItemPictures.lightEdge), so only a rim around the outline shows.
local function dark(holder)
 local v=holder:FindFirstChild('ItemViewport');if not v then return nil end
 local bodies,rims,bad={},{},0
 for _,d in ipairs(v:GetDescendants())do
  if d:IsA('BasePart')and d.Transparency<1 then
   if d.Name=='SilhouetteRim'then
    rims[#rims+1]=d;if not(d.Color.R*255>200 and d.Color.G*255>200 and d.Color.B*255>200)or d.Material~=R.Enum.Material.SmoothPlastic then bad+=1 end
   else
    bodies[#bodies+1]=d;if not(d.Color.R*255<30 and d.Color.G*255<30 and d.Color.B*255<30)or d.Material~=R.Enum.Material.SmoothPlastic then bad+=1 end
   end
  elseif d:IsA('SurfaceAppearance')or d:IsA('Decal')or d:IsA('Texture')then bad+=1 end
 end
 return #bodies>0 and bad==0,bodies,rims
end
-- the rim: one per body part (the copy sits in the same parent, in the same order), ~14% bigger, never nearer the camera than its body (the camera sits at +view = (0,.1,-1) from the pack)
local function rimOK(holder)
 local ok,bodies,rims=dark(holder);if not ok or #rims~=#bodies then return false,'bodies '..tostring(bodies and #bodies)..' rims '..tostring(rims and #rims)end
 local view=R.Vector3.new(0,.1,-1).Unit
 local byParent={};for _,b in ipairs(bodies)do local l=byParent[b.Parent]or{Bodies={},Rims={}};byParent[b.Parent]=l;table.insert(l.Bodies,b)end
 for _,r in ipairs(rims)do local l=byParent[r.Parent];if not l then return false,'a rim with no body beside it'end;table.insert(l.Rims,r)end
 for _,l in pairs(byParent)do
  if #l.Bodies~=#l.Rims then return false,'rims and bodies differ in one parent'end
  for i,b in ipairs(l.Bodies)do
   local r=l.Rims[i]
   if math.abs(r.Size.X/b.Size.X-1.14)>.01 or math.abs(r.Size.Y/b.Size.Y-1.14)>.01 or math.abs(r.Size.Z/b.Size.Z-1.14)>.01 then return false,'size '..b.Name end
   local behind=(r.CFrame.Position-b.CFrame.Position):Dot(view)
   if behind>1e-9 then return false,'in front: '..b.Name end
   if behind>-1e-6 and b.Size.Z>.01 then return false,'not pushed back: '..b.Name end
  end
 end
 return true
end
local function noTile(o)return o.BackgroundTransparency==1 end
local function isGold(c)return math.abs(c.R-255/255)<1e-6 and math.abs(c.G-206/255)<1e-6 and math.abs(c.B-64/255)<1e-6 end
local mystery=true;for d=1,7 do if not noTile(cards[d].Art)then mystery=false end end
check(mystery,'R157: no day card has a white tile behind its picture (the four random-pack days, the Void day and the Gem days are all see-through)')
frames(8)
local silOK=true;for d=1,4 do if dark(cards[d].Art)~=true then silOK=false end end
check(silOK,'R153: those four pictures are the near-black default pack silhouette (no colour, no decal, no texture: nothing says which pack it will be)')
local rimsOK,rimWhy=true,nil;for d=1,4 do local ok,why=rimOK(cards[d].Art);if not ok then rimsOK=false;rimWhy=why end end
check(rimsOK,'R157: ... with a thin light edge so it reads on the dark card without the tile: a pale copy of every body part, 14% bigger, pushed back behind it ('..tostring(rimWhy)..')')
local noRim=true;do local v=cards[7].Art:FindFirstChild('ItemViewport');for _,d in ipairs(v and v:GetDescendants()or{})do if d.Name=='SilhouetteRim'then noRim=false end end end
check(noRim,'(the Void day\'s real pack has no rim)')
local sameSil=true;for d=1,4 do local a=asked[cards[d].Art];if not(a and a.Pack and a.Silhouette==true and a.Shape==nil and a.Stage==1 and a.Variant=='Pack01')then sameSil=false end end
check(sameSil,'R153: the four mystery pictures are all the same proxy: the plain Forest pack, no PackShape (the default shape, like the other reward pictures), Silhouette (nothing about the pack that will be rolled)')
local v7=asked[cards[7].Art];check(v7 and v7.Pack and v7.Variant=='EclipseReliquary'and v7.Stage==7 and v7.Silhouette==nil,'R153: day 7 asks for the Void pack\'s own art (stage 7 EclipseReliquary), no silhouette')
check(dark(cards[7].Art)~=true and cards[7].Art:FindFirstChild('ItemViewport')~=nil,'(the Void day shows the real Void pack, not a silhouette)')
check(cards[1].Today.Visible and not cards[2].Today.Visible,'day 1 is marked TODAY')
-- R157 (owner: "the TODAY is barely visible, colour the letters white and give it a black outline"): white letters, a solid black UIStroke 2 thick (Contextual: it follows the letters), the same gold tag
do
 local t=cards[1].Today;local st=t:FindFirstChildOfClass('UIStroke');local c=t.TextColor3
 check(c.R==1 and c.G==1 and c.B==1,'R157: the TODAY letters are white (#FFFFFF)')
 check(st~=nil and st.Color.R==0 and st.Color.G==0 and st.Color.B==0 and st.Thickness==2 and st.Transparency==0 and st.ApplyStrokeMode==R.Enum.ApplyStrokeMode.Contextual,'R157: ... with a black UIStroke, 2 thick, opaque, Contextual (an outline round the letters)')
 check(t.TextStrokeTransparency==1,'R157: ... and no second, thin text edge on top of it')
 check(t.Text=='TODAY'and isGold(t.BackgroundColor3)and t.BackgroundTransparency==0,'R157: the tag keeps its yellow (gold) fill and its words')
 local n=0;for _,d in ipairs(t:GetChildren())do if d:IsA('UIStroke')then n+=1 end end
 check(n==1,'R157: exactly one outline on the tag')
 local sizeOK=t.Size.Y.Offset>0 and t.TextSize>=13 and t.TextSize<=14 and t.AnchorPoint.X==.5 and t.AnchorPoint.Y==0 and t.Position.X.Scale==.5 and t.Position.Y.Offset==3
 check(sizeOK,'R157: the tag keeps its size and its place (top middle of the card): '..tostring(t.Size)..' text '..tostring(t.TextSize))
end
check(cards[7].Amount.Text=='VOID PACK'and cards[1].Amount.Text=='RANDOM PACK'and cards[4].Amount.Text=='RANDOM PACK'and cards[5].Amount.Text=='+2'and cards[6].Amount.Text=='+3','rewards: days 1-4 RANDOM PACK, +2, +3 Gems, day 7 VOID PACK')
check(cards[2].Amount.Text=='RANDOM PACK'and cards[3].Amount.Text=='RANDOM PACK','(days 2 and 3 too)')
check(login.Note.Text:find('VOID',1,true)and not login.Note.Text:find('MECH',1,true)and login.Note.Text:find('random packs',1,true)and login.Note.Text:find('2 + 3 gems',1,true),'the note: 4 random packs, then 2 + 3 gems, day 7 = VOID: '..login.Note.Text)
check(login.ClaimButton.Caption.Text=='CLAIM DAY 1!','the big button: CLAIM DAY 1!')
audioLog={}
login.ClaimButton.Activated:Fire();frames(5)
check(calls[#calls][1]=='Daily'and calls[#calls][2]=='ClaimLogin','claiming asks the server')
check(audioHas('GemClaim')and not audioHas('Denied'),'R150: a successful claim clicks GemClaim and never Denied')
check(cards[1].Check.Visible and not cards[1].Today.Visible,'day 1 gets a ✓')
check(login.ClaimButton.Caption.Text:find('NEXT REWARD IN 5h',1,true),'then the button counts down: '..login.ClaimButton.Caption.Text)
check(panel.Status.Text=='Your Gems are on the way!','the server message shows')
-- Day 7 wording.
srv.Step=6;srv.Ready=true;panel.QuestsTab.Activated:Fire();panel.LoginTab.Activated:Fire();player:SetAttribute('DailyRevision',5);frames(5)
check(login.ClaimButton.Caption.Text:find('VOID PACK',1,true)and not login.ClaimButton.Caption.Text:find('MECH',1,true)and cards[7].Today.Visible,'day 7: CLAIM YOUR VOID PACK!')
-- Quests.
panel.QuestsTab.Activated:Fire();frames(12) -- (R157: ItemPictures clones on a real-time budget per frame; the menu wheel's two options make these frames a little busier: a few more frames for the rewards' pictures)
check(quests.Visible and not login.Visible,'QUESTS tab')
local rows={};for i=1,3 do rows[i]=quests:FindFirstChild('Quest'..i)end;rows[4]=quests:FindFirstChild('Bonus')
check(rows[4]~=nil and rows[4].Visible and rows[4].Task.Text=='ALL DONE BONUS!','R153: a fourth ALL DONE row')
check(rows[1].Task.Text=='Steal 3 packs'and rows[1].IconBack.Icon.Text=='🎒'and rows[1].Bar.Count.Text=='3 / 3','quest 1: 🎒 Steal 3 packs 3 / 3')
check(rows[2].Bar.Count.Text=='1 / 3'and math.abs(rows[2].Bar.Fill.Size.X.Scale-1/3)<1e-6,'quest 2 shows 1 / 3 with a third of the bar')
check(rows[1].Claim.Visible and not rows[2].Claim.Visible and not rows[3].Claim.Visible,'only finished quests have CLAIM')
check(rows[1].Reward.Amount.Text=='+1 PACK'and rows[2].Reward.Amount.Text=='+1 PACK'and rows[3].Reward.Amount.Text=='+1 PACK','each quest pays +1 PACK')
check(noTile(rows[1].Reward.PackTile)and noTile(rows[2].Reward.PackTile)and noTile(rows[3].Reward.PackTile)and dark(rows[1].Reward.PackTile)==true and dark(rows[3].Reward.PackTile)==true,'R153 / R157: the reward is a mystery pack: a near-black pack silhouette with no white tile behind it, the same for every quest')
check(rimOK(rows[1].Reward.PackTile)and rimOK(rows[2].Reward.PackTile)and rimOK(rows[3].Reward.PackTile),'R157: ... with the thin light edge')
local qsil=true;for i=1,3 do local a=asked[rows[i].Reward.PackTile];if not(a and a.Pack and a.Silhouette==true and a.Shape==nil and a.Stage==1 and a.Variant=='Pack01')then qsil=false end end
check(qsil,'R153: the quest reward pictures ask for the same silhouette proxy as the login days (no hint of the pack)')
check(rows[4].Reward.Amount.Text=='+2'and rows[4].Reward.Gem~=nil and rows[4].Reward:GetAttribute('AccessibleLabel')=='+2 💎'and rows[4].Bar.Count.Text=='0 / 3'and not rows[4].Claim.Visible and not rows[4].Done.Visible,'ALL DONE: +2 (gem icon), 0 / 3 claimed, nothing to claim yet')
check(#quests.Title.Text>0 and quests.Title.Text=='DAILY QUESTS','(the page title stays DAILY QUESTS)')
check(quests.Reset.Text:find('NEW QUESTS IN 5h',1,true),'the reset countdown: '..quests.Reset.Text)
-- R150: the server refuses a claim (it was already taken elsewhere): the press clicks Denied, not GemClaim.
srv.Quests[1].Claimed=true;audioLog={};rows[1].Claim.Activated:Fire();frames(5)
check(audioHas('Denied')and not audioHas('GemClaim'),'R150: a refused quest claim clicks Denied (and never GemClaim) ('..table.concat(audioLog,',')..')')
srv.Quests[1].Claimed=false;player:SetAttribute('DailyRevision',6);frames(5)
check(rows[1].Claim.Visible,'(the window is back to the claimable quest after a refresh)')
rows[1].Claim.Activated:Fire();frames(5)
check(type(calls[#calls][2])=='table'and calls[#calls][2].Quest==1,'claiming quest 1')
check(not rows[1].Claim.Visible and rows[1].Done.Visible,'then it says ✓ DONE')
-- R153: ALL DONE: 1 / 3 claimed so far; quests 2 and 3 get finished and claimed, then the bonus row gets CLAIM (2 Gems, once).
check(rows[4].Bar.Count.Text=='1 / 3'and math.abs(rows[4].Bar.Fill.Size.X.Scale-1/3)<1e-6 and not rows[4].Claim.Visible,'ALL DONE shows 1 / 3 claimed, no CLAIM yet')
srv.Quests[2].Progress=3;srv.Quests[3].Progress=5
player:SetAttribute('DailyRevision',(player:GetAttribute('DailyRevision')or 0)+1);panel.LoginTab.Activated:Fire();panel.QuestsTab.Activated:Fire();frames(5)
check(rows[2].Claim.Visible and rows[3].Claim.Visible and not rows[4].Claim.Visible and isGold(rows[2].Edge.Color),'two finished quests have CLAIM; the bonus waits')
audioLog={};rows[2].Claim.Activated:Fire();frames(5)
check(calls[#calls][2].Quest==2 and panel.Status.Text:find('RANDOM',1,true)and panel.Status.Text:find('bag',1,true)and rows[2].Done.Visible and rows[2].Done.Text=='✓ DONE'and audioHas('GemClaim'),'quest 2: a pack ("'..panel.Status.Text..'"), ✓ DONE')
check(rows[4].Bar.Count.Text=='2 / 3'and not rows[4].Claim.Visible,'ALL DONE 2 / 3')
rows[3].Claim.Activated:Fire();frames(5)
check(rows[3].Done.Visible and rows[4].Bar.Count.Text=='3 / 3'and rows[4].Claim.Visible and not rows[4].Done.Visible and math.abs(rows[4].Bar.Fill.Size.X.Scale-1)<1e-6,'all three claimed: ALL DONE is 3 / 3 and gets CLAIM')
check(isGold(rows[4].Edge.Color),'(a gold rim like a claimable quest)')
audioLog={};local callsBefore=#calls;rows[4].Claim.Activated:Fire();frames(5)
check(#calls==callsBefore+1 and calls[#calls][1]=='Daily'and calls[#calls][2]=='ClaimBonus'and audioHas('GemClaim')and not audioHas('Denied'),'claiming ALL DONE asks the server (ClaimBonus) and clicks GemClaim')
check(rows[4].Done.Visible and rows[4].Done.Text=='✓ DONE'and not rows[4].Claim.Visible and panel.Status.Text:find('ALL DONE',1,true)and panel.Status.Text:find('Gems',1,true),'then it says ✓ DONE and the message shows: '..panel.Status.Text)
-- pressing it again changes nothing (the button is gone; a stale press is refused by the server and clicks Denied)
callsBefore=#calls;rows[4].Claim.Activated:Fire();frames(2);check(#calls==callsBefore,'(no CLAIM left to press)')
srv.BonusClaimed=false;audioLog={};srv.Quests[1].Claimed=false;player:SetAttribute('DailyRevision',(player:GetAttribute('DailyRevision')or 0)+1);frames(5)
check(not rows[4].Claim.Visible and rows[4].Bar.Count.Text=='2 / 3'and rows[1].Claim.Visible,'(a quest that is not claimed takes the CLAIM away from ALL DONE again)')
srv.Quests[1].Claimed=true;srv.BonusBlocked=true;player:SetAttribute('DailyRevision',(player:GetAttribute('DailyRevision')or 0)+1);panel.LoginTab.Activated:Fire();panel.QuestsTab.Activated:Fire();frames(5)
check(not rows[4].Claim.Visible and rows[4].Done.Visible and rows[4].Done.Text=='GOT YOUR 💎'and rows[4].Bar.Count.Text=='3 / 3','older-style claims already paid today\'s Gems: ALL DONE says GOT YOUR 💎 (nothing to claim)')
srv.BonusBlocked=false;srv.Quests[2].Progress=1;srv.Quests[2].Claimed=false;srv.Quests[3].Progress=0;srv.Quests[3].Claimed=false
player:SetAttribute('DailyRevision',(player:GetAttribute('DailyRevision')or 0)+1);panel.LoginTab.Activated:Fire();panel.QuestsTab.Activated:Fire();frames(5)
check(not rows[3].Done.Visible and not rows[3].Claim.Visible and not rows[2].Done.Visible and not rows[2].Claim.Visible and not rows[4].Done.Visible and not rows[4].Claim.Visible,'an unfinished quest shows neither CLAIM nor DONE (and no DAILY LIMIT any more)')
local limitGone=true;for i=1,4 do if rows[i].Done.Text=='DAILY LIMIT'then limitGone=false end end
check(limitGone,'(no row says DAILY LIMIT: quests are packs now)')
-- Close.
panel.Header.Close.Activated:Fire();frames(3)
check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil and pair.Visible and hub.Visible,'X closes it and the top bar buttons and the MENU button come back')
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
  else for i=1,4 do items[#items+1]=rect(rows[i])end end
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
-- R151: a returning player is on the title screen when the reward is published; it waits for the title screen to close.
pg:SetAttribute('TitleActive',true)
player:SetAttribute('TutorialDone',true);R.advance(3.2);frames(3)
check(not panel.Visible,'not over the title screen')
R.advance(30);frames(2);check(not panel.Visible,'(still waiting while the title screen is up)')
pg:SetAttribute('TitleActive',nil);R.advance(3.2);frames(3)
check(panel.Visible and login.Visible,'after the tutorial the week opens by itself (R151: once the title screen closes; it used to give up for the session)')
panel.Header.Close.Activated:Fire();frames(2)
player:SetAttribute('DailyLoginReady',false);frames(1);player:SetAttribute('DailyLoginReady',true);R.advance(4);frames(2)
check(not panel.Visible,'only once a session')
-- 6. Invite.
invite.Activated:Fire();R.advance(.1);frames(1)
check(#invites==1 and type(invites[1])~='string'and invites[1].PromptMessage~=nil,'INVITE opens Roblox\'s invite prompt (with our message)')
check(type(invites[1])~='string'and invites[1].PromptMessage:find('speed gain',1,true)and not invites[1].PromptMessage:lower():find('faster',1,true)and #invites[1].PromptMessage<=60,'(R149: the message is about faster speed gains, short: '..tostring(invites[1].PromptMessage)..')')
check(tostring(invite:GetAttribute('AccessibleLabel')):find('+10% speed gain',1,true)~=nil,'(and so is the INVITE tooltip: '..tostring(invite:GetAttribute('AccessibleLabel'))..')')
canInvite=false;openWheel(true);invite.Activated:Fire();R.advance(.1);frames(1)
do
 -- R157: the hint is on the script's own layer (a 230 x 26 child of a wheel option would be cut by its CanvasGroup), just under the MENU button where INVITE is kept; the tap closed the wheel
 local hintL=gui:FindFirstChild('InviteHint');local h,menu=hintL and rect(hintL),rect(hub)
 check(#invites==1 and hintL and hintL.Visible and hintL.Text:find('right now',1,true)and invite:FindFirstChild('InviteHint')==nil,'where invites are off it says so (R157: on the DAILY / INVITE layer, not inside the option)')
 check(hub:GetAttribute('Expanded')==false and h and h.W==230 and h.H==26 and h.Y>=menu.Y+menu.H and h.Y<=menu.Y+menu.H+10 and h.X>=0 and h.X+h.W<=1280,('R157: the tap closed the wheel and the hint sits just under the MENU button, on screen (%d,%d %dx%d; MENU ends at %d)'):format(h and h.X or -1,h and h.Y or -1,h and h.W or 0,h and h.H or 0,menu.Y+menu.H))
 R.advance(3);frames(1);check(not hintL.Visible,'(the hint goes away)')
end
-- 7. Friend chip.
player:SetAttribute('FriendsInServer',2);player:SetAttribute('FriendSpeedBoost',1.2);frames(2)
local chip=invite:FindFirstChild('Boost')
check(chip and chip.Visible and chip.Text=='+20%','2 friends here: a +20% chip on INVITE')
do
 -- R157: INVITE is inside the closed wheel, so the MENU button carries the same chip just right of it while the wheel is closed (HudLayout, from MenuFriendBoost)
 local copy=hub:FindFirstChild('FriendBoost');local c,menu=copy and rect(copy),rect(hub)
 check(pg:GetAttribute('MenuFriendBoost')=='+20%'and copy and copy.Visible and copy.Text=='+20%'and hub:GetAttribute('Expanded')==false,'R157: the wheel closed: the MENU button shows "+20%" too')
 check(c and c.X>=menu.X+menu.W+2 and math.abs((c.Y+c.H/2)-(menu.Y+menu.H/2))<1 and c.X+c.W<=1280,('R157: ... just right of the MENU button, centred on it (%d,%d %dx%d)'):format(c and c.X or -1,c and c.Y or -1,c and c.W or 0,c and c.H or 0))
 openWheel(true);check(not copy.Visible and chip.Visible,'R157: the wheel open: the chip shows on INVITE only');openWheel(false)
 check(copy.Visible,'... and back on the MENU button when it closes')
end
check(tostring(invite:GetAttribute('AccessibleLabel')):find('2 here: +20% speed gain',1,true)~=nil,'(the tooltip says "+20% speed gain": '..tostring(invite:GetAttribute('AccessibleLabel'))..')')
player:SetAttribute('FriendsInServer',0);player:SetAttribute('FriendSpeedBoost',1);frames(2)
check(not chip.Visible and not hub.FriendBoost.Visible and pg:GetAttribute('MenuFriendBoost')==nil,'no friends: no chip (on INVITE or beside the MENU button)')
-- 8. Plant-ready opt-in.
player:SetAttribute('PlantReadyAlerts',false);player:SetAttribute('SeedsPlanted',1);R.advance(3);frames(1)
check(#optIns==0,'not asked while notifications are not set up')
-- R151: a failed eligibility check (a web hiccup) is tried again at the next planting instead of giving up for the session.
local canPrompt=ENS.CanPromptOptInAsync;ENS.CanPromptOptInAsync=function()error('HTTP 503',0)end
player:SetAttribute('PlantReadyAlerts',true);player:SetAttribute('SeedsPlanted',2);R.advance(3);frames(1)
check(#optIns==0,'the eligibility check failed: no prompt')
ENS.CanPromptOptInAsync=canPrompt
player:SetAttribute('SeedsPlanted',3);R.advance(1);frames(1)
check(#optIns==0,'asked a moment after planting, not at once')
R.advance(2);frames(1);check(#optIns==1,'then Roblox\'s notification opt-in is shown (tried again after the failed check)')
player:SetAttribute('SeedsPlanted',4);R.advance(3);frames(1);check(#optIns==1,'only once a session')
-- 9. Teardown.
sc.Destroying:Fire();gui:Destroy();frames(2)
check(daily.Parent==nil and invite.Parent==nil,'the buttons go with the script')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
