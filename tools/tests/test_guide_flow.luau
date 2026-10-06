local G=require('./new_Guide');local B=G.Bits
local fails=0;local function check(c,m)if not c then fails+=1;print('FAIL',m)end end
-- Saved progress: the same state machine as R111-R139 (saves made before R152 land on the same step).
-- Brand-new player (PlayerDataService creates Mask=0, Done=false).
local s={Version=1,Mask=0,Done=false}
check(G.Step(s)==1,'new -> step 1')
check(G.Event(s,'Pack'),'pack event');check(G.Step(s)==3,'-> open step 3')
check(G.Event(s,'Seed'),'seed event');check(G.Step(s)==4,'-> plant step 4')
check(G.Event(s,'Plant'),'plant event');check(G.Step(s)==5,'-> treadmill step 5 (no waiting to grow)')
check(not G.Event(s,'Train')and G.Step(s)==5,'the server\'s Train event does not end it (the client sends TreadmillInfo)')
s={Version=1,Mask=bit32.bor(B.Pack,B.Seed,B.Plant),Done=false}
check(G.Action(s,'TreadmillInfo')and s.Done and G.Step(s)==0 and bit32.band(s.Mask,B.Train)~=0,'stepping on the treadmill finishes the tutorial')
-- Harvest/Sell/Cash no longer hold it open, and never reopen a finished tutorial.
s={Version=1,Mask=bit32.bor(B.Pack,B.Seed,B.Plant),Done=false};G.Event(s,'Harvest');check(G.Step(s)==5,'harvest event keeps step 5')
s={Version=1,Mask=255,Done=true};check(G.Step(s)==0 and not G.Event(s,'Pack'),'finished stays finished')
-- Old saves partway through land on the right step.
s={Version=1,Mask=bit32.bor(1,B.Pack,B.Seed,B.Plant,B.Harvest),Done=false};check(G.Step(s)==5,'old mid-harvest save -> step 5')
s={Version=1,Mask=bit32.bor(1,B.Pack),Done=false};check(G.Step(s)==3,'old save after steal -> open')
-- TreadmillInfo only works on step 5; Skip always ends it; Replay restarts.
s={Version=1,Mask=1,Done=false};check(not G.Action(s,'TreadmillInfo')and G.Step(s)==1,'treadmill action ignored early')
check(G.Action(s,'Skip')and G.Step(s)==0,'skip ends');check(G.Action(s,'Replay')and G.Step(s)==1,'replay restarts')
check(G.Read(nil).Mask==1 and G.Read({Version=1,Mask=300,Done=false})==nil,'read validation unchanged')
check(G.Read({Version=1,Mask=0,Done=true}).Done==true,'a returning player\'s finished save stays finished')
check(#G.Steps==5 and G.StepCount==5,'5 steps')
check(G.Steps[1].Target=='Pack'and G.Steps[2].Target=='Safety'and G.Steps[3].Target==nil and G.Steps[4].Target=='Garden'and G.Steps[5].Target=='Treadmill','targets: pack, home line, (hotbar), garden, treadmill')
check(type(G.Steps[5].Seconds)=='number'and G.Steps[5].Seconds>=20,'step 5 finishes by itself if ignored')
check(G.Steps[4].Home and G.Steps[5].Home and not G.Steps[1].Home,'BASE is taught only for the steps at your base')
check(G.TravelTrack.Button=='TrackButton'and G.TravelBase.Button=='BaseButton','TRACK / BASE looks ring their buttons')
-- R152: nothing to click through.
check(G.Welcome==nil and G.Tips==nil and G.TipSeconds==nil,'no welcome page, no tip slides')
-- Every look: an icon, at most 4 + 3 words (6 together), the device key, no placeholder left, in the owner's words.
local looks={}
for i,st in ipairs(G.Steps)do looks[#looks+1]={'step '..i,st.Title,st.Chip,st.Icon};if st.EquippedTitle then looks[#looks+1]={'step '..i..' (in hand)',st.EquippedTitle,st.EquippedChip,st.Icon}end end
for _,k in ipairs({'TravelTrack','TravelBase','PickSeed','Waiting','Nice','Finished'})do local l=G[k];looks[#looks+1]={k,l.Title,l.Chip,l.Icon}end
looks[#looks+1]={'FinishedAgain',G.Finished.Title,G.FinishedAgain,G.Finished.Icon}
-- Every word on screen is one of these (a typo fails the test). Owner's voice: "grab a pack", "bring it back to ur base", "u got this".
local vocab={}
for w in ([[grab a pack run home to ur base open it keep tapping clicking pressing plant the dirt seed go track tap click select get
 faster hop on packs coming hang tight nice u got this free have fun hold forest check bag]]):gmatch('%a+')do vocab[w]=true end
local words={}
for _,d in ipairs({'Mouse','Touch','Gamepad'})do for _,l in ipairs(looks)do
 local title=G.Format(l[2],d,'Alex');local label=l[3]and G.Format(l[3].Label or'',d,'Alex')or'';local key=l[3]and l[3].Key and G.Plain(G.Format(l[3].Key,d,'Alex'))
 for _,t in ipairs({title,label,key or''})do check(not t:find('{',1,true),('%s %s: placeholder left: %s'):format(d,l[1],t))end
 local tw,cw=G.Words(title),G.Words(label)
 check(tw>=1 and tw<=G.MaxTitleWords,('%s %s: title "%s" is %d words'):format(d,l[1],G.Plain(title),tw))
 check(cw<=G.MaxChipWords and tw+cw<=G.MaxWords,('%s %s: "%s / %s" is %d words'):format(d,l[1],G.Plain(title),G.Plain(label),tw+cw))
 check(type(l[4])=='string'and l[4]~='',d..' '..l[1]..': has an icon')
 check(key==nil or utf8.len(key)<=5,('%s %s: the key cap is short (%s)'):format(d,l[1],tostring(key)))
 for w in(G.Plain(title)..' '..G.Plain(label)):lower():gsub('alex',''):gmatch('%a+')do if not vocab[w]then words[#words+1]=w end end
 local plain=(G.Plain(title)..' '..G.Plain(label)):lower()
 check(not plain:find('your',1,true)and not plain:find('follow',1,true)and not plain:find('arrow',1,true),d..' '..l[1]..': says it, does not explain it ('..plain..')')
end end
check(#words==0,'every word is a known, correctly spelled word: '..table.concat(words,', '))
for w in G.StarterPack.Notice:lower():gmatch('%a+')do check(vocab[w],'notice word: '..w)end
-- The device keys: E / 👆 / X to grab; CLICK / TAP / R2 to open; TRACK and BASE as the buttons look.
local function key(look,d)return G.Plain(G.Format(look.Chip.Key,d,'x'))end
check(key(G.Steps[1],'Mouse')=='E'and key(G.Steps[1],'Touch')=='👆'and key(G.Steps[1],'Gamepad')=='X','grab: E / 👆 / X')
check(G.Format(G.Steps[3].EquippedChip.Key,'Mouse')=='CLICK'and G.Format(G.Steps[3].EquippedChip.Key,'Touch')=='TAP'and G.Format(G.Steps[3].EquippedChip.Key,'Gamepad')=='R2','open: CLICK / TAP / R2')
check(G.TravelTrack.Chip.KeyStyle=='Track'and G.TravelBase.Chip.KeyStyle=='Base','TRACK / BASE key caps in their button colours')
-- R139: nothing a player sees mentions luck.
local function scan(t,seen)seen=seen or{};if seen[t]then return end;seen[t]=true
 for k,v in pairs(t)do if type(v)=='string'then local l=v:lower();check(not l:find('luck',1,true)and not l:find('2x',1,true),'no luck words: '..tostring(k)..' = '..v)elseif type(v)=='table'then scan(v,seen)end end end
scan(G)
print(G.Plain(G.Format(G.Steps[1].Title,'Touch','Kid'))..' '..G.Plain(G.Format(G.Steps[1].Chip.Key,'Touch','Kid'))..' '..G.Format(G.Steps[1].Chip.Label,'Touch','Kid'))
print(fails==0 and'FLOW OK'or('FAILURES '..fails))
