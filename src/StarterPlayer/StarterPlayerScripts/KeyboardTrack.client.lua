-- R148 (owner playtest of R147): the candy keyboard runway covers the whole track floor, edge to edge, like the reference game
-- ("+1 Speed Keyboard Escape (Candy & Chocolate)"): small tightly packed keys, a letter on every near key, one colour family per biome
-- in four shades picked per key. Client only: no remotes, no server code, nothing collides or can be queried, the real floor is never
-- touched or hidden (the keys and a dark bed sit on top of it). The grid, colours, windows and budgets come from
-- ReplicatedStorage.KeyboardTrack (pure, tested over every position of the track).
--  * Layers around the runner, finest first: (0) keycap MeshParts cloned from ReplicatedStorage.R142Keycap (press, click, legend),
--    (1) plain block keys at the same pitch, (2..4) plain blocks covering 2x2, 4x4 and 8x8 keys with proportionally wider dark gaps.
--    Each layer is a rectangle (full width for the plain ones); a layer leaves out the cells the finer layer covers, snapped to its own
--    cell boundaries, so there is no overlap and no sliver. Cells are bound / released from free-lists (a moving window only touches the
--    cells that enter or leave) and every layer has its own per-frame budget; a ClientFxBudget tier change resizes the windows after it
--    has held 3 s and again only adds / removes the outer cells.
--  * Spacebars: one cream bar per biome start (the biome's first two rows, full width), always present, labelled with the biome name.
--  * Orientation: legends (and the spacebar label) are rotated 180 degrees on the Top face so a runner heading +Z reads them upright,
--    and column 1 is the +X edge so the keys read left -> right (Q W E R T Y ...).
--  * Presses: the local character every frame (Humanoid.FloorMaterial ~= Air), other players and keepers at 30 Hz. The union of pressed
--    keys is diffed with the last frame; only the changing keys animate (quad-out down, back-out up) via BulkMoveTo.
--  * Shovel holes: cells within 2 studs of a hole's Pit are left out at every layer while it exists (the hole parts are lifted by the
--    bed height so they sit above the dark bed); pack platforms clear the fine cells under them. Clicks: 10 pooled Sounds, rate limited.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService');local CS=game:GetService('CollectionService');local Content=game:GetService('ContentProvider')
local K=require(RS:WaitForChild('KeyboardTrack'))
local C=K.Config
local player=Players.LocalPlayer
local map=workspace:WaitForChild('ChestChaseMap')
local V3,V2,CF=Vector3.new,Vector2.new,CFrame.new
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local clock=os.clock
local F=C.FloorTop
local AIR=Enum.Material.Air
local BARBASE=1000                                   -- press index of spacebar i = BARBASE + i (mesh keys use their slot number)

local function optional(name)
 local m=RS:FindFirstChild(name);if not m then return nil end
 local ok,v=pcall(require,m);return ok and v or nil
end
local Fx,Mixer,Dash=optional('ClientFxBudget'),optional('AudioMixer'),optional('KeeperRecoveryDash')

local conns={};local folder;local started=false;local stopped=false
local function cleanup()
 stopped=true
 for _,c in ipairs(conns)do c:Disconnect()end;table.clear(conns)
 if folder then folder:Destroy();folder=nil end
end

