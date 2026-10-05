-- R151: look and motion of the treadmill speed-gain popups ("+4.2K" with a bolt; owner: "the physics and feel of it should feel the same as the video,
-- keep ours white"; then "proposed + split"). Every tunable number in one place plus the pure curves that turn a popup's age into where it is, how big
-- and how clear. Pure functions only (no Instances, no gameplay), like TreadmillBonusStyle, so the Roblox mock, the preview and the game run the very same
-- code. SpeedGainPopup.client.lua draws and moves the popups; the numbers are the ones measured from the reference clip (docs/proposals/R151/speed_popups.md);
-- colours, font and the bolt are OURS and unchanged.
--
-- Units: "design px" = pixels of a 1080-pixel-high screen. The client multiplies every px value by S.Unit(viewportHeight). A popup's offset is measured
-- from the anchor (the player's head) in SCREEN pixels, not studs, so it moves and looks the same at any camera distance.
local S = {}
S.Version = 1

-- Our look, exactly as SpeedGainPopup.client.lua had it before R151 (the amount's pale cyan with its navy outline, the yellow bolt, FredokaOne).
S.Colors = {
	Text = {125, 248, 255},          -- the amount
	TextStroke = {17, 26, 42},       -- its outline (UIStroke 'BoldOutline86')
	Icon = {255, 222, 66},           -- the bolt
	LegacyStroke = {0, 0, 0},        -- TextStrokeColor3 of both labels (TextStrokeTransparency 0, as before)
}
S.Font = 'FredokaOne'
S.Icon = '\u{26A1}'
S.StrokeThickness = 2.5
-- Reference: the video's text is ~1.8% of the screen height; ours was 26 px on a 1080 p screen (2.4%). Smaller = "many small popups".
-- Box = the frame the bolt and the number sit in (centred, 2 px apart); the tilts are random +- degrees per popup.
S.Size = {Text = 22, Icon = 20, Box = {150, 36}, IconBox = 24, Gap = 2, IconTilt = 14, TextTilt = 3}

-- Spawn: the popup starts AT the head (the video: head centre, within a few px), already 45% of full size, nothing in front of the face.
S.Spawn = {Lift = 5, Jitter = 6}     -- px above the head centre, +- px of random start offset
-- Pop: scale goes from From to 1 in Time seconds with a "back" ease-out; Back = 2 gives a 7% overshoot that peaks ~0.16 s after the spawn
-- (the clip: mean of three popups 1.06, single popups up to 1.13; first frame 0.5, 0.7, 0.9, 1.0 after).
S.Pop = {From = 0.45, Time = 0.28, Back = 2.0}
-- Fling: it flies to its own spot in a fan above the head and stops there (cubic ease-out, no gravity, no drift).
--   HalfAngle: degrees from straight up (the video: -48..+72, mean 2, sd 43); Radius: design px from the head to the resting spot
--   (the video: 50..134 px of 1344 = 40..108 px at 1080; mean 78); Slots: the fan is cut in this many slots and each is used once per bag
--   (a shuffled bag, +-SlotJitter degrees) so consecutive popups never pile up on one spot.
S.Fling = {Time = 0.40, Power = 3, HalfAngle = 75, Radius = {44, 104}, Slots = 7, SlotJitter = 9}
-- Fade: opaque until Start, clear Length seconds later (the video: 0.45-0.50 s hold, 0.09-0.17 s fade, linear). The popup is gone at Life.
S.Fade = {Start = 0.50, Length = 0.15}
S.Life = S.Fade.Start + S.Fade.Length                -- 0.65 s
S.RetireFade = 0.08                                  -- a popup retired early (cap reached) fades out this fast instead of vanishing
-- Reduced Motion: no fling, no overshoot: it appears at the head, rises and fades (a simple fade-up). Side: consecutive popups alternate this many px
-- left / right so the numbers do not print over each other.
S.Reduced = {FadeIn = 0.08, Rise = 72, RiseTime = 0.70, FadeStart = 0.45, FadeLength = 0.25, Life = 0.70, Side = 14}
-- How many popups one player may have alive. Tier = ClientFxBudget tier (3 best .. 1 lowest; FastMode and a slow device are 1; phones start at 2).
-- The local player is always shown; other players' popups only within MaxDistance studs of the camera (as the game did before) and in fewer numbers.
S.Caps = {[3] = {Own = 8, Others = 3}, [2] = {Own = 6, Others = 2}, [1] = {Own = 4, Others = 1}}
S.ReducedCaps = {Own = 4, Others = 1}
S.MaxDistance = 100
-- Cadence: the video spawns one popup every 0.10 s, the server awards one tick every 1/6 s (Config.TrainingInterval). SplitTo = how many popups ONE tick of
-- the local player's own award is shown as (equal shares, the sum kept exactly, never below 1 point each): 2 = 12 a second like the clip's 10. Other players'
-- popups and Reduced Motion are never split (their caps are lower; fewer popups is calmer). nil or 1 = off. MaxShares bounds one award event
-- (a lag burst of up to 10 ticks).
S.Cadence = {SplitTo = 2, MaxShares = 12, MaxTicks = 10, MinInterval = 0.1, MaxInterval = 1, MaxPending = 36}
-- The pooled field: one BillboardGui per player that has popups (fixed pixel size, centred on the head, room for the whole fan at the largest Unit).
-- Spare = frames kept beyond the cap (a retired popup still fades out for RetireFade s while its replacement is already there). FreeFields = how many idle
-- fields are kept for the next player or the next run (more are destroyed).
S.Field = {Name = 'SpeedGainField', Width = 560, Height = 420, Spare = 2, FreeFields = 4}

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
S.Clamp = clamp
-- A finite number or the default (a string, nil, NaN or infinity from a bad argument never gets into a curve or a count).
local function num(v, default)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return default end
	return v
end

-- px multiplier for this screen: 1 at 1080 p, never below .8 (phones keep it readable) or above 1.35.
function S.Unit(viewportHeight)
	return clamp(num(viewportHeight, 1080) / 1080, 0.8, 1.35)
end

-- Cap for one player: own popups or another player's.
function S.Cap(tier, isOwn, reduced)
	local row = reduced and S.ReducedCaps or S.Caps[clamp(math.floor(num(tier, 1)), 1, 3)]
	return isOwn and row.Own or row.Others
end

-- The text of an amount: 1,234 -> 1.2K, 3,500 -> 3.5K, 12,000 -> 12K, 1.5e6 -> 1.5M ... (K M B T), plain below 1,000.
-- R151 (owner: "for numnbers obvere 1000 it willl be read as 1k"): the unit is picked AFTER rounding, so nothing reads "1000" or "1000K":
-- 999.6 -> 1K, 999,950 -> 1M, 999,950,000 -> 1B, ... and a positive amount below 1 reads 1 (a gain never reads "+0"). Also used by the
-- treadmill's "+N/step" label and upgrade sign (TreadmillLook151), so the three always match.
function S.FormatGain(amount)
	amount = tonumber(amount) or 0
	if amount ~= amount then amount = 0 end
	if amount > 0 and amount < 1 then amount = 1 end
	local plain = string.format('%.0f', amount)
	if amount < 1e3 and (tonumber(plain) or 0) < 1e3 then return plain end
	local units = {{1e3, 'K'}, {1e6, 'M'}, {1e9, 'B'}, {1e12, 'T'}}
	for i, unit in ipairs(units) do
		local text = string.format('%.1f', amount / unit[1])
		if (tonumber(text) or 0) < 1e3 or i == #units then return (text:gsub('%.0$', '')) .. unit[2] end
	end
	return plain
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

-- A new popup's plan. rng() returns a number in [0, 1); bag is the player's own table (start with {}), it holds the shuffled fan slots. `into` (optional) is
-- a table to fill instead of making a new one (the client reuses one per pooled popup).
-- Returns {Angle (radians from straight up, + = right), Radius, StartX, StartY, ReducedX, IconTilt, TextTilt} in design px / degrees.
function S.Plan(rng, bag, into)
	local f = S.Fling
	if not bag.Slots or bag.Next > #bag.Slots then
		local slots = bag.Slots or {}
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
	local sz = S.Size
	bag.Count = (bag.Count or 0) + 1
	local plan = into or {}
	plan.Angle = math.rad(degrees)
	plan.Radius = f.Radius[1] + rng() * (f.Radius[2] - f.Radius[1])
	plan.StartX = (rng() * 2 - 1) * S.Spawn.Jitter
	plan.StartY = -S.Spawn.Lift
	plan.ReducedX = (bag.Count % 2 == 0 and -1 or 1) * S.Reduced.Side
	plan.IconTilt = (rng() * 2 - 1) * sz.IconTilt
	plan.TextTilt = (rng() * 2 - 1) * sz.TextTilt
	return plan
end

-- Where a popup is at `age` seconds: x, y (design px from the head centre; y is DOWN like a screen, so up is negative), scale, alpha (1 opaque),
-- alive. `retiredAt` (optional): the age at which the cap retired it; it fades out RetireFade seconds from there.
function S.Pose(plan, age, reduced, retiredAt)
	if age < 0 then return 0, 0, 0, 0, true end
	local alpha
	if reduced then
		local r = S.Reduced
		local up = S.EaseOut(age / r.RiseTime, 2) * r.Rise
		alpha = clamp(age / r.FadeIn, 0, 1) * (1 - clamp((age - r.FadeStart) / r.FadeLength, 0, 1))
		if retiredAt then alpha = math.min(alpha, 1 - clamp((age - retiredAt) / S.RetireFade, 0, 1)) end
		-- (alpha is 0 at age 0 while it fades in, so "clear" alone does not mean gone before FadeIn is over)
		return plan.ReducedX or 0, plan.StartY - up, 1, alpha, age < r.Life and (alpha > 0 or age < r.FadeIn)
			and not (retiredAt and age - retiredAt >= S.RetireFade)
	end
	local p = S.EaseOut(age / S.Fling.Time, S.Fling.Power)
	local x = plan.StartX + math.sin(plan.Angle) * plan.Radius * p
	local y = plan.StartY - math.cos(plan.Angle) * plan.Radius * p
	local pop = S.Pop
	local scale = pop.From + (1 - pop.From) * S.Back(age / pop.Time, pop.Back)
	alpha = 1 - clamp((age - S.Fade.Start) / S.Fade.Length, 0, 1)
	if retiredAt then alpha = math.min(alpha, 1 - clamp((age - retiredAt) / S.RetireFade, 0, 1)) end
	return x, y, scale, alpha, age < S.Life and alpha > 0
end

-- How an award of `amount` whole points shown in `shares` popups divides (sum kept exactly, the extra points go to the first ones).
function S.Split(amount, shares)
	shares = math.max(1, math.min(math.floor(shares), math.floor(amount)))
	local each, extra, out = amount // shares, amount % shares, {}
	for i = 1, shares do out[i] = each + (i <= extra and 1 or 0) end
	return out
end

-- How many popups ONE tick of an award is shown as for this kind of player: SplitTo for the local player at full motion, else 1.
function S.SplitFor(isOwn, reduced)
	local split = num(S.Cadence.SplitTo, 1)
	if not isOwn or reduced then return 1 end
	return clamp(math.floor(split), 1, 4)
end

-- How many popups an award event of `amount` whole points is shown as: `ticks` (the server ticks the event covers, 1..MaxTicks) times `split`, never more
-- than MaxShares and never more than the points (each share is at least 1 point). 0 for less than 1 point.
function S.Shares(amount, ticks, split)
	amount = num(amount, 0)
	if amount < 1 then return 0 end
	local c = S.Cadence
	ticks = clamp(math.floor(num(ticks, 1)), 1, c.MaxTicks)
	split = clamp(math.floor(num(split, 1)), 1, 4)
	return math.max(1, math.min(math.floor(amount), ticks * split, c.MaxShares))
end

-- Seconds between the popups of one award event: one tick's interval (clamped 0.1 .. 1 s) shared by `split` popups, and the whole burst within one second.
function S.Spacing(interval, split, shares)
	local c = S.Cadence
	interval = clamp(num(interval, 1 / 6), c.MinInterval, c.MaxInterval)
	return math.min(interval / math.max(1, num(split, 1)), 1 / math.max(1, num(shares, 1)))
end

return S
