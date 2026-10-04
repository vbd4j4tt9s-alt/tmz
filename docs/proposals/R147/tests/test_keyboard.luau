--!nocheck
-- R148: the candy keyboard runway (this file kept its R147 name). Part 1: ReplicatedStorage.KeyboardTrack (pure grid, zones, hierarchy,
-- LOD windows). Part 2: the real StarterPlayerScripts/KeyboardTrack.client.lua on the mock world (client only, no remotes).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS;local workspace=W.workspace
local function frames(n,dt)W.frames(n,dt)end
local floor=math.floor

-- ======================================================================================================================
-- Part 1: KeyboardTrack.lua
-- ======================================================================================================================
local K=W.module('KeyboardTrack');local C=K.Config
local ATTR={BiomeTrackEndZ=5980,BiomeStartZ_1=-100,BiomeEndZ_1=80,BiomeStartZ_6=80,BiomeEndZ_6=530,BiomeStartZ_2=530,BiomeEndZ_2=1180,
 BiomeStartZ_3=1180,BiomeEndZ_3=2030,BiomeStartZ_4=2030,BiomeEndZ_4=3080,BiomeStartZ_5=3080,BiomeEndZ_5=4380,BiomeStartZ_7=4380,BiomeEndZ_7=5980}
local F=C.FloorTop
check(C.Pitch==3 and C.FieldWidth==180 and C.Gap==.28 and C.SpaceRows==3,'config: pitch 3 (60 columns on the 180 floor, about 1.3 x a character torso per key), gap .28, spacebar 3 rows deep')
check(near(F+C.RestRise,4.45)and near(F+C.PressedRise,4.1)and C.PressSeconds==.06 and C.ReleaseSeconds==.14 and C.KeyY==1.3,'config: floor 4.0, rest top +0.45, pressed top +0.10, press .06 s, release .14 s')
check(C.BedRise>=.08 and C.BedRise<=.15 and C.BedColor[1]<=60,'config: the dark bed sits at least 0.08 above the floor (no z-fighting), dark chocolate')
check(C.OwnClicksPerSecond==12 and C.OtherClicksPerSecond==8 and C.OtherClickRange==90 and C.KeeperPitch==.7 and #C.ClickSoundIds==3 and C.ClickSoundIds[1]==113108830240353 and C.ClickSoundIds[2]==88838553648526 and C.ClickSoundIds[3]==96591611478915,'config: click ids, 12/s own, 8/s others within 90, keepers pitch 0.7')
local pitchOk=#C.ClickPitches>=3;for _,p in ipairs(C.ClickPitches)do if p<.96 or p>1.06 then pitchOk=false end end
check(pitchOk,'own click pitches stay within 0.96 .. 1.06')
check(K.Tier(3).Mesh==700 and K.Tier(3).Legends==150 and K.Tier(3).Plain==2500 and K.Tier(2).Mesh==450 and K.Tier(2).Legends==100 and K.Tier(2).Plain==1500 and K.Tier(1).Mesh==250 and K.Tier(1).Legends==60 and K.Tier(1).Plain==800,'tier caps: meshes 700/450/250, legends 150/100/60, plain keys 2500/1500/800')

local g=K.Geometry(ATTR,0)
local function dist2(a,b)return (a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2 end
do
check(g.Pitch==3 and g.Cols==60 and g.HalfWidth==90 and g.Z0==-100 and g.KeyEndZ==5860,'geometry: 60 columns across x -90..90, rows from -100 (the first biome start) to EndZ-120 = 5860')
check(g.Rows==1986 and #g.Segs==7,'geometry: 1986 rows in 7 biome grids (got '..g.Rows..')')
check(K.Geometry(ATTR).Rows==1986 and K.Geometry({BiomeTrackEndZ=1445},0).Rows>=1,'geometry is deterministic')
local wantSegRows={60,150,217,283,350,433,493};local wantIds={1,6,2,3,4,5,7};local rowsOk=true
for i,s in ipairs(g.Segs)do if s.Rows~=wantSegRows[i]or s.Id~=wantIds[i]then rowsOk=false end end
check(rowsOk,'biome grids: Forest 60, Jungle 150, Desert 217, Snow 283, Lava 350, Crystal 433, Storm Peaks 493 rows')
local startOk,pitchBand=true,true
for _,s in ipairs(g.Segs)do
 local z0=g.RowZ(s.FirstRow)
 if not near(z0,s.StartZ,1e-6)then startOk=false end
 if s.RowPitch<2.98 or s.RowPitch>3.02 then pitchBand=false end
 local z2=select(2,g.RowZ(s.LastRow));if not near(z2,s.EndZ,1e-6)then startOk=false end
end
check(startOk,'every biome grid starts exactly on its BiomeStartZ_n (rows tile the biome with no remainder)')
check(pitchBand and near(select(2,g.RowZ(g.Rows)),5860,1e-6),'row pitch of every biome is about 3 (2.98 .. 3.02) and the last row ends at 5860')
check(g.ColCenter(1)==88.5 and g.ColCenter(60)==-88.5 and g.ColCenter(1)>g.ColCenter(2),'column 1 is the +X edge (a heading-+Z runner reads columns left -> right)')
check(g.ColOfX(88.5)==1 and g.ColOfX(-88.5)==60 and g.ColOfX(0.01)==30 and g.ColOfX(-0.01)==31,'ColOfX is the inverse of ColCenter')
local x1,z1c=g.CellCenter(1,1);local x6,z6=g.CellCenter(g.Rows,60)
check(x1==88.5 and near(z1c,-100+1.5)and x6==-88.5 and near(z6,5860-g.Segs[7].RowPitch/2),'CellCenter: (1,1) = (88.5, first row), last cell at the track end')
local gShift=K.Geometry(ATTR,12);check(near(gShift.ColCenter(1),100.5)and near(gShift.ColCenter(60),-76.5),'columns follow TrackCenterX')
check(K.Geometry(ATTR,0,210).Cols==70,'the floor width comes from FieldWidth when given (210 -> 70 columns)')
-- cells in a rect (edges)
local function ids(list)local t={};for _,c in ipairs(list)do t[#t+1]=c.row..':'..c.col end;table.sort(t);return table.concat(t,',')end
local zr3a,zr3b=g.RowZ(5)
check(ids(g.CellsInRect(0,3,zr3a,zr3b))=='5:30','CellsInRect: a rect that exactly fills one cell is that cell only (got '..ids(g.CellsInRect(0,3,zr3a,zr3b))..')')
check(ids(g.CellsInRect(-1.2,1.2,zr3b-1.2,zr3b+1.2))=='5:30,5:31,6:30,6:31','CellsInRect: a footprint on a cell corner claims 4 cells')
check(ids(g.CellsInRect(0,0,zr3a+1,zr3a+1))=='5:31','CellsInRect: a point on a column line belongs to the cell on its -X side (col 31 spans -3 .. 0, col 30 spans 0 .. 3)')
check(#g.CellsInRect(90.5,100,0,10)==0 and #g.CellsInRect(-100,-90.5,0,10)==0,'CellsInRect: outside the floor in x is empty')
check(#g.CellsInRect(-5,5,-120,-100)==0 and #g.CellsInRect(-5,5,5860,5900)==0,'CellsInRect: touching or beyond the first / last row edge is empty')
check(ids(g.CellsInRect(-1,1,5858,5859.5))=='1986:30,1986:31','CellsInRect: the last row is reachable')
check(#g.CellsInRect(-1000,1000,-1000,9000)==60*1986,'CellsInRect: a huge rect clamps to the 60 x 1986 grid')
check(#g.CellsInRect(5,-5,10,-10)==#g.CellsInRect(-5,5,-10,10),'CellsInRect: reversed bounds are accepted')
local c1,c2,r1,r2=g.CellRange(-1.2,1.2,zr3b-1.2,zr3b+1.2);check(c1==30 and c2==31 and r1==5 and r2==6,'CellRange: the allocation-free form agrees')
local nan=0/0;local e1,e2=g.CellRange(nan,1,0,1);check(e1>e2,'CellRange: NaN gives an empty range')
check(g.RowOfZ(-100.1)==0 and g.RowOfZ(-100)==1 and g.RowOfZ(5860)==1987 and g.RowOfZ(79.99)==60 and g.RowOfZ(80)==61,'RowOfZ: biome grids join exactly (row 61 starts at z 80)')
-- biomes and spacebars
local want={{1,'Forest',1,60},{6,'Jungle',61,210},{2,'Desert',211,427},{3,'Snow',428,710},{4,'Lava',711,1060},{5,'Crystal',1061,1493},{7,'Storm Peaks',1494,1986}}
for i,w in ipairs(want)do
 local s=g.Segs[i];local bar=g.Bars[i]
 check(s and s.Id==w[1]and s.Name==w[2]and s.FirstRow==w[3]and s.LastRow==w[4],'biome '..w[2]..' rows '..w[3]..'-'..w[4]..' (got '..tostring(s and s.FirstRow)..'-'..tostring(s and s.LastRow)..')')
 check(bar and bar.Name==w[2]and bar.Row0==w[3]and bar.Row1==w[3]+2 and near(bar.Z0,s.StartZ)and near(bar.Z1-bar.Z0,3*s.RowPitch),'one spacebar at the start of '..w[2]..' (its first three rows, from its BiomeStartZ)')
 check(g.BarOfRow[w[3]]==i and g.BarOfRow[w[3]+2]==i and g.BarOfRow[w[3]+3]==nil and g.RowStage[w[3]]==w[1]and g.RowStage[w[4]]==w[1],'rows of '..w[2]..' belong to stage '..w[1])
end
local id,name=K.BiomeAt(-100,ATTR);check(id==1 and name=='Forest','BiomeAt: the start of the track is Forest')
id,name=K.BiomeAt(80,ATTR);check(id==6 and name=='Jungle','BiomeAt: 80 is Jungle (stage ids are not track order)')
id=K.BiomeAt(5980,ATTR);check(id==0 and K.BiomeAt(-101,ATTR)==0 and K.BiomeAt(10,nil)==0,'BiomeAt: outside the biomes is 0')
local named=table.clone(ATTR);named.BiomeName_6='Rainforest';id,name=K.BiomeAt(100,named);check(name=='Rainforest','BiomeAt: BiomeName_n attribute overrides the name')
check(K.Geometry(named,0).Bars[2].Name=='Rainforest','the spacebar uses the BiomeName_n attribute too')
-- zones: colour families, four shades, hashed per cell
local zoneOk=true
for _,stage in ipairs({1,2,3,4,5,6,7})do local z=K.Zone(stage);if not z or #z.Shades~=4 or not z.Family or not z.Ink then zoneOk=false end end
check(zoneOk,'seven zones, four shades each, a family name and a legend ink')
check(K.Zone(1).Family=='mint'and K.Zone(6).Family=='pistachio'and K.Zone(2).Family=='caramel'and K.Zone(3).Family=='vanilla'and K.Zone(4).Family=='strawberry'and K.Zone(5).Family=='pink-purple'and K.Zone(7).Family=='chocolate','zones: Forest mint, Jungle pistachio, Desert caramel, Snow vanilla, Lava strawberry, Crystal pink/purple, Storm chocolate')
local allShades,jitterOk=true,true
for _,stage in ipairs({1,2,3,4,5,6,7})do
 local z=K.Zone(stage);local used={}
 for r=1,60 do for c=1,60 do
  local rr,gg,bb=K.CellRGB(stage,r,c,1);local best,bi=1e9,0
  for i,sh in ipairs(z.Shades)do local d=dist2({rr,gg,bb},sh);if d<best then best,bi=d,i end end
  used[bi]=(used[bi]or 0)+1
  local sh=z.Shades[K.ShadeIndex(stage,r,c,1)]
  if math.abs(rr-sh[1])>sh[1]*.045+1 or math.abs(gg-sh[2])>sh[2]*.045+1 or math.abs(bb-sh[3])>sh[3]*.045+1 then jitterOk=false end
 end end
 for i=1,4 do if(used[i]or 0)<3600*.15 or(used[i]or 0)>3600*.40 then allShades=false end end
end
check(jitterOk,'a key colour is its zone shade within +-4%')
check(allShades,'all four shades of a zone are used, each by roughly a quarter of the keys')
local bandOk,singleOk=true,true
for _,stage in ipairs({1,2,3,4,5,6,7})do
 local rowSum,rowSq,keySum,keySq,keyN=0,0,0,0,0
 for r=1,120 do
  local seen={};local sum=0
  for c=1,60 do local rr,gg,bb=K.CellRGB(stage,r,c,1);local l=rr+gg+bb;sum+=l;keySum+=l;keySq+=l*l;keyN+=1;seen[K.ShadeIndex(stage,r,c,1)]=true end
  local kinds=0;for _ in pairs(seen)do kinds+=1 end;if kinds<3 then singleOk=false end
  rowSum+=sum/60;rowSq+=(sum/60)^2
 end
 local keyStd=math.sqrt(keySq/keyN-(keySum/keyN)^2);local rowStd=math.sqrt(math.max(0,rowSq/120-(rowSum/120)^2))
 if rowStd>keyStd*.3 then bandOk=false end
end
check(singleOk,'no row is one colour: every row of every zone mixes at least 3 of the 4 shades')
check(bandOk,'no rainbow bands: row-to-row differences of the mean colour are small next to the key-to-key spread in every zone (std ratio <= 0.3)')
check(K.CellRGB(1,5,7,1)==K.CellRGB(1,5,7,1)and K.Jitter(5,7,1)==K.Jitter(5,7,1)and K.ShadeIndex(3,100,33,2)==K.ShadeIndex(3,100,33,2),'colours are deterministic (no randomness)')
local jmin,jmax=2,0;for r=1,200 do for c=1,60 do local j=K.Jitter(r,c,1);jmin=math.min(jmin,j);jmax=math.max(jmax,j)end end
check(jmin>=.96-1e-9 and jmax<=1.04+1e-9 and jmax-jmin>.05,'brightness jitter stays within +-4% and really varies')
local lightInk=K.Zone(7).Ink;check(lightInk[1]>200 and K.Zone(1).Ink[1]<100,'legend ink: cream on the dark chocolate zone, dark on the light zones')
-- legends read left -> right in keyboard order (columns ascend toward the runner's right)
local function legendRow(row)local t={};for c=1,60 do t[#t+1]=K.Legend(row,c)end;return table.concat(t)end
check(K.Legend(1,1)=='Q' and legendRow(1):sub(1,10)=='QWERTYUIOP' and legendRow(2):sub(1,9)=='ASDFGHJKL' and legendRow(3):sub(1,7)=='ZXCVBNM' and legendRow(4):sub(1,10)=='1234567890','legends read QWERTYUIOP / ASDFGHJKL / ZXCVBNM / 1234567890 from column 1 on')
check(legendRow(1):sub(11,20)=='QWERTYUIOP' and legendRow(5):sub(1,3)=='RTY' and legendRow(5)~=legendRow(1),'a keyboard row repeats across the 60 columns; every four rows the start drifts')
local seqOk=true
for r=1,200 do
 local line=K.LegendRows[(r-1)%4+1];local s=legendRow(r)
 if not line:rep(20):find(s,1,true)then seqOk=false end
end
check(seqOk,'every row of every biome reads as a contiguous stretch of its keyboard row, left -> right')
-- easing and heights
check(K.Ease.QuadOut(0)==0 and K.Ease.QuadOut(1)==1 and K.Ease.QuadOut(.5)==.75 and K.Ease.Linear(.3)==.3,'ease: quad-out and linear')
local peak=0;for i=0,100 do peak=math.max(peak,K.Ease.BackOut(i/100))end
check(near(K.Ease.BackOut(0),0)and near(K.Ease.BackOut(1),1)and peak>1.05 and peak<1.2,'ease: back-out overshoots a little and settles at 1 (peak '..string.format('%.3f',peak)..')')
check(near(K.KeyTop(0),4.45)and near(K.KeyTop(1),4.1)and near(K.KeyCenterY(0),4.45-1.3/2)and near(K.BlockCenterY(),4.45-.3),'key heights: rest top 4.45, pressed top 4.10')
check(K.KeeperFootprint(2,2)==1.5 and K.KeeperFootprint(10,12)==3 and K.KeeperFootprint(60,80)==6,'keeper footprint = clamp(0.3 * min extent, 1.5, 6)')
local segs=K.Segments(g.Z0,g.KeyEndZ,1024);local contiguous=true;local total=0
for i,s in ipairs(segs)do total+=s.Length;if s.Length>1024+1e-9 or(i>1 and not near(s.Z0,segs[i-1].Z1))then contiguous=false end end
check(#segs==6 and contiguous and near(total,5960)and near(segs[1].Z0,-100),'bed segments: 6 contiguous pieces of at most 1024 studs covering the whole key area')
local sums=K.Segments(0,10,1024);check(#sums==1 and near(sums[1].Length,10),'a short bed is one piece')
local lim=K.NewLimiter(3);local allowed=0;for i=0,29 do if K.Allow(lim,i*.05)then allowed+=1 end end
check(allowed<=3*2+1 and allowed>=5,'limiter: at most 3 per second over 1.5 s ('..allowed..')')
local lim2=K.NewLimiter(12);local stamps={};for i=0,599 do local t=i/60;if K.Allow(lim2,t)then stamps[#stamps+1]=t end end
local worst=0;for i,t in ipairs(stamps)do local c=0;for _,u in ipairs(stamps)do if u>t-1 and u<=t then c+=1 end end;worst=math.max(worst,c)end
check(worst<=12 and #stamps>=100,'limiter: 12 per second at 60 Hz ('..#stamps..' in 10 s, worst window '..worst..')')

-- hierarchy: groups of 1, 2, 4, 8 key rows per biome, nested
local H=K.Hierarchy(g)
local partOk,nestOk,segOk=true,true,true
local keyRows=0;for _,s in ipairs(g.Segs)do keyRows+=s.LastRow-s.KeyFirst+1 end
for _,m in ipairs(H.Levels)do
 local lv=H[m];local covered=0;local prev=0
 for i=1,lv.Count do
  local a,b=lv.R0[i],lv.R1[i]
  if b-a+1>m or b<a or a<=prev then partOk=false end
  if g.RowSeg[a]~=g.RowSeg[b]or g.BarOfRow[a]or g.BarOfRow[b]then segOk=false end
  covered+=b-a+1;prev=b
  for r=a,b do if H.Ord[m][r]~=i then partOk=false end end
 end
 if covered~=keyRows then partOk=false end
end
check(H[1].Count==1965 and H[2].Count==984 and H[4].Count==494 and H[8].Count==249 and H[16].Count==126,'hierarchy: 1965 / 984 / 494 / 249 / 126 groups of 1 / 2 / 4 / 8 / 16 key rows')
check(partOk,'every level partitions the key rows exactly once, in track order')
check(segOk,'no group crosses a biome boundary or contains a spacebar row')
for _,m in ipairs({2,4,8,16})do
 local lv,fine=H[m],H[m//2]
 for i=1,lv.Count do
  local o0,o1=H.Ord[m//2][lv.R0[i]],H.Ord[m//2][lv.R1[i]]
  if fine.R0[o0]~=lv.R0[i]or fine.R1[o1]~=lv.R1[i]or o1-o0>1 then nestOk=false end
 end
end
check(nestOk,'a group of 2M rows is exactly two groups of M (coarse cell boundaries are fine cell boundaries)')
check(H.Ord[1][g.Bars[1].Row0]==nil and H.Ord[16][g.Bars[3].Row1]==nil,'spacebar rows belong to no group')
-- LOD windows: budgets, no overlap, no gaps, over every position of the track
local function fineCovered(w,H,row,col)
 local o=H.Ord[w.M][row];if not o then return false end
 local cg=(col-1)//w.M+1
 if o<w.A or o>w.B or cg<w.CA or cg>w.CB then return false end
 if w.HasHole then local h=w.Hole;if o>=h.A and o<=h.B and cg>=h.CA and cg<=h.CB then return false end end
 return true
end
for tier=3,1,-1 do
 local cfg=K.Tier(tier);local out={}
 local worstMesh,worstPlain=0,0
 local overlap,gap=0,0
 local frows={};for r=1,g.Rows,1 do frows[#frows+1]=r end
 for _,fr in ipairs(frows)do
  for _,fc in ipairs({1,30,60})do
   K.Windows(g,H,tier,fr,fc,out)
   local mesh,plain=K.WindowCount(out[1]),0
   for j=2,#out do plain+=K.WindowCount(out[j])end
   worstMesh=math.max(worstMesh,mesh);worstPlain=math.max(worstPlain,plain)
  end
 end
 check(worstMesh<=cfg.Mesh,('tier %d: at most %d meshes at any position (worst %d)'):format(tier,cfg.Mesh,worstMesh))
 check(worstPlain<=cfg.Plain,('tier %d: at most %d plain keys at any position (worst %d)'):format(tier,cfg.Plain,worstPlain))
 -- every fine key cell in the outer window is drawn by exactly one layer
 local sample=0
 for fr=1,g.Rows,23 do
  for _,fc in ipairs({1,20,41,60})do
   K.Windows(g,H,tier,fr,fc,out)
   local outer=out[#out];local lvO=H[outer.M]
   if outer.B>=outer.A then
    local ra,rb=lvO.R0[outer.A],lvO.R1[outer.B]
    for r=ra,rb,2 do
     if H.Ord[1][r]then
      for c=1,60,4 do
       local count=0
       for j=1,#out do if fineCovered(out[j],H,r,c)then count+=1 end end
       sample+=1
       if count>1 then overlap+=1 elseif count==0 then gap+=1 end
      end
     end
    end
   end
  end
 end
 check(overlap==0,('tier %d: no cell is drawn by two layers (%d cells checked)'):format(tier,sample))
 check(gap==0,('tier %d: no cell inside the outer window is left undrawn'):format(tier))
end
-- windows follow the runner and the outermost one reaches far
do
 local out={};K.Windows(g,H,3,900,30,out)
 local o=out[#out];local reachAhead=H[o.M].R1[o.B]-900;local reachBehind=900-H[o.M].R0[o.A]
 check(reachAhead*3>=2000 and reachBehind*3>=800,'tier 3 draws keys about 2000+ studs ahead and 800+ behind ('..reachAhead*3 ..' / '..reachBehind*3 ..')')
 local mesh=out[1];check(mesh.B-mesh.A+1==26 and mesh.CB-mesh.CA+1==26,'tier 3 near keys: a 26 x 26 window')
end

end
-- ======================================================================================================================
-- Part 2: the client script
-- ======================================================================================================================
check(not W.B.KeyboardTrackClient:find('RemoteEvent',1,true)and not W.B.KeyboardTrackClient:find('FireServer',1,true)and not W.B.KeyboardTrackClient:find('InvokeServer',1,true)
 and not W.B.KeyboardTrackClient:find('CollisionFidelity',1,true)and not W.B.KeyboardTrackClient:find('RenderFidelity',1,true),'client source: no remote use, never writes CollisionFidelity / RenderFidelity')
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local others={}
function Players.GetPlayers()local t={player};for _,p in ipairs(others)do t[#t+1]=p end;return t end
-- Mock gaps filled here (not in the shared mock): real BulkMoveTo, Sound:Play/Stop, ContentProvider, a controllable ClientFxBudget.
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
local fxTier=3
W.stub('ClientFxBudget',{Get=function()return fxTier end,Low=function()return fxTier==1 end})
-- count writes per frame: Color on keys / blocks (= cell bindings), CFrame on mesh keys outside BulkMoveTo
local writes={mesh=0,K1=0,K2=0,K4=0,K8=0,K16=0};local cframeWrites=0
local origNew=R.instMeta.__newindex
R.instMeta.__newindex=function(o,k,v)
 if k=='Color'then local n=o._props.Name;if n=='Key'then writes.mesh+=1 elseif writes[n]then writes[n]+=1 end end
 if k=='CFrame'and o._props.Name=='Key'and not inBulk then cframeWrites+=1 end
 return origNew(o,k,v)
end
local function resetWrites()for k in pairs(writes)do writes[k]=0 end end

-- the world: map without the biome attributes yet, real-looking floor, the keycap template
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace
local floorPart=R.new('Part');floorPart.Name='BiomeGround_1';floorPart.Size=V3(180,4,180);floorPart.CFrame=CF(0,2,0);floorPart.Anchored=true;floorPart.CanCollide=true;floorPart.Parent=map
local camps=R.new('Folder');camps.Name='GuardianEncounters';camps.Parent=map
local runtime=R.new('Folder');runtime.Name='_GameplayRuntime';runtime.Parent=map
local seeds=R.new('Folder');seeds.Name='Seeds';seeds.Parent=map
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
-- cell helpers
local bm=C.MaxReassignPerFrame
local BR=90 -- the test row: deep inside Jungle, far from every biome edge
local function cx(col)return g.ColCenter(col)end
local function cz(row)local a,b=g.RowZ(row);return (a+b)/2 end
local char,root,hum=makeCharacter('Tester',cx(30),cz(BR));player.Character=char
local PLASTIC,AIR=R.Enum.Material.Plastic,R.Enum.Material.Air
hum.FloorMaterial=AIR -- in the air: presses nothing until a test lands
local function put(x,y,z)root.CFrame=CF(x,y or F+3,z)end
local sc=R.new('LocalScript');sc.Name='KeyboardTrack'
local okLoad,errLoad=pcall(W.load,'KeyboardTrackClient',sc);check(okLoad,'client loads: '..tostring(errLoad))
frames(5)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'without the biome attributes nothing is built yet (it waits for them)')
for k,v in pairs(ATTR)do map:SetAttribute(k,v)end
frames(60)
local vis=workspace:FindFirstChild('KeyboardTrackVisuals')
check(vis~=nil,'the visuals folder appears once the attributes exist')
local keysF=vis:FindFirstChild('Keys');local bedF=vis:FindFirstChild('Bed')
check(keysF and bedF and vis:FindFirstChild('Blocks2')and vis:FindFirstChild('Blocks5'),'sub folders Bed / Keys / Blocks2 .. Blocks5')
-- all key parts: the near keycaps and spacebars (Keys) and the plain layers (Blocks*)
local function allKeyParts()
 local out={}
 for _,f in ipairs(vis:GetChildren())do
  if f.Name=='Keys'or f.Name:find('^Blocks')then for _,p in ipairs(f:GetChildren())do out[#out+1]=p end end
 end
 return out
end
local function shown(list)local t={};for _,p in ipairs(list or allKeyParts())do if p.Transparency==0 then t[#t+1]=p end end;return t end
local function gapOf(p)local m=tonumber(p.Name:match('^K(%d+)$'));return C.Gap*(m or 1)end
local function top(p)return p.CFrame.Position.Y+p.Size.Y/2-(p.Name=='Key'and C.TopOffset or 0)end
-- an index of the cells (part size + its gap) the visible parts draw: cover(x,z) -> how many parts, the first one
local function coverIndex(list)
 local B=40;local buckets={}
 for _,p in ipairs(list)do
  local pos=p.CFrame.Position;local gp=gapOf(p);local hx,hz=(p.Size.X+gp)/2,(p.Size.Z+gp)/2
  local rec={pos.X-hx,pos.X+hx,pos.Z-hz,pos.Z+hz,p}
  for bx=floor(rec[1]/B),floor(rec[2]/B)do for bz=floor(rec[3]/B),floor(rec[4]/B)do
   local k=bx..':'..bz;local b=buckets[k];if not b then b={};buckets[k]=b end;b[#b+1]=rec
  end end
 end
 return function(x,z)
  local b=buckets[floor(x/B)..':'..floor(z/B)];local n,first=0,nil
  if b then for _,r in ipairs(b)do if x>r[1]+1e-6 and x<r[2]-1e-6 and z>r[3]+1e-6 and z<r[4]-1e-6 then n+=1;first=first or r[5]end end end
  return n,first
 end
end
local function meshAt(row,col)
 local x,z=cx(col),cz(row)
 local cover=coverIndex(shown(keysF:GetChildren()))
 local n,p=cover(x,z);if n==1 and p.Name=='Key'then return p end
 return nil
end
local function topOf(row,col)local p=meshAt(row,col);return p and top(p)end
local clickIds,bar1={},nil
local coverageAt,counts,barPart
local function nonRemote()
 for _,o in ipairs(R.created)do if o._class=='RemoteEvent'or o._class=='RemoteFunction'or o._class=='UnreliableRemoteEvent'then return false end end
 return true
end
check(nonRemote(),'no RemoteEvent / RemoteFunction was created')

-- 1. what was built
do
local badParts,partCount=0,0
for _,o in ipairs(vis:GetDescendants())do
 if o:IsA('BasePart')then partCount+=1
  if o.Anchored~=true or o.CanCollide~=false or o.CanQuery~=false or o.CanTouch~=false or o.CastShadow~=false then badParts+=1 end
 end
end
check(partCount>2000 and badParts==0,'every keyboard part is Anchored, CanCollide / CanQuery / CanTouch / CastShadow false ('..partCount..' parts, '..badParts..' bad)')
check(floorPart.Transparency==0 and floorPart.CanCollide==true and floorPart.Size.X==180 and floorPart.CFrame.Position.Y==2 and floorPart.Parent==map,'the real floor is untouched')
local meshN,plainN=0,0
for _,p in ipairs(shown())do if p.Name=='Key'then meshN+=1 elseif p.Name:find('^K%d')then plainN+=1 end end
check(meshN==676,'near keys: 676 keycap MeshParts (26 x 26) at tier 3 ('..meshN..')')
check(plainN>=1800 and plainN<=2500,'plain keys: at most 2500 at tier 3 ('..plainN..')')
local sizeOk,clsOk,scripts=true,true,0
for _,p in ipairs(keysF:GetChildren())do
 if p.Name=='Key'then
  if p._class~='MeshPart'then clsOk=false end
  if not near(p.Size.X,2.72)or not near(p.Size.Z,2.72)or not near(p.Size.Y,1.3)then sizeOk=false end
  for _,d in ipairs(p:GetDescendants())do if d:IsA('BaseScript')then scripts+=1 end end
 end
end
check(clsOk and sizeOk and scripts==0,'near keys are clones of the R142Keycap MeshPart scaled to 2.72 x 1.3 x 2.72, scripts stripped')
-- the dark bed covers the whole key area, no grass
local bedParts,bedLen,bedOk={},0,true
for _,p in ipairs(bedF:GetChildren())do
 bedParts[#bedParts+1]=p;bedLen+=p.Size.Z
 if p.Size.Z>1024+1e-6 or p.Size.X~=180 or not near(p.CFrame.Position.X,0)or not near(p.CFrame.Position.Y+p.Size.Y/2,F+C.BedRise)then bedOk=false end
 local c=p.Color;if math.abs(c.R*255-44)>.5 or math.abs(c.G*255-27)>.5 or math.abs(c.B*255-20)>.5 then bedOk=false end
end
local zLo,zHi=1e9,-1e9;for _,p in ipairs(bedParts)do zLo=math.min(zLo,p.CFrame.Position.Z-p.Size.Z/2);zHi=math.max(zHi,p.CFrame.Position.Z+p.Size.Z/2)end
check(#bedParts==6 and bedOk and near(bedLen,5960)and near(zLo,-100,1e-6)and near(zHi,5860,1e-6),'dark bed: 6 segments of <= 1024 studs, 180 wide (the whole floor), from the track start to the arena ('..#bedParts..' segments, z '..zLo..' .. '..zHi..')')
local RIM_TOP,PIT_TOP=F+.06+C.BedRise,F+.08+C.BedRise -- TrackHoleService: Rim .06 thick, Pit .08 thick on the floor; the client lifts them by BedRise
local bedTop=F+C.BedRise
check(bedTop>F+.05 and RIM_TOP-bedTop>=.05 and PIT_TOP-bedTop>=.07,'z-fighting: the bed top is 0.1 above the floor and the lifted hole Rim / Pit tops are clearly above the bed')
-- the keys sit on top of the bed; no two layers share a cell (exactly one part draws every point of the key area)
function coverageAt(fz,label,behind,ahead)
 behind=behind or 850;ahead=ahead or 1400
 local list=shown();local cover=coverIndex(list)
 local zeros,doubles,probes=0,0,0
 local zA=math.max(g.Z0+.2,fz-behind);local zB=math.min(g.KeyEndZ-.2,fz+ahead)
 local z=zA+.0123456
 while z<=zB do
  for _,x in ipairs({-89.9,-71.3,-52.1,-33.7,-14.2,-.3,.3,13.9,31.1,49.9,68.3,89.9})do
   local n=cover(x,z);probes+=1
   if n==0 then zeros+=1 elseif n>1 then doubles+=1 end
  end
  z+=11.3
 end
 check(zeros==0 and doubles==0,('coverage at z %d (%s): every point of the floor from -%d to +%d studs is drawn by exactly one key or block (%d probes, %d bare, %d doubled)'):format(fz,label,behind,ahead,probes,zeros,doubles))
end
put(cx(30),nil,cz(BR));frames(30)
coverageAt(cz(BR),'start')
-- teleports along the whole track: edge to edge, start to the arena
local stops={{700,'Jungle'},{1176,'Desert/Snow boundary'},{2029,'Snow/Lava boundary'},{3080,'Lava/Crystal'},{4379,'Crystal/Storm'},{5800,'the end'},{5000,'Storm'}}
for _,s in ipairs(stops)do put(-37.3,nil,s[1]);frames(30);coverageAt(s[1],s[2])end
put(cx(30),nil,cz(BR));frames(30)
-- a runner reads upright, left -> right legends
local function legendsInRow(row)
 local out={}
 for _,p in ipairs(keysF:GetChildren())do
  if p.Name=='Key'and p.Transparency==0 and near(p.CFrame.Position.Z,cz(row),.01)then
   local gui=p:FindFirstChildWhichIsA('SurfaceGui')
   if gui then out[#out+1]={X=p.CFrame.Position.X,Gui=gui,Label=gui:FindFirstChildWhichIsA('TextLabel',true)}end
  end
 end
 table.sort(out,function(a,b)return a.X>b.X end) -- +X is a +Z runner's left, so descending x = left -> right
 return out
end
local lg=legendsInRow(BR)
local litTotal=0;for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'and p:FindFirstChildWhichIsA('SurfaceGui')then litTotal+=1 end end
check(#lg>=10 and litTotal>=100 and litTotal<=150,'legends: the keys nearest the runner carry a letter (SurfaceGui), at most 150 in all ('..litTotal..', '..#lg..' in his row)')
local seq,uprightOk,faceOk,inkOk,textOk={},true,true,true,true
for _,e in ipairs(lg)do
 seq[#seq+1]=e.Label.Text
 if e.Label.Rotation~=180 or e.Label.AnchorPoint.X~=.5 or e.Label.AnchorPoint.Y~=.5 then uprightOk=false end
 if e.Gui.Face~=R.Enum.NormalId.Top then faceOk=false end
 local col=g.ColOfX(e.X);if e.Label.Text~=K.Legend(BR,col)then textOk=false end
 local ink=K.Zone(g.RowStage[BR]).Ink;if math.abs(e.Label.TextColor3.R*255-ink[1])>.5 then inkOk=false end
end
local line=K.LegendRows[(BR-1)%4+1];local seqText=table.concat(seq)
check(line:rep(8):find(seqText,1,true)~=nil and #seqText==#lg,'a +Z runner reads his row left -> right in keyboard order: '..seqText)
check(uprightOk and faceOk,'legends sit on the Top face turned 180 degrees about their centre, so they read upright for a runner facing +Z')
check(textOk and inkOk,'each legend is the key letter and the zone ink')
-- the spacebar of the biome ahead: full width, from the biome start, label upright and left -> right
function barPart(i)for _,p in ipairs(keysF:GetChildren())do if p.Name=='Spacebar'and near(p.CFrame.Position.Z,(g.Bars[i].Z0+g.Bars[i].Z1)/2,.01)then return p end end;return nil end
put(cx(30),nil,g.Segs[3].StartZ-14);frames(30)
local bar3=barPart(3)
check(bar3~=nil and near(bar3.Size.X,180-C.Gap,.001)and bar3.Transparency==0,'the Desert spacebar spans the whole floor (180 - gap)')
check(bar3 and near(bar3.CFrame.Position.Z-bar3.Size.Z/2-C.Gap/2,530,1e-6)and near(bar3.Size.Z+C.Gap,3*g.Segs[3].RowPitch,1e-6),'...parallel to the entrance: it starts exactly at z 530 and is three rows deep')
local bgui=bar3 and bar3:FindFirstChildWhichIsA('SurfaceGui');local blabel=bgui and bgui:FindFirstChildWhichIsA('TextLabel',true)
check(blabel and blabel.Text=='DESERT'and blabel.Rotation==180 and blabel.AnchorPoint.X==.5 and bgui.Face==R.Enum.NormalId.Top and bgui.Enabled,'its label reads DESERT, Top face turned 180 degrees = upright for a runner arriving at the biome')
check(bar3 and math.abs(bar3.Color.R*255-K.Cream[1])<.5 and math.abs(bar3.Color.G*255-K.Cream[2])<.5 and math.abs(bar3.Color.B*255-K.Cream[3])<.5 and top(bar3)>F+C.RestRise-1e-6,'the spacebar is cream at rest height')
-- colour: zones, shades, no bands (parts in the world)
local function zoneParts(stage,zlo,zhi,kind)
 local out={}
 for _,p in ipairs(shown())do
  local z=p.CFrame.Position.Z
  if z>=zlo and z<=zhi and(kind=='plain'and p.Name=='K1'or kind=='mesh'and p.Name=='Key')then out[#out+1]=p end
 end
 return out
end
put(cx(30),nil,300);frames(40)
local jungle=zoneParts(6,100,520,'plain');local jz=K.Zone(6)
local inZone,seen=true,{}
for _,p in ipairs(jungle)do
 local rgb={p.Color.R*255,p.Color.G*255,p.Color.B*255};local best,bi=1e9,0
 for i,sh in ipairs(jz.Shades)do local d=dist2(rgb,sh);if d<best then best,bi=d,i end end
 seen[bi]=true
 local sh=jz.Shades[bi];if math.abs(rgb[1]-sh[1])>sh[1]*.045+1.5 or math.abs(rgb[2]-sh[2])>sh[2]*.045+1.5 or math.abs(rgb[3]-sh[3])>sh[3]*.045+1.5 then inZone=false end
end
local nSeen=0;for _ in pairs(seen)do nSeen+=1 end
check(#jungle>300 and inZone and nSeen==4,'Jungle keys are all pistachio / lime: the four zone shades only ('..#jungle..' blocks, '..nSeen..' shades)')
-- no single-colour row bands among the plain blocks and the keycaps
local rowsByZ={}
for _,p in ipairs(jungle)do local k=string.format('%.2f',p.CFrame.Position.Z);local r=rowsByZ[k];if not r then r={n=0,r=0,g=0,b=0,colors={}};rowsByZ[k]=r end
 r.n+=1;r.r+=p.Color.R;r.g+=p.Color.G;r.b+=p.Color.B;r.colors[string.format('%.3f%.3f%.3f',p.Color.R,p.Color.G,p.Color.B)]=true end
local rowCount,mono=0,0;local rowSum,rowSq,rowN=0,0,0
local mr,mg,mb,mn=0,0,0,0;for _,r in pairs(rowsByZ)do mr+=r.r;mg+=r.g;mb+=r.b;mn+=r.n end;mr/=mn;mg/=mn;mb/=mn
for _,r in pairs(rowsByZ)do
 if r.n>=14 then
  rowCount+=1;local kinds=0;for _ in pairs(r.colors)do kinds+=1 end;if kinds<3 then mono+=1 end
  local lum=(r.r+r.g+r.b)/r.n;rowSum+=lum;rowSq+=lum*lum;rowN+=1
 end
end
local keySum,keySq=0,0;for _,p in ipairs(jungle)do local l=p.Color.R+p.Color.G+p.Color.B;keySum+=l;keySq+=l*l end
local keyStd=math.sqrt(keySq/#jungle-(keySum/#jungle)^2);local rowStd=math.sqrt(math.max(0,rowSq/rowN-(rowSum/rowN)^2))
check(rowCount>=20 and mono==0,'no flat colour bands: every full row of keys mixes several shades ('..rowCount..' rows, '..mono..' flat)')
check(rowStd<=keyStd*.3,'...and no row is lighter or darker than the zone as a whole (row means vary '..string.format('%.1f%%',rowStd/keyStd*100)..' of the key-to-key spread)')
-- far blocks (2x2, 4x4, 8x8 keys) keep the zone colours too, in several shades per row
local farKinds=true;local farBlocks=0
for _,name in ipairs({'K2','K4','K8'})do
 local byRow={}
 for _,p in ipairs(shown())do if p.Name==name and p.CFrame.Position.Z>1200 and p.CFrame.Position.Z<1900 then local k=string.format('%.1f',p.CFrame.Position.Z);byRow[k]=byRow[k]or{};byRow[k][string.format('%.3f%.3f%.3f',p.Color.R,p.Color.G,p.Color.B)]=true;farBlocks+=1 end end
 local rowsWith,rowsMulti=0,0
 for _,set in pairs(byRow)do local n=0;for _ in pairs(set)do n+=1 end;rowsWith+=1;if n>=2 then rowsMulti+=1 end end
 if rowsWith>0 and rowsMulti<rowsWith*.7 then farKinds=false end
end
put(cx(30),nil,1500);frames(40)
farBlocks=0;farKinds=true
for _,name in ipairs({'K1','K2','K4','K8'})do
 local byRow={}
 for _,p in ipairs(shown())do if p.Name==name and p.CFrame.Position.Z>1180 and p.CFrame.Position.Z<2030 then local k=string.format('%.1f',p.CFrame.Position.Z);byRow[k]=byRow[k]or{};byRow[k][string.format('%.3f%.3f%.3f',p.Color.R,p.Color.G,p.Color.B)]=true;farBlocks+=1 end end
 local rowsWith,rowsMulti=0,0
 for _,set in pairs(byRow)do local n=0;for _ in pairs(set)do n+=1 end;rowsWith+=1;if n>=2 then rowsMulti+=1 end end
 if name=='K1'and rowsWith>0 and rowsMulti<rowsWith then farKinds=false end
 if name~='K1'and rowsWith>0 and rowsMulti<rowsWith*.6 then farKinds=false end
end
check(farBlocks>200 and farKinds,'at every distance a row of blocks mixes shades of its zone (Snow vanilla / ice blue; '..farBlocks..' blocks)')
local snowOk=true;local snow=K.Zone(3)
for _,p in ipairs(shown())do
 local z=p.CFrame.Position.Z
 if p.Name:find('^K%d')and z>1190 and z<2020 then
  local rgb={p.Color.R*255,p.Color.G*255,p.Color.B*255};local best=1e9;for _,sh in ipairs(snow.Shades)do best=math.min(best,dist2(rgb,sh))end
  if best>(.06*255)^2*3 then snowOk=false end
 end
end
check(snowOk,'far blocks of the Snow zone are vanilla / ice-blue shades (no rainbow)')
put(cx(30),nil,cz(BR));frames(40)
local meshParts=0;for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'then meshParts+=1 end end
check(cframeWrites==meshParts,'keycaps are parked by script once each and moved with BulkMoveTo only ('..cframeWrites..' direct writes on '..meshParts..' keycaps)')
check(bulkCalls>0,'keys are positioned with BulkMoveTo')
local routed=0;for _,o in ipairs(R.created)do if o._class=='Sound'and o.SoundGroup~=nil then routed+=1 end end
check(routed==10,'ten pooled click Sounds, routed through AudioMixer (Effects group) ('..routed..')')
for _,o in ipairs(R.created)do if o._class=='Sound'and o._props.Name=='KeyClickSound'then clickIds[o.SoundId]=true end end
check(clickIds['rbxassetid://113108830240353']and clickIds['rbxassetid://88838553648526']and clickIds['rbxassetid://96591611478915'],'the pool uses the three click recordings')
check(contentCalls>=1,'the click sounds are preloaded')
end

-- 2. a runner presses a key and releases it
local R10,C20=BR,30
do
plays={};hum.FloorMaterial=PLASTIC;put(cx(C20),nil,cz(R10));frames(3)
check(topOf(R10,C20)and topOf(R10,C20)<F+C.RestRise-.1,'a key goes down under the runner (mid-press)')
frames(8)
check(near(topOf(R10,C20),F+C.PressedRise,1e-6),'...to the pressed height (top = floor + 0.12, got '..tostring(topOf(R10,C20))..')')
check(near(topOf(R10,C20+1),F+C.RestRise,1e-6)and near(topOf(R10+1,C20),F+C.RestRise,1e-6)and near(topOf(R10-1,C20),F+C.RestRise,1e-6),'its neighbours stay up')
check(#plays==1 and plays[1].Id:find('rbxassetid://')and(clickIds[plays[1].Id]),'one click played for the one key ('..#plays..')')
check(plays[1]and plays[1].Speed>=.96 and plays[1].Speed<=1.06,'own click pitch within 0.96 .. 1.06')
check(plays[1]and plays[1].Group and plays[1].Group.Name=='GardenEffects','clicks go through the Effects sound group (AudioMixer.Route)')
check(plays[1]and near(plays[1].Pos.X,cx(C20),.01)and near(plays[1].Pos.Z,cz(R10),.01),'the click is played at the key')
put(cx(C20)+15,nil,cz(R10));frames(12)
check(near(topOf(R10,C20),F+C.RestRise,1e-6),'the key comes back up when the runner leaves')
local Mixer=W.module('AudioMixer');Mixer.Set('Effects',0);plays={}
put(cx(C20),nil,cz(R10+8));frames(12);put(cx(C20)+15,nil,cz(R10));frames(12)
check(#plays==0,'Effects volume 0 (Settings): the keys still move but nothing is played')
Mixer.Set('Effects',100);plays={}
put(cx(C20),nil,cz(R10));frames(12)
check(#plays==1,'...and clicks are back with the volume')
put(cx(C20)+15,nil,cz(R10));frames(12);plays={}
-- standing on a corner shared by 4 keys presses all 4
put(cx(C20)-1.5,nil,select(2,g.RowZ(R10)));frames(12)
local cornerDown=0;for _,cc in ipairs({C20,C20+1})do for _,rr in ipairs({R10,R10+1})do if near(topOf(rr,cc),F+C.PressedRise,1e-6)then cornerDown+=1 end end end
check(cornerDown==4 and #plays==4,'standing on a corner presses the 4 keys under the +-1.2 footprint, one click each ('..cornerDown..' down, '..#plays..' clicks)')
put(cx(C20)+15,nil,cz(R10))
local maxTop=0
for _=1,15 do frames(1);local t=topOf(R10,C20);if t then maxTop=math.max(maxTop,t)end end
check(maxTop>F+C.RestRise+.01,'release springs a little past rest (back-out, max '..string.format('%.3f',maxTop)..')')
check(near(topOf(R10,C20),F+C.RestRise,1e-6),'...and settles at rest')
put(cx(C20),nil,cz(R10));frames(10);check(near(topOf(R10,C20),F+C.PressedRise,1e-6),'back on a key: pressed')
hum.FloorMaterial=AIR;put(cx(C20),F+7,cz(R10));frames(12)
check(near(topOf(R10,C20),F+C.RestRise,1e-6),'in the air the key is up (FloorMaterial == Air)')
hum.FloorMaterial=PLASTIC;put(cx(C20),nil,cz(R10));frames(10)
check(near(topOf(R10,C20),F+C.PressedRise,1e-6),'landing presses it again')
hum.Health=0;frames(12);check(near(topOf(R10,C20),F+C.RestRise,1e-6),'a dead character presses nothing');hum.Health=100
-- spacebar: the whole bar goes down
put(cx(8),nil,g.Segs[1].StartZ+2);frames(30)
bar1=barPart(1)
check(bar1~=nil and near(top(bar1),F+C.PressedRise,1e-6),'stepping anywhere on a spacebar presses the whole bar')
put(cx(8),nil,60);frames(20);check(near(top(bar1),F+C.RestRise,1e-6),'...and it comes back up')
end
-- 3. reduced motion
do
W.Gui.ReducedMotionEnabled=true
put(cx(C20),nil,cz(R10+5));frames(1)
check(near(topOf(R10+5,C20),F+C.PressedRise,1e-6),'reduced motion: the key is pressed at once')
put(cx(C20),nil,cz(R10));local overshoot=false;local firstUp=nil
for i=1,3 do frames(1);local t=topOf(R10+5,C20);if i==1 then firstUp=t end;if t and t>F+C.RestRise+1e-6 then overshoot=true end end
check(near(firstUp,F+C.RestRise,1e-6)and not overshoot,'reduced motion: released at once, no bounce')
W.Gui.ReducedMotionEnabled=false
frames(5)
end
-- 4. sprinting at 1000 studs/s: clicks are rate limited, per-frame work is bounded
do
hum.FloorMaterial=PLASTIC;plays={};resetWrites();bulkMax=0
local worst={mesh=0,K1=0,K2=0,K4=0,K8=0,K16=0};local z=cz(BR)
local createdMax=0
for f=1,300 do
 z+=1000/60;put(cx(30),nil,z)
 resetWrites();local createdN=#R.created
 frames(1)
 for k,v in pairs(writes)do worst[k]=math.max(worst[k],v)end
 createdMax=math.max(createdMax,#R.created-createdN)
end
check(worst.mesh<=bm.mesh and worst.K1<=bm.plain and worst.K2<=bm.coarse and worst.K4<=bm.coarse and worst.K8<=bm.coarse and worst.K16<=bm.coarse,('per-frame cell bindings stay within the budgets at 1000 studs/s (keycaps %d/%d, blocks %d/%d, 2x2 %d, 4x4 %d, 8x8 %d, 16x16 %d, each coarse layer %d)'):format(worst.mesh,bm.mesh,worst.K1,bm.plain,worst.K2,worst.K4,worst.K8,worst.K16,bm.coarse))
local worstWindow=0
for i,p in ipairs(plays)do local c=0;for _,q in ipairs(plays)do if q.T>p.T-1 and q.T<=p.T then c+=1 end end;worstWindow=math.max(worstWindow,c)end
check(#plays>=20 and worstWindow<=12,'sprinting at 1000 studs/s: clicks are limited to 12 per second ('..#plays..' clicks, worst 1 s window '..worstWindow..')')
local pitchSet={};for _,p in ipairs(plays)do pitchSet[p.Speed]=true end;local distinct=0;for _ in pairs(pitchSet)do distinct+=1 end
check(distinct>=4,'own click pitch varies between steps ('..distinct..' different pitches)')
frames(40)
coverageAt(z,'after the sprint')
end
-- 5. trips of 1000+ studs and back: nothing leaks, nothing exceeds the caps
do
put(cx(30),nil,cz(BR));frames(60)
local peakParts=0
function counts()
 local m,p=0,0;for _,part in ipairs(shown())do if part.Name=='Key'then m+=1 elseif part.Name:find('^K%d')then p+=1 end end
 return m,p
end
local function trip()
 for _,zz in ipairs({600,1500,2600,4000,5500,5850,3000,1000,-80})do
  put(cx(30),nil,zz);frames(40)
  local m,p=counts();peakParts=math.max(peakParts,m+p)
  check(m<=700 and p<=2500,('tier 3 caps hold at z %d (%d keycaps, %d blocks)'):format(zz,m,p))
  hum.FloorMaterial=PLASTIC
 end
 put(cx(30),nil,cz(BR));frames(40)
end
local n0=#vis:GetDescendants()
trip();local n1=#vis:GetDescendants()
trip();local n2=#vis:GetDescendants()
check(n2<=n1 and n1<=n0+1200,'after trips of 1000+ studs and back the instance count does not grow (start '..n0..', after one trip '..n1..', after two '..n2..')')
check(n2<=5200,'instance budget: <= 5200 under the keyboard folder ('..n2..')')
-- a teleport re-dresses everything with bounded work per frame
put(cx(30),nil,2500);resetWrites();local perFrame={}
local function allWrites()return writes.mesh+writes.K1+writes.K2+writes.K4+writes.K8+writes.K16 end
for f=1,18 do local before=allWrites();frames(1);perFrame[f]=allWrites()-before end
local mx=0;for _,v in ipairs(perFrame)do mx=math.max(mx,v)end
check(mx<=bm.mesh+bm.plain+4*bm.coarse and perFrame[1]>0,'a teleport re-dresses the keys at a bounded rate per frame ('..table.concat(perFrame,',')..')')
end
-- 6. other players
do
hum.FloorMaterial=AIR  -- isolate the others
put(cx(30),F+9,cz(BR));frames(40)
local other=R.new('Player');other.Name='Pal';other.UserId=5;other.Parent=Players;others[1]=other
local ochar,oroot=makeCharacter('Pal',cx(28),cz(BR));other.Character=ochar
plays={};frames(6)
check(near(topOf(BR,28),F+C.PressedRise,1e-6),'another player standing on a key presses it')
check(#plays==1 and plays[1].Speed>=.96 and plays[1].Speed<=1.06,'...with one click ('..#plays..')')
oroot.CFrame=CF(cx(28),F+9,cz(BR));frames(10)
check(near(topOf(BR,28),F+C.RestRise,1e-6),'jumping high (feet more than 3 studs up) releases it')
oroot.CFrame=CF(cx(28),F+5.5,cz(BR));frames(10)
check(near(topOf(BR,28),F+C.PressedRise,1e-6),'feet within about 3 studs of the floor still press')
oroot.CFrame=CF(300,F+3,cz(BR));frames(10)
check(near(topOf(BR,28),F+C.RestRise,1e-6),'walking off the keyboard releases')
-- rate limit for others: a crowd running by
plays={}
for i=1,12 do local pl=R.new('Player');pl.Name='P'..i;pl.UserId=100+i;pl.Parent=Players;others[#others+1]=pl;local _,r2=makeCharacter('P'..i,cx(10+i*3),cz(BR));pl.Character=r2.Parent end
frames(4)
local runnerZ=cz(BR)
for f=1,120 do
 for i=2,13 do local pr=others[i].Character.HumanoidRootPart;pr.CFrame=CF(cx(10+(i-1)*3),F+3,runnerZ+((i%3)*3))end
 put(cx(30),F+9,runnerZ-20) -- the local runner (in the air) keeps pace, so the others stay in earshot
 runnerZ+=400/60;frames(1)
end
local worstOther=0
for i,p in ipairs(plays)do local c=0;for _,q in ipairs(plays)do if q.T>p.T-1 and q.T<=p.T then c+=1 end end;worstOther=math.max(worstOther,c)end
check(#plays>=10 and worstOther<=8,'12 players running by: at most 8 clicks per second from others ('..#plays..' clicks, worst '..worstOther..')')
plays={};local farP=others[2].Character.HumanoidRootPart;for i=3,13 do others[i].Character.HumanoidRootPart.CFrame=CF(300,F+3,0)end
put(cx(30),F+9,cz(BR));farP.CFrame=CF(cx(30),F+3,cz(BR)+200);frames(10)
check(#plays==0,'other players more than 90 studs away are silent ('..#plays..')')
for i=#others,1,-1 do others[i]=nil end
put(cx(30),F+9,cz(BR));frames(40)
end
-- 7. keepers
do
local keeper=R.new('Model');keeper.Name='ForestKeeper';keeper:SetAttribute('PersistentBiomeGuardian',true)
local kroot=R.new('Part');kroot.Name='HumanoidRootPart';kroot.Size=V3(6,10,6);kroot.CFrame=CF(cx(34),F+5,cz(BR+8));kroot.Parent=keeper;keeper.PrimaryPart=kroot
keeper.Parent=camps;W.CS:AddTag(keeper,'BiomeKeeper')
plays={};frames(12)
local ek=K.KeeperFootprint(6,6);local kdown=0
for cc=32,36 do for rr=BR+6,BR+10 do if near(topOf(rr,cc)or 99,F+C.PressedRise,1e-6)then kdown+=1 end end end
check(near(ek,1.8)and kdown>=1 and kdown<=16,'a keeper presses the keys under its feet (footprint '..ek..', '..kdown..' keys down)')
check(#plays>=1 and near(plays[1].Speed,.7),'keeper clicks are pitched down to 0.7')
kroot.CFrame=CF(300,F+5,cz(BR+8));frames(12)
kdown=0;for cc=32,36 do for rr=BR+6,BR+10 do if near(topOf(rr,cc)or 99,F+C.PressedRise,1e-6)then kdown+=1 end end end
check(kdown==0,'the keys come back up when the keeper walks away')
kroot.CFrame=CF(cx(34),F+40,cz(BR+8));frames(12)
kdown=0;for cc=32,36 do for rr=BR+6,BR+10 do if near(topOf(rr,cc)or 99,F+C.PressedRise,1e-6)then kdown+=1 end end end
check(kdown==0,'a keeper high in the air presses nothing')
-- dashing keeper: the rendered dash frame, not the (server) PrimaryPart
kroot.CFrame=CF(300,F+5,cz(BR+8))
keeper:SetAttribute('GuardianBehavior','DASHING');keeper:SetAttribute('GuardianLeaseToken',7);keeper:SetAttribute('KeeperDashToken',7)
keeper:SetAttribute('KeeperDashFrom',CF(cx(40),F+5,cz(BR+8)));keeper:SetAttribute('KeeperDashTo',V3(cx(20),F+5,cz(BR+8)));keeper:SetAttribute('KeeperDashAt',R.clock);keeper:SetAttribute('KeeperDashDuration',.2)
frames(6)
local mid=false;for cc=1,60 do for rr=BR+6,BR+10 do local t=topOf(rr,cc);if t and t<F+C.RestRise-.05 then mid=true end end end
check(mid,'a dashing keeper presses where its dash is drawn (KeeperRecoveryDash.VisualFrame)')
keeper:SetAttribute('GuardianBehavior','GUARDING');frames(15)
local veiled=R.new('Model');veiled.Name='Veiled';veiled:SetAttribute('VeiledKeeper81',true)
local vroot=R.new('Part');vroot.Name='HumanoidRootPart';vroot.Size=V3(8,12,8);vroot.CFrame=CF(cx(38),F+6,cz(BR));vroot.Parent=veiled;veiled.PrimaryPart=vroot;veiled.Parent=runtime
frames(130)
local vdown=0;for cc=36,40 do for rr=BR-3,BR+3 do if near(topOf(rr,cc)or 99,F+C.PressedRise,1e-6)then vdown+=1 end end end
check(vdown>=1,'the event keeper (VeiledKeeper81 in _GameplayRuntime) presses keys (found by the scan)')
veiled:Destroy();frames(15)
vdown=0;for cc=36,40 do for rr=BR-3,BR+3 do if near(topOf(rr,cc)or 99,F+C.PressedRise,1e-6)then vdown+=1 end end end
check(vdown==0,'a destroyed keeper lets go')
end
-- 8. shovel holes: near and far, at every layer
do
local holes=R.new('Folder');holes.Name='TrackHoles';holes.Parent=runtime
local function dig(id,x,z)
 local m=R.new('Model');m.Name='TrackHole_'..id
 local pit=R.new('Part');pit.Name='Pit';pit.Size=V3(.08,3.4,3.4);pit.CFrame=CF(x,F+.04,z);pit.Parent=m
 local rim=R.new('Part');rim.Name='Rim';rim.Size=V3(.06,4,4);rim.CFrame=CF(x,F+.03,z);rim.Parent=m
 m.PrimaryPart=pit;m.Parent=holes;return m,pit,rim
end
put(cx(30),nil,cz(BR));hum.FloorMaterial=PLASTIC;frames(40)
local function coverAtPoint(x,z)local cover=coverIndex(shown());return cover(x,z)end
local hx,hzz=cx(22),cz(BR+4)
check(coverAtPoint(hx,hzz)==1,'(a key covers the spot before the hole)')
local h1,pit1,rim1=dig(1,hx,hzz);frames(30)
check(coverAtPoint(hx,hzz)==0,'near hole: the keys within 2 studs of the Pit are left out, the hole shows')
check(near(pit1.CFrame.Position.Y,F+.04+C.BedRise,1e-6)and near(rim1.CFrame.Position.Y,F+.03+C.BedRise,1e-6),'the hole parts are lifted by the bed height (they sit above the dark bed)')
local hiddenAround=0;for _,d in ipairs({{-5.5,0},{5.5,0},{0,-5.5},{0,5.5}})do if coverAtPoint(hx+d[1],hzz+d[2])==1 then hiddenAround+=1 end end
check(hiddenAround==4,'only the cells next to the Pit are affected (the ones within 2 studs)')
h1:Destroy();frames(30)
check(coverAtPoint(hx,hzz)==1,'the keys come back when the hole is filled')
-- hole under the plain block layer, and far away under the coarse blocks
local plainSpot={cx(30),cz(BR+19)}
local h2=dig(2,plainSpot[1],plainSpot[2]);frames(30)
check(coverAtPoint(plainSpot[1],plainSpot[2])==0,'a hole beyond the keycaps (plain blocks) shows')
h2:Destroy();frames(30)
local farSpot={cx(10),g.Segs[4].StartZ+300}
local farPit=dig(3,farSpot[1],farSpot[2]);frames(30)
check(coverAtPoint(farSpot[1],farSpot[2])==0,'far hole 1000+ studs ahead: the coarse block over it is left out, the hole shows')
local farNeighbours=0;for _,d in ipairs({{-60,0},{60,0},{0,-60},{0,60}})do if coverAtPoint(farSpot[1]+d[1],farSpot[2]+d[2])>=1 then farNeighbours+=1 end end
check(farNeighbours>=3,'...and the blocks around it stay')
farPit:Destroy();frames(30)
check(coverAtPoint(farSpot[1],farSpot[2])==1,'a filled far hole is covered again')
-- a hole under a spacebar hides that bar
local barHole=dig(4,0,g.Bars[1].Z0+3);put(cx(30),nil,cz(BR));frames(30)
check(bar1.Transparency==1,'a hole in a spacebar row hides the bar')
barHole:Destroy();frames(30);check(bar1.Transparency==0,'...and it comes back')
-- pack platforms: the fine cells under them are left out
local seed=R.new('Model');seed.Name='Seed1';seed.Parent=seeds
local plat=R.new('Model');plat.Name='PackPlatform';plat:SetAttribute('PlatformRadius',1.5)
local stone=R.new('Part');stone.Name='BiomeStone';stone.CFrame=CF(cx(44),F+.3,cz(BR+10));stone.Parent=plat;plat.PrimaryPart=stone;plat.Parent=seed
frames(30)
check(coverAtPoint(cx(44),cz(BR+10))==0,'a pack platform clears the keys under it')
plat:Destroy();frames(30);check(coverAtPoint(cx(44),cz(BR+10))==1,'...and gives them back when the platform goes')
check(floorPart.Transparency==0,'the real floor is still untouched')
holes:Destroy()
end
-- 9. tiers: a change applies after it has held a few seconds, and only adds / removes outer cells
do
put(cx(30),nil,cz(BR));hum.FloorMaterial=AIR;frames(60)
local function meshSet()local t={};for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'and p.Transparency==0 then t[p]=true end end;return t end
local before=meshSet();local nb=0;for _ in pairs(before)do nb+=1 end
resetWrites()
fxTier=1;frames(60*2)
local mid1=meshSet();local nm=0;for _ in pairs(mid1)do nm+=1 end
check(nm==nb and writes.mesh==0,'tier 1 for 2 s: nothing changes yet (a tier must hold ~3 s)')
fxTier=3;frames(60*5)
check(writes.mesh==0,'a tier that flips back before 3 s never changed anything')
fxTier=2;frames(60*4)
local after2=meshSet();local n2m=0;local kept=0;for p in pairs(after2)do n2m+=1;if before[p]then kept+=1 end end
check(n2m<=450 and n2m>=300 and kept==n2m and writes.mesh==0,'tier 2 held: a smaller near window ('..n2m..' keycaps), the surviving keycaps are the same parts, untouched (0 reassignments, got '..writes.mesh..')')
local m2,p2=counts();check(m2<=450 and p2<=1500,('tier 2 caps: %d keycaps <= 450, %d blocks <= 1500'):format(m2,p2))
local lit2=0;for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'and p:FindFirstChildWhichIsA('SurfaceGui')then lit2+=1 end end
check(lit2<=100,'tier 2: at most 100 lit legends ('..lit2..')')
coverageAt(cz(BR),'tier 2',500,1200)
fxTier=1;frames(60*4)
local m1,p1=counts();check(m1<=250 and p1<=800 and m1>=150,('tier 1 caps: %d keycaps <= 250, %d blocks <= 800'):format(m1,p1))
local lit1=0;for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'and p:FindFirstChildWhichIsA('SurfaceGui')then lit1+=1 end end
check(lit1<=60 and lit1>=20,'tier 1: at most 60 lit legends ('..lit1..')')
coverageAt(cz(BR),'tier 1',330,900)
fxTier=3;frames(60*4)
local m3,p3=counts();check(m3==676 and p3<=2500,'back to tier 3: 676 keycaps, plain keys within 2500 ('..m3..', '..p3..')')
check(near(topOf(BR,20)or 99,F+C.RestRise,1e-6),'(the keys are up while the runner is in the air)')
local lit3=0;for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'and p:FindFirstChildWhichIsA('SurfaceGui')then lit3+=1 end end
check(lit3<=150 and lit3>=100,'tier 3: up to 150 lit legends ('..lit3..')')
coverageAt(cz(BR),'tier 3 again')
-- a key dressed under a standing runner is down at once and silent
hum.FloorMaterial=PLASTIC;plays={};put(cx(30),nil,2500);frames(14)
local rowT=g.RowOfZ(2500)
check(#plays==0 and near(topOf(rowT,g.ColOfX(cx(30)))or 99,F+C.PressedRise,1e-6),'a key dressed under a standing runner is down at once and silent ('..#plays..' clicks)')
end
-- 10. teardown
sc.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'the folder goes with the script')
local before2=#R.created;frames(30);check(#R.created==before2,'nothing runs after the script is destroyed')
check(nonRemote(),'still no RemoteEvent / RemoteFunction anywhere')
-- 11. no template: plain blocks, still works; columns on RunnerMotion.TrackCenterX
template.Parent=nil
RS:FindFirstChild('RunnerMotion'):SetAttribute('TrackCenterX',12)
local sc2=R.new('LocalScript');sc2.Name='KeyboardTrack'
check(pcall(W.load,'KeyboardTrackClient',sc2),'loads without the R142Keycap template')
put(cx(30)+12,nil,cz(BR));hum.FloorMaterial=PLASTIC;frames(60)
local vis2=workspace:FindFirstChild('KeyboardTrackVisuals');local k2=vis2 and vis2:FindFirstChild('Keys')
local nk=0;local allParts=true;for _,p in ipairs(k2:GetChildren())do if p.Name=='Key'and p.Transparency==0 then nk+=1;if p._class~='Part'then allParts=false end end end
check(k2 and nk==676 and allParts,'without the template the near keys are plain blocks ('..nk..')')
local fallbackLegend=false;for _,p in ipairs(k2:GetChildren())do local gui=p.Name=='Key'and p:FindFirstChildWhichIsA('SurfaceGui');if gui then local l=gui:FindFirstChildWhichIsA('TextLabel',true);if l and l.Text~=''and l.Rotation==180 then fallbackLegend=true end end end
check(fallbackLegend,'...with their own upright legends')
local shifted=false;for _,p in ipairs(k2:GetChildren())do if p.Name=='Key'and p.Transparency==0 and near(p.CFrame.Position.X,12+g.ColCenter(20),.01)then shifted=true end end
local bed2=vis2:FindFirstChild('Bed'):FindFirstChild('Bed1')
check(shifted and bed2 and near(bed2.CFrame.Position.X,12),'the columns and the bed are centred on RunnerMotion.TrackCenterX (12)')
RS:FindFirstChild('RunnerMotion'):SetAttribute('TrackCenterX',nil)
sc2.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'teardown again')
-- 12. the keycap template is still loading: the plain keys cover the near area meanwhile (no bare bed)
template.Parent=nil
do
 local origWait=R.Inst.WaitForChild
 R.Inst.WaitForChild=function(self,n,t)if n=='R142Keycap'then coroutine.yield()end;return origWait(self,n,t)end
 local scL=R.new('LocalScript');scL.Name='KeyboardTrack'
 check(pcall(W.load,'KeyboardTrackClient',scL),'loads while the keycap template is still replicating')
 put(cx(30),nil,cz(BR));hum.FloorMaterial=AIR;frames(60)
 local visL=workspace:FindFirstChild('KeyboardTrackVisuals')
 local meshL=0;for _,p in ipairs(visL:FindFirstChild('Keys'):GetChildren())do if p.Name=='Key'and p.Transparency==0 then meshL+=1 end end
 check(meshL==0,'no keycaps yet')
 local listL={};for _,f in ipairs(visL:GetChildren())do if f.Name=='Keys'or f.Name:find('^Blocks')then for _,p in ipairs(f:GetChildren())do if p.Transparency==0 then listL[#listL+1]=p end end end end
 local coverL=coverIndex(listL);local bareL=0
 for z=cz(BR)-60,cz(BR)+300,7.3 do for _,x in ipairs({-80.3,-41.1,-9.7,0.4,22.3,63.9,84.2})do if coverL(x,z+.0123)~=1 then bareL+=1 end end end
 check(bareL==0,'...and the plain keys cover the whole floor around the runner meanwhile ('..bareL..' bare probes)')
 scL.Destroying:Fire();frames(2)
 R.Inst.WaitForChild=origWait
end
-- 13. a map that describes only its first biome: built after a short wait
template.Parent=RS
for n=2,7 do map:SetAttribute('BiomeStartZ_'..n,nil);map:SetAttribute('BiomeEndZ_'..n,nil)end
local sc3=R.new('LocalScript');sc3.Name='KeyboardTrack'
check(pcall(W.load,'KeyboardTrackClient',sc3),'loads on a partly described map')
put(cx(30),nil,cz(BR));frames(60);check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'...it waits for the other biomes (1 s so far)')
R.advance(2);frames(60)
local vis3=workspace:FindFirstChild('KeyboardTrackVisuals')
check(vis3~=nil and #vis3:FindFirstChild('Keys'):GetChildren()>=676,'...and builds after the wait with what the map has')
local wides=0;for _,p in ipairs(vis3:FindFirstChild('Keys'):GetChildren())do if p.Name=='Spacebar'then wides+=1 end end
check(wides==1,'a one-biome map has one spacebar ('..wides..')')
sc3.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'and tears down')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
