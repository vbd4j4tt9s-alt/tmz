-- R123 PROPOSAL (not installed): refined native-part looks for Sand Snake (2), Ice Fang (3),
-- Lava Dragon (4) and Jungle King (6). Replaces the imported K100 mesh templates for those stages.
-- Same rig: every part carries RestCFrame (root space), BeastGroup (the existing group names) and
-- KeeperEyeGlow, exactly like KeeperUpgradeArt.Build. KeeperRigConfig (Pivots, Bounds, FloorSamples,
-- eye colour) is NOT changed; every part is authored inside its group's existing Bounds (checked by
-- tests/dump_refined.luau), so BeastPose grounding, KeeperStrikeFrames and KeeperContact reach stay put.
-- No meshes, decals or external assets. Ellipsoids are a Block + SpecialMesh(Sphere).
local Refined={Version=123}
local V=Vector3.new
local function rgb(r,g,b)return {r/255,g/255,b/255}end
local PI=math.pi

-- Orientation whose LookVector is fwd; upHint picks the roll.
local function frame(p,fwd,upHint)
 local f=fwd.Unit;local up=upHint or V(0,1,0)
 if math.abs(f:Dot(up.Unit))>.985 then up=V(0,0,-1)end
 local r=f:Cross(up).Unit;local u=r:Cross(f).Unit
 return CFrame.fromMatrix(p,r,u,-f)
end
-- Point on an ellipsoid surface (centre c, size s) in direction d, pushed out by `out` studs.
local function surf(c,s,d,out)
 local a,b,cc=s.X/2,s.Y/2,s.Z/2
 local t=1/math.sqrt((d.X/a)^2+(d.Y/b)^2+(d.Z/cc)^2)
 return c+d*t+d.Unit*(out or 0)
end

local function Kit()
 local k={Parts={}}
 function k.add(name,group,shape,size,cf,color,mat,o)
  o=o or {}
  table.insert(k.Parts,{Name=name,Group=group,Shape=shape,Size=size,CFrame=cf,Color=color,Material=mat or'SmoothPlastic',
   Transparency=o.T or 0,Reflectance=o.Ref or 0,EyeGlow=o.Eye==true})
 end
 -- Axis-aligned (optionally Euler-rotated) part at a centre.
 function k.box(name,group,shape,c,size,color,mat,rot,o)
  local cf=CFrame.new(c);if rot then cf=cf*CFrame.Angles(rot[1],rot[2],rot[3])end
  k.add(name,group,shape,size,cf,color,mat,o)
 end
 -- Part spanning a->b (length along the segment). Wedge: full height at a, tapering to an edge at b.
 function k.seg(name,group,shape,a,b,w,h,color,mat,o)
  o=o or {};local d=b-a;local len=d.Magnitude+(o.Ext or 0)
  local cf=frame((a+b)/2,d,o.Up)
  if shape=='Cyl'then k.add(name,group,'Cyl',V(len,w,w),cf*CFrame.Angles(0,PI/2,0),color,mat,o)
  elseif shape=='Wedge'then k.add(name,group,'Wedge',V(w,h,len),frame((a+b)/2,-d,o.Up),color,mat,o)
  else k.add(name,group,shape,V(w,h,len),cf,color,mat,o)end
 end
 -- Flat triangle a,b,c from two wedges (the standard Roblox triangle construction).
 function k.tri(name,group,a,b,c,thick,color,mat,o)
  local ab,ac,bc=b-a,c-a,c-b
  local abd,acd,bcd=ab:Dot(ab),ac:Dot(ac),bc:Dot(bc)
  if abd>acd and abd>bcd then c,a=a,c elseif acd>bcd and acd>abd then a,b=b,a end
  ab,ac,bc=b-a,c-a,c-b
  local right=ac:Cross(ab).Unit;local up=bc:Cross(right).Unit;local back=bc.Unit
  local height=math.abs(ab:Dot(up))
  k.add(name,group,'Wedge',V(thick,height,math.abs(ab:Dot(back))),CFrame.fromMatrix((a+b)/2,right,up,back),color,mat,o)
  k.add(name,group,'Wedge',V(thick,height,math.abs(ac:Dot(back))),CFrame.fromMatrix((a+c)/2,-right,up,-back),color,mat,o)
 end
 return k
end
local function sides(fn)fn(-1,'Left');fn(1,'Right')end

local Build={}

