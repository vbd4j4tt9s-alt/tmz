--!nocheck
-- R147 / R148: the real VerityClient on the mock (the server half is test_verity.luau), with the real ItemPictures, SeedPackVisuals,
-- AudioMixer and GardenTheme / BrightUI of this checkout.
--  * Her body (a big yellow Ball with her smiley) turns to face the camera on this client (all four sides and the diagonals,
--    never tilted), bobs a little, swells while her voice plays; nothing of that under ReducedMotion.
--  * The marker in her name sign is "!" until she has been talked to (the dialog opened once: gone for the rest of the session, back
--    in a new session), a bouncing gold "?" while a Void Pack Tool (SeedPackTool + BagVariant EclipseReliquary, in the Backpack or the
--    Character) is held; never both once the limited event is over. The sign is one studs-sized BillboardGui: marker row, gap, name,
--    event timer row (rows that cannot overlap, also while the marker bounces, she bobs and swells), offset in camera space.
--  * The limited event (LimitedEvent, EndsAt 2026-11-01 00:00 UTC, the server's clock): "HURRY! ENDS IN 27d 04h 12m 09s" (R152; it said EVENT ENDS IN) under
--    her name (ticking every second); after the end EVENT OVER! THANKS!, GIVE disabled, no marker. R149: NOT in the dialog any more (owner: "remove the event
--    ends thing"): no such line anywhere in her window, and no empty row where it was.
--  * Her greeting (VerityConfig.GreetingSoundId): plays from her body when the dialog opens with Talk, and once when you first come
--    within 30 studs (at most once a minute; a Talk greeting counts); never two copies at once; routed to the Effects group and
--    skipped with Effects at 0; a failed asset load is warned about once and skipped.
--  * The dialog (Open / Done / Refused from a fake server): her quest text, her portrait (R149: her 3D model, a ViewportFrame with the yellow
--    ball and the smiley; the lip sync is in docs/proposals/R149/tests/test_verity_lipsync.luau), the Void Pack count, what has been handed
--    in, The Darkened's countdown, the exchange as the game's real 3D pack pictures (Void Pack -> Verity Pack, the same pictures as the
--    hotbar), GIVE VOID PACK enabled only with a pack (one 'Give' per click, locked while it waits and unlocked by an answer or after 4 s),
--    the thank-you sound, the refusal reason, SeedMenu = 'Verity' set and cleared, hostile payloads, and the window fitting phones and
--    computers with every text shown in full (R149: the quest sentence at a readable size, in at most 5 lines, measured with a font 15%
--    wider than the mock's usual one, on the first Open and on every later one, and no empty row anywhere).
--  * R152 (her texts in her voice): the status line says what to do next until the server answers (section 4b), and every one-line text (The Darkened's
--    line, the status line, both buttons, the stat box titles) stays readable (12 px) on every screen size when drawn with the 15% wider real font.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
-- Mock gaps for the pack picture builders (as in the R137 pictures test).
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
F.packAssets(W)
-- R149: text is measured with a font 15% wider than the shared mock's (.52 em a character; bold capitals run wider in Fredoka), so what fits here fits with room to spare.
W.service('TextService').GetTextSize=function(_,t,size,_,bounds)return R.Vector2.new(math.min(bounds.X,utf8.len(t)*size*.6),size*1.2)end
-- Sounds: every Sound knows when it is playing (3.2 s long), and a log keeps every Play and the most copies heard at once.
local soundLog,playing,maxOverlap,playMode={},0,0,nil
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='Sound'then
  o.Ended=R.signal();o.Loaded=R.signal();o.IsPlaying=false;o.IsLoaded=true;o.TimeLength=3.2;o.TimePosition=0
  function o.Play(self)
   if playMode=='throw'then error('cannot play this sound')end
   soundLog[#soundLog+1]={Sound=self,At=R.clock};self.IsPlaying=true;playing+=1;maxOverlap=math.max(maxOverlap,playing)
   R.task.delay(self.TimeLength,function()if self.IsPlaying then self.IsPlaying=false;playing-=1;self.Ended:Fire()end end)
  end
  function o.Stop(self)if self.IsPlaying then self.IsPlaying=false;playing-=1 end end
 end
 return o end end
local preloadMode,preloadCalls='ok',0
local CP=W.service('ContentProvider')
function CP.PreloadAsync(_,list,cb)
 preloadCalls+=1
 for _,x in ipairs(list)do if cb then local status=preloadMode=='fail'and R.Enum.AssetFetchStatus.Failure or R.Enum.AssetFetchStatus.Success;cb(x.SoundId,status);if preloadMode=='fail'then cb(x.SoundId,status)end end end
end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local backpack=R.new('Backpack');backpack.Parent=player
local character=R.new('Model');character.Name='Tester';character.Parent=W.workspace;player.Character=character
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,7,-150);root.Parent=character
local function standAt(x,y,z)root.CFrame=CF(x,y,z)end
local plays={}
W.stub('InteractionAudio',{Play=function(key)plays[#plays+1]=key;return true end,Preload=function()end})
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='VerityQuest';remote.OnClientEvent=R.signal();remote.Parent=remotes
local fired={};function remote.FireServer(_,...)fired[#fired+1]={...}end
local C=W.module('VerityConfig');local Mixer=W.module('AudioMixer');local Pictures=W.module('ItemPictures');local Visuals=W.module('SeedPackVisuals')
-- Every picture the client asks ItemPictures for (holder name, the look key it resolves to, priority).
local shows={};do local realShow=Pictures.Show;Pictures.Show=function(holder,tool,priority)shows[#shows+1]={Name=holder.Name,Key=Pictures.Key(tool),Priority=priority};return realShow(holder,tool,priority)end end
-- The model the server builds (only what the client reads: Body with its NameSign).
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=map
local model=R.new('Model');model.Name='VerityNPC';model.Parent=hub
local bodyAt=V3(0,16.45,-340)
local body=R.new('Part');body.Name='Body';body.Shape=R.Enum.PartType.Ball;body.Size=V3(22,22,22);body.CFrame=R.CFrame.lookAt(bodyAt,bodyAt+V3(0,0,1));body.Anchored=true;body.Color=R.Color3.fromRGB(255,255,0);body.Parent=model
local S=C.Sign
local function buildSign()
 local sg=R.new('BillboardGui');sg.Name='NameSign';sg.Adornee=body;sg.Size=R.UDim2.new(S.W,0,S.H,0);sg.StudsOffset=V3(0,11+S.Gap+S.H/2,0);sg.StudsOffsetWorldSpace=V3(0,0,0);sg.Parent=body
 local nl=R.new('TextLabel');nl.Name='Name';nl.Text='VERITY';nl.Position=R.UDim2.new(0,0,S.Name.Top/S.H,0);nl.Size=R.UDim2.new(1,0,S.Name.Height/S.H,0);nl.Parent=sg
 return sg,nl
end
local sign,nameLabel=buildSign()
local homeCFrame=body.CFrame
W.CS:AddTag(model,'VerityNPC')
local camera=W.workspace.CurrentCamera
local function aim(x,y,z)camera.CFrame=CF(x,y,z)end
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
local function load(label)
 local sc=R.new('LocalScript');sc.Name='VerityClient';local ok,err=pcall(W.load,'VerityClient',sc);check(ok,label..' loads: '..tostring(err));return sc
end
local Limited=W.module('LimitedEvent');local START_LEFT=27*86400+4*3600+12*60+9
R.clock=Limited.EndsAt-START_LEFT -- 27 days, 4 h, 12 min, 9 s before the end of the event
local sc=load('VerityClient')
-- 1. Her body turns to the camera around Y only (all the way round), bobs, and rests where the server put her ----------------------
frames(5)
local gui=pg:FindFirstChild('VerityGui');local panel=gui and gui.VerityPanel
check(gui and panel and not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'the window exists, closed, SeedMenu not set')
check(panel.VoidChip.Count.Text=='-'and panel.DeliveredChip.Count.Text=='-'and not panel.GiveButton.Active,'before the server has said anything: counts unknown ("-"), GIVE disabled')
local function lookOf()return body.CFrame.LookVector end
local function faces(x,z,label)
 aim(x,20,z);frames(100);local look=lookOf()
 local dx,dz=x-bodyAt.X,z-bodyAt.Z;local len=math.sqrt(dx*dx+dz*dz)
 check(near(look.X,dx/len,.03)and near(look.Z,dz/len,.03)and math.abs(look.Y)<1e-6,label..' (look '..string.format('%.2f, %.2f, %.2f',look.X,look.Y,look.Z)..')')
end
faces(0,-300,'the camera in front (+Z): she faces +Z, level')
faces(100,-340,'the camera to her right (+X): she turns to +X (yaw only, never tilted)')
faces(100,-240,'the camera on the diagonal: she faces it (a ball: no corners)')
faces(0,-440,'the camera behind her: she turns right round to -Z')
faces(-80,-380,'and to the other side')
local lo,hi,posOk=1e9,-1e9,true
aim(0,20,-300);frames(100)
for _=1,200 do frames(1);local p=body.CFrame.Position;if p.X~=0 or p.Z~=-340 then posOk=false end;lo=math.min(lo,p.Y);hi=math.max(hi,p.Y)end
check(posOk and near(hi-lo,.5,.03)and near((hi+lo)/2,16.45,.03),('the bob: x and z fixed, y moves %.2f studs (+-FootOffset) around 16.45'):format(hi-lo))
check(body.Size.X==22 and body.Size.Y==22 and body.Size.Z==22,'(and she keeps her size while she is not talking)')
W.Gui.ReducedMotionEnabled=true;frames(3)
local p0=body.CFrame.Position;local look0=lookOf()
check(p0.X==0 and p0.Y==16.45 and p0.Z==-340 and near(look0.Z,1)and near(look0.X,0),'ReducedMotion: she is back at the server\'s spot and orientation')
aim(100,20,-340);frames(60);local p1=body.CFrame.Position
check(p1.Y==16.45 and near(lookOf().Z,1),'and does not turn or bob')
W.Gui.ReducedMotionEnabled=false;frames(100)
check(near(lookOf().X,1,.03),'with motion on again she turns to the camera')
aim(0,20,-300);frames(100)
-- 2. The marker, in the same sign as her name -------------------------------------------------------------------------------------
local mark=sign:FindFirstChild('Mark');local timerLabel=sign:FindFirstChild('Timer')
check(mark and mark:IsA('TextLabel')and mark.Text=='!'and mark.Visible and mark.TextColor3.R==1 and mark.TextColor3.G==1,'a "!" in her name sign')
-- Rows in studs: the marker (resting on the bottom of its row, bouncing up), the name, the timer: never overlapping.
local function rows()
 local H=S.H;local gh=mark.Size.Y.Scale*H;local bottom=mark.Position.Y.Scale*H
 return {Mark={Top=bottom-gh,Bottom=bottom},Name={Top=nameLabel.Position.Y.Scale*H,Bottom=(nameLabel.Position.Y.Scale+nameLabel.Size.Y.Scale)*H},
  Timer={Top=timerLabel.Position.Y.Scale*H,Bottom=(timerLabel.Position.Y.Scale+timerLabel.Size.Y.Scale)*H}}
end
local function clear(r)return r.Name.Top-r.Mark.Bottom,r.Timer.Top-r.Name.Bottom,r.Mark.Top end
local g1,g2,top=clear(rows())
check(g1>=1 and g2>=.4 and top>=-1e-6 and rows().Timer.Bottom<=S.H+1e-6,string.format('the marker, the name and the timer are separate rows: gaps %.1f and %.1f studs, all inside the sign (%.1f high)',g1,g2,S.H))
check(timerLabel and timerLabel:IsA('TextLabel')and timerLabel.Position.Y.Scale*S.H>=nameLabel.Position.Y.Scale*S.H+nameLabel.Size.Y.Scale*S.H,'the event timer is a small line under her name')
check(mark.AnchorPoint.Y==1 and near(rows().Mark.Bottom,S.Mark.Top+S.Mark.Height,1e-6),'the glyph rests on the bottom of its row, so it bounces up (away from the name)')
local function bounced()local lo2,hi2=1e9,-1e9;for _=1,60 do frames(1);local y=mark.Position.Y.Scale*S.H;lo2=math.min(lo2,y);hi2=math.max(hi2,y)end;return hi2-lo2 end
check(sign:GetAttribute('Bounce')==false and bounced()<1e-6,'"!" stands still')
local plain=F.tool(W,'Forest Seed Pack',{SeedPackTool=true,SeedInventoryId='p1',BagVariant='Pack01',Stage=1},backpack);frames(2)
local notPack=F.tool(W,'Odd tool',{BagVariant='EclipseReliquary',SeedInventoryId='x'},backpack);frames(2)
check(mark.Text=='!','other packs (and a Tool without SeedPackTool) do not count')
local voidTool=F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='v1',BagVariant='EclipseReliquary',Stage=7},backpack);frames(2)
check(mark.Text=='?'and mark.TextColor3.R==1 and mark.TextColor3.G>.7 and mark.TextColor3.B<.4 and sign:GetAttribute('Bounce')==true,'a Void Pack Tool appears in the Backpack: a gold "?"')
check(bounced()>1.1 and bounced()<=S.Mark.Bounce+1e-6,'the "?" bounces (up to '..S.Mark.Bounce..' studs)')
do -- the bounce never reaches the name or leaves its row, in any frame
 local worst,topWorst=1e9,1e9
 for _=1,150 do frames(1);local g,_,t=clear(rows());worst=math.min(worst,g);topWorst=math.min(topWorst,t)end
 check(worst>=1 and topWorst>=-1e-6,string.format('while the "?" bounces it keeps at least %.1f studs from the name and stays inside the sign',worst))
end
voidTool.Parent=character;frames(2)
check(mark.Text=='?','still "?" while it is held (Character)')
voidTool.Parent=backpack;frames(2)
W.Gui.ReducedMotionEnabled=true;frames(3)
check(mark.Text=='?'and bounced()<1e-6,'ReducedMotion: the "?" stays but does not bounce')
W.Gui.ReducedMotionEnabled=false;frames(3)
check(bounced()>1.1,'(and bounces again with motion on)')
local second=F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='v2',BagVariant='EclipseReliquary',Stage=7},backpack);frames(2)
voidTool:Destroy();frames(2)
check(mark.Text=='?','two Void Packs, one goes: still "?"')
second:Destroy();frames(2)
check(mark.Text=='!'and sign:GetAttribute('Bounce')==false,'the last one goes: back to "!"')
check(near(rows().Mark.Bottom,S.Mark.Top+S.Mark.Height,1e-6),'(and the marker is back at rest)')
do
 local late=F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='v3',Stage=7},backpack);frames(2)
 check(mark.Text=='!','(no BagVariant yet: no "?")')
 late:SetAttribute('BagVariant','EclipseReliquary');R.advance(1.2);frames(2)
 check(mark.Text=='?','a late BagVariant is found by the recount');late:Destroy();frames(2)
end
do
 backpack:Destroy();local fresh=R.new('Backpack');fresh.Parent=player;frames(2)
 F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='v4',BagVariant='EclipseReliquary',Stage=7},fresh);frames(2)
 check(mark.Text=='?','a new Backpack after respawn is watched');backpack=fresh
 for _,t in ipairs(fresh:GetChildren())do t:Destroy()end;frames(2);check(mark.Text=='!','(and back to "!")')
