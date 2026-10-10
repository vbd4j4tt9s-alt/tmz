-- R112: wind back (bat cocked behind the shoulder), whip over the top, contact at C.Windup, follow-through, settle.
-- R158 (owner's reference video; docs/proposals/R158/bats/animation.md, owner-approved): the flat hip-height swing. Load .00-.07 (fast: the bat drops
-- behind the head) -> coil .07-.22 (a slow drift, never frozen) -> strike .22-.30 (accelerating; the bat comes round the right side) -> CONTACT .30
-- (= C.Windup, the server's hit time: the bat straight ahead, flat, at hip height) -> through .30-.335 (out to the left) -> follow-through .335-.52
-- (wraps low to the left, slowing: the weight), held to .60 -> recovery .60-.85 (rises in front and blends back into the tool hold; .85 = Windup +
-- Recovery). Upper body only: right arm, left arm, waist; the legs (and R15's lower torso) stay with the Animator, so you keep running and jumping.
-- R6 has its own keys for the one-piece arm and turns its RootJoint (the whole body) only 60 % of the R15 twist, with no lean.
-- Keys: docs/proposals/R158/bats/preview (solve_keys158.py fits each key to where the bat should be; make_pose158.py wrote them). Angles are
-- CFrame.Angles degrees in the joint's parent space (BatClient conjugates them by the joint's own frame), as before.
local C=require(script.Parent.BatConfig)
-- (Total = Windup + Recovery = .85, rounded to the millisecond: .30 + .55 is 0.8500000000000001 in floating point)
local P={Contact=C.Windup,Total=math.floor((C.Windup+C.Recovery)*1000+.5)/1000,HitFrom=C.HitFrom,HitTo=C.HitTo,TrailFrom=C.TrailFrom,TrailTo=C.TrailTo}
-- the key times (s): A load, A2 coil, B, C contact, D through, E follow-through (held to .60), F recovery
P.Keys={A=.07,A2=.22,B=.26,C=.30,D=.335,E=.52,Hold=.60,F=.72}
P.Joints={R15={'RightShoulder','RightElbow','RightWrist','LeftShoulder','LeftElbow','Waist'},R6={'RightShoulder','LeftShoulder','RootJoint'}}
local function a(x,y,z)return CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))end
-- key order: A .07, A2 .22, B .26, C .30, D .335, E .52, F .72
local poses={
 RightShoulder={a(44,29,60),a(34,16,52),a(7,25,-41),a(47,-8,-32),a(84,23,-46),a(-169,32,-140),a(170,147,-151)},
 RightElbow={a(130,0,0),a(147,0,0),a(150,0,0),a(54,0,0),a(0,0,0),a(0,0,0),a(119,0,0)},
 RightWrist={a(-18,-6,-5),a(-1,2,-2),a(2,-33,5),a(-88,-17,-2),a(-77,-6,-6),a(-62,4,-2),a(-52,-37,-3)},
 LeftShoulder={a(20,0,-6),a(28,6,-6),a(12,0,-10),a(-20,0,-18),a(-28,-5,-26),a(-25,-5,-24),a(0,0,-8)},
 LeftElbow={a(20,0,0),a(25,0,0),a(20,0,0),a(15,0,0),a(20,0,0),a(22,0,0),a(12,0,0)},
 Waist={a(-4,-25,3),a(-5,-35,4),a(-8,-15,1),a(-12,12,-3),a(-12,38,-5),a(-10,55,-6),a(-4,22,-2)},
}
local r6={
 RightShoulder={a(-178,38,-35),a(-168,24,-29),a(-179,-62,70),a(178,-179,119),a(171,120,-141),a(-125,48,-158),a(-125,175,168)},
 LeftShoulder={a(20,0,-6),a(28,6,-6),a(12,0,-10),a(-20,0,-18),a(-28,-5,-26),a(-25,-5,-24),a(0,0,-8)},
 Waist={a(0,-15,0),a(0,-21,0),a(0,-9,0),a(0,7,0),a(0,23,0),a(0,33,0),a(0,13,0)},
}
local K=P.Keys
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
local function outQuad(t)t=math.clamp(t,0,1);return 1-(1-t)*(1-t)end
local function outCubic(t)t=math.clamp(t,0,1);return 1-(1-t)^3 end
-- lead: seconds of the swing that passed before this client first saw it; the load restarts from there (as before).
function P.Sample(name,time,lead,isR6)
 if name=='RootJoint'then name='Waist'end -- R6 torso; R15 uses its waist only.
 local k=(isR6 and r6 or poses)[name];if not k then return CFrame.new(),0 end
 if time<0 or time>=P.Total then return CFrame.new(),0 end
 local A,A2,B,Ck,D,E,F=k[1],k[2],k[3],k[4],k[5],k[6],k[7]
 if time<K.A then
  local start=math.clamp(tonumber(lead)or 0,0,K.A*.6)
  return A,outQuad((time-start)/(K.A-start))                       -- load: fast out of the tool hold
 end
 if time<K.A2 then return A:Lerp(A2,smooth((time-K.A)/(K.A2-K.A))),1 end -- coil: a slow drift, never a frozen hold
 if time<K.C then
  local s=((time-K.A2)/(K.C-K.A2))^2                                 -- strike: accelerating, fastest at contact; B at .26 (s = .25)
  if s<.25 then return A2:Lerp(B,s/.25),1 end
  return B:Lerp(Ck,(s-.25)/.75),1
 end
 if time<K.D then return Ck:Lerp(D,(time-K.C)/(K.D-K.C)),1 end        -- through: still fast, the bat goes out to the left
 if time<K.E then return D:Lerp(E,outCubic((time-K.D)/(K.E-K.D))),1 end -- follow-through: slows down (the weight)
 if time<K.Hold then return E,1 end
 if time<K.F then return E:Lerp(F,smooth((time-K.Hold)/(K.F-K.Hold))),1 end -- recovery: the bat rises in front
 return F,1-smooth((time-K.F)/(P.Total-K.F))                          -- and blends back into the tool hold
end
return P
