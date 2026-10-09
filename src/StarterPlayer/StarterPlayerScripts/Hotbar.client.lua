pcall(function()game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)end) -- R152: hide Roblox's own backpack before waiting (this script replaces it)
do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
local Traits=require(game:GetService('ReplicatedStorage').ItemTraitNames)
local Fit=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTextFit'))
local MenuStyle=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenMenuStyle'))
local Theme=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTheme'));local Catalog=require(game:GetService('ReplicatedStorage'):WaitForChild('PlantCatalog'))
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService')
local StarterGui=game:GetService('StarterGui');local GuiService=game:GetService('GuiService');local CAS=game:GetService('ContextActionService')
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Info=require(RS:WaitForChild('HarvestItemInfo'));local State=require(RS:WaitForChild('GardenInventoryState')).new()
local Arrival=require(RS:WaitForChild('HarvestArrival'))
local Collect do local ok,m=pcall(function()return require(RS:WaitForChild('SeedCollect154',10))end);Collect=ok and m or nil end -- R154: a pull reveal's seed shows once it has flown in
local Audio=require(RS:WaitForChild('InteractionAudio'))
-- R155 (owner: "just make it function like the normal inventory ... i can have a blank hot bar if i put everything in my bag ... max amount of items a person can
-- hold 200", "allow people to discard items"): the layout rules live in GardenInventoryState (new items: their stack, else the first free slot, else the Bag;
-- nothing moves by itself; slots emptied into the Bag stay blank; saved between sessions), the Bag's count / Trash / tap-tap / discarding in InventoryPanel155.
-- Here: the Bag lists only what is not on the hotbar; every slot (the shovel's too) takes any item; equipping from the Bag leaves the item in the Bag.
local Inv=require(RS:WaitForChild('InventoryPanel155'))
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
open:SetAttribute('ButtonSound',false) -- R150: the Bag opens / closes through SeedMenu; ButtonFeedback plays MenuClick / MenuClose for it
local panel=Instance.new('Frame');panel.Name='Inventory';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.49);panel.Size=UDim2.new(.86,0,.66,0);panel.BackgroundColor3=C.Panel;panel.BackgroundTransparency=.05;panel.Visible=false;panel.Parent=gui;corner(panel)
local constraint=Instance.new('UISizeConstraint');constraint.MaxSize=Vector2.new(1080,740);constraint.Parent=panel
label(panel,'Title',UDim2.new(1,-65,0,40),UDim2.fromOffset(16,8),'Your Bag',20).TextXAlignment=Enum.TextXAlignment.Left
require(RS:WaitForChild('GardenMenuStyle')).Panel(panel,46)
panel.BackgroundColor3=C.Sheet;panel.BackgroundTransparency=.1 -- R112: dark translucent green sheet.
local close=button(panel,'Close','×',UDim2.fromOffset(36,36),UDim2.new(1,-48,0,10))
local search=Instance.new('TextBox');search.Name='Search';search.PlaceholderText='Search';search.Text='';search.ClearTextOnFocus=false;search.Size=UDim2.new(1,-32,0,36);search.Position=UDim2.fromOffset(16,54);search.BackgroundColor3=C.Slot;search.TextColor3=C.Text;search.PlaceholderColor3=C.Muted;search.Font=Enum.Font.FredokaOne;search.TextSize=14;search.Parent=panel;corner(search);require(RS:WaitForChild('GardenMenuStyle')).Inset(search);search.BackgroundColor3=C.Well
local filters=Instance.new('Frame');filters.Name='Categories';filters.BackgroundTransparency=1;filters.Size=UDim2.new(1,-32,0,32);filters.Position=UDim2.fromOffset(16,98);filters.Parent=panel
local scroll=Instance.new('ScrollingFrame');scroll.Name='Items';scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.Size=UDim2.new(1,-32,1,-218);scroll.Position=UDim2.fromOffset(16,178);scroll.ScrollBarThickness=5;scroll.CanvasSize=UDim2.new();scroll.Parent=panel
label(panel,'Hint',UDim2.new(1,-32,0,26),UDim2.new(0,16,1,-32),'Click to hold it • Drag it onto the hotbar',12).TextColor3=C.Muted
local rarityFilter=button(panel,'RarityFilter','Rarity: All',UDim2.new(1,-32,0,30),UDim2.fromOffset(16,138));rarityFilter.BackgroundColor3=C.Tile
local arrow=Theme.ControlIcon(rarityFilter,'chevron');arrow.Position=UDim2.new(1,-24,.5,-7)
local rarityMenu=Instance.new('Frame');rarityMenu.Name='RarityOptions';rarityMenu.Position=UDim2.fromOffset(16,174);rarityMenu.Size=UDim2.new(1,-32,0,110);rarityMenu.BackgroundColor3=C.Sheet;rarityMenu.BorderSizePixel=0;rarityMenu.Visible=false;rarityMenu.ZIndex=10;rarityMenu.Parent=panel;corner(rarityMenu)
local rarityCategory='All'
local slots={};local rows={};local category='All';local visibleSlots=10;local sequence=0;local seen=setmetatable({},{__mode='k'});local toolConns={};local characterConns={};local allConns={};local queued=false;local selectedKey
local refresh,renderRows,layout,cancelPress,paintHeld
-- R152 (reliability): one odd tool or picture must never freeze the hotbar (an error inside refresh left every later slot, the Bag and new items stale, so
-- clicks went to things that no longer matched). Each item and each slot is guarded; the first failure of a kind is warned once.
local warned={}
local function guard(label,fn,...)local ok,err=pcall(fn,...);if not ok and not warned[label]then warned[label]=true;warn('[R152] Hotbar: '..label..' skipped: '..tostring(err))end;return ok end
-- R139 (owner: "new packs will be highlighted temporarily in the inventory, a rainbow border, temporary, fades after
-- a while"): a pack that arrives while you play (not the ones you had when you joined) gets a spinning rainbow ring on
-- its hotbar slot and Bag card. It waits until you can see it, stays 4 s, then fades out over 2 s.
local Run=game:GetService('RunService')
local GLOW_HOLD,GLOW_FADE,GLOW_MAX=4,2,600
local knownPacks={};local fresh={};local glowing=setmetatable({},{__mode='k'});local glowConn
local RAINBOW=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,72,72)),ColorSequenceKeypoint.new(.17,Color3.fromRGB(255,170,40)),
 ColorSequenceKeypoint.new(.33,Color3.fromRGB(255,240,70)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(90,235,110)),ColorSequenceKeypoint.new(.67,Color3.fromRGB(70,190,255)),
 ColorSequenceKeypoint.new(.83,Color3.fromRGB(150,110,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,72,72))})
local function glowOf(b)
 local g=b:FindFirstChild('NewGlow')
 if not g then
  g=Instance.new('Frame');g.Name='NewGlow';g.BackgroundTransparency=1;g.Size=UDim2.fromScale(1,1);g.Active=false;g.ZIndex=(b.ZIndex or 1)+6;g.Visible=false;g.Parent=b
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=g -- same corners as the card; the ring draws just outside its edge
  local st=Instance.new('UIStroke');st.Name='Rainbow';st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Thickness=3.5;st.Color=Color3.new(1,1,1);st.Parent=g
  local gr=Instance.new('UIGradient');gr.Color=RAINBOW;gr.Parent=st
 end
 return g
end
local function onScreen(b)
 if not b.Visible or b.AbsoluteSize.X<=0 then return false end
 if b:IsDescendantOf(panel)then return panel.Visible end
 return dock.Visible
end
local stepGlow
local function paintGlow(b,key)
 local f=key and fresh[key]
 if not f then local g=b:FindFirstChild('NewGlow');if g then g.Visible=false end;glowing[b]=nil;return end
 glowing[b]=key;glowOf(b).Visible=true
 if not glowConn then glowConn=Run.RenderStepped:Connect(function()stepGlow()end)end
