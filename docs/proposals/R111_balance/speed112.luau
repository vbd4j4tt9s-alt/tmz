-- Speed facts from the REAL modules (edited src): Progression81.Speed on the new PointCurve, keeper rows from
-- RouteBalance83 via BalanceValues81, KeeperPursuit.Speed/Smooth and KeeperCombat reach for a straight-line chase.
local P=RS_MOD('Progression81')
local T=RS_MOD('BalanceValues81')
local K=RS_MOD('KeeperPursuit')
local C=RS_MOD('KeeperCombat')
for _,pts in ipairs({0,100,300,500,1000,1500,2000,3000,4500,6000,9000,12000,18000,30000,60000,120000,1500000,20000000,300000000,5000000000,100000000000,1e12})do
 print('SPEED',string.format('%.0f',pts),string.format('%.4f',P.Speed(string.format('%.0f',pts))))
end
for _,k in ipairs(T.PointCurve)do print('KNOT',string.format('%.0f',k[1]),k[2])end
local order={1,6,2,3,4,5,7}
for _,st in ipairs(order)do local r=T.KeeperSpeeds[st];print('KEEPER',st,r[1],r[2],r[3])end
-- Gap at which the keeper's pursuit speed equals the runner's (it can never close from further back).
local function settle(st,v)
 if K.Speed(nil,nil,0,st)>=v then return 0 end
 for gap=0,400,.25 do if K.Speed(nil,nil,gap,st)>=v then return gap end end
 return math.huge
end
for _,st in ipairs(order)do for _,v in ipairs({24,26,28,31,35,55,88,141,226,363,500})do
 print('SETTLE',st,v,settle(st,v))
end end
-- Straight chase: keeper notices after 0.5 s (ConcurrentKeeperService:93), may hit from +0.85 s, reach from KeeperCombat.
-- Runner starts `gap` studs from the keeper and runs away at v. Returns the closest the keeper gets once hits are enabled.
local function chase(st,v,gap,seconds)
 local dt=1/60;local t=0;local player,keeper=gap,0;local kv=0;local closest=math.huge
 while t<seconds do
  t+=dt;player+=v*dt
  if t>=.5 then kv=K.Smooth(kv,K.Speed(nil,nil,player-keeper,st),dt);keeper+=kv*dt end
  if t>=1.35 then closest=math.min(closest,player-keeper)end
 end
 return closest
end
for _,v in ipairs({22,24,26,28,31,35})do for _,gap in ipairs({5,10,15,25})do
 print('CHASE',1,v,gap,string.format('%.1f',chase(1,v,gap,6)),C.Get(1).Reach)
end end
for _,case in ipairs({{6,35},{2,55},{3,88},{4,141},{5,226},{7,363},{6,31},{2,35},{3,55},{4,88},{5,141},{7,226}})do
 print('CHASE',case[1],case[2],10,string.format('%.1f',chase(case[1],case[2],10,20)),C.Get(case[1]).Reach)
end
