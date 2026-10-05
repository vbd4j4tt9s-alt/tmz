-- R151: the director of every pull reveal on the OPENER's screen (PackOpeningFeedback starts it when the server publishes RevealAt).
--  Common..Mythic  'Ladder': the seed card (RarePullCard), the suspense sounds (RarePullAudio), a light colour grade, and for Legendary /
--                  Mythic a short camera push (FieldOfView only). The pack's own suspense in the world is SeedPackClient (everyone sees it).
--  Secret+ 'Scene' (Full, or Calm with ReducedMotion): the world dims and desaturates, letterbox, fade to black, the hidden story stage
--                  (RarePullScenes) with the camera, silence, the hit, the seed hero shot, fade back; the HUD is hidden and movement held
--                  meanwhile. Skippable after SkipFrom (tap / click anywhere, Space, Enter, A / B): before the hit it jumps to the hit, after
--                  it to the way out.
--  Secret+ 'InPlace' when the full scene is not safe (RarePullRules.Decide: a keeper near or chasing, on the track, ragdoll, a run, a menu,
--                  someone else's camera, in the air): no camera, no hidden stage, HUD and controls untouched, a compact card in the upper
--                  third timed to the world seed's burst.
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
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService');local UIS=game:GetService('UserInputService');local CAS=game:GetService('ContextActionService')
local Collection=game:GetService('CollectionService');local StarterGui=game:GetService('StarterGui')
local Rules=require(script.Parent.RarePullRules);local Audio=require(script.Parent.RarePullAudio)
local M={}
M.BindName='ChestChaseRarePull';M.SkipAction='ChestChaseRarePullSkip'
M.KeepGuis={TouchGui=true,Freecam=true}
M.CoreTypes={'PlayerList','Chat','EmotesMenu','Health','Backpack'}
M.DangerRadius=45;M.MoveLimit=8
local current=nil;M.LastEnd=-math.huge
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
-- The seed's display name, its "1 in N" (the held pack's tooltip, else the Index chance) and a model of it.
function M.SeedInfo(seedId,tool)
 local r=remotes();local catalog=r and r:FindFirstChild('SeedCatalog');local entry=catalog and catalog:FindFirstChild(seedId)
 local name=entry and entry:GetAttribute('DisplayName')
 if not name then
  local ok,Packs=pcall(require,RS:FindFirstChild('SeedPackRules'))
  if ok and Packs and Packs.SeedDesignById and Packs.SeedDesignById[seedId]then name=Packs.SeedDesignById[seedId].name end
 end
 name=name or tostring(seedId)
 local odds=tool and Rules.TooltipOdds(tool.ToolTip,name)
 if not odds and entry then
  local chance=entry:GetAttribute('BaseChance')
  if type(chance)=='number'and chance>0 then local ok,O=pcall(require,RS:FindFirstChild('OddsText85'));if ok then odds=(O.Format(chance)):match('^1/(.+)$')end end
 end
 return name,odds
end
function M.SeedModel(seedId,mutation)
 local r=remotes();local art=r and r:FindFirstChild('SeedArt');local seeds=art and art:FindFirstChild('Seeds');local template=seeds and seeds:FindFirstChild(seedId)
 if not template then return nil end
 local seed=template:Clone();seed.Name='RarePullSeed';seed:SetAttribute('SeedMotionManaged',true)
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
local function grade(run,b,c,s,tint,blur)
 local cam=workspace.CurrentCamera;if not cam then return end
 if not run.Grade or run.Grade.Parent~=cam then
  if run.Grade then run.Grade:Destroy()end
  local g=Instance.new('ColorCorrectionEffect');g.Name='RarePullGrade';g.Parent=cam;run.Grade=g
 end
 local g=run.Grade;g.Brightness=b;g.Contrast=c;g.Saturation=s;g.TintColor=tint
 if blur and blur>.05 and not run.Lite then
  if not run.Blur or run.Blur.Parent~=cam then local bl=Instance.new('BlurEffect');bl.Name='RarePullBlur';bl.Parent=cam;run.Blur=bl end
  run.Blur.Size=blur
 elseif run.Blur then run.Blur:Destroy();run.Blur=nil end
