-- R39. Shared attack timing; only the server decides a catch.
local M={Recovery=.30,HitHold=.07,MissCooldown=.35}
local stages={
 [1]={Windup=.30,Reach=9,Height=12},
 [2]={Windup=.22,Reach=12,Height=12},
 [3]={Windup=.24,Reach=10,Height=12},
 [4]={Windup=.32,Reach=16,Height=16},
 [5]={Windup=.32,Reach=14,Height=15},
 [6]={Windup=.28,Reach=9,Height=12},
 [7]={Windup=.34,Reach=16,Height=16},
}
function M.Get(stage)return assert(stages[stage],'Unknown keeper stage')end
function M.InReach(stage,keeperPosition,targetPosition,padding)
 local s=M.Get(stage);local delta=targetPosition-keeperPosition
 return Vector3.new(delta.X,0,delta.Z).Magnitude<=s.Reach+(padding or 0)and math.abs(delta.Y)<=s.Height
end
-- R128 (owner): a keeper starts its swing only when close (TriggerShare of its reach, from its centre), and a swing
-- that started close lands at the impact frame while the target is still inside that strike range (+HitPadding);
-- body overlap still counts too. A keeper beside a player no longer whiffs the same animation over and over; running
-- out of range during the windup still dodges it. Reach itself (visual reach, pursuit, alarm, dash) is unchanged.
M.TriggerShare=.6;M.HitPadding=2
function M.StrikeReach(stage)return M.Get(stage).Reach*M.TriggerShare end
function M.InStrike(stage,keeperPosition,targetPosition,padding)
 local s=M.Get(stage);local delta=targetPosition-keeperPosition
 return Vector3.new(delta.X,0,delta.Z).Magnitude<=s.Reach*M.TriggerShare+(padding or 0)and math.abs(delta.Y)<=s.Height
end
function M.HoldAfterHit(stage,now,started,lastHit)
 return type(started)=='number'and type(lastHit)=='number'and lastHit>=started
  and now<started+M.Get(stage).Windup+M.Recovery
end
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
function M.Pose(stage,now,started)
 if type(started)~='number'then return 0,0 end
 local elapsed=now-started;local windup=M.Get(stage).Windup
 if elapsed<0 or elapsed>windup+M.Recovery then return 0,0 end
 local load=smooth(elapsed/(windup*.70))
 local strike=smooth((elapsed-windup*.70)/(windup*.30))
 local fade=1-smooth((elapsed-windup-M.HitHold)/(M.Recovery-M.HitHold))
 return load*(1-strike),strike*fade
end
return M
