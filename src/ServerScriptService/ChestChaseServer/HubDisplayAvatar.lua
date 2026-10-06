-- R151: the champion's avatar for a hub display. The server builds it once per champion (never per frame):
--   Players:GetHumanoidDescriptionFromUserId(userId)   (works for a player who has left; cached per user id, a failure is cached for a short while too)
--   Players:CreateHumanoidModelFromDescription(desc, R15)  ->  a rig, which is then
--     * stripped to what is needed: no scripts; its accessories capped (HubDisplayRules.AvatarAccessories);
--     * made inert: every part CanCollide / CanTouch / CanQuery off, the HumanoidRootPart anchored (the limbs hang off it through their Motor6Ds, which is what lets a
--       client animate them), the humanoid's name and health bar off (DisplayDistanceType None, HealthDisplayType AlwaysOff);
--     * scaled to AvatarHeight (R152: 25 studs, about 4.7 times a normal avatar; Model:ScaleTo, measured on the body parts alone, so a tall hat does not shrink the body) and stood
--       with its feet on the floor beside the pedestal, turned a little toward it (Place; R153: measured in the REST POSE THROUGH ITS JOINTS, see restPose).
-- R152 (owner: "the avatar is sized up and dancing") played one of Roblox's default R15 dance emotes here, on the server, and waited 5 s for the track's Length: on a real server that
--   never came (a server need not fetch an animation's data), so the owner's giant stood in the fallback pose. R153: the dance is each CLIENT's (HubDisplayClient plays it on its own
--   screen, retries, falls back to the pose there). Animate only gets the rig READY for it and sets `AvatarMode` ('dance' | 'pose' | 'static'): see Animate.
-- If the description or the rig cannot be had (a bad user id, a Studio test player, no network, the service throwing), a blocky stand-in is built from parts (the
-- same size and pose) and the display is still complete. Build never throws: it returns the model and where it came from ('avatar' | 'fallback').
-- `players` is injectable (tests pass a mock). Caches are per module instance.
local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('HubDisplayRules'))
local Pose=require(RS:WaitForChild('HubAvatarPose'))
local Av={};Av.__index=Av
local RGB=Color3.fromRGB
Av.FailureSeconds=60 -- a user id that failed is not asked about again for this long
-- Roblox's default R15 "dance" emotes (the Animate script's dance set; HubDisplayRules.DanceIds): one is picked per user id, so a champion always dances the same one.
Av.DanceIds=Rules.DanceIds
function Av.new(opts)
 opts=opts or{}
 return setmetatable({Players=opts.Players,Clock=opts.Clock or os.clock,Cache={},Order={},Failed={},Calls={Describe=0,Create=0}},Av)
end
function Av:_players()
 if self.Players then return self.Players end
 self.Players=game:GetService('Players');return self.Players
end
-- The description of a user (or nil and why). Cached by id (the oldest of AvatarCache kept descriptions goes first).
function Av:Describe(userId)
 if type(userId)~='number'or userId~=userId or userId<=0 or userId%1~=0 then return nil,'not a real user id'end
 local hit=self.Cache[userId];if hit then return hit end
 local failed=self.Failed[userId];if failed and self.Clock()<failed.Until then return nil,failed.Why end
 self.Calls.Describe+=1
 local ok,desc=pcall(function()return self:_players():GetHumanoidDescriptionFromUserId(userId)end)
 if not ok or desc==nil then
  local why=tostring(desc or'no description');self.Failed[userId]={Until=self.Clock()+Av.FailureSeconds,Why=why};return nil,why
 end
 self.Failed[userId]=nil;self.Cache[userId]=desc;table.insert(self.Order,userId)
 while #self.Order>Rules.AvatarCache do local old=table.remove(self.Order,1);self.Cache[old]=nil end
 return desc
