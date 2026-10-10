-- R158 bats (docs/proposals/R158/bats/hitbox.md 4.3-4.6, owner-approved): hits that match what the swinger saw, at any speed, with the server
-- still in charge. Pure math on plain numbers (BatService gives it the histories and a wall test):
--  * History / Record / Sample: every player's root and flat facing, BatConfig.HistoryHz times a second, in ring buffers made once per player (preallocated
--    number arrays: nothing is created per sample). A step faster than BatConfig.JumpSpeed (a respawn, a teleport) is marked and never swept along.
--  * Validate: the server's check of one hit claim (the swinger's client names the victim, the moment its screen showed the hit, its own spot and
--    facing). The claimed spot must lie on the swinger's OWN server path; the victim is looked up at the time the swinger's screen was showing (rewound
--    by the claim's measured travel time + the client's interpolation delay, capped); in reach (plus a small capped bonus along fast relative motion),
--    in front, no wall, one claim per swing. Every refusal has a reason (BatService counts them).
local RS=game:GetService('ReplicatedStorage')
local C=require(RS:WaitForChild('BatConfig'))
local Hitbox=require(RS:WaitForChild('BatHitbox'))
local L={}
local function idx(h,k)return (h.Head-1-k)%h.N+1 end -- k = 0 newest .. Count-1 oldest
function L.History(size)
 size=size or C.HistorySize
 return {N=size,Head=0,Count=0,Last=-math.huge,Gap=false,T=table.create(size,0),X=table.create(size,0),Y=table.create(size,0),Z=table.create(size,0),
  LX=table.create(size,0),LZ=table.create(size,1),J=table.create(size,false)}
end
function L.Clear(h)h.Head=0;h.Count=0;h.Last=-math.huge;h.Gap=false end
-- the next sample starts a new path (a new character, a teleport the server made)
function L.Break(h)h.Gap=true end
-- t: server time; (x,y,z): root position; (lx,lz): flat facing. Stores at most HistoryHz samples a second (force: always). Returns true when stored.
function L.Record(h,t,x,y,z,lx,lz,force)
 if not force and t-h.Last<1/C.HistoryHz-1e-6 then return false end
 local jump=h.Gap
 if h.Count>0 and not jump then
  local p=h.Head;local dx,dy,dz=x-h.X[p],y-h.Y[p],z-h.Z[p]
  if math.sqrt(dx*dx+dy*dy+dz*dz)>C.JumpSpeed*math.max(0,t-h.T[p])+10 then jump=true end
 end
 h.Gap=false
 local i=h.Head%h.N+1;h.Head=i;if h.Count<h.N then h.Count+=1 end;h.Last=t
 h.T[i]=t;h.X[i]=x;h.Y[i]=y;h.Z[i]=z;h.LX[i]=lx;h.LZ[i]=lz;h.J[i]=jump
 return true
end
-- position (and facing) at server time t: linear between two samples, held across a jump, clamped to the oldest / newest sample
function L.Sample(h,t)
 if h.Count==0 then return nil end
 local newest=idx(h,0)
 if t>=h.T[newest]then return h.X[newest],h.Y[newest],h.Z[newest],h.LX[newest],h.LZ[newest]end
 for k=1,h.Count-1 do
  local a=idx(h,k);local b=idx(h,k-1)
  if t>=h.T[a]then
   if h.J[b]then return h.X[a],h.Y[a],h.Z[a],h.LX[a],h.LZ[a]end
   local u=(t-h.T[a])/math.max(1e-6,h.T[b]-h.T[a])
   return h.X[a]+(h.X[b]-h.X[a])*u,h.Y[a]+(h.Y[b]-h.Y[a])*u,h.Z[a]+(h.Z[b]-h.Z[a])*u,h.LX[b],h.LZ[b]
  end
 end
 local o=idx(h,h.Count-1);return h.X[o],h.Y[o],h.Z[o],h.LX[o],h.LZ[o]
end
-- flat velocity around t (studs/s), from the samples one history step either side
function L.Velocity(h,t)
 local d=1/C.HistoryHz
 local ax,_,az=L.Sample(h,t-d);local bx,_,bz=L.Sample(h,t+d)
 if not ax then return 0,0 end
 local newest=h.T[idx(h,0)];local span=math.min(t+d,newest)-(t-d)
 if span<=1e-6 then span=2*d end
 return (bx-ax)/span,(bz-az)/span
end
-- distance from p to the segment a-b, and the nearest point
local function pointSegment(px,py,pz,ax,ay,az,bx,by,bz)
 local ex,ey,ez=bx-ax,by-ay,bz-az;local l2=ex*ex+ey*ey+ez*ez
 local u=l2>1e-9 and math.clamp(((px-ax)*ex+(py-ay)*ey+(pz-az)*ez)/l2,0,1)or 0
 local nx,ny,nz=ax+ex*u,ay+ey*u,az+ez*u
 local dx,dy,dz=px-nx,py-ny,pz-nz;return math.sqrt(dx*dx+dy*dy+dz*dz),nx,ny,nz
end
local function bad(n)return type(n)~='number'or n~=n or math.abs(n)>1e7 end
-- one piece of the victim's path (relative to the claimed spot) against the widened sector: the hit time, or nil (+ true when only a wall stopped it)
local function piece(c,blocked,ox,oy,oz,fx,fz,reach,cosHalf,ax,ay,az,at,bx,by,bz,bt)
 local u=Hitbox.Sweep(ax-ox,ay-oy,az-oz,bx-ox,by-oy,bz-oz,fx,fz,reach,cosHalf,C.Inner,C.Height)
 if not u then return nil,false end
 local hx,hy,hz=ax+(bx-ax)*u,ay+(by-ay)*u,az+(bz-az)*u
 if blocked and blocked(c,ox,oy+1.5,oz,hx,hy+1.5,hz)then return nil,true end
 return at+(bt-at)*u,false
