--!nocheck
-- Generic GUI dump for previews: walks a real GUI tree built under the Roblox mock and returns JSON with absolute
-- rectangles (offset/scale/anchor/UIScale), rotation, background, corners, strokes, gradients and text.
-- render_gui.py draws it. Approximation: no real font metrics, images are placeholders.
-- R137 copy (Index preview): also lays out UIGridLayout / UIListLayout children (in LayoutOrder), applies
-- UISizeConstraint.MaxSize and ScrollingFrame.CanvasPosition, and dumps ViewportFrames as image slots named
-- 'VP:<parent name>' (render_index.py pastes a picture there).
local function n(v)return v==nil and'null'or string.format('%.2f',v)end
local function c3(c)return c and string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))or'null'end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function colorSeq(cs)
 if not cs then return'null'end
 if cs.R~=nil then return'[[0,'..c3(cs)..'],[1,'..c3(cs)..']]'end
 if type(cs.A)=='table'and cs.A.R==nil then local out={}
  for _,k in ipairs(cs.A)do out[#out+1]='['..n(k.T)..','..c3(k.V)..']'end;return'['..table.concat(out,',')..']'end
 local a,b=cs.A,cs.B or cs.A;return'[[0,'..c3(a)..'],[1,'..c3(b)..']]'
end
local function numSeq(ns)
 if not ns then return'null'end
 if type(ns)=='number'then return'[[0,'..n(ns)..'],[1,'..n(ns)..']]'end
 if type(ns.A)=='table'then local out={}
  for _,k in ipairs(ns.A)do out[#out+1]='['..n(k.T)..','..n(k.V)..']'end;return'['..table.concat(out,',')..']'end
 local a,b=ns.A,ns.B or ns.A;return'[[0,'..n(a)..'],[1,'..n(b)..']]'
end
local function child(o,class)for _,c in ipairs(o:GetChildren())do if c.ClassName==class then return c end end end
local function gradient(o)
 local g=child(o,'UIGradient');if not g or g.Enabled==false then return'null'end
 local off=g.Offset;return string.format('{"color":%s,"alpha":%s,"rot":%s,"off":[%s,%s]}',colorSeq(g.Color),numSeq(g.Transparency),n(g.Rotation or 0),n(off and off.X or 0),n(off and off.Y or 0))
end
local GUI={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,CanvasGroup=true,ViewportFrame=true}
return function(root,W,H)
 local items={}
 local function walk(o,px,py,pw,ph,k,clip,depth)
  local kids={}
  for i,c in ipairs(o:GetChildren())do if GUI[c.ClassName]then kids[#kids+1]={c,i}end end
  table.sort(kids,function(a,b)local za,zb=a[1].ZIndex or 1,b[1].ZIndex or 1;if za~=zb then return za<zb end;return a[2]<b[2]end)
  -- Layouts: slot positions in LayoutOrder (then child order).
  local slots={}
  local grid,list=child(o,'UIGridLayout'),child(o,'UIListLayout')
  if grid or list then
   local ordered={};for _,pair in ipairs(kids)do if pair[1].Visible~=false then ordered[#ordered+1]=pair end end
   table.sort(ordered,function(a,b)local la,lb=a[1].LayoutOrder or 0,b[1].LayoutOrder or 0;if la~=lb then return la<lb end;return a[2]<b[2]end)
   if grid then
    local cs,cp=grid.CellSize,grid.CellPadding;local cw,ch=cs.X.Scale*pw+cs.X.Offset*k,cs.Y.Scale*ph+cs.Y.Offset*k
    local gx,gy=cp.X.Scale*pw+cp.X.Offset*k,cp.Y.Scale*ph+cp.Y.Offset*k;local cols=math.max(1,math.floor((pw+gx)/(cw+gx)))
    for i,pair in ipairs(ordered)do local col,row=(i-1)%cols,math.floor((i-1)/cols);slots[pair[1]]={px+col*(cw+gx),py+row*(ch+gy),cw,ch}end
   else
    local pad=list.Padding and(list.Padding.Scale*((list.FillDirection and list.FillDirection.Name)=="Horizontal" and pw or ph)+list.Padding.Offset*k)or 0;local at=0
    for _,pair in ipairs(ordered)do local c=pair[1];local sz=c.Size;local w=sz.X.Scale*pw+sz.X.Offset*k;local h=sz.Y.Scale*ph+sz.Y.Offset*k
     if (list.FillDirection and list.FillDirection.Name)=="Horizontal" then slots[c]={px+at,py,w,h};at+=w+pad else slots[c]={px,py+at,w,h};at+=h+pad end end
   end
  end
  for _,pair in ipairs(kids)do
   local c=pair[1]
   if c.Visible~=false then
    local s,p=c.Size,c.Position;local ap=c.AnchorPoint or {X=0,Y=0}
    local scale=child(c,'UIScale');local own=scale and scale.Scale or 1
    local w=(s.X.Scale*pw+s.X.Offset*k);local h=(s.Y.Scale*ph+s.Y.Offset*k)
    local limit=child(c,'UISizeConstraint');if limit and limit.MaxSize then w=math.min(w,limit.MaxSize.X*k);h=math.min(h,limit.MaxSize.Y*k)end
    local ax=px+p.X.Scale*pw+p.X.Offset*k;local ay=py+p.Y.Scale*ph+p.Y.Offset*k
    w*=own;h*=own;local x,y=ax-ap.X*w,ay-ap.Y*h
    local slot=slots[c];if slot then w,h=slot[3]*own,slot[4]*own;x,y=slot[1]+(slot[3]-w)/2,slot[2]+(slot[4]-h)/2 end
    local corner=child(c,'UICorner');local cr=corner and(corner.CornerRadius or{Scale=0,Offset=8});local r=cr and(cr.Scale*math.min(w,h)+cr.Offset*k*own)or 0
    local strokes={}
    for _,st in ipairs(c:GetChildren())do if st.ClassName=='UIStroke'and st.Enabled~=false then
     strokes[#strokes+1]=string.format('{"color":%s,"t":%s,"alpha":%s,"grad":%s,"mode":%s}',c3(st.Color),n((st.Thickness or 1)*k*own),n(st.Transparency or 0),gradient(st),q(st.ApplyStrokeMode and st.ApplyStrokeMode.Name or'Contextual'))
    end end
    local isText=c.ClassName=='TextLabel'or c.ClassName=='TextButton'
    local text='null'
    if isText and c.Text and c.Text~=''then
     local fit=child(c,'UITextSizeConstraint')
     text=string.format('{"s":%s,"size":%s,"scaled":%s,"max":%s,"color":%s,"alpha":%s,"stroke":%s,"strokeAlpha":%s,"x":%s,"y":%s,"rich":%s,"font":%s}',
      q(c.Text),n((c.TextSize or 14)*k*own),tostring(c.TextScaled==true),n(fit and fit.MaxTextSize*k*own or nil),c3(c.TextColor3),n(c.TextTransparency or 0),
      c3(c.TextStrokeColor3),n(c.TextStrokeTransparency or 1),q(c.TextXAlignment and c.TextXAlignment.Name or'Center'),q(c.TextYAlignment and c.TextYAlignment.Name or'Center'),
      tostring(c.RichText==true),q(c.Font and c.Font.Name or'Gotham'))
    end
    local bgA=c.BackgroundTransparency or 0
    items[#items+1]=string.format('{"n":%s,"k":%s,"x":%s,"y":%s,"w":%s,"h":%s,"rot":%s,"bg":%s,"bgA":%s,"r":%s,"grad":%s,"strokes":[%s],"text":%s,"clip":%s,"d":%d,"img":%s}',
     q(c.ClassName=='ViewportFrame'and('VP:'..(c.Parent and c.Parent.Name or''))or c.Name),q(c.ClassName),n(x),n(y),n(w),n(h),n(c.Rotation or 0),c3(c.BackgroundColor3),n(bgA),n(r),gradient(c),table.concat(strokes,','),text,
     clip and('['..n(clip[1])..','..n(clip[2])..','..n(clip[3])..','..n(clip[4])..']')or'null',depth,tostring(c.ClassName=='ImageLabel'or c.ClassName=='ViewportFrame'))
    local nclip=clip
    if c.ClipsDescendants then
     if clip then local x1,y1=math.max(x,clip[1]),math.max(y,clip[2]);nclip={x1,y1,math.min(x+w,clip[1]+clip[3])-x1,math.min(y+h,clip[2]+clip[4])-y1}
     else nclip={x,y,w,h}end
    end
    local cx,cy=0,0;if c.ClassName=='ScrollingFrame'and c.CanvasPosition then cx,cy=c.CanvasPosition.X*k,c.CanvasPosition.Y*k end
    walk(c,x-cx,y-cy,w,h,k*own,nclip,depth+1)
   end
  end
 end
 walk(root,0,0,W,H,1,nil,0)
 return'{"canvas":['..W..','..H..'],"items":['..table.concat(items,',')..']}'
end
