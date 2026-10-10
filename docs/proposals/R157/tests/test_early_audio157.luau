--!nocheck
-- R157b fix: the HUD died for a whole session ("AudioMixer is not a valid member of ReplicatedStorage - InteractionAudio:36", then "Requested module experienced an error while loading"
-- in Hotbar, ChestIndex, EconomyClient ...). The title (ReplicatedFirst, before game.Loaded) required InteractionAudio the moment it replicated; InteractionAudio's body warmed its voices at
-- once and required AudioMixer (not replicated yet); Roblox keeps a failed require, so every later require(InteractionAudio) failed too. On the Roblox mock with the REAL InteractionAudio,
-- AudioMixer, SoundTiming, SettingsConfig and TitleScreen104 of this checkout, in a ReplicatedStorage where modules arrive one at a time:
--  A. InteractionAudio required while AudioMixer / SettingsConfig have not arrived: the require returns at once and does not error; a second require gives the same module; once AudioMixer
--     (then SettingsConfig, or the other way round) arrives the voices are built and routed to the Interface group, and Play sounds
--  B. a failure in the warm-up (a mixer whose Route errors, a mixer that does not load) never fails the require; it is a warning
--  C. AudioMixer required before SettingsConfig has arrived waits for it and then loads
--  D. the title: no require of InteractionAudio (or SeedPackVisuals) before game.Loaded; a click before the game has loaded is silent and harmless; after Loaded the start click sounds
--     (MenuClick, once, through the Interface group); a title that has closed by then loads nothing; a game that is already loaded, or a stand-in without IsLoaded, runs on at once
local W=require('./world');local R=W.R
local E=require('./sfx_env')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end

