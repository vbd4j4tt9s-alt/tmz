-- V107: presentation-only crossings. Progress runs along world +Z,
-- not numeric stage order (Forest -> Jungle -> Desert is 1 -> 6 -> 2).
local Gate = {}
Gate.__index = Gate
function Gate.new() return setmetatable({}, Gate) end
function Gate:Reset() self.Position, self.Stage = nil, nil end
function Gate:Step(position, stage, startZ, moveZ, elapsed, walkSpeed)
    if not position then self:Reset(); return false, true end
    local previous, lastStage = self.Position, self.Stage
    self.Position, self.Stage = position, stage
    if not previous then return false, true end -- Spawn/load is not walking in.
    local delta = position - previous
    local backwards = moveZ < -.05 or delta.Z < -.05
    if stage == lastStage then return false, backwards end
    -- Consume rejected transitions too; do not queue a stale title after a
    -- teleport, sideways re-entry, or return journey.
    if stage == 0 or not startZ or backwards or moveZ <= .05 or delta.Z <= .015 then
        return false, true
    end
    if elapsed <= 0 or elapsed > .5 then return false, true end
    local maxStep = math.max(4, math.max(walkSpeed, 0) * elapsed * 1.8 + 2)
    if delta.Magnitude > maxStep or previous.Z > startZ or position.Z < startZ then
        return false, true
    end
    return true, false
end
return Gate
