--!nocheck
-- R153 start-up fixes (architecture_review.md items 3 and 4; owner: "if a server fails just kick them out"), on the Roblox mock with the REAL main script text of the tree under test
-- (ChestChaseServerMain.server.lua is in the bundle as the module ChestChaseServerMain: only its text is used).
--  [A3] the owner / test commands start from the main script, last, in their own thread inside a pcall: an error (or a hang) in them cannot stop the server; ChaseService no longer starts them
--  [A4] the start-up guard decides on the SERVER: Failed, or still not Ready after 90 s => every player is kicked with the owner's short message, and so is everybody who joins afterwards;
--       a normal start never kicks (also a slow one); Studio never kicks: it warns with the reason and puts the message on screen (the ChestChaseStartupNotice attribute)
-- The two blocks are cut out of the real file between their BEGIN / END marker comments and run in a sandbox (they are written to need nothing but the locals named below); the real script
-- is also run once end to end against a broken install (a Config that throws; a Config that never finishes loading), live and in Studio.
local E=require('./clover_env');local W,R,check=E.W,E.R,E.check
local function T(tag)return function(c,msg)return check(c,'['..tag..'] '..msg)end end
local function section(tag,fn)
 local ok,err=xpcall(fn,debug.traceback)
 if not ok then check(false,'['..tag..'] the section crashed: '..tostring(err))end
end
local RS=E.RS;local Run=W.service('RunService')
local src=W.B.ChestChaseServerMain
local KICK='this server broke while loading 😭 pls rejoin'
local function block(name)return src:match('%-%- BEGIN '..name..'\n(.-)\n%s*%-%- END '..name)end

