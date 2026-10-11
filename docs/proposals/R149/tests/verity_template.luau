--!nocheck
-- The REAL Storm_02 pack template (the Standard design of the Verity pack's stage 7), as read out of the place file: ONE MeshPart
-- (ApprovedMesh01, 1.97 x 2.06 x 1.004, Color white, no TextureID, no SurfaceAppearance, no children) at PackLocalFrame
-- CFrame(0,-.01,-.047) turned 180 degrees about Y. Its print is in the mesh's vertex colours (the asset is not available offline).
-- fixtures.luau's F.packAssets only builds three coloured stand-in MeshParts per design; the Verity pack's tests replace Storm_02.
return function(W)
 local R=W.R
 local folder=W.RS:FindFirstChild('SeedPackMeshAssets')
 local old=folder:FindFirstChild('Storm_02');if old then old:Destroy()end
 local m=R.new('Model');m.Name='Storm_02';m:SetAttribute('MeshBakeVersion',123)
 local p=R.new('MeshPart');p.Name='ApprovedMesh01';p.Size=R.Vector3.new(1.97,2.06,1.004);p.Color=R.Color3.fromRGB(255,255,255)
 p.Material=R.Enum.Material.SmoothPlastic;p.TextureID=''
 local frame=R.CFrame.new(0,-.01,-.047)*R.CFrame.Angles(0,math.pi,0)
 p.CFrame=frame;p:SetAttribute('PackLocalFrame',frame);p.Parent=m
 m:SetAttribute('MeshCount',1);m.Parent=folder
end
