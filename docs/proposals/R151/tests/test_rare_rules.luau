--!nocheck
-- R151 pull reveals, part 1: the REAL RarePullRules / RarePullSounds / RarePullAudio cue sheets on the Roblox mock (pure timelines and maths).
--  * every tier's timeline (story scenes Full / Calm / InPlace; the Common..Mythic ladder, normal and quick): beats in order, escalation,
--    the silence right before the hit, skip windows, the server timeline unchanged (the seed's slide still ends with RevealDuration);
--  * the suspense: the rarity hint starts neutral and ends on the real tier's colour, higher tiers pass every lower colour first;
--    the wobble grows and stops at the burst (none with ReducedMotion); the strips peel a few at a time and are all open at the burst;
--  * framing: in every scene's climax and end frames the seed is on screen, near the centre, big, and never under the title / odds / name
--    (desktop 16:9, phone 844x390, tablet 4:3); the camera stays inside the stage; the pack is visible until the hit;
--  * the safety rule, the odds parsing / count-up, the layout bands, the sound cue sheets (only known slots, the hit layers, loops end).
local W=require('./world');local R=W.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
W.env.CFrame=R.CFrame
local L=W.module('RarePullRules');local Seq=W.module('RarityRevealSequence');local Packs=W.module('SeedPackRules');local B=W.module('BalanceRules')
local Sounds=W.module('RarePullSounds')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
-- 1. the server timeline is unchanged -----------------------------------------------------------------------------------------------------
check(Seq.SeedAt(1)==.1 and Seq.SeedAt(4)==.7 and Seq.SeedAt(5)==1 and Seq.SeedAt(6)==1.35 and Seq.SeedAt(7)==2.45 and Seq.SeedAt(8)==3.35,'the server timeline (SeedAt, so RevealDuration) is unchanged')
for rank=1,8 do
 for _,quick in ipairs({false,true})do
  local at=L.BurstAt(rank,quick);local dur=Packs.GetRevealDuration(names[rank])
  local hover=L.Hover(rank,at,dur)
  check(hover>=.12,('%s%s: the seed still hovers (%.2f s)'):format(names[rank],quick and' quick'or'',hover))
  check(near(at+B.SeedRiseSeconds+hover+B.SeedSlideSeconds,dur,1e-9)or hover==.12,('%s%s: the seed\'s slide still ends with the server\'s RevealDuration (%.2f s)'):format(names[rank],quick and' quick'or'',dur))
  if rank>=6 then check(at==Seq.SeedAt(rank)and near(hover,B.SeedHoverSeconds),names[rank]..': the world seed keeps its old timing (the story scene runs on the opener\'s screen)')end
 end
 local r,s=L.SeedPhase(.2,L.Hover(rank,L.BurstAt(rank),Packs.GetRevealDuration(names[rank])))
 if rank>=6 then local r0,s0=B.SeedPhase(.2);check(r==r0 and s==s0,names[rank]..': SeedPhase equals BalanceRules.SeedPhase')end
end
-- 2. the ladder: suspense and card -------------------------------------------------------------------------------------------------------
local lastBurst,lastLen=0,0
local targets={1.2,1.5,2.0,3.5,4.5}
for rank=1,5 do
 local at=L.BurstAt(rank);local q=L.BurstAt(rank,true);local tl=L.CardTimeline(rank);local tq=L.CardTimeline(rank,true)
 check(at>lastBurst,names[rank]..': a longer suspense than the tier below ('..at..' s)')
 check(at>=Seq.SeedAt(rank),names[rank]..': the seed comes out no earlier than before')
 check(q<at and tq.Length<tl.Length,names[rank]..': quick reveals are shorter ('..q..' / '..string.format('%.2f',tq.Length)..' s)')
 check(tl.Length>lastLen,names[rank]..': a longer presentation than the tier below ('..string.format('%.2f',tl.Length)..' s)')
 check(math.abs(tl.Out-targets[rank])<=.3,('%s: about %.1f s from the 5th click to the card fading (%.2f s)'):format(names[rank],targets[rank],tl.Out))
 check(tl.Burst<=tl.Count and tl.Count<tl.Odds and tl.Odds<tl.FloatEnd and tl.FloatEnd<=tl.Out and tl.Out<tl.Length,names[rank]..': card beats in order (burst, count, slam, float, out)')
 lastBurst,lastLen=at,tl.Length
end
check(L.BurstAt(1)<=.65,'Common stays snappy: '..L.BurstAt(1)..' s of tension')
check(L.BurstAt(5)<=Seq.SeedAt(6),'no jump between Mythic and Secret: Mythic\'s suspense ('..L.BurstAt(5)..' s) does not outlast Secret\'s world charge ('..Seq.SeedAt(6)..' s)')
check(L.InPlace(6).Length>=L.CardTimeline(5).Length*.75,'Secret in place is not a step down from Mythic ('..string.format('%.2f / %.2f s',L.InPlace(6).Length,L.CardTimeline(5).Length)..')')
check(L.CardTimeline(5).Letterbox and not L.CardTimeline(4).Letterbox,'Mythic brings a brief letterbox, Legendary not')
check(L.Tiers[4].Rays and L.Tiers[5].Shock and L.Tiers[4].Push>0 and L.Tiers[1].Push==0,'Legendary: light rays and a short camera push; Mythic: a coloured shockwave')
-- 3. the suspense hint, wobble, tear -----------------------------------------------------------------------------------------------------
local function key(c)return string.format('%d,%d,%d',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
for rank=1,8 do
 local c0=L.Hint(rank,0);local c1=L.Hint(rank,1)
 check(key(c0)==key(L.Neutral),names[rank]..': the hint starts neutral')
 check(key(c1)==key(L.Tiers[rank].Hint),names[rank]..': the hint ends on the real tier colour')
 local seen={};for i=0,400 do seen[key((L.Hint(rank,i/400)))]=true end
 local all=true;for r=1,rank do if not seen[key(L.Tiers[r].Hint)]then all=false end end
 check(all,names[rank]..': on the way it flickers through every lower tier colour (it could be...)')
 local higher=false;for r=rank+1,8 do if seen[key(L.Tiers[r].Hint)]then higher=true end end
 check(not higher,names[rank]..': it never shows a HIGHER tier colour (no false hope)')
 local at=L.BurstAt(rank)
 local function amp(t)local c=L.Wobble(rank,t,false,false);return c.Position.Magnitude+math.abs(c.R[1][2])+math.abs(c.R[2][1])end
 local early,late=0,0;for i=1,20 do early=math.max(early,amp(at*.1*i/20));late=math.max(late,amp(at*(.8+.18*i/20)))end
 check(late>early,names[rank]..': the wobble grows toward the burst')
 -- (R152: it settles over SettleSeconds after the burst instead of snapping straight on the burst frame)
 check(amp(at+(L.SettleSeconds or 0)+.01)==0 and amp(at+1)==0 and amp(at+.005)<=late*1.05+1e-6,names[rank]..': the pack is still after the burst (settling from where it was)')
 check(L.Wobble(rank,at*.7,false,true).Position.Magnitude==0,names[rank]..': ReducedMotion: no wobble')
 local pulses=L.Pulses(rank);local ok=#pulses>=1
 for i,p in ipairs(pulses)do if p<=0 or p>=at or(i>1 and p<=pulses[i-1])then ok=false end end
 check(ok,names[rank]..': '..#pulses..' wobble pulses inside the suspense')
 local open0,openMid,openEnd=0,0,0
 for i=1,8 do open0+=L.StripPeel(rank,0.001,i)>0 and 1 or 0;openMid+=L.StripPeel(rank,at*.5,i)>=1 and 1 or 0;openEnd+=L.StripPeel(rank,at,i)>=1 and 1 or 0 end
 check(open0>=1 and open0<=2 and openMid>open0 and openMid<8 and openEnd==8,('%s: the pack tears a little at a time (%d, %d, %d of 8 strips)'):format(names[rank],open0,openMid,openEnd))
 check(L.Glow(rank,at*.95)>L.Glow(rank,at*.2),names[rank]..': the seam glows brighter as it builds')
end
-- 4. the story scenes ------------------------------------------------------------------------------------------------------------------------
local order={'Dim','Cut','SceneIn','Silence','Climax','FloatEnd','Back','Length'}
local lengths={}
for rank=6,8 do
 for _,variant in ipairs({'Full','Calm'})do
  local tl=L.Timeline(rank,variant);local tag=names[rank]..' '..variant
  local okOrder=true;for i=2,#order do if not(tl[order[i]]>tl[order[i-1]])then okOrder=false;print('  order',tag,order[i-1],order[i])end end
  check(okOrder,tag..': beats in order (dim, cut, scene, silence, hit, seed down, back, done)')
  check(tl.Climax-tl.Silence>=.08 and tl.Climax-tl.Silence<=.15,tag..': a short silence right before the hit ('..string.format('%.2f',tl.Climax-tl.Silence)..' s)')
  check(tl.SkipFrom>tl.SceneIn and tl.SkipFrom<tl.Climax,tag..': skippable from '..tl.SkipFrom..' s (in the scene, before the hit)')
  check(tl.Odds>tl.Climax and tl.Odds<tl.FloatEnd,tag..': "1 in N" slams after the hit and before the seed is down')
  check(tl.FloatEnd-math.max(tl.Rise,tl.StarIn or 0)>=.9,tag..': the seed floats down for '..string.format('%.2f',tl.FloatEnd-math.max(tl.Rise,tl.StarIn or 0))..' s')
  lengths[tag]=tl.Length
  -- cue sheet
  local cues=L.SceneCues(rank,tl);local known=true;local loopsEnd=true;local inSilence={};local atHit={}
  for _,c in ipairs(cues)do
   if not Sounds.Slots[c.Slot]then known=false;print('  unknown slot',c.Slot)end
   local loop=Sounds.Slots[c.Slot]and Sounds.Slots[c.Slot].Loop
   if loop and not c.Until then loopsEnd=false end
   if c.At>tl.Silence+1e-6 and c.At<tl.Climax-1e-6 then inSilence[#inSilence+1]=c.Slot end
   if near(c.At,tl.Climax)then atHit[c.Slot]=true end
   if loop and c.Until and c.Until>tl.Silence+1e-6 and c.At<tl.Silence then loopsEnd=false;print('  loop over the silence',c.Slot)end
  end
  check(known,tag..': every cue is a RarePullSounds slot')
  check(loopsEnd,tag..': every loop ends (and drops out for the silence)')
  check(#inSilence==0,tag..': nothing starts inside the silence ('..table.concat(inSilence,',')..')')
  check((atHit.Impact or(rank==7 and atHit.CosmicBoom))and atHit.GroundImpact and atHit.PackBurst,tag..': the hit is the big impact (Cosmic: its supernova boom) + GroundImpact + PackBurst + the tier sting')
  check((rank==8 and atHit.KingFanfare)or(rank==7 and atHit.CosmicBoom)or(rank==6 and atHit.SecretGlitch),tag..': the tier sting on the hit')
  local slam=false;for _,c in ipairs(cues)do if c.Slot=='TitleSlam'and near(c.At,tl.Odds)then slam=true end end
  check(slam,tag..': TitleSlam on the "1 in N" slam')
  for _,c in ipairs(cues)do if(c.Slot=='Riser'or c.Slot=='SuckIn')and c.Until then check(near(c.Until,tl.Silence),tag..': '..c.Slot..' ends ON the silence')end end
 end
 local ip=L.Timeline(rank,'InPlace')
 check(near(ip.Climax,Seq.SeedAt(rank)),names[rank]..' in place: the hit is on the world seed\'s burst')
end
check(lengths['Secret Full']<lengths['Cosmic Full']and lengths['Cosmic Full']<lengths['King Full'],'escalation: Secret < Cosmic < King ('..lengths['Secret Full']..' / '..lengths['Cosmic Full']..' / '..lengths['King Full']..' s)')
check(L.Timeline(6,'Full').Climax<L.Timeline(7,'Full').Climax and L.Timeline(7,'Full').Climax<L.Timeline(8,'Full').Climax,'escalation: longer build-ups up the ladder')
for rank=6,8 do check(lengths[names[rank]..' Calm']<lengths[names[rank]..' Full']-1,names[rank]..': ReducedMotion is shorter ('..lengths[names[rank]..' Calm']..' s)')end
check(L.Timeline(8,'Full').Climax>=5 and L.Timeline(8,'Full').Length<=10.5,'King: the most epic (hit at '..L.Timeline(8,'Full').Climax..' s, '..L.Timeline(8,'Full').Length..' s in all)')
-- 5. framing -----------------------------------------------------------------------------------------------------------------------------
local aspects={{'desktop',1280/720,false},{'phone',844/390,true},{'tablet',4/3,false}}
local boxes={[6]={35,-35,35,0,34},[7]={65,-75,55,0,90},[8]={15,-13,35,0,24}}
for rank=6,8 do
 for _,variant in ipairs({'Full','Calm'})do
  local tl=L.Timeline(rank,variant);local tag=names[rank]..' '..variant
  for _,a in ipairs(aspects)do
   local lay=L.Layout(a[3],false,rank)
   local worst={dx=0,dy=0,overlap=nil,small=nil,maxDia=0,endDia=0}
   local samples={tl.Climax+.02}
   for t=tl.Climax+.1,tl.FloatEnd,.05 do samples[#samples+1]=t end
   samples[#samples+1]=tl.FloatEnd
   for _,t in ipairs(samples)do
    local eye,target,fov=L.Shot(rank,variant,t,tl)
    local seed,alpha=L.SeedPose(rank,tl,t)
    local x,y,z=L.Project(eye,target,fov,a[2],seed)
    if not x then worst.overlap='behind the camera at '..t
    else
     local r=L.ProjectedRadius(fov,z,L.SeedHeroSize*.5)
     worst.dx=math.max(worst.dx,math.abs(x-.5));worst.dy=math.max(worst.dy,math.abs(y-.5))
     local titleBottom=lay.Title.Y+lay.Title.H/2
     if t>=tl.Climax+.12 and y-r<titleBottom-.005 then worst.overlap=string.format('title at %.2f s (seed top %.3f < %.3f)',t,y-r,titleBottom)end
     if t>=tl.Climax+L.SceneCountDelay and y+r>lay.Odds.Y-lay.Odds.H/2+.005 then worst.overlap=string.format('odds at %.2f s (seed bottom %.3f > %.3f)',t,y+r,lay.Odds.Y-lay.Odds.H/2)end
     -- the hero: from .3 s after the hit at least .30 of the screen height, at the end .35-.45 (the owner: the seed is the main focus)
     if t>=tl.Climax+.3 and 2*r<.30 then worst.small=string.format('%.3f of the height at %.2f s',2*r,t)end
     worst.maxDia=math.max(worst.maxDia,2*r);if t>=tl.FloatEnd-.01 then worst.endDia=2*r end
    end
   end
   check(worst.dx<=.12 and worst.dy<=.16,('%s %s: the seed stays near the centre from the hit to the end (off by %.3f, %.3f)'):format(tag,a[1],worst.dx,worst.dy))
   check(not worst.overlap,tag..' '..a[1]..': the seed is never under the title / "1 in N" ('..tostring(worst.overlap)..')')
   check(not worst.small,tag..' '..a[1]..': the seed is big on screen from .3 s after the hit ('..tostring(worst.small)..')')
   check(worst.endDia>=.35 and worst.maxDia<=.45,('%s %s: the seed fills the end shot (%.0f%% of the height; at most %.0f%%)'):format(tag,a[1],worst.endDia*100,worst.maxDia*100))
  end
  -- the seed is fully visible from just after the hit; the pack until the hit
  local ok=true
  for t=tl.Climax+.1,tl.FloatEnd,.1 do local _,alpha=L.SeedPose(rank,tl,t);if alpha<1 then ok=false end end
  check(ok,tag..': the seed is fully shown from the hit to the end')
  local before=rank==7 and tl.Implode-.05 or tl.Climax-.05 -- (Cosmic: the pack implodes before the supernova)
  local _,_,_,a0=L.PackPose(rank,tl,before);local _,_,_,a1=L.PackPose(rank,tl,tl.Climax+.15)
  check(a0==1 and a1==0,tag..': the pack is there until the hit'..(rank==7 and' (its implosion)'or'')..' and gone after it')
  -- the camera never leaves the stage box
  local b=boxes[rank];local inside=true
  for t=tl.SceneIn,tl.Back,.05 do local eye=L.Shot(rank,variant,t,tl);if math.abs(eye.X)>b[1]or eye.Z<b[2]or eye.Z>b[3]or eye.Y<=b[4]or eye.Y>=b[5]then inside=false end end
  check(inside,tag..': the camera stays inside the stage (the map and sky are never seen)')
 end
end
-- R155: the cinematic camera (RarePullCamera155, the stage's camera from R155 on; RarePullRules.Shot stays as its fallback and Calm's hero shot)
-- keeps the same framing rules for the seed's hero shot - from .3 s after the hit; Cosmic from the star, the owner's answer 2 - and the same box
do local Cam=W.module('RarePullCamera155')
 for rank=6,8 do for _,variant in ipairs({'Full','Calm'})do
  local tl=L.Timeline(rank,variant);local rig=Cam.New(rank,variant,tl);local tag='R155 camera: '..names[rank]..' '..variant
  local from=(variant=='Full'and rank==7)and tl.StarIn or tl.Climax+.3
  for _,a in ipairs(aspects)do
   local lay=L.Layout(a[3],false,rank)
   local worst={dx=0,dy=0,overlap=nil,small=nil,maxDia=0,endDia=0}
   local samples={};for t=from,tl.FloatEnd,.05 do samples[#samples+1]=t end;samples[#samples+1]=tl.FloatEnd
   for _,t in ipairs(samples)do
    local eye,target,fov=Cam.Shot(rig,t,a[2]);local seed=L.SeedPose(rank,tl,t)
    local x,y,z=L.Project(eye,target,fov,a[2],seed)
    if not x then worst.overlap='behind the camera at '..t
    else
     local r=L.ProjectedRadius(fov,z,L.SeedHeroSize*.5)
     worst.dx=math.max(worst.dx,math.abs(x-.5));worst.dy=math.max(worst.dy,math.abs(y-.5))
     if y-r<lay.Title.Y+lay.Title.H/2-.005 then worst.overlap=string.format('title at %.2f s',t)end
     if y+r>lay.Odds.Y-lay.Odds.H/2+.005 then worst.overlap=string.format('odds at %.2f s',t)end
     if 2*r<.30 then worst.small=string.format('%.3f of the height at %.2f s',2*r,t)end
     worst.maxDia=math.max(worst.maxDia,2*r);if t>=tl.FloatEnd-.01 then worst.endDia=2*r end
    end
   end
   check(worst.dx<=.12 and worst.dy<=.16 and not worst.overlap and not worst.small and worst.endDia>=.35 and worst.maxDia<=.45,
    ('%s %s: the seed centred (off %.3f, %.3f), never under the title / "1 in N" (%s), big (%s), %.0f%% at the end (at most %.0f%%)'):format(tag,a[1],worst.dx,worst.dy,tostring(worst.overlap),tostring(worst.small),worst.endDia*100,worst.maxDia*100))
  end
  local b=boxes[rank];local inside=true
  for t=tl.SceneIn-.05,tl.FloatEnd+3,.05 do local eye=Cam.Shot(rig,t,16/9);if math.abs(eye.X)>b[1]or eye.Z<b[2]or eye.Z>b[3]or eye.Y<=b[4]or eye.Y>=b[5]then inside=false end end
  check(inside,tag..': the camera stays inside the stage (the map and sky are never seen)')
 end end
end
-- King: the crown lands on the PACK, then rises with the seed
do local tl=L.Timeline(8,'Full');local pack=L.PackPose(8,tl,tl.CrownOn+.1)
 local c0=L.CrownPose(tl,tl.CrownStart-.1);local c1,_,a1=L.CrownPose(tl,tl.CrownOn+.35);local c2=L.CrownPose(tl,tl.Climax+1) -- (R152: c1 after the little press as it lands)
 check(c0.Y>pack.Y+5,'King: the crown starts high above the throne')
 check(near(c1.Y,pack.Y+L.PackHeroHeight*.5+.32,.02)and near(c1.X,pack.X,.01)and a1==1,'King: the crown settles on top of the pack')
 local seed=L.SeedPose(8,tl,tl.Climax+1);check(c2.Y>seed.Y,'King: after the burst the crown rises with the seed')
 local p0=L.PackPose(8,tl,tl.SceneIn+.05);local p1=L.PackPose(8,tl,tl.Land+.05)
 check(p0.Z>15 and near(p1.Z,L.Points[8].Pack.Z,.05),'King: the pack is carried in from the doors to the throne cushion')
end
do local tl=L.Timeline(7,'Full');local p0=L.PackPose(7,tl,tl.SceneIn+.05);local p1=L.PackPose(7,tl,tl.Drift+.05)
 check((p0-L.Points[7].Pack).Magnitude>5 and(p1-L.Points[7].Pack).Magnitude<.1,'Cosmic: the pack drifts in like a planet')
 local _,_,g0=L.SeedPose(7,tl,tl.Climax+.05);local _,_,g1=L.SeedPose(7,tl,tl.StarIn+.05)
 check(g0>.8 and g1==0,'Cosmic: the seed comes out as a falling star and resolves')
end
-- 6. safety ------------------------------------------------------------------------------------------------------------------------------
local safe={Alive=true,OnTrack=false,KeeperDistance=500,KeeperChasing=false,Ragdoll=false,Running=false,Menu=false,CameraType='Custom',Grounded=true}
check(L.Decide(safe)=='Full','safe: the full story scene')
for k,v in pairs({OnTrack=true,KeeperDistance=30,KeeperChasing=true,Ragdoll=true,Running=true,Menu=true,CameraType='Scriptable',Grounded=false,Alive=false})do
 local s=table.clone(safe);s[k]=v;check(L.Decide(s)=='InPlace','unsafe ('..k..'): the short in-place version')
end
-- R153: the player's "Skip pack animations": the in-place result card even when safe; every card is skippable (from SkipFrom), the story
-- scenes as before; and the short (quick) timing is the setting's alone (no window after the last reveal)
do local s=table.clone(safe);s.SkipCutscenes=true;check(L.Decide(s)=='InPlace','R153: "Skip pack animations" on: the in-place result card, never the story scene')end
for rank=1,5 do local tl=L.CardTimeline(rank);check(tl.SkipFrom and tl.SkipFrom>0 and tl.SkipFrom<tl.Burst-.02 and tl.SkipFrom<tl.FloatEnd,names[rank]..': the card can be skipped from '..tostring(tl.SkipFrom)..' s, before its hit')end
for rank=6,8 do for _,v in ipairs({'InPlace','Result'})do local tl=L.Timeline(rank,v);check(tl.SkipFrom and tl.SkipFrom<tl.FloatEnd,names[rank]..' '..v..': skippable too ('..tostring(tl.SkipFrom)..' s)')end end
check(L.QuickWindow==nil and L.QuickFor(nil)==false,'R153: no quick window: without the setting a reveal is never short')
-- 7. odds ------------------------------------------------------------------------------------------------------------------------------
local tip='Storm Seed Pack\nStatic Grass: 1/2\nStorm Sovereign: 1/1.67B\nBlackout Bloom: 1/12K\nVolt Orchid: 1/1,250'
check(L.TooltipOdds(tip,'Storm Sovereign')=='1.67B'and L.TooltipOdds(tip,'Blackout Bloom')=='12K'and L.TooltipOdds(tip,'Volt Orchid')=='1,250','the held pack\'s tooltip gives the seed\'s own odds')
check(L.TooltipOdds(tip,'Nope')==nil,'a seed not in the tooltip: no odds from it')
check(L.ParseCount('1.67B')==1.67e9 and L.ParseCount('12K')==12000 and L.ParseCount('1,250')==1250,'counts parse back to numbers')
check(L.CountText('12K',1)=='1 in 12K'and L.CountText('1.67B',1)=='1 in 1.67B','the slam shows the exact OddsText85 text')
local prev=0;local mono=true
for i=0,20 do local n=L.ParseCount((L.CountText('1.67B',i/20)):sub(6));if not n or n<prev then mono=false end;prev=n or prev end
check(mono,'"1 in N" counts up')
-- 8. layout --------------------------------------------------------------------------------------------------------------------------------
for _,phone in ipairs({false,true})do for rank=1,8 do
 local l=L.Layout(phone,false,rank)
 check(l.Title.Y+l.Title.H/2<=l.Seed.Y-l.Seed.H/2+.001 and l.Seed.Y+l.Seed.H/2<=l.Odds.Y-l.Odds.H/2+.001 and l.Odds.Y+l.Odds.H/2<=l.Name.Y-l.Name.H/2+.02 and l.Name.Y+l.Name.H/2<=1-l.Bar,
  (phone and'phone 'or'desktop ')..names[rank]..': title, seed, odds, name and letterbox never overlap')
 check(l.Title.Y-l.Title.H/2>=l.Bar-.001,(phone and'phone 'or'desktop ')..names[rank]..': the title clears the letterbox')
end end
local c=L.Layout(true,true,6);check(c.Name.Y+c.Name.H/2<.45,'in place: the compact card stays in the upper part of the screen (the middle stays clear)')
-- 9. ladder cue sheets ---------------------------------------------------------------------------------------------------------------------
for rank=1,5 do
 local cues=L.LadderCues(rank);local tl=L.CardTimeline(rank);local slots={}
 for _,cue in ipairs(cues)do slots[cue.Slot]=(slots[cue.Slot]or 0)+1;check(Sounds.Slots[cue.Slot]~=nil,names[rank]..': '..cue.Slot..' is a slot')end
 check(slots.PackShake==#L.Pulses(rank),names[rank]..': a PackShake on every wobble ('..tostring(slots.PackShake)..')')
 check((slots.Heartbeat or 0)==L.Tiers[rank].Heartbeats,names[rank]..': '..L.Tiers[rank].Heartbeats..' heartbeats build the suspense')
 check(slots.PackBurst==1 and slots.TitleSlam==1,names[rank]..': the burst and the "1 in N" slam')
 check((rank>=4)==(slots.Riser==1),names[rank]..': a riser from Legendary up')
 check((rank>=4)==(slots.GroundImpact==1)and(rank>=5)==(slots.Impact==1),names[rank]..': the hits escalate (Legendary: the ground impact; Mythic: the big impact over it)')
 local q=L.LadderCues(rank,true);check(#q<#cues or rank==1,names[rank]..': quick reveals use fewer layers')
end
print(('R151 rules checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
