--!nocheck
-- R151 (owner: "verity fruit also has 2 faces"): the Verity fruit has ONE face, in every place it is drawn, on the side the viewer sees; the Verity PACK keeps its front and back
-- face (the owner's R149 request). The real VerityPlantArt, PlantVisuals, HarvestPresentation, SeedPackVisuals, CollectionViewport, ItemPictures and PlantGrowthFx on the mock.
--  1. what "front" is in each place (the cameras and the hand): ItemPictures looks at a fruit / seed from (.45, .35, -1) and (.35, .22, -1): from -Z; the Index card's camera
--     from (sin a, .22, -cos a); the held fruit's grip is on its +Z surface (HarvestGeometry.Grip), so its -Z faces forward, away from the hand; seeds' marks face -Z
--     (SeedSignatures). So everything detached from a plant (the fruit as an item: hotbar / Bag / Sell pictures, held; the seed; the Index card's preview crop) has its face on
--     the FRONT (-Z). The PLANTED fruit is seen from the path: the plant's own surface details lie on +Z (PlantVisuals surfacePoint) and the garden's front is +Z (the pad's
--     entrance side), so its face is on the BACK (+Z), which on a plot turned to any direction still looks at the plot's front.
--  2. every build (plant at every growth stage, regrow, the far proxy, the server's regrowing fruit, a harvested crop's fruit, the flight's copy, the item, the seed, the Index
--     card, Gold / Diamond coats) has exactly one Decal, white, the exact picture, on the right side; hidden with the ball when it is picked; none when the picture id is cleared;
--  3. no gloss / glint part in the fruit, the seed, or any of their coats;
--  4. the Verity pack still has the picture on its Front AND Back (source check of VerityPackArt: the pack is a different object);
--  5. a plot turned by 90 / 180 degrees: the face of the planted ball looks along the plot's +Z in the world.
local C=require('./growth_common');local W,R,V3,CF=C.W,C.R,C.V3,C.CF;local check,near=C.check,C.near
local Catalog,Rules,Visuals=C.Catalog,C.Rules,C.Visuals
local Cat=W.module('VerityCatalog');local Art=W.module('VerityPlantArt');local Harvest=W.module('HarvestPresentation');local SeedVisuals=W.module('SeedPackVisuals')
local FxM=W.module('PlantGrowthFx')
local Enum=R.Enum
local ID='VeritySeed';local def=Catalog[ID];local IMAGE=Cat.FaceImageId
local function realCrop(extra)
 local c={Id='verity-garden-1',SeedId=ID,PlantedAt=0,MatureAt=def.Seconds,ReadyAt=def.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
 for k,v in pairs(extra or{})do c[k]=v end;return c
end
local function balls(model)local out={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')and(d.Name=='Verity fruit'or d.Name=='Verity seed')then out[#out+1]=d end end;return out end
local function decals(inst)local out={};for _,d in ipairs(inst:GetDescendants())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
local function oneFace(model,side,label,hidden)
 local ds=decals(model);local b=balls(model)
 local ok=#ds==1 and #b==1 and ds[1].Parent==b[1]and ds[1].Face==Enum.NormalId[side]and ds[1].Texture==IMAGE and ds[1].Color3.R==1 and ds[1].Color3.G==1 and ds[1].Color3.B==1
  and ds[1].Transparency==(hidden and 1 or 0)
 return check(ok,label..': exactly ONE face, on the '..side..' ('..#ds..' Decal(s)'..(ds[1]and(', '..ds[1].Face.Name)or'')..')')
end
local function noShine(model,label)
 local bad={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then local n=d.Name:lower();if n:find('gloss')or n:find('glint')or n:find('shine')or n:find('sheen')then bad[#bad+1]=d.Name end end end
 return check(#bad==0,label..': no gloss / glint / shine part ('..table.concat(bad,', ')..')')
end
local origin=CF(10,0,5)
-- 1. which side -------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 check(Art.FaceSide(nil)==Enum.NormalId.Front and Art.FaceSide({_DetachedHarvest=true,Id='x'})==Enum.NormalId.Front and Art.FaceSide({Id='preview'})==Enum.NormalId.Front
  and Art.FaceSide({Id='preview-VeritySeed'})==Enum.NormalId.Front and Art.FaceSide({})==Enum.NormalId.Front,'FaceSide: front for no crop, a detached harvest and a preview crop')
 check(Art.FaceSide(realCrop())==Enum.NormalId.Back and Art.FaceSide({Id='c1',_VisualHarvest={Index=1,Scale=1}})==Enum.NormalId.Back,'FaceSide: back for a planted crop (and the fruit of one: a harvested crop\'s fruit model, the flight\'s copy)')
 -- the cameras and the grip, from the sources (a convention test: if one of them turns, the face must follow)
 local pictures=W.B.ItemPictures;local geometry=W.B.HarvestGeometry;local views=W.B.CollectionViewport;local surface=W.B.PlantVisuals
 check(pictures:find('Fruit=Vector3.new(.45,.35,-1)',1,true)~=nil and pictures:find('Seed=Vector3.new(.35,.22,-1)',1,true)~=nil,'the hotbar / Bag / Index pictures look at a fruit and a seed from -Z')
 check(views:find('Vector3.new(math.sin(angle),.22,-math.cos(angle))',1,true)~=nil,'the Index card\'s camera looks from -Z')
 check(geometry:find('Vector3.new(0,-size.Y*.08,size.Z*.43)',1,true)~=nil,'the hand grips a fruit on its +Z surface: its -Z side points away from the hand')
 check(surface:find('(depth-.018)*z.Z*(back and -1 or 1)',1,true)~=nil,'the plant\'s own surface details lie on +Z (the plot\'s front, where the path is)')
 check(W.B.VerityPlantArt:find('function A.AddFace(part,image,side)',1,true)~=nil and W.B.VerityPlantArt:find('VerityBallFaceBack',1,true)==nil,'AddFace makes one Decal (the Back decal of R148 is gone)')
end
-- 2. every build ------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 -- the planted fruit: every growth stage and regrow, the far proxy, the server's regrowing fruit, the fruit of a harvested crop, the flight's copy
 for _,f in ipairs({0,.1,.33,.5,.66,1})do
  local m=Visuals.BuildGrowing(ID,origin,realCrop(),f*def.Seconds);oneFace(m,'Back',('planted, %d%% grown'):format(f*100));noShine(m,('planted, %d%%'):format(f*100))
 end
 do
  local c=realCrop();Rules.StartFruitRegrowth(c,def,1,def.Seconds)
  for _,f in ipairs({0,.5,1})do local m=Visuals.BuildGrowing(ID,origin,c,def.Seconds+f*def.RegrowSeconds);oneFace(m,'Back',('regrowing, %d%%'):format(f*100))end
 end
 do
  local m=R.new('Model');m.Parent=W.workspace;Visuals.GrowingSupports(ID,origin,realCrop(),1,m,.5*def.Seconds);oneFace(m,'Back','the far proxy of a growing plant')
  local f=R.new('Model');f.Parent=W.workspace;local c2=realCrop();Rules.StartFruitRegrowth(c2,def,1,def.Seconds);Visuals.GrowingFruitSupports(ID,origin,c2,f,def.Seconds+.5*def.RegrowSeconds);oneFace(f,'Back','the server\'s regrowing fruit')
  local p=R.new('Folder');p.Parent=W.workspace;Visuals.FruitProxy(p,ID,realCrop(),1,origin);oneFace(p,'Back','the harvest prompt\'s proxy ball')
  local sel=Visuals.BuildSelectedFruit(ID,origin,realCrop(),{[1]=true},math.huge);oneFace(sel,'Back','the fruit of a planted crop (BuildSelectedFruit: what the client builds for a fruit that regrows)')
  local fx=FxM.new({Parent=W.workspace});local copy=fx:Copy(realCrop(),1,origin,nil)
  if check(copy~=nil,'the flight\'s detached copy of a Verity fruit builds')then oneFace(copy,'Back','the flight\'s detached copy (it keeps the side the plant\'s ball had)');noShine(copy,'the flight\'s copy')end
  fx:Destroy()
 end
 -- a picked ball hides its face with it
 do
  local c=realCrop();local m=Visuals.BuildGrowing(ID,origin,c,def.Seconds);c.PickedMask=1;Visuals.UpdateGrowth(m,c,def.Seconds+5);oneFace(m,'Back','picked',true)
 end
 -- the fruit as an item: the hotbar / Bag / Sell pictures and the hand
 for _,coat in ipairs({'None','Gold','Diamond'})do
  local item=Harvest.Build({SeedId=ID,Mutation=coat,Weather='None',VisualCrop={SourceCropId='sold-1',FruitIndex=1,HarvestCycle=0}})
  oneFace(item,'Front','the fruit as an item ('..coat..')');noShine(item,'the fruit as an item ('..coat..')')
  local held=Harvest.Build({SeedId=ID,Mutation=coat,Weather='None',FruitScale=2,VisualCrop={SourceCropId='sold-1',FruitIndex=1,HarvestCycle=0}},{WorldSize=true})
  oneFace(held,'Front','the held fruit ('..coat..')')
 end
 -- the Index card's build (a preview crop) and the plain preview build
 local preview=Visuals.Build(ID,CF(),{Id='preview',SeedId=ID,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,PlantedAt=0,MatureAt=1,ReadyAt=1},4,math.huge)
 oneFace(preview,'Front','the Index card\'s plant (a preview crop)')
 oneFace(Visuals.Build(ID,CF(),nil,4,math.huge),'Front','the default preview build (no crop)')
 -- the seed and its coats
 for _,coat in ipairs({'None','Gold','Diamond'})do
  local seed=SeedVisuals.Seed({Id=ID},1,CF(3,2,1),R.new('Model'),1,nil,coat);oneFace(seed,'Front','the seed ('..coat..')');noShine(seed,'the seed ('..coat..')')
  local n=0;for _,d in ipairs(seed:GetChildren())do if d:IsA('BasePart')then n+=1 end end
  check(n==2,'the seed ('..coat..') is the root and the ball ('..n..' parts)')
 end
 -- the picture id cleared: no Decal anywhere
 local saved=Cat.FaceImageId;Cat.FaceImageId=nil
 check(#decals(Visuals.BuildGrowing(ID,origin,realCrop(),def.Seconds))==0 and #decals(SeedVisuals.Seed({Id=ID},1,CF(),R.new('Model'),1,nil,'None'))==0,'no picture id: no Decal on the plant or the seed')
 Cat.FaceImageId=saved
end
-- 3. a plot turned in any direction: the planted face looks along the plot's +Z, the item's along its own -Z ------------------------------------------------------------------------
do
 for _,deg in ipairs({0,90,180,270})do
  local plot=CF(40,0,-12)*R.CFrame.Angles(0,math.rad(deg),0)
  local m=Visuals.BuildGrowing(ID,plot,realCrop(),def.Seconds);local ball=balls(m)[1];local d=decals(m)[1]
  local normal=ball.CFrame:VectorToWorldSpace(d.Face==Enum.NormalId.Back and V3(0,0,1)or d.Face==Enum.NormalId.Front and V3(0,0,-1)or V3(0,0,0))
  local front=plot:VectorToWorldSpace(V3(0,0,1))
  check((normal-front).Magnitude<1e-6,('plot turned %d degrees: the planted face looks along the plot\'s +Z (the path side)'):format(deg))
 end
 local item=Harvest.Build({SeedId=ID,Mutation='None',Weather='None',VisualCrop={SourceCropId='sold-1',FruitIndex=1,HarvestCycle=0}})
 local ball=balls(item)[1];local d=decals(item)[1]
 check((ball.CFrame:VectorToWorldSpace(V3(0,0,-1))-V3(0,0,-1)).Magnitude<1e-6 and d.Face==Enum.NormalId.Front,'the item\'s face looks along -Z (toward the picture camera)')
end
-- 4. the pack keeps both faces ------------------------------------------------------------------------------------------------------------------------------------------------
do
 local pack=W.B.VerityPackArt
 check(pack:find('for _,side in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do',1,true)~=nil and pack:find("d.Name='VerityPicture'",1,true)~=nil,'the Verity PACK still has its picture on the Front and the Back (the owner\'s R149 request)')
end
C.done('verity face')
