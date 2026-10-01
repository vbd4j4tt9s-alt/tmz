--!nocheck
-- R121 micro-check: KeeperHitEffects overlay writes while idle, and the victim flash still plays and clears.
local W=require('./keeper_world');local Mx=W.Mx;local V=Mx.Vector3.new
local which=...
local world=W.new(require('./bundle_'..which),{LocalSfx={Preload=function()end,Play=function()end},BatConfig={SlapSoundId='x',SlapVolume=1},
 KeeperAudio={Asset=function()return nil end,Voice=function()return nil,0,1 end,ImpactVolume=.4},ClientFxBudget={Low=function()return false end}})
local remotes=W.R.new('Folder');remotes.Name='ChestChaseRemotes';local ev=W.R.new('RemoteEvent');ev.Name='KeeperHit';ev.OnClientEvent=W.R.signal();ev.Parent=remotes;remotes.Parent=world.RS
local pg=W.R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=world.Player
world.run('KeeperHitEffects')
local gui=pg:FindFirstChild('KeeperImpactFeedback');local flash=gui:FindFirstChild('ImpactFlash')
local writes=0;local mt=getmetatable(flash);local raw=mt.__newindex
mt.__newindex=function(o,k,v)if k=='BackgroundTransparency'and(o==flash or o.Parent==gui)then writes+=1 end;return raw(o,k,v)end
for _=1,600 do world.step(1/60)end
print(which,'idle 600 frames: overlay writes',writes)
writes=0;local minFlash=1
ev.OnClientEvent:Fire({Id=1,Position=V(0,3,-40),At=world.Now,Stage=2,VictimUserId=77})
for _=1,60 do world.step(1/60);minFlash=math.min(minFlash,flash.BackgroundTransparency)end
print(which,'victim hit: flash min transparency',string.format('%.3f',minFlash),'final',flash.BackgroundTransparency,'writes',writes)
