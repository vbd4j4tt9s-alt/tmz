-- R151 (owner): "for the snow make sure the snow piles are visible throughout and not just when players walk into an area that it appears" and
-- "snow piles can be bigger and more combined so we don't have to deal with that much performance demand too". Pure layout (no Instances, no
-- services, no randomness) of the blizzard's snow over the WHOLE hub, used by WeatherWorld149.client.lua. R149 laid small patches in a pooled
-- radius around the player (130 / 100 / 70 studs by tier), so the snow only existed where you stood. Now:
--
--  LAYOUT  one fixed world layout per map (every client builds the same drifts: a hash of wall / fence segments and grid cells, never the
--          player's position), over the hub floor inside the walls: big snow BANKS along the walls (thicker), a big DRIFT in every corner,
--          banks along the outside of every base's fence, broad drifts in the OPEN (thinner, fewer), a light sprinkle INSIDE the bases on the
--          free pad. A drift is 1..4 overlapping flat ellipses (lobes: a long main lobe and bumps for a ragged edge), far bigger than the R149
--          patches (a wall bank runs ~40-60 studs), so the hub carries ~100 drifts instead of ~1,500 small patches (if it were all covered).
--  AVOID   the client drops every lobe that reaches an avoided thing (garden beds, the bases' paths, treadmills, mystery pedestals, the market,
--          Verity's dais, the hub displays, the leaderboards, ground titles, R151 festival streets / plazas / fountain / arches, anything tagged
--          'SnowAvoid', shovel holes, packs); a drift whose main lobe is avoided is dropped. The ground under every lobe is raycast once (cached).
--  HEIGHT  every disc lies Rise above its ground; overlapping drifts never share a plane: a drift's lobes get thicknesses one Unit (.004)
--          apart, and a drift that overlaps an earlier one is given another height slot (Assign: greedy, its top planes all differ by at least
--          .004 from every overlapping drift's). Bottoms all lie at ground + Rise (no floating gap under thicker banks).
--  LOD     lobes by distance band (tier config: all lobes near, the two biggest in the middle band, the main lobe alone - stretched by FarScale
--          to stand for the blob - far away); the worst case over the hub stays inside the tier's part budget (Budget). Tier 1 skips the
--          lowest-priority drifts (inside the bases).
--  FADE    as R149: every drift follows WeatherWorld149.Level of the one snow history (fade in 10-20 s, out 20-40 s).
local W=require(script.Parent.WeatherWorld149)
local H={Version=151}
local floor,max,min,sqrt,sin,cos,abs,pi=math.floor,math.max,math.min,math.sqrt,math.sin,math.cos,math.abs,math.pi
local hash,unit=W.Hash,W.Unit

-- The hub when the map's parts have not streamed in yet (the owner's place, R150): inner faces of the 48-stud walls, the floor top, the
-- track gap between the front walls. Base pads: none (they are read from the map; a missing base simply has no fence banks yet).
H.Default={X0=-335,X1=335,Z0=-618,Z1=-104,Top=4,Gap=94}
-- Drift kinds. Pri = keep order under a budget (tier MinPri), Lobes = most lobes, Th = thickness of the main lobe and Taper = each lobe's
-- share of it (the main lobe, against the wall, is the deepest; the bumps in front of it step down: a bank reads as a pile from across the
-- hub, its white side showing), Far = stretch of the lone main lobe at long range. Seg = segment length along a wall / fence, Len / Wid =
-- half length / half width of the main lobe, R = main radius, Chance per segment / cell.
H.Kinds={
 corner={Pri=5,Lobes=4,Th=.42,Taper={1,.72,.64,.45},Far=1.15,R={20,26}},
 wall={Pri=4,Lobes=4,Th=.3,Taper={1,.64,.56,.36},Far=1.12,Seg=60,Chance=.97,Len={22,30},Wid={7,11},MinWid=2.4},
 fence={Pri=3,Lobes=3,Th=.2,Taper={1,.64,.54},Far=1.12,Seg=52,Chance=.88,Len={16,24},Wid={5,8},Out=1.4},
 open={Pri=2,Lobes=3,Th=.07,Taper={1,.8,.62},Far=1.2,Cell=38,Chance=.78,R={10,16},Clear=20},
 inner={Pri=1,Lobes=2,Th=.06,Taper={1,.75},Far=1.15,Cell=34,Chance=.5,R={3.5,6}},
}
H.Rise=.07            -- the discs' bottoms over their ground (R149 weather patches: .07)
H.Unit=.004           -- one height slot: the smallest gap between two top planes (fix round A)
H.Slots=80            -- slots a drift may be lifted by to clear the drifts it overlaps, the surfaces in Keep and the lawns (R154: 80 x .004 = .32 at most; 40 did for all but the lawns)
H.FenceOut=3.6        -- a base's fence stands this far outside its pad (GardenFenceArt), when the fence itself is not there to measure
H.TrackMargin=2       -- drifts stay this far off the track rectangle (WeatherWorld149.Outside)
H.FadeIn,H.FadeOut=W.Patch.FadeIn,W.Patch.FadeOut -- (one source: 10-20 s in, 20-40 s out, WeatherWorld149.Patch)
-- Containers of the map whose ground-level parts (streets, plazas, curbs, a fountain basin, arch feet) keep the snow off, part by part: the
-- R151 Seed Festival Square (base_area.md) and its prototype's folder names. Anything else can opt in with the CollectionService tag
-- 'SnowAvoid' (whole box) or offer itself as ground with 'SnowGround'.
H.AvoidFolders={'SeedFestivalSquare','SeedFestivalSquare151','FestivalSquare151','HubDressing151','R151HubDressing'}

-- Tiers (ClientFxBudget 3 best .. 1 lowest; FastMode = 1): Discs = part budget, Lobes per band (< Near, < Mid, farther), MinPri = the lowest
-- drift priority shown, Bind = drifts checked / bound per weather step, Reshape = LOD changes per step, Keep = the hub's snow is kept while the
-- player is within this many studs of the hub (beyond, on the track behind the 48-stud walls, it is released and comes back on return).
H.Tiers={
 [3]={Discs=340,Lobes={4,2,1},Near=120,Mid=240,MinPri=1,Bind=8,Reshape=6,Keep=260,Hyst=12},
 [2]={Discs=230,Lobes={3,2,1},Near=70,Mid=140,MinPri=2,Bind=6,Reshape=4,Keep=200,Hyst=10},
 [1]={Discs=170,Lobes={2,1,1},Near=45,Mid=0,MinPri=2,Bind=4,Reshape=3,Keep=150,Hyst=8},
}
function H.Tier(t)return H.Tiers[floor(tonumber(t)or 1)]or H.Tiers[1]end
-- Lobes wanted at distance d (with the band edges moved out by hyst for a drift that already shows more lobes: no flicker on a band edge).
function H.Lobes(cfg,d,count,shown)
 local l=cfg.Lobes;local h=(shown and shown>0)and cfg.Hyst or 0
 local n
 if d<cfg.Near+((shown or 0)>=l[1]and h or 0)then n=l[1]
 elseif d<cfg.Mid+((shown or 0)>=l[2]and h or 0)then n=l[2]else n=l[3]end
 return min(n,count)
end

-- Geometry ------------------------------------------------------------------------------------------------------------------------------
-- hub = {X0, X1, Z0, Z1 (inner faces of the walls), Top (floor top), Gap (half width of the track gap in the front wall), Pads = {{X0, X1,
-- Z0, Z1 (pad), Top, FX0, FX1, FZ0, FZ1 (its fence), Index}}, Area = WeatherWorld149.Area (the track rectangle)}. The walls of the hub, as
-- segments with an inward normal: back, left, right, front left, front right.
local function walls(hub)
 return{
  {hub.X0,hub.Z0,hub.X1,hub.Z0,0,1},          -- back (z = Z0, facing +Z)
  {hub.X0,hub.Z0,hub.X0,hub.Z1,1,0},          -- left (x = X0, facing +X)
  {hub.X1,hub.Z0,hub.X1,hub.Z1,-1,0},         -- right
  {hub.X0,hub.Z1,-hub.Gap,hub.Z1,0,-1},       -- front left (z = Z1, facing -Z)
  {hub.Gap,hub.Z1,hub.X1,hub.Z1,0,-1},        -- front right
 }
end
H.Walls=walls
local function inRect(x,z,x0,x1,z0,z1,m)return x>x0-m and x<x1+m and z>z0-m and z<z1+m end
local function distRect(x,z,x0,x1,z0,z1)local dx=max(x0-x,0,x-x1);local dz=max(z0-z,0,z-z1);return sqrt(dx*dx+dz*dz)end
-- distance from (x, z) to the nearest hub wall face
local function wallDist(hub,x,z)
 local d=min(x-hub.X0,hub.X1-x,z-hub.Z0)
 if abs(x)>=hub.Gap then d=min(d,hub.Z1-z)end
 return d
end
H.WallDist=wallDist
-- How far out from a wall point (mx, mz) (inward normal (nx, nz), along (tx, tz) for +-L) the floor is free of base fences.
local function freeOut(hub,mx,mz,tx,tz,nx,nz,L)
 local free=math.huge
 for _,p in ipairs(hub.Pads or{})do
  for t=-1.4,1.41,.35 do -- (the bumps reach 1.35 x the main lobe's half length along the wall)
   local x,z=mx+tx*L*t,mz+tz*L*t
   -- distance along the normal to the fence rectangle, when the ray from (x, z) meets it
   local d
   if nx~=0 then
    if z>=p.FZ0 and z<=p.FZ1 then d=nx>0 and p.FX0-x or x-p.FX1 end
   else
    if x>=p.FX0 and x<=p.FX1 then d=nz>0 and p.FZ0-z or z-p.FZ1 end
   end
   if d and d>=0 then free=min(free,d)end
  end
 end
 return free
end
local function nearPad(hub,x,z,m)
 for _,p in ipairs(hub.Pads or{})do if inRect(x,z,p.FX0,p.FX1,p.FZ0,p.FZ1,m)then return p end end
 return nil
end

-- Specs ---------------------------------------------------------------------------------------------------------------------------------
-- A drift record: Key, Kind, Pri, X, Z, N lobes (LX, LZ offsets, LA half length along (sin LY, cos LY), LB half width, LY yaw), Extent,
-- Reach (the farthest a lobe reaches, incl. the stretched lone lobe), Th (main thickness), Slot (height slot), Shade, DIn, DOut, Far,
-- Pad (index of the base pad it lies on, or 0 = the hub floor).
local function newSpec(out,kind,key)
 local n=out.N+1;out.N=n
 local s=out[n]
 if not s then s={LX={},LZ={},LA={},LB={},LY={}};out[n]=s end
 local K=H.Kinds[kind]
 s.Key=key;s.Kind=kind;s.Pri=K.Pri;s.Th=K.Th;s.Far=K.Far;s.N=0;s.Pad=0;s.Slot=0
 return s
end
local function addLobe(s,ox,oz,a,b,yaw)
 local k=s.N+1;s.N=k
 s.LX[k],s.LZ[k],s.LA[k],s.LB[k],s.LY[k]=ox,oz,a,b,yaw
end
local function finish(s,i,j,salt)
 local e=0
 for k=1,s.N do e=max(e,sqrt(s.LX[k]^2+s.LZ[k]^2)+max(s.LA[k],s.LB[k]))end
 s.Extent=e;s.Reach=max(e,max(s.LA[1],s.LB[1])*s.Far)
 s.Shade=1+hash(i,j,salt+6)%#W.Shades
 s.DIn=H.FadeIn[1]+(H.FadeIn[2]-H.FadeIn[1])*unit(i,j,salt+7);s.DOut=H.FadeOut[1]+(H.FadeOut[2]-H.FadeOut[1])*unit(i,j,salt+8)
end
local function lerp(r,u)return r[1]+(r[2]-r[1])*u end

-- A bank along a straight edge: (cx, cz) the segment middle, (tx, tz) along the edge, (nx, nz) away from it; main lobe half length L along
-- the edge, half width w; bumps along it, a little out, for a ragged front. Lobes after the first are ordered biggest first (LOD keeps them).
local function bank(s,i,j,salt,L,w,tx,tz,nx,nz,count,tilt)
 tilt=tilt or 1 -- (0: a bank squeezed into a narrow alley lies straight, its bumps parallel to the wall)
 local yaw=math.atan2(tx,tz)
 addLobe(s,0,0,L,w,yaw+(unit(i,j,salt+1)-.5)*.06*tilt)
 for k=2,count do
  local side=(k%2==0)and 1 or-1
  local along=side*L*(.45+.3*unit(i,j,salt+10*k))
  local outward=w*(.15+.45*unit(i,j,salt+10*k+1))
  local a=L*(.38+.22*unit(i,j,salt+10*k+2));local b=w*(.7+.35*unit(i,j,salt+10*k+3))
  if k==4 then along*=.25;outward=w*(.55+.35*unit(i,j,salt+43));a=L*.3;b=w*.62 end -- a smaller round bump out in front of the middle
  addLobe(s,tx*along+nx*outward,tz*along+nz*outward,a,b,yaw+(unit(i,j,salt+10*k+4)-.5)*.5*tilt)
 end
end
-- A round-ish drift: main radius r, bumps around it.
local function blob(s,i,j,salt,r,count)
 addLobe(s,0,0,r,r*(.62+.3*unit(i,j,salt+4)),unit(i,j,salt+5)*pi)
 for k=2,count do
  local ang=unit(i,j,salt+10*k)*2*pi;local off=r*(.5+.25*unit(i,j,salt+10*k+1))
  local a=r*(.5+.22*unit(i,j,salt+10*k+2));local b=a*(.55+.35*unit(i,j,salt+10*k+3))
  addLobe(s,cos(ang)*off,sin(ang)*off,a,b,unit(i,j,salt+10*k+5)*pi)
 end
end

-- Layout(hub, out) -> out = {N = drift count, [k] = spec}. Deterministic: the same hub gives the same drifts (keys, places, sizes, slots).
function H.Layout(hub,out)
 out=out or{};out.N=0
 local area=hub.Area
 local function keep(s)
  -- nothing that reaches the track, nothing past the walls' inner faces (a little into a wall is fine: the wall hides it)
  if not W.Outside(area,s.X,s.Z,s.Reach,H.TrackMargin)then out.N-=1;return false end
  return true
 end
 -- corners: the four inner corners of the walls
 local K=H.Kinds.corner
 local corners={{hub.X0,hub.Z0,1,1},{hub.X1,hub.Z0,-1,1},{hub.X0,hub.Z1,1,-1},{hub.X1,hub.Z1,-1,-1}}
 for c,v in ipairs(corners)do
  local s=newSpec(out,'corner',1000+c)
  local r=lerp(K.R,unit(c,0,901))
  s.X,s.Z=v[1]+v[3]*r*.42,v[2]+v[4]*r*.42;s.AX,s.AZ=v[1],v[2]
  -- main round drift + two banks running off along each wall + a bump out of the corner
  addLobe(s,0,0,r,r*.82,unit(c,0,902)*pi)
  addLobe(s,v[3]*r*.95,-v[4]*r*.18,r*.62,r*.36,pi/2)
  addLobe(s,-v[3]*r*.18,v[4]*r*.95,r*.62,r*.36,0)
  addLobe(s,v[3]*r*.55,v[4]*r*.55,r*.42,r*.34,unit(c,0,903)*pi)
  finish(s,c,0,900)
  keep(s)
 end
 -- wall banks: segments of Seg studs along every wall (the corners already hold a drift), chance per segment
 K=H.Kinds.wall
 for wi,wl in ipairs(walls(hub))do
  local x0,z0,x1,z1,nx,nz=wl[1],wl[2],wl[3],wl[4],wl[5],wl[6]
  local len=sqrt((x1-x0)^2+(z1-z0)^2);local tx,tz=(x1-x0)/len,(z1-z0)/len
  local n=max(1,floor(len/K.Seg+.5));local seg=len/n
  for k=0,n-1 do
   if unit(k,wi,401)<K.Chance then
    local L=min(lerp(K.Len,unit(k,wi,402)),seg*.5);local w=lerp(K.Wid,unit(k,wi,403))
    local at=(k+.5+(unit(k,wi,404)-.5)*.3)*seg
    local mx,mz=x0+tx*at,z0+tz*at
    -- a base's fence close to the wall (the 6-stud alley beside a base): the bank is narrowed to fit the gap (its bumps reach 2.2 x its
    -- half width out from the wall face); too narrow a gap gets no bank
    local free=freeOut(hub,mx,mz,tx,tz,nx,nz,L)
    local tilt=1
    if free<w*2.2 then w=free/2.4;tilt=0 end
    if w>=K.MinWid then
     local s=newSpec(out,'wall',2000+wi*100+k)
     s.X,s.Z=mx+nx*w*.5,mz+nz*w*.5;s.AX,s.AZ=mx,mz
     bank(s,k,wi,410,L,w,tx,tz,nx,nz,K.Lobes,tilt)
     finish(s,k,wi,400)
     keep(s)
    end
   end
  end
 end
 -- fence banks: along the outside of each base's fence, sides facing the hub (a side within 16 studs of a wall is the wall bank's)
 K=H.Kinds.fence
 for _,p in ipairs(hub.Pads or{})do
  local sides={{p.FX0,p.FZ0,p.FX1,p.FZ0,0,-1},{p.FX0,p.FZ1,p.FX1,p.FZ1,0,1},{p.FX0,p.FZ0,p.FX0,p.FZ1,-1,0},{p.FX1,p.FZ0,p.FX1,p.FZ1,1,0}}
  for si,sd in ipairs(sides)do
   local x0,z0,x1,z1,nx,nz=sd[1],sd[2],sd[3],sd[4],sd[5],sd[6]
   local len=sqrt((x1-x0)^2+(z1-z0)^2);local tx,tz=(x1-x0)/len,(z1-z0)/len
   local mx,mz=(x0+x1)/2,(z0+z1)/2
   if wallDist(hub,mx+nx*2,mz+nz*2)>16 then
    local n=max(1,floor(len/K.Seg+.5));local seg=len/n
    for k=0,n-1 do
     local hi,hj=k+p.Index*16,si
     if unit(hi,hj,501)<K.Chance then
      local L=min(lerp(K.Len,unit(hi,hj,502)),seg*.48);local w=lerp(K.Wid,unit(hi,hj,503))
      local at=(k+.5+(unit(hi,hj,504)-.5)*.3)*seg
      local cx,cz=x0+tx*at+nx*(K.Out+w*.75),z0+tz*at+nz*(K.Out+w*.75)
      -- not into another base's fence, not against a wall (the alley between two bases holds both bases' banks)
      if not nearPad(hub,cx,cz,w*.5)and wallDist(hub,cx,cz)>w then
       local s=newSpec(out,'fence',3000+p.Index*100+si*20+k)
       s.X,s.Z=cx,cz;s.AX,s.AZ=x0+tx*at,z0+tz*at
       bank(s,hi,hj,510,L,w,tx,tz,nx,nz,K.Lobes)
       finish(s,hi,hj,500)
       keep(s)
      end
     end
    end
   end
  end
 end
 -- open drifts: a jittered grid over the hub, away from the walls (their banks) and the bases
 K=H.Kinds.open
 local C=K.Cell
 for i=floor(hub.X0/C),floor(hub.X1/C)do for j=floor(hub.Z0/C),floor(hub.Z1/C)do
  if unit(i,j,601)<K.Chance then
   local r=lerp(K.R,unit(i,j,602))
   local x=(i+.5)*C+(unit(i,j,603)-.5)*C*.55;local z=(j+.5)*C+(unit(i,j,604)-.5)*C*.55
   if x>hub.X0 and x<hub.X1 and z>hub.Z0 and z<hub.Z1 and wallDist(hub,x,z)>K.Clear and not nearPad(hub,x,z,r*.7+2)then
    local s=newSpec(out,'open',100000+(i+64)*128+(j+64))
    s.X,s.Z=x,z;s.AX,s.AZ=x,z
    blob(s,i,j,610,r,K.Lobes)
    finish(s,i,j,600)
    keep(s)
   end
  end
 end end
 -- inside the bases: a light sprinkle on the free pad (the beds, paths, treadmill, pedestal are avoided at run time)
 K=H.Kinds.inner
 C=K.Cell
 for _,p in ipairs(hub.Pads or{})do
  for i=0,floor((p.X1-p.X0)/C)-1 do for j=0,floor((p.Z1-p.Z0)/C)-1 do
   local hi,hj=i+p.Index*64,j
   if unit(hi,hj,701)<K.Chance then
    local r=lerp(K.R,unit(hi,hj,702))
    local x=p.X0+(i+.5)*C+(unit(hi,hj,703)-.5)*C*.5;local z=p.Z0+(j+.5)*C+(unit(hi,hj,704)-.5)*C*.5
    if x-r*1.6>p.X0 and x+r*1.6<p.X1 and z-r*1.6>p.Z0 and z+r*1.6<p.Z1 then
     local s=newSpec(out,'inner',200000+p.Index*4096+i*64+j)
     s.X,s.Z=x,z;s.AX,s.AZ=x,z;s.Pad=p.Index
     blob(s,hi,hj,710,r,K.Lobes)
     finish(s,hi,hj,700)
     keep(s)
    end
   end
  end end
 end
 H.Assign(out)
 return out
