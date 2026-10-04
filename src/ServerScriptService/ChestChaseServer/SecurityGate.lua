-- R79: bounded server input budgets. Caller identity always comes from Roblox's remote dispatch.
local G={Records={},Rejected=0}
local policies={CollectSaleCash={Rate=120,Burst=832},GetPendingSales={Rate=2,Burst=4},GetShopState={Rate=3,Burst=6},PremiumRequest={Rate=8,Burst=16},GardenAction={Rate=10,Burst=18},FruitGift={Rate=2,Burst=3},BatSwing={Rate=4,Burst=6},TrackHole={Rate=2,Burst=4},VerityTalk={Rate=1,Burst=3},VerityGive={Rate=1,Burst=2}}
function G.Finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function G.Valid(value)
 local seen={};local nodes=0;local chars=0
 local function visit(v,depth)
  nodes+=1;if nodes>64 or depth>4 then return false end
  local t=typeof(v)
  if t=='nil'or t=='boolean'then return true
  elseif t=='number'then return G.Finite(v)
  elseif t=='string'then chars+=#v;return #v<=512 and chars<=2048 and utf8.len(v)~=nil
  elseif t=='Vector3'then return G.Finite(v.X)and G.Finite(v.Y)and G.Finite(v.Z)
  elseif t=='Instance'then return true -- individual endpoints validate ownership and expected identity
  elseif t~='table'or seen[v]then return false end
  seen[v]=true
  for k,x in pairs(v)do if type(k)~='string'and type(k)~='number'then return false end;if not visit(k,depth+1)or not visit(x,depth+1)then return false end end
  seen[v]=nil;return true
 end
 return visit(value,0)
end
function G.Allow(player,route,...)
 if select('#',...)>16 then G.Rejected+=1;return false end
 local now=os.clock();local all=G.Records[player]
 if not all then all={};G.Records[player]=all end
 local policy=policies[route]or{Rate=6,Burst=10};local b=all[route]
 if not b then b={At=now,Tokens=policy.Burst};all[route]=b end
 b.Tokens=math.min(policy.Burst,b.Tokens+math.max(0,now-b.At)*policy.Rate);b.At=now
 if b.Tokens<1 then G.Rejected+=1;return false end
 b.Tokens-=1
 for i=1,select('#',...)do if not G.Valid(select(i,...))then G.Rejected+=1;return false end end
 return true
end
function G.Cleanup(player)G.Records[player]=nil end
return G