------------------------------------------------------------------ 2 Sand Snake (desert cobra-viper)
Build[2]=function()
 local k=Kit()
 local sand,top,belly=rgb(222,186,128),rgb(184,138,82),rgb(245,228,186)
 local brown,cream,dark=rgb(98,62,34),rgb(240,214,160),rgb(58,38,24)
 -- Spine path through the existing joint pivots, ending at the tail tip.
 local P={V(0,-2.6,.6),V(1.0,-2.8,3.7),V(3.1,-2.9,6.7),V(4.0,-3.0,10.0),V(3.3,-3.1,13.3),V(1.3,-3.2,16.3),V(-1.5,-3.4,18.8),V(-4.0,-3.5,21.3),V(-5.0,-3.6,24.3),V(-5.15,-3.62,26.75)}
 local W={3.3,3.2,3.0,2.8,2.5,2.2,1.85,1.45,.95}
 for i=1,9 do
  local g='Segment'..i;local a,b=P[i],P[i+1];local w=W[i];local h=math.min(w*.74,2.5)
  local ay,by=-4+h/2,-4+h/2
  local A,B=V(a.X,ay,a.Z),V(b.X,by,b.Z)
  local ext=i==9 and .2 or 1.1
  k.seg('Belly '..i,g,'Ball',A,B,w,h,belly,'SmoothPlastic',{Ext=ext})
  k.seg('Scales '..i,g,'Ball',A+V(0,h*.16,0),B+V(0,h*.16,0),w*.92,h*.8,(i%2==0)and sand or top,'SmoothPlastic',{Ext=ext*.9})
  -- Joint filler so the body reads as one smooth tube rather than beads.
  k.box('Joint '..i,g,'Ball',A+V(0,h*.08,0),V(w*.96,h*.95,w*.9),(i%2==1)and sand or top,'SmoothPlastic')
  if i<=8 then
   local m=(A+B)/2+V(0,h*.47,0);local d=(B-A)
   local yaw=frame(m,V(d.X,0,d.Z))
   k.add('Diamond rim '..i,g,'Block',V(w*.62,.14,w*.62),yaw*CFrame.Angles(0,PI/4,0),cream,'Sandstone')
   k.add('Diamond '..i,g,'Block',V(w*.42,.2,w*.42),yaw*CFrame.new(0,.03,0)*CFrame.Angles(0,PI/4,0),brown,'Sandstone')
  end
 end
 -- Rising neck (Head group pivots at the neck base).
 local n0,n1,n2=V(0,-2.75,.9),V(0,-.9,-1.2),V(0,1.15,-3.0)
 k.seg('Neck low','Head','Ball',n0,n1,3.2,2.9,top,'SmoothPlastic',{Ext=1.4})
 k.seg('Neck high','Head','Ball',n1,n2,2.8,2.6,sand,'SmoothPlastic',{Ext=1.2})
 for i,t in ipairs({.2,.5,.8})do
  local p=n0:Lerp(n2,t);local d=n2-n0
  k.add('Throat band '..i,'Head','Block',V(1.7-.25*t,.34,.42),frame(p+V(0,-.15,-1.1+.1*t),d,V(0,0,1))*CFrame.Angles(PI/2,0,0),belly,'SmoothPlastic')
 end
 k.seg('Neck diamond','Head','Block',V(0,-.55,.15),V(0,.55,-1.0),.95,.2,brown,'Sandstone',{Up=V(0,1,1)})
 -- Hood: flared, flat, behind the head; cream front, dark rim and spectacle marks on the back.
 k.box('Hood rim','Head','Ball',V(0,1.55,-2.75),V(5.6,4.7,.75),rgb(150,104,58),'SmoothPlastic')
 k.box('Hood','Head','Ball',V(0,1.45,-3.0),V(5.1,4.25,.8),rgb(236,206,150),'SmoothPlastic')
 sides(function(s)
  k.box('Hood stripe','Head','Block',V(s*1.45,1.5,-3.36),V(.35,2.6,.12),brown,'Sandstone',{0,0,s*.35})
  k.box('Hood eye spot','Head','Ball',V(s*1.15,2.0,-2.35),V(1.05,1.05,.3),cream,'SmoothPlastic')
  k.box('Hood eye dot','Head','Ball',V(s*1.15,2.0,-2.25),V(.55,.55,.3),dark,'SmoothPlastic')
 end)
 -- Head.
 k.box('Skull','Head','Ball',V(0,2.3,-5.4),V(3.7,2.05,4.0),top,'SmoothPlastic')
 k.box('Crown plate','Head','Ball',V(0,3.05,-5.3),V(2.5,.6,3.0),brown,'Sandstone')
 k.box('Upper lip','Head','Ball',V(0,1.55,-5.8),V(3.3,.62,3.1),cream,'SmoothPlastic')
 sides(function(s)
  k.box('Eye','Head','Ball',V(s*1.5,2.45,-6.0),V(.6,.55,.75),rgb(245,166,31),'Neon',nil,{Eye=true})
  k.seg('Brow horn','Head','Wedge',V(s*1.15,3.0,-5.75),V(s*1.4,4.0,-5.35),.42,.5,rgb(120,82,46),'Sandstone')
  k.box('Nostril','Head','Ball',V(s*.42,2.05,-7.35),V(.22,.18,.12),dark,'SmoothPlastic')
  k.seg('Fang','Head','Wedge',V(s*.78,1.35,-7.15),V(s*.74,.55,-7.35),.18,.22,rgb(250,246,236),'SmoothPlastic')
 end)
 -- Jaw: V-shaped jaw bones, mouth lining and a forked tongue.
 sides(function(s)
  k.seg('Jaw bone','Jaw','Block',V(s*1.3,.95,-3.9),V(s*.32,.95,-7.85),.45,.42,cream,'SmoothPlastic',{Ext=.2})
  k.seg('Tongue fork','Jaw','Block',V(0,1.0,-7.8),V(s*.2,1.0,-8.15),.1,.06,rgb(196,30,48),'SmoothPlastic')
 end)
 k.box('Mouth','Jaw','Block',V(0,.92,-5.8),V(1.5,.14,3.4),rgb(150,56,62),'SmoothPlastic')
 k.seg('Tongue','Jaw','Block',V(0,1.0,-6.4),V(0,1.0,-7.85),.16,.08,rgb(196,30,48),'SmoothPlastic')
 return k.Parts
