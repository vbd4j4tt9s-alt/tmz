--!nocheck
-- R149 PROPOSAL, SCRATCH ONLY. Not in src/, not required by the game, not installed. Part-based fruit redesigns in the cocoa-pod /
-- pepper style, written in the PlantVisuals spec format ({s shape, f feature, r role, m material, k rgb, z size, c CFrame components,
-- g fruit group, t transparency, decor = gloss hidden on Gold/Diamond, rf = authored reflectance}) so dump_fruit_models.luau can
-- build them with the REAL PlantVisuals.Part and an art module could later take them verbatim (translated to each fruit centre).
-- Each fruit is authored around its own centre (0,0,0), front = -Z, at the size today's fruit has in Visuals.Specs, so FruitCenters,
-- FruitRadii, sockets and harvest reach stay as they are.
-- The style, taken from FlutedCocoa / SmoothFirePepper / Plasma Pepper:
--  * silhouette from 1-3 overlapping ellipsoids instead of a Block (shape fidelity, smooth shading);
--  * ribs / flutes / lobes as radial ellipsoids (the cocoa's 10 flutes, the pumpkin's lobes) or meridian bands (melon stripes);
--  * a colour gradient as stacked shells of shifted tone (dark shoulder -> body -> light base), the parts version of the meshes'
--    vertex-colour gradients;
--  * a calyx / sepals / stem like the pepper's three pointed sepals and curled stalk;
--  * one Neon gloss patch (decor, like Verity's gloss) and, for Lava, Neon seams in the grooves (Plasma Pepper's energy seams).
-- Two Phase-2 variants (RibbedMelon149 / LobedPumpkin149) use meshes from gen_meshes.py through the existing s='ApprovedMesh' path.
local V3,CF,ANG=Vector3.new,CFrame.new,CFrame.Angles
local M={}
local function comps(c)return {c:GetComponents()}end
local function spec(shape,name,mat,rgb,size,frame,extra)
 local t={s=shape,f=name,r='Fruit',m=mat or'SmoothPlastic',k=rgb,z=size,c=comps(frame),g=1,t=0}
 for key,v in pairs(extra or{})do t[key]=v end
 return t
end
local function ball(name,rgb,size,frame,extra)return spec('Ball',name,'SmoothPlastic',rgb,size,frame,extra)end
-- Frame on an ellipsoid (semi-axes a,b,c, centre o) in direction dir, local Z = outward normal; inset sinks it along the normal.
local function surface(o,a,b,c,dir,inset)
 local d=dir.Unit;local s=1/math.sqrt((d.X/a)^2+(d.Y/b)^2+(d.Z/c)^2);local p=d*s
 local n=V3(p.X/(a*a),p.Y/(b*b),p.Z/(c*c)).Unit
 local up=math.abs(n.Y)>.95 and V3(1,0,0)or V3(0,1,0);local x=up:Cross(n).Unit;local y=n:Cross(x)
 return CFrame.fromMatrix(o+p-n*(inset or 0),x,y,n)
end
-- Cylinder spec (axis = local Y) from a to b.
local function stick(name,rgb,dia,a,b,mat)
 local d=b-a;local y=d.Unit;local x=y:Cross(V3(0,0,1));if x.Magnitude<.01 then x=y:Cross(V3(1,0,0))end;x=x.Unit
 return spec('Cylinder',name,mat or'SmoothPlastic',rgb,{dia,d.Magnitude,dia},CFrame.fromMatrix((a+b)*.5,x,y,x:Cross(y)))
end
-- Outward frame for a radial rib / lobe at angle a around Y (local Z points away from the axis, local Y up).
local function radial(angle,r,y,tilt)
 local out=V3(math.cos(angle),0,math.sin(angle));local x=V3(math.sin(angle),0,-math.cos(angle))
 return CFrame.fromMatrix(out*r+V3(0,y or 0,0),x,V3(0,1,0),out)*ANG(tilt or 0,0,0)
end
local function gloss(o,a,b,c,dir,w,h,alpha)
 return ball('Fruit gloss',{246,255,236},{w,h,.06},surface(o,a,b,c,dir,.015),{m='Neon',t=alpha or .55,decor=true})
end
local GLOSS=V3(-.42,.55,-.72) -- upper front-left, where the preview sun and Roblox's default sky light it

