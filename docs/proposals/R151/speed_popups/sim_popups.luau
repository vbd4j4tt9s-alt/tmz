-- R151 speed popups preview: runs 1.5 s of a player on a treadmill through two motion models and prints every popup of every 1/30 s frame as a
-- "FRAME <model> <index> <json>" line for render_preview.mjs.
--   now      = the popups of src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua as they are today (constants copied from it: lifetime
--              1.35 s = Config.TreadmillPopupLifetime, Quad-out rise of 3.0..3.76 studs inside a +-14 degree cone, fade from 0.35 s (text Quad-in,
--              outline Quad-out), at most 4 per player: the 5th spawn destroys the oldest on the spot).
--   new6     = SpeedPopupStyle (the proposal): one popup per award, 6 a second (Config.TrainingInterval = 1/6).
--   new12    = the proposal with Cadence.SplitTo = 10: each award is shown as 2 popups of equal share (12 a second).
--   reduced  = the proposal with Reduced Motion on.
-- The screen is a 1080 p one: "px" below are 1080 p pixels, the camera shows the head 44 px wide (as in the reference clip, 55 px of 1344), i.e.
-- 36.8 px per stud (a 1.2 stud head); offsets are from the head centre, y down.
-- Usage: run_speed_popups_preview.sh copies this file next to src/ReplicatedStorage/SpeedPopupStyle.lua and runs  /opt/luau/luau sim_popups.luau > frames.log
local Style = require('./SpeedPopupStyle')

local PX_PER_STUD = 44.2 / 1.2
local HEAD_UP = 1.5                 -- head centre above the HumanoidRootPart, studs (R6; the script starts popups 1.25 studs above the head)
local FPS, SECONDS = 30, 1.5
local TICK = 1 / 6                  -- Config.TrainingInterval
local AWARD = 4200

local function lcg(seed)
	local s = seed
	return function()
		s = (s * 1664525 + 1013904223) % 4294967296
		return s / 4294967296
	end
end

local function formatGain(amount)
	for _, unit in ipairs({{1e12, 'T'}, {1e9, 'B'}, {1e6, 'M'}, {1e3, 'K'}}) do
		if amount >= unit[1] then return (string.format('%.1f', amount / unit[1]):gsub('%.0$', '')) .. unit[2] end
	end
	return string.format('%.0f', amount)
end

local function easeOut(u, p) u = math.clamp(u, 0, 1) return 1 - (1 - u) ^ p end

