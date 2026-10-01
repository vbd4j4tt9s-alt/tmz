--!nocheck
-- R121 micro-check: LavaFlow glow/crust poses identical to the baseline, with one BulkMoveTo per tick.
local W=require('./keeper_world');local Mx=W.Mx;local CF,V=Mx.CFrame,Mx.Vector3.new
local function runOne(which)
 local world=W.new(require('./lava_'..which),{})
 local map=W.R.new('Folder');map.Name='ChestChaseMap';map:SetAttribute('RoutesExpandedV134',true);map.Parent=world.Workspace
 local routes={}
 for k,tag in ipairs({'LavaRouteV092','LavaRouteV128'})do
  local m=W.R.new('Model');m:SetAttribute(tag,true);m:SetAttribute('NodeCount',3);m:SetAttribute('Node1',V(k*10,0,0));m:SetAttribute('Node2',V(k*10,1,20));m:SetAttribute('Node3',V(k*10+5,0,40));m:SetAttribute('FlowSpeed',7)
  for i=1,4 do local p=W.R.new('Part');p.Name='Glow'..i;p:SetAttribute('FlowPhase',i/4);p.Parent=m end
  m.Parent=map;table.insert(routes,m)
 end
 local pool=W.R.new('Model');pool:SetAttribute('MagmaPoolV127',true);pool:SetAttribute('PoolCenter',V(0,0,10));pool:SetAttribute('PoolRadii',V(8,1,8))
 pool.Parent=map
 for i=1,3 do local p=W.R.new('Part');p:SetAttribute('MagmaRest',CF.new(i,0,10));p:SetAttribute('MagmaDrift',i*.7);p.Parent=pool end
 world.Workspace.CurrentCamera.CFrame=CF.new(0,10,20)
 local bulk=0;local raw=world.Workspace.BulkMoveTo;world.Workspace.BulkMoveTo=function(...)bulk+=1;return raw(...)end
 local mt=getmetatable(pool);local rawNew=mt.__newindex;local writes=0
 mt.__newindex=function(o,k,v)if k=='CFrame'and o.Name:sub(1,4)=='Glow'then writes+=1 end;return rawNew(o,k,v)end
 world.run('LavaFlow')
 local ticks=0
 for i=1,240 do world.step(1/60)end
 local out={}
 for _,m in ipairs(routes)do for i=1,4 do local p=m:FindFirstChild('Glow'..i);local q=p.CFrame.Position;table.insert(out,string.format('%.4f,%.4f,%.4f/%.3f',q.X,q.Y,q.Z,p.Transparency))end end
 for _,p in ipairs(pool:GetChildren())do local q=p.CFrame.Position;table.insert(out,string.format('%.4f,%.4f,%.4f',q.X,q.Y,q.Z))end
 mt.__newindex=rawNew
 return table.concat(out,' '),bulk,writes
end
local a,ba,wa=runOne('base');local b,bb,wb=runOne('new')
print('poses identical',a==b,'| over 240 frames: BulkMoveTo base',ba,'new',bb,'| single glow CFrame writes base',wa,'new',wb)
if a~=b then print(a);print(b)end
