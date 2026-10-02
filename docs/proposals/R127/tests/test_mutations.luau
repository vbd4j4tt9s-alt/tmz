--!nocheck
-- R127: weather mutation highlights, end to end through the real WeatherService -> WeatherAdopted -> MutationHighlights,
-- plus the notice copy that names the plant (NoticeCopy83 + MutationGlow127).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- Real HSV so the rainbow can be measured (the shared mock returns white).
R.Color3.fromHSV=function(h,s,v)
 local i=math.floor(h*6);local f=h*6-i;local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s);i%=6
 local r,g,b=({v,q,p,p,t,v})[i+1],({t,v,v,q,p,p})[i+1],({p,p,t,v,v,q})[i+1];return R.Color3.new(r,g,b)
end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
function Players.GetPlayers()return {me}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local Traits=W.module('WeatherTraits');local Glow=W.module('MutationGlow127');local Copy=W.module('NoticeCopy83')
local Rules=W.module('PlantRules');local Catalog=W.module('PlantCatalog')
Traits.PackChance=1;Traits.PlantChance=1;Traits.FruitChance=1 -- force every roll so the paths run deterministically
-- World: a Forest pack slot and my garden plot with one Watermelon.
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local slot=R.new('Model');slot.Name='Pack_F1';slot.Parent=map
local packet=R.new('Model');packet.Name='SeedPacket';packet.Parent=slot
local body=R.new('Part');body.Name='Body';body.Parent=packet
local seed={Available=true,Model=slot,Stage=1,Generation=1,PackSize=1,Weather='None'}
local plot=R.new('Part');plot.Name='Plot1';plot:SetAttribute('GardenOwnerId',7);plot:SetAttribute('GardenPlantCount',1);plot.Parent=map
local crop=Rules.NewCrop({SeedId='SunflowerSeed',SeedScale=1,Id='seed-1',PackMutation='None',Weather='None'},'c1',Catalog.SunflowerSeed,0,0,0)
local cropModel=R.new('Model');cropModel.Name='Crop_c1';cropModel.Parent=plot
local anchor=R.new('Part');anchor.Name='CropAnchor';anchor.CFrame=R.CFrame.new(0,0,0);anchor.Size=R.Vector3.new(4,6,4);anchor.Parent=cropModel;cropModel.PrimaryPart=anchor
local art=R.new('Model');art.Name='LocalPlantArt';art.Parent=cropModel
local fruit1=R.new('Model');fruit1.Name='Harvest_1';fruit1:SetAttribute('HarvestIndex',1);fruit1.Parent=art
local fp=R.new('Part');fp.Parent=fruit1
local garden={Plots={['1']={crop}}}
local Data={Gardens={[me]=garden},IsLoaded=function()return true end,_gardenChanged=function()end,_notifySeedInventory=function()end,
 MarkDirty=function()end,QueueGardenSave=function()end,GetChestRecords=function()return{}end}
