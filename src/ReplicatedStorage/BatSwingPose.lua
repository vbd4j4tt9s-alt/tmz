-- R78: loaded backswing, short anticipation, fast contact and a weighted recovery.
local C=require(script.Parent.BatConfig)
local P={}
local function angles(x,y,z)return CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))end
local poses={
 RightShoulder={angles(-55,-48,72),angles(74,28,-32),angles(92,58,-57)},
 RightElbow={angles(78,0,0),angles(10,0,0),angles(24,0,0)},
 RightWrist={angles(-12,0,18),angles(6,0,-14),angles(14,0,-22)},
 LeftShoulder={angles(12,8,-24),angles(-14,-12,-12),angles(-20,-16,-18)},
 LeftElbow={angles(25,0,0),angles(18,0,0),angles(30,0,0)},
 Waist={angles(-5,-27,5),angles(7,20,-5),angles(9,33,-8)},
 RightGrip={angles(0,0,-20),angles(0,0,26),angles(0,0,42)},
}
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
function P.Sample(name,time)
 if name=='RootJoint'then name='Waist'end -- R6 torso; R15 uses its waist only.
 local key=poses[name];if not key then return CFrame.new(),0 end
 if time<0 or time>=C.Windup+C.Recovery then return CFrame.new(),0 end
 local pull=C.Windup*.55;local release=C.Windup*.70;local follow=C.Recovery*.28
 if time<pull then return key[1],smooth(time/pull)end
 if time<release then return key[1],1 end
 if time<C.Windup then return key[1]:Lerp(key[2],smooth((time-release)/(C.Windup-release))),1 end
 if time<C.Windup+follow then return key[2]:Lerp(key[3],smooth((time-C.Windup)/follow)),1 end
 return key[3],1-smooth((time-C.Windup-follow)/(C.Recovery-follow))
end
return P
