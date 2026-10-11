--!nocheck
-- R154 preview check (not a game test): evaluates the proposed camera (cinecam154.luau) at 240 Hz over the Full Secret / Cosmic / King
-- timelines with the REAL RarePullRules (beats, poses, hero framing) and prints what the design doc quotes:
--  * comfort: the fastest turn of the view (degrees per second; cuts and the hit's 0.5 s shake left out, the shake reported on its own),
--    the biggest dutch tilt, the fastest zoom (a snap / ratchet is reported apart), the fastest move;
--  * every cut and the nearest sound cue (RarePullRules.SceneCues): a cut that is meant to land on a sound lands on its frame;
--  * the camera inside each stage's walls; the seed's share of the screen height from the hit on (16:9, 19.5:9, 4:3) and its distance from
--    the centre; the skip target (Climax - 0.02) is the still silence frame.
-- Turns and moves are counted where they can be seen (not under the black fades). Today's camera is measured the same way for comparison.
-- Run from a folder with the R151 test environment (see run_cinematic_preview.sh): luau check_camera154.luau
local W=require('./world');local R=W.R
local L=W.module('RarePullRules')
local Cam=require('./cinecam154')(R,L)
local V=R.Vector3.new
local HEAD=V(0,6.65,100);local LIVE=R.CFrame.lookAt(V(3.1,10.6,111.4),HEAD)
local BOX={[6]={-35,35,0,34,-35,35},[7]={-65,65,0,90,-75,55},[8]={-15,15,0,24,-13,35}}
local names={[6]='Secret',[7]='Cosmic',[8]='King'}
local HITSLOTS={Impact=true,GroundImpact=true,PackBurst=true,TitleSlam=true,PackShake=true,SecretGlitch=true,SecretVault=true,CosmicBoom=true,CosmicStar=true,KingBell=true,KingFanfare=true,Sparkle=true,SuckIn=true,Riser=true,Flight=true}
local function ang(a,b)return math.deg(math.acos(math.clamp(a:Dot(b),-1,1)))end
-- the black fade of RarePullCard:UpdateScene (0 = clear, 1 = black): a move under the black is not seen
local function fadeAt(t,tl)
 local function c01(x)return math.clamp(x,0,1)end
 if t>=tl.Cut and t<tl.SceneIn then return c01((t-tl.Cut)/math.max(.01,tl.SceneIn-tl.Cut-.05))
 elseif t>=tl.SceneIn and t<tl.SceneIn+.3 then return 1-c01((t-tl.SceneIn)/.3)
 elseif t>=tl.FloatEnd and t<tl.Back then return c01((t-tl.FloatEnd)/math.max(.01,tl.Back-tl.FloatEnd-.05))
 elseif t>=tl.Back then return 1-c01((t-tl.Back)/.35)end
 return 0
end
-- today's camera (R151 / R152: RarePullRules.Shot, the stage only; the world is the player's own camera) for comparison
local function today(rank,tl)
 local dt=1/240;local prev;local turn,turnAt,hit=0,0,0;local t=tl.SceneIn-.05
 while t<tl.Back do
  local e,tg=L.Shot(rank,'Full',t,tl);local f=(tg-e).Unit
  if prev and fadeAt(t,tl)<.8 then local v=ang(prev,f)/dt
   if t>=tl.Climax and t<tl.Climax+.5 then hit=math.max(hit,v)elseif v>turn then turn,turnAt=v,t end end
  prev=f;t+=dt
 end
 return turn,turnAt,hit
