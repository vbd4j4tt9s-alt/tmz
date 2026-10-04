--!nocheck
-- R149 z-fighting: the whole map as players see it. Loads the owner's Workspace.ChestChaseMap (place_tree.luau) into the Roblox mock,
-- runs the REAL startup builders on it (MapService's map passes, MarketLayout, the treadmills, the mystery pedestals, Verity's dais,
-- GardenTypography, the fence / upgrade buttons, the leaderboards, the shop ...) and the client builders that put parts in the world,
-- then prints the scene for zfight.py: one line "SCENE {...}". Every step runs on its own (pcall); a step that fails is reported as
-- "STEP <name> FAILED <why>" and the rest still runs.
-- Globals (optional): SKIP_CLIENT = true (server geometry only), SKINS / FENCES = treadmill skin / fence tier per base
-- ({1,2,3,4,5,6} by default; run again with {7,7,7,7,7,7} for the seventh), RUNNER = {x, z} of the local player on the track
-- (the keyboard and the snow patches are drawn around him; the test shovel hole is dug just ahead of him).
-- MapService.new calls ZFightFix149.Apply itself when the src tree has it (R149), exactly as the live server does.
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return{}end
function Players.GetPlayerByUserId()return nil end;function Players.GetUserThumbnailAsync()return'',true end
local Http=W.service('HttpService');local guid=0;function Http.GenerateGUID()guid+=1;return'guid-'..guid end;function Http.JSONEncode(_,t)return'{}'end;function Http.JSONDecode()return{}end
local DS=W.service('DataStoreService');function DS.GetDataStore()return{GetAsync=function()return nil end,SetAsync=function()end,UpdateAsync=function()return nil end}end;DS.GetOrderedDataStore=DS.GetDataStore
local MS=W.service('MarketplaceService');MS.PromptProductPurchaseFinished=R.signal();MS.PromptGamePassPurchaseFinished=R.signal()
W.env.bit32=bit32
do local Inst=R.Inst;local raw=Inst.IsA
 function Inst:IsA(c)if self._class=='SpawnLocation'and(c=='Part'or c=='BasePart'or c=='PVInstance'or c=='FormFactorPart')then return true end;return raw(self,c)end
end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='RemoteFunction'then o.OnServerInvoke=nil end
 if class=='BindableEvent'then o.Event=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local map=Z.loadPlace(require('./place_tree'),W.workspace)
