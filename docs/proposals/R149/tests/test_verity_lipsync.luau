--!nocheck
-- R149 (owner: "sync verity's voice and cut the audio to only hello my name verity and also change the picture of verity to its 3d model
-- talking and remove the event ends thing"): the real VerityClient on the Roblox mock, with a Sound that behaves like the engine's
-- (it plays from TimePosition, stops at the end of its PlaybackRegion and fires Ended, reports a PlaybackLoudness that follows a scripted
-- "Hello, my name is Verity" and then, past the cut, the rest of the clip), and the real VerityVoice / VerityConfig / ItemPictures / AudioMixer.
--  1. The cut: EVERY greeting (Talk, coming close, the owner's /test verityvoice message, a live override on her model, a changed config)
--     sets PlaybackRegionsEnabled and PlaybackRegion = (Start, Stop) BEFORE it plays, starts at Start, never runs past Stop (the rest of the
--     clip is never heard), fades the volume over the last GreetingFade seconds and restores it for the next one; a region the engine
--     refuses is warned about once and replaced by a timer cut; a clip that has not loaded yet is waited for (not cut by an early clock).
--  2. The voice level in the world (R151: the mouth oval is gone, the ball BOUNCES): she hops (TalkBounce of her size) and swells (TalkPulse) with
--     the Sound's PlaybackLoudness (smoothed: fast rise, slower fall), high on loud syllables and back down in pauses, stays on her dais while she
--     turns, and is exactly at rest when the sound stops or is cut; a talking rhythm runs for the length of the cut if no loudness is ever reported.
--     The cut is GreetingEnd 2.35 now (it stopped at "Ver" at 1.9): the scripted clip has the syllables of "Verity" up to 2.34 s and speech after.
--  3. Nothing is done for nothing: idle = no loudness reads, no new instances, no writes; beyond AnimateDistance, with ReducedMotion or
--     with the Effects volume at 0 she does not move (her sound still plays, fades and ends). No instance but the Sound is ever created.
--  4. The window's portrait (a ViewportFrame with her 3D model) bounces and swells the same way, while the dialog is open only, and is torn down on close.
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
-- that follows the scripted clip: "Hello, my name is Ver-i-ty" up to 2.34 s (syllable bursts with pauses between: "Ver" ends at 1.90, where R150's cut
-- stopped; "i" and "ty" follow), then more speech past the cut (R151: GreetingEnd 2.35).
local SEGMENTS={{.05,.25,420},{.40,.62,520},{.80,1.00,380},{1.15,1.50,600},{1.60,1.72,300},{1.78,1.90,480},{2.00,2.15,500},{2.22,2.34,420},{2.40,3.10,550}}
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
local function mouthOf()return model:FindFirstChild('VerityMouth',true)end -- R151: there is no mouth any more: this is nil at every moment
-- Her bounce this frame, 0..1: how far her centre stands above where her rest height + bob + the swell (her bottom stays on the dais) put it, as a share of
-- the full hop TalkBounce * 22 studs. Her swell, 0..1: how far she has grown, as a share of the full TalkPulse. Both come from the one voice level.
local function bobAt()return math.sin(R.clock*1.4)*C.FootOffset end
local function hopOf()return(body.CFrame.Position.Y-bodyAt.Y-bobAt()-(body.Size.X-22)/2)/(22*C.TalkBounce)end
local function swellOf()return(body.Size.X-22)/(22*C.TalkPulse)end
local function fullRun(trigger,maxSeconds) -- run a greeting to its end, sampling every frame
 local samples={};local t0=R.clock;trigger()
 for _=1,math.floor((maxSeconds or 3)*60)do
  frames(1)
  local s=lastPlay()and lastPlay().Sound
  samples[#samples+1]={T=s and s.TimePosition or 0,Loud=s and s._props.PlaybackLoudness or 0,Hop=hopOf(),Swell=swellOf(),Size=body.Size.X,Volume=s and s.Volume or 0,Playing=s and s.IsPlaying,Mouth=mouthOf()~=nil,
   X=body.CFrame.Position.X,Z=body.CFrame.Position.Z}
 end
 return samples,t0
end

-- 1. The cut: every way she speaks sets the region before playing -------------------------------------------------------------------------
check(C.GreetingStart==0 and C.GreetingEnd==2.35 and C.GreetingFade==.08,'VerityConfig: GreetingStart 0, GreetingEnd 2.35 (R151: the 1.9 cut stopped at "Ver"; still to be tuned in Studio), GreetingFade .08')
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
local run=(function()local out={};for _=1,190 do frames(1);out[#out+1]={T=sound.TimePosition,Loud=sound._props.PlaybackLoudness,Playing=sound.IsPlaying,Volume=sound.Volume,At=R.clock}end;return out end)()
local heard=0;local lastEnd=ends[#ends]
check(not sound.IsPlaying and lastEnd and lastEnd.Sound==sound and near(lastEnd.At-p1.At,C.GreetingEnd-C.GreetingStart,.12),string.format('it stops %.2f s after it started (the cut is %.2f s long, the clip 3.2 s)',lastEnd and lastEnd.At-p1.At or -1,C.GreetingEnd-C.GreetingStart))
local pastCut=false;for _,r in ipairs(run)do if r.Playing and r.T>C.GreetingEnd+.02 then pastCut=true end end
check(not pastCut,'no frame of the audio past the end of the cut is ever played (the rest of the clip after "Verity" is not heard)')
do -- R151: what the 1.9 s cut lost: "i" and "ty" (2.00 .. 2.34 s) are played now, and only the speech after them is cut
 local playedPast19,loudPast19=false,0;for _,r in ipairs(run)do if r.Playing and r.T>1.95 and r.T<C.GreetingEnd then playedPast19=true;loudPast19=math.max(loudPast19,r.Loud)end end
 check(playedPast19 and loudPast19>=420,'R151: the audio between 1.9 s and the new end (the "i" and "ty" of "Verity", loudness '..loudPast19..') is played now')
end
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
seconds(2.7);closeWindow()
-- Coming close greets with the same cut.
standAt(0,7,-150);frames(60);R.advance(70);local n0=#greetingPlays()
standAt(0,7,-315);frames(40)
local p3=lastPlay()
check(#greetingPlays()==n0+1 and p3.Enabled and p3.Min==C.GreetingStart and p3.Max==C.GreetingEnd,'coming within range: the proximity greeting is cut the same way ('..tostring(p3.Min)..' .. '..tostring(p3.Max)..')')
seconds(2.7);standAt(0,7,-150);frames(30)
-- A changed config is picked up by the next greeting.
do
 local s0,e0=C.GreetingStart,C.GreetingEnd
 C.GreetingStart=.4;C.GreetingEnd=1.2
 R.advance(70);local n=#greetingPlays();standAt(0,7,-315);frames(40);local p=lastPlay()
 check(#greetingPlays()==n+1 and p.Min==.4 and p.Max==1.2 and p.TimePosition==.4,'a new GreetingStart / GreetingEnd in VerityConfig is used by the next greeting (.4 .. 1.2)')
 seconds(1.2)
 check(near(ends[#ends].At-p.At,.8,.1),'and it is .8 s long ('..string.format('%.2f',ends[#ends].At-p.At)..')')
 C.GreetingStart=s0;C.GreetingEnd=e0;standAt(0,7,-150);frames(30)
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
 seconds(2.6);standAt(0,7,-150);frames(30)
 model:SetAttribute('VerityVoiceStart',nil);model:SetAttribute('VerityVoiceEnd',nil)
 model:SetAttribute('VerityVoiceStart',.5) -- a half pair is not an override
 closeWindow();server('Open',{VoidPacks=0,Delivered=0})
 check(lastPlay().Min==C.GreetingStart and lastPlay().Max==C.GreetingEnd,'one number alone is ignored: back to the config')
 seconds(2.7);closeWindow();model:SetAttribute('VerityVoiceStart',nil)
 model:SetAttribute('VerityVoiceStart',0/0);model:SetAttribute('VerityVoiceEnd',1/0);server('Open',{VoidPacks=0,Delivered=0})
 check(lastPlay().Min==C.GreetingStart and lastPlay().Max==C.GreetingEnd,'NaN / infinity in the attributes are ignored too')
 seconds(2.7);closeWindow();model:SetAttribute('VerityVoiceStart',nil);model:SetAttribute('VerityVoiceEnd',nil)
end
-- The cut never runs past the clip once its length is known.
do
 local s=lastPlay().Sound;s.TimeLength=1.5
 server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay()
 check(p.Max==1.5 and p.Min==0,'a clip only 1.5 s long: the region ends at 1.5, not at '..C.GreetingEnd)
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
 seconds(2.7)
 local ok=pcall(function()remote.OnClientEvent:Fire('Greet',nil);remote.OnClientEvent:Fire('Greet',5);remote.OnClientEvent:Fire('Greet',{});frames(2)end)
 check(ok,'nil / non-table / empty Greet payloads are handled')
 seconds(2.7)
 Mixer.Set('Effects',0);local n3=#greetingPlays();server('Greet',{Start=0,End=C.GreetingEnd})
 check(#greetingPlays()==n3,'Effects volume 0: no voice for a Greet either');Mixer.Set('Effects',100)
 -- Back to a normal greeting afterwards: from her body again.
 standAt(0,7,-150);aim(0,20,-300);frames(5);closeWindow();server('Open',{VoidPacks=0,Delivered=0})
 check(lastPlay().Sound.Parent==body and lastPlay().Max==C.GreetingEnd,'a Talk after the test is a normal 3D greeting from her body again')
 seconds(2.7);closeWindow()
end
-- The engine refuses the region (a property a game script cannot set): warned once, and a timer cuts the clip instead.
do
 regionRefused=true;local warns0=W.warns or 0
 lastPlay().Sound:Destroy() -- (a fresh Sound: an old one would keep the region of its last playing)
 closeWindow();server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay()
 check(not p.Enabled or p.Min==nil,'(this Sound has no PlaybackRegion at all: the engine refused it)')
 seconds(3.2)
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
 local t0=lastPlay().At;seconds(2.9)
 check(near(ends[#ends].At-t0,C.GreetingEnd-C.GreetingStart,.12),'and the cut is timed from when the audio really started ('..string.format('%.2f',ends[#ends].At-t0)..' s)')
 closeWindow();s.IsLoaded=false;s.TimeLength=0;local n2=#greetingPlays();server('Open',{VoidPacks=0,Delivered=0});seconds(3.4)
 check(#greetingPlays()==n2,'a clip that never loads: nothing plays, nothing errors')
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n2,'(and a late load after the 3 s wait does not play a greeting nobody asked for now)')
 server('Open',{VoidPacks=0,Delivered=0})
 check(#greetingPlays()==n2+1,'a later Talk is not blocked by the earlier wait: it plays')
 seconds(2.7);closeWindow()
 -- IsLoaded can lag behind the length: a Sound that already knows its length (TimeLength > 0) is loaded.
 s.IsLoaded=false;local n3=#greetingPlays();server('Open',{VoidPacks=0,Delivered=0})
 check(#greetingPlays()==n3+1,'a Sound whose IsLoaded still reads false but whose TimeLength is known plays at once')
 seconds(2.7);closeWindow();s.IsLoaded=true
end
-- R150: a greeting is skipped, never spoken late. The wait for a clip that has not loaded is bounded by .5 s (it was 3 s), counted from when she
-- was ASKED to speak, and a 'talk' greeting also needs her window to still be open when the clip arrives.
do
 settleDown()
 local s=lastPlay().Sound;local n=#greetingPlays()
 s.IsLoaded=false;s.TimeLength=0;server('Open',{VoidPacks=0,Delivered=0});seconds(.4)
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n+1,'R150: a clip that loads .4 s after she was asked plays')
 seconds(2.7);closeWindow()
 n=#greetingPlays();s.IsLoaded=false;s.TimeLength=0;server('Open',{VoidPacks=0,Delivered=0});seconds(.7)
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n,'R150: a clip that arrives .7 s after she was asked is skipped, not spoken late')
 closeWindow();seconds(1)
 n=#greetingPlays();s.IsLoaded=false;s.TimeLength=0;server('Open',{VoidPacks=0,Delivered=0});seconds(.2);closeWindow()
 s.IsLoaded=true;s.TimeLength=3.2;s.Loaded:Fire();frames(2)
 check(#greetingPlays()==n,'R150: a Talk greeting whose window was closed before the clip loaded is skipped')
 settleDown()
end

-- 2. The voice level in the world: she swells and BOUNCES (R151: no mouth) ----------------------------------------------------------------------------
settleDown()
check(mouthOf()==nil,'no mouth while she is not talking')
local created0=#R.created
local modelParts0=0;for _ in ipairs(model:GetDescendants())do modelParts0+=1 end
local samples,t0=fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.9)
do
 local made={};for i=created0+1,#R.created do local c=R.created[i]._class;if c~='Sound'and c~='Model'and c~='Part'and c~='Decal'then made[#made+1]=c end end
 local inModel=0;for _ in ipairs(model:GetDescendants())do inModel+=1 end
 check(#made==0 and inModel==modelParts0,'a whole greeting creates nothing but its Sound and the window\'s portrait (a Model, its ball and the smiley Decal): no mouth part, no SpecialMesh, nothing added to her model ('..table.concat(made,',')..'; '..inModel..' parts in her model, '..modelParts0..' before)')
 local mouthEver=false;for _,sm in ipairs(samples)do if sm.Mouth then mouthEver=true end end
 check(not mouthEver and W.CS:GetTagged('VerityMouth')[1]==nil and mouthOf()==nil and model:FindFirstChild('VerityMouth')==nil,'R151: the mouth oval is gone: no VerityMouth part exists at any frame of a greeting')
 check(W.B.VerityClient:find('VerityMouth',1,true)==nil and W.B.VerityClient:find('MouthPose',1,true)==nil and W.B.VerityClient:find('C.Mouth',1,true)==nil,'and the client has no mouth code left')
end
local hopSeen;for _,sm in ipairs(samples)do if sm.Hop>.1 then hopSeen=true end end
check(hopSeen,'she bounces while she talks')
local function windowOf(list,a,b)local out={};for _,sm in ipairs(list)do if sm.T>=a and sm.T<b then out[#out+1]=sm end end;return out end
local function peak(list,key)local v=0;for _,sm in ipairs(list)do v=math.max(v,sm[key])end;return v end
local function last(list,key)return list[#list]and list[#list][key]or 0 end
-- Loudness drives it: high on loud syllables, down in pauses, and the swell follows the same level.
local loudSyl=windowOf(samples,1.15,1.50);local quietSyl=windowOf(samples,1.60,1.72);local gap1=windowOf(samples,.62,.80);local gap2=windowOf(samples,1.00,1.15)
check(peak(loudSyl,'Hop')>.85,string.format('a loud syllable ("name", loudness 600) bounces her to %.2f of the full hop',peak(loudSyl,'Hop')))
check(peak(quietSyl,'Hop')<peak(loudSyl,'Hop')-.1 and peak(quietSyl,'Hop')>.2,string.format('a quieter one ("is", 300) hops less (%.2f)',peak(quietSyl,'Hop')))
check(last(gap1,'Hop')<.15 and last(gap2,'Hop')<.15,string.format('in the pauses she is back down (%.2f and %.2f of the hop at the end of the two gaps)',last(gap1,'Hop'),last(gap2,'Hop')))
check(peak(windowOf(samples,.05,.25),'Hop')>.5,'the first syllable ("Hel", loudness 420) bounces her as well')
check(peak(windowOf(samples,2.00,2.20),'Hop')>.5 and peak(windowOf(samples,2.22,2.36),'Hop')>.4,'R151: the syllables after 1.9 s ("i", "ty": what the old cut lost) bounce her too')
do
 local worst=0;for _,sm in ipairs(samples)do worst=math.max(worst,math.abs(sm.Hop-sm.Swell))end
 check(worst<2e-3,string.format('the bounce and the swell are the one voice level: the same share of their own maximum every frame (worst difference %.1e: her slow bob is only rewritten past 1e-3 studs)',worst))
 local top=0;for _,sm in ipairs(samples)do top=math.max(top,sm.Hop)end
 check(top<=1+1e-9 and top>.9,string.format('and the hop never goes past TalkBounce of her size (%.2f studs at most, %.2f seen)',22*C.TalkBounce,top*22*C.TalkBounce))
end
-- Fast up, slower down.
do
 local function framesTo(list,from,pred)local n=0;for _,sm in ipairs(list)do if sm.T>=from then n+=1;if pred(sm)then return n end end end;return math.huge end
 local rising=framesTo(samples,1.15,function(sm)return sm.Hop>.6 end)
 local falling=framesTo(samples,1.50,function(sm)return sm.Hop<.4 end)
 check(rising<falling,string.format('she rises faster than she falls (%d frames to pass .6 at the start of "name", %d to fall below .4 after it)',rising,falling))
end
do
 local loudest=0;for _,sm in ipairs(samples)do if sm.T>=.05 and sm.T<C.GreetingEnd then loudest=math.max(loudest,sm.Size)end end
 check(loudest>22*(1+C.TalkPulse*.7)and loudest<=22*(1+C.TalkPulse)+1e-6,string.format('she swells with the same level: up to %.2f of her 22 studs on the loud syllables',loudest))
 local quietSize=peak(windowOf(samples,.66,.80),'Size')
 check(quietSize<loudest-.1,string.format('and is smaller in a pause (%.2f)',quietSize))
end
-- She stays on her dais: the bounce is vertical only, whatever the camera does.
do
 local worst=0;for _,sm in ipairs(samples)do worst=math.max(worst,math.abs(sm.X-bodyAt.X)+math.abs(sm.Z-bodyAt.Z))end
 check(worst<1e-6,string.format('the bounce is vertical: her x / z never move off the dais (worst %.1e studs)',worst))
end
-- It stops cleanly when the cut ends: nothing of the rest of the clip is heard, so she settles and is back to 22 studs exactly, at her rest height.
do
 seconds(.6)
 check(body.Size.X==22 and body.Size.Y==22,'after the cut she is exactly 22 studs again')
 check(math.abs(hopOf())<2e-3 and math.abs(swellOf())<1e-9,'and exactly at rest height (no hop left; only her slow bob)')
 local loudAfter=0;for _,sm in ipairs(samples)do if sm.T>C.GreetingEnd+.02 then loudAfter=math.max(loudAfter,sm.Loud)end end
 check(loudAfter==0,'no loudness from past the cut was ever heard (she cannot bounce to words that are not played)')
end
-- Turning to the camera does not disturb it.
do
 settleDown();server('Open',{VoidPacks=0,Delivered=0});seconds(.55)
 local worst,yaws={},0
 for _,cam in ipairs({{100,20,-340},{-100,20,-340},{0,20,-440},{0,20,-300}})do
  aim(cam[1],cam[2],cam[3]);for _=1,8 do frames(1)
   worst[#worst+1]=math.abs(body.CFrame.Position.X-bodyAt.X)+math.abs(body.CFrame.Position.Z-bodyAt.Z)
  end
 end
 local w=0;for _,v in ipairs(worst)do w=math.max(w,v)end
 check(w<1e-6,string.format('she turns to the camera from every side while bouncing and stays on her dais (worst offset %.1e studs)',w))
 seconds(2.7);aim(0,20,-300);frames(5)
end
-- A sound stopped from outside (another greeting, the engine): she settles, nothing is left running.
do
 settleDown();server('Open',{VoidPacks=0,Delivered=0});seconds(.55)
 check(body.Size.X>22 or hopOf()>.01,'(talking: she is up)')
 lastPlay().Sound:Stop();seconds(.9)
 check(body.Size.X==22 and math.abs(hopOf())<2e-3,'the sound is stopped under her: she settles and is back to her size and height')
 local before=loudReads;seconds(.5);check(loudReads==before,'and nothing reads the loudness any more')
 closeWindow()
end
-- No loudness reported (the engine cannot measure it): a talking rhythm for the length of the cut, then nothing.
do
 loudMode='silent';settleDown()
 samples=fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.9)
 local firstUp,ups,wasUp=nil,0,false;local maxHop=0
 for _,sm in ipairs(samples)do
  local o=sm.Hop>.3;if o and not wasUp then ups+=1 end;wasUp=o
  if o and not firstUp then firstUp=sm.T end
  maxHop=math.max(maxHop,sm.Hop)
 end
 check(firstUp and firstUp>.2 and firstUp<.7,string.format('no loudness: she starts the rhythm after a moment (first bounce at %.2f s of the clip)',firstUp or -1))
 check(ups>=4 and maxHop>.6,string.format('and bounces in syllables for the cut: %d bounces, as high as %.2f of the hop',ups,maxHop))
 local pastEnd=0;for _,sm in ipairs(samples)do if not sm.Playing and sm.T>C.GreetingEnd+.1 and sm.Hop>.2 then pastEnd+=1 end end
 seconds(.6)
 check(pastEnd==0 and body.Size.X==22 and math.abs(hopOf())<2e-3,'the rhythm stops with the cut: back to 22 studs at rest height')
 loudMode='missing';settleDown()
 local okMissing=pcall(function()fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.9)end)
 check(okMissing,'a Sound without a PlaybackLoudness at all does not break anything (the rhythm runs)')
 loudMode='speech';settleDown()
 -- Once real loudness has been heard, silence means a pause (she settles), not "no loudness": no rhythm runs through the pauses.
 samples=fullRun(function()server('Open',{VoidPacks=0,Delivered=0})end,2.9)
 -- (R153: the hop trails the voice level by a frame or so, a smoothing that takes the buzz out of it; the window starts 20 ms later for that)
 local g=windowOf(samples,.68,.78);check(last(g,'Hop')<.15 and peak(windowOf(samples,.68,.78),'Hop')<.5,'with real loudness, a pause stays down (no rhythm is mixed in)')
 seconds(.8)
end

-- 3. Nothing is done for nothing -----------------------------------------------------------------------------------------------------------
settleDown();seconds(1)
do
 local reads0,created0=loudReads,#R.created;local steps0=stepCalls
 frames(300)
 check(loudReads==reads0 and stepCalls==steps0,'idle (not talking): 300 frames read the loudness 0 times and run the voice level 0 times')
 check(#R.created==created0,'idle: 300 frames create no instance ('..(#R.created-created0)..')')
 trackWrites=true;writes={};frames(120);trackWrites=false
 local extra,bodySize={},0
 for k,n in pairs(writes)do
  if k=='Body.Size'then bodySize+=n
  elseif not(k:find('^Body%.'))and not k:find('^Mark%.')and not k:find('^Timer%.')then extra[#extra+1]=k..' x'..n end -- (the sign's once-a-second marker recount is older and not about her voice)
 end
 check(#extra==0 and bodySize==0,'idle: her bob is the only thing written (never her Size, no portrait, no sound): '..table.concat(extra,', '))
end
-- Beyond AnimateDistance: the sound plays (and fades and ends) but nothing is read, no instance is made, her body is left alone.
do
 aim(0,16.45,bodyAt.Z+C.AnimateDistance+40);frames(5);local reads0,created0=loudReads,#R.created
 local function newNonSounds(from)local out={};for i=from+1,#R.created do if R.created[i]._class~='Sound'then out[#out+1]=R.created[i]._class end end;return out end
 trackWrites=true;writes={}
 server('Greet',{Start=0,End=C.GreetingEnd});local p=lastPlay();seconds(2.9)
 trackWrites=false
 local bodyWrites=0;for k,n in pairs(writes)do if k:find('^Body%.')then bodyWrites+=n end end
 check(p.Enabled and p.Max==C.GreetingEnd and not p.Sound.IsPlaying and near(ends[#ends].At-p.At,C.GreetingEnd,.12),'the camera 340 studs away: her greeting still plays and ends at the cut')
 check(loudReads==reads0 and #newNonSounds(created0)==0 and mouthOf()==nil,'but the loudness is not read (0 reads) and nothing but the Sound itself is created ('..table.concat(newNonSounds(created0),',')..')')
 check(bodyWrites==0 and body.Size.X==22,'and her body is not written to ('..bodyWrites..' writes)')
 local volumeBack=near(p.Sound.Volume,C.GreetingVolume,1e-9);check(volumeBack,'(the fade ran and the volume is restored: it is audio, not animation)')
 aim(0,20,-300);frames(5)
end
-- ReducedMotion: the voice (cut, fade) plays, but she does not bounce or swell.
do
 W.Gui.ReducedMotionEnabled=true;frames(3);local reads0,created0=loudReads,#R.created
 closeWindow();server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay();local biggest=0
 for _=1,190 do frames(1);biggest=math.max(biggest,body.Size.X)end
 check(p.Enabled and p.Max==C.GreetingEnd and not p.Sound.IsPlaying,'ReducedMotion: the voice plays and is cut as always')
 check(mouthOf()==nil and biggest==22 and body.CFrame.Position.Y==bodyAt.Y,'but she does not swell or bounce (largest size '..biggest..', left exactly at home)')
 check(loudReads==reads0,'and the loudness is not read ('..(loudReads-reads0)..' reads)')
 check(near(p.Sound.Volume,C.GreetingVolume,1e-9),'(volume restored after the fade)')
 closeWindow();W.Gui.ReducedMotionEnabled=false;frames(3)
end
-- Effects at 0: no voice at all, so no movement.
do
 Mixer.Set('Effects',0);local created0=#R.created;local n=#greetingPlays()
 server('Open',{VoidPacks=0,Delivered=0});seconds(1)
 check(#greetingPlays()==n and mouthOf()==nil and body.Size.X==22 and math.abs(hopOf())<2e-3,'Effects volume 0: no greeting, no bounce, no swelling');closeWindow();Mixer.Set('Effects',100)
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
local function pmouth()return view:FindFirstChild('VerityPortraitMouth',true)end -- R151: there is none, at any moment
-- The portrait's bounce and swell (0..1), the same way the world's are measured: her centre above rest height + bob + half the growth, as a share of the full hop.
local function pbobAt()return math.sin(R.clock*1.4)*C.Portrait.Bob*C.Portrait.Size end
local function phop()return(pball.CFrame.Position.Y-pbobAt()-(pball.Size.X-C.Portrait.Size)/2)/(C.Portrait.Size*C.TalkBounce)end
local function pswell()return(pball.Size.X-C.Portrait.Size)/(C.Portrait.Size*C.TalkPulse)end
samples={};local pt0=R.clock
for _=1,190 do
 frames(1);local s=lastPlay().Sound
 samples[#samples+1]={T=s.TimePosition,Playing=s.IsPlaying,Hop=phop(),Swell=pswell(),WorldHop=hopOf(),Y=pball.CFrame.Position.Y,Scale=pball.Size.X/C.Portrait.Size,Mouth=pmouth()~=nil}
end
check(peak(windowOf(samples,1.15,1.50),'Hop')>.85 and peak(windowOf(samples,.05,.25),'Hop')>.5,'the portrait ball bounces on the loud syllables just like the world one')
check(last(windowOf(samples,.62,.80),'Hop')<.15 and last(windowOf(samples,1.00,1.15),'Hop')<.15,'and is back down in the pauses')
check(peak(windowOf(samples,2.00,2.20),'Hop')>.5,'R151: and on the syllables after 1.9 s ("i", "ty") that the old cut lost')
do
 local worst=0;for _,sm in ipairs(samples)do if sm.Playing then worst=math.max(worst,math.abs(sm.Hop-sm.WorldHop))end end
 check(worst<2e-3,string.format('the same voice level as in the world: the two balls hop by the same share every frame (worst difference %.1e)',worst))
 local worstSwell=0;for _,sm in ipairs(samples)do worstSwell=math.max(worstSwell,math.abs(sm.Hop-sm.Swell))end
 check(worstSwell<1e-6,string.format('and bounce and swell are the one level here too (worst difference %.1e)',worstSwell))
 local mouthEver=false;for _,sm in ipairs(samples)do if sm.Mouth then mouthEver=true end end
 check(not mouthEver and pmouth()==nil,'R151: no mouth in the portrait either, at any frame')
end
do
 local lo,hi=1e9,-1e9;for _,sm in ipairs(samples)do lo=math.min(lo,sm.Y);hi=math.max(hi,sm.Y)end
 check(hi>lo,string.format('the portrait ball bobs and bounces while she talks (%.3f studs)',hi-lo))
 local biggest=0;for _,sm in ipairs(samples)do biggest=math.max(biggest,sm.Scale)end
 check(biggest>1+C.TalkPulse*.7 and biggest<=1+C.TalkPulse+1e-9,string.format('and swells with the voice (up to x%.3f)',biggest))
 -- the viewport holds the loudest moment: the ball's top stays below the top of the picture
 local cam=view.CurrentCamera;local half=math.tan(math.rad(C.Portrait.Fov)/2)*(cam.CFrame.Position-V3(0,0,0)).Magnitude
 local topMax=0;for _,sm in ipairs(samples)do topMax=math.max(topMax,sm.Y+sm.Scale*C.Portrait.Size/2-(sm.Scale-1)*C.Portrait.Size/2*0)end
 check(topMax<=half+1e-9,string.format('the loudest bounce stays inside the viewport (the ball\'s top reaches %.2f of %.2f studs)',topMax,half))
end
seconds(1)
check(pmouth()==nil,'the voice has ended: no portrait mouth')
check(pball.Size.X==C.Portrait.Size and math.abs(phop())<1e-9,'and the portrait ball is back to its size and rest height exactly')
-- A fresh model each time the window opens, at rest, with no mouth.
do
 closeWindow();server('Open',{VoidPacks=0,Delivered=0});seconds(.58)
 pm=view:FindFirstChild('VerityPortrait');pball=pm.Body
 check(pm and pball and pball.Shape==R.Enum.PartType.Ball and pball:FindFirstChildOfClass('Decal')~=nil and pmouth()==nil and #pm:GetChildren()==1,'(a fresh model each time the window opens) just the ball with the smiley: no other part in the model')
 seconds(2.9)
end
-- Close: the model goes, nothing per frame.
do
 server('Open',{VoidPacks=0,Delivered=0});seconds(.4);closeWindow()
 check(view:FindFirstChild('VerityPortrait')==nil and #view:GetChildren()==1,'closing the window destroys her portrait model (the viewport keeps only its camera)')
 seconds(2.5)
 check(pmouth()==nil,'no portrait mouth after closing (her body in the world still follows the voice, nothing else does)')
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
 closeWindow();screen=R.Vector2.new(1280,720);frames(3);seconds(2.7)
end
-- Far away with the window open: the portrait still talks (it is on screen), her body in the world is left alone.
do
 settleDown();aim(0,16.45,bodyAt.Z+C.AnimateDistance+60);frames(5)
 server('Open',{VoidPacks=0,Delivered=0});trackWrites=true;writes={};seconds(.6)
 trackWrites=false
 local bodyWrites=0;for k,n in pairs(writes)do if k:find('^Body%.')and not k:find('^Body%.CFrame')then bodyWrites+=n end end
 local pm2=view:FindFirstChild('VerityPortrait')
 local hop2=0;for _=1,40 do frames(1);if pm2 and pm2:FindFirstChild('Body')then local pb=pm2.Body;hop2=math.max(hop2,(pb.CFrame.Position.Y-pbobAt()-(pb.Size.X-C.Portrait.Size)/2)/(C.Portrait.Size*C.TalkBounce))end end
 check(pm2 and hop2>.1,'camera 360 studs away, window open: the portrait ball still bounces')
 check(body.Size.X==22 and body.CFrame.Position.Y==bodyAt.Y,'while her body in the world is not swelled or moved')
 seconds(2.7);closeWindow();aim(0,20,-300);frames(5)
end
-- ReducedMotion with the window open: the portrait is still (rest pose, no bob, no bounce), the voice is not cut short.
do
 W.Gui.ReducedMotionEnabled=true;frames(3);settleDown()
 server('Open',{VoidPacks=0,Delivered=0});local p=lastPlay()
 local pm3=view:FindFirstChild('VerityPortrait');local b3=pm3.Body;local still=true;local mouthSeen=false
 for _=1,190 do frames(1);if b3.CFrame.Position.Magnitude>1e-9 or b3.Size.X~=C.Portrait.Size then still=false end;if pm3:FindFirstChild('VerityPortraitMouth')then mouthSeen=true end end
 check(still and not mouthSeen,'ReducedMotion: the portrait stays at rest (no bob, no swell, no bounce)')
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
