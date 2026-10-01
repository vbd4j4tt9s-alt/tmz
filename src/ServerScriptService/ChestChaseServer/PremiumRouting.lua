local RS=game:GetService('ReplicatedStorage');local Pricing=require(RS.PremiumPricing);local Gifts=require(RS.PassGiftCatalog);local Mech=require(RS.MechCatalog)
local ProductGifts=require(RS.GiftProducts)
local R={}
function R.Resolve(id)
 if type(id)~='number'or id~=id or id<=0 or id%1~=0 or id>=9007199254740991 then return nil end
 local matches={}
 for _,offer in ipairs(Mech.Offers)do if Mech.ProductId(offer.Count)==id then table.insert(matches,{'Mech',offer.Count})end end
 for _,r in ipairs(Pricing.Bundles)do if Pricing.ProductId(r)==id then table.insert(matches,{'Bundle',r.Key})end end
 for _,p in ipairs(require(RS.GamePassCatalog))do if Gifts.ProductId(p.Key)==id then table.insert(matches,{'Gift',p.Key})end end
 -- R121: x2 training boost and the gift versions of every product.
 if Pricing.ProductId(Pricing.Boost)==id then table.insert(matches,{'Boost',Pricing.Boost.Key})end
 for _,row in ipairs(ProductGifts.Rows)do if ProductGifts.ProductId(row.Key)==id then table.insert(matches,{'ProductGift',row.Key})end end
 if #matches==1 then return table.unpack(matches[1])end
 return nil
end
return R
