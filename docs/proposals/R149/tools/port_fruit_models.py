"""R149: applies the PLAN rows of port_fruit_models.luau to the art modules.
Usage: python3 port_fruit_models.py <plan.txt> <base src dir> <out src dir>
Reads every module from the BASE commit's tree (<base src dir>/ReplicatedStorage/<file>.lua) and writes the edited module to
<out src dir>; modules with no PLAN row are not touched. For each (module, seed, design, group) the old fruit specs of that group are
replaced by the new ones, except the connector specs named in the row (they stay in place, byte for byte); the new specs go where the
first removed spec was. Two module styles: PlantArt* (one spec per line, keyed by seed id) and the single-line tables
(TreeReworkData*, ApprovedPlantArt*) whose Specs array is cut apart by brace matching."""
import os, re, sys

plan_path, base_src, out_src = sys.argv[1:4]
SEP = chr(31)
plans = {}
for line in open(plan_path, encoding='utf-8'):
    if not line.startswith('PLAN\t'):
        continue
    _, file, key, design, group, keep, lits = line.rstrip('\n').split('\t')
    plans.setdefault(file, []).append((key, int(design), int(group), [k for k in keep.split(',') if k], lits.split(SEP)))


def group_of(text):
    m = re.search(r'(?:\bg=|\["g"\]=)(\d+)', text)
    return int(m.group(1)) if m else -1


def name_of(text):
    m = re.search(r'(?:\bf=|\["f"\]=)"([^"]*)"', text)
    return m.group(1) if m else None


def rewrite(items, wanted):
    """items: spec texts (no separators). wanted: {group: (keep names, new literals)}. Returns the new list."""
    out, done = [], set()
    for it in items:
        g = group_of(it)
        if g in wanted:
            keep, lits = wanted[g]
            if name_of(it) in keep:
                out.append(it)
                continue
            if g not in done:
                done.add(g)
                out.extend(lits)
            continue
        out.append(it)
    missing = set(wanted) - done
    if missing:
        raise SystemExit('no old spec found for groups %s' % sorted(missing))
    return out


def split_children(text, open_at):
    """text[open_at] == '{': returns [(start, end)] of every direct child table and the index of the closing brace."""
    depth, start, spans, in_str, i = 0, None, [], False, open_at
    while True:
        ch = text[i]
        if in_str:
            if ch == '\\':
                i += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == '{':
            depth += 1
            if depth == 2:
                start = i
        elif ch == '}':
            if depth == 2:
                spans.append((start, i + 1))
            depth -= 1
            if depth == 0:
                return spans, i
        i += 1


# R149 tag comments (Lua comments between table entries, or above the return)
NOTE = {
    'SunflowerSeed': "-- R149: the Watermelon's two fruit are redesigned (ellipsoid rind, 7 stripe bands, stem, tendril, leaf, gloss); the 'Fruit stem' connector and everything else are as before.",
    'SnowdropSeed': "-- R149: the Snow Melon's two fruit are redesigned (the Watermelon build in frost colours plus a snow cap); the 'Fruit stem' connector and everything else are as before.",
    'EmberBloomSeed': "-- R149: the Ember Pumpkin's two fruit are redesigned (10 ribs around a dark heart, Neon ember grooves, curled stem, leaf, gloss); the 'Fruit stem' connector and everything else are as before.",
    'BluebellSeed': "-- R149: the Blueberry's four clusters are redesigned (3 bloomed berries, caps, stalk, stalklets, 2 leaves, glints); the first berry of each keeps its canopy / cd link to the shrub crown.",
    'IceberrySeed': "-- R149: the Iceberry's four clusters are redesigned (the Blueberry build in ice colours); the first berry of each keeps its canopy / cd link to the shrub crown.",
    'TreeReworkData2': "-- R149: the Apple's four fruit are redesigned (body, two shoulder lobes, base tone, dimple, stem, leaf, gloss); the 'Apple hanging stem' connector, the tree, sockets and fruit centres are as before.\n",
    'TreeReworkData4': "-- R149: Elderbloom's five elder apples are redesigned (the Apple build in jade / gold with its Neon rune); the tree, sockets and fruit centres are as before.\n",
    'ApprovedPlantArt6': "-- R149: the Prickly Pear's fruit (both designs, three each) are redesigned (barrel ellipsoid with a three-tone gradient, navel, scales, areoles, gloss), authored at half size around the socket (ApprovedPlantArt.Get grows the fruit x2); the 'Upper surface fruit attachment', the pads, sockets and fruit centres are as before.\n",
}


for file, rows in plans.items():
    path = os.path.join(base_src, 'ReplicatedStorage', file + '.lua')
    text = open(path, encoding='utf-8').read()
    if file.startswith('PlantArt'):
        for key in sorted({r[0] for r in rows}):
            wanted = {g: (keep, lits) for k, d, g, keep, lits in rows if k == key}
            m = re.search(r'^%s=\{\n' % re.escape(key), text, re.M)
            end = re.search(r'^\},?$', text[m.end():], re.M)
            body_start, body_end = m.end(), m.end() + end.start()
            lines = text[body_start:body_end].rstrip('\n').split('\n')
            items = [l[:-1] if l.endswith(',') else l for l in lines]
            new = rewrite(items, wanted)
            text = text[:body_start] + ',\n'.join(new) + '\n' + text[body_end:]
            m = re.search(r'^%s=\{\n' % re.escape(key), text, re.M)
            text = text[:m.start()] + NOTE[key] + '\n' + text[m.start():]
    else:
        designs = sorted({r[1] for r in rows}, reverse=True)  # edit the last design first so earlier offsets stay valid
        for design in designs:
            wanted = {g: (keep, lits) for k, d, g, keep, lits in rows if d == design}
            hits = [m.end() for m in re.finditer(r'\["Specs"\]=', text)]
            open_at = hits[design - 1]
            spans, close = split_children(text, open_at)
            items = [text[a:b] for a, b in spans]
            new = rewrite(items, wanted)
            text = text[:open_at] + '{' + ','.join(new) + '}' + text[close + 1:]
        text = NOTE[file] + text
    out = os.path.join(out_src, 'ReplicatedStorage', file + '.lua')
    open(out, 'w', encoding='utf-8', newline='').write(text)
    print('wrote', out)