end
-- The timer line under her name: "HURRY! ENDS IN 27d 04h 12m 09s" (R152; it said EVENT ENDS IN) on the server's clock, ticking every second.
check(C.Event.Prefix=='HURRY! ENDS IN 'and timerLabel.Text:find('^HURRY! ENDS IN %d+d %d%dh %d%dm %d%ds$')~=nil,'the timer line reads like "HURRY! ENDS IN 27d 04h 12m 09s": '..timerLabel.Text)
do
 local left0=Limited.Left(W.workspace:GetServerTimeNow())
 check(timerLabel.Text=='HURRY! ENDS IN '..Limited.Text(left0),'(and it is LimitedEvent\'s text for the time left: '..left0..' s)')
 local before=timerLabel.Text;R.advance(1.05);frames(2)
 check(timerLabel.Text~=before and timerLabel.Text=='HURRY! ENDS IN '..Limited.Text(Limited.Left(W.workspace:GetServerTimeNow())),'it ticks: a second later '..timerLabel.Text)
end
-- 3. Her voice ----------------------------------------------------------------------------------------------------------------------
local function greetings()local n=0;for _,e in ipairs(soundLog)do if e.Sound.Name=='VerityGreeting'then n+=1 end end;return n end
local function voiceSound()return body:FindFirstChild('VerityGreeting')end
check(C.GreetingSoundId=='rbxassetid://123997993114202','the owner\'s greeting id is VerityConfig.GreetingSoundId')
check(greetings()==0,'(nothing has played yet: she was far away and no one talked to her)')
-- R150: her voice Sound is made as soon as she is in view (the clip downloads before anyone talks to her), so the first greeting is not waiting for it.
check(voiceSound()~=nil and not voiceSound().IsPlaying,'(her voice Sound already exists, silent, so the clip is loading)')
standAt(0,7,-150);frames(40);check(greetings()==0,'far away (190 studs): no greeting')
-- Open with Talk plays it, from her body.
check(mark.Visible and mark.Text=='!','(before anyone talked to her the "!" is showing)')
local nextAt=R.clock+754
server('Open',{VoidPacks=0,Delivered=3,RewardText=C.RewardText,EventActive=false,NextAt=nextAt})
local s=voiceSound()
check(not mark.Visible and sign:GetAttribute('MarkerShown')==false,'she has been talked to: the "!" is gone')
check(greetings()==1 and s and s:IsA('Sound')and s.Parent==body,'opening her dialog with Talk plays her greeting (once), from her body')
check(s and s.SoundId=='rbxassetid://123997993114202'and near(s.Volume,C.GreetingVolume),'rbxassetid://123997993114202 at the configured volume')
check(s and s.RollOffMode==R.Enum.RollOffMode.InverseTapered and s.RollOffMinDistance==30 and s.RollOffMaxDistance==140 and s.Looped==false,'3D: InverseTapered roll-off from 30 to 140 studs')
check(s and s.SoundGroup==Mixer.Group('Effects'),'routed to the Effects sound group (the player\'s Effects volume applies)')
check(preloadCalls==1,'the asset was asked for once, before she needed it')
-- She swells while it plays, and settles after.
local big,clearance=0,1e9;for _=1,40 do frames(1);big=math.max(big,body.Size.X);clearance=math.min(clearance,(sign.StudsOffset.Y-sign.Size.Y.Scale/2)-body.Size.X/2)end
check(big>22*1.03 and big<=22*(1+C.TalkPulse)+1e-6,string.format('a talking pulse while the voice plays: she swells up to %.2f (22 at rest)',big))
do -- R151: she grows upward from the dais (her bottom never sinks into it) and hops by TalkBounce of her size on top of that
 local bottom=body.CFrame.Position.Y-body.Size.X/2
 check(bottom>=5.2+.25-.3 and bottom<=5.2+.25+.3+22*C.TalkBounce,'(she grows upward from the dais, she does not sink into it; her bottom only leaves it by the hop: '..string.format('%.2f',bottom-5.2-.25)..' of at most '..string.format('%.2f',22*C.TalkBounce)..')')
