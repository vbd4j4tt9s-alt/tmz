local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players')
local Bright=require(RS.BrightUI);local Theme=require(RS.GardenTheme);local Mech=require(RS.MechCatalog)
local D={}
function D.Create(parent,player,act,stateFor,infoFor)
 local self={Selected=nil,Pass=nil,Pending=nil}
 local veil=Instance.new('TextButton');veil.Name='GiftVeil';veil.Text='';veil.BackgroundColor3=Color3.new();veil.BackgroundTransparency=.35;veil.Size=UDim2.fromScale(1,1);veil.ZIndex=19;veil.Visible=false;veil.Parent=parent
 local panel=Instance.new('Frame');panel.Name='PassGiftPicker';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.new(.94,0,.92,0);panel.ZIndex=20;panel.Active=true;panel.Visible=false;panel.BorderSizePixel=0;panel.Parent=parent;Bright.Panel(panel)
 local max=Instance.new('UISizeConstraint');max.MaxSize=Vector2.new(460,490);max.Parent=panel
 local title=Instance.new('TextLabel');title.Text='Gift a pass';title.Position=UDim2.fromOffset(14,9);title.Size=UDim2.new(1,-70,0,58);title.BackgroundTransparency=1;title.ZIndex=22;title.TextWrapped=true;Bright.Text(title,24);title.Parent=panel
 local function button(name,caption,pos,size,color)
  local b=Instance.new('TextButton');b.Name=name;b.Text=caption;b.TextSize=18;b.TextWrapped=true;b.Position=pos;b.Size=size;b.ZIndex=23;b.BorderSizePixel=0;b.Parent=panel;Bright.Button(b,color or Theme.Colors.Mint);return b
 end
 local close=button('CloseGift','X',UDim2.new(1,-48,0,12),UDim2.fromOffset(36,36),Color3.fromRGB(248,78,106))
 local list=Instance.new('ScrollingFrame');list.Name='Recipients';list.Position=UDim2.fromOffset(12,74);list.Size=UDim2.new(1,-24,1,-235);list.CanvasSize=UDim2.new();list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.ZIndex=22;list.Parent=panel
 local feedback=Instance.new('TextLabel');feedback.Name='GiftStatus';feedback.Text='';feedback.Position=UDim2.new(0,12,1,-155);feedback.Size=UDim2.new(1,-24,0,34);feedback.BackgroundTransparency=1;feedback.TextWrapped=true;feedback.ZIndex=23;Bright.Text(feedback,15,Theme.Colors.Gold);feedback.Parent=panel
 local gem=button('GiftWithGems','Gems',UDim2.new(0,12,1,-113),UDim2.new(1,-24,0,44),Color3.fromRGB(166,111,255))
 local robux=button('GiftWithRobux','Robux',UDim2.new(0,12,1,-61),UDim2.new(1,-24,0,44),Color3.fromRGB(141,241,45))
 function self:Close()self.Pending=nil;panel.Visible=false;veil.Visible=false end
 local function send(payment)
  if not self.Pass or not self.Selected then return end
  act('GiftPass',{Key=self.Pass.Key,RecipientId=self.Selected,Payment=payment},function(result)if result and result.Success then self:Close()else feedback.Text=result and result.Message or'Please try again.'end end)
 end
 function self:Refresh()
  if not panel.Visible or not self.Pass then return end
  local state=stateFor();local credit=(state.GiftCredits or{})[self.Pass.Key]or 0
  local available=(state.GiftProducts or{})[self.Pass.Key];local info=infoFor(self.Pass.Key)
  local ready=available and available.Available and info and info.PriceInRobux and info.IsForSale~=false
  gem.Text=Mech.PassGemPrices[self.Pass.Key]..' Gems';robux.Text=credit>0 and('Send gift · '..credit..' ready')or ready and(info.PriceInRobux..' Robux')or'Unavailable'
  gem.Interactable=self.Selected~=nil;robux.Interactable=self.Selected~=nil and(credit>0 or ready==true)
  if self.Pending and credit>self.Pending.Before then
   local pending=self.Pending;self.Pending=nil
   -- Selection is never silently redirected if a recipient leaves or the dialog closes.
   if pending.Key==self.Pass.Key and pending.UserId==self.Selected then send('Credit')end
  end
 end
 local function recipients()
  for _,c in ipairs(list:GetChildren())do c:Destroy()end
  local n=0
  for _,p in ipairs(Players:GetPlayers())do if p~=player then
   local b=button('Recipient',p.DisplayName..'  @'..p.Name,UDim2.fromOffset(0,n*52),UDim2.new(1,-6,0,44),p.UserId==self.Selected and Theme.Colors.Mint or Theme.Colors.Card);b.Parent=list;n+=1
   b.Activated:Connect(function()self.Selected=p.UserId;self.Pending=nil;feedback.Text='';recipients();self:Refresh()end)
  end end
  list.CanvasSize=UDim2.fromOffset(0,n*52)
  if n==0 then local t=Instance.new('TextLabel');t.Text='No other players here';t.Size=UDim2.new(1,0,0,50);t.BackgroundTransparency=1;t.ZIndex=23;Bright.Text(t,18);t.Parent=list end
 end
 function self:Open(pass)feedback.Text='';self.Pass=pass;self.Selected=nil;self.Pending=nil;title.Text='Gift '..pass.Name;veil.Visible=true;panel.Visible=true;recipients();self:Refresh()end
 function self:IsOpen()return panel.Visible end
 close.Activated:Connect(function()self:Close()end);veil.Activated:Connect(function()self:Close()end)
 gem.Activated:Connect(function()if gem.Interactable then send('Gems')end end)
 robux.Activated:Connect(function()
  if not robux.Interactable or not self.Selected then return end
  local key=self.Pass.Key;local userId=self.Selected;local credit=(stateFor().GiftCredits or{})[key]or 0
  if credit>0 then send('Credit');return end
  act('RobuxGift',key,function(result)
   if result and result.Success and panel.Visible and self.Pass.Key==key and self.Selected==userId then self.Pending={Key=key,UserId=userId,Before=credit};self:Refresh()elseif panel.Visible then feedback.Text=result and result.Message or'Please try again.'end
  end)
 end)
 local added=Players.PlayerAdded:Connect(function()if panel.Visible then recipients()end end)
 local removed=Players.PlayerRemoving:Connect(function(p)if self.Selected==p.UserId then self.Selected=nil;self.Pending=nil end;if panel.Visible then recipients();self:Refresh()end end)
 panel.Destroying:Connect(function()added:Disconnect();removed:Disconnect()end)
 return self
end
return D
