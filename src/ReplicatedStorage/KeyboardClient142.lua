-- Local visual meshes, never collidable/queryable. Server alone decides actor pressure.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Content=game:GetService('ContentProvider')
local Core=require(RS:WaitForChild('KeyboardCore142'))
local Scene=require(RS:WaitForChild('KeyboardScene142'))
local remote=RS:WaitForChild('Keyboard142State')
local template=RS:WaitForChild('R142Keycap')
local view={Sequence=-1,Held={}};local rows=nil
local folder=Instance.new('Folder');folder.Name='R142KeyboardVisuals';folder.Parent=workspace
local live,pool,pending={},{},{};local pendingIndex=1
local count=0;local nextBuild=0;local lastCenter=nil;local mask={};local nextMask=0
local sounds={};local nextSound=1;local audioReady=false
for i=1,12 do
 local p=Instance.new('Part');p.Name='KeySound';p.Anchored=true;p.Transparency=1;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Size=Vector3.one*.05;p.Parent=folder
 local s=Instance.new('Sound');s.Name='KeyClick';s.SoundId='rbxassetid://113108830240353';s.Volume=.38
 s.RollOffMode=Enum.RollOffMode.InverseTapered;s.RollOffMinDistance=6;s.RollOffMaxDistance=50;s.Parent=p
 sounds[i]={Part=p,Sound=s}
end
-- Permission/loading remains a real Studio acceptance gate. Log a diagnosed asset-load failure.
task.spawn(function()
 local okay,why=pcall(function()Content:PreloadAsync({sounds[1].Sound},function(_,status)
  if status==Enum.AssetFetchStatus.Success then audioReady=true end
 end)end)
 if not okay or not audioReady then warn('[R142] Keyboard sound could not load; verify permission for113108830240353 in this experience: '..tostring(why))end
end)
local function click(entry)
 if not audioReady or not entry or entry.Far then return end
 local camera=workspace.CurrentCamera;if not camera or(camera.CFrame.Position-entry.Home.Position).Magnitude>50 then return end
 local row=sounds[nextSound];nextSound=nextSound%#sounds+1
 row.Sound:Stop();row.Part.CFrame=entry.Home;row.Sound.PlaybackSpeed=.98+(nextSound%5)*.01;row.Sound.TimePosition=0;row.Sound:Play()
