--!nocheck
-- R117 treadmill tiers: server build (BiomeVisuals.BuildTreadmillV131) + client effects (TreadmillFx), offline.
-- Run from a scratch folder holding roblox.luau and the bundle:
--   cp <repo>/tools/tests/roblox.luau .
--   (25396f1 = last commit before the R117 treadmill work)
--   git -C <repo> show 25396f1:src/ServerScriptService/ChestChaseServer/BiomeVisuals.lua > base_BiomeVisuals.lua
--   python3 <repo>/tools/tests/bundle.py tread_bundle.luau \
--     BiomeVisuals=<repo>/src/ServerScriptService/ChestChaseServer/BiomeVisuals.lua \
--     BiomeVisualsBase=base_BiomeVisuals.lua \
--     TreadmillFx=<repo>/src/ReplicatedStorage/TreadmillFx.lua \
--     TreadmillAnimation=<repo>/src/StarterPlayer/StarterPlayerScripts/TreadmillAnimation.client.lua
--   /opt/luau/luau test_treadmills.luau
local R=require('./roblox');local B=require('./tread_bundle')
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-4)end
-- Mock gaps used by the treadmill code ------------------------------------------------------------
local mt=getmetatable(CF(0,0,0));local oldIndex=mt.__index
mt.__index=function(c,k)
 if k=='Rotation'then return setmetatable({Position=V3(0,0,0),R=c.R,__type='CFrame'},mt)end
 if k=='ToObjectSpace'then return function(a,b)return a:Inverse()*b end end
 if k=='VectorToWorldSpace'then return function(a,v)return (a*v)-a.Position end end
 return oldIndex(c,k)
end
local rawIsA=R.Inst.IsA
local lights={PointLight=true,SpotLight=true,SurfaceLight=true}
R.Inst.IsA=function(self,c)if c=='Light'and lights[self._class]then return true end;return rawIsA(self,c)end
R.Inst.Emit=function(self,n)self._emitted=(self._emitted or 0)+n end
local function rng(seed)local s=seed;return {NextNumber=function()s=(s*1103515245+12345)%2147483648;return s/2147483648 end}end
local Random={new=function()return rng(7)end}
local env=setmetatable({Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,Color3=R.Color3,Enum=R.Enum,
 ColorSequence=R.ColorSequence,ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,
 NumberSequenceKeypoint=R.NumberSequenceKeypoint,NumberRange=R.NumberRange,typeof=R.typeof,UDim2=R.UDim2,UDim=R.UDim,Random=Random},{__index=_G})
local function load(name)local fn=assert(loadstring(B[name],'='..name));setfenv(fn,env);return fn()end
local Art,Base,Fx=load('BiomeVisuals'),load('BiomeVisualsBase'),load('TreadmillFx')
local function newBase(name)
 local base=R.new('Model');base.Name=name or'Base';base:SetAttribute('BaseIndex',1)
 local pad=R.new('Part');pad.Name='Pad';pad.Size=V3(120,1,200);pad.CFrame=CF(0,0,0);pad.Parent=base
 return base
