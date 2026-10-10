--!nocheck
-- R150 SFX fix round, part 1: the shared modules on the Roblox mock with the REAL ReplicatedStorage modules of this checkout.
--  1. InteractionAudio: the Denied and MenuClose keys, per-key gaps, the optional minGap, Mute, menu cues replace each other, built-in sound.
--  2. SoundTiming: ONE table of lead-ins (Start_<id> attribute wins), every cue reads it (reveal pop / impact / spark, onlooker burst, Darkened
--     arrival, tear, keyboard-style callers), the cold-file window.
--  3. RarityRevealAudio: the Common / Uncommon pop starts at the Bubble04 lead-in, a Legendary+ burst reaching the client late is dropped.
--  4. RevealFlourish: the onlooker burst skips the file's silent lead-in. VeiledArrivalFx: the arrival sound joins at the packet's age.
--  5. LocalSfx: the shorter cold window, late join (skip).
--  6. ButtonHighlights: close buttons click MenuClose, ButtonSound overrides; WatchMenus: one open / close rule for every SeedMenu path.
--  7. NoticeFeed83 / NotificationClient83 / NotificationService: refusals click Denied (red notice or kind='Denied'), success does not.
--  8. WorldStatusState: the "Reopens in N" row changes on the beep frame.
--  9. AudioMixer: Effects 0 mutes the keeper snore and characters that already existed; the saved mix is applied before SettingsState answers.
local W=require('./world');local E=require('./sfx_env')(W);local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(e or 1e-6)end
local RS=W.RS
local SS=W.service('SoundService')
E.player('Me')
local pg,root=E.pg,E.root
W.stub('EnvironmentLighting',{Level=0,SetBlackout=function()end})
local function played(key)return E.plays('Interaction_'..key)end

