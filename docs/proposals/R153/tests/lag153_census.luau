-- R153 lag audit: what the finished world puts on a client, per area and tier (appended to the R152 sweep scene by lag153_world.py, after every real
-- start-up builder, the keyboard client, the snow client, the two hub displays and the Void giveaway pedestal; this file then loads the hub clients
-- and, with ALLCLIENT = true, every other StarterPlayerScripts client).
-- Globals: TIER (ClientFxBudget 1..3), SPOT = 'hub' | 'track' (where the local runner stands: the hub plaza, or the track at RUNNER), ALLCLIENT.
-- Prints "CENSUS <area> k=v ..." lines and one "CENSUS_TOTAL" line; "RADIUS" (drawn parts within 1024 / 400 / 150 studs of the runner); "SUB" (the
-- biggest areas by child); "GUI" / "GUIBY" / "GUITOP" (the PlayerGui the clients built); "FALLBACK" (how much of it is icon fallback strips);
-- "LOOPS" (RunService connections and bound render steps alive, by the chunk that made them); "WRITES" / "TOPWRITES" (property writes per frame by
-- area and by class.property, standing still, 120 frames); "LUAMS" (Lua ms per frame per chunk on the mock, best of 4 windows of 30 frames).
-- The mock runs CFrame maths and every property write in Lua, so its ms rank the scripts against each other; they are not a phone's ms.
-- Render-cost fields: parts drawn (Transparency < 1), MeshParts, shadow casters (drawn, CastShadow not false), small casters (largest side < 4 studs),
-- tiny casters (< 1.5), semi-transparent drawn parts, Glass / Neon / ForceField drawn parts, unanchored parts (and how many have no weld / joint at all),
-- lights (and with Shadows on), Highlights, emitters (enabled) and their summed Rate, beams / trails on, decals / textures, SurfaceGuis on with their
-- estimated canvas pixels (PixelsPerStud x face, or CanvasSize; a SurfaceGui that sets neither is counted at Roblox's 800 x 600 default), labels drawn,
-- BillboardGuis on, sounds, proximity prompts.
local FP=require('./perf152_fp')(W)
local TIER=TIER or 3
local cam=W.workspace.CurrentCamera
if cam.FieldOfView==nil then cam.FieldOfView=70 end
local me=Players.LocalPlayer
local ws=W.workspace
for _,s in ipairs(steps)do print('STEP '..s..' ok')end
local function look(from,at)cam.CFrame=R.CFrame.lookAt(from,at);cam.Focus=CF(at.X,at.Y,at.Z)end
local function client(name,bundleName)
 local sc=R.new('LocalScript');sc.Name=name;sc.Parent=me:FindFirstChild('PlayerGui')
 local ok,err=pcall(W.load,bundleName,sc);if not ok then print('CLIENT '..name..' FAILED '..tostring(err))end
 return sc
end
local root=me.Character and me.Character:FindFirstChild('HumanoidRootPart')
local DT=TIER>=3 and 1/60 or 1/30
if SPOT=='hub'then
 if root then root.CFrame=CF(0,7,-330)end
 look(V3(0,30,-300),V3(0,10,-392))
else
 local r=RUNNER or{0,600}
 if root then root.CFrame=CF(r[1],7,r[2])end
 look(V3(r[1],21,r[2]-24),V3(r[1],9,r[2]+40))
end
-- Every frame handler (RunService signals and bound render steps) is wrapped once: a handler that errors on the mock (a method it lacks) is
-- reported once and keeps running each frame, as on Roblox, without stopping the others; while TIMING is on, its Lua time (real clock, minus the
-- write probe's own bookkeeping) is added to TIMES under the chunk that defined it (a client script or a module). The mock's frames also fire
-- PostSimulation and PreAnimation (the shared mock fires only RenderStepped, Heartbeat and PreSimulation).
local Run=W.service('RunService');Run.PreAnimation=Run.PreAnimation or R.signal();Run.PostSimulation=Run.PostSimulation or R.signal()
local SIGS={'RenderStepped','Heartbeat','PreSimulation','Stepped','PostSimulation','PreAnimation'}
local ORIG=setmetatable({},{__mode='k'})
local TIMES,TIMING,ERRS={},false,{}
local function chunk(f)f=ORIG[f]or f;local ok,s=pcall(debug.info,f,'s');s=ok and tostring(s)or'?';return(s:gsub('^[=@]',''):gsub('^Client_',''))end
local function instrument(f)
 if not f or ORIG[f]then return f end
 local name=chunk(f);local probe=FP.Probe
 local g=function(...)
  local ov=probe.Overhead;local t0=os.clock()
  local ok,err=pcall(f,...)
  if TIMING then TIMES[name]=(TIMES[name]or 0)+os.clock()-t0-(probe.Overhead-ov)end
  if not ok then local k=name..': '..tostring(err):sub(1,140);if not ERRS[k]then ERRS[k]=true;print('HANDLERERR '..k)end end
 end
 ORIG[g]=f;return g
end
local function instrumentAll()
 for _,name in ipairs(SIGS)do local sig=Run[name];if sig and sig._c then for _,cn in ipairs(sig._c)do if cn._f then cn._f=instrument(cn._f)end end end end
 for _,b in pairs(W.rsBound or{})do b.Fn=instrument(b.Fn)end
end
do local rawFrames=W.frames
 W.frames=function(n,dt)for _=1,n do instrumentAll();rawFrames(1,dt);instrumentAll();Run.PostSimulation:Fire(dt or 1/60);Run.PreAnimation:Fire(dt or 1/60)end end
end
client('HubLife151','HubLife151Client');client('HubDisplayClient','HubDisplayClient');client('VoidGiveawayClient152','VoidGiveawayClient152')
-- ALLCLIENT: every other StarterPlayerScripts client too, each in its own thread (a task.wait yields and is resumed by the mock's scheduler, so a
-- script's "while ... task.wait()" loop runs over the frames instead of hanging), with a stand-in RemoteEvent for any remote a script waits for that
-- the start-up builders did not make. A script that still fails to start is listed ("CLIENTFAIL"); its loops are then missing from the timings.
local clientOk,clientFail={},{}
if ALLCLIENT then
 local T=R.task
 local MAIN=coroutine.running()
 -- deferred / delayed functions run in their own thread (so they may task.wait), as on Roblox
 local rawDelay,rawDefer=T.delay,T.defer
 local function threaded(f)
  if type(f)=='thread'then return function(...)local ok,err=coroutine.resume(f,...);if not ok then print('CLIENTERR '..tostring(err):sub(1,200))end end end
  return function(...)local co=coroutine.create(f);local ok,err=coroutine.resume(co,...);if not ok then print('CLIENTERR '..tostring(err):sub(1,200))end end
 end
 T.delay=function(t,f,...)return rawDelay(t,threaded(f),...)end
 T.defer=function(f,...)return rawDefer(threaded(f),...)end
 T.wait=function(t)
  local co=coroutine.running()
  if co and co~=MAIN and coroutine.isyieldable()then
   local at=R.clock
   rawDelay(t or 0,function()local ok,err=coroutine.resume(co);if not ok then print('CLIENTERR '..tostring(err):sub(1,200))end end)
   coroutine.yield();return R.clock-at
  end
  return t or 0
 end
 W.env.wait=T.wait;W.env.delay=T.delay;W.env.spawn=T.spawn
 local Inst=R.Inst;local rawWFC=Inst.WaitForChild
 Inst.WaitForChild=function(self,n,timeout)
  local c=self:FindFirstChild(n);if c then return c end
  if self._props.Name=='ChestChaseRemotes'then local e=R.Instance.new('RemoteEvent');e.Name=n;e.Parent=self;return e end
  if timeout then return nil end
  return rawWFC(self,n)
 end
 if not Inst.FireServer then Inst.FireServer=function()end end
 if not Inst.InvokeServer then Inst.InvokeServer=function()return nil end end
 -- engine signals the shared mock does not make (made on first use, one per instance)
 local SIG={}
 for _,k in ipairs({'Ended','Played','Loaded','DidLoop','Resumed','Paused','Stopped','CharacterAdded','CharacterRemoving','CharacterAppearanceLoaded','MenuOpened','MenuClosed',
  'TouchTapInWorld','JumpRequest','TouchStarted','TouchEnded','TouchMoved','TouchSwipe','TouchPinch','TouchLongPress','PromptShown','PromptHidden','Triggered','TriggerEnded',
  'Equipped','Unequipped','Activated','Deactivated','MouseButton1Down','MouseButton1Up','MouseButton2Click','FocusLost','Focused','Completed','StateChanged','Died','Running',
  'HealthChanged','MoveToFinished','Seated','Jumping','FreeFalling','GettingUp','Climbing','Swimming','AnimationPlayed','KeyframeReached','PlayerAdded','PlayerRemoving',
  'Idled','OnClientEvent','Event','SelectionChanged','WindowFocused','GamepadConnected','GamepadDisconnected','DescendantRemoving','ViewportSizeChanged','PromptButtonHoldBegan',
  'PromptButtonHoldEnded','PromptProductPurchaseFinished','PromptGamePassPurchaseFinished','PromptPurchaseFinished','ThumbnailFinished','MouseWheelForward','MouseWheelBackward'})do SIG[k]=true end
 local meta=R.instMeta;local rawIndex=meta.__index
 meta.__index=function(o,k)
  local v=rawIndex(o,k);if v~=nil then return v end
  if SIG[k]then local s=R.signal();rawget(o,'_props')[k]=s;return s end
  return nil
 end
 local CAS=W.service('ContextActionService');CAS.BindActionAtPriority=function(_,name,fn)W.actions[name]=fn end
 -- camera and humanoid methods some clients call
 local cam0=W.workspace.CurrentCamera
 local function project(self,p)
  local vs=self.ViewportSize or R.Vector2.new(1280,720);local fov=math.rad(self.FieldOfView or 70)
  local o=self.CFrame:Inverse()*p;local d=-o.Z;if d<=1e-3 then return R.Vector3.new(0,0,d),false end
  local tv=math.tan(fov/2);local th=tv*vs.X/vs.Y
  local x=(o.X/(d*th)+1)/2*vs.X;local y=(1-o.Y/(d*tv))/2*vs.Y
  return R.Vector3.new(x,y,d),x>=0 and y>=0 and x<=vs.X and y<=vs.Y
 end
 cam0.WorldToViewportPoint=project;cam0.WorldToScreenPoint=project
 cam0.ViewportPointToRay=cam0.ViewportPointToRay or function(self,x,y)return{Origin=self.CFrame.Position,Direction=self.CFrame.LookVector}end
 cam0.ScreenPointToRay=cam0.ScreenPointToRay or cam0.ViewportPointToRay
 local Inst=R.Inst
 for k,f in pairs({GetStateEnabled=function()return true end,SetStateEnabled=function()end,ChangeState=function()end,GetState=function()return R.Enum.HumanoidStateType.Running end,
  Move=function()end,MoveTo=function()end,LoadAnimation=function()return{Play=function()end,Stop=function()end,AdjustSpeed=function()end,Stopped=R.signal(),Ended=R.signal(),KeyframeReached=R.signal(),GetMarkerReachedSignal=function()return R.signal()end,IsPlaying=false,Length=1,TimePosition=0}end,
  GetPlayingAnimationTracks=function()return{}end,GetAppliedDescription=function()return nil end,GetMass=function()return 1 end,GetConnectedParts=function()return{}end})do
  if not Inst[k]then Inst[k]=f end
 end
 local PPS=W.service('ProximityPromptService');PPS.PromptTriggered=R.signal();PPS.PromptShown=R.signal();PPS.PromptHidden=R.signal();PPS.PromptTriggerEnded=R.signal()
 local Debris=W.service('Debris');Debris.AddItem=function()end
 for _,n in ipairs({'Backpack','PlayerScripts'})do if not me:FindFirstChild(n)then local f=R.new(n=='Backpack'and'Backpack'or'Folder');f.Name=n;f.Parent=me end end
 local cam=W.workspace.CurrentCamera;if not cam.ViewportSize then cam.ViewportSize=R.Vector2.new(1280,720)end
 local done={HubLife151=true,HubDisplayClient=true,VoidGiveawayClient152=true,KeyboardTrack=true,SnowBiome149=true}
 for _,n in ipairs(require('./client_names'))do if not done[n]then
  local sc=R.new('LocalScript');sc.Name=n;sc.Parent=me:FindFirstChild('PlayerGui')
  local co=coroutine.create(function()local ok,err=pcall(W.load,'Client_'..n,sc);if ok then clientOk[#clientOk+1]=n else clientFail[#clientFail+1]=n..': '..tostring(err):gsub('\n',' '):sub(1,160)end end)
  local ok,err=coroutine.resume(co);if not ok then clientFail[#clientFail+1]=n..': '..tostring(err):sub(1,160)end
  if coroutine.status(co)=='suspended'then clientOk[#clientOk+1]=n..'(waiting)'end
 end end
 print(string.format('CLIENTS started=%d failed=%d',#clientOk,#clientFail))
 for _,f in ipairs(clientFail)do print('CLIENTFAIL '..f)end
end
W.frames(90,DT)

-- areas -------------------------------------------------------------------------------------------------------------------------------------------------
local mapRoot=ws:FindFirstChild('ChestChaseMap')
local function areaOf(o)
 local chain={};local x=o
 while x and x~=ws do table.insert(chain,1,x);x=x._parent end
 local top=chain[1];if not top then return'?'end
 local tn=top._props.Name
 if top~=mapRoot then
  if tn:find('KeyboardTrack')then return'keyboard'end
  if tn:find('Snow')then return'snow (client)'end
  if tn:find('VoidGiveaway')or tn:find('_VoidPackFx')then return'giveaway pack (client)'end
  if tn=='Tester'then return'local character'end
  return'ws/'..tn
 end
 local second=chain[2];if not second then return'map'end
 local sn=second._props.Name
 if sn=='Bases'then
  local third=chain[4] -- Bases/Base_n/<x>
  local tn3=third and third._props.Name or''
  if tn3:find('Treadmill')then return'bases: treadmills'end
  if tn3:find('Mystery')then return'bases: mystery pedestals'end
  if tn3:find('GardenFence')or tn3:find('GardenUpgrade')or tn3:find('PerimeterFence')then return'bases: fences'end
  return'bases: other'
 end
 if sn=='Obby'then
  local third=chain[3];local t3=third and third._props.Name or''
  if t3=='Biomes'then local b=chain[4];return'track: '..(b and b._props.Name or'?')end
  return'track: '..t3
 end
 return'map/'..sn
end

local GLASSY={Glass=true,Neon=true,ForceField=true}
local function isPart(o)return o:IsA('BasePart')end
local function num(v,d)return type(v)=='number'and v or d end
local stats={};local order={}
local function S(a)local s=stats[a];if not s then s={};stats[a]=s;order[#order+1]=a end;return s end
local function add(s,k,n)s[k]=(s[k]or 0)+(n or 1)end
local function faceArea(part,face)
 local sz=part._props.Size;if R.typeof(sz)~='Vector3'then return 4*2 end
 local f=face and face.Name or'Front'
 if f=='Top'or f=='Bottom'then return sz.X*sz.Z elseif f=='Left'or f=='Right'then return sz.Y*sz.Z end
 return sz.X*sz.Y
end
local function hasJoint(part)
 for _,c in ipairs(part._children)do local k=c._class;if k=='Weld'or k=='WeldConstraint'or k=='Motor6D'or k=='ManualWeld'or k=='RigidConstraint'then return true end end
 return false
end
-- weld targets (a WeldConstraint elsewhere that names this part)
local welded={}
for _,d in ipairs(ws:GetDescendants())do
 local k=d._class
 if k=='Weld'or k=='WeldConstraint'or k=='Motor6D'or k=='RigidConstraint'then
  local p0,p1=d._props.Part0,d._props.Part1;if p0 then welded[p0]=true end;if p1 then welded[p1]=true end
 end
end
local function walk(o,guiOn)
 local c,p=o._class,o._props
 local a=areaOf(o);local s=S(a)
 add(s,'inst')
 local childGui=guiOn
 if isPart(o)then
  add(s,'parts')
  local t=num(p.Transparency,0)
  if c=='MeshPart'then add(s,'mesh')end
  if c=='UnionOperation'then add(s,'union')end
  if t<1 then
   add(s,'drawn')
   local sz=p.Size;local big=R.typeof(sz)=='Vector3'and math.max(sz.X,sz.Y,sz.Z)or 4
   if p.CastShadow~=false then add(s,'shadow');if big<4 then add(s,'shadow<4')end;if big<1.5 then add(s,'shadow<1.5')end end
   if t>0 then add(s,'semi')end
   local m=p.Material;local mn=type(m)=='table'and m.Name or nil
   if mn and GLASSY[mn]then add(s,mn)end
  end
  if p.Anchored~=true then add(s,'unanch');if not hasJoint(o)and not welded[o]then add(s,'unanch_free')end end
 elseif c=='PointLight'or c=='SpotLight'or c=='SurfaceLight'then
  if p.Enabled~=false and num(p.Brightness,1)>0 then add(s,'lights');if p.Shadows==true then add(s,'lightShadows')end end
 elseif c=='Highlight'then if p.Enabled~=false then add(s,'highlights')end
 elseif c=='ParticleEmitter'then add(s,'emitters');if p.Enabled~=false then add(s,'emittersOn');add(s,'rate',num(p.Rate,5))end
 elseif c=='Beam'then if p.Enabled~=false then add(s,'beams')end
 elseif c=='Trail'then if p.Enabled~=false then add(s,'trails')end
 elseif c=='Fire'or c=='Smoke'or c=='Sparkles'then if p.Enabled~=false then add(s,'legacyFx')end
 elseif c=='Decal'or c=='Texture'then if num(p.Transparency,0)<1 then add(s,'decals')end
 elseif c=='SurfaceGui'then
  local host=p.Adornee or o._parent
  local on=p.Enabled~=false and host and isPart(host)
  childGui=on and true or false
  if on then
   add(s,'sgui')
   local mode=p.SizingMode;local mn=type(mode)=='table'and mode.Name or nil
   local px
   if mn=='PixelsPerStud'then local pps=num(p.PixelsPerStud,50);px=faceArea(host,p.Face)*pps*pps
   elseif R.typeof(p.CanvasSize)=='Vector2'then px=p.CanvasSize.X*p.CanvasSize.Y
   else px=800*600 end
   add(s,'sguiPx',px)
   if p.AlwaysOnTop==true then add(s,'sguiTop')end
   if num(p.MaxDistance,0)==0 then add(s,'sguiNoMaxDist')end
  end
 elseif c=='BillboardGui'then
  local on=p.Enabled~=false;childGui=on;if on then add(s,'bgui');if p.AlwaysOnTop==true then add(s,'bguiTop')end end
 elseif c=='TextLabel'or c=='TextButton'or c=='ImageLabel'or c=='Frame'then
  if guiOn and p.Visible~=false then add(s,c=='TextLabel'and'labels'or'guiObj')end
 elseif c=='Sound'then add(s,'sounds')
 elseif c=='ProximityPrompt'then if p.Enabled~=false then add(s,'prompts')end
 elseif c=='Humanoid'then add(s,'humanoids')
 elseif c=='Model'then add(s,'models')
 end
 for _,ch in ipairs(o._children)do walk(ch,childGui)end
end
for _,ch in ipairs(ws._children)do if ch._class~='Camera'then walk(ch,nil)end end
-- What a streaming client holds: the server's map parts within StreamingTargetRadius (1024 in the place) of the runner, plus everything the client
-- builds itself (never streamed). Also within 400 studs (about what a phone draws at low quality) and 150.
do
 local at=root and root._props.CFrame.Position or V3(0,7,-330)
 local function inMap(o)local x=o;while x do if x==mapRoot then return true end;x=x._parent end;return false end
 for _,r in ipairs({1024,400,150})do
  local n,sh,tiny,semi,glass,em=0,0,0,0,0,0
  for _,d in ipairs(ws:GetDescendants())do
   if d:IsA('BasePart')and num(d._props.Transparency,0)<1 then
    local pos=d._props.CFrame and d._props.CFrame.Position
    local dist=pos and(pos-at).Magnitude or 0
    if dist<=r then
     n+=1
     local sz=d._props.Size;local big=R.typeof(sz)=='Vector3'and math.max(sz.X,sz.Y,sz.Z)or 4
     if d._props.CastShadow~=false then sh+=1;if big<1.5 then tiny+=1 end end
     local t=num(d._props.Transparency,0);if t>0 then semi+=1 end
     local m=d._props.Material;if type(m)=='table'and m.Name=='Glass'then glass+=1 end
    end
   end
  end
  print(string.format('RADIUS tier=%d spot=%s r=%d drawn=%d shadow=%d shadow<1.5=%d semi=%d Glass=%d',TIER,SPOT,r,n,sh,tiny,semi,glass))
 end
end
local KEYS={'inst','parts','drawn','mesh','union','shadow','shadow<4','shadow<1.5','semi','Glass','Neon','ForceField','unanch','unanch_free','lights','lightShadows',
 'highlights','emittersOn','rate','beams','trails','legacyFx','decals','sgui','sguiPx','sguiTop','sguiNoMaxDist','labels','guiObj','bgui','bguiTop','sounds','prompts','humanoids','models'}
table.sort(order,function(a,b)return(stats[a].parts or 0)>(stats[b].parts or 0)end)
local total={}
for _,a in ipairs(order)do
 local s=stats[a];local out={}
 for _,k in ipairs(KEYS)do local v=s[k];if v and v~=0 then out[#out+1]=k=='sguiPx'and string.format('%s=%.1fM',k,v/1e6)or string.format('%s=%d',k,math.floor(v+.5))end;total[k]=(total[k]or 0)+(v or 0)end
 print(string.format('CENSUS tier=%d spot=%s | %s | %s',TIER,SPOT,a,table.concat(out,' ')))
end
local out={}
for _,k in ipairs(KEYS)do local v=total[k];if v and v~=0 then out[#out+1]=k=='sguiPx'and string.format('%s=%.1fM',k,v/1e6)or string.format('%s=%d',k,math.floor(v+.5))end end
print(string.format('CENSUS_TOTAL tier=%d spot=%s | %s',TIER,SPOT,table.concat(out,' ')))

-- the biggest areas broken down by their children (drawn parts; shadow casters, tiny casters < 1.5 studs, semi-transparent, Glass, Neon)
do
 local function count(o)
  local n,sh,tiny,semi,glass,neon=0,0,0,0,0,0
  for _,d in ipairs(o:GetDescendants())do if d:IsA('BasePart')and num(d._props.Transparency,0)<1 then n+=1
   local sz=d._props.Size;local big=R.typeof(sz)=='Vector3'and math.max(sz.X,sz.Y,sz.Z)or 4
   if d._props.CastShadow~=false then sh+=1;if big<1.5 then tiny+=1 end end
   if num(d._props.Transparency,0)>0 then semi+=1 end
   local m=d._props.Material;local mn=type(m)=='table'and m.Name or''
   if mn=='Glass'then glass+=1 elseif mn=='Neon'then neon+=1 end end end
  return n,sh,tiny,semi,glass,neon
 end
 local function breakdown(label,o)
  if not o then return end
  local kids={}
  for _,c in ipairs(o._children)do local n,sh,tiny,semi,glass,neon=count(c);if n>0 then kids[#kids+1]={c._props.Name,n,sh,tiny,semi,glass,neon}end end
  table.sort(kids,function(a,b)return a[2]>b[2]end)
  local out={};for i=1,math.min(10,#kids)do local k=kids[i];out[#out+1]=string.format('%s: %d (sh %d tiny %d semi %d glass %d neon %d)',k[1],k[2],k[3],k[4],k[5],k[6],k[7])end
  print(string.format('SUB tier=%d spot=%s %s | %s',TIER,SPOT,label,table.concat(out,' ; ')))
 end
 local function at(...)local o=mapRoot;for _,n in ipairs({...})do o=o and o:FindFirstChild(n)end;return o end
 breakdown('EconomyHub',at('EconomyHub'));breakdown('Base_1',at('Bases','Base_1'));breakdown('Base_1/TreadmillArtV131',at('Bases','Base_1','TreadmillArtV131'))
 breakdown('MythicLandmarks',at('MythicLandmarks'));breakdown('HubDecor151',at('HubDecor151'));breakdown('Frostland',at('Obby','Biomes','Biome_3_FROSTLAND'))
 breakdown('CrystalWilds',at('Obby','Biomes','Biome_5_CRYSTAL_WILDS'));breakdown('HubLife151',ws:FindFirstChild('HubLife151'))
 breakdown('EconomyHub/MerchantStands',at('EconomyHub','MerchantStands'))
end

-- the screen UI the clients built (PlayerGui): instances, ScreenGuis on, GUI objects drawn (every ancestor visible), strokes / gradients, viewports
do
 local pg=me:FindFirstChild('PlayerGui')
 local c={inst=0,screens=0,screensOn=0,drawn=0,strokes=0,gradients=0,viewports=0,viewportsDrawn=0,labels=0}
 local function walk(o,on)
  c.inst+=1
  local k=o._class;local p=o._props
  if k=='ScreenGui'then c.screens+=1;on=p.Enabled~=false;if on then c.screensOn+=1 end
  elseif k=='Frame'or k=='TextLabel'or k=='TextButton'or k=='ImageLabel'or k=='ImageButton'or k=='ScrollingFrame'or k=='ViewportFrame'or k=='CanvasGroup'then
   on=on and p.Visible~=false;if on then c.drawn+=1;if k=='TextLabel'or k=='TextButton'then c.labels+=1 end end
   if k=='ViewportFrame'then c.viewports+=1;if on then c.viewportsDrawn+=1 end end
  elseif k=='UIStroke'then if on then c.strokes+=1 end
  elseif k=='UIGradient'then if on then c.gradients+=1 end end
  for _,ch in ipairs(o._children)do walk(ch,on)end
 end
 if pg then walk(pg,true)end
 print(string.format('GUI tier=%d spot=%s playergui instances=%d screenguis=%d (on %d) drawn gui objects=%d labels=%d strokes=%d gradients=%d viewports=%d (drawn %d)',
  TIER,SPOT,c.inst,c.screens,c.screensOn,c.drawn,c.labels,c.strokes,c.gradients,c.viewports,c.viewportsDrawn))
 -- by ScreenGui (and the biggest children of the biggest one): instances, drawn objects, drawn gradients
 if pg then
  local rows={}
  for _,sg in ipairs(pg._children)do
   local n,d,g=0,0,0
   local function w(o,on)
    n+=1
    local k=o._class
    if k=='ScreenGui'then on=o._props.Enabled~=false
    elseif o:IsA('GuiObject')or k=='ViewportFrame'or k=='ScrollingFrame'or k=='CanvasGroup'then on=on and o._props.Visible~=false;if on then d+=1 end
    elseif k=='UIGradient'and on then g+=1 end
    for _,ch in ipairs(o._children)do w(ch,on)end
   end
   w(sg,true);rows[#rows+1]={sg._props.Name..(sg._class=='ScreenGui'and''or'('..sg._class..')'),n,d,g,sg}
  end
  table.sort(rows,function(a,b)return a[2]>b[2]end)
  local out={};for i=1,math.min(14,#rows)do local r=rows[i];out[#out+1]=string.format('%s %d (drawn %d, gradients %d)',r[1],r[2],r[3],r[4])end
  print(string.format('GUIBY tier=%d spot=%s %s',TIER,SPOT,table.concat(out,' ; ')))
  local top=rows[1] and rows[1][5]
  if top then
   local kids={};local function size(o)local n=1;for _,ch in ipairs(o._children)do n+=size(ch)end;return n end
   local function scan(o,depth)for _,ch in ipairs(o._children)do kids[#kids+1]={string.rep('>',depth)..ch._props.Name,size(ch)};if depth<2 and size(ch)>2000 then scan(ch,depth+1)end end end
   scan(top,1);table.sort(kids,function(a,b)return a[2]>b[2]end)
   local o2={};for i=1,math.min(10,#kids)do o2[#o2+1]=kids[i][1]..' '..kids[i][2]end
   print(string.format('GUITOP tier=%d spot=%s %s: %s',TIER,SPOT,rows[1][1],table.concat(o2,' ; ')))
  end
 end
end

-- how much of the PlayerGui is ArtworkRuntime87's icon fallbacks ('SmoothFallback': one Frame + UIGradient per pixel strip, cloned into every icon)
do
 local pg=me:FindFirstChild('PlayerGui')
 if pg then
  local total=#pg:GetDescendants()
  local n,inside=0,0;local perGui={}
  for _,d in ipairs(pg:GetDescendants())do
   if d._props.Name=='SmoothFallback'then
    n+=1;local k=#d:GetDescendants()+1;inside+=k
    local x=d;while x._parent and x._parent~=pg do x=x._parent end
    perGui[x._props.Name]=(perGui[x._props.Name]or 0)+k
   end
  end
  local list={};for k,v in pairs(perGui)do list[#list+1]=k..' '..v end;table.sort(list)
  print(string.format('FALLBACK tier=%d spot=%s playergui=%d icon_fallbacks=%d instances_in_them=%d (%.0f%%) per_icon=%.0f | %s',TIER,SPOT,total,n,inside,inside/math.max(1,total)*100,inside/math.max(1,n),table.concat(list,', ')))
 end
end

-- loops alive (the mock has one RunService: the client handlers, and the server's when a test starts any)---------------------------------------------
local live={}
for _,name in ipairs(SIGS)do
 local sig=Run[name]
 if sig and sig._c then for _,cn in ipairs(sig._c)do if cn.Connected and cn._f then local k=name..':'..chunk(cn._f);live[k]=(live[k]or 0)+1 end end end
end
for n,b in pairs(W.rsBound or{})do local k='BindToRenderStep:'..chunk(b.Fn)..'('..n..')';live[k]=(live[k]or 0)+1 end
local list={};local total=0;for k,v in pairs(live)do list[#list+1]=v>1 and(k..'x'..v)or k;total+=v end;table.sort(list)
print(string.format('LOOPS tier=%d spot=%s n=%d %s',TIER,SPOT,total,table.concat(list,' ')))

-- Lua ms per chunk (best of 4 windows of 30 frames: the mock shares the machine) and property writes per frame by area, standing still ----------------
FP.Probe.Classify=function(o)return areaOf(o)end
W.frames(60,DT)
local N=120
local best={}
FP.probeStart()
for _=1,4 do
 table.clear(TIMES);TIMING=true
 W.frames(N//4,DT)
 TIMING=false
 for k,v in pairs(TIMES)do local ms=v*1000/(N//4);if not best[k]or ms<best[k]then best[k]=ms end end
end
local p=FP.probeStop()
local areas=FP.probeAreas(p);local names={};for k in pairs(areas)do names[#names+1]=k end;table.sort(names,function(a,b)return areas[a][1]>areas[b][1]end)
local ap={};for _,k in ipairs(names)do ap[#ap+1]=string.format('%s %.1f',k,areas[k][1]/N)end
local tm={};local sum=0;for k,v in pairs(best)do tm[#tm+1]={k,v};sum+=v end;table.sort(tm,function(a,b)return a[2]>b[2]end)
local tt={};for i=1,math.min(45,#tm)do tt[#tt+1]=string.format('%s %.3f',tm[i][1],tm[i][2])end
print(string.format('WRITES tier=%d spot=%s total/frame=%.1f | %s',TIER,SPOT,p.Writes/N,table.concat(ap,', ')))
print(string.format('LUAMS tier=%d spot=%s handlers=%d sum=%.3f ms/frame (mock, best of 4 windows) %s',TIER,SPOT,#tm,sum,table.concat(tt,', ')))
print(string.format('TOPWRITES tier=%d spot=%s %s',TIER,SPOT,FP.probeText(p,N,15)))
print('LAG153 DONE')
