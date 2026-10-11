--!nocheck
-- R158l (owner: "give me a command that can make me giant and I can give packs and I can make them rain from the sky and disco all over", then a server-wide sound): the owner's party commands on the Roblox
-- mock (the R152 giveaway harness: the REAL scripts of this checkout) with a LIVE server (RunService:IsStudio() is false) whose place was created by user 501.
--  A. who can run what: the owner runs each command, an admin and a normal player cannot (givepack is a plain grant: an admin may, with the limits of /test pack); the parsers; no /test party;
--  B. giant: scales the character (the game's own size under it), keeps the walk speed, raises the jump, lifts the character, tells MovementGuard, survives a respawn, clears with giant off / scale 1 / leaving;
--  C. givepack: biome / rarity / both / pack names, counts, @name and @all, TEST packs;
--  D. packrain: at most 100 at once, every pack made and taken once by TOUCH, expiring 10 s after landing, a random look 0.6x-2x, random spots over the map, off, a full Bag;
--  E. disco: the workspace attribute (on / seconds / off, a server-wide command), the client's scene (full / Fast Mode / Reduced Motion) and Lighting exactly as it was afterwards;
--  F. sound: one OwnerSound158l in SoundService, replaced by a new one, stop, bad ids refused, an asset that cannot load gives the one message;
--  G. the F4 help lists the commands.
local G=require('./giveaway_harness');local C=require('./party_clients');local H,W,R=G.H,G.W,G.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Run=W.service('RunService');Run.IsStudio=function()return false end
W.game.CreatorType=R.Enum.CreatorType.User;W.game.CreatorId=501 -- the place was created by user 501: the GAME OWNER
local ServerFolder=W.service('ServerScriptService').ChestChaseServer
local Access=H.server('OwnerCommandAccess');local State=H.server('OwnerTestState82')
local SC=H.server('StudioTestCommands');local Rain=H.server('PackRain158l');local Rules=W.module('PartyRules158l')
ServerFolder.OwnerCommandAccess:SetAttribute('AdminUserIds','502')
do local n=0;W.service('HttpService').GenerateGUID=function()n+=1;return'guid-'..n end end -- (the mock has none)
local Players=W.service('Players');local SoundService=W.service('SoundService');local Lighting=W.service('Lighting')
function Players.GetPlayerFromCharacter(_,model)for _,p in ipairs(H.players)do if p.Character==model then return p end end;return nil end
-- Humanoids as Roblox has them: ScaleTo also scales HipHeight / WalkSpeed / JumpPower (the game's BaseService says so: "ScaleTo also adjusts physical movement properties")
do
 local scaleTo=R.Inst.ScaleTo
 function R.Inst.ScaleTo(self,k)
  local before=self._scale or 1;scaleTo(self,k);local f=k/before
  for _,d in ipairs(self:GetDescendants())do if d._class=='Humanoid'then d.HipHeight=(d.HipHeight or 0)*f;d.WalkSpeed=(d.WalkSpeed or 0)*f;d.JumpPower=(d.JumpPower or 0)*f;d.JumpHeight=(d.JumpHeight or 0)*f end end
 end
end
-- a live server with its fake data
local backend=G.backend()
local s=G.server(backend,nil,{Studio=false,Name='Live',Config={MaxSavedChests=1000,GardenPlotCount=2,MaxSavedHarvests=500}})
local D=s.Data
H.server('InventoryCap155').Attach(D)
D.Gardens={};D.Notifications=nil
D.Config.GetSeedById=function(id)return{Id=id,Name=id,Emoji='?',Color=R.Color3.fromRGB(1,2,3)}end
D.Config.BiomeTrackStartZ=0;D.Config.BiomeTrackEndZ=1445
function D:GetOrCreateSpeedValue()return{Value=0}end
local cash={};function D:GetOrCreateCashValue(p)cash[p]=cash[p]or{Value=0};return cash[p]end
function D:GetCash(p)return D:GetOrCreateCashValue(p).Value end
function D:_gardenChanged()end
function D:_notifySeedInventory()end
-- the chests: SyncTools + the REAL pack builder (SeedPackVisuals.Bag, the stand-in meshes of the harness) and its bounds, as ChestService has them
local Visuals=W.module('SeedPackVisuals')
local chests=s.Chests
chests.IsOpening=function()return false end
function chests:BuildSeedPacket(_,origin,parent,scale,weldRoot,stage,variant,seedScale,size,mutation,shape)return Visuals.Bag(origin,parent,scale,weldRoot,stage,variant,seedScale,size,mutation,nil,nil,shape)end
function chests:GetPackBounds(stage,variant,mult)local b=Visuals.Bounds(stage,variant,mult);b.Radius=math.max(b.Radius,Visuals.PlatformDimensions(stage,variant,mult).Radius);return b end
-- the map: the lobby floor of the harness (680 x 520 at 0,2,-360), the track line, the lobby spawn
local root=s.Root;local lobby=root.Lobby
local line=R.new('Part');line.Name='BaseBoundaryLine';line.Size=V3(400,10,4);line.CFrame=CF(0,5,-100);line.Parent=lobby
local spawn=R.new('Part');spawn.Name='FallbackSpawn';spawn.CFrame=CF(10,6,-300);spawn.Parent=lobby
local runtime=R.new('Folder');runtime.Name='RuntimeFolder';runtime.Parent=root
local map={MapRoot=root,LobbyFolder=lobby,BaseBoundaryLine=line,FallbackSpawn=spawn,RuntimeFolder=runtime,BaseRecords={}}
local bases={_applyPhysicalSpeed=function()end,GetPlayerBase=function()return nil end,StopTraining=function()end}
local ground=R.new('Part');ground.Name='Ground';ground.Size=V3(5000,2,5000);ground.CFrame=CF(0,4,0);ground.Parent=W.workspace
-- the world below the sky: one flat ground at y 5 (a ray from above hits it), a box query that sees the characters
function W.workspace.Raycast(_,origin)return{Position=V3(origin.X,5,origin.Z),Normal=V3(0,1,0),Material=R.Enum.Material.Grass,Instance=ground}end
function W.workspace.GetPartBoundsInBox(_,cf,size)
 local out={}
 for _,p in ipairs(H.players)do
  local c=p.Character;local r=c and c:FindFirstChild('HumanoidRootPart')
  if r then local d=r.Position-cf.Position;if math.abs(d.X)<=size.X/2 and math.abs(d.Y)<=size.Y/2 and math.abs(d.Z)<=size.Z/2 then out[#out+1]=r end end
 end
 return out
end
local ctx={Data=D,Config=D.Config,Chests=chests,Chase={Notifications=s.Notes,IsPlayerBusy=function()return false end},Bases=bases,Map=map}
local function player(id,name)local p=G.player(s,id,name,{});p.CharacterAdded=R.signal();p.CameraMaxZoomDistance=100;return p end
local owner,admin,normal,bob,carol=player(501,'Owner'),player(502,'Admin'),player(503,'Normal'),player(504,'Bob'),player(505,'Carol')
local function run(p,text)return SC.Execute(ctx,p,text)end
local function packs(p)return#D:GetChestRecords(p)end
local function seconds(n)G.run(n,.05)end
local function hosts()local f=W.workspace:FindFirstChild('PackRain158l');return f and f:GetChildren()or{}end
-- a character as the game made it: the game's own size (BaseService.ApplyCharacterScale: ChestChaseAvatarScale 1.25) is on it, then the Humanoid's numbers
local function dress(m)
 m:ScaleTo(1.25);local h=m:FindFirstChildOfClass('Humanoid');h.HipHeight=2.5;h.WalkSpeed=16;h.JumpPower=50;h.JumpHeight=7.2;return m,h
end
for _,p in ipairs({owner,admin,normal,bob,carol})do dress(p.Character);p.Character:SetAttribute('ChestChaseAvatarScale',1.25)end

-- A. who can run what; the parsers ----------------------------------------------------------------------------------------------------------------------------------
do
 for _,text in ipairs({'/test giant','/test packrain 3','/test disco','/test sound 123','/test givepack storm'})do
  local ok,why=run(normal,text);check(ok==false and tostring(why):find('owner or configured admins',1,true)~=nil,'A: a normal player is refused: '..text)
 end
 for _,text in ipairs({'/test giant','/test giant 3 @Bob','/test packrain 3','/test packrain off','/test disco','/test disco off','/test sound 123','/test sound stop'})do
  local ok,why=run(admin,text);check(ok==false and tostring(why):find('game owner only',1,true)~=nil,'A: an admin is refused ("game owner only"): '..text)
 end
 check(not State.Giant(admin)and not State.Giant(bob)and W.workspace:GetAttribute('Disco158l')==nil and SoundService:FindFirstChild('OwnerSound158l')==nil and not Rain.State,'A: and nothing happened')
 local ok,why=run(admin,'/test givepack forest 2');check(ok==true and packs(admin)==2,'A: givepack is a plain grant: an admin may use it ('..tostring(why)..')')
 ok=run(admin,'/test givepack forest 150');check(ok==false and packs(admin)==2,'A: ... with the 100-pack limit of /test pack')
 ok,why=run(owner,'/test party');check(ok==false,'A: there is NO /test party ('..tostring(why)..')')
 ok=run(owner,'/test party off');check(ok==false,'A: ... nor party off')
 -- the parsers
 check(Rules.ParseGiant({})==5 and Rules.ParseGiant({'10'})==10 and Rules.ParseGiant({'2.5'})==2.5 and Rules.ParseGiant({'off'})=='off' and Rules.ParseGiant({'1'})=='off','A: giant: default 5, 1-20, off, 1 = off')
 check(Rules.ParseGiant({'21'})==nil and Rules.ParseGiant({'0.5'})==nil and Rules.ParseGiant({'x'})==nil and Rules.ParseGiant({'5','6'})==nil,'A: giant: 21, 0.5, a word and two words are refused')
 local r=Rules.ParseRain({});check(r.Count==30 and r.Seconds==20 and r.Stage==nil and r.Tier==nil,'A: packrain: 30 packs over 20 s by default, any biome and tier')
 r=Rules.ParseRain({'40','storm','epic','30'});check(r.Count==40 and r.Seconds==30 and r.Stage==7 and r.Tier==4,'A: packrain 40 storm epic 30')
 check(Rules.ParseRain({'off'}).Off==true and Rules.ParseRain({'0'})==nil and Rules.ParseRain({'501'})==nil and Rules.ParseRain({'10','mars'})==nil and Rules.ParseRain({'10','storm','forest'})==nil and Rules.ParseRain({'10','20','30'})==nil and Rules.ParseRain({'10','1'})==nil,'A: packrain: off; 0, 501, an unknown word, two biomes, three numbers and 1 s are refused')
 check(Rules.ParseDisco({}).Mode=='on' and Rules.ParseDisco({'off'}).Mode=='off' and Rules.ParseDisco({'90'}).Seconds==90 and Rules.ParseDisco({'1'})==nil and Rules.ParseDisco({'x'})==nil,'A: disco: on, off, seconds (5-3600)')
 check(Rules.ParseSoundId('123')=='rbxassetid://123' and Rules.ParseSoundId('rbxassetid://456')=='rbxassetid://456' and Rules.ParseSoundId('RBXASSETID://7')=='rbxassetid://7'
  and Rules.ParseSoundId('https://www.roblox.com/library/123')==nil and Rules.ParseSoundId('12a')==nil and Rules.ParseSoundId('0')==nil and Rules.ParseSoundId('-5')==nil and Rules.ParseSoundId('')==nil,'A: sound ids: a bare number or rbxassetid://N only')
 local sp=Rules.ParseSound({'5','10','loop'});check(sp and sp.Volume==10 and sp.Loop==true,'A: sound 5 10 loop')
 check(Rules.ParseSound({'5','11'})==nil and Rules.ParseSound({'5','-1'})==nil and Rules.ParseSound({'5','loop','loop'})==nil and Rules.ParseSound({'stop'}).Stop==true,'A: sound: volume 0-10, loop once, stop')
end

-- B. giant ----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local m=owner.Character;local h=m:FindFirstChildOfClass('Humanoid');local y0=m:GetPivot().Position.Y;local serial=owner:GetAttribute('MovementResetSerial')or 0
 check(m:GetScale()==1.25 and h.JumpPower==50,'B: (before) the game\'s own size, jump 50')
 local ok,text=run(owner,'/test giant 5');check(ok==true,'B: the owner runs giant 5 ('..tostring(text)..')')
 check(math.abs(m:GetScale()-6.25)<1e-6,'B: the character is 5x the game\'s own size (1.25 x 5 = '..m:GetScale()..')')
 check(h.WalkSpeed==16,'B: the walk speed stays the game\'s (a giant does not run faster: '..h.WalkSpeed..')')
 check(math.abs(h.JumpPower-50*math.sqrt(5))<1e-6 and math.abs(h.JumpHeight-7.2*5)<1e-6,'B: the jump grows with the body (JumpPower x sqrt 5, JumpHeight x 5)')
 check(m:GetPivot().Position.Y>y0+5,'B: the character is lifted by the added height, not left in the floor ('..y0..' -> '..m:GetPivot().Position.Y..')')
 check((owner:GetAttribute('MovementResetSerial')or 0)>serial,'B: MovementGuard was told (a Reset: the sudden height is no teleport)')
 check(State.Giant(owner)==5 and owner:GetAttribute('Giant158l')==5,'B: OwnerTestState82.Giant is 5 (MovementGuard reads it) and the player attribute too')
 check(owner.CameraMaxZoomDistance>100,'B: the camera may zoom out further ('..owner.CameraMaxZoomDistance..')')
 -- survives respawn
 local fresh=H.character(owner,V3(0,5,-300));local _,fh=dress(fresh)
 owner.CharacterAdded:Fire(fresh)
 check(fresh:GetScale()==1.25,'B: a new character waits for the game\'s own size first (not scaled yet)')
 fresh:SetAttribute('ChestChaseAvatarScale',1.25)
 check(math.abs(fresh:GetScale()-6.25)<1e-6 and fh.WalkSpeed==16,'B: the new character is a giant again once the game has sized it (respawn keeps it)')
 -- another number, still the same giant
 ok=run(owner,'/test giant 10');check(ok==true and math.abs(fresh:GetScale()-12.5)<1e-6 and State.Giant(owner)==10,'B: giant 10 replaces 5 (x1.25 x 10)')
 -- refused numbers
 for _,text in ipairs({'/test giant 21','/test giant 0','/test giant 0.5','/test giant big','/test giant 3 4'})do ok=run(owner,text);check(ok==false and State.Giant(owner)==10,'B: refused: '..text)end
 -- off
 ok,text=run(owner,'/test giant off');check(ok==true and math.abs(fresh:GetScale()-1.25)<1e-6 and State.Giant(owner)==nil and owner:GetAttribute('Giant158l')==nil,'B: giant off: the game\'s own size again, nothing left ('..tostring(text)..')')
 check(fh.JumpPower==50 and fh.JumpHeight==7.2 and fh.WalkSpeed==16 and owner.CameraMaxZoomDistance==100,'B: ... jump, speed and camera as before')
 local again=H.character(owner,V3(0,5,-300));dress(again);again:SetAttribute('ChestChaseAvatarScale',1.25);owner.CharacterAdded:Fire(again)
 check(again:GetScale()==1.25,'B: ... and a respawn after giant off is a normal size')
 ok=run(owner,'/test giant off');check(ok==true,'B: giant off when not a giant is harmless')
 -- scale 1 = off; @name; @all; leaving
 run(owner,'/test giant 4');ok=run(owner,'/test giant 1');check(ok==true and State.Giant(owner)==nil and owner.Character:GetScale()==1.25,'B: giant 1 = giant off')
 ok,text=run(owner,'/test giant 3 @Bob');check(ok==true and State.Giant(bob)==3 and math.abs(bob.Character:GetScale()-3.75)<1e-6,'B: giant 3 @Bob scales Bob ('..tostring(text)..')')
 check(State.Giant(owner)==nil,'B: ... and not the owner')
 ok=run(owner,'/test giant 2 @all');check(ok==true and State.Giant(owner)==2 and State.Giant(carol)==2 and State.Giant(bob)==2,'B: giant 2 @all scales everyone in the server')
 Players.PlayerRemoving:Fire(carol);check(State.Giant(carol)==nil,'B: a player who leaves is no longer a giant (memory cleared)')
 ok=run(owner,'/test giant off @all');check(ok==true and State.Giant(owner)==nil and State.Giant(bob)==nil and owner.Character:GetScale()==1.25 and bob.Character:GetScale()==1.25,'B: giant off @all puts everyone back')
 -- a character that is dead: set, applies on respawn
 local m2=bob.Character;m2:FindFirstChildOfClass('Humanoid').Health=0
 ok,text=run(owner,'/test giant 5 @Bob');check(ok==true and State.Giant(bob)==5 and m2:GetScale()==1.25 and tostring(text):find('applies',1,true)~=nil,'B: a dead character is not scaled; it applies on respawn ('..tostring(text)..')')
 local reborn=H.character(bob,V3(0,5,-300));dress(reborn);reborn:SetAttribute('ChestChaseAvatarScale',1.25);bob.CharacterAdded:Fire(reborn)
 check(math.abs(reborn:GetScale()-6.25)<1e-6,'B: ... and it did')
 run(owner,'/test giant off @Bob')
end

-- C. givepack -------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local base=packs(bob)
 local ok,text=run(owner,'/test givepack storm 5 @Bob')
 check(ok==true and packs(bob)==base+5,'C: givepack storm 5 @Bob gives 5 ('..tostring(text)..')')
 local allStorm,allTier3,allTest=true,true,true
 for i=base+1,base+5 do local r=D:GetChestRecords(bob)[i];if r.Stage~=7 then allStorm=false end;if r.BagVariant~='Pack03'then allTier3=false end;if r.TestGrant~=true then allTest=false end end
 check(allStorm and allTier3,'C: a biome alone = that biome, tier 3 (Rare), like /test pack')
 check(allTest,'C: every one is a TEST pack (TestGrant: never announced, no BEST PULL)')
 base=packs(bob);ok=run(owner,'/test givepack legendary 12 @Bob')
 local seen,tier5,sum={},true,0
 for i=base+1,packs(bob)do local r=D:GetChestRecords(bob)[i];sum+=1;seen[r.Stage]=true;if r.BagVariant~='Pack05'or r.TestGrant~=true then tier5=false end end
 local kinds=0;for _ in pairs(seen)do kinds+=1 end
 check(ok==true and sum==12 and tier5 and kinds>=2,'C: a rarity alone = that tier in a random biome for each pack (12 legendary packs over '..kinds..' biomes)')
 base=packs(bob);ok=run(owner,'/test givepack mythic desert 3 @Bob');local last=D:GetChestRecords(bob)
 check(ok==true and packs(bob)==base+3 and last[#last].Stage==2 and last[#last].BagVariant=='Pack06','C: both words, any order: givepack mythic desert 3 = 3 mythic desert packs')
 local mine=packs(owner);ok=run(owner,'/test givepack storm');check(ok==true and packs(owner)==mine+1,'C: no count = 1, no @name = yourself')
 base=packs(bob);ok=run(owner,'/test givepack void 2 @Bob');check(ok==true and packs(bob)==base+2 and D:voidPacks(bob)>=2,'C: a pack name (void) uses the normal void grant')
 base=packs(bob);ok=run(owner,'/test givepack 400 snow @Bob');check(ok==true and packs(bob)==base+400,'C: the owner may give 400 at once (past the Bag cap)')
 -- @all
 local before={};for _,p in ipairs(H.players)do before[p]=packs(p)end
 ok,text=run(owner,'/test givepack lava 2 @all')
 local every=true;for _,p in ipairs(H.players)do if packs(p)~=before[p]+2 then every=false end end
 check(ok==true and every,'C: @all gives every player in the server (including the admin and the player who has no commands)')
 -- errors
 for _,t in ipairs({'/test givepack','/test givepack mars','/test givepack storm 0','/test givepack storm 2 3','/test givepack storm storm','/test givepack king 30','/test givepack 5'})do
  local before2=packs(owner);ok=run(owner,t);check(ok==false and packs(owner)==before2,'C: refused: '..t)
 end
 -- the plan itself
 local plan=Rules.GivePlan({'legendary','100'},function(lo)return lo end);check(plan and#plan.Commands==1 and plan.Commands[1].Text=='pack forest 5 1 none 100' and plan.Total==100,'C: GivePlan(legendary 100), the first biome every time = one pack command')
 plan=Rules.GivePlan({'storm','mythic','2'});check(plan and plan.Commands[1].Text=='pack storm 6 1 none 2','C: GivePlan(storm mythic 2) = pack storm 6 1 none 2')
 -- no packs from a normal player
 local n=packs(normal);local nb=packs(bob);ok=run(normal,'/test givepack storm 3 @Bob');check(ok==false and packs(bob)==nb and packs(normal)==n,'C: a normal player cannot')
end

-- D. packrain -------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local function cleanup()run(owner,'/test packrain off')end
 -- D1. the cap, the spread, the look
 local ok,text=run(owner,'/test packrain 250 20');check(ok==true and tostring(text):find('PACK RAIN',1,true)~=nil,'D: packrain 250 20 starts ('..tostring(text):sub(1,60)..')')
 check(s.Notes:count(bob)>=1 and tostring(s.Notes:last(bob).Text):find('PACK RAIN',1,true)~=nil,'D: everybody gets the PACK RAIN! notice')
 local maxAlive,sawHub,sawTrack,sawNear=0,false,false,false
 local stagesSeen,tiersSeen,minScale,maxScale={},{},9,0
 local seenHost={};local attrsOk,tagged,droppedFlag,aboveGround=true,true,true,true
 for _=1,60*20 do
  G.run(.05,.05)
  local list=hosts();if#list>maxAlive then maxAlive=#list end
  for _,host in ipairs(list)do if not seenHost[host]then
   seenHost[host]=true
   local sc=host:GetAttribute('RainScale');if sc<minScale then minScale=sc end;if sc>maxScale then maxScale=sc end
   stagesSeen[host:GetAttribute('Stage')]=true;local v=host:GetAttribute('BagVariant');tiersSeen[v]=(tiersSeen[v]or 0)+1
   for _,k in ipairs({'RainLandAt','RainFall','RainHeight','RainSpin','RainEndAt'})do if type(host:GetAttribute(k))~='number'then attrsOk=false end end
   if host:GetAttribute('DroppedChest')~=true then droppedFlag=false end
   if not W.CS:HasTag(host,'PackRain158l')then tagged=false end
   local at=host.Body.Position;if at.Y<=5 then aboveGround=false end
   if at.Z>0 and math.abs(at.X)<=130 then sawTrack=true end
   if math.abs(at.X)<=340 and at.Z>=-620 and at.Z<=-100 then sawHub=true end
   for _,p in ipairs({owner,bob,carol})do local pr=p.Character.HumanoidRootPart.Position;if math.abs(at.X-pr.X)<=56 and math.abs(at.Z-pr.Z)<=56 then sawNear=true end end
  end end
 end
 local total=0;for _ in pairs(seenHost)do total+=1 end
 check(maxAlive==100,'D: never more than 100 packs at once, and the cap was reached (max '..maxAlive..')')
 check(total==250,'D: all 250 packs fell in the end (the ones over the cap waited for room): '..total)
 check(attrsOk and tagged and droppedFlag and aboveGround,'D: every pack has its fall attributes, the PackRain158l tag, DroppedChest (the R158b highlight) and stands on the ground')
 check(minScale>=.6-1e-9 and maxScale<=2+1e-9 and minScale<1 and maxScale>1.5,'D: each pack has a random look size 0.6x-2x ('..string.format('%.2f',minScale)..' to '..string.format('%.2f',maxScale)..')')
 local nStages=0;for _ in pairs(stagesSeen)do nStages+=1 end
 check(nStages==7 and(tiersSeen.Pack01 or 0)>(tiersSeen.Pack06 or 0),'D: a random pack each: all 7 biomes, commons far more than mythics ('..tostring(tiersSeen.Pack01)..' vs '..tostring(tiersSeen.Pack06)..')')
 check(sawHub and sawTrack and sawNear,'D: spots all over the map: the hub, the track and around the players')
 check(#hosts()==0 and Rain.State==nil,'D: when the last pack is gone the rain is over')
 local okS,statusText=Rain.Status();check(okS and tostring(statusText):find('No pack rain',1,true)~=nil,'D: status after it: '..tostring(statusText))
 -- D2. one pack: taken by touch
 local function one(command)
  run(owner,command or'/test packrain 1 storm legendary 5')
  for _=1,200 do G.run(.05,.05);if#hosts()>0 then break end end
  local list=hosts();return list[1],list[1]and list[1].TouchBox
 end
 local host,touch=one();check(host~=nil and touch~=nil,'D: one pack (storm, legendary) is falling')
 local packet=host and host:FindFirstChild('SeedPacket')
 check(packet~=nil and packet:GetAttribute('WorldPack')==false and W.CS:HasTag(packet,'BiomeSeedPackVisual'),'D: its SeedPacket is the real pack art, tagged for the R158b highlight, with no server hover')
 local bobPart=bob.Character.HumanoidRootPart;local carolPart=carol.Character.HumanoidRootPart;local ownerPart=owner.Character.HumanoidRootPart
 local landAt=host:GetAttribute('RainLandAt');local before=packs(bob)
 touch.Touched:Fire(bobPart);check(packs(bob)==before and host.Parent~=nil,'D: touching a pack that is still high up does nothing yet')
 while R.clock<landAt-.1 do G.run(.05,.05)end
 touch.Touched:Fire(bobPart);touch.Touched:Fire(carolPart)
 local rec=D:GetChestRecords(bob)[packs(bob)]
 check(packs(bob)==before+1 and rec.Stage==7 and rec.BagVariant=='Pack05' and rec.TestGrant==true,'D: the first player to touch it gets it straight into the Bag: a normal Legendary Storm pack, TEST (TestGrant)')
 check(host.Parent==nil,'D: ... and the pack is gone')
 local ownerBefore,carolBefore=packs(owner),packs(carol)
 touch.Touched:Fire(ownerPart);touch.Touched:Fire(carolPart);check(packs(owner)==ownerBefore and packs(carol)==carolBefore,'D: ... a second touch gets nothing (each pack once)')
 check(s.Notes:last(bob)and tostring(s.Notes:last(bob).Text):find('Legendary Storm pack',1,true)~=nil,'D: Bob is told what he got')
 -- two at once: Carol first, Bob second
 cleanup();host,touch=one();landAt=host:GetAttribute('RainLandAt');while R.clock<landAt-.1 do G.run(.05,.05)end
 local b2,c2=packs(bob),packs(carol);touch.Touched:Fire(carolPart);touch.Touched:Fire(bobPart);check(packs(carol)==c2+1 and packs(bob)==b2,'D: two players in the same moment: the first one has it, the other gets nothing')
 -- D3. expiry: gone 10 s after it landed, not before
 cleanup();host,touch=one();landAt=host:GetAttribute('RainLandAt');local endAt=host:GetAttribute('RainEndAt')
 check(math.abs((endAt-landAt)-10)<1e-6 and Rules.Rain.LingerSeconds==10,'D: an untouched pack stays 10 s after it lands (a constant: PartyRules158l.Rain.LingerSeconds)')
 while R.clock<endAt-.6 do G.run(.05,.05)end
 check(host.Parent~=nil,'D: ... it is still there just before its time')
 while R.clock<endAt+.4 do G.run(.05,.05)end
 check(host.Parent==nil and#hosts()==0,'D: ... and gone just after')
 touch.Touched:Fire(bobPart);check(packs(bob)==b2,'D: a pack that is gone cannot be touched')
 -- D4. a player already standing on the spot when it lands
 cleanup();host,touch=one();local spot=touch.Position;bobPart.CFrame=CF(spot.X,spot.Y-1.5,spot.Z);local b3=packs(bob)
 local stopAt=host:GetAttribute('RainEndAt');while host.Parent and R.clock<stopAt do G.run(.05,.05)end
 check(packs(bob)==b3+1,'D: a player standing on the spot gets it as it lands (the box query, no Touched needed)')
 bobPart.CFrame=CF(0,5,-300)
 -- D5. a full Bag leaves the pack where it is
 cleanup();host,touch=one();landAt=host:GetAttribute('RainLandAt');while R.clock<landAt-.1 do G.run(.05,.05)end
 local cap=D.Config.MaxSavedChests;D.Config.MaxSavedChests=packs(bob);local b4=packs(bob);local notes=s.Notes:count(bob)
 touch.Touched:Fire(bobPart);touch.Touched:Fire(bobPart)
 check(packs(bob)==b4 and host.Parent~=nil and not Rain.State.Packs[host].Taken,'D: a full Bag: the pack stays and is not used up')
 check(s.Notes:count(bob)==notes+1,'D: ... one notice, not one for every touch')
 D.Config.MaxSavedChests=cap;touch.Touched:Fire(bobPart);check(packs(bob)==b4+1 and host.Parent==nil,'D: ... with room again, the next touch takes it')
 -- D6. off removes everything at once and stops the spawns
 run(owner,'/test packrain 60 20');seconds(6)
 check(#hosts()>5 and Rain.State~=nil,'D: (a rain is running: '..#hosts()..' packs)')
 ok,text=run(owner,'/test packrain off');check(ok==true and#hosts()==0 and Rain.State==nil,'D: packrain off removes every pack at once ('..tostring(text)..')')
 seconds(8);check(#hosts()==0,'D: ... and nothing falls after it')
 ok,text=run(owner,'/test packrain status');check(ok==true,'D: packrain status answers ('..tostring(text)..')')
 -- D7. the rules around it
 ok=run(owner,'/test packrain 0');check(ok==false,'D: packrain 0 is refused')
 ok=run(owner,'/test packrain 5 @Bob');check(ok==false,'D: packrain is a server command: no @name')
 ok=run(owner,'/test packrain 10 mars');check(ok==false,'D: an unknown biome is refused')
 -- a second rain keeps the packs lying and starts a new schedule
 run(owner,'/test packrain 4 forest 5');seconds(5.2);local lying=#hosts()
 run(owner,'/test packrain 3 forest 5');check(#hosts()==lying and lying>0,'D: a second packrain keeps the packs already lying ('..lying..')')
 seconds(40);check(#hosts()==0 and Rain.State==nil,'D: ... and everything is gone in the end');cleanup()
 check(Rules.Rain.MaxAtOnce==100 and Rules.Rain.ScaleMin==.6 and Rules.Rain.ScaleMax==2,'D: constants: cap 100, look size 0.6-2')
 -- D8. the screen's side (PackRainFx158l): the fall with a trail, the landing, the shrink; Fast Mode: no trail; Reduced Motion: no fall
 W.B.PackRainFx158l=C.PackRainFx158l
 local fxScript=R.new('LocalScript');fxScript.Name='PackRainFx158l';fxScript.Parent=Players
 H.tier=3;W.Gui.ReducedMotionEnabled=false
 local loops=H.renderConnections();W.load('PackRainFx158l',fxScript)
 local function fxFolder()return W.workspace:FindFirstChild('_PackRainFx158l')end
 local function trail()return fxFolder()and fxFolder():FindFirstChild('RainTrail')end
 local function fallingPack(command)local h=one(command);G.run(.05,.05);local pk=h:FindFirstChild('SeedPacket');return h,pk,h.Body.Position.Y end
 local baseY;host,packet,baseY=fallingPack()
 local y1=packet:GetPivot().Position.Y
 check(y1>baseY+50,'D: on the screen the pack falls from high up ('..string.format('%.0f',y1-baseY)..' studs over its spot)')
 check(trail()~=nil and H.renderConnections()==loops+1,'D: ... with a trail behind it, and the frame loop runs while it exists')
 landAt=host:GetAttribute('RainLandAt');endAt=host:GetAttribute('RainEndAt')
 while R.clock<landAt-.8 do G.run(.05,.05)end
 check(packet:GetPivot().Position.Y<y1-20 and packet:GetPivot().Position.Y>baseY,'D: ... lower as it goes ('..string.format('%.0f',packet:GetPivot().Position.Y-baseY)..' studs over its spot a moment before landing)')
 while R.clock<landAt+.1 do G.run(.05,.05)end
 check(math.abs(packet:GetPivot().Position.Y-baseY)<1e-6 and(packet:GetPivot().LookVector-CF(0,0,0).LookVector).Magnitude<1e-6,'D: it lands exactly on its spot, upright')
 G.run(1,.05);check(trail()==nil,'D: the trail is gone after it landed')
 while R.clock<endAt-.2 do G.run(.05,.05)end
 check(packet:GetScale()<.6,'D: an untouched pack shrinks away in its last half second ('..string.format('%.2f',packet:GetScale())..')')
 cleanup();G.run(.5,.05);check(H.renderConnections()==loops,'D: ... and with no pack left the frame loop is gone')
 H.tier=1;host,packet,baseY=fallingPack();check(packet:GetPivot().Position.Y>baseY+50 and trail()==nil,'D: Fast Mode: it still falls, with no trail');cleanup()
 H.tier=3;W.Gui.ReducedMotionEnabled=true;host,packet,baseY=fallingPack();check(math.abs(packet:GetPivot().Position.Y-baseY)<1e-6 and trail()==nil,'D: Reduced Motion: no fall, no spin, no trail (the pack is simply there)')
 W.Gui.ReducedMotionEnabled=false;cleanup();fxScript:Destroy();check(fxFolder()==nil,'D: the client script takes its own folder with it')
end

-- E. disco ----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local A,CA=Rules.Disco.Attribute,Rules.Disco.CenterAttribute
 local ok,text=run(owner,'/test disco');check(ok==true and W.workspace:GetAttribute(A)==-1,'E: disco = on until off: the workspace attribute is -1 ('..tostring(text):sub(1,40)..')')
 local c=W.workspace:GetAttribute(CA);check(c~=nil and c.X==10 and c.Z==-300,'E: ... and the hub (the lobby spawn) is the centre')
 ok,text=run(owner,'/test disco status');check(ok==true and tostring(text):find('until /test disco off',1,true)~=nil,'E: disco status says it is on')
 ok=run(owner,'/test disco off');check(ok==true and W.workspace:GetAttribute(A)==nil and W.workspace:GetAttribute(CA)==nil,'E: disco off clears both attributes')
 ok,text=run(owner,'/test disco 30');check(ok==true and math.abs(W.workspace:GetAttribute(A)-(R.clock+30))<.01,'E: disco 30 = until 30 s from now (a server time)')
 seconds(31);check(W.workspace:GetAttribute(A)==nil,'E: ... and it ends by itself (the attribute clears)')
 run(owner,'/test disco 30');run(owner,'/test disco');check(W.workspace:GetAttribute(A)==-1,'E: a plain disco after a timed one is until off ...')
 seconds(31);check(W.workspace:GetAttribute(A)==-1,'E: ... the old timer does not end it')
 ok=run(owner,'/test disco off @Bob');check(ok==false,'E: disco is a server command: no @name')
 for _,t in ipairs({'/test disco 1','/test disco x','/test disco 5000','/test disco on off'})do ok=run(owner,t);check(ok==false and W.workspace:GetAttribute(A)==-1,'E: refused, and the disco is untouched: '..t)end
 run(owner,'/test disco off')
 -- the client: Lighting as it was
 Lighting.Ambient=R.Color3.fromRGB(70,70,70);Lighting.OutdoorAmbient=R.Color3.fromRGB(100,110,120);Lighting.Brightness=2.5;Lighting.ClockTime=14;Lighting.ExposureCompensation=.2;Lighting.ColorShift_Top=R.Color3.fromRGB(1,2,3)
 local effect=R.new('ColorCorrectionEffect');effect.Name='ChestChaseColor';effect.Parent=Lighting
 local props={'Ambient','OutdoorAmbient','Brightness','ClockTime','ExposureCompensation','ColorShift_Top'}
 local function snapshot()local t={};for _,k in ipairs(props)do t[k]=Lighting[k]end;t.Children=#Lighting:GetChildren();return t end
 local function same(a,b)for _,k in ipairs(props)do if a[k]~=b[k]then return false end end;return a.Children==b.Children end
 R.Color3.fromHSV=function(h,sat,v) -- (a real HSV so the colour changes can be measured)
  local i=math.floor(h*6);local f=h*6-i;local p,q,t=v*(1-sat),v*(1-f*sat),v*(1-(1-f)*sat);i=i%6
  local r,g,b=v,t,p;if i==1 then r,g,b=q,v,p elseif i==2 then r,g,b=p,v,t elseif i==3 then r,g,b=p,q,v elseif i==4 then r,g,b=t,p,v elseif i==5 then r,g,b=v,p,q end
  return R.Color3.new(r,g,b)
 end
 local clientScript
 local function startClient()
  W.B.DiscoClient158l=C.DiscoClient158l;clientScript=R.new('LocalScript');clientScript.Name='DiscoClient158l';clientScript.Parent=Players
  W.load('DiscoClient158l',clientScript)
 end
 local function sceneParts(name)local f=W.workspace:FindFirstChild('_Disco158l');return f and H.parts(f,name)or{}end
 local function colorGap(a,b)return math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B)end
 local function flashes(tilePart,secondsLong)
  local last,changes,big=tilePart.Color,0,0
  for _=1,math.floor(secondsLong*20)do G.run(.05,.05);local now=tilePart.Color;if now~=last then changes+=1;if colorGap(now,last)>.5 then big+=1 end;last=now end end
  return changes,big
 end
 local function look(model)return model:GetPivot().LookVector end
 local before=snapshot();local loops=H.renderConnections()
 -- E1. full graphics; the party was already on when the client started (a late arrival)
 H.tier=3;W.Gui.ReducedMotionEnabled=false
 run(owner,'/test disco');startClient()
 local floorParts,beams,facets=sceneParts('Tile'),sceneParts('LightPool'),sceneParts('Facet')
 check(#floorParts==49 and#beams==6 and#facets==22,'E: a late arrival sees it at once: 49 floor tiles, 6 spotlights, a ball with 22 mirrors ('..#floorParts..'/'..#beams..'/'..#facets..')')
 check(Lighting:FindFirstChild('Disco158lTint')~=nil and Lighting:FindFirstChild('ChestChaseColor')==effect,'E: the tint is ONE added effect (the game\'s own effects stay)')
 check(#sceneParts('Ball')==1,'E: the ball is there')
 local flash=flashes(floorParts[1],3);check(flash>=1 and flash<=10,'E: the floor changes colour on the beat, never more than 3 times a second ('..flash..' changes in 3 s)')
 local emitted=0;for _,d in ipairs(W.workspace._Disco158l:GetDescendants())do if d._class=='ParticleEmitter'then emitted+=d._emitted or 0 end end
 check(emitted>0,'E: confetti bursts ('..emitted..' pieces)')
 local ball=W.workspace._Disco158l.DiscoBall;local look1=look(ball);G.run(.5,.05);check((look(ball)-look1).Magnitude>.01,'E: the ball spins')
 local poolAt=beams[1].Position;G.run(.5,.05);check(beams[1].Position~=poolAt,'E: the spotlights sweep')
 check(H.renderConnections()==loops+1,'E: a frame loop runs while it is on')
 run(owner,'/test disco off')
 check(W.workspace:FindFirstChild('_Disco158l')==nil and Lighting:FindFirstChild('Disco158lTint')==nil and same(snapshot(),before),'E: off: the scene and the tint are gone and Lighting is exactly as it was (every setting and every effect)')
 check(H.renderConnections()==loops,'E: ... and the frame loop is gone')
 -- E2. on again, by the attribute alone; it ends by its own time even if the server never clears it
 W.workspace:SetAttribute(CA,V3(0,5,-300));W.workspace:SetAttribute(A,W.workspace:GetServerTimeNow()+4)
 check(W.workspace:FindFirstChild('_Disco158l')~=nil,'E: the attribute alone starts it (the server does nothing else)')
 seconds(5);check(W.workspace:FindFirstChild('_Disco158l')==nil and same(snapshot(),before),'E: it stops at its time on the screen, by itself, Lighting as it was');W.workspace:SetAttribute(A,nil)
 -- E3. Fast Mode: fewer lights
 H.tier=1;run(owner,'/test disco');seconds(.2)
 local tiles1,beams1=sceneParts('Tile'),sceneParts('LightPool')
 local lights,emitters=0,0;for _,d in ipairs(W.workspace._Disco158l:GetDescendants())do if d._class=='PointLight'then lights+=1 end;if d._class=='ParticleEmitter'then emitters+=1 end end
 check(#tiles1==9 and#beams1==2 and lights==0 and emitters==0,'E: Fast Mode: 9 tiles, 2 spotlights, no light, no confetti ('..#tiles1..'/'..#beams1..'/'..lights..'/'..emitters..')')
 run(owner,'/test disco off');check(same(snapshot(),before),'E: ... and off restores Lighting')
 -- E4. Reduced Motion: no flashing
 H.tier=3;W.Gui.ReducedMotionEnabled=true;run(owner,'/test disco');seconds(.2)
 local tiles2=sceneParts('Tile');local ball2=W.workspace._Disco158l.DiscoBall;local look2=look(ball2);local pool=sceneParts('LightPool')[1].Position
 emitters=0;for _,d in ipairs(W.workspace._Disco158l:GetDescendants())do if d._class=='ParticleEmitter'then emitters+=1 end end
 local changes,bigChanges=flashes(tiles2[1],4)
 check(#tiles2==49 and bigChanges==0 and changes<=17,'E: Reduced Motion: no flashing (no colour jump, a slow drift only: '..changes..' small steps in 4 s, '..bigChanges..' big)')
 check((look(ball2)-look2).Magnitude<1e-9 and sceneParts('LightPool')[1].Position==pool and emitters==0,'E: ... the ball and the spotlights stand still and there is no confetti')
 local tint=Lighting:FindFirstChild('Disco158lTint');local t1=tint.TintColor;G.run(1,.05);check(colorGap(tint.TintColor,t1)<.12,'E: ... the tint only drifts (a slow hue, no jumps)')
 run(owner,'/test disco off');check(same(snapshot(),before),'E: ... and off restores Lighting');W.Gui.ReducedMotionEnabled=false;H.tier=3
 -- E5. the script going away takes everything with it
 run(owner,'/test disco');seconds(.2);clientScript:Destroy()
 check(W.workspace:FindFirstChild('_Disco158l')==nil and Lighting:FindFirstChild('Disco158lTint')==nil and same(snapshot(),before),'E: if the client script is destroyed while the party runs, its lights and tint go with it')
 run(owner,'/test disco off')
end

-- F. sound ----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local function sounds()local n=0;for _,c in ipairs(SoundService:GetChildren())do if c.Name=='OwnerSound158l'then n+=1 end end;return n end
 local ok,text=run(owner,'/test sound 12345');local snd=SoundService:FindFirstChild('OwnerSound158l')
 check(ok==true and snd~=nil and snd.SoundId=='rbxassetid://12345' and snd.Volume==1 and snd.Looped==false and snd._plays==1,'F: sound 12345 plays one OwnerSound158l in SoundService (everyone hears it; not positional): '..tostring(text):sub(1,50))
 ok=run(owner,'/test sound rbxassetid://777 5 loop');local snd2=SoundService:FindFirstChild('OwnerSound158l')
 check(ok==true and sounds()==1 and snd2~=snd and snd.Parent==nil and snd2.SoundId=='rbxassetid://777' and snd2.Volume==5 and snd2.Looped==true,'F: a new sound replaces the old one (one at a time), volume 5, looping')
 for _,t in ipairs({'/test sound','/test sound abc','/test sound https://www.roblox.com/library/123','/test sound 0','/test sound 123 11','/test sound 123 loud','/test sound 123 5 loop loop','/test sound 12 @Bob'})do
  ok=run(owner,t);check(ok==false and sounds()==1 and SoundService:FindFirstChild('OwnerSound158l')==snd2,'F: refused, the sound keeps playing: '..t)
 end
 ok,text=run(owner,'/test sound stop');check(ok==true and sounds()==0 and snd2.Parent==nil,'F: sound stop stops and removes it')
 ok=run(owner,'/test sound stop');check(ok==true,'F: stop with nothing playing is harmless')
 -- a sound that cannot load
 local base=R.Instance.new
 R.Instance.new=function(class,parent)local o=base(class,parent);if class=='Sound'then o.IsLoaded=false end;return o end
 ok,text=run(owner,'/test sound 999')
 R.Instance.new=base
 check(ok==false and text=="That sound couldn't load (it may be private or not allowed in this game)." and sounds()==0,'F: an asset that cannot load: the one plain message, nothing left in SoundService ('..tostring(text)..')')
 -- a sound that ends removes itself
 run(owner,'/test sound 55');local one=SoundService:FindFirstChild('OwnerSound158l');one.Ended:Fire();check(sounds()==0,'F: a sound that ends is removed')
end

-- G. the help ---------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local Help=W.module('StudioTestHelp');local seen={}
 for _,row in ipairs(Help)do
  for _,name in ipairs({'giant','givepack','packrain','disco','sound'})do if row[1]:find('/test '..name,1,true)==1 then seen[name]=row end end
  if row[1]:find('/test party',1,true)then seen.party=row end
 end
 for _,name in ipairs({'giant','givepack','packrain','disco','sound'})do check(seen[name]~=nil,'G: /test help lists /test '..name)end
 check(seen.party==nil,'G: ... and no /test party')
 local ok,text=run(owner,'/test help');check(ok==true and tostring(text):find('/test packrain',1,true)~=nil and tostring(text):find('/test disco',1,true)~=nil and tostring(text):find('/test sound',1,true)~=nil and tostring(text):find('/test giant',1,true)~=nil and tostring(text):find('/test givepack',1,true)~=nil,'G: the help text carries them')
 for _,row in ipairs(Help)do local padded=' '..row[2]:lower()..' ';if padded:find('%f[%a]ur%f[%A]')or padded:find('%f[%a]u%f[%A]')then check(false,'G: help row "'..row[1]..'" has a "u" / "ur"')end end
end
print(string.format('party158l: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
