-- R149: pooled snow patches (shared by the weather snow in WeatherWorld149.client.lua and the permanent Snow biome in SnowBiome149.client.lua).
-- A patch is a record (made once, reused) holding a layout (Spec, filled by WeatherWorld149.PatchSpec / BiomeSpec) and up to Max flat
-- ellipse discs borrowed from a pool of Parts. Discs are thin Cylinder parts lying on the ground: Anchored, no collision / touch / query /
-- shadow, SmoothPlastic, a white picked by the layout, raised a few hundredths above the surface they sit on. Parts are made lazily up
-- to the pool's disc budget and never destroyed until the pool is; binding or releasing a patch only writes properties.
local W=require(script.Parent.WeatherWorld149)
local P={}
local V3,CF=Vector3.new,CFrame.new
local ROLL=math.pi/2

-- parent: folder the discs live in. maxDiscs: Part budget. maxPatches: records. maxLobes: discs per patch.
function P.new(parent,maxDiscs,maxPatches,maxLobes)
 local pool={Parent=parent,MaxDiscs=maxDiscs,Made=0,Free={},FreeN=0,Records={},RecordsFree={},RecordsFreeN=0,MaxLobes=maxLobes or 3,Used=0}
 for k=1,maxPatches do
  local rec={Spec={},Discs={},DiscN=0,Key=0,T=1,Y=0,Lobes=0,Idx=0,Level=0,LobeStep=.004}
  pool.Records[k]=rec;pool.RecordsFree[k]=rec
 end
 pool.RecordsFreeN=maxPatches
 return pool
end
local function newDisc(pool)
 local p=Instance.new('Part');p.Name='Snow patch';p.Shape=Enum.PartType.Cylinder;p.Anchored=true
 p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.Size=V3(.06,1,1);p.CFrame=CF(0,-500,0);p.Transparency=1;p.Parent=pool.Parent
 pool.Made+=1
 return p
end
local function takeDisc(pool)
 if pool.FreeN>0 then local p=pool.Free[pool.FreeN];pool.Free[pool.FreeN]=nil;pool.FreeN-=1;return p end
 if pool.Made<pool.MaxDiscs then return newDisc(pool)end
 return nil
end
local function giveDisc(pool,p)
 p.Transparency=1;pool.FreeN+=1;pool.Free[pool.FreeN]=p
end

-- A free record, or nil when the pool is out of records (the caller just skips that patch).
function P.Take(pool)
 local n=pool.RecordsFreeN;if n==0 then return nil end
 local rec=pool.RecordsFree[n];pool.RecordsFree[n]=nil;pool.RecordsFreeN=n-1
 rec.DiscN=0;rec.Lobes=0;rec.T=1;rec.Key=0;rec.Idx=0;rec.Level=0;rec.LobeStep=.004
 pool.Used+=1
 return rec
end
-- Hide a record's discs (back to the pool) and give the record back.
function P.Release(pool,rec)
 for k=rec.DiscN,1,-1 do giveDisc(pool,rec.Discs[k]);rec.Discs[k]=nil end
 rec.DiscN=0;rec.Lobes=0;rec.T=1
 pool.RecordsFreeN+=1;pool.RecordsFree[pool.RecordsFreeN]=rec
 pool.Used-=1
end
-- Draw the first `lobes` lobes of rec.Spec at height y (the discs' centre plane; thickness from the spec). scale stretches a lone lobe that
-- stands in for the whole blob (far patches). lobeStep = how much higher each further lobe lies (default .004: lobes that overlap while the
-- patch is still fading in are never coplanar; the permanent, opaque Snow-biome patches pass 0 - all lobes of one patch are one colour, so
-- they cannot show a seam, and the patch's own height step keeps it clear of its neighbours). Returns how many discs it got (fewer when
-- the part budget is out).
function P.Fill(pool,rec,lobes,scale,y,lobeStep)
 local s=rec.Spec;lobes=math.min(lobes,s.N,pool.MaxLobes)
 local ls=lobeStep or rec.LobeStep or .004;rec.LobeStep=ls
 -- drop discs beyond what is wanted, take the missing ones
 for k=rec.DiscN,lobes+1,-1 do giveDisc(pool,rec.Discs[k]);rec.Discs[k]=nil end
 if rec.DiscN>lobes then rec.DiscN=lobes end
 for k=rec.DiscN+1,lobes do
  local d=takeDisc(pool);if not d then break end
  rec.Discs[k]=d;rec.DiscN=k
 end
 local color=W.Shades[s.Shade]or W.Shades[1]
 local f=(lobes==1 and s.N>1)and(scale or 1)or 1
 local th=s.Thickness or .06
 for k=1,rec.DiscN do
  local d=rec.Discs[k]
  d.Size=V3(th,2*s.LB[k]*f,2*s.LA[k]*f)
  d.CFrame=CF(s.X+s.LX[k],y+(k-1)*ls,s.Z+s.LZ[k])*CFrame.Angles(0,s.LY[k],ROLL)
  d.Color=color
  d.Transparency=rec.T
 end
 rec.Lobes=rec.DiscN;rec.Y=y
 return rec.DiscN
end
-- Move a record's discs to another height (the keyboard appeared / went away under a permanent patch).
function P.Lift(rec,y)
 if rec.Y==y then return end
 for k=1,rec.DiscN do
  local d=rec.Discs[k];local p=d.CFrame.Position
  d.CFrame=CF(p.X,y+(k-1)*(rec.LobeStep or .004),p.Z)*CFrame.Angles(0,rec.Spec.LY[k],ROLL)
 end
 rec.Y=y
end
function P.Alpha(rec,t)
 if rec.T==t then return end
 rec.T=t
 for k=1,rec.DiscN do rec.Discs[k].Transparency=t end
end
function P.Destroy(pool)
 for _,rec in ipairs(pool.Records)do for k=1,rec.DiscN do rec.Discs[k]=nil end;rec.DiscN=0 end
 for _,p in ipairs(pool.Parent:GetChildren())do if p.Name=='Snow patch'then p:Destroy()end end
 table.clear(pool.Free);pool.FreeN=0;pool.Made=0
end
return P
