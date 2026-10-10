--!nocheck
-- R158 bats: offline hit-registration mock. TODAY = the REAL BatHitbox.lua + BatConfig.lua of this checkout (loaded from the bundle) with
-- BatService's timing (the hit is judged once, at the first server frame after request + Windup, on the server's copies of both players).
-- PROPOSED = BatLagComp158.luau (the swinger's client sweeps the strike window on what its screen shows, the server re-checks with its history).
-- The network model (assumptions, see hitbox.md): each client owns its character and sends it at 30 Hz; the server's copy of a player is that
-- player's latest packet (sent ping/2 earlier); a client draws other players smoothly, (its ping/2 + the other's ping/2 + Bc) behind the truth.
-- Server frames 60 Hz, client frames 60 Hz, random phases per swing. Players move in straight lines at constant speed (the worst case for a
-- small box is a fast straight run; turning only adds error).
-- Metrics, per scenario x speed x swinger ping (victim ping 120 ms):
--   COUNTED = of the swings whose bat visibly hit on the swinger's own screen, the share the server counted (today: the box at the contact frame;
--             proposed: its own sweep found the victim);
--   GHOST   = of the server's hits, the share the swinger's screen showed as a miss;
--   WINDOW  = how long (ms) the click may land and still hit (share of hits x the sampled click span).
local R=require('./roblox')
local B=require('./bat_bundle')
local function load(name,env)
 local fn,err=loadstring(B[name],'='..name);if not fn then error(err)end
 setfenv(fn,setmetatable(env,{__index=getfenv(1)}));return fn()
end
local Config=load('BatConfig',{Vector3=R.Vector3})
local marker={}
local Hitbox=load('BatHitbox',{script={Parent={BatConfig=marker}},Vector3=R.Vector3,require=function(x)assert(x==marker);return Config end})
local L=require('./BatLagComp158')
local V3=R.Vector3.new
local args={...}
local N=tonumber(args[1])or 1500
math.randomseed(158)
local HB,CL,PK=1/60,1/60,1/30
-- movers: true position at time t = (x + vx t, 3, z + vz t), facing (fx,fz)
local function pos(m,t)return m.x+m.vx*t,3,m.z+m.vz*t end
local function serverPos(m,ping,phase,t)local sent=math.floor((t-ping/2-phase)/PK)*PK+phase;return pos(m,sent)end
local function nextFrame(t,phase,step)return math.ceil((t-phase)/step-1e-9)*step+phase end
local hA,hV=L.History(),L.History()
local function reset(h)h.Head=0;h.Count=0;h.Last=-math.huge end
local reasons={};local current='?'
local function percentile(list,p)if #list==0 then return 0/0 end;table.sort(list);return list[math.clamp(math.floor(#list*p+.5),1,#list)]end
-- one swing, both systems. sc = {A=mover,V=mover}; returns today (screen,server,realDist), proposed (screen,server,realDist)
local function swing(sc,c,pingA,pingV,bc)
 local A,V=sc.A,sc.V
 local hb=math.random()*HB;local phA,phV=math.random()*PK,math.random()*PK;local cl=math.random()*CL
 local dView=pingA/2+pingV/2+bc
 local function view(t)return pos(V,t-dView)end
 -- TODAY ------------------------------------------------------------------------------------------------------------------------------------
 local at=nextFrame(c+pingA/2,hb,HB)                 -- the server receives the request (At)
 local T=nextFrame(at+Config.Windup,hb,HB)            -- BatService:Step, first frame with now >= ImpactAt
 local ax,ay,az=serverPos(A,pingA,phA,T);local vx,vy,vz=serverPos(V,pingV,phV,T)
 local server1=Hitbox.Contains(R.CFrame.lookAt(V3(ax,ay,az),V3(ax+A.fx,ay,az+A.fz)),V3(vx,vy,vz))
 local tc=nextFrame(at+Config.Windup,cl,CL)           -- the swinger's contact frame (BatClient poses on server time)
 local ox,oy,oz=pos(A,tc);local sx,sy,sz=view(tc)
 local screen1=Hitbox.Contains(R.CFrame.lookAt(V3(ox,oy,oz),V3(ox+A.fx,oy,oz+A.fz)),V3(sx,sy,sz))
 local tax,_,taz=pos(A,T);local tvx,_,tvz=pos(V,T);local real1=math.sqrt((tvx-tax)^2+(tvz-taz)^2)
 -- PROPOSED ---------------------------------------------------------------------------------------------------------------------------------
 local claim
 local first=nextFrame(c+L.Config.HitFrom,cl,CL)
 local t=first
 local px,py,pz=pos(A,t-CL);local qx,qy,qz=view(t-CL);local prx,pry,prz=qx-px,qy-py,qz-pz
 while t<=c+L.Config.HitTo+1e-9 do
  local mx,my,mz=pos(A,t);local wx,wy,wz=view(t);local rx,ry,rz=wx-mx,wy-my,wz-mz
  local u=L.ClientFrame(prx,pry,prz,rx,ry,rz,A.fx,A.fz)
  if u then claim=t-CL*(1-u);break end
  prx,pry,prz=rx,ry,rz;t+=CL
 end
 local screen2,server2,real2=claim~=nil,false,nil
 if claim then
  local now=nextFrame(claim+pingA/2,hb,HB)
  reset(hA);reset(hV)
  local s=now-1.2;s=nextFrame(s,hb,HB)
  while s<=now+1e-9 do
   local x1,y1,z1=serverPos(A,pingA,phA,s);L.Record(hA,s,x1,y1,z1,A.fx,A.fz)
   local x2,y2,z2=serverPos(V,pingV,phV,s);L.Record(hV,s,x2,y2,z2,V.fx,V.fz)
   s+=HB
  end
  local cx,cy,cz=pos(A,claim)
  local why;server2,why=L.Validate({Start=c,ViewTime=claim,OwnX=cx,OwnY=cy,OwnZ=cz,LookX=A.fx,LookZ=A.fz,Swinger=hA,Victim=hV},now)
  if not server2 then reasons[current]=reasons[current]or{};reasons[current][why]=(reasons[current][why]or 0)+1 end
  local tax2,_,taz2=pos(A,now);local tvx2,_,tvz2=pos(V,now);real2=math.sqrt((tvx2-tax2)^2+(tvz2-taz2)^2)
 end
 return screen1,server1,real1,screen2,server2,real2
