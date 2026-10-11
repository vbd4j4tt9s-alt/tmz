-- R151 Seed Festival Square: the owner's studded trees (owner: "tress can also use this" with Creator Store asset 17280628013 "studded-tree",
-- then 16637971059 "Stud-Tree" and "there are different variations of trees that we can use make sure they are studded").
-- Once per server, at start (HubDecor151.Apply spawns Run), every id in HubDecorKit151.TreeAssetIds is loaded and parked in
-- ReplicatedStorage.HubTreeTemplates151, where each client's HubLife151 picks the trees up as templates:
--   1. AssetService:LoadAssetAsync(id) - loads free Creator Store models when the experience allows third-party assets (Studio: Game Settings >
--      Security > "Allow Loading Third Party Assets" = AssetService.AllowInsertFreeAssets, which scripts cannot set); returns a sandboxed model.
--   2. InsertService:LoadAsset(id) - works when the owner (the game's creator) owns the model, e.g. took it into the inventory.
--   3. Neither: whatever tree models the owner put into the folder by hand in Studio; with none, the part-built studded trees stay.
-- Whatever arrives (loaded or hand-inserted) is stripped of every script and non-geometry instance and of any fruit (owner: "remove the apples
-- or red stuff on the trees the trees are just trees"; HubStudTrees151.StripFruit) and has all collision / touch / query off
-- (HubStudTrees151.Sanitize / Lock), also for anything added to the folder later. One log line per id says which route worked; the folder
-- carries Route<id>, ScriptsRemoved, Loaded, Manual and Ready attributes. '/test hubtrees' (Command) prints all of it plus each tier's plan.
local RS=game:GetService('ReplicatedStorage')
local K=require(RS:WaitForChild('HubDecorKit151'))
local T=require(RS:WaitForChild('HubStudTrees151'))
local L={}
L.Status={} -- [id] = {Route=, Error=, Parts=, Scripts=, Name=}
local started=false
local function short(e)local s=tostring(e or'?'):gsub('%s+',' ');return #s>140 and s:sub(1,140)..'...'or s end
function L.Folder()
 local f=RS:FindFirstChild(K.TreeFolder)
 if not f then f=Instance.new('Folder');f.Name=K.TreeFolder;f.Parent=RS end
 return f
end
-- One id: the loaded container model and the route, or nil and why.
function L.Load(id)
 local errs={}
 local ok,res=pcall(function()return game:GetService('AssetService'):LoadAssetAsync(id)end)
 if ok and typeof(res)=='Instance'then return res,'AssetService'end
 errs[#errs+1]='AssetService: '..short(ok and'nothing returned'or res)
 ok,res=pcall(function()return game:GetService('InsertService'):LoadAsset(id)end)
 if ok and typeof(res)=='Instance'then return res,'InsertService'end
 errs[#errs+1]='InsertService: '..short(ok and'nothing returned'or res)
 return nil,nil,table.concat(errs,'; ')
end
-- LoadAsset(Async) wraps the asset in a Model: use the asset itself when it is the only child.
local function unwrap(container)
 local kids=container:GetChildren()
 if #kids==1 and(kids[1]:IsA('Model')or kids[1]:IsA('BasePart')or kids[1]:IsA('Folder'))then
  local m=kids[1];m.Parent=nil;container:Destroy();return m
 end
 return container
end
local function countParts(m)local n=m:IsA('BasePart')and 1 or 0;for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then n+=1 end end;return n end
function L.Run(again) -- (again: the offline tests run it more than once)
 if started and not again then return L.Status end
 started=true
 local f=L.Folder()
 local scripts,manual,loaded,fruit=0,0,0,0
 -- the owner's hand-inserted trees: strip code, physics off
 for _,c in ipairs(f:GetChildren())do if c:GetAttribute('R151AssetId')==nil then
  if T.IsCode(c)then c:Destroy();scripts+=1 else scripts+=T.Sanitize(c);fruit+=T.StripFruit(c);T.Lock(c);manual+=1 end
 end end
 if L.Watch then L.Watch:Disconnect()end
 L.Watch=f.DescendantAdded:Connect(function(d)local n=T.Guard(d);if n>0 then f:SetAttribute('ScriptsRemoved',(f:GetAttribute('ScriptsRemoved')or 0)+n)end end)
 f:SetAttribute('Manual',manual);f:SetAttribute('ScriptsRemoved',scripts)
 for _,id in ipairs(K.TreeAssetIds)do
  local name='Asset'..tostring(id);local st={Id=id}
  L.Status[id]=st
  if f:FindFirstChild(name)then st.Route='already there'
  else
   local res,route,err=L.Load(id)
   if res then
    local m=unwrap(res)
    local assetName=m.Name;local s=T.IsCode(m)and 1 or T.Sanitize(m)
    scripts+=s;st.Scripts=s;st.Name=assetName;st.Fruit=T.IsCode(m)and 0 or T.StripFruit(m);fruit+=st.Fruit
    if T.IsCode(m)or countParts(m)==0 then st.Route='failed';st.Error='the asset has no parts';pcall(function()m:Destroy()end)
    else
     T.Lock(m);m.Name=name;m:SetAttribute('R151AssetId',id);m:SetAttribute('R151Route',route);m:SetAttribute('AssetName',assetName)
     st.Route=route;st.Parts=countParts(m);m.Parent=f;loaded+=1
    end
   else st.Route='failed';st.Error=err end
  end
  f:SetAttribute('Route'..tostring(id),st.Route)
  if st.Route=='AssetService'or st.Route=='InsertService'then
   print(string.format('[R151 trees] %s "%s": loaded by %s (%d parts, %d scripts and %d fruit removed)',tostring(id),tostring(st.Name),st.Route=='AssetService'and'AssetService:LoadAssetAsync'or'InsertService:LoadAsset',st.Parts or 0,st.Scripts or 0,st.Fruit or 0))
  elseif st.Route=='already there'then print(string.format('[R151 trees] %s: already in ReplicatedStorage.%s',tostring(id),K.TreeFolder))
  else
   -- R157 (owner: Studio's Output showed this as a warning and he called it a bug): a tree model that belongs to someone else cannot be loaded and that is fine - the hub
   -- keeps its part-built studded trees - so it is ONE plain print (not a warn); when the error says "not authorized" it says so plainly.
   local using=manual>0 and'using the trees placed in the folder by hand'or'using the built-in trees'
   if tostring(st.Error):lower():find('not authorized',1,true)then print(string.format('[R151 trees] %s can\'t be loaded (not your asset); %s',tostring(id),using))
   else print(string.format('[R151 trees] %s: not loaded (%s); %s',tostring(id),tostring(st.Error),using))end
  end
 end
 f:SetAttribute('ScriptsRemoved',scripts);f:SetAttribute('FruitRemoved',fruit);f:SetAttribute('Loaded',loaded);f:SetAttribute('Ready',true)
 if scripts>0 then print(string.format('[R151 trees] removed %d script(s) from the tree templates',scripts))end
 if fruit>0 then print(string.format('[R151 trees] removed %d fruit part(s) from the tree templates (the trees are just trees)',fruit))end
 return L.Status
end
-- '/test hubtrees': what the server has, and what each device tier builds from it.
function L.Command(ctx,p,a)
 local f=RS:FindFirstChild(K.TreeFolder)
 local out={}
 if not f then return true,'No ReplicatedStorage.'..K.TreeFolder..' yet: the hub uses its part-built studded trees.'end
 out[#out+1]=string.format('Tree templates: %d loaded by id, %d placed by hand, %d script(s) and %d fruit removed, ready: %s.',f:GetAttribute('Loaded')or 0,f:GetAttribute('Manual')or 0,f:GetAttribute('ScriptsRemoved')or 0,f:GetAttribute('FruitRemoved')or 0,tostring(f:GetAttribute('Ready')==true))
 for _,id in ipairs(K.TreeAssetIds)do local st=L.Status[id]
  out[#out+1]=string.format('  %s: %s%s',tostring(id),tostring(f:GetAttribute('Route'..tostring(id))or'not tried'),st and st.Error and(' ('..st.Error..')')or'')
 end
 local infos,sum=T.Collect(f)
 local parts=T.Describe(infos)
 out[#out+1]='  models: '..(parts~=''and parts or'none')
 for _,b in ipairs(sum.Broken)do out[#out+1]='  skipped: '..b end
 local ok,Art=pcall(require,RS:WaitForChild('HubLifeArt151'))
 if ok and Art.TreeSlots then
  for tier=1,3 do local _,plan=T.Plan(infos,tier,Art.TreeSlots());local _,used=T.Describe(infos,plan);out[#out+1]='  tier '..tier..': '..used end
 end
 for _,i in ipairs(infos)do if i.Model then i.Model:Destroy()end end
 out[#out+1]='On your screen: workspace.HubLife151 attributes TemplateParts / UsedFor / ScriptsRemoved.'
 return true,table.concat(out,'\n')
end
return L
