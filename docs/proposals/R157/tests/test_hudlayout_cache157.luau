--!nocheck
-- R157 review fix: the layout cache. HudLayout.Read memoizes its search (wheelArc, barsClear -> PityBars155.Place): the last few answers are kept, keyed by EVERY input
-- the layout depends on (the HUD area w x h clamped to 240 x 150, the touch flag, a phone's thumb controls - Joystick / Jump x, y, w, h -, the NameRows tunables and what barsClear
-- searches with), shared and frozen. On the Roblox mock (/opt/luau/luau) with the REAL HudLayout / PityBars155 / WorldStatusHud / RarePullCard of this checkout:
--  1. same     - on the R157 HUD test's screens (the R155 36, the wheel sweep's 20, the fit check's 19) + 640 x 360, 1920 x 300, 1280 x 320, 640 x 640, each as a computer, as a phone
--                with its thumb controls and as a phone without: the cached Read is exactly (every number, the sign of a zero too) what a fresh, uncached HudLayout computes, and the
--                R157 layout as it was before the cache (a fingerprint per screen, taken from that code); the same again in the reverse and a shuffled order (the ring evicting)
--  2. served   - the same screen again is the same table, runs no search (PityBars155.Place is not called), costs a few microseconds and allocates nothing; a new screen searches once
--  3. keyed    - a different w, h, touch flag, any of the eight control numbers, a missing rect, a changed NameRows tunable or a swapped PityBars155.Place gives a fresh, correct answer; what
--                the layout cannot see (a computer's controls, a size under the 240 x 150 floor) does not make a new one; the safe-area inset moves the thumb controls and so the key
--  4. bounded  - a small ring (a few layouts), an evicted screen is searched again and still exact
--  5. frozen   - the answer is deeply frozen (a write raises and changes nothing for the next caller); the caller's own control rects are never frozen, kept or aliased
--  6. callers  - the real WorldStatusHud ticking for 10 s on a 640 x 360 computer, and RarePullCard.SkipBoxes asked again and again, run the search once
-- "R157 HUD layout cache checks N, fails 0". `luau test_hudlayout_cache157.luau -a golden` prints the fingerprints (run it on the code to compare against).
-- R158 (on purpose): a computer's layout is the 1920 x 1080 arrangement scaled (HudLayout.PcScales): its ":pc" fingerprints are the R158 layout (the touch ones, ":touch" and ":bare", are still
-- R157's byte for byte); it no longer searches the balances' spot with PityBars155.Place (barsClear is gone), so the key has 16 slots (the PityBars155 / its Place / HudBoxes slots are gone)
-- and a swapped Place changes nothing; a layout computation is counted through HudLayout.NameRows, which every layout asks once (the details rule), next to the bars' Place calls.
local W=require('./world');local R=W.R
local V2=R.Vector2.new
local checks,fails=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end;return c end
local fmt=string.format
local MODE=...
local Hud=W.module('HudLayout');local B=W.module('PityBars155')
-- the screen sets (as test_hud157.luau) -----------------------------------------------------------------------------------------------------------------------------------
local R155={ -- R155's 36 screens (test_pity_bars155.luau)
 {1920,1080,false,'PC 1080p'},{2560,1440,false,'PC 1440p'},{1366,768,false,'laptop'},{1280,720,false,'PC 720p'},{1024,768,false,'small window'},{800,600,false,'tiny window'},{1600,900,false,'PC 900p'},
 {844,390,true,'iPhone 14 landscape'},{932,430,true,'iPhone Pro Max landscape'},{667,375,true,'iPhone 8 landscape'},{568,320,true,'iPhone SE landscape'},{740,360,true,'Android landscape'},{800,360,true,'Android wide'},{896,414,true,'iPhone 11 landscape'},
 {390,844,true,'iPhone 14 portrait'},{375,667,true,'iPhone 8 portrait'},{360,640,true,'Android portrait'},{414,896,true,'iPhone 11 portrait'},{320,568,true,'iPhone SE portrait'},{360,800,true,'Android tall'},
 {1024,768,true,'iPad landscape'},{768,1024,true,'iPad portrait'},{1180,820,true,'iPad Air landscape'},{820,1180,true,'iPad Air portrait'},{1366,1024,true,'iPad Pro landscape'},
 {1280,800,true,'Android tablet'},{800,1280,true,'Android tablet portrait'},{1920,1080,true,'touch PC'},{1440,900,false,'MacBook'},{1280,1024,false,'5:4 monitor'},
 {1280,540,false,'short PC window'},{960,480,false,'narrow short window'},{700,400,false,'tiny landscape window'},{812,375,true,'iPhone X landscape'},{430,932,true,'iPhone Pro Max portrait'},{360,740,true,'Android portrait 740'},
}
local SWEEP={ -- the menu wheel preview's 20 (menu_wheel_daily.md)
 {1920,1080,false},{1366,768,false},{1280,720,false},{1024,768,false},{800,600,false},{640,360,false},{932,430,true},{844,390,true},{740,360,true},{667,375,true},
 {750,311,true},{568,320,true},{640,280,true},{600,250,true},{560,220,true},{430,932,true},{390,844,true},{375,667,true},{360,640,true},{320,568,true}}
local FIT19={ -- the reveal fixes preview's fit check (check_fit156.luau)
 {1920,1080,false},{1366,768,false},{1280,720,false},{2560,1440,false},{1891,733,false},{1280,400,false},{800,600,false},{530,593,false},{420,420,false},
 {844,390,true},{932,430,true},{667,375,true},{568,320,true},{390,844,true},{375,667,true},{360,640,true},{414,896,true},{768,1024,true},{1024,768,true}}
local ALL,seen={},{}
for _,set in ipairs({R155,SWEEP,FIT19,{{844,390,true},{390,844,true},{1920,1080,false}}})do for _,s in ipairs(set)do
 local key=s[1]..'x'..s[2]..(s[3]and't'or'')
 if not seen[key]then seen[key]=true;ALL[#ALL+1]={s[1],s[2],s[3],s[4]or(s[3]and'touch 'or'PC ')..s[1]..'x'..s[2]}end
end end
-- a card's ScreenGui in a PlayerGui with Roblox's TouchGui holding the thumb controls c (or none): HudLayout.Controls reads them from it, as in the game
local function cardGui(w,h,c)
 local pg=R.new('Folder');local g=R.new('ScreenGui');g.AbsoluteSize=V2(w,h);g.Parent=pg
 if c then
  local t=R.new('ScreenGui');t.Name='TouchGui';t.Enabled=true;t.Parent=pg
  for key,name in pairs({Joystick='ThumbstickFrame',Jump='JumpButton'})do
   local f=R.new('Frame');f.Name=name;f.Parent=t;f.AbsolutePosition=V2(c[key].X,c[key].Y);f.AbsoluteSize=V2(c[key].W,c[key].H)
  end
 end
 return g
end
local function controls(w,h) -- the phone's thumb controls the way Roblox puts them (as R155's tests do)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
-- the cases: every screen as a computer, as a phone with its thumb controls and as a phone without
local EXTRA={{640,360,false},{1920,300,false},{1280,320,false},{640,640,false}}
local SIZES,seenSize={},{}
for _,set in ipairs({ALL,EXTRA})do for _,s in ipairs(set)do
 local key=s[1]..'x'..s[2]
 if not seenSize[key]then seenSize[key]=true;SIZES[#SIZES+1]={s[1],s[2]}end
end end
local CASES={}
for _,s in ipairs(SIZES)do
 local w,h=s[1],s[2]
 CASES[#CASES+1]={w=w,h=h,touch=false,ctl=nil,tag=w..'x'..h..':pc'}
 CASES[#CASES+1]={w=w,h=h,touch=true,ctl=controls(w,h),tag=w..'x'..h..':touch'}
 CASES[#CASES+1]={w=w,h=h,touch=true,ctl=nil,tag=w..'x'..h..':bare'}
end
-- a canonical text of a value (sorted keys, 17 digits: the sign of a zero shows) and its fingerprint (FNV-1a, 32 bit)
local function num(v)return fmt('%.17g',v)end
local function ser(v)
 local t=type(v)
 if t=='number'then return num(v)end
 if t~='table'then return tostring(v)end
 local keys={}
 for k in pairs(v)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)local ta,tb=type(a),type(b);if ta~=tb then return ta<tb end;return a<b end)
 local out={}
 for _,k in ipairs(keys)do out[#out+1]=(type(k)=='number'and'['..num(k)..']'or tostring(k))..'='..ser(v[k])end
 return'{'..table.concat(out,',')..'}'
end
local function print32(s)
 local h=2166136261
 for i=1,#s do h=bit32.bxor(h,s:byte(i));h=(bit32.lshift(h,24)+h*403)%4294967296 end
 return fmt('%08x',h)
end
local RSD=W.RS
local function fresh()return W.load('HudLayout',RSD:FindFirstChild('HudLayout'))end -- a new copy of the module: its first Read is the uncached computation
local function view(c)return V2(c.w,c.h)end
if MODE=='golden'then
 for _,c in ipairs(CASES)do print(fmt('GOLDEN\t%s\t%s',c.tag,print32(ser(Hud.Read(view(c),c.touch,c.ctl)))))end
 return
end
-- the R157 layout before the cache (HudLayout as of the R157 HUD merge): a fingerprint of every case, taken from that code
local GOLDEN={
 ['1920x1080:pc']='f5a08a25',['1920x1080:touch']='1b28a66d',['1920x1080:bare']='1b28a66d',['2560x1440:pc']='407c307a',
 ['2560x1440:touch']='17c580c1',['2560x1440:bare']='17c580c1',['1366x768:pc']='9a1054d6',['1366x768:touch']='85d06d46',
 ['1366x768:bare']='85d06d46',['1280x720:pc']='d886c604',['1280x720:touch']='9bd86eed',['1280x720:bare']='9bd86eed',
 ['1024x768:pc']='4dab5fe9',['1024x768:touch']='56eae9f6',['1024x768:bare']='56eae9f6',['800x600:pc']='9bfac641',
 ['800x600:touch']='969501fa',['800x600:bare']='969501fa',['1600x900:pc']='bf63ea78',['1600x900:touch']='03e2b759',
 ['1600x900:bare']='03e2b759',['844x390:pc']='6ca5b515',['844x390:touch']='156d0ad7',['844x390:bare']='156d0ad7',
 ['932x430:pc']='594416a4',['932x430:touch']='fe30af20',['932x430:bare']='fe30af20',['667x375:pc']='f4d26b65',
 ['667x375:touch']='382563db',['667x375:bare']='382563db',['568x320:pc']='4ba69472',['568x320:touch']='12d78f1b',
 ['568x320:bare']='12d78f1b',['740x360:pc']='e181d459',['740x360:touch']='17d9b5d5',['740x360:bare']='17d9b5d5',
 ['800x360:pc']='8bf058d0',['800x360:touch']='b56b644e',['800x360:bare']='b56b644e',['896x414:pc']='f3e1975b',
 ['896x414:touch']='dbe439ec',['896x414:bare']='dbe439ec',['390x844:pc']='e6e8b00e',['390x844:touch']='8a978597',
 ['390x844:bare']='8a978597',['375x667:pc']='deedf3ed',['375x667:touch']='2ffde8e8',['375x667:bare']='2ffde8e8',
 ['360x640:pc']='58c49399',['360x640:touch']='de08c28f',['360x640:bare']='de08c28f',['414x896:pc']='de2240d4',
 ['414x896:touch']='922d2702',['414x896:bare']='922d2702',['320x568:pc']='9d13053d',['320x568:touch']='3bd78c0c',
 ['320x568:bare']='3bd78c0c',['360x800:pc']='dd58ff2e',['360x800:touch']='261b103d',['360x800:bare']='261b103d',
 ['768x1024:pc']='c0c6960e',['768x1024:touch']='2d6a8a05',['768x1024:bare']='a380ca70',['1180x820:pc']='d0ca95d7',
 ['1180x820:touch']='2708cab8',['1180x820:bare']='2708cab8',['820x1180:pc']='3ccb9b03',['820x1180:touch']='a5c05dde',
 ['820x1180:bare']='23287f91',['1366x1024:pc']='76b27b65',['1366x1024:touch']='7bad900a',['1366x1024:bare']='7bad900a',
 ['1280x800:pc']='5a53f607',['1280x800:touch']='91b7be57',['1280x800:bare']='91b7be57',['800x1280:pc']='967d6bc4',
 ['800x1280:touch']='aa3dd0f1',['800x1280:bare']='472c6010',['1440x900:pc']='e299b334',['1440x900:touch']='337f2edb',
 ['1440x900:bare']='337f2edb',['1280x1024:pc']='38bfc4ed',['1280x1024:touch']='5dfedb1c',['1280x1024:bare']='5dfedb1c',
 ['1280x540:pc']='a4ff945d',['1280x540:touch']='af1cee75',['1280x540:bare']='af1cee75',['960x480:pc']='502f05ad',
 ['960x480:touch']='37a39c0d',['960x480:bare']='37a39c0d',['700x400:pc']='d8ac0595',['700x400:touch']='0ea2047e',
 ['700x400:bare']='0ea2047e',['812x375:pc']='b6124c05',['812x375:touch']='bcd36936',['812x375:bare']='bcd36936',
 ['430x932:pc']='07de0ff8',['430x932:touch']='bf532103',['430x932:bare']='bf532103',['360x740:pc']='879f7414',
 ['360x740:touch']='4a7ac84d',['360x740:bare']='4a7ac84d',['640x360:pc']='931b9fa3',['640x360:touch']='574fb618',
 ['640x360:bare']='574fb618',['750x311:pc']='dfa7a2dc',['750x311:touch']='3ebda264',['750x311:bare']='3ebda264',
 ['640x280:pc']='e0095316',['640x280:touch']='00d782b4',['640x280:bare']='00d782b4',['600x250:pc']='b1ca29f0',
 ['600x250:touch']='c3ff7013',['600x250:bare']='c3ff7013',['560x220:pc']='36298744',['560x220:touch']='ea7101cb',
 ['560x220:bare']='ea7101cb',['1891x733:pc']='9aa8b58c',['1891x733:touch']='4826988e',['1891x733:bare']='4826988e',
 ['1280x400:pc']='cd131ad8',['1280x400:touch']='12cffdc7',['1280x400:bare']='12cffdc7',['530x593:pc']='aac279d8',
 ['530x593:touch']='87f2e1a5',['530x593:bare']='68187e60',['420x420:pc']='c4d07257',['420x420:touch']='639cf5fc',
 ['420x420:bare']='639cf5fc',['1920x300:pc']='334955dd',['1920x300:touch']='d475c272',['1920x300:bare']='d475c272',
 ['1280x320:pc']='1c178924',['1280x320:touch']='dc1e6aa3',['1280x320:bare']='dc1e6aa3',['640x640:pc']='3a7f2652',
 ['640x640:touch']='c6e09393',['640x640:bare']='d504c09b',
}
local slow={} -- (the search is slow on the short PC windows; the sweep says how slow)

-- 1. the same layout as the uncached one ------------------------------------------------------------------------------------------------------------------------------------
do
 local bad,badGolden,n=0,0,0
 local firstTables={}
 local t0=os.clock()
 for i,c in ipairs(CASES)do
  local t1=os.clock()
  local m=Hud.Read(view(c),c.touch,c.ctl)
  local took=os.clock()-t1
  if took>.005 then slow[#slow+1]=fmt('%s %.0f ms',c.tag,took*1000)end
  local text=ser(m);local ref=ser(fresh().Read(view(c),c.touch,c.ctl))
  if text~=ref then bad+=1;if bad<=5 then print('FAIL: '..c.tag..': the cached Read differs from a fresh computation')end end
  if print32(text)~=GOLDEN[c.tag]then badGolden+=1;if badGolden<=5 then print('FAIL: '..c.tag..': the layout differs from the R157 layout before the cache ('..print32(text)..' want '..tostring(GOLDEN[c.tag])..')')end end
  local again=Hud.Read(view(c),c.touch,c.ctl)
  if not rawequal(again,m)then bad+=1;print('FAIL: '..c.tag..': the same screen again is not the same table')end
  firstTables[i]=text;n+=1
 end
 check(bad==0,'the cached Read is exactly the fresh computation on all '..n..' cases ('..bad..' differ)')
 check(badGolden==0,'every case matches the R157 layout from before the cache ('..badGolden..' differ of '..n..')')
 check(n==#CASES and n==3*#SIZES and #SIZES>=40,#CASES..' cases: '..#SIZES..' screens, each as a computer, a phone with its controls and a phone without')
 -- reverse and shuffled order: the ring evicts all the time, every answer is still the same
 local order={};for i=1,#CASES do order[i]=i end
 local seed=12345
 local function shuffle()for i=#order,2,-1 do seed=(seed*1103515245+12345)%2147483648;local j=seed%i+1;order[i],order[j]=order[j],order[i]end end
 local badOrder=0
 for pass=1,3 do
  if pass==1 then for i=1,#CASES do order[i]=#CASES+1-i end else shuffle()end
  for _,i in ipairs(order)do
   local c=CASES[i];local text=ser(Hud.Read(view(c),c.touch,c.ctl))
   if text~=firstTables[i]then badOrder+=1;if badOrder<=5 then print('FAIL: '..c.tag..': a different answer in pass '..pass)end end
  end
 end
 check(badOrder==0,'the same answers again in reverse and two shuffled orders ('..badOrder..' differ)')
 print(fmt('(%d cases in %.1f s; slow searches: %s)',#CASES,os.clock()-t0,#slow>0 and table.concat(slow,', ')or'none'))
end

-- 2. served from the cache ------------------------------------------------------------------------------------------------------------------------------------------------
local placeCalls=0;local realPlace=B.Place
B.Place=function(...)placeCalls+=1;return realPlace(...)end -- (a counting Place: the bars' own placement)
-- (R158: every layout computation - the computer's and the phones' - asks L.NameRows once, for the details rule: counted too; a cached Read asks nothing)
local realRows=Hud.NameRows
Hud.NameRows=function(...)placeCalls+=1;return realRows(...)end
local costs={}
do
 for _,s in ipairs({{640,360},{1920,300},{1280,320},{640,640},{1920,1080},{1280,720}})do
  local v=V2(s[1],s[2]);local tag=s[1]..'x'..s[2]
  placeCalls=0
  local t0=os.clock();local m=Hud.Read(v,false,nil);local first=os.clock()-t0;local searches=placeCalls
  placeCalls=0
  local t1=os.clock()
  for _=1,5 do Hud.Read(v,false,nil)end
  local n=(os.clock()-t1)/5>math.max(first/10,2e-3)and 5 or 2000 -- (a Read that searches every time is not given minutes to prove it)
  t1=os.clock()
  for _=1,n do Hud.Read(v,false,nil)end
  local per=(os.clock()-t1)/n
  check(placeCalls==0,tag..': '..n..' more Reads run no search ('..placeCalls..' layout computations / PityBars155.Place calls)')
  check(rawequal(Hud.Read(v,false,nil),m),tag..': the same table again')
  check(per<first/50 or per<2e-5,fmt('%s: a repeated Read costs %.4f ms, the first %.3f ms',tag,per*1000,first*1000))
  check(per<5e-4,fmt('%s: a repeated Read is under 0.5 ms (%.4f ms)',tag,per*1000))
  costs[#costs+1]=fmt('%s first %.3f ms (%d Place calls), repeated %.4f ms',tag,first*1000,searches,per*1000)
  if s[1]==640 and s[2]==360 then check(searches>=1,'640x360: a new size computes its layout (it did '..searches..' times)')end
 end
 local c=controls(844,390);local v=V2(844,390)
 local m=Hud.Read(v,true,c);local per
 do local t1=os.clock();for _=1,2000 do Hud.Read(v,true,c)end;per=(os.clock()-t1)/2000 end
 check(rawequal(Hud.Read(v,true,c),m)and per<5e-4,fmt('844x390 phone: the same table again, %.4f ms a Read',per*1000))
 -- nothing allocated per Read (right after a full collection the GC will not run again for megabytes: 10000 Reads that made even a 40 byte table each would show as 400 KB)
 collectgarbage('collect')
 local pcView,phoneView,phoneControls=V2(1280,720),V2(390,844),controls(390,844)
 Hud.Read(pcView,false,nil);Hud.Read(phoneView,true,phoneControls)
 local before=collectgarbage('count')
 for _=1,5000 do Hud.Read(pcView,false,nil);Hud.Read(phoneView,true,phoneControls)end
 local grew=collectgarbage('count')-before
 check(grew<2,fmt('10000 Reads allocate nothing (heap grew %.2f KB)',grew))
 for _,line in ipairs(costs)do print('COST '..line)end
 print(fmt('COST 844x390 phone repeated %.4f ms; 10000 repeated Reads grew the heap by %.2f KB',per*1000,grew))
end

-- 3. every input is in the key ------------------------------------------------------------------------------------------------------------------------------------------------
local function pair(v,touch,ctl,msg) -- the cached Read and a fresh computation agree; returns the cached table
 local m=Hud.Read(v,touch,ctl);local ref=fresh().Read(v,touch,ctl)
 check(ser(m)==ser(ref),msg..': the cached answer is exactly the fresh one')
 return m
end
local function copyControls(c)return c and{Joystick=c.Joystick and{X=c.Joystick.X,Y=c.Joystick.Y,W=c.Joystick.W,H=c.Joystick.H}or nil,Jump=c.Jump and{X=c.Jump.X,Y=c.Jump.Y,W=c.Jump.W,H=c.Jump.H}or nil}or nil end
do
 -- the screen
 local base=pair(V2(1280,720),false,nil,'1280x720')
 check(not rawequal(pair(V2(1281,720),false,nil,'1281x720'),base),'a different width is a new answer')
 check(not rawequal(pair(V2(1280,721),false,nil,'1280x721'),base),'a different height is a new answer')
 check(rawequal(Hud.Read(V2(1280,720),false,nil),base),'back to the first size: its answer')
 check(not rawequal(pair(V2(1280,720),true,nil,'1280x720 touch'),base),'the touch flag is in the key (a phone is not a computer)')
 check(ser(Hud.Read(V2(1280,720),true,nil))~=ser(base),'a phone layout is not the computer one')
 check(rawequal(Hud.Read(V2(100,100),false,nil),Hud.Read(V2(240,150),false,nil))and rawequal(Hud.Read(V2(50,900),false,nil),Hud.Read(V2(240,900),false,nil)),'under the 240 x 150 floor the key is the floor')
 check(rawequal(Hud.Read({X=1280,Y=720},false,nil),base),'a plain {X, Y} view is the same screen')
 check(rawequal(Hud.Read(V2(1280,720),false,controls(1280,720)),base),'a computer ignores the thumb controls (they are not in its key)')
 check(rawequal(Hud.Read(V2(1280,720),nil,nil),base)and rawequal(Hud.Read(V2(1280,720),0>1,nil),base),'touch nil / false is the same computer')
 -- the thumb controls: every number of both rects, a phone in landscape (they are in the answer) and in portrait (they widen / lift the thumb zones)
 for _,s in ipairs({{844,390,20},{390,844,5}})do
  local w,h=s[1],s[2];local tag=w..'x'..h
  local c0=controls(w,h);local m0=pair(V2(w,h),true,c0,tag..' controls')
  local text0=ser(m0);local changed,total=0,0
  check(rawequal(Hud.Read(V2(w,h),true,copyControls(c0)),m0),tag..': equal controls (another table) are the same key')
  for _,name in ipairs({'Joystick','Jump'})do for _,field in ipairs({'X','Y','W','H'})do for _,delta in ipairs({-60,7,300})do
   local c=copyControls(c0);c[name][field]+=delta
   if c[name].W>0 and c[name].H>0 or delta>0 then
    local m=pair(V2(w,h),true,c,tag..' '..name..'.'..field..' '..delta)
    total+=1;if ser(m)~=text0 then changed+=1 end
   end
  end end end
  check(changed>=s[3],tag..': '..changed..' of '..total..' changed control numbers changed the answer (at least '..s[3]..'; each was exact)')
  local noStick=copyControls(c0);noStick.Joystick=nil;pair(V2(w,h),true,noStick,tag..' no joystick')
  local noJump=copyControls(c0);noJump.Jump=nil;pair(V2(w,h),true,noJump,tag..' no jump')
  pair(V2(w,h),true,{},tag..' empty controls')
  local flat=copyControls(c0);flat.Joystick.W=0;flat.Joystick.H=0;pair(V2(w,h),true,flat,tag..' a rect with no size')
  check(rawequal(Hud.Read(V2(w,h),true,nil),Hud.Read(V2(w,h),true,{})),tag..': no controls and an empty table are the same layout and key')
 end
 -- the sign of a zero is an input too (it shows in a landscape phone's m.Joystick)
 local zero=tonumber('0');local minus=-zero
 check(1/minus==-math.huge and 1/zero==math.huge,'(-0 and +0 are told apart)')
 local cz=controls(844,390);cz.Joystick.X=zero;local cm=controls(844,390);cm.Joystick.X=minus
 local mz=pair(V2(844,390),true,cz,'Joystick.X = +0');local mm=pair(V2(844,390),true,cm,'Joystick.X = -0')
 check(not rawequal(mz,mm)and ser(mz)~=ser(mm)and ser(mm):find('X=-0',1,true)~=nil,'-0 and +0 are different keys with different answers (as they were)')
 -- the safe-area inset moves the thumb controls (HudLayout.Controls subtracts the safe area's origin), and the ScreenGui's size is the view
 local oldInset=W.Gui.GetInsetArea;local oldTouch=W.UIS.TouchEnabled;W.UIS.TouchEnabled=true
 local c0=controls(844,390);local g=cardGui(844,390,c0)
 local function pipeline(ix,iy)
  W.Gui.GetInsetArea=function()return{Min=V2(ix,iy),Width=844,Height=390}end
  local ctl=Hud.Controls(g);local v=Hud.Viewport(g)
  local m=Hud.Read(v,true,ctl);local ref=fresh().Read(v,true,ctl)
  check(ser(m)==ser(ref),fmt('through Viewport / Controls with a safe-area inset of (%d, %d): exact',ix,iy))
  return m
 end
 local a=pipeline(0,0);local b=pipeline(44,0);local c=pipeline(0,36)
 check(not rawequal(a,b)and not rawequal(a,c)and not rawequal(b,c)and ser(a)~=ser(b)and ser(a)~=ser(c),'a side inset and a top inset each give a new answer')
 check(rawequal(pipeline(0,0),a)and rawequal(pipeline(44,0),b),'the same insets again: the same answers')
 g.AbsoluteSize=V2(844,354);local d=pipeline(0,0)
 check(not rawequal(d,a),'a shorter ScreenGui (a top bar inset in the size) is a new answer')
 W.Gui.GetInsetArea=oldInset;W.UIS.TouchEnabled=oldTouch
 -- the tunables L.NameRows reads (the details rule): one at a time, on the screens it matters on. Each screen is read with the default (cached), with the tunable changed (a new
 -- answer, exact against a fresh copy changed the same way), and with the default again (the first answer is still there)
 local tuneSizes={{640,360,false},{800,600,false},{1366,768,false},{1280,720,false},{1024,768,false},{700,400,false},{1920,1080,false},{360,740,true},{844,390,true},{390,844,true},{667,375,true},{320,568,true},{375,667,true},{932,430,true},{740,360,true},{750,311,true},{640,280,true}} -- (R158: + the landscape phones where the name rows' width decides whether they show: a computer's layout no longer depends on it)
 local tunables={
  {'NameBand = 300',function(L)L.NameBand=300 end},
  {'NameWidth = 1000',function(L)L.NameWidth=1000 end},
  {'NameClear = 200',function(L)L.NameClear=200 end},
  {'PityBarHeight = 60',function(L)L.PityBarHeight=function()return 60 end end},
  {'PityGap = 30',function(L)L.PityGap=function()return 30 end end},
 }
 local keep={NameBand=Hud.NameBand,NameWidth=Hud.NameWidth,NameClear=Hud.NameClear,PityBarHeight=Hud.PityBarHeight,PityGap=Hud.PityGap}
 local function putBack()for key,value in pairs(keep)do Hud[key]=value end end
 local differs={}
 for _,tn in ipairs(tunables)do
  local differ=0
  for _,s in ipairs(tuneSizes)do
   local v=V2(s[1],s[2]);local ctl=s[3]and controls(s[1],s[2])or nil;local tag=tn[1]..' at '..s[1]..'x'..s[2]
   local m1=Hud.Read(v,s[3],ctl)
   tn[2](Hud);local m2=Hud.Read(v,s[3],ctl);local other=fresh();tn[2](other);local ref=other.Read(v,s[3],ctl)
   putBack()
   check(ser(m2)==ser(ref),tag..': exact')
   if ser(m2)~=ser(m1)then differ+=1;check(not rawequal(m1,m2),tag..': a new answer')end
   check(rawequal(Hud.Read(v,s[3],ctl),m1),tag..': put back: the first answer again')
  end
  check(differ>=1,tn[1]..' can change a layout ('..differ..' of '..#tuneSizes..' screens did), so it is in the key')
  differs[#differs+1]=tn[1]:match('^%a+')..' '..differ
 end
 -- R158: a computer's layout no longer reads PityBars155 (barsClear is gone): a swapped Place changes no answer and is not in the key - the cached answer stays
 do
  local counting=B.Place
  local function never(w,h,m,dock)local r=counting(w,h,m,dock);local copy=table.clone(r);copy.Clear=false;return copy end
  local same=0
  for _,s in ipairs(SIZES)do
   local v=V2(s[1],s[2]);local m1=Hud.Read(v,false,nil);local plainText=ser(fresh().Read(v,false,nil))
   B.Place=never;local neverText=ser(fresh().Read(v,false,nil));local m2=Hud.Read(v,false,nil);B.Place=counting
   if plainText==neverText and rawequal(m1,m2)then same+=1 end
  end
  check(same==#SIZES,'a Place that never finds room changes no computer layout and no cached answer ('..same..' of '..#SIZES..' computer screens)')
 end
 print(fmt('(keyed inputs that really change layouts, of %d screens: %s)',#tuneSizes,table.concat(differs,', ')))
end

-- 4. a small ring ---------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local made,refs={},{}
 for i=1,24 do
  local v=V2(1500+i,800);made[i]=Hud.Read(v,false,nil);refs[i]=ser(fresh().Read(v,false,nil))
  check(ser(made[i])==refs[i],'distinct screen '..i..': exact')
 end
 local kept=0;for i=24,1,-1 do if rawequal(Hud.Read(V2(1500+i,800),false,nil),made[i])then kept+=1 end end
 check(kept>=4 and kept<=16,'24 distinct screens: the cache kept '..kept..' of them (a small ring, not all 24)')
 for i=1,24 do check(ser(Hud.Read(V2(1500+i,800),false,nil))==refs[i],'screen '..i..' read again (evicted or not): exact')end
 local last=Hud.Read(V2(1524,800),false,nil)
 check(rawequal(last,Hud.Read(V2(1524,800),false,nil)),'the newest screen is always kept')
end

-- 5. frozen, and no table of the caller's ---------------------------------------------------------------------------------------------------------------------------------------
do
 local function deepFrozen(t)
  if not table.isfrozen(t)then return false end
  for _,v in pairs(t)do if type(v)=='table'and not deepFrozen(v)then return false end end
  return true
 end
 for _,c in ipairs({{844,390,true,'landscape phone'},{390,844,true,'portrait phone'},{1280,720,false,'computer'},{640,360,false,'small computer'},{1920,1080,false,'big computer'}})do
  local ctl=c[3]and controls(c[1],c[2])or nil
  local m=Hud.Read(V2(c[1],c[2]),c[3],ctl)
  check(deepFrozen(m),c[4]..': the answer is frozen, every table in it')
  local text=ser(m)
  local writes={
   function()m.Slots=99 end,function()m.MenuOffsets[1].X=1 end,function()m.MenuOffsets[1]=nil end,function()table.insert(m.MenuOffsets,{X=0,Y=0})end,
   function()m.NewField=1 end,function()m.WalletX=nil end,function()table.sort(m.MenuOffsets,function(a,b)return a.Y>b.Y end)end,
   function()setmetatable(m,{})end,
  }
  if m.ThumbZones then writes[#writes+1]=function()m.ThumbZones[1].X=-1 end end
  if m.StatusBox then writes[#writes+1]=function()m.StatusBox.W=0 end end
  local raised=0;for _,f in ipairs(writes)do if not pcall(f)then raised+=1 end end
  check(raised==#writes,c[4]..': every write into the answer raises ('..raised..' of '..#writes..')')
  check(ser(m)==text and ser(Hud.Read(V2(c[1],c[2]),c[3],ctl))==text and rawequal(Hud.Read(V2(c[1],c[2]),c[3],ctl),m),c[4]..': and nothing changed for the next caller')
  -- a table made from it by the way callers use it is theirs to change (PityBars155.ButtonSpot's `lifted`, a copy)
  local lifted=setmetatable({HotbarBottom=m.HotbarBottom+5},{__index=m});lifted.HotbarBottom+=1
  local copy=table.clone(m);copy.Slots=1
  check(lifted.Slots==m.Slots and copy.Slots==1 and m.Slots~=1,c[4]..': a setmetatable({..},{__index=m}) proxy and a table.clone stay writable')
 end
 -- the caller's rects: never frozen, never kept (m.Joystick / m.Jump of a landscape phone were the caller's own tables)
 local c1=controls(844,390);c1.Joystick.X=33.25;c1.Jump.Y=c1.Jump.Y-3.5 -- (values nobody read before: a new key, so the Read below searches with these very tables)
 local stick,jump=c1.Joystick,c1.Jump
 local m=Hud.Read(V2(844,390),true,c1)
 check(not table.isfrozen(c1)and not table.isfrozen(stick)and not table.isfrozen(jump),'the caller\'s controls are not frozen')
 check(not rawequal(m.Joystick,stick)and not rawequal(m.Jump,jump),'the answer holds copies of the caller\'s rects')
 local keptX=m.Joystick.X;stick.X=keptX+77;jump.Y=jump.Y-33
 check(m.Joystick.X==keptX,'a caller changing its own rect afterwards does not change the answer')
 local m2=Hud.Read(V2(844,390),true,c1)
 check(not rawequal(m,m2)and ser(m2)==ser(fresh().Read(V2(844,390),true,c1))and m2.Joystick.X==keptX+77,'and a Read with the changed rects is a new, exact answer')
 -- a bad rect is still an error (as before)
 check(not pcall(Hud.Read,V2(844,390),true,{Joystick={X=1,Y=1,H=5},Jump=controls(844,390).Jump}),'a rect without a width still raises')
 check(pcall(Hud.Read,V2(844,390),true,{Joystick={X=1,Y=1,W=0,H=0},Jump=controls(844,390).Jump}),'a rect with no size is ignored')
end

-- 6. the callers ---------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 for i=1,12 do Hud.Read(V2(1600+i,900),false,nil)end -- (the ring now holds other screens: 640 x 360 is searched when the status HUD is built)
 local Players=W.service('Players');local player=R.new('Player');player.Name='P';player.UserId=3;player.Parent=Players;Players.LocalPlayer=player
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 W.UIS.TouchEnabled=false;W.workspace.CurrentCamera.ViewportSize=V2(640,360)
 local real=R.Instance.new;R.Instance.new=function(class,parent)local o=real(class,parent);if class=='ScreenGui'then o.AbsoluteSize=V2(640,360)end;return o end
 local reads=0;local rawRead=Hud.Read;Hud.Read=function(...)reads+=1;return rawRead(...)end
 placeCalls=0
 local status=W.module('WorldStatusHud').Create(pg,player)
 local built=placeCalls
 check(built>=1,'WorldStatusHud at 640x360 computes the layout once when it is built ('..built..' computations / Place calls)')
 placeCalls=0;reads=0
 W.frames(60*10)
 check(reads>=35,'WorldStatusHud read the layout '..reads..' times in 10 s (every .25 s)')
 check(placeCalls==0,'... and none of them searched ('..placeCalls..' Place calls)')
 print('COST WorldStatusHud at 640x360: '..reads..' layout reads in 10 s, '..placeCalls..' searches after the first')
 -- the refresh 3-2-1: a read every frame
 local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
 local endsAt=R.clock+3
 map:SetAttribute('BiomesRefreshing',true);map:SetAttribute('BiomeRefreshEndsAt',endsAt);map:SetAttribute('BiomeRefreshSeconds',3)
 placeCalls=0;reads=0
 W.frames(120)
 check(placeCalls==0,'the refresh countdown ('..reads..' reads in 2 s) searched '..placeCalls..' times')
 check(reads>=60,'the refresh countdown reads the layout every frame ('..reads..' reads in 120 frames)')
 print('COST WorldStatusHud refresh 3-2-1: '..reads..' layout reads in 120 frames, '..placeCalls..' searches')
 Hud.Read=rawRead;R.Instance.new=real;W.UIS.TouchEnabled=false
 pcall(function()status.Destroy()end)
 -- the reveal: SkipBoxes (a Read, HudBoxes and the bars' extent) asked again and again
 local Card=W.module('RarePullCard')
 Card.SkipBoxes(640,360,false,nil)
 placeCalls=0
 for _=1,50 do Card.SkipBoxes(640,360,false,nil)end
 check(placeCalls<=50,'RarePullCard.SkipBoxes x50 at 640x360: '..placeCalls..' Place calls (the bars\' own extent, one each; none from the layout)')
 local skipCalls=placeCalls
 local t0=os.clock();for _=1,50 do Card.SkipBoxes(640,360,false,nil)end;local per=(os.clock()-t0)/50
 print(fmt('COST RarePullCard.SkipBoxes at 640x360: %.3f ms a call, %d Place calls in 50 calls',per*1000,skipCalls))
 local c=controls(844,390);local g=cardGui(844,390,c)
 placeCalls=0;local okFit=pcall(function()return Card.FitBand(g,V2(844,390),3,true,false)end)
 local once=placeCalls
 placeCalls=0;for _=1,20 do pcall(function()return Card.FitBand(g,V2(844,390),3,true,false)end)end
 check(okFit,'RarePullCard.FitBand runs on the mock')
 check(placeCalls<=20*math.max(1,once),'RarePullCard.FitBand repeated: '..placeCalls..' Place calls in 20 calls (first '..once..')')
 print(fmt('COST RarePullCard.FitBand at 844x390: %d Place calls in 20 calls (the first: %d)',placeCalls,once))
end
B.Place=realPlace
print(fmt('R157 HUD layout cache checks %d, fails %d',checks,fails))
if fails>0 then error(fails..' checks failed')end
