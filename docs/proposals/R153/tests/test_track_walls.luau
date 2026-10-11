--!nocheck
-- R153 track walls: checks of the REAL code (ChestChaseServer.TrackWalls153, built by MapService.new after every pass that moves a wall) on the owner's place
-- (place_tree.luau from docs/proposals/R149/tools/rbxl_geom.py) in the R149 Roblox mock. Prints "ok <name>" / "FAIL <name>: why", "INFO ..." lines and, for
-- check_track_walls.py, one "WP" line per solid part of the map after the builders (and "KB" / "HULL" / "GATE" / "TRAMP" lines: the numbers the geometry and fling
-- checks need). Errors at the end if anything failed.
--  1. the blockers as built on the owner's place: one per wall part, a Persistent model, anchored / colliding / invisible / untouchable / never drawn, within the part size limit
--  2. the pure plan (M.Plan) on synthetic walls: a tall wall, a 4,500-stud wall in chunks, a wall that is not a wall, the end wall's orientation, joints
--  3. a rebuild replaces the blockers (no doubles) and follows a wall that changed
--  4. the fallback (M.Step / M.Start) on mock players: a body resting on a wall top / in the blockers is put back on the track after two looks; a body flying past, standing
--     on the floor, on one look only, dead, anchored or in owner test flight is left alone; the movement guard is told
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return{}end
function Players.GetPlayerByUserId()return nil end;function Players.GetUserThumbnailAsync()return'',true end
local Http=W.service('HttpService');local guid=0;function Http.GenerateGUID()guid+=1;return'guid-'..guid end;function Http.JSONEncode(_,t)return'{}'end;function Http.JSONDecode()return{}end
local DS=W.service('DataStoreService');function DS.GetDataStore()return{GetAsync=function()return nil end,SetAsync=function()end,UpdateAsync=function()return nil end}end;DS.GetOrderedDataStore=DS.GetDataStore
local MS=W.service('MarketplaceService');MS.PromptProductPurchaseFinished=R.signal();MS.PromptGamePassPurchaseFinished=R.signal()
W.env.bit32=bit32
do local Inst=R.Inst;local raw=Inst.IsA
 function Inst:IsA(c)if self._class=='SpawnLocation'and(c=='Part'or c=='BasePart'or c=='PVInstance'or c=='FormFactorPart')then return true end;return raw(self,c)end
end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='BindableEvent'then o.Event=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local map=Z.loadPlace(require('./place_tree'),W.workspace)
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local passed,failed=0,0
local function check(name,cond,why)
 if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end
