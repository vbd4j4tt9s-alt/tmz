-- R147 (owner): the Verity pack (BagVariant 'VerityReliquary', Stage 7) - Verity's answer to a Void pack. It is the Void pack's
-- reliquary (same body, parts, size, bounds, motion hints) in the gold / white Verity palette: a gold body, cream and white
-- highlights, warm light instead of purple, and gold sparkles instead of the void haze (Fx, read by VoidPackFx).
-- No new shapes: EclipsePackArt does the building with this palette, so every render path (world, carried, dropped, inventory
-- pictures, previews, the opening copy) is covered by SeedPackRenderer.Build routing here.
local Catalog=require(script.Parent.VerityCatalog)
local Eclipse=require(script.Parent.EclipsePackArt)
local RGB=Color3.fromRGB
local C=Catalog.Palette
local A={Budget=Eclipse.Budget}
-- Same keys as EclipsePackArt.Palette. A gold body means the Void's dark-on-dark glow flips: a dark amber core with white-hot rings.
A.Palette={
 Body=C.Ball,Trim=RGB(190,124,12),Nebula=C.Honey,NebulaPink=C.Amber,NebulaBlue=C.Gloss,
 ArmInner=C.White,ArmMid=C.Honey,ArmOuter=C.Amber,Void=C.Shade,
 PhotonHot=C.White,PhotonPink=C.Amber,PhotonViolet=C.Honey,Accretion=C.Gloss,
 Pupil=C.Gloss,Iris=C.Ball,Rune=C.White,Star=C.White,StarCyan=C.Honey,StarPink=C.Amber,
 Halo=C.Ball,HaloHot=C.Gloss,Debris=RGB(150,98,10),
}
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
-- Fx colours for VoidPackFx (same fields as VoidPackFx.Void): gold sparkles, a warm gold glow, a warm light - nothing purple.
A.Fx={
 Haze={Texture=SPARK,Colors={C.Ball,C.Honey},Size={.5,1.1},Emission=.7,Alpha=.55},
 Nebula={Texture=SPARK,Colors={C.Amber,C.Gloss},Size={.5,1.1},Emission=1,Alpha=.35},
 Stars={Texture=SPARK,Colors={C.White,C.Honey},Size={.10,.03},Emission=1,Alpha=.15},
 Debris=RGB(150,98,10),Comet=C.Honey,Trail={C.Ball,C.Amber},
 Fill=C.Honey,Outline=C.Ball,Light=RGB(255,196,70),
}
function A.Specs()return Eclipse.Specs(A.Palette)end
function A.Bounds(scale)return Eclipse.Bounds(scale)end
function A.Build(bag)
 local done=Eclipse.Build(bag,A.Palette)
 bag:SetAttribute('VerityPack',true)
 return done
end
return A
