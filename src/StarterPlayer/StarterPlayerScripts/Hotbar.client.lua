local Traits=require(game:GetService('ReplicatedStorage').ItemTraitNames)
local Fit=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTextFit'))
local MenuStyle=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenMenuStyle'))
local Theme=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTheme'));local Catalog=require(game:GetService('ReplicatedStorage'):WaitForChild('PlantCatalog'))
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService')
local StarterGui=game:GetService('StarterGui');local GuiService=game:GetService('GuiService');local CAS=game:GetService('ContextActionService')
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Info=require(RS:WaitForChild('HarvestItemInfo'));local State=require(RS:WaitForChild('GardenInventoryState')).new()
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local bag=player:WaitForChild('Backpack')
local old=pg:FindFirstChild('ChestToolHotbar');if old then old:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='ChestToolHotbar';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=25;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local C={Panel=Theme.Colors.Panel,Slot=Theme.Colors.Card,Green=Theme.Colors.Mint,Text=Theme.Colors.Text,Muted=Theme.Colors.Muted}
local function corner(p)local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=p end
local function label(parent,name,size,position,text,fontSize)
 local l=Instance.new('TextLabel');l.Name=name;l.Size=size;l.Position=position;l.Text=text;l.TextColor3=C.Text;l.BackgroundTransparency=1;l.Font=Theme.Font;l.TextSize=fontSize or 13;l.TextWrapped=true;l.Parent=parent;Fit.Attach(l,fontSize or 13,8);return l
end
local function button(parent,name,text,size,position)
 local b=Instance.new('TextButton');b.Name=name;b.Text=text;b.Size=size;b.Position=position;b.BackgroundColor3=C.Slot;b.TextColor3=C.Text;b.Font=Theme.Bold;b.TextSize=14;b.AutoButtonColor=true;b.Parent=parent;corner(b);Fit.Attach(b,14,8);return b
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
local close=button(panel,'Close','×',UDim2.fromOffset(36,36),UDim2.new(1,-48,0,10))
local search=Instance.new('TextBox');search.Name='Search';search.PlaceholderText='Search';search.Text='';search.ClearTextOnFocus=false;search.Size=UDim2.new(1,-32,0,36);search.Position=UDim2.fromOffset(16,54);search.BackgroundColor3=C.Slot;search.TextColor3=C.Text;search.PlaceholderColor3=C.Muted;search.Font=Enum.Font.FredokaOne;search.TextSize=14;search.Parent=panel;corner(search);require(RS:WaitForChild('GardenMenuStyle')).Inset(search)
local filters=Instance.new('Frame');filters.Name='Categories';filters.BackgroundTransparency=1;filters.Size=UDim2.new(1,-32,0,32);filters.Position=UDim2.fromOffset(16,98);filters.Parent=panel
local scroll=Instance.new('ScrollingFrame');scroll.Name='Items';scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.Size=UDim2.new(1,-32,1,-218);scroll.Position=UDim2.fromOffset(16,178);scroll.ScrollBarThickness=5;scroll.CanvasSize=UDim2.new();scroll.Parent=panel
label(panel,'Hint',UDim2.new(1,-32,0,26),UDim2.new(0,16,1,-32),'Click to equip • Drag a slot or item onto the hotbar',12).TextColor3=C.Muted
local rarityFilter=button(panel,'RarityFilter','Rarity: All',UDim2.new(1,-32,0,30),UDim2.fromOffset(16,138))
local arrow=Theme.ControlIcon(rarityFilter,'chevron');arrow.Position=UDim2.new(1,-24,.5,-7)
local rarityMenu=Instance.new('Frame');rarityMenu.Name='RarityOptions';rarityMenu.Position=UDim2.fromOffset(16,174);rarityMenu.Size=UDim2.new(1,-32,0,110);rarityMenu.BackgroundColor3=C.Panel;rarityMenu.BorderSizePixel=0;rarityMenu.Visible=false;rarityMenu.ZIndex=10;rarityMenu.Parent=panel;corner(rarityMenu)
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
 label(b,'Number',UDim2.fromOffset(20,17),UDim2.fromOffset(3,1),i==10 and'0'or tostring(i),11).TextColor3=C.Muted
 local nameLabel=label(b,'ItemName',UDim2.new(1,-8,1,-29),UDim2.fromOffset(4,14),'',12)
 local fontSize=Instance.new('UITextSizeConstraint');fontSize.MinTextSize=8;fontSize.MaxTextSize=11;fontSize.Parent=nameLabel
 local detail=label(b,'ItemTraits',UDim2.new(1,-4,0,12),UDim2.new(0,2,1,-14),'',9);detail.TextScaled=true;detail.TextColor3=C.Muted
 b.Activated:Connect(function()if os.clock()>=suppressedUntil and State.Slots[i]then equip(State.Slots[i])end end)
 b.InputBegan:Connect(function(input)if State.Slots[i]then beginDrag(b,State.Slots[i],input)end end)
