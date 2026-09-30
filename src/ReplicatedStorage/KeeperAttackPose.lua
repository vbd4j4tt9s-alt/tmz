-- R39: seven attacks layered over the existing idle, wake and locomotion poses.
-- R112: deeper wind-back, an accelerating strike, and a follow-through after the hit hold.
-- From Windup to Windup+HitHold (the server's contact check) the pose is exactly the R39 impact pose.
local Config=require(script.Parent.KeeperRigConfig)
local Combat=require(script.Parent.KeeperCombat)
local M={};local CF,V=CFrame.new,Vector3.new
local function around(p,x,y,z)
 return CF(p)*CFrame.Angles(0,y,0)*CFrame.Angles(x,0,z)*CF(-p)
end
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
-- load: wound back (0..1); hit: impact pose weight; follow: extra swing past the impact.
-- lead: seconds of the windup this client missed (late replication); the wind-back restarts from it.
function M.Phases(stage,now,started,lead)
 if type(started)~='number'then return 0,0,0 end
 local elapsed=now-started;local windup=Combat.Get(stage).Windup
 if elapsed<0 or elapsed>windup+Combat.Recovery then return 0,0,0 end
 local cocked,release=windup*.60,windup*.70
 if elapsed<cocked then
  local start=math.clamp(tonumber(lead)or 0,0,cocked*.6)
  return smooth((elapsed-start)/(cocked-start)),0,0
 end
 if elapsed<release then return 1,0,0 end
 if elapsed<windup then local u=(elapsed-release)/(windup-release);u*=u;return 1-u,u,0 end
 local after=elapsed-windup-Combat.HitHold
 if after<0 then return 0,1,0 end
 local v=after/(Combat.Recovery-Combat.HitHold)
 local follow=v<.35 and 1-(1-v/.35)^2 or 1-smooth((v-.35)/.65)
 return 0,1-smooth(v),follow
end
function M.Apply(stage,frames,now,started,lead)
 local load,hit,follow=M.Phases(stage,now,started,lead)
 if load==0 and hit==0 and follow==0 then return frames end
 local rig=Config[stage];local scale=rig.Scale or 1;local piv={}
 for group,p in pairs(rig.Pivots)do piv[group]=V(table.unpack(p))end
 if stage==5 then
  local out=require(script.Parent.CrystalKnightPose).Adapt(frames,1,0,0,now,load,hit)
  -- Sword arm (and blade) swing about the shoulder: further back while wound, on through after the cut.
  local shoulder=out.Body*piv.RightArm;local turn=around(shoulder,.50*load-.60*follow,0,0)
  for _,group in ipairs({'RightArm','RightForearm','Sword'})do out[group]=turn*out[group]end
  if follow>0 then local lean=around(out.Body*piv.Body,.10*follow,-.12*follow,0);for group,f in pairs(out)do out[group]=lean*f end end
  return out
 end
 local out=table.clone(frames)
 if stage==1 or stage==7 then
  local drop=stage==7 and 2.65 or 1.55
  local body=CF(0,-drop*scale*hit+.25*scale*load,-.45*scale*hit+.40*scale*load-.30*scale*follow)
   *around(piv.Body,-.16*load+.10*hit+.08*follow,0,0)
  out.Body=body*frames.Body;out.Head=body*frames.Head*around(piv.Head,.10*load-.10*hit-.05*follow,0,0)
  for _,side in ipairs({'Left','Right'})do
   local group=side..'Arm';local sign=side=='Left'and 1 or -1
   local pitch=-1.50*load+.47*hit+.75*follow
   local yaw=sign*.56*(hit+.5*follow)
   out[group]=body*frames[group]*around(piv[group],pitch,yaw,sign*.12*load)
  end
 elseif stage==2 then
  -- Coil up and back, then a short bite; jaw gapes while coiled and closes at contact.
  local head=CF(0,.55*load-.25*follow,1.30*load-2.1*hit-.70*follow)
  out.Head=head*frames.Head*around(piv.Head,-.34*load+.13*hit+.08*follow,0,0)
  if frames.Jaw then out.Jaw=head*frames.Jaw*around(piv.Jaw or piv.Head,-.60*load+.10*hit,0,0)end
 else
  -- Tiger pounce, dragon rake, and gorilla hammer strike: paws/arms drawn back, then swiped through.
  local reach=stage==4 and 2.8 or 1.8
  local body=CF(0,.30*load-.28*hit,.60*load-reach*hit-.35*follow)*around(piv.Body or V(),.05*load-.04*follow,0,0)
  for group,frame in pairs(frames)do
   local p=piv[group]
   if p and(group:find('FrontLeg')or group:find('Arm'))then
    out[group]=body*frame*around(p,-1.15*load+.54*hit+.55*follow,0,0)
   elseif group=='Head'then out[group]=body*frame*around(p,-.18*load+.18*hit+.06*follow,0,0)
   elseif group=='Jaw'then out[group]=body*frame*around(p or piv.Head,-.40*load+.08*hit,0,0)
   elseif not group:find('BackLeg')then out[group]=body*frame end
  end
 end
 return out
end
return M
