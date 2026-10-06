--!nocheck
-- R152 performance patch: the seed (pack) opening, frame by frame. The REAL SeedPackClient and PackOpeningFeedback (every reveal module: RarePullCinematic,
-- the card, the scenes, the sky beam, PackSuspense, RevealFlourish, the sounds) on the R152 seed-opening mock (rare152_env: sounds that end at their real
-- length, every play / stop logged), driven the way the server drives them (test_seed_stress.luau's protocol: the carried pack, its clicks, RevealSeedId /
-- RevealDuration / RevealAt, the pack destroyed when the reveal ends). For every scenario of SEED_SET every frame is a fingerprint shot (perf152_fp.luau)
-- of what the opening touches (the stage, the world effects, the characters, the reveal GUI, the camera and its grade / blur, the sounds, Lighting) and
-- the sound schedule is a FACT (which sound, at what time from the opening, at what file position, speed and volume, and the voices heard every frame).
-- SEED_SET: a list of {device, rank, fps, who}: device 'desktop' (ClientFxBudget 3) | 'phone' (2, touch) | 'low' (1); who 'own' | 'onlooker'.
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local FP=require('./perf152_fp')(W);FP.orderedPairs()
math.randomseed(152)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local noop=function()end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
local Mixer=W.module('AudioMixer');Mixer.Start()
do
 local queue={}
 W.service('Debris').AddItem=function(_,item,ttl)queue[#queue+1]={Item=item,At=R.clock+(tonumber(ttl)or 10)}end
 W.Run.Heartbeat:Connect(function()for i=#queue,1,-1 do if R.clock>=queue[i].At then local d=table.remove(queue,i);pcall(function()d.Item:Destroy()end)end end end)
end
local Players=W.service('Players')
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules')
local World=W.module('RarePullWorld');local M=W.module('RarePullCinematic')
local Art=W.module('RarePullArt')
local B=W.module('ClientFxBudget')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
local SS=W.service('SoundService');local Lighting=W.service('Lighting')
Art.Hooks.Spawn=function(fn)fn()end;Art.Hooks.Wait=noop
Art.Hooks.Create=function(w,h,rgba)return {W=w,H=h,Destroy=noop}end;Art.Hooks.Content=function(o)return 'rbxtemp://r152/'..o.W..'x'..o.H end
Art.Request(Art.Order)
local others={}
function Players.GetPlayers()local out={X.player};for _,p in ipairs(others)do if p.Parent then out[#out+1]=p end end;return out end
function Players.GetPlayerFromCharacter(_,c)if c==X.char then return X.player end;for _,p in ipairs(others)do if p.Character==c then return p end end;return nil end
local function body(model,x,z)
 local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(x,5,z);t.Parent=model
 local h=R.new('Part');h.Name='HumanoidRootPart';h.Size=V3(2,2,1);h.CFrame=CF(x,3,z);h.Parent=model
 local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.Parent=model
 return h,hum
end
local onlooker=R.new('Player');onlooker.Name='Onlooker';onlooker.UserId=500;onlooker.Parent=Players;others[1]=onlooker
local onlookerChar=R.new('Model');onlookerChar.Name='Onlooker';onlookerChar.Parent=W.workspace;onlooker.Character=onlookerChar;body(onlookerChar,12,96)
local function serverBag(char,stage,variant)
 local bag=Visuals.CarryBag(char,stage,variant,1,1,'None',nil)
 bag:SetAttribute('PackClickCount',0);bag:SetAttribute('PackClicksRequired',Rules.OpenClicks)
 return bag
end
local function reveal(bag,seedId)
 local name=Rules.GetRarity(seedId)
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',name)
 bag:SetAttribute('RevealDuration',Rules.GetRevealDuration(name));bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
end
local function packTool(char,stage,n)
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='s'..n,Stage=stage},nil);tool.Activated=R.signal();tool.Enabled=true;tool.Parent=char
 return tool
end
local function device(kind)
 local tier=kind=='low'and 1 or kind=='phone'and 2 or 3
 X.lowFx=tier==1;W.UIS.TouchEnabled=kind~='desktop';W.UIS.KeyboardEnabled=kind=='desktop'
 B.Get=function()return tier end;B.Low=function()return tier==1 end
 return tier
end
-- the client scripts
do
 local spc=R.new('LocalScript');spc.Name='SeedPackClient';W.load('SeedPackClient',spc)
 local pof=R.new('LocalScript');pof.Name='PackOpeningFeedback';W.load('PackOpeningFeedback',pof)
 W.frames(4,1/30)
end
cam.FieldOfView=70
local static={}
for _,c in ipairs(W.workspace:GetChildren())do static[c]=true end
local function roots()
 local list={cam,X.char,onlookerChar}
 for _,c in ipairs(W.workspace:GetChildren())do if not static[c]then list[#list+1]=c end end
 table.sort(list,function(a,b)return tostring(a._props.Name)<tostring(b._props.Name)end)
 list[#list+1]=X.pg;list[#list+1]=SS;list[#list+1]=Lighting
 return list
end
local function n4(v)return FP.num(v)end
local count=0
for _,sc in ipairs(SEED_SET or{})do
 local dev,rank,fps,who=sc[1],sc[2],sc[3],sc[4]or'own'
 local tier=device(dev);local dt=1/fps
 local label=string.format('seed %s t%d %s %s %dfps',dev,tier,who,names[rank],fps)
 -- a clean start: nothing left of the previous opening, the camera and the player where every opening starts
 M.Abort('next');World.Clear()
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 W.frames(math.floor(4/dt),dt)
 local char=who=='own'and X.char or onlookerChar
 local tool=who=='own'and packTool(X.char,2,rank)or nil
 local bag=serverBag(char,2,'Pack06')
 for i=1,Rules.OpenClicks do bag:SetAttribute('PackClickCount',i);bag:SetAttribute('PackClickAt',W.workspace:GetServerTimeNow());W.frames(math.max(1,math.floor(.12/dt+.5)),dt)end
 local t0=R.clock
 Y.record(function()return R.clock-t0 end)
 reveal(bag,X.byRank[rank])
 local dur=Rules.GetRevealDuration(names[rank])
 local f=0;local quiet=0;local st=FP.stream(label)
 FP.timesReset();FP.probeStart()
 while true do
  FP.timeHandlers(W.Run);W.frames(1,dt);f+=1
  if f==math.floor(dur/dt+.5)then bag:Destroy();if tool then tool:Destroy()end end -- the server ends the opening
  st:frame('f'..f,roots())
  local busy=M.Active()~=nil or W.workspace:FindFirstChild('_RarePullStage')~=nil or X.pg:FindFirstChild('RarePullReveal')~=nil
  if not busy and f*dt>dur then quiet+=1 else quiet=0 end
  if quiet*dt>=1 or f*dt>40 then break end
 end
 local frames=Y.stop()
 local probe=FP.probeStop();local tm=FP.timed()
 local chunks={};for k,v in pairs(tm)do chunks[#chunks+1]=k end;table.sort(chunks)
 local parts={};for _,k in ipairs(chunks)do if tm[k]*1000/f>=.0005 then parts[#parts+1]=string.format('%s %.3f ms',k,tm[k]*1000/f)end end
 print(string.format('PERF seed %s frames=%d lua: %s | %s',label,f,table.concat(parts,', '),FP.probeText(probe,f,10)))
 -- the sound schedule: every play (slot, start time from the reveal, file position, speed, volume, when it ends) and the voices heard on every frame
 local plays={}
 for _,p in ipairs(Y.plays(t0))do plays[#plays+1]=string.format('%s@%s pos=%s x%s v=%s end=%s',tostring(p.Slot or p.Sound.Name),n4(p.At-t0),n4(p.Pos or 0),n4(p.Speed or 1),n4(p.Volume or 0),p.Ends==math.huge and'loop'or n4(p.Ends-t0))end
 FP.fact(label..' plays',table.concat(plays,'; '))
 local heard={}
 for i,fr in ipairs(frames)do
  local v={};for _,x in ipairs(fr.Voices)do v[#v+1]=x.Sound.Name..'='..n4(x.Gain)..'@'..n4(x.Pos)end;table.sort(v)
  heard[#heard+1]=i..':'..table.concat(v,',')
 end
 FP.fact(label..' heard',table.concat(heard,' '))
 count+=1
end
print('PERF152 SEED DONE '..count)
