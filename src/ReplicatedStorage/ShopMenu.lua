-- R70: readable values with an explicit benefit; no extra item descriptions.
local RS=game:GetService('ReplicatedStorage');local Theme=require(RS:WaitForChild('GardenTheme'));local Style=require(RS:WaitForChild('GardenMenuStyle'))
local Cash=require(RS:WaitForChild('CashNumbers'));local Preview=require(RS:WaitForChild('ShopViewport'));local Art=require(RS:WaitForChild('ShopProductArt'));local Motion=require(RS:WaitForChild('GardenCardMotion'))
local M={};M.__index=M;local C=Theme.Colors
local function label(parent,name,content,pos,size,font,bold,color)
 local t=Instance.new('TextLabel');t.Name=name;t.Text=content;t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.BorderSizePixel=0;t.TextWrapped=true;t.TextXAlignment=Enum.TextXAlignment.Left
 require(RS.BrightUI).Text(t,font,color);t.Parent=parent;return t
end
local function button(parent,name,content,pos,size)
 local b=Instance.new('TextButton');b.Name=name;b.Text=content;b.Position=pos;b.Size=size;b.BorderSizePixel=0;b.BackgroundColor3=C.Mint;b.TextWrapped=true;b.TextSize=22;require(RS.BrightUI).Button(b,C.Mint);b.Parent=parent;return b
end
function M.Layout(width,trail)
 local narrow=width<540
 return {Narrow=narrow,Height=narrow and 178 or 154,Preview=narrow and 90 or 120,Left=narrow and 118 or 150,Right=narrow and 12 or 154}
end
function M.Action(product,cash,busy)
 cash=cash or 0
 if busy then return 'Please wait',false end
 if product.Owned then return product.Equipped and'Unequip'or'Equip',true end
 if product.Enabled==false then return product.UnavailableReason or'Coming soon',false end
 if (cash or 0)<(product.Price or 0)then return 'Need $'..Cash.Compact(product.Price-cash),false end
 return 'Buy  $'..Cash.Compact(product.Price),true
end
function M.Description(product)
 return ''
end
function M.new(parent,onTab,onPurchase,onEquip)
 local self=setmetatable({Rows={},Connections={},TabButtons={},OnPurchase=onPurchase,OnEquip=onEquip},M)
 local root=Instance.new('Frame');root.Name='ShopMenu';root.BackgroundTransparency=1;root.BorderSizePixel=0;root.Visible=false;root.Parent=parent;self.Root=root
 local tabs=Instance.new('Frame');tabs.Name='ShopTabs';tabs.Size=UDim2.new(1,0,0,40);tabs.BackgroundTransparency=1;tabs.Parent=root
 for i,entry in ipairs({{'Trails','Trails'},{'Accessories','Boots'}})do
  local b=button(tabs,entry[1],entry[2],UDim2.new((i-1)/2,(i-1)*4,0,0),UDim2.new(1/2,-4,1,0));self.TabButtons[entry[1]]=b
  table.insert(self.Connections,b.Activated:Connect(function()if self.Root.Visible and not self.Busy then onTab(entry[1])end end))
 end
 local list=Instance.new('ScrollingFrame');list.Name='ProductRows';list.Position=UDim2.fromOffset(0,50);list.Size=UDim2.new(1,0,1,-50);list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.ScrollBarImageColor3=C.Mint;list.CanvasSize=UDim2.new();list.CanvasPosition=Vector2.zero;list.ClipsDescendants=true;list.Parent=root;self.List=list
 self.Empty=label(list,'Empty','Loading shop…',UDim2.fromOffset(12,12),UDim2.new(1,-24,0,50),15,false,C.Muted);self.Empty.TextXAlignment=Enum.TextXAlignment.Center
 table.insert(self.Connections,list:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:Render()end))
 return self
end
function M:Clear()
 for _,r in ipairs(self.Rows)do r.Frame:Destroy()end;self.Rows={};self.Key=nil
