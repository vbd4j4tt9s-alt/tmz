-- R68: one short cue at each of the final three seconds, using the server deadline.
local C={}
function C.New(deadline)return {Deadline=deadline,Last=0}end
function C.Take(state,now)
 local deadline=tonumber(state.Deadline)
 if not deadline or deadline~=deadline or math.abs(deadline)==math.huge then return nil end
 local remaining=deadline-now
 if remaining<=0 then state.Last=3;return nil end
 if remaining>3 then return nil end
 local second=math.ceil(remaining);local number=4-second
 if number<=state.Last then return nil end
 state.Last=number
 -- Joining late, a stalled frame or an unloaded sound must never produce a burst of old cues.
 if second-remaining>.25 then return nil end
 return number
end
return C
