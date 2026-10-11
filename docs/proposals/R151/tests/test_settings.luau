--!nocheck
-- R151 setting "Announcements from other servers", the DATA half, on the Roblox mock with the REAL SettingsConfig, AudioMixer, PlayerDataService, PremiumProgress,
-- PremiumService (its SetSetting / SettingsState handler) and PullAnnouncer:
--  1. SettingsConfig: a saved on / off setting next to the volumes; a saved false stays false; bad values fall back to the default (on); the volumes are untouched
--  2. it is saved in the existing Settings table of the Premium save: no profile version change, a save / load round trip, a profile saved before R151 reads "on"
--  3. the server handler: SettingsState returns it, SetSetting accepts a boolean (and refuses 0, "off", nil), the next announcement from another server honours it at once
--  4. PullAnnouncer: only players with it on (or who never touched it) get a global announcement; the in-server announcement does not look at it
local W=require('./world');local R=W.R;local E=require('./announce_env')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
-- PassGiftService (built by PremiumService) runs `while task.wait(60) do ... end`: a wait that really yields, as in R148's purchase test (the mock's returns at once)
R.task.wait=function(t)
 local co=coroutine.running()
 if not co or not coroutine.isyieldable()then return t or 0 end
 R.task.delay(t or 0,function()coroutine.resume(co,t or 0)end);return coroutine.yield()
