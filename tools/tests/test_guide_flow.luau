local G=require('./new_Guide');local B=G.Bits
local fails=0;local function check(c,m)if not c then fails+=1;print('FAIL',m)end end
-- Brand-new player (PlayerDataService creates Mask=0, Done=false).
local s={Version=1,Mask=0,Done=false}
check(G.Step(s)==1,'new -> step 1')
check(G.Event(s,'Pack'),'pack event');check(G.Step(s)==3,'-> open step 3')
check(G.Event(s,'Seed'),'seed event');check(G.Step(s)==4,'-> plant step 4')
check(G.Event(s,'Plant'),'plant event');check(G.Step(s)==5,'-> tips step 5 (no waiting to grow)')
check(not G.Action(s,'Replay')==false,'replay allowed')
s={Version=1,Mask=bit32.bor(B.Pack,B.Seed,B.Plant),Done=false}
check(G.Action(s,'TreadmillInfo')and s.Done and G.Step(s)==0,'tips finish the tutorial')
-- Harvest/Sell/Cash no longer hold it open, and never reopen a finished tutorial.
s={Version=1,Mask=bit32.bor(B.Pack,B.Seed,B.Plant),Done=false};G.Event(s,'Harvest');check(G.Step(s)==5,'harvest event keeps tips step')
s={Version=1,Mask=255,Done=true};check(G.Step(s)==0 and not G.Event(s,'Pack'),'finished stays finished')
-- Old saves partway through the long tutorial land on the right new step.
s={Version=1,Mask=bit32.bor(1,B.Pack,B.Seed,B.Plant,B.Harvest),Done=false};check(G.Step(s)==5,'old mid-harvest save -> tips')
s={Version=1,Mask=bit32.bor(1,B.Pack),Done=false};check(G.Step(s)==3,'old save after steal -> open')
-- TreadmillInfo only works on the tips step; Skip always ends it; Replay restarts.
s={Version=1,Mask=1,Done=false};check(not G.Action(s,'TreadmillInfo')and G.Step(s)==1,'tips action ignored early')
check(G.Action(s,'Skip')and G.Step(s)==0,'skip ends');check(G.Action(s,'Replay')and G.Step(s)==1,'replay restarts')
check(G.Read(nil).Mask==1 and G.Read({Version=1,Mask=300,Done=false})==nil,'read validation unchanged')
check(#G.Steps==5 and G.StepCount==5 and G.Steps[5].Seconds==#G.Tips*G.TipSeconds,'5 steps, tips timing')
for _,d in ipairs({'Mouse','Touch','Gamepad'})do for i,st in ipairs(G.Steps)do for _,t in ipairs({st.Text,st.Equipped})do
 local f=G.Format(t,d,'Kid');check(not f:find('{',1,true),'placeholder left: '..f)
 local words=0;for _ in G.Plain(f):gmatch('%S+')do words+=1 end;check(words<=14,('%s step %d is %d words'):format(d,i,words))
end end end
for _,t in ipairs(G.Tips)do local w=0;for _ in t:gmatch('%S+')do w+=1 end;check(w<=10,'tip too long: '..t)end
print(G.Format(G.Steps[1].Text,'Touch','Kid'));print(G.Format(G.Steps[3].Text,'Mouse','Kid'))
print(fails==0 and'FLOW OK'or('FAILURES '..fails))
