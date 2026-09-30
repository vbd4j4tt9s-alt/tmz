local Traits=require(game:GetService('ReplicatedStorage').ItemTraitNames)
local Fit=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTextFit'))
local MenuStyle=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenMenuStyle'))
local Theme=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTheme'));local Catalog=require(game:GetService('ReplicatedStorage'):WaitForChild('PlantCatalog'))
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService')
local StarterGui=game:GetService('StarterGui');local GuiService=game:GetService('GuiService');local CAS=game:GetService('ContextActionService')
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Info=require(RS:WaitForChild('HarvestItemInfo'));local State=require(RS:WaitForChild('GardenInventoryState')).new()
-- R112: item pictures (cached 3D renders or flat icons) and display-only kg weights.
local Pictures=require(RS:WaitForChild('ItemPictures'));local Weight=require(RS:WaitForChild('ItemWeight'))
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local bag=player:WaitForChild('Backpack')
local old=pg:FindFirstChild('ChestToolHotbar');if old then old:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='ChestToolHotbar';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=25;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local C={Panel=Theme.Colors.Panel,Slot=Theme.Colors.Card,Green=Theme.Colors.Mint,Text=Theme.Colors.Text,Muted=Theme.Colors.Muted,
 Sheet=Color3.fromRGB(20,46,35),Tile=Color3.fromRGB(37,76,57),TileOn=Color3.fromRGB(65,120,76),Well=Color3.fromRGB(14,33,25)}
local function corner(p)local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=p end
local function label(parent,name,size,position,text,fontSize)
 local l=Instance.new('TextLabel');l.Name=name;l.Size=size;l.Position=position;l.Text=text;l.TextColor3=C.Text;l.BackgroundTransparency=1;l.Font=Theme.Font;l.TextSize=fontSize or 13;l.TextWrapped=true;l.Parent=parent;Fit.Attach(l,fontSize or 13,8);return l
end
local function button(parent,name,text,size,position)
 local b=Instance.new('TextButton');b.Name=name;b.Text=text;b.Size=size;b.Position=position;b.BackgroundColor3=C.Slot;b.TextColor3=C.Text;b.Font=Theme.Bold;b.TextSize=14;b.AutoButtonColor=true;b.Parent=parent;corner(b);Fit.Attach(b,14,8);return b
end
-- R112: slot names keep their exact text (the tutorial matches it); long names only shrink or clip visually.
local function plainLabel(parent,name)
 local l=Instance.new('TextLabel');l.Name=name;l.Text='';l.BackgroundTransparency=1;l.Font=Theme.Font;l.TextColor3=C.Text;l.TextScaled=true;l.TextWrapped=true;l.TextTruncate=Enum.TextTruncate.AtEnd;l.ZIndex=3;l.Parent=parent
 local fit=Instance.new('UITextSizeConstraint');fit.MinTextSize=7;fit.MaxTextSize=11;fit.Parent=l;return l
end
local function tint(l,rarity)
 local style=Theme.Rarity(rarity);l.TextColor3=style.Fill and Color3.new(1,1,1)or style.TextColor or style.Color
 local stroke=l:FindFirstChild('RarityOutline')or Instance.new('UIStroke');stroke.Name='RarityOutline';stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;stroke.Color=style.Outline or Color3.fromRGB(19,31,28);stroke.Thickness=1;stroke.Parent=l
 local fill=l:FindFirstChild('RarityFill')
 if style.Fill then if not fill then fill=Instance.new('UIGradient');fill.Name='RarityFill';fill.Rotation=90;fill.Parent=l end;fill.Color=style.Fill elseif fill then fill:Destroy()end
end
local function picture(parent)local f=Instance.new('Frame');f.Name='Picture';f.BackgroundTransparency=1;f.Active=false;f.ZIndex=1;f.Parent=parent;return f end
local function countBadge(parent)
 local l=Instance.new('TextLabel');l.Name='Count';l.Text='';l.BackgroundColor3=Color3.new(0,0,0);l.BackgroundTransparency=.35;l.TextColor3=C.Text;l.Font=Theme.Bold;l.TextSize=12
 l.Size=UDim2.fromOffset(28,16);l.Visible=false;l.ZIndex=4;l.Parent=parent;corner(l);return l
end
local function selectionBorder(b)
 local stroke=Instance.new('UIStroke');stroke.Name='SelectionOutline';stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Color=Color3.new(1,1,1);stroke.Thickness=2;stroke.Enabled=false;stroke.Parent=b
 local hovered,focused=false,false
 local function paint()
  local active=b:GetAttribute('Selected')==true;stroke.Enabled=active or hovered or focused;stroke.Transparency=active and 0 or .18
 end
 b.MouseEnter:Connect(function()hovered=true;paint()end);b.MouseLeave:Connect(function()hovered=false;paint()end)
 b.SelectionGained:Connect(function()focused=true;paint()end);b.SelectionLost:Connect(function()focused=false;paint()end)
 b:GetAttributeChangedSignal('Selected'):Connect(paint);paint()
