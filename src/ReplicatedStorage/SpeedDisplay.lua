-- R158i (owner: "increase the base speed of new players to 20k in-game speed but of course this is still displayed as 1 speed on their screen"): every player's speed POINTS start at
-- Floor (20,000; a new profile starts there and an older profile below it is raised to it on load: PlayerDataService), but the number a player READS is the points minus Offset (19,999),
-- never below 1: a new player reads 1, 20,000 + 60 points read 61. The ONE place that rule lives: every screen that shows a player's speed or a speed a keeper / gate asks for goes through
-- here (the HUD readout, the player list, the hub's TOP SPEED board, the keeper SPEED NEEDED signs and the hub gate keys). Gains (+60 popups, "+N per step", "+15K SPEED" bundles) are
-- DELTAS and stay as they are, and every comparison (a keeper against your speed, walk speed, the save, the board's sort) keeps using the real points. Pure: no Instances.
local P=require(script.Parent.SpeedPoints)
local D={Version='158i',Floor=20000}
D.Offset=D.Floor-1
-- The shown speed as exact decimal text: points - 19,999, never below 1. `points` is a decimal string or a number (anything unreadable counts as 0 points: it shows 1).
function D.Shown(points)
 local p=P.Normalize(points)
 if P.Compare(p,tostring(D.Floor))<=0 then return'1'end
 return P.Sub(p,tostring(D.Offset))
end
-- The same in the three ways the game writes a speed.
function D.Compact(points)return require(script.Parent.CashNumbers).Compact(D.Shown(points))end -- the HUD: 1, 61, 12.5K
function D.Exact(points)return require(script.Parent.CashNumbers).Exact(D.Shown(points))end -- the HUD's exact label: 1,234
function D.PlayerList(points)return require(script.Parent.CashNumbers).PlayerList(D.Shown(points))end -- the narrow player-list cell
-- A speed that is ASKED of the player (a keeper's sign, a gate key): `points` = the real points that are needed; the sign's number = the shown speed rounded UP to 2 significant figures
-- (SpeedPoints.NeedText). Anything up to the starting 20,000 points reads "1" (every player already has it).
function D.NeedText(points)
 local shown=D.Shown(points)
 if shown=='1'then return'1'end
 return P.NeedText(shown)
end
-- The sign's number for a keeper that runs at walk speed `speed` (KeeperEscapeSpeed): you must be strictly faster, so one point more than the points that reach `speed`.
function D.NeedForWalkSpeed(speed)
 local Progress=require(script.Parent.Progression81)
 if speed<Progress.Speed(0)then return D.NeedText('0')end
 return D.NeedText(P.Add(Progress.PointsText(speed),'1'))
end
-- For the owner's / test commands: both numbers, "61 (20,060 points)".
function D.Both(points)
 return D.Shown(points)..' ('..P.Exact(points)..' points)'
end
return D
