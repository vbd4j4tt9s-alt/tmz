--!nocheck
-- R149 fruit meshes on the Roblox mock: AssetService's EditableMesh -> CreateDataModelContentAsync -> CreateMeshPartAsync route (the one
-- ApprovedPlantMeshes and FruitMeshes149 use), recorded so a test can read exactly what was baked.
--   install(W, opts)  adds the three AssetService methods and the Content global to the mock world. opts.FailAt = n makes the n-th
--                     CreateEditableMesh return nil (no mesh memory); opts.Missing = true leaves CreateEditableMesh out (EditableMesh
--                     not allowed in this experience); opts.ContentFail = n makes the n-th CreateDataModelContentAsync report Failure.
--   prepare(W)        requires FruitMeshes149 and runs Prepare() with RunService:IsServer() true (the server bakes; the mock's
--                     ReplicatedStorage is shared, so the "client" sees the templates afterwards), then switches back to a client.
-- log: Editables (made), Destroyed, Contents (one record per baked mesh: Id, V, N, C, F, FN, FC, Yields), Parts.
local M={}
function M.install(W,opts)
 opts=opts or{};local R=W.R;local AS=W.service('AssetService')
 local log={Editables=0,Destroyed=0,Contents={},Parts={},Calls=0};M.log=log
 -- count the bake's yields; R.task.wait is looked up on every call (a test may swap in a scheduler that really waits)
 local yields=0
 W.env.task=setmetatable({wait=function(...)yields+=1;return R.task.wait(...)end},{__index=R.task})
 if not opts.Missing then
  AS.CreateEditableMesh=function()
   log.Calls+=1;if opts.FailAt==log.Calls then return nil end
   log.Editables+=1
   local e={V={},N={},C={},F={},FN={},FC={},Destroyed=false,Yields0=yields}
   function e.AddVertex(self,p)table.insert(self.V,{p.X,p.Y,p.Z});return #self.V end
   function e.AddNormal(self,n)table.insert(self.N,{n.X,n.Y,n.Z});return #self.N end
   function e.AddColor(self,c,a)table.insert(self.C,{c.R,c.G,c.B,a});return #self.C end
   function e.AddTriangle(self,a,b,c)table.insert(self.F,{a,b,c});return #self.F end
   function e.SetFaceNormals(self,f,ids)self.FN[f]=ids end
   function e.SetFaceColors(self,f,ids)self.FC[f]=ids end
   function e.Destroy(self)if not self.Destroyed then self.Destroyed=true;log.Destroyed+=1 end end
   return e
  end
 end
 local contents=0
 AS.CreateDataModelContentAsync=function(_,content)
  contents+=1
  if opts.ContentFail==contents then return R.Enum.CreateContentResult.Failure,nil end
  local e=content.Object
  local rec={Id='gen'..(#log.Contents+1),V=e.V,N=e.N,C=e.C,F=e.F,FN=e.FN,FC=e.FC,Yields=yields-e.Yields0}
  table.insert(log.Contents,rec);return R.Enum.CreateContentResult.Success,rec
 end
 AS.CreateMeshPartAsync=function(_,content,options)
  local p=R.new('MeshPart');p._props.MeshContent=content;p._props.Size=R.Vector3.new(1,1,1)
  rawset(p,'_options',options);table.insert(log.Parts,p);return p
 end
 W.env.Content={fromObject=function(o)return {Object=o}end}
 return log
end
function M.prepare(W)
 local F=W.module('FruitMeshes149');local Run=W.Run
 local was=Run.IsServer;Run.IsServer=function()return true end
 local ok,a,b=pcall(F.Prepare)
 Run.IsServer=was
 if not ok then error(a,0)end
 return a,b
end
return M
