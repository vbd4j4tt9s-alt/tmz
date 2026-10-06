--!nocheck
-- R151 pull announcements, part 3: the CLIENT (the REAL PullAnnouncerClient + PullAnnounceRules) on the Roblox mock. The owner: "pull announcement should only be said in chat", so the
-- client does one thing: write ONE chat line per announcement. What is checked:
--  1. chat only: no ScreenGui and no Instance of any kind is created, nothing is tweened, nothing runs per frame, no sound is asked for, no picture or headshot is fetched,
--     nothing is written to the PlayerGui, nothing is sent to the server
--  2. one pull: exactly one chat line on RBXGeneral, the rarity colour, the bold rarity word, the metadata, shown at once (the server decides when to send it)
--  3. every event kind and rarity: the right colour (rarity / gold / amber), the right sentence, a well formed rich-text line
--  4. exactly once: the same id again is dropped, distinct ids each give one line, the memory is the last 128 ids, the chat limit (8 lines per 10 s) holds and recovers
--  5. escaping: markup in a name or a record key never reaches the chat as a tag; a very long name is cut and the line stays one well formed run
--  6. the old chat (no RBXGeneral, or writing failed): one plain coloured line, never two lines (not both chats), nothing throws when there is no chat at all
--  7. hostile payloads (wrong types, unknown seeds and kinds, no id), the rarity claimed by a payload is ignored (the catalog decides), teardown
--  8. the puller's own screen: a line about THIS player that arrives before their cinematic's hit (LocalPlayer attribute RarePullClimaxAt) + the margin waits for it; lines about
--     other players, from other servers, with no cinematic running or after the hit are never held; a skip (the attribute moves earlier) shortens the wait; nothing is held longer
--     than 8 s; a held line is still written once, rate limited, and never after teardown
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=W.module('PullAnnounceRules');local Packs=W.module('SeedPackRules');local Canon=W.module('SeedRarity153') -- R153: a line says the seed's fixed chance, whatever the payload's Odds says
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
local function seedOf(rarity)for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)==rarity then return spec.id end end end
local LEG,MYTH,SEC,COS,KING=seedOf('Legendary'),seedOf('Mythic'),seedOf('Secret'),seedOf('Cosmic'),seedOf('King')
-- a rich-text line is well formed when the only tags are our own (one colour run, a bold word), no other < or >, and every & starts a known entity
local ENTITIES={amp=true,lt=true,gt=true,quot=true,apos=true}
local function count(text,pattern)local _,n=text:gsub(pattern,'');return n end
local function wellFormed(rich)
 if count(rich,'<font color="#%x%x%x%x%x%x">')~=1 or count(rich,'</font>')~=1 or rich:sub(1,6)~='<font 'or rich:sub(-7)~='</font>'then return false end
 if count(rich,'<b>')~=1 or count(rich,'</b>')~=1 then return false end
 local body=rich:gsub('<font color="#%x%x%x%x%x%x">',''):gsub('</font>',''):gsub('<b>',''):gsub('</b>','')
 if body:find('[<>]')then return false end
 local pos=1
 while true do local at=body:find('&',pos,true);if not at then break end;local name=body:match('^&(%a+);',at);if not name or not ENTITIES[name]then return false end;pos=at+1 end
 return true
end
local function hexOf(rarity)return Rules.Hex(Packs.Rarities[rarity].Color)end

