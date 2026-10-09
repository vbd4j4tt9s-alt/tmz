--!nocheck
-- R152 performance patch: the look / sound fingerprint and the write probe, shared by every perf152_*.luau driver (run_perf152.sh).
-- FP.shot(label, roots...) prints one block "SHOT <label>" .. "END": one line per instance (tree order, depth first) with EVERY property the scripts
-- gave it (the mock keeps them all in _props: class, name, CFrame / Size to 1e-4, colours, material, transparency, mesh / texture ids, emitter / beam /
-- light values, GUI text / size / position / ZIndex, sound ids / volumes ...), its attributes and tags, and a visibility mark:
--   1 = drawn (a part with Transparency < 1, a decal, an enabled gui / gui object that is shown, an enabled emitter / beam / light / highlight, a sound)
--   0 = provably never drawn (Transparency 1, a gui switched off or not on a part, Visible false, a disabled beam / light ...)
--   m = a modifier of its parent (mesh, stroke, corner, gradient, scale, constraints): drawn with it;   n = neutral (folders, models, attachments ...)
-- perf152_canon.py prunes what is never drawn and compares the rest exactly (siblings in any order), so a pool that is built another way still matches.
-- FP.probe() counts property writes per class.property (and the ones that wrote the value already there) and instances made: the per-frame cost.
return function(W)
 local R=W.R
 local FP={}
 -- (R153: run_perf153.sh puts perf153_opts.luau next to the drivers; it sets FP.Normal / FP.Drop to compare what the engine can draw. Absent: no change.)
 local okOpts,optsFn=pcall(require,'./perf153_opts')
 -- (R154: run_perf153.sh also puts perf154_opts.luau there: the differences B1 / B3 are allowed to make (FP.Skip(o) leaves an instance and what is under it out, FP.Label = the shot being made))
 local okOpts4,optsFn4=pcall(require,'./perf154_opts')
 -- (R155: docs/proposals/R155/tests/run_camera155.sh puts perf155_opts.luau there when it compares against the R154 release: the cinematic camera's
 --  in-stage CFrame / Focus / FieldOfView and its depth of field are the only differences allowed)
 local okOpts5,optsFn5=pcall(require,'./perf155_opts')
 local fmt=string.format
 -- (as Roblox: two CFrames with the same components are ==; the shared mock compares them by identity. Both sides of a comparison run with it.)
 do local mt=getmetatable(R.CFrame.new(0,0,0))
  if mt and not rawget(mt,'__eq')then
   mt.__eq=function(a,b)
    if getmetatable(a)~=mt or getmetatable(b)~=mt or a.Position~=b.Position then return false end
    for i=1,3 do for j=1,3 do if a.R[i][j]~=b.R[i][j]then return false end end end
    return true
   end
  end
 end
 local function n(v)
  if v~=v then return'nan'end
  if v==math.huge then return'inf'elseif v==-math.huge then return'-inf'end
  local s=fmt('%.4f',v);if s=='-0.0000'then s='0.0000'end;return s
 end
 FP.num=n
 -- (a table's address in a string - the mock's tostring of an Enum item stored as an attribute - is not part of the look and differs run to run)
 local function esc(s)return(tostring(s):gsub('\\','\\\\'):gsub('\n','\\n'):gsub('\t','\\t'):gsub('|','\\p'):gsub('0x%x+','0x?'))end
 local function path(o)
  local t={};local x=o
  while x and x~=W.game do table.insert(t,1,tostring(x._props.Name));x=x._parent end
  return table.concat(t,'/')
 end
 FP.path=path
 local ser
 local function seq(v)
  -- NumberSequence / ColorSequence in the mock: A = a value or a list of keypoints, B = the end value (or nil)
  local a=v.A;local out={}
  if type(a)=='table'and a.__type==nil and #a>0 then for _,k in ipairs(a)do out[#out+1]=ser(k)end;return'['..table.concat(out,';')..']'end
  return'['..ser(a)..(v.B~=nil and(';'..ser(v.B))or'')..']'
 end
 function ser(v)
  local t=type(v)
  if t=='number'then return n(v)elseif t=='string'then return esc(v)elseif t=='boolean'then return tostring(v)elseif t=='nil'then return'nil'end
  if t~='table'then return nil end
  if v._class then return'<'..esc(path(v))..'>'end
  local ty=v.__type
  if ty=='Vector3'then return'('..n(v.X)..','..n(v.Y)..','..n(v.Z)..')'
  elseif ty=='Vector2'then return'('..n(v.X)..','..n(v.Y)..')'
  elseif ty=='CFrame'then local r=v.R;local p=v.Position
   return'cf('..n(p.X)..','..n(p.Y)..','..n(p.Z)..';'..n(r[1][1])..','..n(r[1][2])..','..n(r[1][3])..','..n(r[2][1])..','..n(r[2][2])..','..n(r[2][3])..','..n(r[3][1])..','..n(r[3][2])..','..n(r[3][3])..')'
  elseif ty=='Color3'then return'c('..n(v.R)..','..n(v.G)..','..n(v.B)..')'
  elseif ty=='UDim'then return'u('..n(v.Scale)..','..n(v.Offset)..')'
  elseif ty=='UDim2'then return'u2('..n(v.X.Scale)..','..n(v.X.Offset)..','..n(v.Y.Scale)..','..n(v.Y.Offset)..')'
  elseif ty=='EnumItem'then return tostring(v.EnumType)..'.'..tostring(v.Name)
  elseif ty=='NumberSequence'or ty=='ColorSequence'then return ty..seq(v)
  elseif ty=='NumberRange'then return'r('..n(v.Min)..','..n(v.Max or v.Min)..')'
  elseif ty then
   local keys={};for k in pairs(v)do if k~='__type'then keys[#keys+1]=tostring(k)end end;table.sort(keys)
   local out={};for _,k in ipairs(keys)do local s=ser(v[k]);if s then out[#out+1]=k..':'..s end end
   return ty..'{'..table.concat(out,',')..'}'
  end
  return nil -- signals, connections, functions: not part of the look
 end
 FP.ser=ser
 -- one property of one instance as text (R153: FP.Normal(o, k, v), when a driver's options set it, may give its own text first; false = leave it out)
 function FP.serKey(o,k,v)
  local n=FP.Normal;if n then local x=n(o,k,v);if x~=nil then return x or nil end end
  return ser(v)
 end
 -- visibility -----------------------------------------------------------------------------------------------------------------------------------
 local MOD={SpecialMesh=true,BlockMesh=true,CylinderMesh=true,SurfaceAppearance=true,UIStroke=true,UICorner=true,UIGradient=true,UIScale=true,UIPadding=true,
  UIAspectRatioConstraint=true,UISizeConstraint=true,UITextSizeConstraint=true,UIListLayout=true,UIGridLayout=true,UIPageLayout=true,UITableLayout=true,UIFlexItem=true}
 local GUIOBJ={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ViewportFrame=true,ScrollingFrame=true,CanvasGroup=true,TextBox=true,VideoFrame=true}
 local function isPart(o)return o and o._class~=nil and o:IsA('BasePart')end
 local function off(v)return v==false end
 -- ctx: nil outside any gui; 'on' inside a gui that is drawn (and every gui object up to here shown); 'off' otherwise
 local function mark(o,ctx)
  local c,p=o._class,o._props
  if MOD[c]then return'm',ctx end
  if isPart(o)then
   local t=p.Transparency or 0;local ltm=p.LocalTransparencyModifier or 0
   return(t<1 and ltm<1)and'1'or'0',ctx
  end
  if c=='Decal'or c=='Texture'then return(isPart(o._parent)and(p.Transparency or 0)<1 and(p.LocalTransparencyModifier or 0)<1)and'1'or'0',ctx end
  if c=='SurfaceGui'or c=='BillboardGui'then
   local host=p.Adornee or o._parent
   local on=not off(p.Enabled)and host~=nil and(isPart(host)or host._class=='Attachment'or(c=='BillboardGui'and host._class=='Model'))
   return on and'1'or'0',on and'on'or'off'
  end
  if c=='ScreenGui'then
   local on=not off(p.Enabled)and o._parent~=nil and o._parent._class=='PlayerGui'
   return on and'1'or'0',on and'on'or'off'
  end
  if GUIOBJ[c]then
   local on=ctx=='on'and not off(p.Visible)
   return on and'1'or'0',on and'on'or'off'
  end
  if c=='ParticleEmitter'then return'1',ctx end -- (an emitter that is off can still Emit a burst: always compared)
  if c=='Beam'or c=='Trail'or c=='Highlight'then return off(p.Enabled)and'0'or'1',ctx end
  if c=='PointLight'or c=='SpotLight'or c=='SurfaceLight'then return(off(p.Enabled)or(p.Brightness or 1)==0)and'0'or'1',ctx end
  if c=='Sound'then return'1',ctx end
  if c=='ColorCorrectionEffect'or c=='BlurEffect'or c=='BloomEffect'or c=='SunRaysEffect'or c=='DepthOfFieldEffect'or c=='Atmosphere'or c=='Sky'then return off(p.Enabled)and'0'or'1',ctx end
  return'n',ctx
 end
 FP.mark=mark
 local SKIP={Name=true,Parent=true}
 -- one line: depth, mark, class, name, sorted properties, attributes, tags
 function FP.line(o,depth,vis,opts)
  local keys={}
  for k in pairs(o._props)do if not SKIP[k]then keys[#keys+1]=k end end
  table.sort(keys)
  local out={tostring(depth),vis,o._class,esc(o._props.Name)}
  local drop=opts and opts.Drop or FP.Drop
  for _,k in ipairs(keys)do
   if not(drop and(drop[k]or drop[o._class..'.'..k]))then
    local s=FP.serKey(o,k,o._props[k]);if s then out[#out+1]=k..'='..s end
   end
  end
  local ak={};for k in pairs(o._attrs)do ak[#ak+1]=k end;table.sort(ak)
  for _,k in ipairs(ak)do if not(drop and drop['@'..k])then local s=ser(o._attrs[k]);if s then out[#out+1]='@'..k..'='..s end end end
  if o._tags then local tg={};for t,on in pairs(o._tags)do if on then tg[#tg+1]=t end end;table.sort(tg);if #tg>0 then out[#out+1]='#'..table.concat(tg,'+')end end
  return table.concat(out,'\t')
 end
 -- every instance under root (root included), depth first; returns the number of lines
 function FP.tree(root,emit,opts,depth0,ctx0)
  local count=0
  local function walk(o,depth,ctx)
   if FP.Skip and FP.Skip(o)then return end
   local vis,cctx=mark(o,ctx)
   emit(FP.line(o,depth,vis,opts));count+=1
   for _,c in ipairs(o._children)do walk(c,depth+1,cctx)end
  end
  local ctx=ctx0
  if ctx==nil then -- a root inside a gui: work out the context from its ancestors
   local chain={};local x=root._parent;while x do table.insert(chain,1,x);x=x._parent end
   for _,a in ipairs(chain)do local _,c=mark(a,ctx);ctx=c end
  end
  walk(root,depth0 or 0,ctx)
  return count
 end
 -- a shot: several roots under one label (a root that is nil is printed as missing)
 function FP.shot(label,roots,opts)
  FP.Label=label
  local buf={'SHOT '..label}
  local function emit(l)buf[#buf+1]=l end
  local total=0
  for i,root in ipairs(roots)do
   if root then emit('ROOT '..esc(path(root)));total+=FP.tree(root,emit,opts,0)else emit('ROOT <missing '..i..'>')end
  end
  buf[#buf+1]='END '..total
  print(table.concat(buf,'\n'))
  return total
 end
 -- A frame-by-frame stream (the seed opening: hundreds of frames of ~1,500 instances): the same content as a shot, but every frame prints only what changed:
 --   "FRAME <stream>\t<frame>", then per instance that is new: "+ <id>\t<parent id>\t<mark>\t<class>\t<name>\t<k=v>..." (properties, @attributes, #tags);
 --   one whose place or mark changed: "^ <id>\t<parent id>\t<mark>"; one whose values changed: "~ <id>\t<k=v>..." (only those; "k" alone = gone);
 --   one that is gone: "- <id>"; then "FEND". perf152_canon.py rebuilds every frame and compares it like a shot. A value is serialized again only when it
 --   is no longer the very value seen last frame.
 function FP.stream(name)
  local st={Name=name,Cache=setmetatable({},{__mode='k'}),Ids=setmetatable({},{__mode='k'}),Next=0,Prev={}}
  local function tagsOf(o)
   if not o._tags then return nil end
   local t={};for k,on in pairs(o._tags)do if on then t[#t+1]=k end end;if #t==0 then return nil end
   table.sort(t);return table.concat(t,'+')
  end
  -- the serialized values of an instance: {key -> text}; raw: {key -> the value they came from}
  local function full(o,c)
   c.S={};c.Raw={};c.A={}
   for k,v in pairs(o._props)do if not SKIP[k]then local x=FP.serKey(o,k,v);if x then c.S[k]=x end;c.Raw[k]=v end end
   for k,v in pairs(o._attrs)do local x=ser(v);if x then c.S['@'..k]=x end;c.A[k]=v end
   local tg=tagsOf(o);c.S['#']=tg;c.Name=o._props.Name
  end
  local function tokens(c)
   local t={};for k,v in pairs(c.S)do if k=='#'then t[#t+1]='#'..v else t[#t+1]=k..'='..v end end
   return table.concat(t,'\t')
  end
  -- what changed since last frame: a list of tokens ("k=v", or "k" when gone)
  local function delta(o,c,out)
   local p=o._props
   for k,v in pairs(p)do
    if not SKIP[k]and c.Raw[k]~=v then
     c.Raw[k]=v;local x=FP.serKey(o,k,v)
     if x~=c.S[k]then c.S[k]=x;out[#out+1]=x and(k..'='..x)or k end
    end
   end
   for k in pairs(c.Raw)do if p[k]==nil then c.Raw[k]=nil;if c.S[k]~=nil then c.S[k]=nil;out[#out+1]=k end end end
   local a=o._attrs
   for k,v in pairs(a)do
    if c.A[k]~=v then
     c.A[k]=v;local x=ser(v);local key='@'..k
     if x~=c.S[key]then c.S[key]=x;out[#out+1]=x and(key..'='..x)or key end
    end
   end
   for k in pairs(c.A)do if a[k]==nil then c.A[k]=nil;local key='@'..k;if c.S[key]~=nil then c.S[key]=nil;out[#out+1]=key end end end
   local tg=tagsOf(o);if tg~=c.S['#']then c.S['#']=tg;out[#out+1]=tg and('#'..tg)or'#' end
   return out
  end
  function st:frame(label,roots)
   local out={'FRAME '..name..'\t'..label}
   local now={}
   local ids,cache=self.Ids,self.Cache
   local function walk(o,pid,ctx)
    if FP.StreamSkip and FP.StreamSkip(o)then return end -- (R155: perf155_opts.luau leaves the cinematic camera's depth of field out of the frame streams)
    local id=ids[o];if not id then self.Next+=1;id=self.Next;ids[o]=id end
    if now[id]then return end
    now[id]=true
    local vis,cctx=mark(o,ctx)
    local c=cache[o]
    if not c or not self.Prev[id]or c.Name~=o._props.Name then
     if not c then c={};cache[o]=c end
     full(o,c);c.Pid,c.Vis=pid,vis
     out[#out+1]='+ '..id..'\t'..pid..'\t'..vis..'\t'..o._class..'\t'..esc(o._props.Name)..'\t'..tokens(c)
    else
     if c.Pid~=pid or c.Vis~=vis then c.Pid,c.Vis=pid,vis;out[#out+1]='^ '..id..'\t'..pid..'\t'..vis end
     local d=delta(o,c,{})
     if #d>0 then out[#out+1]='~ '..id..'\t'..table.concat(d,'\t')end
    end
    for _,ch in ipairs(o._children)do walk(ch,id,cctx)end
   end
   for _,root in ipairs(roots)do
    if root then
     local ctx=nil;local chain={};local x=root._parent;while x do table.insert(chain,1,x);x=x._parent end
     for _,a in ipairs(chain)do local _,cc=mark(a,ctx);ctx=cc end
     walk(root,0,ctx)
    end
   end
   for id in pairs(self.Prev)do if not now[id]then out[#out+1]='- '..id end end
   self.Prev=now
   out[#out+1]='FEND'
   print(table.concat(out,'\n'))
  end
  return st
 end
 -- The game's pairs() in a fixed order. A table keyed by instances (BeastAnimation's keepers, a client's entries) is walked in the order of the
 -- instances' addresses, which differ run to run and side to side; where the walk order matters (a shared random generator, the nearest few
 -- that get a light) two runs of the same code would not match. The scripts' pairs() is given the keys sorted: numbers, strings, booleans, then
 -- instances in the order they were made (the mock's creation list), then other tables in the order first seen.
 function FP.orderedPairs()
  local seq=setmetatable({},{__mode='k'})
  for i,o in ipairs(R.created)do seq[o]=i end
  -- (every instance the mock makes, clones included, is appended to R.created: its index there is its order)
  setmetatable(R.created,{__newindex=function(t,k,o)rawset(t,k,o);if type(k)=='number'then seq[o]=k end end})
  local seen=setmetatable({},{__mode='k'});local m=0
  local rank={number=1,string=2,boolean=3}
  local function key(k)
   local r=rank[type(k)];if r then return r,k end
   local s=seq[k];if s then return 4,s end
   s=seen[k];if not s then m+=1;s=m;seen[k]=s end
   return 5,s
  end
  local rawpairs=pairs
  local function sorted(t)
   local keys={};for k in next,t do keys[#keys+1]=k end
   if #keys>1 then
    local kr,kv={},{}
    for _,k in ipairs(keys)do local a,b=key(k);kr[k]=a;kv[k]=b==true and 1 or b==false and 0 or b end
    table.sort(keys,function(a,b)if kr[a]~=kr[b]then return kr[a]<kr[b]end;return kv[a]<kv[b]end)
   end
   local i=0
   return function()
    while true do i+=1;local k=keys[i];if k==nil then return nil end;local v=rawget(t,k);if v~=nil then return k,v end end -- (a key removed during the walk is skipped, as next() does)
   end
  end
  W.env.pairs=function(t)local mt=getmetatable(t);if type(mt)=='table'and mt.__iter then return rawpairs(t)end;return sorted(t)end
 end
 -- extra facts (a sound schedule, the camera ...) as one tagged line inside the output stream
 function FP.fact(label,text)print('FACT '..label..'\t'..text)end
 -- counts of a tree (instances, BaseParts, MeshParts, SurfaceGuis, drawn parts / guis)
 function FP.counts(root)
  local c={Instances=0,Parts=0,MeshParts=0,SurfaceGuis=0,SurfaceGuisOn=0,Labels=0,Drawn=0,Emitters=0,Beams=0,Lights=0,Sounds=0}
  local function walk(o,ctx)
   local vis,cctx=mark(o,ctx)
   c.Instances+=1
   if isPart(o)then c.Parts+=1;if o._class=='MeshPart'then c.MeshParts+=1 end;if vis=='1'then c.Drawn+=1 end end
   if o._class=='SurfaceGui'then c.SurfaceGuis+=1;if vis=='1'then c.SurfaceGuisOn+=1 end end
   if(o._class=='TextLabel'or o._class=='TextButton')and vis=='1'then c.Labels+=1 end
   if o._class=='ParticleEmitter'then c.Emitters+=1 end
   if o._class=='Beam'or o._class=='Trail'then c.Beams+=1 end
   if o._class=='PointLight'or o._class=='SpotLight'or o._class=='SurfaceLight'then c.Lights+=1 end
   if o._class=='Sound'then c.Sounds+=1 end
   for _,ch in ipairs(o._children)do walk(ch,cctx)end
  end
  if root then walk(root,nil)end
  return c
 end
 function FP.countText(c)
  return fmt('instances=%d parts=%d meshparts=%d drawn=%d surfaceguis=%d(on %d) labels=%d emitters=%d beams=%d lights=%d sounds=%d',c.Instances,c.Parts,c.MeshParts,c.Drawn,c.SurfaceGuis,c.SurfaceGuisOn,c.Labels,c.Emitters,c.Beams,c.Lights,c.Sounds)
 end
 -- the write probe ----------------------------------------------------------------------------------------------------------------------------------
 -- Wraps the mock's property write: every write is counted per "Class.Property", and a write that sets the value already there (compared as the
 -- fingerprint prints it) is counted as "same". Parent writes and the mock's own bookkeeping are counted like any other.
 local probe={On=false,Writes=0,Same=0,By={},SameBy={},Made0=0,Overhead=0}
 FP.Probe=probe
 local meta=R.instMeta;local raw=meta.__newindex
 meta.__newindex=function(o,k,v)
  if probe.On then
   local t0=os.clock()
   local key=o._class..'.'..k
   if probe.Classify then key=probe.Classify(o)..':'..key end
   probe.Writes+=1;probe.By[key]=(probe.By[key]or 0)+1
   if k~='Parent'then
    local old=rawget(o,'_props')[k]
    if old==v or(old~=nil and type(old)=='table'and type(v)=='table'and ser(old)==ser(v))then probe.Same+=1;probe.SameBy[key]=(probe.SameBy[key]or 0)+1
     -- (probe.Where: which line wrote it; a debugging aid, off in the runs)
     if probe.Where then local s,l=debug.info(2,'sl');for lv=3,8 do if not tostring(s):match('^[=@]?%./')then break end;s,l=debug.info(lv,'sl')end
      local w=key..' @'..tostring(s):gsub('^[=@]','')..':'..tostring(l);probe.WhereBy=probe.WhereBy or{};probe.WhereBy[w]=(probe.WhereBy[w]or 0)+1 end
    end
   elseif o._parent==v then probe.Same+=1;probe.SameBy[key]=(probe.SameBy[key]or 0)+1 end
   probe.Overhead+=os.clock()-t0
  end
  return raw(o,k,v)
 end
 function FP.probeStart()probe.On=true;probe.Writes=0;probe.Same=0;probe.By={};probe.SameBy={};probe.Made0=#R.created end
 function FP.probeStop()probe.On=false;return{Writes=probe.Writes,Same=probe.Same,By=probe.By,SameBy=probe.SameBy,Made=#R.created-probe.Made0}end
 function FP.probeText(p,frames,top)
  local list={};for k,v in pairs(p.By)do list[#list+1]={k,v,p.SameBy[k]or 0}end
  table.sort(list,function(a,b)if a[2]~=b[2]then return a[2]>b[2]end;return a[1]<b[1]end)
  local parts={}
  for i=1,math.min(top or 8,#list)do parts[#parts+1]=fmt('%s %.1f (same %.1f)',list[i][1],list[i][2]/frames,list[i][3]/frames)end
  return fmt('writes/frame=%.1f same/frame=%.1f made/frame=%.2f top: %s',p.Writes/frames,p.Same/frames,p.Made/frames,table.concat(parts,'; '))
 end
 function FP.whereText(frames)
  local list={};for k,v in pairs(probe.WhereBy or{})do list[#list+1]={k,v}end;probe.WhereBy={}
  table.sort(list,function(a,b)if a[2]~=b[2]then return a[2]>b[2]end;return a[1]<b[1]end)
  for i=1,math.min(40,#list)do print(fmt('WHERE %.1f/frame %s',list[i][2]/frames,list[i][1]))end
 end
 -- writes per area (the part of the key before ':' when a classifier is set): {area = {writes, same}}
 function FP.probeAreas(p)
  local out={}
  for k,v in pairs(p.By)do local a=k:match('^([^:]+):')or'all';local e=out[a]or{0,0};e[1]+=v;e[2]+=p.SameBy[k]or 0;out[a]=e end
  return out
 end
 -- Lua time per handler: every RunService handler and bound render step is wrapped (again each frame: new connections too) and timed with the
 -- REAL clock, by the chunk that defined it (a client script or a module). FP.timed() -> {chunk = seconds}.
 local times={};local wrapped=setmetatable({},{__mode='k'})
 local realClock=os.clock
 local function chunk(f)local ok,s=pcall(debug.info,f,'s');s=ok and tostring(s)or'?';return(s:gsub('^[=@]',''))end
 local function wrap(f)
  if wrapped[f]then return f end
  local name=chunk(f)
  -- (the probe's own bookkeeping inside the call is not counted)
  local g=function(...)local o0=probe.Overhead;local t0=realClock();local a,b,c=f(...);times[name]=(times[name]or 0)+realClock()-t0-(probe.Overhead-o0);return a,b,c end
  wrapped[g]=true;return g
 end
 function FP.timeHandlers(Run)
  for _,sig in ipairs({Run.RenderStepped,Run.Heartbeat,Run.PreSimulation,Run.Stepped,Run.PostSimulation})do
   if sig and sig._c then for _,c in ipairs(sig._c)do if c.Connected and c._f then c._f=wrap(c._f)end end end
  end
  for _,b in pairs(W.rsBound or{})do b.Fn=wrap(b.Fn)end
 end
 function FP.timesReset()table.clear(times)end
 -- the Lua time of each chunk a frame, the best of `windows` windows of `frames` frames (the mock shares the machine: the minimum is the steady cost);
 -- step() runs one frame (FP.timeHandlers is called before it)
 function FP.minTimes(Run,windows,frames,step)
  local best={}
  for _=1,windows do
   table.clear(times)
   for _=1,frames do FP.timeHandlers(Run);step()end
   for k,v in pairs(times)do local ms=v*1000/frames;if not best[k]or ms<best[k]then best[k]=ms end end
  end
  return best
 end
 function FP.timed()return times end
  if okOpts and type(optsFn)=='function'then optsFn(FP,W)end
 if okOpts4 and type(optsFn4)=='function'then optsFn4(FP,W)end
 if okOpts5 and type(optsFn5)=='function'then optsFn5(FP,W)end
 return FP
end
