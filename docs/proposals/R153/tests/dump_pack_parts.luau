--!nocheck
-- R153: every pack whose pouch is a template mesh, as a scene for check_pack_parts.py (R151's scene format: every part in the root's frame divided by the
-- pack's scale): the 42 designs (ground), the Void and the Mech on the ground and in an R15 hand, and a 25x giant. The pouch MeshParts are written too, so the
-- check can prove they sit on their template's PackLocalFrame (the frame the native render data is drawn in) before it reads the pouch's real surface.
local H=require('./pack_world');local W=H.W
W.module('PackShapes151').Config.Enabled=false -- (the default pouch: the shapes' crimps are test_pack_parts.luau's)
local function emit(label,bag,key)local sc=H.scene(bag,label);sc.attrs.Body=key;print('SCENE '..H.json(sc));bag:Destroy()end
for stage=1,7 do for i,variant in ipairs(H.ORDINARY)do
 local bag=H.ground(stage,variant,1,'None');emit(bag:GetAttribute('PackArtKey'),bag,bag:GetAttribute('PackArtKey'))
end end
emit('Giant25_Lava_06',H.ground(4,'Pack06',25,'Gold'),'Lava_06')
emit('Void',H.ground(7,H.VOID,1,'None'),'Forest_01')
emit('Mech',H.ground(8,H.MECH,1,'None'),'Forest_01')
local held,char=H.held(7,H.VOID,1,'None','R15');emit('Void_held',held,'Forest_01');char:Destroy()
held,char=H.held(8,H.MECH,1,'None','R15');emit('Mech_held',held,'Forest_01');char:Destroy()
emit('Void_25x',H.ground(7,H.VOID,25,'Diamond'),'Forest_01')
