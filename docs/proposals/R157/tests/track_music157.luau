-- R157 track music (owner: "at some points in the track the track music will be replaced with the base music, this happens when entering desert"). This file is the TAIL of the
-- scene: run_track_music157.sh runs it after lines 11 - 63 of R149's zfight_scene.luau (the Roblox mock, the OWNER'S PLACE loaded, the REAL start-up passes: MapService.new with
-- the route balance, TrackExpansion83, the pyramid, ... so the map attributes and the geometry are what the server really makes), with the REAL BackgroundMusic of the checkout
-- (or, for the proof, the R156 release's) loaded as the local player's client script, and one global in front: T157 = {Expect = 'fixed' | 'old', Target, Min, Enabled}
-- (the place's Workspace streaming settings, read from the .rbxl by place_streaming157.py).
--
-- What the owner's place says (printed as GEO lines): the track box BackgroundMusic tests (|X - line X| <= FieldWidth / 2 + 2, Z from the BaseBoundaryLine to BiomeTrackEndZ,
-- -20 < Y <= 300) holds every walkable point of every biome, the Desert and the pyramid included. The ONE thing in the test that is not on the map's attributes is
-- Lobby.BaseBoundaryLine, a plain Part: the place streams (StreamingEnabled, StreamingTargetRadius 1024), so on a client it is only there while the player is within
-- the streaming radius of it. The mock models exactly that (STREAMING below: the line is parented to the Lobby while the player is within the radius of its box, and not
-- otherwise; a Folder, the map's attributes and ReplicatedStorage are never streamed).
--
--  A. the numbers      the facts above, from the real map: line, attributes, floors, walls, the Desert's range, the pyramid
--  B. the others       BiomeMood.Stage / MapService:IsInsideBiomeTrack / WeatherWorld149.Area agree with the box over the whole track (and say "base" in the hub)
--  C. the sweeps       a player walks, at floor height, the centre line and both walls from the hub through every biome to the end of the track, and round and through the
--                      pyramid (the four faces, the chamber, up the steps to the top), once with everything streamed in and then with the line streamed out beyond 1024 / 600 /
--                      64 studs (the target radius of the place, a smaller one, and the engine's minimum): from 2 s after the entrance the track music is heard on EVERY frame
--                      and the base music is silent; in the hub the base music is heard and the track music is silent. Then the walk back to the hub.
--                      Expect = 'old' is the proof run against the R156 script: it must fail exactly where the line streams out.
--  D. the playlists    a long stand in the Desert (the line streamed out) while the track songs end and cross over every 40 s and the base songs rotate: on every frame the track
--                      music is heard in full (a crossfade never dips) and no base voice is audible
--  E. the stand-ins    with neither the line nor RunnerMotion's attributes the answer is "not on the track" (the base music), as before; with both the live line wins
local fails2,checks2=0,0
local function check(c,msg)checks2+=1;if not c then fails2+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(e or 1e-6)end
local EXPECT=(T157 and T157.Expect)or'fixed'
R.advance(1)
check(okMap and failed==0,'MapService.new ran on the owner\'s place ('..failed..' steps failed)')

-- ====================================================================================================================================================================
-- A. the numbers (the real map after the real start-up passes)
-- ====================================================================================================================================================================
local lobby=map:FindFirstChild('Lobby');local line=lobby and lobby:FindFirstChild('BaseBoundaryLine')
if not check(line~=nil,'Lobby.BaseBoundaryLine is in the map')then error('no line: the rest cannot be checked')end
local LZ,LX=line.Position.Z,line.Position.X
local FW=map:GetAttribute('FieldWidth');local ENDZ=map:GetAttribute('BiomeTrackEndZ')
local HALF=FW/2+2
local grounds={}
for _,d in ipairs(map:GetDescendants())do if d:IsA('BasePart')and d.Name:match('^BiomeGround_%d+$')then grounds[#grounds+1]=d end end
table.sort(grounds,function(a,b)return a.Position.Z<b.Position.Z end)
local FLOOR=grounds[1].Position.Y+grounds[1].Size.Y/2;local ROOT=FLOOR+3 -- an R15 root stands ~3 studs over the floor
local innerWall=math.huge;local walls=0
do local obby=map:FindFirstChild('Obby');local bw=obby and obby:FindFirstChild('BiomeWalls')
 for _,w in ipairs(bw and bw:GetChildren()or{})do if w:IsA('BasePart')and w.Size.X<w.Size.Z then walls+=1;innerWall=math.min(innerWall,math.abs(w.Position.X)-w.Size.X/2)end end end
local desert,stageOf={}, {}
for id=1,7 do stageOf[id]={Name=map:GetAttribute('BiomeName_'..id),A=map:GetAttribute('BiomeStartZ_'..id),B=map:GetAttribute('BiomeEndZ_'..id)} end
for id,s in pairs(stageOf)do if s.Name=='Desert'then desert={Id=id,A=s.A,B=s.B}end end
local motion=W.RS:FindFirstChild('RunnerMotion')
local model=(map:FindFirstChild('MythicLandmarks')or{FindFirstChild=function()end}):FindFirstChild('Biome2_Landmark')
local slab1=model and model:FindFirstChild('Slab01')
local PX,PZ=-62.0675,1005;local PHALF=22.4;local PTOP=FLOOR
local pyrLo,pyrHi
if model then for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then local t=p.Position.Y+p.Size.Y/2;if not pyrHi or t>pyrHi then pyrHi=t end end end end
local lastEnd=grounds[#grounds].Position.Z+grounds[#grounds].Size.Z/2
print(string.format('GEO the BaseBoundaryLine: Z %.3f, X %.3f, size %.2f x %.2f x %.2f',LZ,LX,line.Size.X,line.Size.Y,line.Size.Z))
print(string.format('GEO map attributes: FieldWidth %s, BiomeTrackStartZ %s, BiomeTrackEndZ %s (BackgroundMusic\'s own default: 1475), TrackLength %s',tostring(FW),tostring(map:GetAttribute('BiomeTrackStartZ')),tostring(ENDZ),tostring(map:GetAttribute('TrackLength'))))
print(string.format('GEO the box BackgroundMusic tests: |X - %.1f| <= %.1f, %.3f < Z <= %.1f, -20 < Y <= 300',LX,HALF,LZ,ENDZ))
for id=1,7 do local g=grounds[1];for _,x in ipairs(grounds)do if x.Name=='BiomeGround_'..id then g=x end end
 print(string.format('GEO stage %d %-11s Z %7.1f .. %7.1f (BiomeStartZ/EndZ attributes), BiomeGround top Y %.2f, length %.0f',id,tostring(stageOf[id].Name),stageOf[id].A,stageOf[id].B,g.Position.Y+g.Size.Y/2,g.Size.Z))end
print(string.format('GEO walls: %d side walls, inner face at |X| = %.2f (the box reaches |X| = %.1f); a standing root is at Y %.2f (the box: -20 < Y <= 300)',walls,innerWall,HALF,ROOT))
if model then print(string.format('GEO pyramid: centre X %.2f Z %.0f, %.1f wide, top Y %.2f (floor top %.2f); the Desert is Z %.0f .. %.0f',PX,PZ,PHALF*2,pyrHi or 0,FLOOR,desert.A or 0,desert.B or 0))end
check(near(LZ,motion and motion:GetAttribute('TrackBoundaryZ')or-1e9,1e-6)and near(LX,motion and motion:GetAttribute('TrackCenterX')or-1e9,1e-6),'MapService.new wrote the line\'s Z and X to RunnerMotion (TrackBoundaryZ / TrackCenterX): '..tostring(motion and motion:GetAttribute('TrackBoundaryZ')))
check(near(ENDZ,lastEnd,1e-6)and ENDZ>1475,('BiomeTrackEndZ (%s) is where the last biome ends (%.1f), not the old 1475 default'):format(tostring(ENDZ),lastEnd))
check(desert.Id==2 and near(desert.A,530)and near(desert.B,1180)and desert.B<=ENDZ,'the Desert is stage 2, Z 530 .. 1180, inside the track\'s end')
check(walls>=14 and innerWall<HALF and innerWall>80,('the side walls\' inner faces (|X| = %.2f) are inside the box (|X| <= %.1f)'):format(innerWall,HALF))
check(ROOT>-20 and ROOT<=300,'a standing root is inside the box\'s height')
check(model~=nil and pyrHi~=nil and pyrHi+3<=300 and PX-PHALF>-innerWall and PX+PHALF<innerWall,('the pyramid (X %.1f .. %.1f, top Y %.1f) is between the walls and inside the box'):format(PX-PHALF,PX+PHALF,pyrHi or 0))
check(T157 and T157.Enabled==true,'the place streams (Workspace.StreamingEnabled)')
check(T157 and T157.Target==1024,'StreamingTargetRadius 1024')
local lineFar=(T157 and T157.Target or 1024)+line.Position.Z+line.Size.Z/2
print(string.format('GEO streaming: StreamingEnabled %s, StreamingTargetRadius %s, StreamingMinRadius %s; the line\'s nearest face is at Z %.3f, so with the full radius it is gone for Z > %.1f; the Desert starts %.1f studs from it and the pyramid is %.1f studs away',tostring(T157.Enabled),tostring(T157.Target),tostring(T157.Min),line.Position.Z+line.Size.Z/2,lineFar,desert.A-LZ,PZ-LZ))

-- ====================================================================================================================================================================
-- the client side: a local player, the sound mock, the streaming mock, the real script
-- ====================================================================================================================================================================
local E=require('./sfx_env')(W)
local SS=W.service('SoundService')
local FILELEN={['rbxassetid://96110001912212']=900,['rbxassetid://74095461107598']=900,['rbxassetid://132448918728086']=900,['rbxassetid://90864299965930']=92,['rbxassetid://127003062753525']=190}
local BASE_IDS={'rbxassetid://1846088038','rbxassetid://1844513698','rbxassetid://1837487700','rbxassetid://1837487818','rbxassetid://1836280952'}
do local inew=R.Instance.new -- (the mock of R156's music suite) E's wrapper + Pause / Resume / Stop with their states, and the length of a file by its id
 R.Instance.new=function(class,parent)
  local o=inew(class,parent)
  if class=='Sound'then
   o.IsPaused=false
   local play=o.Play;o.Play=function(self)self.IsPaused=false;return play(self)end
   o.Stop=function(self)self.IsPlaying=false;self.IsPaused=false;self.TimePosition=0;self.Stops=(self.Stops or 0)+1 end
   o.Pause=function(self)if self.IsPlaying then self.IsPlaying=false;self.IsPaused=true end end
   o.Resume=function(self)if self.IsPaused then self.IsPaused=false;self.IsPlaying=true end end
   o.Changed:Connect(function(k)
    if k=='SoundId'then local n=FILELEN[o.SoundId]or(table.find(BASE_IDS,o.SoundId)and 900);if n then o.TimeLength=n end end
   end)
  end
  return o
 end
end
do
 local active={}
 local function ease(a)if a<.5 then return 2*a*a end;return 1-(-2*a+2)^2/2 end
 local function finish(tw,state)
  active[tw]=nil;tw.State=state
  tw.Completed:Fire(state)
  local list=tw._waiters;tw._waiters={}
  for _,co in ipairs(list)do coroutine.resume(co)end
 end
 W.service('TweenService').Create=function(_,obj,info,props)
  local tw={Completed=R.signal(),_waiters={},_t=0,State='Idle'}
  function tw.Completed:Wait()if coroutine.isyieldable()then local w=tw._waiters;w[#w+1]=coroutine.running();coroutine.yield()end end
  function tw:Play()
   self._from={};for k in pairs(props)do self._from[k]=obj[k]end;self._t=0;self.State='Playing';active[self]=true
   if info.Time<=0 then for k,v in pairs(props)do obj[k]=v end;finish(self,'Completed')end
  end
  function tw:Cancel()if active[self]then finish(self,'Cancelled')end end
  tw._step=function(dt)
   tw._t+=dt;local a=math.min(1,tw._t/info.Time)
   for k,v in pairs(props)do obj[k]=a>=1 and v or tw._from[k]+(v-tw._from[k])*ease(a)end
   if a>=1 then finish(tw,'Completed')end
  end
  return tw
 end
 W.service('RunService').Heartbeat:Connect(function(dt) -- (connected before the script, so a frame's time runs first)
  local list={};for tw in pairs(active)do list[#list+1]=tw end
  for _,tw in ipairs(list)do if active[tw]then tw._step(dt)end end
  for _,s in ipairs(E.sounds)do
   if s.IsPlaying and s.Parent then
    s.TimePosition+=dt*s.PlaybackSpeed
    if s.TimePosition>=s.TimeLength then
     if s.Looped then s.TimePosition-=s.TimeLength else s.IsPlaying=false;s.TimePosition=0;s.Ended:Fire()end
    end
   end
  end
 end)
end
do local realTask=W.env.task -- a task.wait that yields until the mock clock has moved
 W.env.task=setmetatable({
  wait=function(t)
   local co=coroutine.running()
   if co and coroutine.isyieldable()then R.task.delay(t or .03,function()coroutine.resume(co)end);coroutine.yield();return t or .03 end
   R.advance(t or .03);return t or .03
  end,
 },{__index=realTask})
end
W.env.warn=function()end
E.player('Tester')
local root=E.root
local DT=1/30
local V3,CF=R.Vector3.new,R.CFrame.new

-- STREAMING: the client's copy of the map. A Folder, the map's attributes and ReplicatedStorage are always there; a Part is only there while the player is within the streaming
-- radius of its box. BackgroundMusic needs one such Part: Lobby.BaseBoundaryLine. (The engine can also shrink the radius when it is short of memory: down to StreamingMinRadius.)
local streamRadius=math.huge
local function lineDistance()
 local c,lp,s=root.Position,line.Position,line.Size
 local dx=math.max(math.abs(c.X-lp.X)-s.X/2,0);local dy=math.max(math.abs(c.Y-lp.Y)-s.Y/2,0);local dz=math.max(math.abs(c.Z-lp.Z)-s.Z/2,0)
 return math.sqrt(dx*dx+dy*dy+dz*dz)
end
W.service('RunService').Heartbeat:Connect(function()
 local want=lineDistance()<=streamRadius
 if want and line.Parent==nil then line.Parent=lobby elseif not want and line.Parent~=nil then line.Parent=nil end
end)
root.CFrame=CF(0,ROOT,-300)
local bm=R.new('LocalScript');bm.Name='BackgroundMusic'
W.load('BackgroundMusic',bm)
W.frames(3,DT)
local function frames(seconds)W.frames(math.floor(seconds/DT+.5),DT)end

-- what is heard: the track music = the BiomeScenicMusic sounds' volumes, the base music = the ChestChaseBackgroundMusic sounds' volumes (the base voices' volume is their
-- envelope times the base gain, so a base voice that is faded away reads 0)
local VOL=.07
local function scenicSum()local t=0;for _,s in ipairs(SS:GetChildren())do if s.Name=='BiomeScenicMusic'then t+=s.Volume end end;return t end
local function baseMax()local m=0;for _,s in ipairs(SS:GetChildren())do if s.Name=='ChestChaseBackgroundMusic'and s.Volume>m then m=s.Volume end end;return m end
local function trackHeard()return scenicSum()>=VOL*.95 and baseMax()<=.0005 end
local function baseHeard()return scenicSum()<=.0005 and baseMax()>=.2*.95 end
frames(6)
check(baseHeard(),('in the hub (Z -300) the base music is heard and the track music is not (base %.3f, track %.3f)'):format(baseMax(),scenicSum()))

-- ====================================================================================================================================================================
-- B. the other "is the player on the track" tests agree with the box over the whole track
-- ====================================================================================================================================================================
print('-- B. the other tests')
do
 local Mood=W.module('BiomeMood');local Weather=W.module('WeatherWorld149')
 local area=Weather.Area(map)
 check(area.Valid and area.X0==-HALF and area.X1==HALF and near(area.Z0,-100)and near(area.Z1,ENDZ),('WeatherWorld149.Area is the same rectangle: X +-%.0f, Z %s .. %s'):format(HALF,tostring(area.Z0),tostring(area.Z1)))
 local badMood,badMap,badHub,n=0,0,0,0
 for z=0,ENDZ-1,10 do
  for _,x in ipairs({-innerWall+.5,0,innerWall-.5})do
   n+=1;local p=V3(x,ROOT,z)
   if Mood.Stage(map,p)==0 then badMood+=1 end
   if not mapService:IsInsideBiomeTrack(p)then badMap+=1 end
  end
 end
 for _,p in ipairs({V3(0,ROOT,-110),V3(0,ROOT,-361),V3(300,ROOT,-200),V3(-300,ROOT,-600)})do
  if Mood.Stage(map,p)~=0 or mapService:IsInsideBiomeTrack(p)then badHub+=1 end
 end
 check(badMood==0,('BiomeMood.Stage is a biome (not 0) at all %d samples along the centre line and both walls, Z 0 .. %.0f (%d not)'):format(n,ENDZ,badMood))
 check(badMap==0,('MapService:IsInsideBiomeTrack is true at all %d of them (%d not)'):format(n,badMap))
 check(badHub==0,'both say "not the track" in the hub (4 points)')
end

-- ====================================================================================================================================================================
-- C. the sweeps
-- ====================================================================================================================================================================
print('-- C. the sweeps')
local SETTLE=2.0 -- seconds after the entrance (or the exit): the 0.1 s step + the 1.2 s fade + a margin
local function insideTrack(p)return p.Z>LZ and p.Z<=lastEnd and math.abs(p.X-LX)<=innerWall and p.Y>FLOOR-1 and p.Y<300 end -- the track floor: past the line, between the walls
local function sweep(name,pts,speed,radius)
 streamRadius=radius
 local p0=pts[1];root.CFrame=CF(p0.X,p0.Y,p0.Z);frames(.5)
 local st={Name=name,Radius=radius,Frames=0,Track=0,Base=0,BadTrack=0,BadBase=0}
 local sinceIn,sinceOut=0,0
 local function sample(p)
  st.Frames+=1
  if insideTrack(p)then sinceIn+=DT;sinceOut=0 else sinceOut+=DT;sinceIn=0 end
  if sinceIn>=SETTLE then
   st.Track+=1
   if not trackHeard()then st.BadTrack+=1;st.FirstBad=st.FirstBad or p;st.LastBad=p end
  elseif sinceOut>=SETTLE+3 then
   st.Base+=1
   if not baseHeard()then st.BadBase+=1;st.FirstBadBase=st.FirstBadBase or p end
  end
 end
 sample(p0)
 for i=2,#pts do
  local a,b=pts[i-1],pts[i];local n=math.max(1,math.ceil((b-a).Magnitude/(speed*DT)))
  for k=1,n do local p=a+(b-a)*(k/n);root.CFrame=CF(p.X,p.Y,p.Z);W.frames(1,DT);sample(p)end
 end
 return st
end
local function show(st)
 local r=st.Radius==math.huge and'all streamed in'or('line streamed out beyond '..st.Radius)
 local bad=st.FirstBad and string.format('; base music first heard on the track at (%.1f, %.1f, %.1f), last at Z %.1f',st.FirstBad.X,st.FirstBad.Y,st.FirstBad.Z,st.LastBad.Z)or''
 print(string.format('SWEEP %-34s %-34s %5d frames, %5d on the track: %5d wrong; %4d in the hub: %d wrong%s',st.Name,r,st.Frames,st.Track,st.BadTrack,st.Base,st.BadBase,bad))
end
local function expectClean(st)
 show(st)
 check(st.Track>=300,st.Name..': '..st.Track..' frames were checked on the track')
 check(st.BadTrack==0,('%s (%s): the track music is heard on every checked frame (%d of %d are not%s)'):format(st.Name,st.Radius==math.huge and'all streamed in'or('radius '..st.Radius),st.BadTrack,st.Track,
  st.FirstBad and string.format('; first at Z %.1f',st.FirstBad.Z)or''))
 check(st.BadBase==0,('%s: the base music is heard (and only it) in the hub, %d frames wrong'):format(st.Name,st.BadBase))
end
local SPEED=50 -- studs a second: a runner (the boots go to 600; the script looks every 0.1 s, the box has no feature thinner than 3 studs)
local X=innerWall-.5 -- hugging a wall
local function lane(x,z0,z1)return{V3(x,ROOT,z0),V3(x,ROOT,z1)}end
local WHOLE=ENDZ-1
local centre=lane(LX,-450,WHOLE);local left=lane(LX-X,-450,WHOLE);local right=lane(LX+X,-450,WHOLE)

-- the pyramid: round its four faces (3 studs off the base), through it along both axes at the floor, and up the steps to the top and down the other side
local function pyramidPath()
 local m,t,low,high=PHALF+3,pyrHi+3,ROOT,ROOT
 local x0,x1,z0,z1=PX-m,PX+m,PZ-m,PZ+m
 local out={V3(PX,low,z0-40),V3(x0,low,z0),V3(x0,low,z1),V3(x1,low,z1),V3(x1,low,z0),V3(x0,low,z0)}
 for _,p in ipairs({V3(PX,low,z0-10),V3(PX,low,PZ),V3(PX,low,z1+10),V3(PX,low,PZ),V3(x0+3,low,PZ),V3(PX,low,PZ),V3(x1-3,low,PZ)})do out[#out+1]=p end
 for _,p in ipairs({V3(PX,t,PZ),V3(x1,low,PZ),V3(PX,low,z1+10),V3(PX,t,PZ),V3(PX,low,z0-10)})do out[#out+1]=p end
 return out
end
local pyr=model and pyramidPath()or lane(PX,900,1100)
-- (the Desert zig-zag: wall to wall across its whole length, 650 studs, the way a player crosses it to reach the keys on both sides)
local zig={V3(0,ROOT,desert.A-30)}
for z=desert.A,desert.B,25 do zig[#zig+1]=V3(((z-desert.A)//25)%2==0 and-X or X,ROOT,z)end
zig[#zig+1]=V3(0,ROOT,desert.B+30)

local radii={math.huge}
for _,r in ipairs({T157.Target or 1024,600,T157.Min or 64})do radii[#radii+1]=r end

if EXPECT=='old'then
 -- the proof run: the R156 script. Everything streamed in is fine (the box is right); with the line streamed out beyond the radius the base music comes back exactly there.
 local full=sweep('centre line',centre,SPEED,math.huge)
 show(full);check(full.BadTrack==0,'R156 script, everything streamed in: no wrong frame on the track (the box is right)')
 for _,r in ipairs({T157.Target or 1024,600,T157.Min or 64})do
  local st=sweep('centre line',centre,SPEED,r);show(st)
  local expectZ=math.max(r+line.Position.Z+line.Size.Z/2,LZ+SETTLE*SPEED) -- where the player leaves the radius of the line's box (same height: the Y gap is 3 studs); frames are only checked SETTLE seconds after the entrance
  check(st.BadTrack>0 and st.FirstBad~=nil,('R156 script, radius %s: the base music comes back on the track'):format(tostring(r)))
  check(st.FirstBad~=nil and st.FirstBad.Z>=expectZ-1 and st.FirstBad.Z<=expectZ+12,('R156 script, radius %s: it comes back where the line streams out: Z %.1f (the line is out beyond Z %.1f, the 0.1 s step and the fade add <= 12 studs at %d studs/s)'):format(tostring(r),st.FirstBad and st.FirstBad.Z or-1,expectZ,SPEED))
  if r==(T157.Target or 1024)then
   check(st.FirstBad and st.FirstBad.Z>desert.A and st.FirstBad.Z<desert.B,'R156 script, radius 1024: that is inside the Desert (Z '..desert.A..' .. '..desert.B..')')
   check(st.LastBad and st.LastBad.Z>=WHOLE-60,'R156 script, radius 1024: and the track music stays gone to the end of the track (last wrong frame at Z '..tostring(st.LastBad and st.LastBad.Z)..')')
  end
 end
else
 for _,r in ipairs(radii)do expectClean(sweep('centre line (hub -> end)',centre,SPEED,r))end
 for _,r in ipairs({math.huge,T157.Target or 1024,600,T157.Min or 64})do
  expectClean(sweep('left wall (hub -> end)',left,SPEED,r))
  expectClean(sweep('right wall (hub -> end)',right,SPEED,r))
 end
 for _,r in ipairs({math.huge,T157.Target or 1024,600,T157.Min or 64})do
  expectClean(sweep('round and through the pyramid',pyr,12,r))
  expectClean(sweep('Desert wall to wall',zig,SPEED,r))
 end
 -- the walk home: the whole track back to the hub, the line streaming back in at Z ~925; the track music all the way, then the base music in the hub
 for _,r in ipairs({T157.Target or 1024,T157.Min or 64})do
  local back=lane(LX,WHOLE,-450);local st=sweep('back to the hub (end -> hub)',back,SPEED,r)
  expectClean(st)
  check(baseHeard(),('radius %s: home in the hub the base music is heard (base %.3f, track %.3f)'):format(tostring(r),baseMax(),scenicSum()))
 end
 -- the hub: the base music on the lobby floor, at the spawn, at the line (the 0.5 stud hysteresis keeps the track one stud in)
 streamRadius=math.huge
 local spots={{0,-361},{300,-200},{-300,-600},{0,-141},{0,LZ-3},{LX+X,-110},{LX-X,-110}}
 local ok=true;local why=''
 for _,s in ipairs(spots)do
  root.CFrame=CF(s[1],ROOT,s[2]);frames(SETTLE+4)
  if not baseHeard()then ok=false;why=why..string.format(' (%.0f, %.0f)',s[1],s[2])end
 end
 check(ok,'the base music in the hub: lobby floor, spawn, three studs before the line, the corners by the entrance'..why)
 -- the track just past the line, and both ends of the Desert
 local starts={{0,LZ+3},{LX+X,LZ+3},{0,desert.A+1},{0,desert.B-1},{LX-X,desert.A+1},{LX+X,desert.B-1},{PX,PZ}}
 ok=true;why=''
 for _,s in ipairs(starts)do
  root.CFrame=CF(s[1],ROOT,s[2]);streamRadius=math.huge;frames(SETTLE+4)
  if not trackHeard()then ok=false;why=why..string.format(' (%.0f, %.0f)',s[1],s[2])end
 end
 check(ok,'the track music just past the entrance, at both ends of the Desert and in the middle of the pyramid'..why)
 -- a walk that is not on the track: outside the box (beyond the walls: 93 studs from the middle), too high, and dead
 root.CFrame=CF(LX+HALF+1,ROOT,PZ);frames(SETTLE+4);check(baseHeard(),'beyond the box (X = '..(LX+HALF+1)..') the base music is heard')
 root.CFrame=CF(0,301,PZ);frames(SETTLE+4);check(baseHeard(),'above the box (Y = 301) the base music is heard')
 root.CFrame=CF(0,ROOT,PZ);frames(SETTLE+4);check(trackHeard(),'back inside: the track music')
 E.hum.Health=0;frames(SETTLE+4);check(baseHeard(),'a dead player hears the base music (the character is gone)')
 E.hum.Health=100;frames(SETTLE+4);check(trackHeard(),'alive again: the track music')

 -- D. the playlists on the track. The place's own condition: in the Desert, in front of the pyramid, with the line streamed out (1064 studs from it). The three track songs are
 -- cut to 40 s (the real ones are minutes long; the logic only needs >> 3 s) so that they end and cross over every 40 s for 20 minutes; the base voice rotates every 897 s
 -- (its own rule), and did so in the sweeps above. On every frame: the track music is heard in full (the two songs of a crossfade add up to .07, never a dip into the base)
 -- and not one base voice is audible; the track songs really did start over and over (a crossfade each), and the base voices really were created.
 print('-- D. the playlists')
 streamRadius=T157.Target or 1024
 root.CFrame=CF(PX,ROOT,PZ-40);frames(SETTLE+4)
 check(line.Parent==nil and trackHeard(),'D: in front of the pyramid the line is streamed out and the track music is heard')
 local function startsOf(name)local n=0;for _,s in ipairs(E.named(name))do n+=s.Plays end;return n end
 local scenic={};for _,s in ipairs(SS:GetChildren())do if s.Name=='BiomeScenicMusic'then scenic[#scenic+1]=s;s.TimePosition=0;s.TimeLength=40 end end
 local starts0=startsOf('BiomeScenicMusic');local baseMade=#E.named('ChestChaseBackgroundMusic')
 local bad,dip,loud,quiet=0,0,0,0;local frames0=0
 for i=1,math.floor(1200/DT)do
  W.frames(1,DT);frames0+=1
  local sum,b=scenicSum(),baseMax()
  if b>.0005 then loud+=1;bad+=1 end
  if sum<VOL*.95 or sum>VOL*1.05 then dip+=1;bad+=1 end
  local playing=0;for _,s in ipairs(scenic)do if s.IsPlaying then playing+=1 end end
  if playing<1 then quiet+=1 end
 end
 local starts=startsOf('BiomeScenicMusic')-starts0
 print(string.format('SONGS D: %d frames in the Desert with the line streamed out: %d track song starts (a crossfade each), %d base voices made in all, %d frames with a base voice audible, %d frames off .07, %d frames with no track song playing',
  frames0,starts,#E.named('ChestChaseBackgroundMusic'),loud,dip,quiet))
 check(starts>=25,'D: the track songs ended and crossed over '..starts..' times in 20 minutes (>= 25 expected at 40 s a song)')
 check(#E.named('ChestChaseBackgroundMusic')>=3,'D: the base voice rotated at least twice in the run ('..#E.named('ChestChaseBackgroundMusic')..' base voices made)')
 check(loud==0,'D: no base voice is audible on any of '..frames0..' frames in the Desert ('..loud..' are)')
 check(dip==0,'D: the track music is exactly .07 on every frame, in a crossfade too ('..dip..' frames are not)')
 check(quiet==0,'D: a track song is playing on every frame ('..quiet..' frames are not)')

 -- E. the stand-ins for a streamed-out line
 print('-- E. the stand-ins')
 do
  local tz,tx=motion:GetAttribute('TrackBoundaryZ'),motion:GetAttribute('TrackCenterX')
  motion:SetAttribute('TrackBoundaryZ',nil);motion:SetAttribute('TrackCenterX',nil)
  frames(SETTLE+4);check(baseHeard(),'E: with the line streamed out and no RunnerMotion attributes the answer is "not on the track": the base music (as before)')
  motion:SetAttribute('TrackBoundaryZ',tz);frames(SETTLE+4);check(baseHeard(),'E: one attribute alone is not enough (the base music)')
  motion:SetAttribute('TrackCenterX',tx);frames(SETTLE+4);check(trackHeard(),'E: both attributes back: the track music')
  streamRadius=math.huge;root.CFrame=CF(0,ROOT,100);frames(SETTLE+4);check(line.Parent~=nil and trackHeard(),'E: the line is in: the track music at Z 100')
  motion:SetAttribute('TrackBoundaryZ',5000);frames(SETTLE+4)
  check(trackHeard(),'E: the live line wins over the attributes (they say 5000, the line says -99.3: the track music at Z 100)')
  motion:SetAttribute('TrackBoundaryZ',tz)
  streamRadius=T157.Target or 1024;root.CFrame=CF(PX,ROOT,PZ-40);frames(SETTLE+4);check(trackHeard(),'E: the attributes restored, the line out: the track music')
 end
end
print('R157 track music checks '..checks2..', fails '..fails2)
if fails2>0 then error('R157 track music: '..fails2..' failing check(s)')end