-- 1. Watermelon (Forest Common): Block rind + 18 Block stripes -> ellipsoid rind with 7 meridian stripe bands that meet at both ends.
function M.Watermelon()
 local A,B=1.85,1.48;local out={ball('Melon rind',{108,180,76},{A*2,B*2,B*2},CF())}
 for i=0,6 do -- each band is a thin ellipsoid 4.5% proud of the rind: two dark stripes per band, converging at the ends
  local a=i*math.pi/7+.10*math.sin(i*2.3)
  table.insert(out,ball('Melon stripe band',i%2==0 and{36,98,48}or{42,106,52},{A*2*1.012,B*2*1.045,.92},ANG(a,0,0)))
 end
 local base=V3(1.70,.55,0);local tip=V3(2.12,1.05,.05)
 table.insert(out,stick('Melon stem',{86,128,58},.20,base,tip))
 table.insert(out,stick('Melon tendril',{104,150,70},.09,tip,tip+V3(.32,.05,-.22)))
 table.insert(out,ball('Melon leaf',{80,150,62},{.95,.07,.55},CF(1.95,1.02,.42)*ANG(.25,.5,-.35)))
 table.insert(out,gloss(V3(),A,B,B,GLOSS,1.25,.62))
 return out
end
-- 2. Snow Melon (Snow Uncommon): the same build in frost colours plus a translucent snow cap (a white top-down gradient).
function M.SnowMelon()
 local out=M.Watermelon()
 out[1].k={190,232,234};for i=2,8 do out[i].k=i%2==0 and{58,128,158}or{70,140,170}end
 out[9].k={70,128,138};out[10].k={120,190,200};out[11].k={120,186,196}
 table.insert(out,10,ball('Snow cap',{250,254,255},{3.3,1.5,2.85},CF(0,.82,0),{t=.45}))
 return out
