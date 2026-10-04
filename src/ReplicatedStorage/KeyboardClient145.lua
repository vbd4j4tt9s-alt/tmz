-- Continuous fixed-pitch track grid; bounded local extrusion/legends; authoritative actor pressure.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService');local Content=game:GetService('ContentProvider');local Text=game:GetService('TextService')
local Core=require(RS:WaitForChild('KeyboardCore143'));local Scene=require(RS:WaitForChild('KeyboardScene143'))
local remote=RS:WaitForChild('Keyboard143State');local template=RS:WaitForChild('R142Keycap')
local bare=template:Clone();bare.Parent=nil;for _,child in ipairs(bare:GetChildren())do child:Destroy()end
local folder=Instance.new('Folder');folder.Name='R145KeyboardVisuals';folder.Parent=workspace
local rows,view=nil,{Sequence=-1,Held={}};local byRow,masks={},{ }
local live,pool,active={}, {},{};local pending={};local cursor=1;local count=0
local static,pieces,staticCursor={}, {},1;local staticReady=false;local oldLocal={}
local lastAt,nextPlan=nil,0;local lastCamera=nil;local lastViewport=nil;local lastFov=nil;local predicted,clicked={},{};local rowLive,rowDirty,rowInk={}, {},{};local rowCanvases={};local activeCount=0;local MAX_CAPS=8192;local MAX_ACTIVE=640;local MAX_ROWS=384;local ADVANCE=nil;local FrameNo=0;local canvasDirty=true;local glyphCarrierCount=0;local glyphOwners={};local activeQueue={};local activeCursor=1;local urgent={};local haloDirty=false;local now=0;local legendCount=0
local Stats={Caps=0,CapWrites=0,StaticParts=0,Legends=0,Plans=0,CellVisits=0,PropVisits=0,Registry=0,Watched=0,Listeners=0,DirtyVisits=0,MaskVisits=0,Animations=0}
local function rawPart(class,name,size,cf,color)
 local p=Instance.new(class);p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=Enum.Material.SmoothPlastic
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
 if not okay or not audioReady then warn('[R145] Supplied key click could not load; check experience permissions: '..tostring(why))end
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
local function pressure(id,e)return predicted[id]or view.Held[id]or(e and e.Mask)or false end
local function cell(id)local row,x,z=decode(id);if row then return row,x,z end end
local function rowKey(row,z)return row.Id..':'..z end
local function dirtyRow(row,z)rowDirty[rowKey(row,z)]={Row=row,Z=z}end
local function letter(x,z)local alphabet='QWERTYUIOPASDFGHJKLZXCVBNM';local n=(x*7+z*11)%#alphabet+1;return alphabet:sub(n,n)end
local function textInk(color)local dark=color.R*.2126+color.G*.7152+color.B*.0722<.38;return dark and Color3.fromRGB(245,242,232)or Color3.fromRGB(30,25,34)end
local function glyph(parent,size,cf,color,text,canvas)
 local carrier=rawPart('Part','LegendCarrier',size,cf,color);carrier.Transparency=1;carrier.Parent=parent
 local gui=Instance.new('SurfaceGui');gui.Name='KeyLegend';gui.Adornee=carrier;gui.Face=Enum.NormalId.Top;gui.AlwaysOnTop=false;gui.Enabled=true;gui.LightInfluence=0;gui.Brightness=1;gui.MaxDistance=1200;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=canvas;gui.Parent=carrier
 local label=Instance.new('TextLabel');label.Name='Letter';label.BackgroundTransparency=1;label.BorderSizePixel=0;label.Size=UDim2.fromScale(1,1);label.Position=UDim2.fromScale(0,0)
 label.Font=Enum.Font.Code;label.TextSize=16;label.TextScaled=false;label.TextWrapped=false;label.RichText=false;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Center
 label.Text=text;label.TextColor3=textInk(color);label.TextStrokeColor3=label.TextColor3.R>.5 and Color3.fromRGB(30,25,34)or Color3.fromRGB(245,242,232);label.TextStrokeTransparency=.35;label.TextTransparency=0;label.Parent=gui
 return{Part=carrier,Gui=gui,Label=label}
