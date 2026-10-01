--!nocheck
-- R118 leaderboard: SpeedBoardService (top 100, DataStore read budget, published rows) + LeaderboardClient
-- (scrollable copy on the player's screen, pooled rows, your rank, jump-to-me, cleanup). Roblox mock, offline.
-- Bundle (from a scratch folder holding roblox.luau):
--   python3 <repo>/tools/tests/bundle.py lb_bundle.luau SpeedBoardService=<src>/ServerScriptService/ChestChaseServer/SpeedBoardService.lua \
--     LeaderboardClient=<src>/StarterPlayer/StarterPlayerScripts/LeaderboardClient.client.lua SpeedPoints=<src>/ReplicatedStorage/SpeedPoints.lua \
--     CashNumbers=<src>/ReplicatedStorage/CashNumbers.lua
local R=require('./roblox');local B=require('./lb_bundle')
local new=R.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local game=new('DataModel');local services={}
local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
function game.GetService(_,n)return service(n)end
local workspace=service('Workspace')
local Run=service('RunService');Run.IsStudio=function()return false end;Run.Heartbeat=R.signal();Run.RenderStepped=R.signal()
local Gui=service('GuiService');Gui.ReducedMotionEnabled=false
local Players=service('Players');local RS=service('ReplicatedStorage')
local me=new('Player');me.Name='Me';me.UserId=42;me.Parent=Players;Players.LocalPlayer=me
function Players.GetPlayers()return {}end;function Players.GetPlayerByUserId()return nil end
local pg=new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
-- HttpService JSON: round-trip through a registry (the mock has no JSON).
local Http=service('HttpService');local store={};local n=0
function Http.JSONEncode(_,t)n+=1;store['j'..n]=t;return 'j'..n end
function Http.JSONDecode(_,s)return store[s]end
-- DataStores: 150 speed players and 150 cash players; count exact reads.
local reads=0;local exact={}
local function ordered(kind)
 return {SetAsync=function()end,GetSortedAsync=function(_,asc,size)
  local rows={}
  for i=1,150 do
   local id=1000+i;local v
   if kind=='Speed'then local pts=tostring(10^(20-i*.1)):gsub('%..*','');pts=string.format('%.0f',10^(20-i*.1));exact[tostring(id)]=pts;v=math.floor(math.log10(10^(20-i*.1))*1e9)
   else v=1e14-i*1e11 end
   rows[i]={key=tostring(id),value=v}
  end
  if kind=='Speed'then rows[5].key='42'end
  local page={};for i=1,math.min(size,#rows)do page[i]=rows[i]end
  return {GetCurrentPage=function()return page end}
 end}
end
local DS=service('DataStoreService')
function DS.GetOrderedDataStore(_,name)return ordered(name:find('Speed')and'Speed'or'Cash')end
function DS.GetDataStore()return {GetAsync=function(_,k)reads+=1;return exact[k]or(k=='42'and string.format('%.0f',10^(20-.5)))end,SetAsync=function()end}end
local US=service('UserService');function US.GetUserInfosByUserIdsAsync(_,ids)local out={};for i,id in ipairs(ids)do out[i]={Id=id,DisplayName='User'..id}end;return out end
-- Hub scenery with two boards.
local map=new('Folder');map.Name='ChestChaseMap';map.Parent=workspace
local hub=new('Folder');hub.Name='EconomyHub';hub.Parent=map
local scenery=new('Folder');scenery.Name='GeneratedHubScenery';scenery.Parent=hub
local models={}
for _,key in ipairs({'hub.top1','hub.cash.top1'})do
 local m=new('Model');m.Name=key;m:SetAttribute('SceneryKey',key);m:SetAttribute('SceneryOwner','ChestChase');m.Parent=scenery
 local board=new('Part');board.Name='Board';board.Parent=m
 local d=new('SurfaceGui');d.Name='Display';d.Face=R.Enum.NormalId.Front;d.Enabled=true;d.Parent=board
 local base=new('Part');base.Name='Base';base.Parent=m
 m:SetAttribute('LandscapeRevision',52);models[key]=m
end
local modules={}
local env
local function load(name,scriptInst)local fn=assert(loadstring(B[name],'='..name));setfenv(fn,setmetatable({script=scriptInst},{__index=env}));return fn()end
local function req(m)if modules[m]~=nil then return modules[m]end;if m._source then modules[m]=load(m._source,m);return modules[m]end;error('unknown module '..tostring(m))end
local function module(parent,name,value,source)local m=new('ModuleScript');m.Name=name;m.Parent=parent;if source then m._source=source else modules[m]=value end;return m end
module(RS,'LeaderboardLandscape',{Apply=function()end});module(RS,'SpeedPoints',nil,'SpeedPoints');module(RS,'CashNumbers',nil,'CashNumbers')
module(RS,'EconomyBalance90',{MaxCash=9e14})
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,UDim=R.UDim,UDim2=R.UDim2,Color3=R.Color3,Enum=R.Enum,
 ColorSequence=R.ColorSequence or{new=function(...)return{...}end},TweenInfo=R.TweenInfo or{new=function(...)return{...}end},
 typeof=R.typeof,task=setmetatable({wait=function(t)local co=coroutine.running();R.task.delay(t or 0,function()coroutine.resume(co)end);return coroutine.yield()end},{__index=R.task}),require=req,os={clock=function()return R.clock end,time=function()return 2000000000 end},warn=function(...)print('WARN',...)end},{__index=_G})
