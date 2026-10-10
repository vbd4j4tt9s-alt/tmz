-- R151: look and motion of the treadmill speed-gain popups ("+4.2K" with a bolt; owner: "the physics and feel of it should feel the same as the video,
-- keep ours white"; then "proposed + split"). Every tunable number in one place plus the pure curves that turn a popup's age into where it is, how big
-- and how clear. Pure functions only (no Instances, no gameplay), like TreadmillBonusStyle, so the Roblox mock, the preview and the game run the very same
-- code. SpeedGainPopup.client.lua draws and moves the popups; the numbers are the ones measured from the reference clip (docs/proposals/R151/speed_popups.md);
-- colours, font and the bolt are OURS and unchanged.
--
-- Units: "design px" = pixels of a 1080-pixel-high screen. The client multiplies every px value by S.Unit(viewportHeight). A popup's offset is measured
-- from the anchor (the player's head) in SCREEN pixels at the default camera distance (S.Zoom.Distance); R155: the whole field then grows / shrinks with the camera's
-- distance to it like an object in the world (S.Zoom, S.ZoomScale), so the pixels below are the sizes at the default zoom.
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
S.StrokeThickness = 6
-- Reference: the video's text is ~1.8% of the screen height; ours was 26 px on a 1080 p screen (2.4%). Smaller = "many small popups".
-- Box = the frame the bolt and the number sit in (centred, Gap px apart); the tilts are random +- degrees per popup.
-- R153 (owner, in Studio: "numbers should also be bigger", then "2x bigger"): every size is 2x its R151 value (text 22 -> 44, bolt 20 -> 40, box 150 x 36 -> 300 x 72, bolt box
-- 24 -> 48, gap 2 -> 4, outline 2.5 -> 5); the motion, rate, colours and formatting are untouched. A fan this size does not fit a phone, see S.Fan below.
-- R154 (owner: "reduce the size of the speed notifier number by 20%"): 0.8 of the R153 sizes, so 1.6x R151's: text 44 -> 35, bolt 40 -> 32, box 300 x 72 -> 240 x 58, bolt box 48 -> 38,
-- gap 4 -> 3, outline 5 -> 4. A popup is this size from its first frame to its last (SpeedGainPopup: a pixel-sized BillboardGui; only the brief pop-in
-- below, 0.45 -> 1.07 -> 1 in 0.28 s, changes it). R155: these are the sizes at the default camera distance; the field's scale follows the zoom (S.Zoom).
-- R158 (owner: "increase the size of the speed popups as they are too small right now"): 1.5x R154's, so 2.4x R151's, to whole pixels: text 35 -> 53, bolt 32 -> 48, box 240 x 58 -> 360 x 86,
-- bolt box 38 -> 58, gap 3 -> 5, outline 4 -> 6 (the same shape, bolder to match). These are the sizes on a computer; a small screen shows them a little smaller, see S.SizeScale.
S.Size = {Text = 53, Icon = 48, Box = {360, 86}, IconBox = 58, Gap = 5, IconTilt = 14, TextTilt = 3}

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
-- R154 (owner: "fix the glitchyness they have in them"; the screenshot had a popup half faded in mid-air): the stream is 10 a second and a popup lives 0.65 s, so 6 to 7 are alive at
-- once. The caps of 6 (phones) and 4 (FastMode / a slow frame rate, which includes Studio after a few slow seconds) were BELOW that, so at those tiers every popup was cut short
-- at about 0.4 s and faded out in 0.08 s while still flying and opaque (measured: 55 of 60 popups at tier 1). Own popups now hold 8 at every tier (the stream's 7 plus one: the cap is
-- a burst guard, no longer a limit on the normal stream); other players keep their lower caps (their popups are 5 a second, not split).
S.Caps = {[3] = {Own = 8, Others = 3}, [2] = {Own = 8, Others = 2}, [1] = {Own = 8, Others = 1}}
S.ReducedCaps = {Own = 4, Others = 1}
S.MaxDistance = 100
-- Cadence: the video spawns one popup every 0.10 s, the server awards one tick every 1/5 s (Config.TrainingInterval; 1/6 s before the R151 treadmill
-- polish). SplitTo = how many popups ONE tick of the local player's own award is shown as (equal shares, the sum kept exactly, never below 1 point each):
-- 2 = 10 a second, exactly the clip's 10 (12 a second at the old 1/6 s tick). Other players'
-- popups and Reduced Motion are never split (their caps are lower; fewer popups is calmer). nil or 1 = off. MaxShares bounds one award event
-- (a lag burst of up to 10 ticks).
S.Cadence = {SplitTo = 2, MaxShares = 12, MaxTicks = 10, MinInterval = 0.1, MaxInterval = 1, MaxPending = 36}
-- The pooled field: one BillboardGui per player that has popups (fixed pixel size, centred on the head, room for the whole fan at the largest Unit).
-- Spare = frames kept beyond the cap (a retired popup still fades out for RetireFade s while its replacement is already there). FreeFields = how many idle
-- fields are kept for the next player or the next run (more are destroyed).
-- R153: Width / Height hold the biggest fan (S.FanScale) at the biggest Unit and the pop's 7% overshoot (was 560 x 420 for the 1x popups).
-- R154: 0.8 of R153's 960 x 760 (the popups and the fan are 0.8 of it); MaxFrames bounds the pool's growth in a burst (a lag spike delivers several awards at once): a frame that is
-- still showing is never reused for a new popup, the pool gets one more frame instead (never more than MaxFrames; then that popup is not shown).
-- R155: Width / Height x Zoom.MaxScale (1.3): 768 x 608 -> 1000 x 792, the room for the biggest fan when the camera is close and the field is scaled up to its cap.
-- R158: x 1.5 with the popups and the fan: 1500 x 1188 (the biggest fan, at 4K, with the pop's overshoot and the 1.3 cap, is 1400 x 1038).
S.Field = {Name = 'SpeedGainField', Width = 1500, Height = 1188, Spare = 2, FreeFields = 4, MaxFrames = 24}
-- R153: the fan's size on THIS screen. The popups fly out of the head in a fan of design px; at 2x text the fan that kept R151's look (x2 on both axes) reaches 324 px to each side of the head and 248 px
-- above it (design px), more than a phone has: a landscape phone (844 x 390) has no room above the head, a portrait phone (390 x 844) none at the sides. FanScale(w, h) returns
-- X, Y: the multipliers of a popup's x / y offset (the client applies them with the Unit). Base = 2 (the same fan, 2x, so the popups pile up exactly as much as in R151: about
-- 46% of a popup under others). A direction that lacks room (the head is assumed HeadY of the way down the screen, Margin px to keep clear of the edge, popups HalfWidth /
-- HalfHeight wide / tall at the widest "+999.5K") gets what fits (never below Min), and the other direction takes the room back (up to Max) so the fan keeps its area.
-- A portrait phone keeps the top PortraitTop px clear too: HudLayout puts the status box up there (down to y 67; the three balances under it reach y 209 at the right).
-- R154: the popups are 0.8 of R153's, and so is the fan (Base 1.6 = 0.8 x 2, Max 2.4, Min 0.6, the half popup 89 x 24): the same arrangement and pile-up as R151 / R153, 20% smaller.
-- R158: the popups are 1.5x R154's and so is the fan (Base 2.4, Max 3.6, Min 0.9, the half popup 134 x 36): the same arrangement and pile-up as R151 / R154 (46% of a popup under others), 1.5x bigger.
-- A phone has not got the room for a fan that size (a landscape phone has 140 px above the head, a portrait phone's HUD stack takes the top), so SizeScale makes the popups smaller on a small screen:
-- the biggest share of S.Size, never below MinSize = 2/3 (= R154's size), at which the fan still keeps Keep = 85% of its area. 1 on every computer and tablet screen (800 x 600 and up), 0.97 at 932 x 430,
-- 0.87 at 844 x 390, 0.76 at 390 x 844, and the 2/3 floor (today's size) on the narrow ones (375 x 667, 360 x 740, 320 x 568, 568 x 320): docs/proposals/R158/tests/test_popups158.luau.
S.Fan = {Base = 2.4, Max = 3.6, Min = 0.9, HeadY = 0.36, Margin = 12, PortraitTop = 72, HalfWidth = 134, HalfHeight = 36, Keep = 0.85, MinSize = 2 / 3}
-- R155 (owner: "make the speed popups consistent in size so when zooming out they don't become bigger they stay consistent in their size when zooming out at a certain point it can
-- disappear it's ok"): the popups were pixel-sized, the same on screen at every camera distance, so zooming out shrank the runner but not the numbers. Now the whole popup field is an object in
-- the world: its on-screen size follows the camera's distance to it (the head) like the runner's. Scale = Distance / camera distance, so
--   Distance   = 12.5 studs: Roblox's default camera zoom (nothing in the game sets it: StarterPlayer's CameraMin / MaxZoomDistance are 0.5 / 128, GiantVisualSafety caps it at 100). At this
--                distance the popups are exactly their S.Size sizes (R154: 35 px text at 1080 p; R158: 53); twice as far (25 studs) = half the size; four times (50) = a quarter.
--   MaxScale   = 1.3: closer than 12.5 / 1.3 = 9.6 studs the popups stop growing (1.3x: 69 px text at 1080 p, R154: 45), so a close-up or first person never shows a giant popup.
--   FadeScale / HideScale = 0.4 / 12 / 35: the scale where the popups start to fade (12.5 / 0.4 = 31.25 studs) and where they are gone (12.5 x 35 / 12 = 36.46 studs); the fade is linear in the scale.
--                R155 wrote them as the text size at 1080 p (14 / 12 px of 35). R158 (the text is 53 px) keeps the same DISTANCES: as 14 / 12 px they would have moved out to 47 / 55 studs.
--   Epsilon    = 0.004: the field's scale is written only when it changed by more than this (0.2 px of a 53 px text).
S.Zoom = {Distance = 12.5, MaxScale = 1.3, FadeScale = 0.4, HideScale = 12 / 35, Epsilon = 0.004}

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

-- The fan's X / Y multipliers for a w x h screen when the popups are `size` times S.Size (see S.Fan). `size` is folded into the unit: the room is measured in the popup's own design px.
local function fanAt(w, h, size)
	local f = S.Fan
	local u = S.Unit(h) * size
	local reach = S.Fling.Radius[2]
	local roomX = (w / 2 - f.Margin) / u - f.HalfWidth                      -- design px from the head to the side edge, less the half popup
	local top = (h > w and w <= 500) and f.PortraitTop or f.Margin
	local roomY = (h * f.HeadY - top) / u - f.HalfHeight                    -- ... to the top edge (or to the HUD stack of a portrait phone)
	local fitX = roomX / (S.Spawn.Jitter + math.sin(math.rad(S.Fling.HalfAngle)) * reach)
	local fitY = roomY / (S.Spawn.Lift + reach)
	local x, y = math.min(fitX, f.Base), math.min(fitY, f.Base)
	local area = f.Base * f.Base
	if x < f.Base then y = math.min(fitY, f.Max, area / math.max(x, f.Min)) end
	if y < f.Base then x = math.min(fitX, f.Max, area / math.max(y, f.Min)) end
	return clamp(x, f.Min, f.Max), clamp(y, f.Min, f.Max)
end

-- R158: the popups' size on this screen as a share of S.Size: 1 wherever the fan fits (a computer, a big phone), else the biggest share (never below Fan.MinSize, today's phone size)
-- at which the fan still keeps Fan.Keep of its area (the pile-up and the HUD rows are what a squeezed fan costs). Bisection over the pure fan; numbers only, nothing allocated.
function S.SizeScale(viewportWidth, viewportHeight)
	local f = S.Fan
	local h = num(viewportHeight, 1080)
	local w = num(viewportWidth, h * 16 / 9)
	local want = f.Keep * f.Base * f.Base
	local x, y = fanAt(w, h, 1)
	if x * y >= want then return 1 end
	local lo, hi = f.MinSize, 1
	for _ = 1, 12 do
		local mid = (lo + hi) / 2
		x, y = fanAt(w, h, mid)
		if x * y >= want then lo = mid else hi = mid end
	end
	return lo
end

-- The fan's X / Y multipliers for a viewport (see S.Fan). Unknown sizes read as a 16:9 desktop screen: Base, Base.
function S.FanScale(viewportWidth, viewportHeight)
	local h = num(viewportHeight, 1080)
	local w = num(viewportWidth, h * 16 / 9)
	return fanAt(w, h, S.SizeScale(w, h))
end

-- What the client needs for one popup on a w x h screen: the unit (px per design px of this popup: S.Unit x S.SizeScale) and the fan's X, Y.
function S.Layout(viewportWidth, viewportHeight)
	local h = num(viewportHeight, 1080)
	local w = num(viewportWidth, h * 16 / 9)
	local size = S.SizeScale(w, h)
	local x, y = fanAt(w, h, size)
	return S.Unit(h) * size, x, y
end

-- R155: how the field is scaled for a camera `distance` studs from the head, and how clear it is. Returns scale (1 at S.Zoom.Distance, Distance / distance beyond, never above
-- S.Zoom.MaxScale) and fade (1 opaque .. 0 gone: linear in the scale from FadeScale down to HideScale; 0 means hidden). Pure and allocation-free.
function S.ZoomScale(distance)
	local z = S.Zoom
	local scale = math.min(z.Distance / math.max(num(distance, z.Distance), 0.05), z.MaxScale)
	local hide, from = z.HideScale, z.FadeScale
	return scale, clamp((scale - hide) / (from - hide), 0, 1)
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
	interval = clamp(num(interval, 1 / 5), c.MinInterval, c.MaxInterval) -- (a missing interval: Config.TrainingInterval's 1/5 s)
	return math.min(interval / math.max(1, num(split, 1)), 1 / math.max(1, num(shares, 1)))
end

return S
