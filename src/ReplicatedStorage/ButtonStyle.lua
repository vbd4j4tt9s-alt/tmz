-- V106: shared pictogram controls. No input actions or gameplay state live here.
local TweenService = game:GetService("TweenService")
local Glyphs = require(script.Parent.IconGlyphs)
local Style = {}

function Style.Create(parent, name, icon, position, size, color, wide)
    local button = Instance.new("ImageButton")
    button.Name = name
    button.Image = ""
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.ClipsDescendants = false
    button:SetAttribute("IconControl", true)
    button:SetAttribute("IconName", icon)
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, wide and 7 or 3)
    corner.Parent = button
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(18, 27, 42)
    stroke.Thickness = 2
    stroke.Parent = button
    local fill=Instance.new('UIGradient');fill.Name='ButtonFill';fill.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.32),color:Lerp(Color3.new(),.10));fill.Rotation=90;button.BackgroundColor3=Color3.new(1,1,1);fill.Parent=button
    local glint=Instance.new('Frame');glint.Name='TopGlint';glint.Position=UDim2.fromOffset(3,3);glint.Size=UDim2.new(1,-6,0,2);glint.BackgroundColor3=Color3.new(1,1,1);glint.BackgroundTransparency=.36;glint.BorderSizePixel=0;glint.Active=false;glint.Parent=button
    require(script.Parent.GuiShine).Attach(button)
    -- A dark lower bevel gives square controls their raised cube appearance.
    local bevel = Instance.new("Frame")
    bevel.Name = "LowerEdge"
    bevel.Position = UDim2.new(0, 1, 1, -6)
    bevel.Size = UDim2.new(1, -2, 0, 5)
    bevel.BackgroundColor3 = Color3.new(0, 0, 0)
    bevel.BackgroundTransparency = .68
    bevel.BorderSizePixel = 0
    bevel.Active = false
    bevel.Parent = button
    local iconRoot = Glyphs.Draw(button, icon, Color3.fromRGB(255, 255, 255))
    iconRoot.AnchorPoint = Vector2.new(.5, .5)
    iconRoot.Position = UDim2.fromScale(.5, .46)
    -- V108: make the top navigation symbols legible without enlarging squares.
    iconRoot.Size = UDim2.fromScale(wide and .82 or .66, wide and .82 or .66)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1
    aspect.DominantAxis = Enum.DominantAxis.Height
    aspect.Parent = iconRoot
    local scale = Instance.new("UIScale")
    scale.Name = "HoverScale"
    scale.Parent = button
    local hovered, selected, pressed, dead = false, false, false, false
    local tween, borderTween
    local connections = {}
    local function refresh()
        if dead then return end
        local enabled = button.Active and button.Interactable
        local focus = enabled and (hovered or selected)
        if tween then tween:Cancel() end
        if borderTween then borderTween:Cancel() end
        tween = TweenService:Create(scale, TweenInfo.new(.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Scale = enabled and pressed and .94 or (focus and 1.10 or 1)})
        borderTween = TweenService:Create(stroke, TweenInfo.new(.14),
            {Color = focus and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(18, 27, 42)})
        tween:Play()
        borderTween:Play()
    end
    local function connect(signal, callback)
        table.insert(connections, signal:Connect(callback))
    end
    connect(button.MouseEnter, function() hovered = true; refresh() end)
    connect(button.MouseLeave, function() hovered = false; pressed = false; refresh() end)
    connect(button.SelectionGained, function() selected = true; refresh() end)
    connect(button.SelectionLost, function() selected = false; pressed = false; refresh() end)
    connect(button.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
            or input.KeyCode == Enum.KeyCode.ButtonA then pressed = true; refresh() end
    end)
    connect(button.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
            or input.KeyCode == Enum.KeyCode.ButtonA then pressed = false; refresh() end
    end)
    connect(button:GetPropertyChangedSignal("Active"), refresh)
    connect(button:GetPropertyChangedSignal("Interactable"), refresh)
    connect(button:GetPropertyChangedSignal("Visible"), function()
        if not button.Visible then hovered = false; selected = false; pressed = false; refresh() end
    end)
    connect(button.Destroying, function()
        dead = true
        if tween then tween:Cancel() end
        if borderTween then borderTween:Cancel() end
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
    end)
    return button
end

function Style.SetEnabled(button, enabled)
    button.Active = enabled
    button.Interactable = enabled
    button.Selectable = enabled
    button.BackgroundTransparency = enabled and 0 or .32
end

return Style
