--!nocheck
-- R153 performance patch, one quality signal (architecture review): the frame rate is measured once, in ClientFxBudget, and SettingsClient's Auto
-- quality reads its 3 s windows (B.OnWindow) instead of counting frames on a Heartbeat of its own. With the REAL ClientFxBudget (and SettingsClient's
-- rule, read from its source): for the same frames, the windows and the FastMode decisions are exactly those of the old SettingsClient loop
-- (git: the commit before the patch, handed in as old_settings.lua), and the tier's own thresholds (42 / 55 fps) are unchanged.
-- Usage (run_perf153.sh): luau test_quality153.luau, with quality_bundle.luau (the three sources) next to it.
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Files=require('./quality_bundle') -- (run_perf153.sh: {['ClientFxBudget.lua']=..., ['SettingsClient.client.lua']=..., ['old_settings.lua']=...})
local function read(p)return assert(Files[p],'missing '..p)end
-- a tiny environment for the module: not a client (no RenderStepped), no local player
local services={Players={},UserInputService={TouchEnabled=false,KeyboardEnabled=true},RunService={IsClient=function()return false end},CollectionService={GetTagged=function()return{}end}}
local env=setmetatable({game={GetService=function(_,n)return services[n]end},script={Destroying={Connect=function()end}},warn=function(...)print('WARN',...)end,typeof=type},{__index=_G})
local fn=assert(loadstring(read('ClientFxBudget.lua'),'=ClientFxBudget'));setfenv(fn,env);local B=fn()
check(type(B.OnWindow)=='function'and type(B.CountWindow)=='function','ClientFxBudget gives the window signal (OnWindow) and counts it (CountWindow)')
-- the old SettingsClient loop, as it was (its Heartbeat body), and the rule
local old=read('old_settings.lua')
check(old:find('window+=math.min(dt,.25);frames+=1;if window<3 then return end',1,true)~=nil,'(the old SettingsClient counted 3 s windows on its Heartbeat)')
local new=read('SettingsClient.client.lua')
check(new:find('slow=fps<38 and slow+1 or 0;healthy=fps>53 and healthy+1 or 0',1,true)~=nil and new:find('if slow>=2 and',1,true)~=nil and new:find('elseif healthy>=4 and',1,true)~=nil,
 'SettingsClient keeps its rule: under 38 fps for 2 windows -> FastMode, over 53 fps for 4 -> off')
check(new:find('FxBudget.OnWindow(judge)',1,true)~=nil and not new:find('Run.Heartbeat:Connect(function(dt)\n if values.Quality',1,true),'SettingsClient reads ClientFxBudget\'s windows (its own Heartbeat is only the fallback without the module)')
local budget=read('ClientFxBudget.lua')
check(budget:find('if s.Average>1/42 then',1,true)~=nil and budget:find('elseif s.Average<1/55 then',1,true)~=nil,'the tier\'s own thresholds are unchanged (42 / 55 fps)')
-- the same frames through both: a phone that slows down, recovers, stutters
local seed=153;local function rnd()seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end;local frames={}
local function phase(n,fps,jitter)for _=1,n do frames[#frames+1]=math.max(.001,1/fps+(rnd()-.5)*(jitter or 0))end end
phase(400,60,.002);phase(500,33,.01);phase(300,45,.01);phase(200,24,.02);phase(900,58,.004);phase(30,4,.2);phase(600,60,.002);phase(400,36,.008)
local function judge(state,fps)
 state.slow=fps<38 and state.slow+1 or 0;state.healthy=fps>53 and state.healthy+1 or 0
 if state.slow>=2 and state.fast~=true then state.fast=true;state.log[#state.log+1]='on@'..state.n elseif state.healthy>=4 and state.fast~=false then state.fast=false;state.log[#state.log+1]='off@'..state.n end
end
-- old: SettingsClient's own Heartbeat window
local A={slow=0,healthy=0,fast=nil,log={},n=0,windows={}}
do local window,count=0,0
 for i,dt in ipairs(frames)do A.n=i
  window+=math.min(dt,.25);count+=1
  if window>=3 then local fps=count/window;window=0;count=0;A.windows[#A.windows+1]=string.format('%.6f',fps);judge(A,fps)end
 end
end
-- new: ClientFxBudget's window, SettingsClient's rule on it
local Bs={slow=0,healthy=0,fast=nil,log={},n=0,windows={}}
local link=B.OnWindow(function(fps)Bs.windows[#Bs.windows+1]=string.format('%.6f',fps);judge(Bs,fps)end)
for i,dt in ipairs(frames)do Bs.n=i;B.CountWindow(dt)end
check(#A.windows>10 and table.concat(A.windows,',')==table.concat(Bs.windows,','),'the same 3 s windows, the same frame rates ('..#A.windows..' / '..#Bs.windows..')')
check(#A.log>=2 and table.concat(A.log,',')==table.concat(Bs.log,','),'FastMode switches at the same frames: '..table.concat(A.log,', ')..' / '..table.concat(Bs.log,', '))
link:Disconnect();local before=#Bs.windows;for _=1,400 do B.CountWindow(1/60)end
check(#Bs.windows==before,'a disconnected listener hears nothing more')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
