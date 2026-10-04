--!nocheck
-- R147: the candy keyboard runway. Part 1: ReplicatedStorage.KeyboardTrack (pure config + grid maths). Part 2: the real
-- StarterPlayerScripts/KeyboardTrack.client.lua on the mock world (client only, no remotes).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS;local workspace=W.workspace
local function frames(n,dt)W.frames(n,dt)end

-- ======================================================================================================================
-- Part 1: KeyboardTrack.lua
-- ======================================================================================================================
local K=W.module('KeyboardTrack');local C=K.Config
local ATTR={BiomeTrackEndZ=5980,BiomeStartZ_1=-100,BiomeEndZ_1=80,BiomeStartZ_6=80,BiomeEndZ_6=530,BiomeStartZ_2=530,BiomeEndZ_2=1180,
 BiomeStartZ_3=1180,BiomeEndZ_3=2030,BiomeStartZ_4=2030,BiomeEndZ_4=3080,BiomeStartZ_5=3080,BiomeEndZ_5=4380,BiomeStartZ_7=4380,BiomeEndZ_7=5980}
local F=C.FloorTop
check(C.Pitch==8 and C.Columns==6 and C.KeyX==7.5 and C.KeyY==3.42 and C.KeyZ==7.5,'config: pitch 8, 6 columns, key 7.5 x 3.42 x 7.5')
check(F==4.0 and near(F+C.RestRise,4.8)and near(F+C.PressedRise,4.15)and C.PressSeconds==.06 and C.ReleaseSeconds==.14,'config: floor 4.0, rest top +0.8, pressed top +0.15, press .06 s, release .14 s')
check(C.BedWidth==50 and C.BedColor[1]==86 and C.BedColor[2]==52 and C.BedColor[3]==34 and near(C.BedRise,.05)and C.RailColor[1]==62 and C.RailX==25.6 and C.RailWidth==1.2 and C.RailHeight==1.0,'config: bed 50 wide chocolate top +0.05, rails dark chocolate 1.2 x 1.0 at x = +-25.6')
check(C.NearRadius[3]==160 and C.NearRadius[2]==120 and C.NearRadius[1]==80 and C.LegendRadius==56 and C.StripChunk==16 and C.BuildRadius==1100 and C.FreeRadius==1300 and C.MaxNear==240 and C.TopOffset==0,'config: radii 160/120/80, legends 56, strips in 16-row chunks (build 1100 / free 1300), 240 near keys, TopOffset 0')
check(C.StripSize[1]==47.5 and C.StripSize[2]==.6 and C.StripSize[3]==7.5,'config: far strip 47.5 x 0.6 x 7.5')
check(C.OwnClicksPerSecond==12 and C.OtherClicksPerSecond==8 and C.OtherClickRange==90 and C.KeeperPitch==.7 and #C.ClickSoundIds==3 and C.ClickSoundIds[1]==113108830240353 and C.ClickSoundIds[2]==88838553648526 and C.ClickSoundIds[3]==96591611478915,'config: click ids, 12/s own, 8/s others within 90, keepers pitch 0.7')
local pitchOk=#C.ClickPitches>=3;for _,p in ipairs(C.ClickPitches)do if p<.96 or p>1.06 then pitchOk=false end end
check(pitchOk,'own click pitches stay within 0.96 .. 1.06')

local g=K.Geometry(ATTR,0)
check(g.Z0==-96 and g.Rows==744,'geometry: Z0 -96, 744 rows for EndZ 5980 (got '..g.Rows..')')
check(K.Geometry(ATTR,0).Rows==744 and K.Geometry(ATTR).Rows==744 and K.Geometry({BiomeTrackEndZ=1445},0).Rows==177,'geometry: rows = floor((EndZ-120-Z0)/8) (EndZ 1445 -> 177)')
check(g.Z0+g.Rows*8<=ATTR.BiomeTrackEndZ-120 and g.Z0+(g.Rows+1)*8>ATTR.BiomeTrackEndZ-120,'geometry: the last row ends at or before EndZ-120, the next would not')
local x1,z1=g.CellCenter(1,1);local x6,z6=g.CellCenter(744,6)
check(x1==-20 and z1==-92 and x6==20 and z6==g.Z0+743.5*8,'cell centres: (1,1) = (-20,-92); (744,6) = (20, last row)')
local gShift=K.Geometry(ATTR,12);check(select(1,gShift.CellCenter(1,1))==-8 and select(1,gShift.CellCenter(1,6))==32,'columns follow TrackCenterX')
-- CellsInRect: edges, touching, outside, everything
local function ids(list)local t={};for _,c in ipairs(list)do t[#t+1]=c.row..':'..c.col end;table.sort(t);return table.concat(t,',')end
check(ids(g.CellsInRect(-8,0,-8,0))=='12:3','CellsInRect: a rect that exactly fills one cell is that cell only (got '..ids(g.CellsInRect(-8,0,-8,0))..')')
check(ids(g.CellsInRect(-1.6,1.6,-1.6,1.6))=='12:3,12:4,13:3,13:4','CellsInRect: a footprint on a cell corner claims 4 cells')
check(ids(g.CellsInRect(0,0,-4,-4))=='12:4','CellsInRect: a point on a column line belongs to the cell on its +x side')
check(ids(g.CellsInRect(-24,-24,-96,-96))=='1:1','CellsInRect: the very first corner is cell 1:1')
check(#g.CellsInRect(30,40,0,10)==0 and #g.CellsInRect(-40,-24.5,0,10)==0,'CellsInRect: outside in x is empty')
check(#g.CellsInRect(-5,5,-120,-96)==0 and #g.CellsInRect(-5,5,5856,5900)==0 and #g.CellsInRect(-5,5,5860,5900)==0,'CellsInRect: touching or beyond the first / last row edge is empty')
check(#g.CellsInRect(-5,5,5848,5856)==2 and ids(g.CellsInRect(-5,5,5848,5856))=='744:3,744:4','CellsInRect: the last row is reachable')
check(#g.CellsInRect(-1000,1000,-1000,9000)==6*744,'CellsInRect: a huge rect clamps to the 6 x 744 grid')
check(#g.CellsInRect(5,-5,10,-10)==#g.CellsInRect(-5,5,-10,10),'CellsInRect: reversed bounds are accepted')
local c1,c2,r1,r2=g.CellRange(-1.6,1.6,-1.6,1.6);check(c1==3 and c2==4 and r1==12 and r2==13,'CellRange: the allocation-free form agrees')
local nan=0/0;local e1,e2=g.CellRange(nan,1,0,1);check(e1>e2,'CellRange: NaN gives an empty range')
-- biomes and spacebars
local want={{1,'Forest',1,22},{6,'Jungle',23,78},{2,'Desert',79,159},{3,'Snow',160,265},{4,'Lava',266,397},{5,'Crystal',398,559},{7,'Storm Peaks',560,744}}
check(#g.Stages==7,'seven biomes')
for i,w in ipairs(want)do
 local s=g.Stages[i]
 check(s and s.Id==w[1]and s.Name==w[2]and s.FirstRow==w[3]and s.LastRow==w[4],'biome '..w[2]..' rows '..w[3]..'-'..w[4]..' (got '..tostring(s and s.FirstRow)..'-'..tostring(s and s.LastRow)..')')
 check(g.SpaceRow[w[3]]==s,'the first row of '..w[2]..' (row '..w[3]..') is its spacebar row')
 check(g.RowStage[w[3]]==w[1]and g.RowStage[w[4]]==w[1],'rows of '..w[2]..' belong to stage '..w[1])
end
local spaceCount=0;for _ in pairs(g.SpaceRow)do spaceCount+=1 end
check(spaceCount==7,'exactly one spacebar row per biome (7)')
local id,name=K.BiomeAt(-100,ATTR);check(id==1 and name=='Forest','BiomeAt: the start of the track is Forest')
id,name=K.BiomeAt(79.99,ATTR);check(id==1,'BiomeAt: just before 80 is still Forest')
id,name=K.BiomeAt(80,ATTR);check(id==6 and name=='Jungle','BiomeAt: 80 is Jungle (stage ids are not track order)')
id,name=K.BiomeAt(2030,ATTR);check(id==4 and name=='Lava','BiomeAt: 2030 is Lava')
id,name=K.BiomeAt(5979,ATTR);check(id==7 and name=='Storm Peaks','BiomeAt: 5979 is Storm Peaks')
id=K.BiomeAt(5980,ATTR);check(id==0,'BiomeAt: past the last biome is 0');check(K.BiomeAt(-101,ATTR)==0 and K.BiomeAt(10,nil)==0,'BiomeAt: before the track / without attributes is 0')
local named=table.clone(ATTR);named.BiomeName_6='Rainforest';id,name=K.BiomeAt(100,named);check(name=='Rainforest','BiomeAt: BiomeName_n attribute overrides the name')
check(K.Geometry(named,0).SpaceRow[23].Name=='Rainforest','the spacebar uses the BiomeName_n attribute too')
check(g.BiomeAt(100)==6 and g.BiomeAt(-50)==1,'geometry BiomeAt agrees')
-- palette, jitter, legends
local expectRGB={{255,120,165},{255,224,102},{110,222,182},{110,165,255},{184,136,255},{255,160,96}}
local palette=true
for r=1,12 do
 local s=K.RowStyle(r,0,false);local e=expectRGB[(r-1)%6+1]
 if s.RGB[1]~=e[1]or s.RGB[2]~=e[2]or s.RGB[3]~=e[3]then palette=false end
end
check(palette,'palette cycles strawberry, lemon, mint, blueberry, grape, orange per row (period 6)')
check(K.RowStyle(1,0,false)==K.RowStyle(7,0,false)and K.RowStyle(1,0,false)~=K.RowStyle(2,0,false),'row styles are cached tables')
check(K.RowStyle(3,2,false).Name~=K.RowStyle(3,0,false).Name,'the biome offsets the candy cycle')
local cream=K.RowStyle(23,6,true);check(cream.RGB[1]==255 and cream.RGB[2]==244 and cream.RGB[3]==214 and cream.Space==true,'spacebar rows are cream')
local ink=K.RowStyle(1,0,false).Ink;check(ink.R<.4 and ink.G<.3 and ink.B<.2,'legend ink is chocolate')
local minJ,maxJ,sumJ,n=2,0,0,0
for r=1,744 do for c=1,6 do local j=K.Jitter(r,c);minJ=math.min(minJ,j);maxJ=math.max(maxJ,j);sumJ+=j;n+=1 end end
check(minJ>=.94-1e-9 and maxJ<=1.06+1e-9,'jitter stays within +-6% (got '..string.format('%.4f..%.4f',minJ,maxJ)..')')
check(maxJ-minJ>.08 and math.abs(sumJ/n-1)<.01,'jitter really varies and averages to 1 (got spread '..string.format('%.3f mean %.4f',maxJ-minJ,sumJ/n)..')')
local det=true
for r=1,50 do for c=1,6 do
 local a1,b1,c1_=K.KeyRGB(K.RowStyle(r,3,false),r,c);local a2,b2,c2_=K.KeyRGB(K.RowStyle(r,3,false),r,c)
 if a1~=a2 or b1~=b2 or c1_~=c2_ then det=false end
end end
check(det and K.Jitter(5,2)==K.Jitter(5,2),'colours are deterministic (no randomness)')
local kr,kg,kb=K.KeyRGB(K.RowStyle(1,0,false),1,1);local base=K.RowStyle(1,0,false).RGB
check(math.abs(kr-base[1])<=base[1]*.061+1 and math.abs(kg-base[2])<=base[2]*.061+1 and kb>=0 and kb<=255,'a key colour is its row colour within 6%')
local legendOk=K.Legend(1,1)=='Q' and K.Legend(1,6)=='Y' and K.Legend(2,1)=='A' and K.Legend(2,6)=='H' and K.Legend(3,1)=='Z' and K.Legend(3,6)=='N' and K.Legend(4,1)=='1' and K.Legend(4,6)=='6' and K.Legend(5,3)=='E' and K.Legend(8,2)=='2'
check(legendOk,'legends cycle QWERTY / ASDFGH / ZXCVBN / 123456 per row')
-- easing and heights
check(K.Ease.QuadOut(0)==0 and K.Ease.QuadOut(1)==1 and K.Ease.QuadOut(.5)==.75 and K.Ease.Linear(.3)==.3,'ease: quad-out and linear')
local peak=0;for i=0,100 do peak=math.max(peak,K.Ease.BackOut(i/100))end
check(near(K.Ease.BackOut(0),0)and near(K.Ease.BackOut(1),1)and peak>1.05 and peak<1.2,'ease: back-out overshoots a little and settles at 1 (peak '..string.format('%.3f',peak)..')')
check(near(K.KeyTop(0),4.8)and near(K.KeyTop(1),4.15)and near(K.KeyCenterY(0),4.8-3.42/2),'key heights: rest top 4.8, pressed top 4.15')
check(K.NearRows(3)==40 and K.NearRows(2)==30 and K.NearRows(1)==20 and K.NearRows(3)*6<=C.MaxNear,'near window: 40 / 30 / 20 rows (<= 240 keys)')
check(K.KeeperFootprint(2,2)==1.5 and K.KeeperFootprint(10,12)==3 and K.KeeperFootprint(60,80)==6,'keeper footprint = clamp(0.3 * min extent, 1.5, 6)')
local segs=K.Segments(g.Z0,g.Z0+g.Rows*8,1024);local contiguous=true;local total=0
for i,s in ipairs(segs)do total+=s.Length;if s.Length>1024+1e-9 or(i>1 and not near(s.Z0,segs[i-1].Z1))then contiguous=false end end
check(#segs==6 and contiguous and near(total,5952)and near(segs[1].Z0,-96),'bed segments: 6 contiguous pieces of at most 1024 studs covering all rows')
local lim=K.NewLimiter(3);local allowed=0;for i=0,29 do if K.Allow(lim,i*.05)then allowed+=1 end end
check(allowed<=3*2+1 and allowed>=5,'limiter: at most 3 per second over 1.5 s ('..allowed..')')
-- sliding window: never more than N in any 1 s
local lim2=K.NewLimiter(12);local stamps={};for i=0,599 do local t=i/60;if K.Allow(lim2,t)then stamps[#stamps+1]=t end end
local worst=0;for i,t in ipairs(stamps)do local c=0;for _,u in ipairs(stamps)do if u>t-1 and u<=t then c+=1 end end;worst=math.max(worst,c)end
check(worst<=12 and #stamps>=100,'limiter: 12 per second at 60 Hz ('..#stamps..' in 10 s, worst window '..worst..')')

-- ======================================================================================================================
-- Part 2: the client script
-- ======================================================================================================================
check(not W.B.KeyboardTrackClient:find('RemoteEvent',1,true)and not W.B.KeyboardTrackClient:find('FireServer',1,true)and not W.B.KeyboardTrackClient:find('InvokeServer',1,true),'client source: no remote use')
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local others={}
function Players.GetPlayers()local t={player};for _,p in ipairs(others)do t[#t+1]=p end;return t end
-- Mock gaps filled here (not in the shared mock): real BulkMoveTo, Sound:Play/Stop, ContentProvider.
local bulkCalls,bulkMax,inBulk=0,0,false
function workspace.BulkMoveTo(_,parts,cfs)
 bulkCalls+=1;bulkMax=math.max(bulkMax,#parts);assert(#parts==#cfs,'BulkMoveTo lists must match')
 inBulk=true;for i,p in ipairs(parts)do p.CFrame=cfs[i]end;inBulk=false
end
local plays={}
function R.Inst.Play(self)
 local anchor=self.Parent
 plays[#plays+1]={Id=self.SoundId,Speed=self.PlaybackSpeed,Volume=self.Volume,T=R.clock,Pos=anchor and anchor._props.CFrame and anchor._props.CFrame.Position,Group=self.SoundGroup}
end
function R.Inst.Stop()end
local contentCalls=0
W.service('ContentProvider').PreloadAsync=function()contentCalls+=1 end
-- count writes: Color per key (= key reassignments) and CFrame per key (must only be the one parking write)
local colorWrites,cframeWrites=0,0
local origNew=R.instMeta.__newindex
R.instMeta.__newindex=function(o,k,v)
 if o._props.Name=='Key'then if k=='Color'then colorWrites+=1 elseif k=='CFrame'and not inBulk then cframeWrites+=1 end end
 return origNew(o,k,v)
end

-- the world: map without the biome attributes yet, real-looking floor, the keycap template
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace
local floor=R.new('Part');floor.Name='BiomeGround_1';floor.Size=V3(180,4,180);floor.CFrame=CF(0,2,0);floor.Anchored=true;floor.CanCollide=true;floor.Parent=map
local camps=R.new('Folder');camps.Name='GuardianEncounters';camps.Parent=map
local runtime=R.new('Folder');runtime.Name='_GameplayRuntime';runtime.Parent=map
local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55);template:SetAttribute('MeshId','rbxassetid://8837613273')
local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.CanvasSize=R.Vector2.new(256,256);tgui.Parent=template
local tlabel=R.new('TextLabel');tlabel.Name='TextLabel';tlabel.Text='A';tlabel.Parent=tgui
local tscript=R.new('Script');tscript.Name='StrayScript';tscript.Parent=template
template.Parent=RS
-- the local character
local function makeCharacter(name,x,z)
 local model=R.new('Model');model.Name=name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(x,F+3,z);root.Parent=model
 local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.HipHeight=2;hum.Parent=model
 model.PrimaryPart=root;model.Parent=workspace
 return model,root,hum
end
local char,root,hum=makeCharacter('Tester',-4,-4);player.Character=char;hum.FloorMaterial=R.Enum.Material.Air  -- in the air: presses nothing until a test lands
local PLASTIC,AIR=R.Enum.Material.Plastic,R.Enum.Material.Air
local function put(x,y,z)root.CFrame=CF(x,y or F+3,z)end
local sc=R.new('LocalScript');sc.Name='KeyboardTrack'
local okLoad,errLoad=pcall(W.load,'KeyboardTrackClient',sc);check(okLoad,'client loads: '..tostring(errLoad))
frames(5)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'without the biome attributes nothing is built yet (it waits for them)')
for k,v in pairs(ATTR)do map:SetAttribute(k,v)end
frames(40)
local vis=workspace:FindFirstChild('KeyboardTrackVisuals')
check(vis~=nil,'the visuals folder appears once the attributes exist')
local keys=vis:FindFirstChild('Keys');local strips=vis:FindFirstChild('Strips');local bed=vis:FindFirstChild('Bed')
check(keys and strips and bed,'sub folders Bed / Strips / Keys')
local function keyParts()return keys:GetChildren()end
local function shown()local t={};for _,p in ipairs(keyParts())do if p.Transparency==0 then t[#t+1]=p end end;return t end
local function top(p)return p.CFrame.Position.Y+C.KeyY/2-C.TopOffset end
local function keyAt(row,col)
 local x,z=g.CellCenter(row,col)
 for _,p in ipairs(keyParts())do
  local pos=p.CFrame.Position
  if p.Transparency==0 and near(pos.X,x,.01)and near(pos.Z,z,.01)then return p end
 end
 return nil
end
local function stripAt(row)
 local z=g.Z0+(row-.5)*8
 for _,p in ipairs(strips:GetChildren())do if near(p.CFrame.Position.Z,z,.01)then return p end end
 return nil
end
local function allDescendants()return vis:GetDescendants()end
local function nonRemote()
 for _,o in ipairs(R.created)do if o._class=='RemoteEvent'or o._class=='RemoteFunction'or o._class=='UnreliableRemoteEvent'then return false end end
 return true
end
check(nonRemote(),'no RemoteEvent / RemoteFunction was created')
-- 1. what was built
local badParts=0;local partCount=0
for _,o in ipairs(allDescendants())do
 if o:IsA('BasePart')then partCount+=1
  if o.Anchored~=true or o.CanCollide~=false or o.CanQuery~=false or o.CanTouch~=false or o.CastShadow~=false then badParts+=1 end
 end
end
check(partCount>200 and badParts==0,'every keyboard part is Anchored, CanCollide / CanQuery / CanTouch / CastShadow false ('..partCount..' parts, '..badParts..' bad)')
check(floor.Transparency==0 and floor.CanCollide==true and floor.Size.X==180 and floor.CFrame.Position.Y==2 and floor.Parent==map,'the real floor is untouched')
check(#keyParts()==240,'near keys: pool of 240 MeshParts at tier 3 (got '..#keyParts()..')')
local sizeOk,clsOk,scripts=true,true,0
for _,p in ipairs(keyParts())do
 if p._class~='MeshPart'then clsOk=false end
 if p.Size.X~=7.5 and p.Size.X~=47.5 then sizeOk=false end
 for _,d in ipairs(p:GetDescendants())do if d:IsA('BaseScript')then scripts+=1 end end
end
check(clsOk and sizeOk and scripts==0,'keys are clones of the R142Keycap MeshPart, scaled, scripts stripped')
check(#shown()>=230,'the pooled keys are visible (the two spacebar rows hide five each) ('..#shown()..')')
-- bed and rails
local bedParts,railParts,bedLen,railOk,bedOk={},{},0,true,true
for _,p in ipairs(bed:GetChildren())do
 if p.Name:find('^Bed')then bedParts[#bedParts+1]=p;bedLen+=p.Size.Z
  if p.Size.Z>1024+1e-6 or p.Size.X~=50 or not near(p.CFrame.Position.Y+p.Size.Y/2,F+.05)then bedOk=false end
  local c=p.Color;if math.abs(c.R*255-86)>.5 or math.abs(c.G*255-52)>.5 or math.abs(c.B*255-34)>.5 then bedOk=false end
 elseif p.Name:find('^Rail')then railParts[#railParts+1]=p
  if p.Size.X~=1.2 or p.Size.Y~=1.0 or p.Size.Z>1024+1e-6 or not(near(math.abs(p.CFrame.Position.X),25.6))then railOk=false end
  local c=p.Color;if math.abs(c.R*255-62)>.5 or math.abs(c.G*255-36)>.5 or math.abs(c.B*255-24)>.5 then railOk=false end
 end
end
check(#bedParts==6 and bedOk and near(bedLen,5952),'chocolate bed: 6 segments of <= 1024 studs, 50 wide, top at floor + 0.05 (got '..#bedParts..' segments, '..bedLen..' studs)')
check(#railParts==12 and railOk,'dark chocolate rails: 1.2 x 1.0 at x = +-25.6 in the same segments')
-- far strips
local stripCount=#strips:GetChildren();local stripOk=true
for _,p in ipairs(strips:GetChildren())do
 if p.Size.X~=47.5 or not near(p.Size.Y,.6)or p.Size.Z~=7.5 or not near(p.CFrame.Position.Y+p.Size.Y/2,F+.8)then stripOk=false end
end
check(stripOk and stripCount>=130 and stripCount<=345,'far strips: 47.5 x 0.6 x 7.5, top at rest height, built within 1100 studs ('..stripCount..')')
check(stripAt(12)~=nil and stripAt(12).Transparency==1,'a row that has keys hides its far strip')
check(stripAt(100)~=nil and stripAt(100).Transparency==0,'a row without keys shows its far strip')
local s100=stripAt(100);local rgb=K.RowStyle(100,g.RowStage[100],false).RGB
check(math.abs(s100.Color.R*255-rgb[1])<.5 and math.abs(s100.Color.G*255-rgb[2])<.5 and math.abs(s100.Color.B*255-rgb[3])<.5,'far strip colour is the row candy colour')
local sp=stripAt(79) -- Desert spacebar row (strips exist up to ~137 rows)
check(sp and math.abs(sp.Color.R*255-255)<.5 and math.abs(sp.Color.G*255-244)<.5 and math.abs(sp.Color.B*255-214)<.5,'a spacebar row strip is cream')
-- key positions and colours
local k12=keyAt(12,3)
check(k12~=nil and near(top(k12),F+C.RestRise),'a resting key top sits at floor + 0.8 (got '..tostring(k12 and top(k12))..')')
local kc=k12.Color;local er,eg,eb=K.KeyRGB(K.RowStyle(12,g.RowStage[12],false),12,3)
check(math.abs(kc.R*255-er)<.5 and math.abs(kc.G*255-eg)<.5 and math.abs(kc.B*255-eb)<.5,'key colour = candy row colour with its jitter')
-- legends
local enabled,legendOk,legendNear=0,true,true
for _,p in ipairs(keyParts())do
 local gui=p:FindFirstChildWhichIsA('SurfaceGui')
 if gui and gui.Enabled then
  enabled+=1
  local pos=p.CFrame.Position;local dz=pos.Z-(-4)
  if dz*dz>56*56+1e-6 and p.Size.X<40 then legendNear=false end
  local lab=gui:FindFirstChildWhichIsA('TextLabel',true)
  local row=math.floor((pos.Z-g.Z0)/8)+1;local col=math.floor((pos.X-g.X0)/8)+1
  local expected=p.Size.X>40 and string.upper(g.SpaceRow[row].Name)or K.Legend(row,col)
  if not lab or lab.Text~=expected then legendOk=false end
 end
end
check(enabled>=60 and enabled<=96 and legendNear,'legends only within 56 studs of the runner ('..enabled..' on)')
check(legendOk,'every lit legend shows its key letter (QWERTY / ASDFGH / ...) and the spacebar shows the biome name')
-- the first row is Forest's spacebar
local sb=nil;for _,p in ipairs(keyParts())do if p.Size.X>40 and near(p.CFrame.Position.Z,g.Z0+.5*8,.01)then sb=p end end
check(sb~=nil and sb.Transparency==0 and near(sb.CFrame.Position.X,0)and math.abs(sb.Color.R*255-255)<=255*.061+1,'row 1 is one cream spacebar key 47.5 wide, centred')
put(-4,F+9,-80);frames(12)
local sbGui=sb and sb:FindFirstChildWhichIsA('SurfaceGui');local sbLabel=sbGui and sbGui:FindFirstChildWhichIsA('TextLabel',true)
check(sbGui and sbGui.Enabled and sbLabel and sbLabel.Text=='FOREST','the Forest spacebar is labelled FOREST (its legend lights up when the runner is near)')
put(-4,F+9,-4);frames(12)
local hiddenSibling=0;for _,p in ipairs(keyParts())do if near(p.CFrame.Position.Z,g.Z0+.5*8,.01)and p.Transparency==1 and p.CFrame.Position.Y>0 then hiddenSibling+=1 end end
check(hiddenSibling==5,'the other five pooled keys of a spacebar row are hidden ('..hiddenSibling..')')
check(cframeWrites==#keyParts()and bulkCalls>0,'keys are positioned with BulkMoveTo only (one parking write each: '..cframeWrites..' CFrame writes on '..#keyParts()..' keys)')
local routed=0;for _,o in ipairs(R.created)do if o._class=='Sound'and o.SoundGroup~=nil then routed+=1 end end
check(routed==10,'ten pooled click Sounds, routed through AudioMixer (Effects group) ('..routed..')')
local clickIds={};for _,o in ipairs(R.created)do if o._class=='Sound'and o._props.Name=='KeyClickSound'then clickIds[o.SoundId]=true end end
check(clickIds['rbxassetid://113108830240353']and clickIds['rbxassetid://88838553648526']and clickIds['rbxassetid://96591611478915'],'the pool uses the three click recordings')
check(contentCalls>=1,'the click sounds are preloaded')

-- 2. a runner presses a key and releases it
local function topOf(row,col)local p=keyAt(row,col);return p and top(p)end
plays={};hum.FloorMaterial=PLASTIC;put(-4,nil,-4);frames(3)
check(topOf(12,3)and topOf(12,3)<F+C.RestRise-.1,'a key goes down under the runner (mid-press)')
frames(8)
check(near(topOf(12,3),F+C.PressedRise,1e-6),'...to the pressed height (top = floor + 0.15, got '..tostring(topOf(12,3))..')')
check(near(topOf(12,4),F+C.RestRise,1e-6)and near(topOf(13,3),F+C.RestRise,1e-6)and near(topOf(11,3),F+C.RestRise,1e-6),'its neighbours stay up')
check(#plays==1 and plays[1].Id:find('rbxassetid://')and(clickIds[plays[1].Id]),'one click played for the one key ('..#plays..')')
check(plays[1]and plays[1].Speed>=.96 and plays[1].Speed<=1.06,'own click pitch within 0.96 .. 1.06')
check(plays[1]and plays[1].Group and plays[1].Group.Name=='GardenEffects','clicks go through the Effects sound group (AudioMixer.Route)')
check(plays[1]and near(plays[1].Pos.X,-4,.01)and near(plays[1].Pos.Z,g.Z0+11.5*8,.01),'the click is played at the key')
put(60,nil,-4);frames(12)
check(near(topOf(12,3),F+C.RestRise,1e-6),'the key comes back up when the runner leaves')
local Mixer=W.module('AudioMixer');Mixer.Set('Effects',0);plays={}
put(-4,nil,-4+8*30);frames(12);put(60,nil,-4);frames(12)
check(#plays==0 and near(topOf(42,3)or F+C.RestRise,F+C.RestRise,1e-6),'Effects volume 0 (Settings): the keys still move but nothing is played')
Mixer.Set('Effects',100);plays={}
put(-4,nil,-4);frames(12);put(60,nil,-4);frames(12)
check(#plays==1,'...and clicks are back with the volume')
plays={}
put(0,nil,0);frames(12)
check(near(topOf(12,4),F+C.PressedRise,1e-6)and near(topOf(12,3),F+C.PressedRise,1e-6)and near(topOf(13,4),F+C.PressedRise,1e-6)and near(topOf(13,3),F+C.PressedRise,1e-6),'standing on a key corner (0,0) presses the 4 keys under the +-1.6 footprint')
check(#plays==4,'one click per newly pressed key (got '..#plays..')')
-- releasing: track the heights over a release to see the back-out bounce
put(60,nil,0);local maxTop=0;local minTop=99
for _=1,15 do frames(1);local t=topOf(12,4);if t then maxTop=math.max(maxTop,t);minTop=math.min(minTop,t)end end
check(maxTop>F+C.RestRise+.01,'release springs a little past rest (back-out, max '..string.format('%.3f',maxTop)..')')
check(near(topOf(12,4),F+C.RestRise,1e-6),'...and settles at rest')
-- jumping releases; landing presses again
put(-4,nil,-4);frames(10);check(near(topOf(12,3),F+C.PressedRise,1e-6),'back on a key: pressed')
hum.FloorMaterial=AIR;put(-4,F+7,-4);frames(12)
check(near(topOf(12,3),F+C.RestRise,1e-6),'in the air the key is up (FloorMaterial == Air)')
hum.FloorMaterial=PLASTIC;put(-4,nil,-4);frames(10)
check(near(topOf(12,3),F+C.PressedRise,1e-6),'landing presses it again')
hum.Health=0;frames(12);check(near(topOf(12,3),F+C.RestRise,1e-6),'a dead character presses nothing');hum.Health=100
-- 3. reduced motion
W.Gui.ReducedMotionEnabled=true
put(-4,nil,-4+8*5);frames(1)
check(near(topOf(17,3),F+C.PressedRise,1e-6),'reduced motion: the key is pressed at once')
put(-4,nil,-4);local overshoot=false;local firstUp=nil
for i=1,3 do frames(1);local t=topOf(17,3);if i==1 then firstUp=t end;if t and t>F+C.RestRise+1e-6 then overshoot=true end end
check(near(firstUp,F+C.RestRise,1e-6)and not overshoot,'reduced motion: released at once, no bounce')
W.Gui.ReducedMotionEnabled=false
frames(5)
-- 4. sprinting: clicks are rate limited, reassignments are bounded
hum.FloorMaterial=PLASTIC;plays={};colorWrites=0;bulkMax=0
local worstColor,worstStrips=0,0;local z=-4
for f=1,120 do
 z+=400/60;put(-4,nil,z)
 local before=colorWrites;local createdN=#R.created
 frames(1)
 worstColor=math.max(worstColor,colorWrites-before)
 local made=0;for i=createdN+1,#R.created do if R.created[i]._props.Name=='Strip'then made+=1 end end
 worstStrips=math.max(worstStrips,made)
end
local worstWindow=0
for i,p in ipairs(plays)do local c=0;for _,q in ipairs(plays)do if q.T>p.T-1 and q.T<=p.T then c+=1 end end;worstWindow=math.max(worstWindow,c)end
check(#plays>=20 and worstWindow<=12,'sprinting at 400 studs/s: clicks are limited to 12 per second ('..#plays..' clicks, worst 1 s window '..worstWindow..')')
local pitchSet={};for _,p in ipairs(plays)do pitchSet[p.Speed]=true end;local distinct=0;for _ in pairs(pitchSet)do distinct+=1 end
check(distinct>=4,'own click pitch varies between steps ('..distinct..' different pitches)')
check(worstColor<=64,'at most 64 key reassignments per frame (worst '..worstColor..')')
check(worstStrips<=16,'at most 16 strip creates per frame (worst '..worstStrips..')')
check(#keyParts()<=240,'never more than 240 near MeshParts')
frames(20)
local rowNow=math.floor((z-g.Z0)/8)+1
check(stripAt(rowNow)~=nil and stripAt(rowNow).Transparency==1,'the far strip under the keys the runner has reached is hidden')
check(stripAt(12)~=nil and stripAt(12).Transparency==0,'a row the runner left behind shows its far strip again')
check(keyAt(math.floor((z-g.Z0)/8)+1,3)~=nil,'the keys keep up with the sprint (window follows the runner)')
-- 5. a trip of 1000+ studs and back: nothing leaks
put(-4,nil,-4);frames(60)
local peakCount=0
local function trip()
 for _,zz in ipairs({600,1500,2600,4000,5500,5800,3000,1000,-4})do
  put(-4,nil,zz);frames(70);peakCount=math.max(peakCount,#allDescendants())
  hum.FloorMaterial=PLASTIC
 end
 frames(60)
end
-- teleport: all keys must be reassigned, 64 per frame at most
plays={};put(-4,nil,2500);colorWrites=0;local frameWrites={}
for f=1,12 do local b=colorWrites;frames(1);frameWrites[f]=colorWrites-b end
local wmax=0;local wsum=0;for _,w in ipairs(frameWrites)do wmax=math.max(wmax,w);wsum+=w end
check(wmax<=64 and wsum>=240 and frameWrites[1]>0,'a teleport re-dresses all 240 keys at <= 64 per frame ('..table.concat(frameWrites,',')..')')
check(keyAt(math.floor((2500-g.Z0)/8)+1,3)~=nil,'after the teleport the keys are around the runner')
check(#plays==0 and near(topOf(math.floor((2500-g.Z0)/8)+1,3),F+C.PressedRise,1e-6),'a key dressed under a standing runner is down at once and silent ('..#plays..' clicks)')
put(-4,nil,-4);frames(80)
local n0=#allDescendants()
trip();local n1=#allDescendants()
trip();local n2=#allDescendants()
check(n0<=1500 and peakCount<=1500,'instance budget: <= 1500 under the keyboard folder (start '..n0..', peak '..peakCount..')')
check(n2<=n1 and n1<=n0+64,'after 1000+ stud trips and back the count does not grow (start '..n0..', after one trip '..n1..', after two '..n2..')')
check(#keyParts()<=240 and #strips:GetChildren()<=345,'pool and strips stay bounded (keys '..#keyParts()..', strips '..#strips:GetChildren()..')')
put(-4,nil,5500);frames(80)
local farOk=true;for _,p in ipairs(strips:GetChildren())do if p.CFrame.Position.Z<5500-1300-8 then farOk=false end end
check(farOk,'strips more than 1300 studs behind the camera are freed')
check(keyAt(math.floor((5500-g.Z0)/8)+1,3)~=nil,'keys near the end of the track')
put(-4,nil,5900);frames(40);check(#keyParts()<=240,'at the very end (row ends at EndZ-120) the window clamps to the last rows')
put(-4,nil,-300);frames(40)
check(keyAt(5,3)~=nil,'before the track start the window sits on the first rows')
put(-4,nil,-4);frames(80)
-- 6. other players
hum.FloorMaterial=AIR  -- isolate the others
local other=R.new('Player');other.Name='Pal';other.UserId=5;other.Parent=Players;others[1]=other
local ochar,oroot=makeCharacter('Pal',12,-4);other.Character=ochar
plays={};frames(6)
check(near(topOf(12,5),F+C.PressedRise,1e-6),'another player standing on a key presses it')
check(#plays==1 and plays[1].Speed>=.96 and plays[1].Speed<=1.06,'...with one click ('..#plays..')')
oroot.CFrame=CF(12,F+9,-4);frames(10)
check(near(topOf(12,5),F+C.RestRise,1e-6),'jumping high (feet more than 3 studs up) releases it')
oroot.CFrame=CF(12,F+5.5,-4);frames(10)
check(near(topOf(12,5),F+C.PressedRise,1e-6),'feet within about 3 studs of the floor still press')
oroot.CFrame=CF(70,F+3,-4);frames(10)
check(near(topOf(12,5),F+C.RestRise,1e-6),'walking off the keyboard releases')
-- rate limit for others: one player running by plus many standing
plays={}
for i=1,12 do local pl=R.new('Player');pl.Name='P'..i;pl.UserId=100+i;pl.Parent=Players;others[#others+1]=pl;local _,r2=makeCharacter('P'..i,-20+(i%6)*8+4,-3);pl.Character=r2.Parent end
frames(4)
local runnerZ=0
for f=1,120 do
 for i=2,13 do local pr=others[i].Character.HumanoidRootPart;pr.CFrame=CF(-20+(i%6)*8+4,F+3,runnerZ+(i%3)*8)end
 put(-4,F+9,runnerZ-20) -- the local runner (in the air) keeps pace, so the others stay in earshot
 runnerZ+=400/60;frames(1)
end
local worstOther=0
for i,p in ipairs(plays)do local c=0;for _,q in ipairs(plays)do if q.T>p.T-1 and q.T<=p.T then c+=1 end end;worstOther=math.max(worstOther,c)end
check(#plays>=10 and worstOther<=8,'12 players running by: at most 8 clicks per second from others ('..#plays..' clicks, worst '..worstOther..')')
-- far away players (beyond 90 studs of the runner) are silent
plays={};local far=others[2].Character.HumanoidRootPart;for i=3,13 do others[i].Character.HumanoidRootPart.CFrame=CF(70,F+3,0)end
put(-4,F+3,-4);hum.FloorMaterial=AIR
far.CFrame=CF(-4,F+3,200);frames(10);local sentFar=#plays
check(sentFar==0,'other players more than 90 studs away are silent ('..sentFar..')')
for i=#others,1,-1 do others[i]=nil end
frames(12)
-- 7. keepers
local keeper=R.new('Model');keeper.Name='ForestKeeper';keeper:SetAttribute('PersistentBiomeGuardian',true)
local kroot=R.new('Part');kroot.Name='HumanoidRootPart';kroot.Size=V3(6,10,6);kroot.CFrame=CF(-12,F+5,100);kroot.Parent=keeper;keeper.PrimaryPart=kroot
keeper.Parent=camps;W.CS:AddTag(keeper,'BiomeKeeper')
put(-4,F+9,60);plays={};frames(12)
local krow=math.floor((100-g.Z0)/8)+1
local ek=K.KeeperFootprint(6,6)
check(near(ek,1.8)and near(topOf(krow,2),F+C.PressedRise,1e-6),'a keeper presses the keys under its feet (footprint '..ek..')')
check(#plays>=1 and near(plays[1].Speed,.7),'keeper clicks are pitched down to 0.7')
kroot.CFrame=CF(70,F+5,100);frames(12)
check(near(topOf(krow,2),F+C.RestRise,1e-6)and near(topOf(krow,3),F+C.RestRise,1e-6),'the keys come back up when the keeper walks away')
-- a flying keeper (feet far above the floor) presses nothing
kroot.CFrame=CF(-12,F+40,100);frames(12);check(near(topOf(krow,2),F+C.RestRise,1e-6),'a keeper high in the air presses nothing')
-- dashing keeper: the rendered dash frame, not the (server) PrimaryPart
kroot.CFrame=CF(70,F+5,100)
keeper:SetAttribute('GuardianBehavior','DASHING');keeper:SetAttribute('GuardianLeaseToken',7);keeper:SetAttribute('KeeperDashToken',7)
keeper:SetAttribute('KeeperDashFrom',CF(-12,F+5,100));keeper:SetAttribute('KeeperDashTo',V3(12,F+5,100));keeper:SetAttribute('KeeperDashAt',R.clock);keeper:SetAttribute('KeeperDashDuration',.2)
frames(6) -- 0.1 s: halfway -> x about 0
local mid=false;for col=1,6 do if topOf(krow,col)and topOf(krow,col)<F+C.RestRise-.05 then mid=true end end
check(mid,'a dashing keeper presses where its dash is drawn (KeeperRecoveryDash.VisualFrame)')
keeper:SetAttribute('GuardianBehavior','GUARDING');frames(15)
-- event keeper (VeiledKeeper81) and an untagged guardian found by the scan
local veiled=R.new('Model');veiled.Name='Veiled';veiled:SetAttribute('VeiledKeeper81',true)
local vroot=R.new('Part');vroot.Name='HumanoidRootPart';vroot.Size=V3(8,12,8);vroot.CFrame=CF(20,F+6,60);vroot.Parent=veiled;veiled.PrimaryPart=vroot;veiled.Parent=runtime
frames(130)
local vrow=math.floor((60-g.Z0)/8)+1
check(near(topOf(vrow,6),F+C.PressedRise,1e-6),'the event keeper (VeiledKeeper81 in _GameplayRuntime) presses keys (found by the scan)')
veiled:Destroy();frames(15)
check(near(topOf(vrow,6),F+C.RestRise,1e-6),'a destroyed keeper lets go')
-- 8. shovel holes
local holes=R.new('Folder');holes.Name='TrackHoles';holes.Parent=runtime
local function dig(id,x,z)
 local m=R.new('Model');m.Name='TrackHole_'..id
 local pit=R.new('Part');pit.Name='Pit';pit.Size=V3(.08,3.4,3.4);pit.CFrame=CF(x,F+.04,z);pit.Parent=m
 local rim=R.new('Part');rim.Name='Rim';rim.Size=V3(.06,4,4);rim.CFrame=CF(x,F+.03,z);rim.Parent=m
 m.PrimaryPart=pit;m.Parent=holes;return m
end
put(60,nil,0);hum.FloorMaterial=PLASTIC;frames(10)
local hz=g.Z0+19.5*8   -- row 20 centre
check(keyAt(20,4)~=nil,'(row 20 col 4 is shown before the hole)')
local h1=dig(1,4,hz);frames(30)
check(keyAt(20,4)==nil and keyAt(20,3)~=nil and keyAt(20,5)~=nil and keyAt(19,4)~=nil,'a hole in the middle of a key hides that key only')
local h2=dig(2,0,g.Z0+19*8);frames(30) -- x 0 on a column line, z on a row line: 4 keys
check(keyAt(19,3)==nil and keyAt(19,4)==nil and keyAt(20,3)==nil and keyAt(20,4)==nil,'a hole on a corner hides the 4 keys within 2 studs')
check(keyAt(18,3)~=nil and keyAt(21,4)~=nil and keyAt(19,2)~=nil and keyAt(20,5)~=nil,'...and no others')
put(4,nil,hz);frames(10);check(keyAt(20,4)==nil,'standing over a hidden key presses nothing (it stays hidden)')
put(60,nil,0);frames(5)
h1:Destroy();h2:Destroy();frames(30)
check(keyAt(20,4)~=nil and keyAt(19,3)~=nil and near(topOf(20,4),F+C.RestRise,1e-6),'the keys come back at rest when the holes are filled')
check(holes:GetChildren()[1]==nil,'(holes gone)')
-- holes under far strips never touch real parts
check(floor.Transparency==0,'the real floor is still untouched')
-- 9. tiers
player:SetAttribute('FastMode',true);frames(45)
check(#shown()<=20*6 and #shown()>=60,'FastMode: a smaller near window (20 rows = '..#shown()..' keys)')
player:SetAttribute('FastMode',false);frames(60)
check(#shown()>=200 and #keyParts()<=240,'back to the full window (240 keys)')
-- 10. spacebar rows: one big key
put(-4,nil,g.Z0+22.5*8);hum.FloorMaterial=PLASTIC;frames(40)
local jungle=nil;for _,p in ipairs(keyParts())do if p.Size.X>40 and near(p.CFrame.Position.Z,g.Z0+22.5*8,.01)then jungle=p end end
check(jungle~=nil and jungle.Transparency==0,'the Jungle spacebar is in the window')
local jl=jungle and jungle:FindFirstChildWhichIsA('SurfaceGui'):FindFirstChildWhichIsA('TextLabel',true)
check(jl and jl.Text=='JUNGLE','... labelled JUNGLE')
put(16,nil,g.Z0+22.5*8);frames(10)
check(near(top(jungle),F+C.PressedRise,1e-6),'stepping anywhere on a spacebar presses the whole bar')
put(60,nil,g.Z0+22.5*8);frames(15);check(near(top(jungle),F+C.RestRise,1e-6),'...and it comes back up')
local ringOk=true;for _,p in ipairs(keyParts())do if p.Transparency==0 and p.Size.X>40 and not near(p.CFrame.Position.X,0)then ringOk=false end end
check(ringOk,'spacebar keys are centred on the track')
-- 11. teardown
sc.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'the folder goes with the script')
local before=#R.created;frames(30);check(#R.created==before,'nothing runs after the script is destroyed')
check(nonRemote(),'still no RemoteEvent / RemoteFunction anywhere')
-- 12. no template: plain blocks, still works
template.Parent=nil
RS:FindFirstChild('RunnerMotion'):SetAttribute('TrackCenterX',12)
local sc2=R.new('LocalScript');sc2.Name='KeyboardTrack'
check(pcall(W.load,'KeyboardTrackClient',sc2),'loads without the R142Keycap template')
put(-4,nil,-4);hum.FloorMaterial=PLASTIC;frames(40)
local vis2=workspace:FindFirstChild('KeyboardTrackVisuals');local k2=vis2 and vis2:FindFirstChild('Keys')
check(k2 and #k2:GetChildren()==240 and k2:GetChildren()[1]._class=='Part','without the template the near keys are plain blocks')
local fallbackLegend=false;for _,p in ipairs(k2:GetChildren())do local gui=p:FindFirstChildWhichIsA('SurfaceGui');if gui and gui.Enabled then local l=gui:FindFirstChildWhichIsA('TextLabel',true);if l and l.Text~=''then fallbackLegend=true end end end
check(fallbackLegend,'...with their own legends')
local shifted=false;for _,p in ipairs(k2:GetChildren())do if p.Transparency==0 and near(p.CFrame.Position.X,-8,.01)then shifted=true end end
local bed2=vis2:FindFirstChild('Bed'):FindFirstChild('Bed1')
check(shifted and bed2 and near(bed2.CFrame.Position.X,12),'the columns and the bed are centred on RunnerMotion.TrackCenterX (12)')
RS:FindFirstChild('RunnerMotion'):SetAttribute('TrackCenterX',nil)
sc2.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'teardown again')
-- 13. a map that describes only its first biome: built after a short wait, with one spacebar
template.Parent=RS
for n=2,7 do map:SetAttribute('BiomeStartZ_'..n,nil);map:SetAttribute('BiomeEndZ_'..n,nil)end
local sc3=R.new('LocalScript');sc3.Name='KeyboardTrack'
check(pcall(W.load,'KeyboardTrackClient',sc3),'loads on a partly described map')
frames(60);check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'...it waits for the other biomes (1 s so far)')
R.advance(2);frames(40)
local vis3=workspace:FindFirstChild('KeyboardTrackVisuals')
check(vis3~=nil and #vis3:FindFirstChild('Keys'):GetChildren()==240,'...and builds after the wait with what the map has')
local wides=0;for _,p in ipairs(vis3:FindFirstChild('Keys'):GetChildren())do if p.Size.X>40 and p.Transparency==0 then wides+=1 end end
check(wides==1,'a one-biome map has one spacebar in view ('..wides..')')
sc3.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'and tears down')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
