-- R134 (from the R132 proposal: "some seeds have the same designs but recoloured, make them all unique"). A signature
-- replaces a seed's shared addition (petals / orbit / bolts / broken halo / crown / antlers / crystals / none) with its
-- own shape, drawn with SeedPackVisuals' helpers on the seed body. Seeds not listed keep their current look.
-- R134 (owner): no "winged" side shards (Diamond Vine, Prism Pepper, Ash Tomato, Iceberry and Venom Vine are redesigned);
-- Prism Monarch gets small crystals of different sizes and colours instead of the round wings; nothing floats: every
-- piece is placed on the body with the kit's body helpers (k.H top, k.Bottom, k.span, k.surface, k.front).
-- k.anim(part, 'Flicker'|'Pulse'|'Twinkle') marks parts the client animates on Legendary and rarer seeds.
-- Seed space: x across, y up, the front (marks) faces -Z; the Bag camera looks from front-right.
local S={}
local pi=math.pi
local function ring3(count,fn)for i=1,count do fn((i-1)/count*pi*2,i)end end
-- A curly tendril and a leaf growing from the top of the body.
local function tendril(k,color)
 local y=k.H-.04
 local pts={k.V(0,y,0),k.V(.1,y+.2,0),k.V(.26,y+.25,0),k.V(.33,y+.14,0),k.V(.24,y+.06,0),k.V(.2,y+.16,0)}
 k.path('Tendril',pts,.05,color)
 k.lay('Leaf',k.V(-.13,y+.13,0),k.V(-.6,1,0),.36,.2,.07,color)
end
-- A line that follows the body's surface through (angle, y) points.
local function onSurface(k,name,points,out,width,color,mat)
 local pts={};for i,v in ipairs(points)do pts[i]=k.surface(v[1],v[2],out)end
 return k.path(name,pts,width,color,mat)
