--!nocheck
-- R158 walls: checks of the REAL code on the owner's place (place_tree.luau from docs/proposals/R149/tools/rbxl_geom.py) in the R149 Roblox mock:
--   ServerScriptService.ChestChaseServer.MapService.new (every real start-up pass) -> TrackWalls158 (track wall dressing, outer ground, hub wall caps) + OuterTrackLoader158 (the
--   outer track's models) + LavaVolcano158 (no lava streams / pools, the owner's volcano). Prints "ok <name>" / "FAIL <name>: why" and "INFO ..." lines; errors at the end if anything failed.
--  1. the start-up: the three folders (once each), the parts per biome as the data says, every part's size / CFrame / colour / material, anchored / no collide / no touch / no query,
--     shadows only on parts 20+ studs long, no script and nothing but parts / folders / models / one SpecialMesh under them, nothing Persistent (streams like any part)
--  2. the 15 saved wall parts: only Color / Material changed (size, CFrame, collision as the place saved them), the old look kept in attributes; the R153 blockers still 15, untouched
--  3. the Lava biome: no stream or pool left anywhere (the river, the side pools, the three channels, the molten crater), the old cone stays when no model is there, one plain note
--  4. the outer track with no ids and no mesh service: the keys that have a model (the game's own oaks / jungle trees / ice trees / crystals, the owner's pyramid and dark mountain as
--     data) are placed inside their boxes (|x| >= 100, off the hub), the others skipped with ONE plain note each and nothing built in their place; never a warning
--  5. the refresh: the pieces over the cover's roof vanish while the track refreshes and come back
--  6. idempotent: Apply again (map passes re-run, a refresh) never duplicates a part; Remove puts the walls back; a rebuild is byte-identical (fixed seeds)
--  7. the loader on fake models: hand-placed (scripts / sounds stripped, decals kept), by id, an id that errors / is not authorized / hangs, the keys without a model, scaling to the box,
--     a spot that would reach the track refused, variations different per spot and the same on a rerun, the snow hills' trees placed unevenly, the owner's volcano replacing the old cone at its
--     footprint (walk-through, vent moved, streams gone), both mesh forms failing -> the old cone kept
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
 if class=='BindableEvent'then o.Event=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
