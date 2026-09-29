-- R54. Two arms reach forward using this frame's animated torso, on both R6 and R15.
-- Cosmetic arm solver for R6/R15 and Motor6D/AnimationConstraint.
-- Writes only Transform, after Animator evaluation; never edits rig attachments.
local Rules=require(script.Parent.SeedPackRules)
local Pose={};Pose.__index=Pose
local function jointInfo(j)
    if j:IsA("Motor6D") then return j.Part0,j.Part1,j.C0,j.C1 end
    if j:IsA("AnimationConstraint") then
        local a,b=j.Attachment0,j.Attachment1
        if a and b and a.Parent and b.Parent and a.Parent:IsA("BasePart") and b.Parent:IsA("BasePart") then
            return a.Parent,b.Parent,a.CFrame,b.CFrame
        end
    end
end
local function basis(a,b,up)
    local delta=b-a
    if delta.Magnitude<.001 then return CFrame.new(a) end
    if math.abs(delta.Unit:Dot(up))>.97 then up=Vector3.xAxis end
    return CFrame.lookAt(a,b,up)
end
local function limbFrame(localStart,localEnd,worldStart,worldEnd,up)
    return basis(worldStart,worldEnd,up)*basis(localStart,localEnd,Vector3.zAxis):Inverse()
end
function Pose.new(character)
    local self=setmetatable({Character=character,ByChild={},Written={}},Pose)
    -- Prefer the native upgraded driver if compatibility motors coexist.
    for _,kind in ipairs({"AnimationConstraint","Motor6D"}) do
        for _,j in ipairs(character:GetDescendants()) do
            if j:IsA(kind) and j.Enabled then
                local p0,p1=jointInfo(j)
                if p0 and p1 and p1.Parent==character and not self.ByChild[p1.Name] then self.ByChild[p1.Name]=j end
            end
        end
    end
    return self
end
function Pose:IsReady()
    local r15=self.Character:FindFirstChild("UpperTorso")~=nil
    for _,side in ipairs({"Left","Right"}) do
        local names=r15 and {side.."UpperArm",side.."LowerArm",side.."Hand"} or {side.." Arm"}
        for _,name in ipairs(names) do
            local j=self.ByChild[name]
            if not j or not j.Parent or not j.Enabled then return false end
            local p0,p1=jointInfo(j)
            if not p0 or not p1 or p1.Parent~=self.Character then return false end
        end
    end
    return true
end
function Pose:Reset()
    for j,original in pairs(self.Written) do
        if j.Parent then j.Transform=original end
    end
    table.clear(self.Written)
end
function Pose:_write(j,parentFrame,desired)
    if not j or not j.Parent or not j.Enabled then return end
    local _,_,c0,c1=jointInfo(j)
    if self.Written[j]==nil then self.Written[j]=j.Transform end
    j.Transform=c0:Inverse()*parentFrame:Inverse()*desired*c1
end
-- Animator has written Transform, but joint-driven BasePart CFrames update later.
-- Resolve the current torso from the root instead of using last frame's body position.
function Pose:_frame(part,cache,visiting)
    if cache[part]then return cache[part]end
    local j=self.ByChild[part.Name]
    if part.Name=='HumanoidRootPart'or not j or not j.Enabled or visiting[part]then return part.CFrame end
    local p0,_,c0,c1=jointInfo(j)
    if not p0 or p0.Parent~=self.Character then return part.CFrame end
    visiting[part]=true
    local frame=self:_frame(p0,cache,visiting)*c0*j.Transform*c1:Inverse()
    visiting[part]=nil;cache[part]=frame;return frame
end
function Pose:Apply(bag,now)
    local character=self.Character
    local torso=character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local root=bag.PrimaryPart
    if not torso or not root or character:GetAttribute("ChestChaseRagdollActive") then return end
    local frames,visiting={},{}
    local torsoFrame=self:_frame(torso,frames,visiting)
    local characterRoot=character:FindFirstChild('HumanoidRootPart')
    local carryOffset=bag:GetAttribute('CarryRootOffset')
    local bagFrame=characterRoot and typeof(carryOffset)=='CFrame'and characterRoot.CFrame*carryOffset or root.CFrame
    for _,side in ipairs({"Left","Right"}) do
        local sign=side=="Left" and -1 or 1
        local shoulder=self.ByChild[side.."UpperArm"] or self.ByChild[side.." Arm"]
        local grip=root:FindFirstChild(side.."Grip")
        if not shoulder or not shoulder.Enabled or not grip then continue end
        local p0,upper,c0,c1=jointInfo(shoulder)
        if not p0 or not upper then continue end
        local parentFrame=self:_frame(p0,frames,visiting)
        local start=(parentFrame*c0).Position
        local target=(bagFrame*grip.CFrame).Position
        local elbow=self.ByChild[side.."LowerArm"]
        local wrist=self.ByChild[side.."Hand"]
        if elbow and wrist and elbow.Enabled and wrist.Enabled then
            local _,lower,ec0,ec1=jointInfo(elbow)
            local _,hand,wc0,wc1=jointInfo(wrist)
            local a=(ec0.Position-c1.Position).Magnitude
            local b=(wc0.Position-ec1.Position).Magnitude
            if a<.01 or b<.01 or (target-start).Magnitude<.01 then continue end
            local direction=(target-start).Unit
            local distance=math.clamp((target-start).Magnitude,math.abs(a-b)+.01,(a+b)*.96)
            local reach=start+direction*distance
            local pole=torsoFrame.RightVector*sign*.45-torsoFrame.UpVector
            pole= pole-direction*pole:Dot(direction)
            if pole.Magnitude<.01 then pole=torsoFrame.LookVector:Cross(direction) end
            if pole.Magnitude<.01 then continue end
            local along=(a*a-b*b+distance*distance)/(2*distance)
            local bend=math.sqrt(math.max(0,a*a-along*along))
            local elbowAt=start+direction*along+pole.Unit*bend
            local upperFrame=limbFrame(c1.Position,ec0.Position,start,elbowAt,torsoFrame.LookVector)
            local lowerFrame=limbFrame(ec1.Position,wc0.Position,elbowAt,reach,torsoFrame.LookVector)
            self:_write(shoulder,parentFrame,upperFrame)
            self:_write(elbow,upperFrame,lowerFrame)
            -- Keep the hand aligned with the forearm, preserving its wrist offset.
            local handFrame=lowerFrame*wc0*wc1:Inverse()
            self:_write(wrist,lowerFrame,handFrame)
        else
            local desired=limbFrame(c1.Position,Vector3.new(0,-upper.Size.Y*.5,0),start,target,torsoFrame.LookVector)
            self:_write(shoulder,parentFrame,desired)
        end
    end
end
return Pose
