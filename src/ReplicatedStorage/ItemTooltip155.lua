-- R155 (review): the item's ToolTip, shown the way Roblox's own backpack shows it. ChestService writes a pack's odds, the pity lines ("LUCKY PACK: x1.5 luck on
-- this one!", the rule) and the Mech coat line ("Gold 4.5% / Diamond 0.5% coat") into Tool.ToolTip when the pack is held, and Roblox's backpack, the only built-in
-- UI that draws a ToolTip, is switched off (Hotbar.client.lua), so nobody saw it. This is the paid-random odds disclosure for Mech packs: reachable on every platform.
--  * mouse: hovering a hotbar slot or a Bag card shows it (Roblox does too); leaving hides it.
--  * gamepad: moving the selection onto a slot or card shows it.
--  * touch (and everyone): an item that is PICKED (tap-tap: hold it 0.4 s and let go, right-click, Y) shows it until it is put down.
--  * touch / gamepad: a pack that is just held shows it for a few seconds once the server has written its odds (a tap on the slot is all it takes).
-- A tidy panel in the Bag's look: the item's name in its rarity colour, then the lines (the odds as a name / odds column, the lucky line in gold, the coat line, the
-- pity rule dimmed). Clamped on the screen, never over the pity bars above the hotbar, the held item's name or the Bag's bottom bar; it takes no input
-- (a tap goes through it). A tall tooltip on a small screen drops odds rows from its end ("+3 more") and keeps the lines after them (the coat, the rule).
-- Nothing runs per frame: it is built on the first show, redrawn only when something it reads changes, and costs a table lookup otherwise.
local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService');local TextService=game:GetService('TextService')
local Theme=require(RS:WaitForChild('GardenTheme'))
local T={Margin=8,Gap=6,Pad=12,Seconds=5,Wait=3,ZIndex=45,Name='ItemTooltip'}
local GOLD,COAT=Color3.fromRGB(255,214,140),Color3.fromRGB(255,232,150)
local ctx,ui,src,suppressed=nil,nil,{},false
local watched,watchConn=nil,nil -- the tool whose ToolTip is on show: the server rewrites a pack's when it is held, and the panel follows
local cache,cacheSize={},0
local ORDER={'hover','focus','pick','announce'} -- (what the mouse is over beats the gamepad's selection beats the picked item beats a held pack's)
local function clock()return os.clock()end
-- Text ------------------------------------------------------------------------------------------------------------------------------------------------------
local BIG=Vector2.new(100000,100000)
local function measure(text,size,width) -- the size of `text` at `size` px wrapped to `width` px (a wrap-unaware TextService still gets its line count from the unwrapped width)
 local key=size..':'..width..':'..text;local hit=cache[key];if hit then return hit.X,hit.Y end
 local font=Theme.Font
 local one=TextService:GetTextSize('Ag',size,font,BIG);local line=math.max(1,one.Y)
 local flat=TextService:GetTextSize(text,size,font,BIG)
 local wrapped=TextService:GetTextSize(text,size,font,Vector2.new(width,100000))
 local lines=math.max(1,math.ceil(flat.X/(math.max(1,width)*.96)))
 local w,h=math.min(flat.X,width),math.max(wrapped.Y,lines*line)
 cacheSize+=1;if cacheSize>400 then table.clear(cache);cacheSize=1 end
 cache[key]=Vector2.new(w,h);return w,h
end
local function trim(s)return(s:gsub('^%s+',''):gsub('%s+$',''))end
local function tipOf(tool)
 if not tool then return''end
 local ok,v=pcall(function()return tool.ToolTip end)
 return ok and type(v)=='string'and v or''