end
local function bases(art)local out={};for _,d in ipairs(art:GetDescendants())do if d:IsA('BasePart')then table.insert(out,d)end end;return out end
local function countWhere(art,f)local n=0;for _,d in ipairs(art:GetDescendants())do if f(d)then n+=1 end end;return n end
-- 1. Server build: contract, collision, budget gating, counts -----------------------------------------
local counts={}
local isTexture=function(t)return type(t)=='string'and t:sub(1,29)=='rbxasset://textures/particles'end
for tier=1,7 do
 local base,old=newBase(),newBase()
 local belt,prompt=Art.BuildTreadmillV131(base,tier)
 local oldBelt,oldPrompt=Base.BuildTreadmillV131(old,tier)
 local art,oldArt=base:FindFirstChild('TreadmillArtV131'),old:FindFirstChild('TreadmillArtV131')
 local tag='T'..tier..': '
 -- Return values and every name/attribute other scripts use.
 check(belt and belt.Name=='Treadmill'and belt.Parent==base,tag..'belt returned and parented')
 check(prompt and prompt.ClassName=='ProximityPrompt'and prompt.Name=='TreadmillMenu',tag..'prompt returned')
 check(prompt.Parent and prompt.Parent.Name=='Upgrade badge'and prompt.Parent.Parent==art,tag..'prompt on Upgrade badge')
 check(prompt:GetAttribute('TreadmillVersion')==131 and prompt.Enabled==false and prompt.MaxActivationDistance==9,tag..'prompt attributes')
 for _,k in ipairs({'TreadmillVersion','TreadmillTrainingBelt','TrainingFacingDegrees','TreadmillLengthVersion','TreadmillFrameVersion','TreadmillTrackVersion','TreadmillPolishVersion'})do
  check(belt:GetAttribute(k)==oldBelt:GetAttribute(k),tag..'belt attribute '..k)
 end
 for k,v in pairs(oldArt:GetAttributes())do check(art:GetAttribute(k)==v,tag..'art attribute '..k)end
 check(art:GetAttribute('TreadmillFxVersion')==117,tag..'fx version attribute')
 -- Gameplay geometry unchanged: belt size/frame/collision and the prompt's position.
 check(belt.Size==oldBelt.Size and belt.CFrame.Position==oldBelt.CFrame.Position,tag..'belt size/frame unchanged')
 check(belt.CanCollide==true and belt.CanQuery==true and belt.Transparency==1,tag..'belt collides and is invisible')
 check(prompt.Parent.CFrame.Position==oldPrompt.Parent.CFrame.Position,tag..'prompt badge position unchanged')
 -- SpeedGainPopup contract: same moving track parts (direct children) and track emitters.
 local function motion(a)return countWhere(a,function(d)return d:IsA('BasePart')and d:GetAttribute('TrackMotion')~=nil and d.Parent==a end)end
 local function trackE(a)return countWhere(a,function(d)return d.ClassName=='ParticleEmitter'and d:GetAttribute('TreadmillTrackEmitter')end)end
 check(motion(art)==motion(oldArt),tag..'TrackMotion parts preserved ('..motion(art)..')')
 check(trackE(art)==trackE(oldArt),tag..'track emitters preserved')
 for _,name in ipairs({'Track surface','Track underlay','Console screen','Upgrade badge'})do check(art:FindFirstChild(name)~=nil,tag..name..' present')end
 -- Decoration never collides/queries/touches and is anchored; small parts cast no shadow.
 local parts=bases(art);counts[tier]=#parts
 for _,v in ipairs(parts)do
  if not(v.Anchored==true and v.CanCollide==false and v.CanQuery==false and v.CanTouch==false)then check(false,tag..'decor collides: '..v.Name)break end
 end
 for _,v in ipairs(parts)do
  local s=v.Size;if math.max(s.X,s.Y,s.Z)<2 and v.CastShadow~=false then check(false,tag..'small part casts shadow: '..v.Name)break end
 end
 -- Every emitter/light/beam starts disabled and is gated by the client budget (or by SpeedGainPopup for track motes).
 local fxCount,emitters,lightsN=0,0,0
 for _,d in ipairs(art:GetDescendants())do
  local cls=d.ClassName
  if cls=='ParticleEmitter'or lights[cls]or cls=='Beam'then
   fxCount+=1
   if cls=='ParticleEmitter'then emitters+=1 elseif lights[cls]then lightsN+=1 end
   check(d.Enabled==false,tag..cls..' '..d.Name..' disabled at build')
   local gated=d:GetAttribute('TreadmillTrackEmitter')==true or(d:GetAttribute('TreadmillFx')~=nil and(d:GetAttribute('TreadmillFxQuality')or 0)>=2)
   check(gated,tag..cls..' '..d.Name..' budget-gated')
   if cls~='PointLight'then check(isTexture(d.Texture),tag..d.Name..' uses a built-in particle texture')end
   if cls=='PointLight'then check(d.Shadows==false,tag..d.Name..' no shadows')end
  end
 end
 -- No uploaded assets anywhere in the model.
 for _,d in ipairs(art:GetDescendants())do
  for _,k in ipairs({'Texture','Image','MeshId','TextureID','SoundId'})do
   local v=rawget(d._props,k);if type(v)=='string'and v:find('rbxassetid')then check(false,tag..'asset id on '..d.Name)end
  end
 end
 check(art:FindFirstChild('Tier plaque')~=nil,tag..'tier plaque present')
 local numeral=art:FindFirstChild('Tier plaque').TierPlaqueDisplay.TierNumeral.Text
 check(numeral==({'I','II','III','IV','V','VI','VII'})[tier],tag..'plaque numeral '..numeral)
 local pips=art:FindFirstChild('Console screen').ConsoleDisplay.TierPips
 local lit=0;for i=1,7 do local c=pips['TierPip'..i].BackgroundColor3;if not(near(c.R,.12)and near(c.G,.13)and near(c.B,.16))then lit+=1 end end
 check(lit==tier,tag..'console pips lit = tier')
 print(string.format('T%d %-15s parts %3d (was %3d)  emitters %2d  lights %d  fx %2d  spin %d  pulse %2d',tier,art:GetAttribute('TreadmillTierName'),#parts,#bases(oldArt),emitters,lightsN,fxCount,
  countWhere(art,function(d)return d:GetAttribute('TreadmillSpin')~=nil end),countWhere(art,function(d)return d:GetAttribute('TreadmillPulse')~=nil end)))
