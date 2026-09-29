-- Gift products grant a durable, transferable in-game pass benefit, not platform ownership.
local G={MaxCredits=20000,MaxOutbox=32,MaxInbox=128}
function G.Pass(key)for _,p in ipairs(require(script.Parent.GamePassCatalog))do if p.Key==key then return p end end end
function G.ProductId(key)
 if not G.Pass(key)then return 0 end
 local id=tonumber(script:GetAttribute(key..'GiftProductId'))
 return id and id>0 and id<9007199254740991 and id%1==0 and id or 0
end
function G.ProductKey(id)
 local found
 for _,p in ipairs(require(script.Parent.GamePassCatalog))do if id>0 and G.ProductId(p.Key)==id then if found then return nil end;found=p.Key end end
 return found
end
return G
