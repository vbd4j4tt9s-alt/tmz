-- R155 (owner: "hot bar and inventory management is still not fixed just make it function like the normal inventory (not look like) it should feel responsive
-- and i have a lot of options to manage my inventory i can have a blank hot bar if i put everything in my bag additionally make the max amount of items a
-- person can hold 200", then "allow people to discard items"). The Bag's management half, started by the Hotbar (Hotbar.client.lua keeps the presses, the
-- drag, equipping and drawing; GardenInventoryState keeps the layout rules). One Hotbar per client, so this module is its single instance.
--  * the bottom bar of the Bag: the hint (or, while an item is picked, what to do with it), the count "143/200" (amber from 180, red and FULL at 200; the
--    Bag button shows FULL too) and the Trash (drop an item on it, or tap it while an item is picked: the confirm popup, DiscardDialog155).
--  * tap-tap (phones, and everyone): hold an item (0.4 s) and let go without moving it, or right-click it, or press Y on a gamepad: it is PICKED (a
--    green ring; every slot it can go to is outlined; the Bag opens). Then tap a slot (or press its number key) = put it there (swap if taken); tap a Bag
--    card or "To Bag" (or the Bag button) = into the Bag (its slot stays blank); tap the Trash = discard; "Hold" = hold it; tap it again or the X = put it down.
--  * search: Bag cards filter; hotbar slots that do not match dim.
--  * the layout is sent to the server (ChestChaseRemotes.HotbarLayout155) a moment after it changes; at join the saved one (the player attribute
--    HotbarLayout155) puts each item back on its slot, and once the server says every item is there (InventorySynced155) new items are placed as new.
local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService');local GuiService=game:GetService('GuiService')
local CAS=game:GetService('ContextActionService')
local Stacks=require(RS:WaitForChild('InventoryStacks155'));local Dialog=require(RS:WaitForChild('DiscardDialog155'))
local M={Stacks=Stacks,Key=Stacks.Key,Dialog=Dialog,Cap=Stacks.Cap,SaveDelay=2,LiveDelay=1,JoinFallback=8}
local ctx,picked,ui,conns=nil,nil,{},{}
local RED,AMBER=Color3.fromRGB(255,96,96),Color3.fromRGB(255,190,70)
local lastSent,saveDue,lastVersion=nil,nil,-1
local function on(sig,fn)if sig then conns[#conns+1]=sig:Connect(fn)end end
local function note(t)if ctx and ctx.note then ctx.note(t)end end
local function nameOf(key)local e=key and ctx.State.Items[key];if not e then return tostring(key)end;local ok,n=pcall(ctx.Names.Tool,e.Tool,ctx.Catalog);return ok and n or e.Tool.Name end
-- The bottom bar ------------------------------------------------------------------------------------------------------------------------------------------
local function build()
 local panel,C=ctx.panel,ctx.C
 local bar=Instance.new('Frame');bar.Name='BagBar';bar.BackgroundTransparency=1;bar.Size=UDim2.new(1,-32,0,30);bar.Position=UDim2.new(0,16,1,-36);bar.ZIndex=2;bar.Parent=panel
 local trash=ctx.button(bar,'Trash','🗑 Discard',UDim2.fromOffset(104,30),UDim2.new(1,-104,0,0));trash.BackgroundColor3=Color3.fromRGB(122,44,52);trash.TextSize=13
 trash:SetAttribute('ButtonSound',false)
 do local f=Instance.new('Frame');f.Name='DropTarget';f.BackgroundColor3=RED;f.BackgroundTransparency=.55;f.BorderSizePixel=0;f.Size=UDim2.fromScale(1,1);f.Active=false;f.ZIndex=(trash.ZIndex or 1)+8;f.Visible=false;f.Parent=trash;ctx.corner(f)
  local s=Instance.new('UIStroke');s.Color=RED;s.Thickness=3;s.Parent=f end
 local count=Instance.new('TextLabel');count.Name='HeldCount';count.BackgroundColor3=C.Well;count.BackgroundTransparency=.1;count.Size=UDim2.fromOffset(88,30);count.Position=UDim2.new(1,-200,0,0)
 count.Font=ctx.Theme.Bold;count.TextSize=15;count.TextColor3=C.Text;count.Text='0/200';count.ZIndex=3;count.Parent=bar;ctx.corner(count)
 local pick=Instance.new('Frame');pick.Name='PickBar';pick.BackgroundTransparency=1;pick.Size=UDim2.new(1,-212,1,0);pick.Visible=false;pick.ZIndex=3;pick.Parent=bar
 local what=Instance.new('TextLabel');what.Name='PickName';what.BackgroundTransparency=1;what.Size=UDim2.new(1,-206,1,0);what.Font=ctx.Theme.Font;what.TextSize=13;what.TextColor3=C.Green
 what.TextXAlignment=Enum.TextXAlignment.Left;what.TextWrapped=true;what.TextScaled=true;what.Text='';what.ZIndex=3;what.Parent=pick
 do local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=13;fit.MinTextSize=8;fit.Parent=what end
 local hold=ctx.button(pick,'PickHold','Hold',UDim2.fromOffset(62,30),UDim2.new(1,-202,0,0));hold.BackgroundColor3=C.TileOn;hold.TextSize=13
 local stash=ctx.button(pick,'PickStash','To Bag',UDim2.fromOffset(72,30),UDim2.new(1,-136,0,0));stash.BackgroundColor3=C.Tile;stash.TextSize=13
 local cancel=ctx.button(pick,'PickCancel','✕',UDim2.fromOffset(56,30),UDim2.new(1,-60,0,0));cancel.BackgroundColor3=C.Tile;cancel.TextSize=15
 for _,b in ipairs({hold,stash,cancel})do b:SetAttribute('ButtonSound',false)end
 local badge=Instance.new('TextLabel');badge.Name='FullBadge';badge.Text='FULL';badge.BackgroundColor3=RED;badge.TextColor3=Color3.new(1,1,1);badge.Font=ctx.Theme.Bold;badge.TextSize=11
 badge.AnchorPoint=Vector2.new(.5,0);badge.Position=UDim2.new(.5,0,0,-9);badge.Size=UDim2.fromOffset(40,16);badge.Visible=false;badge.ZIndex=8;badge.Parent=ctx.open;ctx.corner(badge)
 ui={Bar=bar,Trash=trash,Count=count,Pick=pick,What=what,Hold=hold,Stash=stash,Cancel=cancel,Badge=badge}
 M.TrashButton=trash
end
local function held()
 local p=ctx.player;local n=p:GetAttribute('HeldItemCount');local cap=p:GetAttribute('HeldItemCap')
 if type(n)~='number'then n=0;for _,e in pairs(ctx.State.Items)do if Stacks.Counts(e.Tool)then n+=e.Count or 1 end end end
 return n,type(cap)=='number'and cap or M.Cap
end
local function paintCount()
 if not ui.Count then return end
 local n,cap=held();local full=n>=cap
 local text=full and(n..'/'..cap..' FULL')or(n..'/'..cap)
 if ui.Count.Text~=text then ui.Count.Text=text end
 local color=full and RED or n>=math.floor(cap*.9)and AMBER or ctx.C.Text
 if ui.Count.TextColor3~=color then ui.Count.TextColor3=color end
 ui.Count.Size=UDim2.fromOffset(full and 112 or 88,30);ui.Count.Position=UDim2.new(1,full and-224 or-200,0,0)
 if ui.Badge.Visible~=full then ui.Badge.Visible=full end
end
M.Held=held
-- Picking (tap-tap) -----------------------------------------------------------------------------------------------------------------------------------
local hints={}
local function hintOf(b)
 local h=b:FindFirstChild('DropHint')
 if not h then
  h=Instance.new('Frame');h.Name='DropHint';h.BackgroundTransparency=1;h.Size=UDim2.fromScale(1,1);h.Active=false;h.ZIndex=(b.ZIndex or 1)+7;h.Visible=false;h.Parent=b;ctx.corner(h)
  local s=Instance.new('UIStroke');s.Name='Line';s.Color=ctx.C.Green;s.Thickness=2;s.Transparency=.3;s.Parent=h
 end
 return h
end
local function ringOf(b)
 local r=b:FindFirstChild('PickedRing')
 if not r then
  r=Instance.new('Frame');r.Name='PickedRing';r.BackgroundColor3=ctx.C.Green;r.BackgroundTransparency=.78;r.Size=UDim2.fromScale(1,1);r.Active=false;r.ZIndex=(b.ZIndex or 1)+7;r.Visible=false;r.Parent=b;ctx.corner(r)
  local s=Instance.new('UIStroke');s.Name='Line';s.Color=Color3.new(1,1,1);s.Thickness=3;s.Parent=r
 end
 return r
end
local ringOn
local drag -- a drag in progress (the Hotbar's lift): its drop targets are outlined as a picked item's are ({Slot=n}, or Slot=nil from the Bag)
local function paintPick()
 local State=ctx.State
 if picked and not State.Items[picked.Key]then M.Unpick('it is gone');return end
 local src
 if picked then picked.Slot=State:Shown(picked.Key);src=picked.Slot and ctx.slots[picked.Slot]or ctx.rows[picked.Key]end
 if ringOn and ringOn~=src then local r=ringOn:FindFirstChild('PickedRing');if r then r.Visible=false end;ringOn=nil end
 if src then ringOf(src).Visible=true;ringOn=src end
 for i,b in ipairs(ctx.slots)do
  local want=b.Visible and((picked~=nil and i~=picked.Slot)or(drag~=nil and i~=drag.Slot))
  if want then hintOf(b).Visible=true;hints[b]=true elseif hints[b]then local h=b:FindFirstChild('DropHint');if h then h.Visible=false end;hints[b]=nil end
 end
 if ui.Pick then
  ui.Pick.Visible=picked~=nil;if ctx.panel:FindFirstChild('Hint')then ctx.panel.Hint.Visible=picked==nil and ctx.panel.Hint:GetAttribute('Room')~=false end
  if picked then
   local e=State.Items[picked.Key];local n=e and e.Count or 1
   ui.What.Text='Moving '..nameOf(picked.Key)..(n>1 and' x'..n or'')..(picked.Slot and' - tap a slot, the Bag or 🗑'or' - tap a slot or 🗑')
   ui.Stash.Visible=picked.Slot~=nil
  end
 end
end
function M.Picked()return picked end
function M.Layout155()return ctx and ctx.State end -- (tests / the owner's debugging: the hotbar's layout model)
function M.Pick(key,slot,how)
 if not key or not ctx.State.Items[key]then return false end
 if picked and picked.Key==key then M.Unpick('picked again');return false end
 picked={Key=key,Slot=slot,At=os.clock()}
 note(('picked %s (%s)%s'):format(nameOf(key),how or'hold',slot and' from slot '..slot or' from the Bag'))
 if not ctx.panel.Visible then ctx.toggle(true)end
 paintPick();return true
end
function M.Unpick(why)
 if not picked then return end
 local k=picked.Key;picked=nil;if why then note('put down '..nameOf(k)..' ('..why..')')end
 paintPick()
end
local function done(text)note(text);ctx.refresh();paintPick()end
-- A press let go on its own slot / card (the Hotbar's click): a hold let go in place picks it; with an item picked it is where that goes; else the Hotbar equips it.
function M.Release(d,how)
 d.Done=os.clock()
 if d.Lifted and not d.Moved then M.Pick(d.Key,d.Slot,'hold, '..how);return end
 if M.Click(d.Key,d.Slot,how)then return end
 ctx.equip(d.Key,how)
end
function M.PaintPick()if ctx then paintPick()end end
-- The Hotbar lifts an item (mouse drag / a phone's hold) and lets it go: every slot it can go to is outlined meanwhile ("clear drop targets" on a phone too).
function M.Dragging(on,slot)if not on and not drag then return end;drag=on and{Slot=slot}or nil;if ctx then paintPick()end end
-- A click on a slot (slot = its number, key = what is on it or nil) or on a Bag card (slot nil) while an item is picked. True = handled (no equip).
function M.Click(key,slot,how)
 if not picked then return false end
 local State=ctx.State;local k=picked.Key
 if slot then
  if slot==State:Shown(k)then M.Unpick('pressed again');return true end
  if State:Place(k,slot)then picked=nil;done(('%s put on slot %d (%s)'):format(nameOf(k),slot,how or'tap'))else M.Unpick('can\'t go there')end
  return true
 end
 if key==k then M.Unpick('pressed again');return true end
 if State:Shown(k)then M.Stash(how)return true end
 return M.Pick(key,nil,how)or true
end
function M.Stash(how)
 if not picked then return false end
 local k=picked.Key
 if ctx.State:Stow(k)then picked=nil;done(nameOf(k)..' put in the Bag (slot left blank, '..(how or'tap')..')')else M.Unpick('already in the Bag')end
 return true
end
-- Discarding --------------------------------------------------------------------------------------------------------------------------------------------
local function say(text,bad)
 note(text)
 pcall(function()require(RS:WaitForChild('NoticeFeed83')).Plain(text,bad and Color3.fromRGB(255,120,110)or Color3.new(1,1,1),2.5,'bag '..text)end)
end
function M.Discard(key,how)
 local e=key and ctx.State.Items[key];if not e then return false end
 M.Unpick()
 local tool=e.Tool
 if not Stacks.Counts(tool)then say('u can\'t throw that away',true);return false end
 note(('discard? %s x%d (%s), hold to confirm'):format(tool.Name,e.Count or 1,how or'trash'))
 Dialog.Open(ctx.pg,{Tool=tool,Name=ctx.Names.Tool(tool,ctx.Catalog),Rarity=tool:GetAttribute('Rarity'),Count=e.Count or 1},function(amount)
  local remotes=RS:FindFirstChild('ChestChaseRemotes');local remote=remotes and remotes:FindFirstChild('DiscardItems')
  if not remote then Dialog.Fail('try again in a sec');return end
  local request={Kind=Stacks.Kind(tool),Id=Stacks.Id(tool),Count=amount}
  local ok,result=pcall(function()return remote:InvokeServer(request)end)
  if ok and type(result)=='table'and result.Ok then
   Dialog.Done();say(tostring(result.Message or'thrown away'))
  else
   local why=ok and type(result)=='table'and result.Message or'try again!'
   note('discard refused: '..tostring(why));Dialog.Fail(tostring(why):lower())
  end
 end)
 return true
end
function M.OverTrash(p)
 local t=ui.Trash;if not(t and ctx.panel.Visible and t.Visible)then return false end
 local a,z=t.AbsolutePosition,t.AbsoluteSize;return p.X>=a.X-4 and p.Y>=a.Y-4 and p.X<=a.X+z.X+4 and p.Y<=a.Y+z.Y+4
end
-- Search dims the hotbar slots that do not match ----------------------------------------------------------------------------------------------------
local dimmed={}
local function paintSearch()
 if not ctx then return end
 local term=ctx.panel.Visible and ctx.search.Text:lower()or''
 for i,b in ipairs(ctx.slots)do
  local k=ctx.State.Slots[i];local e=k and ctx.State.Items[k]
  local dim=term~=''and b.Visible and(not e or not ctx.Names.Search(e.Tool,ctx.Catalog):find(term,1,true))
  if dim then ctx.cover(b,'SearchDim',Color3.new(0,0,0),.5).Visible=true;dimmed[b]=true
  elseif dimmed[b]then local f=b:FindFirstChild('SearchDim');if f then f.Visible=false end;dimmed[b]=nil end
 end
end
M.PaintSearch=paintSearch
-- The saved layout ------------------------------------------------------------------------------------------------------------------------------------
local function remote()local f=RS:FindFirstChild('ChestChaseRemotes');return f and f:FindFirstChild('HotbarLayout155')end
local function flush()
 saveDue=nil
 local State=ctx.State;if State.Phase~='live'then return end -- (going live bumps the layout: it is sent then)
 if State:Waiting()and os.clock()<=State.BackUntil then -- (a respawn: wait until every item is back, then send)
  saveDue=os.clock()+.5;task.delay(.5,function()if ctx and saveDue then flush()end end);return
 end
 local text=State:Serialize();if text==lastSent then return end
 local r=remote();if not r then return end
 lastSent=text;pcall(function()r:FireServer(text)end);note('layout saved ('..text:gsub('%x%x%x%x%x%x%x%x',function(h)return h:sub(1,3)end)..')')
end
local function scheduleSave()
 if saveDue then return end
 saveDue=os.clock()+M.SaveDelay
 task.delay(M.SaveDelay,function()if ctx then flush()end end)
end
function M.Flush()saveDue=nil;flush()end
local liveQueued=false
local function goLiveSoon(delay)
 if liveQueued or ctx.State.Phase=='live'then return end
 liveQueued=true
 task.delay(delay,function()
  liveQueued=false;if not ctx then return end
  ctx.refresh()
  if ctx.State:GoLive()then note('every item is here: new items now go to the first free slot');ctx.refresh()end
 end)
end
local function restore()
 local text=ctx.player:GetAttribute('HotbarLayout155')
 if type(text)=='string'and text~=''and ctx.State.Phase=='join'then
  if ctx.State:Restore(text)then lastSent=text;note('saved layout restored');ctx.refresh()end
 elseif type(text)=='string'then lastSent=lastSent or text end
end
-- Each refresh of the Hotbar ends here (cheap: no allocation unless something changed).
function M.AfterRefresh()
 if not ctx then return end
 paintCount();paintPick();paintSearch()
 local State=ctx.State
 if State.Version~=lastVersion then lastVersion=State.Version;if State.Phase=='live'then scheduleSave()end end
end
function M.Opened()if ctx then paintSearch();paintCount()end end
function M.Closed()if ctx then M.Unpick();paintSearch()end end
-- Where the bottom bar goes: short sheets (phones) give it the bottom of the grid; others use the hint's row.
function M.Layout(short,sheetWidth)
 if not ui.Bar then return end
 local hint=ctx.panel:FindFirstChild('Hint')
 ui.Bar.Position=UDim2.new(0,16,1,short and-34 or-34);ui.Bar.Size=UDim2.new(1,-32,0,28)
 local narrow=sheetWidth<420
 ui.Trash.Text=narrow and'🗑'or'🗑 Discard';ui.Trash.Size=UDim2.fromOffset(narrow and 44 or 104,28);ui.Trash.Position=UDim2.new(1,narrow and-44 or-104,0,0)
 local right=(narrow and 44 or 104)+8
 ui.Count.Size=UDim2.fromOffset(88,28);ui.Count.Position=UDim2.new(1,-(right+88),0,0)
 ui.Pick.Size=UDim2.new(1,-(right+96),1,0)
 ui.What.Size=UDim2.new(1,-206,1,0);ui.What.Visible=sheetWidth>=380 -- (a very narrow sheet: the outlined slots say it)
 if hint then hint.Size=UDim2.new(1,-(32+right+96),0,26);hint.Position=UDim2.new(0,16,1,-33);hint:SetAttribute('Room',not short);hint.Visible=not short and picked==nil
  hint.Text=Input.TouchEnabled and'Tap to hold • hold to move or discard'or'Click to hold • drag to move • right-click for more'end
 paintCount()
end
M.BarHeight=36
function M.Start(c)
 ctx=c;picked=nil;drag=nil;ringOn=nil;lastSent=nil;saveDue=nil;lastVersion=-1;liveQueued=false;table.clear(hints);table.clear(dimmed) -- (a new Hotbar: nothing of the last one)
 build()
 on(ui.Hold.Activated,function()if picked then local k=picked.Key;M.Unpick();ctx.equip(k,'Hold (picked)')end end)
 on(ui.Stash.Activated,function()M.Stash('To Bag')end)
 on(ui.Cancel.Activated,function()M.Unpick('cancelled')end)
 on(ui.Trash.Activated,function()if picked then M.Discard(picked.Key,'trash (picked)')else say('drag an item here to throw it away')end end)
 on(ctx.player:GetAttributeChangedSignal('HeldItemCount'),paintCount);on(ctx.player:GetAttributeChangedSignal('HeldItemCap'),paintCount)
 on(ctx.player:GetAttributeChangedSignal('HotbarLayout155'),restore)
 on(ctx.player:GetAttributeChangedSignal('InventorySynced155'),function()if ctx.player:GetAttribute('InventorySynced155')==true then goLiveSoon(M.LiveDelay)end end)
 on(Input.InputBegan,function(input,processed)
  if not picked or processed then return end
  local t=input.UserInputType
  if t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch then M.Unpick('tapped away')end -- (a tap in the world puts it down)
 end)
 -- gamepad: Y on the focused slot or card picks it (with the Bag open; X is the garden's Pick prompt); DPad-Up opens / closes the Bag
 local function focusedKey()
  local o=GuiService.SelectedObject;if not o then return nil end
  for i,b in ipairs(ctx.slots)do if b==o then return ctx.State.Slots[i],i end end
  local k=o:GetAttribute('InventoryKey');if k and o:IsDescendantOf(ctx.panel)then return k,nil end
  return nil
 end
 pcall(function()
  CAS:BindAction('GardenBagPick',function(_,state)
   if state~=Enum.UserInputState.Begin or not ctx.panel.Visible then return Enum.ContextActionResult.Pass end
   local key,slot=focusedKey();if not key then return Enum.ContextActionResult.Pass end
   if picked and picked.Key==key then M.Unpick('pressed again')else M.Pick(key,slot,'gamepad')end
   return Enum.ContextActionResult.Sink
  end,false,Enum.KeyCode.ButtonY)
  CAS:BindAction('GardenBagToggle',function(_,state)
   if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
   local menu=ctx.pg:GetAttribute('SeedMenu');if menu~=nil and menu~='Inventory'then return Enum.ContextActionResult.Pass end
   ctx.toggle(not ctx.panel.Visible);return Enum.ContextActionResult.Sink
  end,false,Enum.KeyCode.DPadUp)
 end)
 local text=ctx.player:GetAttribute('HotbarLayout155');if type(text)=='string'then lastSent=text end
 restore()
 if ctx.player:GetAttribute('InventorySynced155')==true then goLiveSoon(M.LiveDelay)end
 task.delay(M.JoinFallback,function()if ctx then goLiveSoon(0)end end)
 paintCount()
end
function M.Stop()
 for _,c in ipairs(conns)do c:Disconnect()end;table.clear(conns)
 pcall(function()CAS:UnbindAction('GardenBagPick');CAS:UnbindAction('GardenBagToggle')end)
 Dialog.Destroy();picked=nil;drag=nil;ctx=nil
end
return M
