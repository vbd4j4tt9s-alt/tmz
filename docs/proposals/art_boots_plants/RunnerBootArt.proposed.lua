-- R110 proposal: sleek tiered runner boots. Same API as R47 (Specs/ShinSpecs/KneeSpecs/Create).
-- Chunky sole with a wrap-around midsole stripe, tapered toe and sloped vamp, heel counter, strap,
-- side stripe, tongue and pull tab. Higher tiers add Neon trims and one outer-ankle ornament. Knees stay bare.
-- Block and Wedge parts only, so ShopProductArt.Build still shows the exact wearable geometry.
local A={}
local V,CF=Vector3.new,CFrame.new
local Smooth,Neon,Metal,Glass=Enum.Material.SmoothPlastic,Enum.Material.Neon,Enum.Material.Metal,Enum.Material.Glass
local FLIP=CFrame.Angles(0,0,math.pi) -- wedge upside down: flat top, underside rises toward the toe
local BACK=CFrame.Angles(0,math.pi,0) -- wedge slope faces the heel
-- Tier follows shop order. Shaft = share of the R15 lower leg the boot covers.
local looks={
 Desert={Tier=1,Shaft=.5,Accent={233,192,113},Outsole={52,38,30},Midsole={246,238,219},Upper={205,154,96},Overlay={112,76,50},Cuff={112,76,50},Tongue={230,190,134},Laces={84,58,40}},
 Snow={Tier=2,Shaft=.56,Accent={150,212,248},Outsole={32,50,82},Midsole={246,251,255},Upper={222,236,248},Overlay={66,112,170},Cuff={250,252,255},Tongue={66,112,170},Laces={250,252,255},Ice={160,218,255}},
 Lava={Tier=3,Shaft=.58,Accent={255,140,53},Outsole={22,18,18},Midsole={58,48,46},Upper={44,37,37},Overlay={255,140,53},Cuff={22,18,18},Tongue={255,140,53},Glow={255,96,20}},
 Crystal={Tier=4,Shaft=.62,Accent={193,152,250},Outsole={30,22,50},Midsole={240,233,255},Upper={96,64,166},Overlay={208,214,230},Cuff={48,32,88},Tongue={193,152,250},Glow={170,96,255}},
 Storm={Tier=5,Shaft=.66,Accent={177,232,255},Outsole={16,20,32},Midsole={242,247,255},Upper={34,66,170},Overlay={242,247,255},Cuff={16,20,32},Tongue={242,247,255},Glow={40,196,255}},
 Forest={Tier=1,Shaft=.5,Accent={122,185,103},Outsole={42,38,32},Midsole={238,242,228},Upper={94,120,76},Overlay={62,52,40},Cuff={62,52,40},Tongue={124,152,100},Laces={42,38,32}},
 Jungle={Tier=1,Shaft=.5,Accent={142,187,74},Outsole={32,38,30},Midsole={234,240,222},Upper={60,100,68},Overlay={44,62,44},Cuff={44,62,44},Tongue={90,134,90},Laces={32,38,30}},
}
local function look(biome)return looks[biome]or looks.Forest end
local function rgb(t)return Color3.fromRGB(t[1],t[2],t[3])end
local function writer(out)
 -- Side=1/-1 marks an ornament for that local X side only; Create keeps the outer one on each leg.
 return function(name,size,frame,color,mat,shape,side)
  table.insert(out,{Name=name,Size=size,Frame=frame,Color=color,Material=mat or Smooth,Shape=shape,Side=side})
 end
end
function A.Specs(size,r6,biome,accent)
 local L=look(biome);local acc=accent or rgb(L.Accent);local out={};local p=writer(out)
 local w=math.clamp(size.X,.25,4);local d=math.clamp(size.Z,.35,5);local u=w
 local base=-size.Y*.5
 local top=r6 and w*.62 or math.max(size.Y*1.08,w*.62) -- collar height above the foot bottom
 local heel=d*.5+u*.05;local toe=heel-math.max(d*1.1,u*1.45);local len=heel-toe
 local mid=-math.min(d*.5,u*.54) -- vamp meets the shaft front here
 local overlay=L.Tier==4 and Metal or Smooth
 -- Sole stack: dark outsole with toe spring, light midsole, one stripe that wraps all four sides.
 p('Outsole',V(w*1.02,u*.08,len-u*.2),CF(0,base,(heel+toe+u*.2)*.5),rgb(L.Outsole))
 p('Toe spring',V(w*1.02,u*.08,u*.16),CF(0,base,toe+u*.12)*FLIP,rgb(L.Outsole),Smooth,'Wedge')
 p('Midsole',V(w*1.06,u*.13,len-u*.04),CF(0,base+u*.105,(heel+toe+u*.04)*.5),rgb(L.Midsole))
 -- Tread plate: the sole is what the third-person camera sees most while running (kicked-back foot).
 p('Tread',V(w*.78,u*.03,len*.62),CF(0,base-u*.045,(heel+toe)*.5+len*.04),L.Glow and rgb(L.Glow)or acc,L.Glow and Neon or Smooth)
 p('Midsole stripe',V(w*1.08,u*.035,len-u*.02),CF(0,base+u*.1,(heel+toe+u*.04)*.5),L.Glow and rgb(L.Glow)or acc,L.Glow and Neon or Smooth)
 -- Upper: tapered toe box, sloped vamp, collar, heel counter and a diagonal side stripe.
 p('Toe box',V(w*.9,u*.14,mid-toe-u*.07),CF(0,base+u*.24,(mid+toe+u*.07)*.5),rgb(L.Overlay),overlay)
 p('Vamp',V(w*.9,u*.26,mid-toe-u*.12),CF(0,base+u*.44,(mid+toe+u*.12)*.5),rgb(L.Upper),Smooth,'Wedge')
 p('Collar',V(w*1.02,top-u*.17,heel-u*.06-mid),CF(0,base+(top+u*.17)*.5,(heel-u*.06+mid)*.5),rgb(L.Upper))
 p('Heel counter',V(w*1.07,u*.32,u*.16),CF(0,base+u*.33,heel-u*.02)*BACK,rgb(L.Overlay),overlay,'Wedge')
 if L.Tier==2 then
  p('Ice toe cap',V(w*.84,u*.1,u*.28),CF(0,base+u*.36,toe+u*.24),rgb(L.Ice),Glass,'Wedge')
 elseif L.Tier==3 then
  p('Ember toe vent',V(w*.48,u*.03,u*.22),CF(0,base+u*.41,toe+u*.3)*CFrame.Angles(-.38,0,0),rgb(L.Glow),Neon)
 elseif L.Tier==5 then
  p('Toe bolt',V(w*.6,u*.035,u*.24),CF(0,base+u*.41,toe+u*.3)*CFrame.Angles(-.38,0,0),rgb(L.Glow),Neon)
 end
 return out
