--!nocheck
-- R151 hub displays: HubDisplayService (events, the day, the shared board, the displays' refresh, notices, owner tools) with the REAL service, board, store, rules and
-- game modules (SeedPackRules / Config / ItemWeight ...), a MemoryStore mock shared by several "servers", a fake clock per server, and a recording stand-in for the art and
-- the avatar builder (their own suites: test_hub_art, test_hub_avatar):
--  1. start: both displays built, the first day set up, the fruit of the day = HubDisplayRules.FruitForDay;
--  2. events: a real pull is ranked and shown (sign, accent, item and avatar requested once), odds = the pack's own SeedOdds; TEST packs, owner-granted players and injected
--     tests are not counted; a worse pull / fruit only moves nothing; fruit of another type ignored;
--  3. notices: text, everyone in the server, the celebration remote, the Rare minimum, the gap, no notice for another server's champion;
--  4. the day: midnight clears both boards and changes the fruit; an event right after midnight counts for the new day; boards are by day in the store;
--  5. cross-server: A writes (about 3 s later), B reads (within 45-60 s) and shows it with a pop but no notice; races between two servers; the better one wins everywhere;
--  6. polling and writes: the interval and jitter, how many requests an hour costs, writes are coalesced;
--  7. failures: MemoryStore down -> this server's own best, keeps trying with backoff, catches up; throttled; recovered;
--  8. a champion change rebuilds the item and the avatar once (a stale build is dropped, an identical record rebuilds nothing);
--  9. owner tools: bestpull / bigfruit (this server only, `share`), reset, day preview (no store traffic), status text.
local HH=require('./hub_harness');local H=HH.H;local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Rules=W.module('HubDisplayRules');local P=W.module('SeedPackRules');local Weight=W.module('ItemWeight')
local Board=H.server('HubDisplayBoard');local Store=H.server('HubDisplayStore');local Service=H.server('HubDisplayService');local Config=H.server('Config')
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local DAY=20727;local T0=DAY*86400+3600*3 -- 03:00 UTC
local list=Rules.EligibleFruits()
local todayFruit=Rules.FruitForDay(list,DAY)

-- A recording stand-in for HubDisplayArt / HubDisplayAvatar -------------------------------------------------------------------------------------------------------------
local function fakeArt()
 local A={Built={},Items={},Avatars={},SignWrites=0,Tints={},ItemBuilds={}}
 function A.BuildFrame(parent,kind,layout,top)
  local m=R.new('Model');m.Name=kind;m.Parent=parent
  local d={Kind=kind,Model=m,FeetAt=CF(0,0,0),ItemAt=CF(0,0,0),Labels={}}
  A.Built[kind]=d;return d
 end
 function A.SetSign(d,text)A.SignWrites+=1;d.Text=text;d.Model:SetAttribute('State',text.State)end
 function A.Tint(d,accent,state,stage)d.Accent=accent;d.TintState=state;d.Stage=stage;A.Tints[#A.Tints+1]={d.Kind,state}end
 function A.BuildItem(d,spec)
  A.ItemBuilds[#A.ItemBuilds+1]={Kind=d.Kind,Spec=spec}
  local m=R.new('Model');m.Name='Item'..#A.ItemBuilds;return m,{Parts=10,Source='art'}
 end
 function A.SetItem(d,m)if d.Item and d.Item~=m then d.Item:Destroy()end;d.Item=m end
 function A.SetAvatar(d,m)if d.Avatar and d.Avatar~=m then d.Avatar:Destroy()end;d.Avatar=m end
 function A.Counts(d)return{Frame=10,Item=d.Item and 10 or 0,Avatar=d.Avatar and 10 or 0}end
 return A
end
local function fakeAvatars()
 local V={Builds={},Pending={},Yield=false,Placed=0}
 function V:Build(uid,opts)
  V.Builds[#V.Builds+1]={Uid=uid,Silhouette=opts and opts.Silhouette}
  if V.Yield then V.Pending[#V.Pending+1]=coroutine.running();coroutine.yield()end
  local m=R.new('Model');m.Name='Avatar'..uid;m:SetAttribute('UserId',uid)
  return m,'avatar'
 end
 function V:Place()V.Placed+=1;return true end
 return V
end
-- one "server" ---------------------------------------------------------------------------------------------------------------------------------------------------------------
local function notes()
 local N={Shown={}}
 function N:Show(player,text,color,seconds)N.Shown[#N.Shown+1]={Player=player,Text=text,Color=color,Seconds=seconds}end
 return N
end
local function makeServer(backend,opts)
 opts=opts or{}
 local s={Clock=opts.Clock or HH.clock(T0),Art=fakeArt(),Avatars=fakeAvatars(),Notes=notes()}
 s.Backend=backend
 s.Svc=HH.memoryService(backend)
 s.Store=Store.new({Service=s.Svc,Clock=s.Clock.now})
 local seed=opts.Seed or 1
 local rng={NextNumber=function()seed=(seed*16807)%2147483647;return seed/2147483647 end}
 local folder=R.new('Folder');folder.Name='ChestChaseMap'
 local lobby=R.new('Folder');lobby.Name='Lobby';lobby.Parent=folder
 local floor=R.new('Part');floor.Name='LobbyFloor';floor.Size=V3(680,1,524);floor.CFrame=CF(0,3.5,-361);floor.Parent=lobby
 s.Map={MapRoot=folder}
 s.Service=Service.new(Config,{},s.Notes,s.Map,{Clock=s.Clock.now,Time=s.Clock.time,Store=s.Store,Art=s.Art,Avatars=s.Avatars,FruitList=list,NoLoop=true,Random=rng})
 return s
end
local function pull(over)
 local base={Uid=1,Name='A',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='Mythic',Odds=.125,Scale=1,Coat='None',At=T0}
 for k,v in pairs(over or{})do base[k]=v end
 return Rules.CleanPull(base)
end
-- A reward as PlayerDataService:OpenSeedPack makes it, and the info of the pack it came from.
local function reward(id,rarity,over)
 local r={SeedId=id,SeedName=(P.SeedDesignById[id]and P.SeedDesignById[id].name or id)..' Seed',Rarity=rarity,SeedScale=1,PackMutation='None',Id='1_1'}
 for k,v in pairs(over or{})do r[k]=v end
 return r
end
local function info(over)
 local i={Stage=4,Variant='Pack03',Version=P.OddsVersion,Luck=1,Test=false}
 for k,v in pairs(over or{})do i[k]=v end
 return i
end
local function step(s,seconds)
 for _=1,math.max(1,math.floor(seconds/5))do s.Clock.advance(math.min(5,seconds));s.Service:Step()end
end

-- 1. Start ---------------------------------------------------------------------------------------------------------------------------------------------------------------
local A
do
 local backend=HH.backend();backend.Now=function()return A and A.Clock.t or 0 end
 A=makeServer(backend);backend.Now=function()return A.Clock.t end
 local svc=A.Service
 svc:Start()
 check(A.Art.Built.Pull and A.Art.Built.Fruit,'both displays are built')
 check(svc.Folder and svc.Folder.Name=='HubDisplays151'and svc.Folder.Parent==A.Map.MapRoot,'in a folder HubDisplays151 under the map')
 local snap=svc:Snapshot()
 check(snap.Day==DAY and snap.FruitId==todayFruit and todayFruit~=nil,'the day is the UTC day ('..snap.Day..') and the fruit of the day is HubDisplayRules.FruitForDay ('..tostring(todayFruit)..')')
 check(snap.Pull.Record==nil and snap.Fruit.Record==nil,'both boards start empty')
 local pd,fd=A.Art.Built.Pull,A.Art.Built.Fruit
 check(pd.Text and pd.Text.State=='Empty'and fd.Text.State=='Empty'and pd.Text.Rows.Name.Text=='Nobody yet','both signs show the empty state at once')
 check(pd.TintState=='Empty'and fd.TintState=='Ready','the empty BEST PULL is calm; the empty fruit is lit in its plant\'s colours (the fruit is shown anyway)')
 check(pd.Model:GetAttribute('Rev')==1 and pd.Model:GetAttribute('NextAt')==Rules.NextAt(DAY)and pd.Model:GetAttribute('FooterPrefix')=='New board in 'and fd.Model:GetAttribute('FooterPrefix')=='New fruit in ','the client\'s attributes are set (Rev, NextAt, FooterPrefix)')
 check(fd.Model:GetAttribute('FruitId')==todayFruit,'the fruit display tells the client which fruit it is')
 check(#A.Art.ItemBuilds==2,'each display builds its item once')
 local kinds={};for _,b in ipairs(A.Art.ItemBuilds)do kinds[b.Kind]=b.Spec end
 check(kinds.Pull.Mystery==true and kinds.Pull.Kind=='Seed'and kinds.Fruit.Kind=='Fruit'and kinds.Fruit.Id==todayFruit and kinds.Fruit.Coat=='None','empty: a black mystery seed; the day\'s fruit in its own colours')
 check(#A.Avatars.Builds==2 and A.Avatars.Builds[1].Silhouette and A.Avatars.Builds[2].Silhouette,'both show the black silhouette while nobody holds the spot')
 check(svc:Start()==svc and #A.Art.ItemBuilds==2,'Start twice does nothing')
 svc:Destroy();check(svc.Folder==nil,'Destroy removes the folder')
end

-- 2. Events --------------------------------------------------------------------------------------------------------------------------------------------------------------
local p1,p2,p3
do
 local backend=HH.backend();A=makeServer(backend);backend.Now=function()return A.Clock.t end
 A.Service:Start();A.Service.Opts.NoLoop=true
 p1=HH.player(11,'Ann');p2=HH.player(12,'Ben');p3=HH.player(13,'Cy')
 local svc=A.Service;local pd=A.Art.Built.Pull
 local before=#A.Art.ItemBuilds
 local counted,why=svc:NotePull(p1,reward('FirePepperSeed','Mythic'),info())
 check(counted,'a real pull is counted')
 local snap=svc:Snapshot();local rec=snap.Pull.Record
 check(rec and rec.Name=='Ann'and rec.Uid==11 and rec.Id=='FirePepperSeed'and rec.Rarity=='Mythic'and rec.Seed=='Fire Pepper'and snap.Pull.Source=='Local','the board holds it (name, user id, seed, rarity), from this server')
 local want=P.SeedOdds(Config,4,'Pack03',1,P.OddsVersion)['FirePepperSeed']
 check(want and math.abs(rec.Odds-want)<1e-12,'its odds are the pack\'s own SeedOdds for that seed ('..tostring(want)..'%)')
 check(pd.Text.State=='Champion'and pd.Text.Rows.Name.Text=='Ann'and pd.Text.Rows.Line.Text=='Mythic Fire Pepper'and pd.Text.Rows.Odds.Text==Rules.OddsText(want),'the sign shows "Ann", "Mythic Fire Pepper" and its chance')
 check(pd.Model:GetAttribute('Champion')=='Ann'and pd.Model:GetAttribute('Rarity')=='Mythic'and pd.Model:GetAttribute('ChampionUserId')==11 and pd.Model:GetAttribute('Rev')==2,'the display\'s attributes name the champion and Rev goes up')
 check(pd.TintState=='Ready'and pd.Accent[1]==Rules.RarityColor('Mythic')[1]and pd.Stage==4,'tinted in the rarity\'s colour, the podium in Lava\'s (the seed\'s biome)')
 check(#A.Art.ItemBuilds==before+1 and A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Id=='FirePepperSeed'and A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Mystery==false,'one new item: the seed itself (not the mystery one)')
 check(A.Avatars.Builds[#A.Avatars.Builds].Uid==11 and A.Art.Built.Pull.Avatar:GetAttribute('UserId')==11,'and Ann\'s avatar (by user id)')
 -- exclusions
 local n=#A.Art.ItemBuilds
 check(not svc:NotePull(p2,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01',Test=true})),'a TEST pack (/test rarepacks) is not counted (even a King that would take the spot)')
 svc:NoteOwnerGrant(p3)
 check(not svc:NotePull(p3,reward('SolarStarfruitSeed','King'),info()),'a player an owner command just gave packs is not counted')
 check(not svc:NoteHarvest(p3,{SeedId=svc.Board.FruitId,FruitScale=25,Mutation='None',Weather='None'}),'nor their harvests')
 check(svc:Snapshot().Pull.Record.Name=='Ann'and #A.Art.ItemBuilds==n,'nothing changed')
 check(not svc:NotePull(p2,nil,info())and not svc:NotePull(p2,{},info())and not svc:NotePull('nobody',reward('FirePepperSeed','Mythic'),info())and not svc:NotePull(p2,reward('FirePepperSeed','Bogus'),info()),'a nil / empty / unknown-rarity reward or a non-player is refused, nothing throws')
 -- ranking
 check(not svc:NotePull(p2,reward('FirePepperSeed','Mythic'),info({Variant='Pack06'}))and svc:Snapshot().Pull.Record.Name=='Ann','a Mythic Fire Pepper from a better pack (Pack06: 1 in 6, so a less rare pull than Pack03\'s 1 in 120) does not take the spot')
 local _,r2=svc:NotePull(p2,reward('FirePepperSeed','Mythic'),info({Variant='Pack01'}))
 check(r2=='took'and svc:Snapshot().Pull.Record.Name=='Ben','the same Mythic from a plain Pack01 (a rarer pull) takes it')
 check(not svc:NotePull(p1,reward('SunflowerSeed','Common'),info({Stage=1,Variant='Pack01'}))and svc:Snapshot().Pull.Record.Name=='Ben','a Common pull cannot take it')
 local _,r3=svc:NotePull(p1,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 check(r3=='took'and svc:Snapshot().Pull.Record.Rarity=='King'and svc:Snapshot().Pull.Record.Name=='Ann','a King beats every Mythic')
 local recK=svc:Snapshot().Pull.Record
 check(recK.Odds<1e-9,'a King from a Forest-style pack has its tiny real chance ('..string.format('%.3g',recK.Odds)..'%)')
 -- a pack's coat and size are kept
 svc:NotePull(p2,reward('SolarStarfruitSeed','King',{SeedScale=4,PackMutation='Gold'}),info({Stage=2,Variant='Pack01'}))
 local top=svc:Snapshot().Pull.Record
 check(top.Name=='Ben'and top.Coat=='Gold'and top.Scale==4,'the same King and pack, a bigger seed: the heavier one wins, with its pack\'s coat')
 check(A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Coat=='Gold','and the giant item is built with the coat')
 -- fruit
 local fid=svc.Board.FruitId
 check(not svc:NoteHarvest(p1,{SeedId='NoSuchSeed',FruitScale=3}),'a fruit of another type is ignored (one comparison)')
 check(svc:NoteHarvest(p1,{SeedId=fid,FruitScale=2,Mutation='None',Weather='None'}),'today\'s fruit is counted')
 local fr=svc:Snapshot().Fruit.Record
 check(fr.Name=='Ann'and math.abs(fr.Kg-2*Weight.FruitBase(fid))<1e-9,'with its weight = base kg x its size')
 local fd=A.Art.Built.Fruit
 check(fd.Text.State=='Champion'and fd.Text.Rows.Name.Text==Rules.KgText(fr.Kg)and fd.Text.Rows.Line.Text=='Ann','the sign shows the weight and the name')
 check(not svc:NoteHarvest(p2,{SeedId=fid,FruitScale=1.5}),'a lighter fruit is recorded for Ben but changes nothing... (counted as ignored: lighter than this server\'s own)')
 check(svc:NoteHarvest(p2,{SeedId=fid,FruitScale=6,Mutation='Gold',Weather='Drippy'})and svc:Snapshot().Fruit.Record.Name=='Ben','a heavier one takes the spot')
 check(svc:Snapshot().Fruit.Record.Coat=='Gold'and A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Coat=='Gold'and A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Kind=='Fruit','its coat is kept and the giant fruit is built with it')
 check(fd.Text.Rows.Odds.Text=='Gold · Drippy','the sign tells the coat and the weather')
 check(not svc:NoteHarvest(p1,{SeedId=fid}) and not svc:NoteHarvest(p1,{SeedId=fid,FruitScale=0/0})and not svc:NoteHarvest(p1,nil)and not svc:NoteHarvest(nil,{SeedId=fid,FruitScale=2}),'a harvest without a size, a NaN size, nothing or no player is refused')
 -- a fruit that took the spot but is not the biggest of a pair at the same weight
 local f1=svc:NoteHarvest(p3,{SeedId=fid,FruitScale=6,Mutation='Gold',Weather='Drippy'})
 check(not f1,'p3 is tainted: still refused')
end

-- 3. Notices -------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();A=makeServer(backend);backend.Now=function()return A.Clock.t end
 A.Service:Start()
 local svc=A.Service
 local players=H.players -- everyone created so far lives in the Players service
 local remote=remotes:FindFirstChild('HubDisplayCelebrate')
 local fired={}
 check(remote and remote:IsA('RemoteEvent'),'the celebration remote ChestChaseRemotes.HubDisplayCelebrate exists')
 remote.FireClient=function(_,player,payload)fired[#fired+1]={Player=player,Payload=payload}end
 local q1=HH.player(21,'Zed')
 local n0=#A.Notes.Shown
 svc:NotePull(q1,reward('FirePepperSeed','Mythic'),info())
 local shown=A.Notes.Shown
 local mine={};for i=n0+1,#shown do mine[#mine+1]=shown[i]end
 local everyone=#H.players
 check(#mine==everyone,'the notice goes to every player in the server ('..#mine..' of '..everyone..')')
 check(mine[1].Text=='🏆 Zed took BEST PULL TODAY with a Mythic Fire Pepper!','the notice reads "🏆 Zed took BEST PULL TODAY with a Mythic Fire Pepper!"')
 check(mine[1].Seconds==5 and mine[1].Color.R and math.abs(mine[1].Color.R*255-Rules.RarityColor('Mythic')[1])<1,'shown for 5 s in the rarity\'s colour')
 check(#fired==everyone and fired[1].Payload.Kind=='Pull'and fired[1].Payload.Name=='Zed','and the celebration remote is fired for each (the client plays the game\'s GemClaim chime)')
 -- the gap
 svc:NotePull(q1,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 check(#A.Notes.Shown==n0+everyone,'a second champion within 8 s: the display changes, no second notice')
 check(svc:Snapshot().Pull.Record.Rarity=='King','(the display did change)')
 A.Clock.advance(9)
 svc:NotePull(q1,reward('SolarStarfruitSeed','King',{SeedScale=5}),info({Stage=2,Variant='Pack01'}))
 check(#A.Notes.Shown==n0+2*everyone,'after the gap the next champion is announced again')
 -- a Common never makes a notice
 local backend2=HH.backend();local B=makeServer(backend2);backend2.Now=function()return B.Clock.t end;B.Service:Start()
 local m0=#B.Notes.Shown
 B.Service:NotePull(q1,reward('SunflowerSeed','Common'),info({Stage=1,Variant='Pack01'}))
 check(B.Service:Snapshot().Pull.Record.Rarity=='Common'and #B.Notes.Shown==m0,'a Common pull takes the spot silently (the display changes, nobody is told)')
 B.Service:NotePull(q1,reward('AppleSeed','Rare'),info({Stage=1,Variant='Pack01'}))
 check(#B.Notes.Shown==m0+everyone,'a Rare is announced (the minimum rank is Rare)')
 -- fruit notice
 local fid=B.Service.Board.FruitId
 B.Service:NoteHarvest(q1,{SeedId=fid,FruitScale=5.5,Mutation='None'})
 local last=B.Notes.Shown[#B.Notes.Shown]
 local rec=B.Service:Snapshot().Fruit.Record
 check(last.Text==Rules.FruitNotice(rec,B.Service:FruitName(fid))and last.Text:find('took BIGGEST',1,true)and last.Text:find('kg',1,true),'the fruit notice: "<emoji> Zed took BIGGEST <FRUIT> TODAY with 12.4 kg!" ('..last.Text..')')
 -- a champion from another server: shown with a pop but no notice
 local backend3=HH.backend();local S1=makeServer(backend3,{Seed=3});local S2=makeServer(backend3,{Seed=9})
 backend3.Now=function()return S1.Clock.t end
 S1.Service:Start();S2.Service:Start()
 S1.Service:NotePull(q1,reward('FirePepperSeed','Mythic'),info())
 step(S1,5)
 local seen=#S2.Notes.Shown
 step(S2,70)
 check(S2.Service:Snapshot().Pull.Record and S2.Service:Snapshot().Pull.Source=='Remote'and #S2.Notes.Shown==seen,'a champion that came from another server updates the display with no notice on this one')
end

-- 4. The day -------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();A=makeServer(backend,{Clock=HH.clock(DAY*86400+86400-100)});backend.Now=function()return A.Clock.t end
 local svc=A.Service;svc:Start()
 local q=HH.player(31,'Dee')
 svc:NotePull(q,reward('FirePepperSeed','Mythic'),info());svc:NoteHarvest(q,{SeedId=svc.Board.FruitId,FruitScale=3})
 check(svc:Snapshot().Pull.Record and svc:Snapshot().Fruit.Record,'before midnight: both boards hold something')
 local dayBefore=svc:Snapshot().Day;local fruitBefore=svc:Snapshot().FruitId
 local revBefore=A.Art.Built.Pull.Model:GetAttribute('Rev')
 step(svc and A,50);check(svc:Snapshot().Day==dayBefore,'50 s later it is still the same day')
 step(A,60)
 local snap=svc:Snapshot()
 check(snap.Day==dayBefore+1,'at midnight UTC the day number moves on')
 check(snap.Pull.Record==nil and snap.Fruit.Record==nil,'both boards are empty')
 check(snap.FruitId==Rules.FruitForDay(list,dayBefore+1)and snap.FruitId~=fruitBefore,'the fruit of the day changed to the next one in the rotation ('..tostring(fruitBefore)..' -> '..tostring(snap.FruitId)..')')
 check(A.Art.Built.Pull.Text.State=='Empty'and A.Art.Built.Fruit.Text.State=='Empty'and A.Art.Built.Pull.Model:GetAttribute('Rev')>revBefore,'the signs are empty again and Rev went up')
 check(A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Id==snap.FruitId or A.Art.ItemBuilds[#A.Art.ItemBuilds-1].Spec.Id==snap.FruitId,'the fruit display builds the new fruit')
 check(A.Art.Built.Pull.Model:GetAttribute('NextAt')==Rules.NextAt(dayBefore+1),'the countdown aims at the next midnight')
 -- yesterday's fruit no longer counts
 check(not svc:NoteHarvest(q,{SeedId=fruitBefore,FruitScale=9}),'yesterday\'s fruit type is not today\'s: ignored')
 -- an event right after midnight, before a Step, counts for the new day
 local backend2=HH.backend();local c2=HH.clock(DAY*86400+86399);local B=makeServer(backend2,{Clock=c2});backend2.Now=function()return c2.t end;B.Service:Start()
 c2.advance(2)
 B.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info())
 check(B.Service:Snapshot().Day==DAY+1 and B.Service:Snapshot().Pull.Record and B.Service:Snapshot().Pull.Record.At==c2.unix,'a pull in the first seconds of the new day (no Step yet) is the new day\'s')
 -- the shared document is per day
 step(B,10)
 check(backend2.peek(Rules.StoreName,'d'..(DAY+1))~=nil and backend2.peek(Rules.StoreName,'d'..DAY)==nil,'it is written to the new day\'s key')
 -- the shared board of the new day is read after rollover
 local backend3=HH.backend();local c3=HH.clock(DAY*86400+86390);local S1=makeServer(backend3,{Clock=c3,Seed=2});backend3.Now=function()return c3.t end
 HH.memoryService(backend3):GetHashMap(Rules.StoreName):SetAsync('d'..(DAY+1),Rules.StoreDoc({pull=pull({Uid=77,Name='Early',Rarity='Secret',Odds=.01})}),1e6)
 S1.Service:Start();step(S1,5)
 check(S1.Service:Snapshot().Pull.Record==nil,'before midnight yesterday\'s key is the only one read')
 step(S1,30)
 check(S1.Service:Snapshot().Pull.Record and S1.Service:Snapshot().Pull.Record.Name=='Early','after midnight the new key is read at the next step')
end

-- 5. Cross-server --------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend()
 local ca,cb=HH.clock(T0),HH.clock(T0);backend.Now=function()return ca.t end
 local SA=makeServer(backend,{Clock=ca,Seed=5});local SB=makeServer(backend,{Clock=cb,Seed=77})
 SA.Service:Start();SB.Service:Start()
 local pa,pb=HH.player(41,'Ava'),HH.player(42,'Bo')
 SA.Service:NotePull(pa,reward('FirePepperSeed','Mythic'),info())
 check(SA.Service:Snapshot().Pull.Unsynced and backend.Calls.Update==0,'an event is instant and local; nothing has been written yet')
 SA.Service:Step()
 check(backend.Calls.Update==1 and not SA.Service:Snapshot().Pull.Unsynced,'the next step writes it (compare-and-set), and it is synced')
 check(backend.peek(Rules.StoreName,'d'..DAY).pull.Name=='Ava','the store holds Ava\'s pull')
 -- B reads within 45-60 s
 local polled
 for t=1,13 do cb.advance(5);SB.Service:Step();if SB.Service:Snapshot().Pull.Record then polled=t*5;break end end
 check(polled and polled<=65,'server B shows Ava\'s pull within about a minute ('..tostring(polled)..' s)')
 local snapB=SB.Service:Snapshot()
 check(snapB.Pull.Record.Name=='Ava'and snapB.Pull.Source=='Remote'and not snapB.Pull.Unsynced,'as the shared (Remote) champion, nothing to write back')
 check(SB.Art.Built.Pull.Text.Rows.Name.Text=='Ava'and SB.Art.Built.Pull.Model:GetAttribute('Rev')==2 and SB.Avatars.Builds[#SB.Avatars.Builds].Uid==41,'B\'s display now shows Ava with her avatar and pops (Rev + 1)')
 check(#SB.Notes.Shown==0,'B posted no notice (it happened in server A)')
 -- B takes the spot with a better pull
 SB.Service:NotePull(pb,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 check(SB.Art.Built.Pull.Text.Rows.Name.Text=='Bo','B\'s own King shows at once on B')
 check(SA.Art.Built.Pull.Text.Rows.Name.Text=='Ava','while A still shows Ava')
 cb.advance(5);SB.Service:Step();ca.advance(5)
 for _=1,14 do ca.advance(5);SA.Service:Step()end
 check(SA.Service:Snapshot().Pull.Record.Name=='Bo'and SA.Art.Built.Pull.Text.Rows.Name.Text=='Bo','within a minute A shows Bo\'s King too')
 local told={};for _,n in ipairs(SA.Notes.Shown)do told[n.Text:match('^%S+ (%S+)')]=true end
 check(told.Ava and not told.Bo,'A only ever told its own players about Ava, never about Bo (his King came from another server)')
 -- a worse pull on A afterwards changes nothing and writes nothing
 local updates=backend.Calls.Update
 SA.Service:NotePull(pa,reward('AppleSeed','Rare'),info({Stage=1,Variant='Pack01'}))
 for _=1,4 do ca.advance(5);SA.Service:Step()end
 check(backend.Calls.Update==updates and SA.Service:Snapshot().Pull.Record.Name=='Bo','a worse pull is never written to the store')
 -- the race: both servers get a champion in the same second and write at the same moment
 backend=HH.backend();ca=HH.clock(T0);cb=HH.clock(T0);backend.Now=function()return ca.t end
 SA=makeServer(backend,{Clock=ca,Seed=5});SB=makeServer(backend,{Clock=cb,Seed=77});SA.Service:Start();SB.Service:Start()
 SA.Service:NotePull(pa,reward('FirePepperSeed','Mythic'),info())
 SB.Service:NotePull(pb,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 backend.Race=function()SB.Service:Step()end -- (B writes its King between A's read and A's commit)
 SA.Service:Step()
 check(backend.peek(Rules.StoreName,'d'..DAY).pull.Name=='Bo','the King is in the store even though A started writing first')
 check(SA.Service:Snapshot().Pull.Record.Name=='Bo'and SA.Art.Built.Pull.Text.Rows.Name.Text=='Bo','A reads the winner back at once (no wait for a poll) and shows it')
 check(not SA.Service:Snapshot().Pull.Unsynced,'and has nothing left to write')
 -- fruit across servers: the heavier wins
 local fid=SA.Service.Board.FruitId
 SA.Service:NoteHarvest(pa,{SeedId=fid,FruitScale=3});SB.Service:NoteHarvest(pb,{SeedId=fid,FruitScale=5})
 SA.Service:Step();cb.advance(5);SB.Service:Step();ca.advance(60);SA.Service:Step()
 local fa=SA.Service:Snapshot().Fruit;local stored=backend.peek(Rules.StoreName,'d'..DAY)
 check(fa.Record and fa.Record.Name=='Bo'and stored.fruit.Name=='Bo','the heavier fruit from the other server wins on both')
end

-- 6. Polling and writes --------------------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local ca=HH.clock(T0);backend.Now=function()return ca.t end
 local SA=makeServer(backend,{Clock=ca,Seed=5});SA.Service:Start()
 local reads={};local last=-1
 for t=5,3600,5 do
  ca.advance(5);local before=backend.Calls.Get;SA.Service:Step()
  if backend.Calls.Get>before then reads[#reads+1]=t end
 end
 local gaps={};for i=2,#reads do gaps[#gaps+1]=reads[i]-reads[i-1]end
 local lo,hi=math.huge,0;for _,g in ipairs(gaps)do lo=math.min(lo,g);hi=math.max(hi,g)end
 check(#reads>=55 and #reads<=80,'an hour of steps reads the shared board '..#reads..' times (about once a minute)')
 check(lo>=45 and hi<=65,'the gap between two reads is 45-60 s plus the 5 s loop ('..lo..'..'..hi..' s)')
 check(backend.Calls.Update==0,'an idle server never writes')
 local backend2=HH.backend();local c2=HH.clock(T0);backend2.Now=function()return c2.t end
 local SB=makeServer(backend2,{Clock=c2,Seed=123});local SC=makeServer(backend2,{Clock=c2,Seed=999});SB.Service:Start();SC.Service:Start()
 local firstB,firstC;for t=1,30 do c2.advance(5);local b=backend2.Calls.Get;SB.Service:Step();local mid=backend2.Calls.Get;SC.Service:Step()
  if not firstB and mid>b then firstB=t end;if not firstC and backend2.Calls.Get>mid then firstC=t end end
 check(firstB and firstC,'both servers read')
 -- jitter: the NextPoll values differ between servers started at the same moment
 SB.Service.NextPoll=0;SC.Service.NextPoll=0;SB.Service:_poll();SC.Service:_poll()
 check(SB.Service.NextPoll~=SC.Service.NextPoll and SB.Service.NextPoll-c2.t>=45 and SB.Service.NextPoll-c2.t<=60.0001,'the next read is 45-60 s away and differs between servers (jitter)')
 -- writes are coalesced: ten better pulls in a few seconds are not ten writes
 local backend3=HH.backend();local c3=HH.clock(T0);backend3.Now=function()return c3.t end
 local S=makeServer(backend3,{Clock=c3,Seed=5});S.Service:Start()
 local q=HH.player(51,'Cat')
 for i=1,10 do
  S.Service:NotePull(q,reward('SunflowerSeed','Common',{SeedScale=i}),info({Stage=1,Variant='Pack01'}))
  c3.advance(.3);S.Service:Step()
 end
 check(backend3.Calls.Update<=2,'ten better pulls in 3 seconds are at most two writes ('..backend3.Calls.Update..')')
 c3.advance(4);S.Service:Step()
 check(not S.Service:Snapshot().Pull.Unsynced and backend3.peek(Rules.StoreName,'d'..DAY).pull.Scale==10,'and the last (best) one ends up in the store')
 -- an hour with events: requests stay far below the budget
 local backend4=HH.backend();local c4=HH.clock(T0);backend4.Now=function()return c4.t end
 local S4=makeServer(backend4,{Clock=c4,Seed=5});S4.Service:Start()
 for t=1,720 do
  c4.advance(5)
  if t%10==0 then S4.Service:NotePull(q,reward('SunflowerSeed','Common',{SeedScale=.35+t/1000}),info({Stage=1,Variant='Pack01'}))end
  S4.Service:Step()
 end
 local perMinute=(backend4.Calls.Get+backend4.Calls.Update)/60
 check(perMinute<=6,'an hour with a new best pull every 50 s costs '..string.format('%.1f',perMinute)..' MemoryStore requests a minute (quota: 1000 + 100 per player)')
end

-- 7. Failures ------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local ca=HH.clock(T0);backend.Now=function()return ca.t end
 local S=makeServer(backend,{Clock=ca,Seed=5});S.Service:Start()
 backend.Fail=function()return'HTTP 500 InternalServerError'end
 local q=HH.player(61,'Dot')
 S.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info())
 check(S.Art.Built.Pull.Text.Rows.Name.Text=='Dot','MemoryStore down: this server still shows its own best')
 for _=1,6 do ca.advance(5);S.Service:Step()end
 local snap=S.Service:Snapshot()
 check(snap.Store.Failures>=1 and snap.Pull.Unsynced and snap.Pull.Record.Name=='Dot','the failure is counted and the record stays unsynced')
 local calls=backend.Calls.Get+backend.Calls.Update
 for _=1,4 do ca.advance(5);S.Service:Step()end
 check(backend.Calls.Get+backend.Calls.Update-calls<=2,'while it is down the server backs off: it is not asking every step ('..(backend.Calls.Get+backend.Calls.Update-calls)..' requests in 20 s)')
 check(S.Service:StatusText():find('FAILING',1,true),'the status line says the shared board is failing')
 -- a champion at the same time in another server, then MemoryStore comes back
 local other=HH.memoryService(backend):GetHashMap(Rules.StoreName)
 backend.Fail=nil
 other:SetAsync('d'..DAY,Rules.StoreDoc({pull=pull({Uid=70,Name='Far',Rarity='Cosmic',Odds=.001})}),1e6)
 for _=1,80 do ca.advance(5);S.Service:Step()end
 snap=S.Service:Snapshot()
 check(snap.Store.Failures==0 and snap.Pull.Record.Name=='Far'and S.Art.Built.Pull.Text.Rows.Name.Text=='Far','when it recovers it catches up with the shared board (a Cosmic from another server beats the Mythic)')
 check(not snap.Pull.Unsynced and backend.peek(Rules.StoreName,'d'..DAY).pull.Name=='Far','and the better shared record was kept (our Mythic never overwrote it)')
 -- a local record that is better is written after the outage
 backend.Fail=function()return'429 throttled'end
 S.Service:NotePull(q,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 for _=1,5 do ca.advance(5);S.Service:Step()end
 check(S.Service:Snapshot().Store.Throttled and S.Service:Snapshot().Pull.Unsynced,'a throttled store keeps the record unsynced and waits')
 backend.Fail=nil
 for _=1,40 do ca.advance(5);S.Service:Step()end
 check(not S.Service:Snapshot().Pull.Unsynced and backend.peek(Rules.StoreName,'d'..DAY).pull.Name=='Dot'and backend.peek(Rules.StoreName,'d'..DAY).pull.Rarity=='King','later the King goes in')
 -- an error thrown out of nowhere never stops the step
 S.Service.Store.Read=function()error('boom')end;S.Service.Store.Merge=function()error('boom')end
 S.Service:NotePull(q,reward('SolarStarfruitSeed','King',{SeedScale=9}),info({Stage=2,Variant='Pack01'}))
 local okStep=pcall(function()for _=1,30 do ca.advance(5);S.Service:Step()end end)
 check(okStep,'a store that throws is caught by the step')
end

-- 8. A champion change rebuilds once --------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local ca=HH.clock(T0);backend.Now=function()return ca.t end
 local S=makeServer(backend,{Clock=ca,Seed=5});S.Service:Start()
 local q=HH.player(71,'Eli')
 local n0=#S.Art.ItemBuilds;local v0=#S.Avatars.Builds
 S.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info())
 check(#S.Art.ItemBuilds==n0+1 and #S.Avatars.Builds==v0+1,'a new champion: one item, one avatar')
 -- the same record again (a poll that brings the same champion back) rebuilds nothing
 step(S,5);ca.advance(60);S.Service:Step();S.Service:Step();ca.advance(60);S.Service:Step()
 check(#S.Art.ItemBuilds==n0+1 and #S.Avatars.Builds==v0+1,'polling the same champion back (the store now holds it) rebuilds nothing')
 local rev=S.Art.Built.Pull.Model:GetAttribute('Rev')
 S.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info())
 check(#S.Art.ItemBuilds==n0+1 and S.Art.Built.Pull.Model:GetAttribute('Rev')==rev,'an equal (not better) pull changes nothing')
 -- two champions in a row while the first avatar is still loading: only the second is installed
 S.Avatars.Yield=true
 S.Service:NotePull(q,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 local q2=HH.player(72,'Flo')
 S.Service:NotePull(q2,reward('SolarStarfruitSeed','King',{SeedScale=7}),info({Stage=2,Variant='Pack01'}))
 check(#S.Avatars.Pending==2,'two avatar loads are in flight')
 S.Avatars.Yield=false
 local placed0=S.Avatars.Placed
 for i=#S.Avatars.Pending,1,-1 do coroutine.resume(S.Avatars.Pending[i])end -- (the NEWER load finishes first, the stale one last: it must not overwrite)
 local d=S.Art.Built.Pull
 check(d.Avatar and d.Avatar:GetAttribute('UserId')==72,'only the newer champion\'s avatar is installed (the stale one, finishing last, was dropped)')
 check(S.Avatars.Placed==placed0+1,'(the older avatar was never placed)')
 check(d.Item~=nil and d.Item.Name=='Item'..#S.Art.ItemBuilds,'(the newest item stays)')
 -- the same for a day change while a build is in flight
 S.Avatars.Yield=true
 S.Service:NotePull(HH.player(73,'Gus'),reward('SolarStarfruitSeed','King',{SeedScale=9}),info({Stage=2,Variant='Pack01'}))
 ca.advance(86400);S.Service:Step()
 S.Avatars.Yield=false
 for _,co in ipairs(S.Avatars.Pending)do pcall(coroutine.resume,co)end
 local snap=S.Service:Snapshot()
 check(snap.Pull.Record==nil and d.Avatar and d.Avatar:GetAttribute('UserId')==0,'a champion that was loading at midnight does not show on the new empty board (a silhouette does)')
end

-- 9. Owner tools ---------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local ca=HH.clock(T0);backend.Now=function()return ca.t end
 local S=makeServer(backend,{Clock=ca,Seed=5});S.Service:Start()
 local svc=S.Service
 local q=HH.player(81,'Ivy');local r=HH.player(82,'Jay')
 check(svc:FindSeed('FirePepperSeed')and svc:FindSeed('fire pepper')and svc:FindSeed('Fire  Pepper')and svc:FindSeed('FIREPEPPERSEED')and svc:FindSeed('Fire Pepper').id=='FirePepperSeed'and not svc:FindSeed('nonsense')and not svc:FindSeed(''),'a seed is found by id or by plant name, any case or spacing')
 check(svc:FindSeed('worldroot')~=nil,'(and by the game\'s display name: Ancient Worldroot is "Worldroot")')
 local ok,msg=svc:InjectPull(q,'fire pepper')
 check(ok and msg:find('Mythic Fire Pepper',1,true)and msg:find('this server only',1,true),'bestpull: injects a Mythic Fire Pepper ('..tostring(msg)..')')
 local snap=svc:Snapshot()
 check(snap.Pull.Record.Name=='Ivy'and snap.Pull.Source=='Test'and not snap.Pull.Unsynced,'it shows (as a Test record) and is never unsynced')
 step(S,15);check(backend.Calls.Update==0,'a test pull is never written to the shared store')
 check(#S.Notes.Shown>=1,'the owner sees the notice of a test (the display and the sound are testable)')
 local ok2,msg2=svc:InjectPull(q,'nonsense');check(not ok2 and msg2:find('Unknown seed',1,true),'an unknown seed is refused with a hint')
 local ok3=svc:InjectPull(q,'sunflower')
 check(not ok3,'a worse pull than what the board holds is refused')
 local ok4,msg4=svc:InjectPull(r,'solar starfruit',true)
 check(ok4 and msg4:find('(shared)',1,true),'bestpull ... share is written like a real one')
 step(S,10);check(backend.Calls.Update>=1 and backend.peek(Rules.StoreName,'d'..DAY).pull.Name=='Jay','and reaches the store')
 -- bigfruit
 local fid=svc.Board.FruitId;local base=Weight.Base('Fruit',fid)
 local okF,msgF=svc:InjectFruit(q,12.4)
 check(okF and svc:Snapshot().Fruit.Record and math.abs(svc:Snapshot().Fruit.Record.Kg-math.clamp(12.4/base,.35,50)*base)<1e-9,'bigfruit 12.4: a fruit of today\'s type ('..tostring(msgF)..')')
 check(svc:Snapshot().Fruit.Source=='Test','as a Test record')
 check(not svc:InjectFruit(q,'x')and not svc:InjectFruit(q,-3)and not svc:InjectFruit(q,0/0)and not svc:InjectFruit(q,0),'a bad weight is refused')
 local okG,msgG=svc:InjectFruit(r,60,'Gold')
 check(okG and svc:Snapshot().Fruit.Record.Coat=='Gold','bigfruit with a gold coat')
 -- status
 local text=svc:StatusText()
 check(text:find('Day '..DAY,1,true)and text:find('fruit of the day',1,true)and text:find('BEST PULL: Jay',1,true)and text:find('BIGGEST FRUIT: Jay',1,true)and text:find('Shared board: ok',1,true),'hubdisplays prints the day, the fruit of the day, both champions and the store\'s health')
 -- reset
 local removed=svc:Reset()
 check(removed==true and svc:Snapshot().Pull.Record==nil and svc:Snapshot().Fruit.Record==nil and backend.peek(Rules.StoreName,'d'..DAY)==nil,'reset empties both boards and deletes today\'s shared document')
 check(S.Art.Built.Pull.Text.State=='Empty','the displays show the empty state again')
 svc:NoteOwnerGrant(q);svc:Reset()
 check(svc:NotePull(q,reward('FirePepperSeed','Mythic'),info()),'reset also forgets who was given items (counting starts afresh)')
 -- day preview
 svc:Reset()
 local todayId=svc.Board.FruitId
 local reqs=backend.Calls.Get+backend.Calls.Update+backend.Calls.Remove
 svc:SetDayOffset(1)
 local tomorrow=Rules.FruitForDay(list,DAY+1)
 check(svc:Snapshot().Day==DAY+1 and svc:Snapshot().FruitId==tomorrow and svc:Snapshot().DayOffset==1,'day +1 previews tomorrow\'s fruit ('..tostring(todayId)..' -> '..tostring(tomorrow)..')')
 check(A and S.Art.Built.Fruit.Model:GetAttribute('FruitId')==tomorrow,'the fruit display builds tomorrow\'s fruit')
 check(S.Art.Built.Fruit.Model:GetAttribute('NextAt')==Rules.NextAt(DAY+1)-86400,'its countdown still aims at the real next midnight')
 svc:InjectFruit(q,30)
 step(S,120)
 check(backend.Calls.Get+backend.Calls.Update+backend.Calls.Remove==reqs,'while previewing nothing is read from or written to the shared store')
 check(svc:StatusText():find('preview',1,true)and svc:StatusText():find('off while previewing',1,true),'the status says it is a preview')
 svc:SetDayOffset(0)
 check(svc:Snapshot().Day==DAY and svc:Snapshot().FruitId==todayId and svc:Snapshot().Fruit.Record==nil,'day 0 comes back to today with an empty fruit board')
 local clamp=svc:SetDayOffset(1e9);check(clamp<=400,'the preview offset is limited');svc:SetDayOffset(0)
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
