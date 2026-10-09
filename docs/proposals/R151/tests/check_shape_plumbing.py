"""R151 pack shapes: where a pack's chip-bag shape (the field / attribute PackShape) is passed, and where it is not. Static facts a mock run cannot show.
Usage: python3 check_shape_plumbing.py <src dir>      exit 1 and a line per problem

  * PackShape (the whole word) is named by exactly the files that handle a pack's own shape: the builders, the world spawn / carry / drop / hold, the item record, the
    mystery pedestal, the hand-made test packs, the picture key and the hotbar stack key. A catalogue / shop / Index / "what's inside" / title / market script naming it
    would be showing a roll there (the owner: those use the default shape).
  * R152: the Verity pack is NEVER shaped. VerityPackArt and VerityPouch151 name neither PackShape nor DefaultPackShape (nor require PackShapes151: the flat pouch is the same in
    every context), and PackShapes151.Applies excludes the Verity variant (every roll, record field, world pack and builder asks it first)
  * DefaultPackShape (the flag that forces the default shape: the owner's catalogue / shop / reward pictures) is named by the mechanism (SeedPackVisuals, SeedPackRenderer,
    ItemPictures, PackShapes151's header); the market stalls and the shop's Mech viewport pass it to SeedPackVisuals.Bag (the shop / catalogue
    pictures); no builder of a real pack (world, hand, drop, hotbar, record, pedestal) names it. The reward panels' proxy packs (the Verity quest, the daily reward cards,
    the treadmill bonus cards) carry no PackShape either, which is the default shape too, and keep sharing the hotbar's default look
  * the hotbar's stack key includes it (packs of different shapes never share a card)
  * ChaseService passes the carried chest's shape to the carry, the drop's pack and the drop's model; ChestService passes the tool's to the hand
  * ProfileVersion is still 22 (the record field is optional)
"""
import os
import re
import sys

src = sys.argv[1]
problems = []

EXPECTED = {
    'ReplicatedStorage/PackShapes151.lua',          # (it names the attribute in its comments / the status)
    'ReplicatedStorage/SeedPackVisuals.lua',        # Bag / CarryBag: the shape argument -> the attribute
    'ReplicatedStorage/SeedPackRenderer.lua',       # reads it for the ordinary pouch
    'ReplicatedStorage/ItemPictures.lua',           # the picture key and spec of a hotbar / Bag tool
    'ReplicatedStorage/InventoryStacks155.lua',     # the stack key (R155: moved out of the Hotbar, shared with the server's discard)
    'ServerScriptService/ChestChaseServer/ChestService.lua',       # the world spawn, the tool, the hand
    'ServerScriptService/ChestChaseServer/ChaseService.lua',       # the carry and the drop
    'ServerScriptService/ChestChaseServer/PlayerDataService.lua',  # the item record
    'ServerScriptService/ChestChaseServer/MysteryPackService.lua', # the pedestal
    'ServerScriptService/ChestChaseServer/StudioTestCommands.lua', # /test pack (hand-made records)
    'ServerScriptService/ChestChaseServer/RarePackTests.lua',      # /test rarepacks (hand-made records)
}
found = set()
for base, _, files in os.walk(src):
    for f in files:
        if not f.endswith('.lua'):
            continue
        path = os.path.join(base, f)
        rel = os.path.relpath(path, src).replace(os.sep, '/')
        text = open(path, encoding='utf-8').read()
        text = text.replace('local PackShape=require(script.Parent.PackMeshShape88)', '').replace('PackShape.Sphere', '')  # (MechArt's own, unrelated PackShape)
        if re.search(r'\bPackShape\b', text):
            found.add(rel)
for extra in sorted(found - EXPECTED):
    problems.append('%s names PackShape: only the pack builders, the world / carry / drop / hold, the record, the pedestal and the picture / stack keys may' % extra)
for missing in sorted(EXPECTED - found):
    problems.append('%s no longer names PackShape' % missing)


def read(rel):
    return open(os.path.join(src, rel), encoding='utf-8').read()


FLAG_MECHANISM = {
    'ReplicatedStorage/SeedPackVisuals.lua', 'ReplicatedStorage/SeedPackRenderer.lua', 'ReplicatedStorage/ItemPictures.lua',
    'ReplicatedStorage/PackShapes151.lua',
}
flagged = set()
for base, _, files in os.walk(src):
    for f in files:
        if f.endswith('.lua') and re.search(r'\bDefaultPackShape\b', open(os.path.join(base, f), encoding='utf-8').read()):
            flagged.add(os.path.relpath(os.path.join(base, f), src).replace(os.sep, '/'))
