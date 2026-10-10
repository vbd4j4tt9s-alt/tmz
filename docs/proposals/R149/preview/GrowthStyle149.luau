--!nocheck
-- R149 growth-style PROPOSAL. Scratch module for the preview only: it is NOT in src/ and nothing in the game requires it.
-- It draws the proposed look on the state that the REAL PlantGrowth.Capture builds (same parts, roles, sockets, colours), and it reads
-- progress from the REAL PlantGrowth.Progress, so readiness, timing, prices and prompts are exactly the game's. Only the drawing differs.
-- Numbers are the items of growth_style.md:
--  #2 sway:    P.Apply takes the sway pose as its base; in the game the sway rig moves the grown pose (existing 6-plant / 600-part budget);
--  #3 sprout:  the seedling pops up as the R112 dirt pile sinks (~3 s after planting) and opens its two leaves (server-time driven);
--  #4 shape:   a fast-start curve, so the plant is readable in the first minute (today: ~4 % of full size at 10 % of the time);
--  #5 leaves:  foliage keeps its real opacity and grows out of the point where it joins the stem (today: it fades in like a ghost);
--  #6 fruit:   a pale "unripe" green made from the fruit's own colour (stripes / shading kept), a swell that plumps 5 % and settles,
--              the ripe colour arriving in the last 45 % through a bright hue path (today: a straight RGB blend from leaf green, which
--              passes through olive / brown on red fruit), and the real material switched on at the ripe moment (today: at 82 %);
--  #9 flower:  (nice-to-have) a small blossom at the fruit socket for the first ~20 % of a fruit, whose petals drop as the fruit sets.
-- The ripe bounce + glints (#7) and the harvest pop (#8) are moments, not poses: dump_growth.luau draws them with P.Bounce / P.Pop.
-- #1 (write only what moved) is about how often the game writes these poses, so it has no picture.
local RS=game:GetService('ReplicatedStorage')
local Growth=require(RS:WaitForChild('PlantGrowth'))
local V,CF=Vector3.new,CFrame.new
local P={}
-- Owner: these keep today's look at every moment (the real PlantGrowth.Apply draws them).
P.LookFrozen={LanternFernSeed=true,AmethystSeed=true}
P.Tuning={
 SproutAt=2.9,SproutRise=.6,SproutOpen=.55, -- seconds after planting: the pile's 'Sink' beat (R112), then the stem rises and the leaves open
 LeafStart=.02,LeafSpread=.16,LeafTime=.25, -- a leaf starts at LeafStart + LeafSpread x (its height / plant height) and takes LeafTime
 UnripeHue=88/360,                      -- young fruit: a pale yellow-green of the fruit's own brightness (today: flat leaf green 83,157,64)
 ColourFrom=.55,                        -- the ripe colour arrives over the last 45 % of a fruit's growth
 SwellDone=.90,SwellPeak=.05,           -- full size at 90 %, plump +5 %, settle to exactly 100 % at ripe
 FlowerEnd=.22,                         -- the blossom shows until 22 % of a fruit, its petals drop from 15 %
 Petal=Color3.fromRGB(255,244,250),PetalTip=Color3.fromRGB(255,190,214),Pollen=Color3.fromRGB(255,214,79),
}
local T=P.Tuning
local green=Color3.fromRGB(83,157,64)
local function clamp01(x)return x<0 and 0 or x>1 and 1 or x end
local function smooth(x)x=clamp01(x);return x*x*(3-2*x)end
local function ease(a,b,x)return smooth((x-a)/math.max(.001,b-a))end
local function backOut(u,s)u=clamp01(u);s=s or 1.5;u-=1;return 1+(s+1)*u*u*u+s*u*u end
P.Ease=ease
-- Colour helpers (Roblox has Color3:ToHSV / Color3.fromHSV; written out here so the mock and the game agree).
local function toHSV(c)
 local r,g,b=c.R,c.G,c.B;local mx,mn=math.max(r,g,b),math.min(r,g,b);local d=mx-mn;local h=0
 if d>1e-6 then
  if mx==r then h=((g-b)/d)%6 elseif mx==g then h=(b-r)/d+2 else h=(r-g)/d+4 end
  h/=6
 end
 return h,mx>0 and d/mx or 0,mx
end
local function fromHSV(h,s,v)
 h=(h%1)*6;local i=math.floor(h);local f=h-i;local p,q,t=v*(1-s),v*(1-s*f),v*(1-s*(1-f))
 local r,g,b
 if i==0 then r,g,b=v,t,p elseif i==1 then r,g,b=q,v,p elseif i==2 then r,g,b=p,v,t elseif i==3 then r,g,b=p,q,v elseif i==4 then r,g,b=t,p,v else r,g,b=v,p,q end
 return Color3.new(r,g,b)
end
-- The unripe look of a ripe colour: same brightness pattern (so a melon keeps its stripes), pale yellow-green hue.
function P.Unripe(c)
 local _,s,v=toHSV(c);return fromHSV(T.UnripeHue,math.clamp(.28+.28*s,.28,.55),math.clamp(v*.8+.14,.40,.82))
end
-- Ripening: hue along the short way round (green -> yellow -> orange -> red for red fruit), so the middle is a bright blush, not mud.
function P.Ripen(c,k)
 if k<=0 then return P.Unripe(c)end;if k>=1 then return c end
 local h0,s0,v0=toHSV(P.Unripe(c));local h1,s1,v1=toHSV(c)
 if s1<.08 then return P.Unripe(c):Lerp(c,k)end -- grey / white fruit: a plain blend
 local dh=h1-h0;if dh>.5 then dh-=1 elseif dh<-.5 then dh+=1 end
 return fromHSV(h0+dh*k,s0+(s1-s0)*k,math.max(v0+(v1-v0)*k,math.min(v0,v1)+.08*math.sin(math.pi*k)))
end
-- #4: the plant's overall size at body progress b. Today: ease(.025,1,b)^(~.8); proposed: fast start, slow finish.
function P.Skeleton(b)if b<=0 then return 0 end;return 1-(1-clamp01((b-.02)/.98))^1.6 end
function P.TodaySkeleton(b,power)return ease(.025,1,b)^(power or .8)end
-- #6: fruit size factor at fruit progress f (0..1): full at SwellDone, a half-sine plump on top that ends at exactly 1.
function P.Swell(f)
 f=clamp01(f);local base=ease(.10,T.SwellDone,f);local from=T.SwellDone-.10
 if f>from and f<1 then base+=T.SwellPeak*math.sin(math.pi*(f-from)/(1-from))end
 return base
end
-- #7: ripe bounce t seconds after the fruit became ripe: scale multiplier (1 before and after .8 s).
function P.Bounce(t)local u=t/.8;if u<=0 or u>=1 then return 1 end;return 1+.15*math.sin(u*math.pi*3)*(1-u)^2 end
-- #8: harvest pop t seconds after the pick: sx, sy, lift (fractions of the fruit radius), fade.
local popKeys={{0,1,1,0},{.16,1.14,.80,0},{.40,.88,1.26,.55},{.70,.52,.52,.85},{1,0,0,1}}
function P.Pop(t)
 local u=clamp01(t/.36);local a,b=popKeys[1],popKeys[#popKeys]
 for i=1,#popKeys-1 do if u>=popKeys[i][1]and u<=popKeys[i+1][1]then a,b=popKeys[i],popKeys[i+1];break end end
 local k=smooth((u-a[1])/math.max(.001,b[1]-a[1]))
 return a[2]+(b[2]-a[2])*k,a[3]+(b[3]-a[3])*k,a[4]+(b[4]-a[4])*k,smooth((u-.55)/.45)
end
-- Where a foliage part joins the plant (origin space, mature pose): the end of its long axis nearer the stem axis (the lower end when it
-- stands upright); for round canopy pieces, the inner side. Computed once per part (Capture time), not per frame.
local function joint(r,profile,def)
 local f=r.Frame;local s=r.Size;local c=f.Position
 local axes={{f.RightVector,s.X},{f.UpVector,s.Y},{-f.LookVector,s.Z}}
 table.sort(axes,function(a,b)return a[2]>b[2]end)
 local long,mid=axes[1],axes[2]
 local horizontal=V(c.X,0,c.Z)
 if long[2]>=mid[2]*1.6 then
  local half=long[1]*long[2]*.5;local a,b=c+half,c-half
  if math.abs(long[1].Y)>.7 then return a.Y<b.Y and a or b end
  local da=V(a.X,0,a.Z).Magnitude;local db=V(b.X,0,b.Z).Magnitude
  return da<db and a or b
 end
 local inward=horizontal.Magnitude>.05 and -horizontal.Unit or V(0,0,0)
 local r0=axes[3][2]*.5
 return c+inward*r0*.6-V(0,r0*.35,0)
end
-- Extend a REAL PlantGrowth.Capture state with what the proposal needs (joints, leaf timing, blossom parts). Preview-only temporaries
-- are tagged GrowthTemporary like today's seed / sprout / bud.
function P.Extend(state)
 if state.Proposal then return state end
 local def=state.Def;local h=math.max(.5,def.Height);local rad=math.max(.5,def.Radius)
 for _,r in ipairs(state.Parts)do
  if r.Foliage and not r.Fruit then
   r.Joint=joint(r,state.Profile,def)
   local level=state.Profile=='Vine'and V(r.Joint.X,0,r.Joint.Z).Magnitude/rad or r.Joint.Y/h
   r.LeafStart=T.LeafStart+T.LeafSpread*clamp01(level)+((r.Index*37)%11)/11*.03
  end
 end
 for index,b in pairs(state.Buds)do
  -- The blossom is sized from the fruit it turns into (half its radius per petal), so a melon gets a melon-sized flower.
  local lo,hi
  for _,r in ipairs(state.Parts)do if r.Fruit and r.Group==index and not r.Foliage then
   local c=r.Frame.Position;local h=r.Size*.5
   lo=lo and V(math.min(lo.X,c.X-h.X),math.min(lo.Y,c.Y-h.Y),math.min(lo.Z,c.Z-h.Z))or c-h
   hi=hi and V(math.max(hi.X,c.X+h.X),math.max(hi.Y,c.Y+h.Y),math.max(hi.Z,c.Z+h.Z))or c+h
  end end
  local size=lo and(hi-lo)or V(.6,.6,.6);b.Radius=math.clamp(math.max(size.X,size.Y,size.Z)*.5,.15,3)
  b.Petals={}
  for i=1,5 do
   local p=Instance.new('Part');p.Name='Blossom petal';p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CastShadow=false
   p.Material=Enum.Material.SmoothPlastic;p.Color=T.Petal:Lerp(T.PetalTip,i%2==0 and .55 or .25);p.Transparency=1;p.Size=V(.1,.1,.1)
   local m=Instance.new('SpecialMesh');m.MeshType=Enum.MeshType.Sphere;m.Scale=V(1,1,1);m.Parent=p -- an ellipsoid, like PlantVisuals' Ball
   p:SetAttribute('GrowthTemporary',true);p.Parent=state.Model;b.Petals[i]=p
  end
 end
 state.Proposal=true
 return state
end
-- The proposed pose of a growing plant (or of one regrowing fruit) at server time `now`. `pose` (optional) = the base pose, e.g. the sway
-- pose (#2). In the game, #1 keeps each part's grown pose and only the existing sway rig moves it every tick; this preview poses once.
function P.Apply(state,crop,now,pose)
 if P.LookFrozen[state.Id]or state.Mech or state.Verity then return Growth.Apply(state,crop,now)end
 P.Extend(state)
 local def=state.Def;local base=pose or state.Origin
 local body=Growth.Progress(crop,def,now)
 local plain=crop.Mutation==nil or crop.Mutation=='None'
 local scale=body>=1 and 1 or P.Skeleton(body)
 -- #3 sprout: seconds since planting (server time, so every client agrees and a late joiner just sees the settled seedling).
 -- Under the dirt pile (0-2.9 s) only the seed is there; as the pile sinks the seedling pops up and opens.
 local age=now-(crop.PlantedAt or now)
 local rise=backOut((age-T.SproutAt)/T.SproutRise,1.4);local open=backOut((age-T.SproutAt-T.SproutRise*.6)/T.SproutOpen,1.6)
 local hand=1-ease(.07,.17,body) -- the real plant takes over once it is taller than the seedling
 local seed=state.Seed;local squash=1-.3*math.sin(math.pi*clamp01(age/.5))
 local seedSize=.30*(1-ease(.02,.08,body))
 seed.Size=V(seedSize*(1+.5*(1-squash)),seedSize*squash,seedSize*(1+.5*(1-squash)));seed.CFrame=base*CF(0,seedSize*squash*.4,0)
 seed.Transparency=seedSize<.02 and 1 or 0
 local baby=state.Sprout;local h=(.34+.30*ease(0,.06,body))*rise*hand;local thick=.06*(.5+.5*rise)*math.max(.2,hand)
 local show=state.Id~='StarfruitSeed'and h>.02
 baby[1].Size=V(thick,math.max(.01,h),thick);baby[1].CFrame=base*CF(0,h*.5,0);baby[1].Transparency=show and 0 or 1
 for i=2,3 do
  local side=i==2 and -1 or 1;local g=(.35+.65*open)*hand
  baby[i].Size=V(.05,math.max(.01,(.16+h*.2)*g),math.max(.01,(.26+h*.2)*g))
  baby[i].CFrame=base*CF(side*(.05+.10*open)*hand,h*.9,0)*CFrame.Angles(0,0,side*(.12+.95*open))
  baby[i].Transparency=(show and open>.03)and 0 or 1
 end
 local progress={}
 for i=1,def.FruitCount do local _,f=Growth.Progress(crop,def,now,i);progress[i]=f end
 for _,r in ipairs(state.Parts)do
  local p=r.Part
  if p.Parent then
   local pos=r.Frame.Position;local size=r.Size*scale;local color=r.Color;local alpha=r.Alpha;local material=r.Material
   local at=pos*scale
   if r.Fruit then
    local f=progress[math.max(1,r.Group)]or progress[1]or 1
    local k=P.Swell(f)
    local anchor=state.Anchors[r.Group]or V(table.unpack(def.Sockets[r.Group]))*(crop.PlantScale or 1)
    at=(anchor+(pos-anchor)*k)*scale;size=r.Size*scale*k
    if f<.12 then alpha=1 end
    if plain and state.Id~='StarfruitSeed'and not r.Foliage then color=P.Ripen(r.Color,ease(T.ColourFrom,.98,f))end
    if f<1 then material=Enum.Material.SmoothPlastic end
   elseif r.Foliage and body<1 then
    local k=ease(r.LeafStart,r.LeafStart+T.LeafTime,body)
    local j=r.Joint
    at=(j+(pos-j)*k)*scale;size=r.Size*scale*k
    if k<.02 then alpha=1 end
   elseif body<1 and plain then
    color=green:Lerp(r.Color,ease(.25,.78,body))
   end
   p.Size=V(math.max(.01,size.X),math.max(.01,size.Y),math.max(.01,size.Z))
   p.CFrame=base*CF(at)*r.Frame.Rotation
   p.Transparency=(body>0 and size.Magnitude>.0002)and alpha or 1
   p.Color=color;p.Material=material
  end
 end
 -- #6 / #9: the bud is a green calyx under the young fruit; the blossom opens on it first and drops its petals as the fruit sets.
 for index,b in pairs(state.Buds)do
  local f=progress[index]or progress[1]or 1
  local live=state.Id~='StarfruitSeed'and body>0 and f<.97
  local bloom=ease(.0,.10,f)*(1-ease(.15,T.FlowerEnd,f))
  local z=math.clamp((def.BaseScale or 1)*(crop.PlantScale or 1)*(.12+.10*f),.10,.8)*scale
  if bloom>0 then z=math.max(z,(b.Radius or .5)*scale*.24*bloom)end -- the flower's yellow heart
  local c=b.Anchor*scale
  b.Part.Size=V(z,z,z);b.Part.CFrame=base*CF(c);b.Part.Color=f<.18 and T.Pollen or green
  b.Part.Transparency=live and(f<.01 and 1 or 0)or 1
  b.Stem.Transparency=1
  for i,petal in ipairs(b.Petals or{})do
   local a=(i-1)/5*math.pi*2;local fall=ease(.15,T.FlowerEnd,f)
   local fr=(b.Radius or .5)*scale
   local spread=fr*(.18+.20*ease(.02,.10,f))
   local ps=fr*.55*bloom
   petal.Size=V(math.max(.01,ps*1.1),math.max(.01,ps*.32),math.max(.01,ps*.7))
   petal.CFrame=base*CF(c+V(math.cos(a)*spread,-fall*fr*.6,math.sin(a)*spread))*CFrame.Angles(0,-a,0)*CFrame.Angles(0,0,.35)
   petal.Transparency=(live and bloom>.04)and 0 or 1
  end
 end
 return body
end
return P
