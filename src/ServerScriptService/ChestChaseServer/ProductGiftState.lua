-- R121: saved fields for product gifts and the timed x2 Speed boost (all inside the premium profile).
--  ProductGiftCredits {[giftKey]=n}   paid gifts not yet sent (recipient left / no recipient chosen)
--  ProductOutbox      {[id]={RecipientId,Key,State}}   saved debit -> durable inbox (like PassOutbox)
--  ProductGiftReceipts{[id]=true}     inbox gifts already granted to this player
--  SpeedBoostEndsAt   unix seconds (os.time) when the x2 training boost ends; nil when never bought
local RS=game:GetService('ReplicatedStorage');local Catalog=require(RS.GiftProducts)
local S={}
function S.Initialize(state)
 state.ProductGiftCredits=state.ProductGiftCredits or{};state.ProductOutbox=state.ProductOutbox or{};state.ProductGiftReceipts=state.ProductGiftReceipts or{}
end
local function id(n)return type(n)=='number'and n==n and n%1==0 and n>0 and n<9007199254740991 end
local function token(s)return type(s)=='string'and #s>0 and #s<=100 and utf8.len(s)~=nil end
function S.Valid(state)
 for _,key in ipairs({'ProductGiftCredits','ProductOutbox','ProductGiftReceipts'})do if state[key]~=nil and type(state[key])~='table'then return false end end
 local count=0
 for key,n in pairs(state.ProductGiftCredits or{})do if not Catalog.Find(key)or type(n)~='number'or n~=n or n%1~=0 or n<0 or n>Catalog.MaxCredits then return false end end
 for key,v in pairs(state.ProductOutbox or{})do
  count+=1;if count>Catalog.MaxOutbox or not token(key)or type(v)~='table'or not id(v.RecipientId)or not Catalog.Find(v.Key)or(v.State~='Pending'and v.State~='Acked')then return false end
 end
 count=0
 for key,v in pairs(state.ProductGiftReceipts or{})do count+=1;if count>Catalog.MaxInbox or not token(key)or v~=true then return false end end
 -- A damaged expiry only loses the boost, never the save.
 local ends=state.SpeedBoostEndsAt
 if ends~=nil and not(type(ends)=='number'and ends==ends and ends%1==0 and ends>=0 and ends<2^40)then state.SpeedBoostEndsAt=nil end
 return true
end
return S
