--!nocheck
-- R152 keeper meshes on the Roblox mock: the AssetService EditableMesh -> CreateDataModelContentAsync -> CreateMeshPartAsync route (as in the
-- R149 fruit_mesh_mock), recorded so a test can read exactly what was baked, and how many EditableMeshes are still alive.
--   install(W, opts)  opts.Missing = true: no CreateEditableMesh at all (an old engine); opts.Throw = true: CreateEditableMesh errors (Game
--                     Settings > Security > "Allow Mesh / Image APIs" off); opts.FailAt = n: the n-th CreateEditableMesh returns nil (no mesh
--                     memory); opts.ContentFail = n: the n-th CreateDataModelContentAsync reports Failure.
-- log: Calls, Editables (made), Destroyed, Alive(), Contents (per baked mesh: V, N, C, F, FN, FC), Parts (MeshParts made), Yields (task.wait calls).
local M={}
function M.install(W,opts)
 opts=opts or{};local R=W.R;local AS=W.service('AssetService')
 local log={Editables=0,Destroyed=0,Contents={},Parts={},Calls=0,Yields=0,Live={}}
 function log.Alive()local n=0;for e in pairs(log.Live)do if not e.Destroyed then n+=1 end end;return n end
 M.log=log
 W.env.task=setmetatable({wait=function(...)log.Yields+=1;return R.task.wait(...)end},{__index=R.task})
 AS.CreateEditableMesh=nil
 if not opts.Missing then
  AS.CreateEditableMesh=function()
   log.Calls+=1
   if opts.Throw then error('Failed to create EditableMesh: this experience does not allow mesh and image APIs',2)end
   if opts.FailAt==log.Calls then return nil end
   log.Editables+=1
   local e={V={},N={},C={},F={},FN={},FC={},Destroyed=false}
   function e.AddVertex(self,p)assert(not self.Destroyed,'used after Destroy');table.insert(self.V,{p.X,p.Y,p.Z});return #self.V end
   function e.AddNormal(self,n)table.insert(self.N,{n.X,n.Y,n.Z});return #self.N end
   function e.AddColor(self,c,a)assert(c.R>=0 and c.R<=1 and c.G>=0 and c.G<=1 and c.B>=0 and c.B<=1,'colour out of range');table.insert(self.C,{c.R,c.G,c.B,a});return #self.C end
   function e.AddTriangle(self,a,b,c)assert(self.V[a]and self.V[b]and self.V[c],'bad vertex id');table.insert(self.F,{a,b,c});return #self.F end
   function e.SetFaceNormals(self,f,ids)for _,i in ipairs(ids)do assert(self.N[i],'bad normal id')end;self.FN[f]=ids end
   function e.SetFaceColors(self,f,ids)for _,i in ipairs(ids)do assert(self.C[i],'bad colour id')end;self.FC[f]=ids end
   function e.Destroy(self)if not self.Destroyed then self.Destroyed=true;log.Destroyed+=1 end end
   log.Live[e]=true
   return e
  end
 end
 local contents=0
 AS.CreateDataModelContentAsync=function(_,content)
  contents+=1
  if opts.ContentFail==contents then return R.Enum.CreateContentResult.Failure,nil end
  local e=content.Object;assert(not e.Destroyed,'content from a destroyed EditableMesh')
  local rec={Id='keeper'..(#log.Contents+1),V=e.V,N=e.N,C=e.C,F=e.F,FN=e.FN,FC=e.FC}
  table.insert(log.Contents,rec);return R.Enum.CreateContentResult.Success,rec
 end
 AS.CreateMeshPartAsync=function(_,content,options)
  local p=R.new('MeshPart');p._props.MeshContent=content
  local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
  for _,v in ipairs(content.V)do for a=1,3 do lo[a]=math.min(lo[a],v[a]);hi[a]=math.max(hi[a],v[a])end end
  p._props.MeshSize=R.Vector3.new(hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3]);p._props.Size=p._props.MeshSize
  rawset(p,'_options',options);rawset(p,'_meshCentre',{(lo[1]+hi[1])/2,(lo[2]+hi[2])/2,(lo[3]+hi[3])/2});table.insert(log.Parts,p)
  -- (the engine's Clone keeps attributes and the mesh; the plain mock Clone drops attributes)
  local plain=p.Clone
  rawset(p,'Clone',function(self)local c=plain(self);for k,v in pairs(self._attrs)do c._attrs[k]=v end;rawset(c,'_options',options);rawset(c,'_source',self);return c end)
  return p
 end
 W.env.Content={fromObject=function(o)return {Object=o}end}
 return log
end
return M
