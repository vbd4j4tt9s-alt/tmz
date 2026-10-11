-- Fit on content/layout changes, wrapping only at spaces. TextScaled implicitly wraps words in Roblox.
local Text=game:GetService('TextService')
local M={};local entries=setmetatable({},{__mode='k'});local widths={};local count=0
local function measure(s,size,font)
 local key=tostring(font)..':'..size..':'..s;local value=widths[key]
 if not value then value=Text:GetTextSize(s,size,font,Vector2.new(100000,100000)).X;count+=1;if count>2048 then table.clear(widths);count=1 end;widths[key]=value end
 return value
end
function M.Layout(text,width,height,font,maximum,minimum)
 text=tostring(text or'');maximum=maximum or 14;minimum=minimum or 8;width=math.max(1,width-4);height=math.max(1,height-2)
 for size=maximum,minimum,-1 do
  local lines={};local valid=true
  for paragraph in (text..'\n'):gmatch('(.-)\n')do
   local line=''
   for word in paragraph:gmatch('%S+')do
    if measure(word,size,font)>width then valid=false;break end
    local candidate=line==''and word or line..' '..word
    if line~=''and measure(candidate,size,font)>width then table.insert(lines,line);line=word else line=candidate end
   end
   if not valid then break end;table.insert(lines,line)
  end
  if valid and #lines*size*1.15<=height then return table.concat(lines,'\n'),size,false end
 end
 -- Preserve a readable minimum. An explicit ellipsis is preferable to splitting a word into letters.
 local line=text:gsub('\n',' ');local ellipsis='...'
 while #line>0 and measure(line..ellipsis,minimum,font)>width do
  local start=utf8.offset(line,-1);line=line:sub(1,(start or 1)-1)
 end
 return line..ellipsis,minimum,true
end
-- The product of every UIScale above the label (and on it), and the product of those named HudScale (HudLayout.ApplyScale: a computer's HUD, drawn smaller than it is laid out).
local function scalesOf(label)
 local scale,hud=1,1;local node=label
 while node and not node:IsA('ScreenGui')do
  local transform=node:FindFirstChildOfClass('UIScale');if transform then scale*=math.max(.001,transform.Scale)end
  local hudScale=node:FindFirstChild('HudScale');if hudScale and hudScale:IsA('UIScale')then hud*=math.max(.001,hudScale.Scale)end
  node=node.Parent
 end
 return scale,hud
end
-- TextSize is in logical GUI pixels; AbsoluteSize already includes ancestor UIScales.
function M.LogicalSize(label,size)
 local scale=scalesOf(label)
 return size.X/scale,size.Y/scale
end
-- R158 review: a minimum is a size in REAL screen px, but a size is in the label's own (HUD) px, which a computer's HUD scale k (under 1 on a window smaller than 1920 x 720) draws
-- k times smaller: a 7 px minimum would show as 3 px on an 800 x 600 window. Floor(minimum, k, height) is the smallest size, in the label's own px, that keeps the minimum in real px:
-- minimum / k, but never more than ONE line of a box `height` tall can hold (the same rule Layout fits by), and never under the minimum itself. Only a readable-text minimum is held
-- that way: one above RealCap px (the status card's 13 / 16, the wallet's 29: they are the label's design size, not a legibility floor) keeps its HUD-px value. At k = 1 (a phone, a
-- window of 1920 x 720 or more) every minimum is as it was.
M.RealCap=9
function M.Floor(minimum,k,height)
 if not k or k>=1 or minimum>M.RealCap then return minimum end
 return math.max(minimum,math.min(math.ceil(minimum/k-1e-6),math.floor((height-2)/1.15)))
end
function M.Attach(label,maximum,minimum)
 local entry=entries[label]
 if entry then entry.Maximum=maximum or entry.Maximum;entry.Minimum=minimum or entry.Minimum;entry.Paint();return label end
 entry={Full=label.Text,Maximum=maximum or label.TextSize or 14,Minimum=minimum or 8,Connections={}};entries[label]=entry
 local writing=false
 local function paint()
  if writing then return end
  -- Native property signals can be deferred. Capture a caller's new text before
  -- a font/layout repaint has a chance to restore the previous displayed string.
  if label.Text~=entry.Displayed then entry.Full=label.Text end
  writing=true
  label.TextScaled=false;label.TextWrapped=false;label.TextTruncate=Enum.TextTruncate.AtEnd
  local constraint=label:FindFirstChildOfClass('UITextSizeConstraint');if constraint then constraint.MinTextSize=entry.Minimum;constraint.MaxTextSize=entry.Maximum end
  local size=label.AbsoluteSize
  if size and size.X>0 and size.Y>0 then
   local scale,hud=scalesOf(label)
   local width,height=size.X/scale,size.Y/scale
   -- (R158 review: under a HUD scale the minimum is held in real px - Floor - and the biggest size may rise to it)
   local minimum,maximum=entry.Minimum,entry.Maximum
   if hud<1 then minimum=M.Floor(minimum,hud,height);maximum=math.max(maximum,minimum)end
   local displayed,fontSize,truncated=M.Layout(entry.Full,width,height,label.Font,maximum,minimum)
   entry.Displayed=displayed;label.Text=displayed;label.TextSize=fontSize;label:SetAttribute('TextShortened',truncated)
  end
  label:SetAttribute('FullText',entry.Full);writing=false
 end
 entry.Paint=paint
 local function connect(signal,fn)table.insert(entry.Connections,signal:Connect(fn))end
 -- Deferred property signals may arrive after paint has released its writing guard.
 connect(label:GetPropertyChangedSignal('Text'),function()if not writing and label.Text~=entry.Displayed then entry.Full=label.Text;paint()end end)
 for _,property in ipairs({'AbsoluteSize','Font','TextScaled','TextWrapped'})do connect(label:GetPropertyChangedSignal(property),paint)end
 connect(label.Destroying,function()for _,c in ipairs(entry.Connections)do c:Disconnect()end;entries[label]=nil end)
 paint();return label
end
return M