end
local WHITE=Color3.new(1,1,1)
-- Finishing -----------------------------------------------------------------------------------------------------------------------------
local finish
local function unbind(run)
 if run.Bound then run.Bound=false;pcall(function()Run:UnbindFromRenderStep(run.BindName or M.BindName)end)end
 if run.SkipBound then run.SkipBound=false;pcall(function()CAS:UnbindAction(M.SkipAction)end)end
 for _,c in ipairs(run.Connections)do c:Disconnect()end;table.clear(run.Connections)
end
local function leaveStage(run)
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
 run.Done=true;run.Reason=reason
 pcall(unbind,run)
 pcall(leaveStage,run)
 pcall(restoreCamera,run)
 if reason=='replaced'and run.Kind~='Scene'and run.Gui then
  pcall(fadeOut,run.Gui,run.Grade);run.Gui=nil;run.Grade=nil;run.Card=nil;run.SeedModel=nil
 end
 if run.Grade then run.Grade:Destroy();run.Grade=nil end
 if run.Blur then run.Blur:Destroy();run.Blur=nil end
 if run.Card then pcall(function()run.Card:Destroy()end);run.Card=nil end
 if run.Gui then run.Gui:Destroy();run.Gui=nil end
 if run.SeedModel and run.SeedModel.Parent then run.SeedModel:Destroy()end
 if run.Audio then run.Audio=false;pcall(Audio.Stop)end
 local player=lp()
 if player and(current==run or current==nil)then
  player:SetAttribute('RarePullCinematic',nil);player:SetAttribute('RarePullClimaxAt',nil);player:SetAttribute('RarePullSeedShownAt',nil)
 end
 if current==run then current=nil end
 if M._building==run then M._building=nil end
 M.LastEnd=os.clock();Rules.LastRevealEnd=M.LastEnd;Rules.RevealRunning=current~=nil
 -- a story scene that had to stop before its hit still shows the result (a compact card), unless the player died / left
 if(reason=='danger'or reason=='moved'or reason=='camera'or reason=='error')and run.Kind=='Scene'and not run.SawClimax and run.Info then
  local info=table.clone(run.Info);info.Result=true
  task.defer(function()if not current then M.Start(info)end end)
 end
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
 local pg=player:FindFirstChildOfClass('PlayerGui');if not pg then return nil end
 local rank=math.clamp(math.floor(tonumber(info.Rank)or 1),1,8)
 -- (R152: the same reveal asked for again - the pack re-equipped mid-reveal - keeps playing; it used to restart as a "quick" reveal)
 if current and not current.Done and info.Bag~=nil and current.Info.Bag==info.Bag and current.At==tonumber(info.At)then return current end
 local hand
 if current then hand=handoff(current);finish(current,'replaced')end
 local run={Info=info,Rank=rank,Connections={},Reduced=reduced(),Phone=phone(),Lite=lite(),At=tonumber(info.At)or workspace:GetServerTimeNow()}
 M._building=run
 -- what kind of presentation
 if rank<=5 then
  run.Kind='Ladder'
  Rules.LastRevealEnd=math.max(Rules.LastRevealEnd,M.LastEnd)
  run.Quick=not info.Preview and Rules.QuickFor(info.Bag) -- (the same answer the world pack gets: RarePullRules.QuickFor)
  Rules.MarkQuick(info.Bag,run.Quick)
  run.TL=Rules.CardTimeline(rank,run.Quick);run.Clock=function()return workspace:GetServerTimeNow()-run.At end
  run.Cues=Rules.LadderCues(rank,run.Quick)
 elseif info.Result then
  run.Kind='Result';run.TL=Rules.Timeline(rank,'Result');local t0=os.clock();run.Clock=function()return os.clock()-t0 end
  run.Cues=Rules.SceneCues(rank,run.TL)
 else
  local okS,snap=pcall(M.Snapshot)
  local variant,why=Rules.Decide(okS and snap or nil)
  run.Why=why
  if variant=='Full'then
   run.Kind='Scene';run.Variant=run.Reduced and'Calm'or'Full';run.TL=Rules.Timeline(rank,run.Variant)
   local t0=os.clock()-math.clamp(workspace:GetServerTimeNow()-run.At,0,.15);run.Offset=0
   run.Clock=function()return os.clock()-t0+run.Offset end
  else
   run.Kind='InPlace';run.TL=Rules.Timeline(rank,'InPlace');run.Clock=function()return workspace:GetServerTimeNow()-run.At end
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
 run.Card=Card.Create(gui,cardKind,{Rank=rank,Phone=run.Phone,Reduced=run.Reduced,Lite=run.Lite,Quick=run.Quick,SeedName=name,Odds=odds,Seed=seedForCard})
 -- audio (every slot was preloaded when the client started: Bind)
 local slots={};local seen={};for _,c in ipairs(run.Cues)do if not seen[c.Slot]then seen[c.Slot]=true;slots[#slots+1]=c.Slot end end
 pcall(Audio.Preload,slots)
 local okA=pcall(Audio.Begin,run.Cues,run.Clock(),run.TL.Length);run.Audio=okA
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
  table.insert(run.Connections,button.Activated:Connect(function()M.Skip()end))
  local ok2=pcall(function()
   CAS:BindActionAtPriority(M.SkipAction,function(_,state)
    if state==Enum.UserInputState.Begin then M.Skip()end
    return Enum.ContextActionResult.Sink
   end,false,Enum.ContextActionPriority.High.Value,Enum.KeyCode.Space,Enum.KeyCode.Return,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB)
  end)
  run.SkipBound=ok2
  local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
  if hum then table.insert(run.Connections,hum.Died:Connect(function()finish(run,'death')end))end
  table.insert(run.Connections,workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()if run.InStage then finish(run,'camera')end end))
 else
  saveCamera(run)
  if hand and run.CameraState then run.CameraState.Fov=hand.Fov;run.FovWritten=hand.Written;run.Carry={From=hand.Fov-hand.Written,T0=os.clock()}end
 end
 table.insert(run.Connections,player.CharacterRemoving:Connect(function()finish(run,'death')end))
 current=run;M._building=nil;Rules.RevealRunning=true
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
-- R152: one failing piece (the card, the grade, the stage, a sound) is switched off for the rest of the presentation and logged once;
-- the reveal plays on and ends on its own clock. Only the camera / timeline failing ends it (cleanly, restoring everything).
local function part(run,name,fn,...)
 if run.Broken and run.Broken[name]then return end
 local ok,err=pcall(fn,...)
 if not ok then run.Broken=run.Broken or{};run.Broken[name]=true;warn('[RarePull] '..name..' failed, the reveal goes on without it: '..tostring(err))end
