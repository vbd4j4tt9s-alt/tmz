-- R154 (owner: "minor fix after i want to make it so that after obtaining the seed the seed stays on the player's screen until they click and the
-- seed goes to their inventory"): the pull reveal's seed goes HOME. The opener's client only, and only what it shows: the server granted the
-- seed on the 5th click and hands its tool over when it ends the opening, exactly as before (nothing here touches data or asks the server).
--  Hold(id)    the reveal of the pack with this inventory id has begun (the seed keeps its pack's id). Until its seed has flown in, the Hotbar
--              does not show a seed tool with this id, the hand does not show it on this screen (hidden locally, its effects off) and the
--              world seed of that pack never flies into the hand (BagState: SeedPackClient). The director touches it every frame (Touch): a
--              hold nobody touches for Backstop seconds ends by itself, so nothing can stay hidden.
--  Fly(opts)   the click sent it home: the seed flies from the card to its hotbar slot, or to the Bag button when it is not on a visible slot
--              (Target: the Hotbar's answer), a soft whoosh swelling on its fastest frame. On arrival it pops, the hold ends (Land: the Hotbar
--              shows the seed and flashes the slot) and the bag's pickup cue plays (Bubble06). A seed whose tool is not there yet (the server
--              ends the opening a moment later) rests on its slot until it is. Reduced Motion: a quick fade where it was, then the same arrival.
--  Release(id) a hold that ends without a fly (the reveal stopped before showing its result, an abort): the seed just shows.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local C={}
C.FlySeconds=.55 -- the flight from the card to the slot
C.FadeSeconds=.25 -- Reduced Motion: the fade in place instead
C.PopSeconds=.2 -- the pop on arrival
C.OutSeconds=.14 -- the flown seed fades into the slot's own picture
C.ParkSeconds=8 -- at most this long resting on its slot while its tool is on its way (a respawn: ~5 s)
C.Backstop=5 -- a hold nobody touches ends after this
C.WhooshVolume=.35;C.WhooshPitch=1.15 -- of the Flight slot (RarePullSounds): softer and a little higher than the seed's slide into the hand
C.ArrivalCue='Bubble06' -- the bag's pickup cue (InteractionAudio), the Hotbar's own arrival sound
C.DisplayOrder=97 -- above the reveal (96) and the HUD
local holds={};local listeners={};local resolver=nil
local bags=setmetatable({},{__mode='k'}) -- bag -> 'held' | os.clock() of its collect
local hidden={} -- tool -> {Items={{instance, property, value}}, Seen={}, Conn}
local flies={};local overlay,flyConn
local function lp()return Players.LocalPlayer end
local function clamp01(x)return math.clamp(x,0,1)end
local function smooth(x)x=clamp01(x);return x*x*(3-2*x)end
local function fire(id,cue,target)for _,fn in ipairs(table.clone(listeners))do local ok,err=pcall(fn,id,cue,target);if not ok then warn('[SeedCollect] '..tostring(err))end end end
-- The hand -------------------------------------------------------------------------------------------------------------------------------
local off={ParticleEmitter=true,Beam=true,Trail=true,PointLight=true,SpotLight=true,SurfaceLight=true,BillboardGui=true,SurfaceGui=true,Highlight=true,Fire=true,Smoke=true,Sparkles=true}
local function hideOne(h,d)
 if h.Seen[d]then return end
 if d:IsA('BasePart')or d:IsA('Decal')then h.Seen[d]=true;h.Items[#h.Items+1]={d,'LocalTransparencyModifier',d.LocalTransparencyModifier};d.LocalTransparencyModifier=1
 elseif off[d.ClassName]then h.Seen[d]=true;h.Items[#h.Items+1]={d,'Enabled',d.Enabled};d.Enabled=false end
end
local function hideTool(tool)
 if hidden[tool]then return end
 local h={Items={},Seen={}};hidden[tool]=h
 for _,d in ipairs(tool:GetDescendants())do hideOne(h,d)end
 h.Conn=tool.DescendantAdded:Connect(function(d) -- (the seed the server builds once it is equipped)
  if hidden[tool]~=h then return end
  pcall(hideOne,h,d);for _,x in ipairs(d:GetDescendants())do pcall(hideOne,h,x)end
 end)
end
local function showTool(tool)
 local h=hidden[tool];if not h then return end;hidden[tool]=nil
 if h.Conn then h.Conn:Disconnect()end
 for _,it in ipairs(h.Items)do pcall(function()if it[1].Parent then it[1][it[2]]=it[3]end end)end
end
local function scanHand()
 local player=lp();local char=player and player.Character
 for tool in pairs(hidden)do if tool.Parent~=char or not C.Holds(tool)then showTool(tool)end end
 if char then for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')and C.Holds(t)then hideTool(t)end end end
end
local handConns={}
local function unwatch()for _,c in ipairs(handConns)do c:Disconnect()end;table.clear(handConns)end
local function watch()
 unwatch()
 local player=lp();if not player then return end
 handConns[#handConns+1]=player.CharacterAdded:Connect(function()watch();scanHand()end)
 local char=player.Character
 if char then
  handConns[#handConns+1]=char.ChildAdded:Connect(function()scanHand()end)
  handConns[#handConns+1]=char.ChildRemoved:Connect(function()scanHand()end)
 end
end
local function holdsChanged()
 if next(holds)then if #handConns==0 then watch()end else unwatch()end
 pcall(scanHand)
end
-- A tool or part this hides from the opener's own screen (SeedPackClient leaves its aura out).
function C.Hidden(inst)
 if next(hidden)==nil or not inst then return false end
 for tool in pairs(hidden)do if inst==tool or inst:IsDescendantOf(tool)then return true end end
 return false
end
-- Holds ------------------------------------------------------------------------------------------------------------------------------------
local function ends(id,cue,target)holds[id]=nil;holdsChanged();fire(id,cue,target)end
local function watchdog(id,e)
 task.delay(C.Backstop,function()
  if holds[id]~=e then return end
  if e.Due-os.clock()>.01 then watchdog(id,e)else ends(id,false)end
 end)
end
function C.Hold(id,info)
 if id==nil then return end
 local e=holds[id]
 if not e then e={Due=os.clock()+C.Backstop};holds[id]=e;watchdog(id,e)end
 e.Due=os.clock()+C.Backstop;if info and info.Spec then e.Spec=info.Spec end
 holdsChanged()
end
function C.Touch(id)local e=id~=nil and holds[id];if e then e.Due=os.clock()+C.Backstop end end
function C.Held(id)local e=id~=nil and holds[id];return e~=nil and e~=false and os.clock()<e.Due end
function C.Holds(tool)
 if next(holds)==nil then return false end
 local ok,yes=pcall(function()return tool:GetAttribute('GardenSeed')~=nil and C.Held(tool:GetAttribute('SeedInventoryId'))end)
 return ok and yes==true
end
-- the seed has arrived: the hold ends and the listeners (the Hotbar) show it; cue: flash + sound wanted (the fly's own arrival)
function C.Land(id,target)if id~=nil then ends(id,true,target)else fire(nil,true,target)end end
function C.Release(id)if id~=nil and holds[id]then ends(id,false)end end
function C.OnRelease(fn)
 listeners[#listeners+1]=fn
 return {Disconnect=function()local at=table.find(listeners,fn);if at then table.remove(listeners,at)end end}
end
-- The Hotbar answers where a seed lands: fn(id, spec) -> the slot / Bag button (a GuiObject) or nil, and whether the item is on show there now.
function C.SetTarget(fn)resolver=fn end
function C.Target(id,spec)
 if not resolver then return nil,false end
 local ok,b,present=pcall(resolver,id,spec)
 if ok and typeof(b)=='Instance'then return b,present==true end
 return nil,false
end
-- The world seed of the opener's pack (SeedPackClient): 'held' while its result waits, the os.clock() of its collect after.
function C.MarkBag(bag,state)if bag~=nil then bags[bag]=state end end
function C.BagState(bag)if bag==nil then return nil end;return bags[bag]end
-- The fly -------------------------------------------------------------------------------------------------------------------------------------
local function screen()
 local player=lp();local pg=player and player:FindFirstChildOfClass('PlayerGui');if not pg then return nil end
 if not overlay or not overlay.Parent then
  overlay=Instance.new('ScreenGui');overlay.Name='SeedCollectFly';overlay.IgnoreGuiInset=true;overlay.ResetOnSpawn=false;overlay.DisplayOrder=C.DisplayOrder
  overlay.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;pcall(function()overlay.ScreenInsets=Enum.ScreenInsets.None end);overlay.Parent=pg
 end
 return overlay
end
local function extent(g)
 local s=g.AbsoluteSize;if s and s.X>0 and s.Y>0 then return s.X,s.Y end
 local cam=workspace.CurrentCamera;local v=cam and cam.ViewportSize;if v and v.X>0 and v.Y>0 then return v.X,v.Y end
 return 1280,720
end
-- a framed view of a seed model (as the card frames it): the view, the model's visible centre and its pivot relative to that centre
function C.View(model)
 local view=Instance.new('ViewportFrame');view.Name='Seed';view.BackgroundTransparency=1;view.AnchorPoint=Vector2.new(.5,.5);view.ImageTransparency=1
 view.Ambient=Color3.fromRGB(170,170,182);view.LightColor=Color3.fromRGB(255,250,240);view.LightDirection=Vector3.new(-.6,-1,-.8)
 local cam=Instance.new('Camera');cam.Name='Seed camera';cam.FieldOfView=30;cam.Parent=view;view.CurrentCamera=cam
 model.Parent=view
 local ok,centre,size=pcall(require(RS.RarePullRules).VisibleBounds,model)
 if not ok or not centre then local ok2,cf,s=pcall(function()return model:GetBoundingBox()end);if ok2 and cf then centre,size=cf.Position,s else centre,size=Vector3.zero,Vector3.one end end
 local radius=math.max(.2,math.max(size.X,size.Y,size.Z)*.53)
 cam.CFrame=CFrame.lookAt(centre+Vector3.new(0,radius*.12,radius/math.tan(math.rad(15))*1.08),centre)
 return view,centre,CFrame.new(centre):ToObjectSpace(model:GetPivot())
end
local function cue()pcall(function()require(RS.InteractionAudio).Play(C.ArrivalCue)end)end
-- the whoosh of the flight: the Flight slot, entered so its swell lands on the flight's fastest frame (half way: smoothstep)
local function whoosh(f,now)
 local ok,def=pcall(function()return require(RS.RarePullSounds).Get('Flight')end)
 if not ok or not def or not def.Id then return end
 local s=Instance.new('Sound');s.Name='SeedCollect_Whoosh';s.SoundId=def.Id;s.PlaybackSpeed=(def.Pitch or 1)*C.WhooshPitch;s.Volume=(def.Volume or .1)*C.WhooshVolume
 if def.Region then pcall(function()s.PlaybackRegionsEnabled=true;s.PlaybackRegion=NumberRange.new(def.Region[1],def.Region[2])end)end
 pcall(function()require(RS.AudioMixer).Route(s,'Effects')end)
 s.Parent=game:GetService('SoundService')
 local peak=C.FlySeconds*.5;local bound=def.Region and def.Region[1]or def.Start or 0
 s.TimePosition=math.max(bound,(def.Swell or bound)-peak*s.PlaybackSpeed);s:Play()
 f.Whoosh=s;f.WhooshPeak=now+peak;f.WhooshVolume=s.Volume
end
local function stopWhoosh(f)local s=f.Whoosh;f.Whoosh=nil;if s then pcall(function()s:Stop()end);s:Destroy()end end
-- where it lands (centre and size in the overlay's pixels) and whether the item is on show there
local function aim(f,g,W,H)
 local b,present=C.Target(f.Id,f.Spec)
 if f.Id==nil then present=true end -- (an owner preview: nothing is granted, nothing to wait for)
 local o=g.AbsolutePosition or Vector2.zero
 if b and b.AbsoluteSize and b.AbsoluteSize.X>0 then
  local a,z=b.AbsolutePosition,b.AbsoluteSize
  return a.X+z.X/2-o.X,a.Y+z.Y/2-o.Y,math.min(z.X,z.Y),present,b
 end
 return W*.5,H*.94,math.min(W,H)*.06,true,nil -- (no hotbar on screen: it goes down to where the hotbar is, and nothing waits for it there)
end
local function place(f,x,y,s,alpha,scale)
 local v=f.View
 v.Position=UDim2.fromOffset(x,y);local d=math.max(1,s*(scale or 1));v.Size=UDim2.fromOffset(d,d)
 local tr=1-clamp01(alpha);if v.ImageTransparency~=tr then v.ImageTransparency=tr end
 f.X,f.Y,f.S=x,y,s
end
local function spin(f,now,rate)
 if not(f.Model and f.Model.Parent and f.Centre and f.Base)then return end
 f.Yaw=(f.Yaw or 0)+(now-(f.SpunAt or now))*rate;f.SpunAt=now
 pcall(function()f.Model:PivotTo(CFrame.new(f.Centre)*CFrame.Angles(0,f.Yaw,0)*f.Base)end)
end
local function land(f,now,b)
 if f.Landed then return end
 f.Landed=now;C.Land(f.Id,b);cue()
end
local function stepFly(f,now)
 local g=overlay;if not(g and g.Parent and f.View.Parent)then return true end
 local W,H=extent(g)
 if f.Id~=nil and not f.Landed then C.Touch(f.Id)end
 if f.Whoosh then
  local a=now-f.WhooshPeak
  if a>.45 then stopWhoosh(f)else local vol=f.WhooshVolume*clamp01(1-(a-.15)/.3);if f.Whoosh.Volume~=vol then f.Whoosh.Volume=vol end end
 end
 if f.State=='wait'then
  local a0=f.Alpha0;local alpha=f.FadeIn>0 and a0+(1-a0)*clamp01((now-f.T0)/f.FadeIn)or a0
  place(f,f.From.X,f.From.Y,f.From.S,alpha);spin(f,now,f.Reduced and 0 or .75)
  if now-f.T0<f.Wait then return false end
  f.Alpha0=alpha;f.Start=now
  if f.Reduced then f.State='fade'else f.State='fly';whoosh(f,now)end
 end
 if f.State=='fade'then -- Reduced Motion: a quick fade where it is, then the arrival
  local k=clamp01((now-f.Start)/C.FadeSeconds)
  place(f,f.From.X,f.From.Y,f.From.S,f.Alpha0*(1-k))
  if k>=1 then local _,_,_,_,b=aim(f,g,W,H);land(f,now,b);return true end
  return false
 end
 local tx,ty,ts,present,b=aim(f,g,W,H)
 if f.State=='fly'then
  local u=clamp01((now-f.Start)/C.FlySeconds);local e=smooth(u)
  local p0x,p0y=f.From.X,f.From.Y
  local p1x,p1y=p0x+(tx-p0x)*.3,math.min(p0y,ty)-H*.12 -- (a hop up out of the card, then down into the slot)
  local x=(1-e)^2*p0x+2*(1-e)*e*p1x+e*e*tx;local y=(1-e)^2*p0y+2*(1-e)*e*p1y+e*e*ty
  local s=f.From.S+(ts*.82-f.From.S)*(u*u)
  place(f,x,y,s,f.Alpha0+(1-f.Alpha0)*clamp01(u/.15),1+.1*math.sin(math.pi*clamp01(u/.3)))
  spin(f,now,.75+6*u)
  if u>=1 then f.State='pop';f.PopAt=now;land(f,now,b)end
  return false
 end
 if f.State=='pop'then
  local k=clamp01((now-f.PopAt)/C.PopSeconds)
  place(f,tx,ty,ts*.82,1,1+.3*math.sin(math.pi*k));spin(f,now,2)
  if k>=1 then f.State=present and'out'or'park';f.OutAt=now end
  return false
 end
 if f.State=='park'then -- its tool is on its way (the server's end of the opening, a respawn): it rests on the slot until it is shown
  place(f,tx,ty,ts*.82,1);spin(f,now,.75)
  if present or now-f.PopAt>C.ParkSeconds then f.State='out';f.OutAt=now end
  return false
 end
 local k=clamp01((now-f.OutAt)/C.OutSeconds)
 place(f,tx,ty,ts*.82,1-k);spin(f,now,.75)
 return k>=1
end
local function dropFly(f)flies[f]=nil;stopWhoosh(f);if f.View then f.View:Destroy()end end
local function stepAll()
 local now=os.clock()
 for f in pairs(flies)do
  local ok,done=pcall(stepFly,f,now)
  if not ok then warn('[SeedCollect] '..tostring(done));if not f.Landed then land(f,now,nil)end;done=true end
  if done then dropFly(f)end
 end
 if next(flies)==nil then
  if flyConn then flyConn:Disconnect();flyConn=nil end
  if overlay then overlay:Destroy();overlay=nil end
 end
end
-- opts: {Id, Spec, View (a seed ViewportFrame: the card's own, moved here) or Model (a seed model: a view is made), Centre, Base, Yaw (its spin),
--  From = {X, Y, S}: where it is now (centre, shares of the screen; S = its height, a share of the screen's), Wait (seconds it rests there first:
--  a story scene's way out), FadeIn (seconds: a new view appears), Reduced}. Returns a handle: Go() starts the flight now.
function C.Fly(opts)
 opts=opts or{}
 local now=os.clock()
 local f={Id=opts.Id,Spec=opts.Spec,Reduced=opts.Reduced==true,T0=now,Wait=math.max(0,tonumber(opts.Wait)or 0),FadeIn=tonumber(opts.FadeIn)or 0,State='wait',Yaw=opts.Yaw}
 local view,centre,base=opts.View,opts.Centre,opts.Base
 if not view and opts.Model then local ok,v,c,b=pcall(C.View,opts.Model);if ok then view,centre,base=v,c,b else pcall(function()opts.Model:Destroy()end)end end
 local g=view and screen()
 if not g then -- nothing to fly (no seed model, no screen): it arrives at once
  if view then view:Destroy()end
  land(f,now,nil);return {Go=function()end,Fly=f}
 end
 f.View,f.Centre,f.Base=view,centre,base;f.Model=view:FindFirstChildWhichIsA('Model')
 local W,H=extent(g);local from=opts.From or{X=.5,Y=.5,S=.3}
 f.From={X=(from.X or .5)*W,Y=(from.Y or .5)*H,S=math.max(8,(from.S or .3)*H)}
 f.Alpha0=f.FadeIn>0 and 0 or 1-clamp01(view.ImageTransparency or 0)
 view.AnchorPoint=Vector2.new(.5,.5);view.Visible=true;view.ZIndex=5
 for _,c in ipairs(view:GetChildren())do if c:IsA('UIAspectRatioConstraint')then c:Destroy()elseif c:IsA('UIScale')then c.Scale=1 end end
 view.Parent=g;place(f,f.From.X,f.From.Y,f.From.S,f.Alpha0)
 flies[f]=true
 if not flyConn then flyConn=Run.RenderStepped:Connect(stepAll)end
 return {Go=function()if f.State=='wait'then f.Wait=0 end end,Fly=f}
end
function C.Flying()local n=0;for _ in pairs(flies)do n+=1 end;return n end
-- Everything at once (the director's script going, a test): no fly is left, every hold ends quietly, the hand shows what it holds.
function C.Clear()
 for f in pairs(flies)do dropFly(f)end
 if flyConn then flyConn:Disconnect();flyConn=nil end
 if overlay then overlay:Destroy();overlay=nil end
 local ids={};for id in pairs(holds)do ids[#ids+1]=id end
 for _,id in ipairs(ids)do ends(id,false)end
 for tool in pairs(hidden)do showTool(tool)end;unwatch()
end
return C
