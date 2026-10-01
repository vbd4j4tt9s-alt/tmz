-- R111: the approved R110 sneaker boots, dressed in their biome. Same API as R47 (Specs/ShinSpecs/KneeSpecs/Create).
-- Chunky sole with a wrap-around midsole stripe, tapered toe and sloped vamp, heel counter, cuff, tongue and pull tab.
-- Sand: leather and canvas, sand-worn toe and heel, a cloth wrap. Frost: glacier ice, snow fur cuff, icicles.
-- Lava: basalt with cracked-lava plates, glowing magma seams and obsidian shards. Crystal: reflective glass shell
-- over a glowing core, crystal toe and a crown of shards. Electric: blue metal and foil, volt trims, side bolt, static field.
-- R117: every tier adds a heel emblem (the chase camera sees the back of the boots) and its own trims, more per tier:
-- Sand stitched patch + sun stone; Frost ice gem + glowing snowflake; Lava magma gem, glowing sole seam, obsidian spur
-- and horns; Crystal faceted heel and tongue gems, prism toe, rainbow facets and a glowing crown prism; Thunder metal spine with a
-- bolt emblem, three glowing Tesla coils, prongs, a heel thruster and a tongue bolt. Parts per leg: 22 / 26 / 29 / 35 / 38.
-- Names matter: the client effects find 'Volt coil', 'Heel gem', 'Toe prism' and 'Outsole' parts by name.
-- Block, Wedge and CornerWedge parts only. Specs may carry Transparency/Reflectance; ShopProductArt shows them too.
local A={}
local V,CF=Vector3.new,CFrame.new
local M=Enum.Material
local Smooth,Neon=M.SmoothPlastic,M.Neon
local FLIP=CFrame.Angles(0,0,math.pi) -- wedge upside down: flat top, underside rises toward the toe
local BACK=CFrame.Angles(0,math.pi,0) -- wedge slope faces the heel
local DOWN=CFrame.Angles(math.pi,0,0) -- wedge hangs point down (icicles, bolt)
local TURN=CFrame.Angles(0,math.pi/2,0) -- wedge profile faces the front instead of the side
-- Tier follows shop order. Shaft = share of the R15 lower leg the boot covers.
-- Mat = material per role (SmoothPlastic when missing); Fin = {Transparency, Reflectance} per role.
-- Shell > 1 widens the collar/shaft so a glowing core fits between the leg and the glass.
local looks={
 Desert={Tier=1,Shaft=.5,Accent={233,192,113},Outsole={52,38,30},Midsole={246,238,219},Upper={205,154,96},Overlay={112,76,50},Cuff={112,76,50},Tongue={230,190,134},Laces={84,58,40},Dust={222,194,146},Emblem={244,206,120},
  Mat={Outsole=M.Rubber,Midsole=M.Sandstone,Upper=M.Leather,Overlay=M.Leather,Cuff=M.Leather,Tongue=M.Fabric,Laces=M.Fabric,Trim=M.Fabric,Tread=M.Sandstone}},
 Snow={Tier=2,Shaft=.56,Accent={150,212,248},Outsole={32,50,82},Midsole={246,251,255},Upper={214,232,248},Overlay={66,112,170},Cuff={250,252,255},Tongue={66,112,170},Laces={250,252,255},Ice={128,200,250},Flake={196,236,255},
  Mat={Outsole=M.Glacier,Midsole=M.Snow,Upper=M.Glacier,Overlay=M.Ice,Cuff=M.Snow,Tongue=M.Ice,Laces=M.Fabric,Trim=M.Ice,Tread=M.Ice},
  Fin={Overlay={0,.15},Tongue={0,.15},Trim={0,.2},Tread={0,.2}}},
 Lava={Tier=3,Shaft=.58,Accent={255,140,53},Outsole={22,18,18},Midsole={58,48,46},Upper={44,37,37},Overlay={255,140,53},Cuff={22,18,18},Tongue={255,140,53},Glow={255,96,20},Obsidian={26,20,30},Hot={255,196,90},
  Mat={Outsole=M.Basalt,Midsole=M.Basalt,Upper=M.Basalt,Overlay=M.CrackedLava,Cuff=M.Basalt,Tongue=M.CrackedLava}},
 Crystal={Tier=4,Shaft=.62,Shell=1.06,Accent={193,152,250},Outsole={30,22,50},Midsole={240,233,255},Upper={116,68,214},Toe={176,136,250},Overlay={208,214,230},Cuff={208,214,230},Tongue={170,128,250},Glow={170,96,255},Core={104,38,214},Shard={200,160,255},
  Rainbow={{255,150,214},{140,230,255},{255,226,140},{170,255,200}},
  Mat={Outsole=M.Glass,Upper=M.Glass,Toe=M.Glass,Overlay=M.Metal,Cuff=M.Metal,Tongue=M.Glass,Trim=M.Metal},
  Fin={Outsole={0,.25},Midsole={0,.15},Upper={.28,.3},Vamp={.1,.35},Toe={.1,.4},Overlay={0,.25},Cuff={0,.25},Tongue={.15,.3},Trim={0,.25},Shard={.12,.45}}},
 Storm={Tier=5,Shaft=.66,Accent={177,232,255},Outsole={16,20,32},Midsole={242,247,255},Upper={34,66,170},Overlay={242,247,255},Cuff={16,20,32},Tongue={242,247,255},Glow={40,196,255},Steel={120,132,156},Spark={224,250,255},
  Mat={Outsole=M.Rubber,Upper=M.Metal,Overlay=M.Foil,Cuff=M.Metal,Tongue=M.Foil,Trim=M.Foil},
  Fin={Upper={0,.12},Overlay={0,.1},Cuff={0,.1},Trim={0,.1}}},
 Forest={Tier=1,Shaft=.5,Accent={122,185,103},Outsole={42,38,32},Midsole={238,242,228},Upper={94,120,76},Overlay={62,52,40},Cuff={62,52,40},Tongue={124,152,100},Laces={42,38,32}},
 Jungle={Tier=1,Shaft=.5,Accent={142,187,74},Outsole={32,38,30},Midsole={234,240,222},Upper={60,100,68},Overlay={44,62,44},Cuff={44,62,44},Tongue={90,134,90},Laces={32,38,30}},
}
local function look(biome)return looks[biome]or looks.Forest end
local function rgb(t)return Color3.fromRGB(t[1],t[2],t[3])end
local function mat(L,role,fallback)return L.Mat and(L.Mat[role]or fallback and L.Mat[fallback])or Smooth end
local function fin(L,role,fallback)return L.Fin and(L.Fin[role]or fallback and L.Fin[fallback])or nil end
local function writer(out)
 -- Side=1/-1 marks an ornament for that local X side only; Create keeps the outer one on each leg.
 return function(name,size,frame,color,material,shape,side,finish)
  table.insert(out,{Name=name,Size=size,Frame=frame,Color=color,Material=material or Smooth,Shape=shape,Side=side,
   Transparency=finish and finish[1]or nil,Reflectance=finish and finish[2]or nil})
 end
