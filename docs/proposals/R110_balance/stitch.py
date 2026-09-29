"""Builds /home/user/tmz/docs/proposals/R110_balancing_proposal.md from doc_template.md + generated tables."""
import re, os
t = open('doc_template.md').read()
fixes = {'`ReplicatedStorage/PackOdds81.lua:4-26`': '`ReplicatedStorage/PackOdds81.lua:4-25`',
         'the R37 re-tier table (`SeedPackRules.lua:163`, `PlantCatalog`)': 'the R37 re-tier table (`SeedPackRules.lua:164`, `PlantCatalog`)',
         '(`RunnerMotion.lua:2,9-15`)': '(`RunnerMotion.lua:2,9-14`)',
         '  Common to Mythic stay close to today.': '  Common to Legendary stay close to today; Mythic gets somewhat rarer (1 in 77 -> 1 in 200 in a Common pack).',
         'Players between about 1K and 10M saved points run 20-25% slower than today': 'Players between about 1K and 10M saved points run 15-25% slower than today'}
for a, b in fixes.items():
    t = t.replace(a, b)
secs = {}
for f in ['out_rarity.md', 'out_speed.md', 'out_sim.md']:
    for p in re.split(r'(?m)^(?=### )', open(f).read()):
        m = re.match(r'### (T\d|S\d|SIM\d)\.', p)
        if m:
            secs[m.group(1)] = p.strip()
secs['R108'] = open('out_r108.md').read().strip()
out = re.sub(r'\{\{(\w+)\}\}', lambda m: secs[m.group(1)], t)
assert '{{' not in out
os.makedirs('/home/user/tmz/docs/proposals', exist_ok=True)
open('/home/user/tmz/docs/proposals/R110_balancing_proposal.md', 'w').write(out)
print(len(out.splitlines()), 'lines')
