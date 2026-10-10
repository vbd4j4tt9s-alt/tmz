--!nocheck
-- R158 bats, BUILT: what a cheater could send, on the REAL BatLagComp.Validate and the REAL BatService:Claim of this checkout (bat_world158.luau).
--  1. Validate: the prototype's cases (docs/proposals/R158/bats/tests/test_bat_anticheat.luau) on the built module: honest claims accepted (in front,
--     66 degrees off, inside you, the first / last strike moment, a 300+ ms ping, a 575 studs/s swinger, 1,150 studs/s apart), every forged one refused
--     with its reason; plus the built extras: a teleport is never a path (the victim's or the swinger's), the swinger's 4-stud slack may not reach
--     through a wall.
--  2. BatService:Claim: no swing / a wrong swing number / a second claim / claim spam (SecurityGate BatHit) / yourself, a part or a player who left as
--     the victim / NaN / a swing that ran out / a tool put away / a teleport during the strike / a back-dated or future swing start / a wall /
--     someone who cannot be hit (ForceField, behind the base line, knocked down, just spawned) or a swinger in the hub: all refused, HitByBat never runs;
--     an honest claim runs HitByBat(swinger, victim, the victim's character) once. Every refusal is counted by reason.
local World=require('./bat_world158')
local R=World.R;local V3=R.Vector3.new;local clock=World.clock
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local w=World.new('now')
local L,C=w.Lag,w.Config
-- 1. Validate ------------------------------------------------------------------------------------------------------------------------------------
local function history(path,t0,t1)
 local h=L.History();local t=t0
 while t<=t1+1e-9 do local x,y,z,lx,lz=path(t);L.Record(h,t,x,y,z,lx,lz,true);t+=1/30 end
 return h
end
local function standing(x,z,lx,lz)return function()return x,3,z,lx or 0,lz or 1 end end
local function running(x,z,vx,vz)local l=math.sqrt(vx*vx+vz*vz);return function(t)return x+vx*t,3,z+vz*t,vx/l,vz/l end end
local function claim(t)
 local c={Start=0,ViewTime=.30,OwnX=0,OwnY=3,OwnZ=0,LookX=0,LookZ=1,Swinger=history(standing(0,0),-1,.40),Victim=history(standing(0,7),-1,.40)}
 for k,v in pairs(t or{})do c[k]=v end
 return c
end
local function wallFn(c)if c.Blocked then return function(_,...)return c.Blocked(...)end end;return nil end
local function expect(c,now,ok,reason,msg)
 local got,why=L.Validate(c,now,wallFn(c))
 check(got==ok and(reason==nil or why==reason),string.format('%s: expected %s (%s), got %s (%s)',msg,tostring(ok),tostring(reason),tostring(got),tostring(why)))
end
expect(claim(),.36,true,'hit','a standing victim 7 studs in front')
expect(claim({Victim=history(standing(9,4),-1,.40)}),.36,true,'hit','a victim to the front-right, 66 degrees off (inside 75)')
expect(claim({Victim=history(standing(1,-1.5),-1,.40)}),.36,true,'hit','a victim inside you (the 4-stud circle all round)')
expect(claim({ViewTime=.24}),.30,true,'hit','the first moment of the strike')
expect(claim({ViewTime=.36}),.42,true,'hit','the last moment of the strike')
expect(claim({Victim=history(running(0,7,100,0),-1,.60)}),.55,true,'hit','300+ ms ping: the victim was in front .30 s before the frame (the cap)')
expect(claim({Victim=history(standing(0,30),-1,.40)}),.36,false,'out of reach','a victim 30 studs away')
expect(claim({Victim=history(standing(3,-6),-1,.40)}),.36,false,'out of reach','a victim behind the swinger')
expect(claim({Victim=history(standing(0,17),-1,.40)}),.36,false,'out of reach','a standing victim 17 studs away (reach 14, no speed bonus)')
expect(claim({ViewTime=.10}),.16,false,'outside the strike','a frame before the strike')
expect(claim({ViewTime=.50}),.56,false,'outside the strike','a frame after the strike')
expect(claim({ViewTime=.30}),.85,false,'too late','a claim arriving .55 s after its frame')
expect(claim({ViewTime=.33}),.30,false,'from the future','a frame later than the server clock')
expect(claim({OwnX=20}),.36,false,'swinger not where it claims','the swinger claims a spot 20 studs off its own path')
expect(claim({OwnX=5}),.36,false,'swinger not where it claims','the swinger claims a spot 5 studs off its own path')
expect(claim({LookX=0,LookZ=-1}),.36,false,'swinger not facing that way','the swinger claims to face backwards')
expect(claim({Blocked=function()return true end}),.36,false,'through a wall','a wall between the bat and the victim')
expect(claim({Resolved=true}),.36,false,'one claim per swing','a second claim for the same swing')
expect(claim({OwnX=0/0}),.36,false,'bad numbers','NaN in the claim')
expect(claim({OwnZ=1e9}),.36,false,'bad numbers','a huge number in the claim')
expect(claim({LookX=0,LookZ=0}),.36,false,'bad facing','a zero facing')
expect(claim({ViewTime='x'}),.36,false,'bad time','a non-number time')
expect(claim({ViewTime=0/0}),.36,false,'bad time','a NaN time')
do -- the rewind cap
 local v=running(0,32,0,100) -- z = 7 at t = -.25, .55 s before the frame at .30
 expect(claim({Victim=history(v,-1,.60)}),.55,false,'out of reach','a victim in front only .55 s before the frame (rewind is capped at .30)')
 local wv=running(0,12,0,100) -- z = 7 at t = -.05; the claim's own lag is .05 -> rewinds .15 (+-.08): z >= 19 there
 expect(claim({Victim=history(wv,-1,.60)}),.35,false,'out of reach','a short lag cannot rewind further than lag + buffer (+- slack)')
 expect(claim({Victim=history(wv,-1,.60)}),.60,true,'hit','the same claim arriving .30 s late: rewinds .30 (the cap) +- .08: inside')
 expect(claim({Victim=history(running(0,32,0,100),-1,.80)}),.79,false,'out of reach','a victim in front only .55 s before the frame: never (cap .30 + slack .08)')
end
do -- fast players
 local s=running(0,-0.30*575,0,575) -- at z = 0 when t = .30
 expect(claim({Swinger=history(s,-1,.40),Victim=history(standing(3,7),-1,.40),OwnZ=0}),.36,true,'hit','a 575 studs/s swinger passing a standing victim')
 expect(claim({Swinger=history(s,-1,.40),Victim=history(standing(3,7),-1,.40),OwnX=6}),.36,false,'swinger not where it claims','a 575 studs/s swinger claiming a spot 6 studs beside its own server path')
 expect(claim({Swinger=history(s,-1,.40),Victim=history(standing(3,7),-1,.40),OwnZ=-30}),.36,false,'out of reach','a spot 30 studs back IS on its path, but the victim is 37 studs from it')
 local function at(gap)return function(t)return 0,3,gap-575*(t-.14),0,-1 end end
 expect(claim({Swinger=history(s,-1,.40),Victim=history(at(19.5),-1,.40)}),.36,true,'hit','head-on at 1,150 studs/s: a victim 19.5 studs ahead (reach 14 + bonus 6)')
 -- the cap itself: a victim crossing at 575 studs/s in front of the 575 studs/s swinger (relative 813: the bonus would be 16, capped at 6)
 local function across(d)return function(t)return 575*(t-.14),3,d,1,0 end end
 expect(claim({Swinger=history(s,-1,.40),Victim=history(across(19.5),-1,.40)}),.36,true,'hit','crossing 19.5 studs ahead at 575 + 575 studs/s: inside 14 + the capped bonus 6')
 expect(claim({Swinger=history(s,-1,.40),Victim=history(across(21),-1,.40)}),.36,false,'out of reach','crossing 21 studs ahead at 575 + 575 studs/s: past 14 + 6 (the bonus never grows past MaxBonus)')
 expect(claim({Swinger=history(s,-1,.40),Victim=history(standing(0,26),-1,.40)}),.36,false,'out of reach','26 studs ahead, standing: no bonus without relative speed at the victim')
end
do -- R158 built: a teleport is never a path
 -- the victim is moved by the server from 200 studs left to 200 studs right across the swinger's front in one sample: no sweep along that jump
 local jump=function(t)if t<.17 then return-200,3,7,1,0 end;return 200,3,7,1,0 end
 expect(claim({Victim=history(jump,-1,.40)}),.36,false,'out of reach','a victim teleported across the front (one sample from x -200 to +200) is not swept along the jump')
 -- the swinger is teleported 300 studs; a claimed spot half way along that line is on no path it ran
 local hop=function(t)if t<.2 then return 0,3,-150,0,1 end;return 0,3,150,0,1 end
 expect(claim({Swinger=history(hop,-1,.40),OwnZ=0,Victim=history(standing(0,7),-1,.40)}),.36,false,'swinger not where it claims','a spot half way along a teleport (never run) is not on the swinger\'s path')
 local h=L.History();for i=0,40 do L.Record(h,i/30,0,3,i,0,1,true)end
 check(h.Count==C.HistorySize and #h.T==C.HistorySize and #h.X==C.HistorySize,'the history ring keeps '..C.HistorySize..' samples in arrays made once ('..#h.T..')')
 local t0=h.T;L.Record(h,2,0,3,0,0,1,true);check(h.T==t0 and #h.T==C.HistorySize,'recording reuses the same arrays (nothing grows, nothing is made)')
 check(h.J[h.Head]==false,'40 studs back in .67 s (60 studs/s) is a run, not a jump')
 L.Record(h,2+1/30,0,3,500,0,1,true)
 check(h.J[h.Head]==true,'500 studs in 1/30 s (15,000 studs/s, over JumpSpeed '..C.JumpSpeed..') is marked as a jump')
 local x,_,z=L.Sample(h,2+1/60);check(x==0 and z==0,'between a jump and the sample before it the history holds still (never a path across)')
end
do -- the swinger's slack may not reach through a wall: a claimed spot 3 studs off its path, a wall between path and spot
 local c=claim({OwnX=3})
 c.Blocked=function(ax,ay,az,bx,by,bz)return math.min(ax,bx)<1.5 and math.max(ax,bx)>1.5 end -- a wall at x = 1.5 (the victim at x 0 is on the near side)
 expect(c,.36,false,'through a wall','a claimed spot 3 studs off the path, behind a wall at 1.5 studs')
 local d=claim({OwnX=3,Victim=history(standing(3,7),-1,.40)})
 expect(d,.36,true,'hit','the same 3-stud slack with no wall: accepted (inside OwnSlack 4)')
end
-- 1b. BatHitbox: the sector, and paths, not points (the client's sweep and the server's check both use it) -------------------------------------------
do
 local H=w.Hitbox
 check(H.InSector(0,0,7,0,1,14,H.CosHalf,4,5)and H.InSector(9,0,4,0,1,14,H.CosHalf,4,5)and not H.InSector(0,0,15,0,1,14,H.CosHalf,4,5),'the sector: 7 ahead and 66 degrees off are in, 15 ahead is out (reach 14)')
 check(not H.InSector(-4,0,-3,0,1,14,H.CosHalf,4,5)and H.InSector(-2,0,-2,0,1,14,H.CosHalf,4,5)and not H.InSector(0,6,7,0,1,14,H.CosHalf,4,5),'behind you only inside the 4-stud circle; +-5 up and down')
 local u=H.ClientFrame(-60,0,7,60,0,7,0,1)
 check(u and u>.2 and u<.8,'paths, not points: a player who crossed 120 studs in one frame (7 in front) is found in the middle of its path (u = '..tostring(u)..')')
 check(H.ClientFrame(-60,0,30,60,0,30,0,1)==nil,'... but not when that path stays 30 studs away')
 check(H.ClientFrame(0,0,3,0,0,-40,0,1)==0,'a path that starts inside the sector is found at its start (u = 0)')
 check(H.Flat(0,0)==nil and select(2,H.Flat(0,-2))==-1,'a facing straight up / down has no flat direction; others are made unit length')
 check(H.OnTrack(0,10,-100,0,114,1445)and not H.OnTrack(0,-97,-100,0,114,1445)and not H.OnTrack(200,10,-100,0,114,1445)and not H.OnTrack(0,1600,-100,0,114,1445)
  and H.OnTrack(0,10,nil,nil,nil,nil),'where a hit can count (the client\'s copy of the rule): past the base line + 4, inside the track, before its end; unknown numbers allow it')
end
-- 2. BatService:Claim ------------------------------------------------------------------------------------------------------------------------------
local function frames(n)for _=1,n do clock.T+=1/60;w:step()end end
local A=w:player('A',0,0,0,1);local V=w:player('V',0,7,1,0);local X=w:player('X',40,40,0,1)
clock.T+=5;frames(40)
local id=0
local function swing(p,start)id+=1;local ok=w:request(p or A,start or clock.T,id);return ok,id,start or clock.T end
local function honest(sid,start,extra)
 local t={Id=sid,Victim=V,ViewTime=start+.30,Own=V3(0,3,0),Look=V3(0,0,1)}
 for k,v in pairs(extra or{})do t[k]=v end
 return t
end
local function rest()clock.T+=3;frames(40)end
local hits=#w.Hits
local function noHit(msg)check(#w.Hits==hits,msg..': HitByBat did not run');hits=#w.Hits end
local function expectClaim(t,want,msg,who)
 local ok,why=w:claim(who or A,t)
 check(ok==false and why==want,string.format('%s: refused "%s" (got %s, %s)',msg,want,tostring(ok),tostring(why)))
 noHit(msg)
end
-- the request: the packet everyone gets carries the click's start; a start from the past / the future is held to the window
do
 local before=#w.Fired
 local ok,sid,start=swing()
 local p=w.Fired[#w.Fired]
 check(ok and #w.Fired==before+1 and p.Kind=='Swing'and p.At==start and p.Id==sid and p.Character==A.Character,'a swing request: everyone gets {Kind=Swing, At = the click\'s start, Id, Character}')
 frames(18)
 local okc,why=w:claim(A,honest(sid,start))
 check(okc and why=='hit'and #w.Hits==hits+1 and w.Hits[#w.Hits].A==A and w.Hits[#w.Hits].V==V and w.Hits[#w.Hits].C==V.Character,'an honest claim: HitByBat(swinger, victim, the victim\'s character), once ('..tostring(why)..')')
 hits=#w.Hits
 expectClaim(honest(sid,start),'no such swing','the same claim again after the hit (the swing is used up)')
 rest()
end
do
 local _,sid,start=swing();frames(18)
 expectClaim(honest(sid+1,start),'no such swing','a claim with another swing number')
 local ok,why=w:claim(A,honest(sid,start,{Victim=X}))
 check(not ok and why=='out of reach','a claim naming a player far away: out of reach ('..tostring(why)..')');noHit('far victim')
 expectClaim(honest(sid,start),'one claim per swing','a second claim for the same swing (the first one is spent, whatever it said)')
 rest()
end
expectClaim(honest(999,clock.T),'no such swing','a claim with no swing at all')
rest()
do -- claim spam: the BatHit budget (2 a second, 3 at once) is spent by junk claims first
 for k=1,3 do w:claim(A,honest(5000+k,clock.T))end
 local _,sid,start=swing();frames(18)
 expectClaim(honest(sid,start),'refused by SecurityGate','an honest claim after 3 junk claims in the same instant (BatHit: 3 at once, then 2 a second)')
 rest();rest()
end
do -- bad victims and bad numbers (each spends the swing)
 local _,sid,start=swing();frames(18)
 expectClaim(honest(sid,start,{Victim=A}),'bad victim','yourself as the victim')
 rest()
 _,sid,start=swing();frames(18)
 local part=R.new('Part');part.Parent=w.workspace
 expectClaim(honest(sid,start,{Victim=part}),'bad victim','a part as the victim')
 rest()
 local G=w:player('G',0,7,1,0);clock.T+=4;frames(40)
 _,sid,start=swing();frames(18);w:remove(G)
 expectClaim(honest(sid,start,{Victim=G}),'bad victim','a player who has left as the victim')
 rest()
 _,sid,start=swing();frames(18)
 expectClaim(honest(sid,start,{Own=V3(0/0,3,0)}),'refused by SecurityGate','NaN in the claim (SecurityGate refuses it before anything else)')
 rest()
 _,sid,start=swing();frames(18)
 expectClaim(honest(sid,start,{Own='here'}),'bad numbers','a text instead of a position')
 rest()
end
do -- the swing ran out / the tool was put away / a teleport during the strike
 local _,sid,start=swing();frames(70)
 expectClaim(honest(sid,start),'no such swing','a claim after the swing ran out (Start + HitTo + slack + MaxClaimDelay)')
 rest()
 _,sid,start=swing();frames(10)
 local tool=w.Service.Tools[A];tool.Parent=A:FindFirstChildOfClass('Backpack');frames(2)
 expectClaim(honest(sid,start),'no such swing','a claim after the bat was put away mid-swing')
 tool.Parent=A.Character;rest()
 _,sid,start=swing();frames(6);w:place(A,0,3,60,0,1);frames(2)
 expectClaim(honest(sid,start,{Own=V3(0,3,60)}),'no such swing','a jump of 60 studs during the strike drops the swing (today\'s rule, max(18, walk speed x .54))')
 w:place(A,0,3,0,0,1);rest()
end
do -- the swing's start: back-dated or from the future
 local ok,sid=w:request(A,clock.T-10,id+1);id+=1
 local p=w.Fired[#w.Fired]
 check(ok and math.abs(p.At-(clock.T-C.StartBack))<1e-9,'a start 10 s in the past is held to receipt - '..C.StartBack..' s ('..tostring(p.At-clock.T)..')')
 frames(18)
 expectClaim(honest(id,clock.T-10),'outside the strike','a claim timed to the faked start')
 rest()
 ok=w:request(A,clock.T+5,id+1);id+=1;p=w.Fired[#w.Fired]
 check(ok and math.abs(p.At-(clock.T+C.StartAhead))<1e-9,'a start in the future is held to receipt + '..C.StartAhead..' s')
 rest()
end
do -- the cooldown: 1.0 s between swing starts; a receipt may come up to CooldownSlack early (jitter), never a start
 local s1=clock.T-.1;local ok1=w:request(A,s1,id+1);id+=1 -- (this packet took .1 s)
 clock.T+=.8;local ok2=w:request(A,s1+.9,id+1);id+=1
 check(ok1 and not ok2,'a second swing starting .9 s after the first: refused (cooldown 1.0 s)')
 clock.T=s1+1.0;local ok3=w:request(A,s1+1.0,id+1);id+=1
 check(ok3,'a swing starting 1.0 s after the first whose packet took .1 s less (network jitter: .9 s between the packets): allowed')
 rest()
 local okA,_,sA=swing();clock.T+=.5;local okB=w:request(A,sA-.1,id+1);id+=1
 check(okA and not okB,'a swing back-dated to before the last one: refused')
 rest()
end
do -- walls
 local _,sid,start=swing();frames(18)
 w.Walls={{-5,3.5,5,3.5}}
 expectClaim(honest(sid,start),'through a wall','a wall between the swinger and the victim')
 w.Walls={};rest()
end
do -- who can be hit: today's rules, checked at the claim
 local function case(setup,undo,msg)
  local _,sid,start=swing();frames(18);setup()
  expectClaim(honest(sid,start),'cannot be hit',msg);undo();rest()
 end
 case(function()R.new('ForceField').Parent=V.Character end,function()V.Character:FindFirstChildOfClass('ForceField'):Destroy()end,'a victim with a ForceField')
 case(function()w.Down[V]=true end,function()w.Down[V]=nil end,'a victim already knocked down (Ragdoll:CanHit)')
 case(function()V:SetAttribute('GuardianFlingActive',true)end,function()V:SetAttribute('GuardianFlingActive',false)end,'a victim just thrown (GuardianFlingActive)')
 local line=w.Chase.Map.BaseBoundaryLine
 case(function()w.Chase.Map.BaseBoundaryLine={Position=V3(0,0,5)}end,function()w.Chase.Map.BaseBoundaryLine=line end,'a victim within 4 studs past the base line (and the swinger behind it: the hub)')
 case(function()w.Service.SpawnAt[V]=clock.T end,function()w.Service.SpawnAt[V]=clock.T-10 end,'a victim in its first 3 s after spawning')
end
-- every refusal above is counted by reason (live: a wrong tolerance shows up as one reason growing)
do
 local n=0;for _,v in pairs(w.Service.Counts)do n+=v end
 check(w.Service.Counts.hit==1 and (w.Service.Counts['no such swing']or 0)>=5 and (w.Service.Counts['cannot be hit']or 0)==5 and n>=20,'every claim is counted by its reason (hit 1, no such swing '..tostring(w.Service.Counts['no such swing'])..', total '..n..')')
 check(w.Remote:GetAttribute('Claims_hit')==1 and w.Remote:GetAttribute('Claims_cannot_be_hit')==5 and w.Remote:GetAttribute('Claims_no_such_swing')==w.Service.Counts['no such swing']
  and w.Remote:GetAttribute('Claims_refused_by_SecurityGate')==w.Service.Counts['refused by SecurityGate'],'... and shown live as attributes of the BatSwing remote (Claims_hit, Claims_cannot_be_hit, ...)')
end
-- the cost: one Validate on full histories (Luau CLI, not the Roblox VM)
do
 local c=claim();local t0=os.clock();for _=1,2000 do L.Validate(c,.36)end
 local us=(os.clock()-t0)/2000*1e6
 print(string.format('cost: one Validate %.1f microseconds on this machine',us))
 check(us<300,'Validate is cheap')
end
print(string.format('anti-cheat: %d checks, %d failed',checks,fails))
if fails>0 then error('anti-cheat test failed')end
