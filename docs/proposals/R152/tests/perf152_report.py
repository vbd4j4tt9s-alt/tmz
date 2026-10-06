"""R152 performance patch: the numbers of run_perf152.sh, before -> after. Reads every "PERF ..." line of <base dir>/*/*.out and <now dir>/*/*.out (the same
run on both sides), pairs them by their label (the text before the first number) and prints the main values side by side: instances / parts / MeshParts /
SurfaceGuis / labels drawn, property writes a frame (and how many of them wrote the value already there), instances made a frame, Lua ms a frame on the mock.
Usage: python3 perf152_report.py <base dir> <now dir>"""
import collections, glob, gzip, os, re, sys

KEYS = ('frames=', 'lua:', 'instances=', 'writes/frame=')


def lines(root):
    out = collections.OrderedDict()
    for path in sorted(glob.glob(os.path.join(root, '*', '*.out.gz'))):
        run = os.path.basename(path)[:-7]
        for l in gzip.open(path, 'rt', encoding='utf-8', errors='replace'):
            if not l.startswith('PERF ') or 'DONE' in l:
                continue
            body = l[5:].strip()
            cut = min([body.find(k) for k in KEYS if body.find(k) >= 0] or [len(body)])
            out[(run, body[:cut].strip())] = body[cut:]
    return out


def values(text):
    v = collections.OrderedDict()
    for k in ('instances', 'parts', 'meshparts', 'drawn', 'surfaceguis', 'labels', 'emitters', 'beams', 'lights'):
        m = re.search(r'(?:^|[ |])' + k + r'=(\d+)', text)
        if m:
            v[k] = int(m.group(1))
    for k in ('writes/frame', 'same/frame', 'made/frame'):
        m = re.search(re.escape(k) + r'=([\d.]+)', text)
        if m:
            v[k] = float(m.group(1))
    ms = re.findall(r'([A-Za-z0-9_]+) ([\d.]+) ms', text)
    if ms:
        v['lua ms'] = round(sum(float(x[1]) for x in ms), 3)
        for name, x in ms:
            if float(x) > 0:
                v[name + ' ms'] = float(x)
    return v


def main():
    a, b = lines(sys.argv[1]), lines(sys.argv[2])
    for key, ta in a.items():
        tb = b.get(key)
        if tb is None:
            continue
        va, vb = values(ta), values(tb)
        cells = []
        for k in va:
            if k in vb:
                x, y = va[k], vb[k]
                cells.append('%s %s -> %s' % (k, x, y) if x != y else '%s %s' % (k, x))
        print('%-22s %-46s %s' % (key[0], key[1][:46], '; '.join(cells)))


if __name__ == '__main__':
    main()