end

------------------------------------------------------------------ 3 Ice Fang (snow sabre tiger)
Build[3]=function()
 local k=Kit()
 local fur,shade,stripe=rgb(238,243,250),rgb(200,216,236),rgb(40,48,70)
 local ice,iceDeep,ivory=rgb(160,222,255),rgb(110,190,245),rgb(250,246,230)
 local body={{'Chest',V(0,2.15,-1.5),V(4.9,4.3,5.9)},{'Torso',V(0,2.3,3.5),V(4.4,3.9,7.0)},{'Hips',V(0,2.4,8.6),V(4.7,4.1,5.9)}}
 for _,b in ipairs(body)do k.box(b[1],'Body','Ball',b[2],b[3],fur,'SmoothPlastic')end
 k.box('Back','Body','Ball',V(0,2.45,3.6),V(4.3,3.7,15.0),fur,'SmoothPlastic')
 k.box('Under fur','Body','Ball',V(0,1.25,3.3),V(3.7,2.4,11.5),shade,'SmoothPlastic')
 -- Tiger stripes: thin tilted bands hugging the widest body shell at each z (one part per stripe).
 local shells={body[1],body[2],body[3],{'Back',V(0,2.45,3.6),V(4.3,3.7,15.0)}}
 for i,z in ipairs({-2.3,.2,2.6,5.0,7.4,9.6})do
  local best,bc,bw,bh=0
  for _,e in ipairs(shells)do local dz=(z-e[2].Z)/(e[3].Z/2)
   if math.abs(dz)<1 then local f=math.sqrt(1-dz*dz);if e[3].X*f>(best or 0)then best=e[3].X*f;bc=e[2];bw=e[3].X*f;bh=e[3].Y*f end end end
  k.box('Stripe '..i,'Body','Ball',V(0,bc.Y+.05,z),V(bw+.16,bh+.16,.42),stripe,'SmoothPlastic',{(i%2==0 and .22 or -.18),0,0})
 end
 -- Belly fur tufts.
 sides(function(s)for _,z in ipairs({1.2,5.2})do
  k.seg('Belly tuft','Body','Wedge',V(s*1.2,.75,z),V(s*1.45,-.35,z+.7),.4,.9,fur,'SmoothPlastic')
 end end)
 -- Frost on the shoulders and haunches (low, inside the body bounds).
 for i,c in ipairs({{V(-1.3,4.0,-1.2),V(-1.8,4.55,-.2)},{V(1.3,4.0,-1.2),V(1.8,4.55,-.2)},{V(0,4.1,.3),V(0,4.6,1.4)},{V(-.9,4.0,8.0),V(-1.2,4.5,9.1)},{V(.9,4.0,8.0),V(1.2,4.5,9.1)}})do
  k.seg('Frost crystal','Body','Wedge',c[1],c[2],.35,.75,i%2==0 and ice or iceDeep,'Glass',{T=.18,Ref=.1})
 end
 -- Head and frosty mane.
 k.box('Mane','Head','Ball',V(0,3.05,-5.3),V(4.2,3.9,3.2),shade,'SmoothPlastic')
 k.box('Skull','Head','Ball',V(0,3.45,-7.5),V(3.7,3.1,3.9),fur,'SmoothPlastic')
 k.box('Muzzle','Head','Ball',V(0,2.6,-9.55),V(2.5,1.85,2.6),rgb(250,252,255),'SmoothPlastic')
 k.box('Nose','Head','Ball',V(0,3.25,-10.75),V(.75,.45,.55),rgb(70,78,100),'SmoothPlastic')
 for i,x in ipairs({-.45,0,.45})do
  k.seg('Brow stripe','Head','Wedge',V(x,4.95,-7.1+math.abs(x)*.4),V(x*1.3,4.55,-8.55),.1,.32,stripe,'SmoothPlastic',{Up=V(0,1,0)})
 end
 sides(function(s)
  k.box('Eye','Head','Ball',V(s*.95,3.75,-9.15),V(.62,.44,.5),rgb(56,184,242),'Neon',{0,s*.3,0},{Eye=true})
  k.box('Brow','Head','Block',V(s*.95,4.12,-9.1),V(.95,.22,.7),rgb(70,84,110),'SmoothPlastic',{.25,s*.3,-s*.25})
  k.seg('Ear','Head','Wedge',V(s*1.25,4.55,-6.6),V(s*1.6,5.85,-6.25),.42,1.0,fur,'SmoothPlastic')
  k.seg('Inner ear','Head','Wedge',V(s*1.25,4.65,-6.82),V(s*1.52,5.5,-6.55),.12,.55,rgb(168,206,248),'SmoothPlastic')
  k.seg('Cheek ruff','Head','Wedge',V(s*1.45,2.75,-7.7),V(s*2.75,2.15,-6.1),.35,1.05,fur,'SmoothPlastic',{Up=V(0,1,0)})
  k.seg('Cheek ruff low','Head','Wedge',V(s*1.3,2.05,-7.2),V(s*2.5,1.25,-5.8),.3,.85,shade,'SmoothPlastic',{Up=V(0,1,0)})
  k.seg('Cheek stripe','Head','Wedge',V(s*1.55,3.3,-7.9),V(s*1.9,3.0,-6.7),.08,.3,stripe,'SmoothPlastic')
  k.seg('Sabre fang','Head','Wedge',V(s*.58,2.05,-10.05),V(s*.5,.62,-10.35),.28,.42,ivory,'SmoothPlastic',{Up=V(0,0,-1)})
 end)
 for i,c in ipairs({{V(0,4.6,-5.0),V(0,5.85,-4.1)},{V(-1.2,4.25,-4.9),V(-2.0,5.45,-4.0)},{V(1.2,4.25,-4.9),V(2.0,5.45,-4.0)},{V(-1.75,3.3,-4.6),V(-2.75,4.2,-3.8)},{V(1.75,3.3,-4.6),V(2.75,4.2,-3.8)}})do
  k.seg('Mane crystal','Head','Wedge',c[1],c[2],.4,.85,i%2==0 and iceDeep or ice,'Glass',{T=.18,Ref=.1})
 end
 -- Jaw.
 k.box('Jaw','Jaw','Ball',V(0,1.88,-8.9),V(1.9,.7,2.55),fur,'SmoothPlastic')
 k.seg('Chin tuft','Jaw','Wedge',V(0,1.65,-9.6),V(0,1.45,-8.0),.7,.35,shade,'SmoothPlastic',{Up=V(0,-1,0)})
 -- Legs.
 sides(function(s,side)
  for _,L in ipairs({{side..'FrontLeg',-2.6,-3.0,-3.45,-3.95,true},{side..'BackLeg',9.9,10.6,9.6,9.05,false}})do
   local g,zt,zk,zf,zp,front=L[1],L[2],L[3],L[4],L[5],L[6]
   local x=s*2.25
   if front then
    k.seg('Upper leg',g,'Ball',V(x,2.0,zt),V(x,-1.0,zk),2.0,2.5,fur,'SmoothPlastic',{Ext=1.0})
    k.seg('Elbow tuft',g,'Wedge',V(x,-.3,-2.5),V(s*2.45,-1.0,-1.45),.35,.7,shade,'SmoothPlastic')
   else
    k.box('Thigh',g,'Ball',V(x,1.0,9.75),V(2.2,3.6,3.3),fur,'SmoothPlastic')
   end
   k.seg('Lower leg',g,'Ball',V(x,front and -.8 or -.6,zk),V(x,-3.6,zf),1.6,1.7,fur,'SmoothPlastic',{Ext=1.1})
   k.box('Paw',g,'Ball',V(x,-4.05,zp),V(1.7,1.1,front and 2.2 or 1.9),shade,'SmoothPlastic')
   local sp=surf(V(x,front and .5 or 1.0,front and -2.8 or 9.8),V(1.85,3.0,2.0),V(s,0,0),.02)
   k.seg('Leg stripe',g,'Wedge',sp+V(0,.9,0),sp+V(0,-.5,.2),.1,.42,stripe,'SmoothPlastic',{Up=V(0,0,1)})
   if front then for _,dx in ipairs({-.5,0,.5})do
    k.seg('Ice claw',g,'Wedge',V(x+dx,-4.15,-4.9),V(x+dx*1.1,-4.5,-5.35),.16,.3,ice,'Glass',{T=.1})
   end end
  end
 end)
 -- Tail with dark rings and a frosted tip.
 local T={V(0,1.6,11.7),V(.4,1.3,14.4),V(1.4,1.05,17.2),V(2.6,1.0,19.5),V(3.3,1.15,21.1)}
 local tw={1.45,1.25,1.05,.95}
 for i=1,4 do k.seg('Tail '..i,'Tail','Ball',T[i],T[i+1],tw[i],tw[i]*.95,fur,'SmoothPlastic',{Ext=1.15})end
 for i=1,3 do local a=T[i]:Lerp(T[i+1],.6);local d=(T[i+1]-T[i]).Unit
  k.seg('Tail ring '..i,'Tail','Cyl',a-d*.17,a+d*.17,tw[i]*.98+.08,0,stripe,'SmoothPlastic')end
 k.box('Tail tuft','Tail','Ball',V(3.25,1.15,21.05),V(1.2,1.15,1.5),shade,'SmoothPlastic')
 k.seg('Tail crystal','Tail','Wedge',V(3.3,1.4,21.0),V(3.6,2.25,21.85),.4,.75,ice,'Glass',{T=.15,Ref=.1})
 return k.Parts
