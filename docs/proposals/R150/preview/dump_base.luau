--!nocheck
-- R150 preview dump (not a test): the owner's REAL base on the Roblox mock - the place file's map (place_tree.luau, written by tools/rbxl_geom.py --tree) with
-- the real start-up builders (MapService, the treadmill, the garden fence) - and the mystery pedestal in the corner across from the treadmill, Locked and
-- Ready, as the base's owner sees it from the entrance (the client's fx and sign included). Whatever src tree this folder was bundled from (R149 = BEFORE,
-- this checkout = AFTER). Prints "SCENE <name> <json>" for render_pedestal.mjs; only parts within 110 studs of the pedestal are written.
local H=require('./pedestal_harness');local D=require('./preview_dump');local Z=H.Z;local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players')
local Http=W.service('HttpService');local guid=0;function Http.GenerateGUID()guid+=1;return'guid-'..guid end;function Http.JSONEncode(_,t)return'{}'end;function Http.JSONDecode()return{}end
local DS=W.service('DataStoreService');function DS.GetDataStore()return{GetAsync=function()return nil end,SetAsync=function()end,UpdateAsync=function()return nil end}end;DS.GetOrderedDataStore=DS.GetDataStore
local MS=W.service('MarketplaceService');MS.PromptProductPurchaseFinished=R.signal();MS.PromptGamePassPurchaseFinished=R.signal()
do local raw=R.Inst.IsA
 function R.Inst:IsA(c)if self._class=='SpawnLocation'and(c=='Part'or c=='BasePart'or c=='PVInstance'or c=='FormFactorPart')then return true end;return raw(self,c)end
end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='BindableEvent'then o.Event=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local map=Z.loadPlace(require('./place_tree'),W.workspace)
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local Config=H.server('Config');local art=H.server('BiomeVisuals')
local okMap,errMap=pcall(function()H.server('MapService').new(Config);R.advance(.1)end)
if not okMap then io.stderr:write('MapService.new: '..tostring(errMap)..'\n')end
-- Base 1's record, its Forest treadmill (tier 1: the pedestal wears the same biome) and its pedestal.
local base,pad
for _,b in ipairs(map.Bases:GetChildren())do if b:GetAttribute('BaseIndex')==1 then base=b;pad=b:FindFirstChild('Pad')end end
assert(base and pad,'Base 1 not found in the place')
pcall(function()art.BuildTreadmillV131(base,1)end)
pcall(function()H.server('GardenFenceArt').Build(base,1)end)
local rec={Index=1,Model=base,Pad=pad};H.records[#H.records+1]=rec
H.service():_build(rec)
local function wp(x,y,z)return pad.CFrame*V3(x,pad.Size.Y/2+y,z)end -- pad space (x, height over the pad, z) -> world
local FOCUS=wp(34,0,75)
local function keep(c)return(c.Position-FOCUS).Magnitude<110 end
-- The client side: the base's owner stands at the entrance and looks across at the pedestal.
Run.IsServer=function()return false end;Run.IsClient=function()return true end
R.clock=20000*86400+3600+11
local me=H.player(77,'Tester',true);local _,root=H.character(me,wp(8,3.5,50))
local cam=wp(2,30,30);local at=wp(0,8,80) -- (inside the garden, looking across it at the entrance corner: the pedestal is on the left, the treadmill across the aisle on the right, the bonus board behind the pedestal)
H.look(cam,at)
H.publish(rec,'Empty');H.loadClient();H.run(.6)
local function faceAt(theta)local period=2*math.pi/.8;local dt=((theta/.8)-R.clock)%period;R.advance(dt);H.run(1/30)end
local function scene(name,view)print('SCENE '..name..' '..D.scene(W,{base,W.workspace:FindFirstChild('MysteryPackFlights')or R.new('Folder')},view,{MysteryBurst=true,MysteryFlash=true,MysteryPop=true},keep))end
local function wide()
 local o={cam=D.v3(cam),at=D.v3(at)}
 return string.format('{"cam":%s,"at":%s,"fov":62,"w":900,"h":520,"opts":{"groundY":3.9}}',o.cam,o.at)
end
H.publish(rec,'Locked',{Owner=77,Stage=1,UnlockIn=12*60+41});H.run(2)
faceAt(2.2);scene('locked',wide())
H.publish(rec,'Ready',{Owner=77,Stage=1,Variant='Pack03'});H.run(2.6)
faceAt(2.2);scene('ready',wide())
