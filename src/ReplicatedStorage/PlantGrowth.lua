local Rules=require(game:GetService('ReplicatedStorage'):WaitForChild('PlantRules'))
-- V149 revision 9: timestamp-driven growth, shared by near art and server fallback.
-- This module never changes saved crops, readiness, rewards, prompts or collision rules.
-- R149 (phase 1 of docs/proposals/R149/growth_style.md): the drawing of a growing plant. Cosmetic only.
--  #1 a plant is rewritten only when its growth moved by 1/Steps, and only the properties that changed (every plant, also the two frozen ones);
--  #2 every part keeps its grown pose (Home) so GardenVisuals can sway a growing plant through the animation batch (G.Place);
--  #3 the seedling springs up and opens its leaves as the R112 dirt pile sinks (server-time driven, so every client agrees);
--  #4 fast-start size curve (G.Shape);  #5 leaves keep their opacity and grow out of the point where they join the stem;
--  #6 fruit: pale green of its own colour pattern, plump + settle, bright ripening path, real material at the ripe moment.
-- Lantern Fern and Amethyst Grape (G.Frozen) keep EXACTLY today's drawing (the 'classic' branch): only #1 applies to them.
local G={};local V,CF=Vector3.new,CFrame.new
local function unit(v)return math.clamp(v,0,1)end
local function ease(a,b,x)local t=unit((x-a)/math.max(.001,b-a));return t*t*(3-2*t)end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local flowers={SunflowerBloomSeed=true,ThunderTulipSeed=true,DatePalmSeed=true,CrystalLilySeed=true,WinterPineSeed=true,LavaLotusSeed=true,OrbitLotusSeed=true,TempestLotusSeed=true,BlackoutBloomSeed=true,PolarStarbloomSeed=true,SupernovaBloomSeed=true,TigerOrchidSeed=true,VoltOrchidSeed=true,SilentFrostbellSeed=true}
local ground={SunflowerSeed=true,SnowdropSeed=true,MoonflowerSeed=true,EmberBloomSeed=true}
-- Owner: these two plants keep today's look at every moment of their growth.
G.Frozen={LanternFernSeed=true,AmethystSeed=true}
G.Tuning={
 Steps=600,                              -- #1: rewrite when growth moved by 1/Steps
 ShapeFrom=.02,ShapePower=1.6,           -- #4: fast start (35 % size at 25 % growth; today 20 %)
 SproutAt=2.9,SproutRise=.6,SproutOpen=.55, -- #3: seconds after planting: the R112 pile's 'Sink' beat, then the stem rises and the leaves open
 LeafStart=.02,LeafSpread=.16,LeafTime=.25, -- #5: a leaf starts at LeafStart + LeafSpread x (height of its joint / plant height) and takes LeafTime
 UnripeHue=88/360,ColourFrom=.55,ColourTo=.98, -- #6: the ripe colour arrives over the last 45 % of a fruit's growth
 SwellFrom=.10,SwellDone=.90,SwellPeak=.05,    -- #6: full size at 90 %, plump +5 %, settle to exactly 100 % at ripe
 MeshTint=Color3.fromRGB(222,240,176),   -- #6: unripe tint of a MeshPart fruit (its vertex colours carry the pattern; Part.Color multiplies them)
}
local T=G.Tuning
G.Stats={Applies=0,Rewrites=0,Skips=0,LinkTests=0}
function G.Profile(id,def)
 return id=='StarfruitSeed'and 'GroundStar'or ground[id]and 'Vine' or flowers[id]and 'Flower' or id=='MooncapSeed'and 'Mushroom' or def.Tree and 'Tree' or def.Mode=='whole'and 'Leafy' or 'Bush'
