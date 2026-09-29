-- Geometry only; never require or parent third-party scripts.
local M={AssetId=12271778963,TemplateName='GardenShovelAsset',DisplayScale=1.6}
local RS=game:GetService('ReplicatedStorage')
local function cleanPart(source)
 local p=source:Clone()
 for _,child in ipairs(p:GetDescendants())do
  if not(child:IsA('DataModelMesh')or child:IsA('SurfaceAppearance')or child:IsA('Decal')or child:IsA('Texture'))then child:Destroy()end
 end
 p.Anchored=false;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Massless=true;p.CastShadow=false
 return p
end
function M.Import()
 local existing=RS:FindFirstChild(M.TemplateName);if existing then return true end
 local loaded=game:GetService('InsertService'):LoadAsset(M.AssetId)
 local result=Instance.new('Model');result.Name=M.TemplateName;local count=0
 for _,part in ipairs(loaded:GetDescendants())do if part:IsA('BasePart')then
  count+=1;if count>80 then loaded:Destroy();result:Destroy();error('Shovel asset has too many parts.')end
  cleanPart(part).Parent=result
 end end
 loaded:Destroy()
 if count==0 then result:Destroy();error('Shovel asset contains no usable geometry.')end
 local cf,size=result:GetBoundingBox();result:ScaleTo(3.7/math.max(size.X,size.Y,size.Z))
 local center=result:GetBoundingBox();result:PivotTo(CFrame.new(0,0,0)*center:Inverse()*result:GetPivot())
 result:SetAttribute('SourceAssetId',M.AssetId);result.Parent=RS;return true
end
function M.AvatarScale(tool)
 local char=tool.Parent;local humanoid=char and char:FindFirstChildOfClass('Humanoid')
 local height=humanoid and humanoid:FindFirstChild('BodyHeightScale')
 if height and height:IsA('NumberValue')then return math.clamp(height.Value,.5,3)end
 local head=char and char:FindFirstChild('Head');local leg=char and(char:FindFirstChild('Left Leg')or char:FindFirstChild('LeftFoot'))
 if head and leg and head:IsA('BasePart')and leg:IsA('BasePart')then return math.clamp((head.Size.Y+leg.Size.Y)/3,.5,3)end
 return 1
end
function M.Build(tool,handle)
 local template=RS:FindFirstChild(M.TemplateName);local model=Instance.new('Model');model.Name='ShovelAppearance';model.Parent=tool
 if template then
  for _,part in ipairs(template:GetChildren())do if part:IsA('BasePart')then local p=cleanPart(part);p.CFrame=handle.CFrame*part.CFrame;p.Parent=model end end
 else
  local function part(name,size,offset,color)
   local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=handle.CFrame*CFrame.new(0,.45,0)*offset;p.Color=color;p.Material=Enum.Material.SmoothPlastic
   p.Anchored=false;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Massless=true;p.CastShadow=false;p.Parent=model
  end
  part('Wooden shaft',Vector3.new(.16,2.25,.16),CFrame.new(0,-.5,0),Color3.fromRGB(139,93,55))
  part('Shovel blade',Vector3.new(.86,.85,.14),CFrame.new(0,-1.88,.08)*CFrame.Angles(-.18,0,0),Color3.fromRGB(136,152,161))
  part('Grip top',Vector3.new(.65,.14,.18),CFrame.new(0,.98,0),Color3.fromRGB(43,58,60))
  for _,x in ipairs({-.25,.25})do part('Grip side',Vector3.new(.13,.4,.16),CFrame.new(x,.78,0),Color3.fromRGB(43,58,60))end
 end
 -- Enlarge both imported and fallback geometry around the hand grip.
 local scale=M.DisplayScale*M.AvatarScale(tool)
 for _,p in ipairs(model:GetChildren())do if p:IsA('BasePart')then
  local at=handle.CFrame:ToObjectSpace(p.CFrame);p.CFrame=handle.CFrame*CFrame.new(at.Position*scale)*at.Rotation;p.Size*=scale
  for _,mesh in ipairs(p:GetChildren())do if mesh:IsA('DataModelMesh')then if mesh:IsA('SpecialMesh')and mesh.MeshType==Enum.MeshType.FileMesh then mesh.Scale*=scale end;mesh.Offset*=scale end end
 end end
 for _,p in ipairs(model:GetChildren())do if p:IsA('BasePart')then local weld=Instance.new('WeldConstraint');weld.Part0=handle;weld.Part1=p;weld.Parent=p end end
 return model
end
return M
