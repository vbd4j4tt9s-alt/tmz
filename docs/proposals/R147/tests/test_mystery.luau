--!nocheck
-- R147 (owner: "a pedestal with a mystery pack, the pack will be a black silhouette, after 15 minutes of staying in the
-- game they unlock the pack, this refreshes every day, the pack will be based on the treadmill they have", "the pedestal
-- will be located in their base at the other empty side of the base", "add a speed req on top of every keeper's head"):
-- the real MysteryPackService + MysteryPackRules + PlayerDataService (AddChest, the pack-size pity, save rows),
-- PremiumProgress.Decode, SeedPackVisuals/SeedPackRenderer (fake mesh assets), BiomeVisuals.BuildTreadmillV131 (the real
-- treadmill, for the pedestal's clearance), the owner command `mystery`, and the keeper tagging (ChaseService
-- _preparePersistentGuardian, VeiledEvent81 EnsureGuardian, KeeperPursuit.EscapeSpeed). DataStores are in memory;
-- BaseService / ChestService are stand-ins (GetPlayerBase / SyncTools); mock time = os.time (R.clock).
-- Review fixes (section 15 and the checks marked [streaming] / [prompt] / [drift]): the pedestal is a Persistent model and
-- its Take prompt is Enabled only while the pack is Ready; a pack that does not fit in a full Bag at midnight is owed
-- (saved, at most 3, granted once when there is room) while today's 15 minutes run; UnlockAt is republished when the
-- countdown drifts after a server hitch.
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-9)end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
function Http.GetSecret(_,name)return {Secret=name}end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
-- Fake pack mesh assets, dressed like the real art (a SurfaceAppearance, a texture, a decal, glints, a light) so the
-- black silhouette has something to strip.
F.packAssets(W)
for _,model in ipairs(RS.SeedPackMeshAssets:GetChildren())do for _,mp in ipairs(model:GetChildren())do if mp:IsA('MeshPart')then
 mp.TextureID='rbxassetid://111';mp.Reflectance=.25;mp.MaterialVariant='PaperVariant';mp.Material=R.Enum.Material.Fabric
 for _,spec in ipairs({{'SurfaceAppearance','PackSkin'},{'Decal','Stamp'},{'ParticleEmitter','Glints'},{'PointLight','Shine'}})do local x=R.new(spec[1]);x.Name=spec[2];x.Parent=mp end
end end end
local Config=server('Config');local M=W.module('MysteryPackRules');local Rules=W.module('SeedPackRules');local Pity=W.module('PackSizePity')
local Pursuit=W.module('KeeperPursuit');local Balance=W.module('BalanceValues81')

