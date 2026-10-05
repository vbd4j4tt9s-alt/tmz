--!nocheck
-- R150 sounds of the treadmill bonus UI with the REAL InteractionAudio / RarityRevealAudio / SoundTiming / AudioMixer on the Roblox mock.
-- New Sounds start cold (not loaded) and load 0.1 s after creation, or 0.05 s after ContentProvider:PreloadAsync; every :Play() is recorded
-- with whether the sound was loaded at that moment. Checks:
--  * the very first tick of the very first roll sounds (the tick voices are built and preloaded at script start, not at the first tick),
--    every tick plays on a loaded voice, rises in pitch, never faster than 30/s, and no Sound is created per tick;
--  * the "roll ready" cue plays in the same call as the sparkles / pops, through the Effects group (Effects volume 0 mutes it), at most one
--    per 0.25 s, never on a decrease;
--  * the reveal sounds play on the frame the reveal word appears; a double Skip tap reveals (and sounds) once; rapid taps never stack requests.
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local C=UW.boot({realAudio=true})
local Rules,me=C.Rules,C.Me
local Style=W.module('TreadmillBonusStyle');local Mixer=W.module('AudioMixer')
local SS=W.service('SoundService')
local audio=UW.audio
local button,panel,hud,bar=C.Button,C.Overlay.Panel,C.Hud,C.Bar
local function plays(from,namePattern)
 local out={};for i=from,#audio.Plays do local p=audio.Plays[i];if not namePattern or p.Name:find(namePattern)then out[#out+1]=p end end;return out
