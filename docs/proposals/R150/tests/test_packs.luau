--!nocheck
-- R150 SFX fix round, part 3: the pack opening on the Roblox mock with the REAL PackOpeningFeedback, SeedPackClient, RevealFlourish and
-- InteractionAudio (the real cue pool, so a swallowed click is a missing sound, not a recorder artefact).
--  1. Pack-opening clicks: every click the server rules accept (SeedPackRules.ClickInterval) sounds - all 5 of a full-speed pack - and the
--     rate never exceeds the accepted click rate (no stacking), however fast the player taps.
--  2. An onlooker watching someone else's Secret / Cosmic / King pull hears one impact at the bag on the frame the seed appears; their own pull
--     (the opener has RarityRevealAudio) and Legendary / Mythic (RevealFlourish has its own) do not double it; a far bag and a stale reveal are silent.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
F.packAssets(W)
local noop=function()end
-- (Play / Stop on instances the mock has no method for; a Sound keeps its own recorder from sfx_env, which Inst methods would shadow)
function R.Inst:Play()local own=rawget(self,'_props').Play;if own then return own(self)end end
function R.Inst:Stop()local own=rawget(self,'_props').Stop;if own then return own(self)end end
function R.Inst:Pause()end
local Players=W.service('Players')
E.player('Tester')
local player,me=E.Player,E.char
do local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(0,5,100);t.Parent=me end
local others={}
function Players.GetPlayers()local out={player};for _,p in ipairs(others)do out[#out+1]=p end;return out end
Players.PlayerRemoving=R.signal()
local binds={};function W.Run.BindToRenderStep(_,name,_,fn)binds[name]=fn end;function W.Run.UnbindFromRenderStep(_,name)binds[name]=nil end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
W.stub('RarityRevealScreen',{Create=function()return setmetatable({},{__index=function()return noop end})end})
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local Audio=W.module('InteractionAudio')
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local art=R.new('Folder');art.Name='SeedArt';art.Parent=remotes
local seeds=R.new('Folder');seeds.Name='Seeds';seeds.Parent=art
local cat=R.new('Folder');cat.Name='SeedCatalog';cat.Parent=remotes
local function seedDef(id,name)
 local def=R.new('Folder');def.Name=id;def:SetAttribute('DisplayName',name);def.Parent=cat
 local m=Visuals.Seed({Id=id},1,CF(0,0,0),nil,1,nil,'None');m.Name=id;m.Parent=seeds
end
seedDef('SunflowerSeed','Sunflower');seedDef('ElderbloomSeed','Elderbloom');seedDef('SilentFrostbellSeed','Silent Frostbell')
seedDef('PolarStarbloomSeed','Polar Starbloom');seedDef('WinterCrownwoodSeed','Winter Crownwood')
local function body(model,x)for _,d in ipairs(model:GetDescendants())do end end
for _,v in ipairs(E.sounds)do if v.Name:match('^Interaction_')then E.load(v)end end
local function played(key)return E.plays('Interaction_'..key)end

-- 1. clicks -------------------------------------------------------------------------------------------------------------------------------------------
local pof=R.new('LocalScript');pof.Name='PackOpeningFeedback'
local ok,err=pcall(W.load,'PackOpeningFeedback',pof);check(ok,'the real PackOpeningFeedback loads: '..tostring(err))
for _,v in ipairs(E.sounds)do if v.Name:match('^Interaction_')then E.load(v)end end
local interval=Rules.ClickInterval
local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='p1',Stage=1},nil);tool.Activated=R.signal();tool.Enabled=true;tool.Parent=me
local carry=Visuals.CarryBag(me,1,'Pack01',1,1,'None')
binds.ChestChasePackPresentation()
R.advance(2)
local function tap(n,gap)
 local count=0
 for i=1,n do tool.Activated:Fire();count+=1;R.advance(gap);binds.ChestChasePackPresentation()end
 return count
