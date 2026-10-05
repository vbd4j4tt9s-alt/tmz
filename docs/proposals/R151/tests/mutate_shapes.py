"""R151: breaks a copy of the pack shape code in one specific way, so run_pack_shapes.sh --mutations can prove test_pack_shapes.luau notices it.
Usage: python3 mutate_shapes.py <src dir (a COPY: it is edited in place)> <mutation name | list>"""
import os
import sys

src, name = sys.argv[1], sys.argv[2]
RS = os.path.join(src, 'ReplicatedStorage')


def patch(file, old, new):
    path = os.path.join(RS, file)
    text = open(path, encoding='utf-8').read()
    assert old in text, (name, file, old[:70])
    open(path, 'w', encoding='utf-8').write(text.replace(old, new, 1))


M = {
    # the crimps (where the seal and the tear strips sit) are reshaped too
    'crimp_moves': ('PackShapes151.lua', 'local function body(v)return 1-ss(.80,.94,math.abs(v))end', 'local function body(v)return 1-ss(.80,1.3,math.abs(v))end'),
    # y moves (the pivot / bottom line)
    'y_moves': ('PackShapes151.lua', ' return u*sx,v,w*sz', ' return u*sx,v*1.02,w*sz'),
    # a variation that grows more than 5%
    'grows_too_much': ('PackShapes151.lua', 'return 1-.04*b,1+.05*b end', 'return 1-.04*b,1+.12*b end'),
    # neighbouring tiers of a biome share a variation
    'neighbours_same': ('PackShapes151.lua', 'return((tonumber(tier)-1+hash(biome))%M.Count)+1 end', 'return((math.floor((tonumber(tier)-1)/2)+hash(biome))%M.Count)+1 end'),
    # the vertex colours are touched (the print would be lost)
    'colors_set': ('PackShapes151.lua', "local vertices=editable:GetVertices();assert(#vertices>0,'the pouch mesh has no vertices')",
                   "local vertices=editable:GetVertices();assert(#vertices>0,'the pouch mesh has no vertices')\n  for _,c in ipairs(editable:GetColors())do editable:SetColor(c,Color3.new(1,1,1))end"),
    # the EditableMesh is not destroyed (a memory leak per design)
    'editable_leak': ('PackShapes151.lua', "if editable then pcall(function()editable:Destroy()end)end", ''),
    # the template's mesh id written into the code
    'hard_coded_id': ('PackShapes151.lua', 'local meshId=source.MeshId', "local meshId='rbxassetid://75504658868908'"),
    # a client that waits for the bake (a picture coroutine would be resumed early)
    'client_waits': ('PackShapes151.lua', "if s=='Loading'and Run:IsServer()and coroutine.isyieldable()and not(", "if s=='Loading'and coroutine.isyieldable()and not("),
    # a failure is forgotten: every pack tries (and warns) again
    'forgets_failure': ('PackShapes151.lua', "failed[key]={Id=id,Reason=reason};stats.Failures+=1", "stats.Failures+=1"),
    # the off switch is ignored
    'off_ignored': ('PackShapes151.lua', "if off then return'off'end", "if false then return'off'end"),
    # the part does not follow its mesh's bounding-box centre (a part off the box's middle drifts)
    'frame_not_following': ('PackShapes151.lua', 'local newFrame=d.Magnitude<1e-6 and frame or frame*CFrame.new(d.X,d.Y,d.Z)', 'local newFrame=frame'),
    # the baked part keeps the template's Size (the reshaped mesh is stretched back to the old box)
    'size_not_updated': ('PackShapes151.lua', 'part.Name=source.Name;part.Size=info.Size', 'part.Name=source.Name;part.Size=source.Size'),
    # every pack waits the full time behind a stuck bake
    'stuck_stalls': ('PackShapes151.lua', "and coroutine.isyieldable()and not(current and current.WaiterGaveUp)then", "and coroutine.isyieldable()then"),
    # several designs baked at once (more than one EditableMesh alive)
    'not_one_at_a_time': ('PackShapes151.lua', ' if current then return end', ' '),
    # a Verity pouch that ignores its design's variation
    'verity_unshaped': ('VerityPouch151.lua', 'local id=Shapes.VariationOf(key);local shape', 'local id=nil;local shape'),
    # the Verity pouch is not baked again when the owner changes the mode
    'verity_not_rebaked': ('VerityPouch151.lua', 'if not watching then', 'if false then'),
}
if name == 'list':
    print(' '.join(M))
    sys.exit(0)
file, old, new = M[name]
patch(file, old, new)
print('ok')
