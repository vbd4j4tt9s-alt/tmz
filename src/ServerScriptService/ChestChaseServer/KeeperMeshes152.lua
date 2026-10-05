-- R152 (owner: "Do it all here, game builds the keeper models itself"): the approved rev 6 keeper models (docs/proposals/R151/keepers) are
-- built by the game, no upload. Each keeper's mesh data (KeeperMeshData152<Name>: base64 of a raw-deflated stream, written by
-- docs/proposals/R152/blender/encode_meshes.py, whose header describes it) is decoded here and baked ONCE per server, part by part, on the
-- FruitMeshes149 / ApprovedPlantMeshes route: AssetService:CreateEditableMesh -> AddVertex / AddNormal / AddColor / AddTriangle /
-- SetFaceNormals / SetFaceColors -> CreateDataModelContentAsync -> CreateMeshPartAsync, and every EditableMesh is destroyed straight after.
--  * Normals: every face of these models is flat, so each triangle gets its own normal (equal normals share one id). Colours: the palette
--    colour of the triangle times the generator's height shade (0.80 + 0.26 t), per corner; eyes and glow parts are plain Neon parts.
--  * Templates (one Model per keeper, MeshParts in KeeperRigConfig152 part order) stay in ServerStorage.KeeperMeshTemplates152: the server
--    clones them into the keepers in the workspace (BeastModels, VeiledKeeper81), clients only see those clones.
--  * Needs Game Settings > Security > "Allow Mesh / Image APIs". If a keeper cannot be baked (the API is off, no mesh memory, a bad
--    stream) it keeps today's model: BeastModels / VeiledEvent81 ask Wanted(stage) and build today's keeper when it says nil.
--  * The bake runs in its own thread with short time slices (SliceSeconds); nothing that builds a keeper ever waits for it. A keeper that
--    was dressed before its template was ready is swapped to the new model by BeastModels when it is next idle (asleep, no chase).
--  * Status (replicated): ReplicatedStorage.KeeperMeshStatus152 attributes Ready (all 8 baked), PreparationFinished, BakedCount,
--    FailureCount, BakeSeconds, Triangles, MeshParts, Mode (auto / off: the owner's /test keepermodels), LastFailure, Revision and
--    per keeper Stage1 .. Stage7 / Darkened = Loading / Ready / Failed; Failures holds one StringValue per failed keeper.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Config=require(RS:WaitForChild('KeeperRigConfig152'))
local M={Revision=152,Variant='R152',Folder='KeeperMeshStatus152',Templates='KeeperMeshTemplates152',SliceSeconds=.004,
 Order={1,6,2,3,4,5,7,0}, -- biome order, then The Darkened (it only appears in events)
 Unavailable='EditableMesh is not available in this environment'}
local WHITE=Color3.new(1,1,1)
function M.Key(stage)return Config.Stages[stage]and Config.Stages[stage].Key end

-- 1. Decoding (pure: base64 -> inflate -> parts) -------------------------------------------------------------------------------------------
local B64={};do local a='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';for i=1,64 do B64[string.byte(a,i)]=i-1 end end
local function base64(s)
 local n=#s;assert(n%4==0,'mesh data: base64 length '..n..' is not a multiple of 4')
 local pad=(string.sub(s,-2)=='==' and 2)or(string.sub(s,-1)=='=' and 1)or 0
 local out=buffer.create(n//4*3-pad);local o,size=0,n//4*3-pad
 for i=1,n,4 do
  local a,b,c,d=string.byte(s,i,i+3)
  local v=assert(B64[a],'mesh data: bad base64')*262144+assert(B64[b],'mesh data: bad base64')*4096+(B64[c]or 0)*64+(B64[d]or 0)
  buffer.writeu8(out,o,v//65536);if o+1<size then buffer.writeu8(out,o+1,v//256%256)end;if o+2<size then buffer.writeu8(out,o+2,v%256)end
  o+=3
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
local function inflate(src,size)
 local out=buffer.create(size);local op=0
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
local function adler(b)
 local a,s=1,0
 for i=0,buffer.len(b)-1 do a=(a+buffer.readu8(b,i))%65521;s=(s+a)%65521 end
 return s*65536+a
end
-- data (a KeeperMeshData152 module's table) -> {Parts={{V={x,y,z,...} studs (rig space), T={a,b,c,...} 1-based, P={cell per triangle} or nil}}}
function M.Decode(data)
 local raw=inflate(base64(table.concat(data.Data)),data.Bytes)
 assert(adler(raw)==data.Adler,'mesh data: checksum mismatch')
 local p=0
 local function u()
  local v,m=0,1
  while true do local c=buffer.readu8(raw,p);p+=1;v+=(c%128)*m;if c<128 then return v end;m*=128 end
 end
 local function s()local v=u();if v%2==0 then return v//2 end;return -(v+1)//2 end
 assert(u()==1,'mesh data: unknown stream version')
 local step=data.Step or 1/512;local parts={}
 for i=1,u()do
  local nv,nt,pal=u(),u(),u()==1
  local V=table.create(nv*3)
  for axis=1,3 do local q=0;for j=1,nv do q+=s();V[(j-1)*3+axis]=q*step end end
  local T=table.create(nt*3);local q=0
  for j=1,nt*3 do q+=s();assert(q>=0 and q<nv,'mesh data: vertex index out of range');T[j]=q+1 end
  local P
  if pal then P=table.create(nt);local j=0;while j<nt do local cell,count=u(),u();for _=1,count do j+=1;P[j]=cell end end;assert(j==nt,'mesh data: palette runs')end
  parts[i]={V=V,T=T,P=P}
 end
 assert(p==buffer.len(raw),'mesh data: trailing bytes')
 return {Parts=parts}
end

-- 2. Status and templates -------------------------------------------------------------------------------------------------------------------
local function status()
 local f=RS:FindFirstChild(M.Folder)
 if not f and Run:IsServer()then
  f=Instance.new('Folder');f.Name=M.Folder;f:SetAttribute('Revision',M.Revision);f:SetAttribute('Mode','auto');f:SetAttribute('Ready',false)
  f:SetAttribute('PreparationFinished',false);for _,stage in ipairs(M.Order)do f:SetAttribute(M.Key(stage),'Loading')end;f.Parent=RS
 end
 return f
end
local function templates()
 local storage=game:GetService('ServerStorage');local t=storage:FindFirstChild(M.Templates)
 if not t then t=Instance.new('Folder');t.Name=M.Templates;t.Parent=storage end
 return t
end
-- 'Ready' | 'Failed' (+ reason) | 'Loading' for one keeper (stage 0 = The Darkened); readable on clients (status attributes).
function M.State(stage)
 local f=RS:FindFirstChild(M.Folder);if not f then return 'Loading'end
 local s=f:GetAttribute(M.Key(stage))or'Loading'
 if s=='Failed'then local v=f:FindFirstChild('Failures');v=v and v:FindFirstChild(M.Key(stage));return s,v and v.Value end
 return s
end
function M.Mode()local f=RS:FindFirstChild(M.Folder);return f and f:GetAttribute('Mode')or'auto'end
function M.SetMode(mode)
 assert(mode=='auto'or mode=='off','Use keepermodels auto or off.');status():SetAttribute('Mode',mode)
end
-- The baked template of a keeper (server), or nil.
function M.Template(stage)
 local t=game:GetService('ServerStorage'):FindFirstChild(M.Templates);return t and t:FindFirstChild(M.Key(stage))
end
-- 'R152' when a keeper of this stage should be built from the new model now (baked and not switched off), else nil (today's model).
function M.Wanted(stage)
 if M.Mode()=='off'or M.State(stage)~='Ready'then return nil end
 return M.Template(stage)and M.Variant or nil
end

-- 3. The bake (server) ------------------------------------------------------------------------------------------------------------------------
local sliceAt=0
local function slice()if os.clock()-sliceAt>M.SliceSeconds then task.wait();sliceAt=os.clock()end end
local function bakePart(spec,part,data)
 local Assets=game:GetService('AssetService');local editable,mesh
 local ok,why=xpcall(function()
  local okApi,method=pcall(function()return Assets.CreateEditableMesh end)
  if Content==nil or not okApi or type(method)~='function'then error(M.Unavailable..' (AssetService:CreateEditableMesh or Content is missing)',0)end
  editable=Assets:CreateEditableMesh()
  assert(editable,'Mesh memory unavailable while preparing '..spec.Name)
  local V,T,P=part.V,part.T,part.P;local nv=#V//3
  local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
  for i=1,nv do for a=1,3 do local x=V[(i-1)*3+a];if x<lo[a]then lo[a]=x end;if x>hi[a]then hi[a]=x end end end
  local cx,cy,cz=(lo[1]+hi[1])/2,(lo[2]+hi[2])/2,(lo[3]+hi[3])/2
  local vid=table.create(nv)
  for i=1,nv do
   vid[i]=editable:AddVertex(Vector3.new(V[i*3-2]-cx,V[i*3-1]-cy,V[i*3]-cz))
   if i%64==0 then slice()end
  end
  local normals,colors={},{}
  local y0,span,pal=data.Y0,math.max(1e-3,data.Y1-data.Y0),data.Palette
  local function colour(v,cell)
   local key=v*256+cell;local c=colors[key];if c then return c end
   local rgb=assert(pal[cell+1],'mesh data: palette cell '..cell..' is not in the palette')
   local shade=.80+.26*math.clamp((V[v*3-1]-y0)/span,0,1)
   c=editable:AddColor(Color3.new(math.min(1,rgb[1]*shade),math.min(1,rgb[2]*shade),math.min(1,rgb[3]*shade)),1);colors[key]=c;return c
  end
  local added=0
  for t=1,#T//3 do
   local a,b,c=T[t*3-2],T[t*3-1],T[t*3]
   local ax,ay,az=V[a*3-2],V[a*3-1],V[a*3];local ux,uy,uz=V[b*3-2]-ax,V[b*3-1]-ay,V[b*3]-az;local wx,wy,wz=V[c*3-2]-ax,V[c*3-1]-ay,V[c*3]-az
   local nx,ny,nz=uy*wz-uz*wy,uz*wx-ux*wz,ux*wy-uy*wx;local m=math.sqrt(nx*nx+ny*ny+nz*nz)
   if m>1e-12 then -- a zero-area sliver (collapsed bevel corners) draws nothing: left out
    local face=editable:AddTriangle(vid[a],vid[b],vid[c]);added+=1
    nx,ny,nz=nx/m,ny/m,nz/m
    local key=math.floor(nx*4096+.5)*67125249+math.floor(ny*4096+.5)*8193+math.floor(nz*4096+.5)
    local n=normals[key];if not n then n=editable:AddNormal(Vector3.new(nx,ny,nz));normals[key]=n end
    editable:SetFaceNormals(face,{n,n,n})
    if P then local cell=P[t];editable:SetFaceColors(face,{colour(a,cell),colour(b,cell),colour(c,cell)})end
   end
   if t%64==0 then slice()end
  end
  assert(added>0,'no triangles in '..spec.Name)
  local result,content=Assets:CreateDataModelContentAsync(Content.fromObject(editable))
  assert(result==Enum.CreateContentResult.Success,'Could not bake keeper mesh '..spec.Name..': '..tostring(result))
  local hit=spec.Kind=='main'and not spec.Cosmetic -- the shapes the server's catch test uses
  mesh=Assets:CreateMeshPartAsync(content,{CollisionFidelity=hit and Enum.CollisionFidelity.Hull or Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise})
  assert(mesh,'no MeshPart for '..spec.Name)
  local size=Vector3.new(hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3])
  local okSize,meshSize=pcall(function()return mesh.MeshSize end)
  if okSize and typeof(meshSize)=='Vector3'and meshSize.Magnitude>0 then
   for _,axis in ipairs({'X','Y','Z'})do assert(math.abs(meshSize[axis]-size[axis])<=.02*size[axis]+1e-3,'the baked mesh '..spec.Name..' is not the decoded one ('..axis..' '..meshSize[axis]..' vs '..size[axis]..')')end
  end
  mesh.Name=spec.Name;mesh.Size=size;mesh.Anchored=true;mesh.CanCollide=false;mesh.CanTouch=false;mesh.CanQuery=false;mesh.Massless=true
  local neon=spec.Kind=='eyes'or spec.Kind=='glow'
  mesh.Material=neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
  mesh.Color=neon and Color3.new(table.unpack(spec.Color or{1,1,1}))or WHITE -- main / face: white, so the vertex colours show
  mesh.CastShadow=spec.Kind=='main'
  mesh:SetAttribute('KeeperMesh',spec.Name);mesh:SetAttribute('BakedCenter',Vector3.new(cx,cy,cz));mesh:SetAttribute('Triangles',added)
 end,debug.traceback)
 if editable then pcall(function()editable:Destroy()end)end
 if not ok then if mesh then pcall(function()mesh:Destroy()end)end;error(tostring(why),0)end
 return mesh
end
local function dataModule(stage)
 local name=Config.Stages[stage].Module
 return require(assert(script.Parent:FindFirstChild(name),'the mesh data module '..name..' is not installed'))
end
-- One keeper's template Model (not parented). Errors with the reason.
local function bakeKeeper(stage)
 local spec=Config.Stages[stage];local data=dataModule(stage)
 assert(data.Key==spec.Key and data.Parts==#spec.Parts,'mesh data '..spec.Module..' does not match KeeperRigConfig152')
 local decoded=M.Decode(data);slice()
 local model=Instance.new('Model');model.Name=spec.Key;model:SetAttribute('KeeperMeshVariant',M.Variant)
 local ok,why=pcall(function()
  local tris=0
  for i,s in ipairs(spec.Parts)do
   local part=decoded.Parts[i];assert(#part.T//3==s.Triangles,'triangle count of '..s.Name)
   local mesh=bakePart(s,part,data);tris+=mesh:GetAttribute('Triangles');mesh.Parent=model;slice()
  end
  model:SetAttribute('Triangles',tris)
 end)
 if not ok then pcall(function()model:Destroy()end);error(tostring(why),0)end
 return model
end
M._bakeKeeper=bakeKeeper
local preparing,started=false,false
-- Server: bakes every keeper (each on its own: a keeper that fails keeps today's model, the others still get theirs). Safe to call more
-- than once (later calls wait for the first). Returns ready (all baked), errors.
function M.Prepare()
 assert(Run:IsServer(),'Keeper mesh preparation is server-only.')
 local f=status();local t=templates()
 while preparing do task.wait()end
 if f:GetAttribute('PreparationFinished')then return f:GetAttribute('Ready')==true,{}end
 preparing=true;started=true;local errors={};local t0=os.clock();sliceAt=os.clock()
 local tris,parts,baked=0,0,0
 for _,stage in ipairs(M.Order)do
  local key=M.Key(stage)
  local ok,result=pcall(bakeKeeper,stage)
  if ok then
   local old=t:FindFirstChild(key);if old then old:Destroy()end
   result.Parent=t;baked+=1;tris+=result:GetAttribute('Triangles');parts+=#result:GetChildren();f:SetAttribute(key,'Ready')
  else
   local reason=tostring(result):match('^[^\n]*')or'?'
   table.insert(errors,key..': '..reason)
   local list=f:FindFirstChild('Failures')or Instance.new('Folder');list.Name='Failures';list.Parent=f
   local v=list:FindFirstChild(key)or Instance.new('StringValue');v.Name=key;v.Value='Could not bake the new '..Config.Stages[stage].Name..' (today\'s model stays): '..reason;v.Parent=list
   f:SetAttribute(key,'Failed');f:SetAttribute('LastFailure',key..': '..reason)
  end
  task.wait()
 end
 f:SetAttribute('BakedCount',baked);f:SetAttribute('FailureCount',#errors);f:SetAttribute('Triangles',tris);f:SetAttribute('MeshParts',parts)
 f:SetAttribute('BakeSeconds',math.floor((os.clock()-t0)*100+.5)/100);f:SetAttribute('PreparationFinished',true);f:SetAttribute('Ready',#errors==0)
 preparing=false
 if #errors>0 then
  local quiet=string.find(errors[1],M.Unavailable,1,true)
  warn('[R152 keeper models] '..#errors..' of '..#M.Order..' keepers keep today\'s model'..(quiet and' (turn on Game Settings > Security > "Allow Mesh / Image APIs")'or'')..'. First failure: '..errors[1])
 end
 return #errors==0,errors
end
-- Server: starts the bake once, deferred into its own thread (the caller never waits, not even for the first slice).
function M.Start()
 if started or not Run:IsServer()then return end
 started=true;status()
 task.defer(function()local ok,why=pcall(M.Prepare);if not ok then warn('[R152 keeper models] '..tostring(why))end end)
end

-- 4. Building keepers from the templates (server; never yields) ----------------------------------------------------------------------------
local function dress(p,s,stage)
 p:SetAttribute('KeeperMeshKind',s.Kind)
 if s.FaceState then p:SetAttribute('KeeperFaceState',s.FaceState)end
 if s.Cosmetic then p:SetAttribute('KeeperCosmetic',true)end
 if s.Floating then p:SetAttribute('KeeperFloating',true)end
end
-- A 'BeastBody' rig of the new model (rest pose in rig space, like KeeperUpgradeArt.Build), or nil when the template is not there.
function M.BuildRig(stage)
 local spec=Config.Stages[stage];local template=M.Template(stage);if not spec or stage==0 or not template then return nil end
 local rig=Instance.new('Model');rig.Name='BeastBody';rig:SetAttribute('VisualVersion',M.Revision);rig:SetAttribute('KeeperMeshVariant',M.Variant)
 for _,s in ipairs(spec.Parts)do
  local source=assert(template:FindFirstChild(s.Name),'template part missing: '..s.Name)
  local p=source:Clone();local rest=CFrame.new(s.Center[1],s.Center[2],s.Center[3])
  local baked=source:GetAttribute('BakedCenter');if baked then rest=CFrame.new(baked)end
  p.CFrame=rest;p.Size=source.Size;p:SetAttribute('RestCFrame',rest);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow==true)
  dress(p,s,stage)
  if s.TreeRest then p:SetAttribute('TreeRestCFrame',CFrame.new(table.unpack(s.TreeRest)));p:SetAttribute('TreeRestSize',Vector3.new(table.unpack(s.TreeSize)))end
  p.Parent=rig
 end
 return rig
end
-- The Darkened's parts: {Part=MeshPart (unparented clone), Spec=part spec} in config order, or nil (VeiledKeeper81 builds today's blocks).
function M.DarkenedParts()
 local spec=Config.Stages[0];local template=M.Template(0);if not spec or not template then return nil end
 local out={}
 for _,s in ipairs(spec.Parts)do
  local source=template:FindFirstChild(s.Name);if not source then return nil end
  local p=source:Clone();p.Size=source.Size;dress(p,s,0);out[#out+1]={Part=p,Spec=s,Center=source:GetAttribute('BakedCenter')}
 end
 return out
end
-- For /test keepermodels and the tests: what this server has.
function M.Status()
 local f=RS:FindFirstChild(M.Folder);local out={Mode=M.Mode(),Stages={}}
 if f then for k,v in pairs(f:GetAttributes())do out[k]=v end end
 for _,stage in ipairs(M.Order)do local s,why=M.State(stage);out.Stages[stage]={State=s,Reason=why,Name=Config.Stages[stage].Name,Triangles=Config.Stages[stage].Triangles,Parts=#Config.Stages[stage].Parts}end
 return out
end
return M
