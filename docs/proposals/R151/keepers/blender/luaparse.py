"""Minimal Lua table literal reader (enough for KeeperRigConfig / KeeperUpgradeData)."""
import re


class P:
    def __init__(s, t):
        s.t = t
        s.i = 0

    def ws(s):
        while s.i < len(s.t):
            c = s.t[s.i]
            if c in ' \t\r\n':
                s.i += 1
            elif s.t.startswith('--', s.i):
                j = s.t.find('\n', s.i)
                s.i = len(s.t) if j < 0 else j
            else:
                break

    def val(s):
        s.ws()
        c = s.t[s.i]
        if c == '{':
            return s.table()
        if c in '"\'':
            q = c
            j = s.i + 1
            out = ''
            while s.t[j] != q:
                if s.t[j] == '\\':
                    out += s.t[j + 1]
                    j += 2
                else:
                    out += s.t[j]
                    j += 1
            s.i = j + 1
            return out
        m = re.match(r'-?[0-9.]+(?:[eE][-+]?\d+)?', s.t[s.i:s.i + 40])
        if m:
            s.i += len(m.group())
            return float(m.group())
        for kw, v in (('true', True), ('false', False), ('nil', None)):
            if s.t.startswith(kw, s.i):
                s.i += len(kw)
                return v
        raise Exception('bad at %d: %s' % (s.i, s.t[s.i:s.i + 50]))

    def table(s):
        s.i += 1
        arr = []
        d = {}
        while True:
            s.ws()
            if s.t[s.i] == '}':
                s.i += 1
                break
            if s.t[s.i] == '[':
                s.i += 1
                k = s.val()
                s.ws()
                assert s.t[s.i] == ']'
                s.i += 1
                s.ws()
                assert s.t[s.i] == '='
                s.i += 1
                d[k] = s.val()
            else:
                m = re.match(r'([A-Za-z_]\w*)\s*=(?!=)', s.t[s.i:s.i + 80])
                if m:
                    s.i += len(m.group())
                    d[m.group(1)] = s.val()
                else:
                    arr.append(s.val())
            s.ws()
            if s.t[s.i] in ',;':
                s.i += 1
        if d and not arr:
            if all(isinstance(k, float) for k in d):
                return {int(k): v for k, v in d.items()}
            return d
        if arr and not d:
            return arr
        if not arr and not d:
            return []
        for i, v in enumerate(arr):
            d[i + 1] = v
        return d


def parse_table_at(text, start):
    p = P(text)
    p.i = start
    return p.table()
