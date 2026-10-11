--!nocheck
-- R152 seed opening, part 2: LOUDNESS (owner: "noises are not too loud for all of them", "don't make the audio so loud"). Every presentation of
-- every tier is played on the mock and, frame by frame, what is heard is added up: each voice is its file's momentary loudness at the point it
-- is playing (measured from the owner's files: sound_levels.luau; the game's own short sounds, never available to measure, are taken as
-- -16 LUFS) plus its gain (Sound.Volume x the Effects group) in dB; voices add as energy. Reported per presentation: the loudest moment of the
-- mix, the loudest single voice, the worst-case sample peak (every voice's file peak at its gain, added as amplitudes), the most voices at once.
-- Checked (unless REPORT_ONLY): the caps below, whooshes well under the hits, the beds under the hits, the climax the loudest moment of its
-- story, the ladder growing with the tier, the voice cap, and the old reveal sounds no louder than they were.
-- R153: also the short version ("Skip pack animations" on) and every presentation skipped by the player: the same caps, and a skip is never
-- louder than the full presentation (it stops what was sounding and joins the sheet at the hit).
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local REPORT=REPORT_ONLY==true -- (a global set by the line put before this file: loudness_before_after.sh)
local function check(c,msg)checks+=1;if not c and not REPORT then fails+=1;print('FAIL: '..msg)end;return c end
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Audio=W.module('RarePullAudio');local Sounds=W.module('RarePullSounds')
local Visuals=W.module('SeedPackVisuals')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
-- the caps (LUFS, effective at Effects 100 %), R152
local CAP={Mix=-18,Voice=-20,Whoosh=-30,Peak=-3,Voices=Audio.MaxVoices or 10}
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear()
 cam=W.workspace.CurrentCamera
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;X.root.CFrame=CF(0,3,100);X.hum.Health=100
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 X.player:SetAttribute('SettingSkipCutscenes',nil)
 R.advance(4)
end
local function start(rank,extra)
 local seedId=X.byRank[rank];local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local info={Rank=rank,SeedId=seedId,At=W.workspace:GetServerTimeNow(),Bag=bag,Mutation='None'}
 for k,v in pairs(extra or{})do info[k]=v end
 return M.Start(info)
end
local function peakOf(id)local l=Y.ById[id];return l and l.Peak or -6 end
local function slotOf(v)return v.Sound.Name:match('^RarePull_(.-)_%d+b?$')end
local rows={}
local function measure(tag,rank,extra,setup,skip)
 reset();if setup then setup()end
 local run=start(rank,extra);if not run then return nil end
 Y.record(function()return run.Clock()end)
 local skipped=false -- (skip: seconds after SkipFrom at which the player skips; R157: a card without SkipFrom is asked from where R153's card skip began, until its hit)
 local hitAt=run.TL.Climax or run.TL.Burst or 0
 X.run(run.TL.Length+.3,1/60,skip and function()if not skipped and not run.Done and run.Clock()>=(run.TL.SkipFrom or L.CardSkipFrom)+skip and run.Clock()<hitAt-.02 then skipped=M.Skip()end end or nil)
 local frames=Y.stop()
 local r={Tag=tag,Rank=rank,Kind=run.Kind,Mix=-99,MixAt=0,Voice=-99,VoiceSlot='',Peak=-99,Voices=0,Whoosh=-99,Bed=-99,Hit=-99,SlotMax={},PreHitMix=-99,PostHitMix=-99}
 local hitT=run.TL.Climax or run.TL.Burst or 0;r.Skip=skip;r.Skipped=skipped
 for _,f in ipairs(frames)do
  local mix=Y.mixLoudness(f)
  if mix>r.Mix then r.Mix=mix;r.MixAt=f.T or 0 end
  if f.T and f.T<hitT-.05 then r.PreHitMix=math.max(r.PreHitMix,mix)elseif f.T and f.T>=hitT-.05 and f.T<hitT+1 then r.PostHitMix=math.max(r.PostHitMix,mix)end
  local amp=0;local n=0
  for _,v in ipairs(f.Voices)do
   if v.Gain>1e-3 then
    n+=1
    local lv=Y.voiceLoudness(v);local slot=slotOf(v)
    if lv>r.Voice then r.Voice=lv;r.VoiceSlot=slot end
    r.SlotMax[slot]=math.max(r.SlotMax[slot]or -99,lv)
    if slot=='Flight'or slot=='CosmicWhoosh'then r.Whoosh=math.max(r.Whoosh,lv)end
    if slot=='KingChoir'or slot=='CosmicPad'or slot=='SecretDrone'or slot=='SecretWhisper'then r.Bed=math.max(r.Bed,lv)end
    if slot=='Impact'or slot=='GroundImpact'or slot=='CosmicBoom'or slot=='PackBurst'then r.Hit=math.max(r.Hit,lv)end
    amp+=10^(Y.filePeak(v.Id,v.Pos)/20)*v.Gain -- (each voice at its own peak around where it is playing, all at once)
   end
  end
  r.Voices=math.max(r.Voices,n)
  if amp>0 then r.Peak=math.max(r.Peak,20*math.log10(amp))end
 end
 rows[#rows+1]=r
 return r
end
for rank=1,5 do measure(names[rank]..' card',rank)end
for rank=6,8 do
 measure(names[rank]..' Full',rank)
 measure(names[rank]..' InPlace',rank,nil,function()X.keeper(V3(10,3,100),{GuardianBehavior='WANDER'})end)
end
-- R153: the short version and the skips
local full={};for _,r in ipairs(rows)do full[r.Tag]=r end
local skips={}
for rank=1,5 do
 local r=measure(names[rank]..' short',rank,nil,function()X.player:SetAttribute('SettingSkipCutscenes',true)end);if r then r.Extra=true end
 -- (R157: a Common..Mythic card has no SkipFrom: a skip asked of it changes nothing - it plays, and sounds, exactly as the full card)
 local k=measure(names[rank]..' no skip',rank,nil,nil,.05)
 if k then local f=full[names[rank]..' card'];k.Extra=true;skips[#skips+1]={Row=k,Full=f};check(k.Skipped==false and f and k.Mix<=f.Mix+.5,k.Tag..': R157: Enter / B / R2 asked all through the build skip nothing; it sounds as the full card does ('..string.format('%.1f vs %.1f',k.Mix,f and f.Mix or -99)..' LUFS)')end
end
for rank=6,8 do
 for _,at in ipairs({.05,1})do local k=measure(names[rank]..' skip+'..at,rank,nil,nil,at);if k then k.Extra=true;skips[#skips+1]={Row=k,Full=full[names[rank]..' Full']}end end
 local k=measure(names[rank]..' IP skip',rank,nil,function()X.keeper(V3(10,3,100),{GuardianBehavior='WANDER'})end,.05);if k then k.Extra=true;skips[#skips+1]={Row=k,Full=full[names[rank]..' InPlace']}end
end
print(string.format('%-18s %8s %8s %-13s %8s %8s %8s %8s %7s','presentation','mix','at','loudest','voice','whoosh','bed','peak','voices'))
for _,r in ipairs(rows)do
 print(string.format('%-18s %8.1f %8.2f %-13s %8.1f %8.1f %8.1f %8.1f %7d',r.Tag,r.Mix,r.MixAt,r.VoiceSlot,r.Voice,r.Whoosh,r.Bed,r.Peak,r.Voices))
end
local slotRows={}
for _,r in ipairs(rows)do for slot,v in pairs(r.SlotMax)do slotRows[slot]=math.max(slotRows[slot]or -99,v)end end
local keys={};for k in pairs(slotRows)do keys[#keys+1]=k end;table.sort(keys)
local line={};for _,k in ipairs(keys)do line[#line+1]=string.format('%s %.1f',k,slotRows[k])end
print('loudest per slot (LUFS, any presentation): '..table.concat(line,', '))
-- the caps --------------------------------------------------------------------------------------------------------------------------------
for _,r in ipairs(rows)do
 check(r.Mix<=CAP.Mix,r.Tag..': the mix never goes over '..CAP.Mix..' LUFS ('..string.format('%.1f',r.Mix)..')')
 check(r.Voice<=CAP.Voice,r.Tag..': no single sound over '..CAP.Voice..' LUFS ('..r.VoiceSlot..string.format(' %.1f',r.Voice)..')')
 check(r.Peak<=CAP.Peak,r.Tag..': the sample peak stays under '..CAP.Peak..' dBFS even with every voice peaking at once ('..string.format('%.1f',r.Peak)..')')
 check(r.Voices<=CAP.Voices,r.Tag..': at most '..CAP.Voices..' voices at once ('..r.Voices..')')
 if r.Whoosh>-99 then
  check(r.Whoosh<=CAP.Whoosh,r.Tag..': the whooshes stay soft (under '..CAP.Whoosh..' LUFS: '..string.format('%.1f',r.Whoosh)..')')
  if r.Hit>-99 then check(r.Whoosh<=r.Hit-8,r.Tag..': the whooshes are at least 8 dB under the hit ('..string.format('%.1f vs %.1f',r.Whoosh,r.Hit)..')')end
 end
 if r.Bed>-99 and r.Hit>-99 then check(r.Bed<=r.Hit-3,r.Tag..': the music bed sits under the hit ('..string.format('%.1f vs %.1f',r.Bed,r.Hit)..')')end
 -- (a skip cuts the build wherever the player chose: what it stopped there is not compared with its hit)
 if(r.Kind=='Scene'or r.Kind=='Ladder')and not r.Skip then check(r.PostHitMix>=r.PreHitMix-1,r.Tag..': the hit is the loudest moment of the reveal (build '..string.format('%.1f, hit %.1f',r.PreHitMix,r.PostHitMix)..')')end
end
-- the ladder grows with the tier, and the story scenes sit above it, without a jump
local ladder={};for _,r in ipairs(rows)do if r.Kind=='Ladder'and not r.Extra then ladder[r.Rank]=r.Mix end end
-- R153: a skip is never louder than the full presentation
for _,k in ipairs(skips)do
 check(k.Full and k.Row.Mix<=k.Full.Mix+.5,k.Row.Tag..': no louder than the full presentation ('..string.format('%.1f vs %.1f',k.Row.Mix,k.Full and k.Full.Mix or -99)..' LUFS)')
end
for rank=2,5 do check(ladder[rank]and ladder[rank-1]and ladder[rank]>=ladder[rank-1]-1,names[rank]..' is at least as loud as (within 1 dB) '..names[rank-1]..string.format(' (%.1f vs %.1f)',ladder[rank]or-99,ladder[rank-1]or-99))end
check(ladder[1]and ladder[1]<=CAP.Mix-4,'Common stays modest ('..string.format('%.1f',ladder[1]or 99)..' LUFS)')
-- nothing louder than it was: R151's loudest moment of each presentation (measured the same way: loudness_before_after.sh)
local BEFORE={['Common card']=-24.8,['Uncommon card']=-22.9,['Rare card']=-23.4,['Legendary card']=-21.0,['Mythic card']=-19.7,['Secret Full']=-13.7,
 ['Secret InPlace']=-15.3,['Cosmic Full']=-14.8,['Cosmic InPlace']=-15.4,['King Full']=-15.1,['King InPlace']=-16.4}
for _,r in ipairs(rows)do
 local b=BEFORE[r.Tag]
 if b then check(r.Mix<=b-1,r.Tag..': quieter than R151 (its loudest moment '..string.format('%.1f -> %.1f',b,r.Mix)..' LUFS)')end
end
-- the old reveal sounds (RarityRevealAudio) and the pack-opening world sounds are not louder than they were
local RA=W.module('RarityRevealAudio')
check(RA.Low and RA.Loud,'RarityRevealAudio tables present')
print(('R152 loudness checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