end
local seeds=setmetatable({},{__mode='k'}) -- (a crop's seed is worked out once: Progress runs for every growing plant 20 times a second)
local function growthSeed(crop)
 local cached=seeds[crop];if cached then return cached end
 local h=17;for i=1,#tostring(crop.Id or '')do h=(h*31+string.byte(tostring(crop.Id or ''),i))%997 end
 local value=h/996;seeds[crop]=value;return value
end
function G.Progress(crop,def,now,index)
 local finish=crop.MatureAt or crop.ReadyAt;local start=crop.PlantedAt
 if not finite(start)or not finite(finish)then return 1,now>=(crop.ReadyAt or 0)and 1 or 0 end
 local body=unit((now-start)/math.max(1,finish-start))
 local readyAt=Rules.FruitReadyAt(crop,index or 1);local cycle=Rules.FruitCycle(crop,index or 1)
 local fruit
 if body<1 or cycle==0 then fruit=ease((def.Tree and .57 or ground[crop.SeedId]and .40 or flowers[crop.SeedId]and .50 or .46)+(growthSeed(crop)-.5)*.06,1,body)
 else local state=crop.FruitStates and crop.FruitStates[tostring(index or 1)];local duration=math.max(1,(state and state.Duration)or def.RegrowSeconds or def.Seconds or 1);fruit=unit((now-(readyAt-duration))/duration)end
 if now>=readyAt then fruit=1 end
 return body,fruit
end
function G.Timer(crop,def,now)
 local index,soon,ready=1,math.huge,0
 for i=1,def.FruitCount do local at=Rules.FruitReadyAt(crop,i);if Rules.FruitReady(crop,i,now)then ready+=1 elseif at>now and at<soon then soon=at;index=i end end
 local body,fruit=G.Progress(crop,def,now,index);local seconds=soon<math.huge and math.max(0,math.ceil(soon-now))or 0
 if seconds==0 then return 'READY',1 end
 local phase=body<1 and body or fruit
 local word=body>=1 and 'Regrowing'or phase<.12 and 'Sprouting'or phase<.55 and 'Growing'or phase<.84 and 'Budding'or 'Almost ready'
 local time=seconds>=3600 and string.format('%dh %02dm',math.floor(seconds/3600),math.floor(seconds%3600/60))or seconds>=60 and string.format('%dm %02ds',math.floor(seconds/60),seconds%60)or tostring(seconds)..'s'
 return (ready>0 and tostring(ready)..' ready • Next 'or word..' · ')..time,phase
end
function G.Sway(id,def,crop,time)
 local h=math.max(1,def.Height*(crop.PlantScale or 1));local hash=0
 for i=1,#tostring(crop.Id or id)do hash=(hash*31+string.byte(tostring(crop.Id or id),i))%997 end
 -- Keep giant trees visually aligned with their static climbing surfaces and fruit prompts.
 if id=='StarfruitSeed'or def.Mech or def.Verity then return CFrame.new()end
 local flower=flowers[id]==true;local a=math.min(flower and .044 or def.Tree and .005 or .009,(flower and .68 or .10)/h)
 return CFrame.Angles((math.sin(time*.83+hash)*.82+math.sin(time*1.31+hash*.3)*.18)*a,0,math.sin(time*.64+hash*.7)*a*.70)
end
-- R149 (#2): whether a GROWING plant sways (the giant Dune star, Mech and Verity plants stand still, and so do the two frozen ones).
function G.Sways(id,def)return not(id=='StarfruitSeed'or def.Mech or def.Verity or G.Frozen[id])end
-- Curves (pure; the tests read them) -------------------------------------------------------------------------------------------------------------
-- #4: the plant's size at growth b (0 .. 1): fast start, slow finish. Today: ease(.025,1,b)^(.68 .. .98).
function G.Shape(b)
 if b<=0 then return 0 end;if b>=1 then return 1 end
 return 1-(1-unit((b-T.ShapeFrom)/(1-T.ShapeFrom)))^T.ShapePower
end
-- #6: fruit size at fruit progress f: full at SwellDone, a half-sine plump on top that ends at exactly 1 (so the ripe size is the old one).
function G.Swell(f)
 f=unit(f);local base=ease(T.SwellFrom,T.SwellDone,f);local from=T.SwellDone-.10
 if f>from and f<1 then base+=T.SwellPeak*math.sin(math.pi*(f-from)/(1-from))end
 return base
end
local function backOut(u,s)u=unit(u);s=s or 1.5;u-=1;return 1+(s+1)*u*u*u+s*u*u end
G.BackOut=backOut
-- Colour helpers (Roblox has Color3:ToHSV / fromHSV; written out so the game and the offline mock agree).
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
G.ToHSV,G.FromHSV=toHSV,fromHSV
-- The unripe look of a ripe colour: the same brightness pattern (so a melon keeps its stripes), a pale yellow-green hue.
function G.Unripe(c)
 local _,s,v=toHSV(c);return fromHSV(T.UnripeHue,math.clamp(.28+.28*s,.28,.55),math.clamp(v*.8+.14,.40,.82))
end
-- Ripening colour at k (0 unripe .. 1 ripe): hue the short way round (green -> yellow -> orange -> red for red fruit), so the middle is a bright blush.
function G.Ripen(c,k)
 if k<=0 then return G.Unripe(c)end;if k>=1 then return c end
 local h0,s0,v0=toHSV(G.Unripe(c));local h1,s1,v1=toHSV(c)
 if s1<.08 then return G.Unripe(c):Lerp(c,k)end
 local dh=h1-h0;if dh>.5 then dh-=1 elseif dh<-.5 then dh+=1 end
 return fromHSV(h0+dh*k,s0+(s1-s0)*k,math.max(v0+(v1-v0)*k,math.min(v0,v1)+.08*math.sin(math.pi*k)))
end
-- The same, with the part's endpoints worked out once (Capture): a MeshPart fruit tints its vertex colours with Part.Color, so its path is a plain blend.
local function ripenPart(r,k)
 -- (the ripe end is what today's drawing leaves, green:Lerp(colour,1), so the end state is byte for byte the same)
 if k<=0 then return r.Unripe end;if k>=1 then return r.Ripe end
 if r.Mesh or r.Grey then return r.Unripe:Lerp(r.Color,k)end
 return fromHSV(r.H0+r.DH*k,r.S0+(r.S1-r.S0)*k,math.max(r.V0+(r.V1-r.V0)*k,r.VMin+.08*math.sin(math.pi*k)))
end
local green=Color3.fromRGB(83,157,64)
local function plain(parent,name,color,kind)
 local p=Instance.new(kind or 'Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.Size=V(.1,.1,.1);p.Transparency=1;p.Parent=parent
 return p
end
-- #5: how a leaf is attached to the plant. Worked out ONCE, at Capture, from the mature pose. Every foliage part (a leaf, but also a crown piece or a bark
-- mark that the art tags Canopy / Leaf) is attached to the part it touches that grows earlier: first the stem or trunk (a part that is not foliage), then the
-- foliage touching those, and so on (a tree a few levels deep). While it grows a part scales about its attach point, and that point rides on its parent's grown
-- surface (G.Apply: the leaves pre-pass), so nothing floats off the plant: a leaf grows out of the stem, lower leaves first. A part that touches nothing
-- grown takes the nearest part (or the ground, for a plant without a stem). Per-plant opt-out: G.PlainLeaves (those plants' leaves grow with the plant and
-- only appear in turn).
-- The opt-out list was filled from the R134 floating check at 25 / 50 / 75 % of the growth (run_growth.sh): in these plants the mature art holds a part to the
-- plant only THROUGH leaves (independent stalks that touch each other only by their caps, pendants hung on leaves, a crown piece that rests on a leaf), so a
-- shrinking leaf would let go of it. Their leaves grow with the plant instead (solid, appearing in turn).
G.PlainLeaves={MooncapSeed=true,DiamondVineSeed=true,SunKingPalmSeed=true,AncientWorldrootSeed=true,WinterCrownwoodSeed=true}
local CONTACT=.04
local function geometry(r,index)
 local f=r.Frame;local h=r.Size*.5;local c=r.Pos;local x,y,z=f.RightVector.Unit,f.UpVector.Unit,f.LookVector.Unit -- (unit axes: art rotations carry rounding)
 local hx,hy,hz=x*h.X,y*h.Y,z*h.Z
 return {R=r,Idx=index,C=c,X=x,Y=y,Z=z,H=h,Rho=h.Magnitude,
  -- the point itself, the 6 face centres and the 8 corners
  S={c,c+hx,c-hx,c+hy,c-hy,c+hz,c-hz,c+hx+hy+hz,c+hx+hy-hz,c+hx-hy+hz,c+hx-hy-hz,c-hx+hy+hz,c-hx+hy-hz,c-hx-hy+hz,c-hx-hy-hz}}
end
local function boxGap(g,q) -- squared distance from a point to the box of a part
 local d=q-g.C;local h=g.H
 local x=math.max(math.abs(d:Dot(g.X))-h.X,0);local y=math.max(math.abs(d:Dot(g.Y))-h.Y,0);local z=math.max(math.abs(d:Dot(g.Z))-h.Z,0)
 return x*x+y*y+z*z
end
local function contact(a,b) -- the smallest squared gap between a's sample points and b's box, and b's sample points and a's box; and that point
 local best,at=math.huge,nil
 for _,q in ipairs(a.S)do local d=boxGap(b,q);if d<best then best=d;at=q end end
 for _,q in ipairs(b.S)do local d=boxGap(a,q);if d<best then best=d;at=q end end
 return best,at
end
local function leafStart(state,r,at,height,radius)
 local level=state.Profile=='Vine'and V(at.X,0,at.Z).Magnitude/radius or at.Y/height
 return T.LeafStart+T.LeafSpread*unit(level)+((r.Index*37)%11)/11*.03
end
local function link(state,height,radius)
 local geo={};local foliage={}
 for _,r in ipairs(state.Parts)do if not r.Fruit then
  local g=geometry(r,#geo+1);geo[#geo+1]=g
  if r.Foliage then foliage[#foliage+1]=g else g.Rank=0 end
 end end
 if #foliage==0 then return end
 if G.PlainLeaves[state.Id]then for _,f in ipairs(foliage)do f.R.LeafStart=leafStart(state,f.R,f.R.Pos,height,radius)end;return end
 local tests=0
 for _,f in ipairs(foliage)do
  f.Near={}
  for _,g in ipairs(geo)do if g~=f and(f.C-g.C).Magnitude<=f.Rho+g.Rho+CONTACT then
   local d,at=contact(f,g);tests+=1;f.Near[#f.Near+1]={G=g,D=d,At=at}
  end end
 end
 G.Stats.LinkTests+=tests
 local pending=#foliage
 local function sweep() -- every unattached part that touches a part that is already grown takes the one that grows earliest
  local added={}
  for _,f in ipairs(foliage)do if not f.Rank then
   local best
   for _,n in ipairs(f.Near)do
    local g=n.G
    if g.Rank and n.D<=CONTACT*CONTACT and(not best or g.Rank<best.G.Rank or(g.Rank==best.G.Rank and n.D<best.D))then best=n end
   end
   if best then added[#added+1]={f,best}end
  end end
  for _,a in ipairs(added)do local f,n=a[1],a[2];f.Rank=n.G.Rank+1;f.Parent=n.G;f.Attach=n.At;pending-=1 end
  return #added>0
 end
 while pending>0 do
  while sweep()do end
  if pending>0 then
   -- the lowest piece that touches nothing grown yet takes the nearest grown part (or grows from the ground)
   local low
   for _,f in ipairs(foliage)do if not f.Rank and(not low or f.C.Y-f.H.Y<low.C.Y-low.H.Y)then low=f end end
   local near,gap
   for _,g in ipairs(geo)do if g.Rank and g~=low then local d=(g.C-low.C).Magnitude-g.Rho;if not gap or d<gap then near,gap=g,d end end end
   if near then
    local at,far=low.S[1],math.huge;for _,q in ipairs(low.S)do local d=(q-near.C).Magnitude;if d<far then at,far=q,d end end
    low.Rank=near.Rank+1;low.Parent=near;low.Attach=at
   else
    local at=low.S[1];for _,q in ipairs(low.S)do if q.Y<at.Y then at=q end end
    low.Rank=1;low.Attach=at
   end
   low.R.Free=true -- (it touches nothing in the mature plant: attached to the nearest part)
   pending-=1
  end
 end
 table.sort(foliage,function(a,b)if a.Rank~=b.Rank then return a.Rank<b.Rank end;return a.Idx<b.Idx end)
 local leaves={}
 for _,f in ipairs(foliage)do
  local r=f.R;local parent=f.Parent and f.Parent.R.Foliage and f.Parent.R or nil
  r.Par=parent;r.PR=f.Parent and f.Parent.R or nil;r.Att=f.Attach;r.D=parent and f.Attach-parent.Att or nil
  local start=leafStart(state,r,f.Attach,height,radius)
  if parent then start=math.max(start,parent.LeafStart+.012)end
  r.LeafStart=start;leaves[#leaves+1]=r
 end
 state.Leaves=leaves
end
-- Per rewrite (growth < 1): where every leaf is and how big, parents first. A leaf is its mature size x (plant size x its own growth), about its attach point,
-- and the attach point sits on the parent's grown surface (a stem or trunk: the plant's size about the ground).
local function leaves(state,body,scale)
 for _,r in ipairs(state.Leaves)do
  local k=ease(r.LeafStart,r.LeafStart+T.LeafTime,body);local s=scale*k
  local parent=r.Par
  local m=parent and parent.LM+r.D*parent.LS or r.Att*scale
  r.LM=m;r.LS=s;r.LAt=m+(r.Pos-r.Att)*s;r.LAmount=s
 end
end
-- A growth state is also findable by its model (GardenVisuals poses growing plants through it); the entry is dropped with the model or when the
-- temporary parts are gone (Visuals.EndGrowth destroys them).
local registry={}
function G.StateOf(model)
 local state=registry[model]
 if state and state.Seed and state.Seed.Parent then return state end
 if state then registry[model]=nil end
 return nil
end
function G.Capture(model,id,def,crop,origin,sockets)
 if def.Mech then return require(script.Parent.MechGrowth).Capture(model,id,def,crop,origin,sockets)end
 if def.Verity then return require(script.Parent.VerityGrowth).Capture(model,id,def,crop,origin,sockets)end
 local state={Model=model,Id=id,Def=def,Origin=origin,Parts={},Buds={},Profile=G.Profile(id,def),Frozen=G.Frozen[id]==true,
  Prog={},Ready={},WProg={},WReady={},Dirty={}}
 local scale=crop.PlantScale or 1;local height=math.max(.5,def.Height*scale);local radius=math.max(.5,def.Radius*scale)
 local groupBounds={}
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p.Transparency<.95 then
  local frame=origin:ToObjectSpace(p.CFrame);local g=p:GetAttribute('GrowthGroup')or 0
  local form=p:GetAttribute('GrowthForm')or'';local role=p:GetAttribute('GrowthRole')or'';local name=p.Name:lower()
  local fruit=g>0 and def.Mode~='whole'
  local foliage=role=='Canopy'or role=='Leaf'or form=='LeafBlade'or form=='ProxyBlade'or name:find('petal',1,true)or name:find('dome',1,true)
  local r={Part=p,Frame=frame,Size=p.Size,Color=p.Color,Material=p.Material,Alpha=p.Transparency,Query=p.CanQuery,Group=g,Fruit=fruit,Foliage=foliage,Index=p:GetAttribute('ArtSpecIndex')or 1,
   Pos=frame.Position,Rot=frame.Rotation,Gi=math.max(1,g),Mesh=p:IsA('MeshPart')or p:GetAttribute('ApprovedMesh')~=nil,
   -- what the part holds now (a diff on every write: only a property that changed is written)
   WS=p.Size,WT=p.Transparency,WC=p.Color,WM=p.Material,WQ=p.CanQuery,WCol=p.CanCollide}
  if not state.Frozen then
   if fruit and id~='StarfruitSeed'then
    local c=r.Color;r.Ripe=green:Lerp(c,1)
    if r.Mesh then local t=T.MeshTint;r.Unripe=Color3.new(c.R*t.R,c.G*t.G,c.B*t.B)
    else
     r.Unripe=G.Unripe(c);r.H0,r.S0,r.V0=toHSV(r.Unripe);r.H1,r.S1,r.V1=toHSV(c)
     r.Grey=r.S1<.08;r.DH=r.H1-r.H0;if r.DH>.5 then r.DH-=1 elseif r.DH<-.5 then r.DH+=1 end;r.VMin=math.min(r.V0,r.V1)
    end
   end
  end
  table.insert(state.Parts,r)
  if fruit then
   local b=groupBounds[g]or{Min=V(math.huge,math.huge,math.huge),Max=V(-math.huge,-math.huge,-math.huge)}
   local c=frame.Position;local z=p.Size/2
   b.Min=V(math.min(b.Min.X,c.X-z.X),math.min(b.Min.Y,c.Y-z.Y),math.min(b.Min.Z,c.Z-z.Z));b.Max=V(math.max(b.Max.X,c.X+z.X),math.max(b.Max.Y,c.Y+z.Y),math.max(b.Max.Z,c.Z+z.Z));groupBounds[g]=b
  end
 end end
 state.Seed=plain(model,'New seed',Color3.fromRGB(117,89,51));state.Seed.Shape=Enum.PartType.Ball
 state.Seed:SetAttribute('GrowthTemporary',true)
 state.Sprout={plain(model,'Baby stem',green),plain(model,'Baby leaf',green,'WedgePart'),plain(model,'Baby leaf',green,'WedgePart')}
 for _,part in ipairs(state.Sprout)do part:SetAttribute('GrowthTemporary',true)end
 state.SeedT={WS=state.Seed.Size,WT=1};state.SproutT={}
 for i,part in ipairs(state.Sprout)do state.SproutT[i]={WS=part.Size,WT=1}end
 state.Anchors={}
 for i,b in pairs(groupBounds)do
  local socket=(sockets and sockets[i]or V(table.unpack(def.Sockets[i])))*(crop.PlantScale or 1);local anchor=socket
  -- Every fruit grows from its authored branch/stem socket, including ground vines.
  state.Anchors[i]=anchor
  local bud=plain(model,'Growing bud',green);bud.Shape=Enum.PartType.Ball;bud:SetAttribute('GrowthTemporary',true)
  local stem=plain(model,'Growing fruit stalk',green);stem:SetAttribute('GrowthTemporary',true)
  state.Buds[i]={Part=bud,Stem=stem,Anchor=anchor,Socket=socket,PartT={WS=bud.Size,WT=1},StemT={WS=stem.Size,WT=1}}
 end
 for _,r in ipairs(state.Parts)do r.Anchor=state.Anchors[r.Group]end
 if not state.Frozen then link(state,height,radius)end
 state.GS=growthSeed(crop)
 registry[model]=state
 model.Destroying:Connect(function()if registry[model]==state then registry[model]=nil end end)
 return state
end
-- Writing -------------------------------------------------------------------------------------------------------------------------------------------
-- A CFrame goes through the caller's PlantAnimationBatch (G.Batch, one BulkMoveTo for the whole step) only for a state that was already drawn once
-- and only during GardenVisuals' animation step; every other write (the first pose, the last pose, the server) is direct.
local function frameSet(state,p,frame)
 local batch=G.Batch
 if batch and state.Posed then batch:Set(p,frame)else p.CFrame=frame end
end
-- A temporary part (seed, seedling, bud): size, transparency and pose, only what changed; a hidden one that stays hidden is not touched.
local function putTemp(state,t,p,size,tr,at,rot,base)
 if tr==1 and t.WT==1 then return end
 if t.WS~=size then p.Size=size;t.WS=size end
 if t.WT~=tr then p.Transparency=tr;t.WT=tr end
 local home=rot and CF(at)*rot or CF(at)
 t.Home=home;frameSet(state,p,base*home)
end
-- #3 sprout (new look): the seed squashes as it is planted; as the R112 pile sinks the seedling rises and opens its two leaves, then the real plant takes over.
local function sproutAt(crop)
 local planted=crop.PlantedAt
 if not finite(planted)then return nil end
 return crop.SproutAt or planted+T.SproutAt
end
local function sproutBusy(state,crop,now)
 if state.Frozen or state.Id=='StarfruitSeed'then return false end
 local at=sproutAt(crop);return at~=nil and now<at+T.SproutRise+T.SproutOpen+.1
end
local function seedlingNew(state,crop,now,body,base)
 local at=sproutAt(crop);local planted=crop.PlantedAt
 local age=finite(planted)and now-planted or 0
 local rise=at and backOut((now-at)/T.SproutRise,1.4)or 1;local open=at and backOut((now-at-T.SproutRise*.6)/T.SproutOpen,1.6)or 1
 local hand=1-ease(.07,.17,body)
 local squash=1-.3*math.sin(math.pi*unit(age/.5))
 local seedSize=.30*(1-ease(.02,.08,body));local wide=seedSize*(1+.5*(1-squash))
 putTemp(state,state.SeedT,state.Seed,V(wide,seedSize*squash,wide),seedSize<.02 and 1 or 0,V(0,seedSize*squash*.4,0),nil,base)
 local baby=state.Sprout;local h=(.34+.30*ease(0,.06,body))*rise*hand;local thick=.06*(.5+.5*rise)*math.max(.2,hand)
 local show=state.Id~='StarfruitSeed'and h>.02
 putTemp(state,state.SproutT[1],baby[1],V(thick,math.max(.01,h),thick),show and 0 or 1,V(0,h*.5,0),nil,base)
 for i=2,3 do
  local side=i==2 and -1 or 1;local g=(.35+.65*open)*hand
  putTemp(state,state.SproutT[i],baby[i],V(.05,math.max(.01,(.16+h*.2)*g),math.max(.01,(.26+h*.2)*g)),(show and open>.03)and 0 or 1,
   V(side*(.05+.10*open)*hand,h*.9,0),CFrame.Angles(0,0,side*(.12+.95*open)),base)
 end
end
-- Today's seed and sprout (Lantern Fern and Amethyst Grape).
local function seedlingClassic(state,body,base)
 local seedSize=.14+.20*ease(0,.10,body)
 putTemp(state,state.SeedT,state.Seed,V(seedSize,seedSize,seedSize),body>=.18 and 1 or ease(.07,.18,body),V(0,seedSize*.45,0),nil,base)
 local baby=state.Sprout;local h=.10+.50*ease(.02,.25,body);local fade=state.Id=='StarfruitSeed'and 1 or(body<.025 and 1 or ease(.26,.46,body))
 putTemp(state,state.SproutT[1],baby[1],V(.055,h,.055),fade,V(0,h*.5,0),nil,base)
 for i=2,3 do local side=i==2 and -1 or 1
  putTemp(state,state.SproutT[i],baby[i],V(.055,.14+h*.18,.21+h*.17),fade,V(side*(.08+h*.08),h*.78,0),CFrame.Angles(0,0,side*.65),base)
 end
end
-- The bud at the socket of a growing fruit. The same in both looks (it only changes when its fruit's progress moved).
local function buds(state,crop,scale,alive,base,all)
 local def=state.Def;local starfruit=state.Id=='StarfruitSeed';local prog=state.Prog
 for index,b in pairs(state.Buds)do
  if all or state.Dirty[index]then
   local fruit=prog[index]or prog[1]
   local show=not starfruit and alive and fruit>.012 and fruit<.94
   local z=math.max(.01,math.clamp((def.BaseScale or 1)*(crop.PlantScale or 1)*(.10+.12*fruit),.10,.85)*scale)
   local c=b.Anchor*scale
   -- The bud centre stays at the socket, so new fruit never separates from its stem.
   putTemp(state,b.PartT,b.Part,V(z,z,z),show and ease(.75,.94,fruit)or 1,c,nil,base)
   local a=b.Socket*scale;local d=c-a
   local stem=show and d.Magnitude>.015
   if stem then
    b.Stem.Transparency=0;b.StemT.WT=0
    b.Stem.Size=V(math.max(.025,z*.15),d.Magnitude,z*.15);b.Stem.CFrame=base*CFrame.lookAt((a+c)/2,c)*CFrame.Angles(math.pi/2,0,0)
   elseif b.StemT.WT~=1 then b.Stem.Transparency=1;b.StemT.WT=1 end
  end
 end
end
-- One part. `alpha` is the opacity it should have (1 = hidden). Only a property that differs from what the part holds is written.
local function putPart(state,r,p,size,tr,color,material,query,at,base)
 if r.WQ~=query then p.CanQuery=query;r.WQ=query end
 if r.WCol~=false then p.CanCollide=false;r.WCol=false end
 -- A part that is hidden and stays hidden costs nothing; the rest is written when it shows.
 if tr==1 then if r.WT~=1 then p.Transparency=1;r.WT=1 end;return end
 if r.WS~=size then p.Size=size;r.WS=size end
 if r.WT~=tr then p.Transparency=tr;r.WT=tr end
 if r.WC~=color then p.Color=color;r.WC=color end
 if r.WM~=material then p.Material=material;r.WM=material end
 if r.At~=at or r.Posed~=state.PoseKey then
  r.At=at;r.Home=nil;r.Posed=state.PoseKey
  frameSet(state,p,base*CF(at)*r.Rot)
 end
end
function G.Apply(state,crop,now)
 if state.Mech then return require(script.Parent.MechGrowth).Apply(state,crop,now,G.Progress)end
 if state.Verity then return require(script.Parent.VerityGrowth).Apply(state,crop,now,G.Progress)end
 local stats=G.Stats;stats.Applies+=1
 local def=state.Def;local count=def.FruitCount;local steps=T.Steps
 local body=G.Progress(crop,def,now)
 local prog,ready,wprog,wready,dirty=state.Prog,state.Ready,state.WProg,state.WReady,state.Dirty
 local first=not state.Written
 local mutation=crop.Mutation
 local bodyDirty=first or state.WMutation~=mutation or math.abs(body-state.WBody)*steps>=1 or(body>=1)~=(state.WBody>=1)
 local anyFruit=false
 for i=1,count do
  local _,f=G.Progress(crop,def,now,i);prog[i]=f;ready[i]=Rules.FruitReady(crop,i,now)
  local d=first or wready[i]~=ready[i]or math.abs(f-wprog[i])*steps>=1 or(f>=1)~=(wprog[i]>=1)
  dirty[i]=d;if d then anyFruit=true end
 end
 local busy=sproutBusy(state,crop,now)
 local base=state.Pose or state.Origin
 -- Growth is finished: the last pose is always written, and at rest (a pose a sway left behind would otherwise stay).
 local final=body>=1
 if final then for i=1,count do if prog[i]<1 then final=false;break end end end
 if final and state.Pose then state.Pose=nil;state.PoseKey=(state.PoseKey or 0)+1;base=state.Origin;bodyDirty=true end
 if not(bodyDirty or anyFruit)then
  -- Nothing moved by 1/Steps: nothing is written (the sprout still plays by the clock).
  if busy or state.WBusy then
   if state.Frozen then seedlingClassic(state,body,base)else seedlingNew(state,crop,now,body,base)end
   state.WBusy=busy
  end
  stats.Skips+=1
  return body,prog[1]or 0
 end
 stats.Rewrites+=1
 local classic=state.Frozen
 local plainCoat=mutation=='None'or mutation==nil
 local starfruit=state.Id=='StarfruitSeed'
 local scale,alive
 if classic then
  local gs=state.GS
  scale=body>=1 and 1 or ease(.025,1,body)^(state.Profile=='Tree'and(.84+gs*.12)or state.Profile=='Vine'and(.68+gs*.10)or(.73+gs*.14))
  alive=body>.028
  seedlingClassic(state,body,base)
 else
  scale=G.Shape(body);alive=body>0
  seedlingNew(state,crop,now,body,base)
 end
 state.WBusy=busy
 if not classic and body<1 and state.Leaves and bodyDirty then leaves(state,body,scale)end
 for _,r in ipairs(state.Parts)do
  local p=r.Part;local index=r.Gi
  if p.Parent and(bodyDirty or(r.Fruit and dirty[index]))then
   local ripe=ready[index]
   local alpha=r.Alpha;local color=r.Color;local material=r.Material
   local at,size,amount
   if r.Fruit then
    local f=prog[index]or prog[1]
    local anchor=r.Anchor or V(table.unpack(def.Sockets[r.Group]))*(crop.PlantScale or 1)
    if classic then
     local factor=ease(.015,1,f)
     at=(anchor+(r.Pos-anchor)*factor)*scale;amount=scale*factor
     if f<.01 then alpha=1 end
     if plainCoat and not starfruit then color=green:Lerp(r.Color,ease(.30,.94,f))end
     if f<.82 then material=Enum.Material.SmoothPlastic end
    else
     local factor=G.Swell(f)
     at=(anchor+(r.Pos-anchor)*factor)*scale;amount=scale*factor
     if plainCoat and not starfruit then color=ripenPart(r,ease(T.ColourFrom,T.ColourTo,f))end
     -- The real material (Neon, Wood, Sand ...) switches on at the ripe moment, together with the cue (it used to snap at 82 %).
     if not ripe then material=Enum.Material.SmoothPlastic end
    end
   elseif classic then
    if r.Foliage and body<1 then
     -- Today: foliage fades in through transparency (the ghost look).
     local start=.12+(r.Index%5)*.025;alpha=1-(1-r.Alpha)*ease(start,.78+(r.Index%3)*.04,body)
    elseif body<1 and plainCoat then color=green:Lerp(r.Color,ease(.25,.78,body))end
    at=r.Pos*scale;amount=scale
   elseif r.Foliage and body<1 then
    -- #5: a leaf keeps its opacity and grows out of the point where it touches its parent, lower leaves first (the leaves pre-pass above).
    if r.LAt then at=r.LAt;amount=r.LAmount
    else at=r.Pos*scale;amount=body>=r.LeafStart and scale or 0 end -- (G.PlainLeaves: with the plant, appearing in turn)
   else
    if body<1 and plainCoat then color=green:Lerp(r.Color,ease(.25,.78,body))end
    at=r.Pos*scale;amount=scale
   end
   local s0=r.Size;size=V(math.max(.01,s0.X*amount),math.max(.01,s0.Y*amount),math.max(.01,s0.Z*amount))
   local tr=alive and amount>.0001 and alpha or 1
   putPart(state,r,p,size,tr,color,material,ripe and body>=1 and r.Query or false,at,base)
  end
 end
 buds(state,crop,scale,alive,base,bodyDirty)
 state.Posed=true
 -- What was written (the next call compares with it): the whole plant when its growth moved, otherwise only the fruit that moved.
 state.Written=true
 if bodyDirty then state.WBody=body;state.WMutation=mutation end
 for i=1,count do if bodyDirty or dirty[i]then wprog[i]=prog[i];wready[i]=ready[i]end end
 state.Model:SetAttribute('VisualGrowth',body);state.Model:SetAttribute('VisualFruitGrowth',prog[1]or 0)
 return body,prog[1]or 0
end
-- #2 sway: move every part of a drawn plant to `pose` (nil = rest) through the caller's batch. The grown pose of each part (Home) is kept by the
-- writer above, so this costs one batched move per visible part. G.Apply keeps writing at the same pose until the pose is changed again.
function G.Place(state,pose,batch)
 if not state.Written then return 0 end
 state.Pose=pose;state.PoseKey=(state.PoseKey or 0)+1
 local base=pose or state.Origin;local n=0
 for _,r in ipairs(state.Parts)do
  local p=r.Part
  if p.Parent and r.WT~=1 and r.At then
   local home=r.Home;if not home then home=CF(r.At)*r.Rot;r.Home=home end
   r.Posed=state.PoseKey;batch:Set(p,base*home);n+=1
  end
 end
 local function put(t,p)if t.Home and p.Parent and t.WT~=1 then batch:Set(p,base*t.Home);n+=1 end end
 put(state.SeedT,state.Seed);for i,p in ipairs(state.Sprout)do put(state.SproutT[i],p)end
 for _,b in pairs(state.Buds)do put(b.PartT,b.Part);if b.StemT.Home then put(b.StemT,b.Stem)end end
 return n
end
-- Every part this growth state moves (a rig that poses the rest of the plant leaves them out).
function G.Parts(state,out)
 out=out or{};for _,r in ipairs(state.Parts)do out[r.Part]=true end
 if state.Seed then out[state.Seed]=true end;for _,p in ipairs(state.Sprout or{})do out[p]=true end
 for _,b in pairs(state.Buds or{})do out[b.Part]=true;out[b.Stem]=true end
 return out
end
return G
