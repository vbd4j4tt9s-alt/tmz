"""R151: breaks a copy of the Verity pouch code in one specific way, so run_verity_pouch.sh --mutations can prove test_verity_pouch.luau notices it.
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


M = {
    # the vertex colours are left as the print had them (a dark patch x yellow = black): the module's own read-back must refuse the bake
    'colors_not_whitened': ('VerityPouch151.lua', 'for _,c in ipairs(colors)do editable:SetColor(c,WHITE);editable:SetColorAlpha(c,1)end', 'for _,c in ipairs(colors)do editable:SetColorAlpha(c,1)end'),
    # the colours are left AND the read-back is removed: a bake that is not white is baked anyway
    'no_readback': ('VerityPouch151.lua', "assert(k.R>.999 and k.G>.999 and k.B>.999,'a vertex colour is not white after the bake')", 'local _=k'),
    # the template's mesh id written into the code
    'hard_coded_id': ('VerityPouch151.lua', 'editable=Assets:CreateEditableMeshAsync(Content.fromUri(id))', "editable=Assets:CreateEditableMeshAsync(Content.fromUri('rbxassetid://75504658868908'))"),
    # the EditableMesh is not destroyed after the bake (a memory leak per server)
    'editable_leak': ('VerityPouch151.lua', "if editable then pcall(function()editable:Destroy()end)end", ''),
    # Verity's picture tinted
    'tinted_decal': ('VerityPackArt.lua', "d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=pouch", "d.Color3=Color3.fromRGB(255,255,200);d.Transparency=0;d.Parent=pouch"),
    # the pouch not painted yellow (the white mesh shows)
    'pouch_not_yellow': ('VerityPackArt.lua', "p.Color=A.Yellow;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0;p.Transparency=0;p.TextureID=''\n  for _,v in", "p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0;p.Transparency=0;p.TextureID=''\n  for _,v in"),
    # the Decals on the seal (floating off the pouch) instead of the pouch
    'decals_on_seal': ('VerityPackArt.lua', "d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=pouch", "d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=bag:FindFirstChild('BottomSeal')"),
    # a client that does not wait for the server's bake (the sachet is cached in the picture for the session)
    'client_does_not_wait': ('VerityPackArt.lua', "if Run:IsClient()and not Run:IsServer()then error('Verity pouch is still loading',0)end", ''),
    # a Verity pack of another design built from the pouch of Storm_02
    'wrong_design': ('VerityPouch151.lua', "if key~=nil and key~=name then return 'Off','only '..tostring(name)..' is baked'end", ''),
    # a world without the EditableMesh API warns (a stray warning in every older suite)
    'unavailable_warns': ('VerityPouch151.lua', "if not tostring(why):find('EditableMesh is not available in this environment',1,true)then warn(", "if true then warn("),
    # a failed bake that is not contained: the sachet fallback is gone (the pack build errors)
    'no_fallback': ('VerityPackArt.lua', "   local ok,built=pcall(buildPouch,bag,isValid,key,template)\n   if ok then return built end", "   return buildPouch(bag,isValid,key,template)"),
}
if name == 'list':
    print(' '.join(M))
    sys.exit(0)
file, old, new = M[name]
patch(file, old, new)
print('ok')
