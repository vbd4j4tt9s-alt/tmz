-- Static garden stationery: colour, fine trim and inset surfaces, with no extra animation loop.
local Theme=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTheme'))
local S={};local C=Theme.Colors
function S.Panel(panel,headerHeight)
 panel.BackgroundColor3=C.Panel
 local wash=Instance.new('UIGradient');wash.Name='GardenWash';wash.Rotation=90
 wash.Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(192,216,199));wash.Parent=panel
 local edge=Instance.new('UIStroke');edge.Name='GardenTrim';edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;edge.Color=C.Mint;edge.Thickness=1.5;edge.Transparency=.48;edge.Parent=panel
 local header=Instance.new('Frame');header.Name='GardenHeader';header.BackgroundColor3=Color3.fromRGB(65,99,77);header.BackgroundTransparency=.32;header.BorderSizePixel=0;header.Position=UDim2.fromOffset(8,8);header.Size=UDim2.new(1,-16,0,headerHeight-8);header.Active=false;header.ZIndex=0;header.Parent=panel;Theme.Corner(header,10)
 local fade=Instance.new('UIGradient');fade.Rotation=0;fade.Transparency=NumberSequence.new(.2,.88);fade.Parent=header
 local rule=Instance.new('Frame');rule.Name='HeaderRule';rule.Position=UDim2.fromOffset(16,headerHeight+2);rule.Size=UDim2.new(1,-32,0,1);rule.BorderSizePixel=0;rule.BackgroundColor3=C.Mint;rule.BackgroundTransparency=.70;rule.Active=false;rule.Parent=panel
 return header
end
function S.Inset(frame)
 frame.BackgroundColor3=C.Inset
 local line=Instance.new('UIStroke');line.Name='InsetLine';line.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;line.Color=C.Line;line.Thickness=1;line.Transparency=.3;line.Parent=frame
end
function S.Accent(parent,color)
 local line=Instance.new('Frame');line.Name='RarityRail';line.Position=UDim2.fromOffset(0,10);line.Size=UDim2.new(0,3,1,-20);line.BorderSizePixel=0;line.BackgroundColor3=color;line.Active=false;line.Parent=parent;Theme.Corner(line,3)
end
function S.Bounds(width,height,inset,noticeBottom,bottomReserve,maxWidth,wantedHeight)
 local usable=height-inset;local top=math.max(8,noticeBottom-inset+8)
 local room=math.max(100,usable-top-bottomReserve-8);local h=math.min(wantedHeight,room)
 local y=math.max(top,(usable-h)/2);y=math.min(y,usable-bottomReserve-h-8)
 return math.min(width-24,maxWidth),h,width/2,y+h/2
end
function S.Place(panel,pg,maxWidth,wantedHeight)
 local camera=workspace.CurrentCamera;if not camera then return end
 local root=panel:FindFirstAncestorOfClass('ScreenGui');if root then root.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end
 local view=root and root.AbsoluteSize or camera.ViewportSize
 -- (R158 review: ChestHotbarReserve is in screen px, scaled with a computer's HUD; the 54 it gives back - the held item's name rows' share - are HUD px too, so they shrink by the same
 -- scale Hotbar publishes as ChestHudScale (none = 1: a phone, a window of 1920 x 720 or more: exactly as before). Gap between a menu's bottom and the slots: 8 + 12 x scale px, 20 at 1.)
 local hudScale=math.clamp(tonumber(pg:GetAttribute('ChestHudScale'))or 1,0,1)
 local reserve=pg:GetAttribute('SeedMenu')=='Economy'and 16 or math.max(64,(pg:GetAttribute('ChestHotbarReserve')or 134)-54*hudScale)
 local w,h,x,y=S.Bounds(view.X,view.Y,0,pg:GetAttribute('HudNoticeBottom')or 48,reserve,maxWidth,wantedHeight)
 panel.Size=UDim2.fromOffset(w,h);panel.Position=UDim2.fromOffset(x,y)
end
return S
