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
-- R148 (owner's play test: she was invisible and in front of the market; "Verity should be a big yellow sphere"): the body is a
-- solid yellow Ball (Color 255,255,0, SmoothPlastic, 22 studs) with her smiley as Decals on its Front and Back faces, on a
-- 28 stud dais BEHIND the market; the position is checked against the REAL MarketLayout's footprint (porch, produce stands,
-- Fruit of the Hour pedestal, fast-travel marker), the lobby bounds, the bases and the spawn.
-- R148 follow-up: her sign is one studs-sized BillboardGui (marker row, gap, name, event timer row: rows that cannot overlap, offset
-- in camera space so it clears her top from any angle, also while she bobs and swells); and the limited event (LimitedEvent.EndsAt,
-- 2026-11-01 00:00 UTC): once it is over the server refuses every hand-in ("THE VERITY EVENT HAS ENDED") before anything else.
local W=require('./world');local R=W.R
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
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
local STAND=R.Vector3.new(0,7,-318) -- 24 studs in front of her (the market side)
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
check(C.Position==R.Vector3.new(0,4,-340)and C.Facing==R.Vector3.new(0,0,1),'behind the market at (0, 4, -340), facing +Z')
check(C.BodySize==22 and C.FootOffset~=nil and C.DaisDiameter==28 and C.DaisHeight==1.2,'BodySize 22 / FootOffset / DaisDiameter 28 exposed to tune')
check(C.BodyColor.R==1 and C.BodyColor.G==1 and C.BodyColor.B==0,'the yellow (255, 255, 0)')
check(C.Quest=='Steal a Void Pack from The Darkened One at the end of Storm Peaks and bring it to me. I\'ll give you a Verity Pack!','the quest text')
check(C.GiveDistance==38 and C.PromptDistance==26 and C.VoidVariant==VOID,'38 stud hand-in range, 26 stud prompt, Void = EclipseReliquary')
check(C.GreetingSoundId=='rbxassetid://123997993114202','the owner\'s greeting voice id in VerityConfig.GreetingSoundId')
local gateSrc=W.B.SecurityGate
check(gateSrc:find('VerityTalk={Rate=1,Burst=3}',1,true)and gateSrc:find('VerityGive={Rate=1,Burst=2}',1,true),'SecurityGate has the VerityTalk and VerityGive policies')
-- The market as built by the real MarketLayout (every part of it, before its showcase fills in), measured on a probe map.
local footprint
do
 local V3=R.Vector3.new
 R.Vector3.FromNormalId=R.Vector3.FromNormalId or function(n)
  local name=type(n)=='table'and n.Name or tostring(n):match('(%a+)$')
  return({Front=V3(0,0,-1),Back=V3(0,0,1),Left=V3(-1,0,0),Right=V3(1,0,0),Top=V3(0,1,0),Bottom=V3(0,-1,0)})[name]
 end
 W.env.Vector3=R.Vector3
 local probe=R.new('Folder');probe.Name='MarketProbe';probe.Parent=W.workspace
 local probeHub=R.new('Folder');probeHub.Name='EconomyHub';probeHub.Parent=probe
 for _,n in ipairs({'BuyStation','SellStation'})do local st=R.new('Part');st.Name=n;st.Parent=probeHub end
 local Market=server('MarketLayout')
 local realWarn=W.env.warn;W.env.warn=function()end
 local ok,err=pcall(Market.Apply,probe)
 check(ok,'the real MarketLayout builds on the probe map: '..tostring(err))
 local lo,hi=R.Vector3.new(1e9,1e9,1e9),R.Vector3.new(-1e9,-1e9,-1e9);local n=0
 for _,d in ipairs(probeHub:GetDescendants())do if d:IsA('BasePart')then
  local r=d.CFrame.R;local sz=d.Size;local c=d.CFrame.Position
  local hx=(math.abs(r[1][1])*sz.X+math.abs(r[1][2])*sz.Y+math.abs(r[1][3])*sz.Z)/2
  local hy=(math.abs(r[2][1])*sz.X+math.abs(r[2][2])*sz.Y+math.abs(r[2][3])*sz.Z)/2
  local hz=(math.abs(r[3][1])*sz.X+math.abs(r[3][2])*sz.Y+math.abs(r[3][3])*sz.Z)/2
  lo=V3(math.min(lo.X,c.X-hx),math.min(lo.Y,c.Y-hy),math.min(lo.Z,c.Z-hz));hi=V3(math.max(hi.X,c.X+hx),math.max(hi.Y,c.Y+hy),math.max(hi.Z,c.Z+hz));n+=1
 end end
 R.advance(.2);W.env.warn=realWarn;probe:Destroy()
 footprint={Lo=lo,Hi=hi,Parts=n}
 check(n>150,'(the market has '..n..' parts here)')
 check(math.abs((lo.X+hi.X)/2)<1 and hi.X-lo.X>48 and hi.X-lo.X<60,('the market is about 54 studs wide, centred on x 0: %.1f .. %.1f'):format(lo.X,hi.X))
 check(hi.Z>-250 and hi.Z<-245 and lo.Z<-290 and lo.Z>-310,('its depth runs z %.1f (the side facing the spawn) to %.1f (porch, string lights, fast-travel marker)'):format(hi.Z,lo.Z))
 check(hi.Y>31 and hi.Y<33,('and its roof ridge is at y %.1f'):format(hi.Y))
