-- R59: a small pooled circuit of lightning follows the Colossus torso and arms.
local M={};local V=Vector3.new
local paths={
 {'Body',V(0,27,-4.8),V(.2,13.5,-4.8)},
 {'Body',V(-9,22.5,-4.6),V(9,22.5,-4.6)},
 {'LeftArm',V(10,21,-3.5),V(11,8,-3.5)},
 {'RightArm',V(-10,21,-3.5),V(-11,8,-3.5)},
}
-- R152: the baked stone colossus (variant 'R152') is broader: the same four arcs on its front, down the chest crack, across the chest
-- and from each shoulder rock down to the fist.
M.Paths152={
 {'Body',V(0,27,-5.95),V(.2,13.5,-5.95)},
 {'Body',V(-9,22.5,-5.9),V(9,22.5,-5.9)},
 {'LeftArm',V(12,21,-5.1),V(12.5,8,-7.6)},
 {'RightArm',V(-12,21,-5.1),V(-12.5,8,-7.6)},
}
function M.New(parent,variant)
 local self={Paths=variant=='R152' and M.Paths152 or paths};local folder=Instance.new('Folder');folder.Name='ColossusSurges';folder.Parent=parent;self.Folder=folder;self.Parts={}
 for i=1,#self.Paths*4 do
  local p=Instance.new('Part');p.Name='Electrical surge';p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Material=Enum.Material.Neon;p.Color=i%3==0 and Color3.fromRGB(225,244,255)or Color3.fromRGB(139,171,255);p.Transparency=1;p.Size=V(.12,.12,.1);p.Parent=folder;self.Parts[i]=p
 end
 return self
end
function M.Step(self,root,frames,t,strength)
 local on=(t%2.6)<.52
 for j,path in ipairs(self.Paths)do
  local pose=root*(frames[path[1]]or frames.Body);local previous=pose*path[2]
  for i=1,4 do
   local point=path[2]:Lerp(path[3],i/4)
   if i<4 then point+=V(math.sin(t*18+i*7+j)*.75,math.cos(t*13+i*3)*.25,-.12)end
   point=pose*point;local p=self.Parts[(j-1)*4+i]
   p.Size=V(.13,.13,(point-previous).Magnitude);p.CFrame=CFrame.lookAt((point+previous)*.5,point)
   p.Transparency=on and 1-.9*(strength or 1)or 1;previous=point
  end
 end
end
function M.Destroy(self)self.Folder:Destroy()end
return M
