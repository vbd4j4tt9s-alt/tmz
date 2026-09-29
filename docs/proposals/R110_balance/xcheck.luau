local O = loadstring(SRC_ODDS)()
local V = loadstring(SRC_VEC)()
local worst, n = 0, 0
for _, v in ipairs(V) do
	local present = {}; for _, t in ipairs(v.present) do present[t] = true end
	local got = O.TierOdds(present, v.biomeFloor, v.pack, v.luck)
	for t, e in pairs(v.expect) do local d = math.abs((got[t] or 0) - e) / math.max(e, 1e-300); if d > worst then worst = d end; n += 1 end
	for t, g in pairs(got) do assert(v.expect[t] ~= nil or g == 0, 'extra tier '..t) end
end
print(string.format('Luau vs Python: %d tier probabilities compared, worst relative difference %.2e', n, worst))
-- staged Bernoulli: p = 3e-5 with gate 0.1 (5 stages), 2e7 trials -> expect 600 hits
math.randomseed(7)
local hits = 0
for _ = 1, 2e7 do if O.Chance(3e-5, math.random, 0.1) then hits += 1 end end
print(string.format('Staged chance p=3e-5 via gate 0.1: %d hits in 2e7 (expected 600, sd ~24.5)', hits))
-- RollTier distribution on a real table (Storm, Mythic pack, Electric)
local present = {Rare=true, Legendary=true, Mythic=true, Secret=true, Cosmic=true, Eternal=true}
local odds = O.TierOdds(present, 'Rare', 'Pack06', 500)
local count, N = {}, 2e6
for _ = 1, N do local t = O.RollTier(odds, math.random); count[t] = (count[t] or 0) + 1 end
for _, t in ipairs(O.Order) do if odds[t] then
	print(string.format('  %-9s expected %.6f  observed %.6f', t, odds[t], (count[t] or 0) / N))
end end