end
-- 2. Start builds her ------------------------------------------------------------------------------------------------------
check(hub:FindFirstChild('VerityNPC')==nil and remotes:FindFirstChild('VerityQuest')==nil,'nothing exists before Start')
check(service:Start()==service,'Start returns the service')
local model=hub:FindFirstChild('VerityNPC')
check(model and model:IsA('Model')and model.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent,'workspace.ChestChaseMap.EconomyHub.VerityNPC, a Persistent Model')
check(model and W.CS:HasTag(model,'VerityNPC')and model:GetAttribute('VerityNPC')==C.Version,'tagged VerityNPC for the client')
local remote=remotes:FindFirstChild('VerityQuest')
check(remote and remote:IsA('RemoteEvent'),'ChestChaseRemotes.VerityQuest is a RemoteEvent')
local dais=model:FindFirstChild('Dais');local body=model:FindFirstChild('Body')
check(dais and dais.Shape==R.Enum.PartType.Cylinder and dais.Size.Y==28 and dais.Size.Z==28 and dais.Size.X==1.2 and dais.CanCollide==true and dais.Anchored,'the dais: a solid stone cylinder, diameter 28, 1.2 high')
check(dais and dais.Position.X==0 and dais.Position.Z==-340 and math.abs(dais.Position.Y-4.6)<1e-6,'standing on the floor at (0, 4, -340)')
check(model:FindFirstChild('Dais rim')and model:FindFirstChild('Inlay'),'with a gold rim and an inlay')
check(model:FindFirstChild('Card')==nil and model:FindFirstChild('Collision')==nil,'the see-through card and the collision pillar of R147 are gone')
check(body and body:IsA('Part')and body.Shape==R.Enum.PartType.Ball,'Verity\'s Body is a Part with Shape = Ball')
check(body and body.Size.X==22 and body.Size.Y==22 and body.Size.Z==22,'22 studs across')
check(body and math.floor(body.Color.R*255+.5)==255 and math.floor(body.Color.G*255+.5)==255 and math.floor(body.Color.B*255+.5)==0,'solid yellow: Color (255, 255, 0)')
check(body and body.Material==R.Enum.Material.SmoothPlastic and body.Transparency==0 and body.Anchored,'SmoothPlastic, not see-through, anchored')
check(body and body.CanCollide==true,'solid (she collides as a sphere)')
check(body and body.Position.X==0 and body.Position.Z==-340 and math.abs(body.Position.Y-(5.2+.25+11))<1e-6,'centred over the dais, a quarter stud above it (y 16.45, her top at 27.45, under the market ridge)')
local look=body and body.CFrame.LookVector
check(look and math.abs(look.X)<1e-6 and math.abs(look.Z-1)<1e-6,'her front faces +Z (toward the market)')
local decals={};for _,d in ipairs(body and body:GetChildren()or{})do if d:IsA('Decal')then decals[#decals+1]=d end end
check(#decals==2,'two Decals on the body ('..#decals..')')
local faces={};for _,d in ipairs(decals)do faces[d.Face.Name]=d;check(d.Texture=='rbxassetid://102712963740896'and d.Transparency==0,'Decal '..d.Name..': the owner\'s smiley, opaque')end
check(faces.Front and faces.Back and not faces.Left and not faces.Right,'on the Front and Back faces')
check(body and W.CS:HasTag(body,'GiantVisualPart'),'tagged GiantVisualPart (the camera right up against her fades her)')
local ring=model:FindFirstChild('Glow ring');local lightAnchor=model:FindFirstChild('LightAnchor');local light=lightAnchor and lightAnchor:FindFirstChild('Glow')
check(ring and ring.Material==R.Enum.Material.Neon,'a neon ring on the dais')
check(light and light:IsA('PointLight')and lightAnchor.Position.Y>body.Position.Y+11 and light.Range<=60,'a PointLight above her')
local sign=body and body:FindFirstChild('NameSign');local nameLabel=sign and sign:FindFirstChild('Name')
check(sign and sign:IsA('BillboardGui')and sign.Adornee==body and nameLabel and nameLabel.Text=='VERITY','a VERITY name sign (BillboardGui on her body)')
do -- her sign: rows in studs that cannot overlap, clear of her at every camera angle and while she bobs and swells
 local S=C.Sign;local sw,sh=sign.Size.X.Scale,sign.Size.Y.Scale
 check(sw==S.W and sh==S.H and sign.Size.X.Offset==0 and sign.Size.Y.Offset==0,'the sign is sized in studs ('..sw..' x '..sh..'), so it scales with her')
 local nameTop,nameH=nameLabel.Position.Y.Scale*sh,nameLabel.Size.Y.Scale*sh
 check(near(nameTop,S.Name.Top)and near(nameH,S.Name.Height)and nameLabel.Position.X.Scale==0 and nameLabel.Size.X.Scale==1,'the name row: '..string.format('%.1f .. %.1f',nameTop,nameTop+nameH)..' studs down the sign')
 local markEnd=S.Mark.Top+S.Mark.Height;local timerTop=S.Timer.Top
 check(markEnd+1>=0 and nameTop-markEnd>=1,string.format('a gap of %.1f studs between the marker row and the name',nameTop-markEnd))
 check(timerTop-(nameTop+nameH)>=.4 and timerTop+S.Timer.Height<=sh+1e-6,string.format('and %.1f studs between the name and the timer row, which ends inside the sign',timerTop-(nameTop+nameH)))
 check(S.Mark.Glyph+S.Mark.Bounce<=S.Mark.Height+1e-6,'the "!" / "?" glyph (rests on the bottom of its row) bounces up inside the row, never down toward the name')
 check(sign.StudsOffsetWorldSpace.X==0 and sign.StudsOffsetWorldSpace.Y==0 and sign.StudsOffsetWorldSpace.Z==0,'no world-space offset (it would drop into her at steep camera angles)')
 local bottom=sign.StudsOffset.Y-sh/2 -- camera-space studs from her middle to the sign's bottom edge
 check(near(bottom,11+S.Gap,1e-6),'camera-space offset: the sign\'s bottom edge is '..S.Gap..' studs above her silhouette top ('..string.format('%.2f',bottom)..' from her middle, she is 11 studs in radius)')
 check(bottom-(11*(1+C.TalkPulse)+C.FootOffset)>=.3,'it still clears her when she swells with her voice and bobs: '..string.format('%.2f',bottom-(11*(1+C.TalkPulse)+C.FootOffset))..' studs to spare')
 check(sign.AlwaysOnTop==false and sign.MaxDistance>=200,'(depth-tested, visible from far away)')
end
local prompt=model:FindFirstChild('Talk',true)
check(prompt and prompt:IsA('ProximityPrompt')and prompt.ActionText=='Talk'and prompt.HoldDuration==0 and prompt.MaxActivationDistance==26 and prompt.RequiresLineOfSight==false and prompt.Enabled,'ProximityPrompt "Talk": hold 0, 26 studs, no line of sight needed')
-- Where she stands, against the real market and the lobby.
do
 local fp=footprint;local c=C.Position;local radius=C.DaisDiameter/2
 local dx0,dx1,dz0,dz1=c.X-radius,c.X+radius,c.Z-radius,c.Z+radius
 local function gap(ax0,ax1,az0,az1)local gx=math.max(ax0-dx1,dx0-ax1,0);local gz=math.max(az0-dz1,dz0-az1,0);return math.sqrt(gx*gx+gz*gz)end
 check(gap(fp.Lo.X,fp.Hi.X,fp.Lo.Z,fp.Hi.Z)>=20,('her dais (z %.0f .. %.0f) is at least 20 studs clear of every market part (porch / stands / pedestal / fast-travel marker): %.1f'):format(dz0,dz1,gap(fp.Lo.X,fp.Hi.X,fp.Lo.Z,fp.Hi.Z)))
 check(dz1<fp.Lo.Z and c.Z<fp.Lo.Z,'she is behind the market, seen from the spawn: the whole dais is beyond its far edge (z '..string.format('%.1f',fp.Lo.Z)..')')
 check(fp.Lo.X<=0 and fp.Hi.X>=0 and c.X==0,'the market stands between the spawn (0, -141) and her on the line x = 0')
 local toSpawn=R.Vector3.new(0,0,-141)-c;local f=C.Facing
 check(f.Z>0 and (toSpawn.Z>0),'she faces +Z, toward the market and the spawn side, the way players come round to her')
 check(body.Position.Y+11<fp.Hi.Y,'her top (y '..string.format('%.1f',body.Position.Y+11)..') is under the market\'s ridge (y '..string.format('%.1f',fp.Hi.Y)..'): big, but it does not dwarf it')
 check(body.Size.X>=18 and body.Size.X<=22,'between 18 and 22 studs across')
 -- The lobby (Workspace.ChestChaseMap.Lobby.LobbyFloor x -340..340, z -623..-99; walls at +-337.5 / -620.5) and the bases (Bases: 1/2 z -240..-121, 3/4 z -417..-299 at |x| 145..326, 5/6 z -603..-422 at |x| 15..133).
 check(dx0>-330 and dx1<330 and dz0>-615 and dz1<-110,'inside the lobby walls')
 local bases={{-326,-145,-417,-299},{145,326,-417,-299},{-133,-15,-603,-422},{15,133,-603,-422},{-326,-145,-240,-121},{145,326,-240,-121}}
 local worst=1e9;for _,b in ipairs(bases)do worst=math.min(worst,gap(b[1],b[2],b[3],b[4]))end
 check(worst>=40,'at least 40 studs from every base ('..string.format('%.0f',worst)..')')
 check(math.sqrt((c.X-0)^2+(c.Z+141)^2)>150,'far from the spawn (so she does not crowd arriving players)')
 -- The way to her: round the market's sides (it is 54 wide; the next obstacles are the bases 145 studs out).
 check(fp.Hi.X<60 and 145-fp.Hi.X>80,'plenty of walkway round the market ('..string.format('%.0f',145-fp.Hi.X)..' studs between its side and the bases)')
end
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
 check(dais.CanCollide==true and body.CanCollide==true,'WalkthroughProps90 (applied to the whole map) cannot make the dais or her body walk-through')
 check(ring.CanCollide==false and model:FindFirstChild('Dais rim').CanCollide==false,'(the other parts stay decor)')
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
 -- Range: 38 studs from the top of the dais.
 local _,root=E.Character,E.Character.HumanoidRootPart
 refusal('too far',E,C.Reasons.TooFar,function()root.CFrame=R.CFrame.new(0,7,-296)end,function()root.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z)end)
 refusal('far to the side',E,C.Reasons.TooFar,function()root.CFrame=R.CFrame.new(60,7,-340)end,function()root.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z)end)
 root.CFrame=R.CFrame.new(0,7,-303) -- 37 studs: inside
 check((root.Position-service:Center()).Magnitude<38,'(37 studs is inside the range)')
 root.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z)
 refusal('no character',E,C.Reasons.Moment,function()E.Character=nil end,function()E.Character=root.Parent end)
 refusal('dead',E,C.Reasons.Moment,function()root.Parent.Humanoid.Health=0 end,function()root.Parent.Humanoid.Health=100 end)
 for _,row in ipairs(C.BusyAttributes)do
  refusal(row[1],E,C.Reasons[row[2]],function()E:SetAttribute(row[1],true)end,function()E:SetAttribute(row[1],nil)end)
 end
 -- Range is checked before the busy states.
 E:SetAttribute('ChestChaseSeedCarrying',true);root.CFrame=R.CFrame.new(0,7,-250)
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
 local L=makePlayer('Lou');local _,root=spawn(L,0,7,-250);void(L,1)
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
-- The limited event is over: every hand-in is refused first (LimitedEvent.EndsAt, 2026-11-01 00:00 UTC, on the server's clock).
do
 local Limited=W.module('LimitedEvent')
 check(Limited.EndsAt==1793491200 and C.EventEndsAt==Limited.EndsAt and C.Reasons.EventEnded=='THE VERITY EVENT HAS ENDED','the event ends at LimitedEvent.EndsAt (2026-11-01 00:00 UTC) and the refusal reads "THE VERITY EVENT HAS ENDED"')
 local before=R.clock
 local Z=makePlayer('Zed');spawn(Z);local zv=void(Z,3);for _,rec in ipairs(Data:GetChestRecords(Z))do toolFor(rec,bag(Z))end
 R.clock=Limited.EndsAt-3
 local ok=service:Give(Z);check(ok and count(Z,VERITY)==1,'3 seconds before the end it still works (one Void pack handed in)')
 R.advance(1.2);R.clock=Limited.EndsAt-1;R.advance(0)
 ok=service:Give(Z);check(ok and count(Z,VERITY)==2,'one second before the end it still works')
 R.clock=Limited.EndsAt
 refusal('the event has ended (exactly at the end)',Z,C.Reasons.EventEnded)
 R.clock=Limited.EndsAt+86400*40
 refusal('the event ended 40 days ago',Z,C.Reasons.EventEnded)
 check(count(Z,VOID)==1 and count(Z,VERITY)==2 and service:Delivered(Z)==2,'(nothing was taken: 1 Void pack left, 2 Verity packs, 2 handed in)')
 -- It is checked before everything else (not just before the Void-pack lookup): data not loaded, far away, carrying, no pack at all.
 refusal('ended, and too far away',Z,C.Reasons.EventEnded,function()Z.Character.HumanoidRootPart.CFrame=R.CFrame.new(0,7,-100)end,function()Z.Character.HumanoidRootPart.CFrame=R.CFrame.new(STAND.X,STAND.Y,STAND.Z)end)
 refusal('ended, and carrying a stolen pack',Z,C.Reasons.EventEnded,function()Z:SetAttribute('ChestChaseSeedCarrying',true)end,function()Z:SetAttribute('ChestChaseSeedCarrying',nil)end)
 refusal('ended, and the data is not loaded',Z,C.Reasons.EventEnded,function()Data.Loaded[Z]=false end,function()Data.Loaded[Z]=true end)
 local Y=makePlayer('Yan');spawn(Y)
 refusal('ended, and no Void pack at all',Y,C.Reasons.EventEnded)
 -- Spam after the end: refused (never converted), still rate limited like any hand-in.
 convertCalls={};for _=1,6 do remote.OnServerEvent:Fire(Z,'Give')end
 check(#convertCalls==0 and count(Z,VOID)==1 and count(Z,VERITY)==2,'six quick Gives after the end convert nothing')
 -- Talking still works (the dialog opens, and says EVENT ENDED).
 R.advance(1.2);local n0=msgs(Z,'Open');prompt.Triggered:Fire(Z)
 local om=last(Z);check(msgs(Z,'Open')==n0+1 and om.Args[1]=='Open'and om.Args[2].VoidPacks==1 and om.Args[2].Delivered==2,'she still opens her dialog after the end (1 Void pack, 2 handed in)')
 -- The real LimitedEvent text format.
 check(Limited.Text(27*86400+4*3600+12*60+9)=='27d 04h 12m 09s'and Limited.Text(0)=='0d 00h 00m 00s'and Limited.Left(Limited.EndsAt+5)==0 and not Limited.Active(Limited.EndsAt)and Limited.Active(Limited.EndsAt-1),'LimitedEvent: "27d 04h 12m 09s", 0 at and after the end')
 R.clock=before;R.advance(0);R.advance(2)
 ok=service:Give(Z);check(ok and count(Z,VERITY)==3 and count(Z,VOID)==0,'with the clock back before the end (the event running) the same player can hand in again')
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
