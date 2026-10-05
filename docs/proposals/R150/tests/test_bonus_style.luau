--!nocheck
-- R150 TreadmillBonusStyle (pure copy / state / timeline functions) and BonusGiftArt (shape builders) on the Roblox mock.
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local S=W.module('TreadmillBonusStyle');local A=W.module('BonusGiftArt');local Rules=W.module('TreadmillBonusRules')
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
-- Clock ---------------------------------------------------------------------------------------------------------
check(S.Clock(0)=='0:00' and S.Clock(59)=='0:59' and S.Clock(60)=='1:00' and S.Clock(222)=='3:42' and S.Clock(360)=='6:00','Clock formats m:ss')
check(S.Clock(372.2)=='6:13' and S.Clock(.2)=='0:01','Clock rounds up like the old countdown')
check(S.Clock(-5)=='0:00' and S.Clock(0/0)=='0:00' and S.Clock(nil)=='0:00','Clock survives negative / NaN / nil')
-- Timer ----------------------------------------------------------------------------------------------------------
local t=S.Timer(0,2,360,222)
check(t.State=='charging' and near(t.Fraction,1-222/360,1e-9) and t.Clock=='3:42' and t.Caption=='NEXT ROLL' and t.Count==0,'timer mid-way: charging, fraction, clock, caption')
check(S.Timer(0,2,360,31).State=='charging' and S.Timer(0,2,360,30).State=='almost' and S.Timer(0,2,360,30.01).State=='charging','"almost there" starts at exactly the last 30 s')
t=S.Timer(0,2,360,24)
check(t.State=='almost' and t.Caption=='ALMOST THERE!' and t.Clock=='0:24' and t.Fraction>.93,'last 30 s: almost there')
check(S.Timer(0,2,360,0).Fraction==1 and S.Timer(0,2,360,0).State=='almost' and S.Timer(0,2,360,360).Fraction==0,'fraction 0 .. 1 across the interval')
check(S.Timer(0,2,360,999).Fraction==0 and S.Timer(0,2,360,-4).Fraction==1,'left is clamped to the interval')
t=S.Timer(2,2,360,100)
check(t.State=='full' and t.Fraction==1 and t.Caption=='2 ROLLS READY!' and t.Hint=='TAP BONUS ROLL','at the cap the timer is full (paused): claim')
check(S.Timer(7,2,360,100).State=='full','more than the cap still counts as full')
t=S.Timer(1,2,360,100)
check(t.State=='charging' and t.Count==1,'one ready, the next one still charging')
t=S.Timer(nil,nil,nil,nil)
check(t.State=='charging' and t.Fraction==0 and t.Count==0,'nil inputs fall back to defaults')
check(S.Timer(0,2,360,0/0).Fraction==0,'NaN left is a full interval')
-- Button mode / lines ---------------------------------------------------------------------------------------------------
check(S.ButtonMode(0,false,false,false)=='hidden' and S.ButtonMode(1,false,false,false)=='ready' and S.ButtonMode(0,true,false,false)=='charging'
 and S.ButtonMode(2,true,false,false)=='ready','button mode: hidden / ready / charging (charging only on the treadmill)')
