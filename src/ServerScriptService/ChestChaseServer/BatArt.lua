-- R42. Appearance only. Imported code, remotes, constraints and effects are never copied.
local C=require(game:GetService('ReplicatedStorage'):WaitForChild('BatConfig'))
local M={TemplateName='ChestChaseBatAppearance',Version=42}
local function finish(tool)
 tool.Name='Bat';tool.ToolTip='Swing to disarm';tool.RequiresHandle=true;tool.CanBeDropped=false
 tool.ManualActivationOnly=false;tool:SetAttribute('ChestChaseBat',true)
 for _,part in ipairs(tool:GetChildren())do if part:IsA('BasePart')then
  part.Anchored=false;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Massless=true
  if part.Name~='Handle'then
   local weld=Instance.new('WeldConstraint');weld.Part0=tool.Handle;weld.Part1=part;weld.Parent=part
  end
 end end
 return tool
end
local function cleanPart(source)
 local part=source:Clone();part:ClearAllChildren()
 for _,child in ipairs(source:GetChildren())do
  if child:IsA('DataModelMesh')or child:IsA('SurfaceAppearance')or child:IsA('Decal')or child:IsA('Texture')then
   local copy=child:Clone();copy:ClearAllChildren();copy.Parent=part
  end
 end
 return part
end
function M.Sanitize(source,assetId)
 local toolSource=source:IsA('Tool')and source or source:FindFirstChildWhichIsA('Tool',true)
 local root=toolSource or source;local parts={}
 if root:IsA('BasePart')then table.insert(parts,root)end
 for _,n in ipairs(root:GetDescendants())do if n:IsA('BasePart')then table.insert(parts,n)end end
 assert(#parts>0 and #parts<=96,'Bat asset must contain 1–96 appearance parts.')
 local originalHandle=toolSource and toolSource:FindFirstChild('Handle')
 local frame,size
 if root:IsA('Model')then frame,size=root:GetBoundingBox()
 else
  local box=Instance.new('Model')
  for _,p in ipairs(parts)do cleanPart(p).Parent=box end
  frame,size=box:GetBoundingBox();box:Destroy()
 end
 local longest=math.max(size.X,size.Y,size.Z)
 assert(longest>.01 and longest<10000,'Invalid bat bounds.')
 local ratio=4.6/longest
 local basis=frame
 if originalHandle and originalHandle:IsA('BasePart')then basis=originalHandle.CFrame
 elseif size.X>=size.Y and size.X>=size.Z then basis=frame*CFrame.Angles(0,0,math.pi/2)
 elseif size.Z>=size.Y then basis=frame*CFrame.Angles(math.pi/2,0,0)end
 local tool=Instance.new('Tool')
 local handle=Instance.new('Part');handle.Name='Handle';handle.Size=Vector3.new(.25,.6,.25);handle.Transparency=1;handle.CFrame=CFrame.new();handle.Parent=tool
 for i,p in ipairs(parts)do
  local copy=cleanPart(p);copy.Name='BatVisual'..i
  local relative=basis:ToObjectSpace(p.CFrame)
  local lift=originalHandle and Vector3.zero or Vector3.new(0,1.9,0)
  copy.CFrame=CFrame.new(relative.Position*ratio+lift)*relative.Rotation;copy.Size=p.Size*ratio
  for _,mesh in ipairs(copy:GetChildren())do if mesh:IsA('SpecialMesh')and mesh.MeshType==Enum.MeshType.FileMesh then mesh.Scale*=ratio;mesh.Offset*=ratio end end
  copy.Parent=tool
 end
 tool.Grip=toolSource and toolSource.Grip or CFrame.new()
 if toolSource then tool.Grip=CFrame.new(tool.Grip.Position*ratio)*tool.Grip.Rotation end
 tool:SetAttribute('BatAppearanceAssetId',assetId);tool:SetAttribute('BatAppearanceVersion',M.Version)
 return finish(tool)
end
function M.Fallback()
 local tool=Instance.new('Tool');tool.Grip=CFrame.new()
 local handle=Instance.new('Part');handle.Name='Handle';handle.Size=Vector3.new(.28,.9,.28);handle.Color=Color3.fromRGB(43,39,37);handle.CFrame=CFrame.new();handle.Parent=tool
 local shapes={{'Neck',.34,1.1,.9},{'Barrel',.64,2.5,2.55},{'Knob',.43,.14,-.5}}
 for _,s in ipairs(shapes)do
  local p=Instance.new('Part');p.Name=s[1];p.Shape=Enum.PartType.Cylinder;p.Size=Vector3.new(s[3],s[2],s[2]);p.CFrame=CFrame.new(0,s[4],0)*CFrame.Angles(0,0,math.pi/2)
  p.Color=Color3.fromRGB(178,139,91);p.Material=Enum.Material.Wood;p.Parent=tool
 end
 tool:SetAttribute('BatTemporaryAppearance',true)
 return finish(tool)
end
-- Scale issued copies only: existing imported templates remain compatible and reversible.
local function enlarge(tool)
 local scale=C.AppearanceScale;local origin=tool.Handle.CFrame
 local welds={}
 for _,item in ipairs(tool:GetDescendants())do if item:IsA('WeldConstraint')then
  table.insert(welds,{Item=item,Enabled=item.Enabled});item.Enabled=false
 end end
 for _,part in ipairs(tool:GetChildren())do if part:IsA('BasePart')then
  local relative=origin:ToObjectSpace(part.CFrame)
  part.Size*=scale;part.CFrame=origin*CFrame.new(relative.Position*scale)*relative.Rotation
  for _,mesh in ipairs(part:GetChildren())do if mesh:IsA('SpecialMesh')and mesh.MeshType==Enum.MeshType.FileMesh then mesh.Scale*=scale;mesh.Offset*=scale end end
 end end
 tool.Grip=CFrame.new(tool.Grip.Position*scale)*tool.Grip.Rotation
 for _,entry in ipairs(welds)do entry.Item.Enabled=entry.Enabled end
 tool:SetAttribute('BatIssuedScale',scale);return tool
end
function M.Create()
 local template=game:GetService('ServerStorage'):FindFirstChild(M.TemplateName)
 if template and template:IsA('Tool')and template:GetAttribute('BatAppearanceVersion')==M.Version and template:FindFirstChild('Handle')then
  local copy=template:Clone();copy.Name='Bat';return enlarge(copy)
 end
 return enlarge(M.Fallback())
end
return M