end
function M:MakeRow(product,index,layout)
 local accent=Art.Color(product);local row=Instance.new('Frame');row.Name=product.Id;row.Position=UDim2.fromOffset(1,(index-1)*layout.Height+1);row.Size=UDim2.new(1,-7,0,layout.Height-9);row.BackgroundColor3=C.Card;row.BorderSizePixel=0;row.Parent=self.List
 require(RS.BrightUI).Card(row,accent,false);Style.Accent(row,accent)
 local view=Instance.new('ViewportFrame');view.Name='RotatingProduct';view.Position=UDim2.fromOffset(12,12);view.Size=UDim2.fromOffset(layout.Preview,layout.Preview);view.BorderSizePixel=0;view.Ambient=Color3.fromRGB(185,193,190);view.LightColor=Color3.fromRGB(255,244,220);view.LightDirection=Vector3.new(-1,-1,-1);view.Parent=row;Theme.Corner(view,8);Style.Inset(view)
 Preview.Attach(view,product,self.State.BootBiome or'Forest')
 local left,right=layout.Left,layout.Right
 label(row,'Name',product.Name,UDim2.fromOffset(left,10),UDim2.new(1,-left-right,0,layout.Narrow and 47 or 38),layout.Narrow and 22 or 27,true,C.Text)
 local boost='×'..tostring(product.SpeedMultiplier or product.LuckMultiplier or 1)
 local benefit=label(row,'Benefit',boost,UDim2.fromOffset(left,layout.Narrow and 56 or 52),UDim2.new(1,-left-right,0,49),layout.Narrow and 37 or 44,true,accent)
 local benefitType=label(row,'BenefitType',product.SpeedMultiplier and'Speed gain'or'Pack luck',UDim2.fromOffset(left,layout.Narrow and 102 or 103),UDim2.new(1,-left-right,0,25),layout.Narrow and 20 or 22,true,C.Text)
 require(RS.GardenTextFit).Attach(benefitType,layout.Narrow and 20 or 22,18)
 local desc=nil
 require(RS.GardenTextFit).Attach(row:FindFirstChild('Name'),layout.Narrow and 22 or 27,18)
 local b=button(row,'Purchase','',layout.Narrow and UDim2.new(0,12,1,-50)or UDim2.new(1,-144,.5,-27),layout.Narrow and UDim2.new(1,-24,0,40)or UDim2.fromOffset(132,54))
 local record={Frame=row,Action=b,Product=product,View=view,Benefit=benefit,Description=desc}
 b.Activated:Connect(function()
  local _,allowed=M.Action(record.Product,self.State and self.State.Cash or 0,self.Busy)
  if not self.Root.Visible or not allowed then return end
  self.Busy=true;self:Render()
  local ok,err
  if record.Product.Owned then ok,err=pcall(self.OnEquip,record.Product.Id,not record.Product.Equipped)
  else ok,err=pcall(self.OnPurchase,record.Product.Id)end
  self.Busy=false;self:Render()
  if not ok then warn('[R49 Shop] '..tostring(err))end
 end)
 return record
end
function M:Render()
 if not self.Root.Visible or self.Rendering then return end;self.Rendering=true
 local state=self.State or{};local products=state.Products and state.Products[self.Tab]or{};local layout=M.Layout(self.List.AbsoluteSize.X,self.Tab=='Trails')
 local ids={self.Tab or'',tostring(layout.Narrow),state.BootBiome or'Forest'};for _,p in ipairs(products)do table.insert(ids,p.Id)end
 local key=table.concat(ids,'|')
 if key~=self.Key then self:Clear();self.Key=key;for i,p in ipairs(products)do self.Rows[i]=self:MakeRow(p,i,layout)end end
 self.Empty.Visible=#products==0;self.Empty.Text=self.State and'No items yet.'or'Loading shop…'
 local canvas=#products*layout.Height;self.List.CanvasSize=UDim2.fromOffset(0,canvas)
 local y=math.clamp(self.List.CanvasPosition.Y,0,math.max(0,canvas-self.List.AbsoluteSize.Y));if y~=self.List.CanvasPosition.Y then self.List.CanvasPosition=Vector2.new(0,y)end
 for i,r in ipairs(self.Rows)do
  r.Product=products[i];local caption,enabled=M.Action(r.Product,state.Cash or 0,self.Busy)
  r.Action.Text=caption;r.Action.Active=enabled;r.Action.AutoButtonColor=enabled;require(RS.BrightUI).Button(r.Action,enabled and Color3.fromRGB(43,177,106)or Color3.fromRGB(68,83,122));r.Action.TextColor3=C.Text;r.Action.Interactable=enabled
  r.Action:SetAttribute('ExactCash',Cash.Exact(r.Product.Price or 0))
 end
 self.Rendering=false
end
function M:Show(state,tab)
 tab=self.TabButtons[tab]and tab or'Trails'
 self.State=state;self.Tab=tab;self.Root.Visible=true
 local compact=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y<480
 self.Root.Position=UDim2.fromOffset(16,compact and 94 or 122);self.Root.Size=UDim2.new(1,-32,1,compact and -124 or -152)
 for name,b in pairs(self.TabButtons)do local active=name==tab;require(RS.BrightUI).Button(b,active and Color3.fromRGB(43,177,106)or Color3.fromRGB(64,86,154));b.TextColor3=C.Text end
 self:Render()
end
function M:Hide()self.Root.Visible=false;self:Clear()end
function M:Destroy()self:Clear();for _,c in ipairs(self.Connections)do c:Disconnect()end;self.Root:Destroy()end
return M
