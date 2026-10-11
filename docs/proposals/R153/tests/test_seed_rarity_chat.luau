--!nocheck
-- R153 (owner: "make it fixed visibly so when players pull a cosmic seed from a void pack they are still reminded of how rare it is"): the CHAT half. The REAL PullAnnouncerClient
-- (+ PullAnnounceRules) on the Roblox mock gets a payload for every one of the 54 seeds, as a pull in this server and as a pull from another server, each claiming "1/12" (what an
-- older server sent: its pack's own chance; a Cosmic from a Void pack read like that): the chat line it writes says the seed's ONE fixed chance (SeedRarity153), the same text as the
-- Index, the reveal card and the hub plaque, whatever the payload claims, and nothing is read back from the text. Prints SURFACE lines (chat): run_seed_rarity.sh compares them.
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=W.module('PullAnnounceRules');local Packs=W.module('SeedPackRules')
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.DisplayName='Me D';me.UserId=1000;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local SS=W.service('SoundService')
-- every Instance the client makes is counted (the script must make none)
local created={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)created[#created+1]=class;return inew(class,parent)end;W.env.Instance=R.Instance end
-- stand-ins for what the OLD banner used: if the client touched any of them the checks below would see it
local picCalls,thumbCalls=0,{}
W.stub('ItemPictures',{Show=function()picCalls+=1 end,Clear=function()picCalls+=1 end,Warm=function()picCalls+=1 end})
local reveal={Calls=0}
W.stub('RarityRevealAudio',{Preload=function()reveal.Calls+=1 end,Burst=function()reveal.Calls+=1 end,Play=function()reveal.Calls+=1 end})
W.stub('AudioMixer',{Get=function()reveal.Calls+=1;return 100 end,Route=function()reveal.Calls+=1 end})
W.stub('ClientFxBudget',{Get=function()reveal.Calls+=1;return 3 end})
function Players.GetUserThumbnailAsync(_,id)thumbCalls[#thumbCalls+1]=id;return 'rbxthumb://x',true end
local TCS=W.service('TextChatService')
local chatLog={};local channels=R.new('Folder');channels.Name='TextChannels';channels.Parent=TCS
local general=R.new('Folder');general.Name='RBXGeneral';general.Parent=channels
local chatError=false
general.DisplaySystemMessage=function(_,text,meta)if chatError then error('chat unavailable')end;chatLog[#chatLog+1]={Text=text,Meta=meta}end
local SG=W.service('StarterGui');local oldChat={}
SG.SetCore=function(_,name,value)oldChat[#oldChat+1]={Name=name,Value=value}end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local ctx
local function boot()
 if ctx then ctx.Script:Destroy();ctx.Remote:Destroy()end
 table.clear(chatLog);table.clear(oldChat);table.clear(thumbCalls);table.clear(created);reveal.Calls=0;picCalls=0
 local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';remote.OnClientEvent=R.signal();remote.FireServer=function()error('the client must never call FireServer')end;remote.Parent=remotes
 local script=R.new('LocalScript');script.Name='PullAnnouncerClient'
 W.load('PullAnnouncerClient',script)
 ctx={Script=script,Remote=remote}
 return ctx
end
local serial=0
local function pull(seed,extra)
 serial+=1
 local t={Kind='Pull',Id='t-'..serial,UserId=2000+serial,Name='Ann'..serial,SeedId=seed,Odds=800}
 for k,v in pairs(extra or{})do t[k]=v end
 return t
end
local function send(payload)ctx.Remote.OnClientEvent:Fire(payload)end
local function eventOf(p)return Rules.Event(p.Kind,p)end
local function seconds(s)UW.seconds(s,1/10)end

local Canon=W.module('SeedRarity153')
boot()
local all=Canon.All()
local bad,seen,n={},{},0
local function lineOf(text)return text:match('%((1/[^)]+)%)')end
for _,r in ipairs(all)do
 for _,kind in ipairs({'Pull','Global'})do
  n+=1;local before=#chatLog
  send({Kind=kind,Id='c-'..n,UserId=5000+n,Name='Ann'..n,SeedId=r.Id,Odds=12})
  seconds(1.6)
  local line=chatLog[before+1]
  local at=line and lineOf(line.Text)
  if#chatLog~=before+1 or at~=r.Text then bad[#bad+1]=r.Id..' '..kind..' says '..tostring(at)..' (fixed '..r.Text..')'end
  if kind=='Pull'then seen[r.Id]=at;print('SURFACE chat '..r.Id..' '..tostring(at))end
 end
end
check(#bad==0,'the real client writes the fixed chance for all 54 seeds, in a pull here and a pull from another server, though every payload says 1/12: '..table.concat(bad,'; '))
check(#chatLog==108,'one chat line per announcement (108)')
do -- a payload with no odds at all, and with silly ones: the fixed chance too
 local before=#chatLog
 send({Kind='Pull',Id='x-1',UserId=9,Name='Zed',SeedId='PolarStarbloomSeed'});seconds(1.6)
 send({Kind='Pull',Id='x-2',UserId=9,Name='Zed',SeedId='PolarStarbloomSeed',Odds=-5});seconds(1.6)
 send({Kind='Pull',Id='x-3',UserId=9,Name='Zed',SeedId='PolarStarbloomSeed',Odds='1/12'});seconds(1.6)
 local ok=#chatLog==before+3
 for i=before+1,#chatLog do if not chatLog[i].Text:find('(1/1M)',1,true)then ok=false end end
 check(ok,'no odds, a negative number or a string in the payload: the line still says (1/1M)')
end
-- a record names no chance, a pull of an unknown seed is dropped (nothing invented)
do
 local before=#chatLog
 send({Kind='Record',Id='r-9',UserId=4,Name='Rex',Record='BestPull',SeedId='PolarStarbloomSeed'});seconds(1.6)
 send({Kind='Pull',Id='u-9',UserId=4,Name='Rex',SeedId='NoSuchSeed',Odds=12});seconds(1.6)
 check(#chatLog==before+1 and not chatLog[#chatLog].Text:find('1/',1,true),'a record line has no chance in it; an unknown seed is dropped')
end
print(('R153 seed rarity (chat): %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
