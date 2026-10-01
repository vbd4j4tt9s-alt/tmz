--!nocheck
-- R118 fruit bonuses (real BalanceRules + WeatherTraits + HarvestSellMenu text): size x coat x weather, capped x100.
local World=require('./world');local W=World.build({})
local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local B=W.req(W.RS.BalanceRules);local Wt=W.req(W.RS.WeatherTraits)
local function m(size,coat,weather)return B.CashMultiplier(B.SizeCash(size),coat,Wt.Traits[Wt.Key(weather)].Multiplier)end
check(m(1,'None','None')==1,'plain x1')
check(m(.5,'None','None')==1,'small fruit still x1')
check(m(2,'None','None')==2 and m(2.5,'None','None')==2.5,'size x2 -> x2, x2.5 -> x2.5')
check(m(1,'Gold','None')==3 and m(1,'Diamond','None')==6,'Gold x3, Diamond x6')
check(m(1,'None','Drippy')==2 and m(1,'None','Frosted')==3 and m(1,'None','Charged')==5,'weather x2/x3/x5')
check(m(1,'None','Drippy+Frosted+Charged')==30,'stacked weather multiplies (x30): '..m(1,'None','Drippy+Frosted+Charged'))
check(m(2,'Gold','Drippy')==12,'x2 size x Gold x Drippy = x12: '..m(2,'Gold','Drippy'))
check(m(25,'Diamond','Charged')==100,'cap x100: '..m(25,'Diamond','Charged'))
check(Wt.Price(39900000000,'Diamond',B.SizeCash(25),'Drippy+Frosted+Charged')<=9000000000000,'biggest fruit stays under the 9T save limit')
print(('%d checks, %d failures'):format(checks,fails))
