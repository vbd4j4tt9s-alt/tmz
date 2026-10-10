--!nocheck
-- R158 bats, BUILT: the hit effects on the Roblox mock with the REAL KeeperHitEffects + HitBurstFx of this checkout (LocalSfx is a recorder).
--  1. the contact star: today's look (8 rays, the warm colour, The Darkened's purple), now from a pool of 4 made once: 12 hits in a row make 4 stars,
--     never more; a star flies out and hides after .26 s; nothing is made while stars animate (no instance per frame)
--  2. the sparks: one shared emitter, Emit(10) on a bat hit; none for a keeper hit; none in Fast Mode or on a low-graphics device
--  3. your own bat hit (HitBurstFx.NoteOwnHit, done by BatClient at once): the server's packet for that victim is skipped for 1.5 s (no second slap,
--     no star, no camera shake); a keeper hit on the same player and a later bat hit are shown as before
--  4. keeper hits keep their sounds and their shake; the victim's flash / red edges as before
local W=require('./world');local E=require('./sfx_env')(W);local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS;W.env.bit32=bit32
local sfx={Log={},WhooshId='rbxassetid://9120768742'}
function sfx.Play(id,pos,vol,pitch,life,skip)sfx.Log[#sfx.Log+1]={Id=id,Pos=pos};return true end
function sfx.Preload()end
function sfx.count(id)local n=0;for _,e in ipairs(sfx.Log)do if not id or e.Id==id then n+=1 end end;return n end
W.stub('LocalSfx',sfx)
local emits=0;R.Inst.Emit=function(self,n)if self.Parent and self.Parent.Name=='BatHitSparks'then emits+=(n or 1)end end -- (the bat's sparks only; keeper dust emits too)
E.player('Viewer')
local player=E.Player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local hitRemote=R.Instance.new('RemoteEvent');hitRemote.Name='KeeperHit';hitRemote.Parent=remotes
local Bat=W.module('BatConfig');local Burst=W.module('HitBurstFx')
local camera=W.workspace.CurrentCamera;camera.CFrame=CF(0,10,-60)
local kh=R.new('LocalScript');kh.Name='KeeperHitEffects';local ok,err=pcall(W.load,'KeeperHitEffects',kh);check(ok,'KeeperHitEffects loads: '..tostring(err))
local function frame(dt)
 dt=dt or 1/60;R.advance(dt);W.Run.RenderStepped:Fire(dt)
 local list=table.clone(W.rsOrder);table.sort(list,function(a,b)return W.rsBound[a].Prio<W.rsBound[b].Prio end)
 for _,n in ipairs(list)do local b=W.rsBound[n];if b then b.Fn(dt)end end
end
local function frames(n)for _=1,n do frame()end end
local id=0
local function hit(t)id+=1;t.Id=id;t.At=W.workspace:GetServerTimeNow();t.Position=t.Position or V3(0,3,0);hitRemote.OnClientEvent:Fire(t)end
local function stars()local n,live=0,0;for _,o in ipairs(W.workspace:GetChildren())do if o.Name=='KeeperHitBurst'then n+=1;if o.ContactStar.Enabled then live+=1 end end end;return n,live end
frames(3)
-- 1. the star pool
hit({VictimUserId=50,Cause='Bat'})
local n,live=stars()
local first=W.workspace:FindFirstChild('KeeperHitBurst')
local rays=first and first.ContactStar:GetChildren()
check(n==1 and live==1 and rays and #rays==8,'a hit shows the 8-ray contact star')
check(rays and rays[1].BackgroundColor3.R==1 and math.abs(rays[1].BackgroundColor3.G-232/255)<1e-6,'... in today\'s warm colour')
for _=1,11 do hit({VictimUserId=50,Stage=2});frame()end
n,live=stars()
check(n==4,'12 hits in a row: a pool of 4 stars, never more ('..n..')')
local mark=#R.created
frames(30)
n,live=stars()
check(live==0,'the stars fly out and hide after .26 s (none left showing)')
check(#R.created==mark,'nothing is made while the stars animate ('..(#R.created-mark)..' new instances)')
mark=#R.created
for _=1,6 do hit({VictimUserId=50,Cause='Bat'});frame()end
check(#R.created==mark,'more hits reuse the pool: nothing new is made ('..(#R.created-mark)..')')
hit({VictimUserId=50,Stage=7,Veiled=true})
local purple=false;for _,o in ipairs(W.workspace:GetChildren())do if o.Name=='KeeperHitBurst'and o.ContactStar.Enabled then local r=o.ContactStar:GetChildren()[1];if r.BackgroundColor3.B>r.BackgroundColor3.G then purple=true end end end
check(purple,'The Darkened\'s catch: its star is purple, as before')
frames(30)
-- 2. the sparks
emits=0;hit({VictimUserId=50,Cause='Bat'})
check(emits==Burst.SparkCount and W.workspace:FindFirstChild('BatHitSparks')~=nil,'a bat hit: one Emit('..Burst.SparkCount..') from the shared spark emitter')
emits=0;hit({VictimUserId=50,Stage=3});check(emits==0,'a keeper hit: no bat sparks')
local sparkParts=0;for _,o in ipairs(W.workspace:GetChildren())do if o.Name=='BatHitSparks'then sparkParts+=1 end end
hit({VictimUserId=50,Cause='Bat'});frames(2)
local after=0;for _,o in ipairs(W.workspace:GetChildren())do if o.Name=='BatHitSparks'then after+=1 end end
check(sparkParts==1 and after==1,'one shared spark emitter, made once')
player:SetAttribute('FastMode',true);emits=0;hit({VictimUserId=50,Cause='Bat'})
check(emits==0,'Fast Mode: no sparks');player:SetAttribute('FastMode',nil)
do local budget=W.module('ClientFxBudget');local low=budget.Low;budget.Low=function()return true end
 emits=0;hit({VictimUserId=50,Cause='Bat'});check(emits==0,'a low-graphics device (ClientFxBudget.Low): no sparks');budget.Low=low end
frames(30)
-- 3. your own hit
R.advance(3);frames(2)
Burst.NoteOwnHit(88);sfx.Log={}
local base=camera.CFrame
local _,liveBefore=stars()
hit({VictimUserId=88,Cause='Bat',Position=V3(0,3,-55)})
local _,liveAfter=stars();frames(6)
check(sfx.count(Bat.SlapSoundId)==0 and liveAfter==liveBefore and(camera.CFrame.Position-base.Position).Magnitude<1e-9,'the server\'s packet of YOUR bat hit (noted at once by BatClient): no second slap, no star, no camera shake')
hit({VictimUserId=88,Stage=4,Position=V3(0,3,-55)})
check(sfx.count()>0,'a keeper hit on that same player is shown as before')
R.advance(1.6);frames(2);sfx.Log={}
hit({VictimUserId=88,Cause='Bat',Position=V3(0,3,-55)})
check(sfx.count(Bat.SlapSoundId)==1,'1.5 s later a bat hit on that player is someone else\'s: shown as before (the slap)')
-- 4. the victim
R.advance(3);frames(2);base=camera.CFrame
local flash=E.pg.KeeperImpactFeedback.ImpactFlash;local minFlash=1
hit({VictimUserId=player.UserId,Cause='Bat',Position=V3(0,3,-58)})
local moved=false;for _=1,6 do frame();minFlash=math.min(minFlash,flash.BackgroundTransparency);if (camera.CFrame.Position-base.Position).Magnitude>1e-6 then moved=true end end
check(moved and minFlash<1,'the one who is hit: camera shake and the flash, as before')
frames(30)
check(flash.BackgroundTransparency==1,'... and it clears')
kh.Destroying:Fire()
print(string.format('hit effects: %d checks, %d failed',checks,fails))
if fails>0 then error('hit effects test failed')end