local steps,failed={},0
local function step(name,fn,...)
 local ok,err=pcall(fn,...)
 if ok then steps[#steps+1]=name else failed+=1;print('STEP '..name..' FAILED '..tostring(err))end
 return ok
end
-- ServerStorage stand-ins for the backups the V134 / V136 passes check (they are installed in the place, so those passes are no-ops).
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
-- MapService.new: the real constructor (map passes in its order, MarketLayout, WalkthroughProps90, the tier-1 treadmills, bindings).
local Config;step('Config',function()Config=server('Config')end)
local art;step('BiomeVisuals',function()art=server('BiomeVisuals')end)
local mapService
local okMap=step('MapService.new',function()mapService=server('MapService').new(Config);R.advance(.1)end)
if not okMap then -- the same passes one by one, so a mock gap in the constructor still leaves the map
 if folder:FindFirstChild('ZFightFix149')then step('ZFightFix149',function()server('ZFightFix149').Apply(map)end)end
 step('ApplyVolcanoV129',function()art.ApplyVolcanoV129(map)end)
 step('ApplyRoutesV134',function()art.ApplyRoutesV134(map)end)
 step('ApplyRoutePolishV136',function()art.ApplyRoutePolishV136(map)end)
 step('GardenBaseLayout',function()server('GardenBaseLayout').Apply(map)end)
 step('TrackExpansion83',function()server('TrackExpansion83').Apply(map)end)
 step('ForestLayout87',function()server('ForestLayout87').Apply(map)end)
 step('RouteDress84',function()server('RouteDress84').Apply(map)end)
 step('HideBushes124',function()server('HideBushes124').Apply(map)end)
 step('MarketLayout',function()server('MarketLayout').Apply(map);R.advance(.1)end)
 step('WalkthroughProps90',function()W.module('WalkthroughProps90').Bind(map)end)
end
-- The treadmill of every base (MapService._bindBases builds tier 1; an owner's skin rebuilds it: one skin per base here).
local skins=SKINS or{1,2,3,4,5,6}
local records={}
for _,base in ipairs(map.Bases:GetChildren())do if base:GetAttribute('BaseIndex')then
 local i=base:GetAttribute('BaseIndex');records[#records+1]={Index=i,Model=base,Pad=base:FindFirstChild('Pad')}
 step('Treadmill '..base.Name,function()art.BuildTreadmillV131(base,skins[i]or 1)end)
end end
table.sort(records,function(a,b)return a.Index<b.Index end)
step('GardenTypography',function()W.module('GardenTypography').Apply(map)end)
-- Garden fence art for every tier on the bases (GardenUpgradeService rebuilds it per owner tier) and the upgrade buttons.
step('GardenFenceArt',function()local A=server('GardenFenceArt');for _,r in ipairs(records)do A.Build(r.Model,FENCES and FENCES[r.Index]or((r.Index-1)%7)+1)end end)
-- The mystery pack pedestal on every base.
step('MysteryPedestal',function()
 local S=server('MysteryPackService');local svc=S.new(Config,{},{Map=nil},{},{},{MapRoot=map})
 for _,r in ipairs(records)do svc:_build(r)end
end)
-- Verity's dais south of the market.
step('VerityDais',function()
 local S=server('VerityService');local svc=S.new(Config,{},{},{},{MapRoot=map,EconomyHub=map.EconomyHub})
 svc:_build(map.EconomyHub)
end)
-- SpeedBoardService:Render dresses both hub leaderboards (LeaderboardLandscape.Apply replaces the saved decor).
step('Leaderboards',function()
 local L=W.module('LeaderboardLandscape')
 for _,m in ipairs(map.EconomyHub.GeneratedHubScenery:GetChildren())do if m:GetAttribute('SceneryOwner')=='ChestChase'then L.Apply(m)end end
end)
-- A shovel hole on the track (TrackHoleService._build) at RUNNER_Z ahead of the runner: the keyboard lifts it onto the keys.
local RUNNER=RUNNER or{0,-60}
step('TrackHole',function()
 local S=server('TrackHoleService');local holes=R.new('Folder');holes.Name='TrackHoles';holes.Parent=map
 local svc=setmetatable({Folder=holes,Random=W.env.Random.new(7)},{__index=S})
 local ground=4
 svc:_build({Id=1,Position=V3(RUNNER[1]+12,ground,RUNNER[2]+20),Owner={UserId=1}})
end)
R.advance(1)
-- Client builders --------------------------------------------------------------------------------------------------------------------------
-- The local player stands on the track at RUNNER (x, z): the keyboard draws its keys and blocks around him, SnowBiome149 its patches.
if not SKIP_CLIENT then
 Run.IsClient=function()return true end;Run.IsServer=function()return false end
 local player=R.new('Player');player.Name='Tester';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
 function Players.GetPlayers()return{player}end
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
 function R.Inst.Play()end;function R.Inst.Stop()end
 W.service('ContentProvider').PreloadAsync=function()end
 W.stub('ClientFxBudget',{Get=function()return 3 end,Low=function()return false end})
 if not RS:FindFirstChild('R142Keycap')then -- the place's keycap mesh (ReplicatedStorage.R142Keycap): a stand-in of the same size
  local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55)
  local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
  local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=RS
 end
 local model=R.new('Model');model.Name='Tester'
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Transparency=1;root.Parent=model
 local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.Parent=model;model.PrimaryPart=root;model.Parent=W.workspace;player.Character=model
 root.CFrame=CF(RUNNER[1],7,RUNNER[2])
 step('KeyboardTrack.client',function()local sc=R.new('LocalScript');sc.Name='KeyboardTrack';W.load('KeyboardTrackClient',sc);W.frames(90)end)
 step('SnowBiome149.client',function()local sc=R.new('LocalScript');sc.Name='SnowBiome149';W.load('SnowBiome',sc);W.frames(60)end)
end
-- Where a camera can be: the lobby floor and the track between its outer walls (a face whose front lies outside is never seen).
local playable={}
do local f=map.Lobby.LobbyFloor;local c,s=f.CFrame.Position,f.Size
 playable[#playable+1]=string.format('[%.3f,%.3f,%.3f,%.3f]',c.X-s.X/2,c.Z-s.Z/2,c.X+s.X/2,c.Z+s.Z/2)
 playable[#playable+1]=string.format('[%.3f,%.3f,%.3f,%.3f]',-94,-110,94,(map:GetAttribute('BiomeTrackEndZ')or 5980)+10)
end
local function areaOf(p)
 local path=Z.path(p)
 if path:find('KeyboardTrackVisuals',1,true)then return'keyboard'end
 if path:find('TrackHole',1,true)then return'holes'end
 if path:find('Snow',1,true)and not path:find('ChestChaseMap',1,true)then return'snow'end
 if path:find('EconomyHub/MerchantStands',1,true)or path:find('EconomyHub/FruitOfTheHour',1,true)then return'shop'end
 if path:find('EconomyHub/'..'VerityNPC',1,true)then return'verity'end
 if path:find('/EconomyHub/',1,true)then return'hub'end
 if path:find('/Bases/',1,true)then
  if path:find('MysteryPedestal',1,true)then return'pedestal'end
  if path:find('Treadmill',1,true)then return'treadmill'end
  if path:find('GardenFence34',1,true)or path:find('GardenUpgradeButtons',1,true)then return'fence'end
  return'bases'
 end
 if path:find('/Lobby/',1,true)or path:find('ChestChaseWalls',1,true)or path:find('GardenHubDesign',1,true)then return'lobby'end
 return'track'
end
for _,s in ipairs(steps)do print('STEP '..s..' ok')end
local parts=Z.dump(W.workspace,areaOf)
print('SCENE {"playable":['..table.concat(playable,',')..'],"parts":['..table.concat(parts,',')..']}')
print(string.format('ZSCENE %d parts, %d steps ok, %d failed',#parts,#steps,failed))