end
for rank=6,8 do
 local tl=L.Timeline(rank,'Full');local dt=1/240
 local cues=L.SceneCues(rank,tl)
 local prev=nil;local cuts={}
 local maxTurn,maxTurnAt,maxShake,maxRoll,maxZoom,maxZoomAt,maxSnap,maxMove,maxMoveAt=0,0,0,0,0,0,0,0,0
 local outside=0;local t=0
 local function frameAt(t)return Cam.Shot(rank,'Full',t,tl,{Live=LIVE,LiveFov=70,Head=HEAD})end
 while t<tl.Length do
  local s=frameAt(t);s.T=t
  s.F=(s.Target-s.Eye).Unit
  if prev then
   local cut=(prev.World~=s.World)or(not s.World and prev.Index~=s.Index and not s.Join)
   if cut then
    -- (the exact moment: bisect between the two samples)
    local a,b=prev.T,t
    for _=1,30 do local m=(a+b)/2;local x=frameAt(m);if(x.World~=prev.World)or(not x.World and x.Index~=prev.Index)then b=m else a=m end end
    cuts[#cuts+1]={T=b,Name=(s.Name or'?'),World=s.World}
   else
    local turn=ang(prev.F,s.F)/dt
    local shaking=t>=tl.Climax and t<tl.Climax+.5
    if fadeAt(t,tl)>=.8 then -- (under the black: not seen)
    elseif shaking then maxShake=math.max(maxShake,turn)elseif turn>maxTurn then maxTurn,maxTurnAt=turn,t end
    local z=math.abs(s.Fov-prev.Fov)/dt
    if z>60 then maxSnap=math.max(maxSnap,z)elseif z>maxZoom then maxZoom,maxZoomAt=z,t end
    local mv=(s.Eye-prev.Eye).Magnitude/dt
    if not shaking and not s.World and fadeAt(t,tl)<.8 and mv>maxMove then maxMove,maxMoveAt=mv,t end
   end
  end
  maxRoll=math.max(maxRoll,math.abs(s.Roll or 0))
  if not s.World then local b=BOX[rank];local e=s.Eye
   if e.X<b[1]+.5 or e.X>b[2]-.5 or e.Y<b[3]+.5 or e.Y>b[4]-.5 or e.Z<b[5]+.5 or e.Z>b[6]-.5 then outside+=1 end end
  prev=s;t+=dt
 end
 local tt,ta,th=today(rank,tl)
 print(string.format('%s (Full, %.2f s): %d cuts; fastest visible turn %.0f deg/s at %.2f s (today\'s camera: %.0f deg/s at %.2f s; the hit\'s first 0.5 s: %.0f deg/s, today %.0f); biggest tilt %.1f deg; fastest zoom %.0f deg/s at %.2f s (snaps / ratchet clicks up to %.0f deg/s); fastest visible move %.1f studs/s at %.2f s; frames outside the stage: %d',
  names[rank],tl.Length,#cuts,maxTurn,maxTurnAt,tt,ta,maxShake,th,maxRoll,maxZoom,maxZoomAt,maxSnap,maxMove,maxMoveAt,outside))
 for _,c in ipairs(cuts)do
  local best,bd=nil,math.huge
  local at=nil
  for _,q in ipairs(cues)do
   local when=q.PeakAt or q.At -- (a whoosh: its swell, the moment you hear it)
   local d=math.abs(when-c.T);if d<bd then best,bd,at=q,d,when end
  end
  local black=c.World or c.Name:find('OUT OF THE DARK')or c.Name:find('ZOOM%-OUT')or c.Name:find('GRAND HALL')
  print(string.format('  cut %.3f s -> %s%s; nearest sound %s%s at %.3f s (%+.1f ms)',c.T,c.Name,black and' (under the black fade)'or'',best and best.Slot or'-',best and best.PeakAt and' (swell)'or'',at or 0,at and(c.T-at)*1000 or 0))
 end
 -- the seed from the hit on (the hero framing), on three screens
 local starts={[6]=tl.Climax+.3,[7]=tl.StarIn,[8]=tl.Climax+.3}
 for _,asp in ipairs({{'16:9',16/9},{'19.5:9',19.5/9},{'4:3',4/3}})do
  local lo,hi,off=1,0,0;local t2=starts[rank]
  while t2<=tl.FloatEnd do
   local s=frameAt(t2);local seed=L.SeedPose(rank,tl,t2)
   local x,y,z=L.Project(s.Eye,s.Target,s.Fov,asp[2],seed)
   if z then local share=2*L.ProjectedRadius(s.Fov,z,L.SeedHeroSize/2);lo=math.min(lo,share);hi=math.max(hi,share);off=math.max(off,math.abs(x-.5),math.abs(y-.5))end
   t2+=1/60
  end
  local s=frameAt(tl.FloatEnd);local _,_,z=L.Project(s.Eye,s.Target,s.Fov,asp[2],L.SeedPose(rank,tl,tl.FloatEnd))
  print(string.format('  seed %s, from %.2f s to the end of its float: %.0f%% .. %.0f%% of the height (at the end %.0f%%), off-centre at most %.3f',asp[1],starts[rank],lo*100,hi*100,2*L.ProjectedRadius(s.Fov,z,L.SeedHeroSize/2)*100,off))
 end
 local a,b=frameAt(tl.Silence+.01),frameAt(tl.Climax-.02)
 print(string.format('  skip target (Climax - 0.02 s) = the silence frame: moved %.3f studs, turned %.2f deg',(a.Eye-b.Eye).Magnitude,ang((a.Target-a.Eye).Unit,(b.Target-b.Eye).Unit)))
end
