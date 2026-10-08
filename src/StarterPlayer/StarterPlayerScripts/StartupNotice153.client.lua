do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R153 (owner: "if a server fails just kick them out"): the live server kicks everybody when it fails to start, so this only ever shows in STUDIO, where the server does not kick but
-- sets ReplicatedStorage.ChestChaseStartupNotice (ChestChaseServerMain's start-up guard) so the owner sees on screen that the server broke while loading. The SERVER decides:
-- this script trusts nothing and decides nothing, it draws the text of that attribute while it is a non-empty string and hides it when it is cleared. It needs no other script,
-- module or server object (a failed server may have none of them), only ReplicatedStorage and the player's own PlayerGui.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local pg=Players.LocalPlayer:WaitForChild('PlayerGui')
local ATTRIBUTE='ChestChaseStartupNotice'
local gui,label
local function build()
 gui=Instance.new('ScreenGui');gui.Name='StartupNotice153';gui.ResetOnSpawn=false;gui.DisplayOrder=1000;gui.IgnoreGuiInset=true;gui.Enabled=false
 local card=Instance.new('Frame');card.Name='Card';card.AnchorPoint=Vector2.new(.5,0);card.Position=UDim2.new(.5,0,0,70);card.Size=UDim2.new(.9,0,0,0);card.AutomaticSize=Enum.AutomaticSize.Y
 card.BackgroundColor3=Color3.fromRGB(34,22,28);card.BackgroundTransparency=.08;card.BorderSizePixel=0;card.Parent=gui
 local cap=Instance.new('UISizeConstraint');cap.MaxSize=Vector2.new(560,1000);cap.Parent=card
 local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,14);round.Parent=card
 local line=Instance.new('UIStroke');line.Color=Color3.fromRGB(255,120,120);line.Thickness=2;line.Parent=card
 local pad=Instance.new('UIPadding');pad.PaddingTop=UDim.new(0,12);pad.PaddingBottom=UDim.new(0,12);pad.PaddingLeft=UDim.new(0,16);pad.PaddingRight=UDim.new(0,16);pad.Parent=card
 label=Instance.new('TextLabel');label.Name='Text';label.BackgroundTransparency=1;label.Size=UDim2.new(1,0,0,0);label.AutomaticSize=Enum.AutomaticSize.Y
 label.Font=Enum.Font.FredokaOne;label.TextSize=22;label.TextColor3=Color3.fromRGB(255,235,235);label.TextWrapped=true;label.TextXAlignment=Enum.TextXAlignment.Center;label.Parent=card
 gui.Parent=pg
end
local function show()
 local text=RS:GetAttribute(ATTRIBUTE)
 if type(text)~='string'or text==''then if gui then gui.Enabled=false end;return end
 if not gui then build()end
 label.Text=string.sub(text,1,400);gui.Enabled=true
end
RS:GetAttributeChangedSignal(ATTRIBUTE):Connect(show)
show()
script.Destroying:Connect(function()if gui then gui:Destroy();gui=nil end end)
