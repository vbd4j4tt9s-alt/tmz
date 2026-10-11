--!nocheck
-- R158d: nothing of a pack's RESULT shows before the reveal (owner: "the mech pack seeds, and also check for other seeds that have similar issues: their effects are
-- already there even before the pack opens. This ruins the surprise of the pack opening"). The REAL SeedPackClient, PackOpeningFeedback (RarePullCinematic, RarePullScenes,
-- the card, the sounds), ItemCosmetics, ItemVisualEffects and ItemEffectAnchor on the Roblox mock, driven the way ChestService drives them (the carried pack, its five clicks,
-- RevealSeedId / Rarity / Weather / RevealDuration / RevealAt, the pack destroyed when the reveal ends). The engine's own rule is added to the mock: a tagged instance that enters
-- the game fires the tag's added signal, and a clone keeps its tags.
--  1. before the reveal   a pack carried and clicked four times (a Mech, a Void, a Verity and a biome pack): no seed anywhere, no scanner / weather effect, no result attribute
--  2. while the seed is hidden in the pack   (the world reveal: every Mech / Void / Verity / biome pack and result; the story scenes of Secret / Cosmic / King on the stage, where the
--                          camera is): the seed's Mech scanner, its weather effect and every effect built into it (sparkles, lights, outlines) are OFF: not one frame shows one
--  3. at the reveal       the same effects come with the seed: the scanner is there within 3 frames of the seed showing (the world pack: on the burst; a scene: on the hit), the
--                          seed's own effects are back on
--  4. nothing left        after the reveal, nothing of the seed's held state is left (FxHeld) and no effect outlives the seed
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local noop=function()end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
local Mixer=W.module('AudioMixer');Mixer.Start()
do -- Debris as on Roblox
 local queue={}
 W.service('Debris').AddItem=function(_,item,ttl)queue[#queue+1]={Item=item,At=R.clock+(tonumber(ttl)or 10)}end
 W.Run.Heartbeat:Connect(function()for i=#queue,1,-1 do if R.clock>=queue[i].At then local d=table.remove(queue,i);pcall(function()d.Item:Destroy()end)end end end)
end
-- the engine's tag rules, which the shared mock lacks: a clone keeps its tags, and a tagged instance entering the game fires the added signal
local CS=W.CS
do
 local base=R.Inst.Clone
 function R.Inst:Clone()
  local c=base(self)
  local a,b=self:GetDescendants(),c:GetDescendants()
  for _,pair in ipairs({{self,c}})do for tag in pairs(pair[1]._tags or{})do CS:AddTag(pair[2],tag)end end
  for i,d in ipairs(a)do local k=b[i];if k then for tag in pairs(d._tags or{})do CS:AddTag(k,tag)end end end
  return c
 end
end
local announced=setmetatable({},{__mode='k'})
local function announce()for _,p in ipairs(CS:GetTagged('GardenItemFX'))do if not announced[p]then announced[p]=true;CS:GetInstanceAddedSignal('GardenItemFX'):Fire(p)end end end
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules');local M=W.module('RarePullCinematic')
local Mech=W.module('MechCatalog');local Verity=W.module('VerityCatalog');local Collect=W.module('SeedCollect154')
local cam=W.workspace.CurrentCamera
local mechByRank={};for _,s in ipairs(Mech.Seeds)do local _,r=Rules.GetRarity(s.Id);if r and not mechByRank[r.Rank]then mechByRank[r.Rank]=s.Id end end
-- the packs, as the server makes them (stage, variant)
local PACKS={
 Mech={Stage=8,Variant='MechLimited'},Void={Stage=7,Variant='EclipseReliquary'},Verity={Stage=Verity.PackStage,Variant=Verity.Variant},
 Biome={Stage=2,Variant='Pack06'},Forest={Stage=1,Variant='Pack03'},Storm={Stage=7,Variant='Pack06'},
}
local function serverBag(char,pack)
 local bag=Visuals.CarryBag(char,pack.Stage,pack.Variant,1,1,'None');bag:SetAttribute('PackClickCount',0);bag:SetAttribute('PackClicksRequired',Rules.OpenClicks);return bag
end
local function packTool(char,pack)
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='l'..math.floor(R.clock*1000),Stage=pack.Stage},nil);tool.Activated=R.signal();tool.Enabled=true;tool.Parent=char;return tool
end
local function reveal(bag,seedId,weather)
 local name=Rules.GetRarity(seedId)
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',name);bag:SetAttribute('Weather',weather or'None')
 bag:SetAttribute('RevealDuration',Rules.GetRevealDuration(name));bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
