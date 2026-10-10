--!nocheck
-- R152 round trip, part 1: KeeperMeshes152.Decode (the game's own decoder: base64 -> inflate -> parts) on the mock, for every keeper,
-- printed as OBJ blocks (rig space, studs; The Darkened: group-local) plus each triangle's palette cell. check_roundtrip.py splits them into
-- .obj files and compares them with an independent Python decode, the approved R151 manifests and KeeperRigConfig152.
local W=require('./world')
local Meshes=W.module('KeeperMeshes152');local C=W.module('KeeperRigConfig152')
local out={}
for _,stage in ipairs(Meshes.Order)do
 local spec=C.Stages[stage];local data=W.module(spec.Module);local d=Meshes.Decode(data)
 out[#out+1]=('KEEPER %s %d %s'):format(spec.Key,stage,spec.Name:gsub(' ','_'))
 for i,p in ipairs(d.Parts)do
  local s=spec.Parts[i]
  out[#out+1]=('o %s %s %s %d %d'):format(s.Name,s.Group,s.Kind,#p.V//3,#p.T//3)
  for j=1,#p.V//3 do out[#out+1]=('v %.6f %.6f %.6f'):format(p.V[j*3-2],p.V[j*3-1],p.V[j*3])end
  for j=1,#p.T//3 do out[#out+1]=('f %d %d %d'):format(p.T[j*3-2],p.T[j*3-1],p.T[j*3])end
  if p.P then local t={};for j,c in ipairs(p.P)do t[j]=tostring(c)end;out[#out+1]='# cells '..table.concat(t,' ')end
 end
end
print(table.concat(out,'\n'))
