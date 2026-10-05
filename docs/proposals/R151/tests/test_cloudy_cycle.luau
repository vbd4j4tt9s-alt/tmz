--!nocheck
-- R151 Cloudy sky (owner: "add a new weather effect where it alternated so th default weather is clear i want you to make the other default weather
-- cloudy where it just dims the lighting so that the lanterns around the map can create a warm ambience"), part 1: the cycle and the server.
--  1. WeatherCycle151.lua (pure): the schedule (alternation, durations ~8 min Clear / ~6 min Cloudy with a little randomness, fades 20 - 40 s, determinism,
--     no jumps anywhere), the level maths, the atomic state string, what a client does with it (event weather / story scenes / track), the lamp rules;
--  2. the REAL WeatherService on the Roblox mock: StepSky publishes every switch once (at its boundary, a smooth start from the level the old state had
--     reached), a late joiner reads the right level, event weather takes priority and the cycle returns afterwards, Cloudy is NOT a mutation weather
--     (no roll, no trait, GlobalWeather stays Clear), the owner's test holds / skip / auto;
--  3. the owner command: weather cloudy | clear | cycle [skip|auto] through the REAL OwnerUpdateCommands82 (the old event commands unchanged),
--     docs/COMMANDS.md and the F4 help list them.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local Cycle=W.module('WeatherCycle151');local Traits=W.module('WeatherTraits')
local floor,abs,max,min=math.floor,math.abs,math.max,math.min
local Cfg=Cycle.Config

-- ======================================================================================================================
-- 1. The pure schedule
-- ======================================================================================================================
print('-- schedule')
check(Cycle.Check(),'the shipped config passes its own sanity check')
check(Cfg.Clear.Seconds==480 and Cfg.Cloudy.Seconds==360,'Clear about 8 minutes, Cloudy about 6 minutes')
check(Cfg.Fade[1]>=20 and Cfg.Fade[2]<=40 and Cfg.Fade[1]<Cfg.Fade[2],'fades take 20 - 40 seconds')
check(not Cycle.Check({Clear={Seconds=480},Cloudy={Seconds=360},Spread=.45,Fade={20,40}}),'a spread that could cross two boundaries is refused')
check(not Cycle.Check({Clear={Seconds=60},Cloudy={Seconds=60},Spread=.1,Fade={20,40}}),'phases shorter than their fades are refused')
check(not Cycle.Check({Clear={Seconds=480},Cloudy={Seconds=360},Spread=.1,Fade={40,20}}),'a backwards fade range is refused')
local T0=1788640000 -- a realistic server time (seconds since 1970)
-- 1a. boundaries increase, kinds alternate, Segment() finds the segment that holds t
do
 local prev=-math.huge;local ok=true
 local n0=floor(T0/Cycle.Period())*2
 for n=n0-4,n0+20000 do local b=Cycle.Boundary(n);if not(b>prev)then ok=false end;prev=b end
 check(ok,'20,000 boundaries in a row strictly increase')
 local alternates,holds,fadeOk=true,true,true
 local counts={Clear=0,Cloudy=0};local sum={Clear=0,Cloudy=0};local lo={Clear=1e9,Cloudy=1e9};local hi={Clear=0,Cloudy=0}
 local fmin,fmax=1e9,0
 for n=n0,n0+19999 do
  local k=Cycle.KindOf(n);if k==Cycle.KindOf(n+1)then alternates=false end
  local a,b=Cycle.Boundary(n),Cycle.Boundary(n+1);local len=b-a
  counts[k]+=1;sum[k]+=len;lo[k]=min(lo[k],len);hi[k]=max(hi[k],len)
  local f=Cycle.FadeSeconds(n);fmin=min(fmin,f);fmax=max(fmax,f)
  if f<20 or f>40 or f>len*.2 then fadeOk=false end
  for _,t in ipairs({a,a+.001,(a+b)/2,b-.001})do
   local m,kind,s,e,fd=Cycle.Segment(t)
   if m~=n or kind~=k or s~=a or e~=b or fd~=f then holds=false end
  end
 end
 check(alternates,'the sky alternates Clear / Cloudy, never two of the same in a row')
 check(holds,'Segment(t) returns the segment that holds t (80,000 probes at both edges and the middle)')
 check(fadeOk and fmin<21 and fmax>39,('every fade is 20 - 40 s (%.1f .. %.1f s) and under a fifth of its phase'):format(fmin,fmax))
 local mc,mk=sum.Clear/counts.Clear,sum.Cloudy/counts.Cloudy
 check(abs(mc-480)<4 and abs(mk-360)<4,('mean Clear %.1f s, mean Cloudy %.1f s (8 and 6 minutes)'):format(mc,mk))
 check(lo.Clear>=480-2*.1*360-1e-6 and hi.Clear<=480+2*.1*360+1e-6 and lo.Cloudy>=360-2*.1*360-1e-6 and hi.Cloudy<=360+2*.1*360+1e-6,
  ('Clear runs %.0f - %.0f s, Cloudy %.0f - %.0f s (a little randomness, bounded)'):format(lo.Clear,hi.Clear,lo.Cloudy,hi.Cloudy))
 check(hi.Clear-lo.Clear>60 and hi.Cloudy-lo.Cloudy>60,'the phases really do differ in length')
 -- not periodic: the lengths of two neighbouring pairs differ
 local different=0;for n=n0,n0+400,2 do if abs((Cycle.Boundary(n+1)-Cycle.Boundary(n))-(Cycle.Boundary(n+3)-Cycle.Boundary(n+2)))>1 then different+=1 end end
 check(different>150,'consecutive Clear phases differ (not a metronome)')
end
-- 1b. deterministic: the same time gives the same answer (every server, every player)
do
 local same=true
 for i=1,2000 do local t=T0+i*37.3;local a1,a2,a3,a4,a5=Cycle.Segment(t);local b1,b2,b3,b4,b5=Cycle.Segment(t);if a1~=b1 or a2~=b2 or a3~=b3 or a4~=b4 or a5~=b5 then same=false end end
 check(same,'Segment() is a pure function of the server time')
end
-- 1c. the scheduled level never jumps (a second of time moves it by at most the steepest fade slope)
do
 local function sched(t)
  local n,kind,s,e,f=Cycle.Segment(t)
  return Cycle.LevelAt(kind,s,f,kind=='Cloudy'and 0 or 1,t)
 end
 local worst,prev,min_,max_=0,sched(T0),1,0
 for i=1,3*86400 do local t=T0+i;local v=sched(t);worst=max(worst,abs(v-prev));prev=v;min_=min(min_,v);max_=max(max_,v) end
 check(worst<=1.5/20+1e-9,('three days second by second: the biggest step is %.4f (limit 1.5 / 20 s = %.4f): no pop'):format(worst,1.5/20))
 check(min_==0 and max_==1,'and it reaches both Clear (0) and Cloudy (1)')
end
-- 1d. level maths
do
 check(Cycle.LevelAt('Cloudy',100,30,0,100)==0 and Cycle.LevelAt('Cloudy',100,30,0,130)==1 and near(Cycle.LevelAt('Cloudy',100,30,0,115),.5),'a fade starts at its from level, is half way at half time and ends at the target')
 check(Cycle.LevelAt('Clear',100,30,1,100)==1 and Cycle.LevelAt('Clear',100,30,1,130)==0 and near(Cycle.LevelAt('Clear',100,30,1,115),.5),'the same going back to Clear')
 check(near(Cycle.LevelAt('Cloudy',100,30,.4,100),.4)and Cycle.LevelAt('Cloudy',100,30,.4,200)==1,'a fade can start part way (a skip or a test mid-fade)')
 local mono=true;local last=0;for i=0,300 do local v=Cycle.LevelAt('Cloudy',0,30,0,i/10);if v<last-1e-12 then mono=false end;last=v end
 check(mono,'smoothstep: monotonic')
 check(Cycle.LevelAt('Cloudy',100,30,0,50)==0 and Cycle.LevelAt('Clear',100,30,1,50)==1,'before its start a state shows its from level')
 check(Cycle.LevelAt('Cloudy',nil,30,0,5)==1 and Cycle.LevelAt('Cloudy',1,0,0,5)==1 and Cycle.LevelAt('Cloudy',0/0,30,0,5)==1,'a damaged state resolves to its target, never an error')
end
-- 1e. the atomic state string
do
 local s=Cycle.Pack('Cloudy',T0+.25,31.5,.125,T0+360)
 local u=Cycle.Unpack(s)
 check(u and u.Kind=='Cloudy' and near(u.Since,T0+.25,.001)and near(u.Fade,31.5,.001)and near(u.From,.125,1e-4)and near(u.Ends,T0+360,.001),'Pack / Unpack round-trip at 1.8e9 seconds: '..s)
 check(#s<96,'the state string is short ('..#s..' bytes)')
 for _,bad in ipairs({'','Rain|1|2|0|3','Cloudy|x|30|0|1','Cloudy|1|0|0|1','Cloudy|1|30|2|1','Cloudy|1|30|-1|1','Cloudy|1|9999|0|1','Cloudy|1|30|0','Cloudy|1|30|0|1|7',string.rep('x',200)})do
  check(Cycle.Unpack(bad)==nil,'refused: '..bad:sub(1,30))
 end
 check(Cycle.Unpack(nil)==nil and Cycle.Unpack(5)==nil,'non-strings are refused')
 local store=R.new('Folder')
 check(select(1,Cycle.Read(store,T0))==0 and select(2,Cycle.Read(store,T0))=='Clear','no attribute (an old server): Clear')
 store:SetAttribute(Cycle.Attribute,'garbage');check(Cycle.Read(store,T0)==0,'a damaged attribute: Clear')
 store:SetAttribute(Cycle.Attribute,Cycle.Pack('Cloudy',T0,30,0,T0+360))
 local l,k=Cycle.Read(store,T0+15);check(near(l,.5,1e-3)and k=='Cloudy','Read: half way through the fade')
 check(Cycle.Read(store,T0+60)==1,'Read: fully cloudy afterwards')
end
-- 1f. what a client does with the level
do
 check(Cycle.Effective(1,0,'Clear',nil)==1 and Cycle.Effective(.4,0,nil,nil)==.4,'the base under a clear default sky takes the level')
 for _,ev in ipairs({'Rain','Thunderstorm','Blizzard'})do check(Cycle.Effective(1,0,ev,nil)==0,'event weather ('..ev..') takes priority: no Cloudy look')end
 check(Cycle.Effective(1,0,'Clear','Scene')==0,'a rare-pull story scene is lit as authored')
 check(Cycle.Effective(1,0,'Clear','Ladder')==1 and Cycle.Effective(1,0,'Clear','InPlace')==1,'the other reveals (in the world) keep the sky')
 for stage=1,7 do check(Cycle.Effective(1,stage,'Clear',nil)==0,'the track (stage '..stage..') keeps its biome mood (Track = 0)')end
 check(near(Cycle.Effective(1,3,'Clear',nil,{Track=.5}),.5)and Cycle.Effective(1,3,'Clear',nil,{Track=2})==1,'an owner Track share between 0 and 1 scales the track')
 check(Cycle.Effective(0,0,'Clear',nil)==0 and Cycle.Effective(nil,0,'Clear',nil)==0,'level 0 / nil: nothing')
 check(Cycle.LampStrength(0)==0 and Cycle.LampStrength(Cycle.Lamps.OnAt)==0 and near(Cycle.LampStrength(1),Cycle.Lamps.Light),'lamps stay off until the sky has dimmed a little, full glow at full Cloudy')
 local mono=true;local last=0;for i=0,100 do local v=Cycle.LampStrength(i/100);if v<last-1e-12 then mono=false end;last=v end
 check(mono,'lamp strength rises monotonically with the level')
 check(Cycle.RealLights(3)==8 and Cycle.RealLights(2)==4 and Cycle.RealLights(1)==0 and Cycle.RealLights(nil)==0 and Cycle.RealLights(9)==Cycle.Lamps.Real[1],'real lights by tier: 8 desktop, 4 phone, 0 FastMode (an unknown tier gets the lowest)')
 check(Cycle.Quant(.51,24)==12/24 and Cycle.Quant(2,10)==1 and Cycle.Quant(-1,10)==0,'Quant clamps and rounds to steps')
end
-- 1g. Cloudy is not an event: the mutation weather tables are untouched
do
 local keys={};for k in pairs(Traits.Events)do keys[#keys+1]=k end;table.sort(keys)
 check(table.concat(keys,',')=='Blizzard,Rain,Thunderstorm','WeatherTraits.Events is still Rain / Thunderstorm / Blizzard only')
 check(Traits.Traits.Cloudy==nil and Traits.Valid('Cloudy')==false and table.concat(Traits.Order,',')=='Drippy,Frosted,Charged','no Cloudy trait, no new mutation layer')
 local never=true;for c=0,20000 do if Traits.Schedule(c*900+10)=='Cloudy'then never=false end end
 check(never,'the event schedule never returns Cloudy')
 check(Traits.Duration==180 and Traits.Interval==900,'event timing unchanged (3 minutes every 15)')
end

-- ======================================================================================================================
-- 2. The real WeatherService
-- ======================================================================================================================
print('-- WeatherService')
local RS=W.RS;local Players=W.service('Players');function Players.GetPlayers()return{}end
local T=T0+12.5
function W.workspace.GetServerTimeNow()return T end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local notice=R.new('RemoteEvent');notice.Name='WeatherAdopted';notice.Parent=remotes
notice.FireAllClients=function()end;notice.FireClient=function()end
local Service=W.module('WeatherService')
local rolls={Pack=0,Crop=0,Held=0}
local origPack,origCrop,origHeld=Service.ApplyPack,Service.ApplyCrop,Service.ApplyHeldPack
function Service:ApplyPack(...)rolls.Pack+=1;return origPack(self,...)end
function Service:ApplyCrop(...)rolls.Crop+=1;return origCrop(self,...)end
function Service:ApplyHeldPack(...)rolls.Held+=1;return origHeld(self,...)end
local seed={Available=true,Model=R.new('Model'),Generation=1,Stage=1,Weather='None',PackSize=1};seed.Model.Parent=W.workspace
local chests={Config={RemoteFolderName='ChestChaseRemotes'},Map={Chests={seed}},Openings={}}
local data={IsLoaded=function()return false end}
local function fresh()return Service.new(data,chests)end
local svc=fresh();svc.Chests.Weather=svc
-- count the changes of the three sky attributes (an unchanged value is not a write on Roblox either)
local writes=0
RS.AttributeChanged:Connect(function(k)if k==Cycle.Attribute or k==Cycle.KindAttribute or k=='AmbientSkyEndsAt'then writes+=1 end end)
local function clientLevel(t)return (Cycle.Read(RS,t))end
-- 2a. start: the first publish matches the pure schedule at that moment
do
 svc:Step(T);svc:StepSky(T)
 local n,kind,s,e,f=Cycle.Segment(T)
 local u=Cycle.Unpack(RS:GetAttribute(Cycle.Attribute))
 check(u~=nil and u.Kind==kind and RS:GetAttribute(Cycle.KindAttribute)==kind,'the first publish carries the scheduled kind ('..kind..')')
 check(near(u.Since,s,.01)and near(u.Fade,f,.01)and near(u.Ends,e,.01)and near(RS:GetAttribute('AmbientSkyEndsAt'),e,.01),'... with the segment start, fade and end')
 check(near(clientLevel(T),Cycle.LevelAt(kind,s,f,kind=='Cloudy'and 0 or 1,T),1e-3),'a player reading it right now sees the scheduled level')
 check(RS:GetAttribute('GlobalWeather')=='Clear','GlobalWeather stays Clear (the default sky is not an event)')
end
-- 2b. six hours at the half-second tick the server uses: alternation, durations, one write per switch, no jumps as the clients see them
do
 local svc2=fresh();writes=0
 local published={};local last=nil;local worst=0;local prevLevel=nil
 local t=T0
 local steps=6*3600*2
 for i=0,steps do
  local now=t+i*.5
  T=now
  local did=svc2:StepSky(now)
  if did then published[#published+1]={At=now,State=table.clone(svc2.Sky)}end
  local lv=clientLevel(now)
  if prevLevel then worst=max(worst,abs(lv-prevLevel))end;prevLevel=lv
 end
 check(#published>=48 and #published<=56,('six hours: %d switches published (a phase averages 7 minutes)'):format(#published))
 check(writes<=3*#published and writes>=3*(#published-1),('three attribute changes per switch (the first may repeat the kind of an earlier publish), none in between (%d changes, %d switches)'):format(writes,#published))
 local alt,delay,startsFrom,fadeOk=true,0,true,true
 local lens={Clear={},Cloudy={}}
 for i,p in ipairs(published)do
  local s=p.State
  if i>1 and published[i-1].State.Kind==s.Kind then alt=false end
  if i>1 then delay=max(delay,p.At-s.Since)end
  if i>1 then
   local before=published[i-1].State
   if not near(s.From,Cycle.LevelAt(before.Kind,before.Since,before.Fade,before.From,s.Since),1e-6)then startsFrom=false end
   table.insert(lens[before.Kind],s.Since-before.Since)
  end
  if s.Fade<20 or s.Fade>40 then fadeOk=false end
 end
 check(alt,'the published kinds alternate')
 check(delay<=.5+1e-9,('every switch is published within the half-second tick of its boundary (%.2f s)'):format(delay))
 check(startsFrom,'each state starts from the level the old one reached')
 check(fadeOk,'every published fade is 20 - 40 s')
 local okLen=true
 for _,list in pairs(lens)do for _,len in ipairs(list)do if len<288-1 or len>552+1 then okLen=false end end end
 check(okLen and #lens.Clear>=5 and #lens.Cloudy>=5,('published phases last 4.8 - 9.2 minutes (%d Clear, %d Cloudy measured)'):format(#lens.Clear,#lens.Cloudy))
 check(worst<=1.5/20*.5+1e-3,('what the clients see moves at most %.4f per half second over six hours: no pop at a publish'):format(worst))
 -- the half-second tick in between does nothing
 writes=0;for i=1,200 do svc2:StepSky(svc2.Sky.Since+1+i*.1)end
 check(writes==0,'steps inside a segment write nothing')
end
-- 2c. a late joiner at every moment of a fade sees what the server meant
do
 local svc3=fresh();T=T0+5000;svc3:StepSky(T)
 local s=svc3.Sky;local ok=true
 for i=0,40 do local t=s.Since+i*s.Fade/40;if not near(clientLevel(t),Cycle.LevelOf(s,t),2e-4)then ok=false end end
 check(ok,'a client joining at any point of the fade reads the server\'s level')
end
-- 2d. event weather: priority, the cycle underneath, the return
do
 local svc4=fresh();svc4.Chests.Weather=svc4;rolls.Pack,rolls.Crop,rolls.Held=0,0,0
 local t=T0+20000;T=t;svc4:Step(t);svc4:StepSky(t)
 local kindBefore=svc4.Sky.Kind
 -- an event begins (the owner test uses the same Override as a scheduled one)
 svc4.Override={Kind='Rain',Cycle=-1,Until=t+180,All=false};svc4:Step(t)
 check(RS:GetAttribute('GlobalWeather')=='Rain','the event is announced as before (GlobalWeather = Rain)')
 local U=Cycle.Unpack(RS:GetAttribute(Cycle.Attribute))
 check(U~=nil,'the default-sky state is still there during the event')
 check(Cycle.Effective(clientLevel(t),0,RS:GetAttribute('GlobalWeather'),nil)==0,'client side: no Cloudy look during the event')
 -- the cycle keeps running underneath: step through the event and a few more minutes
 local flips=0;local before=svc4.Sky.Key
 for i=1,1200 do local now=t+i*1;T=now;if svc4:StepSky(now)then flips+=1 end;if i%5==0 then svc4:Step(now)end end
 check(RS:GetAttribute('GlobalWeather')=='Clear','the event ended on time (GlobalWeather back to Clear)')
 local n,kind=Cycle.Segment(t+1200)
 check(svc4.Sky.Kind==kind,'after the event the sky is wherever the cycle is by then ('..kind..')')
 check(Cycle.Effective(clientLevel(t+1200),0,'Clear',nil)==clientLevel(t+1200),'... and the look is applied again')
 check(flips>=1,'the cycle kept switching while the event ran ('..flips..' switches in 20 minutes)')
 -- event weather still rolls mutations exactly as before; Cloudy never does
 check(rolls.Pack>0,'during the event the pack mutation rolls ran as before ('..rolls.Pack..')')
end
-- 2e. no mutation for Cloudy
do
 local svc5=fresh();svc5.Chests.Weather=svc5;rolls.Pack,rolls.Crop,rolls.Held=0,0,0
 local t;for i=0,5000 do local now=T0+40000+i*7;local _,kind=Cycle.Segment(now);if kind=='Cloudy'and Cycle.Segment(now+30)==Cycle.Segment(now)then t=now;break end end
 T=t;svc5:StepSky(t)
 check(svc5.Sky.Kind=='Cloudy','(found a cloudy moment)')
 -- 15 minutes of steps in a cloudy phase with no event on
 local gw={};local ev=0
 for i=0,170 do local now=t+i*5;T=now;svc5:Step(now);svc5:StepSky(now);gw[RS:GetAttribute('GlobalWeather')or'?']=true
  local k,_=svc5:State(now);if Traits.Events[k]then ev+=1 end end
 local only=true;for k in pairs(gw)do if k~='Clear'and not Traits.Events[k]then only=false end end
 check(only,'GlobalWeather only ever holds Clear or an event weather (never Cloudy)')
 if ev==0 then check(rolls.Pack==0 and rolls.Crop==0 and rolls.Held==0,'cloudy and no event: not one pack / plant / fruit mutation roll')end
 check(svc5.ForceAll==false,'no forced mutation either')
 local src=W.B.WeatherService
 check(not src:find("Events%.Cloudy")and not src:find("'Cloudy'then self:Apply"),'WeatherService does not treat Cloudy as an event')
end
-- 2f. owner tests on the service: hold, skip, auto
do
 local svc6=fresh();local t=T0+90000;T=t;svc6:Step(t);svc6:StepSky(t)
 local natural=svc6.Sky.Kind
 -- hold the other sky
 local other=natural=='Cloudy'and'Clear'or'Cloudy'
 svc6:HoldSky(other,t)
 local s=svc6.Sky
 check(s.Kind==other and s.Hold==true and near(s.Fade,Cfg.TestFade)and near(s.Ends,t+Cfg.TestHold),'a hold: the kind, the test fade ('..Cfg.TestFade..' s) and its length ('..Cfg.TestHold..' s)')
 check(Cycle.Unpack(RS:GetAttribute(Cycle.Attribute)).Kind==other,'published at once')
 local lv0=clientLevel(t);local expect=natural=='Cloudy'and 1 or 0
 check(near(lv0,expect,1e-3),'it starts from the level the natural sky had ('..expect..')')
 check(near(clientLevel(t+Cfg.TestFade),other=='Cloudy'and 1 or 0,1e-6),'and arrives within the test fade')
 -- a second hold mid-fade starts from where the first one had got to
 T=t+3;svc6:HoldSky(natural,t+3)
 local s2=svc6.Sky;local mid=Cycle.LevelAt(other,t,Cfg.TestFade,natural=='Cloudy'and 1 or 0,t+3)
 check(near(s2.From,mid,1e-6),'a hold changed mid-fade starts from the level reached (no jump)')
 -- expiry: back to the cycle with its fade, from the level it had
 local after=t+3+Cfg.TestHold+1;T=after;svc6:StepSky(after)
 local nat=Cycle.Segment(after)
 local s3=svc6.Sky
 check(not s3.Hold and s3.Kind==Cycle.KindOf(nat),'after the hold the cycle goes on ('..s3.Kind..')')
 check(near(s3.Since,after,.01),'... starting now, not at the old boundary (so nothing jumps)')
 check(s3.Fade>=20 and s3.Fade<=40,'... with a real fade')
 -- a hold of the sky the cycle is ALREADY in must not pop when it ends (Cloudy held while Cloudy, Clear while Clear)
 do
  local svcH=fresh();local tH=T0+110000
  -- a moment from which the natural phase outlasts the whole hold (so the cycle is in the SAME sky when the hold ends)
  while true do local n=Cycle.Segment(tH);if Cycle.Segment(tH+Cfg.TestHold+5)==n then break end;tH+=7 end
  T=tH;svcH:StepSky(tH)
  local kindH=svcH.Sky.Kind;svcH:HoldSky(kindH,tH+1)
  local endH=svcH.Sky.Ends+1;local lvBefore=clientLevel(endH-.01);T=endH;svcH:StepSky(endH)
  local sH=svcH.Sky
  check(not sH.Hold and near(sH.From,kindH=='Cloudy'and 1 or 0,1e-6),'a hold of the sky already on show: when it ends the cycle\'s state starts from that level ('..tostring(sH.From)..'), not from the opposite end')
  local jump=math.abs(clientLevel(endH+.01)-lvBefore)
  check(jump<.01,('... so the level does not move at the moment the hold ends (%.4f)'):format(jump))
 end
 -- skip
 local svc7=fresh();local t7=T0+130000;T=t7;svc7:StepSky(t7)
 local shown=svc7.Sky.Kind;local endsOld=svc7.Sky.Ends
 local sk=svc7:SkipSky(t7+1)
 check(sk.Kind~=shown and sk.Fade>=20 and sk.Fade<=40,'skip: the other sky ('..shown..' -> '..sk.Kind..') with a real fade')
 check(near(sk.Since,t7+1,.01),'... starting now')
 check((svc7.SkyShift or 0)~=0,'... by shifting this server\'s clock (the cycle goes on from there)')
 local len=sk.Ends-sk.Since
 check(len>=288-1 and len<=552+1,('... and the new phase lasts its natural length (%.0f s)'):format(len))
 local sk2=svc7:SkipSky(t7+5)
 check(sk2.Kind==shown,'a second skip goes back')
 local rep=table.concat(svc7:SkyReport(t7+6),'\n')
 check(rep:find('Default sky')and rep:find('Cycle: Clear about 8:00, Cloudy about 6:00')and rep:find('Event weather'),'the report names the sky, the cycle and the event weather')
 local rel=svc7:ReleaseSky(t7+10)
 check((svc7.SkyShift or 0)==0 and svc7.SkyHold==nil,'auto: the shift and any hold are gone')
 local nat2,kind2=Cycle.Segment(t7+10)
 check(rel.Kind==kind2,'... and the sky is what the real schedule says')
 check(near(rel.Since,t7+10,.01),'... starting now (no jump from the shifted schedule)')
 -- skip while a hold is on
 local svc8=fresh();local t8=T0+170000;T=t8;svc8:StepSky(t8);local nat8=svc8.Sky.Kind;local oth8=nat8=='Cloudy'and'Clear'or'Cloudy'
 svc8:HoldSky(oth8,t8+1);local sk8=svc8:SkipSky(t8+2)
 check(sk8.Kind==nat8 and not sk8.Hold and svc8.SkyHold==nil,'skip while held: the hold is released and the OTHER sky than the held one starts')
 -- hold only accepts the two skies
 check(svc8:HoldSky('Rain',t8)==false and svc8:HoldSky(nil,t8)==false,'a hold of anything but Clear / Cloudy is refused')
 -- Start(): the 0.5 s heartbeat
 local svc9=fresh()
 T=T0+210000;svc9.Chests.Weather=svc9;svc9:Start()
 check(RS:GetAttribute(Cycle.Attribute)~=nil and svc9.Connection~=nil,'Start() publishes the sky at once and listens')
 writes=0;local k0=svc9.Sky.Key
 local boundary=svc9.Sky.Ends
 T=boundary-3;W.frames(1,1/60)
 check(svc9.Sky.Key==k0,'(just before the boundary: unchanged)')
 for i=1,12 do T=boundary-3+i*.5;W.frames(30,1/60)end
 check(svc9.Sky.Key~=k0,'the server heartbeat publishes the switch as the boundary passes (twice a second)')
 svc9.Connection:Disconnect()
end

-- ======================================================================================================================
-- 3. The owner's command (the real OwnerUpdateCommands82)
-- ======================================================================================================================
print('-- command')
do
 local Owner=W.module('OwnerUpdateCommands82')
 local svc=fresh();svc.Chests=chests;chests.Weather=svc
 local t=T0+260000;T=t;svc:Step(t);svc:StepSky(t)
 local ctx={Chests=chests,Map={MapRoot=R.new('Model')},Chase={Event81={}},Data=data,Config={}}
 local function run(...)return Owner.Execute(ctx,nil,'weather',{...})end
 check(Owner.Actions.weather==true,'weather is an existing action: no new key was added to Actions')
 for _,k in ipairs({'cloudy','skycycle','cycle'})do check(Owner.Actions[k]==nil,'(no new Actions key: '..k..')')end
 -- weather cloudy
 local ok,msg=run('cloudy')
 check(ok and msg:find('Cloudy')and svc.Sky.Kind=='Cloudy'and svc.Sky.Hold==true,'weather cloudy: the sky is held Cloudy ('..tostring(msg):sub(1,50)..')')
 check(svc.Override and svc.Override.Kind=='Clear'and svc.Override.Until>=svc.Sky.Ends-1,'... and event weather is cleared for as long (an event would hide it)')
 check(near(svc.Sky.Ends-svc.Sky.Since,Cfg.TestHold,.01),'... for the test hold time')
 -- weather clear
 ok,msg=run('clear')
 check(ok and svc.Sky.Kind=='Clear'and svc.Sky.Hold==true and svc.Override.Kind=='Clear','weather clear: event weather cleared as before and the default sky held Clear')
 check(msg:find('Normal weather resumes after this event')and msg:find('default sky'),'... the old message plus the sky')
 -- the old event commands: unchanged
 ok,msg=run('rain');check(ok and svc.Override.Kind=='Rain'and svc.Override.All==false and near(svc.Override.Until-t,Traits.Duration,5)and msg:find('Server weather: Rain'),'weather rain: as before')
 local heldBefore=svc.SkyHold
 ok,msg=run('thunder','all');check(ok and svc.Override.Kind=='Thunderstorm'and svc.Override.All==true,'weather thunder all: as before')
 ok=run('blizzard');check(ok and svc.Override.Kind=='Blizzard','weather blizzard: as before')
 check(svc.SkyHold==heldBefore,'event commands leave the default sky alone (the event takes priority on its own)')
 ok,msg=run('clear','all');check(not ok and msg:find('weather'),'weather clear all: still refused')
 ok,msg=run('nonsense');check(not ok and msg:find('cloudy')and msg:find('cycle'),'a wrong word lists the choices, including cloudy and cycle')
 ok,msg=run('cloudy','all');check(not ok,'weather cloudy all: refused')
 -- weather cycle
 ok,msg=run('cycle');check(ok and msg:find('Default sky')and msg:find('Event weather'),'weather cycle: the report')
 local k=svc.Sky.Kind
 ok,msg=run('cycle','skip');check(ok and svc.Sky.Kind~=k and not svc.Sky.Hold and msg:find('skipped'),'weather cycle skip: the other sky, the real fade')
 ok,msg=run('cycle','auto');check(ok and (svc.SkyShift or 0)==0 and msg:find('real schedule'),'weather cycle auto: the real schedule')
 ok=run('cycle','bogus');check(not ok,'weather cycle bogus: refused')
 ok=run('cycle','skip','x');check(not ok,'weather cycle skip x: refused')
 -- no weather service yet
 local lone={Chests={Weather=nil},Map={MapRoot=R.new('Model')},Chase={Event81={}},Data=data,Config={}}
 ok,msg=Owner.Execute(lone,nil,'weather',{'cloudy'});check(not ok and msg:find('loading'),'before the weather service exists: "Weather is loading."')
 -- docs and help
 check(W.B.StudioTestHelp:find('/test weather cloudy',1,true)~=nil and W.B.StudioTestHelp:find('weather cycle',1,true)~=nil,'the F4 help lists weather cloudy and weather cycle')
 check(W.B.StudioTestHelp:find('Weather clear, cloudy, rain',1,true)~=nil,'... and the weather line names cloudy')
end

-- the weather HUD's accessible label names the default sky (the row's picture and timer stay the event weather's)
do
 local State=W.module('WorldStatusState')
 RS:SetAttribute('GlobalWeather','Clear');RS:SetAttribute('AmbientSky','Cloudy')
 local w=State.Read(RS,nil,nil,T)
 check(w.Title=='Cloudy skies'and w.Kind=='Clear','the weather row reads "Cloudy skies" under the Cloudy sky (its picture stays the clear-weather one)')
 RS:SetAttribute('AmbientSky','Clear');check(State.Read(RS,nil,nil,T).Title=='Clear skies','... and "Clear skies" under Clear')
 RS:SetAttribute('AmbientSky',nil);check(State.Read(RS,nil,nil,T).Title=='Clear skies','... and without a sky state (an old server)')
 RS:SetAttribute('GlobalWeather','Rain');RS:SetAttribute('AmbientSky','Cloudy')
 w=State.Read(RS,nil,nil,T);check(w.Title=='Rain'and w.Kind=='Rain','an event weather is still just its name (it takes priority)')
 RS:SetAttribute('GlobalWeather','Clear')
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
