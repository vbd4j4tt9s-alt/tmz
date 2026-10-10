"""R153: the R123 server bundle (every ReplicatedStorage and ChestChaseServer module; OUT/srv_names.luau) plus, when given, the R152 BalanceValues81.lua as the module BalanceValues81Base
(the Index test compares the two: only the Index gems may differ). Usage: python3 mkbundle_index.py OUTDIR [R152_BalanceValues81.lua]"""
import sys, os, subprocess
out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
subprocess.run([sys.executable, os.path.join(here, '../../treadmill_bonus_R123/tests/mkbundle.py'), out], check=True, stdout=subprocess.DEVNULL)
if len(sys.argv) > 2 and os.path.isfile(sys.argv[2]):
    path = os.path.join(out, 'rs_bundle.luau')
    s = open(path, encoding='utf-8').read()
    src = open(sys.argv[2], 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in src: level += 1
    eq = '=' * level
    assert s.rstrip().endswith('}')
    s = s.rstrip()[:-1] + '["BalanceValues81Base"]=[%s[\n%s]%s],\n}' % (eq, src, eq)
    open(path, 'w', encoding='utf-8').write(s)
    print('BalanceValues81Base added')
