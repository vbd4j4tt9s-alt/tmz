-- Runs once, before pack/hazard/keeper coordinates are cached. Decorative models stay rigid.
local R=require(game:GetService('ReplicatedStorage').RouteBalance83)
local T={};local V,CF=Vector3.new,CFrame.new
local function path(root,s)for n in s:gmatch('[^/]+')do root=root and root:FindFirstChild(n)end;return root end
local function nodes(root)local a=root:GetDescendants();table.insert(a,1,root);return a end
function T.Apply(map)
 if map:GetAttribute('RoutesExpandedR83')then assert(math.abs(map:GetAttribute('BiomeTrackEndZ')-R.End)<.01,'R83 route bounds changed');return end
 assert(math.abs((map:GetAttribute('BiomeTrackEndZ')or 0)-R.OldEnd)<.01,'R83 requires the R82 route geometry')
 local biomes=assert(path(map,'Obby/Biomes'));local walls=assert(path(map,'Obby/BiomeWalls'))
 local byStage={};for _,b in ipairs(biomes:GetChildren())do local id=b:GetAttribute('Stage');if id then byStage[id]=b end end
 local edits,created,touched={},{},{};local function set(item,key,value,attribute)
  local old;if attribute then old=item:GetAttribute(key)else old=item[key]end
  table.insert(edits,{Item=item,Key=key,Before=old,After=value,Attribute=attribute})
 end
 local function attr(i,k,v)set(i,k,v,true)end
 local function attributes(item,delta)
  for k,v in pairs(item:GetAttributes())do
   if (k=='SceneCenter'or k=='PoolCenter'or k:match('^Node%d+$'))and typeof(v)=='Vector3'then attr(item,k,v+V(0,0,delta))
   elseif (k=='MagmaRest'or k=='GuardianHomeCFrame'or k=='ClosedHingeCFrame'or k=='OpenHingeCFrame')and typeof(v)=='CFrame'then attr(item,k,v+V(0,0,delta))end
  end
 end
 local function group(root,delta)
  if not root then return end
  local all=nodes(root)
  if not delta then
   local lo,hi=math.huge,-math.huge
   for _,n in ipairs(all)do if n:IsA('BasePart')then lo=math.min(lo,n.Position.Z);hi=math.max(hi,n.Position.Z)end end
   if hi==-math.huge then return end
   local z=(lo+hi)*.5;delta=R.MapZ(z)-z
  end
  for _,n in ipairs(all)do if not touched[n]then
   touched[n]=true;if n:IsA('BasePart')then set(n,'CFrame',n.CFrame+V(0,0,delta))end
   attributes(n,delta)
  end end
 end
 local function stretch(part,first,last)
  if not part or touched[part]then return end;touched[part]=true
  assert(math.abs(part.CFrame.LookVector.Z)>.9999,'R83 structural part rotated: '..part:GetFullName())
  first=first or R.MapZ(part.Position.Z-part.Size.Z/2);last=last or R.MapZ(part.Position.Z+part.Size.Z/2)
  local length=last-first;assert(length>0)
  local count=math.ceil(length/2000);local span=length/count
  -- Never exceed Roblox's per-part size limit on the full-route barriers or fall plane.
  for i=1,count do
   local item=part
   if i>1 then item=part:Clone();item.Name=part.Name..'_R83_'..i;table.insert(created,{Item=item,Parent=part.Parent});item.Parent=nil end
   set(item,'Size',V(part.Size.X,part.Size.Y,span))
   set(item,'CFrame',CF(part.Position.X,part.Position.Y,first+(i-.5)*span)*part.CFrame.Rotation)
  end
 end
 local ok,err=pcall(function()
  for _,id in ipairs(R.Order)do
   local biome=assert(byStage[id],'Missing biome '..id);local ground=assert(biome:FindFirstChild('BiomeGround_'..id))
   assert(math.abs(ground.Size.Z-R.OldLengths[id])<.05,'R83 ground length differs: '..id)
   local a,b=R.NewStart[id],R.NewStart[id]+R.Lengths[id]
   stretch(ground,a,b)
   for _,key in ipairs({'LeftBiomeEdge','RightBiomeEdge'})do stretch(biome:FindFirstChild(key),a,b)end
   for _,side in ipairs({'LeftWall','RightWall'})do
    local w=assert(walls:FindFirstChild('Biome_'..id..'_'..side));stretch(w,a,b);attr(w,'TrackStartZ',a);attr(w,'TrackEndZ',b)
   end
   for _,n in ipairs({biome,path(map,'Obby/Stages/Stage_'..id)})do if n then attr(n,'TrackStartZ',a);attr(n,'TrackEndZ',b);attr(n,'BiomeLength',R.Lengths[id])end end
   attr(map,'BiomeStartZ_'..id,a);attr(map,'BiomeEndZ_'..id,b);attr(map,'BiomeLength_'..id,R.Lengths[id])
  end
  for _,wall in ipairs(walls:GetChildren())do if wall:IsA('BasePart')and wall.Name:match('_EndWall$')then group(wall,R.End-R.OldEnd)end end
  local middle=R.OldStart[4]+R.OldLengths[4]*.5;local lavaDelta=R.MapZ(middle)-middle
  for _,s in ipairs({'PresentationV128','EnvironmentPolishV127/IrregularMagmaPools','MythicLandmarks/Biome4_Landmark'})do group(path(map,s),lavaDelta)end
  group(byStage[4]:FindFirstChild('BiomeScenesV092'),lavaDelta)
  local function scenery(root)
   if touched[root]then return end
   if root:IsA('BasePart')then group(root);return end
   if root:IsA('Model')and root.Name~='BiomeDesignV091'and root.Name~='BiomeScenesV092'then group(root);return end
   for _,child in ipairs(root:GetChildren())do scenery(child)end
  end
  for _,b in pairs(byStage)do for _,n in ipairs(b:GetChildren())do scenery(n)end end
  for _,name in ipairs({'MythicLandmarks','EnvironmentPolishV127','RouteSceneryV134','SparseRouteSceneryV136'})do local root=map:FindFirstChild(name);if root then for _,n in ipairs(root:GetChildren())do scenery(n)end end end
  local camps={}
  for _,m in ipairs(assert(map:FindFirstChild('GuardianEncounters')):GetChildren())do
   local id=m:GetAttribute('Stage');local home=m:GetAttribute('GuardianHomeCFrame')
   if id and typeof(home)=='CFrame'then local delta=R.MapZ(home.Position.Z)-home.Position.Z;camps[id]=delta;group(m,delta)end
  end
  for _,m in ipairs(assert(map:FindFirstChild('Seeds')):GetChildren())do local id=m:GetAttribute('Stage');if camps[id]then group(m,camps[id])end end
  for _,p in ipairs(assert(map:FindFirstChild('InvisibleMapBarriersV071')):GetChildren())do if p:IsA('BasePart')then
   if p:GetAttribute('BarrierType')=='BiomeSide'then stretch(p)
   elseif p:GetAttribute('BarrierType')=='BiomeEnd'then group(p,R.End-R.OldEnd)end
  end end
  stretch(path(map,'Obby/FallReturnPlane'),R.Start-20,R.End+20)
  attr(map,'BiomeTrackEndZ',R.End);attr(map,'TrackLength',R.End-R.Start);attr(map,'BiomeLength',R.Lengths[1]);attr(map,'RoutesExpandedR83',true)
 end)
 if not ok then for _,v in ipairs(created)do v.Item:Destroy()end;error(err)end
 local done=0
 local success,why=pcall(function()
  for i,e in ipairs(edits)do done=i;if e.Attribute then e.Item:SetAttribute(e.Key,e.After)else e.Item[e.Key]=e.After end end
  for _,v in ipairs(created)do v.Item.Parent=v.Parent end
 end)
 if not success then
  for i=done,1,-1 do local e=edits[i];if e.Attribute then e.Item:SetAttribute(e.Key,e.Before)else e.Item[e.Key]=e.Before end end
  for _,v in ipairs(created)do v.Item:Destroy()end;error(why)
 end
 map:SetAttribute('R83RoutePartAdds',#created)
end
return T
