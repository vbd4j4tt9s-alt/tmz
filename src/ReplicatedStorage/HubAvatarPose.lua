-- R151: the champion's avatar on a hub display stands in a pose and (on each player's own screen, only while near) cheers. No animation assets and no Animator:
-- an R15 rig is a tree of Motor6D joints, and both looks are just joint rotations.
-- R152: the avatar now DANCES (HubDisplayAvatar.Animate plays one of Roblox's default R15 dance emotes on its Animator). This module is what it does when it cannot: the static pose
-- below (applied only then: a dance on top of a posed C0 would be turned) and the client's cheer, which only moves a rig the server marked AvatarMode 'pose'.
--  * Static pose (the server, once, when the avatar is built): Pose rotates a few joints' C0 (their rest frame, which replicates): the right arm raised out and a
--    little forward, as if presenting the giant item beside it, the left hand on the hip, the head turned toward the item. It is what everyone sees from afar and
--    what stays if the client script never runs (the avatar is anchored at its root: nothing moves it).
--  * Cheer (the client, near the display only, reduced motion off): Cheer(t) gives, for each joint, an extra CFrame for Motor6D.Transform (a client-side property:
--    it stacks on the joint's C0 and never replicates): the raised arm waves, the body bobs and sways a little, and Celebrate(age) lifts both arms for a moment when
--    a new champion arrives. Everything is bounded (a few tenths of a radian) so no limb can leave the body.
-- The joint names are the R15 ones Players:CreateHumanoidModelFromDescription gives (Model > part > Motor6D); a joint that is missing is simply skipped.
local P={}
-- Static rotations (radians, X / Y / Z) multiplied onto C0: C0 * Angles(x, y, z). Positive Z swings a limb out to the side its joint is on (about 1.57 = level), a negative X swings it forward.
P.Static={
 RightShoulder={-.35,0,1.95},   -- the right arm (+X side of the character): out and a little up and forward (about 110 degrees from hanging): presenting the item
 RightElbow={-.45,0,0},         -- bent a little more
 LeftShoulder={.10,0,-.35},     -- the left arm hangs relaxed, a little out and forward
 LeftElbow={-.25,0,0},
 Neck={0,-.30,.05},             -- the head turns toward the item (the avatar faces slightly toward it, see HubDisplayArt)
 Waist={0,-.12,0},              -- the chest turns a little with it
}
P.Names={'RightShoulder','RightElbow','LeftShoulder','LeftElbow','Neck','Waist','RightWrist','Root','RightHip','LeftHip'}
local function angles(t)return CFrame.Angles(t[1],t[2],t[3])end
-- Finds a Motor6D by name anywhere in a rig.
local function joint(rig,name)
 for _,d in ipairs(rig:GetDescendants())do if d.Name==name and d:IsA('Motor6D')then return d end end
 return nil
end
P.Joint=joint
-- Applies the static pose to a rig (once). Returns how many joints it moved. Safe to call on any model: missing joints are skipped, nothing throws.
function P.Apply(rig)
 local n=0
 for name,t in pairs(P.Static)do
  local j=joint(rig,name)
  if j then local ok=pcall(function()j.C0=j.C0*angles(t)end);if ok then n+=1 end end
 end
 return n
end
-- The cheer at time t (seconds): a table joint name -> CFrame (a Motor6D.Transform). boost 0..1 = the celebration (both arms up); 0 for the plain idle.
P.Cheer={Period=1.7}
local function smooth(x)x=math.clamp(x,0,1);return x*x*(3-2*x)end
function P.CheerAt(t,boost)
 if type(t)~='number'or t~=t or math.abs(t)==math.huge then t=0 end
 boost=type(boost)=='number'and boost==boost and math.clamp(boost,0,1)or 0
 local w=t*2*math.pi/P.Cheer.Period
 local wave=math.sin(w)
 local out={}
 -- the presenting arm waves up and down a little, and when celebrating lifts higher
 out.RightShoulder=CFrame.Angles(-.10*boost,0,.16*wave+.55*boost)
 out.RightElbow=CFrame.Angles(-.22*wave-.35*boost,0,0)
 -- the other arm stays relaxed while idle and joins in on a celebration
 out.LeftShoulder=CFrame.Angles(0,0,-1.6*boost)
 out.LeftElbow=CFrame.Angles(.9*boost,0,0)
 -- the body bobs and sways, the head follows it
 out.Waist=CFrame.Angles(.03*math.sin(2*w),.07*math.sin(w),0)
 out.Neck=CFrame.Angles(-.02*math.sin(2*w+1),.10*math.sin(w+.6),0)
 return out
end
-- The celebration's strength age seconds after a new champion arrived: up fast, held, then down (0 after Duration).
P.Celebrate={Duration=2.6}
function P.CelebrateAt(age)
 if type(age)~='number'or age~=age or age<0 or age>=P.Celebrate.Duration then return 0 end
 local u=age/P.Celebrate.Duration
 if u<.15 then return smooth(u/.15)end
 if u<.7 then return 1 end
 return 1-smooth((u-.7)/.3)
end
-- Every Transform the cheer can write is a rotation of at most about 1.7 rad on one joint: this is the bound the tests check.
P.MaxAngle=1.8
return P