end
-- 3. Apple (Forest Rare): a red cube -> wide body + two shoulder lobes (the apple's heart-shaped top), a lighter base tone
--    (gradient), dimple, stem, leaf, gloss + glint.
function M.Apple()
 return {
  ball('Apple body',{206,36,46},{2.3,2.05,2.3},CF(0,-.05,0)),
  ball('Apple shoulder',{192,30,42},{1.35,1.15,1.6},CF(-.42,.38,0)),
  ball('Apple shoulder',{198,33,44},{1.35,1.15,1.6},CF(.42,.38,0)),
  ball('Apple base tone',{226,72,52},{1.3,.70,1.3},CF(0,-.70,0)),
  ball('Apple dimple',{110,22,28},{.62,.20,.62},CF(0,.90,0)),
  stick('Apple stem',{104,74,44},.13,V3(0,.80,0),V3(.10,1.40,.02)),
  ball('Apple leaf',{78,152,60},{.88,.07,.40},CF(.46,1.24,0)*ANG(0,.2,.32)),
  gloss(V3(0,-.05,0),1.15,1.025,1.15,GLOSS,.70,.42,.55),
 }
end
-- 4. Ember Pumpkin (Lava Rare): 6 tall lobes -> 10 flatter ribs (cocoa-flute style) around a dark heart, Neon ember light in all
--    10 grooves, curled stem, leaf, gloss.
function M.EmberPumpkin()
 local out={ball('Pumpkin heart',{132,46,14},{3.25,2.35,3.25},CF())}
 for i=0,9 do
  local a=i*math.pi/5
  table.insert(out,ball('Pumpkin rib',i%2==0 and{232,108,28}or{220,92,22},{1.30,2.62,1.60},radial(a,1.20)))
 end
 for i=0,9 do
  local a=i*math.pi/5+math.pi/10
  table.insert(out,ball('Ember groove',{255,150,40},{.13,1.85,.13},radial(a,1.66),{m='Neon'}))
 end
 table.insert(out,stick('Pumpkin stem',{88,74,46},.42,V3(0,.95,0),V3(.10,1.75,0)))
 table.insert(out,stick('Pumpkin stem curl',{98,84,52},.30,V3(.10,1.72,0),V3(.52,1.95,-.08)))
 table.insert(out,ball('Pumpkin leaf',{96,138,62},{1.15,.08,.70},CF(-.70,1.33,.25)*ANG(.15,.4,.22)))
 table.insert(out,gloss(V3(),2.0,1.31,2.0,V3(-.30,.45,-.85),.52,.95,.6))
 return out
end
-- 5. Ash Tomato (Lava Rare): a Block -> round body with 5 shallow lobes, Neon ember seams in the grooves, a 5-point star calyx,
--    a translucent ash bloom on top, gloss.
function M.AshTomato()
 local out={ball('Tomato body',{170,42,38},{1.62,1.16,1.62},CF())}
 for i=0,4 do table.insert(out,ball('Tomato lobe',i%2==0 and{186,54,44}or{176,46,40},{1.0,1.20,1.0},radial(i*math.pi*2/5+.3,.50)))end
 for i=0,4 do table.insert(out,ball('Ember seam',{255,128,40},{.07,.95,.07},radial(i*math.pi*2/5+.3+math.pi/5,.80),{m='Neon'}))end
 for i=0,4 do
  table.insert(out,ball('Tomato sepal',{58,100,54},{.20,.06,.78},CF(0,.66,0)*ANG(0,i*math.pi*2/5,0)*CF(0,0,.30)*ANG(.32,0,0)))
 end
 table.insert(out,stick('Tomato stem',{70,108,58},.12,V3(0,.60,0),V3(0,.98,.04)))
 table.insert(out,ball('Ash bloom',{150,142,132},{1.36,.42,1.36},CF(0,.48,0),{t=.45}))
 table.insert(out,gloss(V3(),.95,.68,.95,GLOSS,.50,.30,.5))
 return out
end
-- 6. Prickly Pear (Desert Uncommon): Block + Ball shoulder -> barrel ellipsoid with a dark top / magenta body / coral base gradient,
--    a sunken navel with 5 crown scales, 6 cream areoles, gloss.
function M.PricklyPear()
 local out={
  ball('Pear body',{204,50,110},{2.3,2.9,2.3},CF()),
  ball('Pear crown shade',{170,34,90},{1.70,1.00,1.70},CF(0,1.0,0)),
  ball('Pear coral base',{232,96,96},{1.70,1.00,1.70},CF(0,-.95,0)),
  ball('Pear navel',{104,28,62},{.92,.30,.92},CF(0,1.46,0)),
 }
 for i=0,4 do table.insert(out,ball('Pear crown scale',{214,206,142},{.13,.44,.13},CF(0,1.48,0)*ANG(0,i*math.pi*2/5,0)*CF(0,.10,.38)*ANG(.55,0,0)))end
 local dirs={V3(-.55,.35,-.78),V3(.25,.45,-.86),V3(-.10,-.15,-1),V3(.62,-.05,-.78),V3(-.70,-.35,-.62),V3(.30,-.50,-.82)}
 for _,d in ipairs(dirs)do table.insert(out,ball('Pear areole',{246,228,162},{.22,.22,.09},surface(V3(),1.15,1.45,1.15,d,.02)))end
 table.insert(out,gloss(V3(),1.15,1.45,1.15,GLOSS,.70,.95,.55))
 return out
end
-- 7. Blueberry (Forest Uncommon): 3 berries with Block calyx -> berries with a frosty bloom shell (top-lit gradient), a dark crown,
--    a stalk + pedicels, two leaves and a glint each.
function M.Blueberry(palette)
 local p=palette or{Body={62,76,168},Bloom={152,170,224},Crown={30,36,90},Stalk={70,110,60},Leaf={80,150,66}}
 local berries={{V3(-.38,.02,0),.80},{V3(.40,-.04,-.06),.76},{V3(.02,-.52,-.18),.74}}
 local out={}
 local top=V3(.05,1.02,.12);table.insert(out,stick('Berry stalk',p.Stalk,.09,V3(.05,.62,.10),top))
 for _,b in ipairs(berries)do
  local c,d=b[1],b[2]
  table.insert(out,ball('Berry',p.Body,{d,d*.94,d},CF(c)))
  table.insert(out,ball('Berry bloom',p.Bloom,{d*1.02,d*.62,d*1.02},CF(c+V3(0,d*.17,0)),{t=.5}))
  table.insert(out,ball('Berry crown',p.Crown,{d*.40,d*.11,d*.40},CF(c+V3(0,d*.44,0))))
  table.insert(out,stick('Berry pedicel',p.Stalk,.06,c+V3(0,d*.45,0),V3(.05,.64,.10)))
  table.insert(out,ball('Berry glint',{250,252,255},{d*.26,d*.16,.04},surface(c,d/2,d*.47,d/2,V3(-.45,.5,-.74),.01),{m='Neon',t=.25,decor=true}))
 end
 table.insert(out,ball('Berry leaf',p.Leaf,{.74,.05,.34},CF(top+V3(-.30,-.04,0))*ANG(0,.3,-.30)))
 table.insert(out,ball('Berry leaf',p.Leaf,{.66,.05,.30},CF(top+V3(.28,-.06,.05))*ANG(0,-.4,.35)))
 return out
end
function M.Iceberry()return M.Blueberry({Body={118,196,232},Bloom={236,250,255},Crown={60,120,160},Stalk={70,120,110},Leaf={120,186,196}})end
-- 8. Amethyst Grape (Crystal Rare): 9 'Crystal' grapes = 163 parts -> a 3/3/2/1 bunch of glossy grapes, dark-to-light row gradient,
--    4 facet glints, stem with a small crystal shard. 19 parts.
function M.AmethystGrape()
 local rows={{.50,3,.42,0},{.06,3,.42,math.pi/3},{-.38,2,.28,.4},{-.78,1,0,0}}
 local tones={{112,70,172},{132,88,192},{156,112,212},{178,134,228}}
 local out={}
 for r,row in ipairs(rows)do for j=0,row[2]-1 do
  local a=row[4]+j*math.pi*2/row[2];local c=V3(math.cos(a)*row[3],row[1],math.sin(a)*row[3])
  table.insert(out,ball('Amethyst grape',tones[r],{.76,.84,.76},CF(c),{rf=.15}))
  if c.Z<-.1 or r==4 then table.insert(out,ball('Grape facet glint',{246,236,255},{.13,.22,.04},surface(c,.38,.42,.38,V3(-.4,.45,-.8),.01),{m='Neon',t=.15,decor=true}))end
 end end
 table.insert(out,stick('Grape stem',{96,70,120},.12,V3(0,.80,0),V3(.08,1.30,0)))
 table.insert(out,spec('Gem','Amethyst shard','SmoothPlastic',{200,170,255},{.34,.62,.16},CF(.30,1.20,-.02)*ANG(0,0,-.5)))
 return out
end
-- 9. Lantern Fern (Jungle Rare): Neon Block lantern + 16 trim parts -> a physalis husk: 5 papery ribs (fluted like the cocoa pod)
--    around a Neon core that glows through the grooves, green calyx, pointed tip. 8 parts.
function M.LanternFern()
 local out={ball('Lantern core',{255,206,96},{1.20,1.24,1.20},CF(0,.06,0),{m='Neon'})}
 for i=0,4 do -- ribs lean in at the bottom: widest near the top, closing to a point, with glowing gaps between them
  table.insert(out,ball('Lantern husk rib',i%2==0 and{230,128,36}or{240,150,50},{.50,1.66,.56},radial(i*math.pi*2/5,.38,.0,.26)))
 end
 table.insert(out,ball('Lantern calyx',{98,140,68},{.62,.28,.62},CF(0,.80,0)))
 table.insert(out,ball('Lantern tip',{206,110,32},{.18,.40,.18},CF(0,-.84,0)))
 return out
end
-- Phase 2 (mesh): the same melon / pumpkin as ONE baked mesh each (gen_meshes.py), keeping the stem / leaf / gloss parts.
function M.WatermelonMesh()
 local out={spec('ApprovedMesh','Ribbed melon mesh','SmoothPlastic',{255,255,255},{2.96,3.70,2.96},ANG(0,0,-math.pi/2),{mesh='RibbedMelon149'})}
 local parts=M.Watermelon();for i=9,#parts do table.insert(out,parts[i])end
 return out
end
function M.EmberPumpkinMesh()
 local out={spec('ApprovedMesh','Lobed pumpkin mesh','SmoothPlastic',{255,255,255},{4.0,2.62,4.0},CF(),{mesh='LobedPumpkin149'})}
 local parts=M.EmberPumpkin();for i=22,#parts do table.insert(out,parts[i])end
 return out
end
-- Which seed each prototype replaces, the body specs that mark today's fruit centre on the plant (for the on-plant preview),
-- and the per-fruit part budget. Order = the recommended order of work.
M.List={
 {Key='Watermelon',Id='SunflowerSeed',Anchor={'Rind'},Budget=12},
 {Key='Apple',Id='AppleSeed',Anchor={'Canopy apple'},Budget=8},
 {Key='EmberPumpkin',Id='EmberBloomSeed',Anchor={'Pumpkin lobe'},Budget=25},
 {Key='AshTomato',Id='AshRoseSeed',Anchor={'Squared ash tomato'},Budget=19},
 {Key='PricklyPear',Id='CactusSeed',Anchor={'Cactus pear'},Budget=16},
 {Key='Blueberry',Id='BluebellSeed',Anchor={'Berry'},Budget=18},
 {Key='AmethystGrape',Id='AmethystSeed',Anchor={'Harvest form'},Budget=19},
 {Key='LanternFern',Id='LanternFernSeed',Anchor={'Amber lantern shell'},Budget=8},
 {Key='SnowMelon',Id='SnowdropSeed',Anchor={'Rind'},Budget=13},
 {Key='Iceberry',Id='IceberrySeed',Anchor={'Berry'},Budget=18},
}
M.Mesh={
 {Key='WatermelonMesh',Id='SunflowerSeed',Anchor={'Rind'},Budget=5},
 {Key='EmberPumpkinMesh',Id='EmberBloomSeed',Anchor={'Pumpkin lobe'},Budget=5},
}
return M
