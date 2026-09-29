-- R66: one event-driven Speed / Cash / Gems dock; saved numbers and hover claims stay authoritative.
local RS=game:GetService('ReplicatedStorage');local Numbers=require(RS.CashNumbers);local Theme=require(RS.GardenTheme)
local Tween=game:GetService('TweenService');local Wallet={};Wallet.__index=Wallet
local C=Color3.fromRGB
function Wallet.new(parent)
 local player=game:GetService('Players').LocalPlayer;local pg=parent.Parent;local connections={};local self
 local function row(name,color,kind,page)
  local root=Instance.new(kind=='Gems'and'TextButton'or'Frame');root.Name=name;root.BackgroundTransparency=1;root.BorderSizePixel=0;root.ZIndex=50;root.Parent=parent
  root:SetAttribute('AccessibleLabel',kind)
  if kind=='Gems'then root.Text='';root.AutoButtonColor=false;root:SetAttribute('ButtonHighlight',false)
   table.insert(connections,root.Activated:Connect(function()require(RS.InteractionAudio).Play('Bubble04');pg:SetAttribute('PremiumPage','Gems');pg:SetAttribute('SeedMenu','Passes')end))
  end
  local icon=kind=='Cash'and require(RS.MoneyIcon).new(root)or kind=='Gems'and require(RS.GemIcon).new(root)or require(RS.PremiumEmblems).Draw(root,'Bolt')
  local scale=Instance.new('UIScale');scale.Parent=icon
  local amount=Instance.new('TextLabel');amount.Name=kind=='Gems'and'GemAmount'or'Amount';amount.BackgroundTransparency=1;amount.TextXAlignment=Enum.TextXAlignment.Left;amount.ZIndex=52;Theme.Text(amount,40,true,color);amount.TextStrokeColor3=C(0,0,0);amount.TextStrokeTransparency=0;amount.Parent=root
  local amountScale=Instance.new('UIScale');amountScale.Name='Jump';amountScale.Parent=amount
  local ink=Instance.new('UIStroke');ink.Name='NumberOutline';ink.Color=C(0,0,0);ink.Thickness=2;ink.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;ink.Parent=amount
  local plus=Instance.new('TextButton');plus.Name='More'..kind;plus.Text='+';plus.TextSize=28;plus.BorderSizePixel=0;plus.ZIndex=53;plus.Parent=root;require(RS.BrightUI).Button(plus,C(255,213,65));plus:SetAttribute('AccessibleLabel',kind=='Gems'and'Convert Cash to Gems'or'Buy '..kind)
  local function buy()pg:SetAttribute('PremiumPage',page);pg:SetAttribute('PremiumFocus',kind);pg:SetAttribute('SeedMenu','Passes')end
  table.insert(connections,plus.Activated:Connect(buy))
  local compactTap=Instance.new('TextButton');compactTap.Name='CompactPurchase';compactTap.Text='';compactTap.BackgroundTransparency=1;compactTap.Size=UDim2.fromScale(1,1);compactTap.ZIndex=53;compactTap.Visible=false;compactTap.Parent=root
  compactTap:SetAttribute('AccessibleLabel','Buy '..kind);compactTap:SetAttribute('ButtonHighlight',false)
  table.insert(connections,compactTap.Activated:Connect(buy))
  return setmetatable({Root=root,Amount=amount,AmountScale=amountScale,Icon=icon,IconScale=scale,More=plus,CompactTap=compactTap,Kind=kind,LastPulse=-math.huge},Wallet)
 end
 self=row('CashHud',C(114,255,57),'Cash','Cash');self.Gems=row('GemHud',C(115,222,255),'Gems','Gems');self.Speed=row('SpeedHud',C(255,255,255),'Speed','Speed')
 local rows={self.Speed,self,self.Gems};local dead=false
 local function layout(m)
  local shared=require(RS.HudLayout)
  m=m or shared.Read(shared.Viewport(parent),game:GetService('UserInputService').TouchEnabled,shared.Controls(parent))
  for i,r in ipairs(rows)do
   r.Root.Position=UDim2.fromOffset(({m.SpeedX or m.WalletX,m.CashX or m.WalletX,m.GemX or m.WalletX})[i],({m.SpeedY,m.CashY,m.GemY})[i]);r.Root.Size=UDim2.fromOffset(m.WalletWidth,m.WalletHeight)
   local side=m.WalletIcon or m.WalletHeight;local plus=m.WalletPlus or math.min(36,math.max(16,math.floor(side*.78)))
   r.Icon.Position=UDim2.fromOffset(0,(m.WalletHeight-side)/2);r.Icon.Size=UDim2.fromOffset(side,side)
   r.More.Size=UDim2.fromOffset(plus,plus);r.More.Position=UDim2.new(1,-plus,.5,-plus*.5);r.More.TextSize=math.min(28,plus)
   r.More.Visible=not m.WalletCompactTap;r.CompactTap.Visible=m.WalletCompactTap==true
   r.Amount.AnchorPoint=Vector2.new(0,.5);r.Amount.Position=UDim2.new(0,side+5,.5,0);r.Amount.Size=UDim2.new(1,-side-(m.WalletCompactTap and 8 or plus+12),1,0)
   local font=m.WalletFont or math.min(42,math.floor(side*.8));require(RS.GardenTextFit).Attach(r.Amount,font,m.Phone and 16 or math.max(10,math.floor(font*.7)))
   r.Root.Visible=pg:GetAttribute('SeedMenu')==nil
  end
 end
 local function watch(signal,fn)connections[#connections+1]=signal:Connect(fn)end
 watch(player:GetAttributeChangedSignal('Gems'),function()self.Gems:SetValue(player:GetAttribute('Gems')or 0)end)
 -- Bind the exact runtime stat, never the rounded PlayerList display string.
 local leaderConnections={};local speedConnection;local leader
 local function bindSpeed()
  if speedConnection then speedConnection:Disconnect();speedConnection=nil end
  local value=leader and leader:FindFirstChild('Speed')
  -- R112: the speed number jumps every time it goes up.
  local shown=value and value.Value or 0
  -- Speed is a big-number string, so compare with SpeedPoints rather than as text.
  local function gained(now,before)local ok,diff=pcall(function()local P=require(RS.SpeedPoints);return P.Compare(P.Normalize(now),P.Normalize(before))end);return ok and diff>0 end
  local function update()if dead then return end;local now=value and value.Value or 0;self.Speed:SetValue(now);if gained(now,shown)then self.Speed:Jump()end;shown=now end
  if value then speedConnection=value:GetPropertyChangedSignal('Value'):Connect(update)end;update()
 end
 local function bindLeader()
  for _,c in ipairs(leaderConnections)do c:Disconnect()end;table.clear(leaderConnections)
  leader=player:FindFirstChild('ChestChaseStats')
  if leader then
   leaderConnections[1]=leader.ChildAdded:Connect(function(child)if child.Name=='Speed'then bindSpeed()end end)
   leaderConnections[2]=leader.ChildRemoved:Connect(function(child)if child.Name=='Speed'then bindSpeed()end end)
  end
  bindSpeed()
 end
 watch(player.ChildAdded,function(child)if child.Name=='ChestChaseStats'then bindLeader()end end)
 watch(player.ChildRemoved,function(child)if child.Name=='ChestChaseStats'then bindLeader()end end)
 watch(pg:GetAttributeChangedSignal('SeedMenu'),layout)
 local stopLayout=require(RS.HudLayout).Watch(parent,layout)
 watch(self.Root.Destroying,function()
  if dead then return end;dead=true;stopLayout()
  if speedConnection then speedConnection:Disconnect()end
  for _,c in ipairs(leaderConnections)do c:Disconnect()end;for _,c in ipairs(connections)do c:Disconnect()end
  for _,r in ipairs(rows)do r.Destroyed=true;if r.PulseTween then r.PulseTween:Cancel()end;if r.JumpTween then r.JumpTween:Cancel()end end
  self.Gems.Root:Destroy();self.Speed.Root:Destroy()
 end)
 self:SetValue(0);self.Gems:SetValue(player:GetAttribute('Gems')or 0);bindLeader();layout();return self
end
function Wallet:SetValue(value)
 local content=(self.Kind=='Cash'and'$'or'')..Numbers.Compact(value)
 if self.Amount.Text~=content then self.Amount.Text=content end
 self.Root:SetAttribute('ExactCash',Numbers.Exact(value));self.Root:SetAttribute('AccessibleLabel',(self.Kind or'Cash')..' '..Numbers.Exact(value))
end
function Wallet:Jump()
 if self.Destroyed or game:GetService('GuiService').ReducedMotionEnabled or os.clock()-(self.LastJump or -1)<.12 then return end
 self.LastJump=os.clock();if self.JumpTween then self.JumpTween:Cancel()end
 self.AmountScale.Scale=1.35;self.JumpTween=Tween:Create(self.AmountScale,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1});self.JumpTween:Play()
end
function Wallet:TargetPosition()return self.Icon.AbsolutePosition+self.Icon.AbsoluteSize*.5 end
function Wallet:Pulse()
 if self.Destroyed or game:GetService('GuiService').ReducedMotionEnabled or os.clock()-self.LastPulse<.10 then return end
 self.LastPulse=os.clock();if self.PulseTween then self.PulseTween:Cancel()end
 self.IconScale.Scale=1.13;self.PulseTween=Tween:Create(self.IconScale,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1});self.PulseTween:Play()
end
return Wallet
