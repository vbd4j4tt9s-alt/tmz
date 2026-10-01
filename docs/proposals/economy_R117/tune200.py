import sim,math,json,sys
from live import *
def rnd(v):
    unit=10**(math.floor(math.log10(v))-1);return math.floor(v/unit+.5)*unit   # 2 significant figures
base=sim.live_economy()
prices={'machine':list(base.machine_cost),'trail':list(base.trail_cost),'boot':list(base.boot_cost),'fence':list(base.fence_cost)}
# index -> target hours; only these are tuned, everything else keeps today's price
T={('machine',5):20,('machine',6):180,('trail',3):5,('trail',4):60,('trail',5):200,('boot',3):12,('boot',4):150,('fence',5):10,('fence',6):100}
def key(k,i):
    if k=='machine':return 'machine%d'%(i+1)
    if k=='trail':return 'trail:'+TRAILS[i]
    if k=='boot':return 'boot:'+BOOTS[i]
    return 'fence%d'%(i+1)
def eco(pr):
    e=sim.live_economy();e.machine_cost,e.trail_cost,e.boot_cost,e.fence_cost=pr['machine'],pr['trail'],pr['boot'],pr['fence'];return e
CAP=8.9e14
for it in range(36):
    ev,_=sim.simulate(eco(prices),runs=24,seed=300+it,CHECKPOINTS=(300,))
    worst=0
    for (k,i),tgt in T.items():
        got=ev.get(key(k,i),(None,0))[0];gh=330 if got is None else got/3600
        r=tgt/max(gh,.02);worst=max(worst,abs(math.log(r)))
        prices[k][i]=min(CAP,prices[k][i]*min(8,max(1/8,r))**.5)
    for k in prices:
        for i in range(1,len(prices[k])):prices[k][i]=max(prices[k][i],prices[k][i-1]*1.5)
    print(it,'worst %.2f'%worst,file=sys.stderr)
out={k:[rnd(v) if v>0 else 0 for v in vs] for k,vs in prices.items()}
json.dump(out,open('prices200.json','w'));print(json.dumps(out))