-- 1. The rules (pure) ------------------------------------------------------------------------------------------------
check(M.UnlockSeconds==900 and M.SaveEvery==15,'15 minutes (900 s) of play unlock it; time is saved every 15 s')
check(M.Offset.X==34 and M.Offset.Y==0 and M.Offset.Z==75,'pedestal at pad-space X +34, Z 75 (the treadmill is at X -34)')
check(#M.Order==6 and M.Order[1]=='Pack02'and M.Order[6]=='EclipseReliquary'and table.find(M.Order,'Pack01')==nil,'six rarities, never Pack01 (Common)')
local sum=0;for _,k in ipairs(M.Order)do sum+=M.Odds[k]end
check(near(sum,1,1e-9),'the odds add up to 100% ('..sum..')')
local descending=true;for i=2,#M.Order do if M.Odds[M.Order[i]]>=M.Odds[M.Order[i-1]]then descending=false end end
check(descending and M.Odds.Pack02==.45 and M.Odds.EclipseReliquary==.001,'rarer packs are less likely: 45 / 30 / 17 / 6 / 1.9 / 0.1 %')
check(M.Void.Variant=='EclipseReliquary'and M.Void.Stage==7,'the Void pack lives in stage 7')
check(M.Day(20000*86400)==20000 and M.Day(20000*86400+86399)==20000 and M.Day(20001*86400)==20001,'UTC days')
check(M.NextDay(20000*86400+5)==20001*86400 and M.NextDay(20001*86400-1)==20001*86400 and M.NextDay(20001*86400)==20002*86400,'the next UTC midnight')
check(M.Clock(900)=='15:00'and M.Clock(899.2)=='15:00'and M.Clock(61)=='1:01'and M.Clock(59.1)=='1:00'and M.Clock(0)=='0:00'and M.Clock(-5)=='0:00'and M.Clock(3)=='0:03','countdown text rounds up: 15:00, 1:01, 0:03')
-- Saved state: anything odd resets, nothing odd ever pays.
local fresh=M.Read(nil)
check(fresh.Day==-1 and fresh.Seconds==0 and fresh.Claimed==false and fresh.Stage==nil and fresh.Variant==nil,'no saved state: an empty, locked, untaken pack')
for _,junk in ipairs({'x',5,true,{},{Day='a',Seconds='b',Stage='c',Variant=5,Claimed='yes'}})do
 local r=M.Read(junk);check(r.Day==-1 and r.Seconds==0 and r.Claimed==false and r.Stage==nil and r.Variant==nil,'junk ('..tostring(type(junk))..') reads as fresh')
end
local good={Day=20000,Seconds=300,Stage=3,Variant='Pack04',Claimed=false}
local g=M.Read(good);check(g.Day==20000 and g.Seconds==300 and g.Stage==3 and g.Variant=='Pack04'and g.Claimed==false and g~=good,'a good state is kept (as a copy)')
check(M.Read({Seconds=5000}).Seconds==900 and M.Read({Seconds=-5}).Seconds==0 and M.Read({Seconds=0/0}).Seconds==0 and M.Read({Seconds=math.huge}).Seconds==900 and M.Read({Seconds='9'}).Seconds==0,'seconds are clamped to 0..900')
check(M.Read({Day=1.5}).Day==-1 and M.Read({Day=0/0}).Day==-1 and M.Read({Day=1e9}).Day==-1 and M.Read({Day=-1}).Day==-1 and M.Read({Day=-2}).Day==-1 and M.Read({Day=0}).Day==0,'the day must be a whole number from -1 to 1e7')
local badStage=true;for _,s in ipairs({0,8,1.5,-1,'3',0/0})do if M.Read({Stage=s,Variant='Pack03',Day=1}).Stage~=nil then badStage=false end end
check(badStage,'a stage must be a whole number 1-7')
local badVariant=true;for _,v in ipairs({'Pack01','Small','Standard','MechLimited','pack03','',5})do if M.Read({Stage=2,Variant=v,Day=1}).Variant~=nil then badVariant=false end end
check(badVariant and M.Read({Stage=7,Variant='EclipseReliquary'}).Variant=='EclipseReliquary','the variant must be one of the six mystery rarities (never Pack01, Mech, legacy keys)')
check(M.Read({Claimed=true}).Claimed==false and M.Read({Stage=2,Variant='Pack02',Claimed='yes'}).Claimed==false and M.Read({Stage=2,Variant='Pack02',Claimed=true}).Claimed==true,'"taken" only counts for a pack that was unlocked (has a stage) and only for true')
check(not M.Unlocked({Seconds=900})and M.Unlocked({Seconds=900,Stage=1,Variant='Pack02'})and not M.Unlocked({Seconds=899,Stage=1,Variant='Pack02'}),'unlocked = 900 s and a rolled pack')
check(M.Left({Seconds=0})==900 and M.Left({Seconds=898.5})==1.5 and M.Left({Seconds=900})==0,'time left')
-- Owed packs (a full Bag at midnight): sanitized like the rest, never paying out anything odd.
check(M.MaxOwed==3 and M.DriftSeconds==2,'at most 3 owed packs; UnlockAt drift tolerance 2 s')
check(type(fresh.Owed)=='table'and #fresh.Owed==0 and#M.Read({Day=5,Seconds=900,Stage=2,Variant='Pack05',Claimed=false}).Owed==0,'a save from before Owed existed reads with an empty owed list (everything else as before)')
do
 local old=M.Read({Day=19999,Seconds=900,Stage=2,Variant='Pack05',Claimed=false})
 check(old.Day==19999 and old.Seconds==900 and old.Stage==2 and old.Variant=='Pack05'and old.Claimed==false and M.Unlocked(old),'(and an old unlocked, untaken pack is still read as one)')
 local o=M.Read({Day=20001,Seconds=3,Owed={{Day=20000,Stage=3,Variant='Pack04'},{Day=19999,Stage=7,Variant='EclipseReliquary',Extra=1}}})
 check(#o.Owed==2 and o.Owed[1].Day==20000 and o.Owed[1].Stage==3 and o.Owed[1].Variant=='Pack04'and o.Owed[2].Variant=='EclipseReliquary'and o.Owed[2].Extra==nil,'a good owed list is kept in order, as copies with only Day / Stage / Variant')
 local src={Owed={{Day=1,Stage=2,Variant='Pack02'}}};local c=M.Read(src);check(c.Owed~=src.Owed and c.Owed[1]~=src.Owed[1],'(copies, not the saved tables)')
 local five={Owed={}};for i=1,5 do five.Owed[i]={Day=100+i,Stage=2,Variant='Pack03'}end
 local f=M.Read(five);check(#f.Owed==3 and f.Owed[1].Day==101 and f.Owed[2].Day==102 and f.Owed[3].Day==103,'more than 3: the 3 oldest are kept')
 local big={Owed={}};for i=1,5000 do big.Owed[i]={Day=i,Stage=1,Variant='Pack02'}end
 check(#M.Read(big).Owed==3,'a huge list is cut to 3 without walking it all')
 local junk={Owed={'x',5,true,{},{Day='a',Stage=2,Variant='Pack02'},{Day=3,Stage=0,Variant='Pack02'},{Day=3,Stage=8,Variant='Pack02'},{Day=3,Stage=1.5,Variant='Pack02'},{Day=3,Stage=2,Variant='Pack01'},{Day=3,Stage=2,Variant='Mech'},{Day=3,Stage=2,Variant=5},{Day=1.5,Stage=2,Variant='Pack02'},{Day=0/0,Stage=2,Variant='Pack02'},{Day=2e9,Stage=2,Variant='Pack02'},{Day=-2,Stage=2,Variant='Pack02'}}}
 check(#M.Read(junk).Owed==0,'odd entries (not tables, bad day / stage / variant, Common) are dropped: they never pay out')
 local mixed=M.Read({Owed={{Day=1,Stage=2,Variant='Pack02'},'x',{Day=2,Stage=99,Variant='Pack02'},{Day=3,Stage=4,Variant='Pack05'}}})
 check(#mixed.Owed==2 and mixed.Owed[1].Day==1 and mixed.Owed[2].Day==3,'good entries around bad ones are kept')
 local dup=M.Read({Owed={{Day=7,Stage=2,Variant='Pack02'},{Day=7,Stage=3,Variant='Pack03'},{Day=8,Stage=3,Variant='Pack03'}}})
 check(#dup.Owed==2 and dup.Owed[1].Stage==2 and dup.Owed[2].Day==8,'one owed pack per day (a second entry for the same day is dropped)')
 for _,bad in ipairs({'x',5,true,{Owed='x'},{Owed=5},{Owed=true}})do check(#M.Read(type(bad)=='table'and bad or{Owed=bad}).Owed==0,'a non-list Owed ('..tostring(type(bad))..') reads as empty')end
end
-- Rolls.
local draws=0;local function fixed(u)return function()draws+=1;return u end end
local bins={{.0,'Pack02'},{.449,'Pack02'},{.451,'Pack03'},{.749,'Pack03'},{.751,'Pack04'},{.919,'Pack04'},{.921,'Pack05'},{.979,'Pack05'},{.981,'Pack06'},{.998,'Pack06'},{.9991,'EclipseReliquary'},{1,'EclipseReliquary'}}
local binsOk=true;local bad=''
for _,b in ipairs(bins)do draws=0;local r=M.Roll(3,fixed(b[1]));if r.Variant~=b[2]or draws~=1 then binsOk=false;bad=bad..' '..b[1]..'->'..tostring(r.Variant)end end
check(binsOk,'one draw picks the rarity at the 45/75/92/98/99.9% marks'..bad)
check(M.Roll(3,fixed(.5)).Stage==3 and M.Roll(6,fixed(.1)).Stage==6 and M.Roll(7,fixed(.95)).Stage==7,'a regular pack keeps the treadmill biome')
check(M.Roll(1,fixed(.9995)).Stage==7 and M.Roll(2,fixed(.9995)).Variant=='EclipseReliquary','the Void pack always comes out in stage 7, whatever the treadmill')
check(M.Roll(4,fixed(0/0)).Variant=='Pack02'and M.Roll(4,fixed(-3)).Variant=='Pack02'and M.Roll(4,fixed(7)).Variant=='EclipseReliquary'and M.Roll(4,fixed('x')).Variant=='Pack02'and M.Roll(4,function()return nil end).Variant=='Pack02','bad draws are clamped (NaN / nil / text -> the commonest, huge -> the rarest)')
do
 math.randomseed(147);local counts={};local n=200000
 for _=1,n do local r=M.Roll(2,function()return math.random()end);counts[r.Variant]=(counts[r.Variant]or 0)+1 end
 local good=true;local txt={}
 for _,k in ipairs(M.Order)do local p=M.Odds[k];local sd=math.sqrt(n*p*(1-p));local c=counts[k]or 0;txt[#txt+1]=k..'='..c;if math.abs(c-n*p)>5*sd then good=false end end
 check(good and counts.Pack01==nil,'200,000 rolls follow the odds within 5 sigma and never give Pack01 ('..table.concat(txt,' ')..')')
end
-- The biome of the best treadmill.
local tiers=Config.TreadmillTiers
local want={1,6,2,3,4,5,7};local stagesOk=#tiers==7
for i=1,7 do if M.Stage(tiers,i)~=want[i]then stagesOk=false end end
check(stagesOk,'treadmill tier 1-7 -> Forest, Jungle, Desert, Snow, Lava, Crystal, Storm (1, 6, 2, 3, 4, 5, 7)')
check(M.Stage(tiers,0)==1 and M.Stage(tiers,-4)==1 and M.Stage(tiers,99)==7 and M.Stage(tiers,2.9)==6 and M.Stage(tiers,0/0)==1 and M.Stage(tiers,nil)==1 and M.Stage(tiers,'3')==2,'odd tier values are clamped')
check(M.Stage({{Stage=8}},1)==1 and M.Stage({{Stage=0}},1)==1 and M.Stage({{Stage=2.5}},1)==1 and M.Stage({{Stage=5}},1)==5,'a tier without a regular biome stage falls back to Forest')

-- 2. The world: two bases, the real service ---------------------------------------------------------------------------
local Map={BaseRecords={},GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local shown={}
local Notes={Show=function(_,p,text,color,duration,kind)shown[#shown+1]={P=p,Text=text,Color=color,Kind=kind}end} -- (R150 review: kind = the 5th argument, 'Denied' for a refusal)
local Data=server('PlayerDataService').new(Config,Map,Notes)
R.clock=20000*86400+3600 -- 01:00 UTC
local DAY0=20000
local function baseOf(index,cframe)
 local model=R.new('Model');model.Name='Base'..index;model:SetAttribute('BaseIndex',index);model.Parent=W.workspace
 local pad=R.new('Part');pad.Name='Pad';pad.Size=R.Vector3.new(200,2,200);pad.CFrame=cframe;pad.Parent=model
 return {Index=index,Model=model,Pad=pad}
end
local rec1=baseOf(1,R.CFrame.new(100,5,-40));local rec2=baseOf(2,R.CFrame.new(-300,5,200)*R.CFrame.Angles(0,math.pi/2,0))
Map.BaseRecords[1]=rec1;Map.BaseRecords[2]=rec2
local baseOfUser={}
local Bases={Map=Map,GetPlayerBase=function(_,p)return baseOfUser[p.UserId]end}
local syncedBy={};local Chests={SyncTools=function(_,p)syncedBy[p]=(syncedBy[p]or 0)+1 end}
local function syncs(p)return syncedBy[p]or 0 end
local S=server('MysteryPackService').new(Config,Data,Bases,Chests,Notes,Map)
check(S:Start()==S,'Start returns the service')
local heartbeat=S.Connection
check(S:Start()==S and S.Connection==heartbeat,'Start twice does not connect Heartbeat twice')
local function ped(rec)return S.Pedestals[rec]and S.Pedestals[rec].Model end
local function attr(rec,k)local m=ped(rec);return m and m:GetAttribute(k)end
local function pack(rec)local m=ped(rec);local h=m and m:FindFirstChild('MysteryPack');return h and h:FindFirstChild('SeedPacket')end
local function prompt(rec)return S.Pedestals[rec].Prompt end
-- R150: the pedestal's look follows the state (MysteryPedestalArt.Tint: the glow pad and the four gems, the light) and its colours follow the treadmill's biome.
local function litLook(rec,state)
 local ped=S.Pedestals[rec];local want=M.StateLook[state];local n=0;local ok=true
 for _,p in ipairs(ped.Model:GetChildren())do if p.Name=='Glow ring'or p.Name=='Gem'then
  n+=1;local c=p.Color
  if not(math.abs(c.R*255-want.Color[1])<.5 and math.abs(c.G*255-want.Color[2])<.5 and math.abs(c.B*255-want.Color[3])<.5 and(p.Material==R.Enum.Material.Neon)==want.Neon and math.abs(p.Transparency-want.Transparency)<1e-9)then ok=false end
 end end
 local light=ped.Light
 if want.Light then ok=ok and light.Enabled==true and math.abs(light.Brightness-want.Light.Brightness)<1e-9 and math.abs(light.Range-want.Light.Range)<1e-9 else ok=ok and light.Enabled==false end
 return ok and n==5
end
local function bodyIs(rec,stage)
 local pal=M.Theme(stage);local ok=true;local n=0
 for _,p in ipairs(S.Pedestals[rec].Model:GetChildren())do if p.Name=='Column'then n+=1
  if not(math.abs(p.Color.R*255-pal.Body[1])<.5 and math.abs(p.Color.G*255-pal.Body[2])<.5 and math.abs(p.Color.B*255-pal.Body[3])<.5 and p.Material==R.Enum.Material[pal.Material])then ok=false end
 end end
 return ok and n==1
end
-- 2a. Both pedestals are built at start, empty, tagged, in the right place.
check(ped(rec1)~=nil and ped(rec2)~=nil and ped(rec1)~=ped(rec2),'one pedestal per base, built when the service starts')
check(ped(rec1).Parent==rec1.Model and ped(rec2).Parent==rec2.Model and ped(rec1).Name=='MysteryPedestal','each is a Model "MysteryPedestal" inside its base')
check(W.CS:HasTag(ped(rec1),'MysteryPedestal')and W.CS:HasTag(ped(rec2),'MysteryPedestal'),'tagged "MysteryPedestal"')
check(ped(rec1):GetAttribute('MysteryPedestal')==M.Version,'the model carries the MysteryPedestal version attribute')
check(attr(rec1,'State')=='Empty'and attr(rec1,'OwnerUserId')==nil and attr(rec1,'OwnerName')==nil and attr(rec1,'UnlockAt')==nil and attr(rec1,'Variant')==nil,'with no owner: State Empty and no owner / time / variant')
check(pack(rec1)==nil and ped(rec1):FindFirstChild('MysteryPack')==nil,'no pack on an empty pedestal')
local pr=prompt(rec1)
check(pr.Name=='TakeMysteryPack'and pr.ActionText=='Take'and pr.ObjectText=='Mystery Pack'and pr.HoldDuration==.5 and pr.MaxActivationDistance==12 and pr.Parent==S.Pedestals[rec1].Anchor,'the ProximityPrompt "TakeMysteryPack" (hold 0.5 s, 12 studs) sits on the pack anchor')
check(ped(rec1).ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent and ped(rec2).ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent,'[streaming] each pedestal Model is Persistent (it never streams out, so clients never hold stale or late copies)')
check(ped(rec1).ModelStreamingMode~=R.Enum.ModelStreamingMode.Default and ped(rec1).ModelStreamingMode~=R.Enum.ModelStreamingMode.Atomic,'[streaming] (not Default, not Atomic)')
check(pr.Enabled==false and prompt(rec2).Enabled==false,'[prompt] built Enabled=false: nobody sees a Take prompt on an empty pedestal')
-- The real treadmill, to measure the empty corner.
local okT,errT=pcall(function()return server('BiomeVisuals').BuildTreadmillV131(rec1.Model,1)end)
check(okT,'the real treadmill builds on the mock pad: '..tostring(errT))
local function footprint(model,pad)
 local x0,x1,z0,z1=1e9,-1e9,1e9,-1e9
 for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then
  local c=pad.CFrame:PointToObjectSpace(d.Position);local r=math.max(d.Size.X,d.Size.Y,d.Size.Z)/2 -- (a conservative square)
  x0=math.min(x0,c.X-r);x1=math.max(x1,c.X+r);z0=math.min(z0,c.Z-r);z1=math.max(z1,c.Z+r)
 end end
 return {X0=x0,X1=x1,Z0=z0,Z1=z1}
end
local function overlap(a,b)return a.X0<b.X1 and a.X1>b.X0 and a.Z0<b.Z1 and a.Z1>b.Z0 end
-- The neighbours the pedestal has to keep clear of, as the real layout code builds them.
check(W.B.WorldDesign:find("pad.CFrame*CF(side*49,1,74)",1,true)and W.B.WorldDesign:find("'Tool box',V(7,3,5)",1,true)and W.B.WorldDesign:find("'Box rim',V(7.5,.5,5.5)",1,true),'(WorldDesign still puts a 7x5 tool box with a 7.5x5.5 rim at X=+-49, Z=74)')
check(W.B.GardenBaseLayout:find("'Treadmill apron',Vector3.new(17,.18,22),cf*CFrame.new(-34,ground+.09,75)",1,true)~=nil and W.B.BiomeVisuals:find('pad.CFrame*CF(-34,pad.Size.Y/2+.90,75)',1,true)~=nil,'(GardenBaseLayout / BiomeVisuals still put the treadmill and its apron at X -34, Z 75)')
local treadmill=footprint(rec1.Model.TreadmillArtV131,rec1.Pad)
local tm=(treadmill.X0+treadmill.X1)/2
for _,rec in ipairs({rec1,rec2})do
 local anchor=S.Pedestals[rec].Anchor;local pad=rec.Pad
 local c=pad.CFrame:PointToObjectSpace(anchor.Position)
 check(near(c.X,34,1e-6)and near(c.Z,75,1e-6)and near(c.Y,pad.Size.Y/2+9.3,1e-6),('base %d: the pack hovers at pad-space X 34, Z 75 (got %.2f, %.2f, %.2f), also on a rotated pad'):format(rec.Index,c.X,c.Y,c.Z))
 local fp=footprint(ped(rec),pad)
 check(fp.X0>21+1 and fp.X1<45.25-1,('base %d: the plinth spans X %.1f..%.1f: clear of the entrance aisle (|X|<21) and of the tool boxes (X 45.25..52.75)'):format(rec.Index,fp.X0,fp.X1))
 check(not overlap(fp,{X0=45.25,X1=52.75,Z0=71.25,Z1=76.75})and not overlap(fp,{X0=-52.75,X1=-45.25,Z0=71.25,Z1=76.75}),'not over a tool box (7.5x5.5 with its rim, at X=+-49, Z=74)')
 check(not overlap(fp,{X0=-47.4,X1=-20.6,Z0=65.2,Z1=84.8})and not overlap(fp,{X0=-42.5,X1=-25.5,Z0=64,Z1=86}),'not over the treadmill footprint (X -47.4..-20.6, Z 65.2..84.8) or its apron')
 local plinth=ped(rec):FindFirstChild('Plinth');local pc=pad.CFrame:PointToObjectSpace(plinth.Position)
 check(fp.Z0>=65 and fp.Z1<=85 and near(pc.Y-plinth.Size.Y/2,pad.Size.Y/2,1e-6),'inside the treadmill\'s Z band, the plinth standing on the pad')
end
local fp1=footprint(ped(rec1),rec1.Pad)
check(near(tm,-34,.6)and near((fp1.X0+fp1.X1)/2,34,.01),('the pedestal mirrors the real treadmill across the aisle (treadmill centre X %.1f, pedestal %.1f)'):format(tm,(fp1.X0+fp1.X1)/2))
check(not overlap(fp1,treadmill),'and does not touch the real treadmill ('..('%.1f..%.1f vs %.1f..%.1f'):format(fp1.X0,fp1.X1,treadmill.X0,treadmill.X1)..')')
local solids=0;for _,d in ipairs(ped(rec1):GetDescendants())do if d:IsA('BasePart')and d.CanCollide then solids+=1 end end
check(solids>=3 and solids<=5,'a few solid parts (plinth, column, top), the rest is for show ('..solids..')')
-- Building twice never doubles the model; a destroyed pedestal comes back.
S:_build(rec1)
local count=0;for _,c in ipairs(rec1.Model:GetChildren())do if c.Name=='MysteryPedestal'then count+=1 end end
check(count==1,'rebuilding replaces the pedestal (never two)')
local before=S.Pedestals[rec2].Model;before:Destroy()
check(S:Pedestal(rec2)~=nil and ped(rec2)~=before and ped(rec2).Parent==rec2.Model,'a destroyed pedestal is rebuilt')
check(ped(rec2).ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent and prompt(rec2).Enabled==false and W.CS:HasTag(ped(rec2),'MysteryPedestal'),'[streaming] [prompt] and the rebuilt one is Persistent, tagged, prompt off')
-- No owner: Step / Publish / Claim do nothing and do not fail.
check(select(2,pcall(function()S:Step(1);S:Step(1)end))==nil and attr(rec1,'State')=='Empty','Step with nobody home does nothing')

-- 3. Joining: a locked silhouette --------------------------------------------------------------------------------------
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name..' D';p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 local tut=Data:GetPremium(p).Tutorial;if tut then tut.Done=true end
 return p
end
local A=makePlayer(701,'Ava');baseOfUser[701]=rec1
local B=makePlayer(702,'Ben');baseOfUser[702]=rec2
local function lastNote(p)for i=#shown,1,-1 do if shown[i].P==p then return shown[i].Text,shown[i]end end end
local function notes(p,from)local out={};for i=from or 1,#shown do if shown[i].P==p then out[#out+1]=shown[i].Text end end;return out end
local function bag(p)return #Data:GetChestRecords(p)end
local function play(n)for _=1,n do R.advance(1);S:Step(1)end end
local function today()return M.Day(math.floor(R.clock))end
local function nextDay(n)R.clock+=86400*(n or 1);S:Step(1)end -- (midnight passes; the next tick notices)
local t0=math.floor(R.clock)
S.Random={NextNumber=function()return .5 end} -- Pack03
S:Setup(A)
check(attr(rec1,'State')=='Locked'and attr(rec1,'OwnerUserId')==701 and attr(rec1,'OwnerName')=='Ava D','joining: State Locked, OwnerUserId and the display name')
check(attr(rec1,'UnlockAt')==t0+900 and attr(rec1,'NextAt')==(DAY0+1)*86400 and attr(rec1,'Stage')==1,('UnlockAt = now + 15 min (%s), NextAt = the next UTC midnight, Stage = the Forest treadmill'):format(tostring(attr(rec1,'UnlockAt'))))
check(attr(rec1,'Variant')==nil,'the variant is not published while locked (the rarity stays secret)')
check(prompt(rec1).Enabled==false,'[prompt] Locked: the server keeps the Take prompt off, for everyone')
check(litLook(rec1,'Locked')and litLook(rec2,'Empty'),'[look] Locked: the glow pad and the four gems are calm violet neon and the light a soft violet (Ben\'s empty pedestal stays cold and dark)')
check(bodyIs(rec1,1)and bodyIs(rec2,nil),'[look] the pedestal wears the Forest treadmill\'s colours and wood (an empty one the violet default)')
check(S.Owner[A]==rec1 and attr(rec2,'State')=='Empty','only the joined player\'s pedestal woke up')
local st=Data:GetPremium(A).Mystery
check(st and st.Day==DAY0 and st.Seconds==0 and st.Claimed==false and st.Stage==nil,'saved state: today, 0 s, nothing rolled yet')
-- The black silhouette.
local sil=pack(rec1)
check(sil~=nil,'a pack hovers over the pedestal')
local parts,dark,visible=0,true,0
local stripped=true;local textured=0
for _,d in ipairs(sil:GetDescendants())do
 if d:IsA('SurfaceAppearance')or d:IsA('Decal')or d:IsA('Texture')or d:IsA('ParticleEmitter')or d:IsA('Light')then stripped=false end
 if d:IsA('BasePart')then
  parts+=1
  if d.Transparency<1 then
   visible+=1
   local lum=math.max(d.Color.R,d.Color.G,d.Color.B)
   if lum>.1 or d.Material~=R.Enum.Material.SmoothPlastic or(d.Reflectance or 0)~=0 or(d.MaterialVariant or'')~=''then dark=false end
   if d:IsA('MeshPart')and(d.TextureID or'')~=''then textured+=1 end
  end
  if d.CanCollide then dark=false end
 end
end
check(parts>=10 and visible>=10,'the silhouette is the real pack model ('..parts..' parts, '..visible..' visible)')
check(dark,'every visible part is near-black (R,G,B <= 0.1), smooth plastic, no reflectance, no material variant, no collision')
check(stripped and textured==0,'no SurfaceAppearance / Decal / Texture / particles / light, no TextureID on the meshes')
check(not W.CS:HasTag(sil,'BiomeSeedPackVisual'),'not tagged as a track pack (the renderer and highlights leave it alone)')
check(sil:GetAttribute('BagVariant')=='Pack01'and sil:GetAttribute('Stage')==1 and sil:GetAttribute('PackRarity')=='Common','its attributes are the plain biome pack, so nothing gives the rarity away')
check(sil:GetAttribute('MysteryOrigin')~=nil,'MysteryOrigin is set for the client\'s spin')
Data.Dirty[A]=false;play(14)
check(Data.Dirty[A]~=true and Data:GetPremium(A).Mystery.Seconds==14,'14 s of play counted, not flagged for saving yet')
play(1)
check(Data.Dirty[A]==true,'every 15 s of play the profile is flagged for saving (so a crash loses at most 15 s)')
check(attr(rec1,'UnlockAt')==t0+900,'UnlockAt does not creep while counting (the client counts down to it)')
-- Ben joins 2 minutes later (a different base).
play(105)
S:Setup(B);local t1=math.floor(R.clock)
check(attr(rec2,'State')=='Locked'and attr(rec2,'OwnerUserId')==702 and attr(rec2,'UnlockAt')==t1+900 and attr(rec2,'OwnerName')=='Ben D'and pack(rec2)~=nil,'Ben (joined 2 min later): his own pedestal, his own 15 minutes')
check(attr(rec1,'OwnerUserId')==701,'and Ava\'s is untouched')
-- 4. 899 s: still locked; 900 s: unlocked -------------------------------------------------------------------------------
local early=false
for i=1,779 do R.advance(1);S:Step(1);if attr(rec1,'State')~='Locked'then early=true end end
check(not early and Data:GetPremium(A).Mystery.Seconds==899,'899 s of play: still Locked the whole way ('..Data:GetPremium(A).Mystery.Seconds..' s)')
check(attr(rec1,'State')=='Locked'and attr(rec1,'Variant')==nil and attr(rec1,'UnlockAt')==t0+900,'at 899 s: Locked, no variant, UnlockAt unchanged')
check(near(attr(rec1,'UnlockAt')-W.workspace:GetServerTimeNow(),1,1e-6),'the countdown the client shows is 1 s ('..tostring(attr(rec1,'UnlockAt')-W.workspace:GetServerTimeNow())..')')
local packsA=bag(A)
local noClaim,noWhy=S:Claim(A,rec1);R.advance(1)
check(not noClaim and noWhy=='LOCKED'and bag(A)==packsA,'taking it at 899 s is refused (LOCKED)')
pr=prompt(rec1);pr.Triggered:Fire(A);R.advance(1)
check(bag(A)==packsA and attr(rec1,'State')=='Locked','and so is the prompt')
local noteFrom=#shown+1
R.advance(1);S:Step(1)
check(attr(rec1,'State')=='Ready','at 900 s: Ready')
local stageA=attr(rec1,'Stage');local variantA=attr(rec1,'Variant')
check(stageA==Config.TreadmillTiers[Data:GetTreadmillData(A).Tier].Stage and stageA==1,'the pack is the best treadmill\'s biome (Forest)')
check(variantA=='Pack03'and variantA~='Pack01'and table.find(M.Order,variantA)~=nil,'its rarity is one of the six, rolled at that moment (Pack03 for the 0.5 draw)')
check(attr(rec1,'UnlockAt')==nil and attr(rec1,'OwnerUserId')==701,'UnlockAt is cleared once ready')
check(prompt(rec1).Enabled==true and prompt(rec2).Enabled==false,'[prompt] Ready: the server turns Ava\'s Take prompt on (Ben\'s locked one stays off)')
check(litLook(rec1,'Ready')and litLook(rec2,'Locked'),'[look] Ready: Ava\'s pad and gems light up bright gold and the light is gold and brighter (Ben\'s locked one stays violet)')
local stA=Data:GetPremium(A).Mystery
check(stA.Seconds==900 and stA.Stage==stageA and stA.Variant==variantA and stA.Claimed==false and M.Unlocked(stA),'the saved state holds the rolled pack, not taken yet')
local noteA=notes(A,noteFrom)
check(#noteA==1 and noteA[1]:find('unlocked',1,true)and noteA[1]:find('take it',1,true),'a notice tells Ava: '..tostring(noteA[1]))
local rp=pack(rec1)
local colourful,textures,seal=false,0,nil
for _,d in ipairs(rp:GetDescendants())do
 if d:IsA('BasePart')and d.Transparency<1 and math.max(d.Color.R,d.Color.G,d.Color.B)>.4 then colourful=true end
 if d:IsA('SurfaceAppearance')or d:IsA('Decal')or d:IsA('ParticleEmitter')or d:IsA('Light')then textures+=1 end
end
local theme=Rules.GetTheme(stageA);seal=rp:FindFirstChild('BottomSeal')
check(colourful and textures>=4,'the real colours and art are back (the SurfaceAppearance, decal, glints and light stay)')
check(seal and near(seal.Color.R,theme.Ink.R,1e-6)and near(seal.Color.G,theme.Ink.G,1e-6)and near(seal.Color.B,theme.Ink.B,1e-6),'the seal is the biome\'s ink colour again')
check(rp:GetAttribute('BagVariant')==variantA and rp:GetAttribute('Stage')==stageA and rp:GetAttribute('PackRarity')==Rules.GetPackTier(variantA).Name and rp:GetAttribute('PackRarity')=='Rare','the pack model is a real Pack03 (Rare) Forest pack')
check(not W.CS:HasTag(rp,'BiomeSeedPackVisual'),'still not a track pack')
-- 5. Taking it -------------------------------------------------------------------------------------------------------
local luckSeen,addCalls=nil,0
local realAdd=Data.AddChest
Data.AddChest=function(self,p,chest,options)addCalls+=1;luckSeen={Chest=chest,Options=options};return realAdd(self,p,chest,options)end
packsA=bag(A);local syncBefore=syncs(A);local bigBefore=Data:GetPackLuck(A).Big
local bBag=bag(B)
local refused,refusedWhy=S:Claim(B,rec1)
check(refused==false and refusedWhy=='NOT YOURS','someone else claiming Ava\'s pedestal is refused (NOT YOURS)')
prompt(rec1).Triggered:Fire(B);R.advance(1)
check(bag(A)==packsA and bag(B)==bBag and addCalls==0 and attr(rec1,'State')=='Ready'and syncs(A)==syncBefore and syncs(B)==0,'and so is Ben using her prompt: nothing granted to anyone, still Ready')
prompt(rec1).Triggered:Fire(A)
check(bag(A)==packsA+1 and addCalls==1,'the owner takes it: exactly one pack added')
local rec=Data:GetChestRecords(A)[bag(A)]
check(rec and rec.Kind=='Pack'and rec.Stage==stageA and rec.BagVariant==variantA and rec.PackMutation=='None'and rec.Weather=='None'and not rec.PaidRandom,'the Bag pack: Kind Pack, the same biome and rarity, no mutation, not a paid item')
check(rec and rec.OddsVersion==Rules.OddsVersion and Rules.ValidOddsVersion(rec.OddsVersion),'carries the current odds version ('..tostring(rec and rec.OddsVersion)..')')
check(luckSeen and luckSeen.Options and luckSeen.Options.Luck==true and luckSeen.Chest.PackSize==1,'granted with {Luck=true} (the hidden size pity applies)')
check(rec and rec.PackSize and Rules.SanitizePackSize(rec.PackSize)==rec.PackSize and rec.PackSize>=1 and Data:GetPackLuck(A).Big==bigBefore+1,'the pity counter moved (a regular pack counts): size x'..tostring(rec and rec.PackSize))
check(rec and rec.SeedScale==Rules.NewSeedScale(rec.Stage,rec.BagVariant,rec.PackSize),'the seed scale follows the pack size')
check(syncs(A)==syncBefore+1,'ChestService:SyncTools ran once (the hotbar shows the pack)')
check(attr(rec1,'State')=='Claimed'and attr(rec1,'Variant')==variantA and attr(rec1,'UnlockAt')==nil,'the pedestal says Claimed (variant kept, no UnlockAt)')
check(pack(rec1)==nil,'and the pack is gone from the pedestal')
check(prompt(rec1).Enabled==false,'[prompt] Claimed: the prompt is off again')
check(litLook(rec1,'Claimed')and bodyIs(rec1,1),'[look] Claimed: dim mint, no longer neon, a faint ember of light; the biome colours stay')
check(Data:GetPremium(A).Mystery.Claimed==true,'saved as taken')
local note,noteRow=lastNote(A)
check(note and note:find('MYSTERY PACK',1,true)and note:find('Rare',1,true)and note:find('Forest',1,true),'the notice names the rarity and biome: '..tostring(note))
check(noteRow and noteRow.Color and noteRow.Color.R==Rules.GetPackTier(variantA).Color.R,'in the rarity colour')
-- No second claim.
local again,againWhy=S:Claim(A,rec1)
check(again==false and againWhy=='WAIT'and bag(A)==packsA+1,'a second claim straight away is refused (WAIT)')
R.advance(1);local again2,again2Why=S:Claim(A,rec1)
check(again2==false and again2Why=='LOCKED'and bag(A)==packsA+1 and addCalls==1,'and later too (it is taken today): no second pack')
prompt(rec1).Triggered:Fire(A);R.advance(1);prompt(rec1).Triggered:Fire(A)
check(bag(A)==packsA+1 and addCalls==1 and syncs(A)==syncBefore+1,'prompt spam adds nothing')
Data.AddChest=nil
-- 6. Saved with the profile -------------------------------------------------------------------------------------------
local save=Data:_buildSaveData(A)
local ms=save.Premium and save.Premium.Mystery
check(type(ms)=='table'and ms.Day==DAY0 and ms.Seconds==900 and ms.Stage==stageA and ms.Variant==variantA and ms.Claimed==true,'the save row has Premium.Mystery {Day, Seconds, Stage, Variant, Claimed}')
local plain=true;for k,v in pairs(ms or{})do local t=type(v);if k=='Owed'then
  if t~='table'then plain=false else for _,e in ipairs(v)do for _,x in pairs(e)do local xt=type(x);if not(xt=='number'or xt=='string')then plain=false end end end end
 elseif not(t=='number'or t=='string'or t=='boolean')then plain=false end end
check(plain and ms.Owed~=nil and#ms.Owed==0,'only plain values (DataStore safe; Owed is a list of {Day, Stage, Variant}, empty here)')
local P=server('PremiumProgress');local decoded=P.Decode(save.Premium)
check(decoded and decoded.Mystery and decoded.Mystery.Day==DAY0 and decoded.Mystery.Claimed==true and decoded.Mystery.Variant==variantA,'Premium.Decode keeps it')
local back=M.Read(decoded and decoded.Mystery)
check(back.Day==DAY0 and back.Seconds==900 and back.Stage==stageA and back.Variant==variantA and back.Claimed==true,'and it reads back exactly')
local brokenSave=table.clone(save.Premium);brokenSave.Mystery={Day='x',Seconds={},Stage=99,Variant=false,Claimed=1}
local bd=P.Decode(brokenSave);check(bd~=nil and M.Read(bd.Mystery).Day==-1 and not M.Unlocked(M.Read(bd.Mystery)),'a broken Mystery entry never stops the profile loading and pays nothing')
-- 7. Leaving and rejoining ----------------------------------------------------------------------------------------------
local function rejoin(p,rec)
 S:Leaving(p);present[p.UserId]=nil
 local saved=Data:FinalizePlayer(p,'PlayerRemoving')
 local q=R.new('Player');q.Name=p.Name;q.DisplayName=p.DisplayName;q.UserId=p.UserId;q.Parent=Players;present[p.UserId]=q;order[#order+1]=q
 function q.Kick(_,why)error('kicked '..p.Name..': '..tostring(why),0)end
 R.new('Backpack').Parent=q
 Data:PreparePlayer(q);assert(Data:Load(q),'reload '..p.Name);return q,saved
end
-- Ben has 780 s in; he leaves.
local benSeconds=Data:GetPremium(B).Mystery.Seconds
check(benSeconds==780,'(Ben has played 780 s: he joined 2 minutes after Ava)')
S:Leaving(B)
check(attr(rec2,'State')=='Empty'and attr(rec2,'OwnerUserId')==nil and attr(rec2,'OwnerName')==nil and attr(rec2,'UnlockAt')==nil and attr(rec2,'Variant')==nil,'Ben leaves: the pedestal goes Empty and loses his name / time / variant')
check(pack(rec2)==nil and S.Owner[B]==nil and S.Unsaved[B]==nil,'the pack is removed and the service forgets him')
check(litLook(rec2,'Empty')and bodyIs(rec2,nil),'[look] and his pedestal goes back to the cold look and the violet default colours')
local sBefore=Data:GetPremium(B).Mystery.Seconds;play(30)
check(Data:GetPremium(B).Mystery.Seconds==sBefore and attr(rec2,'State')=='Empty','time away does not count')
local leftClaim=S:Claim(B,rec2)
check(leftClaim==false,'nobody can take from an empty pedestal')
present[B.UserId]=nil
local B2,savedB=nil,nil
do
 local saved=Data:FinalizePlayer(B,'PlayerRemoving');savedB=saved
 R.advance(600) -- away for 10 minutes
 B2=R.new('Player');B2.Name='Ben';B2.DisplayName='Ben D';B2.UserId=702;B2.Parent=Players;present[702]=B2;order[#order+1]=B2
 function B2.Kick(_,why)error('kicked '..tostring(why),0)end
 R.new('Backpack').Parent=B2;Data:PreparePlayer(B2);assert(Data:Load(B2),'reload Ben')
end
check(savedB==true,'his profile saved on leaving')
local t2=math.floor(R.clock);S:Setup(B2)
check(Data:GetPremium(B2).Mystery.Seconds==benSeconds,'rejoining the same day keeps his seconds ('..tostring(Data:GetPremium(B2).Mystery.Seconds)..' of '..benSeconds..')')
check(attr(rec2,'State')=='Locked'and attr(rec2,'OwnerUserId')==702 and attr(rec2,'UnlockAt')==t2+900-benSeconds and pack(rec2)~=nil,'the pedestal is Locked again with the time that is left (UnlockAt = now + '..tostring(900-benSeconds)..' s)')
-- A treadmill upgrade before it unlocks: the biome follows the best treadmill, the Void pack forces stage 7.
Data:GetTreadmillData(B2).Tier=5
R.advance(1);S:Step(1)
check(attr(rec2,'Stage')==Config.TreadmillTiers[5].Stage and attr(rec2,'Stage')==4 and pack(rec2):GetAttribute('Stage')==4,'upgrading to the Magma treadmill changes the silhouette\'s biome (Lava, stage 4) while locked')
check(attr(rec2,'State')=='Locked'and attr(rec2,'Variant')==nil and Data:GetPremium(B2).Mystery.Seconds==benSeconds+1,'(and it counts on: still locked)')
S.Random={NextNumber=function()return .9995 end}
play(900-benSeconds-1)
check(attr(rec2,'State')=='Ready'and attr(rec2,'Variant')=='EclipseReliquary'and attr(rec2,'Stage')==7,'a 0.1% roll is the Void pack, forced to stage 7 though the treadmill is Lava')
check(pack(rec2):GetAttribute('BagVariant')=='EclipseReliquary'and pack(rec2):GetAttribute('Stage')==7,'and the pack on the pedestal is the Void pack')
check(prompt(rec2).Enabled==true and prompt(rec1).Enabled==false,'[prompt] Ben\'s pedestal is Ready: his prompt is on (Ava\'s taken one is off)')
local vBag=bag(B2);local bigB=Data:GetPackLuck(B2).Big
R.advance(1);prompt(rec2).Triggered:Fire(B2)
local vrec=Data:GetChestRecords(B2)[bag(B2)]
check(bag(B2)==vBag+1 and vrec.Stage==7 and vrec.BagVariant=='EclipseReliquary'and vrec.OddsVersion==Rules.OddsVersion,'Ben takes a Void pack (stage 7)')
check(Data:GetPackLuck(B2).Big==bigB and attr(rec2,'State')=='Claimed','a Void pack does not move the size pity (it never counts)')
check(prompt(rec2).Enabled==false,'[prompt] and off once he took it')
-- Rejoin after taking it: still taken, no second pack.
local A2,savedA=rejoin(A,rec1);local bagA=bag(A2)
check(savedA==true and bag(A2)==packsA+1,'Ava leaves and comes back: her profile has the Bag pack ('..bag(A2)..' packs)')
S:Setup(A2)
check(attr(rec1,'State')=='Claimed'and attr(rec1,'OwnerUserId')==701 and bag(A2)==bagA,'rejoining the same day: still taken today, no second pack')
check(Data:GetPremium(A2).Mystery.Claimed==true and Data:GetPremium(A2).Mystery.Day==DAY0,'(the saved state survived the full save and load)')
-- 8. A new UTC day -------------------------------------------------------------------------------------------------------
nextDay();local t3=math.floor(R.clock)
check(attr(rec1,'State')=='Locked'and attr(rec1,'Variant')==nil and attr(rec1,'Stage')==1 and attr(rec1,'NextAt')==(DAY0+2)*86400,'the next day: a fresh Locked pack and a new NextAt')
check(attr(rec1,'UnlockAt')==t3+900,'with a full 15 minutes to go (UnlockAt now + 900)')
local st8=Data:GetPremium(A2).Mystery
check(st8.Day==DAY0+1 and today()==DAY0+1 and st8.Claimed==false and st8.Stage==nil and st8.Seconds==1,'saved: the new day, not taken, nothing rolled, the clock restarted (1 s)')
check(bag(A2)==bagA,'a pack that was taken yesterday gives nothing again')
check(pack(rec1)~=nil and pack(rec1):GetAttribute('BagVariant')=='Pack01','a silhouette is back on the pedestal')
check(prompt(rec1).Enabled==false,'[prompt] the new day\'s locked pack: prompt off')
S.Random={NextNumber=function()return .1 end}
play(899)
check(attr(rec1,'State')=='Ready'and attr(rec1,'Variant')=='Pack02','a new day, a new pack after 900 s (Pack02 for the 0.1 draw)')
-- 9. Not taken: it goes into the Bag on the next day --------------------------------------------------------------------------
local carryStage,carryVariant=attr(rec1,'Stage'),attr(rec1,'Variant')
local bagC=bag(A2);local syncC=syncs(A2);local noteC=#shown+1
nextDay()
check(bag(A2)==bagC+1,'untaken yesterday: it goes into the Bag at midnight')
local crec=Data:GetChestRecords(A2)[bag(A2)]
check(crec and crec.Kind=='Pack'and crec.Stage==carryStage and crec.BagVariant==carryVariant and crec.OddsVersion==Rules.OddsVersion,'the very pack that was on the pedestal ('..tostring(carryVariant)..', stage '..tostring(carryStage)..')')
check(syncs(A2)==syncC+1,'SyncTools ran once for the carried pack')
local carryNotes=notes(A2,noteC)
check(#carryNotes==1 and carryNotes[1]:find('Yesterday',1,true)and carryNotes[1]:find('Bag',1,true),'with a notice: '..tostring(carryNotes[1]))
check(attr(rec1,'State')=='Locked'and attr(rec1,'Variant')==nil and Data:GetPremium(A2).Mystery.Claimed==false and Data:GetPremium(A2).Mystery.Day==DAY0+2,'and today\'s pack starts locked as normal')
-- Not unlocked yet when midnight comes: nothing carries.
play(300);local bagN=bag(A2)
nextDay()
check(bag(A2)==bagN and attr(rec1,'State')=='Locked'and Data:GetPremium(A2).Mystery.Seconds==1,'a pack that was still locked at midnight is simply replaced (no pack, 15 minutes again)')
-- Leaving while Ready, coming back days later: it is still given.
S.Random={NextNumber=function()return .5 end};play(899)
local carry2Variant=attr(rec1,'Variant');check(attr(rec1,'State')=='Ready'and carry2Variant=='Pack03','(Ready again)')
local A3=rejoin(A2,rec1);local bagR=bag(A3)
R.clock+=86400*3;S:Setup(A3)
check(bag(A3)==bagR+1 and Data:GetChestRecords(A3)[bag(A3)].BagVariant==carry2Variant and attr(rec1,'State')=='Locked'and Data:GetPremium(A3).Mystery.Day==today(),'left while Ready, back 3 days later: the pack is in the Bag and a new one is locked')
-- 10. A full Bag keeps it on the pedestal ------------------------------------------------------------------------------------------
S.Random={NextNumber=function()return .5 end};play(900)
check(attr(rec1,'State')=='Ready','(Ready again)')
local cap=Config.MaxSavedChests;Config.MaxSavedChests=bag(A3)
local syncF=syncs(A3);local noteF=#shown+1;local fullBag=bag(A3)
R.advance(1);local fok=S:Claim(A3,rec1)
check(fok==false and bag(A3)==fullBag and attr(rec1,'State')=='Ready'and syncs(A3)==syncF and Data:GetPremium(A3).Mystery.Claimed==false,'a full Bag: taking it is refused, it stays Ready on the pedestal')
local fn=notes(A3,noteF)
check(#fn==1 and fn[1]:find('FULL',1,true),'and the player is told why: '..tostring(fn[1]))
do local _,fullEntry=lastNote(A3)
check(fullEntry and fullEntry.Kind=='Denied','[denied] R150 review: that refusal is marked Denied (the client clicks the Denied cue; its orange colour and 🎒 prefix are not one of SimpleGameText\'s red keys): kind '..tostring(fullEntry and fullEntry.Kind))end
Config.MaxSavedChests=cap;R.advance(1);local took=S:Claim(A3,rec1)
check(took==true and bag(A3)==fullBag+1 and attr(rec1,'State')=='Claimed','after making room the same pack can be taken')
-- ...and across midnight: it is owed (kept), today's pack starts as normal.
nextDay();S.Random={NextNumber=function()return .5 end};play(899)
local fullStage,fullVariant=attr(rec1,'Stage'),attr(rec1,'Variant')
check(attr(rec1,'State')=='Ready'and fullVariant=='Pack03','(a new day, Ready again)')
check(prompt(rec1).Enabled==true,'[prompt] (Ready: the prompt is on)')
Config.MaxSavedChests=bag(A3);local bagBefore=bag(A3);noteF=#shown+1;syncF=syncs(A3)
nextDay();play(5)
local owedNow=Data:GetPremium(A3).Mystery
check(bag(A3)==bagBefore and attr(rec1,'State')=='Locked'and attr(rec1,'Variant')==nil and owedNow.Day==today()and owedNow.Claimed==false and owedNow.Stage==nil,'next day with a full Bag: nothing is lost or added, and today\'s pack starts fresh (Locked, nothing rolled)')
check(#owedNow.Owed==1 and owedNow.Owed[1].Day==today()-1 and owedNow.Owed[1].Variant==fullVariant and owedNow.Owed[1].Stage==fullStage,'yesterday\'s unlocked pack is on the saved owed list (the very pack: '..tostring(fullVariant)..', stage '..tostring(fullStage)..')')
check(owedNow.Seconds==6 and near(attr(rec1,'UnlockAt')-W.workspace:GetServerTimeNow(),894,1.01),'today\'s 15 minutes run: '..tostring(owedNow.Seconds)..' s counted, 894 s to go on the countdown')
local fn2=notes(A3,noteF)
check(#fn2==1 and fn2[1]:find('Make room',1,true)and fn2[1]:find('1 mystery pack waiting',1,true)and syncs(A3)==syncF,'the player is told once: '..tostring(fn2[1])..' (and the retries make no more noise)')
do local _,waitEntry=lastNote(A3)
check(waitEntry and waitEntry.Kind==nil,'[denied] R150 review: the "N packs waiting" reminder is not a refusal: no Denied cue ('..tostring(waitEntry and waitEntry.Kind)..')')end
check(prompt(rec1).Enabled==false,'[prompt] (locked again: off)')
Config.MaxSavedChests=cap
S:Step(1)
check(bag(A3)==bagBefore+1 and Data:GetChestRecords(A3)[bag(A3)].BagVariant==fullVariant and Data:GetChestRecords(A3)[bag(A3)].Stage==fullStage,'once there is room the owed pack goes into the Bag by itself')
check(#Data:GetPremium(A3).Mystery.Owed==0 and attr(rec1,'State')=='Locked'and Data:GetPremium(A3).Mystery.Claimed==false and Data:GetPremium(A3).Mystery.Day==today(),'and it leaves the list; today\'s pack goes on')
local fn3=notes(A3,noteF);check(#fn3==2 and fn3[2]:find('waiting',1,true)and fn3[2]:find('Mystery Pack',1,true)and fn3[2]:find('Rare',1,true),'with a notice: '..tostring(fn3[2]))
do local _,wentIn=lastNote(A3)
check(wentIn and wentIn.Kind==nil,'[denied] R150 review: and a pack that goes into the Bag is no refusal either')end
for _=1,5 do S:Step(1)end
check(bag(A3)==bagBefore+1,'and it is not given again')
-- The size pity reaches the mystery pack through {Luck=true}.
S.Random={NextNumber=function()return .5 end};play(899)
Data:LoadPackLuck(A3,{Big=29,Giant=0})
R.advance(1);local bagP=bag(A3);S:Claim(A3,rec1)
local prec=Data:GetChestRecords(A3)[bag(A3)]
check(bag(A3)==bagP+1 and prec.PackSize>=5 and Data:GetPackLuck(A3).Big==0,'the 30th regular pack in a row without a 5x+ is a big one (the pity is wired through the mystery pack: x'..tostring(prec.PackSize)..')')
-- 11. Heartbeat and hitches ------------------------------------------------------------------------------------------------------
nextDay()
local sec0=Data:GetPremium(A3).Mystery.Seconds
Run.Heartbeat:Fire(1.0)
check(Data:GetPremium(A3).Mystery.Seconds==sec0+1,'Heartbeat drives the clock (1 s per second, connected once)')
Run.Heartbeat:Fire(.4);check(Data:GetPremium(A3).Mystery.Seconds==sec0+1,'(0.4 s: not a second yet)')
Run.Heartbeat:Fire(.7);check(near(Data:GetPremium(A3).Mystery.Seconds,sec0+2.1,1e-9),'(0.4 + 0.7 s: counted together, 1.1 s)')
local sec1=Data:GetPremium(A3).Mystery.Seconds;Run.Heartbeat:Fire(30)
check(near(Data:GetPremium(A3).Mystery.Seconds,sec1+5,1e-9),'a 30 s server hitch credits at most 5 s')
-- 11b. [drift] UnlockAt follows the real countdown: left alone while the clock runs, written again when it drifts ------------------
do
 local m3=ped(rec1);S:Publish(A3,true)
 local writes=0;local conn=m3:GetAttributeChangedSignal('UnlockAt'):Connect(function()writes+=1 end)
 local function shown()return attr(rec1,'UnlockAt')-W.workspace:GetServerTimeNow()end
 local function left()return M.Left(Data:GetPremium(A3).Mystery)end
 local at0=attr(rec1,'UnlockAt')
 check(near(shown(),left(),1.01),'[drift] a forced publish: UnlockAt = now + time left ('..tostring(shown())..' s)')
 play(60)
 check(writes==0 and attr(rec1,'UnlockAt')==at0,'[drift] 60 s of normal play: UnlockAt is not written again (no attribute spam)')
 for _=1,2 do R.advance(2);S:Step(1)end -- (the clock moves 2 s, 1 s is counted: 1 s, then 2 s behind)
 check(writes==0 and near(shown(),left()-2,1.01),'[drift] up to 2 s behind: still not written (the countdown is '..tostring(left()-shown())..' s short)')
 R.advance(2);S:Step(1)
 check(writes==1 and near(shown(),left(),1.01),'[drift] more than 2 s behind: written once, and the countdown shows the time that is really left')
 local counted=Data:GetPremium(A3).Mystery.Seconds;writes=0
 R.advance(30);Run.Heartbeat:Fire(30) -- a 30 s server hitch: 5 s are counted
 check(near(Data:GetPremium(A3).Mystery.Seconds,counted+5,1e-9)and writes==1 and near(shown(),left(),1.01)and shown()>0,'[drift] after a 30 s hitch (5 s counted): UnlockAt is republished at once, so the countdown cannot reach 0:00 before the pack unlocks ('..tostring(shown())..' s left)')
 play(30)
 check(writes==1 and near(shown(),left(),1.01),'[drift] and it stays put again afterwards')
 conn:Disconnect()
end
-- 12. Unusual owners -------------------------------------------------------------------------------------------------------------
local C=makePlayer(703,'Cai')
S:Setup(C)
check(S.Owner[C]==nil and Data:GetPremium(C).Mystery==nil,'a player without a base gets no pedestal and nothing is saved')
S:Step(1);S:Step(1);check(true,'(Step ignores him)')
local D2=makePlayer(704,'Dan');local noPad={Index=9,Model=R.new('Model')};noPad.Model.Parent=W.workspace;baseOfUser[704]=noPad
local okNoPad=pcall(function()S:Setup(D2);S:Step(1);S:Leaving(D2)end)
check(okNoPad,'a base record without a Pad never raises an error')
local E=R.new('Player');E.Name='Eve';E.UserId=705;E.Parent=Players;baseOfUser[705]=rec2;Data:PreparePlayer(E)
S:Setup(E);check(S.Owner[E]==nil and not Data:IsLoaded(E),'Setup waits for the profile to load (nothing happens before)')
-- 13. The owner command `mystery` ---------------------------------------------------------------------------------------------------
local Owner=server('OwnerUpdateCommands82')
check(Owner.Actions.mystery==true,'"mystery" is a registered owner action')
local ctx={Data=Data,Chests=Chests,Chase={Mystery=S,IsPlayerBusy=function()return false end},Map={MapRoot=R.new('Folder')},Config=Config}
-- Use fresh Ava (A3) on rec1: start from a known state.
local okc,out=Owner.Execute(ctx,A3,'mystery',{'reset'})
check(okc and out:find('locked',1,true)and out:find('15:00 to go',1,true)and out:find('in their base',1,true),'mystery reset: '..tostring(out))
check(Data:GetPremium(A3).Mystery.Seconds==0 and attr(rec1,'State')=='Locked'and attr(rec1,'UnlockAt')==math.floor(R.clock)+900,'(a fresh locked pack, UnlockAt = now + 15 min)')
okc,out=Owner.Execute(ctx,A3,'mystery',{})
check(okc and out:find('locked',1,true)and out:find('15:00 to go',1,true),'mystery (no argument) only reports: '..tostring(out))
S.Random={NextNumber=function()return .8 end}
okc,out=Owner.Execute(ctx,A3,'mystery',{'ready'})
check(okc and out:find('locked',1,true)and out:find('0:03 to go',1,true),'mystery ready: 3 s to go: '..tostring(out))
play(2);check(attr(rec1,'State')=='Locked','(2 s later still locked)')
play(1)
check(attr(rec1,'State')=='Ready'and attr(rec1,'Variant')=='Pack04','(3 s later it unlocks: Pack04 for the 0.8 draw)')
okc,out=Owner.Execute(ctx,A3,'mystery',{})
check(okc and out:find('ready: Pack04 stage 1',1,true),'and the command reports it: '..tostring(out))
local bagO=bag(A3);R.advance(1);S:Claim(A3,rec1)
okc,out=Owner.Execute(ctx,A3,'mystery',{})
check(bag(A3)==bagO+1 and okc and out:find('taken today',1,true),'taken: '..tostring(out))
okc,out=Owner.Execute(ctx,A3,'mystery',{'ready'})
check(okc and out:find('locked',1,true)and out:find('0:03 to go',1,true)and attr(rec1,'State')=='Locked'and attr(rec1,'Variant')==nil,'mystery ready after taking it: a second pack on the same day (Claimed cleared)')
play(3);check(attr(rec1,'State')=='Ready','(unlocks again)')
-- `mystery ready` on a pack that is already unlocked and not taken: back to locked, the rarity secret again, then a new roll.
local oldVariant=attr(rec1,'Variant');S.Random={NextNumber=function()return .99 end}
okc,out=Owner.Execute(ctx,A3,'mystery',{'ready'})
check(okc and out:find('locked',1,true)and attr(rec1,'State')=='Locked'and attr(rec1,'Variant')==nil and attr(rec1,'UnlockAt')==math.floor(R.clock)+3,'mystery ready on an unlocked pack: Locked again, no variant published, UnlockAt in 3 s: '..tostring(out))
check(pack(rec1):GetAttribute('BagVariant')=='Pack01'and pack(rec1):GetAttribute('PackRarity')=='Common','(the pedestal shows the plain silhouette again, not the old rarity)')
play(3)
check(attr(rec1,'State')=='Ready'and attr(rec1,'Variant')=='Pack06'and oldVariant=='Pack04','and 3 s later it rolls again (Pack06 for the 0.99 draw; it was Pack04)')
S.Random={NextNumber=function()return .8 end}
local bagN2=bag(A3);syncF=syncs(A3)
okc,out=Owner.Execute(ctx,A3,'mystery',{'next'})
check(okc and out:find('locked',1,true)and bag(A3)==bagN2+1 and syncs(A3)==syncF+1,'mystery next: a new day: the untaken pack goes into the Bag and a new locked one starts: '..tostring(out))
check(Data:GetPremium(A3).Mystery.Day==today(),'(today\'s state)')
local nextDayState=Data:GetPremium(A3).Mystery
check(nextDayState.Claimed==false and nextDayState.Stage==nil and nextDayState.Seconds==0,'and its seconds start from 0')
local before2=Data:GetPremium(A3).Mystery.Day
play(10);okc,out=Owner.Execute(ctx,A3,'mystery',{'next'})
check(okc and Data:GetPremium(A3).Mystery.Day==before2 and bag(A3)==bagN2+1,'mystery next twice in a row (still Locked): no pack, still today')
play(1)
for _,bad in ipairs({{'foo'},{'ready','now'},{'next','@x'},{'12'}})do
 local sb=Data:GetPremium(A3).Mystery.Seconds;okc,out=Owner.Execute(ctx,A3,'mystery',bad)
 check(okc==false and out:find('Use mystery [ready|next|reset]',1,true)and Data:GetPremium(A3).Mystery.Seconds==sb,'mystery '..table.concat(bad,' ')..': usage message, nothing changed')
end
okc,out=Owner.Execute({Data=Data,Chests=Chests,Chase={},Map=ctx.Map,Config=Config},A3,'mystery',{})
check(okc==false and out:find('not running',1,true),'without the service: "not running"')
okc,out=Owner.Execute(ctx,C,'mystery',{})
check(okc and out:find('pedestal not assigned',1,true),'a player with no base: "pedestal not assigned": '..tostring(out))
okc,out=Owner.Execute(ctx,C,'mystery',{'ready'})
check(okc and Data:GetPremium(C).Mystery~=nil,'(and the command still works on his data)')
okc,out=Owner.Execute(ctx,C,'mystery',{'reset'})
check(okc and out:find('15:00 to go',1,true),'reset works for him too: '..tostring(out))

-- 14. Keeper speed tagging (the server half of KeeperSpeedLabels) ------------------------------------------------------------------
local Chase=server('ChaseService')
local fakeChase=setmetatable({},{__index=Chase})
local expected={[1]=20,[6]=32,[2]=50,[3]=80,[4]=128,[5]=205,[7]=330}
local tagOk=true;local detail=''
for stage=1,7 do
 local model=R.new('Model');model.Name='Keeper'..stage;model:SetAttribute('KeeperClientAnimated',true)
 local rootPart=R.new('Part');rootPart.Name='HumanoidRootPart';rootPart.Size=R.Vector3.new(2,2,1);rootPart.Parent=model
 local body=R.new('Part');body.Name='Body';body.Size=R.Vector3.new(3,5,2);body.Parent=model
 model.Parent=W.workspace
 local ok=Chase._preparePersistentGuardian(fakeChase,model,stage)
 local esc=model:GetAttribute('KeeperEscapeSpeed')
 if not(ok==true and esc==expected[stage]and esc==Pursuit.EscapeSpeed(stage)and W.CS:HasTag(model,'BiomeKeeper')and model:GetAttribute('Stage')==stage and model.PrimaryPart==rootPart)then tagOk=false;detail=detail..' stage '..stage..'='..tostring(esc)end
 -- preparing again (a respawn / adoption) keeps the same value and one tag
 Chase._preparePersistentGuardian(fakeChase,model,stage)
 if model:GetAttribute('KeeperEscapeSpeed')~=expected[stage]or not W.CS:HasTag(model,'BiomeKeeper')then tagOk=false;detail=detail..' re-prepare '..stage end
end
check(tagOk,'_preparePersistentGuardian stamps KeeperEscapeSpeed (20, 32, 50, 80, 128, 205, 330) and tags every biome keeper "BiomeKeeper"'..detail)
check(Pursuit.EscapeSpeed(8)==20 and Pursuit.EscapeSpeed(nil)==20 and Pursuit.EscapeSpeed(99)==20,'an unknown stage falls back to the Forest speed (20)')
local noRoot=R.new('Model');noRoot.Parent=W.workspace
check(Chase._preparePersistentGuardian(fakeChase,noRoot,1)==false and noRoot:GetAttribute('KeeperEscapeSpeed')==nil and not W.CS:HasTag(noRoot,'BiomeKeeper'),'a model with no parts is not tagged')
check(Chase._preparePersistentGuardian(fakeChase,nil,1)==false,'(nor nil)')
-- EscapeSpeed is the keeper's slowest chase speed: it never runs slower than this, and it speeds up when far behind.
local pursuitOk=true
for stage=1,7 do
 local escape=Pursuit.EscapeSpeed(stage);local prev=escape
 if Pursuit.Speed(nil,nil,0,stage)~=escape or Pursuit.Speed(nil,nil,35,stage)~=escape then pursuitOk=false end
 for gap=36,400,4 do local s=Pursuit.Speed(nil,nil,gap,stage);if s<prev-1e-9 or s<=escape-1e-9 then pursuitOk=false end;prev=s end
 if Pursuit.Speed(nil,nil,400,stage)<=escape then pursuitOk=false end
end
check(pursuitOk,'KeeperPursuit.Speed never drops below EscapeSpeed (flat up to 35 studs, then rising with the gap): a faster runner always pulls away')
local speedOk=true;for stage=1,7 do if Config.GetGuardianChaseSpeed({},500,5,stage,0)~=Pursuit.EscapeSpeed(stage)then speedOk=false end end
check(speedOk,'the real chase speed next to a runner (Config.GetGuardianChaseSpeed) is exactly the label\'s EscapeSpeed')
check(W.B.ConcurrentKeeperService:find('RouteBalance83).EventSpeed',1,true)~=nil,'The Darkened chases at RouteBalance83.EventSpeed (the 600 on its label)')
local seeds7=Balance.KeeperSpeeds
check(seeds7[1][1]==20 and seeds7[7][1]==330,'(the numbers come from BalanceValues81.KeeperSpeeds / RouteBalance83)')
-- The Darkened (VeiledEvent81).
local Veiled=server('VeiledEvent81')
local evFolder=R.new('Folder');evFolder.Name='VeiledFolder';evFolder.Parent=W.workspace
local eventSelf={Home=R.CFrame.new(0,5,0),Folder=evFolder}
local guardian=Veiled.EnsureGuardian(eventSelf)
check(guardian~=nil and guardian:GetAttribute('KeeperEscapeSpeed')==W.module('RouteBalance83').EventSpeed and guardian:GetAttribute('KeeperEscapeSpeed')==600,'The Darkened is stamped with its fixed speed (600)')
check(guardian and W.CS:HasTag(guardian,'BiomeKeeper'),'and tagged "BiomeKeeper"')
local again3=Veiled.EnsureGuardian(eventSelf)
check(again3==guardian,'EnsureGuardian reuses the live keeper')
guardian:Destroy();local g2=Veiled.EnsureGuardian(eventSelf)
check(g2~=nil and g2~=guardian and g2:GetAttribute('KeeperEscapeSpeed')==600 and W.CS:HasTag(g2,'BiomeKeeper'),'a new keeper after it despawns is stamped and tagged again')
check(Veiled.EnsureGuardian({Home=nil,Folder=evFolder})==nil,'(no Home: no keeper)')

-- 15. A full Bag at midnight: the unlocked pack is owed (saved), today's timer runs, nothing is lost or given twice -------------------
;(function() -- (a function of its own: the main chunk is out of local slots)
 local rec3=baseOf(3,R.CFrame.new(400,5,400));Map.BaseRecords[3]=rec3
 local Dee=makePlayer(706,'Dee');baseOfUser[706]=rec3
 local ROOM=Config.MaxSavedChests
 local PERSISTENT=R.Enum.ModelStreamingMode.Persistent
 local function owedOf(p)return Data:GetPremium(p).Mystery.Owed end
 local function owedKey(p)local t={};for _,e in ipairs(owedOf(p))do t[#t+1]=e.Variant end;return table.concat(t,',')end
 local function roll(u)S.Random={NextNumber=function()return u end}end
 local function readyBy(u)roll(u);local n=0;while attr(rec3,'State')~='Ready'and n<1000 do play(1);n+=1 end;return n<1000 end
 local function waiting(p,from)local n=0;for _,t in ipairs(notes(p,from))do if t:find('Make room',1,true)then n+=1 end end;return n end
 local function bagFrom(p,first)local t={};for i=first,bag(p)do local r=Data:GetChestRecords(p)[i];t[#t+1]=r.BagVariant..':'..r.Stage end;table.sort(t);return table.concat(t,' ')end
 roll(.5);S:Setup(Dee)
 check(ped(rec3)~=nil and ped(rec3).ModelStreamingMode==PERSISTENT and W.CS:HasTag(ped(rec3),'MysteryPedestal')and attr(rec3,'State')=='Locked'and prompt(rec3).Enabled==false,'[streaming] [prompt] a pedestal built after Start (for a base that was added later) is Persistent too, Locked with the prompt off')
 check(readyBy(.5)and attr(rec3,'Variant')=='Pack03'and prompt(rec3).Enabled==true,'[prompt] (Dee: Ready after 15 minutes, the prompt is on)')
 local gone=ped(rec3);gone:Destroy();S:Publish(Dee,true)
 check(ped(rec3)~=gone and ped(rec3).ModelStreamingMode==PERSISTENT and attr(rec3,'State')=='Ready'and attr(rec3,'OwnerUserId')==706 and prompt(rec3).Enabled==true and pack(rec3)~=nil,'[streaming] [prompt] a pedestal that was destroyed and rebuilt while Ready: Persistent, the owner, the real pack, prompt on straight away')
 local bag0=bag(Dee);Config.MaxSavedChests=bag0;local from1=#shown+1;local sync0=syncs(Dee)
 -- Day 1: midnight comes with an unlocked pack and a full Bag.
 nextDay();play(5)
 local d1=Data:GetPremium(Dee).Mystery
 check(bag(Dee)==bag0 and syncs(Dee)==sync0,'[owed] a full Bag at midnight with an unlocked pack: nothing is added (and nothing is lost: see below)')
 check(#d1.Owed==1 and owedKey(Dee)=='Pack03'and d1.Owed[1].Stage==1 and d1.Owed[1].Day==today()-1,'[owed] the very pack is on the saved owed list (Pack03, Forest, from yesterday)')
 check(d1.Day==today()and d1.Claimed==false and d1.Stage==nil and d1.Seconds==6 and attr(rec3,'State')=='Locked'and near(attr(rec3,'UnlockAt')-W.workspace:GetServerTimeNow(),894,1.01),'[owed] today starts fresh and its 15 minutes run: 6 s counted, 894 s on the countdown (the old pack no longer blocks it)')
 check(prompt(rec3).Enabled==false and pack(rec3)~=nil and pack(rec3):GetAttribute('BagVariant')=='Pack01','[prompt] the pedestal is a locked silhouette again, prompt off')
 local n1=notes(Dee,from1)
 check(#n1==1 and n1[1]:find('Make room: 1 mystery pack waiting',1,true),'[owed] the player is told once: '..tostring(n1[1]))
 -- Days 2 and 3: the same again; the list grows oldest first.
 check(readyBy(.8)and attr(rec3,'Variant')=='Pack04','(day 2: Ready, Pack04)')
 nextDay();play(1)
 check(owedKey(Dee)=='Pack03,Pack04'and bag(Dee)==bag0 and Data:GetPremium(Dee).Mystery.Seconds==2,'[owed] day 2: two owed, oldest first, and today\'s clock is running')
 check(readyBy(.1)and attr(rec3,'Variant')=='Pack02','(day 3: Ready, Pack02)')
 nextDay();play(1)
 check(owedKey(Dee)=='Pack03,Pack04,Pack02'and bag(Dee)==bag0,'[owed] day 3: three owed (the cap)')
 check(waiting(Dee,from1)==1,'[owed] no more notices: told once this session, not once a day')
 -- Day 4: three are already owed: the fourth pack is not dropped, it stays on the pedestal.
 check(readyBy(.99)and attr(rec3,'Variant')=='Pack06','(day 4: Ready, Pack06)')
 nextDay();play(3)
 local stuck=Data:GetPremium(Dee).Mystery
 check(owedKey(Dee)=='Pack03,Pack04,Pack02'and bag(Dee)==bag0 and stuck.Day==today()-1 and stuck.Claimed==false and M.Unlocked(stuck)and stuck.Variant=='Pack06'and attr(rec3,'State')=='Ready'and attr(rec3,'Variant')=='Pack06','[owed] with 3 already owed and a full Bag, a fourth pack is never dropped: it stays Ready on the pedestal (the owed list is capped at 3)')
 R.advance(1);local refusedTake=S:Claim(Dee,rec3)
 check(refusedTake==false and bag(Dee)==bag0 and owedKey(Dee)=='Pack03,Pack04,Pack02'and waiting(Dee,from1)==1,'[owed] taking it with a full Bag is refused as before; nothing changes')
 -- Leaving and coming back (saved and loaded): the owed list survives, nothing is added to a full Bag.
 local Dee2=rejoin(Dee,rec3)
 check(attr(rec3,'State')=='Empty'and attr(rec3,'OwnerUserId')==nil and prompt(rec3).Enabled==false and pack(rec3)==nil,'[prompt] Dee leaves while her pack is Ready: the pedestal goes Empty and the server turns the prompt off')
 check(owedKey(Dee2)=='Pack03,Pack04,Pack02'and bag(Dee2)==bag0,'[owed] saved and loaded with the profile: the same 3 owed packs in the same order, nothing added')
 local sv=Data:_buildSaveData(Dee2).Premium.Mystery
 check(type(sv.Owed)=='table'and#sv.Owed==3 and sv.Owed[1].Variant=='Pack03'and sv.Owed[1].Stage==1 and type(sv.Owed[1].Day)=='number'and sv.Owed[3].Variant=='Pack02','[owed] the save row holds Owed = {{Day, Stage, Variant}, ...}')
 local from2=#shown+1;S:Setup(Dee2);play(2)
 check(waiting(Dee2,from2)==1 and lastNote(Dee2):find('3 mystery packs waiting',1,true),'[owed] a new session: told once more ('..tostring(lastNote(Dee2))..')')
 check(attr(rec3,'State')=='Ready'and attr(rec3,'Variant')=='Pack06'and bag(Dee2)==bag0,'(the pack that stayed on the pedestal is back, Ready)')
 -- Room for one: exactly one pack goes in.
 Config.MaxSavedChests=bag0+1;play(1)
 local pend=#owedOf(Dee2)+(attr(rec3,'State')=='Ready'and 1 or 0)
 check(bag(Dee2)==bag0+1 and pend==3 and waiting(Dee2,from2)==1,'[owed] room for one pack: exactly one goes in (3 are still waiting), no new notice')
 local Dee3=rejoin(Dee2,rec3)
 check(bag(Dee3)==bag0+1 and #owedOf(Dee3)==#owedOf(Dee2)and#owedOf(Dee3)>=2,'[owed] saved and loaded again: no pack is repeated, none is lost')
 -- Room for two more at Setup: they go in as the player arrives.
 Config.MaxSavedChests=bag(Dee3)+2;local waitingBefore=#owedOf(Dee3);S:Setup(Dee3)
 check(bag(Dee3)==bag0+3 and #owedOf(Dee3)==math.max(0,waitingBefore-2),'[owed] Setup grants owed packs when there is room (2 more)')
 -- A claim of today's pack with room for two: today's and the last owed one.
 check(readyBy(.5)and attr(rec3,'Variant')=='Pack03','(Ready again)')
 Config.MaxSavedChests=bag(Dee3)+2;R.advance(1)
 local pendingNow=#owedOf(Dee3);local tookIt=S:Claim(Dee3,rec3)
 check(tookIt==true and bag(Dee3)==bag0+3+1+pendingNow and #owedOf(Dee3)==0,'[owed] taking today\'s pack also pays the owed one that was waiting ('..tostring(bag(Dee3)-bag0)..' packs in all)')
 for _=1,10 do play(1)end
 local expected={'Pack02:1','Pack03:1','Pack03:1','Pack04:1','Pack06:1'};table.sort(expected)
 check(bag(Dee3)==bag0+5 and bagFrom(Dee3,bag0+1)==table.concat(expected,' '),'[owed] in the end: exactly the 5 packs Dee earned (4 days of Pack03 / Pack04 / Pack02 / Pack06 + today\'s Pack03), each once: '..bagFrom(Dee3,bag0+1))
 local Dee4=rejoin(Dee3,rec3);Config.MaxSavedChests=ROOM;S:Setup(Dee4);play(5)
 check(bag(Dee4)==bag0+5 and #owedOf(Dee4)==0 and attr(rec3,'State')=='Claimed','[owed] after a save and load: nothing more is given (still 5, nothing owed, today\'s taken)')
 -- A save from before Owed existed, with an unlocked pack from yesterday and a full Bag.
 Config.MaxSavedChests=bag(Dee4)
 Data:GetPremium(Dee4).Mystery={Day=today()-1,Seconds=900,Stage=2,Variant='Pack05',Claimed=false}
 play(1)
 check(owedKey(Dee4)=='Pack05'and bag(Dee4)==bag0+5 and Data:GetPremium(Dee4).Mystery.Day==today()and attr(rec3,'State')=='Locked','[owed] an old-shape save (no Owed) with an unlocked pack and a full Bag loads fine: the pack is owed, today starts')
 Config.MaxSavedChests=ROOM;play(1)
 local last=Data:GetChestRecords(Dee4)[bag(Dee4)]
 check(bag(Dee4)==bag0+6 and last.BagVariant=='Pack05'and last.Stage==2 and #owedOf(Dee4)==0,'[owed] and it goes in when there is room')
 -- Odd data never pays out; a long list keeps the oldest 3.
 local bagJ=bag(Dee4);local secJ=Data:GetPremium(Dee4).Mystery.Seconds
 Data:GetPremium(Dee4).Mystery={Day=today(),Seconds=secJ,Owed={{Day=1,Stage=99,Variant='Pack03'},{Day=2,Stage=2,Variant='Nope'},'x',5,{Day=3,Stage=3,Variant='Pack01'},{Day=4,Stage=3,Variant='EclipseReliquary',Extra='x'}}}
 play(2)
 check(bag(Dee4)==bagJ+1 and Data:GetChestRecords(Dee4)[bag(Dee4)].BagVariant=='EclipseReliquary'and #owedOf(Dee4)==0 and Data:GetPremium(Dee4).Mystery.Seconds>=secJ+2,'[owed] odd owed entries (stage 99, a made-up variant, Common, not tables) never pay out: only the one good entry did')
 local bagK=bag(Dee4)
 Data:GetPremium(Dee4).Mystery={Day=today(),Seconds=5,Owed={{Day=1,Stage=2,Variant='Pack02'},{Day=2,Stage=3,Variant='Pack03'},{Day=3,Stage=4,Variant='Pack04'},{Day=4,Stage=5,Variant='Pack05'},{Day=5,Stage=6,Variant='Pack06'}}}
 play(1)
 check(bag(Dee4)==bagK+3 and bagFrom(Dee4,bagK+1)=='Pack02:2 Pack03:3 Pack04:4','[owed] a saved list longer than 3 pays only the 3 oldest ('..bagFrom(Dee4,bagK+1)..')')
 -- The owner command with an owed pack.
 Config.MaxSavedChests=bag(Dee4);local bagO2=bag(Dee4)
 local okc,out=Owner.Execute(ctx,Dee4,'mystery',{'ready'})
 play(3)
 check(attr(rec3,'State')=='Ready','(mystery ready: unlocked)')
 okc,out=Owner.Execute(ctx,Dee4,'mystery',{'next'})
 check(okc and out:find('locked',1,true)and out:find('1 owed',1,true)and #owedOf(Dee4)==1 and bag(Dee4)==bagO2,'[owed] mystery next with a full Bag: the pack is owed and the command says so: '..tostring(out))
 okc,out=Owner.Execute(ctx,Dee4,'mystery',{'reset'})
 check(okc and out:find('15:00 to go',1,true)and out:find('1 owed',1,true)and #owedOf(Dee4)==1 and Data:GetPremium(Dee4).Mystery.Seconds==0,'[owed] mystery reset restarts today\'s pack but keeps the owed one: '..tostring(out))
 okc,out=Owner.Execute(ctx,Dee4,'mystery',{})
 check(okc and out:find('1 owed',1,true),'mystery (no argument) reports it too')
 Config.MaxSavedChests=ROOM;play(1)
 check(bag(Dee4)==bagO2+1 and #owedOf(Dee4)==0,'(and it goes in when there is room)')
 okc,out=Owner.Execute(ctx,Dee4,'mystery',{})
 check(okc and not out:find('owed',1,true),'with nothing owed the command says nothing about it')
 Config.MaxSavedChests=ROOM
end)()

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
