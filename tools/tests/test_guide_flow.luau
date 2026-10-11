local G=require('./new_Guide');local B=G.Bits
local fails=0;local function check(c,m)if not c then fails+=1;print('FAIL',m)end end
-- R158e: the saved progress keeps R111's {Version=1, Mask, Done} and bits; the published step is the first one the bits have not done (1 / 4 / 6 / 7 / 9 / 10).
local s={Version=1,Mask=0,Done=false}
check(G.Step(s)==1,'new -> step 1 (the client shows 1, 2 or 3 by where you are)')
check(G.Event(s,'Pack'),'pack event');check(G.Step(s)==4,'-> open, step 4')
check(G.Event(s,'Seed'),'seed event');check(G.Step(s)==6,'-> plant, step 6 (5 = BASE while away from home)')
check(G.Event(s,'Plant'),'plant event');check(G.Step(s)==7,'-> grow / harvest, step 7 (8 once the fruit is ripe)')
check(G.Event(s,'Harvest'),'harvest event');check(G.Step(s)==9,'-> sell, step 9')
check(G.Event(s,'Sell'),'sell event');check(G.Step(s)==10,'-> the treadmill, step 10')
check(G.Event(s,'Cash')and G.Step(s)==10,'cash (after a sale) is recorded, the step stays')
check(not G.Event(s,'Train')and G.Step(s)==10,'the server\'s Train event does not end it (the client sends TreadmillInfo)')
check(G.Action(s,'TreadmillInfo')and s.Done and G.Step(s)==0 and bit32.band(s.Mask,B.Train)~=0,'stepping on the treadmill finishes the tutorial')
-- Events count only in their turn: opening, planting, picking or selling before its step is just playing.
s={Version=1,Mask=1,Done=false}
check(not G.Event(s,'Seed')and not G.Event(s,'Plant')and not G.Event(s,'Harvest')and not G.Event(s,'Sell')and not G.Event(s,'Cash')and s.Mask==1,'before the steal: an open / plant / harvest / sale changes nothing')
G.Event(s,'Pack');check(not G.Event(s,'Plant')and not G.Event(s,'Harvest')and G.Step(s)==4,'after the steal: planting before opening changes nothing')
s={Version=1,Mask=255,Done=true};check(G.Step(s)==0 and not G.Event(s,'Pack'),'finished stays finished')
-- Old saves (R111 - R158d) land on the right step of the new tutorial.
check(G.Step({Version=1,Mask=1,Done=false})==1,'old save, nothing done -> 1')
check(G.Step({Version=1,Mask=bit32.bor(1,B.Pack),Done=false})==4,'old save after the steal -> open (4)')
check(G.Step({Version=1,Mask=bit32.bor(1,B.Pack,B.Seed),Done=false})==6,'old save after the open -> plant (6)')
check(G.Step({Version=1,Mask=bit32.bor(1,B.Pack,B.Seed,B.Plant),Done=false})==7,'old save on the R152 treadmill step (planted) -> grow / harvest (7)')
check(G.Step({Version=1,Mask=bit32.bor(1,B.Pack,B.Seed,B.Plant,B.Harvest),Done=false})==9,'old save that had harvested -> sell (9)')
check(G.Step({Version=1,Mask=bit32.bor(1,B.Pack,B.Seed,B.Plant,B.Harvest,B.Sell,B.Cash),Done=false})==10,'old save that had sold -> treadmill (10)')
check(G.Step({Version=1,Mask=bit32.bor(1,B.Harvest,B.Sell),Done=false})==1,'old R111 save with harvest / sell bits but no steal -> 1')
check(G.Step({Version=1,Mask=0,Done=true})==0,'a finished save stays finished')
-- TreadmillInfo only on step 10; R158g: there is no Skip (the action does nothing); Replay is plain data (TutorialProgress refuses it, R158c).
s={Version=1,Mask=1,Done=false};check(not G.Action(s,'TreadmillInfo')and G.Step(s)==1,'treadmill action ignored early')
s={Version=1,Mask=bit32.bor(1,B.Pack,B.Seed,B.Plant),Done=false};check(not G.Action(s,'TreadmillInfo')and G.Step(s)==7,'... and on step 7 (harvest and sell come first)')
check(not G.Action(s,'Skip')and G.Step(s)==7 and not s.Done,'no skip: the action does nothing')
-- Read: the same validation; the two new optional fields are kept when clean, dropped (never refused) when not.
check(G.Read(nil).Mask==1 and G.Read({Version=1,Mask=300,Done=false})==nil and G.Read({Version=2,Mask=1,Done=false})==nil,'read validation unchanged')
check(G.Read({Version=1,Mask=0,Done=true}).Done==true,'a returning player\'s finished save stays finished')
local r=G.Read({Version=1,Mask=7,Done=false,Fast=true,FastCrop='guid-1'})
check(r.Fast==true and r.FastCrop=='guid-1'and r.Mask==7,'Fast / FastCrop are read back')
r=G.Read({Version=1,Mask=7,Done=false,Fast='yes',FastCrop=string.rep('x',101)})
check(r and r.Fast==nil and r.FastCrop==nil,'odd optional fields are dropped, the save still loads')
r=G.Read({Version=1,Mask=7,Done=false});check(r.Fast==nil,'an old save has none of them')
-- Ten steps, one look each moment (Resolve).
check(#G.Steps==10 and G.StepCount==10 and G.Progress==nil,'10 steps (no step row)')
check(G.Steps[1].Seconds==G.IntroSeconds and G.IntroSeconds>=3 and G.IntroSeconds<=6,'the spawn arrow shows a few seconds')
check(type(G.Steps[10].Seconds)=='number'and G.Steps[10].Seconds>=8 and G.Steps[10].Seconds<=15,'the treadmill arrow shows about 10 s at most')
check(type(G.BonusSeconds)=='number'and G.BonusSeconds>=3 and G.BonusSeconds<=8,'then the BONUS ROLL arrow shows a few seconds')
check(type(G.BonusRollSeconds)=='number'and G.BonusRollSeconds>=12 and G.BonusRollSeconds<=20 and G.BonusGiftRolls==1,'R158h: with the free roll ready the arrow waits ~15 s for the press; one free roll')
check(G.Read({Version=1,Mask=255,Done=false,Bonus=true}).Bonus==true and G.Read({Version=1,Mask=255,Done=false,Bonus='x'}).Bonus==nil and G.Read(nil).Bonus==nil,'R158h: the saved Bonus flag is read back (true only)')
check(G.FirstFruitSeconds==10,'the first fruit: 10 s')
local function R(c)return table.pack(G.Resolve(c))end
local walk={
 {{Stage=1,OnTrack=false},1,'Spawn'},{{Stage=1,OnTrack=false,IntroDone=true},2,'Track'},{{Stage=1,OnTrack=true,IntroDone=true},3,'Grab'},
 {{Stage=1,OnTrack=true,Waiting=true},3,'Waiting'},{{Stage=1,Carrying=true},3,'Carry'},{{Stage=1,OnTrack=nil,IntroDone=true},2,'Track'},
 {{Stage=4},4,'PickPack'},{{Stage=4,PackInHand=true},4,'Open'},
 {{Stage=6,Home=false},5,'Base'},{{Stage=6,Home=true},6,'PickSeed'},{{Stage=6,Home=true,SeedInHand=true},6,'Plant'},
 {{Stage=7,Home=true},7,'Grow'},{{Stage=7,Home=true,Ripe=true},8,'Harvest'},{{Stage=7,Home=false},7,'Base'},
 {{Stage=9},9,'Market'},{{Stage=9,Menu='Buy'},9,'SellTab'},{{Stage=9,Menu='Sell'},9,'SellAll'},
 {{Stage=10,Home=true},10,'Treadmill'},{{Stage=10,Home=false},10,'Base'},{{Stage=10,Home=true,Bonus=true},10,'Bonus'},{{Stage=10,Home=false,Bonus=true},10,'Bonus'},{{Stage=0},0,nil},
}
for _,w in ipairs(walk)do local got=R(w[1]);check(got[1]==w[2]and got[2]==w[3],('resolve %s -> %s %s (got %s %s)'):format(w[3]or'done',w[2],tostring(w[3]),tostring(got[1]),tostring(got[2])))end
local seen={};for _,w in ipairs(walk)do if w[3]then seen[G.Looks[w[3]].Step]=true end end
for i=1,10 do check(seen[i],'step '..i..' has a look')end
-- R158g: a look is only pointers. It names what it points at (a world goal, a screen button, a hotbar slot, the clicking hand) and nothing else: no icon, no picture row, no key, no
-- bubble, no trail. One purpose each: a look never points a world arrow AND a button / slot / clicking hand at the same moment (two arrows saying the same thing), and the pressing hand
-- and the ring timer hang on the world goal.
local ALLOWED={Key=true,Step=true,World=true,Button=true,Slot=true,Hand=true,Timer=true,Click=true,NoPress=true}
for key,l in pairs(G.Looks)do
 for field in pairs(l)do check(ALLOWED[field],key..': no '..field..' (a look is only pointers)')end
 check(l.Key==key and type(l.Step)=='number','look '..key..' knows its name and step')
 local purposes=0;for _,f in ipairs({'World','Button','Slot','Click'})do if l[f]then purposes+=1 end end
 check(purposes<=1,key..': one purpose per look ('..purposes..')')
 check((not l.Hand and not l.Timer)or l.World,key..': a hand or a timer is on a world goal')
end
for _,gone in ipairs({'Card','Obstacles','Font','HotbarDetail','Progress','Nice','Finished','FinishedAgain','Devices','Act','Clock','Format','NiceSeconds','FinishSeconds'})do check(G[gone]==nil,'the card is gone: no G.'..gone)end
for _,l in pairs(G.Steps)do check(l.Icon==nil,'no step icon')end
check(G.Wordless('10')and G.Wordless('👆')and not G.Wordless('NICE!!')and not G.Wordless('E')and not G.Wordless('R2')and G.Wordless('R2',true)and not G.Wordless('GO',true),'Wordless: numbers / icons yes, words no, a key glyph only in a key cap (R2)')
check(G.ClickHint.Mouse.Hand=='🖱️'and G.ClickHint.Touch.Hand=='👆'and G.ClickHint.Gamepad.Key=='R2'and G.ClickHint.Mouse.Word==nil,'the clicking hand has no word')
for dev,h in pairs(G.ClickHint)do check(G.Wordless(h.Hand)and(h.Key==nil or G.Wordless(h.Key,true)),dev..': the clicking hand is wordless')end
-- What points where.
check(G.Looks.Spawn.World=='Pack'and G.Looks.Track.Button=='TrackButton'and G.Looks.Track.World==nil,'1 / 2: an arrow at the pack, then just TRACK')
check(G.Looks.Grab.World=='Pack'and G.Looks.Carry.World=='Safety','3: the pack, then home')
check(G.Looks.PickPack.Slot=='Pack'and G.Looks.Open.Click,'4: the slot, then the clicking hand')
check(G.Looks.Base.Button=='BaseButton'and G.Looks.Plant.Hand and G.Looks.Plant.World=='Garden'and G.Looks.PickSeed.Slot=='Seed','5 / 6: BASE, the dirt')
check(G.Looks.Grow.Timer and G.Looks.Grow.World=='Crop'and G.Looks.Harvest.World=='Crop'and G.Looks.Market.World=='Sell'and G.Looks.SellTab.Button=='SellMode'and G.Looks.SellAll.Button=='SellAll','7 - 9: timer, harvest, market')
check(G.Looks.Treadmill.World=='Treadmill'and G.Looks.Bonus.Button=='BonusRollButton'and G.Looks.Bonus.NoPress and not G.Looks.Treadmill.Button,'10: the treadmill, then BONUS ROLL (the arrow alone)')
check(G.Kind(1,false)=='Pack'and G.Kind(1,true)=='Safety'and G.Kind(4)==nil and G.Kind(6)=='Garden'and G.Kind(7)=='Crop'and G.Kind(9)=='Sell'and G.Kind(10)=='Treadmill','server kinds per step')
-- The first fruit in 10 s (pure): one fruit, a whole plant, several fruit.
local now=1000000
local c={Id='a',PlantedAt=now,MatureAt=now+60,ReadyAt=now+60}
check(G.FastFruit(c,{FruitCount=1,Mode='repeat'},now)and c.MatureAt==now+10 and c.ReadyAt==now+10 and c.FruitStates==nil,'one fruit: ripe in 10 s')
c={Id='b',PlantedAt=now,MatureAt=now+86,ReadyAt=now+86};check(G.FastFruit(c,{FruitCount=1,Mode='whole'},now)and c.ReadyAt==now+10,'a whole plant: 10 s')
c={Id='c',PlantedAt=now,MatureAt=now+75,ReadyAt=now+75}
check(G.FastFruit(c,{FruitCount=3,Mode='repeat'},now)and c.MatureAt==now+10 and c.ReadyAt==now+10,'three fruit: the plant grows up in 10 s')
check(c.FruitStates['1'].ReadyAt==now+10 and c.FruitStates['1'].Cycle==0,'... fruit 1 ripe at 10 s')
check(c.FruitStates['2'].ReadyAt==now+75 and c.FruitStates['3'].ReadyAt==now+75 and c.FruitStates['2'].Cycle==1 and c.FruitStates['2'].Duration==75,'... the others in their normal time (75 s), growing from the planting')
c={Id='d',PlantedAt=now,MatureAt=now+8,ReadyAt=now+8};check(not G.FastFruit(c,{FruitCount=1},now)and c.ReadyAt==now+8,'a plant already that quick is left alone')
check(not G.FastFruit(nil,{},now)and not G.FastFruit({},{},now),'junk in: nothing')
-- R139: nothing a player sees mentions luck.
local function scan(t,seen2)seen2=seen2 or{};if seen2[t]then return end;seen2[t]=true
 for k,v in pairs(t)do if type(v)=='string'then local l=v:lower();check(not l:find('luck',1,true)and not l:find('2x',1,true),'no luck words: '..tostring(k)..' = '..v)elseif type(v)=='table'then scan(v,seen2)end end end
scan(G)
print(fails==0 and'FLOW OK'or('FAILURES '..fails))
