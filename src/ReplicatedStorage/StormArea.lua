-- Pure spatial policy shared by server selection and offline tests.
local Area={}
function Area.Contains(area,position,margin)
    local p=area.Frame:PointToObjectSpace(position)
    return math.abs(p.X)<=area.HalfX-margin and math.abs(p.Z)<=area.HalfZ-margin
end
function Area.Clear(area,position,radius)
    if not Area.Contains(area,position,radius+area.EdgeMargin)then return false end
    for _,zone in ipairs(area.Exclusions)do
        local d=position-zone.Position
        if d.X*d.X+d.Z*d.Z<=(radius+zone.Radius)^2 then return false end
    end
    return true
end
function Area.Hit(area,center,position,radius,height)
    if not Area.Contains(area,position,0)then return false end
    local p=area.Frame:PointToObjectSpace(position)
    local delta=position-center
    return p.Y>=-2 and p.Y<=height and delta.X*delta.X+delta.Z*delta.Z<=radius*radius
end
function Area.Choose(area,radius,random,attempts)
    local x,z=area.HalfX-radius-area.EdgeMargin,area.HalfZ-radius-area.EdgeMargin
    if x<=0 or z<=0 then return nil end
    for _=1,attempts do
        local center=area.Frame*Vector3.new(random:NextNumber(-x,x),.12,random:NextNumber(-z,z))
        if Area.Clear(area,center,radius)then return center end
    end
    return nil
end
return Area
