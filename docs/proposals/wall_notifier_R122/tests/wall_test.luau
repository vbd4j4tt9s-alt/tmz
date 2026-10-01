--!nocheck
local R=require('./roblox');local Bn=require('./wall_bundle')
local new=R.new;local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local game=new('DataModel');local services={}
local function service(n)local s=services[n];if not s then s=new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
function game.GetService(_,n)return service(n)end
local workspace=service('Workspace');local RS=service('ReplicatedStorage');local Run=service('RunService');Run.RenderStepped=R.signal();Run.Heartbeat=R.signal()
local now=1000;function workspace.GetServerTimeNow()return now end
local camera=new('Camera');camera.CFrame=R.CFrame.new(0,15,-140);workspace.CurrentCamera=camera
local Players=service('Players');local player=new('Player');player.Parent=Players;Players.LocalPlayer=player;local pg=new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local Lighting=service('Lighting');service('SoundService');service('ContentProvider').PreloadAsync=function()end
local modules={}
local function module(name,value,src)local m=new('ModuleScript');m.Name=name;m.Parent=RS;modules[m]={Value=value,Src=src};return m end
local env
local function load(src,sc)local fn=assert(loadstring(Bn[src],'='..src));setfenv(fn,setmetatable({script=sc},{__index=env}));return fn()end
local function req(m)local e=modules[m];if not e then error('unknown module '..tostring(m))end;if e.Value==nil then e.Value=load(e.Src,m)end;return e.Value end
module('RefreshBarrier',nil,'RefreshBarrier');module('RefreshCountdown',nil,'RefreshCountdown')
local skyBegun=0
module('RefreshSky',{Begin=function()skyBegun+=1;return function()end end,Destroy=function()end})
module('TrackBlackout',nil,'TrackBlackout')
local moonAttached={}
module('HudArtwork',{Attach=function(parent,kind)local f=new('Frame');f.Name='Generated'..kind;f.Size=R.UDim2.fromScale(1,1);f.Parent=parent;moonAttached[#moonAttached+1]={parent,kind};return f end})
module('RefreshHorn',{New=function()return {Play=function()return true end,Stop=function()end,Destroy=function()end}end})
module('AudioMixer',{Group=function()return nil end})
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,UDim=R.UDim,UDim2=R.UDim2,Color3=R.Color3,Enum=R.Enum,typeof=R.typeof,task=R.task,require=req,os={clock=function()return R.clock end}},{__index=_G})
-- Server side: MapService.SetBiomeRefreshing path
local map=new('Folder');map.Name='ChestChaseMap';map.Parent=workspace
local runtime=new('Folder');runtime.Name='_GameplayRuntime';runtime.Parent=map
local line=new('Part');line.Size=R.Vector3.new(180,.24,1);line.CFrame=R.CFrame.new(0,4.12,-99.275)
local Bar=req(RS.RefreshBarrier)
local wall,labels=Bar.Build(line,-100,runtime)
check(wall.Name=='BiomeRefreshWall'and wall.Parent==runtime,'wall parented')
-- R122: track-sized wall. Track: 180 field, side walls 5 thick at x=±91.5 (outer ±94), 48 tall (top Y 51).
check(wall.Size.X==188 and wall.Size.Z==4,'wall spans the track incl. side walls (got '..wall.Size.X..')')
check(wall.Size.Y>=48 and wall.Size.Y<=60,'wall height bounded to about the track walls (got '..wall.Size.Y..')')
local wb=wall.CFrame.Position.Y-wall.Size.Y/2;local wt=wall.CFrame.Position.Y+wall.Size.Y/2
check(math.abs(wb-(4.12-1))<1e-6,'wall bottom unchanged at line.Y-1 (got '..wb..')')
check(wt>=51+1,'wall top above track side walls (got '..wt..')')
check(wall.CFrame.Position.Z==-100 and wall.CFrame.Position.X==0,'wall Z/X placement unchanged')
-- still blocks the entrance: covers the whole 180 field opening and is far above jump height
check(wall.CFrame.Position.X-wall.Size.X/2<=-94 and wall.CFrame.Position.X+wall.Size.X/2>=94,'wall covers entrance to the outer side-wall edge')
check(wt-4>=40,'wall top far above default jump (7.2) from ground Y 4')
check(wall.CanCollide==true and wall.Anchored==true and wall.CanQuery==true and wall.CanTouch==false,'collision flags unchanged')
check(wall:GetAttribute('BiomeRefreshBarrier')==true,'barrier attribute')
local colliders=0;for _,d in ipairs(wall:GetDescendants())do if d:IsA('BasePart')then colliders+=1 end end
check(colliders==0,'no extra parts on the wall')
-- sign fits inside the smaller canvas
for _,g in ipairs(wall:GetChildren())do if g:IsA('SurfaceGui')then
 local cv=g.CanvasSize;local sg=g.NightSign.Sign
 check(cv.X==math.floor(188*Bar.PixelsPerStud)and cv.Y==math.floor(wall.Size.Y*Bar.PixelsPerStud),'canvas follows wall size')
 local cy=(1-Bar.SignHeight)*cv.Y
 check(sg.Size.X.Offset<=cv.X and cy-sg.Size.Y.Offset/2>=0 and cy+sg.Size.Y.Offset/2<=cv.Y,'sign inside the canvas')
 check(sg:FindFirstChild('MoonIcon')and #sg.MoonIcon:GetChildren()==0,'server builds an empty moon slot (no hand-drawn moon)')
 local legacy=0;for _,d in ipairs(g:GetDescendants())do if d.Name=='Cloud'or d.Name=='CloudEdge'or d.Name=='Crescent'or d.Name=='Bite'then legacy+=1 end end
 check(legacy==0,'hand-drawn moon/cloud removed')
 local c=sg.Count;local glyph=c.Size.Y.Offset*c.UIScale.Scale
 check(glyph>=200 and glyph/Bar.PixelsPerStud>=25,'countdown still big: '..glyph..' px = '..glyph/Bar.PixelsPerStud..' studs')
 check(c.Position.X.Offset+c.Size.X.Offset*c.UIScale.Scale<=sg.Size.X.Offset+1,'count fits in sign')
 check(sg.MoonIcon.Position.Y.Offset>=0 and sg.MoonIcon.Position.Y.Offset+sg.MoonIcon.Size.Y.Offset<=sg.Size.Y.Offset,'moon fits in sign')
end end
check(#labels==2,'two faces')
for _,l in ipairs(labels)do l.Text=tostring(math.max(0,math.ceil(10)))end -- MapService line 593
local faces={}
for _,g in ipairs(wall:GetChildren())do if g:IsA('SurfaceGui')then faces[#faces+1]=g end end
check(#faces==2 and faces[1].Face~=faces[2].Face,'front and back SurfaceGuis')
local count=faces[1].NightSign.Sign.Count
check(count.Text=='10s','server write formatted as 10s (got '..count.Text..')')
for _,l in ipairs(labels)do l.Text='7' end;check(count.Text=='7s','proxy formats 7s')
-- Client: real TrackRefreshSky paints from the deadline
map:SetAttribute('BiomeRefreshEndsAt',now+10);map:SetAttribute('BiomesRefreshing',true)
local sc=new('LocalScript');sc.Name='TrackRefreshSky';load('TrackRefreshSky',sc)
check(skyBegun==1,'sky began')
R.advance(.2);Run.RenderStepped:Fire(.1)
check(#moonAttached==2 and moonAttached[1][2]=='Moon' and moonAttached[1][1].Name=='MoonIcon','client attached HudArtwork Moon on both faces (got '..#moonAttached..')')
for _,g in ipairs(wall:GetChildren())do if g:IsA('SurfaceGui')then check(g.NightSign.Sign.MoonIcon:FindFirstChild('GeneratedMoon'),'moon image in sign')end end
check(Bar.Decorate(wall)~=nil and #moonAttached==2,'re-decorate does not duplicate the moon')
local seen={}
for i=0,110 do now=1000+i*.1;R.advance(.1);Run.RenderStepped:Fire(.1)
 seen[faces[1].NightSign.Sign.Count.Text]=true
 check(faces[2].NightSign.Sign.Count.Text==faces[1].NightSign.Sign.Count.Text,'faces agree')
 if i==5 then check(count.Text=='10s','at 0.5 s shows 10s (got '..count.Text..')')end
 if i==72 then check(count.Text=='3s','at 7.2 s shows 3s (got '..count.Text..')')end
end
for n=0,10 do check(seen[n..'s'],'showed '..n..'s')end
print(('wall checks %d, fails %d'):format(checks,fails))
-- Dump GUI tree of the front face for rendering (absolute canvas px).
local out={}
local function abs(o,px,py)
 local p,s=o.Position,o.Size;local w,h
 local pw,ph=o.Parent._w or 0,o.Parent._h or 0
 w=s.X.Scale*pw+s.X.Offset;h=s.Y.Scale*ph+s.Y.Offset
 local ap=o.AnchorPoint or R.Vector2.new(0,0)
 local x=px+p.X.Scale*pw+p.X.Offset-ap.X*w;local y=py+p.Y.Scale*ph+p.Y.Offset-ap.Y*h
 return x,y,w,h
end
local function walk(o,px,py,clip,depth)
 for _,c in ipairs(o:GetChildren())do
  if c._class=='Frame'or c._class=='TextLabel'then
   local x,y,w,h=abs(c,px,py);c._w=w;c._h=h
   local round,st,sc=nil,nil,nil
   for _,k in ipairs(c:GetChildren())do if k._class=='UICorner'then round=k.CornerRadius.Scale>0 and 'circle' or k.CornerRadius.Offset end;if k._class=='UIStroke'then st=k.Thickness end;if k._class=='UIScale'then sc=k.Scale end end
   local col=c.BackgroundColor3
   table.insert(out,string.format('{"n":"%s","k":"%s","x":%.1f,"y":%.1f,"w":%.1f,"h":%.1f,"z":%d,"d":%d,"bg":%s,"round":%s,"stroke":%s,"clip":%s,"text":%s,"scale":%s,"clipsSelf":%s}',
    c.Name,c._class,x,y,w,h,c.ZIndex or 1,depth,(c.BackgroundTransparency or 0)<1 and col and string.format('[%d,%d,%d]',col.R*255,col.G*255,col.B*255) or 'null',
    round and (round=='circle' and '"circle"' or tostring(round)) or 'null',st or 'null',clip and string.format('[%.1f,%.1f,%.1f,%.1f]',clip[1],clip[2],clip[3],clip[4]) or 'null',
    c._class=='TextLabel' and ('"'..c.Text..'"') or 'null',sc or 'null',c.ClipsDescendants and 'true' or 'false'))
   walk(c,x,y,c.ClipsDescendants and {x,y,w,h} or clip,depth+1)
  end
 end
end
local gui=faces[1];gui._w=gui.CanvasSize.X;gui._h=gui.CanvasSize.Y
walk(gui,0,0,nil,0)
print('JSON {"canvas":['..gui.CanvasSize.X..','..gui.CanvasSize.Y..'],"items":['..table.concat(out,',')..']}')
