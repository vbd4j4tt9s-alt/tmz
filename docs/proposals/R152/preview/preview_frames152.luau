--!nocheck
-- R152 preview (not a test): plays the REAL reveals on the Roblox mock (the R151 test environment: real RarePull* modules, PackOpeningFeedback,
-- SeedPackClient) and prints, at chosen moments, everything the screen shows - R151's preview_frames.luau, extended for R152:
--   FRAME <name> <json> - parts, particle emitters (texture, direction, spread, the age of a burst), lights, every Beam layer (its attachments,
--   axes, widths, curve, texture, colour and transparency sequences, light emission), camera-facing images (BillboardGuis: the planets,
--   nebulae, the seed's glow / halo; R151's soft glows), images on part faces (SurfaceGui / Decal / Texture: the rune circle, star map,
--   carpet, banners, glass, damask; the lock plates' strips), the camera, the grade / blur, the GUI (two layers: under and over the seed
--   card's viewport) and the viewport.
-- The images RarePullArt draws are made with the REAL pattern code; the preview names them "r152art://<name>" (dump_art.luau writes the
-- PNGs the renderer uses). Runs on this checkout and, for the before / after sheet, on the R151 tree (no RarePullArt there: nothing to hook).
-- SET: 'main' (every tier), 'king' (the King scene every 0.1 s), 'planets' (Cosmic close-ups), 'beam' (the sky beam: slam, impact, hold,
-- thinning; wide and close; the King's gold beams; a Mythic flourish), 'assets' (the frames of the before / after sheet).
local SET=SET or'main'
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local R=W.R
local dumpTree=require('./dump_tree152')
local V3,CF=R.Vector3.new,R.CFrame.new
local noop=function()end
function R.Inst:Play()local own=rawget(self,'_props').Play;if own then return own(self)end end
function R.Inst:Stop()local own=rawget(self,'_props').Stop;if own then return own(self)end end
function R.Inst:Pause()end
-- a burst's age: when it was emitted
function R.Inst:Emit(n)self._emitted=(self._emitted or 0)+(n or 0);self._emitAt=R.clock end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
local Mixer=W.module('AudioMixer');Mixer.Start()
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules');local M=W.module('RarePullCinematic')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local Art do local ok,m=pcall(W.module,'RarePullArt');Art=ok and m or nil end
local TREE=Art and'R152'or'R151'
if Art then
 Art.Hooks.Spawn=function(fn)fn()end;Art.Hooks.Wait=noop
 Art.Hooks.Create=function(w,h,rgba,name)return {Name=name,Destroy=noop}end
 Art.Hooks.Content=function(o)return 'r152art://'..o.Name end
 Art.Request(Art.Order)
end
-- blocky avatars so the world frames have someone holding the pack (the real avatar is not available offline)
local function avatar(char,x,z)
 local skin,shirt,pants=R.Color3.fromRGB(255,204,153),R.Color3.fromRGB(70,120,220),R.Color3.fromRGB(40,44,60)
 local function limb(name,size,pos,color)local p=R.new('Part');p.Name=name;p.Size=size;p.CFrame=CF(pos.X,pos.Y,pos.Z);p.Color=color;p.Material=R.Enum.Material.SmoothPlastic;p.Parent=char;return p end
 local up=char:FindFirstChild('UpperTorso');up.Color=shirt;up.Material=R.Enum.Material.SmoothPlastic
 limb('Head',V3(1.2,1.2,1.2),V3(x,6.65,z),skin);limb('LeftUpperArm',V3(1,2,1),V3(x-1.5,5,z),shirt);limb('RightUpperArm',V3(1,2,1),V3(x+1.5,5,z),shirt)
 limb('LeftLeg',V3(1,4,1),V3(x-.5,2,z),pants);limb('RightLeg',V3(1,4,1),V3(x+.5,2,z),pants)
 char:FindFirstChild('HumanoidRootPart').Transparency=1
end
avatar(X.char,0,100)
-- an onlooker's view: someone else opens a pack in front of us
local Players=W.service('Players')
local other=R.new('Player');other.Name='Puller';other.UserId=900;other.Parent=Players
local oc=R.new('Model');oc.Name='Puller';oc.Parent=W.workspace;other.Character=oc
do local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(30,5,60);t.Parent=oc
 local h=R.new('Part');h.Name='HumanoidRootPart';h.Size=V3(2,2,1);h.CFrame=CF(30,3,60);h.Parent=oc
 local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.Parent=oc end
avatar(oc,30,60)
function Players.GetPlayers()return {X.player,other}end
function Players.GetPlayerFromCharacter(_,c)if c==X.char then return X.player end;if c==oc then return other end;return nil end
-- JSON ------------------------------------------------------------------------------------------------------------------------------------
local function n(v)if type(v)~='number'or v~=v or v==math.huge or v==-math.huge then return'0'end;return string.format('%.4f',v)end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function c3(c)if not c or type(c)~='table'or c.R==nil then return'[255,255,255]'end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function v3(v)return'['..n(v.X)..','..n(v.Y)..','..n(v.Z)..']'end
local function rot(cf)local r=cf.R;return string.format('[%s,%s,%s,%s,%s,%s,%s,%s,%s]',n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]))end
local function enumName(e)if e==nil then return nil end;if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local function seqColors(s)
 if s==nil then return'[255,255,255]','[255,255,255]'end
 if s.R then return c3(s),c3(s)end
 if type(s.A)=='table'and s.A.R then return c3(s.A),c3(s.B or s.A)end
 if type(s.A)=='table'and s.A[1]then return c3(s.A[1].V),c3(s.A[#s.A].V)end
 return'[255,255,255]','[255,255,255]'
end
local function seqKeys(s,d)
 if type(s)=='number'then return'[[0,'..n(s)..'],[1,'..n(s)..']]'end
 if type(s)=='table'then
  if type(s.A)=='number'then return'[[0,'..n(s.A)..'],[1,'..n(s.B or s.A)..']]'end
  if type(s.A)=='table'and s.A[1]then local o={};for _,k in ipairs(s.A)do o[#o+1]='['..n(k.T)..','..n(k.V)..']'end;return'['..table.concat(o,',')..']'end
 end
 return'[[0,'..n(d)..'],[1,'..n(d)..']]'
end
local function seqFirst(s,d)if type(s)=='number'then return s end;if type(s)=='table'then if type(s.A)=='number'then return s.A end;if type(s.A)=='table'and s.A[1]then return s.A[1].V end end;return d end
local function seqLast(s,d)if type(s)=='number'then return s end;if type(s)=='table'then if type(s.B)=='number'then return s.B end;if type(s.A)=='number'then return s.A end;if type(s.A)=='table'and s.A[1]then return s.A[#s.A].V end end;return d end
local function texKind(t)t=tostring(t or'');if t:find('sparkles')then return'spark'elseif t:find('smoke')then return'smoke'elseif t:find('flare')then return'flare'elseif t==''then return'none'end;return'spark'end
local function partOf(o)local x=o;while x do if x:IsA('BasePart')and x._props.CFrame then return x end;x=x._parent end;return nil end
local function artName(img)local c=img and rawget(img,'_props').ImageContent;return type(c)=='string'and c:match('^r152art://(.+)$')or nil end
local function attWorld(a)
 local host=partOf(a);if not host then return nil end
 local p=a._props.Position;if type(p)~='table'or p.__type~='Vector3'then p=V3(0,0,0)end
 local cf=host._props.CFrame*CF(p.X,p.Y,p.Z);local r=host._props.CFrame.R
 return cf.Position,V3(r[1][1],r[2][1],r[3][1])
end
local function emitDir(e,host)
 local d=enumName(e._props.EmissionDirection)or'Top'
 local r=host._props.CFrame.R
 local axes={Top=V3(r[1][2],r[2][2],r[3][2]),Bottom=V3(-r[1][2],-r[2][2],-r[3][2]),Right=V3(r[1][1],r[2][1],r[3][1]),Left=V3(-r[1][1],-r[2][1],-r[3][1]),Front=V3(-r[1][3],-r[2][3],-r[3][3]),Back=V3(r[1][3],r[2][3],r[3][3])}
 return axes[d]or V3(0,1,0)
end
local function world(roots,keep)
 local parts,emitters,lights,bills,beams,faces,strips={},{},{},{},{},{},{}
 local seen={}
 for _,root in ipairs(roots)do
  local list=root:GetDescendants();if root:IsA('BasePart')then table.insert(list,1,root)end
  for _,c in ipairs(list)do
   if seen[c]then continue end;seen[c]=true
   if c:IsA('BasePart')and(not keep or keep(c))then
    local t=c._props.Transparency or 0;local ltm=c._props.LocalTransparencyModifier or 0;local a=1-(1-t)*(1-ltm)
    if a<.995 and c._props.CFrame and c._props.Size then
     local shape=c._class=='MeshPart'and'Pouch'or enumName(c._props.Shape)or'Block'
     local size=c._props.Size
     local mesh=c:FindFirstChildOfClass('SpecialMesh')
     if mesh then
      local kind=enumName(mesh._props.MeshType)or'Brick';local k=mesh._props.Scale or V3(1,1,1)
      shape=(kind=='Sphere'or kind=='Head')and'Ball'or kind=='Cylinder'and'Cylinder'or'Block'
      size=V3(size.X*k.X,size.Y*k.Y,size.Z*k.Z)
     end
     local color=c._props.Color;local par=c._parent
     if c._class=='MeshPart'and par and par._attrs and par._attrs.PaperColor then color=par._attrs.PaperColor end
     parts[#parts+1]=string.format('{"sh":%s,"s":%s,"p":%s,"r":%s,"c":%s,"m":%s,"t":%s}',q(shape),v3(size),v3(c._props.CFrame.Position),rot(c._props.CFrame),c3(color),q(enumName(c._props.Material)or'Plastic'),n(a))
    end
   elseif c._class=='ParticleEmitter'then
    local host=partOf(c)
    if host then
     local att=c._parent and c._parent._class=='Attachment'and c._parent
     local pos=host._props.CFrame.Position;if att then pos=attWorld(att)or pos end
     local on=c._props.Enabled and(c._props.Rate or 0)>0
     local age=c._emitAt and(R.clock-c._emitAt)or -1
     local life=c._props.Lifetime and(c._props.Lifetime.Min+c._props.Lifetime.Max)/2 or 1
     if on or((c._emitted or 0)>0 and age>=0 and age<life*1.3)then
      local speed=c._props.Speed and(c._props.Speed.Min+c._props.Speed.Max)/2 or 1
      local spread=c._props.SpreadAngle;spread=type(spread)=='table'and spread.X or 0
      local acc=c._props.Acceleration;if type(acc)~='table'or acc.__type~='Vector3'then acc=V3(0,0,0)end
      local col0,col1=seqColors(c._props.Color)
      emitters[#emitters+1]=string.format('{"p":%s,"size":%s,"color":%s,"color1":%s,"rate":%s,"life":%s,"speed":%s,"count":%d,"age":%s,"ps0":%s,"ps1":%s,"tr0":%s,"tr1":%s,"tex":%s,"dir":%s,"spread":%s,"acc":%s,"drag":%s,"le":%s}',
       v3(pos),v3(host._props.Size or V3(1,1,1)),col0,col1,n(on and(c._props.Rate or 0)or 0),n(life),n(speed),c._emitted or 0,n(age),n(seqFirst(c._props.Size,.4)),n(seqLast(c._props.Size,.4)),
       n(seqFirst(c._props.Transparency,0)),n(seqLast(c._props.Transparency,0)),q(texKind(c._props.Texture)),v3(emitDir(c,host)),n(spread),v3(acc),n(c._props.Drag or 0),n(c._props.LightEmission or 0))
     end
    end
   elseif c:IsA('Light')and c._props.Enabled~=false and(c._props.Brightness or 0)>0 then
    local host=partOf(c);if host then lights[#lights+1]=string.format('{"p":%s,"color":%s,"range":%s,"brightness":%s}',v3(host._props.CFrame.Position),c3(c._props.Color),n(c._props.Range or 8),n(c._props.Brightness or 1))end
   elseif c._class=='BillboardGui'and c._props.Enabled~=false then
    local ad=c._props.Adornee or partOf(c)
    local img=c:FindFirstChildOfClass('ImageLabel')
    if ad and ad._props.CFrame and img and img._props.Visible~=false and(img._props.ImageTransparency or 0)<.98 then
     local off=c._props.StudsOffsetWorldSpace;if type(off)~='table'or off.__type~='Vector3'then off=V3(0,0,0)end
     bills[#bills+1]=string.format('{"p":%s,"size":%s,"img":%s,"color":%s,"a":%s,"rot":%s}',v3(ad._props.CFrame.Position+off),n(c._props.Size and c._props.Size.X.Scale or 1),
      q(artName(img)or'soft'),c3(img._props.ImageColor3),n(1-(img._props.ImageTransparency or 0)),n(img._props.Rotation or 0))
    end
   elseif c._class=='SurfaceGui'and c._props.Enabled~=false then
    local host=c._props.Adornee or partOf(c)
    if host and host._props.CFrame and host._props.Size then
     local hostA=1-(host._props.Transparency or 0)
     for _,g in ipairs(c:GetChildren())do
      if g._class=='ImageLabel'and g._props.Visible~=false then
       local name=artName(g)
       if name and(g._props.ImageTransparency or 0)<.98 then
        local tile='null';if enumName(g._props.ScaleType)=='Tile'and g._props.TileSize then local pps=c._props.PixelsPerStud or 50;tile='['..n(g._props.TileSize.X.Offset/pps)..','..n(g._props.TileSize.Y.Offset/pps)..']'end
        -- (its rectangle on the face, in face fractions: centre and size)
        local s,p=g._props.Size,g._props.Position;local ap=g._props.AnchorPoint;local apx,apy=ap and ap.X or 0,ap and ap.Y or 0
        local sx,sy=s and s.X.Scale or 1,s and s.Y.Scale or 1;local px,py=p and p.X.Scale or 0,p and p.Y.Scale or 0
        faces[#faces+1]=string.format('{"p":%s,"r":%s,"s":%s,"face":%s,"img":%s,"unlit":true,"tile":%s,"color":%s,"a":%s,"rot":%s,"rect":[%s,%s,%s,%s],"z":%d}',v3(host._props.CFrame.Position),rot(host._props.CFrame),v3(host._props.Size),
         q(enumName(c._props.Face)or'Front'),q(name),tile,c3(g._props.ImageColor3),n(1-(g._props.ImageTransparency or 0)),n(g._props.Rotation or 0),
         n(px+(.5-apx)*sx),n(py+(.5-apy)*sy),n(sx),n(sy),g._props.ZIndex or 1)
       end
      elseif g._class=='Frame'and g._props.Visible~=false and(g._props.BackgroundTransparency or 0)<.98 then
       local s,p=g._props.Size,g._props.Position
       strips[#strips+1]=string.format('{"p":%s,"r":%s,"s":%s,"face":%s,"rect":[%s,%s,%s,%s],"color":%s,"a":%s}',v3(host._props.CFrame.Position),rot(host._props.CFrame),v3(host._props.Size),
        q(enumName(c._props.Face)or'Front'),n(p and p.X.Scale or .5),n(p and p.Y.Scale or .5),n(s and s.X.Scale or 1),n(s and s.Y.Scale or 1),c3(g._props.BackgroundColor3),n((1-(g._props.BackgroundTransparency or 0))*math.min(1,hostA*4)))
      end
     end
    end
   elseif(c._class=='Decal'or c._class=='Texture')then
    local host=partOf(c);local content=rawget(c,'_props').TextureContent
    local name=type(content)=='string'and content:match('^r152art://(.+)$')
    if host and name and(c._props.Transparency or 0)<.98 then
     local tile=c._class=='Texture'and('['..n(c._props.StudsPerTileU or 2)..','..n(c._props.StudsPerTileV or 2)..']')or'null'
     faces[#faces+1]=string.format('{"p":%s,"r":%s,"s":%s,"face":%s,"img":%s,"unlit":false,"tile":%s,"color":%s,"a":%s,"rot":0}',v3(host._props.CFrame.Position),rot(host._props.CFrame),v3(host._props.Size),
      q(enumName(c._props.Face)or'Front'),q(name),tile,c3(c._props.Color3),n(1-(c._props.Transparency or 0)))
    end
   elseif c._class=='Beam'and c._props.Enabled~=false then
    local a0,a1=c._props.Attachment0,c._props.Attachment1
    local p0,x0=nil,nil;local p1,x1=nil,nil
    if a0 then p0,x0=attWorld(a0)end;if a1 then p1,x1=attWorld(a1)end
    if p0 and p1 then
     local col0,col1=seqColors(c._props.Color)
     beams[#beams+1]=string.format('{"a":%s,"b":%s,"ax":%s,"bx":%s,"w0":%s,"w1":%s,"c0":%s,"c1":%s,"tex":%s,"len":%s,"col0":%s,"col1":%s,"tr":%s,"le":%s,"speed":%s,"t":%s}',
      v3(p0),v3(p1),v3(x0),v3(x1),n(c._props.Width0 or 1),n(c._props.Width1 or 1),n(c._props.CurveSize0 or 0),n(c._props.CurveSize1 or 0),q(texKind(c._props.Texture)),n(c._props.TextureLength or 1),
      col0,col1,seqKeys(c._props.Transparency,0),n(c._props.LightEmission or 0),n(c._props.TextureSpeed or 1),n(R.clock))
    end
   end
  end
 end
 return '"parts":['..table.concat(parts,',')..'],"emitters":['..table.concat(emitters,',')..'],"lights":['..table.concat(lights,',')..'],"bills":['..table.concat(bills,',')..'],"beams":['..table.concat(beams,',')..'],"faces":['..table.concat(faces,',')..'],"strips":['..table.concat(strips,',')..']'
end
-- the GUI ------------------------------------------------------------------------------------------------------------------------------
-- (dump_tree falls back to a global Color3 for a colour never set, which the sandboxed CLI does not have: fill Roblox's defaults first;
-- render_gui.mjs does not apply UIAspectRatioConstraint: those frames get their constrained size for the dump)
local function dump(root,Wd,Ht)
 for _,o in ipairs(root:GetDescendants())do
  if o:IsA('GuiObject')then
   if o._props.BackgroundColor3==nil then o._props.BackgroundColor3=R.Color3.fromRGB(255,255,255)end
   if o._props.TextColor3==nil then o._props.TextColor3=R.Color3.fromRGB(27,42,53)end
   if o._props.TextStrokeColor3==nil then o._props.TextStrokeColor3=R.Color3.fromRGB(0,0,0)end
   if o._props.ImageColor3==nil then o._props.ImageColor3=R.Color3.fromRGB(255,255,255)end
  end
 end
 local undo={}
 for _,o in ipairs(root:GetDescendants())do
  local a=o:IsA('GuiObject')and o:FindFirstChildOfClass('UIAspectRatioConstraint')
  if a and o.Size and o.Size.X.Offset==0 and o.Size.Y.Offset==0 then
   local _,_,pw,ph=X.rect(o,Wd,Ht);local ratio=a.AspectRatio or 1
   local w,h=pw,ph
   if a.DominantAxis==R.Enum.DominantAxis.Height then w=h*ratio else h=w/ratio end
   local parentW,parentH=Wd,Ht
   if o.Parent and o.Parent:IsA('GuiObject')then local _,_,qw,qh=X.rect(o.Parent,Wd,Ht);parentW,parentH=qw,qh end
   undo[o]=o.Size;o._props.Size=R.UDim2.fromScale(w/math.max(1,parentW),h/math.max(1,parentH))
  end
 end
 local out=dumpTree(root,Wd,Ht)
 for o,size in pairs(undo)do o._props.Size=size end
 return out
end
-- the card in two layers: what is under the seed's viewport (its glow, halo, backdrop) and what is over it (title, odds, hint ...)
local function guiLayers(Wd,Ht)
 local under,over={},{}
 local fx=X.pg:FindFirstChild('PackOpeningEffects');if fx and fx.Enabled~=false then over[#over+1]=dump(fx,Wd,Ht)end
 local gui=X.pg:FindFirstChild('RarePullReveal')
 if gui and gui.Enabled~=false then
  local view=gui:FindFirstChild('Seed',true)
  if view and view._class=='ViewportFrame'then
   local root=view.Parent;local z=view.ZIndex or 6
   local saved={}
   for _,c in ipairs(root:GetChildren())do if c:IsA('GuiObject')then saved[c]=c._props.Visible end end
   for c in pairs(saved)do if(c.ZIndex or 1)>=z then c._props.Visible=false end end;under[#under+1]=dump(gui,Wd,Ht)
   for c,v in pairs(saved)do c._props.Visible=v end
   for c in pairs(saved)do if(c.ZIndex or 1)<=z then c._props.Visible=false end end;over[#over+1]=dump(gui,Wd,Ht)
   for c,v in pairs(saved)do c._props.Visible=v end
  else over[#over+1]=dump(gui,Wd,Ht)end
 end
 return under,over
end
-- one frame ------------------------------------------------------------------------------------------------------------------------------
local function frame(name,Wd,Ht,label,tag,opts)
 opts=opts or{}
 local cam=W.workspace.CurrentCamera
 local stage=W.workspace:FindFirstChild('_RarePullStage')
 local inStage=cam.CameraType==R.Enum.CameraType.Scriptable and stage~=nil
 local roots={}
 if inStage then roots={stage}else
  roots={X.char,oc}
  for _,nm in ipairs({'_LocalSeedPackEffects','_RarePullWorld'})do local f=W.workspace:FindFirstChild(nm);if f then roots[#roots+1]=f end end
 end
 local eye=opts.Eye or cam.CFrame.Position;local target=opts.Target or(eye+cam.CFrame.LookVector*10);local fov=opts.Fov or cam.FieldOfView or 70
 local g=cam:FindFirstChild('RarePullGrade');local b=cam:FindFirstChild('RarePullBlur')
 local grade=(g and not opts.NoGui)and string.format('{"b":%s,"c":%s,"s":%s,"tint":%s}',n(g.Brightness or 0),n(g.Contrast or 0),n(g.Saturation or 0),c3(g.TintColor))or'null'
 local under,over={},{}
 if not opts.NoGui then under,over=guiLayers(Wd,Ht)end
 local vp='null'
 local gui=X.pg:FindFirstChild('RarePullReveal');local view=gui and gui:FindFirstChild('Seed',true)
 if not opts.NoGui and view and view._class=='ViewportFrame'and view.Visible and(view.ImageTransparency or 1)<.98 and view.CurrentCamera then
  local x,y,w,h=X.rect(view,Wd,Ht);local s=math.min(w,h);x=x+(w-s)/2;y=y+(h-s)/2
  local scale=view:FindFirstChildOfClass('UIScale');local k=scale and scale.Scale or 1
  local vc=view.CurrentCamera
  vp=string.format('{"rect":[%s,%s,%s,%s],"alpha":%s,"scale":%s,"eye":%s,"target":%s,"fov":%s,%s}',n(x),n(y),n(s),n(s),n(1-view.ImageTransparency),n(k),v3(vc.CFrame.Position),v3(vc.CFrame.Position+vc.CFrame.LookVector*10),n(vc.FieldOfView or 30),world({view}))
 end
 local kind=inStage and('stage'..(M.Active()and M.Active().Rank or 8))or'world'
 print('FRAME '..name..' '..string.format('{"w":%d,"h":%d,"label":%s,"tag":%s,"tree":%s,"kind":%s,"eye":%s,"target":%s,"fov":%s,"grade":%s,"blur":%s,%s,"under":[%s],"guis":[%s],"viewport":%s}',
  Wd,Ht,q(label),q(tag or''),q(TREE),q(kind),v3(eye),v3(target),n(fov),grade,n((b and not opts.NoGui)and b.Size or 0),world(roots),table.concat(under,','),table.concat(over,','),vp))
end
-- driving a reveal ------------------------------------------------------------------------------------------------------------------------
local spc=R.new('LocalScript');spc.Name='SeedPackClient';W.load('SeedPackClient',spc)
local pof=R.new('LocalScript');pof.Name='PackOpeningFeedback';W.load('PackOpeningFeedback',pof)
local function setDevice(phone)
 W.UIS.TouchEnabled=phone;W.UIS.KeyboardEnabled=not phone;X.lowFx=false
 W.workspace.CurrentCamera.ViewportSize=phone and R.Vector2.new(844,390)or R.Vector2.new(1280,720)
end
local function worldCamera()
 local cam=W.workspace.CurrentCamera;cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70
 cam.CFrame=R.CFrame.lookAt(V3(5.2,6.4,90.6),V3(0,4.4,99.2))
end
local function clearAll()
 M.Abort('preview');W.module('RarePullWorld').Clear();R.advance(6);worldCamera()
 for _,c in ipairs(X.char:GetChildren())do if c:IsA('Tool')or c.Name=='CarriedSeed'then c:Destroy()end end
 for _,c in ipairs(oc:GetChildren())do if c.Name=='CarriedSeed'then c:Destroy()end end
end
-- the opener's own pack; shots(tl, run) -> {{label, seconds after the open, opts}}
local function play(rank,shots,Wd,Ht,prefix,tag)
 clearAll()
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='pv'..rank,Stage=2},nil);tool.Activated=R.signal();tool.Enabled=false;tool.Parent=X.char
 local seedId=X.byRank[rank];local spec=Rules.SeedDesignById[seedId]
 tool.ToolTip='Desert Seed Pack\n'..(spec and spec.name or seedId)..': 1/'..({'2','4','16','60','400','5K','83.3K','1.67B'})[rank]
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None')
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealDuration',Rules.GetRevealDuration(names[rank]));bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local t0=R.clock
 W.frames(1,1/30)
 local run=M.Active();local tl=run.TL
 local list=shots(tl,run)
 local dur=Rules.GetRevealDuration(names[rank])
 for i,s in ipairs(list)do
  while R.clock-t0<s[2]-1e-6 do
   W.frames(1,1/30)
   if bag.Parent and R.clock-t0>=dur then bag:Destroy();tool:Destroy()end -- the server ends the opening (the seed is in the hand)
  end
  local opts=s[3];if type(opts)=='function'then opts=opts(run)end
  frame(string.format('%s_%02d',prefix,i),Wd,Ht,s[1],tag,opts)
 end
 if bag.Parent then bag:Destroy()end;if tool.Parent then tool:Destroy()end
end
-- someone else's pack, seen from where we stand; shots(wtl) -> {{label, seconds, opts}}
local function watch(rank,shots,Wd,Ht,prefix,tag)
 clearAll()
 local seedId=X.byRank[rank]
 local bag=Visuals.CarryBag(oc,2,'Pack06',1,1,'None')
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealDuration',Rules.GetRevealDuration(names[rank]));bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local t0=R.clock;local wtl=L.WorldTimeline(rank)
 local list=shots(wtl)
 local dur=Rules.GetRevealDuration(names[rank])
 for i,s in ipairs(list)do
  while R.clock-t0<s[2]-1e-6 do W.frames(1,1/30);if bag.Parent and R.clock-t0>=dur then bag:Destroy()end end
  frame(string.format('%s_%02d',prefix,i),Wd,Ht,s[1],tag,s[3])
 end
 if bag.Parent then bag:Destroy()end
end
local FEET=V3(30,0,60)
local wide={Eye=FEET+V3(-8,3,52),Target=FEET+V3(0,30,0),Fov=70}
local close={Eye=FEET+V3(-7,2.4,13),Target=FEET+V3(0,3.2,0),Fov=60}
local function stagePos(run,part)return part.CFrame.Position end
local strips={
 ladder=function(tl)return{{'SUSPENSE',tl.Burst*.6},{'BURST',tl.Burst+.1},{'1 IN N',tl.Odds+.12},{'SEED',tl.FloatEnd-.08}}end,
 [6]=function(tl)return{{'LOCKED IN THE VOID',tl.Lock+.4},{'CRACKS OF LIGHT',tl.Silence-.12},{'THE HIT',tl.Climax+.12},{'SECRET + 1 IN N',tl.Odds+.15},{'THE SEED FLOATS DOWN',tl.FloatEnd-.05}}end,
 [7]=function(tl)return{{'PLANETS ALIGN',tl.Align3+.08},{'IT SPINS UP',tl.Implode-.15},{'SUPERNOVA',tl.Climax+.12},{'COSMIC + 1 IN N',tl.Odds+.35},{'THE SEED FLOATS DOWN',tl.FloatEnd-.05}}end,
 [8]=function(tl)return{{'CARRIED TO THE THRONE',tl.SceneIn+1.25},{'THE CROWN DESCENDS',tl.CrownStart+1.0},{'THE CROWNED PACK',tl.Silence-.12},{'THE HIT',tl.Climax+.12},{'KING + 1 IN N',tl.Odds+.15},{'THE SEED FLOATS DOWN',tl.FloatEnd-.05}}end,
}
if SET=='main'then
 setDevice(false)
 for _,rank in ipairs({1,3,4,5})do play(rank,strips.ladder,1280,720,'ladder'..rank,names[rank])end
 for rank=6,8 do play(rank,strips[rank],1280,720,'scene'..rank..'d',names[rank]..' desktop')end
 setDevice(true);play(8,strips[8],844,390,'scene8p','King phone')
 setDevice(false)
 watch(6,function(w)return{{'AN ONLOOKER SEES THE BEAM LAND',w.Burst+.05,wide},{'THE IMPACT',w.Burst+.25,close},{'THE AFTERGLOW',w.Burst+3,close}}end,1280,720,'world6','Secret, seen by others')
elseif SET=='king'then
 setDevice(false)
 play(8,function(tl)local out={};local t=.05;while t<tl.Back+1.0 do out[#out+1]={string.format('%.1f s',t),t};t+=.1 end;return out end,640,360,'king','King')
elseif SET=='planets'then
 setDevice(false)
 -- (a close-up from a little to the side of the scene camera, so a planet that passes in front of another is seen alone)
 local function near(i,dist,turn)return function(run)
  local p=run.Scene.Planets[i].Body;local pos=p.CFrame.Position;local cam=W.workspace.CurrentCamera
  local d=(cam.CFrame.Position-pos).Unit;local c,s=math.cos(turn or 0),math.sin(turn or 0)
  local dir=V3(d.X*c-d.Z*s,d.Y,d.X*s+d.Z*c);return {Eye=pos+dir*dist+V3(0,.2,0),Target=pos,Fov=38,NoGui=true}
 end end
 play(7,function(tl)return{{'THE STAGE: STAR MAP, NEBULAE, THREE PLANETS',tl.Align2+.1,{NoGui=true}},{'THE CRATERED WORLD (THE GAS GIANT BEYOND IT)',tl.SceneIn+.5,near(1,4.2,.7)},{'THE GAS GIANT (PASSING BEHIND)',tl.SceneIn+.9,near(2,6,-.7)},
  {'THE RINGED ICE WORLD',tl.SceneIn+1.3,near(3,4.6)},{'PLANETS ALIGN',tl.Align3+.08},{'SUPERNOVA',tl.Climax+.12}}end,1280,720,'planets','Cosmic')
elseif SET=='beam'then
 setDevice(false)
 for rank=6,8 do
  watch(rank,function(w)return{{'COMING DOWN',w.Burst-.07,wide},{'LANDS',w.Burst+.02,wide},{'IMPACT (CLOSE)',w.Burst+.12,close},{'RINGS, DUST, DEBRIS',w.Burst+.4,close},{'HOLDS, EMBERS RISE',w.Burst+1.0,close},{'THINS OUT',w.Burst+2.2,wide}}end,
   1280,720,'beam'..rank,names[rank]..' sky beam (onlooker)')
 end
 play(8,function(tl)return{{'THE GOLD CARRY BEAM',tl.SceneIn+.9,{NoGui=true}},{'THE CROWN BEAM',tl.CrownStart+.9,{NoGui=true}}}end,1280,720,'beamking','King\'s gold beams')
 watch(5,function()local b=L.BurstAt(5);return{{'MYTHIC: ITS SMALLER BEAM',b+.05,{Eye=FEET+V3(-6,4,14),Target=FEET+V3(0,6,0),Fov=60}},{'',b+.3,{Eye=FEET+V3(-6,4,14),Target=FEET+V3(0,6,0),Fov=60}}}end,1280,720,'beam5','Mythic flourish')
elseif SET=='assets'then
 setDevice(false)
 play(6,function(tl)return{{'SECRET: THE VAULT',tl.Lock+.45,{NoGui=true}}}end,1280,720,'asset6','')
 play(7,function(tl)return{{'COSMIC: DEEP SPACE',tl.Align3+.08,{NoGui=true}}}end,1280,720,'asset7','')
 play(8,function(tl)return{{'KING: THE THRONE ROOM',tl.CrownStart+.95,{NoGui=true}}}end,1280,720,'asset8','')
 watch(6,function(w)return{{'THE SKY BEAM',w.Burst+.3,wide}}end,1280,720,'assetbeam','')
 play(4,function(tl)return{{'THE SEED CARD (LEGENDARY)',tl.FloatEnd-.1}}end,1280,720,'assetcard','')
 play(7,function(tl)return{{'THE COSMIC TITLE',tl.Odds+.4}}end,1280,720,'assettitle','')
end
