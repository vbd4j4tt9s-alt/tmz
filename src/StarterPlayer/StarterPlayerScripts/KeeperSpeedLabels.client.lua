do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R141 (owner: "add a speed req on top of every keeper's head"): a label over every keeper (each biome's keeper and
-- The Darkened) with the Speed it takes to outrun it, in the same Speed numbers as the HUD. Green ✓ when you are
-- already faster, red when not. The server stamps each keeper with KeeperEscapeSpeed (the walk speed it chases at
-- while close; KeeperPursuit.EscapeSpeed) and tags it BiomeKeeper. R148: the friend boost only speeds up the speed you GAIN
-- from training, never how fast you run, so the number needed does not depend on it.
-- R148 (owner: "the indicator is too big; the speed needed must be whole numbers and multiples of 5"): a small sign of a
-- fixed size (never grown for big keepers) that always shows a number: the points needed rounded UP to 2 significant
-- figures (SpeedPoints.NeedText: "510", "3,800", "18K", "1,200K", "22B"), "0" when nothing is needed, "∞" when it is out
-- of reach (The Darkened).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local player=Players.LocalPlayer
local Progress=require(RS:WaitForChild('Progression81'));local Points=require(RS:WaitForChild('SpeedPoints'))
-- R153 (owner: "fix all jittery type effects"): the sign hangs on the keeper's smoothed body (KeeperFollow153's anchor, moved by the keeper's
-- animator with the body every frame), not on the server's root, which arrives in packet steps: the sign stepped while the keeper glided.
-- A keeper no animator drives here keeps the root.
local Follow;pcall(function()Follow=require(RS:WaitForChild('KeeperFollow153',5))end)
local RGB=Color3.fromRGB
local GREEN,RED=RGB(110,236,96),RGB(255,86,86)
local labels={}
-- Speed points needed to be faster than a keeper running at `speed`, as the sign's number. You must be strictly faster,
-- so the need is PointsFor + 1 (exact decimal text: PointsFor is a double, and The Darkened's 600 takes 10^1011 points),
-- rounded up to 2 significant figures. Nothing is needed below the new-runner speed: "0".
local function needText(speed)
 if speed<Progress.Speed(0)then return'0'end
 return Points.NeedText(Points.Add(Progress.PointsText(speed),'1'))
end
local function build(model)
 local gui=Instance.new('BillboardGui');gui.Name='SpeedReq';gui.Size=UDim2.fromOffset(104,36);gui.LightInfluence=0;gui.MaxDistance=160
 gui.AlwaysOnTop=false;gui.ResetOnSpawn=false
 local pill=Instance.new('Frame');pill.Name='Pill';pill.AnchorPoint=Vector2.new(.5,.5);pill.Position=UDim2.fromScale(.5,.5);pill.Size=UDim2.fromScale(1,1)
 pill.BackgroundColor3=RGB(14,16,30);pill.BackgroundTransparency=.2;pill.BorderSizePixel=0;pill.Parent=gui
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=pill
 local edge=Instance.new('UIStroke');edge.Name='Edge';edge.Thickness=2;edge.Parent=pill
 local cap=Instance.new('TextLabel');cap.Name='Caption';cap.BackgroundTransparency=1;cap.Position=UDim2.fromScale(0,.05);cap.Size=UDim2.fromScale(1,.3)
 cap.Font=Enum.Font.FredokaOne;cap.TextScaled=true;cap.TextColor3=RGB(214,222,255);cap.Text='SPEED NEEDED';cap.Parent=pill
 local value=Instance.new('TextLabel');value.Name='Value';value.BackgroundTransparency=1;value.Position=UDim2.fromScale(.04,.36);value.Size=UDim2.fromScale(.92,.6)
 value.Font=Enum.Font.FredokaOne;value.TextScaled=true;value.TextStrokeTransparency=.2;value.TextStrokeColor3=RGB(8,10,20);value.Parent=pill
 return gui
end
local function paint(entry)
 local escape=tonumber(entry.Model:GetAttribute('KeeperEscapeSpeed'))
 if not escape then entry.Gui.Enabled=false;return end
 local mine=tonumber(player:GetAttribute('PhysicalWalkSpeed'))or Progress.Speed(0)
 local fast=mine>escape;local need=needText(escape)
 local pill=entry.Gui.Pill;local color=fast and GREEN or RED
 pill.Value.Text='⚡ '..need..(fast and'  ✓'or'')
 pill.Value.TextColor3=color;pill.Edge.Color=color;entry.Gui.Enabled=true
end
-- Over the head: the top of the keeper's bounding box, measured once (keepers keep their size). The sign itself is always
-- the same small size (a giant keeper's sign does not grow).
local function place(entry)
 local model=entry.Model;local root=model.PrimaryPart or model:FindFirstChild('HumanoidRootPart')or model:FindFirstChildWhichIsA('BasePart',true)
 if not root then return false end
 local ok,box,size=pcall(model.GetBoundingBox,model)
 local top=ok and(box.Position.Y+size.Y/2-root.Position.Y)or 6
 entry.Gui.Adornee=Follow and Follow.Get(model)or root;entry.Gui.StudsOffsetWorldSpace=Vector3.new(0,math.clamp(top,2,80)+2.5,0)
 return true
end
local function add(model)
 if labels[model]or not model:IsA('Model')then return end
 local entry={Model=model,Gui=build(model),Links={}}
 labels[model]=entry
 if not place(entry)then entry.Links[#entry.Links+1]=model.ChildAdded:Connect(function()if place(entry)then paint(entry)end end)end
 entry.Gui.Parent=model;paint(entry)
 entry.Links[#entry.Links+1]=model:GetAttributeChangedSignal('KeeperEscapeSpeed'):Connect(function()paint(entry)end)
end
local function remove(model)
 local entry=labels[model];if not entry then return end;labels[model]=nil
 for _,c in ipairs(entry.Links)do c:Disconnect()end;entry.Gui:Destroy()
end
local function repaint()for _,entry in pairs(labels)do paint(entry)end end
for _,m in ipairs(CS:GetTagged('BiomeKeeper'))do add(m)end
local added=CS:GetInstanceAddedSignal('BiomeKeeper'):Connect(add);local removed=CS:GetInstanceRemovedSignal('BiomeKeeper'):Connect(remove)
local a=player:GetAttributeChangedSignal('PhysicalWalkSpeed'):Connect(repaint)
-- (an animator started / stopped driving a keeper: hang its sign on the anchor / back on the root)
local unfollow=Follow and Follow.Listen(function(model)local entry=labels[model];if entry then place(entry)end end)or function()end
script.Destroying:Connect(function()added:Disconnect();removed:Disconnect();a:Disconnect();unfollow();for m in pairs(labels)do remove(m)end end)
