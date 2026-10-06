"""R152 performance patch: compares the fingerprints of two runs of the perf152 drivers (BEFORE = the R152 candidate, AFTER = this checkout).
Usage: python3 perf152_canon.py before.txt after.txt [--area NAME] [--max N]

A dump holds (perf152_fp.luau):
  "SHOT <label>" ... "END <n>"   one line per instance: depth, mark, class, name, every property, attributes, tags
  "FRAME <stream>\\t<frame>" ... "FEND"   a frame of a stream: "+ id\\tparent\\tmark\\tclass\\tname\\t..." (new / changed), "- id" (gone)
  "FACT <label>\\t<text>"        a sound schedule, the camera ...: compared as text
  "PERF ..."                     numbers for perf.md: not compared
For every shot / frame both trees are reduced to what is DRAWN (a node is kept when it is drawn (mark 1), when something under it is kept, or when it is a
modifier (mark m) of a drawn node); siblings are compared in any order. Verdicts:
  identical      the whole tree is the same, never-drawn nodes included
  same-visible   what is drawn is the same; only never-drawn instances differ (listed: the allowed differences)
  offscreen      the label carries "OFFSCREEN=<path>[,<path>]": what is under those paths is left out (an update rate that changed while it is off screen;
                 the shots after it, on screen again, must be identical or same-visible)
  DIFFERENT      something drawn differs: the first differences are printed and the exit status is 1
FACT lines must be equal label by label; a label on one side only is DIFFERENT."""
import collections, gzip, hashlib, re, sys


def H(s):
    return hashlib.sha1(s.encode('utf-8', 'surrogatepass')).hexdigest()


class Node:
    __slots__ = ('id', 'pid', 'line', 'vis', 'name', 'cls', 'kids', 'dirty', 'pd', 'hf', 'hv', 'kept', 'parent', 'skip')

    def __init__(self, id_):
        self.id = id_
        self.kids = set()
        self.dirty = True
        self.pd = None
        self.parent = None
        self.skip = False


def compute(n, pd):
    if not n.dirty and n.pd == pd:
        return
    drawn = n.vis == '1'
    hf, hv = [], []
    anykept = False
    for c in n.kids:
        compute(c, drawn)
        if c.skip:
            continue
        hf.append(c.hf)
        if c.kept:
            hv.append(c.hv)
            anykept = True
    hf.sort()
    hv.sort()
    n.hf = H(n.line + '\n' + '\n'.join(hf))
    n.kept = drawn or (n.vis == 'm' and pd) or anykept
    n.hv = H(n.line + '\n' + '\n'.join(hv)) if n.kept else None
    n.dirty = False
    n.pd = pd


class Tree:
    """the instances of one shot or stream, with cached subtree hashes"""

    def __init__(self):
        self.nodes = {}
        self.roots = set()

    def touch(self, n):
        while n is not None and not n.dirty:
            n.dirty = True
            n = n.parent
        # (an ancestor of a dirty node is dirty)

    def put(self, id_, pid, vis, line):
        n = self.nodes.get(id_)
        if n is None:
            n = Node(id_)
            self.nodes[id_] = n
        else:
            if n.parent is not None:
                n.parent.kids.discard(n)
                self.touch(n.parent)
            else:
                self.roots.discard(n)
        parts = line.split('\t', 2)
        n.cls, n.name = parts[0], parts[1] if len(parts) > 1 else ''
        n.vis, n.line, n.pid = vis, vis + '\t' + line, pid
        n.dirty = False
        n.parent = self.nodes.get(pid) if pid else None
        if n.parent is not None:
            n.parent.kids.add(n)
        else:
            self.roots.add(n)
        n.dirty = True
        self.touch(n.parent)

    def drop(self, id_):
        n = self.nodes.pop(id_, None)
        if n is None:
            return
        if n.parent is not None:
            n.parent.kids.discard(n)
            self.touch(n.parent)
        else:
            self.roots.discard(n)

    def path(self, n):
        t = []
        while n is not None:
            t.append(n.name)
            n = n.parent
        return '/'.join(reversed(t))

    def digest(self, skip=None):
        if skip:
            # off-screen subtrees: matched by the full path the driver printed (the path of the root's ancestors is in the ROOT line / first node)
            for n in self.nodes.values():
                p = self.fullpath(n)
                old = n.skip
                n.skip = any(p == x or p.startswith(x + '/') for x in skip)
                if n.skip != old:
                    self.touch(n.parent)
        elif any(n.skip for n in self.nodes.values()):
            for n in self.nodes.values():
                if n.skip:
                    n.skip = False
                    self.touch(n.parent)
        for r in self.roots:
            compute(r, False)
        rs = [r for r in self.roots if not r.skip]
        full = H('\n'.join(sorted(r.hf for r in rs)))
        vis = H('\n'.join(sorted(r.hv for r in rs if r.kept)))
        return full, vis

    def fullpath(self, n):
        """the path printed by the driver: a shot's root carries its full path (its ROOT line); a stream's roots are their own names"""
        r = self.rootof(n)
        base = getattr(self, 'base', {}).get(r.id)
        p = self.path(n)
        return base + p[len(r.name):] if base else p

    def rootof(self, n):
        while n.parent is not None:
            n = n.parent
        return n

    def flat(self, visible, skip=None):
        out = collections.Counter()
        for n in self.nodes.values():
            if skip and n.skip:
                continue
            if visible and not n.kept:
                continue
            out[self.path(n.parent) + ' :: ' + n.line if n.parent else n.line] += 1
        return out


