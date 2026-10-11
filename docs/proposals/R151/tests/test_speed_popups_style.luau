--!nocheck
-- R151 speed popups: the pure SpeedPopupStyle against the numbers measured in the reference clip (docs/proposals/R151/speed_popups.md): pop, fling, fade,
-- retire, plans, caps per tier, Reduced Motion, splitting an award, spacing, units, bad arguments, and our colours / font / bolt unchanged.
-- Run from a scratch folder holding roblox.luau, world.luau and rs_bundle.luau (run_speed_popups.sh does it).
local PW=require('./speed_popups_world');local W=PW.W
local Style=W.module('SpeedPopupStyle')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local function lcg(seed)local s=seed;return function()s=(s*1664525+1013904223)%4294967296;return s/4294967296 end end
local plan={Angle=0,Radius=100,StartX=0,StartY=-5,ReducedX=14,IconTilt=0,TextTilt=0}

-- 1. pop: starts at 45%, peaks 1.05..1.10 between 0.12 and 0.20 s, is exactly 1 from 0.28 s on -----------------------------------------------------------
local _,_,s0,a0=Style.Pose(plan,0,false)
check(near(s0,0.45),'pop starts at 0.45 ('..s0..')')
check(a0==1,'opaque at birth')
local peak,peakAt=0,0
for i=0,280 do local _,_,s=Style.Pose(plan,i/1000,false);if s>peak then peak,peakAt=s,i/1000 end end
check(peak>1.05 and peak<1.10,'overshoot 5..10% ('..peak..')')
check(peakAt>=0.12 and peakAt<=0.20,'peak between 0.12 and 0.20 s ('..peakAt..')')
check(near(select(3,Style.Pose(plan,0.28,false)),1),'scale is 1 once the pop is over')
for _,t in ipairs({0.3,0.45,0.6})do check(near(select(3,Style.Pose(plan,t,false)),1),'scale stays 1 at '..t)end
-- icon widths measured in the clip (mean of three popups, 1 = full size) at ~0.017 + k/30 s: 0.50 0.71 0.91 1.02 1.06 1.06 1.02
local measured={0.50,0.71,0.91,1.02,1.06,1.06,1.02};local worst=0
for k=0,6 do worst=math.max(worst,math.abs(select(3,Style.Pose(plan,0.017+k/30,false))-measured[k+1]))end
check(worst<0.12,'pop within 0.12 of the measured sizes ('..worst..')')
check(select(3,Style.Pose(plan,-1,false))==0 and select(4,Style.Pose(plan,-1,false))==0,'a negative age is not drawn')

-- 2. fling: cubic ease-out over 0.40 s, straight up here --------------------------------------------------------------------------------------------------
local function rise(t)local _,y=Style.Pose(plan,t,false);return -(y-plan.StartY)end
check(near(rise(0),0),'no travel at birth')
check(near(rise(0.082)/100,0.5,0.01),'half way at 0.082 s ('..rise(0.082)..')')
check(near(rise(0.214)/100,0.9,0.01),'90% at 0.214 s ('..rise(0.214)..')')
check(near(rise(0.40),100) and near(rise(0.64),100),'arrives at 0.40 s and then stays')
check(near(rise(0.001)/0.001,750,12),'initial speed 3 x radius / 0.4 s')
local sx=Style.Pose({Angle=math.rad(90),Radius=100,StartX=0,StartY=0},0.4,false)
check(near(sx,100),'+90 degrees is to the right ('..sx..')')
check(near(Style.Pose({Angle=math.rad(-45),Radius=100,StartX=0,StartY=0},0.4,false),-70.71,0.01),'-45 degrees is to the left')