end
-- every pack takes OpenClicks = 5 clicks: tapped at exactly the accepted rate, all five sound
E.resetPlays();R.advance(2)
tap(5,interval)
check(played('Bubble04')==5,'5 clicks at the accepted click rate (every '..interval..' s): 5 sounds, one per shake ('..played('Bubble04')..')')
-- tapped faster than the server accepts: the sound never outpaces the accepted clicks
R.advance(2);E.resetPlays()
local before=R.clock;tap(30,.02);local span=R.clock-before
local accepted=math.floor(span/interval)+1
check(played('Bubble04')>=accepted-2 and played('Bubble04')<=accepted+1,'30 taps in '..string.format('%.2f',span)..' s: sounds follow the accepted clicks (about '..accepted..'), not the taps ('..played('Bubble04')..')')
check(played('Bubble04')<30,'tapping faster than the interval never stacks one sound per tap')
-- a click while the pack is revealing / not held makes no sound
R.advance(2);E.resetPlays()
carry:SetAttribute('RevealAt',W.workspace:GetServerTimeNow());binds.ChestChasePackPresentation();tool.Activated:Fire()
check(played('Bubble04')==0,'a click while the reveal runs: silent (the server ignores it too)')
carry:SetAttribute('RevealAt',nil)
check((W.B.PackOpeningFeedback:find('Audio.Play(\'Bubble04\',Rules.ClickInterval*.8)',1,true))~=nil,'(source: the click passes a gap just under the click interval)')
carry:Destroy();pof.Destroying:Fire()

-- 2. an onlooker hears a Secret / Cosmic / King pull ----------------------------------------------------------------------------------------------------
local spc=R.new('LocalScript');spc.Name='SeedPackClient'
local okc,errc=pcall(W.load,'SeedPackClient',spc);check(okc,'the real SeedPackClient loads: '..tostring(errc))
local Impact=W.module('RevealFlourish').SoundId
local function bagOf(char)local b=Visuals.CarryBag(char,2,'Pack02',1,1,'None');return b end
local function otherPlayer(name,x,z)
 local p=R.new('Player');p.Name=name;p.UserId=100+#others;p.Parent=Players;others[#others+1]=p
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace;p.Character=c
 local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(x,5,z);t.Parent=c
 local h=R.new('Part');h.Name='HumanoidRootPart';h.Size=V3(2,2,1);h.CFrame=CF(x,4,z);h.Parent=c
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=c
 return p,c
end
local function impactPlays()local n=0;for _,s in ipairs(E.sounds)do if s.SoundId==Impact and(s.Name=='ChestChaseOneShot'or s.Name=='Seed burst')then n+=s.Plays end end;return n end
local function reveal(char,seedId,offset)
 local b=bagOf(char);b:SetAttribute('RevealSeedId',seedId);b:SetAttribute('RevealAt',W.workspace:GetServerTimeNow()-(offset or 0))
 return b
end
local function run(seconds)for _=1,math.floor(seconds*30)do W.frames(1,1/30)end end
local function heardFor(char,seedId,opts)
 opts=opts or{}
 R.advance(3);for _,s in ipairs(E.sounds)do s.Plays=0 end
 local b=reveal(char,seedId,opts.late)
 run(opts.seconds or 6)
 local n=impactPlays();b:Destroy();run(.5)
 return n
end
-- the camera sits near the onlooker's own character
W.workspace.CurrentCamera.CFrame=CF(0,6,20)
local _,oc=otherPlayer('Other',0,0)
check(heardFor(oc,'SilentFrostbellSeed')==1,'Secret pull by someone else: the onlooker hears ONE impact ('..impactPlays()..')')
check(heardFor(oc,'PolarStarbloomSeed')==1,'Cosmic pull: one impact')
check(heardFor(oc,'WinterCrownwoodSeed')==1,'King pull: one impact')
check(heardFor(oc,'ElderbloomSeed')==1,'Mythic pull: exactly one impact (RevealFlourish\'s own; the new cue does not double it)')
-- the pitch: King lower
-- far away and stale
local _,far=otherPlayer('Far',0,400)
check(heardFor(far,'SilentFrostbellSeed')==0,'a Secret pull 400 studs away is not heard')
check(heardFor(oc,'SilentFrostbellSeed',{late=W.module('RarityRevealSequence').SeedAt(6)+.6})==0,'a reveal that reaches this client .6 s after its seed moment (a late packet) is silent')
-- my own pull: the opener hears RarityRevealAudio, not this
local mine=heardFor(me,'SilentFrostbellSeed')
check(mine==0,'my own Secret pull: no onlooker impact (the opener has the reveal audio) ('..mine..')')
spc.Destroying:Fire()

print(('R150 pack checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
