--!nocheck
-- R156 (owner: three looping weather ambiences - Blizzard 87749574738390, Thunderstorm 137593145026034, Rain 107960597100236 - "each should play during its own
-- weather"). On the Roblox mock with the REAL BiomeMood and the REAL BiomeAmbience.client of this checkout:
--  A. BiomeMood.SoundTargets: in the base each of the 3 weathers gives exactly its bed at its volume and the other two at 0; Clear / Cloudy / unknown weather give none; the
--     track (stages 1-7) gives none in any weather; not alive gives all 0; the chase gives x0.12; never two beds; and every OLD key (Birds / Leaves / Wind / Crystal / Rumble)
--     has exactly the old formula's target (the track stages 1-7 x1.25, R156) for every stage, weather, refresh, chase and alive combination (the old function is copied below as the reference).
--  B. the rows: the 3 new ones, the 5 old ones untouched, well formed, unique; the asset ids; the owner's override attribute; M.WeatherBeds is the one place for the volumes.
--  C. the real BiomeAmbience.client: it makes and preloads a Sound per row (the 3 new ones too, on the Ambience group, looped, silent), fades each bed in and out through
--     its alpha (no jump, a crossfade between two weathers, paused at 0 and resumed), is silent on the track, quiet in a chase, follows the Ambience slider and the
--     character, warns after 12 s about an unavailable bed BY NAME, honours an owner's id override, and cleans up.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-9)end
local floor=math.floor
local RS=W.RS;local Mood=W.module('BiomeMood')
local OLDKEYS={'Birds','Leaves','Wind','Crystal','Rumble'};local BEDKEYS={'RainBed','ThunderBed','BlizzardBed'}

-- The pre-R156 function, copied as it was (src/ReplicatedStorage/BiomeMood.lua before this round): the reference for "the old keys did not move".
-- R156 (owner: the track ambience "a bit" louder, in the same release): the track stages 1-7 are x1.25 (TRACK_GAIN); stage 0 and every rule below are as they were.
local TRACK_GAIN=1.25
local function oldTargets(stage,weather,refresh,chase,alive)
 local t={Birds=0,Leaves=0,Wind=0,Crystal=0,Rumble=0}
 if not alive then return t end
 if stage==0 then t.Birds=.018;t.Leaves=.022
 elseif stage==1 then t.Birds=.040*TRACK_GAIN;t.Leaves=.035*TRACK_GAIN
 elseif stage==6 then t.Birds=.033*TRACK_GAIN;t.Leaves=.045*TRACK_GAIN
 elseif stage==2 then t.Wind=.035*TRACK_GAIN
 elseif stage==3 then t.Wind=.045*TRACK_GAIN
 elseif stage==5 then t.Crystal=.008*TRACK_GAIN;t.Wind=.012*TRACK_GAIN
 elseif stage==4 then t.Rumble=.018*TRACK_GAIN;t.Wind=.016*TRACK_GAIN
 elseif stage==7 then t.Wind=.055*TRACK_GAIN;t.Rumble=.025*TRACK_GAIN end
 if weather=='Rain'or weather=='Thunderstorm'or weather=='Blizzard'then
  t.Birds*=.15;t.Leaves*=.65;t.Wind=math.max(t.Wind,weather=='Blizzard'and .055 or .040)
  if weather=='Thunderstorm'then t.Rumble=math.max(t.Rumble,.022)end
 end
 if refresh then t.Birds=0;t.Leaves*=.4;t.Wind=math.max(t.Wind,.018)end
 if chase then for key,value in pairs(t)do t[key]=value*.12 end end
 return t
end
-- The pre-R156 rows (same file), copied as they were.
local OLDROWS={
 {Key='Birds',Name='BiomeForestBirds',Id='9116971475',Attribute='BirdAssetId'},
 {Key='Leaves',Name='BiomeLeaves',Id='9116258282',Attribute='LeavesAssetId'},
 {Key='Wind',Name='BiomeWind',Id='3308152153',Attribute='WindAssetId'},
 {Key='Crystal',Name='BiomeCrystalHum',Id='9125719267',Attribute='CrystalAssetId'},
 {Key='Rumble',Name='BiomeLowRumble',Id='9120018695',Attribute='RumbleAssetId'},
}
-- What the owner asked for.
local EXPECT={Rain={Key='RainBed',Name='WeatherRainAmbience',Id='107960597100236',Attribute='RainBedAssetId',Volume=.3},
 Thunderstorm={Key='ThunderBed',Name='WeatherThunderAmbience',Id='137593145026034',Attribute='ThunderBedAssetId',Volume=.32},
 Blizzard={Key='BlizzardBed',Name='WeatherBlizzardAmbience',Id='87749574738390',Attribute='BlizzardBedAssetId',Volume=.3}}
local STORMS={'Rain','Thunderstorm','Blizzard'}

-- ======================================================================================================================
-- B. The rows and the volume table
-- ======================================================================================================================
print('-- rows')
do
 local rows=Mood.Audio
 check(type(rows)=='table'and #rows==8,'BiomeMood.Audio has 8 rows (5 beds + 3 weather beds): '..tostring(rows and #rows))
 for i,old in ipairs(OLDROWS)do
  local r=rows[i]
  check(r~=nil and r.Key==old.Key and r.Name==old.Name and r.Id==old.Id and r.Attribute==old.Attribute,'row '..i..' ('..old.Key..') is untouched and still in place')
 end
 local keys,names,attrs,ids={}, {}, {}, {}
 for i,r in ipairs(rows)do
  local ok=type(r.Key)=='string'and r.Key~=''and type(r.Name)=='string'and r.Name~=''and type(r.Id)=='string'and r.Id:match('^%d+$')~=nil and type(r.Attribute)=='string'and r.Attribute~=''
  check(ok,'row '..i..' is well formed (Key, Name, Id as digits, Attribute)')
  check(not keys[r.Key],'unique Key '..tostring(r.Key));check(not names[r.Name],'unique Name '..tostring(r.Name))
  check(not attrs[r.Attribute],'unique Attribute '..tostring(r.Attribute));check(not ids[r.Id],'unique Id '..tostring(r.Id))
  keys[r.Key]=true;names[r.Name]=true;attrs[r.Attribute]=true;ids[r.Id]=true
  local n=0;for _ in pairs(r)do n+=1 end;check(n==4,'row '..i..' has exactly the four fields Key / Name / Id / Attribute ('..n..')')
 end
 for i,weather in ipairs(STORMS)do
  local e=EXPECT[weather];local r=rows[5+i]
  check(r and r.Key==e.Key and r.Name==e.Name and r.Id==e.Id and r.Attribute==e.Attribute,weather..': row '..(5+i)..' is exactly '..e.Key..' / '..e.Name..' / '..e.Id..' / '..e.Attribute)
  check(Mood.AudioId(r)=='rbxassetid://'..e.Id,weather..': the asset id resolves to rbxassetid://'..e.Id..' (got '..tostring(Mood.AudioId(r))..')')
 end
 check(Mood.AudioId(rows[6])=='rbxassetid://107960597100236'and Mood.AudioId(rows[7])=='rbxassetid://137593145026034'and Mood.AudioId(rows[8])=='rbxassetid://87749574738390','Rain 107960597100236 / Thunderstorm 137593145026034 / Blizzard 87749574738390 (the owner\'s upload order)')
 for _,old in ipairs(OLDROWS)do check(Mood.AudioId(old)==Mood.AudioId(rows[table.find({'Birds','Leaves','Wind','Crystal','Rumble'},old.Key)]),'the old ids resolve as before: '..old.Key)end
 -- the owner's override: BiomeMood:SetAttribute('RainBedAssetId', id)
 local module=RS:FindFirstChild('BiomeMood')
 for _,weather in ipairs(STORMS)do
  local e=EXPECT[weather];local r=rows[table.find({'Rain','Thunderstorm','Blizzard'},weather)+5]
  module:SetAttribute(e.Attribute,987654321)
  check(Mood.AudioId(r)=='rbxassetid://987654321',weather..': BiomeMood:SetAttribute(\''..e.Attribute..'\', id) overrides the id ('..tostring(Mood.AudioId(r))..')')
  module:SetAttribute(e.Attribute,'555');check(Mood.AudioId(r)=='rbxassetid://555',weather..': a string of digits works too')
  for _,bad in ipairs({0,-5,1.5,'abc','',9007199254740992,false})do module:SetAttribute(e.Attribute,bad);check(Mood.AudioId(r)==nil,weather..': a bad override ('..tostring(bad)..') gives no id, so no sound (never a wrong one)')end
  module:SetAttribute(e.Attribute,nil);check(Mood.AudioId(r)=='rbxassetid://'..e.Id,weather..': removing the override returns the owner\'s upload')
 end
end
print('-- weather beds')
do
 local b=Mood.WeatherBeds
 check(type(b)=='table','M.WeatherBeds exists')
 local n=0;for _ in pairs(b)do n+=1 end;check(n==3,'exactly 3 weathers have a bed ('..n..')')
 for _,weather in ipairs(STORMS)do
  local e=EXPECT[weather];local x=b[weather]
  check(x and x.Key==e.Key and x.Volume==e.Volume,weather..': {Key='..e.Key..', Volume='..e.Volume..'}')
  local m=0;for _ in pairs(x or{})do m+=1 end;check(m==2,weather..': nothing but Key and Volume')
  local found=false;for _,r in ipairs(Mood.Audio)do if r.Key==(x and x.Key)then found=true end end;check(found,weather..': its Key is a row of M.Audio')
  check(type(x.Volume)=='number'and x.Volume>0 and x.Volume<=1,weather..': a volume between 0 and 1')
 end
 check(b.Clear==nil and b.Cloudy==nil,'Clear and Cloudy have no bed')
 check(b.Rain.Key~=b.Thunderstorm.Key and b.Rain.Key~=b.Blizzard.Key and b.Thunderstorm.Key~=b.Blizzard.Key,'three different beds')
 -- the volumes live in M.WeatherBeds only: change one and the target follows (louder / quieter on request)
 local keep=b.Rain.Volume;b.Rain.Volume=.5
 check(Mood.SoundTargets(0,'Rain',false,false,true).RainBed==.5,'M.WeatherBeds.Rain.Volume=.5 -> the Rain bed target is .5')
 check(Mood.SoundTargets(0,'Rain',false,true,true).RainBed==.5*.12,'... and the chase still takes x0.12 of it')
 check(Mood.SoundTargets(0,'Thunderstorm',false,false,true).ThunderBed==.32,'... the other beds are not affected')
 b.Rain.Volume=keep;check(Mood.SoundTargets(0,'Rain',false,false,true).RainBed==.3,'put back: .3')
end

-- ======================================================================================================================
-- A. SoundTargets
-- ======================================================================================================================
print('-- SoundTargets')
do
 local weathers=table.pack('Clear','Cloudy','Rain','Thunderstorm','Blizzard','Fog','rain','',nil)
 weathers.n=9
 local stages={-1,0,1,2,3,4,5,6,7,8}
 local alives=table.pack(true,false,nil);alives.n=3
 local combos,badOld,badBed,badKeys,twoBeds=0,0,0,0,0
 local firstBad
 for _,stage in ipairs(stages)do for wi=1,weathers.n do for _,refresh in ipairs({false,true})do for _,chase in ipairs({false,true})do for ai=1,alives.n do
  local weather,alive=weathers[wi],alives[ai]
  local t=Mood.SoundTargets(stage,weather,refresh,chase,alive);local old=oldTargets(stage,weather,refresh,chase,alive)
  combos+=1
  for _,k in ipairs(OLDKEYS)do if t[k]~=old[k]then badOld+=1;firstBad=firstBad or('stage '..tostring(stage)..' '..tostring(weather)..' refresh='..tostring(refresh)..' chase='..tostring(chase)..' alive='..tostring(alive)..' '..k..': '..tostring(t[k])..' vs '..tostring(old[k]))end end
  -- the keys: the 5 old ones and the 3 beds, nothing else
  local n=0;for k in pairs(t)do n+=1 end;if n~=8 then badKeys+=1 end
  -- the beds: exactly one, in the base, alive, in its own weather
  local bed=alive and stage==0 and EXPECT[weather or'']or nil
  local nonzero=0
  for _,w in ipairs(STORMS)do
   local e=EXPECT[w];local want=(bed==e)and(chase and e.Volume*.12 or e.Volume)or 0
   if t[e.Key]~=want then badBed+=1;firstBad=firstBad or('stage '..tostring(stage)..' '..tostring(weather)..' refresh='..tostring(refresh)..' chase='..tostring(chase)..' alive='..tostring(alive)..' '..e.Key..': '..tostring(t[e.Key])..' wanted '..want)end
   if t[e.Key]~=0 then nonzero+=1 end
  end
  if nonzero>1 then twoBeds+=1 end
 end end end end end
 print(('  %d combinations (stage -1..8, 9 weathers, refresh, chase, alive true / false / nil)'):format(combos))
 check(badOld==0,('every old key (Birds / Leaves / Wind / Crystal / Rumble) has exactly the old formula\'s target (the track stages x1.25) in all %d combinations (%d differ) %s'):format(combos,badOld,tostring(firstBad)))
 check(badBed==0,('every bed is its Volume only in the base, alive, in its own weather; x0.12 in a chase; 0 otherwise (%d wrong) %s'):format(badBed,tostring(firstBad)))
 check(badKeys==0,'the result has exactly the 8 keys (5 old + 3 beds), always')
 check(twoBeds==0,'never two beds at once, in any combination')
end
do
 local function beds(t)return t.RainBed,t.ThunderBed,t.BlizzardBed end
 -- the plain cases, spelled out
 local a,b,c=beds(Mood.SoundTargets(0,'Rain',false,false,true));check(a==.3 and b==0 and c==0,'base + Rain: the rain bed .3, thunder 0, blizzard 0')
 a,b,c=beds(Mood.SoundTargets(0,'Thunderstorm',false,false,true));check(a==0 and b==.32 and c==0,'base + Thunderstorm: thunder .32, the others 0')
 a,b,c=beds(Mood.SoundTargets(0,'Blizzard',false,false,true));check(a==0 and b==0 and c==.3,'base + Blizzard: the blizzard bed .3, the others 0')
 for _,w in ipairs({'Clear','Cloudy'})do a,b,c=beds(Mood.SoundTargets(0,w,false,false,true));check(a==0 and b==0 and c==0,'base + '..w..': no bed')end
 for stage=1,7 do for _,w in ipairs(STORMS)do
  a,b,c=beds(Mood.SoundTargets(stage,w,false,false,true));check(a==0 and b==0 and c==0,'track stage '..stage..' + '..w..': no bed (the track is silent like its weather)')
 end end
 for _,w in ipairs(STORMS)do a,b,c=beds(Mood.SoundTargets(0,w,false,false,false));check(a==0 and b==0 and c==0,'not alive + '..w..': no bed')end
 local t=Mood.SoundTargets(0,'Rain',false,false,false);local all0=true;for _,v in pairs(t)do if v~=0 then all0=false end end;check(all0,'not alive: all 8 targets are 0')
 a,b,c=beds(Mood.SoundTargets(0,'Rain',false,true,true));check(a==.3*.12 and b==0 and c==0,'chase + Rain: .3 x 0.12')
 a,b,c=beds(Mood.SoundTargets(0,'Thunderstorm',false,true,true));check(a==0 and b==.32*.12 and c==0,'chase + Thunderstorm: .32 x 0.12')
 a,b,c=beds(Mood.SoundTargets(0,'Blizzard',false,true,true));check(a==0 and b==0 and c==.3*.12,'chase + Blizzard: .3 x 0.12')
 -- the track-refresh rule only touches Birds / Leaves / Wind, as before: it leaves the bed alone (and the chase still scales it)
 a=Mood.SoundTargets(0,'Rain',true,false,true).RainBed;check(a==.3,'the refresh rule leaves the bed as it is ('..tostring(a)..')')
 a=Mood.SoundTargets(0,'Rain',true,true,true).RainBed;check(a==.3*.12,'refresh + chase: still x0.12')
 -- the result is a fresh table each call
 local x=Mood.SoundTargets(0,'Rain',false,false,true);x.RainBed=9;x.Birds=9
 local y=Mood.SoundTargets(0,'Rain',false,false,true);check(y.RainBed==.3 and near(y.Birds,.018*.15),'every call returns a fresh table (mutating one result changes nothing)')
 -- nothing odd in the weather breaks it
 for _,odd in ipairs({'__index','Rain ','THUNDERSTORM',0,true,'RainBed'})do
  local ok,r=pcall(Mood.SoundTargets,0,odd,false,false,true)
  check(ok and r.RainBed==0 and r.ThunderBed==0 and r.BlizzardBed==0,'an unknown weather value ('..tostring(odd)..') gives no bed and no error')
 end
 -- the old behaviour is still what it was (the rain still thins the birds ...)
 local t2=Mood.SoundTargets(0,'Rain',false,false,true);check(near(t2.Birds,.018*.15)and near(t2.Leaves,.022*.65)and t2.Wind==.040,'the old rain mix is unchanged (Birds x.15, Leaves x.65, Wind .04)')
end

-- ======================================================================================================================
-- C. the real BiomeAmbience.client
-- ======================================================================================================================
print('-- BiomeAmbience.client')
local Players=W.service('Players');local SS=W.service('SoundService');local Mixer=W.module('AudioMixer')
-- A Sound with the bits the script uses (IsLoaded, IsPlaying, Pause / Resume / Play), counting what it was asked.
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='Sound'then
  o._props.IsLoaded=true;o._props.IsPlaying=false;o._props.IsPaused=false;o._props.TimeLength=30;o._props.Loaded=R.signal();o._props.Ended=R.signal()
  o._props.Plays=0;o._props.Resumes=0;o._props.Pauses=0
  o._props.Play=function(self)self._props.IsPlaying=true;self._props.IsPaused=false;self._props.Plays+=1 end
  o._props.Resume=function(self)self._props.IsPlaying=true;self._props.IsPaused=false;self._props.Resumes+=1 end
  o._props.Pause=function(self)self._props.IsPlaying=false;self._props.IsPaused=true;self._props.Pauses+=1 end
  o._props.Stop=function(self)self._props.IsPlaying=false;self._props.IsPaused=false end
 end
 return o end end
local preloaded;local preloadCalls=0
W.service('ContentProvider').PreloadAsync=function(_,list)preloadCalls+=1;preloaded={};for i,s in ipairs(list)do preloaded[i]=s end end
local player=R.new('Player');player.Name='P';player.UserId=3;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal();player.CharacterRemoving=R.signal()
local char=R.new('Model');char.Name='P';local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(0,5,-60);hrp.Parent=char;char.Parent=W.workspace;player.Character=char
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace;map:SetAttribute('FieldWidth',180)
map:SetAttribute('BiomeStartZ_1',0);map:SetAttribute('BiomeEndZ_1',400)
local function run(sec)W.frames(floor(sec*60+.5),1/60)end
local function snd(name)return SS:FindFirstChild(name)end
local ALLNAMES={'BiomeForestBirds','BiomeLeaves','BiomeWind','BiomeCrystalHum','BiomeLowRumble','WeatherRainAmbience','WeatherThunderAmbience','WeatherBlizzardAmbience'}
local BEDNAME={Rain='WeatherRainAmbience',Thunderstorm='WeatherThunderAmbience',Blizzard='WeatherBlizzardAmbience'}
local function vol(n)return snd(n).Volume end
local function silent(n)local s=snd(n);return s.Volume==0 and not s.IsPlaying end
local function onlyBed(weather,v)  -- the weather's bed at v (nil = just check it is playing), the other two silent
 local ok=true
 for _,w in ipairs(STORMS)do
  if w==weather then ok=ok and(v==nil and snd(BEDNAME[w]).Volume>0 or v~=nil and near(vol(BEDNAME[w]),v,1e-9))and snd(BEDNAME[w]).IsPlaying
  else ok=ok and silent(BEDNAME[w])end
 end
 return ok
end
local function allBedsSilent()for _,w in ipairs(STORMS)do if not silent(BEDNAME[w])then return false end end;return true end
local function totalPlays(names)local n=0;for _,name in ipairs(names)do n+=snd(name).Plays+snd(name).Resumes end;return n end
RS:SetAttribute('GlobalWeather','Clear')
local script1=R.new('LocalScript');script1.Name='BiomeAmbience'
local ok,err=pcall(W.load,'BiomeAmbience',script1);check(ok,'the real BiomeAmbience.client loads on the mock: '..tostring(err))

-- 1. what it builds
do
 local n=0;for _,c in ipairs(SS._children)do if c._class=='Sound'then n+=1 end end
 check(n==8,'8 Sounds in SoundService, one per row ('..n..')')
 for i,r in ipairs(Mood.Audio)do
  local s=snd(r.Name)
  check(s~=nil and s._class=='Sound',r.Name..': a Sound named after its row')
  if s then
   check(s.SoundId==Mood.AudioId(r),r.Name..': SoundId '..tostring(s.SoundId))
   check(s.Looped==true and s.Volume==0 and not s.IsPlaying,r.Name..': looped, silent and not playing at the start')
   check(s.SoundGroup==Mixer.Group('Ambience'),r.Name..': routed to the Ambience SoundGroup (so the Ambience slider governs it)')
  end
 end
 check(preloadCalls==1 and preloaded~=nil and #preloaded==8,'one PreloadAsync request with 8 sounds ('..tostring(preloaded and #preloaded)..')')
 local inList={};for _,s in ipairs(preloaded or{})do inList[s.Name]=true end
 for _,name in ipairs(ALLNAMES)do check(inList[name]==true,name..' is in the preload list')end
end
run(6)
-- 2. Clear: the new beds stay out; the old Birds bed still plays as before
check(allBedsSilent() and totalPlays({'WeatherRainAmbience','WeatherThunderAmbience','WeatherBlizzardAmbience'})==0,'Clear in the base: no weather bed starts (never Play()ed)')
check(near(vol('BiomeForestBirds'),.018,1e-9)and snd('BiomeForestBirds').IsPlaying and near(vol('BiomeLeaves'),.022,1e-9),'(and the old Birds / Leaves beds play as before: .018 / .022)')
RS:SetAttribute('GlobalWeather','Cloudy');run(6);check(allBedsSilent(),'Cloudy in the base: no weather bed')

-- 3. Rain fades in through the alpha: no jump, rising, settled at .3
RS:SetAttribute('GlobalWeather','Rain')
do
 local samples={};for i=1,12 do run(.1);samples[i]=vol('WeatherRainAmbience')end
 check(samples[1]>0 and samples[1]<.3*.3,('Rain: it starts to rise, no jump (%.4f after the first .1 s)'):format(samples[1]))
 local up=true;for i=2,12 do if samples[i]<samples[i-1]then up=false end end;check(up and samples[12]>samples[1],'Rain: rising all along')
 check(samples[10]>.18 and samples[10]<.3,('Rain: about a second in it is most of the way (%.3f of .3)'):format(samples[10]))
 check(snd('WeatherRainAmbience').IsPlaying and snd('WeatherRainAmbience').Plays==1,'Rain: Play() once')
 run(6);check(onlyBed('Rain',.3),'Rain settled: the rain bed at .3, thunder and blizzard silent')
 check(snd('WeatherThunderAmbience').Plays==0 and snd('WeatherBlizzardAmbience').Plays==0,'(the other two beds were never started)')
 check(snd('BiomeWind').Volume>0 and near(vol('BiomeWind'),.040,1e-9),'(the old rain mix on Wind is as before: .04)')
end

-- 4. Rain -> Thunderstorm: a crossfade, never two settled beds
RS:SetAttribute('GlobalWeather','Thunderstorm')
do
 local rain,thunder={}, {};local dip=1
 for i=1,12 do run(.1);rain[i]=vol('WeatherRainAmbience');thunder[i]=vol('WeatherThunderAmbience');dip=math.min(dip,rain[i]+thunder[i])end
 local down,up=true,true;for i=2,12 do if rain[i]>rain[i-1]then down=false end;if thunder[i]<thunder[i-1]then up=false end end
 check(down and up and rain[12]<rain[1]and thunder[12]>thunder[1],'Rain -> Thunderstorm: the rain fades out while the thunder fades in (a crossfade)')
 check(dip>.28,('(and there is no gap in between: the two never add up to less than %.3f)'):format(dip))
 check(rain[1]<.3 and rain[1]>.2 and thunder[1]>0 and thunder[1]<.1,'(it starts from the settled rain, no jump)')
 run(8);check(onlyBed('Thunderstorm',.32),'Thunderstorm settled: thunder .32; rain and blizzard silent')
 local rs=snd('WeatherRainAmbience');check(rs.IsPaused and not rs.IsPlaying and rs.Volume==0,'the rain bed is paused at 0 (it costs nothing while it is not their weather)')
 check(near(vol('BiomeLowRumble'),.022,1e-9),'(the old thunder mix on Rumble is as before: .022)')
end
-- 5. Thunderstorm -> Blizzard
RS:SetAttribute('GlobalWeather','Blizzard');run(9);check(onlyBed('Blizzard',.3),'Blizzard: the blizzard bed .3; the others silent')
-- 6. back to Rain: the paused rain bed resumes (Resume, not a restart)
do
 local before=snd('WeatherRainAmbience').Plays
 RS:SetAttribute('GlobalWeather','Rain');run(9)
 check(onlyBed('Rain',.3),'Rain again: .3, the blizzard bed gone')
 check(snd('WeatherRainAmbience').Plays==before and snd('WeatherRainAmbience').Resumes>=1,'the rain bed was resumed from its pause, not restarted')
end
-- 7. Clear: everything fades out
RS:SetAttribute('GlobalWeather','Clear');run(10);check(allBedsSilent(),'back to Clear: every weather bed faded out and paused')

-- 8. the track is silent like its weather: in every weather
do
 RS:SetAttribute('GlobalWeather','Rain');run(8);check(onlyBed('Rain',.3),'(in the base again: Rain .3)')
 hrp.CFrame=CF(0,5,100);run(10)   -- stage 1 (Forest)
 check(allBedsSilent(),'walking onto the track (stage 1) in the rain: the bed fades out and is paused')
 local plays=totalPlays({'WeatherRainAmbience','WeatherThunderAmbience','WeatherBlizzardAmbience'})
 for _,w in ipairs({'Thunderstorm','Blizzard','Rain','Cloudy','Clear'})do RS:SetAttribute('GlobalWeather',w);run(4);check(allBedsSilent(),'on the track in '..w..': no weather bed')end
 check(totalPlays({'WeatherRainAmbience','WeatherThunderAmbience','WeatherBlizzardAmbience'})==plays,'(and none was started on the track)')
 RS:SetAttribute('GlobalWeather','Blizzard');run(8)
 map:SetAttribute('BiomeStartZ_6',400);map:SetAttribute('BiomeEndZ_6',900);hrp.CFrame=CF(0,5,500);run(5)  -- stage 6 (Jungle)
 check(allBedsSilent(),'stage 6 in the blizzard: silent')
 hrp.CFrame=CF(0,5,-60);run(9);check(onlyBed('Blizzard',.3),'back in the base: the blizzard bed returns')
end

-- 9. a chase: x0.12, quickly
do
 player:SetAttribute('ChestChaseRunActive',true);run(3)
 check(near(vol('WeatherBlizzardAmbience'),.3*.12,1e-9),('a chase ducks the blizzard bed to .3 x 0.12 = .036 (%.4f)'):format(vol('WeatherBlizzardAmbience')))
 check(snd('WeatherBlizzardAmbience').IsPlaying,'(and it keeps playing, quietly)')
 player:SetAttribute('ChestChaseRunActive',false);run(9);check(onlyBed('Blizzard',.3),'the chase over: back to .3')
end

-- 10. the Ambience slider
do
 check(Mixer.Set('Ambience',0),'(the Ambience slider to 0)');run(10)
 check(allBedsSilent(),'Ambience at 0: the weather bed is silent and paused')
 Mixer.Set('Ambience',100);run(9);check(onlyBed('Blizzard',.3),'Ambience back up: the bed returns')
 local g=Mixer.Group('Ambience');g.Volume=.5
 check(snd('WeatherBlizzardAmbience').SoundGroup==g and near(vol('WeatherBlizzardAmbience'),.3,1e-9),'the slider is the SoundGroup\'s gain on top of the bed\'s own .3 (the bed does not change)')
 g.Volume=1
end

-- 11. the character
do
 player.CharacterRemoving:Fire();run(10);check(allBedsSilent(),'the character is removed: the bed fades out')
 player.CharacterAdded:Fire();run(9);check(onlyBed('Blizzard',.3),'the character is back in the base: the bed returns')
end
local totalVoices=0;for _,c in ipairs(SS._children)do if c._class=='Sound'then totalVoices+=1 end end
RS:SetAttribute('GlobalWeather','Clear');run(10)

-- 12. teardown
script1.Destroying:Fire()
do local left=0;for _,name in ipairs(ALLNAMES)do if snd(name)then left+=1 end end;check(left==0,'when the script goes, its 8 Sounds go ('..left..' left)')end

-- 13. unavailable beds are named after 12 s; an owner's override is used
do
 local warns={};local oldWarn=W.env.warn;W.env.warn=function(...)local parts={};for i=1,select('#',...)do parts[i]=tostring((select(i,...)))end;warns[#warns+1]=table.concat(parts,' ')end
 local module=RS:FindFirstChild('BiomeMood');module:SetAttribute('ThunderBedAssetId',424242)
 RS:SetAttribute('GlobalWeather','Thunderstorm');hrp.CFrame=CF(0,5,-60)
 local script2=R.new('LocalScript');script2.Name='BiomeAmbience'
 check(pcall(W.load,'BiomeAmbience',script2),'(a second client loads)')
 check(snd('WeatherThunderAmbience').SoundId=='rbxassetid://424242','the owner\'s override (ThunderBedAssetId) is the id the sound gets')
 check(snd('WeatherRainAmbience').SoundId=='rbxassetid://107960597100236'and snd('WeatherBlizzardAmbience').SoundId=='rbxassetid://87749574738390','(the others keep the owner\'s uploads)')
 module:SetAttribute('ThunderBedAssetId',nil)
 for _,n in ipairs({'WeatherRainAmbience','WeatherThunderAmbience','WeatherBlizzardAmbience'})do snd(n)._props.IsLoaded=false end  -- the three never arrive
 run(11);check(#warns==0,'before 12 s there is no warning ('..#warns..')')
 run(2)
 check(#warns==3,'after 12 s: three warnings, one per unavailable bed ('..#warns..'; the 5 loaded beds say nothing)')
 for _,n in ipairs({'WeatherRainAmbience','WeatherThunderAmbience','WeatherBlizzardAmbience'})do
  local hit=0;for _,w in ipairs(warns)do if w:find(n,1,true)and w:find('unavailable',1,true)and w:find('R73',1,true)then hit+=1 end end
  check(hit==1,'the warning names '..n..' once')
 end
 run(30);check(#warns==3,'(and each is said once, not every tick)')
 check(allBedsSilent(),'an unavailable bed stays silent (target 0 until it has loaded)')
 snd('WeatherThunderAmbience')._props.IsLoaded=true;run(9)
 check(near(vol('WeatherThunderAmbience'),.32,1e-9)and snd('WeatherThunderAmbience').IsPlaying,'... and plays at .32 once it has loaded')
 check(silent('WeatherRainAmbience')and silent('WeatherBlizzardAmbience'),'(the others are not in their weather)')
 W.env.warn=oldWarn
 script2.Destroying:Fire()
end

-- 14. the source: the script has no special case for the new rows, and its first line is still the guard
do
 local src=W.B.BiomeAmbience
 check(src:find('RainBed',1,true)==nil and src:find('ThunderBed',1,true)==nil and src:find('BlizzardBed',1,true)==nil and src:find('WeatherBeds',1,true)==nil,'BiomeAmbience.client has no special case for the weather beds (it only iterates M.Audio)')
 check(src:match('^[^\n]*')==[[do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)]],'line 1 of BiomeAmbience.client is the R152 load guard, as before')
 local hub=W.B.HubLife151Client;check(hub:find('RainBed',1,true)==nil and hub:find('WeatherBeds',1,true)==nil,'HubLife151 does not pick the weather beds up (its zones are Birds / Crystal / Rumble)')
end
print(('R156 weather ambience: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
