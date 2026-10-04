--!nocheck
-- R149: the SHIPPED part-based fruit designs (Phase 1 of docs/proposals/R149/fruit_models.md), in the PlantVisuals spec format
-- ({s shape, f feature, r role, m material, k rgb, z size, c CFrame components, g fruit group, t transparency, decor = gloss hidden on
-- Gold / Diamond, rf = authored reflectance}). Derived from the owner-approved prototypes (docs/proposals/R149/preview/FruitModels149.luau)
-- with the changes the real art pipeline needs:
--  * only the seven redesigned fruit: Watermelon, Snow Melon, Apple, Elderbloom's elder apple, Ember Pumpkin, Prickly Pear, Blueberry /
--    Iceberry (owner: Lantern Fern, Amethyst Grape and the Ash Tomato's look stay as they are);
--  * names avoid 'crown' / 'leaf' where the part is not a leaf (PlantSurfaceStyle tints anything called crown / leaf / canopy green);
--  * every Ball / Block carries tx='smooth': PlantVisuals.Part draws no surface marks for it and PlantSurfaceStyle's "first four grain /
--    first six speckle" rules skip it, so a fruit is exactly the parts listed here (the budgets in the proposal);
--  * the stems are NOT in PlantVisuals' connector list (Fruit stem, Berry pedicel, Apple hanging stem ...), so they show in the hotbar /
--    Bag / Index picture; the old connector specs that reach the vine stay on the plant (port_fruit_models.luau decides which);
--  * the Elder apple is the Apple build in jade / gold with its Neon rune, a fifth of the size.
-- Each design is authored around the fruit's own centre (0,0,0), front = -Z, in final studs (the size the old fruit had in the plant), so
-- port_fruit_models.luau can drop it on the old body's centre; `body` names the part whose bottom rests on the ground / pad (BodyHalf is
-- its half height) and `fit(k)` scales a design uniformly.
local V3,CF,ANG=Vector3.new,CFrame.new,CFrame.Angles
local M={}
local function comps(c)return {c:GetComponents()}end
local function spec(shape,name,mat,rgb,size,frame,extra)
 local t={s=shape,f=name,r='Fruit',m=mat or'SmoothPlastic',k=rgb,z=size,c=comps(frame),g=1,t=0}
 if shape=='Ball'or shape=='Block'then t.tx='smooth'end
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

-- 1. Watermelon (Forest Common): ellipsoid rind, 7 meridian stripe bands (a thin ellipsoid 4.5% proud of the rind: two dark stripes per
--    band, meeting at both ends), stem + tendril, leaf, gloss. 12 parts. Lies on the ground, long axis X, stem end +X.
function M.Watermelon()
 local A,B=1.85,1.48;local out={ball('Melon rind',{108,180,76},{A*2,B*2,B*2},CF())}
 for i=0,6 do
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
-- 2. Snow Melon (Snow Uncommon): the same build in frost colours plus a translucent snow cap (a white top-down gradient). 13 parts.
function M.SnowMelon()
 local out=M.Watermelon()
 out[1].k={190,232,234};for i=2,8 do out[i].k=i%2==0 and{58,128,158}or{70,140,170}end
 out[9].k={70,128,138};out[10].k={120,190,200};out[11].k={120,186,196}
 for _,s in ipairs(out)do if s.f:find('Melon',1,true)then s.f=s.f:gsub('Melon','Snow melon')end end
 table.insert(out,10,ball('Snow cap',{250,254,255},{3.3,1.5,2.85},CF(0,.82,0),{t=.45}))
 return out
