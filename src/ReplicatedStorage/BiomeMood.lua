-- R73: presentation only. Stable stage IDs come from map attributes, not biome order.
local C=Color3.fromRGB
local M={}
local function profile(name,ambient,outdoor,tint,air,decay,density,haze,bloom,top)
 return {Name=name,Light={Ambient=C(table.unpack(ambient)),OutdoorAmbient=C(table.unpack(outdoor)),Brightness=2.55,ExposureCompensation=.015,ColorShift_Top=C(table.unpack(top)),ColorShift_Bottom=C(0,1,4)},
  Grade={TintColor=C(table.unpack(tint)),Brightness=.005,Contrast=.045,Saturation=.045},
  Air={Color=C(table.unpack(air)),Decay=C(table.unpack(decay)),Density=density,Offset=.18,Haze=haze,Glare=.025},Bloom=bloom}
end
M.Profiles={
 [0]=profile('Garden',{137,145,166},{185,195,214},{255,252,245},{217,234,255},{159,180,210},.14,.40,.09,{17,9,2}),
 [1]=profile('Forest',{132,146,157},{180,198,207},{250,255,246},{216,237,222},{139,172,153},.16,.50,.09,{15,11,3}),
 [6]=profile('Jungle',{127,146,145},{174,198,189},{245,255,248},{203,232,216},{127,165,150},.17,.60,.10,{10,14,3}),
 [2]=profile('Desert',{149,143,160},{208,191,175},{255,250,237},{244,225,193},{194,162,141},.18,.65,.08,{23,12,2}),
 [3]=profile('Snow',{134,148,176},{190,210,229},{244,251,255},{219,237,254},{152,184,215},.13,.45,.08,{8,12,19}),
 [5]=profile('Crystal',{146,135,177},{195,183,221},{253,245,255},{223,212,250},{164,144,196},.15,.50,.13,{15,6,23}),
 [4]=profile('Lava',{150,134,149},{205,174,163},{255,244,233},{239,208,186},{184,137,126},.17,.60,.12,{27,10,1}),
 [7]=profile('Storm Peaks',{135,147,168},{180,194,217},{243,249,255},{197,216,237},{143,160,188},.18,.65,.10,{6,11,21}),
}
function M.Stage(map,point,previous)
 if not map or not point or math.abs(point.X)>(tonumber(map:GetAttribute('FieldWidth'))or 180)/2+2 or point.Y< -20 or point.Y>300 then return 0 end
 if previous and previous>0 and M.Profiles[previous]then
  local a,b=map:GetAttribute('BiomeStartZ_'..previous),map:GetAttribute('BiomeEndZ_'..previous)
  if type(a)=='number'and type(b)=='number'and point.Z>=a-2 and point.Z<b+2 then return previous end
 end
 for id=1,7 do
  local a,b=map:GetAttribute('BiomeStartZ_'..id),map:GetAttribute('BiomeEndZ_'..id)
  if type(a)=='number'and type(b)=='number'and point.Z>=a and point.Z<b then return id end
 end
 return 0
end
function M.Palette(stage,weather,low,refresh)
 local p=M.Profiles[stage]or M.Profiles[0]
 local out={Light=table.clone(p.Light),Grade=table.clone(p.Grade),Air=table.clone(p.Air),Bloom=p.Bloom,Sun=.008}
 if weather=='Rain'or weather=='Thunderstorm'or weather=='Blizzard'then
  -- R129 (owner): a real overcast: the sky and the light go dark grey under the storm clouds (snow: pale grey).
  local snow=weather=='Blizzard';local storm=weather=='Thunderstorm'
  out.Grade.TintColor=out.Grade.TintColor:Lerp(snow and C(226,236,250)or C(200,210,228),.6)
  out.Grade.Saturation=snow and -.08 or storm and -.2 or -.14;out.Grade.Brightness=snow and -.01 or storm and -.05 or -.03
  out.Air.Color=out.Air.Color:Lerp(snow and C(196,206,220)or storm and C(66,72,88)or C(96,104,120),.8)
  out.Air.Decay=out.Air.Decay:Lerp(snow and C(160,172,190)or storm and C(46,50,64)or C(70,78,94),.8)
  out.Air.Density=math.min(.42,out.Air.Density+(snow and .16 or storm and .2 or .14))
  out.Air.Haze=math.min(2.2,out.Air.Haze+(snow and .9 or .7));out.Air.Glare=0;out.Sun=0;out.Bloom=(out.Bloom or 0)*.5
  out.Light.Brightness=snow and 1.9 or storm and 1.15 or 1.45
  out.Light.ExposureCompensation=snow and -.05 or storm and -.35 or -.22
  out.Light.Ambient=out.Light.Ambient:Lerp(snow and C(150,158,172)or C(92,98,112),.5)
  out.Light.OutdoorAmbient=out.Light.OutdoorAmbient:Lerp(snow and C(170,178,192)or C(104,110,126),.5)
 end
 if stage==4 or stage==5 or stage==7 then out.Sun=0 end
 if low then out.Bloom=0;out.Sun=0;out.Air.Density*=.75;out.Air.Haze*=.5;out.Air.Glare=0 end
 if refresh then
  -- RefreshSky owns ambient light, time, sky and atmosphere until it restores them.
  out.Grade={TintColor=C(247,250,255),Brightness=.01,Contrast=.025,Saturation=.025};out.Bloom=0;out.Sun=0
 end
 return out
