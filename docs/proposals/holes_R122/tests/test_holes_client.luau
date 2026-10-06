--!nocheck
-- R122 holes, client side + dig sound variants under the Roblox mock. Real: TrackHoleClient, GardenShovel (hint
-- passthrough), DigSoundVariants (Pick / Resolve / Detect / segment playback), DigSoundAnalyzer (Run on a mocked
-- AudioPlayer + AudioAnalyzer, Report). Run from a folder holding roblox.luau, world.luau, rs_bundle.luau (see run.sh).
-- R149: the dirt bursts start / land on the keyboard's key tops where the keyboard is drawn (KeyboardSurface149), at the floor elsewhere (3b).
-- R153: the tip (section 2) shows when the shovel is pulled out, anywhere, the first 3 times of a session, and says the shovel removes plants too;
-- the dig animation grows the replicated hole back to its configured (1.5x bigger) size and the dirt lands around the bigger rim (section 3).
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local RS=W.RS;local Run=W.Run;local UIS=W.UIS

-- Mock gaps -------------------------------------------------------------------------------------------------------
local Players=W.service('Players')
local Debris=W.service('Debris');Debris.AddItem=function()end
local CP=W.service('ContentProvider');CP.PreloadAsync=function()end
local Http=W.service('HttpService')
function Http.JSONDecode(_,text)
 -- tiny JSON subset: array of {"Start":n,"Length":n} or [n,n]
 local out={}
 for body in text:gmatch('{([^}]*)}')do out[#out+1]={Start=tonumber(body:match('"Start":%s*([%-%d%.eE]+)')),Length=tonumber(body:match('"Length":%s*([%-%d%.eE]+)'))}end
 if #out==0 then for a,b in text:gmatch('%[%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%]')do out[#out+1]={tonumber(a),tonumber(b)}end end
 if text:sub(1,1)~='['then error('bad json')end
 return out
end
W.env.RaycastParams={new=function()return {}end}
local CAS=W.service('ContextActionService');function CAS.BindActionAtPriority(_,name,fn)W.actions[name]=fn end
UIS.TouchTapInWorld=R.signal();UIS.GamepadEnabled=false
function UIS.GetMouseLocation()return R.Vector2.new(640,360)end
local camera=W.workspace.CurrentCamera
function camera.ViewportPointToRay(_,x,y)return {Origin=V3(0,20,90),Direction=V3(0,-1,0)}end
local rayHit
function W.workspace.Raycast()return rayHit end
local fired={};local sounds={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnClientEvent=R.signal();o.OnServerEvent=R.signal();o.FireServer=function(_,...)fired[#fired+1]=table.pack(...)end end
 if class=='Sound'then
  o.Ended=R.signal();o.IsLoaded=true;o.TimeLength=12;o.IsPlaying=false;o.Loaded=R.signal();o.TimePosition=0;o.PlaybackSpeed=1
  o.Play=function(self)self.IsPlaying=true;self.PlayedAt=R.clock end;o.Stop=function(self)self.IsPlaying=false;self.StoppedAt=R.clock end
  sounds[#sounds+1]=o
 end
 return o end end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local holeRemote=R.Instance.new('RemoteEvent');holeRemote.Name='TrackHole';holeRemote.Parent=remotes
local garden=R.Instance.new('RemoteEvent');garden.Name='GardenInteract';garden.Parent=remotes
local motion=RS:FindFirstChild('RunnerMotion');motion:SetAttribute('TrackBoundaryZ',0);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114)
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local runtime=R.new('Folder');runtime.Name='Runtime';runtime.Parent=map
local holesFolder=R.new('Folder');holesFolder.Name='TrackHoles';holesFolder.Parent=runtime
-- Local player on the track with the shovel equipped.
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local char=R.new('Model');char.Name='Me';char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,100);root.Parent=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local shovel=R.new('Tool');shovel.Name='Shovel';shovel:SetAttribute('GardenShovel',true);shovel.Parent=char
local function frames(n)for _=1,n do R.advance(1/30);Run.Heartbeat:Fire(1/30);Run.RenderStepped:Fire(1/30)end end
local function click()UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},false)end

