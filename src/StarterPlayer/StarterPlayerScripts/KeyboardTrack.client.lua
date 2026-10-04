-- R147 (owner): the candy keyboard runway, client only (replaces R142-R146). The biome track is dressed as one long keyboard
-- of giant candy / chocolate keys that click down under the runners' feet. Everything here is local visuals: no remotes,
-- no server code, nothing collides or can be queried, and the real floor is never touched or hidden (the keys sit on top of it,
-- the chocolate bed fills the gaps between them). The grid and look come from ReplicatedStorage.KeyboardTrack.
--  * Far rows: one thin candy slab per row, built in chunks of 16 rows near the camera and freed when far.
--  * Near rows (a window around the runner; 80/120/160 studs by ClientFxBudget tier): pooled keycap MeshParts cloned from
--    ReplicatedStorage.R142Keycap, in a ring buffer (row r lives in slot r mod rows-in-window), 64 reassignments per frame.
--    The far slab of a row is hidden while the row has keys.
--  * Presses: the local character every frame (Humanoid.FloorMaterial ~= Air), other players and keepers at 30 Hz. The union of
--    pressed keys is diffed with the last frame; only the changing keys animate (quad-out down, back-out up) via BulkMoveTo.
--  * Shovel holes: keys within 2 studs of a hole's Pit hide while it exists. Clicks: 10 pooled Sounds, rate limited.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService');local CS=game:GetService('CollectionService');local Content=game:GetService('ContentProvider')
local K=require(RS:WaitForChild('KeyboardTrack'))
local C=K.Config
local player=Players.LocalPlayer
local map=workspace:WaitForChild('ChestChaseMap')
local V3,V2,CF=Vector3.new,Vector2.new,CFrame.new
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local clock=os.clock
local COLS,P,F=C.Columns,C.Pitch,C.FloorTop
local NRMAX=floor(C.MaxNear/COLS)
local AIR=Enum.Material.Air

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
 local rows=geo.Rows;local Z0=geo.Z0;local spaceRow,rowStage=geo.SpaceRow,geo.RowStage
 if rows<1 then warn('[R147] keyboard: the map has no track rows');return end
 local CX=geo.CenterX

 folder=Instance.new('Folder');folder.Name='KeyboardTrackVisuals';folder.Parent=workspace
 local function sub(name)local f=Instance.new('Folder');f.Name=name;f.Parent=folder;return f end
 local bedFolder,stripFolder,keyFolder,soundFolder=sub('Bed'),sub('Strips'),sub('Keys'),sub('Sounds')
 local function visual(class,parent)
  local p=Instance.new(class);p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.Parent=parent;return p
 end
 local function block(name,size,cframe,rgb,parent)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cframe;p.Color=Color3.fromRGB(rgb[1],rgb[2],rgb[3])
  p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
 end

 -- Chocolate bed and rails: a few long pieces (each at most 1024 studs) covering every row; built once.
 local zFrom,zTo=Z0,Z0+rows*P
 for i,seg in ipairs(K.Segments(zFrom,zTo,C.BedMaxLength))do
  block('Bed'..i,V3(C.BedWidth,C.BedThickness,seg.Length),CF(CX,F+C.BedRise-C.BedThickness/2,seg.Centre),C.BedColor,bedFolder)
  for _,side in ipairs({-1,1})do
   block('Rail'..i,V3(C.RailWidth,C.RailHeight,seg.Length),CF(CX+side*C.RailX,F+C.RailHeight/2,seg.Centre),C.RailColor,bedFolder)
  end
 end

 -- State -----------------------------------------------------------------------------------------------------
 local focusX,focusZ,hasRoot=CX,0,false
 local charRef,rootRef,humRef
 local now,frameNo,reduced=clock(),0,false
 local NR=0                                   -- rows in the near window (0 = not read yet)
 local ringRow={}                             -- ring slot -> the row bound to it (0 = none)
 for s=1,NRMAX do ringRow[s]=0 end
 -- per key (index = (ring slot-1)*6 + column)
 local keyPart,keyGui,keyLabel,keyCanvas={},{},{},{}
 local keyRow,keyX,keyZ,keyDepth={},{},{},{}
 local keyShown,keyWide,keyLegend,keyFresh={},{},{},{}
 local downPos,animPos,animT0,animFrom,animTo,animDur={},{},{},{},{},{}
 local stampAt,moveMark={},{}
 local downList,animList,moveList={},{},{}
 local moveN=0;local moveParts,moveCFs={},{}
 local strips,chunks={},{}
 local holeHidden={};local holeSig=nil;local holesFolder=nil
 local legendDirty=true
 local templateReady=false;local template=nil
 -- other players / keepers (sampled at 30 Hz): cells they press
 local oRow,oCol,oKind,oN={},{},{},0
 local keepers={}

 -- Templates ---------------------------------------------------------------------------------------------------
 local function legendInk()return Color3.fromRGB(K.InkRGB[1],K.InkRGB[2],K.InkRGB[3])end
 local function makeKey(idx)
  local part=template and template:Clone()or Instance.new('Part')
  part.Name='Key';part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
  part.Size=V3(C.KeyX,C.KeyY,C.KeyZ);part.Transparency=1;part.CFrame=CF(CX,F-200,0)
  for _,d in ipairs(part:GetDescendants())do if d:IsA('BaseScript')or d:IsA('Sound')then d:Destroy()end end
  local gui=part:FindFirstChildWhichIsA('SurfaceGui')
  if not gui then
   gui=Instance.new('SurfaceGui');gui.Name='KeyLegend';gui.Face=Enum.NormalId.Top;gui.LightInfluence=0;gui.AlwaysOnTop=false
   gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=V2(256,256);gui.Parent=part
  end
  local label=gui:FindFirstChildWhichIsA('TextLabel',true)
  if not label then
   label=Instance.new('TextLabel');label.Name='Letter';label.BackgroundTransparency=1;label.BorderSizePixel=0
   label.Size=UDim2.fromScale(1,1);label.Font=Enum.Font.FredokaOne;label.TextScaled=true;label.TextStrokeTransparency=1;label.Parent=gui
  end
  gui.Enabled=false
  part.Parent=keyFolder
  keyPart[idx]=part;keyGui[idx]=gui;keyLabel[idx]=label;keyCanvas[idx]=gui.CanvasSize
  keyRow[idx]=0;keyX[idx]=CX;keyZ[idx]=0;keyDepth[idx]=0;keyShown[idx]=false;keyWide[idx]=false;keyLegend[idx]=false;keyFresh[idx]=0
  return part
 end
 task.spawn(function()
  local found=RS:FindFirstChild('R142Keycap')
  if not found then local ok,t=pcall(function()return RS:WaitForChild('R142Keycap',30)end);if ok and typeof(t)=='Instance'then found=t end end
  if stopped then return end
  template=found;templateReady=true
  if not found then warn('[R147] keyboard: ReplicatedStorage.R142Keycap is missing; using plain blocks for the near keys')end
 end)

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
   local idx=moveList[i];moveParts[i]=keyPart[idx];moveCFs[i]=CF(keyX[idx],K.KeyCenterY(keyDepth[idx]),keyZ[idx])
  end
  for i=#moveParts,moveN+1,-1 do moveParts[i]=nil;moveCFs[i]=nil end
  workspace:BulkMoveTo(moveParts,moveCFs,Enum.BulkMoveMode.FireCFrameChanged)
  moveN=0
 end
 local function clearKeyState(idx)
  if downPos[idx]then listRemove(downList,downPos,idx)end
  if animPos[idx]then listRemove(animList,animPos,idx)end
  keyDepth[idx]=0
 end

 -- Far strips ----------------------------------------------------------------------------------------------------
 local CH=C.StripChunk
 local function stripOf(row)return(row-1)//CH end
 local function setStripHidden(row,hidden)
  local s=strips[row];if s then s.Transparency=hidden and 1 or 0 end
 end
 local function buildChunk(c)
  local first=c*CH+1;local last=min(rows,first+CH-1)
  local list={}
  for row=first,last do
   local style=K.RowStyle(row,rowStage[row]or 0,spaceRow[row]~=nil)
   local z=Z0+(row-.5)*P
   local s=block('Strip',V3(C.StripSize[1],C.StripSize[2],C.StripSize[3]),CF(CX,F+C.RestRise-C.StripSize[2]/2,z),style.RGB,stripFolder)
   s.Transparency=(NR>0 and ringRow[row%NR+1]==row)and 1 or 0
   strips[row]=s;list[#list+1]=s
  end
  chunks[c]={First=first,Last=last,Parts=list}
 end
 local function freeChunk(c)
  local ch=chunks[c];if not ch then return end;chunks[c]=nil
  for row=ch.First,ch.Last do strips[row]=nil end
  for _,s in ipairs(ch.Parts)do s:Destroy()end
 end
 local chunkPending=true
 local function updateChunks(budget)
  local lo=max(1,min(rows,geo.RowOfZ(focusZ-C.BuildRadius)));local hi=max(1,min(rows,geo.RowOfZ(focusZ+C.BuildRadius)))
  local cLo,cHi=stripOf(lo),stripOf(hi)
  local cf=max(cLo,min(cHi,stripOf(max(1,min(rows,geo.RowOfZ(focusZ))))))
  chunkPending=false
  for d=0,max(cf-cLo,cHi-cf)do
   for sign=1,(d==0 and 1 or 2)do
    local c=sign==1 and cf+d or cf-d
    if c>=cLo and c<=cHi and not chunks[c]then
     if budget>=CH then buildChunk(c);budget-=CH else chunkPending=true end
    end
   end
  end
  -- free chunks that are far away (hysteresis: built within 1100, freed beyond 1300)
  for c,ch in pairs(chunks)do
   local zLo=Z0+(ch.First-1)*P;local zHi=Z0+ch.Last*P
   local dist=max(0,zLo-focusZ,focusZ-zHi)
   if dist>C.FreeRadius then freeChunk(c)end
  end
 end

 -- Near keys (ring buffer) --------------------------------------------------------------------------------------
 local function wantShown(row,col)
  if spaceRow[row]then
   if col~=1 then return false end
   for c=1,COLS do if holeHidden[row*8+c]then return false end end
   return true
  end
  return not holeHidden[row*8+col]
 end
 local function setShown(idx,on)
  if keyShown[idx]==on then return end
  keyShown[idx]=on;keyPart[idx].Transparency=on and 0 or 1
  if not on then clearKeyState(idx);queueMove(idx);legendDirty=true end
 end
 local function bindRow(row)
  local s=row%NR+1;local old=ringRow[s]
  if old~=0 and old~=row then setStripHidden(old,false)end
  ringRow[s]=row
  local space=spaceRow[row]~=nil
  local style=K.RowStyle(row,rowStage[row]or 0,space)
  local z=Z0+(row-.5)*P;local base=(s-1)*COLS
  for col=1,COLS do
   local idx=base+col
   local part=keyPart[idx]or makeKey(idx)
   clearKeyState(idx)
   keyRow[idx]=row;keyFresh[idx]=frameNo
   keyZ[idx]=z;keyX[idx]=space and CX or(geo.CellCenter(row,col))
   local wide=space and col==1
   if keyWide[idx]~=wide then
    keyWide[idx]=wide
    part.Size=V3(wide and C.SpaceX or C.KeyX,C.KeyY,C.KeyZ)
    local canvas=keyCanvas[idx];keyGui[idx].CanvasSize=wide and V2(canvas.X*C.SpaceX/C.KeyX,canvas.Y)or canvas
   end
   part.Color=K.KeyColor(style,row,wide and 1 or col)
   if keyLegend[idx]then keyGui[idx].Enabled=false;keyLegend[idx]=false end
   local on=wantShown(row,col)
   keyShown[idx]=on;part.Transparency=on and 0 or 1
   queueMove(idx)
  end
  setStripHidden(row,true);legendDirty=true
 end
 local function unbindAll()
  for s=1,NRMAX do
   local row=ringRow[s]
   if row~=0 then
    setStripHidden(row,false);ringRow[s]=0
    for col=1,COLS do
     local idx=(s-1)*COLS+col
     if keyPart[idx]then
      clearKeyState(idx);keyRow[idx]=0;keyShown[idx]=false;keyPart[idx].Transparency=1
      if keyLegend[idx]then keyGui[idx].Enabled=false;keyLegend[idx]=false end
     end
    end
   end
  end
 end
 local function updateWindow()
  if NR==0 or not templateReady then return end
  local fr=geo.RowOfZ(focusZ)
  local rA=max(1,min(fr-NR//2,rows-NR+1));local rB=min(rows,rA+NR-1)
  local mid=max(rA,min(rB,fr))
  local budget=C.MaxReassignPerFrame
  for k=0,NR do
   for sign=1,(k==0 and 1 or 2)do
    local row=sign==1 and mid+k or mid-k
    if row>=rA and row<=rB and ringRow[row%NR+1]~=row then
     if budget<COLS then return end
     bindRow(row);budget-=COLS
    end
   end
  end
 end
 -- Legends: only keys near the runner carry their letter (SurfaceGui enabled).
 local LR2=C.LegendRadius*C.LegendRadius
 local function legendPass()
  legendDirty=false
  for s=1,NR do
   local row=ringRow[s]
   if row~=0 then
    for col=1,COLS do
     local idx=(s-1)*COLS+col
     local dz=keyZ[idx]-focusZ
     local ax=max(0,abs(keyX[idx]-focusX)-(keyWide[idx]and C.SpaceX or C.KeyX)/2)
     local on=keyShown[idx]and dz*dz+ax*ax<=LR2
     if keyLegend[idx]~=on then
      keyLegend[idx]=on
      if on then
       local label=keyLabel[idx]
       label.Text=keyWide[idx]and string.upper(spaceRow[row].Name)or K.Legend(row,col)
       label.TextColor3=legendInk()
      end
      keyGui[idx].Enabled=on
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
  local anchor=visual('Part',soundFolder);anchor.Name='KeyClick';anchor.Size=V3(.2,.2,.2);anchor.Transparency=1
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
  local from=keyDepth[idx];local span=min(1,abs(to-from))
  animFrom[idx]=from;animTo[idx]=to;animT0[idx]=now
  animDur[idx]=to==1 and max(C.PressSeconds*span,.015)or max(C.ReleaseSeconds*max(span,.35),.04)
  if not animPos[idx]then listAdd(animList,animPos,idx)end
 end
 local function pressKey(idx,kind)
  listAdd(downList,downPos,idx)
  if keyFresh[idx]==frameNo then
   -- a key dressed this very frame under a standing runner: down at once and silent (a tier change must not click 240 times)
   if animPos[idx]then listRemove(animList,animPos,idx)end
   keyDepth[idx]=1;queueMove(idx)
  else
   startAnim(idx,1) -- Reduced Motion: animate() finishes it in the same frame
   click(kind,keyX[idx],keyZ[idx])
  end
 end
 local function releaseKey(idx)
  listRemove(downList,downPos,idx)
  startAnim(idx,0)
 end
 local function cellIdx(row,col)
  if NR==0 then return 0 end
  local s=row%NR+1
  if ringRow[s]~=row then return 0 end
  if spaceRow[row]then col=1 end
  local idx=(s-1)*COLS+col
  if not keyShown[idx]then return 0 end
  return idx
 end
 local function touch(idx,kind)
  if stampAt[idx]==frameNo then return end
  stampAt[idx]=frameNo
  if not downPos[idx]then pressKey(idx,kind)end
 end
 local function animate()
  local ease=K.Ease
  for i=#animList,1,-1 do
   local idx=animList[i]
   local to=animTo[idx]
   local t=(now-animT0[idx])/animDur[idx]
   if t>=1 or reduced then keyDepth[idx]=to;listRemove(animList,animPos,idx)
   else keyDepth[idx]=animFrom[idx]+(to-animFrom[idx])*(to==1 and ease.QuadOut(t)or ease.BackOut(t))end
   queueMove(idx)
  end
 end

 -- Other players and keepers (30 Hz) ------------------------------------------------------------------------------
 local function addFootprint(x,z,half,kind)
  local c1,c2,r1,r2=geo.CellRange(x-half,x+half,z-half,z+half)
  for r=r1,r2 do for c=c1,c2 do
   if oN<512 then oN+=1;oRow[oN]=r;oCol[oN]=c;oKind[oN]=kind end
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
  local range=K.NearRadiusFor(3)+40
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

 -- Shovel holes (TrackHoleService: Folder 'TrackHoles' in the map's _GameplayRuntime, a Model per hole with a 'Pit' part).
 local function findHoles()
  if holesFolder and holesFolder:IsDescendantOf(workspace)then return holesFolder end
  local runtime=map:FindFirstChild('_GameplayRuntime')
  holesFolder=runtime and runtime:FindFirstChild('TrackHoles')
  if not holesFolder then runtime=workspace:FindFirstChild('_GameplayRuntime');holesFolder=runtime and runtime:FindFirstChild('TrackHoles')end
  if not holesFolder then holesFolder=map:FindFirstChild('TrackHoles',true)end
  return holesFolder
 end
 local function scanHoles()
  local pits=nil;local sig=0
  local f=findHoles()
  if f then
   for _,model in ipairs(f:GetChildren())do
    local pit=model:FindFirstChild('Pit')
    if pit then
     local pos=pit.Position;pits=pits or{};pits[#pits+1]=pos;sig=sig*31+floor(pos.X*8)*7+floor(pos.Z*8)*13+1;sig=sig%1000000007
    end
   end
  end
  if sig==holeSig then return end
  holeSig=sig
  local hidden={};local R=C.HoleReach
  if pits then
   for _,pos in ipairs(pits)do
    local c1,c2,r1,r2=geo.CellRange(pos.X-R,pos.X+R,pos.Z-R,pos.Z+R)
    for r=r1,r2 do for c=c1,c2 do hidden[r*8+c]=true end end
   end
  end
  holeHidden=hidden
  for s=1,NR do
   local row=ringRow[s]
   if row~=0 then for col=1,COLS do setShown((s-1)*COLS+col,wantShown(row,col))end end
  end
 end

 -- Frame ---------------------------------------------------------------------------------------------------------
 local tNear,tHole,tKeeper,tChunk,tLegend,tSample=0,0,0,0,0,0
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
 end
 local function step(dt)
  now=clock();frameNo+=1;reduced=Gui.ReducedMotionEnabled==true
  updateFocus()
  tNear+=dt;tHole+=dt;tKeeper+=dt;tChunk+=dt;tLegend+=dt;tSample+=dt
  if NR==0 or tNear>=.5 then
   tNear=0
   local want=K.NearRows(Fx and Fx.Get()or 3)
   if want~=NR then unbindAll();NR=want;legendDirty=true end
  end
  if tHole>=.25 then tHole=0;scanHoles()end
  if tKeeper>=2 then tKeeper=0;scanKeepers()end
  updateWindow()
  if chunkPending or tChunk>=.1 then tChunk=0;updateChunks(C.MaxStripsPerFrame)end
  -- presses: the local runner every frame, everyone else from the last 30 Hz sample
  if tSample>=1/C.PlayerSampleHz then tSample=tSample%(1/C.PlayerSampleHz);sampleOthers()end
  if hasRoot and humRef and humRef.Health>0 and humRef.FloorMaterial~=AIR then
   local p=rootRef.Position;local half=C.PlayerFootprint
   local c1,c2,r1,r2=geo.CellRange(p.X-half,p.X+half,p.Z-half,p.Z+half)
   for r=r1,r2 do for c=c1,c2 do local idx=cellIdx(r,c);if idx>0 then touch(idx,1)end end end
  end
  for i=1,oN do local idx=cellIdx(oRow[i],oCol[i]);if idx>0 then touch(idx,oKind[i])end end
  for i=#downList,1,-1 do local idx=downList[i];if stampAt[idx]~=frameNo then releaseKey(idx)end end
  animate()
  if legendDirty or tLegend>=.25 then tLegend=0;legendPass()end
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