end
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear()
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;X.lowFx=false;X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 R.advance(5)
end
-- the scripts: the real ones
local spc=R.new('LocalScript');spc.Name='SeedPackClient';assert(pcall(W.load,'SeedPackClient',spc))
local pof=R.new('LocalScript');pof.Name='PackOpeningFeedback';assert(pcall(W.load,'PackOpeningFeedback',pof))
local icn=R.new('LocalScript');icn.Name='ItemCosmetics';assert(pcall(W.load,'ItemCosmetics',icn))
W.frames(2,1/30)
-- what is on show ------------------------------------------------------------------------------------------------------------------------
local EFFECT={ParticleEmitter=true,Beam=true,Trail=true,PointLight=true,SpotLight=true,SurfaceLight=true,BillboardGui=true,SurfaceGui=true,Highlight=true,Fire=true,Smoke=true,Sparkles=true}
local function findSeed(rootName,seedName)local r=W.workspace:FindFirstChild(rootName);return r and r:FindFirstChild(seedName,true)end
local function seedState(model)
 if not model or not model.Parent then return nil end
 local shown,live=false,0
 for _,d in ipairs(model:GetDescendants())do
  if d:IsA('BasePart')and d~=model.PrimaryPart and d.Transparency<1 and(d.LocalTransparencyModifier or 0)<1 then shown=true end
  if EFFECT[d.ClassName]and d.Enabled==true then live+=1 end
 end
 return {Shown=shown,Live=live,Held=model.PrimaryPart and model.PrimaryPart:GetAttribute('FxHeld')}
end
-- the effect pieces ItemCosmetics draws, by where they are (the stage is far above the map)
local function pieces()
 local f=W.workspace:FindFirstChild('_ItemCosmeticsR59');local out={WorldScanner=0,StageScanner=0,WorldWeather=0,StageWeather=0}
 if f then for _,d in ipairs(f:GetDescendants())do
  if d:IsA('BasePart')and d.Transparency<1 then
   local stage=d.Position.Y>1000
   if d.Name=='Mechanical scanner'then if stage then out.StageScanner+=1 else out.WorldScanner+=1 end
   elseif d.Name=='Frosted'or d.Name=='Drippy'or d.Name=='Charged'then if stage then out.StageWeather+=1 else out.WorldWeather+=1 end end
  end
 end end
 return out
end
local function seedsAnywhere()
 local n=0;for _,d in ipairs(W.workspace:GetDescendants())do if d.Name=='RewardSeed'or d.Name=='RarePullSeed'then n+=1 end end;return n
end
-- 1. before the reveal ------------------------------------------------------------------------------------------------------------------
for name,pack in pairs(PACKS)do
 reset()
 local tool=packTool(X.char,pack);local bag=serverBag(X.char,pack);bag:SetAttribute('Weather','Frosted')
 local worst=0;local seeds=0
 for i=1,4 do
  bag:SetAttribute('PackClickCount',i);bag:SetAttribute('PackClickAt',W.workspace:GetServerTimeNow())
  X.run(.2,1/30,function()announce();local p=pieces();worst=math.max(worst,p.WorldScanner+p.StageScanner);seeds=math.max(seeds,seedsAnywhere())end)
 end
 check(worst==0,name..' pack, 4 clicks in: no Mech scanner anywhere ('..worst..')')
 check(seeds==0,name..' pack, 4 clicks in: no seed exists anywhere (the result is not in the client yet)')
 check(bag:GetAttribute('RevealSeedId')==nil and bag:GetAttribute('Rarity')==nil and tool:GetAttribute('Rarity')==nil and tool:GetAttribute('SeedId')==nil,name..' pack, 4 clicks in: the pack and its tool carry no result attribute')
 bag:Destroy();tool:Destroy();X.run(.3,1/30,announce)
