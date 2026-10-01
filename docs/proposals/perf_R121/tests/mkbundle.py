"""mkbundle.py OUT root [name=path ...] -> bundles every ReplicatedStorage module + overrides as {name=source}."""
import sys,os,glob
out=sys.argv[1]; root=sys.argv[2]; extra=sys.argv[3:]
srcs={}
for p in glob.glob(os.path.join(root,'*.lua')):
    n=os.path.basename(p)[:-4]
    if n.endswith('.client') or n.endswith('.server'): continue
    srcs[n]=p
for e in extra:
    n,p=e.split('=',1); srcs[n]=p
parts=['return {']
for n,p in sorted(srcs.items()):
    s=open(p,'rb').read().decode('utf-8')
    lvl=1
    while (']'+'='*lvl+']') in s: lvl+=1
    eq='='*lvl
    parts.append('["%s"]=[%s[\n%s]%s],'%(n,eq,s,eq))
parts.append('}')
open(out,'w',encoding='utf-8').write('\n'.join(parts))
print('bundled',len(srcs))