end
local dock=Instance.new('Frame');dock.Name='Dock';dock.AnchorPoint=Vector2.new(.5,1);dock.Position=UDim2.new(.5,0,1,-12);dock.BackgroundTransparency=1;dock.Parent=gui
local showSelectedDetails=true
local selectedLabel=label(dock,'SelectedName',UDim2.new(1,0,0,26),UDim2.fromOffset(0,-44),'',14)
local selectedFit=Instance.new('UITextSizeConstraint');selectedFit.MinTextSize=11;selectedFit.MaxTextSize=14;selectedFit.Parent=selectedLabel;selectedLabel.TextScaled=true
local selectedTraits=label(dock,'SelectedTraits',UDim2.new(1,0,0,16),UDim2.fromOffset(0,-18),'',11);selectedTraits.TextColor3=C.Muted
local open=button(dock,'OpenInventory','Bag',UDim2.fromOffset(56,56),UDim2.new(1,-56,0,0))
local panel=Instance.new('Frame');panel.Name='Inventory';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.49);panel.Size=UDim2.new(.86,0,.66,0);panel.BackgroundColor3=C.Panel;panel.BackgroundTransparency=.05;panel.Visible=false;panel.Parent=gui;corner(panel)
local constraint=Instance.new('UISizeConstraint');constraint.MaxSize=Vector2.new(900,620);constraint.Parent=panel
label(panel,'Title',UDim2.new(1,-65,0,40),UDim2.fromOffset(16,8),'Inventory',20).TextXAlignment=Enum.TextXAlignment.Left
require(RS:WaitForChild('GardenMenuStyle')).Panel(panel,46)
panel.BackgroundColor3=C.Sheet;panel.BackgroundTransparency=.1 -- R112: dark translucent green sheet.
local close=button(panel,'Close','×',UDim2.fromOffset(36,36),UDim2.new(1,-48,0,10))
local search=Instance.new('TextBox');search.Name='Search';search.PlaceholderText='Search';search.Text='';search.ClearTextOnFocus=false;search.Size=UDim2.new(1,-32,0,36);search.Position=UDim2.fromOffset(16,54);search.BackgroundColor3=C.Slot;search.TextColor3=C.Text;search.PlaceholderColor3=C.Muted;search.Font=Enum.Font.FredokaOne;search.TextSize=14;search.Parent=panel;corner(search);require(RS:WaitForChild('GardenMenuStyle')).Inset(search);search.BackgroundColor3=C.Well
local filters=Instance.new('Frame');filters.Name='Categories';filters.BackgroundTransparency=1;filters.Size=UDim2.new(1,-32,0,32);filters.Position=UDim2.fromOffset(16,98);filters.Parent=panel
local scroll=Instance.new('ScrollingFrame');scroll.Name='Items';scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.Size=UDim2.new(1,-32,1,-218);scroll.Position=UDim2.fromOffset(16,178);scroll.ScrollBarThickness=5;scroll.CanvasSize=UDim2.new();scroll.Parent=panel
label(panel,'Hint',UDim2.new(1,-32,0,26),UDim2.new(0,16,1,-32),'Click to equip • Drag a slot or item onto the hotbar',12).TextColor3=C.Muted
local rarityFilter=button(panel,'RarityFilter','Rarity: All',UDim2.new(1,-32,0,30),UDim2.fromOffset(16,138));rarityFilter.BackgroundColor3=C.Tile
local arrow=Theme.ControlIcon(rarityFilter,'chevron');arrow.Position=UDim2.new(1,-24,.5,-7)
local rarityMenu=Instance.new('Frame');rarityMenu.Name='RarityOptions';rarityMenu.Position=UDim2.fromOffset(16,174);rarityMenu.Size=UDim2.new(1,-32,0,110);rarityMenu.BackgroundColor3=C.Sheet;rarityMenu.BorderSizePixel=0;rarityMenu.Visible=false;rarityMenu.ZIndex=10;rarityMenu.Parent=panel;corner(rarityMenu)
local rarityCategory='All'
local slots={};local rows={};local category='All';local visibleSlots=10;local sequence=0;local seen=setmetatable({},{__mode='k'});local toolConns={};local characterConns={};local allConns={};local queued=false;local drag;local suppressedUntil=0;local selectedKey
local refresh,renderRows,layout
local function watchTool(tool,onChanged)
 local links={tool:GetPropertyChangedSignal('Name'):Connect(onChanged)}
 for _,attribute in ipairs({'Mutation','PackMutation','Weather'})do table.insert(links,tool:GetAttributeChangedSignal(attribute):Connect(onChanged))end
 return {Disconnect=function()for _,connection in ipairs(links)do connection:Disconnect()end end}
