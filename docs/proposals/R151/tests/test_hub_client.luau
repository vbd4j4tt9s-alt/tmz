--!nocheck
-- R151 hub displays: the REAL HubDisplayClient as the local player, on the displays the REAL HubDisplayArt builds (with a giant item and an avatar rig):
--  1. the countdown on the sign: right at once, kept up to date, "New fruit in ..." for the fruit board, for a display that streams in later, nothing without its attributes;
--  2. motion only when near (110 studs in, 140 out) and allowed: the item turns about its own vertical axis (never moves, never changes height), sparkles in the champion's
--     colour, the avatar cheers (joint transforms, bounded), the per-frame function is connected only while a display is near, parts are written at most ~20 times a second
--     in one bulk move, and everything is put back when you walk away;
--  3. reduced motion and the lowest quality: no motion, no sparkles, no pop; the countdown still runs;
--  4. a new champion (the server bumps Rev): a ring and sparks pop around the item, the avatar celebrates (both arms up) and calms down; not on the first look, not from afar,
--     not with reduced motion;
--  5. the celebration sound for a remote from the server, and only for a well-formed one;
--  6. robustness: the server swapping the item or the avatar, a display streaming out and back, a display with nothing in it, a destroyed model.
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
local avatars=Avatar.new({Players=W.service('Players'),Clock=HH.clock().now})
local function dressed(kind,state)
 local d=Art.BuildFrame(map,kind,Rules.Layout,4)
 local item=Art.BuildItem(d,kind=='Pull'and{Kind='Seed',Id='FirePepperSeed',Coat='None'}or{Kind='Fruit',Id='SunflowerSeed',Coat='None'})
 Art.SetItem(d,item)
 local rig=avatars:Build(1001)
 avatars:Place(rig,d.FeetAt,Rules.AvatarHeight,-.4)
 Art.SetAvatar(d,rig)
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
local pullD=dressed('Pull');local fruitD=dressed('Fruit')
local center=pullD.Model:GetAttribute('ItemCenter')
local function camera(offset)H.look(center+offset,center)end
camera(V3(0,0,-400)) -- far away
H.tier=3
-- load the client
local sc=R.new('LocalScript');sc.Name='HubDisplayClient';W.load('HubDisplayClient',sc)
H.run(1.2)
local function itemParts(d)local out={};for _,p in ipairs(d.ItemFolder:GetDescendants())do if p:IsA('BasePart')then out[#out+1]=p end end;return out end
local function homes(parts)local h={};for _,p in ipairs(parts)do h[p]=p.CFrame.Position end;return h end
local function moved(parts,home)local m=0;for _,p in ipairs(parts)do local q=p.CFrame.Position;if math.abs(q.X-home[p].X)+math.abs(q.Y-home[p].Y)+math.abs(q.Z-home[p].Z)>1e-4 then m+=1 end end;return m end
local function angle(cf)local r=cf.R;local tr=r[1][1]+r[2][2]+r[3][3];return math.acos(math.clamp((tr-1)/2,-1,1))end
local function joint(d,name)local rig=d.AvatarFolder:FindFirstChildOfClass('Model');return rig and Pose.Joint(rig,name)end
local pullParts=itemParts(pullD);local pullHome=homes(pullParts)

-- 1. The countdown -------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local label=pullD.Labels.Footer;local flabel=fruitD.Labels.Footer
 check(label.Text=='New board in 5h 12m','the sign\'s footer shows the countdown at once: "'..label.Text..'"')
 check(flabel.Text=='New fruit in 5h 12m','and the fruit board says "New fruit in ..."')
 H.run(60*5)
 check(label.Text=='New board in 5h 7m','five minutes later: "'..label.Text..'"')
 H.run(5*3600+4*60)
 check(label.Text:find('^New board in %d+m %d+s$')~=nil,'in the last hour it shows minutes and seconds: "'..label.Text..'"')
 pullD.Model:SetAttribute('NextAt',math.floor(R.clock+4000))
 check(label.Text=='New board in 1h 6m','a new NextAt is followed at once (the attribute is listened to): "'..label.Text..'"')
 -- a display without its attributes is left alone
 local lone=Art.BuildFrame(map,'Pull',{Target=V3(0,4,-265),Pull={Center=V3(100,4,-100)},Fruit={Center=V3(-100,4,-100)}},4)
 lone.Labels.Footer.Text='x'
 H.run(6)
 check(lone.Labels.Footer.Text=='x','a display with no NextAt is not touched')
 lone.Model:Destroy()
 H.run(1)
 -- a display that streams in later
 local late=Art.BuildFrame(map,'Fruit',{Target=V3(0,4,-265),Pull={Center=V3(100,4,-100)},Fruit={Center=V3(150,4,-150)}},4)
 late.Model:SetAttribute('FooterPrefix','New fruit in ');late.Model:SetAttribute('NextAt',math.floor(R.clock+90))
 check(late.Labels.Footer.Text=='New fruit in 1m 30s'or late.Labels.Footer.Text=='New fruit in 1m 29s','a display tagged after the client started is picked up, and its attributes followed at once ("'..late.Labels.Footer.Text..'")')
 late.Model:Destroy()
end

-- 2. Motion only when near -------------------------------------------------------------------------------------------------------------------------------------------------
do
 R.clock+=1
 camera(V3(0,0,-300))
 H.run(1.5)
 check(H.renderConnections()==0 or H.renderConnections()<=0,'far away (300 studs): no per-frame function is connected')
 check(moved(pullParts,pullHome)==0,'the item stands still')
 check(not pullD.Model:FindFirstChild('HubSparks'),'no sparkles')
 local rs=joint(pullD,'RightShoulder');check(angle(rs.Transform)==0,'the avatar is not posed by the client')
 camera(V3(-30,-8,-40)) -- a player walking up to it
 H.run(1.2)
 check(H.renderConnections()>=1,'near (about 50 studs): the per-frame function is connected')
 check(pullD.Model:FindFirstChild('HubSparks')and fruitD.Model:FindFirstChild('HubSparks')==nil,'sparkles around the item that is near (not the far display)')
 local e=pullD.Model.HubSparks:FindFirstChildOfClass('ParticleEmitter')
 check(e and e.Rate==14 and e.Color.A and math.abs(e.Color.A.R*255-230)<1,'at the full quality tier; in the champion\'s colour')
 local m1=moved(pullParts,pullHome)
 check(m1>=#pullParts*.9,'the item turns ('..m1..' of '..#pullParts..' parts have moved)')
 local axis=center
 local stable=true
 for _,p in ipairs(pullParts)do
  local q=p.CFrame.Position;local h=pullHome[p]
  local r1=math.sqrt((q.X-axis.X)^2+(q.Z-axis.Z)^2);local r0=math.sqrt((h.X-axis.X)^2+(h.Z-axis.Z)^2)
  if math.abs(r1-r0)>1e-3 or math.abs(q.Y-h.Y)>1e-3 then stable=false end
 end
 check(stable,'it turns about its own vertical axis: every part keeps its distance from the axis and its height')
 -- the speed: .45 rad/s
 local sample=pullParts[1];local before=sample.CFrame.Position;local a0=math.atan2(before.Z-axis.Z,before.X-axis.X)
 H.run(2)
 local after=sample.CFrame.Position;local a1=math.atan2(after.Z-axis.Z,after.X-axis.X)
 local d=(a1-a0)%(2*math.pi);if d>math.pi then d-=2*math.pi end
 check(math.abs(math.abs(d)-.9)<.12,'about 0.45 radians a second ('..string.format('%.2f',math.abs(d)/2)..')')
 -- the cheer
 local rs2=joint(pullD,'RightShoulder');local waist=joint(pullD,'Waist')
 check(angle(rs2.Transform)>0 and angle(rs2.Transform)<=Pose.MaxAngle and angle(waist.Transform)<=Pose.MaxAngle,'the avatar cheers: its joints get bounded transforms')
 local seen={};for step=1,60 do H.run(.1);seen[#seen+1]=angle(rs2.Transform)end
 local lo,hi=1e9,0;for _,a in ipairs(seen)do lo=math.min(lo,a);hi=math.max(hi,a)end
 check(hi-lo>.1 and hi<=Pose.MaxAngle,'and keeps moving (the arm waves between '..string.format('%.2f',lo)..' and '..string.format('%.2f',hi)..' rad)')
 local touched=true;local rig=pullD.AvatarFolder:FindFirstChildOfClass('Model')
 for _,d in ipairs(rig:GetDescendants())do if d:IsA('Motor6D')then local a=angle(d.Transform);local named=Pose.CheerAt(0,0)[d.Name];if a>1e-9 and not named then touched=false end end end
 check(touched,'only the cheer\'s own joints are written (the legs and wrists are never touched)')
 -- the cost: bulk moves at most ~20 a second
 bulk=0;H.run(2)
 check(bulk>=30 and bulk<=45,'the item is moved with one BulkMoveTo about 20 times a second ('..bulk..' in 2 s)')
 -- walking away puts everything back
 camera(V3(0,0,-300))
 H.run(1.5)
 check(H.renderConnections()==0,'walked away: the per-frame function is gone')
 check(moved(pullParts,pullHome)==0,'the item is back where the server put it')
 check(not pullD.Model:FindFirstChild('HubSparks'),'the sparkles are gone')
 check(angle(joint(pullD,'RightShoulder').Transform)==0 and angle(joint(pullD,'Waist').Transform)==0,'the avatar relaxes (its joints are reset)')
 -- hysteresis: 120 studs away it does not start, but once going it keeps going until 140
 camera(V3(0,0,-125));H.run(1.2)
 check(H.renderConnections()==0,'125 studs away: not near enough to start (110)')
 camera(V3(0,0,-100));H.run(1.2);check(H.renderConnections()>=1,'100 studs away: it starts')
 camera(V3(0,0,-130));H.run(1.2);check(H.renderConnections()>=1,'130 studs away: it keeps going (it stops past 140)')
 camera(V3(0,0,-150));H.run(1.2);check(H.renderConnections()==0,'150 studs away: it stops')
 -- the second display
 local fruitParts=itemParts(fruitD);local fh=homes(fruitParts)
 local fc=fruitD.Model:GetAttribute('ItemCenter')
 H.look(fc+V3(0,-8,-40),fc);H.run(1.2)
 check(moved(fruitParts,fh)>=#fruitParts*.9 and fruitD.Model:FindFirstChild('HubSparks')and not pullD.Model:FindFirstChild('HubSparks'),'the fruit display spins when you stand at it (and the other does not)')
 camera(V3(0,0,-300));H.run(1.5)
end

-- 3. Reduced motion and quality ---------------------------------------------------------------------------------------------------------------------------------------------
do
 Gui.ReducedMotionEnabled=true
 camera(V3(-30,-8,-40));H.run(1.5)
 check(H.renderConnections()==0 and moved(pullParts,pullHome)==0,'reduced motion: nothing is connected and nothing turns')
 check(not pullD.Model:FindFirstChild('HubSparks')and angle(joint(pullD,'RightShoulder').Transform)==0,'no sparkles, no cheer')
 pullD.Model:SetAttribute('NextAt',math.floor(R.clock+3600*2+60));H.run(6)
 check(pullD.Labels.Footer.Text:find('^New board in 2h')~=nil,'the countdown still runs ("'..pullD.Labels.Footer.Text..'")')
 local ringsBefore=H.named('HubPopRing')
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(1.2)
 check(H.named('HubPopRing')==ringsBefore,'a new champion pops nothing with reduced motion')
 Gui.ReducedMotionEnabled=false
 H.run(1.5)
 check(H.renderConnections()>=1,'switching it off brings the motion back')
 H.tier=1;H.run(1.5)
 check(H.renderConnections()==0 and not pullD.Model:FindFirstChild('HubSparks'),'the lowest quality tier: no motion, no sparkles')
 H.tier=2;H.run(1.5)
 check(H.renderConnections()>=1,'the middle tier moves')
 local e=pullD.Model:FindFirstChild('HubSparks')and pullD.Model.HubSparks:FindFirstChildOfClass('ParticleEmitter')
 check(e and e.Rate==7,'with half the sparkles')
 H.tier=3;camera(V3(0,0,-300));H.run(1.5)
end

-- 4. A new champion ---------------------------------------------------------------------------------------------------------------------------------------------------------
do
 camera(V3(-30,-8,-40));H.run(1.5)
 local before=H.named('HubPopRing')
 H.run(2)
 check(H.named('HubPopRing')==before,'standing there changes nothing by itself (no pop on the first look or while nothing changes)')
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1)
 H.run(.6)
 check(H.named('HubPopRing')==before+1 and H.named('HubPopSparks')>=1,'a new champion: a ring and a burst of sparks')
 local spark;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='HubPopSparks'then spark=c end end
 local em=spark and spark:FindFirstChildOfClass('Attachment')and spark:FindFirstChildOfClass('Attachment'):FindFirstChildOfClass('ParticleEmitter')
 check(em and em._emitted==36,'with 36 sparks (18 on the lower tiers)')
 local ring;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='HubPopRing'then ring=c end end
 check(ring and ring.Material==R.Enum.Material.Neon and near(ring.Color.R*255,230,1),'in the champion\'s colour')
 local ls=joint(pullD,'LeftShoulder')
 H.run(.5)
 check(angle(ls.Transform)>1,'the avatar throws both arms up ('..string.format('%.2f',angle(ls.Transform))..' rad)')
 H.run(2.5)
 check(angle(ls.Transform)<.2,'and calms down again')
 H.run(1)
 check(H.named('HubPopRing')==before,'the ring and the sparks clean themselves up')
 -- the champion is not announced by Rev when the display is empty
 pullD.Model:SetAttribute('State','Empty');local n=H.named('HubPopRing')
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(.6)
 check(H.named('HubPopRing')==n,'an empty board (a new day) does not pop')
 pullD.Model:SetAttribute('State','Champion')
 camera(V3(0,0,-300));H.run(1.5)
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(.6)
 check(H.named('HubPopRing')==n,'from 300 studs away nothing pops (nobody is looking)')
 camera(V3(0,0,-200));H.run(1.5)
 pullD.Model:SetAttribute('Rev',pullD.Model:GetAttribute('Rev')+1);H.run(.6)
 check(H.named('HubPopRing')==n+1,'from 200 studs (a landmark you can see) it does pop, once')
 H.run(2);camera(V3(0,0,-300));H.run(1.5)
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
 -- the server swaps the item (a new champion): the client takes up the new parts
 local item2=Art.BuildItem(pullD,{Kind='Seed',Id='AppleSeed',Coat='None'})
 Art.SetItem(pullD,item2)
 local newParts=itemParts(pullD);local nh=homes(newParts)
 H.run(1.5)
 check(moved(newParts,nh)>=#newParts*.9,'a new item is picked up and turns ('..#newParts..' parts)')
 -- the server swaps the avatar
 local rig=avatars:Build(1002);avatars:Place(rig,pullD.FeetAt,Rules.AvatarHeight,-.4);Art.SetAvatar(pullD,rig)
 H.run(1.5)
 check(angle(Pose.Joint(rig,'RightShoulder').Transform)>0,'a new avatar is posed')
 -- a fallback (blocky) avatar has no joints: nothing to pose, no error
 local stand=avatars:Fallback(false);avatars:Place(stand,pullD.FeetAt,Rules.AvatarHeight,-.4);Art.SetAvatar(pullD,stand)
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
 check(ok4 and not m:FindFirstChild('HubSparks'),'a display that streams out is forgotten (its sparkles with it, no error)')
 m.Parent=map;CS:AddTag(m,Rules.Tag)
 H.run(1.5)
 check(m:FindFirstChild('HubSparks')~=nil,'and a streamed-back copy starts clean')
 -- destroyed outright
 local d3=dressed('Fruit');H.run(1.2)
 d3.Model:Destroy();local ok5=pcall(function()H.run(2)end)
 check(ok5,'a destroyed display is dropped without an error')
 camera(V3(0,0,-300));H.run(1.5)
 check(H.renderConnections()==0,'nothing stays connected when nothing is near')
 -- the whole run left no stray parts behind
 local strays=H.named('HubPopRing')+H.named('HubPopSparks')
 check(strays==0,'no pop parts are left in the workspace')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
