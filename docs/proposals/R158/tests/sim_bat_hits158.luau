--!nocheck
-- R158 bats, BUILT: the hit-registration mock of docs/proposals/R158/bats/tests/sim_bat_hits.luau, now on the REAL code of both sides:
--  NEW   = this checkout: the swinger's client sweep is BatHitbox.ClientFrame (what BatClient calls each frame of the strike, same rules: the target's
--          path since the last frame, the sub-frame moment, the swinger's own spot at that moment) and the server is the real BatService (Request with
--          the click's Start, Step filling the BatLagComp history at 30 Hz from the server's copies of both players, Claim -> BatLagComp.Validate ->
--          HitByBat), on bat_world158.luau.
--  TODAY = the base commit's BatService + BatHitbox + BatConfig (git), run the same way: the request reaches the server, Step judges the hit once at
--          request + Windup on the server's copies (the box), and the swinger's screen "hit" is the box at its contact frame.
-- Network model (hitbox.md): each client owns its character and sends it at 30 Hz; the server's copy of a player is its latest packet (sent ping/2
-- earlier); a client draws other players (its ping/2 + the other's ping/2 + Bc) behind the truth; 60 Hz frames, random phases per swing; straight
-- lines at constant speed. COUNTED = of the swings whose bat visibly hit on the swinger's own screen, the share the server counted.
-- Usage: luau sim_bat_hits158.luau -a <swings per cell> [quick]   (prints the tables; exits with an error when a NEW cell counts under 90 %)
local World=require('./bat_world158')
local R=World.R;local V3=R.Vector3.new;local clock=World.clock
local args={...}
local N=tonumber(args[1])or 300
local QUICK=args[2]=='quick'
math.randomseed(158)
local HB,CL,PK=1/60,1/60,1/30
local new=World.new('now',{LineZ=-1e6});local old=World.new('base',{LineZ=-1e6})
local Hit=new.Hitbox;local OldHit=old.Hitbox;local C=new.Config;local OC=old.Config
local nA,nV=new:player('A',0,0,0,1,1),new:player('V',0,7,1,0,2)
local oA,oV=old:player('A',0,0,0,1,1),old:player('V',0,7,1,0,2)
clock.T+=10
local base=clock.T -- the true time 0 of the current swing, on the clock (moves on 20 s a swing: cooldowns and rate limits are rested)
local function pos(m,t)return m.x+m.vx*t,3,m.z+m.vz*t end
local function serverPos(m,ping,phase,t)local sent=math.floor((t-ping/2-phase)/PK)*PK+phase;return pos(m,sent)end
local function nextFrame(t,phase,step)return math.ceil((t-phase)/step-1e-9)*step+phase end
local function place(w,p,m,x,y,z)w:place(p,x,y,z,m.fx,m.fz)end
local function boxHit(Hitbox,ax,az,fx,fz,vx,vy,vz)return Hitbox.Contains(R.CFrame.lookAt(V3(ax,3,az),V3(ax+fx,3,az+fz)),V3(vx,vy,vz))end
-- server frames from t0 to t1 (true times): both players at their server copies, then Step; events = {{T, fn}} run in time order after that frame's Step
local function serverRun(w,pA,pV,A,V,pingA,pingV,phA,phV,hb,t0,t1,events)
 local t=nextFrame(t0,hb,HB);local e=1
 while t<=t1+1e-9 do
  clock.T=base+t
  local x,y,z=serverPos(A,pingA,phA,t);place(w,pA,A,x,y,z)
  x,y,z=serverPos(V,pingV,phV,t);place(w,pV,V,x,y,z)
  w:step()
  while events[e]and events[e][1]<=t+1e-9 do events[e][2]();e+=1 end
  t+=HB
 end
end
local swingId=0
-- one swing, both systems. Returns today (screen, server), new (screen, server)
local function swing(sc,c,pingA,pingV,bc)
 local A,V=sc.A,sc.V
 base+=20
 local hb=math.random()*HB;local phA,phV=math.random()*PK,math.random()*PK;local cl=math.random()*CL
 local dView=pingA/2+pingV/2+bc
 local function view(t)return pos(V,t-dView)end
 local speedA=math.sqrt(A.vx*A.vx+A.vz*A.vz)
 nA.Character.Humanoid.WalkSpeed=math.max(24,speedA);oA.Character.Humanoid.WalkSpeed=math.max(24,speedA)
 -- TODAY ----------------------------------------------------------------------------------------------------------------------------------------
 local at=nextFrame(c+pingA/2,hb,HB)
 local before=#old.Hits
 serverRun(old,oA,oV,A,V,pingA,pingV,phA,phV,hb,at-.1,at+OC.Windup+.05,{{at,function()old.Service:Request(oA)end}})
 local server1=#old.Hits>before
 local tc=nextFrame(at+OC.Windup,cl,CL)
 local ox,_,oz=pos(A,tc);local sx,sy,sz=view(tc)
 local screen1=boxHit(OldHit,ox,oz,A.fx,A.fz,sx,sy,sz)
 -- NEW ------------------------------------------------------------------------------------------------------------------------------------------
 local claim
 local t=nextFrame(c+C.HitFrom-.1,cl,CL)
 local prevT,prx,pry,prz,pox,poy,poz
 while true do
  local mx,my,mz=pos(A,t);local wx,wy,wz=view(t);local rx,ry,rz=wx-mx,wy-my,wz-mz
  if prevT and prevT<c+C.HitTo and t>=c+C.HitFrom then
   local u=Hit.ClientFrame(prx,pry,prz,rx,ry,rz,A.fx,A.fz)
   if u then claim={View=prevT+(t-prevT)*u,X=pox+(mx-pox)*u,Y=poy+(my-poy)*u,Z=poz+(mz-poz)*u};break end
  end
  if t>=c+C.HitTo then break end
  prevT,prx,pry,prz,pox,poy,poz=t,rx,ry,rz,mx,my,mz;t+=CL
 end
 local screen2,server2=claim~=nil,false
 swingId+=1
 local id=swingId
 local req=nextFrame(c+pingA/2,hb,HB)
 if claim then
  local arrive=nextFrame(claim.View+pingA/2,hb,HB)
  local before2=#new.Hits
  serverRun(new,nA,nV,A,V,pingA,pingV,phA,phV,hb,math.min(req,arrive)-.7,arrive,{
   {req,function()new:request(nA,base+c,id)end},
   {arrive,function()local ok,why=new:claim(nA,{Id=id,Victim=nV,ViewTime=base+claim.View,Own=V3(claim.X,claim.Y,claim.Z),Look=V3(A.fx,0,A.fz)})
     if not ok then local r=new.Reasons or{};new.Reasons=r;r[why]=(r[why]or 0)+1 end end}})
  server2=#new.Hits>before2
 else
  serverRun(new,nA,nV,A,V,pingA,pingV,phA,phV,hb,req-.1,req,{{req,function()new:request(nA,base+c,id)end}})
 end
 return screen1,server1,screen2,server2
end
local scenarios={
 {Name='crossing',Text='victim runs across in front of a standing swinger',Make=function(v)return{A={x=0,z=0,vx=0,vz=0,fx=0,fz=1},V={x=0,z=7,vx=v,vz=0,fx=1,fz=0}},v end},
 {Name='head-on',Text='victim runs straight at a standing swinger (passes 0-6 studs to the side)',Make=function(v)local x0=math.random()*12-6;return{A={x=0,z=0,vx=0,vz=0,fx=0,fz=1},V={x=x0,z=7,vx=0,vz=-v,fx=0,fz=-1}},v end},
 {Name='drive-by',Text='swinger runs past a standing victim (0-6 studs to the side)',Make=function(v)local x0=math.random()*12-6;return{A={x=0,z=0,vx=0,vz=v,fx=0,fz=1},V={x=x0,z=7,vx=0,vz=0,fx=0,fz=1}},v end},
 {Name='both-head-on',Text='both run at each other at that speed',Make=function(v)local x0=math.random()*12-6;return{A={x=0,z=0,vx=0,vz=v,fx=0,fz=1},V={x=x0,z=7,vx=0,vz=-v,fx=0,fz=-1}},2*v end},
 {Name='chase',Text='swinger chases the victim at the same speed (any gap)',Chase=true},
}
local speeds={24,141,285,500,575}
local pings={.05,.12,.25}
if QUICK then speeds={24,285,575};pings={.05,.25}end
local function cell(sc,v,pingA,pingV,bc,n)
 local s1,b1,s2,b2=0,0,0,0
 for _=1,n do
  local world,c
  if sc.Chase then
   local gap=-4+math.random()*(26+.45*v);local x0=math.random()*14-7
   world={A={x=x0,z=7-gap,vx=0,vz=v,fx=0,fz=1},V={x=0,z=7,vx=0,vz=v,fx=0,fz=1}};c=0
  else
   local rel;world,rel=sc.Make(v)
   local lo,hi=-0.95-25/rel,0.55+25/rel;c=lo+math.random()*(hi-lo)
  end
  local a,b,cc,d=swing(world,c,pingA,pingV,bc)
  if a then s1+=1 end;if a and b then b1+=1 end
  if cc then s2+=1 end;if cc and d then b2+=1 end
 end
 local function pct(x,y)return y>0 and math.floor(1000*x/y+.5)/10 or nil end
 return {Today=pct(b1,s1),New=pct(b2,s2),Seen1=s1,Seen2=s2}
end
local function fmt(x)return x and string.format('%g%%',x)or'-'end
local worst,fails=101,0
print('# R158 bat hits, BUILT: counted (of the hits the swinger SAW, the share the server COUNTED), today / new; victim ping 120 ms; Bc 0.10 s')
print(string.format('swings per cell: %d',N))
for _,sc in ipairs(scenarios)do
 print('');print('## '..sc.Name..': '..sc.Text)
 local head={};for _,p in ipairs(pings)do table.insert(head,string.format('swinger ping %d ms: today / new',p*1000))end
 print('| speed (studs/s) | '..table.concat(head,' | ')..' |');print('|---|'..string.rep('---|',#pings))
 for _,v in ipairs(speeds)do
  local row={tostring(v)}
  for _,p in ipairs(pings)do
   local r=cell(sc,v,p,.12,.10,N)
   table.insert(row,fmt(r.Today)..' / '..fmt(r.New)..string.format(' (%d seen)',r.Seen2))
   if r.New then worst=math.min(worst,r.New);if r.New<90 then fails+=1;print(string.format('FAIL: %s at %d studs/s, ping %d ms: only %g%% of the seen hits counted',sc.Name,v,p*1000,r.New))end
   elseif r.Seen2==0 then fails+=1;print('FAIL: no swing hit on the screen at all in '..sc.Name..' '..v)end
  end
  print('| '..table.concat(row,' | ')..' |')
 end
end
if not QUICK then
 print('');print('## sensitivity (report only): the real client interpolation delay is not the assumed 0.10 s (swinger ping 120 ms), new counted')
 print('| scenario | speed | Bc 0.05 s | Bc 0.15 s |');print('|---|---|---|---|')
 for _,name in ipairs({'crossing','chase','both-head-on'})do
  local sc;for _,s in ipairs(scenarios)do if s.Name==name then sc=s end end
  for _,v in ipairs({141,500})do
   local row={name,tostring(v)}
   for _,bc in ipairs({.05,.15})do local r=cell(sc,v,.12,.12,bc,math.max(100,math.floor(N/2)));table.insert(row,fmt(r.New))end
   print('| '..table.concat(row,' | ')..' |')
  end
 end
end
local t={};for k,v in pairs(new.Reasons or{})do table.insert(t,k..' '..v)end;table.sort(t)
print('');print('new: why the server refused a seen hit (all cells): '..(#t>0 and table.concat(t,', ')or'none'))
print(string.format('sim: worst new cell %g%% counted (must be >= 90%%), %d failing cells',worst,fails))
if fails>0 then error('hit-rate sim failed')end
