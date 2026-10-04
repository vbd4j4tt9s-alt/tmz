--!nocheck
-- R147: the real VerityClient on the mock (the server half is test_verity.luau). Her card turns to the camera around Y
-- only (a gentle bob; nothing with ReducedMotion); the marker over her head is "!" until a Void Pack Tool (SeedPackTool +
-- BagVariant EclipseReliquary, in the Backpack or the Character) shows up, then a bouncing gold "?" (and back);
-- the dialog (Open / Done / Refused from a fake server): her quest text, the Void Pack count, what has been handed in,
-- The Darkened's countdown, GIVE VOID PACK enabled only with a pack (one 'Give' per click, locked while it waits and
-- unlocked by an answer or after 4 s), the thank-you sound, the refusal reason, SeedMenu = 'Verity' set and cleared,
-- hostile payloads, and the window fitting phones and computers with every text shown in full.
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local backpack=R.new('Backpack');backpack.Parent=player
local character=R.new('Model');character.Name='Tester';character.Parent=W.workspace;player.Character=character
local plays={}
W.stub('InteractionAudio',{Play=function(key)plays[#plays+1]=key;return true end,Preload=function()end})
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='VerityQuest';remote.OnClientEvent=R.signal();remote.Parent=remotes
local fired={};function remote.FireServer(_,...)fired[#fired+1]={...}end
local C=W.module('VerityConfig')
-- The model the server builds (only what the client reads).
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=map
local model=R.new('Model');model.Name='VerityNPC';model.Parent=hub
local card=R.new('Part');card.Name='Card';card.Size=R.Vector3.new(24,34,.2)
local base=R.Vector3.new(0,22.2,-222);card.CFrame=R.CFrame.lookAt(base,base+R.Vector3.new(0,0,1));card.Anchored=true;card.Parent=model
W.CS:AddTag(model,'VerityNPC')
local camera=W.workspace.CurrentCamera
local function aim(x,y,z)camera.CFrame=R.CFrame.new(x,y,z)end
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
local function rect(o)return {X=o.AbsolutePosition.X,Y=o.AbsolutePosition.Y,W=o.AbsoluteSize.X,H=o.AbsoluteSize.Y}end
local function overlap(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local function server(kind,payload)remote.OnClientEvent:Fire(kind,payload);frames(2)end
local sc=R.new('LocalScript');sc.Name='VerityClient';local okV,errV=pcall(W.load,'VerityClient',sc);check(okV,'VerityClient loads: '..tostring(errV))
frames(5)
local gui=pg:FindFirstChild('VerityGui');local panel=gui and gui.VerityPanel
check(gui and panel and not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'the window exists, closed, SeedMenu not set')
-- 1. The card turns to the camera around Y only.
local function lookOf()return card.CFrame.LookVector end
aim(0,20,-30);frames(60)
local look=lookOf()
check(math.abs(look.X)<.02 and look.Z>.98 and math.abs(look.Y)<1e-6,'the camera in front (+Z): she faces +Z, level')
aim(100,20,-222);frames(90);look=lookOf()
check(look.X>.98 and math.abs(look.Z)<.1 and math.abs(look.Y)<1e-6,'the camera to her right (+X): she turns to +X (yaw only, never tilted): '..tostring(look))
aim(0,60,-300);frames(120);look=lookOf()
check(look.Z<-.98 and math.abs(look.X)<.05 and math.abs(look.Y)<1e-6,'the camera behind her: she turns to -Z, still level (the picture is on both faces)')
local posOk=true;local lo,hi=1e9,-1e9
for _=1,200 do frames(1);local p=card.CFrame.Position;if p.X~=0 or p.Z~=-222 then posOk=false end;lo=math.min(lo,p.Y);hi=math.max(hi,p.Y)end
check(posOk and hi-lo>.3 and hi-lo<=.71 and math.abs((hi+lo)/2-22.2)<.05,('the bob: x and z fixed, y moves %.2f studs around 22.2'):format(hi-lo))
aim(0,20,-30);frames(5)
-- ReducedMotion: back to where the server put her, then nothing moves.
W.Gui.ReducedMotionEnabled=true;frames(3)
local p0=card.CFrame.Position;look=lookOf()
check(p0.X==0 and p0.Y==22.2 and p0.Z==-222 and math.abs(look.Z-1)<1e-6 and math.abs(look.X)<1e-6,'ReducedMotion: she is back at the server\'s spot and orientation')
aim(100,20,-222);frames(60);local p1=card.CFrame.Position;look=lookOf()
check(p1.Y==22.2 and math.abs(look.Z-1)<1e-6,'and does not turn or bob')
W.Gui.ReducedMotionEnabled=false;frames(90);look=lookOf()
check(look.X>.98,'with motion on again she turns to the camera')
aim(0,20,-30);frames(60)
-- 2. The marker.
local marker=model:FindFirstChild('VerityMarker');local mark=marker and marker:FindFirstChild('Mark')
check(marker and marker:IsA('BillboardGui')and marker.Adornee==card and mark and mark.Text=='!'and mark.TextColor3.R==1 and mark.TextColor3.G==1,'a "!" marker over her head')
check(marker and marker.StudsOffsetWorldSpace.Y>=card.Size.Y/2,'above the top of the card')
local baseOffset=marker.StudsOffsetWorldSpace
local function bounced()local lo2,hi2=1e9,-1e9;for _=1,60 do frames(1);local y=marker.StudsOffsetWorldSpace.Y;lo2=math.min(lo2,y);hi2=math.max(hi2,y)end;return hi2-lo2 end
check(marker:GetAttribute('Bounce')==false and bounced()<1e-6,'"!" stands still')
local plain=F.tool(W,'Forest Seed Pack',{SeedPackTool=true,SeedInventoryId='p1',BagVariant='Pack01',Stage=1},backpack);frames(2)
local notPack=F.tool(W,'Odd tool',{BagVariant='EclipseReliquary',SeedInventoryId='x'},backpack);frames(2)
check(mark.Text=='!','other packs (and a Tool without SeedPackTool) do not count')
local voidTool=F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='v1',BagVariant='EclipseReliquary',Stage=7},backpack);frames(2)
check(mark.Text=='?'and mark.TextColor3.R==1 and mark.TextColor3.G>.7 and mark.TextColor3.B<.4 and marker:GetAttribute('Bounce')==true,'a Void Pack Tool appears in the Backpack: a gold "?"')
check(bounced()>.8,'the "?" bounces')
-- in the hands (equipped)
voidTool.Parent=character;frames(2)
check(mark.Text=='?','still "?" while it is held (Character)')
voidTool.Parent=backpack;frames(2)
W.Gui.ReducedMotionEnabled=true;frames(3)
check(mark.Text=='?'and bounced()<1e-6,'ReducedMotion: the "?" stays but does not bounce')
W.Gui.ReducedMotionEnabled=false;frames(3)
check(bounced()>.8,'(and bounces again with motion on)')
local second=F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='v2',BagVariant='EclipseReliquary',Stage=7},backpack);frames(2)
voidTool:Destroy();frames(2)
check(mark.Text=='?','two Void Packs, one goes: still "?"')
second:Destroy();frames(2)
check(mark.Text=='!'and marker:GetAttribute('Bounce')==false,'the last one goes: back to "!"')
check(math.abs(marker.StudsOffsetWorldSpace.Y-baseOffset.Y)<1e-6,'(and the marker is back at rest)')
-- A pack that arrives with a late attribute is found by the once-a-second recount.
do
 local late=F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='v3',Stage=7},backpack);frames(2)
 check(mark.Text=='!','(no BagVariant yet: no "?")')
 late:SetAttribute('BagVariant','EclipseReliquary');R.advance(1.2);frames(2)
 check(mark.Text=='?','a late BagVariant is found by the recount');late:Destroy();frames(2)
