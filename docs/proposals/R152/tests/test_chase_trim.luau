--!nocheck
-- R152 (owner: "darkened chase is the whole audio but ... skip to the 0:22 part of the song"), on the Roblox mock with the REAL ChaseMusicTrim152 (and,
-- when the mock can run it, the real BackgroundMusic):
--  1. the secret keeper theme (id 127003062753525) gets PlaybackRegion and LoopRegion 22 s -> end of the file (the length once known, an open end before),
--     PlaybackRegionsEnabled, so it plays from 0:22 and every loop restarts at 0:22; the other music (the keeper chase theme, the scenic track, the playlist)
--     is untouched; a file too short to skip into is left whole.
--  2. a Sound created later with that id is cut too; so is one whose SoundId is set after it is parented; the id in either spelling; and the end is
--     re-applied when the length arrives.
--  3. a track that sits before 0:22 while it plays (BackgroundMusic starts every chase with TimePosition=0; Play()) is moved to 0:22 within a frame,
--     one that is paused or not ours is left alone.
--  4. with the real BackgroundMusic running a secret keeper chase: the track is the cut one, starts at 0:22, loops, is paused / resumed and faded without
--     ever leaving the region; the other chase theme stays whole.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
E.player('Tester')
local player=E.Player
local SS=W.service('SoundService');local Run=W.service('RunService')
local SPECIAL='rbxassetid://127003062753525';local SKIP=22;local LEN=190
local function sound(parent,name,id,length)local s=R.Instance.new('Sound');s.Name=name;s.TimeLength=length or LEN;s.SoundId=id or'';s.Parent=parent;return s end
local function cut(s,to)local a,b=s.PlaybackRegion,s.LoopRegion;return s.PlaybackRegionsEnabled==true and a and a.Min==SKIP and a.Max==to and b and b.Min==SKIP and b.Max==to end
local function untouched(s)return s.PlaybackRegionsEnabled~=true end

-- 1. the sounds that exist when the script starts ------------------------------------------------------------------------------------------------------
local special=sound(SS,'ChestChaseSpecialTrack84',SPECIAL)
local chase=sound(SS,'ChestChaseTrack','rbxassetid://90864299965930')
local scenic=sound(SS,'BiomeScenicMusic','rbxassetid://96110001912212')
local morning=sound(SS,'Morning','rbxassetid://1846088038')
local sc=R.new('LocalScript');sc.Name='ChaseMusicTrim152'
local ok,err=pcall(W.load,'ChaseMusicTrim152',sc);check(ok,'ChaseMusicTrim152 loads: '..tostring(err))
check(cut(special,LEN),'the secret keeper chase theme plays from 0:22 to the end of the file (regions 22-190, enabled)')
check(special.TimePosition==SKIP,'(and it starts at 0:22, not 0)')
check(untouched(chase)and untouched(scenic)and untouched(morning),'the keeper chase theme, the scenic track and the playlist are not touched')
check(chase.TimePosition==0 and scenic.TimePosition==0,'(and they still start at 0)')
local short=sound(SS,'Short',SPECIAL,12);check(untouched(short),'a file shorter than the skip is left whole, not silenced')

-- 2. later sounds ----------------------------------------------------------------------------------------------------------------------------------------
local later=sound(SS,'ChestChaseSpecialTrack84',SPECIAL)
check(cut(later,LEN),'a Sound created later with the id is cut as it appears')
local plain=sound(SS,'Plain','127003062753525')
check(cut(plain,LEN),'the id as bare digits is recognised too')
local lateId=sound(SS,'Late','');check(untouched(lateId),'(a sound with no id yet is left alone)')
lateId.SoundId=SPECIAL;check(cut(lateId,LEN),'a SoundId set after parenting is cut')
local nested=R.new('Folder');nested.Name='Nest';nested.Parent=SS;local deep=sound(nested,'Deep',SPECIAL)
check(cut(deep,LEN),'a sound in a folder inside SoundService is cut')
local otherLater=sound(SS,'OtherLater','rbxassetid://96110001912212');check(untouched(otherLater),'another track created later stays whole')
local unknown=sound(SS,'Unknown',SPECIAL,0)
check(unknown.PlaybackRegionsEnabled==true and unknown.PlaybackRegion.Min==SKIP and unknown.PlaybackRegion.Max==math.huge and unknown.LoopRegion.Min==SKIP,'a track whose length is not known yet: 22 s to an open end')
unknown.TimeLength=LEN;check(cut(unknown,LEN),'... and the end is set to the file\'s length once it is known')
special.PlaybackRegionsEnabled=false;special.SoundId=SPECIAL;check(cut(special,LEN),'re-setting the id (a reload of the track) re-applies the cut')

-- 3. the position -------------------------------------------------------------------------------------------------------------------------------------
do
 special.TimePosition=0;special.IsPlaying=true;chase.TimePosition=0;chase.IsPlaying=true
 Run.Heartbeat:Fire(1/60)
 check(special.TimePosition==SKIP,'a playing track at 0:00 is moved to 0:22 within a frame ('..tostring(special.TimePosition)..')')
 check(chase.TimePosition==0,'the other chase theme is not moved')
 special.TimePosition=60;Run.Heartbeat:Fire(1/60);check(special.TimePosition==60,'a track past 0:22 is left where it is')
 special.IsPlaying=false;special.TimePosition=0;Run.Heartbeat:Fire(1/60);check(special.TimePosition==0,'a stopped / paused track is not touched')
 special.TimePosition=SKIP;chase.IsPlaying=false
 if special.Played then special.TimePosition=3;special.IsPlaying=true;special.Played:Fire();check(special.TimePosition==SKIP,'the Played event moves it to 0:22 at once')end
 special.IsPlaying=false;special.TimePosition=SKIP
