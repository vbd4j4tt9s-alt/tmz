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
-- R153 (owner: "make it so that speed needed thing is dislocated from the keeper and is way above the keepers head"; then "for the
-- secret keeper just put the inf speed like above him really high up but stays at his spawn point so when he chases the player it
-- doesnt follow the keeper, for other keepers adopt this same thing"): the sign no longer rides on the keeper. It hangs on its own
-- invisible anchored part at the keeper's spawn point (the server stamps KeeperHome: ChaseService for the biome keepers, VeiledEvent81 for
-- The Darkened, per appearance), LIFT studs above the top of the keeper's body at rest, and stays there while the keeper chases.
-- R152's bug was that the height was measured once, at the tag, from whatever the model was then (today's smaller keeper before the baked
-- rev 6 model was swapped in, a model still streaming in, a pose, effect parts) and hung 2.5 studs over that: on the head. Now the body
-- top is measured from the rest poses (the RestCFrame / TreeRestCFrame / IdleRestCFrame the rig parts carry, so the pose and the
-- animation do not matter), without the root / hitbox and the effect parts, and measured again - debounced - only when body parts are
-- added or removed (a swap, a late stream); it stops listening once the model has been quiet. No per-frame work; nothing is written unless it changed.
-- (The R153 jitter sweep had hung the sign on a smoothed-body follow anchor so it glided with the keeper. A pinned sign never moves,
-- so there is nothing to smooth: it uses no follow anchor, and that anchor module (KeeperFollow) is gone.)
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local player=Players.LocalPlayer
local LIFT=18 -- studs from the top of the keeper's body at rest up to the centre of the sign (owner: "really high up"; the sign is a fixed 104x36 px, far away its half height is a few studs: this keeps a gap)
local MAX_TOP=80 -- a body is never counted taller than this (a runaway part cannot send the sign into the sky)
local RANGE=250 -- MaxDistance: the sign is high up and the run-up sees it from far (it keeps its pixel size: a longer range does not make it bigger)
local DEBOUNCE=.5 -- seconds: body parts that arrive together are measured once, and never more than twice a second
local QUIET=5 -- seconds without a body change after which the model stops being watched (a swap to the baked model re-arms it: KeeperMeshVariant)
local DARKENED_TOP=13.5 -- The Darkened's standing head top over its root (VeiledKeeper81's awake pose reaches 13.06; asleep it lies at 4.3): its pieces follow group frames, so no rest frame says it
local Progress=require(RS:WaitForChild('Progression81'));local Points=require(RS:WaitForChild('SpeedPoints'))
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
 local gui=Instance.new('BillboardGui');gui.Name='SpeedReq';gui.Size=UDim2.fromOffset(104,36);gui.LightInfluence=0;gui.MaxDistance=RANGE
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
-- (the sign shows only once it has a place and a body to hang over: entry.Placed)
local function paint(entry)
 local escape=tonumber(entry.Model:GetAttribute('KeeperEscapeSpeed'))
 if not escape or not entry.Placed then entry.Gui.Enabled=false;return end
 local mine=tonumber(player:GetAttribute('PhysicalWalkSpeed'))or Progress.Speed(0)
 local fast=mine>escape;local need=needText(escape)
 local pill=entry.Gui.Pill;local color=fast and GREEN or RED
 pill.Value.Text='⚡ '..need..(fast and'  ✓'or'')
 pill.Value.TextColor3=color;pill.Edge.Color=color;entry.Gui.Enabled=true
end
-- The anchors: one invisible, anchored, non-colliding, non-touch, non-query part per sign, in one client folder, at the keeper's spawn point.
local anchors
local function anchorFolder()
 if not anchors or not anchors.Parent then anchors=Instance.new('Folder');anchors.Name='KeeperSignAnchors';anchors.Parent=workspace end
 return anchors
end
-- What counts as the keeper's body: the parts of its rig, not its root / hitbox and not what the effects add (the colossus's surge
-- arcs, KeeperFx's parts, anything marked KeeperFxKind, invisible parts). The flames, wisps, leaves, rain, bolts and trails of KeeperFx152
-- are emitters / beams / attachments, not parts, and the Colossus's cloud crown is a real mesh on its head: the sign clears it.
local REST={{'RestCFrame',nil},{'TreeRestCFrame','TreeRestSize'},{'IdleRestCFrame','IdleRestSize'}}
local function isEffect(part)
 local name=part.Name
 return part.Transparency>=1 or part:GetAttribute('KeeperFxKind')~=nil or name=='Electrical surge' or string.sub(name,1,8)=='KeeperFx' or string.sub(name,1,9)=='KeeperHit'
  or part:FindFirstAncestor('ColossusSurges')~=nil
