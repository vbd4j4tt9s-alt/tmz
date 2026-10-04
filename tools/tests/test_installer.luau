--!nocheck
-- Runs the real paste script against mock copies of the live scripts: install, idempotency, undo, redo, refusals.
local R=require('./roblox');local D=require('./inst_bundle');local BACKUP=D.BACKUP
local new=R.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local function world(mutate)
 local game=new('DataModel');game.Name='Game'
 local services={}
 local function service(n)local s=services[n];if not s then s=new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
 game.GetService=function(_,n)return service(n)end
 local running=false
 service('RunService').IsRunning=function()return running end
 local editor=service('ScriptEditorService')
 editor.GetEditorSource=function(_,item)return item.Source end
 editor.UpdateSourceAsync=function(_,item,fn)item.Source=fn(item.Source)end
 service('ChangeHistoryService').SetWaypoint=function()end
 service('ServerStorage')
 local items={}
 for _,s in ipairs(D.Scripts)do
  local parent=game
  local parts=string.split(s.Path,'/')
  for i=1,#parts-1 do parent=parent:FindFirstChild(parts[i])or(function()local f=new(i==1 and parts[i]or'Folder');f.Name=parts[i];f.Parent=parent;return f end)()end
  if not s.New then local item=new(s.Class);item.Name=parts[#parts];item.Source=mutate and mutate(s)or s.Before;item.Parent=parent;items[s.Path]=item end
 end
 -- Objects the update retires (D.Retire, name arrays): built the way the live place has them, scripts with mixed Disabled states.
 -- A name with '/' is ONE instance name; a decoy folder chain (Keycap > Keyboard) next to it must never be touched.
 local retired,decoys={},{}
 local function child(parent,name,class)
  local c=parent:FindFirstChild(name);if c then return c end
  c=new(class or'Folder');c.Name=name;c.Parent=parent;return c
 end
 for i,names in ipairs(D.Retire)do
  local parent=game:FindFirstChild(names[1])or service(names[1])
  for k=2,#names-1 do parent=child(parent,names[k])end
  local leaf=names[#names]
  local class=leaf:find('State$')and'RemoteEvent'or leaf:find('Boot')and'LocalScript'or leaf:find('Server')and'Script'
   or(leaf:find('Core')or leaf:find('Scene')or leaf:find('Client'))and'ModuleScript'or leaf=='Verity'and'Part'or'Folder'
  local item=new(class);item.Name=leaf
  if item:IsA('BaseScript')then item.Disabled=(i%2==0)end
  if class=='Folder'then
   for j=1,3 do
    local sub=new(j==1 and'Model'or'Folder');sub.Name='Sub'..j;sub.Parent=item
    local s=new(j==2 and'LocalScript'or'Script');s.Name='Inner'..j;s.Disabled=(j~=2);s.Parent=sub
   end
  end
  item.Parent=parent;retired[i]=item
  if leaf:find('/',1,true)then
   local d=parent;for _,part in ipairs(string.split(leaf,'/'))do d=child(d,part)end
   decoys[#decoys+1]={Item=d,Parent=d.Parent}
  end
 end
 -- Look scripts up by path each time: added scripts appear and disappear.
 setmetatable(items,{__index=function(_,path)local item=game;for n in string.gmatch(path,'[^/]+')do item=item and item:FindFirstChild(n)end;return item end})
 local env
 local cache={}
 local function req(m)
  if cache[m]==nil then local fn=assert(loadstring(m.Source,'='..m.Name));setfenv(fn,setmetatable({script=m},{__index=env}));cache[m]=fn()end
  return cache[m]
 end
 local printed={}
 env=setmetatable({game=game,Instance=R.Instance,require=req,print=function(...)printed[#printed+1]=table.concat({...},' ')end,task=R.task},{__index=_G})
 local function run(text)local fn=assert(loadstring(text,'=paste'));setfenv(fn,setmetatable({},{__index=env}));return pcall(fn)end
 return {Game=game,Items=items,Run=run,Printed=printed,Storage=service('ServerStorage'),SetRunning=function(v)running=v end,Req=req,Retired=retired,Decoys=decoys}
end
local function all(w,key)
 for _,s in ipairs(D.Scripts)do
  local item=w.Items[s.Path]
  if s.New and key=='Before'then if item~=nil then return false,s.Path end
  elseif not item or item.Source~=s[key]then return false,s.Path end
 end
 return true
end
-- 1) Fresh install.
local w=world();local t0=os.clock();local ok,err=w.Run(D.PASTE);local took=os.clock()-t0
check(ok,'paste runs: '..tostring(err));check(all(w,'After'),'all scripts now match the new sources')
local backup=w.Storage:FindFirstChild(BACKUP);check(backup~=nil,'backup created')
check(backup and backup:GetAttribute('State')=='Installed','state Installed')
check(backup and #backup.Sources:GetChildren()==#D.Scripts,'one backup entry per script')
print(('paste run took %.2fs in the CLI'):format(took))
-- 2) Pasting again is harmless.
ok,err=w.Run(D.PASTE);check(ok,'second paste ok: '..tostring(err));check(all(w,'After'),'still installed')
-- 3) Undo restores the exact originals; redo re-applies.
local installer=w.Req(backup.Installer)
ok,err=pcall(installer,'undo');check(ok,'undo ok: '..tostring(err));check(all(w,'Before'),'undo restores originals byte-for-byte');check(backup:GetAttribute('State')=='Undone','state Undone')
ok,err=pcall(installer,'undo');check(ok,'double undo ok')
ok,err=pcall(installer,'install');check(ok,'redo ok: '..tostring(err));check(all(w,'After'),'redo re-applies')
-- 4) Later hand edits block undo without changing anything.
local firstSpec=D.Scripts[#D.Scripts] -- an added script when the update has one
local first=w.Items[firstSpec.Path];first.Source=first.Source..'\n-- my edit'
ok,err=pcall(installer,'undo');check(not ok and tostring(err):find('later edits',1,true)~=nil,'undo refuses after hand edits')
for _,s in ipairs(D.Scripts)do if s~=firstSpec then check(w.Items[s.Path]~=nil and w.Items[s.Path].Source==s.After,'other scripts untouched by refused undo: '..s.Path)end end
-- 5) Play running refuses.
w.SetRunning(true);ok,err=pcall(installer,'undo');check(not ok and tostring(err):find('Stop Play',1,true)~=nil,'refuses during Play');w.SetRunning(false)
-- 6) A place whose script differs from the expected version: refuses, no changes, no backup.
local victim;local modified=0;for _,s in ipairs(D.Scripts)do if not s.New then victim=s;modified+=1 end end
local w2=world(function(s)if s==victim then return s.Before..' ' end end)
ok,err=w2.Run(D.PASTE);check(not ok and tostring(err):find('not the version',1,true)~=nil,'refuses unexpected version: '..tostring(err))
check(w2.Storage:FindFirstChild(BACKUP)==nil,'no backup left behind on refusal')
local unchanged=true;for i,s in ipairs(D.Scripts)do if s~=victim and not s.New and w2.Items[s.Path].Source~=s.Before then unchanged=false end;if s.New and w2.Items[s.Path]~=nil then unchanged=false end end
check(unchanged,'nothing written on refusal')
-- 6b) A backup left by a DIFFERENT build of the same release: refuse, never run the old installer.
local w4=world()
do local f=R.new('Folder');f.Name=BACKUP;f:SetAttribute('Build','an-older-build');f.Parent=w4.Storage end
ok,err=w4.Run(D.PASTE);check(not ok and tostring(err):find('older',1,true)~=nil and tostring(err):find('undo',1,true)~=nil,'older backup refused with undo steps: '..tostring(err))
check(all(w4,'Before'),'nothing written when an older backup exists')
-- 6c) This same build's backup made by a paste script that never set Build (undone since): recognised by its Installer, re-installed.
local w5=world();ok,err=w5.Run(D.PASTE);check(ok,'6c setup install: '..tostring(err))
local b5=w5.Storage:FindFirstChild(BACKUP);local sha=b5:GetAttribute('Build');b5:SetAttribute('Build',nil)
ok,err=pcall(w5.Req(b5.Installer),'undo');check(ok and all(w5,'Before'),'6c setup undo: '..tostring(err))
ok,err=w5.Run(D.PASTE);check(ok,'same build without Build attribute is re-used, not refused: '..tostring(err))
check(all(w5,'After')and b5:GetAttribute('State')=='Installed','...and installs from it')
check(b5:GetAttribute('Build')==sha and #w5.Storage:GetChildren()==1,'...stamps Build, no second backup')
-- 7) A write failure midway rolls everything back.
local w3=world();local writes=0
local editor=w3.Game:GetService('ScriptEditorService');local real=editor.UpdateSourceAsync
editor.UpdateSourceAsync=function(self,item,fn)writes+=1;if writes==math.min(3,modified)then error('simulated write failure')end;return real(self,item,fn)end
ok,err=w3.Run(D.PASTE);check(not ok and tostring(err):find('rolled back',1,true)~=nil,'failure reports rollback: '..tostring(err))
check(all(w3,'Before'),'rollback restored every script')
-- 8) Added scripts: a name clash at the destination refuses without changes.
local hasNew=false;for _,s in ipairs(D.Scripts)do if s.New then hasNew=true end end
if hasNew then
 local w4=world()
 for _,s in ipairs(D.Scripts)do if s.New then local parts=string.split(s.Path,'/');local parent=w4.Game;for i=1,#parts-1 do parent=parent:FindFirstChild(parts[i])end;local clash=R.new('Folder');clash.Name=parts[#parts];clash.Parent=parent;break end end
 ok,err=w4.Run(D.PASTE);check(not ok and tostring(err):find('already exists',1,true)~=nil,'name clash refused: '..tostring(err))
 check(w4.Storage:FindFirstChild(BACKUP)==nil,'no backup after clash')
 print('added-script paths covered')
