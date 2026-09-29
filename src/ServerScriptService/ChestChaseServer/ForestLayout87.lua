-- R87: rigid camp relocation, before keeper and seed coordinates are cached.
local M={}
function M.Apply(map)
 if map:GetAttribute('ForestLayout87')then return end
 local camps=map:FindFirstChild('GuardianEncounters');local camp
 if camps then for _,m in ipairs(camps:GetChildren())do if m:GetAttribute('Stage')==1 then camp=m;break end end end
 if not camp then return end
 local home=camp:GetAttribute('GuardianHomeCFrame');if typeof(home)~='CFrame'then return end
 local target=CFrame.new(64,home.Position.Y,0)*CFrame.Angles(0,math.rad(90),0)
 local transform=target*home:Inverse()
 local function move(root,cf)
  local all=root:GetDescendants();table.insert(all,root)
  for _,n in ipairs(all)do
   if n:IsA('BasePart')then n.CFrame=cf*n.CFrame end
   for k,v in pairs(n:GetAttributes())do
    if k=='GuardianHomeCFrame'and typeof(v)=='CFrame'then n:SetAttribute(k,cf*v)
    elseif(k=='SceneCenter'or k=='PoolCenter'or k:match('^Node%d+$'))and typeof(v)=='Vector3'then n:SetAttribute(k,cf*v)end
   end
  end
 end
 move(camp,transform)
 local seeds=map:FindFirstChild('Seeds');if seeds then for _,m in ipairs(seeds:GetChildren())do if m:GetAttribute('Stage')==1 then move(m,transform)end end end
 -- Shift only scenery that physically intersects the new sleeping / pickup area.
 local function scenery(n)
  if n:IsA('Model')and n.Name~='BiomeDesignV091'and n.Name~='BiomeScenesV092'then
   local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
   for _,p in ipairs(n:GetDescendants())do if p:IsA('BasePart')then
    local q=p.Position;local r,u,l=p.CFrame.RightVector,p.CFrame.UpVector,p.CFrame.LookVector;local s=p.Size
    local x=(math.abs(r.X)*s.X+math.abs(u.X)*s.Y+math.abs(l.X)*s.Z)/2;local z=(math.abs(r.Z)*s.X+math.abs(u.Z)*s.Y+math.abs(l.Z)*s.Z)/2
    lo=Vector3.new(math.min(lo.X,q.X-x),math.min(lo.Y,q.Y-s.Y/2),math.min(lo.Z,q.Z-z));hi=Vector3.new(math.max(hi.X,q.X+x),math.max(hi.Y,q.Y+s.Y/2),math.max(hi.Z,q.Z+z))
   end end
   if hi.X>=38 and lo.X<=86 and hi.Z>=-38 and lo.Z<=38 and hi.Z-lo.Z<100 then
    local centre=(lo.X+hi.X)/2;move(n,CFrame.new(-64-centre,0,0))
   end
   return
  end
  for _,c in ipairs(n:GetChildren())do scenery(c)end
 end
 for _,name in ipairs({'RouteSceneryV134','SparseRouteSceneryV136','EnvironmentPolishV127','MythicLandmarks'})do local r=map:FindFirstChild(name);if r then scenery(r)end end
 local obby=map:FindFirstChild('Obby');local biomes=obby and obby:FindFirstChild('Biomes')
 if biomes then for _,b in ipairs(biomes:GetChildren())do if b:GetAttribute('Stage')==1 then
  for _,c in ipairs(b:GetChildren())do if not c:IsA('BasePart')then scenery(c)end end
 end end end
 map:SetAttribute('ForestLayout87',true)
end
return M