end
function A.Specs(size,r6,biome,accent)
 local L=look(biome);local acc=accent or rgb(L.Accent);local out={};local p=writer(out)
 local w=math.clamp(size.X,.25,4);local d=math.clamp(size.Z,.35,5);local u=w
 local base=-size.Y*.5
 local top=r6 and w*.62 or math.max(size.Y*1.08,w*.62) -- collar height above the foot bottom
 local heel=d*.5+u*.05;local toe=heel-math.max(d*1.1,u*1.45);local len=heel-toe
 local mid=-math.min(d*.5,u*.54) -- vamp meets the shaft front here
 local shell=L.Shell or 1;local front=mid-(shell-1)*u*.5
 local glow=L.Glow and rgb(L.Glow);local trim=glow or acc
 -- Sole stack: dark outsole with toe spring, light midsole, one stripe that wraps all four sides.
 p('Outsole',V(w*1.02,u*.08,len-u*.2),CF(0,base,(heel+toe+u*.2)*.5),rgb(L.Outsole),mat(L,'Outsole'),nil,nil,fin(L,'Outsole'))
 p('Toe spring',V(w*1.02,u*.08,u*.16),CF(0,base,toe+u*.12)*FLIP,rgb(L.Outsole),mat(L,'Outsole'),'Wedge',nil,fin(L,'Outsole'))
 p('Midsole',V(w*1.06,u*.13,len-u*.04),CF(0,base+u*.105,(heel+toe+u*.04)*.5),rgb(L.Midsole),mat(L,'Midsole'),nil,nil,fin(L,'Midsole'))
 -- Tread plate: the sole is what the third-person camera sees most while running (kicked-back foot).
 p('Tread',V(w*.78,u*.03,len*.62),CF(0,base-u*.045,(heel+toe)*.5+len*.04),trim,glow and Neon or mat(L,'Tread'),nil,nil,not glow and fin(L,'Tread')or nil)
 p('Midsole stripe',V(w*1.08,u*.035,len-u*.02),CF(0,base+u*.1,(heel+toe+u*.04)*.5),trim,glow and Neon or mat(L,'Trim'),nil,nil,not glow and fin(L,'Trim')or nil)
 -- Upper: tapered toe box, sloped vamp, collar, heel counter.
 p('Toe box',V(w*.9,u*.14,mid-toe-u*.07),CF(0,base+u*.24,(mid+toe+u*.07)*.5),rgb(L.Toe or L.Overlay),mat(L,'Toe','Overlay'),nil,nil,fin(L,'Toe','Overlay'))
 p('Vamp',V(w*.9,u*.26,mid-toe-u*.12),CF(0,base+u*.44,(mid+toe+u*.12)*.5),rgb(L.Upper),mat(L,'Vamp','Upper'),'Wedge',nil,fin(L,'Vamp','Upper'))
 p('Collar',V(w*1.02*shell,top-u*.17,heel-u*.06-front),CF(0,base+(top+u*.17)*.5,(heel-u*.06+front)*.5),rgb(L.Upper),mat(L,'Upper'),nil,nil,fin(L,'Upper'))
 p('Heel counter',V(w*1.07*shell,u*.32,u*.16),CF(0,base+u*.33,heel-u*.02)*BACK,rgb(L.Overlay),mat(L,'Overlay'),'Wedge',nil,fin(L,'Overlay'))
 if L.Tier==1 and L.Dust then
  -- Sand worn into the toe and heel.
  p('Sand-worn toe',V(w*.93,u*.06,u*.19),CF(0,base+u*.2,toe+u*.155),rgb(L.Dust),M.Sand)
  p('Sand-worn heel',V(w*1.09,u*.05,u*.17),CF(0,base+u*.195,heel-u*.02),rgb(L.Dust),M.Sand)
 elseif L.Tier==2 then
  p('Ice toe cap',V(w*.84,u*.1,u*.28),CF(0,base+u*.36,toe+u*.24),rgb(L.Ice),M.Ice,'Wedge',nil,{.3,.3})
  -- A clear ice fin rising off the heel, the part the chase camera sees.
  p('Ice heel fin',V(w*.1,u*.3,u*.2),CF(0,base+u*.56,heel-u*.03)*CFrame.Angles(.3,0,0),rgb(L.Ice),M.Ice,'Wedge',nil,{.2,.3})
 elseif L.Tier==3 then
  p('Ember toe vent',V(w*.48,u*.03,u*.22),CF(0,base+u*.41,toe+u*.3)*CFrame.Angles(-.38,0,0),glow,Neon)
  -- One crack wraps both collar sides; a drip of magma runs down the heel counter slope.
  p('Magma crack',V(w*1.04,u*.03,u*.42),CF(0,base+u*.36,u*.06)*CFrame.Angles(.55,0,0),glow,Neon)
  p('Heel magma drip',V(w*.26,u*.2,u*.03),CF(0,base+u*.3345,heel-u*.011)*CFrame.Angles(-.4636,0,0),glow,Neon)
 elseif L.Tier==4 then
  -- The glass shell glows from inside; the core also hides the avatar's foot.
  p('Crystal core',V(w*1.02,top-u*.185,heel-u*.08-mid+u*.015),CF(0,base+(top+u*.165)*.5,(heel-u*.08+mid-u*.015)*.5),rgb(L.Core),Neon)
 elseif L.Tier==5 then
  p('Toe bolt',V(w*.6,u*.035,u*.24),CF(0,base+u*.41,toe+u*.3)*CFrame.Angles(-.38,0,0),glow,Neon)
  -- Two stacked blades make a lightning bolt on the outer side of the collar.
  for _,side in ipairs({-1,1})do
   p('Side bolt',V(w*.03,u*.24,u*.26),CF(side*w*.52,base+u*.46,-u*.08)*DOWN,glow,Neon,'Wedge',side)
   p('Side bolt',V(w*.03,u*.22,u*.26),CF(side*w*.52,base+u*.3,u*.06)*DOWN,glow,Neon,'Wedge',side)
  end
 end
 -- R117 tier trims on the foot. The toe welt runs along the top front edge of the toe box.
 local welt=CF(0,base+u*.31,toe+u*.09)
 if L.Tier==1 and L.Dust then
  p('Toe stitch',V(w*.93,u*.025,u*.035),welt,acc,M.Fabric)
 elseif L.Tier==3 then
  p('Toe welt',V(w*.93,u*.03,u*.035),welt,glow,Neon)
  -- A glowing seam where the basalt outsole meets the midsole, visible all the way round.
  p('Magma sole seam',V(w*1.075,u*.03,len),CF(0,base+u*.04,(heel+toe+u*.04)*.5),glow,Neon)
  p('Heel spur',V(w*.12,u*.18,u*.24),CF(0,base+u*.16,heel+u*.1)*BACK,rgb(L.Obsidian),M.Glass,'Wedge',nil,{0,.45})
 elseif L.Tier==4 then
  -- A faceted prism sits on the toe; rainbow glass facets interrupt the glowing midsole stripe.
  p('Toe prism',V(u*.3,u*.16,u*.3),CF(0,base+u*.45,toe+u*.27)*CFrame.Angles(0,math.pi/4,0),rgb(L.Shard),M.Glass,nil,nil,{.08,.5})
  p('Toe facet',V(u*.21,u*.14,u*.21),CF(0,base+u*.6,toe+u*.27)*CFrame.Angles(0,math.pi/4,0),rgb(L.Shard),M.Glass,'CornerWedge',nil,{.08,.5})
  for i,c in ipairs(L.Rainbow)do
   p('Prism facet',V(w*1.1,u*.12,u*.1),CF(0,base+u*.105,toe+u*(.36+i*.24)),rgb(c),M.Glass,nil,nil,{.05,.5})
  end
 elseif L.Tier==5 then
  -- A metal thruster on the heel, glowing at the back.
  p('Heel thruster',V(w*.46,u*.14,u*.1),CF(0,base+u*.27,heel+u*.07),rgb(L.Steel),M.Metal,nil,nil,{0,.2})
  p('Thruster glow',V(w*.34,u*.06,u*.02),CF(0,base+u*.27,heel+u*.125),rgb(L.Spark),Neon)
 end
 return out
