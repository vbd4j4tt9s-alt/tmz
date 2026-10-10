--!nocheck
-- R158 LavaFlow (StarterPlayerScripts/LavaFlow.client.lua): the Lava biome has no lava streams or pools any more (owner: "yes remove the streams entirely" / "and the lava pool").
-- The script only serves routes and pools, so with none it must do NOTHING per frame (no RenderStepped connection at all), start stepping when one shows up (a stream streamed in, an
-- older place that still has them) and let the frame step go again when the last one is gone. Its glows still move exactly as before when there is a route (R153's jitter suite checks
-- the motion itself). Prints "ok" / "FAIL" lines; errors at the end if anything failed.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local passed,failed=0,0
local function check(name,cond,why)if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end end
local Run=W.Run
function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end -- (the engine's bulk move: the glows' new places)
local function connected(sig)local n=0;for _,c in ipairs(sig._c)do if c.Connected then n+=1 end end;return n end
local map=R.new('Folder');map.Name='ChestChaseMap';map:SetAttribute('RoutesExpandedV134',true);map.Parent=W.workspace
local function route(x)
 local m=R.new('Model');m.Name='LavaRoute';m:SetAttribute('LavaRouteV128',true);m:SetAttribute('NodeCount',3)
 m:SetAttribute('Node1',V3(x,0,0));m:SetAttribute('Node2',V3(x,1,20));m:SetAttribute('Node3',V3(x+5,0,40));m:SetAttribute('FlowSpeed',7)
 for i=1,4 do local p=R.new('Part');p.Name='Glow'..i;p:SetAttribute('FlowPhase',i/4);p.Parent=m end
 return m
end
local function pool()
 local m=R.new('Model');m.Name='Pool';m:SetAttribute('MagmaPoolV127',true);m:SetAttribute('PoolCenter',V3(0,0,0));m:SetAttribute('PoolRadii',V3(5,0,5))
 local s=R.new('Part');s.Name='MagmaSurface';s:SetAttribute('MagmaPulse',1);s.Parent=m
 return m
end
-- 1. nothing on the map ---------------------------------------------------------------------------------------------------------------------------
local sc=R.new('LocalScript');sc.Name='LavaFlow';W.load('LavaFlow',sc)
check('none: with no stream and no pool the script keeps no RenderStepped connection (nothing runs per frame)',connected(Run.RenderStepped)==0,connected(Run.RenderStepped))
W.frames(120)
check('none: still none after two seconds of frames',connected(Run.RenderStepped)==0)
-- 2. a route shows up (a stream streams in / an old place) -----------------------------------------------------------------------------------------
local m=route(0);m.Parent=map
check('route: a route that appears wakes the frame step',connected(Run.RenderStepped)==1,connected(Run.RenderStepped))
local g=m:FindFirstChild('Glow1');local c0=g.CFrame
W.frames(20)
check('route: and its glows flow down it as before (the glow moved)',g.CFrame.Position.Z~=c0.Position.Z or g.CFrame.Position.X~=c0.Position.X)
-- 3. it goes away ------------------------------------------------------------------------------------------------------------------------------------
m:Destroy();W.frames(3)
check('route: when the last route is gone the frame step lets go again',connected(Run.RenderStepped)==0,connected(Run.RenderStepped))
-- 4. a pool ------------------------------------------------------------------------------------------------------------------------------------------
local p=pool();p.Parent=map
check('pool: a pool wakes the step too',connected(Run.RenderStepped)==1,connected(Run.RenderStepped))
p:Destroy();W.frames(8)
check('pool: and it lets go when the pool is gone',connected(Run.RenderStepped)==0,connected(Run.RenderStepped))
-- 5. once more (wake / sleep cycles never stack connections) ----------------------------------------------------------------------------------
local a=route(0);a.Parent=map;local b=route(220);b.Parent=map
check('again: two routes, still one connection',connected(Run.RenderStepped)==1)
a:Destroy();b:Destroy();W.frames(3);local c=route(0);c.Parent=map
check('again: sleep then wake: one connection, not two',connected(Run.RenderStepped)==1,connected(Run.RenderStepped))
c:Destroy();W.frames(8)
check('again: and none left at the end',connected(Run.RenderStepped)==0,connected(Run.RenderStepped))
sc:Destroy()
-- 6. a route already there when the script starts ----------------------------------------------------------------------------------------------
map.Name='ChestChaseMapOld' -- (the first script stays bound to the old folder: a destroyed script's connections live on in the mock)
local map2=R.new('Folder');map2.Name='ChestChaseMap';map2:SetAttribute('RoutesExpandedV134',true);map2.Parent=W.workspace
local early=route(0);early.Parent=map2
local sc2=R.new('LocalScript');sc2.Name='LavaFlow';W.load('LavaFlow',sc2)
check('early: a route that was there before the script started is picked up and stepped',connected(Run.RenderStepped)==1,connected(Run.RenderStepped))
local eg=early:FindFirstChild('Glow1');local e0=eg.CFrame.Position
W.frames(30)
check('early: its glows move',eg.CFrame.Position.Z~=e0.Z or eg.CFrame.Position.X~=e0.X)
print('R158 LavaFlow: '..passed..' checks passed, '..failed..' failed')
if failed>0 then error('R158 LavaFlow: '..failed..' checks failed')end
