--!nocheck
-- R147 (owner: "The Verity seed is just a small Verity ball which players can plant into the ground; the ball grows into a
-- giant Verity fruit which is just a ball, with leaves at its bottom"): the real VerityPlantArt, VerityGrowth, ApprovedPlantArt,
-- PlantGrowth, PlantVisuals and SeedPackVisuals on the Roblox mock.
--  * the seed: one small yellow (255,255,0) Ball part (<= 1.5 studs), King sparkle and motion tag, Gold / Diamond coats; R151: no gloss or glint part;
--  * the plant (PlantVisuals.BuildGrowing, the client path): the ball is Ø1.3 / 1.9 / 6.6 / 10.1 / 16.4 / 22 at 0 / 10 / 33 / 45 / 66 /
--    100% of the growth, on the leaf ring (bottom at the socket), the leaves grow from their bases and no part goes over the
--    budget; after the first harvest the ball regrows on the full leaf ring; a picked ball is hidden; scale (plant 2, fruit 1.5),
--    the harvest prompt, the distant (supports + proxy) path, the harvested fruit, EndGrowth;
--  * R148 (owner: "the exact same smile that Verity has" on the seed, the fruit and the plant): VerityCatalog.FaceImageId is Verity's
--    picture (= VerityConfig.Image) and it is ONE white Decal (no tint; R151, owner: "verity fruit also has 2 faces") on the seed, on the plant's ball at
--    every growth stage and regrowth, on the harvested fruit, in the inventory / hotbar pictures and the Index cards, hidden with the ball when picked.
--    R151: which side: Front (-Z) for the seed, the fruit as an item (hotbar / Bag / sell pictures, held) and the Index cards (the cameras look from -Z), Back (+Z) for
--    the PLANTED fruit (the plant's surface details and the garden's front lie on +Z: the face looks at the path); no gloss / glint part anywhere;
--  * coats (plain, Gold, Diamond; the face stays on top) and the face image option (VerityCatalog.FaceImageId);
--  * existing plants unchanged: the plant art / growth pipeline of the base commit (PlantVisualsBase + PlantGrowthBase +
--    ApprovedPlantArtBase, from git) against the current one, part by part, on four existing plants.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function colorIs(c,r,g,b)local x,y,z=rgb(c);return x==r and y==g and z==b end
-- The real catalog entry (VerityCatalog.ApplyPlants, called by PlantCatalog).
local Catalog=W.module('PlantCatalog')
local def=Catalog.VeritySeed
assert(def and def.Verity==true and def.FruitCount==1,'PlantCatalog has the Verity entry')
local Cat=W.module('VerityCatalog');local Art=W.module('VerityPlantArt');local Growth=W.module('VerityGrowth')
local Rules=W.module('PlantRules');local Approved=W.module('ApprovedPlantArt');local PG=W.module('PlantGrowth')
local Visuals=W.module('PlantVisuals');local SeedVisuals=W.module('SeedPackVisuals');local PackRules=W.module('SeedPackRules')
local ID='VeritySeed';local DAY=def.Seconds
local IMAGE='rbxassetid://102712963740896' -- Verity's smiley (VerityConfig.Image)
local Config=W.module('VerityConfig')
local savedFace=Cat.FaceImageId
local origin=CF(10,0,5)*R.CFrame.Angles(0,.7,0)
local function crop(extra)
 local c={Id='verity-1',SeedId=ID,PlantedAt=0,MatureAt=DAY,ReadyAt=DAY,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1,
  _VisualHarvest={Index=1,Scale=1,Mutation='None'}}
 for k,v in pairs(extra or{})do c[k]=v end;return c
end
local function specParts(model)local out={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')and d:GetAttribute('GrowthForm')~=nil then out[#out+1]=d end end;return out end
local function named(model,name)local out={};for _,d in ipairs(specParts(model))do if d.Name==name then out[#out+1]=d end end;return out end
local function ballOf(model)return named(model,'Verity fruit')[1]end
local function local_(p)return origin:ToObjectSpace(p.CFrame).Position end
local function bottom(ball)return local_(ball).Y-ball.Size.Y/2 end
-- Midrib length of each leaf (by ArtSpecIndex) = its growth factor times the full length.
local function midribs(model)
 local out={};for _,d in ipairs(named(model,'Leaf midrib'))do out[d:GetAttribute('ArtSpecIndex')]=d end;return out
end
local full
do
 local m=Visuals.BuildGrowing(ID,origin,crop(),DAY);full={};for i,d in pairs(midribs(m))do full[i]=d.Size.Y end
end
local function leafFactors(model)local out={};for i,d in pairs(midribs(model))do out[i]=d.Size.Y/full[i]end;return out end
local function range(t)local lo,hi=math.huge,-math.huge;for _,v in pairs(t)do lo=math.min(lo,v);hi=math.max(hi,v)end;return lo,hi end
local function plantAt(frac,extra)return Visuals.BuildGrowing(ID,origin,crop(extra),frac*DAY)end
local function decalsOf(inst)local out={};for _,d in ipairs(inst:GetDescendants())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
-- Verity's face on a ball part (R151): exactly ONE Decal with the exact picture, white, untinted, on `side` ('Front' = the default: the seed, the fruit as an item, the
-- pictures; 'Back' = the planted fruit); `hidden` = fully transparent. No Decal on any other side.
local function faceOk(ball,hidden,image,side)
 local ds,n={},0;for _,d in ipairs(ball:GetChildren())do if d:IsA('Decal')then ds[d.Face.Name]=d;n+=1 end end
 local want=hidden and 1 or 0;local tex=image or IMAGE;local at=ds[side or'Front']
 return n==1 and at~=nil and at.Texture==tex and colorIs(at.Color3,255,255,255)and at.Transparency==want
end
-- No part of the fruit or the seed is a gloss / glint / shine patch (R151: the owner asked for them to go).
local function noGloss(model,label)
 local bad={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then local n=d.Name:lower();if n:find('gloss')or n:find('glint')or n:find('shine')or n:find('sheen')or d:GetAttribute('VerityDecor')then bad[#bad+1]=d.Name end end end
 return check(#bad==0,label..': no gloss / glint part ('..table.concat(bad,', ')..')')
end

-- 1. Art and routing -------------------------------------------------------------------------------------------------
check(Cat.Is(ID)and Approved.Has(ID)==true and Approved.Has('NoSuchSeed')==false,'ApprovedPlantArt knows the Verity seed (and not a made-up one)')
local art=Approved.Get(ID,crop())
check(art and art.RarityRework==true and #art.Specs==15,'the art is a RarityRework spec list of 15 pieces: 14 leaves and the ball (R151: no gloss) ('..tostring(art and #art.Specs)..')')
check(art.Height==23.6 and art.Radius==11.2 and art.Sockets[1][2]==1.6 and art.FruitCenters[1][2]==12.6 and art.FruitRadii[1]==11,'height / radius / socket / fruit centre / fruit radius as agreed with the catalog entry')
local leaves,fruit,cost=0,0,0
for _,s in ipairs(art.Specs)do cost+=Visuals.PartCost(s);if s.r=='Leaf'then leaves+=1;check(s.g==0 and s.s=='LeafBlade','leaf specs are LeafBlades in group 0')else fruit+=1;check(s.g==1,'fruit specs are group 1')end end
check(leaves==14 and fruit==1,'14 leaves (8 outer + 6 inner) and 1 fruit piece, the ball ('..leaves..' / '..fruit..')')
check(cost<=110,'PartCost budget '..cost..' <= 110')
local ballSpec;for _,s in ipairs(art.Specs)do if s.f=='Verity fruit'then ballSpec=s end end
check(ballSpec and ballSpec.s=='Sphere'and ballSpec.z[1]==22 and ballSpec.z[2]==22 and ballSpec.z[3]==22 and ballSpec.rf==.18 and ballSpec.m=='SmoothPlastic','the ball: a Sphere Ø22, SmoothPlastic, reflectance .18')
check(ballSpec.k[1]==255 and ballSpec.k[2]==255 and ballSpec.k[3]==0,'ball colour 255,255,0 (Verity\'s yellow)')
check(ballSpec.face==IMAGE,'the ball spec carries Verity\'s face image')
local outerOk,innerOk=true,true
for i,s in ipairs(art.Specs)do if s.r=='Leaf'then
 local c=i<=8 and s.k[1]==68 and s.k[2]==160 and s.k[3]==72;local d=i>8 and s.k[1]==96 and s.k[2]==188 and s.k[3]==88
 if i<=8 then outerOk=outerOk and c and s.z[1]==3.4 and s.z[2]==9 and s.z[3]==.35 else innerOk=innerOk and d and s.z[1]==2.6 and s.z[2]==6 and s.z[3]==.3 end
end end
check(outerOk and innerOk,'outer leaves 3.4x9x.35 (68,160,72), inner leaves 2.6x6x.3 (96,188,88)')
check(PG.Sway(ID,def,crop(),12.3).Position.Magnitude==0 and PG.Sway(ID,def,crop(),12.3).UpVector.Y>.999999,'PlantGrowth.Sway: no sway for the Verity plant')
check(PG.Sway('SunflowerSeed',Catalog.SunflowerSeed,crop({SeedId='SunflowerSeed'}),12.3).UpVector.Y<.99999999,'PlantGrowth.Sway: other plants still sway')

-- 2. The first growth ------------------------------------------------------------------------------------------------
print('first growth (ball diameter / bottom, leaf factors min..max):')
local targets={{0,1.3,0},{.10,1.9,.08},{.33,6.6,.77},{.45,10.1,1},{.66,16.4,1},{1,22,1}}
local over=0
for _,t in ipairs(targets)do
 local m=plantAt(t[1]);local ball=ballOf(m);local lo,hi=range(leafFactors(m))
 print(('  %3d%%  ball %.2f  bottom %.2f  leaves %.3f..%.3f  parts %d'):format(t[1]*100,ball.Size.X,bottom(ball),lo,hi,#specParts(m)))
 check(near(ball.Size.X,t[2],.3)and near(ball.Size.Y,ball.Size.X)and near(ball.Size.Z,ball.Size.X),('ball Ø %.1f at %d%% (got %.2f)'):format(t[2],t[1]*100,ball.Size.X))
 check(#specParts(m)<=110,'part count '..#specParts(m)..' <= 110 at '..t[1]*100 ..'%')
 over=math.max(over,#specParts(m))
 if t[1]==0 then
  check(hi<.01,'0%: no leaves yet ('..hi..')');for _,p in ipairs(named(m,'Verity leaf'))do check(p.Transparency==1,'0%: leaf piece hidden')end
  check(near(bottom(ball),0,.02),'0%: the seed-sized ball sits on the soil (bottom '..bottom(ball)..')')
 elseif t[1]==.10 then check(near(hi,.08,.02),'10%: leaves '..hi..' ~ 8%')
 elseif t[1]==.33 then check(near(hi,.77,.03),'33%: leaves '..hi..' ~ 77%')
 elseif t[1]==.45 then check(lo>=.84 and hi>=.99,'45%: the leaves are (nearly) full: 84-99% by the stagger of four ('..lo..'..'..hi..')')
 else check(lo>.9999,'full leaves from 56%: '..lo)end
 if t[1]>=.33 then
  check(near(bottom(ball),1.6,.02),('%d%%: the ball sits on the leaf ring, bottom at the socket 1.6 (got %.3f)'):format(t[1]*100,bottom(ball)))
  local c=local_(ball);check(near(c.X,0,.01)and near(c.Z,0,.01),'the ball stays over the plant axis')
 end
 check(ball.Material.Name=='SmoothPlastic'and colorIs(ball.Color,255,255,0)and near(ball.Reflectance,.18),'ball colour (Verity yellow 255,255,0) / material / reflectance never change')
 check(ball.Shape.Name=='Ball','the plant ball is a true Ball part')
 check(faceOk(ball,false,nil,'Back')and #decalsOf(m)==1,('%d%%: Verity\'s ONE face (toward the path, +Z; the exact image, white) is on the ball and nowhere else'):format(t[1]*100))
 noGloss(m,('%d%%'):format(t[1]*100))
end
check(over==99,'99 parts in all: 14 leaves x 4 pieces + the ball + the seed pieces ('..over..')')
check(near(Growth.Diameter(0),1.3)and near(Growth.Diameter(1),22)and near(Growth.Diameter(.33),6.57,.01)and near(Growth.Diameter(.66),16.45,.01),'VerityGrowth.Diameter = 1.3 + 20.7*s(f)')
-- smooth, monotonic, bottom never below the soil or above the socket
local lastD,lastY,smooth=0,-1,true;local worstBottom=0
for i=0,100 do
 local m=plantAt(i/100);local ball=ballOf(m);local y=local_(ball).Y
 if ball.Size.X<lastD-1e-6 or y<lastY-1e-6 then smooth=false end
 worstBottom=math.max(worstBottom,bottom(ball));if bottom(ball)<-.001 then smooth=false end
 lastD=ball.Size.X;lastY=y
end
check(smooth and worstBottom<1.6001,'growth is monotonic (ball never shrinks or sinks) and the bottom stays between the soil and the socket')
-- leaves grow from their bases (each leaf's base point stays put while its length grows)
do
 -- The midrib is .78 of the leaf long, from .09 above the leaf's base: recover each leaf's base from it at two moments.
 local function bases(model)
  local out={}
  for i,d in pairs(midribs(model))do
   local cf=origin:ToObjectSpace(d.CFrame);local up=cf:VectorToWorldSpace(V3(0,1,0));local leafLength=d.Size.Y/.78
   out[i]=cf.Position-up*(d.Size.Y/2)-up*(.09*leafLength)
  end
  return out
 end
 local stays,n=true,0
 for _,frac in ipairs({.2,.5})do
  for i,b in pairs(bases(plantAt(frac)))do
   local s=art.Specs[i].base;n+=1
   if (b-V3(s[1],s[2],s[3])).Magnitude>.2 then stays=false;print('  leaf '..i..' base off by '..(b-V3(s[1],s[2],s[3])).Magnitude)end
  end
 end
 check(stays and n==28,'each leaf grows out of its own base on the ring ('..n..' leaf bases checked at 20% and 50%)')
end
-- Leaves never sink deep into the full ball (they hug its underside).
do
 local m=plantAt(1);local ball=ballOf(m);local c=local_(ball);local deepest=math.huge
 for _,p in ipairs(named(m,'Verity leaf'))do deepest=math.min(deepest,(local_(p)-c).Magnitude-ball.Size.X/2)end
 print(('  deepest leaf piece centre vs the full ball surface: %.2f studs'):format(deepest))
 check(deepest>-1.3,'no leaf piece is buried in the ball ('..deepest..')')
end
-- Harvest prompt: only the ready ball can be queried.
do
 local early,late=plantAt(.5),plantAt(1)
 check(ballOf(early).CanQuery==false and ballOf(late).CanQuery==true,'the ball is a harvest target only when ready')
 local anyLeaf=false;for _,p in ipairs(named(late,'Verity leaf'))do anyLeaf=anyLeaf or p.CanQuery end
 check(not anyLeaf,'leaves are never harvest targets')
end

-- 3. After the first harvest: the ball regrows on the full leaf ring -------------------------------------------------------
do
 local c=crop();Rules.StartFruitRegrowth(c,def,1,DAY)
 check(c.FruitStates and c.FruitStates['1'].ReadyAt==DAY+def.RegrowSeconds,'(regrowth started: ready after RegrowSeconds)')
 print('regrow after the first harvest:')
 for _,t in ipairs({{0,1.3},{.33,6.6},{.66,16.4},{1,22}})do
  local now=DAY+t[1]*def.RegrowSeconds
  local m=Visuals.BuildGrowing(ID,origin,c,now);local ball=ballOf(m);local lo=range(leafFactors(m))
  print(('  %3d%%  ball %.2f  bottom %.2f  leaves from %.3f'):format(t[1]*100,ball.Size.X,bottom(ball),lo))
  check(near(ball.Size.X,t[2],.3),('regrow %d%%: ball Ø %.1f (got %.2f)'):format(t[1]*100,t[2],ball.Size.X))
  check(near(bottom(ball),1.6,.02),'regrow: the ball sits on the leaf ring')
  check(faceOk(ball,false,nil,'Back')and #decalsOf(m)==1,('regrow %d%%: the face is on the ball'):format(t[1]*100))
  check(lo>.9999,'regrow: the leaves stay full')
  check(ball.CanQuery==(t[1]>=1),'regrow: harvestable only when full grown')
 end
end
-- Picked: hidden, then it regrows from seed size.
do
 local c=crop();local m=Visuals.BuildGrowing(ID,origin,c,DAY);local ball=ballOf(m);local pieces=named(m,'Verity fruit')
 local fruitPieces={};for _,p in ipairs(specParts(m))do if p:GetAttribute('GrowthGroup')==1 then fruitPieces[#fruitPieces+1]=p end end
 check(ball.Transparency==0 and ball.Size.X>21.9,'(ripe ball shown)')
 c.PickedMask=1;Visuals.UpdateGrowth(m,c,DAY+5)
 local hidden=true;for _,p in ipairs(fruitPieces)do if p.Transparency<1 or p.CanQuery then hidden=false end end
 check(hidden,'picked: the ball is hidden and cannot be queried')
 check(faceOk(ball,true,nil,'Back')and #decalsOf(m)==1,'picked: Verity\'s face is hidden with the ball (the Decal fully transparent)')
 local leafVisible=false;for _,p in ipairs(named(m,'Verity leaf'))do if p.Transparency<1 then leafVisible=true end end
 check(leafVisible,'picked: the leaves stay')
 c.PickedMask=0;Rules.StartFruitRegrowth(c,def,1,DAY+5);Visuals.UpdateGrowth(m,c,DAY+5)
 check(ball.Transparency==0 and near(ball.Size.X,1.3,.05)and near(bottom(ball),1.6,.02),'after the pick the ball is back at Ø1.3 on the leaf ring')
 check(faceOk(ball,false,nil,'Back'),'... with its face again')
 Visuals.UpdateGrowth(m,c,DAY+5+def.RegrowSeconds)
 check(near(ball.Size.X,22,.05)and ball.CanQuery,'... and is Ø22 and harvestable again when the regrow time is up')
end
-- EndGrowth finishes the plant at full size and drops the growth state.
do
 local c=crop();local m=Visuals.BuildGrowing(ID,origin,c,.3*DAY);local ball=ballOf(m)
 check(near(ball.Size.X,Growth.Diameter(.3),.01),'(growing)')
 Visuals.EndGrowth(m,c,DAY)
 check(near(ball.Size.X,22,.01)and Visuals.UpdateGrowth(m,c,DAY)==false,'EndGrowth: full size, growth state released (no sprout / bud pieces to clean up)')
 local st=Growth.Capture(m,ID,def,c,origin,{V3(0,1.6,0)})
 check(st.Verity==true and next(st.Buds)==nil and next(st.Sprout)==nil,'state: Verity=true, Buds={}, Sprout={}')
 check(PG.Capture(m,ID,def,c,origin,{V3(0,1.6,0)}).Verity==true and PG.Capture(m,'PlasmaPepperSeed',Catalog.PlasmaPepperSeed,crop({SeedId='PlasmaPepperSeed'}),origin,{}).Mech==true,'PlantGrowth.Capture routes Verity to VerityGrowth (Mech still to MechGrowth)')
end

-- 4. Scale: plant 2x, fruit 1.5x -------------------------------------------------------------------------------------------
do
 local extra={PlantScale=2,_VisualHarvest={Index=1,Scale=1.5,Mutation='None'}}
 local c=crop(extra);local m=Visuals.BuildGrowing(ID,origin,c,DAY);local ball=ballOf(m)
 check(near(ball.Size.X,33,.05)and near(bottom(ball),3.2,.02),('scaled: ball Ø%.2f (33), bottom %.3f (socket 3.2)'):format(ball.Size.X,bottom(ball)))
 check(faceOk(ball,false,nil,'Back'),'scaled: the face is on the big ball')
 check(near(midribs(m)[1].Size.Y,full[1]*2,.01),'scaled: leaves follow the plant scale (x2)')
 local m2=Visuals.BuildGrowing(ID,origin,c,.33*DAY);local b2=ballOf(m2)
 check(near(b2.Size.X,6.57*1.5,.05)and near(bottom(b2),3.2,.02),('scaled 33%%: ball Ø%.2f, bottom %.3f'):format(b2.Size.X,bottom(b2)))
 local m0=Visuals.BuildGrowing(ID,origin,c,0);check(near(bottom(ballOf(m0)),0,.02)and near(ballOf(m0).Size.X,1.3*1.5,.05),'scaled 0%: on the soil')
end

-- 5. The distant path (supports + fruit proxy) and the harvested fruit --------------------------------------------------------
do
 local c=crop();local parent=R.new('Model');parent.Parent=W.workspace
 Visuals.GrowingSupports(ID,origin,c,1,parent,.33*DAY)
 local ball=ballOf(parent)
 check(ball and near(ball.Size.X,6.57,.1)and near(bottom(ball),1.6,.02),'distant growth: the proxy ball grows the same way ('..tostring(ball and ball.Size.X)..')')
 check(ball and faceOk(ball,false,nil,'Back')and #decalsOf(parent)==1 and colorIs(ball.Color,255,255,0),'distant growth: the proxy ball is yellow with the face (it is what far players see)')
 check(#specParts(parent)<=110,'distant growth: '..#specParts(parent)..' parts')
 local leafPieces=named(parent,'Verity leaf');local hiddenLeaves=true
 for _,p in ipairs(leafPieces)do if p.Transparency>=1 then hiddenLeaves=false end end
 check(#leafPieces==14*4 and hiddenLeaves,'distant growth: 14 simplified leaves (4 pieces each), shown at 33% ('..#leafPieces..')')
 local zero=R.new('Model');zero.Parent=W.workspace;Visuals.GrowingSupports(ID,origin,crop(),1,zero,0)
 local allHidden=true;for _,p in ipairs(named(zero,'Verity leaf'))do if p.Transparency<1 then allHidden=false end end
 check(allHidden and near(ballOf(zero).Size.X,1.3,.02),'distant growth at 0%: no leaves, seed-sized ball')
 -- the server fallback for a regrowing fruit (GrowingFruitSupports): just the fruit, growing on the (already full) leaf ring
 local c2=crop();Rules.StartFruitRegrowth(c2,def,1,DAY)
 local folder=R.new('Model');folder.Parent=W.workspace;Visuals.GrowingFruitSupports(ID,origin,c2,folder,DAY+.5*def.RegrowSeconds)
 local rb=ballOf(folder)
 check(rb and near(rb.Size.X,Growth.Diameter(.5),.02)and near(bottom(rb),1.6,.02)and #named(folder,'Verity leaf')==0,'server regrow fruit: Ø'..tostring(rb and rb.Size.X)..' on the ring, no leaves of its own')
 check(rb and faceOk(rb,false,nil,'Back'),'server regrow fruit: the face is on it')
 local c3=table.clone(c2);c3.PickedMask=1;Visuals.UpdateGrowth(folder,c3,DAY+.5*def.RegrowSeconds+60);check(rb and faceOk(rb,true,nil,'Back'),'server regrow fruit: picked hides the face')
 -- no work when nothing visible changed (the client calls UpdateGrowth at 20 Hz for hours of growth)
 local mm=plantAt(.4);local b4=ballOf(mm);b4.Transparency=.5;Visuals.UpdateGrowth(mm,crop(),.4*DAY)
 check(b4.Transparency==.5,'UpdateGrowth at the same moment rewrites nothing')
 Visuals.UpdateGrowth(mm,crop(),.4*DAY+3600);check(b4.Transparency==0 and near(b4.Size.X,Growth.Diameter(.65),.02),'... and a later moment does')
 local item=Visuals.BuildSelectedFruit(ID,origin,crop(),{[1]=true},math.huge)
 local b3=ballOf(item)
 check(b3 and near(b3.Size.X,22,.01)and #named(item,'Verity leaf')==0 and #specParts(item)==1,'harvested fruit: the ball only, Ø22 ('..#specParts(item)..' pieces)')
 check(b3 and faceOk(b3,false,nil,'Back')and #decalsOf(item)==1 and colorIs(b3.Color,255,255,0),'the fruit of a planted crop (the flight, BuildSelectedFruit): yellow with ONE face, toward the path like the plant')
 noGloss(item,'harvested fruit')
 local presented=W.module('HarvestPresentation').Build({SeedId=ID,Mutation='None',Weather='None',VisualCrop={SourceCropId='sold-1',FruitIndex=1,HarvestCycle=0}})
 local b5=ballOf(presented)
 check(b5 and faceOk(b5)and #decalsOf(presented)==1,'held / sold fruit (HarvestPresentation.Build, the hotbar and sell-card model): ONE face, on the front (-Z: the pictures look from -Z, the hand holds it -Z forward)')
 noGloss(presented,'held / sold fruit')
 for _,coat in ipairs({'Gold','Diamond'})do
  local pm=W.module('HarvestPresentation').Build({SeedId=ID,Mutation=coat,Weather='None',VisualCrop={SourceCropId='sold-2',FruitIndex=1,HarvestCycle=0}})
  check(faceOk(ballOf(pm)),'held '..coat..' fruit: the face stays on top of the coat')
  noGloss(pm,'held '..coat..' fruit')
 end
end

-- 6. Coats -----------------------------------------------------------------------------------------------------------------
do
 local m=plantAt(1);local ball=ballOf(m)
 -- R151: no gloss patch, no hot spot: the plant's fruit group is the ball alone
 local fruitPieces={};for _,p in ipairs(specParts(m))do if p:GetAttribute('GrowthGroup')==1 then fruitPieces[#fruitPieces+1]=p end end
 check(#fruitPieces==1 and fruitPieces[1]==ball and #named(m,'Verity gloss')==0 and #named(m,'Verity glint')==0,'plain: the fruit is the ball alone (no gloss patch, no hot spot)')
 noGloss(m,'plain plant')
 for _,coat in ipairs({'Gold','Diamond'})do
  local e={Mutation=coat,_VisualHarvest={Index=1,Scale=1,Mutation=coat}}
  local mm=plantAt(1,e);local b=ballOf(mm)
  local r,gc,bc=rgb(b.Color)
  if coat=='Gold'then check(b.Material.Name=='Metal'and r>220 and gc>150 and gc<200 and bc<80 and b.Transparency==0 and near(b.Reflectance,.2),'Gold coat: golden Metal, reflectance .2')
  else check(b.Material.Name=='Glass'and bc>=250 and near(b.Transparency,.18)and near(b.Reflectance,.16),'Diamond coat: Glass, transparency .18, reflectance .16')end
  check(faceOk(b,false,nil,'Back')and #decalsOf(mm)==1,coat..': Verity\'s face stays on top of the coat (white, untinted, one side)')
  noGloss(mm,coat..' plant')
  local leafCoat=true;for _,p in ipairs(named(mm,'Verity leaf'))do leafCoat=leafCoat and p.Material.Name==(coat=='Gold'and'Metal'or'Glass')end
  check(leafCoat,coat..': the leaves wear the coat too')
  Visuals.UpdateGrowth(mm,crop(e),.5*DAY);check(near(b.Size.X,Growth.Diameter(.5),.01)and b.Material.Name==(coat=='Gold'and'Metal'or'Glass'),coat..': growth keeps the coat')
 end
end

-- 7. The seed ----------------------------------------------------------------------------------------------------------------
do
 local holder=R.new('Model');holder.Parent=W.workspace
 local seed=SeedVisuals.Seed({Id=ID},1,CF(3,2,1),holder,1,nil,'None')
 local size=seed:GetExtentsSize()
 check(seed.Name=='LooseSeed'and seed:GetAttribute('SeedId')==ID and seed:GetAttribute('Rarity')=='King'and seed:GetAttribute('SeedBiome')=='Verity'and seed:GetAttribute('SeedVisualScale')==1,'seed model: LooseSeed with SeedId / Rarity King / SeedBiome / SeedVisualScale')
 check(size.X<=1.5 and size.Y<=1.5 and size.Z<=1.5,('seed model is %.2f x %.2f x %.2f studs (<= 1.5)'):format(size.X,size.Y,size.Z))
 local body;for _,d in ipairs(seed:GetChildren())do if d.Name=='Verity seed'then body=d end end
 check(body and body.Shape.Name=='Ball'and near(body.Size.X,1.3)and near(body.Reflectance,.2)and colorIs(body.Color,255,255,0)and body.Material.Name=='SmoothPlastic','seed: a SmoothPlastic Ball Ø1.3, reflectance .2, Verity yellow 255,255,0')
 check(faceOk(body)and #decalsOf(seed)==1,'seed: Verity\'s ONE face (front, -Z; the exact image, white) on the ball only')
 local seedParts=0;for _,d in ipairs(seed:GetChildren())do if d:IsA('BasePart')then seedParts+=1 end end
 check(seedParts==2,'seed: the invisible root and the ball, nothing else (R151: no gloss, no glint) ('..seedParts..' parts)')
 noGloss(seed,'seed')
 local leafLike=false;for _,d in ipairs(seed:GetDescendants())do if d:IsA('BasePart')and d.Name:lower():find('leaf')then leafLike=true end end
 check(not leafLike,'seed: no leaves')
 local emitter;for _,d in ipairs(seed:GetDescendants())do if d.Name=='SeedRaritySparkles'then emitter=d end end
 check(emitter and emitter.Parent==seed.PrimaryPart and emitter.Rate==3,'seed: the King sparkle emitter is on the root')
 check(W.CS:HasTag(seed,PackRules.SeedMotion.Tag),'seed: tagged for the held / dropped seed motion')
 check(seed.Parent==holder and seed.PrimaryPart.Anchored==true and body.Anchored==true,'seed: parented, anchored when there is no weld root')
 local big=SeedVisuals.Seed({Id=ID},1,CF(0,0,0),holder,2,nil,'None');local b2;for _,d in ipairs(big:GetChildren())do if d.Name=='Verity seed'then b2=d end end
 check(near(b2.Size.X,2.6)and big:GetAttribute('SeedVisualScale')==2,'seed: scale 2 gives Ø2.6')
 local hand=R.new('Part');hand.Anchored=false;hand.Parent=W.workspace
 local held=SeedVisuals.Seed({Id=ID},1,CF(0,0,0),holder,1,hand,'None');local welds=0
 for _,d in ipairs(held:GetDescendants())do if d:IsA('WeldConstraint')then welds+=1;check(d.Part0==hand,'seed weld joins the carrying part')end end
 check(welds==2 and body.Anchored and held.PrimaryPart.Anchored==false,'seed: held seed is welded (root + the ball) and unanchored ('..welds..' welds)')
 local heldBall;for _,d in ipairs(held:GetChildren())do if d.Name=='Verity seed'then heldBall=d end end
 check(heldBall and faceOk(heldBall)and #decalsOf(held)==1,'held seed (Tool handle build): the face is on the ball')
 check(faceOk(b2)and #decalsOf(big)==1,'seed at scale 2: the face is on the ball')
 local picture=SeedVisuals.Seed({Id=ID},nil,CF(),nil,1,nil,'None');local pb;for _,d in ipairs(picture:GetChildren())do if d.Name=='Verity seed'then pb=d end end
 check(pb and faceOk(pb),'the hotbar / Bag picture build (ItemPictures: no index, no parent): the face is on the ball')
 for _,coat in ipairs({'Gold','Diamond'})do
  local s=SeedVisuals.Seed({Id=ID},1,CF(0,0,0),holder,1,nil,coat);local b;for _,d in ipairs(s:GetChildren())do if d.Name=='Verity seed'then b=d end end
  local r,gc,bc=rgb(b.Color)
  if coat=='Gold'then check(b.Material.Name=='Metal'and r>200 and bc<100 and near(b.Reflectance,.2),'seed Gold coat applies')
  else check(b.Material.Name=='Glass'and bc>240 and b.Transparency>=.15 and near(b.Reflectance,.16),'seed Diamond coat applies')end
  check(faceOk(b)and #decalsOf(s)==1,'seed '..coat..': the face stays on top of the coat')
  check(s:GetAttribute('Mutation')==coat,'seed '..coat..': Mutation attribute')
  noGloss(s,'seed '..coat)
 end
 check(select(1,pcall(SeedVisuals.Seed,{Id='SunflowerSeed'},1,CF(0,0,0),holder,1,nil,'None')),'an ordinary seed still builds through the same entry point')
end

-- 8. The face image (VerityCatalog.FaceImageId) ------------------------------------------------------------------------------------------
do
 check(IMAGE=='rbxassetid://102712963740896'and Cat.FaceImageId==IMAGE,'VerityCatalog.FaceImageId is the owner\'s picture id (rbxassetid://102712963740896)')
 check(Cat.FaceImageId==Config.Image,'VerityCatalog.FaceImageId == VerityConfig.Image (the NPC card and the ball show the same picture) ('..tostring(Config.Image)..')')
 check(Art.FaceTexture()==IMAGE,'VerityPlantArt.FaceTexture() gives it as the Decal wants it')
 -- another image id: a number, a digit string, a full url; and none at all
 Cat.FaceImageId=123456789
 local c=crop();local m=Visuals.BuildGrowing(ID,origin,c,DAY);local ball=ballOf(m)
 check(faceOk(ball,false,'rbxassetid://123456789','Back'),'a numeric id becomes rbxassetid://123456789 on the Decal')
 local seed=SeedVisuals.Seed({Id=ID},1,CF(0,0,0),W.workspace,1,nil,'None');local sb;for _,d in ipairs(seed:GetChildren())do if d.Name=='Verity seed'then sb=d end end
 check(sb and faceOk(sb,false,'rbxassetid://123456789'),'... and on the seed')
 Cat.FaceImageId='5551212';check(Art.FaceTexture()=='rbxassetid://5551212','a digit string gets its rbxassetid:// prefix')
 Cat.FaceImageId='rbxassetid://5551212';check(Art.FaceTexture()=='rbxassetid://5551212','a full rbxassetid url is kept as it is')
 Cat.FaceImageId=nil
 for _,d in ipairs(specParts(plantAt(1)))do check(d:FindFirstChildOfClass('Decal')==nil,'image cleared: no Decal on the plant')end
 local plainSeed=SeedVisuals.Seed({Id=ID},1,CF(0,0,0),W.workspace,1,nil,'None');check(#decalsOf(plainSeed)==0,'image cleared: no Decal on the seed')
 Cat.FaceImageId=savedFace
 check(faceOk(ballOf(plantAt(1)),false,nil,'Back'),'(image restored)')
end

-- 9. Existing plants unchanged ----------------------------------------------------------------------------------------------------
do
 local Old=W.module('PlantVisualsBase');local OldApproved=W.module('ApprovedPlantArtBase');local OldGrowth=W.module('PlantGrowthBase')
 check(OldApproved.Has(ID)==false and not pcall(Old.Specs,ID,crop()),'(the base commit has no Verity art: the comparison is before / after)')
 for _,id in ipairs({'SunflowerSeed','AppleSeed','MoonflowerSeed','PlasmaPepperSeed','CactusSeed','NoSuchSeed'})do check(Approved.Has(id)==OldApproved.Has(id),'ApprovedPlantArt.Has('..id..') unchanged ('..tostring(OldApproved.Has(id))..')')end
 check(OldGrowth~=PG and Old~=Visuals,'(the base modules are separate copies)')
 local function fingerprint(model)
  local out={}
  for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then
   local p=d.CFrame.Position;local s=d.Size;local c=d.Color or{R=0,G=0,B=0}
   out[#out+1]=table.concat({d.ClassName,d.Name,d.Shape and d.Shape.Name or'-',('%.4f,%.4f,%.4f'):format(s.X,s.Y,s.Z),('%.4f,%.4f,%.4f'):format(p.X,p.Y,p.Z),
    ('%.3f,%.3f,%.3f'):format(c.R,c.G,c.B),d.Material and d.Material.Name or'-',('%.3f'):format(d.Transparency),('%.3f'):format(d.Reflectance or 0),tostring(d.CanQuery),
    tostring(d:GetAttribute('GrowthGroup')),tostring(d:GetAttribute('GrowthRole')),tostring(d:FindFirstChildOfClass('SpecialMesh')~=nil),tostring(d:FindFirstChildOfClass('Decal')~=nil)},'|')
  end end
  return out
 end
 local compared,partsTotal=0,0
 -- R151: the Watermelon's art list now carries `Skipped` (the removed gloss positions), which the base commit's pipeline does not know, so the Clover stands in for it here
 for _,id in ipairs({'CloverSeed','AppleSeed','MoonflowerSeed','PlasmaPepperSeed','SolarStarfruitSeed'})do -- R148: Fire Pepper is x2 now (checked in R148/tests/test_roster_art.luau)
  local d=Catalog[id]
  if d then
   local c={Id='old-'..id,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1.3,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
   for _,variant in ipairs({{'growing',.6,nil},{'ripe',1,4}})do
    local now=d.Seconds*variant[2]
    local okN,a=pcall(function()return variant[3]and Visuals.Build(id,origin,c,4,math.huge)or Visuals.BuildGrowing(id,origin,c,now)end)
    local okO,b=pcall(function()return variant[3]and Old.Build(id,origin,c,4,math.huge)or Old.BuildGrowing(id,origin,c,now)end)
    if check(okN==okO,id..' '..variant[1]..': builds the same way before and after ('..tostring(okN)..'/'..tostring(okO)..')')and okN then
     local fa,fb=fingerprint(a),fingerprint(b);local same=#fa==#fb
     if same then for i=1,#fa do if fa[i]~=fb[i]then same=false;print('  first difference:\n   '..fa[i]..'\n   '..fb[i]);break end end end
     check(same and #fa>0,id..' '..variant[1]..': '..#fa..' parts, identical before and after')
     compared+=1;partsTotal+=#fa;print(('  existing plant %s (%s): %d parts identical before / after'):format(id,variant[1],#fa))
     if variant[1]=='growing'then
      -- and the growth step itself, a later moment
      Visuals.UpdateGrowth(a,c,d.Seconds*.9);Old.UpdateGrowth(b,c,d.Seconds*.9)
      local ga,gb=fingerprint(a),fingerprint(b);local gs=#ga==#gb;if gs then for i=1,#ga do if ga[i]~=gb[i]then gs=false;break end end end
      check(gs,id..' growing: the next growth step is identical too')
     end
    end
   end
  end
 end
 check(compared>=6,'at least three existing plants compared in both modes ('..compared..' comparisons, '..partsTotal..' parts)')
 for _,id in ipairs({'SunflowerSeed','MoonflowerSeed'})do
  local sa,sb=Visuals.Specs(id,crop({SeedId=id})),Old.Specs(id,crop({SeedId=id}))
  check(sa and sb and #sa==#sb,id..': same spec list')
 end
end
-- 10. Everywhere a seed or the fruit is shown: pictures (hotbar / Bag / inventory), Index cards, the pack-opening reveal -----------------------
do
 local F=require('./fixtures');F.packAssets(W)
 local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 local P=W.module('ItemPictures')
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=pg
 local function holderAt(x)local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(x,0);return h end
 local seedTool=F.seed(W,W.workspace,ID,1,'None','Verity Seed');local goldTool=F.seed(W,W.workspace,ID,1,'Gold','Gold Verity Seed')
 local fruitTool=F.fruit(W,W.workspace,ID,1,'None',100,1,'None','Verity Fruit');local plainTool=F.seed(W,W.workspace,'SunflowerSeed',1,'None','Sunflower Seed')
 local h1,h2,h3,h4=holderAt(0),holderAt(70),holderAt(140),holderAt(210)
 P.Show(h1,seedTool,1);P.Show(h2,fruitTool,1);P.Show(h3,goldTool,1);P.Show(h4,plainTool,1)
 for _=1,300 do W.frames(1)end
 local v1,v2,v3,v4=h1:FindFirstChild('ItemViewport'),h2:FindFirstChild('ItemViewport'),h3:FindFirstChild('ItemViewport'),h4:FindFirstChild('ItemViewport')
 check(v1 and v2 and v3 and v4,'the Verity seed, its fruit, a Gold seed and an ordinary seed all get their 3D picture')
 local function balls(v)local out={};for _,d in ipairs(v and v:GetDescendants()or{})do if d:IsA('BasePart')and(d.Name=='Verity seed'or d.Name=='Verity fruit')then out[#out+1]=d end end;return out end
 local b1,b2,b3=balls(v1),balls(v2),balls(v3)
 check(#b1==1 and faceOk(b1[1])and #decalsOf(v1)==1 and colorIs(b1[1].Color,255,255,0),'hotbar / Bag picture of the seed: the yellow ball with ONE face (front: the picture camera looks from -Z)')
 check(#b2==1 and faceOk(b2[1])and #decalsOf(v2)==1,'hotbar / Bag picture of the fruit: the ball with ONE face (front)')
 check(#b3==1 and faceOk(b3[1])and #decalsOf(v3)==1,'picture of a Gold seed: the face stays on top of the coat')
 check(#decalsOf(v4)==0,'an ordinary seed picture has no Decal (unchanged)')
 -- Index cards (CollectionViewport clones the seed library model; the adult card builds the plant)
 local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 local library=R.new('Folder');library.Name='SeedArt';library.Parent=remotes
 local seeds=R.new('Folder');seeds.Name='Seeds';seeds.Parent=library
 local libSeed=SeedVisuals.Seed({Id=ID},1,CF(0,0,0),seeds,1,nil,'None');libSeed.Name=ID
 local CV=W.module('CollectionViewport')
 local function card(adult)
  local view=R.new('ViewportFrame');view.Size=R.UDim2.fromOffset(120,120);view.Parent=gui;view.AbsoluteSize=R.Vector2.new(120,120)
  CV.Attach(view,ID,adult,true);for _=1,60 do W.frames(1)end
  return view
 end
 local seedCard,plantCard=card(false),card(true)
 local sw,pw=seedCard:FindFirstChild('CollectionWorld'),plantCard:FindFirstChild('CollectionWorld')
 local sBall=sw and balls(sw)[1];local pBall=pw and balls(pw)[1]
 check(sBall and faceOk(sBall)and colorIs(sBall.Color,255,255,0),'Index card (seed): the yellow ball with the face')
 check(pBall and faceOk(pBall)and near(pBall.Size.X,22,.2),'Index card (plant): the full ball with ONE face, on the front (the card\'s crop is a preview crop, and its camera looks from -Z)')
 -- a card that is not discovered yet is a silhouette: no picture at all
 local hidden=R.new('ViewportFrame');hidden.Size=R.UDim2.fromOffset(120,120);hidden.Parent=gui;hidden.AbsoluteSize=R.Vector2.new(120,120)
 CV.Attach(hidden,ID,false,false);for _=1,60 do W.frames(1)end
 local hw=hidden:FindFirstChild('CollectionWorld')
 check(hw and #decalsOf(hw)==0,'an undiscovered Index card shows only a dark silhouette (the face is stripped)')
 -- a Tool handle build (ChestService:BuildLooseSeed builds with the carrying part as weld root)
 local handle=R.new('Part');handle.Anchored=false;handle.Parent=W.workspace
 local tool=SeedVisuals.Seed({Id=ID},1,CF(0,0,0),W.workspace,1,handle,'None');local tb;for _,d in ipairs(tool:GetChildren())do if d.Name=='Verity seed'then tb=d end end
 check(tb and faceOk(tb),'held seed Tool: the face is on the ball')
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