end
-- A vine wound round the body: `turns` turns from y0 to y1, lying on the surface.
local function vine(k,turns,y0,y1,phase,color,width)
 local pts={};local steps=math.floor(turns*20)
 for i=0,steps do local f=i/steps;pts[#pts+1]={phase+f*turns*pi*2,y0+(y1-y0)*f}end
 return onSurface(k,'Vine',pts,.01,width or .06,color),pts
end
local function lotusCup(k,color,material,tiers)
 for tier=1,tiers do
  local n=tier==1 and 7 or 5;local y=tier==1 and k.Bottom+.32 or k.Bottom+.55
  ring3(n,function(t)
   local at=k.surface(t+tier*.3,y,-.04);local out=k.V(math.sin(t+tier*.3),.9,-math.cos(t+tier*.3))
   k.lay('Lotus petal',at+out.Unit*.25,out,.62,.28,.09,color,material)
  end)
 end
end
-- One crystal: a prism with a pointed tip, rooted inside the body at `base`, growing along `dir`.
local function crystal(k,base,dir,len,width,color)
 dir=dir.Unit;local mid=base+dir*(len*.5)
 local body=k.p('Crystal',k.V(width,width,len),CFrame.lookAt(mid,mid+dir,math.abs(dir.Y)>.98 and Vector3.zAxis or Vector3.yAxis),color,Enum.Material.Glass)
 body.Transparency=.15
 local tip=k.p('Crystal tip',k.V(width*.72,width*.72,width*.72),CFrame.lookAt(base+dir*len,base+dir*(len+1),math.abs(dir.Y)>.98 and Vector3.zAxis or Vector3.yAxis)*CFrame.Angles(pi/4,pi/4,0),color,Enum.Material.Glass)
 tip.Transparency=.1
 return body,tip
end
local Sig={
 -- Forest -------------------------------------------------------------------------------------------------------
 SunflowerSeed={Draw=function(k)tendril(k,k.RGB(70,140,60))end},  -- Watermelon (its save id is SunflowerSeed)
 -- Desert -------------------------------------------------------------------------------------------------------
 CactusSeed={Draw=function(k) -- Prickly Pear: spines out of the skin and a pink flower on top
  for _,v in ipairs({{-.5,.3},{.5,.3},{-.8,-.05},{.8,-.05},{-.45,-.32},{.45,-.32},{0,.38},{0,-.4}})do
   local base=k.surface(v[1],v[2],-.03);local outward=k.surface(v[1],v[2],.3)
   k.line('Spine',base,outward,.03,k.RGB(255,250,225))
  end
  ring3(5,function(t)k.oval('Flower petal',k.V(math.sin(t)*.12,k.H+.02,math.cos(t)*.1),k.V(.18,.08,.2),k.RGB(255,120,170),CFrame.Angles(0,-t,0))end)
  k.oval('Flower heart',k.V(0,k.H+.05,0),k.V(.11,.09,.11),k.RGB(255,220,80))
 end},
 DatePalmSeed={Draw=function(k)lotusCup(k,k.RGB(255,190,120),nil,2)end}, -- Dune Lotus: a two-tier petal cup
 MirageFigSeed={Draw=function(k) -- heat shimmer on the skin and a fig neck
  for i,y in ipairs({.3,0,-.3})do
   local pts={};for j=0,10 do pts[#pts+1]={-1.1+j*.22,y+math.sin(j*.9+i)*.05}end
   onSurface(k,'Heat shimmer',pts,.012,.035,i==2 and k.RGB(255,230,170)or k.RGB(255,200,140),Enum.Material.Neon)
  end
  local y=k.H-.06;k.oval('Fig neck',k.V(0,y,0),k.V(.3,.32,.28),k.top);k.line('Fig stem',k.V(0,y+.1,0),k.V(.06,y+.28,0),.06,k.RGB(110,80,50))
 end},
 SolarStarfruitSeed={Draw=function(k) -- King: sun rays growing out of the rim, glowing
  ring3(12,function(t,i)
   local r=i%2==0 and .34 or .24;local dir=k.V(math.sin(t),math.cos(t),0)
   local hw=.6;local base=dir*(hw-.06)
   k.anim(k.p('Sun ray',k.V(.13,r,.13),CFrame.lookAt(base+dir*(r/2),base+dir*r,Vector3.zAxis)*CFrame.Angles(pi/2,0,0),k.RGB(255,205,70),Enum.Material.Neon),'Pulse')
  end)
 end},
 StarfruitSeed={Draw=function(k)end},                             -- Dune Starfruit: the star shape on its own
 -- Snow ---------------------------------------------------------------------------------------------------------
 SnowdropSeed={Draw=function(k) -- Snow Melon: snow cap and icicles
  k.oval('Snow cap',k.V(0,k.H-.14,0),k.V(.98,.46,.74),k.RGB(250,253,255))
  for _,x in ipairs({-.22,0,.22})do local y=k.Bottom+.14;local z=(k.front(x,y)or-.1)+.04
   k.line('Icicle',k.V(x,y,z),k.V(x,y-.3+math.abs(x)*.3,z),.07,k.RGB(200,240,255),Enum.Material.Glass)end
 end},
 IceberrySeed={Pattern='Dots',Draw=function(k) -- R134 redesign: a frozen calyx of ice spikes and frost swirls
  ring3(6,function(t,i)
   local base=k.surface(t,k.H-.1,-.06);local up=k.V(math.sin(t)*.5,1,-math.cos(t)*.5)
   crystal(k,base,up,i%2==0 and .26 or .18,.08,k.RGB(215,248,255))
  end)
  for _,side in ipairs({-1,1})do
   local pts={};for j=0,8 do local f=j/8;pts[#pts+1]={side*(.35+f*.5),.25-f*.45+math.sin(f*pi)*.08}end
   onSurface(k,'Frost swirl',pts,.012,.035,k.RGB(240,252,255))
  end
  local y=k.Bottom+.04;k.line('Icicle',k.V(0,y+.08,0),k.V(0,y-.2,0),.07,k.RGB(205,242,255),Enum.Material.Glass)
 end},
 WinterPineSeed={Draw=function(k) -- Aurora Lily: aurora ribbons across the skin and a white lily trumpet on top
  local colors={k.RGB(120,255,190),k.RGB(110,220,255),k.RGB(200,150,255)}
  for i,y in ipairs({.35,.1,-.15})do
   local pts={};for j=0,10 do pts[#pts+1]={-1.15+j*.23,y+math.sin(j*.8+i)*.07}end
   k.anim(onSurface(k,'Aurora',pts,.012,.06,colors[i],Enum.Material.Neon),'Pulse')
  end
  ring3(3,function(t)k.lay('Lily petal',k.V(math.sin(t)*.08,k.H+.14,math.cos(t)*.06),k.V(math.sin(t)*.5,1,math.cos(t)*.4),.42,.16,.07,k.RGB(250,250,255))end)
 end},
 CrystalLilySeed={Draw=function(k) -- Glacier Lotus: frozen in an ice block
  for _,v in ipairs({{k.V(1.2,1.5,.95),CFrame.Angles(.12,.35,.08)},{k.V(1.0,1.35,1.05),CFrame.Angles(-.2,-.4,.3)},{k.V(.9,1.7,.8),CFrame.Angles(.3,.1,-.25)}})do
   local ice=k.p('Ice chunk',v[1],CFrame.new(0,-.02,0)*v[2],k.RGB(190,240,255),Enum.Material.Glass);ice.Transparency=.7
  end
  for _,v in ipairs({{-.4,.0},{.36,.04},{.05,.12}})do k.shard(k.V(v[1],k.H+v[2],0),.22,k.RGB(220,250,255))end
 end},
 SilentFrostbellSeed={Draw=function(k) -- the body is the bell: a hanging loop and a clapper
  k.oval('Bell loop',k.V(0,k.H+.06,0),k.V(.26,.2,.08),k.ink)
  k.line('Clapper cord',k.V(0,k.Bottom+.1,0),k.V(0,k.Bottom-.12,0),.04,k.ink);k.oval('Clapper',k.V(0,k.Bottom-.16,0),k.V(.2,.2,.2),k.RGB(200,225,255))
 end},
 PolarStarbloomSeed={Draw=function(k) -- a large snowflake behind the star
  ring3(6,function(t)
   local tip=k.V(math.sin(t)*1.08,math.cos(t)*1.08,.16);k.anim(k.line('Snowflake arm',k.V(0,0,.16),tip,.05,k.RGB(200,240,255),Enum.Material.Neon),'Pulse')
   for _,f in ipairs({.55,.8})do
    local b=k.V(math.sin(t)*1.08*f,math.cos(t)*1.08*f,.16)
    for _,s in ipairs({-1,1})do k.line('Snowflake branch',b,b+k.V(math.sin(t+s*.8)*.2,math.cos(t+s*.8)*.2,0),.035,k.RGB(200,240,255),Enum.Material.Neon)end
   end
  end)
 end},
 WinterCrownwoodSeed={KeepAddition=true,Crown='ice',Draw=function(k) -- icicle crown and a pine sprig
  for i=0,4 do local base=k.surface(-1.6,.2+i*.08,-.03);k.line('Pine needle',base,base+k.V(-.3-i*.04,.14+i*.02,0),.05,k.RGB(60,120,90))end
 end},
 -- Lava ---------------------------------------------------------------------------------------------------------
 LavaLotusSeed={Draw=function(k) -- flame petals, flickering
  for i=-3,3 do
   local t=i*.38;local c=i%2==0 and k.RGB(255,140,40)or k.RGB(255,215,80)
   k.anim(k.oval('Flame',k.V(math.sin(t)*.48,.55+math.cos(t)*.32,.02),k.V(.2,.5,.12),c,CFrame.Angles(0,0,-t),Enum.Material.Neon),'Flicker')
  end
 end},
 ObsidianMawSeed={Pattern='None',Draw=function(k) -- a jaw of obsidian teeth around a glowing mouth
  local z0=k.front(0,0)or-.25
  k.anim(k.oval('Maw glow',k.V(0,0,z0+.02),k.V(.8,.16,.1),k.RGB(255,140,40),nil,Enum.Material.Neon),'Pulse')
  for i=-3,3 do
   local x=i*.1;local zu,zl=k.front(x,.13)or z0,k.front(x+.05,-.13)or z0
   k.p('Upper tooth',k.V(.09,.18,.09),CFrame.new(x,.13,zu)*CFrame.Angles(0,0,pi/4),k.RGB(35,25,40),Enum.Material.Glass)
   k.p('Lower tooth',k.V(.09,.18,.09),CFrame.new(x+.05,-.13,zl)*CFrame.Angles(0,0,pi/4),k.RGB(35,25,40),Enum.Material.Glass)
  end
 end},
 SupernovaBloomSeed={Draw=function(k) -- Boom Bloom: firework sparks bursting out of the skin, and a lit fuse
  local colors={k.RGB(255,90,120),k.RGB(255,210,80),k.RGB(120,220,255),k.RGB(170,255,120)}
  ring3(10,function(t,i)
   local dir=k.V(math.sin(t),math.cos(t),0);local a=dir*.55;local b=dir*1.0
   k.line('Spark trail',a,b,.04,colors[i%4+1],Enum.Material.Neon)
   k.anim(k.oval('Spark',b,k.V(.1,.1,.1),colors[i%4+1],nil,Enum.Material.Neon),'Twinkle')
  end)
  local y=k.H-.04;k.line('Fuse',k.V(0,y,0),k.V(.12,y+.26,0),.05,k.RGB(90,70,60))
  k.anim(k.oval('Fuse spark',k.V(.13,y+.3,0),k.V(.12,.12,.12),k.RGB(255,230,120),nil,Enum.Material.Neon),'Flicker')
 end},
 -- Crystal ------------------------------------------------------------------------------------------------------
 AmethystSeed={Pattern='None',Draw=function(k) -- Amethyst Grape: a grape cluster on a vine
  for _,v in ipairs({{-.16,.2},{.16,.2},{0,0},{-.28,0},{.28,0},{-.14,-.22},{.14,-.22},{0,-.38}})do
   local z=(k.front(v[1],v[2])or-.3)+.06
   k.oval('Grape',k.V(v[1],v[2],z),k.V(.26,.26,.2),k.RGB(150,95,200))
  end
  tendril(k,k.RGB(90,150,80))
 end},
 PrismOrchidSeed={Pattern='None',Draw=function(k) -- R134 redesign, Prism Pepper: a crystal bell pepper
  -- three lobes at the bottom, a faceted green-crystal calyx and stem, and a rainbow glint down the front
  ring3(3,function(t)k.oval('Pepper lobe',k.surface(t+pi/3,k.Bottom+.14,-.12),k.V(.3,.3,.3),k.bottom)end)
  local y=k.H-.05
  for i=0,4 do local t=i/5*pi*2;k.p('Crystal calyx',k.V(.16,.08,.16),CFrame.new(math.sin(t)*.14,y,math.cos(t)*.12)*CFrame.Angles(0,-t+pi/4,0),k.RGB(110,220,160),Enum.Material.Glass)end
  k.p('Crystal stem',k.V(.1,.3,.1),CFrame.new(.03,y+.17,0)*CFrame.Angles(0,pi/4,-.25),k.RGB(110,220,160),Enum.Material.Glass)
  local colors={k.RGB(255,150,200),k.RGB(140,230,255),k.RGB(255,240,140)}
  for i,a in ipairs({-.32,-.18,-.04})do
   local pts={};for j=0,6 do local y2=.45-j*.15;pts[#pts+1]={a+math.sin(j*.7)*.04,y2}end
   onSurface(k,'Prism glint',pts,.012,.035,colors[i],Enum.Material.Neon)
  end
 end},
 MoonflowerSeed={Draw=function(k) -- Moon Melon: a stem and leaf on the crescent's top tip, a little star on the lower tip
  local y=k.H-.08;local cx=k.span(y);local tip=k.V(cx,y,0)
  k.line('Stem',tip,tip+k.V(.08,.22,0),.07,k.RGB(110,150,90))
  k.lay('Leaf',tip+k.V(.22,.26,0),k.V(1,.3,0),.34,.18,.06,k.leafColor)
  local ly=k.Bottom+.06;local lx=k.span(ly)
  k.anim(k.p('Moon star',k.V(.16,.16,.08),CFrame.new(lx,ly-.04,0)*CFrame.Angles(0,0,pi/4),k.RGB(255,240,170),Enum.Material.Neon),'Twinkle')
 end},
 DiamondVineSeed={Pattern='None',Draw=function(k) -- R134 redesign: a vine wound tight round the seed, diamond leaves on it, a diamond bud
  local _,pts=vine(k,1.5,k.Bottom+.18,k.H-.2,.4,k.RGB(80,170,110),.06)
  for i=4,#pts-2,6 do
   local v=pts[i];local on=k.surface(v[1],v[2],.07)
   k.anim(k.p('Diamond leaf',k.V(.17,.17,.17),CFrame.new(on)*CFrame.Angles(pi/4,v[1],pi/4),k.RGB(220,250,255),Enum.Material.Glass),'Twinkle')
  end
  local y=k.H-.03;k.p('Diamond bud',k.V(.26,.26,.26),CFrame.new(0,y+.12,0)*CFrame.Angles(pi/4,0,pi/4),k.RGB(230,252,255),Enum.Material.Glass)
  k.line('Bud stem',k.V(0,y-.04,0),k.V(0,y+.06,0),.06,k.RGB(80,170,110))
 end},
 HollowGeodeSeed={Pattern='None',Draw=function(k) -- cracked open, crystals inside
  local z=k.front(0,.05)or-.4
  k.oval('Geode hollow',k.V(0,.05,z+.03),k.V(.62,.7,.08),k.RGB(60,30,80))
  for i,v in ipairs({{-.1,.2},{.12,.25},{0,-.05},{-.14,-.2},{.13,-.18}})do
   k.anim(k.p('Geode crystal',k.V(.1,.24,.1),CFrame.new(v[1],v[2],z-.02)*CFrame.Angles(-.5,0,(i-3)*.3),k.RGB(200,140,255),Enum.Material.Neon),'Twinkle')
  end
  ring3(10,function(t)
   local x,y=math.sin(t)*.32,.05+math.cos(t)*.36;local ze=(k.front(x,y)or z)-.01
   k.p('Crack edge',k.V(.08,.08,.06),CFrame.new(x,y,ze)*CFrame.Angles(0,0,pi/4),k.RGB(235,225,245))
  end)
 end},
 OrbitLotusSeed={Draw=function(k) -- two orbit belts wrapped round the seed, with small planets riding them
  local belt1,belt2={},{}
  for j=0,24 do local a=j/24*pi*2;belt1[#belt1+1]={a,math.sin(a)*.32}end
  for j=0,24 do local a=j/24*pi*2;belt2[#belt2+1]={a+.6,-math.sin(a)*.28-.05}end
  onSurface(k,'Orbit belt',belt1,.012,.045,k.ink,Enum.Material.Neon);onSurface(k,'Orbit belt',belt2,.012,.045,k.top,Enum.Material.Neon)
  k.anim(k.oval('Planet',k.surface(belt1[5][1],belt1[5][2],.08),k.V(.2,.2,.2),k.RGB(255,200,120)),'Pulse')
  k.anim(k.oval('Planet',k.surface(belt2[16][1],belt2[16][2],.06),k.V(.15,.15,.15),k.RGB(140,220,255)),'Pulse')
 end},
 PrismMonarchSeed={KeepAddition=true,Draw=function(k) -- R134 redesign: a crown gem with a cluster of small crystals
  -- (owner: "replace the circle around it with smaller crystals of different size and colour")
  local tints={k.RGB(255,95,180),k.RGB(80,190,255),k.RGB(90,235,150),k.RGB(255,210,70),k.RGB(170,110,255),k.RGB(255,140,90)}
  local spots={{-1.2,-.1,.5,.14},{1.1,-.05,.42,.12},{-2.2,-.3,.36,.11},{2.3,-.25,.54,.14},{-.5,-.45,.28,.09},{.6,-.5,.34,.1},{2.9,.05,.3,.09},{-2.8,0,.4,.12}}
  for i,v in ipairs(spots)do
   local base=k.surface(v[1],v[2],-.05);local dir=k.V(math.sin(v[1]),.9+v[2],-math.cos(v[1]))
   local c=crystal(k,base,dir,v[3],v[4],tints[(i-1)%#tints+1]);if i%2==0 then k.anim(c,'Twinkle')end
  end
 end},
 -- Jungle -------------------------------------------------------------------------------------------------------
 CocoaSeed={Pattern='None',Draw=function(k) -- a ribbed cocoa pod
  for _,u in ipairs({-.62,-.31,0,.31,.62})do
   local pts={};for j=0,10 do local y=k.Bottom+.12+(k.H-k.Bottom-.24)*j/10;local cx,hw=k.span(y);pts[#pts+1]=k.V(cx+u*hw,y,(k.front(cx+u*hw,y)or-.1)-.005)end
   k.path('Pod rib',pts,.05,k.ink)
  end
  k.oval('Pod tip',k.V(0,k.Bottom+.05,0),k.V(.16,.2,.14),k.top);k.line('Pod stem',k.V(0,k.H-.06,0),k.V(0,k.H+.18,0),.08,k.RGB(100,70,40))
 end},
 VenomVineSeed={Pattern='Dots',Draw=function(k) -- R134 redesign: a dark vine coiled round the bean and a venom drop
  local _,pts=vine(k,1.25,k.Bottom+.15,k.H-.12,-.6,k.RGB(40,90,45),.06)
  for _,i in ipairs({7,18})do local v=pts[i];local at=k.surface(v[1],v[2],.1)
   k.lay('Vine leaf',at,k.surface(v[1]+.6,v[2]+.1,.3)-at,.3,.16,.05,k.RGB(60,130,60))end
  local y=k.Bottom;local cx=k.span(y+.06)
  k.anim(k.oval('Venom drop',k.V(cx,y-.06,0),k.V(.16,.24,.16),k.RGB(170,255,60),nil,Enum.Material.Neon),'Pulse')
 end},
 AncientWorldrootSeed={Draw=function(k) -- roots below, a small tree crown above
  for i=-2,2 do
   local x=i*.16;local mid=k.V(x*1.6,k.Bottom-.2,-.05);local tip=k.V(x*2.6+(i%2==0 and .08 or -.08),k.Bottom-.4,-.05)
   k.line('Root',k.V(x*.6,k.Bottom+.1,-.05),mid,.08,k.RGB(110,80,55));k.line('Root',mid,tip,.05,k.RGB(110,80,55))
  end
  k.line('Trunk',k.V(0,k.H-.04,0),k.V(0,k.H+.23,0),.1,k.RGB(110,80,55))
  for _,v in ipairs({{0,.4},{-.2,.3},{.2,.3}})do k.oval('Canopy',k.V(v[1],k.H+v[2],0),k.V(.34,.28,.3),k.RGB(60,160,90))end
 end},
 -- Storm --------------------------------------------------------------------------------------------------------
 ThunderTulipSeed={Draw=function(k) -- a tulip cup and one bolt on the front
  ring3(3,function(t)k.oval('Tulip petal',k.V(math.sin(t)*.2,k.H-.04,math.cos(t)*.15),k.V(.34,.62,.12),k.top,CFrame.Angles(0,t,0)*CFrame.Angles(math.rad(-16),0,0))end)
  local zig={{.08,.32},{-.07,.06},{.07,.02},{-.06,-.3}};local pts={}
  for i,v in ipairs(zig)do pts[i]=k.V(v[1],v[2],(k.front(v[1],v[2])or-.3)-.02)end
  k.path('Bolt',pts,.06,k.ink,Enum.Material.Neon)
 end},
 VoltOrchidSeed={Draw=function(k) -- orchid wings and an electric arc between the tips
  for side=-1,1,2 do k.oval('Orchid wing',k.V(side*.62,.35,0),k.V(.62,.42,.1),k.top,CFrame.Angles(0,0,side*-.5))end
  local pts={k.V(-.95,.55,-.1),k.V(-.55,.86,-.1),k.V(-.2,.66,-.1),k.V(.15,.92,-.1),k.V(.5,.7,-.1),k.V(.95,.55,-.1)}
  k.anim(k.path('Arc',pts,.045,k.ink,Enum.Material.Neon),'Flicker')
 end},
 TempestLotusSeed={Pattern='None',Draw=function(k) -- gusts of wind swirling across the skin and a storm cloud on top
  for i,y in ipairs({.35,.05,-.25})do
   local pts={};for j=0,12 do local a=-1.6+i*.3+j*.22;pts[#pts+1]={a,y+j*.025-math.sin(j*.5)*.05}end
   k.anim(onSurface(k,'Gust',pts,.012,.045,k.ink,Enum.Material.Neon),'Pulse')
  end
  for _,v in ipairs({{-.16,.06},{.12,.1},{0,.18}})do k.oval('Storm cloud',k.V(v[1],k.H+v[2],0),k.V(.34,.24,.28),k.RGB(110,120,150))end
 end},
 BlackoutBloomSeed={Draw=function(k) -- an eclipse: a black disc behind the seed with a thin bright corona on its rim
  local disc=k.p('Eclipse disc',k.V(.06,2.0,2.0),CFrame.new(0,0,.3)*CFrame.Angles(0,pi/2,0),k.RGB(8,8,16));disc.Shape=Enum.PartType.Cylinder
  local pts={};for j=0,28 do local a=j/28*pi*2;pts[#pts+1]=k.V(math.sin(a)*.99,math.cos(a)*.99,.27)end
  k.anim(k.path('Corona',pts,.05,k.RGB(230,235,255),Enum.Material.Neon),'Pulse')
 end},
 PulsarStarfruitSeed={Draw=function(k) -- a star with twin beams from its poles
  for _,s in ipairs({1,-1})do
   -- Start where the body really is at x = 0 (a five-point star has two legs at the bottom and a gap between them).
   local from=s>0 and k.H-.12 or k.Bottom+.12
   if s<0 then for y=k.Bottom,0,.02 do if k.front(0,y)then from=y+.06;break end end end
   local beam=k.p('Pulsar beam',k.V(.8,.1,.1),CFrame.new(0,from+s*.4,0)*CFrame.Angles(0,0,pi/2),k.RGB(200,220,255),Enum.Material.Neon);beam.Shape=Enum.PartType.Cylinder;beam.Transparency=.15
   k.anim(beam,'Pulse')
  end
 end},
 StormSovereignSeed={Draw=function(k) -- a thunderbolt with a small crown on its top edge
  local y=k.H-.02
  for i=0,4 do local x=.02+i*.09;k.anim(k.p('Crown point',k.V(.07,.2+.1*(i%2),.07),CFrame.new(x,y+.1+.05*(i%2),0)*CFrame.Angles(0,0,pi/4),k.RGB(255,222,90),Enum.Material.Neon),'Flicker')end
  k.p('Crown band',k.V(.5,.08,.12),CFrame.new(.2,y,0),k.RGB(255,210,70),Enum.Material.Metal)
 end},
}
S.Signatures=Sig
-- Body shapes (SeedShapes). Seeds not listed keep the classic oval.
S.Shapes={
 SunflowerSeed='Flat',BluebellSeed='Round',AppleSeed='Drop',MooncapSeed='Mushroom',SunflowerBloomSeed='Pointed',          -- Forest
 CocoaSeed='Pointed',PineappleSeed='Long',VenomVineSeed='Bean',LanternFernSeed='Teardrop',TigerOrchidSeed='Drop',AncientWorldrootSeed='Acorn', -- Jungle
 CactusSeed='Round',StarfruitSeed='Star',DatePalmSeed='Drop',MirageFigSeed='Teardrop',SolarStarfruitSeed='Round',        -- Desert
 SnowdropSeed='Flat',IceberrySeed='Round',WinterPineSeed='Long',CrystalLilySeed='Gem',SilentFrostbellSeed='Bell',PolarStarbloomSeed='Star6',WinterCrownwoodSeed='Acorn', -- Snow
 FirePepperSeed='Bean',EmberBloomSeed='Flat',AshRoseSeed='Round',LavaLotusSeed='Flame',ObsidianMawSeed='Shard',SupernovaBloomSeed='Round',EmberEmperorSeed='Pointed', -- Lava
 AmethystSeed='Round',PrismOrchidSeed='Pepper',MoonflowerSeed='Crescent',DiamondVineSeed='Long',HollowGeodeSeed='Round',OrbitLotusSeed='Oval',PrismMonarchSeed='Gem', -- Crystal
 SparkReedSeed='Long',ThunderTulipSeed='Tulip',VoltOrchidSeed='Heart',TempestLotusSeed='Teardrop',BlackoutBloomSeed='Round',PulsarStarfruitSeed='Star',StormSovereignSeed='Bolt', -- Storm
}
-- Ash Tomato (R134 redesign): an ashy tomato with a green-grey star of sepals, a stem and glowing ember cracks.
Sig.AshRoseSeed={Pattern='None',Draw=function(k)
 ring3(5,function(t)
  local dir=k.V(math.sin(t),-.45,-math.cos(t)*.85)
  k.lay('Sepal',k.V(0,k.H-.02,0)+dir.Unit*.18,dir,.4,.16,.06,k.RGB(140,175,110))
 end)
 k.line('Stem',k.V(0,k.H-.06,0),k.V(.04,k.H+.16,0),.07,k.RGB(100,120,80))
 for _,crack in ipairs({{{-.55,.28},{-.4,.12},{-.5,-.05},{-.32,-.22}},{{.42,.22},{.56,.04},{.4,-.12},{.5,-.26}}})do
  k.anim(onSurface(k,'Ember crack',crack,.008,.045,k.ink,Enum.Material.Neon),'Pulse')
 end
end}
-- R148 (owner): Desert's Aloe (Rare) and Sand Fruit (Legendary), and Fire Pepper now Mythic.
S.Shapes.DesertAloeSeed='Pointed';S.Shapes.SandFruitSeed='Round'
Sig.DesertAloeSeed={Draw=function(k) -- three fleshy blue-green aloe blades on top and a full red-orange flower spike (ten florets, red grading to yellow)
 local y=k.H-.03
 for _,t in ipairs({-.6,0,.6})do
  local dir=k.V(math.sin(t)*.75,1,math.cos(t)*.15)
  k.lay('Aloe blade',k.V(math.sin(t)*.06,y,0)+dir.Unit*.2,dir,.46-math.abs(t)*.12,.15,.08,k.RGB(46,134,114))
 end
 k.line('Aloe flower stalk',k.V(.04,y,0),k.V(.12,y+.66,0),.05,k.RGB(112,150,92))
 local grade={{226,44,30},{248,84,30},{255,140,36},{255,200,66}}
 for j=0,9 do
  local f=.28+.72*j/9;local c=grade[math.min(4,1+math.floor(j/10*4))]
  k.oval('Aloe floret',k.V(.04+.08*f+.04*(j%2*2-1),y+.66*f,-.03*(j%2*2-1)),k.V(.075,.14,.075),k.RGB(c[1],c[2],c[3]))
 end
end}
Sig.SandFruitSeed={Draw=function(k) -- a sandy round seed: sand grains on the skin, a tiny round cactus on top, two twinkling sand sparkles
 for i=0,13 do
  local a=i*2.399;local y=-.5+((i*37)%100)/100*.95
  k.oval('Sand grain',k.surface(a,y,.012),k.V(.08+.025*(i%3),.06,.08),i%2==0 and k.RGB(184,136,80)or k.RGB(244,222,168),nil,Enum.Material.Sand)
 end
 local y=k.H-.03
 k.oval('Cactus nub',k.V(0,y+.1,0),k.V(.44,.34,.44),k.RGB(65,143,69))
 ring3(5,function(t)local dir=k.V(math.sin(t),.9,math.cos(t));k.lay('Cactus spine',k.V(0,y+.2,0)+dir.Unit*.15,dir,.22,.05,.03,k.RGB(235,225,170))end)
 for _,v in ipairs({{-.3,.1},{.28,-.16}})do
  local z=(k.front(v[1],v[2])or-.3)-.02
  k.anim(k.oval('Sand sparkle',k.V(v[1],v[2],z),k.V(.07,.07,.04),k.RGB(255,240,180),nil,Enum.Material.Neon),'Twinkle')
 end
end}
Sig.FirePepperSeed={Draw=function(k) -- Mythic: a curled green stem cap and three flickering flame wisps on its shoulders
 local y=k.H-.04
 ring3(4,function(t)local dir=k.V(math.sin(t),-.3,math.cos(t));k.lay('Pepper calyx',k.V(0,y,0)+dir.Unit*.12,dir,.26,.12,.05,k.RGB(70,130,60))end)
 k.path('Pepper stem',{k.V(0,y,0),k.V(.04,y+.16,0),k.V(.13,y+.24,0),k.V(.2,y+.2,0)},.06,k.RGB(70,130,60))
 local cx,hw=k.span(y-.12)
 for i,f in ipairs({-.6,0,.6})do
  local tall=i==2 and .1 or 0
  k.anim(k.oval('Flame wisp',k.V(cx+f*hw,y-.02+.17+tall/2,.04),k.V(.12,.34+tall,.08),i==2 and k.RGB(255,215,80)or k.RGB(255,140,40),CFrame.Angles(0,0,-f*.5),Enum.Material.Neon),'Flicker')
 end
end}
function S.Get(id)return Sig[id]end
function S.Shape(id)return S.Shapes[id]or'Oval'end
return S
