--!nocheck
-- R127: world pack spawn odds (Legendary 3%, Mythic 1%) and the buffed pack sizes, through the real SeedPackRules.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local P=W.module('SeedPackRules');local Rare=W.module('RarePackRules');local Schedule=W.module('PackSchedule81')
local total=0;for _,k in ipairs(P.VariantOrder)do total+=P.Variants[k].SpawnWeight end
check(math.abs(total-100)<1e-9,'spawn weights sum to 100 ('..total..')')
check(P.Variants.Pack05.SpawnWeight==3 and P.GetPackTier('Pack05').Name=='Legendary','Legendary spawn weight 3%')
check(P.Variants.Pack06.SpawnWeight==1 and P.GetPackTier('Pack06').Name=='Mythic','Mythic spawn weight 1%')
local w={};for i,k in ipairs(P.VariantOrder)do w[i]=P.Variants[k].SpawnWeight end
check(math.abs(w[1]/w[2]-38/25)<.01 and math.abs(w[2]/w[3]-25/15)<.01 and math.abs(w[3]/w[4]-15/7)<.02,'Common..Epic keep the 38:25:15:7 shape')
-- Real roller over many uniform tickets
math.randomseed(127);local n=400000;local count={}
for _=1,n do local k=P.RollVariant(math.random());count[k]=(count[k]or 0)+1 end
for i,k in ipairs(P.VariantOrder)do local p=w[i]/100;local got=(count[k]or 0)/n
 check(math.abs(got-p)<=4*math.sqrt(p*(1-p)/n),string.format('%s spawns %.2f%% (want %.1f%%)',P.GetPackTier(k).Name,got*100,p*100))end
-- Floors unchanged: a Legendary every 5th refresh, a Mythic every 10th.
local plan=Schedule.Plan(10,table.create(35,'Pack01'),function(lo)return lo end)
check(table.find(plan,'Pack05')and table.find(plan,'Pack06'),'refresh 10 still guarantees a Legendary and a Mythic')
local plain=Schedule.Plan(7,table.create(35,'Pack01'),function(lo)return lo end);check(not table.find(plain,'Pack05'),'no floor on refresh 7')
-- Announcement odds follow the weights
local p5=Rare.Probability('Pack05',1,'None',{});check(p5 and math.abs(p5-.03*P.PackSizes[2].Weight/100*.95)<1e-9,'announcement odds use the new Legendary weight')
-- Sizes
local s=0;for _,r in ipairs(P.PackSizes)do s+=r.Weight end;check(math.abs(s-100)<1e-9,'size weights sum to 100')
local function share(min)local t=0;for _,r in ipairs(P.PackSizes)do if r.Scale>=min then t+=r.Weight end end;return t end
check(share(5)>=.5 and share(5)<=1,string.format('5x and bigger: %.3f%% (was 0.051%%)',share(5)))
check(share(10)>=.04,string.format('10x and bigger: %.3f%% (was 0.003%%)',share(10)))
local old={[.5]=3,[1]=80.799,[1.5]=13,[2.5]=2.8,[3.5]=.35,[5]=.04,[7.5]=.008,[10]=.002,[15]=.0007,[20]=.0002,[25]=.0001}
local up=true;for _,r in ipairs(P.PackSizes)do if r.Scale>1 and r.Weight<=old[r.Scale]then up=false end end
check(up,'every size above 1x is more common than before')
check(P.PackSizes[1].Scale==.5 and P.PackSizes[1].Weight==3,'0.5x unchanged at 3%')
local sc={};for _=1,n do local v=P.RollPackSize(math.random());sc[v]=(sc[v]or 0)+1 end
for _,r in ipairs(P.PackSizes)do if r.Weight>=.4 then local p=r.Weight/100;local got=(sc[r.Scale]or 0)/n
 check(math.abs(got-p)<=4*math.sqrt(p*(1-p)/n),string.format('size %sx rolls %.3f%% (want %.3f%%)',r.Scale,got*100,p*100))end end
check(P.RollPackSize(.99999999)==25 and P.RollPackSize(0)==.5,'table ends roll 0.5x and 25x')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