-- what the modules print / warn (the notes are checked)
local printed,warned={},{}
W.env.print=function(...)local t={};for i=1,select('#',...)do t[#t+1]=tostring((select(i,...)))end;printed[#printed+1]=table.concat(t,' ')end
local baseWarn=W.env.warn
W.env.warn=function(...)local t={};for i=1,select('#',...)do t[#t+1]=tostring((select(i,...)))end;warned[#warned+1]=table.concat(t,' ');baseWarn(...)end
-- task.wait moves the mock clock on (a hung load is given up after its time)
W.env.task=setmetatable({wait=function(t)R.advance(t or .03);return t or .03 end},{__index=R.task})
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local map=Z.loadPlace(require('./place_tree'),W.workspace)
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local passed,failed=0,0
local function check(name,cond,why)
 if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end
end
local function info(s)print('INFO '..s)end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-4)end
local function fmt(v)return string.format('%.4f',v)end
local function aabb(p)
 local c=p._props.CFrame;local s=p._props.Size;local r=c.R;local q=c.Position
 local e={(math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2}
 return{q.X-e[1],q.Y-e[2],q.Z-e[3]},{q.X+e[1],q.Y+e[2],q.Z+e[3]}
end
local function partsOf(root)local out={};if root:IsA('BasePart')then out[1]=root end;for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then out[#out+1]=d end end;return out end
local function countClass(root,class)local n=0;for _,d in ipairs(root:GetDescendants())do if d._class==class then n+=1 end end;return n end
local function enumName(e)return e and e.Name or'?'end
-- one string per part (order of the tree): the whole look of a subtree
local function inModels(p)local a=p._parent;while a do if a.Name=='Models'then return true end;a=a._parent end;return false end
local function fingerprint(root,skipModels)
 local out={}
 for _,p in ipairs(partsOf(root))do
  if skipModels and inModels(p)then continue end
  local pr=p._props;local c=pr.CFrame;local r=c.R;local s=pr.Size;local col=pr.Color
  out[#out+1]=table.concat({p.Name,p._class,fmt(s.X),fmt(s.Y),fmt(s.Z),fmt(c.Position.X),fmt(c.Position.Y),fmt(c.Position.Z),fmt(r[1][1]),fmt(r[1][2]),fmt(r[1][3]),fmt(r[2][1]),fmt(r[2][2]),fmt(r[2][3]),fmt(r[3][1]),fmt(r[3][2]),fmt(r[3][3]),
   fmt(col.R),fmt(col.G),fmt(col.B),enumName(pr.Material),tostring(pr.Transparency),tostring(pr.Anchored),tostring(pr.CanCollide),tostring(pr.CanTouch),tostring(pr.CanQuery),tostring(pr.CastShadow)},'|')
 end
 return table.concat(out,'\n')
end

-- the real start-up on the owner's place -------------------------------------------------------------------------------------------------------------
local Config=server('Config')
-- the saved wall parts as the place has them (before any pass)
local savedWalls={}
for _,p in ipairs(map.Obby.BiomeWalls:GetChildren())do savedWalls[p.Name]={Color=p._props.Color,Material=enumName(p._props.Material),Size=p._props.Size,CFrame=p._props.CFrame,CanCollide=p._props.CanCollide,Place=p._place}end
local t0=os.clock()
local mapService=server('MapService').new(Config);R.advance(.1);R.advance(1)
local Specs=server('TrackWallSpecs158');local TW=server('TrackWalls158');local Assets=server('OuterTrackAssets158');local Models=server('OuterTrackModels158')
local Loader=server('OuterTrackLoader158');local LV=server('LavaVolcano158')
local startup=printed

-- 1. the start-up -----------------------------------------------------------------------------------------------------------------------------------
local function child(root,name)local n=0;local found;for _,c in ipairs(root:GetChildren())do if c.Name==name then n+=1;found=found or c end end;return found,n end
local wallsRoot,nW=child(map,'TrackWalls158');local backRoot,nB=child(map,'TrackBackdrops158');local baseRoot,nC=child(map,'BaseWalls158')
check('built: MapService.new made TrackWalls158, TrackBackdrops158 and BaseWalls158, each once',wallsRoot and backRoot and baseRoot and nW==1 and nB==1 and nC==1,nW..','..nB..','..nC)
check('built: they are plain Folders (parts stream in and out one by one under StreamingEnabled; nothing Persistent or Atomic)',wallsRoot._class=='Folder'and backRoot._class=='Folder'and baseRoot._class=='Folder')
local walls=Specs.TrackWalls();local ground=Specs.Backdrops();local base=Specs.BaseWalls('A')
local want={}
for _,s in ipairs(walls)do local g=s.Group:match('^TrackWalls158/(.+)$');want[g]=(want[g]or 0)+1 end
local gotBy={}
for _,f in ipairs(wallsRoot:GetChildren())do gotBy[f.Name]=#partsOf(f)end
local mismatch
for g,n in pairs(want)do if gotBy[g]~=n then mismatch=(mismatch or'')..g..' '..tostring(gotBy[g])..'/'..n..'; 'end end
for g in pairs(gotBy)do if not want[g]then mismatch=(mismatch or'')..'extra '..g..'; 'end end
check('built: every biome folder holds exactly the parts the data lists ('..#walls..' in all, 7 biomes + 6 border towers)',mismatch==nil and #partsOf(wallsRoot)==#walls,mismatch or(#partsOf(wallsRoot)..' vs '..#walls))
local order=table.concat((function()local t={};for _,b in ipairs(Specs.Biomes)do t[#t+1]=b.Name..'='..(gotBy[b.Name]or 0)end;return t end)(),', ')
info('track wall parts per biome: '..order..'; borders '..(function()local n=0;for k,v in pairs(gotBy)do if k:find('^Border')then n+=v end end;return n end)())
local groundParts={}
for _,f in ipairs(backRoot:GetChildren())do for _,c in ipairs(f:GetChildren())do if c:IsA('BasePart')then groundParts[#groundParts+1]=c end end end
check('built: the outer ground is '..#ground..' slabs (2 per biome + the one behind the end wall) and the base caps '..#base..' parts',#groundParts==#ground and #partsOf(baseRoot)==#base,#groundParts..'/'..#partsOf(baseRoot))
-- every part's look against its spec
local function matches(p,s)
 local pr=p._props;local c=pr.CFrame;local r=c.R
 if not(near(pr.Size.X,s.Size[1])and near(pr.Size.Y,s.Size[2])and near(pr.Size.Z,s.Size[3]))then return false end
 if not(near(c.Position.X,s.CF[1])and near(c.Position.Y,s.CF[2])and near(c.Position.Z,s.CF[3]))then return false end
 for i=1,3 do for j=1,3 do if not near(r[i][j],s.CF[3+(i-1)*3+j])then return false end end end
 if not(near(pr.Color.R*255,s.Color[1],.51)and near(pr.Color.G*255,s.Color[2],.51)and near(pr.Color.B*255,s.Color[3],.51))then return false end
 return enumName(pr.Material)==s.Material and(s.Mesh=='Sphere')==(p:FindFirstChildOfClass('SpecialMesh')~=nil)
end
local byGroup={}
for _,s in ipairs(walls)do local g=s.Group:match('^TrackWalls158/(.+)$');byGroup[g]=byGroup[g]or{};table.insert(byGroup[g],s)end
local badLook,checked
for g,list in pairs(byGroup)do
 local f=wallsRoot:FindFirstChild(g);local ps=f and f:GetChildren()or{}
 for i,s in ipairs(list)do checked=(checked or 0)+1;if not(ps[i]and matches(ps[i],s))then badLook=badLook or(g..' #'..i..' '..s.Name)end end
end
check('built: every wall part has the size, CFrame, colour, material and egg mesh of its spec ('..tostring(checked)..' parts)',badLook==nil,badLook)
local baseParts=partsOf(baseRoot);local badBase
for i,s in ipairs(base)do if not matches(baseParts[i],s)then badBase=badBase or(i..' '..s.Name)end end
check('built: every base cap and coping strip matches its spec',badBase==nil,badBase)
-- flags
local function flagsOf(list,bigShadowOnly,noShadow)
 local bad
 for _,p in ipairs(list)do
  local pr=p._props;local s=pr.Size;local big=math.max(s.X,s.Y,s.Z)>=20
  if not(pr.Anchored==true and pr.CanCollide==false and pr.CanTouch==false and pr.CanQuery==false)then bad=bad or(p.Name..': anchored/collide/touch/query')end
  if noShadow and pr.CastShadow~=false then bad=bad or(p.Name..' casts a shadow')end
  if bigShadowOnly and pr.CastShadow~=false and not big then bad=bad or(p.Name..' ('..string.format('%.1f',math.max(s.X,s.Y,s.Z))..' studs) casts a shadow')end
 end
 return bad
end
local wallList,baseList=partsOf(wallsRoot),partsOf(baseRoot)
check('built: every track wall part is Anchored, CanCollide off, CanTouch off, CanQuery off ('..#wallList..' parts)',flagsOf(wallList,false,false)==nil,flagsOf(wallList,false,false))
check('built: only parts 20+ studs long cast a shadow (walls)',flagsOf(wallList,true,false)==nil,flagsOf(wallList,true,false))
check('built: the ground and the base caps: no collision, no touch, no query; the ground casts no shadow, a cap none either (they are under 20 studs)',flagsOf(groundParts,true,true)==nil and flagsOf(baseList,true,false)==nil,flagsOf(groundParts,true,true)or flagsOf(baseList,true,false))
local nonGeom
for _,root in ipairs({wallsRoot,backRoot,baseRoot})do for _,d in ipairs(root:GetDescendants())do
 local c=d._class
 if not(d:IsA('BasePart')or c=='Folder'or c=='Model'or c=='SpecialMesh'or c=='Decal'or c=='Texture')then nonGeom=nonGeom or(d:GetFullName()..' is a '..c)end
end end
check('built: nothing under them but parts, folders, models, meshes and decals (no script, no sound, no light, no joint)',nonGeom==nil,nonGeom)
local persistent,notAtomic,nBackdrops
nBackdrops=0
for _,root in ipairs({wallsRoot,backRoot,baseRoot})do for _,d in ipairs(root:GetDescendants())do
 if d._class=='Model'then
  local mode=d._props.ModelStreamingMode
  local backdrop=d._parent~=nil and d._parent.Name=='Models'
  if mode==R.Enum.ModelStreamingMode.Persistent or(mode==R.Enum.ModelStreamingMode.Atomic and not backdrop)then persistent=d.Name end
  if backdrop then nBackdrops+=1;if mode~=R.Enum.ModelStreamingMode.Atomic then notAtomic=notAtomic or d.Name end end
 end
end end
check('built: no Persistent model and no Atomic wall / ground / cap part (nothing on a client waits for them: they stream in and out one by one)',persistent==nil,persistent)
check('built: every placed backdrop Model is Atomic (a tree or a mountain streams in whole, never half-built at the streaming edge; '..nBackdrops..' models)',nBackdrops>20 and notAtomic==nil,notAtomic or nBackdrops)
check('built: the folders carry their version and part counts',wallsRoot:GetAttribute('Version')==158 and wallsRoot:GetAttribute('Parts')==#walls and baseRoot:GetAttribute('Parts')==#base and backRoot:GetAttribute('Version')==158)
-- the keep-clear rules on what was BUILT (the data checks do the same on the data)
local keysBad,gateBad,walkBad,pyrBad,reachBad
for _,p in ipairs(wallList)do
 local lo,hi=aabb(p);local endWall=lo[3]>5975
 local ax0,ax1=math.min(math.abs(lo[1]),math.abs(hi[1])),math.max(math.abs(lo[1]),math.abs(hi[1]))
 if not endWall and lo[1]*hi[1]>0 and ax0<89.75 and lo[2]<5.25 then keysBad=keysBad or p.Name end
 if lo[3]<-95.5 and hi[2]>44 then gateBad=gateBad or p.Name end
 if hi[1]<0 and hi[3]>972 and lo[3]<1038 and ax0<88.3 and lo[2]<30 then walkBad=walkBad or p.Name end
 if hi[1]<0 and lo[1]>-88 and hi[3]>982.6 and lo[3]<1027.4 then pyrBad=pyrBad or p.Name end
 local reach=lo[2]<12 and 3.2 or lo[2]<45 and 4.5 or 6
 if not endWall and ax0<89-reach-1e-6 and not(lo[2]>50.9 and(p.Name=='Crystal'or p.Name=='Wall crystal'))then reachBad=reachBad or p.Name end
 if not endWall and ax1>95+1e-6 then reachBad=reachBad or(p.Name..' outer')end
end
check('built: nothing under Y 5.25 inside the keyboard keys\' reach, nothing in the gatehouse, nothing but flat bands on the Desert walkway, nothing in the R157 pyramid\'s footprint',keysBad==nil and gateBad==nil and walkBad==nil and pyrBad==nil,tostring(keysBad or gateBad or walkBad or pyrBad))
check('built: no piece stands further into the track than 3.2 (low) / 4.5 (over heads) / 6 (wall top) studs or past the outer face by more than 1',reachBad==nil,reachBad)

-- 2. the saved wall parts ---------------------------------------------------------------------------------------------------------------------------
local restyle=Specs.Restyle();local nRe=0;local badWall
for path,look in pairs(restyle)do
 local w=map.Obby.BiomeWalls:FindFirstChild(path:match('[^/]+$'))
 if not w then badWall='missing '..path else
  nRe+=1;local pr=w._props;local sv=savedWalls[w.Name]
  if not(near(pr.Color.R*255,look.Color[1],.51)and near(pr.Color.G*255,look.Color[2],.51)and enumName(pr.Material)==look.Material)then badWall=badWall or(w.Name..': not restyled')end
  if pr.CanCollide~=sv.CanCollide then badWall=badWall or(w.Name..': collision changed')end
  if w:GetAttribute('R158OldMaterial')==nil then badWall=badWall or(w.Name..': the old look is not kept')end
 end
end
check('built: the 15 saved wall parts took their biome\'s colour and material (collision as the place saved it; size and place are checked against a build without R158 by check_untouched158.py)',nRe==15 and badWall==nil,badWall or nRe)
local blockers=map:FindFirstChild('TrackWallBlockers153')
check('built: the R153 wall blockers are still there, 15, Persistent, colliding',blockers~=nil and #blockers:GetChildren()==15 and blockers._props.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent)

-- 3. the Lava biome ---------------------------------------------------------------------------------------------------------------------------------
local function findStreams(root)
 local out={}
 for _,d in ipairs(root:GetDescendants())do
  local n=d.Name
  if(d:IsA('BasePart')or d._class=='Model'or d._class=='Folder')and(n:find('^VolcanoMagmaChannel')or n=='MoltenCrater'or n=='ContinuousLavaRiver'or n=='IrregularMagmaPools'or n=='MainMagmaPool'or n:find('^LavaPool')or n=='Lava pool'or n:find('^LavaRiver')or n=='Pool shore')then out[#out+1]=d:GetFullName()end
 end
 return out
end
local leftover=findStreams(map)
check('lava: no stream, pool, river, channel or molten crater is left anywhere on the map',#leftover==0,leftover[1])
local magmaParts=0
for _,p in ipairs(partsOf(map))do if p.Name=='MagmaSurface'or p.Name=='MovingMoltenCurrent'or p.Name=='ContinuousBasaltBank'or p.Name=='BasaltChannelBank'then magmaParts+=1 end end
check('lava: no magma surface, current or channel bank part is left ('..magmaParts..')',magmaParts==0)
do -- owner: the Lava track walls' Neon "Lava drip" pieces are gone for good (the rest of the Lava wall is built)
 local lavaWall=wallsRoot:FindFirstChild('Lava')
 local drips,nBuilt,foot=0,0,0
 if lavaWall then for _,p in ipairs(partsOf(lavaWall))do nBuilt+=1;if p.Name:lower():find('drip',1,true)then drips+=1 end;if p.Name=='Basalt foot'then foot+=1 end end end
 check('lava wall: no part of the Lava track walls is a drip (built: '..nBuilt..' parts, 0 drips), the foot, the glow seams and the crest are there',lavaWall~=nil and drips==0 and nBuilt==gotBy.Lava and foot>0,drips..' drips of '..nBuilt)
end
do -- owner: "remove those leaf balls, don't have plain balls or anything that might reduce the look of the walls": nothing round on any wall
 local round,nChecked={},0
 local function words(n)n=n:lower();for _,w in ipairs({'ball','blob','leaf','leaves','crown','tuft','overgrowth','rubble','pillow','mound','drip','egg','sphere'})do if n:find(w,1,true)then return true end end;return false end
 for _,root in ipairs({wallsRoot,baseRoot})do for _,d in ipairs(root:GetDescendants())do
  nChecked+=1
  local isBall=d:IsA('BasePart')and d._props.Shape~=nil and enumName(d._props.Shape)=='Ball'
  if isBall or d._class=='SpecialMesh'or words(d.Name)then round[#round+1]=d:GetFullName()end
 end end
 for _,g in ipairs(groundParts)do if enumName(g._props.Shape)=='Ball'or words(g.Name)then round[#round+1]=g:GetFullName()end end
 check('walls: no Ball, no sphere mesh and nothing named like a ball / blob / leaf / crown / drip on any track wall, base wall or the ground ('..nChecked..' instances looked at)',#round==0 and nChecked>1000,round[1])
end
local landmark=map.MythicLandmarks:FindFirstChild('Biome4_Landmark')
check('lava: with no volcano model to load the old cone stays (its slopes and crater lip), without its channels and crater',landmark~=nil and landmark:GetAttribute('Volcano158')==nil and landmark:FindFirstChild('BasaltSlope')~=nil and landmark:FindFirstChild('MoltenCrater')==nil)
local sawNote
for _,l in ipairs(startup)do if l:find('^%[R158 volcano%] removed %d+ lava stream / pool parts')and l:find('the old cone stays',1,true)then sawNote=l end end
check('lava: ONE plain note says what was removed and that the old cone stays',sawNote~=nil and not sawNote:find('WARN'),sawNote)
info(sawNote or'(no volcano note)')

-- 4. the outer track with nothing to load -------------------------------------------------------------------------------------------------------------
local status=Loader.Status
local function placed(key)return status[key]and status[key].Placed or 0 end
local nForest,nJungle=#Assets.SlotsOf('ForestTree'),#Assets.SlotsOf('JungleTree')
check('outer: the keys with a model got their spots: ForestTree '..nForest..', JungleTree '..nJungle..', DesertPyramid 1, SnowTree 8, CrystalSpire 6, StormDarkMount 4',placed('ForestTree')==nForest and placed('JungleTree')==nJungle and placed('DesertPyramid')==1 and placed('SnowTree')==8 and placed('CrystalSpire')==6 and placed('StormDarkMount')==4,
 'forest '..placed('ForestTree')..' jungle '..placed('JungleTree')..' pyramid '..placed('DesertPyramid')..' snow '..placed('SnowTree')..' crystal '..placed('CrystalSpire')..' storm '..placed('StormDarkMount'))
local waiting={'DesertDune','DesertObelisk','CrystalMountain','StormTower','StormLightning','StormEndPeak'}
local okWait=true
for _,k in ipairs(waiting)do if placed(k)~=0 then okWait=false end end
check('outer: the keys with no model (DesertDune, DesertObelisk, CrystalMountain, StormTower, StormLightning, StormEndPeak) place nothing',okWait)
check('outer: the owner\'s two mesh models (SnowMountains, LavaVolcano) place nothing when no mesh can be loaded',placed('SnowMountains')==0 and placed('LavaVolcano')==0)
local counts={}
for _,l in ipairs(startup)do
 local key=l:match('^%[R158 outer track%] (%w+):')
 if key then counts[key]=(counts[key]or 0)+1 end
end
local notes=true
for _,k in ipairs(waiting)do if counts[k]~=1 then notes=false end end
for _,def in ipairs(Assets.Keys)do if counts[def.Key]~=1 then notes=false end end
check('outer: exactly one plain note per key (placed, or no model yet), in the Output',notes)
local warnedOurs
for _,w in ipairs(warned)do if w:find('R158',1,true)then warnedOurs=w end end
check('outer: not one warning from the R158 build (a missing model is a plain note)',warnedOurs==nil,warnedOurs)
local modelParts=0
local badOuter
for _,f in ipairs(backRoot:GetChildren())do
 local models=f:FindFirstChild('Models')
 if models then for _,p in ipairs(partsOf(models))do
  modelParts+=1
  local lo,hi=aabb(p)
  if lo[3]<-99.01 then badOuter=badOuter or(p:GetFullName()..': over the hub')end
  if not(lo[3]>5990)and math.min(math.abs(lo[1]),math.abs(hi[1]))<99.99 and lo[1]*hi[1]<=0 or(not(lo[3]>5990)and lo[1]*hi[1]>0 and math.min(math.abs(lo[1]),math.abs(hi[1]))<99.99)then badOuter=badOuter or(p:GetFullName()..': inside |x| 100')end
 end end
end
check('outer: every model part lies at |x| >= 100 (or behind the end wall) and off the hub ('..modelParts..' parts)',badOuter==nil,badOuter)
local bigModels={}
for _,f in ipairs(backRoot:GetChildren())do local models=f:FindFirstChild('Models');if models then for _,p in ipairs(partsOf(models))do bigModels[#bigModels+1]=p end end end
check('outer: every model part is anchored, no collision / touch / query, no shadow',flagsOf(bigModels,true,true)==nil,flagsOf(bigModels,true,true))
local scripts=0
for _,root in ipairs({wallsRoot,backRoot,baseRoot})do scripts+=countClass(root,'Script')+countClass(root,'LocalScript')+countClass(root,'ModuleScript')+countClass(root,'Sound')+countClass(root,'PointLight')+countClass(root,'Weld')end
check('outer: no script, sound, light or joint under any new folder',scripts==0,scripts)
-- 4b. the Forest and Jungle trees as built (owner: "forest and jungle can just have large trees on the outside with our current game assets")
do
 local function modelsIn(biome)local f=backRoot:FindFirstChild(biome);local m=f and f:FindFirstChild('Models');return m and m:GetChildren()or{}end
 local function bbox(m)local lo,hi;for _,p in ipairs(partsOf(m))do local a,b=aabb(p);if not lo then lo,hi={a[1],a[2],a[3]},{b[1],b[2],b[3]}else for i=1,3 do lo[i]=math.min(lo[i],a[i]);hi[i]=math.max(hi[i],b[i])end end end;return lo,hi end
 local totalTreeParts=0
 for _,def in ipairs({{'ForestTree','Forest'},{'JungleTree','Jungle'}})do
  local key,biome=def[1],def[2]
  local tpl=Loader.Template(map,key)
  local protos=tpl and tpl.Protos or{}
  for i,p in ipairs(protos)do info(string.format('tree look %s %d: %-18s %2d parts, size %.2f x %.2f x %.2f',key,i,tostring(p.Label),p.Parts,p.Size.X,p.Size.Y,p.Size.Z))end
  local slots=Assets.SlotsOf(key)
  local list={};for _,m in ipairs(modelsIn(biome))do if m:GetAttribute('Key')==key then list[#list+1]=m end end
  local parts,labels,nLabels,bad=0,{},0,nil
  for _,m in ipairs(list)do
   local slot=slots[m:GetAttribute('Spot')]
   parts+=#partsOf(m)
   local lo,hi=bbox(m);local label=m:GetAttribute('Model')
   if not labels[label or'?']then labels[label or'?']=true;nLabels+=1 end
   local want=protos[1+(((slot.Look or 1)-1)%#protos)]
   local sink=Assets.Ground-lo[2]
   if not(want and want.Label==label)then bad=bad or(m.Name..': is '..tostring(label)..', the spot\'s Look '..tostring(slot.Look)..' wants '..tostring(want and want.Label))end
   if not(near(hi[2]-lo[2],slot.H,slot.H*.012))then bad=bad or(m.Name..': '..string.format('%.1f',hi[2]-lo[2])..' tall, the spot says '..slot.H)end
   if not(sink>=.2 and sink<=.5)then bad=bad or(m.Name..': stands '..string.format('%.2f',sink)..' under the ground (floating or sunk)')end
   local box=Assets.Box(slot)
   if lo[1]<box[1]-.6 or hi[1]>box[2]+.6 or lo[3]<box[5]-.6 or hi[3]>box[6]+.6 then bad=bad or(m.Name..': outside its spot\'s box')end
   -- (the model is stood on its spot by the centre of its box before the turn; a leaning crown moves the box's centre a little when it turns)
   if not(math.abs((lo[1]+hi[1])/2-slot.X)<=.25*math.max(slot.W,slot.D)and math.abs((lo[3]+hi[3])/2-slot.Z)<=.25*math.max(slot.W,slot.D))then bad=bad or(m.Name..': not on its spot')end
  end
  check('trees: '..biome..': all '..#slots..' spots are placed ('..#list..'), each the model its Look says, as tall as the spot says (within 1.2 %), standing on the ground (not floating, not sunk), inside its box and centred',#list==#slots and bad==nil,bad)
  check('trees: '..biome..': '..nLabels..' different tree models in the built forest (at least 6)',nLabels>=6)
  totalTreeParts+=parts
  local tagged=0
  for _,m in ipairs(list)do for _,d in ipairs(m:GetDescendants())do if d._tags and next(d._tags)~=nil or next(d._attrs or{})~=nil then tagged+=1 end end end
  check('trees: '..biome..': no tag and no attribute on any part of any tree (nothing the map\'s passes marked came along)',tagged==0,tagged)
 end
 info('Forest + Jungle tree parts: '..totalTreeParts..' (the owner\'s limit: under about 900; R158 first build: 204 + 198 = 402)')
 check('trees: Forest + Jungle models together are '..totalTreeParts..' parts (under 900)',totalTreeParts>0 and totalTreeParts<900)
end
info('outer track parts: '..modelParts..' in models + '..#groundParts..' ground slabs; walls '..#wallList..', base caps '..#baseList)
info('start-up built in '..string.format('%.2f',os.clock()-t0)..' s on this machine (mock)')

-- 5. the refresh -------------------------------------------------------------------------------------------------------------------------------------
local high=0;local expect=0
for _,s in ipairs(walls)do if Specs.OverCover(s)then expect+=1 end end
for _,h in ipairs(TW.High)do high+=1 end
check('refresh: the parts over the cover\'s roof are listed ('..high..' of '..#wallList..')',high==expect and high>100,high..'/'..expect)
local function hidden()local n=0;for _,p in ipairs(wallList)do if p._props.Transparency==1 then n+=1 end end;return n end
check('refresh: while the track is open nothing is hidden',hidden()==0)
map:SetAttribute('BiomesRefreshing',true)
check('refresh: when the track closes for its refresh exactly those parts turn invisible (no more, no fewer)',hidden()==high,hidden())
map:SetAttribute('BiomesRefreshing',false)
check('refresh: and they are back when it opens again',hidden()==0)
-- independent of Specs.OverCover: every wall piece over the cover's roof (Y 55) or past its sides (|x| 94, the cover's width), inside |x| 95 and off the hub, is on the hidden list
do
 local inHigh={};for _,h in ipairs(TW.High)do inHigh[h.Part]=true end
 local missing,bySide,expectN=nil,0,0
 for _,p in ipairs(wallList)do
  local lo,hi=aabb(p);local reach=math.max(math.abs(lo[1]),math.abs(hi[1]))
  if(hi[2]>55 or reach>94.0001)and reach<=95.0001 and hi[3]>-99 then
   expectN+=1
   if not inHigh[p]then missing=missing or(p:GetFullName()..' sticks out of the refresh cover and is not hidden while the track refreshes')end
   if hi[2]<=55 then bySide+=1 end
  end
 end
 map:SetAttribute('BiomesRefreshing',true)
 local hiddenNow=hidden()
 map:SetAttribute('BiomesRefreshing',false)
 check('refresh: every wall piece over the cover\'s roof (Y 55) or past its sides (|x| 94) is hidden while the track refreshes ('..expectN..' pieces, '..bySide..' of them at or under Y 55, sticking out of its sides)',missing==nil and hiddenNow==expectN and bySide>=10,missing or(hiddenNow..' hidden, '..expectN..' expected, '..bySide..' by the sides'))
end

-- 6. idempotent --------------------------------------------------------------------------------------------------------------------------------------
local fpW,fpC,fpG=fingerprint(wallsRoot),fingerprint(baseRoot),fingerprint(backRoot,true)
local function wallGeometry()local t={};for _,p in ipairs(map.Obby.BiomeWalls:GetChildren())do local c=p._props.CFrame.Position;local sz=p._props.Size;t[#t+1]=p.Name..fmt(c.X)..fmt(c.Y)..fmt(c.Z)..fmt(sz.X)..fmt(sz.Y)..fmt(sz.Z)..tostring(p._props.CanCollide)end;table.sort(t);return table.concat(t,';')end
local geom0=wallGeometry()
local mapParts=#partsOf(map)
local made=TW.Apply(map,{Outer=false})
check('again: Apply on a built map rebuilds the same ('..tostring(made.Walls)..' wall parts, '..tostring(made.Ground)..' ground, '..tostring(made.Base)..' caps, '..tostring(made.Restyled)..' walls)',made.Walls==#walls and made.Ground==#ground and made.Base==#base and made.Restyled==15)
local w2,n1=child(map,'TrackWalls158');local b2,n2=child(map,'TrackBackdrops158');local c2,n3=child(map,'BaseWalls158')
check('again: still one of each folder (a rebuild never doubles anything)',n1==1 and n2==1 and n3==1)
check('again: the walls, the ground and the caps are byte-identical after a rebuild (fixed seeds, nothing random at run time)',fingerprint(w2)==fpW and fingerprint(c2)==fpC and fingerprint(b2,true)==fpG)
check('again: the saved walls keep their size, place and collision across a rebuild',wallGeometry()==geom0)
TW.Apply(map,{Outer=false})
check('again: a third build gives the same walls again',fingerprint((child(map,'TrackWalls158')))==fpW)
check('again: the saved walls keep their ORIGINAL look in the attributes after rebuilds (not the restyled one)',(function()
 for _,p in ipairs(map.Obby.BiomeWalls:GetChildren())do local sv=savedWalls[p.Name];local oc=p:GetAttribute('R158OldColor');if not(oc and near(oc.R,sv.Color.R,1e-4)and p:GetAttribute('R158OldMaterial')==sv.Material)then return false end end
 return true end)())
Loader.Reset();Loader.Run(map)
local fpAll=fingerprint(map.TrackBackdrops158);local nAll=#partsOf(map.TrackBackdrops158)
Loader.Reset();Loader.Run(map)
check('again: the loader run twice leaves the same ground and models, no part doubled ('..nAll..' parts)',#partsOf(map.TrackBackdrops158)==nAll and fingerprint(map.TrackBackdrops158)==fpAll)
local removed=TW.Remove(map)
local gone=map:FindFirstChild('TrackWalls158')==nil and map:FindFirstChild('TrackBackdrops158')==nil and map:FindFirstChild('BaseWalls158')==nil
local restored=true
for _,p in ipairs(map.Obby.BiomeWalls:GetChildren())do local sv=savedWalls[p.Name];if not(near(p._props.Color.R,sv.Color.R,1e-4)and enumName(p._props.Material)==sv.Material)then restored=false end end
check('again: Remove takes everything it built away and puts the 15 walls back as saved',gone and restored and wallGeometry()==geom0,removed)
TW.Apply(map,{Outer=false})
check('again: Apply after Remove builds the same walls, ground and caps as the first time',fingerprint(map.TrackWalls158)==fpW and fingerprint(map.BaseWalls158)==fpC and fingerprint(map.TrackBackdrops158,true)==fpG)
Loader.Reset();Loader.Run(map)
local mapParts2=#partsOf(map)
check('again: the map has the same number of parts as after the start-up ('..mapParts..')',mapParts2==mapParts,mapParts2)

-- 7. the loader on fake models -------------------------------------------------------------------------------------------------------------------------
local SS=W.service('ServerStorage')
local AS=W.service('AssetService');local IS=W.service('InsertService')
local function block(parent,name,size,pos,color)
 local p=R.new('Part');p.Name=name;p.Size=size;p.CFrame=CF(pos.X,pos.Y,pos.Z);p.Color=color or R.Color3.fromRGB(120,120,120);p.Anchored=false;p.CanCollide=true;p.CanTouch=true;p.CanQuery=true;p.Parent=parent;return p
end
local function fakeModel(name,w,h,d)
 local m=R.new('Model');m.Name=name
 block(m,'Body',V3(w,h*.8,d),V3(0,h*.4,0))
 block(m,'Top',V3(w*.5,h*.2,d*.5),V3(0,h*.9,0))
 local s=R.new('Script');s.Name='Evil';s.Parent=m
 local snd=R.new('Sound');snd.Name='Wind';snd.Parent=m.Body
 local light=R.new('PointLight');light.Parent=m.Top
 local decal=R.new('Decal');decal.Name='Face';decal.Parent=m.Body
 return m
end
local function modelsOf(biome)local f=map.TrackBackdrops158:FindFirstChild(biome);local m=f and f:FindFirstChild('Models');return m and m:GetChildren()or{}end
local function box(m)local lo,hi;for _,p in ipairs(partsOf(m))do local a,b=aabb(p);if not lo then lo,hi={a[1],a[2],a[3]},{b[1],b[2],b[3]}else for i=1,3 do lo[i]=math.min(lo[i],a[i]);hi[i]=math.max(hi[i],b[i])end end end;return lo,hi end
Loader.Reset()
local assetsFolder=R.new('Folder');assetsFolder.Name=Assets.Folder;assetsFolder.Parent=SS
-- a hand-placed model: dunes (5 spots), with a script, a sound, a light and a decal inside
fakeModel('DesertDune',60,40,50).Parent=assetsFolder
printed={}
TW.Apply(map,{Outer=false})
Loader.Run(map)
local dunes=modelsOf('Desert')
local nd=0;for _,m in ipairs(dunes)do if m.Name:find('^DesertDune')then nd+=1 end end
check('hand: a model put in ServerStorage.OuterTrackAssets158 is placed at every spot of its key (DesertDune: 5)',nd==5,nd)
local dune=dunes and (function()for _,m in ipairs(dunes)do if m.Name=='DesertDune 1'then return m end end end)()
local spot=Assets.SlotsOf('DesertDune')[1]
if dune then
 local lo,hi=box(dune)
 check('hand: it is scaled evenly to fit the spot\'s box and stands on the ground (box '..string.format('%.0f x %.0f x %.0f',spot.W,spot.H,spot.D)..')',hi[1]-lo[1]<=spot.W+.01 and hi[2]-lo[2]<=spot.H+.01 and hi[3]-lo[3]<=spot.D+.01 and(near(hi[1]-lo[1],spot.W,.05)or near(hi[2]-lo[2],spot.H,.05)or near(hi[3]-lo[3],spot.D,.05)) and lo[2]>=Assets.Ground-.6 and lo[2]<=Assets.Ground,
  string.format('size %.2f x %.2f x %.2f, bottom %.2f',hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3],lo[2]))
 check('hand: centred on the spot (X, Z)',near((lo[1]+hi[1])/2,spot.X,.5)and near((lo[3]+hi[3])/2,spot.Z,.5),string.format('%.1f,%.1f vs %.1f,%.1f',(lo[1]+hi[1])/2,(lo[3]+hi[3])/2,spot.X,spot.Z))
 check('hand: scripts, sounds and lights are stripped, the decal stays, every part locked (anchored, no collide / touch / query, no shadow)',countClass(dune,'Script')==0 and countClass(dune,'Sound')==0 and countClass(dune,'PointLight')==0 and countClass(dune,'Decal')>=1 and flagsOf(partsOf(dune),true,true)==nil)
end
check('hand: the original in ServerStorage is untouched (its script is still there, its parts not anchored)',assetsFolder.DesertDune:FindFirstChild('Evil')~=nil and assetsFolder.DesertDune.Body._props.Anchored==false)
local desertAfter=0;for _,m in ipairs(modelsOf('Desert'))do if m.Name:find('^DesertObelisk')then desertAfter+=1 end end
check('hand: a key with no model (DesertObelisk) gets nothing, nothing part-built in its place',desertAfter==0)
local noteWait
for _,l in ipairs(printed)do if l:find('DesertObelisk: no model yet',1,true)then noteWait=l end end
check('hand: and says so with one plain note (print, not a warning)',noteWait~=nil)
-- variations: several looks of one key (Key, Key2)
fakeModel('DesertDune2',30,60,30).Parent=assetsFolder
Loader.Reset();Loader.Run(map)
local sizes={}
for _,m in ipairs(modelsOf('Desert'))do if m.Name:find('^DesertDune')then local lo,hi=box(m);sizes[#sizes+1]=string.format('%.0f/%.0f/%.0f',hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3])end end
local distinct={};for _,s in ipairs(sizes)do distinct[s]=true end
local nDistinct=0;for _ in pairs(distinct)do nDistinct+=1 end
check('hand: DesertDune and DesertDune2 are two looks, spread over the five spots (the spots differ in size anyway: '..nDistinct..' different sizes)',#sizes==5 and nDistinct>=2)
-- by id
IS.LoadAsset=nil
local calls={}
AS.LoadAssetAsync=function(self,id)
 calls[#calls+1]=id
 if id==111 then local c=R.new('Model');c.Name='Container';local m=fakeModel('Tower',8,100,8);m.Parent=c;return c end
 if id==222 then error('Asset 222 is not authorized for loading')end
 if id==333 then return nil end
 if id==444 then coroutine.yield();return nil end -- never answers
 error('unknown asset '..tostring(id))
end
local savedIds={StormTower=Assets.Ids.StormTower,StormLightning=Assets.Ids.StormLightning,StormEndPeak=Assets.Ids.StormEndPeak,DesertObelisk=Assets.Ids.DesertObelisk}
Assets.Ids.StormTower=111;Assets.Ids.StormLightning=222;Assets.Ids.StormEndPeak=333;Assets.Ids.DesertObelisk=444
printed={};Loader.Reset()
local t1=R.clock
Loader.Run(map)
local towers=0;for _,m in ipairs(modelsOf('Storm Peaks'))do if m.Name:find('^StormTower')then towers+=1 end end
check('id: an asset id that loads is placed at every spot of its key (StormTower: 2), the container unwrapped',towers==2,towers)
local tw=(function()for _,m in ipairs(modelsOf('Storm Peaks'))do if m.Name=='StormTower 1'then return m end end end)()
check('id: the loaded model is made safe like a hand-placed one',tw and countClass(tw,'Script')==0 and flagsOf(partsOf(tw),true,true)==nil)
local authNote,hangNote,nilNote
for _,l in ipairs(printed)do
 if l:find('StormLightning',1,true)and l:find('not your asset',1,true)then authNote=l end
 if l:find('DesertObelisk',1,true)and l:find('timed out',1,true)then hangNote=l end
 if l:find('StormEndPeak',1,true)and l:find('asset 333',1,true)then nilNote=l end
end
check('id: "not authorized" is ONE plain note that says the asset is not yours, the key is skipped',authNote~=nil,authNote)
check('id: an asset that never answers is given up after '..Assets.LoadSeconds..' s (the mock clock moved '..string.format('%.1f',R.clock-t1)..' s) with a note, the key skipped',hangNote~=nil and R.clock-t1>=Assets.LoadSeconds-.01,hangNote)
check('id: an asset that returns nothing is a note too',nilNote~=nil,nilNote)
local anyWarn
for _,w in ipairs(warned)do if w:find('R158',1,true)then anyWarn=w end end
check('id: none of these failures was a warning',anyWarn==nil,anyWarn)
local stormEnd=0;for _,m in ipairs(modelsOf('Storm Peaks'))do if m.Name:find('^StormEndPeak')then stormEnd+=1 end end
check('id: nothing is placed for the keys whose asset failed',stormEnd==0 and #(function()local t={};for _,m in ipairs(modelsOf('Storm Peaks'))do if m.Name:find('^StormLightning')then t[#t+1]=m end end;for _,m in ipairs(modelsOf('Desert'))do if m.Name:find('^DesertObelisk')then t[#t+1]=m end end;return t end)()==0)
for k,v in pairs(savedIds)do Assets.Ids[k]=v end
-- the box guard
local rogue={Key='ForestTree',X=-60,Z=300,Yaw=0,W=50,H=50,D=50}
check('guard: a spot whose box would reach inside |x| 100 is refused',select(1,Loader.Allowed(rogue))==false)
check('guard: a spot over the hub (z < -99) is refused, a spot behind the end wall may cross x = 0',select(1,Loader.Allowed({X=200,Z=-150,Yaw=0,W=20,H=20,D=20}))==false and select(1,Loader.Allowed({X=0,Z=6500,Yaw=0,W=800,H=300,D=800}))==true)
local rulesBad
for i,s in ipairs(Assets.Slots)do local ok,why=Loader.Allowed(s);if not ok then rulesBad=rulesBad or(i..' '..s.Key..': '..why)end end
check('guard: every spot of OuterTrackAssets158.Slots passes it (|x| >= 100 or behind the end wall, off the hub)',rulesBad==nil,rulesBad)
-- the box, turned: an odd turn of a square spot widens its box
local turned=Assets.Box({X=0,Z=0,Yaw=45,W=100,H=10,D=100})
check('guard: Assets.Box turns the box (a 100 x 100 spot turned 45 degrees is 141 wide)',near(turned[2]-turned[1],141.42,.1))

-- 7b. the snow hills and the volcano with a fake CreateMeshPartAsync ------------------------------------------------------------------------------------
local meshCalls={}
local function fakeMesh(id,size)local mp=R.new('MeshPart');mp.Name='MeshPart';mp.Size=size;mp.CFrame=CF(0,0,0);mp.Anchored=false;mp.CanCollide=true;mp.CanTouch=true;mp.CanQuery=true;mp.MeshId=id;return mp end
local meshSizes={['rbxassetid://5150938211']=V3(60,.7,56),['rbxassetid://5150934668']=V3(77,21,71),['rbxassetid://5153142324']=V3(3.2,12,3.2),['rbxassetid://5153169732']=V3(8.8,17,8.8),['rbxassetid://5138886694']=V3(70,52.6,59.8)}
AS.CreateMeshPartAsync=function(self,content)
 local id=type(content)=='table'and content.Uri or content
 meshCalls[#meshCalls+1]=id
 if meshSizes[id]then return fakeMesh(id,meshSizes[id])end
 error('Unable to load mesh '..tostring(id))
end
Loader.Reset();printed={}
TW.Apply(map,{Outer=false});Loader.Run(map)
local snow=modelsOf('Snow')
local clusters={};for _,m in ipairs(snow)do if m.Name:find('^SnowMountains')then clusters[#clusters+1]=m end end
check('hills: the owner\'s Low Poly Island Hills are placed twice (one cluster each side) when his meshes load ('..#meshCalls..' mesh requests)',#clusters==2,#clusters)
if #clusters==2 then
 local function meshCount(m,id)local n=0;for _,p in ipairs(partsOf(m))do if p._props.MeshId==id then n+=1 end end;return n end
 local a,b=clusters[1],clusters[2]
 check('hills: each cluster has its 16 hills (16 grass caps + 16 stone bodies)',meshCount(a,'rbxassetid://5150938211')==16 and meshCount(a,'rbxassetid://5150934668')==16 and meshCount(b,'rbxassetid://5150938211')==16)
 local ta,tb=a:GetAttribute('Trees'),b:GetAttribute('Trees')
 info('snow hills trees: '..tostring(ta)..' and '..tostring(tb))
 local trunksA,trunksB=meshCount(a,'rbxassetid://5153142324'),meshCount(b,'rbxassetid://5153142324')
 check('hills: the trees are re-placed, not the owner\'s 16: a different number on each side, some dropped, none stacked ('..ta..' / '..tb..')',ta~=tb and ta>=6 and tb>=6 and ta~=16 and trunksA+trunksB>0,ta..' / '..tb)
 -- uneven: the spacing between tree trunks (nearest neighbour) is not constant; sizes differ 0.7 - 1.45 x
 local function trunks(m)local out={};for _,p in ipairs(partsOf(m))do if p._props.MeshId=='rbxassetid://5153142324'then out[#out+1]=p end end;return out end
 local ts=trunks(a)
 local heights,lean=nil,false
 local minH,maxH=math.huge,0
 for _,p in ipairs(ts)do local h=p._props.Size.Y;minH=math.min(minH,h);maxH=math.max(maxH,h);if math.abs(p._props.CFrame.R[1][2])>.01 or math.abs(p._props.CFrame.R[3][2])>.01 then lean=true end end
 check('hills: tree sizes differ (0.7 - 1.45 x: '..string.format('%.1f - %.1f',minH,maxH)..') and each leans a little',maxH/minH>1.3 and lean)
 local nearest={}
 for i,p in ipairs(ts)do local best=math.huge;for j,q in ipairs(ts)do if i~=j then local d=(p._props.CFrame.Position-q._props.CFrame.Position).Magnitude;if d<best then best=d end end end;nearest[#nearest+1]=best end
 table.sort(nearest)
 check('hills: the trees are spaced unevenly (nearest-neighbour distances run from '..string.format('%.1f to %.1f',nearest[1]or 0,nearest[#nearest]or 0)..')',#nearest>4 and nearest[#nearest]>nearest[1]*1.8)
 -- clusters sit at their spots and fit their boxes
 local slots=Assets.SlotsOf('SnowMountains')
 for i,m in ipairs(clusters)do
  local lo,hi=box(m);local s=slots[i]
  check('hills: cluster '..i..' stands inside its spot\'s box (|x| >= 100) ',math.min(math.abs(lo[1]),math.abs(hi[1]))>=100 and lo[1]*hi[1]>0,string.format('x %.0f .. %.0f',lo[1],hi[1]))
 end
 check('hills: every hill and tree part is anchored, no collide / touch / query, no shadow',flagsOf(partsOf(a),true,true)==nil and flagsOf(partsOf(b),true,true)==nil)
end
local fpHills=fingerprint(map.TrackBackdrops158)
Loader.Reset();Loader.Run(map)
check('hills: a rerun places everything the same (a fixed seed per spot)',fingerprint(map.TrackBackdrops158)==fpHills)
-- the volcano at the outer spots
local vols={};for _,m in ipairs(modelsOf('Lava'))do if m.Name:find('^LavaVolcano')then vols[#vols+1]=m end end
check('volcano: the four outer spots each get the owner\'s volcano when its mesh loads',#vols==4,#vols)
if #vols==4 then
 local sig={}
 for i,m in ipairs(vols)do
  local p=partsOf(m)[1];local lo,hi=box(m);local s=Assets.SlotsOf('LavaVolcano')[i]
  sig[#sig+1]=string.format('%.0f|%.1f|%.2f',hi[2]-lo[2],p._props.Color.R*255,p._props.CFrame.R[1][1])
  check('volcano: outer spot '..i..' fits its box ('..string.format('%.0f',hi[2]-Assets.Ground)..' tall above the ground, box '..s.H..', leaning '..tostring(s.Tilt)..' degrees) and keeps clear of the track',hi[2]-Assets.Ground<=s.H+math.max(s.W,s.D)*math.sin(math.rad(math.abs(s.Tilt or 0)))+.5 and math.min(math.abs(lo[1]),math.abs(hi[1]))>=100 and lo[1]*hi[1]>0,string.format('y %.1f x %.0f..%.0f',hi[2]-lo[2],lo[1],hi[1]))
  local glow=m:FindFirstChild('Crater glow')
  check('volcano: outer spot '..i..(s.Glow and' has a small glowing mouth (Neon), no lava stream'or' has no glow')..' and carries its tint',(glow~=nil)==(s.Glow==true)and(not glow or enumName(glow._props.Material)=='Neon')and p._props.Color.R<=1)
 end
 local uniq={};for _,s in ipairs(sig)do uniq[s]=true end;local nu=0;for _ in pairs(uniq)do nu+=1 end
 check('volcano: the four copies differ (size, tint, turn): '..nu..' different looks',nu==4,table.concat(sig,' ; '))
 local streams=0;for _,m in ipairs(vols)do streams+=#findStreams(m)end
 check('volcano: no lava stream on any outer volcano',streams==0)
end
-- the in-track volcano: the mesh form, then both forms failing
local oldLandmark=map.MythicLandmarks.Biome4_Landmark
local oldFoot={}
do local x0,x1,z0,z1;for _,d in ipairs(oldLandmark:GetChildren())do if d:IsA('BasePart')and(d.Name=='BasaltSlope'or d.Name=='CraterLip')then local lo,hi=aabb(d);x0=x0 and math.min(x0,lo[1])or lo[1];x1=x1 and math.max(x1,hi[1])or hi[1];z0=z0 and math.min(z0,lo[3])or lo[3];z1=z1 and math.max(z1,hi[3])or hi[3]end end;oldFoot={x0,x1,z0,z1} end
local oldVent=oldLandmark:FindFirstChild('CraterVent')
check('track volcano: the old cone is measured (footprint '..string.format('%.0f x %.0f',oldFoot[2]-oldFoot[1],oldFoot[4]-oldFoot[3])..') and has its vent',oldFoot[1]~=nil and oldVent~=nil)
-- the keyboard's skip scan (KeyboardSkip152) as it sees the map with the OLD cone, to compare with what it sees with the owner's mesh volcano (one MeshPart: its box is a square)
local Skip=W.require(RS.KeyboardSkip152);local KT=W.require(RS.KeyboardTrack)
local function skipCells()
 local attrs=map:GetAttributes();attrs.KeyboardSkip=nil
 local geo=KT.Geometry(attrs,mapService.BaseBoundaryLine.Position.X)
 return Skip.Scan(map,geo).Cells
end
local cellsOld=skipCells()
Loader.Reset();printed={}
local res=LV.Apply(map)
local newLandmark=map.MythicLandmarks:FindFirstChild('Biome4_Landmark')
check('track volcano: with the mesh available the owner\'s volcano replaces the old cone (same name Biome4_Landmark, VolcanoVersion 129 kept, marked Volcano158)',res.Replaced==true and newLandmark~=nil and newLandmark~=oldLandmark and newLandmark:GetAttribute('Volcano158')==true and newLandmark:GetAttribute('VolcanoVersion')==129)
local n1,c=child(map.MythicLandmarks,'Biome4_Landmark')
check('track volcano: exactly one landmark of that name, the old cone gone',c==1 and oldLandmark._destroyed==true)
local lo,hi=box(newLandmark)
local meshes={};for _,p in ipairs(partsOf(newLandmark))do if p._class=='MeshPart'then meshes[#meshes+1]=p end end
check('track volcano: it is the owner\'s mesh ('..#meshes..' MeshPart, mesh 5138886694), at the old spot, inside the old footprint and as wide as it allows',#meshes==1 and meshes[1]._props.MeshId=='rbxassetid://5138886694'
 and lo[1]>=oldFoot[1]-.05 and hi[1]<=oldFoot[2]+.05 and lo[3]>=oldFoot[3]-.05 and hi[3]<=oldFoot[4]+.05 and(near(hi[1]-lo[1],oldFoot[2]-oldFoot[1],.1)or near(hi[3]-lo[3],oldFoot[4]-oldFoot[3],.1)),
 string.format('x %.1f..%.1f z %.1f..%.1f vs old x %.1f..%.1f z %.1f..%.1f',lo[1],hi[1],lo[3],hi[3],oldFoot[1],oldFoot[2],oldFoot[3],oldFoot[4]))
check('track volcano: centred on the old centre',near((lo[1]+hi[1])/2,(oldFoot[1]+oldFoot[2])/2,.2)and near((lo[3]+hi[3])/2,(oldFoot[3]+oldFoot[4])/2,.2))
local walk=true
for _,p in ipairs(meshes)do local pr=p._props;if not(pr.CanCollide==false and pr.CanTouch==false and pr.CanQuery==true and pr.Anchored==true and pr.CastShadow==false)then walk=false end end
check('track volcano: walk-through exactly like the old one: CanCollide off, CanTouch off, CanQuery on (as the old parts), anchored, no shadow',walk)
local vent=newLandmark:FindFirstChild('CraterVent')
check('track volcano: the old embers, smoke and light (CraterVent) moved up to the new mouth',vent~=nil and vent._props.CFrame.Position.Y>=hi[2]-1.5 and near(vent._props.CFrame.Position.X,(lo[1]+hi[1])/2,.5))
check('track volcano: no lava stream, channel or pool in it, none on the map',#findStreams(map)==0)
check('track volcano: its root part is the PrimaryPart (the model can be moved as one)',newLandmark.PrimaryPart~=nil and newLandmark.PrimaryPart.Name=='VolcanoRoot')
-- the keyboard: the mesh volcano's box is a square round a round thing; keys under its square corners must not be left out (bare floor patches the old cone never had)
do
 local cellsNew=skipCells()
 local nOld,nNew,extra,asBox=0,0,0,0
 for k in pairs(cellsOld)do nOld+=1 end
 for k in pairs(cellsNew)do nNew+=1;if not cellsOld[k]then extra+=1 end end
 info('keyboard skip: '..nOld..' cells with the old cone, '..nNew..' with the owner\'s volcano ('..extra..' extra)')
 local disc=0;for _,p in ipairs(meshes)do if type(p:GetAttribute('KeyboardDisc'))=='number'and p:GetAttribute('KeyboardDisc')>0 then disc+=1 end end
 check('track volcano: the keyboard leaves out no key it did not leave out for the old cone (the mesh says KeyboardDisc: a round footprint, not its square box); '..nNew..' cells now, '..nOld..' before',extra==0 and nNew>0 and disc==#meshes,extra..' extra, '..disc..' discs')
end
local res2=LV.Apply(map)
check('track volcano: Apply again changes nothing (already the owner\'s volcano)',res2.Already==true and select(2,child(map.MythicLandmarks,'Biome4_Landmark'))==1)
check('track volcano: the V129 undo still finds its replacement (VolcanoVersion 129 on Biome4_Landmark)',newLandmark:GetAttribute('VolcanoVersion')==129)
-- both mesh forms failing: the old cone stays
do
 AS.CreateMeshPartAsync=function()error('HTTP 403 (Forbidden)')end
 Loader.Reset();printed={}
 -- a fresh old cone to swap against: rebuild it from the place's saved geometry by restoring the landmark the test replaced
 newLandmark:Destroy()
 local cone=R.new('Model');cone.Name='Biome4_Landmark';cone:SetAttribute('VolcanoVersion',129)
 local sl=R.new('Part');sl.Name='BasaltSlope';sl.Size=V3(40,5,40);sl.CFrame=CF(-60,10,2600);sl.Parent=cone
 local mouth=R.new('Model');mouth.Name='MoltenCrater';mouth.Parent=cone
 cone.Parent=map.MythicLandmarks
 local r3=LV.Apply(map)
 local still=map.MythicLandmarks:FindFirstChild('Biome4_Landmark')
 local noteOld
 for _,l in ipairs(printed)do if l:find('the old cone stays',1,true)and l:find('[R158 volcano]',1,true)then noteOld=l end end
 check('track volcano: both CreateMeshPartAsync forms failing keeps the old cone (its crater molten pool is removed: no lava pool), ONE plain note, not a warning',r3.Replaced==false and still==cone and cone:FindFirstChild('MoltenCrater')==nil and noteOld~=nil)
end
-- the volcano mesh through a hand-placed model (the owner's drag-in)
do
 Loader.Reset()
 local hand=R.new('Model');hand.Name='LavaVolcano';local mp=fakeMesh('rbxassetid://1',V3(90,60,80));mp.Parent=hand;hand.Parent=assetsFolder
 AS.CreateMeshPartAsync=function()error('must not be asked: a hand-placed model comes first')end
 local t=Loader.Template(map,'LavaVolcano')
 check('track volcano: a model dragged into ServerStorage.OuterTrackAssets158.LavaVolcano is used before any mesh is loaded',t~=nil and t.Kind=='instance'and t.Source:find('ServerStorage',1,true)~=nil)
 hand:Destroy()
end

-- 8. the code review's fixes ------------------------------------------------------------------------------------------------------------------------------
-- (a) a copy of the game's own model keeps no tag and no attribute; (b) a source that is not a Model (a Folder from a loaded asset) is wrapped in one; (c) the mesh is asked for with
-- the cheap fidelities, and asked again without them only when the engine does not know them.
do
 local CS=W.service('CollectionService')
 -- the mock's Clone leaves tags and attributes behind; Roblox's Clone copies both (that is the bug): make the mock do the same
 local rawClone=R.Inst.Clone
 R.Inst.Clone=function(self)
  local c=rawClone(self)
  for k,v in pairs(self._attrs)do c._attrs[k]=v end
  if self._tags then local own={};for t in pairs(self._tags)do own[t]=true end;c._tags=own end -- (its own table: the mock keeps _tags among the properties Clone copies by reference)
  return c
 end
 local src=R.new('Model');src.Name='Tall jungle tree'
 block(src,'Trunk',V3(5,26,5),V3(0,13,0))
 local bush=block(src,'Bush',V3(9,7,9),V3(14,4,0))
 bush:SetAttribute('HideBushId',7);CS:AddTag(bush,'HideBush')
 src:SetAttribute('Looked',true);CS:AddTag(src,'Scenery')
 local copy=src:Clone()
 check('prepare: (the mock now copies tags and attributes on Clone, as Roblox does: the copy of the bush carries HideBush / HideBushId)',CS:HasTag(copy:FindFirstChild('Bush'),'HideBush')and copy:FindFirstChild('Bush'):GetAttribute('HideBushId')==7 and copy:GetAttribute('Looked')==true)
 local p=Loader.Prepare(src)
 local dirty=0
 for _,d in ipairs(p.Model:GetDescendants())do if(d._tags and next(d._tags)~=nil)or next(d._attrs)~=nil then dirty+=1 end end
 if(p.Model._tags and next(p.Model._tags)~=nil)or next(p.Model._attrs)~=nil then dirty+=1 end
 check('prepare: a prepared copy of a game model keeps no CollectionService tag and no attribute (HideBush / HideBushId would turn the giant bushes see-through for a player hiding in a real bush)',dirty==0 and #partsOf(p.Model)==2,dirty)
 check('prepare: ... and the original in the map keeps its own tag and attribute',CS:HasTag(bush,'HideBush')and bush:GetAttribute('HideBushId')==7 and CS:HasTag(src,'Scenery'),
  tostring(CS:HasTag(bush,'HideBush'))..' '..tostring(bush:GetAttribute('HideBushId'))..' '..tostring(CS:HasTag(src,'Scenery')))
 -- (b) a Folder source
 local folderSrc=R.new('Folder');folderSrc.Name='LoadedTree'
 block(folderSrc,'Trunk',V3(4,20,4),V3(0,10,0));block(folderSrc,'Crown',V3(14,8,14),V3(0,24,0))
 local pf=Loader.Prepare(folderSrc)
 local okPlace,placedF=pcall(function()return Loader.PlaceModel(pf,{X=200,Z=100,Yaw=0,W=60,H=80,D=60},'t')end)
 check('prepare: a Folder source (a loaded asset may be one) is wrapped in a Model of its own, so it scales and moves as one',pf~=nil and pf.Model._class=='Model'and pf.Model.Name=='LoadedTree'and okPlace and #partsOf(placedF)==2,tostring(placedF))
 local partSrc=R.new('Part');partSrc.Name='LoneRock';partSrc.Size=V3(10,10,10)
 local pp=Loader.Prepare(partSrc)
 check('prepare: a lone Part is wrapped in a Model too',pp~=nil and pp.Model._class=='Model')
 R.Inst.Clone=rawClone
 -- (c) the mesh request's options
 local seen={}
 local askedFor
 AS.CreateMeshPartAsync=function(self,content,options)seen[#seen+1]=options;return fakeMesh('rbxassetid://5138886694',V3(70,52.6,59.8))end
 local mp=Loader.CreateMesh('rbxassetid://5138886694')
 check('mesh: CreateMeshPartAsync is asked with CollisionFidelity Box and RenderFidelity Automatic',mp~=nil and #seen==1 and seen[1]~=nil and seen[1].CollisionFidelity==R.Enum.CollisionFidelity.Box and seen[1].RenderFidelity==R.Enum.RenderFidelity.Automatic)
 seen={}
 AS.CreateMeshPartAsync=function(self,content,options)seen[#seen+1]=options or'none';if options then error('invalid argument #3 to \'CreateMeshPartAsync\' (expected nil)')end;return fakeMesh('rbxassetid://5138886694',V3(70,52.6,59.8))end
 local mp2=Loader.CreateMesh('rbxassetid://5138886694')
 check('mesh: an engine that does not know the options is asked again without them',mp2~=nil and #seen==2 and seen[1]~='none'and seen[2]=='none',#seen)
 seen={}
 AS.CreateMeshPartAsync=function(self,content,options)seen[#seen+1]=options or'none';error('HTTP 403 (Forbidden)')end
 local mp3,why3=Loader.CreateMesh('rbxassetid://5138886694')
 check('mesh: a real failure (HTTP 403) is asked once, not twice, and says why',mp3==nil and #seen==1 and tostring(why3):find('403',1,true)~=nil,#seen)
end
print('R158 walls (mock): '..passed..' checks passed, '..failed..' failed')
if failed>0 then error('R158 walls: '..failed..' checks failed')end
