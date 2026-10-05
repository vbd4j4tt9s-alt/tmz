--!nocheck
-- R151 sounds of the pull announcements with the REAL RarityRevealAudio / SoundTiming / AudioMixer on the Roblox mock (like R150's test_bonus_audio): New Sounds start cold
-- (not loaded) and load 0.1 s after creation or 0.05 s after ContentProvider:PreloadAsync; every :Play() is recorded with whether the sound was loaded at that moment.
--  * the banner of someone else's Mythic pull sounds the Mythic reveal burst (impact + chime) through the Effects group, on the frame the banner appears
--  * Secret / Cosmic are louder, King adds the royal fanfare; a Legendary pull gets the Legendary burst; a record the Mythic one; an other-server pull only a quiet chime
--  * your own pull is silent (you just heard it); Effects at 0 is silent: the client does not even ask, and the group is at 0 anyway
--  * a cold voice is dropped, never played late; one burst per banner
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=1000;me.Parent=Players;Players.LocalPlayer=me;function Players.GetPlayers()return {me}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local SS=W.service('SoundService')
UW.audio={Plays={},Preloads={}}
local audio=UW.audio
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(1280,720)end
 if class=='Sound'then
  local sound=o;sound.IsLoaded=false;sound.Loaded=R.signal();sound.IsPlaying=false;sound.TimeLength=1;sound.TimePosition=0
  function sound.Play()sound.IsPlaying=true;audio.Plays[#audio.Plays+1]={Name=sound.Name,At=R.clock,Loaded=sound.IsLoaded,Pitch=sound.PlaybackSpeed,Group=sound.SoundGroup,Volume=sound.Volume}end
  function sound.Stop()sound.IsPlaying=false end
  R.task.delay(.1,function()if not sound._destroyed and not sound.IsLoaded then sound.IsLoaded=true;sound.Loaded:Fire()end end)
 end
 return o end;W.env.Instance=R.Instance end
local Content=W.service('ContentProvider')
function Content.PreloadAsync(_,list)
 audio.Preloads[#audio.Preloads+1]=table.clone(list)
 local items=table.clone(list)
 R.task.delay(.05,function()for _,sound in ipairs(items)do if not sound._destroyed and not sound.IsLoaded then sound.IsLoaded=true;sound.Loaded:Fire()end end end)
end
W.stub('ItemPictures',{Show=function()end,Clear=function()end,Warm=function()end})
W.stub('ClientFxBudget',{Get=function()return 3 end})
W.service('TextChatService');W.service('StarterGui').SetCore=function()end
function Players.GetUserThumbnailAsync(_,id)return 'rbxthumb://'..id,true end
local Rules=W.module('PullAnnounceRules');local Packs=W.module('SeedPackRules');local Mixer=W.module('AudioMixer')
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';remote.OnClientEvent=R.signal();remote.Parent=remotes
local function seconds(s)UW.seconds(s,1/60)end
local function seedOf(rarity)for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)==rarity then return spec.id end end end
local serial=0
local function send(kind,seed,extra)
 serial+=1;local p={Kind=kind,Id='a-'..serial,UserId=2000+serial,Name='Ann'..serial,SeedId=seed,Odds=800,Size=1}
 for k,v in pairs(extra or{})do p[k]=v end
 remote.OnClientEvent:Fire(p)
end
local function plays(from)local out={};for i=from,#audio.Plays do out[#out+1]=audio.Plays[i]end;return out end
local function names(list)local out={};for _,p in ipairs(list)do out[#out+1]=p.Name:gsub('^Reveal_','')end;return table.concat(out,',')end
local script=R.new('LocalScript');script.Name='PullAnnouncerClient';W.load('PullAnnouncerClient',script)
-- 1. a cold voice is dropped, not played late ----------------------------------------------------------------------------------------------------------
local voices={};for _,s in ipairs(SS:GetChildren())do if s.Name:match('^Reveal_')then voices[#voices+1]=s end end
check(#voices==8,'the reveal voices were made at script start ('..#voices..')')
local routed=true;for _,s in ipairs(voices)do if not(s.SoundGroup and s.SoundGroup.Name=='GardenEffects')then routed=false end end
check(routed,'every reveal voice is routed through the Effects group')
local coldAtStart=true;for _,s in ipairs(voices)do if s.IsLoaded then coldAtStart=false end end
check(coldAtStart,'(they are still loading at that moment, like a fresh join)')
local m0=#audio.Plays+1
send('Pull',seedOf('Mythic'));seconds(.05)
check(#plays(m0)==0,'a pull announced while the voices are still cold: no sound at all (nothing plays late)')
seconds(4.6)
local loaded=true;for _,s in ipairs(voices)do if not s.IsLoaded then loaded=false end end
check(loaded and#plays(m0)==0,'... and nothing plays retroactively once they have loaded')
-- 2. the burst per rarity -----------------------------------------------------------------------------------------------------------------------------
local function burst(kind,seed,extra)
 local from=#audio.Plays+1;local at=R.clock
 send(kind,seed,extra)
 local list=plays(from)
 seconds(4.6)
 return list,at
end
local list,at=burst('Pull',seedOf('Mythic'))
check(names(list)=='Impact,Chime','Mythic: the impact and the chime ('..names(list)..')')
check(#list==2 and list[1].At==at and list[1].Loaded and list[2].Loaded,'... on the frame the banner appears (no delay, loaded voices)')
check(list[1].Group and list[1].Group.Name=='GardenEffects'and list[2].Group.Name=='GardenEffects','... through the Effects group')
check(list[1].Pitch==1.05 and list[2].Pitch==.75,'... the Mythic pitches (impact 1.05, chime .75)')
list=burst('Pull',seedOf('Legendary'))
check(names(list)=='Impact,Chime'and list[1].Pitch==1.3 and list[2].Pitch==1.15,'Legendary: its own, higher-pitched burst ('..names(list)..', '..tostring(list[1]and list[1].Pitch)..')')
local sec=burst('Pull',seedOf('Secret'))
check(names(sec)=='Impact'and sec[1].Volume>=.3 and sec[1].Pitch==1.15,'Secret: one loud impact (volume '..tostring(sec[1]and sec[1].Volume)..')')
local cos=burst('Pull',seedOf('Cosmic'))
check(names(cos)=='Impact'and cos[1].Volume>=.34 and cos[1].Volume>sec[1].Volume,'Cosmic: louder still ('..tostring(cos[1]and cos[1].Volume)..')')
local king=burst('Pull',seedOf('King'))
check(names(king)=='Impact,Royal,Spark'and king[1].Volume>=.36,'King: impact, royal fanfare and spark ('..names(king)..')')
local rec=burst('Record',seedOf('Mythic'),{Record='BestPull'})
check(names(rec)=='Impact,Chime'and rec[1].Pitch==1.05,'a record: the Mythic fanfare ('..names(rec)..')')
local glob=burst('Global',seedOf('Secret'))
check(names(glob)=='Chime'and math.abs(glob[1].Volume-.09)<1e-9 and math.abs(glob[1].Pitch-.9)<1e-9,'another server: just a quiet chime (volume '..tostring(glob[1]and glob[1].Volume)..', pitch '..tostring(glob[1]and glob[1].Pitch)..')')
-- 3. your own pull and Effects 0 ---------------------------------------------------------------------------------------------------------------------
local own=burst('Pull',seedOf('King'),{UserId=me.UserId})
check(#own==0,'your own pull: the banner and the chat line, no sound (you just heard the reveal)')
Mixer.Set('Effects',0)
check(Mixer.Group('Effects').Volume==0,'Effects at 0: the group is silent')
local muted=burst('Pull',seedOf('King'))
check(#muted==0,'... and the announcement does not even ask for a sound')
Mixer.Set('Effects',35)
local quiet=burst('Pull',seedOf('Mythic'))
check(names(quiet)=='Impact,Chime'and quiet[1].Group.Volume==.35,'Effects at 35: the burst plays through a group at .35')
Mixer.Set('Effects',100)
-- one burst per banner, in a queue
local from=#audio.Plays+1
send('Pull',seedOf('Secret'));send('Pull',seedOf('Mythic'));send('Pull',seedOf('Legendary'))
seconds(1)
check(#plays(from)==1,'three announcements at once: the first banner sounds, the others wait their turn ('..#plays(from)..' sound now)')
seconds(3.6)
check(#plays(from)==3,'... the second when its banner shows (Secret impact + the Mythic pair = 3 plays, '..#plays(from)..')')
seconds(4.5)
local total=#plays(from)
check(total==5,'all three banners sounded in turn: Secret impact, Mythic impact + chime, Legendary impact + chime = 5 plays ('..total..')')
seconds(5)
check(UW.frameListeners()==0,'idle afterwards')
script:Destroy()
print(('R151 audio: %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
