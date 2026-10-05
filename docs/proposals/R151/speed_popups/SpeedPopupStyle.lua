-- R151 PROPOSAL (not wired into the game; nothing under src/ uses it yet). The look and motion of the treadmill speed-gain popups ("+3.5K" with
-- an icon): every tunable number in one place and the pure curves that turn a popup's age into where it is, how big and how clear. Pure functions
-- only (no Instances, no gameplay), like TreadmillBonusStyle, so the Roblox mock and the preview run the very same code. The numbers are the ones
-- measured from the owner's reference clip (docs/proposals/R151/speed_popups.md, reference_fit.py); colours, font and the icon stay OURS.
--
-- Units: "design px" = pixels of a 1080-pixel-high screen. The client multiplies every px value by S.Unit(viewportHeight). A popup's offset is
-- measured from the anchor (the player's head) in SCREEN pixels, not studs, so it moves and looks the same at any camera distance.
local S = {}
S.Version = 1

-- Our look (kept exactly as SpeedGainPopup.client.lua has it today; only the sizes shrink, see Size).
S.Colors = {
	Text = {125, 248, 255},          -- the amount (unchanged)
	TextStroke = {17, 26, 42},       -- its outline colour (unchanged; UIStroke 'BoldOutline86' thickness 2.5)
	Icon = {255, 222, 66},           -- the lightning glyph (unchanged)
	IconStroke = {0, 0, 0},
}
S.Font = 'FredokaOne'                -- unchanged
S.Icon = '\u{26A1}'                  -- unchanged
S.StrokeThickness = 2.5              -- unchanged
-- Reference: the video's text is ~1.8% of the screen height; ours was 26 px on a 1080 p screen (2.4%). Smaller = "many small popups".
S.Size = {Text = 22, Icon = 20, Box = {150, 36}, IconTilt = 14, TextTilt = 3}   -- design px, degrees (random, +-)

-- Spawn: the popup starts AT the head (the video: head centre, within a few px), already 45% of full size, nothing in front of the face.
S.Spawn = {Lift = 5, Jitter = 6}     -- px above the head centre, +- px of random start offset
-- Pop: scale goes from From to 1 in Time seconds with a "back" ease-out; Back = 2 gives a 7% overshoot that peaks ~0.16 s after the spawn
-- (the clip: mean of three popups 1.06, single popups up to 1.13; first frame 0.5, 0.7, 0.9, 1.0 after).
S.Pop = {From = 0.45, Time = 0.28, Back = 2.0}
-- Fling: it flies to its own spot in a fan above the head and stops there (cubic ease-out, no gravity, no drift).
--   HalfAngle: degrees from straight up (the video: -48..+72, mean 2, sd 43); Radius: design px from the head to the resting spot
--   (the video: 50..134 px of 1344 = 40..108 px at 1080; mean 78); Slots: the fan is cut in this many slots and each is used once per bag
--   (a shuffled bag, +-Jitter degrees) so consecutive popups never pile up on one spot.
S.Fling = {Time = 0.40, Power = 3, HalfAngle = 75, Radius = {44, 104}, Slots = 7, SlotJitter = 9}
-- Fade: opaque until Start, clear Length seconds later (the video: 0.45-0.50 s hold, 0.09-0.17 s fade, linear). The popup is gone at Life.
S.Fade = {Start = 0.50, Length = 0.15}
S.Life = S.Fade.Start + S.Fade.Length                -- 0.65 s
S.RetireFade = 0.08                                  -- a popup retired early (cap reached) fades out this fast instead of vanishing
-- Reduced Motion: no fling, no overshoot: it appears at the head, rises a little and fades (a simple fade-up).
-- Side: consecutive popups alternate this many px left / right so the numbers do not print over each other.
S.Reduced = {FadeIn = 0.08, Rise = 72, RiseTime = 0.70, FadeStart = 0.45, FadeLength = 0.25, Life = 0.70, Side = 14}
-- How many popups one player may have alive. Tier = ClientFxBudget tier (3 best .. 1 lowest; FastMode and a slow device are 1; phones start at 2).
-- The local player is always shown; other players' popups only within MaxDistance studs of the camera (as the game does now) and in fewer numbers.
S.Caps = {[3] = {Own = 8, Others = 3}, [2] = {Own = 6, Others = 2}, [1] = {Own = 4, Others = 1}}
S.ReducedCaps = {Own = 4, Others = 1}
S.MaxDistance = 100
-- Optional cadence: the video spawns one popup every 0.10 s. The server awards one tick every 1/6 s (Config.TrainingInterval), so by default one
-- popup per award (6 a second, the number is the real award). SplitTo: when set, an award is shown as several popups of equal share (sum kept) so
-- the stream is at least this many per second; nil = off (the proposal's default).
S.Cadence = {SplitTo = nil, Target = 10}

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
S.Clamp = clamp

-- px multiplier for this screen: 1 at 1080 p, never below .8 (phones keep it readable) or above 1.35.
function S.Unit(viewportHeight)
	viewportHeight = tonumber(viewportHeight) or 1080
	return clamp(viewportHeight / 1080, 0.8, 1.35)
end

-- Cap for one player: own popups or another player's.
function S.Cap(tier, isOwn, reduced)
	local row = reduced and S.ReducedCaps or S.Caps[clamp(math.floor(tonumber(tier) or 1), 1, 3)]
	return isOwn and row.Own or row.Others
end

-- Ease curves (u in 0..1 -> 0..1).
function S.EaseOut(u, power)
	u = clamp(u, 0, 1)
	return 1 - (1 - u) ^ power
end
function S.Back(u, c)
	u = clamp(u, 0, 1)
	local v = u - 1
	return 1 + (c + 1) * v * v * v + c * v * v
end

-- A new popup's plan. rng() returns a number in [0, 1); bag is the player's own table (start with {}), it holds the shuffled fan slots.
-- Returns {Angle (radians from straight up, + = right), Radius, StartX, StartY, ReducedX, IconTilt, TextTilt} in design px / degrees.
function S.Plan(rng, bag)
	local f = S.Fling
	if not bag.Slots or bag.Next > #bag.Slots then
		local slots = {}
		for i = 1, f.Slots do slots[i] = i end
		for i = #slots, 2, -1 do                                  -- Fisher-Yates
			local j = 1 + math.floor(rng() * i)
			slots[i], slots[j] = slots[j], slots[i]
		end
		-- never the same slot twice in a row across two bags
		if bag.Last and slots[1] == bag.Last then slots[1], slots[#slots] = slots[#slots], slots[1] end
		bag.Slots, bag.Next = slots, 1
	end
	local slot = bag.Slots[bag.Next]
	bag.Next += 1
	bag.Last = slot
	local width = 2 * f.HalfAngle / f.Slots
	local centre = -f.HalfAngle + (slot - 0.5) * width
	local degrees = clamp(centre + (rng() * 2 - 1) * f.SlotJitter, -f.HalfAngle, f.HalfAngle)
	local radius = f.Radius[1] + rng() * (f.Radius[2] - f.Radius[1])
	local sz = S.Size
	bag.Count = (bag.Count or 0) + 1
	return {
		ReducedX = (bag.Count % 2 == 0 and -1 or 1) * S.Reduced.Side,
		Angle = math.rad(degrees), Radius = radius,
		StartX = (rng() * 2 - 1) * S.Spawn.Jitter, StartY = -S.Spawn.Lift,
		IconTilt = (rng() * 2 - 1) * sz.IconTilt, TextTilt = (rng() * 2 - 1) * sz.TextTilt,
	}
end

-- Where a popup is at `age` seconds: x, y (design px from the head centre; y is DOWN like a screen, so up is negative), scale, alpha (1 opaque),
-- alive. `retiredAt` (optional): the age at which the cap retired it; it fades out RetireFade seconds from there.
function S.Pose(plan, age, reduced, retiredAt)
	if age < 0 then return 0, 0, 0, 0, true end
	local alpha, life
	if reduced then
		local r = S.Reduced
		life = r.Life
		local up = S.EaseOut(age / r.RiseTime, 2) * r.Rise
		alpha = clamp(age / r.FadeIn, 0, 1) * (1 - clamp((age - r.FadeStart) / r.FadeLength, 0, 1))
		if retiredAt then alpha = math.min(alpha, 1 - clamp((age - retiredAt) / S.RetireFade, 0, 1)) end
		return plan.ReducedX or 0, plan.StartY - up, 1, alpha, age < life and alpha > 0
	end
	life = S.Life
	local p = S.EaseOut(age / S.Fling.Time, S.Fling.Power)
	local x = plan.StartX + math.sin(plan.Angle) * plan.Radius * p
	local y = plan.StartY - math.cos(plan.Angle) * plan.Radius * p
	local pop = S.Pop
	local scale = pop.From + (1 - pop.From) * S.Back(age / pop.Time, pop.Back)
	alpha = 1 - clamp((age - S.Fade.Start) / S.Fade.Length, 0, 1)
	if retiredAt then alpha = math.min(alpha, 1 - clamp((age - retiredAt) / S.RetireFade, 0, 1)) end
	return x, y, scale, alpha, age < life and alpha > 0
end

-- How an award of `amount` whole points shown in `shares` popups divides (sum kept exactly, the extra points go to the first ones).
function S.Split(amount, shares)
	shares = math.max(1, math.min(math.floor(shares), math.floor(amount)))
	local each, extra, out = amount // shares, amount % shares, {}
	for i = 1, shares do out[i] = each + (i <= extra and 1 or 0) end
	return out
end

-- How many popups an award of `amount` is shown as, for the tick interval `interval` seconds: 1 unless Cadence.SplitTo asks for a faster stream.
function S.Shares(amount, interval)
	local target = S.Cadence.SplitTo
	if not target or not interval or interval <= 0 then return 1 end
	return math.max(1, math.min(math.floor(amount), math.ceil(interval * target - 1e-6)))
end

return S
