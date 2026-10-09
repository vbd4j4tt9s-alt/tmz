-- R151: the director of every pull reveal on the OPENER's screen (PackOpeningFeedback starts it when the server publishes RevealAt).
--  Common..Mythic  'Ladder': the seed card (RarePullCard), the suspense sounds (RarePullAudio), a light colour grade, and for Legendary /
--                  Mythic a short camera push (FieldOfView only). The pack's own suspense in the world is SeedPackClient (everyone sees it).
--  Secret+ 'Scene' (Full, or Calm with ReducedMotion): the world dims and desaturates, letterbox, fade to black, the hidden story stage
--                  (RarePullScenes) with the camera, silence, the hit, the seed hero shot, fade back; the HUD is hidden and movement held
--                  meanwhile. Skippable after SkipFrom (tap / click anywhere, Space, Enter, A / B / R2): before the hit it jumps to the
--                  hit, after it to the way out.
--  Secret+ 'InPlace' when the full scene is not safe (RarePullRules.Decide: a keeper near or chasing, on the track, ragdoll, a run, a menu,
--                  someone else's camera, in the air; R153: or "Skip pack animations" on): no camera, no hidden stage, HUD and controls
--                  untouched, a compact card in the upper third timed to the world seed's burst.
-- Restores EXACTLY on every exit path (normal end, skip, death, character removed, a keeper turning up, being moved / teleported, someone
-- replacing the camera, an error in a frame, the script being destroyed): Camera (type, CFrame, focus, FieldOfView, subject), controls,
-- every ScreenGui it hid (only those), Core GUI it turned off (only those); its own colour grade / blur live on the Camera and are destroyed;
-- Lighting itself is never written. Nothing runs per frame once a presentation ends.
-- For the R151 pull announcements: LocalPlayer attributes RarePullCinematic (kind, while running) and RarePullClimaxAt (server time of the
-- hit): the puller's own banner should wait for that time (others can be told at once).
-- R152 (owner: "audio syncing issues and animation issues"): RarePullSeedShownAt (server time the seed is shown: title, seed and "1 in N"
-- slammed; the hit alone came up to .85 s before it) is what the puller's own chat line waits for; the sounds are preloaded when the
-- client starts (Bind); the music is ducked on the presentation's clock; a pack opened while the last card is still up cross-fades it out
-- (.18 s) and takes over its camera push smoothly instead of snapping the card away and the FieldOfView back.
-- R153 (owner: "pack animations should play all the time and shouldn't stop after 2/3 times. they can skip if they want or we can add a
-- skip cutscene option in the settings"): every opening plays in full (no "quick" reveal for packs opened back to back). Skipping is the
-- player's choice: every card is skippable too (M.Skip; a click / tap on the world, Enter, the gamepad's B / R2: to the hit, then closed),
-- and the setting "Skip pack animations" gives the short version (RarePullRules.SkipAnimations / Decide).
-- R154 (owner: "after obtaining the seed the seed stays on the player's screen until they click and the seed goes to their inventory"): the
-- result WAITS. Once it is shown (the seed, its name, rarity and "1 in N": ShownAt) nothing closes it: no timer, the card / the story scene's
-- hero shot stays, "click to collect!" / "tap to collect!" (Card) until a click / tap anywhere, Enter, B or R2 (the same rules as the skip;
-- the press is the reveal's: RarePullRules.ClaimPress). That press COLLECTS it: the seed flies from the card into its hotbar slot (or the
-- Bag button) and pops (SeedCollect154); a story scene first goes back to the world (its way out, quicker). Until it has flown in, the seed
-- is held out of the hotbar and the hand on this screen (the server's timing is unchanged: the seed was the player's on the 5th click and
-- its tool is handed over when the server ends the opening, as before). A waiting result is never lost: whatever takes the player away
-- (death, a fling, a chase, a teleport, leaving the base or the track, a menu, the next pack opened) collects it first. The sounds and the
-- duck end on the presentation's own Length as before (the result then waits in silence); a collect before that fades their tail
-- (RarePullAudio.FadeOut), so the collect's whoosh and pop never stack on it.
-- R155 (owner: "... dynamic camera movement like a cinema scene ... only secret to king"): inside the stage the Secret / Cosmic / King camera
-- is the cinematic one (RarePullCamera155: shots, cuts on the sounds, moves, dutch tilt, lens; a pure function of the scene's clock) with a
-- depth of field on the Camera (RarePullDof, every device; made on entering the stage, gone with it on every exit path). The world before the
-- cut to black (the lens-only push) and the cut back to the world are today's: the player's own camera is never moved. Without the module (or
-- if it fails three frames in a row) the stage keeps today's camera (RarePullRules.Shot). Common..Mythic are unchanged.
-- R155 (owner: "for some cutscenes u can skip it by spam clicking disable this feature and u can only skip at the bottom right of the
-- screen"), every presentation: a click / tap anywhere never skips any more (a run of clicks during the animation does nothing; it is still
-- the reveal's, never a tool's: no planting, digging or swinging). The skip is the SKIP button at the bottom right (RarePullCard) - and
-- gamepad B / R2 and Enter, which press it - from SkipFrom until the hit. The waiting result is still collected by a click / tap anywhere,
-- but only by a press that STARTED once it had been shown for CollectAfter s (M.Tap): a burst of clicks from the animation never collects it.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService');local UIS=game:GetService('UserInputService');local CAS=game:GetService('ContextActionService')
local Collection=game:GetService('CollectionService');local StarterGui=game:GetService('StarterGui')
local Rules=require(script.Parent.RarePullRules);local Audio=require(script.Parent.RarePullAudio)
local Cache do local ok,m=pcall(require,script.Parent.PropCache152);Cache=ok and m or{new=function()return{Set=function(o,k,v)o[k]=v end}end}end -- (R152 perf)
local Collect do local ok,m=pcall(require,script.Parent.SeedCollect154);Collect=ok and m or nil end -- (R154)
local M={}
do local ok,m=pcall(require,script.Parent.RarePullCamera155);M.Camera=ok and m or nil end -- (R155: the story scenes' cinematic camera)
M.BindName='ChestChaseRarePull';M.SkipAction='ChestChaseRarePullSkip'
M.KeepGuis={TouchGui=true,Freecam=true,SeedCollectFly=true} -- (R154: the seed flying home is never hidden by a story scene)
M.CoreTypes={'PlayerList','Chat','EmotesMenu','Health','Backpack'}
M.DangerRadius=45;M.MoveLimit=8
local current=nil;M.LastEnd=-math.huge
local lastPress=-math.huge -- (R153: the last press on the world)
local pressBegan,pressKey=nil,false -- (R155: the press being claimed: when it began, and whether it is a key that presses the SKIP button)
local function clamp01(x)return math.clamp(x,0,1)end
local function lp()return Players.LocalPlayer end
local function reduced()local ok,v=pcall(function()return Gui.ReducedMotionEnabled end);return ok and v==true end
local function phone()
 local cam=workspace.CurrentCamera;local vp=cam and cam.ViewportSize
 return(UIS.TouchEnabled and not UIS.KeyboardEnabled)or(vp~=nil and math.min(vp.X,vp.Y)>0 and math.min(vp.X,vp.Y)<500)
end
local function lite()
 if phone()then return true end
 local ok,B=pcall(require,script.Parent.ClientFxBudget);if ok and B then local ok2,low=pcall(B.Low);if ok2 and low then return true end end
 return false
end
local function remotes()return RS:FindFirstChild('ChestChaseRemotes')end
-- The seed's display name, its "1 in N" (R153: its fixed chance, SeedRarity153; the Index chance if that cannot load) and a model of it.
function M.SeedInfo(seedId,tool)
 local r=remotes();local catalog=r and r:FindFirstChild('SeedCatalog');local entry=catalog and catalog:FindFirstChild(seedId)
 local name=entry and entry:GetAttribute('DisplayName')
 if not name then
  local ok,Packs=pcall(require,RS:FindFirstChild('SeedPackRules'))
  if ok and Packs and Packs.SeedDesignById and Packs.SeedDesignById[seedId]then name=Packs.SeedDesignById[seedId].name end
 end
 name=name or tostring(seedId)
 -- R153 (owner: a Cosmic from a Void pack must still read how rare it is): the seed's one fixed chance (SeedRarity153), never the held pack's own rows (those answer what THAT pack gives).
 local odds
 local okC,Canon=pcall(require,RS:FindFirstChild('SeedRarity153'));if okC and Canon then odds=Canon.Count(seedId)end
 if not odds and entry then
  local chance=entry:GetAttribute('BaseChance')
  if type(chance)=='number'and chance>0 then local ok,O=pcall(require,RS:FindFirstChild('OddsText85'));if ok then odds=O.Count(1/(math.min(chance,100)/100))end end
 end
 return name,odds
end
function M.SeedModel(seedId,mutation)
 local r=remotes();local art=r and r:FindFirstChild('SeedArt');local seeds=art and art:FindFirstChild('Seeds');local template=seeds and seeds:FindFirstChild(seedId)
 local seed
 if template then seed=template:Clone()
 else -- (R152: not published (yet): built here with the same art code, so the card / scene still shows the seed)
  local ok,m=pcall(function()return require(RS.SeedPackVisuals).Seed({Id=seedId},1,CFrame.new(),nil,1,nil,'None')end)
  if not ok or typeof(m)~='Instance'then return nil end
  seed=m
 end
 seed.Name='RarePullSeed';seed:SetAttribute('SeedMotionManaged',true)
 for _,tag in ipairs(Collection:GetTags(seed))do Collection:RemoveTag(seed,tag)end
 pcall(function()require(RS.PlantVisuals).Coat(seed,mutation)end)
 for _,d in ipairs(seed:GetDescendants())do
  if d:IsA('BasePart')then d.Anchored=true;d.LocalTransparencyModifier=0
  elseif d:IsA('Script')or d:IsA('LocalScript')or d:IsA('Sound')then d:Destroy()end
 end
 return seed
end
-- A copy of the pack in the player's hands (or, for an owner preview, a fresh stand-in of the seed's biome).
function M.PackModel(bag,seedId)
 local copy
 if bag and bag.Parent then
  local ok,c=pcall(function()return bag:Clone()end);copy=ok and c or nil
  if copy then
   copy.Name='RarePullPack'
   for _,tag in ipairs(Collection:GetTags(copy))do Collection:RemoveTag(copy,tag)end
   for _,d in ipairs(copy:GetDescendants())do
    if d:IsA('JointInstance')or d:IsA('WeldConstraint')or d:IsA('Script')or d:IsA('LocalScript')or d:IsA('Sound')then d:Destroy()
    elseif d:IsA('BasePart')then d.Anchored=true;d.LocalTransparencyModifier=d:GetAttribute('PackProxy')and bag:GetAttribute('NativePackArtReady')and 1 or 0 end
   end
   local orbit=copy:FindFirstChild('PackOrbitEffects');if orbit then orbit:Destroy()end
  end
 end
 if not copy then
  local ok,Visuals=pcall(require,RS:FindFirstChild('SeedPackVisuals'));local okP,Packs=pcall(require,RS:FindFirstChild('SeedPackRules'))
  if ok and okP then
   local stage=1
   local spec=Packs.SeedDesignById and Packs.SeedDesignById[seedId]
   if spec then for s,b in pairs(Packs.DesignBiomes or{})do if b==spec.biome then stage=s end end end
   local ok2,m=pcall(Visuals.Bag,CFrame.new(0,-400,0),nil,1,nil,stage,'Pack06',1,1,'None')
   if ok2 and m then copy=m;copy.Name='RarePullPack';for _,tag in ipairs(Collection:GetTags(copy))do Collection:RemoveTag(copy,tag)end end
  end
 end
 return copy
end
-- Safety --------------------------------------------------------------------------------------------------------------------------------
local function onTrack(root)
 local motion=RS:FindFirstChild('RunnerMotion');if not motion or not root then return false end
 local lineZ,cx,half=motion:GetAttribute('TrackBoundaryZ'),motion:GetAttribute('TrackCenterX'),motion:GetAttribute('TrackHalfWidth')
 if type(lineZ)~='number'or type(cx)~='number'or type(half)~='number'then return false end
 return root.Position.Z>lineZ and math.abs(root.Position.X-cx)<=half
end
local airStates={Freefall=true,Jumping=true,Swimming=true,Seated=true,Climbing=true,FallingDown=true,Ragdoll=true,Physics=true,Dead=true}
function M.Snapshot()
 local player=lp();local char=player and player.Character
 local hum=char and char:FindFirstChildOfClass('Humanoid');local root=char and char:FindFirstChild('HumanoidRootPart')
 local s={Alive=hum~=nil and hum.Health>0 and root~=nil,Root=root}
 if not player then s.Alive=false;return s end
 s.Ragdoll=player:GetAttribute('GuardianRagdollActive')==true or player:GetAttribute('GuardianFlingActive')==true or(char~=nil and char:GetAttribute('ChestChaseRagdollActive')==true)
 s.Running=player:GetAttribute('ChestChaseRunActive')==true or player:GetAttribute('ChestChaseQueued')==true or player:GetAttribute('ChestChaseSeedCarrying')==true
 local pg=player:FindFirstChildOfClass('PlayerGui');s.Menu=pg~=nil and(pg:GetAttribute('SeedMenu')~=nil or pg:GetAttribute('TitleActive')==true)
 local cam=workspace.CurrentCamera;s.CameraType=cam and cam.CameraType and cam.CameraType.Name or nil
 local best,chasing=math.huge,false
 for _,k in ipairs(Collection:GetTagged('BiomeKeeper'))do
  local kr=k:IsA('Model')and(k.PrimaryPart or k:FindFirstChild('HumanoidRootPart'))
  if kr and root then local d=(kr.Position-root.Position).Magnitude;if d<best then best=d end end
  local state=k:GetAttribute('GuardianBehavior')
  if k:GetAttribute('TargetUserId')==player.UserId and(state=='ALERTED'or state=='CHASING'or state=='ATTACKING'or state=='DASHING')then chasing=true end
 end
 s.KeeperDistance=best;s.KeeperChasing=chasing;s.OnTrack=onTrack(root)
 s.SkipCutscenes=Rules.SkipAnimations() -- (R153: the player's "Skip pack animations")
 local ok,state=pcall(function()return hum and hum:GetState()end)
 s.Grounded=not(ok and state and airStates[state.Name])
 return s
end
-- HUD / Core GUI / controls ---------------------------------------------------------------------------------------------------------------
local function hideOne(run,g)
 if g:IsA('ScreenGui')and g~=run.Gui and g.Enabled and not M.KeepGuis[g.Name]then g.Enabled=false;run.Hidden[g]=true end
end
local function hideHud(run,pg)
 run.Hidden={};run.Core={}
 for _,g in ipairs(pg:GetChildren())do hideOne(run,g)end
 run.HudConn=pg.ChildAdded:Connect(function(g)if run.Hidden then hideOne(run,g)end end)
 for _,name in ipairs(M.CoreTypes)do
  local ty=Enum.CoreGuiType[name]
  local ok,on=pcall(function()return StarterGui:GetCoreGuiEnabled(ty)end)
  if ok and on==true then pcall(function()StarterGui:SetCoreGuiEnabled(ty,false)end);run.Core[#run.Core+1]=ty end
 end
end
local function rehide(run,pg)if run.Hidden then for _,g in ipairs(pg:GetChildren())do hideOne(run,g)end end end
local function showHud(run)
 if run.HudConn then run.HudConn:Disconnect();run.HudConn=nil end
 for g in pairs(run.Hidden or{})do if g.Parent and not g.Enabled then g.Enabled=true end end
 for _,ty in ipairs(run.Core or{})do pcall(function()StarterGui:SetCoreGuiEnabled(ty,true)end)end
 run.Hidden=nil;run.Core=nil
end
local function controls()
 local player=lp();local ps=player and player:FindFirstChild('PlayerScripts');local pm=ps and ps:FindFirstChild('PlayerModule')
 if not pm then return nil end
 local ok,m=pcall(require,pm);if not ok or type(m)~='table'or not m.GetControls then return nil end
 local ok2,c=pcall(function()return m:GetControls()end);return ok2 and c or nil
end
local function holdControls(run)
 local c=controls();if c and c.Disable then local ok=pcall(function()c:Disable()end);if ok then run.Controls=c end end
end
local function releaseControls(run)
 local c=run.Controls;run.Controls=nil
 if c and c.Enable then pcall(function()c:Enable()end)end
end
-- Camera ------------------------------------------------------------------------------------------------------------------------------
local function saveCamera(run)
 local cam=workspace.CurrentCamera;if not cam then return end
 run.CameraState={Camera=cam,Type=cam.CameraType,CFrame=cam.CFrame,Focus=cam.Focus,Fov=cam.FieldOfView,Subject=cam.CameraSubject}
end
local function restoreCamera(run)
 local s=run.CameraState;if not s then return end
 local cam=workspace.CurrentCamera
 if run.InStage then
  run.InStage=false
  if cam==s.Camera then
   cam.CFrame=s.CFrame;cam.Focus=s.Focus;cam.FieldOfView=s.Fov;cam.CameraType=s.Type
   if s.Subject and s.Subject.Parent then cam.CameraSubject=s.Subject end
  end
 elseif cam==s.Camera and run.FovWritten and cam.FieldOfView==run.FovWritten and not run.KeepFov then cam.FieldOfView=s.Fov end
 run.FovWritten=nil
end
-- The camera push a replaced presentation leaves behind: the next one takes it over and eases it out (no FieldOfView snap).
local function carry(run)
 local c=run.Carry;if not c then return 0 end
 local k=(os.clock()-c.T0)/.3;if k>=1 then run.Carry=nil;return 0 end
 return c.From*(1-Rules.Smooth(k))
end
-- Colour grade on the Camera (never Lighting): {Brightness, Contrast, Saturation, Tint, Blur}
-- (R152 perf: the grade's and the blur's values are written only when they change: they are this run's own)
local function grade(run,b,c,s,tint,blur)
 local cam=workspace.CurrentCamera;if not cam then return end
 if not run.Grade or run.Grade.Parent~=cam then
  if run.Grade then run.Grade:Destroy()end
  local g=Instance.new('ColorCorrectionEffect');g.Name='RarePullGrade';g.Parent=cam;run.Grade=g
 end
 local S=run.Set
 local g=run.Grade;S(g,'Brightness',b);S(g,'Contrast',c);S(g,'Saturation',s);S(g,'TintColor',tint)
 if blur and blur>.05 and not run.Lite then
  if not run.Blur or run.Blur.Parent~=cam then local bl=Instance.new('BlurEffect');bl.Name='RarePullBlur';bl.Parent=cam;run.Blur=bl end
  S(run.Blur,'Size',blur)
 elseif run.Blur then run.Blur:Destroy();run.Blur=nil end
end
local WHITE=Color3.new(1,1,1)
-- Finishing -----------------------------------------------------------------------------------------------------------------------------
local finish,collect
-- R154: reasons that end a presentation without its seed flying in (the script going, a test, a failed start): the hold just ends
M.NoCollect={aborted=true,destroyed=true,test=true,['start failed']=true}
M.CollectAfter=.25 -- a press this soon after the result is shown only lands (the clicks of a skip go on for a moment)
M.SceneExit=.35 -- a collected story scene's fade to black (R153: FloatEnd -> Back, .5-.7 s), then the world and the seed's flight
M.TailFade=.2 -- a collect while the reveal still rings: its tail fades out over this
M.TeleportStep=30 -- studs in one frame: a teleport (no runner moves that far in a frame) ...
M.TeleportRuns=3 -- ... and no more than this many times the distance the runner's WalkSpeed covers in the time since the last frame (a hitch, 10-15 fps)
M.TeleportMaxDt=1 -- (seconds counted for that: a longer freeze is not a reason to stop seeing a teleport)
M.LeaveDistance=90 -- studs from where the result was shown: the player has left
M.Forever=1e6 -- (seconds: a beat that does not come while the result waits)
local function unbind(run)
 if run.Bound then run.Bound=false;pcall(function()Run:UnbindFromRenderStep(run.BindName or M.BindName)end)end
 if run.SkipBound then run.SkipBound=false;pcall(function()CAS:UnbindAction(M.SkipAction)end)end
 for _,c in ipairs(run.Connections)do c:Disconnect()end;table.clear(run.Connections)
end
local function leaveStage(run)
 if run.Dof then run.Dof:Destroy();run.Dof=nil end -- (R155: the stage's depth of field goes with it)
 restoreCamera(run);showHud(run);releaseControls(run)
 if run.SkipBound then run.SkipBound=false;pcall(function()CAS:UnbindAction(M.SkipAction)end)end
 if run.SkipButton then run.SkipButton:Destroy();run.SkipButton=nil end
 if run.Scene then run.Scene:Destroy();run.Scene=nil end
end
-- R152: a card replaced by the next pack fades out (FadeSeconds) under the new one instead of vanishing; its grade eases to nothing.
M.FadeSeconds=.18
local fading,fadeConn={},nil
local fadeProps={'BackgroundTransparency','TextTransparency','TextStrokeTransparency','ImageTransparency'}
local function fadeStep()
 local now=os.clock()
 for f in pairs(fading)do
  local k=math.clamp((now-f.T0)/M.FadeSeconds,0,1)
  for _,it in ipairs(f.Items)do pcall(function()it[1][it[2]]=it[3]+(1-it[3])*k end)end
  local g=f.Grade
  if g and g.Parent then local a=1-k;g.Brightness=f.G[1]*a;g.Contrast=f.G[2]*a;g.Saturation=f.G[3]*a;g.TintColor=f.G[4]:Lerp(WHITE,k)end
  if k>=1 then fading[f]=nil;if f.Gui then f.Gui:Destroy()end;if g then g:Destroy()end end
 end
 if next(fading)==nil and fadeConn then fadeConn:Disconnect();fadeConn=nil end
end
local function fadeOut(gui,g)
 local f={Gui=gui,Grade=g,Items={},T0=os.clock()}
 if gui then
  gui.DisplayOrder-=1;gui.Name='RarePullRevealOut'
  for _,d in ipairs(gui:GetDescendants())do
   if d:IsA('GuiObject')then
    if d:IsA('GuiButton')then d.Visible=false end
    for _,p in ipairs(fadeProps)do local ok,v=pcall(function()return d[p]end);if ok and type(v)=='number'and v<1 then f.Items[#f.Items+1]={d,p,v}end end
   elseif d:IsA('UIStroke')and d.Transparency<1 then f.Items[#f.Items+1]={d,'Transparency',d.Transparency}end
  end
 end
 if g then f.G={g.Brightness,g.Contrast,g.Saturation,g.TintColor};g.Name='RarePullGradeOut'end
 fading[f]=true
 if not fadeConn then fadeConn=Run.Heartbeat:Connect(fadeStep)end
end
function M.Fading()local n=0;for _ in pairs(fading)do n+=1 end;return n end
local function clearFades()for f in pairs(fading)do fading[f]=nil;if f.Gui then f.Gui:Destroy()end;if f.Grade then f.Grade:Destroy()end end;if fadeConn then fadeConn:Disconnect();fadeConn=nil end end
finish=function(run,reason)
 if run.Done then return end
 -- R154: a revealed seed is never lost: whatever ends its presentation (death, a fling, a chase, a menu, the next pack ...) it flies in first
 if run.SawClimax and not run.Collected and not M.NoCollect[reason]then return collect(run,reason)end
 run.Done=true;run.Reason=reason
 pcall(unbind,run)
 pcall(leaveStage,run)
 pcall(restoreCamera,run)
 if(reason=='replaced'or run.Collected)and run.Kind~='Scene'and run.Gui then -- (R154: a collected card fades the same way, its seed flying off)
  pcall(fadeOut,run.Gui,run.Grade);run.Gui=nil;run.Grade=nil;run.Card=nil;run.SeedModel=nil
 end
 if run.Grade then run.Grade:Destroy();run.Grade=nil end
 if run.Blur then run.Blur:Destroy();run.Blur=nil end
 if run.Dof then run.Dof:Destroy();run.Dof=nil end
 if run.Card then pcall(function()run.Card:Destroy()end);run.Card=nil end
 if run.Gui then run.Gui:Destroy();run.Gui=nil end
 if run.SeedModel and run.SeedModel.Parent then run.SeedModel:Destroy()end
 if run.Audio then run.Audio=false;pcall(Audio.Stop)end
 for tool in pairs(run.Held or{})do pcall(function()if tool.ManualActivationOnly then tool.ManualActivationOnly=false end end)end;run.Held=nil;run.Armed=false
 local player=lp()
 if player and(current==run or current==nil)then
  player:SetAttribute('RarePullCinematic',nil);player:SetAttribute('RarePullClimaxAt',nil);player:SetAttribute('RarePullSeedShownAt',nil)
 end
 if current==run then current=nil end
 if M._building==run then M._building=nil end
 M.LastEnd=os.clock();Rules.RevealRunning=current~=nil
 -- a story scene that had to stop before its hit still shows the result (a compact card), unless the player died / left
 local follow=(reason=='danger'or reason=='moved'or reason=='camera'or reason=='error')and run.Kind=='Scene'and not run.SawClimax and run.Info
 -- (R154: its hold goes on to that card; any other presentation that ends without its seed flying in lets it show now)
 if Collect and not run.Collected and not follow then pcall(Collect.Release,run.Id);pcall(Collect.MarkBag,run.Info and run.Info.Bag,nil)end
 if run.Fly then pcall(run.Fly.Go)end
 if follow then
  local info=table.clone(run.Info);info.Result=true
  -- (R154: a follow-up that does not start - no PlayerGui, a failure before it has its id - leaves nothing to release the hold: do it here)
  task.defer(function()
   if not current then if not M.Start(info)and Collect then pcall(Collect.Release,run.Id)end
   elseif Collect then pcall(Collect.Release,run.Id)end
  end)
 end
end
-- R154 ---------------------------------------------------------------------------------------------------------------------------------------
-- The seed flies home (SeedCollect154): a card's own seed view, or (a story scene) its hero seed, centred as the scene frames it. wait: seconds
-- it rests there first (the scene's way out). Without the module or a model it arrives at once.
local function startFly(run,wait)
 if not Collect then return nil end
 local opts={Id=run.Id,Spec=run.Spec,Reduced=run.Reduced,Wait=wait}
 local seed=run.Card and run.Card.TakeSeed and run.Card:TakeSeed()
 if seed then
  opts.View=seed.View;opts.Centre=seed.Centre;opts.Base=seed.Base;opts.Yaw=seed.Yaw;opts.From={X=seed.X,Y=seed.Y,S=seed.S}
  run.SeedModel=nil -- (it flies with its view)
 else
  local ok,m=pcall(M.SeedModel,run.Info.SeedId,run.Info.Mutation)
  opts.Model=ok and m or nil;opts.FadeIn=.15;opts.From={X=.5,Y=.5,S=Rules.HeroDiameter.To*1.08}
 end
 local ok,h=pcall(Collect.Fly,opts)
 if ok then return h end
 warn('[RarePull] collect: '..tostring(h));pcall(Collect.Land,run.Id)
 return nil
end
-- A story scene collected by the player: its way out from t (the fade to black over SceneExit, the world, the grade easing back).
local function exitBeats(run,t)
 local tl=run.TL;local b=table.clone(tl)
 b.FloatEnd=t;b.Back=t+M.SceneExit;b.Length=b.Back+(tl.Length-tl.Back);b.WaitEnd=t
 return b
end
-- What the card (and a story scene's screen beats) see while the result waits: nothing goes out (Out / Length, a scene's FloatEnd / Back far
-- away). The stage, the camera, the grade of a card and the sounds keep the real timeline.
local function waitBeats(run)
 local b=table.clone(run.TL);b.Wait=true;b.Out=M.Forever;b.Length=M.Forever
 if run.Kind=='Scene'then b.FloatEnd=M.Forever;b.Back=M.Forever end
 return b
end
collect=function(run,why)
 if run.Collected or run.Done then return end
 run.Collected=true;run.CollectWhy=why
 if Collect then pcall(Collect.MarkBag,run.Info and run.Info.Bag,os.clock())end
 if run.Audio then run.Audio=false;pcall(Audio.FadeOut,M.TailFade)end
 if run.Kind=='Scene'and why=='press'and run.InStage then
  run.Beats=exitBeats(run,run.Clock());run.Exit=run.Beats
  run.Fly=startFly(run,M.SceneExit)
  return
 end
 run.Fly=startFly(run,0)
 finish(run,why)
end
-- the pack this reveal opened: its inventory id is the seed's (the server keeps it); a pack put away on the frame its reveal began is found as
-- the one the server switched off
local function packId(info)
 local tool=info.Tool;local id=tool and tool:GetAttribute('SeedInventoryId')
 if id~=nil then return id end
 local player=lp();local places={player.Character,player:FindFirstChildOfClass('Backpack')}
 for i=1,2 do local c=places[i];if c then for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')and t:GetAttribute('SeedPackTool')and t.Enabled==false then return t:GetAttribute('SeedInventoryId')end end end end
 return nil
end
-- what the seed tool will look like (the Hotbar puts it with a stack of the same seed): the attributes the server gives it, from the pack
local function specOf(info)
 local bag=info.Bag;local spec={SeedId=info.SeedId}
 local ok,Packs=pcall(require,RS:FindFirstChild('SeedPackRules'))
 if bag and ok and Packs then
  spec.Mutation=Packs.MutationKey(bag:GetAttribute('PackMutation')or info.Mutation)
  local scale=bag:GetAttribute('SeedScale');if scale~=nil then spec.SeedScale=Packs.SanitizeSeedScale(scale)end
 end
 if bag then spec.Rarity=bag:GetAttribute('Rarity');spec.Weather=bag:GetAttribute('Weather')end
 return spec
end
-- A waiting result collects itself (flies in) when the player is taken away from it: death, a ragdoll / fling, a chase (or a keeper chasing),
-- a teleport, leaving the base or the track, a menu (the shop, the Bag ...) opening. Each counts as a CHANGE while it waits: one already going
-- on when the result was shown does not, so a result is never collected the moment it appears.
local function waitCheck(run)
 local player=lp();local char=player and player.Character
 if char~=run.Character then return'death'end
 local root=char and char:FindFirstChild('HumanoidRootPart')
 if root then
  local p=root.Position
  local at=os.clock();local dt=math.clamp(at-(run.LastPosAt or at),0,M.TeleportMaxDt)
  if run.LastPos then
   -- the farthest a runner gets between two checks: the floor, or what its speed (WalkSpeed, or a faster fall / push) covers in the time between them, times a margin
   local hum=char:FindFirstChildOfClass('Humanoid');local speed=hum and tonumber(hum.WalkSpeed)or 0
   local vel=root.AssemblyLinearVelocity;if vel and vel.Magnitude>speed then speed=vel.Magnitude end
   if(p-run.LastPos).Magnitude>math.max(M.TeleportStep,speed*dt*M.TeleportRuns)then return'teleport'end
  end
  run.LastPos=p;run.LastPosAt=at
 end
 if os.clock()<(run.NextWait or 0)then return nil end
 run.NextWait=os.clock()+.2
 local s=M.Snapshot()
 if not s.Alive then return'death'end
 local now={Ragdoll=s.Ragdoll==true,Chase=s.Running==true or s.KeeperChasing==true,Menu=s.Menu==true,Track=s.OnTrack==true}
 local was=run.WaitState;run.WaitState=now
 if not was then run.WaitPos=s.Root and s.Root.Position;return nil end
 if now.Ragdoll and not was.Ragdoll then return'ragdoll'end
 if now.Chase and not was.Chase then return'chase'end
 if now.Menu and not was.Menu then return'menu'end
 if now.Track~=was.Track then return'left'end
 if run.WaitPos and s.Root and(s.Root.Position-run.WaitPos).Magnitude>M.LeaveDistance then return'left'end
 return nil
end
-- Starting ------------------------------------------------------------------------------------------------------------------------------
-- info: {Rank, SeedId, At (RevealAt, server time), Bag, Tool, Mutation, Preview, Result}. Returns the run, or nil (nothing is left behind:
-- a failure while building cleans up whatever it had made, and PackOpeningFeedback falls back to the older reveal).
function M.Start(info)
 local ok,run=pcall(M._start,info)
 if ok then return run end
 warn('[RarePull] start failed: '..tostring(run))
 local half=M._building;M._building=nil
 if half then finish(half,'start failed')end
 return nil
end
-- the camera push of the presentation being replaced, handed to the next one (it eases it out)
local function handoff(old)
 local cam=workspace.CurrentCamera;local s=old.CameraState
 if old.InStage or not s or cam~=s.Camera or not old.FovWritten or cam.FieldOfView~=old.FovWritten then return nil end
 old.KeepFov=true;return {Fov=s.Fov,Written=old.FovWritten}
end
function M._start(info)
 local player=lp();if not player or type(info)~='table'then return nil end
 M.Listen()
 local pg=player:FindFirstChildOfClass('PlayerGui');if not pg then return nil end
 local rank=math.clamp(math.floor(tonumber(info.Rank)or 1),1,8)
 -- (R152: the same reveal asked for again - the pack re-equipped mid-reveal - keeps playing; it used to restart as a "quick" reveal)
 if current and not current.Done and info.Bag~=nil and current.Info.Bag==info.Bag and current.At==tonumber(info.At)then return current end
 local hand
 if current then hand=handoff(current);finish(current,'replaced')end
 local run={Info=info,Rank=rank,Connections={},Reduced=reduced(),Phone=phone(),Lite=lite(),At=tonumber(info.At)or workspace:GetServerTimeNow(),Character=player.Character}
 run.Set=Cache.new().Set;run.Held={}
 M._building=run
 -- what kind of presentation
 if rank<=5 then
  run.Kind='Ladder'
  run.Quick=not info.Preview and Rules.QuickFor(info.Bag) -- (R153: only with "Skip pack animations" on; the same answer the world pack gets)
  Rules.MarkQuick(info.Bag,run.Quick)
  run.TL=Rules.CardTimeline(rank,run.Quick);run.Offset=0;run.Clock=function()return workspace:GetServerTimeNow()-run.At+run.Offset end
  run.Cues=Rules.LadderCues(rank,run.Quick)
 elseif info.Result then
  run.Kind='Result';run.TL=Rules.Timeline(rank,'Result');local t0=os.clock();run.Offset=0;run.Clock=function()return os.clock()-t0+run.Offset end
  run.Cues=Rules.SceneCues(rank,run.TL)
 else
  local okS,snap=pcall(M.Snapshot)
  if okS and snap and info.Preview then snap.SkipCutscenes=nil end -- (an owner preview always plays in full)
  local variant,why=Rules.Decide(okS and snap or nil)
  run.Why=why
  if variant=='Full'then
   run.Kind='Scene';run.Variant=run.Reduced and'Calm'or'Full';run.TL=Rules.Timeline(rank,run.Variant)
   local t0=os.clock()-math.clamp(workspace:GetServerTimeNow()-run.At,0,.15);run.Offset=0
   run.Clock=function()return os.clock()-t0+run.Offset end
  else
   run.Kind='InPlace';run.TL=Rules.Timeline(rank,'InPlace');run.Offset=0;run.Clock=function()return workspace:GetServerTimeNow()-run.At+run.Offset end
  end
  run.Cues=Rules.SceneCues(rank,run.TL)
 end
 local okI,name,odds=pcall(M.SeedInfo,info.SeedId,info.Tool)
 if not okI then name,odds=tostring(info.SeedId or''),nil end
 run.SeedName,run.Odds=name,odds
 -- the screen layer
 local gui=Instance.new('ScreenGui');gui.Name='RarePullReveal';gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=96
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;pcall(function()gui.ScreenInsets=Enum.ScreenInsets.None end);gui.Parent=pg;run.Gui=gui
 local Card=require(script.Parent.RarePullCard)
 local cardKind=run.Kind=='Ladder'and'Ladder'or run.Kind=='Scene'and'Scene'or'InPlace'
 local seedForCard=nil
 if cardKind~='Scene'then local okM,m=pcall(M.SeedModel,info.SeedId,info.Mutation);seedForCard=okM and m or nil end
 run.SeedModel=seedForCard
 run.Card=Card.Create(gui,cardKind,{Rank=rank,Phone=run.Phone,Reduced=run.Reduced,Lite=run.Lite,Quick=run.Quick,SeedName=name,Odds=odds,Seed=seedForCard,
  Skip=run.TL.SkipFrom~=nil and run.TL.SkipFrom<math.huge})
 -- audio (every slot was preloaded when the client started: Bind)
 local slots={};local seen={};for _,c in ipairs(run.Cues)do if not seen[c.Slot]then seen[c.Slot]=true;slots[#slots+1]=c.Slot end end
 pcall(Audio.Preload,slots)
 -- (R152: the sounds belong to this run even when their first frame failed - the sheet is set and plays on - so its end always stops them;
 -- an error there used to leave them playing after the reveal)
 -- (R155: the SKIP button at the bottom right: the only way to skip, with gamepad B / R2 and Enter)
 if run.Card.SkipButton then table.insert(run.Connections,run.Card.SkipButton.Activated:Connect(function()if current==run then M.Skip()end end))end
 local okA,errA=pcall(Audio.Begin,run.Cues,run.Clock(),run.TL.Length);run.Audio=true
 if not okA then warn('[RarePull] sounds: '..tostring(errA))end
 -- the hit and the moment the seed is shown, for the announcements
 local climax=run.Kind=='Ladder'and run.TL.Burst or run.TL.Climax
 local now=workspace:GetServerTimeNow();local t=run.Clock()
 player:SetAttribute('RarePullCinematic',run.Kind)
 player:SetAttribute('RarePullClimaxAt',now+math.max(0,climax-t))
 player:SetAttribute('RarePullSeedShownAt',now+math.max(0,Rules.ShownAt(run.TL)-t))
 -- the story scene: camera, HUD, controls, the stage, the skip
 if run.Kind=='Scene'then
  saveCamera(run);hideHud(run,pg);holdControls(run)
  local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart');run.StartPos=root and root.Position;run.Character=player.Character
  local ok,scene=pcall(function()
   local Scenes=require(script.Parent.RarePullScenes)
   return Scenes.Build(rank,{Lite=run.Lite,Reduced=run.Reduced,Pack=M.PackModel(info.Bag,info.SeedId),Seed=M.SeedModel(info.SeedId,info.Mutation)})
  end)
  if ok then run.Scene=scene else warn('[RarePull] stage build failed: '..tostring(scene))end
  local button=Instance.new('TextButton');button.Name='Backdrop';button:SetAttribute('ButtonHighlight',false);button:SetAttribute('ButtonSound',false)
  button.BackgroundTransparency=1;button.Text='';button.AutoButtonColor=false;button.Size=UDim2.fromScale(1,1);button.ZIndex=40;button.Selectable=false;button.Parent=gui
  run.SkipButton=button
  -- (R155: the full-screen button takes every click / tap - the world never gets one - but it only ever collects the waiting result, and only
  -- a press that began after it was shown: its InputBegan says when; the SKIP button above it is the skip)
  table.insert(run.Connections,button.InputBegan:Connect(function(input)
   local ty=input and input.UserInputType;if ty==Enum.UserInputType.MouseButton1 or ty==Enum.UserInputType.Touch then run.TapBegan=os.clock()end
  end))
  table.insert(run.Connections,button.Activated:Connect(function()local began=run.TapBegan;run.TapBegan=nil;M.Tap(began)end))
  local ok2=pcall(function()
   CAS:BindActionAtPriority(M.SkipAction,function(_,state,input)
    if state==Enum.UserInputState.Begin then
     local k=input and input.KeyCode
     if M.SkipKeys[k]then M.Skip()else M.Tap(os.clock())end -- (B / R2 / Enter: the SKIP button's keys; Space / A collect only)
    end
    return Enum.ContextActionResult.Sink
   end,false,Enum.ContextActionPriority.High.Value,Enum.KeyCode.Space,Enum.KeyCode.Return,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.ButtonR2)
  end)
  run.SkipBound=ok2 -- (R153: R2 too: the gamepad's "click"; taken here, so no pack can be opened under a story scene)
  local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
  if hum then table.insert(run.Connections,hum.Died:Connect(function()finish(run,'death')end))end
  table.insert(run.Connections,workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()if run.InStage then finish(run,'camera')end end))
 else
  saveCamera(run)
  if hand and run.CameraState then run.CameraState.Fov=hand.Fov;run.FovWritten=hand.Written;run.Carry={From=hand.Fov-hand.Written,T0=os.clock()}end
 end
 table.insert(run.Connections,player.CharacterRemoving:Connect(function()finish(run,'death')end))
 current=run;M._building=nil;Rules.RevealRunning=true
 -- R154: the result waits (Beats); the seed is held out of the hotbar and the hand until it has flown in, the world seed of this pack with it
 run.Beats=waitBeats(run)
 if Collect and not info.Preview then
  run.Id=packId(info);run.Spec=specOf(info)
  if run.Id~=nil then pcall(Collect.Hold,run.Id,{Spec=run.Spec})end
  pcall(Collect.MarkBag,info.Bag,'held')
 end
 local priority=Enum.RenderPriority.Camera.Value+2
 pcall(function()Run:UnbindFromRenderStep(M.BindName)end) -- (a binding a failed run could not remove never blocks the next one)
 run.BindName=M.BindName
 Run:BindToRenderStep(M.BindName,priority,function()
  if run.Done then return end
  local ok,err=pcall(M._step,run,pg)
  if not ok then warn('[RarePull] '..tostring(err));finish(run,'error')end
 end)
 run.Bound=true
 return run
end
-- Every frame -------------------------------------------------------------------------------------------------------------------------
-- R152: a failing piece (the card, the grade, a sound) never stops the reveal: one that fails once skips that frame only, one failing three
-- frames in a row is left out for the rest of it (logged); the reveal plays on and ends on its own clock. Only the camera / timeline
-- failing ends it (cleanly, restoring everything). (A first version switched a piece off on its first error: one bad frame froze the card.)
local function part(run,name,fn,...)
 local n=run.Broken and run.Broken[name]
 if n and n>=3 then return end
 local ok,err=pcall(fn,...)
 if ok then if n then run.Broken[name]=nil end;return end
 run.Broken=run.Broken or{};n=(n or 0)+1;run.Broken[name]=n
 if n==1 then warn('[RarePull] '..name..' failed (the frame goes on without it): '..tostring(err))elseif n==3 then warn('[RarePull] '..name..' keeps failing, the reveal goes on without it')end
end
M.Part=part
local function shake(run,t)
 if run.Reduced then return CFrame.new()end
 local a=t-run.TL.Climax;if a<0 or a>.5 then return CFrame.new()end
 local k=(1-a/.5)^2*(run.Phone and .35 or 1)*Rules.Smooth(a/.03) -- (R152: the hit's shake swells in over 30 ms: no camera jump on the hit frame)
 return CFrame.new(math.sin(t*90)*.12*k,math.sin(t*73)*.09*k,0)*CFrame.Angles(0,0,math.sin(t*61)*math.rad(1.1)*k)
end
-- R155: the stage camera at t: the cinematic camera (RarePullCamera155) with its depth of field (RarePullDof on the Camera, like the grade and
-- the blur; on every device: the owner's choice), or today's (RarePullRules.Shot) without the module, and for good once it has failed three
-- frames in a row (one bad frame shows today's framing for that frame only). Returns eye, target (stage-local), FieldOfView, roll (degrees).
local function sceneCamera(run,t,tl,cam)
 local rig=run.Cam
 if rig and(run.CamErrors or 0)<3 then
  local vp=cam.ViewportSize
  local ok,eye,target,fov,roll=pcall(M.Camera.Shot,rig,t,vp and vp.Y>0 and vp.X/vp.Y or nil)
  if ok then
   run.CamErrors=nil
   local d=run.Dof
   if not d or d.Parent~=cam then if d then d:Destroy()end;d=Instance.new('DepthOfFieldEffect');d.Name='RarePullDof';d.Parent=cam;run.Dof=d end
   local S=run.Set;S(d,'FocusDistance',rig.Focus);S(d,'InFocusRadius',rig.Radius);S(d,'FarIntensity',rig.Far);S(d,'NearIntensity',rig.Near)
   return eye,target,fov,roll
  end
  run.CamErrors=(run.CamErrors or 0)+1;if run.CamErrors==1 then warn('[RarePull] camera: '..tostring(eye))end
 end
 if run.Dof and(run.CamErrors or 0)>=3 then run.Dof:Destroy();run.Dof=nil end -- (given up: today's camera has no depth of field)
 local eye,target,fov=Rules.Shot(run.Rank,run.Variant,t,tl)
 return eye,target,fov,0
end
-- FieldOfView push in the world (the player's camera keeps control; only written while nobody else has changed it)
local function push(run,cam,amount)
 amount=math.max(amount,carry(run))
 if not(cam and run.CameraState and cam==run.CameraState.Camera and cam.CameraType==Enum.CameraType.Custom)then return end
 if amount<=0 and not run.FovWritten then return end
 if run.FovWritten==nil or cam.FieldOfView==run.FovWritten then
  local fov=run.CameraState.Fov-amount
  if cam.FieldOfView~=fov then cam.FieldOfView=fov end -- (R152 perf: an unchanged push is not written again)
  run.FovWritten=cam.FieldOfView
 end
end
local function ladderGrade(run,t,tl,tier)
 local q=clamp01(t/tl.Burst)
 local after=t>=tl.Burst and(1-clamp01((t-tl.Burst)/math.max(.1,tl.Length-tl.Burst)))or 0
 local G=tier.Grade
 local hint=Rules.Hint(run.Rank,q)
 local pre=t<tl.Burst and q or 0
 local spike=t>=tl.Burst and .22*G*(1-clamp01((t-tl.Burst)/.25))or 0
 grade(run,-.08*G*pre+spike,.12*G*(pre+after*.5),-.6*G*pre-.25*G*after,WHITE:Lerp(hint,.12*pre),nil)
end
-- R153 follow-up (coordinator: the click that skips a card must not also plant the seed just put in the hand, or use the shovel): a press
-- on the world is the reveal's when a card would take it now (Armed: it would skip / close it) or a story scene runs (it owns every press).
-- The routes that act on a held tool (planting, the shovel, digging, giving) ask RarePullRules.ClaimPress first and do nothing when it is
-- the reveal's; a tool the engine activates on a click (a pack, the bat) is set ManualActivationOnly on this client for as long as a press
-- would be the reveal's, and put back the moment it would be the tool's again or the reveal ends. No reveal: the tools work as before.
-- (R154: a result that waits takes every press, until it is collected)
-- (R155: a card takes every press from its first frame until it is collected: a click never skips, but it is never the tool's either)
local function armed(run,t)
 if run.Kind=='Scene'or run.Collected then return false end
 return true
end
local function holdTool(run,hold)
 local player=lp();local char=hold and player and player.Character;local tool=char and char:FindFirstChildOfClass('Tool')
 for held in pairs(run.Held)do if held~=tool then run.Held[held]=nil;if held.ManualActivationOnly then held.ManualActivationOnly=false end end end
 if tool and not run.Held[tool]and tool.ManualActivationOnly==false then tool.ManualActivationOnly=true;run.Held[tool]=true end
end
function M._step(run,pg)
 local t=run.Clock();local tl=run.TL;local tier=Rules.Tier(run.Rank)
 -- (R154: a card never ends by itself now: it waits for the collect; a story scene ends with its way out after the collect)
 if run.Exit and t>=run.Exit.Length then finish(run,'done');return end
 if t>=(tl.Climax or tl.Burst or 0)then run.SawClimax=true end
 if not run.SawResult and t>=Rules.ShownAt(tl)then run.SawResult=true end
 if t>=tl.Length and not run.Idle and not run.Collected then -- (R154: the reveal's sounds and duck are over: the result waits in silence)
  run.Idle=true;if run.Audio then run.Audio=false;pcall(Audio.Stop)end;Rules.RevealRunning=false
 end
 if Collect and run.Id~=nil then Collect.Touch(run.Id)end
 if run.SawResult and not run.Collected then
  local ok,why=pcall(waitCheck,run)
  if ok and why then finish(run,why);return end
 end
 run.Armed=armed(run,t);part(run,'tool',holdTool,run,run.Armed or run.Kind=='Scene')
 local cam=workspace.CurrentCamera
 local beats=run.Beats or tl
 if run.Kind=='Ladder'then
  part(run,'card',run.Card.UpdateLadder,run.Card,t,beats)
  local q=clamp01(t/tl.Burst)
  local amount=0
  if tier.Push>0 and not run.Reduced then amount=t<tl.Burst and tier.Push*Rules.Smooth(q)or tier.Push*(1-Rules.Smooth((t-tl.Burst)/.3))end
  part(run,'camera',push,run,cam,amount)
  part(run,'grade',ladderGrade,run,t,tl,tier)
 elseif run.Kind=='InPlace'or run.Kind=='Result'then
  part(run,'card',run.Card.UpdateInPlace,run.Card,t,beats)
  part(run,'camera',push,run,cam,0)
  local pre=run.Kind=='InPlace'and clamp01(t/math.max(.01,tl.Climax))or 0
  local post=t>=tl.Climax and 1-clamp01((t-tl.Climax)/math.max(.1,tl.Length-tl.Climax))or 0
  part(run,'grade',grade,run,-.08*pre+(t>=tl.Climax and .2*(1-clamp01((t-tl.Climax)/.3))or 0),.1*(pre+post*.5),-.35*pre-.15*post,WHITE,nil)
 else
  M._stepScene(run,pg,t,tl,tier,cam)
  if run.Done then return end
 end
 if run.Idle or run.Collected then return end -- (the sheet is over, or its tail fades by itself: RarePullAudio.FadeOut)
 part(run,'duck',Audio.Duck,Rules.Duck(run.Kind,run.Rank,tl,t))
 part(run,'audio',Audio.Update,t)
end
local sceneLook={[6]={-.02,.22,-.15,Color3.fromRGB(232,220,255)},[7]={0,.15,.12,Color3.fromRGB(230,236,255)},[8]={.03,.1,.08,Color3.fromRGB(255,246,228)}}
local dimTint={[6]=Color3.fromRGB(220,205,255),[7]=Color3.fromRGB(196,210,255),[8]=Color3.fromRGB(255,236,200)}
local function sceneGrade(run,t,tl,tier)
 local G=tier.Grade;local look=sceneLook[run.Rank]
 if t<tl.Cut or(t<tl.SceneIn-.05)then
  local k=Rules.Smooth(t/math.max(.01,tl.Cut))
  grade(run,-.18*k,.15*k,-.75*G*k,WHITE:Lerp(dimTint[run.Rank],.6*k),run.Reduced and 0 or 8*k)
 elseif t<tl.Back then
  local spike=t>=tl.Climax and .3*(1-clamp01((t-tl.Climax)/.3))or 0
  local blur=(t<tl.SceneIn+.3 and not run.Reduced)and 10*(1-Rules.Smooth((t-tl.SceneIn)/.3))or 0
  grade(run,look[1]+spike,look[2],look[3],look[4],blur)
 else
  local k=1-Rules.Smooth((t-tl.Back)/math.max(.1,tl.Length-tl.Back))
  grade(run,-.1*k,.08*k,-.45*G*k,WHITE:Lerp(dimTint[run.Rank],.4*k),nil)
 end
end
local function danger(run,pg)
 run.NextCheck=run.NextCheck or 0
 if os.clock()<run.NextCheck then return nil end
 run.NextCheck=os.clock()+.2
 local s=M.Snapshot()
 if not s.Alive or lp().Character~=run.Character then return'death'end
 if s.Ragdoll or s.Running or s.KeeperChasing or s.KeeperDistance<M.DangerRadius then return'danger'end
 if run.StartPos and s.Root and(s.Root.Position-run.StartPos).Magnitude>M.MoveLimit then return'moved'end
 rehide(run,pg)
 return nil
end
function M._stepScene(run,pg,t,tl,tier,cam)
 -- (R154: the screen's beats wait with the result: beats.Back is far away until the collect, then the way out starts from it)
 local beats=run.Beats or tl
 -- danger: stop and cut back to the world (the result card follows; R154: a result already shown flies in)
 if run.InStage or t<beats.Back then
  local ok,why=pcall(danger,run,pg)
  if ok and why then finish(run,why);return end
 end
 local inStage=t>=tl.SceneIn-.05 and t<beats.Back
 if inStage and not run.InStage then
  if not run.Scene then finish(run,'error');return end
  run.InStage=true;cam.CameraType=Enum.CameraType.Scriptable
  if M.Camera then local ok,rig=pcall(M.Camera.New,run.Rank,run.Variant,tl);run.Cam=ok and rig or nil end -- (R155)
 elseif not inStage and run.InStage then
  leaveStage(run)
  if run.Fly then pcall(run.Fly.Go)end -- (R154: the world and the hotbar are back: the seed flies home)
 elseif run.InStage and(cam~=run.CameraState.Camera or cam.CameraType~=Enum.CameraType.Scriptable)then
  finish(run,'camera');return
 end
 if run.InStage then
  -- (the stage is the picture itself: if it fails the scene cuts back to the world and the result card shows what was pulled)
  -- (R152: a single bad frame is skipped; three in a row and it cuts back to the world)
  local okS,errS=pcall(run.Scene.Update,run.Scene,t,tl)
  if okS then run.StageErrors=nil
  else
   run.StageErrors=(run.StageErrors or 0)+1;if run.StageErrors==1 then warn('[RarePull] stage: '..tostring(errS))end
   if run.StageErrors>=3 then finish(run,'error');return end
  end
  local eye,target,fov,roll=sceneCamera(run,t,tl,cam)
  local origin=run.Scene.Origin
  local cf=origin*CFrame.lookAt(eye,target)
  if roll~=0 then cf=cf*CFrame.Angles(0,0,-math.rad(roll))end -- (R155: the dutch tilt, about the view: positive turns the camera's up toward its right, as in the approved preview rig)
  cam.CFrame=cf*shake(run,t);cam.Focus=origin*CFrame.new(target);if cam.FieldOfView~=fov then cam.FieldOfView=fov end
 elseif t<tl.SceneIn and not run.Reduced then
  -- the world: a slow push in (FieldOfView only; the player's own camera keeps control)
  part(run,'camera',push,run,cam,tier.Push*Rules.Smooth(t/math.max(.01,tl.Cut)))
 end
 part(run,'card',run.Card.UpdateScene,run.Card,t,beats,true)
 -- colour: the world dims and drains, the stage has its own look, the hit flashes, then the world eases back
 part(run,'grade',sceneGrade,run,t,beats,tier)
end
-- Skip (R153: every presentation, the player's choice; R151 / R152: the story scenes only): from SkipFrom until the seed is down / the card
-- goes. Before the hit it jumps to the hit (the hit and the result still play: straight to the result); once the result is shown (title,
-- seed, "1 in N": ShownAt) it goes to the way out (the card closes); in between nothing (the result is on its way: a late click must not
-- close it unseen). A card runs on the reveal's server clock: its jump to the hit is handed to the opener's pack in the world
-- (RarePullRules.SetShift), so the seed bursts out of it with the card. The seed itself is the server's (granted when the pack opened): a
-- skip changes nothing there, and the puller's chat line, which waits for RarePullSeedShownAt, now waits for the skipped result.
-- R154: once the result is shown the press COLLECTS it (the seed flies home: collect) instead of closing it; one in its first CollectAfter
-- seconds only lands (the clicks of a skip go on for a moment).
-- R155: this is the SKIP button's press (and B / R2 / Enter, its keys): a click / tap anywhere is M.Tap and never skips.
function M.Skip()
 local run=current;if not run or run.Done or not run.Offset or run.Collected then return false end
 local t=run.Clock();local tl=run.TL;local hit=tl.Climax or tl.Burst;local shownAt=Rules.ShownAt(tl)
 if t>=shownAt then
  if t<shownAt+M.CollectAfter then return false end
  collect(run,'press');return true
 end
 if t<(tl.SkipFrom or math.huge)or t>=hit-.02 then return false end
 local target=hit-.02
 run.Offset+=target-t;run.Skipped=(run.Skipped or 0)+1
 if run.Kind~='Scene'then Rules.SetShift(run.Info.Bag,run.Offset)end
 pcall(Audio.Seek,target)
 local player=lp()
 if player then
  local now=workspace:GetServerTimeNow()
  player:SetAttribute('RarePullClimaxAt',now+math.max(0,hit-target));player:SetAttribute('RarePullSeedShownAt',now+math.max(0,Rules.ShownAt(tl)-target))
 end
 return true
end
-- R153: a card (Ladder, InPlace, Result) listens to a click / tap on the world, Enter and the gamepad's B / R2. The HUD and the controls
-- stay the player's, so nothing is taken from them: a press the game already used (a button, the chat box) is ignored, a touch counts as a
-- tap on its release (a drag turns the camera; the engine's TouchTapInWorld counts too). The story scene has its own: the full-screen button
-- and the bound keys. Every route of a press (these, and the tools' own: see armed) goes through RarePullRules.ClaimPress: one answer per
-- press. R155: a click / tap only ever collects (M.Tap: a press that began after the result was shown); B / R2 / Enter are the SKIP button's
-- keys (M.Skip). (SkipGap, R153's "a run of clicks never skips", is kept for whoever reads it: clicks never skip now.)
M.SkipGap=.25;M.TapSeconds=.35;M.TapMove=14
local listening=nil
-- (the reveal's side of RarePullRules.ClaimPress, asked once per press by whichever route comes first)
-- (R155: a tool's own route that asks first - R2 through a tool's action - is the SKIP button's key when B / R2 is held down right now)
local function padSkipDown()
 local ok,down=pcall(function()
  return UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonR2)or UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonB)
 end)
 return ok and down==true
end
Rules.PressTaker=function()
 lastPress=os.clock()
 local mine=pressBegan~=nil -- (the reveal's own listener asks: it says when the press began and whether it is a key)
 local began,key=pressBegan or os.clock(),pressKey -- (a route that asks first, as a press begins: it began now)
 if not mine then key=padSkipDown()end
 local run=current;if not run or run.Done then return false end
 if run.Kind=='Scene'then return true end -- (its buttons and keys act on it)
 if run.Collected then return false end
 -- R155: every press is the reveal's while it runs (from its first frame), but a click / tap never skips: B / R2 / Enter press the SKIP
 -- button (M.Skip), a click / tap only collects the waiting result, and only when it began after the result had been shown (M.Tap)
 if key then if not mine then M.Skip()end -- (the listener's key has pressed it already: M.Press)
 else M.Tap(began)end
 return true
end
-- R154: collect the waiting result now (the seed flies home), as a press would. False when there is none (not shown yet, or collected).
function M.Collect(why)
 local run=current
 if not run or run.Done or run.Collected or not(run.SawResult or run.Clock()>=Rules.ShownAt(run.TL))then return false end
 collect(run,why or'press');return true
end
-- R155: a click / tap anywhere (or Space / A in a story scene): it never skips; it collects the waiting result when it BEGAN (began: os.clock()
-- of the press's start) at least CollectAfter s after the result was shown. A press held down from before, or a burst of clicks from the
-- animation, does nothing. False when it did nothing.
function M.Tap(began)
 local run=current
 if not run or run.Done or run.Collected or not(run.SawResult or run.Clock()>=Rules.ShownAt(run.TL))then return false end
 local at=run.Clock()-(os.clock()-(began or os.clock())) -- (the run's clock when the press began)
 if at<Rules.ShownAt(run.TL)+M.CollectAfter then return false end
 collect(run,'press');return true
end
-- R154: the presentation's result is on screen and waits for its collect
function M.Waiting()local run=current;return run~=nil and not run.Done and not run.Collected and run.SawResult==true end
-- began: when the press started (os.clock; a tap counts on its release); key: a key that presses the SKIP button (B / R2 / Enter). One
-- physical press may come in by several routes (a mouse button, a tool's own, R2's action): RarePullRules.ClaimPress gives them one answer.
function M.Press(processed,began,key)
 if processed then return false end
 if key then -- (R155: B / R2 / Enter press the SKIP button themselves: a key is its own press, whatever clicks came just before it)
  local run=current;if run and not run.Done and run.Kind~='Scene'and not run.Collected then M.Skip()end
 end
 pressBegan,pressKey=began or os.clock(),key==true
 local taken=Rules.ClaimPress()
 pressBegan,pressKey=nil,false
 return taken
end
local pressKeys={[Enum.KeyCode.Return]=true,[Enum.KeyCode.ButtonB]=true,[Enum.KeyCode.ButtonR2]=true}
M.SkipKeys=pressKeys -- (R155: the keys of the SKIP button)
function M.Listen()
 if listening then return end
 listening={}
 local touches=setmetatable({},{__mode='k'});local lastTouch=nil
 local function on(signal,fn)local ok,c=pcall(function()return signal():Connect(fn)end);if ok and c then listening[#listening+1]=c end end
 on(function()return UIS.InputBegan end,function(input,processed)
  if input.UserInputType==Enum.UserInputType.Touch then if not processed then touches[input]={At=os.clock(),Pos=input.Position};lastTouch=os.clock()end;return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 then M.Press(processed,os.clock(),false)
  elseif pressKeys[input.KeyCode]then M.Press(processed,os.clock(),true)end
 end)
 on(function()return UIS.InputEnded end,function(input)
  local t=touches[input];if not t then return end;touches[input]=nil
  if os.clock()-t.At<=M.TapSeconds and(input.Position-t.Pos).Magnitude<=M.TapMove then M.Press(false,t.At,false)end
 end)
 on(function()return UIS.TouchTapInWorld end,function(_,processed)M.Press(processed,lastTouch,false)end)
end
local function unlisten()for _,c in ipairs(listening or{})do c:Disconnect()end;listening=nil end
-- Everything at once (death of the script, a test): the presentation, a card still fading out, every sound and the music duck.
function M.Abort(reason)
 reason=reason or'aborted';if not M.NoCollect[reason]then reason='aborted'end -- (an abort never flies: R154)
 if current then finish(current,reason)end
 if M._building then local b=M._building;M._building=nil;finish(b,reason)end
 clearFades();pcall(Audio.Stop)
 if Collect then pcall(Collect.Clear)end -- (R154: no seed left flying, every hold ended: the items show)
end
function M.Active()return current end
function M.OwnsCamera()return current~=nil and current.Kind=='Scene'and not current.Done end
-- Owner previews (/test rarepull <tier>, /test raresound <Slot>): a demo seed of that tier, nothing granted.
local tierKeys={common=1,uncommon=2,rare=3,legendary=4,mythic=5,secret=6,cosmic=7,king=8}
function M.DemoSeed(rank)
 local ok,Packs=pcall(require,RS:FindFirstChild('SeedPackRules'));if not ok then return nil end
 local want=Rules.Tier(rank).Key
 local r=remotes();local art=r and r:FindFirstChild('SeedArt');local seeds=art and art:FindFirstChild('Seeds')
 for _,spec in ipairs(Packs.SeedDesigns or{})do
  local name=Packs.GetRarity(spec.id)
  if name==want and(not seeds or seeds:FindFirstChild(spec.id))then return spec.id end
 end
 return nil
end
function M.Preview(kind,arg)
 kind=tostring(kind or''):lower()
 if kind=='raresound'then return Audio.PlaySlot(tostring(arg or''))end
 if kind=='rarepull'then
  local rank=tierKeys[tostring(arg or''):lower()];if not rank then return false end
  local seed=M.DemoSeed(rank);if not seed then return false end
  return M.Start({Rank=rank,SeedId=seed,At=workspace:GetServerTimeNow(),Preview=true})~=nil
 end
 return false
end
-- PackOpeningFeedback hands its script over: the owner preview attribute, and stop everything if the script goes.
function M.Bind(scriptInstance)
 local player=lp();if not player then return end
 M.Listen() -- R153: the cards' skip (a press is followed from now on, so the clicks that open a pack are known as such)
 pcall(Audio.Preload) -- R152: every reveal sound loads now, long before the first pack is opened (it used to load as the reveal began)
 pcall(function()require(script.Parent.RarePullArt).Warm()end) -- R152: and the images of the story scenes are drawn a while later
 local conns={}
 conns[#conns+1]=player:GetAttributeChangedSignal('RarePullPreview'):Connect(function()
  local v=player:GetAttribute('RarePullPreview');if type(v)~='string'then return end
  local kind,arg=v:match('^(%a+):([%w_]+)')
  if kind then pcall(M.Preview,kind,arg)end
 end)
 if scriptInstance then
  conns[#conns+1]=scriptInstance.Destroying:Connect(function()M.Abort('destroyed');unlisten();for _,c in ipairs(conns)do c:Disconnect()end end)
 end
 return conns
end
return M
