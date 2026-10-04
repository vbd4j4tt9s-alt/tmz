--!nocheck
-- R149 (owner): "for the snow biome add the snow patches there as permanent". The real SnowBiome149.client.lua next to the real R148
-- KeyboardTrack.client.lua (which covers the whole track floor with keys) on the Roblox mock world:
--  * patches lie in the Snow stage only, ABOVE the resting key tops (no coplanar surface with a key, a block, the bed or the floor),
--    never in the spacebar zone, never past the biome ends or the floor edges, never near a pack or a keeper camp;
--  * the dust is hidden near the runner (the legends under his feet stay readable) and fades in beyond;
--  * level of detail by distance, budgets per ClientFxBudget tier, bounded work while running at 1000 studs/s, deterministic layout
--    (the same patches whatever route the runner took), permanent (the weather changes nothing), teardown.
-- ADDED by the R149 performance patch (review part 1, fix round A), section 5b: patches are opaque; neighbouring patches lie on four different
-- planes (no two overlapping patches coplanar, checked on the scene and on a 300-row layout); a shovel hole is never covered (and the patches come
-- back when it is filled, also in a stretch that is not built yet); packs / camps that move, appear or go re-open and close their cells.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local RS,workspace=W.RS,W.workspace
local abs,floor,max,min,sqrt=math.abs,math.floor,math.max,math.min,math.sqrt
local WW=W.module('WeatherWorld149');local K=W.module('KeyboardTrack');local C=K.Config;local F=C.FloorTop;local B=WW.Biome
local ATTR={BiomeTrackEndZ=5980,BiomeStartZ_1=-100,BiomeEndZ_1=80,BiomeStartZ_6=80,BiomeEndZ_6=530,BiomeStartZ_2=530,BiomeEndZ_2=1180,
 BiomeStartZ_3=1180,BiomeEndZ_3=2030,BiomeStartZ_4=2030,BiomeEndZ_4=3080,BiomeStartZ_5=3080,BiomeEndZ_5=4380,BiomeStartZ_7=4380,BiomeEndZ_7=5980}
local Z0,Z1=1180,2030
local SPACE=C.SpaceRows*C.Pitch+3     -- the keyboard's spacebar (3 rows of 3 studs) plus a margin, independent of the patch layout's own constant
local function frames(sec)W.frames(floor(sec*60+.5),1/60)end

-- world: the keyboard's own harness (see docs/proposals/R148/preview/dump_keyboard.luau)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return {player}end
function workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play()end;function R.Inst.Stop()end
W.service('ContentProvider').PreloadAsync=function()end
local tier=3
W.stub('ClientFxBudget',{Get=function()return tier end,Low=function()return tier==1 end})
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace
for k,v in pairs(ATTR)do map:SetAttribute(k,v)end
local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55)
local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=RS
local model=R.new('Model');model.Name='Tester'
local rootPart=R.new('Part');rootPart.Name='HumanoidRootPart';rootPart.Size=V3(2,2,1);rootPart.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.Parent=model;model.PrimaryPart=rootPart;model.Parent=workspace;player.Character=model
local function runnerAt(x,z)rootPart.CFrame=CF(x,F+3,z)end
local function connected(sig)local n=0;for _,c in ipairs(sig._c)do if c.Connected then n+=1 end end;return n end
local heartbeat0=connected(W.Run.Heartbeat)
-- packs and a keeper camp of the Snow biome (read once a second)
local seeds=R.new('Folder');seeds.Name='Seeds';seeds.Parent=map
local camps=R.new('Folder');camps.Name='GuardianEncounters';camps.Parent=map

-- Find present patch cells of each kind (from the pure layout) to place the avoid zones and the runner.
local function firstPatch(kind,fromRow,toRow,col0,col1)
 local s={}
 for j=fromRow,toRow do for i=col0,col1 do if WW.BiomeSpec(i,j,Z0,Z1,0,s)and s.Kind==kind then return i,j,s.X,s.Z end end end
end
local ei,ej,ex,ez=firstPatch('edge',15,25,0,0)           -- an edge drift in column 0 (x = -90 .. -75), a little ahead of the runner
check(ei~=nil,'layout has an edge drift to test the pack clearance with')
local pack=R.new('Model');pack.Name='SnowPack';pack:SetAttribute('Stage',3);pack.Parent=seeds;pack.CFrame=CF(ex,F+1,ez)
local camp=R.new('Model');camp.Name='SnowKeeper';camp:SetAttribute('Stage',3);camp:SetAttribute('GuardianHomeCFrame',CF(-80,F,1500));camp.Parent=camps
local otherPack=R.new('Model');otherPack.Name='LavaPack';otherPack:SetAttribute('Stage',4);otherPack.Parent=seeds;otherPack.CFrame=CF(ex+200,F,ez)

