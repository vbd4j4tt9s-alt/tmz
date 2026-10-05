--!nocheck
-- R136 on the mock with the real modules:
--  * Legendary / Mythic seed pulls: a short charge-up (RarityRevealSequence), then RevealFlourish's burst (pillar,
--    shockwave rings, sparkles, light, a sound for onlookers only); Mythic bigger than Legendary; Common..Rare and
--    Secret+ timing unchanged;
--  * every chance reads 1/N (OddsText85).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Seq=W.module('RarityRevealSequence');local Rules=W.module('SeedPackRules');local F=W.module('RevealFlourish')
-- 1. Timing -------------------------------------------------------------------------------------------------------
check(Seq.SeedAt(4)==.7 and Seq.SeedAt(5)==1,'Legendary .7 s, Mythic 1.0 s charge-up')
check(Seq.SeedAt(1)==.1 and Seq.SeedAt(2)==.1 and Seq.SeedAt(3)==.1,'Common, Uncommon, Rare unchanged')
check(Seq.SeedAt(6)==1.35 and Seq.SeedAt(7)==2.45 and Seq.SeedAt(8)==3.35,'Secret, Cosmic, King unchanged')
check(math.abs(Rules.GetRevealDuration('Legendary')-Rules.GetRevealDuration('Rare')-.6)<1e-9,'the opening lasts .6 s longer for Legendary')
check(math.abs(Rules.GetRevealDuration('Mythic')-Rules.GetRevealDuration('Rare')-.9)<1e-9,'and .9 s longer for Mythic')
-- 2. Flourish -----------------------------------------------------------------------------------------------------
check(F.Create(W.workspace,6,1)==nil and F.Create(W.workspace,8,1)==nil,'Secret and up keep their own reveal (no flourish)')
local minor=F.Create(W.workspace,3,1);check(minor and minor.Style.Minor and minor.Pillar==nil,'R138: Common..Rare get only the small flourish (no pillar)');minor:Destroy()
local emitted={}
local inew=R.Instance.new
R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='ParticleEmitter'then function o.Emit(_,n)emitted[#emitted+1]=n end end;if class=='Sound'then o.IsLoaded=true;o.Loaded=R.signal();o.TimeLength=3;o.TimePosition=0;function o.Play(self)self.IsPlaying=true end end;return o end -- (R150: the onlooker burst goes through SoundTiming.Play, which reads IsLoaded / Loaded like the engine's Sound)
W.env.Instance=R.Instance
local rawEmit=R.Inst.Emit;R.Inst.Emit=function(self,n)if self.ClassName=='ParticleEmitter'then emitted[#emitted+1]=n end;if rawEmit then return rawEmit(self,n)end end
local holder=R.new('Model');holder.Parent=W.workspace
local function run(rank,heard)
 local f=F.Create(holder,rank,1);local mouth=CF(0,2,0);local at=Seq.SeedAt(rank)
 local states={}
 local function visible(name)local n=0;for _,d in ipairs(f.Folder:GetDescendants())do if d.Name==name and d.Transparency<1 then n+=1 end end;return n end
 local function dist(name)local best=0;local count=0;for _,d in ipairs(f.Folder:GetDescendants())do if d.Name==name and d.Transparency<1 then best+=(d.Position-mouth.Position).Magnitude;count+=1 end end;return count>0 and best/count or 0 end
 f:Update(mouth,at*.2,at,heard);states.early={Glow=f.Glow.Transparency,Light=f.Light.Brightness,Motes=visible('Charge mote'),Dist=dist('Charge mote')}
 f:Update(mouth,at*.9,at,heard);states.late={Glow=f.Glow.Transparency,Light=f.Light.Brightness,Motes=visible('Charge mote'),Pillar=f.Pillar.Transparency}
 f:Update(mouth,at+.05,at,heard);states.burst={Pillar=f.Pillar.Size.X,Sound=f.Sound}
 f:Update(mouth,at+.3,at,heard)
 local radius=0;for _,d in ipairs(f.Rings[1])do radius=math.max(radius,(V3(d.Position.X,0,d.Position.Z)-V3(0,0,0)).Magnitude)end
 states.mid={Pillar=f.Pillar.Size.X,Ring=radius,Rings=#f.Rings,Helix=visible('Helix mote'),Motes=visible('Charge mote'),Light=f.Light.Brightness}
 f:Update(mouth,at+.55,at,heard);local radius2=0;for _,d in ipairs(f.Rings[1])do radius2=math.max(radius2,(V3(d.Position.X,0,d.Position.Z)).Magnitude)end;states.mid.Ring2=radius2
 f:Update(mouth,at+F.BurstSeconds+.1,at,heard);states.done=visible('Light pillar')+visible('Shockwave')+visible('Helix mote')+visible('Mouth glow')
 return f,states
end
local leg,L=run(4,true)
check(L.early.Motes>=5 and L.late.Glow<L.early.Glow and L.late.Light>L.early.Light,'charge-up: motes swirl in while the mouth glow and light build')
check(L.late.Pillar==1,'no pillar before the burst')
check(L.burst.Pillar>0 and L.mid.Pillar>L.burst.Pillar and L.mid.Pillar<=7.01,'burst: the pillar shoots up (to 7 studs)')
check(L.mid.Motes==0,'the charge motes are gone once the seed is out')
check(L.mid.Ring2>L.mid.Ring and L.mid.Ring>.5,'the shockwave ring expands')
check(#emitted==1 and emitted[1]==28,'Legendary sparkle burst: 28 sparkles, once')
check(L.burst.Sound~=nil and L.burst.Sound.SoundId==F.SoundId and L.burst.Sound.RollOffMaxDistance<=60,'onlookers hear a burst sound at the bag')
check(L.done==0,'everything fades out after the burst')
local myth,M=run(5,false)
check(M.mid.Rings==2 and L.mid.Rings==1,'Mythic: two shockwave rings (Legendary one)')
check(M.mid.Helix>0 and L.mid.Helix==0,'Mythic: a helix of motes climbs the pillar')
check(#emitted==2 and emitted[2]>emitted[1],'Mythic: a bigger sparkle burst ('..tostring(emitted[2])..')')
check(M.mid.Pillar>L.mid.Pillar,'Mythic: a taller pillar')
check(M.burst.Sound==nil,'the opener hears the 2D reveal sounds instead (no extra sound at their own bag)')
check(myth.Style.Color~=leg.Style.Color,'Legendary gold, Mythic pink-violet')
leg:Destroy();check(leg.Folder.Parent==nil,'destroyed with the reveal')
-- 3. Odds read 1/N ------------------------------------------------------------------------------------------------
local O=W.module('OddsText85')
local cases={{1755016/5475495*100,'1/3'},{23/600*100,'1/26'},{100/30,'1/30'},{.01,'1/10K'},{100/1250,'1/1,250'},{100/240000,'1/240K'},{100,'1/1'},{50,'1/2'},{12,'1/8'},{100/6.3,'1/6'},{100/6.7,'1/7'},{5.98e-8,'1/1.67B'},{100/16.7e9,'1/16.7B'},{100/1.25e6,'1/1.25M'},{100/2.4e6,'1/2.4M'},{0,'—'}} -- R148: whole numbers under a million; M/B keep decimals
local wrong={}
for _,c in ipairs(cases)do local got=O.Format(c[1]);if got~=c[2]then wrong[#wrong+1]=('%s gave %s (want %s)'):format(tostring(c[1]),got,c[2])end end
check(#wrong==0,'odds read 1/N: '..table.concat(wrong,'; '))
local fractions=0
for i=1,2000 do local p=100/(1+i*3.37);local got=O.Format(p);if not(got:match('^1/[%d,]+K?$')or got:match('^1/[%d%.]+[MBTQa]+$'))then fractions+=1 end end -- R148: whole under a million
check(fractions==0,'2000 chances all read 1/N ('..fractions..' do not)')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