check(S.ButtonMode(2,true,true,false)=='hidden' and S.ButtonMode(1,false,false,true)=='hidden','the title screen and the open roll window hide the button')
local title,sub=S.ButtonLines('ready',S.Timer(1,2,360,100),false)
check(title=='BONUS ROLL' and sub=='READY!','ready lines')
title,sub=S.ButtonLines('charging',S.Timer(0,2,360,222),false)
check(sub=='NEXT 3:42','charging line counts down: '..sub)
title,sub=S.ButtonLines('charging',S.Timer(0,2,360,24),false)
check(sub=='ALMOST! 0:24','charging line, last 30 s: '..sub)
check(select(2,S.ButtonLines('ready',S.Timer(1,2,360,100),true))=='ROLLING...','busy shows ROLLING...')
local caption,clock=S.BillboardLines(S.Timer(0,2,360,222),false)
check(caption=='NEXT ROLL' and clock=='3:42','billboard normal lines')
caption,clock=S.BillboardLines(S.Timer(0,2,360,20),false)
check(caption=='ALMOST THERE!' and clock=='0:20','billboard almost lines')
caption,clock=S.BillboardLines(S.Timer(1,2,360,222),true)
check(caption:find('BONUS READY!')~=nil and clock=='OPEN IT!','billboard ready pop lines')
caption,clock=S.BillboardLines(S.Timer(2,2,360,222),false)
check(caption=='2 ROLLS READY!' and clock=='TAP BONUS ROLL','billboard at the cap')
-- Reveal ---------------------------------------------------------------------------------------------------------------
local words,prev={}
for i,name in ipairs(S.Rarities)do
 local r=S.Reveal(name)
 check(r.Known and #r.Word>=4 and #r.Word<=12 and r.Word==string.upper(r.Word),name..': a short upper-case reveal word ('..r.Word..')')
 check(not words[r.Word],name..': its own word');words[r.Word]=true
 if prev then
  check(r.Pop>prev.Pop and r.Beams>=prev.Beams and r.Alpha<prev.Alpha and r.Confetti>=prev.Confetti and r.Sparkles>prev.Sparkles and r.Speed>prev.Speed,name..': every step up is bigger (pop, beams, brighter rays, confetti, faster rays)')
 end
 prev=r
 local special=Rules.Special[name]==true
 check((r.Close=='AWESOME!')==special,name..': AWESOME! close caption only for Legendary / Mythic / Secret')
 check(r.Confetti<=40 and r.Sparkles<=16 and r.Beams<=8,name..': piece counts stay small')
end
check(S.Reveal('Common').Confetti==0 and S.Reveal('Rare').Confetti>0,'Common is calm (no confetti), Rare starts the confetti')
check(S.Reveal('Nonsense').Word==S.Reveal('Common').Word and not S.Reveal('Nonsense').Known,'an unknown rarity is revealed like Common')
check(#S.Rarities==7 and S.Rarities[5]=='Legendary','the seven rarities in order')
-- every rarity name the rules can produce has a reveal
local seen={}
for _,variant in ipairs(Rules.VariantOrder)do local name=Rules.Tier(variant);seen[name]=true;check(S.Reveal(name).Known,'rules rarity '..name..' has a reveal')end
check(next(seen)~=nil,'the rules name their rarities')
-- Spin line ------------------------------------------------------------------------------------------------------------------
local line,index=S.SpinLine(0)
check(index==1 and line==S.SpinLines[1],'spin line starts at the first line')
check(select(2,S.SpinLine(.29))==1 and select(2,S.SpinLine(.3))==2 and select(2,S.SpinLine(.62))==3 and select(2,S.SpinLine(.86))==4 and select(2,S.SpinLine(1))==4,'spin line phases change at .3 / .62 / .86')
check(select(2,S.SpinLine(-1))==1 and select(2,S.SpinLine(nil))==1 and select(2,S.SpinLine(9))==4,'spin line clamps')
local distinct={};for _,l in ipairs(S.SpinLines)do distinct[l]=true end
check(#S.SpinLines==4 and next(distinct)~=nil and S.SpinHint:find('bag')~=nil,'four playful lines and the reassurance hint')
-- LeftSeconds -------------------------------------------------------------------------------------------------------------
check(near(S.LeftSeconds(1100,nil,360,1000),100) and S.LeftSeconds(nil,200,360,1000)==200 and S.LeftSeconds(nil,nil,360,1000)==360,'left: DueAt, else saved Left, else a full interval')
check(S.LeftSeconds(900,nil,360,1000)==0 and S.LeftSeconds(5000,nil,360,1000)==360,'left is clamped to 0..interval')
-- Wiggle ----------------------------------------------------------------------------------------------------------------------
local peak=0;for i=0,70 do peak=math.max(peak,math.abs(S.Wiggle(i/100,.7,12)))end
check(peak>5 and peak<=12 and S.Wiggle(.7)==0 and S.Wiggle(-1)==0 and S.Wiggle(2)==0 and S.Wiggle(0)==0,'wiggle swings and dies out ('..peak..' deg peak)')
-- Flash --------------------------------------------------------------------------------------------------------------------------
local serverErrors={'SEED BAG FULL! Make room - your roll stays ready.','Please try again.','Please wait a moment.','No bonus roll ready yet.','YOUR DATA IS STILL LOADING',
 'Bonus packs are unavailable right now.','PACK COULD NOT BE ADDED','TRY AGAIN!',nil,''}
for i=1,10 do
 local m=serverErrors[i];local f=S.Flash(m)
 check(#f<=15 and f==string.upper(f)and f~='','Flash keeps '..tostring(m)..' short: '..f)
end
check(S.Flash('SEED BAG FULL! Make room - your roll stays ready.')=='BAG FULL!','Flash: the bag-full refusal')
check(#S.Flash('A VERY LONG UNKNOWN MESSAGE FROM SOMEWHERE')<=15,'Flash truncates unknown long text')
-- BonusGiftArt -------------------------------------------------------------------------------------------------------------------
local function valid(seq,limit)
 local keys=seq.A;if type(keys)~='table'or keys.R~=nil then return true end -- two-colour sequences are always valid
 if #keys>limit or keys[1].T~=0 or keys[#keys].T~=1 then return false end
 for i=2,#keys do if not(keys[i].T>keys[i-1].T)then return false end end
 return true
end
local holder=R.new('Frame')
local gift=A.Gift(holder,34,'Icon')
for _,part in ipairs({'Body','Lid','BandLower','BandUpper','Bow'})do check(gift.Root:FindFirstChild(part)~=nil,'gift has '..part)end
for i=0,50 do
 gift:Fill(i/50)
 check(valid(gift.Gradient.Color,20),'gift fill '..i/50 ..' builds a valid colour sequence')
end
gift:Fill(.5);local before=gift.Gradient.Color;gift:Fill(.502);check(gift.Gradient.Color==before,'a tiny change in fill does not rebuild the gradient')
gift:Fill(1);check(gift.Level==1,'full')
gift:Fill(0/0);check(gift.Level==0,'NaN fill = empty')
local bow=A.Bow(holder,56,'Bow',A.Pink)
check(bow:FindFirstChild('LoopL')and bow:FindFirstChild('LoopR')and bow:FindFirstChild('Knot'),'bow: two loops and a knot')
check(bow.LoopL.Rotation==-bow.LoopR.Rotation and bow.LoopL.Rotation~=0,'bow loops tilt towards each other')
local stripes=A.Stripes(holder,9,35,.93,2)
check(valid(stripes:FindFirstChildOfClass('UIGradient').Transparency,20),'wrapping-paper stripes stay within 20 keypoints even when asked for 9')
check(valid(A.Stripes(holder,3,35,.93,2):FindFirstChildOfClass('UIGradient').Transparency,20),'3 stripes valid')
local rays=A.Rays(holder,6,300,30,6)
check(#rays.Beams==6 and rays.Beams[1]:FindFirstChild('Core')~=nil and rays.Root.Size.X.Offset==300,'rays: 6 beams with a core')
A.TintRays(rays,R.Color3.fromRGB(255,200,0),.7)
check(rays.Beams[3].BackgroundTransparency==.7 and rays.Beams[3].Core.BackgroundTransparency<.7,'rays: the core is brighter than the beam')
check(valid(rays.Beams[1]:FindFirstChildOfClass('UIGradient').Transparency,20),'ray fade is valid')
local beamAngles={};for _,b in ipairs(rays.Beams)do beamAngles[#beamAngles+1]=b.Rotation end
check(beamAngles[1]==0 and near(beamAngles[6],150),'beams are spread over 180 degrees')
-- Shine: the stripe sweeps fully across the pane and starts / ends fully outside it. Roblox turns the stripe about its CENTRE (R150 review), so its real
-- rectangle is tested (a turned box against the pane, separating axes), on a winner card (94 x 118: a tall pane) and on the HUD button face (190 x 36: a wide one).
do
 local function paneRect(w,h)return {X=0,Y=0,W=w,H=h}end
 for _,dim in ipairs({{94,118,'a winner card'},{190,36,'the HUD button face'},{114,46,'a narrow button face'}})do
  local host=R.new('Frame');host.Size=R.UDim2.fromOffset(dim[1]+12,dim[2]+12)
  local sh=A.Shine(host,6,6,.55,9)
  local function stripeEntry()
   local list,by=UW.rects(host,dim[1]+12,dim[2]+12);return by[host.Name..'.ShinePane.Sweep'],by[host.Name..'.ShinePane']
  end
  A.SetShine(sh,.01);local e,pane=stripeEntry()
  check(e and not UW.turnedHits(e,{X=pane.RX,Y=pane.RY,W=pane.RW,H=pane.RH}),dim[3]..': at the start of the sweep the stripe is fully outside the pane')
  A.SetShine(sh,.99);e,pane=stripeEntry()
  check(e and not UW.turnedHits(e,{X=pane.RX,Y=pane.RY,W=pane.RW,H=pane.RH}),dim[3]..': at the end of the sweep the stripe is fully outside the pane')
  local crossed=0;for k=1,99 do A.SetShine(sh,k/100);e,pane=stripeEntry();if UW.turnedHits(e,{X=pane.RX,Y=pane.RY,W=pane.RW,H=pane.RH})then crossed+=1 end end
  check(crossed>=30 and crossed<=95,dim[3]..': in between it crosses the pane ('..crossed..' of 99 steps)')
  -- the middle of the sweep covers the pane's centre line
  A.SetShine(sh,.5);e,pane=stripeEntry()
  check(UW.turnedHits(e,{X=pane.RX+pane.RW/2-1,Y=pane.RY,W=2,H=pane.RH}),dim[3]..': halfway the stripe is over the middle of the pane')
  A.SetShine(sh,0);check(sh.Stripe.Visible==false,dim[3]..': u = 0 hides the stripe');A.SetShine(sh,1);check(sh.Stripe.Visible==false,dim[3]..': u = 1 hides it')
 end
end
-- Burst
local layer=R.new('Frame')
local burst=A.Burst(layer,100,100,{Count=10,Shape='Star',Size=12,Life=.8,Speed={50,100}})
check(#layer:GetChildren()==10,'burst creates exactly its count')
-- R150 review: a sparkle is ONE Frame (a spinning diamond), a confetti bit is one Frame: a Secret reveal draws 160 pieces on a single frame
local oneFrame=true;for _,piece in ipairs(layer:GetChildren())do if #piece:GetChildren()~=0 or piece.ClassName~='Frame' and piece._class~='Frame'then oneFrame=false end end
check(oneFrame and R.Instance and #layer:GetChildren()==10 and #layer:GetDescendants()==10,'a sparkle is one Frame with nothing inside it ('..#layer:GetDescendants()..' instances for 10 sparkles)')
check(layer:GetChildren()[1].Rotation==45 and layer:GetChildren()[1].Size.X.Offset==layer:GetChildren()[1].Size.Y.Offset and layer:GetChildren()[1].Size.X.Offset>=4,'a sparkle is a square turned 45 degrees: a diamond')
check(layer:GetChildren()[1].BackgroundTransparency==0,'and it starts opaque')
local done,steps=false,0
while not done and steps<200 do done=burst:Step(1/60);steps+=1 end
check(done and steps>=45 and steps<=60,'burst ends after its life ('..steps..' steps)')
do local b2=A.Burst(layer,0,0,{Count=4,Shape='Star',Size=12,Life=.8,Speed={50,100}});b2:Step(.45)
 local faded=true;for _,piece in ipairs(layer:GetChildren())do if piece.BackgroundTransparency<=0 then faded=false end end
 check(faded,'a sparkle fades out through its own Frame in the second half of its life');b2:Destroy()end
burst:Destroy();check(#layer:GetChildren()==0,'destroyed burst leaves nothing behind')
local confetti=A.Burst(layer,0,0,{Count=6,Shape='Confetti',Size=7,Life=1,Speed={100,200},Gravity=800})
check(#layer:GetChildren()==6 and layer:GetChildren()[1].Size.Y.Offset>=layer:GetChildren()[1].Size.X.Offset,'confetti bits are taller than wide')
confetti:Step(.4);confetti:Destroy();check(#layer:GetChildren()==0,'confetti destroyed')
-- Candy
local candy=A.Candy(holder,'Btn',R.Color3.fromRGB(255,152,48),'GO',{Lip=4})
check(candy:FindFirstChild('Lip')and candy.Face and candy.Face:FindFirstChild('Gloss')and candy.Face.Label.Text=='GO' and candy.BackgroundTransparency==1,'candy button: lip, face, gloss, label on a transparent hit area')
check(candy.Lip.ZIndex<candy.Face.ZIndex and candy.Face.Gloss.ZIndex<candy.Face.Label.ZIndex,'candy z-order: lip < face, gloss < label')
A.Press(candy,true);check(candy.Face.Position.Y.Offset==3,'pressed: the face sinks onto the lip')
A.Press(candy,false);check(candy.Face.Position.Y.Offset==0,'released: the face rises')
local lipBefore=candy.Lip.BackgroundColor3;A.Recolor(candy,R.Color3.fromRGB(80,90,200));check(candy.Lip.BackgroundColor3~=lipBefore,'recolour changes the lip')
local plain=A.Candy(holder,'Plain',R.Color3.fromRGB(255,152,48),'',{NoLabel=true});check(plain.Face:FindFirstChild('Label')==nil,'NoLabel leaves the face free')
local chip,label=A.Badge(holder,'Chip',20,12);check(chip:FindFirstChild('Pop')~=nil and label.Name=='Count','badge has a Pop scale and a Count label')
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
