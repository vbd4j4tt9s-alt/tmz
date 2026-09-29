-- R53: durable, integer-valued sale receipts. Clients never choose payout amounts.
local R={MaxReceipts=64,MaxCash=require(script.Parent.EconomyBalance90).MaxCash}
local function integer(n,lo,hi)return type(n)=='number'and n==n and n%1==0 and n>=lo and n<=hi end
function R.Share(receipt,index)
 return math.floor(receipt.Amount/receipt.Count)+(index<=receipt.Amount%receipt.Count and 1 or 0)
end
function R.Claimed(receipt,index)return bit32.band(receipt.Claimed,bit32.lshift(1,index-1))~=0 end
function R.Remaining(receipt)
 local total=0;for i=1,receipt.Count do if not R.Claimed(receipt,i)then total+=R.Share(receipt,i)end end;return total
end
function R.Total(receipts,currency)
 currency=currency or 'Cash'
 local total=0;for _,r in ipairs(receipts or{})do if(r.Currency or 'Cash')==currency then total+=R.Remaining(r)end end;return total
end
function R.Valid(receipts)
 if receipts==nil then return true end
 if type(receipts)~='table'or #receipts>R.MaxReceipts then return false end
 local seen,count={},0
 for index,r in pairs(receipts)do
  count+=1
  if not integer(index,1,#receipts)or type(r)~='table'or type(r.Id)~='string'or #r.Id<1 or #r.Id>100 or seen[r.Id]
   or(r.Currency~=nil and r.Currency~='Cash'and r.Currency~='Gems')
   or not integer(r.Amount,1,r.Currency=='Gems'and 1000000 or R.MaxCash)or not integer(r.Count,r.Currency=='Gems'and 1 or 8,13)or not integer(r.Claimed,0,2^r.Count-1)then return false end
  seen[r.Id]=true
 end
 return count==#receipts and R.Total(receipts)<=R.MaxCash and R.Total(receipts,'Gems')<=1000000
end
return R
