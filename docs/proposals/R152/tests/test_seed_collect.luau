--!nocheck
-- R154 seed collect (owner: "minor fix after i want to make it so that after obtaining the seed the seed stays on the player's screen until they
-- click and the seed goes to their inventory"). The REAL SeedPackClient, PackOpeningFeedback (RarePullCinematic, the card, the scenes, the
-- sounds, SeedCollect154) and Hotbar on the Roblox mock; the server driven the way ChestService drives it: the carried pack, its clicks, the
-- pack switched off with RevealSeedId / Rarity / RevealDuration / RevealAt, and at RevealDuration the pack destroyed, the seed's tool (it keeps
-- the pack's inventory id) in the Backpack, put in the hand when the hand is empty, its seed built a frame later (the server builds it when it
-- is equipped). The hotbar is laid out on a 1280 x 720 screen every frame (AbsolutePosition / AbsoluteSize, as the engine does).
--  1. the result WAITS: every tier and presentation (Common..Mythic cards, the Secret / Cosmic / King story scenes, in place, "Skip pack
--     animations" on, Reduced Motion) shows its result, then 120 s without input change nothing: still on screen (title, "1 in N", the seed),
--     the hint "click to collect!" (desktop) / "tap to collect!" (phone), its sounds and duck over by its Length; the seed not in the hotbar,
--     hidden in the hand on this screen (and the seed the server builds a frame later), the world seed never flies into the hand
--  2. the press COLLECTS it (a click / tap / Enter / B / R2 on a card; the scene's full-screen button / keys): the seed flies from the card and
--     lands ON its slot (the first free one, the slot of the stack it joins, the Bag button when no slot is free), pops; the hotbar shows it from
--     that frame and never before, flashes that slot, the pickup cue (Bubble06) plays on that frame; the seed shows in the hand; nothing left
--  3. the press is the reveal's: ClaimPress answers true for the whole wait, the bat in the hand stays manual, nothing reaches it
--  4. edge cases, each collecting the waiting result by itself (it flies in, nothing is lost: the seed shows in the end): the next pack opened,
--     death, a ragdoll, a fling, a chase starting, a keeper chasing, a teleport, walking onto the track, walking far away, the shop opening,
--     the Bag opening; a menu already open when the result appears does not; a collect before the server ends the opening (a skipper): the
--     seed rests on its slot until its tool is there; Reduced Motion: a quick fade in place; mobile: a tap anywhere collects, a HUD button /
--     a hotbar slot / a drag / a long press do not (the slot still equips); R155: the skip is the SKIP button / gamepad B / Enter only (spam in
--     every phase does nothing), the first press that BEGAN after the result (+ CollectAfter) collects, one held from before does not; an onlooker's pack: as before (no hold, its seed flies into their hand)
--  5. sound: the collect never stacks on the reveal's tail (a collect while it rings fades it out first: silent by the landing), the flight's
--     whoosh swells on its fastest frame and stays soft, the pickup cue is heard on the landing frame
--  6. review fixes: a held-back seed's weather / Mech effects (drawn by the real ItemCosmetics outside the tool) stay off until it lands, then
--     come back at once; the watchdog ends a touched hold at its Due, not a Backstop later; a story scene cut short whose result card cannot
--     start lets its hold go at once; a fast runner on a slow frame / a hitch / a fall is not a "teleport" (a real one still is)
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local noop=function()end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
do local Meshes=W.module('ApprovedPlantMeshes');local cache={}
 Meshes.Get=function(key)local p=cache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=V3(1,1,1);cache[key]=p end;return p end
 Meshes.Status=function()return'Ready'end end
local Mixer=W.module('AudioMixer');Mixer.Start()
do -- Debris as on Roblox (the mock's does nothing)
 local queue={}
 W.service('Debris').AddItem=function(_,item,ttl)queue[#queue+1]={Item=item,At=R.clock+(tonumber(ttl)or 10)}end
 W.Run.Heartbeat:Connect(function()for i=#queue,1,-1 do if R.clock>=queue[i].At then local d=table.remove(queue,i);pcall(function()d.Item:Destroy()end)end end end)
end
local Players=W.service('Players')
local others={}
function Players.GetPlayers()local out={X.player};for _,p in ipairs(others)do if p.Parent then out[#out+1]=p end end;return out end
function Players.GetPlayerFromCharacter(_,c)if c==X.char then return X.player end;for _,p in ipairs(others)do if p.Character==c then return p end end;return nil end
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules')
local World=W.module('RarePullWorld');local M=W.module('RarePullCinematic');local Audio=W.module('RarePullAudio');local Sounds=W.module('RarePullSounds')
local Collect=W.module('SeedCollect154');local Settings=W.module('SettingsConfig');local Art=W.module('RarePullArt');local Card=W.module('RarePullCard')
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog');local IA=W.module('InteractionAudio')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
local ATTR=Settings.ToggleAttributes.SkipCutscenes
Art.Hooks.Spawn=function(fn)fn()end;Art.Hooks.Wait=noop
Art.Hooks.Create=function(w,h)return {W=w,H=h,Destroy=noop}end;Art.Hooks.Content=function(o)return 'rbxtemp://r154/'..o.W end
Art.Request(Art.Order)
do local CAS=W.service('ContextActionService');local orig=CAS.BindActionAtPriority
 CAS.BindActionAtPriority=function(self,name,fn,touch,priority,...)return orig(self,name,fn,touch,priority,...)end end
W.UIS.TouchTapInWorld=W.UIS.TouchTapInWorld or R.signal()
-- the hotbar laid out as the engine lays it out (before the scripts' own frame: this listener is connected first)
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph,cx,cy)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
  local x=px+p.X.Scale*pw+p.X.Offset-a.X*w-cx;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h-cy
  set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
  local ox,oy=0,0;if c._class=='ScrollingFrame'then local cp=c._props.CanvasPosition or R.Vector2.new(0,0);ox,oy=cp.X,cp.Y end
  lay(c,x,y,w,h,ox,oy)
 end end
end
W.Run.RenderStepped:Connect(function()local g=X.pg:FindFirstChild('ChestToolHotbar');if g then lay(g,0,0,1280,720,0,0)end end)
-- the hand the world seed would fly into
local hand=R.new('Part');hand.Name='RightHand';hand.Size=V3(1,1,1);hand.CFrame=CF(1.5,4,100);hand.Parent=X.char
-- the real client scripts
for _,n in ipairs({'SeedPackClient','PackOpeningFeedback','Hotbar'})do
 local sc=R.new('LocalScript');sc.Name=n;local ok,err=pcall(W.load,n,sc);check(ok,'the real '..n..' loads: '..tostring(err))
end
X.run(1)
local hb=X.pg:FindFirstChild('ChestToolHotbar');local dock=hb and hb:FindFirstChild('Dock')
check(dock~=nil,'the real hotbar is on screen')
local bagButton=dock and dock:FindFirstChild('OpenInventory')
-- what is on screen ----------------------------------------------------------------------------------------------------------------------
local function revealGui()return X.pg:FindFirstChild('RarePullReveal')end
local function overlay()return X.pg:FindFirstChild('SeedCollectFly')end
local function flyView()local o=overlay();return o and o:FindFirstChild('Seed')end
local function titleShown()local g=revealGui();local t=g and X.find(g,'Title');return t~=nil and t.Visible~=false and t.TextTransparency<.5 end
local function oddsFinal(run)local g=revealGui();local o=g and X.find(g,'Odds');return o~=nil and run.Odds~=nil and o.TextTransparency<.05 and o.Text==L.OddsPrefix..run.Odds end
local function cardSeed()local g=revealGui();local v=g and X.find(g,'Seed');return v~=nil and v:IsA('ViewportFrame')and v.Visible and v.ImageTransparency<.5 end
local function hint()local g=revealGui();return g and X.find(g,'Skip hint')end
local function rarePlaying()local n={};for _,s in ipairs(Y.sounds)do if s.IsPlaying and s.Parent and s.Name:match('^RarePull_')and s.Name~='RarePull_AuraHum'and(tonumber(s.Volume)or 0)>1e-4 then n[#n+1]=s.Name end end;return n end
local function effects()return W.workspace:FindFirstChild('_LocalSeedPackEffects')end
local function worldSeed()
 local e=effects();if not e then return nil end
 for _,r in ipairs(e:GetChildren())do local s=r.Name=='SeedReveal'and r:FindFirstChild('RewardSeed');if s then return s end end
 return nil
end
local function worldSeedVisible()
 local s=worldSeed();if not s then return false end
 for _,d in ipairs(s:GetDescendants())do if d:IsA('BasePart')and d~=s.PrimaryPart and d.LocalTransparencyModifier<1 and d.Transparency<1 then return true end end
 return false
end
-- the hotbar: the slot showing an item of this name (and its count), the slots in use
local function slots()local out={};for i=1,10 do local b=dock['Slot'..i];if b.Visible then out[#out+1]=b end end;return out end
local function slotShowing(name)for _,b in ipairs(slots())do if b.ItemName.Text==name then return b end end;return nil end
local function centre(b)return b.AbsolutePosition.X+b.AbsoluteSize.X/2,b.AbsolutePosition.Y+b.AbsoluteSize.Y/2 end
local function bubbles()local n=0;for _,s in ipairs(E.sounds)do if s.SoundId=='rbxassetid://'..IA.AssetIds.Bubble06 then n+=#s.PlayLog end end;return n end
local function bubbleAt(t)for _,s in ipairs(E.sounds)do if s.SoundId=='rbxassetid://'..IA.AssetIds.Bubble06 then for _,l in ipairs(s.PlayLog)do if near(l.At,t,1e-6)then return l end end end end;return nil end
-- the landing: when the hold of an id ends (the Hotbar's listener has run first: it shows the seed), where the flying seed is on that frame
local landings={}
Collect.OnRelease(function(id,cue,target)
 local v=flyView()
 local x,y=v and v.Position.X.Offset,v and v.Position.Y.Offset
 landings[#landings+1]={Id=id,Cue=cue,Target=target,At=R.clock,X=x,Y=y}
end)
local function landingOf(id)for i=#landings,1,-1 do if landings[i].Id==id then return landings[i]end end;return nil end
-- the server -----------------------------------------------------------------------------------------------------------------------------
local opened=0
local function equip(t)for _,c in ipairs(X.char:GetChildren())do if c:IsA('Tool')then c.Parent=E.bag end end;if t then t.Parent=X.char end end
-- a tool as the engine has it (its Activated signal, ManualActivationOnly off unless set)
local function live(t,manual)t.Activated=t.Activated or R.signal();if t.ManualActivationOnly==nil then t.ManualActivationOnly=manual==true end;return t end
local shovel=live(F.shovel(W,E.bag),true) -- (the shovel keeps slot 1, as in the game)
-- open: a pack in the hand, its five clicks, the server commits (opts.Seed: the seed id; opts.Char: someone else's character)
local function open(rank,opts)
 opts=opts or{}
 opened+=1;local id='inv-r154-'..opened;local char=opts.Char or X.char
 local tool=live(F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId=id,Stage=2},nil));tool.Enabled=true
 if char==X.char then equip(tool)else tool.Parent=char end
 local bag=Visuals.CarryBag(char,2,'Pack06',1,1,'None');bag:SetAttribute('PackClicksRequired',Rules.OpenClicks);bag:SetAttribute('PackClickCount',Rules.OpenClicks)
 W.frames(1,1/30)
 local seedId=opts.Seed or X.byRank[rank];local rarity=Rules.GetRarity(seedId);local dur=Rules.GetRevealDuration(rarity)
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',rarity);bag:SetAttribute('RevealDuration',dur);bag:SetAttribute('Weather','None')
 tool.Enabled=false
 local at=W.workspace:GetServerTimeNow();bag:SetAttribute('RevealAt',at)
 W.frames(1,1/30)
 local spec=Rules.SeedDesignById[seedId]
 local o={Bag=bag,Tool=tool,Rank=rank,At=at,Duration=dur,SeedId=seedId,Id=id,Rarity=rarity,Char=char,Run=char==X.char and M.Active()or nil,Track={},FX=opts.FX,Mech=opts.Mech}
 o.Name=Names.Tool({GetAttribute=function(_,k)return({SeedId=seedId,GardenSeed=true,Mutation='None'})[k]end,Name=(spec and spec.name or seedId)},Catalog)
 return o
end
-- the server ends the opening: the pack goes, the seed's tool arrives (and is held when the hand is empty), its seed built a frame later
local function serverEnd(o)
 o.Bag:Destroy();o.Tool:Destroy();o.EndedAt=W.workspace:GetServerTimeNow()
 local spec=Rules.SeedDesignById[o.SeedId]
 local t=live(F.tool(W,spec and spec.name or o.SeedId,{GardenSeed=true,SeedInventoryId=o.Id,SeedId=o.SeedId,SeedScale=1,Mutation='None',Weather='None',Rarity=o.Rarity,Stage=2},nil,
  {{'SeedBody',V3(1,1,1),CF(0,0,0),R.Color3.new(1,1,1)}}),true)
 t.Parent=o.Char==X.char and E.bag or o.Char;o.SeedTool=t
 o.Name=Names.Tool(t,Catalog)
 if o.Char==X.char and not X.char:FindFirstChildOfClass('Tool')and X.hum.Health>0 then X.hum:EquipTool(t);o.Equipped=true end
 o.BuildAt=R.clock+1/30
end
local function step(o,dt)
 W.frames(1,dt or 1/30)
 if o.Bag.Parent and W.workspace:GetServerTimeNow()-o.At>=o.Duration then serverEnd(o)end
 if o.BuildAt and R.clock>=o.BuildAt and o.SeedTool and o.SeedTool.Parent==X.char then
  o.BuildAt=nil -- (the server builds the seed on Equipped: a model with its own effects)
  local m=R.new('Model');m.Name='LooseSeed';local p=R.new('Part');p.Name='Packet';p.Size=V3(.5,.5,.5);p.Transparency=0;p.Parent=m
  local fx=R.new('ParticleEmitter');fx.Name='Sparkle';fx.Enabled=true;fx.Parent=p;m.Parent=o.SeedTool;o.Packet=p;o.PacketFx=fx
  if o.FX or o.Mech then -- (ItemEffectAnchor.Set, as the server does it: the weather / Mech effects are drawn by ItemCosmetics, outside the tool)
   p.CFrame=CF(0,4,100);p:SetAttribute('WeatherTrait',o.FX or'None');p:SetAttribute('EffectRadius',1.2);p:SetAttribute('EffectHeight',2)
   if o.Mech then p:SetAttribute('MechFX',true)end
   W.CS:AddTag(p,'GardenItemFX')
  end
 end
 local s=worldSeed()
 if s and s.PrimaryPart and o.Bag.Parent then o.Track[#o.Track+1]={T=W.workspace:GetServerTimeNow()-o.At,D=(s:GetPivot().Position-(hand.CFrame*CF(0,-.5,0)).Position).Magnitude,V=worldSeedVisible()}end
end
local function untilT(o,run,t,each)local g=0;while not run.Done and run.Clock()<t and g<6000 do step(o);g+=1;if each then each()end end end
local function untilShown(o,run)local g=0;while not run.SawResult and not run.Done and g<6000 do step(o);g+=1 end end
-- presses -------------------------------------------------------------------------------------------------------------------------------------
local UT,KC=R.Enum.UserInputType,R.Enum.KeyCode
local function click(processed)W.UIS.InputBegan:Fire({UserInputType=UT.MouseButton1,KeyCode=KC.Unknown,Position=V3(400,300,0)},processed==true)end
local function touch(o,hold,move)
 local input={UserInputType=UT.Touch,KeyCode=KC.Unknown,Position=V3(300,200,0)}
 W.UIS.InputBegan:Fire(input,false)
 local t0=R.clock;while R.clock-t0<hold-1e-9 do step(o)end
 input.Position=V3(300+(move or 0),200,0);W.UIS.InputEnded:Fire(input,false)
end
local function press(o,how)
 if how=='click'then click()elseif how=='tap'then touch(o,0,2)elseif how=='Return'then W.UIS.InputBegan:Fire({UserInputType=UT.Keyboard,KeyCode=KC.Return,Position=V3(0,0,0)},false)
 elseif how=='ButtonB'or how=='ButtonR2'then W.UIS.InputBegan:Fire({UserInputType=UT.Gamepad1,KeyCode=KC[how],Position=V3(0,0,0)},false)
 elseif how=='button'then local b=X.find(revealGui(),'Backdrop');if b then b.Activated:Fire()end
 elseif how=='key'then local fn=W.actions[M.SkipAction];if fn then fn(M.SkipAction,R.Enum.UserInputState.Begin)end
 -- R155: the SKIP button at the bottom right (only while it shows), and the story scene's bound gamepad B
 elseif how=='skip'then local b=X.find(revealGui(),'Skip button');if b and b.Visible then b.Activated:Fire()end
 elseif how=='B key'then local fn=W.actions[M.SkipAction];if fn then fn(M.SkipAction,R.Enum.UserInputState.Begin,{KeyCode=KC.ButtonB})end end
end
local function skipShows()local b=revealGui()and X.find(revealGui(),'Skip button');return b~=nil and b.Visible==true and b.BackgroundTransparency<.9 end
-- reset between cases ---------------------------------------------------------------------------------------------------------------------
local function clearItems()
 for _,c in ipairs(X.char:GetChildren())do if(c:IsA('Tool')and c~=shovel)or c.Name=='CarriedSeed'then c:Destroy()end end
 for _,c in ipairs(E.bag:GetChildren())do if c~=shovel then c:Destroy()end end
 shovel.Parent=E.bag
end
local function reset()
 M.Abort('test');World.Clear()
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 clearItems()
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 X.root.CFrame=CF(0,3,100);X.state=R.Enum.HumanoidStateType.Running;X.hum.Health=100
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true;X.lowFx=false;X.hum.WalkSpeed=16;X.root.AssemblyLinearVelocity=nil
 X.player:SetAttribute(ATTR,nil);X.pg:SetAttribute('SeedMenu',nil)
 for _,a in ipairs({'GuardianRagdollActive','GuardianFlingActive','ChestChaseRunActive','ChestChaseQueued','ChestChaseSeedCarrying'})do X.player:SetAttribute(a,nil)end
 local motion=W.RS:FindFirstChild('RunnerMotion');if motion then motion:SetAttribute('TrackBoundaryZ',nil);motion:SetAttribute('TrackCenterX',nil);motion:SetAttribute('TrackHalfWidth',nil)end
 X.run(1)
end
local function clean(tag)
 check(M.Active()==nil and revealGui()==nil and W.workspace:FindFirstChild('_RarePullStage')==nil,tag..': no presentation, stage or reveal GUI left')
 check(Collect.Flying()==0 and overlay()==nil,tag..': no seed left flying, its layer gone')
 check(#rarePlaying()==0 and not Audio.Running()and not Audio.Fading(),tag..': no reveal sound or sheet left ('..table.concat(rarePlaying(),',')..')')
 check(W.rsBound[M.BindName]==nil and W.actions[M.SkipAction]==nil,tag..': no render step or skip binding left')
 check(cam.CameraType==R.Enum.CameraType.Custom and X.controls.Enabled and X.hud.Main.Enabled and hb.Enabled,tag..': the camera, movement and the HUD are the player\'s')
end
-- run frames until nothing is flying (and, with the server, until it has ended its opening)
local function landAll(o)local g=0;while(Collect.Flying()>0 or M.Active()~=nil or(o and o.Bag.Parent))and g<2000 do step(o or{Bag={},Track={}});g+=1 end;X.run(.1)end

-- 1 + 2. every presentation waits, then a press collects it ---------------------------------------------------------------------------------
local cases={}
for rank=1,8 do cases[#cases+1]={Rank=rank,Tag=names[rank]..(rank>=6 and' Full'or' card')}end
for _,rank in ipairs({6,7,8})do cases[#cases+1]={Rank=rank,Tag=names[rank]..' InPlace',Keeper=true}end
for _,rank in ipairs({2,5,8})do cases[#cases+1]={Rank=rank,Tag=names[rank]..' short (Skip pack animations on)',Short=true}end
cases[#cases+1]={Rank=7,Tag='Cosmic Calm (Reduced Motion)',Reduced=true}
cases[#cases+1]={Rank=3,Tag='Rare card on a phone',Phone=true}
local cardPresses={'click','tap','Return','ButtonB','ButtonR2'}
local n=0
for _,c in ipairs(cases)do
 reset();n+=1
 if c.Keeper then X.keeper(V3(25,3,100),{})end
 if c.Short then X.player:SetAttribute(ATTR,true)end
 if c.Reduced then W.Gui.ReducedMotionEnabled=true end
 if c.Phone then W.UIS.TouchEnabled=true;W.UIS.KeyboardEnabled=false end
 local o=open(c.Rank);local run=o.Run;local tag=c.Tag
 if not check(run~=nil and run.Rank==c.Rank,tag..': the opener\'s presentation starts')then landAll(o)else
 untilShown(o,run)
 check(run.SawResult and titleShown()and oddsFinal(run),tag..': the result is shown (title, "1 in N")')
 -- 120 s without input
 local ok={still=true,title=true,seed=true,hint=true,hotbar=true,hand=true,packet=true,sound=true,world=true,claim=true}
 local hintText;local t0=R.clock;local k=0
 while R.clock-t0<120 do
  step(o,o.Bag.Parent and 1/30 or 1/10);k+=1
  if k%5==0 and R.clock-t0>.6 then -- (its hint comes in CollectHint s after the result)
   if M.Active()~=run or run.Done or not M.Waiting()then ok.still=false end
   if not(titleShown()and oddsFinal(run))then ok.title=false end
   if run.Kind=='Scene'then if not(run.InStage and cam.CameraType==R.Enum.CameraType.Scriptable)then ok.seed=false end elseif not cardSeed()then ok.seed=false end
   local h=hint();if not(h and h.Visible and h.TextTransparency<.5)then ok.hint=false end;hintText=h and h.Text
   if slotShowing(o.Name)then ok.hotbar=false end
   if o.SeedTool and o.SeedTool.Parent==X.char and o.SeedTool.SeedBody.LocalTransparencyModifier~=1 then ok.hand=false end
   if o.Packet and(o.Packet.LocalTransparencyModifier~=1 or o.PacketFx.Enabled)then ok.packet=false end
   if run.Clock()>run.TL.Length+.1 and(#rarePlaying()>0 or Audio.Running())then ok.sound=false end
  end
 end
 for _,p in ipairs(o.Track)do if p.V and p.D<.6 then ok.world=false end end
 check(ok.still,tag..': 120 s without input: the result still waits (nothing closes it)')
 check(ok.title and ok.seed,tag..': the title, "1 in N" and the seed stay on screen'..(run.Kind=='Scene'and' (the hero shot, in the stage)'or''))
 check(ok.hint and hintText==Card.CollectText(c.Phone==true),tag..': the hint says "'..tostring(hintText)..'"')
 check(o.EndedAt~=nil and near(o.EndedAt-o.At,o.Duration,.06),tag..': the server ended the opening on its own time ('..string.format('%.2f',o.Duration)..' s), the result waiting on')
 check(ok.hotbar and o.SeedTool and o.SeedTool.Parent~=nil,tag..': the seed\'s tool is in the inventory but the hotbar does not show it yet')
 check(o.Equipped and ok.hand and ok.packet,tag..': in the hand (the server put it there) it is hidden on this screen, the seed it builds a frame later too (and its effects off)')
 check(ok.world,tag..': the world seed never flew into the hand (it faded where it hovered)')
 check(ok.sound and not Audio.Running()and Audio.DuckLevel==0,tag..': the reveal\'s sounds and the music duck ended on its Length: it waits in silence')
 check(L.RevealRunning==false,tag..': and does not hold back the background drawing (RevealRunning off)')
 check(L.ClaimPress()==true,tag..': a press now is the reveal\'s (ClaimPress)')
 X.run(.2)
 -- the target before the press: the first free slot
 local free;for i=2,10 do local b=dock['Slot'..i];if b.Visible and b.ItemName.Text==''then free=b;break end end
 local how=run.Kind=='Scene'and(n%2==0 and'button'or'key')or cardPresses[n%#cardPresses+1]
 if c.Phone then how='tap'end
 local before=#landings;local bub=bubbles();local pressAt=R.clock
 local viewAt=nil
 press(o,how);X.run(1/30)
 check(run.Collected and run.CollectWhy=='press',tag..': a '..how..' collects it')
 if run.Kind~='Scene'then check(run.Done and revealGui()==nil or(X.pg:FindFirstChild('RarePullRevealOut')~=nil),tag..': the card goes (it fades as its seed flies off)')end
 local moved=false;local lastX;local overFade=nil
 local g=0;while(Collect.Flying()>0 or M.Active())and g<600 do
  W.frames(1,1/30);g+=1
  local v=flyView();if v then if lastX and math.abs(v.Position.X.Offset-lastX)>.5 then moved=true end;lastX=v.Position.X.Offset end
  -- (a story scene's way out: the seed already sits over its fade to black, never hidden with the HUD)
  if run.Kind=='Scene'and overFade==nil and R.clock-pressAt>.2 and R.clock-pressAt<M.SceneExit-.03 then local ov=overlay();overFade=ov~=nil and ov.Enabled~=false and v~=nil and v.ImageTransparency<.5 and run.InStage end
  if #landings>before and not viewAt then viewAt=landings[#landings]end
 end
 local land=landingOf(o.Id)
 local shown=slotShowing(o.Name)
 check(land and land.Cue,tag..': the seed lands (its hold ends with the arrival)')
 if run.Kind=='Scene'then check(overFade==true,tag..': during the way out the seed is already on screen, over the fade (its layer never hidden with the HUD)')end
 if c.Reduced then
  check(not moved and land and near(land.At-pressAt,(run.Kind=='Scene'and M.SceneExit or 0)+Collect.FadeSeconds,.1),tag..': Reduced Motion: no flight, a quick fade in place ('..string.format('%.2f',land and land.At-pressAt or -1)..' s)')
 else
  check(moved,tag..': it flies')
  check(land and land.X and shown and math.abs(land.X-select(1,centre(shown)))<1 and math.abs(land.Y-select(2,centre(shown)))<1,tag..': it lands ON the slot that then shows it ('..(land and land.X and string.format('%.0f,%.0f',land.X,land.Y)or'-')..' vs '..(shown and string.format('%.0f,%.0f',centre(shown))or'-')..')')
 end
 check(shown~=nil and shown==free,tag..': the hotbar shows the seed in the first free slot ('..(shown and shown.Name or'none')..')')
 check(land and shown and(land.Target==shown or land.Target==nil),tag..': the flight aimed at it')
 check(land and bubbleAt(land.At)~=nil and bubbles()==bub+1,tag..': the pickup cue (Bubble06) plays once, on the landing frame')
 check(o.SeedTool and o.SeedTool.SeedBody.LocalTransparencyModifier~=1 and(not o.Packet or(o.Packet.LocalTransparencyModifier~=1 and o.PacketFx.Enabled)),tag..': the seed shows in the hand again')
 X.run(.3);clean(tag)
 end
end
-- the hotbar shows the seed only after the flight lands: frame by frame
do
 reset()
 local o=open(4);local run=o.Run;untilShown(o,run);untilT(o,run,o.Duration+.5)
 local early=false;local landAt;local shownAt
 press(o,'click')
 local g=0;while Collect.Flying()>0 and g<300 do
  W.frames(1,1/60);g+=1
  local l=landingOf(o.Id);if l and not landAt then landAt=l.At end
  if slotShowing(o.Name)and not shownAt then shownAt=R.clock end
  if slotShowing(o.Name)and not landAt then early=true end
 end
 check(not early and landAt and shownAt and near(shownAt,landAt,1e-6),'frame by frame (60 fps): the hotbar shows the seed on the landing frame, never before')
 local fl=shownAt and slotShowing(o.Name):FindFirstChild('ArrivalFlash')
 check(fl~=nil,'and that slot flashes (its arrival flash)')
 landAll();clean('frame by frame')
end
-- where it lands: the slot of the stack it joins; the Bag button when no slot is free
do
 reset()
 -- a stack of the same seed (same look) already on the hotbar
 local spec=Rules.SeedDesignById[X.byRank[3]]
 local old=F.tool(W,spec.name,{GardenSeed=true,SeedInventoryId='old-seed',SeedId=X.byRank[3],SeedScale=1,Mutation='None',Weather='None',Rarity=Rules.GetRarity(X.byRank[3]),Stage=2},E.bag)
 X.run(.3)
 local stack=slotShowing(Names.Tool(old,Catalog))
 local o=open(3);local run=o.Run;untilShown(o,run);untilT(o,run,o.Duration+.5)
 check(stack and stack.Count.Visible==false,'a stack of the same seed is on the hotbar (one of it)')
 press(o,'click');landAll(o)
 local land=landingOf(o.Id)
 check(land and stack and math.abs(land.X-select(1,centre(stack)))<1,'it lands on the slot of the stack it joins')
 check(stack and stack.Count.Visible and stack.Count.Text=='x2','that slot now counts two ('..(stack and stack.Count.Text or'-')..')')
 clean('stack')
 -- no slot free: the Bag button
 reset()
 for i=1,10 do F.fruit(W,E.bag,'AppleSeed',1,'None',100+i,i).Name='Fruit '..i end
 X.run(.3)
 local full=true;for _,b in ipairs(slots())do if b.ItemName.Text==''then full=false end end
 check(full,'every visible slot is taken')
 o=open(2);run=o.Run;untilShown(o,run);untilT(o,run,o.Duration+.5)
 press(o,'tap');landAll(o)
 land=landingOf(o.Id)
 local bx,by=centre(bagButton)
 check(land and land.X and math.abs(land.X-bx)<1 and math.abs(land.Y-by)<1,'no slot free: it lands on the Bag button ('..(land and land.X and string.format('%.0f,%.0f',land.X,land.Y)or'-')..' vs '..string.format('%.0f,%.0f',bx,by)..')')
 check(bagButton:FindFirstChild('ArrivalFlash')~=nil,'and the Bag button flashes')
 check(slotShowing(o.Name)==nil,'it is in the Bag, not on a slot')
 clean('bag')
end
-- a collect before the server ends the opening (a skipper): the seed rests on its slot until its tool is there
do
 reset()
 local o=open(5);local run=o.Run;local tl=run.TL
 untilT(o,run,tl.SkipFrom+.3);press(o,'skip');check(run.Skipped==1,'early collect: skipped to the hit (the SKIP button)')
 untilT(o,run,L.ShownAt(tl)+M.CollectAfter+.05)
 check(o.Bag.Parent~=nil,'early collect: the server has not ended the opening yet')
 local packSlot=slotShowing('Seed Pack')
 press(o,'click');check(run.Collected,'early collect: collected')
 local g=0;while not landingOf(o.Id)and g<200 do step(o);g+=1 end
 local land=landingOf(o.Id)
 check(land and o.Bag.Parent~=nil,'early collect: it lands before the server has ended the opening')
 local parked=Collect.Flying()==1
 local v=flyView()
 check(parked and v and v.ImageTransparency<.5,'early collect: it rests on its slot, visible, while its tool is on its way')
 g=0;while o.Bag.Parent and g<400 do step(o);g+=1;if Collect.Flying()==0 then parked=false end end
 check(parked,'early collect: still resting there until the server ends the opening')
 landAll(o)
 local shown=slotShowing(o.Name)
 check(shown and land and math.abs(land.X-select(1,centre(shown)))<1,'early collect: the seed then shows on the very slot it landed on (the pack\'s, now free)')
 check(packSlot==shown,'early collect: (that was the pack\'s own slot)')
 clean('early collect')
end

-- 3. the press is the reveal's: the bat in the hand --------------------------------------------------------------------------------------
do
 reset()
 local o=open(4);local run=o.Run;untilShown(o,run)
 local bat=live(F.bat(W,E.bag));equip(bat)
 local manual=true;local t0=R.clock
 while R.clock-t0<30 do step(o,1/10);if bat.ManualActivationOnly~=true then manual=false end end
 check(manual,'the bat in the hand stays manual for the whole wait (30 s): a click is the reveal\'s')
 local claims=L.ClaimPress();check(claims,'ClaimPress: the reveal\'s')
 X.run(.3);press(o,'click');X.run(1/30)
 check(run.Collected and bat.ManualActivationOnly==false,'the click collects it, and the bat is the player\'s again at once')
 X.run(.3);check(L.ClaimPress()==false,'the next press is the tool\'s')
 landAll(o);clean('bat')
end

-- 4. edge cases ---------------------------------------------------------------------------------------------------------------------------
local function waiting(rank,opts)
 local o=open(rank,opts);local run=o.Run;untilShown(o,run);untilT(o,run,o.Duration+.6)
 X.run(.5) -- (its waiting checks have seen the world as it is)
 return o,run
end
local function selfCollected(tag,o,run,why,how)
 local landed=landingOf(o.Id)
 -- (a story scene's own safety check may see a chase / a fling first: 'danger', the same collect)
 check(run.Collected and(run.CollectWhy==why or run.Kind=='Scene'and run.CollectWhy=='danger'and(why=='chase'or why=='ragdoll')),tag..': the waiting result collects itself ('..tostring(run.CollectWhy)..')')
 landAll(o)
 landed=landingOf(o.Id)
 check(landed and landed.Cue,tag..': its seed flies in (lands)')
 if how~='nohotbar'then check(slotShowing(o.Name)~=nil,tag..': nothing is lost: the seed is on the hotbar')end
end
do -- the next pack opened while a result waits: it flies in first, then the next opening plays
 reset()
 local o1,run1=waiting(3)
 local o2=open(2);local run2=o2.Run
 check(run1.Collected and run1.Reason=='replaced'and run2~=run1 and M.Active()==run2,'next pack: the waiting seed is collected (flies in), the next opening starts')
 local l1=nil;local g=0;while not landingOf(o1.Id)and g<120 do step(o2);g+=1 end;l1=landingOf(o1.Id)
 check(l1 and slotShowing(o1.Name)~=nil,'next pack: the first seed has landed in the hotbar')
 check(run2.Clock()<run2.TL.Burst,'next pack: before the new pack has even burst open ('..string.format('%.2f',run2.Clock())..' s)')
 untilShown(o2,run2);untilT(o2,run2,L.ShownAt(run2.TL)+M.CollectAfter+.05);press(o2,'click');landAll(o2)
 check(slotShowing(o2.Name)~=nil,'next pack: its own seed collected in turn');clean('next pack')
end
do
 -- {what, how, the reason it gives, the tier} (a story scene holds the player still in its stage: being moved there is 'moved', its own rule)
 local trials={
  {'death',function()X.hum.Health=0 end,'death',4},
  {'death',function()X.hum.Health=0 end,'death',8},
  {'ragdoll',function()X.player:SetAttribute('GuardianRagdollActive',true)end,'ragdoll',4},
  {'fling',function()X.player:SetAttribute('GuardianFlingActive',true)end,'ragdoll',6},
  {'chase start',function()X.player:SetAttribute('ChestChaseRunActive',true)end,'chase',2},
  {'chase start',function()X.player:SetAttribute('ChestChaseQueued',true)end,'chase',7},
  {'a keeper chasing',function()X.keeper(V3(80,3,100),{TargetUserId=X.player.UserId,GuardianBehavior='CHASING'})end,'chase',4},
  {'teleport',function()X.root.CFrame=CF(0,3,400)end,'teleport',3},
  {'teleport',function()X.root.CFrame=CF(0,3,400)end,'teleport',6},
  {'onto the track',function()
   local motion=W.RS:FindFirstChild('RunnerMotion');motion:SetAttribute('TrackBoundaryZ',106);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',90)
   for z=100,112 do X.root.CFrame=CF(0,3,z);W.frames(2,1/30)end end,'left',4},
  {'walking far away',function()for z=100,200,2 do X.root.CFrame=CF(0,3,z);W.frames(1,1/30)end end,'left',5},
  {'pushed in the stage',function()for z=100,112 do X.root.CFrame=CF(0,3,z);W.frames(1,1/30)end end,'moved',7},
  {'the shop opening',function()X.pg:SetAttribute('SeedMenu','Economy')end,'menu',4,'nohotbar'},
  {'the shop opening',function()X.pg:SetAttribute('SeedMenu','Economy')end,'menu',8,'nohotbar'},
  {'the Bag opening',function()X.pg:SetAttribute('SeedMenu','Inventory')end,'menu',1},
 }
 for i,tr in ipairs(trials)do
  reset()
  local o,run=waiting(tr[4])
  local tag='edge: '..tr[1]..' ('..names[o.Rank]..')'
  check(M.Waiting(),tag..': (the result waits)')
  tr[2]();X.run(.3)
  selfCollected(tag,o,run,tr[3],tr[5])
  if tr[5]=='nohotbar'then
   check(not dock.Visible,tag..': (the hotbar is hidden by the menu)')
   X.pg:SetAttribute('SeedMenu',nil);X.run(.3)
   check(slotShowing(o.Name)~=nil,tag..': the menu closed, the seed is on the hotbar: nothing lost')
  end
  if tr[1]=='the Bag opening'then
   local l=landingOf(o.Id);local b=slotShowing(o.Name)
   check(l and b and math.abs(l.X-select(1,centre(b)))<1,tag..': it flew to its slot with the Bag open')
  end
  reset();clean(tag)
 end
 -- a menu already open (and a ragdoll already on) when the result appears: it waits all the same
 reset();X.pg:SetAttribute('SeedMenu','Index')
 local o,run=waiting(2)
 X.run(3);check(M.Waiting()and not run.Collected,'a menu already open when the result appears: it waits (only a menu OPENING collects it)')
 X.pg:SetAttribute('SeedMenu',nil);X.run(.5);X.pg:SetAttribute('SeedMenu','Daily');X.run(.5)
 check(run.Collected and run.CollectWhy=='menu','and a menu opened later collects it')
 landAll(o);reset();clean('menu already open')
end
do -- mobile: a tap anywhere collects; a HUD button, a hotbar slot, a drag, a long press do not
 reset();W.UIS.TouchEnabled=true;W.UIS.KeyboardEnabled=false
 local o,run=waiting(4)
 local h=hint();check(h and h.Text=='tap to collect!','mobile: the hint says "tap to collect!"')
 W.UIS.InputBegan:Fire({UserInputType=UT.Touch,KeyCode=KC.Unknown,Position=V3(640,700,0)},true) -- (a HUD button took it)
 W.UIS.InputEnded:Fire({UserInputType=UT.Touch,KeyCode=KC.Unknown,Position=V3(640,700,0)},true);X.run(.1)
 check(not run.Collected,'mobile: a press a HUD button took does not collect')
 local pack=live(F.pack(W,E.bag,2,'Pack06',1,'None'));X.run(.3)
 local slot=slotShowing(pack.Name)
 local sx,sy=centre(slot);local input={UserInputType=UT.Touch,Position=V3(sx,sy,0)}
 slot.InputBegan:Fire(input);W.UIS.InputBegan:Fire(input,true);W.UIS.InputEnded:Fire(input,true);slot.Activated:Fire(input);X.run(.2)
 check(not run.Collected and pack.Parent==X.char,'mobile: a hotbar slot tapped equips its item and does not collect')
 touch(o,.1,60);check(not run.Collected,'mobile: a drag (turning the camera) does not collect')
 touch(o,.6,0);check(not run.Collected,'mobile: a long press does not collect')
 X.run(.3);touch(o,.05,3);check(run.Collected and run.CollectWhy=='press','mobile: a tap anywhere does')
 landAll(o);check(slotShowing(o.Name)~=nil,'mobile: the seed is on the hotbar');clean('mobile')
end
do -- R155 (owner: "... skip it by spam clicking disable this feature and u can only skip at the bottom right of the screen"): the skip is the
 -- SKIP button (or gamepad B / R2, Enter) only; spam presses in every phase do nothing; then the first press that BEGAN after the result was
 -- shown (+ CollectAfter) collects it, one held down from before does not
 local cases={{3,'skip'},{5,'ButtonB'},{7,'B key'},{8,'skip'},{6,'ButtonB',true}}
 for _,c in ipairs(cases)do
  reset()
  if c[3]then X.keeper(V3(25,3,100),{})end
  local o=open(c[1]);local run=o.Run;local tl=run.TL;local hit=tl.Climax or tl.Burst;local shownAt=L.ShownAt(tl)
  local scene=run.Kind=='Scene'
  local tag='skip then collect ('..names[c[1]]..' '..run.Kind..', '..c[2]..')'
  -- a burst of presses: clicks and taps on the world (a story scene: on its full-screen button, and Space)
  local k=0
  local function spam()
   k+=1
   if scene then local b=X.find(revealGui(),'Backdrop');if b then b.InputBegan:Fire({UserInputType=UT.MouseButton1});b.Activated:Fire()end;if k%3==0 then press(o,'key')end
   elseif k%2==0 then click()else touch(o,0,2)end
  end
  local function spamUntil(t)local g=0;while run.Clock()<t and not run.Done and g<400 do spam();step(o);g+=1 end;return g end
  local n1=spamUntil(tl.SkipFrom-.02)
  check(not run.Skipped and not run.Collected and not skipShows(),tag..': opening: '..n1..' spam presses do nothing, no SKIP button yet')
  local n2=spamUntil(math.min(tl.SkipFrom+.4,hit-.12))
  check(not run.Skipped and run.Clock()<hit-.1,tag..': skip window: '..n2..' spam presses never skip')
  check(skipShows(),tag..': the SKIP button shows')
  local before=run.Clock()
  press(o,c[2])
  check(run.Skipped==1 and near(run.Clock(),hit-.02,.04)and not run.Collected,tag..': the '..(c[2]=='skip'and'SKIP button'or c[2])..' jumps to the hit ('..string.format('%.2f -> %.2f',before,run.Clock())..')')
  step(o);step(o);step(o);step(o)
  local n3=spamUntil(shownAt-.02)
  check(run.Skipped==1 and not run.Collected,tag..': hit to result: '..n3..' spam presses do nothing')
  check(not skipShows(),tag..': the SKIP button is gone once the hit has played')
  local n4=spamUntil(shownAt+M.CollectAfter-.15)
  check(run.SawResult and not run.Collected,tag..': the result just shown: '..n4..' spam presses do nothing (none began after it)')
  -- a press held down from just before the collect delay ended, let go after it (still a tap: under TapSeconds, not moved)
  local input={UserInputType=UT.Touch,KeyCode=KC.Unknown,Position=V3(300,200,0)}
  local b=scene and X.find(revealGui(),'Backdrop')
  if b then b.InputBegan:Fire(input)end;W.UIS.InputBegan:Fire(input,b~=nil and b~=false)
  local heldAt=run.Clock()
  untilT(o,run,shownAt+M.CollectAfter+.12) -- (its release, the press's claim, comes after PressWindow: a press of its own)
  W.UIS.InputEnded:Fire(input,b~=nil and b~=false);if b then b.Activated:Fire()end
  check(heldAt<shownAt+M.CollectAfter and run.Clock()-heldAt<M.TapSeconds and not run.Collected,tag..': a press held from before ('..string.format('%.2f',heldAt-shownAt)..' s after the result), let go after the delay, does not collect')
  step(o);step(o);step(o);step(o)
  press(o,scene and'button'or'tap')
  check(run.Collected and run.CollectWhy=='press',tag..': the next fresh tap collects it')
  landAll(o);check(slotShowing(o.Name)~=nil,tag..': in the hotbar');clean(tag)
 end
end
do -- an onlooker's pack: as before
 reset()
 local p=R.new('Player');p.Name='Onlooker';p.UserId=501;p.Parent=Players;others[#others+1]=p
 local c=R.new('Model');c.Name='Onlooker';c.Parent=W.workspace;p.Character=c
 local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(8,5,96);t.Parent=c
 local r=R.new('Part');r.Name='HumanoidRootPart';r.Size=V3(2,2,1);r.CFrame=CF(8,3,96);r.Parent=c
 local hm=R.new('Humanoid');hm.Health=100;hm.Parent=c
 local rh=R.new('Part');rh.Name='RightHand';rh.Size=V3(1,1,1);rh.CFrame=CF(9.5,4,96);rh.Parent=c
 local o=open(4,{Char=c})
 check(M.Active()==nil and not Collect.Held(o.Id),'onlooker: no presentation, no hold on this screen')
 local closest=math.huge
 local g=0;while o.Bag.Parent and g<400 do
  W.frames(1,1/30);g+=1
  local s=worldSeed();if s and s.PrimaryPart and worldSeedVisible()then closest=math.min(closest,(s:GetPivot().Position-(rh.CFrame*CF(0,-.5,0)).Position).Magnitude)end
  if W.workspace:GetServerTimeNow()-o.At>=o.Duration then serverEnd(o)end
 end
 check(closest<.5,'onlooker: their seed still flies into their hand ('..string.format('%.2f',closest)..' studs)')
 p.Parent=nil;c:Destroy();X.run(.2);clean('onlooker')
end

-- 5. sound --------------------------------------------------------------------------------------------------------------------------------
do
 -- a collect while the reveal still rings (a skip, then the collect at once): the tail fades out first; silent by the landing
 for _,rank in ipairs({5,8})do
  reset()
  local o=open(rank);local run=o.Run;local tl=run.TL;local tag='sound ('..names[rank]..')'
  untilT(o,run,tl.SkipFrom+.1);press(o,run.Kind=='Scene'and'button'or'click')
  untilT(o,run,L.ShownAt(tl)+M.CollectAfter+.05)
  local ringing=#rarePlaying()
  check(ringing>0 and run.Clock()<tl.Length,tag..': (the reveal still rings: '..ringing..' voices)')
  local pressAt=R.clock
  press(o,run.Kind=='Scene'and'button'or'click')
  check(run.Collected and not Audio.Running()and(Audio.Fading()or #rarePlaying()==0),tag..': the collect lets the reveal\'s sheet go: its tail fades')
  local whoosh;local silentBy;local g=0
  while not landingOf(o.Id)and g<300 do
   step(o,1/60);g+=1
   if #rarePlaying()==0 and not silentBy then silentBy=R.clock end
   for _,s in ipairs(E.sounds)do if s.Name=='SeedCollect_Whoosh'and s.PlayLog[1]and s.PlayLog[1].At>=pressAt then whoosh=s end end
  end
  local land=landingOf(o.Id)
  check(silentBy and land and silentBy<=pressAt+M.TailFade+.02 and silentBy<land.At,tag..': the reveal is silent '..string.format('%.2f',(silentBy or 99)-pressAt)..' s after the collect, before the seed lands')
  check(land and bubbleAt(land.At),tag..': the pickup cue on the landing frame')
  -- (the afterglow's 3D hum around a Secret+ puller is the world's, not the reveal's tail: RarePullWorld, for AuraSeconds)
  local others0=0;for _,s in ipairs(Y.sounds)do if s.IsPlaying and s.Name:match('^RarePull_')and s.Name~='RarePull_AuraHum'and(tonumber(s.Volume)or 0)>1e-4 then others0+=1 end end
  check(others0==0,tag..': and nothing of the reveal rings under it')
  if check(whoosh~=nil,tag..': the flight has its whoosh')then
   local l=whoosh.PlayLog[1];local def=Sounds.Get('Flight')
   local flyStart=l.At;local peakAt=flyStart+(def.Swell-l.TimePosition)/l.Speed
   check(near(peakAt-flyStart,Collect.FlySeconds*.5,1/60+1e-6),tag..': its swell lands on the flight\'s fastest frame (half way: '..string.format('%.3f',peakAt-flyStart)..' s)')
   local gain=(l.Volume or 0)*(whoosh.SoundGroup and tonumber(whoosh.SoundGroup.Volume)or 1)
   local loud=-99;for i=0,30 do local pos=l.TimePosition+i*.03*l.Speed;local lv=(Y.fileLoudness(whoosh.SoundId,pos)or Y.AssumedLoudness)+20*math.log10(math.max(1e-6,gain));loud=math.max(loud,lv)end
   check(loud<=-30,tag..': and stays soft (loudest '..string.format('%.1f',loud)..' LUFS; the whoosh cap is -30)')
  end
  local cueVol;for _,s in ipairs(E.sounds)do if s.SoundId=='rbxassetid://'..IA.AssetIds.Bubble06 and #s.PlayLog>0 then cueVol=s.Volume end end
  check(cueVol and cueVol<=.25,tag..': the pickup cue at its own level (the bag\'s Bubble06, '..tostring(cueVol)..')')
  landAll(o);clean(tag)
 end
end
-- 6. review fixes -------------------------------------------------------------------------------------------------------------------------
do -- the weather / Mech effects of a seed held out of the hand stay off with it, and come back as it lands (ItemCosmetics, the real script)
 local sc=R.new('LocalScript');sc.Name='ItemCosmetics';local okc,errc=pcall(W.load,'ItemCosmetics',sc);check(okc,'effects: the real ItemCosmetics loads: '..tostring(errc))
 local function sets()local f=W.workspace:FindFirstChild('_ItemCosmeticsR59');return f and #f:GetChildren()or-1 end
 for _,v in ipairs({{Tag='Drippy seed',Rank=4,FX='Drippy'},{Tag='Mech seed',Rank=5,Mech=true},{Tag='Frosted seed',Rank=3,FX='Frosted'}})do
  reset();X.run(.5)
  local tag='effects: '..v.Tag
  check(sets()==0,tag..': (no effect set before it)')
  local o,run=waiting(v.Rank,{FX=v.FX,Mech=v.Mech})
  check(o.Equipped and o.Packet and o.Packet.Parent~=nil and #W.CS:GetTagged('GardenItemFX')==1,tag..': in the hand, built and tagged (GardenItemFX) as the server does')
  local drawn=0;local frames=0
  for _=1,120 do step(o,1/20);frames+=1;if sets()~=0 then drawn+=1 end end
  check(M.Waiting()and not run.Collected,tag..': (the result still waits)')
  check(drawn==0,tag..': no drips / frost / gears at the opener\'s hand while the result waits ('..drawn..' of '..frames..' frames drew some)')
  press(o,run.Kind=='Scene'and'button'or'click')
  local early=false;local g=0
  while not landingOf(o.Id)and g<400 do step(o,1/60);g+=1;if sets()~=0 then early=true end end
  local land=landingOf(o.Id)
  check(land~=nil and not early,tag..': and none while the seed flies in')
  local at=nil;g=0
  while not at and g<120 do if sets()>0 then at=R.clock else step(o,1/60);g+=1 end end
  check(at~=nil and land and at-land.At<=.1,tag..': they are back on the frames after it lands ('..(at and land and string.format('%.3f s',at-land.At)or'never')..')')
  landAll(o);X.run(.5)
  check(sets()==1,tag..': and stay ('..sets()..' set)')
  reset();X.run(.5);check(sets()==0,tag..': the seed gone, its effects gone')
 end
 sc:Destroy()
end
do -- the watchdog: a hold nobody touches ends when its time is up, a touched one at its Due (not a whole Backstop after that), a live one never
 reset();local t0=R.clock
 Collect.Hold('wd-a');Collect.Hold('wd-b');Collect.Hold('wd-c')
 local nextTouch=0
 while R.clock-t0<14 do
  W.frames(1,.05)
  if R.clock-t0>=nextTouch then nextTouch+=.1;Collect.Touch('wd-c')end -- (the director: every frame; here every .1 s)
  if math.abs(R.clock-t0-4.5)<.026 and not landingOf('wd-b')then Collect.Touch('wd-b')end
 end
 local a,b,c=landingOf('wd-a'),landingOf('wd-b'),landingOf('wd-c')
 check(a and a.Cue==false and a.At-t0>=Collect.Backstop-.06 and a.At-t0<=Collect.Backstop+.1,'watchdog: an untouched hold ends after Backstop ('..(a and string.format('%.2f',a.At-t0)or'never')..' s)')
 local due=4.5+Collect.Backstop
 check(b and b.Cue==false and b.At-t0>=due-.06 and b.At-t0<=due+.1,'watchdog: a hold touched at 4.5 s ends at its Due, '..string.format('%.1f',due)..' s, not a Backstop after the first check ('..(b and string.format('%.2f',b.At-t0)or'never')..' s)')
 check(c==nil and Collect.Held('wd-c'),'watchdog: a hold touched all the time is still there after 14 s')
 Collect.Release('wd-c');check(landingOf('wd-c')~=nil and not Collect.Held('wd-c'),'watchdog: and ends when released')
 Collect.Clear()
end
do -- a story scene cut short before its hit: its result card follows; when that card cannot start, the hold is let go at once
 local function cutShort(tag,prepare)
  reset()
  local o=open(7);local run=o.Run
  if not check(run~=nil and run.Kind=='Scene','follow-up '..tag..': a story scene starts')then landAll(o);return nil end
  untilT(o,run,1)
  check(not run.SawClimax and Collect.Held(o.Id),'follow-up '..tag..': before its hit, the seed is held')
  prepare()
  for z=100,112 do X.root.CFrame=CF(0,3,z);W.frames(1,1/30)end -- (pushed in the stage: it cuts back to the world)
  local doneAt=nil;local g=0
  while g<60 and not(doneAt and R.clock-doneAt>=.5)do W.frames(1,1/30);g+=1;if run.Done and not doneAt then doneAt=R.clock end end
  return o,run,doneAt
 end
 for _,mode in ipairs({'Start gives nothing','no PlayerGui'})do
  local realStart=M.Start;local o,run,doneAt
  if mode=='Start gives nothing'then
   o,run,doneAt=cutShort(mode,function()M.Start=function()return nil end end)
   M.Start=realStart
  else
   o,run,doneAt=cutShort(mode,function()X.pg.Parent=nil end)
   X.pg.Parent=X.player
  end
  if o then
   check(run.Done and run.Reason=='moved','follow-up '..mode..': the scene was cut short ('..tostring(run.Reason)..')')
   check(M.Active()==nil,'follow-up '..mode..': and its result card did not start')
   local l=landingOf(o.Id)
   check(not Collect.Held(o.Id)and l and l.Cue==false and doneAt and l.At-doneAt<=.2,'follow-up '..mode..': the hold is let go at once, not by the watchdog ('..(l and doneAt and string.format('%.2f s',l.At-doneAt)or'still held')..')')
   landAll(o);reset()
  end
 end
 -- the result card that follows when it does start: still held, and collected by the next press
 reset()
 local o=open(7);local run=o.Run;untilT(o,run,1)
 for z=100,112 do X.root.CFrame=CF(0,3,z);W.frames(1,1/30)end
 W.frames(3,1/30)
 local card=M.Active()
 check(run.Done and card and card~=run and card.Kind=='Result' and Collect.Held(o.Id),'follow-up: the result card follows the cut-short scene, the seed still held')
 if card then
  untilShown(o,card);untilT(o,card,L.ShownAt(card.TL)+M.CollectAfter+.05)
  press(o,'click');check(card.Collected,'follow-up: its press collects it')
  landAll(o);check(slotShowing(o.Name)~=nil and landingOf(o.Id)and landingOf(o.Id).Cue,'follow-up: the seed flies into the hotbar')
 end
 reset()
end
do -- a teleport is still one, but a fast runner on a slow frame, a hitch and a fall are not
 local function moves(speed,dt,frames,pos,vel)
  reset();local o,run=waiting(4);X.hum.WalkSpeed=speed
  local base=X.root.CFrame.Position
  for i=1,frames do
   local p=pos(i,base);X.root.CFrame=CF(p.X,p.Y,p.Z);if vel then X.root.AssemblyLinearVelocity=vel end
   step(o,dt)
  end
  return o,run
 end
 -- WalkSpeed 300 at 8 fps: 36 studs a frame, back and forth on the spot (it does not leave)
 local o,run=moves(300,.12,16,function(i,b)return V3(b.X,b.Y,b.Z+(i%2==0 and 0 or 36))end)
 check(not run.Collected and M.Waiting(),'teleport: a runner at WalkSpeed 300 moving 36 studs a frame (8 fps) does not collect the result ('..tostring(run.CollectWhy)..')')
 -- the same at WalkSpeed 16 is no runner: it is a teleport
 o,run=moves(16,.12,4,function(i,b)return V3(b.X,b.Y,b.Z+(i%2==0 and 0 or 36))end)
 check(run.Collected and run.CollectWhy=='teleport','teleport: 36 studs in a frame at WalkSpeed 16 is a teleport ('..tostring(run.CollectWhy)..')');landAll(o)
 -- a hitch: a second with no frame, the runner (WalkSpeed 16) got 40 studs further
 o,run=moves(16,1,1,function(i,b)return V3(b.X,b.Y,b.Z+40)end)
 check(not run.Collected and M.Waiting(),'teleport: 40 studs over a 1 s hitch at WalkSpeed 16 does not collect the result ('..tostring(run.CollectWhy)..')')
 -- a fall: 50 studs down in a quarter second (it is falling at 200 studs/s)
 o,run=moves(16,.25,1,function(i,b)return V3(b.X,b.Y-50,b.Z)end,V3(0,-200,0))
 check(not run.Collected and M.Waiting(),'teleport: falling 50 studs in a quarter second does not collect the result ('..tostring(run.CollectWhy)..')')
 -- the real thing: the base / track teleport buttons jump hundreds of studs, whoever is running and however slow the frame
 for _,t in ipairs({{'at 60 fps',16,1/60},{'at 8 fps, WalkSpeed 300',300,.12},{'after a 1 s hitch',16,1}})do
  o,run=moves(t[2],t[3],2,function(i,b)return V3(b.X,b.Y,b.Z+(i==1 and 0 or 300))end)
  check(run.Collected and run.CollectWhy=='teleport','teleport: 300 studs ('..t[1]..') still collects the waiting result ('..tostring(run.CollectWhy)..')');landAll(o)
 end
 reset()
end
print(('R154 collect checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
