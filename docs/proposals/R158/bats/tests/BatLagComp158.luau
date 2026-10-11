--!nocheck
-- R158 PROPOSAL (a preview for the owner, NOT in src/): bat hits that match what the swinger saw, at any speed.
-- Pure math on plain numbers (no Roblox services, no Vector3 allocation): the offline simulation and the anti-cheat test run it as it is,
-- and BatService / BatClient would call the same functions in the game.
--  * the server keeps a short position history per player (ring buffers of numbers, filled at HistoryHz, ~1 s; nothing allocated per frame);
--  * the swinger's client sweeps the bat's hit sector over the strike window (the target's PATH since the last frame, not one point) and claims
--    the first victim it saw, with the server time of that frame and its own position / facing;
--  * the server checks that claim against its OWN history: the swinger's claimed spot must lie on the swinger's own path, the victim is looked
--    up at the time the swinger's screen was showing (rewound by the claim's measured travel time + the client's interpolation delay, capped),
--    in reach (plus a small capped bonus along fast relative motion), in front, not through a wall, once per swing.
local L={}
L.Config={
 HitFrom=.24,HitTo=.36,       -- seconds after the swing starts: the bat's hot sweep (contact, bat straight ahead, at .30 = today's BatConfig.Windup)
 Reach=14,HalfAngle=75,Inner=4,Height=5, -- a 150-degree sector in front, 14 studs (today's box is 14 deep); a 4-stud circle all round (someone inside you); +-5 up/down (today's box)
 HistoryHz=30,HistorySize=32, -- ~1.07 s per player
 Buffer=.10,                  -- the swinger's interpolation delay for other players (assumed; measure it in Studio, see hitbox.md)
 MaxRewind=.30,               -- never judge a victim further back in time than this (s)
 TimeSlack=.08,               -- the victim may be matched anywhere within +-this of the rewound time (buffer / packet / frame uncertainty)
 AngleSlack=15,               -- extra half-angle on the server
 BonusPerSpeed=.02,MaxBonus=6,-- extra reach along fast relative motion: studs per stud/s, capped
 OwnSlack=4,OwnBack=.20,OwnAhead=.06, -- the claimed swinger spot: within OwnSlack of the swinger's server path from ViewTime-OwnBack to now (+ OwnAhead s extrapolated)
 LookSlack=45,                -- the claimed facing: within this many degrees of a facing the server saw in that same span
 MaxClaimDelay=.50,           -- a claim that reaches the server later than this after its ViewTime is refused
 Step=2,MaxSubSteps=32,       -- path sub-steps (studs) and their cap per segment
}
local C=L.Config
-- History -------------------------------------------------------------------------------------------------------------------------------------
function L.History(size)
 size=size or C.HistorySize
 return {N=size,Head=0,Count=0,Last=-math.huge,T=table.create(size,0),X=table.create(size,0),Y=table.create(size,0),Z=table.create(size,0),
  LX=table.create(size,0),LZ=table.create(size,-1)}
end
-- t: server time; (x,y,z): root position; (lx,lz): flat facing. Returns true when a sample was stored (at most HistoryHz per second).
function L.Record(h,t,x,y,z,lx,lz,force)
 if not force and t-h.Last<1/C.HistoryHz-1e-6 then return false end
 local i=h.Head%h.N+1;h.Head=i;if h.Count<h.N then h.Count+=1 end;h.Last=t
 h.T[i]=t;h.X[i]=x;h.Y[i]=y;h.Z[i]=z;h.LX[i]=lx;h.LZ[i]=lz
 return true
end
local function idx(h,k)return (h.Head-1-k)%h.N+1 end -- k = 0 newest .. Count-1 oldest
-- position at server time t (linear between samples; clamped to the oldest / newest sample)
function L.Sample(h,t)
 if h.Count==0 then return nil end
 local newest=idx(h,0)
 if t>=h.T[newest]then return h.X[newest],h.Y[newest],h.Z[newest],h.LX[newest],h.LZ[newest]end
 for k=1,h.Count-1 do
  local a=idx(h,k);local b=idx(h,k-1)
  if t>=h.T[a]then
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
-- Geometry ------------------------------------------------------------------------------------------------------------------------------------
-- (dx,dy,dz) = target minus swinger; (fx,fz) = the swinger's flat facing, unit length
function L.InSector(dx,dy,dz,fx,fz,reach,cosHalf,inner,height)
 if dy>height or dy<-height then return false end
 local d2=dx*dx+dz*dz
 if d2<=inner*inner then return true end
 if d2>reach*reach then return false end
 return dx*fx+dz*fz>=cosHalf*math.sqrt(d2)
end
-- the relative path from (a) to (b) against the sector; nil or the fraction 0..1 of the first hit point
function L.Sweep(ax,ay,az,bx,by,bz,fx,fz,reach,cosHalf,inner,height)
 local ex,ey,ez=bx-ax,by-ay,bz-az
 local n=math.clamp(math.ceil(math.sqrt(ex*ex+ey*ey+ez*ez)/C.Step),1,C.MaxSubSteps)
 for i=0,n do
  local u=i/n
  if L.InSector(ax+ex*u,ay+ey*u,az+ez*u,fx,fz,reach,cosHalf,inner,height)then return u end
 end
 return nil
