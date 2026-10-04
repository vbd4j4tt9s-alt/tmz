-- Continuous fixed-pitch track grid; bounded local extrusion/legends; authoritative actor pressure.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService');local Content=game:GetService('ContentProvider')
local Core=require(RS:WaitForChild('KeyboardCore143'));local Scene=require(RS:WaitForChild('KeyboardScene143'))
local remote=RS:WaitForChild('Keyboard143State');local template=RS:WaitForChild('R142Keycap')
local bare=template:Clone();bare.Parent=nil;for _,child in ipairs(bare:GetChildren())do child:Destroy()end
local folder=Instance.new('Folder');folder.Name='R143KeyboardVisuals';folder.Parent=workspace
local rows,view=nil,{Sequence=-1,Held={}};local byRow,masks={},{ }
local live,pool,active={}, {},{};local pending={};local cursor=1;local count=0
local static,pieces,staticCursor={}, {},1;local staticReady=false;local oldLocal={}
local lastAt,nextPlan=nil,0;local haloDirty=false;local now=0;local legendCount=0
local Stats={Caps=0,CapWrites=0,StaticParts=0,Legends=0,Plans=0,CellVisits=0,PropVisits=0,Registry=0,Watched=0,Listeners=0,DirtyVisits=0,MaskVisits=0,Animations=0}
local function rawPart(class,name,size,cf,color)
 local p=Instance.new(class);p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=folder;return p
end
local sounds={};local soundCursor=1;local audioReady=false
for i=1,12 do
 local p=rawPart('Part','KeySound',Vector3.one*.05,CFrame.new(),Color3.new());p.Transparency=1
 local sound=Instance.new('Sound');sound.SoundId='rbxassetid://113108830240353';sound.Volume=.38;sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.RollOffMinDistance=6;sound.RollOffMaxDistance=50;sound.Parent=p
 sounds[i]={Part=p,Sound=sound}
