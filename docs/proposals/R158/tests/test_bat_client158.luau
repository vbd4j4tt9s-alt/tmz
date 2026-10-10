--!nocheck
-- R158 bats, BUILT: the swinger's client on the Roblox mock with the REAL scripts / modules of this checkout: BatClient, BatSwingPose, BatHitbox,
-- HitBurstFx, KeeperHitEffects, SeedCarryPose (LocalSfx is a recorder; the Animator is played by the test: every joint gets its animation pose before
-- PreSimulation, the hips a running swing).
--  1. the click: the request {Kind=Swing, Start, Id} goes at once, the pose starts at once (no server echo needed), the whoosh is timed from the click
--     (meets contact), the local cooldown; the server's echo of your own swing changes nothing; another player's swing plays from its packet (Lead).
--  2. the sweep: a player crossing in front is claimed once with {Kind=Hit, Id, Victim, ViewTime inside the strike, Own, Look}; nobody in reach, a
--     ForceField, a knocked-down player, a player behind the base line, a swinger in the hub: no claim.
--  3. your hit at once: the slap (once), the pooled star, the sparks, HitBurstFx.IsOwnHit; the 0.05 s hit-stop (the pose holds, then runs 0.05 s late);
--     NO camera shake for you, also when the server's packet arrives (KeeperHitEffects skips it: no second slap); the victim and bystanders keep theirs.
--  4. the trail: white, made once per bat on its barrel, on only from .21 to .40 s of the swing (cleared first), off in Fast Mode and far away.
--  5. nothing per frame: no instance is made during a swing's frames (the trail, the star pool and the spark emitter are made once).
--  6. upper body only: R15 writes Waist + right arm + left arm, R6 its RootJoint + both shoulders; legs / root / neck keep the Animator's pose.
--  7. carrying a pack: the bat writes the right arm only (the waist's turn folded into it: the arm points the same way as without the pack), the carry
--     pose writes the left arm only, and the result is the same in either order of the two PreSimulation handlers.
--  8. no "SMACK!" word anywhere on screen.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new;local typeof=R.typeof
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(e or 1e-6)end
local RS=W.RS;local Run=W.Run;Run.PreAnimation=R.signal()
W.env.bit32=bit32
-- recorders ----------------------------------------------------------------------------------------------------------------------------------------
local sfx={Log={},WhooshId='rbxassetid://9120768742'}
function sfx.Play(id,pos,vol,pitch,life,skip)sfx.Log[#sfx.Log+1]={Id=id,Pos=pos,Vol=vol,Pitch=pitch,Skip=skip,At=R.clock};return true end
function sfx.Preload()end
function sfx.count(id)local n=0;for _,e in ipairs(sfx.Log)do if not id or e.Id==id then n+=1 end end;return n end
W.stub('LocalSfx',sfx)
local emits,clears=0,0
R.Inst.Emit=function(self,n)if self.Parent and self.Parent.Name=='BatHitSparks'then emits+=(n or 1)end end -- (the bat's sparks only)
R.Inst.Clear=function(self)clears+=1 end
E.player('Hitter')
local player,char,root,hum=E.Player,E.char,E.root,E.hum
local Players=W.service('Players')
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local batRemote=R.Instance.new('RemoteEvent');batRemote.Name='BatSwing';batRemote.Parent=remotes
local sent={};function batRemote.FireServer(_,p)sent[#sent+1]=p end
local hitRemote=R.Instance.new('RemoteEvent');hitRemote.Name='KeeperHit';hitRemote.Parent=remotes
local C=W.module('BatConfig');local Pose=W.module('BatSwingPose');local Burst=W.module('HitBurstFx');local Carry=W.module('SeedCarryPose')
local motion=RS:FindFirstChild('RunnerMotion');motion:SetAttribute('TrackBoundaryZ',-100);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114)
-- rigs -----------------------------------------------------------------------------------------------------------------------------------------------
local function part(c,name,size)local p=R.new('Part');p.Name=name;p.Size=size or V3(1,1,1);p.Parent=c;return p end
local function motor(name,p0,p1,c0,c1)local m=R.new('Motor6D');m.Name=name;m.Part0=p0;m.Part1=p1;m.C0=c0;m.C1=c1;m.Transform=CF(0,0,0);m.Parent=p1;return m end
local function rigR15(c,rootPart)
 local lt,ut=part(c,'LowerTorso',V3(2,.5,1)),part(c,'UpperTorso',V3(2,1.6,1))
 local rua,rla,rh=part(c,'RightUpperArm',V3(1,1.2,1)),part(c,'RightLowerArm',V3(1,1.1,1)),part(c,'RightHand',V3(1,.3,1))
 local lua,lla,lh=part(c,'LeftUpperArm',V3(1,1.2,1)),part(c,'LeftLowerArm',V3(1,1.1,1)),part(c,'LeftHand',V3(1,.3,1))
 local rul,lul,head=part(c,'RightUpperLeg',V3(1,1.2,1)),part(c,'LeftUpperLeg',V3(1,1.2,1)),part(c,'Head',V3(1.2,1.2,1.2))
 motor('Root',rootPart,lt,CF(0,-.2,0),CF(0,-.2,0));motor('Waist',lt,ut,CF(0,.4,0),CF(0,-.6,0))
 motor('RightShoulder',ut,rua,CF(1,.56,0),CF(-.5,.4,0));motor('RightElbow',rua,rla,CF(0,-.33,0),CF(0,.26,0));motor('RightWrist',rla,rh,CF(0,-.5,0),CF(0,.12,0))
 motor('LeftShoulder',ut,lua,CF(-1,.56,0),CF(.5,.4,0));motor('LeftElbow',lua,lla,CF(0,-.33,0),CF(0,.26,0));motor('LeftWrist',lla,lh,CF(0,-.5,0),CF(0,.12,0))
 motor('RightHip',lt,rul,CF(.5,-.2,0),CF(0,.5,0));motor('LeftHip',lt,lul,CF(-.5,-.2,0),CF(0,.5,0));motor('Neck',ut,head,CF(0,.8,0),CF(0,-.5,0))
 return rh
end
local function rigR6(c,rootPart)
 local torso=part(c,'Torso',V3(2,2,1));local ra,la=part(c,'Right Arm',V3(1,2,1)),part(c,'Left Arm',V3(1,2,1))
 local rl,ll,head=part(c,'Right Leg',V3(1,2,1)),part(c,'Left Leg',V3(1,2,1)),part(c,'Head',V3(2,1,1))
 local turn=R.CFrame.Angles(-math.pi/2,0,math.pi)
 motor('RootJoint',rootPart,torso,turn,turn);motor('Right Shoulder',torso,ra,CF(1,.5,0)*R.CFrame.Angles(0,math.pi/2,0),CF(-.5,.5,0)*R.CFrame.Angles(0,math.pi/2,0))
 motor('Left Shoulder',torso,la,CF(-1,.5,0)*R.CFrame.Angles(0,-math.pi/2,0),CF(.5,.5,0)*R.CFrame.Angles(0,-math.pi/2,0))
 motor('Right Hip',torso,rl,CF(1,-1,0)*R.CFrame.Angles(0,math.pi/2,0),CF(.5,1,0)*R.CFrame.Angles(0,math.pi/2,0));motor('Left Hip',torso,ll,CF(-1,-1,0),CF(-.5,1,0))
 motor('Neck',torso,head,CF(0,1,0),CF(0,-.5,0))
 return ra
end
local function equip(c,hand)
 local bat=F.bat(W,c);bat.Activated=R.signal();bat.Enabled=true
 local grip=R.new('Weld');grip.Name='RightGrip';grip.Part0=hand;grip.Part1=bat.Handle;grip.C0=CF(0,-.15,0);grip.C1=CF(0,0,0);grip.Parent=hand
 return bat
end
local hand=rigR15(char,root)
hum.RigType=R.Enum.HumanoidRigType.R15
root.CFrame=R.CFrame.lookAt(V3(0,3,0),V3(0,3,1))
local bat=equip(char,hand)
-- another player (what YOUR screen shows of it is where the test puts its root)
local function other(name,id,x,z,r6)
 local p=R.new('Player');p.Name=name;p.UserId=id;p.CharacterAdded=R.signal();p.CharacterRemoving=R.signal();p.Parent=Players
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace;p.Character=c
 local r=R.new('Part');r.Name='HumanoidRootPart';r.CFrame=CF(x,3,z);r.Parent=c
 local h=R.new('Humanoid');h.Health=100;h.RigType=r6 and R.Enum.HumanoidRigType.R6 or R.Enum.HumanoidRigType.R15;h.Parent=c
 if Players.PlayerAdded then Players.PlayerAdded:Fire(p)end
 return p,c,r,h
end
local V,vChar,vRoot=other('Victim',2,200,7)
local camera=W.workspace.CurrentCamera;camera.CFrame=CF(0,8,-14)
-- the frame: render steps, PreAnimation, the Animator (every joint: its animation pose; hips: running), PreSimulation, Heartbeat
local animTime=0
local function animate(c)
 for _,m in ipairs(c:GetDescendants())do if m:IsA('Motor6D')then
  local n=m.Name:gsub(' ','')
  if n=='RightHip'or n=='LeftHip'then m.Transform=R.CFrame.Angles(math.sin(animTime*12)*.6,0,0)else m.Transform=CF(0,0,0)end
 end end
end
local animated={char}
local function frame(dt)
 dt=dt or 1/60;animTime+=dt
 R.advance(dt)
 Run.RenderStepped:Fire(dt)
 local list=table.clone(W.rsOrder);table.sort(list,function(a,b)return W.rsBound[a].Prio<W.rsBound[b].Prio end)
 for _,n in ipairs(list)do local b=W.rsBound[n];if b then b.Fn(dt)end end
 Run.PreAnimation:Fire(dt)
 for _,c in ipairs(animated)do animate(c)end
 Run.PreSimulation:Fire(dt);Run.Heartbeat:Fire(dt)
end
local function frames(n)for _=1,n do frame()end end
local function motorOf(c,n)for _,m in ipairs(c:GetDescendants())do if m:IsA('Motor6D')and m.Name:gsub(' ','')==n then return m end end end
local function same(a,b)local d=(a.Position-b.Position).Magnitude;for i=1,3 do for j=1,3 do d+=math.abs(a.R[i][j]-b.R[i][j])end end;return d<1e-9 end
local function isIdentity(cf)local r=cf.R;return cf.Position.Magnitude<1e-9 and math.abs(r[1][1]-1)<1e-9 and math.abs(r[2][2]-1)<1e-9 and math.abs(r[3][3]-1)<1e-9 end
local sc=R.new('LocalScript');sc.Name='BatClient';local ok,err=pcall(W.load,'BatClient',sc);check(ok,'BatClient loads: '..tostring(err))
local kh=R.new('LocalScript');kh.Name='KeeperHitEffects';local ok2,err2=pcall(W.load,'KeeperHitEffects',kh);check(ok2,'KeeperHitEffects loads: '..tostring(err2))
frames(5);R.advance(4)
-- 1. the click -------------------------------------------------------------------------------------------------------------------------------------
local t0=W.workspace:GetServerTimeNow()
bat.Activated:Fire()
local req=sent[#sent]
check(req and req.Kind=='Swing'and near(req.Start,t0)and req.Id==1,'the click sends {Kind=Swing, Start = now, Id = 1} at once (no wait)')
check(char:GetAttribute('BatSwingArm')==true,'the swing owns the right arm from the click (BatSwingArm, for the carry pose)')
frames(3)
local rs=motorOf(char,'RightShoulder')
check(not isIdentity(rs.Transform),'your swing is moving 0.05 s after the click (no server echo needed)')
local whooshAt
for _=1,28 do frame();if not whooshAt and sfx.count(sfx.WhooshId)>0 then whooshAt=R.clock-t0 end end
check(whooshAt and near(whooshAt,C.Windup-C.SwingSoundLead,.02),'the whoosh is timed from the click: '..tostring(whooshAt)..' s (contact - lead '..(C.Windup-C.SwingSoundLead)..')')
check(sfx.count(sfx.WhooshId)==1,'... once')
local nSent=#sent;bat.Activated:Fire()
check(#sent==nSent,'a click within the 1.0 s cooldown sends nothing')
-- the server's echo of your own swing: nothing restarts
do
 local before=rs.Transform
 batRemote.OnClientEvent:Fire({Kind='Swing',Character=char,At=t0+.05,Serial=1,Id=1});frame()
 local p=sfx.count(sfx.WhooshId)
 check(p==1,'the echo of your own swing plays no second whoosh')
end
frames(60)
check(isIdentity(motorOf(char,'RightShoulder').Transform)and char:GetAttribute('BatSwingArm')==nil,'the swing ends: the arm is the Animator\'s again, BatSwingArm cleared')
-- 2. the sweep and 3. your hit at once ----------------------------------------------------------------------------------------------------------------
R.advance(2);frames(2)
sfx.Log={};table.clear(sent)
local camBefore=camera.CFrame
local createdBefore=#R.created
local speed=141;local start=W.workspace:GetServerTimeNow()
local function placeVictim(t)vRoot.CFrame=CF(-40+speed*(t-start)-speed*.30+40,3,7)end -- at x = 0 (straight in front, 7 studs) at start + .30
placeVictim(start)
bat.Activated:Fire()
local claimed,claimFrame,starShown,endHit
local transforms={}
for i=1,70 do
 placeVictim(W.workspace:GetServerTimeNow()+1/60)
 frame()
 transforms[i]={At=W.workspace:GetServerTimeNow(),T=motorOf(char,'RightShoulder').Transform}
 if not endHit and char:GetAttribute('BatSwingArm')==nil then endHit=W.workspace:GetServerTimeNow()-start end
 if not claimed then for _,p in ipairs(sent)do if p.Kind=='Hit'then claimed=p;claimFrame=i
  local star=W.workspace:FindFirstChild('KeeperHitBurst');starShown=star~=nil and star.ContactStar.Enabled==true end end end
end
check(claimed~=nil,'a player crossing 7 studs in front at 141 studs/s is claimed')
if claimed then
 check(claimed.Id==2 and claimed.Victim==V and typeof(claimed.Own)=='Vector3'and typeof(claimed.Look)=='Vector3','the claim: {Kind=Hit, Id, Victim, Own, Look}')
 check(claimed.ViewTime>=start+C.HitFrom-1/60 and claimed.ViewTime<=start+C.HitTo+1/60,'the claim\'s moment is inside the strike: +'..string.format('%.3f',claimed.ViewTime-start)..' s')
 check(near(claimed.Own.X,0,.01)and near(claimed.Own.Z,0,.01)and near(claimed.Look.Z,1,1e-3),'your spot and facing at that moment')
 local n=0;for _,p in ipairs(sent)do if p.Kind=='Hit'then n+=1 end end
 check(n==1,'one claim per swing ('..n..')')
 check(sfx.count(C.SlapSoundId)==1,'the slap plays at once on your screen (once)')
 check(Burst.IsOwnHit(V.UserId),'your hit is noted (HitBurstFx.IsOwnHit)')
 check(starShown,'the star burst shows at once, in the claim\'s frame (pooled)')
 check(emits==Burst.SparkCount,'the sparks: one Emit of '..Burst.SparkCount..' from the shared emitter ('..emits..')')
 -- the hit-stop: the pose holds for HitStop, then runs HitStop late
 local held=0
 for i=claimFrame+1,#transforms do
  if same(transforms[i].T,transforms[claimFrame].T)then held+=1 end
 end
 check(held>=2 and held<=4,'the hit-stop: your swing holds '..held..' frames (0.05 s at 60 fps)')
 -- the server's packet for that hit arrives a ping later: skipped on your screen (no second slap, no star, no camera shake)
 local slaps=sfx.count(C.SlapSoundId)
 hitRemote.OnClientEvent:Fire({Id=1,At=W.workspace:GetServerTimeNow(),Position=vRoot.Position,VictimUserId=V.UserId,Direction=V3(1,0,0),Cause='Bat'})
 frames(20)
 check(sfx.count(C.SlapSoundId)==slaps,'the server\'s packet of your own hit: no second slap')
 check((camera.CFrame.Position-camBefore.Position).Magnitude<1e-9,'NO camera shake for the hitter (the owner\'s choice), at the hit nor at the server\'s packet')
end
frames(40)
-- 5. nothing per frame: the swing above made only the one-time pieces (the trail + its 2 attachments, the first star and the spark emitter)
do
 local made={};for i=createdBefore+1,#R.created do local o=R.created[i];made[o._class]=(made[o._class]or 0)+1 end
 local list={};for k,v in pairs(made)do list[#list+1]=k..' '..v end;table.sort(list)
 check((made.Trail or 0)<=1 and(made.Attachment or 0)<=3 and(made.Frame or 0)<=8 and(made.Part or 0)<=2,'a whole swing with a hit made only the one-time pieces ('..table.concat(list,', ')..')')
 R.advance(2);frames(2)
 local mark=#R.created
 start=W.workspace:GetServerTimeNow();placeVictim(start);bat.Activated:Fire()
 for _=1,70 do placeVictim(W.workspace:GetServerTimeNow()+1/60);frame()end
 local extra={};for i=mark+1,#R.created do local o=R.created[i];if o._class~='Sound'then extra[#extra+1]=o._class..':'..tostring(o.Name)end end
 check(#extra==0,'the next swing with a hit makes no instance at all (pooled; '..table.concat(extra,', ')..')')
end
-- 4. the trail ---------------------------------------------------------------------------------------------------------------------------------------
do
 local trail=bat.Handle:FindFirstChild('BatSwingTrail')
 check(trail and trail.Attachment0 and trail.Attachment1 and trail.Attachment0.Parent==bat.Handle,'the trail: one Trail between two Attachments on the bat')
 local c=trail and trail.Color and trail.Color.A
 check(c and c.R==1 and c.G==1 and c.B==1,'the trail is white')
 check(trail and near(trail.Attachment1.Position.Y,(2.55+1.25)*.95,.05)and trail.Attachment1.Position.Y>trail.Attachment0.Position.Y,'... from half way up the barrel to near the tip ('..tostring(trail and trail.Attachment1.Position)..')')
 R.advance(2);frames(2)
 vRoot.CFrame=CF(300,3,7)
 local s0=W.workspace:GetServerTimeNow();bat.Activated:Fire();local onFrom,onTo,clears0,endMiss=nil,nil,clears,nil
 for _=1,60 do frame();local t=W.workspace:GetServerTimeNow()-s0;if trail.Enabled then onFrom=onFrom or t;onTo=t end;if not endMiss and char:GetAttribute('BatSwingArm')==nil then endMiss=t end end
 check(endMiss and endHit and endMiss>=Pose.Total-1e-6 and endMiss<Pose.Total+1/60+1e-6 and math.abs(endHit-endMiss-C.HitStop)<=1/60+1e-6,
  string.format('the hit-stop: a swing that hits ends %.3f s later than a miss (%.3f vs %.3f; HitStop %.2f, the server\'s timing does not move)',(endHit or 0)-(endMiss or 0),endHit or-1,endMiss or-1,C.HitStop))
 check(onFrom and onFrom>=C.TrailFrom-1e-6 and onFrom<C.TrailFrom+1/60+1e-6 and onTo<C.TrailTo+1e-6 and onTo>=C.TrailTo-1/60-1e-6,
  string.format('the trail is on only from %.2f to %.2f s of the swing (seen %.3f .. %.3f)',C.TrailFrom,C.TrailTo,onFrom or-1,onTo or-1))
 check(clears==clears0+1,'it is cleared once as it comes on (no old streak)')
 check(#bat.Handle:GetChildren()==3,'still one trail (and its two attachments) on the bat after several swings: made once ('..#bat.Handle:GetChildren()..')')
 -- a miss: no claim, the whoosh still plays
 check(sent[#sent].Kind=='Swing','a swing with nobody in reach claims nothing (a miss)')
 player:SetAttribute('FastMode',true);R.advance(2);frames(2)
 local s1=W.workspace:GetServerTimeNow();bat.Activated:Fire();local seen=false
 for _=1,60 do frame();if trail.Enabled then seen=true end end
 check(not seen,'Fast Mode: no trail')
 emits=0;R.advance(2);frames(2);start=W.workspace:GetServerTimeNow();placeVictim(start);bat.Activated:Fire()
 for _=1,60 do placeVictim(W.workspace:GetServerTimeNow()+1/60);frame()end
 check(emits==0 and sent[#sent].Kind=='Hit','Fast Mode: the hit still counts but no sparks')
 player:SetAttribute('FastMode',nil)
end
-- 2b. no claim: a ForceField, a knocked-down player, a player behind the base line, a swinger in the hub
local function tryHit(setup,undo,msg)
 R.advance(2);frames(2);setup()
 local n=#sent;start=W.workspace:GetServerTimeNow();placeVictim(start);bat.Activated:Fire()
 for _=1,40 do placeVictim(W.workspace:GetServerTimeNow()+1/60);frame()end
 local claims=0;for i=n+1,#sent do if sent[i].Kind=='Hit'then claims+=1 end end
 check(claims==0,msg..': no claim');undo();frames(30)
end
tryHit(function()R.new('ForceField').Parent=vChar end,function()vChar:FindFirstChildOfClass('ForceField'):Destroy()end,'the victim has a ForceField')
tryHit(function()vChar:SetAttribute('ChestChaseRagdollActive',true)end,function()vChar:SetAttribute('ChestChaseRagdollActive',nil)end,'the victim is knocked down')
tryHit(function()V:SetAttribute('GuardianFlingActive',true)end,function()V:SetAttribute('GuardianFlingActive',nil)end,'the victim was just thrown')
tryHit(function()motion:SetAttribute('TrackBoundaryZ',5)end,function()motion:SetAttribute('TrackBoundaryZ',-100)end,'both behind the base line (the hub)')
-- 1b. another player's swing plays from its packet (late, Lead) with the whoosh timed to its contact
do
 local O,oChar,oRoot=other('Other',3,6,-6);table.insert(animated,oChar)
 local oHand=rigR15(oChar,oRoot);oChar.Humanoid.RigType=R.Enum.HumanoidRigType.R15;equip(oChar,oHand)
 R.advance(2);frames(2);sfx.Log={}
 batRemote.OnClientEvent:Fire({Kind='Swing',Character=oChar,At=W.workspace:GetServerTimeNow()-.1,Serial=9,Id=1})
 frame()
 check(not isIdentity(motorOf(oChar,'RightShoulder').Transform),'another player\'s swing plays from the server\'s packet (Id 1 is ITS number, not yours)')
 check(oChar:GetAttribute('BatSwingArm')==true,'... and owns its right arm for the carry pose')
 frames(10);check(sfx.count(sfx.WhooshId)==1,'... with its whoosh timed to its contact')
 frames(60)
end
-- 6. upper body only (R15 here; R6 below) ------------------------------------------------------------------------------------------------------------
local function written(c,from,to)
 -- which joints the swing changed away from the Animator's pose during [from, to] s of a swing
 local changed={}
 R.advance(2);frames(2);vRoot.CFrame=CF(300,3,7)
 local s0=W.workspace:GetServerTimeNow();bat.Activated:Fire()
 for _=1,55 do
  frame();local t=W.workspace:GetServerTimeNow()-s0
  if t>=from and t<=to then for _,m in ipairs(c:GetDescendants())do if m:IsA('Motor6D')then
   local n=m.Name:gsub(' ','')
   local anim=(n=='RightHip'or n=='LeftHip')and R.CFrame.Angles(math.sin(animTime*12)*.6,0,0)or CF(0,0,0)
   local d=m.Transform;local a=anim
   local diff=(d.Position-a.Position).Magnitude;for i=1,3 do for j=1,3 do diff+=math.abs(d.R[i][j]-a.R[i][j])end end
   if diff>1e-6 then changed[n]=true end
  end end end
 end
 local list={};for k in pairs(changed)do list[#list+1]=k end;table.sort(list);return table.concat(list,',')
end
check(written(char,.05,.8)=='LeftElbow,LeftShoulder,RightElbow,RightShoulder,RightWrist,Waist','R15: the swing writes the waist, the right arm and the left arm only; legs, root and neck keep the Animator\'s pose ('..written(char,.05,.8)..')')
-- 7. carrying a pack -----------------------------------------------------------------------------------------------------------------------------------
do
 local bag=R.new('Model');bag.Name='CarriedSeed';bag:SetAttribute('SeedPackCarry',true);bag:SetAttribute('CarryRootOffset',CF(0,0,-1.6))
 local body=R.new('Part');body.Name='Body';body.CFrame=root.CFrame*CF(0,0,-1.6);body.Parent=bag;bag.PrimaryPart=body
 local lg=R.new('Attachment');lg.Name='LeftGrip';lg.CFrame=CF(-.7,0,0);lg.Parent=body;local rg=R.new('Attachment');rg.Name='RightGrip';rg.CFrame=CF(.7,0,0);rg.Parent=body
 bag.Parent=char
 check(written(char,.05,.8)=='RightElbow,RightShoulder,RightWrist','carrying: the bat writes the right arm only (the left hand stays on the pack, the waist with the Animator) ('..written(char,.05,.8)..')')
 -- the fold: at contact the right arm points where it would with the waist turned
 local function chain(c)
  local lt=motorOf(c,'Waist');local sh=motorOf(c,'RightShoulder')
  return (lt.C0*lt.Transform*lt.C1:Inverse()*sh.C0*sh.Transform).R
 end
 local function at(t,carry)
  bag.Parent=carry and char or nil
  R.advance(2);frames(2);local s0=W.workspace:GetServerTimeNow();bat.Activated:Fire()
  while W.workspace:GetServerTimeNow()-s0<t do frame()end
  return chain(char)
 end
 local a,b=at(.52,false),at(.52,true)
 local diff=0;for i=1,3 do for j=1,3 do diff+=math.abs(a[i][j]-b[i][j])end end
 check(diff<1e-6,'carrying: the waist\'s turn is folded into the right arm (the arm points the same way as without the pack: '..string.format('%.2g',diff)..')')
 frames(40);bag.Parent=char
 -- the order of the two PreSimulation handlers does not matter: run the bat then the carry pose, and the carry pose then the bat
 local pose=Carry.new(char)
 local function both(carryFirst)
  R.advance(2);frames(2);animTime=0;local s0=W.workspace:GetServerTimeNow();bat.Activated:Fire()
  local out
  for _=1,24 do
   R.advance(1/60);animTime+=1/60
   Run.PreAnimation:Fire();pose:Reset();animate(char)
   if carryFirst then pose:Apply(bag,W.workspace:GetServerTimeNow());Run.PreSimulation:Fire()else Run.PreSimulation:Fire();pose:Apply(bag,W.workspace:GetServerTimeNow())end
  end
  out={};for _,m in ipairs(char:GetDescendants())do if m:IsA('Motor6D')then out[m.Name]=m.Transform end end
  for _=1,40 do R.advance(1/60);Run.PreAnimation:Fire();pose:Reset();animate(char);Run.PreSimulation:Fire()end
  return out
 end
 local x,y=both(false),both(true)
 local worst,leftMoved=0,false
 for n,cf in pairs(x)do local d=(cf.Position-y[n].Position).Magnitude;for i=1,3 do for j=1,3 do d+=math.abs(cf.R[i][j]-y[n].R[i][j])end end;worst=math.max(worst,d)end
 check(worst<1e-9,'carrying: the same pose whichever of the bat / the carry pose runs first in PreSimulation (worst difference '..string.format('%.2g',worst)..')')
 check(not isIdentity(x.LeftShoulder)and not isIdentity(x.RightShoulder),'... the carry pose holds the pack with the left arm, the bat swings the right')
 bag:Destroy();frames(10)
end
-- 6b. R6 -------------------------------------------------------------------------------------------------------------------------------------------------
do
 local O6,c6,r6=other('Six',4,10,-30,true);table.insert(animated,c6);local h6=rigR6(c6,r6);local b6=equip(c6,h6)
 R.advance(2);frames(2)
 local s0=W.workspace:GetServerTimeNow()
 batRemote.OnClientEvent:Fire({Kind='Swing',Character=c6,At=s0,Serial=11,Id=4})
 local changed={}
 for _=1,50 do frame();for _,m in ipairs(c6:GetDescendants())do if m:IsA('Motor6D')then
  local n=m.Name:gsub(' ','');local hip=n=='RightHip'or n=='LeftHip'
  if not hip and not isIdentity(m.Transform)then changed[n]=true end
 end end end
 local list={};for k in pairs(changed)do list[#list+1]=k end;table.sort(list)
 check(table.concat(list,',')=='LeftShoulder,RightShoulder,RootJoint','R6: the swing writes its RootJoint and both shoulders only ('..table.concat(list,',')..')')
end
-- 8. no SMACK word on screen --------------------------------------------------------------------------------------------------------------------------
do
 local smack=0
 for _,o in ipairs(R.created)do local t=rawget(o,'_props')and o._props.Text;if type(t)=='string'and t:upper():find('SMACK')then smack+=1 end end
 check(smack==0,'no "SMACK!" word was put on screen ('..smack..')')
end
-- the victim and the bystanders keep their shake (KeeperHitEffects, unchanged for them)
do
 R.advance(3);frames(5)
 local base=camera.CFrame
 hitRemote.OnClientEvent:Fire({Id=50,At=W.workspace:GetServerTimeNow(),Position=root.Position,VictimUserId=player.UserId,Direction=V3(1,0,0),Cause='Bat'})
 local moved=false;for _=1,6 do frame();if (camera.CFrame.Position-base.Position).Magnitude>1e-6 then moved=true end end
 check(moved,'the one who is hit still gets its camera shake')
 frames(30);R.advance(3);frames(2);base=camera.CFrame
 hitRemote.OnClientEvent:Fire({Id=51,At=W.workspace:GetServerTimeNow(),Position=V3(4,3,4),VictimUserId=777,Direction=V3(1,0,0),Cause='Bat'})
 moved=false;for _=1,6 do frame();if (camera.CFrame.Position-base.Position).Magnitude>1e-6 then moved=true end end
 check(moved,'a player near someone else\'s bat hit still gets the small shake')
end
sc.Destroying:Fire();kh.Destroying:Fire()
print(string.format('bat client: %d checks, %d failed',checks,fails))
if fails>0 then error('bat client test failed')end