end
-- scenarios: at true time 0 the victim is 7 studs straight in front of the swinger (the chase uses a sampled gap instead)
local scenarios={
 {Name='crossing',Text='victim runs across in front of a standing swinger',Make=function(v)return{A={x=0,z=0,vx=0,vz=0,fx=0,fz=1},V={x=0,z=7,vx=v,vz=0,fx=1,fz=0}},v end},
 {Name='head-on',Text='victim runs straight at a standing swinger (passes 0-6 studs to the side)',Make=function(v)local x0=math.random()*12-6;return{A={x=0,z=0,vx=0,vz=0,fx=0,fz=1},V={x=x0,z=7,vx=0,vz=-v,fx=0,fz=-1}},v end},
 {Name='drive-by',Text='swinger runs past a standing victim (0-6 studs to the side)',Make=function(v)local x0=math.random()*12-6;return{A={x=0,z=0,vx=0,vz=v,fx=0,fz=1},V={x=x0,z=7,vx=0,vz=0,fx=0,fz=1}},v end},
 {Name='both-head-on',Text='both run at each other at that speed',Make=function(v)local x0=math.random()*12-6;return{A={x=0,z=0,vx=0,vz=v,fx=0,fz=1},V={x=x0,z=7,vx=0,vz=-v,fx=0,fz=-1}},2*v end},
 {Name='chase',Text='swinger chases the victim at the same speed (any gap)',Chase=true},
}
local speeds={24,60,141,226,363,500,575}
local pings={.06,.12,.20,.30}
local function cell(sc,v,pingA,pingV,bc,n)
 current=sc.Name
 local s1,v1,b1,s2,v2,b2=0,0,0,0,0,0;local d1,d2={},{}
 local span
 for _=1,n do
  local world,c
  if sc.Chase then
   local gap=-4+math.random()*(26+.45*v);local x0=math.random()*14-7
   world={A={x=x0,z=7-gap,vx=0,vz=v,fx=0,fz=1},V={x=0,z=7,vx=0,vz=v,fx=0,fz=1}};c=0;span=nil
  else
   local rel;world,rel=sc.Make(v)
   local lo,hi=-0.95-25/rel,0.55+25/rel;span=hi-lo;c=lo+math.random()*span
  end
  local a,b,r1,cc,d,r2=swing(world,c,pingA,pingV,bc)
  if a then s1+=1 end;if b then v1+=1;table.insert(d1,r1)end;if a and b then b1+=1 end
  if cc then s2+=1 end;if d then v2+=1;table.insert(d2,r2)end;if cc and d then b2+=1 end
 end
 local function pct(x,y)return y>0 and math.floor(100*x/y+.5)or nil end
 return {Counted1=pct(b1,s1),Counted2=pct(b2,s2),Ghost1=pct(v1-b1,v1),Ghost2=pct(v2-b2,v2),
  Window1=span and v1/n*span*1000,Window2=span and v2/n*span*1000,Screen1=s1,Screen2=s2,
  Real1=percentile(d1,.9),Real2=percentile(d2,.9)}
