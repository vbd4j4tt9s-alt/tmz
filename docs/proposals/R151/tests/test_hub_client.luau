--!nocheck
-- R151 hub displays (R152: the pedestal, the spinning showcase item and the dancing avatar): the REAL HubDisplayClient as the local player, on the displays the REAL HubDisplayArt builds (with a
-- showcase item and an avatar rig the REAL HubDisplayAvatar made ready):
--  0. R153: the DANCE is this client's: ONE looped track of the server's DanceId on the rig's Animator (the server's), playing at once, the joints left alone; a dance that will not
--     load is retried with the next ids (4 tries, 5 s each) and then the rig is posed here (once) and cheers; what happened is reported to the server (HubDisplayAvatarReport);
--  1. the countdown on the big label's Footer row: right at once, kept up to date, "New fruit in ..." for the fruit board, for a display that streams in later, nothing without its attributes;
--  2. motion only when near (260 studs in, 300 out) and allowed: the item turns about its own vertical axis and floats a little (one bulk move every frame, on the middle tier too since R153), the sparkles are an
--     emitter ON the item's own ItemCore part in the champion's colour (they turn with it), a dancing avatar is left to its Animator (the client writes none of its joints), a rig in the static
--     pose cheers (joint transforms, bounded), the per-frame function is connected only while a display is near, and everything is put back when you walk away;
--  2b. R153: nothing culls or pauses the dance on screen or off it (the item's culling only), no per-frame joint write while it plays, on screen -> off -> on: the same track plays on;
--  3. reduced motion and Fast Mode: no motion, no sparkles, no pop, the dance is paused (speed 0) and runs again; the automatic quality tier (a frame-rate dip) stops the item's motion but
--     never the dance (R153: it used to freeze it); the countdown still runs;
--  4. a new champion (the server bumps Rev): a burst of sparks over the item (no ring), a posed avatar celebrates (both arms up) and calms down; not on the first look, not from afar, not
--     with reduced motion, not for a calm board;
--  5. the celebration sound for a remote from the server, and only for a well-formed one;
--  6. robustness: the server swapping the item or the avatar, an avatar whose mode arrives late, a display streaming out and back, a display with nothing in it, a destroyed model;
--     R153: the watchdog (a stopped, unlooped, slowed or destroyed track is put right; another track on the Animator is stopped), the same champion keeps its track, no Animator
--     from the server (one is made here after a try), a slow load, a first load that fails, a stand-in and the silhouette stay static, no leaks over many champion changes.
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
local reports={} -- (R153: what the client tells the server about each dance)
local reportRemote=R.new('RemoteEvent');reportRemote.Name='HubDisplayAvatarReport';reportRemote.Parent=remotes
reportRemote.FireServer=function(_,info)reports[#reports+1]=info end
local function lastReport(kind)for i=#reports,1,-1 do if reports[i].Kind==kind then return reports[i]end end;return nil end
local warned={};do local w=W.env.warn;W.env.warn=function(msg,...)if tostring(msg):find('did not load',1,true)then warned[#warned+1]=tostring(msg)end;w(msg,...)end end
-- the displays, as the server leaves them with a champion --------------------------------------------------------------------------------------------------------
-- Both avatars are made ready to dance by the server (HubDisplayAvatar.Animate: an Animator, DanceId, no track); on this screen BEST PULL's dance loads, BIGGEST FRUIT's never does
-- (the rig's MockDance attribute: the mock's LoadAnimation reads it), so this client retries and then poses and cheers it.
local avatars=Avatar.new({Players=W.service('Players'),Clock=HH.clock().now})
local function dressed(kind,state,danceMode)
 local d=Art.BuildFrame(map,kind,Rules.Layout,4)
 local item=Art.BuildItem(d,kind=='Pull'and{Kind='Seed',Id='FirePepperSeed',Coat='None',Accent={230,125,255}}or{Kind='Fruit',Id='SunflowerSeed',Coat='None',Accent={230,125,255}})
 Art.SetItem(d,item)
 local rig=avatars:Build(1001)
 avatars:Place(rig,d.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn)
 Art.SetAvatar(d,rig)
 if danceMode then rig:SetAttribute('MockDance',danceMode)end
 avatars:Animate(rig,1001)
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
local pullD=dressed('Pull');local fruitD=dressed('Fruit',nil,'never loads')
check(HH.avatars.Dance.Loads==0 and pullD.AvatarFolder:FindFirstChildOfClass('Model'):GetAttribute('AvatarMode')=='dance'and fruitD.AvatarFolder:FindFirstChildOfClass('Model'):GetAttribute('AvatarMode')=='dance','(the server made both avatars ready to dance and loaded nothing)')
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
local function rigOf(d)return d.AvatarFolder:FindFirstChildOfClass('Model')end
local function animatorsOf(rig)local out={};local hum=rig and rig:FindFirstChildOfClass('Humanoid');for _,c in ipairs(hum and hum:GetChildren()or{})do if c._class=='Animator'then out[#out+1]=c end end;return out end
local function tracksOf(rig)local out={};for _,a in ipairs(animatorsOf(rig))do for _,t in ipairs(a._tracks or{})do out[#out+1]=t end end;return out end
local function playingOf(rig)local n=0;for _,t in ipairs(tracksOf(rig))do if t.IsPlaying then n+=1 end end;return n end
local function danceTrack(d)local list=tracksOf(rigOf(d));return list[#list]end
local function restC0(rig)local n=0;for _,j in ipairs(rig:GetDescendants())do if j:IsA('Motor6D')and angle(j.C0)>1e-9 then n+=1 end end;return n end
local function anyTransform(rig)local n=0;for _,j in ipairs(rig:GetDescendants())do if j:IsA('Motor6D')and(angle(j.Transform)>1e-9 or j.Transform.Position.Magnitude>1e-9)then n+=1 end end;return n end
local function core(d)local item=d.ItemFolder:FindFirstChildOfClass('Model');return item and item:FindFirstChild('ItemCore')end
local function sparksOf(d)local c=core(d);return c and c:FindFirstChild('HubSparks')end
local pullParts=itemParts(pullD);local pullHome=homes(pullParts)

-- 0. The dance on this screen (R153) ---------------------------------------------------------------------------------------------------------------------------------------
do
 local rig=rigOf(pullD);local tr=danceTrack(pullD)
 check(tr and tr.IsPlaying and tr.Looped==true and tr.Speed==1 and tr.Length>0 and tr.Priority==R.Enum.AnimationPriority.Action,'BEST PULL: this client plays a looped dance track at full speed (Length '..tostring(tr and tr.Length)..')')
 check(tr and tr.Animation.AnimationId==rig:GetAttribute('DanceId')and table.find(Rules.DanceIds,tr.Animation.AnimationId)~=nil,'the server\'s pick of the three default R15 dances ('..tostring(tr and tr.Animation.AnimationId)..')')
 check(#animatorsOf(rig)==1 and tr.Animator==animatorsOf(rig)[1]and animatorsOf(rig)[1].Name~='HubDanceAnimator','on the Animator the server made (no second one)')
 check(#tracksOf(rig)==1 and playingOf(rig)==1 and tr.Fade and tr.Fade>0,'one track, the only one playing, fading in')
 check(restC0(rig)==0 and anyTransform(rig)==0,'its joints are left to the Animator: no pose in C0, no Transform written')
 local rp=lastReport('Pull')
 check(rp and rp.Mode=='dance'and rp.Loaded==true and rp.Length==2.4 and rp.Id==tr.Animation.AnimationId and rp.User==1001 and rp.Tries==1 and rp.Paused==false,'and it tells the server: dance, loaded, Length 2.4, the id, try 1')
 -- BIGGEST FRUIT: the dance never loads
 local frig=rigOf(fruitD);local first=tracksOf(frig)
 check(#first==1 and first[1].Length==0 and restC0(frig)==0 and anyTransform(frig)==0,'BIGGEST FRUIT: its dance is loading (no Length yet): nothing is posed or written meanwhile')
 local rf=lastReport('Fruit')
 check(rf and rf.Mode=='loading'and rf.Tries==1,'reported as loading, try 1')
 H.run(5)
 local second=tracksOf(frig)
 check(#second==2 and first[1].Destroyed and not first[1].IsPlaying and second[2].Animation.AnimationId~=first[1].Animation.AnimationId,'after 5 s with no Length the load is dropped and the next dance tried')
 H.run(10.5)
 check(#tracksOf(frig)==4 and restC0(frig)==0,'four tries in 20 s, still unposed while it tries')
 local ids={};for _,t in ipairs(tracksOf(frig))do ids[t.Animation.AnimationId]=true end
 local nIds=0;for _ in pairs(ids)do nIds+=1 end
 check(nIds==3 and tracksOf(frig)[1].Animation.AnimationId==frig:GetAttribute('DanceId'),'the server\'s pick first, then the other two default dances')
 H.run(5)
 local rs=Pose.Joint(frig,'RightShoulder')
 check(angle(rs.C0)>1.5 and angle(rs.C0)<2.3 and restC0(frig)==6,'then the rig is posed HERE (the static pose in six joints\' C0, the right arm raised)')
 local dead=true;for _,t in ipairs(tracksOf(frig))do if t.IsPlaying or not t.Destroyed then dead=false end end
 check(dead and playingOf(frig)==0,'no track is left playing (or kept) on it')
 rf=lastReport('Fruit')
 check(rf and rf.Mode=='pose'and rf.Loaded==false and rf.Tries==4 and rf.Length==0,'reported: posed after 4 tries, Length 0')
 check(#warned==1 and warned[1]:find('Fruit',1,true)and warned[1]:find('posed',1,true),'one warning in this player\'s output says so')
 local a0=angle(rs.C0);H.run(12)
 check(#tracksOf(frig)==4 and near(angle(rs.C0),a0,1e-9)and #warned==1,'and that is that: no more tries, the pose is applied once (not turned again), no more warnings')
 check(#tracksOf(rig)==1 and danceTrack(pullD)==tr and tr.IsPlaying,'BEST PULL still dances its one track')
end

-- 1. The countdown -------------------------------------------------------------------------------------------------------------------------------------------------------
do
 for _,d in ipairs({pullD,fruitD})do d.Model:SetAttribute('NextAt',math.floor(R.clock+5*3600+12*60+30))end -- (section 0 took half a minute)
 local label=pullD.Tag.Footer;local flabel=fruitD.Tag.Footer
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
 lone.Tag.Footer.Text='x'
 H.run(6)
 check(lone.Tag.Footer.Text=='x','a display with no NextAt is not touched')
 lone.Model:Destroy()
 H.run(1)
 -- a display that streams in later
 local late=Art.BuildFrame(map,'Fruit',{Target=V3(0,4,-265),Pull={Center=V3(100,4,-100)},Fruit={Center=V3(150,4,-150)}},4)
 late.Model:SetAttribute('FooterPrefix','New fruit in ');late.Model:SetAttribute('NextAt',math.floor(R.clock+90))
 check(late.Tag.Footer.Text=='New fruit in 1m 30s'or late.Tag.Footer.Text=='New fruit in 1m 29s','a display tagged after the client started is picked up, and its attributes followed at once ("'..late.Tag.Footer.Text..'")')
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
 check(danceTrack(pullD).IsPlaying and danceTrack(pullD).Speed==1 and danceTrack(pullD).Looped,'its looped dance track is playing at full speed')
 -- no per-frame joint write while it dances: a mark left in every joint survives a second of frames near it
 local mark=CF(0,0,.0123);local prig=rigOf(pullD)
 for _,j in ipairs(prig:GetDescendants())do if j:IsA('Motor6D')then j.Transform=mark end end
 H.run(1,1/60)
 local kept=0;local total=0;for _,j in ipairs(prig:GetDescendants())do if j:IsA('Motor6D')then total+=1;if j.Transform==mark then kept+=1 end end end
 check(kept==total and total==15,'while the dance plays nothing writes its joints, frame after frame ('..kept..' of '..total..' untouched)')
 for _,j in ipairs(prig:GetDescendants())do if j:IsA('Motor6D')then j.Transform=CF(0,0,0)end end
 -- the cheer of a rig the server could only pose
 local fc=fruitD.Model:GetAttribute('ItemCenter')
 H.look(fc+V3(0,-8,-40),fc);H.run(1.2)
 local rs2=joint(fruitD,'RightShoulder');local waist2=joint(fruitD,'Waist')
 check(rigOf(fruitD):GetAttribute('AvatarMode')=='dance'and angle(rs2.Transform)>0 and angle(rs2.Transform)<=Pose.MaxAngle and angle(waist2.Transform)<=Pose.MaxAngle,'an avatar posed here (its dance could not load on this screen) cheers: its joints get bounded transforms')
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

-- 2b. Nothing culls the dance (R153) ---------------------------------------------------------------------------------------------------------------------------------------
do
 local tr=danceTrack(pullD);local stops,plays,loads=tr.Stops,tr.Plays,HH.avatars.Dance.Loads
 local pc=pullD.Model:GetAttribute('ItemCenter');local feet=pullD.FeetAt.Position;local body=feet+V3(0,12,0)
 local Cull=W.module('ViewCull152');local rawHidden=Cull.Hidden
 local seen={}
 local function look(from,at,label)H.look(from,at);H.run(1.5);seen[#seen+1]=label..(tr.IsPlaying and tr.Speed==1 and''or' STOPPED')end
 look(body+V3(-20,0,-45),body,'on screen, near')
 look(body+V3(0,0,-150),body,'on screen, 150 studs')
 look(body+V3(0,40,-420),body,'on screen, 420 studs (past the motion range)')
 look(body+V3(-20,0,-45),body+V3(-60,0,-200),'looking away (off screen)')
 look(body+V3(-20,0,-45),body,'back on screen')
 Cull.Hidden=function()return true end -- (the item culled on every frame, wherever the camera looks)
 look(body+V3(-20,0,-45),body,'item culled, avatar on screen')
 look(body+V3(0,0,-150),pc,'item culled, 150 studs')
 Cull.Hidden=rawHidden
 local bad={};for _,x in ipairs(seen)do if x:find('STOPPED',1,true)then bad[#bad+1]=x end end
 check(#bad==0,'the dance plays at full speed on screen near and far, off screen and back, with the item culled ('..table.concat(bad,', ')..')')
 check(danceTrack(pullD)==tr and tr.Stops==stops and tr.Plays==plays and HH.avatars.Dance.Loads==loads,'the same track all along: never stopped, restarted or reloaded')
 camera(V3(0,0,-400));H.run(1.5)
end

-- 3. Reduced motion and quality ---------------------------------------------------------------------------------------------------------------------------------------------
do
 Gui.ReducedMotionEnabled=true
 camera(V3(-30,-8,-40));H.run(1.5)
 check(H.renderConnections()==0 and moved(pullParts,pullHome)==0,'reduced motion: nothing is connected and nothing turns')
 check(not sparksOf(pullD)and angle(joint(fruitD,'RightShoulder').Transform)==0,'no sparkles, no cheer')
 check(danceTrack(pullD).Speed==0 and danceTrack(pullD).IsPlaying,'a dancing avatar is paused (its track speed is 0, still playing: it resumes where it stood)')
 check(lastReport('Pull').Paused==true,'(and reported as paused)')
 pullD.Model:SetAttribute('NextAt',math.floor(R.clock+3600*2+60));H.run(6)
 check(pullD.Tag.Footer.Text:find('^New board in 2h')~=nil,'the countdown still runs ("'..pullD.Tag.Footer.Text..'")')
 local popsBefore=H.named('HubPopSparks')
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(1.2)
 check(H.named('HubPopSparks')==popsBefore,'a new champion pops nothing with reduced motion')
 Gui.ReducedMotionEnabled=false
 H.run(1.5)
 check(H.renderConnections()>=1 and danceTrack(pullD).Speed==1,'switching it off brings the motion and the dance back')
 local tr=danceTrack(pullD);local stops=tr.Stops
 H.tier=1;H.run(1.5)
 check(H.renderConnections()==0 and not sparksOf(pullD),'the lowest quality tier: no motion, no sparkles')
 check(tr.Speed==1 and tr.IsPlaying,'R153: but the dance plays on (the tier drops by itself when the frame rate dips: the R152 dance froze then)')
 for _,t in ipairs({2,1,3,1,2,1})do H.tier=t;H.run(.6)end
 check(tr.Speed==1 and tr.IsPlaying and tr.Stops==stops and danceTrack(pullD)==tr,'the tier going up and down never stops or freezes it')
 me:SetAttribute('FastMode',true);H.run(1.2)
 check(tr.Speed==0 and tr.IsPlaying,'Fast Mode (the player\'s own lowest quality) pauses it')
 me:SetAttribute('FastMode',nil);H.run(1.2)
 check(tr.Speed==1,'and switching Fast Mode off resumes it')
 H.tier=2;H.run(1.5)
 check(H.renderConnections()>=1 and danceTrack(pullD).Speed==1,'the middle tier moves')
 local e=sparksOf(pullD)
 check(e and e.Rate==8,'with half the sparkles')
 bulk=0;H.run(2,1/60)
 check(bulk>=110 and bulk<=125,'and the item is moved every frame too (R153: 30 a second still stepped on a 60 Hz screen; R152 fix B6: 12 a second) ('..bulk..' bulk moves in 2 s)')
 for _,fps in ipairs({30,144})do bulk=0;H.run(1,1/fps);check(math.abs(bulk-fps)<=2,string.format('R153: the middle tier at %d fps: one bulk move per drawn frame (%d in 1 s)',fps,bulk))end
 -- a calm board (nobody holds the spot): the item turns, but no sparkles
 pullD.Model:SetAttribute('Calm',true);H.run(1.2)
 check(not sparksOf(pullD)and H.renderConnections()>=1,'a calm display has no sparkles (the item still turns)')
 pullD.Model:SetAttribute('Calm',false);H.run(1.2)
 check(sparksOf(pullD)~=nil,'and they come back with a champion')
 H.tier=3;camera(V3(0,0,-400));H.run(1.5)
 check(danceTrack(pullD).Speed==1,'(away again: the dance runs for everyone who is not reduced)')
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
 check(angle(rs.Transform)==0 and danceTrack(pullD).IsPlaying,'a dancing avatar is left to its dance on a new champion')
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
 -- the server swaps the avatar: the old track goes with the old rig; a rig whose mode has not arrived yet is left alone, then 'pose' makes it cheer
 local oldTrack=danceTrack(pullD)
 local rig=avatars:Build(1002);avatars:Place(rig,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,rig)
 local loads=HH.avatars.Dance.Loads
 H.run(1.5)
 check(oldTrack.Destroyed and not oldTrack.IsPlaying,'a new champion: the old avatar\'s track is stopped and let go')
 check(angle(Pose.Joint(rig,'RightShoulder').Transform)==0 and HH.avatars.Dance.Loads==loads,'a new avatar whose mode is not known yet is not touched (nothing loaded for it)')
 rig:SetAttribute('AvatarMode','pose');H.run(1.2)
 check(angle(Pose.Joint(rig,'RightShoulder').Transform)>0 and HH.avatars.Dance.Loads==loads,'when the server says it is in the static pose it cheers (no dance)')
 avatars:Animate(rig,1002);H.run(1.2)
 local tr=danceTrack(pullD)
 check(rig:GetAttribute('AvatarMode')=='dance'and anyTransform(rig)==0 and tr and tr.IsPlaying and tr.Animation.AnimationId==rig:GetAttribute('DanceId'),'and when it says it dances, the client lets go of its joints and plays the dance')
 -- the watchdog (every half second): a stopped track plays again, an unlooped one is looped, a slowed one is put right, another track on the Animator is stopped
 tr:Stop();H.run(.6)
 check(tr.IsPlaying and #tracksOf(rig)==1,'the watchdog: a track that stopped plays again (the same track)')
 tr.Looped=false;tr:AdjustSpeed(.3);H.run(.6)
 check(tr.Looped==true and tr.Speed==1,'an unlooped or slowed track is looped and at full speed again')
 local foreign=animatorsOf(rig)[1]:LoadAnimation(R.new('Animation'));foreign:Play();loads=HH.avatars.Dance.Loads
 check(playingOf(rig)==2,'(another track playing on the same Animator: a second dance, the shaking)')
 H.run(.6)
 check(not foreign.IsPlaying and tr.IsPlaying and playingOf(rig)==1,'is stopped: one dance only')
 tr:Destroy();H.run(3)
 local tr2=danceTrack(pullD)
 check(tr2~=tr and tr2.IsPlaying and HH.avatars.Dance.Loads==loads+1 and playingOf(rig)==1,'a track that cannot play any more is loaded again (one new load)')
 -- the same champion (the server keeps the rig: a better record of the same player): the same track dances on
 local rev=pullD.Model:GetAttribute('Rev');loads=HH.avatars.Dance.Loads
 pullD.Model:SetAttribute('Rev',rev+1);H.run(2)
 check(danceTrack(pullD)==tr2 and tr2.IsPlaying and HH.avatars.Dance.Loads==loads,'a refresh of the same champion keeps the track (nothing reloaded, nothing stopped)')
 -- no Animator from the server (it never came): one is made here after the first try
 local bare=avatars:Build(1003);avatars:Place(bare,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,bare)
 bare:SetAttribute('DanceId',Rules.DanceIds[1]);bare:SetAttribute('AvatarMode','dance')
 H.run(1.2)
 check(#animatorsOf(bare)==0 and #tracksOf(bare)==0,'a rig said to dance but with no Animator yet: the client waits for the server\'s (a try)')
 H.run(5)
 local made=animatorsOf(bare)[1]
 check(#animatorsOf(bare)==1 and made.Name=='HubDanceAnimator'and danceTrack(pullD)and danceTrack(pullD).IsPlaying,'then makes one of its own and dances')
 -- a slow load (its Length comes 3 s later) is waited for; a first load that fails is followed by the next id
 HH.avatars.Dance.Delay=3
 local slow=avatars:Build(1004);avatars:Place(slow,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,slow);slow:SetAttribute('MockDance','late');avatars:Animate(slow,1004)
 check(not made.Parent or made:IsDescendantOf(bare),'(the animator it made went with its rig)')
 H.run(1.2)
 check(#tracksOf(slow)==1 and danceTrack(pullD).Length==0 and lastReport('Pull').Mode=='loading','a slow load (no Length yet): loading')
 H.run(3)
 check(#tracksOf(slow)==1 and danceTrack(pullD).Length>0 and danceTrack(pullD).IsPlaying and lastReport('Pull').Mode=='dance','is waited for: the same track dances once it has its Length')
 HH.avatars.Dance.FailFirst=HH.avatars.Dance.Loads+1
 local retry=avatars:Build(1005);avatars:Place(retry,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,retry);avatars:Animate(retry,1005)
 H.run(6)
 local rt=tracksOf(retry)
 check(#rt==2 and rt[1].Destroyed and rt[2].IsPlaying and rt[2].Animation.AnimationId~=rt[1].Animation.AnimationId and lastReport('Pull').Mode=='dance'and lastReport('Pull').Tries==2,'a first load that never comes: the second try (the next id) dances, reported as try 2')
 HH.avatars.Dance.FailFirst=0
 -- many champions in a row: no leaks (each one track; every earlier one stopped and let go; no Animation left in the world)
 local all={}
 for i=1,6 do
  local r=avatars:Build(1100+i);avatars:Place(r,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,r);avatars:Animate(r,1100+i)
  H.run(1.2);for _,t in ipairs(tracksOf(r))do all[#all+1]=t end
 end
 local live,kept=0,0;for _,t in ipairs(all)do if t.IsPlaying then live+=1 end;if not t.Destroyed then kept+=1 end end
 check(#all==6 and live==1 and kept==1 and danceTrack(pullD)==all[6],'six champions in a row: one track each, only the last one playing or kept')
 local strays=0;for _,x in ipairs(W.workspace:GetDescendants())do if x._class=='Animation'then strays+=1 end end
 check(strays==0,'no Animation is left in the world (the client\'s are never parented)')
 -- a fallback (blocky) avatar and the silhouette: static, nothing loaded, no joints
 loads=HH.avatars.Dance.Loads
 local stand=avatars:Fallback(false);avatars:Place(stand,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,stand);avatars:Animate(stand)
 local ok=pcall(function()H.run(2)end)
 check(ok and HH.avatars.Dance.Loads==loads and lastReport('Pull').Mode=='static','a blocky stand-in avatar is left alone: static, nothing loaded')
 local sil=avatars:Build(0,{Silhouette=true});avatars:Place(sil,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,sil);avatars:Animate(sil)
 local okS=pcall(function()H.run(2)end)
 check(okS and HH.avatars.Dance.Loads==loads and sil:GetAttribute('AvatarMode')=='static'and lastReport('Pull').Mode=='static','the silhouette too')
 Art.SetAvatar(pullD,nil);local ok2=pcall(function()H.run(2)end)
 check(ok2,'no avatar at all')
 Art.SetItem(pullD,nil);local ok3=pcall(function()H.run(2)end)
 check(ok3,'no item at all (a slot cleared)')
 Art.SetItem(pullD,Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat='None'}))
 -- streaming out: the model leaves the world
 local dancer=avatars:Build(1201);avatars:Place(dancer,pullD.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn);Art.SetAvatar(pullD,dancer);avatars:Animate(dancer,1201);H.run(1.2)
 local before=danceTrack(pullD)
 local m=pullD.Model;m.Parent=nil;CS:RemoveTag(m,Rules.Tag)
 local ok4=pcall(function()H.run(2)end)
 check(ok4 and not sparksOf(pullD)and before.Destroyed and not before.IsPlaying,'a display that streams out is forgotten (its sparkles and its dance track with it, no error)')
 m.Parent=map;CS:AddTag(m,Rules.Tag)
 H.run(1.5)
 check(sparksOf(pullD)~=nil and danceTrack(pullD)~=before and danceTrack(pullD).IsPlaying and playingOf(dancer)==1,'and a streamed-back copy starts clean (a new track dances)')
 -- destroyed outright
 local d3=dressed('Fruit');H.run(1.2)
 local t3=danceTrack(d3)
 d3.Model:Destroy();local ok5=pcall(function()H.run(2)end)
 check(ok5 and t3 and t3.Destroyed,'a destroyed display is dropped without an error (its track let go)')
 camera(V3(0,0,-600));H.run(1.5)
 check(H.renderConnections()==0,'nothing stays connected when nothing is near')
 -- the whole run left no stray parts behind
 local strays=H.named('HubPopRing')+H.named('HubPopSparks')
 check(strays==0,'no pop parts are left in the workspace')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