-- 3. fade: opaque to 0.50 s, linear to 0 at 0.65 s, gone at 0.65 s ------------------------------------------------------------------------------------------------
local function alphaAt(t)local _,_,_,a,alive=Style.Pose(plan,t,false);return a,alive end
check(alphaAt(0.5)==1,'opaque at 0.5 s')
check(near(alphaAt(0.575),0.5),'half clear at 0.575 s')
local aEnd,aliveEnd=alphaAt(0.65)
check(aEnd==0 and aliveEnd==false,'clear and dead at 0.65 s')
check(select(2,alphaAt(0.64))==true,'alive at 0.64 s')
check(near(Style.Life,0.65),'life = 0.65 s')
local _,_,_,aRet=Style.Pose(plan,0.24,false,0.2)
check(near(aRet,0.5),'a retired popup is half clear 0.04 s after the cap retired it')
local _,_,_,aRet2,aliveRet=Style.Pose(plan,0.28,false,0.2)
check(aRet2==0 and aliveRet==false,'a retired popup is gone 0.08 s after')
local _,_,_,aRet3=Style.Pose(plan,0.6,false,0.2)
check(aRet3==0,'retiring never makes a popup clearer than its own fade')

-- 4. plans: a shuffled fan, every slot once per bag, inside the fan, radii inside the range, never the same slot twice in a row ------------------------
local rng,bag=lcg(5),{}
local seen,lastSlot,repeats={},nil,0
local okRange,minR,maxR,sumAngle,minAngle,maxAngle=true,1e9,0,0,1e9,-1e9
for n=1,700 do
 local p=Style.Plan(rng,bag)
 local degrees=math.deg(p.Angle)
 if math.abs(degrees)>Style.Fling.HalfAngle+1e-9 then okRange=false end
 minR,maxR=math.min(minR,p.Radius),math.max(maxR,p.Radius);sumAngle+=degrees;minAngle=math.min(minAngle,degrees);maxAngle=math.max(maxAngle,degrees)
 if bag.Last==lastSlot then repeats+=1 end
 lastSlot=bag.Last;seen[bag.Last]=(seen[bag.Last]or 0)+1
 if math.abs(p.StartX)>Style.Spawn.Jitter+1e-9 or p.StartY~=-Style.Spawn.Lift then okRange=false end
 if math.abs(p.IconTilt)>Style.Size.IconTilt+1e-9 or math.abs(p.TextTilt)>Style.Size.TextTilt+1e-9 then okRange=false end
end
check(okRange,'angles, start offsets and tilts are inside their ranges')
check(minR>=Style.Fling.Radius[1]-1e-9 and maxR<=Style.Fling.Radius[2]+1e-9,'radii inside 44..104 ('..minR..'..'..maxR..')')
check(seen[1]==100 and seen[4]==100 and seen[7]==100,'every slot is used equally (700 plans / 7 slots = 100)')
check(repeats==0,'never the same slot twice in a row ('..repeats..')')
check(math.abs(sumAngle/700)<3,'the fan is centred (mean '..sumAngle/700 ..')')
check(minAngle<-60 and maxAngle>60,'the fan is wide: '..math.floor(minAngle)..' .. '..math.floor(maxAngle)..' degrees')
do -- a plan can fill a table instead of making one
 local into={};local p=Style.Plan(lcg(9),{},into)
 check(p==into and into.Radius~=nil and into.ReducedX~=nil,'Plan fills the table it is given')
 local b2={};local r2=lcg(3);local first=Style.Plan(r2,b2,{});local slotsTable=b2.Slots
 for _=1,20 do Style.Plan(r2,b2,{})end
 check(b2.Slots==slotsTable,'the slot bag is refilled in place (no new table every 7 popups)')
end

