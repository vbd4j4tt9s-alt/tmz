do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R152 (owner: "add a pedestal in the middle that gives a player 1 void pack ... there is a number above that shows how many is left"): the client half of the Void Pack giveaway
-- pedestal in the hub's plaza (the stone, the prompt and the count are the server's: VoidGiveaway152 / VoidGiveawayArt152). This script:
--  * hangs the NUMBER over the pedestal: a BillboardGui in studs (so it shrinks with distance and can never fill the screen from afar), stopped from growing closer than
--    Rules.SignNear (DistanceLowerLimit, the same fix the mystery pedestal's label got in R148), shown up to Rules.SignFar. A small title ("FREE VOID PACK", "ALL CLAIMED" at 0),
--    the number ("487 / 500 LEFT": every change pops it), and for YOU a line ("CLAIMED ✓" once your pack is in, "CLAIMING…" while the server works). The numbers are the server's
--    pedestal attributes (Left / State) and your own player attribute (VoidGift152), so the sign ticks down live for everyone.
--  * floats a Void Pack over the cradle, built the way the game renders one (SeedPackVisuals.Bag -> EclipsePackArt, the same art as the track's), turning slowly and hovering; its
--    glow and particles are VoidPackFx's (haze, nebula, stars, debris, comets, the pulsing light), which are moved WITH the pack every frame, so they are on the pack itself. It
--    is built here (client only) and not by the server, like the Fruit of the Hour's fruit; if the pack art cannot be built a plain stand-in pouch takes its place. At 0 left the
--    pack sleeps: it still turns, its glow and sparks are off.
--  * turns the prompt off for YOU once you have claimed (the server turns it off for everyone at 0), and plays the claim moment when your pack arrives: the pack hops, a spark
--    burst, the sign pops, and the game's reward chime (InteractionAudio GemClaim: no new sound). The text notice ("FREE VOID PACK! Check your Bag!") is the server's.
--  * R158c (owner: "for the void pack there isn't a 20 minute lock anymore and requirement is just finishing the tutorial"): until your player attribute TutorialDone is true (finished or skipped)
--    the line under the number reads "finish the tutorial to claim" and the prompt is off for you; it updates the moment TutorialDone changes. Once you have claimed the sign says "CLAIMED ✓"
--    whatever the tutorial says (one pack per player), and the line is only for a player the server has set up (your VoidGift152 is Open). The text is a constant: nothing is rebuilt per frame.
-- Per frame: only while a pedestal's pack is inside ACTIVE_IN studs of the camera (leaves at ACTIVE_OUT); nothing runs for a pedestal that is far. Tier 3 steps it every frame;
-- tier 2 and below at 30 Hz and without the pack's Highlight (VoidPackFx.Create's noHighlight): the per-frame costs a phone felt. Quality tiers and the plant
-- effects setting limit the effects like the track's Void packs (ClientFxBudget / VoidPackFx.Budget); Reduced Motion: no turn, no bob, no pop, no moving fx (the same parts, still).
-- The place uses StreamingEnabled: the pedestal is Persistent, but a pedestal is found by its tag whenever it appears, its parts are looked up again each half second until they
-- are there, and one that goes away is forgotten (a streamed-back copy starts clean).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local Tween=game:GetService('TweenService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer
local Rules=require(RS:WaitForChild('VoidGiveawayRules152'))
local PackFx;pcall(function()PackFx=require(RS:WaitForChild('VoidPackFx',10))end)
local Budget;pcall(function()Budget=require(RS:WaitForChild('ClientFxBudget',10))end)
local Audio;pcall(function()Audio=require(RS:WaitForChild('InteractionAudio',10))end)
local Cull;pcall(function()Cull=require(RS:WaitForChild('ViewCull152',5))end) -- R152 perf: a pack out of view does not move or recolour its own pieces
local RGB=Color3.fromRGB
local A=Rules.Attr
local ACTIVE_IN,ACTIVE_OUT=190,230 -- the pack turns and wears its effects inside this many studs of the camera (leaving at ACTIVE_OUT)
local LOOK={ -- the sign's pill: fill, outline, how see-through
 Open={Pill=RGB(22,12,46),Stroke=RGB(150,96,236),Alpha=.1},
 Empty={Pill=RGB(26,20,38),Stroke=RGB(96,84,120),Alpha=.22},
}
local entries={};local connections={};local folder
local tierNow=3
local function reduced()return GuiService.ReducedMotionEnabled==true end
-- R158c: true while you still have to finish the tutorial (TutorialDone is not true: the same test the server makes).
local function tutorialLeft()return not Rules.TutorialDone(player:GetAttribute(Rules.TutorialAttr))end
local function quality()
 local tier=3
 if Budget then local ok,t=pcall(Budget.Get);if ok and type(t)=='number'then tier=t end end
 local mode=player:GetAttribute('StudioPlantEffects');if mode=='low'then tier=1 end
 return math.clamp(tier,1,3)
end
local function packFolder()
 if folder and folder.Parent then return folder end
 folder=Instance.new('Folder');folder.Name='VoidGiveawayPacks152';folder.Parent=workspace;return folder
end
-- The sign ---------------------------------------------------------------------------------------------------------------------------------------------------
local function label(parent,name,x,y,w,h,color)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.AnchorPoint=Vector2.new(.5,.5);t.Position=UDim2.fromScale(x,y);t.Size=UDim2.fromScale(w,h);t.ZIndex=2
 t.Font=Enum.Font.FredokaOne;t.TextScaled=true;t.TextColor3=color;t.TextStrokeTransparency=.2;t.TextStrokeColor3=RGB(10,6,22);t.Text='';t.Parent=parent;return t
end
local function buildSign(entry)
 local gui=Instance.new('BillboardGui');gui.Name='VoidGiveawaySign';gui.Adornee=entry.SignAnchor;gui.Size=UDim2.fromScale(Rules.Sign.W,Rules.Sign.H)
 gui.DistanceLowerLimit=Rules.SignNear;gui.MaxDistance=Rules.SignFar;gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.ResetOnSpawn=false
 local pill=Instance.new('Frame');pill.Name='Pill';pill.Size=UDim2.fromScale(1,1);pill.BackgroundColor3=LOOK.Open.Pill;pill.BackgroundTransparency=LOOK.Open.Alpha;pill.BorderSizePixel=0;pill.ZIndex=1;pill.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.3,0);corner.Parent=pill
 local stroke=Instance.new('UIStroke');stroke.Name='Outline';stroke.Color=LOOK.Open.Stroke;stroke.Thickness=3;stroke.Parent=pill
 local shade=Instance.new('UIGradient');shade.Color=ColorSequence.new(Color3.new(1,1,1),RGB(160,150,180));shade.Rotation=90;shade.Parent=pill
 local title=label(gui,'Title',.5,.17,.88,.2,RGB(214,150,255))
 local count=label(gui,'Count',.5,.52,.94,.44,RGB(240,226,255))
 local note=label(gui,'Note',.5,.85,.88,.17,RGB(170,140,230))
 local pop=Instance.new('UIScale');pop.Name='Pop';pop.Scale=1;pop.Parent=count
 gui.Parent=entry.Model
 entry.Gui,entry.Pill,entry.Stroke,entry.Title,entry.Count,entry.Note,entry.Pop=gui,pill,stroke,title,count,note,pop
end
-- What the sign says and how it looks, from the pedestal's attributes and mine. Returns the number shown (nil while loading).
local function render(entry)
 local m=entry.Model;if not entry.Gui or not entry.Gui.Parent then return end
 local left=m:GetAttribute(A.Left);left=type(left)=='number'and left or nil
 local state=m:GetAttribute(A.State)or'Loading';local mine=player:GetAttribute(A.Player)
 local done=state=='Empty'
 local look=done and LOOK.Empty or LOOK.Open
 local function set(obj,prop,value)if obj[prop]~=value then obj[prop]=value end end
 set(entry.Title,'Text',done and Rules.TitleDone or Rules.Title);set(entry.Title,'TextColor3',done and RGB(150,132,184)or RGB(214,150,255))
 set(entry.Count,'Text',Rules.LeftText(left,m:GetAttribute(A.Cap)or Rules.Cap))
 set(entry.Count,'TextColor3',done and RGB(150,132,184)or(left and left<=25)and RGB(255,205,120)or RGB(240,226,255))
 local note,color='',RGB(170,140,230)
 if mine=='Claimed'then note,color=Rules.Mine,RGB(126,240,170)
 elseif mine=='Busy'then note,color=Rules.Busy,RGB(255,225,150)
 elseif state=='Open'and mine=='Open'and tutorialLeft()then note,color=Rules.TutorialHint,RGB(255,205,120) -- R158c: finish the tutorial first
 elseif state=='Open'then note=Rules.Hint end
 set(entry.Note,'Text',note);set(entry.Note,'TextColor3',color)
 set(entry.Pill,'BackgroundColor3',look.Pill);set(entry.Pill,'BackgroundTransparency',look.Alpha);set(entry.Stroke,'Color',look.Stroke)
 return left
end
-- A short pop of the number (a quick overshoot back to size). Reduced motion: none.
local function pop(entry,big)
 if reduced()or not entry.Pop then return end
 entry.Pop.Scale=big and 1.3 or 1.18
 Tween:Create(entry.Pop,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
end
-- The prompt: on only while the server says Open AND you have not claimed (and no claim of yours is in flight).
local function applyPrompt(entry)
 local prompt=entry.Prompt;if not prompt or not prompt.Parent then return end
 local want=entry.Model:GetAttribute(A.State)=='Open'and player:GetAttribute(A.Player)=='Open'and not tutorialLeft() -- (R158c: off until the tutorial is finished)
 if prompt.Enabled~=want then prompt.Enabled=want end
end
-- The pack ---------------------------------------------------------------------------------------------------------------------------------------------------
-- A plain pouch when the pack art cannot be built (its meshes missing, a build error): a dark violet block with a glowing seam, so the pedestal is never empty.
local function standIn(at)
 local m=Instance.new('Model');m.Name='VoidGiveawayPack'
 local body=Instance.new('Part');body.Name='VisualRoot';body.Size=Vector3.new(4.4,5.8,1.2);body.CFrame=at;body.Color=RGB(20,10,40);body.Material=Enum.Material.SmoothPlastic
 body.Anchored=true;body.CanCollide=false;body.CanTouch=false;body.CanQuery=false;body.CastShadow=false;body.Parent=m
 local seam=Instance.new('Part');seam.Name='Seam';seam.Size=Vector3.new(4.6,.4,1.4);seam.CFrame=at*CFrame.new(0,2.5,0);seam.Color=RGB(176,108,255);seam.Material=Enum.Material.Neon
 seam.Anchored=true;seam.CanCollide=false;seam.CanTouch=false;seam.CanQuery=false;seam.CastShadow=false;seam.Parent=m
 m.PrimaryPart=body;m.Parent=packFolder();return m
end
local function buildPack(entry)
 if entry.Pack and entry.Pack.Parent then return end
 local anchor=entry.PackAnchor;if not anchor then return end
 local at=CFrame.new(anchor.Position)
 local ok,bag=pcall(function()
  local Visuals=require(RS:WaitForChild('SeedPackVisuals'))
  local b=Visuals.Bounds(Rules.Pack.Stage,Rules.Pack.BagVariant,1)
  local scale=Rules.PackSize/math.max(b.MaxY-b.MinY,.1)
  return Visuals.Bag(at,packFolder(),scale,nil,Rules.Pack.Stage,Rules.Pack.BagVariant,1,1,'None')
 end)
 if ok and bag then
  CS:RemoveTag(bag,'BiomeSeedPackVisual') -- (ours: the track's Void-pack renderer and VoidPackFx's usual owner leave it alone)
  for _,d in ipairs(bag:GetDescendants())do
   if d:IsA('BasePart')then d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false
   elseif d:IsA('BaseScript')or d:IsA('Sound')or d:IsA('JointInstance')or d:IsA('WeldConstraint')then d:Destroy()end
  end
  bag.Name='VoidGiveawayPack';entry.Pack=bag
  entry.R=PackFx and PackFx.Capture(bag)or nil
  -- R153 perf (lag audit D3): every piece that never moves against the bag (all but the galaxy / halo spinners) is welded to the pack's root,
  -- which stays anchored, and the spinners of one ring (the same pivot and rate) are welded to an invisible hub that turns about that pivot. A
  -- step then moves the root and the few hubs (r.Moving) instead of every piece: each piece gets the very pose VoidPackFx.Pose gave it
  -- (hover x frame, hover x pivot x turn x offset), ~190 moves become ~4. (A root that spins itself, or a missing one: every piece posed, as before.)
  if entry.R then pcall(function()
   local r=entry.R;local root=r.Root;local rootE
   for _,e in ipairs(r.Parts)do if e.Part==root then rootE=e end end
   if not rootE or rootE.Spin then return end
   -- (worked out first, then applied: a failure leaves the pack untouched, every piece posed as before)
   local toRoot=rootE.Frame:Inverse();local moving={rootE};local hubs={};local joins={}
   local function ring(e)
    local p,l,u=e.Pivot.Position,e.Pivot.LookVector,e.Pivot.UpVector
    return string.format('%.6f|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f',e.Spin,p.X,p.Y,p.Z,l.X,l.Y,l.Z,u.X,u.Y,u.Z)
   end
   for _,e in ipairs(r.Parts)do if e~=rootE then
    if e.Spin then
     local key=ring(e);local hub=hubs[key]
     if not hub then hub={Frame=e.Pivot,Spin=e.Spin,Pivot=e.Pivot,Offset=CFrame.new()};hubs[key]=hub;moving[#moving+1]=hub end
     joins[#joins+1]={hub,e.Part,e.Offset}
    else joins[#joins+1]={rootE,e.Part,toRoot*e.Frame}end
   end end
   for _,hub in ipairs(moving)do if hub~=rootE then
    local p=Instance.new('Part');p.Name='PackSpinHub153';p.Size=Vector3.new(.05,.05,.05);p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanTouch=false
    p.CanQuery=false;p.CastShadow=false;p.CFrame=root.CFrame*toRoot*hub.Pivot;p.Parent=bag;hub.Part=p
   end end
   for _,j in ipairs(joins)do
    local w=Instance.new('Weld');w.Name='PackWeld153';w.C0=j[3];w.Part0=j[1].Part;w.Part1=j[2];w.Parent=j[1].Part
    j[2].Massless=true;j[2].Anchored=false
   end
   r.Moving=moving
  end)end
  -- (R152 perf: a ball round the pack's pieces as it turns, hovers and hops: out of view = none of them can be on screen)
  local okR,reach=pcall(function()
   local o=at.Position;local far=0
   for _,d in ipairs(bag:GetDescendants())do if d:IsA('BasePart')then far=math.max(far,(d.Position-o).Magnitude+d.Size.Magnitude/2)end end
   return far
  end)
  entry.Reach=okR and reach>0 and reach+Rules.PackBob+1.5+2 or nil
 else
  warn('[R152] Void giveaway: the Void Pack art could not be built ('..tostring(bag)..'); a plain pouch is shown.')
  entry.Pack=standIn(at);entry.R=nil
 end
end
local function dropPack(entry)
 if entry.R and PackFx then pcall(PackFx.Clear,entry.R)end
 if entry.Pack then entry.Pack:Destroy()end
 entry.Pack,entry.R=nil,nil
end
local function hopCurve(dt)if dt<0 or dt>.6 then return 0 end;return math.sin(dt/.6*math.pi)*1.5 end
local parts,frames={},{}
-- One frame of one pack: the hover and the turn, the pack's parts and its effects moved together in one batch.
local function stepPack(entry,dt,t,now)
 local anchor=entry.PackAnchor;if not anchor or not entry.Pack then return end
 local rm=reduced()
 if not rm then entry.Spin=((entry.Spin or 0)+dt*Rules.PackSpin)%(math.pi*2)end
 local lift=(rm and 0 or math.sin(t*1.3)*Rules.PackBob)+(rm and 0 or hopCurve(t-(entry.HopAt or -10)))
 local origin=CFrame.new(anchor.Position+Vector3.new(0,lift,0))*CFrame.Angles(0,entry.Spin or 0,0)
 local r=entry.R
 if not r then entry.Pack:PivotTo(origin);return end
 r.Origin=origin;table.clear(parts);table.clear(frames)
 local frame=origin
 -- R152 perf: out of view (and not close up) the pack's own pieces stay where they are and keep their colours; its effects (core, emitters, light,
 -- debris, comets) still move every step. In the step it is back in view the pieces get this moment's pose and pulse: on screen nothing differs.
 local hidden=Cull and entry.Reach and Cull.Hidden(workspace.CurrentCamera,anchor.Position,entry.Reach,12)
 -- (the pose a hidden step skipped: the pieces take it if the pack stops being stepped while out of view, where every step used to leave them)
 if hidden then
  local o=entry.StaleRec;if not o then o={};entry.StaleRec=o end
  o.Origin,o.Now,o.Rm,o.Spin=origin,now,rm,entry.Dist<PackFx.Budget.SpinDistance;entry.Stale=o
 else entry.Stale=nil end
 if hidden then if not rm then frame=PackFx.HoverFrame(r,now)end
 elseif rm then -- reduced motion: the same parts, standing still (VoidPackFx.Pose would still sway and bob the pack)
  for _,e in ipairs(r.Moving or r.Parts)do if e.Part.Parent then parts[#parts+1]=e.Part;frames[#frames+1]=origin*PackFx.LocalFrame(e,now,false)end end
 else frame=PackFx.Pose(r,now,parts,frames,entry.Dist<PackFx.Budget.SpinDistance)end
 local want=entry.Dist<PackFx.Budget.EffectDistance and player:GetAttribute('StudioPlantEffects')~='off'and entry.Model:GetAttribute(A.State)~='Empty' -- (at 0 the pack sleeps: it turns, but its glow and sparks are off)
 if r.Fx and(not want or r.Fx.Tier~=tierNow)then PackFx.Clear(r)end
 if want and not r.Fx then PackFx.Create(r,tierNow,tierNow<3)end -- (tier 2 and below: no Highlight)
 if r.Fx then if not hidden then PackFx.Pulse(r,now,rm)end;PackFx.Step(r,now,frame,tierNow,rm,true,parts,frames)end
 workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)
end
-- R152 perf: the pieces' pose of the last step, when that step was out of view and skipped them (the pack stops being stepped: it leaves its range)
local function settle(entry)
 local o=entry.Stale;local r=entry.R;entry.Stale=nil
 if not(o and r and PackFx and entry.Pack)then return end
 table.clear(parts);table.clear(frames)
 r.Origin=o.Origin
 if o.Rm then for _,e in ipairs(r.Moving or r.Parts)do if e.Part.Parent then parts[#parts+1]=e.Part;frames[#frames+1]=o.Origin*PackFx.LocalFrame(e,o.Now,false)end end
 else PackFx.Pose(r,o.Now,parts,frames,o.Spin)end
 workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)
end
-- The loop (connected only while a pack is near) --------------------------------------------------------------------------------------------------------------
local loop
local STEP_LOW=1/30 -- tier 2 and below (phones), out of view only: the whole pack step (pose, debris, comets, pulse) runs at 30 Hz, with the time it skipped, so the turn keeps its speed
-- R153 (owner: "fix all jittery type effects"): in view the pack steps every rendered frame on every tier (on tier 2 and below it turned in 30 Hz
-- steps on a 60 Hz screen: R152 fix B5). The tier-2 saving stays where nothing is seen: out of view (ViewCull152), 30 Hz.
local function inView(entry)
 local anchor=entry.PackAnchor
 return not(Cull and entry.Reach and anchor and Cull.Hidden(workspace.CurrentCamera,anchor.Position,entry.Reach,12))
end
local function frame(dt)
 local busy=false;local t=os.clock();local now=workspace:GetServerTimeNow()
 for _,entry in pairs(entries)do
  if entry.Active and entry.Pack then
   busy=true
   entry.Owed=(entry.Owed or STEP_LOW)+dt
   if tierNow>=3 or entry.Owed>=STEP_LOW-.004 or inView(entry)then
    local step=entry.Owed;entry.Owed=0
    local ok,err=pcall(stepPack,entry,step,t,now);if not ok then entry.Failed=(entry.Failed or 0)+1;if entry.Failed==1 then warn('[R152] Void giveaway pack: '..tostring(err))end end
   end
  end
 end
 if not busy and loop then loop:Disconnect();loop=nil end
end
local function wake()if not loop then loop=Run.RenderStepped:Connect(frame)end end
-- Entries ----------------------------------------------------------------------------------------------------------------------------------------------------
local function measure(entry)
 local cam=workspace.CurrentCamera;local anchor=entry.PackAnchor
 entry.Dist=(cam and anchor and anchor.Parent)and(cam.CFrame.Position-anchor.Position).Magnitude or math.huge
 return entry.Dist
end
-- Parts may arrive after the model: look them up again until they are there (and again if they are replaced).
local function resolve(entry)
 local m=entry.Model
 if not(entry.PackAnchor and entry.PackAnchor.Parent)then entry.PackAnchor=m:FindFirstChild('PackAnchor')end
 if not(entry.SignAnchor and entry.SignAnchor.Parent)then entry.SignAnchor=m:FindFirstChild('SignAnchor')end
 local prompt=m:FindFirstChildWhichIsA('ProximityPrompt',true)
 if prompt~=entry.Prompt then
  entry.Prompt=prompt
  if prompt then table.insert(entry.Links,prompt:GetPropertyChangedSignal('Enabled'):Connect(function()applyPrompt(entry)end))end
 end
 if entry.SignAnchor and not(entry.Gui and entry.Gui.Parent)then buildSign(entry)end
 if entry.Gui and entry.Gui.Adornee~=entry.SignAnchor then entry.Gui.Adornee=entry.SignAnchor end
end
local function refresh(entry)
 resolve(entry);measure(entry)
 local left=render(entry)
 if entry.Shown~=left then local first=entry.Shown==nil;entry.Shown=left;if not first and left~=nil then pop(entry,false)end end
 applyPrompt(entry)
 tierNow=quality()
 local near=entry.Dist<=(entry.Active and ACTIVE_OUT or ACTIVE_IN)
 if near and not entry.Pack and entry.PackAnchor then buildPack(entry)end
 local active=near and entry.Pack~=nil
 if active and not entry.Active then wake()end
 if entry.Active and not active then pcall(settle,entry)end -- (R152 perf: a pose skipped out of view is put back first)
 if entry.Active and not active and entry.R and PackFx then pcall(PackFx.Clear,entry.R)end -- (leaving: the effects go, the pack stays where it is)
 entry.Active=active
end
local function add(model)
 if not model:IsA('Model')or entries[model]then return end
 local entry={Model=model,Links={},Spin=0}
 entries[model]=entry
 for _,name in ipairs({A.Left,A.State,A.Cap})do
  table.insert(entry.Links,model:GetAttributeChangedSignal(name):Connect(function()refresh(entry)end))
 end
 refresh(entry)
end
local function remove(model)
 local entry=entries[model];if not entry then return end
 entries[model]=nil
 for _,c in ipairs(entry.Links)do c:Disconnect()end
 dropPack(entry);if entry.Gui then entry.Gui:Destroy()end
end
-- Your claim: the moment (a pack arrived for YOU just now).
local function moment()
 local at=player:GetAttribute(A.At)
 if type(at)~='number'or math.abs(workspace:GetServerTimeNow()-at)>20 then return end
 if Audio then pcall(Audio.Play,'GemClaim')end
 for _,entry in pairs(entries)do
  entry.HopAt=os.clock();pop(entry,true)
  local fx=entry.R and entry.R.Fx
  if fx and not reduced()then pcall(function()fx.Nebula:Emit(16);fx.Stars:Emit(28)end)end
 end
end
for _,m in ipairs(CS:GetTagged(Rules.Tag))do add(m)end
table.insert(connections,CS:GetInstanceAddedSignal(Rules.Tag):Connect(add))
table.insert(connections,CS:GetInstanceRemovedSignal(Rules.Tag):Connect(remove))
table.insert(connections,player:GetAttributeChangedSignal(A.Player):Connect(function()for _,entry in pairs(entries)do render(entry);applyPrompt(entry)end end))
table.insert(connections,player:GetAttributeChangedSignal(Rules.TutorialAttr):Connect(function()for _,entry in pairs(entries)do render(entry);applyPrompt(entry)end end)) -- R158c: finishing (or skipping) the tutorial opens the claim at once
table.insert(connections,player:GetAttributeChangedSignal(A.At):Connect(moment))
-- Twice a second: parts that arrived, how far the camera is, who is near enough to turn (nothing is per frame for a far pedestal).
local clock=0
table.insert(connections,Run.Heartbeat:Connect(function(dt)
 clock+=dt;if clock<.5 then return end;clock=0
 for _,entry in pairs(entries)do refresh(entry)end
end))
script.Destroying:Connect(function()
 for _,c in ipairs(connections)do c:Disconnect()end
 if loop then loop:Disconnect();loop=nil end
 for model in pairs(entries)do remove(model)end
 if folder then folder:Destroy();folder=nil end
end)
