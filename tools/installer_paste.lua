-- __TAG__ Chest Chase update. Paste the WHOLE script into the Command Bar in Edit mode (Play stopped).
-- It checks every script is the exact version it was built for, saves a backup in ServerStorage, then installs.
-- Undo any time: require(game.ServerStorage.__BACKUP__.Installer)("undo")   Redo: ...("install")
-- Objects this update retires are moved (not deleted) into ServerStorage.__BACKUP__.Retired; undo moves them back.
assert(not game:GetService('RunService'):IsRunning(),'__TAG__ Stop Play first.')
local storage=game:GetService('ServerStorage')
-- @@ENGINE_HELPERS@@
local existing=storage:FindFirstChild('__BACKUP__')
if existing then
 -- Same build pasted again: redo. A different build with the same backup name must never run the old one.
 -- Same build = Build attribute, or an Installer identical to this one (pastes before the attribute never set it).
 local installer=existing:FindFirstChild('Installer')
 local same=existing:GetAttribute('Build')=='__ENGINE_SHA__'or(installer~=nil and installer:IsA('ModuleScript')and sha256(installer.Source)=='__ENGINE_SHA__')
 assert(same,'__TAG__ An older __TAG__ backup is in ServerStorage. Undo it first: require(game.ServerStorage.__BACKUP__.Installer)("undo") then delete ServerStorage.__BACKUP__ and paste this again. Nothing changed.')
 existing:SetAttribute('Build','__ENGINE_SHA__')
 require(existing:WaitForChild('Installer'))('install');return
end
local specs=__SPECS__
local retireList=__RETIRE__
local patches=__PATCHES__
local engineSource=decode(__ENGINE_B64__)
assert(sha256(engineSource)=='__ENGINE_SHA__','__TAG__ The pasted text was damaged while copying. Nothing changed.')
local editor=game:GetService('ScriptEditorService')
local function unique(parent,name)
 local found,count=nil,0
 for _,child in ipairs(parent:GetChildren())do if child.Name==name then found=child;count+=1 end end
 assert(count==1,'__TAG__ Missing or duplicated object: '..name..' in '..parent:GetFullName()..'. Nothing changed.');return found
end
local function resolve(path)local item=game;for name in path:gmatch('[^/]+')do item=unique(item,name)end;return item end
local byPath={};for _,p in ipairs(patches)do byPath[p.Path]=p.Patches end
local backup=Instance.new('Folder');backup.Name='__BACKUP__'
local sources=Instance.new('Folder');sources.Name='Sources';sources.Parent=backup
for i,spec in ipairs(specs)do
 if spec.New then
  -- A script this update adds. It is created parked inside the backup; the installer moves it into place.
  local parentPath,name=spec.Path:match('^(.*)/([^/]+)$');local home=resolve(parentPath)
  assert(home:FindFirstChild(name)==nil,'__TAG__ '..spec.Path..' already exists. Nothing changed.')
  local after=''
  for _,p in ipairs(byPath[spec.Path])do after=after..decode(p[3])end
  assert(#after==spec.AfterBytes and sha256(after)==spec.AfterSHA256,'__TAG__ Patch check failed for '..spec.Path..'. Nothing changed.')
  local entry=Instance.new('Folder');entry.Name=string.format('%02d',i);entry:SetAttribute('Path',spec.Path);entry:SetAttribute('New',true);entry.Parent=sources
  local b=Instance.new('StringValue');b.Name='After';b.Value=after;b.Parent=entry
  local item=Instance.new(spec.Class);item.Name=name;item.Source=after;item.Parent=entry
  local t=Instance.new('ObjectValue');t.Name='Target';t.Value=item;t.Parent=entry
  continue
 end
 local item=resolve(spec.Path)
 assert(item.ClassName==spec.Class,'__TAG__ '..spec.Path..' is a '..item.ClassName..', expected '..spec.Class..'. Nothing changed.')
 local before=editor:GetEditorSource(item)
 assert(item.Source==before,'__TAG__ Close or save unsaved edits in '..spec.Path..' first. Nothing changed.')
 assert(#before==spec.BeforeBytes and sha256(before)==spec.BeforeSHA256,'__TAG__ '..spec.Path..' is not the version this update was built for. Nothing changed.')
 local after=before;local list=byPath[spec.Path]
 table.sort(list,function(a,b)return a[1]>b[1]end)
 for _,p in ipairs(list)do after=after:sub(1,p[1]-1)..decode(p[3])..after:sub(p[1]+p[2])end
 assert(#after==spec.AfterBytes and sha256(after)==spec.AfterSHA256,'__TAG__ Patch check failed for '..spec.Path..'. Nothing changed.')
 local entry=Instance.new('Folder');entry.Name=string.format('%02d',i);entry:SetAttribute('Path',spec.Path);entry.Parent=sources
 local a=Instance.new('StringValue');a.Name='Before';a.Value=before;a.Parent=entry
 local b=Instance.new('StringValue');b.Name='After';b.Value=after;b.Parent=entry
 local t=Instance.new('ObjectValue');t.Name='Target';t.Value=item;t.Parent=entry
end
if #retireList>0 then
 -- Objects to retire are looked up now, before anything changes: a missing one is skipped (reported by the installer),
 -- one name matching two siblings refuses the whole update. The installer moves them; here they are only recorded.
 local retired=Instance.new('Folder');retired.Name='Retired';retired.Parent=backup
 for i,names in ipairs(retireList)do
  local item=findPath(names)
  local entry=Instance.new('Folder');entry.Name=string.format('%02d',i);entry:SetAttribute('Index',i);entry:SetAttribute('Path',display(names));entry.Parent=retired
  if item==nil then entry:SetAttribute('Missing',true)
  else
   assert(item~=storage and not storage:IsDescendantOf(item),'__TAG__ '..display(names)..' contains the backup and cannot be retired. Nothing changed.')
   local target=Instance.new('ObjectValue');target.Name='Target';target.Value=item;target.Parent=entry
   local parked=Instance.new('Folder');parked.Name='Parked';parked.Parent=entry
   -- Every Script/LocalScript inside is remembered with its Disabled state; the installer disables them while parked.
   local list=Instance.new('Folder');list.Name='Scripts';list.Parent=entry
   local scripts=item:IsA('BaseScript')and{item}or{}
   for _,d in ipairs(item:GetDescendants())do if d:IsA('BaseScript')then scripts[#scripts+1]=d end end
   for n,s in ipairs(scripts)do
    local v=Instance.new('ObjectValue');v.Name='S'..n;v.Value=s;v:SetAttribute('Disabled',s.Disabled==true);v.Parent=list
   end
  end
 end
end
local installer=Instance.new('ModuleScript');installer.Name='Installer';installer.Source=engineSource;installer.Parent=backup
backup:SetAttribute('SourceCount',#specs);backup:SetAttribute('RetireCount',#retireList);backup:SetAttribute('Build','__ENGINE_SHA__');backup:SetAttribute('State','Built');backup.Parent=storage
require(installer)('install')
print('__TAG__ Backup: ServerStorage.__BACKUP__   Undo: require(game.ServerStorage.__BACKUP__.Installer)("undo")')
if #retireList>0 then print('__TAG__ Retired objects are parked in ServerStorage.__BACKUP__.Retired; undo puts them back where they were.') end
