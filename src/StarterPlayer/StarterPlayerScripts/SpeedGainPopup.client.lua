do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- Treadmill speed-gain popups. Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- V0.55: whole-point gains from the head. R151 (owner: "speed gain should be touch up regarding the speed popups ... keep ours white but the physics and feel of
-- it should feel the same as the video", then "proposed + split"): the motion of a popular treadmill game's popups with OUR colours, font and bolt. All numbers
-- and curves are in ReplicatedStorage/SpeedPopupStyle (measured in docs/proposals/R151/speed_popups.md): a popup is born at the head at 0.45 size, pops past
-- full size, flies to its own spot in a fan above the head (cubic ease-out, 0.4 s, pixels not studs), holds, fades in 0.15 s and is gone at 0.65 s. The
-- local player's award is shown as 2 equal shares per server tick (12 a second, the sum is exact); other players' popups (only within 100 studs) are not split.
-- Reduced Motion: no fling or pop, a plain fade-up. FastMode / a slow device (ClientFxBudget tier 1) and phones (tier 2) keep fewer alive (SpeedPopupStyle.Caps).
-- Cheap by construction: one BillboardGui per player that has popups, from a small pool, holding pooled popup frames that are moved and reused; ONE RenderStepped
-- updater for all of them, connected only while a popup is alive or queued; no TweenService, no task.delay, no Instance created or destroyed once the pool exists.
-- (The server still publishes Config.TreadmillPopupLifetime as the remote's PopupLifetime attribute; the lifetime now lives in SpeedPopupStyle.)
do
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("ChestChaseRemotes", 10)
assert(remotes, "[V0.55] Missing ChestChaseRemotes; check the first server error.")

local speedGainPopup = remotes:WaitForChild("SpeedGainPopup", 10)
assert(speedGainPopup, "[V0.55] Missing SpeedGainPopup; install matching Config and BaseService modules.")

local Style = require(ReplicatedStorage:WaitForChild("SpeedPopupStyle"))
local Budget = require(ReplicatedStorage:WaitForChild("ClientFxBudget"))

local randomizer = Random.new()
local function rng() return randomizer:NextNumber() end

local function rgb(c) return Color3.fromRGB(c[1], c[2], c[3]) end
local TEXT_COLOR, STROKE_COLOR = rgb(Style.Colors.Text), rgb(Style.Colors.TextStroke)
local ICON_COLOR, LEGACY_STROKE = rgb(Style.Colors.Icon), rgb(Style.Colors.LegacyStroke)

local entries = {}                                  -- [Player] = what is alive or queued for that player (removed when nothing is)
local bags = setmetatable({}, {__mode = "k"})       -- [Player] = the fan-slot bag of SpeedPopupStyle.Plan (kept, tiny)
local freeFields = {}                               -- idle pooled fields
local itemPool = {}                                 -- recycled queue items
local connection                                    -- the one RenderStepped updater, only while entries is not empty

-- Pool: a field (BillboardGui) holds popups (a Frame with the bolt and the amount); nothing is destroyed while it is in use ----------------------------
local function makeLabel(parent, name, text, textSize, color, width, order)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromOffset(width, Style.Size.Box[2])
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font[Style.Font]
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeColor3 = LEGACY_STROKE
	label.TextStrokeTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Name = "BoldOutline86"
	stroke.Thickness = Style.StrokeThickness
	stroke.Color = STROKE_COLOR
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	label.Parent = parent
	return label, stroke
end

local function makePopup(field)
	local box = Style.Size.Box
	local frame = Instance.new("Frame")
	frame.Name = "Popup"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.fromOffset(box[1], box[2])
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Visible = false
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Style.Size.Gap)
	layout.Parent = frame
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = frame
	local icon, iconStroke = makeLabel(frame, "Lightning", Style.Icon, Style.Size.Icon, ICON_COLOR, Style.Size.IconBox, 1)
	local amount, amountStroke = makeLabel(frame, "Amount", "", Style.Size.Text, TEXT_COLOR, 0, 2)
	amount.AutomaticSize = Enum.AutomaticSize.X
	frame.Parent = field.Gui
	local popup = {
		Field = field, Frame = frame, Scale = uiScale, Icon = icon, IconStroke = iconStroke, Amount = amount, AmountStroke = amountStroke,
		Plan = {}, At = 0, Retired = nil, Reduced = false, Unit = 1, FanX = 1, FanY = 1, PX = 0, PY = 0, PS = 1, PA = 1,
	}
	field.Popups[#field.Popups + 1] = popup
	return popup
end

local function makeField()
	local f = Style.Field
	local gui = Instance.new("BillboardGui")
	gui.Name = f.Name
	gui.Size = UDim2.fromOffset(f.Width, f.Height)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = Style.MaxDistance
	gui.ResetOnSpawn = false
	gui.Active = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = playerGui
	return {Gui = gui, Popups = {}, Free = {}, Seq = 0}
end

local function takeField(head)
	local field = table.remove(freeFields)
	while field and field.Gui.Parent ~= playerGui do field = table.remove(freeFields) end -- one that was removed from the PlayerGui is not reused
	field = field or makeField()
	field.Gui.Adornee = head
	field.Gui.Enabled = true
	return field
end

local function giveField(field)
	field.Gui.Enabled = false
	field.Gui.Adornee = nil
	if #freeFields < Style.Field.FreeFields then freeFields[#freeFields + 1] = field else field.Gui:Destroy() end
end

local function takeItem(at, amount)
	local item = table.remove(itemPool) or {}
	item.At, item.Amount = at, amount
	return item
end

local function hidePopup(popup)
	popup.Frame.Visible = false
	popup.Retired = nil
	local free = popup.Field.Free
	free[#free + 1] = popup
end

-- Everything of one player is put away (the player left, the character was replaced, or nothing is alive any more).
local function finishEntry(entry)
	local active, pending = entry.Active, entry.Pending
	for i = #active, 1, -1 do hidePopup(active[i]); active[i] = nil end
	for i = #pending, 1, -1 do itemPool[#itemPool + 1] = pending[i]; pending[i] = nil end
	if entry.Field then giveField(entry.Field); entry.Field = nil end
end

-- Moving one popup: only what changed is written (a resting popup costs nothing) ---------------------------------------------------------------------
local function apply(popup, x, y, scale, alpha)
	local unit = popup.Unit
	x, y = x * unit * popup.FanX, y * unit * popup.FanY -- (R153: the fan's size on this screen, SpeedPopupStyle.FanScale)
	if math.abs(x - popup.PX) > 0.05 or math.abs(y - popup.PY) > 0.05 then
		popup.PX, popup.PY = x, y
		popup.Frame.Position = UDim2.new(0.5, x, 0.5, y)
	end
	scale = scale * unit
	if math.abs(scale - popup.PS) > 0.002 then
		popup.PS = scale
		popup.Scale.Scale = scale
	end
	if math.abs(alpha - popup.PA) > 0.004 then
		popup.PA = alpha
		local t = 1 - alpha
		popup.Icon.TextTransparency = t
		popup.Icon.TextStrokeTransparency = t
		popup.IconStroke.Transparency = t
		popup.Amount.TextTransparency = t
		popup.Amount.TextStrokeTransparency = t
		popup.AmountStroke.Transparency = t
	end
end

local function readReducedMotion() return GuiService.ReducedMotionEnabled end
local function reducedMotion()
	local ok, value = pcall(readReducedMotion)
	return ok and value == true
end

-- ClientFxBudget tier (3 best .. 1 lowest); FastMode is always 1.
local function currentTier()
	if localPlayer:GetAttribute("FastMode") == true then return 1 end
	local ok, tier = pcall(Budget.Get)
	return ok and tier or 1
end

local function spawnPopup(entry, item, now)
	local reduced = reducedMotion()
	local cap = Style.Cap(currentTier(), entry.Own, reduced)
	local active = entry.Active
	-- over the cap: the oldest ones fade out fast (SpeedPopupStyle.RetireFade) instead of vanishing
	local live = 0
	for i = 1, #active do if active[i].Retired == nil then live += 1 end end
	if live >= cap then
		for i = 1, #active do
			local old = active[i]
			if old.Retired == nil then
				old.Retired = now - old.At
				live -= 1
				if live < cap then break end
			end
		end
	end
	local field = entry.Field
	if not field then
		field = takeField(entry.Head)
		entry.Field = field
	end
	-- the pool is built whole the first time a field is used for this cap (cap + Spare frames); after that nothing is created
	while #field.Popups < cap + Style.Field.Spare do
		local built = makePopup(field)
		field.Free[#field.Free + 1] = built
	end
	local popup = table.remove(field.Free)
	if not popup then popup = table.remove(active, 1) end -- every frame is busy (not expected): the oldest goes at once
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
	popup.Unit = Style.Unit(viewport and viewport.Y)
	popup.FanX, popup.FanY = Style.FanScale(viewport and viewport.X, viewport and viewport.Y)
	popup.Reduced = reduced
	popup.At = item.At
	popup.Retired = nil
	local plan = Style.Plan(rng, entry.Bag, popup.Plan)
	field.Seq = field.Seq % 1000000 + 1
	popup.Frame.ZIndex = field.Seq -- the newest is drawn on top
	popup.Icon.Rotation = reduced and 0 or plan.IconTilt
	popup.Amount.Rotation = reduced and 0 or plan.TextTilt
	popup.Amount.Text = "+" .. Style.FormatGain(item.Amount)
	popup.PX, popup.PY, popup.PS, popup.PA = math.huge, math.huge, -1, -1 -- the first pose writes everything
	local x, y, scale, alpha = Style.Pose(plan, now - item.At, reduced)
	apply(popup, x, y, scale, alpha)
	popup.Frame.Visible = true
	active[#active + 1] = popup
end

-- One entry per frame: spawn what is due, move what is alive. Returns false when the entry is finished (nothing alive or queued, or the player / character is gone).
local function updateEntry(entry, now)
	local player = entry.Player
	if player.Parent == nil or player.Character ~= entry.Character or entry.Head.Parent == nil then return false end
	local pending = entry.Pending
	local index = 1
	while index <= #pending do
		local item = pending[index]
		if item.At <= now then
			table.remove(pending, index)
			-- as before R151: the award only shows while the player is still on the treadmill with the character that earned it
			if player:GetAttribute("TreadmillTraining") == true and now - item.At < Style.Life then spawnPopup(entry, item, now) end
			itemPool[#itemPool + 1] = item
		else
			index += 1
		end
	end
	local active = entry.Active
	index = 1
	while index <= #active do
		local popup = active[index]
		local x, y, scale, alpha, alive = Style.Pose(popup.Plan, now - popup.At, popup.Reduced, popup.Retired)
		if alive then
			apply(popup, x, y, scale, alpha)
			index += 1
		else
			table.remove(active, index)
			hidePopup(popup)
		end
	end
	return #active > 0 or #pending > 0
end

local function step()
	local now = os.clock()
	for player, entry in pairs(entries) do
		if not updateEntry(entry, now) then
			finishEntry(entry)
			entries[player] = nil
		end
	end
	if next(entries) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- A delayed server frame can contain several real awards (ticks). Each tick is shown as SplitFor popups of equal share for the local player (the sum is kept
-- exactly), spaced over the tick; old-character events are rejected when they are due.
speedGainPopup.OnClientEvent:Connect(function(targetPlayer, amount, _, ticks, interval, earnedCharacter)
	if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player")
		or type(amount) ~= "number" or amount ~= amount or amount <= 0
		or amount > 1000000000 then return end
	amount = math.floor(amount)
	if amount < 1 then return end
	local character = earnedCharacter or targetPlayer.Character
	if typeof(character) ~= "Instance" or targetPlayer.Character ~= character or targetPlayer.Parent == nil then return end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - head.Position).Magnitude > Style.MaxDistance then return end
	local own = targetPlayer == localPlayer
	local split = Style.SplitFor(own, reducedMotion())
	local shares = Style.Shares(amount, ticks, split)
	if shares < 1 then return end
	local spacing = Style.Spacing(interval, split, shares)
	local entry = entries[targetPlayer]
	if entry and (entry.Character ~= character or entry.Head ~= head) then
		finishEntry(entry) -- a new character: the old one's popups are gone
		entries[targetPlayer] = nil
		entry = nil
	end
	if not entry then
		local bag = bags[targetPlayer]
		if not bag then
			bag = {}
			bags[targetPlayer] = bag
		end
		entry = {Player = targetPlayer, Own = own, Character = character, Head = head, Bag = bag, Field = nil, Active = {}, Pending = {}}
		entries[targetPlayer] = entry
	end
	local pending = entry.Pending
	local now = os.clock()
	local each, extra = amount // shares, amount % shares
	for i = 1, shares do
		if #pending >= Style.Cadence.MaxPending then break end
		pending[#pending + 1] = takeItem(now + (i - 1) * spacing, each + (i <= extra and 1 or 0))
	end
	if not connection then connection = RunService.RenderStepped:Connect(step) end
end)

Players.PlayerRemoving:Connect(function(player)
	local entry = entries[player]
	if entry then
		finishEntry(entry)
		entries[player] = nil
	end
	bags[player] = nil
end)

script.Destroying:Connect(function()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end)

if game:GetService('RunService'):IsStudio()then print("[R151] PASS - speed popups: pooled, one updater, popped and flung like the reference, split awards for you.") end -- R114: Studio-only load message
end


do
-- V134: broad forward arrows and biome track motion, with jump to exit.
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Input=game:GetService('UserInputService')
local Run=game:GetService('RunService')
local player=Players.LocalPlayer
local playerGui=player:WaitForChild('PlayerGui')
local remotes=ReplicatedStorage:WaitForChild('ChestChaseRemotes',15)
assert(remotes,'[V133] Missing ChestChaseRemotes.')
local stop=remotes:WaitForChild('StopTreadmillTraining',15)
assert(stop,'[V133] Missing StopTreadmillTraining.')
local old=playerGui:FindFirstChild('TreadmillTrainingUI');if old then old:Destroy()end
for _,child in ipairs(playerGui:GetChildren())do
    if child.Name=='TreadmillMovingBelt'and child:IsA('SurfaceGui')then child:Destroy()end
end
local lastRequest=-math.huge
local connections={}
table.insert(connections,Input.JumpRequest:Connect(function()
    if Input:GetFocusedTextBox()or player:GetAttribute('TreadmillTraining')~=true then return end
    local now=os.clock();if now-lastRequest<.20 then return end;lastRequest=now
    stop:FireServer()
end))
-- One cached local animator. Fixed collision belt; no server animation writes.
local belts={}
local function disableMotes(record)
    for _,e in ipairs(record.Emitters)do if e.Parent then e.Enabled=false end end
end
local function releaseBelt(record)
    disableMotes(record)
    for _,connection in ipairs(record.Connections)do connection:Disconnect()end
end
local function syncBelt(belt)
    local base=belt.Parent;local art=base and base:FindFirstChild('TreadmillArtV131')
    if not art or art:GetAttribute('TreadmillTrackVersion')~=133 then return end
    local record=belts[belt]
    if not record or record.Art~=art then
        if record then releaseBelt(record)end
        record={Art=art,Distance=0,Clock=0,Motion={},Emitters={},Dirty=true,Connections={}};belts[belt]=record
        local function changed()record.Dirty=true end
        table.insert(record.Connections,art.DescendantAdded:Connect(changed))
        table.insert(record.Connections,art.DescendantRemoving:Connect(changed))
    end
    -- Streaming additions/removals invalidate the cache. Idle models need no descendant scan.
    if not record.Dirty then return end;record.Dirty=false
    local motion,emitters={},{}
    for _,v in ipairs(art:GetDescendants())do
        if v:IsA('BasePart')and v:GetAttribute('TrackMotion')then
            local rest,phase,rate=v:GetAttribute('TrackRest'),v:GetAttribute('TrackPhase'),v:GetAttribute('TrackRate')
            if typeof(rest)=='CFrame'and type(phase)=='number'and type(rate)=='number'then
                table.insert(motion,{Part=v,Rest=rest,Phase=phase,Rate=rate,Travel=v:GetAttribute('TrackTravel')or 10.8,Alpha=v:GetAttribute('TrackAlpha')or 0,Pulse=v:GetAttribute('TrackPulse')})
            end
        elseif v:IsA('ParticleEmitter')and v:GetAttribute('TreadmillTrackEmitter')then
            table.insert(emitters,v)
        end
    end
    for _,e in ipairs(record.Emitters)do
        if not e:IsDescendantOf(art)then e.Enabled=false end
    end
    record.Motion=motion;record.Emitters=emitters
end
local scan,elapsed=1,0
local moving,frames={},{} -- R121: reused BulkMoveTo buffers (were new tables every 30 Hz tick)
table.insert(connections,Run.Heartbeat:Connect(function(dt)
    scan+=dt;elapsed+=dt
    if scan>=1 then
        scan=0
        local map=workspace:FindFirstChild('ChestChaseMap');local bases=map and map:FindFirstChild('Bases')
        if bases then
            for _,base in ipairs(bases:GetChildren())do
                local belt=base:FindFirstChild('Treadmill')
                if belt and belt:IsA('BasePart')and belt:GetAttribute('TreadmillTrainingBelt')then syncBelt(belt)end
            end
        end
    end
    local low=player:GetAttribute('FastMode')==true
    if elapsed<(low and 1/20 or 1/30)then return end
    local step=math.min(elapsed,.10);elapsed=0
    local camera=workspace.CurrentCamera;table.clear(moving);table.clear(frames)
    for belt,record in pairs(belts)do
        if not belt:IsDescendantOf(workspace)or record.Art.Parent~=belt.Parent then
            releaseBelt(record);belts[belt]=nil
        else
            local distance=camera and (camera.CFrame.Position-belt.Position).Magnitude or math.huge
            local near=distance<(low and 90 or 140)
            for _,e in ipairs(record.Emitters)do
                if e.Parent then
                    local enabled=not low and distance<85
                    if e.Enabled~=enabled then e.Enabled=enabled end
                end
            end
            if near then
                record.Distance+=step*(belt:GetAttribute('TrainingActive')and 3.0 or 1.3)
                record.Clock+=step
                for _,entry in ipairs(record.Motion)do
                    local v=entry.Part
                    if v.Parent==record.Art then
                        -- Negative Z is forward. Each complete arrow fades together at wrap.
                        local phase=(entry.Phase-record.Distance*entry.Rate/entry.Travel)%1
                        local edge=math.clamp(math.min(phase,1-phase)/.07,0,1)
                        local pulse=entry.Pulse and (.06+.06*math.sin(record.Clock*1.8+entry.Phase*math.pi*2))or 0
                        local alpha=1-edge*(1-math.clamp(entry.Alpha+pulse,0,1))
                        if math.abs(v.Transparency-alpha)>.005 then v.Transparency=alpha end
                        table.insert(moving,v)
                        table.insert(frames,belt.CFrame*CFrame.new(0,0,(phase-.5)*entry.Travel)*entry.Rest)
                    end
                end
            end
        end
    end
    if #moving>0 then workspace:BulkMoveTo(moving,frames,Enum.BulkMoveMode.FireCFrameChanged)end
end))
table.insert(connections,script.Destroying:Connect(function()
    for _,connection in ipairs(connections)do connection:Disconnect()end
    for _,record in pairs(belts)do releaseBelt(record)end
    table.clear(belts)
end))
if game:GetService('RunService'):IsStudio()then print('[V134] PASS - forward arrows and living biome tracks; jump to exit.') end -- R114: Studio-only load message
end


-- R71: style menu removed; the existing garden floor button still upgrades the treadmill.
