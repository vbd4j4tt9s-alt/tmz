local RS=game:GetService('ReplicatedStorage');local Preview=require(RS:WaitForChild('HarvestViewport'));local Cash=require(RS:WaitForChild('CashNumbers'));local Theme=require(RS:WaitForChild('GardenTheme'));local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Style=require(RS:WaitForChild('GardenMenuStyle'))
local Filters=require(RS:WaitForChild('CropFilters'));local Numbers=require(RS:WaitForChild('SizeNumbers'));local Traits=require(RS.ItemTraitNames)
local Weight=require(RS:WaitForChild('ItemWeight')) -- R112: sizes read as kg.
local Menu={};Menu.__index=Menu;local C=Theme.Colors
local function text(parent,name,content,pos,size,font,bold,color)
 local x=Instance.new('TextLabel');x.Name=name;x.Text=content;x.Position=pos;x.Size=size;x.BackgroundTransparency=1;x.TextWrapped=true;x.TextXAlignment=Enum.TextXAlignment.Left;require(RS.BrightUI).Text(x,font or 18,color);x.Parent=parent;return x
end
local function button(parent,name,content,pos,size)
 local b=Instance.new('TextButton');b.Name=name;b.Text=content;b.Position=pos;b.Size=size;b.BorderSizePixel=0;b.BackgroundColor3=C.Mint;b.TextWrapped=true;b.TextSize=22;require(RS.BrightUI).Button(b,C.Mint);b.Parent=parent;return b
end
local function key(item,index)return tostring(item.InventoryId or index)end
local function visualKey(item)
 local v=item.VisualCrop or item
 return table.concat({item.SeedId or'',item.Mutation or'None',item.Weather or'None',v.SourceCropId or v.Id or item.InventoryId or'',v.FruitIndex or 1,v.HarvestCycle or 0},'|')
