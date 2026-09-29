local RS=game:GetService('ReplicatedStorage');local Catalog=require(RS.PassGiftCatalog)
local S={}
function S.Initialize(state)
 state.GiftCredits=state.GiftCredits or{};state.PassOutbox=state.PassOutbox or{};state.PassGiftReceipts=state.PassGiftReceipts or{}
end
local function id(n)return type(n)=='number'and n==n and n%1==0 and n>0 and n<9007199254740991 end
local function token(s)return type(s)=='string'and #s>0 and #s<=100 and utf8.len(s)~=nil end
function S.Valid(state)
 for _,key in ipairs({'GiftCredits','PassOutbox','PassGiftReceipts'})do if state[key]~=nil and type(state[key])~='table'then return false end end
 local count=0
 for key,n in pairs(state.GiftCredits or{})do if not Catalog.Pass(key)or type(n)~='number'or n~=n or n%1~=0 or n<0 or n>Catalog.MaxCredits then return false end end
 for key,v in pairs(state.PassOutbox or{})do
  count+=1;if count>Catalog.MaxOutbox or not token(key)or type(v)~='table'or not id(v.RecipientId)or not Catalog.Pass(v.PassKey)or(v.State~='Pending'and v.State~='Acked')then return false end
 end
 count=0
 for key,v in pairs(state.PassGiftReceipts or{})do count+=1;if count>Catalog.MaxInbox or not token(key)or v~=true then return false end end
 return true
end
return S