end
check(clearance>=.3,string.format('while she swells (and bobs) the sign\'s bottom edge stays at least %.2f studs above her top, from any camera angle (camera-space offset)',clearance))
-- No overlap: more Talks while it plays do not start a second copy.
server('Open',{VoidPacks=0,Delivered=3});frames(20);server('Open',{VoidPacks=0,Delivered=3})
check(greetings()==1 and maxOverlap==1,'opening the dialog again while she is talking does not play a second copy (most heard at once: '..maxOverlap..')')
-- The voice is 3.2 s long: the moment it ends (not a safety timeout later) she can speak again.
R.advance(soundLog[#soundLog].At+3.3-R.clock);frames(1)
check(not s.IsPlaying,'(the voice has ended)')
server('Open',{VoidPacks=0,Delivered=3})
check(greetings()==2 and maxOverlap==1,'once it has ended, opening the dialog again plays it again at once')
R.advance(3.5);frames(60)
check(not s.IsPlaying and near(body.Size.X,22,1e-6),'when the voice ends she is back to her size')
panel.Header.Close.Activated:Fire();frames(2)
R.advance(4);frames(30)
-- Proximity: once on coming within 30 studs; not while standing there; not again within a minute; again after.
R.advance(70)
local before=greetings()
standAt(0,7,-300);frames(40)
check(greetings()==before,'40 studs away: no greeting yet')
standAt(0,7,-315);frames(40)
check(greetings()==before+1,'coming within 30 studs (25 away) greets once')
R.advance(4);frames(30);standAt(5,7,-318);frames(120)
check(greetings()==before+1,'standing there (or walking about) does not repeat it')
standAt(0,7,-150);frames(40);R.advance(10);standAt(0,7,-315);frames(40)
check(greetings()==before+1,'going away and coming back within a minute: no second greeting')
standAt(0,7,-150);frames(40);R.advance(60);standAt(0,7,-315);frames(40)
check(greetings()==before+2,'after a minute away, coming close greets again')
R.advance(70);frames(40)
check(greetings()==before+2,'not even after a minute of standing near her: it is for coming close, not for being close')
-- A Talk greeting just played: coming close does not greet again (and no overlap with a proximity one).
R.advance(5);frames(30);standAt(0,7,-150);frames(40);R.advance(70)
server('Open',{VoidPacks=0,Delivered=3});local afterTalk=greetings()
R.advance(4);frames(30);standAt(0,7,-315);frames(40)
check(greetings()==afterTalk,'coming close right after a Talk greeting does not greet again')
panel.Header.Close.Activated:Fire();frames(2)
R.advance(70);standAt(0,7,-150);frames(40);standAt(0,7,-318);frames(30)
local g=greetings();check(playing==1,'(a proximity greeting is playing)')
server('Open',{VoidPacks=0,Delivered=3})
check(greetings()==g and maxOverlap==1,'opening the dialog during a proximity greeting does not overlap it (most at once: '..maxOverlap..')')
panel.Header.Close.Activated:Fire();frames(2)
R.advance(4);frames(30)
-- The player's Effects volume: at 0 she is silent (and does not swell), otherwise it is the Effects group's volume.
Mixer.Set('Effects',0);local g0=greetings()
server('Open',{VoidPacks=0,Delivered=3});frames(30)
check(greetings()==g0 and near(body.Size.X,22,1e-6),'Effects volume 0: no greeting, no swelling')
panel.Header.Close.Activated:Fire();frames(2)
Mixer.Set('Effects',35);check(near(Mixer.Group('Effects').Volume,.35,1e-9)and voiceSound().SoundGroup==Mixer.Group('Effects'),'Effects volume 35: her voice follows the Effects group ('..Mixer.Group('Effects').Volume..')')
server('Open',{VoidPacks=0,Delivered=3})
check(greetings()==g0+1,'and she speaks again when it is above 0')
panel.Header.Close.Activated:Fire();frames(2);R.advance(4);frames(30)
Mixer.Set('Effects',100)
-- ReducedMotion: the voice plays, nothing swells.
W.Gui.ReducedMotionEnabled=true;frames(3)
server('Open',{VoidPacks=0,Delivered=3});local swell=0;for _=1,40 do frames(1);swell=math.max(swell,body.Size.X)end
check(greetings()==g0+2 and swell==22,'ReducedMotion: she still greets, without the swelling pulse')
panel.Header.Close.Activated:Fire();frames(2);R.advance(4);frames(30)
W.Gui.ReducedMotionEnabled=false;frames(3)
-- 3b. The "!" stays gone for the rest of this session (a rejoin = a new copy of the script shows it again); the "?" is a separate cue ---------
do
do local lo3=1e9;for _=1,200 do frames(1);lo3=math.min(lo3,(sign.StudsOffset.Y-sign.Size.Y.Scale/2)-body.Size.X/2)end;check(lo3>=.3,string.format('and through a whole bob cycle: %.2f studs',lo3))end
 check(not mark.Visible,'(the "!" is still gone after the voice and the proximity greetings)')
 R.advance(5);frames(30);check(not mark.Visible and sign:GetAttribute('MarkerShown')==false,'it does not come back by itself (time passing, the once-a-second recount)')
 server('Done',{Delivered=9});server('Refused',{Reason=C.Reasons.TooFar});panel.Header.Close.Activated:Fire();frames(2);plays={}
 check(not mark.Visible,'nor after a hand-in, a refusal or closing the window')
 local vt=F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='t1',BagVariant='EclipseReliquary',Stage=7},backpack);frames(2)
 check(mark.Visible and mark.Text=='?'and sign:GetAttribute('Bounce')==true and bounced()>1.1,'but a Void Pack still brings the bouncing "?" (a different cue)')
 local g,_,t=clear(rows());check(g>=1 and t>=-1e-6,'(the "?" keeps its gap to the name too: '..string.format('%.1f',g)..' studs)')
 vt:Destroy();frames(2)
 check(not mark.Visible and sign:GetAttribute('Bounce')==false,'the Void Pack goes: nothing (not the "!" again)')
 -- She streams out and in (the model is removed and added again): the session still remembers.
 W.CS:RemoveTag(model,'VerityNPC');frames(2)
 check(sign:FindFirstChild('Mark')==nil and sign:FindFirstChild('Timer')==nil,'(streamed out: her marker and timer go)')
 check(near(body.CFrame.Position.Y,16.45,1e-6)and near(lookOf().Z,1,1e-6)and near(lookOf().X,0,1e-6)and body.Size.X==22,'(and she is left exactly as the server placed her, so the next entry takes that as home)')
 W.CS:AddTag(model,'VerityNPC');frames(3)
 mark=sign:FindFirstChild('Mark');timerLabel=sign:FindFirstChild('Timer')
 check(mark and not mark.Visible and timerLabel and timerLabel.Text:find('^HURRY! ENDS IN '),'streamed back in: still no "!" (the session remembers), the timer is back')
 -- A respawn (new Backpack and Character) does not bring it back either.
 backpack:Destroy();local fresh=R.new('Backpack');fresh.Parent=player;frames(2);backpack=fresh;check(not mark.Visible,'a respawn does not bring it back')
