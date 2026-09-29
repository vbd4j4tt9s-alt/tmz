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

-- @@SPLIT@@
local sourceSpecs=__SPECS__
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
 local function read(item)
  local source=editor:GetEditorSource(item)
  assert(item.Source==source,'__TAG__ Unsaved editor changes: '..item:GetFullName());return source
 end
 local function write(item,before,after)
  editor:UpdateSourceAsync(item,function(current)
   assert(current==before,'__TAG__ Script changed during write: '..item:GetFullName());return after
  end)
  assert(read(item)==after,'__TAG__ Write did not persist: '..item:GetFullName())
 end
 local folder=unique(package,'Sources');local sources={};local specs={};local seen={}
 for _,spec in ipairs(sourceSpecs)do specs[spec.Path]=spec end
 assert(#folder:GetChildren()==#sourceSpecs and package:GetAttribute('SourceCount')==#sourceSpecs,'__TAG__ Incomplete backup.')
 for _,entry in ipairs(folder:GetChildren())do
  local path=entry:GetAttribute('Path');local spec=specs[path]
  assert(spec and not seen[path],'__TAG__ Invalid or duplicated backup entry.');seen[path]=true
  local target=unique(entry,'Target');local b=unique(entry,'After')
  assert(target:IsA('ObjectValue')and b:IsA('StringValue')and #b.Value==spec.AfterBytes and sha256(b.Value)==spec.AfterSHA256,'__TAG__ Damaged source backup: '..path)
  if spec.New then
   -- A script this update adds: installed = in place, undone = parked inside this backup entry.
   local item=target.Value;local parentPath,name=path:match('^(.*)/([^/]+)$')
   assert(item and item.ClassName==spec.Class and item.Name==name,'__TAG__ Added script object was replaced: '..path)
   sources[#sources+1]={New=true,Item=item,Entry=entry,Home=resolve(parentPath),Name=name,After=b.Value}
  else
   local item=resolve(path)
   assert(item.ClassName==spec.Class and target.Value==item,'__TAG__ Script object was replaced: '..path)
   local a=unique(entry,'Before')
   assert(a:IsA('StringValue')and #a.Value==spec.BeforeBytes and sha256(a.Value)==spec.BeforeSHA256,'__TAG__ Damaged source backup: '..path)
   sources[#sources+1]={Item=item,Before=a.Value,After=b.Value}
  end
 end
 local from,to=mode=='install'and'Before'or'After',mode=='install'and'After'or'Before'
 -- Added scripts: 'Before' means parked in the backup, 'After' means in place. Their source never changes.
 local function state(c)
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
  if c.New then
   if where=='After'then
    for _,other in ipairs(c.Home:GetChildren())do assert(other==c.Item or other.Name~=c.Name,'__TAG__ Something named '..c.Name..' already exists in '..c.Home:GetFullName())end
    c.Item.Parent=c.Home
   else c.Item.Parent=c.Entry end
   assert(state(c)==where,'__TAG__ Move did not persist: '..c.Name)
  else write(c.Item,c[where=='After'and'Before'or'After'],c[where])end
 end
 local fromCount,toCount=0,0
 for _,c in ipairs(sources)do
  local current=state(c)
  if current==from then fromCount+=1 else toCount+=1 end
 end
 if toCount==#sources then print('__TAG__ Already '..(mode=='install'and'installed.'or'undone.'));return end
 assert(fromCount==#sources and toCount==0,'__TAG__ Mixed script versions; nothing changed.')
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
   local ok,err=pcall(function()if state(c)==to then put(c,from)end end)
   if not ok then errors[#errors+1]=tostring(err)end
  end
  package:SetAttribute('State',#errors==0 and'RolledBack'or'RestoreIncomplete')
  assert(#errors==0,'__TAG__ Restore incomplete; reopen your saved place. '..table.concat(errors,' | '))
  error('__TAG__ Installation stopped; its source writes were rolled back: '..tostring(why))
 end
 package:SetAttribute('State',mode=='install'and'Installed'or'Undone')
 pcall(function()game:GetService('ChangeHistoryService'):SetWaypoint('__RELEASE__ '..mode)end)
 print(mode=='install'and'__TAG__ Installed. Save, then start a NEW Play session.'or'__TAG__ Undone; previous scripts restored. Save, then start a NEW Play session.')
end
