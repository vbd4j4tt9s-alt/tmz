"""Rebuilds copy.json (the strings the Verity window preview draws) from the real VerityConfig.lua / NoticeCopy83.lua text.
No Roblox needed: the texts are plain literals joined with ..   Usage: python3 gen_verity_copy.py copy.json   (keeps the colours of the old Arrival line)"""
import sys,os,re,json
def strings(src):
    """return list of (line, string_value, raw) for each string literal outside comments"""
    i=0;n=len(src);line=1
    out=[]
    while i<n:
        c=src[i]
        if c=='\n': line+=1;i+=1;continue
        if c=='-' and src.startswith('--',i):
            m=re.match(r'--\[(=*)\[',src[i:i+40])
            if m:
                close=']'+m.group(1)+']'
                j=src.find(close,i)
                if j<0:j=n
                line+=src[i:j].count('\n');i=j+len(close);continue
            j=src.find('\n',i)
            if j<0:j=n
            i=j;continue
        if c in '"\'':
            q=c;j=i+1;buf=[]
            while j<n and src[j]!=q:
                if src[j]=='\\' and j+1<n:
                    d=src[j+1]
                    if d=='n':buf.append('\n')
                    elif d=='t':buf.append('\t')
                    elif d=='\\':buf.append('\\')
                    elif d in '"\'':buf.append(d)
                    elif d=='u':
                        m=re.match(r'\\u\{([0-9a-fA-F]+)\}',src[j:j+14])
                        if m:
                            buf.append(chr(int(m.group(1),16)));j+=len(m.group(0));continue
                        buf.append(src[j:j+2])
                    elif d.isdigit():
                        m=re.match(r'\\(\d{1,3})',src[j:j+5])
                        buf.append(chr(int(m.group(1))));j+=len(m.group(0));continue
                    elif d=='\n':
                        buf.append('\n');line+=1
                    else: buf.append(src[j:j+2])
                    j+=2;continue
                if src[j]=='\n': break
                buf.append(src[j]);j+=1
            out.append((line,''.join(buf),src[i:j+1]))
            i=j+1;continue
        if c=='[':
            m=re.match(r'\[(=*)\[',src[i:i+10])
            if m:
                close=']'+m.group(1)+']'
                j=src.find(close,i+len(m.group(0)))
                if j<0:j=n
                val=src[i+len(m.group(0)):j]
                out.append((line,val,src[i:j+len(close)]))
                line+=src[i:j].count('\n');i=j+len(close);continue
        i+=1
    return out
ROOT=os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','..','..'))
cfg=open(ROOT+'/src/ReplicatedStorage/VerityConfig.lua',encoding='utf8').read()
cat=open(ROOT+'/src/ReplicatedStorage/VerityCatalog.lua',encoding='utf8').read()
pack=re.search(r"PackName='([^']*)'",cat).group(1) if re.search(r"PackName='([^']*)'",cat) else 'Verity Pack'
def ev(expr):
    out=''
    for part in re.split(r'\.\.(?=(?:[^\'"]*[\'"][^\'"]*[\'"])*[^\'"]*$)',expr):
        part=part.strip()
        if part.startswith(("'",'"')): out+=strings(part)[0][1]
        elif part=='Catalog.PackName': out+=pack
        elif part=='Catalog.PackName:upper()': out+=pack.upper()
        else: raise SystemExit('cannot evaluate '+part)
    return out
def line(prefix):
    m=re.search(r'^'+re.escape(prefix)+r'=(.*)$',cfg,re.M);return ev(m.group(1))
def table(name):
    m1=re.search(r'^C\.'+name+r'=\{(.*)\}\s*$',cfg,re.M)
    if m1: body=m1.group(1)
    else:
        m=re.search(r'^C\.'+name+r'=\{\s*$(.*?)^\}',cfg,re.M|re.S);body=m.group(1)
    d={}
    for k,q in re.findall(r"(\w+)=((?:'(?:\\.|[^'\\])*')|(?:\"(?:\\.|[^\"\\])*\"))",body):
        d[k]=strings(q)[0][1]
    return d
old=json.load(open(ROOT+'/docs/proposals/R152/preview/copy.json',encoding='utf8'))
new=dict(old)
new['Quest']=line('C.Quest');new['RewardText']=line('C.RewardText');new['Thanks']=line('C.Thanks');new['Notice']=line('C.Notice')
new['Dialog']=table('Dialog');new['Hint']=table('Hint');new['Reasons']=table('Reasons')
ev_=re.search(r"C\.Event=\{(.*?)\}",cfg).group(1)
new['Event']={k:strings(q)[0][1] for k,q in re.findall(r"(\w+)=('(?:\\.|[^'\\])*')",ev_)}
nc=open(ROOT+'/src/ReplicatedStorage/NoticeCopy83.lua',encoding='utf8').read()
arr=old['Arrival']
head=re.search(r"function N\.Arrival\(\)return (.*?)end\n",nc,re.S).group(1)
texts=[v for _,v,_ in strings(head)]
# rebuild with the old colours: texts[0]='🌑 ', then coloured runs
arr=re.sub(r'<font color="#DDC3FF">.*?</font>','<font color="#DDC3FF">'+[x for x in texts if 'Darkened' in x][0]+'</font>',arr)
mid=[x for x in texts if ' in ' in x and 'Storm' not in x][0]
arr=re.sub(r'</font> [a-z ]+ in <font color="#A2BBFF">','</font>'+mid+'<font color="#A2BBFF">',arr)
new['Arrival']=arr
# the Dialog's Here is built inside the table in this file
json.dump(new,open(sys.argv[1],'w',encoding='utf8'),ensure_ascii=False,indent=1,sort_keys=True)
print('wrote',sys.argv[1]);print(new['Quest']);print(new['Dialog']['Here']);print(new['Arrival'])
