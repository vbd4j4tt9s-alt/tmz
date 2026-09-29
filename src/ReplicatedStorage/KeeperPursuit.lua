-- R80. Biome ceilings preserve progression; pursuit follows observed movement, not just earned points.
local Combat=require(script.Parent.KeeperCombat)
local Balance=require(script.Parent.BalanceRules)
local Motion=require(script.Parent.RunnerMotion)
local P={Rank={[1]=1,[6]=2,[2]=3,[3]=4,[4]=5,[5]=6,[7]=7}}
function P.Gap(stage)
    local rank=P.Rank[stage]or 1
    return Combat.Get(P.Rank[stage]and stage or 1).Reach+9-(rank-1)*.65
end
function P.AlarmDistance(stage)return Combat.Get(P.Rank[stage]and stage or 1).Reach+7 end
function P.Speed(_settings,_playerSpeed,distance,stage,_observedSpeed)
    local row=require(script.Parent.BalanceValues81).KeeperSpeeds[stage]or {20,23,27}
    local gap=Motion.Finite(distance)and math.max(0,distance)or 0
    if gap<=35 then return row[1]end
    if gap<=100 then return row[1]+(row[2]-row[1])*(gap-35)/65 end
    if gap<=250 then return row[2]+(row[3]-row[2])*(gap-100)/150 end
    return row[3]
end
function P.Smooth(current,target,dt)
    target=Motion.Finite(target)and math.max(0,target)or 0
    current=Motion.Finite(current)and math.max(0,current)or target
    dt=Motion.Finite(dt)and math.clamp(dt,0,.1)or 0
    return current+(target-current)*(1-math.exp(-dt/.15))
end

return P