-- 5. Reduced Motion: no fling, no pop, rises 72 px in 0.7 s, alternating sides, gone at 0.7 s ---------------------------------------------------------------
local _,_,rs0,ra0=Style.Pose(plan,0,true)
check(ra0==0 and rs0==1,'reduced: starts clear at full size (no pop)')
check(select(5,Style.Pose(plan,0,true))==true and select(5,Style.Pose(plan,0.04,true))==true,'reduced: alive while it fades in (clear at age 0 does not mean gone)')
check(select(5,Style.Pose(plan,0.3,true,0.2))==false and select(5,Style.Pose(plan,0.27,true,0.2))==true,'reduced: a retired popup is gone 0.08 s after')
local rx,_,rs,ra=Style.Pose(plan,0.3,true)
check(ra==1 and rx==14 and rs==1,'reduced: opaque, on its side, full size at 0.3 s')
local _,ryEnd=Style.Pose(plan,0.7,true)
check(near(plan.StartY-ryEnd,72),'reduced: rises 72 px ('..(plan.StartY-ryEnd)..')')
check(select(5,Style.Pose(plan,0.7,true))==false and select(5,Style.Pose(plan,0.69,true))==true,'reduced: gone at 0.7 s')
local rsSame=true;for i=0,70 do if select(3,Style.Pose(plan,i/100,true))~=1 then rsSame=false end end
check(rsSame,'reduced: the size never changes (no overshoot)')
local ry={};for i=0,70 do ry[i]=select(2,Style.Pose(plan,i/100,true))end
local monotone=true;for i=1,70 do if ry[i]>ry[i-1]+1e-9 then monotone=false end end
check(monotone,'reduced: only rises (a fade-up)')
local bag2={};local p1,p2,p3=Style.Plan(lcg(1),bag2),Style.Plan(lcg(2),bag2),Style.Plan(lcg(3),bag2)
check(p1.ReducedX==-p2.ReducedX and p1.ReducedX~=0 and p3.ReducedX==p1.ReducedX,'reduced: the sides alternate')
local _,_,_,raRet=Style.Pose(plan,0.3,true,0.25);check(near(raRet,1-0.05/Style.RetireFade),'reduced: retiring fades too')

-- 6. caps per tier ------------------------------------------------------------------------------------------------------------------------------------------
check(Style.Cap(3,true,false)==8 and Style.Cap(3,false,false)==3,'caps tier 3: own 8 / others 3')
-- R154 (owner: "fix the glitchyness"): own popups hold 8 at EVERY tier (R151: 8 / 6 / 4). The stream is 10 a second and a popup lives 0.65 s, so 7 are alive at once: a cap of 6 or 4 cut every popup short
-- and faded it out in 0.08 s while it was still flying (test_popups154.luau measures it on the real client).
check(Style.Cap(2,true,false)==8 and Style.Cap(2,false,false)==2,'caps tier 2 (phones): own 8 / others 2 (R154: own was 6)')
check(Style.Cap(1,true,false)==8 and Style.Cap(1,false,false)==1,'caps tier 1 (low / FastMode): own 8 / others 1 (R154: own was 4)')
check(Style.Cap(9,true,false)==8 and Style.Cap(-4,true,false)==8 and Style.Cap(nil,true,false)==8 and Style.Cap(0/0,true,false)==8 and Style.Cap('x',true,false)==8,'caps: tiers out of range or not numbers clamp to 1..3 (nothing bigger than the top tier)')
check(Style.Cap(2.9,true,false)==8 and Style.Cap(1.9,false,false)==1 and Style.Cap(2.9,false,false)==2,'caps: a fractional tier rounds down')
for tier=1,3 do check(Style.Cap(tier,true,false)>=math.ceil(Style.Life/Style.Cadence.MinInterval)+1,'R154: tier '..tier..': the own cap ('..Style.Cap(tier,true,false)..') is above what the 10 a second stream keeps alive ('..math.ceil(Style.Life/Style.Cadence.MinInterval)..'), so the cap never cuts the normal stream short')end
check(Style.Cap(3,true,true)==4 and Style.Cap(3,false,true)==1 and Style.Cap(1,true,true)==4,'caps: Reduced Motion own 4 / others 1 at any tier')
check(Style.Cap(2,true,false)<=Style.Cap(3,true,false) and Style.Cap(1,true,false)<=Style.Cap(2,true,false) and Style.Cap(1,false,false)<=Style.Cap(2,false,false),'fewer popups on lower tiers')
check(Style.MaxDistance==100,'other players only within 100 studs (as before)')

