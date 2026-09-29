-- R86: invisible structural depth below walkable floors; visible elevations stay intact.
local F={Thickness=32}
local V,CF=Vector3.new,CFrame.new
local caches=setmetatable({},{__mode='k'})
function F.IsFloor(p)
 return p:IsA('BasePart')and(p.Name=='LobbyFloor'or p.Name:match('^BiomeGround_%d')~=nil or(p.Name=='Pad'and p.Size.X>=60 and p.Size.Z>=60))and p.CFrame.UpVector.Y>.99
end
function F.Apply(map)
 local old=map:FindFirstChild('FloorSupport86');if old then old:Destroy()end
 local model=Instance.new('Model');model.Name='FloorSupport86';model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 local floors={}
 for _,p in ipairs(map:GetDescendants())do if F.IsFloor(p)then
  floors[#floors+1]=p
  local cols,rows=math.ceil(p.Size.X/2000),math.ceil(p.Size.Z/2000)
  for x=1,cols do for z=1,rows do
   local support=Instance.new('Part');support.Name='Support_'..p.Name
   support.Size=V(p.Size.X/cols,F.Thickness,p.Size.Z/rows)
   support.CFrame=p.CFrame*CF((x-(cols+1)/2)*support.Size.X,p.Size.Y/2-F.Thickness/2-.03,(z-(rows+1)/2)*support.Size.Z)
   support.Anchored=true;support.Transparency=1;support.CanCollide=true;support.CanTouch=false;support.CanQuery=true;support.CastShadow=false
   support.CollisionGroup=p.CollisionGroup;support.Parent=model
  end end
 end end
 for _,p in ipairs(map:GetDescendants())do if p:IsA('BasePart')and p.Name:match('^DirtPlot_%d')and p.CFrame.UpVector.Y>.99 then floors[#floors+1]=p end end
 model.Parent=map
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances=floors;params.IgnoreWater=true
 caches[map]=params;return model
end
function F.Recover(character,humanoid,root,map)
 map=map or workspace:FindFirstChild('ChestChaseMap')
 local params=map and caches[map];if not params or not root.Parent then return false end
 local hit=workspace:Raycast(root.Position+V(0,64,0),V(0,-112,0),params)
 if not hit or hit.Normal.Y<.8 then return false end
 local height=humanoid.HipHeight+root.Size.Y/2
 if humanoid.RigType==Enum.HumanoidRigType.R6 then
  local leg=character:FindFirstChild('Left Leg');height+=(leg and leg.Size.Y or 2)
 end
 local minimum=hit.Position.Y+math.max(2,height)+.30
 if root.Position.Y>minimum+2 then return false end -- never pull airborne players down
 local at=V(root.Position.X,math.max(root.Position.Y,minimum),root.Position.Z)
 local forward=V(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
 if forward.Magnitude<.001 then forward=V(0,0,-1)end
 local frame=CFrame.lookAt(at,at+forward)
 character:PivotTo(frame*root.CFrame:Inverse()*character:GetPivot())
 root.AssemblyLinearVelocity=V(0,math.max(0,root.AssemblyLinearVelocity.Y),0);root.AssemblyAngularVelocity=V()
 return true
end
return F
