--!nocheck
-- R151 preview (not a test): plays the REAL reveals on the Roblox mock (RarePullCinematic / Scenes / Card / Audio / World, the real
-- PackOpeningFeedback and SeedPackClient, R151 test environment) and prints, at chosen moments, everything the screen shows:
--   FRAME <name> <json>  - the world or the hidden stage (parts, particle emitters, lights, the seed aura's soft glows and beams), the camera
--                          (eye, target, vertical field of view), the colour grade / blur on the camera, the screen GUI tree (dump_tree,
--                          the R150 format) and, for a seed card, its viewport (rectangle, camera and the seed's parts).
-- run_rare_pull_preview.sh renders the world with three.js (rare_pull.html), the GUI with R150's render_gui.mjs, and composes the strips.
-- SET: 'strips' (every tier, desktop; Secret / Cosmic / King also phone) or 'gif' (the King scene every 0.2 s, desktop).
local SET=SET or'strips'
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local R=W.R
local dumpTree=require('./dump_tree')
-- (dump_tree falls back to a global Color3 for a colour never set, which the sandboxed CLI does not have: fill Roblox's defaults first)
local function dump(root,Wd,Ht)
 for _,o in ipairs(root:GetDescendants())do
  if o:IsA('GuiObject')then
   if o._props.BackgroundColor3==nil then o._props.BackgroundColor3=R.Color3.fromRGB(255,255,255)end
   if o._props.TextColor3==nil then o._props.TextColor3=R.Color3.fromRGB(27,42,53)end
   if o._props.TextStrokeColor3==nil then o._props.TextStrokeColor3=R.Color3.fromRGB(0,0,0)end
  end
 end
 -- render_gui.mjs does not apply UIAspectRatioConstraint: give those frames their constrained size for the dump, then put them back
 local undo={}
 for _,o in ipairs(root:GetDescendants())do
  local a=o:IsA('GuiObject')and o:FindFirstChildOfClass('UIAspectRatioConstraint')
  if a and o.Size and o.Size.X.Offset==0 and o.Size.Y.Offset==0 then
   local px,py,pw,ph=X.rect(o,Wd,Ht);local ratio=a.AspectRatio or 1
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
local V3,CF=R.Vector3.new,R.CFrame.new
local noop=function()end
function R.Inst:Play()local own=rawget(self,'_props').Play;if own then return own(self)end end
function R.Inst:Stop()local own=rawget(self,'_props').Stop;if own then return own(self)end end
function R.Inst:Pause()end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
local Mixer=W.module('AudioMixer');Mixer.Start()
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules');local M=W.module('RarePullCinematic')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
-- a blocky avatar so the world frames have someone holding the pack (the real avatar is not available offline)
do local char=X.char
 local skin,shirt,pants=R.Color3.fromRGB(255,204,153),R.Color3.fromRGB(70,120,220),R.Color3.fromRGB(40,44,60)
 local function limb(name,size,pos,color)local p=R.new('Part');p.Name=name;p.Size=size;p.CFrame=CF(pos.X,pos.Y,pos.Z);p.Color=color;p.Material=R.Enum.Material.SmoothPlastic;p.Parent=char;return p end
 local up=char:FindFirstChild('UpperTorso');up.Color=shirt;up.Material=R.Enum.Material.SmoothPlastic
 limb('Head',V3(1.2,1.2,1.2),V3(0,6.65,100),skin);limb('LeftUpperArm',V3(1,2,1),V3(-1.5,5,100),shirt);limb('RightUpperArm',V3(1,2,1),V3(1.5,5,100),shirt)
 limb('LeftLeg',V3(1,4,1),V3(-.5,2,100),pants);limb('RightLeg',V3(1,4,1),V3(.5,2,100),pants)
 X.root.Transparency=1
end
-- JSON ------------------------------------------------------------------------------------------------------------------------------------
local function n(v)if v~=v or v==math.huge or v==-math.huge then return'0'end;return string.format('%.4f',v)end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function c3(c)if not c then return'[255,255,255]'end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function v3(v)return'['..n(v.X)..','..n(v.Y)..','..n(v.Z)..']'end
local function enumName(e)if e==nil then return nil end;if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local function seqColor(s)if s==nil then return nil end;if s.R then return s end;if s.A and s.A.R then return s.A end;if type(s.A)=='table'and s.A[1]then return s.A[1].V end;return nil end
local function seqNum(s,d)if type(s)=='number'then return s end;if type(s)=='table'then if type(s.A)=='number'then return s.A end;if type(s.A)=='table'and s.A[1]then return s.A[1].V end end;return d end
local function hidden(o)local x=o;while x do if x._props and(x._props.Enabled==false)and(x:IsA('ScreenGui')or x:IsA('BillboardGui'))then return true end;x=x._parent end;return false end
local function partOf(o)local x=o;while x do if x:IsA('BasePart')and x._props.CFrame then return x end;x=x._parent end;return nil end
-- every visible part / emitter / light / soft glow / beam under the roots
local function world(roots,keep)
 local parts,emitters,lights,glows,beams={},{},{},{},{}
 for _,root in ipairs(roots)do
  local list=root:GetDescendants();if root:IsA('BasePart')then table.insert(list,1,root)end
  for _,c in ipairs(list)do
   if c:IsA('BasePart')and(not keep or keep(c))then
    local t=c._props.Transparency or 0;local ltm=c._props.LocalTransparencyModifier or 0;local a=1-(1-t)*(1-ltm)
    if a<.995 and c._props.CFrame and c._props.Size then
     local r=c._props.CFrame.R;local shape=c._class=='MeshPart'and'Pouch'or enumName(c._props.Shape)or'Block'
     local size=c._props.Size
     local mesh=c:FindFirstChildOfClass('SpecialMesh') -- (the seed art: spheres / cylinders scaled by a SpecialMesh)
     if mesh then
      local kind=enumName(mesh._props.MeshType)or'Brick';local k=mesh._props.Scale or V3(1,1,1)
      shape=(kind=='Sphere'or kind=='Head')and'Ball'or kind=='Cylinder'and'Cylinder'or'Block'
      size=V3(size.X*k.X,size.Y*k.Y,size.Z*k.Z)
     end
     local color=c._props.Color;local par=c._parent
     if c._class=='MeshPart'and par and par._attrs and par._attrs.PaperColor then color=par._attrs.PaperColor end
     parts[#parts+1]=string.format('{"sh":%s,"s":%s,"p":%s,"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"c":%s,"m":%s,"t":%s}',q(shape),v3(size),v3(c._props.CFrame.Position),
      n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),c3(color),q(enumName(c._props.Material)or'Plastic'),n(a))
    end
   elseif c._class=='ParticleEmitter'then
    local host=partOf(c)
    local att=c._parent and c._parent._class=='Attachment'and c._parent
    local pos=host and host._props.CFrame.Position
    local ap=att and att._props.Position;if type(ap)~='table'or ap.__type~='Vector3'then ap=V3(0,0,0)end -- (the mock's default Position is not a Vector3)
    if att and host then pos=(host._props.CFrame*CF(ap.X,ap.Y,ap.Z)).Position end
    if pos and((c._props.Enabled and(c._props.Rate or 0)>0)or(c._emitted or 0)>0)then
     local life=c._props.Lifetime and(c._props.Lifetime.Min+c._props.Lifetime.Max)/2 or 1
     local speed=c._props.Speed and(c._props.Speed.Min+c._props.Speed.Max)/2 or 1
     emitters[#emitters+1]=string.format('{"p":%s,"size":%s,"color":%s,"rate":%s,"life":%s,"speed":%s,"count":%d,"ps":%s,"smoke":%s}',v3(pos),v3(host._props.Size or V3(1,1,1)),
      c3(seqColor(c._props.Color)),n(c._props.Enabled and(c._props.Rate or 0)or 0),n(life),n(speed),c._emitted or 0,n(seqNum(c._props.Size,.4)),tostring((c._props.Texture or''):find('smoke')~=nil))
    end
   elseif c:IsA('Light')and c._props.Enabled~=false and(c._props.Brightness or 0)>0 then
    local host=partOf(c);if host then lights[#lights+1]=string.format('{"p":%s,"color":%s,"range":%s,"brightness":%s}',v3(host._props.CFrame.Position),c3(c._props.Color),n(c._props.Range or 8),n(c._props.Brightness or 1))end
   elseif c._class=='BillboardGui'and c._props.Enabled~=false then
    local ad=c._props.Adornee or partOf(c)
    local img=c:FindFirstChildOfClass('ImageLabel')
    if ad and ad._props.CFrame and img and(img._props.ImageTransparency or 0)<.98 then
     glows[#glows+1]=string.format('{"p":%s,"size":%s,"color":%s,"a":%s}',v3(ad._props.CFrame.Position),n(c._props.Size and c._props.Size.X.Scale or 1),c3(img._props.ImageColor3),n(1-(img._props.ImageTransparency or 0)))
    end
   elseif c._class=='Beam'and c._props.Enabled~=false then
    local a0,a1=c._props.Attachment0,c._props.Attachment1
    local h0,h1=a0 and partOf(a0),a1 and partOf(a1)
    if h0 and h1 then
     local p0=(h0._props.CFrame*(a0._props.CFrame or CF(0,0,0))).Position;local p1=(h1._props.CFrame*(a1._props.CFrame or CF(0,0,0))).Position
     beams[#beams+1]=string.format('{"a":%s,"b":%s,"color":%s,"w":%s,"t":%s}',v3(p0),v3(p1),c3(seqColor(c._props.Color)),n(c._props.Width0 or .1),n(seqNum(c._props.Transparency,0)))
    end
   end
  end
 end
 return '"parts":['..table.concat(parts,',')..'],"emitters":['..table.concat(emitters,',')..'],"lights":['..table.concat(lights,',')..'],"glows":['..table.concat(glows,',')..'],"beams":['..table.concat(beams,',')..']'
end
-- one frame ------------------------------------------------------------------------------------------------------------------------------
local function frame(name,Wd,Ht,label,tag)
 local cam=W.workspace.CurrentCamera
 local stage=W.workspace:FindFirstChild('_RarePullStage')
 local inStage=cam.CameraType==R.Enum.CameraType.Scriptable and stage~=nil
 local roots={}
 if inStage then roots={stage}else
  roots={X.char}
  for _,nm in ipairs({'_LocalSeedPackEffects','_RarePullWorld'})do local f=W.workspace:FindFirstChild(nm);if f then roots[#roots+1]=f end end
 end
 local eye=cam.CFrame.Position;local target=eye+cam.CFrame.LookVector*10
 local g=cam:FindFirstChild('RarePullGrade');local b=cam:FindFirstChild('RarePullBlur')
 local grade=g and string.format('{"b":%s,"c":%s,"s":%s,"tint":%s}',n(g.Brightness or 0),n(g.Contrast or 0),n(g.Saturation or 0),c3(g.TintColor))or'null'
 local guis={}
 for _,nm in ipairs({'PackOpeningEffects','RarePullReveal'})do local s=X.pg:FindFirstChild(nm);if s and s.Enabled~=false then guis[#guis+1]=dump(s,Wd,Ht)end end
 -- the seed card's viewport
 local vp='null'
 local gui=X.pg:FindFirstChild('RarePullReveal');local view=gui and gui:FindFirstChild('Seed',true)
 if view and view._class=='ViewportFrame'and view.Visible and(view.ImageTransparency or 1)<.98 and view.CurrentCamera then
  local x,y,w,h=X.rect(view,Wd,Ht);local s=math.min(w,h);x=x+(w-s)/2;y=y+(h-s)/2 -- (UIAspectRatioConstraint: square, height-dominant)
  local scale=view:FindFirstChildOfClass('UIScale');local k=scale and scale.Scale or 1
  local vc=view.CurrentCamera
  vp=string.format('{"rect":[%s,%s,%s,%s],"alpha":%s,"scale":%s,"eye":%s,"target":%s,"fov":%s,%s}',n(x),n(y),n(s),n(s),n(1-view.ImageTransparency),n(k),v3(vc.CFrame.Position),v3(vc.CFrame.Position+vc.CFrame.LookVector*10),n(vc.FieldOfView or 30),world({view}))
 end
 local kind=inStage and('stage'..(M.Active()and M.Active().Rank or 8))or'world'
 print('FRAME '..name..' '..string.format('{"w":%d,"h":%d,"label":%s,"tag":%s,"kind":%s,"eye":%s,"target":%s,"fov":%s,"grade":%s,"blur":%s,%s,"guis":[%s],"viewport":%s}',
  Wd,Ht,q(label),q(tag or''),q(kind),v3(eye),v3(target),n(cam.FieldOfView or 70),grade,n(b and b.Size or 0),world(roots),table.concat(guis,','),vp))
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
local function play(rank,shots,Wd,Ht,prefix,tag)
 M.Abort('preview');W.module('RarePullWorld').Clear();R.advance(6);worldCamera()
 for _,c in ipairs(X.char:GetChildren())do if c:IsA('Tool')or c.Name=='CarriedSeed'then c:Destroy()end end
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='pv'..rank,Stage=2},nil);tool.Activated=R.signal();tool.Enabled=false;tool.Parent=X.char
 local seedId=X.byRank[rank];local spec=Rules.SeedDesignById[seedId]
 tool.ToolTip='Desert Seed Pack\n'..(spec and spec.name or seedId)..': 1/'..({'2','4','16','60','400','5K','83.3K','1.67B'})[rank]
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None')
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealDuration',Rules.GetRevealDuration(names[rank]));bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local t0=R.clock
 W.frames(1,1/30)
 local run=M.Active();local tl=run.TL
 local list=shots(tl)
 local dur=Rules.GetRevealDuration(names[rank])
 for i,s in ipairs(list)do
  while R.clock-t0<s[2]-1e-6 do
   W.frames(1,1/30)
   if bag.Parent and R.clock-t0>=dur then bag:Destroy();tool:Destroy()end -- the server ends the opening (the seed is in the hand)
   if run.Kind=='Scene'and run.Clock then -- keep the cinematic clock on the preview's clock (no frame drift)
   end
  end
  frame(string.format('%s_%02d',prefix,i),Wd,Ht,s[1],tag)
 end
 if bag.Parent then bag:Destroy()end;if tool.Parent then tool:Destroy()end
end
local strips={
 [1]=function(tl)return{{'SUSPENSE',tl.Burst*.5},{'IT COULD BE...',tl.Burst*.93},{'BURST',tl.Burst+.12},{'1 IN N',tl.Odds+.12},{'SEED',tl.FloatEnd-.08}}end,
 [6]=function(tl)return{{'THE WORLD DIMS',.3},{'LOCKED IN THE VOID',tl.Lock+.4},{'CRACKS OF LIGHT',tl.Silence-.12},{'THE HIT',tl.Climax+.42},{'SECRET + 1 IN N',tl.Odds+.15},{'THE SEED FLOATS DOWN',tl.FloatEnd-.05},{'AFTERGLOW',tl.Back+.7}}end,
 [7]=function(tl)return{{'THE WORLD DIMS',.3},{'PLANETS ALIGN',tl.Align3+.08},{'IT SPINS UP',tl.Implode-.15},{'SUPERNOVA',tl.Climax+.42},{'A FALLING STAR',tl.StarIn-.3},{'COSMIC + 1 IN N',tl.Odds+.35},{'THE SEED FLOATS DOWN',tl.FloatEnd-.05},{'AFTERGLOW',tl.Back+.7}}end,
 [8]=function(tl)return{{'THE WORLD DIMS',.3},{'CARRIED TO THE THRONE',tl.SceneIn+1.25},{'THE CROWN DESCENDS',tl.CrownStart+1.0},{'THE CROWNED PACK',tl.Silence-.12},{'THE HIT',tl.Climax+.42},{'KING + 1 IN N',tl.Odds+.15},{'THE SEED FLOATS DOWN',tl.FloatEnd-.05},{'AFTERGLOW',tl.Back+.7}}end,
}
if SET=='strips'then
 for rank=1,5 do setDevice(false);play(rank,strips[1],1280,720,'ladder'..rank,names[rank])end
 for rank=6,8 do
  setDevice(false);play(rank,strips[rank],1280,720,'scene'..rank..'d',names[rank]..' desktop')
  setDevice(true);play(rank,strips[rank],844,390,'scene'..rank..'p',names[rank]..' phone')
 end
else
 setDevice(false)
 play(8,function(tl)local out={};local t=.05;while t<tl.Back+1.2 do out[#out+1]={string.format('%.1f s',t),t};t+=.2 end;return out end,640,360,'king','King')
end
