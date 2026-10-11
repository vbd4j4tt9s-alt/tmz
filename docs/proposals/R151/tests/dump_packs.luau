--!nocheck
-- R151: prints every distinct pack the game can build as a scene for check_packs.py / the three.js preview:
--   "SCENE <json>"   one line per pack: label, scale, parts (root-frame, scale-normalised: zfight.py's part format + anchored / fx flags)
-- The scenes are the ground build (Visuals.Bag, an anchored world pack): every other context builds the same parts (test_packs.luau proves it part by
-- part), so one scene per design is enough for the geometry checks. Designs: the 42 ordinary ones (7 biomes x Pack01..Pack06), the Void pack, the
-- Mech pack and the Verity pack. COAT=Gold / Diamond (global) builds them in that coat.
local H=require('./pack_world');local W,R=H.W,H.R
local coat=rawget(_G,'COAT')or'None'
local function emit(label,bag)print('SCENE '..H.json(H.scene(bag,label)));bag:Destroy()end
for _,stage in ipairs(H.STAGES)do for i,variant in ipairs(H.ORDINARY)do
 emit(string.format('%s_%02d',H.BIOMES[stage],i),H.ground(stage,variant,1,coat))
end end
-- the pad under a world pack (SeedPackVisuals.Platform): its own scenes, the stone is the body
for _,stage in ipairs(H.STAGES)do
 local pad=H.Visuals.Platform(R.CFrame.new(0,10,0),stage,'Pack03',1);pad.Parent=W.workspace
 print('SCENE '..H.json(H.scene(pad,'Pad_'..H.BIOMES[stage],true)));pad:Destroy()
end
-- a giant (25x): the camera fade of GiantVisualSafety is applied to its tagged parts by the preview (and test_packs.luau checks the tags)
emit('Giant25_Forest_03',H.ground(1,'Pack03',25,coat))
emit('Void',H.ground(7,H.VOID,1,coat))
emit('Mech',H.ground(8,H.MECH,1,coat))
emit('Verity',H.ground(7,H.VERITY,1,coat))