end
local function halfY(cf,size)return(math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z)/2 end
-- Top of the keeper's body at rest, in studs over its root, and how many body parts it saw (nil, 0: none yet). A rig part carries its rest
-- frames (root space) as attributes, so the pose it is in now does not matter; The Darkened's pieces (VeiledFrame, group space) and the
-- parts of a model without rig attributes are measured where they are now, and The Darkened's top is never below its standing height.
-- Once any rig part is there only rig parts count: whatever else the model holds (hitbox, effects) is not the body.
local function bodyTop(model,root)
 local rigTop,rigN,otherTop,otherN=-math.huge,0,-math.huge,0
 local rootY=root and root.Position.Y or 0
 for _,d in ipairs(model:GetDescendants())do
  if d:IsA('BasePart')and d~=root then
   local rest,veiled=d:GetAttribute('RestCFrame'),d:GetAttribute('VeiledFrame')
   if rest or veiled then
    local t=-math.huge
    if rest then
     for _,k in ipairs(REST)do
      local cf=d:GetAttribute(k[1])
      if typeof(cf)=='CFrame'then
       local size=k[2]and d:GetAttribute(k[2]);if typeof(size)~='Vector3'then size=d.Size end
       t=math.max(t,cf.Position.Y+halfY(cf,size))
      end
     end
    end
    if t==-math.huge then t=d.Position.Y-rootY+halfY(d.CFrame,d.Size)end
    rigTop=math.max(rigTop,t);rigN+=1
   elseif not isEffect(d)then otherTop=math.max(otherTop,d.Position.Y-rootY+halfY(d.CFrame,d.Size));otherN+=1 end
  end
 end
 local top,n=rigTop,rigN
 if rigN==0 then top,n=otherTop,otherN end
 if n==0 then return nil,0 end
 if model:GetAttribute('VeiledKeeper81')then top=math.max(top,DARKENED_TOP)end
 return top,n
end
-- Pins the sign: the anchor at the keeper's spawn point (KeeperHome; where the keeper was first seen if the server has not stamped it),
-- the sign LIFT studs over the body top. False until there is a place and a body to measure. Writes only what changed.
local function place(entry)
 local model=entry.Model;local root=model.PrimaryPart or model:FindFirstChild('HumanoidRootPart')or model:FindFirstChildWhichIsA('BasePart',true)
 local home=model:GetAttribute('KeeperHome')
 if typeof(home)~='Vector3'then if not entry.Seen and root then entry.Seen=root.Position end;home=entry.Seen end
 local top=bodyTop(model,root)
 if not home or not top then return false end
 local a=entry.Anchor
 if not a then
  a=Instance.new('Part');a.Name='SpeedSign';a.Size=Vector3.new(.2,.2,.2);a.Transparency=1;a.Anchored=true;a.CanCollide=false;a.CanTouch=false;a.CanQuery=false;a.CastShadow=false;a.Locked=true
  local link=Instance.new('ObjectValue');link.Name='Keeper';link.Value=model;link.Parent=a
  a.CFrame=CFrame.new(home);a.Parent=anchorFolder();entry.Anchor=a;entry.Home=home
  entry.Gui.Adornee=a;entry.Gui.Parent=a
 elseif entry.Home~=home then entry.Home=home;a.CFrame=CFrame.new(home)end
 local y=math.clamp(top,2,MAX_TOP)+LIFT
 if not entry.Lift or math.abs(entry.Lift-y)>.25 then entry.Lift=y;entry.Gui.StudsOffsetWorldSpace=Vector3.new(0,y,0)end
 entry.Placed=true
 return true
end
local function disarm(entry)
 if entry.Watch then for _,c in ipairs(entry.Watch)do c:Disconnect()end;entry.Watch=nil end
end
-- QUIET seconds after the last body change (and its measurement) the model is no longer watched.
local function settle(entry)
 entry.Settle=(entry.Settle or 0)+1;local token=entry.Settle
 task.delay(QUIET,function()if entry.Settle==token and not entry.Pending and labels[entry.Model]==entry then disarm(entry)end end)
end
-- The body changed (parts added / removed: a swap to the baked model, a late stream): measure again after DEBOUNCE, once for all of them.
local function dirty(entry)
 entry.Settle=(entry.Settle or 0)+1
 if entry.Pending then return end
 entry.Pending=true
 task.delay(DEBOUNCE,function()
  entry.Pending=false
  if labels[entry.Model]~=entry then return end
  if place(entry)then paint(entry);settle(entry)end
 end)
end
local function arm(entry)
 if entry.Watch then return end
 local function hit(d)if d:IsA('BasePart')then dirty(entry)end end
 entry.Watch={entry.Model.DescendantAdded:Connect(hit),entry.Model.DescendantRemoving:Connect(hit)}
end
local function add(model)
 if labels[model]or not model:IsA('Model')then return end
 local entry={Model=model,Gui=build(model),Links={}}
 labels[model]=entry
 arm(entry)
 if place(entry)then settle(entry)end
 paint(entry)
 entry.Links[#entry.Links+1]=model:GetAttributeChangedSignal('KeeperEscapeSpeed'):Connect(function()paint(entry)end)
 entry.Links[#entry.Links+1]=model:GetAttributeChangedSignal('KeeperHome'):Connect(function()if place(entry)then paint(entry)end end)
 entry.Links[#entry.Links+1]=model:GetAttributeChangedSignal('KeeperMeshVariant'):Connect(function()arm(entry);dirty(entry)end)
end
local function remove(model)
 local entry=labels[model];if not entry then return end;labels[model]=nil
 disarm(entry);for _,c in ipairs(entry.Links)do c:Disconnect()end;entry.Gui:Destroy();if entry.Anchor then entry.Anchor:Destroy()end
end
local function repaint()for _,entry in pairs(labels)do paint(entry)end end
for _,m in ipairs(CS:GetTagged('BiomeKeeper'))do add(m)end
local added=CS:GetInstanceAddedSignal('BiomeKeeper'):Connect(add);local removed=CS:GetInstanceRemovedSignal('BiomeKeeper'):Connect(remove)
local a=player:GetAttributeChangedSignal('PhysicalWalkSpeed'):Connect(repaint)
script.Destroying:Connect(function()added:Disconnect();removed:Disconnect();a:Disconnect();for m in pairs(labels)do remove(m)end;if anchors then anchors:Destroy()end end)
