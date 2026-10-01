-- R103: bounded reactor, piston and power-light motion on the original bag.
-- All artwork is thin, inside the outline, and shared by world and shop packs.
local A={TemplateKey='Forest_01'}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local Renderer=require(script.Parent.SeedPackRenderer)
local cache
local function bodyBounds()
 if cache then return cache end
 local t=assert(Renderer.GetGeometry(A.TemplateKey),'Approved pack template missing')
 local b={Radius=1,MinY=-1.22,MaxY=1.22,MinZ=0,MaxZ=0}
 for _,p in ipairs(t:GetChildren())do if p:IsA('MeshPart')then
  local f=p:GetAttribute('PackLocalFrame')
  for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
   local q=f*V(p.Size.X*x,p.Size.Y*y,p.Size.Z*z)
   b.Radius=math.max(b.Radius,V(q.X,0,q.Z).Magnitude);b.MinY=math.min(b.MinY,q.Y);b.MaxY=math.max(b.MaxY,q.Y)
   b.MinZ=math.min(b.MinZ,q.Z);b.MaxZ=math.max(b.MaxZ,q.Z)
  end end end
 end end
 cache=b;return b
end
-- R122: the Void (EclipseReliquary) design lives in EclipsePackArt (SeedPackRenderer/SeedPackVisuals
-- call it directly); this module keeps the Mech rig and the shared approved body bounds.
function A.BodyBounds()return bodyBounds()end
-- Baked from the approved Forest_01 body and shallow printed-surface triangles.
-- Each record is width, height and CFrame components; no runtime mesh fitting.
local fittedPrint={
 {0.3153237756,0.3815878264,-0.7364498371,-0.7398280775,-0.1931466845,0.9327838894,-0.07593076134,0.3523474637,0,0.9775586248,0.2106635588,-0.3604361465,-0.1965035737,0.9118509362}, -- MechSkin1_1-1
 {0.2975340004,0.4017220739,-0.4359572779,-0.7453217672,-0.2580490898,0.9900967288,-0.05305562771,0.1299752588,0,0.9258364242,0.3779244841,-0.1403868496,-0.3741817955,0.916667615}, -- MechSkin1_2-1
 {0.2949726619,0.4100991611,-0.1451997794,-0.7469546021,-0.2875682594,0.998933713,-0.01959853111,0.04180113132,0,0.9054235483,0.4245093618,-0.04616748858,-0.424056713,0.9044581069}, -- MechSkin1_3-1
 {0.2949726619,0.4133962507,0.145052414,-0.7462368924,-0.2844425082,0.998933713,0.02030665758,-0.04146174935,0,0.8980724451,0.4398475682,0.04616748858,-0.4393785645,0.8971148422}, -- MechSkin1_4-1
 {0.2975340004,0.4105451478,0.4351229318,-0.7450616925,-0.2523445975,0.9900967288,0.05946000389,-0.127173014,0,0.9058755454,0.423543972,0.1403868496,-0.4193495012,0.8969044143}, -- MechSkin1_5-1
 {0.3153237756,0.3923538852,0.7376079521,-0.7463751892,-0.1964678987,0.9327838894,0.108688514,-0.3436582934,0,0.9534512471,0.3015472092,0.3604361465,-0.2812783786,0.8893639626}, -- MechSkin1_6-1
 {0.3389812719,0.3753198699,-0.7413976929,-0.3698008045,-0.2675715341,0.866111442,-0.05820530608,0.4964505136,0,0.9931971034,0.116445325,-0.4998509479,-0.1008546284,0.8602193754}, -- MechSkin2_1-1
 {0.300444523,0.3768918233,-0.4357046694,-0.3686504745,-0.3532153613,0.9802428978,-0.03148725421,0.1952752267,0,0.987248074,0.1591893227,-0.1977975261,-0.156044203,0.9677429129}, -- MechSkin2_2-1
 {0.2953072499,0.3785512851,-0.1455400096,-0.3702871656,-0.4022155574,0.9977703898,-0.0124674536,0.06556532568,0,0.9823968496,0.1868058614,-0.0667401628,-0.1863893571,0.9802064875}, -- MechSkin2_3-1
 {0.2953489282,0.3783104054,0.1455364796,-0.3699682958,-0.4015038479,0.9976256689,0.01263085291,-0.06770145053,0,0.9830379267,0.1834023844,0.06886962211,-0.1829669264,0.9807038692}, -- MechSkin2_4-1
 {0.3010442854,0.376901896,0.4365348718,-0.3690732098,-0.3563620225,0.9782366726,0.03299793276,-0.2048515289,0,0.9872734027,0.1590321612,0.2074921985,-0.1555710922,0.9657870484}, -- MechSkin2_5-1
 {0.3349332506,0.3752858287,0.7209639266,-0.3650554033,-0.2332806587,0.8768354585,0.05638088296,-0.4774733236,0,0.9931004197,0.1172670299,0.4807905768,-0.10282389,0.8707856619}, -- MechSkin2_6-1
 {0.3460388559,0.3720510431,-0.7214357378,0.0001278077356,-0.260861459,0.8480287448,0.007525748786,0.5298967928,0,0.9998991627,-0.01420085951,-0.5299502316,0.01204273707,0.8479432319}, -- MechSkin3_1-1
 {0.3021383159,0.3722128581,-0.4320145273,0.0002998471117,-0.3710868511,0.9745981778,0.007461551862,0.2238363621,0,0.9994448565,-0.03331634575,-0.2239606924,0.03247004986,0.974057136}, -- MechSkin3_2-1
 {0.2954703148,0.3722743805,-0.1440053264,0.000348276402,-0.4198396083,0.9972044135,0.002891540393,0.07466590009,0,0.9992509759,-0.038697378,-0.07472186857,0.03858919613,0.9964574834}, -- MechSkin3_3-1
 {0.2954703148,0.3723170624,0.144021412,0.0003833591359,-0.4200251533,0.9972044135,-0.003108043784,-0.0746572013,0,0.9991345604,-0.04159483487,0.07472186857,0.04147855291,0.9963413933}, -- MechSkin3_4-1
 {0.3021383159,0.3722743805,0.4320384076,0.0003444828373,-0.3711444573,0.9745981778,-0.008470505345,-0.2238004519,0,0.9992845152,-0.03782139292,0.2239606924,0.03686066062,0.9739008676}, -- MechSkin3_5-1
 {0.3460388559,0.3721368823,0.7214349292,0.0002092735852,-0.2607533689,0.8480287448,-0.01232273166,-0.5298069443,0,0.9997296213,-0.02325262058,0.5299502316,0.01971889064,0.8477994559}, -- MechSkin3_6-1
 {0.3335430509,0.3757615416,-0.7211994727,0.3652139971,-0.230586106,0.8805798984,0.05966910968,0.4701261957,0,0.9920414947,-0.1259113687,-0.4738977131,0.1108750203,0.8735717986}, -- MechSkin4_1-1
 {0.3009269329,0.3779934489,-0.4318219818,0.3655799602,-0.3281076891,0.978628574,0.03609961079,0.2024424171,0,0.9844703147,-0.1755511305,-0.2056358776,0.1717993526,0.9634307802}, -- MechSkin4_2-1
 {0.2952640557,0.3806592159,-0.1439000298,0.3659250437,-0.3708530552,0.9979204186,0.01378717036,0.06296627746,0,0.976856932,-0.2138937458,-0.06445803413,0.2134489363,0.9748254784}, -- MechSkin4_3-1
 {0.2952640557,0.3799365868,0.1439110742,0.3658779655,-0.3706646405,0.9979204186,-0.01321841075,-0.0630881271,0,0.9787473036,-0.2050700262,0.06445803413,0.2046435664,0.9767119189}, -- MechSkin4_4-1
 {0.3002208782,0.3779872044,0.4320451591,0.3658830025,-0.3290269649,0.9809931052,-0.03412677423,-0.1910180381,0,0.9844129369,-0.175872595,0.1940425922,0.172529803,0.9657023037}, -- MechSkin4_5-1
 {0.3382076809,0.3757818583,0.7231609597,0.3656417367,-0.2327642155,0.8681405166,-0.0617875254,-0.4924574552,0,0.992220651,-0.1244916856,0.49631849,0.1080762762,0.8613869485}, -- MechSkin4_6-1
 {0.3161503673,0.3812058949,-0.7218567099,0.7309787081,-0.1583380665,0.9302817619,0.07557976916,0.3589756844,0,0.9785465202,-0.2060259882,-0.3668458034,0.1916622193,0.9103239809}, -- MechSkin5_1-1
 {0.2976427513,0.4059609808,-0.4311790109,0.7316066136,-0.222968227,0.9897249813,0.05729872289,0.1310012125,0,0.9161940759,-0.4007348441,-0.1429841296,0.3966172861,0.9067801647}, -- MechSkin5_2-1
 {0.2949816048,0.416349149,-0.1437091634,0.7320755042,-0.252951341,0.9989025841,0.02120900352,0.04175889803,0,0.8915949481,-0.4528337978,-0.04683617614,0.4523368508,0.8906164977}, -- MechSkin5_3-1
 {0.2949816048,0.420311803,0.1437055576,0.7322236674,-0.2524734242,0.9989025841,-0.02198004774,-0.04135825065,0,0.8830407189,-0.4692963762,0.04683617614,0.4687813629,0.882071656}, -- MechSkin5_4-1
 {0.2976427513,0.4165838526,0.4316257951,0.7337378967,-0.2249058646,0.9897249813,-0.06441703149,-0.1276515075,0,0.8927669657,-0.450518751,0.1429841296,0.4458896624,0.8835937684}, -- MechSkin5_5-1
 {0.3161503673,0.3933796064,0.7262946943,0.7364901953,-0.1675282794,0.9302817619,-0.1129108451,-0.3490372251,0,0.9514548672,-0.307788297,0.3668458034,0.2863298392,0.8851211102}, -- MechSkin5_6-1
 {0.1870800591,0.03458962216,0.5727727241,-0.5017931321,-0.2682105514,0.9492960905,0.0626367789,-0.3080804545,0,0.9799513537,0.1992369051,0.3143834164,-0.1891348151,0.930263989}, -- VentPrint1-1
 {0.1853062165,0.03539549665,0.5811889455,-0.6025365749,-0.2736340087,0.9587932299,0.08617637844,-0.2707197335,0,0.9528868405,0.3033260114,0.2841048087,-0.2908269262,0.9136214515}, -- VentPrint2-1
 {0.1831899117,0.03618632699,0.5795776803,-0.6961038343,-0.2442930197,0.9703755105,0.09092892496,-0.2238376628,0,0.9264739746,0.3763588372,0.2416016736,-0.3652093988,0.899027656}, -- VentPrint3-1
}
local mechSpecs
function A.Specs(kind)
 if mechSpecs then return mechSpecs end
 local out={};local bounds=bodyBounds();local minZ,maxZ=bounds.MinZ,bounds.MaxZ
 local silver,light,graphite,gold,cyan=RGB(180,197,207),RGB(232,238,241),RGB(53,66,79),RGB(242,180,65),RGB(34,231,255)
 local function add(name,size,frame,color,material,shape)
  local spec={Name=name,Size=size,Frame=frame,Color=color,Material=material or Enum.Material.SmoothPlastic,Shape=shape};out[#out+1]=spec;return spec
 end
 local function motion(spec,kind,pivot,rate,amplitude,phase,pulse)spec.Motion=kind;spec.Pivot=pivot;spec.Rate=rate;spec.Amplitude=amplitude;spec.Phase=phase;spec.Pulse=pulse;return spec end
for _,side in ipairs({-1,1})do
 local flip=side>0 and CFrame.Angles(0,math.pi,0)or CF()
 for row=1,5 do for column=1,6 do
  local t=fittedPrint[(row-1)*6+column];local color=(column==1 or column==6)and silver or light
  if row==3 and(column==2 or column==5)then color=gold end
  add('FittedArmor'..side..'_'..row..'_'..column,V(t[1],t[2],.008),flip*CF(table.unpack(t,3)),color)
 end end
 -- Recessed piston channels sit inside the original silhouette.
 for _,x in ipairs({-.66,.66})do
  add('PistonChannel'..side..x,V(.20,1.32,.025),flip*CF(x,-.01,-.415),graphite)
  add('SilverPiston'..side..x,V(1.08,.055,.055),flip*CF(x,-.01,-.449)*CFrame.Angles(0,0,math.pi/2),light,Enum.Material.Metal,Enum.PartType.Cylinder)
  for _,y in ipairs({-.53,.51})do add('GoldPistonCap'..side..x..y,V(.17,.13,.13),flip*CF(x,y,-.449)*CFrame.Angles(0,0,math.pi/2),gold,Enum.Material.Metal,Enum.PartType.Cylinder)end
  motion(add('PistonCuff'..side..x,V(.14,.19,.08),flip*CF(x,-.23,-.455),silver),'Slide',nil,math.pi*2/3,.12,x<0 and 0 or math.pi)
  motion(add('CuffLight'..side..x,V(.03,.12,.012),flip*CF(x,-.23,-.501),cyan,Enum.Material.Neon),'Slide',nil,math.pi*2/3,.12,x<0 and 0 or math.pi,.12)
 end
 local face=(side<0 and minZ or maxZ)+side*.013
 local base=CF(0,-.02,face)*CFrame.Angles(0,side>0 and math.pi or 0,0)
 add('ReactorHousing'..side,V(.028,.93,.93),base*CFrame.Angles(0,math.pi/2,0),graphite,nil,Enum.PartType.Cylinder)
 add('ReactorInset'..side,V(.014,.66,.66),base*CF(0,0,-.023)*CFrame.Angles(0,math.pi/2,0),RGB(20,123,152),nil,Enum.PartType.Cylinder)
 local core=add('ReactorCore'..side,V(.012,.49,.49),base*CF(0,0,-.035)*CFrame.Angles(0,math.pi/2,0),cyan,Enum.Material.Neon,Enum.PartType.Cylinder);core.Pulse=.10
 for ring,radius in ipairs({.43,.31})do for i=1,8 do
  local a,b=(i-1)*math.pi/4,i*math.pi/4
  local p,q=V(math.cos(a)*radius,math.sin(a)*radius,0),V(math.cos(b)*radius,math.sin(b)*radius,0);local d=q-p
  add('ReactorEdge'..side..ring..'_'..i,V(d.Magnitude+.009,ring==1 and .055 or .022,.014),base*CF((p+q)*.5+V(0,0,ring==1 and -.020 or -.037))*CFrame.Angles(0,0,math.atan2(d.Y,d.X)),ring==1 and silver or cyan,ring==1 and Enum.Material.Metal or Enum.Material.Neon)
 end end
 motion(add('CoreFacet'..side,V(.19,.19,.008),base*CF(0,0,-.047)*CFrame.Angles(0,0,math.pi/4),RGB(143,251,255),Enum.Material.Neon),'Spin',base,math.pi*2/3)
 for i=1,8 do
  local angle=(i-1)*math.pi/4;local pivot=base*CF(0,0,-.057)
  motion(add('TurbineBlade'..side..'_'..i,V(.12,.035,.010),pivot*CF(math.cos(angle)*.175,math.sin(angle)*.175,0)*CFrame.Angles(0,0,angle+.50),i%2==0 and graphite or silver),'Spin',pivot,math.pi*2/3)
 end
 for i=1,4 do
  local angle=(i-1)*math.pi/2;local pivot=base*CF(0,0,-.036)
  motion(add('CounterGear'..side..'_'..i,V(.080,.047,.012),pivot*CF(math.cos(angle)*.39,math.sin(angle)*.39,0)*CFrame.Angles(0,0,angle),gold,Enum.Material.Metal),'Spin',pivot,-math.pi/3)
 end
 for _,x in ipairs({-.40,.40})do
  add('PowerConduit'..side..x,V(.085,.20,.020),base*CF(x,.37,.075)*CFrame.Angles(0,0,x<0 and -.3 or .3),graphite)
  local light=add('PowerLED'..side..x,V(.025,.13,.012),base*CF(x,.37,.057)*CFrame.Angles(0,0,x<0 and -.3 or .3),cyan,Enum.Material.Neon);light.Pulse=.16;light.Phase=x<0 and 0 or math.pi
 end
 for _,x in ipairs({-.43,.43})do for _,y in ipairs({-.73,.72})do
  add('Bolt'..side..x..y,V(.023,.085,.085),flip*CF(x,y,-.30)*CFrame.Angles(0,math.pi/2,0),graphite,nil,Enum.PartType.Cylinder)
 end end
 for i=1,3 do add('LowerVent'..side..i,V(.20+(i-1)*.04,.024,.012),flip*CF(0,-.67-(i-1)*.072,-.30),graphite)end
 local upper=add('UpperCoreAccent'..side,V(.24,.04,.012),base*CF(0,.55,.13),cyan,Enum.Material.Neon);upper.Pulse=.12
 local lower=add('LowerCoreAccent'..side,V(.24,.04,.012),base*CF(0,-.55,.13),cyan,Enum.Material.Neon);lower.Pulse=.12;lower.Phase=math.pi
end
 mechSpecs=out;return out
end
function A.Bounds(kind,scale)
 local b=table.clone(bodyBounds());local depth=kind=='MechLimited'and .075 or .055;b.MinZ-=depth;b.MaxZ+=depth;b.Radius+=kind=='MechLimited'and .085 or .06;b.MinY-=.04;b.MaxY+=.04
 for k,v in pairs(b)do b[k]=v*(scale or 1)end;return b
end
function A.Build(bag,kind)
 if bag:GetAttribute('SpecialPackDesign89')then return true end
 Renderer.BuildStandard(bag,A.TemplateKey)
 local root=bag.PrimaryPart;local folder=bag:FindFirstChild('PackGeometry');local scale=bag:GetAttribute('VisualScale')or 1
 local mech=kind=='MechLimited';local body=mech and RGB(231,237,239)or RGB(22,13,43);local trim=mech and RGB(246,171,75)or RGB(159,128,219)
 for _,p in ipairs(folder:GetChildren())do if p:IsA('MeshPart')then
  p.TextureID='';p.MaterialVariant='';p.Material=Enum.Material.SmoothPlastic;p.Color=body
  for _,v in ipairs(p:GetChildren())do if v:IsA('SurfaceAppearance')then v:Destroy()end end
  if mech then p.Reflectance=0;p.Transparency=0 end
 end end
 local count=bag:GetAttribute('CompactPackPartCount')or 10
 for _,s in ipairs(A.Specs(kind))do
  local p=Instance.new('Part');p.Name=s.Name;p.Size=s.Size*scale
  local frame=CF(s.Frame.Position*scale)*s.Frame.Rotation;p.CFrame=root.CFrame*frame;p:SetAttribute('PackLocalFrame',frame)
  p.Color=s.Color;p.Material=s.Material;if s.Shape then p.Shape=s.Shape end;p.Reflectance=0;p.Anchored=root.Anchored;p.Massless=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  if s.Motion then
   p:SetAttribute('MechMotion',s.Motion);p:SetAttribute('MechMotionRate',s.Rate);p:SetAttribute('MechMotionAmplitude',(s.Amplitude or 0)*scale);p:SetAttribute('MechMotionPhase',s.Phase or 0)
   if s.Pivot then p:SetAttribute('MechMotionPivot',CF(s.Pivot.Position*scale)*s.Pivot.Rotation)end
  end
  if s.Pulse then p:SetAttribute('MechPulse',s.Pulse);p:SetAttribute('MechMotionPhase',s.Phase or 0)end
  if not p.Anchored then
   if s.Motion then local joint=Instance.new('Motor6D');joint.Name='MechServo';joint.Part0=root;joint.Part1=p;joint.C0=frame;joint.C1=CF();joint.Parent=p
   else local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p end
  end
  if(bag:GetAttribute('PackSize')or 1)>10 then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end
  p.Parent=folder;count+=1
 end
 for _,p in ipairs(bag:GetChildren())do if p:IsA('BasePart')and(p.Name=='BottomSeal'or p:GetAttribute('TearIndex'))then p.Color=trim;p.Material=mech and Enum.Material.SmoothPlastic or Enum.Material.Metal;p.Reflectance=0 end end
 bag:SetAttribute('ApprovedShapeKey89',A.TemplateKey);bag:SetAttribute('SpecialPackDesign89',true);bag:SetAttribute('CompactPackPartCount',count)
 bag:SetAttribute('PaperColor',body);bag:SetAttribute('PreserveTextStyle',true)
 if mech then bag:SetAttribute('MechDesignRevision',103);require(script.Parent.ItemEffectAnchor).Set(bag,bag:GetAttribute('Weather'),true,scale*1.05,scale*2.2)
 else bag:SetAttribute('EclipsePack',true);bag:SetAttribute('VoidDesignRevision',89)end
 return true
end
-- Captured once by each existing renderer. This object owns no connections.
function A.CaptureMotion(bag)
 local state={Bag=bag,Root=bag and bag.PrimaryPart,Entries={},ByPart={},Colors={}}
 if not state.Root or bag:GetAttribute('BagVariant')~='MechLimited'then
  state.LocalFrame=function()return nil end;state.Step=function()end;state.Pulse=function()end;state.Reset=function()end;return state
 end
 for _,part in ipairs(bag:GetDescendants())do if part:IsA('BasePart')then
  local kind=part:GetAttribute('MechMotion');local rest=part:GetAttribute('PackLocalFrame')
  if kind and typeof(rest)=='CFrame'then
   local entry={Part=part,Rest=rest,Kind=kind,Rate=part:GetAttribute('MechMotionRate')or 0,Amplitude=part:GetAttribute('MechMotionAmplitude')or 0,Phase=part:GetAttribute('MechMotionPhase')or 0,Joint=part:FindFirstChild('MechServo')}
   local pivot=part:GetAttribute('MechMotionPivot');entry.Pivot=typeof(pivot)=='CFrame'and pivot or rest;entry.Offset=entry.Pivot:ToObjectSpace(rest)
   state.Entries[#state.Entries+1]=entry;state.ByPart[part]=entry
  end
  local pulse=part:GetAttribute('MechPulse')
  if type(pulse)=='number'and pulse>0 then state.Colors[#state.Colors+1]={Part=part,Color=part.Color,Amount=math.clamp(pulse,0,.18),Phase=part:GetAttribute('MechMotionPhase')or 0}end
 end end
 local function time(t)return type(t)=='number'and t==t and math.abs(t)<math.huge and t%6 or 0 end
 local function live(part)return bag.Parent~=nil and state.Root.Parent~=nil and part.Parent~=nil and part:IsDescendantOf(bag)end
 function state:LocalFrame(part,t)
  local entry=self.ByPart[part];if not entry or not live(part)then return nil end;t=time(t)
  if entry.Kind=='Spin'then return entry.Pivot*CFrame.Angles(0,0,t*entry.Rate)*entry.Offset end
  if entry.Kind=='Slide'then return entry.Rest*CF(0,math.sin(t*entry.Rate+entry.Phase)*entry.Amplitude,0)end
  return entry.Rest
 end
 function state:Pulse(t)
  t=time(t)
  for _,entry in ipairs(self.Colors)do if live(entry.Part)then
   local amount=(.5+.5*math.sin(t*math.pi*2/3+entry.Phase))*entry.Amount
   entry.Part.Color=entry.Color:Lerp(Color3.new(1,1,1),amount)
  end end
 end
 local function apply(entry,pose,rootFrame,move)
  local part=entry.Part
  if part.Anchored then
   if move then move(part,rootFrame*pose)else part.CFrame=rootFrame*pose end
  else
   -- The part may replicate before its servo; retry the lookup until it arrives.
   if not entry.Joint or entry.Joint.Parent~=part then entry.Joint=part:FindFirstChild('MechServo')end
   if entry.Joint and entry.Joint:IsA('Motor6D')and entry.Joint.Part0==state.Root and entry.Joint.Part1==part then
    -- Adjust the local joint only; never move a welded character assembly.
    entry.Joint.C0=pose
   end
  end
 end
 function state:Step(t,rootFrame,move)
  if not bag.Parent or not self.Root.Parent then return end
  rootFrame=rootFrame or self.Root.CFrame
  for _,entry in ipairs(self.Entries)do local pose=self:LocalFrame(entry.Part,t);if pose then apply(entry,pose,rootFrame,move)end end
  self:Pulse(t)
 end
 function state:Reset()
  if not bag.Parent or not self.Root.Parent then return end
  for _,entry in ipairs(self.Entries)do if live(entry.Part)then apply(entry,entry.Rest,self.Root.CFrame)end end
  for _,entry in ipairs(self.Colors)do if live(entry.Part)then entry.Part.Color=entry.Color end end
 end
 return state
end
return A
