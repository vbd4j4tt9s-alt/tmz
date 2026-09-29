-- Built-in geometry: no upload, mesh permission, asset fetch or runtime mesh bake.
-- A Sphere SpecialMesh follows all three parent Size axes, retaining pouch depth.
local Shape={}
function Shape.Sphere(part)
 part.Shape=Enum.PartType.Block
 local mesh=Instance.new('SpecialMesh');mesh.Name='RoundedPackSurface'
 mesh.MeshType=Enum.MeshType.Sphere;mesh.Scale=Vector3.one;mesh.Offset=Vector3.zero
 mesh.Parent=part
 return mesh
end
return Shape
