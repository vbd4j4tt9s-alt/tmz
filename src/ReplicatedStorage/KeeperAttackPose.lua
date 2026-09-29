-- R39: seven attacks layered over the existing idle, wake and locomotion poses.
local Config=require(script.Parent.KeeperRigConfig)
local Combat=require(script.Parent.KeeperCombat)
local M={};local CF,V=CFrame.new,Vector3.new
local function around(p,x,y,z)
 return CF(p)*CFrame.Angles(0,y,0)*CFrame.Angles(x,0,z)*CF(-p)
end
function M.Apply(stage,frames,now,started)
 local load,hit=Combat.Pose(stage,now,started)
 if load==0 and hit==0 then return frames end
 if stage==5 then return require(script.Parent.CrystalKnightPose).Adapt(frames,1,0,0,now,load,hit)end
 local rig=Config[stage];local scale=rig.Scale or 1;local piv={}
 for group,p in pairs(rig.Pivots)do piv[group]=V(table.unpack(p))end
 local out=table.clone(frames)
 if stage==1 or stage==5 or stage==7 then
  local drop=stage==7 and 2.65 or stage==1 and 1.55 or .65
  local body=CF(0,-drop*scale*hit,-.45*scale*hit)*around(piv.Body,-.08*load+.10*hit,0,0)
  out.Body=body*frames.Body;out.Head=body*frames.Head*around(piv.Head,.06*load-.10*hit,0,0)
  for _,side in ipairs({'Left','Right'})do
   local group=side..'Arm';local sign=side=='Left'and 1 or -1
   local pitch=-1.05*load+(stage==5 and .69 or .47)*hit
   local yaw=sign*(stage==5 and .8 or .56)*hit
   if stage==5 and side=='Left'then pitch=-.20*load+.18*hit;yaw=0 end
   out[group]=body*frames[group]*around(piv[group],pitch,yaw,sign*.08*load)
  end
 elseif stage==2 then
  -- Coil, then a short bite; jaw closes at contact.
  out.Head=CF(0,.18*load,-2.1*hit)*frames.Head*around(piv.Head,-.24*load+.13*hit,0,0)
  if frames.Jaw then out.Jaw=CF(0,.18*load,-2.1*hit)*frames.Jaw*around(piv.Jaw or piv.Head,-.45*load+.10*hit,0,0)end
 else
  -- Tiger pounce, dragon rake, and gorilla hammer strike.
  local reach=stage==4 and 2.8 or 1.8
  local body=CF(0,.20*load-.28*hit,-reach*hit)
  for group,frame in pairs(frames)do
   local p=piv[group]
   if p and(group:find('FrontLeg')or group:find('Arm'))then
    out[group]=body*frame*around(p,-.75*load+.54*hit,0,0)
   elseif group=='Head'then out[group]=body*frame*around(p,-.12*load+.18*hit,0,0)
   elseif group=='Jaw'then out[group]=body*frame*around(p or piv.Head,-.32*load+.08*hit,0,0)
   elseif not group:find('BackLeg')then out[group]=body*frame end
  end
 end
 return out
end
return M
