-- R113: a few client-only accent parts per keeper (biome read + silhouette), moved with the pose groups.
-- They exist only on clients: the server's KeeperContact never sees them, so reach and hits are unchanged.
-- Budget: at most 5 parts per keeper, no collision/query/touch/shadow.
-- R149 (owner: "add gear to the snow tiger, like silver sapphire gear"): the Snow keeper (stage 3, Ice Fang, the tiger) also wears
-- silver-and-sapphire armour (A.Gear below, 38 parts). It is the same kind of part as an accent: client only, anchored, never
-- collidable / queryable / touchable, moved every pose frame with its limb's group frame (root*group*rest), so it follows the
-- gait, the sleep curl, the wake roar, the strike and the fling exactly like the mesh under it and changes no hit shape.
-- Detail pieces (studs, facets) are hidden beyond DetailRange studs and in low graphics, and are not moved while hidden.
local A={}
local V,CF=Vector3.new,CFrame.new
local function rgb(r,g,b)return Color3.fromRGB(r,g,b)end
-- Group, rest position (rig space), size, shape, material, colour, transparency, animation kind.
A.Specs={
 [1]={ -- Timber Golem: glowing heartwood rune and shelf mushrooms (hidden while it is a tree).
  {Group='Body',At=V(0,6.4,-2.62),Size=V(1.2,1.9,.25),Material='Neon',Color=rgb(130,245,164),Tree=true},
  {Group='Body',At=V(2.9,10.25,-1.2),Size=V(1.6,.55,1.6),Shape='Ball',Material='SmoothPlastic',Color=rgb(236,148,62),Tree=true},
  {Group='Body',At=V(3.4,9.85,.4),Size=V(1.1,.4,1.1),Shape='Ball',Material='SmoothPlastic',Color=rgb(247,190,96),Tree=true},
 },
 [2]={ -- Sand Snake: tail rattle, buzzes while it hunts.
  {Group='Segment9',At=V(-5.40,-3.40,27.20),Size=V(.95,.72,.72),Shape='Ball',Material='Sandstone',Color=rgb(214,186,132),Anim='Rattle'},
  {Group='Segment9',At=V(-5.58,-3.34,27.76),Size=V(.80,.62,.62),Shape='Ball',Material='Sandstone',Color=rgb(196,164,112),Anim='Rattle'},
  {Group='Segment9',At=V(-5.74,-3.30,28.26),Size=V(.62,.50,.50),Shape='Ball',Material='Sandstone',Color=rgb(178,146,98),Anim='Rattle'},
 },
 [3]={ -- Ice Fang: ice shards along the spine.
  {Group='Body',At=V(0,4.95,-.4),Size=V(.36,1.5,1.7),Shape='Wedge',Material='Ice',Color=rgb(176,222,255),Transparency=.15},
  {Group='Body',At=V(0,5.05,2.8),Size=V(.40,1.8,1.9),Shape='Wedge',Material='Ice',Color=rgb(190,232,255),Transparency=.15},
  {Group='Body',At=V(0,4.85,6.0),Size=V(.34,1.3,1.6),Shape='Wedge',Material='Ice',Color=rgb(176,222,255),Transparency=.15},
 },
 [5]={ -- Crystal Knight: three shards orbit the helm.
  {Group='Head',At=V(0,28.2,0),Size=V(.8,2.3,.8),Material='Neon',Color=rgb(206,164,255),Anim='Orbit',Index=0},
  {Group='Head',At=V(0,28.2,0),Size=V(.7,1.9,.7),Material='Neon',Color=rgb(170,128,236),Anim='Orbit',Index=1},
  {Group='Head',At=V(0,28.2,0),Size=V(.6,1.6,.6),Material='Neon',Color=rgb(226,196,255),Anim='Orbit',Index=2},
 },
 [7]={ -- Storm Colossus: a storm cloud crown (R114: about twice as big, five puffs, owner request).
  {Group='Head',At=V(-5.0,33.4,.6),Size=V(8.6,4.6,7.6),Shape='Ball',Material='SmoothPlastic',Color=rgb(70,76,92),Transparency=.12,Anim='Drift',Index=0},
  {Group='Head',At=V(4.8,33.7,-.4),Size=V(8.0,4.4,7.2),Shape='Ball',Material='SmoothPlastic',Color=rgb(82,88,106),Transparency=.12,Anim='Drift',Index=1},
  {Group='Head',At=V(0,35.4,.2),Size=V(10.0,5.4,8.8),Shape='Ball',Material='SmoothPlastic',Color=rgb(60,66,82),Transparency=.12,Anim='Drift',Index=2},
  {Group='Head',At=V(-2.2,33.2,-3.4),Size=V(6.4,3.6,5.6),Shape='Ball',Material='SmoothPlastic',Color=rgb(76,82,98),Transparency=.12,Anim='Drift',Index=3},
  {Group='Head',At=V(2.4,33.4,3.6),Size=V(6.8,3.6,6.0),Shape='Ball',Material='SmoothPlastic',Color=rgb(66,72,88),Transparency=.12,Anim='Drift',Index=4},
 },
}
-- R149 snow tiger gear. Rig space = the keeper's root space (head toward -Z), fitted to the tiger's mesh hulls (KeeperRigConfig
-- FloorSamples / Bounds: skull top 5.85, back top 4.5, front legs x +-1.2..3.3, back legs z 8..11.5, tail z 11.5..22).
-- Fields as for A.Specs plus: Name, Rot (degrees, CFrame.Angles order), Reflectance, Detail (hidden when far / low graphics).
local SILVER,SILVER_DK=rgb(200,205,215),rgb(132,142,160)
local SAPPHIRE,FACET=rgb(30,80,200),rgb(90,150,255)
local function tigerGear()
 local g={}
 local function plate(name,group,at,size,rot,dark)
  g[#g+1]={Name=name,Group=group,At=at,Size=size,Rot=rot,Material='Metal',Color=dark and SILVER_DK or SILVER,Reflectance=dark and .18 or .26,Gear=true}
 end
 -- A sapphire: a glassy deep-blue body (ball or cut block) ...
 local function stone(name,group,at,size,rot,ball,detail)
  g[#g+1]={Name=name,Group=group,At=at,Size=size,Rot=rot,Shape=ball and 'Ball'or nil,Material='Glass',Color=SAPPHIRE,Transparency=.08,Reflectance=.2,Gear=true,Detail=detail}
 end
 -- ... and a lighter glowing facet set on it.
 local function facet(name,group,at,size,rot)
  g[#g+1]={Name=name,Group=group,At=at,Size=size,Rot=rot,Material='Neon',Color=FACET,Transparency=.25,Gear=true,Detail=true}
 end
 -- Helm: two hinged crown plates over the skull, a sapphire between the brows, brow blades and a chin guard on the jaw.
 plate('HelmFront','Head',V(0,5.33,-8.32),V(2.8,.3,2.1),V(-33.8,0,0))
 plate('HelmRear','Head',V(0,5.58,-6.3),V(3.2,.3,2.3),V(24.4,0,0))
 stone('BrowGem','Head',V(0,5.12,-9.2),V(1.3,.7,1.3),V(-33.8,45,0))
 facet('BrowGemFacet','Head',V(0,5.42,-9.42),V(.8,.5,.8),V(-33.8,0,0))
 plate('ChinGuard','Jaw',V(0,1.32,-8.65),V(2.4,.24,2.7),V(0,0,0),true)
 -- Collar behind the head: a top plate, two shoulder bevels, three sapphire studs.
 plate('CollarTop','Body',V(0,4.61,-3.1),V(3.0,.3,1.1),V(0,0,0))
 stone('CollarStud','Body',V(0,4.95,-3.1),V(.75,.75,.75),nil,true,true)
 -- Back: three saddle plates (the ice spines grow through them), two flank plates and the large sapphire between spines 1 and 2.
 plate('SaddleA','Body',V(0,4.55,-.175),V(2.7,.28,4.05),V(2.7,0,0))
 plate('SaddleB','Body',V(0,4.4,3.475),V(2.7,.28,2.95),V(2.7,0,0))
 plate('SaddleC','Body',V(0,4.23,6.45),V(2.7,.28,2.7),V(2.7,0,0))
 stone('SaddleGem','Body',V(0,5.0,1.15),V(1.45,1.0,1.45),V(0,45,0))
 facet('SaddleGemFacet','Body',V(0,5.52,1.15),V(.85,.55,.85),V(0,0,0))
 for _,side in ipairs({-1,1})do
  local tag=side<0 and'L'or'R';local x=side
  plate('Flank'..tag,'Body',V(1.95*x,4.33,2.8),V(1.3,.26,9.6),V(2.7,0,-25*x),true)
  plate('CollarBevel'..tag,'Body',V(2.1*x,4.33,-3.1),V(1.2,.28,1.1),V(0,0,-30*x),true)
  stone('CollarBevelStud'..tag,'Body',V(2.23*x,4.6,-3.1),V(.65,.65,.65),nil,true,true)
  -- Brow blade and cheek guard (with a sapphire stud) on the head.
  plate('BrowBlade'..tag,'Head',V(1.95*x,5.0,-8.45),V(1.1,.26,2.0),V(-34,0,-20*x),true)
  plate('CheekGuard'..tag,'Head',V(2.77*x,3.0,-7.7),V(.28,2.1,2.5),V(0,9*x,0))
  stone('CheekStud'..tag,'Head',V(3.0*x,3.0,-7.7),V(.7,.7,.7),nil,true,true)
  -- Shoulder pauldron riding the front leg, a bracer above each paw, a sapphire stud on each.
  plate('Pauldron'..tag,(side<0 and'Left'or'Right')..'FrontLeg',V(3.3*x,2.0,-2.7),V(.3,2.4,2.6),V(0,0,10*x))
  stone('PauldronStud'..tag,(side<0 and'Left'or'Right')..'FrontLeg',V(3.66*x,2.0,-2.7),V(.8,.8,.8),nil,true,true)
  plate('FrontCuff'..tag,(side<0 and'Left'or'Right')..'FrontLeg',V(2.255*x,-2.55,-3.5),V(2.2,.7,3.5),V(15,0,0),true)
  stone('FrontCuffStud'..tag,(side<0 and'Left'or'Right')..'FrontLeg',V(3.42*x,-2.55,-3.5),V(.75,.75,.75),nil,true,true)
  plate('BackCuff'..tag,(side<0 and'Left'or'Right')..'BackLeg',V(2.33*x,-2.55,9.91),V(2.25,.7,3.4),V(-4,0,0),true)
  stone('BackCuffStud'..tag,(side<0 and'Left'or'Right')..'BackLeg',V(3.52*x,-2.55,9.91),V(.75,.75,.75),nil,true,true)
 end
 -- Tail: a silver ring round the tail's root (a cylinder along the tail, which leans toward +X) with a sapphire on top.
 g[#g+1]={Name='TailRing',Group='Tail',At=V(.52,1.5,13.2),Size=V(.7,2.3,2.3),Rot=V(0,-73,0),Shape='Cylinder',Material='Metal',Color=SILVER_DK,Reflectance=.18,Gear=true}
 stone('TailRingStud','Tail',V(.52,2.66,13.2),V(.8,.8,.8),nil,true,true)
 return g
end
A.Gear={[3]=tigerGear()}
-- The rig length the gear was fitted to (K100_3_Body_01, Z). If the keeper's rig is built larger or smaller (rig scaled), the gear
-- is scaled by the same factor: positions and sizes both, about the rig origin.
A.ScaleRef={[3]=16.7}
A.DetailRange=140
local function rigScale(model,stage)
 local ref=A.ScaleRef[stage];if not ref then return 1 end
 local rig=model:FindFirstChild('BeastBody');if not rig then return 1 end
 local longest=0
 for _,p in ipairs(rig:GetChildren())do
  if p:IsA('BasePart')and p:GetAttribute('BeastGroup')=='Body'then longest=math.max(longest,p.Size.Z)end
 end
 if longest<=0 then return 1 end
 local k=longest/ref;if math.abs(k-1)<.02 then return 1 end
 return math.clamp(k,.25,8)
end
function A.new(model,stage)
 local specs,gear=A.Specs[stage],A.Gear[stage]
 if not specs and not gear then return nil end
 local folder=Instance.new('Folder');folder.Name='KeeperAccentsLocal'
 local k=rigScale(model,stage)
 local self={Folder=folder,Items={},Stage=stage,Scale=k}
 local list={}
 for _,s in ipairs(specs or{})do table.insert(list,s)end
 for _,s in ipairs(gear or{})do table.insert(list,s)end
 for i,s in ipairs(list)do
  local p=Instance.new(s.Shape=='Wedge'and'WedgePart'or'Part');p.Name=s.Gear and('KeeperGear_'..s.Name)or('KeeperAccent'..i)
  if s.Shape=='Ball'then p.Shape=Enum.PartType.Ball elseif s.Shape=='Cylinder'then p.Shape=Enum.PartType.Cylinder end
  p.Size=k==1 and s.Size or s.Size*k;p.Color=s.Color;p.Material=Enum.Material[s.Material];p.Transparency=s.Transparency or 0
  if s.Reflectance then p.Reflectance=s.Reflectance end
  p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  if s.Gear then p.Massless=true;p:SetAttribute('KeeperGear',true)end
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=folder
  local rest=CF(k==1 and s.At or s.At*k)
  if s.Rot then rest=rest*CFrame.Angles(math.rad(s.Rot.X),math.rad(s.Rot.Y),math.rad(s.Rot.Z))end
  table.insert(self.Items,{Part=p,Spec=s,Rest=rest,Hidden=nil})
  if s.Detail then self.HasDetail=true end
 end
 folder.Parent=model
 return self
end
-- Appends accent parts/frames to the caller's BulkMoveTo lists. distance (camera to keeper) and low (low graphics) are optional:
-- beyond DetailRange (15% hysteresis) or in low graphics the Detail pieces are hidden and skipped.
function A.Pose(self,frames,root,awake,now,hunting,parts,out,distance,low)
 if not self then return end
 local blend=math.clamp((awake-.55)/.35,0,1)
 local detail=true
 if self.HasDetail then
  if low then detail=false
  elseif distance then detail=distance<=(self.DetailOn and A.DetailRange*1.15 or A.DetailRange)end
  self.DetailOn=detail
 end
 for _,item in ipairs(self.Items)do
  local s=item.Spec;local group=frames[s.Group]
  if s.Detail then
   if not detail then
    if not item.Off then item.Part.LocalTransparencyModifier=1;item.Off=true end
    continue
   elseif item.Off then item.Part.LocalTransparencyModifier=0;item.Off=false end
  end
  if group and item.Part.Parent then
   local rest=item.Rest
   if s.Anim=='Rattle'then
    local buzz=hunting and math.sin(now*70)*.22 or math.sin(now*2)*.03*awake
    rest=CF(-5.0,-3.6,26.6)*CFrame.Angles(0,buzz,buzz*.5)*CF(5.0,3.6,-26.6)*rest
   elseif s.Anim=='Orbit'then
    local a=now*(.9+.9*awake)+s.Index*math.pi*2/3;local radius=4.6+.4*math.sin(now*1.7+s.Index)
    rest=CF(math.cos(a)*radius,28.2+math.sin(now*2.1+s.Index*2)*.45-1.2*(1-awake),math.sin(a)*radius)*CFrame.Angles(0,-a,.25)
   elseif s.Anim=='Drift'then
    local w=now*.6+s.Index*2.1
    rest=CF(math.sin(w)*.35,math.sin(w*1.3)*.2,math.cos(w)*.3)*rest
   end
   table.insert(parts,item.Part);table.insert(out,root*group*rest)
   if s.Tree then
    local hide=1-blend
    if item.Hidden~=hide then item.Part.LocalTransparencyModifier=hide;item.Hidden=hide end
   end
  end
 end
end
function A.Destroy(self)if self then self.Folder:Destroy()end end
return A
