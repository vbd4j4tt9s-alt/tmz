-- R54. The entire pack stays ahead of a stable, root-relative body clearance plane.
local Layout={}
function Layout.Calculate(character,bounds,visual)
 local torso=character:FindFirstChild('UpperTorso')or character:FindFirstChild('Torso')
 local root=character:FindFirstChild('HumanoidRootPart')
 if not torso or not root then return nil end
 local avatar=math.clamp(torso.Size.X/2,.65,2)*.86
 local chestHeight=torso.Name=='UpperTorso'and .7*avatar or 0
 -- Reserve room for the standard run's torso lean without making the bag bob.
 local front=math.max(root.Size.Z*.5,torso.Size.Z*.5+torso.Size.Y*.5*math.sin(math.rad(30)))+.12*avatar
 -- The default R15 run also pitches the head ahead of the chest.
 local gap=.42*avatar
 local backZ=-front-gap
 if torso.Name=='Torso'then
  local width=math.min(.78*avatar,.73*(visual or 1));local gripY=chestHeight-.30*avatar
  -- R6 has rigid one-piece arms. Put the pack where their ends can meet its near face.
  for _,j in ipairs(character:GetDescendants())do
   local p1,c0,c1
   if j:IsA('Motor6D')then p1=j.Part1;c0=j.C0;c1=j.C1
   elseif j:IsA('AnimationConstraint')and j.Attachment0 and j.Attachment1 then p1=j.Attachment1.Parent;c0=j.Attachment0.CFrame;c1=j.Attachment1.CFrame end
   if p1 and(p1.Name=='Left Arm'or p1.Name=='Right Arm')and c0 and c1 then
    local length=(Vector3.new(0,-p1.Size.Y*.5,0)-c1.Position).Magnitude
    local dy=c0.Position.Y-gripY;local dx=math.abs(c0.Position.X)-width
    local reach=math.sqrt(math.max(0,length*length-dy*dy-dx*dx))
    backZ=math.min(backZ,c0.Position.Z-reach-.18*avatar)
   end
  end
 end
 local maxZ=bounds.MaxZ or bounds.Radius
 local y=math.max(-.20*avatar,-avatar-bounds.MinY)+chestHeight
 local offset=CFrame.new(0,y,backZ-maxZ)
 return root,root.CFrame*offset,avatar,{Offset=offset,BackZ=backZ,GripY=chestHeight-.30*avatar,Front=front}
end
function Layout.Grip(frame,anchor,avatar,visual,info,sign)
 local width=math.min(.78*avatar,.73*visual)
 -- Grip the near face, even for a 25x pack: never aim the arms at its distant centre.
 local target=anchor.CFrame*CFrame.new(sign*width,info.GripY,info.BackZ+.18*avatar)
 return frame:ToObjectSpace(target)
end
return Layout
