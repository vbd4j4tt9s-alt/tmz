-- Each approved mesh is baked once per server; every plant clones its static template.
-- No mesh generation runs on clients, and no asset upload or network request is exposed to players.
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local AssetService=game:GetService('AssetService')
local Meshes={};local building={};local failed={};local index
local folderName='ApprovedPlantMeshTemplates'
local function folder()
 local f=RS:FindFirstChild(folderName)
 if not f and RunService:IsServer()then f=Instance.new('Folder');f.Name=folderName;f:SetAttribute('PlantRevision',15);f.Parent=RS end
 return f
end
local function failure(key,message)
 local f=folder();local errors=f:FindFirstChild('Failures')
 if not errors then errors=Instance.new('Folder');errors.Name='Failures';errors.Parent=f end
 local value=errors:FindFirstChild(key)
 if not value then value=Instance.new('StringValue');value.Name=key end
 value.Value=message;value.Parent=errors
end
-- Client lookups never yield, bake meshes or mistake pending replication for a failure.
function Meshes.Status(key,neutral)
 if neutral then key..='_Neutral'end
 local f=folder();if not f then return 'Loading' end
 if f:FindFirstChild(key)then return 'Ready' end
 local errors=f:FindFirstChild('Failures');local value=errors and errors:FindFirstChild(key)
 if value then return 'Failed',value.Value end
 return 'Loading'
end
local function build(key)
 local f=folder();local existing=f:FindFirstChild(key);if existing then return existing end
 while building[key]do task.wait();existing=f:FindFirstChild(key);if existing then return existing end end
 assert(not failed[key],failed[key]);building[key]=true
 local editable,part
 local ok,why=xpcall(function()
  local storage=game:GetService('ServerStorage')
  index=index or require(storage:WaitForChild('ApprovedPlantMeshIndex'))
  local baseKey=key:gsub('_Neutral$','');local neutral=baseKey~=key
  local data=require(storage:WaitForChild(assert(index[baseKey],'Unknown approved mesh: '..key)))
  editable=assert(AssetService:CreateEditableMesh(),'Mesh memory unavailable while preparing '..key)
  local vertices,normals,colors={},{},{}
  for i,v in ipairs(data.Vertices)do
   vertices[i]=editable:AddVertex(Vector3.new(table.unpack(v)))
   normals[i]=editable:AddNormal(Vector3.new(table.unpack(data.Normals[i])))
   colors[i]=editable:AddColor(neutral and Color3.new(1,1,1)or Color3.new(table.unpack(data.Colors[i])),1)
   if i%192==0 then task.wait()end
  end
  for i,face in ipairs(data.Faces)do
   local a,b,c=face[1],face[2],face[3];local faceId=editable:AddTriangle(vertices[a],vertices[b],vertices[c])
   editable:SetFaceNormals(faceId,{normals[a],normals[b],normals[c]})
   editable:SetFaceColors(faceId,{colors[a],colors[b],colors[c]})
   if i%256==0 then task.wait()end
  end
  local result,content=AssetService:CreateDataModelContentAsync(Content.fromObject(editable))
  assert(result==Enum.CreateContentResult.Success,'Could not bake approved mesh '..key..': '..tostring(result))
  part=AssetService:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity.Hull,RenderFidelity=Enum.RenderFidelity.Precise})
  part.Name=key;part.Size=Vector3.one;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  part:SetAttribute('ApprovedMesh',key);part.Parent=f
 end,debug.traceback)
 if editable then editable:Destroy()end
 building[key]=nil
 if not ok then
  if part then part:Destroy()end
  failed[key]='Could not prepare approved plant mesh '..key..': '..tostring(why)
  failure(key,failed[key])
  error(failed[key])
 end
 return part
end
function Meshes.Get(key,neutral)
 if neutral then key..='_Neutral'end
 local f=folder();local part=f and f:FindFirstChild(key)
 if part then return part end
 if RunService:IsServer()then return build(key)end
 error('Approved plant mesh is still loading: '..key)
end
function Meshes.Prepare()
 assert(RunService:IsServer(),'Mesh preparation is server-only.')
 local storage=game:GetService('ServerStorage');index=index or require(storage:WaitForChild('ApprovedPlantMeshIndex'))
 local keys={};for key in pairs(index)do table.insert(keys,key)end;table.sort(keys)
 local errors={};local f=folder();f:SetAttribute('Ready',false);f:SetAttribute('PreparationFinished',false)
 -- One failed asset must not prevent later plants from ever becoming available.
 -- Normal templates go first; neutral templates also need preparing for client-only fruit mutations.
 for _,neutral in ipairs({false,true})do for _,key in ipairs(keys)do
  local okay,why=pcall(Meshes.Get,key,neutral)
  if not okay then table.insert(errors,tostring(why))end
  task.wait()
 end end
 f:SetAttribute('FailureCount',#errors);f:SetAttribute('PreparationFinished',true);f:SetAttribute('Ready',#errors==0)
 return #errors==0,errors
end
return Meshes