end
-- At most `limit` accessories (the description's own order: rigid ones first). Safe on any description: a failure leaves it as it was.
local function trimAccessories(desc,limit)
 pcall(function()
  local list=desc:GetAccessories(true)
  if type(list)=='table'and #list>limit then
   local kept={};for i=1,limit do kept[i]=list[i]end
   desc:SetAccessories(kept,true)
  end
 end)
end
-- The parts of the body (the model's own BasePart children): the head's top and the feet's bottom, not accessories.
local function bodyBox(model)
 local lo,hi
 for _,p in ipairs(model:GetChildren())do if p:IsA('BasePart')and p.Name~='HumanoidRootPart'then
  local cf=p.CFrame;local s=p.Size
  local ey=(math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.RightVector.Y)*s.X+math.abs(cf.LookVector.Y)*s.Z)/2
  local a,b=cf.Position.Y-ey,cf.Position.Y+ey
  lo=lo and math.min(lo,a)or a;hi=hi and math.max(hi,b)or b
 end end
 return lo,hi
end
local function inert(model)
 for _,d in ipairs(model:GetDescendants())do
  if d:IsA('BasePart')then
   d.CanCollide=false;d.CanTouch=false;d.CanQuery=false;d.Massless=true
   if d.Name=='HumanoidRootPart'then d.Anchored=true end
  elseif d:IsA('LuaSourceContainer')then d:Destroy()end
 end
 local humanoid=model:FindFirstChildOfClass('Humanoid')
 if humanoid then
  pcall(function()
   humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
   humanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
   humanoid.NameDisplayDistance=0;humanoid.HealthDisplayDistance=0
   humanoid.RequiresNeck=false;humanoid.BreakJointsOnDeath=false
  end)
 end
end
-- A blocky stand-in (the owner's "blocky default"): head, torso, two arms, two legs, in the classic colours; the right arm raised like the real pose. silhouette = true makes
-- it a black shadow (the empty fruit display's mysterious figure). Parts only: no humanoid, no joints.
function Av:Fallback(silhouette)
 local model=Instance.new('Model');model.Name='ChampionAvatar';model:SetAttribute('Fallback',true)
 local function block(name,size,at,color,tilt)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=silhouette and RGB(14,12,22)or color;p.Material=Enum.Material.SmoothPlastic
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=true
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p.CFrame=CFrame.new(at)*(tilt or CFrame.new());p.Parent=model;return p
 end
 local skin,shirt,pants=RGB(245,205,48),RGB(13,105,172),RGB(75,151,75)
 block('LeftLeg',Vector3.new(1,2,1),Vector3.new(-.5,1,0),pants)
 block('RightLeg',Vector3.new(1,2,1),Vector3.new(.5,1,0),pants)
 local torso=block('Torso',Vector3.new(2,2,1),Vector3.new(0,3,0),shirt)
 block('Head',Vector3.new(1.2,1.2,1.2),Vector3.new(0,4.6,0),skin)
 block('LeftArm',Vector3.new(1,2,1),Vector3.new(-1.5,3,0),skin)
 -- the right arm out and up (rotated about the shoulder at (1.5, 3.95), like HubAvatarPose.Static)
 local shoulder=Vector3.new(1.5,3.95,0);local arm=CFrame.new(shoulder)*CFrame.Angles(0,0,1.95)*CFrame.new(0,-.95,0)
 local right=block('RightArm',Vector3.new(1,2,1),Vector3.zero,skin);right.CFrame=arm
 model.PrimaryPart=torso
 return model
end
-- R153 (owner: "not on the ground"): a rig's REST POSE through its joints. Once the rig is in the world its anchored root holds it and every Motor6D puts its Part1 at
-- Part0 * C0 * C1:Inverse() (no animation); the parts' own CFrames on an unparented rig need not say the same, so the feet are measured (and the parts put) where the joints will
-- hold them. Returns part -> CFrame for the root and every part a Motor6D chain reaches from it, or nil (no root).
local function restPose(model)
 local root=model:FindFirstChild('HumanoidRootPart')
 if not(root and root:IsA('BasePart'))then return nil end
 local joints={};for _,j in ipairs(model:GetDescendants())do if j:IsA('Motor6D')and j.Part0 and j.Part1 then joints[#joints+1]=j end end
 local at={[root]=root.CFrame};local grew=true
 while grew do
  grew=false
  for _,j in ipairs(joints)do
   if at[j.Part0]and not at[j.Part1]then at[j.Part1]=at[j.Part0]*j.C0*j.C1:Inverse();grew=true
   elseif at[j.Part1]and not at[j.Part0]then at[j.Part0]=at[j.Part1]*j.C1*j.C0:Inverse();grew=true end
  end
 end
 return at
end
Av.RestPose=restPose
-- The rig's body parts put where their joints hold them at rest (the root stays). Returns how many moved.
local function settle(model)
 local at=restPose(model);if not at then return 0 end
 local n=0
 for p,cf in pairs(at)do if p.Name~='HumanoidRootPart'and p.CFrame~=cf then p.CFrame=cf;n+=1 end end
 return n
end
-- Stands a model upright: scaled so the body is `height` studs tall, its feet at `feet` (a CFrame: position = where the soles go, rotation = which way it faces; a rig
-- faces its own -Z, like the display's front), then turned `turn` radians about Y. Works on a rig (ScaleTo + PivotTo) and on the stand-in (parts moved by hand).
function Av:Place(model,feet,height,turn)
 local face=feet*CFrame.Angles(0,turn or 0,0)
 if model:GetAttribute('Fallback')then
  -- the stand-in is 5.4 tall with its soles at y 0, built at the origin facing -Z
  local k=height/5.4
  for _,p in ipairs(model:GetChildren())do if p:IsA('BasePart')then
   local rel=p.CFrame;p.Size=p.Size*k
   p.CFrame=face*CFrame.new(rel.Position*k)*rel.Rotation
  end end
  return true
 end
 pcall(settle,model)
 local lo,hi=bodyBox(model)
 local body=lo and hi-lo or 0
 if body>0 then
  local k=math.clamp(height/body,.2,40)
  local ok=pcall(function()model:ScaleTo(k)end)
  if not ok then return false end
  pcall(settle,model) -- (ScaleTo scales the joints' offsets too: the rest pose again, at the new size)
  lo,hi=bodyBox(model)
 end
 -- stand the soles on the floor: pivot at the feet, then lift by how far the lowest body part (at rest, through the joints) sits below the model's pivot
 local pivot=model:GetPivot()
 local below=lo and(pivot.Position.Y-lo)or 3
 model:PivotTo(face*CFrame.new(0,below,0))
 -- (a Humanoid's HipHeight is the floor to its root's bottom: the same height, should anything ever read it)
 local humanoid=model:FindFirstChildOfClass('Humanoid');local root=model:FindFirstChild('HumanoidRootPart')
 if humanoid and root and lo then pcall(function()humanoid.HipHeight=math.max(below-root.Size.Y/2,0)end)end
 return true
end
-- R153: gets a placed avatar that is in the world READY for the dance each client plays on its own screen (HubDisplayClient), and says how it moves: the rig's `AvatarMode`
-- attribute and the return value, 'dance' | 'pose' | 'static'.
--  'dance' = clients dance it: an Animator on its Humanoid (made HERE when there is none, so it exists on every client), every Motor6D enabled and every part a joint moves unanchored
--            (the root alone is anchored: an anchored limb cannot be moved by its joint), every joint at rest (no pose in C0: a dance on top of a posed C0 would be turned), the
--            humanoid alive with its state machine OFF (no state, no forces, nothing turns or lifts the root: a statue that an Animator still moves), AutoRotate off, no track
--            playing on the server (one played here would be a second dance on every screen), and `DanceId` = which of HubDisplayRules.DanceIds (a stable pick per user id).
--  'pose'  = no humanoid, joints or Animator to dance with, or the rig is not in the world: the static pose goes into the joints' C0 here (it replicates; clients cheer it);
--  'static' = a blocky stand-in or the silhouette (no joints; it carries its pose in its parts).
-- Never yields, never throws.
function Av:Animate(model,userId)
 if typeof(model)~='Instance'then return'static'end
 if model:GetAttribute('Fallback')then model:SetAttribute('AvatarMode','static');return'static'end
 local humanoid=model:FindFirstChildOfClass('Humanoid')
 local ready=false
 if humanoid and model.Parent then
  ready=pcall(function()
   local moved={};local joints=0
   for _,j in ipairs(model:GetDescendants())do if j:IsA('Motor6D')and j.Part0 and j.Part1 then
    joints+=1;moved[j.Part1]=true
    if j.Enabled==false then j.Enabled=true end
   end end
   if joints==0 then error('no joints')end
   for p in pairs(moved)do if p.Name~='HumanoidRootPart'and p.Anchored then p.Anchored=false end end
   if humanoid.Health<=0 then humanoid.Health=math.max(tonumber(humanoid.MaxHealth)or 100,1)end
   local animator=humanoid:FindFirstChildOfClass('Animator')
   if not animator then animator=Instance.new('Animator');animator.Parent=humanoid end
   pcall(function()for _,t in ipairs(animator:GetPlayingAnimationTracks())do t:Stop(0)end end)
   humanoid.EvaluateStateMachine=false
   pcall(function()humanoid.AutoRotate=false end)
  end)
 end
 local mode
 if ready then
  mode='dance'
  model:SetAttribute('DanceId',Rules.DanceIds[Rules.DanceIndex(tonumber(userId)or tonumber(model:GetAttribute('UserId'))or 0,1)])
 else
  mode='pose'
  model:SetAttribute('DanceId',nil)
  pcall(Pose.Apply,model)
  if humanoid then pcall(function()humanoid.EvaluateStateMachine=false end)end
 end
 model:SetAttribute('AvatarMode',mode)
 return mode
end
-- Builds the avatar model for a user id (not parented, not placed). Returns model, source ('avatar' | 'fallback'). Never throws.
function Av:Build(userId,opts)
 opts=opts or{}
 local model,source
 if not opts.Silhouette then
  local desc=self:Describe(userId)
  if desc then
   trimAccessories(desc,Rules.AvatarAccessories)
   self.Calls.Create+=1
   local ok,rig=pcall(function()return self:_players():CreateHumanoidModelFromDescription(desc,Enum.HumanoidRigType.R15)end)
   if ok and typeof(rig)=='Instance'and rig:IsA('Model')then
    local clean=pcall(inert,rig)
    if clean then
     model,source=rig,'avatar'
     model.Name='ChampionAvatar';model:SetAttribute('UserId',userId)
    else pcall(function()rig:Destroy()end)end
   end
  end
 end
 if not model then
  model=self:Fallback(opts.Silhouette);source='fallback'
  if not opts.Silhouette then model:SetAttribute('UserId',userId)end
 end
 return model,source
end
return Av
