-- R151 speed popups: sanity checks of the prototype SpeedPopupStyle against the numbers measured from the reference clip.
-- Usage (from this folder): /opt/luau/luau check_curves.luau
local Style = require('./SpeedPopupStyle')
local passed, failed = 0, 0
local function check(name, ok, detail)
	if ok then passed += 1 else failed += 1 print('FAIL: ' .. name .. (detail and (' (' .. tostring(detail) .. ')') or '')) end
end
local function near(a, b, tol) return math.abs(a - b) <= tol end
local function lcg(seed) local s = seed return function() s = (s * 1664525 + 1013904223) % 4294967296 return s / 4294967296 end end

-- pop: starts at 45%, peaks 1.05..1.10 between 0.12 and 0.20 s, is exactly 1 from 0.28 s on
local plan = {Angle = 0, Radius = 100, StartX = 0, StartY = -5, ReducedX = 14, IconTilt = 0, TextTilt = 0}
local _, _, s0, a0 = Style.Pose(plan, 0, false)
check('pop starts at 0.45', near(s0, 0.45, 1e-9), s0)
check('opaque at birth', a0 == 1)
local peak, peakAt = 0, 0
for i = 0, 280 do
	local _, _, s = Style.Pose(plan, i / 1000, false)
	if s > peak then peak, peakAt = s, i / 1000 end
end
check('overshoot 5..10%', peak > 1.05 and peak < 1.10, peak)
check('peak between 0.12 and 0.20 s', peakAt >= 0.12 and peakAt <= 0.20, peakAt)
local _, _, sEnd = Style.Pose(plan, 0.28, false)
check('scale is 1 once the pop is over', near(sEnd, 1, 1e-9), sEnd)
for _, t in ipairs({0.3, 0.45, 0.6}) do
	local _, _, s = Style.Pose(plan, t, false)
	check('scale stays 1 at ' .. t, near(s, 1, 1e-9), s)
end
-- samples measured in the clip (icon width / full width, mean of three popups): 0.50 0.71 0.91 1.02 1.06 1.06 1.02 at ~0.017 + 0.033 k s
local measured = {0.50, 0.71, 0.91, 1.02, 1.06, 1.06, 1.02}
local worst = 0
for k = 0, 6 do
	local _, _, s = Style.Pose(plan, 0.017 + 0.0333 * k, false)
	worst = math.max(worst, math.abs(s - measured[k + 1]))
end
check('pop within 0.12 of the measured sizes (the first frames are +-0.1 by the unknown frame phase)', worst < 0.12, worst)

-- fling: straight up here; cubic ease-out over 0.40 s
local function rise(t) local _, y = Style.Pose(plan, t, false) return -(y - plan.StartY) end
check('no travel at birth', near(rise(0), 0, 1e-9))
check('half way at 0.082 s', near(rise(0.082) / 100, 0.5, 0.01), rise(0.082))
check('90% at 0.214 s', near(rise(0.214) / 100, 0.9, 0.01), rise(0.214))
check('arrives at 0.40 s and then stays', near(rise(0.40), 100, 1e-6) and near(rise(0.64), 100, 1e-6))
local vmax = rise(0.001) / 0.001
check('initial speed 3 x radius / 0.4 s', near(vmax, 750, 12), vmax)

-- fade: opaque to 0.50 s, linear to 0 at 0.65 s, gone at 0.65 s
local function alphaAt(t) local _, _, _, a, alive = Style.Pose(plan, t, false) return a, alive end
check('opaque at 0.5 s', alphaAt(0.5) == 1)
check('half clear at 0.575 s', near(alphaAt(0.575), 0.5, 1e-9), alphaAt(0.575))
local aEnd, aliveEnd = alphaAt(0.65)
check('clear and dead at 0.65 s', aEnd == 0 and aliveEnd == false)
check('alive at 0.64 s', select(2, alphaAt(0.64)) == true)
check('life = 0.65', near(Style.Life, 0.65, 1e-9))

-- retire: a popup retired at 0.2 s is clear 0.08 s later
local _, _, _, aRet = Style.Pose(plan, 0.24, false, 0.2)
check('retired popup fades in 0.08 s', near(aRet, 0.5, 1e-9), aRet)
local _, _, _, aRet2, aliveRet = Style.Pose(plan, 0.28, false, 0.2)
check('retired popup gone after 0.08 s', aRet2 == 0 and aliveRet == false)