end
for tier=2,7 do check(counts[tier]>counts[tier-1],('part count rises T%d %d > T%d %d'):format(tier,counts[tier],tier-1,counts[tier-1]))end
check(counts[7]<=260,'tier 7 stays under 260 parts ('..counts[7]..')')
-- Rebuild in place (upgrade) keeps the same belt and leaves one art model.
do
 local base=newBase()
 local belt1=Art.BuildTreadmillV131(base,3);belt1:SetAttribute('TrainingActive',false)
 local belt2,prompt2=Art.BuildTreadmillV131(base,7)
 local arts=0;for _,c in ipairs(base:GetChildren())do if c.Name=='TreadmillArtV131'then arts+=1 end end
 check(belt1==belt2 and arts==1 and base:FindFirstChild('TreadmillArtV131'):GetAttribute('SkinTier')==7,'upgrade rebuild keeps belt, one art model')
 check(prompt2.Parent.Parent==base:FindFirstChild('TreadmillArtV131'),'upgrade prompt belongs to new art')
 check(select(2,pcall(Art.BuildTreadmillV131,base,99))~=nil,'out-of-range tier clamps')
 check(base:FindFirstChild('TreadmillArtV131'):GetAttribute('SkinTier')==7,'tier 99 clamps to 7')
end
-- 2. Client effects controller ---------------------------------------------------------------------------
local map=R.new('Folder');map.Name='ChestChaseMap'
local basesFolder=R.new('Folder');basesFolder.Name='Bases';basesFolder.Parent=map
local machines={}
for tier=1,7 do
 local base=newBase('Base'..tier);base.Parent=basesFolder
 -- Space machines 400 studs apart so only one is near the camera at a time.
 base.Pad.CFrame=CF(tier*400,0,0)
 local belt=Art.BuildTreadmillV131(base,tier);machines[tier]={Base=base,Belt=belt,Art=base.TreadmillArtV131}
end
local camera={CFrame=CF(0,0,0)}
local state={Quality=3,Fast=false,Reduced=false}
local moves,moved=0,{}
local controller=Fx.new({Map=function()return map end,Camera=function()return camera end,
 Quality=function()return state.Quality end,Fast=function()return state.Fast end,Reduced=function()return state.Reduced end,
 Random=rng(3),Move=function(parts,frames)moves+=1;for i,p in ipairs(parts)do p.CFrame=frames[i];moved[p]=true end end})
local function look(tier,distance,away)
 local p=machines[tier].Belt.Position
 local eye=p+V3(0,6,distance)
 camera.CFrame=R.CFrame.lookAt(eye,away and eye+V3(0,0,1)or p)
end
local function run(seconds)for _=1,math.floor(seconds*60+.5)do controller:Step(1/60)end end
local function enabled(tier,cls,role)
 return countWhere(machines[tier].Art,function(d)return d.ClassName==cls and d.Enabled==true and(role==nil or d:GetAttribute('TreadmillFx')==role)end)
end
local function allOff(tier)
 return enabled(tier,'ParticleEmitter')==0 and enabled(tier,'PointLight')==0 and enabled(tier,'Beam')==0
end
-- Far away: nothing on, no animation.
look(7,400);run(1.2)
for tier=1,7 do check(allOff(tier),'T'..tier..' far: all fx off')end
check(moves==0,'far: no orbit moves')
-- High quality, near tier 7, idle: ambient emitters + lights on, training emitters off, orbiters move, arcs flicker.
look(7,30);run(1.5)
check(enabled(7,'ParticleEmitter','Ambient')>0,'T7 near: ambient emitters on')
check(enabled(7,'ParticleEmitter','Training')==0,'T7 idle: training emitters off')
check(enabled(7,'PointLight')>0,'T7 near: lights on')
check(moves>0,'T7 near: orbiters animate')
for tier=1,6 do check(allOff(tier),'T'..tier..' stays off while only T7 is near')end
local sawArc=false
for _=1,240 do controller:Step(1/60);if enabled(7,'Beam','Arc')>0 then sawArc=true end end
check(sawArc,'T7: lightning arcs flicker')
local pulseMoved=false
for _,d in ipairs(machines[7].Art:GetDescendants())do
 if d:GetAttribute('TreadmillPulse')and math.abs(d.Transparency-d:GetAttribute('TreadmillPulseBase'))>.02 then pulseMoved=true end