-- the start-up guard in a sandbox ---------------------------------------------------------------------------------------------------------------------------------------------
local guardText=block('STARTUP_GUARD_153')
local function sandboxGuard(studio)
 local rs=R.new('Folder');local list={};local added=R.signal();local warns={}
 local players={PlayerAdded=added};function players.GetPlayers()return table.clone(list)end
 local run={IsStudio=function()return studio end}
 local g={GetService=function(_,n)if n=='RunService'then return run end;error('the guard asked for service '..tostring(n))end}
 local env=setmetatable({game=g,warn=function(...)local t={};for i=1,select('#',...)do t[#t+1]=tostring((select(i,...)))end;warns[#warns+1]=table.concat(t,' ')end},{__index=W.env})
 local fn=loadstring('local Players,ReplicatedStorage=...\nlocal startupPhase="loading Config"\n'..guardText..'\nreturn guardStartup,function(v)startupPhase=v end','=guard');setfenv(fn,env)
 local guard,setPhase=fn(players,rs)
 local S={RS=rs,Players=players,Added=added,Warns=warns,SetPhase=setPhase,List=list}
 function S.Start()rs:SetAttribute('ChestChaseStartupState','Starting');rs:SetAttribute('ChestChaseStartupError',nil);guard()end
 function S.Join(name,fire)
  local p={Name=name,Kicks={}};function p.Kick(self,m)self.Kicks[#self.Kicks+1]=m end
  list[#list+1]=p;if fire then added:Fire(p)end;return p
 end
 function S.Warned(text)for _,w in ipairs(warns)do if w:find(text,1,true)then return true end end;return false end
 return S
end
local function kicked(p)return #p.Kicks>0 end
local function kickedWith(p)return #p.Kicks>0 and p.Kicks[1]==KICK end

section('A4',function()
 local t=T('A4')
 t(guardText~=nil,'the main script has the start-up guard block (STARTUP_GUARD_153)')
 if not guardText then return end
 t(guardText:find('STARTUP_TIMEOUT = 90',1,true)~=nil,'the timeout is 90 seconds')
 t(not guardText:find('OnServerEvent',1,true)and not guardText:find('RemoteEvent',1,true)and not guardText:find('FireServer',1,true)and not guardText:find('InvokeServer',1,true),'the guard listens to no remote: the server decides alone (no client trust)')
 -- a normal start: nobody is ever kicked
 do
  local g=sandboxGuard(false);g.Start()
  local a,b=g.Join('Ann'),g.Join('Bob')
  E.advance(5);g.RS:SetAttribute('ChestChaseStartupState','Ready')
  E.advance(1)
  local late=g.Join('Late',true)
  E.advance(300)
  t(not kicked(a)and not kicked(b)and not kicked(late),'a normal start never kicks (players in, a late joiner, 300 s later)')
  t(#g.Added._c==0 or not g.Added._c[1].Connected,'... and the guard has ended: no join listener is left behind')
  t(#g.Warns==0,'... and says nothing')
 end
 -- a slow but healthy start (Ready at 85 s): still no kick
 do
  local g=sandboxGuard(false);g.Start();local a=g.Join('Ann')
  E.advance(85);g.RS:SetAttribute('ChestChaseStartupState','Ready');E.advance(30)
  t(not kicked(a)and g.RS:GetAttribute('ChestChaseStartupState')=='Ready','a start that takes 85 s is not kicked (the limit is 90)')
 end
 -- Failed: everybody in is kicked within a second, with the owner's message; a joiner is kicked at once
 do
  local g=sandboxGuard(false);g.Start();local a,b=g.Join('Ann'),g.Join('Bob')
  E.advance(10);t(not kicked(a),'(nobody is kicked while the server is starting)')
  g.RS:SetAttribute('ChestChaseStartupState','Failed');g.RS:SetAttribute('ChestChaseStartupError','STARTUP FAILED during loading Config:\nboom')
  E.advance(1.1)
  t(kickedWith(a)and kickedWith(b),'Failed: every player is kicked with "'..KICK..'" ('..tostring(a.Kicks[1])..')')
  local late=g.Join('Late',true)
  t(kickedWith(late),'a player who joins afterwards is kicked at once (PlayerAdded)')
  local quiet=g.Join('Quiet',false);E.advance(2.5)
  t(kickedWith(quiet),'... and one that slipped in without the event is kicked by the next sweep')
  t(g.Warned('THIS SERVER DID NOT START')and g.Warned('boom'),'the reason is warned in the Output')
  t(g.RS:GetAttribute('ChestChaseStartupState')=='Failed','the state stays Failed')
  E.advance(60);t(#a.Kicks==1 and #b.Kicks==1,'each player is kicked once, not again at every sweep')
  local veryLate=g.Join('VeryLate',false);E.advance(2.5)
  t(kickedWith(veryLate),'(it keeps going until the server is empty: a player who appears a minute later is kicked too)')
 end
 -- stuck: not Ready after 90 s
 do
  local g=sandboxGuard(false);g.Start();g.SetPhase('starting ChaseService');local a=g.Join('Ann')
  E.advance(89);t(not kicked(a),'at 89 s nobody is kicked')
  E.advance(2.5)
  t(kickedWith(a),'a server still not Ready after 90 s kicks everybody')
  t(g.RS:GetAttribute('ChestChaseStartupState')=='Failed','... and marks itself Failed for good')
  local err=tostring(g.RS:GetAttribute('ChestChaseStartupError'))
  t(err:find('90',1,true)~=nil and err:find('starting ChaseService',1,true)~=nil,'... with the reason and the phase it was stuck in ('..err..')')
  local late=g.Join('Late',true);t(kickedWith(late),'a late joiner is kicked')
  -- the main script would set Ready if it finished after all: the guard has already given up, the kicking goes on
  g.RS:SetAttribute('ChestChaseStartupState','Ready')
  local later=g.Join('Later',false);E.advance(5)
  t(kickedWith(later),'a start that finishes after the limit does not undo it: new joiners are still kicked')
 end
 -- Studio: no kick, a loud warning and the message on screen
 do
  local g=sandboxGuard(true);g.Start();local a=g.Join('Ann')
  g.RS:SetAttribute('ChestChaseStartupState','Failed');g.RS:SetAttribute('ChestChaseStartupError','STARTUP FAILED during loading Config:\nboom')
  E.advance(1.1)
  local late=g.Join('Late',true);E.advance(5)
  t(not kicked(a)and not kicked(late),'Studio: nobody is kicked (also not a late joiner)')
  t(g.Warned('THIS SERVER DID NOT START')and g.Warned('boom'),'Studio: the failure reason is warned in the Output')
  local notice=g.RS:GetAttribute('ChestChaseStartupNotice')
  t(type(notice)=='string'and notice:find('this server broke while loading',1,true)~=nil and notice:find('STARTUP FAILED during loading Config',1,true)~=nil,'Studio: the message and the reason go on screen (ChestChaseStartupNotice): '..tostring(notice))
  t(notice and not notice:find('boom',1,true),'... the first line of the reason only')
 end
 -- Studio, stuck, then it finishes after all: the notice goes away again
 do
  local g=sandboxGuard(true);g.Start();local a=g.Join('Ann')
  E.advance(91)
  t(not kicked(a)and type(g.RS:GetAttribute('ChestChaseStartupNotice'))=='string','Studio, stuck for 90 s: no kick, the message is on screen')
  t(g.RS:GetAttribute('ChestChaseStartupState')=='Starting','... and the state is left alone (a slow Studio start may still finish)')
  g.RS:SetAttribute('ChestChaseStartupState','Ready');E.advance(3)
  t(g.RS:GetAttribute('ChestChaseStartupNotice')==nil,'it finished after all: the message is taken off the screen')
 end
end)
section('A4',function()
 local t=T('A4')
 -- the real main script, end to end, against a broken install ---------------------------------------------------------------------------------------------------------------
 -- (each run has its own game stand-in: its own ReplicatedStorage, Players and RunService, so the guard loops of earlier runs can't touch a later one)
 local function mainRun(broken,studio)
  local rs=R.new('Folder');local list={};local added=R.signal()
  local players={PlayerAdded=added};function players.GetPlayers()return table.clone(list)end
  local g={GetService=function(_,n)
   if n=='Players'then return players elseif n=='ReplicatedStorage'then return rs elseif n=='RunService'then return {IsStudio=function()return studio end}end
   error('the main script asked for service '..tostring(n))
  end}
  local sss=R.new('Folder');sss.Name='FakeServerScriptService'
  local main=R.new('Script');main.Name='ChestChaseServerMain';main.Parent=sss
  local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=sss
  W.B.BrokenConfigForTest=broken
  local cfg=R.new('ModuleScript');cfg.Name='Config';cfg._source='BrokenConfigForTest';cfg.Parent=folder
  local who={}
  for _,n in ipairs({'Ann','Bob'})do local log={};local p={Name=n,Log=log};function p.Kick(self,m)log[#log+1]=m end;list[#list+1]=p;who[#who+1]=p end
  local fn=loadstring(src,'=ChestChaseServerMain');setfenv(fn,setmetatable({script=main,game=g},{__index=W.env}))
  local thread=coroutine.create(fn)
  local ok,err=coroutine.resume(thread)
  return {Ok=ok,Err=err,RS=rs,Who=who,Added=added,List=list}
 end
 do
  local r=mainRun("error('config exploded while loading')",false)
  t(r.Ok==false and tostring(r.Err):find('config exploded',1,true)~=nil,'(the real main script fails on a Config that throws, as it always did)')
  t(r.RS:GetAttribute('ChestChaseStartupState')=='Failed','... and marks Failed')
  E.advance(1.2)
  t(#r.Who[1].Log==1 and r.Who[1].Log[1]==KICK and #r.Who[2].Log==1,'END TO END, live: the failed server kicks its players with the message ('..tostring(r.Who[1].Log[1])..')')
  local late={Name='Late',Log={}};function late.Kick(self,m)self.Log[#self.Log+1]=m end;r.List[#r.List+1]=late;r.Added:Fire(late)
  t(#late.Log==1,'... and kicks the player who joins afterwards')
 end
 do
  local r=mainRun("task.wait(1e9)",false)
  t(r.Ok==true,'(the real main script hangs while loading Config: it is still running)')
  t(r.RS:GetAttribute('ChestChaseStartupState')=='Starting','... state Starting')
  E.advance(80);t(#r.Who[1].Log==0,'END TO END, live, stuck: nobody is kicked at 80 s')
  E.advance(12)
  t(#r.Who[1].Log==1 and r.Who[1].Log[1]==KICK and #r.Who[2].Log==1,'... everybody is kicked after 90 s ('..tostring(r.Who[1].Log[1])..')')
  local err2=tostring(r.RS:GetAttribute('ChestChaseStartupError'))
  t(err2:find('loading Config',1,true)~=nil,'... and the reason names the phase it hung in ('..err2:sub(1,100)..')')
 end
 do
  local r=mainRun("error('config exploded while loading')",true)
  E.advance(5)
  t(#r.Who[1].Log==0 and #r.Who[2].Log==0,'END TO END, Studio: the failed server kicks nobody')
  local notice=r.RS:GetAttribute('ChestChaseStartupNotice')
  t(type(notice)=='string'and notice:find('this server broke while loading',1,true)~=nil,'... and shows the message on screen ('..tostring(notice)..')')
 end
 -- the guard is started once, inside a pcall, right after the state is set to Starting
 local starting=src:find('SetAttribute("ChestChaseStartupState","Starting")',1,true)
 local started=src:find('pcall(guardStartup)',1,true)
 t(starting and started and started>starting and select(2,src:gsub('pcall%(guardStartup%)',''))==1,'the guard is started once, in a pcall, after the state became Starting')
 t(src:find('"ChestChaseStartupState") == "Failed" then',1,true)~=nil,'the main script does not mark Ready over a Failed state')
end)

-- the owner / test commands start --------------------------------------------------------------------------------------------------------------------------------------------
section('A3',function()
 local t=T('A3')
 local text=block('OWNER_TOOLS_START_153')
 t(text~=nil,'the main script has the owner tools block (OWNER_TOOLS_START_153)')
 local chase=W.B.ChaseService
 t(chase~=nil and not chase:find('StudioTestCommands',1,true)and not chase:find('startV142',1,true),'ChaseService no longer starts the owner commands (no Start override, no StudioTestCommands)')
 local startAt=src:find('chaseService:Start()',1,true);local blockAt=src:find('BEGIN OWNER_TOOLS_START_153',1,true);local readyAt=src:find('SetAttribute("ChestChaseStartupState","Ready")',1,true)
 t(startAt and blockAt and readyAt and startAt<blockAt and blockAt<readyAt,'they start after chaseService:Start() and before the state becomes Ready')
 t(src:find('chaseService.HubDisplays=hubDisplays',1,true)<(blockAt or 0),'... after the services were handed to the chase service (the commands find them there)')
 if not text then return end
 local function run(startFn,requireFn)
  local order={};local warns={}
  local modules={StudioTestCommands='STC'}
  local env=setmetatable({require=function(m)if requireFn then return requireFn(m)end;return {Start=function(...)order[#order+1]={...};return startFn and startFn(...)end}end,
   warn=function(...)local x={};for i=1,select('#',...)do x[#x+1]=tostring((select(i,...)))end;warns[#warns+1]=table.concat(x,' ')end},{__index=W.env})
  local fn=loadstring('local modules,Config,playerData,chestService,chaseService,baseService,notifications,mapService=...\n'..text..'\nAFTER=true',"=tools");setfenv(fn,env)
  env.AFTER=false
  local ok,err=pcall(fn,modules,'cfg','data','chests','chase','bases','notes','map')
  return ok,err,order,warns,env
 end
 local ok,err,order,warns,env=run()
 t(ok and #order==1,'the block starts the commands once ('..tostring(err)..')')
 local a=order[1]or{}
 t(a[1]=='cfg'and a[2]=='data'and a[3]=='chests'and a[4]=='chase'and a[5]=='bases'and a[6]=='notes'and a[7]=='map','... with the arguments StudioTestCommands.Start takes (config, data, chests, chase, bases, notifications, map)')
 local ok2,err2,_,warns2,env2=run(function()error('owner commands exploded')end)
 t(ok2==true and env2.AFTER==true,'a Start that throws does not stop the main script ('..tostring(err2)..')')
 local seen=false;for _,w in ipairs(warns2)do if w:find('owner commands exploded',1,true)then seen=true end end
 t(seen,'... the failure is warned')
 local ok3,err3,_,warns3,env3=run(nil,function()error('could not load StudioTestCommands')end)
 t(ok3==true and env3.AFTER==true,'a StudioTestCommands that does not even load does not stop it either ('..tostring(err3)..')')
 local ok4,err4,order4,_,env4=run(function()W.env.task.wait(1e9)end)
 t(ok4==true and env4.AFTER==true,'a Start that hangs does not hold the main script up (it runs in its own thread)')
end)

E.finish('R153 start-up fixes')
