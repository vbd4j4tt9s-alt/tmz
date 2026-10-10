--!nocheck
-- R157: the title screen's rotating "tip:" line (owner-approved, R156 title_tips.md round 2). On the Roblox mock with the REAL TitleScreen104 and the REAL TitleTips156 of this checkout, the
-- title started at each screen size and stepped through its own frame function (the one RunService calls), exactly like the game.
--  A. the list: the 24 tips, their kinds, the {y} / {g} markup, simple words, "you" / "your" in full
--  B. the markup as RichText (T.Rich / T.Plain / T.Line), what a stray & < > does, an unknown {x}
--  C. the order: a shuffle of all 24 with no repeats, a random first tip, a new shuffle (not the same tip twice in a row) when every tip has shown
--  D. the rotation in the title: a new tip every 10 s, every tip once before any repeat, the text changes while the line is invisible
--  E. the fade (0.4 s in / out) and the pulse (R157b, "too jittery": +-3%, a full breath every 1.8 s, a UIScale; was +-5% every 0.5 s with a 1.5 px bob): the line is never moved, and a slow
--     frame (0.1 s) moves the scale by 1% at most (was 6.3%)
--  F. Reduced Motion: no fade, no pulse (also switched on and off while the title shows)
--  G. the layout at PC 1920x1080, 1366x768, 844x390, 390x844, 360x640, 320x568 (and more): the line is centred in the gap, the gap is at least the line's height + 20 px, the line (grown by
--     the pulse) never touches the logo, the pack or the button (grown by its hover), the logo is 443 px wide at 844x390 and unchanged where the room was there; a resize
--  H. no input: the label is not active, not interactable, has no listener; the click and Enter still start the game; it fades out with the title
--  I. nothing allocated per frame (no UDim2 / Vector2 / Color3 / Instance ... built by the tip line, A / B against the title without tips; the step's code has no table, closure, string);
--     the pulse runs only while the title shows and stops when it closes
--  J. a missing / broken / late list never blocks the title
local W=require('./world');local R=W.R
local V2=R.Vector2.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end

-- ======================================================================================================================
-- the mock (as the R156 preview scene): what TitleScreen104 needs to start and run
-- ======================================================================================================================
rawset(R.Enum.PlayerActions,'GetEnumItems',function()return {}end)
W.service('ReplicatedFirst').RemoveDefaultLoadingScreen=function()end
W.service('Lighting');W.service('ProximityPromptService').Enabled=true;W.service('ContentProvider')
W.UIS.GamepadEnabled=false;W.Gui.MenuIsOpen=false
do -- (the mock's buttons have no MouseButton1Down / Up)
 local inew=R.Instance.new
 R.Instance.new=function(class,parent)
  local o=inew(class,parent)
  if class:find('Button')then o._props.MouseButton1Down=R.signal();o._props.MouseButton1Up=R.signal()end
  return o
 end
 W.env.Instance=R.Instance
end
local binds={}
function W.Run.BindToRenderStep(_,name,_,fn)binds[name]=fn end
function W.Run.UnbindFromRenderStep(_,name)binds[name]=nil end
W.service('ContextActionService').BindActionAtPriority=function(_,name,fn)W.actions[name]=fn end
local BINDING='StealAPackTitle104'
local Players=W.service('Players')
local T=W.module('TitleScreen104');local Tips=W.module('TitleTips156')
local RS=W.RS;local TipsModule=RS:FindFirstChild('TitleTips156')
-- warnings the title prints
local warnings={}
W.env.warn=function(...)local parts={};for i=1,select('#',...)do parts[i]=tostring((select(i,...)))end;warnings[#warnings+1]=table.concat(parts,' ')end
local function warned(prefix)local n=0;for _,m in ipairs(warnings)do if m:sub(1,#prefix)==prefix then n+=1 end end;return n end
-- a seeded Random (the mock's own is a poor generator): xorshift32
local function makeRng(seed)
 local s=bit32.bor(bit32.band(seed*2654435761,0xFFFFFFFF),1)
 return {NextInteger=function(_,a,b)
  s=bit32.bxor(s,bit32.lshift(s,13));s=bit32.bxor(s,bit32.rshift(s,17));s=bit32.bxor(s,bit32.lshift(s,5))
  return a+math.floor(s/4294967296*(b-a+1))
 end}
end
local seedFor=1
W.env.Random={new=function(seed)return makeRng(seed or seedFor)end}
-- constructor counters (I): every value type the title could build per frame
local counts={}
do
 local function wrap(tbl,label,keys)for _,k in ipairs(keys)do local f=tbl[k];tbl[k]=function(...)counts[label..'.'..k]=(counts[label..'.'..k]or 0)+1;return f(...)end end end
 wrap(R.UDim2,'UDim2',{'new','fromOffset','fromScale'});wrap(R.UDim,'UDim',{'new'});wrap(R.Vector2,'Vector2',{'new'});wrap(R.Vector3,'Vector3',{'new'})
 wrap(R.Color3,'Color3',{'new','fromRGB'});wrap(R.CFrame,'CFrame',{'new','Angles','lookAt'});wrap(R.Instance,'Instance',{'new'})
 wrap(R.NumberSequence,'NumberSequence',{'new'});wrap(R.ColorSequence,'ColorSequence',{'new'});wrap(R.TweenInfo,'TweenInfo',{'new'})
end
local function snapshot()local c=table.clone(counts);c._created=#R.created;return c end
local function diff(a,b)local d={};for k,v in pairs(b)do if v-(a[k]or 0)~=0 then d[k]=v-(a[k]or 0)end end;return d end
local function sameDiff(d1,d2)for k,v in pairs(d1)do if d2[k]~=v then return false end end;for k,v in pairs(d2)do if d1[k]~=v then return false end end;return true end
local function show(d)local t={};for k,v in pairs(d)do t[#t+1]=k..'='..v end;table.sort(t);return table.concat(t,' ')end

-- ======================================================================================================================
-- the title at a size, stepped through its own frame function
-- ======================================================================================================================
local function boot(o)
 o=o or{}
 local w,h=o.w or 1920,o.h or 1080
 W.UIS.TouchEnabled=o.touch or false;W.UIS.KeyboardEnabled=not o.touch
 W.Gui.ReducedMotionEnabled=o.reduced==true
 W.Gui.GetInsetArea=function()return{Min=V2(0,0),Width=w,Height=h}end
 W.workspace.CurrentCamera.ViewportSize=V2(w,h)
 seedFor=o.seed or 1
 T.TipOrder=o.order
 local player=R.new('Player');player.Name='Ann';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 local nWarn=#warnings
 local stop=T.Start(player,pg)
 T.TipOrder=nil
 local backdrop=pg:FindFirstChild('StealAPackTitleBackdrop');local screen=pg:FindFirstChild('StealAPackTitle')
 local group=screen:FindFirstChild('TitleContent')
 group.AbsoluteSize=V2(w,h);backdrop.AbsoluteSize=V2(w,h);screen.AbsoluteSize=V2(w,h) -- (the mock's size is 100 x 40; the title lays out from it)
 local h_={w=w,h=h,pg=pg,screen=screen,backdrop=backdrop,group=group,stop=stop,t=0,startWarnings=nWarn}
 h_.visual=group:FindFirstChild('Logo');h_.button=group:FindFirstChild('ClickToStart')
 function h_.label()return group:FindFirstChild('TipLine')end
 function h_.step(n,dt)
  dt=dt or 1/60
  for _=1,n do
   R.advance(dt);local f=binds[BINDING];if not f then return false end;f(dt);h_.t+=dt
  end
  return binds[BINDING]~=nil
 end
 function h_.alive()return binds[BINDING]~=nil end
 function h_.close()if h_.stop then h_.stop()end;h_.stop=nil;pg.Parent=nil end
 return h_
end
local function lineOf(index)return Tips.Line(index)end
local indexOfLine={};for i=1,#Tips.Tips do indexOfLine[Tips.Line(i)]=i end
local function shownIndex(label)return indexOfLine[label.Text]end

-- ======================================================================================================================
-- A. the list
-- ======================================================================================================================
print('-- A. the list')
local EXPECTED={
 {'howto','{y}rare packs{/y} = {g}better seeds{/g}'},
 {'howto','{y}mythic packs{/y} give the most {g}King{/g} seeds 👑'},
 {'howto','every {y}10th pack{/y} you open is {g}lucky{/g}! 🍀'},
 {'howto','{y}boots{/y} give biome packs more {g}luck{/g}'},
 {'howto','click or tap a pack {y}5 times{/y} to open it'},
 {'howto','hold {y}E{/y} to {g}steal{/g} a pack'},
 {'howto','dig holes with your {y}shovel{/y} to trip {g}pack thieves{/g}'},
 {'howto','the {y}shovel{/y} can remove plants in your {g}garden{/g}'},
 {'howto','hit thieves with your {y}bat{/y} to {g}drop their pack{/g}'},
 {'howto','click soil with a {y}seed{/y} to {g}plant{/g} it 🌱'},
 {'howto',"plants {g}grow{/g} even when you're {y}gone{/y}"},
 {'howto','{y}weather{/y} can make your plants {g}worth more{/g}'},
 {'howto','{y}gold{/y} fruit sells x3, {g}diamond{/g} fruit x6 💎'},
 {'howto','sell your {y}fruit{/y} at the {g}market{/g}'},
 {'howto','{y}fruit of the hour{/y} sells for up to {g}x3{/g}'},
 {'howto','walk on a {y}treadmill{/y} to get {g}faster{/g} ⚡'},
 {'howto','{y}friends{/y} in your server help you get {g}faster{/g}'},
 {'howto','{y}keeper{/y} signs show the {g}speed you need{/g}'},
 {'howto','play to unlock a {y}mystery pack{/y} {g}each day{/g}'},
 {'lore','beware {y}the darkened{/y}'},
 {'lore','when the {y}lights go out{/y}... run'},
 {'lore','are you faster than {y}the darkened{/y}?'},
 {'lore','something waits at the end of {y}storm peaks{/y}'},
 {'egg','dont look into the {y}pyramid{/y}'},
}
check(#Tips.Tips==24,'24 tips ('..#Tips.Tips..')')
local kinds={howto=0,lore=0,egg=0}
for i,e in ipairs(EXPECTED)do
 local tip=Tips.Tips[i]
 if check(tip~=nil,'tip '..i..' exists')then
  check(tip.Kind==e[1],'tip '..i..' kind '..tostring(tip.Kind)..' (expected '..e[1]..')')
  check(tip.Text==e[2],'tip '..i..' text is exactly as listed: '..tostring(tip.Text))
  kinds[tip.Kind]=(kinds[tip.Kind]or 0)+1
 end
end
check(kinds.howto==19 and kinds.lore==4 and kinds.egg==1,('19 how-to, 4 lore, 1 easter egg (%d / %d / %d)'):format(kinds.howto,kinds.lore,kinds.egg))
check(Tips.Tips[24].Text=='dont look into the {y}pyramid{/y}' and Tips.Plain(Tips.Tips[24].Text)=='dont look into the pyramid','the easter egg is "dont look into the pyramid"')
check(Tips.Interval==10 and Tips.Fade==.4 and Tips.Prefix=='tip:' and Tips.PulseAmount==.03 and Tips.PulsePeriod==1.8 and Tips.BobPixels==nil and Tips.BobPeriod==nil,'the numbers at the top of the list: 10 s, 0.4 s, "tip:", pulse +-3% every 1.8 s, no bob (R157b: was +-5% every 0.5 s and a 1.5 px bob every 1.9 s)')
check(Tips.Colors.y=='#FFE14D' and Tips.Colors.g=='#77E542','yellow #FFE14D and green #77E542')
local seen={}
for i,tip in ipairs(Tips.Tips)do
 local plain=Tips.Plain(tip.Text)
 local opens={y=0,g=0};local closes={y=0,g=0}
 for c in tip.Text:gmatch('{(%a)}')do opens[c]=(opens[c]or 0)+1 end
 for c in tip.Text:gmatch('{/(%a)}')do closes[c]=(closes[c]or 0)+1 end
 local words=opens.y+opens.g
 check(opens.y==closes.y and opens.g==closes.g and words>=1 and words<=2,'tip '..i..': 1-2 highlighted words, every {y} / {g} closed ('..tip.Text..')')
 check(not tip.Text:gsub('{/?[yg]}',''):find('[{}<>&]'),'tip '..i..': no other brace, <, > or & in the text')
 check(not plain:find('%f[%a]ur?%f[%A]'),'tip '..i..': "you" / "your" in full, not u / ur ('..plain..')')
 check(utf8.len(plain)<=55,'tip '..i..' is short ('..utf8.len(plain)..' characters)')
 check(not seen[plain],'tip '..i..' is not a repeat of another');seen[plain]=true
end
local youTips=0;for _,tip in ipairs(Tips.Tips)do if Tips.Plain(tip.Text):find('%f[%a]your?%f[%A]')then youTips+=1 end end
check(youTips>=9,'the "you" / "your" tips are written in full ('..youTips..' tips)')

-- ======================================================================================================================
-- B. the markup as RichText
-- ======================================================================================================================
print('-- B. RichText')
check(Tips.Rich(Tips.Tips[2].Text)=='<font color="#FFE14D">mythic packs</font> give the most <font color="#77E542">King</font> seeds 👑','Rich: tip 2 (yellow, green, emoji kept)')
check(Tips.Rich(Tips.Tips[24].Text)=='dont look into the <font color="#FFE14D">pyramid</font>','Rich: the easter egg (one yellow word)')
check(Tips.Rich('a & b < c > d')=='a &amp; b &lt; c &gt; d','Rich escapes & < >')
check(Tips.Rich('{y}a<b{/y} {g}c&d{/g}')=='<font color="#FFE14D">a&lt;b</font> <font color="#77E542">c&amp;d</font>','Rich: a stray < or & inside a highlight cannot break the line')
check(Tips.Rich('{x}no{/x}')=='{x}no{/x}','Rich: an unknown {x} is left as written')
check(Tips.Plain('{y}x{/y} and {g}y{/g}')=='x and y','Plain strips the markup')
check(Tips.Line(0)==''and Tips.Line(25)==''and Tips.Line(nil)=='','Line of a tip that does not exist is empty')
for i,tip in ipairs(Tips.Tips)do
 local rich=Tips.Rich(tip.Text);local line=Tips.Line(i)
 local fonts=select(2,rich:gsub('<font color="#%x%x%x%x%x%x">',''));local ends=select(2,rich:gsub('</font>',''))
 local opens=select(2,tip.Text:gsub('{[yg]}',''))
 check(fonts==opens and ends==opens,'tip '..i..': one <font> per highlighted word')
 check(not rich:find('[{}]'),'tip '..i..': no markup left in the RichText')
 check(rich:gsub('<[^>]+>','')==Tips.Plain(tip.Text):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'),'tip '..i..': the RichText without its tags is the plain text')
 check(line=='<font color="#C8D9E8">tip:</font> '..rich,'tip '..i..': Line = the pale "tip:" then the tip')
 local colors={};for c in rich:gmatch('<font color="(#%x+)">')do colors[#colors+1]=c end
 for _,c in ipairs(colors)do check(c=='#FFE14D'or c=='#77E542'or c=='#C8D9E8','tip '..i..': only the two highlight colours ('..c..')')end
end

-- ======================================================================================================================
-- C. the order
-- ======================================================================================================================
print('-- C. the order')
local function isPermutation(order,n)
 if #order~=n then return false end
 local used={};for _,v in ipairs(order)do if type(v)~='number'or v<1 or v>n or v%1~=0 or used[v]then return false end;used[v]=true end
 return true
end
do
 local firsts={};local allPerm=true;local distinctOrders={}
 for seed=1,100 do
  local o=Tips.Order(makeRng(seed))
  if not isPermutation(o,24)then allPerm=false end
  firsts[o[1]]=true;distinctOrders[table.concat(o,',')]=true
 end
 local nFirst=0;for _ in pairs(firsts)do nFirst+=1 end;local nOrders=0;for _ in pairs(distinctOrders)do nOrders+=1 end
 check(allPerm,'Order: every order is each of the 24 tips exactly once')
 check(nFirst>=15,'Order: the first tip is random ('..nFirst..' different first tips in 100 shuffles)')
 check(nOrders>=95,'Order: the shuffles differ ('..nOrders..' different orders in 100)')
 local into={};local back=Tips.Order(makeRng(7),into)
 check(back==into and isPermutation(into,24),'Order(random, table): fills that table in place')
 local again=Tips.Order(makeRng(8),into);check(again==into,'... and again, still the same table')
 local avoidOk=true
 for avoid=1,24 do for seed=1,40 do local o=Tips.Order(makeRng(seed*31+avoid),nil,avoid);if o[1]==avoid or not isPermutation(o,24)then avoidOk=false end end end
 check(avoidOk,'Order(random, nil, avoid): never starts with the tip just shown, still all 24 once')
end

-- ======================================================================================================================
-- D. the rotation in the title
-- ======================================================================================================================
print('-- D. the rotation')
do
 -- the first tip is random: a new random tip each time the title shows
 local firstSeen={};local ok=true
 for seed=1,40 do
  local t=boot({seed=seed});t.step(2)
  local label=t.label()
  if not label or shownIndex(label)~=Tips.Order(makeRng(seed))[1]then ok=false end
  if label then firstSeen[shownIndex(label)or 0]=true end
  t.close()
 end
 local n=0;for _ in pairs(firstSeen)do n+=1 end
 check(ok,'the title opens with the first tip of its (seeded) shuffle')
 check(n>=12,'the first tip is random: '..n..' different first tips in 40 visits')
 -- 515 s at 60 fps: two whole passes and a bit
 local seed=5
 local rng=makeRng(seed);local pass1=Tips.Order(rng);local pass2=Tips.Order(rng,nil,pass1[24])
 local t=boot({seed=seed});local label=t.label()
 check(label~=nil,'the title built its tip line')
 local shown={shownIndex(label)};local times={0};local alphaBefore,alphaAfter={},{}
 local lastText=label.Text;local lastAlpha=1-label.TextTransparency
 local frames=0;local alive=true
 while t.t<515 and alive do
  alive=t.step(1)
  frames+=1
  local text=label.Text;local alpha=1-label.TextTransparency
  if text~=lastText then
   shown[#shown+1]=shownIndex(label);times[#times+1]=t.t;alphaBefore[#alphaBefore+1]=lastAlpha;alphaAfter[#alphaAfter+1]=alpha;lastText=text
  end
  lastAlpha=alpha
 end
 check(alive,'the title kept running for 515 s of frames')
 check(#shown==52,'one tip at the start and a new one every 10 s: '..#shown..' tips in 515 s (52 expected)')
 local first24,second24={},{}
 for i=1,24 do first24[i]=shown[i];second24[i]=shown[24+i]end
 check(isPermutation(first24,24),'the first 24 tips shown are all 24 tips, no repeat until every tip has shown ('..table.concat(first24,',')..')')
 check(table.concat(first24,',')==table.concat(pass1,','),'... in the shuffled order of the list (Tips.Order)')
 check(isPermutation(second24,24),'the next 24 are all 24 again, no repeat ('..table.concat(second24,',')..')')
 check(table.concat(second24,',')==table.concat(pass2,',')and table.concat(second24,',')~=table.concat(first24,','),'... in a new shuffle, not the same order again')
 check(shown[25]~=shown[24],'the same tip is never shown twice in a row (across the new shuffle too)')
 local worstTime,worstAlpha=0,0
 for i=2,#times do
  worstTime=math.max(worstTime,math.abs(times[i]-(i-1)*10));worstAlpha=math.max(worstAlpha,alphaBefore[i-1],alphaAfter[i-1])
 end
 check(worstTime<=1/60+1e-6,('a new tip every 10 s (worst %.4f s off)'):format(worstTime))
 check(worstAlpha<=1/60/Tips.Fade+1e-6,('the text changes while the line is invisible (worst alpha %.3f around a change)'):format(worstAlpha))
 t.close()
 -- the fixed-order hook (the tests and the preview): the list is copied, never changed
 local fixed={24,3,17,1,2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,22,23}
 local copy=table.clone(fixed)
 local t2=boot({order=fixed});t2.step(2);check(shownIndex(t2.label())==24,'T.TipOrder: the title starts with the given first tip')
 t2.step(60*10,1/60);check(shownIndex(t2.label())==3,'... and goes on in the given order')
 check(table.concat(fixed,',')==table.concat(copy,','),'... and does not change the table it was given')
 t2.close()
end

-- ======================================================================================================================
-- E. fade, pulse (and no bob)
-- ======================================================================================================================
print('-- E. fade, pulse')
do
 local t=boot({seed=3});local label=t.label();local stroke=label:FindFirstChildOfClass('UIStroke');local scale=label:FindFirstChildOfClass('UIScale')
 local L=T.Layout(1920,1080)
 local DT=1/240
 local clock,pulse=0,0
 local worstFade,worstPulse,worstStroke=0,0,0
 local maxS,minS=-9,9
 local pulseUp={}
 local prevS,maxSpeed
 local atHalfIn,atFull,atHalfOut,atZero
 local rest=label.Position
 local moved=0
 maxSpeed=0
 for _=1,240*24 do
  t.step(1,DT)
  clock+=DT;pulse+=DT
  if clock>=Tips.Interval then clock-=Tips.Interval end
  local alpha=1-label.TextTransparency
  local expect=math.min(1,clock/Tips.Fade,(Tips.Interval-clock)/Tips.Fade)
  worstFade=math.max(worstFade,math.abs(alpha-expect));worstStroke=math.max(worstStroke,math.abs(stroke.Transparency-label.TextTransparency))
  local s=scale.Scale
  worstPulse=math.max(worstPulse,math.abs(s-(1+.03*math.sin(pulse*math.pi*2/1.8))))
  maxS=math.max(maxS,s);minS=math.min(minS,s)
  if prevS then maxSpeed=math.max(maxSpeed,math.abs(s-prevS)/DT) end
  if prevS and prevS<1 and s>=1 then pulseUp[#pulseUp+1]=t.t end
  prevS=s
  if label.Position~=rest or label.Position.X.Offset~=1920/2 or label.Position.Y.Offset~=L.TipY then moved+=1 end
  if math.abs(t.t-.2)<DT/2 then atHalfIn=alpha end
  if math.abs(t.t-.4)<DT/2 then atFull=alpha end
  if math.abs(t.t-9.8)<DT/2 then atHalfOut=alpha end
  if math.abs(t.t-9.9999)<DT then atZero=math.min(atZero or 1,alpha)end
 end
 check(worstFade<1e-9,('the fade follows min(1, t / 0.4, (10 - t) / 0.4) every frame (worst %.2e)'):format(worstFade))
 check(worstStroke==0,'the outline fades with the text')
 check(atHalfIn and near(atHalfIn,.5,.02),'fade in: half way at 0.2 s ('..tostring(atHalfIn)..')')
 check(atFull and near(atFull,1,.02),'fade in: fully visible at 0.4 s ('..tostring(atFull)..')')
 check(atHalfOut and near(atHalfOut,.5,.02),'fade out: half way at 9.8 s ('..tostring(atHalfOut)..')')
 check(atZero and atZero<.02,'fade out: invisible at 10 s ('..tostring(atZero)..')')
 check(worstPulse<1e-9,('the pulse is 1 + 0.03 sin(2 pi t / 1.8) every frame (worst %.2e)'):format(worstPulse))
 check(near(maxS,1.03,1e-3)and near(minS,.97,1e-3)and maxS<=1.03+1e-9 and minS>=.97-1e-9,('pulse amplitude +-3%%: %.4f .. %.4f'):format(minS,maxS))
 local periodOk=#pulseUp>=12
 for i=2,#pulseUp do if not near(pulseUp[i]-pulseUp[i-1],1.8,2*DT)then periodOk=false end end
 check(periodOk,'pulse period: a full breath every 1.8 s ('..#pulseUp..' breaths in 24 s)')
 -- calm: the fastest the scale ever changes. R157b: it was 0.63 per second (+-5% every 0.5 s); the sine's top speed is amplitude * 2 pi / period
 check(maxSpeed<=.03*math.pi*2/1.8*1.001 and maxSpeed>=.03*math.pi*2/1.8*.98,('the scale changes by at most %.3f per second (0.105 expected; it was 0.628: 6 times calmer)'):format(maxSpeed))
 check(maxSpeed*L.TipSize<=3.5,('... at the biggest text (%d px) that is %.2f px of text size per second (it was %.1f)'):format(L.TipSize,maxSpeed*L.TipSize,.05*math.pi*2/.5*L.TipSize))
 -- the line is never moved (R157b: no bob): the same Position in every frame, so there is no pixel to hop to
 check(moved==0,'the line never moves: the same Position (centre, '..L.TipY..') in all '..(240*24)..' frames ('..moved..' differ)')
 t.close()
 -- a slow frame (the game is loading; the title clamps a frame to 0.1 s): the scale moves by 1% at most (it was 6.3%)
 local t2=boot({seed=3});local s2=t2.label():FindFirstChildOfClass('UIScale');local worstJump,prev=0,1
 for _=1,400 do t2.step(1,.1);local s=s2.Scale;worstJump=math.max(worstJump,math.abs(s-prev));prev=s end
 check(worstJump<=.03*math.pi*2*.1/1.8+1e-9,('a 0.1 s frame (the title\'s longest) changes the scale by %.4f at most (0.0105 = 1%%; it was 0.063)'):format(worstJump))
 t2.close()
end

-- ======================================================================================================================
-- F. Reduced Motion
-- ======================================================================================================================
print('-- F. Reduced Motion')
do
 local t=boot({reduced=true,seed=4});local label=t.label();local scale=label:FindFirstChildOfClass('UIScale');local stroke=label:FindFirstChildOfClass('UIStroke')
 local L=T.Layout(1920,1080)
 local bad=0;local changes=0;local last=label.Text;local when={}
 for _=1,60*25 do
  t.step(1)
  if label.TextTransparency~=0 or stroke.Transparency~=0 or scale.Scale~=1 or label.Position.Y.Offset~=L.TipY or label.Position.X.Offset~=1920/2 then bad+=1 end
  if label.Text~=last then changes+=1;when[#when+1]=t.t;last=label.Text end
 end
 check(bad==0,'Reduced Motion: fully visible, scale 1, not moved, in every frame ('..bad..' frames differ)')
 check(changes==2 and near(when[1],10,1/60+1e-6)and near(when[2],20,1/60+1e-6),'Reduced Motion: the text still changes every 10 s (at '..table.concat(when,', ')..')')
 t.close()
 -- switched on and off while the title shows
 local t2=boot({seed=4});local label2=t2.label();local scale2=label2:FindFirstChildOfClass('UIScale')
 t2.step(60*3+7)
 check(scale2.Scale~=1,'(not reduced: the line pulses)')
 W.Gui.ReducedMotionEnabled=true;t2.step(1)
 check(scale2.Scale==1 and label2.TextTransparency==0 and label2.Position.Y.Offset==L.TipY,'Reduced Motion switched on: the next frame has no pulse, no fade')
 W.Gui.ReducedMotionEnabled=false;t2.step(6)
 check(scale2.Scale~=1 and label2.Position.Y.Offset==L.TipY,'... and switched off again: the pulse is back (and the line is where it was)')
 t2.close()
end

-- ======================================================================================================================
-- G. the layout
-- ======================================================================================================================
print('-- G. the layout')
local OLD={ -- the title's Layout before R157 (logo width, logo y, button y)
 ['1920x1080']={1160,464.4,1005},['1366x768']={1090.955,330.240,693},['844x390']={477.248,160.3,342.6},['390x844']={354.9,362.92,769},['360x640']={327.6,275.2,574.4},['320x568']={291.2,244.24,509.78},
}
local SIZES={{1920,1080,false},{1366,768,false},{844,390,true},{390,844,true},{360,640,true},{320,568,true},{2560,1440,false},{1280,720,false},{568,320,true},{932,430,true},{412,915,true},{768,1024,true}}
local function rectOf(o,k)
 local p,s=o.Position,o.Size;k=k or 1
 local cx,cy,hw,hh=p.X.Offset,p.Y.Offset,s.X.Offset*k/2,s.Y.Offset*k/2
 return {l=cx-hw,r=cx+hw,t=cy-hh,b=cy+hh}
end
local function packOf(logo) -- the pack art's box inside the logo (the title's ViewportFrame: Position .71,.04 / Size .29,.92 of the logo)
 local w,h=logo.r-logo.l,logo.b-logo.t
 return {l=logo.l+.71*w,r=logo.l+.71*w+.29*w,t=logo.t+.04*h,b=logo.t+.04*h+.92*h}
end
do
 local src=W.B.TitleScreen104
 check(src:find("Position=UDim2.fromScale(.71,.04),Size=UDim2.fromScale(.29,.92)",1,true)~=nil,'the pack art box used here (.71,.04 / .29,.92 of the logo) is the title\'s')
end
local minAir=1e9
for _,s in ipairs(SIZES)do
 local w,h,touch=s[1],s[2],s[3];local name=w..'x'..h
 local L=T.Layout(w,h)
 local logoBottom=L.LogoY+L.LogoHeight/2;local buttonTop=L.ButtonY-L.ButtonHeight/2
 local gap=buttonTop-logoBottom
 check(gap>=L.TipHeight+20-1e-6,('%s: the gap (%.1f) is at least the line height + 20 (%d)'):format(name,gap,L.TipHeight+20))
 check(near((L.TipY-logoBottom),(buttonTop-L.TipY),1e-6),('%s: the line is vertically centred in the gap'):format(name))
 check(L.TipSize>=16 and L.TipSize<=32 and L.TipSize==math.clamp(math.floor(h*.03),16,32),('%s: the text size cap %d is 3%% of the height, 16 to 32'):format(name,L.TipSize))
 local lines=w<520 and 2 or 1
 check(L.TipHeight>=lines*L.TipSize*1.15 and L.TipHeight<=lines*L.TipSize*1.15+5,('%s: the line box (%d px) holds %d line(s) of %d px'):format(name,L.TipHeight,lines,L.TipSize))
 check(L.TipWidth==math.min(780,w-48),('%s: the line box is %d px wide, inside the screen'):format(name,L.TipWidth))
 -- every tip shrinks to fit (TextScaled 11-32): a safe estimate of 0.6 em per character
 local worst=99
 for _,tip in ipairs(Tips.Tips)do
  local chars=utf8.len(Tips.Plain(tip.Text))+5
  local size=math.min(L.TipSize,L.TipHeight/(1.15*lines),L.TipWidth*lines/(.6*chars))
  worst=math.min(worst,size)
 end
 check(worst>=11,('%s: every tip fits in %d line(s) at %.1f px or more (11 is the smallest allowed)'):format(name,lines,worst))
 -- the real title at this size: the actual boxes, over a full breath (1.8 s) of the pulse, with the button hovered
 local t=boot({w=w,h=h,touch=touch,seed=2});local label=t.label()
 t.button.MouseEnter:Fire();t.step(90)
 local scale=label:FindFirstChildOfClass('UIScale')
 local logo=rectOf(t.visual);local pack=packOf(logo);local btn=rectOf(t.button,t.button:FindFirstChildOfClass('UIScale').Scale)
 check(near(t.button:FindFirstChildOfClass('UIScale').Scale,1.035,.002),name..': (the button is at its hover size 1.035)')
 check(near(logo.b-logo.t,L.LogoHeight,1e-6)and near(logo.r-logo.l,L.LogoWidth,1e-6),name..': the title uses Layout for the logo')
 check(label.Size.X.Offset==L.TipWidth and label.Size.Y.Offset==L.TipHeight and label.Position.X.Offset==w/2,name..': the line box is Layout\'s, centred across')
 check(label:FindFirstChildOfClass('UITextSizeConstraint').MaxTextSize==L.TipSize and label:FindFirstChildOfClass('UITextSizeConstraint').MinTextSize==11,name..': TextScaled between 11 and '..L.TipSize..' px')
 check(label.TextScaled==true and label.RichText==true and label.TextWrapped==true,name..': TextScaled, RichText, wrapped')
 local airAbove,airBelow,airPack=1e9,1e9,1e9;local inside=true
 for _=1,440 do
  t.step(1,1/240)
  local tip=rectOf(label,scale.Scale)
  airAbove=math.min(airAbove,tip.t-logo.b);airBelow=math.min(airBelow,btn.t-tip.b);airPack=math.min(airPack,tip.t-pack.b)
  if tip.l<0 or tip.r>w then inside=false end
 end
 check(airAbove>=4 and airBelow>=4 and airPack>=4,('%s: the line (pulsing) stays clear of the logo %.1f px, the pack %.1f px and the hovered button %.1f px'):format(name,airAbove,airPack,airBelow))
 check(inside,name..': the line stays on the screen')
 check(pack.b<=logo.b+1e-6 and pack.t>=logo.t-1e-6,name..': the pack is inside the logo\'s box')
 minAir=math.min(minAir,airAbove,airBelow)
 print(('   %-9s gap %6.1f px (needs %3d), line %d px high, air above / below the pulsing line %.1f / %.1f px, logo %.0f wide'):format(name,gap,L.TipHeight+20,L.TipHeight,airAbove,airBelow,L.LogoWidth))
 t.close()
 -- PC and portrait unchanged where the room was there; the landscape phone's logo is smaller
 local old=OLD[name]
 if old then
  local roomBefore=true
  local oldGap=(old[3]-L.ButtonHeight/2)-(old[2]+old[1]/1.7768/2)
  if oldGap>=L.TipHeight+20 then
   check(near(L.LogoWidth,old[1],.01)and near(L.LogoY,old[2],.01)and near(L.ButtonY,old[3],.01),name..': logo, pack and button are where they were (the gap was already '..('%.0f'):format(oldGap)..' px)')
  else
   check(L.LogoWidth<old[1]and near(gap,L.TipHeight+20,1e-6),('%s: the logo is %.1f%% smaller (%.0f px, was %.0f), just enough for the gap'):format(name,100-100*L.LogoWidth/old[1],L.LogoWidth,old[1]))
   check(near(L.ButtonY,old[3],.01),name..': the button is where it was')
  end
 end
end
do
 local L=T.Layout(844,390)
 check(math.floor(L.LogoWidth+.5)==443,('landscape phone 844x390: the logo is 443 px wide (%.1f)'):format(L.LogoWidth))
 check(near(1-L.LogoWidth/477.248,.07,.005),('... 7%% smaller than the 477 px before (%.1f%%)'):format(100-100*L.LogoWidth/477.248))
 local P=T.Layout(1920,1080)
 check(near(P.LogoWidth,1160,1e-6)and P.TipHeight==41 and P.TipSize==32,'PC 1920x1080: the logo is 1160 px wide as before, the line is up to 32 px, 41 px high')
 local Q=T.Layout(390,844)
 check(near(Q.LogoWidth,354.9,1e-6)and Q.TipHeight==62 and Q.TipSize==25,'portrait 390x844: the logo is 355 px wide as before, two lines of up to 25 px, 62 px high')
end
do -- a sweep: every size from a phone to a big monitor
 local bad=0;local n=0
 for w=320,2560,40 do for h=240,1440,20 do
  local L=T.Layout(w,h);n+=1
  local gap=L.ButtonY-L.ButtonHeight/2-(L.LogoY+L.LogoHeight/2)
  if L.LogoWidth>1 and(gap<L.TipHeight+20-1e-6 or not near(L.TipY-(L.LogoY+L.LogoHeight/2),L.ButtonY-L.ButtonHeight/2-L.TipY,1e-6)or L.LogoY-L.LogoHeight/2<8-1e-6)then bad+=1 end
 end end
 check(bad==0,'sweep of '..n..' screen sizes (320x240 to 2560x1440): the gap is at least the line + 20 px, the line centred, the logo on the screen ('..bad..' bad)')
end
do -- a resize while the title shows (a window drag, a rotation)
 local t=boot({seed=2});local label=t.label();t.step(30)
 local scale=label:FindFirstChildOfClass('UIScale')
 t.group.AbsoluteSize=V2(390,844);t.step(60)
 local L=T.Layout(390,844)
 check(label.Size.X.Offset==L.TipWidth and label.Size.Y.Offset==L.TipHeight and label.Position.X.Offset==195,'a resize to 390x844: the line box follows')
 local still=true
 for _=1,480 do t.step(1,1/240);if label.Position.X.Offset~=195 or label.Position.Y.Offset~=L.TipY then still=false end end
 check(still,'... and it stays on the new centre (195, '..L.TipY..') while it pulses: it is never moved')
 check(label:FindFirstChildOfClass('UITextSizeConstraint').MaxTextSize==L.TipSize,'... with the new text size cap '..L.TipSize)
 t.close()
end

-- ======================================================================================================================
-- H. no input; fades out with the title
-- ======================================================================================================================
print('-- H. input')
local function activeNames(t)
 local names={}
 for _,root in ipairs({t.screen,t.backdrop})do for _,o in ipairs(root:GetDescendants())do if o.Active==true or o.Interactable==true or o.Selectable==true then names[#names+1]=o.Name end end end
 table.sort(names);return table.concat(names,',')
end
local function hideTips(on)if on then TipsModule.Parent=nil else TipsModule.Parent=RS end end
do
 local t=boot({seed=1});local label=t.label();t.step(5)
 check(label.ClassName=='TextLabel'and label.Parent==t.group and t.group.ClassName=='CanvasGroup','the tip line is a TextLabel inside the title\'s CanvasGroup (it fades with it)')
 check(label.Active==false and label.Interactable==false and label.Selectable==false,'the label takes no input: not Active, not Interactable, not Selectable')
 check(#label.InputBegan._c==0 and #label.InputEnded._c==0 and #label.MouseEnter._c==0 and #label.MouseLeave._c==0 and #label.InputChanged._c==0,'the label has no input listener')
 local guiChildren=0;for _,o in ipairs(label:GetDescendants())do if o:IsA('GuiObject')then guiChildren+=1 end end
 check(guiChildren==0,'the label has no GuiObject inside it that could take a click')
 check(label.TextColor3.R>.99 and label.TextColor3.G>.99 and label.TextColor3.B>.9,'white text')
 local titleStroke;for _,o in ipairs(t.screen:GetDescendants())do if o.Name=='StealA'then titleStroke=o:FindFirstChildOfClass('UIStroke')end end
 local stroke=label:FindFirstChildOfClass('UIStroke')
 check(titleStroke and stroke and stroke.Color.R==titleStroke.Color.R and stroke.Color.G==titleStroke.Color.G and stroke.Color.B==titleStroke.Color.B,'the outline is the title\'s dark stroke colour')
 check(label.Font==R.Enum.Font.FredokaOne and label.Name=='TipLine','the title\'s font (Fredoka One)')
 check(label.Text:find('<font color="#C8D9E8">tip:</font> ',1,true)==1,'the line starts with the "tip:" prefix')
 local withTips=activeNames(t)
 t.close()
 hideTips(true);local t0=boot({seed=1});t0.step(5);local without=activeNames(t0);check(t0.label()==nil,'(without the list there is no line)');t0.close();hideTips(false)
 check(withTips==without,'the only active / selectable things are what they were without tips ('..withTips..')')
 for _,go in ipairs({'click','enter','A'})do
  local tt=boot({seed=1});tt.step(90)
  if go=='click'then tt.button.Activated:Fire()
  elseif go=='enter'then W.actions.StealAPackTitle104Start('StealAPackTitle104Start',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.Return})
  else W.actions.StealAPackTitle104Start('StealAPackTitle104Start',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonA})end
  local lbl=tt.label()
  local before=tt.group.GroupTransparency
  tt.step(24) -- .4 s: the title has faded out (.32 s)
  check(tt.group.GroupTransparency>=.999 and before<.5,'with the tip line, '..go..' starts the game: the title (and the line in it) fades out (GroupTransparency '..('%.2f'):format(tt.group.GroupTransparency)..')')
  check(lbl~=nil and lbl.Parent==tt.group,'... the line fades out inside the title, it is not removed early')
  tt.step(120)
  check(not tt.alive()and tt.screen.Parent==nil and lbl.Parent==nil,'... and the title, with the line, is gone afterwards')
  tt.close()
 end
end

-- ======================================================================================================================
-- I. no allocation per frame; stops when the title closes
-- ======================================================================================================================
print('-- I. nothing allocated per frame')
do
 local src=W.B.TitleScreen104
 local step=src:match('local function stepTip%(dt,reduced%).-\n  end\n')
 check(step~=nil,'stepTip is in the title')
 if step then
  local code=step:gsub('%-%-[^\n]*','')
  local bad={}
  for _,pat in ipairs({'{','function%s*%(','Instance%.new','UDim2','Position','UDim%.','Vector2','Vector3','Color3','CFrame','Random%.','table%.','string%.','tostring','%.%.','format','task%.','Line%(','Rich%(','Plain%(','require','GetService','FindFirst','Clone','Tween'})do
   if code:find(pat)then bad[#bad+1]=pat end
  end
  check(#bad==0,'the tip step (run every frame) builds no table, closure, string, UDim2, Vector or Instance: '..table.concat(bad,' '))
  check(code:find('tips.Order(tipRandom,tipOrder,tipOrder[#tipOrder])',1,true)~=nil,'the only call that builds anything runs once per 24 tips: Order() refills the same table')
 end
 for _,reduced in ipairs({false,true})do
  local function run(withTips)
   if not withTips then hideTips(true)end
   local t=boot({seed=6,reduced=reduced});t.step(120)
   local a=snapshot();t.step(60*25) -- 25 s: the text changes twice, the fade and the pulse run
   local b=snapshot();local alive=t.alive()
   local label=t.label();t.close()
   if not withTips then hideTips(false)end
   return diff(a,b),alive,label
  end
  local dWith,aliveWith,labelWith=run(true);local dWithout,aliveWithout,labelWithout=run(false)
  check(aliveWith and aliveWithout and labelWith~=nil and labelWithout==nil,(reduced and 'Reduced Motion: 'or'')..'both titles ran 25 s (one with the tip line, one without)')
  check(sameDiff(dWith,dWithout),(reduced and 'Reduced Motion: 'or'')..'the tip line builds nothing per frame: the same constructor calls with and without it ['..show(dWith)..'] vs ['..show(dWithout)..']')
  check((dWith._created or 0)==0,(reduced and 'Reduced Motion: 'or'')..'no Instance created in 1500 frames ('..(dWith._created or 0)..')')
 end
 -- the pulse stops when the title closes: unbound, the line is gone, nothing runs on
 local t=boot({seed=2});local label=t.label();local scale=label:FindFirstChildOfClass('UIScale');t.step(100)
 check(binds[BINDING]~=nil,'(the title is up: its frame step is bound)')
 t.close()
 check(binds[BINDING]==nil and label.Parent==nil and t.screen.Parent==nil,'closing the title unbinds the frame step and removes the line')
 local before=scale.Scale;local posBefore=label.Position
 for _=1,30 do R.advance(1/60)end
 check(scale.Scale==before and label.Position==posBefore,'... and the pulse does not run any more')
 -- leaving: the line stops where it is while the title fades out (no pulse after the click)
 local t2=boot({seed=2});local l2=t2.label();local s2=l2:FindFirstChildOfClass('UIScale');t2.step(100)
 t2.button.Activated:Fire();t2.step(1)
 local sc,pos,tx=s2.Scale,l2.Position,l2.TextTransparency;t2.step(10)
 check(s2.Scale==sc and l2.Position==pos and l2.TextTransparency==tx,'after the click the line stops pulsing while the title fades out')
 t2.step(120);t2.close()
 -- a Heartbeat / RenderStepped / task of its own? none: the title has one bound step and no tip-line connection survives
 local t3=boot({seed=2});t3.step(10)
 local conns=0;local live=0
 for _,sig in pairs(t3.group._propSignals)do for _,c in ipairs(sig._c)do conns+=1;if c.Connected then live+=1 end end end
 t3.close()
 local left=0;for _,sig in pairs(t3.group._propSignals)do for _,c in ipairs(sig._c)do if c.Connected then left+=1 end end end
 check(live>=1 and left==0,'the title\'s listeners (including the resize one the tip line uses) are all disconnected when it closes ('..live..' live before, '..left..' after)')
end

-- ======================================================================================================================
-- J. a missing / broken / late list never blocks the title
-- ======================================================================================================================
print('-- J. a missing, broken or late list')
local function titleWorks(t)
 t.step(60)
 local ok=t.alive()and t.button~=nil
 t.button.Activated:Fire();t.step(150)
 return ok and not t.alive()
end
do
 hideTips(true)
 local t=boot({seed=1});check(t.label()==nil,'no list in ReplicatedStorage: no tip line');local nW=warned('[Title]')
 check(titleWorks(t),'... and the title still starts the game');check(warned('[Title]')==nW,'... without an error');t.close()
 hideTips(false)
 local RealTips=Tips
 local function bad(name,list,expectWarn)
  W.stub('TitleTips156',list)
  local n0=warned('[Title tips]');local t=boot({seed=1})
  check(t.label()==nil,name..': no tip line left in the title')
  check(titleWorks(t),name..': the title still starts the game')
  if expectWarn then check(warned('[Title tips]')==n0+1,name..': one warning') end
  t.close()
 end
 local function with(patch)local copy=table.clone(RealTips);for k,v in pairs(patch)do copy[k]=v end;return copy end
 bad('an empty list',with({Tips={}}),false)
 bad('Tips is not a table',with({Tips=5}),false)
 bad('no Interval',with({Interval=false}),true)
 bad('Interval is text',with({Interval='ten'}),true)
 bad('a Fade as long as the interval',with({Fade=6}),true)
 bad('a zero pulse period',with({PulsePeriod=0}),true)
 bad('a NaN pulse period',with({PulsePeriod=0/0}),true)
 bad('a pulse amount that is text',with({PulseAmount='big'}),true)
 bad('a pulse period that is a table',with({PulsePeriod={}}),true)
 bad('Line gives a number',with({Line=function()return 5 end}),true)
 bad('Order is missing',with({Order=false}),true)
 W.stub('TitleTips156',RealTips)
 -- a require that fails (the module cannot be fetched): WaitForChild raises
 local origWait=R.Inst.WaitForChild
 R.Inst.WaitForChild=function(self,n,timeout)if n=='TitleTips156'then error('Infinite yield possible on TitleTips156')end;return origWait(self,n,timeout)end
 local t=boot({seed=1});check(t.label()==nil and titleWorks(t),'the module cannot be fetched (WaitForChild raises): no line, the title works');t.close()
 -- a list that arrives late (the title is already up): the line appears then and fades in
 local held
 R.Inst.WaitForChild=function(self,n,timeout)if n=='TitleTips156'then held=coroutine.running();coroutine.yield()end;return origWait(self,n,timeout)end
 local t2=boot({seed=9});t2.step(60*3)
 check(held~=nil and t2.label()==nil,'a list that has not arrived yet: the title runs without a line')
 coroutine.resume(held);held=nil
 local label=t2.label()
 check(label~=nil and shownIndex(label)==Tips.Order(makeRng(9))[1],'the list arrives 3 s late: the line appears with the first tip of its shuffle')
 check(label.TextTransparency==1 and label:FindFirstChildOfClass('UIStroke').Transparency==1,'... starts invisible (no flash before its first frame)')
 t2.step(1,1/120)
 t2.step(24,1/120);check(near(1-label.TextTransparency,(25/120)/.4,.02),'... and fades in over 0.4 s from its arrival ('..('%.2f'):format(1-label.TextTransparency)..')')
 t2.step(60);check(label:FindFirstChildOfClass('UIScale').Scale~=1,'... and pulses')
 t2.close()
 -- the title closes before the list arrives: nothing is built, nothing errors
 local t3=boot({seed=9});t3.step(30);check(held~=nil,'(waiting for the list)')
 local created=#R.created;local nW=#warnings
 t3.close();local created2=#R.created
 coroutine.resume(held);held=nil
 check(#R.created==created2 and #warnings==nW,'the list arrives after the title closed: no label is built, no warning')
 R.Inst.WaitForChild=origWait
 -- and a normal start again
 local t4=boot({seed=1});check(t4.label()~=nil,'(the list is back: the line is back)');t4.close()
end
check(warned('[Title]')==0,'no "[Title]" warning in the whole run: the frame step never errored ('..warned('[Title]')..')')

print(('R157 title tips: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
