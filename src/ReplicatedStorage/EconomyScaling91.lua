-- Shared geometric cash prices and server-calculated earned-currency bundle quotes.
-- No client balance, equipped bonus, crop size or mutation can inflate a quote.
local E={Version=91,BundleMinutes={2,5,12.5,31.25,78.125},BundleGemPrices={50,125,315,790,1975}}
function E.Round(value)
 if value<=0 then return 0 end
 local unit=math.max(5,10^(math.floor(math.log10(value))-2))
 return math.floor(value/unit+.5)*unit
end
function E.Curve(first,last,count,free)
 local prices=free and{0}or{}
 for i=0,count-1 do prices[#prices+1]=E.Round(first*(last/first)^(i/(count-1)))end
 prices[free and 2 or 1]=first;prices[#prices]=last
 return prices
end
function E.BaseIncome(def)
 if not def or type(def.Value)~='number'or def.Value<=0 then return 0 end
 local seconds=def.Regrows==false and def.Seconds or def.RegrowSeconds
 if type(seconds)~='number'or seconds<=0 then return 0 end
 return math.min(def.Value,10000000000)*math.clamp(def.FruitCount or 1,1,6)/seconds
end
function E.CashQuote(index,grown,catalog)
 if not E.BundleMinutes[index]then return nil end
 local rate=E.BaseIncome(catalog.SunflowerSeed)
 for id,owned in pairs(grown or{})do if owned==true then rate=math.max(rate,E.BaseIncome(catalog[id]))end end
 -- Eight base-size mature plants; exclude cash multipliers and growth passes.
 -- Never return enough Cash to buy back the Gems spent through Cash-to-Gems.
 local limit=E.BundleGemPrices[index]*1000000000*.8
 return math.max(5,math.min(E.Round(rate*8*60*E.BundleMinutes[index]),limit))
end
return E