end
-- 3c. Far away she is left alone: no writes to her collidable, queryable body (R148 review) ---------------------------------------------------
do
 local cfWrites,sizeWrites=0,0
 body:GetPropertyChangedSignal('CFrame'):Connect(function()cfWrites+=1 end)
 body:GetPropertyChangedSignal('Size'):Connect(function()sizeWrites+=1 end)
 local D=C.AnimateDistance
 check(D==300,'beyond 300 studs (VerityConfig.AnimateDistance) the client leaves her body alone')
 local function camAt(dist)aim(0,16.45,bodyAt.Z+dist);frames(3)end
 -- just inside the range: she moves (turns to the camera, bobs)
 camAt(D-10);cfWrites=0;frames(60)
 check(cfWrites>=30,'at '..(D-10)..' studs she is still animated ('..cfWrites..' CFrame writes in 60 frames)')
 sizeWrites=0;frames(100);check(sizeWrites==0,'(and her Size is not rewritten while she is not talking: '..sizeWrites..' writes)')
 -- beyond it: set back to the server's pose once, then not a single write
 camAt(D+10);local settled=near(body.CFrame.Position.Y,16.45,1e-6)and near(lookOf().Z,1,1e-6)and near(lookOf().X,0,1e-6)and body.Size.X==22
 check(settled,'beyond '..D..' studs she is put back to how the server placed her (once)')
 cfWrites,sizeWrites=0,0;frames(200)
 check(cfWrites==0 and sizeWrites==0,'and then 200 frames with the camera far away: no CFrame and no Size writes ('..cfWrites..' / '..sizeWrites..')')
 aim(300,200,bodyAt.Z+500);frames(60);check(cfWrites==0 and sizeWrites==0,'(any direction: camera 600 studs off)')
 -- her voice plays while the camera is far: no swelling writes either
 standAt(0,7,-318);frames(5);server('Open',{VoidPacks=0,Delivered=3});local vs=body:FindFirstChild('VerityGreeting');local playing0=vs and vs.IsPlaying
 cfWrites,sizeWrites=0,0;frames(100)
 check(playing0 and cfWrites==0 and sizeWrites==0 and body.Size.X==22,'her voice playing (dialog opened) with the camera far away: still no writes, she does not swell')
 panel.Header.Close.Activated:Fire();frames(2);R.advance(4);frames(60);standAt(0,7,-150);frames(30)
 -- back in range: writes resume and she is right (faces the camera, normal size once the voice is done)
 aim(100,16.45,bodyAt.Z);frames(2);cfWrites=0;frames(100)
 check(cfWrites>=50,'back inside the range the writes resume ('..cfWrites..' in 100 frames)')
 check(near(lookOf().X,1,.03)and body.Size.X==22,'and she is correct again: turned to the camera, back at her size')
 -- when nothing changes there is nothing to write (no bob, camera still): the pose is only rewritten when it changes
 local cfg=C.FootOffset;C.FootOffset=0;frames(60);cfWrites=0;frames(120)
 check(cfWrites==0,'with nothing moving (no bob offset, camera still, settled) she is not rewritten at all ('..cfWrites..' writes)');C.FootOffset=cfg
 aim(0,20,-300);frames(100)
