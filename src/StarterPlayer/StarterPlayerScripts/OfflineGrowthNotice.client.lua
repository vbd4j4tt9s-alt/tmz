-- R125 (owner): while the Roblox menu is open (Esc / the Roblox button), a big card behind it reminds players that
-- their plants keep growing offline (crops grow on real time; nothing pauses while you are away).
-- Shows the player's own plant count when they have plants. Nothing runs while the menu is closed.
local Players=game:GetService('Players');local GuiService=game:GetService('GuiService');local Run=game:GetService('RunService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local RGB=Color3.fromRGB;local INK=RGB(12,24,16)
local old=pg:FindFirstChild('OfflineGrowthNotice');if old then old:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='OfflineGrowthNotice';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=250
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false;gui.Parent=pg
local card=Instance.new('Frame');card.Name='Card';card.AnchorPoint=Vector2.new(.5,1);card.Position=UDim2.new(.5,0,1,-28)
card.Size=UDim2.fromOffset(720,118);card.BackgroundColor3=Color3.new(1,1,1);card.BorderSizePixel=0;card.Parent=gui
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,22);corner.Parent=card
local shade=Instance.new('UIGradient');shade.Rotation=90;shade.Color=ColorSequence.new(RGB(64,150,72),RGB(22,74,40));shade.Parent=card
local rim=Instance.new('UIStroke');rim.Color=RGB(196,255,140);rim.Thickness=3;rim.Parent=card
local limit=Instance.new('UISizeConstraint');limit.MinSize=Vector2.new(280,96);limit.Parent=card
local sprout=Instance.new('TextLabel');sprout.Name='Sprout';sprout.BackgroundTransparency=1;sprout.Text='🌱';sprout.TextScaled=true
sprout.Font=Enum.Font.GothamBlack;sprout.AnchorPoint=Vector2.new(0,.5);sprout.Position=UDim2.new(0,16,.5,0);sprout.Size=UDim2.fromOffset(78,78);sprout.Parent=card
local grow=Instance.new('UIScale');grow.Parent=sprout
local title=Instance.new('TextLabel');title.Name='Title';title.BackgroundTransparency=1;title.Font=Enum.Font.FredokaOne;title.TextScaled=true
title.Text='YOUR PLANTS GROW WHILE YOU\'RE OFFLINE';title.TextColor3=Color3.new(1,1,1);title.TextXAlignment=Enum.TextXAlignment.Left
title.Position=UDim2.new(0,106,0,14);title.Size=UDim2.new(1,-124,0,46);title.Parent=card
local titleFit=Instance.new('UITextSizeConstraint');titleFit.MaxTextSize=34;titleFit.MinTextSize=14;titleFit.Parent=title
local titleEdge=Instance.new('UIStroke');titleEdge.Color=INK;titleEdge.Thickness=2.5;titleEdge.Parent=title
local titleShine=Instance.new('UIGradient');titleShine.Rotation=90;titleShine.Color=ColorSequence.new(Color3.new(1,1,1),RGB(214,255,160));titleShine.Parent=title
local sub=Instance.new('TextLabel');sub.Name='Detail';sub.BackgroundTransparency=1;sub.Font=Enum.Font.GothamBold;sub.TextScaled=true
sub.TextColor3=RGB(232,255,214);sub.TextXAlignment=Enum.TextXAlignment.Left;sub.Position=UDim2.new(0,108,0,64);sub.Size=UDim2.new(1,-126,0,36);sub.Parent=card
local subFit=Instance.new('UITextSizeConstraint');subFit.MaxTextSize=20;subFit.MinTextSize=11;subFit.Parent=sub
local subEdge=Instance.new('UIStroke');subEdge.Color=INK;subEdge.Thickness=1.5;subEdge.Transparency=.2;subEdge.Parent=sub
-- Plot parts carry GardenOwnerId / GardenPlantCount (GardenPlantRuntime). Found once, re-read on every open.
local plots
local function plantCount()
 local map=workspace:FindFirstChild('ChestChaseMap');if not map then return 0 end
 if not plots then plots={};for _,d in ipairs(map:GetDescendants())do if d:IsA('BasePart')and d:GetAttribute('GardenPlantCount')~=nil then table.insert(plots,d)end end end
 local n=0
 for _,p in ipairs(plots)do if p.Parent and p:GetAttribute('GardenOwnerId')==player.UserId then n+=tonumber(p:GetAttribute('GardenPlantCount'))or 0 end end
 if n==0 then plots=nil end -- a plot assigned after the first look is found next time
 return n
end
local function detail(n)
 if n<=0 then return'Plant seeds before you leave - they keep growing while you\'re away!'end
 return string.format('Your %d plant%s keep%s growing - come back to harvest!',n,n==1 and''or's',n==1 and's'or'')
end
local pulse;local clock=0
local Audio=require(game:GetService('ReplicatedStorage'):WaitForChild('InteractionAudio'))
local function setOpen(open)
 -- R150: the card is a menu-like pop-up on Esc: it clicks open / closed like every other panel (not at script start: gui.Enabled already false).
 if open~=gui.Enabled then Audio.Play(open and'MenuClick'or'MenuClose')end
 if open then
  sub.Text=detail(plantCount());gui.Enabled=true
  if not pulse then pulse=Run.RenderStepped:Connect(function(dt)
   clock+=dt;grow.Scale=GuiService.ReducedMotionEnabled and 1 or 1+.06*math.sin(clock*3)
  end)end
 else
  gui.Enabled=false;if pulse then pulse:Disconnect();pulse=nil end
 end
end
local conns={GuiService.MenuOpened:Connect(function()setOpen(true)end),GuiService.MenuClosed:Connect(function()setOpen(false)end)}
setOpen(GuiService.MenuIsOpen==true)
script.Destroying:Connect(function()for _,c in ipairs(conns)do c:Disconnect()end;if pulse then pulse:Disconnect()end;gui:Destroy()end)
