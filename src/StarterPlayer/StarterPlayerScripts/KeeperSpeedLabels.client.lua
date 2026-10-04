-- R141 (owner: "add a speed req on top of every keeper's head"): a label over every keeper (each biome's keeper and
-- The Darkened) with the Speed it takes to outrun it, in the same Speed numbers as the HUD. Green ✓ when you are
-- already faster, red when not. The server stamps each keeper with KeeperEscapeSpeed (the walk speed it chases at
-- while close; KeeperPursuit.EscapeSpeed) and tags it BiomeKeeper; the friend speed boost is included.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local player=Players.LocalPlayer
local Progress=require(RS:WaitForChild('Progression81'));local Points=require(RS:WaitForChild('SpeedPoints'));local D=require(RS:WaitForChild('DailyRewards'))
local RGB=Color3.fromRGB
local GREEN,RED=RGB(110,236,96),RGB(255,86,86)
local labels={}
local function boost()
 local b=player:GetAttribute('FriendSpeedBoost')
 return type(b)=='number'and b==b and math.clamp(b,1,D.MaxMultiplier())or 1
end
-- Speed points needed to be faster than a keeper running at `speed`, as label text (nil = everyone already is).
-- R147: written out with %.0f (tostring of a big number can come out in e-notation); past what a double holds, from
-- PointsText. Past 1e36 points (beyond the Speed number names; The Darkened's 600 needs about 10^1011) the label says
-- TOO FAST instead of an absurd number.
local function needText(speed)
 local walk=speed/boost()
 if walk<Progress.Speed(0)then return nil end
 local n=Progress.PointsFor(walk)
 if n>=1e36 then return'TOO FAST'end
 return Points.Compact(n<1e15 and string.format('%.0f',n+1)or Progress.PointsText(walk))
end
local function build(model)
 local gui=Instance.new('BillboardGui');gui.Name='SpeedReq';gui.Size=UDim2.fromOffset(150,50);gui.LightInfluence=0;gui.MaxDistance=220
 gui.AlwaysOnTop=false;gui.ResetOnSpawn=false
 local pill=Instance.new('Frame');pill.Name='Pill';pill.AnchorPoint=Vector2.new(.5,.5);pill.Position=UDim2.fromScale(.5,.5);pill.Size=UDim2.fromScale(1,1)
 pill.BackgroundColor3=RGB(14,16,30);pill.BackgroundTransparency=.2;pill.BorderSizePixel=0;pill.Parent=gui
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,12);c.Parent=pill
 local edge=Instance.new('UIStroke');edge.Name='Edge';edge.Thickness=2.5;edge.Parent=pill
 local cap=Instance.new('TextLabel');cap.Name='Caption';cap.BackgroundTransparency=1;cap.Position=UDim2.fromScale(0,.04);cap.Size=UDim2.fromScale(1,.34)
 cap.Font=Enum.Font.FredokaOne;cap.TextScaled=true;cap.TextColor3=RGB(214,222,255);cap.Text='SPEED NEEDED';cap.Parent=pill
 local value=Instance.new('TextLabel');value.Name='Value';value.BackgroundTransparency=1;value.Position=UDim2.fromScale(.04,.38);value.Size=UDim2.fromScale(.92,.58)
 value.Font=Enum.Font.FredokaOne;value.TextScaled=true;value.TextStrokeTransparency=.2;value.TextStrokeColor3=RGB(8,10,20);value.Parent=pill
 return gui
end
local function paint(entry)
 local escape=tonumber(entry.Model:GetAttribute('KeeperEscapeSpeed'))
 if not escape then entry.Gui.Enabled=false;return end
 local mine=tonumber(player:GetAttribute('PhysicalWalkSpeed'))or Progress.Speed(0)*boost()
 local fast=mine>escape;local need=needText(escape)
 local pill=entry.Gui.Pill;local color=fast and GREEN or RED
 pill.Value.Text='⚡ '..(need or'ANY')..(fast and'  ✓'or'')
 pill.Value.TextColor3=color;pill.Edge.Color=color;entry.Gui.Enabled=true
end
-- Over the head: the top of the keeper's bounding box, measured once (keepers keep their size).
local function place(entry)
 local model=entry.Model;local root=model.PrimaryPart or model:FindFirstChild('HumanoidRootPart')or model:FindFirstChildWhichIsA('BasePart',true)
 if not root then return false end
 local ok,box,size=pcall(model.GetBoundingBox,model)
 local top=ok and(box.Position.Y+size.Y/2-root.Position.Y)or 6
 entry.Gui.Adornee=root;entry.Gui.StudsOffsetWorldSpace=Vector3.new(0,math.clamp(top,2,80)+2.5,0)
 local tall=ok and size.Y or 8;local scale=math.clamp(tall/10,1,2.2)
 entry.Gui.Size=UDim2.fromOffset(math.floor(150*scale),math.floor(50*scale))
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
local a=player:GetAttributeChangedSignal('PhysicalWalkSpeed'):Connect(repaint);local b=player:GetAttributeChangedSignal('FriendSpeedBoost'):Connect(repaint)
script.Destroying:Connect(function()added:Disconnect();removed:Disconnect();a:Disconnect();b:Disconnect();for m in pairs(labels)do remove(m)end end)