def shot_tree(lines):
    """a SHOT block as a Tree (ids made up from the order)"""
    t = Tree()
    t.base = {}
    stack = []
    root_path = ''
    i = 0
    for l in lines:
        if l.startswith('ROOT '):
            root_path = l[5:]
            stack = []
            continue
        depth, vis, rest = l.split('\t', 2)
        d = int(depth)
        i += 1
        del stack[d:]
        pid = stack[-1] if stack else 0
        t.put(i, pid, vis, rest)
        if pid == 0:
            t.base[i] = root_path
        stack.append(i)
    return t


def blocks(path):
    """yields ('shot', label, lines) / ('frame', stream, label, lines) / ('fact', label, text)"""
    cur = None
    opener = gzip.open if path.endswith('.gz') else open
    with opener(path, 'rt', encoding='utf-8', errors='replace') as f:
        for raw in f:
            line = raw.rstrip('\n')
            if cur is not None:
                if line.startswith('END ') and cur[0] == 'shot':
                    yield cur
                    cur = None
                elif line == 'FEND' and cur[0] == 'frame':
                    yield cur
                    cur = None
                else:
                    cur[-1].append(line)
                continue
            if line.startswith('SHOT '):
                cur = ('shot', line[5:], [])
            elif line.startswith('FRAME '):
                s, _, lab = line[6:].partition('\t')
                cur = ('frame', s, lab, [])
            elif line.startswith('FACT '):
                k, _, v = line[5:].partition('\t')
                yield ('fact', k, v)


def offscreen(label):
    m = re.search(r'OFFSCREEN=(\S+)', label)
    return m.group(1).split(',') if m else None


def fold(s):
    return re.sub(r'\d+', 'N', s)


def walk(path, want=None):
    """yields (label, tree-after-this-shot-or-frame, skip); want = labels whose trees are needed (otherwise the tree object is reused)"""
    streams = {}
    for b in blocks(path):
        if b[0] == 'fact':
            yield ('fact', b[1], b[2])
            continue
        if b[0] == 'shot':
            label = b[1]
            yield ('tree', label, shot_tree(b[2]))
            continue
        _, s, lab, lines = b
        t = streams.get(s)
        if t is None:
            t = streams[s] = Tree()
            t.vals = {}
        vals = t.vals
        touched = set()
        for l in lines:
            op = l[:2]
            if op == '+ ':
                f = l[2:].split('\t')
                id_ = int(f[0])
                vals[id_] = [int(f[1]), f[2], f[3], f[4], {}]
                d = vals[id_][4]
                for tok in f[5:]:
                    if tok.startswith('#'):
                        d['#'] = tok
                    else:
                        k, _, v = tok.partition('=')
                        d[k] = tok
                touched.add(id_)
            elif op == '^ ':
                id_, pid, vis = l[2:].split('\t')
                e = vals[int(id_)]
                e[0], e[1] = int(pid), vis
                touched.add(int(id_))
            elif op == '~ ':
                f = l[2:].split('\t')
                id_ = int(f[0])
                d = vals[id_][4]
                for tok in f[1:]:
                    if tok.startswith('#'):
                        if tok == '#':
                            d.pop('#', None)
                        else:
                            d['#'] = tok
                    elif '=' in tok:
                        d[tok.partition('=')[0]] = tok
                    else:
                        d.pop(tok, None)
                touched.add(id_)
            elif op == '- ':
                id_ = int(l[2:])
                vals.pop(id_, None)
                touched.discard(id_)
                t.drop(id_)
        # (every node of this frame exists before any is linked: a child may move under a parent made in the same frame)
        for id_ in touched:
            if id_ not in t.nodes:
                t.nodes[id_] = Node(id_)
        for id_ in sorted(touched):
            e = vals[id_]
            t.put(id_, e[0], e[1], e[2] + '\t' + e[3] + '\t' + '\t'.join(sorted(e[4].values())))
        yield ('tree', s + ' ' + lab, t)


