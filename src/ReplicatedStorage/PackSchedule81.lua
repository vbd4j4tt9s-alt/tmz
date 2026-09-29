-- One shared scheduled floor. Natural luck never restarts the counter.
local S={}
function S.Plan(cycle,variants,randomInteger)
 local reserved={};local result=table.clone(variants)
 local function ensure(tier)
  for i,key in ipairs(result)do if key==tier and not reserved[i]then reserved[i]=true;return end end
  local candidates,lowest={},math.huge
  for i,key in ipairs(result)do if not reserved[i]then
   local rank=tonumber(key:match('(%d+)$'))or 0
   if rank<lowest then lowest=rank;candidates={i}elseif rank==lowest then table.insert(candidates,i)end
  end end
  if #candidates==0 then return end
  local index=candidates[randomInteger(1,#candidates)];result[index]=tier;reserved[index]=true
 end
 if cycle>0 and cycle%5==0 then ensure('Pack05')end
 if cycle>0 and cycle%10==0 then ensure('Pack06')end
 return result
end
function S.Event(cycle)return cycle>0 and cycle%3==0 end
-- Exact marginal tier odds for a uniformly chosen slot after Plan's shared floors.
-- Floors replace the lowest unreserved tier; summing the removed order statistics
-- keeps announcements honest without changing any rolls or guaranteed spawns.
function S.Probabilities(cycle,count,weights)
 local n=math.max(0,math.floor(tonumber(count)or 0));local p,total={},0
 for i=1,6 do total+=math.max(0,tonumber(weights[i])or 0)end
 if total<=0 then return {}end
 for i=1,6 do p[i]=math.max(0,tonumber(weights[i])or 0)/total end
 if n==0 or cycle<=0 or cycle%5~=0 then return p end
 if n==1 then return {0,0,0,0,1,0}end
 local counts={};for i=1,6 do counts[i]=n*p[i]end
 local function tail(first,omit5,omit6)
  local sum=0;for i=first,6 do if not(omit5 and i==5)and not(omit6 and i==6)then sum+=p[i]end end;return sum
 end
 -- First floor: insert Pack05 only when absent, removing the minimum original tier.
 for j=1,6 do if j~=5 then local removed=tail(j,true,false)^n-tail(j+1,true,false)^n;counts[j]-=removed;counts[5]+=removed end end
 if cycle%10==0 then
  -- With no natural Pack06, the first floor either reserves a natural Pack05,
  -- or removes the first minimum. The second floor then removes the second minimum.
  local lowTotal=tail(1,true,true)
  local function secondTail(first)
   local q=tail(first,true,true);local below=math.max(0,lowTotal-q)
   return q^n+n*below*q^(n-1)
  end
  for j=1,4 do
   local natural=tail(j,false,true)^n-tail(j+1,false,true)^n
   local noFive=tail(j,true,true)^n-tail(j+1,true,true)^n
   local removed=natural-noFive+secondTail(j)-secondTail(j+1)
   counts[j]-=removed;counts[6]+=removed
  end
  local removed=p[5]^n;counts[5]-=removed;counts[6]+=removed
 end
 for i=1,6 do p[i]=math.clamp(counts[i]/n,0,1)end
 return p
end
return S
