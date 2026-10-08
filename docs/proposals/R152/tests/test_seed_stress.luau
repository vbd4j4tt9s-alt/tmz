--!nocheck
-- R152 seed opening, part 4: RELIABILITY (owner: "sometimes the animation not playing"). The REAL SeedPackClient and PackOpeningFeedback
-- (with every reveal module: RarePullCinematic, the card, the scenes, the sky beam, PackSuspense, RevealFlourish, the sounds) on the Roblox
-- mock, driven the way the server drives them (ChestService: the carried pack, its clicks, RevealSeedId / RevealDuration / RevealAt, the
-- pack destroyed when the reveal ends):
--  0. the server's attributes arrive before the client scripts start (a slow join): the reveals in progress still play
--  then STRESS_N random openings (default 240), each with a random seed of a random tier (every seed of the game: the biome seeds, the
--  Mech seeds, Verity; most of them NOT in the published art the client has, so they go through the client-side fallback), a random pack
--  (every variant: the six biome designs, the old sacks, Mech, Void, Verity; every chip-bag shape; giant), a random device (desktop, phone,
--  low quality / FastMode), sometimes ReducedMotion, the opener or someone else nearby, and now and then:
--   - a fast second pack (opened as soon as the first one's reveal ends on the server, while its presentation still plays)
--   - the tool put away on the frame the reveal starts (the hotbar switched right after the last click)
--   - the opener dying mid-reveal and respawning, the next pack opened on the new character straight away
--   - one step of the reveal throwing an error at a random moment (the card, the stage, the beam, the pack's suspense, the flourish, the
--     sound engine): the reveal finishes or exits cleanly, and the next one plays
--  Every opening must produce its reveal (the opener's card / story scene and the pack opening in the world; an onlooker's world reveal
--  and, for Secret+, the sky beam) and every one must end clean (no presentation, stage, GUI, sound, duck, binding, camera change, held
--  controls or hidden HUD left; no beam or emitter outside the afterglow). At the end nothing has leaked (instances, GUIs, connections).
--  R153 (owner: "pack animations should play all the time and shouldn't stop after 2/3 times"): every opener's presentation is the FULL
--  one (the short one only when the player has "Skip pack animations" on: now and then here) and plays to its end: it ends by itself, or,
--  for a fast second pack opened over a card, after the card has shown its result (a story scene keeps the clicks and the gamepad's R2
--  until it is over, so the next pack waits for it). Now and then the player skips (a click / the scene's button at a random moment).
--  R154 (owner: "... the seed stays on the player's screen until they click and the seed goes to their inventory"): no presentation ends by
--  itself now: its result waits until the player collects it (a click / the scene's button, at a random moment after it is up: at once or
--  seconds later), or something collects it for them (a death, the fast second pack). Every opening must end with its result collected and
--  its seed flown in (landed), unless the opener died before the seed was revealed (then it simply shows); nothing left flying.
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local failLines={}
local function check(c,msg)checks+=1;if not c then fails+=1;if #failLines<60 then print('FAIL: '..msg)end;failLines[#failLines+1]=msg end;return c end
local N=tonumber(STRESS_N)or 240 -- (STRESS_N=... on a line put before this file: a shorter or longer run)
local noop=function()end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
local Mixer=W.module('AudioMixer');Mixer.Start()
-- Debris as on Roblox (the mock's does nothing): an item goes when its time is up (LocalSfx's one-shots at a position)
do
 local queue={}
 W.service('Debris').AddItem=function(_,item,ttl)queue[#queue+1]={Item=item,At=R.clock+(tonumber(ttl)or 10)}end
 W.Run.Heartbeat:Connect(function()for i=#queue,1,-1 do if R.clock>=queue[i].At then local d=table.remove(queue,i);pcall(function()d.Item:Destroy()end)end end end)
end
local Players=W.service('Players')
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules')
local World=W.module('RarePullWorld');local M=W.module('RarePullCinematic');local Audio=W.module('RarePullAudio')
local Card=W.module('RarePullCard');local Fx=W.module('RarePullFx');local Suspense=W.module('PackSuspense');local Flourish=W.module('RevealFlourish')
local Art=W.module('RarePullArt');local Collect=W.module('SeedCollect154')
-- every seed that flew in (its hold ended with the arrival): id -> the count
local landed={};Collect.OnRelease(function(id,cue)if cue and id~=nil then landed[id]=(landed[id]or 0)+1 end end)
local Mech=W.module('MechCatalog');local Verity=W.module('VerityCatalog')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
local SS=W.service('SoundService')
-- images: drawn at once (the client's background drawing), so the stages use them
Art.Hooks.Spawn=function(fn)fn()end;Art.Hooks.Wait=noop
Art.Hooks.Create=function(w,h,rgba)return {W=w,H=h,Destroy=noop}end;Art.Hooks.Content=function(o)return 'rbxtemp://r152/'..o.W end
Art.Request(Art.Order)
-- other players ------------------------------------------------------------------------------------------------------------------------
local others={}
function Players.GetPlayers()local out={X.player};for _,p in ipairs(others)do if p.Parent then out[#out+1]=p end end;return out end
function Players.GetPlayerFromCharacter(_,c)if c==X.char then return X.player end;for _,p in ipairs(others)do if p.Character==c then return p end end;return nil end
local function body(model,x,z)
 local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(x,5,z);t.Parent=model
 local h=R.new('Part');h.Name='HumanoidRootPart';h.Size=V3(2,2,1);h.CFrame=CF(x,3,z);h.Parent=model
 local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.Parent=model
 return h,hum
end
local function otherPlayer(name,x,z)
 local p=R.new('Player');p.Name=name;p.UserId=500+#others;p.Parent=Players;others[#others+1]=p
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace;p.Character=c;body(c,x,z)
 return p,c
end
local onlooker,onlookerChar=otherPlayer('Onlooker',12,96)
-- the opener's respawn: a new character (the scripts follow Player.Character / CharacterAdded)
local function respawn()
 local old=X.char
 X.player.CharacterRemoving:Fire(old);old:Destroy()
 local c=R.new('Model');c.Name=X.player.Name;c.Parent=W.workspace
 local root,hum=body(c,0,100);hum.Died=R.signal();hum.GetState=function()return X.state end
 hum.EquipTool=function(_,tool)for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')then t.Parent=E.bag end end;tool.Parent=c end
 X.player.Character=c;X.char,X.root,X.hum=c,root,hum;E.char,E.root,E.hum=c,root,hum
 W.workspace.CurrentCamera.CameraSubject=hum
 X.player.CharacterAdded:Fire(c)
end
-- the server ------------------------------------------------------------------------------------------------------------------------
local packs={}
for stage=1,7 do for _,v in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small','Standard','Grand'})do packs[#packs+1]={Stage=stage,Variant=v}end end
packs[#packs+1]={Stage=8,Variant='MechLimited'};packs[#packs+1]={Stage=7,Variant='EclipseReliquary'};packs[#packs+1]={Stage=7,Variant=Verity.Variant}
local seedsByRank={}
local function addSeed(id)local _,r=Rules.GetRarity(id);if r and r.Rank then seedsByRank[r.Rank]=seedsByRank[r.Rank]or{};table.insert(seedsByRank[r.Rank],id)end end
for _,s in ipairs(Rules.SeedDesigns)do addSeed(s.id)end
for _,s in ipairs(Mech.Seeds)do addSeed(s.Id)end
addSeed(Verity.Id)
local published={};for _,id in pairs(X.byRank)do published[id]=true end
local seed=20251005
local function rnd()seed=(seed*16807)%2147483647;return seed/2147483647 end
-- (R153: the setting and the skips draw from their own sequence, so every other choice of the run is what it was)
local seed2=153
local function rnd2()seed2=(seed2*16807)%2147483647;return seed2/2147483647 end
local ATTR=W.module('SettingsConfig').ToggleAttributes.SkipCutscenes
local function pick(list)return list[math.floor(rnd()*#list)+1]end
local function serverBag(char,pack,shape,size)
 local ok,bag=pcall(Visuals.CarryBag,char,pack.Stage,pack.Variant,1,size,'None',shape)
 check(ok and bag~=nil,'the pack '..pack.Variant..' (stage '..pack.Stage..', shape '..tostring(shape)..', size '..size..') can be carried: '..tostring(bag))
 if ok and bag then bag:SetAttribute('PackClickCount',0);bag:SetAttribute('PackClicksRequired',Rules.OpenClicks)end
 return ok and bag or nil
end
local function reveal(bag,seedId,tool)
 if tool then tool.Enabled=false end -- (the server switches the opened pack off as it commits: R154 finds the seed's id on it)
 local name=Rules.GetRarity(seedId)
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',name)
 bag:SetAttribute('RevealDuration',Rules.GetRevealDuration(name));bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
end
local function packTool(char,pack)
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='s'..math.floor(rnd()*1e6),Stage=pack.Stage},nil);tool.Activated=R.signal();tool.Enabled=true;tool.Parent=char
 return tool
end
-- what is on screen / in the world ------------------------------------------------------------------------------------------------------
local function effects()return W.workspace:FindFirstChild('_LocalSeedPackEffects')end
local function worldReveals()local n=0;local e=effects();if e then for _,c in ipairs(e:GetChildren())do if c.Name=='SeedReveal'then n+=1 end end end;return n end
local function revealGui()return X.pg:FindFirstChild('RarePullReveal')end
local function seedOut()
 local e=effects();if not e then return false end
 for _,r in ipairs(e:GetChildren())do
  local s=r.Name=='SeedReveal'and r:FindFirstChild('RewardSeed')
  if s then for _,d in ipairs(s:GetDescendants())do if d:IsA('BasePart')and d.LocalTransparencyModifier<1 and d.Transparency<1 then return true end end end
 end
 return false
end
local function titleShown()local g=revealGui();local t=g and X.find(g,'Title');return t~=nil and t.Visible~=false and t.TextTransparency<.5 end
-- (a destroyed Sound is silent on Roblox; the afterglow's hum belongs to the aura, which outlives the reveal by design: checked at the end)
local function rarePlaying(withAura)local n={};for _,s in ipairs(Y.sounds)do if s.IsPlaying and s.Parent and s.Name:match('^RarePull_')and(withAura or s.Name~='RarePull_AuraHum')then n[#n+1]=s.Name end end;return n end
local function ducks()local n=0;for _,d in ipairs(SS:GetDescendants())do if d.Name=='RarePullDuck'then n+=1 end end;return n end
-- a beam / emitter / light that belongs to nothing alive: not on a character, not in a living world effect (the sky beam lives until its
-- fade ends, the afterglow until the aura ends)
local function strayFx()
 local n={}
 local live={}
 for _,p in ipairs({X.player,onlooker})do local e=World.Get(p);if e and e.Folder then live[#live+1]=e end end
 for _,d in ipairs(W.workspace:GetDescendants())do
  if(d.ClassName=='Beam'or d.ClassName=='ParticleEmitter'or d.ClassName=='PointLight')then
   local okC=d:IsDescendantOf(X.char)or d:IsDescendantOf(onlookerChar)
   for _,e in ipairs(live)do if d:IsDescendantOf(e.Folder)and(d.ClassName~='Beam'or(e.Beam and d:IsDescendantOf(e.Beam.Folder)))then okC=true end end
   if not okC then n[#n+1]=d:GetFullName()end
  end
 end
 return n
end
local function clean(tag)
 local ok=true
 local function c(v,msg)if not check(v,tag..': '..msg)then ok=false end end
 c(M.Active()==nil and W.workspace:FindFirstChild('_RarePullStage')==nil and revealGui()==nil,'no presentation, stage or reveal GUI left')
 c(cam:FindFirstChild('RarePullGrade')==nil and cam:FindFirstChild('RarePullBlur')==nil,'no grade / blur left')
 c(#rarePlaying()==0,'every reveal sound has stopped ('..table.concat(rarePlaying(),',')..')')
 c(ducks()==0 and not Audio.Running(),'no duck, no sound sheet')
 c(W.rsBound[M.BindName]==nil,'no render step left')
 c(cam.CameraType==R.Enum.CameraType.Custom and math.abs(cam.FieldOfView-70)<1e-6,'the camera is the player\'s, FieldOfView 70 ('..tostring(cam.FieldOfView)..')')
 c(X.controls.Enabled,'movement is back')
 c(X.hud.Main.Enabled and X.hud.Hotbar.Enabled and X.hud.Touch.Enabled and X.core.PlayerList and X.core.Chat,'the HUD and the Core GUI are back')
 c(worldReveals()==0 and W.workspace:FindFirstChild('_LocalClickingPack')==nil,'no world reveal or clicking pack left')
 c(Collect.Flying()==0 and X.pg:FindFirstChild('SeedCollectFly')==nil,'no seed left flying (R154)')
 local s=strayFx();c(#s==0,'no stray beam / emitter / light ('..table.concat(s,', ',1,math.min(#s,4))..')')
 return ok
end
-- error injection --------------------------------------------------------------------------------------------------------------------------
local targets={
 {Name='card',Mod=Card,Fn={'UpdateLadder','UpdateScene','UpdateInPlace'}},
 {Name='beam',Mod=Fx.BeamClass,Fn={'Update'}},
 {Name='suspense',Mod=Suspense,Fn={'Update'}},
 {Name='flourish',Mod=Flourish,Fn={'Update'}},
 {Name='sound engine',Mod=Audio,Fn={'Update'}},
 {Name='stage',Stage=true},
}
local armed
local function arm(target,at)
 armed={Target=target,At=at,Fired=false,Saved={}}
 local function wrap(mod,fn)
  local orig=mod[fn];armed.Saved[#armed.Saved+1]={mod,fn,orig}
  mod[fn]=function(...)if armed and not armed.Fired and R.clock>=armed.At then armed.Fired=true;error('injected failure (test): '..target.Name)end;return orig(...)end
 end
 if target.Stage then armed.Stage=true else for _,fn in ipairs(target.Fn)do wrap(target.Mod,fn)end end
end
local function armStage()
 -- the stage's class is reached through a live stage
 if not(armed and armed.Stage and not armed.StageWrapped)then return end
 local run=M.Active();local sc=run and run.Scene;if not sc then return end
 local mt=getmetatable(sc);local cls=mt and mt.__index;if type(cls)~='table'then return end
 armed.StageWrapped=true
 local orig=cls.Update;armed.Saved[#armed.Saved+1]={cls,'Update',orig}
 cls.Update=function(...)if armed and not armed.Fired and R.clock>=armed.At then armed.Fired=true;error('injected failure (test): stage')end;return orig(...)end
end
local function disarm()if not armed then return end;for _,s in ipairs(armed.Saved)do s[1][s[2]]=s[3]end;local was=armed;armed=nil;return was end
-- 0. the server's attributes before the client scripts start -------------------------------------------------------------------------
local baseline
do
 cam.CFrame=CF(3,9,112)
 local tool=packTool(X.char,packs[1])
 local own=serverBag(X.char,packs[6],nil,1);own:SetAttribute('PackClickCount',5);reveal(own,X.byRank[5])
 own:SetAttribute('RevealAt',W.workspace:GetServerTimeNow()-.3)
 local theirs=serverBag(onlookerChar,packs[3],nil,1);reveal(theirs,X.byRank[6])
 R.advance(.2)
 local spc=R.new('LocalScript');spc.Name='SeedPackClient'
 local okc,errc=pcall(W.load,'SeedPackClient',spc);check(okc,'the real SeedPackClient loads: '..tostring(errc))
 local pof=R.new('LocalScript');pof.Name='PackOpeningFeedback'
 local okp,errp=pcall(W.load,'PackOpeningFeedback',pof);check(okp,'the real PackOpeningFeedback loads: '..tostring(errp))
 W.frames(4,1/30)
 local run=M.Active()
 check(run and run.Rank==5,'a slow join: the opener\'s Mythic opened before the scripts started still gets its seed card')
 check(worldReveals()==2,'and both packs (the opener\'s and the onlooker\'s) open in the world ('..worldReveals()..')')
 check(World.Get(onlooker)~=nil,'and the onlooker\'s Secret gets its sky beam')
 X.run(Rules.GetRevealDuration('Secret'))
 own:Destroy();theirs:Destroy();tool:Destroy()
 X.run(6)
 check(M.Active()==run and M.Waiting(),'a slow join: its result waits for the player (R154)')
 M.Collect();local g=0;while(M.Active()or Collect.Flying()>0)and g<300 do X.run(.1);g+=1 end
 clean('slow join')
end
-- 0b. the seed's whoosh into the hand (SeedPackClient) is not cut when the world reveal ends (review fix B3): it was a child of the seed effect, destroyed at RevealDuration
-- while the whoosh was still fading (cut at ~75 % volume). It must finish its fade (on an anchor of its own) and then be gone.
-- (R154: the opener's own world seed no longer flies into the hand while their result waits on screen - it fades where it hovers - so this
-- is checked on a pack someone else opens next to them, the seed flying into THAT player's hand: the same code, and what onlookers hear)
do
 local hand=R.new('Part');hand.Name='RightHand';hand.Size=V3(1,1,1);hand.CFrame=CF(13.5,4,96);hand.Parent=onlookerChar
 local known={};for _,s in ipairs(Y.sounds)do known[s]=true end
 local handedOver=0
 for _,rank in ipairs({3,5,7})do
  local tag='whoosh '..names[rank]
  local tool=packTool(onlookerChar,packs[6]);local bag=serverBag(onlookerChar,packs[6],nil,1)
  if bag then
   bag:SetAttribute('PackClickCount',5);reveal(bag,X.byRank[rank])
   local snd,peak,lastVol,gone,goneVol,goneStops,onTail=nil,0,0,false,nil,nil,false
   X.run(Rules.GetRevealDuration(names[rank])+1.2,1/30,function()
    if not snd then for _,s in ipairs(Y.sounds)do if not known[s]and s.Name=='Seed flight'then snd=s end end end
    if snd and not gone then
     if snd.Parent~=nil and snd:IsDescendantOf(W.workspace)then
      lastVol=snd.Volume;peak=math.max(peak,lastVol);if snd.Parent.Name=='Seed flight whoosh'then onTail=true end
     else gone=true;goneVol=lastVol;goneStops=snd.Stops or 0 end
    end
   end)
   if onTail then handedOver+=1 end
   check(snd~=nil and peak>0,tag..': the seed\'s whoosh into the hand plays (peak volume '..string.format('%.3f',peak)..')')
   check(gone,tag..': and is cleaned up afterwards (nothing left in the world)')
   check(gone and goneVol<=.12*peak,tag..': it finished its fade before it went: '..string.format('%.3f',goneVol or -1)..' of a peak of '..string.format('%.3f',peak)..' when it was removed (a cut would leave ~75 %)')
   check(gone and goneStops>=1,tag..': and was stopped, not just destroyed')
   local e=effects();local stray=0;if e then for _,c in ipairs(e:GetChildren())do if c.Name=='Seed flight whoosh'then stray+=1 end end end
   check(stray==0,tag..': no whoosh anchor is left in the effects folder ('..stray..')')
   bag:Destroy();tool:Destroy()
  end
  local guard=0;while M.Active()and guard<300 do X.run(.2);guard+=1 end
  X.run(2)
  for _,s in ipairs(Y.sounds)do known[s]=true end
 end
 check(handedOver>=1,'at least one of the three reveals ended while its whoosh was still fading (the hand-over ran: '..handedOver..')')
 hand:Destroy()
 X.run(1);clean('whoosh scenes')
end
-- the baseline (after the auras have ended)
X.run(40);World.Clear();X.run(.2)
local function census()
 local c={ws=#W.workspace:GetDescendants(),pg=#X.pg:GetDescendants(),rs=X.live(W.Run.RenderStepped),hb=X.live(W.Run.Heartbeat),bound=0,sounds=0}
 for _ in pairs(W.rsBound)do c.bound+=1 end
 for _,s in ipairs(Y.sounds)do if s.IsPlaying and s.Parent then c.sounds+=1 end end
 if W.Run.Stepped then c.st=X.live(W.Run.Stepped)end
 return c
end
baseline=census()
local baseSet={};for _,d in ipairs(W.workspace:GetDescendants())do baseSet[d]=true end
-- the random openings ---------------------------------------------------------------------------------------------------------------
local stats={own=0,other=0,double=0,respawn=0,inject=0,unequip=0,fallbackArt=0,byRank={0,0,0,0,0,0,0,0},device={desktop=0,phone=0,low=0},injected={},short=0,skipped=0,toEnd=0,handedOver=0,collected=0,landed=0,waited=0}
-- R153: the presentation the opener got is the full one (or, with "Skip pack animations" on, the short one)
local function fullFor(r,short)
 if r.Kind=='Ladder'then return r.Quick==(short==true)and r.TL.Length==L.CardTimeline(r.Rank,short==true).Length end
 if r.Kind=='Scene'then return not short and r.TL.Length==L.Timeline(r.Rank,r.Variant).Length end
 if r.Kind=='InPlace'then return r.TL.Length==L.Timeline(r.Rank,'InPlace').Length end
 return r.Kind=='Result'
end
local function skipNow()
 local run=M.Active()
 if run and run.Kind=='Scene'then local b=X.find(revealGui(),'Backdrop');if b then b.Activated:Fire()end
 else W.UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,KeyCode=R.Enum.KeyCode.Unknown,Position=V3(400,300,0)},false)end
end
local produced,finished=0,0
local forceOwn=false
local function device(kind)
 X.lowFx=kind=='low';W.UIS.TouchEnabled=kind=='phone';W.UIS.KeyboardEnabled=kind~='phone'
end
local function openOwn(trial,seedId,pack,shape,size,opts)
 local tag=trial.Tag
 local tool=packTool(X.char,pack)
 local bag=serverBag(X.char,pack,shape,size);if not bag then tool:Destroy();return nil end
 -- the clicks (the server counts them)
 for i=1,Rules.OpenClicks do bag:SetAttribute('PackClickCount',i);bag:SetAttribute('PackClickAt',W.workspace:GetServerTimeNow());X.run(.12)end
 if opts.Unequip then tool.Parent=E.bag end -- (the hotbar switched on the same frame the reveal starts)
 reveal(bag,seedId,tool)
 local rank=select(2,Rules.GetRarity(seedId)).Rank
 W.frames(3,1/30)
 local run=M.Active()
 local okRun=check(run~=nil and run.Rank==rank and not run.Done,tag..': the opener\'s presentation starts ('..tostring(run and run.Kind)..' '..tostring(run and run.Rank)..')')
 local okWorld=check(worldReveals()>=1,tag..': the pack opens in the world')
 return {Bag=bag,Tool=tool,Run=run,Rank=rank,Ok=okRun and okWorld,Start=R.clock}
end
for i=1,N do
 local rank=math.floor(rnd()*8)+1
 local seedId=pick(seedsByRank[rank])
 local pack=pick(packs)
 local shape=(pack.Variant:match('^Pack0')and rnd()<.5)and(math.floor(rnd()*6)+1)or nil
 local size=rnd()<.12 and 12 or(rnd()<.2 and 3 or 1)
 local dev=rnd()<.5 and'desktop'or(rnd()<.6 and'phone'or'low')
 local reduced=rnd()<.15
 local own=forceOwn or rnd()<.75;forceOwn=false
 local double=own and rnd()<.2
 local died=own and not double and rnd()<.1
 local unequip=own and rnd()<.1
 local inject=rnd()<.15 and pick(targets)or nil
 local flags={}
 for _,f in ipairs({{reduced,'reduced motion'},{double,'fast second pack'},{died,'dies'},{unequip,'tool put away'},{inject,inject and('error in the '..inject.Name)}})do if f[1]then flags[#flags+1]=f[2]end end
 local tag=string.format('#%d %s %s (%s%s, %s, %s%s%s)',i,own and'own'or'onlooker',names[rank],pack.Variant,shape and(' shape '..shape)or'',dev,size>1 and('size '..size..', ')or'',seedId,
  #flags>0 and('; '..table.concat(flags,', '))or'')
 stats.byRank[rank]+=1;stats.device[dev]+=1;if not published[seedId]then stats.fallbackArt+=1 end
 device(dev);W.Gui.ReducedMotionEnabled=reduced
 cam.CameraType=R.Enum.CameraType.Custom;cam.CFrame=CF(3,9,112);X.root.CFrame=CF(0,3,100);X.state=R.Enum.HumanoidStateType.Running
 local dur=Rules.GetRevealDuration(names[rank])
 if inject then
  local at=R.clock+.75+(own and .4 or 0)+rnd()*(dur-.3)
  arm(inject,at);stats.inject+=1;stats.injected[inject.Name]=(stats.injected[inject.Name]or 0)+1;forceOwn=true
 end
 if own then
  stats.own+=1;if unequip then stats.unequip+=1 end
  -- R153: now and then "Skip pack animations" is on; now and then the player skips at a random moment (both drawn from rnd2)
  local short=rnd2()<.15;local skipAt=rnd2()<.25 and rnd2()*dur or nil
  if short then stats.short+=1;tag=tag..' [skip pack animations on]'end;if skipAt then stats.skipped+=1;tag=tag..string.format(' [skipped at %.2f s]',skipAt)end
  X.player:SetAttribute(ATTR,short or nil)
  local o=openOwn({Tag=tag},seedId,pack,shape,size,{Unequip=unequip})
  if o then
   if o.Ok then produced+=1 end
   local first,second=o.Run,nil
   local reached={} -- the furthest each presentation's own clock got
   local function watch()local run=M.Active();if run and not run.Done then reached[run]=math.max(reached[run]or -1,run.Clock())end end
   local sawTitle,sawSeed=false,false
   local dieAt=died and(R.clock+.3+rnd()*(dur-.5))or nil
   local dead,skipped=false,false
   X.run(dur-.15,1/30,function(now)
    armStage();watch()
    if titleShown()then sawTitle=true end
    if seedOut()then sawSeed=true end
    if dieAt and not dead and now>=dieAt then dead=true;X.hum.Health=0;X.hum.Died:Fire()end
    if skipAt and not skipped and not dead and now-o.Start>=skipAt then skipped=true;skipNow()end
   end)
   -- the server ends the opening
   o.Bag:Destroy();o.Tool:Destroy()
   if dead then
    stats.respawn+=1
    X.run(.2+rnd()*.8);respawn()
   elseif double then
    stats.double+=1
    -- (R153: a story scene keeps the clicks, the screen and the gamepad's R2 until it is over: the next pack is opened when the player has
    -- control again; over a card (the HUD and the controls stay the player's) straight away, while the card still plays)
    -- (R154: its result waits: the player collects it, then opens the next pack)
    if first and first.Kind=='Scene'then local g=0;while M.Active()==first and g<300 do if first.SawResult and not first.Collected and first.Clock()>=L.ShownAt(first.TL)+M.CollectAfter then skipNow()end;X.run(.2,1/30,watch);g+=1 end end
    X.run(rnd()*.3)
    local rank2=math.floor(rnd()*8)+1;local seed2=pick(seedsByRank[rank2])
    local o2=openOwn({Tag=tag..' then a fast '..names[rank2]},seed2,pick(packs),nil,1,{})
    if o2 then
     second=o2.Run
     X.run(Rules.GetRevealDuration(names[rank2])-.15,1/30,function()armStage();watch();if titleShown()then sawTitle=true end end)
     o2.Bag:Destroy();o2.Tool:Destroy()
    end
   end
   -- R154: the result waits; the player collects it at a random moment once it is up (at once, or up to 4 s later); its seed flies in
   local guard=0;local waitFor=rnd2()<.3 and 0 or rnd2()*4
   while(M.Active()or Collect.Flying()>0)and guard<1500 do
    local run=M.Active()
    if run and run.SawResult and not run.Collected and run.Clock()>=L.ShownAt(run.TL)+M.CollectAfter+waitFor then
     if run.Clock()>=run.TL.Length then stats.waited+=1 end
     skipNow()
    end
    X.run(1/30,1/30,function()watch();if titleShown()then sawTitle=true end end);guard+=1
   end
   X.run(.4)
   X.player:SetAttribute(ATTR,nil)
   if not dead then
    check(sawTitle,tag..': the seed is shown on the opener\'s screen')
    check(sawSeed,tag..': and in the world')
   end
   -- R153: full (or short by the setting), and to its end
   local fired=armed and armed.Fired
   for _,r in ipairs({first,second})do
    if r then
     local which=r==first and'its presentation'or'the second pack\'s presentation'
     check(fullFor(r,short),tag..': '..which..' is the '..(short and'short'or'full')..' one ('..tostring(r.Kind)..' '..tostring(r.Variant or'')..(r.Quick and' quick'or'')..', '..string.format('%.2f',r.TL.Length)..' s)')
     if not dead and not fired then
      local gotTo=reached[r]or -1
      -- (R154: to its end = its result shown and the player collected it; a story scene then went out by itself)
      local toEnd=r.Collected and r.CollectWhy=='press'and gotTo>=L.ShownAt(r.TL)-1/30
      local over=r.Reason=='replaced'and r==first and r.Kind~='Scene'and gotTo>=L.ShownAt(r.TL)-1/30 and r.Collected
      if toEnd then stats.toEnd+=1 elseif over then stats.handedOver+=1 end
      check(toEnd or over,tag..': '..which..' plays to its end and is collected ('..tostring(r.Reason)..' / '..tostring(r.CollectWhy)..' at '..string.format('%.2f',gotTo)..' of '..string.format('%.2f',r.TL.Length)..' s)')
     end
     -- R154: every revealed seed was collected and flew in (landed once); one whose opener died before it was revealed just shows
     if r.Id~=nil then
      if r.SawClimax then
       stats.collected+=1;if landed[r.Id]==1 then stats.landed+=1 end
       check(r.Collected and landed[r.Id]==1,tag..': '..which..': its seed was collected and flew in once ('..tostring(r.CollectWhy)..', landed '..tostring(landed[r.Id])..')')
      else check(not Collect.Held(r.Id),tag..': '..which..': ended before its seed was revealed: nothing held back') end
     end
    end
   end
   if clean(tag)then finished+=1 end
  end
 else
  stats.other+=1
  local bag=serverBag(onlookerChar,pack,shape,size)
  if bag then
   reveal(bag,seedId);W.frames(3,1/30)
   local okW=check(worldReveals()>=1,tag..': the onlooker sees the pack open')
   local okB=rank<6 or check(World.Get(onlooker)~=nil,tag..': and the sky beam')
   if okW and okB then produced+=1 end
   local sawSeed=false
   X.run(dur-.15,1/30,function()armStage();if seedOut()then sawSeed=true end end)
   check(sawSeed,tag..': the seed comes out in the world')
   bag:Destroy();X.run(.4)
   if clean(tag)then finished+=1 end
  end
 end
 disarm() -- (after an injected error the next opening is the opener's own: forceOwn; it must play)
 R.advance(1+rnd()*2)
end
-- leaks -------------------------------------------------------------------------------------------------------------------------------
X.run(40)
check(#rarePlaying(true)==0,'after the auras have ended no reveal sound plays ('..table.concat(rarePlaying(true),',')..')')
check(World.Count()==0 and not World.Connected(),'and no world effect is left, nor its per-frame work')
World.Clear();X.run(.2)
local after=census()
local leaks={}
for k,v in pairs(baseline)do if after[k]~=v then leaks[#leaks+1]=k..' '..v..' -> '..tostring(after[k])end end
local extra={};for _,d in ipairs(W.workspace:GetDescendants())do if not baseSet[d]and #extra<12 then extra[#extra+1]=d:GetFullName()end end
check(#leaks==0,'after '..N..' openings nothing has leaked ('..table.concat(leaks,', ')..(#extra>0 and('; new: '..table.concat(extra,', '))or'')..')')
check(produced==N,'every opening produced its reveal ('..produced..' of '..N..')')
check(finished==N,'every opening ended clean ('..finished..' of '..N..')')
local inj={};for k,v in pairs(stats.injected)do inj[#inj+1]=k..' '..v end;table.sort(inj)
print(string.format('stress: %d openings (%d own, %d onlooker); tiers %s; desktop %d, phone %d, low %d; %d fast second packs, %d deaths + respawns, %d tools put away, %d seeds not in the published art; %d errors injected (%s)',
 N,stats.own,stats.other,table.concat(stats.byRank,'/'),stats.device.desktop,stats.device.phone,stats.device.low,stats.double,stats.respawn,stats.unequip,stats.fallbackArt,stats.inject,table.concat(inj,', ')))
print(string.format('R153: %d own presentations played to their end, %d cards handed over to a fast second pack after their result; %d with "Skip pack animations" on, %d skipped by the player',
 stats.toEnd,stats.handedOver,stats.short,stats.skipped))
print(string.format('R154: %d revealed seeds collected, %d of them flew in (landed once); %d collected after waiting past their whole timeline',stats.collected,stats.landed,stats.waited))
check(stats.collected>0 and stats.landed==stats.collected,'R154: every revealed seed flew in ('..stats.landed..' of '..stats.collected..')')
print(('R152 stress checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
