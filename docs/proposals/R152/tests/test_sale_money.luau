--!nocheck
-- R152 (owner: "when u sell something u no longer need to hover over it to collect it, it just auto flies towards the players balance ... the same
-- for gems and every other feature that has the money animations"): the REAL SaleMoneyEffects (the one helper every cash / gem reward uses: market sales,
-- the gem converter, cash bundles, the Index, daily rewards and quests) on the Roblox mock, with the real GardenWallet / HudLayout for the counters' places.
--  1. no input: every share is claimed by itself, on arrival, once; the coins pop, rest .25-.5 s (staggered), then fly; nothing is left behind
--  2. the flight: smooth, eased, a slight arc, shrinking towards the end, into the RIGHT counter (cash -> cash row, gems -> gem row), a bump + click per coin
--  3. the claim happens on arrival (the coin is AT the counter when its claim goes out), never at the pop or the launch
--  4. reduced motion / FastMode / StudioPlantEffects=off: claimed at once with a minimal effect (no coins); switching it on mid-flight claims at once
--  5. many sales at once: the icon caps hold (13 per currency, 26 in all) and the overflow is claimed directly; 64 receipts x 13 shares all claimed
--  6. a failed claim (refused / error / nil / slow / hung) is retried until it lands, never claimed twice, never more than 8 at once; nothing left behind
--  7. the screen cannot hold money back: a stalled render loop (minimised window), a hidden / zero-size layer, a throwing burst, a destroyed UI
--  8. exploits: only ids and indices the server listed are ever sent, a claimed share is never sent again, a stale poll adds nothing
--  9. phone / desktop / landscape layouts: the coins end on the real wallet row's icon, inside the safe area; a window's own balance line (Anchor) can take over
-- 10. the hint is gone (no CollectCashHint, no MouseEnter / Activated / TextButton in the helper), and the callers' wiring (EconomyClient) is intact
-- Run from a folder holding roblox.luau, world.luau, fixtures.luau, sfx_env.luau and rs_bundle.luau (see run_sale_money.sh).
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local V2=R.Vector2.new
local RS=W.RS
F.packAssets(W)
W.env.bit32=bit32
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end -- (the mock's Vector2 has no multiply; the real wallet needs one)
local rec=E.recorder()
W.stub('LocalSfx',{Play=function()return true end,Preload=function()end,WhooshId='rbxassetid://9120768742'})
E.player('Tester')
local player,pg=E.Player,E.pg
local Gui=W.service('GuiService')
local function frames(n,dt)for _=1,n do W.frames(1,dt or 1/60)end end
local Effects=W.module('SaleMoneyEffects');local T=Effects.Timing;local Rules=W.module('SaleReceiptRules')
local host=R.Instance.new('ScreenGui');host.Name='CurrencyRewards';host.Parent=pg
local function receipt(id,count,amount,currency,claimed)return {Id=id,Count=count,Amount=amount,Claimed=claimed or 0,Currency=currency or'Cash'}end
-- two stand-in counters in different places, with bump counts
local function make(claim,opts)
 local log={cash=0,gems=0}
 local cashRow={Pulse=function()log.cash+=1 end,TargetPosition=function()return V2(220,44)end}
 local gemRow={Pulse=function()log.gems+=1 end,TargetPosition=function()return V2(420,44)end}
 cashRow.Gems=gemRow
 local fx=Effects.new(host,cashRow,claim,opts);fx.Layer.AbsoluteSize=V2(1280,720);fx.Layer.AbsolutePosition=V2(0,0)
 return fx,log
end
local function coins(fx)local out={};for _,c in ipairs(fx.Layer:GetChildren())do if c.Name=='SaleCoin'then out[#out+1]=c end end;return out end
local function labels(fx)local n=0;for _,c in ipairs(fx.Layer:GetChildren())do if c.Name=='SaleTotal'then n+=1 end end;return n end
-- a claim recorder: every (id,index) with the time; `reply` decides each answer
local function claims(reply)
 local c={List={},Count={}}
 function c.fn(id,index)
  c.List[#c.List+1]={Id=id,Index=index,At=R.clock};local key=id..':'..index;c.Count[key]=(c.Count[key]or 0)+1
  if reply then return reply(id,index,c.Count[key])end
  return {Success=true}
 end
 function c.distinct()local n=0;for _ in pairs(c.Count)do n+=1 end;return n end
 function c.maxRepeat()local m=0;for _,n in pairs(c.Count)do m=math.max(m,n)end;return m end
 return c
end
local function settle(seconds)for _=1,math.ceil(seconds*60)do W.frames(1,1/60)end end
local function clean(fx,label)
 settle(3)
 local n=0;for _ in pairs(fx.Shares)do n+=1 end
 check(#fx.Icons==0 and #fx.Receipts==0 and #fx.Open==0 and n==0 and fx.Busy==0,label..': nothing is left behind (icons '..#fx.Icons..', labels '..#fx.Receipts..', open shares '..#fx.Open..', registry '..n..', busy '..fx.Busy..')')
 check(#fx.Layer:GetChildren()==0,label..': the layer is empty ('..#fx.Layer:GetChildren()..' children)')
 check(fx.Connection==nil,label..': the render connection is gone')
end
local function dist(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)end

-- 1. no input: pop, rest, fly, claim -----------------------------------------------------------------------------------------------------------------------------
do
 local c=claims();local fx,log=make(c.fn)
 local t0=R.clock
 fx:Sync({receipt('a',8,1000)},V2(300,300))
 local list=coins(fx)
 check(#list==8,'one coin per share ('..#list..' / 8)')
 check(#c.List==0,'nothing is claimed at the pop')
 check(labels(fx)==1,'the sale total shows once')
 local hint=false;for _,d in ipairs(fx.Layer:GetDescendants())do if d:IsA('TextLabel')and d.Name~='SaleTotal'then hint=true end end
 check(not hint and fx.Layer:FindFirstChild('CollectCashHint')==nil,'no hint text (no CollectCashHint, no label but the total)')
 local anyInput=false;for _,coin in ipairs(list)do if coin:IsA('GuiButton')or coin.Active then anyInput=true end end
 check(not anyInput,'no coin is a button or takes input (nothing to hover or tap, and none can block the screen behind it)')
 -- the pop: the coins leave the origin within .4 s, as before
 frames(math.floor(T.Pop*60)+1)
 local far=0;for _,coin in ipairs(list)do if dist(V2(coin.Position.X.Offset,coin.Position.Y.Offset),V2(300,300))>40 then far+=1 end end
 check(far>=7,'the pop is kept: the coins have spread out from the sale ('..far..' / 8)')
 check(#c.List==0,'still nothing claimed before any coin flew')
 frames(120)
 check(#c.List==8 and c.distinct()==8 and c.maxRepeat()==1,'every share claimed by itself, once ('..#c.List..' claims, '..c.distinct()..' distinct)')
 local first,last=math.huge,0;for _,e in ipairs(c.List)do first=math.min(first,e.At-t0);last=math.max(last,e.At-t0)end
 check(first>=T.Pop+T.BeatMin+T.Fly-.03,'no claim before the first coin has rested its beat and flown ('..string.format('%.2f',first)..' s)')
 check(last<=T.Pop+T.BeatMax+T.Fly+.05,'the last claim lands by pop + longest beat + flight ('..string.format('%.2f',last)..' s)')
 check(last-first>=.15,'the coins are staggered, not one lump ('..string.format('%.2f',last-first)..' s apart)')
 check(log.cash==8 and log.gems==0,'one counter bump per coin, on the cash counter ('..log.cash..' / '..log.gems..')')
 check(rec.count('Bubble06')>=8,'one click per coin (the R150 collect cue)')
 local seen={};for _,e in ipairs(c.List)do seen[e.Index]=true end
 check(seen[1]and seen[2]and seen[3]and seen[4]and seen[5]and seen[6]and seen[7]and seen[8],'indices 1..8 all claimed')
 clean(fx,'sale');fx:Destroy()
end

-- 2. the flight: eased, an arc, shrinking, into the right counter -------------------------------------------------------------------------------------------------
do
 local c=claims();local fx,log=make(c.fn)
 fx:Sync({receipt('c',8,1000,'Cash'),receipt('g',4,40,'Gems')},V2(640,360))
 local track={} -- key -> samples {Pos, Scale, Fly}
 local function sample()
  for _,it in ipairs(fx.Icons)do
   local key=it.Share.ReceiptId..':'..it.Share.Index;track[key]=track[key]or{Currency=it.Currency,S={}}
   if it.Start then local s=track[key].S;s[#s+1]={Pos=it.Position,Scale=it.Frame.Size.X.Offset/it.Size,Fly=it.Fly,Start=it.Start}end
  end
 end
 for _=1,200 do sample();W.frames(1,1/60)end
 local cashTo,gemTo=V2(220,44),V2(420,44)
 local okEnd,okEase,okArc,okScale,okStep,okMono,n=true,true,true,true,true,true,0
 for key,t in pairs(track)do
  local s=t.S;if #s>=6 then
   n+=1
   local to=t.Currency=='Gems'and gemTo or cashTo
   if dist(s[#s].Pos,to)>25 then okEnd=false;print('  end',key,dist(s[#s].Pos,to))end
   -- speeds in px per frame along the flight
   local sp={};for i=2,#s do sp[#sp+1]=dist(s[i].Pos,s[i-1].Pos)end
   local mid=sp[math.ceil(#sp/2)];if not(sp[1]<mid*.5 and sp[#sp]<mid*.5)then okEase=false;print('  ease',key,sp[1],mid,sp[#sp])end
   local len=dist(s[1].Start,to);local peak=1.6*len/T.Fly/60
   for _,v in ipairs(sp)do if v>peak+6 then okStep=false end end
   -- arc: sideways distance from the straight line start -> counter
   local dx,dy=to.X-s[1].Start.X,to.Y-s[1].Start.Y;local maxSide=0
   for _,smp in ipairs(s)do local side=math.abs((smp.Pos.X-s[1].Start.X)*dy-(smp.Pos.Y-s[1].Start.Y)*dx)/math.max(len,1);maxSide=math.max(maxSide,side)end
   if not(maxSide>4 and maxSide<70)then okArc=false;print('  arc',key,maxSide)end
   if not(s[1].Scale>.9 and s[#s].Scale<.5)then okScale=false;print('  scale',key,s[1].Scale,s[#s].Scale)end
   for i=2,#s do if dist(s[i].Pos,to)>dist(s[i-1].Pos,to)+.75 then okMono=false end end
  end
 end
 check(n==12,'twelve flights sampled ('..n..')')
 check(okEnd,'every coin ends on its counter: cash coins on the cash counter, gem coins on the gem counter')
 check(okEase,'the flight is eased (slow at the start and the end, fastest in the middle)')
 check(okStep,'no jump: every frame step stays inside the eased peak speed')
 check(okArc,'a slight arc (a few px to well under 70 px off the straight line)')
 check(okScale,'coins start full size and shrink to under half size by the counter')
 check(okMono,'every coin gets closer to its counter all the way (no wobble back)')
 check(log.cash==8 and log.gems==4,'cash coins bump the cash counter, gem coins the gem counter ('..log.cash..' / '..log.gems..')')
 check(c.distinct()==12 and c.maxRepeat()==1,'all 12 claimed once')
 clean(fx,'cash + gems');fx:Destroy()
end

-- 3. the claim happens on arrival --------------------------------------------------------------------------------------------------------------------------------
do
 local fx
 local early,atCounter,total=0,0,0
 fx=make(function(id,index)
  total+=1
  local it;for _,i in ipairs(fx.Icons)do if i.Share.ReceiptId==id and i.Share.Index==index then it=i end end
  if not it then early+=1 elseif it.Fly>=T.Fly-1e-6 and dist(it.Position,V2(220,44))<2 then atCounter+=1 else early+=1 end
  return {Success=true}
 end)
 fx:Sync({receipt('d',10,5000)},V2(500,400));frames(150)
 check(total==10 and atCounter==10 and early==0,'every claim goes out with its coin AT the counter ('..atCounter..' on arrival, '..early..' elsewhere, '..total..' in all)')
 clean(fx,'arrival');fx:Destroy()
end

-- 4. reduced motion / FastMode: claimed at once, minimal effect -------------------------------------------------------------------------------------------------
do
 for _,mode in ipairs({'FastMode','ReducedMotion','StudioPlantEffects'})do
  if mode=='FastMode'then player:SetAttribute('FastMode',true)elseif mode=='ReducedMotion'then Gui.ReducedMotionEnabled=true else player:SetAttribute('StudioPlantEffects','off')end
  local c=claims();local fx,log=make(c.fn);rec.clear()
  fx:Sync({receipt('q',9,900,'Cash')},V2(300,300))
  check(#c.List==9 and c.distinct()==9,mode..': all 9 shares are claimed at once (before a single frame) ('..#c.List..')')
  check(#fx.Icons==0,mode..': no coins at all (nothing to fly)')
  check(labels(fx)==1,mode..': the sale total still shows (the minimal effect)')
  check(log.cash>=1 and rec.count('Bubble06')>=1,mode..': the counter still bumps and clicks as the money lands ('..log.cash..' / '..rec.count('Bubble06')..')')
  clean(fx,mode);fx:Destroy()
  local cg=claims();local fg,logg=make(cg.fn)
  fg:Sync({receipt('qg',3,30,'Gems')},V2(300,300))
  check(#cg.List==3 and logg.gems>=1,mode..': gems the same ('..#cg.List..')')
  clean(fg,mode..' gems');fg:Destroy()
  if mode=='FastMode'then player:SetAttribute('FastMode',nil)elseif mode=='ReducedMotion'then Gui.ReducedMotionEnabled=nil else player:SetAttribute('StudioPlantEffects',nil)end
 end
 -- switched on while the coins are in the air
 local c=claims();local fx=make(c.fn)
 fx:Sync({receipt('m',8,800)},V2(300,300));frames(45)
 check(#c.List<8 and #fx.Icons>0,'(mid-flight: some coins still up)')
 player:SetAttribute('FastMode',true);frames(1)
 check(#c.List==8 and #fx.Icons==0 and c.maxRepeat()==1,'FastMode switched on mid-flight: the rest are claimed at once, none twice ('..#c.List..')')
 player:SetAttribute('FastMode',nil);clean(fx,'mid-flight FastMode');fx:Destroy()
end

-- 5. many sales at once: caps and overflow ------------------------------------------------------------------------------------------------------------------------
do
 local c=claims();local fx,log=make(c.fn)
 local batch={};for i=1,4 do batch[#batch+1]=receipt('big'..i,13,13000)end
 fx:Sync(batch,V2(640,360))
 check(#fx.Icons==Effects.MaxPerCurrency,'4 x 13 cash shares: only '..Effects.MaxPerCurrency..' coins are drawn ('..#fx.Icons..')')
 check(#c.List==52-Effects.MaxPerCurrency and c.distinct()==#c.List,'the 39 shares without a coin are claimed directly, at once ('..#c.List..')')
 check(log.cash>=1,'the overflow claims bump the counter too')
 frames(150)
 check(#c.List==52 and c.distinct()==52 and c.maxRepeat()==1,'every one of the 52 shares claimed exactly once ('..#c.List..' / '..c.distinct()..')')
 clean(fx,'overflow');fx:Destroy()
 -- both currencies: 13 + 13 = MAX_ICONS
 local c2=claims();local f2=make(c2.fn)
 local mix={};for i=1,3 do mix[#mix+1]=receipt('mc'..i,13,13000,'Cash');mix[#mix+1]=receipt('mg'..i,13,2600,'Gems')end
 f2:Sync(mix,V2(640,360))
 check(#f2.Icons==Effects.MaxIcons and #f2.Icons<=26,'cash + gems: '..Effects.MaxIcons..' coins at most ('..#f2.Icons..')')
 frames(150)
 check(c2.distinct()==78 and c2.maxRepeat()==1,'all 78 shares claimed once ('..c2.distinct()..')')
 clean(f2,'mixed overflow');f2:Destroy()
 -- the most the server can hold: 64 receipts of 13
 local c3=claims();local f3=make(c3.fn)
 local all={};for i=1,Rules.MaxReceipts do all[#all+1]=receipt('max'..i,13,13000)end
 f3:Sync(all,V2(640,360));frames(240)
 check(c3.distinct()==832 and c3.maxRepeat()==1,'64 receipts x 13 = 832 shares all claimed once ('..c3.distinct()..')')
 clean(f3,'64 receipts');f3:Destroy()
 -- a second sale while coins are still up: it adds to the drawing, none is lost
 local c4=claims();local f4=make(c4.fn)
 f4:Sync({receipt('s1',8,800)},V2(300,300));frames(30)
 f4:Sync({receipt('s1',8,800),receipt('s2',8,800)},V2(900,300));frames(150)
 check(c4.distinct()==16 and c4.maxRepeat()==1,'a sale on top of a sale: 16 shares, each once ('..c4.distinct()..')')
 clean(f4,'two sales');f4:Destroy()
end

-- 6. a failed claim is retried ------------------------------------------------------------------------------------------------------------------------------------
do
 -- refused twice, then goes through; one share errors; one answers nil; one answers a bare table
 local c=claims(function(id,index,n)
  if index==1 then return {Success=n>=3}end
  if index==2 then if n<3 then error('remote failed')end;return {Success=true}end
  if index==3 then if n<2 then return nil end;return {Success=true}end
  if index==4 then if n<2 then return {}end;return {Success=true}end
  return {Success=true}
 end)
 local fx=make(c.fn)
 fx:Sync({receipt('f',8,800)},V2(300,300));frames(150);for _=1,60 do R.advance(.25)end
 local tries={};for _,e in ipairs(c.List)do tries[e.Index]=(tries[e.Index]or 0)+1 end
 check(tries[1]==3 and tries[2]==3 and tries[3]==2 and tries[4]==2,'the shares that failed are tried again until they land ('..tostring(tries[1])..','..tostring(tries[2])..','..tostring(tries[3])..','..tostring(tries[4])..')')
 for i=5,8 do check(tries[i]==1,'a share that landed first time is not claimed again (index '..i..': '..tostring(tries[i])..')')end
 -- spacing of the retries: not a hammer (>= the first back-off)
 local gaps=true;local lastAt={}
 for _,e in ipairs(c.List)do if e.Index==1 then if lastAt[1]and e.At-lastAt[1]<T.RetryFirst-.02 then gaps=false end;lastAt[1]=e.At end end
 check(gaps,'a retry waits at least the first back-off ('..T.RetryFirst..' s)')
 clean(fx,'retries');fx:Destroy()
 -- the server refuses for a long time: back-off doubles up to the cap, then it keeps trying; one success ends it
 local refuse=true;local c2=claims(function()return {Success=not refuse}end)
 local f2=make(c2.fn)
 f2:Sync({receipt('long',8,800)},V2(300,300));frames(120)
 local n1=#c2.List;R.advance(1)
 for _=1,200 do R.advance(.25)end -- 50 s of refusals
 local n2=#c2.List
 check(n2>n1 and n2<n1+8*(50/T.RetryFirst),'refused for 50 s: still retried, with back-off, not hammered ('..n1..' -> '..n2..' calls for 8 shares)')
 check(#f2.Open==8,'every share is still held, none dropped ('..#f2.Open..')')
 refuse=false;for _=1,80 do R.advance(.25)end
 check(#f2.Open==0 and c2.distinct()==8,'the moment the server accepts, all 8 are claimed ('..#f2.Open..' open)')
 local after=#c2.List;for _=1,80 do R.advance(.25)end
 check(#c2.List==after,'and the retries stop')
 clean(f2,'long refusal');f2:Destroy()
 -- a slow remote (each claim yields, like InvokeServer): never more than MAX_BUSY (8) in flight, every one finishes, none twice
 local waiting={};local inflight,peak=0,0
 local c3=claims(function(id,index)
  inflight+=1;peak=math.max(peak,inflight);waiting[#waiting+1]=coroutine.running();coroutine.yield();inflight-=1;return {Success=true}
 end)
 local f3=make(c3.fn)
 f3:Sync({receipt('slow',13,1300)},V2(300,300));frames(150)
 check(#c3.List==8 and peak==8,'a slow remote: 13 coins landed but only 8 claims are out at once ('..#c3.List..' sent, peak '..peak..')')
 local guard=0
 while #waiting>0 and guard<100 do guard+=1;local co=table.remove(waiting,1);local ok,err=coroutine.resume(co);if not ok then print('resume error',err)end;R.advance(.05)end
 settle(1)
 check(c3.distinct()==13 and c3.maxRepeat()==1 and peak<=8,'as answers come back the rest go out: 13 shares, each once, never more than 8 at a time ('..c3.distinct()..', peak '..peak..')')
 clean(f3,'slow remote');f3:Destroy()
 -- a claim that never comes back does not hold the others up beyond the cap
 local c4=claims(function(id,index)if index<=7 then coroutine.yield();return {Success=true}end;return {Success=true}end)
 local f4=make(c4.fn)
 f4:Sync({receipt('hang',12,1200)},V2(300,300));frames(150)
 check(c4.distinct()>=8,'seven claims that never answer do not stop the rest being sent ('..c4.distinct()..')')
 f4:Destroy()
 -- eight claims that never get an answer (a hung remote): after CLAIM_WAIT they are given up on and sent again; the slots are freed, all 13 shares end up claimed
 local hung={}
 local c5=claims(function(id,index,n)if index<=8 and n==1 then hung[#hung+1]=coroutine.running();coroutine.yield()end;return {Success=true}end)
 local f5=make(c5.fn)
 f5:Sync({receipt('stuck',13,1300)},V2(300,300));frames(150)
 check(#hung==8 and f5.Busy==8,'eight claims hang and hold all eight slots (hung '..#hung..', busy '..f5.Busy..')')
 for _=1,math.ceil((T.ClaimWait+3)/.25)do R.advance(.25)end
 check(#f5.Open==0 and c5.distinct()==13 and c5.maxRepeat()==2 and f5.Busy==0,'after the wait the hung claims are sent again and every share is claimed ('..c5.distinct()..' of 13, busy '..f5.Busy..')')
 for _,co in ipairs(hung)do coroutine.resume(co)end -- the old answers finally arrive: nothing is counted twice
 check(f5.Busy==0 and #f5.Open==0,'a very late answer changes nothing (busy '..f5.Busy..')')
 clean(f5,'hung remote');f5:Destroy()
end

-- 7. the screen cannot hold money back ---------------------------------------------------------------------------------------------------------------------------
do
 -- a stalled render loop (window minimised: RenderStepped stops, the scheduler runs): the watchdog claims everything by the deadline
 local c=claims();local fx=make(c.fn)
 fx:Sync({receipt('mini',8,800),receipt('minig',4,40,'Gems')},V2(300,300))
 check(#c.List==0,'(nothing claimed yet)')
 for _=1,math.ceil((T.Deadline+.6)/.05)do R.advance(.05)end -- time passes, no frame is ever drawn
 check(c.distinct()==12 and c.maxRepeat()==1,'no render frames at all: all 12 claimed by the deadline ('..string.format('%.1f',T.Deadline)..' s) ('..c.distinct()..')')
 -- the window comes back: the coins carry on and land, with no second claim
 local before=#c.List;frames(150)
 check(#c.List==before,'the coins that land afterwards claim nothing a second time')
 clean(fx,'minimised');fx:Destroy()
 -- hidden UI: a zero-size layer (nothing can be drawn): claimed at once, no coins, no label
 local c2=claims();local f2=make(c2.fn);f2.Layer.AbsoluteSize=V2(0,0)
 f2:Sync({receipt('hid',8,800)},V2(300,300))
 check(c2.distinct()==8 and #f2.Icons==0 and labels(f2)==0,'a zero-size layer: all 8 claimed at once, nothing drawn ('..c2.distinct()..')')
 clean(f2,'zero-size');f2:Destroy()
 -- the reward ScreenGui disabled: the coins still fly and claim
 host.Enabled=false
 local c3=claims();local f3=make(c3.fn);f3:Sync({receipt('dis',8,800)},V2(300,300));frames(150)
 check(c3.distinct()==8,'a disabled ScreenGui: still all 8 claimed ('..c3.distinct()..')')
 host.Enabled=true;clean(f3,'disabled gui');f3:Destroy()
 -- a burst that throws (bad layer size): claimed anyway
 local c4=claims();local f4=make(c4.fn);f4.Layer._props.AbsoluteSize='broken'
 local W0=W.warns;f4:Sync({receipt('boom',8,800)},V2(300,300))
 check(c4.distinct()==8,'a burst that errors: all 8 claimed anyway ('..c4.distinct()..')')
 f4.Layer._props.AbsoluteSize=V2(1280,720);clean(f4,'throwing burst');f4:Destroy()
 -- the UI destroyed while coins are up: whatever is owed is claimed right then
 local c5=claims();local f5=make(c5.fn)
 f5:Sync({receipt('gone',8,800)},V2(300,300));frames(20)
 check(#c5.List==0,'(coins up, nothing claimed)')
 f5:Destroy()
 check(c5.distinct()==8 and c5.maxRepeat()==1,'Destroy claims what is still owed, once each ('..c5.distinct()..')')
 -- the layer destroyed from outside (its ScreenGui removed)
 local c6=claims();local f6=make(c6.fn)
 f6:Sync({receipt('gone2',8,800)},V2(300,300));f6.Layer:Destroy()
 check(c6.distinct()==8,'a layer destroyed from outside claims what is owed too ('..c6.distinct()..')')
 -- after Destroy nothing runs
 local n=#c6.List;R.advance(30);check(#c6.List==n,'and nothing runs afterwards')
end

-- 8. exploits: only what the server listed, once --------------------------------------------------------------------------------------------------------------
do
 local allowed={};local function allow(r)for i=1,r.Count do allowed[r.Id..':'..i]=true end end
 local c=claims();local fx=make(c.fn)
 -- shares 1 and 3 are already claimed on the server (mask 0b101): they are never sent
 local r1=receipt('x1',8,800,'Cash',5);allow(r1)
 fx:Sync({r1},V2(300,300));frames(150)
 local sent13=(c.Count['x1:1']or 0)+(c.Count['x1:3']or 0)
 check(sent13==0 and c.distinct()==6,'shares the server already marks claimed are never claimed again ('..sent13..' sent, '..c.distinct()..' of 6 left)')
 -- the 5 s poll lists the same receipts again (and again): no new coins, no new claims
 local before=#c.List
 fx:Sync({r1},V2(300,300));fx:Sync({receipt('x1',8,800,'Cash',0)},V2(300,300));frames(60)
 check(#c.List==before and #fx.Icons==0,'a stale / repeated poll adds nothing, even if it still shows the share unclaimed')
 -- an older poll arriving late cannot un-claim: a share the server later marks claimed stops its pending claim
 local c2=claims(function()return {Success=false}end);local f2=make(c2.fn)
 local r2=receipt('x2',8,800);f2:Sync({r2},V2(300,300));frames(150)
 local n=#c2.List;f2:Sync({receipt('x2',8,800,'Cash',255)},V2(300,300));R.advance(20)
 check(#c2.List==n and #f2.Open==0,'a share the server reports claimed (the response was lost) stops being retried ('..#c2.List..' calls)')
 -- hostile receipts are ignored: nothing claimed, nothing drawn
 local c3=claims();local f3=make(c3.fn)
 f3:Sync({{Id='bad',Count=99,Amount=5,Claimed=0},{Id=7,Count=8,Amount=5,Claimed=0},{Id='nan',Count=8,Amount=0/0,Claimed=0},{Id='neg',Count=8,Amount=-5,Claimed=0},{Id='cur',Count=8,Amount=5,Claimed=0,Currency='Robux'},'str',42},V2(10,10))
 f3:Sync('not a table',V2(10,10));f3:Sync(nil);frames(150)
 check(#c3.List==0 and #f3.Icons==0,'malformed receipts (bad count / id / amount / currency, non-tables) are ignored')
 for _,e in ipairs(c.List)do check(allowed[e.Id..':'..e.Index]==true,'claimed only a listed share ('..e.Id..':'..e.Index..')')end
 clean(fx,'exploit');fx:Destroy();f2:Destroy();f3:Destroy()
end

-- 9. where the counters really are: the real GardenWallet + HudLayout ------------------------------------------------------------------------------------------
do
 local UIS=W.UIS;local Layout=W.module('HudLayout');local Wallet=W.module('GardenWallet')
 local profiles={{'desktop 1280x720',V2(1280,720),false},{'phone portrait 390x844',V2(390,844),true},{'phone landscape 844x390',V2(844,390),true},{'small phone landscape 667x375',V2(667,375),true}}
 for _,p in ipairs(profiles)do
  local label,size,touch=p[1],p[2],p[3]
  UIS.TouchEnabled=touch;pg:SetAttribute('SeedMenu',nil)
  local screen=R.Instance.new('ScreenGui');screen.Name='WalletHost';screen.Parent=pg;screen.AbsoluteSize=size
  local ok,wallet=pcall(Wallet.new,screen);check(ok and wallet,label..': the real wallet builds ('..tostring(wallet)..')')
  if ok and wallet then
   local mv=Layout.Read(size,touch,nil);local k=mv.Scale or 1;local m=Layout.Real(mv) -- (R158: a computer's rows are drawn at mv.Scale; m is the layout in screen px, a phone's as it is)
   for _,row in ipairs({wallet,wallet.Gems})do -- the mock does no layout: the icon's screen place = its row + its offset in the row (times the row's scale)
    local rp,ip,isz=row.Root.Position,row.Icon.Position,row.Icon.Size
    row.Icon._props.AbsolutePosition=V2(rp.X.Offset+ip.X.Offset*k,rp.Y.Offset+ip.Y.Offset*k);row.Icon._props.AbsoluteSize=V2(isz.X.Offset*k,isz.Y.Offset*k)
   end
   local cashAt,gemAt=wallet:TargetPosition(),wallet.Gems:TargetPosition()
   local side=m.WalletIcon or m.WalletHeight
   check(math.abs(cashAt.X-((m.CashX or m.WalletX)+side/2))<1.5 and math.abs(cashAt.Y-(m.CashY+m.WalletHeight/2))<1.5,label..': the cash counter is where HudLayout puts it ('..string.format('%.0f,%.0f',cashAt.X,cashAt.Y)..')')
   check(math.abs(gemAt.X-((m.GemX or m.WalletX)+side/2))<1.5 and math.abs(gemAt.Y-(m.GemY+m.WalletHeight/2))<1.5,label..': the gem counter is where HudLayout puts it ('..string.format('%.0f,%.0f',gemAt.X,gemAt.Y)..')')
   check(cashAt.X>=0 and cashAt.X<=size.X and cashAt.Y>=0 and cashAt.Y<=size.Y and gemAt.X>=0 and gemAt.X<=size.X and gemAt.Y>=0 and gemAt.Y<=size.Y,label..': both counters are on screen')
   local c=claims();local fx=Effects.new(host,wallet,c.fn);fx.Layer.AbsoluteSize=size;fx.Layer.AbsolutePosition=V2(0,0)
   fx:Sync({receipt('p'..label,8,800,'Cash'),receipt('pg'..label,4,40,'Gems')},V2(size.X*.5,size.Y*.5))
   local last={}
   for _=1,200 do for _,it in ipairs(fx.Icons)do last[it.Currency..it.Share.Index]={Pos=it.Position,Cur=it.Currency}end;W.frames(1,1/60)end
   local worst,inside=0,true
   for _,v in pairs(last)do
    local to=v.Cur=='Gems'and gemAt or cashAt;worst=math.max(worst,dist(v.Pos,to))
    if v.Pos.X<0 or v.Pos.Y<0 or v.Pos.X>size.X or v.Pos.Y>size.Y then inside=false end
   end
   check(worst<12,label..': coins land on their real counter icons (worst '..string.format('%.1f',worst)..' px off)')
   check(inside,label..': every coin stays inside the screen the whole way')
   check(c.distinct()==12,label..': all 12 claimed ('..c.distinct()..')')
   clean(fx,label);fx:Destroy()
   -- a safe-area inset on the layer (a notch): the layer is smaller than the screen and offset; coins still end on the counter, or on the layer's edge if the counter lies outside it
   local fy=Effects.new(host,wallet,claims().fn);fy.Layer.AbsolutePosition=V2(44,0);fy.Layer.AbsoluteSize=V2(size.X-88,size.Y)
   fy:Sync({receipt('n'..label,8,800,'Cash')},V2(size.X*.5,size.Y*.5))
   local lastN,allIn={},true
   for _=1,200 do for _,it in ipairs(fy.Icons)do lastN[it.Share.Index]=it.Position;local p=it.Position;if p.X<7.9 or p.Y<7.9 or p.X>size.X-88-7.9 or p.Y>size.Y-7.9 then allIn=false end end;W.frames(1,1/60)end
   local toN=V2(math.clamp(wallet:TargetPosition().X-44,12,size.X-88-12),math.clamp(wallet:TargetPosition().Y,12,size.Y-12));local worstN=0
   for _,pos in pairs(lastN)do worstN=math.max(worstN,dist(pos,toN))end
   check(allIn and worstN<12,label..': with a notch inset (the layer is smaller and offset) the coins never leave the safe area and end on the counter, or at the layer edge if it lies outside ('..string.format('%.1f',worstN)..' px off)')
   fy:Destroy()
  end
  screen:Destroy()
 end
 UIS.TouchEnabled=false
 -- a counter that is not laid out yet / far off: the coin goes to the nearest point of the safe area, never off screen
 local far={Pulse=function()end,TargetPosition=function()return V2(5000,-300)end};far.Gems=far
 local c=claims();local fx=Effects.new(host,far,c.fn);fx.Layer.AbsoluteSize=V2(800,600);fx.Layer.AbsolutePosition=V2(0,0)
 fx:Sync({receipt('far',8,800)},V2(400,300));local endPos={}
 for _=1,800 do for _,it in ipairs(fx.Icons)do endPos[it.Share.Index]=it.Position end;W.frames(1,1/240)end -- (fine frames: the last sample is within a px of the landing)
 local okFar=true;for _,pos in pairs(endPos)do if math.abs(pos.X-788)>2.5 or math.abs(pos.Y-12)>2.5 then okFar=false end end
 check(okFar and c.distinct()==8,'a counter outside the layer: coins end at its nearest edge, 12 px inside the safe area, and still claim')
 fx:Destroy()
 -- a counter row that errors / returns junk: a default place near the top-left, still claims
 local bad={Pulse=function()error('x')end,TargetPosition=function()return 'junk'end};bad.Gems=bad
 local c2=claims();local f2=Effects.new(host,bad,c2.fn);f2.Layer.AbsoluteSize=V2(800,600);f2.Layer.AbsolutePosition=V2(0,0)
 f2:Sync({receipt('junk',8,800)},V2(400,300));frames(150)
 check(c2.distinct()==8,'a broken counter row cannot stop the claims ('..c2.distinct()..')')
 f2:Destroy()
 -- a window's own balance line takes over while the HUD counters are hidden (the Sell window): Anchor
 local pulsed,lineAt=0,V2(150,120)
 local line={TargetPosition=function()return lineAt end,Pulse=function()pulsed+=1 end}
 local open=true
 local c3=claims();local f3,log3=make(c3.fn,{Anchor=function(cur)if open and cur=='Cash'then return line end end})
 f3:Sync({receipt('win',8,800,'Cash'),receipt('wing',3,30,'Gems')},V2(640,360))
 local lastW={};for _=1,200 do for _,it in ipairs(f3.Icons)do lastW[it.Currency..it.Share.Index]={it.Position,it.Currency}end;W.frames(1,1/60)end
 local cashOk,gemOk=true,true
 for _,v in pairs(lastW)do if v[2]=='Cash'then cashOk=cashOk and dist(v[1],lineAt)<12 else gemOk=gemOk and dist(v[1],V2(420,44))<12 end end
 check(cashOk and pulsed==8 and log3.cash==0,'while the window is open the cash coins fly to its balance line and bump IT, not the hidden HUD row ('..pulsed..' / '..log3.cash..')')
 check(gemOk and log3.gems==3,'gems (no line there) still fly to the gem counter')
 open=false
 f3:Sync({receipt('win2',8,800,'Cash')},V2(640,360));frames(150)
 check(log3.cash==8,'once the window closes the HUD cash counter is the target again ('..log3.cash..')')
 clean(f3,'anchor');f3:Destroy()
 -- an Anchor that throws is ignored
 local f4,log4=make(claims().fn,{Anchor=function()error('boom')end});f4:Sync({receipt('anc',8,800)},V2(640,360));frames(150)
 check(log4.cash==8,'an Anchor that errors falls back to the HUD counter')
 f4:Destroy()
end

-- 10. the hint is gone, the callers' wiring is intact -----------------------------------------------------------------------------------------------------------
do
 local B=W.B
 local fxSrc=B.SaleMoneyEffects
 for _,bad in ipairs({'CollectCashHint','MouseEnter','MouseLeave','Activated','TextButton','Hovered','Hint','hover','tap to','Item.Pending'})do
  check(fxSrc:find(bad,1,true)==nil,'the helper has no "'..bad..'"')
 end
 local eco=B.EconomyClient
 check(eco~=nil and eco:find("SaleMoneyEffects')).new(rewardGui,wallet,function(id,index)",1,true)~=nil,'EconomyClient builds the helper with the claim callback')
 check(eco:find("claimCash:InvokeServer(id,index)",1,true)~=nil and eco:find("remotes:WaitForChild('CollectSaleCash')",1,true)~=nil,'... which still calls the same remote with (id, index)')
 check(eco:find('Anchor=function(currency)',1,true)~=nil,'... and hands over the Sell window\'s balance line')
 check(eco:find("saleEffects:Sync(state.PendingSales,origin)",1,true)~=nil and eco:find("pendingCash:InvokeServer()",1,true)~=nil,'... sales and the 5 s / revision polls still feed it')
 local _,claimCalls=eco:gsub('claimCash:InvokeServer','')
 check(claimCalls==1,'... the only caller of the claim remote is the helper\'s callback ('..claimCalls..')')
 for name,src in pairs(B)do
  if type(src)=='string'and name~='BeginnerTutorial'and name~='BeginnerGuide'then
   check(src:find('CollectCashHint',1,true)==nil,name..': no CollectCashHint')
   check(src:find('HOVER OVER',1,true)==nil and src:find('Hover over',1,true)==nil and src:find('hover over the',1,true)==nil,name..': no "hover over" instruction')
  end
 end
 -- every client script keeps the load guard on line 1 (run_load_guard.sh covers it; this is the script I touched)
 check(eco:match('^[^\n]*')and eco:match('^[^\n]*'):find('R152: start once the whole game has arrived',1,true)~=nil,'EconomyClient keeps the load guard on line 1')
end

print('R152 sale money checks '..checks..', fails '..fails)
if fails>0 then error('failures: '..fails)end
