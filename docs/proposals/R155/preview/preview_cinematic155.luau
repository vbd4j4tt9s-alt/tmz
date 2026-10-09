--!nocheck
-- R155 preview (not a test, not game code): plays the REAL Secret / Cosmic / King reveals on the Roblox mock (the R151 test environment: the real
-- RarePull* modules with the R155 cinematic camera RarePullCamera155, PackOpeningFeedback, SeedPackClient, SeedCollect154 and the Hotbar; R152's
-- frame dump, as in R154's preview_cinematic154.luau) and prints every frame AS THE GAME SETS IT: the Camera's CFrame (its dutch tilt included),
-- FieldOfView and its depth of field (RarePullDof) are read off the camera, nothing is computed here. Each clip plays the whole scene, waits a few
-- seconds on the hero shot ("click to collect!"), then clicks: the fade to black (0.35 s), the world (the player's own camera, as before) and the
-- seed's flight into its hotbar slot. Prints FRAME lines (R154's format plus the flying seed's "viewport") for render_cinematic155.mjs, and a BEATS
-- line per scene (the beats, the sound cues, the wait and the click) for the beat ruler.
-- SET: 'secret' | 'cosmic' | 'king' (every 1/FPS s), 'board' (the keyframes; the SKIP button; phone / low quality; Reduced Motion; an onlooker). WAIT: seconds on the
-- hero shot before the click (3). WIDTH / HEIGHT: the frame (1280 x 720: the hotbar and the flight are laid out in pixels).
local SET=SET or'secret';local FPS=FPS or 25;local WAIT=WAIT or 3
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
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules');local M=W.module('RarePullCinematic');local Cam155=W.module('RarePullCamera155')
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
-- one frame: the world (or the stage) as the game left it this frame, the card / hotbar GUI, the flying seed ------------------------------------
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
 local up=opts.Up or cam.CFrame.UpVector
 if opts.Eye and not opts.Up then local f=(target-eye).Unit;local r=f:Cross(V3(0,1,0)).Unit;up=r:Cross(f)end -- (a given view: level, no tilt)
 local g=cam:FindFirstChild('RarePullGrade');local b=cam:FindFirstChild('RarePullBlur');local d=cam:FindFirstChild('RarePullDof')
 local grade=g and string.format('{"b":%s,"c":%s,"s":%s,"tint":%s}',n(g.Brightness or 0),n(g.Contrast or 0),n(g.Saturation or 0),c3(g.TintColor))or'null'
 local dof=d and(d.FarIntensity or 0)+(d.NearIntensity or 0)>0 and string.format('{"focus":%s,"radius":%s,"far":%s,"near":%s}',n(d.FocusDistance),n(d.InFocusRadius),n(d.FarIntensity),n(d.NearIntensity))or'null'
 local under,over={},{}
 local hb=X.pg:FindFirstChild('ChestToolHotbar');if hb and hb.Enabled~=false then under[#under+1]=dump(hb,Wd,Ht)end
 local u2,o2=guiLayers(Wd,Ht);for _,x in ipairs(u2)do under[#under+1]=x end;for _,x in ipairs(o2)do over[#over+1]=x end
 local vp='null'
 local fly=X.pg:FindFirstChild('SeedCollectFly');local fv=fly and fly:FindFirstChild('Seed')
 if fv and fv.CurrentCamera and(fv.ImageTransparency or 1)<.98 then
  local s=fv.Size.X.Offset;local x,y=fv.Position.X.Offset-s/2,fv.Position.Y.Offset-s/2;local vc=fv.CurrentCamera
  vp=string.format('{"rect":[%s,%s,%s,%s],"alpha":%s,"scale":1,"eye":%s,"target":%s,"fov":%s,%s}',n(x),n(y),n(s),n(s),n(1-fv.ImageTransparency),v3(vc.CFrame.Position),v3(vc.CFrame.Position+vc.CFrame.LookVector*10),n(vc.FieldOfView or 30),world({fv}))
 end
 local kind=inStage and('stage'..(M.Active()and M.Active().Rank or opts.Rank or 8))or'world'
 print('FRAME '..name..' '..string.format('{"w":%d,"h":%d,"label":%s,"tag":%s,"tree":"R155","kind":%s,"eye":%s,"target":%s,"up":%s,"fov":%s,"dof":%s,"shot":%s,"move":%s,"t":%s,"grade":%s,"blur":%s,%s,"under":[%s],"guis":[%s],"viewport":%s}',
  Wd,Ht,q(label),q(tag or''),q(kind),v3(eye),v3(target),v3(up),n(fov),dof,q(opts.Shot or''),q(opts.Move or''),n(opts.T or 0),grade,n(b and b.Size or 0),world(roots),table.concat(under,','),table.concat(over,','),vp))
end
-- driving a reveal ------------------------------------------------------------------------------------------------------------------------
local spc=R.new('LocalScript');spc.Name='SeedPackClient';W.load('SeedPackClient',spc)
local pof=R.new('LocalScript');pof.Name='PackOpeningFeedback';W.load('PackOpeningFeedback',pof)
-- the hotbar (the collected seed flies into its slot), laid out as the engine lays it out (R154 collect_frames154.luau)
local Collect=W.module('SeedCollect154')
do local Meshes=W.module('ApprovedPlantMeshes');local cache={}
 Meshes.Get=function(key)local p=cache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=V3(1,1,1);cache[key]=p end;return p end
 Meshes.Status=function()return'Ready'end end
local function setXY(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
  local x=px+p.X.Scale*pw+p.X.Offset-a.X*w;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h
  setXY(c,'AbsoluteSize',R.Vector2.new(w,h));setXY(c,'AbsolutePosition',R.Vector2.new(x,y));lay(c,x,y,w,h)
 end end
end
W.Run.RenderStepped:Connect(function()
 local g=X.pg:FindFirstChild('ChestToolHotbar');local vp=W.workspace.CurrentCamera.ViewportSize
 if g then lay(g,0,0,vp.X,vp.Y)end
end)
local function live(t,manual)t.Activated=t.Activated or R.signal();if t.ManualActivationOnly==nil then t.ManualActivationOnly=manual==true end;return t end
live(F.shovel(W,E.bag),true);live(F.fruit(W,E.bag,'AppleSeed',1,'None',240,1))
do local hb=R.new('LocalScript');hb.Name='Hotbar';W.load('Hotbar',hb)end
W.frames(10,1/30)
local HEAD=V3(0,6.65,100)
local LIVE=R.CFrame.lookAt(V3(3.1,10.6,111.4),HEAD) -- the player's own camera: behind and above, over the right shoulder (Roblox's default zoom)
local function setDevice(kind,vp)
 local phone=kind=='phone'
 W.UIS.TouchEnabled=phone;W.UIS.KeyboardEnabled=not phone;X.lowFx=kind=='low'
 W.workspace.CurrentCamera.ViewportSize=vp or(phone and R.Vector2.new(844,390)or R.Vector2.new(1280,720))
end
local function worldCamera()
 local cam=W.workspace.CurrentCamera;cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=LIVE;cam.Focus=R.CFrame.new(HEAD.X,HEAD.Y,HEAD.Z)
end
local function clearAll()
 M.Abort('preview');W.module('RarePullWorld').Clear();R.advance(6);worldCamera()
 for _,c in ipairs(X.char:GetChildren())do if c:IsA('Tool')or c.Name=='CarriedSeed'then c:Destroy()end end
 for _,c in ipairs(E.bag:GetChildren())do if c:GetAttribute('GardenSeed')then c:Destroy()end end
 for _,c in ipairs(oc:GetChildren())do if c.Name=='CarriedSeed'then c:Destroy()end end
end
local function beats(rank,run,press)
 local tl=run.TL;local o={}
 for k,v in pairs(tl)do if type(v)=='number'then o[#o+1]=string.format('%s:%s',q(k),n(v))end end
 if press then o[#o+1]=string.format('"Press":%s,"Settle":%s',n(press),n(run.Cam and run.Cam.Settle or tl.FloatEnd))end
 local cues={}
 for _,c in ipairs(L.SceneCues(rank,tl))do cues[#cues+1]=string.format('[%s,%s]',n(c.PeakAt or c.At),q(c.Slot))end
 local cuts={};for _,c in ipairs(run.Cam and run.Cam.Cuts or{})do cuts[#cuts+1]=n(c)end
 print('BEATS '..rank..' {"tl":{'..table.concat(o,',')..'},"cues":['..table.concat(cues,',')..'],"cuts":['..table.concat(cuts,',')..']}')
end
-- what the caption says: the shot the game is in (the cinematic camera's own name for it), or the world
local function caption(run)
 local cam=W.workspace.CurrentCamera
 if run.InStage and cam.CameraType==R.Enum.CameraType.Scriptable then
  if run.Collected then return'COLLECTED','the click: the fade to black (0.35 s); the camera holds'end
  local rig=run.Cam;if rig then return rig.Name,rig.Move end
  return'TODAY\'S CAMERA','(no cinematic camera)'
 end
 if run.Collected then return'THE WORLD','the player\'s own camera, as before (no hand-back move); the seed flies into its hotbar slot'end
 return'THE WORLD','the player\'s own camera; today\'s lens-only push, then the cut to black'
end
-- the opener's own pack: frames at the clip's times (seconds on the scene's clock); the click WAIT s after the hero shot has settled
local opened=0
local function play(rank,times,Wd,Ht,prefix,tag,opts)
 opts=opts or{}
 clearAll();opened+=1;local id='pv155-'..opened
 local tool=live(F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId=id,Stage=2},nil));tool.Enabled=false;tool.Parent=X.char
 local seedId=X.byRank[rank];local spec=Rules.SeedDesignById[seedId];local rarity=Rules.GetRarity(seedId)
 tool.ToolTip='Desert Seed Pack\n'..(spec and spec.name or seedId)..': 1/'..({'2','4','16','60','400','5K','83.3K','1.67B'})[rank]
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None')
 local dur=Rules.GetRevealDuration(rarity)
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',rarity);bag:SetAttribute('Weather','None');bag:SetAttribute('RevealDuration',dur);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local t0=R.clock
 local function step(dt)
  W.frames(1,dt)
  if bag.Parent and R.clock-t0>=dur then -- the server ends the opening: the pack goes, the seed's tool arrives (held back until it has flown in)
   bag:Destroy();tool:Destroy()
   local t=live(F.tool(W,spec and spec.name or seedId,{GardenSeed=true,SeedInventoryId=id,SeedId=seedId,SeedScale=1,Mutation='None',Weather='None',Rarity=rarity,Stage=2},E.bag),true)
   X.hum:EquipTool(t)
  end
 end
 step(1/60)
 local run=M.Active();if not run or run.Kind~='Scene'then error('no story scene: '..tostring(run and run.Kind)..' '..tostring(run and run.Why))end
 local tl=run.TL
 local press=opts.Press or(tl.FloatEnd+Cam155.SettleSeconds+WAIT)
 beats(rank,run,press)
 local list=type(times)=='function'and times(tl,press)or times
 for i,s in ipairs(list)do
  local want=type(s)=='table'and s[1]or s
  while run.Clock()<want-1e-6 do
   if not run.Collected and run.Clock()>=press-1e-6 then local b=X.pg:FindFirstChild('Backdrop',true);if b then b.Activated:Fire()end;if not run.Collected then M.Collect()end end
   local left=math.min(1/60,want-run.Clock());if not run.Collected then left=math.min(left,press-run.Clock())end
   step(math.max(1e-4,left))
  end
  local t=run.Clock()
  local shot,move=caption(run)
  local label=type(s)=='table'and s[2]or string.format('%.2f s',t)
  frame(string.format('%s_%03d',prefix,i),Wd,Ht,label,tag,{T=t,Shot=shot,Move=move,Rank=rank})
 end
 -- (nothing left behind for the next clip)
 if not run.Collected then M.Collect()end
 local g=0;while(M.Active()or Collect.Flying()>0)and g<600 do step(1/30);g+=1 end
 if bag.Parent then bag:Destroy()end;if tool.Parent then tool:Destroy()end
 return run
end
-- someone else's pack, seen from where we stand (an onlooker: nothing of the camera changes)
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
  local o=s[3];o.Shot='ONLOOKER';o.Move='their own camera: never moved';o.T=R.clock-t0
  frame(string.format('%s_%02d',prefix,i),Wd,Ht,s[1],tag,o)
 end
 if bag.Parent then bag:Destroy()end
end
local function every(from,to,fps)local out={};local k=math.ceil(from*fps-1e-6);while k/fps<to-1e-6 do out[#out+1]=k/fps;k+=1 end;return out end
local scenes={secret=6,cosmic=7,king=8}
local WD,HT=WIDTH or 1280,HEIGHT or 720
if scenes[SET]then
 setDevice('desktop')
 local rank=scenes[SET]
 -- the whole scene, the wait on the hero shot, the click, the way out, the world and the flight
 play(rank,ONLY or function(tl,press)return every(0,press+M.SceneExit+1.9,FPS)end,WD,HT,SET,names[rank])
elseif SET=='board'then
 local BW,BH=768,432
 setDevice('desktop',R.Vector2.new(BW,BH))
 play(6,function(tl,press)return{{.30,'the world: today\'s push'},{tl.SceneIn+.5,'S1 out of the dark (rack focus)'},{tl.Glitch1+.08,'S2 cut on the glitch, +8 deg'},{tl.Glitch2+.08,'S3 cut on the glitch, -8.5 deg'},
  {tl.Lock+.5,'S4 the lock: a ratchet on each click'},{tl.Silence-.02,'S5 into the cracks, then STOP'},{tl.Climax+.25,'S6 the hit throws it back'},{tl.Rise+.1,'S7 crane up with the seed'},{press-.1,'the result waits ("click to collect!")'},{press+M.SceneExit+.25,'the world as before; the seed flies home'}}end,BW,BH,'b6','Secret')
 play(7,function(tl,press)return{{.40,'the world: today\'s push'},{tl.SceneIn+.2,'C1 cosmic zoom-out: close'},{tl.Align2,'C1 ... out to deep space'},{tl.SpinUp,'C1 settles on the planets\' line'},
  {tl.Implode-.1,'C2 vortex push-in'},{tl.Silence-.02,'C3 crash into the core, STOP'},{tl.Climax+.3,'C4 the supernova blows it back'},{tl.StarIn,'C5 the star leads it home'},{press-.1,'the result waits ("click to collect!")'},{press+M.SceneExit+.25,'the world as before; the seed flies home'}}end,BW,BH,'b7','Cosmic')
 play(8,function(tl,press)return{{.45,'the world: today\'s push'},{tl.SceneIn+.5,'K1 crane down the great hall'},{tl.SceneIn+1.3,'K2 tracking past the pillars'},{tl.CrownStart+.3,'K3 look up: the crown descends'},
  {tl.CrownOn,'K3 the crown lands'},{tl.Silence-.02,'K4 low push-in, then STOP'},{tl.Climax+.25,'K5 the hit throws it back'},{tl.Rise+.2,'K6 crane up, the crowned seed'},{press-.1,'the result waits ("click to collect!")'},{press+M.SceneExit+.25,'the world as before; the seed flies home'}}end,BW,BH,'b8','King')
 -- R155: the SKIP button at the bottom right, from SkipFrom to the hit: the only skip (owner: "... u can only skip at the bottom right of the screen")
 play(6,function(tl)return{{tl.SkipFrom+.3,'SKIP, bottom right: the only skip'}}end,BW,BH,'bs','The SKIP button')
 -- phones / low quality: the same shots, the light stage, the depth of field on (owner: "background blur on all devices")
 setDevice('phone');play(8,function(tl)return{{tl.SceneIn+1.3,'phone 844x390: K2'},{tl.SkipFrom+.4,'phone: SKIP clear of the thumb controls'},{tl.CrownOn,'phone 844x390: crowned'},{tl.FloatEnd+1,'phone 844x390: the seed'}}end,844,390,'bp','Phones and low quality')
 setDevice('low',R.Vector2.new(BW,BH));W.UIS.GamepadEnabled=true -- (R155: a gamepad: the SKIP button shows its B)
 play(7,function(tl)return{{tl.SkipFrom+.4,'low quality, a gamepad: SKIP (B)'},{tl.Align3,'low quality: C1'},{tl.StarIn+.3,'low quality: the star'}}end,BW,BH,'bl','Phones and low quality')
 W.UIS.GamepadEnabled=false
 setDevice('desktop',R.Vector2.new(BW,BH))
 -- Reduced Motion: still shots, cuts on the Calm beats (a still depth of field)
 W.service('GuiService').ReducedMotionEnabled=true
 play(6,function(tl)return{{tl.SceneIn+.2,'Secret: a low still'},{tl.Lock+.1,'Secret: cut to the lock'},{tl.Climax+.6,'Secret: the still hero, 37%'}}end,BW,BH,'bc6','Reduced Motion')
 play(8,function(tl)return{{tl.CrownStart+.6,'King: one still, the crown comes down'},{tl.Climax+.6,'King: the still hero, 37%'}}end,BW,BH,'bc8','Reduced Motion')
 W.service('GuiService').ReducedMotionEnabled=false
 -- an onlooker: their camera is never moved; they see the sky beam land on the puller
 local FEET=V3(30,0,60)
 watch(8,function(w)return{{'the beam lands',w.Burst+.05,{Eye=FEET+V3(-8,3,52),Target=FEET+V3(0,30,0),Fov=70}},{'the impact',w.Burst+.3,{Eye=FEET+V3(-10,3.2,10),Target=FEET+V3(0,3.2,0),Fov=60}}}end,BW,BH,'bo','Onlookers')
end
