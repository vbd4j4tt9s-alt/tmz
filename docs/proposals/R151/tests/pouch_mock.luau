--!nocheck
-- R151: a mock of the EditableMesh bake route VerityPouch151 uses (AssetService:CreateEditableMeshAsync / CreateDataModelContentAsync /
-- CreateMeshPartAsync, Content.fromUri / fromObject, Enum.CreateContentResult) on the Roblox mock, with switches for every way the real thing can fail.
--   local P=require('./pouch_mock')(W)
--   P.mode = 'ok' | 'denied' (CreateEditableMeshAsync errors: no permission) | 'no_vertices' | 'setcolor_error' | 'color_stuck' (SetColor does nothing: a
--            dark colour survives) | 'content_fails' (CreateDataModelContentAsync does not succeed) | 'meshpart_fails' | 'size_mismatch' (the baked mesh is
--            another size) | 'second_fails' (the 2nd mesh of a template cannot be loaded)
--   P.uris       the Content URIs asked for, in order            P.alive    EditableMeshes created and not yet destroyed (a leak if > 0 when idle)
--   P.created    EditableMeshes created                          P.baked    MeshParts made (P.bakedAlive: not destroyed)
--   P.colorsAtBake  for each CreateDataModelContentAsync: the number of vertex colours that were NOT white (must be 0)   P.vertices  vertices per mesh
return function(W)
 local R=W.R
 local P={mode='ok',uris={},alive=0,created=0,baked=0,bakedAlive=0,colorsAtBake={},vertices=1800,calls=0}
 local AS=W.service('AssetService')
 local function mesh(uri)
  local colors={};for i=1,P.vertices do colors[i]=R.Color3.fromRGB(20+(i*37)%200,15+(i*11)%120,30+(i*53)%220)end -- the print: dark navy, orange, crimps
  local m={_colors=colors,_alpha={},_dead=false}
  for i=1,P.vertices do m._alpha[i]=1 end
  function m:GetVertices()local v={};if P.mode=='no_vertices'then return v end;for i=1,P.vertices do v[i]=i end;return v end
  function m:GetColors()local c={};for i=1,#self._colors do c[i]=i end;return c end
  function m:GetColor(i)return self._colors[i]end
  function m:SetColor(i,c)
   if P.mode=='setcolor_error'then error('EditableMesh:SetColor is not available',2)end
   if P.mode=='color_stuck'and i%7==0 then return end
   self._colors[i]=c
  end
  function m:SetColorAlpha(i,a)self._alpha[i]=a end
  function m:Destroy()if not self._dead then self._dead=true;P.alive-=1 end end
  P.created+=1;P.alive+=1;return m
 end
 function AS.CreateEditableMeshAsync(_,content)
  P.calls+=1
  P.uris[#P.uris+1]=content and content.Uri
  if P.mode=='denied'then error('Failed to load mesh: no permission to read '..tostring(content and content.Uri)..' as an EditableMesh',2)end
  if P.mode=='second_fails'and P.calls>=2 then error('second mesh not available',2)end
  return mesh(content.Uri)
 end
 function AS.CreateDataModelContentAsync(_,content)
  local m=content.Object;local dark=0
  for _,c in ipairs(m._colors)do if not(c.R>.999 and c.G>.999 and c.B>.999)then dark+=1 end end
  P.colorsAtBake[#P.colorsAtBake+1]=dark
  if P.mode=='content_fails'then return R.Enum.CreateContentResult.Failure,nil end
  return R.Enum.CreateContentResult.Success,{__type='Content',Baked=m}
 end
 function AS.CreateMeshPartAsync(_,content)
  if P.mode=='meshpart_fails'then error('CreateMeshPartAsync failed: out of mesh memory',2)end
  local part=R.new('MeshPart');P.baked+=1;P.bakedAlive+=1
  part.MeshSize=R.Vector3.new(1.97,2.06,1.004)*(P.mode=='size_mismatch'and 1.1 or 1) -- (the template's MeshSize is set by the test to its Size)
  part.MeshId=''
  part.Destroying:Connect(function()P.bakedAlive-=1 end) -- (Instance:Destroy fires Destroying once)
  return part
 end
 -- Content / Enum for the module's globals
 W.env.Content={fromUri=function(u)return{__type='Content',Uri=u}end,fromAssetId=function(i)return{__type='Content',Uri='rbxassetid://'..tostring(i)}end,fromObject=function(o)return{__type='Content',Object=o}end}
 function P.reset()P.mode='ok';P.uris={};P.alive=0;P.created=0;P.baked=0;P.bakedAlive=0;P.colorsAtBake={};P.calls=0;P.vertices=1800 end
 return P
end