end
local matched={};local listDirty=true;local viewKey
local function connect(signal,fn)local c=signal:Connect(fn);table.insert(allConns,c);return c end
local function toggle(show)
 panel.Visible=show;rarityMenu.Visible=false;selectedLabel.Visible=not show and showSelectedDetails;selectedTraits.Visible=not show and showSelectedDetails
 if show then pg:SetAttribute('SeedMenu','Inventory');search:ReleaseFocus();layout();renderRows()
 elseif pg:GetAttribute('SeedMenu')=='Inventory'then pg:SetAttribute('SeedMenu',nil)end
end
local function equip(key)
 local e=State.Items[key];local char=player.Character;local humanoid=char and char:FindFirstChildOfClass('Humanoid')
 if not e or not humanoid or humanoid.Health<=0 then return end
 if e.Tool.Parent==char then humanoid:UnequipTools();selectedKey=nil else
  State:Ensure(key,visibleSlots);humanoid:EquipTool(e.Tool);selectedKey=key
 end
 toggle(false);refresh()
end
local function beginDrag(button0,key,input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  drag={Key=key,Start=Vector2.new(input.Position.X,input.Position.Y),Input=input,Moved=false}
 end
end
for i=1,10 do
 local b=button(dock,'Slot'..i,'',UDim2.fromOffset(56,56),UDim2.new());slots[i]=b
 selectionBorder(b);Theme.CardBorder(b,'Common')
 -- R112: picture behind the number, a small exact name along the bottom, weight and stack count on the picture.
 picture(b)
 local number=label(b,'Number',UDim2.fromOffset(20,17),UDim2.fromOffset(3,1),i==10 and'0'or tostring(i),11);number.TextColor3=C.Muted;number.ZIndex=3
 plainLabel(b,'ItemName')
 local weight=label(b,'ItemWeight',UDim2.new(1,-4,0,12),UDim2.new(0,2,1,-26),'',9);weight.TextXAlignment=Enum.TextXAlignment.Right;weight.ZIndex=3
 countBadge(b)
 b.Activated:Connect(function()if os.clock()>=suppressedUntil and State.Slots[i]then equip(State.Slots[i])end end)
 b.InputBegan:Connect(function(input)if State.Slots[i]then beginDrag(b,State.Slots[i],input)end end)
end
local filterButtons={}
for i,name in ipairs({'All','Seeds','Fruit','Tools'})do
 local b=button(filters,name,'',UDim2.fromOffset(64,64),UDim2.new());filterButtons[name]=b;label(b,'Caption',UDim2.new(1,-4,0,18),UDim2.new(0,2,1,-20),name,13).ZIndex=3
 -- R113: square picture cards outside the sheet: a pack (All), a seed, a fruit and the shovel, drawn like the items.
 b.BackgroundColor3=C.Tile;selectionBorder(b);Pictures.ShowSample(picture(b),name,0);b:SetAttribute('Selected',name=='All')
 b.Activated:Connect(function()category=name;listDirty=true;scroll.CanvasPosition=Vector2.zero;renderRows()end)
end
local function rarity(tool)
 local def=Catalog[tool:GetAttribute('SeedId')];return tool:GetAttribute('Rarity')or(def and def.Rarity)
end
local function traits(tool)return Traits.Text(Traits.Tool(tool))end
local function decorate(label,tool,size)
 Theme.RarityText(label,tool and rarity(tool)or'Common',size);Fit.Attach(label,size,8)
end
local function emblem(button0,tool)
 local item=tool and(tool:GetAttribute('GardenSeed')or tool:GetAttribute('SeedPackTool')or tool:GetAttribute('HarvestItemTool'))
 local value=item and(rarity(tool)or'')or''
 if button0:GetAttribute('EmblemRarity')==value then return end
 button0:SetAttribute('EmblemRarity',value)
 local old=button0:FindFirstChild('RarityDecoration');if old then old:Destroy()end
 Theme.CardBorder(button0,value)
 if value~=''then local icon=Theme.Icon(button0,value);icon.Name='RarityDecoration';icon.Size=UDim2.fromOffset(12,12);icon.Position=UDim2.new(1,-15,0,2);icon.ZIndex=3 end
end
local function kind(tool)return tool:GetAttribute('HarvestItemTool')and'Fruit'or(tool:GetAttribute('GardenSeed')or tool:GetAttribute('SeedPackTool'))and'Seeds'or'Tools'end
local function weighedName(tool)local kg=Weight.ToolText(tool);local name=Names.Tool(tool,Catalog);return kg~=''and name..' ('..kg..')'or name end
-- R112: identical packs, seeds and fruit share one card/slot with a count; tools stay separate.
local stackFields={Pack={'Stage','BagVariant','PackSize','PackMutation','Weather','SeedScale'},Seed={'SeedId','SeedScale','Mutation','Weather','Rarity'},
 Fruit={'SeedId','FruitScale','Mutation','Weather','SellValue','FruitName','FruitIndex','Rarity'}}
local function stackKey(tool)
 local group=tool:GetAttribute('SeedPackTool')and'Pack'or tool:GetAttribute('GardenSeed')and'Seed'or tool:GetAttribute('HarvestItemTool')and'Fruit'
 if not group then return nil end
 local parts={group,tool.Name};for _,field in ipairs(stackFields[group])do table.insert(parts,tostring(tool:GetAttribute(field)))end
 return 'stack|'..table.concat(parts,'|')
end
local freeCards={}
local function makeCard()
 local b=button(scroll,'Item','',UDim2.fromOffset(92,92),UDim2.new());b.TextWrapped=true;b.BackgroundColor3=C.Tile
 -- R112: big picture, then a small readable "Name (2.4kg)" under it.
 local art=picture(b);art.Position=UDim2.fromOffset(6,5);art.Size=UDim2.new(1,-12,1,-37)
 local name=label(b,'ItemName',UDim2.new(1,-8,0,28),UDim2.new(0,4,1,-31),'',12);name.ZIndex=3
 local detail=label(b,'ItemTraits',UDim2.new(1,-8,0,13),UDim2.new(0,4,1,-45),'',10);detail.ZIndex=3
 countBadge(b).Position=UDim2.fromOffset(4,4)
 selectionBorder(b)
 b.Activated:Connect(function()local key=b:GetAttribute('InventoryKey');if key and os.clock()>=suppressedUntil then equip(key)end end)
 b.InputBegan:Connect(function(input)local key=b:GetAttribute('InventoryKey');if key then beginDrag(b,key,input)end end)
 return b
end
renderRows=function()
 if not panel.Visible then return end
 local changed=listDirty
 if listDirty then
  table.clear(matched);local term=search.Text:lower()
  for key,e in pairs(State.Items)do if(category=='All'or kind(e.Tool)==category)and(rarityCategory=='All'or rarity(e.Tool)==rarityCategory)and Names.Search(e.Tool,Catalog):find(term,1,true)then table.insert(matched,{Key=key,Entry=e})end end
  table.sort(matched,function(a,b)return a.Entry.Order<b.Entry.Order end);listDirty=false
  for name,b in pairs(filterButtons)do b.BackgroundColor3=name==category and C.TileOn or C.Tile;b:SetAttribute('Selected',name==category)end
 end
 local width=scroll.AbsoluteSize.X;local side=width<400 and 84 or width<640 and 92 or 104;local cell=side+8;local cols=math.max(1,math.floor((math.max(1,width-12)+8)/cell))
 local canvas=math.ceil(#matched/cols)*cell+8
 local y=math.clamp(scroll.CanvasPosition.Y,0,math.max(0,canvas-scroll.AbsoluteSize.Y))
 -- R113: two rows kept above and below the view, so cards (and their pictures) are ready before they scroll in.
 local firstRow=math.max(0,math.floor(y/cell)-2);local lastRow=math.floor(y/cell)+math.ceil(scroll.AbsoluteSize.Y/cell)+2
 local key=table.concat({firstRow,lastRow,cols,side,#matched},':')
 if not changed and viewKey==key then return end;viewKey=key
 scroll.CanvasSize=UDim2.fromOffset(0,canvas)
 if y~=scroll.CanvasPosition.Y then scroll.CanvasPosition=Vector2.new(0,y)end
 local used={};local last=math.min(#matched,(lastRow+1)*cols)
 for index=firstRow*cols+1,last do used[matched[index].Key]=true end
 -- R113: cards leaving the window are recycled (their picture is parked by look), never rebuilt per item.
 for key,b in pairs(rows)do if not used[key]then rows[key]=nil;Pictures.Clear(b.Picture)
  if #freeCards<32 then b.Visible=false;b.Name='SpareItem';b:SetAttribute('InventoryKey',nil);table.insert(freeCards,b)else b:Destroy()end
 end end
 for index=firstRow*cols+1,last do
  local item=matched[index];local b=rows[item.Key]
  if not b then
   b=table.remove(freeCards)or makeCard()
   b.Name='Item';b.Visible=true;b:SetAttribute('InventoryKey',item.Key);rows[item.Key]=b
  end
  b.Size=UDim2.fromOffset(side,side);b.Position=UDim2.fromOffset(4+(index-1)%cols*cell,4+math.floor((index-1)/cols)*cell)
  local tool=item.Entry.Tool;local name=rarity(tool)or''
  if b:GetAttribute('NameRarity')~=name then decorate(b.ItemName,tool,12);b:SetAttribute('NameRarity',name)end
  emblem(b,tool);b.ItemName.Text=weighedName(tool);b.ItemTraits.Text=traits(tool);Traits.Style(b.ItemTraits,Traits.Tool(tool))
  local count=item.Entry.Count or 1;b.Count.Text='x'..count;b.Count.Visible=count>1
  Pictures.Show(b.Picture,tool,2)
  b:SetAttribute('Selected',tool.Parent==player.Character)
 end
end

rarityFilter.Activated:Connect(function()rarityMenu.Visible=not rarityMenu.Visible end)
for i,name in ipairs({'All','Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'})do
 local option=button(rarityMenu,name,name,UDim2.new(1/3,-8,0,30),UDim2.new((i-1)%3/3,4,0,4+math.floor((i-1)/3)*36));option.ZIndex=11
 Theme.RarityText(option,name,12,false)
 option.Activated:Connect(function()
  rarityCategory=name;rarityFilter.Text='Rarity: '..name;rarityMenu.Visible=false
  listDirty=true;scroll.CanvasPosition=Vector2.zero;renderRows()
 end)
end

refresh=function()
 local items={};local containers={bag};if player.Character then table.insert(containers,player.Character)end
 for _,container in ipairs(containers)do for _,tool in ipairs(container:GetChildren())do if tool:IsA('Tool')then
  if not seen[tool]then sequence+=1;seen[tool]=sequence end
  local key=stackKey(tool)or Info.Key(tool)or('tool-'..seen[tool]);local order=tool:GetAttribute('GardenShovel')and-1 or seen[tool];local e=items[key]
  if not e then items[key]={Tool=tool,Order=order,Count=1}
  else -- The equipped copy, else the oldest, represents a stack.
   e.Count+=1;e.Order=math.min(e.Order,order)
   if tool.Parent==player.Character or(e.Tool.Parent~=player.Character and seen[tool]<seen[e.Tool])then e.Tool=tool end
  end
  if tool.Parent==player.Character then selectedKey=key end
  if not toolConns[tool]then toolConns[tool]=watchTool(tool,function()refresh()end)end
 end end end
 for tool,c in pairs(toolConns)do if tool.Parent~=bag and tool.Parent~=player.Character then c:Disconnect();toolConns[tool]=nil end end
 State:Reconcile(items);listDirty=true
 -- R113: build every look in the bag ahead of time (time-sliced), in inventory order.
 local ordered={};for _,e in pairs(items)do table.insert(ordered,e)end;table.sort(ordered,function(a,b)return a.Order<b.Order end)
 for i,e in ipairs(ordered)do ordered[i]=e.Tool end;Pictures.Prefetch(ordered)
 local active=selectedKey and items[selectedKey];if not active or active.Tool.Parent~=player.Character then selectedKey=nil end
 local selectedTool=selectedKey and items[selectedKey].Tool
 selectedLabel.Text=selectedTool and weighedName(selectedTool)or''
 selectedTraits.Text=selectedTool and traits(selectedTool)or'';Traits.Style(selectedTraits,Traits.Tool(selectedTool))
 decorate(selectedLabel,selectedTool,14)
 for i,b in ipairs(slots)do
  local e=items[State.Slots[i]];local tool=e and e.Tool
  b.ItemName.Text=tool and Names.Tool(tool,Catalog)or'';tint(b.ItemName,tool and rarity(tool)or'Common')
  b.ItemWeight.Text=tool and Weight.ToolText(tool)or'';Traits.Style(b.ItemWeight,Traits.Tool(tool))
  local count=e and e.Count or 0;b.Count.Text='x'..count;b.Count.Visible=count>1;Pictures.Show(b.Picture,tool,1)
  emblem(b,tool);b:SetAttribute('Selected',e~=nil and tool.Parent==player.Character);b.BackgroundTransparency=e and .10 or .50
 end
 renderRows()
end
local function queue()
 if queued then return end;queued=true;task.defer(function()queued=false;if gui.Parent then refresh()end end)
end
-- R113: HUD boxes that stay on screen while the bag is open (same metrics HudLayout gives each HUD script).
local function hudBoxes(m,w,h)
 local shared=require(RS.HudLayout).HudBoxes
 if shared then local b=shared(m,w,h,false);local t=m.Travel;if t then table.insert(b,{X=t.X,Y=t.Y,W=t.W,H=t.H})end;return b end
 local b={{X=m.MenuX,Y=h/2+(m.MenuShiftY or 0)-m.MenuSize/2,W=m.MenuSize,H=m.MenuSize}}
 local bar=(m.Slots+1)*m.SlotSize+m.Slots*6
 table.insert(b,{X=w/2+(m.HotbarShiftX or 0)-bar/2,Y=h-m.HotbarBottom-m.SlotSize,W=bar,H=m.SlotSize})
 for _,k in ipairs({'Speed','Cash','Gem'})do table.insert(b,{X=m[k..'X']or m.WalletX,Y=m[k..'Y'],W=m.WalletWidth,H=m.WalletHeight})end
 if m.Phone then
  local sw=(m.StatusHorizontal and 388 or 190)*m.StatusScale;local sh=(m.StatusHorizontal and 39 or 82)*m.StatusScale
  table.insert(b,{X=w-12-sw,Y=8,W=sw,H=sh});for _,z in ipairs(m.ThumbZones or{})do table.insert(b,z)end
 else
  local sw=(m.StatusStacked and 190 or 337)*m.StatusScale;local sh=(m.StatusStacked and 211 or 125)*m.StatusScale
  table.insert(b,{X=w-12-sw,Y=h-m.StatusBottom-sh,W=sw,H=sh})
 end
 return b
end
-- Places the sheet and returns how the category cards go: 'Column' (left of the sheet) or 'Row' (above it, at x).
local function placeTabs(m,w,h)
 local boxes=hudBoxes(m,w,h);local gap=8
 local function clear(x,y,bw,bh)
  if x<4 or y<4 or x+bw>w-4 or y+bh>h-4 then return false end
  for _,b in ipairs(boxes)do if x<b.X+b.W+4 and x+bw>b.X-4 and y<b.Y+b.H+4 and y+bh>b.Y-4 then return false end end
  return true
 end
 local maxWidth,wanted=math.min(900,w*.86),math.min(620,h*.66)
 local function place(width)
  MenuStyle.Place(panel,pg,width,wanted)
  local sw,sh=panel.Size.X.Offset,panel.Size.Y.Offset;return sw,sh,panel.Position.X.Offset,panel.Position.Y.Offset
 end
 -- Column: the sheet narrows (the pair stays centred) until the cards clear the HUD.
 for _,t in ipairs({72,64,56,48})do
  local width=maxWidth
  while width>=math.min(maxWidth,420)do
   local sw,sh,cx,cy=place(width);cx+=(t+gap)/2
   if sw+t+gap<=w-16 and 4*t+18<=sh and clear(cx-sw/2-gap-t,cy-sh/2,t,4*t+18)then panel.Position=UDim2.fromOffset(cx,cy);return 'Column',t,0 end
   width-=40
  end
 end
 -- Row: the sheet moves down by one card; the row sits at its left edge, right edge or centre.
 for _,t in ipairs({56,48,44})do
  local sw,sh,cx,cy=place(maxWidth);local rowWidth=4*t+18;local top=cy-sh/2
  if sh-t-gap>=180 then
   for _,x in ipairs({0,sw-rowWidth,(sw-rowWidth)/2})do
    if clear(cx-sw/2+x,top,rowWidth,t)then panel.Size=UDim2.fromOffset(sw,sh-t-gap);panel.Position=UDim2.fromOffset(cx,cy+(t+gap)/2);return 'Row',t,x end
   end
  end
 end
 local sw,sh,cx,cy=place(maxWidth);panel.Size=UDim2.fromOffset(sw,sh-52);panel.Position=UDim2.fromOffset(cx,cy+26);return 'Row',44,0
end
layout=function()
 local camera=workspace.CurrentCamera;local view=require(RS.HudLayout).Viewport(gui);local width=view.X
 local metrics=require(RS.HudLayout).Read(view,Input.TouchEnabled,require(RS.HudLayout).Controls(gui))
 showSelectedDetails=metrics.HotbarDetails~=false
 selectedLabel.Visible=showSelectedDetails and not panel.Visible;selectedTraits.Visible=showSelectedDetails and not panel.Visible
 visibleSlots=metrics.Slots
 local gap=6;local side=metrics.SlotSize
 dock.Position=UDim2.new(.5,metrics.HotbarShiftX or 0,1,-metrics.HotbarBottom);dock.Size=UDim2.fromOffset((visibleSlots+1)*side+visibleSlots*gap,side)
 local nameHeight=math.max(12,math.floor(side*.3));local small=math.max(8,math.floor(side*.15))
 for i,b in ipairs(slots)do b.Visible=i<=visibleSlots;b.Size=UDim2.fromOffset(side,side);b.Position=UDim2.fromOffset((i-1)*(side+gap),0)
  -- R112: picture fills the slot above a two-line name strip; weight and count sit on the picture's lower edge.
  b.Picture.Position=UDim2.fromOffset(3,3);b.Picture.Size=UDim2.new(1,-6,1,-(nameHeight+3))
  b.ItemName.Position=UDim2.new(0,2,1,-(nameHeight+1));b.ItemName.Size=UDim2.new(1,-4,0,nameHeight)
  b.ItemWeight.Visible=side>=52;b.ItemWeight.Position=UDim2.new(0,2,1,-(nameHeight+small+3));b.ItemWeight.Size=UDim2.new(1,-4,0,small+2);Fit.Attach(b.ItemWeight,small+1,7)
  b.Count.Position=UDim2.new(0,3,1,-(nameHeight+small+5));b.Count.Size=UDim2.fromOffset(math.max(22,math.floor(side*.4)),small+4);b.Count.TextSize=small+1
  -- R110: slot text grows with the larger slots.
  local fit=b.ItemName:FindFirstChildOfClass('UITextSizeConstraint');if fit then fit.MaxTextSize=math.max(8,math.floor(side*.17))end
  b.Number.TextSize=math.max(11,math.floor(side*.2));b.Number.Size=UDim2.fromOffset(math.floor(side*.34),math.floor(side*.29))
 end
 open.Size=UDim2.fromOffset(side,side);open.Position=UDim2.new(1,-side,0,0)
 if pg:GetAttribute('ChestHotbarReserve')~=side+78 then pg:SetAttribute('ChestHotbarReserve',side+78)end
 local height=view.Y
 -- R113: category cards sit outside the sheet: a column on its left, else a row above it; never over the HUD.
 local mode,tab,rowX=placeTabs(metrics,width,height)
 local sheetWidth,sheetHeight=panel.Size.X.Offset,panel.Size.Y.Offset;local title=panel.Title
 local tabGap=8;local caption=math.max(11,math.floor(tab*.2))
 if mode=='Column'then filters.Position=UDim2.fromOffset(-(tab+tabGap),0);filters.Size=UDim2.fromOffset(tab,4*tab+18)
 else filters.Position=UDim2.fromOffset(rowX,-(tab+tabGap));filters.Size=UDim2.fromOffset(4*tab+18,tab)end
 for i,name in ipairs({'All','Seeds','Fruit','Tools'})do
  local b=filterButtons[name];local at=(i-1)*(tab+6);b.Size=UDim2.fromOffset(tab,tab)
  b.Position=mode=='Column'and UDim2.fromOffset(0,at)or UDim2.fromOffset(at,0)
  b.Picture.Position=UDim2.fromOffset(4,3);b.Picture.Size=UDim2.new(1,-8,1,-(caption+7))
  b.Caption.Position=UDim2.new(0,2,1,-(caption+4));b.Caption.Size=UDim2.new(1,-4,0,caption+2);Fit.Attach(b.Caption,caption,8)
 end
 if sheetWidth>=560 then
  -- Wide sheets: search in the header, rarity row, then the grid.
  local searchWidth=math.clamp(math.floor(sheetWidth*.34),160,280)
  title.Size=UDim2.new(1,-(searchWidth+120),0,40)
  search.Position=UDim2.new(1,-(searchWidth+58),0,12);search.Size=UDim2.fromOffset(searchWidth,32)
  rarityFilter.Position=UDim2.fromOffset(16,58);rarityFilter.Size=UDim2.fromOffset(math.min(220,sheetWidth-32),30)
  rarityMenu.Position=UDim2.fromOffset(16,92);rarityMenu.Size=UDim2.new(1,-32,0,110)
  scroll.Position=UDim2.fromOffset(16,96);scroll.Size=UDim2.new(1,-32,1,-130)
 else
  title.Size=UDim2.new(1,-65,0,40)
  search.Position=UDim2.fromOffset(16,54);search.Size=UDim2.new(1,-32,0,34)
  rarityFilter.Position=UDim2.fromOffset(16,94);rarityFilter.Size=UDim2.new(1,-32,0,30)
  rarityMenu.Position=UDim2.fromOffset(16,128);rarityMenu.Size=UDim2.new(1,-32,0,110)
  scroll.Position=UDim2.fromOffset(16,132);scroll.Size=UDim2.new(1,-32,1,-166)
 end
 renderRows()
end
local function character(char)
 for _,c in ipairs(characterConns)do c:Disconnect()end;table.clear(characterConns)
 if char then table.insert(characterConns,char.ChildAdded:Connect(queue));table.insert(characterConns,char.ChildRemoved:Connect(queue))end;queue()
end
local bagConns={}
local function watchBag(nextBag)
 for _,c in ipairs(bagConns)do c:Disconnect()end;table.clear(bagConns);bag=nextBag
 table.insert(bagConns,bag.ChildAdded:Connect(queue));table.insert(bagConns,bag.ChildRemoved:Connect(queue));queue()
end
connect(player.ChildAdded,function(child)if child:IsA('Backpack')then watchBag(child)end end)
watchBag(bag);connect(player.CharacterAdded,character);character(player.Character)
connect(search:GetPropertyChangedSignal('Text'),function()listDirty=true;scroll.CanvasPosition=Vector2.zero;renderRows()end)
connect(scroll:GetPropertyChangedSignal('CanvasPosition'),function()Pictures.Hurry();renderRows()end);connect(scroll:GetPropertyChangedSignal('AbsoluteSize'),renderRows)
connect(pg:GetAttributeChangedSignal('SeedMenu'),function()dock.Visible=(pg:GetAttribute('SeedMenu')==nil or pg:GetAttribute('SeedMenu')=='Inventory');if panel.Visible and pg:GetAttribute('SeedMenu')~='Inventory'then toggle(false)end end)
connect(Input.InputChanged,function(input)
 if not drag then return end
 if input.UserInputType==Enum.UserInputType.MouseMovement or input==drag.Input then
  local p=Vector2.new(input.Position.X,input.Position.Y);if(p-drag.Start).Magnitude>12 then drag.Moved=true end
 end
end)
connect(Input.InputEnded,function(input)
 if not drag or not(input.UserInputType==Enum.UserInputType.MouseButton1 or input==drag.Input)then return end
 local d=drag;drag=nil;if not d.Moved then return end;suppressedUntil=os.clock()+.2
 -- InputObject.Position and AbsolutePosition already share CoreUISafeInsets coordinates.
 local p=Vector2.new(input.Position.X,input.Position.Y)
 for i,b in ipairs(slots)do local a,z=b.AbsolutePosition,b.AbsoluteSize;if b.Visible and p.X>=a.X and p.Y>=a.Y and p.X<=a.X+z.X and p.Y<=a.Y+z.Y then State:Place(d.Key,i);refresh();break end end
end)
local numbers={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8,[Enum.KeyCode.Nine]=9,[Enum.KeyCode.Zero]=10}
connect(Input.InputBegan,function(input,processed)
 if processed or Input:GetFocusedTextBox()then return end
 if input.KeyCode==Enum.KeyCode.Backquote or input.KeyCode==Enum.KeyCode.B then toggle(not panel.Visible)
 elseif numbers[input.KeyCode]and not pg:GetAttribute('SeedMenu')then local key=State.Slots[numbers[input.KeyCode]];if key then equip(key)end
 elseif input.KeyCode==Enum.KeyCode.Escape and panel.Visible then toggle(false)end
end)
CAS:BindAction('GardenHotbarCycle',function(_,state,input)
 if state~=Enum.UserInputState.Begin or pg:GetAttribute('SeedMenu')then return Enum.ContextActionResult.Pass end
 local current=0;for i=1,visibleSlots do if State.Slots[i]==selectedKey then current=i end end
 local direction=input.KeyCode==Enum.KeyCode.ButtonL1 and-1 or 1
 for offset=1,visibleSlots do local index=(current-1+offset*direction)%visibleSlots+1;local key=State.Slots[index];if key then equip(key);break end end
 return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
selectionBorder(open);Theme.CardBorder(open,'Common')
open.Activated:Connect(function()toggle(not panel.Visible)end);close.Activated:Connect(function()toggle(false)end)
local stopHudLayout=require(RS.HudLayout).Watch(gui,layout)
connect(pg:GetAttributeChangedSignal('HudNoticeBottom'),layout);refresh()
for attempt=1,5 do local okay=pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)end);if okay then break end;task.wait(.2)end
script.Destroying:Connect(function()
 for _,c in ipairs(allConns)do c:Disconnect()end;for _,c in ipairs(characterConns)do c:Disconnect()end;for _,c in pairs(toolConns)do c:Disconnect()end
 for _,c in ipairs(bagConns)do c:Disconnect()end
 stopHudLayout();CAS:UnbindAction('GardenHotbarCycle');pg:SetAttribute('ChestHotbarReserve',nil);gui:Destroy()
 pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,true)end)
end)