end
task.spawn(function()
 local okay,why=pcall(function()Content:PreloadAsync({sounds[1].Sound},function(_,status)audioReady=status==Enum.AssetFetchStatus.Success end)end)
 if not okay or not audioReady then warn('[R143] Supplied key click could not load; check experience permissions: '..tostring(why))end
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
 if not camera or(camera.CFrame.Position-p).Magnitude>50 then return end
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
local function recycle(id,e)
 live[id]=nil;active[id]=nil;e.Part.Parent=nil;pool[#pool+1]=e.Part;count-=1
 if e.Label then legendCount-=1 end
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
 byRow={};masks={}
 for _,row in ipairs(rows)do byRow[row.Id]=row;masks[row.Id]=Scene.masks(rows,row)end
 for _,row in ipairs(rows)do if row.Enabled~=false and row.Keyboard then
  local g=row.Grid;local polys=Scene.subtract(Scene.rectangle(-g.X/2,-g.Z/2,g.X/2,g.Z/2),masks[row.Id]);local color=Scene.fill(row.Stage)
  for _,poly in ipairs(polys)do
   local axis=#poly==4
   if axis then for i,p in ipairs(poly)do local q=poly[i%4+1];if math.abs(p[1]-q[1])>1e-5 and math.abs(p[2]-q[2])>1e-5 then axis=false end end end
   if axis then
    local x0,z0,x1,z1=math.huge,math.huge,-math.huge,-math.huge
    for _,p in ipairs(poly)do x0=math.min(x0,p[1]);x1=math.max(x1,p[1]);z0=math.min(z0,p[2]);z1=math.max(z1,p[2])end
    pieces[#pieces+1]={Class='Part',Size=Vector3.new(x1-x0,.016,z1-z0),Frame=row.Frame*CFrame.new((x0+x1)/2,Core.FillTop-.008,(z0+z1)/2),Color=color,Fill=true}
   else
    for i=2,#poly-1 do
     local function v(p)return row.Frame:PointToWorldSpace(Vector3.new(p[1],Core.FillTop-.008,p[2]))end
     local before=#pieces;trianglePlan(row,v(poly[1]),v(poly[i]),v(poly[i+1]),color)
     for j=before+1,#pieces do pieces[j].Fill=true end
    end
   end
  end
 end end
 -- Build every fill before any outlines; original tracks remain visible until fill commit.
 local fillCount=#pieces
 for _,row in ipairs(rows)do if row.Enabled~=false and row.Keyboard then
  local g=row.Grid;local ink=Scene.ink(row.Stage)
  local function line(a,b)
   for _,s in ipairs(Scene.segments(a,b,masks[row.Id],.055))do
    local dx,dz=s[2][1]-s[1][1],s[2][2]-s[1][2];local length=math.sqrt(dx*dx+dz*dz)
    if length>.001 then
     local middle=Vector3.new((s[1][1]+s[2][1])/2,Core.GridTop-.009,(s[1][2]+s[2][2])/2)
     local frame=row.Frame*CFrame.new(middle)*CFrame.Angles(0,math.atan2(dx,dz),0)
     pieces[#pieces+1]={Class='Part',Size=Vector3.new(.10,.018,length),Frame=frame,Color=ink}
    end
   end
  end
  for x=0,g.NX do local lx=math.clamp(-g.X/2+x*g.DX,-g.X/2+.05,g.X/2-.05);line({lx,-g.Z/2+.05},{lx,g.Z/2-.05})end
  for z=0,g.NZ do local lz=math.clamp(-g.Z/2+z*g.DZ,-g.Z/2+.05,g.Z/2-.05);line({-g.X/2+.05,lz},{g.X/2-.05,lz})end
 end end
 Stats.StaticPlanned=#pieces;Stats.FillPlanned=fillCount
end
-- Support registry: one bootstrap enumeration, bounded coalesced changes, no spatial/global rescan loop.
local map=workspace:WaitForChild('ChestChaseMap');local initial=map:GetDescendants();local initialCursor=1
local registry,bins={},{};local explicit,explicitIndex,explicitFree={}, {},{};local explicitCursor=1
local query=OverlapParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={map};query.MaxParts=1024
local nextQuery=0
local function remember(p)
 if not p:IsA('BasePart')or p.CanQuery~=false or explicitIndex[p]then return end
 if #explicit>=4096 and #explicitFree==0 then return end
 local i=table.remove(explicitFree)or(#explicit+1);explicit[i]=p;explicitIndex[p]=i
end
local dirty,dirtySet={},{};local dirtyCursor=1;local revision=0
local function bin(x,z)return math.floor(x/16)..':'..math.floor(z/16)end
local function actor(p)
 local at=p.Parent
 while at and at~=map do
  if at.Name=='GuardianEncounters'or at:IsA('Model')and(at:GetAttribute('PersistentBiomeGuardian')or at:GetAttribute('GardenerArtVersion')or at:GetAttribute('VeiledKeeper81'))then return true end
  at=at.Parent
 end
 return false
end
local function clearProp(p)
 local record=registry[p];if not record then return end
 for _,k in ipairs(record.Bins)do if bins[k]then bins[k][p]=nil end end
 for _,connection in ipairs(record.Connections)do connection:Disconnect();Stats.Listeners-=1 end
 registry[p]=nil;if record.Active then Stats.Registry-=1 end;Stats.Watched-=1;revision+=1
end
local function enqueue(p)
 if dirtySet[p]then return end
 if #dirty-dirtyCursor+1>=1024 then warn('[R143] Support change queue saturated; inspect this scene.');return end
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
 for _,k in ipairs(r.Bins)do if bins[k]then bins[k][p]=nil end end;r.Bins={}
 local on=eligible==true and p.Transparency<.98
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
local function targetLevel(distance,halo)
 if halo then return Core.RestTop end
 return Core.DownTop+(Core.RestTop-Core.DownTop)*math.clamp((Core.NearRadius-distance)/10,0,1)
end
local function touch(e)
 local held=view.Held[e.Id]~=nil;local down=held or e.Mask
 e.Down=down;active[e.Id]=e
end
local function plan(at)
 Stats.Plans+=1;local candidates={};local desired={};local camera=workspace.CurrentCamera
 local halo={};local promoted=0
 for id in pairs(view.Held)do
  local row,x,z=decode(id)
  if row and row.Keyboard then
   local p=point(row,x,z);local d=(Vector3.new(p.X,at.Y,p.Z)-at).Magnitude
   local cd=camera and(camera.CFrame.Position-p).Magnitude or d
   if d<160 or cd<160 then halo[#halo+1]={Id=id,Row=row,X=x,Z=z,Distance=d,Halo=true}end
  end
 end
 table.sort(halo,function(a,b)return a.Distance<b.Distance end)
 for _,e in ipairs(halo)do if promoted>=Core.MaxHalo then break end
  if e.Distance>Core.NearRadius and Scene.insideCell(e.Row,e.X,e.Z,masks[e.Row.Id])then candidates[#candidates+1]=e;desired[e.Id]=true;promoted+=1 end
 end
 for _,row in ipairs(rows)do if row.Enabled~=false and row.Keyboard then
  local g=row.Grid;local p=row.Frame:PointToObjectSpace(at)
  local a=math.clamp(math.floor((p.X-Core.NearRadius+g.X/2)/g.DX)+1,1,g.NX);local b=math.clamp(math.ceil((p.X+Core.NearRadius+g.X/2)/g.DX),1,g.NX)
  local c=math.clamp(math.floor((p.Z-Core.NearRadius+g.Z/2)/g.DZ)+1,1,g.NZ);local d=math.clamp(math.ceil((p.Z+Core.NearRadius+g.Z/2)/g.DZ),1,g.NZ)
  for x=a,b do for z=c,d do
   Stats.CellVisits+=1;local lx,lz=Core.center(g,x,z);local distance=math.sqrt((lx-p.X)^2+(lz-p.Z)^2)
   if distance<=Core.NearRadius and Scene.insideCell(row,x,z,masks[row.Id])then local id=Core.id(row.Id,x,z);desired[id]=true;candidates[#candidates+1]={Id=id,Row=row,X=x,Z=z,Distance=distance}end
  end end
 end end
 table.sort(candidates,function(a,b)if a.Halo~=b.Halo then return not a.Halo end;return a.Distance<b.Distance end)
 pending={};cursor=1;local near=0;promoted=0
 for _,e in ipairs(candidates)do
  if e.Halo then if promoted>=Core.MaxHalo then desired[e.Id]=nil;continue end;promoted+=1
  else if near>=Core.MaxNear then desired[e.Id]=nil;continue end;near+=1 end
  local old=live[e.Id]
  if old then old.Distance=e.Distance;old.Halo=e.Halo;old.LevelTarget=targetLevel(e.Distance,e.Halo);active[e.Id]=old
  else pending[#pending+1]=e end
 end
 for id,e in pairs(live)do
  if not desired[id]then
   if e.Halo and not view.Held[id]and e.Level>Core.DownTop+.002 then e.LevelTarget=Core.DownTop;e.Down=false;active[id]=e
   else recycle(id,e)end
  end
 end
end
local remoteConnection=remote.OnClientEvent:Connect(function(kind,seq,entries,descriptions)
 if not Core.packet(view,kind,seq,entries)then return end
 if kind=='Snapshot'then
  rows=descriptions;geometry();for id,e in pairs(live)do recycle(id,e)end;pending={};cursor=1;lastAt=nil;nextPlan=0
 else
  for _,change in ipairs(entries)do local e=live[change[1]];if e then touch(e)end;if change[2]then click(change[1])end end
  local at=center();local camera=workspace.CurrentCamera;local relevant=false
  for _,change in ipairs(entries)do
   local row,x,z=decode(change[1]);if row and at then local p=point(row,x,z);local d=(Vector3.new(p.X,at.Y,p.Z)-at).Magnitude
    if d>Core.NearRadius and(d<160 or camera and(camera.CFrame.Position-p).Magnitude<160)then relevant=true end
   end
  end
  if relevant then haloDirty=true end
 end
end)
remote:FireServer('Ready')
local maskCursor=1;local maskList={};local lastRevision=-1
local renderConnection=Run.RenderStepped:Connect(function(dt)
 now=os.clock();local at=center();if not at then return end
 if not rows then if now>=nextPlan then nextPlan=now+2;remote:FireServer('Ready')end;return end
 local built=0
 while staticCursor<=#pieces and built<Core.StaticPerFrame do
  local p=pieces[staticCursor];staticCursor+=1;local o=rawPart(p.Class,'TrackGrid',p.Size,p.Frame,p.Color);static[#static+1]=o;built+=1
  if not staticReady and staticCursor>Stats.FillPlanned then
   staticReady=true;for _,candidate in ipairs(initial)do hideFloor(candidate)end
  end
 end
 Stats.StaticParts=#static
 if now>=nextPlan and(not lastAt or(at-lastAt).Magnitude>2 or haloDirty)then plan(at);lastAt=at;haloDirty=false;nextPlan=now+.25;nextQuery=0 end
 local created=0
 while cursor<=#pending and created<Core.CreatePerFrame and count<Core.MaxCaps do
  local e=pending[cursor];cursor+=1;local p=table.remove(pool)or bare:Clone()
  for _,gui in ipairs(p:GetChildren())do gui:Destroy()end
  local lx,lz,w,d=Core.bounds(e.Row.Grid,e.X,e.Z);e.Base=point(e.Row,e.X,e.Z);e.Size=Vector3.new(w,Core.Height,d)
  p.Name=e.Id;p.Size=e.Size;p.Color=Scene.palette(e.Row.Stage,e.X,e.Z);p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Transparency=0
  if legendCount<Core.MaxLegends and e.Distance<20 then
   local sourceGui=template:FindFirstChildWhichIsA('SurfaceGui');local gui=sourceGui and sourceGui:Clone()
   if gui then gui.MaxDistance=35;gui.Parent=p;local label=gui:FindFirstChildWhichIsA('TextLabel',true);local text='QWERTYUIOPASDFGHJKLZXCVBNM';local n=(e.X*7+e.Z*11)%#text+1;label.Text=text:sub(n,n);label.TextColor3=Scene.ink(e.Row.Stage);e.Label=label;legendCount+=1 end
  end
  e.Part=p;e.Mask=mask(e);e.LevelTarget=targetLevel(e.Distance,e.Halo);e.Level=e.LevelTarget;e.Press=(view.Held[e.Id]or e.Mask)and 1 or 0
  local top=e.Level*(1-e.Press)+Core.DownTop*e.Press;p.CFrame=e.Row.Frame*CFrame.new(lx,top-Core.Height/2,lz);p.Parent=folder
  live[e.Id]=e;count+=1;created+=1;touch(e);Stats.CapWrites+=1
 end
 if now>=nextQuery then
  nextQuery=now+.5;local surface=Scene.at(rows,at);local floorY=surface and surface.Frame.Position.Y or 4
  local found=workspace:GetPartBoundsInBox(CFrame.new(at.X,floorY+.7,at.Z),Vector3.new(112,6,112),query)
  Stats.Queries=(Stats.Queries or 0)+1;Stats.QueryParts=(Stats.QueryParts or 0)+#found
  for _,p in ipairs(found)do if not actor(p)then enqueue(p)end end
 end
 local scanned=0
 while scanned<16 and #explicit>0 do
  if explicitCursor>#explicit then explicitCursor=1 end
  local p=explicit[explicitCursor];explicitCursor+=1;scanned+=1
  if p and p.Parent and not actor(p)then enqueue(p)end
 end
 local work=0
 while initialCursor<=#initial and work<64 do remember(initial[initialCursor]);updateProp(initial[initialCursor]);initialCursor+=1;work+=1 end
 work=0
 while dirtyCursor<=#dirty and work<64 do local p=dirty[dirtyCursor];dirtyCursor+=1;dirtySet[p]=nil;updateProp(p);work+=1;Stats.DirtyVisits+=1 end
 if dirtyCursor>#dirty then dirty={};dirtyCursor=1 elseif dirtyCursor>256 then dirty=table.move(dirty,dirtyCursor,#dirty,1,{});dirtyCursor=1 end
 Stats.DirtyPending=#dirty-dirtyCursor+1;Stats.DirtySlots=#dirty
 if lastRevision~=revision and maskCursor>#maskList then maskList={};for _,e in pairs(live)do maskList[#maskList+1]=e end;maskCursor=1;lastRevision=revision end
 work=0
 while maskCursor<=#maskList and work<64 do local e=maskList[maskCursor];maskCursor+=1;if live[e.Id]==e then local value=mask(e);if value~=e.Mask then e.Mask=value;touch(e)end end;work+=1 end
 for id,e in pairs(active)do
  Stats.Animations+=1;local beforePress,beforeLevel=e.Press,e.Level
  e.Press=Core.animate(e.Press,view.Held[id]~=nil or e.Mask,dt)
  -- Intermediate taper levels are targets, not merely binary rest/down.
  e.Level=beforeLevel+(e.LevelTarget-beforeLevel)*(1-math.exp(-math.clamp(dt,0,.1)*18))
  if math.abs(e.Level-e.LevelTarget)<.001 then e.Level=e.LevelTarget end
  if e.Press~=beforePress or e.Level~=beforeLevel then
   local lx,lz=Core.center(e.Row.Grid,e.X,e.Z);local top=e.Level*(1-e.Press)+Core.DownTop*e.Press
   e.Part.CFrame=e.Row.Frame*CFrame.new(lx,top-Core.Height/2,lz);Stats.CapWrites+=1
  end
  if e.Press==((view.Held[id]or e.Mask)and 1 or 0)and e.Level==e.LevelTarget then active[id]=nil
   if e.Halo and not view.Held[id]and e.LevelTarget==Core.DownTop then recycle(id,e)end
  end
 end
 while #pool+count>Core.MaxCaps do table.remove(pool):Destroy()end
 Stats.Caps=count;Stats.Legends=legendCount;Stats.Pool=#pool
end)
local function cleanup()
 renderConnection:Disconnect();remoteConnection:Disconnect();addedConnection:Disconnect();removedConnection:Disconnect()
 unhide();for p in pairs(registry)do clearProp(p)end;for _,p in ipairs(pool)do p:Destroy()end;pool={};bare:Destroy();folder:Destroy()
end
return {Folder=folder,Stats=Stats,Cleanup=cleanup}