end
function A.ShinSpecs(size,r6,biome,accent)
 local L=look(biome);local acc=accent or rgb(L.Accent);local out={};local p=writer(out)
 local w,sy,d=size.X,size.Y,size.Z
 local shell=L.Shell or 1;local glow=L.Glow and rgb(L.Glow)
 -- R6 legs carry the whole boot, so map the R15 lower-leg span onto the bottom of the leg.
 local bottom=r6 and(-sy*.5+w*.17)or(-sy*.5-w*.06)
 local top=r6 and(-sy*.5+sy*(.125+.55*L.Shaft))or(-sy*.5+sy*L.Shaft)
 local h=top-bottom;local y=(top+bottom)*.5;local front=-d*.52*shell;local back=d*.52*shell
 p('Boot shaft',V(w*1.04*shell,h,d*1.04*shell),CF(0,y,0),rgb(L.Upper),mat(L,'Upper'),nil,nil,fin(L,'Upper'))
 if L.Core then p('Crystal core',V(w*1.02,h-w*.03,d*1.02),CF(0,y-w*.015,0),rgb(L.Core),Neon)end
 if L.Tier==2 then
  p('Fur cuff',V(w*1.18,w*.24,d*1.18),CF(0,top-w*.01,0),rgb(L.Cuff),mat(L,'Cuff'))
 else
  p('Cuff band',V(w*1.09*shell,w*.12,d*1.09*shell),CF(0,top-w*.04,0),rgb(L.Cuff),mat(L,'Cuff'),nil,nil,fin(L,'Cuff'))
 end
 -- The tongue starts just above the vamp (about 0.66 x foot width above the ground on either rig).
 local low=math.min(bottom+w*(r6 and .49 or .47),top-w*.22);local high=top+w*.1
 -- Frost's fur cuff is deeper, so its tongue sits further forward to stay in front of the fur.
 local lip=L.Tier==2 and w*.1 or w*.03
 p('Tongue',V(w*.46,high-low,w*.08),CF(0,(high+low)*.5,front-lip),rgb(L.Tongue),mat(L,'Tongue'),nil,nil,fin(L,'Tongue'))
 if L.Tier>=3 then
  p('Strap',V(w*1.08*shell,w*.13,d*.56*shell),CF(0,low,-d*.25*shell),L.Tier>=4 and rgb(L.Overlay)or acc,mat(L,'Trim'),nil,nil,fin(L,'Trim'))
 else
  for i=1,2 do p('Lace',V(w*.54,w*.045,w*.05),CF(0,low+(high-low)*(i==1 and .3 or .62),front-lip-w*.05),rgb(L.Laces),mat(L,'Laces'))end
 end
 p('Pull tab',V(w*.26,w*.22,w*.07),CF(0,top+w*.03,back+w*.03),glow or acc,glow and Neon or mat(L,'Trim'),nil,nil,not glow and fin(L,'Trim')or nil)
 if L.Tier<=2 then
  p('Side stripe',V(w*1.055,w*.07,d*.5),CF(0,bottom+h*.45,d*.2)*CFrame.Angles(-.5,0,0),acc,mat(L,'Trim'),nil,nil,fin(L,'Trim'))
 end
 if L.Tier==1 and L.Dust then
  -- The side stripe is a cloth wrap; its loose end hangs on the outer side.
  for _,side in ipairs({-1,1})do
   p('Wrap tail',V(w*.035,h*.5,w*.14),CF(side*w*.535,bottom+h*.2+w*.12,d*.4)*CFrame.Angles(.2,0,side*.05),acc,mat(L,'Trim'),nil,side)
  end
 elseif L.Tier==2 then
  -- Icicles hang from the fur: two flank the tongue, one on the outer side.
  for _,x in ipairs({-.34,.34})do
   p('Icicle',V(w*.07,w*.28,w*.11),CF(x*w,top-w*.25,-d*.56)*TURN*DOWN,rgb(L.Ice),M.Ice,'Wedge',nil,{.2,.3})
  end
  for _,side in ipairs({-1,1})do
   p('Icicle',V(w*.08,w*.34,w*.13),CF(side*w*.56,top-w*.28,-d*.12)*DOWN,rgb(L.Ice),M.Ice,'Wedge',side,{.2,.3})
  end
 elseif L.Tier==3 then
  -- Two glowing magma seams wrap the shaft sides; one part shows on both sides.
  for i,t in ipairs({.2,.66})do
   p('Magma seam',V(w*1.055,w*.035,d*.5),CF(0,bottom+h*t,d*.2)*CFrame.Angles(i==1 and -.55 or .45,0,0),glow,Neon)
  end
  for _,side in ipairs({-1,1})do
   p('Obsidian shard',V(w*.13,h*.55,w*.26),CF(side*w*.55,bottom+h*.44,d*.06)*CFrame.Angles(-.12,0,side*-.12),rgb(L.Obsidian),M.Glass,'Wedge',side,{0,.45})
   p('Obsidian shard',V(w*.11,h*.38,w*.2),CF(side*w*.55,bottom+h*.3,d*.3)*CFrame.Angles(-.45,0,side*-.08),rgb(L.Obsidian),M.Glass,'Wedge',side,{0,.45})
  end
 elseif L.Tier==4 then
  local shard=fin(L,'Shard')
  for _,side in ipairs({-1,1})do
   p('Ankle crystal',V(w*.16,h*.62,w*.28),CF(side*w*.6,bottom+h*.46,d*.1)*CFrame.Angles(-.12,0,side*-.1),rgb(L.Shard),M.Glass,'CornerWedge',side,shard)
   p('Ankle crystal',V(w*.12,h*.42,w*.22),CF(side*w*.6,bottom+h*.34,d*.32)*CFrame.Angles(-.45,0,side*-.08),glow,Neon,'CornerWedge',side)
   -- A crown of shards rises from the outer half of the cuff.
   for i,c in ipairs({{.55,-.34,.3},{.6,0,.4},{.55,.34,.28}})do
    p('Crown shard',V(w*.14,w*c[3],w*.14),CF(side*w*c[1],top+w*(.02+c[3]*.5),d*c[2])*CFrame.Angles(0,i*1.2,side*-.22),rgb(L.Shard),M.Glass,'CornerWedge',side,shard)
   end
  end
 elseif L.Tier==5 then
  p('Volt ring',V(w*1.1,w*.04,d*1.1),CF(0,top-w*.12,0),glow,Neon)
  -- A thin static field shimmers over the lower shaft.
  p('Static field',V(w*1.075,h*.7,d*1.075),CF(0,bottom+h*.35,0),glow,M.ForceField)
  for _,side in ipairs({-1,1})do
   for i,f in ipairs({{.62,.5,-.05},{.44,.42,.3},{.3,.34,.62}})do
    -- Three swept-back feathers form a small wing on the outer ankle.
    p('Volt wing',V(w*.06,h*f[1],w*f[2]),CF(side*w*.54,bottom+h*(.78-i*.12),back-w*(.12-i*.08))*CFrame.Angles(f[3],0,0),i==2 and acc or glow,Neon,'Wedge',side)
   end
  end
 end
 -- R117 tier emblem on the back of the shaft, then the tier's own trims.
 local ey=bottom+h*.5;local diamond=CFrame.Angles(0,0,math.pi/4)
 local function emblem(name,s,z,color,material,finish)p(name,V(w*s,w*s,w*.05),CF(0,ey,back+w*z)*diamond,color,material,nil,nil,finish)end
 if L.Tier==1 and L.Dust then
  emblem('Heel patch',.3,.02,rgb(L.Overlay),M.Leather)
  emblem('Sun stone',.16,.045,rgb(L.Emblem),M.Sandstone)
 elseif L.Tier==2 then
  emblem('Gem frame',.32,.02,rgb(L.Cuff),M.Snow)
  emblem('Frost gem',.2,.045,rgb(L.Ice),M.Glass,{.1,.45})
  -- A small glowing snowflake on the outer ankle: three crossed bars.
  for _,side in ipairs({-1,1})do
   for i=0,2 do
    p('Snowflake',V(w*.03,w*.28,w*.035),CF(side*w*.535,bottom+h*.24,d*.2)*CFrame.Angles(i*math.pi/3,0,0),rgb(L.Flake),Neon,nil,side)
   end
  end
 elseif L.Tier==3 then
  emblem('Gem bezel',.34,.02,rgb(L.Midsole),M.Basalt)
  emblem('Magma gem',.2,.045,rgb(L.Hot),Neon)
  p('Tongue vent',V(w*.08,(high-low)*.55,w*.02),CF(0,(high+low)*.5,front-lip-w*.045),glow,Neon)
  -- Obsidian horns sweep back from the outer top of the cuff.
  for _,side in ipairs({-1,1})do
   p('Heel horn',V(w*.1,w*.36,w*.17),CF(side*w*.4,top+w*.12,back-w*.04)*CFrame.Angles(.35,0,side*-.25),rgb(L.Obsidian),M.Glass,'Wedge',side,{0,.45})
   p('Heel horn',V(w*.08,w*.24,w*.13),CF(side*w*.47,top+w*.06,back-w*.24)*CFrame.Angles(.3,0,side*-.35),rgb(L.Obsidian),M.Glass,'Wedge',side,{0,.45})
  end
 elseif L.Tier==4 then
  -- A faceted heel gem in a metal setting, glowing from inside; a tall glass prism crowns the back of the cuff.
  local shard=fin(L,'Shard')
  emblem('Gem setting',.4,.02,rgb(L.Overlay),M.Metal,{0,.3})
  p('Heel gem',V(w*.3,w*.3,w*.09),CF(0,ey,back+w*.06)*diamond,rgb(L.Shard),M.Glass,nil,nil,{.32,.4})
  p('Gem core',V(w*.16,w*.16,w*.06),CF(0,ey,back+w*.065)*diamond,rgb(L.Glow),Neon)
  local crown=CF(0,top+w*.2,back+w*.1)*CFrame.Angles(-.18,math.pi/4,0)
  p('Crown prism',V(w*.16,w*.46,w*.16),crown,rgb(L.Shard),M.Glass,nil,nil,shard)
  p('Prism heart',V(w*.07,w*.34,w*.07),crown,rgb(L.Glow),Neon)
  p('Prism tip',V(w*.16,w*.2,w*.16),crown*CF(0,w*.33,0),rgb(L.Shard),M.Glass,'CornerWedge',nil,shard)
  -- The front gets a glowing gem on the tongue, seen by other players and in the shop.
  local tongue=CF(0,(high+low)*.5+w*.06,front-lip-w*.065)*diamond
  p('Tongue gem',V(w*.22,w*.22,w*.06),tongue,rgb(L.Shard),M.Glass,nil,nil,{.3,.4})
  p('Tongue core',V(w*.11,w*.11,w*.04),tongue,rgb(L.Glow),Neon)
 elseif L.Tier==5 then
  -- Tesla coils: three glowing bands over the static field on a metal base ring.
  p('Coil base',V(w*1.14,w*.07,d*1.14),CF(0,bottom+h*.1,0),rgb(L.Steel),M.Metal,nil,nil,{0,.2})
  for i,t in ipairs({.26,.42,.58})do p('Volt coil',V(w*1.1,w*.04,d*1.1),CF(0,bottom+h*t,0),glow,Neon)end
  -- A metal spine down the back carries a bolt emblem in a diamond ring.
  p('Tesla spine',V(w*.14,h*.8,w*.08),CF(0,bottom+h*.5,back+w*.05),rgb(L.Steel),M.Metal,nil,nil,{0,.2})
  p('Emblem ring',V(w*.34,w*.34,w*.03),CF(0,ey,back+w*.105)*diamond,rgb(L.Cuff),M.Metal,nil,nil,{0,.15})
  p('Bolt emblem',V(w*.03,w*.2,w*.17),CF(-w*.035,ey+w*.065,back+w*.135)*TURN*DOWN,rgb(L.Spark),Neon,'Wedge')
  p('Bolt emblem',V(w*.03,w*.18,w*.17),CF(w*.035,ey-w*.065,back+w*.135)*TURN*DOWN,rgb(L.Spark),Neon,'Wedge')
  -- A glowing bolt on the foil tongue for the front view.
  local ty=(high+low)*.5+w*.04;local tz=front-lip-w*.055
  p('Tongue bolt',V(w*.03,w*.2,w*.16),CF(-w*.03,ty+w*.065,tz)*TURN*DOWN,glow,Neon,'Wedge')
  p('Tongue bolt',V(w*.03,w*.18,w*.16),CF(w*.03,ty-w*.065,tz)*TURN*DOWN,glow,Neon,'Wedge')
  -- Two prongs with glowing tips rise from the back of the cuff.
  for _,x in ipairs({-.3,.3})do
   p('Volt prong',V(w*.06,w*.38,w*.06),CF(x*w,top+w*.13,back+w*.04),rgb(L.Steel),M.Metal,nil,nil,{0,.2})
   p('Prong tip',V(w*.1,w*.1,w*.1),CF(x*w,top+w*.36,back+w*.04)*CFrame.Angles(math.pi/4,0,math.pi/4),rgb(L.Spark),Neon)
  end
 end
 return out
