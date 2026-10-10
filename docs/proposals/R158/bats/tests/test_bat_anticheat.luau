--!nocheck
-- R158 bats: the server check of a hit claim (BatLagComp158.Validate) refuses what a cheater could send, and accepts honest claims at any speed.
-- Histories are filled the way the server would (30 Hz samples of each player's root); times are server times in seconds; the swing starts at 0.
local L=require('./BatLagComp158')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- path(t) -> x,y,z,lx,lz ; fills a history from t0 to t1
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
local function expect(c,now,ok,reason,msg)
 local got,why=L.Validate(c,now)
 check(got==ok and(reason==nil or why==reason),string.format('%s: expected %s (%s), got %s (%s)',msg,tostring(ok),tostring(reason),tostring(got),tostring(why)))
end
-- 1. honest claims ------------------------------------------------------------------------------------------------------------------------------
expect(claim(),.36,true,'hit','a standing victim 7 studs in front')
expect(claim({Victim=history(standing(9,4),-1,.40)}),.36,true,'hit','a victim to the front-right, 66 degrees off (inside 75)')
expect(claim({Victim=history(standing(1,-1.5),-1,.40)}),.36,true,'hit','a victim inside you (the 4-stud circle all round)')
expect(claim({ViewTime=.24}),.30,true,'hit','the first moment of the strike')
expect(claim({ViewTime=.36}),.42,true,'hit','the last moment of the strike')
-- a high-ping swinger: the claim arrives .25 s after its frame; the victim ran across and was in front .25+.10 s before (capped at .30, +-.08)
do
 local v=running(-100*.0,7,100,0) -- at x=0 when t=0
 local c=claim({Victim=history(v,-1,.60)})
 expect(c,.55,true,'hit','300+ ms ping: the victim was in front .30 s before the frame (the cap)')
end
-- 2. refused ------------------------------------------------------------------------------------------------------------------------------------
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
-- the rewind cap: the victim was in front only .55 s before the frame (running away at 100 studs/s) -> never reachable by rewinding
do
 local v=running(0,7-100*-.25,0,100) -- z = 32 + 100 t: z = 7 at t = -.25, i.e. .55 s before the frame at .30
 expect(claim({Victim=history(v,-1,.60)}),.55,false,'out of reach','a victim in front only .55 s before the frame (rewind is capped at .30)')
 local w=running(0,12,0,100) -- z = 7 at t = -.05, .35 s before the frame; the claim's own lag is .05 -> rewinds .15 (+-.08) = .07..23: z >= 19 there
 expect(claim({Victim=history(w,-1,.60)}),.35,false,'out of reach','a short lag cannot rewind further than lag + buffer (+- slack)')
 expect(claim({Victim=history(w,-1,.60)}),.60,true,'hit','the same claim arriving .30 s late: rewinds .30 (the cap) +- .08: .35 is inside')
 local f=running(0,32,0,100) -- z = 7 at t = -.25, .55 s before the frame; at the oldest time a claim may reach (.38 s before) it is 24 studs away
 expect(claim({Victim=history(f,-1,.80)}),.79,false,'out of reach','a victim in front only .55 s before the frame: never (cap .30 + slack .08)')
end
-- 3. fast players --------------------------------------------------------------------------------------------------------------------------------
-- the swinger runs at 575 studs/s past a standing victim 3 studs to the side; its claim is the sub-frame moment 7 studs before the victim
do
 local s=running(0,-0.30*575,0,575) -- at z = 0 when t = .30
 local c=claim({Swinger=history(s,-1,.40),Victim=history(standing(3,7),-1,.40),OwnZ=0})
 expect(c,.36,true,'hit','a 575 studs/s swinger passing a standing victim')
 local d=claim({Swinger=history(s,-1,.40),Victim=history(standing(3,7),-1,.40),OwnX=6})
 expect(d,.36,false,'swinger not where it claims','a 575 studs/s swinger claiming a spot 6 studs beside its own server path')
 local e=claim({Swinger=history(s,-1,.40),Victim=history(standing(3,7),-1,.40),OwnZ=-30})
 expect(e,.36,false,'out of reach','a spot 30 studs back IS on its path (.05 s earlier), but the victim is 37 studs from it')
end
-- the reach bonus along relative speed is capped: both run head-on at 575 (1,150 studs/s apart) -> reach 14 + 6 = 20, never more
do
 local s=running(0,-.30*575,0,575)
 -- honest geometry: the victim is checked at view - back = .30 - .16 = .14 (+-.08); make it exactly `gap` ahead of the claimed spot (z = 0) at .14
 local function at(gap)return function(t)return 0,3,gap-575*(t-.14),0,-1 end end
 expect(claim({Swinger=history(s,-1,.40),Victim=history(at(19.5),-1,.40)}),.36,true,'hit','head-on at 1,150 studs/s: a victim 19.5 studs ahead (reach 14 + bonus 6)')
 -- the same victim but stopped 26 studs ahead (it never comes closer): out of reach even with the bonus
 expect(claim({Swinger=history(s,-1,.40),Victim=history(standing(0,26),-1,.40)}),.36,false,'out of reach','26 studs ahead, standing: no bonus without relative speed at the victim')
end
-- 4. cost: one Validate on full histories, and no table is created per call beyond the claim itself (the histories are reused ring buffers)
do
 local c=claim();local t0=os.clock();for _=1,2000 do L.Validate(c,.36)end
 local us=(os.clock()-t0)/2000*1e6
 print(string.format('cost: one Validate %.1f microseconds on this machine (Luau CLI, not the Roblox VM)',us))
 check(us<200,'Validate is cheap')
end
print(string.format('%d checks, %d failed',checks,fails))
if fails>0 then error('anti-cheat test failed')end