end
M.Part=part
local function shake(run,t)
 if run.Reduced then return CFrame.new()end
 local a=t-run.TL.Climax;if a<0 or a>.5 then return CFrame.new()end
 local k=(1-a/.5)^2*(run.Phone and .35 or 1)*Rules.Smooth(a/.03) -- (R152: the hit's shake swells in over 30 ms: no camera jump on the hit frame)
 return CFrame.new(math.sin(t*90)*.12*k,math.sin(t*73)*.09*k,0)*CFrame.Angles(0,0,math.sin(t*61)*math.rad(1.1)*k)
end
-- FieldOfView push in the world (the player's camera keeps control; only written while nobody else has changed it)
local function push(run,cam,amount)
 amount=math.max(amount,carry(run))
 if not(cam and run.CameraState and cam==run.CameraState.Camera and cam.CameraType==Enum.CameraType.Custom)then return end
 if amount<=0 and not run.FovWritten then return end
 if run.FovWritten==nil or cam.FieldOfView==run.FovWritten then cam.FieldOfView=run.CameraState.Fov-amount;run.FovWritten=cam.FieldOfView end
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
function M._step(run,pg)
 local t=run.Clock();local tl=run.TL;local tier=Rules.Tier(run.Rank)
 if t>=tl.Length then finish(run,'done');return end
 if t>=(tl.Climax or tl.Burst or 0)then run.SawClimax=true end
 local cam=workspace.CurrentCamera
 if run.Kind=='Ladder'then
  part(run,'card',run.Card.UpdateLadder,run.Card,t,tl)
  local q=clamp01(t/tl.Burst)
  local amount=0
  if tier.Push>0 and not run.Reduced then amount=t<tl.Burst and tier.Push*Rules.Smooth(q)or tier.Push*(1-Rules.Smooth((t-tl.Burst)/.3))end
  part(run,'camera',push,run,cam,amount)
  part(run,'grade',ladderGrade,run,t,tl,tier)
 elseif run.Kind=='InPlace'or run.Kind=='Result'then
  part(run,'card',run.Card.UpdateInPlace,run.Card,t,tl)
  part(run,'camera',push,run,cam,0)
  local pre=run.Kind=='InPlace'and clamp01(t/math.max(.01,tl.Climax))or 0
  local post=t>=tl.Climax and 1-clamp01((t-tl.Climax)/math.max(.1,tl.Length-tl.Climax))or 0
  part(run,'grade',grade,run,-.08*pre+(t>=tl.Climax and .2*(1-clamp01((t-tl.Climax)/.3))or 0),.1*(pre+post*.5),-.35*pre-.15*post,WHITE,nil)
 else
  M._stepScene(run,pg,t,tl,tier,cam)
  if run.Done then return end
 end
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
 -- danger: stop and cut back to the world (the result card follows)
 if run.InStage or t<tl.Back then
  local ok,why=pcall(danger,run,pg)
  if ok and why then finish(run,why);return end
 end
 local inStage=t>=tl.SceneIn-.05 and t<tl.Back
 if inStage and not run.InStage then
  if not run.Scene then finish(run,'error');return end
  run.InStage=true;cam.CameraType=Enum.CameraType.Scriptable
 elseif not inStage and run.InStage then
  leaveStage(run)
 elseif run.InStage and(cam~=run.CameraState.Camera or cam.CameraType~=Enum.CameraType.Scriptable)then
  finish(run,'camera');return
 end
 if run.InStage then
  -- (the stage is the picture itself: if it fails the scene cuts back to the world and the result card shows what was pulled)
  local okS,errS=pcall(run.Scene.Update,run.Scene,t,tl)
  if not okS then warn('[RarePull] stage: '..tostring(errS));finish(run,'error');return end
  local eye,target,fov=Rules.Shot(run.Rank,run.Variant,t,tl)
  local origin=run.Scene.Origin
  local cf=origin*CFrame.lookAt(eye,target)*shake(run,t)
  cam.CFrame=cf;cam.Focus=origin*CFrame.new(target);cam.FieldOfView=fov
 elseif t<tl.SceneIn and not run.Reduced then
  -- the world: a slow push in (FieldOfView only; the player's own camera keeps control)
  part(run,'camera',push,run,cam,tier.Push*Rules.Smooth(t/math.max(.01,tl.Cut)))
 end
 part(run,'card',run.Card.UpdateScene,run.Card,t,tl,true)
 -- colour: the world dims and drains, the stage has its own look, the hit flashes, then the world eases back
 part(run,'grade',sceneGrade,run,t,tl,tier)
end
-- Skip: only in a story scene, from SkipFrom until the seed has floated down.
function M.Skip()
 local run=current;if not run or run.Kind~='Scene'or run.Done then return false end
 local t=run.Clock();local tl=run.TL
 if t<tl.SkipFrom or t>=tl.FloatEnd then return false end
 local target=t<tl.Climax-.02 and tl.Climax-.02 or tl.FloatEnd
 run.Offset+=target-t;run.Skipped=(run.Skipped or 0)+1
 pcall(Audio.Seek,target)
 local player=lp()
 if player then
  local now=workspace:GetServerTimeNow()
  player:SetAttribute('RarePullClimaxAt',now+math.max(0,tl.Climax-target));player:SetAttribute('RarePullSeedShownAt',now+math.max(0,Rules.ShownAt(tl)-target))
 end
 return true
end
-- Everything at once (death of the script, a test): the presentation, a card still fading out, every sound and the music duck.
function M.Abort(reason)
 if current then finish(current,reason or'aborted')end
 if M._building then local b=M._building;M._building=nil;finish(b,reason or'aborted')end
 clearFades();pcall(Audio.Stop)
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
 pcall(Audio.Preload) -- R152: every reveal sound loads now, long before the first pack is opened (it used to load as the reveal began)
 local conns={}
 conns[#conns+1]=player:GetAttributeChangedSignal('RarePullPreview'):Connect(function()
  local v=player:GetAttribute('RarePullPreview');if type(v)~='string'then return end
  local kind,arg=v:match('^(%a+):([%w_]+)')
  if kind then pcall(M.Preview,kind,arg)end
 end)
 if scriptInstance then
  conns[#conns+1]=scriptInstance.Destroying:Connect(function()M.Abort('destroyed');for _,c in ipairs(conns)do c:Disconnect()end end)
 end
 return conns
end
return M
