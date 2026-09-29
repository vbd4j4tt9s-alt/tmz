-- GetInsetArea rectangles all share CoreUISafeInsets coordinates. Subtract
-- the None rectangle origin to work in true viewport coordinates.
local Layout = {}
function Layout.Calculate(full, device, top)
    local cx = full.Width / 2
    local left, right = top.Min.X - full.Min.X, top.Max.X - full.Min.X
    local width = math.min(420, 2 * math.min(cx - left, right - cx) - 16)
    local y = top.Min.Y - full.Min.Y + 5
    local fallback = width < 126 or top.Height < 52
    if fallback then
        left, right = device.Min.X - full.Min.X, device.Max.X - full.Min.X
        width = math.min(420, 2 * math.min(cx - left, right - cx) - 16)
        y = math.max(top.Max.Y, device.Min.Y) - full.Min.Y + 5
    end
    return {X = cx, Y = y, Width = math.max(0, width), Height = 48,
        Visible = width >= 126, BelowCoreUI = fallback}
end
return Layout
