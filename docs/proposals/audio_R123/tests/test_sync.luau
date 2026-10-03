--!nocheck
-- R123 sound-sync checks (see run.sh). Real ReplicatedStorage modules and real client scripts under the Roblox mock.
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local RS=W.RS;local Run=W.Run

-- Mock gaps -------------------------------------------------------------------------------------------------------
local Players=W.service('Players')
W.service('Debris').AddItem=function()end
local preloaded={}
W.service('ContentProvider').PreloadAsync=function(_,list)for _,s in ipairs(list)do preloaded[s]=true end end
W.service('HttpService').JSONDecode=function()return {}end
local CAS=W.service('ContextActionService');function CAS.BindActionAtPriority(_,name,fn)W.actions[name]=fn end
W.UIS.TouchTapInWorld=R.signal();W.UIS.GamepadEnabled=false
local sounds={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnClientEvent=R.signal();o.OnServerEvent=R.signal();o.FireServer=function()end end
 if class=='Sound'then
  o.Ended=R.signal();o.IsLoaded=true;o.TimeLength=12;o.IsPlaying=false;o.Loaded=R.signal();o.TimePosition=0;o.PlaybackSpeed=1
  o.Play=function(self)self.IsPlaying=true;self.PlayedAt=R.clock;self.Plays=(self.Plays or 0)+1 end
  o.Stop=function(self)self.IsPlaying=false end
  sounds[#sounds+1]=o
 end
 return o end end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
me.CharacterAdded=R.signal();me.CharacterRemoving=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local char=R.new('Model');char.Name='Me';char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,100);root.Parent=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local camera=W.workspace.CurrentCamera;camera.FieldOfView=70
local function frame(dt)dt=dt or 1/60;R.advance(dt);Run.RenderStepped:Fire(dt);Run.Heartbeat:Fire(dt)end
local function run(name)local sc=R.new('LocalScript');sc.Name=name;W.load(name,sc);return sc end
local function count(name)local n=0;for _,s in ipairs(sounds)do if s.Name==name then n+=1 end end;return n end

-- 1. LocalSfx: one play per id / spot / instant ------------------------------------------------------------------
local Sfx=W.module('LocalSfx')
local id='rbxassetid://123456'
Sfx.Play(id,V3(0,0,0),.4);Sfx.Play(id,V3(1,0,0),.4)
check(count('ChestChaseOneShot')==1,'same id, same spot, same frame plays once')
Sfx.Play(id,V3(60,0,0),.4);check(count('ChestChaseOneShot')==2,'same id far away still plays')
Sfx.Play('rbxassetid://654321',V3(0,0,0),.4);check(count('ChestChaseOneShot')==3,'other id at the same spot plays')
R.advance(.05);Sfx.Play(id,V3(0,0,0),.4);check(count('ChestChaseOneShot')==4,'repeat after the de-dupe window plays')
Sfx.Play('rbxassetid://777',nil,.3);Sfx.Play('rbxassetid://777',nil,.3);check(count('ChestChaseOneShot')==5,'2D double fire plays once')

-- 2. RarityRevealAudio: the reveal reaches the client late; audio joins the screen timeline ----------------------
local A=W.module('RarityRevealAudio');A.Preload()
local SS=W.service('SoundService')
local whoosh,chime=SS:FindFirstChild('Reveal_Whoosh'),SS:FindFirstChild('Reveal_Chime')
local pitch=math.clamp(2.8/W.module('RarityRevealSequence').SeedAt(7),.75,2)
A.Begin(7,0);check(whoosh.IsPlaying and near(whoosh.TimePosition,.44,1e-4),'on-time reveal: whoosh from its trimmed start')
A.Begin(7,.3);check(whoosh.IsPlaying and near(whoosh.TimePosition,.44+.3*pitch,1e-4),'late reveal: whoosh skips the elapsed build (x pitch)')
A.Begin(7,2.6);check(not whoosh.IsPlaying,'reveal already past the burst: no whoosh')
-- R138: Common..Rare sound when the seed pops out (Burst), not at Begin; each tier differs; a late cue is dropped.
local pop,note,note2,spark=SS:FindFirstChild('Reveal_Pop'),SS:FindFirstChild('Reveal_Note'),SS:FindFirstChild('Reveal_Note2'),SS:FindFirstChild('Reveal_Spark')
A.Begin(3,.1);check(not chime.IsPlaying and not pop.IsPlaying and not note.IsPlaying,'low tiers: nothing at the start any more')
A.Stop();A.Burst(1,.1);check(pop.IsPlaying and not note.IsPlaying and not spark.IsPlaying,'Common: a pop')
A.Stop();A.Burst(2,.1);check(pop.IsPlaying and not note.IsPlaying,'Uncommon: a pop...');R.advance(.1);check(note.IsPlaying and note.PlaybackSpeed>pop.PlaybackSpeed,'...then a rising note')
A.Stop();A.Burst(3,.1);check(spark.IsPlaying and note.IsPlaying and not pop.IsPlaying,'Rare: a sparkle and a note...');R.advance(.1);check(note2.IsPlaying and note2.PlaybackSpeed>note.PlaybackSpeed,'...then a higher note')
A.Stop();A.Burst(2,.8);R.advance(.2);check(not pop.IsPlaying and not note.IsPlaying,'a low-tier cue reaching this client late is dropped')
A.Stop();A.Burst(3);check(spark.IsPlaying,'old call shape (no time) still plays')
-- R136: Legendary / Mythic get a whoosh during their charge-up (it joins late like Secret+), then chimes and an impact.
local impact=SS:FindFirstChild('Reveal_Impact')
A.Begin(4,0);check(whoosh.IsPlaying and not chime.IsPlaying,'Legendary: whoosh on the charge-up')
A.Begin(5,.2);check(whoosh.IsPlaying and near(whoosh.TimePosition,.44+.2*A.CuePitch[5],1e-4),'Mythic joined late: whoosh skips the elapsed build')
A.Begin(4,.69);check(not whoosh.IsPlaying,'Legendary reveal already at its burst: no whoosh')
A.Begin(5,0);A.Step(5,.5);check(chime.IsPlaying,'Mythic: a rising chime half way through the charge-up')
A.Burst(5);check(not whoosh.IsPlaying and impact.IsPlaying and chime.IsPlaying,'Mythic burst: impact + chime, whoosh cut')
A.Burst(7);check(not whoosh.IsPlaying,'burst still cuts the whoosh')
-- R138 (owner: Secret / Cosmic / King more audible): louder build, beats and burst; King adds a low impact.
local royal=SS:FindFirstChild('Reveal_Royal')
A.Begin(7,0);check(whoosh.IsPlaying and whoosh.Volume>=.2,'Cosmic: the build is louder ('..whoosh.Volume..', was .09)')
A.Step(7,1.0);check(chime.IsPlaying and chime.Volume>=.12,'Cosmic: louder beats ('..chime.Volume..', was .04)')
A.Begin(6,0);A.Burst(6);check(impact.IsPlaying and impact.Volume>=.28,'Secret: louder burst ('..impact.Volume..', was .12)')
A.Stop();A.Burst(8);check(impact.IsPlaying and impact.Volume>=.3 and royal.IsPlaying and royal.Volume>=.3 and spark.IsPlaying,'King: louder impact and fanfare plus a low hit')
A.Stop();A.Begin(4,0);check(whoosh.IsPlaying and whoosh.Volume<.1,'Legendary keeps its R136 volume')

-- 3. TrackRefreshSky: each countdown beep and the wall number change on the same frame ------------------------------
local paints={}
W.stub('RefreshSky',{Begin=function()return function()end end,Destroy=function()end})
W.stub('TrackBlackout',{Bounds=function()return nil end,InBounds=function()return false end})
W.stub('RefreshHorn',{New=function()return {Play=function()return true end,Stop=function()end,Destroy=function()end}end})
W.stub('RefreshBarrier',{Decorate=function()return function(now,remaining)paints[#paints+1]={At=R.clock,Shown=math.max(0,math.ceil(remaining))}end end})
local rt=R.new('Folder');rt.Name='_GameplayRuntime';rt.Parent=map
local wall=R.new('Part');wall.Name='BiomeRefreshWall';wall.Parent=rt
map:SetAttribute('BiomeRefreshEndsAt',R.clock+5.31);map:SetAttribute('BiomesRefreshing',true)
run('TrackRefreshSky')
local beep=SS:FindFirstChild('TrackRefreshCountdown')
local seen={};local lastPlays=0
for _=1,6*60 do
 frame()
 if (beep.Plays or 0)>lastPlays then
  lastPlays=beep.Plays
  local p=paints[#paints]
  seen[#seen+1]=p and p.At==R.clock and p.Shown or -1
 end
end
check(#seen==3,'three countdown beeps (got '..#seen..')')
check(seen[1]==3 and seen[2]==2 and seen[3]==1,'wall shows 3 / 2 / 1 on the beep frame (got '..table.concat(seen,',')..')')
map:SetAttribute('BiomesRefreshing',false)

-- 4. ChestRunAlert: alarm loaded before the first run, played on the RUN!! frame -----------------------------------
local alert=R.Instance.new('RemoteEvent');alert.Name='ChestRunAlert';alert.Parent=remotes
alert:SetAttribute('AlarmSoundId','rbxassetid://135684635714618');alert:SetAttribute('HeartbeatSoundId','');alert:SetAttribute('SuccessSoundId','')
run('ChestRunAlert')
local alarm=SS:FindFirstChild('ChestRunAlarm')
check(alarm.SoundId=='rbxassetid://135684635714618','alarm id taken from the server attribute at start')
check(preloaded[alarm],'alarm preloaded at start')
me:SetAttribute('ChestChaseRunToken',1);me:SetAttribute('ChestChaseRunActive',true)
alert.OnClientEvent:Fire('Show','rbxassetid://135684635714618',.16,1,char)
frame()
local label=pg:FindFirstChild('ChestRunAlertUI'):FindFirstChild('RunWarning')
check(label.Visible and alarm.IsPlaying and alarm.PlayedAt==R.clock,'alarm starts on the frame the RUN!! label appears')
frame();frame();check(alarm.Plays==1,'alarm plays once per run')
me:SetAttribute('ChestChaseRunActive',false);frame()

-- 5. NotificationClient83: notice cues warm at startup -------------------------------------------------------------
local notice=R.Instance.new('RemoteEvent');notice.Name='Notice83';notice.Parent=remotes
run('NotificationClient83')
local rare=SS:FindFirstChild('Notice_RarePack')
check(rare~=nil and preloaded[rare],'rare-pack cue exists and is preloaded before the first notice')

-- 6. TrackHoleClient: trap thud preloaded; dirt follows FastMode ----------------------------------------------------
local hole=R.Instance.new('RemoteEvent');hole.Name='TrackHole';hole.Parent=remotes
local motion=RS:FindFirstChild('RunnerMotion');motion:SetAttribute('TrackBoundaryZ',0);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114)
run('TrackHoleClient')
local landId;for _,s in ipairs(W.module('PlantingEffects').Sounds)do if s.Key=='Land'then landId=s.Id end end
local warm=false;for _,s in ipairs(sounds)do if s.SoundId==landId and s.Name~='Planting Land'then warm=true end end
check(warm,'trap thud id preloaded with the dig recording')
local function dirt()local n=0;for _,p in ipairs(W.workspace:GetChildren())do if p.Name=='HoleDirt'then n+=1 end end;return n end
local before=dirt();hole.OnClientEvent:Fire({Kind='Dig',Id=1,Position=V3(0,0,100)});local full=dirt()-before
me:SetAttribute('FastMode',true)
before=dirt();hole.OnClientEvent:Fire({Kind='Dig',Id=2,Position=V3(0,0,100)});local fast=dirt()-before
check(full==8 and fast==4,'dirt chunks 8 normally, 4 in FastMode (got '..full..'/'..fast..')')
W.Gui.ReducedMotionEnabled=true;me:SetAttribute('FastMode',false)
before=dirt();hole.OnClientEvent:Fire({Kind='Trap',Id=3,Position=V3(0,0,100)})
check(dirt()-before>=3,'reduced motion still shows a burst')

print(('sync checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