end
stepGlow=function()
 local now=os.clock();local calm=GuiService.ReducedMotionEnabled
 for b,key in pairs(glowing)do
  local f=fresh[key];local g=b.Parent and b:FindFirstChild('NewGlow')
  if not f or not g or b:GetAttribute('InventoryKey')~=key and not b:IsDescendantOf(dock)then if g then g.Visible=false end;glowing[b]=nil
  else
   if not f.SeenAt and onScreen(b)then f.SeenAt=now end
   local alpha=0
   if f.SeenAt then local age=now-f.SeenAt;alpha=age<=GLOW_HOLD and 0 or math.clamp((age-GLOW_HOLD)/GLOW_FADE,0,1)end
   g.Rainbow.Transparency=alpha;g.Rainbow.UIGradient.Rotation=calm and 45 or(now*140)%360
  end
 end
 for key,f in pairs(fresh)do
  if f.SeenAt and now-f.SeenAt>GLOW_HOLD+GLOW_FADE or now-f.Born>GLOW_MAX then fresh[key]=nil end
 end
 if not next(fresh)then
  for b in pairs(glowing)do local g=b:FindFirstChild('NewGlow');if g then g.Visible=false end end;table.clear(glowing)
  if glowConn then glowConn:Disconnect();glowConn=nil end
 end
end
-- New = numbered after your save loaded (the server stamps PackNumber on the tool and PackSerialAtJoin on you), so
-- the packs you joined with never glow. Each pack glows once: tools rebuilt on a respawn or a sync keep their id.
local function notePack(tool,key)
 if not tool:GetAttribute('SeedPackTool')then return end
 local id=tool:GetAttribute('SeedInventoryId')or tool
 if knownPacks[id]then return end;knownPacks[id]=true
 local number,joined=tool:GetAttribute('PackNumber'),player:GetAttribute('PackSerialAtJoin')
 if not key or type(number)~='number'or type(joined)~='number'or number<=joined then return end
 local f=fresh[key];if f then f.SeenAt=nil;f.Born=os.clock()else fresh[key]={Born=os.clock()}end
end
local function watchTool(tool,onChanged)
 local links={tool:GetPropertyChangedSignal('Name'):Connect(onChanged)}
 for _,attribute in ipairs({'Mutation','PackMutation','Weather'})do table.insert(links,tool:GetAttributeChangedSignal(attribute):Connect(onChanged))end
 return {Disconnect=function()for _,connection in ipairs(links)do connection:Disconnect()end end}
end
-- R149 (owner: the picked fruit floats into the player and appears in the inventory): a harvested item is in the Backpack as soon as the server adds it,
-- but the Hotbar does not SHOW it until the fruit has arrived (HarvestArrival; instantly when no fruit flies: reduced motion, low quality, far away).
-- When it shows, its slot (or the Bag button when the item is not on a visible slot; and its card while the Bag is open) flashes once.
local FLASH_SECONDS=.32
local flashes={};local flashConn;local released={}
local function flashOf(b)
 local f=b:FindFirstChild('ArrivalFlash')
 if not f then
  f=Instance.new('Frame');f.Name='ArrivalFlash';f.BackgroundColor3=Color3.new(1,1,1);f.BackgroundTransparency=1;f.BorderSizePixel=0;f.Size=UDim2.fromScale(1,1);f.Active=false
  f.ZIndex=(b.ZIndex or 1)+7;f.Parent=b;local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=f
 end
 return f
end
local function stepFlashes()
 local now=os.clock()
 for b,at in pairs(flashes)do
  local f=b.Parent and b:FindFirstChild('ArrivalFlash');local u=(now-at)/FLASH_SECONDS
  if not f or u>=1 then if f then f.BackgroundTransparency=1 end;flashes[b]=nil
  else f.BackgroundTransparency=.3+.7*u*u end
 end
 if not next(flashes)and flashConn then flashConn:Disconnect();flashConn=nil end
end
local function flash(b)
 flashOf(b).BackgroundTransparency=.3;flashes[b]=os.clock()
 if not flashConn then flashConn=Run.RenderStepped:Connect(stepFlashes)end
end
local matched={};local listDirty=true;local viewKey
local function connect(signal,fn)local c=signal:Connect(fn);table.insert(allConns,c);return c end
local function queue()
 if queued then return end;queued=true;task.defer(function()queued=false;if gui.Parent then refresh()end end)
end
local function toggle(show)
 if show and cancelPress then cancelPress('the Bag opened')end
 panel.Visible=show;rarityMenu.Visible=false;selectedLabel.Visible=not show and showSelectedDetails;selectedTraits.Visible=not show and showSelectedDetails
 if show then pg:SetAttribute('SeedMenu','Inventory');search:ReleaseFocus();layout();renderRows();Inv.Opened()
 else Inv.Closed();if pg:GetAttribute('SeedMenu')=='Inventory'then pg:SetAttribute('SeedMenu',nil)end end
