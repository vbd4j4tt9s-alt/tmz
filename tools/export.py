import rbxl, os, sys, re, collections
src, out = sys.argv[1], sys.argv[2]
inst, par = rbxl.load(src)
SC = ('Script','LocalScript','ModuleScript')
kids = collections.defaultdict(list)
for c,p in par.items(): kids[p].append(c)
def has_script_desc(r):
    return any(inst[c]['ClassName'] in SC or has_script_desc(c) for c in kids[r])
def ext(i):
    c=i['ClassName']
    if c=='ModuleScript': return '.lua'
    if c=='LocalScript' or (c=='Script' and i.get('RunContext')==2): return '.client.lua'
    return '.server.lua'
def safe(n): return re.sub(r'[<>:"/\\|?*\x00-\x1f]','_',n) or '_'
count=0; manifest=[]
def walk(r, d, logical):
    global count
    used=collections.Counter()
    for c in sorted(kids[r], key=lambda x:(inst[x].get('Name',b''),x)):
        i=inst[c]; name=i.get('Name',b'?').decode('utf-8','replace')
        if logical==[] and name=='ServerStorage': continue  # backups archive
        is_s = i['ClassName'] in SC; deep = has_script_desc(c)
        if not is_s and not deep: continue
        n=safe(name); used[n]+=1
        if used[n]>1: n=f"{n}~{used[n]}"
        lp=logical+[name]
        if is_s and not deep:
            path=os.path.join(d,n+ext(i))
        else:
            sub=os.path.join(d,n); os.makedirs(sub,exist_ok=True)
            path=os.path.join(sub,'init'+ext(i)) if is_s else None
            walk(c, sub, lp)
        if path:
            os.makedirs(os.path.dirname(path),exist_ok=True)
            open(path,'wb').write(i.get('Source',b''))
            count+=1; manifest.append(f"{i['ClassName']}\t{'/'.join(lp)}\t{os.path.relpath(path,out)}")
walk(-1, out, [])
open(os.path.join(out,'MANIFEST.tsv'),'w').write('class\tpath_in_place\tfile\n'+'\n'.join(sorted(manifest,key=lambda l:l.split('\t')[1]))+'\n')
print(count)