end
local function clearGlyph(e)if e.Glyph then e.Glyph.Part:Destroy();e.Glyph=nil;glyphOwners[e.Id]=nil;glyphCarrierCount-=1 end end
local function recycle(id,e)
 live[id]=nil;active[id]=nil;clearGlyph(e);e.Part.Parent=nil;pool[#pool+1]=e.Part;count-=1;dirtyRow(e.Row,e.Z)
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
 local function state(x)local id=Core.id(row.Id,x,z);if live[id]then return'fine'end;return view.Held[id]and'down'or'rest'end
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
local function geometry()
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
  for z=1,row.Grid.NZ do dirtyRow(row,z)end
  for x=0,row.Grid.NX do local lx=math.clamp(-row.Grid.X/2+x*row.Grid.DX,-row.Grid.X/2+.05,row.Grid.X/2-.05)
   for _,s in ipairs(Scene.segments({lx,-row.Grid.Z/2+.05},{lx,row.Grid.Z/2-.05},masks[row.Id],.055))do
    local length=s[2][2]-s[1][2];if length>.001 then pieces[#pieces+1]={Class='Part',Size=Vector3.new(.10,.018,length),Frame=row.Frame*CFrame.new(lx,Core.RestTop+.025,(s[1][2]+s[2][2])/2),Color=Scene.ink(row.Stage)}end
   end
  end
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
 if #dirty-dirtyCursor+1>=1024 then Stats.AdmissionOverflow=(Stats.AdmissionOverflow or 0)+1;nextQuery=0;if not Stats.LastQueueWarning or now-Stats.LastQueueWarning>=10 then Stats.LastQueueWarning=now;warn('[R145] Relevant support burst exceeded bounded admission; spatial/explicit recovery scheduled.')end;return end
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
local addedConnection=map.DescendantAdded:Connect(function(p)if p:IsA('BasePart')then remember(p);enqueue(p)end end)
local removedConnection=map.DescendantRemoving:Connect(function(p)clearProp(p);local i=explicitIndex[p];if i then explicit[i]=false;explicitIndex[p]=nil;explicitFree[#explicitFree+1]=i end;local value=oldLocal[p];if value~=nil and p.LocalTransparencyModifier==1 then p.LocalTransparencyModifier=value end;oldLocal[p]=nil end);Stats.Listeners=2
local function mask(e)
 Stats.MaskVisits+=1;local p=e.Base;local rx,rz=e.Size.X/2,e.Size.Z/2;local y=e.Row.Frame.Position.Y
 for _,r in pairs(bins[bin(p.X,p.Z)]or{})do
  if r.Lo.Y<y+Core.RestTop and r.Hi.Y>y+.01 and p.X+rx>r.Lo.X and p.X-rx<r.Hi.X and p.Z+rz>r.Lo.Z and p.Z-rz<r.Hi.Z then return true end
 end
 return false
end
local function touch(e)
 if pressure(e.Id,e)then e.Press=1;local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);local cf=e.Row.Frame*CFrame.new(lx,Core.DownTop-Core.Height/2,lz);if e.Part.CFrame~=cf then e.Part.CFrame=cf;Stats.CapWrites+=1 end end;if not active[e.Id]then activeQueue[#activeQueue+1]=e end;active[e.Id]=e;canvasDirty=true
end
local function updateGlyph(e)
 local needed=predicted[e.Id]or(e.Press>0 and not pressure(e.Id,e))
 if e.Mask then clearGlyph(e);return end
 if not needed then clearGlyph(e);return end
 if not e.Glyph and glyphCarrierCount>=640 then
  if predicted[e.Id]then for _,other in pairs(glyphOwners)do if not predicted[other.Id]then clearGlyph(other);break end end end
  if glyphCarrierCount>=640 then e.Press=0;local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);e.Part.CFrame=e.Row.Frame*CFrame.new(lx,Core.RestTop-Core.Height/2,lz);Stats.CapWrites+=1;canvasDirty=true;return end
 end
 if not e.Glyph then e.Glyph=glyph(folder,Vector3.new(e.Size.X,.02,e.Size.Z),CFrame.new(),e.Part.Color,' '..letter(e.X,e.Z)..' ',Vector2.new(3*ADVANCE,24));glyphCarrierCount+=1;glyphOwners[e.Id]=e end
 local desired=e.Part.CFrame*CFrame.new(0,e.Size.Y/2+.11,0);if e.Glyph.Part.CFrame~=desired then e.Glyph.Part.CFrame=desired end
end
local function createCap(row,x,z)
 local id=Core.id(row.Id,x,z);if live[id]then return live[id]end
 if count>=MAX_CAPS then for other,e in pairs(live)do if not pressure(other,e)and e.Press==0 then recycle(other,e);break end end;if count>=MAX_CAPS then return nil end end
 local lx,lz,w,d=Core.bounds(row.Grid,x,z);local part=table.remove(pool)or bare:Clone();part.Name=id;part.Size=Vector3.new(w,Core.Height,d);part.Color=Scene.palette(row.Stage,x,z);part.Parent=folder
 local e={Id=id,Row=row,X=x,Z=z,Base=point(row,x,z),Size=part.Size,Part=part,Press=0};e.Mask=mask(e);e.Press=pressure(id,e)and 1 or 0
 part.CFrame=row.Frame*CFrame.new(lx,(e.Press==1 and Core.DownTop or Core.RestTop)-Core.Height/2,lz);live[id]=e;count+=1;Stats.CapWrites+=1
 dirtyRow(row,z);if e.Press==1 then touch(e);updateGlyph(e)end;return e
end
local function projection(row,x,z,camera)
 local p=point(row,x,z)+Vector3.new(0,Core.RestTop,0);local v=camera.CFrame:PointToObjectSpace(p);local depth=-v.Z
 if depth<=.1 then return false end
 local vp=camera.ViewportSize;local focal=vp.Y/(2*math.tan(math.rad(camera.FieldOfView/2)));local width=row.Grid.DX*focal/depth
 local sx,sy=v.X*focal/depth,-v.Y*focal/depth
 return math.abs(sx)<=vp.X/2+12 and math.abs(sy)<=vp.Y/2+12 and width>=6*vp.Y/848,width
end
local function refreshCanvases()
 local wanted={};local camera=workspace.CurrentCamera;local ranked={}
 for _,e in pairs(live)do local key=rowKey(e.Row,e.Z);if not wanted[key]then wanted[key]=true;ranked[#ranked+1]={Key=key,Row=e.Row,Z=e.Z,Distance=(e.Base-camera.CFrame.Position).Magnitude}end end
 table.sort(ranked,function(a,b)return a.Distance<b.Distance end)
 wanted={};local allocated=0
 local function commit(e,suffix,top,text)
  if allocated>=MAX_ROWS then return end;allocated+=1;local key=e.Key..suffix;wanted[key]=true;local entry=rowCanvases[key];local g=e.Row.Grid
  if not entry then local _,lz=Core.center(g,1,e.Z);entry=glyph(folder,Vector3.new(g.X,.02,g.DZ-.14),e.Row.Frame*CFrame.new(0,top+.11,lz),Scene.fill(e.Row.Stage),'',Vector2.new(g.NX*3*ADVANCE,24));entry.Row=e.Row;entry.Z=e.Z;rowCanvases[key]=entry end
  if entry.Label.Text~=text then entry.Label.Text=text;Stats.GlyphWrites=(Stats.GlyphWrites or 0)+1 end
 end
 for _,e in ipairs(ranked)do
  local row,g=e.Row,e.Row.Grid;local rest,down={},{};local hasDown=false
  for x=1,g.NX do local id=Core.id(row.Id,x,e.Z);local cap=live[id];local valid=#masks[row.Id]==0 or Scene.insideCell(row,x,e.Z,masks[row.Id]);local pressed=pressure(id,cap)or(cap and cap.Press>0)
   rest[x]=valid and not pressed and' '..letter(x,e.Z)..' 'or'   '
   local downGlyph=valid and pressed and not(cap and(cap.Mask or cap.Glyph or cap.Press<1));down[x]=downGlyph and' '..letter(x,e.Z)..' 'or'   ';hasDown=hasDown or downGlyph
  end
  commit(e,':rest',Core.RestTop,table.concat(rest));if hasDown then commit(e,':down',Core.DownTop,table.concat(down))end
 end
 for key,e in pairs(rowCanvases)do if not wanted[key]then e.Part:Destroy();rowCanvases[key]=nil end end
 Stats.RowCanvases=allocated
end
local function plan(at)
 local camera=workspace.CurrentCamera;if not camera then return end;Stats.Plans+=1;local desired={};pending={};cursor=1
 local buckets={};local focal=camera.ViewportSize.Y/(2*math.tan(math.rad(camera.FieldOfView/2)));local range=Core.Pitch*focal/(6*camera.ViewportSize.Y/848)+32
 for _,row in ipairs(rows)do if row.Keyboard and row.Enabled~=false then
  local g=row.Grid;local c=row.Frame:PointToObjectSpace(camera.CFrame.Position);local a=math.clamp(math.floor((c.X-range+g.X/2)/g.DX)+1,1,g.NX);local b=math.clamp(math.ceil((c.X+range+g.X/2)/g.DX),1,g.NX);local q=math.clamp(math.floor((c.Z-range+g.Z/2)/g.DZ)+1,1,g.NZ);local r=math.clamp(math.ceil((c.Z+range+g.Z/2)/g.DZ),1,g.NZ)
  for z=q,r do for x=a,b do Stats.CellVisits+=1;local visible=projection(row,x,z,camera)
   if visible and(#masks[row.Id]==0 or Scene.insideCell(row,x,z,masks[row.Id]))then local id=Core.id(row.Id,x,z);desired[id]=true;local distance=(point(row,x,z)-camera.CFrame.Position).Magnitude;local bucket=math.floor(distance/16);buckets[bucket]=buckets[bucket]or{};buckets[bucket][#buckets[bucket]+1]={Id=id,Row=row,X=x,Z=z}end
  end end
 end end
 for id in pairs(predicted)do desired[id]=true end
 for id in pairs(view.Held)do local row,x,z=decode(id);if row and(point(row,x,z)-at).Magnitude<160 then desired[id]=true end end
 for id,e in pairs(live)do if not desired[id]and not pressure(id,e)and e.Press==0 then recycle(id,e)end end
 for bucket=0,math.ceil(range/16)+1 do for _,e in ipairs(buckets[bucket]or{})do if not live[e.Id]then pending[#pending+1]=e end end end
 Stats.PlannedCaps=0;for _ in pairs(desired)do Stats.PlannedCaps+=1 end
 lastCamera=camera.CFrame;lastViewport=camera.ViewportSize;lastFov=camera.FieldOfView;lastAt=at;nextPlan=now+.1
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
 for id in pairs(nextSet)do if not old[id]or not live[id]then local row,x,z=decode(id);if row then local e=live[id]or createCap(row,x,z);if e then touch(e);updateGlyph(e);dirtyRow(row,z)end end end end
 for id in pairs(old)do if not nextSet[id]and live[id]then touch(live[id]);dirtyRow(live[id].Row,live[id].Z)end end
 for id,time in pairs(clicked)do if now-time>2 then clicked[id]=nil end end
end
local remoteConnection=remote.OnClientEvent:Connect(function(kind,seq,entries,descriptions)
 if not Core.packet(view,kind,seq,entries)then return end
 if kind=='Snapshot'then rows=descriptions;for id,e in pairs(live)do recycle(id,e)end;geometry();pending={};cursor=1;lastAt=nil;lastCamera=nil;nextPlan=0
 else for _,change in ipairs(entries)do local row,x,z=decode(change[1]);if row then dirtyRow(row,z)end;local e=live[change[1]];if not e and change[2]then local row,x,z=decode(change[1]);local at=center();local camera=workspace.CurrentCamera;if row and at and((point(row,x,z)-at).Magnitude<160 or(camera and projection(row,x,z,camera)))then urgent[change[1]]={Row=row,X=x,Z=z}end end;if e then touch(e)end
  if change[2]then local suppress=predicted[change[1]]or clicked[change[1]];clicked[change[1]]=nil;if not suppress then click(change[1])end else clicked[change[1]]=nil end
 end end
end)
remote:FireServer('Ready')
ADVANCE=Text:GetTextSize('MMMM',16,Enum.Font.Code,Vector2.new(1024,24)).X/4
assert(ADVANCE>0 and ADVANCE*3*57<=2048,'R145 monospace canvas metric unsupported')
local lastRevision=-1;local maskList={};local maskCursor=1
local renderConnection=Run.RenderStepped:Connect(function(dt)
 now=os.clock();FrameNo+=1;local at=center();if not at then return end
 if not rows then if now>=nextPlan then nextPlan=now+2;remote:FireServer('Ready')end;return end
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
 local work=0;while initialCursor<=#initial and work<64 do remember(initial[initialCursor]);enqueue(initial[initialCursor]);initialCursor+=1;work+=1 end
 work=0;while dirtyCursor<=#dirty and work<64 do local p=dirty[dirtyCursor];dirtyCursor+=1;dirtySet[p]=nil;updateProp(p);work+=1;Stats.DirtyVisits+=1 end
 if dirtyCursor>#dirty then dirty={};dirtyCursor=1 elseif dirtyCursor>256 then dirty=table.move(dirty,dirtyCursor,#dirty,1,{});dirtyCursor=1 end
 Stats.DirtyPending=#dirty-dirtyCursor+1;Stats.DirtySlots=#dirty
 if lastRevision~=revision and maskCursor>#maskList then maskList={};for _,e in pairs(live)do maskList[#maskList+1]=e end;maskCursor=1;lastRevision=revision end
 work=0;while maskCursor<=#maskList and work<64 do local e=maskList[maskCursor];maskCursor+=1;if live[e.Id]==e then local value=mask(e);if value~=e.Mask then e.Mask=value;touch(e);dirtyRow(e.Row,e.Z);canvasDirty=true end end;work+=1 end
 local animations=0
 local queueEnd=#activeQueue
 while activeCursor<=queueEnd and animations<MAX_ACTIVE do local e=activeQueue[activeCursor];activeCursor+=1;local id=e.Id;if active[id]==e then animations+=1;Stats.Animations+=1;local previous=e.Press;local down=pressure(id,e)
  e.Press=down and 1 or Core.animate(e.Press,false,dt)
  if e.Press~=previous then local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);e.Part.CFrame=e.Row.Frame*CFrame.new(lx,(Core.RestTop*(1-e.Press)+Core.DownTop*e.Press)-Core.Height/2,lz);Stats.CapWrites+=1;canvasDirty=true end
  -- Immediate press was applied by touch; ensure transform reconciles that target in the same frame.
  if down then local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);local desired=e.Row.Frame*CFrame.new(lx,Core.DownTop-Core.Height/2,lz);if e.Part.CFrame~=desired then e.Part.CFrame=desired;Stats.CapWrites+=1;canvasDirty=true end end
  updateGlyph(e);if e.Press==(down and 1 or 0)then active[id]=nil else activeQueue[#activeQueue+1]=e end
 end end
 if activeCursor>256 then activeQueue=table.move(activeQueue,activeCursor,#activeQueue,1,{});activeCursor=1 end
 local changed=0
 for key,e in pairs(rowDirty)do if changed>=96 then break end;rebuildRow(e.Row,e.Z);changed+=1 end
 -- Newly created fine meshes may never share a background face. Hide pending dirty rows until split commit.
 for key in pairs(rowDirty)do for _,part in ipairs(rowLive[key]or{})do part.Parent=nil end end
 if canvasDirty then refreshCanvases();canvasDirty=false end
 while #pool+count>MAX_CAPS do table.remove(pool):Destroy()end
 Stats.Caps=count;Stats.Pool=#pool;Stats.StaticParts=#static;Stats.ActiveVisited=animations;Stats.GlyphCarriers=glyphCarrierCount
end)
local function cleanup()
 renderConnection:Disconnect();remoteConnection:Disconnect();addedConnection:Disconnect();removedConnection:Disconnect();unhide();for p in pairs(registry)do clearProp(p)end
 for _,part in ipairs(pool)do part:Destroy()end;bare:Destroy();folder:Destroy()
 for _,list in pairs(rowLive)do for _,part in ipairs(list)do if not part.Parent then part:Destroy()end end end
end
local function diagnose()
 local camera=workspace.CurrentCamera;local sample;for _,entry in pairs(rowCanvases)do sample=entry;break end
 local out={Revision=145,Caps=count,RowCanvases=Stats.RowCanvases,GlyphCarriers=Stats.GlyphCarriers,DirtyPending=Stats.DirtyPending,AdmissionRejected=Stats.AdmissionRejected,AdmissionOverflow=Stats.AdmissionOverflow,FontAdvance=ADVANCE,CameraViewport=camera and camera.ViewportSize}
 if sample then out.CanvasSize=sample.Gui.CanvasSize;out.TextBounds=sample.Label.TextBounds;out.AbsoluteSize=sample.Label.AbsoluteSize;out.FirstGlyphU=.5/sample.Row.Grid.NX;out.LastGlyphU=1-.5/sample.Row.Grid.NX;out.CarrierClearance=.12 end
 print('[R145 diagnostic]',out);return out
end
return{Folder=folder,Stats=Stats,Cleanup=cleanup,Diagnose=diagnose}
