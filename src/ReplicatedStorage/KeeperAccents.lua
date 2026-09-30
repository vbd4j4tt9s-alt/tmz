-- R113: a few client-only accent parts per keeper (biome read + silhouette), moved with the pose groups.
-- They exist only on clients: the server's KeeperContact never sees them, so reach and hits are unchanged.
-- Budget: at most 3 parts per keeper, no collision/query/touch/shadow.
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
 [7]={ -- Storm Colossus: a small storm cloud crown.
  {Group='Head',At=V(-2.8,32.0,.5),Size=V(5.0,2.6,4.5),Shape='Ball',Material='SmoothPlastic',Color=rgb(70,76,92),Transparency=.12,Anim='Drift',Index=0},
  {Group='Head',At=V(2.6,32.3,-.3),Size=V(4.6,2.4,4.2),Shape='Ball',Material='SmoothPlastic',Color=rgb(82,88,106),Transparency=.12,Anim='Drift',Index=1},
  {Group='Head',At=V(0,33.4,.2),Size=V(5.6,3.0,5.0),Shape='Ball',Material='SmoothPlastic',Color=rgb(60,66,82),Transparency=.12,Anim='Drift',Index=2},
 },
}
function A.new(model,stage)
 local specs=A.Specs[stage];if not specs then return nil end
 local folder=Instance.new('Folder');folder.Name='KeeperAccentsLocal'
 local self={Folder=folder,Items={},Stage=stage}
 for i,s in ipairs(specs)do
  local p=Instance.new(s.Shape=='Wedge'and'WedgePart'or'Part');p.Name='KeeperAccent'..i
  if s.Shape=='Ball'then p.Shape=Enum.PartType.Ball end
  p.Size=s.Size;p.Color=s.Color;p.Material=Enum.Material[s.Material];p.Transparency=s.Transparency or 0
  p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=folder
  table.insert(self.Items,{Part=p,Spec=s,Rest=CF(s.At),Hidden=nil})
 end
 folder.Parent=model
 return self
end
-- Appends accent parts/frames to the caller's BulkMoveTo lists.
function A.Pose(self,frames,root,awake,now,hunting,parts,out)
 if not self then return end
 local blend=math.clamp((awake-.55)/.35,0,1)
 for _,item in ipairs(self.Items)do
  local s=item.Spec;local group=frames[s.Group]
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
