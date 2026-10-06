--!nocheck
-- R151 hub displays (R152: the pedestal, the spinning showcase item and the dancing avatar): the REAL HubDisplayClient as the local player, on the displays the REAL HubDisplayArt builds (with a
-- showcase item and an avatar rig):
--  1. the countdown on the pedestal's plaque: right at once, kept up to date, "New fruit in ..." for the fruit board, for a display that streams in later, nothing without its attributes;
--  2. motion only when near (260 studs in, 300 out) and allowed: the item turns about its own vertical axis and floats a little (one bulk move every frame; 30 times a second on the middle tier), the sparkles are an
--     emitter ON the item's own ItemCore part in the champion's colour (they turn with it), a dancing avatar is left to its Animator (the client writes none of its joints), a rig in the static
--     pose cheers (joint transforms, bounded), the per-frame function is connected only while a display is near, and everything is put back when you walk away;
--  3. reduced motion and the lowest quality: no motion, no sparkles, no pop, the dance is paused (speed 0) and runs again; the countdown still runs;
--  4. a new champion (the server bumps Rev): a burst of sparks over the item (no ring), a posed avatar celebrates (both arms up) and calms down; not on the first look, not from afar, not
--     with reduced motion, not for a calm board;
--  5. the celebration sound for a remote from the server, and only for a well-formed one;
--  6. robustness: the server swapping the item or the avatar, an avatar whose mode arrives late, a display streaming out and back, a display with nothing in it, a destroyed model.
local HH=require('./hub_harness');local H=HH.H;local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local rawWarn=W.env.warn;W.env.warn=function(msg,...)if tostring(msg):find('fruit meshes',1,true)then return end;rawWarn(msg,...)end
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('MeshPart');p.Name=key;p.Size=V3(1,1,1);return p end}end
Meshes.Status=function()return 'Ready'end
local Rules=W.module('HubDisplayRules');local Pose=W.module('HubAvatarPose')
local Art=H.server('HubDisplayArt');local Avatar=H.server('HubDisplayAvatar')
HH.installPlayers()
local CS=W.CS;local Gui=W.Gui
-- BulkMoveTo really moves (the shared mock's is empty); count the calls.
local bulk=0
function W.workspace.BulkMoveTo(_,list,cfs)bulk+=1;for i,p in ipairs(list)do p.CFrame=cfs[i]end end
local me=H.player(1,'Me',true)
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local celebrate=R.new('RemoteEvent');celebrate.Name='HubDisplayCelebrate';celebrate.OnClientEvent=R.signal();celebrate.Parent=remotes
-- the displays, as the server leaves them with a champion --------------------------------------------------------------------------------------------------------
-- BEST PULL's avatar dances (the Animator plays a track); BIGGEST FRUIT's could not (the dance never loads): the static pose, which the client cheers.
local avatars=Avatar.new({Players=W.service('Players'),Clock=HH.clock().now})
local tracks={}
local function dressed(kind,state,dances)
 local d=Art.BuildFrame(map,kind,Rules.Layout,4)
 local item=Art.BuildItem(d,kind=='Pull'and{Kind='Seed',Id='FirePepperSeed',Coat='None',Accent={230,125,255}}or{Kind='Fruit',Id='SunflowerSeed',Coat='None',Accent={230,125,255}})
 Art.SetItem(d,item)
 local rig=avatars:Build(1001)
 avatars:Place(rig,d.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn)
 Art.SetAvatar(d,rig)
 HH.avatars.Dance.Mode=dances==false and'never loads'or'ok'
 avatars:Animate(rig,1001)
 tracks[kind]=HH.avatars.Dance.Last
 HH.avatars.Dance.Mode='ok'
 local text=Rules.SignText(kind,nil,'SunflowerSeed',1,'Watermelon')
 Art.SetSign(d,text)
 local m=d.Model
 m:SetAttribute('Accent',R.Color3.fromRGB(230,125,255))
 m:SetAttribute('FooterPrefix',kind=='Pull'and'New board in 'or'New fruit in ')
 m:SetAttribute('NextAt',math.floor(R.clock+5*3600+12*60+30))
 m:SetAttribute('State',state or'Champion');m:SetAttribute('Rev',1)
 return d
end
R.clock=20727*86400+3600
local pullD=dressed('Pull');local fruitD=dressed('Fruit',nil,false)
local center=pullD.Model:GetAttribute('ItemCenter')
local function camera(offset)H.look(center+offset,center)end
camera(V3(0,0,-600)) -- far away
H.tier=3
-- load the client
local sc=R.new('LocalScript');sc.Name='HubDisplayClient';W.load('HubDisplayClient',sc)
H.run(1.2)
local function itemParts(d)local out={};for _,p in ipairs(d.ItemFolder:GetDescendants())do if p:IsA('BasePart')then out[#out+1]=p end end;return out end
local function homes(parts)local h={};for _,p in ipairs(parts)do h[p]=p.CFrame.Position end;return h end
local function moved(parts,home)local m=0;for _,p in ipairs(parts)do local q=p.CFrame.Position;if math.abs(q.X-home[p].X)+math.abs(q.Y-home[p].Y)+math.abs(q.Z-home[p].Z)>1e-4 then m+=1 end end;return m end
local function angle(cf)local r=cf.R;local tr=r[1][1]+r[2][2]+r[3][3];return math.acos(math.clamp((tr-1)/2,-1,1))end
local function joint(d,name)local rig=d.AvatarFolder:FindFirstChildOfClass('Model');return rig and Pose.Joint(rig,name)end
local function core(d)local item=d.ItemFolder:FindFirstChildOfClass('Model');return item and item:FindFirstChild('ItemCore')end
local function sparksOf(d)local c=core(d);return c and c:FindFirstChild('HubSparks')end
local pullParts=itemParts(pullD);local pullHome=homes(pullParts)

-- 1. The countdown -------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local label=pullD.Plate.Footer;local flabel=fruitD.Plate.Footer
 check(label.Text=='New board in 5h 12m','the plaque\'s footer shows the countdown at once: "'..label.Text..'"')
 check(flabel.Text=='New fruit in 5h 12m','and the fruit board says "New fruit in ..."')
 H.run(60*5)
 check(label.Text=='New board in 5h 7m','five minutes later: "'..label.Text..'"')
 H.run(5*3600+4*60)
 check(label.Text:find('^New board in %d+m %d+s$')~=nil,'in the last hour it shows minutes and seconds: "'..label.Text..'"')
 pullD.Model:SetAttribute('NextAt',math.floor(R.clock+4000))
 check(label.Text=='New board in 1h 6m','a new NextAt is followed at once (the attribute is listened to): "'..label.Text..'"')
 -- a display without its attributes is left alone
 local lone=Art.BuildFrame(map,'Pull',{Target=V3(0,4,-265),Pull={Center=V3(100,4,-100)},Fruit={Center=V3(-100,4,-100)}},4)
 lone.Plate.Footer.Text='x'
 H.run(6)
 check(lone.Plate.Footer.Text=='x','a display with no NextAt is not touched')
 lone.Model:Destroy()
 H.run(1)
 -- a display that streams in later
 local late=Art.BuildFrame(map,'Fruit',{Target=V3(0,4,-265),Pull={Center=V3(100,4,-100)},Fruit={Center=V3(150,4,-150)}},4)
 late.Model:SetAttribute('FooterPrefix','New fruit in ');late.Model:SetAttribute('NextAt',math.floor(R.clock+90))
 check(late.Plate.Footer.Text=='New fruit in 1m 30s'or late.Plate.Footer.Text=='New fruit in 1m 29s','a display tagged after the client started is picked up, and its attributes followed at once ("'..late.Plate.Footer.Text..'")')
 late.Model:Destroy()
end

-- 2. Motion only when near -------------------------------------------------------------------------------------------------------------------------------------------------
do
 R.clock+=1
 camera(V3(0,0,-400))
 H.run(1.5)
 check(H.renderConnections()==0,'far away (400 studs): no per-frame function is connected')
 check(moved(pullParts,pullHome)==0,'the item stands still')
 check(not sparksOf(pullD),'no sparkles')
 check(angle(joint(fruitD,'RightShoulder').Transform)==0,'the posed avatar is not moved by the client')
 camera(V3(-30,-8,-40)) -- a player walking up to it
 H.run(1.2)
 check(H.renderConnections()>=1,'near (about 50 studs): the per-frame function is connected')
 local e=sparksOf(pullD)
 check(e and e:IsA('ParticleEmitter')and not sparksOf(fruitD),'sparkles on the item that is near (not the far display)')
 check(e.Parent==core(pullD)and e:IsDescendantOf(pullD.ItemFolder:FindFirstChildOfClass('Model')),'the sparkles are ON the item: an emitter parented to its ItemCore, inside the item (they move with it, nothing flat behind it)')
 check(e.Rate==16 and e.Color.A and math.abs(e.Color.A.R*255-230)<1 and e.Shape==R.Enum.ParticleEmitterShape.Sphere and e.ShapeInOut==R.Enum.ParticleEmitterShapeInOut.Outward,'at the full quality tier, in the champion\'s colour, spawning round the item and drifting outward')
 local m1=moved(pullParts,pullHome)
 check(m1>=#pullParts*.9,'the item turns ('..m1..' of '..#pullParts..' parts have moved)')
 local axis=center
 local stable,bobs=true,{}
 for _,p in ipairs(pullParts)do
  local q=p.CFrame.Position;local h=pullHome[p]
  local r1=math.sqrt((q.X-axis.X)^2+(q.Z-axis.Z)^2);local r0=math.sqrt((h.X-axis.X)^2+(h.Z-axis.Z)^2)
  if math.abs(r1-r0)>1e-3 then stable=false end
  bobs[#bobs+1]=q.Y-h.Y
 end
 local sameBob=true;for _,b in ipairs(bobs)do if math.abs(b-bobs[1])>1e-3 or math.abs(b)>.61 then sameBob=false end end
 check(stable and sameBob,'it turns about its own vertical axis and floats up and down together (every part keeps its distance from the axis; the whole item rises by the same <= .6 studs)')
 -- the speed: .6 rad/s
 local sample=pullParts[1];local before=sample.CFrame.Position;local a0=math.atan2(before.Z-axis.Z,before.X-axis.X)
 H.run(2)
 local after=sample.CFrame.Position;local a1=math.atan2(after.Z-axis.Z,after.X-axis.X)
 local d=(a1-a0)%(2*math.pi);if d>math.pi then d-=2*math.pi end
 check(math.abs(math.abs(d)-1.2)<.15,'about 0.6 radians a second ('..string.format('%.2f',math.abs(d)/2)..')')
 -- the core is one of the turning parts: the light and the sparkles stay in the middle of the item
 local c=core(pullD);local cp=c.CFrame.Position
 check(c and math.abs(cp.X-axis.X)<1.5 and math.abs(cp.Z-axis.Z)<1.5 and math.abs(cp.Y-axis.Y)<=3.5,'the core (light and sparkles) stays at the item\'s centre while it turns')
 -- the dance is the Animator's: no joint of a dancing avatar is written by the client, and its track runs at full speed
 local rs=joint(pullD,'RightShoulder');local waist=joint(pullD,'Waist')
 check(angle(rs.Transform)==0 and angle(waist.Transform)==0 and pullD.AvatarFolder:FindFirstChildOfClass('Model'):GetAttribute('AvatarMode')=='dance','a dancing avatar: the client writes none of its joints')
 check(tracks.Pull and tracks.Pull.IsPlaying and tracks.Pull.Speed==1 and tracks.Pull.Looped,'its looped dance track is playing at full speed')
 -- the cheer of a rig the server could only pose
 local fc=fruitD.Model:GetAttribute('ItemCenter')
 H.look(fc+V3(0,-8,-40),fc);H.run(1.2)
 local rs2=joint(fruitD,'RightShoulder');local waist2=joint(fruitD,'Waist')
 check(fruitD.AvatarFolder:FindFirstChildOfClass('Model'):GetAttribute('AvatarMode')=='pose'and angle(rs2.Transform)>0 and angle(rs2.Transform)<=Pose.MaxAngle and angle(waist2.Transform)<=Pose.MaxAngle,'an avatar in the static pose (the dance could not load) cheers: its joints get bounded transforms')
 local seen={};for step=1,60 do H.run(.1);seen[#seen+1]=angle(rs2.Transform)end
 local lo,hi=1e9,0;for _,a in ipairs(seen)do lo=math.min(lo,a);hi=math.max(hi,a)end
 check(hi-lo>.1 and hi<=Pose.MaxAngle,'and keeps moving (the arm waves between '..string.format('%.2f',lo)..' and '..string.format('%.2f',hi)..' rad)')
 local touched=true;local rig=fruitD.AvatarFolder:FindFirstChildOfClass('Model')
 for _,d in ipairs(rig:GetDescendants())do if d:IsA('Motor6D')then local a=angle(d.Transform);local named=Pose.CheerAt(0,0)[d.Name];if a>1e-9 and not named then touched=false end end end
 check(touched,'only the cheer\'s own joints are written (the legs and wrists are never touched)')
 camera(V3(-30,-8,-40));H.run(1.2)
 -- the cost: one bulk move a frame (R152 review fix B6: 20 a second turned in visible steps; the item is at most 150 parts)
 bulk=0;H.run(2,1/60)
 check(bulk>=110 and bulk<=125,'the item is moved with one BulkMoveTo every frame ('..bulk..' in 2 s at 60 fps)')
 -- walking away puts everything back
 camera(V3(0,0,-400))
 H.run(1.5)
 check(H.renderConnections()==0,'walked away: the per-frame function is gone')
 check(moved(pullParts,pullHome)==0,'the item is back where the server put it')
 check(not sparksOf(pullD)and not sparksOf(fruitD),'the sparkles are gone')
 check(angle(joint(fruitD,'RightShoulder').Transform)==0 and angle(joint(fruitD,'Waist').Transform)==0,'the posed avatar relaxes (its joints are reset)')
 -- hysteresis: 280 studs away it does not start, but once going it keeps going until 300
 camera(V3(0,0,-280));H.run(1.2)
 check(H.renderConnections()==0,'280 studs away: not near enough to start (260)')
 camera(V3(0,0,-250));H.run(1.2);check(H.renderConnections()>=1,'250 studs away (about the far side of the hub): it starts')
 camera(V3(0,0,-290));H.run(1.2);check(H.renderConnections()>=1,'290 studs away: it keeps going (it stops past 300)')
 camera(V3(0,0,-320));H.run(1.2);check(H.renderConnections()==0,'320 studs away: it stops')
 -- the second display
 local fruitParts=itemParts(fruitD);local fh=homes(fruitParts)
 H.look(fc+V3(0,-8,-40),fc);H.run(1.2)
 check(moved(fruitParts,fh)>=#fruitParts*.9 and sparksOf(fruitD)and not sparksOf(pullD),'the fruit display spins when you stand at it (and the other does not)')
 camera(V3(0,0,-400));H.run(1.5)
end

-- 3. Reduced motion and quality ---------------------------------------------------------------------------------------------------------------------------------------------
do
 Gui.ReducedMotionEnabled=true
 camera(V3(-30,-8,-40));H.run(1.5)
 check(H.renderConnections()==0 and moved(pullParts,pullHome)==0,'reduced motion: nothing is connected and nothing turns')
 check(not sparksOf(pullD)and angle(joint(fruitD,'RightShoulder').Transform)==0,'no sparkles, no cheer')
 check(tracks.Pull.Speed==0,'a dancing avatar is paused (its track speed is 0)')
 pullD.Model:SetAttribute('NextAt',math.floor(R.clock+3600*2+60));H.run(6)
 check(pullD.Plate.Footer.Text:find('^New board in 2h')~=nil,'the countdown still runs ("'..pullD.Plate.Footer.Text..'")')
 local popsBefore=H.named('HubPopSparks')
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(1.2)
 check(H.named('HubPopSparks')==popsBefore,'a new champion pops nothing with reduced motion')
 Gui.ReducedMotionEnabled=false
 H.run(1.5)
 check(H.renderConnections()>=1 and tracks.Pull.Speed==1,'switching it off brings the motion and the dance back')
 H.tier=1;H.run(1.5)
 check(H.renderConnections()==0 and not sparksOf(pullD)and tracks.Pull.Speed==0,'the lowest quality tier: no motion, no sparkles, the dance paused')
 H.tier=2;H.run(1.5)
 check(H.renderConnections()>=1 and tracks.Pull.Speed==1,'the middle tier moves')
 local e=sparksOf(pullD)
 check(e and e.Rate==8,'with half the sparkles')
 bulk=0;H.run(2,1/60)
 check(bulk>=55 and bulk<=66,'and the item is moved about 30 times a second instead of every frame (R152 review fix B6: 12 a second turned in visible steps) ('..bulk..' bulk moves in 2 s)')
 -- a calm board (nobody holds the spot): the item turns, but no sparkles
 pullD.Model:SetAttribute('Calm',true);H.run(1.2)
 check(not sparksOf(pullD)and H.renderConnections()>=1,'a calm display has no sparkles (the item still turns)')
 pullD.Model:SetAttribute('Calm',false);H.run(1.2)
 check(sparksOf(pullD)~=nil,'and they come back with a champion')
 H.tier=3;camera(V3(0,0,-400));H.run(1.5)
 check(tracks.Pull.Speed==1,'(away again: the dance runs for everyone who is not reduced)')
end

-- 4. A new champion ---------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local fc=fruitD.Model:GetAttribute('ItemCenter')
 H.look(fc+V3(0,-8,-40),fc);H.run(1.5)
 local before=H.named('HubPopSparks')
 H.run(2)
 check(H.named('HubPopSparks')==before,'standing there changes nothing by itself (no pop on the first look or while nothing changes)')
 fruitD.Model:SetAttribute('Rev',fruitD.Model:GetAttribute('Rev')+1)
 H.run(.6)
 check(H.named('HubPopSparks')==before+1 and H.named('HubPopRing')==0,'a new champion: a burst of sparks over the item (and no ring: nothing flat)')
 local spark;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='HubPopSparks'then spark=c end end
 local em=spark and spark:FindFirstChildOfClass('Attachment')and spark:FindFirstChildOfClass('Attachment'):FindFirstChildOfClass('ParticleEmitter')
 check(em and em._emitted==36,'with 36 sparks (18 on the lower tiers)')
 check(near((spark.CFrame.Position-fc).Magnitude,0,.01),'at the item\'s centre, in the air over the pedestal')
 check(em and near(em.Color.A.R*255,230,1),'in the champion\'s colour')
 local ls=joint(fruitD,'LeftShoulder')
 H.run(.5)
 check(angle(ls.Transform)>1,'the posed avatar throws both arms up ('..string.format('%.2f',angle(ls.Transform))..' rad)')
 H.run(2.5)
 check(angle(ls.Transform)<.2,'and calms down again')
 H.run(1)
 check(H.named('HubPopSparks')==before,'the burst cleans itself up')
 -- a dancing avatar just keeps dancing (the pop is only the sparks)
 camera(V3(-30,-8,-40));H.run(1.5)
 local rs=joint(pullD,'RightShoulder')
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(1)
 check(angle(rs.Transform)==0 and tracks.Pull.IsPlaying,'a dancing avatar is left to its dance on a new champion')
 H.run(2)
 -- the champion is not announced by Rev when the display is empty
 pullD.Model:SetAttribute('State','Empty');local n=H.named('HubPopSparks')
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(.6)
 check(H.named('HubPopSparks')==n,'an empty board (a new day) does not pop')
 pullD.Model:SetAttribute('State','Champion')
 camera(V3(0,0,-600));H.run(1.5)
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(.6)
 check(H.named('HubPopSparks')==n,'from 600 studs away nothing pops (nobody is looking)')
 camera(V3(0,0,-400));H.run(1.5)
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(.6)
 check(H.named('HubPopSparks')==n+1,'from 400 studs (a landmark you can see) it does pop, once')
 H.run(2);camera(V3(0,0,-600));H.run(1.5)
end

-- 5. The sound -----------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local n0=H.soundCount('GemClaim')
 celebrate.OnClientEvent:Fire({Kind='Pull',Name='Zed'})
 check(H.soundCount('GemClaim')==n0+1,'the server\'s celebration plays the game\'s GemClaim chime')
 celebrate.OnClientEvent:Fire({Kind='Fruit',Name='Zed'})
 check(H.soundCount('GemClaim')==n0+2,'for the fruit board too')
 celebrate.OnClientEvent:Fire({Kind='Bogus'});celebrate.OnClientEvent:Fire('x');celebrate.OnClientEvent:Fire(nil);celebrate.OnClientEvent:Fire(5)
 check(H.soundCount('GemClaim')==n0+2,'anything else is ignored')
end

-- 6. Robustness -----------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 camera(V3(-30,-8,-40));H.run(1.5)
 -- the server swaps the item (a new champion): the client takes up the new parts, and its core gets the sparkles
 local item2=Art.BuildItem(pullD,{Kind='Seed',Id='AppleSeed',Coat='None'})
 Art.SetItem(pullD,item2)
 local newParts=itemParts(pullD);local nh=homes(newParts)
 H.run(1.5)
 check(moved(newParts,nh)>=#newParts*.9,'a new item is picked up and turns ('..#newParts..' parts)')
 check(sparksOf(pullD)and sparksOf(pullD).Parent==item2:FindFirstChild('ItemCore'),'and the sparkles are on the new item\'s core')
 -- the server swaps the avatar: a rig whose mode has not arrived yet is left alone, then 'pose' makes it cheer
 local rig=avatars:Build(1002);avatars:Place(rig,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,rig)
 H.run(1.5)
 check(angle(Pose.Joint(rig,'RightShoulder').Transform)==0,'a new avatar whose mode is not known yet is not touched')
 rig:SetAttribute('AvatarMode','pose');H.run(1.2)
 check(angle(Pose.Joint(rig,'RightShoulder').Transform)>0,'when the server says it is in the static pose it cheers')
 rig:SetAttribute('AvatarMode','dance');H.run(1.2)
 check(angle(Pose.Joint(rig,'RightShoulder').Transform)==0,'and when it says it dances, the client lets go of its joints')
 -- a fallback (blocky) avatar has no joints: nothing to pose, no error
 local stand=avatars:Fallback(false);avatars:Place(stand,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,stand);avatars:Animate(stand)
 local ok=pcall(function()H.run(2)end)
 check(ok,'a blocky stand-in avatar is left alone')
 -- a silhouette
 Art.SetAvatar(pullD,nil);local ok2=pcall(function()H.run(2)end)
 check(ok2,'no avatar at all')
 Art.SetItem(pullD,nil);local ok3=pcall(function()H.run(2)end)
 check(ok3,'no item at all (a slot cleared)')
 Art.SetItem(pullD,Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat='None'}))
 -- streaming out: the model leaves the world
 local m=pullD.Model;m.Parent=nil;CS:RemoveTag(m,Rules.Tag)
 local ok4=pcall(function()H.run(2)end)
 check(ok4 and not sparksOf(pullD),'a display that streams out is forgotten (its sparkles with it, no error)')
 m.Parent=map;CS:AddTag(m,Rules.Tag)
 H.run(1.5)
 check(sparksOf(pullD)~=nil,'and a streamed-back copy starts clean')
 -- destroyed outright
 local d3=dressed('Fruit');H.run(1.2)
 d3.Model:Destroy();local ok5=pcall(function()H.run(2)end)
 check(ok5,'a destroyed display is dropped without an error')
 camera(V3(0,0,-600));H.run(1.5)
 check(H.renderConnections()==0,'nothing stays connected when nothing is near')
 -- the whole run left no stray parts behind
 local strays=H.named('HubPopRing')+H.named('HubPopSparks')
 check(strays==0,'no pop parts are left in the workspace')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