end
-- 2 + 3. the reveal ---------------------------------------------------------------------------------------------------------------------
local function open(label,pack,seedId,opts)
 opts=opts or{}
 reset()
 local tool=packTool(X.char,pack);local bag=serverBag(X.char,pack)
 local dt=opts.Dt or 1/30
 for i=1,Rules.OpenClicks do bag:SetAttribute('PackClickCount',i);X.run(.12,dt,announce)end
 reveal(bag,seedId,opts.Weather);local at=bag:GetAttribute('RevealAt');local dur=bag:GetAttribute('RevealDuration')
 local isMech=Mech.ById and Mech.ById[seedId]~=nil
 local rec={Hidden={World=0,Stage=0},Leaks={},FirstShown={},FirstFx={},StageInStage=0,Frames=0}
 local function frame(now)
  announce()
  local t=now-at
  local w=seedState(findSeed('_LocalSeedPackEffects','RewardSeed'));local s=seedState(findSeed('_RarePullStage','RarePullSeed'))
  local p=pieces()
  local run=M.Active();local inStage=run and run.InStage==true
  -- (where a piece sits is not trusted for the leak check: before its first frame on the stage the hero seed sits wherever it was built)
  local shownSeeds=(w and w.Shown and 1 or 0)+(s and s.Shown and 1 or 0)
  local scanner=p.WorldScanner+p.StageScanner;local weather=p.WorldWeather+p.StageWeather
  local live=(w and not w.Shown and w.Live or 0)+(s and not s.Shown and s.Live or 0)
  if scanner>(isMech and 12*shownSeeds or 0)or weather>8*shownSeeds or live>0 then
   rec.Leaks[#rec.Leaks+1]=('t=%.2f world %s stage %s inStage=%s: scanner %d weather %d effects built into a hidden seed %d'):format(t,w and(w.Shown and'shown'or'hidden')or'-',s and(s.Shown and'shown'or'hidden')or'-',tostring(inStage),scanner,weather,live)
  end
  if w then
   if not w.Shown then rec.Hidden.World+=1 elseif not rec.FirstShown.World then rec.FirstShown.World=t end
   if w.Shown and not rec.FirstFx.World and(p.WorldScanner>0 or p.WorldWeather>0 or w.Live>0)then rec.FirstFx.World=t end
  end
  if s then
   if not s.Shown then rec.Hidden.Stage+=1;if inStage then rec.StageInStage+=1 end
   elseif not rec.FirstShown.Stage then rec.FirstShown.Stage=t;rec.StageHeldOnShow=s.Held end
   if s.Shown and not rec.FirstFx.Stage and(p.StageScanner>0 or p.StageWeather>0 or s.Live>0)then rec.FirstFx.Stage=t end
  end
  rec.Frames+=1
 end
 X.run(dur+.05,dt,frame)
 if bag.Parent then bag:Destroy()end;tool:Destroy()
 local guard=0
 while(M.Active()or Collect.Flying()>0)and guard<200 do local r=M.Active();if r and r.SawResult and not r.Collected and r.Clock()>=L.ShownAt(r.TL)+M.CollectAfter then M.Collect()end;X.run(.2,dt,frame);guard+=1 end
 X.run(.3,dt,announce)
 rec.IsMech=isMech;rec.Dt=dt
 return rec
end
local function verdict(label,rec,want)
 local dt=rec.Dt
 print(('  %s: world seed hidden %d frames, shown at %s, effects at %s; stage seed hidden %d frames (%d on the stage), shown at %s, effects at %s'):format(label,rec.Hidden.World,tostring(rec.FirstShown.World),tostring(rec.FirstFx.World),rec.Hidden.Stage,rec.StageInStage,tostring(rec.FirstShown.Stage),tostring(rec.FirstFx.Stage)))
 check(#rec.Leaks==0,label..': not one frame shows a result effect while the seed is hidden'..(#rec.Leaks>0 and(' ('..#rec.Leaks..': '..rec.Leaks[1]..')')or''))
 if want.World then
  check(rec.Hidden.World>=10,label..(': the world seed was hidden for %d frames (the window the check covers)'):format(rec.Hidden.World))
  check(rec.FirstShown.World~=nil,label..': the world seed shows at the burst')
  if want.Effects then check(rec.FirstFx.World~=nil and rec.FirstShown.World~=nil and rec.FirstFx.World-rec.FirstShown.World<=3*dt+1e-6,label..(': its effects come with it, within 3 frames (seed %.2f s, effects %s)'):format(rec.FirstShown.World or-1,tostring(rec.FirstFx.World)))end
 end
 if want.Stage then
  check(rec.StageInStage>=10,label..(': the camera was on the stage with the seed hidden for %d frames (the window the check covers)'):format(rec.StageInStage))
  check(rec.FirstShown.Stage~=nil,label..': the hero seed shows at the hit')
  if want.Effects then check(rec.FirstFx.Stage~=nil and rec.FirstShown.Stage~=nil and rec.FirstFx.Stage-rec.FirstShown.Stage<=3*dt+1e-6,label..(': its effects come with it, within 3 frames (seed %.2f s, effects %s)'):format(rec.FirstShown.Stage or-1,tostring(rec.FirstFx.Stage)))end
 end
end
local function leftovers()
 local n=0
 for _,d in ipairs(W.workspace:GetDescendants())do if d.Name=='RewardSeed'or d.Name=='RarePullSeed'then n+=1 elseif d.Name=='Mechanical scanner'and d.Parent then n+=1 end end
 return n
end
-- (pack, result, weather): the Mech seeds of the Mech / Void / Verity pack (the Void's 1/200 and the Verity's Mech roll), generic seeds in a biome / Void pack
local CASES={
 {'Mech pack, Legendary Mech seed (card)',PACKS.Mech,mechByRank[4],nil,{World=true,Effects=true}},
 {'Mech pack, Secret Mech seed (story scene)',PACKS.Mech,mechByRank[6],nil,{World=true,Stage=true,Effects=true}},
 {'Mech pack, Cosmic Mech seed (story scene)',PACKS.Mech,mechByRank[7],nil,{World=true,Stage=true,Effects=true}},
 {'Mech pack, King Mech seed (story scene)',PACKS.Mech,mechByRank[8],nil,{World=true,Stage=true,Effects=true}},
 {'Void pack, Mech seed (the 1/200)',PACKS.Void,mechByRank[7]or mechByRank[6],nil,{World=true,Stage=true,Effects=true}},
 {'Void pack, Cosmic seed',PACKS.Void,X.byRank[7],nil,{World=true,Stage=true,Effects=true}},
 {'Verity pack, Mech seed',PACKS.Verity,mechByRank[6]or mechByRank[7],nil,{World=true,Stage=true,Effects=true}},
 {'Verity pack, King seed',PACKS.Verity,X.byRank[8],nil,{World=true,Stage=true,Effects=true}},
 {'Storm pack, Secret seed, Frosted',PACKS.Storm,X.byRank[6],'Frosted',{World=true,Stage=true,Effects=true}},
 {'biome pack, Mythic seed (card), Frosted',PACKS.Biome,X.byRank[5],'Frosted',{World=true,Effects=true}},
 {'Forest pack, Rare seed (card)',PACKS.Forest,X.byRank[3],nil,{World=true,Effects=true}},
 {'Forest pack, Common seed (card)',PACKS.Forest,X.byRank[1],nil,{World=true,Effects=true}},
}
for _,c in ipairs(CASES)do
 local label,pack,seed,weather,want=c[1],c[2],c[3],c[4],c[5]
 if seed then
  local rec=open(label,pack,seed,{Weather=weather})
  verdict(label,rec,want)
  check(leftovers()==0,label..': nothing of the seed or its scanner is left after the reveal')
 else print('skip: '..label..' (no such seed in this checkout)')end
end
do -- 60 fps and ReducedMotion do not change it
 local rec=open('Mech pack, Mythic-class Mech seed at 60 fps',PACKS.Mech,mechByRank[5]or mechByRank[4],{Dt=1/60})
 verdict('Mech pack at 60 fps',rec,{World=true,Effects=true})
 W.Gui.ReducedMotionEnabled=true
 local rec2=open('Mech pack, Cosmic, Reduced Motion',PACKS.Mech,mechByRank[7],{});W.Gui.ReducedMotionEnabled=false
 check(#rec2.Leaks==0,'Mech pack, Cosmic, Reduced Motion: not one frame shows a result effect while the seed is hidden')
end
-- 4. nothing left -----------------------------------------------------------------------------------------------------------------------
do
 local held=0;for _,p in ipairs(CS:GetTagged('GardenItemFX'))do if p:GetAttribute('FxHeld')~=nil then held+=1 end end
 check(held==0,'no part is still held after the reveals ('..held..')')
 spc:Destroy();pof:Destroy();icn:Destroy();W.frames(2,1/30)
 check(leftovers()==0,'the scripts destroyed: nothing of the seeds or their effects is left')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
