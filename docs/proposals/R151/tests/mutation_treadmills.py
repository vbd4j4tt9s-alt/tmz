"""R151 treadmill polish: mutation check of the treadmill suite. Each mutation breaks a COPY of src/ (never the checkout) in one way; the suite
(test_treadmills151.luau, plus check_belt_images.py for the images) must fail for every one of them.
Usage: python3 mutation_treadmills.py <scratch dir>   (exit 1 if a mutation is missed)"""
import os, shutil, subprocess, sys
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..'))
OUT = sys.argv[1]
MUTS = [
    ('belt scroll speed', 'src/ReplicatedStorage/TreadmillLook151.lua', 'L.Scroll={Training=3.0,', 'L.Scroll={Training=2.0,'),
    ('label never hides', 'src/ReplicatedStorage/TreadmillFx.lua', "    local hide=self:OwnerTraining(record)", "    local hide=false"),
    ('a dress part answers raycasts', 'src/ServerScriptService/ChestChaseServer/BiomeVisuals.lua', "local v=part(dm,name,size,origin*frame,color,material,class);v.CastShadow=false;return v", "local v=part(dm,name,size,origin*frame,color,material,class);v.CastShadow=false;v.CanQuery=true;return v"),
    ('flow pieces kept', 'src/ServerScriptService/ChestChaseServer/BiomeVisuals.lua', "if v:IsA('BasePart')and v:GetAttribute('TrackMotion')=='Flow'then v:Destroy();retired+=1 end", "if false then retired+=1 end"),
    ('step back to 1/6 s', 'src/ServerScriptService/ChestChaseServer/Config.lua', 'Config.TrainingInterval = 1 / 5', 'Config.TrainingInterval = 1 / 6'),
    ('formatter old boundary', 'src/ReplicatedStorage/SpeedPopupStyle.lua', "if (tonumber(text) or 0) < 1e3 or i == #units then", "if true then"),
    ('light cap ignored', 'src/ServerScriptService/ChestChaseServer/BiomeVisuals.lua', "            if room<=0 then return end", "            if false then return end"),
    ('a pattern drifts', 'src/ReplicatedStorage/TreadmillBeltArt151.lua', "for _,p in ipairs(pads)do ring(c,p[1],p[2],5.5,1.3,5,110)", "for _,p in ipairs(pads)do ring(c,p[1],p[2],5.6,1.3,5,110)"),
    ('grid fallback missing', 'src/ReplicatedStorage/TreadmillBeltArt151.lua', " else texture.Texture=look.Grid end\n", " else end\n"),
    ('sign price colour fixed', 'src/ServerScriptService/ChestChaseServer/GardenUpgradeService.lua', "(tonumber(balance)or 0)>=cost and RGB(67,185,98)or RGB(200,66,65)", "RGB(200,66,65)"),
    ('scroll while far', 'src/ReplicatedStorage/TreadmillFx.lua', "    local animate=policy.Animate and record.Visible and record.Distance<=Fx.ANIMATE", "    local animate=policy.Animate"),
    ('belt collider resized', 'src/ServerScriptService/ChestChaseServer/BiomeVisuals.lua', "    local beltSize=V(9.4,.4,13.2*lengthScale)", "    local beltSize=V(9.6,.4,13.2*lengthScale)"),
]
caught = 0
for name, f, old, new in MUTS:
    d = os.path.join(OUT, 'm')
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    shutil.copytree(os.path.join(REPO, 'src'), os.path.join(d, 'src'))
    p = os.path.join(d, f)
    s = open(p, encoding='utf-8').read()
    assert s.count(old) >= 1, (name, old)
    open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
    t = os.path.join(d, 't')
    os.makedirs(t)
    for x in ('tools/tests/roblox.luau', 'docs/proposals/inventory_R113/tests/world.luau', 'docs/proposals/R149/tests/zfight_world.luau', 'docs/proposals/R151/tests/test_treadmills151.luau'):
        shutil.copy(os.path.join(REPO, x), t)
    subprocess.check_call([sys.executable, os.path.join(REPO, 'docs/proposals/R149/tests/zfight_bundle.py'), os.path.join(d, 'src'), t], stdout=subprocess.DEVNULL)
    r = subprocess.run(['/opt/luau/luau', 'test_treadmills151.luau'], cwd=t, capture_output=True, text=True, timeout=900)
    log = r.stdout + r.stderr
    fails = [l for l in log.split('\n') if l.startswith('FAIL')]
    extra = ''
    if name == 'a pattern drifts':  # the image check is a separate step: compare with the PNG
        r2 = subprocess.run([sys.executable, os.path.join(REPO, 'docs/proposals/R151/tests/check_belt_images.py'), '/dev/stdin', REPO, os.path.join(d, 'img')], input=log, capture_output=True, text=True)
        if r2.returncode != 0:
            fails.append('belt images differ')
    ok = len(fails) > 0 or r.returncode != 0
    caught += ok
    print('%-32s %s  %s' % (name, 'CAUGHT' if ok else 'MISSED', (fails[0][:110] if fails else '')))
print('%d / %d mutations caught' % (caught, len(MUTS)))
sys.exit(0 if caught == len(MUTS) else 1)