end

------------------------------------------------------------------ 4 Lava Dragon
Build[4]=function()
 local k=Kit()
 local scale,scale2,plate=rgb(112,26,22),rgb(78,20,20),rgb(40,30,32)
 local belly,bone,magma=rgb(226,150,64),rgb(236,220,178),rgb(255,110,20)
 -- Body.
 k.box('Chest','Body','Ball',V(0,2.3,-1.4),V(6.4,5.4,6.6),scale,'Slate')
 k.box('Belly','Body','Ball',V(0,2.05,3.3),V(6.0,4.9,7.2),scale2,'Slate')
 sides(function(s)
  k.box('Shoulder','Body','Ball',V(s*2.35,3.3,-1.9),V(2.5,2.8,3.4),scale,'Slate')
  k.box('Haunch','Body','Ball',V(s*2.3,2.4,4.3),V(2.6,3.2,4.0),scale2,'Slate')
  for i,c in ipairs({{V(3.08,2.9,-2.4),.55},{V(3.06,1.6,-.6),-.6}})do
   k.box('Magma crack','Body','Block',V(s*c[1].X,c[1].Y,c[1].Z),V(.14,.22,2.0),magma,'Neon',{c[2],0,0})
  end
 end)
 for i,z in ipairs({-3.3,-1.5,.5})do
  k.box('Belly plate','Body','Block',V(0,-.25+(i==1 and .55 or 0),z),V(3.0,.42,1.55),belly,'SmoothPlastic',{i==1 and -.45 or 0,0,0})
 end
 local spine={{-3.2,4.75,.9},{-1.4,4.95,1.0},{.5,4.8,.95},{2.4,4.45,.85},{4.4,4.25,.75}}
 for i,s in ipairs(spine)do k.box('Spine plate','Body','Wedge',V(0,s[2]+s[3]/2-.1,s[1]),V(.42,s[3],1.5),plate,'Basalt',{0,PI,0})end
 k.seg('Spine glow','Body','Block',V(0,4.75,-3.6),V(0,4.25,5.4),.5,.22,magma,'Neon')
 -- Neck and head.
 local n0,n1,n2=V(0,4.0,-2.6),V(0,5.6,-5.2),V(0,7.6,-7.6)
 k.seg('Neck low','Head','Ball',n0,n1,3.0,3.0,scale,'Slate',{Ext=.8})
 k.seg('Neck high','Head','Ball',n1,n2,2.45,2.5,scale,'Slate',{Ext=.8})
 for i,t in ipairs({.3,.75})do local p=n0:Lerp(n2,t)
  k.add('Throat plate','Head','Block',V(1.7,.35,1.3),frame(p+V(0,-1.15,-.55),n2-n0,V(0,0,1))*CFrame.Angles(PI/2,0,0),belly,'SmoothPlastic')
  k.add('Neck spine','Head','Wedge',V(.36,1.2,1.2),frame(p+V(0,1.45,.45),n2-n0)*CFrame.Angles(0,PI,0),plate,'Basalt')
 end
 k.box('Skull','Head','Ball',V(0,8.0,-9.0),V(3.2,2.8,3.8),scale,'Slate')
 k.box('Snout','Head','Block',V(0,7.0,-11.6),V(2.3,1.45,3.4),scale,'Slate')
 k.box('Snout ridge','Head','Wedge',V(0,8.05,-11.4),V(2.0,.66,3.0),scale2,'Slate')
 k.box('Crest spine','Head','Wedge',V(0,9.85,-8.4),V(.36,.9,1.5),plate,'Basalt',{0,PI,0})
 sides(function(s)
  k.box('Eye','Head','Ball',V(s*1.42,8.4,-9.95),V(.5,.5,1.0),rgb(235,5,2),'Neon',{0,-s*.25,0},{Eye=true})
  k.box('Brow','Head','Wedge',V(s*1.3,9.0,-10.0),V(.85,.55,1.5),plate,'Basalt',{-.25,-s*.2,0})
  k.box('Nostril','Head','Block',V(s*.55,7.55,-13.25),V(.32,.24,.14),magma,'Neon')
  for _,z in ipairs({-12.9,-11.4})do k.seg('Tooth','Head','Wedge',V(s*.98,6.3,z),V(s*.98,5.75,z-.05),.18,.32,bone,'SmoothPlastic')end
  -- Swept horns: thick base, tapered tip.
  local h0,h1,h2=V(s*1.0,9.2,-8.2),V(s*1.55,10.25,-6.6),V(s*2.15,10.9,-4.2)
  k.seg('Horn base','Head','Ball',h0,h1,.9,.9,bone,'SmoothPlastic',{Ext=.4})
  k.seg('Horn tip','Head','Wedge',h1,h2,.62,.75,bone,'SmoothPlastic',{Up=V(0,1,0)})
  k.seg('Cheek spike','Head','Wedge',V(s*1.45,7.2,-8.4),V(s*2.3,7.75,-6.3),.3,.6,plate,'Basalt')
 end)
 -- Jaw with an ember-lit mouth.
 k.box('Lower jaw','Jaw','Block',V(0,5.2,-10.0),V(2.05,.8,6.0),scale2,'Slate')
 k.box('Mouth glow','Jaw','Block',V(0,5.66,-10.0),V(1.55,.12,5.3),magma,'Neon')
 sides(function(s)for _,z in ipairs({-12.6,-11.0})do
  k.seg('Lower tooth','Jaw','Wedge',V(s*.82,5.55,z),V(s*.82,5.9,z),.16,.26,bone,'SmoothPlastic')end end)
 -- Legs.
 sides(function(s,side)
  local x=s*2.85
  local F=side..'FrontLeg'
  k.seg('Upper arm',F,'Ball',V(x,2.0,-2.5),V(x,-.9,-3.0),1.85,2.2,scale,'Slate',{Ext=1.0})
  k.seg('Forearm',F,'Block',V(x,-.7,-3.0),V(x,-3.95,-3.6),1.3,1.4,scale2,'Slate',{Ext=.2})
  k.box('Fore foot',F,'Block',V(x,-4.45,-3.95),V(1.6,.9,2.2),scale2,'Slate')
  k.seg('Elbow spike',F,'Wedge',V(x,-.55,-2.4),V(s*3.05,-.15,-1.15),.3,.55,plate,'Basalt')
  k.box('Forearm crack',F,'Block',V(s*3.47,-2.2,-3.3),V(.12,1.6,.18),magma,'Neon',{.2,0,0})
  for _,dx in ipairs({-.55,0,.55})do k.seg('Claw',F,'Wedge',V(x+dx,-4.35,-4.95),V(x+dx,-4.85,-5.38),.2,.4,bone,'SmoothPlastic')end
  local B=side..'BackLeg'
  k.box('Thigh',B,'Ball',V(s*2.85,1.0,4.6),V(2.6,3.2,3.6),scale,'Slate')
  k.seg('Shin',B,'Block',V(s*2.85,-.6,5.4),V(s*2.85,-3.9,3.9),1.4,1.45,scale2,'Slate',{Ext=.3})
  k.box('Hind foot',B,'Block',V(s*2.85,-4.35,3.4),V(1.75,.9,2.4),scale2,'Slate')
  k.box('Thigh crack',B,'Block',V(s*4.15,1.1,4.6),V(.12,.22,1.9),magma,'Neon',{-.6,0,0})
  for _,dx in ipairs({-.55,0,.55})do k.seg('Claw',B,'Wedge',V(s*2.85+dx,-4.35,2.3),V(s*2.85+dx,-4.75,1.95),.2,.36,bone,'SmoothPlastic')end
 end)
 -- Tail: tapering, curling right, side spikes, glowing seam, spade tip.
 local T={V(0,.75,6.6),V(.2,.45,9.5),V(.9,.15,12.3),V(2.0,-.15,14.7),V(3.15,-.3,16.55)}
 local tw={2.4,1.95,1.5,1.05}
 for i=1,4 do
  local a,b=T[i],T[i+1]
  k.seg('Tail '..i,'Tail','Ball',a,b,tw[i],tw[i]*.85,i%2==1 and scale or scale2,'Slate',{Ext=1.0})
  if i<=3 then
   local m=a:Lerp(b,.5)+V(0,tw[i]*.85/2-.05,0)
   k.seg('Tail seam '..i,'Tail','Block',m-(b-a)*.3,m+(b-a)*.3,.24,.14,magma,'Neon')
   k.add('Tail spine','Tail','Wedge',V(.3,.55,1.1),frame(m+V(0,.3,0),b-a)*CFrame.Angles(0,PI,0),plate,'Basalt')
  end
 end
 for _,s in ipairs({-1,1})do local m=T[2]:Lerp(T[3],.5)
  k.seg('Tail side spike','Tail','Wedge',m+V(s*.6,0,0),m+V(s*1.55,.1,.9),.25,.5,plate,'Basalt')end
 k.add('Tail spade','Tail','Block',V(1.25,.28,1.25),CFrame.new(V(3.6,-.3,17.4))*CFrame.Angles(0,PI/4+.55,0),plate,'Basalt')
 k.add('Tail spade glow','Tail','Block',V(.7,.32,.7),CFrame.new(V(3.6,-.3,17.4))*CFrame.Angles(0,PI/4+.55,0),magma,'Neon')
 -- Wings: arm bones, finger ribs, and wedge-triangle membranes (inner panels darker).
 sides(function(s,side)
  local g=side..'Wing'
  local function P(x,y,z)return V(s*x,y,z)end
  local S,E,Wr=P(2.9,4.8,-1.2),P(7.6,10.4,-.4),P(12.2,12.9,.9)
  local F1,F2,F3,R0=P(16.3,10.9,4.0),P(14.4,7.4,8.6),P(10.4,4.5,10.9),P(3.1,3.6,6.4)
  local mem,memIn=rgb(150,34,22),rgb(96,20,18)
  k.tri('Membrane',g,Wr,F1,F2,.16,mem)
  k.tri('Membrane',g,Wr,F2,F3,.16,mem)
  k.tri('Membrane',g,E,Wr,F3,.16,memIn)
  k.tri('Membrane',g,S,E,F3,.16,memIn)
  k.tri('Membrane',g,S,F3,R0,.16,memIn)
  k.seg('Wing arm',g,'Ball',S,E,.95,.95,scale,'Slate',{Ext=.6})
  k.seg('Wing forearm',g,'Block',E,Wr,.7,.7,scale2,'Slate',{Ext=.3})
  for _,f in ipairs({F1,F2,F3})do k.seg('Wing rib',g,'Cyl',Wr,f,.32,0,plate,'Basalt')end
  k.seg('Wing thumb',g,'Wedge',Wr,P(12.8,13.5,-.6),.3,.45,bone,'SmoothPlastic')
 end)
 return k.Parts
