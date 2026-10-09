-- R155 (owner: "hot bar and inventory management is still not fixed just make it function like the normal inventory (not look like) it should feel responsive
-- and i have a lot of options to manage my inventory i can have a blank hot bar if i put everything in my bag additionally make the max amount of items a
-- person can hold 200", then "allow people to discard items"). The Bag's management half, started by the Hotbar (Hotbar.client.lua keeps the presses, the
-- drag, equipping and drawing; GardenInventoryState keeps the layout rules). One Hotbar per client, so this module is its single instance.
--  * the bottom bar of the Bag: the count "143/200" (amber from 180, red and FULL at 200; the
--    Bag button shows FULL too) and the Trash (drop an item on it, or tap it while an item is picked: the confirm popup, DiscardDialog155).
--    (R157, owner: "dont make this green and remove that text saying click to hold and so on": the bar has no hint line on any device, and the Bag has no green; the lit colour is a light
--    neutral, C.Lit.)
--  * tap-tap (phones, and everyone): hold an item (0.4 s) and let go without moving it, or right-click it, or press Y on a gamepad: it is PICKED (a
--    light ring; every slot it can go to is outlined; the Bag opens). Then tap a slot (or press its number key) = put it there (swap if taken); tap a Bag
--    card or "To Bag" (or the Bag button) = into the Bag (its slot stays blank); tap the Trash = discard; "Hold" = hold it; tap it again or the X = put it down.
--  * search: Bag cards filter; hotbar slots that do not match dim.
--  * the layout is sent to the server (ChestChaseRemotes.HotbarLayout155) a moment after it changes; at join the saved one (the player attribute
--    HotbarLayout155) puts each item back on its slot, and once the server says every item is there (InventorySynced155) new items are placed as new.
--    Nothing goes live or is sent while that attribute has not arrived (a slow profile load): an arrival-order layout would be saved over the player's own.
--  * no item info panel (R156, owner: "these descriptions can be removed from the game"): the R155 item info panel, and everything that fed it (hover, selection, the picked item, a just-held pack), is gone.
local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService');local GuiService=game:GetService('GuiService')
local CAS=game:GetService('ContextActionService')
local Stacks=require(RS:WaitForChild('InventoryStacks155'));local Dialog=require(RS:WaitForChild('DiscardDialog155'))
local M={Stacks=Stacks,Key=Stacks.Key,Dialog=Dialog,Cap=Stacks.Cap,SaveDelay=2,LiveDelay=1,JoinFallback=8}
local ctx,picked,ui,conns=nil,nil,{},{}
local right,barH,sheetW=112,30,500 -- the Trash's width + 8 and the bar's height (M.Layout sets them with the sheet's width: a narrow sheet has a small Trash)
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
 local what=Instance.new('TextLabel');what.Name='PickName';what.BackgroundTransparency=1;what.Size=UDim2.new(1,-206,1,0);what.Font=ctx.Theme.Font;what.TextSize=13;what.TextColor3=C.Lit
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
local NEED=202 -- the pick bar's three buttons (Hold, To Bag, x) and the gaps between them
local picking -- (set by paintPick: an item is picked)
local function paintCount()
 if not ui.Count then return end
 local n,cap=held();local full=n>=cap
 local text=full and(n..'/'..cap..' FULL')or(n..'/'..cap)
 if ui.Count.Text~=text then ui.Count.Text=text end
 local color=full and RED or n>=math.floor(cap*.9)and AMBER or ctx.C.Text
 if ui.Count.TextColor3~=color then ui.Count.TextColor3=color end
 -- (R155 review) the count sits left of the Trash, wherever the sheet's width put it (M.Layout's `right`); FULL is wider, and the pick bar ends where the count starts,
 -- so neither covers the pick bar's x button on a narrow sheet or on a wide one
 local w=full and 112 or 88
 local barW=sheetW-32;local room=barW-(right+w+8) -- (the pick bar's width beside the count)
 -- a picked item's buttons need NEED px: on a sheet too narrow for them beside the count (a portrait phone), the count steps aside while an item is picked
 local showCount=not picking or room>=NEED
 if ui.Count.Visible~=showCount then ui.Count.Visible=showCount end
 ui.Count.Size=UDim2.fromOffset(w,barH);ui.Count.Position=UDim2.new(1,-(right+w),0,0)
 if ui.Pick then
  local pw=showCount and room or barW-right
  ui.Pick.Size=UDim2.new(1,-(barW-pw),1,0)
  local text=pw-206 -- (the text left of the three buttons: too small to read on a very narrow sheet: the outlined slots say it)
  if ui.What.Visible~=(text>=60)then ui.What.Visible=text>=60 end
 end
 if ui.Badge.Visible~=full then ui.Badge.Visible=full end
end
M.Held=held
-- Picking (tap-tap) -----------------------------------------------------------------------------------------------------------------------------------
local hints={}
local function hintOf(b)
 local h=b:FindFirstChild('DropHint')
 if not h then
  h=Instance.new('Frame');h.Name='DropHint';h.BackgroundTransparency=1;h.Size=UDim2.fromScale(1,1);h.Active=false;h.ZIndex=(b.ZIndex or 1)+7;h.Visible=false;h.Parent=b;ctx.corner(h)
  local s=Instance.new('UIStroke');s.Name='Line';s.Color=ctx.C.Lit;s.Thickness=2;s.Transparency=.3;s.Parent=h
 end
 return h
end
local function ringOf(b)
 local r=b:FindFirstChild('PickedRing')
 if not r then
  r=Instance.new('Frame');r.Name='PickedRing';r.BackgroundColor3=ctx.C.Lit;r.BackgroundTransparency=.78;r.Size=UDim2.fromScale(1,1);r.Active=false;r.ZIndex=(b.ZIndex or 1)+7;r.Visible=false;r.Parent=b;ctx.corner(r)
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
  ui.Pick.Visible=picked~=nil;if picking~=(picked~=nil)then picking=picked~=nil;paintCount()end
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
 -- (R155 review) the reply is tagged with the popup it belongs to (`ticket`): "Keep it" while a request is in flight and then another discard must not have the old
 -- reply close, or fail, the new popup. The old reply still says what happened (the item may really be gone).
 Dialog.Open(ctx.pg,{Tool=tool,Name=ctx.Names.Tool(tool,ctx.Catalog),Rarity=tool:GetAttribute('Rarity'),Count=e.Count or 1},function(amount,ticket)
  local remotes=RS:FindFirstChild('ChestChaseRemotes');local remote=remotes and remotes:FindFirstChild('DiscardItems')
  if not remote then Dialog.Fail('try again in a sec',ticket);return end
  local request={Kind=Stacks.Kind(tool),Id=Stacks.Id(tool),Count=amount}
  local ok,result=pcall(function()return remote:InvokeServer(request)end)
  if ok and type(result)=='table'and result.Ok then
   Dialog.Done(ticket);say(tostring(result.Message or'thrown away'))
  else
   local why=ok and type(result)=='table'and result.Message or'try again!'
   note('discard refused: '..tostring(why));Dialog.Fail(tostring(why):lower(),ticket)
  end
 end)
 return true
end
-- Esc belongs to the discard popup while it is open (or was closed by that very Esc a moment ago): the Hotbar must not close the Bag as well.
function M.PopupEsc()return Dialog.IsOpen()or os.clock()-(Dialog.EscAt or-1)<.1 end
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
local function layoutKnown()return type(ctx.player:GetAttribute('HotbarLayout155'))=='string'end -- (the server sets it, '' = none saved, when the profile has loaded)
local function flush()
 saveDue=nil
 local State=ctx.State;if State.Phase~='live'then return end -- (going live bumps the layout: it is sent then)
 if not layoutKnown()then return end -- (R155 review: the saved layout has not arrived: what this client has is arrival order, which would be saved over the player's own)
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
local liveQueued,liveWaits=false,false
local function goLiveSoon(delay)
 if liveQueued or ctx.State.Phase=='live'then return end
 liveQueued=true
 task.delay(delay,function()
  liveQueued=false;if not ctx then return end
  -- (R155 review) a slow profile load: the saved layout (HotbarLayout155) has not arrived, so the join goes on (new items follow the same rule meanwhile); going live now
  -- would send this client's arrival-order layout over the player's saved one. It goes live when the layout arrives (restore).
  if not layoutKnown()then liveWaits=true;note('waiting for the saved layout');return end
  ctx.refresh()
  if ctx.State:GoLive()then note('every item is here: new items now go to the first free slot');ctx.refresh()end
 end)
end
local function restore()
 local text=ctx.player:GetAttribute('HotbarLayout155')
 if type(text)~='string'then return end
 -- (R155 review) a layout that arrives after the player already moved something is not applied: what the player did stays, and is saved
 if text~=''and ctx.State.Phase=='join'and not ctx.State.Touched then
  if ctx.State:Restore(text)then lastSent=text;note('saved layout restored');ctx.refresh()end
 else lastSent=lastSent or text end
 if liveWaits then liveWaits=false;goLiveSoon(0)end
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
-- Where the bottom bar goes: the bottom row of the sheet (the count next to Discard; while an item is picked, what to do with it takes the left of the row).
function M.Layout(short,sheetWidth)
 if not ui.Bar then return end
 ui.Bar.Position=UDim2.new(0,16,1,short and-34 or-34);ui.Bar.Size=UDim2.new(1,-32,0,28)
 local narrow=sheetWidth<420
 ui.Trash.Text=narrow and'🗑'or'🗑 Discard';ui.Trash.Size=UDim2.fromOffset(narrow and 44 or 104,28);ui.Trash.Position=UDim2.new(1,narrow and-44 or-104,0,0)
 right=(narrow and 44 or 104)+8;barH=28;sheetW=sheetWidth -- (paintCount places the count and the pick bar from these: R155 review, it used a fixed offset that covered the x button)
 ui.What.Size=UDim2.new(1,-206,1,0)
 paintCount()
end
M.BarHeight=36
function M.Start(c)
 ctx=c;picked=nil;picking=false;drag=nil;ringOn=nil;lastSent=nil;saveDue=nil;lastVersion=-1;liveQueued=false;liveWaits=false;table.clear(hints);table.clear(dimmed) -- (a new Hotbar: nothing of the last one)
 right,barH,sheetW=112,30,500
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
 -- gamepad: Y on the focused slot or card picks it (with the Bag open; X is the garden's Pick prompt); DPad-Up opens / closes the Bag (and moves the selection when it is on the Bag or the hotbar)
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
   -- (R155 review) with the selection inside the Bag or on the hotbar, DPad-Up moves it (Roblox's GUI navigation); it only opens / closes the Bag from outside
   local o=GuiService.SelectedObject
   if o and(o==ctx.dock or o:IsDescendantOf(ctx.dock)or o:IsDescendantOf(ctx.panel))then return Enum.ContextActionResult.Pass end
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
