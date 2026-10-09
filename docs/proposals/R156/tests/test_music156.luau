--!nocheck
-- R156 (owner: "for the track ambience and pre existing music we can just increase the volume by a bit and add these sound tracks 74095461107598, 132448918728086, that
-- alternate. for base music we can add these tracks 1837487700, 1837487818, 1836280952."). On the Roblox mock with the REAL BackgroundMusic and the REAL BiomeMood of this
-- checkout. The mock gets what BackgroundMusic needs to be heard in time: sounds that play (their TimePosition runs, a non-looped one ends, Pause / Resume / Stop),
-- tweens that run on the mock clock (quad in-out, Completed fires, Cancel stops), and a task.wait that really waits.
--  A. the track playlist: Nature Inspiration -> 74095461107598 -> 132448918728086 -> Nature Inspiration ..., each played once to its end; the next one starts PLAYLIST_CROSSFADE_SECONDS
--     (3 s) before the end and the two cross over (quad in-out: the sum never above the track volume); the old one is stopped and rewound; all three at .07; all named
--     BiomeScenicMusic, in the Music SoundGroup; fade in on entering, fade out and pause on leaving.
--  B. leaving and coming back: the same track resumes at its position (Resume, not Play), also when it was left in the middle of a crossfade (the incoming track is the one that
--     resumes); the character removed / added; the track music is silent while the chase music plays, and comes back where it was.
--  C. a track that fails to load is skipped with the warning (once per minute), the first track failing starts the list at the second, a late loader joins the rotation, one
--     track alone loops, none loaded = silence, no warning flood and the base music untouched.
--  D. the base: PEACEFUL_PLAYLIST holds 5 tracks (the 3 new ids last), all rotate in order with the crossfade, a base track that fails to load is skipped; PEACEFUL_VOLUME .2, the chase
--     volumes and the base music behind the track music as before.
--  E. the track ambience: BiomeMood.SoundTargets x1.25 on the track stages 1-7 (spelled out, and against the old formula in every combination), stage 0 / weather beds / chase / refresh rules
--     as before.
--  F. nothing is created while idle: no Instance, no tween, no task in 300 idle frames on the track, in the base, left, in a chase; the 0.1 s step has no table / closure in its code; the
--     clean-up on destroy.
local W=require('./world');local E=require('./sfx_env')(W);local R=W.R
local CF=R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local SS=W.service('SoundService');local Run=W.service('RunService');local Players=W.service('Players')

local ID={'rbxassetid://96110001912212','rbxassetid://74095461107598','rbxassetid://132448918728086'}
local LEN={[ID[1]]=40,[ID[2]]=50,[ID[3]]=60} -- the test lengths of the three track files (the real ones are minutes long; the logic only needs >> 3 s)
local BASE_OLD={'rbxassetid://1846088038','rbxassetid://1844513698'}
local BASE_NEW={'rbxassetid://1837487700','rbxassetid://1837487818','rbxassetid://1836280952'}
local BASE_ALL={BASE_OLD[1],BASE_OLD[2],BASE_NEW[1],BASE_NEW[2],BASE_NEW[3]}
local CHASE_ID,SPECIAL_ID='rbxassetid://90864299965930','rbxassetid://127003062753525'
local FILELEN={[CHASE_ID]=92,[SPECIAL_ID]=190}
for id,n in pairs(LEN)do FILELEN[id]=n end
local baseLen=400 -- the length given to the five base files (shorter in D, so that they rotate)
local VOL=.07;local CROSS=3

-- ======================================================================================================================
-- the mock: playing sounds, timed tweens, a task.wait that waits
-- ======================================================================================================================
do local inew=R.Instance.new -- (E's wrapper: Play log, Ended / Loaded signals, cold files) + Pause / Resume / Stop with their states, and the length of a file by its id
 R.Instance.new=function(class,parent)
  local o=inew(class,parent)
  if class=='Sound'then
   o.IsPaused=false
   local play=o.Play;o.Play=function(self)self.IsPaused=false;return play(self)end
   o.Stop=function(self)self.IsPlaying=false;self.IsPaused=false;self.TimePosition=0;self.Stops=(self.Stops or 0)+1 end
   o.Pause=function(self)if self.IsPlaying then self.IsPlaying=false;self.IsPaused=true;self.Pauses=(self.Pauses or 0)+1 end end
   o.Resume=function(self)if self.IsPaused then self.IsPaused=false;self.IsPlaying=true;self.Resumes=(self.Resumes or 0)+1 end end
   o.Changed:Connect(function(k)
    if k=='SoundId'then local n=FILELEN[o.SoundId]or(table.find(BASE_ALL,o.SoundId)and baseLen);if n then o.TimeLength=n end end
   end)
  end
  return o
 end
end
local createdTweens,taskCalls=0,0
do
 local active={}
 local function ease(a)if a<.5 then return 2*a*a end;return 1-(-2*a+2)^2/2 end
 local function finish(tw,state)
  active[tw]=nil;tw.State=state
  tw.Completed:Fire(state)
  local list=tw._waiters;tw._waiters={}
  for _,co in ipairs(list)do coroutine.resume(co)end
 end
 W.service('TweenService').Create=function(_,obj,info,props)
  createdTweens+=1
  local tw={Completed=R.signal(),_waiters={},_t=0,State='Idle'}
  function tw.Completed:Wait()if coroutine.isyieldable()then local w=tw._waiters;w[#w+1]=coroutine.running();coroutine.yield()end end
  function tw:Play()
   self._from={};for k in pairs(props)do self._from[k]=obj[k]end;self._t=0;self.State='Playing';active[self]=true
   if info.Time<=0 then for k,v in pairs(props)do obj[k]=v end;finish(self,'Completed')end
  end
  function tw:Cancel()if active[self]then finish(self,'Cancelled')end end
  tw._step=function(dt)
   tw._t+=dt;local a=math.min(1,tw._t/info.Time)
   for k,v in pairs(props)do obj[k]=a>=1 and v or tw._from[k]+(v-tw._from[k])*ease(a)end
   if a>=1 then finish(tw,'Completed')end
  end
  return tw
 end
 Run.Heartbeat:Connect(function(dt) -- (connected before the script, so a frame's time runs first)
  local list={};for tw in pairs(active)do list[#list+1]=tw end
  for _,tw in ipairs(list)do if active[tw]then tw._step(dt)end end
  for _,s in ipairs(E.sounds)do
   if s.IsPlaying and s.Parent then
    s.TimePosition+=dt*s.PlaybackSpeed
    if s.TimePosition>=s.TimeLength then
     if s.Looped then s.TimePosition-=s.TimeLength else s.IsPlaying=false;s.TimePosition=0;s.Ended:Fire()end
    end
   end
  end
 end)
end
do -- a task.wait that yields until the mock clock has moved; every task call is counted (F: nothing while idle)
 local realTask=W.env.task
 W.env.task=setmetatable({
  wait=function(t)
   local co=coroutine.running()
   if co and coroutine.isyieldable()then R.task.delay(t or .03,function()coroutine.resume(co)end);coroutine.yield();return t or .03 end
   R.advance(t or .03);return t or .03
  end,
  spawn=function(...)taskCalls+=1;return realTask.spawn(...)end,
  delay=function(...)taskCalls+=1;return realTask.delay(...)end,
  defer=function(...)taskCalls+=1;return realTask.defer(...)end,
 },{__index=realTask})
end
local warns={}
W.env.warn=function(...)local p={};for i=1,select('#',...)do p[i]=tostring((select(i,...)))end;warns[#warns+1]=table.concat(p,' ')end
local function warnsAbout(text)local n=0;for _,w in ipairs(warns)do if w:find(text,1,true)then n+=1 end end;return n end

-- the world: a player on a character, and the track (z > the base boundary line)
E.player('Tester');local player=E.Player
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local lobby=R.new('Folder');lobby.Name='Lobby';lobby.Parent=map
local line=R.new('Part');line.Name='BaseBoundaryLine';line.CFrame=CF(0,0,0);line.Parent=lobby
local BASE_Z,TRACK_Z=-60,60
local function goTrack()E.root.CFrame=CF(0,3,TRACK_Z)end
local function goBase()E.root.CFrame=CF(0,3,BASE_Z)end
local function run(seconds)W.frames(math.floor(seconds*30+.5),1/30)end
local function runUntil(cond,maxSeconds) -- steps 1/30 s frames until cond(); returns the seconds it took, or nil
 local t=0;while t<maxSeconds do if cond()then return t end;W.frames(1,1/30);t+=1/30 end
 if cond()then return t end;return nil
end

-- ======================================================================================================================
-- boot: a fresh BackgroundMusic (the old one destroyed), the files in "cold" as given
-- ======================================================================================================================
local bm,bootMark=nil,0 -- (E.sounds keeps every Sound ever made: bootMark is how many there were before this boot)
local function named(name)local out={};for i=bootMark+1,#E.sounds do if E.sounds[i].Name==name then out[#out+1]=E.sounds[i]end end;return out end
local function boot(opts)
 opts=opts or{}
 if bm then bm.Destroying:Fire();bm=nil end
 player:SetAttribute('ChestChaseRunActive',false);player:SetAttribute('SpecialKeeperChase84',false)
 table.clear(E.cold);for id in pairs(opts.cold or{})do E.cold[id]=true end
 baseLen=opts.baseLen or 400
 table.clear(warns);goBase();bootMark=#E.sounds
 bm=R.new('LocalScript');bm.Name='BackgroundMusic'
 W.load('BackgroundMusic',bm)
 W.frames(3,1/30)
end
local function scenicSounds() -- the BiomeScenicMusic sounds in SoundService, in the order they were made
 local out={};for _,c in ipairs(SS:GetChildren())do if c.Name=='BiomeScenicMusic'then out[#out+1]=c end end;return out
end
local function indexOf(sound)for i,id in ipairs(ID)do if sound.SoundId==id then return i end end end
local function trackSound(i)for _,s in ipairs(scenicSounds())do if s.SoundId==ID[i]then return s end end end
local function volumes()local v={};for i=1,3 do local s=trackSound(i);v[i]=s and s.Volume or-1 end;return v end
local function playingTracks()local out={};for i=1,3 do local s=trackSound(i);if s and s.IsPlaying then out[#out+1]=i end end;return out end
local function playOrder() -- every Play() call on a track sound, in time order: {track, at, position}
 local calls={};for _,s in ipairs(named('BiomeScenicMusic'))do for _,p in ipairs(s.PlayLog)do calls[#calls+1]={Track=indexOf(s),At=p.At,Pos=p.TimePosition}end end
 table.sort(calls,function(a,b)return a.At<b.At end);return calls
end
local function orderText(calls)local t={};for _,c in ipairs(calls)do t[#t+1]=tostring(c.Track)end;return table.concat(t,',')end
local function baseSound()for _,s in ipairs(named('ChestChaseBackgroundMusic'))do if s.Parent and s.IsPlaying then return s end end end
local function chase()return SS:FindFirstChild('ChestChaseActionTrack')end

-- ======================================================================================================================
-- A. the track playlist
-- ======================================================================================================================
print('-- A. the track playlist')
boot();run(4)
do
 local sounds=scenicSounds()
 check(#sounds==3,'three BiomeScenicMusic sounds, one per track: '..#sounds)
 local ids={};for i,s in ipairs(sounds)do ids[i]=s.SoundId end
 check(table.concat(ids,' ')==table.concat(ID,' '),'in the owner\'s order: Nature Inspiration (96110001912212), 74095461107598, 132448918728086')
 local group=SS:FindFirstChild('ChestChaseMusic');check(group~=nil and group:IsA('SoundGroup'),'the Music SoundGroup (ChestChaseMusic) exists')
 local allGroup,allLoop,allQuiet=true,true,true
 for _,s in ipairs(sounds)do
  if s.SoundGroup~=group then allGroup=false end
  if s.Looped~=false then allLoop=false end
  if s.Volume~=0 or s.IsPlaying then allQuiet=false end
 end
 check(allGroup,'all three are routed to the same SoundGroup as the base music (ChestChaseMusic)')
 check(allLoop,'none loops by itself: each plays once to its end (the list loops)')
 check(allQuiet,'silent and not playing in the base')
 local mixer=W.module('AudioMixer');local ok=true
 for _,s in ipairs(sounds)do local g=s.SoundGroup;mixer.Route(s);if s.SoundGroup~=g or s.SoundGroup~=group then ok=false end end
 check(ok,'AudioMixer.Route maps the name BiomeScenicMusic to the same Music group for each of them (the Music slider)')
 check(sounds[1]:GetAttribute('TrackName')=='Nature Inspiration','track 1 is named Nature Inspiration')
 check(baseSound()~=nil and near(baseSound().Volume,.2),'the base music plays at .2 in the base ('..tostring(baseSound()and baseSound().Volume)..')')
 check(#named('ChestChaseBackgroundMusic')>=1 and warnsAbout('Music not ready')==0,'nothing to warn about when every file loads')
end
-- enter the track
goTrack()
run(.6)
do
 local v=volumes();local pl=playingTracks()
 check(#pl==1 and pl[1]==1,'entering the track starts Nature Inspiration (track 1) and only it: '..table.concat(pl,','))
 check(v[1]>0 and v[1]<VOL,'it fades in (0.6 s in: '..string.format('%.4f',v[1])..' of '..VOL..')')
 check(v[2]==0 and v[3]==0,'the other two stay silent')
 check(baseSound()==nil or baseSound().Volume<.2,'the base music fades away behind it')
end
run(1.4)
do
 local v=volumes()
 check(near(v[1],VOL,1e-9),'track 1 fades in to .07 ('..v[1]..')')
 check(baseSound()==nil or baseSound().Volume==0,'the base music is silent on the track')
end
-- track 1 -> 2: the crossfade starts 3 s before the end of track 1
local t1=trackSound(1);local t2=trackSound(2);local t3=trackSound(3)
local startAt2=runUntil(function()return t2.IsPlaying end,LEN[ID[1]]+5)
check(startAt2~=nil,'track 2 starts by itself')
do
 local calls=playOrder()
 check(#calls==2 and calls[2].Track==2,'the second Play() is track 2 (order so far: '..orderText(calls)..')')
 check(t1.IsPlaying and math.abs(t1.TimePosition-(LEN[ID[1]]-CROSS))<=.25,('track 2 starts when track 1 has 3 s left (track 1 at %.2f of %d s)'):format(t1.TimePosition,LEN[ID[1]]))
 check(calls[2].Pos==0,'track 2 starts from 0')
 -- the crossfade: both play, the sum is the track volume at every frame, mid-way each is half
 local maxSum,minSum,frames=0,1,0
 local mid1,mid2
 for f=1,math.floor(CROSS*30)+3 do
  W.frames(1,1/30);local v=volumes();local sum=v[1]+v[2];frames+=1
  if f>=2 and f<=math.floor(CROSS*30)-2 then maxSum=math.max(maxSum,sum);minSum=math.min(minSum,sum)end
  if f==math.floor(CROSS*30/2)then mid1,mid2=v[1],v[2];check(t1.IsPlaying and t2.IsPlaying,'both play in the middle of the crossfade')end
 end
 check(maxSum<=VOL+1e-6 and minSum>=VOL-1e-6,('the two volumes add up to .07 all through the crossfade (no dip, no bump: %.5f..%.5f)'):format(minSum,maxSum))
 check(mid1 and near(mid1,VOL/2,.004)and near(mid2,VOL/2,.004),('mid-way each is about half ('..tostring(mid1)..' / '..tostring(mid2)..')'))
 run(.3)
 check(not t1.IsPlaying and not t1.IsPaused and t1.TimePosition==0 and t1.Volume==0,'track 1 is stopped and rewound when its crossfade is over')
 check(t2.IsPlaying and near(t2.Volume,VOL,1e-9),'track 2 plays at .07')
 check(#playingTracks()==1,'one track plays')
end
-- 2 -> 3
runUntil(function()return t3.IsPlaying end,LEN[ID[2]]+5)
check(t3.IsPlaying and t2.IsPlaying and math.abs(t2.TimePosition-(LEN[ID[2]]-CROSS))<=.25,('track 3 starts when track 2 has 3 s left (track 2 at %.2f of %d s)'):format(t2.TimePosition,LEN[ID[2]]))
run(CROSS+.4)
check(not t2.IsPlaying and t2.TimePosition==0 and t3.IsPlaying and near(t3.Volume,VOL,1e-9),'track 2 is stopped, track 3 plays at .07')
-- 3 -> 1 (and the list is a loop)
runUntil(function()return t1.IsPlaying end,LEN[ID[3]]+5)
check(t1.IsPlaying and t3.IsPlaying and math.abs(t3.TimePosition-(LEN[ID[3]]-CROSS))<=.25,('after track 3 the list goes back to track 1 (track 3 at %.2f of %d s)'):format(t3.TimePosition,LEN[ID[3]]))
run(CROSS+.4)
check(near(t1.Volume,VOL,1e-9)and not t3.IsPlaying and t1.TimePosition>0 and t1.TimePosition<CROSS+1,'track 1 plays again from its start, track 3 is stopped')
do
 local calls=playOrder();local ord=orderText(calls)
 check(ord=='1,2,3,1','the order of the Play() calls is 1,2,3,1: '..ord)
 local gaps={};for i=2,#calls do gaps[#gaps+1]=calls[i].At-calls[i-1].At end
 check(near(gaps[1],LEN[ID[1]]-CROSS,.25)and near(gaps[2],LEN[ID[2]]-CROSS,.25)and near(gaps[3],LEN[ID[3]]-CROSS,.25),
  ('each next one starts (length - 3 s) after the one before: %.1f / %.1f / %.1f s'):format(gaps[1],gaps[2],gaps[3]))
end
-- a second lap: 1 -> 2 again
runUntil(function()return t2.IsPlaying end,LEN[ID[1]]+5);run(CROSS+.4)
check(t2.IsPlaying and not t1.IsPlaying and near(t2.Volume,VOL,1e-9)and orderText(playOrder())=='1,2,3,1,2','a second lap goes on with track 2 (order: '..orderText(playOrder())..')')

-- ======================================================================================================================
-- B. leaving, coming back, the chase
-- ======================================================================================================================
print('-- B. leaving, coming back, the chase')
do
 run(10);local pos=t2.TimePosition;local playsBefore=t2.Plays;local resumesBefore=t2.Resumes or 0
 goBase();run(.5)
 local v=volumes()
 check(v[2]>0 and v[2]<VOL and t2.IsPlaying,'leaving the track: the track music fades out (0.5 s in: '..string.format('%.4f',v[2])..')')
 run(1.5)
 check(t2.Volume==0 and t2.IsPaused and not t2.IsPlaying,'... and pauses at 0')
 check(near(t2.TimePosition,pos+.5+0,.8),('(paused at its position: %.2f, left at %.2f)'):format(t2.TimePosition,pos))
 local held=t2.TimePosition
 check(#playingTracks()==0 and not t1.IsPaused and not t3.IsPaused and t1.TimePosition==0 and t3.TimePosition==0,'the other two are untouched (stopped at 0)')
 check(baseSound()~=nil and near(baseSound().Volume,.2,.01),'the base music is back at .2 ('..tostring(baseSound()and baseSound().Volume)..')')
 run(30)
 check(t2.TimePosition==held and t2.IsPaused,'30 s later it is still paused at the same position')
 goTrack();run(.5)
 check(t2.IsPlaying and not t2.IsPaused and t2.Plays==playsBefore and (t2.Resumes or 0)==resumesBefore+1,'coming back resumes the same track (Resume(), no new Play())')
 check(t2.TimePosition>=held and t2.TimePosition<=held+1.2,('... at its position (%.2f, was %.2f)'):format(t2.TimePosition,held))
 run(1.7)
 check(near(t2.Volume,VOL,1e-9)and #playingTracks()==1,'... and fades in to .07')
 check(baseSound()==nil or baseSound().Volume==0,'(the base music is silent again)')
end
-- the chase takes over and gives back
do
 local pos=t2.TimePosition
 player:SetAttribute('ChestChaseRunActive',true);run(.3)
 check(t2.Volume<VOL and t2.Volume>0,'a chase starts: the track music fades (0.3 s in: '..string.format('%.4f',t2.Volume)..')')
 run(1.2)
 local ch=chase()
 check(t2.Volume==0 and t2.IsPaused,'... to 0 and pauses')
 check(ch and ch.IsPlaying and near(ch.Volume,.10,1e-6),'the chase theme plays at .10 ('..tostring(ch and ch.Volume)..')')
 check(near(t2.TimePosition,pos+1.5,.8),'(the track music kept its position)')
 run(5);local held=t2.TimePosition
 player:SetAttribute('ChestChaseRunActive',false);run(3)
 check(t2.IsPlaying and near(t2.Volume,VOL,1e-9)and t2.TimePosition>=held,'the chase ends: the track music resumes where it was at .07')
 check(ch.Volume==0 and not ch.IsPlaying,'... and the chase theme is silent and paused')
 -- a secret keeper chase (The Darkened) takes over just the same
 player:SetAttribute('SpecialKeeperChase84',true);player:SetAttribute('ChestChaseRunActive',true);run(2)
 check(t2.Volume==0 and t2.IsPaused,'a Darkened chase silences it too')
 player:SetAttribute('ChestChaseRunActive',false);player:SetAttribute('SpecialKeeperChase84',false);run(3)
 check(t2.IsPlaying and near(t2.Volume,VOL,1e-9),'... and gives it back')
 -- a chase that starts while the player is in the base does not touch the track music
 goBase();run(3);player:SetAttribute('ChestChaseRunActive',true);run(2);player:SetAttribute('ChestChaseRunActive',false);run(2)
 check(t2.IsPaused and t2.Volume==0,'a chase in the base leaves the (paused) track music alone')
 goTrack();run(3)
 check(t2.IsPlaying and near(t2.Volume,VOL,1e-9),'(and it resumes on the track)')
end
-- the character removed and added
do
 local held=t2.TimePosition
 player.CharacterRemoving:Fire();run(2)
 check(t2.Volume==0 and t2.IsPaused,'the character is removed: the track music fades out and pauses')
 player.CharacterAdded:Fire();run(3)
 check(t2.IsPlaying and near(t2.Volume,VOL,1e-9)and t2.TimePosition>=held,'the character is back on the track: it resumes at .07')
end
-- left in the middle of a crossfade: the incoming track is the one that resumes
do
 runUntil(function()return t3.IsPlaying end,LEN[ID[2]]+5);run(1.5)
 check(t2.IsPlaying and t3.IsPlaying and t2.Volume>0 and t3.Volume>0,'(in the middle of the 2 -> 3 crossfade)')
 goBase();run(3)
 check(t3.IsPaused and t3.Volume==0 and t3.TimePosition>.5,'left in the middle of a crossfade: the incoming track 3 is paused where it was ('..string.format('%.2f',t3.TimePosition)..')')
 check(not t2.IsPlaying and not t2.IsPaused and t2.TimePosition==0 and t2.Volume==0,'... and the outgoing track 2 is faded out, stopped and rewound')
 local held=t3.TimePosition;run(10)
 goTrack();run(3)
 check(t3.IsPlaying and near(t3.Volume,VOL,1e-9)and t3.TimePosition>=held and t3.TimePosition<=held+3.2,'coming back resumes track 3 at its position')
 check(#playingTracks()==1 and orderText(playOrder())=='1,2,3,1,2,3','(and exactly one more Play() was made: '..orderText(playOrder())..')')
 -- a chase in the middle of the next crossfade (3 -> 1), then the end of the chase
 runUntil(function()return t1.IsPlaying end,LEN[ID[3]]+5);run(1)
 player:SetAttribute('ChestChaseRunActive',true);run(2)
 check(t1.IsPaused and t1.Volume==0 and not t3.IsPlaying,'a chase in the middle of the 3 -> 1 crossfade: track 1 is the one left paused, track 3 is stopped')
 player:SetAttribute('ChestChaseRunActive',false);run(3)
 check(t1.IsPlaying and near(t1.Volume,VOL,1e-9)and #playingTracks()==1,'... and track 1 resumes when the chase is over')
end

-- ======================================================================================================================
-- C. a track that does not load
-- ======================================================================================================================
print('-- C. a track that does not load')
do -- track 2 never loads
 boot({cold={[ID[2]]=true}});local t0=R.clock;goTrack();run(.5)
 local a,b,c=trackSound(1),trackSound(2),trackSound(3)
 check(a.IsPlaying and not b.IsPlaying,'(track 1 plays at once, track 2 is still loading)')
 run(15)
 check(warnsAbout('74095461107598')==1 and warnsAbout('Track music 74095461107598')==1,'the failed track warns once, by name and id: '..(warns[1]or'(no warning)'))
 runUntil(function()return c.IsPlaying end,LEN[ID[1]]+5);run(CROSS+.4)
 check(c.IsPlaying and not a.IsPlaying and not b.IsPlaying and b.Plays==0,'after track 1 comes track 3: track 2 is skipped, never played')
 runUntil(function()return a.IsPlaying end,LEN[ID[3]]+5);run(CROSS+.4)
 check(a.IsPlaying and not c.IsPlaying and orderText(playOrder())=='1,3,1','... and then track 1 again (order: '..orderText(playOrder())..')')
 check(R.clock-t0>=90 and warnsAbout('74095461107598')==1,('no warning flood: %d warning(s) in %d s'):format(warnsAbout('74095461107598'),R.clock-t0))
 -- the file arrives late: it joins the rotation at its place
 b.TimeLength=LEN[ID[2]];E.load(b);run(.5)
 runUntil(function()return b.IsPlaying end,LEN[ID[1]]+5);run(CROSS+.4)
 check(b.IsPlaying and not a.IsPlaying and orderText(playOrder())=='1,3,1,2','a late loader joins: 1,3,1,2 (order: '..orderText(playOrder())..')')
end
do -- track 1 never loads: the list starts at track 2
 boot({cold={[ID[1]]=true}});goTrack();run(2)
 local a,b,c=trackSound(1),trackSound(2),trackSound(3)
 check(b.IsPlaying and not a.IsPlaying and near(b.Volume,VOL,1e-9),'Nature Inspiration not loaded: the list starts at track 2')
 runUntil(function()return c.IsPlaying end,LEN[ID[2]]+5);run(CROSS+.4)
 runUntil(function()return b.IsPlaying and b.TimePosition<5 and b.Plays>=2 end,LEN[ID[3]]+5);run(CROSS+.4)
 check(orderText(playOrder())=='2,3,2'and a.Plays==0,'... then 3, then 2 again (1 is skipped): '..orderText(playOrder()))
end
do -- only one loads: it loops (no crossfade into itself, no gap)
 boot({cold={[ID[1]]=true,[ID[3]]=true}});goTrack();run(2)
 local b=trackSound(2)
 check(b.IsPlaying and b.Looped==true and near(b.Volume,VOL,1e-9),'one track alone is looped')
 run(LEN[ID[2]]*2+5)
 check(b.IsPlaying and b.Plays==1 and near(b.Volume,VOL,1e-9)and #playingTracks()==1,'... and plays on through its end without a stop, a restart or a dip (Plays='..b.Plays..')')
 local late=trackSound(3);late.TimeLength=LEN[ID[3]];E.load(late);run(.5)
 check(b.Looped==false,'a second track loading takes the first off its loop')
 runUntil(function()return late.IsPlaying end,LEN[ID[2]]+5);run(CROSS+.4)
 check(late.IsPlaying and not b.IsPlaying,'... and the list goes on to it')
end
do -- none loads: silence, a bounded number of warnings, the base music untouched
 boot({cold={[ID[1]]=true,[ID[2]]=true,[ID[3]]=true}});goTrack();run(120)
 check(#playingTracks()==0 and #playOrder()==0,'no track loaded: nothing plays')
 local v=volumes();check(v[1]==0 and v[2]==0 and v[3]==0,'... all three silent')
 local w1,w2,w3=warnsAbout('96110001912212'),warnsAbout('74095461107598'),warnsAbout('132448918728086')
 check(w1==1 and w2==1 and w3==1,('one warning per track, no more (%d / %d / %d)'):format(w1,w2,w3))
 check(baseSound()~=nil and near(baseSound().Volume,.2,.01),'the base music is not silenced when there is no track music to replace it ('..tostring(baseSound()and baseSound().Volume)..')')
 goBase();run(3);goTrack();run(3)
 check(#playingTracks()==0,'entering and leaving the track with no files is quiet')
end

-- ======================================================================================================================
-- D. the base playlist
-- ======================================================================================================================
print('-- D. the base music')
do
 local src=W.B.BackgroundMusic
 local block=src:match('local PEACEFUL_PLAYLIST = {(.-)\n}')
 local ids,names={},{}
 for name,id in (block or''):gmatch('Name = "([^"]*)",%s*SoundId = "([^"]*)"')do ids[#ids+1]=id;names[#names+1]=name end
 check(#ids==5,'PEACEFUL_PLAYLIST holds 5 tracks: '..#ids)
 check(table.concat(ids,' ')==table.concat(BASE_ALL,' '),'the two old ones first, then 1837487700, 1837487818, 1836280952')
 check(names[3]=='Base track 1837487700'and names[4]=='Base track 1837487818'and names[5]=='Base track 1836280952','the new ones are named "Base track <id>" (the titles are not known)')
 check(names[1]:find('Morning Mood',1,true)~=nil and names[2]:find('Clair de Lune',1,true)~=nil,'(the old two keep their names)')
 check(src:find('local PEACEFUL_VOLUME = 0.2',1,true)~=nil,'PEACEFUL_VOLUME is 0.2 as before')
 check(src:find('local PLAYLIST_CROSSFADE_SECONDS = 3',1,true)~=nil,'PLAYLIST_CROSSFADE_SECONDS is 3 as before')
 check(src:find('local CHASE_VOLUME = 0.10',1,true)~=nil and src:find('Volume,.16',1,true)==nil,'the chase volume is 0.10 as before')
 check(src:find('local SCENIC_VOLUME=.07',1,true)~=nil and src:find('SCENIC_VOLUME=.055',1,true)==nil,'SCENIC_VOLUME is .07 (the old .055 is gone)')
end
do -- they rotate, in order, with the crossfade (files of 20 s so that it takes minutes of the mock clock, not hours)
 boot({baseLen=20})
 local seen={}
 local function record()for _,s in ipairs(named('ChestChaseBackgroundMusic'))do if not seen[s]then seen[s]=#seen+1;seen[#seen+1]=s end end end
 for _=1,260 do W.frames(30,1/30);record()end
 local seq={};for _,s in ipairs(seen)do seq[#seq+1]=table.find(BASE_ALL,s.SoundId)or 0 end
 check(#seq>=6,'the base music keeps rotating ('..#seq..' tracks started in 260 s)')
 local inOrder,all=true,{}
 for i=1,#seq do all[seq[i]]=true;if i>1 and seq[i]~=seq[i-1]%5+1 then inOrder=false end end
 check(inOrder,'they follow each other in the playlist order: '..table.concat(seq,','))
 check(all[1]and all[2]and all[3]and all[4]and all[5],'all five play, the three new ones too')
 -- the crossfade: while one fades out, the next fades in (two sounds playing, the sum at most the base volume)
 local two,maxSum=false,0
 for _=1,40 do for _=1,30 do W.frames(1,1/30)
  local n,sum=0,0;for _,s in ipairs(named('ChestChaseBackgroundMusic'))do if s.Parent and s.IsPlaying then n+=1;sum+=s.Volume end end
  if n>=2 then two=true end;maxSum=math.max(maxSum,sum)
 end end
 check(two,'two base sounds overlap while the next one comes in (the crossfade)')
 check(maxSum<=.2+1e-6,('... and never louder than .2 together (%.4f)'):format(maxSum))
 local s=baseSound();check(s and near(s.Volume,.2,.02),'the base music plays at .2 ('..tostring(s and s.Volume)..')')
end
do -- a new base file that does not load is skipped (with its warning) and the rotation goes on
 boot({baseLen=20,cold={[BASE_NEW[2]]=true}})
 local seen,order={},{}
 for _=1,300 do W.frames(30,1/30)
  for _,s in ipairs(named('ChestChaseBackgroundMusic'))do if not seen[s]then seen[s]=true;order[#order+1]=s end end
 end
 -- every attempt at the cold file makes a Sound too (and destroys it); the others are the rotation: each one's successor is the next in the list, 4 (cold) left out
 local okSkip,last,steps=true,nil,0
 for _,s in ipairs(order)do
  local i=table.find(BASE_ALL,s.SoundId)
  if i~=4 then
   if last then steps+=1;local want=last%5+1;if want==4 then want=5 end;if i~=want then okSkip=false end end
   last=i
  end
 end
 check(okSkip and steps>=5,'the cold base track (1837487818) is skipped: the rotation goes 3 -> 5 -> 1 -> 2 -> 3 ... ('..steps..' steps)')
 check(warnsAbout('Base track 1837487818')>=1,'... with the load warning, by name: '..tostring(warnsAbout('Base track 1837487818'))..' warnings')
 local s=baseSound();check(s~=nil and s.SoundId~=BASE_NEW[2],'(and a base track is playing)')
end

-- ======================================================================================================================
-- E. the track ambience (BiomeMood.SoundTargets)
-- ======================================================================================================================
print('-- E. the track ambience')
do
 local Mood=W.module('BiomeMood')
 local G=1.25
 -- the stage values of R155 and what the owner's "a bit louder" makes of them: x1.25 on the track (stages 1-7), none on the base (stage 0)
 local OLD={[0]={Birds=.018,Leaves=.022},[1]={Birds=.040,Leaves=.035},[6]={Birds=.033,Leaves=.045},[2]={Wind=.035},[3]={Wind=.045},[5]={Crystal=.008,Wind=.012},[4]={Rumble=.018,Wind=.016},[7]={Wind=.055,Rumble=.025}}
 local KEYS={'Birds','Leaves','Wind','Crystal','Rumble'}
 local function ref(stage,weather,refresh,chase,alive)
  local t={Birds=0,Leaves=0,Wind=0,Crystal=0,Rumble=0}
  if not alive then return t end
  local g=(stage and stage>=1 and stage<=7)and G or 1
  for k,v in pairs(OLD[stage]or{})do t[k]=v*g end
  if weather=='Rain'or weather=='Thunderstorm'or weather=='Blizzard'then
   t.Birds*=.15;t.Leaves*=.65;t.Wind=math.max(t.Wind,weather=='Blizzard'and .055 or .040)
   if weather=='Thunderstorm'then t.Rumble=math.max(t.Rumble,.022)end
  end
  if refresh then t.Birds=0;t.Leaves*=.4;t.Wind=math.max(t.Wind,.018)end
  if chase then for k,v in pairs(t)do t[k]=v*.12 end end
  return t
 end
 -- spelled out, without the formula
 local SPELLED={[1]={Birds=.05,Leaves=.04375},[2]={Wind=.04375},[3]={Wind=.05625},[4]={Rumble=.0225,Wind=.02},[5]={Crystal=.01,Wind=.015},[6]={Birds=.04125,Leaves=.05625},[7]={Wind=.06875,Rumble=.03125}}
 for stage=1,7 do
  local t=Mood.SoundTargets(stage,'Clear',false,false,true);local want=SPELLED[stage];local ok=true
  for _,k in ipairs(KEYS)do if not near(t[k],want[k]or 0,1e-12)then ok=false end end
  check(ok,('stage %d: Birds %.5f Leaves %.5f Wind %.5f Crystal %.5f Rumble %.5f are the old values x1.25'):format(stage,t.Birds,t.Leaves,t.Wind,t.Crystal,t.Rumble))
  for _,k in ipairs(KEYS)do local o=OLD[stage][k]or 0;if o>0 then check(near(t[k]/o,1.25,1e-9),'stage '..stage..' '..k..' is exactly 25% louder')end end
 end
 local b=Mood.SoundTargets(0,'Clear',false,false,true)
 check(b.Birds==.018 and b.Leaves==.022 and b.Wind==0 and b.Crystal==0 and b.Rumble==0,'stage 0 (the base) is as before: Birds .018, Leaves .022')
 -- every stage / weather / refresh / chase / alive combination against the old formula with the track stages x1.25
 local combos,bad,first=0,0,nil
 local weathers=table.pack('Clear','Cloudy','Rain','Thunderstorm','Blizzard','Fog','',nil);weathers.n=8
 for _,stage in ipairs({-1,0,1,2,3,4,5,6,7,8})do for wi=1,weathers.n do for _,refresh in ipairs({false,true})do for _,chase in ipairs({false,true})do for _,alive in ipairs({true,false})do
  local weather=weathers[wi];local t=Mood.SoundTargets(stage,weather,refresh,chase,alive);local r=ref(stage,weather,refresh,chase,alive);combos+=1
  for _,k in ipairs(KEYS)do if not near(t[k],r[k],1e-12)then bad+=1;first=first or(('stage %s %s refresh=%s chase=%s alive=%s %s: %s vs %s'):format(tostring(stage),tostring(weather),tostring(refresh),tostring(chase),tostring(alive),k,tostring(t[k]),tostring(r[k])))end end
 end end end end end
 check(bad==0,('all %d combinations: the track stages x1.25, the weather / refresh / chase rules and the base as before (%d differ) %s'):format(combos,bad,tostring(first)))
 -- the weather beds (R156) and the base weather are untouched
 local wb=Mood.WeatherBeds
 check(wb.Rain.Volume==.3 and wb.Thunderstorm.Volume==.32 and wb.Blizzard.Volume==.3 and wb.Rain.Key=='RainBed','M.WeatherBeds is as it was (.3 / .32 / .3)')
 check(Mood.SoundTargets(0,'Rain',false,false,true).RainBed==.3 and Mood.SoundTargets(3,'Rain',false,false,true).RainBed==0,'the weather beds: in the base only, at their volume')
 local r=Mood.SoundTargets(0,'Rain',false,false,true);check(near(r.Birds,.018*.15,1e-12)and near(r.Leaves,.022*.65,1e-12)and r.Wind==.04,'the base in the rain is as before')
 local s=Mood.SoundTargets(2,'Blizzard',false,false,true);check(s.Wind==.055,'a track stage in a blizzard: Wind is the weather\'s .055 where that is above the louder stage value (.04375)')
 local s3=Mood.SoundTargets(3,'Blizzard',false,false,true);check(near(s3.Wind,.05625,1e-12),'... and the louder stage value .05625 where that is above .055')
 local c=Mood.SoundTargets(7,'Clear',false,true,true);check(near(c.Wind,.06875*.12,1e-12)and near(c.Rumble,.03125*.12,1e-12),'a chase takes x0.12 of the louder value')
end

-- ======================================================================================================================
-- F. nothing is created while idle; the clean-up
-- ======================================================================================================================
print('-- F. idle and clean-up')
do
 boot();goTrack();run(5)
 local function snapshot()return {Created=#R.created,Tweens=createdTweens,Tasks=taskCalls}end
 local function idle(label,seconds)
  local before=snapshot();W.frames(math.floor(seconds*30),1/30);local after=snapshot()
  check(after.Created==before.Created,label..': no Instance created in '..math.floor(seconds*30)..' frames ('..(after.Created-before.Created)..')')
  check(after.Tweens==before.Tweens,label..': no tween created ('..(after.Tweens-before.Tweens)..')')
  check(after.Tasks==before.Tasks,label..': no task spawned / delayed / deferred ('..(after.Tasks-before.Tasks)..')')
 end
 idle('playing on the track',10)
 goBase();run(5);idle('left the track (paused)',10)
 goTrack();run(5);player:SetAttribute('ChestChaseRunActive',true);run(5);idle('in a chase',10)
 player:SetAttribute('ChestChaseRunActive',false);run(5)
 goBase();run(5);player:SetAttribute('ChestChaseRunActive',false);idle('in the base',10)
 -- the code of the 0.1 s step: no table, no closure, no Instance, no tween, no task
 local src=W.B.BackgroundMusic
 local step=src:match('local function stepScenic%(%).-\nend\n')
 check(step~=nil,'stepScenic is in the script')
 if step then
  check(not step:find('{',1,true)and not step:find('function%s*%(')and not step:find('Instance.new',1,true)and not step:find('task%.')and not step:find('tween%(')and not step:find('TweenService'),
   'stepScenic (run every 0.1 s) builds no table or closure and creates no Instance, tween or task')
 end
 local hb=src:match('local loopConnection=RunService%.Heartbeat:Connect%(function%(dt%).-\nend%)')
 check(hb~=nil and not hb:find('{',1,true)and not hb:find('Instance.new',1,true)and not hb:find('task%.')and not hb:find('tween%('),'the Heartbeat handler has no table, Instance, tween or task either')
end
do -- destroying the script cleans everything
 local sounds=scenicSounds();local n=#sounds
 bm.Destroying:Fire();bm=nil
 local left=0;for _,c in ipairs(SS:GetChildren())do if c.Name=='BiomeScenicMusic'or c.Name=='ChestChaseBackgroundMusic'or c.Name=='ChestChaseActionTrack'or c.Name=='ChestChaseSpecialTrack84'then left+=1 end end
 check(n==3 and left==0,'destroying the script removes the three track sounds, the base sounds and the chase sounds ('..left..' left)')
 local before=#R.created;local pl=0
 for _=1,3 do goTrack();run(2);goBase();run(2)end
 for _,s in ipairs(sounds)do if s.IsPlaying and s.Parent then pl+=1 end end
 check(#R.created==before and pl==0,'... and nothing runs afterwards (no sound made, none playing)')
end

print(('R156 music checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
