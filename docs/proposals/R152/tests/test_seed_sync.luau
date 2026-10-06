--!nocheck
-- R152 seed opening, part 1: SYNC and CLEAN-UP. The real RarePullCinematic / RarePullCard / RarePullScenes / RarePullAudio / RarePullRules
-- on the Roblox mock, every tier and every presentation, at 30, 60 and 144 fps:
--  1. every sound is loaded when the client starts (Bind), not when the reveal begins
--  2. every cue's hit is HEARD within 1/60 s of the frame that SHOWS its beat (each file's measured hit / lead-in allowed for); flights'
--     whooshes swell on the flight's fastest frame; risers end on the silence; the visual beats are really there on those frames
--  3. no sound outlives its presentation, and none is cut while still loud at its end
--  4. skip / abort / death / the script destroyed: every sound, the music duck, the grade, the GUI, the camera, the bindings are cleaned up
--  5. two openings in quick succession: the first card fades out under the second, no FieldOfView snap, no leftovers; the same reveal asked
--     for again keeps playing
--  6. the music duck follows the presentation's clock (down by the cut, back by the end, gone after)
--  7. files still loading on their beat join on the clock (never a late hit)
--  8. the chat line about a pull never shows before the puller's own screen has shown the seed (a slow device, a skip)
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Audio=W.module('RarePullAudio');local Sounds=W.module('RarePullSounds')
local Visuals=W.module('SeedPackVisuals')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
local SS=W.service('SoundService')
local function rarePlaying()local n={};for _,s in ipairs(Y.sounds)do if s.IsPlaying and s.Name:match('^RarePull_')then n[#n+1]=s.Name end end;return n end
local function ducks()local n=0;for _,d in ipairs(SS:GetDescendants())do if d.Name=='RarePullDuck'then n+=1 end end;return n end
local function duckDb()for _,d in ipairs(SS:GetDescendants())do if d.Name=='RarePullDuck'then return d.MidGain end end;return 0 end
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear()
 cam=W.workspace.CurrentCamera
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true;X.lowFx=false
 X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 R.advance(4) -- (no quick reveal: the previous presentation ended long ago)
end
local function packFor(rank,seedId)
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='p'..rank,Stage=2},nil)
 local spec=W.module('SeedPackRules').SeedDesignById[seedId]
 tool.ToolTip='Desert Seed Pack\nSomething: 1/2\n'..(spec and spec.name or seedId)..': 1/'..({'2','4','16','60','400','5K','83.3K','1.67B'})[rank]
 return bag,tool
end
local function start(rank,extra)
 local seedId=X.byRank[rank];local bag,tool=packFor(rank,seedId)
 local info={Rank=rank,SeedId=seedId,At=W.workspace:GetServerTimeNow(),Bag=bag,Tool=tool,Mutation='None'}
 for k,v in pairs(extra or{})do info[k]=v end
 return M.Start(info),bag