local function start()
 if started or stopped then return end;started=true
 local Motion=RS:FindFirstChild('RunnerMotion')
 local centerX=Motion and Motion:GetAttribute('TrackCenterX')
 local geo=K.Geometry(map:GetAttributes(),type(centerX)=='number'and centerX or nil)
 if geo.Rows<1 then warn('[R148] keyboard: the map has no track rows');return end
 local H=K.Hierarchy(geo)
 local CX,COLS,P=geo.CenterX,geo.Cols,geo.Pitch
 local LEFT=CX+geo.HalfWidth                          -- the +X edge: column 1 is here, columns count toward -X
 local rowStage,barOfRow=geo.RowStage,geo.BarOfRow
 local ord1=H.Ord[1]

 folder=Instance.new('Folder');folder.Name='KeyboardTrackVisuals';folder.Parent=workspace
 local function sub(name,parent)local f=Instance.new('Folder');f.Name=name;f.Parent=parent or folder;return f end
 local bedFolder,keyFolder,soundFolder,legendHolder=sub('Bed'),sub('Keys'),sub('Sounds'),sub('Legends')
 local function flat(p)
  p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 end
 local function block(name,size,cframe,rgb,parent)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cframe;p.Color=Color3.fromRGB(rgb[1],rgb[2],rgb[3])
  p.Material=Enum.Material.SmoothPlastic;flat(p);p.Parent=parent;return p
 end

 -- The dark bed under the keys: the gaps between them, no grass. A few long pieces over the whole key area, clearly above the floor.
 for i,seg in ipairs(K.Segments(geo.Z0,geo.KeyEndZ,C.BedMaxLength))do
  block('Bed'..i,V3(geo.HalfWidth*2,C.BedThickness,seg.Length),CF(CX,F+C.BedRise-C.BedThickness/2,seg.Centre),C.BedColor,bedFolder)
 end

 -- State -----------------------------------------------------------------------------------------------------
 local focusX,focusZ,hasRoot=CX,geo.Z0,false
 local focusRow,focusCol=1,1
 local charRef,rootRef,humRef
 local now,frameNo,reduced=clock(),0,false
 local tier,wantTier,wantSince=0,0,0
 local tierCfg=K.Tier(3)
 local wins={}
 local templateReady=false;local template=nil;local legendProto=nil
 -- press state per index (mesh slot or BARBASE + bar): part, centre, depth 0..1, height fudge, dress frame
 local kPart,kX,kZ,kDepth,kOff,kFresh={},{},{},{},{},{}
 local downPos,animPos,animT0,animFrom,animTo,animDur={},{},{},{},{},{}
 local stampAt,moveMark={},{}
 local downList,animList,moveList={},{},{}
 local moveN=0;local moveParts,moveCFs={},{}
 local stN=0;local stP,stC={},{}                      -- static moves (plain blocks)
 local oRow,oCol,oKind,oX,oZ,oN={},{},{},{},{},0       -- cells other players / keepers press (30 Hz)
 local keepers={}
 local holeRects,platRects={},{};local clearSig=nil;local holesFolder=nil
 local barHidden={}

 -- Lists with O(1) removal --------------------------------------------------------------------------------------
 local function listAdd(list,pos,idx)local n=#list+1;list[n]=idx;pos[idx]=n end
 local function listRemove(list,pos,idx)
  local n=#list;local at=pos[idx];local last=list[n]
  list[at]=last;pos[last]=at;list[n]=nil;pos[idx]=nil
 end
 local function queueMove(idx)
  if moveMark[idx]~=frameNo then moveMark[idx]=frameNo;moveN+=1;moveList[moveN]=idx end
 end
 local function flushMoves()
  if moveN>0 then
   for i=1,moveN do
    local idx=moveList[i];moveParts[i]=kPart[idx];moveCFs[i]=CF(kX[idx],K.KeyTop(kDepth[idx])-C.KeyY/2+kOff[idx],kZ[idx])
   end
   for i=#moveParts,moveN+1,-1 do moveParts[i]=nil;moveCFs[i]=nil end
   workspace:BulkMoveTo(moveParts,moveCFs,Enum.BulkMoveMode.FireCFrameChanged)
   moveN=0
  end
  if stN>0 then
   for i=#stP,stN+1,-1 do stP[i]=nil;stC[i]=nil end
   workspace:BulkMoveTo(stP,stC,Enum.BulkMoveMode.FireCFrameChanged)
   stN=0
  end
 end
 local function clearKeyState(idx)
  if downPos[idx]then listRemove(downList,downPos,idx)end
  if animPos[idx]then listRemove(animList,animPos,idx)end
  kDepth[idx]=0
 end

 -- Legends (a pool of SurfaceGuis lent to the keys nearest the runner) ------------------------------------------
 local inkColor={}
 for stage,z in pairs(K.Zones)do inkColor[stage]=Color3.fromRGB(z.Ink[1],z.Ink[2],z.Ink[3])end
 inkColor[0]=Color3.fromRGB(K.Fallback.Ink[1],K.Fallback.Ink[2],K.Fallback.Ink[3])
 local creamInk=Color3.fromRGB(K.CreamInk[1],K.CreamInk[2],K.CreamInk[3])
 -- Text sits on the Top face with its up toward -Z and its reading direction toward +X; turning it half a way round (about the label's
 -- centre) makes it upright for a runner facing +Z, reading toward -X = his right.
 local function upright(label)
  label.AnchorPoint=V2(.5,.5);label.Position=UDim2.fromScale(.5,.5);label.Rotation=180
 end
 local function newLegendGui()
  local gui=legendProto and legendProto:Clone()
  if not gui then
   gui=Instance.new('SurfaceGui');gui.Name='KeyLegend';gui.Face=Enum.NormalId.Top;gui.LightInfluence=0;gui.AlwaysOnTop=false
   gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=V2(256,256)
  end
  local label=gui:FindFirstChildWhichIsA('TextLabel',true)
  if not label then
   label=Instance.new('TextLabel');label.Name='Letter';label.BackgroundTransparency=1;label.BorderSizePixel=0
   label.Size=UDim2.fromScale(1,1);label.Font=Enum.Font.FredokaOne;label.TextScaled=true;label.TextStrokeTransparency=1;label.Parent=gui
  end
  upright(label);gui.Enabled=true;gui.Parent=legendHolder
  return {Gui=gui,Label=label,Slot=0,Key=0}
 end
 local legendFree,legendFreeN,legendMade={},0,0
 local legendList,legendPos,legendOf={},{},{}        -- active entries; entry -> position; mesh slot -> entry
 local function dropLegend(slot)
  local e=legendOf[slot];if not e then return end
  legendOf[slot]=nil;listRemove(legendList,legendPos,e)
  e.Gui.Parent=legendHolder;e.Slot=0;e.Key=0
  legendFreeN+=1;legendFree[legendFreeN]=e
 end

 -- Layers ----------------------------------------------------------------------------------------------------------
 local maxPlan=K.Tier(3).Layers
 local layers={}
 local meshLayer
 local meshBound,plainBound=0,0
 local progress=false                              -- some cell was bound or released this frame
 local keptMesh,keptPlain=0,0                    -- cells held last frame only to avoid a gap: they do not count against the caps
 local function makeMeshPart(slot)
  local part=template and template:Clone()or Instance.new('Part')
  part.Name='Key';flat(part);part.Size=V3(K.KeySize(),C.KeyY,K.KeySize());part.Transparency=1;part.CFrame=CF(CX,F-200,0)
  for _,d in ipairs(part:GetDescendants())do if d:IsA('BaseScript')or d:IsA('Sound')or d:IsA('SurfaceGui')then d:Destroy()end end
  part.Parent=keyFolder
  kPart[slot]=part;kX[slot]=CX;kZ[slot]=0;kDepth[slot]=0;kOff[slot]=C.TopOffset;kFresh[slot]=0
  return part
 end
 local function makePlainPart(L)
  local p=Instance.new('Part');p.Name='K'..L.M;p.Size=V3(K.KeySize()*L.M,C.BlockY,K.KeySize()*L.M);p.Transparency=1
  p.Material=Enum.Material.SmoothPlastic;flat(p);p.CFrame=CF(CX,F-200,0);p.Parent=L.Folder
  return p
 end
 for j,pl in ipairs(maxPlan)do
  local L={I=j,M=pl.M,Kind=pl.Kind,Lv=H[pl.M],NCols=(COLS+pl.M-1)//pl.M,GapM=C.Gap*pl.M,
   Folder=pl.Kind=='plain'and sub('Blocks'..j,folder)or nil,
   Part={},SKey={},SW={},SD={},Free={},FreeN=0,Made=0,SlotOf={},Act={},ActPos={},
   Blocked={},BlockedDirty=true,Pending=true,PendingRel=false,Dirty=true,GateFrames=0,Kept=0,
   A=0,B=-1,CA=0,CB=-1,HasHole=false,HA=0,HB=-1,HCA=0,HCB=-1}
  if pl.Kind=='mesh'then L.Part=kPart;meshLayer=L end
  layers[j]=L
 end

 local function releaseCell(L,slot)
  progress=true
  local key=L.SKey[slot]
  L.SlotOf[key]=nil;L.SKey[slot]=0
  listRemove(L.Act,L.ActPos,slot)
  L.Part[slot].Transparency=1
  L.FreeN+=1;L.Free[L.FreeN]=slot
  if L.Kind=='mesh'then dropLegend(slot);clearKeyState(slot);meshBound-=1 else plainBound-=1 end
 end
 -- Bind cell (group g, column group cg) of layer L: position, size, colour.
 local function acquireCell(L,g,cg)
  local isMesh=L.Kind=='mesh'
  -- (until the keycap template is there the plain blocks also cover the area the keycaps will take, so they may use that share of the cap)
  if isMesh then if meshBound-keptMesh>=tierCfg.Mesh then return false end
  elseif plainBound-keptPlain>=tierCfg.Plain+(templateReady and 0 or tierCfg.Mesh)then return false end
  local slot
  if L.FreeN>0 then slot=L.Free[L.FreeN];L.Free[L.FreeN]=nil;L.FreeN-=1
  else
   slot=L.Made+1;L.Made=slot
   if isMesh then makeMeshPart(slot)else L.Part[slot]=makePlainPart(L);L.SW[slot]=K.KeySize()*L.M;L.SD[slot]=K.KeySize()*L.M end
  end
  progress=true
  local key=g*64+cg
  local lv,m=L.Lv,L.M
  local r0,r1=lv.R0[g],lv.R1[g]
  local zmin=geo.RowZ(r0);local _,zmax=geo.RowZ(r1)
  local c0=(cg-1)*m+1;local c1=min(COLS,cg*m)
  local x=LEFT-((c0-1)+(c1-c0+1)/2)*P
  local z=(zmin+zmax)/2
  local part=L.Part[slot]
  L.SlotOf[key]=slot;L.SKey[slot]=key;listAdd(L.Act,L.ActPos,slot)
  -- a block takes the colour of its first key (row r0, column c0): when a layer hands a cell to a finer one a quarter of the area keeps
  -- its colour, so the swap is hard to see, yet far blocks keep the full spread of shades (no averaging into flat bands)
  part.Color=K.CellColor(rowStage[r0],r0,c0,1)
  part.Transparency=0
  if isMesh then
   kX[slot]=x;kZ[slot]=z;kDepth[slot]=0;kFresh[slot]=frameNo;meshBound+=1
   queueMove(slot)
  else
   local w=(c1-c0+1)*P-L.GapM;local d=(zmax-zmin)-L.GapM
   if abs(L.SW[slot]-w)>1e-6 or abs(L.SD[slot]-d)>1e-6 then L.SW[slot]=w;L.SD[slot]=d;part.Size=V3(w,C.BlockY,d)end
   plainBound+=1
   stN+=1;stP[stN]=part;stC[stN]=CF(x,K.BlockCenterY(L.I),z)
  end
  return true
 end
 -- Window state of a layer for this frame (the plan: K.Windows).
 local function loadWindow(L,w)
  local hole=w.HasHole
  local ha,hb,hca,hcb=0,-1,0,-1
  if hole then local h=w.Hole;ha,hb,hca,hcb=h.A,h.B,h.CA,h.CB end
  if L.BlockedDirty or L.A~=w.A or L.B~=w.B or L.CA~=w.CA or L.CB~=w.CB or L.HasHole~=hole or(hole and(L.HA~=ha or L.HB~=hb or L.HCA~=hca or L.HCB~=hcb))then L.Dirty=true end
  L.A,L.B,L.CA,L.CB,L.HasHole,L.HA,L.HB,L.HCA,L.HCB=w.A,w.B,w.CA,w.CB,hole,ha,hb,hca,hcb
  L.BlockedDirty=false
 end
 -- Is the region of cell (g, cg) of layer j wholly drawn by bound cells of the finer layers? (cleared cells count as drawn: the gap is meant)
 local function coveredBelow(j,g,cg)
  local f=layers[j-1];if not f then return false end
  local L=layers[j]
  if f.M==L.M then
   local key=g*64+cg
   return f.SlotOf[key]~=nil or f.Blocked[key]==true or coveredBelow(j-1,g,cg)
  end
  local ord=H.Ord[f.M];local lv=L.Lv
  local o0,o1=ord[lv.R0[g]],ord[lv.R1[g]]
  local c0,c1=(cg-1)*2+1,min(f.NCols,cg*2)
  for gg=o0,o1 do for cc=c0,c1 do
   local key=gg*64+cc
   if not(f.SlotOf[key]~=nil or f.Blocked[key]==true or coveredBelow(j-1,gg,cc))then return false end
  end end
  return true
 end
 -- The cell of layer k (coarser than j) that holds cell (g, cg) of layer j.
 local function aboveKey(j,g,cg,k)
  local L=layers[j];local Lk=layers[k]
  return H.Ord[Lk.M][L.Lv.R0[g]]*64+((cg-1)*L.M)//Lk.M+1
 end
 local function boundAbove(j,g,cg)
  for k=j+1,#layers do
   local Lk=layers[k];local key=aboveKey(j,g,cg,k)
   if Lk.SlotOf[key]~=nil or Lk.Blocked[key]==true then return true end
  end
  return false
 end
 local function insideOuter(j,g,cg)
  local n=#layers;if j>=n then return false end
  local O=layers[n];local key=aboveKey(j,g,cg,n);local og,ocg=key//64,key%64
  return og>=O.A and og<=O.B and ocg>=O.CA and ocg<=O.CB
 end
 -- Bind what the plan wants and the layer lacks, nearest rows first (budgeted). Cells are never left bare: a coarser cell stays until
 -- the finer cells that replace it are bound, a finer cell stays until the coarser one that replaces it is (see releasePass).
 local function acquirePass(L,budget)
  L.Pending=false
  local a,b,ca,cb=L.A,L.B,L.CA,L.CB
  if b<a or cb<ca then return end
  local hole=L.HasHole;local ha,hb,hca,hcb=L.HA,L.HB,L.HCA,L.HCB
  local blocked,slotOf=L.Blocked,L.SlotOf
  local center=max(a,min(b,K.NearestOrd(H,L.M,focusRow)))
  local used=0
  for d=0,max(center-a,b-center)do
   for sign=1,(d==0 and 1 or 2)do
    local g=sign==1 and center+d or center-d
    if g>=a and g<=b then
     local holeRow=hole and g>=ha and g<=hb
     for cg=ca,cb do
      if not(holeRow and cg>=hca and cg<=hcb)then
       local key=g*64+cg
       if not slotOf[key]and not blocked[key]then
        if used<budget and acquireCell(L,g,cg)then used+=1 else L.Pending=true end
       end
      end
     end
    end
   end
  end
 end
 -- Release what the plan no longer wants - but only once the region is drawn some other way (a gap would show the dark bed). Two kinds:
 --  * outside the layer's window (the runner moved on): kept until a coarser cell holds the region; cleared cells (holes, platforms) go at once;
 --  * inside the window but under the finer layer's hole: kept until the finer cells that replace it are bound (they sit higher, so the overlap
 --    never z-fights).
 -- A cell stuck for GateStallFrames is released anyway.
 local function releaseOutside(L)
  local force=L.GateFrames>=C.GateStallFrames
  local j=L.I
  for i=#L.Act,1,-1 do
   local slot=L.Act[i];local key=L.SKey[slot];local g=key//64;local cg=key%64
   if L.Blocked[key]then releaseCell(L,slot)
   elseif g<L.A or g>L.B or cg<L.CA or cg>L.CB then
    if not force and insideOuter(j,g,cg)and not boundAbove(j,g,cg)then L.Kept+=1 else releaseCell(L,slot)end
   end
  end
 end
 local function releaseHole(L)
  if not L.HasHole then return end
  local force=L.GateFrames>=C.GateStallFrames
  local j=L.I;local ha,hb,hca,hcb=L.HA,L.HB,L.HCA,L.HCB
  for i=#L.Act,1,-1 do
   local slot=L.Act[i];local key=L.SKey[slot];local g=key//64;local cg=key%64
   if g>=ha and g<=hb and cg>=hca and cg<=hcb and g>=L.A and g<=L.B and cg>=L.CA and cg<=L.CB then
    if force or coveredBelow(j,g,cg)then releaseCell(L,slot)else L.Kept+=1 end
   end
  end
 end
 -- Spacebars: one cream bar per biome start, always present ------------------------------------------------------
 local bars=geo.Bars
 local cr,cg2,cb2=K.CreamRGB()
 local function makeBar(i,bar)
  local depth=(bar.Z1-bar.Z0)-C.Gap
  local p=Instance.new('Part');p.Name='Spacebar';p.Size=V3(geo.HalfWidth*2-C.Gap,C.KeyY,depth);p.Color=Color3.fromRGB(cr,cg2,cb2)
  p.Material=Enum.Material.SmoothPlastic;flat(p);p.CFrame=CF(CX,F-200,0);p.Parent=keyFolder
  local gui=Instance.new('SurfaceGui');gui.Name='SpacebarLegend';gui.Face=Enum.NormalId.Top;gui.LightInfluence=0;gui.AlwaysOnTop=false
  gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=8;gui.Parent=p
  local label=Instance.new('TextLabel');label.Name='Biome';label.BackgroundTransparency=1;label.BorderSizePixel=0
  label.Size=UDim2.fromScale(1,1);label.Font=Enum.Font.FredokaOne;label.TextScaled=true;label.TextStrokeTransparency=1
  label.Text=string.upper(bar.Name);label.TextColor3=creamInk;upright(label);label.Parent=gui
  local idx=BARBASE+i
  kPart[idx]=p;kX[idx]=CX;kZ[idx]=(bar.Z0+bar.Z1)/2;kDepth[idx]=0;kOff[idx]=0;kFresh[idx]=0
  barHidden[i]=false
  queueMove(idx);p.Transparency=0
 end
 for i,bar in ipairs(bars)do makeBar(i,bar)end
 local function setBarHidden(i,hidden)
  if barHidden[i]==hidden then return end
  barHidden[i]=hidden;kPart[BARBASE+i].Transparency=hidden and 1 or 0
  local gui=kPart[BARBASE+i]:FindFirstChildWhichIsA('SurfaceGui');if gui then gui.Enabled=not hidden end
  if hidden then clearKeyState(BARBASE+i);queueMove(BARBASE+i)end
 end

 -- Template (the keycap mesh) ------------------------------------------------------------------------------------
 task.spawn(function()
  local found=RS:FindFirstChild('R142Keycap')
  if not found then local ok,t=pcall(function()return RS:WaitForChild('R142Keycap',30)end);if ok and typeof(t)=='Instance'then found=t end end
  if stopped then return end
  template=found;legendProto=found and found:FindFirstChildWhichIsA('SurfaceGui')or nil;templateReady=true
  if not found then warn('[R148] keyboard: ReplicatedStorage.R142Keycap is missing; using plain blocks for the near keys')end
 end)

 -- Legend pass: the keys nearest the runner carry their letter (a pooled SurfaceGui is lent to each) ---------------
 local function legendPass()
  local radius=tierCfg.LegendRadius;local r2=radius*radius;local hold=(radius+P)*(radius+P)
  local L=meshLayer
  for i=#legendList,1,-1 do
   local e=legendList[i];local slot=e.Slot
   local dx,dz=kX[slot]-focusX,kZ[slot]-focusZ
   local d2=dx*dx+dz*dz
   -- a little hysteresis; a smaller tier (fewer legends, smaller radius) drops everything outside its radius at once
   if d2>hold or(d2>r2 and #legendList>tierCfg.Legends)then dropLegend(slot)end
  end
  local w=wins[1]
  if not w or w.B<w.A or not templateReady then return end
  local lv=H[1];local center=K.NearestOrd(H,1,focusRow);local reach=math.ceil(radius/P)+1
  local ga,gb=max(w.A,center-reach),min(w.B,center+reach)
  local ca,cb=max(w.CA,focusCol-reach),min(w.CB,focusCol+reach)
  local changes=0
  for g=ga,gb do
   for c=ca,cb do
    local slot=L.SlotOf[g*64+c]
    if slot and not legendOf[slot]then
     local dx,dz=kX[slot]-focusX,kZ[slot]-focusZ
     if dx*dx+dz*dz<=r2 then
      local e
      if legendFreeN>0 then e=legendFree[legendFreeN];legendFree[legendFreeN]=nil;legendFreeN-=1
      elseif legendMade<tierCfg.Legends then legendMade+=1;e=newLegendGui()end
      if not e then return end
      if #legendList>=tierCfg.Legends then legendFreeN+=1;legendFree[legendFreeN]=e;return end
      local row=lv.R0[g]
      e.Slot=slot;e.Key=g*64+c;legendOf[slot]=e;listAdd(legendList,legendPos,e)
      e.Label.Text=K.Legend(row,c);e.Label.TextColor3=inkColor[rowStage[row]]or inkColor[0]
      e.Gui.Parent=kPart[slot]
      changes+=1
      if changes>=C.MaxLegendChangesPerFrame then return end
     end
    end
   end
  end
 end

 -- Clicks ---------------------------------------------------------------------------------------------------------
 local ownLimit,otherLimit=K.NewLimiter(C.OwnClicksPerSecond),K.NewLimiter(C.OtherClicksPerSecond)
 local sounds={};local soundNext=1;local pitchN=0
 local OR2=C.OtherClickRange*C.OtherClickRange
 for i=1,10 do
  local anchor=Instance.new('Part');flat(anchor);anchor.Name='KeyClick';anchor.Size=V3(.2,.2,.2);anchor.Transparency=1;anchor.Parent=soundFolder
  local sound=Instance.new('Sound');sound.Name='KeyClickSound';sound.SoundId='rbxassetid://'..tostring(C.ClickSoundIds[(i-1)%#C.ClickSoundIds+1])
  sound.Volume=C.ClickVolume;sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.RollOffMinDistance=14;sound.RollOffMaxDistance=90
  sound.Parent=anchor
  if Mixer and type(Mixer.Route)=='function'then pcall(Mixer.Route,sound,'Effects')end
  sounds[i]={Part=anchor,Sound=sound}
 end
 task.spawn(function()
  local list={};for _,e in ipairs(sounds)do list[#list+1]=e.Sound end
  pcall(function()Content:PreloadAsync(list)end)
 end)
 local function click(kind,x,z)
  if Mixer and type(Mixer.Get)=='function'and Mixer.Get('Effects')==0 then return end
  local own=kind==1
  if not own then local dx,dz=x-focusX,z-focusZ;if dx*dx+dz*dz>OR2 then return end end
  if not K.Allow(own and ownLimit or otherLimit,now)then return end
  -- next idle Sound in round-robin order (so the three recordings alternate), else steal the oldest
  local pick
  for i=0,#sounds-1 do
   local at=(soundNext-1+i)%#sounds+1
   if not sounds[at].Sound.Playing then pick=sounds[at];soundNext=at%#sounds+1;break end
  end
  if not pick then pick=sounds[soundNext];soundNext=soundNext%#sounds+1;pick.Sound:Stop()end
  pitchN=pitchN%#C.ClickPitches+1
  pick.Part.CFrame=CF(x,F+1,z)
  pick.Sound.PlaybackSpeed=kind==3 and C.KeeperPitch or C.ClickPitches[pitchN]
  pick.Sound.Volume=own and C.ClickVolume or C.ClickVolume*.6
  pick.Sound.TimePosition=0;pick.Sound:Play()
 end

 -- Presses --------------------------------------------------------------------------------------------------------
 local function startAnim(idx,to)
  local from=kDepth[idx];local span=min(1,abs(to-from))
  animFrom[idx]=from;animTo[idx]=to;animT0[idx]=now
  animDur[idx]=to==1 and max(C.PressSeconds*span,.015)or max(C.ReleaseSeconds*max(span,.35),.04)
  if not animPos[idx]then listAdd(animList,animPos,idx)end
 end
 local function pressKey(idx,kind,px,pz)
  listAdd(downList,downPos,idx)
  if kFresh[idx]==frameNo then
   -- a key dressed this very frame under a standing runner: down at once and silent (a tier change must not click 700 times)
   if animPos[idx]then listRemove(animList,animPos,idx)end
   kDepth[idx]=1;queueMove(idx)
  else
   startAnim(idx,1) -- Reduced Motion: animate() finishes it in the same frame
   if idx>=BARBASE then click(kind,px,pz)else click(kind,kX[idx],kZ[idx])end
  end
 end
 local function releaseKey(idx)
  listRemove(downList,downPos,idx)
  startAnim(idx,0)
 end
 local function touch(idx,kind,px,pz)
  if stampAt[idx]==frameNo then return end
  stampAt[idx]=frameNo
  if not downPos[idx]then pressKey(idx,kind,px,pz)end
 end
 -- A fine cell (row, column) is pressed by `kind`; px, pz = where the presser stands.
 local function pressCell(row,col,kind,px,pz)
  local bar=barOfRow[row]
  if bar then
   if not barHidden[bar]then touch(BARBASE+bar,kind,px,pz)end
  else
   local g=ord1[row]
   if g then local slot=meshLayer.SlotOf[g*64+col];if slot then touch(slot,kind,px,pz)end end
  end
 end
 local function animate()
  local ease=K.Ease
  for i=#animList,1,-1 do
   local idx=animList[i]
   local to=animTo[idx]
   local t=(now-animT0[idx])/animDur[idx]
   if t>=1 or reduced then kDepth[idx]=to;listRemove(animList,animPos,idx)
   else kDepth[idx]=animFrom[idx]+(to-animFrom[idx])*(to==1 and ease.QuadOut(t)or ease.BackOut(t))end
   queueMove(idx)
  end
 end

 -- Other players and keepers (30 Hz) ------------------------------------------------------------------------------
 local function addFootprint(x,z,half,kind)
  local c1,c2,r1,r2=geo.CellRange(x-half,x+half,z-half,z+half)
  for r=r1,r2 do for c=c1,c2 do
   if oN<512 then oN+=1;oRow[oN]=r;oCol[oN]=c;oKind[oN]=kind;oX[oN]=x;oZ[oN]=z end
  end end
 end
 local function refreshKeeper(model,rec)
  local ok,ext=pcall(model.GetExtentsSize,model)
  if ok and ext then rec.Half=K.KeeperFootprint(ext.X,ext.Z);rec.ExtY=ext.Y end
 end
 local function addKeeper(model)
  if keepers[model]or not model:IsA('Model')or not model:IsDescendantOf(workspace)then return end
  local rec={Half=C.KeeperMinFootprint,ExtY=6};keepers[model]=rec;refreshKeeper(model,rec)
 end
 local function scanKeepers()
  for _,m in ipairs(CS:GetTagged('BiomeKeeper'))do addKeeper(m)end
  local camps=map:FindFirstChild('GuardianEncounters')
  if camps then for _,m in ipairs(camps:GetChildren())do if m:GetAttribute('PersistentBiomeGuardian')then addKeeper(m)end end end
  local function runtime(r)if r then for _,m in ipairs(r:GetChildren())do if m:GetAttribute('VeiledKeeper81')or m:GetAttribute('PersistentBiomeGuardian')then addKeeper(m)end end end end
  runtime(map:FindFirstChild('_GameplayRuntime'));runtime(workspace:FindFirstChild('_GameplayRuntime'))
  for model,rec in pairs(keepers)do if not model:IsDescendantOf(workspace)then keepers[model]=nil else refreshKeeper(model,rec)end end
 end
 local function sampleOthers()
  oN=0
  local range=tierCfg.Layers[1].Ahead*P+60
  for _,p in ipairs(Players:GetPlayers())do
   if p~=player then
    local char=p.Character
    local root=char and char:FindFirstChild('HumanoidRootPart');local hum=char and char:FindFirstChildOfClass('Humanoid')
    if root and hum and hum.Health>0 then
     local pos=root.Position
     if abs(pos.Z-focusZ)<=range and pos.Y-C.PlayerRootToFeet<=F+C.PlayerFeetReach then addFootprint(pos.X,pos.Z,C.PlayerFootprint,2)end
    end
   end
  end
  local serverNow=workspace:GetServerTimeNow()
  for model,rec in pairs(keepers)do
   if not model:IsDescendantOf(workspace)then keepers[model]=nil
   else
    local root=model.PrimaryPart or model:FindFirstChild('HumanoidRootPart')
    if root then
     local frame=root.CFrame
     if Dash and Dash.VisualFrame then
      local ok,f=pcall(Dash.VisualFrame,model,serverNow,frame);if ok and typeof(f)=='CFrame'then frame=f end
     end
     local pos=frame.Position
     if abs(pos.Z-focusZ)<=range+200 and pos.Y-rec.ExtY*.5<=F+C.PlayerFeetReach then addFootprint(pos.X,pos.Z,rec.Half,3)end
    end
   end
  end
 end

 -- Clearances: shovel holes (every layer) and pack platforms (fine layers) leave their cells out ------------------
 -- TrackHoleService: Folder 'TrackHoles' in the map's _GameplayRuntime, a Model per hole with a 'Pit' part (+ Rim, crumbs).
 local function findHoles()
  if holesFolder and holesFolder:IsDescendantOf(workspace)then return holesFolder end
  local runtime=map:FindFirstChild('_GameplayRuntime')
  holesFolder=runtime and runtime:FindFirstChild('TrackHoles')
  if not holesFolder then runtime=workspace:FindFirstChild('_GameplayRuntime');holesFolder=runtime and runtime:FindFirstChild('TrackHoles')end
  if not holesFolder then holesFolder=map:FindFirstChild('TrackHoles',true)end
  return holesFolder
 end
-- The hole parts were authored to sit a few hundredths above the floor; every part is lifted above the dark bed, once per PART (a part
 -- streamed in again is a new instance at the server height). TrackHoleClient.grow tweens crumbs back to the frames it captured, which can
 -- undo a lift for 0.3 s: a part found again at its server height is lifted again. Lifting is relative to the part's current position.
 local liftBase,liftSet=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
 local function liftPart(d)
  if not d:IsA('BasePart')then return end
  local y=d.Position.Y;local base=liftBase[d]
  if not base then
   liftBase[d]=y;liftSet[d]=y+C.BedRise;d.Position=d.Position+V3(0,C.BedRise,0)
  elseif abs(y-liftSet[d])>1e-3 and abs(y-base)<1e-3 then
   d.Position=d.Position+V3(0,C.BedRise,0)
  end
 end
 local function liftAny(d)
  if d:IsA('BasePart')then liftPart(d)
  elseif d:IsA('Model')then for _,x in ipairs(d:GetDescendants())do liftPart(x)end end
 end
 local liftHook,liftHooked=nil,nil
 local function rebuildBlocked()
  for _,L in ipairs(layers)do
   local set={};local m=L.M;local ord=H.Ord[m]
   local function mark(rect)
    local c1,c2,r1,r2=geo.CellRange(rect[1],rect[2],rect[3],rect[4])
    if c1>c2 then return end
    for r=r1,r2 do
     local g=ord[r]
     if g then for cg=(c1-1)//m+1,(c2-1)//m+1 do set[g*64+cg]=true end end
    end
   end
   for _,rect in ipairs(holeRects)do mark(rect)end
   if m==1 then for _,rect in ipairs(platRects)do mark(rect)end end
   L.Blocked=set;L.BlockedDirty=true
  end
  for i,bar in ipairs(bars)do
   local hide=false
   for _,rect in ipairs(holeRects)do
    local c1,c2,r1,r2=geo.CellRange(rect[1],rect[2],rect[3],rect[4])
    if c1<=c2 and r2>=bar.Row0 and r1<=bar.Row1 then hide=true;break end
   end
   setBarHidden(i,hide)
  end
 end
 local function scanClearances()
  local sig=0;local nh,np=0,0
  local f=findHoles()
  local holes={}
  if f and f~=liftHooked then
   -- parts that appear later (streamed in, rebuilt) are lifted at once, not on the next scan
   if liftHook then liftHook:Disconnect()end
   liftHooked=f;liftHook=f.DescendantAdded:Connect(liftAny);table.insert(conns,liftHook)
  end
  if f then
   for _,model in ipairs(f:GetChildren())do
    local pit=model:FindFirstChild('Pit')
    if pit then
     holes[#holes+1]=pit
     for _,d in ipairs(model:GetDescendants())do liftPart(d)end
    end
   end
  end
  local R=C.HoleReach
  local newHoles={}
  for i,pit in ipairs(holes)do
   local pos=pit.Position;newHoles[i]={pos.X-R,pos.X+R,pos.Z-R,pos.Z+R}
   sig=(sig*31+floor(pos.X*8)*7+floor(pos.Z*8)*13+1)%1000000007;nh+=1
  end
  local newPlat={}
  local seeds=map:FindFirstChild('Seeds')
  if seeds then
   for _,seed in ipairs(seeds:GetChildren())do
    local plat=seed:FindFirstChild('PackPlatform')
    if plat then
     local radius=plat:GetAttribute('PlatformRadius')
     local root=plat.PrimaryPart or plat:FindFirstChildWhichIsA('BasePart')
     if type(radius)=='number'and root then
      local pos=root.Position;local rr=radius+C.PlatformClearance
      newPlat[#newPlat+1]={pos.X-rr,pos.X+rr,pos.Z-rr,pos.Z+rr}
      sig=(sig*37+floor(pos.X*8)*11+floor(pos.Z*8)*17+floor(radius*8)+3)%1000000007;np+=1
     end
    end
   end
  end
  sig=sig*7+nh*1000+np
  if sig==clearSig then return end
  clearSig=sig;holeRects,platRects=newHoles,newPlat
  rebuildBlocked()
 end

 -- Frame ---------------------------------------------------------------------------------------------------------
 local tTier,tClear,tKeeper,tSample=0,0,0,0
 local function updateFocus()
  local char=player.Character
  if char~=charRef then charRef=char;rootRef=nil;humRef=nil end
  if char then
   if not rootRef or not rootRef.Parent then rootRef=char:FindFirstChild('HumanoidRootPart')end
   if not humRef or not humRef.Parent then humRef=char:FindFirstChildOfClass('Humanoid')end
  end
  if rootRef then
   local p=rootRef.Position;focusX,focusZ,hasRoot=p.X,p.Z,true
  else
   hasRoot=false
   local cam=workspace.CurrentCamera
   if cam then local p=(cam.Focus or cam.CFrame).Position;focusX,focusZ=p.X,p.Z end
  end
  local r=geo.RowOfZ(focusZ);focusRow=max(1,min(geo.Rows,r))
  focusCol=max(1,min(COLS,geo.ColOfX(focusX)))
 end
 local BM=C.MaxReassignPerFrame
 local function step(dt)
  now=clock();frameNo+=1;reduced=Gui.ReducedMotionEnabled==true
  updateFocus()
  tTier+=dt;tClear+=dt;tKeeper+=dt;tSample+=dt
  if tier==0 or tTier>=.5 then
   tTier=0
   local want=Fx and Fx.Get()or 3
   if tier==0 then tier=want;wantTier=want;wantSince=now;tierCfg=K.Tier(tier)
   elseif want~=wantTier then wantTier=want;wantSince=now end
   -- a tier change only applies once it has held for a few seconds (a device bouncing between tiers must not flicker)
   if wantTier~=tier and now-wantSince>=C.TierHoldSeconds then tier=wantTier;tierCfg=K.Tier(tier)end
  end
  if tClear>=.25 then tClear=0;scanClearances()end
  if tKeeper>=2 then tKeeper=0;scanKeepers()end
  K.Windows(geo,H,tier,focusRow,focusCol,wins)
  if not templateReady then
   -- no keycaps yet: the plain layer next to them covers their area meanwhile
   wins[1].B=wins[1].A-1;if wins[2]then wins[2].HasHole=false end
  end
  for j=1,#layers do loadWindow(layers[j],wins[j])end
  -- cell bindings per layer this frame; a slower frame (more distance covered) gets proportionally more
  local scale=min(2,max(1,dt*60))
  local bMesh,bPlain,bCoarse=floor(BM.mesh*scale),floor(BM.plain*scale),floor(BM.coarse*scale)
  local n=#layers
  -- coarse to fine: a cell that left its window goes once the coarser layer holds its region (that layer was just served), freeing
  -- room before the layer binds what entered; then fine to coarse: cells under a finer window go once the finer cells are bound
  for j=n,1,-1 do
   local L=layers[j]
   if L.Kind~='mesh'or templateReady then
    L.Kept=0
    if L.Dirty or L.PendingRel then releaseOutside(L)end
    if L.Dirty or L.Pending then acquirePass(L,L.Kind=='mesh'and bMesh or L.M==1 and bPlain or bCoarse)end
   end
  end
  keptMesh,keptPlain=0,0
  for j=1,n do
   local L=layers[j]
   if L.Kind~='mesh'or templateReady then
    if L.Dirty or L.PendingRel then releaseHole(L)end
    if L.Kind=='mesh'then keptMesh+=L.Kept else keptPlain+=L.Kept end
    L.PendingRel=L.Kept>0
    L.Dirty=false
   end
  end
  -- the stall valve: layers that keep cells while nothing at all is being bound or released are stuck (cap deadlock): after a while let go
  for j=1,n do local L=layers[j];if L.PendingRel and not progress then L.GateFrames+=1 else L.GateFrames=0 end end
  progress=false
  -- presses: the local runner every frame, everyone else from the last 30 Hz sample
  if tSample>=1/C.PlayerSampleHz then tSample=tSample%(1/C.PlayerSampleHz);sampleOthers()end
  if hasRoot and humRef and humRef.Health>0 and humRef.FloorMaterial~=AIR then
   local p=rootRef.Position;local half=C.PlayerFootprint
   local c1,c2,r1,r2=geo.CellRange(p.X-half,p.X+half,p.Z-half,p.Z+half)
   for r=r1,r2 do for c=c1,c2 do pressCell(r,c,1,p.X,p.Z)end end
  end
  for i=1,oN do pressCell(oRow[i],oCol[i],oKind[i],oX[i],oZ[i])end
  for i=#downList,1,-1 do local idx=downList[i];if stampAt[idx]~=frameNo then releaseKey(idx)end end
  animate()
  legendPass()
  flushMoves()
 end
 table.insert(conns,Run.RenderStepped:Connect(step))
 table.insert(conns,CS:GetInstanceAddedSignal('BiomeKeeper'):Connect(addKeeper))
 scanKeepers()
end

-- The biome attributes arrive with the map: build once all seven biomes are described (or, for a map that describes fewer,
-- two seconds after the track end and the first biome appear).
local function mapComplete()
 if type(map:GetAttribute('BiomeTrackEndZ'))~='number'then return false end
 for n=1,K.StageCount do
  if type(map:GetAttribute('BiomeStartZ_'..n))~='number'or type(map:GetAttribute('BiomeEndZ_'..n))~='number'then return false end
 end
 return true
end
local function mapStarted()return type(map:GetAttribute('BiomeTrackEndZ'))=='number'and type(map:GetAttribute('BiomeStartZ_1'))=='number'end
local waiting;local link
local function tryStart()
 if started or stopped then return end
 if mapComplete()then start()
 elseif mapStarted()and not waiting then waiting=true;task.delay(2,start)end
 if started and link then link:Disconnect();link=nil end
end
tryStart()
if not started then link=map.AttributeChanged:Connect(tryStart);table.insert(conns,link)end
script.Destroying:Connect(cleanup)
