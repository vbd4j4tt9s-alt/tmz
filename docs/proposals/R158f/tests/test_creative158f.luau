--!nocheck
-- R158f (owner: "give me cmds to test everything, remove restrictions for my cmds, my cmds are absolute, basically give me creative mode"): the game owner's commands and creative mode, on the Roblox
-- mock (the R152 giveaway harness: a fake player data, the REAL scripts of this checkout) with a LIVE server (RunService:IsStudio() is false) whose place is created by user 501.
--  A. who is who: the creator is the owner, an AdminUserIds user is allowed but not the owner, anyone else is refused (a normal player can use nothing);
--  B. the Studio-only gates on a LIVE server: the owner runs playtime / voidgift reset me / voidgift left / starterverity reset; an admin is still refused;
--  C. the owner's other limits: grants past the 200 Bag cap (and 20 / 100 per command), no wait for a chase, no wait between commands' count of one per .35 s; an admin keeps them;
--  D. creative on / off: nothing can hit the player, no Bag cap, no rate limit, no movement correction, no bat cooldown, speed, plants ripe; off puts it all back; it is per player (@name), and
--     clears when the player leaves; only the owner can set it (an admin and a normal player cannot, nor tutorial / newplayer / verityevent);
--  E. the tutorial for the owner: reset (step 1, Fast / FastCrop cleared, the client is told), step N, done; a normal player's Replay request is still refused;
--  F. newplayer, verityevent, droppack, bonusrolls, holo, fastfruit and the help list.
local G=require('./giveaway_harness');local H,W,R=G.H,G.W,G.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local warns={};W.env.warn=function(...)local t={};for _,v in ipairs({...})do t[#t+1]=tostring(v)end;warns[#warns+1]=table.concat(t,' ')end
local Run=W.service('RunService');Run.IsStudio=function()return false end
W.game.CreatorType=R.Enum.CreatorType.User;W.game.CreatorId=501 -- the place was created by user 501: the GAME OWNER
local ServerFolder=W.service('ServerScriptService').ChestChaseServer
local Access=H.server('OwnerCommandAccess');local State=H.server('OwnerTestState82');local Gate=H.server('SecurityGate')
local SC=H.server('StudioTestCommands');local Creative=H.server('OwnerCreative158f');local Ragdoll=H.server('RagdollService')
ServerFolder.OwnerCommandAccess:SetAttribute('AdminUserIds','502')
local Limited=W.module('LimitedEvent');local Rules=G.Rules
local function now()return math.floor(R.clock)end -- (the mock's os.time inside the scripts)
-- a live server with its fake data (the cap of 1000 packs is the save's, as in Config)
local backend=G.backend()
local s=G.server(backend,nil,{Studio=false,Name='Live',Config={MaxSavedChests=1000,GardenPlotCount=2,MaxSavedHarvests=500}})
s.Svc:Start()
local D=s.Data
H.server('InventoryCap155').Attach(D) -- the real 200 cap (RoomFor, HeldItemCount)
H.server('TutorialProgress').Attach(D) -- the real tutorial state (PublishTutorial, GrantStarterPack)
D.Gardens={};D.Notifications=nil
function D:GetOrCreateSpeedValue()return{Value=0}end
local cash={};function D:GetOrCreateCashValue(p)cash[p]=cash[p]or{Value=0};return cash[p]end
function D:GetCash(p)return D:GetOrCreateCashValue(p).Value end
function D:_gardenChanged()end
function D:_notifySeedInventory()end
s.Chests.IsOpening=function()return false end
local speeds={}
local bases={_applyPhysicalSpeed=function(_,p,_,_)speeds[p]=(speeds[p]or 0)+1 end,GetPlayerBase=function()return nil end,StopTraining=function()end}
local ragdoll=Ragdoll.new({},function()end)
local drops={}
local chase={IsPlayerBusy=function(_,p)return p:GetAttribute('ChestChaseSeedCarrying')==true end,Ragdoll=ragdoll,Bats={Counts={hit=7,['out of reach']=2},Serial=9},
 TestDropPack=function(_,p,stage,tier,seconds)drops[#drops+1]={p,stage,tier,seconds};return true,'dropped'end}
local ctx={Data=D,Config=D.Config,Chests=s.Chests,Chase=chase,Bases=bases,Map={MapRoot=s.Root}}
local function player(id,name,o)o=o or{};return G.player(s,id,name,o)end -- (standing 12 studs from the Void pedestal)
local owner,admin,normal,bob=player(501,'Owner'),player(502,'Admin'),player(503,'Normal'),player(504,'Bob')
local function run(p,text)return SC.Execute(ctx,p,text)end
local function packs(p)return#D:GetChestRecords(p)end

-- A. who is who ---------------------------------------------------------------------------------------------------------------------------------------------
check(Access.IsOwner(owner)and Access.IsAllowed(owner),'A: the place\'s creator is the game owner')
check(Access.IsAllowed(admin)and not Access.IsOwner(admin),'A: an AdminUserIds user is allowed but is NOT the owner')
check(not Access.IsAllowed(normal)and not Access.IsOwner(normal),'A: anyone else is neither')
for _,text in ipairs({'/test creative on','/test cash 5','/test tutorial reset','/test newplayer','/test verityevent off','/test droppack','/test walls','/test fly'})do
 local ok,why=run(normal,text);check(ok==false and tostring(why):find('owner or configured admins',1,true)~=nil and not State.Creative(normal),'A: a normal player is refused: '..text)
end

-- B. the Studio-only gates on a live server ----------------------------------------------------------------------------------------------------------------
do
 local PT=function(p,text)return run(p,text)end
 local ok,text=PT(owner,'/test playtime @me 12');local field=D:GetPremium(owner)[Rules.PlayField]
 check(ok==true and field==720,'B: the owner sets play time on a live server ('..tostring(text)..')')
 ok,text=PT(admin,'/test playtime @me 12');check(ok==false and tostring(text):find('Studio only',1,true)~=nil and D:GetPremium(admin)[Rules.PlayField]~=720,'B: an admin is still refused ("works in Studio only")')
 -- the pedestal: the owner claims, resets the claim (the LIVE count goes down), edits the count
 s.Svc:Claim(owner);local KEY='VoidGiveaway152/Claims'
 check(backend.Data[KEY]and backend.Data[KEY].Count==1 and D:GetPremium(owner)[Rules.Flag]==true,'B: (setup) the owner claimed the free Void Pack on the live store')
 ok,text=PT(admin,'/test voidgift reset me');check(ok==false and tostring(text):find('Studio only',1,true)~=nil and backend.Data[KEY].Count==1,'B: an admin cannot reset a claim on a live server')
 ok,text=PT(admin,'/test voidgift left 3');check(ok==false and backend.Data[KEY].Count==1,'B: an admin cannot edit the live count')
 ok,text=PT(owner,'/test voidgift reset me');check(ok==true and backend.Data[KEY].Count==0 and D:GetPremium(owner)[Rules.Flag]==nil,'B: the owner resets his claim on the LIVE store ('..tostring(text)..')')
 ok,text=PT(owner,'/test voidgift left 3');check(ok==true and backend.Data[KEY].Count==497,'B: the owner sets the live count (497 claimed = 3 left)')
 -- the starter Verity gift
 local Starter=H.server('StarterVerity158d');local Starter158=W.module('StarterVerityRules158d')
 D.FreshProfile={}
 local sv=Starter.new(D.Config,D,s.Chests,s.Notes,nil,{Studio=false,Time=function()return 1790000000 end,NoWatch=true})
 ok,text=PT(owner,'/test starterverity @me reset');check(ok==true and D:GetPremium(owner)[Starter158.Flag]~=nil,'B: the owner resets the starter gift flag on a live server ('..tostring(text):sub(1,70)..')')
 ok,text=PT(admin,'/test starterverity @me reset');check(ok==false and tostring(text):find('Studio only',1,true)~=nil,'B: an admin is refused')
end

-- C. the owner's other limits -------------------------------------------------------------------------------------------------------------------------------
do
 local ok,text=run(owner,'/test eclipse 250 @Bob');check(ok==true and packs(bob)==250,'C: the owner grants 250 Void Packs at once, past the 200 Bag cap (Bob holds '..packs(bob)..')')
 local before=packs(bob);ok,text=run(admin,'/test eclipse 25 @Bob');check(ok==false and packs(bob)==before and tostring(text):find('20',1,true)~=nil,'C: an admin keeps the 20 limit')
 ok,text=run(admin,'/test eclipse 5 @Bob');check(ok==false and packs(bob)==before,'C: an admin keeps the 200 cap (Bob is over it)')
 ok,text=run(owner,'/test eclipse 5 @Bob');check(ok==true and packs(bob)==before+5,'C: the owner is not stopped by it')
 ok,text=run(owner,'/test verity 1200 @Bob');check(ok==false and packs(bob)==before+5,'C: more than 500 in one command is refused ("Use verity [1-500]")')
 ok,text=run(owner,'/test eclipse 500 @Bob');check(ok==true and packs(bob)==before+505,'C: 500 in one command works for the owner')
 ok,text=run(owner,'/test eclipse 500 @Bob');check(ok==false and packs(bob)==before+505 and tostring(text):find('1000',1,true)~=nil,'C: the save\'s own ceiling (1000 packs and seeds) still stops a grant (the save format)')
 -- a chase / carrying: the owner is never refused, an admin is
 owner:SetAttribute('ChestChaseSeedCarrying',true);admin:SetAttribute('ChestChaseSeedCarrying',true)
 ok,text=run(owner,'/test cash 5000000');check(ok==true and D:GetCash(owner)==5000000,'C: "/test cash 5000000" while carrying a pack works for the owner (cash <n> = cash set <n>)')
 ok,text=run(admin,'/test cash 5');check(ok==false and tostring(text):find('Finish your chase',1,true)~=nil,'C: an admin is told to finish the chase')
 owner:SetAttribute('ChestChaseSeedCarrying',nil);admin:SetAttribute('ChestChaseSeedCarrying',nil)
 -- no wait between commands for the owner (the dispatcher\'s .35 s wait is the admin\'s)
 local SCstart=SC.Start
 check(type(SCstart)=='function','C: (setup) the dispatcher exposes Start')
end

-- D. creative mode -----------------------------------------------------------------------------------------------------------------------------------------
do
 -- not for an admin, not for a normal player
 local ok,text=run(admin,'/test creative on');check(ok==false and tostring(text):find('game owner only',1,true)~=nil and not State.Creative(admin),'D: an admin cannot turn creative on ("game owner only")')
 ok,text=run(admin,'/test creative on @Bob');check(ok==false and not State.Creative(bob),'D: ... nor for someone else')
 -- before: everything normal for the owner
 local function gateTries(p)local n=0;for _=1,20 do if Gate.Allow(p,'BatHit',{})then n+=1 end end;return n end
 check(ragdoll:CanHit(owner)and gateTries(owner)<=4,'D: (before) a normal player can be hit and is rate limited')
 for _=1,200-packs(owner)do D:AddChest(owner,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None'})end
 check(D:HeldItemCount(owner)==200 and D:RoomFor(owner,1)==false,'D: (before) a Bag of 200 is full')
 ok,text=run(owner,'/test creative on');check(ok==true and State.Creative(owner)and owner:GetAttribute('CreativeMode158f')==true,'D: the owner turns creative on ('..tostring(text):sub(1,60)..')')
 check(not ragdoll:CanHit(owner),'D: nothing can hit a creative player (keepers, The Darkened, bats, lightning, holes all ask Ragdoll:CanHit)')
 check(ragdoll:CanHit(owner,true),'D: ... but the owner\'s own /test fling and /test ragdoll still can (force)')
 check(ragdoll:Apply(owner,V3(0,1,0),'Keeper')==nil,'D: Ragdoll:Apply does nothing to them')
 check(D:RoomFor(owner,1)==true and D:RoomFor(owner,50)==true,'D: the Bag has no 200 cap in creative mode')
 check(gateTries(owner)==20,'D: no rate limit (SecurityGate) in creative mode')
 check(State.GetSpeed(owner)==200 and State.MovementGranted(owner),'D: walk speed 200 and movement (fly) allowed')
 ok,text=run(owner,'/test movespeed 300');check(ok==true and State.GetSpeed(owner)==300,'D: /test movespeed overrides the creative speed')
 ok,text=run(owner,'/test creative speed 350');check(ok==true,'D: /test creative speed 350 ('..tostring(text)..')')
 ok,text=run(owner,'/test creative speed 9999');check(ok==false,'D: ... a walk speed above 500 is refused')
 -- plants ripe at once
 D.Gardens[owner]={Plots={['1']={{PlantedAt=os.time(),MatureAt=os.time()+9999,ReadyAt=os.time()+9999,HarvestCycle=0,PickedMask=0,FruitStates={}}},['2']={}},Harvests={}}
 local crop=D.Gardens[owner].Plots['1'][1]
 ok,text=run(owner,'/test fastfruit');check(ok==true and crop.ReadyAt<=os.time()and crop.MatureAt<=os.time()and crop.FruitStates==nil,'D: /test fastfruit ripens the crops now ('..tostring(text):sub(1,50)..')')
 -- the movement check lets a creative player be
 do
  local Guard=H.server('MovementGuard');Guard.Started=true;Guard.Data={IsLoaded=function()return true end,GetOrCreateSpeedValue=function()return{Value=0}end}
  Guard.Config={GetPlayerWalkSpeed=function(p)return State.GetSpeed(p)or 16 end};Guard.Bases={TrainingSessions={},Map=nil}
  local rm=G.RS.RunnerMotion;rm:SetAttribute('TrackBoundaryZ',-200);rm:SetAttribute('TrackCenterX',0);rm:SetAttribute('TrackHalfWidth',60)
  for _,q in ipairs({owner,bob})do q.Character:FindFirstChildOfClass('Humanoid').JumpPower=50 end
  local function jump(p)
   Guard.Reset(p);local root=p.Character.HumanoidRootPart;root.CFrame=R.CFrame.new(0,5,0);Guard.Reset(p)
   local state=Guard.Records[p];state.Grace=0;state.At=os.clock()-.5 -- (past the .25 s grace after a reset)
   root.CFrame=R.CFrame.new(0,5,3000)
   local ok2=Guard.Check(p);return ok2,root.CFrame.Position.Z
  end
  local okC,zC=jump(owner);check(okC==true and zC==3000,'D: MovementGuard does not correct a creative player (3000 studs at once)')
  State.SetCreative(bob,false);local okN,zN=jump(bob);check(okN==false,'D: ... it still corrects a normal player')
 end
 -- the bat: no cooldown
 do
  local Bat=H.server('BatService');local tool=R.new('Tool');tool.Name='Bat';tool.Parent=owner.Character
  local fake={_validCharacter=function(_,p)local c=p.Character;return c,c:FindFirstChildOfClass('Humanoid'),c:FindFirstChild('HumanoidRootPart')end,Chests={IsOpening=function()return false end},Map={Refreshing=false}}
  local bats=Bat.new(fake);bats.Remote={FireAllClients=function()end,SetAttribute=function()end};bats.Tools[owner]=tool
  local function swing(p,id)bats.NextRequest[p]=nil;return bats:Request(p,{Kind='Swing',Start=W.workspace:GetServerTimeNow(),Id=id})end
  local first=swing(owner,1);local second=swing(owner,2)
  check(first==true and second==true,'D: creative: a second bat swing right after the first is accepted (no cooldown)')
  State.SetCreative(owner,false);bats.Tools[owner]=tool;bats.NextSwing[owner]=nil;bats.LastStart[owner]=nil;local a1=swing(owner,3);local a2=swing(owner,4)
  check(a1==true and a2==false,'D: ... off: the 1 s cooldown is back (second swing refused)');State.SetCreative(owner,true)
 end
 -- per player (@name), and the owner's own is unchanged by it
 ok,text=run(owner,'/test creative on @Bob');check(ok==true and State.Creative(bob)and State.Creative(owner),'D: /test creative on @Bob turns it on for Bob only')
 ok,text=run(owner,'/test creative status @Bob');check(ok==true and tostring(text):find('ON',1,true)~=nil,'D: creative status')
 -- off puts it all back
 run(owner,'/test movespeed off')
 ok,text=run(owner,'/test creative off');check(ok==true and not State.Creative(owner)and owner:GetAttribute('CreativeMode158f')==nil,'D: /test creative off ('..tostring(text):sub(1,40)..')')
 check(ragdoll:CanHit(owner)and D:RoomFor(owner,1)==false and gateTries(owner)<=4 and State.GetSpeed(owner)==nil,'D: off: can be hit, the Bag is full again, rate limited, the earned speed')
 -- it clears when the player leaves
 check(State.Creative(bob),'D: (before) Bob is in creative mode')
 State.Leave(bob);check(not State.Creative(bob)and bob:GetAttribute('CreativeMode158f')==nil,'D: leaving ends creative mode (OwnerTestState82.Leave; the dispatcher calls it on PlayerRemoving)')
 -- a respawn keeps it
 State.SetCreative(owner,true);State.Clear(owner);check(State.Creative(owner)and State.MovementGranted(owner),'D: a respawn (Clear) keeps creative mode');State.SetCreative(owner,false)
end

-- E. the tutorial for the owner -----------------------------------------------------------------------------------------------------------------------------
do
 local G158=W.module('BeginnerGuide')
 local premium=D:GetPremium(owner)
 premium.Tutorial={Version=1,Mask=255,Done=true,Fast=true,FastCrop='crop1'};D:PublishTutorial(owner)
 check(owner:GetAttribute('TutorialDone')==true and owner:GetAttribute('TutorialStep')==0,'E: (before) a finished tutorial')
 local ok,text=run(admin,'/test tutorial reset');check(ok==false and tostring(text):find('game owner only',1,true)~=nil,'E: an admin cannot restart the tutorial')
 ok,text=run(owner,'/test tutorial reset')
 local t=premium.Tutorial
 check(ok==true and t.Done==false and t.Mask==1 and t.Fast==nil and t.FastCrop==nil,'E: tutorial reset: not done, the mask is back to the start, Fast / FastCrop are gone (a new 10-second fruit)')
 check(owner:GetAttribute('TutorialDone')==false and owner:GetAttribute('TutorialStep')==1,'E: ... and the player\'s screen is told: TutorialStep 1, TutorialDone false')
 check(owner:GetAttribute('TutorialRestart158f')==1,'E: ... the client restarts from its first look (TutorialRestart158f)')
 local expect={[1]=1,[2]=1,[3]=1,[4]=4,[5]=6,[6]=6,[7]=7,[8]=7,[9]=9,[10]=10}
 for n=1,10 do
  ok=run(owner,'/test tutorial step '..n);check(ok==true and owner:GetAttribute('TutorialStep')==expect[n]and owner:GetAttribute('TutorialDone')==false,'E: tutorial step '..n..' shows published step '..expect[n]..' (got '..tostring(owner:GetAttribute('TutorialStep'))..')')
 end
 ok=run(owner,'/test tutorial step 11');check(ok==false,'E: step 11 is refused')
 ok,text=run(owner,'/test tutorial done');check(ok==true and owner:GetAttribute('TutorialDone')==true and owner:GetAttribute('TutorialStep')==0,'E: tutorial done finishes it')
 check(premium.StarterPack==true and packs(owner)>200,'E: ... and the free Forest pack came (once per account)')
 local n=packs(owner);run(owner,'/test tutorial done');check(packs(owner)==n,'E: ... not again')
 -- a normal player still cannot replay
 check(D:TutorialAction(owner,'Replay')==false and owner:GetAttribute('TutorialDone')==true,'E: the normal Replay request is still refused (only the owner commands restart it)')
 -- the 10-second fruit works again after a reset: Fast is clear
 run(owner,'/test tutorial reset');check(D:GetPremium(owner).Tutorial.Fast==nil,'E: after a reset the first fruit is quick again (Fast is nil)')
end

-- F. newplayer, verityevent, droppack, bonusrolls, holo, the help ---------------------------------------------------------------------------------------------
do
 local ok,text=run(admin,'/test newplayer');check(ok==false and tostring(text):find('game owner only',1,true)~=nil,'F: an admin cannot use newplayer')
 local premium=D:GetPremium(owner);premium.StarterPack=true;premium.Tutorial={Version=1,Mask=255,Done=true,Fast=true,FastCrop='x'}
 local bag=D:GetChestRecords(owner);for i=#bag,1,-1 do table.remove(bag,i)end
 owner.Character.HumanoidRootPart.CFrame=R.CFrame.new(0,5,-380) -- (back at the pedestal)
 D:PublishTutorial(owner);s.Svc:Claim(owner) -- the Void pedestal claim to clear (it needs a finished tutorial)
 check(premium[Rules.Flag]==true,'F: (setup) the Void claim is set')
 ok,text=run(owner,'/test newplayer')
 check(ok==true and tostring(text):find('WARNING',1,true)~=nil,'F: newplayer warns in its text that it resets those flags ('..tostring(text):sub(1,60)..')')
 check(premium.Tutorial.Done==false and premium.Tutorial.Fast==nil and owner:GetAttribute('TutorialStep')==1,'F: ... the tutorial restarts at step 1 (Fast cleared)')
 check(premium.StarterPack==nil and owner:GetAttribute('StarterPackClaimed')==false,'F: ... the free Forest starter pack flag is cleared')
 check(premium[Rules.Flag]==nil,'F: ... the Void pedestal claim is cleared (live)')
 local SR=W.module('StarterVerityRules158d');check(premium[SR.Flag]==SR.Owed,'F: ... and the starter Verity gift is owed again (flag '..tostring(premium[SR.Flag])..')')
 -- verityevent
 ok,text=run(owner,'/test verityevent off');check(ok==true and Limited.Active(now())==false,'F: verityevent off ends the limited event')
 ok,text=run(owner,'/test verityevent on');check(ok==true and Limited.Active(now())==true,'F: verityevent on starts it')
 ok,text=run(owner,'/test verityevent auto');check(ok==true,'F: verityevent auto goes back to the real end date')
 ok=run(owner,'/test verityevent off @Bob');check(ok==false,'F: verityevent is a server command: no @name')
 ok,text=run(admin,'/test verityevent off');check(ok==false and tostring(text):find('game owner only',1,true)~=nil,'F: an admin cannot use verityevent')
 -- droppack
 ok,text=run(owner,'/test droppack storm 6 120');check(ok==true and drops[1]and drops[1][1]==owner and drops[1][2]==7 and drops[1][3]==6 and drops[1][4]==120,'F: droppack storm 6 120 asks for a storm tier 6 drop of 120 s at the owner')
 ok=run(owner,'/test droppack');check(ok==true and drops[2][2]==1 and drops[2][3]==3 and drops[2][4]==60,'F: droppack alone: forest, tier 3, 60 s')
 ok=run(owner,'/test droppack mars');check(ok==false,'F: a wrong biome is refused')
 -- bonusrolls = bonus ready (at most 2 are ever ready)
 local granted={};chase.TreadmillBonus={Ready={},GrantReady=function(_,p,n)granted[#granted+1]={p,n};return true,n end}
 ok,text=run(owner,'/test bonusrolls 2');check(ok==true and granted[1]and granted[1][1]==owner and granted[1][2]==2,'F: bonusrolls 2 makes 2 bonus rolls ready ('..tostring(text)..')')
 ok=run(owner,'/test bonusrolls 7');check(ok==true and granted[2]and granted[2][2]==2,'F: bonusrolls 7 is held to the game\'s 2')
 ok=run(owner,'/test bonusrolls x');check(ok==false,'F: bonusrolls needs a number')
 -- holo: both seeds exist in the seed list the command gives from
 local Packs=W.module('SeedPackRules');check(Packs.SeedDesignById.HoloMelonSeed~=nil and Packs.SeedDesignById.HoloAppleTreeSeed~=nil,'F: the Holo Melon and the Holo Apple Tree seeds are in the seed list (holo gives both)')
 -- walls (nothing built on the mock map: it says so) / batstats
 ok,text=run(owner,'/test walls');check(ok==true and tostring(text):find('R158 walls',1,true)~=nil and tostring(text):find('Lava streams and pools left: 0',1,true)~=nil,'F: walls prints the R158 state ('..tostring(text):sub(1,50)..')')
 ok,text=run(owner,'/test batstats');check(ok==true and tostring(text):find('hit: 7',1,true)~=nil,'F: batstats prints the counters')
 -- the help lists every new command and the old Studio-only rows were reworded
 local Help=W.module('StudioTestHelp');local seen={}
 for _,row in ipairs(Help)do for _,name in ipairs({'creative','fly','droppack','tutorial','newplayer','fastfruit','verityevent','bonusrolls','holo','reveal','walls','batstats'})do
  if row[1]:find('/test '..name,1,true)then seen[name]=true end
 end end
 local missing={};for _,name in ipairs({'creative','fly','droppack','tutorial','newplayer','fastfruit','verityevent','bonusrolls','holo','reveal','walls','batstats'})do if not seen[name]then missing[#missing+1]=name end end
 check(#missing==0,'F: /test help lists every new command (missing: '..table.concat(missing,', ')..')')
 ok,text=run(owner,'/test help');check(ok==true and tostring(text):find('/test creative',1,true)~=nil and tostring(text):find('/test newplayer',1,true)~=nil,'F: the /test help text carries them')
 for _,row in ipairs(Help)do
  local padded=' '..row[2]:lower()..' '
  if padded:find('%f[%a]ur%f[%A]')or padded:find('%f[%a]u%f[%A]')then check(false,'F: help row "'..row[1]..'" has a "u" / "ur"')end
 end
end

-- G. the dispatcher itself: no wait between commands for the owner (an admin waits), creative ends when the player leaves
do
 local rawNew=R.Instance.new -- (the mock's TextChatCommand has no Triggered signal)
 R.Instance.new=function(class,...)local i=rawNew(class,...);if class=='TextChatCommand'then i.Triggered=R.signal()end;return i end
 for _,q in ipairs(H.players)do q.CharacterAdded=R.signal()end
 R.Inst.FireClient=R.Inst.FireClient or function()end
 local rawSpawn=R.task.spawn;R.task.spawn=function()end -- (the periodic re-publish loop would spin: the mock's task.wait does not wait)
 local okStart,controller=pcall(SC.Start,D.Config,D,s.Chests,chase,bases,s.Notes,{MapRoot=s.Root})
 R.task.spawn=rawSpawn
 if not check(okStart and controller~=nil,'G: (setup) the owner tools start on the mock ('..tostring(controller)..')')then print(controller)
 else
  local folder=G.RS:FindFirstChild('ChestChaseStudioTests');local execute=folder and folder:FindFirstChild('Execute')
  check(execute~=nil and type(execute.OnServerInvoke)=='function','G: the Execute remote is there')
  if execute and type(execute.OnServerInvoke)=='function'then
   local a1=execute.OnServerInvoke(owner,'/test cash 1');local a2=execute.OnServerInvoke(owner,'/test cash 2')
   check(a1==true and a2==true and D:GetCash(owner)==2,'G: the owner\'s second command right after the first is not made to wait')
   local b1=execute.OnServerInvoke(admin,'/test cash 1');local b2,why=execute.OnServerInvoke(admin,'/test cash 2')
   check(b1==true and b2==false and tostring(why):find('Wait a moment',1,true)~=nil,'G: an admin still waits between commands ("Wait a moment.")')
   local carol=player(505,'Carol');State.SetCreative(carol,true)
   G.leave(carol);check(not State.Creative(carol)and carol:GetAttribute('CreativeMode158f')==nil,'G: leaving the game ends creative mode (PlayerRemoving)')
  end
  controller:Destroy()
 end
 R.Instance.new=rawNew
end

print(string.format('creative158f: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
