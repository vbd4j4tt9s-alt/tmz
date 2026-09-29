--!nonstrict
-- DRAFT ONLY (not installed, not a game file). Reference implementation of the R110 proposal so the
-- Python numbers in the proposal can be cross-checked in Luau. Pure functions, no Roblox APIs.
local O = {}
O.Order = {'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King','Divine','Eternal'}
O.Rank = {}; for i, t in ipairs(O.Order) do O.Rank[t] = i end
O.PackFloor = {Pack01='Common',Pack02='Common',Pack03='Uncommon',Pack04='Rare',Pack05='Rare',Pack06='Legendary'}
O.TopOneIn = {Secret=1e4, Cosmic=1e6, King=1e8, Divine=1e12, Eternal=1e15}
O.PackTopLuck = {Pack01=1, Pack02=2.5, Pack03=6, Pack04=20, Pack05=60, Pack06=200}
O.MidOneIn = {
	Pack01={Uncommon=4, Rare=8, Legendary=30, Mythic=200},
	Pack02={Uncommon=3, Rare=5, Legendary=15, Mythic=80},
	Pack03={Rare=2.5, Legendary=7, Mythic=30},
	Pack04={Legendary=3, Mythic=10},
	Pack05={Legendary=2.5, Mythic=4},
	Pack06={Mythic=2.5},
}
O.Power = {Uncommon=0, Rare=0, Legendary=.2, Mythic=.4, Secret=.7, Cosmic=1, King=1, Divine=1, Eternal=1}
O.Cap = {Uncommon=1, Rare=1, Legendary=.5, Mythic=.45, Secret=.25, Cosmic=.05, King=.01, Divine=.001, Eternal=.001}
O.FloorKeep, O.GivebackKeep, O.MaxLuck = .4, .5, 500

local function oneIn(pack: string, tier: string): number?
	local mid = O.MidOneIn[pack][tier]
	if mid then return mid end
	local top = O.TopOneIn[tier]
	return top and top / O.PackTopLuck[pack] or nil
end

-- present: set of tiers that have at least one seed in this biome. Returns {tier = probability}.
function O.TierOdds(present: {[string]: boolean}, biomeFloor: string, pack: string, luck: number): {[string]: number}
	luck = (type(luck) == 'number' and luck == luck) and math.clamp(luck, 1, O.MaxLuck) or 1
	local floorRank = math.max(O.Rank[O.PackFloor[pack]], O.Rank[biomeFloor])
	local floor
	for i = floorRank, #O.Order do if present[O.Order[i]] then floor = O.Order[i]; break end end
	assert(floor, 'no tier at or above the floor')
	local out: {[string]: number} = {}
	for i = O.Rank[floor] + 1, #O.Order do
		local t = O.Order[i]
		local base = 1 / (oneIn(pack, t) :: number)
		local p = math.min(math.max(base, O.Cap[t]), base * luck ^ O.Power[t])
		if present[t] then
			out[t] = (out[t] or 0) + p
		elseif i <= O.Rank.Mythic then
			for j = i + 1, O.Rank.Mythic do
				if present[O.Order[j]] then out[O.Order[j]] = (out[O.Order[j]] or 0) + p; break end
			end
		end
	end
	if luck > 1 then
		local base = O.TierOdds(present, biomeFloor, pack, 1)
		local total = 0; for _, v in pairs(out) do total += v end
		local need = total - (1 - O.FloorKeep * base[floor])
		for _, t in ipairs(O.Order) do
			if need <= 0 then break end
			local pw = O.Power[t]
			if out[t] and pw and pw > 0 and pw < 1 then
				local give = math.min(need, out[t] - O.GivebackKeep * (base[t] or 0))
				out[t] -= give; need -= give
			end
		end
	end
	local total = 0; for _, v in pairs(out) do total += v end
	out[floor] = (out[floor] or 0) + 1 - total
	return out
end

-- Exact Bernoulli(p) for tiny p even if one random draw has only ~32 bits: split p into gates.
function O.Chance(p: number, draw: () -> number, gate: number?): boolean
	local g = gate or 1e-5
	while p < g do
		if draw() >= g then return false end
		p /= g
	end
	return draw() < p
end

-- Rarest tier first, each tested with its conditional probability, so the result follows `odds` exactly.
function O.RollTier(odds: {[string]: number}, draw: () -> number, gate: number?): string
	local remaining = 1
	local lowest
	for i = #O.Order, 1, -1 do
		local t = O.Order[i]
		local p = odds[t]
		if p and p > 0 then
			lowest = t
			if remaining <= p or O.Chance(p / remaining, draw, gate) then return t end
			remaining -= p
		end
	end
	return lowest :: string
end
return O
