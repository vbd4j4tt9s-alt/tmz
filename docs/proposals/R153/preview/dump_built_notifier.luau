--!nocheck
-- R153: runs the REAL BiomeEntryNotifier (+ HudNoticeLayout, BiomeTitleStyle, BiomeMood) on the Roblox mock for every biome on three screens and prints ONE line, "JSON {...}", with the
-- numbers the built-notifier preview draws: box sizes, text sizes and positions, UIStroke thickness / colour, the shadow copies, the HudNoticeLayout row, the fade / settle timeline, the sky colours.
-- (Text widths come from the mock's TextService, 0.52 x size per character; the preview measures them again with its stand-in fonts.) Usage: see run_biome_notifier_built.sh
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.CharacterAdded=R.signal();me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local order={1,6,2,3,4,5,7};local starts={}
for i,id in ipairs(order)do starts[id]=(i-1)*200;map:SetAttribute('BiomeStartZ_'..id,(i-1)*200);map:SetAttribute('BiomeEndZ_'..id,i*200)end
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,190);root.Parent=char
local hum=R.new('Humanoid');hum.Health=100;hum.WalkSpeed=16;hum.MoveDirection=V3(0,0,1);hum.Parent=char
local function screen(w,h)W.Gui.GetInsetArea=function()return {Min=R.Vector2.new(0,0),Width=w,Height=h}end end
screen(1280,676)
W.load('BiomeEntryNotifier',R.new('LocalScript'))
local gui=pg:FindFirstChild('BiomeEntryUI');local group=gui:FindFirstChild('BiomeTitle');local content=group:FindFirstChild('Content')
local Styles=W.module('BiomeTitleStyle');local Notice=W.module('HudNoticeLayout');local Mood=W.module('BiomeMood')
local function enter(stage)
 me.CharacterAdded:Fire(char);hum.MoveDirection=V3(0,0,1);local z=starts[stage]-8;root.CFrame=CF(0,3,z);W.frames(10)
 for _=1,90 do z+=16/60;root.CFrame=CF(0,3,z);W.frames(1);if group.Visible then return true end end
 return false
end
local function c3(c)return {math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)}end
-- tiny JSON encoder (keys sorted, numbers rounded to 4 places)
local function enc(v)
 local t=type(v)
 if t=='number'then return tostring(math.floor(v*10000+.5)/10000)
 elseif t=='string'then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"'
 elseif t=='boolean'then return tostring(v)
 elseif t=='table'then
  if #v>0 or next(v)==nil then local o={};for i,x in ipairs(v)do o[i]=enc(x)end;return '['..table.concat(o,',')..']' end
  local keys={};for k in pairs(v)do keys[#keys+1]=tostring(k)end;table.sort(keys)
  local o={};for _,k in ipairs(keys)do o[#o+1]=enc(k)..':'..enc(v[k]==nil and v[tonumber(k)]or v[k])end;return '{'..table.concat(o,',')..'}'
 end
 return 'null'
end
local function line(l,edge)
 return {Text=l.Text,Font=l.Font.Name,Size=l.TextSize,X=l.Position.X.Offset,Y=l.Position.Y.Offset,W=l.Size.X.Offset,H=l.Size.Y.Offset,Color=c3(l.TextColor3),TextT=l.TextTransparency,
  Edge={Thickness=edge.Thickness,Color=c3(edge.Color),T=edge.Transparency},Z=l.ZIndex}
end
local function snapshot(stage)
 local cap,title=group:FindFirstChild('Caption',true),group:FindFirstChild('BiomeName',true)
 local capSh,titleSh=group:FindFirstChild('CaptionShadow',true),group:FindFirstChild('NameShadow',true)
 local vw,vh=W.Gui:GetInsetArea().Width,W.Gui:GetInsetArea().Height
 local row=Notice.Calculate(vw,vh,0,{Biome=true}).Biome
 return {Stage=stage,Label=Styles[stage].Label,Group={W=group.Size.X.Offset,H=group.Size.Y.Offset,X=group.Position.X.Offset,Y=group.Position.Y.Offset},
  Row={X=row.X,Y=row.Y,W=row.Width,H=row.Height},Caption=line(cap,cap:FindFirstChild('Edge')),CaptionShadow=line(capSh,capSh:FindFirstChild('Edge')),
  Name=line(title,title:FindFirstChild('Edge')),NameShadow=line(titleSh,titleSh:FindFirstChild('Edge'))}
end
local out={Devices={},Skies={},Timeline={},Styles={}}
for _,id in ipairs(order)do out.Styles[tostring(id)]={Label=Styles[id].Label,Name=Styles[id].Name,Color=c3(Styles[id].Color)}end
for id,p in pairs(Mood.Profiles)do out.Skies[tostring(id)]={Name=p.Name,Air=c3(p.Air.Color),Decay=c3(p.Air.Decay)}end
-- screens as the preview draws them: a 44 px top bar above the safe area
for _,d in ipairs({{'pc',1280,720},{'land',844,390},{'port',390,844}})do
 local key,w,h=d[1],d[2],d[3];screen(w,h-44)
 local dev={W=w,H=h,SafeW=w,SafeH=h-44,Biomes={}}
 for _,id in ipairs(order)do
  if not enter(id)then error('no title for '..id)end
  W.frames(40);dev.Biomes[tostring(id)]=snapshot(id)
 end
 out.Devices[key]=dev
end
-- the fade / settle timeline on PC (Storm Peaks), normal and with Reduced Motion, one sample per frame (1/60 s) from the frame the title appears
local function timeline(reduced)
 W.Gui.ReducedMotionEnabled=reduced;screen(1280,676)
 me.CharacterAdded:Fire(char);hum.MoveDirection=V3(0,0,1);local z=starts[7]-8;root.CFrame=CF(0,3,z);W.frames(10);local t0;local s={}
 for _=1,60*6 do
  z+=16/60;root.CFrame=CF(0,3,z);W.frames(1)
  if group.Visible and not t0 then t0=R.clock end
  if t0 then
   s[#s+1]={T=R.clock-t0,Visible=group.Visible,Y=content.Position.Y.Offset,NameT=group:FindFirstChild('BiomeName',true).TextTransparency,CapT=group:FindFirstChild('Caption',true).TextTransparency,
    EdgeT=group:FindFirstChild('BiomeName',true):FindFirstChild('Edge').Transparency,ShadeT=group:FindFirstChild('NameShadow',true).TextTransparency,ShadeEdgeT=group:FindFirstChild('NameShadow',true):FindFirstChild('Edge').Transparency,
    CapEdgeT=group:FindFirstChild('Caption',true):FindFirstChild('Edge').Transparency,CapShadeT=group:FindFirstChild('CaptionShadow',true).TextTransparency,CapShadeEdgeT=group:FindFirstChild('CaptionShadow',true):FindFirstChild('Edge').Transparency}
   if not group.Visible then break end
  end
 end
 W.Gui.ReducedMotionEnabled=false;return s
end
out.Timeline.Normal=timeline(false);out.Timeline.Reduced=timeline(true)
local last=out.Timeline.Normal;out.Total=last[#last].T
print('JSON '..enc(out))