end
local function fmt(x)return x and tostring(x)..'%'or'-'end
print('# R158 bat hit mock: TODAY (real BatHitbox, one check at request+Windup on server copies) vs PROPOSED (BatLagComp158)')
print(string.format('swings per cell: %d; victim ping 120 ms; client interpolation delay Bc = 0.10 s (the proposal assumes 0.10)',N))
for _,sc in ipairs(scenarios)do
 print('');print('## '..sc.Name..': '..sc.Text)
 print('| speed (studs/s) | '..table.concat((function()local t={}for _,p in ipairs(pings)do table.insert(t,string.format('ping %d ms: counted today / proposed',p*1000))end;return t end)(),' | ')..' |')
 print('|---|'..string.rep('---|',#pings))
 local ghosts,windows={},{}
 for _,v in ipairs(speeds)do
  local row={tostring(v)};local grow={tostring(v)};local wrow={tostring(v)}
  for _,p in ipairs(pings)do
   local r=cell(sc,v,p,.12,.10,N)
   table.insert(row,fmt(r.Counted1)..' / '..fmt(r.Counted2))
   table.insert(grow,fmt(r.Ghost1)..' / '..fmt(r.Ghost2))
   if r.Window1 then table.insert(wrow,string.format('%d / %d',math.floor(r.Window1+.5),math.floor(r.Window2+.5)))else table.insert(wrow,'-')end
  end
  print('| '..table.concat(row,' | ')..' |');table.insert(ghosts,'| '..table.concat(grow,' | ')..' |');table.insert(windows,'| '..table.concat(wrow,' | ')..' |')
 end
 print('');print('ghost hits (server hit, screen showed a miss), today / proposed:')
 print('| speed | '..table.concat((function()local t={}for _,p in ipairs(pings)do table.insert(t,string.format('ping %d ms',p*1000))end;return t end)(),' | ')..' |')
 print('|---|'..string.rep('---|',#pings))
 for _,l in ipairs(ghosts)do print(l)end
 if not sc.Chase then
  print('');print('click window (ms during which a click lands a hit), today / proposed:')
  print('| speed | '..table.concat((function()local t={}for _,p in ipairs(pings)do table.insert(t,string.format('ping %d ms',p*1000))end;return t end)(),' | ')..' |')
  print('|---|'..string.rep('---|',#pings))
  for _,l in ipairs(windows)do print(l)end
 end
end
-- sensitivity: the real client buffer differs from the assumed 0.10 s
print('');print('## sensitivity: the real client interpolation delay is not the assumed 0.10 s (ping 120 ms), counted today / proposed')
print('| scenario | speed | Bc 0.05 s | Bc 0.10 s | Bc 0.15 s |');print('|---|---|---|---|---|')
for _,name in ipairs({'crossing','chase','both-head-on'})do
 local sc;for _,s in ipairs(scenarios)do if s.Name==name then sc=s end end
 for _,v in ipairs({141,363,575})do
  local row={name,tostring(v)}
  for _,bc in ipairs({.05,.10,.15})do local r=cell(sc,v,.12,.12,bc,N);table.insert(row,fmt(r.Counted1)..' / '..fmt(r.Counted2))end
  print('| '..table.concat(row,' | ')..' |')
 end
end
-- fairness: how far apart the two players REALLY were at the moment the server applied the hit (90th percentile of hits)
print('');print('## fairness: real distance between the players when the hit lands (90% of hits are closer), ping 120 ms, today / proposed (studs)')
print('| scenario | '..table.concat((function()local t={}for _,v in ipairs(speeds)do table.insert(t,tostring(v))end;return t end)(),' | ')..' |')
print('|---|'..string.rep('---|',#speeds))
for _,sc in ipairs(scenarios)do
 local row={sc.Name}
 for _,v in ipairs(speeds)do local r=cell(sc,v,.12,.12,.10,N);table.insert(row,string.format('%s / %s',r.Real1==r.Real1 and tostring(math.floor(r.Real1+.5))or'-',r.Real2==r.Real2 and tostring(math.floor(r.Real2+.5))or'-'))end
 print('| '..table.concat(row,' | ')..' |')
end
-- the rewind cap: who wins close calls at high speed. Swinger first = MaxRewind .30 (the proposal); runner first = .12
print('');print('## the rewind cap: counted (proposed) and the real distance when the hit lands (90%), swinger first (MaxRewind 0.30 s) vs runner first (0.12 s)')
print('| scenario | speed | ping | swinger first: counted, real distance | runner first: counted, real distance |');print('|---|---|---|---|---|')
for _,name in ipairs({'crossing','chase'})do
 local sc;for _,s in ipairs(scenarios)do if s.Name==name then sc=s end end
 for _,v in ipairs({141,363,575})do for _,p in ipairs({.12,.30,.45})do
  local row={name,tostring(v),string.format('%d ms',p*1000)}
  for _,cap in ipairs({.30,.12})do
   local keep=L.Config.MaxRewind;L.Config.MaxRewind=cap
   local r=cell(sc,v,p,.12,.10,N);L.Config.MaxRewind=keep
   table.insert(row,string.format('%s, %s studs',fmt(r.Counted2),r.Real2==r.Real2 and tostring(math.floor(r.Real2+.5))or'-'))
  end
  print('| '..table.concat(row,' | ')..' |')
 end end
end
-- why the server refused a claim the swinger's screen showed (all cells above)
print('');print('## proposed: why the server refused a screen hit (count over every cell above)')
for _,sc in ipairs(scenarios)do
 local r=reasons[sc.Name];local t={}
 for k,v in pairs(r or{})do table.insert(t,k..' '..v)end;table.sort(t)
 print('- '..sc.Name..': '..(#t>0 and table.concat(t,', ')or'none'))
end
