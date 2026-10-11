-- R154 (lag audit B1, owner: "for the lag fixes we can implement B3 and B1"): no shadows from the small parts the game's scripts build.
-- A part whose largest side is under S.MaxSide (1.5 studs: fruit, pebbles, petals, lamp collars, fence insets, pack seals ...) casts a shadow a few
-- pixels wide; the sun's shadow pass pays for every caster (about 900 of the hub's 3,300). The builders call this where they make or settle a part,
-- once, so nothing scans the workspace afterwards (no DescendantAdded listener):
--   S.Keeps(size)  -> true when a part of that size keeps its shadow (largest side >= MaxSide)
--   S.Part(part)   -> the part, with CastShadow off when it is small (a part that already casts none stays that way; a big part is never touched)
--   S.Tree(root)   -> number of parts under root (root included) switched off: for a model that was scaled after it was built (the market's fruit)
-- Never used on the saved map's own parts, characters, avatars or keepers (their builders do not call it).
local S={MaxSide=1.5}
function S.Keeps(size)return math.max(size.X,size.Y,size.Z)>=S.MaxSide end
function S.Part(part)
 if part.CastShadow~=false and not S.Keeps(part.Size)then part.CastShadow=false end
 return part
end
function S.Tree(root)
 local n=0
 local function one(d)if d:IsA('BasePart')and d.CastShadow~=false and not S.Keeps(d.Size)then d.CastShadow=false;n+=1 end end
 one(root)
 for _,d in ipairs(root:GetDescendants())do one(d)end
 return n
end
return S