end

------------------------------------------------------------------ 6 Jungle King (silverback)
Build[6]=function()
 local k=Kit()
 local fur,fur2,silver,skin=rgb(40,40,46),rgb(56,56,62),rgb(160,162,170),rgb(62,54,56)
 local moss,vine,leaf,bone=rgb(92,140,56),rgb(78,102,40),rgb(62,158,56),rgb(246,240,222)
 -- Body.
 k.box('Torso','Body','Ball',V(0,3.6,1.0),V(7.4,7.3,5.6),fur,'SmoothPlastic')
 k.box('Shoulder mass','Body','Ball',V(0,5.65,.4),V(8.6,3.6,4.6),fur2,'SmoothPlastic')
 k.box('Silver saddle','Body','Ball',V(0,4.9,2.2),V(6.0,4.4,3.6),silver,'SmoothPlastic')
 k.box('Belly','Body','Ball',V(0,2.3,-.9),V(4.6,3.8,2.4),skin,'SmoothPlastic')
 sides(function(s)
  k.box('Pec','Body','Ball',V(s*1.45,4.75,-1.55),V(2.7,2.2,1.3),skin,'SmoothPlastic',{0,0,s*.12})
  k.box('Moss','Body','Ball',V(s*2.7,7.0,.6),V(2.5,.7,2.3),moss,'Grass')
 end)
 local v0,v1,v2=V(-3.35,6.4,-.75),V(-.4,4.15,-2.35),V(3.0,1.5,-1.35)
 k.seg('Chest vine','Body','Cyl',v0,v1,.4,0,vine,'SmoothPlastic',{Ext=.3})
 k.seg('Chest vine','Body','Cyl',v1,v2,.4,0,vine,'SmoothPlastic',{Ext=.3})
 for i,p in ipairs({v0:Lerp(v1,.45),v1,v1:Lerp(v2,.55)})do
  k.seg('Vine leaf','Body','Wedge',p,p+V(i==2 and .9 or -.6,.55,-.35),.12,.55,leaf,'LeafyGrass',{Up=V(0,0,-1)})
 end
 -- Head: cranium + sagittal crest, heavy brow, leathery face, leaf crown.
 k.box('Cranium','Head','Ball',V(0,9.25,-2.6),V(4.5,4.4,4.6),fur,'SmoothPlastic')
 k.box('Crest','Head','Ball',V(0,10.9,-1.7),V(1.3,1.4,3.4),fur2,'SmoothPlastic')
 k.box('Face','Head','Ball',V(0,8.75,-4.25),V(3.4,3.2,1.6),skin,'SmoothPlastic')
 k.box('Brow ridge','Head','Ball',V(0,9.75,-4.4),V(3.5,.85,1.3),rgb(48,42,44),'SmoothPlastic',{-.2,0,0})
 k.box('Muzzle','Head','Ball',V(0,7.9,-4.55),V(2.8,1.85,1.55),skin,'SmoothPlastic')
 k.box('Nose','Head','Ball',V(0,8.45,-5.15),V(1.4,.55,.4),rgb(34,30,32),'SmoothPlastic')
 sides(function(s)
  k.box('Eye','Head','Ball',V(s*.8,9.35,-4.95),V(.55,.38,.32),rgb(235,153,38),'Neon',nil,{Eye=true})
  k.box('Ear','Head','Ball',V(s*2.25,9.0,-2.5),V(.55,1.0,.8),skin,'SmoothPlastic')
  k.seg('Upper fang','Head','Wedge',V(s*.68,7.15,-5.05),V(s*.64,6.6,-5.15),.2,.26,bone,'SmoothPlastic')
 end)
 for i=0,4 do
  local a=-PI*.95+i*(PI*.9/4);local dir=V(math.cos(a),0,math.sin(a))
  k.seg('Leaf crown','Head','Wedge',V(0,10.75,-2.4)+dir*1.45,V(0,11.55,-2.4)+dir*2.1,.14,.75,i%2==0 and leaf or moss,'LeafyGrass',{Up=dir})
 end
 k.box('Crown orchid','Head','Ball',V(0,11.15,-3.85),V(.7,.6,.6),rgb(238,92,188),'Neon')
 -- Jaw.
 k.box('Chin','Jaw','Ball',V(0,7.15,-4.3),V(2.6,.9,1.5),skin,'SmoothPlastic')
 k.box('Mouth','Jaw','Block',V(0,7.58,-4.45),V(1.8,.12,1.0),rgb(120,40,44),'SmoothPlastic')
 sides(function(s)k.seg('Lower fang','Jaw','Wedge',V(s*.7,7.45,-4.85),V(s*.7,7.9,-4.9),.2,.24,bone,'SmoothPlastic')end)
 -- Arms: big deltoid, long arm, thick forearm, knuckle-walking fist, vine bracers.
 sides(function(s,side)
  local g=side..'Arm';local function P(x,y,z)return V(s*x,y,z)end
  k.box('Deltoid',g,'Ball',P(4.6,6.0,0),V(3.2,3.0,3.4),fur2,'SmoothPlastic')
  k.box('Arm moss',g,'Ball',P(4.75,7.25,.1),V(2.0,.5,2.0),moss,'Grass')
  local sh,el,wr=P(4.8,5.6,-.1),P(5.7,1.4,-1.1),P(5.5,-2.4,-2.8)
  k.seg('Upper arm',g,'Ball',sh,el,2.55,2.55,fur,'SmoothPlastic',{Ext=1.0})
  k.seg('Forearm',g,'Ball',el,wr,2.4,2.6,fur2,'SmoothPlastic',{Ext=1.0})
  k.seg('Elbow tuft',g,'Wedge',P(5.9,1.6,-.4),P(6.3,.8,.9),.4,.7,fur2,'SmoothPlastic')
  k.box('Fist',g,'Ball',P(5.45,-3.0,-3.1),V(2.3,1.9,2.4),skin,'SmoothPlastic')
  for i,dx in ipairs({-.72,-.24,.24,.72})do k.box('Knuckle',g,'Ball',P(5.45+dx,-3.55,-4.05),V(.6,.6,.55),rgb(34,30,32),'SmoothPlastic')end
  local d=(wr-el).Unit
  for i,t in ipairs({.3,.62})do local c=el:Lerp(wr,t)
   k.seg('Vine bracer',g,'Cyl',c-d*.17,c+d*.17,2.75,0,vine,'SmoothPlastic')
   k.seg('Bracer leaf',g,'Wedge',c+P(1.25,0,0)-V(0,0,0),c+P(1.75,.6,.5),.12,.55,leaf,'LeafyGrass',{Up=V(0,0,1)})
  end
 end)
 -- Short, thick legs.
 sides(function(s,side)
  local g=side..'BackLeg'
  k.box('Thigh',g,'Ball',V(s*1.9,.2,1.75),V(2.8,3.4,2.8),fur,'SmoothPlastic')
  k.seg('Shin',g,'Ball',V(s*1.9,-1.0,1.6),V(s*1.95,-3.1,.9),2.0,2.1,fur2,'SmoothPlastic',{Ext=.8})
  k.box('Foot',g,'Ball',V(s*1.95,-3.6,.2),V(1.9,.8,2.8),skin,'SmoothPlastic')
 end)
 return k.Parts
