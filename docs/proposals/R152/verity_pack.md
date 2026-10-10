# R152: the Verity pack is a clean flat pouch

Owner: "verity pack is also not flat for some reason and there is some leftover design" (the pack held, front: embossed shapes at the corners and edges; from the side: strongly puffy, the face bending round the curve).
Preview: `verity_pack.png` (front, the owner's side angle, profile, held; BEFORE over AFTER).

## Cause

R151 made the Verity pack from a COPY of the standard pouch's uploaded mesh (Storm_02) with every vertex colour set to white and the part painted yellow. That fixes the colour, but two things of that mesh are geometry, which a colour cannot remove:

1. **Relief.** The mesh carries part of its print as embossed shapes at the corners and edges. Whitening the colours left the bumps, now yellow: the "leftover design".
2. **The puffy belly.** The standard pouch is a pillow, about 1.0 stud deep. A Decal on a MeshPart is projected along its face onto whatever surface it meets, so on the curved belly Verity's face stretched and bent round the curve.

R151 also gave every new pack one of six random chip-bag shapes (PackShapes151), Verity packs included, which bent the pouch further per pack.

## Fix

**The Verity pack no longer uses the standard pouch's mesh.** `VerityPouch151.Generate` makes a clean pouch as plain data and the server bakes it once at start with EditableMesh (`AssetService:CreateEditableMesh` -> `AddVertex` / `AddNormal` / `AddColor` / `AddTriangle` -> `CreateDataModelContentAsync` -> `CreateMeshPartAsync`, the route FruitMeshes149 uses). No asset is loaded, so no relief can come with it.

* the template pouch's width and height (1.97 x 2.06) and its PackLocalFrame, so the outline, pivot, Bounds, seal and the 8 tear strips are the standard pack's; depth 0.56 of the standard's (a flat sachet, as R149's);
* front and back are exactly flat planes over the whole body, the long edges rounded, nothing else on the surface;
* the ends pinch smoothly to a crimped zig-zag seal (18 ridges) that closes in a knife edge, like a chip bag; one closed outward-facing surface (3,546 vertices, 7,088 triangles), one white colour on every face, planar UVs;
* `VerityPackArt` paints the pouch 255,255,0, the seal and strips a slightly darker yellow (230,230,0), puts Verity's face on it as two Decals (Front and Back) and destroys anything else a template carries (appearance, Storm print Decal, texture, extra parts). The fallback chain is unchanged: no API, a denied or failed bake, a bad template -> the R149 sachet.
* **Never shaped.** `PackShapes151.Applies` excludes the Verity variant, so nothing rolls, stores or builds a shape for it (track, hand, hotbar, shop / Index / market / dialog pictures, opening). Older records that carry a Verity shape lose it on load and gift.

Generate, not flatten: flattening the copy means classifying the vertices of an uploaded mesh nobody can inspect here (front, back, relief, edge), a guess that would miss relief on the edges and still depend on the asset. A generated mesh has a shape the tests can state and check.

## Files

`src/ReplicatedStorage/VerityPouch151.lua` (rewritten), `VerityPackArt.lua`, `PackShapes151.lua` (Verity exclusion). Outside them, minimal: `PlayerDataService.lua` (`savedPackShape` drops a shape of a pack that takes none; the Void -> Verity hand-in no longer rolls one), `ApprovedPlantsBootstrap.server.lua` (comment, warn tag).
Tests in `docs/proposals/R151/tests`: `test_verity_pouch.luau` (1,213 checks: flat within 1e-9, no relief, closed outward surface, same width / height / frame as the standard pouch, never shaped, no leftover design, EditableMesh destroyed, fallbacks), `pouch_mock.luau`, `mutate_pouch.py` (24 mutants), and the pack shape suites brought in line.
Preview: `tools/dump_verity_pouch.py` (runs the real `Generate`, writes an OBJ), `blender/verity_pack.py`, `blender/compose_sheet.py`.

## Doubts

* **Depth.** Width, height, frame and pivot are the standard pouch's, but Size Z is 0.56 of it (`VerityPouch151.DepthShare`; 1 gives a flat brick). The carry layout uses the standard pouch's bounds, so a held flat pack's near face is about 0.22 studs further from the hands (R149's sachet had the same gap).
* **Not verifiable offline:** the real EditableMesh API (`AddUV` / `SetFaceUVs` are best effort and never fail a bake), replication of the baked part to clients (as FruitMeshes149), and that Roblox projects a Decal on a MeshPart along its face (the premise of "flat face = crisp face"). Check in Studio: hold the Verity pack and look at it from the side.
* The preview's BEFORE row is a stand-in (the real mesh is not available offline) and its smiley is drawn, not Verity's picture.
