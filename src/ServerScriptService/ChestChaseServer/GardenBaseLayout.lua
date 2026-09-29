-- One static layout per base. Plot identities and planting frames are never moved.
local L={}
local function part(parent,name,size,frame,color,material,collide)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.Wood;p.Anchored=true;p.CanCollide=collide==true;p.CanTouch=false;p.CanQuery=collide==true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local function rounded(n)return math.round(n*1000)/1000 end
local function add(lines,at,a,b)
 at=rounded(at);a=rounded(a);b=rounded(b);lines[at]=lines[at]or{};table.insert(lines[at],{a,b})
end
local function merge(lines)
 for at,spans in pairs(lines)do
  table.sort(spans,function(a,b)return a[1]<b[1]end);local out={}
  for _,s in ipairs(spans)do local last=out[#out]
   if last and s[1]<=last[2]+.002 then last[2]=math.max(last[2],s[2])else table.insert(out,{s[1],s[2]})end
  end
  lines[at]=out
 end
end
function L.Base(base)
 if base:FindFirstChild('GardenDesign36')then
  local fence=base:FindFirstChild('GardenFence34');require(script.Parent.GardenFenceArt).Build(base,fence and fence:GetAttribute('Tier')or 1);return
 end
 local pad=assert(base:FindFirstChild('Pad'),'Garden pad missing');local plots=assert(base:FindFirstChild('GardenPlots'),'Garden plots missing')
 local cf=pad.CFrame;local ground=pad.Size.Y/2;local top=ground
 -- Retire the old reserve, its rails and the earlier decorative layout together.
 for _,name in ipairs({'GardenLayout32','GardenDesign34','GardenBedBorders'})do local old=base:FindFirstChild(name);if old then old:Destroy()end end
 local design=Instance.new('Folder');design.Name='GardenDesign36';design.Parent=base
 local trim=Instance.new('Folder');trim.Name='GardenBedBorders';trim.Parent=base
 local rects={};local byPlot={}
 for _,plot in ipairs(plots:GetChildren())do if plot:IsA('BasePart')then
  local at=cf:PointToObjectSpace(plot.Position);local r={X0=rounded(at.X-plot.Size.X/2),X1=rounded(at.X+plot.Size.X/2),Z0=rounded(at.Z-plot.Size.Z/2),Z1=rounded(at.Z+plot.Size.Z/2)}
  top=math.max(top,at.Y+plot.Size.Y/2);table.insert(rects,r);byPlot[plot.Name]=r
 end end
 -- Finish the three-stud front-left recess at the same edge as the right bed.
 -- This is a visual infill; the saved plot and crop coordinates stay unchanged.
 local left,right=byPlot.DirtPlot_5,byPlot.DirtPlot_9
 if left and right and right.Z1>left.Z1+.01 then
  local source=plots.DirtPlot_5;local y=cf:PointToObjectSpace(source.Position).Y
  part(design,'Soil edge finish',Vector3.new(source.Size.X,source.Size.Y,right.Z1-left.Z1),cf*CFrame.new((left.X0+left.X1)/2,y,(left.Z1+right.Z1)/2),source.Color,source.Material,false)
  left.Z1=right.Z1
 end
 local hLines,vLines={},{}
 for _,r in ipairs(rects)do
  add(hLines,r.Z0,r.X0,r.X1);add(hLines,r.Z1,r.X0,r.X1)
  add(vLines,r.X0,r.Z0,r.Z1);add(vLines,r.X1,r.Z0,r.Z1)
 end
 merge(hLines);merge(vLines)
 local thickness=.6;local half=thickness/2;local bottom=ground-.04;local height=top+.22-bottom;local y=bottom+height/2
 local wood=Color3.fromRGB(145,109,69)
 for z,spans in pairs(hLines)do for _,s in ipairs(spans)do
  part(trim,'Bed divider',Vector3.new(s[2]-s[1]+thickness,height,thickness),cf*CFrame.new((s[1]+s[2])/2,y,z),wood)
 end end
 -- Vertical pieces stop at horizontal edges, producing flush corners without doubled top faces.
 for x,spans in pairs(vLines)do for _,s in ipairs(spans)do
  local pieces={{s[1],s[2]}}
  for z,rows in pairs(hLines)do for _,row in ipairs(rows)do if x>=row[1]-.001 and x<=row[2]+.001 then
   local nextPieces={}
   for _,p in ipairs(pieces)do
    if z+half<=p[1] or z-half>=p[2]then table.insert(nextPieces,p)
    else
     if z-half>p[1]+.001 then table.insert(nextPieces,{p[1],z-half})end
     if z+half<p[2]-.001 then table.insert(nextPieces,{z+half,p[2]})end
    end
   end
   pieces=nextPieces
  end end end
  for _,p in ipairs(pieces)do if p[2]-p[1]>.001 then
   part(trim,'Bed divider',Vector3.new(thickness,height,p[2]-p[1]),cf*CFrame.new(x,y,(p[1]+p[2])/2),wood)
  end end
 end end
 part(design,'Treadmill apron',Vector3.new(17,.18,22),cf*CFrame.new(-34,ground+.09,75),Color3.fromRGB(105,117,106),Enum.Material.Slate,false)
 for _,z in ipairs({81,69,55,40,25,10,-5,-20,-35,-49})do
  part(design,'Aisle paver',Vector3.new(17,.16,10),cf*CFrame.new(0,ground+.08,z),Color3.fromRGB(163,158,136),Enum.Material.Cobblestone,false)
 end
 require(script.Parent.GardenFenceArt).Build(base,1)
end
L.Design=L.Base
local function restoreExpandedHub(map)
 if not map:GetAttribute('GardenLayout32')then return end
 local amount=42
 for _,name in ipairs({'ChestChaseWalls','InvisibleMapBarriersV071','GardenHubDesign'})do
  local folder=map:FindFirstChild(name)
  if folder then for _,p in ipairs(folder:GetDescendants())do if p:IsA('BasePart')then
   local n=p.Name;local dx,dz=0,0;local x,z=p.Size.X,p.Size.Z
   if n:find('LobbyLeftWall',1,true)then dx=-amount;dz=-amount/2;z-=amount
   elseif n:find('LobbyRightWall',1,true)then dx=amount;dz=-amount/2;z-=amount
   elseif n:find('LobbyBackWall',1,true)then dz=-amount;x-=amount*2
   elseif n:find('LobbyFrontWallLeft',1,true)then dx=-amount/2;x-=amount
   elseif n:find('LobbyFrontWallRight',1,true)then dx=amount/2;x-=amount end
   if dx~=0 or dz~=0 then p.Size=Vector3.new(x,p.Size.Y,z);p.CFrame=CFrame.new(-dx,0,-dz)*p.CFrame end
  end end end
 end
 local lobby=map:FindFirstChild('Lobby');local floor=lobby and lobby:FindFirstChild('LobbyFloor')
 if floor then floor.Size-=Vector3.new(amount*2,0,amount);floor.CFrame=CFrame.new(0,0,amount/2)*floor.CFrame end
 map:SetAttribute('GardenLayout32',nil);map:SetAttribute('GardenDesign34',nil)
end
function L.Apply(map)
 if not map:GetAttribute('GardenDesign36')then restoreExpandedHub(map)end
 for _,base in ipairs(assert(map:FindFirstChild('Bases'),'Bases missing'):GetChildren())do if base:IsA('Model')and base:GetAttribute('BaseIndex')then L.Base(base)end end
 map:SetAttribute('GardenDesign36',true)
end
return L