end
-- R152 (owner: "hot bar movements ... no sound effect"): the hotbar is silent. Equipping (keys 1-0, L1 / R1, a slot, a Bag card), unequipping,
-- an empty slot and moving an item between slots play nothing (R150 clicked Equip / Bubble04 for them). Equipping from the Bag closes it
-- without MenuClose, so that is silent too.
-- R152: a slot can point at a tool that is gone (picked up, replaced by the server, destroyed with a Backpack the frame before): the press is resolved against
-- what exists NOW (refresh first), never sent to a dead tool, so the first click lands on the item the slot shows.
local function alive(tool)local at=tool.Parent;return at~=nil and(at==player.Character or(at:IsA('Backpack')and at.Parent==player))end
-- R153 debug aid (owner: paste it if a press still goes missing): every press, what it did, and every move of an item the hotbar did not make itself (the
-- server's), with times. The last 60 lines are always kept; with the log on (/test hotbar sets the player's HotbarLog) each line is also printed (F9
-- console) and shown in a box top-left, ready to select and copy.
local logLines,logBox={},nil
local function note(text)
 local line=('%.2f %s'):format(os.clock(),text);logLines[#logLines+1]=line;if #logLines>60 then table.remove(logLines,1)end
 if player:GetAttribute('HotbarLog')==true then print('[Hotbar] '..line);if logBox then logBox.Text=table.concat(logLines,'\n',math.max(1,#logLines-21))end end
end
local keyOf=setmetatable({},{__mode='k'}) -- tool -> its key at the last refresh
local mine=setmetatable({},{__mode='k'}) -- tool -> where the hotbar itself just put it {At=, Hand=}
local lastPress=0
local function nameOf(key)local e=key and State.Items[key];return e and e.Tool.Name or tostring(key)end
-- R153 (owner: "i need to put in inputs twice to equip something in the hotbar"). Traced from the press to the item in the hand:
--  * a PACK is put in the hand by the server, which first waits up to 2.5 s for its chip-bag shape (R151, PackShapes151 Await; often after joining or once
--    the shape cache let it go). The hand stayed empty, so players pressed again: that second press UNEQUIPPED it, and only a third press held it. Now a pack
--    the player asked for is "on its way" until its bag is in the hand (or 4 s): its slot shows a pulsing ring and another press on it is ignored.
--  * a pack pressed while another one is being revealed (or while knocked down: the server takes every tool out of the hand then) was thrown back into the
--    Backpack by the server with no sign; it now waits and is held as soon as that is over. While carrying a stolen pack / in a chase a pack cannot be held:
--    FINISH THAT FIRST! says so (nothing is sent).
local pending -- a pack the player asked to hold that is not in the hand yet {Key, Tool, At, Old (the bag already in the hand), Queued (waiting its turn)}
-- (R153 client bug review, finding 9: a queued press waits at most QUEUED_SECONDS, then it is dropped quietly (a log line, no message); pressing the same slot again cancels it;
--  a press on another slot replaces it. Before, a press queued behind a reveal that never finished waited for ever, with a pulsing ring, and a second press was ignored.)
local QUEUED_SECONDS=8
local function carried(char)local c=char and char:FindFirstChild('CarriedSeed');return c and c:GetAttribute('SeedPackCarry')and c or nil end
local function revealing(char)local c=carried(char);return c~=nil and c:GetAttribute('RevealAt')~=nil end
local function knocked()return player:GetAttribute('GuardianRagdollActive')==true or player:GetAttribute('GuardianFlingActive')==true end
local function busy(tool)return tool:GetAttribute('SeedPackTool')and(player:GetAttribute('ChestChaseSeedCarrying')or player:GetAttribute('ChestChaseRunActive')or player:GetAttribute('ChestChaseQueued'))end
local Feed
local function notice(text)pcall(function()Feed=Feed or require(RS:WaitForChild('NoticeFeed83'));Feed.Plain(text,Color3.fromRGB(255,120,110),2.5,'hotbar '..text)end)end
local tickConn,tick
local function wake()if not tickConn then tickConn=Run.RenderStepped:Connect(function()tick()end)end end
local function equip(key,how,quiet)
 how=how or'press';lastPress=os.clock()
 local e=State.Items[key]
 if not e or not alive(e.Tool)then refresh();e=State.Items[key] end
 local char=player.Character;local humanoid=char and char:FindFirstChildOfClass('Humanoid')
 if not e or not alive(e.Tool)or not humanoid or humanoid.Health<=0 then note(how..': nothing to hold ('..tostring(key)..')');return end
 local tool=e.Tool;local held=char:FindFirstChildOfClass('Tool')
 if pending and pending.Key==key then
  if pending.Queued then pending=nil;wake();note(how..': '..tool.Name..' was waiting; cancelled (pressed again)');return end -- (the next tick takes the ring off)
  note(how..': '..tool.Name..' is already on its way, press ignored');return
 end
 if pending and pending.Queued then note(how..': '..pending.Tool.Name..' was waiting; '..tool.Name..' replaces it');pending=nil end
 if held and(held==tool or keyOf[held]==key)then
  mine[held]={At=os.clock(),Hand=false};humanoid:UnequipTools();selectedKey=nil;pending=nil;note(how..': unequip '..held.Name)
 elseif busy(tool)then note(how..': '..tool.Name..' refused (carrying a pack / in a chase)');notice('FINISH THAT FIRST!');return
 elseif knocked()or tool:GetAttribute('SeedPackTool')and revealing(char)then
  pending={Key=key,Tool=tool,At=os.clock(),Queued=true};wake()
  note(how..': '..tool.Name..' waits ('..(knocked()and'knocked down'or'a pack is being opened')..')')
 else
  if held then mine[held]={At=os.clock(),Hand=false}end;mine[tool]={At=os.clock(),Hand=true}
  humanoid:EquipTool(tool);selectedKey=key
  pending=nil;if tool:GetAttribute('SeedPackTool')then pending={Key=key,Tool=tool,At=os.clock(),Old=carried(char)};wake()end
  note(how..': equip '..tool.Name..(held and' (was '..held.Name..')'or''))
 end
 if quiet then refresh();return end
 if panel.Visible then Audio.Mute('MenuClose',.25)end
 toggle(false);paintHeld();queue() -- R155: the held item shows at once; the rest follows in ONE deferred refresh (the hand's ChildAdded / ChildRemoved queue it too: was two full refreshes)
end
-- A tool entered the hand / the Backpack: the hotbar's own move, a new item, or something else (the server) moved it (logged, with the server's reason).
local function moved(tool,hand)
 if not tool:IsA('Tool')then return end
 local m=mine[tool];mine[tool]=nil
 if m and m.Hand==hand and os.clock()-m.At<3 then return end
 if not keyOf[tool]then return end -- (a new item)
 -- (the server's reason counts only when it is fresh: an old one stays on the tool)
 local why=not hand and tool:GetAttribute('HoldRefused');local at=why and tonumber(tostring(why):match('@(.*)$'))
 why=at and math.abs(workspace:GetServerTimeNow()-at)<3 and tostring(why):match('^[^@]*')or nil
 note(('%s -> %s, not by the hotbar%s, %.2f s after the last press'):format(tool.Name,hand and'hand'or'Backpack',why and' (server: '..why..')'or'',os.clock()-lastPress))
 if not hand and pending and pending.Tool==tool and not pending.Queued then
  -- (the server refused it: a reveal it knew of before this client did, or a knock-down, means wait and hold it after; carrying / a chase means not now)
  if why=='opening'or why=='knocked'then pending={Key=pending.Key,Tool=tool,At=os.clock(),Queued=true};wake()else pending=nil end
  if why=='busy'then notice('FINISH THAT FIRST!')end
 end
end
local function ringOf(b)
 local r=b:FindFirstChild('PendingRing')
 if not r then
  r=Instance.new('Frame');r.Name='PendingRing';r.BackgroundTransparency=1;r.Size=UDim2.fromScale(1,1);r.Active=false;r.ZIndex=(b.ZIndex or 1)+5;r.Visible=false;r.Parent=b;corner(r)
  local st=Instance.new('UIStroke');st.Name='Ring';st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Thickness=3;st.Color=C.Green;st.Parent=r
 end
 return r
end
local ringOn
local function paintPending()
 local want;if pending then for i,b in ipairs(slots)do if b.Visible and State.Slots[i]==pending.Key then want=b end end end
 if ringOn and ringOn~=want then local r=ringOn:FindFirstChild('PendingRing');if r then r.Visible=false end;ringOn=nil end
 if want then -- (R153 client bug review, finding 8: with Reduced Motion the ring holds still, like the new-pack rainbow)
  local r=ringOf(want);r.Visible=true;ringOn=want
  local alpha=GuiService.ReducedMotionEnabled and .25 or .1+.5*(.5+.5*math.sin(os.clock()*9))
  if r.Ring.Transparency~=alpha then r.Ring.Transparency=alpha end
 end
end
-- R153 presses: one press = one action, whatever the engine delivers (owner: "i need to put in inputs twice" / "cant drag seeds and reorganise").
--  * a press starts on a slot / card's InputBegan OR its MouseButton1Down (a button may keep its primary click to itself: then InputBegan never comes and
--    R112-R152 never saw a drag at all), moves with UserInputService.InputChanged (the mouse, or that touch: by identity, else the touch nearest it) and ends
--    with UserInputService.InputEnded OR the MouseButton1Up of the button it is let go over. Activated is the engine's own "that was a click" and counts when
--    the release has not acted already. The first of them acts, once.
--  * where it ends decides: on another slot = a move (swap), off the hotbar onto the Bag (its sheet or its button) = out of the hotbar, on its own slot /
--    card = a click, however far it wandered (R152). A release that reports the press point again (a stale mouse position) uses the last move.
--  * screen points (MouseButton1Down / Up) lose the top inset; which shift lines a point up with the button pressed is learned on the first press.
--  * dragging shows the item under the pointer (a ghost), dims where it came from and lights where it would land. On a phone a 0.4 s hold picks it up at
--    once and stops the Bag grid scrolling under it; a quick tap is still a tap.
local SNAP,MOVE,HOLD=4,12,.4 -- SNAP: px around a slot or card that still count as it (the gap between slots is 6, so a neighbour never claims a point inside a slot)
local press;local lastOf=setmetatable({},{__mode='k'}) -- the press in progress; button -> its last press
local objShift,screenShift,learned=Vector2.zero,nil,false
local function within(b,p,pad)local a,z=b.AbsolutePosition,b.AbsoluteSize;pad=pad or 0;return p.X>=a.X-pad and p.Y>=a.Y-pad and p.X<=a.X+z.X+pad and p.Y<=a.Y+z.Y+pad end
local function inset()local ok,a=pcall(function()return GuiService:GetGuiInset()end);return ok and a and a.X and a or Vector2.zero end
local function fromInput(input)local p=input.Position;return Vector2.new(p.X-objShift.X,p.Y-objShift.Y)end
local function fromScreen(b,x,y)
 if screenShift then return Vector2.new(x-screenShift.X,y-screenShift.Y)end
 local i=inset();local a,z=Vector2.new(x-i.X,y-i.Y),Vector2.new(x,y)
 if b and within(b,a,SNAP)then screenShift=i;return a elseif b and within(b,z,SNAP)then screenShift=Vector2.zero;return z end
 return a
end
local function slotAt(p) -- the visible slot nearest to p within SNAP of it
 local best,bestD
 for i,b in ipairs(slots)do if b.Visible and within(b,p,SNAP)then
  local a,z=b.AbsolutePosition,b.AbsoluteSize
  local d=math.abs(p.X-(a.X+z.X/2))+math.abs(p.Y-(a.Y+z.Y/2));if not bestD or d<bestD then best,bestD=i,d end
 end end
 return best
end
local function overBag(p)return dock.Visible and(panel.Visible and within(panel,p)or within(open,p,SNAP))end
local function onSelf(d,p)local b=d.Slot and slots[d.Slot]or rows[d.Key];return b~=nil and b.Visible and within(b,p,SNAP)end
local ghost,lit,rowsHeld
local function cover(b,name,color,transparency)
 local f=b:FindFirstChild(name)
 if not f then
  f=Instance.new('Frame');f.Name=name;f.BackgroundColor3=color;f.BackgroundTransparency=transparency;f.BorderSizePixel=0;f.Size=UDim2.fromScale(1,1);f.Active=false;f.ZIndex=(b.ZIndex or 1)+8;f.Visible=false;f.Parent=b;corner(f)
  if name=='DropTarget'then local st=Instance.new('UIStroke');st.Color=color;st.Thickness=3;st.Parent=f end
 end
 return f
end
local function light(b)
 if lit==b then return end
 if lit then local f=lit:FindFirstChild('DropTarget');if f then f.Visible=false end end
 lit=b;if b then cover(b,'DropTarget',C.Green,.55).Visible=true end
end
local function lift(d)
 d.Lifted=true;local e=State.Items[d.Key];local tool=e and e.Tool
 if not ghost then
  ghost=Instance.new('Frame');ghost.Name='DragGhost';ghost.AnchorPoint=Vector2.new(.5,.5);ghost.BackgroundColor3=C.TileOn;ghost.BackgroundTransparency=.2;ghost.BorderSizePixel=0;ghost.Active=false;ghost.ZIndex=40;ghost.Visible=false;ghost.Parent=gui;corner(ghost)
  local st=Instance.new('UIStroke');st.Color=Color3.new(1,1,1);st.Thickness=2;st.Parent=ghost
  local pic=picture(ghost);pic.Position=UDim2.fromOffset(4,3);pic.Size=UDim2.new(1,-8,1,-18)
  local l=plainLabel(ghost,'ItemName');l.Position=UDim2.new(0,2,1,-15);l.Size=UDim2.new(1,-4,0,13)
 end
 local side=math.max(40,slots[1].AbsoluteSize.X);ghost.Size=UDim2.fromOffset(side,side);ghost.ItemName.Text=tool and Names.Tool(tool,Catalog)or''
 Pictures.Show(ghost.Picture,tool,1);ghost.Visible=true
 d.Shade=d.Slot and slots[d.Slot]or rows[d.Key];if d.Shade then cover(d.Shade,'DragShade',Color3.new(0,0,0),.55).Visible=true end
 if d.Card then d.Scrolling=scroll.ScrollingEnabled;scroll.ScrollingEnabled=false end
 Inv.Dragging(true,d.Slot);note('picked up '..nameOf(d.Key))
end
local function follow(d,p)
 if ghost then local g=gui.AbsolutePosition;ghost.Position=UDim2.fromOffset(p.X-g.X,p.Y-g.Y)end
 local to=slotAt(p)
 if to then light(to~=d.Slot and slots[to]or nil)
 elseif Inv.OverTrash(p)then light(Inv.TrashButton) -- R155: drop it on the Trash to throw it away
 elseif d.Slot and overBag(p)then light(panel.Visible and within(panel,p)and panel or open)
 else light(nil)end
end
local function settle(d) -- the ghost, the lights and the Bag grid back to normal
 if ghost and ghost.Visible then ghost.Visible=false;Pictures.Clear(ghost.Picture)end
 light(nil);Inv.Dragging(false)
 if d.Shade then local s=d.Shade:FindFirstChild('DragShade');if s then s.Visible=false end end
 if d.Scrolling~=nil then scroll.ScrollingEnabled=d.Scrolling;d.Scrolling=nil end
 if rowsHeld then rowsHeld=false;renderRows()end
end
cancelPress=function(why)local d=press;if not d then return end;press=nil;settle(d);note('press cancelled: '..why)end
local function begin(b,slot,key,kind,input,p)
 local now=os.clock()
 local began=input~=nil
 if press and press.Button==b and not press.Done and now-press.At<.05 and(began and press.Down and not press.Began or not began and press.Began and not press.Down)then
  -- (the InputBegan and the MouseButton1Down of one press, either first)
  if began then press.Began=true;press.Input=press.Input or input;press.Kind=kind else press.Down=true end;return
 end
 if press then cancelPress('a new press began')end
 press={Button=b,Slot=slot,Key=key,Card=slot==nil,Kind=kind,Input=input,Start=p,Pos=p,At=now,Began=began,Down=not began,ScrollY=b:IsDescendantOf(scroll)and scroll.CanvasPosition.Y or nil}
 lastOf[b]=press;lastPress=now;wake()
 note(('press %s: %s (%s)'):format(slot and'slot '..slot or'Bag card',nameOf(key),kind))
end
local function kindOf(input)local t=input.UserInputType;return t==Enum.UserInputType.MouseButton1 and'mouse'or t==Enum.UserInputType.Touch and'touch'or nil end
local function lineUp(b,input) -- the InputObject's point on button b, learning once whether this device reports it with the top inset (nil: not on b)
 local raw=input.Position;local i=inset()
 if learned then local p=fromInput(input);return within(b,p,SNAP*3)and p or nil end
 for _,shift in ipairs({Vector2.zero,i})do local p=Vector2.new(raw.X-shift.X,raw.Y-shift.Y);if within(b,p,SNAP)then objShift=shift;learned=true;return p end end
 return nil
end
local function beganOn(b,slot,key,input)
 local kind=kindOf(input);if not kind or not key then return end
 begin(b,slot,key,kind,input,lineUp(b,input)or fromInput(input))
end
local lastBegan -- the last mouse button / touch UserInputService saw begin: a press that started on MouseButton1Down takes it as its own
local function downOn(b,slot,key,x,y)
 if not key then return end
 local lb=lastBegan;local p=lb and os.clock()-lb.At<.05 and lineUp(b,lb.Input)
 if p then begin(b,slot,key,kindOf(lb.Input),nil,p);if press and not press.Input then press.Input=lb.Input end;return end
 local kind='mouse';pcall(function()if Input:GetLastInputType()==Enum.UserInputType.Touch then kind='touch'end end)
 begin(b,slot,key,kind,nil,fromScreen(b,x,y))
end
local function finish(p,how)
 local d=press;if not d then return end;press=nil
 if p then -- (a mouse release that reports the press point again: where the button saw it let go, else the last move, counts)
  if d.Kind=='mouse'and p.X==d.Start.X and p.Y==d.Start.Y then p=d.Up or(d.Tracked and d.Pos)or p end;d.Pos=p
 end
 settle(d)
 if d.Done then return end
 p=d.Pos;local moved=d.Moved or d.Lifted or(p-d.Start).Magnitude>MOVE
 local to=moved and slotAt(p)
 if to and to~=d.Slot then d.Done=os.clock();Inv.Unpick() -- (R155: any slot, the shovel's too; a taken slot swaps, a Bag item sends what was there to the Bag)
  if State:Place(d.Key,to)then note(('%s moved to slot %d (%s)'):format(nameOf(d.Key),to,how));refresh()end
  return
 end
 if d.Lifted and not to and Inv.OverTrash(p)then d.Done=os.clock();Inv.Discard(d.Key,'dropped on the Trash ('..how..')');return end -- R155 (a real drag: a finger that scrolled the grid onto it is no drop)
 if moved and not to and d.Slot and overBag(p)then d.Done=os.clock();Inv.Unpick()
  if State:Stow(d.Key)then note(nameOf(d.Key)..' put in the Bag (its slot stays blank)');refresh()end
  return
 end
 if os.clock()-d.At<8 and onSelf(d,p)and not(d.ScrollY and scroll.CanvasPosition.Y~=d.ScrollY)then Inv.Release(d,'click ('..how..')');return end -- (R155: a hold let go in place picks it: tap-tap)
 if d.Lifted then d.Done=os.clock()else d.Ended=os.clock()end;note('let go away from it ('..how..'): nothing') -- (R155: a lifted item let go in the world is a cancelled drag; an Activated that follows is no click)
end
local function upOn(b,x,y) -- let go over button b: the release of a press that has no InputObject of its own (else UserInputService's InputEnded, or the next frame)
 local d=press;if not d then return end
 local p=fromScreen(b,x,y);if not d.Input then finish(p,'button up')else d.Up=p;d.UpAt=os.clock();wake()end
end
local function activated(b,input,direct)
 local d=lastOf[b];local t=type(input)~='number'and input and input.UserInputType or nil
 if(t==nil or t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch)and d and os.clock()-d.At<8 then
  if d.Done then if os.clock()-d.Done<.5 then return end
  elseif press==d then -- (Activated before the release: a click, unless the pointer is known to be away from its button: a drag the release will drop)
   if not(d.Up and not onSelf(d,d.Up)or(d.Moved or d.Lifted)and not onSelf(d,d.Pos))then Inv.Release(d,'click (Activated)')end;return
  elseif d.Ended and os.clock()-d.Ended<.5 then Inv.Release(d,'click (Activated after the release)');return end
 end
 direct()
end
local function hook(b,slot,keyNow)
 b.Activated:Connect(function(input)activated(b,input,function()local key=keyNow();if not Inv.Click(key,slot,slot and'slot '..slot or'Bag card')and key then equip(key,slot and'slot '..slot or'Bag card')end end)end)
 b.InputBegan:Connect(function(input)beganOn(b,slot,keyNow(),input)end)
 local right=b.MouseButton2Click;if right then right:Connect(function()local key=keyNow();if key then Inv.Pick(key,slot,'right-click')end end)end -- R155: right-click picks it (tap-tap: then click where it goes)
 local down,up=b.MouseButton1Down,b.MouseButton1Up -- (a few test worlds have no such events)
 if down then down:Connect(function(x,y)downOn(b,slot,keyNow(),x,y)end)end
 if up then up:Connect(function(x,y)upOn(b,x,y)end)end
end
tick=function()
 local now=os.clock();local char=player.Character;local d=press
 if d then
  if now-d.At>8 then cancelPress('held over 8 s')
  elseif d.UpAt and now>d.UpAt then finish(d.Up,'button up')
  elseif d.Kind=='mouse'and d.Input and now-d.At>.1 and select(2,pcall(function()return Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)end))==false then finish(nil,'the button is up')
  elseif d.Input and d.Input.UserInputState==Enum.UserInputState.Cancel then cancelPress('the touch was cancelled')
  elseif d.Kind=='touch'and not d.Lifted and not d.Moved and now-d.At>=HOLD then lift(d);follow(d,d.Pos)end
 end
 local p=pending
 if p then
  if not alive(p.Tool)then pending=nil;note(p.Tool.Name..' is gone while on its way')
  elseif p.Queued then
   if now-p.At>QUEUED_SECONDS then pending=nil;note(p.Tool.Name..': waited '..QUEUED_SECONDS..' s, dropped') -- (quietly: the hotbar says nothing)
   elseif knocked()or revealing(char)then p.Clear=nil
   else p.Clear=p.Clear or now;if now-p.Clear>=.35 then pending=nil;equip(p.Key,'its turn came',true)end end -- (the server's own hand-off after a reveal lands first)
  elseif p.Tool.Parent~=char then pending=nil
  else local c=carried(char)
   if c and c~=p.Old then pending=nil;note(('%s in the hand %.2f s after the press'):format(p.Tool.Name,now-p.At))
   elseif now-p.At>4 then pending=nil;note(p.Tool.Name..': no pack in the hand 4 s after the press (the server never held it)')end
  end
 end
 paintPending()
 if not press and not pending and tickConn then tickConn:Disconnect();tickConn=nil end
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
 b:SetAttribute('ButtonSound',false) -- R152: a slot is silent (R150 clicked Equip / Bubble04); ButtonHighlights reads this at click time
 hook(b,i,function()return State.Slots[i]end)
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
-- R123: no rarity emblem; the slot/card border itself carries the rarity (GardenCardMotion.Rarity).
local function rarityBorder(button0,tool)
 local item=tool and(tool:GetAttribute('GardenSeed')or tool:GetAttribute('SeedPackTool')or tool:GetAttribute('HarvestItemTool'))
 local value=item and(rarity(tool)or'')or''
 if button0:GetAttribute('BorderFor')==value then return end
 button0:SetAttribute('BorderFor',value);Theme.CardBorder(button0,value)
end
local function kind(tool)return tool:GetAttribute('HarvestItemTool')and'Fruit'or(tool:GetAttribute('GardenSeed')or tool:GetAttribute('SeedPackTool'))and'Seeds'or'Tools'end
local function weighedName(tool)local kg=Weight.ToolText(tool);local name=Names.Tool(tool,Catalog);return kg~=''and name..' ('..kg..')'or name end
-- R155 (owner: "it should feel responsive"): what the hand holds, painted at once on a press (the slot, its Bag card, the name above the hotbar); cheap with 200 items.
paintHeld=function()
 local char=player.Character;local h=char and char:FindFirstChildOfClass('Tool');local k=h and keyOf[h]
 selectedKey=k
 for i,b in ipairs(slots)do local want=k~=nil and State.Slots[i]==k;if b:GetAttribute('Selected')~=want then b:SetAttribute('Selected',want)end end
 for rowKey,b in pairs(rows)do local want=rowKey==k;if b:GetAttribute('Selected')~=want then b:SetAttribute('Selected',want)end end
 selectedLabel.Text=h and weighedName(h)or'';selectedTraits.Text=h and traits(h)or'';Traits.Style(selectedTraits,Traits.Tool(h));decorate(selectedLabel,h,14)
end
-- R112: identical packs, seeds and fruit share one card/slot with a count; tools stay separate. (R155: the key is InventoryStacks155.Key, shared with the server's discard)
local freeCards={}
local function makeCard()
 local b=button(scroll,'Item','',UDim2.fromOffset(92,92),UDim2.new());b.TextWrapped=true;b.BackgroundColor3=C.Tile
 -- R112: big picture, then a small readable "Name (2.4kg)" under it.
 local art=picture(b);art.Position=UDim2.fromOffset(6,5);art.Size=UDim2.new(1,-12,1,-37)
 local name=label(b,'ItemName',UDim2.new(1,-8,0,28),UDim2.new(0,4,1,-31),'',12);name.ZIndex=3
 local detail=label(b,'ItemTraits',UDim2.new(1,-8,0,13),UDim2.new(0,4,1,-45),'',10);detail.ZIndex=3
 countBadge(b).Position=UDim2.fromOffset(4,4)
 selectionBorder(b);b:SetAttribute('ButtonSound',false) -- R152: a Bag card is silent too (R150: the Equip cue)
 hook(b,nil,function()return b:GetAttribute('InventoryKey')end)
 return b
end
renderRows=function()
 if not panel.Visible then return end
 -- R153: the cards hold still under a finger / the mouse until it lets go (then this runs); a press that scrolls the grid is a scroll, so it lets them go
 if press and press.Card and scroll.CanvasPosition.Y==press.ScrollY then rowsHeld=true;return end
 local changed=listDirty
 if listDirty then
  table.clear(matched);local term=search.Text:lower()
  for key,e in pairs(State.Items)do if not State:Shown(key)and(category=='All'or kind(e.Tool)==category)and(rarityCategory=='All'or rarity(e.Tool)==rarityCategory)and Names.Search(e.Tool,Catalog):find(term,1,true)then table.insert(matched,{Key=key,Entry=e})end end
  table.sort(matched,function(a,b)return a.Entry.Order<b.Entry.Order end);listDirty=false
  for name,b in pairs(filterButtons)do b.BackgroundColor3=name==category and C.TileOn or C.Tile;b:SetAttribute('Selected',name==category)end
 end
 local width=scroll.AbsoluteSize.X;local side=width<400 and 96 or width<640 and 108 or 124; -- R127: bigger cards (were 84/92/104)
 side=math.max(64,math.min(side,scroll.AbsoluteSize.Y-8)) -- R113: short grids get smaller cards.
 local cell=side+8;local cols=math.max(1,math.floor((math.max(1,width-12)+8)/cell))
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
 for rowKey,b in pairs(rows)do if not used[rowKey]then rows[rowKey]=nil;Pictures.Clear(b.Picture)
  paintGlow(b,nil)
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
  rarityBorder(b,tool);b.ItemName.Text=weighedName(tool);b.ItemTraits.Text=traits(tool);Traits.Style(b.ItemTraits,Traits.Tool(tool))
  local count=item.Entry.Count or 1;b.Count.Text='x'..count;b.Count.Visible=count>1
  Pictures.Show(b.Picture,tool,2)
  b:SetAttribute('Selected',tool.Parent==player.Character)
  paintGlow(b,item.Key)
 end
 Inv.PaintPick()
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
 local arrived;local clock=os.clock()
 for k,at in pairs(released)do if clock-at>6 then released[k]=nil end end
 -- R153: a tool that is no stack and has no inventory id (the bat) is keyed by its name (+ a number for a second one), not by when it arrived: the one the
 -- server hands back after a respawn is the same item and keeps its slot (R152: 'tool-<n>', a new key each time).
 local loose,renames,add={},nil,nil
 local function take(tool)
  if not tool:IsA('Tool')or not(seen[tool]or not(Arrival.Holds(tool)or Collect~=nil and Collect.Holds(tool)))then return end -- (R154: and a pull's seed until it has flown in)
  -- (R149: only a tool that was never shown is held back; an older fruit of the same plant and slot keeps its place while the new one flies)
  local isNew=not seen[tool]
  if isNew then sequence+=1;seen[tool]=sequence end
  local key=Inv.Key(tool)or Info.Key(tool)
  if not key then table.insert(loose,tool);return end
  add(tool,key,isNew)
 end
 add=function(tool,key,isNew)
  notePack(tool,key)local order=tool:GetAttribute('GardenShovel')and-1 or seen[tool];local e=items[key]
  local was=keyOf[tool];if was and was~=key then renames=renames or{};renames[was]=key end;keyOf[tool]=key
  local arrival=isNew and released[Arrival.ToolKey(tool)or'']
  if arrival then released[Arrival.ToolKey(tool)]=nil;arrived=arrived or{};arrived[key]=true end
  if not e then items[key]={Tool=tool,Order=order,Count=1}
  else -- The equipped copy, else the oldest, represents a stack.
   e.Count+=1;e.Order=math.min(e.Order,order)
   if tool.Parent==player.Character or(e.Tool.Parent~=player.Character and seen[tool]<seen[e.Tool])then e.Tool=tool end
  end
  if tool.Parent==player.Character then selectedKey=key end
  if not toolConns[tool]then toolConns[tool]=watchTool(tool,function()refresh()end)end
 end
 for _,container in ipairs(containers)do for _,tool in ipairs(container:GetChildren())do guard('an item',take,tool)end end
 table.sort(loose,function(a,b)return seen[a]<seen[b]end);local named={}
 for _,tool in ipairs(loose)do local n=(named[tool.Name]or 0)+1;named[tool.Name]=n;guard('an item',add,tool,'tool|'..tool.Name..(n>1 and'|'..n or''),false)end
 for tool,c in pairs(toolConns)do if tool.Parent~=bag and tool.Parent~=player.Character then c:Disconnect();toolConns[tool]=nil end end
 State:Reconcile(items,renames);listDirty=true
 -- R113: build every look in the bag ahead of time (time-sliced), in inventory order.
 local ordered={};for _,e in pairs(items)do table.insert(ordered,e)end;table.sort(ordered,function(a,b)return a.Order<b.Order end)
 for i,e in ipairs(ordered)do ordered[i]=e.Tool end;guard('the picture cache',Pictures.Prefetch,ordered)
 local active=selectedKey and items[selectedKey];if not active or active.Tool.Parent~=player.Character then selectedKey=nil end
 local selectedTool=selectedKey and items[selectedKey].Tool
 selectedLabel.Text=selectedTool and weighedName(selectedTool)or''
 selectedTraits.Text=selectedTool and traits(selectedTool)or'';Traits.Style(selectedTraits,Traits.Tool(selectedTool))
 decorate(selectedLabel,selectedTool,14)
 for i,b in ipairs(slots)do guard('a slot',function()
  local e=items[State.Slots[i]];local tool=e and e.Tool
  b.ItemName.Text=tool and Names.Tool(tool,Catalog)or'';tint(b.ItemName,tool and rarity(tool)or'Common')
  b.ItemWeight.Text=tool and Weight.ToolText(tool)or'';Traits.Style(b.ItemWeight,Traits.Tool(tool))
  local count=e and e.Count or 0;b.Count.Text='x'..count;b.Count.Visible=count>1;Pictures.Show(b.Picture,tool,1)
  rarityBorder(b,tool);b:SetAttribute('Selected',e~=nil and tool.Parent==player.Character);b.BackgroundTransparency=e and .10 or .50
  paintGlow(b,e and State.Slots[i]or nil)
 end)end
 guard('the Bag',renderRows);paintPending();guard('the Bag bar',Inv.AfterRefresh)
 if arrived then
  -- R150: the "it landed in your bag" cue belongs to this flash (the fruit's arrival), not to the server reply that lifted it off.
  Audio.Play('Bubble06')
  for key in pairs(arrived)do
   local shown=false
   for i,b in ipairs(slots)do if b.Visible and State.Slots[i]==key then flash(b);shown=true end end
   if not shown then flash(open)end
   if panel.Visible and rows[key]then flash(rows[key])end
  end
 end
end
-- R113: HUD boxes that stay on screen while the bag is open (same metrics HudLayout gives each HUD script).
local function hudBoxes(m,w,h)
 local shared=require(RS.HudLayout).HudBoxes
 -- R129: on landscape phones the balances, timers, menu stack and BASE/TRACK hide while the Bag is open (SeedMenu), so
 -- the sheet only has to clear the hotbar and the jump button.
 if shared and m.PhoneWide then local out={};for _,x in ipairs(shared(m,w,h,false))do if x.N=='Hotbar'or x.N=='Jump'then out[#out+1]=x end end;return out end
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
-- Places the sheet and returns where the category cards go: 'Left' of the sheet (1 or 2 cards wide) or a 'Row' above it.
local function placeTabs(m,w,h)
 local boxes=hudBoxes(m,w,h);local gap=8
 local function clear(x,y,bw,bh)
  if x<4 or y<4 or x+bw>w-4 or y+bh>h-4 then return false end
  for _,b in ipairs(boxes)do if x<b.X+b.W+4 and x+bw>b.X-4 and y<b.Y+b.H+4 and y+bh>b.Y-4 then return false end end
  return true
 end
 local maxWidth,wanted=math.min(1080,w*.9),math.min(740,h*.74) -- R127 (owner): bigger Bag sheet (was 900 x 620, 86% x 66%)
 local function place(width)
  MenuStyle.Place(panel,pg,width,wanted)
  return panel.Size.X.Offset,panel.Size.Y.Offset,panel.Position.X.Offset,panel.Position.Y.Offset
 end
 -- Left: for each card size (1 or 2 cards wide) the widest sheet whose cards clear the HUD (sliding the cards down the sheet edge,
 -- if needed; tiny screens may raise the whole sheet up to 48 px instead). R113b: cards never stick out above the
 -- sheet's top edge (owner saw "All" poking out). Best grid area x card size wins, a single column preferred.
 local best
 local function left(t,across,minWidth,lift)
  local bw,bh=across*t+(across-1)*6,(4/across)*t+(4/across-1)*6;local width=maxWidth
  while width>=minWidth do
   local sw,sh,cx,cy=place(width);cx+=(bw+gap)/2;local top=cy-sh/2;local x=cx-sw/2-gap-bw
   if sw+bw+gap<=w-16 then
    local shifts={0};for k=8,sh,8 do if k+bh<=sh then table.insert(shifts,k)end;if k<=lift and top-k>=8 then table.insert(shifts,-k)end end
    for _,dy in ipairs(shifts)do
     if bh<=sh and clear(x,top+dy,bw,bh)then
      -- dy<0: raise the whole sheet by -dy so the cards stay level with its top edge.
      local score=sw*sh*(t/72)*(across==1 and 1.25 or 1)*(1-math.max(0,-dy)/300)
      if not best or score>best.Score then best={Score=score,Width=width,T=t,Across=across,Dy=math.max(0,dy),Raise=math.max(0,-dy),Shift=(bw+gap)/2}end
      return
     end
    end
   end
   width-=20
  end
 end
 for _,lift in ipairs({0,48})do -- raise the sheet only when nothing fits without it
  if not best then for _,t in ipairs({84,72,64,56,48,44})do left(t,1,math.min(maxWidth,220),lift);left(t,2,math.min(maxWidth,220),lift)end end
 end
 if best then
  local _,_,cx,cy=place(best.Width);panel.Position=UDim2.fromOffset(cx+best.Shift,cy-best.Raise);return 'Left',best.T,best.Across,best.Dy
 end
 -- Row: the sheet moves down by one card; the row sits at its left edge, right edge or centre.
 for _,t in ipairs({64,56,48,44})do
  local sw,sh,cx,cy=place(maxWidth);local rowWidth=4*t+18;local top=cy-sh/2
  if sh-t-gap>=180 then
   for _,x in ipairs({0,sw-rowWidth,(sw-rowWidth)/2})do
    if clear(cx-sw/2+x,top,rowWidth,t)then panel.Size=UDim2.fromOffset(sw,sh-t-gap);panel.Position=UDim2.fromOffset(cx,cy+(t+gap)/2);return 'Row',t,4,x end
   end
  end
 end
 local sw,sh,cx,cy=place(maxWidth);panel.Size=UDim2.fromOffset(sw,sh-52);panel.Position=UDim2.fromOffset(cx,cy+26);return 'Row',44,4,0
end
layout=function()
 local camera=workspace.CurrentCamera;local view=require(RS.HudLayout).Viewport(gui);local width=view.X
 local metrics=require(RS.HudLayout).Read(view,Input.TouchEnabled,require(RS.HudLayout).Controls(gui))
 showSelectedDetails=metrics.HotbarDetails~=false
 selectedLabel.Visible=showSelectedDetails and not panel.Visible;selectedTraits.Visible=showSelectedDetails and not panel.Visible
 visibleSlots=metrics.Slots;if State.Visible~=visibleSlots then State.Visible=visibleSlots;listDirty=true;queue()end -- (R155: an item on a slot this screen does not show is a Bag item here)
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
 -- R113: raised hotbars (portrait phones sit it above the thumb controls) reserve their real height, so sheets end above it.
 local reserve=side+78+math.max(0,(metrics.HotbarBottom or 12)-12)
 if pg:GetAttribute('ChestHotbarReserve')~=reserve then pg:SetAttribute('ChestHotbarReserve',reserve)end
 local height=view.Y
 -- R113: category cards sit outside the sheet: a column (or 2x2 block) on its left, else a row above it; never over the HUD.
 local mode,tab,across,rowX=placeTabs(metrics,width,height) -- rowX: row x, or the column's vertical shift
 local sheetWidth,sheetHeight=panel.Size.X.Offset,panel.Size.Y.Offset;local title=panel.Title
 local tabGap=8;local caption=math.max(11,math.floor(tab*.2));local blockWidth,blockHeight=across*tab+(across-1)*6,(4/across)*tab+(4/across-1)*6
 if mode=='Left'then filters.Position=UDim2.fromOffset(-(blockWidth+tabGap),rowX)else filters.Position=UDim2.fromOffset(rowX,-(tab+tabGap))end
 filters.Size=UDim2.fromOffset(blockWidth,blockHeight)
 for i,name in ipairs({'All','Seeds','Fruit','Tools'})do
  local b=filterButtons[name];b.Size=UDim2.fromOffset(tab,tab);b.Position=UDim2.fromOffset((i-1)%across*(tab+6),math.floor((i-1)/across)*(tab+6))
  b.Picture.Position=UDim2.fromOffset(4,3);b.Picture.Size=UDim2.new(1,-8,1,-(caption+7))
  b.Caption.Position=UDim2.new(0,2,1,-(caption+4));b.Caption.Size=UDim2.new(1,-4,0,caption+2);Fit.Attach(b.Caption,caption,8)
 end
 local short=sheetHeight<300;panel.Hint.Visible=not short;title.Visible=not short or sheetWidth>=440
 if short then
  -- Short sheets (phones): search and rarity share the header (with the title when it fits); the grid gets the rest.
  local room=sheetWidth-66-(title.Visible and 126 or 16);local rarityWidth=math.min(150,math.floor(room*.38));local searchWidth=room-rarityWidth-8
  title.Size=UDim2.fromOffset(110,36)
  search.Position=UDim2.new(1,-(searchWidth+rarityWidth+66),0,12);search.Size=UDim2.fromOffset(searchWidth,30)
  rarityFilter.Position=UDim2.new(1,-(rarityWidth+58),0,12);rarityFilter.Size=UDim2.fromOffset(rarityWidth,30)
  rarityMenu.Position=UDim2.fromOffset(16,48);rarityMenu.Size=UDim2.new(1,-32,0,110)
  scroll.Position=UDim2.fromOffset(16,54);scroll.Size=UDim2.new(1,-32,1,-92) -- (R155: the Bag bar below: count, Trash)
 elseif sheetWidth>=560 then
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
 Inv.Layout(short,sheetWidth)
 renderRows()
end
local function character(char)
 for _,c in ipairs(characterConns)do c:Disconnect()end;table.clear(characterConns)
 if char then table.insert(characterConns,char.ChildAdded:Connect(function(c)moved(c,true);queue()end));table.insert(characterConns,char.ChildRemoved:Connect(queue))end;queue()
end
local bagConns={}
local function watchBag(nextBag)
 if bag and nextBag~=bag then State:Remember()end -- R153: a new Backpack (respawn): every item goes back to its slot when the server hands it back
 for _,c in ipairs(bagConns)do c:Disconnect()end;table.clear(bagConns);bag=nextBag
 table.insert(bagConns,bag.ChildAdded:Connect(function(c)moved(c,false);queue()end));table.insert(bagConns,bag.ChildRemoved:Connect(queue));queue()
end
connect(player.ChildAdded,function(child)if child:IsA('Backpack')then watchBag(child)end end)
connect(panel:GetPropertyChangedSignal('Visible'),function()if next(fresh)then listDirty=true;renderRows()end end)
watchBag(bag);connect(player.CharacterAdded,character);character(player.Character)
if player.CharacterRemoving then connect(player.CharacterRemoving,function()State:Remember();cancelPress('respawn');Inv.Unpick('respawn');pending=nil;note('respawn: the hotbar keeps its order')end)end
-- A hold ended (the fruit arrived, or none will): show the item now. `cue` is false for a request that failed (nothing to celebrate).
table.insert(allConns,Arrival.OnRelease(function(k,cue)if cue then released[k]=os.clock()end;queue()end))
connect(search:GetPropertyChangedSignal('Text'),function()listDirty=true;scroll.CanvasPosition=Vector2.zero;renderRows();Inv.PaintSearch()end)
connect(scroll:GetPropertyChangedSignal('CanvasPosition'),function()Pictures.Hurry();renderRows()end);connect(scroll:GetPropertyChangedSignal('AbsoluteSize'),renderRows)
connect(pg:GetAttributeChangedSignal('SeedMenu'),function()dock.Visible=(pg:GetAttribute('SeedMenu')==nil or pg:GetAttribute('SeedMenu')=='Inventory');if panel.Visible and pg:GetAttribute('SeedMenu')~='Inventory'then toggle(false)end end)
connect(Input.InputChanged,function(input) -- R153: the press follows ITS pointer: the mouse, or its own touch (the first touch near it when the engine gave no InputObject)
 local d=press;if not d or d.Done then return end
 local t=input.UserInputType
 if d.Kind=='mouse'then if t~=Enum.UserInputType.MouseMovement then return end
 elseif t~=Enum.UserInputType.Touch then return
 elseif d.Input then if input~=d.Input then return end
 elseif(fromInput(input)-d.Pos).Magnitude>60 then return else d.Input=input end
 local p=fromInput(input);d.Pos=p;d.Tracked=true
 if not d.Moved and(p-d.Start).Magnitude>MOVE then d.Moved=true end
 -- (a Bag card on a phone is picked up when it leaves the grid, or by the hold: a finger moving inside the grid scrolls it)
 if d.Moved and not d.Lifted and(not d.Card or d.Kind=='mouse'or not within(scroll,p))then lift(d)end
 if d.Lifted then follow(d,p)end
end)
connect(Input.InputEnded,function(input)
 -- (a press ends with ITS OWN release: a touch with that touch, a mouse press with the mouse button; a touch the system cancelled never ends, and a later
 --  unrelated mouse release must not be taken for its end)
 local d=press;if not d then return end
 local t=input.UserInputType
 if d.Kind=='mouse'then if t~=Enum.UserInputType.MouseButton1 then return end
 elseif t~=Enum.UserInputType.Touch or(d.Input and input~=d.Input)or(not d.Input and(fromInput(input)-d.Pos).Magnitude>60)then return end
 finish(fromInput(input),'release')
end)
local numbers={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8,[Enum.KeyCode.Nine]=9,[Enum.KeyCode.Zero]=10}
connect(Input.InputBegan,function(input,processed)
 if kindOf(input)then -- (R153: a press that began on MouseButton1Down learns its InputObject here, whichever came first)
  lastBegan={Input=input,At=os.clock()}
  local d=press;if d and not d.Input and os.clock()-d.At<.05 then local p=lineUp(d.Button,input);if p then d.Input=input;d.Kind=kindOf(input);d.Start=p;d.Pos=p end end
 end
 if processed or Input:GetFocusedTextBox()then return end
 if input.KeyCode==Enum.KeyCode.Backquote or input.KeyCode==Enum.KeyCode.B then toggle(not panel.Visible)
 elseif numbers[input.KeyCode]and(pg:GetAttribute('SeedMenu')==nil or pg:GetAttribute('SeedMenu')=='Inventory')then local n=numbers[input.KeyCode];local key=State.Slots[n];if not Inv.Click(key,n,'key '..(n%10))and key then equip(key,'key '..(n%10))end -- (R152: with the Bag open a number key equips too; R155: with an item picked it puts it on that slot)
 elseif input.KeyCode==Enum.KeyCode.Escape and panel.Visible then if Inv.PopupEsc()then return elseif Inv.Picked()then Inv.Unpick('Esc')else toggle(false)end end -- (R155: Esc in the discard popup closes only the popup)
end)
CAS:BindAction('GardenHotbarCycle',function(_,state,input)
 if state~=Enum.UserInputState.Begin or pg:GetAttribute('SeedMenu')then return Enum.ContextActionResult.Pass end
 local current=0;for i=1,visibleSlots do if State.Slots[i]==selectedKey then current=i end end
 local direction=input.KeyCode==Enum.KeyCode.ButtonL1 and-1 or 1
 for offset=1,visibleSlots do local index=(current-1+offset*direction)%visibleSlots+1;local key=State.Slots[index];if key then equip(key,'L1 / R1');break end end
 return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
selectionBorder(open);Theme.CardBorder(open,'Common')
open.Activated:Connect(function()if Inv.Picked()and Inv.Picked().Slot then Inv.Stash('the Bag button')else toggle(not panel.Visible)end end);close.Activated:Connect(function()toggle(false)end) -- (R155: with a hotbar item picked the Bag button takes it)
if open.MouseButton1Up then connect(open.MouseButton1Up,function(x,y)upOn(open,x,y)end)end -- (R153: let go over the Bag button)
-- R153 debug aid: /test hotbar (an owner command) turns the player's HotbarLog on / off: a box top-left with the last lines (select them to copy) and every new
-- line in the F9 console. The first line says what this device is; the server's own reply lists the packs it held late or refused, with why.
local function showLog()
 local on=player:GetAttribute('HotbarLog')==true
 if on and not logBox then
  local f=Instance.new('Frame');f.Name='HotbarLog';f.BackgroundColor3=Color3.fromRGB(10,22,17);f.BackgroundTransparency=.12;f.BorderSizePixel=0;f.Position=UDim2.fromOffset(8,8);f.ZIndex=60;f.Parent=gui;corner(f)
  f.Size=UDim2.fromOffset(math.clamp((gui.AbsoluteSize.X>0 and gui.AbsoluteSize.X or 600)-16,240,520),250)
  local t=Instance.new('TextLabel');t.Name='Title';t.BackgroundTransparency=1;t.Position=UDim2.fromOffset(8,4);t.Size=UDim2.new(1,-16,0,16);t.Font=Theme.Bold;t.TextSize=12;t.TextColor3=C.Green
  t.TextXAlignment=Enum.TextXAlignment.Left;t.Text='HOTBAR LOG - select the text to copy it (also in F9) - /test hotbar hides it';t.ZIndex=61;t.Parent=f
  logBox=Instance.new('TextBox');logBox.Name='Lines';logBox.BackgroundTransparency=1;logBox.Position=UDim2.fromOffset(8,22);logBox.Size=UDim2.new(1,-16,1,-28);logBox.Font=Enum.Font.Code;logBox.TextSize=11;logBox.TextColor3=C.Text
  logBox.TextXAlignment=Enum.TextXAlignment.Left;logBox.TextYAlignment=Enum.TextYAlignment.Bottom;logBox.TextWrapped=true;logBox.MultiLine=true;logBox.ClearTextOnFocus=false;logBox.TextEditable=false;logBox.ZIndex=61;logBox.Parent=f
 end
 if logBox then logBox.Parent.Visible=on end
 if not on then return end
 local cam=workspace.CurrentCamera;local i=inset();local list={}
 for k=1,10 do if State.Slots[k]then list[#list+1]=k..'='..nameOf(State.Slots[k])end end
 note(('log on: touch %s, mouse %s, screen %s, inset %.0f,%.0f, shifts %.0f,%.0f / %s, %d slots shown, held %s, waiting %s'):format(tostring(Input.TouchEnabled),tostring(Input.MouseEnabled),
  cam and('%.0fx%.0f'):format(cam.ViewportSize.X,cam.ViewportSize.Y)or'?',i.X,i.Y,objShift.X,objShift.Y,screenShift and('%.0f,%.0f'):format(screenShift.X,screenShift.Y)or'-',visibleSlots,
  player.Character and player.Character:FindFirstChildOfClass('Tool')and player.Character:FindFirstChildOfClass('Tool').Name or'nothing',pending and pending.Tool.Name or'nothing'))
 note('slots: '..table.concat(list,', '))
end
connect(player:GetAttributeChangedSignal('HotbarLog'),showLog);if player:GetAttribute('HotbarLog')==true then task.defer(showLog)end
-- R154 (owner: "... the seed stays on the player's screen until they click and the seed goes to their inventory"): a pull reveal's seed is held out of
-- the hotbar until it has flown in (SeedCollect154; take() above), like a harvested fruit. Where it lands: the slot of the stack it joins, else the slot it
-- will take (the first free one; the opened pack's own when that was its only one), else the Bag button. On arrival it shows and that slot (or the Bag)
-- flashes; the flight plays the arrival cue (Bubble06) on that frame.
if Collect then
 local function fits(tool,spec)for k,v in pairs(spec)do if tostring(tool:GetAttribute(k))~=tostring(v)then return false end end;return true end
 local function onBar(k)for i=1,visibleSlots do if State.Slots[i]==k and slots[i].Visible then return slots[i]end end;return nil end
 local function target(id,spec) -- the button, whether the item is on show there now, its key
  if id==nil then return open,true end -- (an owner preview: nothing is granted)
  local tool
  for _,c in ipairs({bag,player.Character or bag})do for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')and t:GetAttribute('GardenSeed')and t:GetAttribute('SeedInventoryId')==id then tool=t end end end
  local key=tool and(Inv.Key(tool)or Info.Key(tool));local shown=tool~=nil and seen[tool]~=nil
  if key then local b=onBar(key);if b then return b,shown,key end end
  if shown then return open,true,key end -- (on show, in the Bag: not on a visible slot)
  if not tool and spec then for k,e in pairs(State.Items)do if e.Tool:GetAttribute('GardenSeed')and fits(e.Tool,spec)then local b=onBar(k);return b or open,false,k end end end -- (the stack it joins: on the hotbar, or in the Bag)
  -- R155: the slot it will really take (GardenInventoryState:Target, the rule a new item follows: the first free slot that is not blank, the opened pack's own slot
  -- when it was the last of its stack), else the Bag button
  local freeing;for i=1,10 do local k=State.Slots[i];local e=k and State.Items[k];if e and e.Count==1 and e.Tool:GetAttribute('SeedPackTool')and e.Tool:GetAttribute('SeedInventoryId')==id then freeing=k end end
  local i=State:Target(key,freeing)
  if i and slots[i]and slots[i].Visible then return slots[i],false,key end
  return open,false,key
 end
 Collect.SetTarget(function(id,spec)if not(gui.Enabled and dock.Visible)then return nil,false end;return target(id,spec)end)
 table.insert(allConns,Collect.OnRelease(function(id,cue)
  refresh()
  if not cue then return end
  local b,_,key=target(id,nil);if b then flash(b)end
  if panel.Visible and key and rows[key]then flash(rows[key])end
  note('a pull\'s seed flew in ('..tostring(id)..')')
 end))
end
Inv.Start({player=player,pg=pg,gui=gui,dock=dock,panel=panel,open=open,scroll=scroll,search=search,slots=slots,rows=rows,State=State,Names=Names,Catalog=Catalog,Theme=Theme,C=C,
 refresh=function()refresh()end,toggle=toggle,equip=function(k,how)equip(k,how)end,note=note,cover=cover,corner=corner,button=button}) -- R155: the Bag bar, tap-tap, discarding, the saved layout
local stopHudLayout=require(RS.HudLayout).Watch(gui,layout)
connect(pg:GetAttributeChangedSignal('HudNoticeBottom'),layout);refresh()
for attempt=1,5 do local okay=pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)end);if okay then break end;task.wait(.2)end
script.Destroying:Connect(function()
 if glowConn then glowConn:Disconnect();glowConn=nil end
 if flashConn then flashConn:Disconnect();flashConn=nil end
 if tickConn then tickConn:Disconnect();tickConn=nil end
 for _,c in ipairs(allConns)do c:Disconnect()end;for _,c in ipairs(characterConns)do c:Disconnect()end;for _,c in pairs(toolConns)do c:Disconnect()end
 for _,c in ipairs(bagConns)do c:Disconnect()end
 stopHudLayout();CAS:UnbindAction('GardenHotbarCycle');pg:SetAttribute('ChestHotbarReserve',nil);Inv.Stop();gui:Destroy()
 pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,true)end)
end)