-- Server ---------------------------------------------------------------------------------
local S=req(module(game,'SpeedBoardService',nil,'SpeedBoardService'))
check(S.FromLog(math.log10(123456789))=='123456789','FromLog small exact ('..S.FromLog(math.log10(123456789))..')')
local big=S.FromLog(40.5);check(#big==41 and big:sub(1,4)=='3162','FromLog big ('..big:sub(1,6)..'.. len '..#big..')')
local svc=S.new({IsLoaded=function()return false end})
svc:Refresh()
check(#svc:Top('Speed')==100 and #svc:Top('Cash')==100,'top 100 for both boards ('..#svc:Top('Speed')..', '..#svc:Top('Cash')..')')
check(reads<=12,'exact speed reads within budget on a cold refresh ('..reads..')')
local r0=reads;svc:Refresh();check(reads-r0==0,'no exact re-reads when scores did not change ('..(reads-r0)..')')
local sm=models['hub.top1']
check(type(sm:GetAttribute('LeaderboardRows'))=='string'and sm:GetAttribute('LeaderboardTitle')=='TOP SPEED'and sm:GetAttribute('LeaderboardStatus')=='ok','rows/title/status published')
local rows=Http:JSONDecode(sm:GetAttribute('LeaderboardRows'));check(#rows==100 and rows[1].n=='User1001'and rows[1].s~='','100 packed rows with names and scores')
local disp=sm.Board.Display.Root or sm.Board.Display:FindFirstChildWhichIsA('Frame')
local shown=0;for _,c in ipairs(disp:FindFirstChild('Ranks'):GetChildren())do if c.Visible then shown+=1 end end
check(shown==10,'server sign keeps a short top 10 fallback ('..shown..')')
-- Client ---------------------------------------------------------------------------------
local rawNew=R.Instance.new
R.Instance.new=function(class,parent)local o=rawNew(class,parent)
 if class=='ScrollingFrame'then o.AbsoluteWindowSize=R.Vector2.new(692,770);o.CanvasPosition=R.Vector2.new(0,0);o.AbsoluteCanvasSize=R.Vector2.new(692,10000)end
 if class=='TextButton'then o.Activated=R.signal()end
 return o end
local cs=new('LocalScript');cs.Name='LeaderboardClient'
load('LeaderboardClient',cs);R.advance(.1)
local guis={};for _,g in ipairs(pg:GetChildren())do if g:IsA('SurfaceGui')then guis[#guis+1]=g end end
check(#guis==2,'one scrollable board per sign on the player screen ('..#guis..')')
check(sm.Board.Display.Enabled==false,'server sign hidden locally')
local g=pg:FindFirstChild('Leaderboard_hub.top1');check(g and g.Adornee==sm.Board,'adorned to the board part')
local list=g:FindFirstChildWhichIsA('Frame'):FindFirstChild('Ranks')
local function cards()local v,all=0,0;for _,c in ipairs(list:GetChildren())do if c.Name=='Rank'then all+=1;if c.Visible then v+=1 end end end;return v,all end
local v,all=cards();check(v>=8 and v<=14 and all<=14,'only rows on screen exist ('..v..' visible, '..all..' made)')
check(list.CanvasSize.Y.Offset==100*100,'canvas fits 100 rows ('..list.CanvasSize.Y.Offset..')')
local function texts(prefix)local out={};for _,c in ipairs(list:GetChildren())do if c.Name=='Rank'and c.Visible then out[#out+1]=c.Medal.Rank.Text end end;return out end
list.CanvasPosition=R.Vector2.new(0,9230);R.advance(.05)
local seen=texts();local has100=false;for _,t in ipairs(seen)do if t=='#100'then has100=true end end
v,all=cards();check(has100 and all<=16,'scrolled to the bottom: #100 shown, pool reused ('..all..' frames)')
local foot=g:FindFirstChildWhichIsA('Frame'):FindFirstChild('Footer')
check(foot.YourRank.Text:find('#5')~=nil,'your rank shown ('..foot.YourRank.Text..')')
check(foot.JumpToMe.Caption.Text=='FIND ME','find-me button')
list.CanvasPosition=R.Vector2.new(0,0);R.advance(.05)
local meRow;for _,c in ipairs(list:GetChildren())do if c.Name=='Rank'and c.Visible and c.You.Text~=''then meRow=c end end
check(meRow and meRow.Medal.Rank.Text=='#5','your own row is highlighted')
local medals=texts();check(medals[1]=='🥇'or table.find(medals,'🥇'),'medals for the top 3')
-- Cash board: not in it -> encouragement + TOP button.
local cg=pg:FindFirstChild('Leaderboard_hub.cash.top1');local cf=cg:FindFirstChildWhichIsA('Frame').Footer
check(cf.YourRank.Text:find('Not in the top')~=nil and cf.JumpToMe.Caption.Text=='TOP','not ranked: message + TOP button')
-- Updates and removal.
svc.Rows.Speed={{UserId=7,Score='5'}};svc:Render();R.advance(.05)
v=cards();check(v==1,'live update shrinks the list ('..v..')')
sm.Parent=nil;R.advance(6)
check(pg:FindFirstChild('Leaderboard_hub.top1')==nil,'board removed -> player copy removed')
cs:Destroy();R.advance(.1)
check(pg:FindFirstChild('Leaderboard_hub.cash.top1')==nil and models['hub.cash.top1'].Board.Display.Enabled==true,'script removed: copies destroyed, server sign restored')
print(('%d checks, %d failures'):format(checks,fails))
