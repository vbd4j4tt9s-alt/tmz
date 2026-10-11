-- ASCII-only transport keeps embedded sources independent of pasted Unicode and indentation.
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local values={};for i=1,#alphabet do values[alphabet:sub(i,i)]=i-1 end
local function decode(text)
    local out={}
    for i=1,#text,4 do
        local a,b,c,d=text:sub(i,i),text:sub(i+1,i+1),text:sub(i+2,i+2),text:sub(i+3,i+3)
        local n=assert(values[a])*262144+assert(values[b])*4096+(values[c] or 0)*64+(values[d] or 0)
        out[#out+1]=string.char(math.floor(n/65536)%256)
        if c~='=' then out[#out+1]=string.char(math.floor(n/256)%256) end
        if d~='=' then out[#out+1]=string.char(n%256) end
    end
    return table.concat(out)
end
local function sha256(text)
    local band,bxor,bnot,rshift,ror=bit32.band,bit32.bxor,bit32.bnot,bit32.rshift,bit32.rrotate
    local k={0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
    local h={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    local bits=#text*8
    text=text..string.char(128)..string.rep(string.char(0),(55-#text)%64)
    local length={};for i=7,0,-1 do length[#length+1]=string.char(math.floor(bits/2^(8*i))%256) end
    text=text..table.concat(length)
    for offset=1,#text,64 do
        local w={}
        for i=0,15 do local a,b,c,d=text:byte(offset+i*4,offset+i*4+3);w[i]=a*16777216+b*65536+c*256+d end
        for i=16,63 do
            local a,b=w[i-15],w[i-2]
            w[i]=(w[i-16]+bxor(ror(a,7),ror(a,18),rshift(a,3))+w[i-7]+bxor(ror(b,17),ror(b,19),rshift(b,10)))%4294967296
        end
        local a,b,c,d,e,f,g,j=table.unpack(h)
        for i=0,63 do
            local t1=(j+bxor(ror(e,6),ror(e,11),ror(e,25))+bxor(band(e,f),band(bnot(e),g))+k[i+1]+w[i])%4294967296
            local t2=(bxor(ror(a,2),ror(a,13),ror(a,22))+bxor(band(a,b),band(a,c),band(b,c)))%4294967296
            j=g;g=f;f=e;e=(d+t1)%4294967296;d=c;c=b;b=a;a=(t1+t2)%4294967296
        end
        for i,v in ipairs({a,b,c,d,e,f,g,j})do h[i]=(h[i]+v)%4294967296 end
    end
    local out={};for _,v in ipairs(h)do out[#out+1]=string.format('%08x',v)end;return table.concat(out)
end
-- Retire paths are arrays of names (a name may contain '/'), never '/'-joined strings.
local function display(names)
    local out={}
    for i,name in ipairs(names)do out[#out+1]=name:match('^[%a_][%w_]*$')and(i>1 and'.'..name or name)or('["'..name..'"]')end
    return table.concat(out)
end
-- Walks the names down from game. nil when something on the way is missing; refuses when a name matches several siblings.
local function findPath(names)
    local item=game
    for _,name in ipairs(names)do
        local found,count=nil,0
        for _,child in ipairs(item:GetChildren())do if child.Name==name then found=child;count+=1 end end
        assert(count<2,'__TAG__ Ambiguous: '..count..' objects are named "'..name..'" in '..item:GetFullName()..' (looking for '..display(names)..'). Nothing changed.')
        if count==0 then return nil end
        item=found
    end
    return item
end
-- A StringValue.Value must be shorter than 200,000 bytes, so text of CHUNK bytes or more is stored as a Folder of numbered StringValues
-- ('1'..'n', each shorter than CHUNK, cut only at UTF-8 character boundaries). Shorter text stays one StringValue.
local CHUNK=100000
local function storeText(parent,name,text)
    if #text<CHUNK then local v=Instance.new('StringValue');v.Name=name;v.Value=text;v.Parent=parent;return end
    local folder=Instance.new('Folder');folder.Name=name;local n,i=0,1
    while i<=#text do
        local j=math.min(i+CHUNK-2,#text)
        while j>i and j<#text and text:byte(j+1)>=128 and text:byte(j+1)<192 do j-=1 end
        n+=1;local v=Instance.new('StringValue');v.Name=tostring(n);v.Value=text:sub(i,j);v.Parent=folder;i=j+1
    end
    folder:SetAttribute('Bytes',#text);folder:SetAttribute('Chunks',n);folder.Parent=parent
end
-- The text storeText saved under `name` in entry; refuses a missing, duplicated, incomplete or resized backup.
local function loadText(entry,name)
    local found,count=nil,0
    for _,child in ipairs(entry:GetChildren())do if child.Name==name then found=child;count+=1 end end
    local bad='__TAG__ Damaged source backup: '..name..' in '..entry:GetFullName()
    assert(count==1,bad)
    if found:IsA('StringValue')then return found.Value end
    local kids=found:GetChildren();local n=found:GetAttribute('Chunks')
    assert(found:IsA('Folder')and n==#kids,bad)
    local parts={}
    for i=1,n do
        local part,c=nil,0
        for _,k in ipairs(kids)do if k.Name==tostring(i)then part=k;c+=1 end end
        assert(c==1 and part:IsA('StringValue'),bad);parts[i]=part.Value
    end
    local text=table.concat(parts);assert(#text==found:GetAttribute('Bytes'),bad);return text
end

-- @@SPLIT@@
local sourceSpecs=__SPECS__
local retireList=__RETIRE__
-- Local source-only transaction; no map, asset, ID or gameplay-data edits.
local package=script.Parent
local function unique(parent,name)
 local found,count=nil,0
 for _,child in ipairs(parent:GetChildren())do if child.Name==name then found=child;count+=1 end end
 assert(count==1,'__TAG__ Missing or duplicated object: '..name);return found
end
local function resolve(path)
 local item=game;for name in path:gmatch('[^/]+')do item=unique(item,name)end;return item
end
return function(mode)
 assert(not game:GetService('RunService'):IsRunning(),'__TAG__ Stop Play first.')
 assert(mode=='install'or mode=='undo','Use install or undo.')
 local editor=game:GetService('ScriptEditorService')
 -- R154b: a script open in a tab can take a moment to copy the editor's text into Source after a write; wait up to 3 s for it.
 local function synced(item)
  for _=1,60 do if item.Source==editor:GetEditorSource(item)then return true end;task.wait(.05)end
  return item.Source==editor:GetEditorSource(item)
 end
 local function read(item)
  assert(synced(item),'__TAG__ Unsaved editor changes (close its script tab): '..item:GetFullName());return editor:GetEditorSource(item)
 end
 local function write(item,before,after)
  editor:UpdateSourceAsync(item,function(current)
   assert(current==before,'__TAG__ Script changed during write: '..item:GetFullName());return after
  end)
  assert(read(item)==after,'__TAG__ Write did not persist: '..item:GetFullName())
 end
 local folder=unique(package,'Sources');local sources={};local specs={};local seen={};local skipped={}
 for _,spec in ipairs(sourceSpecs)do specs[spec.Path]=spec end
 assert(#folder:GetChildren()==#sourceSpecs and package:GetAttribute('SourceCount')==#sourceSpecs,'__TAG__ Incomplete backup.')
 -- Retired objects: installed = parked in the backup (Retired/NN/Parked), undone = back at their original parent.
 -- Entries come first so they are moved first and, on a failure, put back last.
 if #retireList>0 then
  local rfolder=unique(package,'Retired');local seenIndex={}
  assert(#rfolder:GetChildren()==#retireList and package:GetAttribute('RetireCount')==#retireList,'__TAG__ Incomplete backup (retired objects).')
  for _,entry in ipairs(rfolder:GetChildren())do
   local index=entry:GetAttribute('Index');local names=retireList[index]
   assert(names and not seenIndex[index],'__TAG__ Invalid or duplicated backup entry (retired objects).');seenIndex[index]=true
   if entry:GetAttribute('Missing')then skipped[#skipped+1]={Names=names,Why='not found when the backup was made'}
   else
    local target=unique(entry,'Target');local parked=unique(entry,'Parked');local list=unique(entry,'Scripts')
    assert(target:IsA('ObjectValue')and parked:IsA('Folder')and list:IsA('Folder'),'__TAG__ Damaged retire backup: '..display(names))
    if target.Value==nil then skipped[#skipped+1]={Names=names,Why='deleted since the backup was made'}
    else
     local c={Retire=true,Item=target.Value,Entry=entry,Parked=parked,Names=names,Name=names[#names],ParentNames=table.move(names,1,#names-1,1,{}),Scripts={}}
     for _,v in ipairs(list:GetChildren())do if v.Value~=nil then c.Scripts[#c.Scripts+1]={Item=v.Value,Disabled=v:GetAttribute('Disabled')==true}end end
     sources[#sources+1]=c
    end
   end
  end
 end
 for _,entry in ipairs(folder:GetChildren())do
  local path=entry:GetAttribute('Path');local spec=specs[path]
  assert(spec and not seen[path],'__TAG__ Invalid or duplicated backup entry.');seen[path]=true
  local target=unique(entry,'Target');local b=loadText(entry,'After')
  assert(target:IsA('ObjectValue')and #b==spec.AfterBytes and sha256(b)==spec.AfterSHA256,'__TAG__ Damaged source backup: '..path)
  if spec.New then
   -- A script this update adds: installed = in place, undone = parked inside this backup entry.
   local item=target.Value;local parentPath,name=path:match('^(.*)/([^/]+)$')
   assert(item and item.ClassName==spec.Class and item.Name==name,'__TAG__ Added script object was replaced: '..path)
   sources[#sources+1]={New=true,Item=item,Entry=entry,Home=resolve(parentPath),Name=name,After=b}
  else
   local item=resolve(path)
   assert(item.ClassName==spec.Class and target.Value==item,'__TAG__ Script object was replaced: '..path)
   local a=loadText(entry,'Before')
   assert(#a==spec.BeforeBytes and sha256(a)==spec.BeforeSHA256,'__TAG__ Damaged source backup: '..path)
   sources[#sources+1]={Item=item,Before=a,After=b}
  end
 end
 local from,to=mode=='install'and'Before'or'After',mode=='install'and'After'or'Before'
 -- Added scripts: 'Before' means parked in the backup, 'After' means in place. Their source never changes.
 -- Retired objects: 'Before' = at the original parent under the original name, 'After' = parked in the backup.
 local function home(c)
  local parent=findPath(c.ParentNames)
  assert(parent~=nil,'__TAG__ The original parent of '..display(c.Names)..' no longer exists; nothing changed.')
  return parent
 end
 local function destination(c)
  local parent=home(c)
  for _,other in ipairs(parent:GetChildren())do assert(other==c.Item or other.Name~=c.Name,'__TAG__ Something named '..c.Name..' already exists in '..parent:GetFullName()..'; nothing changed.')end
  return parent
 end
 local function state(c)
  if c.Retire then
   if c.Item.Parent==c.Parked then return'After'end
   local parent=home(c);local same=0
   for _,other in ipairs(parent:GetChildren())do if other.Name==c.Name then same+=1 end end
   if c.Item.Parent==parent and c.Item.Name==c.Name then
    assert(same==1,'__TAG__ Ambiguous: '..same..' objects are named '..c.Name..' in '..parent:GetFullName()..'; nothing changed.')
    return'Before'
   end
   error('__TAG__ Retired object was moved or renamed; nothing changed: '..display(c.Names))
  end
  if c.New then
   assert(read(c.Item)==c.After,'__TAG__ Added script has later edits; nothing changed: '..c.Item:GetFullName())
   if c.Item.Parent==c.Home then return'After'elseif c.Item.Parent==c.Entry then return'Before'end
   error('__TAG__ Added script was moved; nothing changed: '..c.Item:GetFullName())
  end
  local current=read(c.Item)
  if current==c.Before then return'Before'elseif current==c.After then return'After'end
  error('__TAG__ Source has later edits; nothing changed: '..c.Item:GetFullName())
 end
 local function put(c,where)
  if c.Retire then
   -- Idempotent, so a rollback can run it on a half-done object. Scripts are switched off before they leave and back on after they return.
   if where=='After'then
    for _,s in ipairs(c.Scripts)do s.Item.Disabled=true end
    c.Item.Parent=c.Parked
   else
    local parent=destination(c)
    c.Item.Name=c.Name;c.Item.Parent=parent
    for _,s in ipairs(c.Scripts)do s.Item.Disabled=s.Disabled end
   end
   assert(state(c)==where,'__TAG__ Move did not persist: '..display(c.Names))
   for _,s in ipairs(c.Scripts)do assert((s.Item.Disabled==true)==(where=='After'or s.Disabled),'__TAG__ Disabled state did not persist: '..s.Item:GetFullName())end
   return
  end
  if c.New then
   if where=='After'then
    for _,other in ipairs(c.Home:GetChildren())do assert(other==c.Item or other.Name~=c.Name,'__TAG__ Something named '..c.Name..' already exists in '..c.Home:GetFullName())end
    c.Item.Parent=c.Home
   else c.Item.Parent=c.Entry end
   assert(state(c)==where,'__TAG__ Move did not persist: '..c.Name)
  else write(c.Item,c[where=='After'and'Before'or'After'],c[where])end
 end
 -- R154b: a script open in a script tab may not take a write cleanly (R154's first paste stopped on one): refuse up front, before anything changes.
 local open={}
 pcall(function()for _,doc in ipairs(editor:GetScriptDocuments())do if not doc:IsCommandBar()then local s=doc:GetScript();if s then open[s]=true end end end end)
 for _,c in ipairs(sources)do
  if not c.Retire and open[c.Item]then error('__TAG__ Close the script tab of '..c.Item:GetFullName()..' (close every script tab), then paste again. Nothing changed.')end
 end
 local fromCount,toCount=0,0
 for _,c in ipairs(sources)do
  local current=state(c)
  if current==from then fromCount+=1 else toCount+=1 end
 end
 local function reportSkipped()for _,s in ipairs(skipped)do print('__TAG__ Skipped '..display(s.Names)..' ('..s.Why..').')end end
 if #sources==0 then reportSkipped();print('__TAG__ Nothing to '..mode..'.');return end
 if toCount==#sources then print('__TAG__ Already '..(mode=='install'and'installed.'or'undone.'));return end
 assert(fromCount==#sources and toCount==0,'__TAG__ Mixed script versions or retired objects; nothing changed.')
 if mode=='undo'then for _,c in ipairs(sources)do if c.Retire then destination(c)end end end
 -- R124: Play started while scripts are still being written copies a half-installed place; say so up front.
 print(mode=='install'and'__TAG__ Installing... do not press Play until it says Installed.'or'__TAG__ Undoing... do not press Play until it says Undone.')
 local attempted={}
 local okay,why=xpcall(function()
  for _,c in ipairs(sources)do
   assert(state(c)==from,'__TAG__ Script changed during installation.')
   attempted[#attempted+1]=c;put(c,to)
  end
  for _,c in ipairs(sources)do assert(state(c)==to,'__TAG__ Final source verification failed.')end
 end,debug.traceback)
 if not okay then
  local errors={}
  for i=#attempted,1,-1 do
   local c=attempted[i]
   local ok,err=pcall(function()if c.Retire or state(c)==to then put(c,from)end end)
   if not ok then errors[#errors+1]=tostring(err)end
  end
  package:SetAttribute('State',#errors==0 and'RolledBack'or'RestoreIncomplete')
  assert(#errors==0,'__TAG__ Restore incomplete; reopen your saved place. '..table.concat(errors,' | '))
  error('__TAG__ Installation stopped; its source writes were rolled back: '..tostring(why))
 end
 package:SetAttribute('State',mode=='install'and'Installed'or'Undone')
 for _,c in ipairs(sources)do
  if c.Retire then
   print('__TAG__ '..(mode=='install'and'Retired 'or'Restored ')..display(c.Names)..' ('..c.Item.ClassName..(#c.Scripts>0 and', '..#c.Scripts..' script(s) '..(mode=='install'and'disabled'or'set back to their original Disabled state')or'')..')')
  end
 end
 reportSkipped()
 pcall(function()game:GetService('ChangeHistoryService'):SetWaypoint('__RELEASE__ '..mode)end)
 print(mode=='install'and'__TAG__ Installed. Save, then start a NEW Play session.'or'__TAG__ Undone; previous scripts restored. Save, then start a NEW Play session.')
end