end

-- 4. the real BackgroundMusic ------------------------------------------------------------------------------------------------------------------------
-- (its playlist loop waits with task.wait; on the mock that never yields, so here a wait is a real yield resumed by the mock clock, and os.clock is the mock's)
do local inew=R.Instance.new -- (the mock's Sound has no Pause / Resume: BackgroundMusic fades its tracks out with Pause)
 R.Instance.new=function(class,parent)
  local o=inew(class,parent)
  if class=='Sound'then
   o.IsPaused=false
   local play=o.Play;o.Play=function(self)self.IsPaused=false;return play(self)end
   o.Pause=function(self)if self.IsPlaying then self.IsPlaying=false;self.IsPaused=true end end
   o.Resume=function(self)if self.IsPaused then self.IsPaused=false;self.IsPlaying=true end end
  end
  return o
 end
end
do
 for _,s in ipairs({special,chase,scenic,morning,later,plain,lateId,deep,otherLater,unknown,short})do s:Destroy()end
 nested:Destroy()
 do local realTask=W.env.task;local mt={}
  local t2=setmetatable({wait=function(t)
   local co=coroutine.running();if co and coroutine.isyieldable()then R.task.delay(t or .03,function()coroutine.resume(co)end);coroutine.yield();return t or .03 end
   R.advance(t or .03);return t or .03 end},{__index=realTask});W.env.task=t2
  W.env.os=setmetatable({clock=function()return R.clock end},{__index=os})
 end
 local bm=R.new('LocalScript');bm.Name='BackgroundMusic'
 local okB,errB=pcall(W.load,'BackgroundMusic',bm)
 check(okB,'the real BackgroundMusic runs on the mock: '..tostring(errB))
 if okB then
  W.frames(5,1/30)
  local sp=SS:FindFirstChild('ChestChaseSpecialTrack84');local ch=SS:FindFirstChild('ChestChaseActionTrack')
  check(sp~=nil and ch~=nil,'BackgroundMusic made the special and the ordinary chase tracks in SoundService')
  if sp and ch then
   check(sp.SoundId==SPECIAL and sp.Looped==true,'(the special track is the id, Looped)')
   sp.TimeLength=LEN;ch.TimeLength=LEN;sp.Loaded:Fire();ch.Loaded:Fire();W.frames(10,1/30)  -- the files load: their length arrives
   check(cut(sp,LEN),'BackgroundMusic\'s own track is cut once its length is known (22 s to the end)')
   check(untouched(ch),'the ordinary chase theme stays whole')
   -- a secret keeper chase begins
   sp.IsPlaying=false;sp.Plays=0;table.clear(sp.PlayLog)
   player:SetAttribute('SpecialKeeperChase84',true);player:SetAttribute('ChestChaseRunActive',true);W.frames(60,1/30)
   check(sp.Plays>=1 and sp.IsPlaying==true,'the secret keeper chase plays the track ('..tostring(sp.Plays)..' plays)')
   check(sp.PlayLog[1]and sp.PlayLog[1].TimePosition<SKIP,'(BackgroundMusic starts it with TimePosition = 0 ... as read)')
   check(sp.TimePosition>=SKIP,'... and within frames its position is 0:22 or later ('..tostring(sp.TimePosition)..')')
   check(sp.Looped==true and cut(sp,LEN),'it loops, and the region is still 22 s to the end')
   check(ch.IsPlaying~=true,'the ordinary chase theme does not play for it')
   -- every moment it is playing, it is never before 0:22
   local minPos=math.huge
   for _=1,120 do W.frames(1,1/30);if sp.IsPlaying then minPos=math.min(minPos,sp.TimePosition)end end
   check(minPos>=SKIP,'sampled each frame for 4 s, the playing position never drops below 0:22 ('..tostring(minPos)..')')
   -- the chase ends: fade out and pause; the next chase resumes (or restarts) inside the region
   player:SetAttribute('ChestChaseRunActive',false);W.frames(90,1/30)
   check(cut(sp,LEN)and sp.IsPlaying~=true,'after the chase ends the track is paused and the region is unchanged')
   player:SetAttribute('ChestChaseRunActive',true);W.frames(60,1/30)
   check(cut(sp,LEN)and sp.IsPlaying==true and sp.TimePosition>=SKIP,'a second chase plays again inside the region ('..tostring(sp.TimePosition)..')')
   -- BackgroundMusic's own "restart a track that is not playing" guard (once a second) also lands on 0:22
   sp.IsPlaying=false;sp.TimePosition=0;W.frames(60,1/30)
   check(sp.IsPlaying~=true or sp.TimePosition>=SKIP,'a restart by the 1 s guard (TimePosition 0, Play) is moved to 0:22 too ('..tostring(sp.TimePosition)..')')
   -- an ordinary keeper chase
   player:SetAttribute('SpecialKeeperChase84',false);W.frames(60,1/30)
   check(untouched(ch),'an ordinary chase later: its theme is still whole')
  end
  bm.Destroying:Fire()
 end
end
sc.Destroying:Fire()

print(('R152 chase trim checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