end

function Refined.Specs(stage)local b=Build[stage];return b and b()or nil end

-- Same contract as KeeperUpgradeArt.Build: a 'BeastBody' model whose parts carry RestCFrame/BeastGroup/KeeperEyeGlow.
function Refined.Build(stage)
 local specs=Refined.Specs(stage);if not specs then return nil end
 local rig=Instance.new('Model');rig.Name='BeastBody';rig:SetAttribute('VisualVersion',Refined.Version)
 for _,s in ipairs(specs)do
  local p=Instance.new(s.Shape=='Wedge'and'WedgePart'or'Part')
  p.Name=s.Name;p.Size=s.Size;p.CFrame=s.CFrame
  if s.Shape=='Cyl'then p.Shape=Enum.PartType.Cylinder
  elseif s.Shape=='Ball'then
   if math.abs(s.Size.X-s.Size.Y)<1e-3 and math.abs(s.Size.Y-s.Size.Z)<1e-3 then p.Shape=Enum.PartType.Ball
   else local m=Instance.new('SpecialMesh');m.MeshType=Enum.MeshType.Sphere;m.Parent=p end
  end
  p.Color=Color3.new(table.unpack(s.Color));p.Material=Enum.Material[s.Material]
  p.Transparency=s.Transparency;p.Reflectance=s.Reflectance
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=s.Material~='Neon'
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p:SetAttribute('RestCFrame',p.CFrame);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow)
  p.Parent=rig
 end
 return rig
end
return Refined
