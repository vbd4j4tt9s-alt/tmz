SRC_ODDS=[=[--!strict
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
]=]
SRC_VEC=[=[return {
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=1,expect={Uncommon=0.25,Rare=0.125,Legendary=0.033333333333333333,Mythic=0.0050000000000000001,Common=0.58666666666666667}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=2,expect={Uncommon=0.25,Rare=0.125,Legendary=0.038289945166567835,Mythic=0.0065975395538644711,Common=0.58011251527956764}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=5,expect={Uncommon=0.25,Rare=0.125,Legendary=0.045990988715373826,Mythic=0.0095182696935793929,Common=0.56949074159104685}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=20,expect={Uncommon=0.25,Rare=0.125,Legendary=0.060685473434202671,Mythic=0.016572270086699935,Common=0.54774225647909747}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=100,expect={Uncommon=0.25,Rare=0.125,Legendary=0.083729547716986,Mythic=0.031547867224009665,Common=0.50972258505900436}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=500,expect={Uncommon=0.25,Rare=0.125,Legendary=0.11552414052585774,Mythic=0.060056221699071564,Common=0.44941963777507066}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=1,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.066666666666666666,Mythic=0.012500000000000001,Common=0.38750000000000007}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=2,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.07657989033313567,Mythic=0.01649384888466118,Common=0.37359292744886974}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=5,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.091981977430747652,Mythic=0.023795674233948485,Common=0.35088901500197056}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=20,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.12137094686840534,Mythic=0.04143067521674984,Common=0.30386504458151153}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=100,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.167459095433972,Mythic=0.07886966806002417,Common=0.22033790317267055}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=500,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.16152611241898773,Mythic=0.15014055424767891,Common=0.15500000000000003}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=1,expect={Rare=0.40000000000000002,Legendary=0.14285714285714285,Mythic=0.033333333333333333,Uncommon=0.42380952380952375}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=2,expect={Rare=0.40000000000000002,Legendary=0.16409976499957643,Mythic=0.043983597025763141,Uncommon=0.39191663797466036}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=5,expect={Rare=0.40000000000000002,Legendary=0.19710423735160212,Mythic=0.063455131290529293,Uncommon=0.33944063135786862}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=20,expect={Rare=0.40000000000000002,Legendary=0.26008060043229714,Mythic=0.11048180057799957,Uncommon=0.22943759898970317}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=100,expect={Rare=0.40000000000000002,Legendary=0.22015707564945936,Mythic=0.2103191148267311,Uncommon=0.16952380952380941}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=500,expect={Rare=0.40000000000000002,Legendary=0.071428571428571452,Mythic=0.359047619047619,Uncommon=0.16952380952380952}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=1,expect={Legendary=0.33333333333333331,Mythic=0.10000000000000001,Rare=0.56666666666666665}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=2,expect={Legendary=0.38289945166567835,Mythic=0.13195079107728944,Rare=0.48514975725703224}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=5,expect={Legendary=0.45990988715373826,Mythic=0.19036539387158788,Rare=0.34972471897467383}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=20,expect={Legendary=0.44188793159933459,Mythic=0.33144540173399872,Rare=0.22666666666666668}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=100,expect={Legendary=0.32333333333333336,Mythic=0.45000000000000001,Rare=0.22666666666666657}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=500,expect={Legendary=0.32333333333333336,Mythic=0.45000000000000001,Rare=0.22666666666666657}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=1,expect={Legendary=0.40000000000000002,Mythic=0.25,Rare=0.34999999999999998}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=2,expect={Legendary=0.45947934199881407,Mythic=0.32987697769322355,Rare=0.21064368030796232}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=5,expect={Legendary=0.41000000000000003,Mythic=0.45000000000000001,Rare=0.1399999999999999}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=20,expect={Legendary=0.41000000000000003,Mythic=0.45000000000000001,Rare=0.1399999999999999}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=100,expect={Legendary=0.41000000000000003,Mythic=0.45000000000000001,Rare=0.1399999999999999}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=500,expect={Legendary=0.41000000000000003,Mythic=0.45000000000000001,Rare=0.1399999999999999}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=1,expect={Mythic=0.40000000000000002,Legendary=0.59999999999999998}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=2,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=5,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=20,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=100,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=500,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=1,expect={Uncommon=0.25,Rare=0.125,Legendary=0.033333333333333333,Mythic=0.0050000000000000001,Common=0.58666666666666667}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=2,expect={Uncommon=0.25,Rare=0.125,Legendary=0.038289945166567835,Mythic=0.0065975395538644711,Common=0.58011251527956764}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=5,expect={Uncommon=0.25,Rare=0.125,Legendary=0.045990988715373826,Mythic=0.0095182696935793929,Common=0.56949074159104685}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=20,expect={Uncommon=0.25,Rare=0.125,Legendary=0.060685473434202671,Mythic=0.016572270086699935,Common=0.54774225647909747}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=100,expect={Uncommon=0.25,Rare=0.125,Legendary=0.083729547716986,Mythic=0.031547867224009665,Common=0.50972258505900436}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack01",luck=500,expect={Uncommon=0.25,Rare=0.125,Legendary=0.11552414052585774,Mythic=0.060056221699071564,Common=0.44941963777507066}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=1,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.066666666666666666,Mythic=0.012500000000000001,Common=0.38750000000000007}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=2,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.07657989033313567,Mythic=0.01649384888466118,Common=0.37359292744886974}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=5,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.091981977430747652,Mythic=0.023795674233948485,Common=0.35088901500197056}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=20,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.12137094686840534,Mythic=0.04143067521674984,Common=0.30386504458151153}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=100,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.167459095433972,Mythic=0.07886966806002417,Common=0.22033790317267055}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack02",luck=500,expect={Uncommon=0.33333333333333331,Rare=0.20000000000000001,Legendary=0.16152611241898773,Mythic=0.15014055424767891,Common=0.15500000000000003}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=1,expect={Rare=0.40000000000000002,Legendary=0.14285714285714285,Mythic=0.033333333333333333,Uncommon=0.42380952380952375}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=2,expect={Rare=0.40000000000000002,Legendary=0.16409976499957643,Mythic=0.043983597025763141,Uncommon=0.39191663797466036}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=5,expect={Rare=0.40000000000000002,Legendary=0.19710423735160212,Mythic=0.063455131290529293,Uncommon=0.33944063135786862}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=20,expect={Rare=0.40000000000000002,Legendary=0.26008060043229714,Mythic=0.11048180057799957,Uncommon=0.22943759898970317}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=100,expect={Rare=0.40000000000000002,Legendary=0.22015707564945936,Mythic=0.2103191148267311,Uncommon=0.16952380952380941}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack03",luck=500,expect={Rare=0.40000000000000002,Legendary=0.071428571428571452,Mythic=0.359047619047619,Uncommon=0.16952380952380952}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=1,expect={Legendary=0.33333333333333331,Mythic=0.10000000000000001,Rare=0.56666666666666665}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=2,expect={Legendary=0.38289945166567835,Mythic=0.13195079107728944,Rare=0.48514975725703224}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=5,expect={Legendary=0.45990988715373826,Mythic=0.19036539387158788,Rare=0.34972471897467383}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=20,expect={Legendary=0.44188793159933459,Mythic=0.33144540173399872,Rare=0.22666666666666668}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=100,expect={Legendary=0.32333333333333336,Mythic=0.45000000000000001,Rare=0.22666666666666657}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack04",luck=500,expect={Legendary=0.32333333333333336,Mythic=0.45000000000000001,Rare=0.22666666666666657}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=1,expect={Legendary=0.40000000000000002,Mythic=0.25,Rare=0.34999999999999998}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=2,expect={Legendary=0.45947934199881407,Mythic=0.32987697769322355,Rare=0.21064368030796232}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=5,expect={Legendary=0.41000000000000003,Mythic=0.45000000000000001,Rare=0.1399999999999999}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=20,expect={Legendary=0.41000000000000003,Mythic=0.45000000000000001,Rare=0.1399999999999999}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=100,expect={Legendary=0.41000000000000003,Mythic=0.45000000000000001,Rare=0.1399999999999999}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack05",luck=500,expect={Legendary=0.41000000000000003,Mythic=0.45000000000000001,Rare=0.1399999999999999}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=1,expect={Mythic=0.40000000000000002,Legendary=0.59999999999999998}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=2,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=5,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=20,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=100,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Common","Uncommon","Rare","Legendary","Mythic"},biomeFloor="Common",pack="Pack06",luck=500,expect={Mythic=0.45000000000000001,Legendary=0.55000000000000004}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=1,expect={Mythic=0.16333333333333333,Secret=0.0001,Cosmic=9.9999999999999995e-07,King=1e-08,Uncommon=0.83656565666666671}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=2,expect={Mythic=0.1698874847204323,Secret=0.00016245047927124711,Cosmic=1.9999999999999999e-06,King=2e-08,Uncommon=0.82994804480029649}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=5,expect={Mythic=0.18050925840895321,Secret=0.0003085169313600048,Cosmic=4.9999999999999996e-06,King=4.9999999999999998e-08,Uncommon=0.81917717465968676}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=20,expect={Mythic=0.20225774352090259,Secret=0.00081418106307380874,Cosmic=1.9999999999999998e-05,King=1.9999999999999999e-07,Uncommon=0.79690787541602359}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=100,expect={Mythic=0.24027741494099564,Secret=0.0025118864315095794,Cosmic=9.9999999999999991e-05,King=9.9999999999999995e-07,Uncommon=0.75710969862749478}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=500,expect={Mythic=0.30058036222492929,Secret=0.0077495949377416841,Cosmic=0.00050000000000000001,King=5.0000000000000004e-06,Uncommon=0.69116504283732905}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=1,expect={Mythic=0.27916666666666667,Secret=0.00025000000000000001,Cosmic=2.5000000000000002e-06,King=2.4999999999999999e-08,Uncommon=0.72058080833333338}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=2,expect={Mythic=0.29307373921779684,Secret=0.00040612619817811772,Cosmic=5.0000000000000004e-06,King=4.9999999999999998e-08,Uncommon=0.70651508458402512}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=5,expect={Mythic=0.31577765166469612,Secret=0.00077129232840001196,Cosmic=1.2500000000000001e-05,King=1.2499999999999999e-07,Uncommon=0.68343843100690382}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=20,expect={Mythic=0.36280162208515521,Secret=0.002035452657684522,Cosmic=5.0000000000000002e-05,King=4.9999999999999998e-07,Uncommon=0.63511242525716027}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=100,expect={Mythic=0.44632876349399619,Secret=0.0062797160787739486,Cosmic=0.00025000000000000001,King=2.4999999999999998e-06,Uncommon=0.54713902042722995}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=500,expect={Mythic=0.58118883529939436,Secret=0.019373987344354211,Cosmic=0.00125,King=1.2499999999999999e-05,Uncommon=0.39817467735625145}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=1,expect={Mythic=0.57619047619047625,Secret=0.00059999999999999995,Cosmic=6.0000000000000002e-06,King=6.0000000000000008e-08,Uncommon=0.42320346380952378}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=2,expect={Mythic=0.60808336202533964,Secret=0.00097470287562748245,Cosmic=1.2e-05,King=1.2000000000000002e-07,Uncommon=0.3909298150990328}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=5,expect={Mythic=0.66055936864213138,Secret=0.0018511015881600285,Cosmic=3.0000000000000001e-05,King=3.0000000000000004e-07,Uncommon=0.33755922976970865}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=20,expect={Mythic=0.77056240101029683,Secret=0.004885086378442852,Cosmic=0.00012,King=1.2000000000000002e-06,Uncommon=0.22443131261126026}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=100,expect={Mythic=0.81504129588713292,Secret=0.015071318589057475,Cosmic=0.00060000000000000006,King=6.000000000000001e-06,Uncommon=0.16928138552380956}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=500,expect={Mythic=0.78119104484974056,Secret=0.046497569626450096,Cosmic=0.0030000000000000001,King=3.0000000000000004e-05,Uncommon=0.16928138552380934}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=1,expect={Secret=0.002,Cosmic=2.0000000000000002e-05,King=1.9999999999999999e-07,Mythic=0.99797979999999997}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=2,expect={Secret=0.0032490095854249418,Cosmic=4.0000000000000003e-05,King=3.9999999999999998e-07,Mythic=0.9967105904145751}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=5,expect={Secret=0.0061703386272000957,Cosmic=0.0001,King=9.9999999999999995e-07,Mythic=0.99372866137279992}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=20,expect={Secret=0.016283621261476176,Cosmic=0.00040000000000000002,King=3.9999999999999998e-06,Mythic=0.98331237873852384}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=100,expect={Secret=0.050237728630191589,Cosmic=0.002,King=1.9999999999999998e-05,Mythic=0.94774227136980838}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=500,expect={Secret=0.15499189875483368,Cosmic=0.01,King=9.9999999999999991e-05,Mythic=0.83490810124516635}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=1,expect={Secret=0.0060000000000000001,Cosmic=5.9999999999999995e-05,King=5.9999999999999997e-07,Mythic=0.99393940000000003}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=2,expect={Secret=0.0097470287562748253,Cosmic=0.00011999999999999999,King=1.1999999999999999e-06,Mythic=0.9901317712437252}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=5,expect={Secret=0.018511015881600288,Cosmic=0.00029999999999999997,King=3.0000000000000001e-06,Mythic=0.98118598411839975}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=20,expect={Secret=0.048850863784428523,Cosmic=0.0011999999999999999,King=1.2e-05,Mythic=0.94993713621557152}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=100,expect={Secret=0.15071318589057478,Cosmic=0.0059999999999999993,King=5.9999999999999995e-05,Mythic=0.84322681410942524}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=500,expect={Secret=0.25,Cosmic=0.029999999999999999,King=0.00029999999999999997,Mythic=0.71970000000000001}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=1,expect={Secret=0.02,Cosmic=0.00020000000000000001,King=1.9999999999999999e-06,Mythic=0.97979799999999995}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=2,expect={Secret=0.032490095854249418,Cosmic=0.00040000000000000002,King=3.9999999999999998e-06,Mythic=0.96710590414575059}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=5,expect={Secret=0.061703386272000955,Cosmic=0.001,King=9.9999999999999991e-06,Mythic=0.93728661372799904}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=20,expect={Secret=0.16283621261476175,Cosmic=0.0040000000000000001,King=3.9999999999999996e-05,Mythic=0.83312378738523818}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=100,expect={Secret=0.25,Cosmic=0.02,King=0.00019999999999999998,Mythic=0.7298}},
 {present={"Uncommon","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=500,expect={Secret=0.25,Cosmic=0.050000000000000003,King=0.001,Mythic=0.69900000000000007}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=1,expect={Rare=0.125,Legendary=0.033333333333333333,Mythic=0.0050000000000000001,Secret=0.0001,Cosmic=9.9999999999999995e-07,King=1e-08,Uncommon=0.83656565666666671}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=2,expect={Rare=0.125,Legendary=0.038289945166567835,Mythic=0.0065975395538644711,Secret=0.00016245047927124711,Cosmic=1.9999999999999999e-06,King=2e-08,Uncommon=0.82994804480029649}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=5,expect={Rare=0.125,Legendary=0.045990988715373826,Mythic=0.0095182696935793929,Secret=0.0003085169313600048,Cosmic=4.9999999999999996e-06,King=4.9999999999999998e-08,Uncommon=0.81917717465968676}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=20,expect={Rare=0.125,Legendary=0.060685473434202671,Mythic=0.016572270086699935,Secret=0.00081418106307380874,Cosmic=1.9999999999999998e-05,King=1.9999999999999999e-07,Uncommon=0.79690787541602359}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=100,expect={Rare=0.125,Legendary=0.083729547716986,Mythic=0.031547867224009665,Secret=0.0025118864315095794,Cosmic=9.9999999999999991e-05,King=9.9999999999999995e-07,Uncommon=0.75710969862749478}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack01",luck=500,expect={Rare=0.125,Legendary=0.11552414052585774,Mythic=0.060056221699071564,Secret=0.0077495949377416841,Cosmic=0.00050000000000000001,King=5.0000000000000004e-06,Uncommon=0.69116504283732905}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=1,expect={Rare=0.20000000000000001,Legendary=0.066666666666666666,Mythic=0.012500000000000001,Secret=0.00025000000000000001,Cosmic=2.5000000000000002e-06,King=2.4999999999999999e-08,Uncommon=0.72058080833333338}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=2,expect={Rare=0.20000000000000001,Legendary=0.07657989033313567,Mythic=0.01649384888466118,Secret=0.00040612619817811772,Cosmic=5.0000000000000004e-06,King=4.9999999999999998e-08,Uncommon=0.70651508458402512}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=5,expect={Rare=0.20000000000000001,Legendary=0.091981977430747652,Mythic=0.023795674233948485,Secret=0.00077129232840001196,Cosmic=1.2500000000000001e-05,King=1.2499999999999999e-07,Uncommon=0.68343843100690382}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=20,expect={Rare=0.20000000000000001,Legendary=0.12137094686840534,Mythic=0.04143067521674984,Secret=0.002035452657684522,Cosmic=5.0000000000000002e-05,King=4.9999999999999998e-07,Uncommon=0.63511242525716027}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=100,expect={Rare=0.20000000000000001,Legendary=0.167459095433972,Mythic=0.07886966806002417,Secret=0.0062797160787739486,Cosmic=0.00025000000000000001,King=2.4999999999999998e-06,Uncommon=0.54713902042722995}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack02",luck=500,expect={Rare=0.20000000000000001,Legendary=0.23104828105171549,Mythic=0.15014055424767891,Secret=0.019373987344354211,Cosmic=0.00125,King=1.2499999999999999e-05,Uncommon=0.39817467735625145}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=1,expect={Rare=0.40000000000000002,Legendary=0.14285714285714285,Mythic=0.033333333333333333,Secret=0.00059999999999999995,Cosmic=6.0000000000000002e-06,King=6.0000000000000008e-08,Uncommon=0.42320346380952378}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=2,expect={Rare=0.40000000000000002,Legendary=0.16409976499957643,Mythic=0.043983597025763141,Secret=0.00097470287562748245,Cosmic=1.2e-05,King=1.2000000000000002e-07,Uncommon=0.3909298150990328}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=5,expect={Rare=0.40000000000000002,Legendary=0.19710423735160212,Mythic=0.063455131290529293,Secret=0.0018511015881600285,Cosmic=3.0000000000000001e-05,King=3.0000000000000004e-07,Uncommon=0.33755922976970865}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=20,expect={Rare=0.40000000000000002,Legendary=0.26008060043229714,Mythic=0.11048180057799957,Secret=0.004885086378442852,Cosmic=0.00012,King=1.2000000000000002e-06,Uncommon=0.22443131261126026}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=100,expect={Rare=0.40000000000000002,Legendary=0.2047221810604018,Mythic=0.2103191148267311,Secret=0.015071318589057475,Cosmic=0.00060000000000000006,King=6.000000000000001e-06,Uncommon=0.16928138552380956}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack03",luck=500,expect={Rare=0.40000000000000002,Legendary=0.071428571428571452,Mythic=0.30976247342116908,Secret=0.046497569626450096,Cosmic=0.0030000000000000001,King=3.0000000000000004e-05,Uncommon=0.16928138552380934}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=1,expect={Legendary=0.33333333333333331,Mythic=0.10000000000000001,Secret=0.002,Cosmic=2.0000000000000002e-05,King=1.9999999999999999e-07,Rare=0.56464646666666662}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=2,expect={Legendary=0.38289945166567835,Mythic=0.13195079107728944,Secret=0.0032490095854249418,Cosmic=4.0000000000000003e-05,King=3.9999999999999998e-07,Rare=0.48186034767160724}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=5,expect={Legendary=0.45990988715373826,Mythic=0.19036539387158788,Secret=0.0061703386272000957,Cosmic=0.0001,King=9.9999999999999995e-07,Rare=0.34345338034747375}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=20,expect={Legendary=0.42600839033785842,Mythic=0.33144540173399872,Secret=0.016283621261476176,Cosmic=0.00040000000000000002,King=3.9999999999999998e-06,Rare=0.22585858666666669}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=100,expect={Legendary=0.27188368470314184,Mythic=0.45000000000000001,Secret=0.050237728630191589,Cosmic=0.002,King=1.9999999999999998e-05,Rare=0.22585858666666658}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack04",luck=500,expect={Legendary=0.16666666666666663,Mythic=0.44238284791183297,Secret=0.15499189875483368,Cosmic=0.01,King=9.9999999999999991e-05,Rare=0.22585858666666681}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=1,expect={Legendary=0.40000000000000002,Mythic=0.25,Secret=0.0060000000000000001,Cosmic=5.9999999999999995e-05,King=5.9999999999999997e-07,Rare=0.34393940000000001}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=2,expect={Legendary=0.45947934199881407,Mythic=0.32987697769322355,Secret=0.0097470287562748253,Cosmic=0.00011999999999999999,King=1.1999999999999999e-06,Rare=0.20077545155168741}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=5,expect={Legendary=0.39361022411839974,Mythic=0.45000000000000001,Secret=0.018511015881600288,Cosmic=0.00029999999999999997,King=3.0000000000000001e-06,Rare=0.13757575999999994}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=20,expect={Legendary=0.36236137621557152,Mythic=0.45000000000000001,Secret=0.048850863784428523,Cosmic=0.0011999999999999999,King=1.2e-05,Rare=0.13757576000000005}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=100,expect={Legendary=0.25565105410942524,Mythic=0.45000000000000001,Secret=0.15071318589057478,Cosmic=0.0059999999999999993,King=5.9999999999999995e-05,Rare=0.13757576000000005}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack05",luck=500,expect={Legendary=0.20000000000000001,Mythic=0.38212424,Secret=0.25,Cosmic=0.029999999999999999,King=0.00029999999999999997,Rare=0.13757576000000005}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=1,expect={Mythic=0.40000000000000002,Secret=0.02,Cosmic=0.00020000000000000001,King=1.9999999999999999e-06,Legendary=0.57979800000000004}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=2,expect={Mythic=0.45000000000000001,Secret=0.032490095854249418,Cosmic=0.00040000000000000002,King=3.9999999999999998e-06,Legendary=0.51710590414575064}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=5,expect={Mythic=0.45000000000000001,Secret=0.061703386272000955,Cosmic=0.001,King=9.9999999999999991e-06,Legendary=0.48728661372799909}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=20,expect={Mythic=0.45000000000000001,Secret=0.16283621261476175,Cosmic=0.0040000000000000001,King=3.9999999999999996e-05,Legendary=0.38312378738523822}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=100,expect={Mythic=0.45000000000000001,Secret=0.25,Cosmic=0.02,King=0.00019999999999999998,Legendary=0.27980000000000005}},
 {present={"Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"},biomeFloor="Uncommon",pack="Pack06",luck=500,expect={Mythic=0.45000000000000001,Secret=0.25,Cosmic=0.050000000000000003,King=0.001,Legendary=0.249}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack01",luck=1,expect={Legendary=0.033333333333333333,Secret=0.0001,Cosmic=9.9999999999999995e-07,King=1e-08,Rare=0.96656565666666672}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack01",luck=2,expect={Legendary=0.038289945166567835,Secret=0.00016245047927124711,Cosmic=1.9999999999999999e-06,King=2e-08,Rare=0.96154558435416093}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack01",luck=5,expect={Legendary=0.045990988715373826,Secret=0.0003085169313600048,Cosmic=4.9999999999999996e-06,King=4.9999999999999998e-08,Rare=0.95369544435326614}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack01",luck=20,expect={Legendary=0.060685473434202671,Secret=0.00081418106307380874,Cosmic=1.9999999999999998e-05,King=1.9999999999999999e-07,Rare=0.93848014550272352}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack01",luck=100,expect={Legendary=0.083729547716986,Secret=0.0025118864315095794,Cosmic=9.9999999999999991e-05,King=9.9999999999999995e-07,Rare=0.91365756585150437}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack01",luck=500,expect={Legendary=0.11552414052585774,Secret=0.0077495949377416841,Cosmic=0.00050000000000000001,King=5.0000000000000004e-06,Rare=0.87622126453640059}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack02",luck=1,expect={Legendary=0.066666666666666666,Secret=0.00025000000000000001,Cosmic=2.5000000000000002e-06,King=2.4999999999999999e-08,Rare=0.93308080833333329}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack02",luck=2,expect={Legendary=0.07657989033313567,Secret=0.00040612619817811772,Cosmic=5.0000000000000004e-06,King=4.9999999999999998e-08,Rare=0.92300893346868618}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack02",luck=5,expect={Legendary=0.091981977430747652,Secret=0.00077129232840001196,Cosmic=1.2500000000000001e-05,King=1.2499999999999999e-07,Rare=0.90723410524085235}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack02",luck=20,expect={Legendary=0.12137094686840534,Secret=0.002035452657684522,Cosmic=5.0000000000000002e-05,King=4.9999999999999998e-07,Rare=0.87654310047391015}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack02",luck=100,expect={Legendary=0.167459095433972,Secret=0.0062797160787739486,Cosmic=0.00025000000000000001,King=2.4999999999999998e-06,Rare=0.82600868848725406}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack02",luck=500,expect={Legendary=0.23104828105171549,Secret=0.019373987344354211,Cosmic=0.00125,King=1.2499999999999999e-05,Rare=0.74831523160393032}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack03",luck=1,expect={Legendary=0.14285714285714285,Secret=0.00059999999999999995,Cosmic=6.0000000000000002e-06,King=6.0000000000000008e-08,Rare=0.85653679714285713}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack03",luck=2,expect={Legendary=0.16409976499957643,Secret=0.00097470287562748245,Cosmic=1.2e-05,King=1.2000000000000002e-07,Rare=0.83491341212479608}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack03",luck=5,expect={Legendary=0.19710423735160212,Secret=0.0018511015881600285,Cosmic=3.0000000000000001e-05,King=3.0000000000000004e-07,Rare=0.80101436106023782}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack03",luck=20,expect={Legendary=0.26008060043229714,Secret=0.004885086378442852,Cosmic=0.00012,King=1.2000000000000002e-06,Rare=0.73491311318926}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack03",luck=100,expect={Legendary=0.35884091878708285,Secret=0.015071318589057475,Cosmic=0.00060000000000000006,King=6.000000000000001e-06,Rare=0.62548176262385968}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack03",luck=500,expect={Legendary=0.49510345939653316,Secret=0.046497569626450096,Cosmic=0.0030000000000000001,King=3.0000000000000004e-05,Rare=0.45536897097701678}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack04",luck=1,expect={Legendary=0.33333333333333331,Secret=0.002,Cosmic=2.0000000000000002e-05,King=1.9999999999999999e-07,Rare=0.66464646666666671}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack04",luck=2,expect={Legendary=0.38289945166567835,Secret=0.0032490095854249418,Cosmic=4.0000000000000003e-05,King=3.9999999999999998e-07,Rare=0.6138111387488967}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack04",luck=5,expect={Legendary=0.45990988715373826,Secret=0.0061703386272000957,Cosmic=0.0001,King=9.9999999999999995e-07,Rare=0.53381877421906165}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack04",luck=20,expect={Legendary=0.5,Secret=0.016283621261476176,Cosmic=0.00040000000000000002,King=3.9999999999999998e-06,Rare=0.48331237873852384}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack04",luck=100,expect={Legendary=0.5,Secret=0.050237728630191589,Cosmic=0.002,King=1.9999999999999998e-05,Rare=0.44774227136980838}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack04",luck=500,expect={Legendary=0.5,Secret=0.15499189875483368,Cosmic=0.01,King=9.9999999999999991e-05,Rare=0.33490810124516635}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack05",luck=1,expect={Legendary=0.40000000000000002,Secret=0.0060000000000000001,Cosmic=5.9999999999999995e-05,King=5.9999999999999997e-07,Rare=0.59393940000000001}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack05",luck=2,expect={Legendary=0.45947934199881407,Secret=0.0097470287562748253,Cosmic=0.00011999999999999999,King=1.1999999999999999e-06,Rare=0.53065242924491107}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack05",luck=5,expect={Legendary=0.5,Secret=0.018511015881600288,Cosmic=0.00029999999999999997,King=3.0000000000000001e-06,Rare=0.48118598411839975}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack05",luck=20,expect={Legendary=0.5,Secret=0.048850863784428523,Cosmic=0.0011999999999999999,King=1.2e-05,Rare=0.44993713621557152}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack05",luck=100,expect={Legendary=0.5,Secret=0.15071318589057478,Cosmic=0.0059999999999999993,King=5.9999999999999995e-05,Rare=0.34322681410942524}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack05",luck=500,expect={Legendary=0.48212423999999998,Secret=0.25,Cosmic=0.029999999999999999,King=0.00029999999999999997,Rare=0.23757576000000002}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack06",luck=1,expect={Secret=0.02,Cosmic=0.00020000000000000001,King=1.9999999999999999e-06,Legendary=0.97979799999999995}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack06",luck=2,expect={Secret=0.032490095854249418,Cosmic=0.00040000000000000002,King=3.9999999999999998e-06,Legendary=0.96710590414575059}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack06",luck=5,expect={Secret=0.061703386272000955,Cosmic=0.001,King=9.9999999999999991e-06,Legendary=0.93728661372799904}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack06",luck=20,expect={Secret=0.16283621261476175,Cosmic=0.0040000000000000001,King=3.9999999999999996e-05,Legendary=0.83312378738523818}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack06",luck=100,expect={Secret=0.25,Cosmic=0.02,King=0.00019999999999999998,Legendary=0.7298}},
 {present={"Rare","Legendary","Secret","Cosmic","King"},biomeFloor="Rare",pack="Pack06",luck=500,expect={Secret=0.25,Cosmic=0.050000000000000003,King=0.001,Legendary=0.69900000000000007}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack01",luck=1,expect={Mythic=0.03833333333333333,Secret=0.0001,Cosmic=9.9999999999999995e-07,Divine=9.9999999999999998e-13,Rare=0.96156566666566667}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack01",luck=2,expect={Mythic=0.044887484720432302,Secret=0.00016245047927124711,Cosmic=1.9999999999999999e-06,Divine=2e-12,Rare=0.95494806479829641}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack01",luck=5,expect={Mythic=0.055509258408953217,Secret=0.0003085169313600048,Cosmic=4.9999999999999996e-06,Divine=4.9999999999999997e-12,Rare=0.94417722465468679}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack01",luck=20,expect={Mythic=0.077257743520902603,Secret=0.00081418106307380874,Cosmic=1.9999999999999998e-05,Divine=1.9999999999999999e-11,Rare=0.9219080753960236}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack01",luck=100,expect={Mythic=0.11527741494099566,Secret=0.0025118864315095794,Cosmic=9.9999999999999991e-05,Divine=1e-10,Rare=0.8821106985274948}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack01",luck=500,expect={Mythic=0.17558036222492931,Secret=0.0077495949377416841,Cosmic=0.00050000000000000001,Divine=5.0000000000000003e-10,Rare=0.81617004233732904}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack02",luck=1,expect={Mythic=0.079166666666666663,Secret=0.00025000000000000001,Cosmic=2.5000000000000002e-06,Divine=2.4999999999999998e-12,Rare=0.92058083333083329}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack02",luck=2,expect={Mythic=0.093073739217796853,Secret=0.00040612619817811772,Cosmic=5.0000000000000004e-06,Divine=4.9999999999999997e-12,Rare=0.90651513457902499}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack02",luck=5,expect={Mythic=0.11577765166469614,Secret=0.00077129232840001196,Cosmic=1.2500000000000001e-05,Divine=1.2499999999999999e-11,Rare=0.8834385559944038}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack02",luck=20,expect={Mythic=0.1628016220851552,Secret=0.002035452657684522,Cosmic=5.0000000000000002e-05,Divine=4.9999999999999995e-11,Rare=0.83511292520716029}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack02",luck=100,expect={Mythic=0.24632876349399618,Secret=0.0062797160787739486,Cosmic=0.00025000000000000001,Divine=2.4999999999999996e-10,Rare=0.7471415201772299}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack02",luck=500,expect={Mythic=0.3811888352993944,Secret=0.019373987344354211,Cosmic=0.00125,Divine=1.25e-09,Rare=0.59818717610625138}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack03",luck=1,expect={Mythic=0.17619047619047618,Secret=0.00059999999999999995,Cosmic=6.0000000000000002e-06,Divine=6.0000000000000003e-12,Rare=0.8232035238035238}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack03",luck=2,expect={Mythic=0.20808336202533956,Secret=0.00097470287562748245,Cosmic=1.2e-05,Divine=1.2000000000000001e-11,Rare=0.79092993508703291}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack03",luck=5,expect={Mythic=0.26055936864213142,Secret=0.0018511015881600285,Cosmic=3.0000000000000001e-05,Divine=3e-11,Rare=0.73755952973970862}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack03",luck=20,expect={Mythic=0.37056240101029669,Secret=0.004885086378442852,Cosmic=0.00012,Divine=1.2e-10,Rare=0.62443251249126042}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack03",luck=100,expect={Mythic=0.56916003361381395,Secret=0.015071318589057475,Cosmic=0.00060000000000000006,Divine=6e-10,Rare=0.41516864719712843}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack03",luck=500,expect={Mythic=0.62122101785214023,Secret=0.046497569626450096,Cosmic=0.0030000000000000001,Divine=3e-09,Rare=0.32928140952140961}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack04",luck=1,expect={Mythic=0.43333333333333335,Secret=0.002,Cosmic=2.0000000000000002e-05,Divine=1.9999999999999999e-11,Rare=0.56464666664666663}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack04",luck=2,expect={Mythic=0.51485024274296776,Secret=0.0032490095854249418,Cosmic=4.0000000000000003e-05,Divine=3.9999999999999998e-11,Rare=0.48186074763160724}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack04",luck=5,expect={Mythic=0.65027528102532617,Secret=0.0061703386272000957,Cosmic=0.0001,Divine=9.9999999999999991e-11,Rare=0.34345438024747377}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack04",luck=20,expect={Mythic=0.7574577116798572,Secret=0.016283621261476176,Cosmic=0.00040000000000000002,Divine=3.9999999999999996e-10,Rare=0.22585866665866661}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack04",luck=100,expect={Mythic=0.72190360271114185,Secret=0.050237728630191589,Cosmic=0.002,Divine=1.9999999999999997e-09,Rare=0.2258586666586665}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack04",luck=500,expect={Mythic=0.60914942458649968,Secret=0.15499189875483368,Cosmic=0.01,Divine=1e-08,Rare=0.22585866665866661}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack05",luck=1,expect={Mythic=0.65000000000000002,Secret=0.0060000000000000001,Cosmic=5.9999999999999995e-05,Divine=6e-11,Rare=0.34393999994000002}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack05",luck=2,expect={Mythic=0.78935631969203768,Secret=0.0097470287562748253,Cosmic=0.00011999999999999999,Divine=1.2e-10,Rare=0.20077665143168744}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack05",luck=5,expect={Mythic=0.84361298384239969,Secret=0.018511015881600288,Cosmic=0.00029999999999999997,Divine=3e-10,Rare=0.13757599997600001}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack05",luck=20,expect={Mythic=0.81237313503957131,Secret=0.048850863784428523,Cosmic=0.0011999999999999999,Divine=1.2e-09,Rare=0.13757599997600023}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack05",luck=100,expect={Mythic=0.70571080813342513,Secret=0.15071318589057478,Cosmic=0.0059999999999999993,Divine=6e-09,Rare=0.13757599997600001}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack05",luck=500,expect={Mythic=0.58242397002399993,Secret=0.25,Cosmic=0.029999999999999999,Divine=2.9999999999999997e-08,Rare=0.13757599997600001}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack06",luck=1,expect={Secret=0.02,Cosmic=0.00020000000000000001,Divine=2.0000000000000001e-10,Mythic=0.97979999979999999}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack06",luck=2,expect={Secret=0.032490095854249418,Cosmic=0.00040000000000000002,Divine=4.0000000000000001e-10,Mythic=0.96710990374575057}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack06",luck=5,expect={Secret=0.061703386272000955,Cosmic=0.001,Divine=1.0000000000000001e-09,Mythic=0.93729661272799902}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack06",luck=20,expect={Secret=0.16283621261476175,Cosmic=0.0040000000000000001,Divine=4.0000000000000002e-09,Mythic=0.83316378338523822}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack06",luck=100,expect={Secret=0.25,Cosmic=0.02,Divine=2e-08,Mythic=0.72999997999999999}},
 {present={"Rare","Mythic","Secret","Cosmic","Divine"},biomeFloor="Rare",pack="Pack06",luck=500,expect={Secret=0.25,Cosmic=0.050000000000000003,Divine=1.0000000000000001e-07,Mythic=0.69999990000000001}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack01",luck=1,expect={Legendary=0.033333333333333333,Mythic=0.0050000000000000001,Secret=0.0001,Cosmic=9.9999999999999995e-07,Eternal=1.0000000000000001e-15,Rare=0.96156566666666565}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack01",luck=2,expect={Legendary=0.038289945166567835,Mythic=0.0065975395538644711,Secret=0.00016245047927124711,Cosmic=1.9999999999999999e-06,Eternal=2.0000000000000002e-15,Rare=0.95494806480029448}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack01",luck=5,expect={Legendary=0.045990988715373826,Mythic=0.0095182696935793929,Secret=0.0003085169313600048,Cosmic=4.9999999999999996e-06,Eternal=5.0000000000000008e-15,Rare=0.94417722465968179}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack01",luck=20,expect={Legendary=0.060685473434202671,Mythic=0.016572270086699935,Secret=0.00081418106307380874,Cosmic=1.9999999999999998e-05,Eternal=2.0000000000000003e-14,Rare=0.92190807541600361}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack01",luck=100,expect={Legendary=0.083729547716986,Mythic=0.031547867224009665,Secret=0.0025118864315095794,Cosmic=9.9999999999999991e-05,Eternal=1e-13,Rare=0.88211069862739477}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack01",luck=500,expect={Legendary=0.11552414052585774,Mythic=0.060056221699071564,Secret=0.0077495949377416841,Cosmic=0.00050000000000000001,Eternal=4.9999999999999999e-13,Rare=0.81617004283682903}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack02",luck=1,expect={Legendary=0.066666666666666666,Mythic=0.012500000000000001,Secret=0.00025000000000000001,Cosmic=2.5000000000000002e-06,Eternal=2.5e-15,Rare=0.92058083333333085}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack02",luck=2,expect={Legendary=0.07657989033313567,Mythic=0.01649384888466118,Secret=0.00040612619817811772,Cosmic=5.0000000000000004e-06,Eternal=5e-15,Rare=0.90651513458402}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack02",luck=5,expect={Legendary=0.091981977430747652,Mythic=0.023795674233948485,Secret=0.00077129232840001196,Cosmic=1.2500000000000001e-05,Eternal=1.25e-14,Rare=0.88343855600689136}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack02",luck=20,expect={Legendary=0.12137094686840534,Mythic=0.04143067521674984,Secret=0.002035452657684522,Cosmic=5.0000000000000002e-05,Eternal=5.0000000000000002e-14,Rare=0.83511292525711034}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack02",luck=100,expect={Legendary=0.167459095433972,Mythic=0.07886966806002417,Secret=0.0062797160787739486,Cosmic=0.00025000000000000001,Eternal=2.4999999999999999e-13,Rare=0.7471415204269799}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack02",luck=500,expect={Legendary=0.23104828105171549,Mythic=0.15014055424767891,Secret=0.019373987344354211,Cosmic=0.00125,Eternal=1.2499999999999999e-12,Rare=0.59818717735500138}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack03",luck=1,expect={Legendary=0.14285714285714285,Mythic=0.033333333333333333,Secret=0.00059999999999999995,Cosmic=6.0000000000000002e-06,Eternal=6.0000000000000005e-15,Rare=0.82320352380951789}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack03",luck=2,expect={Legendary=0.16409976499957643,Mythic=0.043983597025763141,Secret=0.00097470287562748245,Cosmic=1.2e-05,Eternal=1.2000000000000001e-14,Rare=0.79092993509902099}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack03",luck=5,expect={Legendary=0.19710423735160212,Mythic=0.063455131290529293,Secret=0.0018511015881600285,Cosmic=3.0000000000000001e-05,Eternal=3.0000000000000005e-14,Rare=0.73755952976967865}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack03",luck=20,expect={Legendary=0.26008060043229714,Mythic=0.11048180057799957,Secret=0.004885086378442852,Cosmic=0.00012,Eternal=1.2000000000000002e-13,Rare=0.62443251261114041}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack03",luck=100,expect={Legendary=0.35884091878708285,Mythic=0.2103191148267311,Secret=0.015071318589057475,Cosmic=0.00060000000000000006,Eternal=6.0000000000000007e-13,Rare=0.41516864779652851}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack03",luck=500,expect={Legendary=0.22084620951959882,Mythic=0.40037481132714375,Secret=0.046497569626450096,Cosmic=0.0030000000000000001,Eternal=3.0000000000000001e-12,Rare=0.32928140952380724}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack04",luck=1,expect={Legendary=0.33333333333333331,Mythic=0.10000000000000001,Secret=0.002,Cosmic=2.0000000000000002e-05,Eternal=2e-14,Rare=0.56464666666664665}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack04",luck=2,expect={Legendary=0.38289945166567835,Mythic=0.13195079107728944,Secret=0.0032490095854249418,Cosmic=4.0000000000000003e-05,Eternal=4e-14,Rare=0.48186074767156728}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack04",luck=5,expect={Legendary=0.45990988715373826,Mythic=0.19036539387158788,Secret=0.0061703386272000957,Cosmic=0.0001,Eternal=1e-13,Rare=0.34345438034737374}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack04",luck=20,expect={Legendary=0.42601231033746645,Mythic=0.33144540173399872,Secret=0.016283621261476176,Cosmic=0.00040000000000000002,Eternal=4.0000000000000001e-13,Rare=0.22585866666665866}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack04",luck=100,expect={Legendary=0.27190360470114983,Mythic=0.45000000000000001,Secret=0.050237728630191589,Cosmic=0.002,Eternal=2e-12,Rare=0.22585866666665866}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack04",luck=500,expect={Legendary=0.16666666666666663,Mythic=0.44248276790184099,Secret=0.15499189875483368,Cosmic=0.01,Eternal=9.9999999999999994e-12,Rare=0.22585866666665877}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack05",luck=1,expect={Legendary=0.40000000000000002,Mythic=0.25,Secret=0.0060000000000000001,Cosmic=5.9999999999999995e-05,Eternal=5.9999999999999997e-14,Rare=0.34393999999994007}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack05",luck=2,expect={Legendary=0.45947934199881407,Mythic=0.32987697769322355,Secret=0.0097470287562748253,Cosmic=0.00011999999999999999,Eternal=1.1999999999999999e-13,Rare=0.20077665155156743}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack05",luck=5,expect={Legendary=0.39361298411812373,Mythic=0.45000000000000001,Secret=0.018511015881600288,Cosmic=0.00029999999999999997,Eternal=2.9999999999999998e-13,Rare=0.13757599999997605}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack05",luck=20,expect={Legendary=0.36237313621439549,Mythic=0.45000000000000001,Secret=0.048850863784428523,Cosmic=0.0011999999999999999,Eternal=1.1999999999999999e-12,Rare=0.13757599999997594}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack05",luck=100,expect={Legendary=0.25571081410344909,Mythic=0.45000000000000001,Secret=0.15071318589057478,Cosmic=0.0059999999999999993,Eternal=5.9999999999999995e-12,Rare=0.13757599999997605}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack05",luck=500,expect={Legendary=0.20000000000000001,Mythic=0.38242399997002396,Secret=0.25,Cosmic=0.029999999999999999,Eternal=3e-11,Rare=0.13757599999997594}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack06",luck=1,expect={Mythic=0.40000000000000002,Secret=0.02,Cosmic=0.00020000000000000001,Eternal=2.0000000000000001e-13,Legendary=0.57979999999980003}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack06",luck=2,expect={Mythic=0.45000000000000001,Secret=0.032490095854249418,Cosmic=0.00040000000000000002,Eternal=4.0000000000000001e-13,Legendary=0.51710990414535063}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack06",luck=5,expect={Mythic=0.45000000000000001,Secret=0.061703386272000955,Cosmic=0.001,Eternal=9.9999999999999998e-13,Legendary=0.48729661372699906}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack06",luck=20,expect={Mythic=0.45000000000000001,Secret=0.16283621261476175,Cosmic=0.0040000000000000001,Eternal=3.9999999999999999e-12,Legendary=0.38316378738123824}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack06",luck=100,expect={Mythic=0.45000000000000001,Secret=0.25,Cosmic=0.02,Eternal=2.0000000000000002e-11,Legendary=0.27999999998000002}},
 {present={"Rare","Legendary","Mythic","Secret","Cosmic","Eternal"},biomeFloor="Rare",pack="Pack06",luck=500,expect={Mythic=0.45000000000000001,Secret=0.25,Cosmic=0.050000000000000003,Eternal=1e-10,Legendary=0.24999999989999999}},
}]=]
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