end
function Menu.new(parent,onSell)
 local self=setmetatable({Rows={},ById={},Data={},Connections={},OnSell=onSell},Menu)
 local root=Instance.new('Frame');root.Name='HarvestSellMenu';root.Position=UDim2.fromOffset(16,82);root.Size=UDim2.new(1,-32,1,-112);root.BackgroundTransparency=1;root.BorderSizePixel=0;root.Visible=false;root.Parent=parent;self.Root=root
 local total=Instance.new('Frame');total.Name='BagSummary';total.BackgroundColor3=C.Card;total.BorderSizePixel=0;total.Size=UDim2.new(1,0,0,52);total.Parent=root;self.SummaryBox=total;Theme.Corner(total,10);Style.Inset(total)
 self.Summary=text(total,'Summary','YOUR HARVESTS',UDim2.fromOffset(12,3),UDim2.new(1,-156,1,-6),20,true,C.Text)
 require(RS.GardenTextFit).Attach(self.Summary,20,12)
 self.All=button(total,'SellAll','Sell all',UDim2.new(1,-138,0,6),UDim2.fromOffset(132,40))
 table.insert(self.Connections,self.All.Activated:Connect(function()if self.State and self.State.CanSell and #(self.State.Harvests or{})>0 then onSell('ALL',self.All.AbsolutePosition+self.All.AbsoluteSize*.5)end end))
 local list=Instance.new('ScrollingFrame');list.Name='HarvestRows';list.Position=UDim2.fromOffset(0,62);list.Size=UDim2.new(1,0,1,-62);list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.ScrollBarImageColor3=C.Mint;list.CanvasSize=UDim2.new();list.ClipsDescendants=true;list.Parent=root;self.List=list
 self.Empty=text(list,'Empty','No crops',UDim2.fromOffset(18,12),UDim2.new(1,-36,0,70),16,false,C.Muted);self.Empty.TextXAlignment=Enum.TextXAlignment.Center
 local search=Instance.new('TextBox');search.Name='CropSearch';search.PlaceholderText='Search crops…';search.Text='';search.ClearTextOnFocus=false;search.Size=UDim2.new(1,0,0,32);search.Position=UDim2.fromOffset(0,58);search.BackgroundColor3=C.Card;search.BorderSizePixel=0;Theme.Text(search,18,false,C.Text);Theme.Corner(search,7);search.Parent=root;self.Search=search
 local controls=Instance.new('ScrollingFrame');controls.Name='HarvestControls';controls.BackgroundTransparency=1;controls.BorderSizePixel=0;controls.ScrollBarThickness=4;controls.ScrollBarImageColor3=C.Mint;controls.ScrollingDirection=Enum.ScrollingDirection.Y;controls.CanvasSize=UDim2.new();controls.ClipsDescendants=true;controls.Visible=false;controls.Parent=root;self.Controls=controls
 self.FilterButtons={};self.FilterIndex={1,1,1};self.Mutated=false
 local choices={Filters.Rarities,Filters.Kinds,Filters.Sorts}
 local function update(reset)self.Filtered=Filters.Apply(self.State and self.State.Harvests or{},search.Text,Filters.Rarities[self.FilterIndex[1]],Filters.Kinds[self.FilterIndex[2]],self.Mutated,Filters.Sorts[self.FilterIndex[3]]);self.ViewKey=nil;if reset~=false then self.List.CanvasPosition=Vector2.zero end;self:Render(true)end
 self.ApplyFilters=update
 for i=1,4 do
  local b=button(root,'Filter'..i,i==4 and'All mutations'or choices[i][1],UDim2.new((i-1)*.25,0,0,96),UDim2.new(.25,-5,0,30));Theme.Text(b,15,true,C.Text);require(RS.GardenTextFit).Attach(b,15,12);self.FilterButtons[i]=b
  table.insert(self.Connections,b.Activated:Connect(function()if i==4 then self.Mutated=not self.Mutated;b.Text=self.Mutated and'Mutated only'or'All mutations'else self.FilterIndex[i]=self.FilterIndex[i]%#choices[i]+1;b.Text=choices[i][self.FilterIndex[i]]end;update()end))
 end
 table.insert(self.Connections,search:GetPropertyChangedSignal('Text'):Connect(update))
 table.insert(self.Connections,list:GetPropertyChangedSignal('CanvasPosition'):Connect(function()self:Render()end))
 table.insert(self.Connections,list:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:Render()end))
 table.insert(self.Connections,parent:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()if self.Root.Visible then self:Layout();self:Render(true)end end))
 return self
end
function Menu:Clear()
 for _,row in pairs(self.ById)do row:Destroy()end;table.clear(self.Rows);table.clear(self.ById);table.clear(self.Data);self.ViewKey=nil
end
function Menu:MakeRow(item,narrow,height)
 local def=Catalog[item.SeedId];local rarity=item.Rarity or(def and def.Rarity)or'Common';local style=Theme.Rarity(rarity)
 local row=Instance.new('Frame');row.Name='Harvest';row.Size=UDim2.new(1,-7,0,height-9);row.BackgroundColor3=C.Card;row.BorderSizePixel=0;row.Parent=self.List;require(RS.BrightUI).Card(row,style.Accent,false);Style.Accent(row,style.Accent)
 local preview=Instance.new('ViewportFrame');preview.Name='RotatingHarvest';preview.Position=UDim2.fromOffset(10,10);preview.Size=UDim2.fromOffset(narrow and 84 or 128,narrow and 96 or 134);preview.BackgroundColor3=C.Inset;preview.BorderSizePixel=0;preview.Ambient=Color3.fromRGB(185,185,185);preview.LightColor=Color3.fromRGB(255,244,220);preview.LightDirection=Vector3.new(-1,-1,-1);preview.Parent=row;Theme.Corner(preview,8);Style.Inset(preview);Preview.Attach(preview,item)
 local left=narrow and 104 or 150;local right=narrow and 10 or 164
 local name=text(row,'Name','',UDim2.fromOffset(left,8),UDim2.new(1,-left-right,0,44),narrow and 21 or 25,true,style.Color);name.TextYAlignment=Enum.TextYAlignment.Top;Theme.RarityText(name,rarity,narrow and 21 or 25);require(RS.GardenTextFit).Attach(name,narrow and 21 or 25,17)
 local badge=Theme.Badge(row,rarity,false,true);badge.Position=UDim2.fromOffset(left,53)
 local traits=text(row,'Traits','',UDim2.fromOffset(narrow and 10 or left,narrow and 116 or 84),UDim2.new(1,-(narrow and 20 or left+right),0,narrow and 56 or 62),narrow and 16 or 18,false,C.Text)
 traits.TextYAlignment=Enum.TextYAlignment.Top;require(RS.GardenTextFit).Attach(traits,narrow and 16 or 18,12)
 local details=text(row,'Multipliers','',UDim2.fromOffset(narrow and 10 or left,narrow and 178 or 150),UDim2.new(1,-(narrow and 20 or left+right),0,narrow and 24 or 40),narrow and 16 or 17,false,C.Muted)
 require(RS.GardenTextFit).Attach(details,narrow and 16 or 17,12)
 local action=button(row,'Sell','',narrow and UDim2.new(0,10,1,-49)or UDim2.new(1,-152,.5,-30),narrow and UDim2.new(1,-20,0,38)or UDim2.fromOffset(140,60))
 local record={Narrow=narrow,Height=height,Visual=visualKey(item),Name=name,Traits=traits,Details=details,Action=action,Item=item};self.Data[row]=record
 action.Activated:Connect(function()if self.Root.Visible and self.State and self.State.CanSell then self.OnSell(record.Item.InventoryId,action.AbsolutePosition+action.AbsoluteSize*.5)end end)
 return row
end
function Menu:UpdateRow(row,item)
 local r=self.Data[row];r.Item=item
 local traitText=Traits.Lines(item,22);if traitText==''then traitText='Normal'end
 Traits.Style(r.Traits,item)
 local values={Name=Names.Fruit(item.SeedId,item.FruitName or item.Name)..((item.Count or 1)>1 and' ×'..item.Count or''),Traits=traitText..'\n'..Weight.Text('Fruit',item.SeedId,math.min(25,item.FruitScale or 1)),Details='Bonus + '..tostring(math.max(0,require(script.Parent.BalanceRules).Half((item.CashMultiplier or 1)-1)))..'× · Total ×'..Numbers.Format(Numbers.Half(item.CashMultiplier or 1)),Action='Sell\n$'..Cash.Compact(item.SellValue)}
 for field,value in pairs(values)do if r[field].Text~=value then r[field].Text=value end end
 r.Action:SetAttribute('ExactCash',Cash.Exact(item.SellValue));r.Action.Active=self.State.CanSell==true;r.Action.AutoButtonColor=r.Action.Active;r.Action.BackgroundTransparency=r.Action.Active and 0 or .5
end
function Menu:Render(force)
 if not self.Root.Visible or not self.State then return end
 local items=self.Filtered or self.State.Harvests or{};local narrow=self.List.AbsoluteSize.X<540;local height=narrow and 266 or 214
 local canvas=#items*height;self.List.CanvasSize=UDim2.fromOffset(0,canvas);self.Empty.Visible=#items==0
 local y=math.clamp(self.List.CanvasPosition.Y,0,math.max(0,canvas-self.List.AbsoluteSize.Y))
 if self.List.CanvasPosition.Y~=y then self.List.CanvasPosition=Vector2.new(0,y)end
 local first=math.max(1,math.floor(y/height)+1);local last=math.min(#items,first+math.ceil(self.List.AbsoluteSize.Y/height))
 local viewKey=table.concat({first,last,tostring(narrow),height,#items},':');if not force and self.ViewKey==viewKey then return end;self.ViewKey=viewKey
 local nextRows,used={},{}
 for i=first,last do
  local item=items[i];local id=key(item,i);local row=self.ById[id];local record=row and self.Data[row]
  if row and(record.Narrow~=narrow or record.Height~=height or record.Visual~=visualKey(item))then row:Destroy();self.Data[row]=nil;self.ById[id]=nil;row=nil end
  if not row then row=self:MakeRow(item,narrow,height);self.ById[id]=row end
  row.Position=UDim2.fromOffset(1,(i-1)*height+1);self:UpdateRow(row,item);nextRows[i]=row;used[id]=true
 end
 -- Keep still-visible rows and their native 3D previews when an item is sold or state is refreshed.
 for id,row in pairs(self.ById)do if not used[id]then row:Destroy();self.Data[row]=nil;self.ById[id]=nil end end
 self.Rows=nextRows
end
-- R101: a short viewport cannot spend all of its item area on fixed toolbar rows.
function Menu:Layout()
 local parent=self.Root.Parent;local view=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
 self.Compact=view and view.Y<480 or false
 local parentHeight=parent.AbsoluteSize.Y
 if parent.Size.Y.Scale==0 and parent.Size.Y.Offset>0 then parentHeight=parent.Size.Y.Offset end
 local top=self.Compact and 94 or 122;local height=math.max(40,parentHeight-(self.Compact and 124 or 152))
 local tight=height<210;self.Tight=tight
 self.Root.Position=UDim2.fromOffset(16,top);self.Root.Size=UDim2.new(1,-32,0,height)
 self.Controls.Visible=tight
 if tight then
  local width=math.max(228,parent.AbsoluteSize.X-32);local sidebar=math.min(146,math.max(90,math.floor(width*.28)))
  self.Controls.Position=UDim2.fromOffset(0,0);self.Controls.Size=UDim2.new(0,sidebar,1,0);self.Controls.CanvasSize=UDim2.fromOffset(0,272)
  self.SummaryBox.Parent=self.Controls;self.SummaryBox.Position=UDim2.fromOffset(0,0);self.SummaryBox.Size=UDim2.new(1,-6,0,86)
  self.All.Position=UDim2.fromOffset(0,0);self.All.Size=UDim2.new(1,0,0,40)
  self.Summary.Position=UDim2.fromOffset(4,44);self.Summary.Size=UDim2.new(1,-8,0,38)
  self.Search.Parent=self.Controls;self.Search.Position=UDim2.fromOffset(0,90);self.Search.Size=UDim2.new(1,-6,0,32)
  for i,button in ipairs(self.FilterButtons)do button.Parent=self.Controls;button.Position=UDim2.fromOffset(0,128+(i-1)*36);button.Size=UDim2.new(1,-6,0,32)end
  self.List.Position=UDim2.fromOffset(sidebar+10,0);self.List.Size=UDim2.new(1,-sidebar-10,1,0)
 else
  self.SummaryBox.Parent=self.Root;self.SummaryBox.Position=UDim2.fromOffset(0,0);self.SummaryBox.Size=UDim2.new(1,0,0,self.Compact and 46 or 52)
  self.All.Position=UDim2.new(1,-138,0,6);self.All.Size=UDim2.fromOffset(132,self.Compact and 34 or 40)
  self.Summary.Position=UDim2.fromOffset(12,3);self.Summary.Size=UDim2.new(1,-156,1,-6)
  self.Search.Parent=self.Root;self.Search.Position=UDim2.fromOffset(0,58);self.Search.Size=UDim2.new(1,0,0,32)
  for i,button in ipairs(self.FilterButtons)do button.Parent=self.Root;button.Position=UDim2.new((i-1)*.25,0,0,96);button.Size=UDim2.new(.25,-5,0,30)end
  self.List.Position=UDim2.fromOffset(0,134);self.List.Size=UDim2.new(1,0,1,-134)
 end
 self.ViewKey=nil
end
function Menu:Show(state)
 self.State=state;self.Root.Visible=true;self:Layout()
 local count,total=0,0
 for _,item in ipairs(state.Harvests or{})do count+=item.Count or 1;total+=(item.Count or 1)*(item.SellValue or 0)end
 self.Summary.Text=tostring(count)..(count==1 and' crop' or' crops')..'\n$'..Cash.Compact(total)..' total';self.Summary:SetAttribute('ExactCash',Cash.Exact(total))
 self.All.Active=state.CanSell and count>0;self.All.AutoButtonColor=self.All.Active;self.All.BackgroundTransparency=self.All.Active and 0 or .5
 self.ApplyFilters(false)
end
function Menu:Hide()self.Root.Visible=false;self:Clear()end
function Menu:Destroy()self:Clear();for _,c in ipairs(self.Connections)do c:Disconnect()end;self.Root:Destroy()end
return Menu