for extra in sorted(flagged - FLAG_MECHANISM):
    problems.append('%s names DefaultPackShape: only the mechanism may (a shop / catalogue picture passes it to SeedPackVisuals.Bag as defaultShape, or sets it on its proxy and is added here); a builder of a real pack must never flag it' % extra)
for missing in sorted(FLAG_MECHANISM - flagged):
    problems.append('%s no longer names DefaultPackShape' % missing)
for rel, call in (('ServerScriptService/ChestChaseServer/MarketLayout.lua', "spec.Variant,1,1,'None',nil,true)"), ('ReplicatedStorage/PackViewport89.lua', "'MechLimited',1,1,'None',nil,true)")):
    if call not in read(rel):
        problems.append('%s must build its pack with defaultShape (SeedPackVisuals.Bag(..., nil, true))' % rel)


for rel in ('ReplicatedStorage/VerityPackArt.lua', 'ReplicatedStorage/VerityPouch151.lua'):
    if 'require(script.Parent.PackShapes151)' in read(rel) or 'GetAttribute(\'PackShape\')' in read(rel):
        problems.append('%s must not use PackShapes151 or read a PackShape: the Verity pack is never shaped (R152)' % rel)
shapes = read('ReplicatedStorage/PackShapes151.lua')
if not re.search(r"function M\.Applies\(variantKey\)\n if [^\n]*variantKey==require\(script\.Parent\.VerityCatalog\)\.Variant then return false end", shapes):
    problems.append('PackShapes151.Applies must exclude the Verity variant (VerityCatalog.Variant): the Verity pack is never shaped (R152)')
pd0 = read('ServerScriptService/ChestChaseServer/PlayerDataService.lua')
if 'PackShapes.Applies(PackRules.VariantKey(row.BagVariant))' not in pd0:
    problems.append('PlayerDataService.savedPackShape must drop the shape of a pack that takes none (an older Verity record): PackShapes.Applies(PackRules.VariantKey(row.BagVariant))')
hot = read('ReplicatedStorage/InventoryStacks155.lua')  # (R155: the Hotbar's stack key moved here, shared with the server's discard)
if not re.search(r"S\.Fields=\{Pack=\{[^}]*'PackShape'", hot):
    problems.append("InventoryStacks155's Fields.Pack lacks 'PackShape': packs of different shapes would share a card")
chase = read('ServerScriptService/ChestChaseServer/ChaseService.lua')
if len(re.findall(r'chest\.PackShape\)', chase)) != 3:
    problems.append('ChaseService must pass chest.PackShape to the carry, the dropped pack and the dropped model (found %d)' % len(re.findall(r'chest\.PackShape\)', chase)))
chest = read('ServerScriptService/ChestChaseServer/ChestService.lua')
if 'tool:GetAttribute("PackShape")' not in chest or not re.search(r'tool:GetAttribute\("PackMutation"\),shape\)', chest):
    problems.append('ChestService._holdPack must put the tool\'s PackShape in the hand (CarryBag(..., shape))')
if 'tool:SetAttribute("PackShape",shape)' not in chest:
    problems.append('ChestService._createPackTool must give the tool its PackShape')
keeper = read('ServerScriptService/ChestChaseServer/ConcurrentKeeperService.lua')
if 'table.clone(seed)' not in keeper:
    problems.append('ConcurrentKeeperService must clone the whole seed on a steal (the shape rides along)')
cfg = read('ServerScriptService/ChestChaseServer/Config.lua')
versions = re.findall(r'Config\.ProfileVersion\s*=\s*(\d+)', cfg)
if not versions or versions[-1] != '22':
    problems.append('ProfileVersion must stay 22 (found %s)' % versions)
pd = read('ServerScriptService/ChestChaseServer/PlayerDataService.lua')
if pd.count('savedPackShape(') < 3:
    problems.append('PlayerDataService: the record field is decoded and serialised through savedPackShape (3 mentions expected)')
for line in problems:
    print('FAIL: ' + line)
if problems:
    sys.exit(1)
print('ok: PackShape is named by %d files, all of them the places a pack\'s own shape is made, kept or drawn; DefaultPackShape by %d (the mechanism; the market stalls and the shop viewport pass defaultShape); the hotbar stack key, the carry / drop / hand, the steal clone and ProfileVersion 22 are as expected' % (len(found), len(flagged)))
