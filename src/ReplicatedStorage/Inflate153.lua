-- R153: the decoder every R152 keeper's mesh data goes through (base64 -> raw deflate (RFC 1951) -> Adler-32 check), moved here from KeeperMeshes152 UNCHANGED so the client can use it too
-- (CloverIcon153 decodes the 4 Leaf Clover picture with it). KeeperMeshes152 requires it and exports Base64 / Inflate as before. Error messages still say 'mesh data' (the first user).
-- Every step takes an optional `tick` (the caller passes slice()): called about every 1 KB of work so a long decode can yield between slices; no tick = one go, same result.
local M={}
local function noop()end
local B64={};do local a='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';for i=1,64 do B64[string.byte(a,i)]=i-1 end end
local function base64(s,tick)
 tick=tick or noop;local nextTick=8192
 local n=#s;assert(n%4==0,'mesh data: base64 length '..n..' is not a multiple of 4')
 local pad=(string.sub(s,-2)=='==' and 2)or(string.sub(s,-1)=='=' and 1)or 0
 local out=buffer.create(n//4*3-pad);local o,size=0,n//4*3-pad
 for i=1,n,4 do
  local a,b,c,d=string.byte(s,i,i+3)
  local v=assert(B64[a],'mesh data: bad base64')*262144+assert(B64[b],'mesh data: bad base64')*4096+(B64[c]or 0)*64+(B64[d]or 0)
  buffer.writeu8(out,o,v//65536);if o+1<size then buffer.writeu8(out,o+1,v//256%256)end;if o+2<size then buffer.writeu8(out,o+2,v%256)end
  o+=3
  if i>=nextTick then nextTick=i+8192;tick()end
 end
 return out
end
M.Base64=base64
-- Raw deflate (RFC 1951), after Mark Adler's puff: canonical Huffman codes decoded a bit at a time.
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
 for l=1,15 do left=left*2-count[l];assert(left>=0,'mesh data: over-subscribed Huffman code')end
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
   assert(ip<len,'mesh data: the deflate stream ends early')
   bitbuf+=bit32.lshift(buffer.readu8(src,ip),bitcnt);ip+=1;bitcnt+=8
  end
  local v=bit32.band(bitbuf,bit32.lshift(1,n)-1);bitbuf=bit32.rshift(bitbuf,n);bitcnt-=n
  return v
 end
 local function decode(h)
  local code,first,index=0,0,0;local count=h.Count
  for l=1,15 do
   if bitcnt==0 then assert(ip<len,'mesh data: the deflate stream ends early');bitbuf=buffer.readu8(src,ip);ip+=1;bitcnt=8 end
   code+=bit32.band(bitbuf,1);bitbuf=bit32.rshift(bitbuf,1);bitcnt-=1
   local c=count[l]
   if code-c<first then return h.Symbol[index+code-first]end
   index+=c;first=(first+c)*2;code*=2
  end
  error('mesh data: bad Huffman code',0)
 end
 local function codes(lcode,dcode)
  while true do
   local sym=decode(lcode)
   if op>=nextTick then nextTick=op+1024;tick()end
   if sym<256 then
    assert(op<size,'mesh data: more bytes than announced');buffer.writeu8(out,op,sym);op+=1
   elseif sym==256 then return
   else
    sym-=257;assert(sym<29,'mesh data: bad length code')
    local l=LBASE[sym+1]+bits(LEXT[sym+1])
    local ds=decode(dcode);assert(ds<30,'mesh data: bad distance code')
    local d=DBASE[ds+1]+bits(DEXT[ds+1])
    assert(d<=op,'mesh data: distance too far back');assert(op+l<=size,'mesh data: more bytes than announced')
    for _=1,l do buffer.writeu8(out,op,buffer.readu8(out,op-d));op+=1 end
   end
  end
 end
 repeat
  local last=bits(1);local kind=bits(2)
  if kind==0 then
   bitbuf,bitcnt=0,0;assert(ip+4<=len,'mesh data: the deflate stream ends early')
   local n=buffer.readu16(src,ip);assert(bit32.bxor(n,buffer.readu16(src,ip+2))==65535,'mesh data: bad stored block');ip+=4
   assert(ip+n<=len and op+n<=size,'mesh data: bad stored block');buffer.copy(out,op,src,ip,n);ip+=n;op+=n
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
     if sym==16 then assert(i>0,'mesh data: repeat with no length');l=lengths[i-1];rep=3+bits(2)
     elseif sym==17 then rep=3+bits(3)else rep=11+bits(7)end
     assert(i+rep<=nlen+ndist,'mesh data: too many lengths')
     for _=1,rep do lengths[i]=l;i+=1 end
    end
   end
   codes(construct(lengths,0,nlen),construct(lengths,nlen,ndist))
  else error('mesh data: bad block type',0)end
 until last==1
 assert(op==size,'mesh data: '..op..' bytes decoded, '..size..' announced')
 return out
end
M.Inflate=inflate
local function adler(b,tick)
 local a,s=1,0
 for i=0,buffer.len(b)-1 do a=(a+buffer.readu8(b,i))%65521;s=(s+a)%65521;if i%4096==4095 then tick()end end
 return s*65536+a
end
M.Noop=noop;M.Adler=function(b,tick)return adler(b,tick or noop)end -- (the tick is optional here too)
return M
