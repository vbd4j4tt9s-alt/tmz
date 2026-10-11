--!nocheck
-- R150 preview helper (not a test): serialises a real GUI tree built under the Roblox mock as nested JSON (raw UDim2 / anchor /
-- rotation / colours / modifiers, children in tree order). render_gui.mjs lays it out like Roblox does (UDim2 against the parent's
-- size, AnchorPoint, UIScale, UICorner, UIStroke, UIGradient, ClipsDescendants, ZIndex siblings) and Chromium draws it, so rotated
-- parents, gradients, strokes and emoji look like the game (approximately: Montserrat stands in for Gotham).
-- Usage: local dump=require('./dump_tree'); print('SCENE name '..dump(root,W,H))
local function num(v)
 if v==nil then return'null'end
 if v~=v or v==math.huge or v==-math.huge then return'0'end
 local s=string.format('%.3f',v):gsub('0+$',''):gsub('%.$','')
 return s==''and'0'or s
end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function c3(c)return c and string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))or'null'end
local function udim2(u)if not u then return'[0,0,0,0]'end return string.format('[%s,%s,%s,%s]',num(u.X.Scale),num(u.X.Offset),num(u.Y.Scale),num(u.Y.Offset))end
local function colorSeq(cs)
 if not cs then return'null'end
 if cs.R~=nil then return'[[0,'..c3(cs)..'],[1,'..c3(cs)..']]'end
 if type(cs.A)=='table'and cs.A.R==nil then local out={};for _,k in ipairs(cs.A)do out[#out+1]='['..num(k.T)..','..c3(k.V)..']'end;return'['..table.concat(out,',')..']'end
 return'[[0,'..c3(cs.A)..'],[1,'..c3(cs.B or cs.A)..']]'
end
local function numSeq(ns)
 if ns==nil then return'null'end
 if type(ns)=='number'then return'[[0,'..num(ns)..'],[1,'..num(ns)..']]'end
 if type(ns.A)=='table'then local out={};for _,k in ipairs(ns.A)do out[#out+1]='['..num(k.T)..','..num(k.V)..']'end;return'['..table.concat(out,',')..']'end
 return'[[0,'..num(ns.A)..'],[1,'..num(ns.B or ns.A)..']]'
end
local function gradient(g)
 if not g or g.Enabled==false then return'null'end
 local off=g.Offset
 return string.format('{"color":%s,"alpha":%s,"rot":%s,"off":[%s,%s]}',colorSeq(g.Color),numSeq(g.Transparency),num(g.Rotation or 0),num(off and off.X or 0),num(off and off.Y or 0))
end
local function child(o,class)for _,c in ipairs(o:GetChildren())do if c.ClassName==class then return c end end end
local GUI={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,CanvasGroup=true,ViewportFrame=true}
local function node(o)
 local ap=o.AnchorPoint or{X=0,Y=0}
 local corner=child(o,'UICorner');local scale=child(o,'UIScale');local fit=child(o,'UITextSizeConstraint')
 local strokes={}
 for _,st in ipairs(o:GetChildren())do
  if st.ClassName=='UIStroke'and st.Enabled~=false then
   strokes[#strokes+1]=string.format('{"color":%s,"t":%s,"a":%s,"mode":%s,"grad":%s}',c3(st.Color),num(st.Thickness or 1),num(st.Transparency or 0),
    q(st.ApplyStrokeMode and st.ApplyStrokeMode.Name or'Contextual'),gradient(child(st,'UIGradient')))
  end
 end
 local isText=o.ClassName=='TextLabel'or o.ClassName=='TextButton'
 local text='null'
 if isText and o.Text and o.Text~=''then
  text=string.format('{"s":%s,"size":%s,"scaled":%s,"wrap":%s,"max":%s,"min":%s,"color":%s,"alpha":%s,"stroke":%s,"strokeA":%s,"x":%s,"y":%s,"rich":%s,"font":%s}',
   q(o.Text),num(o.TextSize or 14),tostring(o.TextScaled==true),tostring(o.TextWrapped==true),num(fit and fit.MaxTextSize or nil),num(fit and fit.MinTextSize or nil),
   c3(o.TextColor3 or Color3.new(0,0,0)),num(o.TextTransparency or 0),c3(o.TextStrokeColor3 or Color3.new(0,0,0)),num(o.TextStrokeTransparency or 1),
   q(o.TextXAlignment and o.TextXAlignment.Name or'Center'),q(o.TextYAlignment and o.TextYAlignment.Name or'Center'),tostring(o.RichText==true),q(o.Font and o.Font.Name or'SourceSans'))
 end
 local kids={}
 for i,c in ipairs(o:GetChildren())do if GUI[c.ClassName]then kids[#kids+1]={c,i}end end
 local parts={}
 for _,pair in ipairs(kids)do parts[#parts+1]=node(pair[1])end
 local bg=o.BackgroundColor3
 local hasBg=(o.BackgroundTransparency or 0)<1
 return string.format('{"n":%s,"k":%s,"vis":%s,"z":%d,"size":%s,"pos":%s,"ap":[%s,%s],"rot":%s,"bg":%s,"bgA":%s,"clip":%s,"cr":%s,"scale":%s,"strokes":[%s],"grad":%s,"text":%s,"kids":[%s]}',
  q(o.Name),q(o.ClassName),tostring(o.Visible~=false),o.ZIndex or 1,udim2(o.Size),udim2(o.Position),num(ap.X),num(ap.Y),num(o.Rotation or 0),
  hasBg and c3(bg or Color3.new(1,1,1))or'null',num(o.BackgroundTransparency or 0),tostring(o.ClipsDescendants==true),
  corner and string.format('[%s,%s]',num(corner.CornerRadius.Scale),num(corner.CornerRadius.Offset))or'null',scale and num(scale.Scale)or'1',
  table.concat(strokes,','),gradient(child(o,'UIGradient')),text,table.concat(parts,','))
end
-- Returns {canvas:[W,H], root:{...}}: the root's own properties are ignored (it is the screen / billboard).
return function(root,W,H)
 local kids={}
 for _,c in ipairs(root:GetChildren())do if GUI[c.ClassName]then kids[#kids+1]=node(c)end end
 return'{"canvas":['..num(W)..','..num(H)..'],"kids":['..table.concat(kids,',')..']}'
end