end
do local raw=R.advance;R.advance=function(dt)local n=math.max(1,math.ceil(dt/.25-1e-9));for _=1,n do raw(dt/n)end end end
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local Http=W.service('HttpService');local httpMock=E.http();Http.JSONEncode=httpMock.JSONEncode;Http.JSONDecode=httpMock.JSONDecode;Http.GenerateGUID=httpMock.GenerateGUID
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
W.stub('OwnerCommandAccess',{IsAllowed=function(p)return p~=nil end,Publish=function()return true end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='RemoteFunction'then o.InvokeClient=function()end end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local Settings=W.module('SettingsConfig');local Packs=W.module('SeedPackRules');local Rules=W.module('PullAnnounceRules')
R.clock=20000*86400+3600

-- 1. SettingsConfig ---------------------------------------------------------------------------------------------------------------------------------
do
 check(Settings.Defaults.GlobalAnnouncements==true,'the default is ON')
 check(Settings.Valid('GlobalAnnouncements',true)and Settings.Valid('GlobalAnnouncements',false),'true and false are valid')
 for _,bad in ipairs({0,1,'on','off','true',{},0/0})do check(not Settings.Valid('GlobalAnnouncements',bad),'invalid: '..tostring(bad))end
 check(not Settings.Valid('GlobalAnnouncements',nil),'invalid: nil')
 check(not Settings.Valid('Music',true)and not Settings.Valid('Effects',false)and Settings.Valid('Music',50)and not Settings.Valid('Music',101)and not Settings.Valid('Music',5.5)and Settings.Valid('Quality','Low')and not Settings.Valid('Quality',true),'the volumes and Quality validate exactly as before (a boolean is not a volume)')
 check(Settings.Read({GlobalAnnouncements=false}).GlobalAnnouncements==false,'a saved FALSE reads false (it must not turn back into the default)')
 check(Settings.Read({GlobalAnnouncements=true}).GlobalAnnouncements==true and Settings.Read(nil).GlobalAnnouncements==true and Settings.Read({}).GlobalAnnouncements==true,'true / nothing saved / nil reads on')
 check(Settings.Read({GlobalAnnouncements='off'}).GlobalAnnouncements==true and Settings.Read({GlobalAnnouncements=0}).GlobalAnnouncements==true,'a bad saved value reads on')
 local read=Settings.Read({Music=35,Effects=0,Quality='Low',GlobalAnnouncements=false,Junk=5})
 check(read.Music==35 and read.Effects==0 and read.Quality=='Low'and read.GlobalAnnouncements==false and read.Junk==nil and read.Chase==100,'a mixed save reads every field; unknown keys are dropped')
 check(Settings.AudioAttributes.Effects=='AudioEffects'and Settings.AudioAttributes.GlobalAnnouncements==nil,'the audio attribute table (the mixer\'s) does not include it')
 -- the mixer: still volumes only
 local me=R.new('Player');me.Name='Me';me.Parent=Players;Players.LocalPlayer=me
 local inst=R.new('ModuleScript');inst.Name='AudioMixer';inst.Parent=RS
 local Mixer=W.load('AudioMixer',inst)
 check(Mixer.Get('Effects')==100 and Mixer.Get('Music')==100,'the mixer starts at the default volumes')
 Players.LocalPlayer=nil
end

-- 2. saved with the Premium settings ---------------------------------------------------------------------------------------------------------------------
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Data=server('PlayerDataService').new(Config,Map,{Show=function()end})
local function makePlayer(data,id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 data:PreparePlayer(p);assert(data:Load(p),'load '..name)
 return p
end
local a=makePlayer(Data,1101,'Fresh')
do
 check(Data:GetPremium(a).Settings.GlobalAnnouncements==true,'a new player: ON')
 Data:GetPremium(a).Settings.GlobalAnnouncements=false
 local saved=Data:_buildSaveData(a)
 check(saved.Premium and saved.Premium.Settings and saved.Premium.Settings.GlobalAnnouncements==false,'the save carries the setting inside Premium.Settings (the existing table)')
 check(saved.Version==Config.ProfileVersion and Config.ProfileVersion==22,'ProfileVersion is still '..tostring(Config.ProfileVersion)..' (no bump)')
 local DataB=server('PlayerDataService').new(Config,Map,{Show=function()end})
 DataB.Store.Data[DataB:_getKey({UserId=1102,Name='Back'})]=saved
 local b=makePlayer(DataB,1102,'Back')
 check(DataB:GetPremium(b).Settings.GlobalAnnouncements==false,'a returning player: it is still OFF after the save / load round trip')
 -- a profile saved before R151 has no such key
 local old=Data:_buildSaveData(a);old.Premium.Settings.GlobalAnnouncements=nil
 local DataC=server('PlayerDataService').new(Config,Map,{Show=function()end})
 DataC.Store.Data[DataC:_getKey({UserId=1103,Name='Old'})]=old
 local c=makePlayer(DataC,1103,'Old')
 check(DataC:GetPremium(c).Settings.GlobalAnnouncements==true,'a profile saved before R151 (no key) reads ON')
 -- a profile with a bad value
 local weird=Data:_buildSaveData(a);weird.Premium.Settings.GlobalAnnouncements='nope'
 local DataD=server('PlayerDataService').new(Config,Map,{Show=function()end})
 DataD.Store.Data[DataD:_getKey({UserId=1104,Name='Weird'})]=weird
 local d=makePlayer(DataD,1104,'Weird')
 check(DataD:GetPremium(d).Settings.GlobalAnnouncements==true,'a profile with a bad value reads ON (it still loads)')
 check(a:GetAttribute('AudioEffects')==100 and b:GetAttribute('AudioEffects')==100,'the audio attributes published at load are untouched')
end

-- 3. the server handler -------------------------------------------------------------------------------------------------------------------------------
do
 Data:GetPremium(a).Settings.GlobalAnnouncements=true
 local Premium=server('PremiumService').new(Data,{SyncTools=function()end},{Refresh=function()end})
 local request=remotes:FindFirstChild('PremiumRequest')
 check(request~=nil and request.OnServerInvoke~=nil,'PremiumService is listening')
 local function ask(action,value)return request.OnServerInvoke(a,action,value)end
 local state=ask('SettingsState');check(state and state.Success and state.Settings.GlobalAnnouncements==true and state.Settings.Music==100,'SettingsState returns it (on) with the volumes')
 R.advance(1)
 local r=ask('SetSetting',{Key='GlobalAnnouncements',Value=false});check(r and r.Success==true,'SetSetting false is accepted')
 check(Data:GetPremium(a).Settings.GlobalAnnouncements==false,'... and is in the player\'s saved settings at once')
 check(ask('SettingsState').Settings.GlobalAnnouncements==false,'SettingsState now says off')
 R.advance(1)
 for _,bad in ipairs({0,1,'off','false'})do
  local r2=ask('SetSetting',{Key='GlobalAnnouncements',Value=bad});check(r2 and r2.Success==false,'SetSetting '..tostring(bad)..' is refused')
  R.advance(1)
 end
 check(ask('SetSetting',{Key='GlobalAnnouncements'}).Success==false,'SetSetting with no value is refused')
 R.advance(1)
 check(ask('SetSetting',{Key='NoSuchSetting',Value=true}).Success==false,'an unknown setting is refused')
 R.advance(1)
 check(Data:GetPremium(a).Settings.GlobalAnnouncements==false and Data:GetPremium(a).Settings.NoSuchSetting==nil,'(nothing changed by the refusals)')
 local r3=ask('SetSetting',{Key='GlobalAnnouncements',Value=true});check(r3.Success==true and Data:GetPremium(a).Settings.GlobalAnnouncements==true,'and back on')
 R.advance(1)
 local r4=ask('SetSetting',{Key='Effects',Value=40});check(r4.Success==true and Data:GetPremium(a).Settings.Effects==40 and Data:GetPremium(a).Settings.GlobalAnnouncements==true,'the volumes still save, next to it')
end

-- 4. PullAnnouncer honours it ----------------------------------------------------------------------------------------------------------------------------
do
 local Announcer=server('PullAnnouncer')
 local p2=makePlayer(Data,1105,'Two');local p3=makePlayer(Data,1106,'Three')
 Data:GetPremium(a).Settings.GlobalAnnouncements=true;Data:GetPremium(p2).Settings.GlobalAnnouncements=false;Data:GetPremium(p3).Settings.GlobalAnnouncements=nil
 local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';local log={}
 remote.FireClient=function(_,p,payload)log[#log+1]={Player=p,Payload=payload}end
 local clock=function()return R.clock end;local time=function()return 1700000000+math.floor(R.clock)end
 local bus=E.bus(clock,time)
 local srv=Announcer.new({Data=Data,Players=Players,Http=Http,Messaging=bus:Server('here'),Remote=remote,Clock=clock,Time=time,JobId='job-here',Warn=function()end});srv:Run()
 local other=Announcer.new({Data=nil,Players={GetPlayers=function()return{}end},Http=Http,Messaging=bus:Server('there'),Remote=(function()local r=R.new('RemoteEvent');r.FireClient=function()end;return r end)(),Clock=clock,Time=time,JobId='job-there',Warn=function()end});other:Run()
 local e=Rules.Event('Pull',{Name='Far',UserId=9,Id=other:_id(),SeedId='ObsidianMawSeed',Odds=1000,At=time()})
 other:_queue(e)
 local got={};for _,l in ipairs(log)do got[l.Player]=l.Payload end
 check(got[a]and got[a].Kind=='Global','a player with it ON gets the announcement from the other server')
 check(got[p2]==nil,'a player with it OFF gets nothing')
 check(got[p3]~=nil,'a player who never set it (nil) gets it: the default is on')
 -- toggling takes effect for the very next announcement
 table.clear(log);Data:GetPremium(p2).Settings.GlobalAnnouncements=true;R.advance(6)
 other:_queue(Rules.Event('Pull',{Name='Far',UserId=9,Id=other:_id(),SeedId='ObsidianMawSeed',Odds=1000,At=time()}))
 local got2={};for _,l in ipairs(log)do got2[l.Player]=l.Payload end
 check(got2[p2]~=nil,'switched on: the next announcement reaches that player')
 table.clear(log);Data:GetPremium(a).Settings.GlobalAnnouncements=false;R.advance(6)
 other:_queue(Rules.Event('Pull',{Name='Far',UserId=9,Id=other:_id(),SeedId='ObsidianMawSeed',Odds=1000,At=time()}))
 local got3={};for _,l in ipairs(log)do got3[l.Player]=l.Payload end
 check(got3[a]==nil and got3[p2]~=nil,'switched off: the next one skips that player')
 -- the in-server announcement never looks at it
 table.clear(log)
 local mine=Rules.Event('Pull',{Name='Near',UserId=1,Id=srv:_id(),SeedId='ObsidianMawSeed',Odds=1000,At=time()})
 srv:_broadcast(mine)
 local got4={};for _,l in ipairs(log)do got4[l.Player]=l.Payload end
 check(got4[a]and got4[p2]and got4[p3]and got4[a].Kind=='Pull','a pull in THIS server is shown to everyone, whatever they set (it is a local event)')
 -- a player whose data has not loaded
 local limbo=R.new('Player');limbo.Name='Limbo';limbo.UserId=1107;limbo.Parent=Players;present[1107]=limbo;order[#order+1]=limbo
 check(srv:_wants(limbo)==false,'data not loaded yet: no global announcement (nothing is sent before the setting can be read)')
 check(srv:_wants(a)==false and srv:_wants(p2)==true,'_wants reads the live setting')
end

-- 5. R153: "Skip pack animations" (SkipCutscenes): off by default, saved like the other settings, published on the Player at load for the reveal ---------
do
 check(Settings.Defaults.SkipCutscenes==false and Settings.Read(nil).SkipCutscenes==false and Settings.Read({}).SkipCutscenes==false,'R153: the default is OFF')
 check(Settings.Valid('SkipCutscenes',true)and Settings.Valid('SkipCutscenes',false)and not Settings.Valid('SkipCutscenes',1)and not Settings.Valid('SkipCutscenes','on')and not Settings.Valid('SkipCutscenes',nil),'R153: on / off only (a boolean)')
 check(Settings.Read({SkipCutscenes=true}).SkipCutscenes==true and Settings.Read({SkipCutscenes='yes'}).SkipCutscenes==false,'R153: a saved ON reads on, a bad value reads off')
 check(Settings.ToggleAttributes.SkipCutscenes=='SettingSkipCutscenes'and Settings.AudioAttributes.SkipCutscenes==nil,'R153: published under SettingSkipCutscenes (not an audio attribute)')
 local DataE=server('PlayerDataService').new(Config,Map,{Show=function()end})
 local e=makePlayer(DataE,1108,'NewOne')
 check(DataE:GetPremium(e).Settings.SkipCutscenes==false and e:GetAttribute('SettingSkipCutscenes')==false,'R153: a new player: off, and the Player says so from the moment the data loads')
 local before={};for _,c in ipairs(remotes:GetChildren())do before[c]=true end
 server('PremiumService').new(DataE,{SyncTools=function()end},{Refresh=function()end})
 local request;for _,c in ipairs(remotes:GetChildren())do if c.Name=='PremiumRequest'and not before[c]then request=c end end
 R.advance(1)
 local r=request.OnServerInvoke(e,'SetSetting',{Key='SkipCutscenes',Value=true})
 check(r and r.Success==true and DataE:GetPremium(e).Settings.SkipCutscenes==true,'R153: SetSetting true is accepted and kept')
 R.advance(1)
 check(request.OnServerInvoke(e,'SetSetting',{Key='SkipCutscenes',Value='on'}).Success==false and DataE:GetPremium(e).Settings.SkipCutscenes==true,'R153: a non-boolean is refused')
 R.advance(1)
 check(request.OnServerInvoke(e,'SettingsState').Settings.SkipCutscenes==true,'R153: SettingsState says on')
 local saved=DataE:_buildSaveData(e)
 check(saved.Premium.Settings.SkipCutscenes==true and saved.Version==Config.ProfileVersion,'R153: saved inside Premium.Settings (no profile version change)')
 local DataF=server('PlayerDataService').new(Config,Map,{Show=function()end})
 DataF.Store.Data[DataF:_getKey({UserId=1109,Name='Again'})]=saved
 local f=makePlayer(DataF,1109,'Again')
 check(DataF:GetPremium(f).Settings.SkipCutscenes==true and f:GetAttribute('SettingSkipCutscenes')==true,'R153: it persists: the next session loads ON and publishes it on the Player')
 local old=DataE:_buildSaveData(e);old.Premium.Settings.SkipCutscenes=nil
 local DataG=server('PlayerDataService').new(Config,Map,{Show=function()end})
 DataG.Store.Data[DataG:_getKey({UserId=1110,Name='Older'})]=old
 local g=makePlayer(DataG,1110,'Older')
 check(DataG:GetPremium(g).Settings.SkipCutscenes==false and g:GetAttribute('SettingSkipCutscenes')==false,'R153: a profile saved before R153 (no key) reads off')
end

print(('R151 settings (data): %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
