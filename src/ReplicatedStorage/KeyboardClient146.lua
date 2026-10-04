-- Continuous fixed-pitch track grid; bounded local extrusion/legends; authoritative actor pressure.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService');local Content=game:GetService('ContentProvider');local Text=game:GetService('TextService')
local Core=table.clone(require(RS:WaitForChild('KeyboardCore143')));Core.Height=2.4;Core.RestTop=2.2;local Scene=require(RS:WaitForChild('KeyboardScene143'))
local remote=RS:WaitForChild('Keyboard143State');local bare=Instance.new('Part');bare.Name='PrimitiveKey';bare.Shape=Enum.PartType.Block;bare.Anchored=true;bare.CanCollide=false;bare.CanTouch=false;bare.CanQuery=false;bare.CastShadow=false;bare.Material=Enum.Material.SmoothPlastic;for _,k in ipairs({'TopSurface','BottomSurface','LeftSurface','RightSurface','FrontSurface','BackSurface'})do bare[k]=Enum.SurfaceType.Smooth end
local folder=Instance.new('Folder');folder.Name='R146KeyboardVisuals';folder.Parent=workspace
local rows,view=nil,{Sequence=-1,Held={}};local byRow,masks={},{ }
local live,pool,active={}, {},{};local pending={};local cursor=1;local count=0
local static,pieces,staticCursor={}, {},1;local staticReady=false;local oldLocal={}
local lastAt,nextPlan=nil,0;local lastCamera=nil;local lastViewport=nil;local lastFov=nil;local predicted,clicked={},{};local rowLive,rowDirty,rowInk={}, {},{};local rowCanvases={};local glyphWanted={};local glyphPlan={};local glyphPlanCursor=1;local glyphCount=0;local activeCount=0;local MAX_CAPS=8192;local MAX_ACTIVE=640;local MAX_ROWS=384;local ADVANCE=nil;local FrameNo=0;local canvasDirty=true;local glyphCarrierCount=0;local deferredDown={};local columnDirty={};local columnParts={};local hullModels={};local hullPartOwners={};local hullHeld={};local hullModelCount=0;local hullEpoch=0;local glyphChunks={};local glyphAssignments={};local dirtyGlyphIds={};local slotPending={};local slotCursor=1;local labelsAllocated=0;local sharedCanvases=0;local chunkPixelCount=0;local labelPool={};local canvasDirtyChunks={};local glyphOwners={};local activeQueue={};local activeCursor=1;local urgent={};local haloDirty=false;local now=0;local legendCount=0
local Stats={Caps=0,CapWrites=0,StaticParts=0,Legends=0,Plans=0,CellVisits=0,PropVisits=0,Registry=0,Watched=0,Listeners=0,DirtyVisits=0,MaskVisits=0,Animations=0}
local function rawPart(class,name,size,cf,color)
 local p=Instance.new(class);p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=Enum.Material.SmoothPlastic;if class=='Part'then p.Shape=Enum.PartType.Block;for _,k in ipairs({'TopSurface','BottomSurface','LeftSurface','RightSurface','FrontSurface','BackSurface'})do p[k]=Enum.SurfaceType.Smooth end end
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=folder;return p
end
local sounds={};local soundCursor=1;local audioReady=false
for i=1,12 do
 local p=rawPart('Part','KeySound',Vector3.one*.05,CFrame.new(),Color3.new());p.Transparency=1
 local sound=Instance.new('Sound');sound.SoundId='rbxassetid://113108830240353';sound.Volume=1;sound.RollOffMode=Enum.RollOffMode.Linear;sound.RollOffMinDistance=24;sound.RollOffMaxDistance=180;sound.Parent=p
 sounds[i]={Part=p,Sound=sound}
end
task.spawn(function()
 local okay,why=pcall(function()Content:PreloadAsync({sounds[1].Sound},function(_,status)audioReady=status==Enum.AssetFetchStatus.Success end)end)
 if not okay or not audioReady then warn('[R146] Supplied key click could not load; check experience permissions: '..tostring(why))end
end)
local function decode(id)
 local s,x,z=id:match('^(%d+):(%d+):(%d+)$');return byRow[tonumber(s)],tonumber(x),tonumber(z)
end
local function point(row,x,z)
 local lx,lz=Core.center(row.Grid,x,z);return row.Frame:PointToWorldSpace(Vector3.new(lx,0,lz))
end
local function click(id)
 if not audioReady then return end
 local row,x,z=decode(id);if not row or not row.Keyboard then return end
 local p=point(row,x,z);local camera=workspace.CurrentCamera
 if not camera or(camera.CFrame.Position-p).Magnitude>180 then return end
 local entry=sounds[soundCursor];soundCursor=soundCursor%#sounds+1
 entry.Sound:Stop();entry.Part.CFrame=CFrame.new(p);entry.Sound.PlaybackSpeed=.98+(soundCursor%5)*.01;entry.Sound.TimePosition=0;entry.Sound:Play()
