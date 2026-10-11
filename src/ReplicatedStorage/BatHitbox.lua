-- R78: target centres inside one horizontal box extending forward from the attacker.
-- R158 (docs/proposals/R158/bats/hitbox.md): the box is replaced by a flat SECTOR in front (BatConfig Reach, HalfAngle, +-Height) plus an Inner circle
-- all round, and a target is tested along its PATH since the last look (sub-steps of Step studs), never at one point, so nothing jumps through it at
-- any speed. Pure math on plain numbers (no Roblox types, nothing allocated): the swinger's client sweeps with it (BatClient) and the server's re-check
-- uses the same test (BatLagComp).
local C=require(script.Parent.BatConfig)
local B={}
B.CosHalf=math.cos(math.rad(C.HalfAngle))
-- (dx,dy,dz) = target minus swinger; (fx,fz) = the swinger's flat facing, unit length
function B.InSector(dx,dy,dz,fx,fz,reach,cosHalf,inner,height)
 if dy>height or dy<-height then return false end
 local d2=dx*dx+dz*dz
 if d2<=inner*inner then return true end
 if d2>reach*reach then return false end
 return dx*fx+dz*fz>=cosHalf*math.sqrt(d2)
end
-- the relative path from a to b against the sector: nil, or the fraction 0..1 of the path at its first point inside
function B.Sweep(ax,ay,az,bx,by,bz,fx,fz,reach,cosHalf,inner,height)
 local ex,ey,ez=bx-ax,by-ay,bz-az
 local n=math.clamp(math.ceil(math.sqrt(ex*ex+ey*ey+ez*ez)/C.Step),1,C.MaxSubSteps)
 for i=0,n do
  local u=i/n
  if B.InSector(ax+ex*u,ay+ey*u,az+ez*u,fx,fz,reach,cosHalf,inner,height)then return u end
 end
 return nil
end
-- The swinger's client, once per rendered frame of the strike: (prx,pry,prz) / (rx,ry,rz) = the target minus the swinger at the previous / this frame,
-- as this screen shows them; (fx,fz) = the swinger's flat facing now. Returns nil, or the fraction 0..1 of the frame at which the path first touched
-- the sector: the claim carries THAT moment and the swinger's own spot at that moment (a fast swinger can pass a victim inside one frame).
function B.ClientFrame(prx,pry,prz,rx,ry,rz,fx,fz)
 return B.Sweep(prx,pry,prz,rx,ry,rz,fx,fz,C.Reach,B.CosHalf,C.Inner,C.Height)
end
-- a flat unit facing from a look vector's X / Z, or nil when it points straight up / down
function B.Flat(lx,lz)
 local l=math.sqrt(lx*lx+lz*lz)
 if l<1e-3 then return nil end
 return lx/l,lz/l
end
-- Where a hit can count (BatService._eligible's RequireBiome / SafeLineMargin rule, for the client's own sweep): inside the biome track and more than
-- SafeLineMargin studs past the base line. lineZ / centerX / halfWidth = RunnerMotion's TrackBoundaryZ / TrackCenterX / TrackHalfWidth (MapService
-- writes them from the line), endZ = the map's BiomeTrackEndZ. Unknown numbers allow the hit (the server decides).
function B.OnTrack(x,z,lineZ,centerX,halfWidth,endZ)
 if not C.RequireBiome then return true end
 if type(lineZ)=='number'and z<=lineZ+C.SafeLineMargin then return false end
 if type(centerX)=='number'and type(halfWidth)=='number'and math.abs(x-centerX)>halfWidth then return false end
 if z>(type(endZ)=='number'and endZ or 1445)+60 then return false end
 return true
end
return B
