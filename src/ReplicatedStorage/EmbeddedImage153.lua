-- R153 (owner: "for the bonus roll pack replace that gift icon with the pack"): small pictures that travel INSIDE the game as data (no upload): a module such as
-- BonusPackImage153 holds the picture as 256 x 3 palette bytes + W x H palette indices + W x H alpha bytes, raw-deflated and base64'd (Data = the base64 split
-- in lines, Bytes = the raw size, Check = its Adler-32). This module decodes it and draws it with an EditableImage (AssetService:CreateEditableImage +
-- WritePixelsBuffer, applied with Content.fromObject to an ImageLabel's ImageContent, the same route as RarePullArt / TreadmillBeltArt151).
--  * M.Decode(data,tick)       pure: -> w, h, rgba (a buffer of straight RGBA bytes, row by row). Asserts the sizes and the checksum. tick (optional) is called about
--                              every 1 KB of work so the caller can yield between slices.
--  * M.Show(label,data,onRoute) label = an ImageLabel. The first Show of a picture decodes it on its own thread in short slices and makes ONE EditableImage, shared by
--                              every label that shows it (cached per data.Key). onRoute('image') when the label shows the picture, onRoute('fallback') when it cannot
--                              (Mesh / Image API off, memory budget, a bad stream): the caller keeps its plain drawn stand-in. The label's attribute ImageRoute says
--                              pending / image / fallback.
--  * M.Release(label)          stops showing it; when no label uses a picture any more its EditableImage is destroyed and the cache entry is dropped. A destroyed
--                              label is released by itself.
--  * M.Status()                {Pictures, Users, Ready, Failed, Pending} (tests).
-- Hooks (tests): Hooks.Create(w,h,rgba) -> object, Hooks.Content(object) -> content, Hooks.None (what Content.none is), Hooks.Spawn(fn), Hooks.Wait().
local M={SliceSeconds=.004,Hooks={}}
local function noop()end
-- 1. base64 + raw deflate (RFC 1951, after Mark Adler's puff), the same decoder as KeeperMeshes152 ----------------------------------------------------------------
local B64={};do local a='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';for i=1,64 do B64[string.byte(a,i)]=i-1 end end
local function base64(s,tick)
 tick=tick or noop;local nextTick=8192
 local n=#s;assert(n%4==0,'image data: base64 length '..n..' is not a multiple of 4')
 local pad=(string.sub(s,-2)=='==' and 2)or(string.sub(s,-1)=='=' and 1)or 0
 local out=buffer.create(n//4*3-pad);local o,size=0,n//4*3-pad
 for i=1,n,4 do
  local a,b,c,d=string.byte(s,i,i+3)
  local v=assert(B64[a],'image data: bad base64')*262144+assert(B64[b],'image data: bad base64')*4096+(B64[c]or 0)*64+(B64[d]or 0)
  buffer.writeu8(out,o,v//65536);if o+1<size then buffer.writeu8(out,o+1,v//256%256)end;if o+2<size then buffer.writeu8(out,o+2,v%256)end
  o+=3
  if i>=nextTick then nextTick=i+8192;tick()end
 end
 return out
end
local LBASE={3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local LEXT={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local DBASE={1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local DEXT={0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local ORDER={16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}
local function construct(lengths,from,n)
 local count,symbol,offs={},{},{}
 for l=0,15 do count[l]=0 end
 for s=0,n-1 do local l=lengths[from+s]or 0;count[l]+=1 end
 local left=1
 for l=1,15 do left=left*2-count[l];assert(left>=0,'image data: over-subscribed Huffman code')end
 offs[1]=0;for l=1,14 do offs[l+1]=offs[l]+count[l]end
 for s=0,n-1 do local l=lengths[from+s]or 0;if l~=0 then symbol[offs[l]]=s;offs[l]+=1 end end
 return {Count=count,Symbol=symbol}
end
local FIXED_L,FIXED_D
local function inflate(src,size,tick)
 tick=tick or noop;local out=buffer.create(size);local op=0;local nextTick=1024
 local ip,len=0,buffer.len(src);local bitbuf,bitcnt=0,0
 local function bits(n)
  while bitcnt<n do
   assert(ip<len,'image data: the deflate stream ends early')
   bitbuf+=bit32.lshift(buffer.readu8(src,ip),bitcnt);ip+=1;bitcnt+=8
  end
  local v=bit32.band(bitbuf,bit32.lshift(1,n)-1);bitbuf=bit32.rshift(bitbuf,n);bitcnt-=n
  return v
 end
 local function decode(h)
  local code,first,index=0,0,0;local count=h.Count
  for l=1,15 do
   if bitcnt==0 then assert(ip<len,'image data: the deflate stream ends early');bitbuf=buffer.readu8(src,ip);ip+=1;bitcnt=8 end
   code+=bit32.band(bitbuf,1);bitbuf=bit32.rshift(bitbuf,1);bitcnt-=1
   local c=count[l]
   if code-c<first then return h.Symbol[index+code-first]end
   index+=c;first=(first+c)*2;code*=2
  end
  error('image data: bad Huffman code',0)
 end
 local function codes(lcode,dcode)
  while true do
   local sym=decode(lcode)
   if op>=nextTick then nextTick=op+1024;tick()end
   if sym<256 then
    assert(op<size,'image data: more bytes than announced');buffer.writeu8(out,op,sym);op+=1
   elseif sym==256 then return
   else
    sym-=257;assert(sym<29,'image data: bad length code')
    local l=LBASE[sym+1]+bits(LEXT[sym+1])
    local ds=decode(dcode);assert(ds<30,'image data: bad distance code')
    local d=DBASE[ds+1]+bits(DEXT[ds+1])
    assert(d<=op,'image data: distance too far back');assert(op+l<=size,'image data: more bytes than announced')
    for _=1,l do buffer.writeu8(out,op,buffer.readu8(out,op-d));op+=1 end
   end
  end
 end
 repeat
  local last=bits(1);local kind=bits(2)
  if kind==0 then
   bitbuf,bitcnt=0,0;assert(ip+4<=len,'image data: the deflate stream ends early')
   local n=buffer.readu16(src,ip);assert(bit32.bxor(n,buffer.readu16(src,ip+2))==65535,'image data: bad stored block');ip+=4
   assert(ip+n<=len and op+n<=size,'image data: bad stored block');buffer.copy(out,op,src,ip,n);ip+=n;op+=n
  elseif kind==1 then
   if not FIXED_L then
    local l={};for s=0,143 do l[s]=8 end;for s=144,255 do l[s]=9 end;for s=256,279 do l[s]=7 end;for s=280,287 do l[s]=8 end
    local d={};for s=0,29 do d[s]=5 end
    FIXED_L,FIXED_D=construct(l,0,288),construct(d,0,30)
   end
   codes(FIXED_L,FIXED_D)
  elseif kind==2 then
   local nlen,ndist,ncode=bits(5)+257,bits(5)+1,bits(4)+4
   local lengths={};for i=1,ncode do lengths[ORDER[i]]=bits(3)end
   local lencode=construct(lengths,0,19);lengths={};local i=0
   while i<nlen+ndist do
    local sym=decode(lencode)
    if sym<16 then lengths[i]=sym;i+=1
    else
     local l,rep=0,0
     if sym==16 then assert(i>0,'image data: repeat with no length');l=lengths[i-1];rep=3+bits(2)
     elseif sym==17 then rep=3+bits(3)else rep=11+bits(7)end
     assert(i+rep<=nlen+ndist,'image data: too many lengths')
     for _=1,rep do lengths[i]=l;i+=1 end
    end
   end
   codes(construct(lengths,0,nlen),construct(lengths,nlen,ndist))
  else error('image data: bad block type',0)end
 until last==1
 assert(op==size,'image data: '..op..' bytes decoded, '..size..' announced')
 return out
end
M.Base64,M.Inflate=base64,inflate
local function adler(b,tick)
 local a,s=1,0
 for i=0,buffer.len(b)-1 do a=(a+buffer.readu8(b,i))%65521;s=(s+a)%65521;if i%4096==4095 then tick()end end
 return s*65536+a
end
-- 2. data -> straight RGBA ---------------------------------------------------------------------------------------------------------------------------------------------
function M.Decode(data,tick)
 tick=tick or noop
 assert(type(data)=='table'and type(data.Data)=='table','image data: no data')
 local w,h=data.Width,data.Height;local colors=data.Colors or 256
 assert(type(w)=='number'and type(h)=='number'and w>=1 and h>=1 and w<=1024 and h<=1024,'image data: bad size')
 assert(colors>=1 and colors<=256,'image data: bad palette size')
 local want=colors*3+w*h*2
 assert(data.Bytes==want,'image data: Bytes is '..tostring(data.Bytes)..', the size says '..want)
 local raw=inflate(base64(table.concat(data.Data),tick),want,tick)
 if data.Check then assert(adler(raw,tick)==data.Check,'image data: the checksum does not match')end
 local n=w*h;local out=buffer.create(n*4);local idx0,alpha0=colors*3,colors*3+n
 for i=0,n-1 do
  local p=buffer.readu8(raw,idx0+i);assert(p<colors,'image data: palette index out of range')
  local o=i*4
  buffer.writeu8(out,o,buffer.readu8(raw,p*3));buffer.writeu8(out,o+1,buffer.readu8(raw,p*3+1));buffer.writeu8(out,o+2,buffer.readu8(raw,p*3+2))
  buffer.writeu8(out,o+3,buffer.readu8(raw,alpha0+i))
  if i%2048==2047 then tick()end
 end
 return w,h,out
end
-- 3. drawing: one EditableImage per picture, shared and counted ----------------------------------------------------------------------------------------------------
local entries={} -- key -> {State='pending'|'ready'|'failed',Image=,Users={[label]={Callback=,Connection=}},Count=}
local function createImage(w,h,rgba)
 if M.Hooks.Create then return M.Hooks.Create(w,h,rgba)end
 local image=game:GetService('AssetService'):CreateEditableImage({Size=Vector2.new(w,h)})
 assert(image,'no EditableImage (memory budget or API unavailable)')
 image:WritePixelsBuffer(Vector2.zero,Vector2.new(w,h),rgba)
 return image
end
local function contentOf(image)if M.Hooks.Content then return M.Hooks.Content(image)end;return Content.fromObject(image)end
local function tell(user,route)if user.Callback then pcall(user.Callback,route)end end
local function paint(label,e,user)
 if not label.Parent then return end
 local ok=pcall(function()label.ImageContent=contentOf(e.Image)end)
 local route=ok and'image'or'fallback'
 label:SetAttribute('ImageRoute',route);tell(user,route)
end
local function drop(key,e)
 if entries[key]~=e then return end
 entries[key]=nil
 if e.Image then pcall(function()e.Image:Destroy()end);e.Image=nil end
end
local function start(key,e,data)
 local spawn=M.Hooks.Spawn or task.spawn
 spawn(function()
  local t0=os.clock()
  local function tick()if os.clock()-t0>M.SliceSeconds then if M.Hooks.Wait then M.Hooks.Wait()else task.wait()end;t0=os.clock()end end
  local ok,w,h,rgba=pcall(M.Decode,data,tick)
  if entries[key]~=e or next(e.Users)==nil then drop(key,e);return end -- everybody let go while it was decoding
  local image
  if ok then local made,value=pcall(createImage,w,h,rgba);if made and value then image=value else ok,w=false,value end end
  if not image then
   e.State,e.Why='failed',tostring(w)
   for label,user in pairs(e.Users)do label:SetAttribute('ImageRoute','fallback');tell(user,'fallback')end
   return
  end
  e.State,e.Image='ready',image
  for label,user in pairs(e.Users)do paint(label,e,user)end
 end)
end
function M.Show(label,data,onRoute)
 local key=data and data.Key;if type(key)~='string'then label:SetAttribute('ImageRoute','fallback');if onRoute then pcall(onRoute,'fallback')end;return'fallback'end
 local e=entries[key];local fresh=false
 if not e then e={State='pending',Users={}};entries[key]=e;fresh=true end
 local user=e.Users[label]
 if user then user.Callback=onRoute else
  user={Callback=onRoute}
  local ok,connection=pcall(function()return label.Destroying:Connect(function()M.Release(label)end)end)
  if ok then user.Connection=connection end
  e.Users[label]=user;label:SetAttribute('ImageRoute','pending')
 end
 if fresh then start(key,e,data)end -- (after the label is registered: a decode that finishes without yielding must find its user)
 local route=label:GetAttribute('ImageRoute') -- (a decode that finished inside start() has told this label already)
 if e.State=='ready'and route~='image'then paint(label,e,user)
 elseif e.State=='failed'and route~='fallback'then label:SetAttribute('ImageRoute','fallback');tell(user,'fallback')end
 return label:GetAttribute('ImageRoute')
end
function M.Release(label)
 for key,e in pairs(entries)do
  local user=e.Users[label]
  if user then
   e.Users[label]=nil
   if user.Connection then user.Connection:Disconnect()end
   if label.Parent then pcall(function()local none=M.Hooks.None;if none==nil then none=Content.none end;label.ImageContent=none end)end
   if next(e.Users)==nil and e.State~='pending'then drop(key,e)end -- (a pending decode drops itself when it finishes)
  end
 end
end
function M.Status()
 local s={Pictures=0,Users=0,Ready=0,Failed=0,Pending=0}
 for _,e in pairs(entries)do
  s.Pictures+=1;for _ in pairs(e.Users)do s.Users+=1 end
  if e.State=='ready'then s.Ready+=1 elseif e.State=='failed'then s.Failed+=1 else s.Pending+=1 end
 end
 return s
end
return M
