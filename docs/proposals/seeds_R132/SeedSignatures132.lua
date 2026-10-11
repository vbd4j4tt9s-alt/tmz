-- R132 PROPOSAL (owner: "some seeds have the same designs but recoloured, make them all unique"). A signature replaces
-- a seed's shared addition (petals / orbit / bolts / broken halo / crown / antlers / crystals / none) with its own
-- shape, drawn with SeedPackVisuals' helpers on the same seed body. Seeds not listed keep their current look.
-- Seed space: body half-sizes x .54, y .75, z .38; the front (marks) faces -Z; the Bag camera looks from front-right.
local S={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local A=CFrame.Angles
local pi=math.pi
local function ring3(k,n,count,fn)for i=1,count do fn((i-1)/count*pi*2,i)end end
-- k = SeedPackVisuals' helpers and colours: {p,oval,line,leaf,shard,ring,bolt,top,bottom,ink,leafColor}
local function tendril(k,color)
 local pts={V(0,.7,0),V(.1,.9,0),V(.26,.95,0),V(.33,.84,0),V(.24,.76,0),V(.2,.86,0)}
 for i=1,#pts-1 do k.line('Tendril',pts[i],pts[i+1],.05,color)end
 k.leaf(-.18,.86,0,.9,color,V(.2,.36,.07))
end
local function lotusCup(k,color,material,tiers)
 for tier=1,tiers do
  local n=tier==1 and 7 or 5;local lift=tier==1 and -.42 or -.18;local spread=tier==1 and .5 or .38
  ring3(k,0,n,function(t)
   k.oval('Lotus petal',V(math.sin(t)*spread,lift,math.cos(t)*spread*.7),V(.3,.68,.09),color,A(0,t,0)*A(math.rad(-28),0,0),material)
  end)
 end
end
local function pricklyPear(k)
 for _,v in ipairs({{-.3,.3},{.3,.3},{-.36,-.05},{.36,-.05},{-.22,-.4},{.22,-.4},{0,.5},{0,-.55}})do
  local z=-.38*math.sqrt(math.max(.1,1-(v[1]/.54)^2-(v[2]/.75)^2))
  local base=V(v[1],v[2],z);local out=V(v[1]*.5,v[2]*.3,-.6).Unit*.22
  k.line('Spine',base,base+out,.03,RGB(255,250,225))
 end
 ring3(k,0,5,function(t)k.oval('Flower petal',V(math.sin(t)*.13,.83+math.cos(t)*.1,0),V(.16,.2,.08),RGB(255,120,170),A(0,0,-t))end)
 k.oval('Flower heart',V(0,.83,-.03),V(.1,.1,.1),RGB(255,220,80))
end
-- Shared helpers for the new signatures
local function wave(k,name,y,z,amp,width,color,mat)
 local last
 for i=0,10 do
  local x=-.95+i*.19;local p=V(x,y+math.sin(i*.9)*amp,z)
  if last then k.line(name,last,p,width,color,mat or Enum.Material.Neon)end;last=p
 end
end
local function helix(k,turns,r0,r1,y0,y1,color,width)
 local steps=math.floor(turns*16);local last
 for i=0,steps do
  local f=i/steps;local t=f*turns*pi*2;local r=r0+(r1-r0)*f
  local p=V(math.cos(t)*r,y0+(y1-y0)*f,math.sin(t)*r*.8)
  if last then k.line('Spiral',last,p,width,color,Enum.Material.Neon)end;last=p
 end
end
local Sig={
 -- Forest
 SunflowerSeed={Draw=function(k)tendril(k,RGB(70,140,60))end},  -- Watermelon (its save id is SunflowerSeed)
 -- Desert
 CactusSeed={Draw=pricklyPear},                                  -- Prickly Pear: spines and a pink flower
 DatePalmSeed={Draw=function(k)lotusCup(k,RGB(255,190,120),nil,2)end}, -- Dune Lotus: a two-tier petal cup
 MirageFigSeed={Draw=function(k) -- heat shimmer and a fig neck
  for i,y in ipairs({.35,.05,-.25})do wave(k,'Heat shimmer',y,.25,.06,.035,i==2 and RGB(255,230,170)or RGB(255,200,140))end
  k.oval('Fig neck',V(0,.78,0),V(.32,.34,.3),k.top);k.line('Fig stem',V(0,.92,0),V(.06,1.08,0),.06,RGB(110,80,50))
 end},
 SolarStarfruitSeed={Draw=function(k) -- sun corona of golden rays
  ring3(k,0,12,function(t,i)
   local r=i%2==0 and 1.02 or .9;k.p('Sun ray',V(.13,.13,.13),CF(math.sin(t)*r*.86,math.cos(t)*r,.05)*A(0,0,-t+pi/4),RGB(255,205,70),Enum.Material.Neon)
  end)
  k.ring(.84,0,false,RGB(255,225,120))
 end},
 -- Snow
 SnowdropSeed={Draw=function(k) -- Snow Melon: snow cap and icicles
  k.oval('Snow cap',V(0,.6,0),V(.98,.46,.74),RGB(250,253,255))
  for _,x in ipairs({-.22,0,.22})do k.line('Icicle',V(x,-.62,-.12),V(x,-.92-math.abs(x)*.3+.06,-.12),.07,RGB(200,240,255),Enum.Material.Glass)end
 end},
 WinterPineSeed={Draw=function(k) -- Aurora Lily: aurora curtains and a white lily trumpet
  wave(k,'Aurora',.75,.3,.08,.07,RGB(120,255,190));wave(k,'Aurora',.95,.34,.07,.06,RGB(110,220,255));wave(k,'Aurora',.55,.36,.06,.05,RGB(200,150,255))
  ring3(k,0,3,function(t)k.oval('Lily petal',V(math.sin(t)*.12,.86,math.cos(t)*.08),V(.16,.42,.08),RGB(250,250,255),A(0,t,0)*A(math.rad(-20),0,0))end)
 end},
 CrystalLilySeed={Draw=function(k) -- Glacier Lotus: frozen in an ice block
  for i,v in ipairs({{V(1.2,1.5,.95),A(.12,.35,.08)},{V(1.0,1.35,1.05),A(-.2,-.4,.3)},{V(.9,1.7,.8),A(.3,.1,-.25)}})do
   local ice=k.p('Ice chunk',v[1],CF(0,-.02,0)*v[2],RGB(190,240,255),Enum.Material.Glass);ice.Transparency=.7
  end
  for _,v in ipairs({{-.5,.86},{.42,.9},{.05,.98}})do k.shard(V(v[1],v[2],0),.22,RGB(220,250,255))end
 end},
 SilentFrostbellSeed={Draw=function(k) -- the body is the bell: a hanging loop and a clapper
  k.oval('Bell loop',V(0,.86,0),V(.26,.2,.08),k.ink)
  k.line('Clapper cord',V(0,-.62,0),V(0,-.86,0),.04,k.ink);k.oval('Clapper',V(0,-.9,0),V(.2,.2,.2),RGB(200,225,255))
 end},
 PolarStarbloomSeed={Draw=function(k) -- a large snowflake behind the seed
  ring3(k,0,6,function(t)
   local tip=V(math.sin(t)*1.08,math.cos(t)*1.08,.25);k.line('Snowflake arm',V(0,0,.25),tip,.05,RGB(200,240,255),Enum.Material.Neon)
   for _,f in ipairs({.55,.8})do
    local b=V(math.sin(t)*1.08*f,math.cos(t)*1.08*f,.25)
    for _,s in ipairs({-1,1})do k.line('Snowflake branch',b,b+V(math.sin(t+s*.8)*.2,math.cos(t+s*.8)*.2,0),.035,RGB(200,240,255),Enum.Material.Neon)end
   end
  end)
 end},
 WinterCrownwoodSeed={KeepAddition=true,Crown='ice',Draw=function(k) -- icicle crown and a pine sprig
  for i=0,4 do k.line('Pine needle',V(-.5,.35+i*.07,-.05),V(-.8-i*.04,.5+i*.09,-.05),.05,RGB(60,120,90))end
 end},
 -- Lava
 LavaLotusSeed={Draw=function(k) -- flame petals
  for i=-3,3 do
   local t=i*.38;local c=i%2==0 and RGB(255,140,40)or RGB(255,215,80)
   k.oval('Flame',V(math.sin(t)*.48,.55+math.cos(t)*.32,.02),V(.2,.5,.12),c,A(0,0,-t),Enum.Material.Neon)
  end
 end},
 ObsidianMawSeed={Pattern='None',Draw=function(k) -- a jaw of obsidian teeth around a glowing mouth
  k.oval('Maw glow',V(0,0,-.3),V(.86,.16,.12),RGB(255,140,40),nil,Enum.Material.Neon)
  for i=-3,3 do
   local x=i*.13;local z=-.36*math.sqrt(math.max(.1,1-(x/.54)^2))
   k.p('Upper tooth',V(.09,.18,.09),CF(x,.13,z)*A(0,0,pi/4),RGB(35,25,40),Enum.Material.Glass)
   k.p('Lower tooth',V(.09,.18,.09),CF(x+.065,-.13,z)*A(0,0,pi/4),RGB(35,25,40),Enum.Material.Glass)
  end
 end},
 SupernovaBloomSeed={Draw=function(k) -- Boom Bloom: firework burst and a fuse
  local colors={RGB(255,90,120),RGB(255,210,80),RGB(120,220,255),RGB(170,255,120)}
  ring3(k,0,10,function(t,i)
   local a,b=V(math.sin(t)*.72,math.cos(t)*.86,.2),V(math.sin(t)*1.08,math.cos(t)*1.22,.2)
   k.line('Spark trail',a,b,.04,colors[i%4+1],Enum.Material.Neon);k.oval('Spark',b,V(.09,.09,.09),colors[i%4+1],nil,Enum.Material.Neon)
  end)
  k.line('Fuse',V(0,.72,0),V(.12,.98,0),.05,RGB(90,70,60));k.oval('Fuse spark',V(.13,1.02,0),V(.12,.12,.12),RGB(255,230,120),nil,Enum.Material.Neon)
 end},
 -- Crystal
 AmethystSeed={Pattern='None',Draw=function(k) -- Amethyst Grape: a grape cluster on a vine
  for _,v in ipairs({{-.16,.2},{.16,.2},{0,.0},{-.28,.0},{.28,.0},{-.14,-.22},{.14,-.22},{0,-.42}})do
   local z=-.38*math.sqrt(math.max(.1,1-(v[1]/.54)^2-(v[2]/.75)^2))
   k.oval('Grape',V(v[1],v[2],z),V(.26,.26,.2),RGB(150,95,200))
  end
  tendril(k,RGB(90,150,80))
 end},
 DiamondVineSeed={Draw=function(k) -- a vine spiralling round the seed with diamond leaves
  helix(k,1.6,.6,.6,-.7,.7,RGB(80,170,110),.05)
  for i=0,3 do local t=i*1.6+.6;k.p('Diamond leaf',V(.16,.16,.16),CF(math.cos(t)*.62,-.55+i*.38,math.sin(t)*.5)*A(pi/4,0,pi/4),RGB(220,250,255),Enum.Material.Glass)end
 end},
 HollowGeodeSeed={Pattern='None',Draw=function(k) -- cracked open, crystals inside
  k.oval('Geode hollow',V(0,.05,-.33),V(.62,.78,.08),RGB(60,30,80))
  for i,v in ipairs({{-.1,.2},{.12,.25},{0,-.05},{-.14,-.2},{.13,-.18}})do
   k.p('Geode crystal',V(.1,.24,.1),CF(v[1],v[2],-.4)*A(-.5,0,(i-3)*.3),RGB(200,140,255),Enum.Material.Neon)
  end
  ring3(k,0,10,function(t)k.p('Crack edge',V(.08,.08,.06),CF(math.sin(t)*.32,.05+math.cos(t)*.4,-.36)*A(0,0,pi/4),RGB(235,225,245))end)
 end},
 OrbitLotusSeed={Draw=function(k) -- keeps two crossed orbits, now with small planets
  k.ring(.94,.5,false,k.ink);k.ring(1.06,-.45,false,k.top)
  k.oval('Planet',V(.86,.38,.2),V(.2,.2,.2),RGB(255,200,120));k.oval('Planet',V(-.8,-.45,-.1),V(.15,.15,.15),RGB(140,220,255))
 end},
 PrismMonarchSeed={KeepAddition=true,Draw=function(k) -- prism butterfly wings with the crown
  local tints={RGB(255,170,220),RGB(170,220,255),RGB(200,255,200),RGB(255,240,170)}
  for side=-1,1,2 do
   local w1=k.oval('Prism wing',V(side*.78,.32,.15),V(.62,.72,.06),tints[side<0 and 1 or 2],A(0,0,side*-.35),Enum.Material.Glass);w1.Transparency=.25
   local w2=k.oval('Prism wing',V(side*.66,-.32,.15),V(.44,.5,.06),tints[side<0 and 3 or 4],A(0,0,side*.4),Enum.Material.Glass);w2.Transparency=.25
  end
 end},
 -- Jungle
 CocoaSeed={Pattern='None',Draw=function(k) -- a ribbed cocoa pod
  for _,x in ipairs({-.3,-.15,0,.15,.3})do
   local z=-.38*math.sqrt(math.max(.1,1-(x/.54)^2))-.01
   k.oval('Pod rib',V(x,0,z),V(.06,1.25,.05),k.ink)
  end
  k.oval('Pod tip',V(0,-.78,0),V(.22,.3,.2),k.top);k.line('Pod stem',V(0,.72,0),V(0,.95,0),.08,RGB(100,70,40))
 end},
 AncientWorldrootSeed={Draw=function(k) -- roots below, a small tree crown above
  for i=-2,2 do
   local x=i*.16;local mid=V(x*1.6,-.92,-.05);local tip=V(x*2.6+(i%2==0 and .08 or -.08),-1.12,-.05)
   k.line('Root',V(x*.6,-.62,-.05),mid,.08,RGB(110,80,55));k.line('Root',mid,tip,.05,RGB(110,80,55))
  end
  k.line('Trunk',V(0,.68,0),V(0,.95,0),.1,RGB(110,80,55))
  for _,v in ipairs({{0,1.12},{-.2,1.02},{.2,1.02}})do k.oval('Canopy',V(v[1],v[2],0),V(.34,.28,.3),RGB(60,160,90))end
 end},
 -- Storm
 ThunderTulipSeed={Draw=function(k) -- a tulip cup and one bolt
  ring3(k,0,3,function(t)k.oval('Tulip petal',V(math.sin(t)*.2,.72,math.cos(t)*.15),V(.34,.62,.12),k.top,A(0,t,0)*A(math.rad(-16),0,0))end)
  local zig={V(.08,.32,-.43),V(-.07,.06,-.45),V(.07,.02,-.45),V(-.06,-.3,-.42)}
  for i=1,3 do k.line('Bolt',zig[i],zig[i+1],.06,k.ink,Enum.Material.Neon)end
 end},
 VoltOrchidSeed={Draw=function(k) -- orchid wings and an electric arc between the tips
  for side=-1,1,2 do k.oval('Orchid wing',V(side*.62,.35,0),V(.62,.42,.1),k.top,A(0,0,side*-.5))end
  local pts={V(-.95,.55,-.1),V(-.55,.86,-.1),V(-.2,.66,-.1),V(.15,.92,-.1),V(.5,.7,-.1),V(.95,.55,-.1)}
  for i=1,#pts-1 do k.line('Arc',pts[i],pts[i+1],.045,k.ink,Enum.Material.Neon)end
 end},
 TempestLotusSeed={Pattern='None',Draw=function(k) -- a storm vortex around the seed and a cloud on top
  helix(k,2.2,.62,.92,-.75,.75,k.ink,.045)
  for _,v in ipairs({{-.18,.95},{.12,1.0},{0,1.08}})do k.oval('Storm cloud',V(v[1],v[2],0),V(.34,.24,.28),RGB(110,120,150))end
 end},
 BlackoutBloomSeed={Draw=function(k) -- an eclipse: a black disc with a thin bright corona
  local disc=k.p('Eclipse disc',V(.06,2.0,2.0),CF(0,0,.32)*A(0,pi/2,0),RGB(8,8,16));disc.Shape=Enum.PartType.Cylinder
  k.ring(1.02,0,false,RGB(230,235,255))
 end},
 PulsarStarfruitSeed={Draw=function(k) -- a star with twin beams from its poles
  for _,s in ipairs({1,-1})do
   local beam=k.p('Pulsar beam',V(.8,.1,.1),CF(0,s*1.12,0)*A(0,0,pi/2),RGB(200,220,255),Enum.Material.Neon);beam.Shape=Enum.PartType.Cylinder;beam.Transparency=.15
  end
 end},
 StarfruitSeed={Draw=function(k)end},                             -- Dune Starfruit: the star shape on its own
 StormSovereignSeed={Draw=function(k) -- a thunderbolt with a small crown
  for i=0,4 do local x=.02+i*.09;k.p('Crown point',V(.07,.2+.1*(i%2),.07),CF(x,1.05+.05*(i%2),0)*A(0,0,pi/4),RGB(255,222,90),Enum.Material.Neon)end
  k.p('Crown band',V(.5,.08,.12),CF(.2,.95,0),RGB(255,210,70),Enum.Material.Metal)
 end},
}
S.Signatures=Sig
-- Body shapes (SeedShapes132). Seeds not listed keep the classic oval.
S.Shapes={
 SunflowerSeed='Flat',BluebellSeed='Round',AppleSeed='Drop',MooncapSeed='Mushroom',SunflowerBloomSeed='Pointed',          -- Forest
 CocoaSeed='Pointed',PineappleSeed='Long',VenomVineSeed='Bean',LanternFernSeed='Teardrop',TigerOrchidSeed='Drop',AncientWorldrootSeed='Acorn', -- Jungle
 CactusSeed='Round',StarfruitSeed='Star',DatePalmSeed='Drop',MirageFigSeed='Teardrop',SolarStarfruitSeed='Round',        -- Desert
 SnowdropSeed='Flat',IceberrySeed='Round',WinterPineSeed='Long',CrystalLilySeed='Gem',SilentFrostbellSeed='Bell',PolarStarbloomSeed='Star6',WinterCrownwoodSeed='Acorn', -- Snow
 FirePepperSeed='Bean',EmberBloomSeed='Flat',AshRoseSeed='Round',LavaLotusSeed='Flame',ObsidianMawSeed='Shard',SupernovaBloomSeed='Round',EmberEmperorSeed='Pointed', -- Lava
 AmethystSeed='Round',PrismOrchidSeed='Gem',MoonflowerSeed='Crescent',DiamondVineSeed='Long',HollowGeodeSeed='Round',OrbitLotusSeed='Oval',PrismMonarchSeed='Shard', -- Crystal
 SparkReedSeed='Long',ThunderTulipSeed='Tulip',VoltOrchidSeed='Heart',TempestLotusSeed='Teardrop',BlackoutBloomSeed='Round',PulsarStarfruitSeed='Star',StormSovereignSeed='Bolt', -- Storm
}
function S.Get(id)return Sig[id]end
function S.Shape(id)return S.Shapes[id]or'Oval'end
return S