local rendered=0
local Chests={Config={RemoteFolderName='ChestChaseRemotes'},Map={Chests={seed}},Openings={},Bases={GetPlayerBase=function()return nil end},RenderGarden=function()rendered+=1 end}
-- Server
local Service=W.load('WeatherService',R.new('ModuleScript'))
local svc=Service.new(Data,Chests)
local remote=remotes:FindFirstChild('WeatherAdopted');check(remote~=nil,'WeatherAdopted remote exists')
remote.OnClientEvent=R.signal();local toAll,toMe={},{}
remote.FireAllClients=function(_,p)table.insert(toAll,p);remote.OnClientEvent:Fire(p)end
remote.FireClient=function(_,who,p)table.insert(toMe,{Who=who,P=p});remote.OnClientEvent:Fire(p)end
-- Client
W.load('MutationHighlights',R.new('LocalScript'))
local labels=pg:FindFirstChild('MutationLabels');check(labels~=nil,'client label folder made')
-- 1. Rain: the pack, the plant and both fruits turn Drippy -------------------------------------------------------------
svc.Override={Kind='Rain',Cycle=5,Until=1e12}
svc:Step(R.clock)
local glow=packet:FindFirstChild('MutationGlow')
check(glow and glow:IsA('Highlight'),'mutated pack gets a server Highlight on the pack art (seen by everyone)')
check(glow and W.CS:HasTag(glow,'MutationGlow'),'glow is tagged for the client pulse')
check(glow and glow.Adornee==packet and glow.DepthMode==R.Enum.HighlightDepthMode.AlwaysOnTop,'glow adorns the pack and shows through walls')
local drippy=Traits.Traits.Drippy.Color
check(glow and glow.FillColor.R==drippy.R and glow.FillColor.B==drippy.B,'glow uses the weather colour (Drippy blue)')
check(seed.Weather=='Drippy','pack became Drippy')
check(#toAll==1 and toAll[1].Scope=='World'and toAll[1].Packs==1,'everyone gets the world pack notice')
check(#toMe==1 and toMe[1].Who==me,'owner gets the owned notice')
local owned=toMe[1]and toMe[1].P
local items=owned and owned.Items
check(items and #items==1 and items[1].CropId=='c1'and items[1].SeedId=='SunflowerSeed','owned notice names the crop that changed')
check(items and items[1].Plant==true and #items[1].Fruits==2,'plant + both fruits recorded ('..tostring(items and #items[1].Fruits)..' fruits)')
local text=owned and Copy.Weather({Trait=owned.Trait,Count=owned.Count,Plants=owned.Plants,Fruits=owned.Fruits,Packs=owned.Packs,Scope='Owned',Items=Glow.Items(owned.Items,Catalog)})
check(text and text:find('Your Watermelon plant and 2 fruits',1,true)and text:find('Drippy',1,true),'notice states which plant: '..tostring(text))
local worldText=Copy.Weather(toAll[1]);check(worldText:find('1 pack',1,true)and worldText:find('Forest',1,true),'world pack notice unchanged: '..worldText)
-- Client: rainbow outline on my plant + label naming it
local rainbow=cropModel:FindFirstChild('MutationRainbow')
check(rainbow and rainbow:IsA('Highlight')and rainbow.Adornee==cropModel,'my plant gets a rainbow outline')
local label=labels:FindFirstChild('Mutation_c1')
check(label and label:FindFirstChild('Text').Text:find('Drippy Watermelon',1,true),'label names the plant: '..tostring(label and label:FindFirstChild('Text').Text))
check(label and label.Adornee==anchor and label.AlwaysOnTop,'label floats over the plant')
check(label and label.MaxDistance==math.huge,'R129: label shows from any distance')
check(rainbow.DepthMode==R.Enum.HighlightDepthMode.AlwaysOnTop,'R129: rainbow outline shows through walls')
W.frames(1,1/60);local c1=rainbow.FillColor;W.frames(30,1/60);local c2=rainbow.FillColor
check(c1 and c2 and(math.abs(c1.R-c2.R)+math.abs(c1.G-c2.G)+math.abs(c1.B-c2.B))>.2,'outline colour cycles (rainbow)')
check(rainbow.FillColor~=rainbow.OutlineColor,'fill and outline are different hues')
local sat=math.max(c2.R,c2.G,c2.B)-math.min(c2.R,c2.G,c2.B);check(sat>.6,'neon: fully saturated colours ('..sat..')')
-- Pack glow pulses on the client and hides while the pack is taken.
local t1=glow.FillTransparency;W.frames(20,1/60);local t2=glow.FillTransparency
check(math.abs(t1-t2)>.02,'pack glow pulses ('..t1..' -> '..t2..')')
packet:SetAttribute('PackVisible',false);W.frames(1);check(glow.Enabled==false,'glow hidden while the pack is taken/hidden')
packet:SetAttribute('PackVisible',true);W.frames(1);check(glow.Enabled==true,'glow back when the pack shows')
-- Rainbow fades and is cleaned up after PlantSeconds
W.frames(math.floor((Glow.PlantSeconds-.5-R.clock)*60),1/60) -- the notice came at clock 0
check(rainbow.Parent~=nil and rainbow.FillTransparency>.3,'rainbow fading near the end ('..rainbow.FillTransparency..')')
W.frames(60,1/60)
check(cropModel:FindFirstChild('MutationRainbow')==nil and labels:FindFirstChild('Mutation_c1')==nil,'rainbow and label removed after '..Glow.PlantSeconds..' s')
-- 2. Server expiry: the glow goes when the pack is taken, respawned or after PackSeconds ---------------------------------
seed.Available=false;svc.Override={Kind='Clear',Cycle=5,Until=1e12};svc:Step(R.clock)
check(packet:FindFirstChild('MutationGlow')==nil,'taken pack loses its glow on the next weather step')
seed.Available=true;svc:GlowPack(seed,packet,'Frosted',seed);seed.Generation+=1;svc:Step(R.clock)
check(packet:FindFirstChild('MutationGlow')==nil,'respawned pack (new generation) loses the old glow')
svc:GlowPack(seed,packet,'Charged',seed);svc:Step(R.clock);check(packet:FindFirstChild('MutationGlow')~=nil,'fresh glow stays while live')
R.advance(Glow.PackSeconds+1);svc:Step(R.clock);check(packet:FindFirstChild('MutationGlow')==nil,'glow expires after '..Glow.PackSeconds..' s')
-- 3. Thunderstorm with plant rolls off: only fruits change -> the fruit itself is outlined ------------------------------
Traits.PlantChance=0;table.clear(toMe);table.clear(toAll)
svc.Override={Kind='Thunderstorm',Cycle=6,Until=1e12};svc:Step(R.clock)
owned=toMe[1]and toMe[1].P;items=owned and owned.Items
check(items and items[1].Plant==false and #items[1].Fruits==2,'fruit-only change recorded')
text=owned and Copy.Weather({Trait=owned.Trait,Count=owned.Count,Plants=owned.Plants,Fruits=owned.Fruits,Packs=0,Scope='Owned',Items=Glow.Items(owned.Items,Catalog)})
check(text and text:find('2 fruits on your Watermelon',1,true)and text:find('Charged',1,true),'fruit notice: '..tostring(text))
check(fruit1:FindFirstChild('MutationRainbow')~=nil,'the fruit itself gets the rainbow outline')
check(cropModel:FindFirstChild('MutationRainbow')==nil,'whole plant not outlined for a fruit-only change')
label=labels:FindFirstChild('Mutation_c1');check(label and label:FindFirstChild('Text').Text:find('Charged Watermelon',1,true),'fruit label: '..tostring(label and label:FindFirstChild('Text').Text))
-- Art rebuilt (fruit model replaced): the outline follows the new model.
fruit1:Destroy();local fruitB=R.new('Model');fruitB.Name='Harvest_1';fruitB:SetAttribute('HarvestIndex',1);fruitB.Parent=art
W.frames(40,1/60);check(fruitB:FindFirstChild('MutationRainbow')~=nil,'outline re-attaches after the plant art is rebuilt')
W.frames(13*60,1/60)
-- 4. Copy for several plants, and sanitising ----------------------------------------------------------------------------
local many=Glow.Items({{CropId='a',SeedId='SunflowerSeed',Plant=true},{CropId='b',SeedId='MooncapSeed',Plant=true},{CropId='c',SeedId='BluebellSeed',Fruits={1}},{CropId='d',SeedId='AppleSeed',Plant=true}},Catalog)
local multi=Copy.PlantSubject(many,0);check(multi and multi:find(' and ',1,true)and multi:find('more plants',1,true),'several plants: '..tostring(multi))
check(Copy.PlantSubject(Glow.Items({{CropId='a',SeedId='SunflowerSeed',Fruits={2}}},Catalog),0)=='A fruit on your Watermelon','one fruit wording')
check(#Glow.Items({{CropId='x',SeedId='NotASeed',Plant=true},{CropId=('z'):rep(200),SeedId='SunflowerSeed',Plant=true},{CropId='y',SeedId='SunflowerSeed'},'junk',{CropId='ok',SeedId='SunflowerSeed',Fruits={1,1,9,-1,1.5,2}}},Catalog)==1,'bad items dropped')
local clean=Glow.Item({CropId='ok',SeedId='SunflowerSeed',Fruits={1,1,9,2}},Catalog);check(clean and #clean.Fruits==2,'fruit indexes de-duplicated and bounded')
local cap={};for i=1,40 do cap[i]={CropId='c'..i,SeedId='SunflowerSeed',Plant=true}end;check(#Glow.Items(cap,Catalog)==Glow.MaxItems,'items capped at '..Glow.MaxItems)
check(Copy.PlantSubject(nil,0)==nil and Copy.Weather({Trait='Drippy',Count=2,Plants=2,Scope='Owned'}):find('Your 2 plants',1,true),'old notices without items keep the old wording')
-- Client caps simultaneous plant outlines (Roblox renders at most 31 highlights).
for i=1,20 do local m=R.new('Model');m.Name='Crop_k'..i;m.Parent=plot;local a=R.new('Part');a.Parent=m;m.PrimaryPart=a end
remote.OnClientEvent:Fire({Kind='WeatherAdopted',Scope='Owned',Trait='Frosted',Count=20,EventId='x',Items=(function()local t={}for i=1,16 do t[i]={CropId='k'..i,SeedId='SunflowerSeed',Plant=true}end;return t end)()})
local n=0;for _,d in ipairs(map:GetDescendants())do if d.Name=='MutationRainbow'then n+=1 end end
check(n<=Glow.MaxLocal and n>0,'at most '..Glow.MaxLocal..' plant outlines at once ('..n..')')
remote.OnClientEvent:Fire({Kind='WeatherAdopted',Scope='World',Trait='Frosted',Count=1,EventId='y',Items={{CropId='k1',SeedId='SunflowerSeed',Plant=true}}})
check(true,'world notices never outline plants')
-- 5. The real notice feed carries the items through its 0.2 s merge window and shows the plant name.
do
 local Feed=W.module('NoticeFeed83')
 Feed.Weather({Kind='WeatherAdopted',EventId='feed-1',Scope='Owned',Trait='Drippy',Count=1,Plants=1,Fruits=0,Packs=0,Items={{CropId='c1',SeedId='SunflowerSeed',Plant=true,Fruits={}}}})
 W.frames(30,1/60)
 local shown=''
 local root=pg:FindFirstChild('ChestChaseNotices83');if root then for _,d in ipairs(root:GetDescendants())do if d.Name=='Announcement'then shown..=tostring(d._props.Text)..'|'end end end
 check(shown:find('Your Watermelon plant',1,true)~=nil,'notice on screen names the plant: '..shown)
end
-- 6. Owner test 'weather rain all': every exposed pack/plant/fruit changes even at the real 2% odds; glows capped.
do
 Traits.PackChance=.02;Traits.PlantChance=.02;Traits.FruitChance=.02
 local folder=R.new('Folder');folder.Name='ChestChaseServer'
 for _,n in ipairs({'OwnerUpdateCommands82','OwnerTestState82'})do local m=R.new('ModuleScript');m.Name=n;m._source=n;m.Parent=folder end
 local X=W.require(folder.OwnerUpdateCommands82)
 -- 24 fresh world packs (more than the glow cap) plus my Watermelon.
 local extra={}
 for i=1,24 do
  local slotI=R.new('Model');slotI.Name='Pack_X'..i;slotI.Parent=map
  local pk=R.new('Model');pk.Name='SeedPacket';pk.Parent=slotI;local b=R.new('Part');b.Parent=pk
  extra[i]={Available=true,Model=slotI,Stage=2,Generation=1,PackSize=1,Weather='None'}
 end
 Chests.Map.Chests=extra;Chests.Weather=svc;table.clear(toAll);table.clear(toMe)
 crop.Weather='None';crop.FruitWeather=nil
 local owner=R.new('Player');owner.Name='Owner';owner.UserId=1
 local ok,msg=X.Execute({Chests=Chests,Data=Data,Map={MapRoot=map},Chase={}},owner,'weather',{'blizzard','all'})
 check(ok and tostring(msg):find('every exposed pack',1,true),'weather blizzard all accepted: '..tostring(msg))
 local frosted,glowing=0,0
 for _,s2 in ipairs(extra)do if Traits.Has(s2.Weather,'Frosted')then frosted+=1 end;if s2.Model.SeedPacket:FindFirstChild('MutationGlow')then glowing+=1 end end
 check(frosted==24,'every exposed pack became Frosted ('..frosted..')')
 local lit=0;for _,d in ipairs(map:GetDescendants())do if d.Name=='MutationGlow'then lit+=1 end end
 check(lit==Glow.MaxPackGlows and glowing>0,'pack glows capped at '..Glow.MaxPackGlows..' in the whole world ('..lit..')')
 check(Traits.Has(crop.Weather,'Frosted'),'my plant became Frosted too')
 local own=toMe[1]and toMe[1].P;check(own and own.Items and own.Items[1].Plant==true,'owner notice names the plant')
 ok,msg=X.Execute({Chests=Chests,Data=Data,Map={MapRoot=map},Chase={}},owner,'weather',{'clear','all'})
 check(ok==false,'clear all refused (nothing to change)')
 ok=X.Execute({Chests=Chests,Data=Data,Map={MapRoot=map},Chase={}},owner,'weather',{'rain','lots'});check(ok==false,'unknown extra word refused')
 -- Plain weather (no all) uses the real 2% odds: a fresh event changes only a few of 24 packs.
 for _,s2 in ipairs(extra)do s2.Weather='None';s2.Generation+=1 end
 X.Execute({Chests=Chests,Data=Data,Map={MapRoot=map},Chase={}},owner,'weather',{'rain'})
 local drippy=0;for _,s2 in ipairs(extra)do if Traits.Has(s2.Weather,'Drippy')then drippy+=1 end end
 check(drippy<=6,'normal weather keeps the 2% odds ('..drippy..' of 24)')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
