-- R147 (owner): the Verity seed and the Verity pack, shared constants (no requires, so any module can use it).
--  * Verity pack (BagVariant 'VerityReliquary', Stage 7): Verity gives one for every Void pack handed in. Odds = the
--    Void pack's with King removed and the Verity seed at 1% (VerityPackOdds).
--  * Verity seed ('VeritySeed', rarity King, its own Index category Stage 9): "just a small Verity ball which players can
--    plant into the ground; the ball grows into a giant Verity fruit which is just a ball, with leaves at its bottom".
local C={Id='VeritySeed',Variant='VerityReliquary',PackStage=7,Stage=9,Biome='Verity',Rarity='King',
 Name='Verity',SeedName='Verity Seed',FruitName='Verity Fruit',PackName='Verity Pack',
 VerityChance=.01,
 -- Economy (owner default: a bit above the best King plant; one fruit at the per-fruit cap, quick regrow).
 Value=9e10,Seconds=14400,RegrowSeconds=1500,FruitCount=1,IndexFirst=1e11,IndexRepeat=2e10,HalfwayGems=10,CompletionGems=100,
 -- Optional image on the fruit (needs the image id behind the owner's Decal); nil = plain glossy ball.
 FaceImageId=nil,
 Palette={Ball=Color3.fromRGB(255,213,46),Gloss=Color3.fromRGB(255,252,232),LeafOuter=Color3.fromRGB(68,160,72),LeafInner=Color3.fromRGB(96,188,88)},
}
function C.Is(id)return id==C.Id end
function C.IsPack(variant)return variant==C.Variant end
return C
