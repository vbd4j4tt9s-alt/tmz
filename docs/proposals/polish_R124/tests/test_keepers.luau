--!nocheck
-- R124 keeper audio/FX: ground-smash keepers (Forest hammer, Jungle slam) play 73468358342062 at the visual impact
-- (real KeeperFx.Slam); a confirmed hit then skips the generic snap in range; punches/swipes unchanged; The Darkened's
-- catch plays 119010321306307 with a purple sci-fi impact (real KeeperHitEffects).
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me;me.CharacterRemoving=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.service('SoundService');W.service('ContentProvider').PreloadAsync=function()end;W.service('Debris').AddItem=function()end
W.Run.BindToRenderStep=function(_,name,_,fn)W.Run['_'..name]=fn end;W.Run.UnbindFromRenderStep=function()end
local played={};local preload={}
W.stub('LocalSfx',{Play=function(id,pos,vol,pitch,life)played[#played+1]={Id=id,Pos=pos,Vol=vol};return true end,Preload=function(ids)for _,i in ipairs(ids)do preload[i]=true end end})
local GROUND,VEIL,SNAP='rbxassetid://73468358342062','rbxassetid://119010321306307','rbxassetid://138131702183716'
local function count(id)local n=0;for _,p in ipairs(played)do if p.Id==id then n+=1 end end;return n end
-- 1) Real KeeperFx.Slam: ground-smash moves play the slam sound at the strike point, others do not.
local KFx=W.module('KeeperFx');local Sig=W.module('KeeperSignatureStrike')
check(Sig.Moves[1].Ground and Sig.Moves[6].Ground and not Sig.Moves[2].Ground and not Sig.Moves[3].Ground and not Sig.Moves[4].Ground and not Sig.Moves[5].Ground and not Sig.Moves[7].Ground,'only the Forest hammer and Jungle slam smash the ground')
for _,stage in ipairs({1,2,3,4,5,6,7})do
 local root=R.new('Part');root.Name='Root';root.CFrame=CF(0,6,0);root.Parent=W.workspace
 local ok,fx=pcall(KFx.new,root,stage);check(ok and fx,'KeeperFx.new stage '..stage..': '..tostring(fx))
 if ok and fx then
  table.clear(played)
  local ok2,err=pcall(KFx.Slam,fx,{Distance=20,LocalDistance=20,Frame=CF(0,6,0),Low=false,Now=R.clock})
  check(ok2,'Slam runs for stage '..stage..': '..tostring(err))
  local want=(stage==1 or stage==6)and 1 or 0
  check(count(GROUND)==want,('stage %d: ground-slam sound %d (want %d)'):format(stage,count(GROUND),want))
  if want==1 then check(played[1].Pos.Y<6,'slam sound at ground level under the strike')end
  table.clear(played);pcall(KFx.Slam,fx,{Distance=500,Frame=CF(0,6,0),Low=false,Now=R.clock});check(count(GROUND)==0,'no slam sound beyond the effect range')
 end
end
check(preload[GROUND]==true,'ground-slam sound preloaded')
-- 2) Real KeeperHitEffects
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local hitRemote=R.Instance.new('RemoteEvent');hitRemote.Name='KeeperHit';hitRemote.OnClientEvent=R.signal();hitRemote.Parent=remotes
W.workspace.CurrentCamera.CFrame=CF(0,10,-20)
W.load('KeeperHitEffects',R.new('LocalScript'))
check(preload[VEIL]==true,'Darkened catch sound preloaded')
local id=0
local function hit(t)id+=1;t.Id=id;t.At=W.workspace:GetServerTimeNow();table.clear(played);hitRemote.OnClientEvent:Fire(t)end
hit({Position=V3(0,3,0),Stage=6,VictimUserId=99})
check(count(SNAP)==0,'Jungle slam hit in range: no extra snap (slam sound already played at the impact)')
hit({Position=V3(0,3,0),Stage=1,VictimUserId=99})
check(count(SNAP)==0,'Forest hammer hit in range: no extra snap')
-- R150: the slam SOUND is heard out to LocalSfx's range (260), not only the 120-stud effect range, and the generic snap is skipped exactly when that
-- slam was heard (KeeperFx.SlamHeard, 1.5 s): near the old 120 border a hit sounds as one slam OR one snap, never both and never neither.
R.advance(2)
hit({Position=V3(0,3,200),Stage=6,VictimUserId=99})
check(count(SNAP)==1,'Jungle hit whose slam was not heard keeps the snap')
do
 local root6=R.new('Part');root6.Name='Root';root6.CFrame=CF(0,6,0);root6.Parent=W.workspace
 local _,fx6=pcall(KFx.new,root6,6)
 for _,d in ipairs({100,119,121,200,259})do
  R.advance(2);table.clear(played)
  pcall(KFx.Slam,fx6,{Distance=d,LocalDistance=d,Frame=CF(0,6,0),Low=false,Now=R.clock})
  local slam=count(GROUND)
  hit({Position=V3(0,3,d-20),Stage=6,VictimUserId=99})
  -- (hit() cleared the log: the snap count is the hit's own)
  check(slam==1,'distance '..d..': the slam sound is heard (the sound range is 260, not the 120-stud effect range)')
  check(count(SNAP)==0,'distance '..d..': ...and the snap stays out (one slam, not slam + snap)')
 end
 R.advance(2);table.clear(played)
 pcall(KFx.Slam,fx6,{Distance=300,LocalDistance=300,Frame=CF(0,6,0),Low=false,Now=R.clock})
 check(count(GROUND)==0,'beyond the sound range (300): no slam sound')
 hit({Position=V3(0,3,235),Stage=6,VictimUserId=99}) -- (the victim is ~255 studs from the camera: inside the hit's own 260 range)
 check(count(SNAP)==1,'... so the hit keeps its snap (never neither)')
end
for _,stage in ipairs({2,3,4,5,7})do hit({Position=V3(0,3,0),Stage=stage,VictimUserId=99});check(count(SNAP)==1,'stage '..stage..' (punch/swipe/push): snap unchanged')end
hit({Position=V3(0,3,0),Stage=7,VictimUserId=7,Veiled=true})
check(count(VEIL)==1 and count(SNAP)==0,'The Darkened catch: its own sound, no generic snap')
local shell=W.workspace:FindFirstChild('VeiledImpactShell');local beam=W.workspace:FindFirstChild('VeiledImpactBeam')
check(shell and beam and shell.Material==R.Enum.Material.Neon,'purple neon shell + beam')
check(shell and shell.Color.R>shell.Color.G and shell.Color.B>shell.Color.G,'shell is purple')
local step=W.Run._ChestChaseKeeperImpact
R.advance(.1);step();local s1=shell.Size.X;local t1=shell.Transparency
R.advance(.2);step();check(shell.Size.X>s1 and shell.Transparency>t1,'shell grows and fades')
R.advance(.3);step();check(shell.Transparency==1 and beam.Transparency==1,'shell and beam hidden after the impact')
local edge=pg.KeeperImpactFeedback:FindFirstChild('HitEdge1');check(edge and edge.BackgroundColor3.B>edge.BackgroundColor3.G,'victim screen edge tinted purple')
hit({Position=V3(0,3,0),Stage=7,VictimUserId=99,Veiled=true})
check(W.workspace:FindFirstChild('VeiledImpactShell')==shell,'shell is pooled (reused)')
local n=0;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='VeiledImpactShell'then n+=1 end end;check(n==1,'one shell part only')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
