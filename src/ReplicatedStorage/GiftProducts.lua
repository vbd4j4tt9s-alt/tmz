-- R121: GIFT developer products. Every Robux product the shop sells has a separate gift product with the
-- same reward. Paste each gift product's id into the matching attribute ON THIS ModuleScript
-- (ReplicatedStorage.GiftProducts). While an attribute is 0 / missing that gift button shows SOON.
--
--  Product                   Normal id attribute (ModuleScript)          Gift id attribute (this ModuleScript)
--  +30B CASH                 CashSmallProductId      (PremiumPricing)    GiftCashSmallProductId
--  +100B CASH                CashMediumProductId     (PremiumPricing)    GiftCashMediumProductId
--  +300B CASH                CashProductId           (PremiumPricing)    GiftCashProductId
--  +650B CASH                CashValueProductId      (PremiumPricing)    GiftCashValueProductId
--  +1.4T CASH                CashMegaProductId       (PremiumPricing)    GiftCashMegaProductId
--  +250K SPEED               SpeedSmallProductId     (PremiumPricing)    GiftSpeedSmallProductId
--  +1M SPEED                 SpeedMediumProductId    (PremiumPricing)    GiftSpeedMediumProductId
--  +3M SPEED                 SpeedProductId          (PremiumPricing)    GiftSpeedProductId
--  +8M SPEED                 SpeedValueProductId     (PremiumPricing)    GiftSpeedValueProductId
--  +25M SPEED                SpeedMegaProductId      (PremiumPricing)    GiftSpeedMegaProductId
--  Limited Mech Pack x1      MechPackProductId       (MechCatalog)       GiftMechPackProductId
--  Limited Mech Pack x5      MechPack5ProductId      (MechCatalog)       GiftMechPack5ProductId
--  Limited Mech Pack x10     MechPack10ProductId     (MechCatalog)       GiftMechPack10ProductId
--  x2 Speed boost 10 min     SpeedBoost10ProductId   (PremiumPricing)    GiftSpeedBoost10ProductId
--
-- Pass gifts (x2 Growth / x2 Speed) keep their R79 attributes on PassGiftCatalog.
local RS=game:GetService('ReplicatedStorage')
local G={MaxCredits=20000,MaxOutbox=32,MaxInbox=128,Rows={
 {Key='CashSmall',Kind='Bundle',Attribute='GiftCashSmallProductId'},
 {Key='CashMedium',Kind='Bundle',Attribute='GiftCashMediumProductId'},
 {Key='Cash',Kind='Bundle',Attribute='GiftCashProductId'},
 {Key='CashValue',Kind='Bundle',Attribute='GiftCashValueProductId'},
 {Key='CashMega',Kind='Bundle',Attribute='GiftCashMegaProductId'},
 {Key='SpeedSmall',Kind='Bundle',Attribute='GiftSpeedSmallProductId'},
 {Key='SpeedMedium',Kind='Bundle',Attribute='GiftSpeedMediumProductId'},
 {Key='Speed',Kind='Bundle',Attribute='GiftSpeedProductId'},
 {Key='SpeedValue',Kind='Bundle',Attribute='GiftSpeedValueProductId'},
 {Key='SpeedMega',Kind='Bundle',Attribute='GiftSpeedMegaProductId'},
 {Key='MechPack1',Kind='Mech',Count=1,Attribute='GiftMechPackProductId'},
 {Key='MechPack5',Kind='Mech',Count=5,Attribute='GiftMechPack5ProductId'},
 {Key='MechPack10',Kind='Mech',Count=10,Attribute='GiftMechPack10ProductId'},
 {Key='SpeedBoost10',Kind='Boost',Attribute='GiftSpeedBoost10ProductId'},
}}
G.ByKey={};for _,row in ipairs(G.Rows)do G.ByKey[row.Key]=row end
function G.Find(key)return type(key)=='string'and G.ByKey[key]or nil end
function G.MechKey(count)return 'MechPack'..tostring(count)end
function G.ProductId(key)
 local row=G.Find(key);if not row then return 0 end
 local id=tonumber(script:GetAttribute(row.Attribute))
 return id and id>0 and id<9007199254740991 and id%1==0 and id or 0
end
function G.ProductKey(id)
 local found
 for _,row in ipairs(G.Rows)do if id>0 and G.ProductId(row.Key)==id then if found then return nil end;found=row.Key end end
 return found
end
function G.Name(key)
 local row=G.Find(key);if not row then return 'Gift'end
 if row.Kind=='Bundle'then local b=require(RS.PremiumPricing).Find(row.Key);return b and b.Name or row.Key end
 if row.Kind=='Mech'then return row.Count==1 and'Limited Mech Pack'or(row.Count..' Limited Mech Packs')end
 return 'x2 Speed for 10 min'
end
return G
