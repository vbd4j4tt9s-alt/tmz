local G=require('./new_Guide');local O=require('./old_Guide');local L=require('./Hud')
local fails=0;local function check(c,msg)if not c then fails+=1;print('FAIL',msg)end end
-- 1) state machine: see flow.luau (R111 intentionally ends the tutorial after planting)
-- 2) formatting
for _,d in ipairs({'Mouse','Touch','Gamepad','???'})do
 for i,s in ipairs(G.Steps)do
  for _,t in ipairs({s.Text,s.Equipped,s.Title,s.EquippedTitle,s.Chip and s.Chip.Key,s.Chip and s.Chip.Label,s.EquippedChip and s.EquippedChip.Key})do
   local f=G.Format(t,d,'Bob<3&Co')
   check(not f:find('{',1,true),'placeholder left '..d..' '..i..': '..f)
   check(f:find('Bob&lt;3&amp;Co',1,true)or not t:find('{name}',1,true),'escape '..i)
   check(G.Plain(f):find('Bob<3&Co',1,true)or not t:find('{name}',1,true),'plain '..i)
  end
 end
end
-- 3) placement never overlaps HUD
local function ov(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local function controls(w,h)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-110,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-180,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local views={}
for _,v in ipairs({{1920,1080},{1366,768},{1280,720},{1024,768},{800,600},{1280,540},{960,480},{700,400}})do views[#views+1]={v[1],v[2],false}end
for _,v in ipairs({{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{800,360},{1024,768},{1180,820},{1366,1024},{320,568},{375,667},{390,844},{430,932},{360,740},{768,1024},{820,1180}})do views[#views+1]={v[1],v[2],true}end
local function longestFor(short)local n=0;for _,s in ipairs(G.Steps)do n=math.max(n,#G.Plain(G.Format(G.Copy(s,'Text',short),'Mouse','ABCDEFGHIJKLMNOPQRST')))end;return n end
for _,v in ipairs(views)do
 local w,h,touch=v[1],v[2],v[3]
 for _,ctl in ipairs({false,true})do
  local m=L.Read({X=w,Y=h},touch,ctl and touch and controls(w,h)or nil)
  local font=G.Font(m,w,h);local badge=m.Phone and 46 or 60;local longest=longestFor(m.Phone)
  -- Height estimate: average glyph ~0.55em, 1.2 line height, 20 top + 26 bottom chrome.
  -- R138: the visual card has a fixed height (icon, title, chip, step row) + the 12px name tag.
  local function heightFor(width)return(m.Phone and 100 or 112)+12 end
  local c=G.Card(w,h,m,heightFor)
  local relaxed=nil
  if not c.Clear then relaxed=1;c=G.Card(w,h,m,heightFor,1)end
  if not c.Clear then font-=2;c=G.Card(w,h,m,heightFor,1)end
  if not c.Clear then relaxed=2;c=G.Card(w,h,m,heightFor,2)end
  if relaxed then print('  relaxed level',relaxed,w,h)end
  local box={X=c.X-c.Width/2,Y=c.Top,W=c.Width,H=c.Height}
  local hits={}
  for i,b in ipairs(G.Obstacles(m,w,h,relaxed))do if ov(box,b)then hits[#hits+1]=i end end
  check(c.Clear and #hits==0 and box.Y>=0 and box.X>=0 and box.X+box.W<=w,('placement %dx%d'):format(w,h))
  if not ctl or touch then print(string.format('%s %4dx%-4d %s card x=%4d y=%4d w=%3d h=%3d font=%d %s',touch and'TOUCH'or'PC   ',w,h,ctl and'ctl'or'   ',box.X,box.Y,box.W,box.H,font,c.Clear and #hits==0 and'ok'or'OVERLAP'))end
 end
end
print(fails==0 and'ALL PASS'or('FAILURES '..fails))
