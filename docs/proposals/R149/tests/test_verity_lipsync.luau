--!nocheck
-- R149 (owner: "sync verity's voice and cut the audio to only hello my name verity and also change the picture of verity to its 3d model
-- talking and remove the event ends thing"): the real VerityClient on the Roblox mock, with a Sound that behaves like the engine's
-- (it plays from TimePosition, stops at the end of its PlaybackRegion and fires Ended, reports a PlaybackLoudness that follows a scripted
-- "Hello, my name is Verity" and then, past the cut, the rest of the clip), and the real VerityVoice / VerityConfig / ItemPictures / AudioMixer.
--  1. The cut: EVERY greeting (Talk, coming close, the owner's /test verityvoice message, a live override on her model, a changed config)
--     sets PlaybackRegionsEnabled and PlaybackRegion = (Start, Stop) BEFORE it plays, starts at Start, never runs past Stop (the rest of the
--     clip is never heard), fades the volume over the last GreetingFade seconds and restores it for the next one; a region the engine
--     refuses is warned about once and replaced by a timer cut; a clip that has not loaded yet is waited for (not cut by an early clock).
--  2. Lip sync in the world: her mouth (a dark oval, Sphere SpecialMesh, on the front of her ball) opens with the Sound's PlaybackLoudness
--     (smoothed: fast opening, slower closing), is wide on loud syllables and closed in pauses, swells her with it, follows her bob and
--     turn, and goes away when the sound stops or is cut; a talking rhythm runs for the length of the cut if no loudness is ever reported.
--  3. Nothing is done for nothing: idle = no loudness reads, no new instances, no writes; beyond AnimateDistance, with ReducedMotion or
--     with the Effects volume at 0 no mouth is made (her sound still plays, fades and ends).
--  4. The window's portrait (a ViewportFrame with her 3D model) has the same lip sync, while the dialog is open only, and is torn down on close.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
F.packAssets(W)
-- Instrumentation of the mock's instances: how often a Sound's PlaybackLoudness is read, and every property write to a named instance.
local loudReads,trackWrites,writes,regionRefused,stepCalls=0,false,{},false,0
do
 local baseIndex=R.instMeta.__index
 R.instMeta.__index=function(o,k)
  if k=='PlaybackLoudness'then loudReads+=1 end
  return baseIndex(o,k)
 end
 local baseNew=R.instMeta.__newindex
 R.instMeta.__newindex=function(o,k,v)
  if o._class=='Sound'and k=='PlaybackRegion'and regionRefused then error('lacking capability',2)end
  if trackWrites and k~='Parent'then local key=rawget(o,'_props').Name..'.'..k;writes[key]=(writes[key]or 0)+1 end
  return baseNew(o,k,v)
 end
end
-- The Sound: plays from TimePosition, follows the clock, honours PlaybackRegion (stops and fires Ended at its end), and reports a PlaybackLoudness
-- that follows the scripted clip: "Hello, my name is Verity" up to 1.9 s (syllable bursts with pauses between), then more speech past the cut.
local SEGMENTS={{.05,.25,420},{.40,.62,520},{.80,1.00,380},{1.15,1.50,600},{1.60,1.72,300},{1.78,1.90,480},{1.90,2.60,550}}
local loudMode='speech' -- 'speech' | 'silent' (0 while playing) | 'missing' (no PlaybackLoudness at all)
local function loudAt(t)for _,s in ipairs(SEGMENTS)do if t>=s[1]and t<s[2]then return s[3]end end;return 0 end
local sounds,plays,playing,maxOverlap,ends={},{},0,0,{}
local playMode=nil
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='Sound'then
  o.Ended=R.signal();o.Loaded=R.signal();o.IsPlaying=false;o.IsLoaded=true;o.TimeLength=3.2;o.TimePosition=0;o.PlaybackLoudness=0;o.PlaybackRegionsEnabled=false
  sounds[#sounds+1]=o
  function o.Play(self)
   if playMode=='throw'then error('cannot play this sound')end
   local region=self.PlaybackRegion
   plays[#plays+1]={Sound=self,At=R.clock,Enabled=self.PlaybackRegionsEnabled,Min=region and region.Min,Max=region and region.Max,TimePosition=self.TimePosition,Volume=self.Volume,Parent=self.Parent,
    Group=self.SoundGroup}
   self._t0=R.clock;self._p0=self.TimePosition;self.IsPlaying=true;playing+=1;maxOverlap=math.max(maxOverlap,playing)
  end
  function o.Stop(self)if self.IsPlaying then self.IsPlaying=false;playing-=1;self.PlaybackLoudness=0;ends[#ends+1]={Sound=self,At=R.clock,Stopped=true}end end
 end
 return o end end
local function endSound(s)s.IsPlaying=false;playing-=1;s.PlaybackLoudness=0;ends[#ends+1]={Sound=s,At=R.clock};s.Ended:Fire()end
W.Run.RenderStepped:Connect(function() -- (connected before the client's own loop, so each frame the engine moves first)
 for _,s in ipairs(sounds)do if s.IsPlaying then
  local t=s._p0+(R.clock-s._t0);s.TimePosition=t
  local region=s.PlaybackRegionsEnabled and s.PlaybackRegion
  if region and t>=region.Max then endSound(s)
  elseif t>=s.TimeLength then endSound(s)
  else
   if loudMode=='speech'then s.PlaybackLoudness=loudAt(t)elseif loudMode=='silent'then s.PlaybackLoudness=0 else s._props.PlaybackLoudness=nil end
  end
 end end
end)
local preloadCalls=0
local CP=W.service('ContentProvider')
function CP.PreloadAsync(_,list,cb)preloadCalls+=1;for _,x in ipairs(list)do if cb then cb(x.SoundId,R.Enum.AssetFetchStatus.Success)end end end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local backpack=R.new('Backpack');backpack.Parent=player
local character=R.new('Model');character.Name='Tester';character.Parent=W.workspace;player.Character=character
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,7,-150);root.Parent=character
local function standAt(x,y,z)root.CFrame=CF(x,y,z)end
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end})
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='VerityQuest';remote.OnClientEvent=R.signal();remote.Parent=remotes
local fired={};function remote.FireServer(_,...)fired[#fired+1]={...}end
local C=W.module('VerityConfig');local Mixer=W.module('AudioMixer');local Voice=W.module('VerityVoice')
local SoundService=W.service('SoundService')
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=map
local model=R.new('Model');model.Name='VerityNPC';model.Parent=hub
local bodyAt=V3(0,16.45,-340)
local body=R.new('Part');body.Name='Body';body.Shape=R.Enum.PartType.Ball;body.Size=V3(22,22,22);body.CFrame=R.CFrame.lookAt(bodyAt,bodyAt+V3(0,0,1));body.Anchored=true;body.Color=R.Color3.fromRGB(255,255,0);body.Parent=model
local S=C.Sign
do
 local sg=R.new('BillboardGui');sg.Name='NameSign';sg.Adornee=body;sg.Size=R.UDim2.new(S.W,0,S.H,0);sg.StudsOffset=V3(0,11+S.Gap+S.H/2,0);sg.Parent=body
 local nl=R.new('TextLabel');nl.Name='Name';nl.Text='VERITY';nl.Parent=sg
end
W.CS:AddTag(model,'VerityNPC')
local camera=W.workspace.CurrentCamera
local function aim(x,y,z)camera.CFrame=CF(x,y,z)end
-- Layout emulation (absolute rects from UDim2 + AnchorPoint + UISizeConstraint, as the R147 client test).
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  if s and p then
   local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
   local lim=c:FindFirstChildOfClass('UISizeConstraint');if lim and lim.MaxSize then w=math.min(w,lim.MaxSize.X);h=math.min(h,lim.MaxSize.Y)end
   local x=px+p.X.Scale*pw+p.X.Offset-a.X*w;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h
   set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
   lay(c,x,y,w,h)
  end
 end end
end
local screen=R.Vector2.new(1280,720)
local function frames(n,dt)
 for _=1,n do
  for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')then if g.AbsoluteSize~=screen then g.AbsoluteSize=screen end;lay(g,0,0,screen.X,screen.Y)end end
  W.frames(1,dt)
 end
end
local function seconds(t)frames(math.floor(t*60+.5))end
local function rect(o)return {X=o.AbsolutePosition.X,Y=o.AbsolutePosition.Y,W=o.AbsoluteSize.X,H=o.AbsoluteSize.Y}end
local function server(kind,payload)remote.OnClientEvent:Fire(kind,payload);frames(2)end
do local realStep=Voice.Step;Voice.Step=function(...)stepCalls+=1;return realStep(...)end end -- (the client calls Voice.Step through the module table)
local sc=R.new('LocalScript');sc.Name='VerityClient'
R.clock=W.module('LimitedEvent').EndsAt-27*86400
local okLoad,errLoad=pcall(W.load,'VerityClient',sc);check(okLoad,'VerityClient loads: '..tostring(errLoad))
frames(5)
local gui=pg:FindFirstChild('VerityGui');local panel=gui.VerityPanel
local function greetingPlays()local out={};for _,p in ipairs(plays)do if p.Sound.Name=='VerityGreeting'then out[#out+1]=p end end;return out end
local function lastPlay()local g=greetingPlays();return g[#g]end
local function closeWindow()panel.Header.Close.Activated:Fire();frames(2)end
local function settleDown()closeWindow();seconds(3.2);aim(0,20,-300);standAt(0,7,-150);frames(5)end
local function mouthOf()return model:FindFirstChild('VerityMouth')end
local function openness(m)return m and m.Size.Y/body.Size.X/C.Mouth.Height or 0 end -- 0..1: the oval's height as a share of its full opening
local function fullRun(trigger,maxSeconds) -- run a greeting to its end, sampling every frame
 local samples={};local t0=R.clock;trigger()
 for _=1,math.floor((maxSeconds or 3)*60)do
  frames(1)
  local s=lastPlay()and lastPlay().Sound
  samples[#samples+1]={T=s and s.TimePosition or 0,Loud=s and s._props.PlaybackLoudness or 0,Open=openness(mouthOf()),Size=body.Size.X,Volume=s and s.Volume or 0,Playing=s and s.IsPlaying}
 end
 return samples,t0
end

-- 1. The cut: every way she speaks sets the region before playing -------------------------------------------------------------------------
check(C.GreetingStart==0 and C.GreetingEnd==1.9 and C.GreetingFade==.08,'VerityConfig: GreetingStart 0, GreetingEnd 1.9 (to be tuned in Studio), GreetingFade .08')
aim(0,20,-300);standAt(0,7,-150);frames(30)
check(#greetingPlays()==0 and playing==0,'(nothing has played yet)')
server('Open',{VoidPacks=0,Delivered=0})
local p1=lastPlay()
check(p1~=nil and p1.Sound.Parent==body,'Talk (the dialog opens): the greeting plays from her body')
check(p1 and p1.Enabled==true and p1.Min==C.GreetingStart and p1.Max==C.GreetingEnd,'PlaybackRegionsEnabled and PlaybackRegion = '..tostring(p1 and p1.Min)..' .. '..tostring(p1 and p1.Max)..' were set before it played (VerityConfig.GreetingStart / GreetingEnd)')
check(p1 and p1.TimePosition==C.GreetingStart,'it starts at GreetingStart')
check(p1 and p1.Volume==C.GreetingVolume,'at the configured volume')
check(p1 and p1.Sound.SoundGroup==Mixer.Group('Effects'),'still routed through the Effects volume')
check(p1.Sound.RollOffMode==R.Enum.RollOffMode.InverseTapered and p1.Sound.RollOffMinDistance==C.GreetingRollOffMin and p1.Sound.RollOffMaxDistance==C.GreetingRollOffMax,'and still 3D (InverseTapered)')
-- It ends at the end of the cut, not at the end of the 3.2 s clip, and the rest of the clip is never heard.
local sound=p1.Sound
local run=(function()local out={};for _=1,150 do frames(1);out[#out+1]={T=sound.TimePosition,Loud=sound._props.PlaybackLoudness,Playing=sound.IsPlaying,Volume=sound.Volume,At=R.clock}end;return out end)()
local heard=0;local lastEnd=ends[#ends]
check(not sound.IsPlaying and lastEnd and lastEnd.Sound==sound and near(lastEnd.At-p1.At,C.GreetingEnd-C.GreetingStart,.12),string.format('it stops %.2f s after it started (the cut is %.2f s long, the clip 3.2 s)',lastEnd and lastEnd.At-p1.At or -1,C.GreetingEnd-C.GreetingStart))
local pastCut=false;for _,r in ipairs(run)do if r.Playing and r.T>C.GreetingEnd+.02 then pastCut=true end end
check(not pastCut,'no frame of the audio past the end of the cut is ever played ("i-ty" of the rest of the clip is not heard)')
-- The fade: full volume until GreetingFade before the end, then ramping to nothing, never an abrupt stop at full volume.
do
 local early,fading,lastGain,monotone=true,0,1,true
 for _,r in ipairs(run)do if r.Playing then
  local gain=r.Volume/C.GreetingVolume
  if r.T<C.GreetingEnd-C.GreetingFade-.001 and not near(gain,1,1e-6)then early=false end
  if r.T>C.GreetingEnd-C.GreetingFade and gain<1 then fading+=1 end
  if r.T>C.GreetingEnd-C.GreetingFade-.001 and gain>lastGain+1e-9 then monotone=false end
  lastGain=gain
 end end
 check(early and fading>=3 and monotone,'the volume is full until the last '..C.GreetingFade..' s, then ramps down ('..fading..' frames of fade)')
 local lastPlaying;for _,r in ipairs(run)do if r.Playing then lastPlaying=r end end
 check(lastPlaying and lastPlaying.Volume/C.GreetingVolume<.35,string.format('the last frame played is already faded (%.0f%% of the volume), so stopping does not click',lastPlaying and 100*lastPlaying.Volume/C.GreetingVolume or -1))
 check(near(sound.Volume,C.GreetingVolume,1e-9),'and the volume is back to normal once it has stopped ('..tostring(sound.Volume)..')')
end
-- Another Talk plays it again at once, at full volume, from the start of the cut.
closeWindow();server('Open',{VoidPacks=0,Delivered=0})
local p2=lastPlay()
check(#greetingPlays()==2 and p2.Volume==C.GreetingVolume and p2.TimePosition==C.GreetingStart and p2.Enabled and p2.Max==C.GreetingEnd,'Talk again: the same cut, at full volume')
seconds(2.2);closeWindow()
-- Coming close greets with the same cut.
standAt(0,7,-150);frames(60);R.advance(70);local n0=#greetingPlays()
standAt(0,7,-315);frames(40)
local p3=lastPlay()
check(#greetingPlays()==n0+1 and p3.Enabled and p3.Min==C.GreetingStart and p3.Max==C.GreetingEnd,'coming within range: the proximity greeting is cut the same way ('..tostring(p3.Min)..' .. '..tostring(p3.Max)..')')
seconds(2.2);standAt(0,7,-150);frames(5)
-- A changed config is picked up by the next greeting.
do
 local s0,e0=C.GreetingStart,C.GreetingEnd
 C.GreetingStart=.4;C.GreetingEnd=1.2
 R.advance(70);local n=#greetingPlays();standAt(0,7,-315);frames(40);local p=lastPlay()
 check(#greetingPlays()==n+1 and p.Min==.4 and p.Max==1.2 and p.TimePosition==.4,'a new GreetingStart / GreetingEnd in VerityConfig is used by the next greeting (.4 .. 1.2)')
 seconds(1.2)
 check(near(ends[#ends].At-p.At,.8,.1),'and it is .8 s long ('..string.format('%.2f',ends[#ends].At-p.At)..')')
 C.GreetingStart=s0;C.GreetingEnd=e0;standAt(0,7,-150);frames(5)
end
-- The owner's live override on her model (attributes set by /test verityvoice on the server) wins over the config, for every greeting.
do
 model:SetAttribute('VerityVoiceStart',.5);model:SetAttribute('VerityVoiceEnd',2.1)
 closeWindow();server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay()
 check(p.Min==.5 and p.Max==2.1 and p.TimePosition==.5 and p.Enabled,'the live override on her model (VerityVoiceStart .5 / VerityVoiceEnd 2.1) is what Talk plays')
 seconds(2.6)
 check(near(ends[#ends].At-p.At,1.6,.12),'and it ends 1.6 s later ('..string.format('%.2f',ends[#ends].At-p.At)..')')
 closeWindow();R.advance(70);local n=#greetingPlays();standAt(0,7,-150);frames(40);standAt(0,7,-315);frames(40)
 check(#greetingPlays()==n+1 and lastPlay().Min==.5 and lastPlay().Max==2.1,'and what coming close plays')
 seconds(2.6);standAt(0,7,-150);frames(5)
 model:SetAttribute('VerityVoiceStart',nil);model:SetAttribute('VerityVoiceEnd',nil)
 model:SetAttribute('VerityVoiceStart',.5) -- a half pair is not an override
 closeWindow();server('Open',{VoidPacks=0,Delivered=0})
 check(lastPlay().Min==C.GreetingStart and lastPlay().Max==C.GreetingEnd,'one number alone is ignored: back to the config')
 seconds(2.3);closeWindow();model:SetAttribute('VerityVoiceStart',nil)
 model:SetAttribute('VerityVoiceStart',0/0);model:SetAttribute('VerityVoiceEnd',1/0);server('Open',{VoidPacks=0,Delivered=0})
 check(lastPlay().Min==C.GreetingStart and lastPlay().Max==C.GreetingEnd,'NaN / infinity in the attributes are ignored too')
 seconds(2.3);closeWindow();model:SetAttribute('VerityVoiceStart',nil);model:SetAttribute('VerityVoiceEnd',nil)
end
-- The cut never runs past the clip once its length is known.
do
 local s=lastPlay().Sound;s.TimeLength=1.5
 server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay()
 check(p.Max==1.5 and p.Min==0,'a clip only 1.5 s long: the region ends at 1.5, not 1.9')
 seconds(2);closeWindow();s.TimeLength=3.2
end
-- The owner's /test verityvoice message: plays at once, from anywhere, whatever the cooldown, flat (2D), with the numbers it brings.
do
 aim(0,20,200);standAt(900,7,900);frames(5);local n=#greetingPlays()
 server('Greet',{Start=.2,End=1.1});local p=lastPlay()
 check(#greetingPlays()==n+1 and p.Min==.2 and p.Max==1.1 and p.TimePosition==.2 and p.Enabled,'a Greet message plays its own cut at once (.2 .. 1.1), 900 studs from her, inside the cooldown')
 check(p.Sound.Parent==SoundService,'as a flat sound in SoundService, so it is heard from anywhere (not 3D from her body)')
 check(p.Sound.SoundGroup==Mixer.Group('Effects'),'(still through the Effects volume)')
 seconds(1.2)
 check(near(ends[#ends].At-p.At,.9,.1) and playing==0,'and it is .9 s long ('..string.format('%.2f',ends[#ends].At-p.At)..')')
 -- Again while it is still playing: it restarts with the new numbers (the owner is hunting for the end), never two at once.
 server('Greet',{Start=0,End=1.9});local first=lastPlay();seconds(.5)
 server('Greet',{Start=0,End=2.4});local second=lastPlay()
 check(second~=first and second.Max==2.4 and playing==1 and maxOverlap==1,'asked again while playing: it restarts with the new end, one copy at a time (most at once: '..maxOverlap..')')
 seconds(3)
 check(near(ends[#ends].At-second.At,2.4,.12),'and plays the whole new cut ('..string.format('%.2f',ends[#ends].At-second.At)..' s)')
 -- Garbage numbers fall back to the live values / the config; garbage payloads do nothing bad.
 local n2=#greetingPlays();server('Greet',{Start='x',End=0/0});check(#greetingPlays()==n2+1 and lastPlay().Min==C.GreetingStart and lastPlay().Max==C.GreetingEnd,'a Greet with bad numbers falls back to the config cut')
 seconds(2.2)
 local ok=pcall(function()remote.OnClientEvent:Fire('Greet',nil);remote.OnClientEvent:Fire('Greet',5);remote.OnClientEvent:Fire('Greet',{});frames(2)end)
 check(ok,'nil / non-table / empty Greet payloads are handled')
 seconds(2.2)
 Mixer.Set('Effects',0);local n3=#greetingPlays();server('Greet',{Start=0,End=1.9})
 check(#greetingPlays()==n3,'Effects volume 0: no voice for a Greet either');Mixer.Set('Effects',100)
 -- Back to a normal greeting afterwards: from her body again.
 standAt(0,7,-150);aim(0,20,-300);frames(5);closeWindow();server('Open',{VoidPacks=0,Delivered=0})
 check(lastPlay().Sound.Parent==body and lastPlay().Max==C.GreetingEnd,'a Talk after the test is a normal 3D greeting from her body again')
 seconds(2.3);closeWindow()
end
-- The engine refuses the region (a property a game script cannot set): warned once, and a timer cuts the clip instead.
do
 regionRefused=true;local warns0=W.warns or 0
 lastPlay().Sound:Destroy() -- (a fresh Sound: an old one would keep the region of its last playing)
 closeWindow();server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay()
 check(not p.Enabled or p.Min==nil,'(this Sound has no PlaybackRegion at all: the engine refused it)')
 seconds(3)
 local took=ends[#ends].At-p.At
 check(near(took,C.GreetingEnd-C.GreetingStart,.12),string.format('PlaybackRegion refused: the client still cuts it at %.2f s (the cut is %.2f s, the clip 3.2 s)',took,C.GreetingEnd-C.GreetingStart))
 check(playing==0,'(and it stopped)')
 closeWindow();server('Open',{VoidPacks=0,Delivered=0});seconds(3);closeWindow()
 check((W.warns or 0)==warns0+1,'warned exactly once ('..((W.warns or 0)-warns0)..' warnings)')
 regionRefused=false
end
-- A clip that has not loaded yet: wait for it, then play (not cut by a clock that started early); give up after .5 s (R150; it was 3 s) without blocking later ones.
do
 settleDown()
 local s=lastPlay().Sound;s.IsLoaded=false;s.TimeLength=0;local n=#greetingPlays()
 server('Open',{VoidPacks=0,Delivered=0});seconds(.5)
 check(#greetingPlays()==n and playing==0,'the clip is not loaded: nothing plays yet')
 server('Open',{VoidPacks=0,Delivered=0});seconds(.3)
 check(#greetingPlays()==n,'(asking again while it waits does not queue a second one)')
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n+1 and lastPlay().Enabled and lastPlay().Max==C.GreetingEnd and lastPlay().TimePosition==C.GreetingStart,'it loads: it plays once, with the cut')
 local t0=lastPlay().At;seconds(2.5)
 check(near(ends[#ends].At-t0,C.GreetingEnd-C.GreetingStart,.12),'and the cut is timed from when the audio really started ('..string.format('%.2f',ends[#ends].At-t0)..' s)')
 closeWindow();s.IsLoaded=false;s.TimeLength=0;local n2=#greetingPlays();server('Open',{VoidPacks=0,Delivered=0});seconds(3.4)
 check(#greetingPlays()==n2,'a clip that never loads: nothing plays, nothing errors')
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n2,'(and a late load after the 3 s wait does not play a greeting nobody asked for now)')
 server('Open',{VoidPacks=0,Delivered=0})
 check(#greetingPlays()==n2+1,'a later Talk is not blocked by the earlier wait: it plays')
 seconds(2.3);closeWindow()
 -- IsLoaded can lag behind the length: a Sound that already knows its length (TimeLength > 0) is loaded.
 s.IsLoaded=false;local n3=#greetingPlays();server('Open',{VoidPacks=0,Delivered=0})
 check(#greetingPlays()==n3+1,'a Sound whose IsLoaded still reads false but whose TimeLength is known plays at once')
 seconds(2.3);closeWindow();s.IsLoaded=true
end
-- R150: a greeting is skipped, never spoken late. The wait for a clip that has not loaded is bounded by .5 s (it was 3 s), counted from when she
-- was ASKED to speak, and a 'talk' greeting also needs her window to still be open when the clip arrives.
do
 settleDown()
 local s=lastPlay().Sound;local n=#greetingPlays()
 s.IsLoaded=false;s.TimeLength=0;server('Open',{VoidPacks=0,Delivered=0});seconds(.4)
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n+1,'R150: a clip that loads .4 s after she was asked plays')
 seconds(2.3);closeWindow()
 n=#greetingPlays();s.IsLoaded=false;s.TimeLength=0;server('Open',{VoidPacks=0,Delivered=0});seconds(.7)
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n,'R150: a clip that arrives .7 s after she was asked is skipped, not spoken late')
 closeWindow();seconds(1)
 n=#greetingPlays();s.IsLoaded=false;s.TimeLength=0;server('Open',{VoidPacks=0,Delivered=0});seconds(.2);closeWindow()
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n,'R150: a Talk greeting whose window was closed before the clip loaded is skipped')
 settleDown()
end

-- 2. Lip sync in the world -----------------------------------------------------------------------------------------------------------------
settleDown()
check(mouthOf()==nil,'no mouth while she is not talking (her smile picture is her closed mouth)')
local samples,t0=fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.6)
local mouthSeen;for _,sm in ipairs(samples)do if sm.Open>0 then mouthSeen=true end end
check(mouthSeen,'the mouth appears while she talks')
local m
do -- the part: what it is made of and where it sits
 server('Open',{VoidPacks=0,Delivered=0});seconds(.6);m=mouthOf()
 check(m and m:IsA('Part')and m.Anchored and not m.CanCollide and not m.CanQuery and not m.CanTouch and not m.CastShadow,'the mouth is an anchored Part that never collides, is never queried or touched, casts no shadow')
 local mesh=m and m:FindFirstChildOfClass('SpecialMesh');check(mesh and mesh.MeshType==R.Enum.MeshType.Sphere,'a Sphere SpecialMesh, so its three sizes are independent (an oval, not a ball)')
 check(m and m.Color==C.Mouth.Color and m.Parent==model,'dark (VerityConfig.Mouth.Color), in her model')
 check(W.CS:HasTag(m,'GiantVisualPart'),'tagged GiantVisualPart (the camera right up against her fades it with her body)')
 local rel=body.CFrame:Inverse()*m.CFrame.Position
 local d=body.Size.X;local y=d*C.Mouth.Y;local z=-math.sqrt((d/2)^2-y^2)
 check(near(rel.X,0,1e-6)and near(rel.Y,y,1e-6)and near(rel.Z,z,1e-6),string.format('it sits on the front of her ball: %.2f below the centre, %.2f out along her face (surface %.2f)',-rel.Y,-rel.Z,-z))
 check(near((body.CFrame.LookVector.X*m.CFrame.LookVector.X+body.CFrame.LookVector.Z*m.CFrame.LookVector.Z),1,1e-6),'and faces the way she does')
 local pose=Voice.MouthPose(C,body.Size.X,1)
 check(m.Size.X<=pose.W+1e-6 and m.Size.Y<=pose.H+1e-6 and m.Size.Z==pose.D,'never larger than the full-open oval')
 seconds(2.4)
end
-- Loudness drives it: wide on loud syllables, nearly shut in pauses, and the swell follows the same level.
local function windowOf(list,a,b)local out={};for _,sm in ipairs(list)do if sm.T>=a and sm.T<b then out[#out+1]=sm end end;return out end
local function peak(list,key)local v=0;for _,sm in ipairs(list)do v=math.max(v,sm[key])end;return v end
local function last(list,key)return list[#list]and list[#list][key]or 0 end
settleDown()
samples=fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.6)
local loudSyl=windowOf(samples,1.15,1.50);local quietSyl=windowOf(samples,1.60,1.72);local gap1=windowOf(samples,.62,.80);local gap2=windowOf(samples,1.00,1.15)
check(peak(loudSyl,'Open')>.85,string.format('a loud syllable ("name", loudness 600) opens the mouth wide (%.2f of full)',peak(loudSyl,'Open')))
check(peak(quietSyl,'Open')<peak(loudSyl,'Open')-.1 and peak(quietSyl,'Open')>.2,string.format('a quieter one ("is", 300) opens it less (%.2f)',peak(quietSyl,'Open')))
check(last(gap1,'Open')<.15 and last(gap2,'Open')<.15,string.format('in the pauses it closes (%.2f and %.2f of full open at the end of the two gaps)',last(gap1,'Open'),last(gap2,'Open')))
check(peak(windowOf(samples,.05,.25),'Open')>.5,'the first syllable ("Hel", loudness 420) opens it as well')
-- Fast to open, slower to close.
do
 local function framesTo(list,from,pred)local n=0;for _,sm in ipairs(list)do if sm.T>=from then n+=1;if pred(sm)then return n end end end;return math.huge end
 local opening=framesTo(samples,1.15,function(sm)return sm.Open>.6 end)
 local closing=framesTo(samples,1.50,function(sm)return sm.Open<.4 end)
 check(opening<closing,string.format('it opens faster than it closes (%d frames to open past .6 at the start of "name", %d to close below .4 after it)',opening,closing))
end
do
 local loudest=0;for _,sm in ipairs(samples)do if sm.T>=.05 and sm.T<1.9 then loudest=math.max(loudest,sm.Size)end end
 check(loudest>22*(1+C.TalkPulse*.7)and loudest<=22*(1+C.TalkPulse)+1e-6,string.format('she swells with the same level: up to %.2f of her 22 studs on the loud syllables',loudest))
 local quietSize=peak(windowOf(samples,.66,.80),'Size')
 check(quietSize<loudest-.1,string.format('and is smaller in a pause (%.2f)',quietSize))
end
-- It stops cleanly when the cut ends: nothing of the rest of the clip is heard, so the mouth closes, goes away, and she is back to 22 studs exactly.
do
 seconds(.6)
 check(mouthOf()==nil or mouthOf().Parent==nil,'the mouth is gone shortly after the cut ends')
 check(body.Size.X==22 and body.Size.Y==22,'and she is exactly 22 studs again')
 local endedAt=ends[#ends].At;local loudAfter=0;for _,sm in ipairs(samples)do if sm.T>C.GreetingEnd+.02 then loudAfter=math.max(loudAfter,sm.Loud)end end
 check(loudAfter==0,'no loudness from past the cut was ever heard (the mouth cannot move to words that are not played)')
end
-- Follows her bob and her turn while she talks.
do
 settleDown();server('Open',{VoidPacks=0,Delivered=0});seconds(.55)
 local worst=0
 for _,cam in ipairs({{100,20,-340},{-100,20,-340},{0,20,-440},{0,20,-300}})do
  aim(cam[1],cam[2],cam[3]);for _=1,8 do frames(1)
   local mm=mouthOf();if mm then
    local rel=body.CFrame:Inverse()*mm.CFrame.Position;local d=body.Size.X;local y=d*C.Mouth.Y;local z=-math.sqrt((d/2)^2-y^2)
    worst=math.max(worst,(rel-V3(0,y,z)).Magnitude)
   end
  end
 end
 check(worst<1e-6,string.format('the mouth stays on her face while she turns to the camera from every side and bobs (worst offset %.1e studs)',worst))
 seconds(2.2);aim(0,20,-300);frames(5)
end
-- A sound stopped from outside (another greeting, the engine): the mouth closes, nothing is left running.
do
 settleDown();server('Open',{VoidPacks=0,Delivered=0});seconds(.55)
 check(mouthOf()~=nil and mouthOf().Parent==model,'(talking: the mouth is up)')
 lastPlay().Sound:Stop();seconds(.9)
 check(mouthOf()==nil or mouthOf().Parent==nil,'the sound is stopped under her: the mouth closes and goes away')
 check(body.Size.X==22,'and she is back to her size')
 local before=loudReads;seconds(.5);check(loudReads==before,'and nothing reads the loudness any more')
 closeWindow()
end
-- No loudness reported (the engine cannot measure it): a talking rhythm for the length of the cut, then nothing.
do
 loudMode='silent';settleDown()
 samples=fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.6)
 local firstOpen,opens,wasOpen=nil,0,false;local maxOpen=0
 for _,sm in ipairs(samples)do
  local o=sm.Open>.3;if o and not wasOpen then opens+=1 end;wasOpen=o
  if o and not firstOpen then firstOpen=sm.T end
  maxOpen=math.max(maxOpen,sm.Open)
 end
 check(firstOpen and firstOpen>.2 and firstOpen<.7,string.format('no loudness: she starts the rhythm after a moment (first opening at %.2f s of the clip)',firstOpen or -1))
 check(opens>=4 and maxOpen>.6,string.format('and talks in syllables for the cut: %d openings, as wide as %.2f',opens,maxOpen))
 local pastEnd=0;for _,sm in ipairs(samples)do if not sm.Playing and sm.T>C.GreetingEnd+.1 and sm.Open>.2 then pastEnd+=1 end end
 seconds(.6)
 check(pastEnd==0 and (mouthOf()==nil or mouthOf().Parent==nil)and body.Size.X==22,'the rhythm stops with the cut: mouth gone, back to 22 studs')
 loudMode='missing';settleDown()
 local okMissing=pcall(function()fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.6)end)
 check(okMissing,'a Sound without a PlaybackLoudness at all does not break anything (the rhythm runs)')
 loudMode='speech';settleDown()
 -- Once real loudness has been heard, silence means a pause (the mouth closes), not "no loudness": no rhythm runs through the pauses.
 samples=fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.6)
 local g=windowOf(samples,.66,.78);check(last(g,'Open')<.15 and peak(windowOf(samples,.66,.78),'Open')<.5,'with real loudness, a pause stays shut (no rhythm is mixed in)')
 seconds(.8)
end

-- 3. Nothing is done for nothing -----------------------------------------------------------------------------------------------------------
settleDown();seconds(1)
do
 local reads0,created0=loudReads,#R.created;local steps0=stepCalls
 frames(300)
 check(loudReads==reads0 and stepCalls==steps0,'idle (not talking): 300 frames read the loudness 0 times and run the lip sync 0 times')
 check(#R.created==created0,'idle: 300 frames create no instance ('..(#R.created-created0)..')')
 trackWrites=true;writes={};frames(120);trackWrites=false
 local extra,bodySize={},0
 for k,n in pairs(writes)do
  if k=='Body.Size'then bodySize+=n
  elseif not(k:find('^Body%.'))and not k:find('^Mark%.')and not k:find('^Timer%.')then extra[#extra+1]=k..' x'..n end -- (the sign's once-a-second marker recount is older and not about her voice)
 end
 check(#extra==0 and bodySize==0,'idle: her bob is the only thing written (never her Size, no mouth, no portrait, no sound): '..table.concat(extra,', '))
end
-- Beyond AnimateDistance: the sound plays (and fades and ends) but no mouth is made, nothing is read, her body is left alone.
do
 aim(0,16.45,bodyAt.Z+C.AnimateDistance+40);frames(5);local reads0,created0=loudReads,#R.created
 local function newNonSounds(from)local out={};for i=from+1,#R.created do if R.created[i]._class~='Sound'then out[#out+1]=R.created[i]._class end end;return out end
 trackWrites=true;writes={}
 server('Greet',{Start=0,End=1.9});local p=lastPlay();seconds(2.4)
 trackWrites=false
 local bodyWrites=0;for k,n in pairs(writes)do if k:find('^Body%.')then bodyWrites+=n end end
 check(p.Enabled and p.Max==1.9 and not p.Sound.IsPlaying and near(ends[#ends].At-p.At,1.9,.12),'the camera 340 studs away: her greeting still plays and ends at the cut')
 check(loudReads==reads0 and #newNonSounds(created0)==0 and mouthOf()==nil,'but the loudness is not read (0 reads), no mouth is made and nothing but the Sound itself is created ('..table.concat(newNonSounds(created0),',')..')')
 check(bodyWrites==0 and body.Size.X==22,'and her body is not written to ('..bodyWrites..' writes)')
 local volumeBack=near(p.Sound.Volume,C.GreetingVolume,1e-9);check(volumeBack,'(the fade ran and the volume is restored: it is audio, not animation)')
 aim(0,20,-300);frames(5)
end
-- ReducedMotion: the voice (cut, fade) plays, but she does not move her mouth or swell.
do
 W.Gui.ReducedMotionEnabled=true;frames(3);local reads0,created0=loudReads,#R.created
 closeWindow();server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay();local biggest=0
 for _=1,150 do frames(1);biggest=math.max(biggest,body.Size.X)end
 check(p.Enabled and p.Max==C.GreetingEnd and not p.Sound.IsPlaying,'ReducedMotion: the voice plays and is cut as always')
 check(mouthOf()==nil and biggest==22,'but no mouth is made and she does not swell (largest size '..biggest..')')
 check(loudReads==reads0,'and the loudness is not read ('..(loudReads-reads0)..' reads)')
 check(near(p.Sound.Volume,C.GreetingVolume,1e-9),'(volume restored after the fade)')
 closeWindow();W.Gui.ReducedMotionEnabled=false;frames(3)
end
-- Effects at 0: no voice at all, so no mouth.
do
 Mixer.Set('Effects',0);local created0=#R.created;local n=#greetingPlays()
 server('Open',{VoidPacks=0,Delivered=0});seconds(1)
 check(#greetingPlays()==n and mouthOf()==nil and body.Size.X==22,'Effects volume 0: no greeting, no mouth, no swelling');closeWindow();Mixer.Set('Effects',100)
end

-- 4. The window's portrait: her 3D model, talking ----------------------------------------------------------------------------------------------
settleDown()
local view=panel.Portrait.Model
check(view:IsA('ViewportFrame')and view:FindFirstChild('VerityPortrait')==nil and #view:GetChildren()==1,'the window is closed: the ViewportFrame holds only its camera (no model is kept, nothing is drawn)')
do
 local created0=#R.created;frames(200);check(#R.created==created0,'(closed window: no instance is created in 200 frames)')
 trackWrites=true;writes={};frames(60);trackWrites=false
 local portraitWrites=0;for k,n in pairs(writes)do if k:find('^VerityPortrait')or k:find('^Portrait')then portraitWrites+=n end end
 check(portraitWrites==0,'(and the portrait is not written to while the window is closed)')
end
server('Open',{VoidPacks=0,Delivered=0});frames(2)
local pm=view:FindFirstChild('VerityPortrait');local pball=pm and pm:FindFirstChild('Body')
check(panel.Visible and pm and pball and pball:FindFirstChildOfClass('Decal')~=nil,'the window opens: her 3D model is built into the viewport (a ball with the smiley Decal)')
local function pmouth()return pm and pm:FindFirstChild('VerityPortraitMouth')end
local function popen(m)return m and m.Size.Y/pball.Size.X/C.Mouth.Height or 0 end
samples={};local pt0=R.clock
for _=1,150 do
 frames(1);local s=lastPlay().Sound
 samples[#samples+1]={T=s.TimePosition,Playing=s.IsPlaying,Open=popen(pmouth()),WorldOpen=openness(mouthOf()),Y=pball.CFrame.Position.Y,Scale=pball.Size.X/C.Portrait.Size}
end
check(peak(windowOf(samples,1.15,1.50),'Open')>.85 and peak(windowOf(samples,.05,.25),'Open')>.5,'the portrait mouth opens on the loud syllables just like the world one')
check(last(windowOf(samples,.62,.80),'Open')<.15 and last(windowOf(samples,1.00,1.15),'Open')<.15,'and closes in the pauses')
do
 local worst=0;for _,sm in ipairs(samples)do if sm.Playing then worst=math.max(worst,math.abs(sm.Open-sm.WorldOpen))end end
 check(worst<1e-6,string.format('the same lip sync as in the world: the two mouths are open by the same share every frame (worst difference %.1e)',worst))
end
do
 local lo,hi=1e9,-1e9;for _,sm in ipairs(samples)do lo=math.min(lo,sm.Y);hi=math.max(hi,sm.Y)end
 check(hi>lo,string.format('the portrait ball bobs while she talks (%.3f studs)',hi-lo))
 local biggest=0;for _,sm in ipairs(samples)do biggest=math.max(biggest,sm.Scale)end
 check(biggest>1+C.TalkPulse*.7 and biggest<=1+C.TalkPulse+1e-9,string.format('and swells with the voice (up to x%.3f)',biggest))
end
seconds(1)
check(pmouth()==nil or pmouth().Parent==nil,'the voice has ended: the portrait mouth has closed and gone')
check(pball.Size.X==C.Portrait.Size,'and the portrait ball is back to its size exactly')
-- Placement of the portrait mouth (while talking).
do
 closeWindow();server('Open',{VoidPacks=0,Delivered=0});seconds(.58)
 pm=view:FindFirstChild('VerityPortrait');pball=pm.Body;local m=pmouth()
 check(m and m:IsA('Part')and m.Anchored and not m.CanCollide and m:FindFirstChildOfClass('SpecialMesh')and m.Color==C.Mouth.Color,'(a fresh model each time the window opens) the portrait mouth is the same dark oval')
 local rel=pball.CFrame:Inverse()*m.CFrame.Position;local D=pball.Size.X;local y=D*C.Mouth.Y;local z=-math.sqrt((D/2)^2-y^2)
 check(near(rel.X,0,1e-6)and near(rel.Y,y,1e-6)and near(rel.Z,z,1e-6),'sitting on the front of the portrait ball (toward the camera)')
 local cam=view.CurrentCamera;local toCam=(cam.CFrame.Position-m.CFrame.Position).Unit
 check(toCam.Z<-.9,'on the side the camera looks from')
 seconds(2.2)
end
-- Close: the model goes, nothing per frame.
do
 server('Open',{VoidPacks=0,Delivered=0});seconds(.4);closeWindow()
 check(view:FindFirstChild('VerityPortrait')==nil and #view:GetChildren()==1,'closing the window destroys her portrait model (the viewport keeps only its camera)')
 seconds(2.5)
 check(pmouth()==nil,'no portrait mouth after closing (the world mouth still follows the voice, nothing else does)')
 local reads1=loudReads;frames(120);check(loudReads==reads1,'and once the voice has ended nothing reads the loudness')
end
-- SeedMenu taking over closes it the same way.
do
 settleDown();server('Open',{VoidPacks=0,Delivered=0});frames(2)
 check(view:FindFirstChild('VerityPortrait')~=nil,'(reopened: a new model)')
 pg:SetAttribute('SeedMenu','Index');frames(2)
 check(not panel.Visible and view:FindFirstChild('VerityPortrait')==nil,'another menu opening closes her window and drops the model');pg:SetAttribute('SeedMenu',nil)
 seconds(2.4)
end
-- Resizes while open do not leak models.
do
 settleDown();server('Open',{VoidPacks=0,Delivered=0})
 for _,sz in ipairs({{1280,720},{1024,768},{844,390},{1920,1080},{1280,720}})do screen=R.Vector2.new(sz[1],sz[2]);frames(3)
  local models=0;for _,c in ipairs(view:GetChildren())do if c.Name=='VerityPortrait'then models+=1 end end
  check(models==(panel.Portrait.Visible and 1 or 0),'resized to '..sz[1]..'x'..sz[2]..': '..models..' portrait model(s) for a '..(panel.Portrait.Visible and'shown'or'hidden')..' portrait')
 end
 -- A phone-sized window hides the portrait: no model, no work for it.
 screen=R.Vector2.new(390,844);frames(4);check(not panel.Portrait.Visible and view:FindFirstChild('VerityPortrait')==nil,'a phone-sized window has no portrait and no model')
 seconds(.6)
 closeWindow();screen=R.Vector2.new(1280,720);frames(3);seconds(2.2)
end
-- Far away with the window open: the portrait still talks (it is on screen), her body in the world is left alone.
do
 settleDown();aim(0,16.45,bodyAt.Z+C.AnimateDistance+60);frames(5)
 server('Open',{VoidPacks=0,Delivered=0});trackWrites=true;writes={};seconds(.6)
 trackWrites=false
 local bodyWrites=0;for k,n in pairs(writes)do if k:find('^Body%.')and not k:find('^Body%.CFrame')then bodyWrites+=n end end
 local pm2=view:FindFirstChild('VerityPortrait')
 check(pm2 and pm2:FindFirstChild('VerityPortraitMouth')~=nil and popen(pm2:FindFirstChild('VerityPortraitMouth'))>0,'camera 360 studs away, window open: the portrait mouth moves')
 check(mouthOf()==nil and body.Size.X==22,'while the world mouth is not made and her body is not swelled')
 seconds(2.2);closeWindow();aim(0,20,-300);frames(5)
end
-- ReducedMotion with the window open: the portrait is still (rest pose, no bob, no mouth), the voice is not cut short.
do
 W.Gui.ReducedMotionEnabled=true;frames(3);settleDown()
 server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay()
 local pm3=view:FindFirstChild('VerityPortrait');local b3=pm3.Body;local still=true;local mouthSeen=false
 for _=1,150 do frames(1);if b3.CFrame.Position.Magnitude>1e-9 or b3.Size.X~=C.Portrait.Size then still=false end;if pm3:FindFirstChild('VerityPortraitMouth')and pm3.VerityPortraitMouth.Parent==pm3 then mouthSeen=true end end
 check(still and not mouthSeen,'ReducedMotion: the portrait stays at rest (no bob, no swell, no mouth)')
 check(p.Enabled and not p.Sound.IsPlaying,'and her voice still plays and ends')
 closeWindow();W.Gui.ReducedMotionEnabled=false;frames(3)
end
-- Teardown: the window and the model go, nothing runs afterwards.
do
 settleDown();server('Open',{VoidPacks=0,Delivered=0});frames(2)
 check(view:FindFirstChild('VerityPortrait')~=nil,'(window open)')
 gui:Destroy();frames(3)
 check(view:FindFirstChild('VerityPortrait')==nil,'the script is torn down: the portrait model is destroyed')
 local ok=pcall(function()aim(50,20,-100);frames(10);remote.OnClientEvent:Fire('Greet',{Start=0,End=1})end)
 check(ok and mouthOf()==nil,'nothing runs (or errors) after it is torn down')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