-- the spawn schedule: {time, amount} (the very functions the game uses: SplitFor / Shares / Split / Spacing of src/ReplicatedStorage/SpeedPopupStyle.lua;
-- the local player at full motion is split SplitTo = 2 ways, the first model of the preview ("6 a second") is the unsplit one)
local function ticks(split)
	local list = {}
	local k = 1
	local parts = split and Style.SplitFor(true, false) or 1
	while k * TICK < SECONDS do
		local at = k * TICK
		local shares = Style.Split(AWARD, Style.Shares(AWARD, 1, parts))
		local spacing = Style.Spacing(TICK, parts, #shares)
		for j, v in ipairs(shares) do list[#list + 1] = {at + (j - 1) * spacing, v} end
		k += 1
	end
	return list
end

local CONE = {-14, 14, -7, 7, 0, -11, 11, -4, 4, 0}
local function nowModel()
	local rng = lcg(7)
	local pops, seq = {}, 0
	local list = ticks(false)
	local frames = {}
	local nextSpawn = 1
	for f = 0, FPS * SECONDS do
		local t = f / FPS
		while list[nextSpawn] and list[nextSpawn][1] <= t + 1e-9 do
			seq += 1
			local deg = math.clamp(CONE[(seq - 1) % #CONE + 1] + (rng() * 1.4 - 0.7), -15, 15)
			local startH = (rng() * 0.16 - 0.08)
			local startV = math.max(2, HEAD_UP + 1.25)
			local dist = 3.0 + ((seq - 1) % 3) * 0.38 + (rng() * 0.24 - 0.12)
			-- the oldest goes when a 5th would exist
			local alive = 0
			for _, p in ipairs(pops) do if not p.Dead then alive += 1 end end
			if alive >= 4 then
				for _, p in ipairs(pops) do if not p.Dead then p.Dead = true p.DiedAt = list[nextSpawn][1] break end end
			end
			pops[#pops + 1] = {At = list[nextSpawn][1], Amount = list[nextSpawn][2], Deg = math.rad(deg), StartH = startH, StartV = startV, Dist = dist,
				IconTilt = (rng() * 28 - 14), TextTilt = (rng() * 6 - 3)}
			nextSpawn += 1
		end
		local out = {}
		for _, p in ipairs(pops) do
			local age = t - p.At
			local deadAt = p.DiedAt
			if age >= 0 and age < 1.35 and not (deadAt and t >= deadAt - 1e-9) then
				local q = easeOut(age / 1.35, 2)
				local x = (p.StartH + math.sin(p.Deg) * p.Dist * q) * PX_PER_STUD
				local y = -((p.StartV - HEAD_UP) + math.cos(p.Deg) * p.Dist * q) * PX_PER_STUD
				local u2 = math.clamp((age - 0.35) / 1.0, 0, 1)
				out[#out + 1] = {x = x, y = y, s = 1, a = 1 - u2 * u2, sa = (1 - u2) ^ 2, ri = p.IconTilt, rt = p.TextTilt, txt = '+' .. formatGain(p.Amount),
					age = age}
			end
		end
		frames[#frames + 1] = out
	end
	return frames
end

local function newModel(split, reduced)
	local rng = lcg(11)
	local bag = {}
	local cap = Style.Cap(3, true, reduced)
	local pops = {}
	local list = ticks(split)
	local frames = {}
	local nextSpawn = 1
	for f = 0, FPS * SECONDS do
		local t = f / FPS
		while list[nextSpawn] and list[nextSpawn][1] <= t + 1e-9 do
			local alive = {}
			for _, p in ipairs(pops) do
				local _, _, _, _, ok = Style.Pose(p.Plan, t - p.At, reduced, p.Retired and (p.Retired - p.At))
				if ok then alive[#alive + 1] = p end
			end
			-- over the cap: the oldest still-fading-in-place one that is not yet retired is retired (fades out in RetireFade s)
			local live = 0
			for _, p in ipairs(alive) do if not p.Retired then live += 1 end end
			if live >= cap then
				for _, p in ipairs(alive) do if not p.Retired then p.Retired = list[nextSpawn][1] break end end
			end
			pops[#pops + 1] = {At = list[nextSpawn][1], Amount = list[nextSpawn][2], Plan = Style.Plan(rng, bag)}
			nextSpawn += 1
		end
		local out = {}
		for _, p in ipairs(pops) do
			local age = t - p.At
			local x, y, s, a, ok = Style.Pose(p.Plan, age, reduced, p.Retired and (p.Retired - p.At))
			if age >= 0 and ok then
				out[#out + 1] = {x = x, y = y, s = s, a = a, sa = a, ri = p.Plan.IconTilt, rt = p.Plan.TextTilt, txt = '+' .. formatGain(p.Amount), age = age}
			end
		end
		frames[#frames + 1] = out
	end
	return frames
end

local function json(frame)
	local parts = {}
	for _, p in ipairs(frame) do
		parts[#parts + 1] = string.format('{"x":%.2f,"y":%.2f,"s":%.3f,"a":%.3f,"sa":%.3f,"ri":%.1f,"rt":%.1f,"txt":"%s","age":%.3f}',
			p.x, p.y, p.s, p.a, p.sa, p.ri, p.rt, p.txt, p.age)
	end
	return '[' .. table.concat(parts, ',') .. ']'
end

print(string.format('STYLE {"fling":{"time":%g,"power":%g},"pop":{"from":%g,"time":%g,"back":%g},"fade":{"start":%g,"length":%g},"life":%g}',
	Style.Fling.Time, Style.Fling.Power, Style.Pop.From, Style.Pop.Time, Style.Pop.Back, Style.Fade.Start, Style.Fade.Length, Style.Life))
local models = {now = nowModel(), new6 = newModel(false, false), new12 = newModel(true, false), reduced = newModel(false, true)}
for _, name in ipairs({'now', 'new6', 'new12', 'reduced'}) do
	local maxAlive = 0
	for i, frame in ipairs(models[name]) do
		print(string.format('FRAME %s %d %s', name, i - 1, json(frame)))
		if #frame > maxAlive then maxAlive = #frame end
	end
	print(string.format('STAT %s max_alive=%d', name, maxAlive))
end