-- ======================================================================================================================
-- the mock: modules that arrive one at a time (WaitForChild really waits), a game that finishes loading when the test says so
-- ======================================================================================================================
do -- WaitForChild that yields (the shared mock's errors "would hang"); a timeout (seconds on the mock clock) gives nil
 function R.Inst.WaitForChild(self,name,timeout)
  local found=self:FindFirstChild(name);if found then return found end
  local co=coroutine.running();local done,conn=false,nil
  local function resume(value)
   if done then return end;done=true;if conn then conn:Disconnect()end
   local ok,err=coroutine.resume(co,value);if not ok then error(err,0)end
  end
  conn=self.ChildAdded:Connect(function(child)if child.Name==name then resume(child)end end)
  if timeout then R.task.delay(timeout,function()resume(nil)end)end
  return coroutine.yield()
 end
end
local gameLoaded,loadWaiters=false,{}
W.game.IsLoaded=function()return gameLoaded end
W.game.Loaded={Wait=function()
 if gameLoaded then return end
 loadWaiters[#loadWaiters+1]=coroutine.running();coroutine.yield()
end}
local function fireLoaded()
 gameLoaded=true
 local list=loadWaiters;loadWaiters={}
 for _,co in ipairs(list)do local ok,err=coroutine.resume(co);if not ok then error(err,0)end end
end
local warnings={}
W.env.warn=function(...)local parts={};for i=1,select('#',...)do parts[i]=tostring((select(i,...)))end;warnings[#warnings+1]=table.concat(parts,' ')end
local function warned(prefix)local n=0;for _,m in ipairs(warnings)do if m:sub(1,#prefix)==prefix then n+=1 end end;return n end
local requires={}
do local base=W.env.require
 W.env.require=function(m)if type(m)=='table'and m._class=='ModuleScript'then requires[m.Name]=(requires[m.Name]or 0)+1 end;return base(m)end
end
-- sources that exist only in this test
W.B.BrokenRouteMixer="return {Route=function()error('mixer boom')end,Group=function()return nil end}"
W.B.BrokenConfig="error('config boom')"
W.B.StubSeedPackVisuals="return {Bag=function()error('no pack art in this test')end}"
local function newModule(parent,name,source)local m=R.new('ModuleScript');m.Name=name;m._source=source or name;m.Parent=parent;return m end
local function newFolder(name)local f=R.new('Folder');f.Name=name or 'ReplicatedStorageStandIn';return f end
local function voices()local out={};for _,s in ipairs(E.sounds)do if s.Name:match('^Interaction_')then out[#out+1]=s end end;return out end
local function tryRequire(m)local co=coroutine.create(function()return W.require(m)end);local ok,res=coroutine.resume(co);return co,ok,res end
local function reset()table.clear(warnings);table.clear(requires);E.resetPlays();table.clear(E.sounds)end

-- ======================================================================================================================
-- A. InteractionAudio required before AudioMixer / SettingsConfig have arrived
-- ======================================================================================================================
print('-- A. InteractionAudio before AudioMixer')
do
 reset();E.player('A');gameLoaded=false
 local rs=newFolder();newModule(rs,'SoundTiming');local ia=newModule(rs,'InteractionAudio')
 local co,ok,res=tryRequire(ia)
 check(ok,'A1 the require does not error (AudioMixer and SettingsConfig are not there): '..tostring(res))
 check(coroutine.status(co)=='dead','A1 the require returns at once: it does not wait for AudioMixer')
 check(type(res)=='table'and type(res.Play)=='function'and type(res.Preload)=='function','A1 it returns the module')
 if type(res)~='table'then print('FAIL: the rest of A needs the module');print(('R157 early audio: %d checks, %d failures'):format(checks,fails+1));error('failed')end
 check(#voices()==0,'A1 no voice yet ('..#voices()..')')
 check(#warnings==0,'A1 no warning ('..table.concat(warnings,' | ')..')')
 local ok2,again=pcall(W.require,ia)
 check(ok2 and again==res,'A2 a second require (a HUD script) gives the same working module')
 -- a script that plays a cue this early (not on a real join: they wait for game.Loaded) waits for the mixer too and must find a COMPLETE pool when it goes on
 local early;local earlyCo=coroutine.create(function()early={pcall(res.Play,'Equip')}end);coroutine.resume(earlyCo)
 check(coroutine.status(earlyCo)=='suspended'and #voices()==0,'A2 an early Play waits for AudioMixer (nothing built, no error)')
 local mixerModule=newModule(rs,'AudioMixer')
 check(#voices()==0 and #warnings==0,'A3 AudioMixer arrives, SettingsConfig has not: still waiting, no error ('..#warnings..' warnings)')
 newModule(rs,'SettingsConfig')
 check(coroutine.status(earlyCo)=='dead'and early and early[1]==true and early[2]==true,'A4 the early Play goes on once the mixer is there and sounds ('..tostring(early and early[1])..' '..tostring(early and early[2])..')')
 check(E.plays('Interaction_Equip')==1,'A4 the Equip voice played once ('..E.plays('Interaction_Equip')..')')
 local count=0;for key in pairs(res.AssetIds)do if res.Asset(key)then count+=1 end end
 check(count==10 and #voices()==count*3,'A4 SettingsConfig arrives: the 3 voices of each of the '..count..' cues are built ('..#voices()..')')
 local mixer=W.require(mixerModule);local group=mixer.Group('Interface')
 local routed=0;for _,v in ipairs(voices())do if v.SoundGroup==group and v.Parent==W.service('SoundService')then routed+=1 end end
 check(group and group.Name=='GardenInterface'and routed==#voices()and routed>0,'A4 every voice is routed to the Interface group ('..routed..' of '..#voices()..')')
 check(#warnings==0,'A4 no warning ('..table.concat(warnings,' | ')..')')
 R.advance(1)
 check(res.Play('MenuClick')==true,'A5 Play(MenuClick) works afterwards')
 check(E.plays('Interaction_MenuClick')==1,'A5 and the MenuClick voice played once ('..E.plays('Interaction_MenuClick')..')')
 -- the other order: SettingsConfig first, then AudioMixer
 reset();E.player('A2')
 local rs2=newFolder();newModule(rs2,'SoundTiming');local ia2=newModule(rs2,'InteractionAudio')
 local _,ok3,res2=tryRequire(ia2);newModule(rs2,'SettingsConfig')
 check(ok3 and type(res2)=='table'and #voices()==0,'A6 SettingsConfig first: nothing yet, no error')
 newModule(rs2,'AudioMixer')
 check(#voices()==30,'A6 AudioMixer last: the voices are built ('..#voices()..')')
 check(#warnings==0,'A6 no warning ('..table.concat(warnings,' | ')..')')
end

-- ======================================================================================================================
-- B. a failing warm-up never fails the require
-- ======================================================================================================================
print('-- B. a failing warm-up')
do
 reset();E.player('B');gameLoaded=true
 local rs=newFolder();newModule(rs,'SoundTiming');newModule(rs,'SettingsConfig');newModule(rs,'AudioMixer','BrokenRouteMixer')
 local ia=newModule(rs,'InteractionAudio')
 local co,ok,res=tryRequire(ia)
 check(ok and coroutine.status(co)=='dead'and type(res)=='table'and type(res.Play)=='function','B1 the require survives a mixer that errors in the warm-up: '..tostring(res))
 check(warned('[InteractionAudio] preload')==1,'B1 the failure is one warning ('..table.concat(warnings,' | ')..')')
 local ok2,again=pcall(W.require,ia)
 check(ok2 and again==res,'B2 and a later require still gives the module')
 -- a mixer that fails to load at all (its SettingsConfig errors)
 reset();E.player('B2')
 local rs2=newFolder();newModule(rs2,'SoundTiming');newModule(rs2,'SettingsConfig','BrokenConfig');newModule(rs2,'AudioMixer')
 local ia2=newModule(rs2,'InteractionAudio')
 local _,ok3,res3=tryRequire(ia2)
 check(ok3 and type(res3)=='table','B3 AudioMixer failing to load does not fail the require either: '..tostring(res3))
 check(warned('[InteractionAudio] preload')==1,'B3 one warning ('..table.concat(warnings,' | ')..')')
end

-- ======================================================================================================================
-- C. AudioMixer before SettingsConfig has arrived
-- ======================================================================================================================
print('-- C. AudioMixer before SettingsConfig')
do
 reset();E.player('C')
 local rs=newFolder();local mixer=newModule(rs,'AudioMixer')
 local co,ok,res=tryRequire(mixer)
 check(ok and coroutine.status(co)=='suspended','C1 AudioMixer waits for SettingsConfig instead of erroring ('..tostring(res)..')')
 newModule(rs,'SettingsConfig')
 check(coroutine.status(co)=='dead','C2 it loads once SettingsConfig has arrived')
 local got=W.require(mixer)
 check(type(got)=='table'and got.Get('Music')==100 and got.Get('Interface')==100,'C3 and works (the default mix)')
end

-- ======================================================================================================================
-- D. the title
-- ======================================================================================================================
print('-- D. the title')
rawset(R.Enum.PlayerActions,'GetEnumItems',function()return {}end)
W.service('ReplicatedFirst').RemoveDefaultLoadingScreen=function()end
W.service('Lighting');W.service('ProximityPromptService').Enabled=true
W.UIS.GamepadEnabled=false;W.Gui.MenuIsOpen=false
W.service('ContextActionService').BindActionAtPriority=function(_,name,fn)W.actions[name]=fn end
local binds={}
function W.Run.BindToRenderStep(_,name,_,fn)binds[name]=fn end
function W.Run.UnbindFromRenderStep(_,name)binds[name]=nil end
local BINDING='StealAPackTitle104'
local RS=W.RS
-- ReplicatedStorage at one moment of the join: only the named modules have arrived (addModules: more arrive)
local function addModules(...)
 for _,n in ipairs({...})do
  if n=='SeedPackVisuals'then newModule(RS,n,'StubSeedPackVisuals')
  elseif n=='SeedPackMeshAssets'then local f=newFolder(n);f.Parent=RS;newFolder('Forest_06').Parent=f
  else newModule(RS,n)end
 end
end
local function setRS(...)
 for _,n in ipairs({'InteractionAudio','AudioMixer','SettingsConfig','SoundTiming','SeedPackVisuals','SeedPackMeshAssets'})do
  local m=RS:FindFirstChild(n);if m then m:Destroy()end
 end
 addModules(...)
end
local function startTitle(label)
 reset();local player=E.player(label);local pg=E.pg
 W.Gui.MenuIsOpen=false
 local T=W.load('TitleScreen104',R.new('ModuleScript'))
 local stop=T.Start(player,pg)
 local screen=pg:FindFirstChild('StealAPackTitle')
 local group=screen:FindFirstChild('TitleContent')
 local h={pg=pg,stop=stop,button=group:FindFirstChild('ClickToStart')}
 function h.alive()return binds[BINDING]~=nil end
 function h.step(n,dt)dt=dt or 1/30;for _=1,n do R.advance(dt);local f=binds[BINDING];if not f then return false end;f(dt)end;return binds[BINDING]~=nil end
 function h.finish()local n=0;while binds[BINDING]and n<900 do h.step(1);n+=1 end;return not binds[BINDING]end
 return h
end
local function titleWarnings()return warned('[Title]')end

-- D1. a click before the game has loaded
do
 setRS('InteractionAudio','SoundTiming','SeedPackVisuals','SeedPackMeshAssets');gameLoaded=false;loadWaiters={}
 local t=startTitle('D1')
 check(requires.InteractionAudio==nil,'D1 title started, game still loading: InteractionAudio is NOT required ('..tostring(requires.InteractionAudio)..')')
 check(requires.SeedPackVisuals==nil,'D1 nor SeedPackVisuals (the pack preview also waits for the game)')
 t.step(60)
 check(t.alive()and requires.InteractionAudio==nil,'D1 a second later: still not')
 t.button.Activated:Fire() -- the player clicks before the game has loaded
 check(E.totalPlays()==0 and #voices()==0,'D1 a click before the game has loaded has no click sound (and nothing built)')
 check(titleWarnings()==0,'D1 and no warning ('..table.concat(warnings,' | ')..')')
 addModules('AudioMixer','SettingsConfig') -- the rest of the game arrives ...
 check(requires.InteractionAudio==nil,'D1 ... still not required while Loaded has not fired')
 fireLoaded()
 check(requires.InteractionAudio==1,'D1 game.Loaded: the title requires InteractionAudio, once ('..tostring(requires.InteractionAudio)..')')
 check(requires.SeedPackVisuals==1,'D1 and the pack preview its SeedPackVisuals (as before)')
 check(t.finish(),'D1 the title closes')
 check(titleWarnings()==0,'D1 no [Title] warning ('..table.concat(warnings,' | ')..')')
 -- a HUD script (after Loaded) requires it: it works
 local ok,mod=pcall(W.require,RS:FindFirstChild('InteractionAudio'))
 check(ok and type(mod)=='table'and type(mod.Play)=='function','D1 a HUD script requiring InteractionAudio afterwards gets a working module: '..tostring(mod))
 check(#voices()==30,'D1 its voices are built ('..#voices()..')')
end

-- D2. the click after the game has loaded sounds
do
 setRS('InteractionAudio','SoundTiming');gameLoaded=false;loadWaiters={}
 local t=startTitle('D2')
 check(requires.InteractionAudio==nil,'D2 not required while loading')
 addModules('AudioMixer','SettingsConfig');fireLoaded()
 check(requires.InteractionAudio==1,'D2 required once after Loaded')
 t.step(60)
 t.button.Activated:Fire()
 check(E.plays('Interaction_MenuClick')==1,'D2 the start click sounds: one MenuClick ('..E.plays('Interaction_MenuClick')..')')
 local group=W.service('SoundService'):FindFirstChild('GardenInterface')
 local routed=group~=nil;for _,s in ipairs(E.named('Interaction_MenuClick'))do if s.SoundGroup~=group then routed=false end end
 check(routed,'D2 through the Interface group')
 check(t.finish()and titleWarnings()==0,'D2 the title closes without a warning')
end

-- D3. a title that has closed before the game finished loading loads nothing
do
 setRS('InteractionAudio','SoundTiming','SeedPackVisuals','SeedPackMeshAssets');gameLoaded=false;loadWaiters={}
 local t=startTitle('D3')
 t.button.Activated:Fire();check(t.finish(),'D3 the title closes (the click, then its leave animation) while the game loads')
 addModules('AudioMixer','SettingsConfig');fireLoaded()
 check(requires.InteractionAudio==nil,'D3 after Loaded a closed title does not require InteractionAudio')
 check(requires.SeedPackVisuals==nil,'D3 nor SeedPackVisuals')
 check(titleWarnings()==0 and E.totalPlays()==0,'D3 no warning, no sound')
end

-- D4. the game is already loaded: no wait; IsLoaded unavailable (older mocks): no wait
do
 setRS('InteractionAudio','SoundTiming','AudioMixer','SettingsConfig');gameLoaded=true;loadWaiters={}
 local t=startTitle('D4')
 check(requires.InteractionAudio==1,'D4 a game that is already loaded: required at once')
 t.step(60);t.button.Activated:Fire()
 check(E.plays('Interaction_MenuClick')==1,'D4 and the click sounds')
 check(t.finish()and titleWarnings()==0,'D4 clean close')
 setRS('InteractionAudio','SoundTiming','AudioMixer','SettingsConfig');gameLoaded=false;loadWaiters={}
 local realIsLoaded=W.game.IsLoaded
 W.game.IsLoaded=function()error('IsLoaded is not available')end
 local startedOk,t2=pcall(startTitle,'D4b')
 if not startedOk then check(false,'D4 a stand-in whose IsLoaded errors: the title must still start ('..tostring(t2)..')');W.game.IsLoaded=realIsLoaded;gameLoaded=true;print(('R157 early audio: %d checks, %d failures'):format(checks,fails));error('failed')end
 check(requires.InteractionAudio==1 and #loadWaiters==0,'D4 a stand-in whose IsLoaded errors: the title does not wait (the R152 guard style)')
 t2.step(60);t2.button.Activated:Fire()
 check(E.plays('Interaction_MenuClick')==1,'D4 and the click sounds')
 check(t2.finish()and titleWarnings()==0,'D4 clean close')
 W.game.IsLoaded=realIsLoaded;gameLoaded=true
end

print(('R157 early audio: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