end

-- Height slots ------------------------------------------------------------------------------------------------------------------------------
-- Lobe k of a drift is Base(k) + Slot units (of .004) thick, Base(k) = its kind's Th x Taper[k] (the main lobe the deepest, the bumps stepping
-- down); its top plane lies there (bottom at ground + Rise for all). Within a drift the bases differ (Taper), and the slot lifts the whole
-- drift: two drifts whose reach circles overlap (and lie on the same ground) never share a top plane - each takes the lowest slot whose planes
-- are all clear of every earlier overlapping drift's planes. The surfaces a drift must also stay clear of (HubSnow151.Keep: the R151 streets
-- 4.20 / plazas 4.14, 4.26 / curbs 4.32 / run-up 4.06, grass patches 4.07 / 4.12, the floor itself) are never a top plane either: a slot
-- that would put a lobe within KeepGap of one is skipped.
-- R154 (owner: "remove the cases of z fighting in the hub area too"):
--  * the lawns: a drift on the hub floor whose reach meets a grass disc of HubLifeArt151 (A.PatchDiscs: the lawns as pure data, their
--    discs on the planes 4.07 - 4.27) keeps every top plane at least LawnGap from that disc's top - lifted by more slots where it must (a
--    drift top .018 - .046 over a raised grass disc flickered). The drifts lie on the lawns a little thicker there; nothing else moves.
--  * drifts that overlap share one shade (Assign): two overlapping drifts are only .004 apart at least, a gap only a look-alike pair may
--    have (two whites 11 / 255 apart flickered there).
local function base(s,k)local K=H.Kinds[s.Kind];return floor(s.Th*(K.Taper[k]or K.Taper[#K.Taper])/H.Unit+.5)end
function H.Plane(s,k)return base(s,k)+s.Slot end
H.Keep={4.06,4.07,4.12,4.14,4.20,4.26,4.32} -- tops of the hub's flat things (relative to a floor top of 4: R151 HubDecor151 / HubLifeArt151)
H.KeepGap=.012
H.LawnGap=.049 -- (R152's MIN_GAP: the depth rule's .043 at 300 studs plus the quantisation)
local lawnList
function H.Lawns() -- HubLifeArt151's grass discs {X, Z, R, Top} (empty when it is not there)
 if lawnList==nil then
  lawnList={}
  local art=script.Parent:FindFirstChild('HubLifeArt151')
  if art then
   local ok,A=pcall(require,art)
   if ok and type(A)=='table'and A.PatchDiscs then local ok2,list=pcall(A.PatchDiscs);if ok2 and type(list)=='table'then lawnList=list end end
  end
 end
 return lawnList
end
local function clashes(s,a,out)
 for k=1,s.N do
  local p=base(s,k)+s.Slot
  local top=H.Rise+p*H.Unit -- above the ground
  for _,y in ipairs(H.Keep)do if abs(4+top-y)<H.KeepGap then return true end end
 end
 if s.Pad==0 then for _,g in ipairs(H.Lawns())do
  if(g.X-s.X)^2+(g.Z-s.Z)^2<(g.R+s.Reach)^2 then
   for k=1,s.N do if abs(4+H.Rise+(base(s,k)+s.Slot)*H.Unit-g.Top)<H.LawnGap then return true end end
  end
 end end
 for b=1,a-1 do
  local t=out[b]
  if t.Pad==s.Pad and(t.X-s.X)^2+(t.Z-s.Z)^2<(t.Reach+s.Reach)^2 then
   for k=1,s.N do local p=base(s,k)+s.Slot
    for l=1,t.N do if base(t,l)+t.Slot==p then return true end end
   end
  end
 end
 return false
end
function H.Assign(out)
 -- R154: drifts that overlap (in a chain) share one white, the shade of the first of them
 local root={}
 local function find(i)while root[i]~=i do root[i]=root[root[i]];i=root[i]end;return i end
 for a=1,out.N do root[a]=a end
 for a=2,out.N do local s=out[a]
  for b=1,a-1 do local t=out[b]
   if t.Pad==s.Pad and(t.X-s.X)^2+(t.Z-s.Z)^2<(t.Reach+s.Reach)^2 then local ra,rb=find(a),find(b);if ra<rb then root[rb]=ra elseif rb<ra then root[ra]=rb end end
  end
 end
 for a=1,out.N do out[a].Shade=out[find(a)].Shade end
 for a=1,out.N do
  local s=out[a];s.Slot=0
  while s.Slot<H.Slots and clashes(s,a,out)do s.Slot+=1 end
 end
end
-- Thickness of lobe k of drift s.
function H.Thickness(s,k)return(base(s,k)+s.Slot)*H.Unit end

-- Ellipse tests -----------------------------------------------------------------------------------------------------------------------------
-- Does lobe k of s (stretched by f) reach the box centred at (bx, bz) with half sizes hx (along its own X axis (ux, uz)) and hz (along
-- (-uz, ux))? Exact for an ellipse and a box: the box's corners in the ellipse's unit space form a parallelogram; they meet when the
-- ellipse's centre is inside the box or one of the parallelogram's edges comes within 1 of the origin. Allocates nothing.
local function segNear(ax,ay,bx,by)
 local dx,dy=bx-ax,by-ay;local l2=dx*dx+dy*dy
 local t=l2>0 and max(0,min(1,-(ax*dx+ay*dy)/l2))or 0
 local px,py=ax+dx*t,ay+dy*t
 return px*px+py*py<=1
end
-- a box corner at (box centre - ellipse centre) = (dx, dz) plus (ox, oz), in the ellipse's unit space
local function toUnit(dx,dz,ox,oz,sy,cy,a,b)
 local x,z=ox-dx,oz-dz
 return(x*sy+z*cy)/a,(-x*cy+z*sy)/b
end
function H.LobeHitsBox(s,k,f,bx,bz,hx,hz,ux,uz)
 local cx,cz=s.X+s.LX[k],s.Z+s.LZ[k];local a,b=s.LA[k]*f,s.LB[k]*f
 -- the ellipse centre in the box's frame
 local dx,dz=cx-bx,cz-bz
 local lx,lz=dx*ux+dz*uz,-dx*uz+dz*ux
 if abs(lx)<=hx and abs(lz)<=hz then return true end
 local r=max(a,b)
 if abs(lx)>hx+r or abs(lz)>hz+r then return false end
 local sy,cy=sin(s.LY[k]),cos(s.LY[k])
 -- the four corners (world), then in unit space: u along (sy, cy) / a, v along (-cy, sy) / b
 local ex,ez=ux*hx,uz*hx;local gx,gz=-uz*hz,ux*hz
 local u1,v1=toUnit(dx,dz,-ex-gx,-ez-gz,sy,cy,a,b);local u2,v2=toUnit(dx,dz,ex-gx,ez-gz,sy,cy,a,b)
 local u3,v3=toUnit(dx,dz,ex+gx,ez+gz,sy,cy,a,b);local u4,v4=toUnit(dx,dz,-ex+gx,-ez+gz,sy,cy,a,b)
 return segNear(u1,v1,u2,v2)or segNear(u2,v2,u3,v3)or segNear(u3,v3,u4,v4)or segNear(u4,v4,u1,v1)
end
-- Does lobe k of s (stretched by f) reach the circle (x, z, r)? (the ellipse grown by r: a little generous at the ends, never short)
function H.LobeHitsCircle(s,k,f,x,z,r)
 local dx,dz=x-(s.X+s.LX[k]),z-(s.Z+s.LZ[k])
 local sy,cy=sin(s.LY[k]),cos(s.LY[k])
 local u=dx*sy+dz*cy;local v=-dx*cy+dz*sy
 local a,b=s.LA[k]*f+r,s.LB[k]*f+r
 return(u/a)^2+(v/b)^2<1
end
-- Worst-case part count of a layout for a tier (the most discs any player position over the hub asks for). step = probe spacing.
function H.Budget(layout,cfg,hub,step)
 local worst,wx,wz=0,0,0
 step=step or 20
 for x=hub.X0,hub.X1,step do for z=hub.Z0,hub.Z1,step do
  local n=0
  for k=1,layout.N do local s=layout[k]
   if s.Pri>=cfg.MinPri then n+=H.Lobes(cfg,sqrt((s.X-x)^2+(s.Z-z)^2),s.N,s.N)end
  end
  if n>worst then worst,wx,wz=n,x,z end
 end end
 return worst,wx,wz
end
return H
