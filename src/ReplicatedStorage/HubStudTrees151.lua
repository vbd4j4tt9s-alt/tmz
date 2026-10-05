-- R151 Seed Festival Square: studded tree templates (owner: "tress can also use this" + "there are different variations of trees that we can
-- use make sure they are studded" + "make sure they are collision is off as we dont want players jumping around bugging with it in highspeeds").
-- (This module is ReplicatedStorage.HubStudTrees151; the models live in the Folder ReplicatedStorage.HubTreeTemplates151.)
-- ReplicatedStorage.HubTreeTemplates151 holds tree models: the Creator Store trees the server loads at start (ChestChaseServer.HubTreeLoader151,
-- ids in HubDecorKit151.TreeAssetIds) and any model the owner drops in by hand. This module turns them into safe templates and places clones
-- in the hub's leafy tree slots (oaks, blossoms, fruit trees; HubLifeArt151):
--  * Sanitize: everything that is not geometry is removed - every Script / LocalScript / ModuleScript (counted), and every other non-visual
--    instance (welds, joints, constraints, body movers, sounds, lights, particles, prompts, values ...). Kept: parts, models, folders, meshes,
--    decals / textures, surface appearances.
--  * Lock: every BasePart (MeshParts, unions, nested parts included) Anchored, CanCollide / CanTouch / CanQuery off, the Default collision
--    group; Guard does the same to anything added later (DescendantAdded on the folders).
--  * Prepare: a sanitized, locked private copy (the original is never cloned into the world), its part count, size, and which parts are
--    leaves (name, colour, height) so clones can take the slot's leaf colour. Broken templates (no parts, impossible size, cannot be copied)
--    are reported and skipped.
--  * Plan: which slots get a template on this device tier (HubDecorKit151.TreeBudget: a clone with more than PerTree parts is not used on
--    that tier; all clones together add at most Total parts, slots taken in the layout's order), templates spread over the slots by a hash.
--  * Place: a clone fitted to the slot by its bounding box (ScaleTo to the slot's height, never wider than the slot's crown), turned, leaned a
--    little, grounded on the floor, leaves recoloured.
local RS=game:GetService('ReplicatedStorage')
local K=require(RS:WaitForChild('HubDecorKit151'))
local T={}
local V,CF=Vector3.new,CFrame.new
T.Version=151

-- Sanitize / lock ------------------------------------------------------------------------------------------------------------------------------
local KEEP={'BasePart','Model','Folder','DataModelMesh','FaceInstance','SurfaceAppearance'}
local KEEP_CLASS={SpecialMesh=true,BlockMesh=true,CylinderMesh=true,FileMesh=true,Decal=true,Texture=true,SurfaceAppearance=true,Folder=true,Model=true}
local CODE={'LuaSourceContainer','BaseScript','Script','LocalScript','ModuleScript'}
local function isa(o,list)for _,c in ipairs(list)do local ok,r=pcall(o.IsA,o,c);if ok and r then return true end end;return false end
function T.IsCode(o)return isa(o,CODE)end
function T.Kept(o)return KEEP_CLASS[o.ClassName]==true or isa(o,KEEP)end
-- Removes everything but geometry under root (root itself is kept). Returns scripts removed, other instances removed.
function T.Sanitize(root)
 local scripts,other=0,0
 local gone={}
 for _,o in ipairs(root:GetDescendants())do
  local code=T.IsCode(o)
  if code then scripts+=1 end
  if code or not T.Kept(o)then
   if not code then other+=1 end
   local p=o.Parent;local dead=false
   while p and p~=root do if gone[p]then dead=true;break end;p=p.Parent end
   if not dead then gone[o]=true;pcall(function()o:Destroy()end)end
  end
 end
 return scripts,other
end
-- Every BasePart (root included when it is one): anchored, never collides, untouchable, unqueryable, Default collision group.
local function lockPart(p,shadows) -- (reads first: a part that is already locked costs no property change)
 if p.Anchored~=true then p.Anchored=true end;if p.CanCollide~=false then p.CanCollide=false end
 if p.CanTouch~=false then p.CanTouch=false end;if p.CanQuery~=false then p.CanQuery=false end
 pcall(function()if p.CollisionGroup~='Default'then p.CollisionGroup='Default'end end)
 if shadows~=nil then local s=p.Size;p.CastShadow=shadows and math.max(s.X,s.Y,s.Z)>=2 end
end
function T.Lock(root,shadows)
 local n=0
 if root:IsA('BasePart')then lockPart(root,shadows);n+=1 end
 for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then lockPart(d,shadows);n+=1 end end
 return n
end
-- For DescendantAdded on the template folder: code and non-geometry go, parts are locked (a model added whole is walked too).
-- keepVisuals (GuardSquare, DescendantAdded on the client's square, which has its own signs, lights and particles): only code goes.
function T.Guard(o,keepVisuals)
 if o.Parent==nil then return 0 end
 if T.IsCode(o)then pcall(function()o:Destroy()end);return 1 end
 if not keepVisuals and not T.Kept(o)then pcall(function()o:Destroy()end);return 0 end
 local scripts=0
 if keepVisuals then
  for _,d in ipairs(o:GetDescendants())do if T.IsCode(d)and d.Parent then scripts+=1;pcall(function()d:Destroy()end)end end
 elseif not o:IsA('BasePart')then scripts=T.Sanitize(o)end
 if o:IsA('BasePart')or o:IsA('Model')or o:IsA('Folder')then T.Lock(o)end
 return scripts
end
function T.GuardSquare(o)return T.Guard(o,true)end

-- Prepare ------------------------------------------------------------------------------------------------------------------------------------
-- The world-axis bounding box of the visible parts: centre, size.
function T.Box(root,filter)
 local lo,hi
 local list=root:IsA('BasePart')and{root}or root:GetDescendants()
 for _,p in ipairs(list)do if p:IsA('BasePart')and(not filter or filter(p))then
  local c=p.CFrame;local s=p.Size
  local e=V(math.abs(c.RightVector.X)*s.X+math.abs(c.UpVector.X)*s.Y+math.abs(c.LookVector.X)*s.Z,
   math.abs(c.RightVector.Y)*s.X+math.abs(c.UpVector.Y)*s.Y+math.abs(c.LookVector.Y)*s.Z,
   math.abs(c.RightVector.Z)*s.X+math.abs(c.UpVector.Z)*s.Y+math.abs(c.LookVector.Z)*s.Z)/2
  local q=c.Position;local a,b=q-e,q+e
  lo=lo and V(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))or a
  hi=hi and V(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))or b
 end end
 if not lo then return nil,nil end
 return(lo+hi)/2,hi-lo
end
local LEAF_WORDS={'leaf','leaves','foliage','crown','canopy','bush','blossom','top'}
local TRUNK_WORDS={'trunk','wood','bark','log','branch','stem','root','stump'}
local function classify(p,centre,size)
 local n=string.lower(p.Name)
 for _,w in ipairs(TRUNK_WORDS)do if string.find(n,w,1,true)then return false end end
 for _,w in ipairs(LEAF_WORDS)do if string.find(n,w,1,true)then return true end end
 local c=p.Color;local r,g,b=c.R,c.G,c.B
 if g>r*1.08 and g>b*1.08 then return true end -- green
 if r>=g and g>=b and r-b>.08 and(r+g+b)/3<.65 then return false end -- brown
 return(p.CFrame.Position.Y-(centre.Y-size.Y/2))/math.max(size.Y,.01)>.45 -- the upper part of the tree
end
local function finite(v)return v==v and v>-1e6 and v<1e6 end
-- A safe private copy of a template. Returns info, or nil and why it cannot be used.
function T.Prepare(src)
 if typeof(src)~='Instance'then return nil,'not an instance'end
 if T.IsCode(src)then return nil,'a script, not a model'end
 -- (Clone skips anything with Archivable off: switch it on first; a local change only)
 pcall(function()src.Archivable=true;for _,d in ipairs(src:GetDescendants())do d.Archivable=true end end)
 local ok,copy=pcall(function()return src:Clone()end)
 if not ok or not copy then return nil,'cannot be copied'end
 copy.Parent=nil
 local model=copy
 if copy:IsA('BasePart')then model=Instance.new('Model');copy.Parent=model
 elseif copy:IsA('Folder')then model=Instance.new('Model');for _,c in ipairs(copy:GetChildren())do c.Parent=model end;copy:Destroy()
 elseif not copy:IsA('Model')then copy:Destroy();return nil,'not a model or part ('..src.ClassName..')'end
 model.Name=src.Name
 local scripts,other=T.Sanitize(model)
 local parts={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then parts[#parts+1]=d end end
 local info={Source=src,Name=src.Name,Model=model,Parts=#parts,ScriptsRemoved=scripts,OtherRemoved=other}
 if #parts==0 then model:Destroy();info.Model=nil;info.Broken='no parts';return info end
 for _,p in ipairs(parts)do local s=p.Size
  if not(finite(s.X)and finite(s.Y)and finite(s.Z))or s.Magnitude<.01 then model:Destroy();info.Model=nil;info.Broken='a part with an impossible size ('..p.Name..')';return info end
 end
 local centre,size=T.Box(model)
 if not centre or not(finite(size.X)and finite(size.Y)and finite(size.Z))or size.Y<.5 or math.max(size.X,size.Y,size.Z)>2000 then
  model:Destroy();info.Model=nil;info.Broken='an impossible size';return info
 end
 T.Lock(model,true)
 local leaves,fixed=0,false
 for _,p in ipairs(parts)do
  if classify(p,centre,size)then leaves+=1;p:SetAttribute('R151Leaf',true)
   if p:FindFirstChildWhichIsA('SurfaceAppearance')or(p:IsA('MeshPart')and(p.TextureID or'')~='')then fixed=true end
  end
 end
 info.Size=size;info.Leaves=leaves;info.Recolourable=leaves>0 and not fixed
 return info
end
-- Every usable template in the folder, sorted by name (every client the same order), plus a summary.
function T.Collect(folder)
 local infos,summary={},{ScriptsRemoved=0,Broken={},Templates=0}
 if not folder then return infos,summary end
 local list=folder:GetChildren();table.sort(list,function(a,b)return a.Name<b.Name end)
 for _,c in ipairs(list)do
  local info,why=T.Prepare(c)
  if info then summary.ScriptsRemoved+=info.ScriptsRemoved;infos[#infos+1]=info;if info.Broken then table.insert(summary.Broken,c.Name..': '..info.Broken)else summary.Templates+=1 end
  else table.insert(summary.Broken,c.Name..': '..tostring(why))end
 end
 return infos,summary
end

-- Plan ---------------------------------------------------------------------------------------------------------------------------------------
-- slots: {{Index, Kind, X, Z, Variant}, ...} in layout order. Returns {[Index] = info} and a summary.
function T.Plan(infos,tier,slots,budget)
 budget=budget or K.TreeBudget
 local per,total=budget.PerTree[tier]or 0,budget.Total[tier]or 0
 local usable={};for _,i in ipairs(infos or{})do if not i.Broken and i.Model and i.Parts<=budget.MaxParts then usable[#usable+1]=i end end
 local out,sum={},{Used=0,Parts=0,ByKind={},Eligible=0,PerTree=per,Total=total,Tier=tier,TooBig={}}
 for _,i in ipairs(usable)do if i.Parts>per then sum.TooBig[#sum.TooBig+1]=i.Name end end
 for _,s in ipairs(slots)do if budget.Kinds[s.Kind]then
  sum.Eligible+=1
  local cands={};for _,i in ipairs(usable)do if i.Parts<=per and(s.Kind~='blossom'or i.Recolourable)then cands[#cands+1]=i end end
  if #cands>0 then
   local pick=cands[math.min(#cands,math.floor(K.Rng('tree'..s.Kind..s.X..','..s.Z)()*#cands)+1)]
   if sum.Parts+pick.Parts>total then
    local cheap=cands[1];for _,i in ipairs(cands)do if i.Parts<cheap.Parts then cheap=i end end
    pick=sum.Parts+cheap.Parts<=total and cheap or nil
   end
   if pick then out[s.Index]=pick;sum.Parts+=pick.Parts;sum.Used+=1;sum.ByKind[s.Kind]=(sum.ByKind[s.Kind]or 0)+1 end
  end
 end end
 return out,sum
end
-- The folder attributes' texts.
function T.Describe(infos,sum)
 local parts={}
 for _,i in ipairs(infos or{})do parts[#parts+1]=i.Broken and(i.Name..' broken: '..i.Broken)or(i.Name..' '..i.Parts)end
 local used
 if not sum or #(infos or{})==0 then used='none: no tree templates (part-built studded trees)'
 elseif sum.Used==0 then used=string.format('none on tier %d: %s (part-built studded trees)',sum.Tier,#sum.TooBig>0 and('more than '..sum.PerTree..' parts a tree: '..table.concat(sum.TooBig,', '))or'no usable template')
 else
  local k={};for _,kind in ipairs({'oak','blossom','fruit'})do if sum.ByKind[kind]then k[#k+1]=kind..' '..sum.ByKind[kind]end end
  used=string.format('%d of %d leafy trees (%s), %d parts; tier %d: one tree up to %d parts, %d in all',sum.Used,sum.Eligible,table.concat(k,', '),sum.Parts,sum.Tier,sum.PerTree,sum.Total)
 end
 return table.concat(parts,', '),used
end

-- Place --------------------------------------------------------------------------------------------------------------------------------------
-- Slot sizes (studs): the part-built tree's height and crown width.
T.Fit={oak={S={13,14},M={18,18},L={23,22}},blossom={16,18},fruit={14,15}}
local function fitOf(kind,variant)local f=T.Fit[kind]or T.Fit.oak;if f[1]then return f[1],f[2]end;f=f[variant]or f.M;return f[1],f[2]end
local function relLum(c)return .3*c.R+.59*c.G+.11*c.B end
-- A clone for one slot: {Kind, Variant, X, Z}; o = {Floor, Leaf (Color3 or nil), Shadows}. Returns the Model (unparented) or nil.
function T.Place(info,slot,o)
 if not info or info.Broken or not info.Model then return nil end
 local ok,m=pcall(function()
  local m=info.Model:Clone();m.Parent=nil
  local rng=K.Rng('stud'..slot.Kind..tostring(slot.Variant)..slot.X..','..slot.Z)
  local h,w=fitOf(slot.Kind,slot.Variant)
  local k=math.min(h*rng(.9,1.1)/info.Size.Y,w*rng(.92,1)/math.max(info.Size.X,info.Size.Z))
  m:ScaleTo(m:GetScale()*k)
  local centre,size=T.Box(m)
  local bottom=V(centre.X,centre.Y-size.Y/2,centre.Z)
  local turn=CFrame.Angles(0,rng(0,math.pi*2),0)*CFrame.Angles(math.rad(rng(-3,3)),0,math.rad(rng(-3,3)))
  m:PivotTo(CF(slot.X,(o.Floor or K.Floor)-.3,slot.Z)*turn*CF(-bottom.X,-bottom.Y,-bottom.Z)*m:GetPivot())
  -- leaves: the slot's colour, each part keeping its own light / dark relative to the template's average leaf
  if o.Leaf and info.Recolourable then
   local leaves,sum={},0
   for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')and d:GetAttribute('R151Leaf')then leaves[#leaves+1]=d;sum+=relLum(d.Color)end end
   local avg=#leaves>0 and sum/#leaves or 1
   local c=typeof(o.Leaf)=='Color3'and o.Leaf or K.C(o.Leaf)
   for _,d in ipairs(leaves)do local f=math.clamp(relLum(d.Color)/math.max(avg,.01),.75,1.25)
    d.Color=Color3.new(math.clamp(c.R*f,0,1),math.clamp(c.G*f,0,1),math.clamp(c.B*f,0,1))
   end
  end
  T.Lock(m,o.Shadows~=false)
  return m
 end)
 if ok then return m end
 return nil
end
-- The leaves' bounding box (for fruit): centre, size.
function T.LeafBox(m)
 local c,s=T.Box(m,function(p)return p:GetAttribute('R151Leaf')==true end)
 if not c then c,s=T.Box(m)end
 return c,s
end
return T
