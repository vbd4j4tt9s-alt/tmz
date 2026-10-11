--!nocheck
-- R149 (owner: "sync verity's voice and cut the audio to only hello my name verity ..."): the shared rules and the server half, on the Roblox
-- mock with the REAL modules of this checkout (VerityVoice, VerityConfig, VerityService, OwnerUpdateCommands82, OwnerCommandTargets82,
-- StudioTestCommands, StudioTestHelp):
--  1. VerityVoice.Region: the cut (start, stop) in seconds: the config's, the owner's live pair, made safe (NaN, infinity, negatives,
--     too long, too short, reversed, past the clip's length), never silently turned into something else for a valid pair.
--  2. VerityVoice.Fade: the volume ramp over the last GreetingFade seconds.
--  3. VerityVoice.Step (the voice level): real loudness is normalised to the loudest syllable heard, gated, curved, rises fast and falls slower, a
--     pause lets it fall (no rhythm mixed in once real loudness has been heard), nothing is heard for .3 s then a talking rhythm runs if no
--     loudness is ever reported, it stops with the voice and falls smoothly to exactly 0; hostile input (NaN, negative, huge dt) is safe.
--  4. VerityVoice.Pose (R151: the mouth oval is gone, the ball bounces): her size and her rise at a voice level: she swells by TalkPulse and hops by
--     TalkBounce of her size, bottom first (she grows up from the dais), the same fractions at every size, safe for NaN / nil / out of range; and
--     nothing of the mouth is left (no Mouth setting, no MouthPose).
--  5. VerityConfig: the numbers and their "TUNE IN STUDIO" mark; VerityService: the live cut on her model (VerityVoiceStart / VerityVoiceEnd),
--     PlayVoice (a 'Greet' message to one player only), nothing saved, a rebuilt server starts from the config.
--  6. The owner command `verityvoice <end> [start]` / `verityvoice` / `verityvoice reset` through OwnerUpdateCommands82 and through the real
--     dispatcher (StudioTestCommands.Execute: owner only, no @target, "/test" and "/cctest"), every bad input refused with nothing changed and
--     nothing played; and the help row.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local sent={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function(_,p,...)sent[#sent+1]={P=p,Args={...}}end end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 return o end end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=mapRoot
local C=W.module('VerityConfig');local Voice=W.module('VerityVoice')
local nextId=900
local function makePlayer(name)nextId+=1;local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=nextId;p.Parent=Players;present[nextId]=p;order[#order+1]=p;return p end
local function inbox(p)local out={};for _,m in ipairs(sent)do if m.P==p then out[#out+1]=m end end;return out end

-- 1. Region -----------------------------------------------------------------------------------------------------------------------------
do
 local cfg={GreetingStart=0,GreetingEnd=1.9}
 local function r(a,b,len,c)local s,e=Voice.Region(c or cfg,a,b,len);return s,e end
 local s,e=r();check(s==0 and e==1.9,'no override: the config (0 .. 1.9)')
 s,e=r(.3,2.2);check(s==.3 and e==2.2,'a pair of numbers is used as it is (.3 .. 2.2)')
 s,e=r(.3,nil);check(s==0 and e==1.9,'one number alone: the config')
 s,e=r(nil,2.2);check(s==0 and e==1.9,'(the other one too)')
 for _,bad in ipairs({{0/0,1},{1,0/0},{1/0,2},{0,1/0},{-1/0,1},{'a',1},{1,'b'},{{},1},{true,1}})do s,e=r(bad[1],bad[2]);check(s==0 and e==1.9,'a bad pair ('..tostring(bad[1])..', '..tostring(bad[2])..') falls back to the config')end
 s,e=r(nil,nil,nil,{GreetingStart=0/0,GreetingEnd=1});check(s==0 and e==Voice.Default.Stop and Voice.Default.Stop==2.35,'a broken config falls back to 0 .. 2.35 (R151: the same cut as the config, not the old 1.9)')
 s,e=r(nil,nil,nil,{GreetingStart='x',GreetingEnd=nil});check(s==0 and e==Voice.Default.Stop,'(and a missing one)')
 s,e=r(nil,nil,nil,{GreetingStart=.4,GreetingEnd=1.2});check(s==.4 and e==1.2,'a changed config is used (.4 .. 1.2)')
 s,e=r(-3,2);check(s==0 and e==2,'a negative start is 0')
 s,e=r(0,500);check(s==0 and e==Voice.MaxSeconds,'an end past '..Voice.MaxSeconds..' s is '..Voice.MaxSeconds)
 s,e=r(2,2);check(s==2 and near(e-s,Voice.MinLength),'start = end: at least '..Voice.MinLength..' s long')
 s,e=r(3,2);check(s==3 and near(e-s,Voice.MinLength),'start after end: '..Voice.MinLength..' s long from the start')
 s,e=r(0,1.9,1.5);check(s==0 and e==1.5,'a clip 1.5 s long: the end is 1.5')
 s,e=r(1.45,1.9,1.5);check(near(s,1.4)and e==1.5,'a start inside the last '..Voice.MinLength..' s of the clip moves back (1.4 .. 1.5)')
 s,e=r(5,6,3.2);check(near(s,3.1)and e==3.2,'a start past the clip: the last '..Voice.MinLength..' s')
 s,e=r(0,1.9,0);check(s==0 and e==1.9,'length 0 (not loaded yet): no clamp')
 s,e=r(0,1.9,nil);check(s==0 and e==1.9,'(nil too)')
 s,e=r(0,1.9,0/0);check(s==0 and e==1.9,'(NaN too)')
 s,e=r(0,1.9,3.2);check(s==0 and e==1.9,'a clip longer than the cut leaves it alone')
 for _,pair in ipairs({{0,.1},{.1,.2},{0,1.9},{.25,1.75},{10,60},{0,60}})do s,e=r(pair[1],pair[2]);check(s==pair[1]and near(e,pair[2]),'a valid pair is never changed: '..pair[1]..' .. '..pair[2])end
 check(select(2,r(0,1.9))-select(1,r(0,1.9))>=Voice.MinLength,'every result is at least MinLength long')
end
-- 2. Fade ----------------------------------------------------------------------------------------------------------------------------------
do
 check(Voice.Fade(0,1.9,.08)==1 and Voice.Fade(1.8,1.9,.08)==1,'full volume until the last .08 s')
 check(near(Voice.Fade(1.86,1.9,.08),.5,1e-9),'half way down in the middle of the fade (1.86 of 1.9)')
 check(Voice.Fade(1.9,1.9,.08)==0 and Voice.Fade(2.5,1.9,.08)==0,'zero at the end and after it')
 check(Voice.Fade(1.85,1.9,0)==1 and Voice.Fade(1.85,1.9,-1)==1 and Voice.Fade(0/0,1.9,.08)==1 and Voice.Fade(1,0/0,.08)==1 and Voice.Fade(1,1.9,0/0)==1,'no fade (0, negative, NaN) is full volume')
 local last=1;local ok=true;for i=0,100 do local g=Voice.Fade(1.82+i*.0008,1.9,.08);if g>last+1e-12 then ok=false end;last=g end
 check(ok,'the ramp only goes down')
end
-- 3. Lip sync ------------------------------------------------------------------------------------------------------------------------------------
do
 local L=C.Lip
 local lip=Voice.NewLip(L)
 check(lip.Level==0 and lip.Peak==L.Floor and not lip.Seen,'a new voice level is 0')
 -- Real loudness.
 local function run(lip,loud,frames,playing)local v;for _=1,frames do v=Voice.Step(lip,L,loud,1/60,playing~=false)end;return v end
 local v=run(lip,500,4);check(v>.8,string.format('a loud syllable (500) raises it within 4 frames (%.2f)',v))
 v=run(lip,500,30);check(v>.99,'and to the top when it holds')
 local nOpen=0;do local l2=Voice.NewLip(L);while Voice.Step(l2,L,500,1/60,true)<.9 do nOpen+=1;if nOpen>200 then break end end end
 local nClose=0;do local l2=Voice.NewLip(L);run(l2,500,30);while Voice.Step(l2,L,0,1/60,true)>.1 do nClose+=1;if nClose>200 then break end end end
 check(nOpen<nClose and nOpen<=4 and nClose<=30,string.format('it rises faster than it falls (%d frames to .9, %d frames to .1)',nOpen,nClose))
 check(run(lip,0,60)==0,'in a pause (loudness 0) it is 0 exactly')
 do -- real loudness heard once: silence stays silence (no rhythm mixed into pauses)
  local l2=Voice.NewLip(L);run(l2,400,10);local worst=0;for _=1,90 do worst=math.max(worst,Voice.Step(l2,L,0,1/60,true))end
  check(l2.Seen and worst<.8 and l2.Level==0,'once real loudness has been heard, a pause just lets it fall (no talking rhythm in the gaps)')
 end
 do -- normalised to the loudest syllable (never below the floor)
  local l2=Voice.NewLip(L);run(l2,600,20);local half=run(l2,300,20);local quiet=run(l2,60,12)
  check(half>.4 and half<.75,string.format('half the loudest syllable raises it about half way (%.2f)',half))
  check(quiet<.2,string.format('a murmur of a tenth of it is nearly 0 (%.2f)',quiet))
  local l3=Voice.NewLip(L);local tiny=run(l3,30,40);check(tiny<.7 and tiny>.2,string.format('a very quiet clip (30) is not blown up to full level (%.2f): the floor is %d',tiny,L.Floor))
  local l4=Voice.NewLip(L);local loud=run(l4,1000,40);check(loud>.99,'loudness at the top of the 0..1000 scale is the full level')
  local l5=Voice.NewLip(L);run(l5,1000,5);for _=1,120 do Voice.Step(l5,L,200,1/60,true)end
  check(l5.Peak<1000 and run(l5,200,10)>.6,'the peak decays: after a long quiet stretch ordinary speech raises it properly again ('..string.format('%.0f',l5.Peak)..')')
 end
 -- Begin() forgets the last playing.
 do local l2=Voice.NewLip(L);run(l2,900,20);Voice.Begin(l2,L);check(l2.Peak==L.Floor and not l2.Seen and l2.Age==0 and l2.Level>.9,'Begin: forgets the peak and what was heard, keeps the level where it is (it falls smoothly)')end
 -- Fallback rhythm.
 do
  local l2=Voice.NewLip(L);local early=0;for _=1,math.floor((L.FallbackAfter-.02)*60)do early=math.max(early,Voice.Step(l2,L,0,1/60,true))end
  check(early==0,'no loudness yet: the level stays 0 for the first '..L.FallbackAfter..' s (the sound may just be starting)')
  local opens,wasOpen,maxv=0,false,0;local closedSeen=false
  for _=1,math.floor((C.GreetingEnd-L.FallbackAfter)*60)do
   local x=Voice.Step(l2,L,0,1/60,true);maxv=math.max(maxv,x);local o=x>.45;if o and not wasOpen then opens+=1 end;wasOpen=o;if x<.15 then closedSeen=true end
  end
  check(opens>=4 and maxv>.7 and closedSeen,string.format('then a talking rhythm: %d syllables in the rest of a %.2f s cut, as high as %.2f, falling between',opens,C.GreetingEnd,maxv))
  check(not l2.Seen,'(it never pretends it heard something)')
  local l3=Voice.NewLip(L);run(l3,0,60);local o=run(l3,500,6);check(l3.Seen and o>.8,'a loudness that arrives late (after the rhythm started) takes over at once')
 end
 -- Stopping.
 do
  local l2=Voice.NewLip(L);run(l2,500,20)
  local before=l2.Level;local v1=Voice.Step(l2,L,500,1/60,false);check(before>.99 and v1<before and v1>0,'the voice has stopped: it falls smoothly, not in one jump ('..string.format('%.2f -> %.2f',before,v1)..')')
  local frames=0;while l2.Level>0 and frames<300 do Voice.Step(l2,L,500,1/60,false);frames+=1 end
  check(l2.Level==0 and frames<60,'and reaches exactly 0 ('..frames..' frames), whatever loudness a stopped Sound still reports')
  check(Voice.Step(l2,L,500,1/60,false)==0,'and stays 0')
 end
 -- Hostile input.
 do
  local l2=Voice.NewLip(L)
  for _,bad in ipairs({0/0,-5,1/0,-1/0,'x',{},true})do local out=Voice.Step(l2,L,bad,1/60,true);check(type(out)=='number'and out==out and out>=0 and out<=1,'loudness '..tostring(bad)..' gives a level in 0..1')end
  for _,dt in ipairs({0,-1,0/0,1/0,1e9,'x'})do local out=Voice.Step(l2,L,300,dt,true);check(type(out)=='number'and out==out and out>=0 and out<=1,'dt '..tostring(dt)..' gives a level in 0..1')end
  local lipNil=Voice.NewLip(L);check(select(2,pcall(Voice.Step,lipNil,L,nil,1/60,true))~=nil,'nil loudness is fine')
 end
end
-- 4. Pose (R151: the ball bounces, there is no mouth) ----------------------------------------------------------------------------------------------
do
 check(Voice.MouthPose==nil and C.Mouth==nil and not W.B.VerityVoice:find('function M.MouthPose',1,true)and not W.B.VerityConfig:find('C.Mouth=',1,true),'the mouth oval is gone: no VerityVoice.MouthPose, no VerityConfig.Mouth')
 local rest=Voice.Pose(C,22,0)
 check(rest.Scale==1 and rest.Size==22 and rest.Rise==0,'at level 0 she is exactly at rest: scale 1, 22 studs, no rise')
 local full=Voice.Pose(C,22,1)
 check(near(full.Scale,1+C.TalkPulse)and near(full.Size,22*(1+C.TalkPulse))and near(full.Rise,22*C.TalkPulse/2+22*C.TalkBounce),'at level 1 she swells by TalkPulse and hops by TalkBounce of her size (swelling up from her bottom: Rise = D * pulse / 2 + D * bounce)')
 check(near(full.Rise-(full.Size-22)/2,22*C.TalkBounce,1e-9),'(so the hop on top of the swell is TalkBounce of her size: '..string.format('%.2f',22*C.TalkBounce)..' studs of her 22)')
 local half=Voice.Pose(C,22,.5)
 check(half.Scale>rest.Scale and half.Scale<full.Scale and half.Rise>rest.Rise and half.Rise<full.Rise,'a quieter syllable swells and hops less: both follow the level')
 local last=-1;local mono=true;for i=0,20 do local r=Voice.Pose(C,22,i/20).Rise;if r<last then mono=false end;last=r end
 check(mono,'the rise grows with the level, never back')
 local big,small=Voice.Pose(C,22,.7),Voice.Pose(C,10,.7)
 check(near(big.Rise/22,small.Rise/10,1e-9)and near(big.Scale,small.Scale,1e-12)and near(big.Size/22,small.Size/10,1e-9),'it scales with her size (22 studs in the world, 10 in the portrait): the same fractions')
 local over,under,nan,nothing=Voice.Pose(C,22,5),Voice.Pose(C,22,-1),Voice.Pose(C,22,0/0),Voice.Pose(C,22,nil)
 check(near(over.Rise,full.Rise)and under.Rise==0 and nan.Rise==0 and nothing.Rise==0 and nan.Scale==1 and nothing.Size==22,'a level above 1 is 1; negative, NaN and nil are 0')
 check(C.TalkBounce>=.04 and C.TalkBounce<=.12 and C.TalkPulse>0,'the bounce is a clear hop but not a leap: '..C.TalkBounce..' of her size (world: '..string.format('%.2f',22*C.TalkBounce)..' studs)')
 -- the portrait must hold the whole movement: the top of the ball at the loudest moment (swell + hop + bob) stays inside the viewport
 do
  local D=C.Portrait.Size;local top=D*(C.Portrait.Bob)+Voice.Pose(C,D,1).Rise+Voice.Pose(C,D,1).Size/2
  local halfView=D/2/C.Portrait.Fill
  check(top<=halfView and halfView-top<D*.06,string.format('the portrait\'s viewport holds the loudest bounce: the ball reaches %.2f of %.2f studs above its resting centre (Fill %.2f)',top,halfView,C.Portrait.Fill))
 end
end
-- 5. Config and service ---------------------------------------------------------------------------------------------------------------------
check(C.Version==149 and C.GreetingSoundId=='rbxassetid://123997993114202'and C.GreetingVolume==.8,'VerityConfig: version 149, the owner\'s voice id and volume unchanged')
check(C.GreetingStart==0 and C.GreetingEnd==2.35 and C.GreetingFade==.08 and Voice.Default.Stop==2.35,'R151: GreetingStart 0, GreetingEnd 2.35 (the owner heard the 1.9 cut stop at "Ver"), GreetingFade .08 (kept); a broken config falls back to the same 2.35')
check(W.B.VerityConfig:find('TUNE IN STUDIO',1,true)~=nil and W.B.VerityConfig:find('/test verityvoice',1,true)~=nil,'the config says where to tune them and how (/test verityvoice)')
check(C.TalkPulseRate==nil,'(the old swell-rhythm setting is gone: the swell follows the loudness)')
check(type(C.Lip)=='table'and C.Mouth==nil and type(C.Portrait)=='table'and C.Portrait.Size>0 and C.Portrait.Fill>0 and C.Portrait.Fill<1 and type(C.TalkBounce)=='number','the voice level (Lip), TalkPulse / TalkBounce and Portrait settings exist; the Mouth setting is gone')
local Verity=server('VerityService')
local service=Verity.new({},{},{},{},{MapRoot=mapRoot,EconomyHub=hub})
check(select(1,service:VoiceRegion())==0 and not service:SetVoiceRegion(1,2)and not service:PlayVoice(makePlayer('Early')),'before she is built there is nothing to set or play')
service:Start()
local model=hub:FindFirstChild('VerityNPC');local remote=remotes:FindFirstChild('VerityQuest')
check(model~=nil and remote~=nil,'(Start builds her)')
do
 local s,e,custom=service:VoiceRegion()
 check(s==0 and e==C.GreetingEnd and custom==false,'the cut in force: the config\'s (0 .. '..C.GreetingEnd..')')
 check(model:GetAttribute('VerityVoiceStart')==nil and model:GetAttribute('VerityVoiceEnd')==nil,'her model carries no override')
 check(service:SetVoiceRegion(.3,2.4),'SetVoiceRegion(.3, 2.4)')
 s,e,custom=service:VoiceRegion()
 check(s==.3 and e==2.4 and custom==true and model:GetAttribute('VerityVoiceStart')==.3 and model:GetAttribute('VerityVoiceEnd')==2.4,'is kept on her model as VerityVoiceStart / VerityVoiceEnd (replicated to every client)')
 check(not service:SetVoiceRegion(0/0,1)and not service:SetVoiceRegion(1,1/0)and not service:SetVoiceRegion('a',1)and not service:SetVoiceRegion(1,nil)and select(1,service:VoiceRegion())==.3,'bad numbers are refused and change nothing')
 check(service:SetVoiceRegion(3,2),'a reversed pair is made safe')
 s,e=service:VoiceRegion();check(s==3 and near(e-s,Voice.MinLength),'(start 3, at least '..Voice.MinLength..' s long)')
 local ava,bob=makePlayer('Ava'),makePlayer('Bob')
 service:SetVoiceRegion(.3,2.4);check(service:PlayVoice(ava),'PlayVoice(Ava)')
 local box=inbox(ava);local m=box[#box]
 check(m and m.Args[1]=='Greet'and m.Args[2].Start==.3 and m.Args[2].End==2.4 and #inbox(bob)==0,'sends Ava a Greet with the cut in force ({Start .3, End 2.4}) and nobody else')
 check(not service:PlayVoice(nil)and not service:PlayVoice({}),'(a missing player is nothing)')
 local gone=makePlayer('Gone');gone.Parent=nil;check(not service:PlayVoice(gone),'a player who left gets nothing')
 check(service:SetVoiceRegion(nil,nil)and model:GetAttribute('VerityVoiceStart')==nil and model:GetAttribute('VerityVoiceEnd')==nil and select(3,service:VoiceRegion())==false,'SetVoiceRegion(nil, nil) goes back to the config')
 service:PlayVoice(ava);box=inbox(ava);m=box[#box];check(m.Args[2].Start==0 and m.Args[2].End==C.GreetingEnd,'and Greet then carries the config cut')
 local keepEnd=C.GreetingEnd;C.GreetingStart=.25;C.GreetingEnd=1.4;s,e=service:VoiceRegion();check(s==.25 and e==1.4,'a changed config is the cut in force (nothing is saved by the command)');C.GreetingStart=0;C.GreetingEnd=keepEnd
 -- A rebuilt server starts from the config again: the override lives on the model only.
 service:SetVoiceRegion(.5,.9)
 local hub2=R.new('Folder');hub2.Name='EconomyHub';hub2.Parent=R.new('Folder')
 local service2=Verity.new({},{},{},{},{MapRoot=mapRoot,EconomyHub=hub2});service2:Start()
 check(select(1,service2:VoiceRegion())==0 and select(2,service2:VoiceRegion())==C.GreetingEnd,'a new server (a new model) starts from the config, not from the old override')
 service:SetVoiceRegion(nil,nil)
end

-- 6. The owner command -------------------------------------------------------------------------------------------------------------------------
local X=server('OwnerUpdateCommands82');local Targets=server('OwnerCommandTargets82')
local owner=makePlayer('Owner')
local ctx={Map={MapRoot=mapRoot},Chase={Verity=service},Data={IsLoaded=function()return true end}}
local function run(...)return X.Execute(ctx,owner,'verityvoice',{...})end
local function lastGreet()local box=inbox(owner);local m=box[#box];return m and m.Args[1]=='Greet'and m.Args[2]or nil end
local function greets()local n=0;for _,m in ipairs(inbox(owner))do if m.Args[1]=='Greet'then n+=1 end end;return n end
check(X.Actions.verityvoice==true,'verityvoice is registered as an owner command')
do
 local g0=greets()
 local ok,msg=run()
 check(ok and greets()==g0+1 and lastGreet().Start==0 and lastGreet().End==C.GreetingEnd,'verityvoice alone: plays the current cut for the caller (0 .. '..C.GreetingEnd..')')
 check(msg:find('0.00 s to 2.35 s',1,true)and msg:find('2.35 s long',1,true)and msg:find('GreetingStart=0',1,true)and msg:find('GreetingEnd=2.35',1,true)and msg:find('VerityConfig',1,true),'and prints the numbers and where to write them: '..msg)
 check(msg:find('from VerityConfig',1,true),'(saying they come from the config)')
 ok,msg=run('2.1')
 check(ok and select(1,service:VoiceRegion())==0 and select(2,service:VoiceRegion())==2.1 and model:GetAttribute('VerityVoiceEnd')==2.1,'verityvoice 2.1: the end is 2.1 for this whole server (on her model), the start stays 0')
 check(greets()==g0+2 and lastGreet().Start==0 and lastGreet().End==2.1,'and plays it for the caller at once ({0, 2.1})')
 check(msg:find('GreetingEnd=2.1',1,true)and msg:find('this command, for this server only',1,true),'the message gives the number to write: '..msg)
 ok,msg=run('1.5','0.3')
 check(ok and select(1,service:VoiceRegion())==.3 and select(2,service:VoiceRegion())==1.5 and lastGreet().Start==.3 and lastGreet().End==1.5,'verityvoice 1.5 0.3: end 1.5, start .3')
 check(msg:find('0.30 s to 1.50 s',1,true)and msg:find('GreetingStart=0.3',1,true),'and says so: '..msg)
 ok=run('1.7');check(ok and select(1,service:VoiceRegion())==.3 and select(2,service:VoiceRegion())==1.7,'verityvoice 1.7 keeps the start in force (.3)')
 local g1=greets();ok,msg=run();check(ok and greets()==g1+1 and lastGreet().Start==.3 and lastGreet().End==1.7,'verityvoice alone replays the numbers in force (.3 .. 1.7)')
 check(msg:find('0.30 s to 1.70 s',1,true),'and prints them')
 ok,msg=run('reset');check(ok and model:GetAttribute('VerityVoiceStart')==nil and model:GetAttribute('VerityVoiceEnd')==nil and lastGreet().Start==0 and lastGreet().End==C.GreetingEnd and msg:find('Back to VerityConfig',1,true),'verityvoice reset: back to the config, played once: '..msg)
 ok,msg=run('RESET');check(ok,'(RESET works too)')
 -- Every bad input: refused, nothing changed, nothing played.
 run('1.2','0.4');local sBefore,eBefore=service:VoiceRegion();local gN=greets()
 for _,bad in ipairs({{'abc'},{'0'},{'-1'},{'nan'},{'inf'},{'-inf'},{'2','3'},{'2','2'},{'0.35','0.3'},{'1','-1'},{'61'},{'1e9'},{'1','2','3'},{'1','x'},{'x','1'},{'reset','1'},{'1..2'},{''}})do
  local okBad,why=run(table.unpack(bad))
  check(okBad==false and type(why)=='string'and why~='','refused: verityvoice '..table.concat(bad,' ')..' ('..tostring(why)..')')
 end
 local sAfter,eAfter=service:VoiceRegion();check(sAfter==sBefore and eAfter==eBefore and greets()==gN,'none of them changed the cut or played anything')
 check(select(2,run('1.7','1.7')):find('at least',1,true)~=nil and select(2,run('abc')):find('numbers',1,true)~=nil and select(2,run('61')):find('at most',1,true)~=nil,'and each says what is wrong')
 check(select(1,run('0.45','0.4'))==false and select(1,run('0.5','0.4'))==true and select(2,service:VoiceRegion())==.5,'(the shortest cut is '..Voice.MinLength..' s: end .45 after start .4 is refused, end .5 after .4 is fine)')
 run('reset')
 local noService={Map={MapRoot=mapRoot},Chase={}}
 local okNo,whyNo=X.Execute(noService,owner,'verityvoice',{'2'});check(okNo==false and whyNo:find('not in this server',1,true),'without her in the server: "Verity is not in this server."')
 check(X.Execute({Map={MapRoot=mapRoot},Chase={Verity={}}},owner,'verityvoice',{'2'})==false,'(or a service that is not built)')
end
-- Through the real dispatcher.
do
 check(Targets.IsGlobal('/test verityvoice 2.1')and Targets.IsGlobal('/cctest verityvoice')and Targets.IsGlobal('verityvoice reset'),'IsGlobal: verityvoice takes no @target (a server command)')
 check(not Targets.IsGlobal('/test verity 3'),'(the older verity pack command is not global)')
 local body,target=Targets.Split('verityvoice 2.1 @bob');check(body=='verityvoice 2.1'and target=='bob','Split reads the @target')
 local Commands=server('StudioTestCommands');local Access=server('OwnerCommandAccess')
 local allowed={[owner]=true};Access.IsAllowed=function(p)return allowed[p]==true end
 local guest=makePlayer('Guest')
 local dctx={Map={MapRoot=mapRoot},Chase={Verity=service,IsPlayerBusy=function()return false end},Data={IsLoaded=function()return true end}}
 local g0=greets()
 local ok,msg=Commands.Execute(dctx,owner,'/test verityvoice 2.1 0.3')
 check(ok and greets()==g0+1 and lastGreet().Start==.3 and lastGreet().End==2.1,'/test verityvoice 2.1 0.3 (the real dispatcher): sets it and plays it for the owner: '..tostring(msg))
 ok,msg=Commands.Execute(dctx,owner,'/cctest verityvoice');check(ok and greets()==g0+2,'/cctest works too')
 ok,msg=Commands.Execute(dctx,owner,'/test verityvoice 2.5 @guest');check(not ok and msg:find('affects the server once',1,true)~=nil and select(2,service:VoiceRegion())==2.1,'an @target is refused ("omit @target") and nothing changes: '..tostring(msg))
 ok,msg=Commands.Execute(dctx,owner,'/test verityvoice 2.5 @all');check(not ok and select(2,service:VoiceRegion())==2.1,'(@all too)')
 local g1=greets();ok,msg=Commands.Execute(dctx,guest,'/test verityvoice 9');check(not ok and msg:find('experience owner',1,true)~=nil and select(2,service:VoiceRegion())==2.1 and #inbox(guest)==0,'somebody who is not the owner or an admin is refused and nothing changes or plays')
 ok,msg=Commands.Execute(dctx,owner,'/test verityvoice abc');check(not ok,'a bad number through the dispatcher is refused')
 ok,msg=Commands.Execute(dctx,owner,'/test verityvoice reset');check(ok and select(3,service:VoiceRegion())==false,'/test verityvoice reset')
 ok,msg=Commands.Execute(dctx,owner,'/test Verityvoice 1.4');check(ok and select(2,service:VoiceRegion())==1.4,'(not case sensitive)')
 Commands.Execute(dctx,owner,'/test verityvoice reset')
end
-- The help list.
do
 local Help=W.module('StudioTestHelp');local row
 for _,e in ipairs(Help)do if e[1]:find('verityvoice',1,true)then row=e end end
 check(row and row[1]:find('^/test verityvoice')and row[2]:find('server',1,true)and row[2]:find('verityvoice reset',1,true)and row[2]:find('GreetingEnd',1,true),'StudioTestHelp has the /test verityvoice row (what it does, reset, where the numbers go)')
 local rows=0;for _,e in ipairs(Help)do if e[1]:find('verityvoice',1,true)then rows+=1 end end;check(rows==1,'exactly one row')
 local helpOk,helpText=pcall(function()return server('StudioTestCommands')end);check(helpOk,'(the dispatcher loads with the new help)')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