end
local function center()
 local p=Players.LocalPlayer;local root=p.Character and p.Character:FindFirstChild('HumanoidRootPart')
 return root and root.Position or(workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
end
local function unhide()
 for p,value in pairs(oldLocal)do if p.Parent and p.LocalTransparencyModifier==1 then p.LocalTransparencyModifier=value end end;oldLocal={}
end
local function hideFloor(p)
 if not staticReady or not p:IsA('BasePart')or not p.Name:match('^BiomeGround_%d+$')then return end
 local stage=tonumber(p.Name:match('(%d+)$'));local row
 for _,candidate in pairs(byRow)do if candidate.Stage==stage and candidate.Keyboard then row=candidate;break end end
 if not row or p.CFrame*CFrame.new(0,p.Size.Y/2,0)~=row.Frame or p.Size.X~=row.Grid.X or p.Size.Z~=row.Grid.Z then return end
 if oldLocal[p]==nil then oldLocal[p]=p.LocalTransparencyModifier end;p.LocalTransparencyModifier=1
end
local function pressure(id,e)return predicted[id]or view.Held[id]or hullHeld[id]or(e and e.Mask)or false end
local function cell(id)local row,x,z=decode(id);if row then return row,x,z end end
local function rowKey(row,z)return row.Id..':'..z end
local function markColumn(row,x)
 local key=row.Id..':'..x;columnDirty[key]={Row=row,X=x};for _,p in ipairs(columnParts[key]or{})do p.Parent=nil end
end
local function dirtyRow(row,z,x)
 rowDirty[rowKey(row,z)]={Row=row,Z=z}
 if x and not live[Core.id(row.Id,x,z)]then markColumn(row,x-1);markColumn(row,x)end
end
local function dirtyGlyph(id)dirtyGlyphIds[id]=true;local a=glyphAssignments[id];if a then a.Label.TextTransparency=1 end end
local function letter(x,z)local alphabet='QWERTYUIOPASDFGHJKLZXCVBNM';local n=(x*7+z*11)%#alphabet+1;return alphabet:sub(n,n)end
local function textInk(color)local dark=color.R*.2126+color.G*.7152+color.B*.0722<.38;return dark and Color3.fromRGB(245,242,232)or Color3.fromRGB(30,25,34)end
local function glyph(parent,size,cf,color,text,canvas)
 local carrier=rawPart('Part','LegendCarrier',size,cf,color);carrier.Transparency=1;carrier.Parent=parent
 local gui=Instance.new('SurfaceGui');gui.Name='KeyLegend';gui.Adornee=carrier;gui.Face=Enum.NormalId.Front;gui.AlwaysOnTop=false;gui.Enabled=true;gui.LightInfluence=0;gui.Brightness=1;gui.MaxDistance=1200;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=canvas;gui.Parent=carrier
 local label=Instance.new('TextLabel');label.Name='Letter';label.BackgroundTransparency=1;label.BorderSizePixel=0;label.Size=UDim2.fromScale(1,1);label.Position=UDim2.fromScale(0,0)
 label.Font=Enum.Font.GothamBold;label.TextSize=24;label.TextScaled=false;label.TextWrapped=false;label.RichText=false;label.TextXAlignment=Enum.TextXAlignment.Center;label.TextYAlignment=Enum.TextYAlignment.Center
 label.Text=text;label.TextColor3=textInk(color);label.TextStrokeColor3=label.TextColor3.R>.5 and Color3.fromRGB(30,25,34)or Color3.fromRGB(245,242,232);label.TextStrokeTransparency=1;label.TextTransparency=0;label.Parent=gui
 return{Part=carrier,Gui=gui,Label=label}
end
local function clearGlyph(e)if e.Glyph then e.Glyph.Part:Destroy();e.Glyph=nil;glyphOwners[e.Id]=nil;glyphCarrierCount-=1;dirtyGlyph(e.Id) end end
local function recycle(id,e)
 markColumn(e.Row,e.X-1);markColumn(e.Row,e.X);live[id]=nil;active[id]=nil;dirtyGlyph(id);clearGlyph(e);e.Part.Parent=nil;pool[#pool+1]=e.Part;count-=1;dirtyRow(e.Row,e.Z,e.X)
end
local function axis(poly)
 if #poly~=4 then return false end
 for i,p in ipairs(poly)do local q=poly[i%4+1];if math.abs(p[1]-q[1])>1e-5 and math.abs(p[2]-q[2])>1e-5 then return false end end;return true
end
local function rectangle(poly)
 local a,b,c,d=math.huge,math.huge,-math.huge,-math.huge
 for _,q in ipairs(poly)do a=math.min(a,q[1]);b=math.min(b,q[2]);c=math.max(c,q[1]);d=math.max(d,q[2])end;return a,b,c,d
end
local function makeRibbon(row,z,first,last,down,list)
 local g=row.Grid;local x0=-g.X/2+(first-1)*g.DX+.07;local x1=-g.X/2+last*g.DX-.07;local _,middle=Core.center(g,1,z)
 local polys=Scene.subtract(Scene.rectangle(x0,middle-g.DZ/2+.07,x1,middle+g.DZ/2-.07),masks[row.Id]);local top=down and Core.DownTop or Core.RestTop
 for _,poly in ipairs(polys)do
  if axis(poly)then local a,b,c,d=rectangle(poly);if c-a>.001 and d-b>.001 then
   local part=bare:Clone();part.Name='FarKeyRow';part.Size=Vector3.new(c-a,Core.Height,d-b);part.Color=Scene.fill(row.Stage);part.CFrame=row.Frame*CFrame.new((a+c)/2,top-Core.Height/2,(b+d)/2);part.Parent=folder;list[#list+1]=part
  end
  else
   -- Clipped boundary polygons use the proven thin triangle decomposition; raised height stays exact.
   for i=2,#poly-1 do local a,b,c=poly[1],poly[i],poly[i+1];local va=row.Frame:PointToWorldSpace(Vector3.new(a[1],top-.008,a[2]));local vb=row.Frame:PointToWorldSpace(Vector3.new(b[1],top-.008,b[2]));local vc=row.Frame:PointToWorldSpace(Vector3.new(c[1],top-.008,c[2]));local ab,bc,ca=(va-vb).Magnitude,(vb-vc).Magnitude,(vc-va).Magnitude
    if ab>bc and ab>=ca then va,vb,vc=vc,va,vb elseif ca>bc then va,vb,vc=vb,vc,va end
    local zz=(vc-vb).Unit;local dd=vb+zz*(va-vb):Dot(zz);local h=(va-dd).Magnitude
    if h>.001 then local xx=(va-dd).Unit:Cross(zz).Unit;local yy=zz:Cross(xx).Unit;local l,r=(dd-vb).Magnitude,(vc-dd).Magnitude
     if l>.001 then list[#list+1]=rawPart('WedgePart','FarBoundary',Vector3.new(.016,h,l),CFrame.fromMatrix((va+vb)/2,xx,yy,zz),Scene.fill(row.Stage))end
     if r>.001 then list[#list+1]=rawPart('WedgePart','FarBoundary',Vector3.new(.016,h,r),CFrame.fromMatrix((va+vc)/2,-xx,yy,-zz),Scene.fill(row.Stage))end
    end
   end
  end
 end
end
local function rebuildRow(row,z)
 local key=rowKey(row,z);local list=rowLive[key]or{};for _,part in ipairs(list)do part:Destroy()end;list={};rowLive[key]=list
 local first,lastState=1,nil
 local function state(x)local id=Core.id(row.Id,x,z);if live[id]then return'fine'end;return(view.Held[id]or hullHeld[id])and'down'or'rest'end
 lastState=state(1)
 for x=2,row.Grid.NX+1 do local nextState=x<=row.Grid.NX and state(x)or'end'
  if nextState~=lastState then if lastState~='fine'then makeRibbon(row,z,first,x-1,lastState=='down',list)end;first=x;lastState=nextState end
 end
 rowDirty[key]=nil
end
local function trianglePlan(row,a,b,c,color)
 local ab,bc,ca=(a-b).Magnitude,(b-c).Magnitude,(c-a).Magnitude
 if ab>bc and ab>=ca then a,b,c=c,a,b elseif ca>bc then a,b,c=b,c,a end
 local z=(c-b).Unit;local d=b+z*(a-b):Dot(z);local h=(a-d).Magnitude;if h<.001 then return end
 local x=(a-d).Unit:Cross(z).Unit;local y=z:Cross(x).Unit
 local left,right=(d-b).Magnitude,(c-d).Magnitude
 if left>.001 then pieces[#pieces+1]={Class='WedgePart',Size=Vector3.new(.016,h,left),Frame=CFrame.fromMatrix((a+b)/2,x,y,z),Color=color}end
 if right>.001 then pieces[#pieces+1]={Class='WedgePart',Size=Vector3.new(.016,h,right),Frame=CFrame.fromMatrix((a+c)/2,-x,y,-z),Color=color}end
end
local function rebuildColumn(row,x)
 local key=row.Id..':'..x;for _,p in ipairs(columnParts[key]or{})do p:Destroy()end;local list={};columnParts[key]=list
 local g=row.Grid;local lx=math.clamp(-g.X/2+x*g.DX,-g.X/2+.05,g.X/2-.05)
 local function state(z)
  Stats.ColumnCellVisits=(Stats.ColumnCellVisits or 0)+1
  local a=Core.id(row.Id,math.clamp(x,1,g.NX),z);local b=Core.id(row.Id,math.clamp(x+1,1,g.NX),z)
  if live[a]or live[b]then return'fine'end
  return(view.Held[a]or view.Held[b]or hullHeld[a]or hullHeld[b])and'down'or'rest'
 end
 local first,last=1,state(1)
 for z=2,g.NZ+1 do local nextState=z<=g.NZ and state(z)or'end'
  if nextState~=last then
   if last~='fine'then
    local z0=-g.Z/2+(first-1)*g.DZ+.05;local z1=-g.Z/2+(z-1)*g.DZ-.05
    for _,segment in ipairs(Scene.segments({lx,z0},{lx,z1},masks[row.Id],.055))do local length=segment[2][2]-segment[1][2]
     if length>.001 then local top=last=='down'and(Core.FillTop+.009)or(Core.RestTop+.034);list[#list+1]=rawPart('Part','KeyColumnInk',Vector3.new(.10,.018,length),row.Frame*CFrame.new(lx,top-.009,(segment[1][2]+segment[2][2])/2),Scene.ink(row.Stage))end
    end
   end
   first,last=z,nextState
  end
 end
 columnDirty[key]=nil
end
local function geometry()
 hullEpoch+=1;hullHeld={};for _,r in pairs(hullModels)do r.Keys={};r.Hash=nil end
 for _,list in pairs(columnParts)do for _,part in ipairs(list)do part:Destroy()end end;columnParts={};columnDirty={};
 for _,a in pairs(glyphAssignments)do a.Label.Parent=nil;labelPool[#labelPool+1]=a.Label end;glyphAssignments={};glyphCount=0;glyphWanted={};glyphPlan={};glyphPlanCursor=1;dirtyGlyphIds={};deferredDown={}
 for _,c in pairs(glyphChunks)do if c.Rest then c.Rest.Part:Destroy()end;if c.Down then c.Down.Part:Destroy()end end;glyphChunks={};sharedCanvases=0;chunkPixelCount=0
 unhide();for _,p in ipairs(static)do p:Destroy()end;static={};pieces={};staticCursor=1;staticReady=false
 for _,list in pairs(rowLive)do for _,part in ipairs(list)do part:Destroy()end end;rowLive={};rowDirty={};rowInk={}
 for _,e in pairs(rowCanvases)do e.Part:Destroy()end;rowCanvases={}
 byRow={};masks={}
 for _,row in ipairs(rows)do byRow[row.Id]=row;masks[row.Id]=Scene.masks(rows,row)end
 for _,row in ipairs(rows)do if row.Enabled~=false and row.Keyboard then
  local g=row.Grid
  for _,poly in ipairs(Scene.subtract(Scene.rectangle(-g.X/2,-g.Z/2,g.X/2,g.Z/2),masks[row.Id]))do
   if axis(poly)then local a,b,c,d=rectangle(poly);pieces[#pieces+1]={Class='Part',Size=Vector3.new(c-a,.016,d-b),Frame=row.Frame*CFrame.new((a+c)/2,Core.FillTop-.008,(b+d)/2),Color=Scene.fill(row.Stage),Fill=true}
   else for i=2,#poly-1 do local function v(q)return row.Frame:PointToWorldSpace(Vector3.new(q[1],Core.FillTop-.008,q[2]))end;local before=#pieces;trianglePlan(row,v(poly[1]),v(poly[i]),v(poly[i+1]),Scene.fill(row.Stage));for j=before+1,#pieces do pieces[j].Fill=true end end end
  end
 end end
 Stats.FillPlanned=#pieces
 for _,row in ipairs(rows)do if row.Enabled~=false and row.Keyboard then
  for z=1,row.Grid.NZ do dirtyRow(row,z,x)end
  for x=0,row.Grid.NX do markColumn(row,x)end
 end end
end
-- Support registry: one bootstrap enumeration, bounded coalesced changes, no spatial/global rescan loop.
local map=workspace:WaitForChild('ChestChaseMap');local initial=map:GetDescendants();local initialCursor=1
local registry,bins={},{};local explicit,explicitIndex,explicitFree={}, {},{};local explicitCursor=1
local query=OverlapParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={map};query.MaxParts=1024
local nextQuery=0
local function actor(p)
 local at=p.Parent
 while at and at~=map do
  if at.Name=='GuardianEncounters'or at:IsA('Model')and(at:GetAttribute('PersistentBiomeGuardian')or at:GetAttribute('GardenerArtVersion')or at:GetAttribute('VeiledKeeper81'))then return true end
  at=at.Parent
 end
 return false
end
local function remember(p)
 if not p:IsA('BasePart')or p.CanQuery~=false or explicitIndex[p]or actor(p)or p.Name:match('^Support_')then return end
 local e=Scene.extents(p);local at=center();local cam=workspace.CurrentCamera;local near=at and math.abs(p.Position.X-at.X)<=56+e.X and math.abs(p.Position.Z-at.Z)<=56+e.Z
 if cam then near=near or(math.abs(p.Position.X-cam.CFrame.X)<=384+e.X and math.abs(p.Position.Z-cam.CFrame.Z)<=384+e.Z)end
 local surface=rows and Scene.at(rows,p.Position);if not near and not(surface and surface.Keyboard)or e.X>80 or e.Z>80 then return end
 if #explicit>=4096 and #explicitFree==0 then return end
 local i=table.remove(explicitFree)or(#explicit+1);explicit[i]=p;explicitIndex[p]=i
end
local dirty,dirtySet={},{};local dirtyCursor=1;local revision=0
local function bin(x,z)return math.floor(x/16)..':'..math.floor(z/16)end
local function clearProp(p)
 local record=registry[p];if not record then return end
 for _,k in ipairs(record.Bins)do if bins[k]then bins[k][p]=nil end end
 for _,connection in ipairs(record.Connections)do connection:Disconnect();Stats.Listeners-=1 end
 registry[p]=nil;if record.Active then Stats.Registry-=1 end;Stats.Watched-=1;revision+=1
end
local function enqueue(p)
 if not p:IsA('BasePart')or not rows or not p:IsDescendantOf(map)or actor(p)or p.Name:match('^Support_')then if registry[p]then clearProp(p)end;Stats.AdmissionRejected=(Stats.AdmissionRejected or 0)+1;return end
 local at=center();local cam=workspace.CurrentCamera;local e=Scene.extents(p);local near=at and math.abs(p.Position.X-at.X)<=56+e.X and math.abs(p.Position.Z-at.Z)<=56+e.Z
 if cam then near=near or(math.abs(p.Position.X-cam.CFrame.X)<=384+e.X and math.abs(p.Position.Z-cam.CFrame.Z)<=384+e.Z)end
 if not near or e.X>80 or e.Z>80 then if p.Name:match('^BiomeGround_')then hideFloor(p)end;if registry[p]then clearProp(p)end;Stats.AdmissionRejected=(Stats.AdmissionRejected or 0)+1;return end
 if dirtySet[p]then return end
 if #dirty-dirtyCursor+1>=1024 then Stats.AdmissionOverflow=(Stats.AdmissionOverflow or 0)+1;nextQuery=0;if not Stats.LastQueueWarning or now-Stats.LastQueueWarning>=10 then Stats.LastQueueWarning=now;warn('[R146] Relevant support burst exceeded bounded admission; spatial/explicit recovery scheduled.')end;return end
 dirtySet[p]=true;dirty[#dirty+1]=p
end
local function updateProp(p)
 Stats.PropVisits+=1
 if not p:IsA('BasePart')then return end;hideFloor(p)
 if not rows or not p:IsDescendantOf(map)or p.Name:match('^Support_')or actor(p)then clearProp(p);return end
 local row=Scene.at(rows,p.Position);local e=Scene.extents(p);local lo,hi=p.Position-e,p.Position+e
 local r=registry[p]
 local eligible=row and row.Keyboard and e.X<=80 and e.Z<=80 and not p.Name:match('^BiomeGround_')and lo.Y<row.Frame.Position.Y+Core.RestTop and hi.Y>row.Frame.Position.Y+.01
 local at=center();local near=at and math.abs(p.Position.X-at.X)<=56+e.X and math.abs(p.Position.Z-at.Z)<=56+e.Z and e.X<=80 and e.Z<=80 and not p.Name:match('^BiomeGround_')
 local cam=workspace.CurrentCamera;if cam then near=near or(math.abs(p.Position.X-cam.CFrame.X)<=384+e.X and math.abs(p.Position.Z-cam.CFrame.Z)<=384+e.Z and e.X<=80 and e.Z<=80 and not p.Name:match('^BiomeGround_'))end
 if not near then clearProp(p);return end
 if not r then
  if Stats.Watched>=512 then
   local candidate,distance=nil,-1
   for other in pairs(registry)do local d=(Vector3.new(other.Position.X,at.Y,other.Position.Z)-at).Magnitude;if d>distance then candidate,distance=other,d end end
   if candidate and distance>(Vector3.new(p.Position.X,at.Y,p.Position.Z)-at).Magnitude then clearProp(candidate)else return end
  end
  r={Bins={},Connections={},Active=false};registry[p]=r;Stats.Watched+=1
  for _,property in ipairs({'CFrame','Size','Transparency'})do r.Connections[#r.Connections+1]=p:GetPropertyChangedSignal(property):Connect(function()enqueue(p)end);Stats.Listeners+=1 end
 end
 local on=eligible==true and p.Transparency<.98
 if r.Lo==lo and r.Hi==hi and r.Active==on then return end
 r.Lo,r.Hi=lo,hi
 for _,k in ipairs(r.Bins)do if bins[k]then bins[k][p]=nil end end;r.Bins={}
 if r.Active~=on then Stats.Registry+=on and 1 or -1 end;r.Active=on
 if on then
  r.Lo,r.Hi=lo,hi
  for x=math.floor((lo.X-2)/16),math.floor((hi.X+2)/16)do for z=math.floor((lo.Z-2)/16),math.floor((hi.Z+2)/16)do
   local k=x..':'..z;bins[k]=bins[k]or{};bins[k][p]=r;r.Bins[#r.Bins+1]=k
  end end
 end
 revision+=1
end
local function hullModel(p)
 local at=p:IsA('Model')and p or p.Parent
 while at and at~=map do
  if at:IsA('Model')and(at:GetAttribute('PersistentBiomeGuardian')or at:GetAttribute('VeiledKeeper81')or at:GetAttribute('GardenerArtVersion')or at:GetAttribute('GuardianBehavior'))then return at end
  at=at.Parent
 end
end
local function registerHull(p)
 if not p:IsA('BasePart')then return end;local model=hullModel(p);if not model or p==model.PrimaryPart or p:FindFirstAncestorOfClass('Accessory')then return end
 local record=hullModels[model]
 if not record then if hullModelCount>=32 then Stats.HullModelAdmissionMiss=(Stats.HullModelAdmissionMiss or 0)+1;return end;record={Model=model,Parts={},Count=0,Keys={},Hash=nil};hullModels[model]=record;hullModelCount+=1 end
 if record.Parts[p]then return end
 local priority=(p.Name:match('_01$')or p.Name=='Torso'or p.Name=='Body'or p.Name=='LFoot'or p.Name=='RFoot')and 0 or 1
 if record.Count>=64 then
  local replace;for other,v in pairs(record.Parts)do if v.Priority>priority then replace=other;break end end
  if not replace then Stats.HullPartAdmissionMiss=(Stats.HullPartAdmissionMiss or 0)+1;return end
  record.Parts[replace]=nil;hullPartOwners[replace]=nil;record.Count-=1
 end
 record.Parts[p]={Part=p,Priority=priority};hullPartOwners[p]=record;record.Count+=1;record.Hash=nil
end
local addedConnection=map.DescendantAdded:Connect(function(p)if p:IsA('BasePart')then registerHull(p);remember(p);enqueue(p)end end)
local removedConnection=map.DescendantRemoving:Connect(function(p)local owner=hullPartOwners[p];if owner then owner.Parts[p]=nil;owner.Count-=1;owner.Hash=nil;hullPartOwners[p]=nil end;clearProp(p);local i=explicitIndex[p];if i then explicit[i]=false;explicitIndex[p]=nil;explicitFree[#explicitFree+1]=i end;local value=oldLocal[p];if value~=nil and p.LocalTransparencyModifier==1 then p.LocalTransparencyModifier=value end;oldLocal[p]=nil end);Stats.Listeners=2
local function mask(e)
 Stats.MaskVisits+=1;local p=e.Base;local rx,rz=e.Size.X/2,e.Size.Z/2;local y=e.Row.Frame.Position.Y
 for _,r in pairs(bins[bin(p.X,p.Z)]or{})do
  if r.Lo.Y<y+Core.RestTop and r.Hi.Y>y+.01 and p.X+rx>r.Lo.X and p.X-rx<r.Hi.X and p.Z+rz>r.Lo.Z and p.Z-rz<r.Hi.Z then return true end
 end
 return false
end
local function touch(e)
 if pressure(e.Id,e)then e.Press=1;local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);local cf=e.Row.Frame*CFrame.new(lx,Core.DownTop-Core.Height/2,lz);if e.Part.CFrame~=cf then e.Part.CFrame=cf;Stats.CapWrites+=1 end end;if not active[e.Id]then activeQueue[#activeQueue+1]=e end;active[e.Id]=e;canvasDirty=true;dirtyGlyph(e.Id)
end
local function updateGlyph(e)
 local needed=predicted[e.Id]or(e.Press>0 and not pressure(e.Id,e))
 if e.Mask then clearGlyph(e);return end
 if not needed then clearGlyph(e);return end
 if not e.Glyph and glyphCarrierCount>=640 then
  if predicted[e.Id]then for _,other in pairs(glyphOwners)do if not predicted[other.Id]then clearGlyph(other);break end end end
  if glyphCarrierCount>=640 then e.Press=0;local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);e.Part.CFrame=e.Row.Frame*CFrame.new(lx,Core.RestTop-Core.Height/2,lz);Stats.CapWrites+=1;canvasDirty=true;return end
 end
 if not e.Glyph then e.Glyph=glyph(folder,Vector3.new(e.Size.X,e.Size.Z,.02),CFrame.new(),e.Part.Color,letter(e.X,e.Z),Vector2.new(32,32));glyphCarrierCount+=1;glyphOwners[e.Id]=e end
 local desired=e.Part.CFrame*CFrame.new(0,e.Size.Y/2+.11,0)*CFrame.Angles(math.pi/2,0,0);if e.Glyph.Part.CFrame~=desired then e.Glyph.Part.CFrame=desired end
end
local function createCap(row,x,z)
 local id=Core.id(row.Id,x,z);if live[id]then return live[id]end
 if count>=MAX_CAPS then for other,e in pairs(live)do if not pressure(other,e)and e.Press==0 then recycle(other,e);break end end;if count>=MAX_CAPS then return nil end end
 local lx,lz,w,d=Core.bounds(row.Grid,x,z);local part=table.remove(pool)or bare:Clone();part.Name=id;part.Size=Vector3.new(w,Core.Height,d);part.Color=Scene.palette(row.Stage,x,z);part.Parent=folder
 local e={Id=id,Row=row,X=x,Z=z,Base=point(row,x,z),Size=part.Size,Part=part,Press=0};e.Mask=mask(e);e.Press=pressure(id,e)and 1 or 0
 part.CFrame=row.Frame*CFrame.new(lx,(e.Press==1 and Core.DownTop or Core.RestTop)-Core.Height/2,lz);live[id]=e;count+=1;Stats.CapWrites+=1
 dirtyRow(row,z,x);markColumn(row,x-1);markColumn(row,x);if e.Press==1 then touch(e);updateGlyph(e)end;return e
end
local function projection(row,x,z,camera)
 local p=point(row,x,z)+Vector3.new(0,Core.RestTop,0);local v=camera.CFrame:PointToObjectSpace(p);local depth=-v.Z
 if depth<=.1 then return false end
 local vp=camera.ViewportSize;local focal=vp.Y/(2*math.tan(math.rad(camera.FieldOfView/2)));local width=row.Grid.DX*focal/depth
 local sx,sy=v.X*focal/depth,-v.Y*focal/depth
 return math.abs(sx)<=vp.X/2+12 and math.abs(sy)<=vp.Y/2+12 and width>=6*vp.Y/848,width
end
local function chunkKey(row,x,z)return row.Id..':'..math.floor((x-1)/8)..':'..math.floor((z-1)/8)end
local function makeChunkPlane(chunk,down)
 if sharedCanvases>=128 or(not down and sharedCanvases>=96)then return nil end
 local row,g=chunk.Row,chunk.Row.Grid;local width,depth=(chunk.X1-chunk.X0+1)*g.DX,(chunk.Z1-chunk.Z0+1)*g.DZ
 local lx=-g.X/2+(chunk.X0-1)*g.DX+width/2;local lz=-g.Z/2+(chunk.Z0-1)*g.DZ+depth/2
 local cf=row.Frame*CFrame.new(lx,(down and Core.DownTop or Core.RestTop)+.11,lz)*CFrame.Angles(math.pi/2,0,0)
 local carrier=rawPart('Part','LegendChunk',Vector3.new(width,depth,.02),cf,Scene.fill(row.Stage));carrier.Transparency=1
 local gui=Instance.new('SurfaceGui');gui.Name='CellLegends';gui.Face=Enum.NormalId.Front;gui.Adornee=carrier;gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.Brightness=1;gui.MaxDistance=1200;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=Vector2.new((chunk.X1-chunk.X0+1)*16,(chunk.Z1-chunk.Z0+1)*16);gui.Parent=carrier
 local plane={Part=carrier,Gui=gui,Pixels=gui.CanvasSize.X*gui.CanvasSize.Y,Users=0};sharedCanvases+=1;chunkPixelCount+=plane.Pixels;return plane
end
local function releaseSlot(id)
 local a=glyphAssignments[id];deferredDown[id]=nil;if not a then return end;a.Plane.Users-=1;a.Label.Parent=nil;labelPool[#labelPool+1]=a.Label;a.Chunk.Count-=1;glyphAssignments[id]=nil;glyphCount-=1
end
local function trimChunks()
 for key,c in pairs(glyphChunks)do if c.Down and c.Down.Users==0 then c.Down.Part:Destroy();sharedCanvases-=1;chunkPixelCount-=c.Down.Pixels;c.Down=nil end;if c.Count==0 then for _,p in ipairs({c.Rest,c.Down})do if p then p.Part:Destroy();sharedCanvases-=1;chunkPixelCount-=p.Pixels end end;glyphChunks[key]=nil end end
end
local function assignSlot(id,e)
 if glyphAssignments[id]then return glyphAssignments[id]end
 if glyphCount>=4096 then return nil end
 local key=chunkKey(e.Row,e.X,e.Z);local c=glyphChunks[key]
 if not c then local g=e.Row.Grid;local x0=math.floor((e.X-1)/8)*8+1;local z0=math.floor((e.Z-1)/8)*8+1;c={Row=e.Row,X0=x0,X1=math.min(x0+7,g.NX),Z0=z0,Z1=math.min(z0+7,g.NZ),Count=0};c.Rest=makeChunkPlane(c,false);if not c.Rest then return nil end;glyphChunks[key]=c end
 local label=table.remove(labelPool)
 if not label then if labelsAllocated>=4096 then return nil end;label=Instance.new('TextLabel');labelsAllocated+=1 end
 label.Name='CellLetter';label.BackgroundTransparency=1;label.BorderSizePixel=0;label.TextWrapped=false;label.RichText=false;label.TextScaled=false;label.Font=Enum.Font.GothamBold;label.TextSize=14;label.TextXAlignment=Enum.TextXAlignment.Center;label.TextYAlignment=Enum.TextYAlignment.Center;label.TextStrokeTransparency=1
 label.Size=UDim2.new(0,16,0,16);label.Position=UDim2.new(0,(e.X-c.X0)*16,0,(c.Z1-e.Z)*16);label.Text=letter(e.X,e.Z);label.TextColor3=textInk(e.Part.Color);label.TextTransparency=0;label.Parent=c.Rest.Gui
 local a={Label=label,Chunk=c,Plane=c.Rest};c.Rest.Users+=1;glyphAssignments[id]=a;c.Count+=1;glyphCount+=1;return a
end
local function updateSlot(id)
 Stats.GlyphSlotVisits=(Stats.GlyphSlotVisits or 0)+1;local e=live[id]
 if not e or not glyphWanted[id]then releaseSlot(id);return end
 local a=glyphAssignments[id]or assignSlot(id,e);if not a then return end
 if e.Mask or e.Glyph or e.Press>0 and e.Press<1 then a.Label.TextTransparency=1;return end
 local down=pressure(id,e);local c=a.Chunk
 if down and not c.Down then c.Down=makeChunkPlane(c,true)end
 local plane;if down then plane=c.Down else plane=c.Rest end
 if not plane then a.Label.TextTransparency=1;deferredDown[id]=true;return end;deferredDown[id]=nil
 if a.Plane~=plane then a.Plane.Users-=1;plane.Users+=1;a.Plane=plane;a.Label.Parent=plane.Gui;Stats.GlyphParentWrites=(Stats.GlyphParentWrites or 0)+1 end
 a.Label.TextTransparency=0;Stats.GlyphSlotWrites=(Stats.GlyphSlotWrites or 0)+1
end
local function refreshCanvases()
 -- Dirty IDs only. Camera plans build the resident label set separately.
 if sharedCanvases<128 then local retries=0;for id in pairs(deferredDown)do if retries>=64 then break end;dirtyGlyphIds[id]=true;retries+=1 end end
 local work=0;for id in pairs(dirtyGlyphIds)do if work>=128 then break end;dirtyGlyphIds[id]=nil;updateSlot(id);work+=1 end
 local built=0;while glyphPlanCursor<=#glyphPlan and built<64 do local e=glyphPlan[glyphPlanCursor];glyphPlanCursor+=1;if live[e.Id]and glyphWanted[e.Id]then updateSlot(e.Id);built+=1 end end
 trimChunks();Stats.SharedCanvases=sharedCanvases;Stats.BaseCanvasPixels=chunkPixelCount+glyphCarrierCount*1024;Stats.LabelsAllocated=labelsAllocated;Stats.GlyphSlots=glyphCount
end
local function glyphProjection(row,x,z,camera)
 local g=row.Grid;local p=point(row,x,z)+row.Frame.UpVector*(Core.RestTop+.12);local v=camera.CFrame:PointToObjectSpace(p);if -v.Z<=.1 then return false end
 local focal=camera.ViewportSize.Y/(2*math.tan(math.rad(camera.FieldOfView/2)))
 local function screen(q)local d=-q.Z;if d<=.1 then return nil end;return Vector2.new(q.X*focal/d,-q.Y*focal/d)end
 local u=camera.CFrame:VectorToObjectSpace(row.Frame.RightVector*g.DX/2);local w=camera.CFrame:VectorToObjectSpace(-row.Frame.LookVector*g.DZ/2)
 local a,b,c,d=screen(v-u),screen(v+u),screen(v-w),screen(v+w);if not a or not b or not c or not d then return false end
 local dx,dy=b.X-a.X,b.Y-a.Y;local zx,zy=d.X-c.X,d.Y-c.Y
 return math.sqrt(dx*dx+dy*dy)*.65>=6 and math.sqrt(zx*zx+zy*zy)*.875>=8
end
local function plan(at)
 local camera=workspace.CurrentCamera;if not camera then return end;Stats.Plans+=1;local desired={};local nextGlyphs={};pending={};cursor=1;glyphPlan={};glyphPlanCursor=1
 local buckets={};local focal=camera.ViewportSize.Y/(2*math.tan(math.rad(camera.FieldOfView/2)));local range=Core.Pitch*focal/(6*camera.ViewportSize.Y/848)+32
 for _,row in ipairs(rows)do if row.Keyboard and row.Enabled~=false then
  local g=row.Grid;local c=row.Frame:PointToObjectSpace(camera.CFrame.Position);local a=math.clamp(math.floor((c.X-range+g.X/2)/g.DX)+1,1,g.NX);local b=math.clamp(math.ceil((c.X+range+g.X/2)/g.DX),1,g.NX);local q=math.clamp(math.floor((c.Z-range+g.Z/2)/g.DZ)+1,1,g.NZ);local r=math.clamp(math.ceil((c.Z+range+g.Z/2)/g.DZ),1,g.NZ)
  for z=q,r do for x=a,b do Stats.CellVisits+=1;local visible=projection(row,x,z,camera)
   if visible and(#masks[row.Id]==0 or Scene.insideCell(row,x,z,masks[row.Id]))then local id=Core.id(row.Id,x,z);desired[id]=true;nextGlyphs[id]=glyphProjection(row,x,z,camera);local distance=(point(row,x,z)-camera.CFrame.Position).Magnitude;local bucket=math.floor(distance/16);buckets[bucket]=buckets[bucket]or{};buckets[bucket][#buckets[bucket]+1]={Id=id,Row=row,X=x,Z=z}end
  end end
 end end
 for id in pairs(predicted)do desired[id]=true end
 for id in pairs(view.Held)do local row,x,z=decode(id);if row and(point(row,x,z)-at).Magnitude<160 then desired[id]=true end end
 for id,e in pairs(live)do if not desired[id]and not pressure(id,e)and e.Press==0 then recycle(id,e)end end
 for bucket=0,math.ceil(range/16)+1 do for _,e in ipairs(buckets[bucket]or{})do if not live[e.Id]then pending[#pending+1]=e end;if nextGlyphs[e.Id]then glyphPlan[#glyphPlan+1]=e end end end
 glyphWanted=nextGlyphs;for id in pairs(glyphAssignments)do if not glyphWanted[id]then releaseSlot(id)end end;trimChunks()
 Stats.PlannedCaps=0;for _ in pairs(desired)do Stats.PlannedCaps+=1 end
 lastCamera=camera.CFrame;lastViewport=camera.ViewportSize;lastFov=camera.FieldOfView;lastAt=at;nextPlan=now+.2
end
local function predict()
 local player=Players.LocalPlayer;local character=player.Character;local hum=character and character:FindFirstChildOfClass('Humanoid');local root=character and character:FindFirstChild('HumanoidRootPart');local nextSet={}
 if hum and hum.Health>0 and root then
  local height=hum.HipHeight+root.Size.Y/2;if hum.RigType==Enum.HumanoidRigType.R6 then local leg=character:FindFirstChild('Left Leg');height+=(leg and leg.Size.Y or 2)end
  local p=root.Position-Vector3.new(0,height,0);Scene.contact(rows,p,math.clamp(root.Size.X/2+.9,1.5,3),1.9,nextSet)
  for _,name in ipairs({'LeftFoot','RightFoot','Left Leg','Right Leg'})do local foot=character:FindFirstChild(name);if foot and foot:IsA('BasePart')then local at=foot.CFrame:PointToWorldSpace(Vector3.new(0,-foot.Size.Y/2,0));if math.abs(at.Y-p.Y)<.8 then Scene.contact(rows,at,foot.Size.X/2+.25,foot.Size.Z/2+.25,nextSet)end end end
 end
 for id in pairs(nextSet)do if not predicted[id]and not view.Held[id]then click(id);clicked[id]=now end end
 local old=predicted;predicted=nextSet
 for id in pairs(nextSet)do if not old[id]or not live[id]then local row,x,z=decode(id);if row then local e=live[id]or createCap(row,x,z);if e then touch(e);updateGlyph(e);dirtyRow(row,z,x)end end end end
 for id in pairs(old)do if not nextSet[id]and live[id]then touch(live[id]);dirtyRow(live[id].Row,live[id].Z,live[id].X)end end
 for id,time in pairs(clicked)do if now-time>2 then clicked[id]=nil end end
end
local priorityHull={};local priorityHullCursor=1;local camps=map:FindFirstChild('GuardianEncounters')
if camps then local models=0;for _,model in ipairs(camps:GetChildren())do if models>=32 then break end;if model:IsA('Model')then models+=1;local visited=0;for _,part in ipairs(model:GetChildren())do if visited>=2048 then break end;visited+=1;if part:IsA('BasePart')and(part.Name:match('_01$')or part.Name=='Body'or part.Name=='Torso'or part.Name=='LFoot'or part.Name=='RFoot')and #priorityHull<256 then priorityHull[#priorityHull+1]=part end end end end end
local function setHullKeys(record,nextKeys)
 local changed={};for id in pairs(record.Keys)do if not nextKeys[id]then hullHeld[id]=(hullHeld[id]or 1)-1;if hullHeld[id]<=0 then hullHeld[id]=nil end;changed[id]=true end end
 for id in pairs(nextKeys)do if not record.Keys[id]then hullHeld[id]=(hullHeld[id]or 0)+1;changed[id]=true end end;record.Keys=nextKeys
 for id in pairs(changed)do local e=live[id];if e then touch(e);dirtyRow(e.Row,e.Z,e.X)else local row,x,z=decode(id);if row then dirtyRow(row,z,x)end end end
end
local function hullStep()
 local at=center();local cam=workspace.CurrentCamera;local checks,boxes,changedKeys,candidateVisits=0,0,0,0
 for model,record in pairs(hullModels)do
  if not model.Parent or not model:IsDescendantOf(map)then setHullKeys(record,{});for part in pairs(record.Parts)do hullPartOwners[part]=nil end;hullModels[model]=nil;hullModelCount-=1
  else
   local root=model.PrimaryPart;local near=root and at and math.abs(root.Position.X-at.X)<96 and math.abs(root.Position.Z-at.Z)<96
   if root and cam then near=near or(math.abs(root.Position.X-cam.CFrame.X)<384 and math.abs(root.Position.Z-cam.CFrame.Z)<384)end
   local rects={}
   if near then for part,r in pairs(record.Parts)do
    checks+=1
    if not part.Parent or not part:IsDescendantOf(model)then record.Parts[part]=nil;record.Count-=1;hullPartOwners[part]=nil;record.Hash=nil
    else
     if r.Frame~=part.CFrame or r.Size~=part.Size or r.Transparency~=part.Transparency or r.Primary~=model.PrimaryPart or r.Epoch~=hullEpoch then
      r.Frame,r.Size,r.Transparency,r.Primary,r.Epoch=part.CFrame,part.Size,part.Transparency,model.PrimaryPart,hullEpoch;r.Row=nil;boxes+=1
      if part~=model.PrimaryPart and part.Transparency<.98 then local row=Scene.at(rows,part.Position);local ext=Scene.extents(part);local lo,hi=part.Position-ext,part.Position+ext
       if row and row.Keyboard and ext.X<=80 and ext.Z<=80 and lo.Y<row.Frame.Y+Core.RestTop+.12 and hi.Y>row.Frame.Y+.01 then r.Row=row;r.Lo=lo;r.Hi=hi end
      end
     end
     if r.Row then rects[#rects+1]={Row=r.Row,Lo=r.Lo,Hi=r.Hi,Priority=r.Priority}end
    end
   end end
   local signature={};local ranges={}
   for _,b in ipairs(rects)do local row,g=b.Row,b.Row.Grid;local c=row.Frame:PointToObjectSpace((b.Lo+b.Hi)/2);local h=(b.Hi-b.Lo)/2;local right,forward=row.Frame.RightVector,row.Frame.LookVector;local rx=math.abs(right.X)*h.X+math.abs(right.Z)*h.Z+.1;local rz=math.abs(forward.X)*h.X+math.abs(forward.Z)*h.Z+.1
    if c.X+rx>=-g.X/2 and c.X-rx<=g.X/2 and c.Z+rz>=-g.Z/2 and c.Z-rz<=g.Z/2 then
     local x0=math.clamp(math.floor((c.X-rx+g.X/2)/g.DX)+1,1,g.NX);local x1=math.clamp(math.floor((c.X+rx+g.X/2)/g.DX)+1,1,g.NX);local z0=math.clamp(math.floor((c.Z-rz+g.Z/2)/g.DZ)+1,1,g.NZ);local z1=math.clamp(math.floor((c.Z+rz+g.Z/2)/g.DZ)+1,1,g.NZ)
     signature[#signature+1]=row.Id..':'..x0..':'..x1..':'..z0..':'..z1;local focus=row.Frame:PointToObjectSpace(root.Position);local cx=math.clamp(math.floor((focus.X+g.X/2)/g.DX)+1,x0,x1);local cz=math.clamp(math.floor((focus.Z+g.Z/2)/g.DZ)+1,z0,z1);ranges[#ranges+1]={Row=row,X0=x0,X1=x1,Z0=z0,Z1=z1,CX=cx,CZ=cz,Priority=b.Priority,Distance=(b.Lo+b.Hi-root.Position*2).Magnitude}
    end
   end
   table.sort(signature);local hash=hullEpoch..'|'..table.concat(signature,'|')
   if record.Hash~=hash then
    record.Hash=hash;local nextKeys={};local n=0;local visits=0
    table.sort(ranges,function(a,b)if a.Priority~=b.Priority then return a.Priority<b.Priority end;return a.Distance<b.Distance end)
    -- Each body piece contributes its own footprint. Start at its root-nearest cell;
    -- sparse pieces never turn the empty space between them into one giant hull.
    for _,range in ipairs(ranges)do if visits>=1024 then break end
     local function ordered(lo,hi,c)
      local first,turn=true,true;local left,right=c-1,c+1
      return function()if first then first=false;return c end;if left>=lo and(turn or right>hi)then local v=left;left-=1;turn=false;return v end;if right<=hi then local v=right;right+=1;turn=true;return v end end
     end
     for z in ordered(range.Z0,range.Z1,range.CZ)do if visits>=1024 then break end
      for x in ordered(range.X0,range.X1,range.CX)do if visits>=1024 then break end;visits+=1;candidateVisits+=1
       if Scene.at(rows,point(range.Row,x,z))==range.Row then local id=Core.id(range.Row.Id,x,z);if not nextKeys[id]then nextKeys[id]=true;n+=1 end end
      end
     end
    end;changedKeys+=n;setHullKeys(record,nextKeys)
   end
  end
 end
 Stats.HullPartChecks=(Stats.HullPartChecks or 0)+checks;Stats.HullBoundsBuilds=(Stats.HullBoundsBuilds or 0)+boxes;Stats.HullKeyBuilds=(Stats.HullKeyBuilds or 0)+changedKeys;Stats.HullCandidateVisits=(Stats.HullCandidateVisits or 0)+candidateVisits;Stats.HullCandidateVisitsFrame=candidateVisits;Stats.HullChecksFrame=checks;Stats.HullModels=hullModelCount
end
local remoteConnection=remote.OnClientEvent:Connect(function(kind,seq,entries,descriptions)
 if not Core.packet(view,kind,seq,entries)then return end
 if kind=='Snapshot'then rows=descriptions;for id,e in pairs(live)do recycle(id,e)end;geometry();pending={};cursor=1;lastAt=nil;lastCamera=nil;nextPlan=0
 else for _,change in ipairs(entries)do local row,x,z=decode(change[1]);if row then dirtyRow(row,z,x)end;local e=live[change[1]];if not e and change[2]then local row,x,z=decode(change[1]);local at=center();local camera=workspace.CurrentCamera;if row and at and((point(row,x,z)-at).Magnitude<160 or(camera and projection(row,x,z,camera)))then urgent[change[1]]={Row=row,X=x,Z=z}end end;if e then touch(e)end
  if change[2]then local suppress=predicted[change[1]]or clicked[change[1]];clicked[change[1]]=nil;if not suppress then click(change[1])end else clicked[change[1]]=nil end
 end end
end)
remote:FireServer('Ready')
ADVANCE=16
local lastRevision=-1;local maskList={};local maskCursor=1
local renderConnection=Run.RenderStepped:Connect(function(dt)
 now=os.clock();FrameNo+=1;local at=center();if not at then return end
 if not rows then if now>=nextPlan then nextPlan=now+2;remote:FireServer('Ready')end;return end
 local priority=0;while priorityHullCursor<=#priorityHull and priority<64 do registerHull(priorityHull[priorityHullCursor]);priorityHullCursor+=1;priority+=1 end
 hullStep()
 predict() -- Current contact geometry/press/click precede all background queues.
 local priorityBuilt=0;for id,e in pairs(urgent)do if priorityBuilt>=64 then break end;urgent[id]=nil;if view.Held[id]then createCap(e.Row,e.X,e.Z);priorityBuilt+=1;canvasDirty=true end end;Stats.PriorityBuilt=priorityBuilt
 local built=0
 while staticCursor<=#pieces and built<48 do local p=pieces[staticCursor];staticCursor+=1;static[#static+1]=rawPart(p.Class,'TrackGrid',p.Size,p.Frame,p.Color);built+=1
  if not staticReady and staticCursor>Stats.FillPlanned then staticReady=true;for _,p in ipairs(initial)do hideFloor(p)end end
 end
 local cam=workspace.CurrentCamera;local cameraChanged=cam and(not lastCamera or cam.ViewportSize~=lastViewport or cam.FieldOfView~=lastFov or(cam.CFrame.Position-lastCamera.Position).Magnitude>2 or cam.CFrame.LookVector:Dot(lastCamera.LookVector)<.999)
 if now>=nextPlan and(not lastAt or(at-lastAt).Magnitude>2 or cameraChanged)then plan(at);canvasDirty=true end
 local created=0
 while cursor<=#pending and created<256 and count<MAX_CAPS do local e=pending[cursor];cursor+=1;createCap(e.Row,e.X,e.Z);created+=1;canvasDirty=true end
 if now>=nextQuery then nextQuery=now+.5;local surface=Scene.at(rows,at);local floorY=surface and surface.Frame.Y or 4
  local found=workspace:GetPartBoundsInBox(CFrame.new(at.X,floorY+.7,at.Z),Vector3.new(112,6,112),query);Stats.Queries=(Stats.Queries or 0)+1;Stats.QueryParts=(Stats.QueryParts or 0)+#found;for _,p in ipairs(found)do enqueue(p)end
  if cam and(Vector3.new(cam.CFrame.X,at.Y,cam.CFrame.Z)-at).Magnitude>56 then local cp=cam.CFrame.Position;local foundCamera=workspace:GetPartBoundsInBox(CFrame.new(cp.X,floorY+.7,cp.Z),Vector3.new(768,6,768),query);Stats.Queries+=1;Stats.QueryParts+=#foundCamera;for _,p in ipairs(foundCamera)do enqueue(p)end end
 end
 local scanned=0;while scanned<16 and #explicit>0 do if explicitCursor>#explicit then explicitCursor=1 end;local p=explicit[explicitCursor];explicitCursor+=1;scanned+=1;if p and p.Parent then enqueue(p)end end
 local work=0;while initialCursor<=#initial and work<64 do registerHull(initial[initialCursor]);remember(initial[initialCursor]);enqueue(initial[initialCursor]);initialCursor+=1;work+=1 end
 work=0;while dirtyCursor<=#dirty and work<64 do local p=dirty[dirtyCursor];dirtyCursor+=1;dirtySet[p]=nil;updateProp(p);work+=1;Stats.DirtyVisits+=1 end
 if dirtyCursor>#dirty then dirty={};dirtyCursor=1 elseif dirtyCursor>256 then dirty=table.move(dirty,dirtyCursor,#dirty,1,{});dirtyCursor=1 end
 Stats.DirtyPending=#dirty-dirtyCursor+1;Stats.DirtySlots=#dirty
 if lastRevision~=revision and maskCursor>#maskList then maskList={};for _,e in pairs(live)do maskList[#maskList+1]=e end;maskCursor=1;lastRevision=revision end
 work=0;while maskCursor<=#maskList and work<64 do local e=maskList[maskCursor];maskCursor+=1;if live[e.Id]==e then local value=mask(e);if value~=e.Mask then e.Mask=value;touch(e);dirtyRow(e.Row,e.Z,e.X);canvasDirty=true end end;work+=1 end
 local animations=0
 local queueEnd=#activeQueue
 while activeCursor<=queueEnd and animations<MAX_ACTIVE do local e=activeQueue[activeCursor];activeCursor+=1;local id=e.Id;if active[id]==e then animations+=1;Stats.Animations+=1;local previous=e.Press;local down=pressure(id,e)
  e.Press=down and 1 or Core.animate(e.Press,false,dt)
  if e.Press~=previous then local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);e.Part.CFrame=e.Row.Frame*CFrame.new(lx,(Core.RestTop*(1-e.Press)+Core.DownTop*e.Press)-Core.Height/2,lz);Stats.CapWrites+=1;canvasDirty=true;dirtyGlyph(e.Id)end
  -- Immediate press was applied by touch; ensure transform reconciles that target in the same frame.
  if down then local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);local desired=e.Row.Frame*CFrame.new(lx,Core.DownTop-Core.Height/2,lz);if e.Part.CFrame~=desired then e.Part.CFrame=desired;Stats.CapWrites+=1;canvasDirty=true;dirtyGlyph(e.Id)end end
  updateGlyph(e);if e.Press==(down and 1 or 0)then active[id]=nil else activeQueue[#activeQueue+1]=e end
 end end
 if activeCursor>256 then activeQueue=table.move(activeQueue,activeCursor,#activeQueue,1,{});activeCursor=1 end
 local columnsBuilt=0;for _,e in pairs(columnDirty)do if columnsBuilt>=8 then break end;rebuildColumn(e.Row,e.X);columnsBuilt+=1 end
 local changed=0
 for key,e in pairs(rowDirty)do if changed>=96 then break end;rebuildRow(e.Row,e.Z);changed+=1 end
 -- Newly created fine meshes may never share a background face. Hide pending dirty rows until split commit.
 for key in pairs(rowDirty)do for _,part in ipairs(rowLive[key]or{})do part.Parent=nil end end
 refreshCanvases();canvasDirty=false
 while #pool+count>MAX_CAPS do table.remove(pool):Destroy()end
 Stats.Caps=count;Stats.Pool=#pool;Stats.StaticParts=#static;Stats.ActiveVisited=animations;Stats.GlyphCarriers=glyphCarrierCount
end)
local function cleanup()
 renderConnection:Disconnect();remoteConnection:Disconnect();addedConnection:Disconnect();removedConnection:Disconnect();unhide();for p in pairs(registry)do clearProp(p)end
 for _,part in ipairs(pool)do part:Destroy()end;for _,label in ipairs(labelPool)do label:Destroy()end;bare:Destroy();folder:Destroy()
 for _,list in pairs(rowLive)do for _,part in ipairs(list)do if not part.Parent then part:Destroy()end end end;for _,list in pairs(columnParts)do for _,part in ipairs(list)do if not part.Parent then part:Destroy()end end end
end
local function diagnose()
 local camera=workspace.CurrentCamera;local sample;for _,entry in pairs(glyphAssignments)do sample=entry;break end
 local out={Revision=146,Caps=count,SharedCanvases=sharedCanvases,BaseCanvasPixels=chunkPixelCount+glyphCarrierCount*1024,GlyphSlots=glyphCount,LabelsAllocated=labelsAllocated,GlyphCarriers=Stats.GlyphCarriers,DirtyPending=Stats.DirtyPending,AdmissionRejected=Stats.AdmissionRejected,AdmissionOverflow=Stats.AdmissionOverflow,FontAdvance=ADVANCE,CameraViewport=camera and camera.ViewportSize}
 if sample then out.TextBounds=sample.Label.TextBounds;out.AbsoluteSize=sample.Label.AbsoluteSize;out.FontSize=14;out.Face='Front';out.CarrierClearance=.12 end
 print('[R146 diagnostic]',out);return out
end
return{Folder=folder,Stats=Stats,Cleanup=cleanup,Diagnose=diagnose}