end
-- 1. The tick pool exists and is warm before any roll -----------------------------------------------------------------
local ticks={}
for _,s in ipairs(SS:GetChildren())do if s.Name:match('^Interaction_BonusTick%d$')then ticks[#ticks+1]=s end end
check(#ticks==4,'script start: the four tick voices already exist ('..#ticks..')')
local routed=true;for _,s in ipairs(ticks)do if not(s.SoundGroup and s.SoundGroup.Name=='GardenInterface')then routed=false end end
check(routed,'tick voices are routed through the mixer (Interface group, as the other UI clicks)')
local preloaded=false
for _,list in ipairs(audio.Preloads)do local hit=0;for _,s in ipairs(list)do if s.Name:match('^Interaction_BonusTick%d$')then hit+=1 end end;if hit==4 then preloaded=true end end
check(preloaded,'script start: ContentProvider:PreloadAsync is asked for all four tick voices')
local coldAtStart=true;for _,s in ipairs(ticks)do if s.IsLoaded then coldAtStart=false end end
check(coldAtStart,'(the test world: the voices are still loading at that moment, like a fresh join)')
UW.seconds(.3,1/60)
local allLoaded=true;for _,s in ipairs(ticks)do if not s.IsLoaded then allLoaded=false end end
check(allLoaded,'a moment later they are loaded')
local soundsBefore=#SS:GetChildren()
-- 2. The first roll: every tick sounds, the first one included ---------------------------------------------------------
local lastSpin
do local real=Rules.NewSpin;Rules.NewSpin=function(opts)lastSpin=real(opts);return lastSpin end end
local function roll(case,readyAfter)
 C.Reply={Ok=true,Stage=case.Stage,Variant=case.Variant,Rarity=case.Rarity,Label=case.Label,Pool='1,6,2,3,4,5,7',Ready=readyAfter or 0}
 C.set('Ready',1);UW.frames(1,1/60)
 local at=R.clock;button.Activated:Fire()
 panel.StripWindow.AbsoluteSize=R.Vector2.new(panel.Size.X.Offset-28,panel.StripWindow.Size.Y.Offset)
 return at
end
local cases={Common={Rarity='Common',Variant='Pack01',Stage=1,Label='Forest Seed Pack'},Legendary={Rarity='Legendary',Variant='Pack05',Stage=4,Label='Lava Seed Pack'}}
local mark=#audio.Plays+1
local startAt=roll(cases.Common,0)
local frameOfReveal,revealPlays
local n=0
while panel.Actions.Skip.Visible and n<2000 do UW.frames(1,1/60);n+=1 end
local tickPlays=plays(mark,'^Interaction_BonusTick')
check(lastSpin and lastSpin.Ticks>=35,'the strip passes '..(lastSpin and lastSpin.Ticks or 0)..' cards')
check(lastSpin and #tickPlays==lastSpin.Ticks,'every tick is heard, the very first included ('..#tickPlays..' played of '..(lastSpin and lastSpin.Ticks or 0)..' requested)')
check(#tickPlays>0 and tickPlays[1].At-startAt<.2,'the first tick sounds within a fraction of a second of the click ('..(#tickPlays>0 and string.format('%.3f',tickPlays[1].At-startAt)or'none')..' s)')
local cold=0;for _,p in ipairs(tickPlays)do if not p.Loaded then cold+=1 end end
check(cold==0,'no tick is played on a voice that was still loading')
local fast=false;for i=2,#tickPlays do if tickPlays[i].At-tickPlays[i-1].At<1/30-1e-6 then fast=true end end
check(not fast,'ticks never faster than 30 per second')
check(#tickPlays>1 and tickPlays[#tickPlays].Pitch>tickPlays[1].Pitch,'tick pitch rises as the strip slows')
check(#SS:GetChildren()==soundsBefore,'no Sound is created while ticking ('..(#SS:GetChildren()-soundsBefore)..' new)')
local groups=true;for _,p in ipairs(tickPlays)do if not(p.Group and p.Group.Name=='GardenInterface')then groups=false end end
check(groups,'every tick plays through the Interface group')
panel.Actions.Close.Activated:Fire()
-- 3. The roll-ready cue ---------------------------------------------------------------------------------------------------
me:SetAttribute('TreadmillTraining',true);C.set('Interval',360);C.set('DueAt',R.clock+300);C.set('Left',300);C.set('Ready',0);UW.seconds(2,1/60)
mark=#audio.Plays+1
local clockBefore=R.clock
C.set('Ready',1) -- no frame has run yet
local cue=plays(mark,'^Reveal_')
check(#cue==1 and cue[1].Name=='Reveal_Note' and cue[1].Loaded,'a roll becoming ready: one bright note ('..#cue..(cue[1]and(' '..cue[1].Name)or'')..')')
check(R.clock==clockBefore and #hud.Fx:GetChildren()==8 and #bar.Fx:GetChildren()==8 and bar.Back.Caption.Text:find('BONUS READY')~=nil,'...on the same frame as the button sparkles (8), the timer sparkles (8) and "BONUS READY!"')
check(cue[1].Group and cue[1].Group.Name=='GardenEffects','the cue goes through the Effects group')
check(cue[1].Pitch>1.2,'the first ready note is bright ('..cue[1].Pitch..')')
UW.seconds(.3,1/60)
-- Effects volume 0 mutes it
Mixer.Set('Effects',0)
mark=#audio.Plays+1
C.set('Ready',2)
cue=plays(mark,'^Reveal_')
check(#cue==1 and cue[1].Name=='Reveal_Note2' and cue[1].Group.Volume==0,'second ready: a higher note, and with Effects at 0 its group is silent (group volume '..(cue[1]and cue[1].Group.Volume or'?')..')')
check(cue[1].Pitch>1.5,'the second ready note is higher ('..cue[1].Pitch..')')
Mixer.Set('Effects',100)
-- a decrease is silent
UW.seconds(.5,1/60);mark=#audio.Plays+1
C.set('Ready',1);check(#plays(mark,'^Reveal_')==0,'a roll used: no cue')
C.set('Ready',0);UW.seconds(1,1/60)
-- rapid changes do not stack
mark=#audio.Plays+1
for i=1,6 do C.set('Ready',i%2==1 and 1 or 0);UW.frames(1,1/60)end
C.set('Ready',1);UW.frames(1,1/60)
check(#plays(mark,'^Reveal_')==1,'a flurry of ready changes inside 0.25 s makes one sound ('..#plays(mark,'^Reveal_')..')')
UW.seconds(.4,1/60);C.set('Ready',0);UW.seconds(.4,1/60);mark=#audio.Plays+1;C.set('Ready',1)
check(#plays(mark,'^Reveal_')==1,'and the next ready after the gap sounds again')
C.set('Ready',0);me:SetAttribute('TreadmillTraining',nil);UW.seconds(3,1/60)
-- off the treadmill (no timer): the button alone still gets its cue
mark=#audio.Plays+1;C.set('Ready',1)
check(#plays(mark,'^Reveal_')==1 and #hud.Fx:GetChildren()==8,'a ready roll with no timer showing: cue and button sparkles together')
C.set('Ready',0);UW.seconds(3,1/60)
-- 4. Reveal sounds land on the frame of the reveal -----------------------------------------------------------------------------
mark=#audio.Plays+1
roll(cases.Legendary,0)
local revealClock,wordSeen
n=0
while panel.Actions.Skip.Visible and n<2000 do
 UW.frames(1,1/60);n+=1
 if not wordSeen and panel.Word.Visible then wordSeen=true;revealClock=R.clock end
end
check(wordSeen,'the reveal word appeared')
local atReveal=0;local names={}
for _,p in ipairs(plays(mark))do if p.At==revealClock and not p.Name:match('^Interaction_BonusTick')then atReveal+=1;names[#names+1]=p.Name end end
check(atReveal>=2,'Legendary: the fanfare and the chime play on the frame the word appears ('..table.concat(names,', ')..')')
local gem=false;for _,nm in ipairs(names)do if nm=='Interaction_GemClaim'then gem=true end end
check(gem,'Legendary: the gem-claim chime is one of them')
local effectsOnly=true;for _,p in ipairs(plays(mark))do if p.Name:match('^Reveal_')and not(p.Group and p.Group.Name=='GardenEffects')then effectsOnly=false end end
check(effectsOnly,'the reveal fanfare voices are in the Effects group')
panel.Actions.Close.Activated:Fire()
-- 5. Double Skip, rapid taps ---------------------------------------------------------------------------------------------------------
roll(cases.Legendary,0)
UW.frames(30,1/60)
mark=#audio.Plays+1
panel.Actions.Skip.Activated:Fire();panel.Actions.Skip.Activated:Fire();panel.Actions.Skip.Activated:Fire()
local gemPlays=#plays(mark,'^Interaction_GemClaim');local fx=#panel.Fx:GetChildren()
local expected=Style.Reveal('Legendary').Sparkles+Style.Reveal('Legendary').Confetti
check(gemPlays==1 and fx==expected,'three quick Skip taps reveal once: one chime, one set of pieces ('..gemPlays..', '..fx..' of '..expected..')')
panel.Actions.Close.Activated:Fire()
-- taps on the button right after a roll: nothing is stacked
C.Reply={Ok=true,Stage=1,Variant='Pack01',Rarity='Common',Label='Forest Seed Pack',Pool='1',Ready=0}
C.set('Ready',1);UW.frames(1,1/60)
local invoked=C.Invoked
for i=1,5 do button.Activated:Fire()end
check(C.Invoked==invoked+1,'five rapid taps ask the server once ('..(C.Invoked-invoked)..')')
panel.Actions.Skip.Activated:Fire();panel.Actions.Close.Activated:Fire()
-- and nothing was created per sound along the way
UW.seconds(3,1/60)
local reveals=0;for _,s in ipairs(SS:GetChildren())do if s.Name:match('^Reveal_')then reveals+=1 end end
check(reveals==8,'the reveal voice pool stays at its 8 voices ('..reveals..')')
local tickCount=0;for _,s in ipairs(SS:GetChildren())do if s.Name:match('^Interaction_BonusTick%d$')then tickCount+=1 end end
check(tickCount==4,'the tick pool stays at 4 voices')
-- 6. R150 review: every refusal clicks Denied (the built-in ping, low, in the Interface group); a roll that starts never does ----------------------------------
do
 me:SetAttribute('TreadmillTraining',true);C.set('Interval',360);C.set('DueAt',R.clock+300);C.set('Left',300);C.set('Ready',0);UW.seconds(3,1/60)
 local denied=function(from)return plays(from,'^Interaction_Denied$')end
 mark=#audio.Plays+1;button.Activated:Fire()
 local d=denied(mark)
 check(#d==1 and d[1].Loaded and d[1].Group and d[1].Group.Name=='GardenInterface','R150 review: a tap on the charging button plays the Denied ping once, on a loaded voice, in the Interface group ('..#d..')')
 check(d[1] and d[1].Pitch==.55 and d[1].Volume<=.25,'R150 review: ... low and quiet (speed '..tostring(d[1]and d[1].Pitch)..', volume '..tostring(d[1]and d[1].Volume)..')')
 -- a server refusal
 UW.seconds(1,1/60);C.set('Ready',1);UW.frames(1,1/60);C.Reply={Error='SEED BAG FULL! Make room - your roll stays ready.',Ready=1}
 mark=#audio.Plays+1;button.Activated:Fire()
 check(#denied(mark)==1 and #plays(mark,'^Reveal_')==0,'R150 review: a server refusal plays Denied once (nothing else)')
 -- no reply / a failed call
 UW.seconds(1,1/60);C.Reply=nil;mark=#audio.Plays+1;button.Activated:Fire()
 check(#denied(mark)==1,'R150 review: no reply plays Denied once')
 -- two refusals closer than the cue's gap are one sound (InteractionAudio: .25 s)
 mark=#audio.Plays+1;button.Activated:Fire();UW.seconds(.1,1/60);button.Activated:Fire()
 check(#denied(mark)<=1,'R150 review: a refusal tapped twice within .25 s stays one sound ('..#denied(mark)..')')
 -- a roll that starts: spin, reveal and close without a Denied
 UW.seconds(3,1/60);mark=#audio.Plays+1
 roll(cases.Common,0)
 local m=0;while panel.Actions.Skip.Visible and m<2000 do UW.frames(1,1/60);m+=1 end
 panel.Actions.Close.Activated:Fire();UW.seconds(2,1/60)
 roll(cases.Legendary,0);panel.Actions.Skip.Activated:Fire();UW.seconds(1,1/60);panel.Actions.Close.Activated:Fire();UW.seconds(2,1/60)
 check(#denied(mark)==0 and #plays(mark,'^Interaction_BonusTick')>0,'R150 review: two rolls that start, spin and reveal never play Denied')
 C.set('Ready',0);me:SetAttribute('TreadmillTraining',nil);UW.seconds(3,1/60)
end
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