end
function A.ShinSpecs(size,r6,biome,accent)
 local L=look(biome);local acc=accent or rgb(L.Accent);local out={};local p=writer(out)
 local w,sy,d=size.X,size.Y,size.Z
 -- R6 legs carry the whole boot, so map the R15 lower-leg span onto the bottom of the leg.
 local bottom=r6 and(-sy*.5+w*.17)or(-sy*.5-w*.06)
 local top=r6 and(-sy*.5+sy*(.125+.55*L.Shaft))or(-sy*.5+sy*L.Shaft)
 local h=top-bottom;local y=(top+bottom)*.5;local front=-d*.52;local back=d*.52
 p('Boot shaft',V(w*1.04,h,d*1.04),CF(0,y,0),rgb(L.Upper))
 if L.Tier==2 then
  p('Fur cuff',V(w*1.18,w*.24,d*1.18),CF(0,top-w*.01,0),rgb(L.Cuff))
 else
  p('Cuff band',V(w*1.09,w*.12,d*1.09),CF(0,top-w*.04,0),rgb(L.Cuff))
 end
 -- The tongue starts just above the vamp (about 0.66 x foot width above the ground on either rig).
 local low=math.min(bottom+w*(r6 and .49 or .47),top-w*.22);local high=top+w*.1
 -- Frost's fur cuff is deeper, so its tongue sits further forward to stay in front of the fur.
 local lip=L.Tier==2 and w*.1 or w*.03
 p('Tongue',V(w*.46,high-low,w*.08),CF(0,(high+low)*.5,front-lip),rgb(L.Tongue))
 if L.Tier>=3 then
  p('Strap',V(w*1.08,w*.13,d*.56),CF(0,low,-d*.25),L.Tier==4 and rgb(L.Overlay)or acc,L.Tier==4 and Metal or Smooth)
 else
  for i=1,2 do p('Lace',V(w*.54,w*.045,w*.05),CF(0,low+(high-low)*(i==1 and .3 or .62),front-lip-w*.05),rgb(L.Laces))end
 end
 p('Pull tab',V(w*.26,w*.22,w*.07),CF(0,top+w*.03,back+w*.03),L.Glow and rgb(L.Glow)or acc,L.Glow and Neon or Smooth)
 if L.Tier<=2 then
  p('Side stripe',V(w*1.055,w*.07,d*.5),CF(0,bottom+h*.45,d*.2)*CFrame.Angles(-.5,0,0),acc)
 elseif L.Tier==3 then
  -- Two glowing magma seams wrap the shaft sides; one part shows on both sides.
  for i,t in ipairs({.2,.66})do
   p('Magma seam',V(w*1.055,w*.035,d*.5),CF(0,bottom+h*t,d*.2)*CFrame.Angles(i==1 and -.55 or .45,0,0),rgb(L.Glow),Neon)
  end
 elseif L.Tier==4 then
  p('Crystal ring',V(w*1.1,w*.035,d*1.1),CF(0,top-w*.12,0),rgb(L.Glow),Neon)
  for _,side in ipairs({-1,1})do
   p('Ankle crystal',V(w*.14,h*.62,w*.28),CF(side*w*.55,bottom+h*.46,d*.1)*CFrame.Angles(-.12,0,side*-.1),rgb(L.Glow),Neon,'Wedge',side)
   p('Ankle crystal',V(w*.12,h*.42,w*.22),CF(side*w*.55,bottom+h*.34,d*.32)*CFrame.Angles(-.45,0,side*-.08),rgb(L.Midsole),Glass,'Wedge',side)
  end
 elseif L.Tier==5 then
  p('Volt ring',V(w*1.1,w*.04,d*1.1),CF(0,top-w*.12,0),rgb(L.Glow),Neon)
  for _,side in ipairs({-1,1})do
   for i,f in ipairs({{.62,.5,-.05},{.44,.42,.3},{.3,.34,.62}})do
    -- Three swept-back feathers form a small wing on the outer ankle.
    p('Volt wing',V(w*.06,h*f[1],w*f[2]),CF(side*w*.54,bottom+h*(.78-i*.12),back-w*(.12-i*.08))*CFrame.Angles(f[3],0,0),i==2 and acc or rgb(L.Glow),Neon,'Wedge',side)
   end
  end
 end
 return out
end
function A.KneeSpecs(size,r6,biome,accent)
 return {} -- knees stay bare for a cleaner silhouette
end
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
    local p=Instance.new(s.Shape=='Wedge'and 'WedgePart'or 'Part');p.Name=s.Name;p.Size=s.Size;p.CFrame=target.CFrame*s.Frame;p.Color=s.Color;p.Material=s.Material
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