-- 1. InteractionAudio ----------------------------------------------------------------------------------------------------------------------
local Audio=W.module('InteractionAudio')
do
 check(Audio.Asset('Denied')=='rbxasset://sounds/electronicpingshort.wav','Denied is the built-in ping (no upload)')
 check(Audio.Asset('MenuClose')==Audio.Asset('MenuClick'),'MenuClose is the MenuClick file')
 local function voices(key)return E.named('Interaction_'..key)end
 check(#voices('Denied')==3 and #voices('MenuClose')==3,'both new keys have their own 3-voice pool')
 local speedsOk=true;for _,v in ipairs(voices('Denied'))do if not near(v.PlaybackSpeed,.55)then speedsOk=false end end
 for _,v in ipairs(voices('MenuClose'))do if not near(v.PlaybackSpeed,.85)then speedsOk=false end end
 check(speedsOk,'Denied plays at .55 and MenuClose at .85 (the existing sounds at another pitch)')
 check(voices('Denied')[1].SoundGroup==W.module('AudioMixer').Group('Interface'),'both are on the Interface group')
 for _,v in ipairs(E.sounds)do if v.Name:match('^Interaction_')then E.load(v)end end
 -- gaps
 E.resetPlays();R.advance(1)
 check(Audio.Play('Denied')==true and Audio.Play('Denied')==false,'a second Denied inside its gap does not play')
 R.advance(.2);check(Audio.Play('Denied')==false,'still inside .25 s')
 R.advance(.06);check(Audio.Play('Denied')==true,'after .25 s it plays again')
 check(played('Denied')==2,'two sounds in all for four taps')
 -- default gap .09 and the optional minGap
 E.resetPlays();R.advance(1)
 local n=0;for i=1,5 do if Audio.Play('Bubble04')then n+=1 end;R.advance(.065)end
 check(n==3,'the default .09 s gap swallows 2 of 5 clicks at .065 s (the old pack-click bug) ('..n..')')
 R.advance(1);n=0
 for i=1,5 do if Audio.Play('Bubble04',.065*.8)then n+=1 end;R.advance(.065)end
 check(n==5,'with a minGap under the click interval all 5 sound ('..n..')')
 R.advance(1);n=0
 for i=1,40 do if Audio.Play('Bubble04',.065*.8)then n+=1 end;R.advance(.01)end
 check(n<=8,'hammering the key faster than the interval never stacks beyond the gap ('..n..' in .4 s)')
 -- Bubble04 plays from its measured lead-in
 R.advance(1);E.resetPlays();Audio.Play('Bubble04')
 local logged
 for _,v in ipairs(voices('Bubble04'))do if v.PlayedAt==R.clock then logged=v.PlayLog[#v.PlayLog] end end
 check(logged and near(logged.TimePosition,.1),'Bubble04 starts at its .1 s lead-in')
 -- Mute
 R.advance(1);Audio.Mute('MenuClose',.25)
 check(Audio.Play('MenuClose')==false,'a muted key does not play')
 R.advance(.3);check(Audio.Play('MenuClose')==true,'and plays again when the mute is over')
 -- menu cues replace each other
 R.advance(1);E.resetPlays()
 Audio.Play('MenuClick');R.advance(.12);local before=0;for _,v in ipairs(voices('MenuClick'))do if v.IsPlaying then before+=1 end end
 Audio.Play('MenuClose')
 local after=0;for _,v in ipairs(voices('MenuClick'))do if v.IsPlaying then after+=1 end end
 check(before==1 and after==0,'MenuClose cuts a MenuClick that is still sounding (one menu cue at a time)')
 check(Audio.Play('NoSuchKey')==false,'an unknown key is refused')
end

-- 2. SoundTiming: one table -------------------------------------------------------------------------------------------------------------------
local Timing=W.module('SoundTiming')
local timingScript=RS:FindFirstChild('SoundTiming')
do
 local function snd(id)local s=R.Instance.new('Sound');s.SoundId=id;return s end
 check(near(Timing.Offset(snd('rbxassetid://9120769331')),.04),'Impact / Spark / onlooker burst id: .04 in the shared table')
 check(near(Timing.Offset(snd('rbxassetid://9120768742')),.44),'Whoosh id: .44 in the shared table')
 check(near(Timing.Offset(snd('rbxassetid://9125725227')),.10),'paper tear id: .10 in the shared table')
 check(near(Timing.Offset(snd('rbxassetid://96764044228884')),.10),'Bubble04 id: .10')
 check(Timing.Offset(snd('rbxassetid://113108830240353'))==0,'the keyboard click id has no measured lead-in yet: 0')
 timingScript:SetAttribute('Start_113108830240353',.07)
 check(near(Timing.Offset(snd('rbxassetid://113108830240353')),.07),'a Start_<id> attribute on SoundTiming tunes any cue without a code change')
 timingScript:SetAttribute('Start_113108830240353',nil)
 timingScript:SetAttribute('Start_9120769331',.2)
 check(near(Timing.Offset(snd('rbxassetid://9120769331')),.2),'the attribute wins over the table')
 timingScript:SetAttribute('Start_9120769331',nil)
 check(near(Timing.Offset(snd('rbxassetid://9120769331'),.5),.5),'an explicit override beats both')
 check(Timing.Offset(snd('rbxasset://sounds/electronicpingshort.wav'))==0,'a built-in sound has no lead-in')
end

-- 3. RarityRevealAudio ------------------------------------------------------------------------------------------------------------------------
local A=W.module('RarityRevealAudio');A.Preload()
local Seq=W.module('RarityRevealSequence')
do
 local function rv(name)return SS:FindFirstChild('Reveal_'..name)end
 local pop,note,impact,spark,whoosh,chime=rv('Pop'),rv('Note'),rv('Impact'),rv('Spark'),rv('Whoosh'),rv('Chime')
 A.Stop();A.Burst(1,Seq.SeedAt(1))
 check(pop.IsPlaying and near(pop.TimePosition,.10),'Common: the pop starts at its .1 s lead-in (it used to start at 0 and sound ~90 ms late) ('..tostring(pop.TimePosition)..')')
 check(near(pop.TimePosition,Timing.Offset(pop)),'it reads SoundTiming (the same offset a Bubble04 button click gets)')
 A.Stop();A.Burst(2,Seq.SeedAt(2));R.advance(.08)
 check(near(pop.TimePosition,.10) and note.IsPlaying,'Uncommon: the pop at .1 and the rising note .08 s later are two separate beats')
 A.Stop();A.Burst(3,Seq.SeedAt(3))
 check(near(spark.TimePosition,.04),'Rare: the spark skips the .04 s lead-in too')
 A.Stop();A.Begin(7,0)
 check(near(whoosh.TimePosition,.44),'the whoosh still starts at its .44 s lead-in (now from the shared table)')
 for _,rank in ipairs({4,5,6,7,8})do
  A.Stop();A.Begin(rank,0);A.Burst(rank,Seq.SeedAt(rank)+.1)
  check(impact.IsPlaying,'rank '..rank..': a burst .1 s after its seed moment still sounds')
 end
 for _,rank in ipairs({4,5,6,7,8})do
  A.Stop();E.resetPlays();A.Begin(rank,0);A.Burst(rank,Seq.SeedAt(rank)+2.0)
  check(not impact.IsPlaying and not chime.IsPlaying and not whoosh.IsPlaying,'rank '..rank..': a burst 2 s late (a stalled frame / a late RevealAt) is dropped')
 end
 A.Stop();A.Burst(7)
 check(impact.IsPlaying,'the old call shape (no time) still sounds')
 A.Stop();A.Burst(2,Seq.SeedAt(2)+.9);R.advance(.2)
 check(not pop.IsPlaying,'a late low-tier cue is still dropped')
end

-- 4. RevealFlourish (onlooker) + VeiledArrivalFx ---------------------------------------------------------------------------------------------
do
 local F=W.module('RevealFlourish');local holder=R.new('Model');holder.Parent=W.workspace
 local f=F.Create(holder,4,1);local at=Seq.SeedAt(4)
 f:Update(CF(0,2,0),at+.01,at,false)
 check(f.Sound==nil,'nobody hears a flourish that is not marked heard (the opener has its own)')
 f:Destroy()
 f=F.Create(holder,4,1);f:Update(CF(0,2,0),at+.01,at,true)
 check(f.Sound and f.Sound.IsPlaying and near(f.Sound.TimePosition,.04),'onlooker burst: the .04 s lead-in is skipped (it used to start from 0, ~35 ms late) ('..tostring(f.Sound and f.Sound.TimePosition)..')')
 check(f.Sound.SoundGroup==W.module('AudioMixer').Group('Effects'),'and it is on the Effects group')
 f:Destroy()
 local V=W.module('VeiledArrivalFx');V._Reset()
 local function arrive(serial,age)local s=V.Preload();s.Plays=0;s.PlayLog={};local now=1000;local ok=V.Arrive(serial,now-age,now);return ok,s end
 local ok,s=arrive(1,0)
 check(ok and s.Plays==1 and near(s.PlayLog[1].TimePosition,0),'on-time arrival: the sound starts at 0')
 ok,s=arrive(2,.8)
 check(ok and s.Plays==1 and near(s.PlayLog[1].TimePosition,.8),'a packet .8 s late: the sound joins .8 s in, like the lights-out ('..tostring(s.PlayLog[1]and s.PlayLog[1].TimePosition)..')')
 ok,s=arrive(3,1.4)
 check(ok and s.Plays==1 and near(s.PlayLog[1].TimePosition,1.4),'1.4 s late: 1.4 s in (still inside SoundMaxAge)')
 ok,s=arrive(4,1.6)
 check(ok and s.Plays==0,'older than SoundMaxAge: the lights come in part-way, no sound')
 timingScript:SetAttribute('Start_113339179211972',.25)
 ok,s=arrive(5,.5)
 check(ok and near(s.PlayLog[1].TimePosition,.75),'a measured lead-in is added to the age (.25 + .5)')
 timingScript:SetAttribute('Start_113339179211972',nil)
 V._Reset()
end

-- 5. LocalSfx ----------------------------------------------------------------------------------------------------------------------------------
do
 local Sfx=W.module('LocalSfx')
 check(Sfx.MaxAge==.25 and Sfx.WhooshId=='rbxassetid://9120768742','one-shots drop a cold file after .25 s; the whoosh id is shared')
 R.advance(1)
 local s=Sfx.Play(Sfx.WhooshId,nil,.2,1.4,2)
 check(s and s.IsPlaying and near(s.TimePosition,.44) and near(s.PlaybackSpeed,1.4),'the whoosh skips its .44 s lead-in (central table), at pitch 1.4')
 R.advance(1)
 s=Sfx.Play(Sfx.WhooshId,V3(1,2,3),.2,1,2,.1)
 check(s and near(s.TimePosition,.54),'a late-joining cue skips the elapsed time too (.44 + .1)')
 E.cold['rbxassetid://5551']=true;R.advance(1)
 local c=Sfx.Play('rbxassetid://5551',V3(0,0,0),.2,1,2)
 check(c and c.IsPlaying and not c.IsLoaded,'a cold one-shot is asked to play')
 R.advance(.2);E.load(c);check(c.IsPlaying,'loaded after .2 s: it plays')
 E.cold['rbxassetid://5552']=true;R.advance(1)
 c=Sfx.Play('rbxassetid://5552',V3(50,0,0),.2,1,2)
 R.advance(.3);E.load(c);check(not c.IsPlaying,'loaded after .3 s: dropped, never played late')
end

-- 6. ButtonHighlights: close names, ButtonSound, SeedMenu rule ---------------------------------------------------------------------------------
do
 local H=W.module('ButtonHighlights')
 local function button(name,attrs)
  local b=R.new('TextButton');b.Name=name;b.Active=true;for k,v in pairs(attrs or{})do b:SetAttribute(k,v)end
  b.Parent=pg;return b
 end
 local stop=H.Start(pg);local stopMenus=H.WatchMenus(pg)
 local function click(b)R.advance(1);E.resetPlays();b.Activated:Fire()end
 local close=button('Close');local closeButton=button('CloseButton');local gift=button('CloseGift');local plain=button('Plain')
 local custom=button('Gift',{ButtonSound='MenuClick'});local quiet=button('Quiet',{ButtonSound=false});local shade=button('Shade')
 click(close);check(played('MenuClose')==1 and played('Bubble04')==0,'a button named Close clicks MenuClose, not the generic click')
 click(closeButton);check(played('MenuClose')==1 and played('Bubble04')==0,'CloseButton too')
 click(gift);check(played('MenuClose')==1 and played('Bubble04')==0,'CloseGift too')
 click(plain);check(played('Bubble04')==1 and played('MenuClose')==0,'any other button keeps the Bubble04 default')
 click(custom);check(played('MenuClick')==1 and played('Bubble04')==0,'ButtonSound names the cue')
 click(quiet);check(E.totalPlays()==0,'ButtonSound=false is silent (read at click time)')
 click(shade);check(E.totalPlays()==0,'a Shade is not a button: the SeedMenu rule covers it')
 -- one rule for every SeedMenu path
 R.advance(1);E.resetPlays();pg:SetAttribute('SeedMenu','Index')
 check(played('MenuClick')==1,'a menu opening (nil -> Index) clicks MenuClick')
 R.advance(1);E.resetPlays();pg:SetAttribute('SeedMenu','Passes')
 check(played('MenuClick')==1 and played('MenuClose')==0,'switching menus (Index -> Passes) clicks MenuClick')
 R.advance(1);E.resetPlays();pg:SetAttribute('SeedMenu',nil)
 check(played('MenuClose')==1 and played('MenuClick')==0,'closing (Passes -> nil) clicks MenuClose')
 R.advance(1);E.resetPlays();pg:SetAttribute('SeedMenu',nil);check(E.totalPlays()==0,'no change, no sound')
 -- the same close from every input sounds the same, once: X button (its own click + the rule), shade tap, Esc, B, walking away, a script
 for _,path in ipairs({'X button','shade tap','Esc','B','walk away','auto close'})do
  R.advance(1);pg:SetAttribute('SeedMenu','Settings');R.advance(1);E.resetPlays()
  if path=='X button'then close.Activated:Fire()end
  pg:SetAttribute('SeedMenu',nil)
  check(played('MenuClose')==1 and played('Bubble04')==0 and E.totalPlays()==1,path..': exactly one MenuClose and nothing else ('..E.totalPlays()..' sounds)')
 end
 -- a button that opens a menu and names MenuClick (DAILY, nav) plus the rule's own click is still ONE sound
 R.advance(1);E.resetPlays();custom.Activated:Fire();pg:SetAttribute('SeedMenu','Daily')
 check(played('MenuClick')==1 and E.totalPlays()==1,'a DAILY-style button + the SeedMenu click is one MenuClick')
 pg:SetAttribute('SeedMenu',nil)
 stopMenus();R.advance(1);pg:SetAttribute('SeedMenu','Index');E.resetPlays();pg:SetAttribute('SeedMenu',nil)
 check(E.totalPlays()==0,'the watcher stops when told to')
 stop()
 for _,b in ipairs({close,closeButton,gift,plain,custom,quiet,shade})do b:Destroy()end
end

-- 7. Refusals click Denied -----------------------------------------------------------------------------------------------------------------------
local SimpleText=W.module('SimpleGameText')
do
 local Feed=W.module('NoticeFeed83')
 local orange=R.Color3.fromRGB(255,187,91)
 check(Feed.IsRefusal(SimpleText.Red,nil)==true,'the shared red is a refusal')
 check(Feed.IsRefusal(orange,nil)==false and Feed.IsRefusal(SimpleText.Green,nil)==false and Feed.IsRefusal(nil,nil)==false,'orange, green and no colour are not')
 check(Feed.IsRefusal(orange,'Denied')==true,'kind Denied is (colour alone is not enough: "HOLE COVERED" is orange news)')
 local folder=R.new('Folder');folder.Name='ChestChaseRemotes';folder.Parent=RS
 local remote=R.Instance.new('RemoteEvent');remote.Name='Notice83';remote.Parent=folder
 local sc=R.new('LocalScript');sc.Name='NotificationClient83';W.load('NotificationClient83',sc)
 local function frames(n)for _=1,n do W.frames(1,1/20)end end
 local function send(text,color,kind)R.advance(1);E.resetPlays();remote.OnClientEvent:Fire(text,color,2.5,kind);frames(3)end
 send('NEED MORE CASH!',SimpleText.Red)
 check(played('Denied')==1,'a red notice clicks Denied when its line appears')
 send('HOLE COVERED',orange)
 check(played('Denied')==0,'an orange news line does not')
 send('3s',orange,'Denied')
 check(played('Denied')==1,'a refusal the server marks Denied does (dig cooldown)')
 send('SOLD! +$40 💰',SimpleText.Green)
 check(played('Denied')==0,'a success does not')
 R.advance(1);E.resetPlays()
 for i=1,8 do remote.OnClientEvent:Fire('TOO CLOSE!'..i,SimpleText.Red,2,nil);frames(1)end
 check(played('Denied')<=3 and played('Denied')>=1,'a burst of refusals is rate-limited ('..played('Denied')..' sounds for 8 notices over .4 s)')
 -- the server half: NotificationService passes the kind through
 local sent={}
 local Notes=W.module('NotificationService')
 local n=Notes.new();n.Remote.FireClient=function(_,p,...)sent[#sent+1]={...}end
 local fake={Parent=true}
 n:Show(fake,'NOT ENOUGH CASH',orange,2,'Denied');n:Show(fake,'COVERED',orange,2)
 check(#sent==2 and sent[1][4]=='Denied' and sent[2][4]==nil,'NotificationService:Show forwards kind Denied (and nothing for a plain notice)')
end

-- 8. The HUD "Reopens in" row changes on the beep ----------------------------------------------------------------------------------------------
do
 local State=W.module('WorldStatusState');local Countdown=W.module('RefreshCountdown')
 local storage=R.new('Folder');local map=R.new('Folder')
 local endsAt=1000+5.31
 map:SetAttribute('BiomesRefreshing',true);map:SetAttribute('BiomeRefreshEndsAt',endsAt)
 local state=Countdown.New(endsAt);local seen={}
 local now=1000
 while now<endsAt+.1 do
  -- the server's whole-second attribute lags (it was written a moment ago), as in the live game
  map:SetAttribute('BiomeRefreshSeconds',math.ceil(endsAt-(now-.4)))
  local number=Countdown.Take(state,now)
  local _,track=State.Read(storage,map,nil,now)
  if number then seen[#seen+1]={Number=number,Left=track.Left,Time=track.Time}end
  now+=1/60
 end
 check(#seen==3,'three beeps (got '..#seen..')')
 for _,s in ipairs(seen)do check(s.Left==4-s.Number,'beep '..s.Number..': the row shows '..(4-s.Number)..' on the same frame (got '..tostring(s.Left)..')')end
 local _,track=State.Read(storage,map,nil,endsAt-.2)
 check(track.Left==1 and track.Time=='00:01','the last second shows 1 until the wall opens')
 map:SetAttribute('BiomeRefreshEndsAt',nil);map:SetAttribute('BiomeRefreshSeconds',7)
 _,track=State.Read(storage,map,nil,1000)
 check(track.Left==7,'without a deadline the server integer is the fallback')
 map:SetAttribute('BiomesRefreshing',false);map:SetAttribute('NextBiomeRefreshAt',1000+90)
 _,track=State.Read(storage,map,nil,1000)
 check(track.Closed==false and track.Left==90,'an open track still counts to its next reset')
end

-- 9. AudioMixer: routing and the saved mix ----------------------------------------------------------------------------------------------------------
do
 local Players=W.service('Players')
 local function fresh(name)local inst=R.new('ModuleScript');inst.Name=name;inst.Parent=RS;return W.load(name,inst)end
 -- 9a. the saved mix is applied as soon as the Player carries it (before any SettingsState)
 Players.LocalPlayer:SetAttribute('AudioEffects',0);Players.LocalPlayer:SetAttribute('AudioMusic',30)
 local Mixer=fresh('AudioMixer')
 check(Mixer.Get('Effects')==0 and Mixer.Get('Music')==30 and Mixer.Get('Chase')==100,'a Mixer made after the attributes arrived starts from the saved mix (Effects 0, Music 30)')
 check(Mixer.Group('Effects').Volume==0 and near(Mixer.Group('Music').Volume,.3),'its groups are set before SettingsState has answered')
 -- 9b. attributes arriving later still win until the player or SettingsState decides
 Players.LocalPlayer:SetAttribute('AudioAmbience',55)
 check(Mixer.Get('Ambience')==55 and near(Mixer.Group('Ambience').Volume,.55),'an attribute that arrives later is applied too')
 Mixer.Set('Ambience',20);Players.LocalPlayer:SetAttribute('AudioAmbience',90)
 check(Mixer.Get('Ambience')==20,'once the player (or SettingsState) has set a group, the attribute no longer overrides it')
 Players.LocalPlayer:SetAttribute('AudioChase',500)
 check(Mixer.Get('Chase')==100,'an invalid attribute is ignored')
 -- a brand-new player (no attributes) is not silenced
 local blank=R.new('Player');blank.Name='New';Players.LocalPlayer=blank
 local M2=fresh('AudioMixer');check(M2.Get('Effects')==100 and M2.Get('Music')==100 and M2.Group('Music').Volume==1,'no saved mix (first-time player): everything at the defaults, nothing muted')
 Players.LocalPlayer=E.Player
 -- 9c. characters that exist before Start() are routed to Effects (jump / land sounds); Effects 0 mutes them
 local other=R.new('Player');other.Name='Other';other.Parent=Players
 local oc=R.new('Model');oc.Name='Other';oc.Parent=W.workspace;other.Character=oc
 local jump=R.Instance.new('Sound');jump.Name='Jumping';jump.Parent=oc
 local land=R.Instance.new('Sound');land.Name='Landing';land.Parent=E.char
 check(jump.SoundGroup==nil and land.SoundGroup==nil,'(before Start nothing is routed)')
 Mixer.Start()
 local effects=Mixer.Group('Effects')
 check(jump.SoundGroup==effects and land.SoundGroup==effects,'Start() routes the sounds of characters that already exist (yours and other players\') to Effects')
 check(effects.Volume==0,'and Effects 0 (saved) silences them: the group volume is 0')
 local late=R.Instance.new('Sound');late.Name='Splash';late.Parent=oc
 check(late.SoundGroup==effects,'sounds added later are routed as before')
 -- 9d. the keeper snore is routed where it is made, whether or not Start() has run
 local Sleep=fresh('KeeperSleep')
 local part=R.new('Part');part.Name='KeeperRoot';part.Parent=W.workspace
 local config={Bounds={Head={{0,0,0},{2,2,2}}}}
 local keeper=Sleep.new(part,2,config)
 check(keeper.Sound.SoundGroup~=nil and keeper.Sound.SoundGroup.Name=='GardenEffects','the keeper snore is on the Effects group the moment it is made')
 Mixer.Set('Effects',0)
 check(keeper.Sound.SoundGroup.Volume==0,'Effects 0 mutes the snore (group volume 0)')
 Mixer.Set('Effects',70);check(near(keeper.Sound.SoundGroup.Volume,.7),'and Effects 70 gives it back at 70%')
 keeper:Destroy()
end

print(('R150 cue checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