local fakeNow=0
local kb=R.new('LocalScript');kb.Name='KeyboardTrack';W.load('KeyboardTrackClient',kb)
runnerAt(0,1500)
local sb=R.new('LocalScript');sb.Name='SnowBiome149';W.load('SnowBiome',sb)
frames(4)
local function folder()return workspace:FindFirstChild('_SnowBiomeR149')end
local function allDiscs()
 local out={};local f=folder();if not f then return out end
 for _,d in ipairs(f:GetChildren())do if d.Name=='Snow patch'and d.CFrame.Position.Y>0 then out[#out+1]=d end end
 return out
end
local function visible()local out={};for _,d in ipairs(allDiscs())do if d.Transparency<1 then out[#out+1]=d end end;return out end
local function dist(d,rx,rz)local p=d.CFrame.Position;return sqrt((p.X-rx)^2+(p.Z-rz)^2)end
local vis=visible()
check(folder()~=nil and #vis>=40,('the Snow biome has patches around the runner (%d discs in view)'):format(#vis))

-- 1. Placement
local posOk,spaceOk,propsOk,thickOk=true,true,true,true
for _,d in ipairs(allDiscs())do
 local p=d.CFrame.Position
 if abs(p.X)>94 then posOk=false end
 if p.Z<Z0+SPACE-1e-6 or p.Z>Z1 then spaceOk=false end
 if d.Anchored~=true or d.CanCollide~=false or d.CanTouch~=false or d.CanQuery~=false or d.CastShadow~=false or d.Shape.Name~='Cylinder'then propsOk=false end
 if d.Size.X>.1 then thickOk=false end
end
check(posOk,'patches stay on the floor (|x| <= 94 at the lobe centres)')
check(spaceOk and B.SpaceClear>=SPACE,'nothing in the spacebar zone (first '..SPACE..' studs of the biome: the keyboard\'s 3 spacebar rows + 3) and nothing past the biome end')
check(propsOk and thickOk,'patches are thin Cylinder parts: anchored, no collision / touch / query / shadow')
-- Z-fighting against the keyboard: gather every plane the keyboard draws (tops of the bed, keys, blocks, spacebars) and the floor
local keyboard=workspace:FindFirstChild('KeyboardTrackVisuals')
local planes={[F]=true};local keyParts=0
for _,folderK in ipairs(keyboard:GetChildren())do for _,p in ipairs(folderK:GetChildren())do
 if p:IsA('BasePart')and p.Transparency<1 and p.CFrame.Position.Y>0 then
  keyParts+=1;planes[floor((p.CFrame.Position.Y+p.Size.Y/2)*1000+.5)/1000]=true
 end
end end
local maxTop=0;local nPlanes=0;for y in pairs(planes)do maxTop=max(maxTop,y);nPlanes+=1 end
check(keyParts>300 and nPlanes>=3,('keyboard around the runner: %d parts, %d distinct top planes (floor, bed, key / block layers)'):format(keyParts,nPlanes))
local clear,above=true,true
for _,d in ipairs(vis)do
 local y=d.CFrame.Position.Y;local bottom,top=y-d.Size.X/2,y+d.Size.X/2
 if bottom<maxTop+.05 then above=false end
 for plane in pairs(planes)do if abs(plane-bottom)<.04 or abs(plane-top)<.04 then clear=false end end
end
check(above,('every patch lies above the highest keyboard surface (%.2f): bottoms %.2f..%.2f'):format(maxTop,F+C.RestRise+B.Rise,F+C.RestRise+B.Rise+.02))
check(clear,'no patch face is coplanar with a key, block, bed or floor surface (within 0.04): no z-fighting')
local expectY=K.KeyTop(0)+B.Rise
local yOk=true;for _,d in ipairs(vis)do local bottom=d.CFrame.Position.Y-d.Size.X/2;if bottom<expectY-1e-6 or bottom>expectY+.012 then yOk=false end end
check(yOk,('patches rest on the resting key tops (%.2f) plus %.2f'):format(K.KeyTop(0),B.Rise))
check(next(workspace:FindFirstChild('KeyboardTrackVisuals'):GetChildren())~=nil and#keyboard:GetDescendants()>0 and not keyboard:FindFirstChild('Snow patch',true),'the keyboard\'s own folder is untouched: patches live in their own folder')

-- 2. Expected set: replicate the layout + LOD + dust rule + avoid zones from the pure module and compare disc counts
local avoidList={{ex,ez,16},{-80,1500,24}}
local function nearAvoid(x,z,extent)for _,a in ipairs(avoidList)do local r=a[3]+extent*.5;if (x-a[1])^2+(z-a[2])^2<r*r then return true end end;return false end
local function expectedDiscs(rx,rz,tn)
 local cfg=WW.Tier(tn).Biome;local rows,cols=WW.BiomeRows(Z0,Z1),WW.BiomeCols();local s={};local n,patches=0,0
 local clearR=K.Tier(tn).LegendRadius+6
 for j=0,rows-1 do for i=0,cols-1 do
  local xc,zc=-B.Half+(i+.5)*B.Cell,Z0+(j+.5)*B.Cell
  if(xc-rx)^2+(zc-rz)^2<=cfg.Radius^2 and WW.BiomeSpec(i,j,Z0,Z1,0,s)and not nearAvoid(s.X,s.Z,s.Extent)and not(s.Kind=='dust'and not cfg.Dust)then
   local d=sqrt((s.X-rx)^2+(s.Z-rz)^2)
   if s.Kind=='dust'then if d>clearR then n+=1 end
   else n+=WW.BiomeLobes(cfg,d,s.N)end
   patches+=1
  end
 end end
 return n,patches
end
local en,ep=expectedDiscs(0,1500,3)
check(#vis==en,('the discs in view are exactly the layout in the window: %d discs (%d expected from %d patches)'):format(#vis,en,ep))
check(#vis<=WW.Tier(3).Biome.Discs,'within the tier-3 part budget ('..#vis..' / '..WW.Tier(3).Biome.Discs..')')
-- packs and camps stay clear
local nearPack,nearCamp=0,0
for _,d in ipairs(allDiscs())do local p=d.CFrame.Position
 if(p.X-ex)^2+(p.Z-ez)^2<12^2 then nearPack+=1 end
 if(p.X+80)^2+(p.Z-1500)^2<20^2 then nearCamp+=1 end
end
check(nearPack==0 and nearCamp==0,'no snow within 12 studs of a Snow pack or 20 of the keeper camp (the other biome\'s pack changes nothing)')

-- 3. LOD by distance (tier 3: 3 lobes within 70 studs, 2 within 120, 1 beyond; far lobes drawn bigger). From the middle of the floor every
-- edge drift is 75+ studs away (2 and 1 discs); a runner on the edge sees the near ones in full.
local function lodAt(rx,rz)
 local bands={};local lodOk,bigOk,n=true,true,0
 local s={};local rows,cols=WW.BiomeRows(Z0,Z1),WW.BiomeCols();local vv=visible()
 for j=0,rows-1 do for i=0,cols-1 do
  local xc,zc=-B.Half+(i+.5)*B.Cell,Z0+(j+.5)*B.Cell
  if(xc-rx)^2+(zc-rz)^2<=170^2 and WW.BiomeSpec(i,j,Z0,Z1,0,s)and s.Kind~='dust'and not nearAvoid(s.X,s.Z,s.Extent)then
   local d=sqrt((s.X-rx)^2+(s.Z-rz)^2);local count=0;local firstSize
   for _,disc in ipairs(vv)do local p=disc.CFrame.Position
    for k=1,s.N do if abs(p.X-(s.X+s.LX[k]))<1e-3 and abs(p.Z-(s.Z+s.LZ[k]))<1e-3 then count+=1;if k==1 then firstSize=disc.Size.Z end end end
   end
   local want=WW.BiomeLobes(WW.Tier(3).Biome,d,s.N);bands[want]=true;n+=1
   if count~=want then lodOk=false end
   if want==1 and s.N>1 and firstSize and abs(firstSize-2*s.LA[1]*B.FarScale)>1e-3 then bigOk=false end
  end
 end end
 return lodOk,bigOk,bands,n
end
local lodOk,bigOk,bands,nLod=lodAt(0,1500)
check(lodOk and bands[2]and bands[1],('level of detail from the middle of the floor: 2 and 1 discs per patch (%d patches)'):format(nLod))
check(bigOk,'a far patch drawn with one disc is that disc scaled up ('..B.FarScale..'x)')
runnerAt(60,1500);frames(3)
local lodOk2,bigOk2,bands2,nLod2=lodAt(60,1500)
check(lodOk2 and bigOk2 and bands2[3]and bands2[2]and bands2[1],('level of detail from the edge: 3, 2 and 1 discs per patch by distance (%d patches)'):format(nLod2))
runnerAt(0,1500);frames(3)

-- 4. The dust rule: hidden near the runner, white beyond
local di,dj,dx,dz
for j=18,30 do for i=2,9 do local s={};if WW.BiomeSpec(i,j,Z0,Z1,0,s)and s.Kind=='dust'then di,dj,dx,dz=i,j,s.X,s.Z;break end end;if di then break end end
check(di~=nil,'layout has a dust patch in the middle of the biome')
runnerAt(dx+7,dz);frames(1.5)
local dustHidden,dustShown,dustBad,nearDust,farDust=0,0,false,0,0
local rx,rz=dx+7,dz;local clearR=K.Tier(3).LegendRadius+6
for _,d in ipairs(allDiscs())do
 if near(d.Size.X,B.DustThickness)then
  local dd=dist(d,rx,rz)
  if dd<=clearR then nearDust+=1;if d.Transparency~=1 then dustBad=true end end
  if dd>=clearR+B.DustFade then farDust+=1;if d.Transparency>B.FinalTransparency+1e-6 then dustBad=true end end
 end
end
check(nearDust>=1 and farDust>=2 and not dustBad,('dust: hidden within %d studs of the runner (%d patches), white beyond %d (%d patches)'):format(clearR,nearDust,clearR+B.DustFade,farDust))
-- he runs on: the dust he left behind comes back, the next dust ahead goes away
runnerAt(dx+7,dz+60);frames(1.5)
local backBad=false
for _,d in ipairs(allDiscs())do
 if near(d.Size.X,B.DustThickness)then
  local dd=dist(d,rx,rz+60);if dd<=clearR and d.Transparency~=1 then backBad=true end;if dd>=clearR+B.DustFade and d.Transparency>B.FinalTransparency+1e-6 then backBad=true end
 end
end
check(not backBad,'running on: dust near his new spot is hidden, dust behind him is back')

-- 5. Permanent: weather changes nothing; deterministic whatever route was taken
runnerAt(0,1500);frames(2)
local function signature()
 local out={}
 for _,d in ipairs(visible())do local p=d.CFrame.Position;if dist(d,0,1500)<=165 then out[#out+1]=string.format('%.3f,%.3f,%.3f|%.3f,%.3f|%.2f',p.X,p.Y,p.Z,d.Size.Y,d.Size.Z,d.Transparency)end end
 table.sort(out);return out
end
local sigA=signature()
for _,k in ipairs({'Blizzard','Rain','Thunderstorm','Clear'})do RS:SetAttribute('GlobalWeather',k);frames(10)end
frames(300)
local sigB=signature();local sameAB=#sigA==#sigB;for i=1,#sigA do if sigA[i]~=sigB[i]then sameAB=false end end
check(sameAB,'permanent: 5 minutes of every weather later the patches are exactly the same (position, size, transparency)')
-- another client: starts far away and runs in at 300 studs/s
runnerAt(0,1200);frames(2)
for z=1200,1500,5 do runnerAt(0,z);W.frames(1,1/60)end
frames(2)
local sigC=signature();local sameAC=#sigA==#sigC;for i=1,#sigA do if sigA[i]~=sigC[i]then sameAC=false end end
check(sameAC,('deterministic: arriving from 300 studs back builds the same %d discs as spawning there'):format(#sigA))

-- 5b. R149 review part 1 (findings 3, 6 and the avoid list): height steps (no two overlapping patches coplanar), opaque patches, shovel holes
-- are never covered, the avoid list follows packs / camps / holes that move or go.
do
 runnerAt(0,1500);frames(2)
 local rows,cols=WW.BiomeRows(Z0,Z1),WW.BiomeCols()
 local function patchesInView()
  local byPos={};for _,d in ipairs(visible())do local p=d.CFrame.Position;byPos[string.format('%.2f,%.2f',p.X,p.Z)]=d end
  local out={};local sp={}
  for j=0,rows-1 do for i=0,cols-1 do
   if WW.BiomeSpec(i,j,Z0,Z1,0,sp)then
    local discs={};for k=1,sp.N do local d=byPos[string.format('%.2f,%.2f',sp.X+sp.LX[k],sp.Z+sp.LZ[k])];if d then discs[#discs+1]=d end end
    if #discs>0 then out[#out+1]={I=i,J=j,Discs=discs,Kind=sp.Kind}end
   end
  end end
  return out
 end
 local function ellipse(d)
  local p=d.CFrame.Position;local up,look=d.CFrame.UpVector,d.CFrame.LookVector
  return {X=p.X,Z=p.Z,A=d.Size.Z/2,B=d.Size.Y/2,AX=-look.X,AZ=-look.Z,BX=up.X,BZ=up.Z}
 end
 local function inside(e,x,z)local dx,dz=x-e.X,z-e.Z;local u=dx*e.AX+dz*e.AZ;local v=dx*e.BX+dz*e.BZ;return(u/e.A)^2+(v/e.B)^2<=1 end
 local function overlaps(e1,e2)
  if inside(e2,e1.X,e1.Z)or inside(e1,e2.X,e2.Z)then return true end
  for t=0,23 do local a=t/24*2*math.pi
   for _,r in ipairs({1,.5})do
    local u,v=math.cos(a)*e1.A*r,math.sin(a)*e1.B*r
    if inside(e2,e1.X+u*e1.AX+v*e1.BX,e1.Z+u*e1.AZ+v*e1.BZ)then return true end
   end
  end
  return false
 end
 -- the discs reaching a circle (a hole's rim): points on the circle and its centre inside a disc
 local function reaching(x,z,r)
  local n=0
  for _,d in ipairs(visible())do
   local e=ellipse(d);local hit=inside(e,x,z)
   for t=0,15 do local a=t/16*2*math.pi;if inside(e,x+math.cos(a)*r,z+math.sin(a)*r)then hit=true end end
   if hit then n+=1 end
  end
  return n
 end
 local base=K.KeyTop(0)+B.Rise
 local list=patchesInView()
 -- every patch lies on its cell's plane (all its lobes on one), in four steps .004 apart
 local stepOk,lobesOk,levels=true,true,{}
 for _,pt in ipairs(list)do
  local want=WW.BiomeStep(pt.I,pt.J);levels[floor(want*1000+.5)]=true
  local d1=pt.Discs[1];local b1=d1.CFrame.Position.Y-d1.Size.X/2-base
  if not near(b1,want,1e-6)then stepOk=false end
  for _,d in ipairs(pt.Discs)do if not near(d.CFrame.Position.Y-d.Size.X/2-base,b1,1e-6)then lobesOk=false end end
 end
 local nLevels=0;for _ in pairs(levels)do nLevels+=1 end
 check(#list>=40 and stepOk and lobesOk and nLevels==4,('every patch lies on its own cell\'s plane: %d patches on %d levels (0 / .004 / .008 / .012 above the key tops + 0.1), all lobes of a patch in one plane'):format(#list,nLevels))
 check(near(WW.BiomeStep(0,0),0)and near(WW.BiomeStep(1,0),.004)and near(WW.BiomeStep(0,1),.008)and near(WW.BiomeStep(1,1),.012)and near(WW.BiomeStep(5,-3),WW.BiomeStep(1,1)),'the step is (i mod 2) + 2 (j mod 2) times .004')
 -- no two patches that overlap share a plane
 local pairsOverlapping,coplanar=0,0
 for a=1,#list do for b=a+1,#list do
  local A,Bp=list[a],list[b]
  if abs(A.I-Bp.I)<=2 and abs(A.J-Bp.J)<=2 then
   local hit=false
   for _,da in ipairs(A.Discs)do for _,db in ipairs(Bp.Discs)do if not hit and overlaps(ellipse(da),ellipse(db))then hit=true end end end
   if hit then
    pairsOverlapping+=1
    local ya=A.Discs[1].CFrame.Position.Y-A.Discs[1].Size.X/2;local yb=Bp.Discs[1].CFrame.Position.Y-Bp.Discs[1].Size.X/2
    if abs(ya-yb)<.004-1e-6 then coplanar+=1 end
   end
  end
 end end
 check(pairsOverlapping>=3 and coplanar==0,('%d pairs of patches overlap in the window and none of them lies in the same plane (%d coplanar)'):format(pairsOverlapping,coplanar))
 -- the whole layout of a long biome: no two overlapping patches of one level (any two cells up to 2 apart), by the layout itself
 do
  local specs={};local sp={}
  for j=0,299 do for i=0,cols-1 do
   if WW.BiomeSpec(i,j,0,300*B.Cell,0,sp)then
    local c={I=i,J=j,X=sp.X,Z=sp.Z,N=sp.N,LX={},LZ={},LA={},LB={},LY={}}
    for k=1,sp.N do c.LX[k],c.LZ[k],c.LA[k],c.LB[k],c.LY[k]=sp.LX[k],sp.LZ[k],sp.LA[k],sp.LB[k],sp.LY[k]end
    specs[#specs+1]=c
   end
  end end
  local function lobe(c,k)local sy,cy=math.sin(c.LY[k]),math.cos(c.LY[k]);local f=(k==1 and c.N>1)and B.FarScale or 1
   return {X=c.X+c.LX[k],Z=c.Z+c.LZ[k],A=c.LA[k]*f,B=c.LB[k]*f,AX=sy,AZ=cy,BX=-cy,BZ=sy}end
  local clash,total=0,0
  for a=1,#specs do for b=a+1,#specs do
   local A,Bp=specs[a],specs[b]
   if abs(A.I-Bp.I)<=2 and abs(A.J-Bp.J)<=2 then
    local hit=false
    for k=1,A.N do for m=1,Bp.N do if not hit and overlaps(lobe(A,k),lobe(Bp,m))then hit=true end end end
    if hit then total+=1;if WW.BiomeStep(A.I,A.J)==WW.BiomeStep(Bp.I,Bp.J)then clash+=1 end end
   end
  end end
  check(#specs>1000 and total>50 and clash==0,('a 300-row biome (%d patches): %d overlapping pairs, none on the same plane (%d)'):format(#specs,total,clash))
 end
 -- opaque: no patch is translucent any more (they were drawn in the sorted transparent pass for ever)
 local translucent,farDust=0,0;local clearR0=K.Tier(3).LegendRadius+6
 for _,d in ipairs(visible())do
  if not near(d.Size.X,B.DustThickness)then if d.Transparency~=0 then translucent+=1 end
  elseif dist(d,0,1500)>=clearR0+B.DustFade and d.Transparency~=0 then farDust+=1 end
 end
 check(B.FinalTransparency==0 and translucent==0 and farDust==0,('Snow-biome patches are opaque (FinalTransparency %s): %d translucent discs, %d translucent dust discs beyond the dust fade'):format(tostring(B.FinalTransparency),translucent,farDust))

 -- shovel holes: a patch would hide the trap (it lies 0.06 above the pit / rim), so no disc may reach a hole, and the patches come back when it goes
 local sig0=signature();local vis0=#visible()
 local rt=R.new('Folder');rt.Name='_GameplayRuntime';rt.Parent=map
 local holes=R.new('Folder');holes.Name='TrackHoles';holes.Parent=rt
 local digN=0
 local function dig(x,z)
  digN+=1;local m=R.new('Model');m.Name='TrackHole_'..digN
  local pit=R.new('Part');pit.Name='Pit';pit.Size=V3(.08,3.4,3.4);pit.CFrame=CF(x,F+.04,z);pit.Parent=m
  local rim=R.new('Part');rim.Name='Rim';rim.Size=V3(.04,4,4);rim.CFrame=CF(x,F+.02,z);rim.Parent=m
  m.PrimaryPart=pit;m.Parent=holes;return m
 end
 local target
 for _,pt in ipairs(list)do if not target and pt.Kind=='edge'and pt.I==cols-1 then target=pt end end
 check(target~=nil,'(an edge patch on the right-hand side is in view to dig under)')
 local hx,hz=target.Discs[1].CFrame.Position.X,target.Discs[1].CFrame.Position.Z
 check(reaching(hx,hz,2)>=1,'(before the hole there is a disc under it)')
 local hole=dig(hx,hz);frames(1.3)
 check(reaching(hx,hz,2)==0,'a hole dug under a patch: no disc reaches its rim within 1.3 s (the trap is visible)')
 check(#visible()<vis0 and #visible()>=vis0-12,('...only the patches over it went (%d discs of %d)'):format(vis0-#visible(),vis0))
 -- a hole in the Forest (z 0, outside the Snow biome) changes nothing here; a second hole in the Snow biome is kept clear too
 local keep=#visible()
 local forest=dig(0,0);frames(1.3)
 check(#visible()==keep,'a hole in the Forest (outside the Snow biome) changes nothing here')
 local far=dig(hx-40,hz);frames(1.3)
 check(reaching(hx-40,hz,2)==0 and #visible()>=keep-8,'a second hole 40 studs from the first: nothing reaches it either')
 far:Destroy();forest:Destroy();frames(1.3)
 check(#visible()==keep,'filling those holes brings their patches back (the cells were never put on the skip list)')
 hole:Destroy();frames(1.3)
 local sig1=signature()
 local same=#sig0==#sig1;for i=1,#sig0 do if sig0[i]~=sig1[i]then same=false end end
 check(same and #visible()==vis0,'the hole filled: exactly the patches that were there before come back')
 -- a hole in a stretch that is not built yet: its patch is never bound while the hole is there, and binds once it is gone
 local ti,tj,tx,tz
 for j=44,50 do if not ti then local sp={};if WW.BiomeSpec(cols-1,j,Z0,Z1,0,sp)and sp.Kind=='edge'then ti,tj,tx,tz=cols-1,j,sp.X+sp.LX[1],sp.Z+sp.LZ[1]end end end
 check(ti~=nil and sqrt((tx)^2+(tz-1500)^2)>WW.Tier(3).Biome.Radius+30,'(a patch far ahead, out of the window, to dig under)')
 local ahead=dig(tx,tz);frames(1.3)
 runnerAt(0,tz-60);frames(3)
 check(reaching(tx,tz,2)==0 and #visible()>40,'a hole in a stretch not built yet: the patch there is not bound when the runner arrives')
 ahead:Destroy();frames(2)
 local back=0;for _,d in ipairs(visible())do local p=d.CFrame.Position;if abs(p.X-tx)<.02 and abs(p.Z-tz)<.02 then back+=1 end end
 check(back==1,'...and it appears once the hole is filled')
 runnerAt(0,1500);frames(3)
 local sig2=signature();local same2=#sig0==#sig2;for i=1,#sig0 do if sig0[i]~=sig2[i]then same2=false end end
 check(same2,'(back at the start: the same discs within 165 studs)')
 -- the avoid list follows packs and camps that move, are added or go (it was only re-read when the NUMBER of packs changed)
 local function matches(label)
  -- the discs of the patches whose cell lies in the window (a few patches just past it stay until they are 15 studs beyond: hysteresis)
  local want=expectedDiscs(0,1500,3);local got=0
  for _,pt in ipairs(patchesInView())do
   local xc,zc=-B.Half+(pt.I+.5)*B.Cell,Z0+(pt.J+.5)*B.Cell
   if(xc-0)^2+(zc-1500)^2<=WW.Tier(3).Biome.Radius^2 then got+=#pt.Discs end
  end
  check(got==want,('avoid list: %s - %d discs in view, the layout says %d'):format(label,got,want))
 end
 matches('as built')
 local p2=nil;for _,pt in ipairs(list)do if not p2 and pt.Kind=='edge'and pt.I==cols-1 and sqrt((pt.Discs[1].CFrame.Position.Z-1500)^2)<80 then p2=pt end end
 local qx,qz=p2.Discs[1].CFrame.Position.X,p2.Discs[1].CFrame.Position.Z
 local noOldNear=0;for _,d in ipairs(visible())do local p=d.CFrame.Position;if(p.X-ex)^2+(p.Z-ez)^2<12^2 then noOldNear+=1 end end
 pack.CFrame=CF(qx,F+1,qz);avoidList[1]={qx,qz,16};frames(1.3)
 local oldBack,newNear=0,0
 for _,d in ipairs(visible())do local p=d.CFrame.Position;if(p.X-ex)^2+(p.Z-ez)^2<12^2 then oldBack+=1 end;if(p.X-qx)^2+(p.Z-qz)^2<12^2 then newNear+=1 end end
 check(noOldNear==0 and oldBack>=1 and newNear==0,('a pack that MOVED (the pack count did not change): snow comes back where it stood (%d discs) and keeps clear of where it is now (%d)'):format(oldBack,newNear))
 matches('pack moved')
 local extra=R.new('Model');extra.Name='SnowPack2';extra:SetAttribute('Stage',3);extra.CFrame=CF(-60,F+1,1560);extra.Parent=seeds
 avoidList[3]={-60,1560,16};frames(1.3);matches('a second pack added')
 pack.CFrame=CF(ex,F+1,ez);avoidList[1]={ex,ez,16};frames(1.3);matches('the pack back')
 extra:Destroy();avoidList[3]=nil;frames(1.3);matches('the second pack gone')
 camp.Parent=nil;avoidList[2]=nil;frames(1.3);matches('the keeper camp gone')
 camp.Parent=camps;avoidList[2]={-80,1500,24};frames(1.3);matches('the keeper camp back')
 local sig3=signature();local same3=#sig0==#sig3;for i=1,#sig0 do if sig0[i]~=sig3[i]then same3=false end end
 check(same3,'(everything back as at the start: the same discs within 165 studs)')
end

-- 6. Running fast through the biome: bounded work
local function mine()return #folder():GetChildren()end
local worstFrame,discsMax=0,0
local lastCount=mine()
for z=1250,1950,1000/60 do
 runnerAt(0,z);W.frames(1,1/60)
 local n=mine();worstFrame=max(worstFrame,n-lastCount);lastCount=n
 discsMax=max(discsMax,#allDiscs())
end
check(discsMax<=WW.Tier(3).Biome.Discs,('1000 studs/s through the biome: parts stay within the budget (%d / %d)'):format(discsMax,WW.Tier(3).Biome.Discs))
check(worstFrame<=130,('...and at most %d new parts in a single frame'):format(worstFrame))
frames(2)
-- (the stretch is walked once first: the pool settles on what it needs there - a couple of discs more or less than the sprint's peak, whatever
-- phase the 5 Hz step clock is in - and then it never creates anything again)
for z=1500,1700,2 do runnerAt(0,z);W.frames(1,1/60)end
frames(2)
local n0=mine()
for z=1500,1700,2 do runnerAt(0,z);W.frames(1,1/60)end
check(mine()==n0,'walking through already-built stretches creates nothing new')

-- 7. Tiers
local function atTier(t)runnerAt(0,1500);frames(2);tier=t;frames(6)end
atTier(2)
local v2=visible();local en2=expectedDiscs(0,1500,2)
check(#v2==en2 and #v2<=WW.Tier(2).Biome.Discs and #v2<#vis,('tier 2: %d discs (budget %d, window %d studs)'):format(#v2,WW.Tier(2).Biome.Discs,WW.Tier(2).Biome.Radius))
atTier(1)
local v1=visible();local en1=expectedDiscs(0,1500,1)
local thin,farthest=0,0;for _,d in ipairs(v1)do if near(d.Size.X,B.DustThickness)then thin+=1 end;farthest=max(farthest,dist(d,0,1500))end
check(#v1==en1 and #v1<=WW.Tier(1).Biome.Discs and thin==0 and farthest<=WW.Tier(1).Biome.Radius+B.Cell+14,('tier 1: %d discs, no dust, nothing beyond ~%d studs (%d, farthest %.0f)'):format(#v1,WW.Tier(1).Biome.Radius,thin,farthest))
check(#v1<#v2 and #v2<#vis,'fewer parts on lower tiers')
tier=3;frames(6)
check(#visible()==#vis,'back to tier 3: the same patches as before')
-- the pool never outgrows its budget even after tier swaps
check(#allDiscs()<=WW.Tier(3).Biome.Discs,'part pool within the budget after the tier changes')

-- 8. Other places
runnerAt(0,0);frames(2)
check(#visible()==0,'in the Forest (z = 0) there are no Snow patches')
runnerAt(0,1100);frames(2)
local nearStart=#visible()
check(nearStart>0,'approaching the Snow biome from the Desert side the first patches are already there ('..nearStart..')')
local firstZ=math.huge;for _,d in ipairs(visible())do firstZ=min(firstZ,d.CFrame.Position.Z)end
check(firstZ>=Z0+SPACE,'...and none of them is in the spacebar zone ('..string.format('%.1f',firstZ)..' >= '..(Z0+SPACE)..')')
runnerAt(0,2020);frames(2)
local lastZ=-math.huge;for _,d in ipairs(visible())do lastZ=max(lastZ,d.CFrame.Position.Z)end
check(lastZ<=Z1,'at the far end nothing sticks out of the biome ('..string.format('%.1f',lastZ)..')')

-- 9. The keyboard goes away (or has not been built): the patches sit on the bare floor instead
runnerAt(0,1500);frames(2)
kb.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'(keyboard torn down)')
local lowOk=true;local lowest=0
for _,d in ipairs(visible())do local bottom=d.CFrame.Position.Y-d.Size.X/2;if not near(bottom,F+B.Rise,.012)then lowOk=false end;lowest=bottom end
check(lowOk and #visible()>0,('without the keyboard the patches drop to the floor (+%.2f)'):format(B.Rise))

-- 10. Teardown
sb.Destroying:Fire()
check(folder()==nil and connected(W.Run.Heartbeat)==heartbeat0,'teardown removes the folder and disconnects every Heartbeat connection (keyboard included)')
frames(2);check(folder()==nil,'a destroyed script does nothing more')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
