-- R151 (owner: "the notification for the index, the red circle and the +, has to be polished, it looks really low quality and cut out wrongly"): ONE red
-- notification badge for every Index alert (the INDEX button's count, the MENU button's "!", the dots on the Index tabs) and for the DAILY button / tabs, which
-- carried a copy of the same code. Replaces the R138 badge (a flat red Frame with a 2 px white UIStroke and a TextScaled label as big as the frame).
--  * WHY IT WAS CUT OUT (HudLayout.Navigation): the INDEX button lives inside a CanvasGroup (MenuOption2) that is only 8 px bigger than the button, and a
--    CanvasGroup clips everything past its edge. The old badge hung 6 px past the button's top-right corner, plus its 2 px ring, so 4 px of the circle
--    (top and right) were sliced off flat. The dots on the tabs had the same fault: the tab row is a ScrollingFrame, which clips at its top edge, and a dot
--    that hangs 1 px out was cut there. Nothing was wrong with the colour or the Corner: the circle was simply drawn outside its parent's clip.
--  * NOW: a transparent square holder (UIAspectRatioConstraint 1) that holds, back to front, a pulse halo, a soft two-layer drop shadow, the disc (a perfect
--    circle: UICorner 1,0; a bright red UIGradient; a white UIStroke ring that stays INSIDE the holder, so `size` is the outer diameter) with a glass shine, and
--    the count (FredokaOne, centred, TextScaled inside a UITextSizeConstraint, white with a dark red edge; "9+" past nine). The overhang past the corner it
--    is placed on is explicit (B.Make's `overhang`) and B.Extent says how far the badge can ever reach (ring, shadow, pop, halo), which HudLayout turns into
--    the CanvasGroup's margin (B.Margin) so nothing is clipped; the tab dots sit fully inside their tab (overhang 0).
--  * Motion: a pop-in when it appears and a short pop when the count goes up, then a gentle halo pulse (one looping tween per visible badge, none for a
--    hidden one). With Reduced Motion (GuiService.ReducedMotionEnabled) there is no pop and no pulse, also when it is switched on while a badge pulses.
-- Names stay what they were (the holder is the "RewardBadge" / "RewardDot" / "IndexRewardAlert"; its `Count` TextLabel holds the text and the holder's
-- Visible says whether it shows), so callers and tests that read `badge.Visible` and `badge.Count.Text` are unchanged.
local Tween=game:GetService('TweenService');local Gui=game:GetService('GuiService')
local RGB=Color3.fromRGB
-- R153 (owner, after R152: "increase the size of the notification bubble"): every badge is 1.5x its R151 size (B.Grow), the same circle, ring, shine, pop and halo, only bigger. Its
-- hold on the corner grows with it (overhang x 1.5), so B.Extent of the biggest (the INDEX count: 15 px) is what the wheel's CanvasGroup keeps round a button: Margin 12 -> 16.
-- The callers read the sizes from B.Sizes / B.Overhang (nothing hard-codes a diameter any more).
local B={Revision=151,Grow=1.5,
 Margin=16,        -- px a host (HudLayout's CanvasGroup) leaves around a button for the badge on its corner; B.Extent of the largest badge must fit
 PopScale=1.2,     -- the biggest the holder gets (the pop)
 PulseScale=1.25,  -- the biggest the halo gets, in holders
 PopSeconds=.32,PulseSeconds=1.3,PulseDelay=.6,
 Colors={Top=RGB(255,104,116),Bottom=RGB(214,24,54),Ring=Color3.new(1,1,1),Shadow=RGB(14,0,10),Edge=RGB(124,10,30),Halo=RGB(255,72,88)}}
-- Outer diameter (px) and overhang past the corner (px; negative = inside it) of every badge in the game. R151: 24 / 20 / 20 / 14 and 6 / 6 / 1 / -3.
B.Sizes={Count=36,Alert=30,Daily=30,Dot=21}
B.Overhang={Count=9,Alert=9,Daily=-1,Dot=-4}
local pulses=setmetatable({},{__mode='k'})
local hooked
-- The ring is part of `size` (the holder is the OUTER diameter): 1.5 px on a dot, 2 on the 20-24 px badges.
function B.RingThickness(size)return math.clamp(math.floor(size*.09*2+.5)/2,1.5,3)end
function B.ShadowOffset(size)return math.max(1,math.floor(size*.08+.5))end
-- "3", "9+" (past nine) or '' (nothing to count: a dot).
function B.Text(n)
 n=type(n)=='number'and n==n and math.floor(n)or 0
 if n<=0 then return''end
 return n>9 and'9+'or tostring(n)
end
-- How far (px) a badge of `size` placed with `overhang` can reach past the corner it sits on, over everything it draws: the pop, the halo's pulse and the
-- shadow's drop. (Pop and halo never run together: the pulse starts after the pop.) 0 or less = it stays inside the corner.
function B.Extent(size,overhang)
 local r=size/2;local inset=r-(overhang or 0)
 local reach=math.max(r*B.PopScale,r*B.PulseScale)+B.ShadowOffset(size)*.5
 return math.max(0,math.ceil(reach-inset))
end
local function circle(parent,name,z)
 local f=Instance.new('Frame');f.Name=name;f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale(.5,.5);f.Size=UDim2.fromScale(1,1);f.BorderSizePixel=0
 f.BackgroundColor3=Color3.new(1,1,1);f.Active=false;f.ZIndex=z;f.Parent=parent
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(1,0);c.Parent=f
 return f
end
local function style(b,size)
 local ring=B.RingThickness(size);local drop=B.ShadowOffset(size)
 b.Size=UDim2.fromOffset(size,size)
 local soft=b.ShadowSoft;soft.Position=UDim2.new(.5,0,.5,drop);soft.Size=UDim2.fromScale(1.14,1.14)
 local tight=b.Shadow;tight.Position=UDim2.new(.5,0,.5,math.max(1,math.floor(drop*.6+.5)))
 local disc=b.Disc;disc.Size=UDim2.new(1,-ring*2,1,-ring*2);disc.RingStroke.Thickness=ring
 local label=b.Count;label.Size=UDim2.new(1,-(ring*2+2),1,-(ring*2+2)) -- inside the disc, a pixel clear of the ring
 label.UITextSizeConstraint.MaxTextSize=math.max(8,math.floor(size*.62));label.UITextSizeConstraint.MinTextSize=6
 b:SetAttribute('BadgeSize',size)
end
local function build(parent,name,size)
 local b=Instance.new('Frame');b.Name=name;b.AnchorPoint=Vector2.new(.5,.5);b.BackgroundTransparency=1;b.BorderSizePixel=0;b.ClipsDescendants=false;b.Active=false
 b.ZIndex=20;b.Visible=false;b:SetAttribute('NotifyBadge',B.Revision)
 local ratio=Instance.new('UIAspectRatioConstraint');ratio.AspectRatio=1;ratio.DominantAxis=Enum.DominantAxis.Width;ratio.Parent=b
 local scale=Instance.new('UIScale');scale.Name='Pop';scale.Scale=1;scale.Parent=b
 -- back to front: halo (pulses), soft shadow, tight shadow, disc (ring, gradient, shine), count
 local glow=circle(b,'Glow',1);glow.BackgroundColor3=B.Colors.Halo;glow.BackgroundTransparency=1;glow.Visible=false
 local soft=circle(b,'ShadowSoft',2);soft.BackgroundColor3=B.Colors.Shadow;soft.BackgroundTransparency=.84
 local tight=circle(b,'Shadow',3);tight.BackgroundColor3=B.Colors.Shadow;tight.BackgroundTransparency=.6
 local disc=circle(b,'Disc',4)
 local gradient=Instance.new('UIGradient');gradient.Name='Fill';gradient.Rotation=90;gradient.Color=ColorSequence.new(B.Colors.Top,B.Colors.Bottom);gradient.Parent=disc
 local ring=Instance.new('UIStroke');ring.Name='RingStroke';ring.Color=B.Colors.Ring;ring.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;ring.LineJoinMode=Enum.LineJoinMode.Round;ring.Parent=disc
 local shine=circle(disc,'Shine',5);shine.AnchorPoint=Vector2.new(.5,0);shine.Position=UDim2.fromScale(.5,.07);shine.Size=UDim2.fromScale(.62,.3);shine.BackgroundTransparency=.7
 local fade=Instance.new('UIGradient');fade.Rotation=90;fade.Transparency=NumberSequence.new(0,1);fade.Parent=shine
 local label=Instance.new('TextLabel');label.Name='Count';label.AnchorPoint=Vector2.new(.5,.5);label.Position=UDim2.fromScale(.5,.5)
 label.BackgroundTransparency=1;label.BorderSizePixel=0;label.Active=false;label.Font=Enum.Font.FredokaOne;label.Text='';label.TextScaled=true;label.TextWrapped=false
 label.TextColor3=Color3.new(1,1,1);label.TextStrokeColor3=B.Colors.Edge;label.TextStrokeTransparency=.3
 label.TextXAlignment=Enum.TextXAlignment.Center;label.TextYAlignment=Enum.TextYAlignment.Center;label.ZIndex=6;label.Parent=b
 local fit=Instance.new('UITextSizeConstraint');fit.Parent=label
 b.Parent=parent
 style(b,size)
 b.Destroying:Connect(function()local p=pulses[b];if p then p:Cancel();pulses[b]=nil end end)
 return b
end
-- Puts the badge's centre `size/2 - overhang` px inside the parent's top-right corner: `overhang` px of it hang past the top and the right (0 = fully inside).
-- R153 client bug review (finding 7): with `left` it goes on the top-LEFT corner instead (the same distances), for a parent whose top-right holds text (the Index biome tabs' count).
local function place(b,size,overhang,left)
 left=left==true
 if b:GetAttribute('BadgeOverhang')==overhang and b:GetAttribute('BadgeLeft')==left then return end
 local inset=size/2-overhang;b.Position=left and UDim2.new(0,inset,0,inset)or UDim2.new(1,-inset,0,inset);b:SetAttribute('BadgeOverhang',overhang);b:SetAttribute('BadgeLeft',left)
end
-- parent: the button / tab it sits on (its top-right corner); name: 'RewardBadge' / 'RewardDot' / 'IndexRewardAlert'; size: the outer diameter in px (the old badge
-- sizes were 24, 20 and 14); overhang: px hanging past the corner (the parent's clip must have B.Extent(size,overhang) to spare; default 0 = inside);
-- left: true = the top-left corner (default: the top-right one).
-- Idempotent: asking again for the same name returns the same badge (and restyles it when the size changed).
function B.Make(parent,name,size,overhang,left)
 size=math.max(10,math.floor((tonumber(size)or 20)+.5));overhang=tonumber(overhang)or 0
 local b=parent:FindFirstChild(name)
 if not(b and b:GetAttribute('NotifyBadge')==B.Revision)then if b then b:Destroy()end;b=build(parent,name,size)end
 if b:GetAttribute('BadgeSize')~=size then style(b,size);b:SetAttribute('BadgeOverhang',nil)end
 place(b,size,overhang,left)
 return b
end
local function stop(b)
 local p=pulses[b];if p then p:Cancel();pulses[b]=nil end
 local glow=b:FindFirstChild('Glow');if glow then glow.Visible=false;glow.BackgroundTransparency=1;glow.Size=UDim2.fromScale(1,1)end
end
local function pulse(b)
 if pulses[b]or Gui.ReducedMotionEnabled or not b.Visible then return end
 local glow=b:FindFirstChild('Glow');if not glow then return end
 glow.Size=UDim2.fromScale(1,1);glow.BackgroundTransparency=.55;glow.Visible=true
 local t=Tween:Create(glow,TweenInfo.new(B.PulseSeconds,Enum.EasingStyle.Sine,Enum.EasingDirection.Out,-1,false,B.PulseDelay),{Size=UDim2.fromScale(B.PulseScale,B.PulseScale),BackgroundTransparency=1})
 pulses[b]=t;t:Play()
 if not hooked then
  hooked=true
  Gui:GetPropertyChangedSignal('ReducedMotionEnabled'):Connect(function()
   if Gui.ReducedMotionEnabled then for badge in pairs(pulses)do stop(badge)end end
  end)
 end
end
-- A short pop of the whole badge (count went up). Nothing with Reduced Motion.
function B.Pop(b)
 local scale=b:FindFirstChildOfClass('UIScale');if not scale or Gui.ReducedMotionEnabled then return end
 scale.Scale=B.PopScale;Tween:Create(scale,TweenInfo.new(B.PopSeconds,Enum.EasingStyle.Back),{Scale=1}):Play()
end
-- Shows / hides the badge with its text ('' for a dot). `pop`: the count went up (a visible badge pops; a badge that has just appeared pops in anyway).
function B.Set(b,text,visible,pop)
 text=type(text)=='string'and text or'';visible=visible==true
 local label=b:FindFirstChild('Count');if label and label.Text~=text then label.Text=text end
 local was=b.Visible
 if visible~=was then b.Visible=visible end
 if not visible then stop(b);return b end
 if Gui.ReducedMotionEnabled then
  local scale=b:FindFirstChildOfClass('UIScale');if scale then scale.Scale=1 end;stop(b)
 elseif not was then
  local scale=b:FindFirstChildOfClass('UIScale')
  if scale then scale.Scale=.45;Tween:Create(scale,TweenInfo.new(B.PopSeconds,Enum.EasingStyle.Back),{Scale=1}):Play()end
  pulse(b)
 else
  if pop then B.Pop(b)end
  pulse(b)
 end
 return b
end
-- Tests / tools: is this badge pulsing right now?
function B.Pulsing(b)return pulses[b]~=nil end
return B
