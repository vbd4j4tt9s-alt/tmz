-- R66: charge light at a fixed distance; a burst travels outward, never the emblem.
local R={}
-- R136: Legendary (.7 s) and Mythic (1.0 s) get a short charge-up before the seed bursts out (was .1 like Common).
function R.SeedAt(rank)return rank==8 and 3.35 or rank==7 and 2.45 or rank==6 and 1.35 or rank==5 and 1.0 or rank==4 and .7 or .1 end
function R.Sample(rank,t,reduced)
 local at=R.SeedAt(rank);local charge=math.clamp(t/at,0,1);local age=math.max(0,t-at)
 local burst=t>=at;local release=math.clamp(age/.75,0,1)
 return {Charge=charge,Rotation=reduced and 0 or t*28+charge^4*480,Scale=1,
  Flash=burst and math.clamp(1-math.max(0,age-.065)/.34,0,1)*(reduced and .3 or 1)or 0,
  Cover=rank>=6 and(1-math.clamp((age-.10)/.50,0,1))or 0,SeedVisible=burst,
  Burst=burst and age<.75,Done=burst and age>=.75,Expansion=1,
  BurstProgress=release,CoreVisible=not burst,CoreAlpha=.72-charge*.72,
  RaysAlpha=1-charge^2*.65,Age=age}
end
-- Tilted elliptical orbits, sampled with line segments instead of rounded rectangles.
function R.OrbitPoint(ring,theta,rotation)
 local radius=.205+ring*.044;local a=theta+math.rad(rotation)*(ring%2==0 and -1 or 1)
 local tilt=math.rad((ring-1)*57+12);local x=math.cos(a)*radius;local y=math.sin(a)*radius*(.29+ring*.055)
 return Vector2.new(.5+x*math.cos(tilt)-y*math.sin(tilt),.5+x*math.sin(tilt)+y*math.cos(tilt))
end
return R
