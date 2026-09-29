-- Stable stage IDs; world distances are independent of saved progression.
local R={Order={1,6,2,3,4,5,7},Start=-100,OldLengths={[1]=225,[6]=270,[2]=292.5,[3]=315,[4]=360,[5]=405,[7]=450},
 Lengths={[1]=180,[6]=450,[2]=650,[3]=850,[4]=1050,[5]=1300,[7]=1600},
 KeeperSpeeds={[1]={20,22,25},[6]={29,34,40},[2]={48,56,64},[3]={72,84,98},[4]={115,140,170},[5]={220,270,320},[7]={400,450,520}},
 EventSpeed=600,EventReturnSpeed=600,SpawnWeights={38,25,15,7,10,5}}
R.OldStart={};R.NewStart={};local old,new=R.Start,R.Start
for _,id in ipairs(R.Order)do R.OldStart[id]=old;R.NewStart[id]=new;old+=R.OldLengths[id];new+=R.Lengths[id]end
R.OldEnd=old;R.End=new
function R.MapZ(z)
 if z<=R.Start then return z end
 for _,id in ipairs(R.Order)do local first=R.OldStart[id];local length=R.OldLengths[id]
  if z<=first+length then return R.NewStart[id]+(z-first)*R.Lengths[id]/length end
 end
 return R.End+(z-R.OldEnd)
end
function R.ApplyConfig(config)
 if config.RouteBalanceVersion==83 then return end
 for stage,e in ipairs(config.MythicEncounters)do
  local oldHome=e.Home[3];local delta=R.MapZ(oldHome)-oldHome;e.Home[3]+=delta
  for _,point in ipairs(e.Seeds)do point[3]+=delta end
  e.Landmark[3]=stage==4 and e.Landmark[3]+(R.MapZ(R.OldStart[4]+R.OldLengths[4]/2)-(R.OldStart[4]+R.OldLengths[4]/2))or R.MapZ(e.Landmark[3])
 end
 local e=config.MythicEncounters[1];local z=e.Home[3]
 for _,p in ipairs(e.Seeds)do p[1]=64-(p[1]-e.Home[1]);p[3]=0-(p[3]-z)end
 e.Home={64,8,0};e.Yaw=90
 config.RouteBalanceVersion=83
 config.BiomeRunLengths=table.clone(R.Lengths);config.BiomeTrackEndZ=R.End;config.BiomeRunLength=R.Lengths[1]
end
return R
