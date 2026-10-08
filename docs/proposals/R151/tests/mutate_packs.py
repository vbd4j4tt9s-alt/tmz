"""R151: breaks a copy of the pack code in one specific way, so run_packs.sh --mutations can prove the audit notices it.
Usage: python3 mutate_packs.py <src dir (a COPY: it is edited in place)> <mutation name>
Prints the check that must fail ("test:<kind>" = test_packs.luau reports failures of that kind, "geometry" = check_packs.py exits 1)."""
import os
import sys

src, name = sys.argv[1], sys.argv[2]
RS = os.path.join(src, 'ReplicatedStorage')


def patch(file, old, new, count=1):
    path = os.path.join(RS, file)
    text = open(path, encoding='utf-8').read()
    assert old in text, (name, file, old[:60])
    open(path, 'w', encoding='utf-8').write(text.replace(old, new, count))


M = {
    # a tear strip that is not welded: it would stay behind when the pack is carried
    'unwelded_strip': ('SeedPackVisuals.lua', 'if root and not p.Anchored then', 'if root and not p.Anchored and name~="TearStrip3" then', 'test:connection'),
    # a part of a held pack that is anchored: it stays where it was built
    'anchored_seal': ('SeedPackVisuals.lua', 'p.Anchored=root==nil or root.Anchored; p.Massless=true', 'p.Anchored=root==nil or root.Anchored or name=="BottomSeal"; p.Massless=true', 'test:anchored'),
    # the pack's root not welded to the carrier: the whole pack stays behind
    'unwelded_root': ('SeedPackVisuals.lua', 'if root and not p.Anchored then', 'if root and not p.Anchored and name~="VisualRoot" then', 'test:connection'),
    # the giant fix taken out again (R151 finding 1)
    'giant_untagged': ('SeedPackVisuals.lua', "if packSize>10 then for _,p in ipairs(m:GetChildren())do if p:IsA('BasePart')and p~=root then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end end end", '', 'test:giant'),
    # a PackLocalFrame that is not the part's real frame: SeedPackRender / VoidPackFx would move the part to the wrong place
    'wrong_local_frame': ('SeedPackRenderer.lua', "p:SetAttribute('PackLocalFrame',frame)", "p:SetAttribute('PackLocalFrame',frame*CFrame.new(0,.1,0))", 'test:structure'),
    # a pack that is bigger in the hotbar / Bag picture than on the ground
    'picture_size_jump': ('SeedPackVisuals.lua', "scale=(scale or 1)*variant.BagScale*theme.Scale*(displaySize or packSize)", "scale=(scale or 1)*variant.BagScale*theme.Scale*(displaySize or packSize)*(parent==nil and origin.Position.Y==0 and 1.1 or 1)", 'test:context'),
    # a part count the renderers never reach: the pack would never be animated
    'part_count': ('SeedPackRenderer.lua', "bag:SetAttribute('CompactPackPartCount',count+10)", "bag:SetAttribute('CompactPackPartCount',count+11)", 'test:structure'),
    # a Mech servo whose C0 is not the rest frame: the part jumps when the motor is solved
    'motor_rest': ('SpecialPackArt89.lua', 'joint.C0=frame;joint.C1=CF()', 'joint.C0=frame*CF(0,.5,0);joint.C1=CF()', 'test:connection'),
    # the bottom seal off the pouch: a floating part
    'floating_seal': ('SeedPackVisuals.lua', 'origin*CFrame.new(0,-1.12*scale,0),seal,visualWeldRoot)', 'origin*CFrame.new(0,-1.52*scale,0),seal,visualWeldRoot)', 'geometry'),
    # a duplicate of the seal one stud-thousandth away: z-fighting
    'zfight_seal': ('SeedPackVisuals.lua', '    for i=1,8 do\n        local strip=part(', '    part(m,"SealDup",Vector3.new(1.9,.16,.035)*scale,origin*CFrame.new(0,-1.12*scale,0),Color3.new(1,0,0),visualWeldRoot)\n    for i=1,8 do\n        local strip=part(', 'geometry'),
    # a weather trait that adds a part to the pack
    'weather_part': ('ItemEffectAnchor.lua', "p:SetAttribute('WeatherTrait'", "if model:IsA('Model')then local x=Instance.new('Part');x.Name='WeatherRing';x.Parent=model end;p:SetAttribute('WeatherTrait'", 'test:weather'),
    # a stray part that is not welded to a held Verity pack
    'verity_loose': ('VerityPackArt.lua', "if not p.Anchored then local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p end", "if not p.Anchored and s.Name~='VerityBodyTop' then local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p end", 'test:connection'),
    # a Void part pushed off the face (the stars back at .016 / .01 deep is the base; now far out)
    'void_floating': ('EclipsePackArt.lua', "local at=base*CF(star[1],star[2],depth('Star',i))", "local at=base*CF(star[1],star[2],-.2)", 'geometry'),  # (R153: the stars' depth comes from depth())
}
if name == 'list':
    print(' '.join(M))
    sys.exit(0)
file, old, new, expect = M[name]
patch(file, old, new)
print(expect)
