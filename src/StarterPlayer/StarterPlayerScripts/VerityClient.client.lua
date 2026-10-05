-- R147 (owner: "Verity NPC is a quest giver: it tells players to steal a pack from The Darkened one and give it to the
-- Verity NPC. The Verity NPC will be behind the market and it will be big."): the client half of VerityService.
-- R148 (owner's play test, "Verity should be a big yellow sphere", and her greeting voice):
--  * Her Body (a big yellow ball with her smiley as a Decal) turns to face the camera on this client, bobs a little, and swells
--    while she talks (all of it cosmetic and local; none with ReducedMotion).
--  * A marker over her head, in the same sign as her name (marker row, a gap, the name, the event timer: rows that cannot overlap):
--    a "!" until you have opened her dialog once (then it is gone for the rest of this session; a rejoin shows it again), a bouncing
--    gold "?" while you carry a Void Pack (a Backpack / Character Tool with SeedPackTool and BagVariant 'EclipseReliquary').
--    Once the limited event is over (LimitedEvent) neither shows, her timer line says EVENT ENDED and she takes nothing.
--  * Her greeting (VerityConfig.GreetingSoundId) plays from her body, 3D, through the Effects volume setting: when you open her
--    dialog with Talk, and once when you first come within GreetingDistance of her (at most once a minute; a Talk greeting counts).
--    Never two copies at once; an asset that fails to load is warned about once and skipped.
--  * Talk to her (the server answers the prompt with 'Open') and a window shows her quest, her picture, how many Void Packs you
--    have, how many you handed in, when The Darkened is here / comes, the exchange as pictures (Void Pack -> Verity Pack, the
--    game's own 3D pack pictures, like the hotbar) and the GIVE VOID PACK button (only with a Void Pack).
--    'Done' = thanks + a sound, 'Refused' = the reason. PlayerGui.SeedMenu = 'Verity' while it is open.
-- R151 (owner's play test of R150: "the Verity mouth thing can be removed and the ball can just bounce. For the audio it cuts off at 'Ver'"): the dark
-- mouth oval is gone (world and portrait); the voice level drives a BOUNCE and the swell: she hops by TalkBounce of her size on every syllable and swells by
-- TalkPulse, both from VerityVoice.Pose. The greeting's cut ends at VerityConfig.GreetingEnd 2.35 (was 1.9, which stopped inside "Verity").
-- R149 (owner: "sync verity's voice and cut the audio to only hello my name verity and also change the picture of verity to its 3d model
-- talking and remove the event ends thing"):
--  * Her greeting plays ONLY "Hello, my name is Verity": the Sound's PlaybackRegion is VerityConfig.GreetingStart .. GreetingEnd (or the
--    owner's live /test verityvoice values, read from her model's VerityVoiceStart / VerityVoiceEnd attributes each time she speaks), with a
--    short fade at the end. All three ways she speaks (Talk, coming close, the owner's test) go through the same startVoice.
--  * Voice level: while the voice plays, the Sound's PlaybackLoudness (smoothed, normalised: VerityVoice.Step) swells her and bounces her (R151: no
--    mouth any more); a plain talking rhythm runs if the engine reports no loudness. Only while she talks: nothing per frame at rest, none beyond
--    AnimateDistance (the window's portrait still follows while it is open), none with ReducedMotion.
--  * The window's portrait is her 3D model (the same yellow ball and smiley, in a ViewportFrame) bobbing, swelling and bouncing with the same level;
--    it exists only while the window is open. The window no longer shows the "EVENT ENDS IN ..." line (her sign and the Index keep theirs),
--    and her quest sentence gets the room it needs (every label is fitted by GardenTextFit, which layout() no longer overrides).
-- The server owns every rule; this only sends 'Give' (no arguments) and shows what it is told.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local Tween=game:GetService('TweenService');local GuiService=game:GetService('GuiService')
local SoundService=game:GetService('SoundService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local remotes=RS:WaitForChild('ChestChaseRemotes')
local C=require(RS:WaitForChild('VerityConfig'));local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI);local Audio=require(RS.InteractionAudio)
local Pictures;pcall(function()Pictures=require(RS.ItemPictures)end)
local Mixer;pcall(function()Mixer=require(RS.AudioMixer)end)
local Limited=require(RS:WaitForChild('LimitedEvent'));local VerityVoice=require(RS:WaitForChild('VerityVoice'));local Fit=require(RS:WaitForChild('GardenTextFit'))
local RGB=Color3.fromRGB
local GOLD,MINT,SKY,RED,VIOLET=RGB(255,206,64),RGB(110,226,96),RGB(86,182,255),RGB(255,96,96),RGB(190,140,255)
local connections={};local function watch(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
local function new(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function text(parent,name,value,size,color)
 local t=new('TextLabel',{Name=name,Text=value,BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center},parent)
 Bright.Text(t,size or 16,color);return t
end
local function stroke(parent,color,thickness)return new('UIStroke',{Color=color,Thickness=thickness or 2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent)end
local function countdown(seconds)
 seconds=math.max(0,math.floor(seconds));local h=math.floor(seconds/3600);local m=math.floor(seconds%3600/60)
 if h>0 then return h..'h '..m..'m'end;if m>0 then return m..'m '..seconds%60 ..'s'end;return seconds..'s'
end
-- Void Packs in your hands or Bag (Tools): the marker's "?" and nothing else (the window uses the server's count).
local function isVoidTool(tool)
 return tool:IsA('Tool')and tool:GetAttribute('SeedPackTool')==true and tool:GetAttribute('BagVariant')==C.VoidVariant
end
local function countVoidTools()
 local n=0
 for _,container in ipairs({player:FindFirstChildOfClass('Backpack'),player.Character})do
  if container then for _,child in ipairs(container:GetChildren())do if isVoidTool(child)then n+=1 end end end
 end
 return n
end
local function wrap(angle)return(angle+math.pi)%(math.pi*2)-math.pi end
-- The limited event, on the SERVER's clock ("EVENT ENDS IN 27d 04h 12m 09s"); after EndsAt it is over.
local function eventLive()return Limited.Active(workspace:GetServerTimeNow())end
local function eventTimerText()
 if eventLive()then return C.Event.Prefix..Limited.Text(Limited.Left(workspace:GetServerTimeNow())),true end
 return C.Event.Ended,false
end
local talked=false -- opened her dialog this session: the "!" is gone until the next session
-- Her voice -------------------------------------------------------------------------------------------------------------------
-- One Sound on her body (3D, rolled off by distance, routed to the Effects group so the player's Effects volume applies).
-- R149: it plays ONLY "Hello, my name is Verity": the part of the clip from Start to Stop seconds (VerityConfig.GreetingStart / GreetingEnd,
-- or the owner's live values on her model), as the Sound's PlaybackRegion. Every greeting starts in startVoice, so every one is cut the same
-- way. Her volume is faded over the last GreetingFade seconds (voiceTick, from the Sound's own TimePosition) so the cut does not click, and
-- voice.Until ends it by timer even if the engine did not honour the region. A greeting asked for before the clip has loaded waits for it
-- (up to GreetingMaxWait, .5 s since R150, like every other cue) rather than being timed by a clock that started before the audio did.
local GREETING_MAX_WAIT=.5 -- R150: a greeting that is not ready this long after it was asked for is skipped, never spoken late
local voice={Playing=false,Until=0,LastAt=-math.huge,Failed=false,Warned=false,Sound=nil,Checked=false,Plays=0,Start=0,Stop=0,StartedAt=0,Gain=1,
 Lip=VerityVoice.NewLip(C.Lip),Waiting=nil,RegionWarned=false,PanelOpen=function()return false end}
local entry=nil
local function failVoice(why)
 voice.Failed=true
 if not voice.Warned then voice.Warned=true;warn('[R148] Verity\'s greeting could not be loaded ('..tostring(C.GreetingSoundId)..'): '..tostring(why))end
end
-- flat: the owner's test plays it as a plain 2D sound (SoundService), so it is heard from anywhere in the server, not only near her.
local function voiceSound(e,flat)
 local parent=flat and SoundService or e.Body
 local s=voice.Sound
 if s and s.Parent==parent then return s end
 if s then s:Destroy();voice.Sound=nil;voice.Checked=false;voice.Playing=false end
 s=new('Sound',{Name='VerityGreeting',SoundId=C.GreetingSoundId,Volume=C.GreetingVolume,Looped=false,RollOffMode=Enum.RollOffMode.InverseTapered,
  RollOffMinDistance=C.GreetingRollOffMin,RollOffMaxDistance=C.GreetingRollOffMax},parent)
 if Mixer then pcall(Mixer.Route,s,'Effects')end
 watch(s.Ended,function()if voice.Sound==s then voice.Playing=false;voice.Gain=1;pcall(function()s.Volume=C.GreetingVolume end)end end) -- (the engine ended it: undo the fade)
 voice.Sound=s
 -- Ask for the asset now so a bad id is found (and warned about once) before anyone waits for her to speak.
 if not voice.Checked then
  voice.Checked=true
  task.spawn(function()
   local okService,content=pcall(game.GetService,game,'ContentProvider')
   if not okService or not content or type(content.PreloadAsync)~='function'then return end
   pcall(content.PreloadAsync,content,{s},function(id,status)
    if status~=nil and status~=Enum.AssetFetchStatus.Success then failVoice('asset fetch '..tostring(status.Name or status))end
   end)
  end)
 end
 return s
end
-- True while a greeting is playing (the Sound's Ended clears it; one that never ends is given up on half a second after its cut should have).
local function speaking()return voice.Playing and os.clock()<voice.Until end
-- Stop it now (restoring the volume the fade lowered).
local function finishVoice()
 local s=voice.Sound
 if s and s.Parent then pcall(function()if s.IsPlaying then s:Stop()end;s.Volume=C.GreetingVolume end)end
 voice.Playing=false;voice.Gain=1
end
-- Every frame while a greeting plays (audio, so never skipped for ReducedMotion or her distance): the fade-out, and the end.
local function voiceTick()
 local s=voice.Sound
 if not s or not s.Parent then voice.Playing=false;return end
 local now=os.clock();local age=now-voice.StartedAt;local position=s.TimePosition
 if now>=voice.Until or(age>.15 and position>=voice.Stop-.004)or(age>.3 and not s.IsPlaying)then finishVoice();return end
 local gain=VerityVoice.Fade(position,voice.Stop,C.GreetingFade)
 if gain~=voice.Gain then voice.Gain=gain;s.Volume=C.GreetingVolume*gain end
end
-- The cut in force: the owner's live values on her model if both are there, else VerityConfig (made safe, and kept inside the clip once its length is known).
local function regionNow(e,s,override)
 local a,b
 if override then a,b=override.Start,override.End end
 if not(VerityVoice.Finite(a)and VerityVoice.Finite(b))then a,b=e.Model:GetAttribute('VerityVoiceStart'),e.Model:GetAttribute('VerityVoiceEnd')end
 return VerityVoice.Region(C,a,b,s.TimeLength)
end
local function startVoice(e,s,kind,override)
 local start,stop=regionNow(e,s,override)
 local okRegion=pcall(function()s.PlaybackRegionsEnabled=true;s.PlaybackRegion=NumberRange.new(start,stop)end)
 if not okRegion and not voice.RegionWarned then voice.RegionWarned=true;warn('[R149] Verity\'s greeting could not be cut with PlaybackRegion; a timer cuts it instead')end
 local ok=pcall(function()s.Volume=C.GreetingVolume;s.TimePosition=start;s:Play()end)
 if not ok then failVoice('Play failed');return false end
 local now=os.clock()
 voice.Playing=true;voice.Start=start;voice.Stop=stop;voice.StartedAt=now;voice.Until=now+(stop-start)+.5;voice.LastAt=now;voice.Plays+=1;voice.Kind=kind;voice.Gain=1
 VerityVoice.Begin(voice.Lip,C.Lip)
 return true
end
-- kind: 'talk' (her dialog opened), 'near' (you came close) or 'test' (the owner's /test verityvoice: override = {Start, End}, replays at once, flat).
-- Returns true when she started speaking (false when it was skipped, or is waiting for the clip to load).
local function greet(kind,override)
 local e=entry;if not e or not e.Body.Parent or voice.Failed then return false end
 if Mixer and Mixer.Get('Effects')==0 then return false end -- the player turned effects off: no voice, no swelling
 if speaking()then
  if not override then return false end -- never two copies at once (only the owner's test restarts it)
  finishVoice()
 end
 local s=voiceSound(e,override~=nil);if not s or voice.Failed then return false end
 if s.IsLoaded==false and not((s.TimeLength or 0)>0)then -- (an unloaded Sound has no length yet)
  if voice.Waiting then return false end
  local ticket={};voice.Waiting=ticket;local askedAt=os.clock()
  local c;c=s.Loaded:Connect(function()
   c:Disconnect()
   if voice.Waiting~=ticket then return end
   voice.Waiting=nil
   -- R150: too late is no greeting. (Her bounce follows the sound, so it was never out of step, but "Hello, my name is Verity" seconds after
   -- the window opened, or after you walked past, is a bug.) A 'talk' greeting also needs her window to still be open.
   if os.clock()-askedAt>GREETING_MAX_WAIT then return end
   if kind=='talk'and not voice.PanelOpen()then return end
   if entry==e and e.Body.Parent and s.Parent and not speaking()and not voice.Failed then startVoice(e,s,kind,override)end
  end)
  connections[#connections+1]=c
  task.delay(GREETING_MAX_WAIT,function()if voice.Waiting==ticket then voice.Waiting=nil;c:Disconnect()end end)
  return false
 end
 return startVoice(e,s,kind,override)
end
-- Her body and the marker ---------------------------------------------------------------------------------------------------------
local S=C.Sign
local MARK_BASE=(S.Mark.Top+S.Mark.Height)/S.H     -- the glyph rests on the bottom of its row
local MARK_BOUNCE=S.Mark.Bounce/S.H
local function markAt(lift)return UDim2.fromScale(.5,MARK_BASE-lift)end
local function settle(e) -- back to how the server placed her (one write, only if she had been moved)
 if not e.Moved then return end
 e.Moved=false;e.Yaw=e.Yaw0;e.Scale=1;e.LastY=nil;e.LastYaw=nil;e.LastScale=nil
 e.Body.Size=Vector3.new(e.Size,e.Size,e.Size);e.Body.CFrame=e.Home
 if e.Mark.Parent then e.Mark.Position=markAt(0)end
end
local function refreshTimer()
 local e=entry;if not e or not e.Timer.Parent then return end
 local text,live=eventTimerText();e.Timer.Text=text;e.Timer.TextColor3=live and C.EventColor or RED
end
local function refreshMarker()
 local e=entry;if not e or not e.Mark.Parent then return end
 local has=countVoidTools()>0;local live=eventLive()
 -- "?" while you hold a Void Pack; "!" until you have talked to her; nothing once the event is over.
 local shown=live and(has or not talked)
 e.Mark.Visible=shown;e.Mark.Text=has and'?'or'!';e.Mark.TextColor3=has and GOLD or Color3.new(1,1,1)
 e.Has=shown and has
 e.Sign:SetAttribute('Bounce',e.Has);e.Sign:SetAttribute('HasVoidPack',has);e.Sign:SetAttribute('MarkerShown',shown)
 if not e.Has then e.Mark.Position=markAt(0)end
 refreshTimer()
end
local function build(model,body)
 local sign=body:FindFirstChild('NameSign')
 if not sign then
  local waiting;waiting=body.ChildAdded:Connect(function(child)if child.Name=='NameSign'then waiting:Disconnect();if model.Parent and not entry then build(model,body)end end end)
  connections[#connections+1]=waiting;return
 end
 -- The marker row (above the name, with the glyph at the bottom so it can bounce up inside the row) and the timer row (under it).
 local mark=new('TextLabel',{Name='Mark',BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,1),Position=markAt(0),Size=UDim2.fromScale(.4,S.Mark.Glyph/S.H),Font=Enum.Font.FredokaOne,TextScaled=true,
  Text='!',TextColor3=Color3.new(1,1,1),TextStrokeColor3=RGB(40,22,70),TextStrokeTransparency=0},sign)
 local timer=new('TextLabel',{Name='Timer',BackgroundTransparency=1,Position=UDim2.fromScale(0,S.Timer.Top/S.H),Size=UDim2.fromScale(1,S.Timer.Height/S.H),Font=Enum.Font.FredokaOne,TextScaled=true,
  Text='',TextColor3=C.EventColor,TextStrokeColor3=RGB(30,20,60),TextStrokeTransparency=.1},sign)
 local look=body.CFrame.LookVector;local yaw=math.atan2(-look.X,-look.Z)
 entry={Model=model,Body=body,Sign=sign,Mark=mark,Timer=timer,Home=body.CFrame,Base=body.Position,Size=body.Size.X,Yaw=yaw,Yaw0=yaw,Has=false,Moved=false,Scale=1,Poll=1,Near=nil}
 refreshMarker()
 -- R150: make her voice's Sound now (the asset is requested while she is merely in view), so the first greeting is not waiting for a download.
 pcall(voiceSound,entry,false)
end
local function attach(model)
 if entry and entry.Model==model then return end
 if not model:IsA('Model')then return end
 local body=model:FindFirstChild('Body')
 if body then build(model,body);return end
 local waiting;waiting=model.ChildAdded:Connect(function(child)if child.Name=='Body'then waiting:Disconnect();if model.Parent and not entry then build(model,child)end end end)
 connections[#connections+1]=waiting
end
local function detach(model)
 if entry and entry.Model==model then
  if entry.Body.Parent then settle(entry)end -- leave her as the server placed her (the next entry reads that as home)
  if entry.Mark then entry.Mark:Destroy()end
  if entry.Timer then entry.Timer:Destroy()end
  if voice.Sound then voice.Sound:Destroy();voice.Sound=nil;voice.Checked=false;voice.Playing=false end
  voice.Waiting=nil;voice.Lip.Level=0
  entry=nil
 end
end
for _,model in ipairs(CS:GetTagged(C.Tag))do attach(model)end
watch(CS:GetInstanceAddedSignal(C.Tag),attach);watch(CS:GetInstanceRemovedSignal(C.Tag),detach)
do -- (the model may already be in the map without the tag having replicated yet)
 local map=workspace:FindFirstChild('ChestChaseMap');local hub=map and map:FindFirstChild('EconomyHub');local model=hub and hub:FindFirstChild(C.ModelName)
 if model then attach(model)end
end
-- Each frame: turn to the camera, bob, swell and bounce while she talks (with the loudness of her voice), bounce the "?"; four
-- times a second, greet whoever came close.
-- Her Body is a big collidable, queryable anchored ball, so it is only written to when it matters: not at all while the camera is
-- beyond VerityConfig.AnimateDistance (she is set back to how the server placed her once, then left alone; her sign is not drawn
-- that far either) and not on a frame where nothing about her pose changed. Coming back, she picks up again from the rest pose.
local function playerRoot()
 local character=player.Character;return character and character:FindFirstChild('HumanoidRootPart')
end
-- The portrait in her window (built further down, only while the window is open); declared here because the frame loop drives it.
local P={Model=nil}
local portraitFrame
watch(Run.RenderStepped,function(dt)
 dt=math.min(dt or 1/60,.1)
 if voice.Playing then voiceTick()end -- audio, not animation: the fade-out and the end are never skipped
 local e=entry;local live=e~=nil and e.Body.Parent~=nil
 local reduced=GuiService.ReducedMotionEnabled
 local camera=workspace.CurrentCamera
 if live then
  -- Proximity greeting: only on coming within range (not while standing there), at most once a GreetingCooldown.
  e.Poll+=dt
  if e.Poll>=.25 then
   e.Poll=0
   local root=playerRoot()
   if root then
    local near=(root.Position-e.Base).Magnitude<=C.GreetingDistance
    if near and e.Near~=true and os.clock()-voice.LastAt>=C.GreetingCooldown then greet('near')end
    e.Near=near
   end
  end
 end
 local worldOn=live and not reduced and not(camera and(camera.CFrame.Position-e.Base).Magnitude>C.AnimateDistance)
 local portraitOn=P.Model~=nil and not reduced
 -- Voice level (R149, bounce since R151): this frame's level, from the voice's loudness. Only while she talks (and the level is still falling after it)
 -- and only if someone can see it: her body within AnimateDistance, or the window's portrait while it is open. Otherwise nothing is read or written.
 local lip=voice.Lip
 if worldOn or portraitOn then
  local talking=speaking()
  if talking or lip.Level>0 then
   local sound=voice.Sound
   VerityVoice.Step(lip,C.Lip,talking and sound and sound.PlaybackLoudness or 0,dt,talking)
  end
 elseif lip.Level>0 then lip.Level=0 end
 if portraitOn or P.Model then portraitFrame(reduced)end
 if not live then return end
 if not worldOn then settle(e);return end
 local now=os.clock()
 if camera then
  local to=camera.CFrame.Position-e.Base;local flat=math.sqrt(to.X*to.X+to.Z*to.Z)
  if flat>1 then
   local target=math.atan2(-to.X,-to.Z);e.Yaw=e.Yaw+wrap(target-e.Yaw)*(1-math.exp(-8*dt))
  end
 end
 -- Swelling and bouncing with the voice (the level: smoothed in and out): she grows upward from the dais and hops by TalkBounce of her size.
 local pose=VerityVoice.Pose(C,e.Size,lip.Level)
 local scale=pose.Scale
 if scale~=e.Scale then e.Scale=scale;local d=pose.Size;e.Body.Size=Vector3.new(d,d,d);e.Moved=true end
 local y=e.Base.Y+math.sin(now*1.4)*C.FootOffset+pose.Rise
 if not e.LastY or math.abs(y-e.LastY)>1e-3 or math.abs(wrap(e.Yaw-e.LastYaw))>1e-4 then -- nothing changed: no write
  e.LastY=y;e.LastYaw=e.Yaw;e.Moved=true
  e.Body.CFrame=CFrame.new(e.Base.X,y,e.Base.Z)*CFrame.Angles(0,e.Yaw,0)
 end
 if e.Has and e.Mark.Parent then e.Mark.Position=markAt(math.abs(math.sin(now*4.2))*MARK_BOUNCE)end
end)
-- Re-count the Void Tools whenever Tools come and go in the Backpack or the Character (and once a second, in case an
-- attribute arrives late). A new Backpack / Character (respawn) is picked up as it appears.
local function watchContainer(container)
 if not container then return end
 watch(container.ChildAdded,refreshMarker);watch(container.ChildRemoved,refreshMarker)
end
watchContainer(player:FindFirstChildOfClass('Backpack'));watchContainer(player.Character)
watch(player.ChildAdded,function(child)if child:IsA('Backpack')then watchContainer(child);refreshMarker()end end)
watch(player.CharacterAdded,function(character)watchContainer(character);refreshMarker()end)
local alive=true
local function recount()if not alive then return end;refreshMarker();task.delay(1,recount)end
task.delay(1,recount)
-- The window ---------------------------------------------------------------------------------------------------------------------
local old=pg:FindFirstChild('VerityGui');if old then old:Destroy()end
-- R150: the voice code above is declared before the window exists; this tells it whether her window is open (for a late 'talk' greeting).
local gui=new('ScreenGui',{Name='VerityGui',ResetOnSpawn=false,DisplayOrder=41,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
local shade=new('TextButton',{Name='Shade',Text='',AutoButtonColor=false,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=.48,BorderSizePixel=0,Visible=false},gui)
shade:SetAttribute('ButtonSound',false)
pcall(function()require(RS.MenuBackdrop).Attach(gui,shade,false)end)
local panel=new('Frame',{Name='VerityPanel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.94,.88),Visible=false,BorderSizePixel=0},gui);Bright.Panel(panel)
new('UISizeConstraint',{MaxSize=Vector2.new(660,450)},panel)
local header=new('Frame',{Name='Header',Size=UDim2.new(1,0,0,56),BorderSizePixel=0},panel);Bright.Header(header)
local title=text(header,'Title','🌟 VERITY',28);title.TextXAlignment=Enum.TextXAlignment.Left;title.Position=UDim2.fromOffset(18,2);title.Size=UDim2.new(1,-84,1,-4)
local closeX=new('TextButton',{Name='Close',Text='X',Position=UDim2.new(1,-52,0,7),Size=UDim2.fromOffset(42,42),BorderSizePixel=0,TextSize=20},header);Bright.Button(closeX,RGB(255,61,85))
-- Verity herself (R149): her 3D model in a ViewportFrame (the same yellow ball and smiley as in the world), bobbing, swelling and bouncing with the same
-- voice level, standing on a little gold dais (a flat oval behind it). The model exists only while the window is open and the portrait is shown.
local portrait=new('Frame',{Name='Portrait',BackgroundColor3=Theme.Colors.Inset,BorderSizePixel=0},panel);Theme.Corner(portrait,12);stroke(portrait,GOLD,2)
local daisShadow=new('Frame',{Name='Dais',AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=GOLD,BackgroundTransparency=.35,BorderSizePixel=0},portrait);Theme.Corner(daisShadow,40)
local view=new('ViewportFrame',{Name='Model',AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0,Ambient=RGB(195,195,185),LightColor=RGB(255,247,228),
 LightDirection=Vector3.new(-.45,-.8,1)},portrait)
local portraitCamera=new('Camera',{Name='PortraitCamera',FieldOfView=C.Portrait.Fov},view);view.CurrentCamera=portraitCamera
-- The camera looks at the ball (centred on the origin, her face toward -Z) from straight in front; the viewport is square, so the ball fills
-- C.Portrait.Fill of it at rest (room is left for the swell, the bounce and the bob).
do
 local half=math.tan(math.rad(C.Portrait.Fov)/2)
 local distance=C.Portrait.Size/2/(half*C.Portrait.Fill)
 portraitCamera.CFrame=CFrame.lookAt(Vector3.new(0,0,-distance),Vector3.new(0,0,0))
end
local function buildPortrait()
 if P.Model then return end
 local D=C.Portrait.Size
 local model=new('Model',{Name='VerityPortrait'},view)
 local ball=new('Part',{Name='Body',Shape=Enum.PartType.Ball,Size=Vector3.new(D,D,D),CFrame=CFrame.new(0,0,0),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,
  CastShadow=false,Color=C.BodyColor,Material=Enum.Material.SmoothPlastic},model)
 new('Decal',{Name='FaceFront',Face=Enum.NormalId.Front,Texture=C.Image,Color3=Color3.new(1,1,1)},ball)
 P.Model,P.Body,P.Scale,P.Still=model,ball,1,nil
 portraitFrame(GuiService.ReducedMotionEnabled)
end
local function dropPortrait()
 if not P.Model then return end
 P.Model:Destroy()
 P.Model,P.Body=nil,nil
end
-- One frame of the portrait (only while it exists): the ball bobs, swells and bounces with the voice level (its bottom stays where it rests, like her body in
-- the world). still (ReducedMotion): the rest pose, once.
portraitFrame=function(still)
 local ball=P.Body;if not ball then return end
 if still then
  if P.Still then return end
  P.Still=true
 else P.Still=false end
 local D=C.Portrait.Size;local level=still and 0 or voice.Lip.Level
 local pose=VerityVoice.Pose(C,D,level)
 local scale=pose.Scale
 if scale~=P.Scale then P.Scale=scale;ball.Size=Vector3.new(pose.Size,pose.Size,pose.Size)end
 ball.CFrame=CFrame.new(0,(still and 0 or math.sin(os.clock()*1.4)*C.Portrait.Bob*D)+pose.Rise,0)
end
local quest=text(panel,'QuestText',C.Quest,20);quest.TextXAlignment=Enum.TextXAlignment.Left;quest.TextYAlignment=Enum.TextYAlignment.Center
local eventLine=text(panel,'EventLine','',16,VIOLET)
local function chip(name,color)
 local f=new('Frame',{Name=name,BackgroundColor3=Theme.Colors.Card,BorderSizePixel=0},panel);Theme.Corner(f,10);stroke(f,color,2)
 local caption=text(f,'Caption','',13,Theme.Colors.Muted);local value=text(f,'Count','0',22,color);return f,caption,value
end
local voidChip,voidCaption,voidCount=chip('VoidChip',VIOLET);voidCaption.Text='VOID PACKS YOU HAVE'
local doneChip,doneCaption,doneCount=chip('DeliveredChip',GOLD);doneCaption.Text='HANDED IN'
-- The exchange as pictures: [Void Pack] -> [Verity Pack] and "1 VOID PACK = 1 VERITY PACK" (real 3D pack pictures, like the hotbar).
local exchange=new('Frame',{Name='Exchange',BackgroundTransparency=1,BorderSizePixel=0},panel)
local function packHolder(name,color)
 local h=new('Frame',{Name=name,BackgroundColor3=Theme.Colors.Inset,BorderSizePixel=0},exchange);Theme.Corner(h,10);stroke(h,color,2);return h
end
local voidHolder=packHolder('VoidPack',VIOLET);local verityHolder=packHolder('VerityPack',GOLD)
local arrow=text(exchange,'Arrow','➜',30,GOLD);arrow.TextWrapped=false
local rewardLine=text(exchange,'RewardLine',C.RewardText,16,GOLD)
local function showPack(holder,variant,fallback)
 local shown=false
 if Pictures then
  local proxy=Instance.new('Folder');proxy:SetAttribute('SeedPackTool',true);proxy:SetAttribute('Stage',C.PackStage);proxy:SetAttribute('BagVariant',variant);proxy:SetAttribute('PackMutation','None')
  shown=pcall(Pictures.Show,holder,proxy,1)
 end
 if not shown then local e=text(holder,'Emoji',fallback,28);e.Size=UDim2.fromScale(1,1);e.TextScaled=true end
end
showPack(voidHolder,C.VoidVariant,'🌑');showPack(verityHolder,C.VerityVariant,'🌟')
local status=text(panel,'Status','',16,MINT)
local give=new('TextButton',{Name='GiveButton',Text='',BorderSizePixel=0},panel);Bright.Button(give,GOLD)
local giveCaption=text(give,'Caption','GIVE VOID PACK',22);giveCaption.Size=UDim2.new(1,-16,1,0);giveCaption.Position=UDim2.fromOffset(8,0);giveCaption.ZIndex=12
new('UIScale',{Name='Pulse'},give)
local closeButton=new('TextButton',{Name='CloseButton',Text='',BorderSizePixel=0},panel);Bright.Button(closeButton,RGB(92,128,255))
local closeCaption=text(closeButton,'Caption','CLOSE',20);closeCaption.Size=UDim2.new(1,-8,1,0);closeCaption.Position=UDim2.fromOffset(4,0);closeCaption.ZIndex=12
local function tint(button,color)Bright.Gradient(button,color:Lerp(Color3.new(1,1,1),.24),color:Lerp(Color3.new(),.12),90)end
-- Layout (pixels from the panel's real size, so phones and computers both fit) ---------------------------------------------------
-- Every label is sized through GardenTextFit (fit): it picks the largest font up to `size` whose wrapped text fits the label's box, and only then
-- shortens it. (Before R149 layout() wrote TextSize itself after the fitter had chosen one, so on the second layout the quest sentence kept the
-- full-size font in a box it no longer fitted and the engine cut it off with "...".)
local function fit(label,size,minimum)Fit.Attach(label,size,minimum or 8)end
local function layout()
 local size=panel.AbsoluteSize;local W,H=size.X,size.Y;if W<=0 or H<=0 then return end
 local short=H<380
 local headH=short and 46 or 56;header.Size=UDim2.new(1,0,0,headH);fit(title,short and 22 or 28)
 closeX.Position=UDim2.new(1,-(headH-6)-6,0,3);closeX.Size=UDim2.fromOffset(headH-6,headH-6)
 local pad=12;local top=headH+pad;local bodyH=H-top-pad
 local showPortrait=W>=560 and H>=330
 local pw=showPortrait and math.min(bodyH,math.floor(W*.34))or 0
 portrait.Visible=showPortrait;portrait.Position=UDim2.fromOffset(pad,top);portrait.Size=UDim2.fromOffset(pw,bodyH)
 local side=math.max(0,pw-16);local ballSize=math.floor(side*C.Portrait.Fill)
 view.Size=UDim2.fromOffset(side,side);view.Position=UDim2.new(.5,0,.5,-math.floor(ballSize*.04))
 daisShadow.Size=UDim2.fromOffset(math.floor(ballSize*.8),math.max(8,math.floor(ballSize*.12)));daisShadow.Position=UDim2.new(.5,0,.5,math.floor(ballSize*.5))
 if panel.Visible and showPortrait then buildPortrait()else dropPortrait()end
 local cx=pad+(showPortrait and pw+pad or 0);local cw=W-cx-pad
 local gap=short and 6 or 10
 local eventH=short and 17 or 24;local chipH=short and 32 or 54;local exH=short and 44 or 66;local statusH=short and 17 or 24;local buttonH=short and 36 or 52
 -- No empty row: when The Darkened's line has nothing to say its room goes to the quest sentence.
 local eventRow=eventLine.Visible and eventH+gap or 0
 local questH=math.max(short and 30 or 40,bodyH-(eventRow+chipH+exH+statusH+buttonH)-gap*4)
 local y=top
 quest.Position=UDim2.fromOffset(cx,y);quest.Size=UDim2.fromOffset(cw,questH);fit(quest,short and 15 or cw<380 and 18 or 20,11);y+=questH+gap
 if eventLine.Visible then
  eventLine.Position=UDim2.fromOffset(cx,y);eventLine.Size=UDim2.fromOffset(cw,eventH);fit(eventLine,short and 12 or 16);y+=eventH+gap
 end
 local chipW=math.floor((cw-gap)/2)
 for i,spec in ipairs({{voidChip,voidCaption,voidCount},{doneChip,doneCaption,doneCount}})do
  spec[1].Position=UDim2.fromOffset(cx+(i-1)*(chipW+gap),y);spec[1].Size=UDim2.fromOffset(chipW,chipH)
  spec[2].Position=UDim2.fromOffset(4,2);spec[2].Size=UDim2.new(1,-8,0,math.floor(chipH*.38));fit(spec[2],short and 10 or 12)
  spec[3].Position=UDim2.fromOffset(4,math.floor(chipH*.4));spec[3].Size=UDim2.new(1,-8,0,math.floor(chipH*.58));fit(spec[3],short and 16 or 24)
 end
 y+=chipH+gap
 -- The exchange row: two square pack pictures with an arrow between, then the rule in words.
 exchange.Position=UDim2.fromOffset(cx,y);exchange.Size=UDim2.fromOffset(cw,exH)
 local arrowW=math.max(28,math.floor(exH*.5));local pic=math.min(exH,math.floor((cw-arrowW-12-90)/2))
 voidHolder.Position=UDim2.fromOffset(0,math.floor((exH-pic)/2));voidHolder.Size=UDim2.fromOffset(pic,pic)
 arrow.Position=UDim2.fromOffset(pic+4,0);arrow.Size=UDim2.fromOffset(arrowW,exH);fit(arrow,short and 22 or 30)
 verityHolder.Position=UDim2.fromOffset(pic+arrowW+8,math.floor((exH-pic)/2));verityHolder.Size=UDim2.fromOffset(pic,pic)
 local rx=pic*2+arrowW+8+10
 rewardLine.Position=UDim2.fromOffset(rx,0);rewardLine.Size=UDim2.fromOffset(math.max(10,cw-rx),exH);fit(rewardLine,short and 13 or 16)
 y+=exH+gap
 status.Position=UDim2.fromOffset(cx,y);status.Size=UDim2.fromOffset(cw,statusH);fit(status,short and 13 or 16);y+=statusH+gap
 local giveW=math.floor((cw-gap)*.62)
 give.Position=UDim2.fromOffset(cx,y);give.Size=UDim2.fromOffset(giveW,buttonH);fit(giveCaption,short and 16 or 22)
 closeButton.Position=UDim2.fromOffset(cx+giveW+gap,y);closeButton.Size=UDim2.fromOffset(cw-giveW-gap,buttonH);fit(closeCaption,short and 15 or 20)
end
watch(panel:GetPropertyChangedSignal('AbsoluteSize'),layout)
-- State ------------------------------------------------------------------------------------------------------------------------
local state={Known=false,VoidPacks=0,Delivered=0}
local busy=false;local busySerial=0
local pulse
local function number(v)return type(v)=='number'and v==v and v>=0 and math.min(math.floor(v),1e9)or nil end
local function eventText()
 if state.EventActive==true then return'🌑 THE DARKENED IS HERE NOW!',VIOLET end
 if state.NextAt then
  local left=state.NextAt-workspace:GetServerTimeNow()
  if left>0 then return'🌑 THE DARKENED ARRIVES IN '..countdown(left),SKY end
  return'🌑 THE DARKENED IS ARRIVING...',SKY
 end
 return'',VIOLET
end
local function render()
 if pulse then pulse:Cancel();pulse=nil end;give.Pulse.Scale=1
 voidCount.Text=state.Known and tostring(state.VoidPacks)or'-';doneCount.Text=state.Known and tostring(state.Delivered)or'-'
 rewardLine.Text=state.RewardText or C.RewardText
 local live=eventLive();state.Live=live -- (R149: no "EVENT ENDS IN ..." line here; after the end the GIVE button says EVENT ENDED)
 local line,color=eventText();eventLine.Text=line;eventLine.TextColor3=color;eventLine.Visible=line~=''
 local can=state.Known and state.VoidPacks>0 and not busy and live
 give.Active=can;give.Interactable=can;give.AutoButtonColor=can;give:SetAttribute('Enabled',can)
 tint(give,can and GOLD or RGB(96,104,140))
 giveCaption.Text=not live and C.Event.Ended or busy and'HANDING IT OVER...'or'GIVE VOID PACK'
 if can and not GuiService.ReducedMotionEnabled then
  pulse=Tween:Create(give.Pulse,TweenInfo.new(.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Scale=1.05});pulse:Play()
 end
 layout()
end
local function say(message,good)
 status.Text=message or'';status.TextColor3=good and MINT or RED
end
local function setBusy(value)
 busy=value;busySerial+=1
 if value then local serial=busySerial -- (a dropped request must not leave the button locked)
  task.delay(4,function()if busy and busySerial==serial then busy=false;render()end end)
 end
end
local ticking=false
local function open()
 panel.Visible=true;shade.Visible=true
 if pg:GetAttribute('SeedMenu')~='Verity'then pg:SetAttribute('SeedMenu','Verity')end
 render()
 if not ticking then ticking=true
  local function tick()
   if not panel.Visible or not gui.Parent then ticking=false;return end
   local was=eventLine.Visible
   local line,color=eventText();eventLine.Text=line;eventLine.TextColor3=color;eventLine.Visible=line~=''
   if eventLive()~=state.Live then render() -- the event ended while the window was open
   elseif eventLine.Visible~=was then layout()end -- (its row appears / goes: the quest sentence gives it room)
   task.delay(1,tick)
  end
  task.delay(1,tick)
 end
end
local function hidePanel()
 panel.Visible=false;shade.Visible=false;if pulse then pulse:Cancel();pulse=nil end
 dropPortrait() -- (her 3D model lives only while the window is open)
end
local function close()
 hidePanel()
 if pg:GetAttribute('SeedMenu')=='Verity'then pg:SetAttribute('SeedMenu',nil)end
end
local function onServer(kind,payload)
 if type(payload)~='table'then payload={}end
 if kind=='Open'then
  state.Known=true;state.VoidPacks=number(payload.VoidPacks)or 0;state.Delivered=number(payload.Delivered)or 0
  state.RewardText=type(payload.RewardText)=='string'and payload.RewardText:sub(1,80)or nil
  state.EventActive=type(payload.EventActive)=='boolean'and payload.EventActive or nil
  state.NextAt=type(payload.NextAt)=='number'and payload.NextAt==payload.NextAt and payload.NextAt or nil
  setBusy(false);say('')
  talked=true;refreshMarker() -- she has been talked to: the "!" is gone for the rest of this session
  open()
  greet('talk')
 elseif kind=='Greet'then
  -- The owner's /test verityvoice: play her cut now (the numbers come with the message; a bad pair falls back to her model's / the config's).
  local a,b=payload.Start,payload.End
  if not(VerityVoice.Finite(a)and VerityVoice.Finite(b))then a,b=nil,nil end
  greet('test',{Start=a,End=b})
 elseif kind=='Done'then
  setBusy(false)
  state.Delivered=number(payload.Delivered)or state.Delivered+1;state.VoidPacks=math.max(0,state.VoidPacks-1)
  say(C.Thanks,true);Audio.Play('GemClaim')
  render()
  if not panel.Visible then open()end
 elseif kind=='Refused'then
  setBusy(false)
  say(type(payload.Reason)=='string'and payload.Reason:sub(1,90)or C.Reasons.Failed,false);Audio.Play('Denied') -- R150: a refused hand-in
  if not panel.Visible then open()else render()end
 end
end
task.spawn(function()
 local remote=remotes:WaitForChild(C.RemoteName,60);if not remote or not gui.Parent then return end
 watch(remote.OnClientEvent,onServer)
 give.Activated:Connect(function()
  if not give.Active or busy then return end
  setBusy(true);say('');render()
  remote:FireServer('Give')
 end)
end)
voice.PanelOpen=function()return panel.Visible end
closeX.Activated:Connect(close);closeButton.Activated:Connect(close);shade.Activated:Connect(close)
watch(pg:GetAttributeChangedSignal('SeedMenu'),function()
 if panel.Visible and pg:GetAttribute('SeedMenu')~='Verity'then hidePanel()end
end)
render()
gui.Destroying:Connect(function()
 alive=false;if pulse then pulse:Cancel()end
 for _,c in ipairs(connections)do c:Disconnect()end
 dropPortrait()
 if Pictures then pcall(Pictures.Clear,voidHolder);pcall(Pictures.Clear,verityHolder)end
 if entry then
  if entry.Mark then entry.Mark:Destroy()end
  if entry.Timer then entry.Timer:Destroy()end
  if entry.Body.Parent then settle(entry)end -- leave her as the server placed her
  if voice.Sound then voice.Sound:Destroy();voice.Sound=nil end
  voice.Playing=false;voice.Waiting=nil;voice.Lip.Level=0
  entry=nil
 end
end)