end
-- 4. The dialog -----------------------------------------------------------------------------------------------------------------------
local gBefore=greetings()
server('Refused',{Reason=C.Reasons.Loading})
local quest,eventLine,voidChip,doneChip,rewardLine,status,give,closeButton=panel.QuestText,panel.EventLine,panel.VoidChip,panel.DeliveredChip,panel.Exchange.RewardLine,panel.Status,panel.GiveButton,panel.CloseButton
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Verity','a refusal while closed opens the window (SeedMenu = Verity)')
check(status.Text=='HOLD ON, YOUR DATA IS LOADING!'and not give.Active,'it shows the reason, GIVE disabled')
panel.Header.Close.Activated:Fire();frames(2)
check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'X closes it and clears SeedMenu')
check(greetings()==gBefore,'(a refusal does not make her speak: only Talk does)')
R.advance(5)
nextAt=R.clock+754
server('Open',{VoidPacks=0,Delivered=3,RewardText=C.RewardText,EventActive=false,NextAt=nextAt})
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Verity','Open shows the window and sets SeedMenu = Verity')
check(quest:GetAttribute('FullText')==C.Quest and not quest:GetAttribute('TextShortened')and quest.Text:gsub('\n',' ')==C.Quest,'her quest text, in full (wrapped by the text fitter): '..quest.Text:gsub('\n',' '))
check(panel.Header.Title.Text:find('VERITY',1,true),'titled VERITY')
check(voidChip.Count.Text=='0'and doneChip.Count.Text=='3'and voidChip.Caption.Text:find('VOID',1,true)and voidChip.Caption.Text=='YOUR VOID PACKS'and doneChip.Caption.Text=='YOU GAVE ME','chips: 0 Void packs, 3 handed in (R152 titles: YOUR VOID PACKS / YOU GAVE ME)')
check(rewardLine:GetAttribute('FullText')=='SWAP! 1 VOID PACK = 1 VERITY PACK'and C.RewardText=='SWAP! 1 VOID PACK = 1 VERITY PACK','the reward line from the server, in the exchange row')
local function eventEndsLines(root) -- every label of her window that says (or would say, in full) "... ENDS IN ..." (R152: the sign's "HURRY! ENDS IN ...")
 local found={};for _,d in ipairs((root or panel):GetDescendants())do
  if d:IsA('TextLabel')or d:IsA('TextButton')then
   local full=d:GetAttribute('FullText')
   if d.Text:find('ENDS IN',1,true)or(type(full)=='string'and full:find('ENDS IN',1,true))then found[#found+1]=d.Name..': '..d.Text end
  end
 end;return found
end
do -- R149 (owner: "remove the event ends thing"): her window has no "EVENT ENDS IN ..." line; the event itself still ends (section 8)
 local found=eventEndsLines()
 check(panel:FindFirstChild('EventTimer')==nil and #found==0,'her window has no "EVENT ENDS IN" line anywhere ('..table.concat(found,' | ')..')')
 R.advance(2.05);frames(2)
 check(#eventEndsLines()==0,'(nor does one appear later while the window is open)')
 nextAt=R.clock+754
 server('Open',{VoidPacks=0,Delivered=3,RewardText=C.RewardText,EventActive=false,NextAt=nextAt})
end
do local m0,s0=eventLine.Text:match('WAKES IN (%d+)m (%d+)s');local left0=m0 and tonumber(m0)*60+tonumber(s0)or -1
 check(eventLine.Visible and left0>=752 and left0<=754,'The Darkened\'s countdown (12m 34s, a moment ago): '..eventLine.Text)end
check(give.Active==false and give.Interactable==false and give.Caption.Text=='GIVE VOID PACK\u{00A0}🌑','no Void pack: GIVE VOID PACK 🌑 is disabled')
give.Activated:Fire();frames(2);check(#fired==0,'(clicking it sends nothing)')
check(closeButton.Caption.Text=='BYE! 👋','a close button, "BYE! 👋" (R152)')
R.advance(61);frames(2)
local mm,ss=eventLine.Text:match('WAKES IN (%d+)m (%d+)s');local shownLeft=mm and tonumber(mm)*60+tonumber(ss)or -1;local trueLeft=nextAt-R.clock
check(mm and shownLeft<=754-60 and trueLeft-shownLeft<=2 and trueLeft-shownLeft>=-1,'the countdown ticks while open: '..eventLine.Text..' (really '..math.floor(trueLeft)..' s left)')
server('Open',{VoidPacks=0,Delivered=3,EventActive=true})
check(eventLine.Visible and eventLine.Text=='🌑 THE DARKENED IS HERE!!'and rewardLine:GetAttribute('FullText')==C.RewardText,'The Darkened is here: "HERE NOW" (and the reward line falls back to the config)')
server('Open',{VoidPacks=0,Delivered=3})
check(not eventLine.Visible,'no schedule information: the line is hidden')
server('Open',{VoidPacks=0,Delivered=3,EventActive=false,NextAt=R.clock-5})
check(eventLine.Visible and eventLine.Text=='🌑 THE DARKENED IS WAKING UP...','a NextAt in the past reads "waking up"')
server('Open',{VoidPacks=2,Delivered=3,EventActive=false})
check(voidChip.Count.Text=='2'and give.Active and give.Interactable,'two Void packs: GIVE VOID PACK is enabled')
give.Activated:Fire();frames(2)
check(#fired==1 and fired[1][1]=='Give'and #fired[1]==1,'a click sends exactly "Give" (no arguments)')
check(not give.Active and give.Caption.Text=='SWAPPING... ✨','then it is locked until the server answers')
give.Activated:Fire();give.Activated:Fire();frames(2);check(#fired==1,'more clicks while waiting send nothing')
server('Done',{Delivered=4,RecordId='x_1'})
check(status.Text==C.Thanks and plays[#plays]=='GemClaim','Done: the thank-you and the GemClaim sound ('..status.Text..')')
check(voidChip.Count.Text=='1'and doneChip.Count.Text=='4'and give.Active,'the counts update (1 Void pack left, 4 handed in) and GIVE is ready again')
give.Activated:Fire();frames(2);check(#fired==2,'a second hand-in sends a second Give')
server('Done',{Delivered=5})
local gemClaims=0;for _,k in ipairs(plays)do if k=='GemClaim'then gemClaims+=1 end end
check(voidChip.Count.Text=='0'and doneChip.Count.Text=='5'and not give.Active and gemClaims==2,'the last one: 0 left, GIVE disabled, the sound played twice (R150: a refusal earlier clicked Denied, which is not counted)')
server('Open',{VoidPacks=1,Delivered=5})
give.Activated:Fire();frames(2);check(#fired==3 and not give.Active,'(another click, waiting)')
server('Refused',{Reason=C.Reasons.TooFar})
check(status.Text=='OVER HERE! COME CLOSER TO ME!'and status.TextColor3.R>.9 and status.TextColor3.G<.5,'Refused: the reason, in red')
check(plays[#plays]=='Denied','R150: a refused hand-in clicks Denied (and a success never does)')
check(give.Active and voidChip.Count.Text=='1','and GIVE is unlocked again, the count unchanged')
give.Activated:Fire();frames(2);check(not give.Active and #fired==4,'(waiting for an answer that never comes)')
R.advance(3);frames(2);check(not give.Active,'still waiting after 3 s')
R.advance(1.2);frames(2);check(give.Active,'after 4 s the button is free again')
for _,payload in ipairs({{VoidPacks='x',Delivered=-1,RewardText=12,EventActive='yes',NextAt='soon'},{VoidPacks=0/0,Delivered=1e30},{}})do
 local ok=pcall(function()server('Open',payload)end)
 check(ok and voidChip.Count.Text~=nil,'an odd Open payload is handled')
end
check(voidChip.Count.Text=='0'and not give.Active,'(garbage counts read as 0 and disable GIVE)')
local ok1=pcall(function()remote.OnClientEvent:Fire('Open',nil);remote.OnClientEvent:Fire('Mystery',{});remote.OnClientEvent:Fire('Refused',5);frames(2)end)
check(ok1,'nil / unknown / non-table messages are ignored')
server('Open',{VoidPacks=1,Delivered=0})
closeButton.Activated:Fire();frames(2);check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'CLOSE closes it and clears SeedMenu')
server('Open',{VoidPacks=1,Delivered=0});gui.Shade.Activated:Fire();frames(2);check(not panel.Visible and pg:GetAttribute('SeedMenu')==nil,'tapping outside closes it')
pg:SetAttribute('SeedMenu','Inventory');server('Open',{VoidPacks=1,Delivered=0})
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Verity','opening while another menu is up takes SeedMenu over')
pg:SetAttribute('SeedMenu','Index');frames(2)
check(not panel.Visible and pg:GetAttribute('SeedMenu')=='Index','another menu opening closes hers and leaves its SeedMenu alone')
pg:SetAttribute('SeedMenu',nil);frames(2)
-- 4b. R152: the status line is not empty after an Open: it says what to do next, until the server answers ---------------------------------
do
 local function colorIs(c,r,g,b)return near(c.R,r/255,.01)and near(c.G,g/255,.01)and near(c.B,b/255,.01)end
 local MINT,GOLD,MUTED,RED=function(c)return colorIs(c,110,226,96)end,function(c)return colorIs(c,255,206,64)end,function(c)return colorIs(c,204,224,255)end,function(c)return c.R>.9 and c.G<.5 end
 server('Open',{VoidPacks=2,Delivered=3,EventActive=false})
 check(status.Text=='Ooh, a Void Pack! Hand it over!'and status.Text==C.Hint.Have and MINT(status.TextColor3),'you carry a Void Pack: "Ooh, a Void Pack! Hand it over!" in green ('..status.Text..')')
 server('Open',{VoidPacks=1,Delivered=3,EventActive=true})
 check(status.Text==C.Hint.Have,'(a Void Pack wins over The Darkened being here)')
 server('Open',{VoidPacks=0,Delivered=3,EventActive=true})
 check(status.Text=='Quick! Steal one in Storm Peaks!'and status.Text==C.Hint.Here and GOLD(status.TextColor3),'none, and The Darkened is here: "Quick! Steal one in Storm Peaks!" in gold ('..status.Text..')')
 server('Open',{VoidPacks=0,Delivered=3,EventActive=false,NextAt=R.clock+600})
 check(status.Text=='Get ready to steal one!'and status.Text==C.Hint.Wait and MUTED(status.TextColor3),'none, and it comes back later: "Get ready to steal one!" in pale blue ('..status.Text..')')
 server('Open',{VoidPacks=0,Delivered=3})
 check(status.Text==C.Hint.Wait,'(no schedule information reads the same)')
 server('Open',{VoidPacks=1,Delivered=3,EventActive=false})
 give.Activated:Fire();frames(2)
 check(status.Text==''and give.Caption.Text=='SWAPPING... ✨','while the hand-in waits the status line is quiet and the button says "SWAPPING... ✨"')
 server('Done',{Delivered=4})
 check(status.Text=='Yay, thanks! Here\'s your Verity Pack!'and status.Text==C.Thanks and MINT(status.TextColor3),'Done: the thanks replaces the hint ('..status.Text..')')
 server('Open',{VoidPacks=0,Delivered=4,EventActive=true})
 check(status.Text==C.Hint.Here,'opening the window again: the thanks is gone and the hint is back')
 server('Open',{VoidPacks=1,Delivered=4,EventActive=true});give.Activated:Fire();frames(2)
 server('Refused',{Reason=C.Reasons.NoVoid})
 check(status.Text=='NO VOID PACK YET! GO STEAL ONE!'and RED(status.TextColor3),'a refusal replaces the hint, in red ('..status.Text..')')
 R.advance(5);frames(2);check(status.Text==C.Reasons.NoVoid,'(and it stays while the window is open)')
 server('Open',{VoidPacks=1,Delivered=4,EventActive=true})
 check(status.Text==C.Hint.Have,'the next Open brings the hint back')
 -- Every text of her window is one of these: nothing else is left in the old words.
 local words={C.Quest,C.RewardText,C.Thanks,C.Notice,C.Dialog.VoidChip,C.Dialog.DoneChip,C.Dialog.Give,C.Dialog.Busy,C.Dialog.Close,C.Dialog.Here,C.Dialog.Next,C.Dialog.Arriving,C.Hint.Have,C.Hint.Here,C.Hint.Wait,C.Hint.Over,C.Event.Prefix,C.Event.Ended,C.PromptActionText}
 for _,r in pairs(C.Reasons)do words[#words+1]=r end
 local old={'HANDED IN','VOID PACKS YOU HAVE','ARRIVES IN','HANDING IT OVER','EVENT ENDED','EVENT ENDS IN','Thank you! Here is','COME CLOSER TO VERITY','VERITY IS NOT READY','YOU NEED A VOID PACK'}
 local stale={};for _,w in ipairs(words)do for _,o in ipairs(old)do if w:find(o,1,true)then stale[#stale+1]=o..' in "'..w..'"'end end end
 check(#stale==0 and #words>=30,'none of her '..#words..' texts still has an old wording ('..table.concat(stale,' | ')..')')
 pg:SetAttribute('SeedMenu',nil);frames(2)
end
-- 5. Verity herself in the window (R149: her 3D model in a ViewportFrame), and the exchange as real pack pictures ---------------------------------
server('Open',{VoidPacks=2,Delivered=7,EventActive=true});frames(4)
local portrait=panel.Portrait;local view=portrait:FindFirstChild('Model')
check(portrait.Visible and view and view:IsA('ViewportFrame'),'the portrait is a ViewportFrame (her 3D model), not a flat picture')
check(portrait:FindFirstChild('Ball')==nil and portrait:FindFirstChild('Picture',true)==nil and #(function()local out={};for _,d in ipairs(portrait:GetDescendants())do if d:IsA('ImageLabel')then out[#out+1]=d end end;return out end)()==0,'(no flat ball frame and no flat ImageLabel picture left in it)')
local pcam=view and view.CurrentCamera;check(pcam and pcam:IsA('Camera')and pcam.Parent==view,'the ViewportFrame has its own Camera (CurrentCamera set)')
local pmodel=view and view:FindFirstChild('VerityPortrait');local pball=pmodel and pmodel:FindFirstChild('Body')
check(pball and pball:IsA('BasePart')and pball.Shape==R.Enum.PartType.Ball,'her model is in it: a Ball part')
check(pball and pball.Color==C.BodyColor and pball.Material==R.Enum.Material.SmoothPlastic,'yellow SmoothPlastic, like the ball in the world (VerityConfig.BodyColor)')
local pdecal=pball and pball:FindFirstChildOfClass('Decal')
check(pdecal and pdecal.Texture==C.Image and pdecal.Face==R.Enum.NormalId.Front,'with her smiley (VerityConfig.Image) as a Decal on its Front face')
check(pball and pcam and pball.CFrame.Position.Magnitude<=C.Portrait.Bob*C.Portrait.Size+1e-6 and pcam.CFrame.Position.Z<0 and pcam.CFrame.LookVector.Z>.99,'the camera looks at the ball from the front (her face looks toward -Z, the camera is on that side)')
local lookFrom=pcam and (pball.CFrame.Position-pcam.CFrame.Position).Unit;check(lookFrom and math.abs(lookFrom.X)<.05 and lookFrom.Z>.99,'straight at it, so her face is toward the camera')
local vr,pr=rect(view),rect(portrait);check(math.abs(vr.W-vr.H)<1 and vr.W>80 and vr.X>=pr.X and vr.Y>=pr.Y and vr.X+vr.W<=pr.X+pr.W and vr.Y+vr.H<=pr.Y+pr.H,'the viewport is a square inside the portrait frame ('..vr.W..' px)')
check(portrait:FindFirstChildOfClass('UICorner')~=nil and portrait:FindFirstChildOfClass('UIStroke')~=nil and portrait.BackgroundColor3==W.module('GardenTheme').Colors.Inset,'the panel keeps its look: rounded, a gold border, the inset colour')
check(view.BackgroundTransparency==1 and portrait:FindFirstChild('Dais')~=nil,'(and the gold dais under her shows through the transparent viewport)')
-- It bobs gently while the window is open (the ball moves a little, the camera does not).
do
 local lo,hi=1e9,-1e9;local camAt=pcam.CFrame.Position
 for _=1,240 do frames(1);local y=pball.CFrame.Position.Y;lo=math.min(lo,y);hi=math.max(hi,y)end
 check(hi-lo>.15*C.Portrait.Bob*C.Portrait.Size and hi-lo<=2*C.Portrait.Bob*C.Portrait.Size+C.Portrait.Size*(C.TalkBounce+C.TalkPulse/2)+1e-6 and pcam.CFrame.Position==camAt,string.format('the portrait ball bobs gently and bounces with her voice (%.2f of %d studs; R151: the window opening greets, so the hop is in it) and the camera stays put',hi-lo,C.Portrait.Size))
end
-- The pictures are the game's 3D packs (ItemPictures into ViewportFrames), the same ones the hotbar uses.
local exchange=panel.Exchange;local voidHolder,verityHolder,arrow=exchange.VoidPack,exchange.VerityPack,exchange.Arrow
check(voidHolder and verityHolder and arrow and arrow.Text=='➜','the exchange row: a Void pack picture, an arrow, a Verity pack picture')
for _=1,200 do frames(1)end
local vv,ve=voidHolder:FindFirstChild('ItemViewport'),verityHolder:FindFirstChild('ItemViewport')
check(vv and vv:IsA('ViewportFrame')and ve and ve:IsA('ViewportFrame'),'both holders got a ViewportFrame (ItemViewport)')
local function partsOf(root)local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then out[#out+1]=d end end;return out end
local function decalsOf(root)local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
local refVoid=Visuals.Bag(CF(0,0,0),nil,1,nil,7,'EclipseReliquary',1,1,'None');local refVerity=Visuals.Bag(CF(0,0,0),nil,1,nil,7,'VerityReliquary',1,1,'None')
local refVoidNames,refVerityNames={}, {};for _,p in ipairs(partsOf(refVoid))do refVoidNames[p.Name]=true end;for _,p in ipairs(partsOf(refVerity))do refVerityNames[p.Name]=true end
local voidParts=vv and partsOf(vv)or{};local veParts=ve and partsOf(ve)or{}
local allVoid=#voidParts>0;for _,p in ipairs(voidParts)do if not refVoidNames[p.Name]then allVoid=false end end
check(#voidParts>=#partsOf(refVoid)*.8 and #voidParts>100 and allVoid,'the Void picture is built from the real Void pack model ('..#voidParts..' of its '..#partsOf(refVoid)..' parts, all of them the model\'s own)')
check(#veParts>=1 and ve:FindFirstChild('VerityPicture',true)~=nil,'the Verity picture is built from the real Verity pack model (the yellow pack with its smiley Decal, '..#veParts..' parts)') -- R148: the pack is the plain pack painted yellow
local vd=ve and decalsOf(ve)or{};check(#vd==2 and vd[1].Texture==C.Image and vd[2].Texture==C.Image,'with Verity\'s smiley Decals on it (the pack art\'s two faces)')
check(#voidParts~=#veParts,'(two different pictures: the Void pack is not the Verity pack)')
local function key(variant)return Pictures.Key(F.tool(W,'x',{SeedPackTool=true,SeedInventoryId='k',Stage=7,BagVariant=variant,PackMutation='None'},W.workspace))end
check(key('EclipseReliquary')=='Pack|7|EclipseReliquary|None'and key('VerityReliquary')=='Pack|7|VerityReliquary|None','the hotbar and the Bag use these looks for these packs')
local askedVoid,askedVerity;for _,e in ipairs(shows)do if e.Name=='VoidPack'then askedVoid=e elseif e.Name=='VerityPack'then askedVerity=e end end
check(#shows==2 and askedVoid and askedVerity and askedVoid.Key==key('EclipseReliquary')and askedVerity.Key==key('VerityReliquary'),'the dialog asked ItemPictures for exactly those two looks (Stage 7 Void: '..tostring(askedVoid and askedVoid.Key)..', Verity: '..tostring(askedVerity and askedVerity.Key)..')')
check(Pictures.Stats().Views>=2,'(ItemPictures holds the two views: '..Pictures.Stats().Views..')')
local vr,er=rect(voidHolder),rect(verityHolder)
check(vr.W==vr.H and er.W==er.H and vr.W>=40 and not overlap(vr,er)and rect(arrow).X>=vr.X+vr.W-1 and rect(arrow).X+rect(arrow).W<=er.X+1,'two square pictures with the arrow between them: '..vr.W..' px each')
-- 6. The window fits phones and computers ------------------------------------------------------------------------------------------------
local function itemsOf()
 local out={{'quest',quest},{'chips-void',voidChip},{'chips-done',doneChip},{'void picture',voidHolder},{'arrow',arrow},{'verity picture',verityHolder},{'reward',rewardLine},{'status',status},{'give',give},{'close',closeButton}}
 if eventLine.Visible then table.insert(out,2,{'event',eventLine})end
 return out
end
local TextS=W.service('TextService')
-- R149: the quest sentence as the engine would draw it: the text on screen (the fitter's own line breaks) is the whole sentence, at a readable
-- size, in at most 5 lines (a phone's 314 px column), every line inside the box's width and all of them inside its height (measured with the wider font, 1.15 x the size a line: the fitter's own rule).
local function questProblems(label,minSize)
 local abs=label.AbsoluteSize;local lines={};for line in (label.Text..'\n'):gmatch('(.-)\n')do lines[#lines+1]=line end
 local size=label.TextSize;local widest=0
 for _,line in ipairs(lines)do widest=math.max(widest,TextS:GetTextSize(line,size,label.Font,R.Vector2.new(1e5,1e5)).X)end
 local why=''
 if table.concat(lines,' ')~=C.Quest then why=why..' not the whole sentence ("'..table.concat(lines,' ')..'")'end
 if label:GetAttribute('TextShortened')then why=why..' TextShortened'end
 if size<minSize then why=why..' font '..size..' < '..minSize end
 if #lines>5 then why=why..' '..#lines..' lines'end
 if widest>abs.X-4+1e-6 then why=why..(' a line is %d px in a %d px box'):format(widest,abs.X)end
 if #lines*size*1.15>abs.Y+1e-6 then why=why..(' %d lines of %d px need %d px, the box is %d'):format(#lines,size,#lines*size*1.15,abs.Y)end
 return why,#lines,size
end
-- R152: a one-line label as the REAL font would draw it: the capitals of FredokaOne are about 15% wider than the mock's measure (the margin of the quest check
-- above), so a line too wide for its box at that width is drawn smaller by the same factor. Returns the size it would settle on.
local function realOneLine(label)
 local abs=label.AbsoluteSize;local size=label.TextSize
 local wide=TextS:GetTextSize(label.Text,size,label.Font,R.Vector2.new(1e5,1e5)).X*1.15
 local room=abs.X-4
 return wide<=room and size or math.floor(size*room/wide)
end
local sizes={{1920,1080},{1280,720},{1024,768},{844,390},{780,360},{667,340},{667,375},{430,932},{390,844},{390,760},{375,667},{360,640},{360,600}}
local worstSize,worstLines=99,0
for _,sz in ipairs(sizes)do
 for _,variant in ipairs({{'with The Darkened\'s line',{VoidPacks=2,Delivered=7,EventActive=true}},{'without it',{VoidPacks=2,Delivered=7}},
  {'none, here now',{VoidPacks=0,Delivered=7,EventActive=true}},{'none, countdown',{VoidPacks=0,Delivered=7,EventActive=false,NextAt=R.clock+754}}})do
  resize(sz[1],sz[2]);server('Done',{Delivered=8});server('Open',variant[2]);frames(4)
  local P=rect(panel);local good,why=true,''
  local short=P.H<380
  local items=itemsOf()
  check(eventLine.Visible==(variant[2].EventActive==true or variant[2].NextAt~=nil),'(the Darkened line shows only when there is something to say)')
  for i,a in ipairs(items)do
   local r=rect(a[2])
   if r.X<P.X-1 or r.Y<P.Y-1 or r.X+r.W>P.X+P.W+1 or r.Y+r.H>P.Y+P.H+1 then good=false;why=why..(' %s outside the panel'):format(a[1])end
   if r.W<24 or r.H<16 then good=false;why=why..(' %s too small (%dx%d)'):format(a[1],r.W,r.H)end
   for j=i+1,#items do if overlap(r,rect(items[j][2]))then good=false;why=why..(' %s/%s overlap'):format(a[1],items[j][1])end end
  end
  for _,a in ipairs({{'give',give},{'close',closeButton}})do local r=rect(a[2]);if r.H<36 or r.W<80 then good=false;why=why..' '..a[1]..' is hard to tap'end end
  for _,a in ipairs({{'void picture',voidHolder},{'verity picture',verityHolder}})do local r=rect(a[2]);if r.W<40 or r.H<40 then good=false;why=why..' '..a[1]..' too small to read ('..r.W..')'end end
  local row=rect(exchange);local inRow=true
  for _,a in ipairs({voidHolder,arrow,verityHolder,rewardLine})do local r=rect(a);if r.X<row.X-1 or r.X+r.W>row.X+row.W+1 or r.Y<row.Y-1 or r.Y+r.H>row.Y+row.H+1 then inRow=false end end
  if not inRow then good=false;why=why..' exchange row content outside the row'end
  local pr=rect(portrait);local pic=''
  if portrait.Visible then
   local bb=rect(view)
   if pr.X<P.X-1 or pr.Y<P.Y-1 or pr.X+pr.W>P.X+P.W+1 or pr.Y+pr.H>P.Y+P.H+1 then good=false;why=why..' portrait outside'end
   if bb.X<pr.X or bb.Y<pr.Y or bb.X+bb.W>pr.X+pr.W or bb.Y+bb.H>pr.Y+pr.H then good=false;why=why..' 3D model viewport outside its frame'end
   if math.abs(bb.W-bb.H)>1 or bb.W<80 then good=false;why=why..' viewport not square / too small'end
   for _,a in ipairs(items)do if overlap(pr,rect(a[2]))then good=false;why=why..' portrait overlaps '..a[1]end end
   if not(view.Parent==portrait and view:FindFirstChild('VerityPortrait'))then good=false;why=why..' portrait model missing'end
   pic='portrait '..bb.W..' px'
  else pic='portrait hidden';if view:FindFirstChild('VerityPortrait')then good=false;why=why..' a hidden portrait still holds its model'end end
  local hdr=rect(panel.Header.Close);if hdr.X+hdr.W>P.X+P.W+1 or hdr.W<30 then good=false;why=why..' X button off or small'end
  for _,label in ipairs({eventLine,rewardLine,status,voidChip.Count,doneChip.Count,voidChip.Caption,doneChip.Caption,give.Caption,closeButton.Caption})do
   if label:GetAttribute('TextShortened')then good=false;why=why..' text cut: '..tostring(label.Name)..' ("'..label.Text..'")'end
  end
  -- R152: every one-line text stays readable with the real font too (the status line and The Darkened's line are the longest).
  for _,label in ipairs({eventLine,status,give.Caption,closeButton.Caption,voidChip.Caption,doneChip.Caption})do
   if label.Visible and label.Text~=''then
    local real=realOneLine(label);local need=math.min(label.TextSize,short and 10 or 12) -- (a box too short for a bigger font, like the chip titles, is not the text's doing)
    if real<need then good=false;why=why..(' %s would be %d px with the real font ("%s")'):format(label.Name,real,label.Text)end
   end
  end
  -- The quest sentence (R149: it was cut off with "..." in the owner's window): in full and readable, on the first Open and on every later one.
  local qwhy,qlines,qsize=questProblems(quest,short and 12 or 14)
  worstSize=math.min(worstSize,qsize);worstLines=math.max(worstLines,qlines)
  if qwhy~=''then good=false;why=why..' QUEST:'..qwhy end
  server('Open',variant[2]);frames(2);server('Open',variant[2]);frames(2)
  local qwhy2=questProblems(quest,short and 12 or 14)
  if qwhy2~=''then good=false;why=why..' QUEST after reopening:'..qwhy2 end
  -- No empty room: the rows run from the header to the bottom edge with one gap between each.
  local rows={quest,voidChip,exchange,status,give}
  if eventLine.Visible then table.insert(rows,2,eventLine)end
  local headH=rect(panel.Header).H;local gapWant=short and 6 or 10
  if math.abs((rect(quest).Y-P.Y)-(headH+12))>1 then good=false;why=why..' the first row is not right under the header'end
  for i=1,#rows-1 do local a,b=rect(rows[i]),rect(rows[i+1]);if math.abs((b.Y-(a.Y+a.H))-gapWant)>1 then good=false;why=why..(' gap %d is %d px, not %d'):format(i,b.Y-(a.Y+a.H),gapWant)end end
  local last=rect(rows[#rows]);if math.abs((P.Y+P.H)-(last.Y+last.H)-12)>1 then good=false;why=why..' the last row is not at the bottom'end
  check(good,('window fits %dx%d %s (panel %dx%d, %s, packs %d px, quest %d px in %d lines)%s'):format(sz[1],sz[2],variant[1],P.W,P.H,pic,rect(voidHolder).W,qsize,qlines,why))
  pg:SetAttribute('SeedMenu',nil);frames(1)
 end
end
print(('(the quest sentence: at worst %d px in %d lines)'):format(worstSize,worstLines))
resize(1280,720)
server('Open',{VoidPacks=1,Delivered=0});resize(360,640)
for _,reason in pairs(C.Reasons)do
 server('Refused',{Reason=reason});frames(2)
 check(not status:GetAttribute('TextShortened')and status:GetAttribute('FullText')==reason,'every server refusal fits a phone in full: '..reason)
end
resize(1280,720)
-- 7. Teardown, then a second copy with a greeting that cannot load -------------------------------------------------------------------------
gui:Destroy();frames(3)
check(mark.Parent==nil and voiceSound()==nil,'the marker and the voice go with the script')
local ok2=pcall(function()aim(50,20,-100);frames(5);remote.OnClientEvent:Fire('Open',{VoidPacks=1})end)
check(ok2,'nothing runs (or errors) after it is torn down')
preloadMode='fail';preloadCalls=0;local warns0=W.warns or 0;local count0=greetings()
local sc2=load('a second VerityClient (greeting asset fails to load)');frames(5)
local gui2=pg:FindFirstChild('VerityGui');local panel2=gui2 and gui2.VerityPanel
do
 local mark2=sign:FindFirstChild('Mark')
 check(mark2 and mark2~=mark and mark2.Visible and mark2.Text=='!','a new session (a rejoin: a fresh copy of the script): the "!" shows again')
 server('Refused',{Reason='YOUR DATA IS STILL LOADING'});check(mark2.Visible,'a refusal is not "talking to her": the "!" stays')
 panel2.Header.Close.Activated:Fire();frames(2)
end
standAt(0,7,-318);R.advance(70);frames(40)
local okOpen=pcall(function()server('Open',{VoidPacks=1,Delivered=0});R.advance(5);server('Open',{VoidPacks=1,Delivered=0})end)
check(okOpen and panel2.Visible,'a greeting asset that fails to load does not break her dialog')
check(not sign:FindFirstChild('Mark').Visible,'(and opening it hid the "!" in this session)')
check(greetings()==count0 and #(function()local out={};for _,e in ipairs(soundLog)do out[#out+1]=e end;return out end)()==count0,'nothing is played')
check((W.warns or 0)==warns0+1,'and it is warned about exactly once ('..((W.warns or 0)-warns0)..' warnings)')
check(near(body.Size.X,22,1e-6),'(and she does not swell for a voice that never plays)')
gui2:Destroy();frames(3)
-- A Play() that throws is tolerated too (warned once, skipped).
preloadMode='ok';playMode='throw';warns0=W.warns or 0
local sc3=load('a third VerityClient (Sound:Play errors)');frames(5)
local gui3=pg:FindFirstChild('VerityGui')
local ok3=pcall(function()server('Open',{VoidPacks=1,Delivered=0});R.advance(5);server('Open',{VoidPacks=1,Delivered=0})end)
check(ok3 and gui3.VerityPanel.Visible and (W.warns or 0)==warns0+1,'a Sound that errors on Play is skipped without breaking the dialog, warned once ('..((W.warns or 0)-warns0)..')')
playMode=nil;gui3:Destroy();frames(3)
-- 8. The event ends ----------------------------------------------------------------------------------------------------------------
do
 preloadMode='ok';playMode=nil
 R.clock=Limited.EndsAt-2
 local sc4=load('a fourth VerityClient (2 s before the end of the event)');frames(5)
 local gui4=pg:FindFirstChild('VerityGui');local panel4=gui4.VerityPanel
 local mk=sign:FindFirstChild('Mark');local tl=sign:FindFirstChild('Timer')
 check(mk.Visible and mk.Text=='!'and tl.Text=='HURRY! ENDS IN 0d 00h 00m 02s','2 s before the end: the "!" shows and the sign says "'..tl.Text..'"')
 server('Open',{VoidPacks=2,Delivered=4})
 local gb,gc=panel4.GiveButton,panel4.GiveButton.Caption
 check(#eventEndsLines(panel4)==0 and gb.Active and gc.Text=='GIVE VOID PACK\u{00A0}🌑','2 s before the end the dialog has no countdown (R149) and GIVE VOID PACK works')
 local vt=F.tool(W,'Void Pack',{SeedPackTool=true,SeedInventoryId='e1',BagVariant='EclipseReliquary',Stage=7},backpack);frames(2)
 check(mk.Visible and mk.Text=='?','(with a Void Pack she shows the "?")')
 R.advance(1.1);frames(2)
 check(#eventEndsLines(panel4)==0 and tl.Text=='HURRY! ENDS IN 0d 00h 00m 01s','one second later her sign says "'..tl.Text..'" and the dialog still has no countdown')
 R.advance(1.1);frames(3) -- the end has passed
 check(not gb.Active and not gb.Interactable and gc:GetAttribute('FullText')==C.Event.Ended and #eventEndsLines(panel4)==0,'the event ends while the window is open: GIVE is disabled and says "'..gc.Text..'" even with Void Packs')
 check(tl.Text==C.Event.Ended and tl.TextColor3.R>.9 and tl.TextColor3.G<.5,'her sign says the event is over too')
 check(not mk.Visible and sign:GetAttribute('Bounce')==false,'and neither the "!" nor the "?" shows (with a Void Pack in the Bag)')
 local n0=#fired;gb.Activated:Fire();frames(2);check(#fired==n0,'clicking GIVE sends nothing')
 server('Open',{VoidPacks=2,Delivered=4})
 check(not gb.Active and gc:GetAttribute('FullText')==C.Event.Ended and C.Event.Ended=='EVENT OVER! THANKS!'and panel4.VoidChip.Count.Text=='2','a fresh Open after the end: 2 Void Packs counted, GIVE still disabled, "EVENT OVER! THANKS!"')
 check(panel4.Status.Text==C.Hint.Over and panel4.Status.Text=='Thanks for playing, you were great!','(and the status line says so too: "'..panel4.Status.Text..'")')
 server('Refused',{Reason=C.Reasons.EventEnded});check(panel4.Status.Text=='EVENT\'S OVER! THANKS FOR PLAYING!','the server\'s refusal text is shown: '..panel4.Status.Text)
 vt:Destroy();frames(2);gui4:Destroy();frames(3)
 -- A session that starts after the end: the "!" never shows.
 local sc5=load('a fifth VerityClient (after the end)');frames(5)
 local gui5=pg:FindFirstChild('VerityGui');local mk5=sign:FindFirstChild('Mark');local tl5=sign:FindFirstChild('Timer')
 check(not mk5.Visible and tl5.Text==C.Event.Ended,'a session after the end: no "!", the sign says the event is over')
 R.advance(5);frames(30);check(not mk5.Visible,'(and it never comes back)')
 server('Open',{VoidPacks=0,Delivered=0});check(gui5.VerityPanel.GiveButton.Caption:GetAttribute('FullText')==C.Event.Ended and not gui5.VerityPanel.GiveButton.Active,'her dialog says the event is over on the GIVE button, which is disabled')
 -- Phones: the ended window fits too.
 resize(360,640);check(not gui5.VerityPanel.GiveButton.Caption:GetAttribute('TextShortened')and not gui5.VerityPanel.Status:GetAttribute('TextShortened'),'EVENT OVER! THANKS! and the status line fit on a phone')
 check(realOneLine(gui5.VerityPanel.GiveButton.Caption)>=12 and realOneLine(gui5.VerityPanel.Status)>=12,'(and stay readable with the real font: '..realOneLine(gui5.VerityPanel.GiveButton.Caption)..' / '..realOneLine(gui5.VerityPanel.Status)..' px)');resize(1280,720)
 gui5:Destroy();frames(3)
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
