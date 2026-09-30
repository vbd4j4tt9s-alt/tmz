--!nocheck
-- Offline checks for PlantingEffects (real module + real PlantCatalog under the Roblox mock).
local World=require('./world')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local function approx(a,b,e)return math.abs(a-b)<=(e or 1e-3)end

local function setup(opts)
 local W=World.build(opts)
 local R=W.R;local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
 W.camera.CFrame=R.CFrame.lookAt(V3(0,14,-22),V3(0,0,0))
 local map=new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
 local base=new('Model');base.Name='Base_1';base.Parent=map
 local plots=new('Folder');plots.Name='GardenPlots';plots.Parent=base
 local plot=new('Part');plot.Name='DirtPlot_1';plot.Size=V3(46,.8,22.6);plot.CFrame=CF(0,.4,0);plot.Color=R.Color3.fromRGB(112,75,45)
 plot:SetAttribute('GardenSoil',true);plot:SetAttribute('GardenOwnerId',opts and opts.Owner or 1);plot.Parent=plots
 W.map=map;W.plot=plot
 local serial=0
 function W.crop(seed,x,z,plantedAt,scale,parent,id)
  serial+=1
  local m=new('Model');m.Name='Crop_'..serial
  for k,v in pairs({GardenGenerated=true,GardenPlantV141=true,CropId=id or('crop-'..serial),SeedId=seed,GrowthStage=1,OffsetX=x,OffsetZ=z,PlantScale=scale or 1,PlantedAt=plantedAt,MatureAt=plantedAt+60})do m:SetAttribute(k,v)end
  local a=new('Part');a.Name='CropAnchor';a.Size=V3(.1,.1,.1);a.CFrame=(parent or plot).CFrame*CF(x,(parent or plot).Size.Y/2+.025,z);a.Parent=m
  m.PrimaryPart=a;m.Parent=parent or plot
  return m
 end
 W.P=W.req(W.RS.PlantingEffects)
 return W
