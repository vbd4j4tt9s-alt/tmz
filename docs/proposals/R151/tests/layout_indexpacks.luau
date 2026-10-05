--!nocheck
-- R151 Index tests: a small layout engine for the Roblox mock (which only stores properties). local L=require('./layout_indexpacks')(R)
-- L.lay(gui, w, h)  writes AbsoluteSize / AbsolutePosition on every GuiObject under a ScreenGui from Position / Size / AnchorPoint, UISizeConstraint, UIAspectRatioConstraint,
--                   UIListLayout (Horizontal / Vertical, Padding, LayoutOrder, hidden children left out) and ScrollingFrame (children are placed against the canvas and moved by
--                   CanvasPosition; an AutomaticCanvasSize of X / Y takes the size of the list's content). UIGridLayout and UIScale are NOT emulated (a UIScale is read by hand).
--                   Values are written only when they change (the Index watches AbsoluteSize).
-- L.rect(o)         {x0, y0, x1, y1} of a laid-out object.
-- L.clippers(o)     the ancestors of o that cut off what leaves them, nearest first: a ScrollingFrame, a CanvasGroup, a GuiObject with ClipsDescendants.
-- L.inside(a, b, tol)  is rect a inside rect b?
return function(R)
 local L={}
 local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
 local function name(e)return type(e)=='table'and e.Name or tostring(e)end
 local function udim(u,total)return u.Scale*total+u.Offset end
 local function sizeOf(c,pw,ph)
  local s=c._props.Size;local w=udim(s.X,pw);local h=udim(s.Y,ph)
  for _,k in ipairs(c._children)do
   if k._class=='UISizeConstraint'then
    local mx,mn=k._props.MaxSize,k._props.MinSize
    if mx then w=math.min(w,mx.X);h=math.min(h,mx.Y)end;if mn then w=math.max(w,mn.X);h=math.max(h,mn.Y)end
   elseif k._class=='UIAspectRatioConstraint'then
    local r=k._props.AspectRatio or 1
    if name(k._props.DominantAxis)=='Height'then w=h*r else h=w/r end
   end
  end
  return w,h
 end
 local function listOf(o)for _,k in ipairs(o._children)do if k._class=='UIListLayout'then return k end end end
 local function place(o,ox,oy,pw,ph)
  local list=listOf(o)
  local kids={}
  for _,c in ipairs(o._children)do if c:IsA('GuiObject')then kids[#kids+1]=c end end
  local sizes={}
  for _,c in ipairs(kids)do local w,h=sizeOf(c,pw,ph);sizes[c]={w,h} end
  if list then
   local shown={};for _,c in ipairs(kids)do if c._props.Visible~=false then shown[#shown+1]=c end end
   local idx={};for i,c in ipairs(shown)do idx[c]=i end
   table.sort(shown,function(a,b)local la,lb=a._props.LayoutOrder or 0,b._props.LayoutOrder or 0;if la~=lb then return la<lb end;return idx[a]<idx[b]end)
   local horizontal=name(list._props.FillDirection)=='Horizontal'
   local pad=list._props.Padding and udim(list._props.Padding,horizontal and pw or ph)or 0
   local cursor=0;local extent=0
   for _,c in ipairs(shown)do
    local w,h=sizes[c][1],sizes[c][2]
    local x,y=horizontal and cursor or 0,horizontal and 0 or cursor
    cursor+=(horizontal and w or h)+pad;extent=cursor-pad
    set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(ox+x,oy+y))
    L.walk(c,ox+x,oy+y,w,h)
   end
   for _,c in ipairs(kids)do if c._props.Visible==false then local w,h=sizes[c][1],sizes[c][2];set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(ox,oy));L.walk(c,ox,oy,w,h)end end
   return horizontal and extent or 0,horizontal and 0 or extent
  end
  for _,c in ipairs(kids)do
   local w,h=sizes[c][1],sizes[c][2];local p=c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
   local x=ox+udim(p.X,pw)-a.X*w;local y=oy+udim(p.Y,ph)-a.Y*h
   set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
   L.walk(c,x,y,w,h)
  end
  return 0,0
 end
 -- o's rect is (x, y, w, h): lay out its children
 function L.walk(o,x,y,w,h)
  if o._class=='ScrollingFrame'then
   local cs=o._props.CanvasSize or R.UDim2.new();local cw,ch=udim(cs.X,w),udim(cs.Y,h)
   local cp=o._props.CanvasPosition or R.Vector2.new(0,0)
   -- the content's size first (an automatic canvas), then place the children against the canvas
   local ex,ey=place(o,x-cp.X,y-cp.Y,cw>0 and cw or w,ch>0 and ch or h)
   local auto=name(o._props.AutomaticCanvasSize)
   if auto=='X'or auto=='XY'then cw=ex end;if auto=='Y'or auto=='XY'then ch=ey end
   o._canvas=R.Vector2.new(cw>0 and cw or w,ch>0 and ch or h)
  else
   place(o,x,y,w,h)
  end
 end
 function L.lay(gui,w,h)
  if gui.AbsoluteSize.X~=w or gui.AbsoluteSize.Y~=h then gui.AbsoluteSize=R.Vector2.new(w,h)end
  L.walk(gui,0,0,w,h)
 end
 function L.rect(o)local p,s=o.AbsolutePosition,o.AbsoluteSize;return{x0=p.X,y0=p.Y,x1=p.X+s.X,y1=p.Y+s.Y}end
 function L.inside(a,b,tol)tol=tol or 1e-6;return a.x0>=b.x0-tol and a.y0>=b.y0-tol and a.x1<=b.x1+tol and a.y1<=b.y1+tol end
 -- How far (px) rect a sticks out of rect b (the largest of the four overshoots; 0 = inside).
 function L.overshoot(a,b)return math.max(0,b.x0-a.x0,b.y0-a.y0,a.x1-b.x1,a.y1-b.y1)end
 -- {x0,y0,x1,y1} of everything a badge can ever draw. NotifyBadge151 (Badge = the module): the holder, the soft shadow and the shadow at the pop's biggest scale, or at rest with the pulse's
 -- halo at its biggest (the two never run together). The R150 badge (no NotifyBadge attribute): the frame plus its UIStroke ring, at rest.
 function L.badgeReach(Badge,b)
  local r=L.rect(b)
  if not b:GetAttribute('NotifyBadge')then
   local ring=b:FindFirstChildOfClass('UIStroke');local t=ring and ring._props.Thickness or 0
   return{x0=r.x0-t,y0=r.y0-t,x1=r.x1+t,y1=r.y1+t}
  end
  local cx,cy=(r.x0+r.x1)/2,(r.y0+r.y1)/2
  local function scaled(o,k)local q=L.rect(o);return{x0=cx+(q.x0-cx)*k,y0=cy+(q.y0-cy)*k,x1=cx+(q.x1-cx)*k,y1=cy+(q.y1-cy)*k}end
  local out=r
  local function add(q)out={x0=math.min(out.x0,q.x0),y0=math.min(out.y0,q.y0),x1=math.max(out.x1,q.x1),y1=math.max(out.y1,q.y1)}end
  for _,n in ipairs({'ShadowSoft','Shadow'})do add(scaled(b[n],Badge.PopScale));add(scaled(b[n],1))end
  add(scaled(b,Badge.PopScale))
  local half=(r.x1-r.x0)/2*Badge.PulseScale;add({x0=cx-half,y0=cy-half,x1=cx+half,y1=cy+half})
  return out
 end
 function L.clippers(o)
  local out={};local p=o._parent
  while p and not p:IsA('LayerCollector')do
   if p._class=='ScrollingFrame'or p._class=='CanvasGroup'or(p:IsA('GuiObject')and p._props.ClipsDescendants==true)then out[#out+1]=p end
   p=p._parent
  end
  return out
 end
 return L
end
