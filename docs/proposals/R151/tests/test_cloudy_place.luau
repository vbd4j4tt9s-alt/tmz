--!nocheck
-- R151 Cloudy sky, part 4: the lanterns on the OWNER'S PLACE (place_tree.luau from docs/proposals/R149/tools/rbxl_geom.py) in the R149 Roblox mock, after the
-- real start-up builders: the real MapService.new (MarketLayout with its tagged warm lights, HubDecor151), the real HubLife151.client + HubLifeArt151
-- (R154 tidy: 12 lamps with 16 heads, 8 of them with real lights, 14 wall lanterns) and the real sky state. Which lamps and lanterns light up, tier by tier, and that the market's warm
-- lights are found by their tag.
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return{}end
function Players.GetPlayerByUserId()return nil end;function Players.GetUserThumbnailAsync()return'',true end
local Http=W.service('HttpService');local guid=0;function Http.GenerateGUID()guid+=1;return'guid-'..guid end;function Http.JSONEncode(_,t)return'{}'end;function Http.JSONDecode()return{}end
local DS=W.service('DataStoreService');function DS.GetDataStore()return{GetAsync=function()return nil end,SetAsync=function()end,UpdateAsync=function()return nil end}end;DS.GetOrderedDataStore=DS.GetDataStore
local MS=W.service('MarketplaceService');MS.PromptProductPurchaseFinished=R.signal();MS.PromptGamePassPurchaseFinished=R.signal()
W.env.bit32=bit32
do local Inst=R.Inst;local raw=Inst.IsA
 function Inst:IsA(c)if self._class=='SpawnLocation'and(c=='Part'or c=='BasePart'or c=='PVInstance'or c=='FormFactorPart')then return true end;return raw(self,c)end
end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='BindableEvent'then o.Event=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local map=Z.loadPlace(require('./place_tree'),W.workspace)
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
if not RS:FindFirstChild('RunnerMotion')then local m=R.new('ModuleScript');m.Name='RunnerMotion';m.Parent=RS end
if not RS:FindFirstChild('R142Keycap')then
 local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55)
 local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
 local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=RS
end
local passed,failed=0,0
local function check(name,cond,why)
 if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end
end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local Config=server('Config')
server('MapService').new(Config);R.advance(.1)
R.advance(1)
local dec=map:FindFirstChild('HubDecor151')
check('server: MapService.new builds the festival square (HubDecor151)',dec~=nil)
if not dec then error('no HubDecor151')end
local Cycle=W.module('WeatherCycle151')
local function warmth(c)return c.B/math.max(c.R,1e-6)end

