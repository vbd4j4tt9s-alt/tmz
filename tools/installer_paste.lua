-- __TAG__ Chest Chase update. Paste the WHOLE script into the Command Bar in Edit mode (Play stopped).
-- It checks every script is the exact version it was built for, saves a backup in ServerStorage, then installs.
-- Undo any time: require(game.ServerStorage.__BACKUP__.Installer)("undo")   Redo: ...("install")
assert(not game:GetService('RunService'):IsRunning(),'__TAG__ Stop Play first.')
local storage=game:GetService('ServerStorage')
local existing=storage:FindFirstChild('__BACKUP__')
if existing then require(existing:WaitForChild('Installer'))('install');return end
-- @@ENGINE_HELPERS@@
local specs=__SPECS__
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
local installer=Instance.new('ModuleScript');installer.Name='Installer';installer.Source=engineSource;installer.Parent=backup
backup:SetAttribute('SourceCount',#specs);backup:SetAttribute('State','Built');backup.Parent=storage
require(installer)('install')
print('__TAG__ Backup: ServerStorage.__BACKUP__   Undo: require(game.ServerStorage.__BACKUP__.Installer)("undo")')
