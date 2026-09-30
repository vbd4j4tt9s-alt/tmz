-- R112: wind back (bat cocked behind the shoulder), whip over the top, contact at C.Windup, follow-through, settle.
-- The bat never turns inside the fist; shoulder, elbow, wrist and waist carry it. R6 uses the composed arm.
local C=require(script.Parent.BatConfig)
local P={}
local function angles(x,y,z)return CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))end
-- Keys: 1 cocked, 2 over the top, 3 contact (server impact), 4 follow-through.
local poses={
 RightShoulder={angles(91,15,85),angles(95,2,25),angles(31,-10,6),angles(-10,0,0)},
 RightElbow={angles(100,0,0),angles(20,0,0),angles(8,0,0),angles(20,0,0)},
 RightWrist={angles(90,-70,90),angles(0,-30,0),angles(-20,0,0),angles(-30,0,0)},
 LeftShoulder={angles(71,7,-19),angles(20,9,-3),angles(-25,9,4),angles(-35,8,6)},
 LeftElbow={angles(30,0,0),angles(25,0,0),angles(20,0,0),angles(30,0,0)},
 Waist={angles(-6,-32,4),angles(0,-6,0),angles(10,18,-4),angles(12,30,-6)},
}
-- R6 has one rigid arm: give it the R15 hand orientation so the bat points the same way.
local r6={Waist=poses.Waist,RightShoulder={},LeftShoulder={}}
for i=1,4 do
 r6.RightShoulder[i]=poses.RightShoulder[i]*poses.RightElbow[i]*poses.RightWrist[i]
 r6.LeftShoulder[i]=poses.LeftShoulder[i]*poses.LeftElbow[i]
end
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
-- lead: seconds of the swing that passed before this client first saw it; the wind-back restarts from there.
function P.Sample(name,time,lead,isR6)
 if name=='RootJoint'then name='Waist'end -- R6 torso; R15 uses its waist only.
 local key=(isR6 and r6 or poses)[name];if not key then return CFrame.new(),0 end
 local total=C.Windup+C.Recovery
 if time<0 or time>=total then return CFrame.new(),0 end
 local pull=C.Windup*.45;local strike=C.Windup*.55;local follow=C.Windup+C.Recovery*.30
 if time<pull then
  local start=math.clamp(tonumber(lead)or 0,0,pull*.6)
  return key[1],smooth((time-start)/(pull-start))
 end
 if time<strike then return key[1],1 end
 if time<C.Windup then
  -- Ease-in: the bat is fastest at contact, as a slap should be.
  local u=(time-strike)/(C.Windup-strike);u*=u
  if u<.5 then return key[1]:Lerp(key[2],u*2),1 end
  return key[2]:Lerp(key[3],u*2-1),1
 end
 if time<follow then
  local u=(time-C.Windup)/(follow-C.Windup);u=1-(1-u)*(1-u)
  return key[3]:Lerp(key[4],u),1
 end
 return key[4],1-smooth((time-follow)/(total-follow))
end
return P
