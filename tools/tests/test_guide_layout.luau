local G=require('./new_Guide');local L=require('./Hud')
local fails=0;local function check(c,msg)if not c then fails+=1;print('FAIL',msg)end end
-- 1) state machine: see test_guide_flow.luau
-- 2) R158e: no words to fill any more; Format still escapes a {name} (kept for older callers)
for _,d in ipairs({'Mouse','Touch','Gamepad','???'})do
 local f=G.Format('{name}',d,'Bob<3&Co')
 check(f:find('Bob&lt;3&amp;Co',1,true)and G.Plain(f)=='Bob<3&Co','escape '..d)
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
for _,v in ipairs(views)do
 local w,h,touch=v[1],v[2],v[3]
 for _,ctl in ipairs({false,true})do
  local m=L.Read({X=w,Y=h},touch,ctl and touch and controls(w,h)or nil)
  -- The card has a fixed height (icon, one picture row, step row) + the 12px face above it (BeginnerTutorial.place); step 10 has two picture rows (they stand beside the icon: + 6 / 8 px).
  for _,rows in ipairs({1,2})do
  local function heightFor(width)return(m.Phone and 100 or 112)+(rows==2 and(m.Phone and 6 or 8)or 0)+12 end
  local c=G.Card(w,h,m,heightFor)
  local relaxed=nil
  if not c.Clear then relaxed=1;c=G.Card(w,h,m,heightFor,1)end
  if not c.Clear then relaxed=2;c=G.Card(w,h,m,heightFor,2)end
  if relaxed then print('  relaxed level',relaxed,w,h)end
  local box={X=c.X-c.Width/2,Y=c.Top,W=c.Width,H=c.Height}
  local hits={}
  for i,b in ipairs(G.Obstacles(m,w,h,relaxed))do if ov(box,b)then hits[#hits+1]=i end end
  check(c.Clear and #hits==0 and box.Y>=0 and box.X>=0 and box.X+box.W<=w and box.Y+box.H<=h,('placement %dx%d (%d rows)'):format(w,h,rows))
  -- R152: with the TRACK / BASE button ringed (top bar row, above the safe area) the card starts below the pressing hand.
  -- R152: the card hugs its words (the shortest card is 300 / 360 wide): it never grows past them and still clears the HUD.
  for _,want in ipairs({m.Phone and 300 or 360,m.Phone and 380 or 460})do
   local hug=G.Card(w,h,m,heightFor,nil,nil,want)
   if not hug.Clear then hug=G.Card(w,h,m,heightFor,1,nil,want)end
   if not hug.Clear then hug=G.Card(w,h,m,heightFor,2,nil,want)end
   local hb={X=hug.X-hug.Width/2,Y=hug.Top,W=hug.Width,H=hug.Height};local hit=false
   check(hug.Width<=want and hug.Clear,('hugging card %dx%d want %d: w=%d'):format(w,h,want,hug.Width))
   check(hb.X>=0 and hb.X+hb.W<=w and hb.Y>=0 and hb.Y+hb.H<=h,('hugging card on screen %dx%d'):format(w,h))
  end
  local pushed=G.Card(w,h,m,heightFor,nil,(m.Phone and 26 or 34))
  if pushed.Clear then
   local pb={X=pushed.X-pushed.Width/2,Y=pushed.Top,W=pushed.Width,H=pushed.Height};local hit=false
   for _,b in ipairs(G.Obstacles(m,w,h))do if ov(pb,b)then hit=true end end
   check(not hit and pb.Y>=(m.Phone and 26 or 34),('pushed placement %dx%d'):format(w,h))
  end
  if not ctl or touch then print(string.format('%s %4dx%-4d %s %d row card x=%4d y=%4d w=%3d h=%3d %s',touch and'TOUCH'or'PC   ',w,h,ctl and'ctl'or'   ',rows,box.X,box.Y,box.W,box.H,c.Clear and #hits==0 and'ok'or'OVERLAP'))end
  end
 end
end
print(fails==0 and'ALL PASS'or('FAILURES '..fails))