end
-- The swinger's client, once per rendered frame inside [Start+HitFrom, Start+HitTo]: prev / now = the target's position on this screen at the
-- previous / this frame minus the swinger's own position at those frames. Returns nil, or the fraction 0..1 of the frame at which the path
-- first touched the sector: the claim then carries THAT moment (ViewTime = previous frame + fraction x frame time) and the swinger's own
-- position at that moment (a fast swinger can pass the victim inside one frame; the frame's end would already be past it).
function L.ClientFrame(prx,pry,prz,rx,ry,rz,fx,fz)
 return L.Sweep(prx,pry,prz,rx,ry,rz,fx,fz,C.Reach,math.cos(math.rad(C.HalfAngle)),C.Inner,C.Height)
end
-- Server check of one claim ------------------------------------------------------------------------------------------------------------------
-- c = {Start (the swing's start, server time), Resolved (a claim was already handled), ViewTime, OwnX,OwnY,OwnZ, LookX,LookZ,
--      Swinger = the swinger's history, Victim = the victim's history, Blocked = function(ax,ay,az,bx,by,bz) -> true when a wall is between (optional)}
-- now = the server time the claim is handled. Returns ok, reason, matched time, rewind used.
local function pointSegment(px,py,pz,ax,ay,az,bx,by,bz)
 local ex,ey,ez=bx-ax,by-ay,bz-az;local l2=ex*ex+ey*ey+ez*ez
 local u=l2>1e-9 and math.clamp(((px-ax)*ex+(py-ay)*ey+(pz-az)*ez)/l2,0,1)or 0
 local dx,dy,dz=px-(ax+ex*u),py-(ay+ey*u),pz-(az+ez*u);return math.sqrt(dx*dx+dy*dy+dz*dz)
end
function L.Validate(c,now)
 local view=c.ViewTime
 if type(view)~='number'or view~=view then return false,'bad time'end
 if c.Resolved then return false,'one claim per swing'end
 if view<c.Start+C.HitFrom-.05 or view>c.Start+C.HitTo+.05 then return false,'outside the strike'end
 if view>now+.02 then return false,'from the future'end
 if now-view>C.MaxClaimDelay then return false,'too late'end
 local ox,oy,oz,fx,fz=c.OwnX,c.OwnY,c.OwnZ,c.LookX,c.LookZ
 for _,n in ipairs({ox,oy,oz,fx,fz})do if type(n)~='number'or n~=n or math.abs(n)>1e7 then return false,'bad numbers'end end
 local fl=math.sqrt(fx*fx+fz*fz);if fl<.5 or fl>1.5 then return false,'bad facing'end;fx/=fl;fz/=fl
 -- 1. the swinger: the claimed spot lies on its own server path (ViewTime-OwnBack .. now, plus OwnAhead s of its newest velocity)
 local s=c.Swinger;if not s or s.Count<2 then return false,'no swinger history'end
 local best,bestLook=math.huge,-2;local from=view-C.OwnBack
 local px,py,pz;local cosLook=math.cos(math.rad(C.LookSlack))
 for k=s.Count-1,0,-1 do
  local i=idx(s,k)
  if s.T[i]>=from-1/C.HistoryHz then
   local x,y,z=s.X[i],s.Y[i],s.Z[i]
   if px then best=math.min(best,pointSegment(ox,oy,oz,px,py,pz,x,y,z))else best=math.min(best,pointSegment(ox,oy,oz,x,y,z,x,y,z))end
   px,py,pz=x,y,z;bestLook=math.max(bestLook,s.LX[i]*fx+s.LZ[i]*fz)
  end
 end
 if px then
  local vx,vz=L.Velocity(s,s.T[idx(s,0)])
  best=math.min(best,pointSegment(ox,oy,oz,px,py,pz,px+vx*C.OwnAhead,py,pz+vz*C.OwnAhead))
 end
 if best>C.OwnSlack then return false,'swinger not where it claims'end
 if bestLook<cosLook then return false,'swinger not facing that way'end
 -- 2. the victim, at the time the swinger's screen was showing: ViewTime - (the claim's travel time + the client's buffer), capped
 local v=c.Victim;if not v or v.Count<1 then return false,'no victim history'end
 local back=math.min(C.MaxRewind,math.max(0,now-view)+C.Buffer)
 local t0,t1=view-back-C.TimeSlack,view-back+C.TimeSlack
 local vvx,vvz=L.Velocity(v,view-back);local svx,svz=L.Velocity(s,view)
 local rel=math.sqrt((vvx-svx)^2+(vvz-svz)^2)
 local reach=C.Reach+math.min(C.MaxBonus,C.BonusPerSpeed*rel)
 local cosHalf=math.cos(math.rad(C.HalfAngle+C.AngleSlack))
 -- walk the victim's path over [t0,t1]: t0, every stored sample inside, t1
 local lx,ly,lz=L.Sample(v,t0);local lt=t0
 local function try(t)
  local x,y,z=L.Sample(v,t)
  local u=L.Sweep(lx-ox,ly-oy,lz-oz,x-ox,y-oy,z-oz,fx,fz,reach,cosHalf,C.Inner,C.Height)
  local blocked=false
  if u then
   local ht=lt+(t-lt)*u;local hx,hy,hz=lx+(x-lx)*u,ly+(y-ly)*u,lz+(z-lz)*u
   if not(c.Blocked and c.Blocked(ox,oy+1.5,oz,hx,hy+1.5,hz))then return ht end
   blocked=true
  end
  lx,ly,lz,lt=x,y,z,t
  return nil,blocked and'wall'or nil
 end
 local wall=false
 for k=v.Count-1,0,-1 do
  local i=idx(v,k);local t=v.T[i]
  if t>t0 and t<t1 then local hit,why=try(t);if hit then return true,'hit',hit,back end;if why then wall=true end end
 end
 local hit,why=try(t1);if hit then return true,'hit',hit,back end;if why then wall=true end
 return false,wall and'through a wall'or'out of reach',nil,back
end
return L
