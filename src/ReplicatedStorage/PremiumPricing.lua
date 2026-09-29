-- R79: five fixed cash and speed bundles. Legacy Cash/Speed IDs keep their original rewards.
local P={GemsPerRobux=1,Bundles={
 {Key='CashSmall',Kind='Cash',Tier='Small',Amount=30000000000,Name='+30B CASH',GemPrice=49,RobuxPrice=49,IdAttribute='CashSmallProductId',Emblem='Money'},
 {Key='CashMedium',Kind='Cash',Tier='Medium',Amount=100000000000,Name='+100B CASH',GemPrice=149,RobuxPrice=149,IdAttribute='CashMediumProductId',Emblem='Money'},
 {Key='Cash',Kind='Cash',Tier='Large',Amount=300000000000,Name='+300B CASH',GemPrice=350,RobuxPrice=350,IdAttribute='CashProductId',Emblem='Money'},
 {Key='CashValue',Kind='Cash',Tier='Value',Amount=650000000000,Name='+650B CASH',GemPrice=699,RobuxPrice=699,IdAttribute='CashValueProductId',Emblem='Money'},
 {Key='CashMega',Kind='Cash',Tier='Mega',Amount=1400000000000,Name='+1.4T CASH',GemPrice=1499,RobuxPrice=1499,IdAttribute='CashMegaProductId',Emblem='Money'},
 {Key='SpeedSmall',Kind='Speed',Tier='Small',Amount=15000,Name='+15K SPEED',GemPrice=49,RobuxPrice=49,IdAttribute='SpeedSmallProductId',Emblem='Bolt'},
 {Key='SpeedMedium',Kind='Speed',Tier='Medium',Amount=55000,Name='+55K SPEED',GemPrice=149,RobuxPrice=149,IdAttribute='SpeedMediumProductId',Emblem='Bolt'},
 {Key='Speed',Kind='Speed',Tier='Large',Amount=150000,Name='+150K SPEED',GemPrice=350,RobuxPrice=350,IdAttribute='SpeedProductId',Emblem='Bolt'},
 {Key='SpeedValue',Kind='Speed',Tier='Value',Amount=350000,Name='+350K SPEED',GemPrice=699,RobuxPrice=699,IdAttribute='SpeedValueProductId',Emblem='Bolt'},
 {Key='SpeedMega',Kind='Speed',Tier='Mega',Amount=850000,Name='+850K SPEED',GemPrice=1499,RobuxPrice=1499,IdAttribute='SpeedMegaProductId',Emblem='Bolt'},
}}
-- Existing pending Speed receipts receive at least their previous entitlement.
local rewards={250000,1000000,3000000,8000000,25000000};local n=0
for _,row in ipairs(P.Bundles)do if row.Kind=='Speed'then
 n+=1;row.LegacyAmount=row.Amount;row.Amount=math.max(row.Amount,rewards[n]);row.RewardVersion=81
 row.Name='+'..require(script.Parent.CashNumbers).Compact(row.Amount)..' SPEED'
end end
-- R94: cash bundles use their original fixed rewards and Gem prices above.
-- Preserve the existing speed bundle prices.
local speedTier=0
for _,row in ipairs(P.Bundles)do if row.Kind=='Speed'then
 speedTier+=1;row.GemPrice=require(script.Parent.EconomyScaling91).BundleGemPrices[speedTier]
end end
function P.FromRobux(price)return math.ceil(price*P.GemsPerRobux)end
function P.Find(key)for _,row in ipairs(P.Bundles)do if row.Key==key then return row end end end
function P.ProductId(row)
 local id=tonumber(script:GetAttribute(row.IdAttribute))
 return id and id>0 and id<9007199254740991 and id%1==0 and id or 0
end
function P.ProductKey(id)
 local found
 for _,row in ipairs(P.Bundles)do if id>0 and P.ProductId(row)==id then if found then return nil end;found=row.Key end end
 return found
end
return P
