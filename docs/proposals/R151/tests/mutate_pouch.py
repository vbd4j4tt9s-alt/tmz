"""R151 / R152: breaks a copy of the Verity pouch code in one specific way, so run_verity_pouch.sh --mutations can prove test_verity_pouch.luau notices it.
Usage: python3 mutate_pouch.py <src dir (a COPY: it is edited in place)> <mutation name | list>"""
import os
import sys

src, name = sys.argv[1], sys.argv[2]
RS = os.path.join(src, 'ReplicatedStorage')


def patch(file, old, new):
    path = os.path.join(RS, file)
    text = open(path, encoding='utf-8').read()
    assert old in text, (name, file, old[:70])
    open(path, 'w', encoding='utf-8').write(text.replace(old, new, 1))


POUCH = 'VerityPouch151.lua'
ART = 'VerityPackArt.lua'
M = {
    # --- the mesh (R152: generated, flat) ---
    # a vertex colour that is not white (a dark patch x yellow = black)
    'colors_not_white': (POUCH, 'editable:AddColor(WHITE,1)', 'editable:AddColor(Color3.new(.2,.2,.3),1)'),
    # relief: the last flat row of the body gets a ridge (a bump standing out of the face)
    'relief_added': (POUCH, 'local up={{yb,h0,0}}', 'local up={{yb,h0,.03}}'),
    # a puffy belly: a row in the middle of the body that is thicker than the faces
    'puffy_belly': (POUCH, 'for _,r in ipairs(up)do rows[#rows+1]=r end', 'rows[#rows+1]={0,h0*1.2,0};for _,r in ipairs(up)do rows[#rows+1]=r end'),
    # the knife edge is not welded: the surface is open at the ends
    'open_ends': (POUCH, 'up[#up+1]={h,0,amp,true}', 'up[#up+1]={h,0,amp,false}'),
    # triangles wound the other way (the pouch faces inward)
    'inward_faces': (POUCH, 'for _,t in ipairs({{A,Bq,C},{A,C,D}})do', 'for _,t in ipairs({{A,C,Bq},{A,D,C}})do'),
    # the side edges are not rounded (a sharp box)
    'sharp_edges': (POUCH, 'local rc0=math.min(o.EdgeRadius,a*.5,h0*.9)', 'local rc0=0'),
    # the pouch is not the template\'s width
    'size_wrong': (POUCH, 'local data=M.Generate(size.X,size.Y,size.Z*M.DepthShare)', 'local data=M.Generate(size.X*.9,size.Y,size.Z*M.DepthShare)'),
    # the pouch loses the template's PackLocalFrame (the pivot)
    'frame_lost': (POUCH, "part:SetAttribute('PackLocalFrame',frame)", "part:SetAttribute('PackLocalFrame',CFrame.new())"),
    # the baked mesh is not checked against the generated one
    'no_size_check': (POUCH, "assert(math.abs(own[axis]-data.Extent[i])<=M.SizeTolerance*data.Extent[i]+1e-4,", "assert(true or math.abs(own[axis]-data.Extent[i])<=M.SizeTolerance*data.Extent[i]+1e-4,"),
    # the EditableMesh is not destroyed after the bake (a memory leak per server)
    'editable_leak': (POUCH, "if editable then pcall(function()editable:Destroy()end)end", ''),
    # the template's mesh id comes back into the code
    'hard_coded_id': (POUCH, "local frame=source:GetAttribute('PackLocalFrame')", "local _id='rbxassetid://75504658868908';local frame=source:GetAttribute('PackLocalFrame')"),
    # the pouch is the whole template again (every part of the design is baked)
    'all_parts': (POUCH, "local part=bake(sources[1]);part.Parent=model", "for _,sp in ipairs(sources)do bake(sp).Parent=model end;local part=model:GetChildren()[1]"),
    # a world without the EditableMesh API warns (a stray warning in every older suite)
    'unavailable_warns': (POUCH, "if not tostring(why):find('EditableMesh is not available in this environment',1,true)then warn(", "if true then warn("),
    # a Verity pack of another design built from the pouch of Storm_02
    'wrong_design': (POUCH, "if key~=nil and key~=name then return 'Off','only '..tostring(name)..' is made'end", ''),
    # --- the pack ---
    # Verity's picture tinted
    'tinted_decal': (ART, "d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=pouch", "d.Color3=Color3.fromRGB(255,255,200);d.Transparency=0;d.Parent=pouch"),
    # the pouch not painted yellow (the white mesh shows)
    'pouch_not_yellow': (ART, "pouch.Color=A.Yellow;pouch.Material", "pouch.Material"),
    # the seal and strips not the darker yellow
    'seal_not_darker': (ART, "p.Color=A.Seal;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0", "p.Color=A.Yellow;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0"),
    # the Decals on the seal (floating off the pouch) instead of the pouch
    'decals_on_seal': (ART, "d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=pouch", "d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=bag:FindFirstChild('BottomSeal')"),
    # leftover design: nothing of the template's other parts / appearances / decals is removed
    'leftover_kept': (ART, "if p:IsA('MeshPart')and not pouch then pouch=p else p:Destroy()end", "if p:IsA('MeshPart')and not pouch then pouch=p end"),
    'leftover_appearance_kept': (ART, "if not v:IsA('WeldConstraint')then v:Destroy()end", "if false then v:Destroy()end"),
    # a template that is not marked flat (an old Model) is used anyway
    'flat_gate_removed': (ART, " and template:GetAttribute('Flat')==true then", " then"),
    # a client that does not wait for the server's bake (the sachet is cached in the picture for the session)
    'client_does_not_wait': (ART, "if Run:IsClient()and not Run:IsServer()then error('Verity pouch is still loading',0)end", ''),
    # a failed bake that is not contained: the sachet fallback is gone (the pack build errors)
    'no_fallback': (ART, "   local ok,built=pcall(buildPouch,bag,isValid,key,template)\n   if ok then return built end", "   return buildPouch(bag,isValid,key,template)"),
    # --- never shaped ---
    # PackShapes151 gives the Verity pack a shape again (Applies no longer excludes it)
    'verity_shaped': ('PackShapes151.lua', "or variantKey==require(script.Parent.VerityCatalog).Variant then return false end", " then return false end"),
}
if name == 'list':
    print(' '.join(M))
    sys.exit(0)
file, old, new = M[name]
patch(file, old, new)
print('ok')
