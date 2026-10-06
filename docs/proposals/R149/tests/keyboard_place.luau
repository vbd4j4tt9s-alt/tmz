-- R152 (owner: "for some areas on the track like this make sure that there is no keyboard tiles there": the Desert oasis). The owner's place (Workspace.ChestChaseMap) on the Roblox
-- mock, after the REAL start-up passes (MapService.new: the scenery passes, TrackExpansion83 moving every scenery group, then KeyboardSkip152.Apply writes the map attribute
-- KeyboardSkip), then the REAL client keyboard next to the oasis. This file is the TAIL of the scene: run_keyboard.sh runs it after lines 11 - 63 of zfight_scene.luau (the mock
-- world, the place, MapService.new). Prints AREAS (the areas left out per biome) and DROPPED (the number of keys dropped); every check below uses only the live part positions.
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return a~=nil and b~=nil and math.abs(a-b)<=(e or 1e-6)end
local abs,min,max,floor=math.abs,math.min,math.max,math.floor
R.advance(1)
check(failed==0,'every start-up step of the scene ran ('..failed..' failed)')
local K=W.module('KeyboardTrack');local C=K.Config;local F=C.FloorTop;local S=W.module('KeyboardSkip152')
local attrStr=map:GetAttribute('KeyboardSkip')
check(type(attrStr)=='string'and #attrStr>40,'MapService.new published the map attribute KeyboardSkip ('..tostring(attrStr and #attrStr)..' characters)')
local geo=K.Geometry(map:GetAttributes(),0)
local dropped=geo.SkipCount
check(geo.Rows==728 and dropped>=100 and dropped<=250,('the keyboard has %d of its %d cells left out (%.1f%%)'):format(dropped,geo.Rows*geo.Cols,dropped/(geo.Rows*geo.Cols)*100))
-- the scan again: the same cells, and the areas per biome
local a2=map:GetAttributes();a2.KeyboardSkip=nil
local res=S.Scan(map,K.Geometry(a2,0))
check(res.Count==dropped,'scanning the finished map again gives the same cells ('..res.Count..')')
local ids={};for stage in pairs(res.Report)do ids[#ids+1]=stage end;table.sort(ids)
local perBiome={}
for _,stage in ipairs(ids)do
 local total=0;local names={}
 for _,e in ipairs(res.Report[stage])do total+=e.Cells;names[#names+1]=('%s [%s] %d'):format(e.Name,e.Class,e.Cells)end
 perBiome[stage]=total
 print(('AREAS %s (stage %d): %d keys dropped: %s'):format(K.BiomeNames[stage]or'?',stage,total,table.concat(names,'; ')))
end
print(('DROPPED %d of %d keys (%d scenery parts looked at)'):format(dropped,geo.Rows*geo.Cols,res.Parts))
local desertFlat=0;for _,e in ipairs(res.Report[2]or{})do if e.Class=='flat'and e.Name=='Small oasis'then desertFlat=e.Cells end end
check(desertFlat>=10,'the Desert oasis (Small oasis: water, its stone and palm bases) leaves out '..desertFlat..' keys')
local lavaFlat=0;for _,e in ipairs(res.Report[4]or{})do if e.Class=='flat'then lavaFlat+=e.Cells end end
check(lavaFlat>=15,'the Lava biome leaves out '..lavaFlat..' keys over its lava river / pools / channels')
-- props only when mostly buried (60%): the wall banks / rocky edges along the track's edge leave their edge keys in (R151 look, no bare gaps along the walls)
local bankCells,flatTotal,propTotal=0,0,0
for stage=1,7 do for _,e in ipairs(res.Report[stage]or{})do
 if e.Class=='flat'then flatTotal+=e.Cells else propTotal+=e.Cells end
 local n=e.Name:lower();if n:find('wall bank',1,true)or n:find('rocky edge',1,true)then bankCells+=e.Cells end
end end
check(bankCells<=12,('wall banks / rocky edges drop only %d keys in all (was 175 at a 25%% threshold)'):format(bankCells))
check(flatTotal>=40 and propTotal>=60,('%d keys dropped for water / lava, %d for props that bury them'):format(flatTotal,propTotal))
print(('SPLIT water/lava %d, props %d'):format(flatTotal,propTotal))
-- the live oasis: its water parts (oriented boxes, turned a little about the vertical axis), found by name in the finished map
local function find(root,path)for n in path:gmatch('[^/]+')do root=root and root:FindFirstChild(n)end;return root end
local oasis;for _,b in ipairs(map.Obby.Biomes:GetChildren())do local f=find(b,'GeneratedScenery/Small oasis');if f then oasis=f end end
check(oasis~=nil,'the Desert\'s Small oasis is in the map')
local water={}
for _,pt in ipairs(oasis:GetChildren())do
 if pt.Name=='Oasis water'or pt.Name=='Water edge'or pt.Name=='Water corner'then
  local _,_,_,r00,r01,r02,r10,r11,r12,r20,r21,r22=pt.CFrame:GetComponents();local p=pt.CFrame.Position
  check(abs(r10)<.02 and abs(r12)<.02 and abs(r11)>.99,'the oasis water part '..pt.Name..' is only turned about the vertical axis (the independent check below uses its oriented box)')
  water[#water+1]={X=p.X,Z=p.Z,SX=pt.Size.X/2,SZ=pt.Size.Z/2,R00=r00,R20=r20,R02=r02,R22=r22}
 end
end
check(#water==3,'three water parts found ('..#water..')')
local wz0,wz1,wx0,wx1=1e9,-1e9,1e9,-1e9
for _,w in ipairs(water)do -- the oriented box's extent
 local hx=abs(w.R00)*w.SX+abs(w.R02)*w.SZ;local hz=abs(w.R20)*w.SX+abs(w.R22)*w.SZ
 wx0=min(wx0,w.X-hx);wx1=max(wx1,w.X+hx);wz0=min(wz0,w.Z-hz);wz1=max(wz1,w.Z+hz)
end
local KW=K.KeySize(geo.Pitch)
-- the share of a key footprint (an 8 x 8 grid of points, not the scan's 5 x 5) over the union of the water boxes
local function waterShare(row,col)
 local x,z=geo.CellCenter(row,col);local n=0
 for i=1,8 do for j=1,8 do
  local px,pz=x+((i-.5)/8-.5)*KW,z+((j-.5)/8-.5)*KW
  for _,w in ipairs(water)do
   local dx,dz=px-w.X,pz-w.Z
   if abs(w.R00*dx+w.R20*dz)<=w.SX and abs(w.R02*dx+w.R22*dz)<=w.SZ then n+=1;break end
  end
 end end
 return n/64
end
local r0,r1=geo.RowOfZ(wz0)-2,geo.RowOfZ(wz1)+2
local inWater,keptOver,skippedClear=0,0,0
for r=r0,r1 do if not geo.BarOfRow[r]then for c=1,geo.Cols do
 local share=waterShare(r,c);local out=geo.Skipped(r,c)
 if share>=.22 then inWater+=1;if not out then keptOver+=1 end end
 if not out and share>.16 then keptOver+=1 end
end end end
check(inWater>=6 and keptOver==0,('rows %d .. %d around the oasis (%.0f .. %.0f, x %.0f .. %.0f): %d cells have at least 22%% of their key under its water: every one is left out, and no kept key has more than 16%% (%d violations)'):format(r0,r1,wz0,wz1,wx0,wx1,inWater,keptOver))
-- the real client next to the oasis: the keys, the letters, the floor
local Run=W.service('RunService');Run.IsClient=function()return true end;Run.IsServer=function()return false end
local player=R.new('Player');player.Name='Tester';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return{player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play()end;function R.Inst.Stop()end
W.service('ContentProvider').PreloadAsync=function()end
W.stub('ClientFxBudget',{Get=function()return 3 end,Low=function()return false end})
if not RS:FindFirstChild('R142Keycap')then
 local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55);template.Parent=RS
end
local model=R.new('Model');model.Name='Tester'
local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Transparency=1;root.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Air;hum.Parent=model;model.PrimaryPart=root;model.Parent=W.workspace;player.Character=model
local zc=(wz0+wz1)/2
root.CFrame=CF(0,F+9,zc-70)
local camera=W.workspace.CurrentCamera;camera.CFrame=R.CFrame.lookAt(V3(0,20,zc-90),V3(0,20,zc+100))
local okLoad=false
step('KeyboardTrack.client',function()local sc=R.new('LocalScript');sc.Name='KeyboardTrack';W.load('KeyboardTrackClient',sc);W.frames(240);okLoad=true end)
check(okLoad,'the keyboard client runs on the owner\'s map')
local vis=W.workspace:FindFirstChild('KeyboardTrackVisuals')
check(vis~=nil,'the keyboard is built')
local keysF,legF,groundF=vis.Keys,vis.Legends,vis.Ground
local keysOverWater,keysSeen,keyOnSkip=0,0,0
for _,p in ipairs(keysF:GetChildren())do
 if p.Name=='Key'and p.Transparency==0 then
  keysSeen+=1
  local pos=p.CFrame.Position;local row,col=geo.RowOfZ(pos.Z),geo.ColOfX(pos.X)
  if geo.Skipped(row,col)then keyOnSkip+=1 end
  if pos.Z>=wz0-9 and pos.Z<=wz1+9 and waterShare(row,col)>.16 then keysOverWater+=1 end
 end
end
check(keysSeen>2500 and keyOnSkip==0,('the client dressed %d keys around the oasis and none stands on a left-out cell (%d)'):format(keysSeen,keyOnSkip))
check(keysOverWater==0,'no key stands in or over the oasis water ('..keysOverWater..')')
-- letters: none over a left-out cell
local labels,floating=0,0
for _,st in ipairs(legF:GetChildren())do
 if(st.Name=='LegendStrip'or st.Name=='LegendFar')and st.CFrame.Position.Y>0 then
  local gui=st:FindFirstChildWhichIsA('SurfaceGui');local pps=gui.PixelsPerStud
  for _,l in ipairs(gui:GetChildren())do
   if l._class=='TextLabel'and l.Visible then
    labels+=1
    local p=st.CFrame.Position
    local wx=p.X-st.Size.X/2+l.Position.Y.Offset/pps;local wz=p.Z+st.Size.Z/2-l.Position.X.Offset/pps
    if geo.Skipped(geo.RowOfZ(wz),geo.ColOfX(wx))then floating+=1 end
   end
  end
 end
end
check(labels>800 and floating==0,('%d letters shown around the oasis, none over a left-out cell (%d)'):format(labels,floating))
-- the real floor stays under the oasis (local copies at the floor top)
local under=0
for _,pt in ipairs(groundF:GetChildren())do
 if pt.Name=='GroundPatch'and abs(pt.CFrame.Position.Y+pt.Size.Y/2-F)<1e-6 and pt.CFrame.Position.Z>wz0-40 and pt.CFrame.Position.Z<wz1+40 then under+=1 end
end
check(under>=1,'floor copies lie under the left-out cells around the oasis ('..under..')')
-- the effects authored at floor level stay at the floor over the water
local KS=W.module('KeyboardSurface149')
local wx,wz=(wx0+wx1)/2,(wz0+wz1)/2
check(geo.Skipped(geo.RowOfZ(wz),geo.ColOfX(wx))and KS.TopY(wx,wz)==nil,'KeyboardSurface149: no key top over the middle of the oasis')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