end
-- The lines of a ToolTip as rows: {Kind='text'|'lucky'|'coat'|'rule'|'odds', A=text (the name for odds), B=the odds}. The first line is dropped when it only repeats the title.
function T.Parse(text,titles)
 local rows={};local first=true
 for line in(tostring(text)..'\n'):gmatch('(.-)\n')do
  line=trim(line)
  if line~=''then
   local skip=false
   if first then for _,t in ipairs(titles)do if line==t then skip=true end end end
   first=false
   if not skip then
    local name,odds=line:match('^(.-): (1/[%w%.,]+)$')
    if name and name~=''then rows[#rows+1]={Kind='odds',A=name,B=odds}
    elseif line:sub(1,5)=='LUCKY'then rows[#rows+1]={Kind='lucky',A=line}
    elseif line:sub(-5)==' coat'then rows[#rows+1]={Kind='coat',A=line}
    elseif line:sub(1,6)=='every 'then rows[#rows+1]={Kind='rule',A=line}
    else rows[#rows+1]={Kind='text',A=line}end
   end
  end
 end
 return rows
end
-- The rows that fit in maxH px at width w: {Items = {{Row, Y, H, More}}, Height, ValueWidth, NameWidth, Dropped (odds rows left out)}. Odds rows leave from the end of
-- the odds block first (one "+N more" row takes their place); the lines after the odds (the coat, the rule) stay.
function T.Fit(rows,w,maxH,size,titleH)
 local pad,gap=T.Pad,3;local inner=w-2*pad
 local valueW=0
 for _,r in ipairs(rows)do if r.Kind=='odds'then local vw=measure(r.B,size,100000);valueW=math.max(valueW,math.min(vw+2,inner*.45))end end
 local nameW=valueW>0 and inner-valueW-10 or inner
 local heights={}
 for i,r in ipairs(rows)do
  if r.Kind=='odds'then local _,h1=measure(r.A,size,nameW);local _,h2=measure(r.B,size,valueW+2);heights[i]=math.max(h1,h2)
  else local _,h=measure(r.A,r.Kind=='rule'and size-1 or size,inner);heights[i]=h end
 end
 local _,moreH=measure('+99 more',size-1,inner)
 local keep={};for i=1,#rows do keep[i]=true end
 local first -- the first odds row that was dropped: the "+N more" row stands there
 local function layout()
  local items,y={},pad+titleH+4
  local more=0;for i=1,#rows do if not keep[i]and rows[i].Kind=='odds'then more+=1 end end
  for i=1,#rows do
   if i==first and more>0 then items[#items+1]={Row={Kind='rule',A='+'..more..' more'},Y=y,H=moreH,More=true};y+=moreH+gap end
   if keep[i]then items[#items+1]={Row=rows[i],Y=y,H=heights[i]};y+=heights[i]+gap end
  end
  if #items>0 then y-=gap end
  return items,math.ceil(y+pad),more
 end
 local items,height,more=layout()
 while height>maxH do
  local drop
  for i=#rows,1,-1 do if keep[i]and rows[i].Kind=='odds'then drop=i;break end end
  if not drop then for i=#rows,2,-1 do if keep[i]then drop=i;break end end end -- (no odds left: the lines after the first go from the end)
  if not drop then break end
  keep[drop]=false
  if rows[drop].Kind=='odds'then first=math.min(first or drop,drop)end
  items,height,more=layout()
 end
 return {Items=items,Height=height,ValueWidth=valueW,NameWidth=nameW,Dropped=more}
end
-- Geometry (everything in the hotbar ScreenGui's own pixels) -------------------------------------------------------------------------------------------------
local function rectOf(o)
 local a,z=o.AbsolutePosition,o.AbsoluteSize;local g=ctx.gui.AbsolutePosition
 return {X=a.X-g.X,Y=a.Y-g.Y,W=z.X,H=z.Y}
end
local function showing(o)
 local p=o
 while p and p~=ctx.gui do if p:IsA('GuiObject')and p.Visible==false then return false end;p=p.Parent end
 return p==ctx.gui and o.AbsoluteSize.X>0
end
local function hits(x,y,w,h,r)return x<r.X+r.W and x+w>r.X and y<r.Y+r.H and y+h>r.Y end
local function spanHits(x0,x1,r)return x0<r.X+r.W and x1>r.X end
-- What the tooltip keeps clear of: the pity bars above the hotbar (their glow and the held bar's 1.06 scale included), the held item's name above the hotbar, the Bag's
-- bottom bar (count, Trash, the pick bar) while the Bag is open.
function T.Avoid()
 local out={}
 local bars=ctx.pg:FindFirstChild('PackPityBars155');local root=bars and bars.Enabled~=false and bars:FindFirstChild('PityBars')
 if root and root.Visible then
  local x0,y0,x1,y1
  for _,bar in ipairs(root:GetChildren())do if bar:IsA('GuiObject')and bar.Visible and bar.AbsoluteSize.X>0 then
   local r=rectOf(bar);x0=math.min(x0 or r.X,r.X);y0=math.min(y0 or r.Y,r.Y);x1=math.max(x1 or r.X+r.W,r.X+r.W);y1=math.max(y1 or r.Y+r.H,r.Y+r.H)
  end end
  if x0 then out[#out+1]={X=x0-8,Y=y0-8,W=x1-x0+16,H=y1-y0+16,Name='pity'}end
 end
 local dock=ctx.dock;local name,traits=dock:FindFirstChild('SelectedName'),dock:FindFirstChild('SelectedTraits')
 if name and name.Visible and name.Text~=''then
  local a=rectOf(name);local y1=a.Y+a.H
  if traits and traits.Visible and traits.Text~=''then local b=rectOf(traits);y1=math.max(y1,b.Y+b.H)end
  out[#out+1]={X=a.X,Y=a.Y,W=a.W,H=y1-a.Y,Name='held'}
 end
 local bagBar=ctx.panel.Visible and ctx.panel:FindFirstChild('BagBar')
 if bagBar and bagBar.Visible then local r=rectOf(bagBar);out[#out+1]={X=r.X-4,Y=r.Y-4,W=r.W+8,H=r.H+8,Name='bagbar'}end
 return out
end
-- Where the panel goes, w x (as tall as the text needs, at most what fits). Above its anchor; a hotbar slot's tooltip takes one baseline along the whole hotbar
-- (above the pity bars and the held item's name), so it does not jump about while the mouse crosses the slots. Below the anchor when that shows more of it (a Bag card
-- in the top row has little room above), clamped inside the screen otherwise. Returns x, y, the fitted rows.
function T.Place(anchor,onBar,w,fit,avoid,view)
 local m,gap=T.Margin,T.Gap
 local x=math.clamp(anchor.X+anchor.W/2-w/2,m,math.max(m,view.X-w-m))
 local bottom=anchor.Y-gap
 if onBar then
  local d=rectOf(ctx.dock)
  for _,a in ipairs(avoid)do if a.Y<anchor.Y and spanHits(d.X,d.X+d.W,a)then bottom=math.min(bottom,a.Y-gap)end end
 end
 local above
 for _=1,4 do
  above=fit(math.max(40,bottom-m))
  local y=bottom-above.Height
  local hit
  for _,a in ipairs(avoid)do if hits(x,y,w,above.Height,a)then hit=a end end
  if not hit then break end
  bottom=math.min(bottom,hit.Y-gap) -- (slide up above what it ran into)
 end
 local ay=bottom-above.Height
 if ay<m or above.Dropped>0 then -- (cramped above: is there more room below?)
  local top=anchor.Y+anchor.H+gap;local room=view.Y-m-top
  for _,a in ipairs(avoid)do if a.Y>=anchor.Y+anchor.H-1 and spanHits(x,x+w,a)then room=math.min(room,a.Y-gap-top)end end
  if room>=60 then
   local below=fit(math.max(40,room))
   if below.Dropped<above.Dropped or(ay<m and below.Height<=room)then return x,top,below end
  end
 end
 return x,math.max(m,ay),above
end
-- The panel ------------------------------------------------------------------------------------------------------------------------------------------
local function label(parent,name,size,bold)
 local l=Instance.new('TextLabel');l.Name=name;l.BackgroundTransparency=1;l.Active=false;l.Font=bold and Theme.Bold or Theme.Font;l.TextSize=size;l.TextColor3=ctx.C.Text
 l.TextWrapped=true;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Top;l.RichText=false;l.ZIndex=T.ZIndex+1;l.Parent=parent;return l
end
local function build()
 local f=Instance.new('Frame');f.Name=T.Name;f.BackgroundColor3=Color3.fromRGB(14,33,25);f.BackgroundTransparency=.04;f.BorderSizePixel=0;f.Active=false;f.Visible=false
 f.ZIndex=T.ZIndex;f.Parent=ctx.gui;ctx.corner(f)
 local st=Instance.new('UIStroke');st.Color=ctx.C.Green;st.Transparency=.45;st.Thickness=1.5;st.Parent=f
 ui={Frame=f,Title=label(f,'Title',15,true),Rows={}}
 ui.Title.TextWrapped=false;ui.Title.TextTruncate=Enum.TextTruncate.AtEnd
end
local function rowOf(i)
 local r=ui.Rows[i]
 if not r then r={Left=label(ui.Frame,'Row'..i,13,false),Right=label(ui.Frame,'Odds'..i,13,true)};r.Right.TextXAlignment=Enum.TextXAlignment.Right;ui.Rows[i]=r end
 return r
end
local function set(o,k,v)if o[k]~=v then o[k]=v end end
local function setRect(o,x,y,w,h)
 set(o,'Position',UDim2.fromOffset(x,y));set(o,'Size',UDim2.fromOffset(w,h))
end
local paint
local function watch(tool)
 if watched==tool then return end
 if watchConn then watchConn:Disconnect();watchConn=nil end
 watched=tool
 if tool then
  local ok,sig=pcall(function()return tool:GetPropertyChangedSignal('ToolTip')end)
  if ok and sig then watchConn=sig:Connect(function()if ctx then paint()end end)end
 end
end
local function hide()
 if ui and ui.Frame.Visible then ui.Frame.Visible=false end
 watch(nil);T.Current=nil
end
local function nameOf(tool)local ok,n=pcall(ctx.Names.Tool,tool,ctx.Catalog);return ok and n or tool.Name end
local function rarityOf(tool)
 local r=tool:GetAttribute('Rarity');if r then return r end
 local def=ctx.Catalog[tool:GetAttribute('SeedId')];return def and def.Rarity or'Common'
end
-- the name in its rarity colour (the Hotbar's slot names: colour, a dark outline, the gradient of the shiny rarities)
local function tint(l,rarity)
 local style=Theme.Rarity(rarity);l.TextColor3=style.Fill and Color3.new(1,1,1)or style.TextColor or style.Color
 local stroke=l:FindFirstChild('RarityOutline')or Instance.new('UIStroke');stroke.Name='RarityOutline';stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
 stroke.Color=style.Outline or Color3.fromRGB(19,31,28);stroke.Thickness=1;stroke.Parent=l
 local fill=l:FindFirstChild('RarityFill')
 if style.Fill then if not fill then fill=Instance.new('UIGradient');fill.Name='RarityFill';fill.Rotation=90;fill.Parent=l end;fill.Color=style.Fill elseif fill then fill:Destroy()end
end
local function colorOf(kind)return kind=='lucky'and GOLD or kind=='coat'and COAT or kind=='rule'and ctx.C.Muted or ctx.C.Text end
local function draw(tool,text,anchor,onBar)
 if not ui then build()end
 local view=ctx.gui.AbsoluteSize;local m=T.Margin
 local size=view.Y<520 and 12 or 13;local titleH=size+9
 local w=math.min(math.clamp(math.floor(view.X*.34),210,300),math.max(120,view.X-2*m))
 local title=nameOf(tool)
 local rows=T.Parse(text,{title,tool.Name})
 local avoid=T.Avoid()
 local x,y,fit=T.Place(anchor,onBar,w,function(maxH)return T.Fit(rows,w,math.min(maxH,view.Y-2*m),size,titleH)end,avoid,view)
 local f=ui.Frame
 setRect(f,x,y,w,fit.Height)
 set(ui.Title,'Text',title);setRect(ui.Title,T.Pad,T.Pad,w-2*T.Pad,titleH)
 do local ts=size+2;while ts>11 and measure(title,ts,100000)>w-2*T.Pad do ts-=1 end;set(ui.Title,'TextSize',ts) -- (a long name shrinks to fit its line)
  local rarity=rarityOf(tool);if ui.Rarity~=rarity then ui.Rarity=rarity;tint(ui.Title,rarity)end end
 local inner=w-2*T.Pad
 for i,it in ipairs(fit.Items)do
  local r=rowOf(i);local row=it.Row
  local left,right=r.Left,r.Right
  set(left,'Visible',true);set(left,'TextSize',row.Kind=='rule'and size-1 or size);set(left,'Font',row.Kind=='lucky'and Theme.Bold or Theme.Font)
  set(left,'TextColor3',colorOf(row.Kind));set(left,'Text',row.A)
  if row.Kind=='odds'then
   setRect(left,T.Pad,it.Y,fit.NameWidth,it.H)
   set(right,'Visible',true);set(right,'TextSize',size);set(right,'Text',row.B);set(right,'TextColor3',ctx.C.Green)
   setRect(right,T.Pad+inner-fit.ValueWidth,it.Y,fit.ValueWidth,it.H)
  else setRect(left,T.Pad,it.Y,inner,it.H);set(right,'Visible',false)end
 end
 for i=#fit.Items+1,#ui.Rows do set(ui.Rows[i].Left,'Visible',false);set(ui.Rows[i].Right,'Visible',false)end
 if not f.Visible then f.Visible=true end
 T.Current={Tool=tool,Text=text,X=x,Y=y,W=w,H=fit.Height,Dropped=fit.Dropped}
end
-- What is shown ----------------------------------------------------------------------------------------------------------------------------------------
local function touchLast()
 local ok,t=pcall(function()return Input:GetLastInputType()end)
 return ok and t==Enum.UserInputType.Touch
end
local function padLast()
 local ok,t=pcall(function()return Input:GetLastInputType()end)
 return ok and t~=nil and tostring(t.Name or''):find('Gamepad',1,true)~=nil
end
paint=function()
 if not ctx then return end
 if suppressed then hide();return end
 local s
 for _,name in ipairs(ORDER)do if src[name]then s=src[name];break end end
 if not s then hide();return end
 local tool=s.Tool
 if not tool then
  local key=s.Fn and s.Fn()or s.Key;local e=key and ctx.State.Items[key];tool=e and e.Tool
 end
 local text=tipOf(tool)
 if not tool or text==''then hide();if tool then watch(tool)end;return end -- (no text yet: it may come)
 if s.Kind=='announce'then
  if not s.Born or tool.Parent~=ctx.player.Character then hide();return end
  if not text:find('\n',1,true)then hide();return end -- (the short line a pack has before the server writes its odds: nothing to announce)
  if not s.Until then s.Until=clock()+T.Seconds;task.delay(T.Seconds+.05,function()if src.announce==s then T.Unannounce(s)end end)end
 end
 local b=s.B
 if b and not showing(b)then if s.Kind=='hover'then hide();return end;b=nil end
 local onBar=b~=nil and b:IsDescendantOf(ctx.dock)
 local anchor=b and rectOf(b)or rectOf(ctx.dock)
 if not b then onBar=true end
 watch(tool);draw(tool,text,anchor,onBar)
end
function T.Unannounce(s)
 if src.announce~=s then return end
 src.announce=nil;if s.Conn then s.Conn:Disconnect();s.Conn=nil end;paint()
end
-- The sources: the Bag (InventoryPanel155) forwards the Hotbar's hover / selection events and the picked item ----------------------------------------------------
function T.Start(c)
 ctx=c;ui=nil;src={};suppressed=false;T.Current=nil
end
function T.Stop()
 if src.announce and src.announce.Conn then src.announce.Conn:Disconnect()end
 watch(nil)
 if ui then ui.Frame:Destroy()end
 ctx=nil;ui=nil;src={};T.Current=nil
end
function T.Hover(b,fn)
 if not ctx or touchLast()then return end -- (a finger is no hover: a tap would flash the tooltip for as long as it is down)
 src.hover={Kind='hover',B=b,Fn=fn};paint()
end
function T.Leave(b)if ctx and src.hover and src.hover.B==b then src.hover=nil;paint()end end
function T.Focus(b,fn)if ctx then src.focus={Kind='focus',B=b,Fn=fn};paint()end end
function T.Unfocus(b)if ctx and src.focus and src.focus.B==b then src.focus=nil;paint()end end
-- The picked item (key; b = its slot or card, nil when it has none on show) or nothing.
function T.Pick(key,b)
 if not ctx then return end
 local cur=src.pick
 if not key then if cur then src.pick=nil;paint()end;return end
 if cur and cur.Key==key and cur.B==b then return end
 src.pick={Kind='pick',Key=key,B=b};paint()
end
-- A pack that was just held (touch / gamepad): its tooltip for a few seconds, once it has its odds (the server writes them when the pack is held).
function T.Announce(tool,b)
 if not ctx or not tool or not(touchLast()or padLast())then return end
 local old=src.announce;if old and old.Tool==tool then return end
 if old and old.Conn then old.Conn:Disconnect()end
 local s={Kind='announce',Tool=tool,B=b,Born=clock()}
 src.announce=s
 local ok,sig=pcall(function()return tool:GetPropertyChangedSignal('ToolTip')end)
 if ok and sig then s.Conn=sig:Connect(function()if ctx then paint()end end)end
 task.delay(T.Wait,function()if src.announce==s and not s.Until then T.Unannounce(s)end end) -- (the odds never came: give up quietly)
 paint()
end
-- A drag lifts an item: no tooltip meanwhile.
function T.Suppress(on)if ctx and suppressed~=on then suppressed=on;paint()end end
-- The Bag opened / closed: what the mouse and the selection were on in the Bag (a card) is not there any more; a hotbar slot is (a click on it closes the Bag and the
-- cursor is still over it: Roblox keeps the tooltip).
function T.Reset()
 if not ctx then return end
 for _,name in ipairs({'hover','focus'})do local s=src[name];if s and s.B and s.B:IsDescendantOf(ctx.panel)then src[name]=nil end end
 paint()
end
-- Every refresh of the hotbar (and layout change): the item, its text or its place may have changed.
function T.Refresh()if ctx and next(src)then paint()end end
function T.Ui()return ui end
return T
