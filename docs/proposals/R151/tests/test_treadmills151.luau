--!nocheck
-- R151 treadmill polish: checks of the REAL code on the Roblox mock (R149 zfight_world: every ReplicatedStorage and ChestChaseServer module of this
-- checkout): BiomeVisuals.BuildTreadmillV131 with the dressing (TreadmillLook151), TreadmillFx (belt scroll, images, label hide), TreadmillBeltArt151
-- (the belt images and their routes), GardenUpgradeService (the sign), Config / BalanceValues81 (round per-step gains) and SpeedPopupStyle.FormatGain.
-- Prints "ok <name>" / "FAIL <name>: why", "BUDGET ..." lines, "ALPHA <name> <w> <h> <hex>" (the drawn belt images, compared with the PNGs by
-- run_treadmills.sh), and errors at the end if anything failed.
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return{}end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local Config=server('Config');local Art=server('BiomeVisuals');local Upgrade=server('GardenUpgradeService')
local Look=W.module('TreadmillLook151');local Belt=W.module('TreadmillBeltArt151');local Fx=W.module('TreadmillFx');local Style=W.module('SpeedPopupStyle')
local passed,failed=0,0
local function check(name,cond,why)
 if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end
end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local function rgb(c,r,g,b)return c and math.floor(c.R*255+.5)==r and math.floor(c.G*255+.5)==g and math.floor(c.B*255+.5)==b end
local function newBase(name,at)
 local base=R.new('Model');base.Name=name or'Base';base:SetAttribute('BaseIndex',1)
 local pad=R.new('Part');pad.Name='Pad';pad.Size=V3(118,1,180);pad.CFrame=at or CF(0,4.5,0);pad.Parent=base
 base.Parent=W.workspace
 return base
end
local function build(base,skin,level,dressed)
 if dressed==false then Art.TreadmillLook=false end
 local warns=W.warns or 0
 local belt,prompt=Art.BuildTreadmillV131(base,skin,level)
 Art.TreadmillLook=nil
 return belt,prompt,(W.warns or 0)-warns
