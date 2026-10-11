--!nocheck
-- R150 SFX fix round, part 5: the server half on the Roblox mock with the REAL server modules (treadmill_bonus_R123 world + bundle):
--  1. PlayerDataService publishes the saved audio mix on the Player at data load (AudioEffects / AudioMusic ... numbers), defaults for a new
--     player, so the client's AudioMixer can apply it before SettingsState answers.
--  2. NotificationService forwards kind 'Denied'; TrackHoleService marks only its refusals (cooldown, can't dig here / now); FastTravelService's
--     refusals are marked too (docs: tools/tests/test_fast_travel.luau runs the whole remote flow).
--  3. GardenUpgradeService: every press bumps UpgradePressSerial, and the result is published as UpgradeBoughtSerial or UpgradeRefusedSerial.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
-- (the art builder is replaced before the server modules are moved under their folder)
local builds=0
W.stub('GardenFenceArt',{Build=function()builds+=1 end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function()end;o.FireAllClients=function()end end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end end

-- 1. the saved mix is published at load ------------------------------------------------------------------------------------------------------------
do
 local Config=server('Config');local Settings=W.module('SettingsConfig')
 local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
 local Data=server('PlayerDataService').new(Config,Map,{Show=function()end})
 local function makePlayer(D,id,name)
  local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
  function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
  R.new('Backpack').Parent=p
  D:PreparePlayer(p);assert(D:Load(p),'load '..name)
  return p
 end
 local a=makePlayer(Data,801,'Fresh')
 local ok=true;for key,attribute in pairs(Settings.AudioAttributes)do if a:GetAttribute(attribute)~=100 then ok=false end end
 check(ok,'a new player: every audio attribute is published at the default (100): nobody is muted by the bootstrap')
 check(Settings.AudioAttributes.Effects=='AudioEffects' and Settings.AudioAttributes.Music=='AudioMusic','the attribute names live in SettingsConfig (the mixer reads the same table)')
 -- a player who saved Effects = 0 and Music = 35
 local premium=Data:GetPremium(a);premium.Settings.Effects=0;premium.Settings.Music=35
 local saved=Data:_buildSaveData(a)
 check(saved.Premium and saved.Premium.Settings and saved.Premium.Settings.Effects==0,'(the save carries the mix)')
 local DataB=server('PlayerDataService').new(Config,Map,{Show=function()end})
 local key=DataB:_getKey({UserId=802,Name='Saved'})
 DataB.Store.Data[key]=saved
 local b=makePlayer(DataB,802,'Saved')
 check(b:GetAttribute('AudioEffects')==0 and b:GetAttribute('AudioMusic')==35 and b:GetAttribute('AudioChase')==100,'a returning player: Effects 0 and Music 35 are on the Player the moment the profile is read ('..tostring(b:GetAttribute('AudioEffects'))..', '..tostring(b:GetAttribute('AudioMusic'))..')')
 -- and the client mixer starts from them
 local Mixer;do local inst=R.new('ModuleScript');inst.Name='AudioMixer';inst.Parent=RS;Players.LocalPlayer=b;Mixer=W.load('AudioMixer',inst)end
 check(Mixer.Get('Effects')==0 and Mixer.Get('Music')==35,'the client AudioMixer made with those attributes starts at Effects 0 / Music 35, before any SettingsState')
 Players.LocalPlayer=nil
end

-- 2. refusals are marked Denied ---------------------------------------------------------------------------------------------------------------------
do
 local shown={}
 local Notes=server('NotificationService').new()
 local sent={};Notes.Remote.FireClient=function(_,p,...)sent[#sent+1]={...}end
 local fake={Parent=true}
 Notes:Show(fake,'NEED MORE CASH',R.Color3.new(1,0,0),2,'Denied');Notes:Show(fake,'SOLD FOR $5 CASH',R.Color3.new(0,1,0),2)
 check(#sent==2 and sent[1][4]=='Denied' and sent[2][4]==nil,'NotificationService: kind Denied reaches the client, a plain notice carries none')
 Notes:Show(fake,'NEED MORE CASH',R.Color3.new(1,0,0),2,'Denied');Notes:Show(fake,'NEED MORE CASH',R.Color3.new(1,0,0),2,'Denied')
 check(#sent==3,'(the same refusal twice inside .7 s is sent once: no repeat sound either)')
 local TH=server('TrackHoleService')
 local log={}
 local self={Notifications={Show=function(_,p,text,color,secs,kind)log[#log+1]={Text=text,Kind=kind}end}}
 local refusals={'Cooldown','Carrying','Refreshing','Ground','Pack','Camp','Entrance','Spacing','PlayerCap','ServerCap'}
 for _,key in ipairs(refusals)do log={};TH._tell(self,fake,key,3);check(log[1]~=nil and log[1].Kind=='Denied',key..': a dig refusal is marked Denied')end
 for _,key in ipairs({'Covered','Trapped','Tripped'})do log={};TH._tell(self,fake,key,'X');check(log[1]~=nil and log[1].Kind==nil,key..': news (covered / fell in / tripped) is not a refusal')end
end

-- 3. GardenUpgradeService: bought vs refused ---------------------------------------------------------------------------------------------------------
do
 local U=server('GardenUpgradeService')
 local Players2=Players
 local sender=R.new('Player');sender.Name='Owner';sender.UserId=900;sender.Parent=Players2;present[900]=sender
 local char=R.new('Model');char.Name='Owner';char.Parent=W.workspace;sender.Character=char
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Parent=char
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
 local baseModel=R.new('Model');baseModel.Name='Base1';baseModel.Parent=W.workspace
 local pad=R.new('Part');pad.Name='Pad';pad.Size=V3(40,1,40);pad.CFrame=CF(0,0,0);pad.Parent=baseModel
 local record={Index=1,Model=baseModel}
 local cash=R.Instance.new('IntValue');cash.Value=1e9
 local outcome={true,'BOUGHT'}
 local self={GardenUpgradeRecords={},BaseOwners={sender},Config={TreadmillTiers={{Cost=100},{Cost=200},{Cost=300}}},BusyChecker=function()return false end,
  GetPlayerBase=function()return record end,RefreshTreadmill=function()end,
  PlayerData={IsLoaded=function()return true end,GetFenceTier=function()return 1 end,GetTreadmillData=function()return {Tier=1}end,GetCash=function()return 1e9 end,
   GetOrCreateCashValue=function()return cash end,BuyFence=function()return outcome[1],outcome[2]end,BuyTreadmill=function()return outcome[1],outcome[2]end}}
 local ok,err=pcall(U.Refresh,self,sender);check(ok,'GardenUpgradeService.Refresh builds the buttons on the mock: '..tostring(err))
 local state=self.GardenUpgradeRecords[1]
 local button=state and state.Buttons.Fence
 if button then
  root.CFrame=CF(button.Cap.Position.X,button.Cap.Position.Y+3,button.Cap.Position.Z)
  local function press(result)
   outcome=result;R.advance(1)
   -- (a bought upgrade rebuilds the buttons after its .34 s settle: take the current ones)
   state=self.GardenUpgradeRecords[1];button=state.Buttons.Fence;state.Busy=false
   local p0,b0,r0=sender:GetAttribute('UpgradePressSerial')or 0,sender:GetAttribute('UpgradeBoughtSerial')or 0,sender:GetAttribute('UpgradeRefusedSerial')or 0
   button.Prompt.Triggered:Fire(sender)
   return (sender:GetAttribute('UpgradePressSerial')or 0)-p0,(sender:GetAttribute('UpgradeBoughtSerial')or 0)-b0,(sender:GetAttribute('UpgradeRefusedSerial')or 0)-r0
  end
  local dp,db,dr=press({true,'BOUGHT'})
  check(dp==1 and db==1 and dr==0,'a bought upgrade: the press serial and the bought serial move (the client plays UpgradeClick + KaChing)')
  dp,db,dr=press({false,'NOT ENOUGH CASH'})
  check(dp==1 and db==0 and dr==1,'a refused upgrade: the press serial and the refused serial move (UpgradeClick + Denied), never bought')
  dp,db,dr=press({true,'BOUGHT'})
  check(dp==1 and db==1 and dr==0,'and the next purchase is bought again')
  R.advance(1);state=self.GardenUpgradeRecords[1];button=state.Buttons.Fence;state.Busy=false
  local p0=sender:GetAttribute('UpgradePressSerial')or 0
  button.Prompt.Triggered:Fire(sender);state.Busy=false;button.Prompt.Triggered:Fire(sender)
  check((sender:GetAttribute('UpgradePressSerial')or 0)-p0<=1,'presses faster than the server\'s .65 s limit change nothing (no stacked sounds)')
 end
end

print(('R150 server checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
