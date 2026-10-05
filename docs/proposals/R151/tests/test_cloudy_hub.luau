--!nocheck
-- R151 Cloudy sky, part 3: the lanterns. "make the other default weather cloudy where it just dims the lighting so that the lanterns around the map can
-- create a warm ambience." The REAL HubLife151.client + HubLifeArt151 (the festival square's 26 lamps with 30 neon heads, 8 of them with a real PointLight,
-- and 14 wall lanterns) and the market's tagged warm lights on the Roblox mock:
--  * Clear: nothing changes (lights off, heads and lanterns in their own colours);
--  * Cloudy: the lamp heads and wall lanterns warm up at every tier, the real lights fade in within the device tier's cap (8 desktop / 4 phone / 0 FastMode),
--    the market's lights strengthen; the fade is a handful of steps from the half-second tick (nothing per frame, nothing once settled);
--  * the dark (The Darkened, Rain, Thunderstorm) keeps its R151 rule exactly (all 8 lights, every tier); a Blizzard does not light them; event weather
--    suppresses the Cloudy part and the lamps return to it afterwards;
--  * Reduced Motion, FastMode, a late joiner, damaged state, streaming, teardown.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local C3=R.Color3.fromRGB
local floor,abs,max,min=math.floor,math.abs,math.max,math.min
local RS=W.RS;local Run=W.Run
local Cycle=W.module('WeatherCycle151');local K=W.module('HubDecorKit151');local Env=W.module('EnvironmentLighting')
Run.IsClient=function()return true end;Run.IsServer=function()return false end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=1001;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return{player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play(s)s._props.IsPlaying=true end;function R.Inst.Stop(s)s._props.IsPlaying=false end;function R.Inst.Pause(s)s._props.IsPlaying=false end
W.service('ContentProvider').PreloadAsync=function()end
local budget={Tier=3};W.stub('ClientFxBudget',{Get=function()return budget.Tier end,Low=function()return budget.Tier==1 end})
local model=R.new('Model');model.Name='Tester'
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.Transparency=1;hrp.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=model;model.PrimaryPart=hrp;model.Parent=W.workspace;player.Character=model
hrp.CFrame=CF(0,7,-200);W.workspace.CurrentCamera.CFrame=CF(0,12,-230)
-- the server's folder: a bare HubDecor151 (the client builds the life layer from its own art)
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local dec=R.new('Folder');dec.Name=K.FolderName;dec.Parent=map
local function load()
 local sc=R.new('LocalScript');sc.Name='HubLife151';sc:SetAttribute('R151TestHook',true);sc.Parent=pg
 local api=W.load('HubLife151Client',sc)
 api.Tick(.5) -- the first tick builds the square (as it does in the game)
 return api,sc
end
local function unload(sc)sc.Destroying:Fire()end
local function frames(sec)W.frames(floor(sec*60+.5),1/60)end
-- the server's sky state, as WeatherService publishes it
local function sky(kind,since,fade,from)RS:SetAttribute(Cycle.Attribute,Cycle.Pack(kind,since,fade,from or(kind=='Cloudy'and 0 or 1),since+360))end
local function clearSky()RS:SetAttribute(Cycle.Attribute,nil)RS:SetAttribute('GlobalWeather','Clear')end
-- writes to anything the lamp code owns
local counters={}
local function watch(list,label)local n={count=0};counters[label]=n;for _,o in ipairs(list)do o.Changed:Connect(function(k)if k~='Parent'then n.count+=1 end end)end;return n end
local function brightLights(ctx)local n=0;for _,l in ipairs(ctx.Lights)do if l.Enabled then n+=1 end end;return n end
local function warmth(c)return c.B/max(c.R,1e-6)end -- (a warmer colour has less blue against red)

-- ======================================================================================================================
print('-- structure')
local api,apiScript=load()
local ctx=api.State.Ctx
check(ctx~=nil and W.workspace:FindFirstChild('HubLife151')~=nil,'the festival square builds (tier 3)')
check(#ctx.Lights==8,'8 lit lamps carry a real PointLight (the R151 cap): '..#ctx.Lights)
check(#ctx.Heads==30,'30 lamp heads in all (18 posts, 4 doubles x 2, 4 bollards): '..#ctx.Heads)
check(#ctx.Lanterns==14,'14 wall lanterns (tier >= 2): '..#ctx.Lanterns)
do
 local allNeon,allLit=true,true
 for _,h in ipairs(ctx.Heads)do if h.Material~=R.Enum.Material.Neon then allNeon=false end end
 for _,h in ipairs(ctx.Lanterns)do if h.Material~=R.Enum.Material.Neon then allNeon=false end end
 check(allNeon,'every lamp head and wall lantern is neon: it glows at every tier whatever the lights do')
 -- priority order: mirror pairs side by side
 local mirrored=true
 for i=1,#ctx.Lights,2 do
  local a,b=ctx.LightAt[ctx.Lights[i]],ctx.LightAt[ctx.Lights[i+1]]
  if not(a and b and near(a[1],-b[1],.01)and near(a[2],b[2],.01))then mirrored=false end
 end
 check(mirrored,'the real lights are ordered in mirror pairs (x, -x at the same z): any even cap keeps the square symmetric')
end
-- the colours the art gives them (HubLifeArt151): a Clear sky must leave exactly these
local HEAD,LANTERN=C3(255,222,150),C3(255,214,140)
local function sameColor(a,b)return a.R==b.R and a.G==b.G and a.B==b.B end
do
 local ok=true;for _,p in ipairs(ctx.Heads)do if not sameColor(p.Color,HEAD)then ok=false end end;for _,p in ipairs(ctx.Lanterns)do if not sameColor(p.Color,LANTERN)then ok=false end end
 check(ok,'(the heads are the art\'s amber (255,222,150), the wall lanterns (255,214,140), before any sky)')
end
local lampBase={};for _,l in ipairs(ctx.Lights)do lampBase[l]=l.Brightness end
local colorBase={};for _,p in ipairs(ctx.Heads)do colorBase[p]=p.Color end;for _,p in ipairs(ctx.Lanterns)do colorBase[p]=p.Color end
local function allBase()for p,c in pairs(colorBase)do if p.Color.R~=c.R or p.Color.G~=c.G or p.Color.B~=c.B then return false end end;return true end
local function atBrightness(ctx,f,base)for _,l in ipairs(ctx.Lights)do if not near(l.Brightness,base[l]*f,1e-6)then return false end end;return true end

print('-- Clear')
clearSky();api.ApplyLamps(true)
check(brightLights(ctx)==0 and allBase(),'a Clear sky: every light off, every head and lantern in its own colour (as before R151)')
sky('Clear',R.clock-500,30,1);api.ApplyLamps()
check(brightLights(ctx)==0 and allBase(),'... also with a Clear state from the server')
RS:SetAttribute(Cycle.Attribute,'garbage');api.ApplyLamps()
check(brightLights(ctx)==0 and allBase(),'a damaged state reads as Clear (nothing lights, no error)')
RS:SetAttribute(Cycle.Attribute,nil)
unload(apiScript)

print('-- Cloudy at every tier')
for _,tier in ipairs({3,2,1})do
 budget.Tier=tier;local a,sc=load()
 local c=a.State.Ctx
 local base={};for _,l in ipairs(c.Lights)do base[l]=l.Brightness end
 local colors={};for _,p in ipairs(c.Heads)do colors[p]=p.Color end;for _,p in ipairs(c.Lanterns)do colors[p]=p.Color end
 sky('Cloudy',R.clock-300,30,0);a.ApplyLamps()
 local want=Cycle.RealLights(tier)
 check(brightLights(c)==want,('tier %d: %d real lights on (the cap is %d)'):format(tier,brightLights(c),want))
 local ok=true;for i,l in ipairs(c.Lights)do if(i<=want)~=l.Enabled then ok=false end;if l.Enabled and not near(l.Brightness,base[l]*Cycle.Lamps.Light,1e-6)then ok=false end end
 check(ok,'... the first '..want..' of the priority order, at their full brightness')
 if want>0 and want%2==0 then
  local sum=0;for i=1,want do sum+=c.LightAt[c.Lights[i]][1]end
  check(near(sum,0,.01),'... a mirror-symmetric set (x sums to 0)')
 end
 local warmer,all=0,0
 for p,c0 in pairs(colors)do all+=1;local now=p.Color;if warmth(now)<warmth(c0)-.05 and now.G<c0.G and near(now.R,c0.R,.02)then warmer+=1 end end
 check(warmer==all and all==#c.Heads+#c.Lanterns,('tier %d: all %d lamp heads and wall lanterns glow warmer (neon, free)'):format(tier,all))
 check(tier>=2 and #c.Lanterns==14 or tier==1 and #c.Lanterns==0,'(wall lanterns are built from tier 2 up: '..#c.Lanterns..')')
 -- all heads end at one share of the warm colour
 local sample=c.Heads[1].Color;local expectShare=Cycle.Lamps.WarmShare
 local b0=colors[c.Heads[1]];local w=Cycle.Lamps.Warm
 check(near(sample.G,b0.G+(w.G-b0.G)*expectShare,.01)and near(sample.B,b0.B+(w.B-b0.B)*expectShare,.01),'... by the configured share of the warm colour')
 -- back to Clear: exact (against the art's own colours, not a snapshot)
 sky('Clear',R.clock-300,30,1);a.ApplyLamps()
 local exact=brightLights(c)==0
 for _,p in ipairs(c.Heads)do if not sameColor(p.Color,HEAD)then exact=false end end
 for _,p in ipairs(c.Lanterns)do if not sameColor(p.Color,LANTERN)then exact=false end end
 check(exact,'tier '..tier..': Clear again gives every colour back exactly and switches the lights off')
 unload(sc)
end
budget.Tier=3

print('-- the fade')
do
 local a,sc=load();local c=a.State.Ctx
 local cb={};for _,p in ipairs(c.Heads)do cb[p]=p.Color end
 local lightWrites=watch(c.Lights,'lights');local headWrites=watch(c.Heads,'heads');local lantWrites=watch(c.Lanterns,'lanterns')
 local base={};for _,l in ipairs(c.Lights)do base[l]=l.Brightness end
 local t0=R.clock+.5;sky('Cloudy',t0,30,0)
 -- the half-second tick, 60 s: 30 s of fade, 30 s settled
 local firstOn,lastBright,mono=nil,0,true;local maxStep=0
 local heads1,distinct={},{}
 local settledAt=nil
 for i=1,120 do
  R.advance(.5);a.Tick(.5)
  local t=R.clock-t0
  local b=c.Lights[1].Brightness;if c.Lights[1].Enabled then if b<lastBright-1e-9 then mono=false end;maxStep=max(maxStep,b-lastBright);lastBright=b;firstOn=firstOn or t end
  distinct[string.format('%.3f',c.Heads[1].Color.G)]=true
 end
 local level=Cycle.Read(RS,R.clock)
 check(level==1,'(the sky is fully cloudy after 60 s)')
 check(firstOn and firstOn>=30*.1 and firstOn<=30*.55,('the lights start when the dimming is well under way (after %.1f s of the 30 s fade)'):format(firstOn or -1))
 check(mono,'a light only ever gets brighter during the fade')
 check(maxStep<=base[c.Lights[1]]/Cycle.Lamps.Steps*1.01+1e-9,('in steps of 1/%d of the full brightness (biggest %.3f of %.2f)'):format(Cycle.Lamps.Steps,maxStep,base[c.Lights[1]]))
 check(brightLights(c)==8 and atBrightness(c,Cycle.Lamps.Light,base),'fully cloudy: 8 lights at full brightness')
 local steps=Cycle.Lamps.HeadSteps[3]
 local count=0;for _ in pairs(distinct)do count+=1 end
 check(count<=steps+1,('the head colour is written in %d steps (at most %d + the start)'):format(count-1,steps))
 check(lightWrites.count<=#c.Lights*(Cycle.Lamps.Steps+1)*2,('%d writes to the lamps\' lights over a 30 s fade (<= %d: Enabled once, Brightness a step at a time)'):format(lightWrites.count,#c.Lights*(Cycle.Lamps.Steps+1)*2))
 check(headWrites.count<=#c.Heads*(steps+1)and lantWrites.count<=#c.Lanterns*(steps+1),('%d head and %d lantern colour writes (each part %d times at most)'):format(headWrites.count,lantWrites.count,steps+1))
 -- once settled: no work at all (no write, and not even a pass over the 44 heads: reading the warm colour is what that pass does)
 local before=lightWrites.count+headWrites.count+lantWrites.count
 local realLamps=Cycle.Lamps;local reads={}
 Cycle.Lamps=setmetatable({},{__index=function(_,k)reads[k]=(reads[k]or 0)+1;return realLamps[k]end})
 for i=1,240 do R.advance(.5);a.Tick(.5)end
 local passes=reads.Warm or 0;Cycle.Lamps=realLamps
 check(passes==0,'settled: 240 ticks make no pass over the heads and lanterns ('..passes..' warm-colour reads)')
 check(lightWrites.count+headWrites.count+lantWrites.count==before,'settled: 2 minutes of ticks write nothing')
 -- between ticks nothing runs: mid-fade, the 29 heartbeats inside a half second change nothing
 sky('Clear',R.clock,30,1)
 for i=1,12 do R.advance(.5);a.Tick(.5)end
 local mid=lightWrites.count+headWrites.count+lantWrites.count
 local conn=#Run.RenderStepped._c
 for i=1,29 do R.advance(1/60);Run.Heartbeat:Fire(1/60)end
 check(lightWrites.count+headWrites.count+lantWrites.count==mid,'no per-frame work: the 29 frames between two ticks write nothing, mid-fade')
 -- lights and colours return exactly
 for i=1,100 do R.advance(.5);a.Tick(.5)end
 check(brightLights(c)==0 and atBrightness(c,1,base),'faded back to Clear: lights off, brightness back to the base value')
 local exact=true;for _,p in ipairs(c.Heads)do if not sameColor(p.Color,HEAD)then exact=false end end
 for _,p in ipairs(c.Lanterns)do if not sameColor(p.Color,LANTERN)then exact=false end end
 check(exact,'... and every head and lantern is exactly the art\'s colour again')
 unload(sc)
end

print('-- the dark keeps its rule')
do
 budget.Tier=1;local a,sc1=load();local c=a.State.Ctx
 local base={};for _,l in ipairs(c.Lights)do base[l]=l.Brightness end
 clearSky();a.ApplyLamps(true)
 Env.Level=1;a.ApplyLamps()
 check(brightLights(c)==8 and atBrightness(c,1,base),'The Darkened at tier 1 (FastMode): all 8 lights on at the R151 brightness, as before')
 Env.Level=0;a.ApplyLamps();check(brightLights(c)==0,'... off when the lights come back')
 for _,t in ipairs({3,2,1})do
  budget.Tier=t;local b,scb=load();local d=b.State.Ctx
  for _,weather in ipairs({'Rain','Thunderstorm'})do
   RS:SetAttribute('GlobalWeather',weather);sky('Clear',R.clock-300,30,1);b.ApplyLamps()
   check(brightLights(d)==8,('tier %d, %s: all 8 lights, as before'):format(t,weather))
  end
  RS:SetAttribute('GlobalWeather','Clear');unload(scb)
 end
 unload(sc1);budget.Tier=3
 -- Rain over a cloudy sky: the dark's rule (all 8), the heads leave Cloudy; the rain ends: Cloudy again
 budget.Tier=2;local b,scb=load();local d=b.State.Ctx
 local baseHead={};for _,p in ipairs(d.Heads)do baseHead[p]=p.Color end
 sky('Cloudy',R.clock-300,30,0);b.ApplyLamps()
 local cloudyLights=brightLights(d)
 check(cloudyLights==4,'(phone, cloudy: 4 lights)')
 local warmNow={};for _,p in ipairs(d.Heads)do warmNow[p]=p.Color end
 RS:SetAttribute('GlobalWeather','Rain');b.ApplyLamps()
 local allWarmOff=true;for _,p in ipairs(d.Heads)do if p.Color.R==baseHead[p].R and p.Color.G==baseHead[p].G then else allWarmOff=false end end
 check(brightLights(d)==8 and allWarmOff,'Rain over a Cloudy sky: the storm rule (8 lights, phone too) and the heads back to their own colour (no Cloudy under an event)')
 RS:SetAttribute('GlobalWeather','Blizzard');b.ApplyLamps()
 check(brightLights(d)==0,'a Blizzard does not light the lamps (as before), Cloudy or not')
 RS:SetAttribute('GlobalWeather','Clear');b.ApplyLamps()
 local back=brightLights(d)==4;for _,p in ipairs(d.Heads)do if not near(p.Color.G,warmNow[p].G,1e-9)then back=false end end
 check(back,'the event ends: the lamps are exactly as Cloudy had them (4 lights, warm heads)')
 -- The Darkened's blackout while cloudy
 Env.Level=1;b.ApplyLamps()
 check(brightLights(d)==8,'The Darkened while cloudy: all 8')
 Env.Level=0;b.ApplyLamps()
 check(brightLights(d)==4,'... and Cloudy\'s 4 afterwards')
 unload(scb)
end

print('-- Reduced Motion, FastMode, a late joiner')
do
 budget.Tier=3;clearSky();local a,sca=load();local c=a.State.Ctx
 local cb={};for _,p in ipairs(c.Heads)do cb[p]=p.Color end
 W.Gui.ReducedMotionEnabled=true
 sky('Cloudy',R.clock-300,30,0);for i=1,4 do R.advance(.5);a.Tick(.5)end
 check(brightLights(c)==8,'Reduced Motion: the lamps light as usual (a slow dim is not motion)')
 local on=0;for _,pe in ipairs(c.Emitters)do if pe.Enabled then on+=1 end end
 check(on==0,'Reduced Motion: still no particles (unchanged)')
 W.Gui.ReducedMotionEnabled=false
 player:SetAttribute('FastMode',true);for i=1,4 do R.advance(.5);a.Tick(.5)end
 check(brightLights(c)==0,'FastMode (tier 1): no real lights (a few lamps cost real GPU time on weak devices)')
 local warm=true;for _,p in ipairs(c.Heads)do if not(warmth(p.Color)<warmth(cb[p])-.05)then warm=false end end
 check(warm,'... every head still glows warm')
 player:SetAttribute('FastMode',nil);for i=1,4 do R.advance(.5);a.Tick(.5)end
 check(brightLights(c)==8,'FastMode off: back to the desktop cap')
 -- a late joiner: the first tick already shows the right state
 unload(sca)
 local b,scb=load();local d=b.State.Ctx
 check(brightLights(d)==8,'a player who joins in a Cloudy phase sees the lit square on the first frame')
 -- mid-fade join
 unload(scb);clearSky();sky('Cloudy',R.clock-18,30,0);b,scb=load();d=b.State.Ctx
 local lvl=Cycle.LampStrength(Cycle.Read(RS,R.clock))
 check(lvl>0 and lvl<1 and brightLights(d)==8 and near(d.Lights[1].Brightness,Cycle.Quant(lvl,Cycle.Lamps.Steps)*1.4,1e-6),'a mid-fade join starts at the fade\'s level')
 unload(scb)
end

print('-- the market\'s warm lights')
do
 clearSky()
 local a,sca=load()
 local tag=Cycle.Market.Tag
 check(tag=='WarmLight151'and W.B.MarketLayout:find("local WARM_TAG='"..tag.."'",1,true)~=nil,'the server tags the market\'s lights with the name the client reads ('..tag..')')
 local function mk(brightness,range,color)local part=R.new('Part');part.Name='Warm lantern';part.CFrame=CF(0,8,-275);part.Color=C3(255,207,123);part.Material=R.Enum.Material.Neon;part.Parent=W.workspace
  local l=R.new('PointLight');l.Brightness=brightness;l.Range=range;l.Color=color;l.Parent=part;return part,l end
 local part,light=mk(.55,10,C3(255,213,146))
 local holder,ceiling=mk(.9,18,C3(255,214,160))
 W.CS:AddTag(light,tag);W.CS:AddTag(part,tag);W.CS:AddTag(ceiling,tag)
 -- (streamed in after the script started: picked up by the tag signal)
 sky('Cloudy',R.clock-300,30,0);for i=1,3 do R.advance(.5);a.Tick(.5)end
 local M=Cycle.Market
 check(near(light.Brightness,.55*(1+M.Brightness),1e-6)and near(light.Range,10*(1+M.Range),1e-6)and near(ceiling.Brightness,.9*(1+M.Brightness),1e-6),('under Cloudy the market lights strengthen: Brightness %.2f (was .55), Range %.1f (was 10)'):format(light.Brightness,light.Range))
 check(warmth(light.Color)<warmth(C3(255,213,146))-.01 and warmth(part.Color)<warmth(C3(255,207,123))-.01,'... and warm up (the light and the neon head)')
 check(part.Material==R.Enum.Material.Neon and light.Enabled==true,'(still neon, still on)')
 -- a Blizzard / Rain: not applied (the event takes priority)
 RS:SetAttribute('GlobalWeather','Rain');for i=1,3 do R.advance(.5);a.Tick(.5)end
 check(near(light.Brightness,.55,1e-6)and near(light.Range,10,1e-6),'an event weather: the market lights are as they always were')
 RS:SetAttribute('GlobalWeather','Clear');for i=1,3 do R.advance(.5);a.Tick(.5)end
 check(light.Brightness>.55*1.5,'... and strengthen again when it clears')
 sky('Clear',R.clock,30,1);for i=1,100 do R.advance(.5);a.Tick(.5)end
 check(near(light.Brightness,.55,1e-9)and near(light.Range,10,1e-9)and light.Color.G==213/255 and part.Color.G==207/255,'Clear: exactly the original values')
 local writes=watch({light,part,ceiling},'market')
 for i=1,100 do R.advance(.5);a.Tick(.5)end
 check(writes.count==0,'a clear sky costs the market lights no writes')
 -- the lights stand even when the festival square is not built (tick before the decor exists)
 a.Teardown();dec.Parent=nil
 sky('Cloudy',R.clock-300,30,0);for i=1,3 do R.advance(.5);a.Tick(.5)end
 check(light.Brightness>.55*1.5,'the market lights follow the sky even without the HubLife square (their own script path)')
 dec.Parent=map
 -- a removed tag is forgotten
 W.CS:RemoveTag(light,tag);sky('Clear',R.clock,30,1);for i=1,100 do R.advance(.5);a.Tick(.5)end
 check(light.Brightness>.55*1.5,'an untagged light is left alone')
 unload(sca)
end

print('-- teardown and wiring')
do
 local before=#Run.Heartbeat._c
 local live=0;for _,c in ipairs(Run.Heartbeat._c)do if c.Connected then live+=1 end end
 local a,sc=load();local mid=0;for _,c in ipairs(Run.Heartbeat._c)do if c.Connected then mid+=1 end end
 check(mid==live+1,'HubLife adds exactly one Heartbeat connection (the half-second tick drives every lamp step)')
 local rs0=0;for _,c in ipairs(Run.RenderStepped._c)do if c.Connected then rs0+=1 end end
 sky('Cloudy',R.clock-10,30,0);for i=1,10 do R.advance(.5);a.Tick(.5)end
 local rs1=0;for _,c in ipairs(Run.RenderStepped._c)do if c.Connected then rs1+=1 end end
 check(rs1==rs0,'Cloudy binds nothing to RenderStepped (no per-frame lamp work)')
 sc.Destroying:Fire();local after=0;for _,c in ipairs(Run.Heartbeat._c)do if c.Connected then after+=1 end end
 check(after==live,'destroying the script disconnects its tick and the tag listeners')
 check(W.B.HubLife151Client:find('RenderStepped')~=nil and W.B.HubLife151Client:find('applyLamps',1,true)~=nil,'(the ambience still has its own RenderStepped; the lamp code is in the tick)')
 local lampSection=W.B.HubLife151Client:sub(W.B.HubLife151Client:find('Lamps in the dark and under clouds',1,true),W.B.HubLife151Client:find('Gate keys:',1,true))
 check(lampSection:find('RenderStepped')==nil and lampSection:find('Heartbeat')==nil,'the lamp section itself binds no per-frame event')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