end
local function parts(root)local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then out[#out+1]=d end end;return out end
local function count(root,f)local n=0;for _,d in ipairs(root:GetDescendants())do if f(d)then n+=1 end end;return n end
local LIGHT={PointLight=true,SpotLight=true,SurfaceLight=true}
local EXPECT={'+20/step','+65/step','+335/step','+2K/step','+10K/step','+65K/step','+500K/step'}
local OLD_MULT={1,4,20,100,600,4000,30000} -- BalanceValues81.MachineMultipliers before R151

-- 1. The "+N/step" numbers: round multiples of 5, the real award, the rounding rule, one formatter ---------------------------------------------
do
 local function allowed(v) -- "round": below 1,000 a multiple of 5; in K / M: 1, 1.5, 2 ... under 10 of the unit, a multiple of 5 from 10 up
  if v<1000 then return v%5==0 end
  local u=v>=1e6 and 1e6 or 1e3;local m=v/u
  if m<10 then return near(m*2,math.floor(m*2+.5),1e-9)end
  return near(m%5,0,1e-9)
 end
 local rows={}
 for level=1,7 do
  local tier=Config.TreadmillTiers[level]
  local gain=Look.StepGain(Config.TrainingPointsPerSecond,Config.TrainingInterval,tier.Multiplier)
  local old=100/6*OLD_MULT[level]
  -- nearest round value; UP when the nearest would lose more than ~3 %
  local below,above=nil,nil
  for v=5,2e6,5 do if allowed(v)then if v<=old+1e-9 then below=v elseif not above then above=v;break end end end
  local pick=below and above and((old-below<=above-old)and below or above)or above
  if pick<old*.97 then pick=above end
  check(('level %d: the per-step gain is a whole multiple of 5 (%s)'):format(level,tostring(gain)),near(gain,math.floor(gain+.5),1e-6)and math.floor(gain+.5)%5==0)
  check(('level %d: %.4g -> %s is the nearest round value, never more than 3%% down (%s)'):format(level,old,Look.Format(pick),Look.Format(gain)),near(gain,pick,1e-6))
  check(('level %d: label %s'):format(level,EXPECT[level]),Look.LabelText(gain)==EXPECT[level],Look.LabelText(gain))
  -- the server pays exactly that (Config.GetTrainingAward pays whole fives and carries the rest): 1 tick, and 600 ticks in a row
  local award,rest=Config.GetTrainingAward(0,tier.Multiplier,1)
  local sum,carry=0,0;for _=1,600 do local a;a,carry=Config.GetTrainingAward(carry,tier.Multiplier,1);sum+=a end
  check(('level %d: one training step awards exactly %d (rest %.2g), 600 steps award 600 x it (%d)'):format(level,award,rest,sum),
   near(award,gain,1e-6)and rest<1e-6 and near(sum,600*gain,1e-6))
  rows[#rows+1]=('L%d %s -> %s (%+.1f%%) machine x%s'):format(level,Look.Format(old),Look.Format(gain),(gain/old-1)*100,tostring(tier.Multiplier))
 end
 print('GAINS '..table.concat(rows,' | '))
 local same=true
 for _,v in ipairs({1,5,17,20,65,335,999,999.6,1000,1666.7,2000,9999,10000,65000,66666.7,500000,999950,1e6,2.5e9,7e12})do
  if Look.Format(v)~=Style.FormatGain(v)then same=false end
 end
 check('the label, the sign and the speed popups use the same formatter (SpeedPopupStyle.FormatGain)',same)
 check('formatter boundaries: 999.6 -> 1K, 999,950 -> 1M, never "+0"',Style.FormatGain(999.6)=='1K'and Style.FormatGain(999950)=='1M'and Style.FormatGain(.3)=='1')
end

-- 2. Every level and biome builds; the machine's own shape is unchanged; nothing new collides -------------------------------------------------------
local function signature(p)
 local c=p.CFrame.Position;local s=p.Size;local col=p.Color
 return table.concat({p.Name,p.ClassName,('%.3f,%.3f,%.3f'):format(s.X,s.Y,s.Z),('%.3f,%.3f,%.3f'):format(c.X,c.Y,c.Z),('%.3f,%.3f,%.3f'):format(col.R,col.G,col.B),
  tostring(p.Material),('%.3f'):format(p.Transparency or 0),tostring(p.Shape)},'|')
end
local budgets={}
do
 local warns=0;local built=0;local wrong={}
 for skin=1,7 do for level=1,7 do
  local base=newBase('Combo');local _,_,w=build(base,skin,level)
  local dress=base.TreadmillArtV131:FindFirstChild('TreadmillDress151');warns+=w;built+=1
  if not(dress and dress:GetAttribute('DressGrade')==Look.GradeOf(level)and dress:GetAttribute('DressBiome')==Look.BiomeOf(skin))then wrong[#wrong+1]=skin..'/'..level end
  base:Destroy()
 end end
 check(('every skin x level builds with its dressing (%d builds, no warning)'):format(built),#wrong==0 and warns==0,table.concat(wrong,' ')..' warns '..warns)
 for level=1,7 do
  local tag='L'..level..' '
  local plain,dressed=newBase('Plain'),newBase('Dressed')
  local belt0,prompt0=build(plain,level,level,false)
  local belt1,prompt1=build(dressed,level,level)
  local art0,art1=plain.TreadmillArtV131,dressed.TreadmillArtV131
  local dress=art1:FindFirstChild('TreadmillDress151')
  check(tag..'undressed build has no dressing (no TreadmillLook151 = exactly as before R151)',art0:FindFirstChild('TreadmillDress151')==nil and count(art0,function(d)return d.ClassName=='Texture'end)==0)
  -- running surface and step detection: the training belt is identical, solid, invisible, and the only thing that collides
  check(tag..'the training belt is unchanged (size, CFrame, collision, query, transparency, attributes)',belt1.Size==belt0.Size and belt1.CFrame.Position==belt0.CFrame.Position
   and belt1.CanCollide==true and belt1.CanQuery==true and belt1.Transparency==1 and belt1:GetAttribute('TreadmillTrainingBelt')==true and belt1:GetAttribute('TrainingFacingDegrees')==belt0:GetAttribute('TrainingFacingDegrees'))
  -- (and as it was before R151: 9.4 x 0.4 x 15.84 at pad * (-34, top + .9, 75), turned 180 degrees)
  local want=dressed.Pad.CFrame*CF(-34,dressed.Pad.Size.Y/2+.9,75)*R.CFrame.Angles(0,math.pi,0)
  local lb=want:PointToObjectSpace(belt1.CFrame.Position)
  check(tag..'the training belt is where and how big it was before R151',near(belt1.Size.X,9.4)and near(belt1.Size.Y,.4)and near(belt1.Size.Z,15.84)
   and lb.Magnitude<1e-6 and near(belt1.CFrame.LookVector.X,want.LookVector.X)and near(belt1.CFrame.LookVector.Z,want.LookVector.Z),tostring(belt1.Size))
  check(tag..'the menu prompt and its badge are unchanged',prompt1.Name=='TreadmillMenu'and prompt1.Enabled==false and prompt1.MaxActivationDistance==prompt0.MaxActivationDistance
   and prompt1.Parent.Name=='Upgrade badge'and prompt1.Parent.CFrame.Position==prompt0.Parent.CFrame.Position)
  -- shape: every part of today's machine is still there with the same size, place, colour and material, except the retired flow pieces
  local want,have={},{}
  for _,p in ipairs(parts(art0))do if p:GetAttribute('TrackMotion')~='Flow'then local k=signature(p);want[k]=(want[k]or 0)+1 end end
  for _,p in ipairs(parts(art1))do if not p:IsDescendantOf(dress)then local k=signature(p);have[k]=(have[k]or 0)+1 end end
  local missing,extra=0,0
  for k,n in pairs(want)do if(have[k]or 0)~=n then missing+=1 end end
  for k,n in pairs(have)do if(want[k]or 0)~=n then extra+=1 end end
  check(tag..'every part of the machine keeps its size, place, colour and material (only the flow pieces are retired)',missing==0 and extra==0,missing..' missing, '..extra..' extra')
  local flow0=count(art0,function(d)return d:GetAttribute('TrackMotion')=='Flow'end)
  check(tag..'the per-part flow pieces are retired ('..flow0..'), the chevrons stay',count(art1,function(d)return d:GetAttribute('TrackMotion')=='Flow'end)==0
   and dress:GetAttribute('RetiredFlowParts')==flow0
   and count(art1,function(d)return d:GetAttribute('TrackMotion')=='Arrow'end)==count(art0,function(d)return d:GetAttribute('TrackMotion')=='Arrow'end)
   and count(art1,function(d)return d:GetAttribute('TreadmillTrackEmitter')==true end)==count(art0,function(d)return d:GetAttribute('TreadmillTrackEmitter')==true end))
  -- collision: no part of the art (old or new) collides, answers raycasts or touches; all anchored; new parts cast no shadow
  local bad
  for _,p in ipairs(parts(art1))do if not(p.Anchored and p.CanCollide==false and p.CanQuery==false and p.CanTouch==false)then bad=p.Name;break end end
  check(tag..'nothing in the art collides, answers raycasts or touches',bad==nil,bad)
  bad=nil;for _,p in ipairs(parts(dress))do if p.CastShadow~=false then bad=p.Name end end
  check(tag..'new parts cast no shadow',bad==nil,bad)
  -- budgets per grade
  local G=Look.Grades[Look.GradeOf(level)]
  local new=#parts(dress)
  local lights=count(art1,function(d)return LIGHT[d.ClassName]end)
  local function mine(d)return d:GetAttribute('TreadmillDress151')==true end
  local newEmit=count(art1,function(d)return d.ClassName=='ParticleEmitter'and mine(d)end)
  local newBeams=count(art1,function(d)return d.ClassName=='Beam'and mine(d)end)
  local textures=count(art1,function(d)return d.ClassName=='Texture'end)
  local total=#parts(art1)
  budgets[level]={Parts=total,Before=#parts(art0),New=new,Retired=flow0,Lights=lights,LightsBefore=count(art0,function(d)return LIGHT[d.ClassName]end),Emitters=newEmit,Beams=newBeams,Textures=textures}
  print(('BUDGET L%d %s parts %d -> %d (+%d new, -%d retired) lights %d -> %d (cap %d) new emitters %d new beams %d textures %d'):format(level,Look.GradeOf(level),
   #parts(art0),total,new,flow0,budgets[level].LightsBefore,lights,G.Cap,newEmit,newBeams,textures))
  check(tag..('new parts within the %s budget (%d <= %d)'):format(Look.GradeOf(level),new,G.Budget),new<=G.Budget)
  check(tag..('real lights of the whole machine within the cap (%d <= %d)'):format(lights,G.Cap),lights<=G.Cap)
  check(tag..('new emitters / beams within the grade (%d <= %d, %d <= %d)'):format(newEmit,G.Emitters,newBeams,G.Beams),newEmit<=G.Emitters and newBeams<=G.Beams)
  check(tag..'the machine stays under 260 parts (R117) ('..total..')',total<=260)
  check(tag..('one belt texture layer per grade layer (%d)'):format(textures),textures==#Look.Layers(Look.BiomeOf(level),Look.GradeOf(level))and textures>=1)
  -- effects near the camera only: every new light / particle / beam is disabled at build, with an R117 role and a quality of 2 or more
  local gated=true;local builtIn=true
  for _,d in ipairs(art1:GetDescendants())do
   if mine(d)and(d.ClassName=='ParticleEmitter'or LIGHT[d.ClassName]or d.ClassName=='Beam')then
    if d.Enabled~=false or d:GetAttribute('TreadmillFx')==nil or(d:GetAttribute('TreadmillFxQuality')or 0)<2 then gated=false end
    if d.ClassName~='PointLight'and not tostring(d.Texture):find('^rbxasset://textures/particles/')then builtIn=false end
    if LIGHT[d.ClassName]and d.Shadows~=false then gated=false end
   end
  end
  check(tag..'new lights, particles and beams start off and are gated by TreadmillFx (role, quality >= 2, no shadows)',gated)
  check(tag..'new particles and beams use built-in textures',builtIn)
  local asset=false
  for _,d in ipairs(art1:GetDescendants())do for _,k in ipairs({'Texture','Image','MeshId','TextureID','SoundId'})do local v=rawget(d._props,k);if type(v)=='string'and v:find('rbxassetid')then asset=true end end end
  check(tag..'no asset id anywhere in the machine (the belt images are painted on the client)',not asset)
  -- the label: the level's round gain, above the front, on the tier plaque
  local label=dress:FindFirstChild('StepLabel',true)or art1:FindFirstChild('StepLabel',true)
  local gain=label and label:FindFirstChild('Gain')
  check(tag..'"+N/step" label reads '..EXPECT[level],gain and gain.Text==EXPECT[level]and dress:GetAttribute('StepLabel')==EXPECT[level],gain and gain.Text)
  check(tag..'the label hangs on the tier plaque, is drawn within 90 studs and hides for its training owner',label and label.Parent.Parent.Name=='Tier plaque'
   and label.MaxDistance==90 and label:GetAttribute('HideWhileOwnerTrains')==true)
  -- belt textures: on the Track surface's top face, with an image name and a scroll rate; no new part moves
  local okTex=true
  for _,d in ipairs(art1:GetDescendants())do if d.ClassName=='Texture'then
   if not(d.Parent.Name=='Track surface'and d.Face==R.Enum.NormalId.Top and Belt.Sizes[d:GetAttribute('BeltImage')]and(d:GetAttribute('TreadmillScroll')or 0)>0 and d.Texture=='')then okTex=false end
  end end
  check(tag..'belt textures on the Track surface top, with an image and a scroll rate, painted on the client',okTex)
  check(tag..'no new part is moved per frame (no TrackMotion, no spin)',count(dress,function(d)return d:GetAttribute('TrackMotion')~=nil or d:GetAttribute('TreadmillSpin')~=nil end)==0)
  -- the label floats above everything of the front
  local top=-math.huge;local origin=belt1.CFrame
  for _,p in ipairs(parts(art1))do if not p:IsDescendantOf(dress)and p.Transparency<.9 and not p:GetAttribute('TreadmillSpin')then
   local l=origin:PointToObjectSpace(p.CFrame.Position)
   if l.Z<-4 then top=math.max(top,l.Y)end
  end end
  local at=label and label.Parent.Parent.CFrame*label.Parent.Position
  check(tag..'the label is above the front',at and origin:PointToObjectSpace(at).Y>top)
  plain:Destroy();dressed:Destroy()
 end
 do -- the light cap binds: with a top cap of 4, level 6 (4 lights of its own) gets no new light
  local cap=Look.Grades.top.Cap;Look.Grades.top.Cap=4
  local base=newBase('Cap');build(base,6,6)
  local lights=count(base.TreadmillArtV131,function(d)return LIGHT[d.ClassName]end)
  Look.Grades.top.Cap=cap;base:Destroy()
  check('the light cap counts the machine\'s own lights: a cap of 4 at level 6 adds none ('..lights..')',lights==4)
 end
 local layers={}
 for _,g in ipairs({'low','mid','top'})do layers[#layers+1]=Look.Grades[g].Layers end
 check('higher grades get more belt layers, edge flows and light (low < mid < top)',layers[1]<layers[2]and layers[2]<layers[3]and not Look.Grades.low.EdgeBeams and Look.Grades.mid.EdgeBeams
  and Look.Grades.low.Cap<Look.Grades.mid.Cap and Look.Grades.mid.Cap<Look.Grades.top.Cap and Look.Grades.top.Pulse and not Look.Grades.mid.Pulse)
end

-- 3. The client: images, scroll with the chevrons, effects near the camera only, the label hide --------------------------------------------------
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
local machines={}
for level=1,7 do
 local base=newBase('Base'..level,CF(level*400,4.5,0));base.Parent=bases
 local belt=build(base,level,level);machines[level]={Base=base,Belt=belt,Art=base.TreadmillArtV131}
end
local camera={CFrame=CF(0,0,0)}
local state={Quality=3,Fast=false,Reduced=false}
local created,published={},{}
Belt.Reset()
Belt.Hooks.Create=function(w,h,rgba)created[#created+1]={w,h,rgba};return{Fake=true,W=w,H=h,Destroy=function()end}end
Belt.Hooks.Content=function(o)return{ContentOf=o}end
Belt.Hooks.Spawn=function(f)f()end
local moved={}
local controller=Fx.new({Map=function()return map end,Camera=function()return camera end,Quality=function()return state.Quality end,Fast=function()return state.Fast end,
 Reduced=function()return state.Reduced end,Random=W.env.Random.new(3),Move=function(ps,cfs)for i,p in ipairs(ps)do p.CFrame=cfs[i];moved[p]=true end end,
 Look=Look,Belt=Belt,UserId=function()return 77 end,Publish=function(s)published[#published+1]=s end})
local function look(level,distance,away)
 local p=machines[level].Belt.Position;local eye=p+V3(0,6,distance)
 camera.CFrame=R.CFrame.lookAt(eye,away and eye+V3(0,0,1)or p)
end
local function run(seconds)for _=1,math.floor(seconds*60+.5)do controller:Step(1/60)end end
local function textures(level)local out={};for _,d in ipairs(machines[level].Art:GetDescendants())do if d.ClassName=='Texture'then out[#out+1]=d end end;return out end
look(7,400);run(1.2)
do -- images: drawn once per image name, applied to every texture, route published
 local routes,names=true,{}
 for level=1,7 do for _,t in ipairs(textures(level))do names[t:GetAttribute('BeltImage')]=true
  if not(t:GetAttribute('BeltRoute')=='generated'and type(t.TextureContent)=='table'and t.TextureContent.ContentOf)then routes=false end end end
 local distinct=0;for _ in pairs(names)do distinct+=1 end
 check('every belt texture gets its drawn image (route "generated", Content.fromObject of an EditableImage)',routes)
 check(('one EditableImage per image name, shared by every treadmill (%d made for %d names)'):format(#created,distinct),#created==distinct and distinct==5)
 local sizes=true;for _,c in ipairs(created)do if buffer.len(c[3])~=c[1]*c[2]*4 then sizes=false end end
 check('the images are white RGBA buffers of the right size (WritePixelsBuffer)',sizes)
 check('the route is published (TreadmillBeltTextures = "generated")',published[#published]=='generated')
 for _,name in ipairs({'slats','circuit','crust','veins','stream'})do
  local w,h,a=Belt.Pattern(name);local hex={}
  for i=0,w*h-1 do hex[#hex+1]=string.format('%02x',buffer.readu8(a,i))end
  print('ALPHA '..name..' '..w..' '..h..' '..table.concat(hex))
 end
end
do -- scroll: with the chevrons (3.0 studs/s training, 1.3 idle) x each layer's rate, wrapped at one tile; nothing when far / reduced / low quality
 local function offsets(level)local out={};for _,t in ipairs(textures(level))do out[t]=t.OffsetStudsV end;return out end
 local function travelled(a,b,expect)
  local ok=true
  for t,o in pairs(a)do
   local p=t.StudsPerTileV;local rate=t:GetAttribute('TreadmillScroll')
   local d=((b[t]-o)%p);local want=(expect*rate)%p
   if math.min(math.abs(d-want),p-math.abs(d-want))>.03 then ok=false;print('  scroll '..t.Name..' moved '..d..' want '..want)end
  end
  return ok
 end
 look(5,30);run(1.5)
 machines[5].Belt:SetAttribute('TrainingActive',true);run(.5)
 local a=offsets(5);run(2);local b=offsets(5)
 check('training: the belt textures travel 3.0 studs a second x their rate (2 s)',travelled(a,b,2*3.0*Look.Scroll.Sign))
 machines[5].Belt:SetAttribute('TrainingActive',false);run(.5)
 a=offsets(5);run(2);b=offsets(5)
 check('idle: the belt textures travel 1.3 studs a second x their rate (2 s)',travelled(a,b,2*1.3*Look.Scroll.Sign))
 local inRange=true;for t,o in pairs(b)do if o<0 or o>=t.StudsPerTileV then inRange=false end end
 check('the offsets stay within one tile',inRange)
 local function still(prep)prep();run(.6);local x=offsets(5);run(1);local y=offsets(5);for t,o in pairs(x)do if y[t]~=o then return false end end;return true end
 check('far away: the belt does not scroll',still(function()look(5,400)end))
 check('looking away: the belt does not scroll',still(function()look(5,40,true)end))
 check('Reduced Motion: the belt does not scroll',still(function()look(5,30);state.Reduced=true end))
 state.Reduced=false
 check('low quality: the belt does not scroll',still(function()state.Quality=1 end))
 check('FastMode: the belt does not scroll',still(function()state.Quality=3;state.Fast=true end))
 state.Fast=false
 -- edge flows: Beams with a moving texture, on near (quality 2+), stopped with Reduced Motion
 look(5,30);run(1)
 local beams={};for _,d in ipairs(machines[5].Art:GetDescendants())do if d.ClassName=='Beam'and d:GetAttribute('TreadmillDress151')then beams[#beams+1]=d end end
 local on=#beams==2;for _,b in ipairs(beams)do if not(b.Enabled and b.TextureSpeed>0)then on=false end end
 check('mid level: the two edge light flows are on near the camera and their texture moves (TextureSpeed)',on)
 state.Reduced=true;run(1);local stopped=true;for _,b in ipairs(beams)do if b.TextureSpeed~=0 then stopped=false end end
 check('Reduced Motion: the edge flows stand still',stopped);state.Reduced=false
 look(5,400);run(1);local off=true;for _,b in ipairs(beams)do if b.Enabled then off=false end end
 check('far away: the edge flows are off',off)
 -- lights and accent particles only near the camera
 local function enabled(level,cls)return count(machines[level].Art,function(d)return d.ClassName==cls and d.Enabled==true and d:GetAttribute('TreadmillDress151')end)end
 check('far away: no new light or particle is on',enabled(1,'PointLight')+enabled(1,'ParticleEmitter')==0)
 look(1,30);run(1.2)
 check('near: the entry glow and the accent motes come on (quality 3)',enabled(1,'PointLight')==1 and enabled(1,'ParticleEmitter')==2)
 state.Quality=1;run(.6);check('low quality / FastMode: they are off again',enabled(1,'PointLight')+enabled(1,'ParticleEmitter')==0);state.Quality=3
 -- only the orbiters are moved per frame: never a new part
 local dressMoved=false
 for p in pairs(moved)do local x=p;while x do if x.Name=='TreadmillDress151'then dressMoved=true end;x=x.Parent end end
 check('no dressing part is ever moved by script',not dressMoved)
end
do -- the label hides for its owner while he trains, and only for him
 local m=machines[3];local label=m.Art:FindFirstChild('StepLabel',true)
 look(3,30);run(1)
 m.Base:SetAttribute('BaseOwnerUserId',77)
 check('label shown while nobody trains',label.Enabled==true)
 m.Belt:SetAttribute('TrainingActive',true);run(.3)
 check('label hidden on the owner\'s screen while he trains',label.Enabled==false)
 m.Belt:SetAttribute('TrainingActive',false);run(.3)
 check('label back when he stops',label.Enabled==true)
 m.Base:SetAttribute('BaseOwnerUserId',88);m.Belt:SetAttribute('TrainingActive',true);run(.3)
 check('another player training there: the label stays for this player',label.Enabled==true)
 m.Base:SetAttribute('BaseOwnerUserId',77);run(.3);check('(and hides once it is this player\'s base)',label.Enabled==false)
 controller:Destroy()
 check('teardown: destroying the controller shows the label again and turns everything off',label.Enabled==true and count(m.Art,function(d)return(d.ClassName=='PointLight'or d.ClassName=='ParticleEmitter'or d.ClassName=='Beam')and d.Enabled==true end)==0)
 m.Belt:SetAttribute('TrainingActive',false)
end
do -- routes: uploaded ids win; no EditableImage -> the place's grid texture
 local function fresh(level)
  local base=newBase('Route');local _=build(base,level,level)
  local list={};for _,d in ipairs(base.TreadmillArtV131:GetDescendants())do if d.ClassName=='Texture'then list[#list+1]=d end end
  return base,list
 end
 Belt.Reset();published={}
 Look.Images.slats='rbxassetid://424242'
 local base,list=fresh(1)
 local route=Belt.Paint(list[1],Look,function(s)published[#published+1]=s end)
 check('an uploaded id in TreadmillLook151.Images wins (route "uploaded")',route=='uploaded'and list[1].Texture=='rbxassetid://424242'and list[1]:GetAttribute('BeltRoute')=='uploaded'and published[#published]=='uploaded')
 Look.Images.slats='';base:Destroy()
 Belt.Reset();published={}
 Belt.Hooks.Create=function()error('EditableImage budget')end
 base,list=fresh(4)
 for _,t in ipairs(list)do Belt.Paint(t,Look,function(s)published[#published+1]=s end)end
 local grid=true;for _,t in ipairs(list)do if not(t.Texture==Look.Grid and t:GetAttribute('BeltRoute')=='grid')then grid=false end end
 check('no EditableImage: every layer falls back to the place\'s grid texture '..Look.Grid..' (route "grid")',grid and published[#published]=='grid')
 base:Destroy()
 Belt.Reset();Belt.Hooks.Create=nil;Belt.Hooks.Content=nil
 base,list=fresh(1)
 Belt.Paint(list[1],Look)
 check('the real API path on a client without AssetService.CreateEditableImage (the mock) also falls back to the grid',list[1].Texture==Look.Grid and list[1]:GetAttribute('BeltRoute')=='grid')
 base:Destroy();Belt.Reset()
end

-- 4. The upgrade sign (GardenUpgradeService): next level, gains, price colour, MAX; never collides; the buttons are unchanged ---------------------------
do
 local player=R.new('Player');player.Name='Ben';player.UserId=1001;player.Parent=Players
 local cash=R.new('NumberValue');cash.Value=0
 local tread={Tier=1,Skin=1}
 local base=newBase('SignBase')
 local record={Index=1,Model=base}
 local svc={GardenUpgradeRecords={},BaseOwners={[1]=player},BusyChecker=function()return false end,Config=Config,GetPlayerBase=function()return record end,RefreshTreadmill=function()end,
  PlayerData={GetFenceTier=function()return 1 end,GetCash=function()return cash.Value end,GetTreadmillData=function()return tread end,GetOrCreateCashValue=function()return cash end,IsLoaded=function()return true end}}
 -- the buttons without the sign (TreadmillLook151 absent) and with it
 local saved=RS:FindFirstChild('TreadmillLook151');saved.Parent=nil
 Upgrade.Refresh(svc,player)
 local function snap()
  local m=base:FindFirstChild('GardenUpgradeButtons');local out={}
  for _,c in ipairs(m:GetChildren())do if c:IsA('BasePart')and not(c.Name:sub(1,5)=='Sign 'or c.Name=='Button rim glow')then
   local pr=c:FindFirstChild('UpgradePress');out[#out+1]=c.Name..'@'..tostring(c.CFrame.Position)..'|'..tostring(c.Size)..'|'..tostring(c.CanQuery)..(pr and('|'..pr.ActionText..'|'..pr.MaxActivationDistance..'|'..tostring(pr.KeyboardKeyCode))or'')
  end end
  table.sort(out);return table.concat(out,'\n')
 end
 local before=snap()
 check('without TreadmillLook151 there is no sign (the buttons as before)',count(base.GardenUpgradeButtons,function(d)return d.Name:sub(1,5)=='Sign 'end)==0)
 saved.Parent=RS
 local signParts
 for tier=1,7 do
  tread.Tier=tier;tread.Skin=tier;cash.Value=0
  Upgrade.Refresh(svc,player)
  local m=base.GardenUpgradeButtons
  local board=m:FindFirstChild('Sign board');local gui=board and board:FindFirstChild('UpgradeSign')
  local T=gui and{Title=gui.Title.Text,Levels=gui.Levels.Text,Gain=gui.Gain.Text,Price=gui.Price}
  signParts=0;local solid=false
  for _,c in ipairs(m:GetChildren())do if c:IsA('BasePart')and(c.Name:sub(1,5)=='Sign 'or c.Name=='Button rim glow')then signParts+=1;if c.CanCollide or c.CanQuery or c.CanTouch then solid=true end end end
  check(('tier %d: the sign is built (%d parts) and nothing of it collides, answers raycasts or touches'):format(tier,signParts),signParts==16 and not solid)
  if tier<7 then
   local nextCost=Config.TreadmillTiers[tier+1].Cost
   local want=EXPECT[tier]:gsub('/step','')..'  >  '..EXPECT[tier+1]
   check(('tier %d: "UPGRADE", "LV %d  >  LV %d", "%s", "$%s" in red (cannot afford)'):format(tier,tier,tier+1,want,Look.Format(nextCost)),T and T.Title=='UPGRADE'and T.Levels==('LV %d  >  LV %d'):format(tier,tier+1)
    and T.Gain==want and T.Price.Text=='$'..Look.Format(nextCost)and T.Price.Visible and rgb(T.Price.BackgroundColor3,200,66,65),T and(T.Levels..' / '..T.Gain..' / '..T.Price.Text))
   cash.Value=nextCost -- (the mock fires the Value changed signal: the service repaints)
   check(('tier %d: the price turns green when he can afford it'):format(tier),T and rgb(T.Price.BackgroundColor3,67,185,98))
  else
   check('tier 7: "MAX LEVEL" and its gain, no price',T and T.Title=='MAX LEVEL'and T.Gain==EXPECT[7]and T.Price.Visible==false)
  end
  check(('tier %d: the buttons, their places and prompts are unchanged by the sign'):format(tier),snap()==before)
 end
 Upgrade.Clear(svc,record)
 check('teardown: GardenUpgradeService.Clear removes the sign with the buttons',base:FindFirstChild('GardenUpgradeButtons')==nil)
end

-- 5. Teardown and rebuilds ------------------------------------------------------------------------------------------------------------------------
do
 local base=newBase('Rebuild')
 local belt1=build(base,3,3);local art1=base.TreadmillArtV131
 local belt2=build(base,7,7)
 local arts,dresses=0,0
 for _,c in ipairs(base:GetChildren())do if c.Name=='TreadmillArtV131'then arts+=1 end end
 dresses=count(base,function(d)return d.Name=='TreadmillDress151'end)
 check('an upgrade rebuild keeps the same belt and leaves one machine with one dressing',belt1==belt2 and arts==1 and dresses==1 and art1.Parent==nil)
 check('the old machine\'s textures and label left with it',count(base,function(d)return d.ClassName=='Texture'end)==3 and count(base,function(d)return d.Name=='StepLabel'end)==1)
 local belt3=build(base,1)
 check('releasing the base (tier 1) shows level 1: +20/step, one texture layer',base.TreadmillArtV131.TreadmillDress151:GetAttribute('StepLabel')=='+20/step'and count(base,function(d)return d.ClassName=='Texture'end)==1 and belt3==belt1)
 Art.TreadmillLook={BiomeOf=function()error('broken look')end,GradeOf=function()return'low'end}
 local warns=W.warns or 0
 Art.BuildTreadmillV131(base,2)
 check('a failing dressing pass leaves the machine exactly as before R151 (and warns once)',base.TreadmillArtV131:FindFirstChild('TreadmillDress151')==nil
  and count(base.TreadmillArtV131,function(d)return d.ClassName=='Texture'or d:GetAttribute('TreadmillDress151')end)==0 and(W.warns or 0)==warns+1)
 Art.TreadmillLook=nil
end

print(('R151 treadmills: %d passed, %d failed'):format(passed,failed))
if failed>0 then error('FAILED')end
