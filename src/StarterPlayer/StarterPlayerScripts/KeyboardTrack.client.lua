-- R151 (owner playtest of R149 / R150): "it doesn't push down far enough", "the words are missing, they only appear if under my foot", "the
-- forest, desert named tiles must also be parallel to the safe zone and horizontal":
--  * the press travels 1.15 studs (resting top floor + 1.2, pressed floor + .05: level with the planted feet) and the runner's footprint reaches
--    PressLead seconds ahead along his velocity, so the key in front is down when the foot gets there;
--  * LETTERS: a Top-face SurfaceGui is laid out with its x axis toward world -Z and its y axis toward world +X (K.TopCanvas / K.TopPoint). R149's
--    strips assumed x -> +X: each strip's canvas was 131 px wide, its labels sat at x offsets up to 1374 px, so only the one label inside the
--    canvas showed (the owner saw a single line of letters) and every letter was a quarter turn off; the spacebar name ran along the track.
--    Labels now sit at (row centre, key centre) on the real canvas and turn 270 degrees (upright, left -> right for a +Z runner); the spacebar
--    name is one wide label turned the same way, across the track. The strips and the pressed keys' own letters also stand Legend.Margin above the
--    key top measured from the keycap template (not just the configured one), and a plain-block key has no mesh to measure.
-- R149 (owner playtest of R148: keys "way too small and not tall enough", "rendering issues", wants "the keyboard tiles visible from a
-- really long range" with "a really consistent look overall", the click "consistent with its noise", the colours matching each biome).
-- Client only: no remotes, no server code, nothing collides or can be queried. Grid, colours, windows and budgets come from
-- ReplicatedStorage.KeyboardTrack (pure, tested).
--  * ONE look at every distance: every key is the same keycap (a clone of ReplicatedStorage.R142Keycap at its own proportions, 7.7 studs
--    wide; plain blocks only while that template has not replicated yet, swapped in place once it has) in its biome's colours. There are no
--    coarse / flat far layers any more: whole rows of keys are dressed around the runner (12 rows behind .. 122 ahead on tier 3, ~1000 studs)
--    from a recycled pool, nearest rows first, and a row is only recycled a few rows past the window edge (hysteresis).
--  * Depth: the pressed key tops stand just above the real floor (runners and keepers stand on them); the keys reach down past a sunken grout bed
--    (the biome's darker colour) so every key shows 2.8 studs of side at rest. The real track floor (BiomeGround_n) is hidden for this client only
--    (LocalTransparencyModifier, restored on teardown) so no surface is ever coplanar with it; the parts of a floor the keyboard does not
--    cover (The Darkened's arena) are drawn by local copies. A low rim closes the keyboard's sides and ends.
--  * Letters: one SurfaceGui per half row (11 letters) on an invisible strip just above the resting key tops, upright for a +Z runner and in
--    keyboard order left -> right (column 1 = +X edge, labels turned 270 degrees on the Top-face canvas). Rows of letters reach ~150 studs ahead
--    and fade out over their last rows. A key that is down carries its own letter (a pooled SurfaceGui) while it moves, then gives it back to its strip.
--  * Spacebars: one cream bar per biome start (the biome's first row, full width), always present, labelled with the biome name.
--  * Presses: the local character every frame (Humanoid.FloorMaterial ~= Air), other players and keepers at 30 Hz within PressRange. The union
--    of pressed keys is diffed with the last frame; only the changing keys animate (quad-out down, back-out up) via BulkMoveTo.
--  * Shovel holes: lifted onto the key tops (every part, once per part, streamed-in parts too); the keys under a hole stay up. Pack platforms
--    hold the keys under them down (silently), so the platform shows on them.
--  * Camera: the real floor is hidden (LocalTransparencyModifier 1), so it no longer stops the default camera (Popper only treats a part as an
--    occluder below 0.25 transparency): a render step right after the camera module keeps the camera at least 0.6 above the resting key tops
--    while it is over the keyboard (translation only, the look direction stays; Scriptable cameras and first person are left alone).
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
local Timing=optional('SoundTiming')                -- R150: the shared lead-in table (Start_<id> on SoundTiming tunes the click)

local conns={};local folder;local started=false;local stopped=false
local hidden={}                                      -- real floor part -> {Faces = {decals / textures}, Patches = {local copies}, Conn = its ChildAdded}
local function restoreGround()
 for part,rec in pairs(hidden)do
  if rec.Conn then rec.Conn:Disconnect();rec.Conn=nil end
  pcall(function()part.LocalTransparencyModifier=0 end)
  for _,d in ipairs(rec.Faces)do pcall(function()d.LocalTransparencyModifier=0 end)end
 end
 table.clear(hidden)
end
local unlift=nil                                     -- puts lifted shovel-hole parts back at their server height (set by start)
local CAMERA_STEP='KeyboardCameraFloor'
local cameraBound=false
local function unbindCamera()
 if cameraBound then cameraBound=false;pcall(Run.UnbindFromRenderStep,Run,CAMERA_STEP)end
end
-- Teardown, also the error path of start(): the real floor is shown again, the camera clamp and every connection go, the folder goes.
local function cleanup()
 stopped=true
 unbindCamera()
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
 -- (armed at the very end of start(): until the keys exist and the frame step is connected, the floor stays visible - an error half way
 -- through start() must never leave an invisible floor and no keys)
 local scanGround,armGround
 -- The camera clamp's rectangle: the keys plus whatever hidden floor the local copies redraw (The Darkened's arena), grown by 2 studs
 local clampRect={CX-HALF-2,CX+HALF+2,geo.Z0-2,geo.Segs[#geo.Segs].EndZ+2}
 do
 local keyRect={CX-HALF,CX+HALF,geo.Z0,geo.Segs[#geo.Segs].EndZ}
 local function growClamp()
  local x0,x1,z0,z1=keyRect[1],keyRect[2],keyRect[3],keyRect[4]
  for _,rec in pairs(hidden)do
   for _,r in ipairs(rec.Rects)do x0=min(x0,r[1]);x1=max(x1,r[2]);z0=min(z0,r[3]);z1=max(z1,r[4])end
  end
  clampRect[1],clampRect[2],clampRect[3],clampRect[4]=x0-2,x1+2,z0-2,z1+2
 end
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
  local rec={Faces={},Patches={},Rects={}}
  for _,rect in ipairs(K.RectMinus({x0,x1,z0,z1},keyRect))do
   if rect[2]-rect[1]>.01 and rect[4]-rect[3]>.01 then rec.Patches[#rec.Patches+1]=makePatch(part,rect,y0,y1);rec.Rects[#rec.Rects+1]=rect end
  end
  hidden[part]=rec
  part.LocalTransparencyModifier=1
  hideFaces(part,rec)
  growClamp()
  -- a texture / decal that streams in after its floor is hidden at once too (a Decal ignores its part's modifier). The connection lives in
  -- the record only (a part that streams out takes it with it), not in the long-lived list: a 2000-stud floor part that streams in and out
  -- all session must not grow that list.
  rec.Conn=part.ChildAdded:Connect(function(d)if hidden[part]==rec then hideFaces(part,rec)end end)
 end
 -- A floor container (the map, Obby.Biomes, each biome model) is watched for floors that stream in: one connection per container instance. A
 -- container that left the game (streamed out, replaced) loses its connection at the next ground scan, so the long-lived list never grows.
 local watched={}
 local function watch(container,onChild)
  if watched[container]then return end
  local c=container.ChildAdded:Connect(onChild);watched[container]=c;table.insert(conns,c)
 end
 local function hook(container)watch(container,hideGround)end
 local function pruneConns()
  for container,c in pairs(watched)do
   if not c.Connected or not container:IsDescendantOf(workspace)then c:Disconnect();watched[container]=nil end
  end
  for i=#conns,1,-1 do if not conns[i].Connected then table.remove(conns,i)end end
 end
 function scanGround()
  local gone=false
  for part,rec in pairs(hidden)do
   if not part.Parent then
    for _,p in ipairs(rec.Patches)do p:Destroy()end;hidden[part]=nil;gone=true
    if rec.Conn then rec.Conn:Disconnect();rec.Conn=nil end
   else
    if part.LocalTransparencyModifier~=1 then part.LocalTransparencyModifier=1 end
    hideFaces(part,rec)
   end
  end
  if gone then growClamp()end
  for _,c in ipairs(map:GetChildren())do hideGround(c)end
  local obby=map:FindFirstChild('Obby');local biomes=obby and obby:FindFirstChild('Biomes')
  if biomes then
   watch(biomes,function(m)hook(m);for _,c in ipairs(m:GetChildren())do hideGround(c)end end)
   for _,m in ipairs(biomes:GetChildren())do hook(m);for _,c in ipairs(m:GetChildren())do hideGround(c)end end
  end
  pruneConns()
 end
 function armGround()hook(map);scanGround()end
 end

 -- State -----------------------------------------------------------------------------------------------------
 local focusX,focusZ,hasRoot=CX,geo.Z0,false
 local focusRow,focusCol=1,1
 local charRef,rootRef,humRef
 local now,frameNo,reduced=clock(),0,false
 local tier,wantTier,wantSince=0,0,0
 local tierCfg=K.Tier(3)
 local template=nil;local templateReady=false         -- template = a private, script-stripped copy of ReplicatedStorage.R142Keycap
 -- per key slot (and BARBASE + bar): part, centre, depth 0..1, height fudge, dress frame, cell
 local kPart,kX,kZ,kDepth,kOff,kFresh,kKey,kRow,kCol={},{},{},{},{},{},{},{},{}
 local slotOf={}                                     -- cell key (row * 64 + col) -> slot
 local freeSlots,freeN,made=table.create(256),0,0
 local plainSlot={}                                  -- slots whose part is a plain block (template not there yet)
 local shown={}                                      -- slot -> its part is visible (Transparency 0): a recycled key is only written when this changes
 local hideList,hideN={},0                           -- slots released in this window pass (hidden at its end unless they were dressed again)
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
 local facing,facingWant,facingSince=1,1,0                         -- the window's long side: +1 = toward +Z, -1 = toward -Z (see K.Facing)

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
 -- The Top face's canvas (K.TopCanvas / K.TopPoint, R151): x toward world -Z, y toward world +X. An unrotated label reads toward -Z with its up
 -- toward -X; turned 270 degrees (clockwise, about the label's centre) it reads toward -X = a +Z runner's right with its up toward +Z.
 local ROT=LG.Rotation
 local function letterLabel(parent)
  local l=Instance.new('TextLabel');l.Name='Letter';l.BackgroundTransparency=1;l.BorderSizePixel=0;l.AnchorPoint=V2(.5,.5)
  l.Rotation=ROT;l.Font=FONT;l.TextScaled=false;l.TextSize=TEXT;l.TextStrokeTransparency=1;l.Parent=parent
  return l
 end
 -- topExtra: how far the keycap mesh's visible top stands above the configured key top (measured once the template is there, see measureKeyTop).
 -- A letter strip is lifted by it; a pooled per-key letter, which rides on the key's own face, is offset toward the camera by it (ZOffset).
 local topExtra=0
 local function letterGui(name,parent)
  local gui=Instance.new('SurfaceGui');gui.Name=name;gui.Face=Enum.NormalId.Top;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
  gui.PixelsPerStud=PPS;gui.LightInfluence=0;gui.AlwaysOnTop=false;pcall(function()gui.MaxDistance=LG.MaxDistance end);gui.Parent=parent
  return gui
 end
 -- Strips wait in one pool per half row (k): a strip always serves the same half, so its labels keep their positions when it is bound again.
 -- A strip released in a pass is only parked (moved away, its gui switched off) at the end of the pass if no row took it again.
 local stripFree,stripFreeN={}, {}
 for k=1,STRIPS do stripFree[k]={};stripFreeN[k]=0 end
 local parkList,parkN={},0
 local stripsOfRow,stripRows,stripRowPos={},{},{}
 local STRIP_H=.05                                   -- the strip is a thin plate; its top face carries the SurfaceGui
 -- the strip's centre height: its top face stands Legend.Margin above the visible top of a resting key (a mesh key's top is KeyTop + TopOffset + the measured excess)
 local function visibleRestTop()return K.KeyTop(0)+(template and C.TopOffset or 0)+topExtra end
 local function stripCentreY()return visibleRestTop()+LG.Margin-STRIP_H/2 end
 local function newStrip(k)
  local p=Instance.new('Part');p.Name='LegendStrip';flat(p);p.Transparency=1;p.Size=V3(1,STRIP_H,1);p.CFrame=CF(CX,F-200,0);p.Parent=legendFolder
  local gui=letterGui('Letters',p)
  local labels={}
  for i=1,SPAN do local l=letterLabel(gui);l.Size=UDim2.fromOffset(KW*PPS,KW*PPS);labels[i]=l end
  -- the last value written to each label (a TextLabel change re-renders the whole 1440 x 131 px SurfaceGui: unchanged values are never written)
  return {Part=p,Gui=gui,Labels=labels,K=k,W=0,D=0,X=0,Z=0,Alpha=-1,On=true,Free=false,Parked=false,PX={},PY={},Tx={},Ink={},Vis={true,true,true,true,true,true,true,true,true,true,true}}
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
  local i=col-(k-1)*SPAN
  if st.Vis[i]~=shown then st.Vis[i]=shown;st.Labels[i].Visible=shown end
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
  local y=stripCentreY()
  local list={}
  for k=1,STRIPS do
   local st
   local n=stripFreeN[k]
   if n>0 then st=stripFree[k][n];stripFree[k][n]=nil;stripFreeN[k]=n-1 else st=newStrip(k)end
   st.Free=false;st.Parked=false
   local c0=(k-1)*SPAN+1;local c1=min(COLS,k*SPAN)
   local w=(c1-c0+1)*P;local xMin=LEFT-c1*P
   if abs(st.W-w)>1e-6 or abs(st.D-d)>1e-6 then st.W=w;st.D=d;st.Part.Size=V3(w,STRIP_H,d)end
   st.X,st.Z=xMin+w/2,z
   st.Part.CFrame=CF(st.X,y,z)
   if not st.On then st.On=true;st.Gui.Enabled=true end
   -- canvas (K.TopPoint): x runs toward -Z, so every label of the strip sits at the row's centre, x = d / 2; y runs toward +X from the strip's -X end
   local px=d/2*PPS
   for i=1,SPAN do
    local l=st.Labels[i];local c=c0+i-1
    if c<=c1 then
     local _,py=K.TopPoint(st.X,z,w,d,PPS,LEFT-(c-.5)*P,z)
     if st.PX[i]~=px or st.PY[i]~=py then st.PX[i]=px;st.PY[i]=py;l.Position=UDim2.fromOffset(px,py)end
     local text=K.Legend(row,c);if st.Tx[i]~=text then st.Tx[i]=text;l.Text=text end
     local ink=inkColor(stage,row,c);if st.Ink[i]~=ink then st.Ink[i]=ink;l.TextColor3=ink end
     local vis=labelShown(row,c);if st.Vis[i]~=vis then st.Vis[i]=vis;l.Visible=vis end
    elseif st.Vis[i]~=false then st.Vis[i]=false;l.Visible=false end
   end
   stripAlpha(st,K.LegendAlpha(tier,(row-focusRow)*facing)) -- (st.Alpha is kept across rows: only a changed fade is written)
   list[k]=st
  end
  stripsOfRow[row]=list;listAdd(stripRows,stripRowPos,row)
 end
 local function releaseStrips(row)
  local list=stripsOfRow[row];if not list then return end
  for _,st in ipairs(list)do
   st.Free=true;local k=st.K;stripFreeN[k]+=1;stripFree[k][stripFreeN[k]]=st
   parkN+=1;parkList[parkN]=st
  end
  stripsOfRow[row]=nil;listRemove(stripRows,stripRowPos,row)
 end
 -- per-key letters (a key that is down keeps its letter while it moves)
 local klFree,klFreeN,klMade={},0,0
 local klList,klPos,klStamp={},{},{}
 local klAll={}                                       -- every pooled per-key letter ever made (applyTopExtra reaches the idle ones too)
 local function keyLegendOffset(gui)
  -- a letter on a key's own face is exactly at the configured top; when the mesh stands higher it is drawn that much toward the camera
  if topExtra>0 then pcall(function()gui.ZOffset=topExtra+LG.Margin end)end
 end
 local function newKeyLegend()
  local gui=letterGui('KeyLegend',legendFolder)
  local l=letterLabel(gui);l.Position=UDim2.fromScale(.5,.5);l.Size=UDim2.fromScale(1,1)
  keyLegendOffset(gui)
  local e={Gui=gui,Label=l,Slot=0};klAll[#klAll+1]=e
  return e
 end
 -- The keycap's visible top was measured (once, after the template arrived): lift every bound strip, offset every per-key letter.
 local function applyTopExtra(extra)
  if extra==topExtra then return end
  topExtra=extra
  local y=stripCentreY()
  for _,r in ipairs(stripRows)do
   for _,st in ipairs(stripsOfRow[r])do st.Part.CFrame=CF(st.X,y,st.Z)end
  end
  for _,e in ipairs(klAll)do keyLegendOffset(e.Gui)end
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
 -- A keycap: a clone of the private, already stripped template. A template that stops cloning (it cannot normally: nobody else holds it) is
 -- dropped once, with one warning: from then on every new key is a plain block and nothing is retried (swapPass stops with it).
 local function cloneKeycap()
  if not template then return nil end
  local ok,c=pcall(template.Clone,template)
  if ok and typeof(c)=='Instance'and c:IsA('BasePart')then return c end
  template=nil
  warn('[R149] keyboard: the keycap template stopped cloning; the keys stay plain blocks')
  return nil
 end
 local function dressKeyPart(part)
  part.Name='Key';flat(part);part.Size=V3(KW,C.KeyY,KW);part.Transparency=1;part.CFrame=CF(CX,F-200,0);part.Parent=keyFolder
  return part
 end
 local function newKeyPart()
  local part=cloneKeycap();local mesh=part~=nil
  if not part then part=Instance.new('Part');part.Material=Enum.Material.SmoothPlastic end
  return dressKeyPart(part),mesh
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
   local part=kPart[s];part.Color=K.CellColor(stage,row,col,1)
   if not shown[s]then shown[s]=true;part.Transparency=0 end -- a slot recycled in the same pass is still visible: no write
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
    slotOf[key]=nil;kKey[s]=0
    hideN+=1;hideList[hideN]=s -- hidden at the end of the pass unless a row dressed in it takes the slot (then it is never written twice)
    freeN+=1;freeSlots[freeN]=s
   end
  end
  rowBound[row]=nil;listRemove(boundRows,boundRowPos,row);boundKeys-=COLS
 end
 -- swap a plain block for a keycap in place (the template replicated after the keys were dressed)
 local function swapSlot(s)
  local old=kPart[s];local clone=cloneKeycap();if not clone then return false end
  local part=dressKeyPart(clone)
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
  -- after a teleport (respawn, a pad) the rows right around the runner are missing: catch up with 4x the budget until they are there.
  -- A window that turned round (the camera swung to the other way) gets no burst: its long side is dressed nearest first within the
  -- normal budget (about 8 frames) and the rows it no longer needs are released at the same rate - one hitch of thousands of writes
  -- on a phone (where the Follow camera turns on every pack carry) became a few cheap frames.
  local burst=false
  for r=max(wa,focusRow-2),min(wb,focusRow+2)do if not rowBound[r]and not barOfRow[r]then burst=true;break end end
  local budget=floor(tierCfg.Bind*scale*(burst and C.TeleportBurst or 1));local relBudget=budget
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
  -- hide the keys that were released and not dressed again in this pass (a recycled key keeps its Transparency 0: one write, not two)
  for i=1,hideN do
   local slot=hideList[i];hideList[i]=nil
   if kKey[slot]==0 and shown[slot]then shown[slot]=nil;kPart[slot].Transparency=1 end
  end
  hideN=0
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
  -- park the strips no row took again: moved away, and neither drawn nor rendered (their gui is off until they are bound again; a parked
  -- strip sat within MaxDistance of the base). A strip that goes straight to another row is not touched.
  for i=1,parkN do
   local st=parkList[i];parkList[i]=nil
   if st.Free and not st.Parked then
    st.Parked=true;st.Part.CFrame=CF(CX,F-200,0)
    if st.On then st.On=false;st.Gui.Enabled=false end
   end
  end
  parkN=0
  return pending
 end

 -- Spacebars: one cream bar per biome start, always present ------------------------------------------------------
 local bars=geo.Bars
 do
 local cr,cg,cb=K.CreamRGB()
 for i,bar in ipairs(bars)do
  local depth=(bar.Z1-bar.Z0)-C.Gap
  local width=HALF*2-C.Gap
  local p=Instance.new('Part');p.Name='Spacebar';p.Size=V3(width,C.KeyY,depth);p.Color=Color3.fromRGB(cr,cg,cb)
  p.Material=Enum.Material.SmoothPlastic;flat(p);p.CFrame=CF(CX,F-200,0);p.Parent=keyFolder
  local gui=Instance.new('SurfaceGui');gui.Name='SpacebarLegend';gui.Face=Enum.NormalId.Top;gui.LightInfluence=0;gui.AlwaysOnTop=false
  gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=C.SpacebarPixelsPerStud;pcall(function()gui.MaxDistance=C.SpacebarMaxDistance end);gui.Parent=p
  -- The Top face's canvas is depth x width (x toward -Z, y toward +X: K.TopCanvas), so the name is ONE label before the turn .9 of the canvas' long
  -- side wide (X scale = width / depth * .9 of the short x axis) and .9 of its short side high (Y scale = depth / width * .9 of the long y axis),
  -- turned 270 degrees like every letter: it then reads across the track (toward -X), parallel to the SAFE ZONE line, upright for a runner
  -- approaching from the start. TextScaled fills the label's height (.9 of the bar's depth) with the biome name.
  local label=Instance.new('TextLabel');label.Name='Biome';label.BackgroundTransparency=1;label.BorderSizePixel=0
  label.AnchorPoint=V2(.5,.5);label.Position=UDim2.fromScale(.5,.5);label.Size=UDim2.fromScale(width/depth*.9,depth/width*.9);label.Rotation=ROT
  label.Font=FONT;label.TextScaled=true;label.TextStrokeTransparency=1;label.Text=string.upper(bar.Name);label.TextColor3=creamInk;label.Parent=gui
  local idx=BARBASE+i
  kPart[idx]=p;kX[idx]=CX;kZ[idx]=(bar.Z0+bar.Z1)/2;kDepth[idx]=0;kOff[idx]=0;kFresh[idx]=0
  queueMove(idx);p.Transparency=0
 end
 end

 -- The visible top of the keycap mesh (R151) ---------------------------------------------------------------------
 -- A probe key (a clone of the template dressed like a resting key, parked far off the track, invisible, queryable only for the instant of a
 -- ray) says how far the mesh's top stands above the configured key top: its Size.Y reading, a SpecialMesh child's offset / scale, and downward
 -- rays over its top face (centre, edge middles, corners; a RaycastParams include list holds only the probe, so nothing else can answer). The
 -- mesh's collision shape may not be there on the first frame: the rays are repeated every half second for up to 3 s. K.TopExtra combines them
 -- (>= 0, capped); the letter strips and the per-key letters follow it (applyTopExtra). The result is published on the keyboard folder
 -- (KeyTopConfigured / KeyTopExtra / LegendTop attributes) so Studio's Explorer shows what was measured.
 local function publishTop()
  if folder then
   folder:SetAttribute('KeyTopConfigured',K.KeyTop(0));folder:SetAttribute('KeyTopExtra',topExtra);folder:SetAttribute('LegendTop',visibleRestTop()+LG.Margin)
  end
 end
 local function measureKeyTop()
  local probe=cloneKeycap();if not probe then return end
  local restCentre=K.KeyTop(0)-C.KeyY/2+C.TopOffset
  local px,pz=CX,geo.Z0-1500
  probe.Name='KeyProbe';flat(probe);probe.Size=V3(KW,C.KeyY,KW);probe.Transparency=1;probe.CFrame=CF(px,restCentre,pz);probe.Parent=folder
  local cfgTop=restCentre+C.KeyY/2                    -- the probe's own configured top (a resting mesh key's: KeyTop + TopOffset)
  local canCast=type(workspace.Raycast)=='function'
  local tries=0
  local function cast()
   local hits={}
   if not canCast then return hits end
   pcall(function()
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={probe}
    probe.CanQuery=true
    local o=cfgTop+LG.MaxExtra+1;local len=C.KeyY+LG.MaxExtra+2
    for _,u in ipairs({-.4,0,.4})do for _,v in ipairs({-.4,0,.4})do
     local hit=workspace:Raycast(V3(px+u*KW,o,pz+v*KW),V3(0,-len,0),params)
     if hit and hit.Instance==probe then hits[#hits+1]=hit.Position.Y end
    end end
   end)
   pcall(function()probe.CanQuery=false end)
   return hits
  end
  local function meshExtra()
   local extra=0
   for _,d in ipairs(probe:GetChildren())do
    if d:IsA('SpecialMesh')then
     local off=d.Offset.Y;local up=0
     if d.MeshType~=Enum.MeshType.FileMesh then up=C.KeyY*(d.Scale.Y-1)/2 end -- a block-type mesh scales with the part; a file mesh's own size is unknown
     extra=max(extra,off+max(0,up))
    end
   end
   return extra
  end
  local function finish(hits)
   local okSize,sizeY=pcall(function()return probe.Size.Y end)
   local okMesh,me=pcall(meshExtra)
   probe:Destroy()
   if not okSize then sizeY=nil end
   if not okMesh then me=0 end
   local ok,extra=pcall(K.TopExtra,C.KeyY,sizeY,me,cfgTop,hits)
   if stopped then return end
   applyTopExtra(ok and extra or 0);publishTop()
  end
  local function poll()
   if stopped or not probe.Parent then return end
   tries+=1
   local hits=cast()
   if #hits>0 or not canCast or tries>=6 then finish(hits)else task.delay(.5,poll)end
  end
  poll()
 end

 -- Template (the keycap mesh) ------------------------------------------------------------------------------------
 task.spawn(function()
  local found=C.UseKeycapMesh~=false and RS:FindFirstChild('R142Keycap')or nil
  if not found and C.UseKeycapMesh~=false then local ok,t=pcall(function()return RS:WaitForChild('R142Keycap',30)end);if ok and typeof(t)=='Instance'then found=t end end
  if stopped then return end
  if found and found:IsA('BasePart')then
   -- a template that cannot be cloned (Archivable off) is no template: the keys stay plain blocks instead of being swapped every frame.
   -- The one clone made to find out IS the template from then on, stripped once of the toolbox's scripts / guis / sounds / decals: the
   -- ~2,000 key clones no longer copy those children only to destroy them again (and nobody else can stop it cloning).
   local ok,c=pcall(found.Clone,found)
   if ok and typeof(c)=='Instance'and c:IsA('BasePart')then stripPart(c);template=c end
  end
  templateReady=true
  if not template and C.UseKeycapMesh~=false then warn('[R149] keyboard: ReplicatedStorage.R142Keycap is missing; the keys are plain blocks')end
  if template then pcall(measureKeyTop)end
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
  -- R150: the click starts at the shared SoundTiming lead-in for its file (0 until measured), like every other cue.
  if Timing then Timing.Play(v.Sound,nil,.25)else v.Sound.TimePosition=0;v.Sound:Play()end
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
   if facingWant~=facing and now-facingSince>=C.FacingHoldSeconds then facing=facingWant;windowDirty=true end
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
   local x0,x1,z0,z1=p.X-half,p.X+half,p.Z-half,p.Z+half
   -- R151: the key ahead must be down when the foot gets there (the press takes PressSeconds): the footprint also covers PressLead seconds of
   -- the runner's velocity in front of it (never behind: the keys he leaves go up as before)
   local vel=rootRef.AssemblyLinearVelocity
   if typeof(vel)=='Vector3'then
    local lead,cap=C.PressLead,C.PressLeadMax
    local lx=math.clamp(vel.X*lead,-cap,cap);local lz=math.clamp(vel.Z*lead,-cap,cap)
    if lx>0 then x1+=lx else x0+=lx end
    if lz>0 then z1+=lz else z0+=lz end
   end
   local c1,c2,r1,r2=geo.CellRange(x0,x1,z0,z1)
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

 -- The camera: with the real floor hidden nothing stops the default camera from sinking into the keys or under the bed (looking up from the
 -- track at a distance of ~12 studs puts it at y 1..4). A render step just after the camera module (Camera priority + 1) lifts it, by
 -- translation only so its look direction stays, to at least `camMinY` while it is over the keyboard / the arena copy. One CFrame read and
 -- a few compares per frame, a CFrame write only when it actually sinks. Scriptable cameras (the pack opening, cut-scenes) and first
 -- person (the camera within ~1 stud of its focus) are left alone.
 local camMinY=K.KeyTop(0)+C.CameraAbove
 local SCRIPTABLE=Enum.CameraType.Scriptable
 local function cameraStep()
  if stopped then return end
  local cam=workspace.CurrentCamera
  if not cam or cam.CameraType==SCRIPTABLE then return end
  local cf=cam.CFrame;local p=cf.Position;local y=p.Y
  if y>=camMinY then return end
  local x,z=p.X,p.Z
  if x<clampRect[1]or x>clampRect[2]or z<clampRect[3]or z>clampRect[4]then return end
  local focus=cam.Focus
  if focus and(focus.Position-p).Magnitude<1.2 then return end
  cam.CFrame=cf+V3(0,camMinY-y,0)
 end

 -- Everything that can fail is above this line. Only now does the real floor go: a client whose start-up failed half way keeps a visible
 -- floor (and the pcall around start() restores it for good).
 publishTop()
 scanKeepers()
 table.insert(conns,CS:GetInstanceAddedSignal('BiomeKeeper'):Connect(addKeeper))
 armGround()
 pcall(Run.UnbindFromRenderStep,Run,CAMERA_STEP)
 if pcall(Run.BindToRenderStep,Run,CAMERA_STEP,Enum.RenderPriority.Camera.Value+1,cameraStep)then cameraBound=true end
 local failed=0
 -- a frame that errors (a destroyed part, a bad value) is reported; three in a row give the keyboard up and the floor back
 table.insert(conns,Run.RenderStepped:Connect(function(dt)
  local ok,err=pcall(step,dt)
  if ok then failed=0;return end
  failed+=1;warn('[R149] keyboard: frame error: '..tostring(err))
  if failed>=3 and not stopped then warn('[R149] keyboard: giving up, the real floor is shown again');cleanup()end
 end))
end

-- A start() that errors leaves nothing behind: the floor is shown again, everything it made is removed, and it is not retried.
local function safeStart()
 if started or stopped then return end
 local ok,err=pcall(start)
 if not ok then warn('[R149] keyboard: start-up failed, the real floor stays: '..tostring(err));cleanup()end
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
 if mapComplete()then safeStart()
 elseif mapStarted()and not waiting then waiting=true;task.delay(2,safeStart)end
 if started and link then link:Disconnect();link=nil end
end
tryStart()
if not started then link=map.AttributeChanged:Connect(tryStart);table.insert(conns,link)end
script.Destroying:Connect(cleanup)
