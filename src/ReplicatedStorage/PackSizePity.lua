-- R137 (owner-approved, docs/proposals/pity_R136; owner: "the pity thing and giant drop thing has to feel random",
-- "dont put a indicator or anything just write it into the game code"): a hidden soft pity for pack sizes.
-- Nothing is shown or announced for it: a pity pack is an ordinary pack of a bigger size.
--  Player: packs you get from the track (steals, event packs) and the treadmill bonus. Once Start packs in a row came
--   out small, each further small one has a growing chance ((n-Start)/(Cap-Start))^2 to come out big instead, and the
--   Cap-th is always big. Saved per player. Mech (bought) packs, gifts and test packs neither count nor change.
--  Track: the same ramp per server, counted in refreshes; the big pack lands on a random spot.
-- A pity size is rolled from the normal size table's rows at or above the target, so it is sometimes far bigger.
local Rules=require(script.Parent.SeedPackRules)
local P={Version=137}
P.Player={Big={Size=5,Start=18,Cap=30},Giant={Size=10,Start=150,Cap=200}}
P.Track={Big={Size=5,Start=1,Cap=6},Giant={Size=10,Start=5,Cap=12}}
P.MaxCount=1e6
function P.Count(n)
 n=tonumber(n)
 if not n or n~=n then return 0 end
 return math.clamp(math.floor(n),0,P.MaxCount)
end
-- n: this pack's (or refresh's) number counted since the last big one, starting at 1.
function P.Chance(rule,n)
 if n>=rule.Cap then return 1 end
 if n<=rule.Start then return 0 end
 local k=(n-rule.Start)/(rule.Cap-rule.Start)
 return k*k
end
-- A size from the size table's rows at or above `minimum`, weighted as in the table.
function P.RollAtLeast(minimum,unit)
 local rows,total={},0
 for _,row in ipairs(Rules.PackSizes)do if row.Scale>=minimum then rows[#rows+1]=row;total+=row.Weight end end
 if #rows==0 then return minimum end
 local t=(type(unit)=='number'and unit==unit and math.clamp(unit,0,1-1e-12)or 0)*total
 for _,row in ipairs(rows)do t-=row.Weight;if t<0 then return row.Scale end end
 return rows[#rows].Scale
end
function P.State(saved)
 return {Big=P.Count(type(saved)=='table'and saved.Big),Giant=P.Count(type(saved)=='table'and saved.Giant)}
end
-- The counters after a pack (or a refresh whose biggest pack was `size`).
function P.After(rules,state,size)
 state=P.State(state)
 return {Big=size>=rules.Big.Size and 0 or math.min(P.MaxCount,state.Big+1),Giant=size>=rules.Giant.Size and 0 or math.min(P.MaxCount,state.Giant+1)}
end
-- Which pity (if any) fires for the next pack/refresh whose natural biggest size is `size`. Returns the minimum size or nil.
-- draw() is only called when a chance is above 0.
function P.Pick(rules,state,size,draw)
 state=P.State(state)
 if size<rules.Giant.Size then
  local chance=P.Chance(rules.Giant,state.Giant+1)
  if chance>=1 or chance>0 and draw()<chance then return rules.Giant.Size end
 end
 if size<rules.Big.Size then
  local chance=P.Chance(rules.Big,state.Big+1)
  if chance>=1 or chance>0 and draw()<chance then return rules.Big.Size end
 end
 return nil
end
-- One player pack: returns the size it comes out at and the new counters.
function P.ApplyPlayer(state,size,draw)
 size=Rules.SanitizePackSize(size)
 local minimum=P.Pick(P.Player,state,size,draw)
 if minimum then size=P.RollAtLeast(minimum,draw())end
 return size,P.After(P.Player,state,size)
end
-- Which pack types count: the six regular biome packs in a biome (not Mech, Void or test packs).
function P.Counts(stage,variant,paid)
 return paid~=true and type(stage)=='number'and stage>=1 and stage<=7 and table.find(Rules.VariantOrder,variant)~=nil
end
-- One track refresh. sizes: the natural size roll of every spot (in order). Returns the sizes with at most one spot
-- made big, and that spot's index (or nil). Counters move with P.After on the sizes that actually spawned.
function P.PlanTrack(state,sizes,draw)
 local out=table.clone(sizes);local biggest=0
 for _,s in ipairs(out)do biggest=math.max(biggest,s)end
 if #out==0 then return out,nil end
 local minimum=P.Pick(P.Track,state,biggest,draw)
 if not minimum then return out,nil end
 local index=math.clamp(math.floor(draw()*#out)+1,1,#out)
 out[index]=P.RollAtLeast(minimum,draw())
 return out,index
end
return P
