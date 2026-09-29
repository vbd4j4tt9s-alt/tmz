import proposed as PR
from data import *
def check(verbose=False):
    B=[('none',1)]+list(zip(BOOTS,PR.BOOT_LUCK))
    viol=0; minfl=(1,None)
    for st in BIOME_ORDER:
        for mode in ('boot','pack'):
            outer = B if mode=='pack' else PACKS
            for o_ in outer:
                prev=None
                inner = PACKS if mode=='pack' else B
                for i_ in inner:
                    pk, (name,L) = (i_, o_) if mode=='pack' else (o_, i_)
                    o=PR.tier_odds(st,pk,L)
                    fl=min(o,key=lambda t:PR.RANK[t])
                    if o[fl]<minfl[0]: minfl=(o[fl],(BIOME_NAME[st],pk,name))
                    if prev:
                        for t in PR.TIERS:
                            a=sum(v for q,v in prev.items() if PR.RANK[q]>=PR.RANK[t]); b=sum(v for q,v in o.items() if PR.RANK[q]>=PR.RANK[t])
                            if b<a-1e-12:
                                viol+=1
                                if verbose: print(mode,BIOME_NAME[st],pk,name,t,round(a,4),round(b,4))
                    prev=o
    return viol,minfl
if __name__=='__main__':
    print(check(True))
