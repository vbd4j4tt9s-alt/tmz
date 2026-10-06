--!nocheck
-- R153 (owner, in Studio: "the ground like the lava or the track should be moving for all treadmills not just the arrow"): the treadmill belt's pattern against the chevrons, on the Roblox
-- mock with the REAL BiomeVisuals (every level / biome of the machine), TreadmillFx (started the way the game starts it: Fx.Start), TreadmillBeltArt151 and the chevrons' OWN code
-- (the V134 block of SpeedGainPopup.client.lua, bundled as 'BeltArrows') running in one world, on the same frames. MODE 'before' (the R152 src): the root cause is measured;
-- MODE 'after' (this checkout): the pattern moves.
--  root cause   at quality tier 1 (what ClientFxBudget drops to in Studio after a few slow seconds) and in FastMode the chevrons move and the pattern stands still; at tier 3 the
--               glow / stream layers run 1.6 / 2.4 x the chevrons' speed
--  after        every machine (the 7 levels / biomes), every tier (1 / 2 / 3), training and idle: every layer travels exactly what the chevrons travel (3.0 / 1.3 studs a second);
--               over many tile wraps no jump (the biggest step of a frame is the step's travel, offsets stay inside the tile); the pattern moves exactly where the chevrons
--               move (near, 140 studs; FastMode 90) and not with Reduced Motion; a write only when the offset changed; the route that drew the belt (generated, grid, pending,
--               uploaded) makes no difference; a rescan (streaming) does not jump; the live Axis / Sign overrides; the numbers equal the chevrons' own
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local after=MODE~='before'
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return{}end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireServer=function()end end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local Art=server('BiomeVisuals');local Config=server('Config')
local Look=W.module('TreadmillLook151');local Belt=W.module('TreadmillBeltArt151');local Fx=W.module('TreadmillFx')
local passed,failed=0,0
local function check(name,cond,why)
 if cond then passed+=1;if VERBOSE then print('ok '..name)end else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end
end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
-- the client: the local player (FastMode / the belt overrides are its attributes), the chevrons' remote, Roblox's own quality governor stubbed to a tier we set --------------------
local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local stopRemote=R.new('RemoteEvent');stopRemote.Name='StopTreadmillTraining';stopRemote.Parent=remotes
W.service('UserInputService').JumpRequest=R.signal()
function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
local TIER=3
W.stub('ClientFxBudget',{Get=function()return TIER end,Low=function()return TIER==1 end})
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
local function newBase(name,x)
 local base=R.new('Model');base.Name=name;base:SetAttribute('BaseIndex',1)
 local pad=R.new('Part');pad.Name='Pad';pad.Size=V3(118,1,180);pad.CFrame=CF(x,4.5,0);pad.Parent=base
 base.Parent=W.workspace
 return base
end
-- the seven machines (Forest .. Storm = the seven levels, grades low / mid / top) in a row 14 studs apart, all near one camera --------------------------------------------------------
local machines={}
for level=1,7 do
 local base=newBase('Base'..level,(level-1)*14);base.Parent=bases
 Art.TreadmillLook=nil
 local belt=Art.BuildTreadmillV131(base,level,level)
 machines[level]={Base=base,Belt=belt,Art=base.TreadmillArtV131,Level=level}
end
local camera=W.workspace.CurrentCamera
local Gui=W.Gui
local created={}
Belt.Reset()
Belt.Hooks.Create=function(w,h,rgba)created[#created+1]={w,h};return{Fake=true,W=w,H=h,Destroy=function()end}end
Belt.Hooks.Content=function(o)return{ContentOf=o}end
Belt.Hooks.Spawn=function(f)f()end
local stopFx,controller=Fx.Start(player)
W.load('BeltArrows',R.new('LocalScript'))
local function look(at,distance,height)
 local p=at.Position;local eye=p+V3(0,height or 6,distance);camera.CFrame=R.CFrame.lookAt(eye,p)
end
local function lookRow(distance)local sum=V3(0,0,0);for _,m in ipairs(machines)do sum=sum+m.Belt.Position end;local p=sum/#machines;camera.CFrame=R.CFrame.lookAt(p+V3(0,6,distance),p)end -- (the belts sit 75 studs in front of their pads, 14 apart)
local function frames(n,each)for _=1,n do W.frames(1);if each then each()end end end
local function artOf(x)return type(x)=='table'and x.Art or machines[x].Art end -- (a machine or a level)
local function textures(x)local out={};for _,d in ipairs(artOf(x):GetDescendants())do if d.ClassName=='Texture'and d:GetAttribute('BeltImage')then out[#out+1]=d end end;return out end
local function arrowOf(x)for _,d in ipairs(artOf(x):GetDescendants())do if d:IsA('BasePart')and d.Name:find('^ForwardChevron')and d:GetAttribute('TrackMotion')then return d end end end
local writes={}
local function watch(t)if not writes[t]then writes[t]=0;t.Changed:Connect(function(k)if k=='OffsetStudsV'or k=='OffsetStudsU'then writes[t]+=1 end end)end end
-- A tracker: per frame, the unwrapped travel of every layer's offset (along Axis, + = forward as the chevrons' direction is declared) and of the first chevron (forward = -Z).
local function tracker(machine,axis)
 axis=axis or'V'
 local tr={Layers={},Arrow=arrowOf(machine)}
 for _,t in ipairs(textures(machine))do watch(t);tr.Layers[#tr.Layers+1]={T=t,Last=t['OffsetStuds'..axis],Sum=0,Max=0,Period=t['StudsPerTile'..axis],W0=writes[t]}end
 local function lz()return machine.Belt.CFrame:PointToObjectSpace(tr.Arrow.CFrame.Position).Z end -- (in the belt's own space: forward is -Z whatever way the machine faces)
 tr.ArrowLast=tr.Arrow and lz();tr.ArrowSum=0
 function tr.Step()
  for _,l in ipairs(tr.Layers)do
   local o=l.T['OffsetStuds'..axis];local d=o-l.Last;d=(d+l.Period/2)%l.Period-l.Period/2;l.Sum+=d;l.Max=math.max(l.Max,math.abs(d));l.Last=o
  end
  if tr.Arrow then local z=lz();local d=z-tr.ArrowLast;local p=tr.Arrow:GetAttribute('TrackTravel')or 10;d=(d+p/2)%p-p/2;tr.ArrowSum-=d;tr.ArrowLast=z end
 end
 function tr.Writes()local n=0;for _,l in ipairs(tr.Layers)do n+=writes[l.T]-l.W0 end;return n end
 return tr
end
local function settle(seconds)frames(math.floor((seconds or 1.5)*60))end
local function setTraining(on)for _,m in ipairs(machines)do m.Belt:SetAttribute('TrainingActive',on)end end
local function reset(opts)
 opts=opts or{}
 TIER=opts.Tier or 3;player:SetAttribute('FastMode',opts.Fast==true or nil);Gui.ReducedMotionEnabled=opts.Reduced==true
 player:SetAttribute('TreadmillBeltAxis',nil);player:SetAttribute('TreadmillBeltSign',nil)
 setTraining(opts.Training==true);lookRow(opts.Distance or 60);settle(opts.Settle or 1.2)
end
local function arrowsMoved(machine)
 local a=arrowOf(machine);local p0=a.CFrame.Position
 frames(60);return(a.CFrame.Position-p0).Magnitude>.5
end
local function patternMoved(machine)
 local before={};for _,t in ipairs(textures(machine))do before[t]=t.OffsetStudsV end
 frames(60);for t,o in pairs(before)do if t.OffsetStudsV~=o then return true end end;return false
end
settle(2.5)
local ART_READY=true
for _,m in ipairs(machines)do check('level '..m.Level..': the chevrons exist and the belt has pattern layers',arrowOf(m.Level)~=nil and #textures(m.Level)>=1)end

-- the machines tracked by both systems? (the 1 s scans)
do
 reset({Tier=3,Training=true})
 check('the chevrons move on the seven machines (their own code, in this world)',(function()for _,m in ipairs(machines)do if not arrowsMoved(m)then return false end end;return true end)())
end

-- ROOT CAUSE (before) / THE FIX (after): the Studio case, tier 1, and FastMode ---------------------------------------------------------------------------------------------------
local m5=machines[5]
for _,case in ipairs({{'quality tier 1 (ClientFxBudget\'s degrade in Studio)',{Tier=1,Training=true}},{'FastMode',{Tier=3,Fast=true,Training=true}},{'quality tier 2',{Tier=2,Training=true}},{'quality tier 3',{Tier=3,Training=true}}}) do
 reset(case[2])
 local arrows=arrowsMoved(m5);local pattern=patternMoved(m5)
 if after then check('after: '..case[1]..': the chevrons move AND the pattern moves',arrows and pattern,'arrows '..tostring(arrows)..', pattern '..tostring(pattern))
 elseif case[1]:find('tier 1')or case[1]=='FastMode'then check('ROOT CAUSE (R152): '..case[1]..': the chevrons move and the pattern STANDS STILL',arrows and not pattern,'arrows '..tostring(arrows)..', pattern '..tostring(pattern))
 else check('R152: '..case[1]..': both move',arrows and pattern)end
end
if not after then
 -- at tier 3 the glow / stream layers run faster than the chevrons (rate 1.6 / 2.4)
 reset({Tier=3,Training=true});local tr=tracker(machines[7]);frames(120,tr.Step)
 local fast=0;for _,l in ipairs(tr.Layers)do if math.abs(l.Sum)>tr.ArrowSum*1.3 then fast+=1 end end
 check('R152: at tier 3 the top level\'s glow and stream layers travel faster than the chevrons ('..fast..' of '..#tr.Layers..')',fast==2)
 print(('%d passed, %d failed (R152 behaviour measured)'):format(passed,failed))
 if failed>0 then error('FAILED')end
 return
end

-- after ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 1. every machine, every tier, training and idle: every layer travels what the chevrons travel
local rows={}
for _,tier in ipairs({1,2,3})do for _,training in ipairs({true,false})do
 reset({Tier=tier,Training=training});local trs={};for _,m in ipairs(machines)do trs[m.Level]=tracker(m)end
 frames(180,function()for _,tr in pairs(trs)do tr.Step()end end) -- 3 s
 local speed=training and Look.Scroll.Training or Look.Scroll.Idle
 for level,tr in ipairs(trs)do
  local ok=near(tr.ArrowSum,speed*3,.35)
  check(('level %d tier %d %s: the chevrons travel %.2f studs in 3 s (%.1f / s)'):format(level,tier,training and'training'or'idle',tr.ArrowSum,speed),ok)
  for i,l in ipairs(tr.Layers)do
   check(('level %d tier %d %s: layer %d (%s) travels %.2f studs in 3 s = the chevrons\' %.2f'):format(level,tier,training and'training'or'idle',i,l.T.Name,l.Sum,tr.ArrowSum),near(l.Sum,tr.ArrowSum,.35)and l.Sum>0)
  end
 end
 rows[#rows+1]=('tier %d %s: every layer of the 7 machines travelled %.1f studs in 3 s like the chevrons'):format(tier,training and'training'or'idle',speed*3)
end end
-- 2. many wraps, no jump
do
 reset({Tier=2,Training=true});local trs={};for _,m in ipairs(machines)do trs[m.Level]=tracker(m)end
 frames(720,function()for _,tr in pairs(trs)do tr.Step()end end) -- 12 s = 36 studs: several wraps of every tile (1.6 .. 5.12 studs)
 local worst,inside,laps=0,true,math.huge
 for level,tr in pairs(trs)do for _,l in ipairs(tr.Layers)do
  worst=math.max(worst,l.Max);if l.T.OffsetStudsV<0 or l.T.OffsetStudsV>=l.Period then inside=false end;laps=math.min(laps,l.Sum/l.Period)
  check(('level %d %s: 36 studs over %.1f tiles, no drift (%.2f)'):format(level,l.T.Name,l.Sum/l.Period,l.Sum),near(l.Sum,36,.45))
 end end
 check('no jump at a wrap: the biggest step of a frame is one tick of travel ('..string.format('%.3f',worst)..' studs, a 1/20 s tick is .15)',worst<=.16)
 check('the offsets stay inside their tile (0 .. StudsPerTileV)',inside)
 check('every layer wrapped at least 6 times in 12 s ('..string.format('%.1f',laps)..' tiles at least)',laps>=6)
end
-- 3. the pattern moves exactly where and when the chevrons move
do
 local rowsT={}
 for _,fast in ipairs({false,true})do for _,d in ipairs({40,85,95,135,145})do
  reset({Tier=2,Fast=fast,Training=true,Distance=d,Settle=1.2})
  look(m5.Belt,d)
  settle(.6)
  local arrows=arrowsMoved(m5);local pattern=patternMoved(m5)
  check(('%s, %d studs away: the pattern moves exactly when the chevrons do (chevrons %s, pattern %s)'):format(fast and'FastMode'or'normal',d,tostring(arrows),tostring(pattern)),arrows==pattern)
  rowsT[#rowsT+1]=('%s %d: %s'):format(fast and'F'or'N',d,arrows and'moving'or'still')
 end end
 -- (the chevrons' reach: 140 studs, 90 in FastMode: the numbers the belt uses are the same)
 local src=io and io.open and nil
end
-- 4. Reduced Motion: the chevrons keep moving (their code ignores it), the pattern stays still on purpose (the R151 rule of a moving effect)
do
 reset({Tier=3,Reduced=true,Training=true});look(m5.Belt,40);settle(.6)
 check('Reduced Motion: the pattern stands still (the chevrons keep going)',arrowsMoved(m5)and not patternMoved(m5))
 Gui.ReducedMotionEnabled=false
end
-- 5. a write only when the offset changed
do
 reset({Tier=2,Training=true});local tr=tracker(m5);frames(120,tr.Step)
 local n=tr.Writes();local layers=#tr.Layers
 check(('2 s of scroll: %d writes for %d layers (at most 30 a second each, at least one a tick)'):format(n,layers),n>=layers*20 and n<=layers*60)
 -- belt standing: no write at all (dt 0, far, Reduced Motion)
 local record;for _,r in pairs(controller.Records)do if r.Belt==m5.Belt then record=r end end
 check('the controller tracks the machine (a record with its layers)',record~=nil and #record.Lists.Textures==layers)
 local w0=tr.Writes();controller:Scroll(record,0);controller:Scroll(record,0)
 check('a tick of no time writes nothing (the offsets did not change)',tr.Writes()==w0)
 lookRow(60);look(m5.Belt,400);settle(.6);local w1=tr.Writes();frames(60,tr.Step)
 check('far away: no write',tr.Writes()==w1)
 reset({Tier=3,Reduced=true,Training=true});look(m5.Belt,40);settle(.6);w1=tr.Writes();frames(60,tr.Step)
 check('Reduced Motion: no write',tr.Writes()==w1);Gui.ReducedMotionEnabled=false
end
-- 6. whichever route drew the belt: generated (EditableImage), grid (no EditableImage), pending (not drawn yet), uploaded. (The controller paints a machine on its first scan with the
--    hooks it finds then, so each route's machine is built and painted before the next one's hooks are set.)
do
 local function routeMachine(level,x,name,hooks)
  hooks()
  local base=newBase(name,x);base.Parent=bases
  Art.TreadmillLook=nil;local belt=Art.BuildTreadmillV131(base,level,level)
  local m={Base=base,Belt=belt,Art=base.TreadmillArtV131,Level=level}
  reset({Tier=2,Training=true});look(belt,50);settle(2)
  return m
 end
 local function routeOf(m)local r={};for _,t in ipairs(textures(m))do r[t:GetAttribute('BeltRoute')or'?']=true end;return r end
 local g=routeOf(machines[6])
 check('route generated: the layers of the seven machines carry an EditableImage content',g.generated==true and next(g,'generated')==nil)
 local gridM=routeMachine(4,200,'RouteGrid',function()Belt.Reset();Belt.Hooks.Create=function()error('EditableImage budget')end;Belt.Hooks.Spawn=function(f)f()end;Look.Images.slats=''end)
 local pendM=routeMachine(3,230,'RoutePending',function()Belt.Reset();Belt.Hooks.Create=function(w,h)return{Fake=true}end;Belt.Hooks.Spawn=function(f)end end)
 local upM=routeMachine(2,260,'RouteUp',function()Belt.Reset();Belt.Hooks.Create=function(w,h)return{Fake=true}end;Belt.Hooks.Spawn=function(f)f()end;Look.Images.slats='rbxassetid://424242' end)
 local grid,pend,up=routeOf(gridM),routeOf(pendM),routeOf(upM)
 check("route grid (no EditableImage): the layers carry the place's grid texture",grid.grid==true and next(grid,'grid')==nil)
 check('route pending (the image is not drawn yet): the layers wait',pend.pending==true and next(pend,'pending')==nil)
 check('route uploaded: the Slats layer carries the uploaded id',up.uploaded==true)
 for _,pair in ipairs({{'grid',gridM},{'pending',pendM},{'uploaded',upM}})do
  local name,m=pair[1],pair[2]
  look(m.Belt,50);m.Belt:SetAttribute('TrainingActive',true);settle(.8);local tr=tracker(m);frames(120,tr.Step)
  local ok=#tr.Layers>0;for _,l in ipairs(tr.Layers)do if not near(l.Sum,tr.ArrowSum,.35)or l.Sum<=0 then ok=false end end
  check('route '..name..': every layer travels with the chevrons ('..#tr.Layers..' layers, '..string.format('%.2f',tr.ArrowSum)..' studs in 2 s)',ok and near(tr.ArrowSum,6,.35))
 end
 Look.Images.slats='';Belt.Reset();Belt.Hooks.Create=function(w,h)created[#created+1]={w,h};return{Fake=true,W=w,H=h,Destroy=function()end}end;Belt.Hooks.Spawn=function(f)f()end
 for _,m in ipairs({gridM,pendM,upM})do m.Base:Destroy()end
 settle(1.2)
end
-- 7. a rescan (a streamed-in part) keeps the pattern going: no jump
do
 reset({Tier=2,Training=true});look(m5.Belt,40);settle(.6)
 local tr=tracker(m5);frames(30,tr.Step)
 local extra=R.new('Part');extra.Name='StreamedIn';extra.Parent=m5.Art
 frames(90,tr.Step)
 local worst=0;local sum=0;for _,l in ipairs(tr.Layers)do worst=math.max(worst,l.Max);sum=math.max(sum,l.Sum)end
 check('a streamed-in part (rescan of the machine) does not make the pattern jump (biggest step '..string.format('%.3f',worst)..')',worst<=.16)
 check('... and it keeps travelling ('..string.format('%.2f',sum)..' studs in 2 s)',near(sum,6,.4))
 extra:Destroy();settle(.5)
end
-- 8. live overrides: the player's TreadmillBeltSign / TreadmillBeltAxis (Studio) and what is ignored
do
 reset({Tier=2,Training=true});look(m5.Belt,40);settle(.6)
 player:SetAttribute('TreadmillBeltSign',-1);settle(.6)
 local tr=tracker(m5);frames(120,tr.Step)
 local back=#tr.Layers>0;for _,l in ipairs(tr.Layers)do if not near(l.Sum,-tr.ArrowSum,.4)then back=false end end
 check('TreadmillBeltSign = -1 (set in Studio): the pattern runs the other way, the chevrons do not',back and tr.ArrowSum>5)
 player:SetAttribute('TreadmillBeltSign',2);player:SetAttribute('TreadmillBeltAxis','X');settle(.6)
 tr=tracker(m5);frames(120,tr.Step)
 local fwd=true;for _,l in ipairs(tr.Layers)do if not near(l.Sum,tr.ArrowSum,.4)then fwd=false end end
 check('a value that is not 1 / -1 or U / V is ignored (back to the designed direction and axis)',fwd)
 player:SetAttribute('TreadmillBeltSign',nil);player:SetAttribute('TreadmillBeltAxis','U');settle(.6)
 local u={};for _,t in ipairs(textures(5))do u[t]=t.OffsetStudsU end
 local v={};for _,t in ipairs(textures(5))do v[t]=t.OffsetStudsV end
 frames(60);local moved,still=true,true
 for t,o in pairs(u)do if t.OffsetStudsU==o then moved=false end end
 for t,o in pairs(v)do if t.OffsetStudsV~=o then still=false end end
 check('TreadmillBeltAxis = U: the U offset runs, the V offset stays',moved and still)
 local record;for _,r in pairs(controller.Records)do if r.Belt==m5.Belt then record=r end end
 local base0=record~=nil;if record then for _,e in ipairs(record.Lists.Textures)do if e.Inst.OffsetStudsV~=e.BaseV then base0=false end end end
 check('(the axis that stopped is back at its base offset)',base0)
 player:SetAttribute('TreadmillBeltAxis',nil);settle(.6)
end
-- 9. the numbers are the chevrons' own
do
 local f=io and io.open;local text
 local ok=pcall(function()text=require('./rs_bundle').BeltArrows end)
 check('the chevrons\' code is bundled',ok and type(text)=='string')
 check('the chevrons advance 3.0 studs a second training, 1.3 idle: Look.Scroll says the same',text:find("record.Distance+=step*(belt:GetAttribute('TrainingActive')and 3.0 or 1.3)",1,true)~=nil and Look.Scroll.Training==3.0 and Look.Scroll.Idle==1.3)
 check('the chevrons reach 140 studs (90 in FastMode): Look.Scroll says the same',text:find("local near=distance<(low and 90 or 140)",1,true)~=nil and Look.Scroll.Range==140 and Look.Scroll.RangeFast==90 and Fx.SCROLL.Range==140 and Fx.SCROLL.RangeFast==90 and Fx.SCROLL.Training==3.0 and Fx.SCROLL.Idle==1.3)
 local rates=true;for _,biome in ipairs(Look.Biome)do for _,grade in ipairs({'low','mid','top'})do for _,layer in ipairs(Look.Layers(biome,grade))do if layer.Rate~=1 then rates=false end end end end
 check('every belt layer of every biome runs at the chevrons\' speed (rate 1: one rigid belt)',rates)
 check('the designed axis is V and the direction +1 (the chevrons run to -Z, forward)',Look.Scroll.Axis=='V'and Look.Scroll.Sign==1)
end
stopFx()
print(('%d passed, %d failed'):format(passed,failed))
for _,r in ipairs(rows)do print('  '..r)end
if failed>0 then error('FAILED')end
