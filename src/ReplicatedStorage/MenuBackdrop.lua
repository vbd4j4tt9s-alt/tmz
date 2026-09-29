-- Full viewport artwork/dimmer; controls retain Roblox's safe area.
local M={}
function M.Attach(owner,shade,city)
 shade:SetAttribute('ButtonHighlight',false)
 local pg=owner.Parent;local name=owner.Name..'Backdrop';local old=pg:FindFirstChild(name);if old then old:Destroy()end
 local gui=Instance.new('ScreenGui');gui.Name=name;gui.ResetOnSpawn=false;gui.DisplayOrder=owner.DisplayOrder-1;gui.IgnoreGuiInset=true;gui.ScreenInsets=Enum.ScreenInsets.None;gui.ClipToDeviceSafeArea=false
 local root=Instance.new('Frame');root.Name='FullScreenShade';root.Size=UDim2.fromScale(1,1);root.BackgroundColor3=Color3.fromRGB(8,13,30);root.BorderSizePixel=0;root.Active=false;root.Parent=gui
 if city then
  require(script.Parent.HudArtwork).Attach(root,'City')
  local wash=Instance.new('Frame');wash.Name='Dimmer';wash.Size=UDim2.fromScale(1,1);wash.BackgroundColor3=Color3.fromRGB(7,12,32);wash.BackgroundTransparency=.35;wash.BorderSizePixel=0;wash.Active=false;wash.ZIndex=2;wash.Parent=root
 else root.BackgroundTransparency=shade.BackgroundTransparency end
 shade.BackgroundTransparency=1
 local function sync()gui.Enabled=owner.Enabled and shade.Visible end
 local a=shade:GetPropertyChangedSignal('Visible'):Connect(sync);local b=owner:GetPropertyChangedSignal('Enabled'):Connect(sync)
 sync();gui.Parent=pg
 owner.Destroying:Connect(function()a:Disconnect();b:Disconnect();gui:Destroy()end)
 return gui
end
return M