-- plans: shuffled fan, every bag of 7 uses each slot once, angles inside the fan, radii inside the range, never the same slot twice in a row
local rng, bag = lcg(5), {}
local seen, lastSlot, repeats = {}, nil, 0
local width = 2 * Style.Fling.HalfAngle / Style.Fling.Slots
local okRange, minR, maxR, sumAngle = true, 1e9, 0, 0
for n = 1, 700 do
	local p = Style.Plan(rng, bag)
	local degrees = math.deg(p.Angle)
	if math.abs(degrees) > Style.Fling.HalfAngle + 1e-9 then okRange = false end
	minR, maxR = math.min(minR, p.Radius), math.max(maxR, p.Radius)
	sumAngle += degrees
	local slot = bag.Last
	if slot == lastSlot then repeats += 1 end
	lastSlot = slot
	seen[slot] = (seen[slot] or 0) + 1
end
check('angles inside the fan', okRange)
check('radii inside 44..104', minR >= Style.Fling.Radius[1] - 1e-9 and maxR <= Style.Fling.Radius[2] + 1e-9, minR .. '..' .. maxR)
check('every slot used equally (700 plans / 7 slots = 100)', seen[1] == 100 and seen[4] == 100 and seen[7] == 100, seen[1])
check('never the same slot twice in a row', repeats == 0, repeats)
check('fan is centred (mean angle within 3 degrees of 0)', math.abs(sumAngle / 700) < 3, sumAngle / 700)

-- Reduced Motion: no fling, no pop, rises 72 px in 0.7 s, alternates sides, gone at 0.7 s
local rx0, ry0, rs0, ra0 = Style.Pose(plan, 0, true)
check('reduced: starts clear, full size', ra0 == 0 and rs0 == 1)
local rx, ry, rs, ra = Style.Pose(plan, 0.3, true)
check('reduced: opaque and on its side at 0.3 s', ra == 1 and rx == 14 and rs == 1)
local _, ryEnd = Style.Pose(plan, 0.7, true)
check('reduced: rise 72 px', near(plan.StartY - ryEnd, 72, 1e-9), plan.StartY - ryEnd)
check('reduced: gone at 0.7 s', select(5, Style.Pose(plan, 0.7, true)) == false)
local bag2 = {}
local p1, p2 = Style.Plan(lcg(1), bag2), Style.Plan(lcg(2), bag2)
check('reduced: sides alternate', p1.ReducedX == -p2.ReducedX and p1.ReducedX ~= 0)

-- caps per tier, own / others, reduced
check('caps desktop', Style.Cap(3, true, false) == 8 and Style.Cap(3, false, false) == 3)
check('caps phone', Style.Cap(2, true, false) == 6 and Style.Cap(2, false, false) == 2)
check('caps low / FastMode', Style.Cap(1, true, false) == 4 and Style.Cap(1, false, false) == 1)
check('caps out of range tiers clamp', Style.Cap(9, true, false) == 8 and Style.Cap(-4, true, false) == 4 and Style.Cap(nil, true, false) == 4)
check('caps reduced', Style.Cap(3, true, true) == 4 and Style.Cap(3, false, true) == 1)
check('phones never get more than desktop', Style.Cap(2, true, false) <= Style.Cap(3, true, false) and Style.Cap(1, false, false) <= Style.Cap(2, false, false))

-- unit and splitting
check('unit 1 at 1080', Style.Unit(1080) == 1)
check('unit clamps (phone .8, 4k 1.35)', Style.Unit(390) == 0.8 and Style.Unit(2160) == 1.35 and Style.Unit(nil) == 1)
for _, amount in ipairs({1, 2, 3, 99, 4200, 123457}) do
	for shares = 1, 5 do
		local parts = Style.Split(amount, shares)
		local sum = 0
		for _, v in ipairs(parts) do sum += v end
		check('split keeps the sum ' .. amount .. '/' .. shares, sum == amount and #parts == math.min(shares, amount))
	end
end
Style.Cadence.SplitTo = nil
check('no split by default', Style.Shares(4200, 1 / 6) == 1)
Style.Cadence.SplitTo = 10
check('split to 10 a second -> 2 shares per 1/6 s tick', Style.Shares(4200, 1 / 6) == 2 and Style.Shares(1, 1 / 6) == 1)
Style.Cadence.SplitTo = nil

-- our colours and font are untouched: the text colour of SpeedGainPopup.client.lua today
check('text colour as today (125,248,255)', Style.Colors.Text[1] == 125 and Style.Colors.Text[2] == 248 and Style.Colors.Text[3] == 255)
check('icon colour as today (255,222,66)', Style.Colors.Icon[1] == 255 and Style.Colors.Icon[2] == 222 and Style.Colors.Icon[3] == 66)
check('font as today', Style.Font == 'FredokaOne')

print(string.format('check_curves: %d passed, %d failed', passed, failed))
if failed > 0 then error('check_curves failed') end