end
check(pulseMoved,'T7: neon pulses animate')
-- Training starts: burst once, training emitters on.
local function emitted(tier)return countWhere(machines[tier].Art,function(d)return(d._emitted or 0)>0 end)end
machines[7].Belt:SetAttribute('TrainingActive',true);run(.3)
check(emitted(7)>=2,'T7: run-start burst emitted ('..emitted(7)..' emitters)')
check(enabled(7,'ParticleEmitter','Training')>0,'T7 training: training emitters on')
machines[7].Belt:SetAttribute('TrainingActive',false);run(.3)
check(enabled(7,'ParticleEmitter','Training')==0,'T7 stop: training emitters off')
-- Low quality / FastMode: everything off and orbiters still.
state.Quality=1;run(.5);local before=moves;run(1)
check(allOff(7),'low quality: all fx off')
check(moves==before,'low quality: no per-frame moves')
state.Quality=3;state.Fast=true;run(.5)
check(allOff(7),'FastMode: all fx off')
state.Fast=false;run(.5)
check(enabled(7,'ParticleEmitter','Ambient')>0,'quality restored: emitters back')
-- Medium quality: quality-3 extras stay off, quality-2 effects stay on, rates scaled.
state.Quality=2;run(.5)
local q3on=countWhere(machines[7].Art,function(d)return(d.ClassName=='ParticleEmitter'or d.ClassName=='PointLight'or d.ClassName=='Beam')and d.Enabled and(d:GetAttribute('TreadmillFxQuality')or 0)>2 end)
check(q3on==0,'medium quality: tier-3-only effects off')
local scaled=true
for _,d in ipairs(machines[7].Art:GetDescendants())do
 if d.ClassName=='ParticleEmitter'and d.Enabled and d:GetAttribute('TreadmillFxRate')and not near(d.Rate,d:GetAttribute('TreadmillFxRate')*.55)then scaled=false end
end
check(scaled,'medium quality: emitter rates scaled to 55%')
-- Reduced motion: no moves, no arcs, pulses back at rest; lights stay on; no burst.
state.Quality=3;state.Reduced=true;run(.5);before=moves;run(1)
check(moves==before,'reduced motion: no orbit moves')
check(enabled(7,'Beam','Arc')==0,'reduced motion: arcs off')
local rest=true
for _,d in ipairs(machines[7].Art:GetDescendants())do
 if d:GetAttribute('TreadmillPulse')and not near(d.Transparency,d:GetAttribute('TreadmillPulseBase'),1e-6)then rest=false end
end
check(rest,'reduced motion: pulses restored to base')
check(enabled(7,'PointLight')>0,'reduced motion: lights stay on')
for _,d in ipairs(machines[7].Art:GetDescendants())do d._emitted=nil end
machines[7].Belt:SetAttribute('TrainingActive',true);run(.3)
check(emitted(7)==0,'reduced motion: no burst')
machines[7].Belt:SetAttribute('TrainingActive',false);state.Reduced=false;run(.5)
-- Off screen (camera close but looking away): no emitters, no animation.
look(7,40,true);run(.5);before=moves;run(1)
check(moves==before,'off screen: no orbit moves')
check(enabled(7,'ParticleEmitter')==0,'off screen: emitters off')
-- Every tier gets something on at high quality when near; low tiers stay modest.
look(7,400);run(.5)
local onCounts={}
for tier=1,7 do
 look(tier,30);run(.6)
 onCounts[tier]=enabled(tier,'ParticleEmitter')+enabled(tier,'PointLight')+enabled(tier,'Beam')
 check(onCounts[tier]>0,'T'..tier..' near: some fx enabled')
 look(tier,400);run(.6)
 check(allOff(tier),'T'..tier..' after leaving: all fx off')
end
print('fx enabled near (high quality, idle): '..table.concat(onCounts,' '))
check(onCounts[7]>onCounts[1]and onCounts[5]>onCounts[2],'higher tiers light up more')
-- Rebuilding (upgrade) while near: old record dropped, new art picked up.
look(5,30);run(1.2)
local belt5=Art.BuildTreadmillV131(machines[5].Base,6);machines[5].Art=machines[5].Base.TreadmillArtV131
run(1.3)
check(enabled(5,'ParticleEmitter','Ambient')>0,'upgrade while near: new art effects on')
local records=0;for _ in pairs(controller.Records)do records+=1 end
check(records==7,'one record per treadmill after upgrade ('..records..')')
check(belt5==machines[5].Belt,'upgrade keeps belt')
-- Streaming: a removed ornament marks the record dirty and is dropped from the lists.
local orb=machines[7].Art:FindFirstChild('Orbiting energy orb')
if orb then orb.Parent=nil;machines[7].Art.DescendantRemoving:Fire(orb)end -- the mock only fires ChildRemoved
look(7,30);run(1.2)
local stale=false
for _,e in ipairs(controller.Records[machines[7].Art].Lists.Spin)do if e.Inst==orb then stale=true end end
check(not stale,'streamed-out part leaves the spin list')
controller:Destroy()
check(allOff(7),'destroy: all fx off')
-- TreadmillAnimation.client.lua still compiles with the effects hook.
check(loadstring(B.TreadmillAnimation,'=TreadmillAnimation')~=nil,'TreadmillAnimation compiles')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
