"""R151 fruit fixes, source-level checks (run_fruit_fixes.sh stage 0; no game world needed).
Usage: python3 check_fixes_static.py <repo> <base commit>
  1. every src file this change touches compiles (luau-compile);
  2. no shine part is left in the sources: none of the part names the owner's screenshots showed ('Fruit gloss', 'Berry glint', 'Moon glint', 'Verity gloss', 'Verity glint', 'Fruit shine',
     'Pepper sheen', 'Fruit heart glint'), no `decor` spec, no GlossOut / GlossDirections / VerityDecor leftovers;
  3. the Verity fruit has one Decal (AddFace) and the pack keeps both faces;
  4. the harvest path is wired the way the flight needs it: PlayerDataService leaves its mark, GardenPlantRuntime reads it (and keeps the model a beat), ChestService's InteractGarden is
     unchanged around it (HarvestPlant, then the failure return, then the hook, then the save), EconomyClient expects the arrival before it sends the request and cancels it when refused,
     GardenVisuals launches flights from every path, HarvestArrival lets a flight in the air keep its hold.
Prints a line per group and 'static checks passed' (exit 0), else the failures (exit 1)."""
import os, re, subprocess, sys

repo, base = sys.argv[1], sys.argv[2]
bad = []


def read(rel):
    return open(os.path.join(repo, rel), encoding='utf-8').read()


# 1. compile --------------------------------------------------------------------------------------------------------------------------------------------------------------------
changed = subprocess.run(['git', '-C', repo, 'diff', '--name-only', base, '--', 'src'], capture_output=True, text=True).stdout.split()
changed += subprocess.run(['git', '-C', repo, 'ls-files', '--others', '--exclude-standard', '--', 'src'], capture_output=True, text=True).stdout.split()
compiled = 0
for rel in sorted(set(changed)):
    if rel.endswith('.lua'):
        r = subprocess.run(['/opt/luau/luau-compile', '--text', os.path.join(repo, rel)], capture_output=True, text=True, errors='replace')
        compiled += 1
        if r.returncode != 0:
            bad.append('does not compile: %s %s' % (rel, r.stderr.strip()[:200]))
print('1. %d changed src files compile' % compiled)

# 2. no shine left -----------------------------------------------------------------------------------------------------------------------------------------------------------------
NAMES = ['Fruit gloss', 'Berry glint', 'Moon glint', 'Verity gloss', 'Verity glint', 'Fruit shine', 'Pepper sheen', 'Fruit heart glint']
left = 0
for root, _, files in os.walk(os.path.join(repo, 'src')):
    for f in files:
        if not f.endswith('.lua'):
            continue
        s = open(os.path.join(root, f), encoding='utf-8').read()
        for n in NAMES:
            if n in s:
                bad.append('%s still names a shine part: %s' % (f, n)); left += 1
        for token in ('GlossOut', 'GlossDirections', 'VerityDecor'):
            if token in s:
                bad.append('%s still has %s' % (f, token)); left += 1
        if re.search(r'(\bdecor=true|\["decor"\]=true)', s):
            bad.append('%s still has a decor spec' % f); left += 1
print('2. no shine part, GlossOut, GlossDirections, VerityDecor or decor spec left in src (%d findings)' % left)

# 3. one Verity face ---------------------------------------------------------------------------------------------------------------------------------------------------------------
art = read('src/ReplicatedStorage/VerityPlantArt.lua')
if art.count("Instance.new('Decal')") != 1 or 'VerityBallFaceBack' in art:
    bad.append('VerityPlantArt must create exactly one Decal and no back decal')
pack = read('src/ReplicatedStorage/VerityPackArt.lua')
if 'for _,side in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do' not in pack:
    bad.append('the Verity pack lost its front and back face')
print('3. the Verity fruit has one face; the pack keeps both')

# 4. the wiring ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
pd = read('src/ServerScriptService/ChestChaseServer/PlayerDataService.lua')
m = re.search(r'if PlantRules\.FinishFruit\(crop,definition,fruitIndex,now,self:GetFenceTier\(player\)\)then\s+table\.remove\(crops,cropIndex\)\s+.*?marks\[crop\.Id\]=\{Index=fruitIndex,By=player\.UserId,At=os\.clock\(\)\}', pd, re.S)
if not m:
    bad.append('PlayerDataService:HarvestPlant does not leave its mark right after removing the plant')
rt = read('src/ServerScriptService/ChestChaseServer/GardenPlantRuntime.lua')
if not ('HarvestRemovals' in rt and "SetAttribute('HarvestedBy',mark.By)" in rt and "SetAttribute('HarvestedIndex',mark.Index)" in rt and 'task.delay(Runtime.HarvestLinger' in rt
        and rt.index("SetAttribute('HarvestedIndex',mark.Index)") < rt.index("SetAttribute('HarvestedBy',mark.By)")):
    bad.append('GardenPlantRuntime does not read the mark / keep the model a beat / set HarvestedIndex before HarvestedBy')
cs = read('src/ServerScriptService/ChestChaseServer/ChestService.lua')
a = cs.find('self.PlayerData:HarvestPlant(player, slot, crop.Id, os.time(), payload.FruitIndex)')
d = cs.find('if not success then return reject(result) end', a)
b = cs.find('if action == "Harvest" and self.HarvestHook then pcall(self.HarvestHook, player, result) end')
c = cs.find('self.PlayerData:QueueGardenSave(player)\n\tlocal refreshed')
if not (0 < a < d < b < c):
    bad.append('ChestService.InteractGarden: HarvestPlant, failure return, hook, save are out of order')
ec = read('src/StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua')
e1 = ec.find('if action == "Harvest" then Arrival.Expect(payload.CropId, payload.FruitIndex) end')
e2 = ec.find('local ok, result = pcall(function() return gardenInteract:InvokeServer(action, payload) end)')
e3 = ec.find('if action == "Harvest" and not (ok and type(result) == "table" and result.Success == true) then Arrival.Cancel(payload.CropId, payload.FruitIndex) end')
if not (0 < e1 < e2 < e3):
    bad.append('EconomyClient: Arrival.Expect must come before the request and Arrival.Cancel after a refused one')
gv = read('src/StarterPlayer/StarterPlayerScripts/GardenVisuals.client.lua')
for token in ('local function launch(item,r,crop,index,child)', 'local function harvestedAway(item,r)', 'local function pickedWithoutModel(item,r)', "GetAttributeChangedSignal('HarvestedBy')",
              "GetAttributeChangedSignal('FruitRevision')", 'harvestedAway(item,r) -- R151', 'local function letGo(r)'):
    if token not in gv:
        bad.append('GardenVisuals lacks: ' + token)
ar = read('src/ReplicatedStorage/HarvestArrival.lua')
if 'not entry.Flying then table.insert(list,k)end' not in ar:
    bad.append('HarvestArrival.LandCrop must leave a hold whose fruit is in the air')
fx = read('src/ReplicatedStorage/PlantGrowthFx.lua')
if 'FlightMaxParts=300' not in fx or 'Tokens=4,Range=0' not in fx:
    bad.append('PlantGrowthFx: the lowest tier must fly the player\'s own fruit and the parts cap must be 300')
print('4. the harvest path is wired: mark -> runtime -> client flights -> arrival')
if bad:
    print('\n'.join(bad))
    sys.exit(1)
print('static checks passed')
