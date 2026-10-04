-- R149 (owner playtest of R148: keys "way too small and not tall enough", "rendering issues", wants "the keyboard tiles visible from a
-- really long range" with "a really consistent look overall", the click "consistent with its noise", the colours matching each biome).
-- Client only: no remotes, no server code, nothing collides or can be queried. Grid, colours, windows and budgets come from
-- ReplicatedStorage.KeyboardTrack (pure, tested).
--  * ONE look at every distance: every key is the same keycap (a clone of ReplicatedStorage.R142Keycap at its own proportions, 7.7 studs
--    wide; plain blocks only while that template has not replicated yet, swapped in place once it has) in its biome's colours. There are no
--    coarse / flat far layers any more: whole rows of keys are dressed around the runner (12 rows behind .. 122 ahead on tier 3, ~1000 studs)
--    from a recycled pool, nearest rows first, and a row is only recycled a few rows past the window edge (hysteresis).
--  * Depth: the key tops stand just above the real floor (runners and keepers stand on them); the keys reach down past a sunken grout bed
--    (the biome's darker colour) so every key shows 2.15 studs of side. The real track floor (BiomeGround_n) is hidden for this client only
--    (LocalTransparencyModifier, restored on teardown) so no surface is ever coplanar with it; the parts of a floor the keyboard does not
--    cover (The Darkened's arena) are drawn by local copies. A low rim closes the keyboard's sides and ends.
--  * Letters: one SurfaceGui per half row (11 letters) on an invisible strip just above the resting key tops, upright for a +Z runner and in
--    keyboard order left -> right (column 1 = +X edge, labels turned 180 degrees). Rows of letters reach ~150 studs ahead and fade out over
--    their last rows. A key that is down carries its own letter (a pooled SurfaceGui) while it moves, then gives it back to its strip.
--  * Spacebars: one cream bar per biome start (the biome's first row, full width), always present, labelled with the biome name.
--  * Presses: the local character every frame (Humanoid.FloorMaterial ~= Air), other players and keepers at 30 Hz within PressRange. The union
--    of pressed keys is diffed with the last frame; only the changing keys animate (quad-out down, back-out up) via BulkMoveTo.
--  * Shovel holes: lifted onto the key tops (every part, once per part, streamed-in parts too); the keys under a hole stay up. Pack platforms
--    hold the keys under them down (silently), so the platform shows on them.
--  * Clicks: one recording, pitch 0.98 .. 1.02 (keepers 0.94), the same volume rule for all (3D roll-off from the key), a steady cadence per
--    presser (K.Allow: at most one click per 1/12 s each, evenly spaced while sprinting) and a voice pool that reuses the oldest voice; no
--    shared budget that drops some runners' clicks. Effects volume 0 (Settings) = silent.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService');local CS=game:GetService('CollectionService');local Content=game:GetService('ContentProvider')
local K=require(RS:WaitForChild('KeyboardTrack'))
local C=K.Config
local player=Players.LocalPlayer
local map=workspace:WaitForChild('ChestChaseMap')
local V3,V2,CF=Vector3.new,Vector2.new,CFrame.new
local floor,min,max,abs,ceil=math.floor,math.min,math.max,math.abs,math.ceil
local clock=os.clock
local F=C.FloorTop
local AIR=Enum.Material.Air
local BARBASE=100000                                 -- press index of spacebar i = BARBASE + i (keys use their slot number)

local function optional(name)
 local m=RS:FindFirstChild(name);if not m then return nil end
 local ok,v=pcall(require,m);return ok and v or nil
end
local Fx,Mixer,Dash=optional('ClientFxBudget'),optional('AudioMixer'),optional('KeeperRecoveryDash')

local conns={};local folder;local started=false;local stopped=false
local hidden={}                                      -- real floor part -> {Faces = {decals / textures}, Patches = {local copies}}
local function restoreGround()
 for part,rec in pairs(hidden)do
  pcall(function()part.LocalTransparencyModifier=0 end)
  for _,d in ipairs(rec.Faces)do pcall(function()d.LocalTransparencyModifier=0 end)end
 end
 table.clear(hidden)
end
local unlift=nil                                     -- puts lifted shovel-hole parts back at their server height (set by start)
local function cleanup()
 stopped=true
 for _,c in ipairs(conns)do c:Disconnect()end;table.clear(conns)
 restoreGround()
 if unlift then pcall(unlift);unlift=nil end
 if folder then folder:Destroy();folder=nil end
end

local function start()
 if started or stopped then return end;started=true
 local Motion=RS:FindFirstChild('RunnerMotion')
 local centerX=Motion and Motion:GetAttribute('TrackCenterX')
 local geo=K.Geometry(map:GetAttributes(),type(centerX)=='number'and centerX or nil)
 if geo.Rows<1 then warn('[R149] keyboard: the map has no track rows');return end
 local CX,COLS,P,HALF=geo.CenterX,geo.Cols,geo.Pitch,geo.HalfWidth
 local LEFT=CX+HALF                                   -- the +X edge: column 1 is here, columns count toward -X
 local KW=P-C.Gap                                     -- key width / depth (square keycaps)
 local rowStage,barOfRow=geo.RowStage,geo.BarOfRow
 local BED=K.BedTop()

 folder=Instance.new('Folder');folder.Name='KeyboardTrackVisuals';folder.Parent=workspace
 local function sub(name)local f=Instance.new('Folder');f.Name=name;f.Parent=folder;return f end
 local bedFolder,keyFolder,legendFolder,soundFolder,groundFolder=sub('Bed'),sub('Keys'),sub('Legends'),sub('Sounds'),sub('Ground')
 local function flat(p)
  p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 end
 local function block(name,size,cframe,r,g,b,parent)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cframe;p.Color=Color3.fromRGB(r,g,b)
  p.Material=Enum.Material.SmoothPlastic;flat(p);p.Parent=parent;return p
 end

 -- The sunken grout bed (each biome's own darker colour) and the rim that closes the keyboard's sides and ends -----------------------
 do
 local rimTop=F-C.RimDrop;local rimBottom=BED-C.BedThickness-.1
 local rimH=rimTop-rimBottom;local rimY=(rimTop+rimBottom)/2;local rimX=HALF-C.RimInset+C.RimWidth/2
 for _,seg in ipairs(geo.Segs)do
  local r,g,b=K.BedRGB(seg.Id)
  for _,piece in ipairs(K.Segments(seg.StartZ,seg.EndZ,C.BedMaxLength))do
   block('Bed',V3(HALF*2,C.BedThickness,piece.Length),CF(CX,BED-C.BedThickness/2,piece.Centre),r,g,b,bedFolder)
   for side=-1,1,2 do block('Rim',V3(C.RimWidth,rimH,piece.Length),CF(CX+side*rimX,rimY,piece.Centre),r,g,b,bedFolder)end
  end
 end
 do
  local first,last=geo.Segs[1],geo.Segs[#geo.Segs]
  local w=2*(HALF-C.RimInset+C.RimWidth)
  local r,g,b=K.BedRGB(first.Id)
  block('RimEnd',V3(w,rimH,C.RimWidth),CF(CX,rimY,geo.Z0+C.RimInset-C.RimWidth/2),r,g,b,bedFolder)
  r,g,b=K.BedRGB(last.Id)
  block('RimEnd',V3(w,rimH,C.RimWidth),CF(CX,rimY,last.EndZ-C.RimInset+C.RimWidth/2),r,g,b,bedFolder)
 end
 end

 -- The real floor: hidden for this client under the keyboard; the rest of a floor part is drawn by a local copy ------------------------
 local scanGround
 do
 local keyRect={CX-HALF,CX+HALF,geo.Z0,geo.Segs[#geo.Segs].EndZ}
 local function extents(part)
  local cf,s=part.CFrame,part.Size
  local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
  local hx=abs(r.X)*s.X/2+abs(u.X)*s.Y/2+abs(l.X)*s.Z/2
  local hy=abs(r.Y)*s.X/2+abs(u.Y)*s.Y/2+abs(l.Y)*s.Z/2
  local hz=abs(r.Z)*s.X/2+abs(u.Z)*s.Y/2+abs(l.Z)*s.Z/2
  local p=cf.Position
  return p.X-hx,p.X+hx,p.Y-hy,p.Y+hy,p.Z-hz,p.Z+hz
 end
 local function makePatch(part,rect,y0,y1)
  local p
  if part.Archivable then local ok,c=pcall(part.Clone,part);if ok and typeof(c)=='Instance'then p=c end end
  if p then
   for _,d in ipairs(p:GetDescendants())do
    if d:IsA('Decal')then d.LocalTransparencyModifier=0 elseif not d:IsA('SurfaceAppearance')then d:Destroy()end
   end
  else
   p=Instance.new('Part');p.Color=part.Color;p.Material=part.Material;p.Reflectance=part.Reflectance;p.Transparency=part.Transparency
   pcall(function()p.MaterialVariant=part.MaterialVariant end)
  end
  -- a local copy must not pass for the floor: no tags, no attributes (other scripts look floors up by tag / attribute / name)
  pcall(function()for _,t in ipairs(CS:GetTags(p))do CS:RemoveTag(p,t)end end)
  pcall(function()for k in pairs(p:GetAttributes())do p:SetAttribute(k,nil)end end)
  p.Name='GroundPatch';flat(p);p.LocalTransparencyModifier=0
  p.Size=V3(rect[2]-rect[1],y1-y0,rect[4]-rect[3]);p.CFrame=CF((rect[1]+rect[2])/2,(y0+y1)/2,(rect[3]+rect[4])/2)
  p.Parent=groundFolder
  return p
 end
 local function hideFaces(part,rec)
  for _,d in ipairs(part:GetChildren())do
   if d:IsA('Decal')and d.LocalTransparencyModifier~=1 then
    d.LocalTransparencyModifier=1
    if not table.find(rec.Faces,d)then rec.Faces[#rec.Faces+1]=d end
   end
  end
 end
 local function hideGround(part)
  if stopped or hidden[part]or not part:IsA('BasePart')or not part.Name:match('^BiomeGround_%d')then return end
  if abs(part.CFrame.UpVector.Y)<.99 then return end
  local x0,x1,y0,y1,z0,z1=extents(part)
  if abs(y1-F)>.6 then return end                      -- not the track floor at the keyboard's height
  if x1<=keyRect[1]or x0>=keyRect[2]or z1<=keyRect[3]or z0>=keyRect[4]then return end
  local rec={Faces={},Patches={}}
  for _,rect in ipairs(K.RectMinus({x0,x1,z0,z1},keyRect))do
   if rect[2]-rect[1]>.01 and rect[4]-rect[3]>.01 then rec.Patches[#rec.Patches+1]=makePatch(part,rect,y0,y1)end
  end
  hidden[part]=rec
  part.LocalTransparencyModifier=1
  hideFaces(part,rec)
  -- a texture / decal that streams in after its floor is hidden at once too (a Decal ignores its part's modifier)
  rec.Conn=part.ChildAdded:Connect(function(d)if hidden[part]==rec then hideFaces(part,rec)end end);table.insert(conns,rec.Conn)
 end
 local hooked=setmetatable({},{__mode='k'})
 local function hook(container)
  if hooked[container]then return end;hooked[container]=true
  table.insert(conns,container.ChildAdded:Connect(function(c)hideGround(c)end))
 end
 function scanGround()
  for part,rec in pairs(hidden)do
   if not part.Parent then
    for _,p in ipairs(rec.Patches)do p:Destroy()end;hidden[part]=nil
    if rec.Conn then rec.Conn:Disconnect()end
   else
    if part.LocalTransparencyModifier~=1 then part.LocalTransparencyModifier=1 end
    hideFaces(part,rec)
   end
  end
  for _,c in ipairs(map:GetChildren())do hideGround(c)end
  local obby=map:FindFirstChild('Obby');local biomes=obby and obby:FindFirstChild('Biomes')
  if biomes then
   if not hooked[biomes]then hooked[biomes]=true;table.insert(conns,biomes.ChildAdded:Connect(function(m)hook(m);for _,c in ipairs(m:GetChildren())do hideGround(c)end end))end
   for _,m in ipairs(biomes:GetChildren())do hook(m);for _,c in ipairs(m:GetChildren())do hideGround(c)end end
  end
 end
 hook(map)
 end
 scanGround()

 -- State -----------------------------------------------------------------------------------------------------
 local focusX,focusZ,hasRoot=CX,geo.Z0,false
 local focusRow,focusCol=1,1
 local charRef,rootRef,humRef
 local now,frameNo,reduced=clock(),0,false
 local tier,wantTier,wantSince=0,0,0
 local tierCfg=K.Tier(3)
 local template=nil;local templateReady=false
 -- per key slot (and BARBASE + bar): part, centre, depth 0..1, height fudge, dress frame, cell
 local kPart,kX,kZ,kDepth,kOff,kFresh,kKey,kRow,kCol={},{},{},{},{},{},{},{},{}
 local slotOf={}                                     -- cell key (row * 64 + col) -> slot
 local freeSlots,freeN,made=table.create(256),0,0
 local plainSlot={}                                  -- slots whose part is a plain block (template not there yet)
 local rowBound,boundRows,boundRowPos={},{},{}
 local boundKeys=0
 local downPos,animPos,animT0,animFrom,animTo,animDur={},{},{},{},{},{}
 local stampAt,moveMark={},{}
 local downList,animList,moveList={},{},{}
 local moveN=0;local moveParts,moveCFs={},{}
 local oRow,oCol,oKind,oWho,oX,oZ,oN={},{},{},{},{},{},0 -- cells other players / keepers press (30 Hz)
 local keepers={}
 local holeCell,platCell,platList={},{},{};local barHole,barPlat={},{}
 local holeRects,platRects,clearSig,holesFolder={},{},nil,nil
 local windowDirty,pendingBind,pendingLegend=true,false,false
 local facing,facingWant,facingSince,turnBurst=1,1,0,false        -- the window's long side: +1 = toward +Z, -1 = toward -Z (see K.Facing)

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
  if moveN==0 then return end
  for i=1,moveN do
   local idx=moveList[i];moveParts[i]=kPart[idx];moveCFs[i]=CF(kX[idx],K.KeyTop(kDepth[idx])-C.KeyY/2+kOff[idx],kZ[idx])
  end
  for i=#moveParts,moveN+1,-1 do moveParts[i]=nil;moveCFs[i]=nil end
  workspace:BulkMoveTo(moveParts,moveCFs,Enum.BulkMoveMode.FireCFrameChanged)
  moveN=0
 end
 local function clearKeyState(idx)
  if downPos[idx]then listRemove(downList,downPos,idx)end
  if animPos[idx]then listRemove(animList,animPos,idx)end
  kDepth[idx]=0
 end

 -- Letters ----------------------------------------------------------------------------------------------------------
 local LG=C.Legend;local PPS=LG.PixelsPerStud;local TEXT=min(100,floor(LG.TextHeight*PPS+.5))
 local FONT=Enum.Font[LG.Font]
 local SPAN=LG.KeysPerStrip;local STRIPS=ceil(COLS/SPAN)
 local inkCache={}
 local function inkColor(stage,row,col)
  local ink=K.ShadeInk(stage,K.ShadeIndex(stage,row,col,1))
  local c=inkCache[ink];if not c then c=Color3.fromRGB(ink[1],ink[2],ink[3]);inkCache[ink]=c end
  return c
 end
 local creamInk=Color3.fromRGB(K.CreamInk[1],K.CreamInk[2],K.CreamInk[3])
 -- Text sits on the Top face with its up toward -Z and its reading direction toward +X; turned half a way round (about the label's
 -- centre) it is upright for a runner facing +Z, reading toward -X = his right.
 local function letterLabel(parent)
  local l=Instance.new('TextLabel');l.Name='Letter';l.BackgroundTransparency=1;l.BorderSizePixel=0;l.AnchorPoint=V2(.5,.5)
  l.Rotation=180;l.Font=FONT;l.TextScaled=false;l.TextSize=TEXT;l.TextStrokeTransparency=1;l.Parent=parent
  return l
 end
 local function letterGui(name,parent)
  local gui=Instance.new('SurfaceGui');gui.Name=name;gui.Face=Enum.NormalId.Top;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
  gui.PixelsPerStud=PPS;gui.LightInfluence=0;gui.AlwaysOnTop=false;pcall(function()gui.MaxDistance=LG.MaxDistance end);gui.Parent=parent
  return gui
 end
 local stripFree,stripFreeN={},0
 local stripsOfRow,stripRows,stripRowPos={},{},{}
 local function newStrip()
  local p=Instance.new('Part');p.Name='LegendStrip';flat(p);p.Transparency=1;p.Size=V3(1,.05,1);p.CFrame=CF(CX,F-200,0);p.Parent=legendFolder
  local gui=letterGui('Letters',p)
  local labels={}
  for i=1,SPAN do local l=letterLabel(gui);l.Size=UDim2.fromOffset(KW*PPS,KW*PPS);labels[i]=l end
  return {Part=p,Gui=gui,Labels=labels,W=0,D=0,Alpha=-1}
 end
 local keyLegendOf={}                                -- slot -> pooled per-key letter while the key is down
 local function labelShown(row,col)
  local key=row*64+col
  if holeCell[key]or platCell[key]then return false end
  local s=slotOf[key];if not s then return false end
  if keyLegendOf[s]or kDepth[s]~=0 or animPos[s]then return false end
  return true
 end
 local function setLabel(row,col,shown)
  local list=stripsOfRow[row];if not list then return end
  local k=(col-1)//SPAN+1;local st=list[k];if not st then return end
  local l=st.Labels[col-(k-1)*SPAN]
  if l.Visible~=shown then l.Visible=shown end
 end
 local labelMarks,labelMarkN,labelMarkAt={},0,{}
 local function markLabel(slot)
  if slot>=BARBASE or labelMarkAt[slot]==frameNo then return end
  labelMarkAt[slot]=frameNo;labelMarkN+=1;labelMarks[labelMarkN]=slot
 end
 local function flushLabels()
  for i=1,labelMarkN do
   local s=labelMarks[i];local key=kKey[s]
   if key and key>0 then local row,col=key//64,key%64;setLabel(row,col,labelShown(row,col))end
   labelMarks[i]=nil
  end
  labelMarkN=0
 end
 local function stripAlpha(st,a)
  if st.Alpha==a then return end
  st.Alpha=a
  for _,l in ipairs(st.Labels)do l.TextTransparency=a end
 end
 local function bindStrips(row)
  local za,zb=geo.RowZ(row);local d=zb-za;local z=(za+zb)/2;local stage=rowStage[row]
  local y=K.KeyTop(0)+(template and C.TopOffset or 0)+LG.Lift-.025
  local list={}
  for k=1,STRIPS do
   local st
   if stripFreeN>0 then st=stripFree[stripFreeN];stripFree[stripFreeN]=nil;stripFreeN-=1 else st=newStrip()end
   local c0=(k-1)*SPAN+1;local c1=min(COLS,k*SPAN)
   local w=(c1-c0+1)*P;local xMin=LEFT-c1*P
   if abs(st.W-w)>1e-6 or abs(st.D-d)>1e-6 then st.W=w;st.D=d;st.Part.Size=V3(w,.05,d)end
   st.Part.CFrame=CF(xMin+w/2,y,z)
   for i=1,SPAN do
    local l=st.Labels[i];local c=c0+i-1
    if c<=c1 then
     local x=(LEFT-(c-.5)*P)-xMin
     l.Position=UDim2.fromOffset(x*PPS,d/2*PPS)
     l.Text=K.Legend(row,c);l.TextColor3=inkColor(stage,row,c)
     l.Visible=labelShown(row,c)
    else l.Visible=false end
   end
   st.Alpha=-1;stripAlpha(st,K.LegendAlpha(tier,(row-focusRow)*facing))
   list[k]=st
  end
  stripsOfRow[row]=list;listAdd(stripRows,stripRowPos,row)
 end
 local function releaseStrips(row)
  local list=stripsOfRow[row];if not list then return end
  for _,st in ipairs(list)do st.Part.CFrame=CF(CX,F-200,0);stripFreeN+=1;stripFree[stripFreeN]=st end
  stripsOfRow[row]=nil;listRemove(stripRows,stripRowPos,row)
 end
 -- per-key letters (a key that is down keeps its letter while it moves)
 local klFree,klFreeN,klMade={},0,0
 local klList,klPos,klStamp={},{},{}
 local function newKeyLegend()
  local gui=letterGui('KeyLegend',legendFolder)
  local l=letterLabel(gui);l.Position=UDim2.fromScale(.5,.5);l.Size=UDim2.fromScale(1,1)
  return {Gui=gui,Label=l,Slot=0}
 end
 local function dropKeyLegend(slot)
  local e=keyLegendOf[slot];if not e then return end
  keyLegendOf[slot]=nil;listRemove(klList,klPos,e)
  e.Gui.Parent=legendFolder;e.Slot=0
  klFreeN+=1;klFree[klFreeN]=e
  markLabel(slot)
 end

 -- Keys ---------------------------------------------------------------------------------------------------------------
 local function stripPart(part)
  for _,d in ipairs(part:GetDescendants())do if d:IsA('BaseScript')or d:IsA('Sound')or d:IsA('SurfaceGui')or d:IsA('Decal')then d:Destroy()end end
 end
 local function newKeyPart()
  local part
  if template then local ok,c=pcall(template.Clone,template);if ok and typeof(c)=='Instance'and c:IsA('BasePart')then part=c end end
  local mesh=part~=nil
  if not part then part=Instance.new('Part');part.Material=Enum.Material.SmoothPlastic end
  part.Name='Key';flat(part);part.Size=V3(KW,C.KeyY,KW);part.Transparency=1;part.CFrame=CF(CX,F-200,0)
  if mesh then stripPart(part)end
  part.Parent=keyFolder
  return part,mesh
 end
 local function takeSlot()
  if freeN>0 then local s=freeSlots[freeN];freeSlots[freeN]=nil;freeN-=1;return s end
  made+=1;local s=made
  local part,mesh=newKeyPart()
  kPart[s]=part;plainSlot[s]=(not mesh)or nil;kOff[s]=mesh and C.TopOffset or 0;kDepth[s]=0;kFresh[s]=0;kKey[s]=0
  return s
 end
 local function bindRow(row)
  local stage=rowStage[row];local za,zb=geo.RowZ(row);local z=(za+zb)/2
  for col=1,COLS do
   local s=takeSlot();local key=row*64+col
   slotOf[key]=s;kKey[s]=key;kRow[s]=row;kCol[s]=col
   kX[s]=LEFT-(col-.5)*P;kZ[s]=z;kDepth[s]=0;kFresh[s]=frameNo
   local part=kPart[s];part.Color=K.CellColor(stage,row,col,1);part.Transparency=0
   queueMove(s)
  end
  rowBound[row]=true;listAdd(boundRows,boundRowPos,row);boundKeys+=COLS
 end
 local function releaseRow(row)
  releaseStrips(row)
  for col=1,COLS do
   local key=row*64+col;local s=slotOf[key]
   if s then
    dropKeyLegend(s);clearKeyState(s)
    slotOf[key]=nil;kKey[s]=0;kPart[s].Transparency=1
    freeN+=1;freeSlots[freeN]=s
   end
  end
  rowBound[row]=nil;listRemove(boundRows,boundRowPos,row);boundKeys-=COLS
 end
 -- swap a plain block for a keycap in place (the template replicated after the keys were dressed)
 local function swapSlot(s)
  local old=kPart[s];local part,mesh=newKeyPart();if not mesh then part:Destroy();return false end
  part.Color=old.Color;part.Transparency=old.Transparency
  kPart[s]=part;kOff[s]=C.TopOffset;plainSlot[s]=nil
  local e=keyLegendOf[s];if e then e.Gui.Parent=part end
  if old.Transparency<1 then queueMove(s)end
  old:Destroy()
  return true
 end
 -- The window of rows: recycle the rows past it (with hysteresis), dress the missing ones nearest first, within the budgets.
 local function windowPass(dt)
  local wa,wb,ka,kb=K.KeyWindow(geo,tier,focusRow,facing)
  local scale=min(2,max(1,dt*60))
  -- after a teleport (respawn, a pad) the rows right around the runner are missing, after the window turned round its long side is:
  -- catch up with 4x the budget until they are there
  local burst=turnBurst
  for r=max(wa,focusRow-2),min(wb,focusRow+2)do if not rowBound[r]and not barOfRow[r]then burst=true;break end end
  local budget=floor(tierCfg.Bind*scale*(burst and C.TeleportBurst or 1));local relBudget=budget*4
  local released=0
  for i=#boundRows,1,-1 do
   local r=boundRows[i]
   if(r<ka or r>kb)and released<relBudget then releaseRow(r);released+=COLS end
  end
  local cap=K.KeyCap(tier,COLS);local used=0;local pending=false
  for d=0,max(focusRow-wa,wb-focusRow)do
   for pass=1,(d==0 and 1 or 2)do
    local r=pass==1 and focusRow+d or focusRow-d
    if r>=wa and r<=wb and not rowBound[r]and not barOfRow[r]then
     if used+COLS<=max(budget,COLS)and boundKeys+COLS<=cap then bindRow(r);used+=COLS else pending=true end
    end
   end
  end
  if not pending then turnBurst=false end
  return pending or released>=relBudget
 end
 local function legendWindowPass()
  local la,lb=K.LegendWindow(geo,tier,focusRow,facing)
  for i=#stripRows,1,-1 do
   local r=stripRows[i]
   if r<la-1 or r>lb+1 or not rowBound[r]then releaseStrips(r)end
  end
  local n,pending=0,false
  for d=0,max(focusRow-la,lb-focusRow)do
   for pass=1,(d==0 and 1 or 2)do
    local r=pass==1 and focusRow+d or focusRow-d
    if r>=la and r<=lb and rowBound[r]and not stripsOfRow[r]then
     if n<LG.RowsPerFrame then bindStrips(r);n+=1 else pending=true end
    end
   end
  end
  for _,r in ipairs(stripRows)do
   local a=K.LegendAlpha(tier,(r-focusRow)*facing)
   for _,st in ipairs(stripsOfRow[r])do stripAlpha(st,a)end
  end
  return pending
 end

 -- Spacebars: one cream bar per biome start, always present ------------------------------------------------------
 local bars=geo.Bars
 do
 local cr,cg,cb=K.CreamRGB()
 for i,bar in ipairs(bars)do
  local depth=(bar.Z1-bar.Z0)-C.Gap
  local p=Instance.new('Part');p.Name='Spacebar';p.Size=V3(HALF*2-C.Gap,C.KeyY,depth);p.Color=Color3.fromRGB(cr,cg,cb)
  p.Material=Enum.Material.SmoothPlastic;flat(p);p.CFrame=CF(CX,F-200,0);p.Parent=keyFolder
  local gui=Instance.new('SurfaceGui');gui.Name='SpacebarLegend';gui.Face=Enum.NormalId.Top;gui.LightInfluence=0;gui.AlwaysOnTop=false
  gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=C.SpacebarPixelsPerStud;gui.Parent=p
  local label=Instance.new('TextLabel');label.Name='Biome';label.BackgroundTransparency=1;label.BorderSizePixel=0
  label.AnchorPoint=V2(.5,.5);label.Position=UDim2.fromScale(.5,.5);label.Size=UDim2.fromScale(1,.9);label.Rotation=180
  label.Font=FONT;label.TextScaled=true;label.TextStrokeTransparency=1;label.Text=string.upper(bar.Name);label.TextColor3=creamInk;label.Parent=gui
  local idx=BARBASE+i
  kPart[idx]=p;kX[idx]=CX;kZ[idx]=(bar.Z0+bar.Z1)/2;kDepth[idx]=0;kOff[idx]=0;kFresh[idx]=0
  queueMove(idx);p.Transparency=0
 end
 end

 -- Template (the keycap mesh) ------------------------------------------------------------------------------------
 task.spawn(function()
  local found=C.UseKeycapMesh~=false and RS:FindFirstChild('R142Keycap')or nil
  if not found and C.UseKeycapMesh~=false then local ok,t=pcall(function()return RS:WaitForChild('R142Keycap',30)end);if ok and typeof(t)=='Instance'then found=t end end
  if stopped then return end
  if found and found:IsA('BasePart')then
   -- a template that cannot be cloned (Archivable off) is no template: the keys stay plain blocks instead of being swapped every frame
   local ok,c=pcall(found.Clone,found)
   if ok and typeof(c)=='Instance'then c:Destroy();template=found end
  end
  templateReady=true
  if not template and C.UseKeycapMesh~=false then warn('[R149] keyboard: ReplicatedStorage.R142Keycap is missing; the keys are plain blocks')end
 end)
 local function swapPass()
  local n=0
  for s=1,made do
   if plainSlot[s]then if not swapSlot(s)then return end;n+=1;if n>=tierCfg.Bind then return end end
  end
 end

 -- Clicks -----------------------------------------------------------------------------------------------------------
 local click
 do
 local voices={};local voiceNext=1
 local RANGE2=C.ClickRange*C.ClickRange
 for i=1,C.ClickVoices do
  local anchor=Instance.new('Part');flat(anchor);anchor.Name='KeyClick';anchor.Size=V3(.2,.2,.2);anchor.Transparency=1;anchor.Parent=soundFolder
  local sound=Instance.new('Sound');sound.Name='KeyClickSound';sound.SoundId='rbxassetid://'..tostring(C.ClickSoundId)
  sound.Volume=C.ClickVolume;sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.RollOffMinDistance=C.ClickRollOffMin;sound.RollOffMaxDistance=C.ClickRollOffMax
  sound.Parent=anchor
  if Mixer and type(Mixer.Route)=='function'then pcall(Mixer.Route,sound,'Effects')end
  voices[i]={Part=anchor,Sound=sound}
 end
 task.spawn(function()pcall(function()Content:PreloadAsync({voices[1].Sound})end)end)
 local ownGate=K.NewCadence(C.ClickGap)
 local gates=setmetatable({},{__mode='k'})          -- presser (a Player or a keeper Model) -> its own cadence
 function click(kind,who,x,z)
  if Mixer and type(Mixer.Get)=='function'and Mixer.Get('Effects')==0 then return end
  if kind~=1 then local dx,dz=x-focusX,z-focusZ;if dx*dx+dz*dz>RANGE2 then return end end
  local gate=ownGate
  if kind~=1 then
   if who==nil then return end
   gate=gates[who];if not gate then gate=K.NewCadence(C.ClickGap);gates[who]=gate end
  end
  if not K.Allow(gate,now)then return end
  gate.N=(gate.N or 0)+1
  -- strict rotation: the voice reused is always the one started longest ago (all voices play the same recording)
  local v=voices[voiceNext];voiceNext=voiceNext%#voices+1
  if v.Sound.Playing then v.Sound:Stop()end
  v.Part.CFrame=CF(x,F+1,z)
  v.Sound.PlaybackSpeed=K.ClickPitch(kind,gate.N);v.Sound.Volume=C.ClickVolume
  v.Sound.TimePosition=0;v.Sound:Play()
 end
 end

 -- Presses --------------------------------------------------------------------------------------------------------
 local function startAnim(idx,to)
  local from=kDepth[idx];local span=min(1,abs(to-from))
  animFrom[idx]=from;animTo[idx]=to;animT0[idx]=now
  animDur[idx]=to==1 and max(C.PressSeconds*span,.015)or max(C.ReleaseSeconds*max(span,.35),.04)
  if not animPos[idx]then listAdd(animList,animPos,idx)end
 end
 -- kind: 1 = you, 2 = another player, 3 = a keeper, 0 = a pack platform (silent); who = the presser (gate key); px, pz = where he stands
 local function pressKey(idx,kind,who,px,pz)
  listAdd(downList,downPos,idx)
  markLabel(idx)
  if kFresh[idx]==frameNo or kind==0 then
   -- a key dressed this very frame under a standing runner (or under a platform): down at once and silent
   if animPos[idx]then listRemove(animList,animPos,idx)end
   kDepth[idx]=1;queueMove(idx)
  else
   startAnim(idx,1) -- Reduced Motion: animate() finishes it in the same frame
   if idx>=BARBASE then click(kind,who,px,pz)else click(kind,who,kX[idx],kZ[idx])end
  end
 end
 local function releaseKey(idx)
  listRemove(downList,downPos,idx)
  startAnim(idx,0)
 end
 local function touch(idx,kind,who,px,pz)
  if stampAt[idx]==frameNo then return end
  stampAt[idx]=frameNo
  if not downPos[idx]then pressKey(idx,kind,who,px,pz)end
 end
 -- A cell (row, column) is pressed by `kind` / `who`; px, pz = where the presser stands. Keys under a shovel hole stay up.
 local function pressCell(row,col,kind,who,px,pz)
  local bar=barOfRow[row]
  if bar then
   if not barHole[bar]then touch(BARBASE+bar,kind,who,px,pz)end
  else
   local key=row*64+col
   if holeCell[key]then return end
   local slot=slotOf[key];if slot then touch(slot,kind,who,px,pz)end
  end
 end
 local function animate()
  local ease=K.Ease
  for i=#animList,1,-1 do
   local idx=animList[i]
   local to=animTo[idx]
   local t=(now-animT0[idx])/animDur[idx]
   if t>=1 or reduced then kDepth[idx]=to;listRemove(animList,animPos,idx);if to==0 then markLabel(idx)end
   else kDepth[idx]=animFrom[idx]+(to-animFrom[idx])*(to==1 and ease.QuadOut(t)or ease.BackOut(t))end
   queueMove(idx)
  end
 end
 -- letters riding on keys that are down (within the rows that show letters), given back once the key is up again
 local klA,klB,klLimit=1,0,0
 local function wantKeyLegend(idx)
  if idx>=BARBASE then return end
  local key=kKey[idx];if not key or key==0 then return end
  local row=key//64
  if row<klA or row>klB or not stripsOfRow[row]or holeCell[key]or platCell[key]then return end
  klStamp[idx]=frameNo
  if keyLegendOf[idx]or #klList>=klLimit then return end
  local e
  if klFreeN>0 then e=klFree[klFreeN];klFree[klFreeN]=nil;klFreeN-=1 else klMade+=1;e=newKeyLegend()end
  local col=key%64
  e.Slot=idx;e.Label.Text=K.Legend(row,col);e.Label.TextColor3=inkColor(rowStage[row],row,col)
  e.Label.TextTransparency=K.LegendAlpha(tier,(row-focusRow)*facing)
  e.Gui.Parent=kPart[idx];keyLegendOf[idx]=e;listAdd(klList,klPos,e)
  markLabel(idx)
 end
 local function keyLegendPass()
  klA,klB=K.LegendWindow(geo,tier,focusRow,facing);klLimit=tierCfg.KeyLegends
  for _,idx in ipairs(downList)do wantKeyLegend(idx)end
  for _,idx in ipairs(animList)do wantKeyLegend(idx)end
  for i=#klList,1,-1 do local e=klList[i];if klStamp[e.Slot]~=frameNo or #klList>klLimit then dropKeyLegend(e.Slot)end end
 end

 -- Other players and keepers (30 Hz) ------------------------------------------------------------------------------
 local function addFootprint(x,z,half,kind,who)
  local c1,c2,r1,r2=geo.CellRange(x-half,x+half,z-half,z+half)
  for r=r1,r2 do for c=c1,c2 do
   if oN<512 then oN+=1;oRow[oN]=r;oCol[oN]=c;oKind[oN]=kind;oWho[oN]=who;oX[oN]=x;oZ[oN]=z end
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
  for i=1,oN do oWho[i]=nil end
  oN=0
  local range=tierCfg.PressRange
  for _,p in ipairs(Players:GetPlayers())do
   if p~=player then
    local char=p.Character
    local root=char and char:FindFirstChild('HumanoidRootPart');local hum=char and char:FindFirstChildOfClass('Humanoid')
    if root and hum and hum.Health>0 then
     local pos=root.Position
     if abs(pos.Z-focusZ)<=range and pos.Y-C.PlayerRootToFeet<=F+C.PlayerFeetReach then addFootprint(pos.X,pos.Z,C.PlayerFootprint,2,p)end
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
     if abs(pos.Z-focusZ)<=range and pos.Y-rec.ExtY*.5<=F+C.PlayerFeetReach then addFootprint(pos.X,pos.Z,rec.Half,3,model)end
    end
   end
  end
 end

 -- Clearances: shovel holes (keys stay up, the hole parts lie on them) and pack platforms (keys held down) -------------------
 -- TrackHoleService: Folder 'TrackHoles' in the map's _GameplayRuntime, a Model per hole with a 'Pit' part (+ Rim, crumbs).
 local scanClearances
 do
 local function findHoles()
  if holesFolder and holesFolder:IsDescendantOf(workspace)then return holesFolder end
  local runtime=map:FindFirstChild('_GameplayRuntime')
  holesFolder=runtime and runtime:FindFirstChild('TrackHoles')
  if not holesFolder then runtime=workspace:FindFirstChild('_GameplayRuntime');holesFolder=runtime and runtime:FindFirstChild('TrackHoles')end
  if not holesFolder then holesFolder=map:FindFirstChild('TrackHoles',true)end
  return holesFolder
 end
 -- The hole parts were authored a few hundredths above the floor; every part is lifted onto the resting key tops, once per PART (a part
 -- streamed in again is a new instance at the server height). TrackHoleClient.grow tweens crumbs back to the frames it captured, which can
 -- undo a lift for 0.3 s: a part found again at its server height is lifted again. Lifting is relative to the part's current position.
 local liftBase,liftSet=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
 local LIFT=V3(0,C.HoleLift,0)
 local function liftPart(d)
  if not d:IsA('BasePart')then return end
  local y=d.Position.Y;local base=liftBase[d]
  if not base then
   liftBase[d]=y;liftSet[d]=y+C.HoleLift;d.Position=d.Position+LIFT
  elseif abs(y-liftSet[d])>1e-3 and abs(y-base)<1e-3 then
   d.Position=d.Position+LIFT
  end
 end
 unlift=function()
  for d,y in pairs(liftSet)do
   if d.Parent and abs(d.Position.Y-y)<1e-3 then d.Position=d.Position-LIFT end
  end
 end
 local function liftAny(d)
  if d:IsA('BasePart')then liftPart(d)
  elseif d:IsA('Model')then for _,x in ipairs(d:GetDescendants())do liftPart(x)end end
 end
 local liftHook,liftHooked=nil,nil
 local function markRects(rects,set,list)
  for _,rect in ipairs(rects)do
   local c1,c2,r1,r2=geo.CellRange(rect[1],rect[2],rect[3],rect[4])
   for r=r1,r2 do if not barOfRow[r]then for c=c1,c2 do local key=r*64+c;if not set[key]then set[key]=true;if list then list[#list+1]=key end end end end end
  end
 end
 local function barTouched(rects,bar)
  for _,rect in ipairs(rects)do
   local c1,c2,r1,r2=geo.CellRange(rect[1],rect[2],rect[3],rect[4])
   if c1<=c2 and r2>=bar.Row0 and r1<=bar.Row1 then return true end
  end
  return false
 end
 local function rebuildClearances()
  holeCell,platCell,platList={},{},{}
  markRects(holeRects,holeCell,nil);markRects(platRects,platCell,platList)
  for i,bar in ipairs(bars)do barHole[i]=barTouched(holeRects,bar);barPlat[i]=not barHole[i]and barTouched(platRects,bar)end
  for _,r in ipairs(stripRows)do for c=1,COLS do setLabel(r,c,labelShown(r,c))end end
 end
 function scanClearances()
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
  rebuildClearances()
 end
 end

 -- Frame ---------------------------------------------------------------------------------------------------------
 local T={Tier=0,Clear=0,Keeper=0,Sample=0,Ground=0}   -- timers
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
  local r=geo.RowOfZ(focusZ);r=max(1,min(geo.Rows,r))
  if r~=focusRow then focusRow=r;windowDirty=true end
  -- the window's long side follows the camera (a dead zone around sideways, and the turn must hold a moment)
  local cam=workspace.CurrentCamera
  if cam then
   local want=K.Facing(cam.CFrame.LookVector.Z,facingWant)
   if frameNo==1 then facing=want end                -- the first window already faces the camera's way
   if want~=facingWant then facingWant=want;facingSince=now end
   if facingWant~=facing and now-facingSince>=C.FacingHoldSeconds then facing=facingWant;windowDirty=true;turnBurst=true end
  end
  focusCol=max(1,min(COLS,geo.ColOfX(focusX)))
 end
 local function step(dt)
  now=clock();frameNo+=1;reduced=Gui.ReducedMotionEnabled==true
  updateFocus()
  T.Tier+=dt;T.Clear+=dt;T.Keeper+=dt;T.Sample+=dt;T.Ground+=dt
  if tier==0 or T.Tier>=.5 then
   T.Tier=0
   local want=Fx and Fx.Get()or 3
   if tier==0 then tier=want;wantTier=want;wantSince=now;tierCfg=K.Tier(tier);windowDirty=true
   elseif want~=wantTier then wantTier=want;wantSince=now end
   -- a tier change only applies once it has held for a few seconds (a device bouncing between tiers must not flicker)
   if wantTier~=tier and now-wantSince>=C.TierHoldSeconds then tier=wantTier;tierCfg=K.Tier(tier);windowDirty=true end
  end
  if T.Clear>=.25 then T.Clear=0;scanClearances()end
  if T.Keeper>=2 then T.Keeper=0;scanKeepers()end
  if T.Ground>=C.GroundScanSeconds then T.Ground=0;scanGround()end
  if templateReady and template and next(plainSlot)then swapPass()end
  if windowDirty or pendingBind or pendingLegend then
   local dirty=windowDirty or pendingBind
   windowDirty=false
   if dirty then pendingBind=windowPass(dt)end
   pendingLegend=legendWindowPass()
  end
  -- presses: the local runner every frame, everyone else from the last 30 Hz sample, pack platforms hold their keys down
  if T.Sample>=1/C.PlayerSampleHz then T.Sample=T.Sample%(1/C.PlayerSampleHz);sampleOthers()end
  if hasRoot and humRef and humRef.Health>0 and humRef.FloorMaterial~=AIR then
   local p=rootRef.Position;local half=C.PlayerFootprint
   local c1,c2,r1,r2=geo.CellRange(p.X-half,p.X+half,p.Z-half,p.Z+half)
   for r=r1,r2 do for c=c1,c2 do pressCell(r,c,1,nil,p.X,p.Z)end end
  end
  for i=1,oN do pressCell(oRow[i],oCol[i],oKind[i],oWho[i],oX[i],oZ[i])end
  for _,key in ipairs(platList)do local s=slotOf[key];if s then touch(s,0,nil,kX[s],kZ[s])end end
  for i in ipairs(bars)do if barPlat[i]then touch(BARBASE+i,0,nil,CX,kZ[BARBASE+i])end end
  for i=#downList,1,-1 do local idx=downList[i];if stampAt[idx]~=frameNo then releaseKey(idx)end end
  animate()
  keyLegendPass()
  flushLabels()
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