end
-- 9) Retired objects: moved into the backup and back, all-or-nothing. Needs the retire list the installer was built with.
if #D.Retire<3 then print('retire checks skipped: no retire list in the bundle (pass the --retire file to installer_testdata.py)')
else
 local function show(names)local out={};for i,n in ipairs(names)do out[#out+1]=n:match('^[%a_][%w_]*$')and(i>1 and'.'..n or n)or('["'..n..'"]')end;return table.concat(out)end
 local function scriptsOf(item)local list=item:IsA('BaseScript')and{item}or{};for _,d in ipairs(item:GetDescendants())do if d:IsA('BaseScript')then list[#list+1]=d end end;return list end
 -- What each retired object looked like before the install.
 local function snapshot(w)
  local snap={}
  for i,item in pairs(w.Retired)do
   local flags={};for _,s in ipairs(scriptsOf(item))do flags[s]=s.Disabled==true end
   snap[i]={Item=item,Parent=item.Parent,Name=item.Name,Flags=flags,Children=#item:GetDescendants()}
  end
  return snap
 end
 local function restored(snap)
  for i,e in pairs(snap)do
   local it=e.Item
   if it.Parent~=e.Parent or it.Name~=e.Name or #it:GetDescendants()~=e.Children then return false,i end
   for s,flag in pairs(e.Flags)do if (s.Disabled==true)~=flag then return false,i end end
  end
  return true
 end
 local function parked(snap,backup)
  for i,e in pairs(snap)do
   local it=e.Item;local p=it.Parent
   if not(p and p.Name=='Parked'and p.Parent and p.Parent.Parent==backup:FindFirstChild('Retired'))or it.Name~=e.Name then return false,i end
   for s in pairs(e.Flags)do if s.Disabled~=true then return false,i end end
   for _,c in ipairs(e.Parent:GetChildren())do if c==it then return false,i end end
  end
  return true
 end
 local function parkedEmpty(backup)for _,e in ipairs(backup.Retired:GetChildren())do if e:FindFirstChild('Parked')and #e.Parked:GetChildren()>0 then return false end end;return true end
 local function decoysIntact(w)for _,d in ipairs(w.Decoys)do if d.Item.Parent~=d.Parent then return false end end;return true end
 local function failParent(pred)
  local real=R.instMeta.__newindex
  R.instMeta.__newindex=function(o,k,v)if k=='Parent'and pred(o,v)then error('simulated move failure')end;return real(o,k,v)end
  return function()R.instMeta.__newindex=real end
 end
 local function printed(w)return table.concat(w.Printed,'\n')end
 local slash;for i,names in ipairs(D.Retire)do for _,n in ipairs(names)do if n:find('/',1,true)then slash=i end end end
 check(slash~=nil and #D.Retire>0,'retire list has a name containing a slash')

 -- 9a) Install retires everything; undo / redo / undo round trip.
 local rw=world();local snap=snapshot(rw);local sawTrue,sawFalse=false,false
 for _,e in pairs(snap)do for _,flag in pairs(e.Flags)do if flag then sawTrue=true else sawFalse=true end end end
 check(sawTrue and sawFalse and #rw.Decoys>0,'retire test data has Disabled=true and false scripts and a slash decoy')
 ok,err=rw.Run(D.PASTE);check(ok,'retire: paste runs: '..tostring(err))
 local rb=rw.Storage:FindFirstChild(BACKUP)
 check(rb~=nil and parked(snap,rb),'retire: every object is parked in the backup with its scripts Disabled')
 check(all(rw,'After'),'retire: scripts are patched in the same install')
 check(rb and #rb.Retired:GetChildren()==#D.Retire and rb:GetAttribute('RetireCount')==#D.Retire,'retire: one backup entry per path')
 check(decoysIntact(rw),'retire: a name with a slash retires that one object, not Keycap > Keyboard')
 for i,names in ipairs(D.Retire)do check(printed(rw):find('Retired '..show(names)..' (',1,true)~=nil,'retire: prints Retired '..show(names))end
 check(rb and rb:GetAttribute('State')=='Installed','retire: state Installed')
 local rinst=rw.Req(rb.Installer)
 ok,err=rw.Run(D.PASTE);check(ok and parked(snap,rb),'retire: pasting again changes nothing')
 ok,err=pcall(rinst,'undo');check(ok,'retire: undo ok: '..tostring(err))
 check(restored(snap),'retire: undo restores every object to its exact parent, name, children and Disabled state')
 check(all(rw,'Before')and parkedEmpty(rb),'retire: undo restores scripts and empties the backup')
 check(decoysIntact(rw),'retire: decoys untouched by undo')
 check(printed(rw):find('Restored '..show(D.Retire[slash])..' (',1,true)~=nil,'retire: undo prints what it restored')
 ok,err=pcall(rinst,'undo');check(ok and restored(snap),'retire: double undo ok')
 ok,err=pcall(rinst,'install');check(ok and parked(snap,rb)and all(rw,'After'),'retire: redo parks them again: '..tostring(err))
 ok,err=pcall(rinst,'undo');check(ok and restored(snap)and all(rw,'Before'),'retire: second undo restores again: '..tostring(err))
 -- Play running refuses without moving anything.
 rw.SetRunning(true);ok,err=pcall(rinst,'install');check(not ok and restored(snap)and parkedEmpty(rb),'retire: refuses during Play');rw.SetRunning(false)

 -- 9b) A missing object is skipped and reported; the rest is retired and restored.
 local mw=world();local goneIndex=2;local gone=mw.Retired[goneIndex];gone.Parent=nil;mw.Retired[goneIndex]=nil
 local msnap=snapshot(mw)
 ok,err=mw.Run(D.PASTE);check(ok,'retire: paste with a missing object runs: '..tostring(err))
 local mb=mw.Storage:FindFirstChild(BACKUP)
 check(mb and parked(msnap,mb)and all(mw,'After'),'retire: the objects that exist are retired')
 check(printed(mw):find('Skipped '..show(D.Retire[goneIndex])..' (not found',1,true)~=nil,'retire: missing object reported as skipped')
 check(gone.Parent==nil and #mb.Retired:GetChildren()==#D.Retire,'retire: the missing one is not recreated')
 local minst=mw.Req(mb.Installer)
 ok,err=pcall(minst,'undo');check(ok and restored(msnap)and all(mw,'Before')and gone.Parent==nil,'retire: undo with a skipped object: '..tostring(err))
 ok,err=pcall(minst,'install');check(ok and parked(msnap,mb),'retire: redo with a skipped object: '..tostring(err))
 -- an object that vanished from the backup itself (deleted while parked) is skipped on undo, the others still come back
 local entry=mb.Retired:FindFirstChild('03');local lost=entry and entry.Target.Value
 if entry then entry.Target.Value=nil;msnap[3]=nil end
 ok,err=pcall(minst,'undo');check(ok and restored(msnap)and all(mw,'Before'),'retire: undo skips an object deleted from the backup: '..tostring(err))
 check(printed(mw):find('Skipped '..show(D.Retire[3])..' (deleted',1,true)~=nil,'retire: ...and says so')
 -- nothing exists at all
 local nw=world();for _,item in pairs(nw.Retired)do item.Parent=nil end
 ok,err=nw.Run(D.PASTE);check(ok and all(nw,'After'),'retire: every object missing still installs the scripts: '..tostring(err))
 local skippedCount=0;for _ in printed(nw):gmatch('Skipped ')do skippedCount+=1 end
 check(skippedCount==#D.Retire,'retire: every missing object reported ('..skippedCount..')')

 -- 9c) Two siblings with the same name: refused before anything changes.
 for _,k in ipairs({1,math.min(5,#D.Retire)})do
  local aw=world();local asnap=snapshot(aw)
  local twin=R.new(aw.Retired[k].ClassName);twin.Name=aw.Retired[k].Name;twin.Parent=aw.Retired[k].Parent
  ok,err=aw.Run(D.PASTE)
  check(not ok and tostring(err):find('Ambiguous',1,true)~=nil and tostring(err):find('Nothing changed',1,true)~=nil,'retire: ambiguous '..show(D.Retire[k])..' refused: '..tostring(err))
  check(aw.Storage:FindFirstChild(BACKUP)==nil,'retire: no backup after an ambiguous path')
  check(restored(asnap)and twin.Parent==asnap[k].Parent and all(aw,'Before'),'retire: nothing moved or written after an ambiguous path')
 end
 -- ...also when the second sibling shows up before a redo
 do
  local ow=world();local osnap=snapshot(ow);ok,err=ow.Run(D.PASTE);local ob=ow.Storage:FindFirstChild(BACKUP);local oi=ow.Req(ob.Installer)
  ok,err=pcall(oi,'undo');check(ok and restored(osnap),'retire: ambiguity setup undo')
  local twin=R.new(ow.Retired[2].ClassName);twin.Name=ow.Retired[2].Name;twin.Parent=ow.Retired[2].Parent
  ok,err=pcall(oi,'install');check(not ok and tostring(err):find('Ambiguous',1,true)~=nil,'retire: redo refused when a twin appeared: '..tostring(err))
  check(restored(osnap)and all(ow,'Before')and parkedEmpty(ob),'retire: nothing moved by the refused redo')
 end

 -- 9d) Failure in the middle of the install: no object stays moved, no script stays disabled.
 local fw=world();local fsnap=snapshot(fw);local victim=fw.Retired[math.min(5,#D.Retire)]
 local heal=failParent(function(o,v)return o==victim and v~=nil and v.Name=='Parked'end)
 ok,err=fw.Run(D.PASTE);heal()
 check(not ok and tostring(err):find('rolled back',1,true)~=nil,'retire: failed move reports rollback: '..tostring(err))
 local fb=fw.Storage:FindFirstChild(BACKUP)
 check(restored(fsnap)and parkedEmpty(fb)and all(fw,'Before')and decoysIntact(fw),'retire: failed move leaves every object, Disabled state and script as before')
 check(fb:GetAttribute('State')=='RolledBack','retire: state RolledBack')
 ok,err=fw.Run(D.PASTE);check(ok and parked(fsnap,fb)and all(fw,'After'),'retire: pasting again after the failure installs everything: '..tostring(err))
 -- the failure comes after every object was moved (a script write fails): they all come back
 local sw=world();local ssnap=snapshot(sw)
 local sEditor=sw.Game:GetService('ScriptEditorService');local sReal=sEditor.UpdateSourceAsync
 sEditor.UpdateSourceAsync=function(self,item,fn)error('simulated write failure')end
 ok,err=sw.Run(D.PASTE);sEditor.UpdateSourceAsync=sReal
 local sb=sw.Storage:FindFirstChild(BACKUP)
 check(not ok and tostring(err):find('rolled back',1,true)~=nil,'retire: failed write after the moves reports rollback')
 check(restored(ssnap)and parkedEmpty(sb)and all(sw,'Before'),'retire: failed write moves every object back and re-enables its scripts')
 -- a failure while undoing: everything stays installed
 local uw=world();local usnap=snapshot(uw);uw.Run(D.PASTE);local ub=uw.Storage:FindFirstChild(BACKUP);local ui=uw.Req(ub.Installer)
 local uvictim=uw.Retired[math.min(4,#D.Retire)]
 heal=failParent(function(o,v)return o==uvictim and v~=nil and v.Name~='Parked'end)
 ok,err=pcall(ui,'undo');heal()
 check(not ok and tostring(err):find('rolled back',1,true)~=nil,'retire: failed undo reports rollback: '..tostring(err))
 check(parked(usnap,ub)and all(uw,'After'),'retire: failed undo leaves every object parked and every script as installed')
 ok,err=pcall(ui,'undo');check(ok and restored(usnap)and all(uw,'Before'),'retire: undo works once the failure is gone: '..tostring(err))

 -- 9e) Undo refuses, changing nothing, when the place no longer matches.
 local cw=world();local csnap=snapshot(cw);cw.Run(D.PASTE);local cb=cw.Storage:FindFirstChild(BACKUP);local ci=cw.Req(cb.Installer)
 local cv=cw.Retired[3];local clash=R.new('Folder');clash.Name=cv.Name;clash.Parent=csnap[3].Parent
 ok,err=pcall(ci,'undo');check(not ok and tostring(err):find('already exists',1,true)~=nil,'retire: undo refused when the name is taken: '..tostring(err))
 check(parked(csnap,cb)and all(cw,'After'),'retire: ...and nothing moved')
 clash.Parent=nil
 local hand=cw.Retired[4];hand.Parent=cw.Game:GetService('Workspace')
 ok,err=pcall(ci,'undo');check(not ok and tostring(err):find('moved',1,true)~=nil,'retire: undo refused when a parked object was moved by hand: '..tostring(err))
 check(all(cw,'After')and cv.Parent.Name=='Parked','retire: ...and nothing else moved')
 hand.Parent=cb.Retired:FindFirstChild('04').Parked
 ok,err=pcall(ci,'undo');check(ok and restored(csnap)and all(cw,'Before'),'retire: undo works once it matches again: '..tostring(err))
end
-- 10) Roblox refuses a StringValue.Value of 200,000 bytes or more, so the backup stores sources of 100,000+ bytes as Folders of chunks.
do
 local CH=100000
 local sv=R.new('StringValue')
 check(pcall(function()sv.Value=string.rep('x',199999)end),'chunks: the mock accepts a 199,999-byte StringValue')
 local bigOk,bigErr=pcall(function()sv.Value=string.rep('x',200000)end)
 check(not bigOk and tostring(bigErr):find('Unable to assign property Value. Provided string length (200000) is greater than or equal to max length (200000)',1,true)~=nil,'chunks: the mock refuses 200,000 bytes like Roblox: '..tostring(bigErr))
 local scr=R.new('ModuleScript');check(pcall(function()scr.Source=string.rep('x',300000)end),'chunks: the mock does not limit Script.Source')
 local function specOf(path)for _,s in ipairs(D.Scripts)do if s.Path==path then return s end end end
 -- Is `node` the stored form of `text`? (a StringValue below CH, else a Folder of valid UTF-8 chunks that join back exactly)
 local function holds(node,text)
  if node==nil then return false,'missing'end
  if #text<CH then return node:IsA('StringValue')and node.Value==text,'small text must stay one StringValue'end
  if not node:IsA('Folder')then return false,'large text must be a Folder'end
  local n=node:GetAttribute('Chunks');local kids=node:GetChildren()
  if node:GetAttribute('Bytes')~=#text or n~=#kids or n<2 then return false,'Bytes/Chunks attributes'end
  local valid=utf8.len(text)~=nil;local parts={}
  for i=1,n do
   local part=node:FindFirstChild(tostring(i))
   if not(part and part:IsA('StringValue'))then return false,'chunk '..i..' missing'end
   local v=part.Value;local first=string.byte(v,1)
   if #v==0 or #v>=CH then return false,'chunk '..i..' has '..#v..' bytes'end
   if first>=128 and first<192 then return false,'chunk '..i..' starts inside a character'end
   if valid and utf8.len(v)==nil then return false,'chunk '..i..' is not valid UTF-8'end
   parts[i]=v
  end
  return table.concat(parts)==text,'chunks do not join back to the source'
 end
 local cw=world();ok,err=cw.Run(D.PASTE);check(ok,'chunks: paste runs: '..tostring(err))
 local cb=cw.Storage:FindFirstChild(BACKUP);local big,small,biggest,biggestNew=0,0,nil,nil
 for _,entry in ipairs(cb.Sources:GetChildren())do
  local s=specOf(entry:GetAttribute('Path'))
  for _,key in ipairs({'Before','After'})do
   local text=s[key]
   if text==nil then check(entry:FindFirstChild(key)==nil,'chunks: an added script has no '..key..': '..s.Path)
   else
    local good,why=holds(entry:FindFirstChild(key),text);check(good,'chunks: '..s.Path..' '..key..' is stored correctly: '..tostring(why))
    if #text>=CH then big+=1 else small+=1 end
    -- the largest changed script (its Before) and the largest added one, for the damage checks below
    if #text>=CH and key=='Before'and(not biggest or #text>#specOf(biggest:GetAttribute('Path')).Before)then biggest=entry end
    if #text>=CH and s.New and(not biggestNew or #text>#specOf(biggestNew:GetAttribute('Path')).After)then biggestNew=entry end
   end
  end
 end
 for _,d in ipairs(cb:GetDescendants())do if d:IsA('StringValue')then check(#d.Value<CH,'chunks: no StringValue holds '..#d.Value..' bytes: '..d:GetFullName())end end
 if big==0 then print('chunk damage checks skipped: no source of '..CH..' bytes or more in the bundle (use tools/tests/chunk_fixture.py)')
 else
  print(('chunked sources: %d large texts in chunks, %d small ones as plain StringValues'):format(big,small))
  local inst=cw.Req(cb.Installer)
  -- A damaged backup is refused before anything is written: every script keeps its current version.
  local function refused(label,mode)
   ok,err=pcall(inst,mode);check(not ok and tostring(err):find('Damaged source backup',1,true)~=nil,'chunks: '..label..' refused: '..tostring(err))
   check(all(cw,mode=='undo'and'After'or'Before')and cb:GetAttribute('State')==(mode=='undo'and'Installed'or'Undone'),'chunks: '..label..' changed nothing')
  end
  local function damage(entry,key,mode)
   local f=entry:FindFirstChild(key);local who=entry:GetAttribute('Path')..' '..key..' ('..mode..')'
   if f:IsA('Folder')then
    local c=f:FindFirstChild('2');local old=c.Value;local n=f:GetAttribute('Chunks');local bytes=f:GetAttribute('Bytes');local extra
    local function drop()if extra then extra.Parent=nil;extra=nil end end
    local function add(class,name)extra=R.new(class);extra.Name=name;extra.Parent=f end
    local steps={
     {'edited chunk',function()c.Value=old:sub(1,9)..(old:sub(10,10)=='x'and'y'or'x')..old:sub(11)end,function()c.Value=old end},
     {'shortened chunk',function()c.Value=old:sub(1,-2)end,function()c.Value=old end},
     {'missing chunk',function()c.Parent=nil end,function()c.Parent=f end},
     {'renamed chunk',function()c.Name='9'end,function()c.Name='2'end},
     {'duplicated chunk',function()extra=c:Clone();extra.Parent=f end,drop},
     {'chunk replaced by a Folder',function()c.Parent=nil;add('Folder','2')end,function()drop();c.Parent=f end},
     {'extra child',function()add('StringValue','x')end,drop},
     {'wrong Chunks attribute',function()f:SetAttribute('Chunks',n+1)end,function()f:SetAttribute('Chunks',n)end},
     {'wrong Bytes attribute',function()f:SetAttribute('Bytes',bytes+1)end,function()f:SetAttribute('Bytes',bytes)end},
     {'missing '..key,function()f.Parent=nil end,function()f.Parent=entry end},
    }
    for _,step in ipairs(steps)do step[2]();refused(who..': '..step[1],mode);step[3]()end
   end
   -- repaired: the backup is whole again
   return pcall(inst,mode)
  end
  for _,key in ipairs({'After','Before'})do
   ok,err=damage(biggest,key,'undo');check(ok and all(cw,'Before'),'chunks: undo works once '..key..' is repaired: '..tostring(err))
   ok,err=pcall(inst,'install');check(ok and all(cw,'After'),'chunks: redo is byte-exact: '..tostring(err))
  end
  -- ...the same when it is the redo that meets the damage, and when the damage is met by pasting again
  ok,err=pcall(inst,'undo');check(ok and all(cw,'Before'),'chunks: undo before the redo checks: '..tostring(err))
  ok,err=damage(biggest,'Before','install');check(ok and all(cw,'After'),'chunks: redo works once Before is repaired: '..tostring(err))
  local f=biggest:FindFirstChild('After');local c=f:IsA('Folder')and f:FindFirstChild('2')
  if c then
   local old=c.Value;c.Value=old:sub(1,-2);ok,err=cw.Run(D.PASTE)
   check(not ok and tostring(err):find('Damaged source backup',1,true)~=nil,'chunks: pasting again over a damaged backup is refused: '..tostring(err))
   check(all(cw,'After'),'chunks: ...and changed nothing');c.Value=old
  end
  -- a big added script
  if biggestNew then
   ok,err=damage(biggestNew,'After','undo');check(ok and all(cw,'Before'),'chunks: undo works once the added script backup is repaired: '..tostring(err))
   ok,err=pcall(inst,'install');check(ok and all(cw,'After'),'chunks: redo after the added script repair: '..tostring(err))
  end
 end
end
print(('%d checks, %d failures'):format(checks,fails))