end
local function parts(W,name)local out={};for _,p in ipairs(W.workspace.LocalPlantingEffects:GetChildren())do if p.Name==name then table.insert(out,p)end end;return out end
local function visible(list)local n=0;for _,p in ipairs(list)do if p.Transparency<1 then n+=1 end end;return n end
local function marks(W)return visible(parts(W,'Planting mark'))end
local function soilTop(W)return W.plot.CFrame.Position.Y+W.plot.Size.Y/2 end
local function sounds(W,prefix)local n={};for _,p in ipairs(W.plays)do if p.Name:sub(1,#prefix)==prefix then n[p.Name]=(n[p.Name]or 0)+1 end end;return n end

-- 1. Join / garden load: existing crops (even a young one) never pile; every crop gets a mark ----------------------
do
 local W=setup()
 local now=W.serverNow
 local old=W.crop('SunflowerSeed',-6,0,now-500)
 local young=W.crop('AppleSeed',6,0,now-2)   -- planted 2 s before this client joined
 local fx=W.P.new()
 fx:Add(old,true);fx:Add(young,true)
 W.frames(40)
 check(#fx.Piles==0 and fx.LiveChunks==0,'join: no pile for loaded crops')
 check(marks(W)==2,'join: both crops have a mark ('..marks(W)..')')
 check(#W.plays==0,'join: silent')
 -- Streaming in after the grace: an old crop is not fresh either.
 W.frames(60*4)
 local streamed=W.crop('SunflowerSeed',0,6,now-900);fx:Add(streamed,false);W.frames(5)
 check(#fx.Piles==0,'stream-in of an old crop: no pile');W.frames(40);check(marks(W)==3,'stream-in crop gets a mark')
 fx:Destroy()
 check(W.workspace:FindFirstChild('LocalPlantingEffects')==nil,'destroy removes the folder')
end

-- 2. Startup grace: a crop that appears in the first seconds is treated as part of the join --------------------------
do
 local W=setup()
 local fx=W.P.new();W.frames(30)
 local m=W.crop('SunflowerSeed',0,0,math.floor(W.serverNow));fx:Add(m,false);W.frames(5)
 check(#fx.Piles==0,'startup grace: no pile in the first seconds')
 fx:Destroy()
end

-- 3. Fresh plant: pile rises with a bounce, holds, sinks, leaves a mark; layered sounds; dirt burst -------------------
local timeline={}
do
 local W=setup()
 local fx=W.P.new();W.frames(60*4)
 local m=W.crop('AppleSeed',2,1,math.floor(W.serverNow))
 fx:Add(m,false);W.frames(1)
 check(#fx.Piles==1,'fresh: pile started')
 local pile=fx.Piles[1];local chunks=parts(W,'Dirt chunk')
 local size=W.P.Size(W.P.BaseRadius('AppleSeed',1))
 check(fx.LiveChunks==#pile.Chunks and #pile.Chunks>=20,'fresh: '..#pile.Chunks..' chunks live')
 local top=soilTop(W);local hidden=true
 for i,c in ipairs(pile.Chunks)do local p=pile.Parts[i];if p.CFrame.Position.Y+c.Size*.5>top+.001 then hidden=false end end
 check(hidden,'fresh: chunks start hidden inside the soil')
 check(marks(W)==0,'fresh: no mark while the pile is up')
 check(#W.emits>=2,'fresh: dirt puff + clods emitted ('..#W.emits..')')
 -- Heights over time for the overshoot check.
 local restTop=-math.huge;for _,c in ipairs(pile.Chunks)do if not c.Flyer then restTop=math.max(restTop,c.Position.Y)end end
 local peak=-math.huge;local flyerPeak=-math.huge
 for f=1,60 do
  W.frames(1)
  for i,c in ipairs(pile.Chunks)do local y=pile.Parts[i].CFrame.Position.Y-top
   if c.Flyer then flyerPeak=math.max(flyerPeak,y)elseif c.Position.Y>=restTop-.001 then peak=math.max(peak,y)end end
  if f%6==0 then local up=0;for i,c in ipairs(pile.Chunks)do if pile.Parts[i].CFrame.Position.Y-top>c.HiddenY+.01 then up+=1 end end;table.insert(timeline,up)end
 end
 check(peak>restTop+.02,('fresh: top chunk overshoots its rest (%.2f > %.2f)'):format(peak,restTop))
 check(flyerPeak>restTop+.3,('fresh: tossed chunks fly above the mound (%.2f)'):format(flyerPeak))
 -- Settled: every chunk sits at its rest pose, inside the mound radius and not floating.
 W.frames(10)
 local worst,far=0,0
 for i,c in ipairs(pile.Chunks)do
  local got=pile.Parts[i].CFrame.Position;local d=(got-pile.Origin*c.Position).Magnitude;worst=math.max(worst,d)
  local rel=pile.Origin:Inverse()*got;far=math.max(far,math.sqrt(rel.X^2+rel.Z^2))
 end
 check(worst<1e-6,('settled: all chunks at rest (max error %.4f)'):format(worst))
 check(far<=size.Radius+.01,('settled: mound within radius (%.2f <= %.2f)'):format(far,size.Radius))
 local tones={};for _,p in ipairs(chunks)do if p.Transparency<1 then tones[tostring(p.Color.R)]=true end end
 local nt=0;for _ in pairs(tones)do nt+=1 end;check(nt>=3,'settled: several shades of brown ('..nt..')')
 local s=sounds(W,'Planting ')
 check(s['Planting Thud']==1 and s['Planting Crunch']==1 and s['Planting Pop']==1 and s['Planting Sparkle']==nil,'fresh: thud + crunch + pop played once each')
 for _,p in ipairs(W.plays)do
  if p.Name=='Planting Pop'then check(p.Speed>=1.12*.99 and p.Speed<=1.26,'pop pitch in range '..p.Speed)end
  if p.Name=='Planting Thud'then check(p.Speed<.8 and p.Speed>.6,'thud pitch low '..p.Speed)end
  check(p.Parent and p.Parent.ClassName=='Attachment','sound is positional (attachment)')
 end
 local crunch;for _,e in ipairs(fx.Emitters)do if e.Sounds.Crunch and e.Sounds.Crunch._plays then crunch=e.Sounds.Crunch end end
 check(crunch and crunch._playing==false,'crunch is cut short')
 -- Hold, then sink; the mark fades in while the chunks sink.
 local sinkAt=pile.Start+pile.SinkAfter
 W.frames(math.floor((sinkAt-W.R.clock)*60)-2)
 check(#fx.Piles==1 and marks(W)==0,'hold: pile still up, no mark yet')
 W.frames(12)
 local mk=parts(W,'Planting mark')[1]
 check(mk and mk.Transparency<1 and mk.Transparency>0,'sink: mark fading in ('..tostring(mk and mk.Transparency)..')')
 W.frames(90)
 check(#fx.Piles==0 and fx.LiveChunks==0,'end: pile gone, chunks back in the pool')
 check(visible(parts(W,'Dirt chunk'))==0,'end: no visible chunk left')
 check(marks(W)==1 and mk.Transparency==0,'end: mark stays, fully opaque')
 check(approx(mk.Size.Y,size.Mark*2),'mark diameter follows the plant size')
 local markTop=mk.CFrame.Position.Y+mk.Size.X/2
 check(markTop>top+.02 and markTop<top+.07,('mark sits just above the soil (%.3f)'):format(markTop-top))
 -- Growth-stage rebuild: the server adds the mature model with the same CropId, then destroys the old one.
 local mature=W.crop('AppleSeed',2,1,m:GetAttribute('PlantedAt'),1,nil,m:GetAttribute('CropId'))
 fx:Add(mature,false);fx:Remove(m);m:Destroy();W.frames(60)
 check(#fx.Piles==0 and marks(W)==1,'stage rebuild: no replay, mark kept')
 -- Final harvest / shovel: crop model removed for good -> mark cleaned up.
 fx:Remove(mature);mature:Destroy();W.frames(20)
 check(marks(W)==1,'removal: short grace for reordered replication')
 W.frames(30)
 check(marks(W)==0 and fx.Marks==0,'removal: mark cleaned up')
 check(next(fx.Records)==nil,'removal: record released')
 -- Every cosmetic part is invisible to raycasts, touches and collisions.
 local safe=true;for _,p in ipairs(W.workspace.LocalPlantingEffects:GetChildren())do if p.CanQuery or p.CanCollide or p.CanTouch then safe=false end end
 check(safe,'no part blocks raycasts, touches or collides')
 fx:Destroy()
end
print('rise timeline (chunks above hidden, every 0.1 s): '..table.concat(timeline,' '))

-- 4. Removal while the pile is up (shovel right after planting / owner leaves) --------------------------------------
do
 local W=setup()
 local fx=W.P.new();W.frames(60*4)
 local m=W.crop('SunflowerSeed',0,0,math.floor(W.serverNow));fx:Add(m,false);W.frames(30)
 check(#fx.Piles==1,'early removal: pile up')
 fx:Remove(m);m:Destroy();W.frames(40)
 check(#fx.Piles==0 and fx.LiveChunks==0 and visible(parts(W,'Dirt chunk'))==0,'early removal: chunks released')
 check(marks(W)==0,'early removal: no mark')
 -- Player leaves: the server clears the whole garden.
 local all={}
 for i=1,8 do local c=W.crop('SunflowerSeed',-12+i*3,4,W.serverNow-1000);fx:Add(c,false);table.insert(all,c)end
 W.frames(40);check(marks(W)==8,'garden: 8 marks')
 for _,c in ipairs(all)do fx:Remove(c);c:Destroy()end;W.frames(40)
 check(marks(W)==0 and next(fx.Records)==nil,'player leave: all marks and records cleaned')
 fx:Destroy()
end

-- 5. Caps: ten plantings in one frame (owner command / fast clicking) -----------------------------------------------
local function burst(opts,label)
 local W=setup(opts)
 local fx=W.P.new();W.frames(60*4)
 if opts and opts.Fast then W.player:SetAttribute('FastMode',true)end
 local list={}
 for i=1,10 do local c=W.crop(i%2==0 and'WinterCrownwoodSeed'or'SunflowerSeed',-18+i*3.6,-3,math.floor(W.serverNow),i%2==0 and 2 or 1);fx:Add(c,false);table.insert(list,c)end
 local maxPiles,maxChunks=0,0
 for _=1,300 do W.frames(1);maxPiles=math.max(maxPiles,#fx.Piles);maxChunks=math.max(maxChunks,fx.LiveChunks)end
 local b=fx:Budget()
 check(maxPiles<=b.Piles and maxChunks<=b.Chunks,('%s: caps respected (piles %d/%d, chunks %d/%d)'):format(label,maxPiles,b.Piles,maxChunks,b.Chunks))
 local s=sounds(W,'Planting Thud')
 check((s['Planting Thud']or 0)==1,label..': one sound set per burst of plantings ('..tostring(s['Planting Thud'])..')')
 W.frames(60*6)
 check(fx.LiveChunks==0,label..': all chunks returned')
 check(marks(W)==10,label..': every crop still gets a mark ('..marks(W)..')')
 print(('%s: peak piles %d, peak chunks %d, skipped %d'):format(label,maxPiles,maxChunks,fx.Stats.Skipped))
 fx:Destroy()
end
burst(nil,'tier 3')
burst({Fast=true},'fast mode (tier 1)')
burst({Quality=2},'graphics level 2 (tier 1)')

-- 6. Size scaling: small herb vs giant king tree ----------------------------------------------------------------------
do
 local W=setup()
 local P=W.P
 local small=P.Layout(P.BaseRadius('HoloMelonSeed',1),P.Hash('a'),96,6)
 local big=P.Layout(P.BaseRadius('WinterCrownwoodSeed',2),P.Hash('b'),96,6)
 local function extent(l)local r,h,s=0,0,0;for _,c in ipairs(l.Chunks)do r=math.max(r,math.sqrt(c.Position.X^2+c.Position.Z^2));h=math.max(h,c.Position.Y+c.Size*.5);s+=c.Size end;return r,h,s/#l.Chunks end
 local r1,h1,s1=extent(small);local r2,h2,s2=extent(big)
 print(('small (HoloMelon x1, base %.1f): %d chunks, reach %.2f, height %.2f, mean cube %.2f, mark %.2f'):format(P.BaseRadius('HoloMelonSeed',1),#small.Chunks,r1,h1,s1,P.Size(P.BaseRadius('HoloMelonSeed',1)).Mark))
 print(('big (WinterCrownwood x2, base %.1f): %d chunks, reach %.2f, height %.2f, mean cube %.2f, mark %.2f'):format(P.BaseRadius('WinterCrownwoodSeed',2),#big.Chunks,r2,h2,s2,P.Size(P.BaseRadius('WinterCrownwoodSeed',2)).Mark))
 check(#big.Chunks>#small.Chunks and r2>r1*2.5 and h2>h1*2.5 and s2>s1*1.8,'bigger plant => wider, taller mound with more and bigger cubes')
 check(P.Size(P.BaseRadius('WinterCrownwoodSeed',2)).Mark>P.Size(P.BaseRadius('HoloMelonSeed',1)).Mark*2,'bigger plant => bigger mark')
 check(P.Size(1e9).Radius==4.5 and P.Size(0/0).Radius==1,'size clamps (giant rolls, NaN)')
 local a=P.Layout(10,P.Hash('same'),96,3);local b2=P.Layout(10,P.Hash('same'),96,3)
 local same=#a.Chunks==#b2.Chunks;for i,c in ipairs(a.Chunks)do if (c.Position-b2.Chunks[i].Position).Magnitude>0 then same=false end end
 check(same,'layout is deterministic per crop id (same pile on every client)')
 -- Mean cube size per catalog plant at scale 1, for the notes.
 local Catalog=W.req(W.RS.PlantCatalog)
 local lo,hi=math.huge,0
 for id in pairs(Catalog)do local s=P.Size(P.BaseRadius(id,1));lo=math.min(lo,s.Radius);hi=math.max(hi,s.Radius)end
 print(('catalog at scale 1: pile radius %.2f .. %.2f'):format(lo,hi))
end

-- 7. Distance, off-screen, Reduced Motion and the effects-off switch ------------------------------------------------
do
 local W=setup()
 local fx=W.P.new();W.frames(60*4)
 W.camera.CFrame=W.R.CFrame.lookAt(W.R.Vector3.new(0,20,-300),W.R.Vector3.new(0,0,-400))
 local m=W.crop('SunflowerSeed',0,0,math.floor(W.serverNow));fx:Add(m,false);W.frames(40)
 check(#fx.Piles==0 and #W.plays==0,'far away: no pile, no sound')
 check(marks(W)==0,'far away: mark culled beyond range')
 W.camera.CFrame=W.R.CFrame.lookAt(W.R.Vector3.new(0,14,-22),W.R.Vector3.new(0,0,0));W.frames(40)
 check(marks(W)==1,'walking closer shows the mark')
 -- Looking away at 60 studs: sound yes, pile no.
 W.camera.CFrame=W.R.CFrame.lookAt(W.R.Vector3.new(0,10,-60),W.R.Vector3.new(0,10,-120))
 local m2=W.crop('SunflowerSeed',5,5,math.floor(W.serverNow));fx:Add(m2,false);W.frames(10)
 check(#fx.Piles==0 and #W.plays>0,'off-screen: sound but no pile')
 fx:Destroy()
end
do
 local W=setup({Reduced=true})
 local fx=W.P.new();W.frames(60*4)
 local m=W.crop('AppleSeed',0,0,math.floor(W.serverNow));fx:Add(m,false);W.frames(1)
 local pile=fx.Piles[1];check(pile~=nil,'reduced motion: pile still shows')
 local flyers=0;for _,c in ipairs(pile.Chunks)do if c.Flyer then flyers+=1 end end
 check(flyers==0,'reduced motion: no tossed chunks')
 local clods=0;for _,e in ipairs(W.emits)do if e.Name=='Dirt clods'then clods+=e.Count end end
 check(clods==0,'reduced motion: no flying clod particles')
 local over=0;local top=soilTop(W)
 for _=1,40 do W.frames(1);for i,c in ipairs(pile.Chunks)do over=math.max(over,(pile.Parts[i].CFrame.Position.Y-top)-c.Position.Y)end end
 check(over<=1e-6,('reduced motion: no overshoot (%.4f)'):format(over))
 fx:Destroy()
end
do
 local W=setup()
 local fx=W.P.new();W.frames(60*4)
 W.player:SetAttribute('StudioPlantEffects','off')
 local m=W.crop('AppleSeed',0,0,math.floor(W.serverNow));fx:Add(m,false);W.frames(40)
 check(#fx.Piles==0 and marks(W)==0,'effects off: no pile, no marks')
 fx:Destroy()
end
-- 8. Other players' plantings are quieter; the owner's plant uses full volume -----------------------------------------
do
 local W=setup({Owner=99})
 local fx=W.P.new();W.frames(60*4)
 local m=W.crop('SunflowerSeed',0,0,math.floor(W.serverNow));fx:Add(m,false);W.frames(10)
 local thud;for _,p in ipairs(W.plays)do if p.Name=='Planting Thud'then thud=p end end
 check(thud and thud.Volume<W.P.Sounds[1].Volume,'someone else planting: quieter thud')
 fx:Destroy()
end
-- 9. Sound id overrides via attributes on the ModuleScript ---------------------------------------------------------
do
 local W=setup()
 W.RS.PlantingEffects:SetAttribute('SparkleSoundId',123456789)
 W.RS.PlantingEffects:SetAttribute('PopSoundId','')
 local fx=W.P.new();W.frames(60*4)
 local m=W.crop('SunflowerSeed',0,0,math.floor(W.serverNow));fx:Add(m,false);W.frames(20)
 local s=sounds(W,'Planting ')
 check(s['Planting Sparkle']==1 and s['Planting Pop']==nil,'attribute overrides: sparkle added, pop removed')
 local id;for _,p in ipairs(W.plays)do if p.Name=='Planting Sparkle'then id=p.Id end end
 check(id=='rbxassetid://123456789','override id normalised ('..tostring(id)..')')
 fx:Destroy()
end
print(('%d checks, %d failures'):format(checks,fails))
