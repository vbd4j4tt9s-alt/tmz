--!nocheck
-- Server contact part sets unchanged by the finish pass; hit-effects ring/dust smoke run; effect pools bounded.
local W=require('./world');local Mx=W.Mx;local CF,V=Mx.CFrame,Mx.Vector3.new
local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local function contactSet(bundleName,stage)
 local world=W.new(require('./bundle_'..bundleName),{})
 local rig=world.require('KeeperUpgradeArt').Build(stage);local out={}
 for _,p in ipairs(rig:GetDescendants())do if p:IsA('BasePart')and p.Transparency<.95 and p.Size.Magnitude>.15 then table.insert(out,p.Name..tostring(p:GetAttribute('RestCFrame').Position)..tostring(p.Size))end end
 table.sort(out);return out,rig
end
for _,stage in ipairs({1,5,7})do
 local a=contactSet('base',stage);local b,rig=contactSet('new',stage)
 check(#a==#b and table.concat(a,'|')==table.concat(b,'|'),stage..' contact part set identical ('..#a..' vs '..#b..')')
 local mats={};for _,p in ipairs(rig:GetChildren())do mats[p.Material.Name]=(mats[p.Material.Name]or 0)+1 end
 local t={};for k,v in pairs(mats)do table.insert(t,k..'='..v)end;table.sort(t);print(stage,'materials',table.concat(t,' '))
end
-- Refinish on an already dressed (saved) rig is idempotent and keeps geometry.
do local world=W.new(require('./bundle_new'),{});local Art=world.require('KeeperUpgradeArt')
 local rig=Art.Build(1);local before={};for _,p in ipairs(rig:GetChildren())do before[p]=tostring(p.CFrame.Position)..tostring(p.Size)end
 Art.Refinish(rig,1);Art.Refinish(rig,1);local ok=true
 for _,p in ipairs(rig:GetChildren())do if before[p]~=tostring(p.CFrame.Position)..tostring(p.Size)then ok=false end end
 check(ok,'refinish keeps geometry')
end
-- KeeperHitEffects: ring + dust, pools bounded, cleanup on script destroy.
do
 local world=W.new(require('./bundle_new'),{LocalSfx={Preload=function()end,Play=function()end},BatConfig={SlapSoundId='x',SlapVolume=1},
  KeeperAudio={Asset=function()return nil end,Voice=function()return nil,0,1 end,ImpactVolume=.4},ClientFxBudget={Low=function()return false end}})
 local remotes=W.R.new('Folder');remotes.Name='ChestChaseRemotes';local ev=W.R.new('RemoteEvent');ev.Name='KeeperHit';ev.OnClientEvent=W.R.signal();ev.Parent=remotes;remotes.Parent=world.RS
 local pg=W.R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=world.Player
 local sc=world.run('KeeperHitEffects')
 for i=1,12 do ev.OnClientEvent:Fire({Id=i,Position=V(0,3,-40),At=world.Now,Stage=(i%7)+1,VictimUserId=i==3 and 77 or 1});world.step(1/30)end
 local folder=world.Workspace:FindFirstChild('KeeperFxLocal');check(folder~=nil,'fx folder made')
 local rings=0;for _,p in ipairs(folder:GetChildren())do if p.Name=='KeeperFxRing'then rings+=1 end end
 check(rings>=1 and rings<=6,'ring pool bounded ('..rings..')')
 check(W.emitted>0,'hit dust emitted ('..W.emitted..')')
 for _=1,60 do world.step(1/30)end
 local visible=0;for _,p in ipairs(folder:GetChildren())do if p.Name=='KeeperFxRing'and p.Transparency<1 then visible+=1 end end
 check(visible==0,'rings fade out')
 -- camera shake leaves the camera where the camera script put it
 local cam=world.Workspace.CurrentCamera;local base=CF.new(1,2,3);cam.CFrame=base
 world.require('KeeperFx').Shake(1);world.step(1/60)
 local shaken=cam.CFrame;local list={};for _,b in pairs(world.Bound)do if b.P<6 then table.insert(list,b)end end
 table.sort(list,function(a,b)return a.P<b.P end);for _,b in ipairs(list)do b.F(1/60)end
 check((cam.CFrame.Position-base.Position).Magnitude<1e-6,'shake offset removed before next camera update')
 check((shaken.Position-base.Position).Magnitude>0,'shake applied')
 sc.Destroying:Fire()
end
print(('side checks %d, fails %d'):format(checks,fails))
