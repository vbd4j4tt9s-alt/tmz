do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R113b: BASE / TRACK fast-travel rectangles in Roblox's top bar row (owner request). R114: centred on the whole screen. The server checks every request
-- (FastTravelService); this script only shows the buttons, the shared cooldown and a dimmed state.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local remotes=RS:WaitForChild('ChestChaseRemotes')
local requestBase=remotes:WaitForChild('RequestBaseTeleport');local requestTrack=remotes:WaitForChild('RequestTrackTeleport')
local Bright=require(RS:WaitForChild('BrightUI'));local Fit=require(RS:WaitForChild('GardenTextFit'))
local Tween=game:GetService('TweenService')
local Sfx=require(RS:WaitForChild('LocalSfx'));Sfx.Preload({Sfx.WhooshId}) -- R150: the arrival whoosh is warm before the first teleport
local old=pg:FindFirstChild('TravelButtons');if old then old:Destroy()end
-- Below the tutorial card (25) and the menu hub (33): anything important draws above these buttons.
local gui=Instance.new('ScreenGui');gui.Name='TravelButtons';gui.ResetOnSpawn=false;gui.DisplayOrder=24;gui.ScreenInsets=Enum.ScreenInsets.None;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local holder=Instance.new('Frame');holder.Name='TravelPair';holder.BackgroundTransparency=1;holder.Visible=false;holder.Parent=gui
-- R140: two square slots in the same row, right of TRACK, for the 🎁 DAILY and 👥 INVITE buttons (DailyRewardsClient
-- builds them inside these frames). They show and hide with the pair.
local icons=Instance.new('Frame');icons.Name='TopIcons';icons.BackgroundTransparency=1;icons.Visible=false;icons.Parent=gui
for i,name in ipairs({'Daily','Invite'})do local slot=Instance.new('Frame');slot.Name=name;slot.BackgroundTransparency=1;slot.LayoutOrder=i;slot.Parent=icons end
local connections={};local lastSent=0
-- R116: text-only buttons (pictures removed, owner request) with a stronger glossy highlight, a drop shadow and a
-- hover / press bounce.
local function make(name,caption,color,remote,order)
 local shadow=Instance.new('Frame');shadow.Name=name..'Shadow';shadow.BackgroundColor3=Color3.new(0,0,0);shadow.BackgroundTransparency=.55;shadow.BorderSizePixel=0;shadow.Active=false;shadow.ZIndex=9;shadow.Parent=holder
 local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,8);round.Parent=shadow
 local b=Instance.new('TextButton');b.Name=name;b.Text='';b.BorderSizePixel=0;b.ZIndex=10;b.LayoutOrder=order;b.Parent=holder
 Bright.Button(b,color);b:SetAttribute('AccessibleLabel',caption=='BASE'and'Teleport to your base'or'Teleport to the front of the track')
 local glass=b:FindFirstChild('GlassHighlight')
 if glass then glass.BackgroundTransparency=.6;glass.Size=UDim2.new(1,-6,.5,-3)end -- brighter top shine
 local bounce=Instance.new('UIScale');bounce.Name='Bounce';bounce.Parent=b
 local hovering,pressing,motion=false,false,nil
 local function settle()
  local target=pressing and .92 or hovering and 1.05 or 1
  if motion then motion:Cancel()end
  if GuiService.ReducedMotionEnabled then bounce.Scale=target;return end
  motion=Tween:Create(bounce,TweenInfo.new(pressing and .06 or .22,pressing and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=target});motion:Play()
 end
 local function pointer(input)return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA end
 connections[#connections+1]=b.MouseEnter:Connect(function()hovering=true;settle()end)
 connections[#connections+1]=b.MouseLeave:Connect(function()hovering=false;pressing=false;settle()end)
 connections[#connections+1]=b.InputBegan:Connect(function(input)if pointer(input)then pressing=true;settle()end end)
 connections[#connections+1]=b.InputEnded:Connect(function(input)if pointer(input)then pressing=false;settle()end end)
 local label=Instance.new('TextLabel');label.Name='Caption';label.Text=caption;label.BackgroundTransparency=1;label.TextXAlignment=Enum.TextXAlignment.Center;label.ZIndex=15;label.Parent=b
 Bright.Text(label,10)
 local shade=Instance.new('Frame');shade.Name='Cooldown';shade.BackgroundColor3=Color3.fromRGB(8,13,24);shade.BackgroundTransparency=.45;shade.BorderSizePixel=0;shade.AnchorPoint=Vector2.new(0,1);shade.Position=UDim2.fromScale(0,1);shade.Size=UDim2.fromScale(1,0);shade.Visible=false;shade.Active=false;shade.ZIndex=16;shade.Parent=b
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=shade
 connections[#connections+1]=b.Activated:Connect(function()
  if not holder.Visible then return end
  local now=os.clock();if now-lastSent<.3 then return end;lastSent=now
  remote:FireServer()
 end)
 return {Button=b,Shadow=shadow,Caption=label,Shade=shade}
end
local base=make('BaseButton','BASE',Color3.fromRGB(78,168,96),requestBase,1)
local track=make('TrackButton','TRACK',Color3.fromRGB(226,138,48),requestTrack,2)
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
 holder.Visible=pg:GetAttribute('TitleActive')~=true and pg:GetAttribute('SeedMenu')==nil;icons.Visible=holder.Visible
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
 -- R140: the DAILY / INVITE squares go right of TRACK. If they would reach Roblox's buttons, the pair narrows (not
 -- below 72), then the whole row slides left; with no room at all (screens under ~370 px) they drop to the left edge
 -- just under the row, where phones have nothing (the MENU button is at the left middle).
 local side=height;local iconsW=side*2+gap;local limit=right-8
 local function over()return centre+width+gap/2+gap+iconsW-limit end
 if over()>0 then width=math.max(72,width-math.ceil(over()/2))end
 if over()>0 and centre-over()-width-gap/2>=left+8 then centre-=over()end
 local iconX,iconY=centre+width+gap/2+gap,top+rowHeight/2-side/2
 if iconX+iconsW>limit then iconX=left+8;iconY=top+rowHeight+4 end
 icons.Position=UDim2.fromOffset(math.floor(iconX),math.floor(iconY));icons.Size=UDim2.fromOffset(iconsW,side)
 for i,name in ipairs({'Daily','Invite'})do local slot=icons[name];slot.Position=UDim2.fromOffset((i-1)*(side+gap),0);slot.Size=UDim2.fromOffset(side,side)end
 holder.AnchorPoint=Vector2.new(.5,.5);holder.Position=UDim2.fromOffset(math.floor(centre),math.floor(top+rowHeight/2));holder.Size=UDim2.fromOffset(width*2+gap,height)
 for i,entry in ipairs({base,track})do
  entry.Button.Size=UDim2.fromOffset(width,height);entry.Button.Position=UDim2.fromOffset((i-1)*(width+gap),0)
  entry.Shadow.Size=entry.Button.Size;entry.Shadow.Position=UDim2.fromOffset((i-1)*(width+gap),3)
  entry.Caption.Position=UDim2.fromOffset(6,0);entry.Caption.Size=UDim2.new(1,-12,1,0)
  local font=math.clamp(math.floor(height*.5),14,22);entry.Caption.TextSize=font;Fit.Attach(entry.Caption,font,10)
 end
 refresh()
end
local sized=gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout);task.defer(layout)
local inset=GuiService:GetPropertyChangedSignal('TopbarInset'):Connect(layout)
local function stopLayout()sized:Disconnect();inset:Disconnect()end
for _,key in ipairs({'TitleActive','SeedMenu'})do connections[#connections+1]=pg:GetAttributeChangedSignal(key):Connect(refresh)end
-- R150: arrival. The server writes FastTravelReadyAt (now + cooldown) right after it moves the character, so a rise to a time still in
-- the future is "you arrived": a short whoosh. A stale value at join, or the cooldown draining, never plays it.
local lastReady=tonumber(player:GetAttribute('FastTravelReadyAt'))or 0
connections[#connections+1]=player:GetAttributeChangedSignal('FastTravelReadyAt'):Connect(function()
 local ready=tonumber(player:GetAttribute('FastTravelReadyAt'))or 0
 local rose=ready-lastReady>.5 and ready>workspace:GetServerTimeNow();lastReady=ready
 if rose then Sfx.Play(Sfx.WhooshId,nil,.22,1.4,2)end
end)
for _,key in ipairs({'FastTravelReadyAt','ChestChaseSeedCarrying','ChestChaseRunActive','TreadmillTraining','GuardianRagdollActive','GuardianFlingActive'})do connections[#connections+1]=player:GetAttributeChangedSignal(key):Connect(paint)end
paint();refresh()
gui.Destroying:Connect(function()
 stopLayout();if cooling then cooling:Disconnect();cooling=nil end
 for _,c in ipairs(connections)do c:Disconnect()end;table.clear(connections)
end)