end
remote.OnClientEvent:Connect(function(kind,seq,entries,descriptions)
 if not Core.packet(view,kind,seq,entries)then return end
 if kind=='Snapshot'then rows=descriptions;nextBuild=0;lastCenter=nil
  for id,e in pairs(live)do e.Part.Parent=nil;pool[#pool+1]=e.Part end;live={};count=0;pending={};pendingIndex=1
 else for _,change in ipairs(entries)do if change[2]then click(live[change[1]])end end end
end)
remote:FireServer('Ready') -- Listener is connected before requesting the initial snapshot.
local function center()
 local camera=workspace.CurrentCamera
 local character=Players.LocalPlayer.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 return root and root.Position or(camera and camera.CFrame.Position)
end
local function recycle(id,e)
 live[id]=nil;e.Part.Parent=nil;pool[#pool+1]=e.Part;count-=1
end
local function tile(row,x,z,far,at)
 local lx,lz,w,d=Core.bounds(row.Grid,x,z,far and 2 or 1)
 local home=row.Frame*CFrame.new(lx,Core.RestTop-Core.Height/2,lz)
 -- Full rectangle must belong to this surface: prevents lobby tiles crossing a raised/rotated pad edge.
 for _,a in ipairs({-.5,.5})do for _,b in ipairs({-.5,.5})do
  if Scene.at(rows,row.Frame:PointToWorldSpace(Vector3.new(lx+a*w,0,lz+b*d)))~=row then return nil end
 end end
 local distance=(Vector3.new(home.X,at.Y,home.Z)-at).Magnitude
 if distance>Core.FarRadius then return nil end
 return {Id=(far and 'L:'or'')..Core.id(row.Id,x,z),Row=row,X=x,Z=z,Home=home,Size=Vector3.new(w,Core.Height,d),Distance=distance,Far=far}
end
local function plan(at)
 local candidates={};local nearN,farN=0,0
 for _,row in ipairs(rows or{})do if row.Enabled~=false then
  local g=row.Grid;local p=row.Frame:PointToObjectSpace(at)
  local a=math.clamp(math.floor((p.X-Core.FarRadius+g.X/2)/g.DX)+1,1,g.NX)
  local b=math.clamp(math.ceil((p.X+Core.FarRadius+g.X/2)/g.DX),1,g.NX)
  local c=math.clamp(math.floor((p.Z-Core.FarRadius+g.Z/2)/g.DZ)+1,1,g.NZ)
  local d=math.clamp(math.ceil((p.Z+Core.FarRadius+g.Z/2)/g.DZ),1,g.NZ)
  for x=a,b do for z=c,d do
   local lx,lz=Core.center(g,x,z);local distance=math.sqrt((lx-p.X)^2+(lz-p.Z)^2)
   -- Partition entire2x2 blocks once: no coarse cap can overlap a near member.
   local bx,bz=x-(x-1)%2,z-(z-1)%2
   local gx,gz=Core.bounds(g,bx,bz,2)
   local far=(gx-p.X)^2+(gz-p.Z)^2>Core.NearRadius^2
   if not far or(x%2==1 and z%2==1)then local e=tile(row,x,z,far,at);if e then candidates[#candidates+1]=e end end
  end end
 end end
 table.sort(candidates,function(a,b)return a.Distance<b.Distance end)
 local desired={};pending={};pendingIndex=1
 for _,e in ipairs(candidates)do
  if count>=Core.MaxCaps and nearN+farN>=Core.MaxCaps then break end
  if(e.Far and farN>=Core.MaxFar)or(not e.Far and nearN>=Core.MaxNear)then continue end
  if e.Far then farN+=1 else nearN+=1 end
  desired[e.Id]=true
  local old=live[e.Id]
  if old then old.Distance=e.Distance else pending[#pending+1]=e end
 end
 for id,e in pairs(live)do if not desired[id]then recycle(id,e)end end
end
local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.MaxParts=2048
local queryWarned=false
local function refreshMask(at)
 local exclude={folder}
 for _,p in ipairs(Players:GetPlayers())do if p.Character then exclude[#exclude+1]=p.Character end end
 local map=workspace:FindFirstChild('ChestChaseMap');local guardians=map and map:FindFirstChild('GuardianEncounters')
 if guardians then exclude[#exclude+1]=guardians end
 if map then local runtime=map:FindFirstChild('_GameplayRuntime');if runtime then for _,n in ipairs(runtime:GetChildren())do if n:GetAttribute('PersistentBiomeGuardian')or n:GetAttribute('VeiledKeeper81')then exclude[#exclude+1]=n end end end end
 overlap.FilterDescendantsInstances=exclude
 local surface=Scene.at(rows,at);local floorY=surface and surface.Frame.Position.Y or 4
 local parts=workspace:GetPartBoundsInBox(CFrame.new(at.X,floorY+.7,at.Z),Vector3.new(320,4,320),overlap)
 if #parts>=2048 and not queryWarned then queryWarned=true;warn('[R142] Nearby prop query reached2048parts; inspect visual support coverage/performance in Studio.')end
 -- These baseline markers/platforms deliberately have CanQuery=false; read their explicit scene roots.
 local function includeParts(root)
  if not root then return end
  for _,p in ipairs(root:GetDescendants())do if p:IsA('BasePart')and(p.Position-at).Magnitude<Core.FarRadius+24 then parts[#parts+1]=p end end
 end
 local runtime=map and map:FindFirstChild('_GameplayRuntime')
 includeParts(runtime and runtime:FindFirstChild('TrackHoles'))
 for _,root in ipairs({map and map:FindFirstChild('Seeds'),runtime})do
  if root then for _,p in ipairs(root:GetDescendants())do if p:IsA('Model')and p.Name=='PackPlatform'then includeParts(p)end end end
 end
 local floors={}
 local mapRoot=workspace:FindFirstChild('ChestChaseMap')
 if mapRoot then for _,p in ipairs(parts)do if p.Name=='LobbyFloor'or p.Name:match('^BiomeGround_%d')or(p.Name=='Pad'and p.Size.X>=60 and p.Size.Z>=60)then floors[p]=true end end end
 local boxes={};local bins={}
 local function bin(x,z)return math.floor(x/16)..':'..math.floor(z/16)end
 for _,p in ipairs(parts)do
  if floors[p]or p.Transparency>=.98 or p.Name:match('^Support_')then continue end
  local parent=p.Parent;local actor=false
  while parent and parent~=map do
   if parent:IsA('Model')and(parent:GetAttribute('PersistentBiomeGuardian')or parent:GetAttribute('GardenerArtVersion')or parent:GetAttribute('VeiledKeeper81'))then actor=true;break end
   parent=parent.Parent
  end
  if actor then continue end
  local e=Scene.extents(p);local lo,hi=p.Position-e,p.Position+e
  if e.X>80 or e.Z>80 then continue end
  local box={Lo=lo,Hi=hi}
  for x=math.floor((lo.X-3.2)/16),math.floor((hi.X+3.2)/16)do for z=math.floor((lo.Z-3.2)/16),math.floor((hi.Z+3.2)/16)do local k=x..':'..z;bins[k]=bins[k]or{};table.insert(bins[k],box)end end
 end
 local nextMask={}
 for id,e in pairs(live)do
  local floor=e.Row.Frame.Position.Y;local h=Scene.extents(e.Part);local p=e.Home.Position
  for _,b in ipairs(bins[bin(p.X,p.Z)]or{})do
   if b.Lo.Y<floor+Core.RestTop and b.Hi.Y>floor+.01 and p.X+h.X>b.Lo.X and p.X-h.X<b.Hi.X and p.Z+h.Z>b.Lo.Z and p.Z-h.Z<b.Hi.Z then nextMask[id]=true;break end
  end
 end
 mask=nextMask
end
local function held(e)
 local span=e.Far and 2 or 1
 for x=e.X,math.min(e.X+span-1,e.Row.Grid.NX)do for z=e.Z,math.min(e.Z+span-1,e.Row.Grid.NZ)do if view.Held[Core.id(e.Row.Id,x,z)]then return true end end end
 return false
end
Run.RenderStepped:Connect(function(dt)
 local at=center();if not at then return end
 local now=os.clock()
 if not rows then if now>nextBuild then nextBuild=now+2;remote:FireServer('Ready')end;return end
 if now>=nextBuild and(not lastCenter or(at-lastCenter).Magnitude>3)then plan(at);lastCenter=at;nextBuild=now+.2 end
 local built=0
 while pendingIndex<=#pending and built<Core.CreatePerFrame and count<Core.MaxCaps do
  local e=pending[pendingIndex];pendingIndex+=1;local part=table.remove(pool)or template:Clone()
  part.Name=e.Id;part.Size=e.Size;part.Color=Scene.palette(e.Row.Stage,e.X,e.Z);part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Anchored=true;part.CastShadow=false
  local label=part:FindFirstChildWhichIsA('TextLabel',true)
  if label then local legend='QWERTYUIOPASDFGHJKLZXCVBNM';label.Text=legend:sub((e.X*7+e.Z*11)%#legend+1,(e.X*7+e.Z*11)%#legend+1);label.TextColor3=e.Row.Stage%2==0 and Color3.fromRGB(54,31,69)or Color3.fromRGB(42,29,25)end
  e.Part=part;e.Label=label;e.Press=(held(e)or mask[e.Id])and 1 or 0
  part.CFrame=e.Home*CFrame.new(0,-(Core.RestTop-Core.DownTop)*e.Press,0);part.Parent=folder
  live[e.Id]=e;count+=1;built+=1
 end
 if now>=nextMask then nextMask=now+.25;refreshMask(at)end
 for id,e in pairs(live)do
  local down=held(e)or mask[id]
  local before=e.Press;e.Press=Core.animate(e.Press,down,dt)
  if e.Press~=before then e.Part.CFrame=e.Home*CFrame.new(0,-(Core.RestTop-Core.DownTop)*e.Press,0)end
  local fade=math.clamp((e.Distance-130)/20,0,1)
  if e.Fade~=fade then
   e.Fade=fade;e.Part.Transparency=fade
   if e.Label then e.Label.TextTransparency=fade;e.Label.TextStrokeTransparency=1 end
  end
 end
 -- Pool plus live are bounded; surplus from a smaller visible field is safely discarded.
 while #pool+count>Core.MaxCaps do table.remove(pool):Destroy()end
end)

return {Folder=folder}