end
-- Creator Store source links and overrides are documented in READ_ME_R73.
M.Audio={
 {Key='Birds',Name='BiomeForestBirds',Id='9116971475',Attribute='BirdAssetId'},
 {Key='Leaves',Name='BiomeLeaves',Id='9116258282',Attribute='LeavesAssetId'},
 {Key='Wind',Name='BiomeWind',Id='3308152153',Attribute='WindAssetId'},
 {Key='Crystal',Name='BiomeCrystalHum',Id='9125719267',Attribute='CrystalAssetId'},
 {Key='Rumble',Name='BiomeLowRumble',Id='9120018695',Attribute='RumbleAssetId'},
}
function M.AudioId(row)
 local value=script:GetAttribute(row.Attribute)
 if value==nil then value=row.Id end
 value=tonumber(value)
 if not value or value%1~=0 or value<=0 or value>=9007199254740991 then return nil end
 return 'rbxassetid://'..string.format('%.0f',value)
end
function M.SoundTargets(stage,weather,refresh,chase,alive)
 local t={Birds=0,Leaves=0,Wind=0,Crystal=0,Rumble=0}
 if not alive then return t end
 if stage==0 then t.Birds=.018;t.Leaves=.022
 elseif stage==1 then t.Birds=.040;t.Leaves=.035
 elseif stage==6 then t.Birds=.033;t.Leaves=.045
 elseif stage==2 then t.Wind=.035
 elseif stage==3 then t.Wind=.045
 elseif stage==5 then t.Crystal=.008;t.Wind=.012
 elseif stage==4 then t.Rumble=.018;t.Wind=.016
 elseif stage==7 then t.Wind=.055;t.Rumble=.025 end
 if weather=='Rain'or weather=='Thunderstorm'or weather=='Blizzard'then
  t.Birds*=.15;t.Leaves*=.65;t.Wind=math.max(t.Wind,weather=='Blizzard'and .055 or .040)
  if weather=='Thunderstorm'then t.Rumble=math.max(t.Rumble,.022)end
 end
 if refresh then t.Birds=0;t.Leaves*=.4;t.Wind=math.max(t.Wind,.018)end
 if chase then for key,value in pairs(t)do t[key]=value*.12 end end
 return t
end
-- R127 (owner): The Darkened's arrival turns the lights off. The air goes black a short way from the camera, so only
-- nearby things can be seen and everything further away is black; no sun, dim ambient, drained colour.
-- Blackout(palette,k) blends any biome palette toward it (k 0..1); k=0 returns the palette untouched.
M.Dark={Light={Brightness=0,ExposureCompensation=-.35,Ambient=C(12,10,20),OutdoorAmbient=C(16,14,26),ColorShift_Top=C(0,0,0),ColorShift_Bottom=C(0,0,0)},
 Air={Color=C(0,0,0),Decay=C(0,0,0),Density=.7,Offset=0,Haze=0,Glare=0},
 Grade={TintColor=C(214,206,240),Brightness=-.04,Contrast=.1,Saturation=-.3}}
function M.Blackout(out,k)
 k=math.clamp(tonumber(k)or 0,0,1);if k<=0 then return out end
 local function mix(dst,src)
  if type(dst)~='table'then return end
  for name,v in pairs(src)do local a=dst[name];if a~=nil then dst[name]=typeof(v)=='Color3'and a:Lerp(v,k)or a+(v-a)*k end end
 end
 mix(out.Light,M.Dark.Light);mix(out.Air,M.Dark.Air);mix(out.Grade,M.Dark.Grade)
 out.Bloom=(out.Bloom or 0)*(1-k);out.Sun=(out.Sun or 0)*(1-k)
 return out
end
return M
