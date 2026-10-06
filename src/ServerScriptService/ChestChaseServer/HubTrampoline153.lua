-- R153 hub trampolines, server half (owner: "remove these benches at the corner just add a trampoline that boosts players up by a bit"). Built
-- once at start-up by HubDecor151.Apply into Workspace.ChestChaseMap.HubTrampolines153: one round, chunky, low trampoline in the middle of each
-- garden nook (HubTrampolineRules153.Spots), in the hub's palette (HubDecorKit151.P): six stubby feet, a red 16-sided frame, a ring of 16 gold
-- springs round a teal mat with a cream badge. The client half (HubTrampoline153.client) does the bouncing; this one only builds the geometry.
-- Collision matches what you see: ONE invisible cylinder (the only part that collides) covers the frame's whole footprint, its top 0.9 over the
-- floor (a kerb the game's runner steps onto without a jump), the mat and the frame ring at that height; the squash animation moves only the
-- visual mat and badge. Nothing but the collider can be queried (clicks and rays pass through the dressing). Planes: no two same-facing faces of
-- different parts share a height (checked by the hub z-fight run).
-- THE LOOK (owner: "trampoline can just use this asset 12088629887"), the pattern of the owner's tree templates (HubTreeLoader151): the built trampoline above is
-- always made first; then, off the start-up thread, the look is replaced by the owner's model: 1. a model the owner dropped into
-- ReplicatedStorage.HubTrampolineTemplates153 (preferred; "Get Model" on the store page with the game owner's account, which also cures "User is not authorized
-- to access Asset"), else 2. InsertService:LoadAsset(12088629887) (then AssetService:LoadAssetAsync), each with a timeout, else 3. the built one stays. A
-- model from outside is never trusted: it is cloned, every Script / LocalScript / ModuleScript is destroyed and so is everything that is not geometry (sounds,
-- click detectors, prompts, welds, humanoids, lights, particles, guis, remotes: HubStudTrees151.Sanitize), invisible and absurd parts go, every part is locked
-- (anchored, no collision, no touch, no query), the part count is capped, then it is scaled so its footprint is the collider's (12.1 studs), centred on the nook
-- with its mat (the largest flat top part, when one can be told) at the collider's top, held off the paving's planes; the built visuals go, the collider stays.
-- '/test trampoline' (Command) says which look is in use and why not the others.
local RS=game:GetService('ReplicatedStorage')
local K=require(RS:WaitForChild('HubDecorKit151'));local T=require(RS:WaitForChild('HubTrampolineRules153'))
local Trees=require(RS:WaitForChild('HubStudTrees151')) -- (its Sanitize / Lock / Box: the tree templates' own sanitiser)
local M={Version=153}
local V,CF=Vector3.new,CFrame.new
local P,Mat=K.P,Enum.Material
local F=T.Floor
-- Heights (absolute): the paving's top is 4.26; the walking top is Floor + Dims.Top = 4.9.
M.Layers={FootBottom=F+.2,FootTop=F+.5,GapBottom=F+.3,GapTop=F+.62,FrameBottom=F+.5,FrameTop=F+.94,SpringTop=F+.88,MatBottom=F+.62,MatTop=F+.86,BadgeBottom=F+.8,BadgeTop=F+1.06}
M.Frame={Sides=16,Ring=5.55,Width=1.0}      -- the frame's boxes stand on a 16-gon of this radius (5.05 - 6.05 from the centre)
M.Springs={Count=16,Ring=4.6,Diameter=.45}
M.Feet={Count=6,Ring=5.65,Diameter=1.2}   -- (the feet stand just outside the dark gap's edge, 5.05: no overlapping tops)
M.BadgeRadius=1.6
local function build(parent,spot)
 local L,D=M.Layers,T.Dims
 local x,z=spot.X,spot.Z
 local model=K.Model(parent,'Trampoline '..spot.Name,true)
 model:SetAttribute('Spot',spot.Name);model:SetAttribute('Top',T.Top());model:SetAttribute('Radius',D.Radius);model:SetAttribute('MatRadius',D.MatRadius)
 model:SetAttribute('CenterX',x);model:SetAttribute('CenterZ',z)
 -- the collider: the footprint of the frame, from just under the floor to the walking top
 local c=K.VCyl(model,'Trampoline collider',D.Radius*2,F-.1,T.Top(),x,z,P.Metal,Mat.SmoothPlastic,{collide=true,shadow=false,t=1})
 c.CanQuery=true -- (it is a floor the Humanoid stands on)
 for k=0,M.Feet.Count-1 do
  local a=(k+.5)/M.Feet.Count*math.pi*2
  K.VCyl(model,'Trampoline foot',M.Feet.Diameter,L.FootBottom,L.FootTop,x+math.cos(a)*M.Feet.Ring,z+math.sin(a)*M.Feet.Ring,P.StoneDark,Mat.Slate,{shadow=false})
 end
 -- the frame: 16 red boxes round a 16-gon (each a little longer than its side, so the corners close)
 local n=M.Frame.Sides;local side=2*M.Frame.Ring*math.tan(math.pi/n)+.16
 for k=0,n-1 do
  local a=k/n*math.pi*2
  K.Part(model,'Trampoline frame',V(side,L.FrameTop-L.FrameBottom,M.Frame.Width),
   CF(x+math.cos(a)*M.Frame.Ring,(L.FrameTop+L.FrameBottom)/2,z+math.sin(a)*M.Frame.Ring)*CFrame.Angles(0,-(a+math.pi/2),0),P.RoofRed,Mat.SmoothPlastic,{shadow=false})
 end
 -- the dark floor of the spring ring, and the springs (gold) standing on it between the mat and the frame
 K.VCyl(model,'Trampoline gap',(M.Frame.Ring-M.Frame.Width/2)*2,L.GapBottom,L.GapTop,x,z,P.Ink,Mat.SmoothPlastic,{shadow=false})
 for k=0,M.Springs.Count-1 do
  local a=(k+.5)/M.Springs.Count*math.pi*2
  K.VCyl(model,'Trampoline spring',M.Springs.Diameter,L.GapTop,L.SpringTop,x+math.cos(a)*M.Springs.Ring,z+math.sin(a)*M.Springs.Ring,P.Gold,Mat.SmoothPlastic,{shadow=false})
 end
 -- the mat and its badge (the only parts the client moves)
 local mat=K.VCyl(model,'Trampoline mat',D.MatRadius*2,L.MatBottom,L.MatTop,x,z,P.RoofTeal,Mat.SmoothPlastic,{shadow=false})
 local badge=K.VCyl(model,'Trampoline badge',M.BadgeRadius*2,L.BadgeBottom,L.BadgeTop,x,z,P.Cream,Mat.SmoothPlastic,{shadow=false})
 model:SetAttribute('HasMat',true);model:SetAttribute('Look','built')
 return model
end

-- The look from outside ----------------------------------------------------------------------------------------------------------------------------
M.Look='built'      -- what the nooks show now: built | template | asset
M.Status={}         -- what the last try found: Kind, Tried (why a route failed), Parts, Scripts, Other, Dropped, Route, Name, MatName, Done
local prepared=nil  -- the sanitised look, parentless: {Model, Parts, Scripts, Other, Dropped, MatIndex, MatName, Name, Source, Route}
local loading,gen,mapRef=false,0,nil
local PLANES={4.14,4.2,4.26,4.32} -- tops of the hub's paving layers: no flat top of the look may lie on one (HubSnow151.Keep)
local MAT_WORDS={'mat','bounc','jump','canvas','surface','fabric','cloth'}
local NOT_WORDS={'frame','leg','spring','pole','post','rim','ring','edge','foot','feet','support','net','shadow','border','rail','fence'}
local function short(e)local s=tostring(e or'?'):gsub('%s+',' ');return #s>160 and s:sub(1,160)..'...'or s end
local function sane(n)return n==n and n>0 and n<=T.MaxPartSize end
local function aabb(p) -- the world box of a part
 local c=p.CFrame;local s=p.Size;local r,u,l=c.RightVector,c.UpVector,c.LookVector
 local e=V((math.abs(r.X)*s.X+math.abs(u.X)*s.Y+math.abs(l.X)*s.Z)/2,(math.abs(r.Y)*s.X+math.abs(u.Y)*s.Y+math.abs(l.Y)*s.Z)/2,(math.abs(r.Z)*s.X+math.abs(u.Z)*s.Y+math.abs(l.Z)*s.Z)/2)
 return c.Position-e,c.Position+e
end
local function partsOf(model)local out={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then out[#out+1]=d end end;return out end
-- The mat: the largest roughly flat part up at the top of the look (thin, in the upper half, a quarter of the footprint or more), preferring names like Mat /
-- Bouncy / Jump; frames, legs, springs, poles and nets are not mats. Two like candidates (no telling the frame ring from the mat) = no mat = no squash.
local function findMat(list,lo,hi)
 local h=hi.Y-lo.Y;local foot=(hi.X-lo.X)*(hi.Z-lo.Z)
 if #list<2 or h<=0 or foot<=0 then return nil end
 local cands,hinted={},false
 for i,p in ipairs(list)do
  local a,b=aabb(p);local area=(b.X-a.X)*(b.Z-a.Z)
  if b.Y-a.Y<=.4*h and b.Y>=lo.Y+.5*h and area>=.25*foot then
   local n=string.lower(p.Name);local hint,bad=false,false
   for _,w in ipairs(MAT_WORDS)do if string.find(n,w,1,true)then hint=true end end
   for _,w in ipairs(NOT_WORDS)do if string.find(n,w,1,true)then bad=true end end
   if not bad then cands[#cands+1]={I=i,Area=area,Hint=hint};if hint then hinted=true end end
  end
 end
 local pool=cands
 if hinted then pool={};for _,c in ipairs(cands)do if c.Hint then pool[#pool+1]=c end end end
 table.sort(pool,function(x,y)return x.Area>y.Area end)
 if #pool==0 or(#pool>1 and pool[2].Area>=pool[1].Area*.95)then return nil end
 return pool[1].I
end
-- A safe private copy of a model (or part) from outside, or nil and why. The original is never used in place.
function M.Prepare(src)
 if typeof(src)~='Instance'then return nil,'it is not an instance'end
 if Trees.IsCode(src)then return nil,'it is a script, not a model'end
 local ok,copy=pcall(function()return src:Clone()end)
 if not ok or typeof(copy)~='Instance'then return nil,'it cannot be copied'end
 local model
 if copy:IsA('BasePart')then model=Instance.new('Model');copy.Parent=model
 elseif copy:IsA('Model')then model=copy
 elseif copy:IsA('Folder')then model=Instance.new('Model');for _,c in ipairs(copy:GetChildren())do c.Parent=model end;copy:Destroy()
 else copy:Destroy();return nil,'it is a '..src.ClassName..', not a model or a part'end
 local scripts,other=Trees.Sanitize(model) -- code and everything that is not geometry: counted, destroyed
 local dropped=0
 for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')and d:IsDescendantOf(model)then
  local s=d.Size
  if not(sane(s.X)and sane(s.Y)and sane(s.Z))or(d.Transparency or 0)>=.95 then dropped+=1;pcall(function()d:Destroy()end)end -- (absurd sizes; invisible hulls: the look has its own collider)
 end end
 local list=partsOf(model)
 local note=dropped>0 and(' ('..dropped..' invisible or absurd part(s) dropped)')or''
 if #list==0 then model:Destroy();return nil,'it has no usable parts'..note end
 if #list>T.AssetMaxParts then model:Destroy();return nil,string.format('too many parts (%d; the limit is %d per trampoline)',#list,T.AssetMaxParts)end
 local centre,size=Trees.Box(model)
 if not centre or math.max(size.X,size.Z)<.5 or math.max(size.X,size.Y,size.Z)>T.MaxPartSize*2 then model:Destroy();return nil,'an impossible size'end
 Trees.Lock(model,true) -- anchored, CanCollide / CanTouch / CanQuery off, Default collision group, shadows from the size
 local matI=findMat(list,centre-size/2,centre+size/2)
 return{Model=model,Parts=#list,Scripts=scripts,Other=other,Dropped=dropped,MatIndex=matI,MatName=matI and list[matI].Name or nil,Name=src.Name}
end
-- One look, cloned, scaled to the collider's footprint, centred on a nook, its mat at the collider's top, held off the paving's planes (nothing is in the world yet).
local function fit(spot)
 local look=prepared.Model:Clone();look.Name='Trampoline look'
 local centre,size=Trees.Box(look)
 local k=T.Dims.Radius*2/math.max(size.X,size.Z)
 look:ScaleTo(k)
 local list=partsOf(look);local mat=prepared.MatIndex and list[prepared.MatIndex]or nil
 centre,size=Trees.Box(look)
 local top=mat and select(2,aabb(mat)).Y or centre.Y+size.Y/2
 look:TranslateBy(V(spot.X-centre.X,T.Top()-top,spot.Z-centre.Z))
 local nudged=0 -- a flat top on a plane of the paving would z-fight with it: lift the look by a tenth (up to three times)
 while nudged<3 do
  local clash=false
  for _,p in ipairs(list)do local a,b=aabb(p);if b.Y-a.Y<=.5 then for _,y in ipairs(PLANES)do if math.abs(b.Y-y)<.04 then clash=true end end end end
  if not clash then break end
  look:TranslateBy(V(0,.1,0));nudged+=1
 end
 if mat then mat.Name='Trampoline mat' end
 look:SetAttribute('Scale',k);look:SetAttribute('Nudged',nudged);look:SetAttribute('Parts',#list)
 return look,mat~=nil
end
-- Both trampolines or neither: every look is fitted first, then the built visuals go (the collider stays) and the looks go in. Returns true, or false and why.
local function dressAll(folder,kind)
 local looks={}
 for _,spot in ipairs(T.Spots)do
  local m=folder:FindFirstChild('Trampoline '..spot.Name)
  if m then
   local ok,look,hasMat=pcall(fit,spot)
   if not ok then for _,l in ipairs(looks)do l.Look:Destroy()end;return false,short(look)end
   looks[#looks+1]={Model=m,Look=look,HasMat=hasMat}
  end
 end
 for _,l in ipairs(looks)do
  for _,c in ipairs(l.Model:GetChildren())do if c:IsA('BasePart')and c.Name~='Trampoline collider'then c:Destroy()end end
  l.Look:SetAttribute('Kind',kind);l.Look.Parent=l.Model
  l.Model:SetAttribute('HasMat',l.HasMat);l.Model:SetAttribute('Look',kind)
 end
 folder:SetAttribute('Look',kind);folder:SetAttribute('Looks',(folder:GetAttribute('Looks')or 0)+1) -- (the clients look again when this changes)
 return true
end
local function finish(info,kind)
 prepared=info;M.Look=kind
 local st=M.Status
 st.Kind=kind;st.Parts=info.Parts;st.Scripts=info.Scripts;st.Other=info.Other;st.Dropped=info.Dropped;st.Route=info.Route;st.Name=info.Name;st.MatName=info.MatName
 local f=mapRef and mapRef:FindFirstChild(T.FolderName)
 if f then
  local ok,why=dressAll(f,kind)
  if not ok then -- (cannot be placed: the built trampolines stay as they were)
   prepared=nil;M.Look='built';st.Kind='built';table.insert(st.Tried,'it could not be placed: '..tostring(why))
   warn('[R153 trampoline] the '..kind..' could not be placed ('..tostring(why)..'): the built trampoline stays.');return
  end
 end
 print(string.format('[R153 trampoline] %s: %d parts per trampoline, %d script(s) and %d other instance(s) removed, %d invisible or absurd part(s) dropped, mat %s',
  kind=='template'and('the hand-placed template "'..tostring(info.Name)..'"')or('asset '..T.AssetId..' loaded by '..tostring(info.Route)),info.Parts,info.Scripts,info.Other,info.Dropped,info.MatName and('"'..info.MatName..'" (squashes)')or'not found (no squash)'))
end
-- One load route with a timeout (a load that never answers must not hold anything).
local function within(seconds,fn)
 local state={}
 task.spawn(function()
  local ok,res=pcall(fn)
  if state.Gave then if ok and typeof(res)=='Instance'then pcall(function()res:Destroy()end)end;return end
  state.Ok,state.Res,state.Done=ok,res,true
 end)
 local t=0
 while not state.Done and t<seconds do task.wait(.1);t+=.1 end
 if not state.Done then state.Gave=true;return false,'timed out after '..seconds..' s'end
 return state.Ok,state.Res
end
function M.Load()
 local st=M.Status;local mine=gen
 st.Tried={};st.Kind='built'
 -- 1. the owner's hand-placed template (preferred): any Model / part / folder in ReplicatedStorage.HubTrampolineTemplates153
 local folder=RS:FindFirstChild(T.TemplateFolder);st.Templates=0
 if folder then for _,c in ipairs(folder:GetChildren())do if c:IsA('Model')or c:IsA('BasePart')or c:IsA('Folder')then
  st.Templates+=1
  local info,why=M.Prepare(c)
  if info then info.Source='template';return finish(info,'template')end
  st.Tried[#st.Tried+1]='template "'..c.Name..'": '..why
 end end end
 -- 2. the asset: InsertService:LoadAsset, then AssetService:LoadAssetAsync
 local container,route
 for _,r in ipairs({{'InsertService:LoadAsset',function()return game:GetService('InsertService'):LoadAsset(T.AssetId)end},
  {'AssetService:LoadAssetAsync',function()return game:GetService('AssetService'):LoadAssetAsync(T.AssetId)end}})do
  local ok,res=within(T.LoadTimeout,r[2])
  if ok and typeof(res)=='Instance'then container,route=res,r[1];break end
  st.Tried[#st.Tried+1]=r[1]..': '..short(ok and'it returned nothing'or res)
 end
 if mine~=gen then if container then pcall(function()container:Destroy()end)end;return end
 if container then
  local info,why=M.Prepare(container)
  pcall(function()container:Destroy()end)
  if info then info.Source='asset';info.Route=route;return finish(info,'asset')end
  st.Tried[#st.Tried+1]='asset '..T.AssetId..' ('..route..'): '..why
 end
 warn('[R153 trampoline] asset '..T.AssetId..' not used ('..table.concat(st.Tried,'; ')..'): the built trampoline stays. "Not authorized": open the store page with the game owner\'s account, "Get Model", and drop it into ReplicatedStorage.'..T.TemplateFolder..'.')
end
function M.StartLoad()
 if loading or M.Status.Done then return end
 loading=true;local mine=gen
 task.spawn(function()
  local ok,err=pcall(M.Load)
  if mine~=gen then return end
  loading=false;M.Status.Done=true
  if not ok then M.Status.Tried=M.Status.Tried or{};table.insert(M.Status.Tried,'error: '..short(err));warn('[R153 trampoline] '..short(err))end
 end)
end
-- Forget the look (and any load still running): the next Build starts over (the owner's `/test trampoline reload`, and the tests).
function M.Reset()prepared=nil;loading=false;gen+=1;M.Look='built';M.Status={}end
function M.Build(map)
 assert(map,'HubTrampoline153: no map')
 mapRef=map
 local old=map:FindFirstChild(T.FolderName);if old then old:Destroy()end
 local made0=K.Made
 local root=Instance.new('Folder');root.Name=T.FolderName;root:SetAttribute('Version',M.Version)
 for _,spot in ipairs(T.Spots)do build(root,spot)end
 root:SetAttribute('Parts',K.Made-made0);root:SetAttribute('Look','built')
 if prepared then local ok=dressAll(root,M.Look);if not ok then prepared=nil;M.Look='built'end end -- (already loaded on this server: no second load)
 root.Parent=map
 if not prepared then M.StartLoad()end
 return root
end
-- '/test trampoline [status | reload]': which look is in use, and why not the others.
function M.Describe()
 local st=M.Status;local out={}
 local f=RS:FindFirstChild(T.TemplateFolder)
 local hand=not f and'not there (nothing placed by hand)'or(st.Templates and st.Templates>0 and(st.Templates..' model(s) placed by hand')or'there, but empty')
 if M.Look=='asset'then out[#out+1]=string.format('Trampoline look: THE ASSET %s (loaded by %s; "%s").',tostring(T.AssetId),tostring(st.Route),tostring(st.Name))
 elseif M.Look=='template'then out[#out+1]=string.format('Trampoline look: THE HAND-PLACED TEMPLATE "%s" (ReplicatedStorage.%s).',tostring(st.Name),T.TemplateFolder)
 else out[#out+1]=st.Done and'Trampoline look: THE BUILT TRAMPOLINE (the fallback): the asset and the template were not used.'or(loading and'Trampoline look: the built trampoline for now; the load is still running.'or'Trampoline look: THE BUILT TRAMPOLINE (nothing was tried yet).')end
 if M.Look~='built'then
  out[#out+1]=string.format('  %d parts per trampoline (cap %d), %d script(s) and %d other instance(s) removed, %d invisible or absurd part(s) dropped; mat for the squash: %s.',st.Parts or 0,T.AssetMaxParts,st.Scripts or 0,st.Other or 0,st.Dropped or 0,st.MatName and('"'..st.MatName..'"')or'not found (no squash)')
 end
 out[#out+1]='  ReplicatedStorage.'..T.TemplateFolder..': '..hand..'.'
 local lost=false
 for _,t in ipairs(st.Tried or{})do out[#out+1]='  tried: '..t;if string.find(string.lower(t),'authoriz',1,true)then lost=true end end
 if lost then out[#out+1]='  "Not authorized" = the asset is not owned by the game\'s owner. Open the store page with the game owner\'s account, "Get Model", then drop the model into ReplicatedStorage.'..T.TemplateFolder..' in Studio (it is preferred over the asset); `/test trampoline reload` tries again.'end
 out[#out+1]=string.format('  Gameplay is the same whatever the look: one invisible collider %.1f studs over the floor, a %g-stud bounce, %.2f s debounce.',T.Dims.Top,T.Height(),T.Cooldown)
 return table.concat(out,'\n')
end
function M.Command(ctx,p,a)
 local sub=string.lower(tostring(a and a[1]or''))
 if sub=='reload'then
  local map=mapRef or(ctx and ctx.Map and ctx.Map.MapRoot);if not map then return false,'No map yet.'end
  M.Reset();M.Build(map)
  return true,'Trampolines rebuilt; the look is loading again. Run /test trampoline in a few seconds.\n'..M.Describe()
 elseif sub~=''and sub~='status'then return false,'Use trampoline [status | reload].'end
 return true,M.Describe()
end
return M
