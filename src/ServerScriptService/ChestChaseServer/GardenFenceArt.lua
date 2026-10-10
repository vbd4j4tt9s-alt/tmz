-- Static native geometry; all skins share the same boundary and open entrance.
local Rules=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenFenceRules'))
local Shadow=require(game:GetService('ReplicatedStorage'):WaitForChild('SmallShadow154')) -- R154 (lag audit B1): a part under 1.5 studs casts no shadow
local Players=game:GetService('Players')
local thumbnails={}
local A={};local V,CF=Vector3.new,CFrame.new;local RGB=Color3.fromRGB
local themes={
 {Body=RGB(125,85,52),Trim=RGB(217,183,128),Accent=RGB(94,138,75),Material=Enum.Material.Wood},
 {Body=RGB(106,116,96),Trim=RGB(155,167,133),Accent=RGB(75,115,65),Material=Enum.Material.Cobblestone},
 {Body=RGB(197,146,91),Trim=RGB(237,201,142),Accent=RGB(135,82,59),Material=Enum.Material.Sandstone},
 {Body=RGB(112,166,190),Trim=RGB(197,234,241),Accent=RGB(168,224,247),Material=Enum.Material.Ice},
 {Body=RGB(113,94,150),Trim=RGB(199,169,238),Accent=RGB(130,224,220),Material=Enum.Material.Slate},
 {Body=RGB(65,60,70),Trim=RGB(103,84,82),Accent=RGB(253,136,66),Material=Enum.Material.Basalt},
 {Body=RGB(47,60,77),Trim=RGB(116,145,161),Accent=RGB(117,219,246),Material=Enum.Material.Metal},
}
local function part(parent,name,size,cf,color,material,collide,class)
 local p=Instance.new(class or'Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=Shadow.Keeps(size);p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
-- R131 (owner): the badges were a fixed 210x128 px drawn on top of everything, so from a distance one covered the
-- garden under it and gardens in front of it. Now the size is in studs (11 x 7) plus a small pixel floor, so a badge
-- shrinks with distance like the garden below it, and nearer things are drawn over it. With no avatar picture (Studio
-- test players), only the name shows instead of a blank circle. Older badges are restyled when the owner updates.
local BADGE_REVISION=131
local function styleBadge(gui)
 if gui:GetAttribute('BadgeRevision')==BADGE_REVISION then return end
 gui:SetAttribute('BadgeRevision',BADGE_REVISION)
 gui.Size=UDim2.new(11,34,7,22);gui.AlwaysOnTop=false
 local portrait=gui:FindFirstChild('Portrait')
 if portrait then
  portrait.AnchorPoint=Vector2.new(.5,0);portrait.Position=UDim2.fromScale(.5,.02);portrait.Size=UDim2.fromScale(.6,.6)
  local square=portrait:FindFirstChildOfClass('UIAspectRatioConstraint')or Instance.new('UIAspectRatioConstraint')
  square.AspectRatio=1;square.DominantAxis=Enum.DominantAxis.Height;square.Parent=portrait
  local outline=portrait:FindFirstChildOfClass('UIStroke');if outline then outline.Thickness=2 end
 end
 local name=gui:FindFirstChild('OwnerName');if name then name.Position=UDim2.fromScale(0,.64);name.Size=UDim2.fromScale(1,.34)end
end
-- R99: a fixed high landmark; exceptional plants never move the owner marker.
local function ownerBadge(base,root,pad,front)
 local anchor=part(root,'Owner marker',V(.1,.1,.1),pad.CFrame*CF(0,pad.Size.Y/2+64,front),RGB(255,255,255))
 anchor.Transparency=1;anchor.CastShadow=false
 local gui=Instance.new('BillboardGui');gui.Name='GardenOwnerBadge';gui.Adornee=anchor;gui.Size=UDim2.fromOffset(210,128);gui.AlwaysOnTop=true;gui.LightInfluence=0;gui.MaxDistance=850;gui.Enabled=false;gui.Parent=anchor
 local portrait=Instance.new('ImageLabel');portrait.Name='Portrait';portrait.AnchorPoint=Vector2.new(.5,0);portrait.Position=UDim2.new(.5,0,0,3);portrait.Size=UDim2.fromOffset(78,78);portrait.BackgroundColor3=RGB(221,231,218);portrait.BorderSizePixel=0;portrait.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(1,0);corner.Parent=portrait
 local outline=Instance.new('UIStroke');outline.Thickness=3;outline.Color=RGB(27,32,38);outline.Parent=portrait
 local name=Instance.new('TextLabel');name.Name='OwnerName';name.Position=UDim2.fromOffset(4,85);name.Size=UDim2.new(1,-8,0,38);name.BackgroundTransparency=1;name.Font=Enum.Font.FredokaOne;name.TextColor3=RGB(255,255,255);name.TextScaled=true;name.TextWrapped=false;name.RichText=false;name.TextTruncate=Enum.TextTruncate.AtEnd;name.Parent=gui
 local edge=Instance.new('UIStroke');edge.Thickness=2;edge.Color=RGB(24,29,36);edge.Parent=name
 local fit=Instance.new('UITextSizeConstraint');fit.MinTextSize=10;fit.MaxTextSize=28;fit.Parent=name
 styleBadge(gui)
 return gui
end
function A.UpdateOwner(base,displayName)
 if displayName~=nil then base:SetAttribute('BaseOwnerDisplayName',displayName)end
 local root=base:FindFirstChild('GardenFence34');local gui=root and root:FindFirstChild('GardenOwnerBadge',true)
 if not gui then return end
 local name=base:GetAttribute('BaseOwnerDisplayName')or'';local id=base:GetAttribute('BaseOwnerUserId')or 0
 styleBadge(gui)
 gui.Enabled=name~='';gui.OwnerName.Text=name;gui.Portrait.Visible=id>0;gui.OwnerName.Position=UDim2.fromScale(0,id>0 and .64 or .33)
 -- Names stay readable even while Roblox is preparing a new portrait.
 if gui:GetAttribute('PortraitUserId')==id then return end
 gui:SetAttribute('PortraitUserId',id)
 local portrait=gui.Portrait;portrait.Image=id>0 and('rbxthumb://type=AvatarHeadShot&id='..id..'&w=150&h=150')or''
 if id<=0 then return end
 if thumbnails[id]then portrait.Image=thumbnails[id];return end
 task.spawn(function()
  for attempt=1,3 do
   if not gui.Parent or base:GetAttribute('BaseOwnerUserId')~=id then return end
   local okay,url,ready=pcall(Players.GetUserThumbnailAsync,Players,id,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
   if okay and ready and type(url)=='string'and url~=''then
    thumbnails[id]=url
    if gui.Parent and base:GetAttribute('BaseOwnerUserId')==id then portrait.Image=url end
    return
   end
   if attempt<3 then task.wait(attempt*2)end
  end
 end)
end
function A.Build(base,level)
 level=Rules.Level(level);local existing=base:FindFirstChild('GardenFence34')
 if existing and existing:GetAttribute('Tier')==level and existing:GetAttribute('DesignRevision')==99 then require(game:GetService('ReplicatedStorage').WalkthroughProps90).Model(existing,false);A.UpdateOwner(base);return existing end
 local pad=assert(base:FindFirstChild('Pad'));local cf=pad.CFrame*CF(0,pad.Size.Y/2,0);local theme=themes[level]
 local root=Instance.new('Model');root.Name='GardenFence34';root:SetAttribute('Tier',level);root:SetAttribute('DesignRevision',99)
 local function p(name,size,frame,color,material,collide,class)return part(root,name,size,cf*frame,color or theme.Body,material or theme.Material,collide,class)end
 -- The soil keeps its saved footprint. Fence feet sit outside its trim on a grounded sill.
 local side=pad.Size.X/2+2;local back=-pad.Size.Z/2-2;local front=pad.Size.Z/2-2
 -- R149: the sill stands .08 above the pad (was .02: the front sills lie on the pad and flickered against it).
 local depth=pad.Size.Y+.08;local footingY=(.08-pad.Size.Y)/2
 -- R154: the side sills stop at the front and back sills (they ran under them: Slate is a textured material, so the overlapping corners flickered
 -- even in one colour); the sills' outline and collision are unchanged.
 for _,sign in ipairs({-1,1})do
  p('Fence foundation',V(3.2,depth,front-back-3.8),CF(sign*side,footingY,(back+front)/2-.3),theme.Body,Enum.Material.Slate,true)
  p('Fence foundation',V(side-16+3.8,depth,4.4),CF(sign*(side+16-.6)/2,footingY,front),theme.Body,Enum.Material.Slate,true)
 end
 p('Fence foundation',V(side*2+3.2,depth,3.2),CF(0,footingY,back),theme.Body,Enum.Material.Slate,true)
 local posts={}
 local function post(x,z,gate)
  local key=x..':'..z;if posts[key]then return end;posts[key]=true
  local h=gate and 8 or level==1 and 4.4 or 4.8
  p('Footing',V(gate and 4 or 2.8,gate and 2.2 or .65,gate and 4 or 2.8),CF(x,gate and 1.1 or .325,z),theme.Trim,level==1 and Enum.Material.Slate or theme.Material,true)
  p(gate and'Entrance pillar'or'Fence pillar',V(gate and 2.4 or 1.75,h,gate and 2.4 or 1.75),CF(x,h/2+.4,z),nil,nil,true)
  p('Pillar cap',V(gate and 3.6 or 2.5,.45,gate and 3.6 or 2.5),CF(x,h+.65,z),theme.Trim)
  if level>=4 then
   p('Element inset',V(.55,gate and 2.6 or 1.3,.08),CF(x,h*.66,z+.915),theme.Accent,Enum.Material.Neon)
  elseif level==2 then p('Moss cap',V(2.25,.15,1.9),CF(x+.1,h+.94,z),theme.Accent,Enum.Material.Grass)end
 end
 local function span(a,b)
  post(a.X,a.Z);post(b.X,b.Z)
  local length=(b-a).Magnitude;local mid=(a+b)/2;local frame=CF(mid)*CFrame.Angles(0,math.atan2(-(b.Z-a.Z),b.X-a.X),0)
  if level==1 then
   for _,h in ipairs({1.35,3.05})do p('Wood rail',V(length-1.2,.58,.65),frame*CF(0,h,0),theme.Trim,nil,true)end
   p('Rail brace',V(length*.47,.34,.35),frame*CF(0,2.2,.05)*CFrame.Angles(0,0,.16),theme.Body)
  else
   p('Wall panel',V(length-1.5,2.45,1.15),frame*CF(0,1.65,0),nil,nil,true)
   p('Wall coping',V(length-1.2,.40,1.5),frame*CF(0,3.1,0),theme.Trim)
   if level==7 then
    p('Electric panel inset',V(length-3.5,1.3,.08),frame*CF(0,1.75,.61),RGB(31,46,59),Enum.Material.Metal)
    p('Electric light strip',V(length-4,.10,.09),frame*CF(0,2.1,.67),theme.Accent,Enum.Material.Neon)
    p('Panel contact',V(.35,.8,.12),frame*CF(length*.22,1.72,.69),RGB(245,209,113),Enum.Material.Metal) -- R149: 1.72 (its top was the light strip's top)
   elseif level==6 then p('Lava channel',V(length-3,.12,.09),frame*CF(0,1.2,.61),theme.Accent,Enum.Material.Neon)
   elseif level==5 then
    for _,x in ipairs({-.22,.22})do p('Crystal inset',V(.85,1.25,.14),frame*CF(length*x,1.75,.63)*CFrame.Angles(0,0,math.pi/4),theme.Accent,Enum.Material.Neon)end
   elseif level==4 then p('Snow ledge',V(length-1.1,.18,1.6),frame*CF(0,3.38,0),RGB(232,247,249),Enum.Material.Snow)
   elseif level==2 then p('Moss seam',V(length*.44,.22,.09),frame*CF(-length*.13,2.55,.61),theme.Accent,Enum.Material.Grass)
   else p('Sandstone band',V(length-2.2,.25,.09),frame*CF(0,1.8,.61),theme.Accent)end
  end
 end
 local zs={back,-60,-30,0,30,60,front}
 for _,sign in ipairs({-1,1})do for i=1,#zs-1 do span(V(sign*side,0,zs[i]),V(sign*side,0,zs[i+1]))end end
 for i=0,5 do span(V(-side+i*side/3,0,back),V(-side+(i+1)*side/3,0,back))end
 for _,sign in ipairs({-1,1})do span(V(sign*side,0,front),V(sign*(side+16)/2,0,front));span(V(sign*(side+16)/2,0,front),V(sign*16,0,front))end
 -- The 32-stud opening itself stays clear (no posts, beam or roof inside it). R151 (owner approved): HubDecor151 stands a name arch
 -- just outside it - two posts beside the opening and a beam 14 studs over the pad with the owner's name.
 ownerBadge(base,root,pad,front)
 -- Compact framed plaque mounted on the entrance's right fence span.
 local boardFrame=CF(35,5.6,front-1.3)*CFrame.Angles(math.rad(10),math.pi,0)
 p('Garden bonus frame',V(20.8,6.0,.6),boardFrame,theme.Trim)
 local bonus=p('Garden bonus board',V(20,5.45,.25),boardFrame*CF(0,0,.34),RGB(33,57,44),Enum.Material.Wood)
 bonus:SetAttribute('GardenBonusSign84',true)
 for _,x in ipairs({27,43})do p('Bonus sign bracket',V(.5,2.6,.65),CF(x,3.1,front-.95),theme.Body)end
 root.Parent=base;if existing then existing:Destroy()end;A.UpdateOwner(base)
 local old=base:FindFirstChild('PerimeterFence');if old then old:Destroy()end
 return root
end
return A