end
local filterButtons={}
for i,name in ipairs({'All','Seeds','Fruit','Tools'})do
 local b=button(filters,name,'',UDim2.new(.25,-6,1,0),UDim2.new((i-1)*.25,0,0,0));filterButtons[name]=b;local caption=label(b,'Caption',UDim2.new(1,-8,1,0),UDim2.fromOffset(4,0),name,14)
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
 if value~=''then local icon=Theme.Icon(button0,value);icon.Name='RarityDecoration';icon.Size=UDim2.fromOffset(12,12);icon.Position=UDim2.new(1,-15,0,2)end
end
local function kind(tool)return tool:GetAttribute('HarvestItemTool')and'Fruit'or(tool:GetAttribute('GardenSeed')or tool:GetAttribute('SeedPackTool'))and'Seeds'or'Tools'end
renderRows=function()
 if not panel.Visible then return end
 local changed=listDirty
 if listDirty then
  table.clear(matched);local term=search.Text:lower()
  for key,e in pairs(State.Items)do if(category=='All'or kind(e.Tool)==category)and(rarityCategory=='All'or rarity(e.Tool)==rarityCategory)and Names.Search(e.Tool,Catalog):find(term,1,true)then table.insert(matched,{Key=key,Entry=e})end end
  table.sort(matched,function(a,b)return a.Entry.Order<b.Entry.Order end);listDirty=false
  for name,b in pairs(filterButtons)do b.BackgroundColor3=name==category and Color3.fromRGB(65,99,66)or C.Slot end
 end
 local width=scroll.AbsoluteSize.X;local side=width<400 and 64 or 72;local cell=side+8;local cols=math.max(1,math.floor((math.max(1,width-12)+8)/cell))
 local canvas=math.ceil(#matched/cols)*cell+8
 local y=math.clamp(scroll.CanvasPosition.Y,0,math.max(0,canvas-scroll.AbsoluteSize.Y))
 local firstRow=math.max(0,math.floor(y/cell)-1);local lastRow=firstRow+math.ceil(scroll.AbsoluteSize.Y/cell)+2
 local key=table.concat({firstRow,lastRow,cols,side,#matched},':')
 if not changed and viewKey==key then return end;viewKey=key
 scroll.CanvasSize=UDim2.fromOffset(0,canvas)
 if y~=scroll.CanvasPosition.Y then scroll.CanvasPosition=Vector2.new(0,y)end
 local used={}
 for index=firstRow*cols+1,math.min(#matched,(lastRow+1)*cols)do
  local item=matched[index];local b=rows[item.Key];used[item.Key]=true
  if not b then
   b=button(scroll,'Item','',UDim2.fromOffset(side,side),UDim2.new());b.TextWrapped=true;b:SetAttribute('InventoryKey',item.Key);rows[item.Key]=b
   local name=label(b,'ItemName',UDim2.new(1,-10,1,-35),UDim2.fromOffset(5,15),'',13);name.TextScaled=true
   local limit=Instance.new('UITextSizeConstraint');limit.MinTextSize=8;limit.MaxTextSize=13;limit.Parent=name
   local detail=label(b,'ItemTraits',UDim2.new(1,-6,0,15),UDim2.new(0,3,1,-17),'',9);detail.TextScaled=true;detail.TextColor3=C.Muted
   selectionBorder(b)
   b.Activated:Connect(function()if os.clock()>=suppressedUntil then equip(b:GetAttribute('InventoryKey'))end end)
   b.InputBegan:Connect(function(input)beginDrag(b,b:GetAttribute('InventoryKey'),input)end)
  end
  b.Size=UDim2.fromOffset(side,side);b.Position=UDim2.fromOffset(4+(index-1)%cols*cell,4+math.floor((index-1)/cols)*cell)
  local tool=item.Entry.Tool;local name=rarity(tool)or''
  if b:GetAttribute('NameRarity')~=name then decorate(b.ItemName,tool,13);b:SetAttribute('NameRarity',name)end
  emblem(b,tool);b.ItemName.Text=Names.Tool(tool,Catalog);b.ItemTraits.Text=traits(tool);Traits.Style(b.ItemTraits,Traits.Tool(tool))
  b:SetAttribute('Selected',tool.Parent==player.Character)
 end
 -- Keep overlapping cells alive. Only retire cells after entering cells exist.
 for key,b in pairs(rows)do if not used[key]then b:Destroy();rows[key]=nil end end
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
  local key=Info.Key(tool)or('tool-'..seen[tool]);items[key]={Tool=tool,Order=tool:GetAttribute('GardenShovel')and-1 or seen[tool]}
  if tool.Parent==player.Character then selectedKey=key end
  if not toolConns[tool]then toolConns[tool]=watchTool(tool,function()refresh()end)end
 end end end
 for tool,c in pairs(toolConns)do if tool.Parent~=bag and tool.Parent~=player.Character then c:Disconnect();toolConns[tool]=nil end end
 State:Reconcile(items);listDirty=true
 local active=selectedKey and items[selectedKey];if not active or active.Tool.Parent~=player.Character then selectedKey=nil end
 local selectedTool=selectedKey and items[selectedKey].Tool
 selectedLabel.Text=selectedTool and Names.Tool(selectedTool,Catalog)or''
 selectedTraits.Text=selectedTool and traits(selectedTool)or'';Traits.Style(selectedTraits,Traits.Tool(selectedTool))
 decorate(selectedLabel,selectedTool,14)
 for i,b in ipairs(slots)do
  local e=items[State.Slots[i]];b.ItemName.Text=e and Names.Tool(e.Tool,Catalog)or'';b.ItemTraits.Text=e and traits(e.Tool)or'';Traits.Style(b.ItemTraits,Traits.Tool(e and e.Tool))
  emblem(b,e and e.Tool);decorate(b.ItemName,e and e.Tool,11);b:SetAttribute('Selected',e~=nil and e.Tool.Parent==player.Character);b.BackgroundTransparency=e and .10 or .50
 end
 renderRows()
end
local function queue()
 if queued then return end;queued=true;task.defer(function()queued=false;if gui.Parent then refresh()end end)
end
layout=function()
 local camera=workspace.CurrentCamera;local view=require(RS.HudLayout).Viewport(gui);local width=view.X
 local metrics=require(RS.HudLayout).Read(view,Input.TouchEnabled,require(RS.HudLayout).Controls(gui))
 showSelectedDetails=metrics.HotbarDetails~=false
 selectedLabel.Visible=showSelectedDetails and not panel.Visible;selectedTraits.Visible=showSelectedDetails and not panel.Visible
 visibleSlots=metrics.Slots
 local gap=6;local side=metrics.SlotSize
 dock.Position=UDim2.new(.5,metrics.HotbarShiftX or 0,1,-metrics.HotbarBottom);dock.Size=UDim2.fromOffset((visibleSlots+1)*side+visibleSlots*gap,side)
 for i,b in ipairs(slots)do b.Visible=i<=visibleSlots;b.ItemName.TextScaled=true;b.Size=UDim2.fromOffset(side,side);b.Position=UDim2.fromOffset((i-1)*(side+gap),0)end
 open.Size=UDim2.fromOffset(side,side);open.Position=UDim2.new(1,-side,0,0)
 if pg:GetAttribute('ChestHotbarReserve')~=side+78 then pg:SetAttribute('ChestHotbarReserve',side+78)end
 local height=view.Y;MenuStyle.Place(panel,pg,math.min(900,width*.86),math.min(620,height*.66))
 local compact=height<480 and width>540
 local title=panel.Title
 title.Size=compact and UDim2.fromOffset(145,36)or UDim2.new(1,-65,0,40)
 search.Position=compact and UDim2.fromOffset(170,12)or UDim2.fromOffset(16,54)
 search.Size=compact and UDim2.new(1,-234,0,30)or UDim2.new(1,-32,0,36)
 filters.Position=UDim2.fromOffset(16,compact and 56 or 98);filters.Size=compact and UDim2.new(.68,-24,0,28)or UDim2.new(1,-32,0,32)
 rarityFilter.Position=compact and UDim2.new(.68,0,0,56)or UDim2.fromOffset(16,138)
 rarityFilter.Size=compact and UDim2.new(.32,-16,0,28)or UDim2.new(1,-32,0,30)
 rarityMenu.Position=UDim2.fromOffset(16,compact and 88 or 174)
 scroll.Position=UDim2.fromOffset(16,compact and 94 or 178);scroll.Size=UDim2.new(1,-32,1,compact and -130 or -218)
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
connect(scroll:GetPropertyChangedSignal('CanvasPosition'),renderRows);connect(scroll:GetPropertyChangedSignal('AbsoluteSize'),renderRows)
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