end
-- 3. Apple (Forest Rare): wide body + two shoulder lobes (the apple's heart-shaped top), a lighter base tone (gradient), dimple, stem,
--    leaf, gloss. 8 parts.
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
-- 4. Elderbloom's elder apple (Forest Mythic): the Apple build in jade with a gold base tone, a fifth of the size, keeping the Neon rune
--    (a bar and a cross on the front). 10 parts.
function M.ElderApple()
 local k=.45;local out={}
 for _,s in ipairs(M.Apple())do
  s.z={s.z[1]*k,s.z[2]*k,s.z[3]*k};s.c[1]*=k;s.c[2]*=k;s.c[3]*=k
  if s.f=='Fruit gloss'then s.z[3]=.03 end
  table.insert(out,s)
 end
 local pal={['Apple body']={112,164,92},['Apple shoulder']={140,184,98},['Apple base tone']={214,190,104},['Apple dimple']={58,92,48},['Apple stem']={107,79,54},['Apple leaf']={128,168,109}}
 for _,s in ipairs(out)do
  local p=pal[s.f];if p then s.k=p end
  s.f=s.f:gsub('Apple','Elder apple')
  if s.f=='Elder apple stem'then s.m='Wood'end
 end
 out[3].k={150,192,104}
 -- the rune: a bar and a cross, Neon, proud of the front of the body (the old Blocks sat just inside the new ellipsoid)
 local a,b,c=1.15*k,1.025*k,1.15*k;local o=V3(0,-.05*k,0)
 table.insert(out,spec('Block','Ancient apple rune','Neon',{255,225,138},{.08,.27,.03},surface(o,a,b,c,V3(0,-.03,-1),.006)))
 table.insert(out,spec('Block','Ancient apple rune cross','Neon',{255,225,138},{.21,.06,.03},surface(o,a,b,c,V3(0,.10,-1),.006)))
 return out
end
-- 5. Ember Pumpkin (Lava Rare): 10 flatter ribs (cocoa-flute style) around a dark heart, Neon ember light in all 10 grooves, a curled
--    stem, leaf, gloss. 25 parts.
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
-- 6. Prickly Pear (Desert Uncommon): barrel ellipsoid with a dark top / magenta body / coral base gradient, a sunken navel with 5
--    scales, 6 cream areoles, gloss. 16 parts. Final studs (the art module halves it: the plant grows the fruit x2 around its socket).
function M.PricklyPear()
 local out={
  ball('Pear body',{204,50,110},{2.3,2.9,2.3},CF()),
  ball('Pear shoulder shade',{170,34,90},{1.70,1.00,1.70},CF(0,1.0,0)),
  ball('Pear coral base',{232,96,96},{1.70,1.00,1.70},CF(0,-.95,0)),
  ball('Pear navel',{104,28,62},{.92,.30,.92},CF(0,1.46,0)),
 }
 for i=0,4 do table.insert(out,ball('Pear navel scale',{214,206,142},{.13,.44,.13},CF(0,1.48,0)*ANG(0,i*math.pi*2/5,0)*CF(0,.10,.38)*ANG(.55,0,0)))end
 local dirs={V3(-.55,.35,-.78),V3(.25,.45,-.86),V3(-.10,-.15,-1),V3(.62,-.05,-.78),V3(-.70,-.35,-.62),V3(.30,-.50,-.82)}
 for _,d in ipairs(dirs)do table.insert(out,ball('Pear areole',{246,228,162},{.22,.22,.09},surface(V3(),1.15,1.45,1.15,d,.02)))end
 table.insert(out,gloss(V3(),1.15,1.45,1.15,GLOSS,.70,.95,.55))
 return out
end
-- 7. Blueberry (Forest Uncommon): 3 berries with a frosty bloom shell (top-lit gradient), a dark cap, a stalk + stalklets (named
--    'Berry stem' / 'Berry stalklet': 'Berry pedicel' is a connector and would vanish from the hotbar picture), two leaves and a glint
--    each. 18 parts. Iceberry (Snow Rare) is the same build in ice colours.
local BLUE={Body={62,76,168},Bloom={152,170,224},Crown={30,36,90},Stalk={70,110,60},Leaf={80,150,66}}
local ICE={Body={118,196,232},Bloom={236,250,255},Crown={60,120,160},Stalk={70,120,110},Leaf={120,186,196}}
local function berries(p)
 local list={{V3(-.38,.02,0),.80},{V3(.40,-.04,-.06),.76},{V3(.02,-.52,-.18),.74}}
 local out={}
 local top=V3(.05,1.02,.12);table.insert(out,stick('Berry stem',p.Stalk,.09,V3(.05,.62,.10),top))
 for _,b in ipairs(list)do
  local c,d=b[1],b[2]
  table.insert(out,ball('Berry',p.Body,{d,d*.94,d},CF(c)))
  table.insert(out,ball('Berry bloom',p.Bloom,{d*1.02,d*.62,d*1.02},CF(c+V3(0,d*.17,0)),{t=.5}))
  table.insert(out,ball('Berry cap',p.Crown,{d*.40,d*.11,d*.40},CF(c+V3(0,d*.44,0))))
  table.insert(out,stick('Berry stalklet',p.Stalk,.06,c+V3(0,d*.45,0),V3(.05,.64,.10)))
  table.insert(out,ball('Berry glint',{250,252,255},{d*.26,d*.16,.04},surface(c,d/2,d*.47,d/2,V3(-.45,.5,-.74),.01),{m='Neon',t=.25,decor=true}))
 end
 table.insert(out,ball('Berry leaf',p.Leaf,{.74,.05,.34},CF(top+V3(-.30,-.04,0))*ANG(0,.3,-.30)))
 table.insert(out,ball('Berry leaf',p.Leaf,{.66,.05,.30},CF(top+V3(.28,-.06,.05))*ANG(0,-.4,.35)))
 return out
end
function M.Blueberry()return berries(BLUE)end
function M.Iceberry()return berries(ICE)end
-- Uniform scale of a design about its centre (a Snow Melon is bigger than a Watermelon).
function M.fit(list,k)
 for _,s in ipairs(list)do s.z={s.z[1]*k,s.z[2]*k,s.z[3]*k};s.c[1]*=k;s.c[2]*=k;s.c[3]*=k end
 return list
end
-- Half height of the body ellipsoid (index 1) for each ground fruit: the port lowers / raises the design so its bottom meets the old body's.
M.BodyHalf={Watermelon=1.48,SnowMelon=1.48,EmberPumpkin=1.31,PricklyPear=1.45}
return M
