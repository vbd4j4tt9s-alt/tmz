--!nocheck
-- R122 shovel holes under the Roblox mock. Real modules: TrackHoleService, TrackHoleConfig, SecurityGate,
-- ConcurrentKeeperService (Finish / _dropChestAfterCatch / _canTake), RagdollService (on a mock R6 rig),
-- MapService.IsInsideBiomeTrack and HarvestToolService. Only the legacy chase helpers that build art are stubbed.
-- Run from a folder holding roblox.luau, world.luau, rs_bundle.luau and srv_names.luau (see run.sh).
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end

-- Services ----------------------------------------------------------------------------------------------
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
function Players.GetPlayers()local out={};for _,c in ipairs(Players:GetChildren())do if c.ClassName=='Player'then out[#out+1]=c end end;return out end
function Players.GetPlayerFromCharacter(_,m)for _,p in ipairs(Players.GetPlayers())do if p.Character==m then return p end end;return nil end
W.service('Debris').AddItem=function()end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.RaycastParams={new=function()return {}end}
function W.workspace.Raycast()return nil end
local fired={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='Tool'then o.Equipped=R.signal();o.Unequipped=R.signal()end
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()
  o.FireAllClients=function(_,payload)fired[#fired+1]=payload end;o.FireClient=function()end end;return o end end
local function step(dt)R.advance(dt);Run.Heartbeat:Fire(dt);Run.PostSimulation:Fire(dt)end

-- Map: track is z>0, |x|<=114 (entrance line at z=0). Ground y=0. A rock top at y=3 around (22,200).
local mapRoot=R.new('Model');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local runtime=R.new('Folder');runtime.Name='Runtime';runtime.Parent=mapRoot
local lobby=R.new('Folder');lobby.Name='Lobby';lobby.Parent=mapRoot
local line=R.new('Part');line.Name='BaseBoundaryLine';line.Size=V3(100,1,2);line.CFrame=CF(0,0,0);line.Parent=lobby
local ground=R.new('Part');ground.Name='BiomeGround_1';ground.Size=V3(200,2,1400);ground.CFrame=CF(0,-1,700);ground.Parent=mapRoot
local lobbyFloor=R.new('Part');lobbyFloor.Name='LobbyFloor';lobbyFloor.Parent=lobby
local rock=R.new('Part');rock.Name='Rock';rock.Parent=mapRoot
local camp=R.new('Model');camp.Name='Keeper1';camp.Parent=mapRoot
local MapService=server('MapService')
local Map={MapRoot=mapRoot,RuntimeFolder=runtime,BaseBoundaryLine=line,Config={BiomeTrackStartZ=0,BiomeTrackEndZ=1445},
 Chests={},GuardiansByStage={[1]=camp},Refreshing=false,IsInsideBiomeTrack=MapService.IsInsideBiomeTrack}
local function inRock(x,z)return x>=20 and x<=24 and z>=198 and z<=204 end
local function raycast(_,origin,_,params)
 local x,z=origin.X,origin.Z
 if params.FilterType==R.Enum.RaycastFilterType.Include then
  if z>0 and math.abs(x)<=100 then return {Instance=ground,Position=V3(x,0,z),Normal=V3(0,1,0)}end
  return nil
 end
 if inRock(x,z)then return {Instance=rock,Position=V3(x,3,z),Normal=V3(0,1,0)}end
 if z>0 and math.abs(x)<=100 then return {Instance=ground,Position=V3(x,0,z),Normal=V3(0,1,0)}end
 if z<=0 then return {Instance=lobbyFloor,Position=V3(x,0,z),Normal=V3(0,1,0)}end
 return nil
end

-- Chase: real ConcurrentKeeperService over a minimal legacy base -----------------------------------------------
local notes={}
local Notes={Show=function(_,p,msg)notes[#notes+1]={P=p,Text=msg}end}
local function noted(p,text)for _,n in ipairs(notes)do if n.P==p and n.Text==text then return true end end;return false end
local flings=0
local Legacy={};Legacy.__index=Legacy
function Legacy:_clearRunEffects()end
function Legacy:_restorePhysicalSpeed(p,h)if self.Ragdoll and self.Ragdoll:IsActive(p)then return end;if h and h.Parent then h.WalkSpeed=16 end end -- mirrors ChaseService
function Legacy:_getGroundedDropPosition(run)return run.Character.HumanoidRootPart.Position end
function Legacy:_createDroppedChest(pos,_,_)
 local m=R.new('Model');local pp=R.new('Part');pp.CFrame=CF(pos.X,pos.Y,pos.Z);pp.Parent=m;m.PrimaryPart=pp;m.Parent=W.workspace
 local prompt=R.new('ProximityPrompt');prompt.Parent=pp;return m,prompt,R.new('TextLabel')
end
function Legacy:_crossedBoundary(p)return p.Z<=0 end
function Legacy:_getGuardianHomeCFrame()return CF(0,0,500)end
function Legacy:_applyGuardianFling()flings+=1 end
local Chase=server('ConcurrentKeeperService')(Legacy)
local Chests={}
function Chests:SetWorldPackAvailable(slot,v)slot.Available=v end
function Chests:IsOpening()return false end
function Chests:GetPackPickupPosition(_,pos)return pos end
local chase=setmetatable({Runs={},KeeperTargets={},KeeperQueues={},Drops={},Advancing={},Starting={},KnownSeeds={},DropSerial=0,HitSerial=0,
 Config={DroppedChestDuration=10,DroppedChestClaimGrace=.35},Map=Map,Chests=Chests,Notifications=Notes,
 PlayerData={IsLoaded=function()return true end,CanReceiveSeed=function()return true end},Bases={GetPlayerBase=function()return {}end}},Chase)
local RagdollService=server('RagdollService')
chase.Ragdoll=RagdollService.new({GuardianFlingProtectionTime=1.25},function(p,h)chase:_restorePhysicalSpeed(p,h)end)

-- Players with mock R6 rigs ----------------------------------------------------------------------------------
local userId=0
local function bodyPart(char,name,pos)local p=R.new('Part');p.Name=name;p.Size=V3(1,2,1);p.CFrame=CF(pos.X,pos.Y,pos.Z);p.Parent=char;return p end
local function motor(name,parent,p0,p1)local m=R.new('Motor6D');m.Name=name;m.Part0=p0;m.Part1=p1;m.C0=CF(0,0,0);m.C1=CF(0,0,0);m.Enabled=true;m.Parent=parent end
local function newPlayer(name,pos)
 userId+=1
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=userId;p.CharacterRemoving=R.signal();p.Parent=Players
 local backpack=R.new('Backpack');backpack.Name='Backpack';backpack.Parent=p
 local char=R.new('Model');char.Name=name
 local root=bodyPart(char,'HumanoidRootPart',pos);local torso=bodyPart(char,'Torso',pos)
 local head=bodyPart(char,'Head',pos);local la=bodyPart(char,'Left Arm',pos);local ra=bodyPart(char,'Right Arm',pos)
 local ll=bodyPart(char,'Left Leg',pos);local rl=bodyPart(char,'Right Leg',pos)
 motor('RootJoint',root,root,torso);motor('Neck',torso,torso,head);motor('Left Shoulder',torso,torso,la);motor('Right Shoulder',torso,torso,ra)
 motor('Left Hip',torso,torso,ll);motor('Right Hip',torso,torso,rl)
 local hum=R.new('Humanoid');hum.Name='Humanoid';hum.Health=100;hum.WalkSpeed=16;hum.JumpPower=50;hum.JumpHeight=7.2;hum.AutoRotate=true
 hum.PlatformStand=false;hum.RigType=R.Enum.HumanoidRigType.R6;hum.HipHeight=0;hum.RequiresNeck=true;hum.EvaluateStateMachine=true;hum.Died=R.signal()
 local states={}
 hum.GetStateEnabled=function(_,s)return states[s]~=false end;hum.SetStateEnabled=function(_,s,v)states[s]=v end
 hum.ChangeState=function(_,s)hum.State=s end
 hum.UnequipTools=function()for _,t in ipairs(char:GetChildren())do if t.ClassName=='Tool'then t.Parent=backpack end end end
 hum.Parent=char
 local tool=R.new('Tool');tool.Name='Shovel';tool:SetAttribute('GardenShovel',true);tool.Enabled=true;tool.Parent=char
 char.Parent=W.workspace;p.Character=char
 return p
end
local function rootOf(p)return p.Character.HumanoidRootPart end
local function moveTo(p,x,y,z)rootOf(p).CFrame=CF(x,y,z)end
local slotSerial=0
local function newSlot(pos)
 slotSerial+=1
 local model=R.new('Model');model.Parent=mapRoot;local body=R.new('Part');body.CFrame=CF(pos.X,pos.Y,pos.Z);body.Parent=model
 local slot={Model=model,Body=body,Available=true,Generation=1,BagVariant=1,Id=slotSerial}
 table.insert(Map.Chests,slot);chase.KnownSeeds[slot]=true;return slot
end
newSlot(V3(0,1,300)) -- the pack pad used by the clearance test
local function startRun(p)
 local slot=newSlot(V3(-90,1,1300+slotSerial*20));slot.Available=false
 local chest={OriginSlot=slot,OriginGeneration=1,BagVariant=1,Stage=1}
 local run={Player=p,Character=p.Character,Humanoid=p.Character.Humanoid,Chest=chest,Stage=1,KeeperKey=1,GuardianLeaseToken=1}
 chase.Runs[p]=run;if not chase.KeeperTargets[1]then chase.KeeperTargets[1]=run end
 p:SetAttribute('ChestChaseSeedCarrying',true);p:SetAttribute('ChestChaseRunActive',true)
 return run,slot
end

-- Service under test ----------------------------------------------------------------------------------------------
local C=W.module('TrackHoleConfig')
local Gate=server('SecurityGate')
local Holes=server('TrackHoleService')
local holes=Holes.new({},Map,chase,Notes);holes.Raycast=raycast;holes:Start()
local function dig(p,aim)Gate.Cleanup(p);holes.NextDig[p]=nil;return holes:Request(p,aim)end
local function holeCount(p)return holes:OwnedCount(p)end
local function onlyHole(p)for _,h in pairs(holes.ByOwner[p]or{})do return h end end
local function clearAll()holes:ClearAll();table.clear(fired);table.clear(notes)end

-- 1. Config sanity: one table, owner's numbers ---------------------------------------------------------------------
check(C.MaxPerPlayer==4 and C.CooldownSeconds==8 and C.MaxPerServer==30 and C.LifetimeSeconds==180 and C.ArmSeconds==1
 and C.RagdollSeconds==4 and C.Diameter>=3 and C.Diameter<=3.5,'config values')
check(holes.Remote.Parent==remotes and holes.Remote.Name=='TrackHole','TrackHole remote created in ChestChaseRemotes')
check(holes.Folder.Parent==runtime,'holes folder lives in the runtime folder')

-- 2. Dig on the track at the feet -----------------------------------------------------------------------------------
local A=newPlayer('Ann',V3(0,3,100))
local ok,why=dig(A)
check(ok and why=='Dug','dig on track ok ('..tostring(why)..')')
local h=onlyHole(A)
check(h and near(h.Position.X,0)and near(h.Position.Z,100)and near(h.Position.Y,0),'hole at the feet on the ground')
local model=h and h.Model
check(model and model.Parent==holes.Folder,'hole model visible (replicated folder)')
local pit=model and model:FindFirstChild('Pit');local rim=model and model:FindFirstChild('Rim')
check(pit and rim and pit.Shape==R.Enum.PartType.Cylinder and near(pit.Size.Y,C.Diameter)and near(pit.Size.Z,C.Diameter),'pit is a flat cylinder of the configured diameter')
check(rim and rim.Size.Y>pit.Size.Y and pit.Size.X<.1 and rim.Size.X<.1,'rim is wider and both are flat (no dent)')
local crumbs,solid=0,false
for _,part in ipairs(model:GetChildren())do
 if part.Name=='Crumb'then crumbs+=1 end
 if part.CanCollide or part.CanQuery or part.CanTouch or not part.Anchored then solid=true end
end
check(crumbs==C.CrumbCount,'dirt crumbs around the hole: '..crumbs)
check(not solid,'hole parts never collide / query / touch')
check(fired[#fired]and fired[#fired].Kind=='Dig'and fired[#fired].Id==h.Id,'dig effect broadcast to everyone')
check(model:GetAttribute('OwnerUserId')==A.UserId,'owner attribute for the client hint')

-- 3. Off the track (lobby / garden): garden shovel keeps its behaviour, nothing happens, no message
table.clear(notes)
moveTo(A,0,3,-40)
ok,why=dig(A)
check(not ok and why=='OffTrack'and #notes==0 and holeCount(A)==1,'off track rejected silently')
moveTo(A,500,3,100)
ok,why=dig(A);check(not ok and why=='OffTrack','beside the track rejected')

-- 4. Aim point / range / forged far aim
moveTo(A,0,3,140)
ok,why=dig(A,V3(8,0,140))
local aimed;for _,x in pairs(holes.ByOwner[A])do if near(x.Position.Z,140)then aimed=x end end
check(ok and aimed and near(aimed.Position.X,8),'dig at an aimed spot in range')
moveTo(A,0,3,180)
ok,why=dig(A,V3(9000,0,9000))
local feet;for _,x in pairs(holes.ByOwner[A])do if near(x.Position.Z,180)then feet=x end end
check(ok and feet and near(feet.Position.X,0),'forged far aim digs at the feet instead')
clearAll()

-- 5. Cooldown
moveTo(A,0,3,100)
ok=dig(A);Gate.Cleanup(A)
moveTo(A,0,3,120)
ok,why=holes:Request(A)
check(not ok and why=='Cooldown'and noted(A,'SHOVEL READY IN 8S'),'cooldown 8 s')
step(7.5);Gate.Cleanup(A);ok,why=holes:Request(A);check(not ok and why=='Cooldown','still cooling at 7.5 s')
step(.6);Gate.Cleanup(A);ok,why=holes:Request(A);check(ok,'dig again after 8 s')
clearAll()

-- 6. Spot rules
local B=newPlayer('Ben',V3(30,3,100))
moveTo(A,0,3,100);dig(A)
moveTo(B,4,3,100);ok,why=dig(B);check(not ok and why=='Spacing'and noted(B,C.Messages.Spacing),'spacing between holes')
moveTo(B,22,3,200);ok,why=dig(B);check(not ok and why=='Ground','not on top of scenery (rock)')
moveTo(B,3,3,300);ok,why=dig(B);check(not ok and why=='Pack','not on a pack spawn pad')
moveTo(B,5,3,505);ok,why=dig(B);check(not ok and why=='Camp','not in a keeper camp')
moveTo(B,0,3,5);ok,why=dig(B);check(not ok and why=='Entrance'and noted(B,C.Messages.Entrance),'not at the entrance / refresh wall')
chase.Drops[99]={Position=V3(40,0,700)}
moveTo(B,42,3,700);ok,why=dig(B);check(not ok and why=='Pack','not on a dropped pack')
chase.Drops[99]=nil
moveTo(B,40,3,700);ok,why=dig(B);check(ok,'same spot ok once the drop is gone')
-- R123: The Dark's Void Pack slots and its home (Event81) block holes too.
chase.Event81={Home=CF(-40,5,800),Slots={{PackHome=V3(-40,5,760)},{PackHome=V3(-20,5,760),Stolen=true}},Active=function()return true end}
moveTo(B,-41,3,760);ok,why=dig(B);check(not ok and why=='Pack','not on a Void Pack slot')
moveTo(B,-39,3,801);ok,why=dig(B);check(not ok and why=='Camp','not at The Dark\'s home')
moveTo(B,-20,3,760);ok,why=dig(B);check(ok,'a stolen Void Pack slot no longer blocks')
chase.Event81=nil
clearAll()

-- 7. Player state rules
moveTo(B,0,3,400)
startRun(B);ok,why=dig(B);check(not ok and why=='Carrying'and noted(B,C.Messages.Carrying),'no digging while carrying')
chase.Runs[B]=nil;chase.KeeperTargets[1]=nil;B:SetAttribute('ChestChaseSeedCarrying',false);B:SetAttribute('ChestChaseRunActive',false)
B:SetAttribute('GuardianRagdollActive',true);ok,why=dig(B);check(not ok and why=='Downed','no digging while ragdolled')
B:SetAttribute('GuardianRagdollActive',false)
Map.Refreshing=true;ok,why=dig(B);check(not ok and why=='Refreshing','no digging during the refresh');Map.Refreshing=false
local shovel=B.Character.Shovel
shovel.Parent=B.Backpack;ok,why=dig(B);check(not ok and why=='Shovel','shovel must be equipped')
shovel.Parent=B.Character;shovel.Enabled=false;ok,why=dig(B);check(not ok and why=='Shovel','disabled shovel (ragdoll disarm) cannot dig')
shovel.Enabled=true;ok=dig(B);check(ok,'dig ok again')
clearAll()

-- 8. Forged remote args and rate limit (through the real OnServerEvent path)
local before=holes.Count
moveTo(B,0,3,400)
for _,bad in ipairs({'x',{1,2},V3(0/0,0,0),V3(math.huge,0,0),B.Character,true,12})do
 Gate.Cleanup(B);holes.NextDig[B]=nil;holes.Remote.OnServerEvent:Fire(B,bad)
end
check(holes.Count==before,'forged args never dig')
ok,why=dig(B,'x');check(not ok and(why=='Args'or why=='Rate'),'string aim rejected')
ok,why=dig(B,{X=1,Y=2,Z=3});check(not ok and why=='Args','table aim rejected')
ok,why=dig(B,V3(0/0,0,0));check(not ok and why=='Rate','NaN aim rejected by the gate')
Gate.Cleanup(B);local accepted=0
for _=1,10 do local _,w=holes:Request(B,'spam');if w~='Rate'then accepted+=1 end end
check(accepted==4,'remote rate-limited by SecurityGate (burst 4): '..accepted)
clearAll()

-- 9. Arming delay, trap, ragdoll 4 s, drop through the existing path, hole used up
moveTo(A,0,3,600);dig(A);local trapHole=onlyHole(A)
moveTo(B,0,3,580)
local run,slot=startRun(B)
step(.1);moveTo(B,0,3,600);step(.1)
check(chase.Runs[B]==run and trapHole.Model.Parent,'fresh hole is not armed yet (no trap)')
step(.9);step(.05)
check(chase.Runs[B]==nil and B:GetAttribute('ChestChaseSeedCarrying')==false,'armed hole traps the carrier (run finished)')
local drop;for _,d in pairs(chase.Drops)do if d.Chest==run.Chest then drop=d end end
check(drop~=nil and slot.Available==false,'pack dropped on the ground via ConcurrentKeeperService (not returned, not banked)')
check(flings==0,'keeper fling skipped (ImpactApplied)')
check(not noted(B,'CAUGHT! PACK DROPPED')and noted(B,C.Messages.Trapped),'only the hole notice (R123: no double toast)')
check(noted(A,string.format(C.Messages.Tripped,'Ben')),'digger told who fell in')
check(trapHole.Model.Parent==nil and holes.Holes[trapHole.Id]==nil and holeCount(A)==0,'hole used up by the trap; slot freed')
check(fired[#fired].Kind=='Trap'and fired[#fired].VictimUserId==B.UserId,'trap effect broadcast')
check(B:GetAttribute('GuardianRagdollActive')==true and near(B:GetAttribute('LastGuardianRagdollDuration'),4),'ragdolled for exactly 4 s')
local hum=B.Character.Humanoid
check(hum.WalkSpeed==0 and hum.PlatformStand==true,'cannot move while down')
check(shovel.Enabled==false and shovel.Parent==B.Backpack,'disarmed: tools unequipped and disabled')
step(3.8)
check(B:GetAttribute('GuardianRagdollActive')==true,'still down at 3.9 s')
check(chase:_canTake(B,V3(0,3,600))==nil,'cannot steal while down')
ok,why=dig(B);check(not ok,'cannot dig while down')
step(.2)
check(B:GetAttribute('GuardianRagdollActive')==false and B:GetAttribute('GuardianFlingActive')==false,'recovered after 4 s')
check(hum.WalkSpeed==16 and hum.PlatformStand==false and shovel.Enabled==true,'movement and tools restored by the normal recovery')
check(chase:_canTake(B,V3(0,3,600))~=nil,'can steal again after recovery')
clearAll()

-- 10. Fast runner crossing a hole between two heartbeats still falls in
moveTo(A,0,3,700);dig(A);step(1.1)
local C1=newPlayer('Cal',V3(0,3,690));startRun(C1);step(.02)
moveTo(C1,0,3,710);step(.02)
check(chase.Runs[C1]==nil,'segment crossing traps a fast carrier')
clearAll();chase.Ragdoll:Clear(C1)

-- 11. Non-carrier walks over normally; digger cannot trap self; high jump clears; tutorial steps 1-2 safe
moveTo(A,0,3,800);dig(A);local h2=onlyHole(A);step(1.1)
local D=newPlayer('Dee',V3(0,3,800));step(.1)
check(h2.Model.Parent~=nil and not D:GetAttribute('GuardianRagdollActive'),'non-carrier unaffected; hole stays')
moveTo(A,0,3,800);startRun(A);step(.1)
check(chase.Runs[A]~=nil and h2.Model.Parent~=nil,'digger cannot trap themself')
chase.Runs[A]=nil;chase.KeeperTargets[1]=nil;A:SetAttribute('ChestChaseSeedCarrying',false);A:SetAttribute('ChestChaseRunActive',false)
moveTo(D,0,12,780);startRun(D);step(.05);moveTo(D,0,12,800);step(.05)
check(chase.Runs[D]~=nil,'a high jump over the hole is not a fall')
moveTo(D,0,3,800);D:SetAttribute('TutorialStep',1);D:SetAttribute('TutorialDone',false);step(.05)
check(chase.Runs[D]~=nil,'tutorial step 1 carrier is not trapped')
D:SetAttribute('TutorialStep',2);step(.05);check(chase.Runs[D]~=nil,'tutorial step 2 carrier is not trapped')
D:SetAttribute('TutorialStep',3);step(.05);check(chase.Runs[D]==nil,'tutorial step 3 carrier is trapped')
clearAll();chase.Ragdoll:Clear(D)

-- 12. Edge of the circle: trap circle == visible circle
moveTo(A,0,3,900);dig(A);step(1.1)
local E=newPlayer('Eve',V3(C.Diameter/2+.05,3,900));startRun(E);step(.05)
check(chase.Runs[E]~=nil,'just outside the visible circle: no fall')
moveTo(E,C.Diameter/2-.05,3,900);step(.05)
check(chase.Runs[E]==nil,'just inside the visible circle: fall')
clearAll();chase.Ragdoll:Clear(E)

-- 13. Limits: 4 per player (5th refused, never replaced), slot frees only on trap / cover / expiry / refresh / leave
local F=newPlayer('Fay',V3(0,3,1000))
for i=1,4 do moveTo(F,0,3,1000+i*10);ok=dig(F);check(ok,'dig #'..i)end
moveTo(F,0,3,1060);ok,why=dig(F)
check(not ok and why=='PlayerCap'and noted(F,string.format(C.Messages.PlayerCap,4))and holeCount(F)==4,'5th hole refused with the cap message')
step(100);moveTo(F,0,3,1060);ok,why=dig(F);check(not ok and why=='PlayerCap','time alone (100 s) does not free a slot')
-- cover: aim at your own hole (also works at the cap and during cooldown)
local own;for _,x in pairs(holes.ByOwner[F])do if near(x.Position.Z,1010)then own=x end end
moveTo(F,0,3,1014);holes.NextDig[F]=R.clock+5;Gate.Cleanup(F)
ok,why=holes:Request(F,V3(.5,0,1010.5))
check(ok and why=='Covered'and own.Model.Parent==nil and holeCount(F)==3,'owner covers own hole; slot freed')
check(fired[#fired].Kind=='Cover'and noted(F,C.Messages.Covered),'cover effect + notice')
moveTo(F,0,3,1060);ok=dig(F);check(ok and holeCount(F)==4,'dig again after covering')
-- others cannot cover your hole
local G=newPlayer('Gus',V3(0,3,1020));local theirs;for _,x in pairs(holes.ByOwner[F])do if near(x.Position.Z,1020)then theirs=x end end
ok,why=dig(G,V3(0,0,1020))
check(not ok and why=='Spacing'and theirs.Model.Parent~=nil and holeCount(F)==4,'non-owner cannot cover someone else\'s hole')
-- trap frees a slot
step(1.1);local Hn=newPlayer('Hal',V3(0,3,1020));startRun(Hn);step(.05)
check(holeCount(F)==3 and theirs.Model.Parent==nil,'trap frees the owner slot')
moveTo(F,0,3,1080);ok=dig(F);check(ok and holeCount(F)==4,'dig again after a trap')
chase.Ragdoll:Clear(Hn)
-- expiry after 180 s frees slots
local newest;for _,x in pairs(holes.ByOwner[F])do if not newest or x.DugAt>newest.DugAt then newest=x end end
local oldest;for _,x in pairs(holes.ByOwner[F])do if not oldest or x.DugAt<oldest.DugAt then oldest=x end end
check(near(oldest.ExpiresAt-oldest.DugAt,180),'lifetime is 180 s')
step(oldest.ExpiresAt-R.clock+.05)
check(holes.Holes[oldest.Id]==nil and holeCount(F)<4,'oldest hole expired after 180 s; slot freed')
local untilNewest=newest.ExpiresAt-R.clock
step(untilNewest-.2);check(holes.Holes[newest.Id]~=nil,'not expired at 179.8 s')
step(.3);check(holes.Holes[newest.Id]==nil and newest.Model.Parent==nil and holeCount(F)==0,'expired at 180 s; all slots free')
clearAll()

-- 14. Server cap (temporarily 5)
local cap=C.MaxPerServer;C.MaxPerServer=5
local diggers={}
for i=1,5 do local p=newPlayer('S'..i,V3(-60+i*10,3,1200));diggers[i]=p;check(dig(p),'server dig '..i)end
local S6=newPlayer('S6',V3(60,3,1200));ok,why=dig(S6)
check(not ok and why=='ServerCap'and noted(S6,C.Messages.ServerCap),'server cap refuses')
C.MaxPerServer=cap

-- 15. Track refresh clears every hole (and frees slots); owner leaving clears theirs
mapRoot:SetAttribute('BiomesRefreshing',true)
check(holes.Count==0 and #holes.Folder:GetChildren()==0,'refresh clears all holes')
mapRoot:SetAttribute('BiomesRefreshing',false)
for i=1,2 do moveTo(diggers[1],0,3,1200+i*10);dig(diggers[1])end
moveTo(diggers[2],40,3,1250);dig(diggers[2])
holes:CleanupPlayer(diggers[1])
check(holeCount(diggers[1])==0 and holes.Count==1,'leaving clears only the leaver\'s holes')
diggers[2].Parent=nil;step(.05)
check(holes.Count==0,'owner gone: heartbeat removes their holes')
clearAll()

-- 16. Ragdoll regression: other causes keep their durations
local K=newPlayer('Kim',V3(0,3,50))
chase.Ragdoll:Apply(K,V3(0,0,0),'Bat')
check(near(K:GetAttribute('LastGuardianRagdollDuration'),W.module('KnockbackConfig').Bat.Stun),'bat stun unchanged')
chase.Ragdoll:Clear(K)

-- 17. Garden shovel unchanged: same tool, hint added to the tooltip only
local tools=server('HarvestToolService')
local P=newPlayer('Pat',V3(0,3,-50));P.Character.Shovel:Destroy()
local fakeChests={PlayerData={IsLoaded=function()return true end,Gardens={}},Config={GardenPlants={}}}
function fakeChests:_getToolContainers(p)return {p.Backpack,p.Character},p.Backpack end
tools.Sync(fakeChests,P)
local made=P.Backpack:FindFirstChild('Shovel')
check(made and made:GetAttribute('GardenShovel')==true and made.ManualActivationOnly==true and made.CanBeDropped==false
 and made:GetAttribute('InventoryKey')=='shovel'and made.RequiresHandle==true,'garden shovel tool unchanged')
check(made and made.ToolTip:find('Remove a plant',1,true)and made.ToolTip:find('Dig a hole on the track',1,true),'tooltip hints the hole feature')

-- 18. R123 owner commands: dig / holes / holes clear / ragdoll / fling (OwnerUpdateCommands82.Execute)
local X=server('OwnerUpdateCommands82')
chase.TrackHoles=holes
function chase:_getGuardianSettings(st)local k=W.module('KnockbackConfig').Keeper[st];return {FlingHorizontal=k[1],FlingVertical=k[2]}end
local ctx={Chase=chase,Map=Map,Data={Gardens={}},Config={BiomeNames={'Forest','Desert','Snow','Lava','Crystal','Jungle','Storm'}}}
local O=newPlayer('Ola',V3(40,3,1000))
local ok,msg=X.Execute(ctx,O,'dig',{});check(ok and holeCount(O)==1,'dig @target digs at their feet: '..tostring(msg))
moveTo(O,40,3,1040);ok,msg=X.Execute(ctx,O,'dig',{});check(ok and holeCount(O)==2,'dig skips the 8 s cooldown: '..tostring(msg))
ok,msg=X.Execute(ctx,O,'holes',{});check(ok and msg:find('@Ola: 2',1,true),'holes lists per player: '..tostring(msg))
O.Character.Shovel.Parent=O.Backpack;moveTo(O,40,3,1080)
ok,msg=X.Execute(ctx,O,'dig',{});check(not ok and msg:find('shovel',1,true),'dig needs the shovel: '..tostring(msg))
O.Character.Humanoid:UnequipTools();O.Backpack.Shovel.Parent=O.Character
ok,msg=X.Execute(ctx,O,'holes',{'clear'});check(ok and holes.Count==0,'holes clear removes all: '..tostring(msg))
ok,msg=X.Execute(ctx,O,'ragdoll',{'4'});check(ok and chase.Ragdoll:IsActive(O)and near(O:GetAttribute('LastGuardianRagdollDuration'),4),'ragdoll 4 lasts 4 s: '..tostring(msg))
ok,msg=X.Execute(ctx,O,'fling',{'storm'});check(not ok,'no second ragdoll while one is active')
chase.Ragdoll:Clear(O);step(2)
ok,msg=X.Execute(ctx,O,'fling',{'storm'});check(ok and chase.Ragdoll:IsActive(O)and msg:find('182 up',1,true),'fling storm uses the Storm keeper launch: '..tostring(msg))
chase.Ragdoll:Clear(O);step(2)
ok,msg=X.Execute(ctx,O,'fling',{'dark'});check(ok and msg:find('The Dark',1,true)and msg:find('200 up',1,true),'fling dark uses The Dark launch: '..tostring(msg))
chase.Ragdoll:Clear(O);step(2)
ok,msg=X.Execute(ctx,O,'fling',{'mars'});check(not ok,'unknown fling biome refused')
ok,msg=X.Execute(ctx,O,'ragdoll',{'60'});check(not ok,'ragdoll over 10 s refused')
local T=server('OwnerCommandTargets82')
check(T.IsGlobal('/test holes clear')and T.IsGlobal('holes')and T.IsGlobal('admins')and not T.IsGlobal('dig')and not T.IsGlobal('fling storm'),'server-wide commands refuse @target; player commands accept it')

print(string.format('%s: %d checks, %d failures',fails==0 and'PASS'or'FAIL',checks,fails))
if fails>0 then error('failures',0)end