-- 1. chat only ----------------------------------------------------------------------------------------------------------------------------------------
boot()
check(#pg:GetChildren()==0 and#created==0,'booting creates nothing: no ScreenGui, no Instance at all')
check(UW.frameListeners()==0,'an idle client has no per-frame connection ('..UW.frameListeners()..')')
check(#ctx.Remote.OnClientEvent._c==1,'one listener on the remote, nothing else is waited for')
do
 local tweens0=UW.tweensCreated;local delays0=UW.delays
 for i,seed in ipairs({LEG,MYTH,SEC,COS,KING})do send(pull(seed));seconds(.2);if i%3==0 then seconds(4)end end
 send({Kind='Global',Id='g-1',UserId=3,Name='Far',SeedId=SEC,Odds=1000});send({Kind='Record',Id='r-1',UserId=4,Name='Rex',Record='BestPull',SeedId=KING})
 check(#pg:GetChildren()==0,'seven announcements (five rarities, another server, a record): the PlayerGui is still empty (no banner, no ScreenGui)')
 check(#created==0,'... and the client created no Instance of any kind (no Gui, no Sound, no Folder): '..table.concat(created,','))
 check(#SS:GetChildren()==0,'... no Sound in SoundService')
 check(UW.tweensCreated==tweens0,'... nothing was tweened (no slide)')
 check(UW.frameListeners()==0,'... nothing runs per frame (no sparkles, no shine)')
 check(reveal.Calls==0,'... no sound system was asked for anything (RarityRevealAudio, AudioMixer: untouched)')
 check(picCalls==0 and#thumbCalls==0,'... no seed picture and no headshot was asked for')
 check(next(pg:GetAttributes())==nil,'... nothing was written to the PlayerGui (no PullBannerBottom or any other attribute)')
 check(UW.delays==delays0,'... and no timer was started')
 check(#chatLog==7,'... only chat lines: '..#chatLog)
end

-- 2. one pull ----------------------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 local p=pull(MYTH);local e=eventOf(p)
 local t0=R.clock
 send(p)
 check(#chatLog==1 and chatLog[1].Text==Rules.Chat(e)and chatLog[1].Meta=='PullAnnounce151','one chat line, '..tostring(chatLog[1]and chatLog[1].Text))
 check(R.clock==t0,'... at once: the client adds no delay (the server decides when to send it: after the puller\'s reveal)')
 check(chatLog[1].Text:find('<font color="'..hexOf('Mythic')..'">',1,true)==1,'the line is in the Mythic colour '..hexOf('Mythic'))
 check(chatLog[1].Text:find('<b>MYTHIC</b>',1,true)~=nil and chatLog[1].Text:find('🌟',1,true)~=nil and chatLog[1].Text:find('('..Canon.Text(MYTH)..')',1,true)~=nil,'... the rarity word is bold, with the 🌟 and the odds (the seed\'s fixed chance, '..Canon.Text(MYTH)..': the payload said 1/800)')
 check(wellFormed(chatLog[1].Text),'... and it is well formed rich text')
 check(#oldChat==0,'the old chat is not used when RBXGeneral works (one line, not two)')
 seconds(10);check(#chatLog==1,'nothing more appears later (no second line, no repeat)')
 -- your OWN pull is the same single line (the sound / banner exceptions of the old banner are gone)
 send(pull(KING,{UserId=me.UserId,Name='Me D'}))
 check(#chatLog==2 and chatLog[2].Text:find('Me D',1,true)~=nil,'your own pull is one chat line too')
end

-- 3. every kind and rarity ------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 local want={{'Legendary',LEG},{'Mythic',MYTH},{'Secret',SEC},{'Cosmic',COS},{'King',KING}}
 local used={}
 for i,row in ipairs(want)do
  local rarity,seed=row[1],row[2]
  local p=pull(seed);local e=eventOf(p);send(p)
  local line=chatLog[#chatLog].Text
  check(line==Rules.Chat(e)and line:find('<font color="'..hexOf(rarity)..'">',1,true)==1 and line:find('<b>'..string.upper(rarity)..'</b>',1,true)~=nil and wellFormed(line),rarity..': '..hexOf(rarity)..' and the word '..string.upper(rarity)..' ('..line..')')
  used[hexOf(rarity)]=true
  seconds(2.5)
 end
 local distinct=0;for _ in pairs(used)do distinct+=1 end
 check(distinct==5,'the five rarities have five different colours')
 -- another server: gold, the 🌐 sentence with the odds before the "!"
 seconds(10)
 local g=pull(SEC,{Kind='Global',Odds=1000});local ge=eventOf(g);send(g)
 local gl=chatLog[#chatLog].Text
 check(gl==Rules.Chat(ge)and gl:find('<font color="'..Rules.Hex(Rules.Gold)..'">',1,true)==1 and gl:find('🌐',1,true)~=nil and gl:find('</b> ',1,true)~=nil and gl:find('('..Canon.Text(SEC)..')!',1,true)~=nil and wellFormed(gl),'another server: gold, "🌐 ... pulled a SECRET ... ('..Canon.Text(SEC)..')!" ('..gl..')')
 -- a record: amber
 local r={Kind='Record',Id='rec-1',UserId=3000,Name='Rex',Record='BestPull',SeedId=KING,Odds=5e6};send(r)
 local rl=chatLog[#chatLog].Text
 check(rl=='<font color="'..Rules.Hex(Rules.Amber)..'">🏆 Rex just took BEST PULL TODAY!</font>','a record: amber, "🏆 Rex just took BEST PULL TODAY!" ('..rl..')')
 send({Kind='Record',Id='rec-2',UserId=3001,Name='Roy',Record='BiggestFruit'})
 check(chatLog[#chatLog].Text:find('🏆 Roy just took BIGGEST FRUIT TODAY!',1,true)~=nil,'"just took BIGGEST FRUIT TODAY!" (a record needs no seed)')
 check(#chatLog==8,'eight events (five rarities, another server, two records), eight lines ('..#chatLog..')')
end

-- 4. exactly once ------------------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 local d=pull(MYTH);send(d);send(table.clone(d));send(table.clone(d))
 check(#chatLog==1,'the same announcement id three times: ONE chat line')
 local d2=table.clone(d);d2.Kind='Global';send(d2)
 check(#chatLog==1,'... also when it comes again as another kind (an id is one announcement)')
 send(pull(MYTH));send(pull(MYTH))
 check(#chatLog==3,'two new ids: two more lines')
 seconds(11)
 -- the memory is the last 128 ids
 boot()
 local first=pull(LEG);send(first)
 for i=1,127 do send(pull(LEG,{Id='m-'..i}));if i%7==0 then seconds(11)end end
 send(table.clone(first));local before=#chatLog
 check(before==128,'128 ids seen so far ('..before..' lines): the first one is still remembered')
 seconds(11);send(pull(LEG,{Id='m-extra'}));seconds(11)
 send(table.clone(first));check(#chatLog==before+2,'after 129 newer ids the oldest is forgotten (a late repeat that old would show; nothing sends one)')
 -- the rate limit: 8 lines in 10 s
 boot();seconds(11)
 for i=1,12 do send(pull(LEG))end
 check(#chatLog==8,'12 announcements at once: 8 chat lines in 10 s, not more ('..#chatLog..')')
 seconds(10.5);send(pull(LEG));check(#chatLog==9,'... and the next one after the window is written again')
 -- an event that was dropped by the limit is gone, not queued for later
 seconds(30);check(#chatLog==9,'(nothing queued: the four dropped lines never appear later)')
end

-- 5. escaping and long names ------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 send({Kind='Pull',Id='x1',UserId=7,Name='<b>Hax</b> <font color="#FF0000">RED</font> &amp; "q"',SeedId=LEG,Odds=3})
 local line=chatLog[#chatLog].Text
 check(wellFormed(line)and line:find('#FF0000',1,true)==nil and line:find('<b>Hax',1,true)==nil,'markup in a name never reaches the chat as a tag ('..line..')')
 seconds(2)
 send({Kind='Record',Id='x2',UserId=7,Name='Zed',Record='<font color="#FF0000">Hack</font>'})
 check(chatLog[#chatLog].Text=='<font color="'..Rules.Hex(Rules.Amber)..'">🏆 Zed just took A NEW RECORD!</font>','a record key with markup is the plain "A NEW RECORD" (no free text is ever shown)')
 seconds(2)
 send({Kind='Pull',Id='x3',UserId=7,Name=string.rep('W',80),SeedId=KING,Odds=1e15})
 local long=chatLog[#chatLog].Text
 check(wellFormed(long)and long:find(string.rep('W',23)..'…',1,true)~=nil and long:find(string.rep('W',24),1,true)==nil,'an 80-letter name is cut to 24 characters ending with an ellipsis, in one well formed line ('..#long..' bytes)')
 seconds(2)
 send({Kind='Pull',Id='x4',UserId=7,Name=string.rep('é',60),SeedId=KING,Odds=5})
 check(wellFormed(chatLog[#chatLog].Text)and chatLog[#chatLog].Text:find(string.rep('é',23)..'…',1,true)~=nil,'accented letters are cut by character, not by byte')
 seconds(2)
 send({Kind='Pull',Id='x5',UserId=7,Name='a\u{202E}b\u{200B}c',SeedId=LEG,Odds=5})
 check(chatLog[#chatLog].Text:find('a b c',1,true)~=nil and chatLog[#chatLog].Text:find('\u{202E}',1,true)==nil,'text-direction and zero-width characters are blanked')
 seconds(2)
 send({Kind='Pull',Id='x6',UserId=7,Name='🌟Star🌟',SeedId=LEG})
 check(chatLog[#chatLog].Text:find('🌟Star🌟 just pulled',1,true)~=nil,'emoji in a name stay')
end

-- 6. the old chat ------------------------------------------------------------------------------------------------------------------------------------------
do
 general.Parent=nil;boot()
 local p=pull(LEG);send(p);local e=eventOf(p)
 check(#chatLog==0 and#oldChat==1 and oldChat[1].Name=='ChatMakeSystemMessage','without an RBXGeneral channel the old chat gets ONE line')
 check(oldChat[1].Value.Text==Rules.Plain(e)and oldChat[1].Value.Text:find('<',1,true)==nil,'... a plain sentence, no markup ('..tostring(oldChat[1].Value.Text)..')')
 check(oldChat[1].Value.Color==Rules.RarityColor('Legendary'),'... in the rarity colour')
 send(pull(SEC,{Kind='Global',Odds=1000}));check(oldChat[2].Value.Color==Rules.Gold,'another server: gold in the old chat')
 send({Kind='Record',Id='o-r',UserId=1,Name='Rex',Record='BestPull'});check(oldChat[3].Value.Color==Rules.Amber and oldChat[3].Value.Text=='🏆 Rex just took BEST PULL TODAY!','a record: amber')
 -- the channel appears later (TextChatService finishes loading): the next line goes there, and only there
 general.Parent=channels;seconds(11)
 send(pull(MYTH));check(#chatLog==1 and#oldChat==3,'when RBXGeneral exists the line goes to it and not to the old chat')
 -- a DisplaySystemMessage that fails: ONE line in the old chat
 seconds(11);chatError=true;boot()
 send(pull(LEG));check(#chatLog==0 and#oldChat==1,'a DisplaySystemMessage that fails falls back to the old chat: one line');chatError=false
 -- no chat at all
 seconds(11);general.Parent=nil;local saved=SG.SetCore;SG.SetCore=function()error('no old chat either')end
 boot();local ok=pcall(send,pull(LEG));check(ok and#chatLog==0,'no chat at all: nothing throws, nothing is shown')
 SG.SetCore=saved;general.Parent=channels
end

-- 7. hostile payloads, the claimed rarity, teardown ----------------------------------------------------------------------------------------------------
do
 boot()
 local bad={5,'x',true,{},{Kind='Pull'},{Kind='Pull',Name='x'},{Kind='Pull',Name='x',SeedId='NoSuchSeed'},{Kind='Evil',Name='x',SeedId=LEG},{Kind='Pull',Name=nil,SeedId=LEG},{Kind='Pull',Name='   ',SeedId=LEG},
  {Kind='Global',Name='x',SeedId=string.rep('a',100)},{Kind='Pull',Name='NoId',SeedId=LEG},{Kind='Pull',Id='bad id!',Name='x',SeedId=LEG},{Kind='Pull',Id=5,Name='x',SeedId=LEG}}
 for i,payload in ipairs(bad)do local ok=pcall(send,payload);check(ok,'hostile payload #'..i..' does not throw')end
 check(#chatLog==0 and#oldChat==0,'... and none of them writes a line (an announcement needs a valid id, name, seed and kind)')
 -- the rarity claim is ignored: a Common seed sent with Rarity='King' reads COMMON
 send({Kind='Pull',Id='liar-1',UserId=7,Name='Liar',SeedId='SunflowerSeed',Rarity='King',Odds=3})
 local line=chatLog[#chatLog].Text
 check(line:find('<b>'..string.upper(Packs.GetRarity('SunflowerSeed'))..'</b>',1,true)~=nil and line:find('KING',1,true)==nil,'a rarity sent in a payload is ignored: the catalog decides ('..line..')')
 -- teardown: the listener goes, later events are ignored
 ctx.Script:Destroy()
 check(UW.live(ctx.Remote.OnClientEvent)==0,'destroying the script removes the remote listener')
 local before=#chatLog;local ok=pcall(send,pull(KING));check(ok and#chatLog==before,'an event after teardown is ignored')
 check(UW.frameListeners()==0,'(nothing left running)')
 ctx.Remote:Destroy();ctx=nil
end

-- 8. the puller's own screen -------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 local margin=Rules.Setting('RevealMargin')
 local function hit(inSeconds)me:SetAttribute('RarePullClimaxAt',W.workspace:GetServerTimeNow()+inSeconds)end
 -- no cinematic running: at once (the server's timing is the only one)
 me:SetAttribute('RarePullClimaxAt',nil)
 send(pull(KING,{UserId=me.UserId,Name='Me D'}));check(#chatLog==1,'no cinematic running: your own line is written at once')
 seconds(11)
 -- a cinematic whose hit is 2 s away: your own line waits for it plus the margin
 hit(2);local t0=R.clock
 send(pull(MYTH,{UserId=me.UserId,Name='Me D'}))
 check(#chatLog==1,'your hit is 2 s away: your own line is not written yet')
 seconds(2+margin-.3);check(#chatLog==1,'... not at your hit either, nor just before the margin is over')
 seconds(.5);check(#chatLog==2 and chatLog[2].Text:find('Me D',1,true)~=nil,'... it is written once your hit + the margin has passed ('..string.format('%.2f',R.clock-t0)..' s)')
 seconds(10);check(#chatLog==2,'... exactly once')
 -- other players, other servers, a record about you, the hit already past
 seconds(11)
 hit(5);local n=#chatLog
 send(pull(LEG,{UserId=555,Name='Someone'}));check(#chatLog==n+1,'a line about SOMEONE ELSE is never held (their reveal is their own)')
 send(pull(SEC,{Kind='Global',UserId=me.UserId,Odds=1000}));check(#chatLog==n+2,'a line from another server is never held')
 send({Kind='Record',Id='own-rec',UserId=me.UserId,Name='Me D',Record='BestPull',SeedId=KING});check(#chatLog==n+2,'a record about YOU is held like your pull line')
 seconds(5+margin+.2);check(#chatLog==n+3 and chatLog[#chatLog].Text:find('took BEST PULL TODAY',1,true)~=nil,'... and is written after your hit')
 seconds(11);hit(-3)
 send(pull(KING,{UserId=me.UserId,Name='Me D'}));check(#chatLog==n+4,'your hit is already past (a margin ago): written at once')
 -- a skip moves the hit earlier: the wait follows the attribute at the moment the line arrives
 seconds(11);hit(.2);local m=#chatLog
 send(pull(COS,{UserId=me.UserId,Name='Me D'}));seconds(.1);check(#chatLog==m,'(held)')
 seconds(.2+margin);check(#chatLog==m+1,'a hit that is only .2 s away holds the line .2 s + the margin')
 -- never held longer than 8 s, whatever the attribute says
 seconds(11);me:SetAttribute('RarePullClimaxAt',W.workspace:GetServerTimeNow()+1e6);local k=#chatLog
 send(pull(KING,{UserId=me.UserId,Name='Me D'}));seconds(7.9);check(#chatLog==k,'a hit a million seconds away: still held at 7.9 s')
 seconds(.3);check(#chatLog==k+1,'... but written at 8 s (nothing is held longer)')
 -- bad attribute values do not hold anything
 for _,bad in ipairs({'soon',0/0,true})do me:SetAttribute('RarePullClimaxAt',bad);local c=#chatLog;seconds(11);send(pull(KING,{UserId=me.UserId,Name='Me D'}));check(#chatLog==c+1,'an attribute that is not a number ('..tostring(bad)..') holds nothing')end
 me:SetAttribute('RarePullClimaxAt',nil)
 -- the held line is rate limited when it is written (not when it arrived) and teardown cancels it
 seconds(11);boot()
 hit(1);for i=1,3 do send(pull(LEG,{UserId=me.UserId,Name='Me D'}))end;check(#chatLog==0,'three own lines held')
 seconds(1+margin+.3);check(#chatLog==3,'... all three are written afterwards')
 seconds(11);hit(3);send(pull(KING,{UserId=me.UserId,Name='Me D'}));ctx.Script:Destroy();seconds(5)
 check(#chatLog==3,'a line that was held when the script was destroyed is never written')
 me:SetAttribute('RarePullClimaxAt',nil)
 ctx.Remote:Destroy();ctx=nil
end

print(('R151 client: %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
