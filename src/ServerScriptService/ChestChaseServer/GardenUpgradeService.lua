-- Server-owned transactions. Two anchored buttons per base, animated only on a press.
local RS=game:GetService('ReplicatedStorage');local Tween=game:GetService('TweenService')
local Rules=require(RS:WaitForChild('GardenFenceRules'));local Art=require(script.Parent.GardenFenceArt)
local U={};local V,CF=Vector3.new,CFrame.new;local RGB=Color3.fromRGB
local function cash(n)
 local str=tostring(math.floor(n));local formatted=str:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','');return '$'..formatted
end
local function part(parent,name,size,frame,color)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
function U.Clear(self,record)
 self.GardenUpgradeRecords=self.GardenUpgradeRecords or{}
 local state=self.GardenUpgradeRecords[record.Index];if state then
  for _,c in ipairs(state.Connections)do c:Disconnect()end
  if state.Model then state.Model:Destroy()end;self.GardenUpgradeRecords[record.Index]=nil
 end
end
function U.CanPress(self,player,record,cap)
 local char=player and player.Character;local root=char and char:FindFirstChild('HumanoidRootPart');local hum=char and char:FindFirstChildOfClass('Humanoid')
 return record and self.BaseOwners[record.Index]==player and self:GetPlayerBase(player)==record and root and hum and hum.Health>0
  and cap and cap.Parent and(root.Position-cap.Position).Magnitude<=12 and self.PlayerData:IsLoaded(player)
  and not self.BusyChecker(player)and not player:GetAttribute('GuardianRagdollActive')
