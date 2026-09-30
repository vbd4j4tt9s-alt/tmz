-- R113b: BASE / TRACK fast-travel rectangles in Roblox's top bar row (owner request). R114: centred on the whole screen. The server checks every request
-- (FastTravelService); this script only shows the buttons, the shared cooldown and a dimmed state.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local remotes=RS:WaitForChild('ChestChaseRemotes')
local requestBase=remotes:WaitForChild('RequestBaseTeleport');local requestTrack=remotes:WaitForChild('RequestTrackTeleport')
local Bright=require(RS:WaitForChild('BrightUI'));local Fit=require(RS:WaitForChild('GardenTextFit'))
local Icons=require(RS:WaitForChild('VectorIcons91'))
local old=pg:FindFirstChild('TravelButtons');if old then old:Destroy()end
-- Below the tutorial card (25) and the menu hub (33): anything important draws above these buttons.
local gui=Instance.new('ScreenGui');gui.Name='TravelButtons';gui.ResetOnSpawn=false;gui.DisplayOrder=24;gui.ScreenInsets=Enum.ScreenInsets.None;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local holder=Instance.new('Frame');holder.Name='TravelPair';holder.BackgroundTransparency=1;holder.Visible=false;holder.Parent=gui
local connections={};local lastSent=0
local function make(name,caption,icon,color,remote,order)
 local b=Instance.new('TextButton');b.Name=name;b.Text='';b.BorderSizePixel=0;b.ZIndex=10;b.LayoutOrder=order;b.Parent=holder
 Bright.Button(b,color);b:SetAttribute('AccessibleLabel',caption=='BASE'and'Teleport to your base'or'Teleport to the front of the track')
 local art=Instance.new('Frame');art.Name='Icon';art.BackgroundTransparency=1;art.AnchorPoint=Vector2.new(.5,0);art.ZIndex=12;art.Parent=b
 Icons.Draw(art,icon)
 local label=Instance.new('TextLabel');label.Name='Caption';label.Text=caption;label.BackgroundTransparency=1;label.TextXAlignment=Enum.TextXAlignment.Center;label.ZIndex=15;label.Parent=b
 Bright.Text(label,10)
 local shade=Instance.new('Frame');shade.Name='Cooldown';shade.BackgroundColor3=Color3.fromRGB(8,13,24);shade.BackgroundTransparency=.45;shade.BorderSizePixel=0;shade.AnchorPoint=Vector2.new(0,1);shade.Position=UDim2.fromScale(0,1);shade.Size=UDim2.fromScale(1,0);shade.Visible=false;shade.Active=false;shade.ZIndex=16;shade.Parent=b
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=shade
 connections[#connections+1]=b.Activated:Connect(function()
  if not holder.Visible then return end
  local now=os.clock();if now-lastSent<.3 then return end;lastSent=now
  remote:FireServer()
 end)
 return {Button=b,Icon=art,Caption=label,Shade=shade}
end
local base=make('BaseButton','BASE','Home',Color3.fromRGB(78,168,96),requestBase,1)
local track=make('TrackButton','TRACK','Track',Color3.fromRGB(226,138,48),requestTrack,2)
local function blocked()
 return player:GetAttribute('ChestChaseSeedCarrying')or player:GetAttribute('ChestChaseRunActive')or player:GetAttribute('TreadmillTraining')
  or player:GetAttribute('GuardianRagdollActive')or player:GetAttribute('GuardianFlingActive')
end
local cooling
local function paint()
 local left=(tonumber(player:GetAttribute('FastTravelReadyAt'))or 0)-workspace:GetServerTimeNow()
 local fraction=blocked()and 1 or math.clamp(left/math.max(.1,tonumber(player:GetAttribute('FastTravelCooldown'))or 4),0,1)
 for _,entry in ipairs({base,track})do entry.Shade.Visible=fraction>0;entry.Shade.Size=UDim2.fromScale(1,fraction)end
 -- The per-frame update only runs while a cooldown is draining.
 if left>0 and not cooling then cooling=Run.RenderStepped:Connect(paint)
 elseif left<=0 and cooling then cooling:Disconnect();cooling=nil end
end
local function refresh()
 holder.Visible=pg:GetAttribute('TitleActive')~=true and pg:GetAttribute('SeedMenu')==nil
end
-- The top bar row: two rectangles, icon left and caption right, centred on the screen. GuiService.TopbarInset is the
-- free part of that row (between Roblox's own buttons), so the pair shrinks to stay inside it; if the screen centre is
-- too close to Roblox's buttons it centres in the free part instead.
local function layout()
 local area=gui.AbsoluteSize;if area.X<=0 or area.Y<=0 then return end
 local inset=GuiService.TopbarInset;local left,right,top,rowHeight=0,area.X,0,52
 if typeof(inset)=='Rect'and inset.Width>0 and inset.Height>0 then left,right,top,rowHeight=inset.Min.X,inset.Max.X,inset.Min.Y,inset.Height end
 local gap=8;local height=math.clamp(rowHeight-8,30,44)
 local centre=area.X/2;local half=math.min(centre-left,right-centre)-8
 if half<80 then centre=(left+right)/2;half=(right-left)/2-8 end
 local width=math.floor(math.clamp((half*2-gap)/2,72,132))
 holder.AnchorPoint=Vector2.new(.5,.5);holder.Position=UDim2.fromOffset(math.floor(centre),math.floor(top+rowHeight/2));holder.Size=UDim2.fromOffset(width*2+gap,height)
 for i,entry in ipairs({base,track})do
  entry.Button.Size=UDim2.fromOffset(width,height);entry.Button.Position=UDim2.fromOffset((i-1)*(width+gap),0)
  local icon=height-10
  entry.Icon.AnchorPoint=Vector2.new(0,.5);entry.Icon.Position=UDim2.new(0,6,.5,0);entry.Icon.Size=UDim2.fromOffset(icon,icon)
  entry.Caption.Position=UDim2.fromOffset(icon+10,0);entry.Caption.Size=UDim2.new(1,-icon-16,1,0)
  local font=math.clamp(math.floor(height*.42),12,18);entry.Caption.TextSize=font;Fit.Attach(entry.Caption,font,10)
 end
 refresh()
end
local sized=gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout);task.defer(layout)
local inset=GuiService:GetPropertyChangedSignal('TopbarInset'):Connect(layout)
local function stopLayout()sized:Disconnect();inset:Disconnect()end
for _,key in ipairs({'TitleActive','SeedMenu'})do connections[#connections+1]=pg:GetAttributeChangedSignal(key):Connect(refresh)end
for _,key in ipairs({'FastTravelReadyAt','ChestChaseSeedCarrying','ChestChaseRunActive','TreadmillTraining','GuardianRagdollActive','GuardianFlingActive'})do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(paint)end
paint();refresh()
gui.Destroying:Connect(function()
 stopLayout();if cooling then cooling:Disconnect();cooling=nil end
 for _,c in ipairs(connections)do c:Disconnect()end;table.clear(connections)
end)