-- 1. the market's tagged lights, found on the real market ------------------------------------------------------------------------------------
local tagged=W.CS:GetTagged(Cycle.Market.Tag)
local lights,heads,names={},{},{}
for _,o in ipairs(tagged)do if o:IsA('Light')then lights[#lights+1]=o;names[#names+1]=o.Name..'@'..tostring(o.Parent.Name)elseif o:IsA('BasePart')then heads[#heads+1]=o end end
table.sort(names)
check('market: 6 warm lights are tagged WarmLight151 (2 porch lanterns, 3 ceiling lantern lights, the Fruit of the Hour light)',#lights==6,#lights..' '..table.concat(names,', '))
local porch,ceiling,fruit=0,0,0
for _,l in ipairs(lights)do local pn=l.Parent.Name;if pn=='Warm lantern'then porch+=1 elseif pn=='Lantern light'then ceiling+=1 elseif l.Name=='FruitLight'then fruit+=1 end end
check('market: ... 2 porch + 3 ceiling + 1 fruit pedestal',porch==2 and ceiling==3 and fruit==1,porch..'/'..ceiling..'/'..fruit)
check('market: the 2 porch lantern heads (neon) are tagged too',#heads==2 and heads[1].Material==R.Enum.Material.Neon and heads[1].Name=='Warm lantern',#heads)
local inMarket=true;for _,o in ipairs(tagged)do if not o:IsDescendantOf(map.EconomyHub)then inMarket=false end end
check('market: all of them stand inside the hub',inMarket)
local lampsOn=0;for _,l in ipairs(lights)do if l.Enabled then lampsOn+=1 end end
check('market: they are on already (always lit, as before)',lampsOn==6)

-- 2. client: the lamps on the real decor ------------------------------------------------------------------------------------------------------
Run.IsClient=function()return true end;Run.IsServer=function()return false end
local player=R.new('Player');player.Name='Tester';player.UserId=1001;player.Parent=Players;Players.LocalPlayer=player
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
local function sky(kind,since,fade,from)RS:SetAttribute(Cycle.Attribute,Cycle.Pack(kind,since,fade,from or(kind=='Cloudy'and 0 or 1),since+360))end
local function lit(ctx)local n=0;for _,l in ipairs(ctx.Lights)do if l.Enabled then n+=1 end end;return n end
local function load()
 local sc=R.new('LocalScript');sc.Name='HubLife151';sc:SetAttribute('R151TestHook',true);sc.Parent=pg
 local api=W.load('HubLife151Client',sc);api.Tick(.5);return api,sc
end
local before={};for _,l in ipairs(lights)do before[l]={B=l.Brightness,R=l.Range,C=l.Color}end
local beforeHead={};for _,h in ipairs(heads)do beforeHead[h]=h.Color end
RS:SetAttribute('GlobalWeather','Clear')
for _,tier in ipairs({3,2,1})do
 budget.Tier=tier;sky('Clear',R.clock-300,30,1)
 local api,sc=load();local ctx=api.State.Ctx
 check('tier '..tier..': the square builds with 12 lamps (16 neon heads), 8 lit lamps'..(tier>=2 and' and 14 wall lanterns'or''),ctx~=nil and #ctx.Heads==16 and #ctx.Lights==8 and #ctx.Lanterns==(tier>=2 and 14 or 0),ctx and(#ctx.Heads..'/'..#ctx.Lights..'/'..#ctx.Lanterns))
 local base={};for _,p in ipairs(ctx.Heads)do base[p]=p.Color end;for _,p in ipairs(ctx.Lanterns)do base[p]=p.Color end
 check('tier '..tier..': Clear: no light on, every colour its own',lit(ctx)==0)
 sky('Cloudy',R.clock-300,30,0);api.Tick(.5);R.advance(.5);api.Tick(.5)
 local want=Cycle.RealLights(tier)
 check('tier '..tier..': Cloudy: '..want..' of the 8 lamp lights on (the tier\'s cap)',lit(ctx)==want,lit(ctx))
 local warmer=0;local total=0
 for p,c in pairs(base)do total+=1;if warmth(p.Color)<warmth(c)-.05 then warmer+=1 end end
 check('tier '..tier..': all '..total..' lamp heads and wall lanterns glow warm',warmer==total and total==16+(tier>=2 and 14 or 0),warmer..'/'..total)
 -- which lamps
 if tier==2 then
  local pos={};for i,l in ipairs(ctx.Lights)do if l.Enabled then pos[#pos+1]=string.format('(%.0f,%.0f)',ctx.LightAt[l][1],ctx.LightAt[l][2])end end
  print('  phone lamps with a real light: '..table.concat(pos,' '))
 end
 -- the market, boosted
 local boosted=0;for _,l in ipairs(lights)do if l.Brightness>before[l].B*1.5 and l.Range>before[l].R*1.2 and warmth(l.Color)<warmth(before[l].C)-.01 then boosted+=1 end end
 check('tier '..tier..': the market\'s 6 warm lights are stronger and warmer',boosted==6,boosted)
 local headsWarm=0;for _,h in ipairs(heads)do if warmth(h.Color)<warmth(beforeHead[h])-.01 then headsWarm+=1 end end
 check('tier '..tier..': and the 2 porch lantern heads warmer',headsWarm==2)
 -- Clear again, exactly
 sky('Clear',R.clock,30,1);for i=1,100 do R.advance(.5);api.Tick(.5)end
 local exact=lit(ctx)==0;for p,c in pairs(base)do if p.Color.R~=c.R or p.Color.G~=c.G or p.Color.B~=c.B then exact=false end end
 for _,l in ipairs(lights)do local b=before[l];if l.Brightness~=b.B or l.Range~=b.R or l.Color.G~=b.C.G then exact=false end end
 check('tier '..tier..': Clear again: every colour, light and market value exactly as before',exact)
 sc.Destroying:Fire()
end
budget.Tier=3
-- the dark rule on the real square: The Darkened, Rain, Thunderstorm light all 8 on every tier
do
 local Env=W.module('EnvironmentLighting')
 for _,tier in ipairs({3,2,1})do
  budget.Tier=tier;sky('Clear',R.clock-300,30,1);local api,sc=load();local ctx=api.State.Ctx
  Env.Level=1;api.ApplyLamps();local d1=lit(ctx);Env.Level=0;api.ApplyLamps()
  RS:SetAttribute('GlobalWeather','Rain');api.ApplyLamps();local d2=lit(ctx);RS:SetAttribute('GlobalWeather','Thunderstorm');api.ApplyLamps();local d3=lit(ctx)
  RS:SetAttribute('GlobalWeather','Blizzard');api.ApplyLamps();local d4=lit(ctx);RS:SetAttribute('GlobalWeather','Clear');api.ApplyLamps()
  check('tier '..tier..': the dark keeps the R151 rule (Darkened '..d1..', Rain '..d2..', Thunderstorm '..d3..' of 8; Blizzard '..d4..')',d1==8 and d2==8 and d3==8 and d4==0)
  sc.Destroying:Fire()
 end
end
print(('R151 Cloudy lanterns on the owner\'s place: %d passed, %d failed'):format(passed,failed))
if failed>0 then error('FAILED')end
