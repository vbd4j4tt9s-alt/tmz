"""Bundle every ReplicatedStorage module plus the client scripts the R124 polish tests load into OUT/rs_bundle.luau."""
import sys, os
out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, '../../../../src'))
pairs = [(f[:-4], src + '/ReplicatedStorage/' + f) for f in sorted(os.listdir(src + '/ReplicatedStorage')) if f.endswith('.lua')]
for n in ('BiomeEntryNotifier', 'TreadmillBonusClient', 'TrackRefreshSky', 'KeeperHitEffects', 'VeiledEventClient81', 'BiomeEffectGovernor', 'GardenLiftPrompts', 'OfflineGrowthNotice'):
    pairs.append((n, src + '/StarterPlayer/StarterPlayerScripts/' + n + '.client.lua'))
parts = ['return {']
for name, path in pairs:
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s: level += 1
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, '=' * level, s, '=' * level))
parts.append('}')
open(os.path.join(out, 'rs_bundle.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
print(len(pairs), 'modules')