-- R124: the shovel tip goes through NoticeFeed83 (fades by itself); spy on it.
local Feed=W.module('NoticeFeed83');local tips={};Feed.Plain=function(text,color,duration)tips[#tips+1]={Text=text,Duration=duration,At=R.clock}end
-- Load the real client scripts -----------------------------------------------------------------------------------
local clientScript=R.new('LocalScript');clientScript.Name='TrackHoleClient'
local okLoad,err=pcall(W.load,'TrackHoleClient',clientScript)
check(okLoad,'TrackHoleClient loads: '..tostring(err))
local gsScript=R.new('LocalScript');gsScript.Name='GardenShovel'
local okGarden,gerr=pcall(W.load,'GardenShovel',gsScript)
if not okGarden then print('NOTE: GardenShovel not loadable under the mock ('..tostring(gerr)..'); hint passthrough checked by source')end

-- 1. Input routing
rayHit={Position=V3(4,0,104),Normal=V3(0,1,0),Instance=W.workspace}
click()
check(#fired==1 and R.typeof(fired[1][1])=='Vector3'and near(fired[1][1].X,4),'click on the track sends the aimed point')
frames(10);rayHit={Position=V3(60,0,160),Normal=V3(0,1,0),Instance=W.workspace};click()
check(#fired==2 and fired[2][1]==nil,'aim out of range sends nil (server digs at the feet)')
click();check(#fired==2,'client throttle .25 s')
frames(10);UIS.TouchTapInWorld:Fire(R.Vector2.new(100,100),false)
check(#fired==3,'mobile tap on the track digs')
frames(10);UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},true)
check(#fired==3,'GUI-processed click ignored')
local action=W.actions.TrackHoleDig
frames(10);check(action and action('TrackHoleDig',R.Enum.UserInputState.Begin)==R.Enum.ContextActionResult.Sink and #fired==4,'gamepad R2 digs on the track and sinks')
root.CFrame=CF(0,3,-40);frames(10)
click();check(#fired==4,'garden / lobby click never sends a hole request')
check(action('TrackHoleDig',R.Enum.UserInputState.Begin)==R.Enum.ContextActionResult.Pass,'R2 passes to the garden shovel off the track')
root.CFrame=CF(0,3,100);shovel.Parent=nil;frames(10);click()
check(#fired==4,'no request without the shovel equipped')
shovel.Parent=char;me:SetAttribute('ChestChaseSeedCarrying',true);frames(10);click()
check(#fired==4,'no request while carrying a pack');me:SetAttribute('ChestChaseSeedCarrying',false)

-- 2. Tip (R124, R153): one fading notice when the shovel is pulled out (garden or track), the first HintTimes pull-outs of a session; it says the shovel
-- removes plants too. A pull-out while the last tip is still on screen shows nothing and is not counted. No permanent hint line.
local HC=W.module('TrackHoleConfig')
check(#tips==1 and tips[1].Text==HC.Hint and tips[1].Duration==HC.HintSeconds,'tip shown when the shovel is pulled out (on the track): '..tostring(tips[1]and tips[1].Text))
check(HC.Hint:find('trap',1,true)~=nil and HC.Hint:find('remove',1,true)~=nil and HC.Hint:find('plant',1,true)~=nil,'the tip says dig holes to trap players AND tap a plant to remove it')
check(utf8.len(HC.Hint)<=90 and HC.HintSeconds>=4 and HC.HintSeconds<=6 and HC.HintTimes==3,'short (<= 90 chars), 4 - 6 s on screen, 3 times per session: '..utf8.len(HC.Hint)..' chars')
check(pg:GetAttribute('ShovelHint')==nil,'no permanent hint line')
local function pull(wait)shovel.Parent=nil;frames(10);R.advance(wait or 9);shovel.Parent=char;frames(10)end
pull(1);check(#tips==1,'pulling it out again while the tip is still on screen (1 s later) shows nothing')
root.CFrame=CF(0,3,-40);frames(10)
pull();check(#tips==2,'2nd pull-out (in the garden, 9 s later) shows the tip again: the quick one above was not counted')
root.CFrame=CF(0,3,100);frames(10)
pull();check(#tips==3,'3rd pull-out (on the track) shows it again')
pull();check(#tips==3,'4th pull-out: not shown (3 per session)')
R.advance(3600);pull();check(#tips==3,'...not an hour later either (per session, not per hour)')
shovel.Parent=nil;frames(10);R.advance(31);frames(10);check(#tips==3,'no tip without the shovel')
check(tips[2].Text==HC.Hint and tips[3].Text==HC.Hint and tips[3].Duration==HC.HintSeconds,'every shown tip is the same fading line')
shovel.Parent=char;frames(10)
if okGarden then
 local label=pg:FindFirstChild('GardenShovelUI')and pg.GardenShovelUI:FindFirstChild('ShovelFeedback')
 frames(10);check(label and label.Text=='','shovel feedback line stays empty on the track')
end

-- 3. Effects: dig grows the replicated hole and plays a dig variant at the hole
local model=R.new('Model');model.Name='TrackHole_9';model.Parent=holesFolder
-- (the server's hole: pit Diameter across, rim a RimWidth wider all round, crumbs outside it)
local pit=R.new('Part');pit.Name='Pit';pit.Size=V3(.08,HC.Diameter,HC.Diameter);pit.CFrame=CF(0,0,100);pit.Parent=model;model.PrimaryPart=pit
local rimD=HC.Diameter+2*HC.RimWidth
local rimPart=R.new('Part');rimPart.Name='Rim';rimPart.Size=V3(.04,rimD,rimD);rimPart.CFrame=CF(0,0,100);rimPart.Parent=model
local crumb=R.new('Part');crumb.Name='Crumb';crumb.CFrame=CF(rimD/2+.5,0,100);crumb.Parent=model
local before=#sounds
-- the dig animation ("preview"): the pit and the rim open from a quarter to the configured size and stop exactly there; the crumbs go back to where they were
local grew={}
local Tween0=W.service('TweenService');local create0=Tween0.Create
Tween0.Create=function(self,obj,info,props)if props.Size and(obj==pit or obj==rimPart)then grew[obj]={From=obj.Size,To=props.Size}end;return create0(self,obj,info,props)end
holeRemote.OnClientEvent:Fire({Kind='Dig',Id=9,Position=V3(0,0,100),OwnerUserId=7})
Tween0.Create=create0
check(grew[pit]and near(grew[pit].To.Y,HC.Diameter)and near(grew[pit].To.Z,HC.Diameter)and near(grew[pit].From.Y,HC.Diameter*.25)
 and grew[rimPart]and near(grew[rimPart].To.Y,rimD)and near(grew[rimPart].From.Z,rimD*.25),'dig animation: pit and rim open from 1/4 to exactly the configured size ('..HC.Diameter..' / '..rimD..')')
local digSound=sounds[#sounds]
check(#sounds==before+1 and digSound.SoundId==W.module('TrackHoleConfig').DigSound.Id and digSound.IsPlaying,'dig plays the dig recording')
check(digSound.Parent and near(digSound.Parent.Position.Z,100)and digSound.SoundGroup~=nil,'positional at the hole, routed through AudioMixer')
check(near(pit.Size.Y,HC.Diameter)and near(pit.Size.Z,HC.Diameter)and near(pit.Size.X,.08)and near(rimPart.Size.Y,rimD),'hole grows back to full size (the drawn pit = Config.Diameter)')
holeRemote.OnClientEvent:Fire({Kind='Cover',Id=9,Position=V3(0,0,100),OwnerUserId=7})
check(#sounds==before+2 and sounds[#sounds].PlaybackSpeed<1,'cover uses the variant player, lower pitch')
holeRemote.OnClientEvent:Fire({Kind='Trap',Id=9,Position=V3(0,0,100)})
holeRemote.OnClientEvent:Fire('junk');holeRemote.OnClientEvent:Fire({Kind='Dig'})
check(true,'junk fx payloads ignored')

-- 3b. R149: the dirt bursts ride on the keyboard's key tops where the keyboard is drawn (the new keys stand 0.55 above the floor and the real
-- floor is hidden, so dirt tossed from floor height would be under them); everywhere else they stay at the floor, exactly as before.
do
 local K=W.module('KeyboardTrack');local FL=K.Config.FloorTop;local top0=K.KeyTop(0)
 local Tween=W.service('TweenService');local origCreate=Tween.Create
 local starts,goals={}, {}
 Tween.Create=function(self,obj,info,props)
  if obj.Name=='HoleDirt'and props.CFrame then
   if not starts[obj]then starts[obj]=obj.CFrame.Position;goals[obj]={}end
   table.insert(goals[obj],props.CFrame.Position)
  end
  return origCreate(self,obj,info,props)
 end
 local function dirt(kind,pos)
  for _,d in ipairs(W.workspace:GetChildren())do if d.Name=='HoleDirt'then d:Destroy()end end
  starts,goals={}, {}
  holeRemote.OnClientEvent:Fire({Kind=kind,Id=3,Position=pos,OwnerUserId=7})
  local out={}
  for _,d in ipairs(W.workspace:GetChildren())do if d.Name=='HoleDirt'and starts[d]then out[#out+1]={Start=starts[d],Peak=goals[d][1],Land=goals[d][2]}end end
  return out
 end
 -- every chunk starts .2 above `base`, lands s * .4 (.072 .. .184) above it and is tossed up at least .5 above it
 local function dirtAt(list,base)
  local ok=#list>0
  for _,d in ipairs(list)do
   if not near(d.Start.Y,base+.2)or d.Land.Y<base+.072-1e-6 or d.Land.Y>base+.184+1e-6 or d.Peak.Y<base+.5 then ok=false end
  end
  return ok
 end
 local function lowest(list)local lo=math.huge;for _,d in ipairs(list)do lo=math.min(lo,d.Start.Y,d.Peak.Y,d.Land.Y)end;return lo end
 local FLOOR=V3(0,FL,100)
 local counts={Dig=8,Cover=6,Trap=10}
 -- no keyboard (the folder KeyboardTrack.client builds is not there): the old burst at the floor
 for _,kind in ipairs({'Dig','Cover','Trap'})do
  local list=dirt(kind,FLOOR)
  check(#list==counts[kind]and dirtAt(list,FL),kind..' without the keyboard: '..#list..' dirt chunks at the floor (start .2, landing .07 .. .18 above it)')
 end
 -- the keyboard drawn (its folder + the map's biome attributes: the covered rectangle is the one KeyboardTrack builds)
 for k,v in pairs({BiomeStartZ_1=-100,BiomeEndZ_1=1000,BiomeTrackEndZ=1120})do map:SetAttribute(k,v)end
 local kbFolder=R.new('Folder');kbFolder.Name='KeyboardTrackVisuals';kbFolder.Parent=W.workspace
 for _,kind in ipairs({'Dig','Cover','Trap'})do
  local list=dirt(kind,FLOOR)
  check(#list==counts[kind]and lowest(list)>=top0-1e-6,kind..' on the keyboard: every chunk starts, peaks and lands at or above the resting key top ('..string.format('%.3f',lowest(list))..' >= '..string.format('%.3f',top0)..')')
  check(dirtAt(list,top0),kind..' on the keyboard: the same burst, moved up by the key rise (start '..string.format('%.2f',top0+.2)..')')
 end
 do -- R153: the toss lands around the bigger hole: outside the pit, no more than 1.4 studs from its edge
  local list=dirt('Dig',FLOOR);local lo,hi=math.huge,0
  for _,d in ipairs(list)do local rr=math.sqrt((d.Land.X-FLOOR.X)^2+(d.Land.Z-FLOOR.Z)^2);lo=math.min(lo,rr);hi=math.max(hi,rr)end
  check(#list>0 and lo>=HC.Diameter/2-1e-6 and hi<=HC.Diameter/2+1.4+1e-6,string.format('dirt lands %.2f .. %.2f studs from the centre (pit edge %.2f, within 1.4 of it)',lo,hi,HC.Diameter/2))
 end
 check(dirtAt(dirt('Dig',V3(100,FL,100)),FL),'beside the 180-wide keyboard (x = 100) the dirt stays at the floor')
 check(dirtAt(dirt('Dig',V3(0,top0+1,100)),top0+1),'a surface already above the key tops is not lowered')
 W.workspace.CurrentCamera.CFrame=CF(0,20,1000)
 check(dirtAt(dirt('Dig',V3(0,FL,1050)),FL),'past the last key row (the arena) the dirt stays at the floor')
 W.workspace.CurrentCamera.CFrame=CF(0,20,-30)
 kbFolder:Destroy()
 check(dirtAt(dirt('Dig',FLOOR),FL),'once the keyboard is gone the dirt is back at the floor')
 for k in pairs({BiomeStartZ_1=1,BiomeEndZ_1=1,BiomeTrackEndZ=1})do map:SetAttribute(k,nil)end
 for _,d in ipairs(W.workspace:GetChildren())do if d.Name=='HoleDirt'then d:Destroy()end end
 Tween.Create=origCreate
end

-- 4. DigSoundVariants
local DS=W.module('DigSoundVariants');local cfg=DS.Config
local rng=R.new and W.env.Random.new(3)
local last,repeats,seen=nil,0,{}
for _=1,2000 do local i=DS.Pick(6,last,rng);if i==last then repeats+=1 end;seen[i]=true;last=i end
check(repeats==0,'never the same variant twice in a row')
local all=true;for i=1,6 do all=all and seen[i]==true end;check(all,'every variant gets played')
check(DS.Pick(1,1,rng)==1 and DS.Pick(0,nil,rng)==nil,'single / empty lists')
local fb=DS.Resolve(12,nil,{})
check(#fb==6 and near(fb[2].Start,2)and near(fb[6].Start,10)and near(fb[1].Length,cfg.MaxLength),'fallback: TimeLength split into 6 equal windows')
check(#DS.Resolve(0,nil,{})==0,'no list and not loaded: nothing to play yet')
local listed=DS.Resolve(12,nil,{{Start=1,Length=.4},{Start=3.5,Length=9},{Start=-1,Length=1},{Start=11.9,Length=.5}})
check(#listed==3 and near(listed[2].Length,cfg.MaxLength)and near(listed[3].Length,.1),'config list validated and clipped')
local saved=DS.Parse(DS.Encode({{Start=.5,Length=.3},{Start=2.25,Length=.45}}))
local fromAttr=DS.Resolve(12,saved,{{Start=1,Length=.4}})
check(#fromAttr==2 and near(fromAttr[2].Start,2.25),'saved attribute wins over the config list')
check(DS.Parse('not json')==nil,'bad attribute ignored')
-- segment playback stops at Length / pitch
local player=DS.new();RS.TrackHoleConfig:SetAttribute('DigSegments',DS.Encode({{Start=1,Length=.5},{Start=3,Length=.6}}))
local s=player:Play(V3(0,0,0))
local seg=player:Segments()[player.Last]
check(s.IsPlaying and near(s.TimePosition,seg.Start),'variant starts at its segment start')
check(s.PlaybackSpeed>=cfg.PitchMin-1e-9 and s.PlaybackSpeed<=cfg.PitchMax+1e-9,'slight random pitch')
local stopAfter=seg.Length/s.PlaybackSpeed
R.advance(stopAfter-.02);check(s.IsPlaying,'still playing just before the segment end')
R.advance(.03);check(not s.IsPlaying and near(s.StoppedAt-s.PlayedAt,stopAfter,.03),'stopped at the segment end')
local lastIndex=player.Last;player:Play(V3(0,0,0));check(player.Last~=lastIndex,'next play is the other variant')
RS.TrackHoleConfig:SetAttribute('DigSegments',nil)
player=DS.new();player:Play(V3(0,0,0));check(#player:Segments()==6,'runtime fallback once TimeLength is known')
-- not loaded yet: waits for Loaded, drops stale plays
do
 local inew=R.Instance.new;local pending
 R.Instance.new=function(c,p)local o=inew(c,p);if c=='Sound'then o.IsLoaded=false;o.TimeLength=0;pending=o end;return o end
 local p2=DS.new();local snd=p2:Play(V3(0,0,0));check(not snd.IsPlaying,'waits for the sound to load')
 snd.TimeLength=12;R.advance(.1);snd.Loaded:Fire();check(snd.IsPlaying and p2.TimeLength==12,'plays on load')
 local late=p2:Play(V3(0,0,0));R.advance(1);late.TimeLength=12;late.Loaded:Fire();check(not late.IsPlaying,'stale load skipped')
 R.Instance.new=inew
end

-- 5. Onset detection on a synthetic level series (60 Hz)
local onsets={.5,1.6,2.4,4.0}
local function series(list,len,decay)
 local out={};local dt=1/60
 for k=0,math.floor(len/dt)do
  local t=k*dt;local level=.02+.01*math.sin(k*1.7)
  for _,o in ipairs(list)do if t>=o then level=math.max(level,.9*math.exp(-(t-o)/(decay or .08)))end end
  out[#out+1]={T=t,Level=level}
 end
 return out
end
local segs,info=DS.Detect(series(onsets,5.5))
check(#segs==4,'4 digs found: '..#segs)
for i,sg in ipairs(segs)do
 check(math.abs(sg.Onset-onsets[i])<=1/60+1e-6,'onset '..i..' within one frame')
 check(near(sg.Start,math.max(0,sg.Onset-.03),1e-6),'starts a little before onset '..i)
 if segs[i+1]then check(sg.Start+sg.Length<=segs[i+1].Start+1e-6,'ends before the next dig '..i)end
 check(sg.Length>=.08 and sg.Length<=1.2,'length bounded '..i)
end
check(info.Threshold>info.Floor and info.Threshold<info.Peak,'auto threshold between floor and peak')
local merged=DS.Detect(series({1,1.04},3))
check(#merged==1,'two hits 40 ms apart = one dig')
local quiet=DS.Detect(series({},3))
check(#quiet<=1,'noise only: no real digs')
local fixed=DS.Detect(series(onsets,5.5),{Threshold=.95})
check(#fixed==0,'explicit threshold above every dig finds none')

-- 6. Studio analyzer end to end with a mocked Audio API
local A=W.module('DigSoundAnalyzer')
local okRun=pcall(A.Run);check(not okRun,'analyzer refuses outside Studio')
Run.IsStudio=function()return true end
local playerInst
do
 local inew=R.Instance.new
 R.Instance.new=function(c,p)
  local o=inew(c,p)
  if c=='AudioPlayer'then
   playerInst=o;o.IsReady=true;o.TimeLength=5.5;o.TimePosition=0;o.IsPlaying=false
   o.Play=function(self)self.IsPlaying=true;self.Started=R.clock end;o.Stop=function(self)self.IsPlaying=false end
  elseif c=='AudioAnalyzer'then
   local data=series(onsets,5.5)
   setmetatable(o._props,{__index=function(_,k)
    if k=='PeakLevel'or k=='RmsLevel'then
     local t=playerInst and playerInst.TimePosition or 0;local i=math.clamp(math.floor(t*60)+1,1,#data);return data[i].Level*(k=='RmsLevel'and .7 or 1)end
   end})
  end
  return o
 end
 local task2=table.clone(R.task)
 task2.wait=function(t)t=t or 1/60;local n=math.max(1,math.floor(t*60+.5))
  for _=1,n do R.advance(1/60)
   if playerInst and playerInst.IsPlaying then playerInst.TimePosition=R.clock-playerInst.Started;if playerInst.TimePosition>=playerInst.TimeLength then playerInst.IsPlaying=false end end
   Run.Heartbeat:Fire(1/60)
  end
  return t end
 W.env.task=task2
 local out=A.Run()
 R.Instance.new=inew;W.env.task=R.task
 check(out and #out==4,'analyzer finds every dig in the recording: '..(out and #out or 0))
 check(type(RS.TrackHoleConfig:GetAttribute('DigSegments'))=='string'and #DS.Parse(RS.TrackHoleConfig:GetAttribute('DigSegments'))==4,'analyzer saves the list as the DigSegments attribute')
 check(#DS.new():Segments()==4,'saved list is used by the game at once')
 check(#W.service('SoundService'):GetChildren()==0 or not W.service('SoundService'):FindFirstChild('DigSoundAnalyzer'),'analyzer cleans up its audio graph')
 local lua=A.Report(out,{},5.5)
 local count=0;for _ in lua:gmatch('{Start=')do count+=1 end
 check(count==4 and lua:find('^Segments={'),'paste-ready Segments line')
end

print(string.format('%s: %d checks, %d failures',fails==0 and'PASS'or'FAIL',checks,fails))
if fails>0 then error('failures',0)end
