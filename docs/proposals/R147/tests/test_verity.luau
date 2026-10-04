--!nocheck
-- R147 (owner: "Verity NPC is a quest giver: it tells players to steal a pack from The Darkened one and give it to the
-- Verity NPC. The Verity NPC will be behind the market and it will be big."; reward = one Verity pack per Void pack
-- handed in, repeatable, no daily cap): the real VerityService, VerityConfig, SecurityGate and PlayerDataService
-- (records, premium save / load) on the mock. ChestService:ConvertVoidPack (built by another coder) is a stub that swaps
-- the Void record for a Verity record in place and syncs the Tools, like its contract; ChestService.Openings is a plain
-- table. Covers: the model built at her spot with every part, the Open message (with / without The Darkened's schedule),
-- a successful hand-in (exactly one Void record and its Tool consumed, one Verity pack, Count saved / loaded), the pick
-- order (equipped Void tool, else the oldest), and every refusal: no Void pack, too far, no body, carrying / running /
-- queued / ragdolled, mid-opening, rate-limited spam, data not loaded / not saving, ConvertVoidPack missing, failing or
-- throwing (everything unchanged), plus a few hostile remote calls.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
-- Every message the server sends to a client.
local sent={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function(_,p,...)sent[#sent+1]={P=p,Args={...}}end end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 return o end end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=mapRoot
local Config=server('Config');local C=W.module('VerityConfig');local Gate=server('SecurityGate')
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end,MapRoot=mapRoot,EconomyHub=hub}
local shown={}
local Notes={Show=function(_,p,text)shown[#shown+1]={P=p,Text=text}end}
local Data=server('PlayerDataService').new(Config,Map,Notes)
R.clock=20000*86400+3600
local VOID='EclipseReliquary';local VERITY='VerityReliquary'
-- The placeholder the installer retires: must be left alone.
local placeholder=R.new('Part');placeholder.Name='Verity';placeholder.Parent=W.workspace;placeholder.Color=R.Color3.new(1,0,0)
-- The chest service: Openings, a tiny SyncTools and the ConvertVoidPack stub (the real one is another coder's).
local convertCalls,convertMode,syncCalls={},nil,0
local Chests={Openings={}}
local function toolFor(record,parent)
 local t=R.new('Tool');t.Name=record.Id;t:SetAttribute('SeedPackTool',true);t:SetAttribute('SeedInventoryId',record.Id);t:SetAttribute('BagVariant',record.BagVariant);t:SetAttribute('Stage',record.Stage);t.Parent=parent;return t
end
function Chests:SyncTools(player)
 syncCalls+=1
 local ids={};for _,r in ipairs(Data:GetChestRecords(player))do ids[r.Id]=r end
 local seen={};local bag=player:FindFirstChildOfClass('Backpack')
 for _,container in ipairs({bag,player.Character})do if container then for _,t in ipairs(container:GetChildren())do
  if t:IsA('Tool')and t:GetAttribute('SeedPackTool')then local id=t:GetAttribute('SeedInventoryId');if not ids[id]or seen[id]then t:Destroy()else seen[id]=true end end
 end end end
 for _,r in ipairs(Data:GetChestRecords(player))do if not seen[r.Id]then toolFor(r,bag)end end
end
function Chests:ConvertVoidPack(player,id)
 convertCalls[#convertCalls+1]={Player=player,Id=id}
 if convertMode=='fail'then return nil,'THE BAG COULD NOT TAKE IT'end
 if convertMode=='failsilently'then return nil end
 if convertMode=='throw'then error('boom')end
 local records=Data:GetChestRecords(player)
 for i,r in ipairs(records)do
  if r.Id==id and r.Kind=='Pack'and r.BagVariant==VOID then
   local serial=(player:GetAttribute('ChestInventorySerial')or 0)+1;player:SetAttribute('ChestInventorySerial',serial)
   local new={Id=string.format('%d_%d',player.UserId,serial),ChestNumber=serial,ChestName='Seed Pack',Kind='Pack',Stage=7,AccentColor=r.AccentColor,BagVariant=VERITY,OddsVersion=r.OddsVersion,
    PackSize=r.PackSize,PackMutation=r.PackMutation,Weather=r.Weather,SeedScale=r.SeedScale}
   records[i]=new;Data:_notifySeedInventory(player);self:SyncTools(player) -- (no MarkDirty here: the Count is VerityService's own change to save)
   if convertMode=='convertthenthrow'then error('late boom')end
   return new
  end
 end
 return nil,'THAT IS NOT A VOID PACK'
end
-- Players ----------------------------------------------------------------------------------------------------------
local nextId=600
local function makePlayer(name)
 nextId+=1;local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=nextId;p.Parent=Players;present[nextId]=p;order[#order+1]=p
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local STAND=R.Vector3.new(0,7,-200)
local function spawn(p,x,y,z)
 local c=R.new('Model');c.Name=p.Name;local h=R.new('Humanoid');h.Name='Humanoid';h.Health=100;h.Parent=c
 local r=R.new('Part');r.Name='HumanoidRootPart';r.CFrame=R.CFrame.new(x or STAND.X,y or STAND.Y,z or STAND.Z);r.Parent=c;c.Parent=W.workspace;p.Character=c;return c,r
end
local function addPack(p,variant,stage)
 local rec=Data:AddChest(p,{Stage=stage or(variant==VOID and 7 or 1),BagVariant=variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=81})
 assert(rec,'AddChest '..variant);return rec
end
local function void(p,n)local out={};for _=1,n or 1 do out[#out+1]=addPack(p,VOID)end;return out end
local function bag(p)return p:FindFirstChildOfClass('Backpack')end
local function hasTool(p,id)for _,c in ipairs({bag(p),p.Character})do if c and c:FindFirstChild(id)then return true end end;return false end
local function snapshot(p)
 local rows={};for i,r in ipairs(Data:GetChestRecords(p))do rows[i]=r end;return rows
end
local function same(a,b)if #a~=#b then return false end;for i=1,#a do if a[i]~=b[i]then return false end end;return true end
local function count(p,variant)local n=0;for _,r in ipairs(Data:GetChestRecords(p))do if r.BagVariant==variant and r.Kind=='Pack'then n+=1 end end;return n end
local function inbox(p)local out={};for _,m in ipairs(sent)do if m.P==p then out[#out+1]=m end end;return out end
local function last(p)local box=inbox(p);return box[#box]end
local function msgs(p,kind)local n=0;for _,m in ipairs(inbox(p))do if m.Args[1]==kind then n+=1 end end;return n end
local Verity=server('VerityService')
local service=Verity.new(Config,Data,Chests,Notes,Map)
-- 1. The numbers and the gate -------------------------------------------------------------------------------------------
check(C.Image=='rbxassetid://102712963740896','the owner\'s Verity picture');
check(C.Position==R.Vector3.new(0,4,-222)and C.Facing==R.Vector3.new(0,0,1),'behind the market at (0, 4, -222), facing +Z')
check(C.CardWidth==24 and C.CardHeight==34 and C.FootOffset~=nil,'CardWidth 24 / CardHeight 34 / FootOffset exposed to tune')
check(C.Quest=='Steal a Void Pack from The Darkened One at the end of Storm Peaks and bring it to me. I\'ll give you a Verity Pack!','the quest text')
check(C.GiveDistance==30 and C.PromptDistance==20 and C.VoidVariant==VOID,'30 stud hand-in range, 20 stud prompt, Void = EclipseReliquary')
local gateSrc=W.B.SecurityGate
check(gateSrc:find('VerityTalk={Rate=1,Burst=3}',1,true)and gateSrc:find('VerityGive={Rate=1,Burst=2}',1,true),'SecurityGate has the VerityTalk and VerityGive policies')
-- 2. Start builds her ------------------------------------------------------------------------------------------------------
check(hub:FindFirstChild('VerityNPC')==nil and remotes:FindFirstChild('VerityQuest')==nil,'nothing exists before Start')
check(service:Start()==service,'Start returns the service')
local model=hub:FindFirstChild('VerityNPC')
check(model and model:IsA('Model')and model.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent,'workspace.ChestChaseMap.EconomyHub.VerityNPC, a Persistent Model')
check(model and W.CS:HasTag(model,'VerityNPC')and model:GetAttribute('VerityNPC')==C.Version,'tagged VerityNPC for the client')
local remote=remotes:FindFirstChild('VerityQuest')
check(remote and remote:IsA('RemoteEvent'),'ChestChaseRemotes.VerityQuest is a RemoteEvent')
local dais=model:FindFirstChild('Dais');local pillar=model:FindFirstChild('Collision');local card=model:FindFirstChild('Card')
check(dais and dais.Shape==R.Enum.PartType.Cylinder and dais.Size.Y==16 and dais.Size.Z==16 and dais.Size.X==1.2 and dais.CanCollide==true and dais.Anchored,'the dais: a solid stone cylinder, diameter 16, 1.2 high')
check(dais and dais.Position.X==0 and dais.Position.Z==-222 and math.abs(dais.Position.Y-4.6)<1e-6,'standing on the floor at (0, 4, -222)')
check(model:FindFirstChild('Dais rim')and model:FindFirstChild('Inlay'),'with a gold rim and an inlay')
check(pillar and pillar.Size.X==14 and pillar.Size.Y==7 and pillar.Size.Z==7 and pillar.CanCollide==true and pillar.Transparency==1 and pillar.Shape==R.Enum.PartType.Cylinder,'the invisible collision pillar: diameter 7, 14 high, solid')
check(pillar and pillar.Position.X==0 and pillar.Position.Z==-222 and math.abs(pillar.Position.Y-(5.2+7))<1e-6,'at her feet (on top of the dais)')
check(card and card.Size.X==24 and card.Size.Y==34 and not card.CanCollide and card.Anchored,'the card: 24 x 34, not solid')
check(card and math.abs(card.Position.Y+card.Size.Y/2-39.2)<1e-6 and math.abs(card.Position.Y-card.Size.Y/2-5.2)<1e-6,'its top is at y 39.2 (over the market roof) and it stands on the dais')
check(card and card.Position.X==0 and card.Position.Z==-222,'centred on her spot')
local look=card and card.CFrame.LookVector
check(look and math.abs(look.X)<1e-6 and math.abs(look.Z-1)<1e-6,'its front faces +Z')
for _,spec in ipairs({{'FrontPicture',R.Enum.NormalId.Front},{'BackPicture',R.Enum.NormalId.Back}})do
 local gui=card and card:FindFirstChild(spec[1]);local image=gui and gui:FindFirstChild('Picture')
 check(gui and gui:IsA('SurfaceGui')and gui.Face==spec[2]and gui.LightInfluence==.2,spec[1]..': a SurfaceGui on that face, LightInfluence .2')
 check(image and image:IsA('ImageLabel')and image.Image=='rbxassetid://102712963740896'and image.ScaleType==R.Enum.ScaleType.Fit and image.BackgroundTransparency==1,spec[1]..': the picture, ScaleType Fit')
end
local ring=model:FindFirstChild('Glow ring');local light=ring and ring:FindFirstChild('Glow')
check(ring and ring.Material==R.Enum.Material.Neon and light and light:IsA('PointLight'),'a neon ring with a PointLight')
local sign=card and card:FindFirstChild('NameSign');local nameLabel=sign and sign:FindFirstChild('Name')
check(sign and sign:IsA('BillboardGui')and nameLabel and nameLabel.Text=='VERITY','a VERITY name sign (BillboardGui)')
local prompt=model:FindFirstChild('Talk',true)
check(prompt and prompt:IsA('ProximityPrompt')and prompt.ActionText=='Talk'and prompt.HoldDuration==0 and prompt.MaxActivationDistance==20 and prompt.RequiresLineOfSight==false and prompt.Enabled,'ProximityPrompt "Talk": hold 0, 20 studs, no line of sight needed')
check(placeholder.Parent==W.workspace and placeholder.Color.R==1,'the old workspace.Verity placeholder is left alone')
-- Start twice: still one of everything, and one handler.
service:Start()
local models,remoteCount=0,0
for _,c in ipairs(hub:GetChildren())do if c.Name=='VerityNPC'then models+=1 end end
for _,c in ipairs(remotes:GetChildren())do if c.Name=='VerityQuest'then remoteCount+=1 end end
check(models==1 and remoteCount==1 and hub:FindFirstChild('VerityNPC')==model and service.Remote==remote,'Start is idempotent: one model, one remote')
-- MapService binds WalkthroughProps90 (everything under EconomyHub turns walk-through): she stays solid, the rest does not.
do
 local Walk=W.module('WalkthroughProps90');Walk.Apply(mapRoot)
 R.advance(.1)
 check(dais.CanCollide==true and pillar.CanCollide==true,'WalkthroughProps90 (applied to the whole map) cannot make the dais or the pillar walk-through')
 check(card.CanCollide==false and ring.CanCollide==false,'(the other parts stay decor)')
end
-- 3. Talking: the Open message ---------------------------------------------------------------------------------------------
local A=makePlayer('Ava');spawn(A)
local aVoid=void(A,2);local aPlain=addPack(A,'Pack01',1)
for _,rec in ipairs(Data:GetChestRecords(A))do toolFor(rec,bag(A))end
mapRoot:SetAttribute('VeiledEventActive',false);mapRoot:SetAttribute('VeiledNextAt',R.clock+600)
prompt.Triggered:Fire(A)
local m=last(A)
check(m and m.Args[1]=='Open'and m.Args[2].VoidPacks==2 and m.Args[2].Delivered==0 and m.Args[2].RewardText==C.RewardText,'the prompt sends Open {VoidPacks = 2, Delivered = 0, RewardText}')
check(m and m.Args[2].EventActive==false and m.Args[2].NextAt==R.clock+600,'with The Darkened away: EventActive false and NextAt (server time)')
mapRoot:SetAttribute('VeiledEventActive',true);mapRoot:SetAttribute('VeiledNextAt',nil)
R.advance(2);prompt.Triggered:Fire(A);m=last(A)
check(m.Args[2].EventActive==true and m.Args[2].NextAt==nil,'while The Darkened is here: EventActive true, no NextAt')
R.advance(2);mapRoot:SetAttribute('VeiledEventActive',nil);mapRoot:SetAttribute('VeiledNextAt',R.clock+99)
prompt.Triggered:Fire(A);m=last(A)
check(m.Args[2].EventActive==nil and m.Args[2].NextAt==R.clock+99,'EventActive is left out when the map does not say; NextAt still sent')
mapRoot:SetAttribute('VeiledNextAt',nil);R.advance(2);prompt.Triggered:Fire(A);m=last(A)
check(m.Args[2].EventActive==nil and m.Args[2].NextAt==nil,'both left out when unknown')
-- Talk is rate limited (VerityTalk burst 3).
do
 local T=makePlayer('Tess');spawn(T);local before=#inbox(T)
 for _=1,8 do prompt.Triggered:Fire(T)end
 check(#inbox(T)-before==3,'talking is rate limited: 8 quick prompts, only the burst of 3 answered ('..(#inbox(T)-before)..')')
 R.advance(1.1);prompt.Triggered:Fire(T);check(#inbox(T)-before==4,'and it refills with time')
 local L=makePlayer('Lia');Data.Loaded[L]=false;prompt.Triggered:Fire(L)
 local lm=last(L);check(lm and lm.Args[1]=='Refused'and lm.Args[2].Reason==C.Reasons.Loading,'Open before the data loaded is refused')
end
-- 4. A successful hand-in -----------------------------------------------------------------------------------------------------
do
 mapRoot:SetAttribute('VeiledEventActive',false)
 local records=snapshot(A);local oldest=aVoid[1];local newer=aVoid[2]
 local revision=Data.Revision[A];local beforeSync=syncCalls
 local okFlag,newRecord=service:Give(A)
 check(okFlag==true and newRecord and newRecord.BagVariant==VERITY and newRecord.Kind=='Pack','Give returns the new Verity record')
 check(#convertCalls==1 and convertCalls[1].Id==oldest.Id and convertCalls[1].Player==A,'ConvertVoidPack was called once, for the oldest Void pack (nothing held)')
 check(count(A,VOID)==1 and count(A,VERITY)==1 and count(A,'Pack01')==1 and #Data:GetChestRecords(A)==3,'exactly one Void record consumed and one Verity pack added; the plain pack is untouched')
 local after=Data:GetChestRecords(A)
 check(after[1]==newRecord and after[2]==newer and after[3]==aPlain,'the Verity pack took the Void pack\'s slot (same position)')
 check(not hasTool(A,oldest.Id)and hasTool(A,newRecord.Id)and hasTool(A,newer.Id)and hasTool(A,aPlain.Id),'its Tool is gone, the Verity Tool exists, the others are unchanged')
 check(Data:GetPremium(A).Verity.Count==1 and service:Delivered(A)==1,'Premium.Verity.Count = 1')
 check(Data.Revision[A]>revision and Data.Dirty[A]==true,'the profile is marked dirty')
 check(Data.GardenSaveQueued[A]~=nil,'and a save is queued')
 local done=last(A)
 check(done.Args[1]=='Done'and done.Args[2].Delivered==1 and done.Args[2].RecordId==newRecord.Id and msgs(A,'Done')==1,'Done {Delivered = 1, RecordId = the new pack}')
 local told=false;for _,s in ipairs(shown)do if s.P==A and s.Text=='🌟 Verity gave you a Verity Pack!'then told=true end end
 check(told,'the notification: "🌟 Verity gave you a Verity Pack!"')
 -- Saved and loaded.
 local save=Data:_buildSaveData(A)
 check(save.Premium and type(save.Premium.Verity)=='table'and save.Premium.Verity.Count==1,'the count is in the save data')
 local decoded=server('PremiumProgress').Decode(save.Premium)
 check(decoded and type(decoded.Verity)=='table'and decoded.Verity.Count==1,'and decodes back with the profile')
 -- Open now says Delivered 1 and one Void pack left.
 R.advance(1);prompt.Triggered:Fire(A);local o=last(A)
 check(o.Args[1]=='Open'and o.Args[2].VoidPacks==1 and o.Args[2].Delivered==1,'Open afterwards: 1 Void pack left, 1 delivered')
end
-- Pick order: the equipped Void Tool wins over the oldest.
do
 local B=makePlayer('Ben');spawn(B);local v=void(B,3);for _,rec in ipairs(Data:GetChestRecords(B))do toolFor(rec,bag(B))end
 bag(B)[v[3].Id].Parent=B.Character -- the newest is in his hands
 convertCalls={};local ok,new=service:Give(B)
 check(ok and convertCalls[1].Id==v[3].Id,'holding a Void pack: that one is handed in (not the oldest)')
 local r=Data:GetChestRecords(B)
 check(r[1]==v[1]and r[2]==v[2]and r[3]==new and not hasTool(B,v[3].Id)and hasTool(B,new.Id),'the held pack is replaced in place and its Tool is gone')
 R.advance(1.2);convertCalls={};ok=service:Give(B)
 check(ok and convertCalls[1].Id==v[1].Id,'then the oldest (nothing held any more)')
 -- A held pack that is not Void does not count as "equipped Void".
 local plain=addPack(B,'Pack01',1);local t=toolFor(plain,B.Character)
 R.advance(1.2);convertCalls={};ok=service:Give(B)
 check(ok and convertCalls[1].Id==v[2].Id,'holding a plain pack: the Void pack in the Bag is handed in')
 -- Oldest by pack number, whatever the list order says.
 local C2=makePlayer('Cleo');spawn(C2);local c2=void(C2,3);c2[1].ChestNumber=30;c2[2].ChestNumber=10;c2[3].ChestNumber=20
 convertCalls={};service:Give(C2);check(convertCalls[1].Id==c2[2].Id,'the oldest is the lowest pack number ('..tostring(convertCalls[1].Id)..')')
 -- A Void Tool whose record is gone (stale) falls back to the oldest record.
 local D2=makePlayer('Dov');spawn(D2);local d2=void(D2,2);local ghost=R.new('Tool');ghost:SetAttribute('SeedPackTool',true);ghost:SetAttribute('BagVariant',VOID);ghost:SetAttribute('SeedInventoryId','ghost');ghost.Parent=D2.Character
 convertCalls={};service:Give(D2);check(convertCalls[1].Id==d2[1].Id,'a stale held Tool is ignored: the oldest record is used')
end
-- Repeatable, no daily cap: ten Void packs, ten Verity packs.
do
 local P=makePlayer('Pia');spawn(P);void(P,10)
 for i=1,10 do R.advance(1.1);local ok=service:Give(P);if not ok then check(false,'hand-in '..i..' refused: '..tostring(last(P).Args[2].Reason));break end end
 check(count(P,VOID)==0 and count(P,VERITY)==10 and service:Delivered(P)==10 and msgs(P,'Done')==10,'ten hand-ins: all ten converted, Delivered 10 (no daily cap)')
 R.clock+=86400*2;R.advance(1.1);void(P,1);check(service:Give(P)and service:Delivered(P)==11,'and another one two days later: 11')
end
-- The saved counter is read defensively.
do
 local S=makePlayer('Sam');spawn(S);local prem=Data:GetPremium(S)
 for _,case in ipairs({{nil,0},{'x',0},{{Count='x'},0},{{Count=-5},0},{{Count=0/0},0},{{Count=2.7},2},{{Count=1e12},1e9},{{Count=7},7},{{},0},{42,0}})do
  prem.Verity=case[1];check(service:Delivered(S)==case[2],'stored '..tostring(type(case[1])=='table'and 'Count='..tostring(case[1].Count)or case[1])..' reads as '..case[2])
 end
 prem.Verity={Count=1e9};void(S,1);R.advance(1.1);service:Give(S);check(service:Delivered(S)==1e9,'the counter stops at 1e9')
end
-- 5. Every refusal leaves everything exactly as it was -----------------------------------------------------------------------
local function refusal(name,p,reason,setup,undo,asked)
 local records=snapshot(p);local tools={};for _,c in ipairs(bag(p):GetChildren())do tools[#tools+1]=c end
 local count0=service:Delivered(p);local calls=#convertCalls;local done0=msgs(p,'Done');local refused0=msgs(p,'Refused');local rev=Data.Revision[p];local notes0=#shown
 if setup then setup()end
 local ok,why=service:Give(p)
 local m=last(p)
 check(ok==false and why==reason and m.Args[1]=='Refused'and m.Args[2].Reason==reason and msgs(p,'Refused')==refused0+1,name..': refused with "'..reason..'" ('..tostring(why)..')')
 local unchanged=same(snapshot(p),records)and #convertCalls==calls+(asked or 0)and service:Delivered(p)==count0 and msgs(p,'Done')==done0 and Data.Revision[p]==rev and #shown==notes0
 local sameTools=#bag(p):GetChildren()==#tools;for i,t in ipairs(tools)do if bag(p):GetChildren()[i]~=t then sameTools=false end end
 check(unchanged and sameTools,name..': nothing changed (records, Tools, count'..((asked or 0)==0 and', no Convert call'or', ConvertVoidPack asked '..asked..' time')..', no notice)')
 if undo then undo()end
 R.advance(2)
end
do
 local E=makePlayer('Eve');spawn(E);addPack(E,'Pack01',1);addPack(E,'Pack03',3);for _,rec in ipairs(Data:GetChestRecords(E))do toolFor(rec,bag(E))end
 refusal('no Void pack (only other packs)',E,C.Reasons.NoVoid)
 local ev=void(E,2);toolFor(ev[1],bag(E));toolFor(ev[2],bag(E))
 -- Range: 30 studs from the top of the dais.
 local _,root=E.Character,E.Character.HumanoidRootPart
 refusal('too far',E,C.Reasons.TooFar,function()root.CFrame=R.CFrame.new(0,7,-190)end,function()root.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z)end)
 refusal('far to the side',E,C.Reasons.TooFar,function()root.CFrame=R.CFrame.new(45,7,-222)end,function()root.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z)end)
 root.CFrame=R.CFrame.new(0,7,-193) -- 29 studs: inside
 check((root.Position-service:Center()).Magnitude<30,'(29 studs is inside the range)')
 root.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z)
 refusal('no character',E,C.Reasons.Moment,function()E.Character=nil end,function()E.Character=root.Parent end)
 refusal('dead',E,C.Reasons.Moment,function()root.Parent.Humanoid.Health=0 end,function()root.Parent.Humanoid.Health=100 end)
 for _,row in ipairs(C.BusyAttributes)do
  refusal(row[1],E,C.Reasons[row[2]],function()E:SetAttribute(row[1],true)end,function()E:SetAttribute(row[1],nil)end)
 end
 -- Range is checked before the busy states.
 E:SetAttribute('ChestChaseSeedCarrying',true);root.CFrame=R.CFrame.new(0,7,-150)
 refusal('too far AND carrying: range first',E,C.Reasons.TooFar,nil,function()E:SetAttribute('ChestChaseSeedCarrying',nil);root.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z)end)
 -- Mid-opening.
 local heldTool=hasTool(E,ev[1].Id)and bag(E):FindFirstChild(ev[1].Id)
 refusal('this Void pack is being clicked open',E,C.Reasons.Opening,function()Chests.Openings[E]={Tool=heldTool,Clicks=3,Committed=false}end,function()Chests.Openings[E]=nil end)
 local revealTool=toolFor(addPack(E,'Pack02',2),bag(E))
 refusal('a reveal is playing',E,C.Reasons.Opening,function()Chests.Openings[E]={Tool=revealTool,Clicks=5,Committed=true}end,function()Chests.Openings[E]=nil end)
 -- Data.
 refusal('data not saved (CanSave false)',E,C.Reasons.CannotSave,function()Data.CanSave[E]=false end,function()Data.CanSave[E]=true end)
 refusal('data not loaded',E,C.Reasons.Loading,function()Data.Loaded[E]=false end,function()Data.Loaded[E]=true end)
 -- ConvertVoidPack missing / failing / throwing.
 local realConvert=Chests.ConvertVoidPack
 refusal('ConvertVoidPack missing',E,C.Reasons.NotReady,function()Chests.ConvertVoidPack=nil end,function()Chests.ConvertVoidPack=realConvert end)
 convertMode='fail'
 refusal('ConvertVoidPack fails with a reason',E,'THE BAG COULD NOT TAKE IT',nil,nil,1)
 check(#convertCalls>0 and convertCalls[#convertCalls].Id==ev[1].Id,'(it was asked to convert the oldest Void pack)')
 convertMode='failsilently'
 refusal('ConvertVoidPack fails without a reason',E,C.Reasons.Failed,nil,nil,1)
 convertMode='throw'
 refusal('ConvertVoidPack throws before changing anything',E,C.Reasons.Failed,nil,nil,1)
 convertMode=nil
 refusal('no chest service at all',E,C.Reasons.NotReady,function()service.Chests=nil end,function()service.Chests=Chests end)
 -- And with all of that undone she works again.
 R.advance(2);Chests.Openings[E]=nil;local ok=service:Give(E)
 check(ok and count(E,VOID)==1 and count(E,VERITY)==1 and service:Delivered(E)==1,'after all the refusals a normal hand-in still works (one Void -> one Verity)')
end
-- Holding a Void tool that has not been clicked is NOT mid-opening (the held pack is simply the one handed in).
do
 local H=makePlayer('Hal');spawn(H);local hv=void(H,1)[1];local t=toolFor(hv,H.Character)
 Chests.Openings[H]={Tool=t,Clicks=0,Committed=false}
 local ok,new=service:Give(H);check(ok and new and not hasTool(H,hv.Id)and hasTool(H,new.Id),'holding the Void pack with no clicks yet: handed in')
 Chests.Openings[H]=nil
 -- An opening of a different, plain pack does not block either.
 local I=makePlayer('Ida');spawn(I);local iv=void(I,1)[1];local plain=addPack(I,'Pack02',2);toolFor(iv,bag(I));local pt=toolFor(plain,I.Character)
 Chests.Openings[I]={Tool=pt,Clicks=4,Committed=false}
 ok=service:Give(I);check(ok,'clicking a different pack open does not block the hand-in')
 Chests.Openings[I]=nil
end
-- A conversion that threw AFTER swapping the record still counts (the pack is already Verity), nothing is lost.
do
 local J=makePlayer('Joy');spawn(J);local jv=void(J,1)[1];toolFor(jv,bag(J))
 convertMode='convertthenthrow';local ok,new=service:Give(J);convertMode=nil
 check(ok and new and new.BagVariant==VERITY and count(J,VOID)==0 and count(J,VERITY)==1 and service:Delivered(J)==1 and last(J).Args[1]=='Done','a late error in ConvertVoidPack: the swap already happened, so it is counted and Done is sent')
end
-- Spam: the rate limit (VerityGive burst 2, 1 a second) drops the rest silently.
do
 local K=makePlayer('Kit');spawn(K);void(K,6);for _,rec in ipairs(Data:GetChestRecords(K))do toolFor(rec,bag(K))end
 local before=#inbox(K);convertCalls={}
 for _=1,6 do remote.OnServerEvent:Fire(K,'Give')end
 check(count(K,VERITY)==2 and count(K,VOID)==4 and #convertCalls==2,'6 quick Gives: only the burst of 2 goes through ('..count(K,VERITY)..' converted)')
 check(#inbox(K)-before==2 and msgs(K,'Done')==2 and msgs(K,'Refused')==0,'the other 4 are dropped without an answer')
 R.advance(1.05);remote.OnServerEvent:Fire(K,'Give');check(count(K,VERITY)==3,'a second later one more goes through')
 -- Refusals do not use up the budget: the player can still hand in right after being told "come closer".
 local L=makePlayer('Lou');local _,root=spawn(L,0,7,-150);void(L,1)
 for _=1,5 do remote.OnServerEvent:Fire(L,'Give')end
 check(msgs(L,'Refused')==5,'five refusals for being too far are all answered')
 root.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z);remote.OnServerEvent:Fire(L,'Give')
 check(count(L,VERITY)==1,'and the next, in range, still works')
end
-- Hostile remote calls: wrong action, arguments, a table that loops. Nothing happens.
do
 local M2=makePlayer('Max');spawn(M2);void(M2,3);convertCalls={}
 remote.OnServerEvent:Fire(M2,'Take');remote.OnServerEvent:Fire(M2,nil);remote.OnServerEvent:Fire(M2,{Give=true});remote.OnServerEvent:Fire(M2,12)
 local loop={};loop.Self=loop;remote.OnServerEvent:Fire(M2,'Give',loop)
 local huge={};for i=1,200 do huge[i]=i end;remote.OnServerEvent:Fire(M2,'Give',huge)
 check(#convertCalls==0 and count(M2,VOID)==3 and #inbox(M2)==0,'unknown actions and malformed arguments do nothing (no conversion, no answer)')
 R.advance(2) -- (the two hostile Gives above used up the burst, as they should)
 remote.OnServerEvent:Fire(M2,'Give','extra-but-harmless');check(count(M2,VERITY)==1,'harmless extra arguments are ignored, the hand-in itself is the same')
end
-- A player who leaves between the click and the check is ignored.
do
 local N=makePlayer('Nia');spawn(N);void(N,1);N.Parent=nil;convertCalls={}
 check(service:Give(N)==false and #convertCalls==0,'a player who already left: nothing happens')
end
-- Without the map there is nothing to build, and no crash.
do
 local lonely=Verity.new(Config,Data,Chests,Notes,{});local oldHub=hub.Parent;local mapParent=mapRoot.Parent
 mapRoot.Parent=nil;local ok=pcall(function()lonely:Start()end)
 check(ok and lonely.Started~=true,'Start without an EconomyHub only warns (and can be tried again later)')
 mapRoot.Parent=mapParent
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