-- 7. units --------------------------------------------------------------------------------------------------------------------------------------------------
check(Style.Unit(1080)==1 and Style.Unit(nil)==1,'unit 1 at 1080 p')
check(Style.Unit(390)==0.8 and Style.Unit(2160)==1.35 and Style.Unit(0/0)==1 and Style.Unit(math.huge)==1,'unit clamps (phone .8, 4k 1.35, bad value 1)')
check(near(Style.Unit(1296),1.2),'unit follows the screen height in between')

-- 8. splitting an award: the sum is exact, every share at least 1 -------------------------------------------------------------------------------------
for _,amount in ipairs({1,2,3,7,99,4200,123457,999999999})do
 for shares=1,12 do
  local parts=Style.Split(amount,shares);local sum,minPart=0,math.huge
  for _,v in ipairs(parts)do sum+=v;minPart=math.min(minPart,v)end
  check(sum==amount and #parts==math.min(shares,amount) and minPart>=1,'split '..amount..' in '..shares..' keeps the sum, no share below 1')
 end
end
check(Style.Split(5,2)[1]==3 and Style.Split(5,2)[2]==2,'the extra points go to the first shares')
check(Style.Cadence.SplitTo==2,'the owner chose "proposed + split": 2 popups per tick by default')
check(Style.SplitFor(true,false)==2,'the local player at full motion: 2 shares per tick (10 a second at the 1/5 s tick, the clip\'s 10)')
check(Style.SplitFor(false,false)==1 and Style.SplitFor(true,true)==1 and Style.SplitFor(false,true)==1,'other players and Reduced Motion are not split')
do local keep=Style.Cadence.SplitTo
 Style.Cadence.SplitTo=nil;check(Style.SplitFor(true,false)==1,'SplitTo nil = off')
 Style.Cadence.SplitTo=0/0;check(Style.SplitFor(true,false)==1,'SplitTo NaN = off')
 Style.Cadence.SplitTo=9;check(Style.SplitFor(true,false)==4,'SplitTo is capped at 4')
 Style.Cadence.SplitTo=keep end
check(Style.Shares(4200,1,2)==2 and Style.Shares(4200,1,1)==1,'shares: one tick, split 2 -> 2; not split -> 1')
check(Style.Shares(1,1,2)==1 and Style.Shares(2,1,2)==2 and Style.Shares(1,5,2)==1 and Style.Shares(3,5,2)==3,'shares: never more than the points (each share is at least 1)')
check(Style.Shares(4200,3,2)==6 and Style.Shares(4200,10,2)==12 and Style.Shares(4200,10,1)==10,'shares: ticks x split, at most 12 (a lag burst of 10 ticks)')
check(Style.Shares(4200,99,4)==12 and Style.Shares(4200,0,2)==2 and Style.Shares(4200,-3,2)==2,'shares: ticks are clamped to 1..10')
check(Style.Shares(0,1,2)==0 and Style.Shares(0.5,1,2)==0 and Style.Shares(-1,1,2)==0 and Style.Shares(0/0,1,2)==0 and Style.Shares('x',1,2)==0 and Style.Shares(nil,1,2)==0,'shares: nothing below 1 point')
check(Style.Shares(4200,0/0,0/0)==1 and Style.Shares(4200,'a','b')==1 and Style.Shares(4200,math.huge,math.huge)==1,'shares: bad ticks / split count as 1')
-- R151 treadmill polish: the server's step is 1/5 s (Config.TrainingInterval, was 1/6): 10 a second, 2 shares per 1/5 s tick spaced 1/10 s
check(near(Style.Spacing(1/5,2,2),1/10),'spacing: two shares share one 1/5 s tick (1/10 s apart)')
check(near(Style.Spacing(1/5,1,1),1/5),'spacing: one popup per tick, a tick apart')
check(near(Style.Spacing(1/5,2,12),1/12) and near(Style.Spacing(1/5,2,20),1/20),'spacing: the whole burst fits in one second')
check(near(Style.Spacing(1/6,2,2),1/12),'spacing: an older server\'s 1/6 s tick still splits evenly (1/12 s)')
check(near(Style.Spacing(0,2,2),0.05) and near(Style.Spacing(9,1,1),1) and near(Style.Spacing(nil,2,2),1/10) and near(Style.Spacing(0/0,2,2),1/10),'spacing: the interval is clamped to 0.1 .. 1 s, a bad one is the default 1/5 s')
do -- 5 ticks a second x 2 shares: a popup every 1/10 s for the whole run (the reference clip's 10 a second)
 local starts={};for tick=0,4 do for j=0,1 do starts[#starts+1]=tick/5+j*Style.Spacing(1/5,2,2)end end
 local even=true;for i=2,#starts do if not near(starts[i]-starts[i-1],1/10,1e-9)then even=false end end
 check(even and #starts==10,'a steady run: a popup every 1/10 s, 10 in the first second')
 local alive=0;for i=1,#starts do if 1.0-starts[i]<Style.Life then alive+=1 end end
 check(alive==7 or alive==6,'a steady run keeps about 6.5 alive at once, under the tier-3 cap of 8 ('..alive..')')
end

-- 9. the text of an amount: unchanged from the R114 formatGain ----------------------------------------------------------------------------------------
local function oldFormatGain(amount)
 for _,unit in ipairs({{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}})do
  if amount>=unit[1]then return (string.format('%.1f',amount/unit[1]):gsub('%.0$',''))..unit[2]end
 end
 return string.format('%.0f',amount)
end
-- R151 treadmill polish (owner: "for numnbers obvere 1000 it willl be read as 1k"): the old text everywhere EXCEPT where it read "1000" / "1000K"
-- / "1000M" / "1000B" (the unit is now picked after rounding) or "0" for a positive amount below .5.
local sameText=true
for _,v in ipairs({1,9,10,99,100,999,1000,1049,1050,1500,2100,3500,4200,12000,99999,100000,999949,1e6,1.25e6,3.5e9,7e12,123456789012345})do
 if Style.FormatGain(v)~=oldFormatGain(v)then sameText=false;print('differs at '..v)end
end
check(sameText,'FormatGain gives the same text as the formatGain of SpeedGainPopup before R151 away from the unit boundaries')
check(Style.FormatGain(3500)=='3.5K' and Style.FormatGain(4200)=='4.2K' and Style.FormatGain(2100)=='2.1K' and Style.FormatGain(12000)=='12K' and Style.FormatGain(999)=='999','FormatGain: 3.5K, 4.2K, 12K, 999')
do -- the boundaries: never "1000" of a unit, never "+0"
 local want={[999.4]='999',[999.5]='1K',[999.6]='1K',[999.99]='1K',[1000]='1K',[999949]='999.9K',[999950]='1M',[999999]='1M',[1e6]='1M',
  [999949999]='999.9M',[999950000]='1B',[999950001]='1B',[999999999]='1B',[1e9]='1B',[999950000000]='1T',[999999999999]='1T',[1e12]='1T',[2.5e15]='2500T',
  [.4]='1',[.01]='1',[1]='1',[17]='17',[20]='20',[65]='65',[335]='335',[2000]='2K',[10000]='10K',[65000]='65K',[500000]='500K'}
 local bad={}
 for v,text in pairs(want)do if Style.FormatGain(v)~=text then bad[#bad+1]=v..' -> '..Style.FormatGain(v)..' (want '..text..')'end end
 table.sort(bad);check(#bad==0,'FormatGain boundaries (999.6 -> 1K, 999,950 -> 1M, 999,950,000 -> 1B ..., a positive amount never "0"): '..table.concat(bad,'; '))
 local thousand=0
 for e=3,14 do for _,k in ipairs({.99949,.9995,.99951,.99999,1})do local t=Style.FormatGain(10^e*k);if t:match('^1000[KMBT]?$')and not t:match('T$')then thousand+=1;print('reads 1000: '..10^e*k..' -> '..t)end end end
 check(thousand==0,'FormatGain: no amount reads "1000" of a unit')
 check(Style.FormatGain(0)=='0'and Style.FormatGain(-3)=='-3','FormatGain: zero and negatives (never shown: the client only shows awards of 1 or more) stay as they were')
end

-- 10. our look is unchanged ----------------------------------------------------------------------------------------------------------------------------------
local C=Style.Colors
check(C.Text[1]==125 and C.Text[2]==248 and C.Text[3]==255,'amount colour as before (125,248,255)')
check(C.TextStroke[1]==17 and C.TextStroke[2]==26 and C.TextStroke[3]==42,'outline colour as before (17,26,42)')
check(C.Icon[1]==255 and C.Icon[2]==222 and C.Icon[3]==66,'bolt colour as before (255,222,66)')
check(C.LegacyStroke[1]==0 and C.LegacyStroke[2]==0 and C.LegacyStroke[3]==0,'legacy TextStroke colour as before (black)')
check(Style.Font=='FredokaOne' and Style.Icon=='\u{26A1}','font FredokaOne and the bolt as before')
check(Style.StrokeThickness==6,'R158: the outline is 6 px on the 53 px text (R154: 4 on 35; R153: 5 on 44; R151: 2.5 on 22)')
-- the numbers of the proposal the owner approved
check(Style.Pop.From==0.45 and Style.Pop.Time==0.28 and Style.Fling.Time==0.40 and Style.Fling.Power==3 and Style.Fade.Start==0.5 and Style.Fade.Length==0.15,'the approved pop / fling / fade numbers')
check(Style.Fling.Radius[1]==44 and Style.Fling.Radius[2]==104 and Style.Fling.HalfAngle==75 and Style.Fling.Slots==7,'the approved fan: +-75 degrees in 7 slots, 44..104 px')
-- R153 (owner: "numbers should also be bigger", then "2x bigger") made every size 2x its R151 value; R154 (owner: "reduce the size of the speed notifier number by 20%") took 20% off that: 1.6x R151, to whole pixels.
-- R158 (owner: "increase the size of the speed popups as they are too small right now", on purpose): 1.5x R154's = 2.4x R151's, to whole pixels: text 35 -> 53, bolt 32 -> 48, box 240 x 58 -> 360 x 86,
-- bolt box 38 -> 58, gap 3 -> 5, outline 4 -> 6.
-- The tilts (degrees) are not sizes. test_popups153.luau (docs/proposals/R153/tests) has the fan, the screens and the pile-up.
check(Style.Size.Text==53 and Style.Size.Icon==48 and Style.Size.Box[1]==360 and Style.Size.Box[2]==86 and Style.Size.IconBox==58 and Style.Size.Gap==5,'R158: the sizes are 1.5x R154\'s 35 / 32 / 240 x 58 / 38 / 3: text 53, bolt 48, box 360 x 86, bolt box 58, gap 5')
check(math.abs(Style.Size.Text-22*2.4)<=.5 and math.abs(Style.Size.Icon-20*2.4)<=.5 and math.abs(Style.Size.Box[1]-150*2.4)<=.5 and math.abs(Style.Size.Box[2]-36*2.4)<=.5 and math.abs(Style.Size.IconBox-24*2.4)<=.5 and math.abs(Style.Size.Gap-2*2.4)<=.5,'R158: ... which is 2.4x the R151 sizes, to the nearest pixel')
check(math.abs(Style.Size.Text/35-1.5)<=.02 and math.abs(Style.Size.Icon/32-1.5)<=.001 and math.abs(Style.Size.Box[1]/240-1.5)<=.001 and math.abs(Style.Size.Box[2]/58-1.5)<=.02 and math.abs(Style.Size.IconBox/38-1.5)<=.03 and math.abs(Style.StrokeThickness/4-1.5)<=.001,'R158: ... and within 3% of 1.5x R154 (text 1.514, bolt 1.5, box 1.5 x 1.483, bolt box 1.526, outline 1.5; the gap 3 -> 5 is a pixel)')
check(Style.Size.IconTilt==14 and Style.Size.TextTilt==3,'(the random tilts are the same degrees)')

print(string.format('test_speed_popups_style: %d checks, %d failed',checks,fails))
if fails>0 then error('test_speed_popups_style failed',0)end