def main():
    a_path, b_path = sys.argv[1], sys.argv[2]
    area = sys.argv[sys.argv.index('--area') + 1] if '--area' in sys.argv else ''
    maxn = int(sys.argv[sys.argv.index('--max') + 1]) if '--max' in sys.argv else 12
    DA, FA, order = {}, {}, []
    for kind, label, x in walk(a_path):
        if kind == 'fact':
            FA[label] = x
        else:
            DA[label] = x.digest(offscreen(label))
            order.append(label)
    verdict = collections.Counter()
    need = {}
    seen = set()
    FB = {}
    bad = []
    for kind, label, x in walk(b_path):
        if kind == 'fact':
            FB[label] = x
            continue
        seen.add(label)
        if label not in DA:
            verdict['DIFFERENT'] += 1
            bad.append((label, ['only in AFTER']))
            continue
        skip = offscreen(label)
        fb, vb = x.digest(skip)
        fa, va = DA[label]
        if fa == fb:
            verdict['offscreen' if skip else 'identical'] += 1
        elif va == vb:
            verdict['offscreen' if skip else 'same-visible'] += 1
            need[label] = 'hidden'
        else:
            verdict['DIFFERENT'] += 1
            need[label] = 'bad'
    for label in order:
        if label not in seen:
            verdict['DIFFERENT'] += 1
            bad.append((label, ['only in BEFORE']))
    # the shots / frames that differ: hidden differences are listed (by class and name, digits folded), drawn ones printed
    hidden = collections.Counter()
    if need:
        A = {}
        for kind, label, x in walk(a_path):
            if kind == 'tree' and label in need:
                x.digest(offscreen(label))
                A[label] = (x.flat(False, True), x.flat(True, True))
        shown = 0
        for kind, label, x in walk(b_path):
            if kind != 'tree' or label not in need:
                continue
            x.digest(offscreen(label))
            fa, va = A[label]
            if need[label] == 'hidden':
                fb = x.flat(False, True)
                for k, v in (fa - fb).items():
                    line = k.partition(' :: ')[2] or k
                    cls, name = line.split('\t')[1:3]
                    hidden['%s %s: before only' % (cls, fold(name))] += v
                for k, v in (fb - fa).items():
                    line = k.partition(' :: ')[2] or k
                    cls, name = line.split('\t')[1:3]
                    hidden['%s %s: after only' % (cls, fold(name))] += v
            elif shown < maxn:
                shown += 1
                vb = x.flat(True, True)
                diff = ['- (%d) %s' % (v, k[:500]) for k, v in list((va - vb).items())[:maxn]]
                diff += ['+ (%d) %s' % (v, k[:500]) for k, v in list((vb - va).items())[:maxn]]
                bad.append((label, diff))
            else:
                bad.append((label, []))
    facts_bad = [(k, FA.get(k), FB.get(k)) for k in sorted(set(FA) | set(FB)) if FA.get(k) != FB.get(k)]
    total = sum(verdict.values())
    print('%s: %d shots / frames: %s; %d facts, %d differ' % (area or a_path, total, ', '.join('%s %d' % (k, v) for k, v in sorted(verdict.items())),
                                                           len(set(FA) | set(FB)), len(facts_bad)))
    for k, v in sorted(hidden.items()):
        print('  allowed (never drawn): %s x%d' % (k, v))
    printed = 0
    for label, diff in bad:
        if printed >= maxn:
            print('  ... %d more DIFFERENT' % (len(bad) - printed))
            break
        printed += 1
        print('  DIFFERENT %s' % label)
        for d in diff:
            print('    ' + d)
    for k, a, b in facts_bad[:maxn]:
        print('  FACT DIFFERS %s\n    before: %s\n    after:  %s' % (k, (a or '')[:600], (b or '')[:600]))
    sys.exit(1 if bad or facts_bad else 0)


if __name__ == '__main__':
    main()