end
local function info(s)print('INFO '..s)end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local function aabb(p)
 local c=p._props.CFrame;local s=p._props.Size;local r=c.R;local q=c.Position
 local e={(math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2}
 return{q.X-e[1],q.Y-e[2],q.Z-e[3]},{q.X+e[1],q.Y+e[2],q.Z+e[3]},e
end

-- the stand-in movement guard (the real one is checked by its own suites) ----------------------------------------------------------------------------
local resets={}
folder.MovementGuard.Parent=nil
W.stub('MovementGuard',{Reset=function(p,g)resets[#resets+1]={Player=p,Grace=g}end})
RS.MovementGuard.Parent=folder

-- the real start-up on the owner's place -------------------------------------------------------------------------------------------------------------
local Config=server('Config')
server('MapService').new(Config);R.advance(.1);R.advance(1)
local TW=server('TrackWalls153')

-- 1. the blockers as built ---------------------------------------------------------------------------------------------------------------------------
local walls=map.Obby.BiomeWalls
local wallParts={}
for _,p in ipairs(walls:GetChildren())do if p:IsA('BasePart')then wallParts[#wallParts+1]=p end end
local model=map:FindFirstChild(TW.Name)
check('built: MapService.new made the blockers model',model~=nil and model._class=='Model')
local blockers={}
if model then for _,p in ipairs(model:GetChildren())do blockers[#blockers+1]=p end end
check('built: one blocker per wall part ('..#wallParts..' walls: 7 biomes x 2 sides + the end wall)',#wallParts==15 and #blockers==#wallParts,#blockers..' blockers for '..#wallParts..' walls')
check('built: the model is Persistent (always on every client under StreamingEnabled)',model and model._props.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent)
local bad
for _,p in ipairs(blockers)do
 local pr=p._props
 if not(p:IsA('BasePart')and pr.Anchored==true and pr.CanCollide==true and pr.CanTouch==false and pr.CanQuery==true and pr.CastShadow==false and pr.Transparency==1)then bad=bad or p.Name end
 if #p._children>0 then bad=bad or(p.Name..' has children')end
end
check('built: anchored, colliding, Transparency 1, CastShadow off, CanTouch off, CanQuery on (the runner sweep must see them), nothing inside them',bad==nil,bad)
local big
for _,p in ipairs(blockers)do local s=p._props.Size;if s.X>2048 or s.Y>2048 or s.Z>2048 then big=p.Name end end
check('built: no part exceeds Roblox\'s 2,048-stud size limit',big==nil,big)
local reach=math.huge;local names={}
for _,p in ipairs(blockers)do names[#names+1]=p.Name end
check('built: every blocker belongs to a different wall',(function()local seen={};for _,p in ipairs(blockers)do local w=p:GetAttribute('Wall');if not w or seen[w]or not walls:FindFirstChild(w)then return false end;seen[w]=true end;return true end)())
-- the geometry dump for check_track_walls.py (every solid part of the map now)
local n=0
local function walk(o)
 for _,c in ipairs(o._children)do
  if c:IsA('BasePart')and c._props.CFrame and c._props.Size and c._props.CanCollide~=false then
   local lo,hi,e=aabb(c);local r=c._props.CFrame.R
   local axis=true;for i=1,3 do for j=1,3 do local v=math.abs(r[i][j]);if v>1e-4 and v<1-1e-4 then axis=false end end end
   print(string.format('WP\t%s\t%s\t%d\t%.2f\t%.4f %.4f %.4f\t%.4f %.4f %.4f\t%d',Z.path(c),c._class,(c._props.CanQuery==false)and 0 or 1,c._props.Transparency or 0,lo[1],lo[2],lo[3],hi[1],hi[2],hi[3],axis and 1 or 0))
   n+=1
  end
  walk(c)
 end
end
walk(map)
print('WPCOUNT '..n)
-- the numbers the fling checks use
local K=W.module('KnockbackConfig')
for i,l in ipairs(K.Keeper)do print(string.format('KB\tKeeper\t%d\t%g\t%g',i,l[1],l[2]))end
print(string.format('KB\tSpecialKeeper\t0\t%g\t%g',K.SpecialKeeper.Horizontal,K.SpecialKeeper.Vertical))
print(string.format('KB\tLightning\t0\t%g\t%g',K.Lightning.Horizontal,K.Lightning.Vertical))
print(string.format('KB\tBat\t0\t%g\t%g',K.Bat.Horizontal,K.Bat.Vertical))
print('KB\tGravity\t0\t'..tostring(W.workspace.Gravity or 196.2)..'\t0')
local motion=RS:FindFirstChild('RunnerMotion')
print('KB\tTrackHalfWidth\t0\t'..tostring(motion and motion:GetAttribute('TrackHalfWidth'))..'\t0')
do -- the runner's hull (RunnerSweep.Hull) for a default R15 body
 local Sweep=W.module('RunnerSweep')
 local ch=R.new('Model');local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Parent=ch
 local hum=R.new('Humanoid');hum.HipHeight=2;hum.RigType=R.Enum.HumanoidRigType.R15;hum.Parent=ch
 local size,off=Sweep.Hull(ch,hum,root)
 print(string.format('HULL\t%.4f\t%.4f\t%.4f',size.X,size.Y,size.Z))
end
do -- the refresh barrier's opening and the keyboard's heights
 local RB=W.module('RefreshBarrier');local o=RB.Opening(map.Lobby.BaseBoundaryLine)
 print(string.format('GATE\t%.4f\t%.4f\t%.4f',o.Half or 0,o.Bottom or 0,o.Top or 0))
 local KT=W.module('KeyboardTrack').Config
 print(string.format('KEYBOARD\t%.4f\t%.4f\t%.4f\t%.4f',KT.FieldWidth,KT.FloorTop+KT.RestRise+KT.KeyY,KT.FloorTop,KT.CenterX))
 local T=W.module('HubTrampolineRules153')
 print(string.format('TRAMP\t%.4f\t%.4f',T.Top()+T.Apex(T.Velocity(196.2),196.2),T.MaxHeight+T.Top()))
end

-- 2. the pure plan ------------------------------------------------------------------------------------------------------------------------------------
local function wall(name,cx,cy,cz,hx,hy,hz)return{Name=name,CX=cx,CY=cy,CZ=cz,HX=hx,HY=hy,HZ=hz}end
do -- the place's shape: two side walls and an end wall
 local plan=TW.Plan({wall('Biome_1_LeftWall',-91.5,27,-10,2.5,24,90),wall('Biome_6_LeftWall',-91.5,27,305,2.5,24,225),wall('Biome_1_RightWall',91.5,27,-10,2.5,24,90),wall('Biome_5_EndWall',0,27,5982.5,94,24,2.5)})
 check('plan: one blocker per wall',#plan.Blockers==4 and #plan.Zones==4,#plan.Blockers)
 local byWall={};for _,b in ipairs(plan.Blockers)do byWall[b.Wall]=b end
 local r=byWall.Biome_1_RightWall
 check('plan: the right wall\'s blocker starts at the wall\'s inner face (x 89, 0.02 on the track side) and reaches 3 past the outer face (94)',near(r.Cx-r.Sx/2,89-.02)and near(r.Cx+r.Sx/2,97),r.Cx-r.Sx/2)
 local l=byWall.Biome_1_LeftWall
 check('plan: the left wall\'s mirrors it',near(l.Cx+l.Sx/2,-89+.02)and near(l.Cx-l.Sx/2,-97))
 check('plan: from 6 studs inside the wall to 1000 over its top (51)',near(r.Cy-r.Sy/2,45)and near(r.Cy+r.Sy/2,1051),r.Cy-r.Sy/2)
 check('plan: along the wall: the wall\'s own length where nothing joins it (z -100 .. 80)',near(r.Cz-r.Sz/2,-100)and near(r.Cz+r.Sz/2,80),r.Cz-r.Sz/2)
 check('plan: where two walls meet (z 80) each reaches 0.5 past the joint (no seam)',near(l.Cz+l.Sz/2,80.5)and near(byWall.Biome_6_LeftWall.Cz-byWall.Biome_6_LeftWall.Sz/2,79.5),l.Cz+l.Sz/2)
 local e=byWall.Biome_5_EndWall
 check('plan: the end wall (z 5980 - 5985, running along x) is covered the same way: inner face z 5979.98, 3 past the outer face',near(e.Cz-e.Sz/2,5980-.02)and near(e.Cz+e.Sz/2,5988)and near(e.Cx-e.Sx/2,-94)and near(e.Cx+e.Sx/2,94),e.Cz-e.Sz/2)
end
do -- a taller wall (a future biome): the blocker follows it
 local plan=TW.Plan({wall('Tall_RightWall',91.5,42,0,2.5,40,100)})
 local b=plan.Blockers[1]
 check('plan: a wall 80 tall (top 82) gets a blocker from 76 to 1082',near(b.Cy-b.Sy/2,76)and near(b.Cy+b.Sy/2,1082),b.Cy-b.Sy/2)
end
do -- a long wall: parts of at most 2,000 studs that overlap and cover it
 local plan=TW.Plan({wall('Long_RightWall',91.5,27,2250,2.5,24,2250)})
 local lo,hi,okSize,okLap=math.huge,-math.huge,true,true;local last
 local list=plan.Blockers;table.sort(list,function(a,b)return a.Cz<b.Cz end)
 for _,b in ipairs(list)do
  if b.Sz>2000+2 then okSize=false end
  if last and b.Cz-b.Sz/2>last then okLap=false end
  last=b.Cz+b.Sz/2;lo=math.min(lo,b.Cz-b.Sz/2);hi=math.max(hi,b.Cz+b.Sz/2)
 end
 check('plan: a 4,500-stud wall is covered by '..#list..' parts of at most 2,000 studs that overlap',#list==3 and okSize and okLap and near(lo,0)and near(hi,4500),#list)
end
do -- a thick block is not a wall
 local plan=TW.Plan({wall('Block',0,10,0,30,10,40),wall('Biome_1_RightWall',91.5,27,0,2.5,24,50)})
 check('plan: a part thicker than 12 studs is not a wall',#plan.Blockers==1 and plan.Blockers[1].Wall=='Biome_1_RightWall',#plan.Blockers)
end
check('plan: no walls, no blockers',#TW.Plan({}).Blockers==0)
do -- a wall turned 90 degrees in the world (Measure uses the part's real extents)
 local f=R.new('Folder');f.Name='T';local obby=R.new('Folder');obby.Name='Obby';obby.Parent=f
 local bw=R.new('Folder');bw.Name='BiomeWalls';bw.Parent=obby
 local p=R.new('Part');p.Name='Turned';p.Size=V3(100,48,5);p.CFrame=R.CFrame.new(91.5,27,0,0,0,1,0,1,0,-1,0,0);p.Parent=bw
 local list=TW.Measure(f)
 check('measure: a wall turned 90 degrees is read by its world extents (2.5 x 24 x 50)',#list==1 and near(list[1].HX,2.5,1e-3)and near(list[1].HZ,50,1e-3)and near(list[1].HY,24,1e-3),list[1] and list[1].HX)
end

-- 3. a rebuild replaces the blockers, and follows a changed wall ---------------------------------------------------------------------------------
do
 TW.Apply(map)
 local again=map:FindFirstChild(TW.Name);local count=0
 for _,c in ipairs(map._children)do if c._props.Name==TW.Name then count+=1 end end
 check('rebuild: Apply again leaves exactly one model with the same parts',count==1 and #again._children==#wallParts and again~=model,count)
 local w=walls:FindFirstChild('Biome_7_RightWall');local keep=w._props.Size;local keepCf=w._props.CFrame
 w.Size=V3(keep.X,80,keep.Z);w.CFrame=CF(keepCf.Position.X,43,keepCf.Position.Z)
 TW.Apply(map)
 local b;for _,p in ipairs(map:FindFirstChild(TW.Name)._children)do if p:GetAttribute('Wall')=='Biome_7_RightWall'then b=p end end
 check('rebuild: a wall made 80 tall (top 83) gets a blocker from 77 to 1083',b and near(b._props.CFrame.Position.Y-b._props.Size.Y/2,77,1e-3)and near(b._props.CFrame.Position.Y+b._props.Size.Y/2,1083,1e-3))
 w.Size=keep;w.CFrame=keepCf;TW.Apply(map)
end

-- 4. the fallback -------------------------------------------------------------------------------------------------------------------------------------
local playersList={}
function Players.GetPlayers()return playersList end
local function body(x,y,z,vy,opts)
 opts=opts or{}
 local player=R.new('Player');player.Name='P'..(#playersList+1)
 local ch=R.new('Model');ch.Name='Character'
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(x,y,z);root.Anchored=opts.Anchored==true;root.Parent=ch
 root.AssemblyLinearVelocity=V3(opts.Vx or 0,vy,0);root.AssemblyAngularVelocity=V3(1,2,3)
 local hum=R.new('Humanoid');hum.Health=opts.Health or 100;hum.Parent=ch
 ch._props.PrimaryPart=root;ch.Parent=W.workspace;player.Character=ch
 if opts.Flying then player:SetAttribute('StudioTestFlying',true)end
 if opts.Noclip then player:SetAttribute('StudioTestNoclip',true)end
 playersList[#playersList+1]=player
 return player,root,ch
end
local function clear()playersList={};resets={};TW.Seen=setmetatable({},{__mode='k'});TW.Rescues=0 end
do
 clear()
 local p,root=body(89.5,54,500,0)
 local m1=TW.Step();local at1=root.Position
 check('fallback: a body resting on a right wall top is not moved on the first look',m1==0 and near(at1.X,89.5))
 local m2=TW.Step();local at2=root.Position
 check('fallback: ... and is put 6 studs in from the wall\'s face (x 83) on the second, keeping its height and place along the wall',m2==1 and near(at2.X,83,1e-6)and near(at2.Y,54,1e-6)and near(at2.Z,500,1e-6),tostring(at2))
 local v=root.AssemblyLinearVelocity
 check('fallback: its sideways speed and spin are stopped',near(v.X,0)and near(v.Z,0)and near(v.Y,0)and near(root.AssemblyAngularVelocity.Magnitude,0))
 check('fallback: the movement guard is told (a move it did not see must not look like a speed hack)',#resets==1 and resets[1].Player==p and resets[1].Grace>0,#resets)
 check('fallback: counted',TW.Rescues==1)
 TW.Step();TW.Step()
 check('fallback: once on the track it is left alone',TW.Rescues==1 and near(root.Position.X,83))
end
do
 clear()
 local _,l=body(-89.4,60,2000,1.5);TW.Step();TW.Step()
 check('fallback: the left wall mirrors it (x -83)',near(l.Position.X,-83)and TW.Rescues==1,tostring(l.Position))
 local _,e=body(0,54,5982.5,-1);TW.Step();TW.Step()
 check('fallback: a body on the end wall (z 5982.5) goes to z 5974',near(e.Position.Z,5974)and TW.Rescues==2,tostring(e.Position))
 local _,fall=body(89.5,58,100,-2);TW.Step();TW.Step()
 check('fallback: a body sinking at 2 studs/s (settling on the top) is still moved in',near(fall.Position.X,83)and TW.Rescues==3,tostring(fall.Position))
end
do
 clear()
 local _,fling=body(89.5,80,500,60)
 local _,sliding=body(88.5,70,500,-40)
 local _,floor=body(88,7,500,0)
 local _,mid=body(60,54,500,0)
 local _,beyond=body(120,54,500,0)
 local _,before=body(89.5,54,-150,0)
 local _,low=body(89.5,40,500,0)
 for _=1,8 do TW.Step()end
 check('fallback: a body flying up or sliding down past the wall is never touched (60 / -40 studs/s)',near(fling.Position.X,89.5)and near(sliding.Position.X,88.5))
 check('fallback: a body on the floor beside the wall, in the middle of the track, outside the wall zone, before the first wall, or below the wall top is left alone',near(floor.Position.X,88)and near(mid.Position.X,60)and near(beyond.Position.X,120)and near(before.Position.X,89.5)and near(low.Position.X,89.5)and TW.Rescues==0,TW.Rescues)
end
do
 clear()
 local _,pass=body(89.5,60,500,0)
 TW.Step()
 pass.AssemblyLinearVelocity=V3(0,50,0) -- it was only at the top of a jump
 TW.Step();TW.Step()
 check('fallback: one look is not enough (a body at the top of a hop is moving on the next look, and the first look is forgotten)',near(pass.Position.X,89.5)and TW.Rescues==0)
 pass.AssemblyLinearVelocity=V3(0,0,0)
 TW.Step()
 check('fallback: ... it needs two resting looks in a row again',near(pass.Position.X,89.5)and TW.Rescues==0)
 TW.Step()
 check('fallback: ... and then it is moved',near(pass.Position.X,83)and TW.Rescues==1,tostring(pass.Position))
end
do
 clear()
 local _,dead=body(89.5,54,500,0,{Health=0})
 local _,anchored=body(89.5,54,500,0,{Anchored=true})
 local _,flying=body(89.5,54,500,0,{Flying=true})
 local _,noclip=body(89.5,54,500,0,{Noclip=true})
 for _=1,6 do TW.Step()end
 check('fallback: a dead body, an anchored one and owner test flight / noclip are left alone',near(dead.Position.X,89.5)and near(anchored.Position.X,89.5)and near(flying.Position.X,89.5)and near(noclip.Position.X,89.5)and TW.Rescues==0)
 local gone=R.new('Player');gone.Name='NoCharacter';playersList[#playersList+1]=gone
 local ok=pcall(TW.Step)
 check('fallback: a player without a character is skipped',ok)
end
do -- Start / Stop: four looks a second off the heartbeat
 clear()
 local _,root=body(89.5,54,500,0)
 TW.Start();TW.Start()
 W.frames(10) -- 1/6 s: no look yet
 check('fallback: Start looks every 0.25 s, not every frame (nothing after 10 frames)',near(root.Position.X,89.5))
 W.frames(40) -- 0.67 s more: two looks
 check('fallback: ... and two looks later the body is back on the track',near(root.Position.X,83)and TW.Rescues==1,tostring(root.Position))
 local connections=0;for _,c in ipairs(Run.Heartbeat._c)do if c.Connected then connections+=1 end end
 TW.Stop();TW.Stop()
 local after=0;for _,c in ipairs(Run.Heartbeat._c)do if c.Connected then after+=1 end end
 check('fallback: Start twice makes one connection; Stop removes it',after==connections-1,connections..' -> '..after)
end
check('Inspect: the zones are numbers only (no instances kept)',(function()for _,z in ipairs(TW.Zones)do for _,v in pairs(z)do if type(v)=='table'or type(v)=='userdata'then return false end end end;return #TW.Zones>0 end)())

print(string.format('R153 track walls: %d checks, %d failures',passed+failed,failed))
if failed>0 then error('failed')end