end
function A.KneeSpecs(size,r6,biome,accent)
 return {} -- knees stay bare for a cleaner silhouette
end
local classes={Wedge='WedgePart',CornerWedge='CornerWedgePart'}
function A.Create(character,parent,biome,accent)
 local count=0
 for _,side in ipairs({'Left','Right'})do
  local foot=character:FindFirstChild(side..'Foot');local r6=false
  if not foot then foot=character:FindFirstChild(side..' Leg');r6=true end
  if foot and foot:IsA('BasePart')then
   local model=Instance.new('Model');model.Name=side..'RunnerBoot';model.Parent=parent
   local outer=side=='Left'and -1 or 1
   local function build(target,specs)
   for _,s in ipairs(specs)do if not s.Side or s.Side==outer then
    local p=Instance.new(classes[s.Shape]or'Part');p.Name=s.Name;p.Size=s.Size;p.CFrame=target.CFrame*s.Frame;p.Color=s.Color;p.Material=s.Material
    if s.Transparency then p.Transparency=s.Transparency end;if s.Reflectance then p.Reflectance=s.Reflectance end
    p.Anchored=false;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=model
    local weld=Instance.new('WeldConstraint');weld.Part0=target;weld.Part1=p;weld.Parent=p
   end end
   end
   build(foot,A.Specs(foot.Size,r6,biome,accent))
   local shin=r6 and foot or character:FindFirstChild(side..'LowerLeg')
   local knee=r6 and foot or character:FindFirstChild(side..'UpperLeg')
   if shin and shin:IsA('BasePart')then build(shin,A.ShinSpecs(shin.Size,r6,biome,accent))end
   if knee and knee:IsA('BasePart')then build(knee,A.KneeSpecs(knee.Size,r6,biome,accent))end
   count+=1
  end
 end
 return count
end
return A