end
function U.Refresh(self,player)
 local record=self:GetPlayerBase(player);if not record then return end
 U.Clear(self,record);local tier=self.PlayerData:GetFenceTier(player);Art.Build(record.Model,tier)
 local model=Instance.new('Model');model.Name='GardenUpgradeButtons';model:SetAttribute('OwnerUserId',player.UserId);model.Parent=record.Model
 local state={Model=model,Connections={},Buttons={},Busy=false};self.GardenUpgradeRecords[record.Index]=state
 local pad=record.Model.Pad;local origin=pad.CFrame*CF(0,pad.Size.Y/2,0)
 local function connect(signal,fn)table.insert(state.Connections,signal:Connect(fn))end
 for i,kind in ipairs({'Treadmill','Fence'})do
  local pos=CF(-49,.75,68.5+(i-1)*11.5)
  part(model,kind..' housing',V(10.4,1.5,10.4),origin*pos,RGB(47,62,55))
  local cap=part(model,kind..' button',V(9.6,.55,9.6),origin*pos*CF(0,.90,0),RGB(67,185,98));cap:SetAttribute('GardenUpgradeKind',kind)
  local home=cap.CFrame;local surface=Instance.new('SurfaceGui');surface.Name='ButtonLabel';surface.Face=Enum.NormalId.Top;surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;surface.CanvasSize=Vector2.new(512,512);surface.LightInfluence=0;surface.MaxDistance=100;surface.Parent=cap
  local function lettering(name,text,y,height,maxSize,minSize,font)
   local label=Instance.new('TextLabel');label.Name=name;label.Size=UDim2.new(1,-40,0,height);label.Position=UDim2.fromOffset(20,y);label.BackgroundTransparency=1;label.Text=text;label.Font=font;label.TextScaled=true;label.TextWrapped=true;label.TextColor3=RGB(255,255,239);label.TextStrokeTransparency=.7;label.Parent=surface
   local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=maxSize;fit.MinTextSize=minSize;fit.Parent=label;return label
  end
  lettering('Action','UPGRADE\n'..kind:upper(),32,154,53,34,Enum.Font.FredokaOne)
  local price=lettering('Price','',208,116,82,32,Enum.Font.FredokaOne)
  local note=lettering('Hint','',380,84,30,18,Enum.Font.FredokaOne);note.Visible=false
  local click=Instance.new('ClickDetector');click.MaxActivationDistance=12;click.Parent=cap
  local prompt=Instance.new('ProximityPrompt');prompt.Name='UpgradePress';prompt.Style=Enum.ProximityPromptStyle.Custom;prompt.ActionText='UPGRADE';prompt.ObjectText='';prompt.KeyboardKeyCode=kind=='Fence'and Enum.KeyCode.R or Enum.KeyCode.E;prompt.GamepadKeyCode=kind=='Fence'and Enum.KeyCode.ButtonY or Enum.KeyCode.ButtonX;prompt.MaxActivationDistance=9;prompt.RequiresLineOfSight=false;prompt.HoldDuration=0;prompt:SetAttribute('GardenUpgradeOwner',player.UserId);prompt.Parent=cap
  state.Buttons[kind]={Cap=cap,Price=price,Note=note,Prompt=prompt,Home=home}
  local function press(sender)
   if state.Busy or not U.CanPress(self,sender,record,cap)then return end
   local now=os.clock();self.GardenUpgradeLast=self.GardenUpgradeLast or setmetatable({},{__mode='k'})
   if now-(self.GardenUpgradeLast[sender]or -math.huge)<.65 then return end;self.GardenUpgradeLast[sender]=now;state.Busy=true
   sender:SetAttribute('UpgradePressSerial',(sender:GetAttribute('UpgradePressSerial')or 0)+1)
   local row=state.Buttons[kind];local expected=row.Expected
   local okay,message
   if not expected then okay=false;message='Fully upgraded!'
   elseif kind=='Fence'then okay,message=self.PlayerData:BuyFence(sender,expected)
   else okay,message=self.PlayerData:BuyTreadmill(sender,expected)end
   -- Even a rejected purchase gives a short tactile press without a debit.
   Tween:Create(cap,TweenInfo.new(.10,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=home*CF(0,-.35,0)}):Play()
   task.delay(.12,function()if cap.Parent then Tween:Create(cap,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=home}):Play()end end)
   if not okay then note.Text=message or'Try again';note.Visible=true end
   task.delay(.34,function()
    if self.GardenUpgradeRecords[record.Index]~=state then return end
    state.Busy=false
    if okay then
     if kind=='Treadmill'then self:RefreshTreadmill(sender)else U.Refresh(self,sender)end
    end
   end)
  end
  connect(click.MouseClick,press);connect(prompt.Triggered,press)
 end
 local function paint()
  local balance=self.PlayerData:GetCash(player)
  for kind,b in pairs(state.Buttons)do
   local current=kind=='Fence'and self.PlayerData:GetFenceTier(player)or self.PlayerData:GetTreadmillData(player).Tier
   local nextTier=kind=='Fence'and Rules.Tiers[current+1]or self.Config.TreadmillTiers[current+1]
   b.Expected=nextTier and current+1 or nil
   local unlocked=true
   local affordable=nextTier and balance>=nextTier.Cost
   b.Cap.Color=not nextTier and RGB(101,124,108)or affordable and unlocked and RGB(67,185,98)or RGB(200,66,65)
   b.Cap:SetAttribute('Affordable',affordable==true);b.Cap:SetAttribute('NextTier',b.Expected);b.Cap:SetAttribute('Price',nextTier and nextTier.Cost or 0)
   b.Price.Text=nextTier and cash(nextTier.Cost)or'MAX'
   b.Note.Text='';b.Note.Visible=false
   b.Prompt.Enabled=nextTier~=nil
  end
 end
 connect(self.PlayerData:GetOrCreateCashValue(player):GetPropertyChangedSignal('Value'),paint)
 connect(player:GetAttributeChangedSignal('TreadmillTier'),paint);connect(player:GetAttributeChangedSignal('FenceTier'),paint)
 connect(player:GetAttributeChangedSignal('DataStatus'),paint);connect(player:GetAttributeChangedSignal('TreadmillUnlockRevision'),paint)
 paint()
end
return U
