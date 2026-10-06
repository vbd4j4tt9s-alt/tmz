--!nocheck
-- R152 z-fighting, the pack-opening scenes (not a test by itself; check_opening_zfight.py reads it): everything a pull puts into the world as plain parts, in the zfight.py scene format
-- ("SCENE <name> <json>": every part's path, size, position, rotation, colour, material, transparency and its Decal / SurfaceGui faces), at the moments that matter:
--  * the three story stages the Secret / Cosmic / King pulls build far above the map (RarePullScenes: the void vault, the space stage, the throne room) with their real pack and seed,
--    with and without the client-drawn images (RarePullArt) and in the lite (phone / low quality) build, from the first frame to the way out;
--  * the sky beam and its landing (RarePullFx.Beam: shockwave rings, cracks, debris on the ground) on a floor part, at every graphics tier, from the slam to the end of the impact;
--  * the Legendary / Mythic flourish (RevealFlourish: its shockwave rings, glow, pillar) at normal, giant and tiny pack scale, from the charge to the end of the burst.
-- The seed card (RarePullCard) is a ScreenGui (nothing in the world), its seed a ViewportFrame model: not part of the scene.
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Z=require('./zfight_world')
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Scenes=W.module('RarePullScenes')
local Fx=W.module('RarePullFx');local Art=W.module('RarePullArt');local World=W.module('RarePullWorld');local Flourish=W.module('RevealFlourish')
local Visuals=W.module('SeedPackVisuals')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local function reset()
 M.Abort('test');World.Clear()
 local cam=W.workspace.CurrentCamera
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true;X.lowFx=false
 X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 for _,c in ipairs(X.char:GetChildren())do if c.Name=='CarriedSeed'or c:IsA('Tool')then c:Destroy()end end
 R.advance(4)
end
local function start(rank,extra)
 local seedId=X.byRank[rank]
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local info={Rank=rank,SeedId=seedId,At=W.workspace:GetServerTimeNow(),Bag=bag,Mutation='None'}
 for k,v in pairs(extra or{})do info[k]=v end
 return M.Start(info),bag
end
local yields=0
local function hooks(ok)
 Art.Hooks.Spawn=function(fn)fn()end
 Art.Hooks.Wait=function()yields+=1 end
 Art.Hooks.Create=function(w,h,rgba)if not ok then error('EditableImage unavailable (test)')end;return {W=w,H=h,Data=rgba,Destroy=function()end}end
 Art.Hooks.Content=function(o)return 'rbxtemp://r152/'..o.W..'x'..o.H end
end
local function drawAll(ok)Art.Reset();hooks(ok);Art.Request(Art.Order)end
local function area(p)return'opening'end
local function scene(name)
 local parts=Z.dump(W.workspace,function(p)
  local path=Z.path(p)
  if path:find('_RarePullStage',1,true)then return'stage'end
  if path:find('Sky beam',1,true)or path:find('Light beam',1,true)or path:find('BeamTest',1,true)then return'beam'end
  if path:find('RevealFlourish',1,true)then return'flourish'end
  return'other'
 end)
 -- (a hidden pack the mock scaled to nothing has no position: left out)
 local kept={};for _,s in ipairs(parts)do if not(s:find('[%[,]%-?nan')or s:find('[%[,]%-?inf'))then kept[#kept+1]=s end end
 print('SCENE '..name..' {"parts":['..table.concat(kept,',')..']}')
end
-- 1. the story stages, in the real run (camera, HUD, stage, pack, seed) ----------------------------------------------------------------------
local function stages(tag,withArt)
 for rank=6,8 do
  reset()
  local run=start(rank);local tl=run.TL
  local marks={tl.SceneIn+.1,tl.SceneIn+(tl.Climax-tl.SceneIn)*.35,tl.SceneIn+(tl.Climax-tl.SceneIn)*.7,tl.Climax-.15,tl.Climax+.1,tl.Climax+.7,(tl.Climax+tl.FloatEnd)/2,tl.FloatEnd-.1}
  local mi=1;local t0=R.clock
  X.run(tl.Length+.3,1/30,function()
   local t=run.Done and math.huge or run.Clock()
   while mi<=#marks and t>=marks[mi]do
    local st=W.workspace:FindFirstChild('_RarePullStage')
    if st then scene(string.format('stage_%s_%s_%d',names[rank],tag,mi))end
    mi+=1
   end
  end)
 end
end
drawAll(true);stages('art',true)
drawAll(false);stages('plain',false)
-- the lite (phone / low quality) stages, built and posed by hand at the same moments
for _,withArt in ipairs({true,false})do
 drawAll(withArt)
 for rank=6,8 do
  local sc=Scenes.Build(rank,{Lite=true,Reduced=true})
  local tl=L.Timeline(rank,'Calm')
  for i,t in ipairs({tl.SceneIn+.5,tl.Climax-.2,tl.Climax+.2,tl.Climax+.8,tl.FloatEnd-.2})do
   sc:Update(t,tl);scene(string.format('lite_%s_%s_%d',names[rank],withArt and'art'or'plain',i))
  end
  sc:Destroy()
 end
end
-- 2. the sky beam on the ground ------------------------------------------------------------------------------------------------------------
local function clearWorld()for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='BeamTest'or c.Name=='Floor'or c.Name=='RevealFx'then c:Destroy()end end end
for _,withArt in ipairs({true,false})do
 drawAll(withArt)
 for tier=1,3 do
  clearWorld()
  local floor=R.new('Part');floor.Name='Floor';floor.Size=V3(400,4,400);floor.Anchored=true;floor.CFrame=CF(0,2,0);floor.Color=R.Color3.fromRGB(120,170,90);floor.Material=R.Enum.Material.Grass;floor.Parent=W.workspace
  local folder=R.new('Folder');folder.Name='BeamTest';folder.Parent=W.workspace
  local b=Fx.Beam({Parent=folder,Name='Sky beam',Ground=V3(10,4,20),Height=140,Width=2.5,Color=R.Color3.fromRGB(170,120,255),Glow=R.Color3.fromRGB(235,215,255),Land=1,Descent=.16,Hold=1.5,Fade=1,Tier=tier,Cracks=true})
  local ages={-.1}
  for k=0,40 do ages[#ages+1]=k*.04 end -- (every 1/25 s through the impact: the two shockwaves cross each other, and the cracks lie under both)
  for _,a in ipairs({1.6,2.0,2.2})do ages[#ages+1]=a end
  for i,a in ipairs(ages)do
   b:Update(1+a);scene(string.format('beam_%s_t%d_%d',withArt and'art'or'plain',tier,i))
  end
  b:Destroy()
 end
end
clearWorld()
-- 3. the Legendary / Mythic flourish at the bag's mouth ------------------------------------------------------------------------------------
for _,rank in ipairs({4,5,1,2,3})do for _,scale in ipairs({1,.3,12})do
 clearWorld()
 local folder=R.new('Folder');folder.Name='RevealFx';folder.Parent=W.workspace
 local fl=Flourish.Create(folder,rank,scale,{Tier=3})
 if fl then
  local mouth=CF(4,6,8)
  local burstAt=1.2
  local times={.2,.8,1.1}
  for k=0,40 do times[#times+1]=burstAt+k*.025 end -- (every 1/40 s through the burst: the second ring catches up with the first somewhere in it)
  times[#times+1]=2.5
  for i,t in ipairs(times)do
   fl:Update(mouth,t,burstAt,false);scene(string.format('flourish_%s_s%s_%d',names[rank],tostring(scale),i))
  end
  fl:Destroy()
 end
end end