end
-- A new Backpack (respawn) is watched too.
do
 backpack:Destroy();local fresh=R.new('Backpack');fresh.Parent=player;frames(2)
 F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='v4',BagVariant='EclipseReliquary',Stage=7},fresh);frames(2)
 check(mark.Text=='?','a new Backpack after respawn is watched');backpack=fresh
 for _,t in ipairs(fresh:GetChildren())do t:Destroy()end;frames(2);check(mark.Text=='!','(and back to "!")')
end
-- 3. The dialog. A refusal before any Open (the data was still loading): the window opens with the reason.
server('Refused',{Reason='YOUR DATA IS STILL LOADING'})
local quest,eventLine,voidChip,doneChip,rewardLine,status,give,closeButton=panel.QuestText,panel.EventLine,panel.VoidChip,panel.DeliveredChip,panel.RewardLine,panel.Status,panel.GiveButton,panel.CloseButton
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Verity','a refusal while closed opens the window (SeedMenu = Verity)')
check(status.Text=='YOUR DATA IS STILL LOADING'and voidChip.Count.Text=='-'and doneChip.Count.Text=='-'and not give.Active,'it shows the reason, counts unknown ("-"), GIVE disabled')
panel.Header.Close.Activated:Fire();frames(2)
check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'X closes it and clears SeedMenu')
-- Open with nothing to hand in.
local nextAt=R.clock+754
server('Open',{VoidPacks=0,Delivered=3,RewardText='1 VOID PACK = 1 VERITY PACK',EventActive=false,NextAt=nextAt})
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Verity','Open shows the window and sets SeedMenu = Verity')
check(quest:GetAttribute('FullText')==C.Quest and not quest:GetAttribute('TextShortened')and quest.Text:gsub('\n',' ')==C.Quest,'her quest text, in full (wrapped by the text fitter): '..quest.Text:gsub('\n',' '))
check(panel.Header.Title.Text:find('VERITY',1,true),'titled VERITY')
check(voidChip.Count.Text=='0'and doneChip.Count.Text=='3'and voidChip.Caption.Text:find('VOID',1,true)and doneChip.Caption.Text:find('HANDED',1,true),'chips: 0 Void packs, 3 handed in')
check(rewardLine.Text=='1 VOID PACK = 1 VERITY PACK','the reward line from the server')
check(eventLine.Visible and eventLine.Text:find('ARRIVES IN 12m 34s',1,true),'The Darkened\'s countdown: '..eventLine.Text)
check(give.Active==false and give.Interactable==false and give.Caption.Text=='GIVE VOID PACK','no Void pack: GIVE VOID PACK is disabled')
give.Activated:Fire();frames(2);check(#fired==0,'(clicking it sends nothing)')
check(closeButton.Caption.Text=='CLOSE','a CLOSE button')
R.advance(61);frames(2)
local mm,ss=eventLine.Text:match('ARRIVES IN (%d+)m (%d+)s');local shownLeft=mm and tonumber(mm)*60+tonumber(ss)or -1;local trueLeft=nextAt-R.clock
check(mm and shownLeft<=754-60 and trueLeft-shownLeft<=2 and trueLeft-shownLeft>=-1,'the countdown ticks while open: '..eventLine.Text..' (really '..math.floor(trueLeft)..' s left)')
server('Open',{VoidPacks=0,Delivered=3,EventActive=true})
check(eventLine.Visible and eventLine.Text:find('HERE NOW',1,true)and rewardLine.Text==C.RewardText,'The Darkened is here: "HERE NOW" (and the reward line falls back to the config)')
server('Open',{VoidPacks=0,Delivered=3})
check(not eventLine.Visible,'no schedule information: the line is hidden')
server('Open',{VoidPacks=0,Delivered=3,EventActive=false,NextAt=R.clock-5})
check(eventLine.Visible and eventLine.Text:find('ARRIVING',1,true),'a NextAt in the past reads "arriving"')
-- Hand one in.
server('Open',{VoidPacks=2,Delivered=3,EventActive=false})
check(voidChip.Count.Text=='2'and give.Active and give.Interactable,'two Void packs: GIVE VOID PACK is enabled')
give.Activated:Fire();frames(2)
check(#fired==1 and fired[1][1]=='Give'and #fired[1]==1,'a click sends exactly "Give" (no arguments)')
check(not give.Active and give.Caption.Text:find('HANDING',1,true),'then it is locked until the server answers')
give.Activated:Fire();give.Activated:Fire();frames(2);check(#fired==1,'more clicks while waiting send nothing')
server('Done',{Delivered=4,RecordId='x_1'})
check(status.Text==C.Thanks and plays[#plays]=='GemClaim','Done: the thank-you and the GemClaim sound ('..status.Text..')')
check(voidChip.Count.Text=='1'and doneChip.Count.Text=='4'and give.Active,'the counts update (1 Void pack left, 4 handed in) and GIVE is ready again')
give.Activated:Fire();frames(2);check(#fired==2,'a second hand-in sends a second Give')
server('Done',{Delivered=5})
check(voidChip.Count.Text=='0'and doneChip.Count.Text=='5'and not give.Active and #plays==2,'the last one: 0 left, GIVE disabled, the sound played twice')
-- A refusal unlocks the button and shows the reason.
server('Open',{VoidPacks=1,Delivered=5})
give.Activated:Fire();frames(2);check(#fired==3 and not give.Active,'(another click, waiting)')
server('Refused',{Reason='COME CLOSER TO VERITY'})
check(status.Text=='COME CLOSER TO VERITY'and status.TextColor3.R>.9 and status.TextColor3.G<.5,'Refused: the reason, in red')
check(give.Active and voidChip.Count.Text=='1','and GIVE is unlocked again, the count unchanged')
-- A request nobody answers (rate limited) frees the button after 4 seconds.
give.Activated:Fire();frames(2);check(not give.Active and #fired==4,'(waiting for an answer that never comes)')
R.advance(3);frames(2);check(not give.Active,'still waiting after 3 s')
R.advance(1.2);frames(2);check(give.Active,'after 4 s the button is free again')
-- Hostile / odd payloads never break the window.
for _,payload in ipairs({{VoidPacks='x',Delivered=-1,RewardText=12,EventActive='yes',NextAt='soon'},{VoidPacks=0/0,Delivered=1e30},{}})do
 local ok=pcall(function()server('Open',payload)end)
 check(ok and voidChip.Count.Text~=nil,'an odd Open payload is handled')
end
check(voidChip.Count.Text=='0'and not give.Active,'(garbage counts read as 0 and disable GIVE)')
local ok1=pcall(function()remote.OnClientEvent:Fire('Open',nil);remote.OnClientEvent:Fire('Mystery',{});remote.OnClientEvent:Fire('Refused',5);frames(2)end)
check(ok1,'nil / unknown / non-table messages are ignored')
-- Closing: X, CLOSE, the shade; another menu takes over.
server('Open',{VoidPacks=1,Delivered=0})
closeButton.Activated:Fire();frames(2);check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'CLOSE closes it and clears SeedMenu')
server('Open',{VoidPacks=1,Delivered=0});gui.Shade.Activated:Fire();frames(2);check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'tapping outside closes it')
pg:SetAttribute('SeedMenu','Inventory');server('Open',{VoidPacks=1,Delivered=0})
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Verity','opening while another menu is up takes SeedMenu over')
pg:SetAttribute('SeedMenu','Index');frames(2)
check(not panel.Visible and pg:GetAttribute('SeedMenu')=='Index','another menu opening closes hers and leaves its SeedMenu alone')
pg:SetAttribute('SeedMenu',nil);frames(2)
-- 4. The picture, and the window fits phones and computers.
server('Open',{VoidPacks=2,Delivered=7,EventActive=true})
local picture=panel.Portrait.Picture
check(picture.Image==C.Image and picture.ScaleType==R.Enum.ScaleType.Fit,'her picture in the window, ScaleType Fit')
local function itemsOf()
 local out={{'quest',quest},{'chips-void',voidChip},{'chips-done',doneChip},{'reward',rewardLine},{'status',status},{'give',give},{'close',closeButton}}
 if eventLine.Visible then table.insert(out,2,{'event',eventLine})end
 return out
end
for _,s in ipairs({{1920,1080},{1280,720},{1024,768},{844,390},{780,360},{667,340},{667,375},{430,932},{390,844},{390,760},{375,667},{360,640},{360,600}})do
 resize(s[1],s[2]);server('Done',{Delivered=8});server('Open',{VoidPacks=2,Delivered=7,EventActive=true})
 local P=rect(panel);local good,why=true,''
 local items=itemsOf()
 for i,a in ipairs(items)do
  local r=rect(a[2])
  if r.X<P.X-1 or r.Y<P.Y-1 or r.X+r.W>P.X+P.W+1 or r.Y+r.H>P.Y+P.H+1 then good=false;why=why..(' %s outside the panel'):format(a[1])end
  if r.W<30 or r.H<16 then good=false;why=why..(' %s too small (%dx%d)'):format(a[1],r.W,r.H)end
  for j=i+1,#items do if overlap(r,rect(items[j][2]))then good=false;why=why..(' %s/%s overlap'):format(a[1],items[j][1])end end
 end
 for _,a in ipairs({{'give',give},{'close',closeButton}})do local r=rect(a[2]);if r.H<36 or r.W<80 then good=false;why=why..' '..a[1]..' is hard to tap'end end
 local port=panel.Portrait;local pr=rect(port)
 if port.Visible then
  if pr.X<P.X-1 or pr.Y<P.Y-1 or pr.X+pr.W>P.X+P.W+1 or pr.Y+pr.H>P.Y+P.H+1 then good=false;why=why..' portrait outside'end
  for _,a in ipairs(items)do if overlap(pr,rect(a[2]))then good=false;why=why..' portrait overlaps '..a[1]end end
 end
 local hdr=rect(panel.Header.Close);if hdr.X+hdr.W>P.X+P.W+1 or hdr.W<30 then good=false;why=why..' X button off or small'end
 for _,label in ipairs({quest,eventLine,rewardLine,status,voidChip.Count,doneChip.Count,voidChip.Caption,doneChip.Caption,give.Caption,closeButton.Caption})do
  if label:GetAttribute('TextShortened')then good=false;why=why..' text cut: '..tostring(label.Name)..' ("'..label.Text..'")'end
 end
 check(good,('window fits %dx%d (panel %dx%d, portrait %s)%s'):format(s[1],s[2],P.W,P.H,port.Visible and'shown'or'hidden',why))
 pg:SetAttribute('SeedMenu',nil);frames(1)
end
resize(1280,720)
check(panel.Portrait.Visible==false or panel.Portrait.AbsoluteSize.X>0,'(the portrait has a size when shown)')
-- A long refusal reason still fits the status line.
server('Open',{VoidPacks=1,Delivered=0});resize(360,640)
for _,reason in pairs(C.Reasons)do
 server('Refused',{Reason=reason});frames(2)
 check(not status:GetAttribute('TextShortened')and status:GetAttribute('FullText')==reason,'every server refusal fits a phone in full: '..reason)
end
-- 5. Teardown.
resize(1280,720)
gui:Destroy();frames(3)
check(marker.Parent==nil,'the marker goes with the script')
local ok2=pcall(function()aim(50,20,-100);frames(5);remote.OnClientEvent:Fire('Open',{VoidPacks=1})end)
check(ok2,'nothing runs (or errors) after it is torn down')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
