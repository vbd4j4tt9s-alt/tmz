-- R78: target centres inside one horizontal box extending forward from the attacker.
local C=require(script.Parent.BatConfig)
local B={}
function B.Contains(frame,position)
 local forward=Vector3.new(frame.LookVector.X,0,frame.LookVector.Z)
 if forward.Magnitude<.01 then return false end
 forward=forward.Unit;local offset=position-frame.Position
 local depth=forward:Dot(offset);local side=forward:Cross(Vector3.yAxis):Dot(offset)
 return depth>0 and depth<=C.HitboxSize.Z and math.abs(side)<=C.HitboxSize.X*.5 and math.abs(offset.Y)<=C.HitboxSize.Y*.5
end
return B