end
local function stage()return W.workspace:FindFirstChild('_RarePullStage')end
local function cleanAll(tag)
 check(M.Active()==nil and stage()==nil and X.pg:FindFirstChild('RarePullReveal')==nil,tag..': no presentation, stage or reveal GUI left')
 check(cam:FindFirstChild('RarePullGrade')==nil and cam:FindFirstChild('RarePullBlur')==nil and cam:FindFirstChild('RarePullGradeOut')==nil,tag..': no grade / blur left on the camera')
 check(#rarePlaying()==0,tag..': every reveal sound has stopped ('..table.concat(rarePlaying(),',')..')')
 check(ducks()==0 and Audio.DuckLevel==0,tag..': the music is no longer ducked')
 check(not Audio.Running()and Audio.Waiting()==0,tag..': no sound sheet or waiting file left')
 check(W.rsBound[M.BindName]==nil and W.actions[M.SkipAction]==nil,tag..': no render step or skip binding left')
 check(cam.CameraType==R.Enum.CameraType.Custom and cam.FieldOfView==70,tag..': the camera is the player\'s again, FieldOfView 70 ('..tostring(cam.FieldOfView)..')')
 check(X.player:GetAttribute('RarePullCinematic')==nil and X.player:GetAttribute('RarePullSeedShownAt')==nil and X.player:GetAttribute('RarePullClimaxAt')==nil,tag..': the announcement attributes are cleared')
end
-- 1. preloaded when the client starts ------------------------------------------------------------------------------------------------------
do
 local holder=R.new('LocalScript');holder.Name='PackOpeningFeedback'
 table.clear(E.preloaded)
 M.Bind(holder)
 local missing={}
 for _,slot in ipairs(Sounds.Order)do
  for i=1,#Audio.Layers(slot)do
   local found=false;for s in pairs(E.preloaded)do if s.Name=='RarePull_'..slot..'_'..i then found=true end end
   if not found then missing[#missing+1]=slot..'_'..i end
  end
 end
 check(#missing==0,'every reveal sound is preloaded by Bind (when the client starts), before any pack is opened (missing: '..table.concat(missing,',')..')')
 check(M.Active()==nil,'binding starts no presentation')
end
-- 2/3. every tier, every presentation, three frame rates ------------------------------------------------------------------------------------
-- the frames of a presentation: clock -> its own t; plays -> the t of the frame they started on
local function tOf(frames,clock)
 for _,f in ipairs(frames)do if math.abs(f.Clock-clock)<1e-9 then return f.T end end
 return nil
end
-- (the same comparison the reveal makes: t>=beat, no tolerance, so a beat that falls on a frame's float edge is judged as the code judges it)
local function firstFrameAtOrAfter(frames,t)
 for _,f in ipairs(frames)do if f.T and f.T>=t then return f end end
 return nil
end
-- what a play's file is: the owner's measured file (Hit / Swell) or one of the game's own sounds (heard from where it starts)
local function slotDef(slot)return Sounds.Get(slot)end
local stats={worstHit=0,worstSwell=0,worstEnd=0,plays=0,flights=0,risers=0}
local function presentations()
 local list={}
 for rank=1,5 do list[#list+1]={Rank=rank,Tag=names[rank]..' card'};list[#list+1]={Rank=rank,Tag=names[rank]..' quick',Quick=true}end
 for rank=6,8 do
  list[#list+1]={Rank=rank,Tag=names[rank]..' Full'}
  list[#list+1]={Rank=rank,Tag=names[rank]..' Calm',Reduced=true}
  list[#list+1]={Rank=rank,Tag=names[rank]..' InPlace',Keeper=true}
  list[#list+1]={Rank=rank,Tag=names[rank]..' Result',Result=true}
 end
 return list
end
local function setup(p)
 reset()
 if p.Quick then M.LastEnd=R.clock-.5;L.LastRevealEnd=M.LastEnd end
 if p.Reduced then W.Gui.ReducedMotionEnabled=true end
 if p.Keeper then X.keeper(V3(10,3,100),{GuardianBehavior='WANDER'})end
 return start(p.Rank,p.Result and{Result=true}or nil)
end
local function verify(p,dt)
 local tag=p.Tag..' @'..math.floor(1/dt+.5)..'fps'
 local run,bag=setup(p)
 if not check(run~=nil,tag..': it starts')then return end
 check((p.Quick==true)==(run.Quick==true)or run.Kind~='Ladder',tag..': quick as asked')
 local tl=run.TL;local startClock=R.clock
 Y.record(function()return run.Clock()end)
 Y.frames[1]={Clock=R.clock,T=run.Clock(),Voices={}}
 local probes={}
 local gui=X.pg:FindFirstChild('RarePullReveal')
 local flash=gui and X.find(gui,'Flash');local odds=gui and X.find(gui,'Odds');local view=gui and X.find(gui,'Seed')
 local oddsScale=odds and odds:FindFirstChildOfClass('UIScale')
 local edge=gui and X.find(gui,'Edge Top')
 local endClock
 X.run(tl.Length+.4,dt,function(now)
  local f=Y.frames[#Y.frames];if not f or f.Clock~=now then return end
  f.Flash=flash and flash.BackgroundTransparency;f.OddsScale=oddsScale and oddsScale.Scale;f.View=view and view.Visible
  f.Edge=edge and edge.Visible and(1-edge.BackgroundTransparency)or 0
  local st=stage()
  if st and run.Scene then
   local sum,n=V3(0,0,0),0;for _,d in ipairs(st:GetChildren())do if d.Name=='Crown band'then sum=sum+d.CFrame.Position;n+=1 end end
   f.Crown=n>0 and sum/n or nil -- (the centre of the band: the crown also turns slowly about it)
   f.Pack=run.Scene.PackCF and run.Scene.PackCF.Position
   local plate=st:FindFirstChild('Lock plate');f.Plate=plate and plate.CFrame
  end
  if not M.Active()and not endClock then endClock=now end
 end)
 local frames=Y.stop()
 check(endClock~=nil,tag..': it ends by itself')
 endClock=endClock or R.clock
 local plays=Y.plays(startClock)
 local used={}
 local expected=0
 for _,c in ipairs(run.Cues)do
  local def=slotDef(c.Slot)
  for i,l in ipairs(Audio.Layers(c.Slot))do
   local beat=c.At+(l.Delay or 0)
   if beat<tl.Length-1e-6 and(not c.Until or c.Until>beat+1e-6)then
    expected+=1
    -- the play of this cue and layer: the first unused one of that voice pair from the frame that reaches its start
    local want=beat
    local pitch=(l.Pitch or 1)*(c.Pitch or 1)
    if c.PeakAt and l.Swell then local bound=l.Region and l.Region[1]or l.Start or 0;want=math.max(beat,c.PeakAt-(l.Swell-bound)/pitch)end
    local vf=firstFrameAtOrAfter(frames,want)
    local match
    for k,pl in ipairs(plays)do
     if not used[k]and pl.Slot==c.Slot and pl.Sound.Name:match('_'..i..'b?$')then
      local tp=tOf(frames,pl.At)
      if tp and tp>=want-1e-6 and tp<want+dt+1e-6 then match=k;break end
     end
    end
    if not check(match~=nil,tag..': '..c.Slot..' layer '..i..' plays on its beat ('..string.format('%.3f',want)..' s)')then continue end
    used[match]=true;stats.plays+=1
    local pl=plays[match];local tp=tOf(frames,pl.At)
    check(vf and math.abs(vf.T-tp)<1e-9,tag..': '..c.Slot..' starts on the frame that shows its beat')
    local owner=l.Owner and def and def.Id==pl.Id
    if c.PeakAt and l.Swell then
     local swellT=tp+(l.Swell-pl.Pos)/pl.Speed;local err=math.abs(swellT-c.PeakAt);stats.worstSwell=math.max(stats.worstSwell,err);stats.flights+=1
     check(err<=1/60+1e-6,tag..': the '..(c.Flight or c.Slot)..' whoosh swells on the flight\'s fastest moment ('..string.format('%.3f vs %.3f',swellT,c.PeakAt)..')')
    elseif l.AlignEnd and l.Content and c.Until then
     local endT=tp+((l.Start or 0)+l.Content-pl.Pos)/pl.Speed;local err=math.abs(endT-c.Until);stats.worstEnd=math.max(stats.worstEnd,err);stats.risers+=1
     check(err<=1/60+1e-6,tag..': the '..c.Slot..' ends ON its cue\'s end ('..string.format('%.3f vs %.3f',endT,c.Until)..')')
    elseif not(l.Loop or l.PitchTo or(owner and def.Loop))then
     -- a one-shot: when its hit is HEARD (the owner's file: its measured Hit; one of the game's own: from where it starts, its lead-in skipped)
     local hitPos=(owner and l.Hit)or pl.Pos
     local heard=tp+(hitPos-pl.Pos)/pl.Speed;local err=math.abs(heard-vf.T);stats.worstHit=math.max(stats.worstHit,err)
     check(err<=1/60+1e-6,tag..': '..c.Slot..' is heard within 1/60 s of the frame of its beat ('..string.format('%.4f',heard-vf.T)..' s)')
     check(vf.T-beat<dt+1e-6,tag..': and that frame is the first one of its beat')
    end
   end
  end
 end
 -- the visual beats are on those frames
 local function at(t)return firstFrameAtOrAfter(frames,t)end
 local function before(t)local b;for _,f in ipairs(frames)do if f.T and f.T<t then b=f end end;return b end
 local hitT=tl.Climax or tl.Burst
 if hitT and hitT>0 and not tl.ResultOnly then
  local f,b=at(hitT),before(hitT)
  check(f and b and(f.Flash or 1)<.9 and(b.Flash or 1)>.99,tag..': the flash is on the hit frame and not before')
 end
 if tl.Odds and odds and run.Odds and not run.Reduced then -- (ReducedMotion: "1 in N" does not scale)
  local f,b=at(tl.Odds),before(tl.Odds);local f2=f and firstFrameAtOrAfter(frames,f.T+1e-4)
  check(b and(b.OddsScale or 1)<=1.0001 and f and((f.OddsScale or 1)>1.0001 or(f2 and frames[table.find(frames,f)+1]and(frames[table.find(frames,f)+1].OddsScale or 1)>1.0001)),tag..': "1 in N" slams on its beat (its sound\'s frame, or the frame after)')
 end
 if run.Kind=='Ladder'then
  local f,b=at(tl.Burst),before(tl.Burst)
  check(f and f.View and b and not b.View,tag..': the seed card appears on the burst frame')
  if not p.Quick then
   for _,h in ipairs(L.Heartbeats(p.Rank,false))do
    local f0=before(h);local f1=at(h);local idx=f1 and table.find(frames,f1);local f2=idx and frames[idx+1]
    check(f0 and f2 and f2.Edge>f0.Edge,tag..': the screen edges throb on the heartbeat at '..string.format('%.2f',h))
   end
  end
 end
 if run.Kind=='Scene'and run.Variant=='Full'then
  if p.Rank==8 then
   local f,b=at(tl.CrownOn),before(tl.CrownOn-.1)
   check(f and f.Crown and b and b.Crown and(f.Crown-b.Crown).Magnitude>.05,tag..': the crown is still visibly coming down a tenth of a second before it lands')
   local rest;for _,g in ipairs(frames)do if g.T and g.T>tl.CrownOn+.3 and g.T<tl.Silence-.2 and g.Crown then rest=g end end
   check(f and rest and(f.Crown-rest.Crown).Magnitude<.012,tag..': and it touches the pack on the frame of its bell / fanfare')
   local l1,l0=at(tl.Land),before(tl.Glide)
   check(l1 and l1.Pack and l0 and l0.Pack and(l1.Pack-L.Points[8].Pack).Magnitude<.02 and(l0.Pack-L.Points[8].Pack).Magnitude>.05,tag..': the pack is on the cushion on the frame of its landing sound')
  elseif p.Rank==6 then
   for _,k in ipairs(L.LockTurns)do
    if tl.Lock+k<tl.Unlock then
     local f,b=at(tl.Lock+k),before(tl.Lock+k)
     check(f and b and f.Plate and b.Plate and(f.Plate.LookVector-b.Plate.LookVector).Magnitude+(f.Plate.Position-b.Plate.Position).Magnitude>.02,tag..': the lock ring turns on its click at +'..k)
    end
   end
  end
 end
 -- 3. nothing outlives the presentation; nothing is cut while loud at its end
 local outlived={}
 for _,pl in ipairs(plays)do if pl.Ends>endClock+1e-6 then outlived[#outlived+1]=pl.Slot..string.format('[%s at %.2f ends %.2f, end %.2f]',pl.Sound.Name,pl.At-startClock,pl.Ends-startClock,endClock-startClock)end end
 check(#outlived==0,tag..': no sound outlives the presentation ('..table.concat(outlived,',')..')')
 local last=frames[#frames]
 for i=#frames,1,-1 do if frames[i].Clock<endClock-1e-9 then last=frames[i];break end end
 local loud={}
 for _,v in ipairs(last.Voices)do
  local peak=0;for _,pl in ipairs(plays)do if pl.Sound==v.Sound then peak=math.max(peak,pl.Volume or 0)end end
  if v.Gain>.2*math.max(peak,1e-3)+1e-4 then loud[#loud+1]=v.Sound.Name end
 end
 check(#loud==0,tag..': every voice has faded out by the end ('..table.concat(loud,',')..' still loud)')
 cleanAll(tag)
end
for _,dt in ipairs({1/30,1/60,1/144})do
 for _,p in ipairs(presentations())do verify(p,dt)end
end
print(string.format('sync: %d plays checked; worst hit %.4f s, worst whoosh swell %.4f s (%d flights), worst riser end %.4f s (%d)',stats.plays,stats.worstHit,stats.worstSwell,stats.flights,stats.worstEnd,stats.risers))
-- 4. skip / abort / death / the script destroyed ------------------------------------------------------------------------------------------
for rank=6,8 do
 for _,when in ipairs({'skip early','skip late','abort','death','destroyed'})do
  reset()
  local run=start(rank);local tl=run.TL
  local tag=names[rank]..' '..when
  if when=='skip early'then
   X.run(tl.SkipFrom+.1);check(M.Skip(),tag..': skipped');X.run(.05)
   check(run.Clock()>=tl.Climax-.03,tag..': straight to the hit')
   X.run(tl.Length+.5)
  elseif when=='skip late'then
   X.run(tl.Rise+.2);check(M.Skip(),tag..': skipped');X.run(tl.Length+.5)
  elseif when=='abort'then
   X.run(tl.SceneIn+.6);M.Abort('test')
  elseif when=='death'then
   X.run(tl.SceneIn+.6);X.hum.Died:Fire();X.run(.1)
  else
   X.run(tl.SceneIn+.6);local holder=R.new('LocalScript');M.Bind(holder);holder.Destroying:Fire()
  end
  X.run(.3)
  cleanAll(tag)
  check(M.Fading()==0,tag..': nothing fading')
 end
end
-- 5. two openings in quick succession --------------------------------------------------------------------------------------------------
for rank=1,5 do
 for _,frac in ipairs({.3,.8,1.2})do
  reset()
  local first=start(rank);local tl=first.TL;local switchAt=tl.Burst*frac
  local fovs,grades,guis={},0,0
  local second
  X.run(math.min(switchAt,tl.Length-.05),1/60,function()fovs[#fovs+1]=cam.FieldOfView end)
  second=start(math.min(5,rank+1))
  local tag=names[rank]..' -> '..names[math.min(5,rank+1)]..' at '..string.format('%.2f',switchAt)
  check(second and M.Active()==second and first.Done,tag..': the second takes over')
  check(second.Quick,tag..': and is a quick reveal')
  local maxGuis,maxGrades,afterGuis,afterGrades=0,0,9,9
  local t0=R.clock
  X.run(second.TL.Length+.4,1/60,function(now)
   fovs[#fovs+1]=cam.FieldOfView
   local g=0;for _,c in ipairs(X.pg:GetChildren())do if c.Name:match('^RarePullReveal')then g+=1 end end
   local gr=0;for _,c in ipairs(cam:GetChildren())do if c.Name:match('^RarePullGrade')then gr+=1 end end
   maxGuis=math.max(maxGuis,g);maxGrades=math.max(maxGrades,gr)
   if now-t0>.25 and now-t0<.3 then afterGuis,afterGrades=g,gr end
  end)
  local jump=0;for i=2,#fovs do jump=math.max(jump,math.abs(fovs[i]-fovs[i-1]))end
  check(jump<=.6,tag..': no FieldOfView snap (largest step '..string.format('%.2f',jump)..' degrees a frame)')
  check(maxGuis<=2 and afterGuis<=1,tag..': the first card fades out under the second ('..maxGuis..' at once, '..afterGuis..' after .25 s)')
  check(maxGrades<=2 and afterGrades<=1,tag..': and its colour grade with it')
  cleanAll(tag)
 end
end
do -- the same reveal asked for again (the pack re-equipped mid-reveal) keeps playing
 reset()
 local run,bag=start(4);X.run(.5)
 local again=M.Start({Rank=4,SeedId=X.byRank[4],At=run.At,Bag=bag,Mutation='None'})
 check(again==run and not run.Done and not run.Quick,'the same reveal asked for again keeps playing (it is not restarted as a quick one)')
 X.run(run.TL.Length+.3);cleanAll('re-equip')
end
-- 6. the music duck ---------------------------------------------------------------------------------------------------------------------
do
 for _,rank in ipairs({4,5,6,7,8})do
  reset()
  local run=start(rank);local tl=run.TL
  local samples={}
  X.run(tl.Length+.2,1/60,function()samples[#samples+1]={T=run.Done and math.huge or run.Clock(),Db=duckDb(),N=ducks()}end)
  local tag=names[rank]..' duck'
  local okHold,okIn,okEnd=true,true,true
  for _,s in ipairs(samples)do
   if s.T<math.huge then
    local want=-Audio.DuckDb*L.Duck(run.Kind,rank,tl,s.T)
    if math.abs(s.Db-want)>.051 then okHold=false end
   end
  end
  check(okHold,tag..': the music duck follows the presentation\'s clock frame by frame')
  if run.Kind=='Scene'then
   local atCut;for _,s in ipairs(samples)do if s.T>=tl.Cut and not atCut then atCut=s end end
   check(atCut and atCut.Db<=-Audio.DuckDb+.01,tag..': the music is fully down by the cut (when the story starts)')
  end
  check(ducks()==0,tag..': and the duck is gone after it ends')
 end
 reset();local run=start(8);X.run(run.TL.Cut+.2);check(ducks()==2,'King: the duck sits on the Music and Chase groups');M.Abort('test');check(ducks()==0,'and an abort lifts it at once')
end
-- 7. files still loading on their beat --------------------------------------------------------------------------------------------------
do
 for _,rank in ipairs({4,8})do
  reset()
  local cold={}
  for _,s in ipairs(Y.sounds)do if s.Name:match('^RarePull_')and Y.ById[s.SoundId]then Y.cold(s);cold[#cold+1]=s end end
  local run=start(rank);local tl=run.TL;local t0=R.clock
  Y.record(function()return run.Clock()end);Y.frames[1]={Clock=R.clock,T=run.Clock(),Voices={}}
  local seed=rank*7919;local function rnd()seed=(seed*16807)%2147483647;return seed/2147483647 end
  local loadAt={};for _,s in ipairs(cold)do loadAt[s]=rnd()*tl.Length*.6 end
  X.run(tl.Length+.3,1/60,function(now)for s,t in pairs(loadAt)do if now-t0>=t then Y.load(s);loadAt[s]=nil end end end)
  local frames=Y.stop()
  local late=0;local joined=0
  for _,pl in ipairs(Y.plays(t0))do
   local tp=tOf(frames,pl.At)
   if tp and Y.ById[pl.Id]then
    -- find its cue: the latest beat of that slot at or before the play
    local best
    for _,c in ipairs(run.Cues)do if c.Slot==pl.Slot and c.At<=tp+1e-6 and(not best or c.At>best.At)then best=c end end
    if best then
     local l=Audio.Layers(pl.Slot)[1];local d=Sounds.Get(pl.Slot)
     local hitPos=(l.Hit and not(best.PeakAt or l.AlignEnd or d.Loop))and l.Hit or nil
     if hitPos then
      local heard=tp+(hitPos-pl.Pos)/pl.Speed
      if heard>tp+1/60+1e-6 and tp-best.At>1/60 then late+=1 end -- a hit heard after its own beat's frame
      if tp-best.At>1/60 then joined+=1 end
     end
    end
   end
  end
  check(late==0,names[rank]..' with every file loading late: no hit is ever heard late ('..late..'; '..joined..' joined the clock part-way)')
  X.run(.3);cleanAll(names[rank]..' cold')
  for _,s in ipairs(cold)do Y.load(s)end
 end
end
-- 8. the chat line about a pull and the puller's own screen --------------------------------------------------------------------------------
do
 local Rules=W.module('PullAnnounceRules')
 local remotes=W.RS:FindFirstChild('ChestChaseRemotes')
 local remote=R.Instance.new('RemoteEvent');remote.Name=Rules.RemoteName;remote.Parent=remotes
 local TCS=W.service('TextChatService');local channels=R.new('Folder');channels.Name='TextChannels';channels.Parent=TCS
 local general=R.new('TextChannel');general.Name='RBXGeneral';general.Parent=channels
 local chat={};general.DisplaySystemMessage=function(_,text)chat[#chat+1]={At=R.clock,Text=text}end
 local client=R.new('LocalScript');client.Name='PullAnnouncerClient'
 local ok,err=pcall(W.load,'PullAnnouncerClient',client);check(ok,'the real PullAnnouncerClient loads: '..tostring(err))
 local n=0
 local function trial(rank,lateBy,skip,reduced)
  reset();if reduced then W.Gui.ReducedMotionEnabled=true end;table.clear(chat)
  local seedId=X.byRank[rank];local bag,tool=packFor(rank,seedId)
  -- the pack opened `lateBy` seconds ago on the server: this client is that late
  local openedAt=W.workspace:GetServerTimeNow()-lateBy
  local run=M.Start({Rank=rank,SeedId=seedId,At=openedAt,Bag=bag,Tool=tool,Mutation='None'})
  local sendAt=openedAt+Rules.RevealDelay(names[rank])
  local seen,sent=nil,false
  local gui=X.pg:FindFirstChild('RarePullReveal');local odds=gui and X.find(gui,'Odds');local title=gui and X.find(gui,'Title')
  X.run(16,1/60,function(now)
   if skip and run.Kind=='Scene'and not run.Skipped and run.Clock()>=run.TL.SkipFrom+.05 then M.Skip()end
   if not seen and odds and title and odds.Parent and odds.TextTransparency<.05 and title.TextTransparency<.05 and run.Odds and odds.Text==L.OddsPrefix..run.Odds and run.Clock()>=L.ShownAt(run.TL)then seen=now end
   if not sent and now>=sendAt then sent=true;n+=1;remote.OnClientEvent:Fire({Kind='Pull',Name=X.player.Name,UserId=X.player.UserId,Id='pull-'..n,SeedId=seedId,Odds=100})end
  end)
  local tag=names[rank]..(reduced and' Calm'or'')..' (client '..lateBy..' s late'..(skip and', skipped'or'')..')'
  check(#chat==1,tag..': one chat line')
  check(seen and chat[1]and chat[1].At>=seen-1e-6,tag..': the line comes after the puller has seen the seed ('..string.format('line %.2f, seed %.2f',chat[1]and chat[1].At-openedAt or -1,seen and seen-openedAt or -1)..' s)')
 end
 for _,rank in ipairs({4,5,6,7,8})do
  for _,lateBy in ipairs({0,.4,.9})do trial(rank,lateBy,false)end
  if rank>=6 then trial(rank,.9,true);trial(rank,.9,false,true)end
 end
 client.Destroying:Fire()
end

-- 9. review fix B2: the engine may report IsPlaying false for a frame after Play(): the voice cap must not stop the one-shots that started in the same frame (the King's four climax hits) -------
do
 local HITS={Impact=true,GroundImpact=true,PackBurst=true,KingFanfare=true}
 for _,dt in ipairs({1/30,1/60})do
  for _,rank in ipairs({8,7})do
   reset()
   local run=start(rank);local tl=run.TL;local tag='lagging IsPlaying '..names[rank]..' @'..math.floor(1/dt+.5)..'fps'
   -- IsPlaying turns true one frame after Play() (a RenderStepped listener runs after the director's frame); every Stop is logged
   local pending,played,stops,restore={},{},{},{}
   for _,s in ipairs(Y.sounds)do
    local props=rawget(s,'_props');local play,stop=props.Play,props.Stop
    props.Play=function(self)play(self);self.IsPlaying=false;pending[self]=true;played[self]=R.clock end
    -- (a Stop right after its own Play is a cut; the Stop that comes just BEFORE a Play, to reset the voice, is not)
    props.Stop=function(self)pending[self]=nil;if played[self]then stops[#stops+1]={Sound=self,After=R.clock-played[self],At=R.clock}end;stop(self) end
    restore[#restore+1]=function()props.Play=play;props.Stop=stop end
   end
   local conn=W.Run.RenderStepped:Connect(function()for s in pairs(pending)do pending[s]=nil;if s.Parent then s.IsPlaying=true end end end)
   local hitAt
   X.run(tl.Climax+.4,dt,function()if not hitAt and run.Clock()>=tl.Climax then hitAt=R.clock end end)
   local cut,heard,slots={},{},{}
   for _,st in ipairs(stops)do
    local slot=st.Sound.Name:match('^RarePull_(.-)_%d+b?$')
    if slot and HITS[slot]and hitAt and st.At>=hitAt-1e-6 and st.At<=hitAt+.1 and st.After<=.1 then cut[#cut+1]=st.Sound.Name end
   end
   for _,s in ipairs(Y.sounds)do
    local slot=s.Name:match('^RarePull_(.-)_%d+b?$')
    if slot and HITS[slot]and s.IsPlaying and s.Parent then heard[#heard+1]=s.Name;slots[slot]=true end
   end
   local wanted=rank==8 and{'Impact','GroundImpact','PackBurst','KingFanfare'}or{'GroundImpact','PackBurst'}
   local missing={};for _,slot in ipairs(wanted)do if not slots[slot]then missing[#missing+1]=slot end end
   check(hitAt~=nil,tag..': the climax was reached')
   check(#cut==0,tag..': no climax hit is stopped on its own frame by the voice cap ('..table.concat(cut,',')..')')
   check(#missing==0,tag..': every climax hit is still sounding 0.4 s after the climax (missing: '..table.concat(missing,',')..'; sounding: '..table.concat(heard,',')..')')
   conn:Disconnect();for _,f in ipairs(restore)do f()end
   M.Abort('test');X.run(.3)
  end
 end
 -- the grace a voice gets before the cap judges it by IsPlaying is short: a voice that never started does not hold a place for long
 reset()
 local run=start(8);X.run(run.TL.Climax+.3,1/60)
 check(Audio.PlayLag>0 and Audio.PlayLag<=.25,'the lag a voice may show before it is judged is short ('..tostring(Audio.PlayLag)..' s)')
 M.Abort('test');X.run(.3)
end
print(('R152 sync checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
