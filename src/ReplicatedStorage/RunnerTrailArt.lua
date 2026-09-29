-- R48: shared broad ribbon silhouette for live trails and shop models.
local A={}
A.WidthKeys={{0,.82},{.16,1},{.53,.95},{.76,.60},{.90,.25},{1,0}}
function A.Width(t)
 for i=2,#A.WidthKeys do local a,b=A.WidthKeys[i-1],A.WidthKeys[i];if t<=b[1]then return a[2]+(b[2]-a[2])*math.clamp((t-a[1])/(b[1]-a[1]),0,1)end end
 return 0
end
function A.BodyRange(character,root)
 local lo,hi=math.huge,-math.huge
 for _,p in ipairs(character:GetChildren())do
  if p:IsA('BasePart')and p~=root and(p.Name=='Head'or p.Name:find('Torso')or p.Name:find('Leg')or p.Name:find('Foot')or p.Name:find(' Arm'))then
   local y=root.CFrame:PointToObjectSpace(p.Position).Y
   lo=math.min(lo,y-p.Size.Y/2);hi=math.max(hi,y+p.Size.Y/2)
  end
 end
 if lo==math.huge then return -2.6,2.6 end
 return lo+.10,hi-.10
end
function A.Attachments(rootSize,layer,lo,hi)
 local scale=math.clamp(rootSize.Y/2,.5,3);local back=rootSize.Z*.5+.10*scale;local y=.22*scale
 if lo and hi then local x=layer==1 and 0 or .18*scale;return Vector3.new(x,hi,back),Vector3.new(x,lo,back)end
 if layer==1 then return Vector3.new(0,y+.76*scale,back),Vector3.new(0,y-.76*scale,back)end
 return Vector3.new(-.51*scale,y,back),Vector3.new(.51*scale,y,back)
end
-- Fixed palettes, shared by the live ribbon and the shop preview. No image assets.
A.Palettes={
 MintTrail={Color3.fromRGB(42,218,139),Color3.fromRGB(87,249,179),Color3.fromRGB(23,173,113)},
 ArcTrail={Color3.fromRGB(59,118,255),Color3.fromRGB(69,219,255),Color3.fromRGB(55,128,239)},
 SolarTrail={Color3.fromRGB(255,121,43),Color3.fromRGB(255,217,71),Color3.fromRGB(244,157,34)},
 AuroraTrail={Color3.fromRGB(63,225,178),Color3.fromRGB(181,105,248),Color3.fromRGB(249,139,209)},
 NebulaTrail={Color3.fromRGB(127,73,222),Color3.fromRGB(102,190,247),Color3.fromRGB(111,61,195)},
 RoyalTrail={Color3.fromRGB(235,91,170),Color3.fromRGB(255,202,67),Color3.fromRGB(199,63,137)},
}
A.Profiles={}
for id in pairs(A.Palettes)do A.Profiles[id]={{0,.8},{.12,1},{.55,.82},{.82,.4},{1,0}}end
function A.Color(color,t,id)
 local palette=A.Palettes[id]or{color,color,color}
 if t<=.5 then return palette[1]:Lerp(palette[2],t*2)end
 return palette[2]:Lerp(palette[3],(t-.5)*2)
end
function A.Configure(trail,color,layer,id)
 local profile=A.Profiles[id]or A.WidthKeys;local keys={}
 for _,k in ipairs(profile)do table.insert(keys,NumberSequenceKeypoint.new(k[1],k[2]*(layer==1 and 1 or .20)))end
 trail.WidthScale=NumberSequence.new(keys);trail.Texture=''
 local palette=A.Palettes[id]or{color,color,color}
 trail.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,palette[1]),ColorSequenceKeypoint.new(.5,palette[2]),ColorSequenceKeypoint.new(1,palette[3])})
 local alpha=layer==1 and .20 or .45
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,alpha),NumberSequenceKeypoint.new(.60,alpha+.08),NumberSequenceKeypoint.new(.84,.6),NumberSequenceKeypoint.new(1,1)})
 trail.FaceCamera=true;trail.LightEmission=.35;trail.LightInfluence=0;trail.MinLength=.06;trail.Lifetime=1.4;trail.MaxLength=52;trail.Enabled=false
 trail:SetAttribute('PlainColourTrail91',true)
end
return A