end
-- The server's check of one claim. c = {Start (the swing's start, server time), Resolved (a claim was already handled for this swing), ViewTime,
-- OwnX, OwnY, OwnZ, LookX, LookZ, Swinger (the swinger's history), Victim (the victim's history)}; now = the server time it is handled;
-- blocked(c, ax,ay,az, bx,by,bz) -> true when a wall is between (optional). Returns ok, reason, matched victim time, rewind used.
function L.Validate(c,now,blocked)
 local view=c.ViewTime
 if type(view)~='number'or view~=view then return false,'bad time'end
 if c.Resolved then return false,'one claim per swing'end
 if view<c.Start+C.HitFrom-C.StrikeSlack or view>c.Start+C.HitTo+C.StrikeSlack then return false,'outside the strike'end
 if view>now+C.FutureSlack then return false,'from the future'end
 if now-view>C.MaxClaimDelay then return false,'too late'end
 local ox,oy,oz,fx,fz=c.OwnX,c.OwnY,c.OwnZ,c.LookX,c.LookZ
 if bad(ox)or bad(oy)or bad(oz)or bad(fx)or bad(fz)then return false,'bad numbers'end
 local fl=math.sqrt(fx*fx+fz*fz);if fl<.5 or fl>1.5 then return false,'bad facing'end;fx/=fl;fz/=fl
 -- 1. the swinger: the claimed spot lies on its own server path (ViewTime - OwnBack .. now, plus OwnAhead s of its newest velocity), facing that way
 local s=c.Swinger;if not s or s.Count<2 then return false,'no swinger history'end
 local best,bestLook=math.huge,-2;local nx,ny,nz=ox,oy,oz
 local from=view-C.OwnBack-1/C.HistoryHz
 local px,py,pz
 for k=s.Count-1,0,-1 do
  local i=idx(s,k)
  if s.T[i]>=from then
   local x,y,z=s.X[i],s.Y[i],s.Z[i]
   local d,ax,ay,az
   if px and not s.J[i]then d,ax,ay,az=pointSegment(ox,oy,oz,px,py,pz,x,y,z)else d,ax,ay,az=pointSegment(ox,oy,oz,x,y,z,x,y,z)end
   if d<best then best,nx,ny,nz=d,ax,ay,az end
   px,py,pz=x,y,z;bestLook=math.max(bestLook,s.LX[i]*fx+s.LZ[i]*fz)
  end
 end
 if px then
  local vx,vz=L.Velocity(s,s.T[idx(s,0)])
  local d,ax,ay,az=pointSegment(ox,oy,oz,px,py,pz,px+vx*C.OwnAhead,py,pz+vz*C.OwnAhead)
  if d<best then best,nx,ny,nz=d,ax,ay,az end
 end
 if best>C.OwnSlack then return false,'swinger not where it claims'end
 if bestLook<math.cos(math.rad(C.LookSlack))then return false,'swinger not facing that way'end
 -- (the claimed spot's few studs of slack may not reach through a wall either)
 if blocked and best>.25 and blocked(c,nx,ny+1.5,nz,ox,oy+1.5,oz)then return false,'through a wall'end
 -- 2. the victim, at the time the swinger's screen was showing: ViewTime - (the claim's travel time + the client's buffer), capped; +- TimeSlack
 local v=c.Victim;if not v or v.Count<1 then return false,'no victim history'end
 local back=math.min(C.MaxRewind,math.max(0,now-view)+C.Buffer)
 local t0,t1=view-back-C.TimeSlack,view-back+C.TimeSlack
 local vvx,vvz=L.Velocity(v,view-back);local svx,svz=L.Velocity(s,view)
 local rx,rz=vvx-svx,vvz-svz
 local reach=C.Reach+math.min(C.MaxBonus,C.BonusPerSpeed*math.sqrt(rx*rx+rz*rz))
 local cosHalf=math.cos(math.rad(C.HalfAngle+C.AngleSlack))
 -- 3. its path over [t0, t1] (t0, every stored sample inside, t1) against the sector around the claimed spot and facing; no wall in between
 local wall=false
 local lx,ly,lz=L.Sample(v,t0);local lt=t0
 for k=v.Count-1,0,-1 do
  local i=idx(v,k);local t=v.T[i]
  if t>=t0 and t<=t1 then
   local x,y,z=v.X[i],v.Y[i],v.Z[i]
   if v.J[i]then lx,ly,lz,lt=x,y,z,t end -- a new path starts here: nothing is swept along the jump
   local hit,w=piece(c,blocked,ox,oy,oz,fx,fz,reach,cosHalf,lx,ly,lz,lt,x,y,z,t)
   if hit then return true,'hit',hit,back end
   wall=wall or w;lx,ly,lz,lt=x,y,z,t
  end
 end
 local x,y,z=L.Sample(v,t1)
 local hit,w=piece(c,blocked,ox,oy,oz,fx,fz,reach,cosHalf,lx,ly,lz,lt,x,y,z,t1)
 if hit then return true,'hit',hit,back end
 return false,(wall or w)and'through a wall'or'out of reach',nil,back
end
return L
