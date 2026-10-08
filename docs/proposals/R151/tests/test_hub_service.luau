--!nocheck
-- R151 hub displays: HubDisplayService (events, the day, the shared board, the displays' refresh, notices, owner tools) with the REAL service, board, store, rules and
-- game modules (SeedPackRules / Config / ItemWeight ...), a MemoryStore mock shared by several "servers", a fake clock per server, and a recording stand-in for the art and
-- the avatar builder (their own suites: test_hub_art, test_hub_avatar):
--  1. start: both displays built, the first day set up, the fruit of the day = HubDisplayRules.FruitForDay;
--  2. events: a real pull is ranked and shown (plaque and label, accent, item and avatar requested once, the avatar placed, put in the display and then told to dance: R152), odds = the
--     pack's own SeedOdds; TEST packs, owner-granted players and injected
--     tests are not counted; a worse pull / fruit only moves nothing; fruit of another type ignored;
--  3. the record line (R153: for this server and this window only): ONE announcement through PullAnnouncer.Announce (a stand-in that decides like the real one; the real one is in test_hub_hooks), no notice of the hub's
--     own, a pull record AfterReveal and the chime in step with it, a fruit record at once, the gap, nothing for another server's champion or a preview day, an announcer that fails;
--  4. the day: midnight (also a 10-minute mark) clears both boards and changes the fruit; an event right after midnight counts for the new day / window; the FRUIT is by day in the store;
--  5. cross-server (the FRUIT): A writes (about 3 s later), B reads (within 45-60 s) and shows it with a pop but no notice; races between two servers; the heavier wins everywhere; a pull
--     on A never arrives on B;
--  6. polling and writes (the fruit's): the interval and jitter, how many requests an hour costs, writes are coalesced, pulls cost none;
--  7. failures: MemoryStore down -> this server's own best, keeps trying with backoff, catches up; throttled; recovered; the pull board does not notice;
--  8. a champion change rebuilds the item and the avatar once (a stale build is dropped, also while its avatar is made ready; an identical record rebuilds nothing); R153: the same
--     champion with a better record keeps the avatar that stands there (no new rig: every screen's dance goes on);
--  8b. R153: the clients' dance reports (HubDisplayAvatarReport): checked field by field, rate-limited, the last per display kept; the owner's status line says each display's
--     AvatarMode and dance id, the asking owner's own screen (track loaded, its Length) and what the other screens report;
--  9. owner tools: bestpull / bigfruit (this server only; bigfruit has `share`, bestpull does not any more; announced PRIVATELY to the target), reset, day preview (no store
--     traffic; the pull board does not care), status text;
--  R153 (owner: "make the best pull of the day refresh every 10 minutes and its a local server only thing to increase performance"): BEST PULL is per server and per wall-clock 10-minute
--  window. Sections 1-9 and 11 now hold for the FRUIT's shared half only (the pull never reaches the store, another server, MessagingService or any save: a trap on those services and a
--  recording store prove it), and
--  12. the window: the board and the avatar clear at the boundary (:00, :10, :20 ... of os.time()), exactly as an empty board does; the next pull is the new record whatever the last one
--     was; a better pull in the window replaces the record; the countdown ("new board in 7:42"); TEST packs, owner grants and injected tests; the fruit board is untouched; an empty board that
--     stays empty is not rebuilt; a pull right after the mark (before any step) is the new window's; the loop wakes at the mark; nothing leaks over many windows (rigs, items, parts);
--     a preview day does not touch the pull board.
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
-- R153: a trap on everything BEST PULL must never touch: DataStoreService, MessagingService, and the default MemoryStoreService (every server here is handed its own mock store). Any
-- call counts; they throw too, so a caller that reaches one fails loudly.
local trapped={DataStore=0,Messaging=0,MemoryStore=0}
do
 local ds=W.service('DataStoreService');for _,m in ipairs({'GetDataStore','GetOrderedDataStore','GetGlobalDataStore'})do ds[m]=function()trapped.DataStore+=1;error('trap: DataStoreService.'..m)end end
 local ms=W.service('MessagingService');for _,m in ipairs({'PublishAsync','SubscribeAsync'})do ms[m]=function()trapped.Messaging+=1;error('trap: MessagingService.'..m)end end
 local mem=W.service('MemoryStoreService');for _,m in ipairs({'GetHashMap','GetSortedMap','GetQueue'})do mem[m]=function()trapped.MemoryStore+=1;error('trap: MemoryStoreService.'..m)end end
end

-- A recording stand-in for HubDisplayArt / HubDisplayAvatar -------------------------------------------------------------------------------------------------------------
local function fakeArt()
 local A={Built={},Items={},Avatars={},SignWrites=0,Tints={},ItemBuilds={}}
 function A.BuildFrame(parent,kind,layout,top)
  local m=R.new('Model');m.Name=kind;m.Parent=parent
  local d={Kind=kind,Model=m,FeetAt=CF(0,0,0),ItemAt=CF(0,0,0),Labels={}}
  A.Built[kind]=d;return d
 end
 function A.SetSign(d,text)A.SignWrites+=1;d.Text=text;d.Model:SetAttribute('State',text.State)end
 function A.Tint(d,accent,state)d.Accent=accent;d.TintState=state;A.Tints[#A.Tints+1]={d.Kind,state}end
 function A.BuildItem(d,spec)
  A.ItemBuilds[#A.ItemBuilds+1]={Kind=d.Kind,Spec=spec}
  local m=R.new('Model');m.Name='Item'..#A.ItemBuilds;A.ItemModels=A.ItemModels or{};A.ItemModels[#A.ItemModels+1]=m;return m,{Parts=10,Source='art'}
 end
 function A.SetItem(d,m)if d.Item and d.Item~=m then d.Item:Destroy()end;d.Item=m end
 function A.SetAvatar(d,m)if d.Avatar and d.Avatar~=m then d.Avatar:Destroy()end;d.Avatar=m;if m then m:SetAttribute('InDisplay',true);m.Parent=d.Model end end -- (in the display, as the real one)
 function A.Counts(d)return{Frame=10,Item=d.Item and 10 or 0,Avatar=d.Avatar and 10 or 0}end
 return A
end
local function fakeAvatars()
 local V={Builds={},Pending={},Yield=false,Placed=0,Animated={},AnimateYield=false,AnimatePending={},AnimateMode='dance'}
 function V:Build(uid,opts)
  V.Builds[#V.Builds+1]={Uid=uid,Silhouette=opts and opts.Silhouette}
  if V.Yield then V.Pending[#V.Pending+1]=coroutine.running();coroutine.yield()end
  local m=R.new('Model');m.Name='Avatar'..uid;m:SetAttribute('UserId',uid)
  V.Models=V.Models or{};V.Models[#V.Models+1]=m -- (every rig made, to see that each one that is not on the display was destroyed)
  if opts and opts.Silhouette then m:SetAttribute('Fallback',true);return m,'fallback'end
  return m,'avatar'
 end
 function V:Place(m,feet,height,turn)V.Placed+=1;V.Last={Height=height,Turn=turn};if m then m:SetAttribute('Placed',true)end;return true end
 -- R152 / R153: made ready to dance once the avatar is in the display (the clients play the dance on its Animator); a stand-in may yield here.
 function V:Animate(m,uid)
  V.Animated[#V.Animated+1]={Model=m,Uid=uid,Placed=m:GetAttribute('Placed')==true,InDisplay=m:GetAttribute('InDisplay')==true}
  if V.AnimateYield then V.AnimatePending[#V.AnimatePending+1]=coroutine.running();coroutine.yield()end
  if m:GetAttribute('Fallback')then m:SetAttribute('AvatarMode','static');return'static'end
  m:SetAttribute('AvatarMode',V.AnimateMode);m:SetAttribute('DanceId',V.AnimateMode=='dance'and Rules.DanceIds[Rules.DanceIndex(uid,1)]or nil);return V.AnimateMode
 end
 return V
end
-- A stand-in for PullAnnouncer.Announce that decides like the real one where it matters here (PullAnnounceRules.RecordScope: a BestPull below Legendary is refused; a pull
-- record AfterReveal waits RevealDelay + RecordLag) and records every call, every accepted one and every wait.
local Announce=W.module('PullAnnounceRules')
local function fakeAnnouncer()
 local F={Calls={},Sent={},Waits={}}
 function F.Announce(spec)
  F.Calls[#F.Calls+1]=spec
  local info=spec.SeedId and Announce.SeedInfo(spec.SeedId)
  local scope=spec.Scope or Announce.RecordScope(spec.Record,info and info.Rarity)
  if scope==nil then return false,'below the threshold'end
  local wait=0
  if spec.AfterReveal and not spec.To and info then wait=Announce.RevealDelay(info.Rarity)+Announce.Setting('RecordLag')end
  F.Sent[#F.Sent+1]=spec;F.Waits[#F.Waits+1]=wait
  return true,wait
 end
 return F
end
-- one "server" ---------------------------------------------------------------------------------------------------------------------------------------------------------------
local function notes()
 local N={Shown={}}
 function N:Show(player,text,color,seconds)N.Shown[#N.Shown+1]={Player=player,Text=text,Color=color,Seconds=seconds}end
 return N
end
local function makeServer(backend,opts)
 opts=opts or{}
 local s={Clock=opts.Clock or HH.clock(T0),Art=fakeArt(),Avatars=fakeAvatars(),Notes=notes(),Announcer=fakeAnnouncer()}
 s.Backend=backend
 s.Svc=HH.memoryService(backend)
 s.Store=Store.new({Service=s.Svc,Clock=s.Clock.now})
 local seed=opts.Seed or 1
 local rng={NextNumber=function()seed=(seed*16807)%2147483647;return seed/2147483647 end}
 local folder=R.new('Folder');folder.Name='ChestChaseMap'
 local lobby=R.new('Folder');lobby.Name='Lobby';lobby.Parent=folder
 local floor=R.new('Part');floor.Name='LobbyFloor';floor.Size=V3(680,1,524);floor.CFrame=CF(0,3.5,-361);floor.Parent=lobby
 s.Map={MapRoot=folder}
 s.Service=Service.new(Config,{},s.Notes,s.Map,{Clock=s.Clock.now,Time=s.Clock.time,Store=s.Store,Art=s.Art,Avatars=s.Avatars,FruitList=opts.List or list,NoLoop=true,Random=rng,Announce=s.Announcer.Announce})
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
 check(pd.Text and pd.Text.State=='Empty'and fd.Text.State=='Empty'and pd.Text.Label.Name.Text=='Nobody yet'and pd.Text.Plaque.Name.Text=='Nobody yet'and pd.Text.Plaque.Title.Text=='BEST PULL'and pd.Text.Label.Title.Text=='BEST PULL'and fd.Text.Plaque.Title.Text=='BIGGEST FRUIT TODAY','both pedestals show the empty state at once (the plaque and the label; R153: "BEST PULL", no "today")')
 check(pd.TintState=='Empty'and fd.TintState=='Ready','the empty BEST PULL is calm; the empty fruit is lit (the fruit is shown anyway)')
 check(pd.Model:GetAttribute('Rev')==1 and fd.Model:GetAttribute('NextAt')==Rules.NextAt(DAY)and fd.Model:GetAttribute('FooterPrefix')=='New fruit in ','the fruit display\'s attributes are set as ever (Rev, NextAt = the next midnight, "New fruit in ")')
 check(pd.Model:GetAttribute('NextAt')==T0+600 and pd.Model:GetAttribute('FooterPrefix')=='new board in 'and snap.Window==T0//600,'R153: the pull display counts to the next wall-clock 10-minute mark ('..tostring(pd.Model:GetAttribute('NextAt')-T0)..' s away), in the words "new board in "')
 check(pd.Text.Label.Footer.Text=='new board in 10:00'and pd.Text.Plaque.Footer.Text=='new board in 10:00'and fd.Text.Label.Footer.Text=='New fruit in 21h 0m','the footers read "new board in 10:00" (03:00:00: a whole window to go) and, as ever, "New fruit in 21h 0m"')
 check(fd.Model:GetAttribute('FruitId')==todayFruit,'the fruit display tells the client which fruit it is')
 check(#A.Art.ItemBuilds==2,'each display builds its item once')
 local kinds={};for _,b in ipairs(A.Art.ItemBuilds)do kinds[b.Kind]=b.Spec end
 check(kinds.Pull.Mystery==true and kinds.Pull.Calm==true and kinds.Pull.Kind=='Seed'and kinds.Fruit.Kind=='Fruit'and kinds.Fruit.Id==todayFruit and kinds.Fruit.Coat=='None'and not kinds.Fruit.Calm,'empty: a black mystery seed with its light off; the day\'s fruit lit')
 check(#A.Avatars.Builds==2 and A.Avatars.Builds[1].Silhouette and A.Avatars.Builds[2].Silhouette,'both show the black silhouette while nobody holds the spot')
 check(A.Avatars.Last.Height==Rules.AvatarHeight and Rules.AvatarHeight==25 and A.Avatars.Last.Turn==Rules.AvatarTurn,'at the giant size (25 studs), turned toward the pedestal')
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
 check(pd.Text.State=='Champion'and pd.Text.Label.Name.Text=='Ann'and pd.Text.Plaque.Name.Text=='Ann'and pd.Text.Label.Info.Text=='Fire Pepper'and pd.Text.Plaque.Line.Text=='Mythic · '..W.module('SeedRarity153').Text('FirePepperSeed'),'the plaque and the label say "Ann", the seed ("Fire Pepper") and the rarity and chance (R153: the seed\'s fixed chance, 1/800, not the Pack03 one the pull is ranked by: '..Rules.OddsText(want)..')')
 check(pd.Model:GetAttribute('Champion')=='Ann'and pd.Model:GetAttribute('Rarity')=='Mythic'and pd.Model:GetAttribute('ChampionUserId')==11 and pd.Model:GetAttribute('Rev')==2,'the display\'s attributes name the champion and Rev goes up')
 check(pd.TintState=='Ready'and pd.Accent[1]==Rules.RarityColor('Mythic')[1],'tinted in the rarity\'s colour')
 check(#A.Art.ItemBuilds==before+1 and A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Id=='FirePepperSeed'and A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Mystery==false,'one new item: the seed itself (not the mystery one)')
 check(A.Avatars.Builds[#A.Avatars.Builds].Uid==11 and A.Art.Built.Pull.Avatar:GetAttribute('UserId')==11,'and Ann\'s avatar (by user id)')
 local an=A.Avatars.Animated[#A.Avatars.Animated]
 check(an and an.Uid==11 and an.Model==A.Art.Built.Pull.Avatar and an.Placed and an.InDisplay and A.Art.Built.Pull.Avatar:GetAttribute('AvatarMode')=='dance','the avatar is told to dance, after it was placed and put in the display (an Animator plays only in the world)')
 check(A.Service.AvatarMode and A.Service.AvatarMode.Pull=='dance'and A.Service:StatusText():find('AvatarMode dance '..Rules.DanceIds[Rules.DanceIndex(11,1)]:match('%d+'),1,true),'and the owner\'s hubdisplays line says so, with the dance id')
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
 check(A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Coat=='Gold','and the showcase item is built with the coat')
 -- fruit
 local fid=svc.Board.FruitId
 check(not svc:NoteHarvest(p1,{SeedId='NoSuchSeed',FruitScale=3}),'a fruit of another type is ignored (one comparison)')
 check(not svc:NoteHarvest(p1,{SeedId=fid,FruitScale=9,TestGrant=true})and svc:Snapshot().Fruit.Record==nil,'R152: a fruit grown from a seed an owner gave (TestGrant on the harvest) is not counted, with no session taint')
 check(svc:NoteHarvest(p1,{SeedId=fid,FruitScale=2,Mutation='None',Weather='None'}),'today\'s fruit is counted')
 local fr=svc:Snapshot().Fruit.Record
 check(fr.Name=='Ann'and math.abs(fr.Kg-2*Weight.FruitBase(fid))<1e-9,'with its weight = base kg x its size')
 local fd=A.Art.Built.Fruit
 check(fd.Text.State=='Champion'and fd.Text.Label.Info.Text:find(Rules.KgText(fr.Kg),1,true)==1 and fd.Text.Label.Name.Text=='Ann'and fd.Text.Plaque.Name.Text=='Ann'and fd.Text.Plaque.Line.Text:find('Today: ',1,true)==1,'the label shows the winner and the weight; the plaque the winner and the fruit of the day')
 check(not svc:NoteHarvest(p2,{SeedId=fid,FruitScale=1.5}),'a lighter fruit is recorded for Ben but changes nothing... (counted as ignored: lighter than this server\'s own)')
 check(svc:NoteHarvest(p2,{SeedId=fid,FruitScale=6,Mutation='Gold',Weather='Drippy'})and svc:Snapshot().Fruit.Record.Name=='Ben','a heavier one takes the spot')
 check(svc:Snapshot().Fruit.Record.Coat=='Gold'and A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Coat=='Gold'and A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Kind=='Fruit','its coat is kept and the giant fruit is built with it')
 check(fd.Text.Label.Info.Text==Rules.KgText(svc:Snapshot().Fruit.Record.Kg)..' · Gold · Drippy','the label tells the coat and the weather after the weight')
 check(not svc:NoteHarvest(p1,{SeedId=fid}) and not svc:NoteHarvest(p1,{SeedId=fid,FruitScale=0/0})and not svc:NoteHarvest(p1,nil)and not svc:NoteHarvest(nil,{SeedId=fid,FruitScale=2}),'a harvest without a size, a NaN size, nothing or no player is refused')
 -- a fruit that took the spot but is not the biggest of a pair at the same weight
 local f1=svc:NoteHarvest(p3,{SeedId=fid,FruitScale=6,Mutation='Gold',Weather='Drippy'})
 check(not f1,'p3 is tainted: still refused')
end

-- 3. The record line: ONE chat line through PullAnnouncer, never a notice of the hub's own -----------------------------------------------------------------------------------
do
 R.advance(60) -- (the chimes the earlier sections' pulls scheduled play out first, so they are not counted below)
 local backend=HH.backend();A=makeServer(backend);backend.Now=function()return A.Clock.t end
 A.Service:Start()
 local svc=A.Service
 local players=H.players -- everyone created so far lives in the Players service
 local remote=remotes:FindFirstChild('HubDisplayCelebrate')
 local fired={}
 check(remote and remote:IsA('RemoteEvent'),'the celebration remote ChestChaseRemotes.HubDisplayCelebrate exists')
 remote.FireClient=function(_,player,payload)fired[#fired+1]={Player=player,Payload=payload,At=R.clock}end
 local q1=HH.player(21,'Zed')
 local n0=#A.Notes.Shown;local everyone=#H.players
 local t0=R.clock
 svc:NotePull(q1,reward('FirePepperSeed','Mythic'),info())
 check(#A.Notes.Shown==n0,'a new Best Pull shows NO notice of the hub\'s own (the old banner is gone: no second message next to the chat line)')
 local spec=A.Announcer.Calls[1]
 check(#A.Announcer.Calls==1 and spec.Kind=='Record'and spec.Record=='BestPull'and spec.Player==q1 and spec.SeedId=='FirePepperSeed'and spec.AfterReveal==true and spec.To==nil and spec.Scope==nil,'it is announced ONCE through PullAnnouncer.Announce: {Kind=Record, Record=BestPull, Player=the puller, SeedId, AfterReveal=true} and the scope is the rules\' (none given)')
 local wait=A.Announcer.Waits[1]
 check(math.abs(wait-(Announce.RevealDelay('Mythic')+Announce.Setting('RecordLag')))<1e-9,'a record that comes from a pull waits for the puller\'s reveal (RevealDelay of a Mythic + the record lag = '..string.format('%.2f',wait)..' s)')
 check(#fired==0,'the celebration chime has not played yet (the puller\'s reveal is still playing)')
 R.advance(wait-.05);check(#fired==0,'... nor just before the line')
 R.advance(.1)
 check(#fired==everyone and fired[1].Payload.Kind=='Pull'and fired[1].Payload.Name=='Zed','in step with the line the chime goes to everyone in the server ('..#fired..' of '..everyone..'; the client plays the game\'s GemClaim)')
 -- the gap: a second champion within 8 s: the display changes, no second announcement
 svc:NotePull(q1,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 check(#A.Announcer.Calls==1,'a second champion within 8 s: the display changes, no second announcement')
 check(svc:Snapshot().Pull.Record.Rarity=='King','(the display did change)')
 A.Clock.advance(9)
 svc:NotePull(q1,reward('SolarStarfruitSeed','King',{SeedScale=5}),info({Stage=2,Variant='Pack01'}))
 check(#A.Announcer.Calls==2 and#A.Announcer.Sent==2,'after the gap the next champion is announced again')
 check(#A.Notes.Shown==n0,'(and still no notice of the hub\'s own)')
 -- the announcer decides who hears it (PullAnnounceRules.RecordScope): a Common takes the spot silently, and so does anything below Legendary
 local backend2=HH.backend();local B=makeServer(backend2);backend2.Now=function()return B.Clock.t end;B.Service:Start()
 local q2=HH.player(22,'Yan')
 B.Service:NotePull(q2,reward('SunflowerSeed','Common'),info({Stage=1,Variant='Pack01'}))
 check(B.Service:Snapshot().Pull.Record.Rarity=='Common'and#B.Announcer.Sent==0 and#B.Notes.Shown==0,'a Common pull takes the spot silently (the display changes; the announcer says nobody hears it)')
 B.Service:NotePull(q2,reward('AppleSeed','Rare'),info({Stage=1,Variant='Pack01'}))
 check(B.Service:Snapshot().Pull.Record.Rarity=='Rare'and#B.Announcer.Sent==0,'a Rare is silent too: chat records start at Legendary (PullAnnounceRules.InServerMinRarity), not at the hub\'s old Rare notice')
 B.Service:NotePull(q2,reward('FirePepperSeed','Mythic'),info({Stage=4,Variant='Pack01'}))
 check(#B.Announcer.Sent==1 and B.Announcer.Sent[1].SeedId=='FirePepperSeed','a Mythic right after is announced (a refused record does not use up the gap)')
 -- the fruit record: this server, at once (a harvest has no reveal)
 local fid=B.Service.Board.FruitId
 B.Service:NoteHarvest(q2,{SeedId=fid,FruitScale=5.5,Mutation='None'})
 local last=B.Announcer.Sent[#B.Announcer.Sent]
 check(last.Record=='BiggestFruit'and last.Kind=='Record'and last.Player==q2 and last.AfterReveal==nil and last.To==nil,'a biggest-fruit record: BiggestFruit, the picker, no reveal to wait for ('..tostring(last.Record)..')')
 check(B.Announcer.Waits[#B.Announcer.Waits]==0 and#B.Notes.Shown==0,'... it goes out at once and the hub shows no notice')
 -- R153: a pull taken in another server never arrives here (BEST PULL is each server's own): nothing shown, nothing announced, nothing written
 local backend3=HH.backend();local S1=makeServer(backend3,{Seed=3});local S2=makeServer(backend3,{Seed=9})
 backend3.Now=function()return S1.Clock.t end
 S1.Service:Start();S2.Service:Start()
 S1.Service:NotePull(q1,reward('FirePepperSeed','Mythic'),info())
 step(S1,5)
 step(S2,70)
 check(S1.Service:Snapshot().Pull.Record and S2.Service:Snapshot().Pull.Record==nil and S2.Art.Built.Pull.Text.Label.Name.Text=='Nobody yet'and#S2.Announcer.Calls==0 and#S2.Notes.Shown==0,'a pull taken in another server never shows here (and so nothing is announced here)')
 check(backend3.Calls.Update==0 and backend3.peek(Rules.StoreName,'d'..DAY)==nil,'and was never written anywhere')
 -- the announcer failing or missing never breaks an event
 local backend4=HH.backend();local C=makeServer(backend4);C.Service.Announce=function()error('announcer exploded')end;C.Service:Start()
 local okC,resC=C.Service:NotePull(q1,reward('FirePepperSeed','Mythic'),info())
 check(okC==true and resC=='took'and C.Service:Snapshot().Pull.Record.Name=='Zed','an announcer that throws: the pull is still counted and shown')
 C.Service.Announce=function()return false,'no announcer'end;C.Clock.advance(9)
 check(C.Service:NotePull(q1,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))and#C.Notes.Shown==0,'an announcer that says no: still counted, still no hub notice')
 -- a preview of another day announces nothing (nothing about it is real)
 local backend5=HH.backend();local P5=makeServer(backend5);P5.Service:Start();P5.Service:SetDayOffset(1)
 P5.Service:NotePull(q1,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 P5.Service:NoteHarvest(q1,{SeedId=P5.Service.Board.FruitId,FruitScale=9,Mutation='None'})
 check(P5.Service:Snapshot().Pull.Record and P5.Service:Snapshot().Fruit.Record and#P5.Announcer.Calls==0,'while previewing another day a real pull and a real harvest are recorded but announce nothing')
end

-- 4. The day (the fruit board) and midnight, which is also a 10-minute mark (the pull board) ---------------------------------------------------------------------------------
do
 local backend=HH.backend();A=makeServer(backend,{Clock=HH.clock(DAY*86400+86400-100)});backend.Now=function()return A.Clock.t end
 local svc=A.Service;svc:Start()
 local q=HH.player(31,'Dee')
 svc:NotePull(q,reward('FirePepperSeed','Mythic'),info());svc:NoteHarvest(q,{SeedId=svc.Board.FruitId,FruitScale=3})
 check(svc:Snapshot().Pull.Record and svc:Snapshot().Fruit.Record,'before midnight: both boards hold something')
 local dayBefore=svc:Snapshot().Day;local fruitBefore=svc:Snapshot().FruitId
 local revBefore=A.Art.Built.Pull.Model:GetAttribute('Rev')
 step(A,50);check(svc:Snapshot().Day==dayBefore,'50 s later it is still the same day')
 step(A,60)
 local snap=svc:Snapshot()
 check(snap.Day==dayBefore+1,'at midnight UTC the day number moves on')
 check(snap.Pull.Record==nil and snap.Fruit.Record==nil,'both boards are empty (midnight is a 10-minute mark too: the pull window ended with the day)')
 check(snap.FruitId==Rules.FruitForDay(list,dayBefore+1)and snap.FruitId~=fruitBefore,'the fruit of the day changed to the next one in the rotation ('..tostring(fruitBefore)..' -> '..tostring(snap.FruitId)..')')
 check(A.Art.Built.Pull.Text.State=='Empty'and A.Art.Built.Fruit.Text.State=='Empty'and A.Art.Built.Pull.Model:GetAttribute('Rev')>revBefore,'the signs are empty again and Rev went up')
 check(A.Art.ItemBuilds[#A.Art.ItemBuilds].Spec.Id==snap.FruitId or A.Art.ItemBuilds[#A.Art.ItemBuilds-1].Spec.Id==snap.FruitId,'the fruit display builds the new fruit')
 check(A.Art.Built.Fruit.Model:GetAttribute('NextAt')==Rules.NextAt(dayBefore+1)and A.Art.Built.Pull.Model:GetAttribute('NextAt')==Rules.PullWindowEnd(A.Clock.unix),'the fruit display counts to the next midnight, the pull display to the next 10-minute mark')
 -- yesterday's fruit no longer counts
 check(not svc:NoteHarvest(q,{SeedId=fruitBefore,FruitScale=9}),'yesterday\'s fruit type is not today\'s: ignored')
 -- an event right after midnight, before a Step, counts for the new window / the new day
 local backend2=HH.backend();local c2=HH.clock(DAY*86400+86399);local B=makeServer(backend2,{Clock=c2});backend2.Now=function()return c2.t end;B.Service:Start()
 B.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info())
 check(B.Service:Snapshot().Pull.Record.At==c2.unix,'(a pull in the last second of the old window is that window\'s)')
 c2.advance(2)
 B.Service:NotePull(HH.player(32,'Eve'),reward('AppleSeed','Rare'),info({Stage=1,Variant='Pack01'}))
 check(B.Service:Snapshot().Pull.Record and B.Service:Snapshot().Pull.Record.Name=='Eve'and B.Service:Snapshot().Pull.Record.At==c2.unix and B.Service:Snapshot().Window==Rules.PullWindowIndex(c2.unix),'a pull in the first seconds of the new window (no Step yet) is the new window\'s: the old Mythic is gone, even though this one is worse')
 B.Service:NoteHarvest(q,{SeedId=Rules.FruitForDay(list,DAY+1),FruitScale=3})
 check(B.Service:Snapshot().Day==DAY+1 and B.Service:Snapshot().Fruit.Record and B.Service:Snapshot().Fruit.Record.At==c2.unix,'a harvest in the first seconds of the new day (no Step yet) is the new day\'s')
 -- the shared document is per day, and holds the fruit only
 step(B,10)
 local doc=backend2.peek(Rules.StoreName,'d'..(DAY+1))
 check(doc~=nil and doc.fruit~=nil and doc.pull==nil and backend2.peek(Rules.StoreName,'d'..DAY)==nil,'the fruit is written to the new day\'s key (and no pull with it)')
 -- the shared board of the new day is read after rollover
 local backend3=HH.backend();local c3=HH.clock(DAY*86400+86390);local S1=makeServer(backend3,{Clock=c3,Seed=2});backend3.Now=function()return c3.t end
 HH.memoryService(backend3):GetHashMap(Rules.StoreName):SetAsync('d'..(DAY+1),Rules.StoreDoc({fruit=Rules.CleanFruit({Uid=77,Name='Early',Id=Rules.FruitForDay(list,DAY+1),Scale=3,Coat='None',Weather='None',At=5})}),1e6)
 S1.Service:Start();step(S1,5)
 check(S1.Service:Snapshot().Fruit.Record==nil,'before midnight yesterday\'s key is the only one read')
 step(S1,30)
 check(S1.Service:Snapshot().Fruit.Record and S1.Service:Snapshot().Fruit.Record.Name=='Early','after midnight the new key is read at the next step')
end

-- 5. Cross-server: the FRUIT is shared, BEST PULL is not (R153) ---------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend()
 local ca,cb=HH.clock(T0),HH.clock(T0);backend.Now=function()return ca.t end
 local SA=makeServer(backend,{Clock=ca,Seed=5});local SB=makeServer(backend,{Clock=cb,Seed=77})
 SA.Service:Start();SB.Service:Start()
 local pa,pb=HH.player(41,'Ava'),HH.player(42,'Bo')
 -- a pull is instant, local and never written
 SA.Service:NotePull(pa,reward('FirePepperSeed','Mythic'),info())
 check(not SA.Service:Snapshot().Pull.Unsynced and backend.Calls.Update==0,'an event is instant and local; nothing is written')
 SA.Service:Step()
 check(backend.Calls.Update==0 and backend.peek(Rules.StoreName,'d'..DAY)==nil,'R153: and the next step writes nothing for a pull either (no compare-and-set, no key)')
 -- B reads the shared board about once a minute and never gets Ava's pull
 for _=1,26 do cb.advance(5);SB.Service:Step()end
 check(backend.Calls.Get>=2,'(server B did read the shared board: the fruit\'s)')
 check(SB.Service:Snapshot().Pull.Record==nil and SB.Art.Built.Pull.Text.Label.Name.Text=='Nobody yet'and SB.Art.Built.Pull.Model:GetAttribute('Rev')==1,'but after two minutes it still shows nobody for BEST PULL: Ava\'s pull is in server A only')
 check(#SB.Notes.Shown==0 and#SB.Announcer.Calls==0,'B posted no notice and announced nothing')
 -- B takes its own spot with a better pull: the two servers each show their own best
 SB.Service:NotePull(pb,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 check(SB.Art.Built.Pull.Text.Label.Name.Text=='Bo','B\'s own King shows at once on B')
 for _=1,26 do ca.advance(5);cb.advance(5);SA.Service:Step();SB.Service:Step()end
 check(SA.Art.Built.Pull.Text.Label.Name.Text=='Ava'and SA.Service:Snapshot().Pull.Record.Name=='Ava'and SB.Service:Snapshot().Pull.Record.Name=='Bo','two minutes on A still shows Ava\'s Mythic and B Bo\'s King: each server has its own board')
 check(#SA.Announcer.Calls==1 and SA.Announcer.Calls[1].Player==pa and#SB.Announcer.Calls==1 and SB.Announcer.Calls[1].Player==pb,'each announced only its own pull')
 check(backend.Calls.Update==0,'and still nothing was written')
 -- fruit across servers: the heavier wins (as ever)
 local fid=SA.Service.Board.FruitId
 SA.Service:NoteHarvest(pa,{SeedId=fid,FruitScale=3});SB.Service:NoteHarvest(pb,{SeedId=fid,FruitScale=5})
 SA.Service:Step();cb.advance(5);SB.Service:Step();ca.advance(60);SA.Service:Step()
 local fa=SA.Service:Snapshot().Fruit;local stored=backend.peek(Rules.StoreName,'d'..DAY)
 check(fa.Record and fa.Record.Name=='Bo'and stored.fruit.Name=='Bo'and stored.pull==nil,'the heavier fruit from the other server wins on both (and the document holds the fruit only)')
 -- the race: both servers get a fruit in the same second and write at the same moment
 backend=HH.backend();ca=HH.clock(T0);cb=HH.clock(T0);backend.Now=function()return ca.t end
 SA=makeServer(backend,{Clock=ca,Seed=5});SB=makeServer(backend,{Clock=cb,Seed=77});SA.Service:Start();SB.Service:Start()
 SA.Service:NoteHarvest(pa,{SeedId=fid,FruitScale=3})
 SB.Service:NoteHarvest(pb,{SeedId=fid,FruitScale=9})
 backend.Race=function()SB.Service:Step()end -- (B writes its heavier fruit between A's read and A's commit)
 SA.Service:Step()
 check(backend.peek(Rules.StoreName,'d'..DAY).fruit.Name=='Bo','the heavier fruit is in the store even though A started writing first')
 check(SA.Service:Snapshot().Fruit.Record.Name=='Bo'and SA.Art.Built.Fruit.Text.Label.Name.Text=='Bo','A reads the winner back at once (no wait for a poll) and shows it')
 check(not SA.Service:Snapshot().Fruit.Unsynced,'and has nothing left to write')
end

-- 6. Polling and writes (the fruit's; R153: a pull costs none) -----------------------------------------------------------------------------------------------------------
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
 -- writes are coalesced: ten heavier fruits in a few seconds are not ten writes
 local backend3=HH.backend();local c3=HH.clock(T0);backend3.Now=function()return c3.t end
 local S=makeServer(backend3,{Clock=c3,Seed=5});S.Service:Start()
 local q=HH.player(51,'Cat');local fid=S.Service.Board.FruitId
 for i=1,10 do
  S.Service:NoteHarvest(q,{SeedId=fid,FruitScale=i})
  c3.advance(.3);S.Service:Step()
 end
 check(backend3.Calls.Update<=2,'ten heavier fruits in 3 seconds are at most two writes ('..backend3.Calls.Update..')')
 c3.advance(4);S.Service:Step()
 check(not S.Service:Snapshot().Fruit.Unsynced and backend3.peek(Rules.StoreName,'d'..DAY).fruit.Scale==10,'and the last (heaviest) one ends up in the store')
 -- R153: ten better pulls in 3 seconds are no write at all
 local backend3b=HH.backend();local c3b=HH.clock(T0);backend3b.Now=function()return c3b.t end
 local Sb=makeServer(backend3b,{Clock=c3b,Seed=5});Sb.Service:Start()
 for i=1,10 do
  Sb.Service:NotePull(q,reward('SunflowerSeed','Common',{SeedScale=i}),info({Stage=1,Variant='Pack01'}))
  c3b.advance(.3);Sb.Service:Step()
 end
 c3b.advance(4);Sb.Service:Step()
 check(Sb.Service:Snapshot().Pull.Record and Sb.Service:Snapshot().Pull.Record.Scale==10 and backend3b.Calls.Update==0 and backend3b.Calls.Set==0 and backend3b.Calls.Remove==0,'R153: ten better pulls in 3 seconds are no write at all (the board is local: the heaviest is shown, nothing is stored)')
 -- an hour with events: requests stay far below the budget; the pulls add none
 local backend4=HH.backend();local c4=HH.clock(T0);backend4.Now=function()return c4.t end
 local S4=makeServer(backend4,{Clock=c4,Seed=5});S4.Service:Start()
 local fid4=S4.Service.Board.FruitId;local harvests=0
 for t=1,720 do
  c4.advance(5)
  if t%10==0 then S4.Service:NotePull(q,reward('SunflowerSeed','Common',{SeedScale=.35+t/1000}),info({Stage=1,Variant='Pack01'}))end
  if t%10==5 then harvests+=1;S4.Service:NoteHarvest(q,{SeedId=fid4,FruitScale=.35+t/100})end
  S4.Service:Step()
 end
 local perMinute=(backend4.Calls.Get+backend4.Calls.Update)/60
 check(perMinute<=6,'an hour with a new best pull and a new best fruit every 50 s costs '..string.format('%.1f',perMinute)..' MemoryStore requests a minute (quota: 1000 + 100 per player)')
 check(backend4.Calls.Update<=harvests,'... and the writes are the fruit\'s alone: '..backend4.Calls.Update..' writes for '..harvests..' fruit records, none for the 72 pulls')
 local pullOnly=HH.backend();local c5=HH.clock(T0);pullOnly.Now=function()return c5.t end
 local S5=makeServer(pullOnly,{Clock=c5,Seed=5});S5.Service:Start()
 for t=1,720 do c5.advance(5);if t%10==0 then S5.Service:NotePull(q,reward('SunflowerSeed','Common',{SeedScale=.35+t/1000}),info({Stage=1,Variant='Pack01'}))end;S5.Service:Step()end
 check(pullOnly.Calls.Update==0 and pullOnly.Calls.Set==0 and pullOnly.Calls.Remove==0,'a server that only has pulls for an hour (and a window every 10 minutes) writes nothing, ever ('..pullOnly.Calls.Get..' reads: the fruit\'s poll, about one a minute)')
end

-- 7. Failures (the fruit's shared board; the pull board does not notice) -------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local ca=HH.clock(T0);backend.Now=function()return ca.t end
 local S=makeServer(backend,{Clock=ca,Seed=5});S.Service:Start()
 backend.Fail=function()return'HTTP 500 InternalServerError'end
 local q=HH.player(61,'Dot');local fid=S.Service.Board.FruitId
 S.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info())
 S.Service:NoteHarvest(q,{SeedId=fid,FruitScale=3})
 check(S.Art.Built.Pull.Text.Label.Name.Text=='Dot'and S.Art.Built.Fruit.Text.Label.Name.Text=='Dot','MemoryStore down: this server still shows its own best (pull and fruit)')
 for _=1,6 do ca.advance(5);S.Service:Step()end
 local snap=S.Service:Snapshot()
 check(snap.Store.Failures>=1 and snap.Fruit.Unsynced and snap.Fruit.Record.Name=='Dot','the failure is counted and the fruit stays unsynced')
 check(snap.Pull.Record.Name=='Dot'and not snap.Pull.Unsynced,'the pull board has nothing waiting: it was never going to the store')
 local calls=backend.Calls.Get+backend.Calls.Update
 for _=1,4 do ca.advance(5);S.Service:Step()end
 check(backend.Calls.Get+backend.Calls.Update-calls<=2,'while it is down the server backs off: it is not asking every step ('..(backend.Calls.Get+backend.Calls.Update-calls)..' requests in 20 s)')
 check(S.Service:StatusText():find('FAILING',1,true),'the status line says the shared board is failing')
 -- a heavier fruit in another server at the same time, then MemoryStore comes back
 local other=HH.memoryService(backend):GetHashMap(Rules.StoreName)
 backend.Fail=nil
 other:SetAsync('d'..DAY,Rules.StoreDoc({fruit=Rules.CleanFruit({Uid=70,Name='Far',Id=fid,Scale=20,Coat='None',Weather='None',At=T0})}),1e6)
 for _=1,80 do ca.advance(5);S.Service:Step()end
 snap=S.Service:Snapshot()
 check(snap.Store.Failures==0 and snap.Fruit.Record.Name=='Far'and S.Art.Built.Fruit.Text.Label.Name.Text=='Far','when it recovers it catches up with the shared board (a heavier fruit from another server beats ours)')
 check(not snap.Fruit.Unsynced and backend.peek(Rules.StoreName,'d'..DAY).fruit.Name=='Far','and the better shared record was kept (our fruit never overwrote it)')
 -- 80 steps are 400 s: still the same window: the pull is as it was
 check(S.Service:Snapshot().Pull.Record and S.Service:Snapshot().Pull.Record.Name=='Dot','(and the pull board was never touched by any of it)')
 -- a local record that is better is written after the outage
 backend.Fail=function()return'429 throttled'end
 S.Service:NoteHarvest(q,{SeedId=fid,FruitScale=40})
 for _=1,5 do ca.advance(5);S.Service:Step()end
 check(S.Service:Snapshot().Store.Throttled and S.Service:Snapshot().Fruit.Unsynced,'a throttled store keeps the record unsynced and waits')
 backend.Fail=nil
 for _=1,40 do ca.advance(5);S.Service:Step()end
 check(not S.Service:Snapshot().Fruit.Unsynced and backend.peek(Rules.StoreName,'d'..DAY).fruit.Name=='Dot'and backend.peek(Rules.StoreName,'d'..DAY).fruit.Scale==40,'later the heavier fruit goes in')
 -- an error thrown out of nowhere never stops the step
 S.Service.Store.Read=function()error('boom')end;S.Service.Store.Merge=function()error('boom')end
 S.Service:NoteHarvest(q,{SeedId=fid,FruitScale=45})
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
 check(#S.Art.ItemBuilds==n0+1 and #S.Avatars.Builds==v0+1,'polling the shared board for a minute (the fruit\'s) rebuilds nothing: a pull is not part of it')
 local rev=S.Art.Built.Pull.Model:GetAttribute('Rev')
 S.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info())
 check(#S.Art.ItemBuilds==n0+1 and S.Art.Built.Pull.Model:GetAttribute('Rev')==rev,'an equal (not better) pull changes nothing')
 -- R153: the same champion with a better pull keeps the avatar that stands there (the dance every screen plays on it goes on)
 local before=S.Art.Built.Pull.Avatar;local b0=#S.Avatars.Builds;local a0=#S.Avatars.Animated;local built0=S.Art.Built.Pull.Model:GetAttribute('Built')
 S.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info({Variant='Pack01'}))
 check(S.Service:Snapshot().Pull.Record.Odds<P.SeedOdds(Config,4,'Pack03',1,P.OddsVersion)['FirePepperSeed']and S.Art.Built.Pull.Avatar==before and before.Parent~=nil and #S.Avatars.Builds==b0 and #S.Avatars.Animated==a0,'the same champion with a rarer pull: the same avatar stays (no new rig, nothing made ready again)')
 check(#S.Art.ItemBuilds==n0+2 and S.Art.Built.Pull.Model:GetAttribute('Built')==built0+1,'(the item is the new one, and the display counts as built)')
 -- two champions in a row while the first avatar is still loading: only the second is installed
 S.Avatars.Yield=true
 S.Service:NotePull(HH.player(70,'Dee'),reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
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
 -- an avatar being made ready may yield (a stand-in does): a champion overtaken meanwhile is dropped too, and only the newest counts as built
 S.Avatars.AnimateYield=true
 built0=S.Art.Built.Pull.Model:GetAttribute('Built')or 0
 S.Service:NotePull(HH.player(75,'Hal'),reward('SolarStarfruitSeed','King',{SeedScale=11}),info({Stage=2,Variant='Pack01'}))
 S.Service:NotePull(HH.player(76,'Ida'),reward('SolarStarfruitSeed','King',{SeedScale=13}),info({Stage=2,Variant='Pack01'}))
 check(#S.Avatars.AnimatePending==2 and S.Art.Built.Pull.Model:GetAttribute('Built')==built0,'two champions\' avatars are being made ready (nothing is counted as built yet)')
 S.Avatars.AnimateYield=false
 for i=#S.Avatars.AnimatePending,1,-1 do coroutine.resume(S.Avatars.AnimatePending[i])end
 check(S.Art.Built.Pull.Model:GetAttribute('Built')==built0+1 and d.Avatar:GetAttribute('UserId')==76,'when they finish only the newer champion (Ida) counts: one built, hers on the display')
 -- the same for a window mark (R153) while a build is in flight: the champion that was loading never shows on the new empty board
 S.Avatars.Yield=true
 local pendingBefore=#S.Avatars.Pending
 S.Service:NotePull(HH.player(73,'Gus'),reward('SolarStarfruitSeed','King',{SeedScale=9}),info({Stage=2,Variant='Pack01'}))
 ca.advance(Rules.PullSecondsLeft(ca.unix));S.Service:Step() -- (to the next :00 / :10 / :20 ...)
 S.Avatars.Yield=false
 for i=pendingBefore+1,#S.Avatars.Pending do pcall(coroutine.resume,S.Avatars.Pending[i])end
 local snap=S.Service:Snapshot()
 check(snap.Pull.Record==nil and d.Avatar and d.Avatar:GetAttribute('UserId')==0 and d.Avatar:GetAttribute('Fallback')==true,'R153: a champion that was loading when the window ended does not show on the new empty board (a silhouette does)')
 local liveRigs=0;for _,m in ipairs(S.Avatars.Models)do if not m._destroyed then liveRigs+=1 end end
 check(liveRigs==2,'and every rig that was made, except the one standing on each display, was destroyed ('..liveRigs..' alive of '..#S.Avatars.Models..' made)')
 -- the same for a day change while a build is in flight
 S.Avatars.Yield=true
 pendingBefore=#S.Avatars.Pending
 S.Service:NotePull(HH.player(74,'Hex'),reward('SolarStarfruitSeed','King',{SeedScale=9}),info({Stage=2,Variant='Pack01'}))
 ca.advance(86400);S.Service:Step()
 S.Avatars.Yield=false
 for i=pendingBefore+1,#S.Avatars.Pending do pcall(coroutine.resume,S.Avatars.Pending[i])end
 snap=S.Service:Snapshot()
 check(snap.Pull.Record==nil and d.Avatar and d.Avatar:GetAttribute('UserId')==0,'a champion that was loading at midnight does not show on the new empty board (a silhouette does)')
 -- an avatar that could not dance is the static pose: the service just records it
 S.Avatars.AnimateMode='pose';S.Service:NotePull(HH.player(77,'Jo'),reward('SolarStarfruitSeed','King',{SeedScale=15}),info({Stage=2,Variant='Pack01'}))
 check(S.Service.AvatarMode.Pull=='pose'and S.Service:StatusText():find('AvatarMode pose',1,true),'an avatar that could not dance is reported as the static pose')
 S.Avatars.AnimateMode='dance'
end

-- 8b. The clients' dance reports (R153) -----------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local ca=HH.clock(T0);backend.Now=function()return ca.t end
 local S=makeServer(backend,{Clock=ca,Seed=9});S.Service:Start()
 local svc=S.Service
 local remote=remotes:FindFirstChild(Rules.ReportRemote)
 check(remote and remote:IsA('RemoteEvent')and Rules.ReportRemote=='HubDisplayAvatarReport','the report remote ChestChaseRemotes.HubDisplayAvatarReport exists')
 local owner=HH.player(91,'Owner');local other=HH.player(92,'Pal');local third=HH.player(93,'Tri')
 svc:NotePull(HH.player(90,'Champ'),reward('FirePepperSeed','Mythic'),info())
 local id=Rules.DanceIds[Rules.DanceIndex(90,1)]
 local text=svc:StatusText(owner)
 check(text:find('Pull display:',1,true)and text:find('AvatarMode dance '..id:match('%d+'),1,true)and text:find('your screen: no report yet',1,true),'before any report: the display\'s AvatarMode and dance id, "your screen: no report yet"')
 check(text:find('Fruit display:',1,true)and text:find('AvatarMode static',1,true),'(the empty fruit board\'s silhouette is static)')
 -- through the remote, as a client sends it
 remote.OnServerEvent:Fire(owner,{Kind='Pull',Mode='dance',User=90,Id=id,Loaded=true,Length=8.4321,Tries=1,Paused=false})
 local t2=svc:StatusText(owner)
 check(t2:find('your screen: dance: track loaded, Length 8.43 s, playing',1,true),'the owner\'s own screen: the track loaded, its Length, playing ('..t2:match('Pull display:[^\n]*')..')')
 check(svc:NoteReport(other,{Kind='Pull',Mode='pose',User=90,Id=Rules.DanceIds[2],Loaded=false,Length=0,Tries=4})and svc:NoteReport(third,{Kind='Pull',Mode='dance',User=90,Id=id,Loaded=true,Length=8.4,Tries=2,Paused=true}),'other players\' reports are kept')
 local t3=svc:StatusText(owner)
 check(t3:find('other screens: 1 dance, 1 pose',1,true),'and counted: "other screens: 1 dance, 1 pose"')
 local t4=svc:StatusText(other)
 check(t4:find('your screen: pose: the dance did not load (4 tries, Length 0.00), posed on that screen (id '..Rules.DanceIds[2]:match('%d+')..')',1,true),'a screen whose dance did not load says so, with its tries and the last id')
 check(svc:StatusText(third):find('your screen: dance: track loaded, Length 8.40 s, paused (reduced motion / low quality), try 2',1,true),'a paused dance says paused, and a dance that loaded on a later try says which')
 check(svc:StatusText():find('your screen',1,true)==nil and svc:StatusText():find('other screens: 2 dance, 1 pose',1,true),'without an owner (the server\'s own call) only the counts')
 -- bad reports are dropped, never an error
 local okAll=true
 for _,bad in ipairs({nil,5,'x',{},{Kind='Bogus',Mode='dance'},{Kind='Pull',Mode='jump'},{Kind='Pull'},{Kind='Pull',Mode={}},{Kind='Fruit',Mode=5}})do
  local okCall,kept=pcall(svc.NoteReport,svc,owner,bad);if not okCall or kept then okAll=false end
 end
 check(okAll and not svc:NoteReport('nobody',{Kind='Pull',Mode='dance'}),'a malformed report (no table, an unknown kind or mode, no player) is dropped')
 svc:NoteReport(owner,{Kind='Pull',Mode='dance',User=90,Id='rbxassetid://1',Loaded=true,Length=1e9,Tries=-3})
 local kept=svc.Reports[owner].Pull
 check(kept.Id==nil and kept.Length==0 and kept.Tries==0,'an id that is not one of the dances, an absurd Length or a negative try count is not believed')
 local okFire=pcall(function()remote.OnServerEvent:Fire(owner,'junk');remote.OnServerEvent:Fire(owner,{Kind='Pull',Mode='dance',Length=0/0})end)
 check(okFire,'junk through the remote never errors')
 -- at most ReportBurst a player in ReportWindow seconds
 local n=0;for i=1,60 do if svc:NoteReport(third,{Kind='Fruit',Mode='static',User=0})then n+=1 end end
 check(n<=Service.ReportBurst,'a flood is cut off ('..n..' of 60 kept in one window)')
 ca.advance(Service.ReportWindow+1)
 check(svc:NoteReport(third,{Kind='Fruit',Mode='static',User=0}),'and the next window takes reports again')
 -- a report about an avatar that is no longer there is not shown as the current one
 svc:NotePull(HH.player(95,'Newer'),reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
 check(svc:StatusText(owner):find('your screen: no report yet',1,true),'a new champion: the owner\'s old report (about the last avatar) is not shown as this one\'s')
 svc:Destroy()
 check(svc.ReportConnection==nil,'the report connection goes with the service')
end

-- 9. Owner tools ---------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local ca=HH.clock(T0);backend.Now=function()return ca.t end
 local S=makeServer(backend,{Clock=ca,Seed=5});S.Service:Start()
 local svc=S.Service
 local q=HH.player(81,'Ivy');local r=HH.player(82,'Jay')
 local chime={};remotes:FindFirstChild('HubDisplayCelebrate').FireClient=function(_,player)chime[#chime+1]=player end
 check(svc:FindSeed('FirePepperSeed')and svc:FindSeed('fire pepper')and svc:FindSeed('Fire  Pepper')and svc:FindSeed('FIREPEPPERSEED')and svc:FindSeed('Fire Pepper').id=='FirePepperSeed'and not svc:FindSeed('nonsense')and not svc:FindSeed(''),'a seed is found by id or by plant name, any case or spacing')
 check(svc:FindSeed('worldroot')~=nil,'(and by the game\'s display name: Ancient Worldroot is "Worldroot")')
 local ok,msg=svc:InjectPull(q,'fire pepper')
 check(ok and msg:find('Mythic Fire Pepper',1,true)and msg:find('this server only',1,true)and msg:find('board resets',1,true)and not msg:find('shared',1,true),'bestpull: injects a Mythic Fire Pepper, this server only, until the board resets ('..tostring(msg)..')')
 local snap=svc:Snapshot()
 check(snap.Pull.Record.Name=='Ivy'and snap.Pull.Source=='Test'and not snap.Pull.Unsynced,'it shows (as a Test record) and is never unsynced')
 step(S,15);check(backend.Calls.Update==0,'a test pull is never written to the shared store')
 check(#S.Notes.Shown==0,'a test shows no hub notice either')
 local sp=S.Announcer.Calls[#S.Announcer.Calls]
 check(#S.Announcer.Calls==1 and sp.Record=='BestPull'and sp.To==q and sp.Player==q and sp.AfterReveal==nil,'a test (bestpull) is announced PRIVATELY: To = its target only, now: never the server, never another server')
 check(#chime==1 and chime[1]==q,'... and so is the chime: only the target hears it ('..#chime..' of '..#H.players..' players)')
 local ok2,msg2=svc:InjectPull(q,'nonsense');check(not ok2 and msg2:find('Unknown seed',1,true),'an unknown seed is refused with a hint')
 local ok3=svc:InjectPull(q,'sunflower')
 check(not ok3,'a worse pull than what the board holds is refused')
 local ok4,msg4=svc:InjectPull(r,'solar starfruit')
 check(ok4 and msg4:find('this server only',1,true)and not msg4:find('shared',1,true),'a better test pull replaces the record (R153: there is no `share` for BEST PULL any more)')
 local sp4=S.Announcer.Calls[#S.Announcer.Calls]
 check(#S.Announcer.Calls==2 and sp4.To==r and sp4.Player==r and sp4.AfterReveal==nil,'its announcement is private to the target: a test never talks to the server')
 step(S,10);check(backend.Calls.Update==0 and backend.peek(Rules.StoreName,'d'..DAY)==nil,'and nothing reaches the store: a test pull is this server\'s own, like every pull')
 -- bigfruit
 local fid=svc.Board.FruitId;local base=Weight.Base('Fruit',fid)
 local okF,msgF=svc:InjectFruit(q,12.4)
 check(okF and svc:Snapshot().Fruit.Record and math.abs(svc:Snapshot().Fruit.Record.Kg-math.clamp(12.4/base,.35,50)*base)<1e-9,'bigfruit 12.4: a fruit of today\'s type ('..tostring(msgF)..')')
 check(svc:Snapshot().Fruit.Source=='Test','as a Test record')
 local spF=S.Announcer.Calls[#S.Announcer.Calls]
 check(spF.Record=='BiggestFruit'and spF.To==q and spF.Player==q,'a bigfruit test is announced privately to its target too')
 check(not svc:InjectFruit(q,'x')and not svc:InjectFruit(q,-3)and not svc:InjectFruit(q,0/0)and not svc:InjectFruit(q,0),'a bad weight is refused')
 local okG,msgG=svc:InjectFruit(r,60,'Gold')
 check(okG and svc:Snapshot().Fruit.Record.Coat=='Gold','bigfruit with a gold coat')
 -- status
 local text=svc:StatusText()
 check(text:find('Day '..DAY,1,true)and text:find('fruit of the day',1,true)and text:find('BEST PULL: Jay',1,true)and text:find('BIGGEST FRUIT: Jay',1,true)and text:find('Shared board (BIGGEST FRUIT only): ok',1,true),'hubdisplays prints the day, the fruit of the day, both champions and the store\'s health')
 check(text:find('this server only | new board in %d+:%d%d')and text:find('new fruit in %d+h'),'R153: and BEST PULL\'s own clock ("this server only | new board in 9:35") apart from the fruit\'s ("new fruit in 20h 59m")')
 check(not text:find('not shared yet',1,true),'a pull is never "not shared yet"')
 -- reset
 local removed=svc:Reset()
 check(removed==true and svc:Snapshot().Pull.Record==nil and svc:Snapshot().Fruit.Record==nil and backend.peek(Rules.StoreName,'d'..DAY)==nil,'reset empties both boards and deletes today\'s shared document (the fruit\'s)')
 check(S.Art.Built.Pull.Text.State=='Empty','the displays show the empty state again')
 svc:NoteOwnerGrant(q);svc:Reset()
 check(svc:NotePull(q,reward('FirePepperSeed','Mythic'),info()),'reset also forgets who was given items (counting starts afresh)')
 -- day preview
 svc:Reset()
 local todayId=svc.Board.FruitId
 local reqs=backend.Calls.Get+backend.Calls.Update+backend.Calls.Remove
 -- R153: a pull on the board is the pull board's own business: previewing a day does not touch it (its clock is the real one)
 svc:InjectPull(q,'fire pepper')
 local pullBefore=svc:Snapshot().Pull.Record;local pullBuilds=0;for _,b in ipairs(S.Art.ItemBuilds)do if b.Kind=='Pull'then pullBuilds+=1 end end
 local pullNextAt=S.Art.Built.Pull.Model:GetAttribute('NextAt')
 svc:SetDayOffset(1)
 local tomorrow=Rules.FruitForDay(list,DAY+1)
 check(svc:Snapshot().Day==DAY+1 and svc:Snapshot().FruitId==tomorrow and svc:Snapshot().DayOffset==1,'day +1 previews tomorrow\'s fruit ('..tostring(todayId)..' -> '..tostring(tomorrow)..')')
 check(A and S.Art.Built.Fruit.Model:GetAttribute('FruitId')==tomorrow,'the fruit display builds tomorrow\'s fruit')
 check(S.Art.Built.Fruit.Model:GetAttribute('NextAt')==Rules.NextAt(DAY+1)-86400,'its countdown still aims at the real next midnight')
 local pullBuildsAfter=0;for _,b in ipairs(S.Art.ItemBuilds)do if b.Kind=='Pull'then pullBuildsAfter+=1 end end
 check(svc:Snapshot().Pull.Record==pullBefore and pullBuildsAfter==pullBuilds and S.Art.Built.Pull.Model:GetAttribute('NextAt')==pullNextAt and pullNextAt==Rules.PullWindowEnd(ca.unix),'R153: previewing tomorrow leaves the pull board, its display and its countdown (the real next mark) exactly as they were')
 svc:InjectFruit(q,30)
 step(S,120)
 check(backend.Calls.Get+backend.Calls.Update+backend.Calls.Remove==reqs,'while previewing nothing is read from or written to the shared store')
 check(svc:StatusText():find('preview',1,true)and svc:StatusText():find('off while previewing',1,true),'the status says it is a preview')
 svc:SetDayOffset(0)
 check(svc:Snapshot().Day==DAY and svc:Snapshot().FruitId==todayId and svc:Snapshot().Fruit.Record==nil,'day 0 comes back to today with an empty fruit board')
 check(svc:Snapshot().Pull.Record==pullBefore,'(and the pull board is still the one it was)')
 local clamp=svc:SetDayOffset(1e9);check(clamp<=400,'the preview offset is limited');svc:SetDayOffset(0)
end
-- 11. R152: servers that disagree on the fruit of the day (an update that adds plants changes the list) must not starve the shared fruit board. The fruit board of a server whose fruit is not
-- the stored one stayed "unsynced" for ever (the store never holds its fruit), so every step tried again (a compare-and-set + a read) and spent this server's whole request budget (12 a
-- minute). R153: BEST PULL no longer shares anything, so the other half of the old story (its writes and reads being refused with 'budget') cannot happen: here the pull stays on its
-- server whatever the fruit boards do, and the mismatch costs a few requests a minute.
do
 local listB;for drop=1,#list do local t={};for i,id in ipairs(list)do if i~=drop then t[#t+1]=id end end;if Rules.FruitForDay(t,DAY)~=todayFruit then listB=t;break end end
 local otherFruit=listB and Rules.FruitForDay(listB,DAY)
 check(listB~=nil and otherFruit~=nil and otherFruit~=todayFruit,'(two lists with different fruits of the day: '..tostring(todayFruit)..' and '..tostring(otherFruit)..')')
 local function mismatch(label,heavyOther)
  local backend=HH.backend();local ca=HH.clock(T0);local cb=HH.clock(T0);backend.Now=function()return ca.t end
  local SA=makeServer(backend,{Clock=ca,Seed=5});local SB=makeServer(backend,{Clock=cb,Seed=77,List=listB})
  SA.Service:Start();SB.Service:Start()
  check(SA.Service.Board.FruitId==todayFruit and SB.Service.Board.FruitId==otherFruit,label..': the two servers have different fruits of the day')
  local pa,pb=HH.player(91,'Ann'),HH.player(92,'Bea')
  local function both(seconds)for _=1,math.floor(seconds/5)do ca.advance(5);cb.advance(5);SA.Service:Step();SB.Service:Step()end end
  -- A takes the shared fruit slot first; B has a fruit of ITS day and a pull
  SA.Service:NoteHarvest(pa,{SeedId=todayFruit,FruitScale=8});both(10)
  local firstFruit=backend.peek(Rules.StoreName,'d'..DAY).fruit
  check(firstFruit and firstFruit.Name=='Ann'and firstFruit.Id==todayFruit,label..': A\'s fruit is the shared one')
  SB.Service:NoteHarvest(pb,{SeedId=otherFruit,FruitScale=heavyOther and 50 or .5})
  SB.Service:NotePull(pb,reward('FirePepperSeed','Mythic'),info())
  local r0=SB.Svc.Requests
  both(60)
  local stored=backend.peek(Rules.StoreName,'d'..DAY)
  check(stored.pull==nil and SB.Service:Snapshot().Pull.Record.Name=='Bea','B\'s pull is not in the store (it never goes there) and still shows on B')
  check(stored.fruit and stored.fruit.Name=='Ann'and stored.fruit.Id==todayFruit,label..': a fruit of another type is never written over the shared one ('..tostring(stored.fruit and stored.fruit.Id)..')')
  check(not SB.Service:Snapshot().Fruit.Unsynced and SB.Service:Snapshot().Fruit.Record and SB.Service:Snapshot().Fruit.Record.Name=='Bea','B keeps its own fruit board (shown, and nothing left to write: a mismatch is not an outstanding write)')
  -- the other way round: a King pulled on A does not reach B (and B's traffic stays small)
  SA.Service:NotePull(pa,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
  both(120)
  check(SB.Service:Snapshot().Pull.Record and SB.Service:Snapshot().Pull.Record.Name=='Bea'and SA.Service:Snapshot().Pull.Record.Name=='Ann','R153: A\'s King stays on A and B keeps its own pull: BEST PULL is per server')
  local window=Rules.PullSecondsLeft(ca.unix)
  both(math.min(window,300))
  local perMinute=(SB.Svc.Requests-r0)/(3+math.min(window,300)/60)
  check(perMinute<=4,label..': B spends at most a few store requests a minute ('..string.format('%.1f',perMinute)..'); it used to retry the fruit every step until the budget ran out')
  check(SB.Store:Status().Failures==0,label..': and nothing was refused or failed ('..SB.Store:Status().Failures..' failures)')
 end
 mismatch('B\'s fruit is lighter',false)
 mismatch('B\'s fruit is heavier',true)
 -- a mismatch that has gone (B restarted on the new list): the fruit syncs again
 do
  local backend=HH.backend();local ca=HH.clock(T0);local cb=HH.clock(T0);backend.Now=function()return ca.t end
  local SA=makeServer(backend,{Clock=ca,Seed=5});local SB=makeServer(backend,{Clock=cb,Seed=77,List=listB});SA.Service:Start();SB.Service:Start()
  local pa,pb=HH.player(93,'Cy'),HH.player(94,'Di')
  SA.Service:NoteHarvest(pa,{SeedId=todayFruit,FruitScale=8})
  for _=1,12 do ca.advance(5);cb.advance(5);SA.Service:Step();SB.Service:Step()end
  SB.Service:NoteHarvest(pb,{SeedId=otherFruit,FruitScale=9})
  for _=1,24 do ca.advance(5);cb.advance(5);SA.Service:Step();SB.Service:Step()end
  check(backend.peek(Rules.StoreName,'d'..DAY).fruit.Name=='Cy','(while the shared fruit is of A\'s type, B writes none)')
  SB.Service.FruitList=list;SB.Service.Board:SetDay(DAY,todayFruit) -- B now agrees with A
  SB.Service:NoteHarvest(pb,{SeedId=todayFruit,FruitScale=9})
  for _=1,24 do ca.advance(5);cb.advance(5);SA.Service:Step();SB.Service:Step()end
  check(backend.peek(Rules.StoreName,'d'..DAY).fruit.Name=='Di','once both servers agree on the fruit, the heavier one is shared again')
 end
 -- the safety net for anything else that keeps a shared board unsynced after a write (a store that answers but never keeps the record): that board waits a poll before it tries again, so
 -- it can never spend the request budget
 do
  local backend=HH.backend();local ca=HH.clock(T0);backend.Now=function()return ca.t end
  local S=makeServer(backend,{Clock=ca,Seed=5});S.Service:Start()
  local merges=0;S.Service.Store.Merge=function()merges+=1;return true,nil,false,false end
  S.Service.Store.Read=function()return true,{}end
  S.Service:NoteHarvest(HH.player(95,'Eve'),{SeedId=S.Service.Board.FruitId,FruitScale=9})
  for _=1,12 do ca.advance(5);S.Service:Step()end
  check(merges>=1 and merges<=2,'a write that settles nothing is not repeated every step ('..merges..' attempts in a minute; it used to be one per step)')
  for _=1,18 do ca.advance(5);S.Service:Step()end
  check(merges<=4,'... and in two and a half minutes only about once a poll ('..merges..')')
 end
end

-- 12. R153: BEST PULL is this server's own and lasts one wall-clock 10-minute window ---------------------------------------------------------------------------------------------
-- (owner: "make the best pull of the day refresh every 10 minutes and its a local server only thing to increase performance")
do
 local function newServer(unix,opts)
  local backend=HH.backend();local c=HH.clock(unix);backend.Now=function()return c.t end
  opts=opts or{};opts.Clock=c;opts.Seed=opts.Seed or 5
  local S=makeServer(backend,opts)
  -- a recording store: what the hub asks of it, kind by kind
  local kinds={Merge={},Read=0,Remove=0}
  local store=S.Service.Store;local merge,read,remove=store.Merge,store.Read,store.Remove
  store.Merge=function(self,day,kind,...)kinds.Merge[tostring(kind)]=(kinds.Merge[tostring(kind)]or 0)+1;return merge(self,day,kind,...)end
  store.Read=function(self,...)kinds.Read+=1;return read(self,...)end
  store.Remove=function(self,...)kinds.Remove+=1;return remove(self,...)end
  S.Kinds=kinds
  return S,backend,c
 end
 local function gone(m)return m==nil or m._destroyed==true end
 local function children(model,prefix)local n=0;for _,ch in ipairs(model:GetChildren())do if ch.Name:sub(1,#prefix)==prefix then n+=1 end end;return n end
 local function live(list)local n=0;for _,m in ipairs(list or{})do if not gone(m)then n+=1 end end;return n end
 local function countDescendants(m)return #m:GetDescendants()end
 local q=HH.player(121,'Win');local r=HH.player(122,'Wes')

 -- a. the boundary clears the board and the avatar, exactly as an empty board looks
 do
  local S,backend,c=newServer(T0+120) -- 03:02:00
  local svc=S.Service;svc:Start()
  local d,fd=S.Art.Built.Pull,S.Art.Built.Fruit
  check(d.Text.Label.Footer.Text=='new board in 8:00'and d.Model:GetAttribute('NextAt')==T0+600,'03:02:00: the empty board counts "new board in 8:00" to 03:10:00')
  c.advance(18)
  svc:NotePull(q,reward('FirePepperSeed','Mythic'),info())
  check(svc:Snapshot().Pull.Record.Name=='Win'and d.Text.Label.Footer.Text=='new board in 7:42'and d.Text.Label.Title.Text=='BEST PULL'and d.Text.State=='Champion','03:02:18: Win\'s Mythic is the record, the label says BEST PULL ... "new board in 7:42"')
  check(d.Model:GetAttribute('NextAt')==T0+600,'the client counts down to 03:10:00 (the NextAt attribute)')
  local rig1=d.Avatar;local item1=d.Item
  check(rig1 and rig1:GetAttribute('UserId')==121 and not gone(rig1),'Win\'s avatar stands there')
  -- a better pull in the window replaces the record
  c.advance(30)
  svc:NotePull(r,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
  check(svc:Snapshot().Pull.Record.Name=='Wes'and svc:Snapshot().Pull.Record.Rarity=='King'and d.Text.Label.Name.Text=='Wes'and d.Text.Label.Footer.Text=='new board in 7:12','a better pull in the window (a King) replaces the record, shown at once: "Wes", "new board in 7:12"')
  check(gone(rig1)and d.Avatar:GetAttribute('UserId')==122 and children(d.Model,'Avatar')==1,'Win\'s rig is gone, Wes\'s stands there (one avatar on the display)')
  check(not svc:NotePull(q,reward('AppleSeed','Rare'),info({Stage=1,Variant='Pack01'}))and svc:Snapshot().Pull.Record.Name=='Wes','a worse pull in the same window changes nothing')
  -- the fruit board has its own day: put something on it
  local fid=svc.Board.FruitId
  svc:NoteHarvest(q,{SeedId=fid,FruitScale=3})
  local fruitRev=fd.Model:GetAttribute('Rev');local fruitBuilds=0;for _,b in ipairs(S.Art.ItemBuilds)do if b.Kind=='Fruit'then fruitBuilds+=1 end end
  local fruitRig=fd.Avatar;local fruitRec=svc:Snapshot().Fruit.Record
  local calls=#S.Announcer.Calls;local sent0=#S.Announcer.Sent
  local rigWes=d.Avatar
  -- just before the boundary: nothing has changed
  c.advance(T0+599-c.unix);svc:Step()
  check(c.unix==T0+599 and svc:Snapshot().Pull.Record.Name=='Wes'and d.Text.Label.Footer.Text~=nil,'03:09:59: the record is still there')
  check(svc:SleepSeconds()==1,'and the loop sleeps 1 s (to wake just after the mark)')
  -- the boundary
  local revBefore=d.Model:GetAttribute('Rev');local avatarBuilds=#S.Avatars.Builds;local itemBuilds=#S.Art.ItemBuilds
  c.advance(1);svc:Step()
  local snap=svc:Snapshot()
  check(c.unix==T0+600 and snap.Window==(T0+600)//600 and snap.Pull.Record==nil,'03:10:00: the board is empty')
  check(d.Text.State=='Empty'and d.Text.Label.Name.Text=='Nobody yet'and d.Text.Label.Info.Text=='???'and d.Text.Label.Title.Text=='BEST PULL','and its words are the empty board\'s (BEST PULL, "Nobody yet", "???")')
  check(d.Text.Label.Footer.Text=='new board in 10:00'and d.Model:GetAttribute('NextAt')==T0+1200 and d.Model:GetAttribute('FooterPrefix')=='new board in ','a whole new window to go: "new board in 10:00" to 03:20:00')
  check(d.Model:GetAttribute('Champion')==nil and d.Model:GetAttribute('ChampionUserId')==nil and d.Model:GetAttribute('Rarity')==nil and d.Model:GetAttribute('State')=='Empty','the display\'s attributes name nobody (the client sees an empty board)')
  check(d.Model:GetAttribute('Rev')>revBefore and d.TintState=='Empty','the client is told (Rev) and the light is calm, as on a fresh server')
  local last=S.Art.ItemBuilds[#S.Art.ItemBuilds]
  check(#S.Art.ItemBuilds==itemBuilds+1 and last.Kind=='Pull'and last.Spec.Mystery==true and last.Spec.Calm==true,'the item is the black mystery seed again')
  check(#S.Avatars.Builds==avatarBuilds+1 and S.Avatars.Builds[#S.Avatars.Builds].Silhouette==true and d.Avatar:GetAttribute('UserId')==0 and d.Avatar:GetAttribute('Fallback')==true,'the champion\'s avatar is replaced by the black silhouette, exactly as an empty board shows')
  check(gone(rigWes)and children(d.Model,'Avatar')==1 and not gone(d.Avatar),'Wes\'s rig is destroyed (the client drops its dance with it); one avatar (the silhouette) stands there')
  check(live(S.Avatars.Models)==2 and live(S.Art.ItemModels)==2,'every rig made so far is destroyed except one per display: the pull\'s silhouette and the fruit champion ('..live(S.Avatars.Models)..' alive of '..#S.Avatars.Models..'; items: '..live(S.Art.ItemModels)..': the pull\'s and the fruit\'s)')
  check(#S.Announcer.Calls==calls,'the reset announces nothing')
  check(fd.Text.State=='Champion'and Rules.Key(svc:Snapshot().Fruit.Record)==Rules.Key(fruitRec)and fd.Model:GetAttribute('Rev')==fruitRev and fd.Avatar==fruitRig and not gone(fruitRig),'BIGGEST FRUIT is untouched: the same champion, the same display, the same rig, no Rev')
  local fb=0;for _,b in ipairs(S.Art.ItemBuilds)do if b.Kind=='Fruit'then fb+=1 end end
  check(fb==fruitBuilds,'and its item was not rebuilt')
  -- the next pull is the new record, even a worse one than the last window's
  c.advance(20)
  check(svc:NotePull(q,reward('SunflowerSeed','Common'),info({Stage=1,Variant='Pack01'})),'03:10:20: a Common pull ...')
  check(svc:Snapshot().Pull.Record.Rarity=='Common'and svc:Snapshot().Pull.Record.Name=='Win'and d.Text.Label.Name.Text=='Win'and d.Text.Label.Footer.Text=='new board in 9:40','... is the new record (the last window\'s King does not count any more): "Win", "new board in 9:40"')
  check(d.Avatar:GetAttribute('UserId')==121 and children(d.Model,'Avatar')==1,'with Win\'s avatar (the silhouette is gone)')
  check(#S.Announcer.Sent==sent0 and #S.Announcer.Calls==calls+1 and S.Announcer.Calls[#S.Announcer.Calls].Record=='BestPull','the announcer was asked (and, below Legendary, said nobody hears it)')
  -- a better pull in the window replaces it, and a Mythic is announced again in this new window
  c.advance(20)
  svc:NotePull(r,reward('AppleSeed','Rare'),info({Stage=1,Variant='Pack01'}))
  check(svc:Snapshot().Pull.Record.Rarity=='Rare'and svc:Snapshot().Pull.Record.Name=='Wes','a Rare replaces the Common')
  local sentBefore=#S.Announcer.Sent
  c.advance(10)
  svc:NotePull(q,reward('FirePepperSeed','Mythic'),info())
  check(svc:Snapshot().Pull.Record.Rarity=='Mythic'and #S.Announcer.Sent==sentBefore+1 and S.Announcer.Sent[#S.Announcer.Sent].Record=='BestPull'and S.Announcer.Sent[#S.Announcer.Sent].Player==q,'a Mythic takes the record again and is announced again (a record line per window, in this server)')
  check(S.Announcer.Sent[#S.Announcer.Sent].Scope==nil,'(through the announcer\'s own scope rules; the hub asks for no other server)')
 end

 -- b. test packs, owner grants and injected tests
 do
  local S,backend,c=newServer(T0+10)
  local svc=S.Service;svc:Start()
  check(not svc:NotePull(q,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01',Test=true}))and svc:Snapshot().Pull.Record==nil,'a TEST pack (/test rarepacks, a TestGrant pack, owner-given boots) does not count in the window')
  svc:NoteOwnerGrant(r)
  check(not svc:NotePull(r,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))and svc:Snapshot().Pull.Record==nil,'nor does a pull of a player an owner command gave items')
  check(svc:NotePull(q,reward('AppleSeed','Rare'),info({Stage=1,Variant='Pack01'})),'a real pull does')
  -- an injected test pull lives until the window ends, like any record, then is gone with it
  local ok,msg=svc:InjectPull(q,'solar starfruit')
  check(ok and svc:Snapshot().Pull.Source=='Test'and svc:Snapshot().Pull.Record.Rarity=='King','an injected test pull (bestpull) shows')
  c.advance(T0+600-c.unix);svc:Step()
  check(svc:Snapshot().Pull.Record==nil and svc.Board.Boards.Pull.Test==nil and svc.Board.Boards.Pull.Local==nil,'the window ends: the test pull and the real one are both gone')
  check(not svc:NotePull(r,reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'})),'(the owner-granted player is still not counted in the new window: the grant lasts the session)')
 end

 -- c. a window that opens on an empty board changes only the countdown
 do
  local S,backend,c=newServer(T0+5)
  local svc=S.Service;svc:Start()
  local d=S.Art.Built.Pull
  local items,rigs,rev,writes=#S.Art.ItemBuilds,#S.Avatars.Builds,d.Model:GetAttribute('Rev'),S.Art.SignWrites
  local nextAts={d.Model:GetAttribute('NextAt')}
  for i=1,3 do
   c.advance(600);svc:Step()
   nextAts[#nextAts+1]=d.Model:GetAttribute('NextAt')
  end
  check(#S.Art.ItemBuilds==items and #S.Avatars.Builds==rigs and d.Model:GetAttribute('Rev')==rev,'three windows with nobody pulling: no new item, no new rig, no Rev (an empty board that stays empty is not rebuilt)')
  check(nextAts[2]==nextAts[1]+600 and nextAts[3]==nextAts[1]+1200 and nextAts[4]==nextAts[1]+1800,'but the countdown moves on every window (NextAt follows the real next mark)')
  check(d.Text.Label.Footer.Text=='new board in 9:55'and S.Art.SignWrites>writes,'and the server\'s own footer text is right for the new window ("new board in 9:55" at 03:30:05)')
 end

 -- d. a pull right after the mark, before the loop has noticed it, is the new window's
 do
  local S,backend,c=newServer(T0+300)
  local svc=S.Service;svc:Start()
  svc:NotePull(q,reward('FirePepperSeed','Mythic'),info())
  c.advance(301) -- (03:10:01: no Step yet)
  check(svc:Snapshot().Pull.Record.Name=='Win','(the old window\'s record is still in the books until something looks)')
  svc:NotePull(r,reward('SunflowerSeed','Common'),info({Stage=1,Variant='Pack01'}))
  check(svc:Snapshot().Pull.Record.Name=='Wes'and svc:Snapshot().Pull.Record.Rarity=='Common'and S.Art.Built.Pull.Text.Label.Name.Text=='Wes'and svc:Snapshot().Window==(T0+600)//600,'a pull at 03:10:01, before any step, is the first of the new window (the Mythic of the old one is gone)')
  local rigs=live(S.Avatars.Models)
  check(rigs==2,'and only the new champion\'s rig is alive on the pull display (one rig a display: '..rigs..')')
 end

 -- e. the loop wakes just after each mark (the real loop, with the scheduler's wait caught)
 do
  local S,backend,c=newServer(T0+292)
  S.Service.Opts.NoLoop=false
  local oldWait=R.task.wait;local waits={}
  R.task.wait=function(t)waits[#waits+1]={T=t,Co=coroutine.running()};coroutine.yield()end
  S.Service:Start()
  R.task.wait=oldWait
  local d=S.Art.Built.Pull
  check(#waits==1 and waits[1].T==5,'the loop waits 5 s while the mark is further away (03:04:52: 308 s to go)')
  S.Service:NotePull(q,reward('FirePepperSeed','Mythic'),info())
  local function tick() -- (the loop's sleep ends: the clock moved by what it asked, one pass)
   local w=table.remove(waits,1);c.advance(w.T)
   R.task.wait=function(t)waits[#waits+1]={T=t,Co=coroutine.running()};coroutine.yield()end
   coroutine.resume(w.Co);R.task.wait=oldWait
  end
  local seen={}
  for _=1,70 do tick();seen[#seen+1]=waits[1]and waits[1].T or-1
   if c.unix>=T0+600 then break end end
  check(c.unix==T0+600 and S.Service:Snapshot().Pull.Record==nil and d.Text.State=='Empty','the loop is awake at the mark: 03:10:00 and the board is already empty (within a second of the boundary, not up to 5 s later)')
  local short=false;for _,v in ipairs(seen)do if v<5 then short=true end end
  check(short,'(it shortened its last sleeps to land on it: '..table.concat(seen,',',math.max(1,#seen-3))..')')
  check(waits[1].T==5,'and after the mark it is back to 5 s ('..tostring(waits[1].T)..')')
  S.Service:Destroy();for _,w in ipairs(waits)do pcall(coroutine.resume,w.Co)end;waits={}
 end

 -- f. nothing leaks over many windows
 do
  local S,backend,c=newServer(T0)
  local svc=S.Service;svc:Start()
  local d=S.Art.Built.Pull
  local players={};for i=1,6 do players[i]=HH.player(300+i,'Pl'..i)end
  local parts0,size0
  local skip={Opts=1,Config=1,Data=1,Map=1,Notes=1,Art=1,Store=1,Avatars=1,Displays=1,Board=1,Random=1,Folder=1,Remote=1,ReportRemote=1,FruitList=1}
  local function stateSize()local n=0;for k,v in pairs(svc)do if type(v)=='table'and not skip[k]then for _ in pairs(v)do n+=1 end end end;return n end
  local windows=48
  for w=1,windows do
   c.advance(37)
   svc:NotePull(players[w%6+1],reward('FirePepperSeed','Mythic'),info({Variant='Pack01'}))
   c.advance(120)
   svc:NotePull(players[(w+1)%6+1],reward('SolarStarfruitSeed','King'),info({Stage=2,Variant='Pack01'}))
   if w==2 then parts0=countDescendants(d.Model);size0=stateSize()end
   c.advance(Rules.PullSecondsLeft(c.unix));svc:Step() -- the mark
   if svc:Snapshot().Pull.Record~=nil then check(false,'the board did not empty at window '..w)break end
  end
  check(svc:Snapshot().Pull.Record==nil,'after '..windows..' windows (8 hours) of two pulls each the board is empty')
  check(live(S.Avatars.Models)==2 and children(d.Model,'Avatar')==1 and d.Avatar:GetAttribute('Fallback')==true,'one rig alive on each display: the pull\'s is the silhouette ('..live(S.Avatars.Models)..' of '..#S.Avatars.Models..' made are alive)')
  check(live(S.Art.ItemModels)==2,'one item alive per display ('..live(S.Art.ItemModels)..' of '..#S.Art.ItemModels..' made)')
  check(parts0==nil or countDescendants(d.Model)<=parts0,'the display holds no more than it did at the second window ('..tostring(parts0)..' -> '..countDescendants(d.Model)..' descendants)')
  local slots=svc.Board.Boards.Pull
  check(slots.Local==nil and slots.Test==nil and slots.Remote==nil,'the board keeps no old records')
  check(stateSize()<=size0,'no bookkeeping table of the service grew over the windows ('..tostring(size0)..' entries at window 2, '..stateSize()..' at the end)')
 end

 -- g. no store, no other server, no save: not for any of it (the recording store and the traps)
 do
  local S,backend,c=newServer(T0)
  local svc=S.Service;svc:Start()
  for w=1,6 do
   svc:NotePull(q,reward('FirePepperSeed','Mythic'),info());c.advance(30)
   svc:InjectPull(r,'solar starfruit')
   svc:NotePull(q,reward('SunflowerSeed','Common'),info({Stage=1,Variant='Pack01'}))
   for _=1,24 do c.advance(25);svc:Step()end
  end
  check(S.Kinds.Merge.Pull==nil,'the store was never offered a pull ('..tostring(S.Kinds.Merge.Pull)..' offers, in 6 windows of events)')
  check(backend.Calls.Update==0 and backend.Calls.Set==0 and backend.Calls.Remove==0,'MemoryStore never saw a write')
  check(S.Kinds.Read>=1 and S.Kinds.Read==backend.Calls.Get,'the only traffic is the fruit\'s poll: '..backend.Calls.Get..' reads in an hour')
  check(trapped.DataStore==0 and trapped.Messaging==0 and trapped.MemoryStore==0,'DataStoreService, MessagingService and the default MemoryStoreService were never touched by anything in this suite (R153: '..trapped.DataStore..' / '..trapped.Messaging..' / '..trapped.MemoryStore..')')
 end

 -- h. a preview day does not touch the board, and a mark still empties it while previewing
 do
  local S,backend,c=newServer(T0+100)
  local svc=S.Service;svc:Start()
  svc:NotePull(q,reward('FirePepperSeed','Mythic'),info())
  local rec=svc:Snapshot().Pull.Record
  svc:SetDayOffset(2)
  check(svc:Snapshot().Pull.Record==rec and S.Art.Built.Pull.Text.Label.Name.Text=='Win','previewing +2 days: the pull board is untouched')
  c.advance(T0+600-c.unix);svc:Step()
  check(svc:Snapshot().Pull.Record==nil and S.Art.Built.Pull.Text.State=='Empty'and S.Art.Built.Pull.Model:GetAttribute('NextAt')==T0+1200,'the real mark still empties it while previewing (the preview is for the fruit)')
  svc:SetDayOffset(0)
  check(svc:Snapshot().Pull.Record==nil,'and coming back keeps it empty')
 end
end
check(trapped.DataStore==0 and trapped.Messaging==0 and trapped.MemoryStore==0,'R153: at the very end of the suite: no DataStoreService / MessagingService / default MemoryStoreService call by the hub ('..trapped.DataStore..' / '..trapped.Messaging..' / '..trapped.MemoryStore..')')
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
