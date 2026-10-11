--!nocheck
-- R157 HUD, the client half: the REAL HudLayout.Navigation (the menu wheel), DailyRewardsClient (DAILY / INVITE as options 4 / 5), TravelButtons (BASE / TRACK alone), Hotbar
-- (the held item's name rows) and PityBars155 (the bars) on the Roblox mock, with the inventory test's layout emulation for absolute rects:
--  1. the wheel     - five options in their CanvasGroups (MenuOption1..5, later ones drawn over earlier ones); open, each sits at HudLayout's offset for the screen (PC, a landscape
--                     phone, a portrait phone, the short landscape); DAILY / INVITE are options 4 / 5 and the top bar row has no squares
--  2. badges        - DAILY's badge on its option's top-right corner exactly like INDEX's; the closed wheel's MENU button carries ONE red "!" (Alert size) while a DAILY or an
--                     Index reward waits (MenuAlertDaily / MenuAlertIndex), none when nothing waits; the MENU button hides while a menu is open (SeedMenu)
--  3. gamepad       - explicit links while the wheel is open (MENU up -> 1, right -> 3, down -> 5; 1 -> 5 on down / right and back on up / left, the ends to MENU),
--                     SelectionOrder 1..5; none while it is closed; opened from the pad: option 1 selected; closed from an option: back to MENU
--  4. INVITE        - the hint on the script's own layer, under the MENU button (a child of the option would be cut by its CanvasGroup); the friend "+%" chip on INVITE, and
--                     beside the MENU button while the wheel is closed
--  5. name rows     - the real Hotbar puts SelectedName / SelectedTraits right above the real bars (PityBarsRow), at most 240 px wide and centred; the name drops into the traits
--                     row when there is no traits line; they follow the bars when the screen changes; the bars draw the clover on a disc, no diamond
--  6. lucky tag     - on the real fitted card it follows the rows the card publishes (PityBars155.TagPlace with B.CardRows), not the unfitted layout
local W=require('./world');local F=require('./fixtures');local R=W.R
local V2=R.Vector2.new
local checks,fails=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end;return c end
local function near(a,b,t)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(t or 1e-6)end
local fmt=string.format
F.packAssets(W)
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end,Transaction=function()end})
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
local char=R.new('Model');char.Parent=W.workspace;player.Character=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char;player.CharacterAdded=R.signal()
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
for _,n in ipairs({'RequestBaseTeleport','RequestTrackTeleport'})do local e=R.new('RemoteEvent');e.Name=n;e.Parent=remotes end
local request=R.new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
function request.InvokeServer(_,action,value)if action~='Daily'then return {Success=false}end;return {Success=true,Login={Ready=false,Next=1,Claimed=0},Quests={},ResetIn=3600,Day=1}end
local Social=W.service('SocialService');local canInvite=true;function Social.CanSendGameInviteAsync()return canInvite end;function Social.PromptGameInvite()end
local ENS=W.service('ExperienceNotificationService');function ENS.CanPromptOptInAsync()return true end;function ENS.PromptOptIn()end
local Gui=W.Gui
local function inset(l,r,top,rowH)Gui.TopbarInset={__type='Rect',Min=V2(l,top),Max=V2(r,top+rowH),Width=r-l,Height=rowH}end
inset(120,1280,0,52)
-- layout emulation (absolute rects from UDim2 + AnchorPoint), as the R140 client test
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
-- (R158: the HUD's own UIScale - HudScale, HudLayout.ApplyScale - scales its object about its AnchorPoint and everything in it; a child's UDim2 resolves against its parent's UNSCALED size;
-- ps: the parent's accumulated scale. With no HudScale in the tree this is the old emulation.)
local function lay(o,px,py,pw,ph,ps)
 ps=ps or 1
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or V2(0,0)
  if s and p then
   local ui=c:FindFirstChild('HudScale');local k=ui and(ui._props.Scale or 1)or 1
   local w=(s.X.Scale*(pw/ps)+s.X.Offset)*ps*k;local h=(s.Y.Scale*(ph/ps)+s.Y.Offset)*ps*k
   local x=px+(p.X.Scale*(pw/ps)+p.X.Offset)*ps-a.X*w;local y=py+(p.Y.Scale*(ph/ps)+p.Y.Offset)*ps-a.Y*h
   set(c,'AbsoluteSize',V2(w,h));set(c,'AbsolutePosition',V2(x,y));lay(c,x,y,w,h,ps*k)
  end
 end end
end
local screen=V2(1280,720)
local function frames(n)
 for _=1,n or 1 do
  for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')then if g.AbsoluteSize~=screen then g.AbsoluteSize=screen end;lay(g,0,0,screen.X,screen.Y)end end
  W.frames(1)
 end
end
local function resize(w,h,touch)W.UIS.TouchEnabled=touch==true;W.UIS.KeyboardEnabled=not touch;screen=V2(w,h);W.workspace.CurrentCamera.ViewportSize=screen;frames(3)end
local function rect(o)return {X=o.AbsolutePosition.X,Y=o.AbsolutePosition.Y,W=o.AbsoluteSize.X,H=o.AbsoluteSize.Y}end
local Hud=W.module('HudLayout');local Badge=W.module('NotifyBadge151')
player:SetAttribute('TutorialDone',false)
-- the three options other scripts register (SETTINGS, INDEX, SHOP: stand-ins on their own layer), then the real scripts
local host=R.new('ScreenGui');host.Name='WheelStandIns';host.Parent=pg
local stand={}
for i,name in ipairs({'SettingsToggle','IndexToggle','ShopToggle'})do local b=R.new('TextButton');b.Name=name;b.Parent=host;Hud.Navigation(b,i);stand[i]=b end
local tb=R.new('LocalScript');tb.Name='TravelButtons';check(pcall(W.load,'TravelButtons',tb),'TravelButtons loads')
local sc=R.new('LocalScript');sc.Name='DailyRewardsClient';local okD,errD=pcall(W.load,'DailyRewardsClient',sc);check(okD,'DailyRewardsClient loads: '..tostring(errD))
frames(10)
local nav=pg.GardenNavigation;local hub=nav.MenuButton
local function opt(i)return nav:FindFirstChild('MenuOption'..i)end
local daily=opt(4)and opt(4):FindFirstChild('DailyButton');local invite=opt(5)and opt(5):FindFirstChild('InviteButton')
local function openWheel(open)if(hub:GetAttribute('Expanded')==true)~=open then hub.Activated:Fire()end;frames(2)end

-- 1. the wheel ---------------------------------------------------------------------------------------------------------------------------------------------------------
check(daily and invite and pg.TravelButtons:FindFirstChild('TopIcons')==nil,'DAILY and INVITE are options 4 and 5 of the menu wheel; the top bar row has no DAILY / INVITE squares')
local okZ=true;for i=1,5 do local g=opt(i);if not(g and g.ClassName=='CanvasGroup'and g.ZIndex==2+i)then okZ=false end end
check(okZ,'five options, each in its CanvasGroup, later ones drawn over earlier ones (ZIndex 3..7: DAILY\'s badge over SHOP\'s edge, never under it)')
openWheel(true)
for _,s in ipairs({{1920,1080,false},{1366,768,false},{844,390,true},{390,844,true},{750,311,true},{640,280,true},{600,250,true},{360,640,true}})do
 resize(s[1],s[2],s[3])
 local m=Hud.Real(Hud.Read(screen,s[3],nil)) -- (R158: in screen px: a computer's MENU is drawn at its own scale)
 local menu=rect(hub);local ok=true;local got={}
 check(near(menu.Y+menu.H/2,s[2]/2+(m.MenuShiftY or 0),.5)and near(menu.W,m.MenuSize,.01),fmt('%dx%d: the MENU button where HudLayout puts it (centre %.0f)',s[1],s[2],menu.Y+menu.H/2))
 for i=1,5 do
  local b=opt(i):FindFirstChildWhichIsA('GuiButton');local r=rect(b)
  local dx,dy=r.X+r.W/2-(menu.X+menu.W/2),r.Y+r.H/2-(menu.Y+menu.H/2)
  got[i]=fmt('(%.0f,%.0f)',dx,dy)
  if not(near(dx,m.MenuOffsets[i].X,.6)and near(dy,m.MenuOffsets[i].Y,.6)and near(r.W,m.MenuOptionSize,.01)and opt(i).Visible and opt(i).GroupTransparency==0)then ok=false end
 end
 check(ok,fmt('%dx%d%s: the open wheel\'s five options sit at HudLayout\'s offsets, %d px: %s',s[1],s[2],s[3]and' touch'or'',m.MenuOptionSize,table.concat(got,' ')))
end
openWheel(false);resize(1280,720,false)
check(not opt(4).Visible and not opt(5).Visible,'the wheel closed: DAILY and INVITE are hidden with it')

-- 2. badges --------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 -- DAILY's badge sits like INDEX's (the same Count size and overhang on the top-right corner)
 local index=Badge.Make(stand[2],'RewardBadge',Badge.Sizes.Count,Badge.Overhang.Count)
 player:SetAttribute('DailyLoginReady',true);player:SetAttribute('DailyQuestsReady',1);frames(3)
 local d=daily:FindFirstChild('RewardBadge')
 check(d and d.Visible and d.Count.Text=='2'and d:GetAttribute('BadgeSize')==index:GetAttribute('BadgeSize')and d.Position.X.Scale==index.Position.X.Scale and d.Position.X.Offset==index.Position.X.Offset
  and d.Position.Y.Offset==index.Position.Y.Offset and d:GetAttribute('BadgeOverhangTop')==index:GetAttribute('BadgeOverhangTop'),'the DAILY badge ("2") sits on its option\'s top-right corner exactly like the INDEX badge (Count size, the same overhang on both sides)')
 local alert=hub:FindFirstChild('IndexRewardAlert')
 check(alert and alert.Visible and alert.Count.Text=='!'and alert:GetAttribute('BadgeSize')==Badge.Sizes.Alert and pg:GetAttribute('MenuAlertDaily')==2 and hub:GetAttribute('Expanded')==false,'the wheel closed, 2 DAILY rewards waiting: the MENU button shows the red "!" (Alert size)')
 player:SetAttribute('DailyLoginReady',false);player:SetAttribute('DailyQuestsReady',0);frames(3)
 check(not alert.Visible and pg:GetAttribute('MenuAlertDaily')==0,'nothing waiting: no "!"')
 pg:SetAttribute('MenuAlertIndex',3);frames(1)
 check(alert.Visible,'an Index reward waiting (ChestIndex publishes MenuAlertIndex): the same one "!"')
 pg:SetAttribute('MenuAlertIndex',0);frames(1);check(not alert.Visible,'... and it goes when that is claimed')
 local src=require('./rs_bundle').ChestIndex
 check(src==nil or(src:find("pg:SetAttribute('MenuAlertIndex',total)",1,true)~=nil and not src:find("Badge.Make(hub,'IndexRewardAlert'",1,true)),'ChestIndex hands the "!" to the MENU button (MenuAlertIndex) instead of drawing its own')
 pg:SetAttribute('SeedMenu','Shop');frames(1)
 check(not hub.Visible and not hub.Active,'a menu open (SeedMenu): the MENU button hides (so the Bag\'s cards may use its place)')
 pg:SetAttribute('SeedMenu',nil);frames(1);check(hub.Visible,'... and comes back with it closed')
end

-- 3. gamepad ------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local b={};for i=1,5 do b[i]=opt(i):FindFirstChildWhichIsA('GuiButton')end
 check(hub.NextSelectionUp==nil and hub.NextSelectionDown==nil and hub.NextSelectionRight==nil,'the wheel closed: MENU links to no hidden option')
 Gui.SelectedObject=hub;hub.Activated:Fire();frames(2)
 check(hub:GetAttribute('Expanded')==true and Gui.SelectedObject==b[1],'opened from the gamepad (MENU was selected): SETTINGS, option 1, is selected')
 check(hub.NextSelectionUp==b[1]and hub.NextSelectionRight==b[3]and hub.NextSelectionDown==b[5],'MENU: up -> option 1 (SETTINGS), right -> option 3 (SHOP), down -> option 5 (INVITE)')
 local chain=true
 for i=1,5 do
  local after,before=b[i+1]or hub,b[i-1]or hub
  if not(b[i].NextSelectionDown==after and b[i].NextSelectionRight==after and b[i].NextSelectionUp==before and b[i].NextSelectionLeft==before and b[i].SelectionOrder==i)then chain=false end
 end
 check(chain and hub.SelectionOrder==0,'the options chain clockwise 1 -> 2 -> 3 -> 4 -> 5 on down / right and back on up / left, the two ends back to MENU; SelectionOrder 1..5')
 Gui.SelectedObject=b[4];hub.Activated:Fire();frames(2)
 check(hub:GetAttribute('Expanded')==false and Gui.SelectedObject==hub and b[1].NextSelectionDown==nil,'closed with the pad on DAILY: the selection goes back to MENU; the links are cleared')
 Gui.SelectedObject=nil
 hub.Activated:Fire();frames(2);check(Gui.SelectedObject==nil,'opened with the mouse: nothing is selected for it');openWheel(false)
end

-- 4. INVITE ---------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local gui=pg.DailyRewardsGui
 canInvite=false;openWheel(true);invite.Activated:Fire();R.advance(.1);frames(1)
 local hint=gui:FindFirstChild('InviteHint');local h,menu=hint and rect(hint),rect(hub)
 check(hint and hint.Visible and invite:FindFirstChild('InviteHint')==nil and hint.Parent==gui,'the INVITE hint is on the DAILY / INVITE layer, not inside the option (its CanvasGroup would cut it)')
 check(hub:GetAttribute('Expanded')==false and h.X>=0 and h.X+h.W<=screen.X and h.Y>=menu.Y+menu.H and h.Y<=menu.Y+menu.H+10 and h.W==230,fmt('the tap closed the wheel; the hint shows just under the MENU button, on screen (%d,%d)',h.X,h.Y))
 R.advance(3);frames(1);canInvite=true
 player:SetAttribute('FriendsInServer',2);player:SetAttribute('FriendSpeedBoost',1.2);frames(2)
 local chip=invite:FindFirstChild('Boost');local copy=hub:FindFirstChild('FriendBoost')
 check(chip and chip.Visible and chip.Text=='+20%','2 friends here: "+20%" on the INVITE option')
 local c,m2=copy and rect(copy),rect(hub)
 check(copy and copy.Visible and copy.Text=='+20%'and c.X>=m2.X+m2.W+2 and near(c.Y+c.H/2,m2.Y+m2.H/2,.5)and near(c.W,Hud.ChipSize.X*(Hud.Read(screen,false,nil).MenuScale or 1),.01),'... and, the wheel closed, beside the MENU button (right of it, centred on it)')
 openWheel(true);check(not copy.Visible,'the wheel open: only INVITE carries it');openWheel(false)
 player:SetAttribute('FriendsInServer',0);player:SetAttribute('FriendSpeedBoost',1);frames(2)
 check(not chip.Visible and not copy.Visible,'no friend here: no chip anywhere')
end

-- 5. the name rows over the real bars --------------------------------------------------------------------------------------------------------------------------------------
do
 F.shovel(W,bag);F.pack(W,bag,1,'Pack01',1,'None')
 W.load('Hotbar',R.new('LocalScript'))
 local B=W.module('PityBars155');local Pity=W.module('PackPity155')
 local s=B.Start(player,{Notice=function()end})
 for _,sz in ipairs({{1920,1080,false},{844,390,true},{390,844,true},{1366,768,false}})do
  resize(sz[1],sz[2],sz[3]);frames(4)
  local hot=pg.ChestToolHotbar;local dock=hot.Dock;local name,traits=dock.SelectedName,dock.SelectedTraits
  local row=pg:GetAttribute('PityBarsRow')
  local m=Hud.Read(screen,sz[3],nil);local d=B.DefaultDock(m,sz[1],sz[2]);local place=B.Place(sz[1],sz[2],m,d)
  local want=B.NameRow(sz[1],sz[2],m,d,place);local k=m.Scale or 1;local width=math.min(d.W/k,Hud.NameWidth) -- (R158: the rows are laid out inside the scaled dock: HUD px)
  check(row==want and traits.Position.Y.Offset==-(row+16)and traits.Size.X.Offset==width and traits.Position.X.Scale==.5 and traits.Position.X.Offset==-width/2,
   fmt('%dx%d: the traits row ends %d px over the slots (PityBarsRow, right over the bars: %d px), %d px wide, centred',sz[1],sz[2],row or -1,dock.Size.Y.Offset and(d.Y-place.Pair.Y)or 0,width))
  check(name.Position.Y.Offset==-(row+(traits.Text~=''and 42 or 26))and name.Size.X.Offset==width,fmt('%dx%d: the name row right above it (or in its place with no traits line)',sz[1],sz[2]))
  check(name.Visible==(m.HotbarDetails~=false),fmt('%dx%d: shown where the screen has room for them (%s)',sz[1],sz[2],tostring(m.HotbarDetails~=false)))
 end
 resize(1920,1080,false);frames(4)
 local dock=pg.ChestToolHotbar.Dock;local name,traits=dock.SelectedName,dock.SelectedTraits;local row=pg:GetAttribute('PityBarsRow')
 -- a held pack (no traits line): the name sits right over the bars
 local pack;for _,t in ipairs(bag:GetChildren())do if t:GetAttribute('SeedPackTool')then pack=t end end
 if pack then pack.Parent=char end;frames(4)
 check(name.Text~=''and traits.Text==''and name.Position.Y.Offset==-(row+26),'a pack in hand (no traits line): "'..tostring(name.Text)..'" drops into the traits row, right over the bars')
 if pack then pack.Parent=bag end;frames(4)
 -- the bars: the clover on a dark disc, no diamond
 local bar=s.Bars.Normal
 check(bar.Root:FindFirstChild('Mark')==nil and bar.Badge and bar.Badge:FindFirstChild('Clover')and bar.Badge.Clover.ClassName=='CanvasGroup','the bars carry the clover (in a CanvasGroup on a dark disc), not the diamond')
 -- 6. the lucky tag on the REAL fitted card (PityBars155.TagPlace with the rows the card publishes, B.CardRows): a lucky pack opened under a Mythic card on a landscape phone
 do
  local Card=W.module('RarePullCard')
  resize(844,390,true);frames(4)
  local cg=R.new('ScreenGui');cg.Name='RarePullReveal';cg.DisplayOrder=96;cg.Parent=pg;frames(1)
  local card=Card.Create(cg,'Ladder',{Rank=5,Phone=true,SeedName='Sand Fruit Seed',Odds=90})
  player:SetAttribute('RarePullCinematic','Ladder');frames(2)
  local key=Pity.LuckyAttribute.Normal;player:SetAttribute(key,(player:GetAttribute(key)or 0)+1);player:SetAttribute(Pity.Attribute.Normal,0)
  frames(40)
  local t=pg:FindFirstChild(B.TagName,true);t=t and t:FindFirstChild('LuckyTag')
  local rows={};for k,v in pairs(Card.Rows(card.Layout))do rows[k]=v*390 end
  local want=B.TagPlace('Ladder',true,844,390,rows);local old=B.TagPlace('Ladder',true,844,390,nil)
  check(card.Layout.Fit~=nil and math.abs(want.Y-old.Y)>4,fmt('844x390: the fitted Mythic card moves the tag\'s place (%.0f px, the unfitted layout\'s %.0f px)',want.Y,old.Y))
  check(t and t.Visible and t.Position.Y.Offset==math.floor(want.Y+.5)and t.Size.Y.Offset==want.H and t.Position.Y.Offset-want.H/2>=rows.SeedTop-.5 and t.Position.Y.Offset+want.H/2<=rows.OddsTop+.5,
   fmt('844x390: the lucky tag "%s" follows the fitted card\'s rows (at %s px: seed %.0f..%.0f, "1 in N" from %.0f)',Pity.TagText('Normal'),t and tostring(t.Position.Y.Offset)or'none',rows.SeedTop,rows.SeedBottom,rows.OddsTop))
  player:SetAttribute('RarePullCinematic',nil);frames(30);card:Destroy();cg:Destroy();frames(2)
 end
 s:Destroy();check(pg:GetAttribute('PityBarsRow')==nil,'the bars gone: PityBarsRow cleared (the Hotbar puts the rows back over the slots)')
 frames(3);check(traits.Position.Y.Offset==-18,'... 2 px over the slots, R155\'s place')
end
print(fmt('R157 HUD client checks %d, fails %d',checks,fails))
if fails>0 then error('failures')end
