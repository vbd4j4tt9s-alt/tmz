-- V0.79: deterministic, native Roblox geometry. No downloaded assets or scripts.
local Art = {Version = 79}
local V, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local function part(parent, name, size, frame, color, material, class)
    local p = Instance.new(class or "Part")
    p.Name, p.Size, p.CFrame, p.Color = name, size, frame, color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end
-- Closed polygon shells built from right triangular wedges, not flat block tips.
local function triangle(parent, name, a, b, c, color, material)
    local ab, bc, ca = (a-b).Magnitude, (b-c).Magnitude, (c-a).Magnitude
    if ab > bc and ab >= ca then a,b,c = c,a,b
    elseif ca > bc then a,b,c = b,c,a end
    local z = (c-b).Unit
    local d = b + z * (a-b):Dot(z)
    local h = (a-d).Magnitude
    if h < 0.001 then return end
    local x = (a-d).Unit:Cross(z).Unit
    local y = z:Cross(x).Unit
    local left, right = (d-b).Magnitude, (c-d).Magnitude
    if left > 0.001 then
        part(parent,name,V(0.04,h,left),CFrame.fromMatrix((a+b)/2,x,y,z),color,material,"WedgePart")
    end
    if right > 0.001 then
        part(parent,name,V(0.04,h,right),CFrame.fromMatrix((a+c)/2,-x,y,-z),color,material,"WedgePart")
    end
end
local function quad(parent,name,a,b,c,d,color,material)
    triangle(parent,name,a,b,c,color,material); triangle(parent,name,a,c,d,color,material)
end
local function anchor(parent,name,frame)
    local p=part(parent,name,V(0.1,0.1,0.1),frame,RGB(100,100,100))
    p.Transparency=1; p.CastShadow=false
    local a=Instance.new("Attachment"); a.Name="EmitterOrigin"; a.Parent=p
    return a
end
local function emitter(a,name,color,rate,size,speed,smoke)
    local e=Instance.new("ParticleEmitter"); e.Name=name
    e.Texture=smoke and "rbxasset://textures/particles/smoke_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
    e.Color=ColorSequence.new(color)
    e.Rate=rate; e.Lifetime=NumberRange.new(1.8,3.5); e.Speed=NumberRange.new(speed*0.6,speed)
    e.SpreadAngle=Vector2.new(24,24); e.Rotation=NumberRange.new(0,360); e.RotSpeed=NumberRange.new(-16,16)
    e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*0.35),NumberSequenceKeypoint.new(0.6,size),NumberSequenceKeypoint.new(1,size*1.3)})
    e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.8),NumberSequenceKeypoint.new(0.2,smoke and 0.62 or 0.12),NumberSequenceKeypoint.new(1,1)})
    e.LightEmission=smoke and 0 or 0.55; e.LightInfluence=smoke and 0.7 or 0.1
    e.Acceleration=smoke and V(1.5,0.7,0.5) or V(0,0.6,0)
    e:SetAttribute("BiomeEffect",true); e.Parent=a
    return e
end
local function beam(parent,name,a,b,color,width,speed,curve)
    local e=Instance.new("Beam");e.Name=name;e.Attachment0=a;e.Attachment1=b
    e.Color=ColorSequence.new(color);e.Width0=width;e.Width1=width*0.7
    e.Texture="rbxasset://textures/particles/sparkles_main.dds";e.TextureLength=3;e.TextureSpeed=speed
    e.FaceCamera=true;e.LightEmission=0.6;e.LightInfluence=0;e.Segments=10
    e.Transparency=NumberSequence.new(0.35); e.CurveSize0=curve or 0;e.CurveSize1=-(curve or 0)
    e:SetAttribute("BiomeEffect",true);e.Parent=parent;return e
end
local function light(a,color)
    local l=Instance.new("PointLight");l.Color=color;l.Brightness=0.55;l.Range=16;l.Shadows=false;l.Parent=a
end
local function crystal(parent,frame,radius,height,colors,sides)
    sides=sides or 6
    local low,high={},{}
    for i=1,sides do
        local angle=(i-1)*math.pi*2/sides
        low[i]=frame:PointToWorldSpace(V(math.cos(angle)*radius,0,math.sin(angle)*radius))
        high[i]=frame:PointToWorldSpace(V(math.cos(angle)*radius*0.85,height*0.7,math.sin(angle)*radius*0.85))
    end
    local tip=frame:PointToWorldSpace(V(radius*0.12,height,-radius*0.15))
    for i=1,sides do
        local j=i%sides+1
        quad(parent,"CrystalFacet",low[i],low[j],high[j],high[i],colors[(i-1)%#colors+1])
        triangle(parent,"CrystalPoint",high[i],high[j],tip,colors[i%#colors+1])
    end
    return tip
end
local function mountain(parent,origin)
    local rocks={RGB(73,92,108),RGB(92,112,126),RGB(110,128,138),RGB(63,81,96)}
    local snow={RGB(211,222,226),RGB(167,190,203),RGB(194,209,217),RGB(145,171,186)}
    for index,spec in ipairs({{0,3,15,39,0},{-12,-3,11,27,-0.4},{12,-5,10,24,0.4},{3,-12,8,18,0.1}}) do
        local frame=origin*CF(spec[1],0,spec[2])*CFrame.Angles(0,spec[5],0)
        local bottom,edge={},{}
        local tip=frame:PointToWorldSpace(V(1.5,spec[4],-1.8))
        for i=1,7 do
            local theta=i*2*math.pi/7
            local r=spec[3]*(1+0.12*math.sin(i*4+index))
            local snowline=0.51+0.17*((i*3+index)%5)/4
            bottom[i]=frame:PointToWorldSpace(V(math.cos(theta)*r,0,math.sin(theta)*r))
            edge[i]=bottom[i]:Lerp(tip,snowline)
        end
        for i=1,7 do
            local j=i%7+1
            quad(parent,"RockFace",bottom[i],bottom[j],edge[j],edge[i],rocks[(i+index)%#rocks+1],Enum.Material.Slate)
            triangle(parent,"JaggedSnowCap",edge[i],edge[j],tip,snow[(i+index)%#snow+1],Enum.Material.SmoothPlastic)
        end
    end
    local colors={RGB(80,157,179),RGB(137,197,209),RGB(108,180,199)}
    for _,s in ipairs({{-15,-11,1.3,6,-0.25},{14,-12,1.5,8,0.2},{17,-9,0.9,4,0.45}}) do
        crystal(parent,origin*CF(s[1],0,s[2])*CFrame.Angles(0,0,s[5]),s[3],s[4],colors,4)
    end
    local wind=anchor(parent,"SummitWind",origin*CF(2,34,2))
    local e=emitter(wind,"WindblownSnow",RGB(193,211,220),5,0.22,3,false)
    e.Acceleration=V(4,-0.3,1);e.LightEmission=0.05;e.SpreadAngle=Vector2.new(55,55)
end
local function volcano(parent,origin)
    local sizes={42,34,27,20,13}
    for i,size in ipairs(sizes) do
        local y=(i-1)*5.5+2.75
        part(parent,"BasaltTerrace",V(size,5.5,size*.86),origin*CF(0,y,0),RGB(42+i*3,43+i*3,53+i*3),Enum.Material.Slate)
        part(parent,"BrokenBasaltLedge",V(size*.35,3,size*.36),origin*CF(-size*.34,y-1,size*.31)*CFrame.Angles(0,0.12,0),RGB(36+i*3,39+i*3,49+i*3),Enum.Material.Slate)
    end
    -- Open square crater with distinct dark rim and an inset molten surface.
    part(parent,"CraterPool",V(9,.24,8),origin*CF(0,27.62,0),RGB(245,126,32),Enum.Material.Neon)
    for _,s in ipairs({{-5.5,0,2,11},{5.5,0,2,11},{0,4.6,9,1.8}}) do
        part(parent,"CraterRim",V(s[3],1.4,s[4]),origin*CF(s[1],27.8,s[2]),RGB(49,45,49),Enum.Material.Slate)
    end
    local paths={
        {V(0,27.9,-2),V(0,27.9,-6),V(0,22.35,-6.1),V(4,22.35,-8.7),V(4,16.85,-8.8),V(1,16.85,-11.7),V(1,11.35,-11.8),V(-4,11.35,-14.7),V(-4,5.85,-14.8),V(-8,5.85,-18.2),V(-8,.35,-18.3),V(-13,.35,-24)},
        {V(-2,27.9,0),V(-6.6,27.9,0),V(-6.7,22.35,0),V(-10.1,22.35,3),V(-10.2,16.85,3),V(-13.6,16.85,1),V(-13.7,11.35,1),V(-17.1,11.35,4),V(-17.2,5.85,4),V(-21.2,5.85,5),V(-21.3,.35,5),V(-25,.35,9)},
        {V(2,27.9,2),V(6.6,27.9,2),V(6.7,22.35,2),V(10.1,22.35,5),V(10.2,16.85,5),V(13.6,16.85,7),V(13.7,11.35,7),V(17.1,11.35,5),V(17.2,5.85,5),V(21.2,5.85,7),V(21.3,.35,7),V(24,.35,13)},
    }
    for branch,points in ipairs(paths) do
        for i=1,#points-1 do
            local a,b=points[i],points[i+1]
            -- lookAt needs a nonparallel up vector for the vertical waterfalls.
            local up=math.abs((b-a).Unit.Y)>.95 and V(0,0,1) or V(0,1,0)
            local frame=origin*CFrame.lookAt((a+b)/2,b,up)
            part(parent,"LavaChannel_"..branch,V(3.5,.3,(b-a).Magnitude+.3),frame,RGB(189,59,21),Enum.Material.SmoothPlastic)
            part(parent,"MoltenFlow_"..branch,V(2,.34,(b-a).Magnitude+.2),frame,RGB(246,119+branch*7,28),Enum.Material.Neon)
            local aa=anchor(parent,"FlowStart",origin*CF(a));local bb=anchor(parent,"FlowEnd",origin*CF(b))
            beam(parent,"FlowingLava_"..branch,aa,bb,RGB(255,188,68),.8,1.2)
        end
        local endp=points[#points]
        part(parent,"LavaPool_"..branch,V(8,.22,6),origin*CF(endp)*CFrame.Angles(0,branch*.6,0),RGB(231,102,27),Enum.Material.Neon)
        part(parent,"CoolingPoolCrust",V(3,.24,2),origin*CF(endp+V(2,.04,1)),RGB(61,48,48),Enum.Material.Slate)
    end
    local vent=anchor(parent,"CraterVent",origin*CF(0,28,0))
    emitter(vent,"CinderSmoke",RGB(83,78,89),7,4,5,true)
    local e=emitter(vent,"RisingEmbers",RGB(255,157,48),11,.22,7,false);e.Acceleration=V(0,-1,0)
    light(vent,RGB(255,132,52))
end
local function crystals(parent,origin)
    local colors={RGB(113,76,166),RGB(147,105,204),RGB(187,152,233),RGB(100,74,152),RGB(157,117,214),RGB(204,178,237)}
    part(parent,"PrismBedrock",V(32,1.4,26),origin*CF(0,.7,0)*CFrame.Angles(0,.12,0),RGB(66,60,88),Enum.Material.Slate)
    local tips={}
    for _,s in ipairs({{0,2,5.2,37,-.09,.12},{-11,0,3.6,23,.21,.25},{10,3,3.5,28,-.3,-.12},{-7,-9,2.8,16,.22,-.1},{8,-10,2.5,19,-.2,.2}}) do
        table.insert(tips,crystal(parent,origin*CF(s[1],1,s[2])*CFrame.Angles(s[6],0,s[5]),s[3],s[4],colors))
    end
    local core=anchor(parent,"Heartlight",origin*CF(0,13,-4))
    emitter(core,"PrismMotes",RGB(173,232,229),9,.45,2,false);light(core,RGB(165,133,230))
    for i,p in ipairs(tips) do
        local a=anchor(parent,"CrystalTip",CF(p))
        emitter(a,"CrystalDust",RGB(211,182,249),4,.35,1.5,false)
        if i>1 then beam(parent,"PrismEnergy",core,a,RGB(177,143,231),.15,.5,3) end
    end
end
function Art.StageEnvironment(map, lighting)
    local changes={}
    local function change(item,key,value)
        if item[key]~=value then table.insert(changes,{Item=item,Key=key,Before=item[key],After=value}) end
    end
    local decor=Instance.new("Folder");decor.Name="BiomePolishDecorV079"
    local snowColors={RGB(87,159,181),RGB(140,194,208),RGB(105,177,198)}
    local prismColors={RGB(116,85,164),RGB(160,119,211),RGB(195,169,227)}
    for _,biome in ipairs(map.Obby.Biomes:GetChildren()) do
        local stage=tonumber(biome.Name:match("Biome_(%d)_"))
        if stage and stage>=3 then
            for _,p in ipairs(biome:GetDescendants()) do
                if not p:IsA("BasePart") then continue end
                if p.Name=="Crystal" or p.Name=="CrystalShard" then
                    change(p,"Transparency",1)
                    local h=p.Size.Y
                    crystal(decor,CF(p.CFrame.Position-V(0,h/2,0))*CFrame.Angles(0,h*.7,.12),math.max(.5,p.Size.X*.65),h,stage==3 and snowColors or prismColors,4)
                elseif stage==3 then
                    if p.Name=="BiomeGround_3" then change(p,"Color",RGB(176,194,204))
                    elseif p.Name:find("SnowyPine") then change(p,"Color",p.Color.G>.8 and RGB(198,214,220) or RGB(65,105,112))
                    elseif p.Name:find("Ice") then change(p,"Color",RGB(111,171,192));change(p,"Material",Enum.Material.SmoothPlastic)
                    elseif p.Name:find("BiomeEdge") then change(p,"Color",RGB(100,158,179));change(p,"Material",Enum.Material.SmoothPlastic)
                    end
                elseif stage==4 then
                    if p.Name=="LavaCrack" or p.Name=="LavaGlow" then
                        change(p,"Color",RGB(133,68,47));change(p,"Material",Enum.Material.Slate)
                    elseif p.Name=="BiomeGround_4" then change(p,"Color",RGB(56,57,66)) end
                elseif stage==5 and p.Name=="BiomeGround_5" then change(p,"Color",RGB(94,78,123)) end
            end
        end
    end
    for _,p in ipairs(map.Obby.BiomeWalls:GetChildren()) do
        if p:IsA("BasePart") and p.Name:find("Biome_3_") then change(p,"Color",RGB(112,140,159)) end
    end
    for _,e in ipairs(lighting:GetChildren()) do
        if e:IsA("BloomEffect") then change(e,"Intensity",.18);change(e,"Threshold",1.6)
        elseif e.Name=="ChestChaseColor" and e:IsA("ColorCorrectionEffect") then
            change(e,"Brightness",0);change(e,"Contrast",.1);change(e,"Saturation",.08)
        end
    end
    return decor,changes
end
function Art.PolishBiomes(original)
    local biomes=original:Clone()
    for _,biome in ipairs(biomes:GetChildren()) do
        local stage=tonumber(biome.Name:match("^Biome_(%d+)_"))
        if stage==3 or stage==5 then
            local old=biome:GetDescendants()
            for _,p in ipairs(old) do
                if stage==3 and p:IsA("Texture") then p.Color3=RGB(190,207,216) end
                if not p:IsA("BasePart") then continue end
                if p.Name=="Crystal" or p.Name=="CrystalShard" then
                    local cluster=Instance.new("Model");cluster.Name="FacetedOutcrop"
                    local colors=stage==3 and {RGB(103,163,183),RGB(145,194,207),RGB(78,139,166)}
                        or {RGB(128,91,180),RGB(179,143,220),RGB(98,82,150)}
                    local h=math.clamp(p.Size.Y,2.5,8)
                    local pos=p.CFrame.Position
                    local frame=CF(pos.X,4.03,pos.Z)*CFrame.Angles(0,pos.Z%3,(pos.X%5-2)*.12)
                    crystal(cluster,frame,math.clamp(p.Size.X*.42,.45,1.2),h,colors,4)
                    cluster.PrimaryPart=cluster:FindFirstChildWhichIsA("BasePart")
                    cluster.Parent=p.Parent;p:Destroy()
                elseif stage==3 then
                    if p.Name=="BiomeGround_3" then p.Color=RGB(176,194,204);p.Material=Enum.Material.SmoothPlastic
                    elseif p.Name=="Snowdrift" then p.Color=RGB(198,212,220);p.Material=Enum.Material.SmoothPlastic
                    elseif p.Name=="SnowyPine" then p.Color=RGB(185,204,211);p.Material=Enum.Material.SmoothPlastic
                    elseif p.Name=="SnowyPineLayer" then
                        if p.Color.R>.6 then p.Color=RGB(194,211,216) else p.Color=RGB(62,107,113) end
                    elseif p.Name:find("BiomeEdge") then p.Color=RGB(104,159,181);p.Material=Enum.Material.SmoothPlastic
                    elseif p.Name=="GuardianCampPatch" then p.Color=RGB(132,162,178) end
                end
            end
        elseif stage==4 then
            for _,p in ipairs(biome:GetDescendants()) do
                if p:IsA("BasePart") and p.Name=="LavaCrack" then
                    p.Material=Enum.Material.SmoothPlastic;p.Color=RGB(141,66,39)
                    -- Subdued warm fissures support the main animated lava routes.
                end
            end
        end
    end
    biomes:SetAttribute("BiomePolishVersion",79)
    return biomes
end
function Art.Build(config)
    local folder=Instance.new("Folder");folder.Name="MythicLandmarks";folder:SetAttribute("ArtVersion",79)
    for stage,encounter in ipairs(config.MythicEncounters) do
        local model=Instance.new("Model");model.Name="Biome"..stage.."_Landmark";model:SetAttribute("Stage",stage)
        model:SetAttribute("LandmarkName",config.ArtModels.Landmarks[tostring(stage)].Name)
        model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
        local origin=CF(table.unpack(encounter.Landmark))
        if stage==3 then mountain(model,origin)
        elseif stage==4 then volcano(model,origin)
        elseif stage==5 then crystals(model,origin)
        else
            origin=origin*CFrame.Angles(0,math.rad(-encounter.Yaw),0)
            for _,s in ipairs(config.ArtModels.Landmarks[tostring(stage)].Parts) do
                local r=s.r or {0,0,0}
                local p=part(model,s.n,V(table.unpack(s.s)),origin*CF(table.unpack(s.p))*CFrame.Angles(math.rad(r[1] or 0),math.rad(r[2] or 0),math.rad(r[3] or 0)),RGB(table.unpack(s.c)),s.m and Enum.Material[s.m],s.k=="W" and "WedgePart" or "Part")
                if s.k=="C" then p.Shape=Enum.PartType.Cylinder;p.Size=V(s.s[2],s.s[1],s.s[3]);p.CFrame=p.CFrame*CFrame.Angles(0,0,math.pi/2) end
            end
        end
        model.PrimaryPart=model:FindFirstChildWhichIsA("BasePart")
        model.Parent=folder
    end
    return folder
end
-- V127 scenery migration. Original instances are archived for exact undo.
local ENV_ROOT='EnvironmentPolishV127'
local ENV_BACKUP='ChestChaseEnvironmentV127Backup'
local function findPath(root,path)
    for name in path:gmatch('[^/]+')do root=root and root:FindFirstChild(name) end
    return root
end
local function boundsWorld(model)
    local lo,hi=V(math.huge,math.huge,math.huge),V(-math.huge,-math.huge,-math.huge)
    local count=0
    for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
        count+=1
        for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
            local v=p.CFrame*V(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2)
            lo=V(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
            hi=V(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
        end end end
    end end
    assert(count>0,'[V127] Empty scenery model: '..model.Name)
    return lo,hi
end
local function iceCopy(source,name,destination,height,yaw,parent)
    local m=source:Clone();m.Name=name
    -- Reuse the exact earlier imported trees/spikes, with their original detail.
    for _,v in ipairs(m:GetDescendants())do if v:IsA('LuaSourceContainer')then v:Destroy()end end
    local lo,hi=boundsWorld(m);local scale=height/(hi.Y-lo.Y)
    m:ScaleTo(m:GetScale()*scale)
    local pivot=m:GetPivot();m:PivotTo(CF(pivot.Position)*CFrame.Angles(0,yaw,0)*pivot.Rotation)
    lo,hi=boundsWorld(m)
    local shift=destination-V((lo.X+hi.X)/2,lo.Y,(lo.Z+hi.Z)/2)
    m:PivotTo(m:GetPivot()+shift)
    m:SetAttribute('DesignVersion',127);m:SetAttribute('SceneryBaseline',nil)
    m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    for _,p in ipairs(m:GetDescendants())do if p:IsA('BasePart')then
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
        p.Material=Enum.Material.Glass;p.Reflectance=.14;p.Transparency=.24
        p.Color=p.Color:Lerp(RGB(171,222,246),.28)
    end end
    m.Parent=parent;return m
end
local function lavaPool(parent,name,center,rx,rz,main)
    local m=Instance.new('Model');m.Name=name;m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    m:SetAttribute('MagmaPoolV127',true);m:SetAttribute('PoolCenter',center)
    m:SetAttribute('PoolRadii',V(rx,0,rz))
    local count=main and 14 or 10
    local radii={.90,.72,.99,.83,.68,.94,.79,.99,.74,.89,.65,.96,.78,.93}
    local edge={}
    for i=1,count do local a=(i-1)*math.pi*2/count
        edge[i]=V(math.cos(a)*rx*radii[i],0,math.sin(a)*rz*radii[i])
    end
    for i=1,count do
        local a,b=edge[i],edge[i%count+1]
        triangle(m,'BasaltBed',center-V(0,.14,0),center+a*1.12-V(0,.14,0),center+b*1.12-V(0,.14,0),RGB(48,34,34),Enum.Material.Basalt)
        local before=#m:GetChildren()
        triangle(m,'MagmaSurface',center,center+a,center+b,RGB(246,91+(i%3)*8,14),Enum.Material.Neon)
        local children=m:GetChildren()
        for j=before+1,#children do children[j]:SetAttribute('MagmaPulse',i*.61)end
        -- Individually angled, uneven low shoreline; no rectangular border.
        local mid=center+(a+b)*.55
        local rock=part(m,'BrokenBasaltRim',V(math.max(1,(b-a).Magnitude*.72),.35+(i%3)*.11,main and 1.05 or .45),
            CF(mid+V(0,.02,0))*CFrame.Angles(0,math.atan2(-(b-a).Z,(b-a).X),.03*(i%3-1)),RGB(43+i%4*3,34,35),Enum.Material.Basalt)
        rock.CastShadow=false
    end
    for i=1,main and 6 or 3 do
        local a=i*2.39996;local radius=i%2==0 and .42 or .23
        local frame=CF(center+V(math.cos(a)*rx*radius,.08,math.sin(a)*rz*radius))*CFrame.Angles(0,a,.01)
        local crust=part(m,'DriftingCrust',V(rx*.20,.10,rz*.18),frame,RGB(53,32,32),Enum.Material.CrackedLava)
        crust:SetAttribute('MagmaRest',frame);crust:SetAttribute('MagmaDrift',i*1.27)
        crust.CastShadow=false
    end
    local origin=part(m,'MagmaAnchor',V(.1,.1,.1),CF(center),RGB(255,170,38))
    origin.Transparency=1;origin.CastShadow=false
    for i=1,main and 4 or 2 do
        local a=Instance.new('Attachment');a.Name='CurrentA'..i;a.Parent=origin
        local b=Instance.new('Attachment');b.Name='CurrentB'..i;b.Parent=origin
        local angle=i*math.pi*.5
        a.Position=V(math.cos(angle)*rx*.30,.065,math.sin(angle)*rz*.30)
        b.Position=V(math.cos(angle+.8)*rx*.54,.065,math.sin(angle+.8)*rz*.54)
        local flow=beam(m,'MoltenCurrent',a,b,RGB(255,207,70),main and .26 or .12,.25,main and 1.1 or .3)
        flow:SetAttribute('MagmaCurrent',i);flow.LightEmission=1;flow.Transparency=NumberSequence.new(.32)
    end
    m.PrimaryPart=origin;m.Parent=parent;return m
end
function Art.UndoPolishV127(map)
    local storage=game:GetService('ServerStorage');local backup=storage:FindFirstChild(ENV_BACKUP)
    local created=map:FindFirstChild(ENV_ROOT)
    if not backup then
        assert(not created and not map:GetAttribute('EnvironmentAppliedV127'),'[V127] Scenery backup is missing.')
        return
    end
    assert(backup:GetAttribute('OwnerVersion')==127,'[V127] Unrecognized scenery backup.')
    -- Validate every destination before restoring anything.
    for _,record in ipairs(backup:GetChildren())do
        local target=record:FindFirstChild('OriginalParent')
        assert(target and target.Value and target.Value:IsDescendantOf(map),'[V127] Original scenery parent is missing.')
    end
    for _,record in ipairs(backup:GetChildren())do
        local target=record.OriginalParent.Value
        for _,v in ipairs(record:GetChildren())do if v.Name~='OriginalParent'then v.Parent=target end end
    end
    if created then created:Destroy()end
    backup:Destroy();map:SetAttribute('EnvironmentAppliedV127',nil)
end
function Art.ApplyPolishV127(map)
    if map:GetAttribute('EnvironmentAppliedV127')then
        assert(map:FindFirstChild(ENV_ROOT),'[V127] Applied scenery is missing.');return
    end
    local storage=game:GetService('ServerStorage')
    assert(not map:FindFirstChild(ENV_ROOT)and not storage:FindFirstChild(ENV_BACKUP),'[V127] Unfinished scenery update found.')
    local snow=findPath(map,'Obby/Biomes/Biome_3_FROSTLAND')
    local ice=findPath(snow,'CustomScenery/TranslucentIceV106')
    local grove=findPath(snow,'GeneratedScenery/Snow pine grove')
    local river=findPath(map,'Obby/Biomes/Biome_4_EMBER_WASTES/BiomeScenesV092/LavaRiverV092')
    local oldPool=river and river:FindFirstChild('Lava pool')
    local bank=river and river:FindFirstChild('Pool bank')
    assert(ice and grove and oldPool and bank,'[V127] Expected ice assets, pine grove or lava pool missing.')
    local tree=ice:FindFirstChild('IceTree_1');local spike=ice:FindFirstChild('IceSpike_5')
    assert(tree and spike,'[V127] Earlier imported ice tree/spike missing.')
    local created=Instance.new('Folder');created.Name=ENV_ROOT
    local backup=Instance.new('Folder');backup.Name=ENV_BACKUP;backup:SetAttribute('OwnerVersion',127)
    local originals={grove,oldPool,bank}
    local okay,err=xpcall(function()
        local trees=Instance.new('Folder');trees.Name='RestoredIceGrove';trees.Parent=created
        -- Only the old pine grove is replaced. Existing V106 ice scenery is retained.
        local trunks={};for _,v in ipairs(grove:GetDescendants())do
            if v:IsA('BasePart')and v.Name=='Pine trunk'then table.insert(trunks,v)end
        end
        assert(#trunks==2,'[V127] Pine grove layout changed; stopped before replacement.')
        table.sort(trunks,function(a,b)return a.Position.X<b.Position.X end)
        for i,p in ipairs(trunks)do
            local y=p.Position.Y-p.Size.Y/2
            iceCopy(tree,'IceTree_Repl'..i,V(p.Position.X,y,p.Position.Z),i==1 and 25 or 18,i*.7,trees)
        end
        local cover=grove:FindFirstChild('Ground cover');assert(cover,'[V127] Grove ground missing.')
        local ground=cover.Position.Y+cover.Size.Y/2
        for i,offset in ipairs({V(-8,0,10),V(5,0,-9),V(10,0,6)})do
            local pos=cover.CFrame*offset
            iceCopy(spike,'IceSpike_Repl'..i,V(pos.X,ground,pos.Z),4.5+i*.7,i*1.1,trees)
        end
        -- Keep the grove's snow floor and stones in their exact original positions.
        for _,p in ipairs(grove:GetChildren())do
            if p:IsA('BasePart')and not(p.Name:find('Pine')or p.Name=='Snow cap')then p:Clone().Parent=trees end
        end
        local pools=Instance.new('Folder');pools.Name='IrregularMagmaPools';pools.Parent=created
        lavaPool(pools,'MainMagmaPool',oldPool.Position,9.5,7,true)
        local landmark=findPath(map,'MythicLandmarks/Biome4_Landmark')
        if landmark then for _,p in ipairs(landmark:GetChildren())do
            if p:IsA('BasePart')and p.Name:match('^LavaPool_%d+$')then
                lavaPool(pools,p.Name..'_Irregular',p.Position,3.8,2.8,false);table.insert(originals,p)
            elseif p:IsA('BasePart')and p.Name=='CoolingPoolCrust'then table.insert(originals,p)end
        end end
        -- Archive targets only after every replacement is built successfully.
        backup.Parent=storage
        for i,v in ipairs(originals)do
            local record=Instance.new('Folder');record.Name='Original'..i;record.Parent=backup
            local parent=Instance.new('ObjectValue');parent.Name='OriginalParent';parent.Value=v.Parent;parent.Parent=record
            v.Parent=record
        end
        created.Parent=map;map:SetAttribute('EnvironmentAppliedV127',true)
    end,debug.traceback)
    if not okay then
        for _,record in ipairs(backup:GetChildren())do
            local target=record:FindFirstChild('OriginalParent')
            if target and target.Value then for _,v in ipairs(record:GetChildren())do if v~=target then v.Parent=target.Value end end end
        end
        created:Destroy();backup:Destroy();map:SetAttribute('EnvironmentAppliedV127',nil)
        error(err)
    end
end

-- One outline, one triangulated magma surface, one continuous shoreline.
local function crossXZ(a,b,c)return(b.X-a.X)*(c.Z-a.Z)-(b.Z-a.Z)*(c.X-a.X)end
function Art.RiverOutlineV128(nodes)
    assert(#nodes>=2 and #nodes<=16,'[V128] Invalid river node count.')
    local points=table.clone(nodes)
    for _=1,2 do
        local smooth={points[1]}
        for i=1,#points-1 do
            table.insert(smooth,points[i]:Lerp(points[i+1],.25));table.insert(smooth,points[i]:Lerp(points[i+1],.75))
        end
        table.insert(smooth,points[#points]);points=smooth
    end
    local distances,total={0},0
    for i=2,#points do total+=(points[i]-points[i-1]).Magnitude;distances[i]=total end
    local left,right,widths={},{},{}
    for i,p in ipairs(points)do
        local delta=points[math.min(#points,i+1)]-points[math.max(1,i-1)]
        local tangent=V(delta.X,0,delta.Z).Unit;local normal=V(-tangent.Z,0,tangent.X)
        local widen=math.clamp((17-(total-distances[i]))/17,0,1);widen=widen*widen*(3-2*widen)
        local width=2.8+3.7*widen+math.sin(distances[i]*.13)*.16*(1-widen)
        left[i]=p+normal*width;right[i]=p-normal*width;widths[i]=width
    end
    local outline=table.clone(left)
    local finish=points[#points];local f=(finish-points[#points-1]).Unit;local side=V(-f.Z,0,f.X)
    for i=1,12 do
        local a=i*math.pi/12;local irregular=1+.045*math.sin(a*3)+.025*math.sin(a*7)
        table.insert(outline,finish+(side*math.cos(a)*widths[#points]+f*math.sin(a)*8.2)*irregular)
    end
    for i=#right-1,1,-1 do table.insert(outline,right[i])end
    local start=points[1];local forward=(points[2]-start).Unit;local normal=V(-forward.Z,0,forward.X)
    for i=1,7 do local a=i*math.pi/8
        table.insert(outline,start-normal*math.cos(a)*widths[1]-forward*math.sin(a)*widths[1])
    end
    local area=0
    for i,a in ipairs(outline)do local b=outline[i%#outline+1];area+=a.X*b.Z-b.X*a.Z end
    if area<0 then local reversed={};for i=#outline,1,-1 do table.insert(reversed,outline[i])end;outline=reversed end
    local outer={}
    for i,p in ipairs(outline)do
        local before=outline[(i-2)%#outline+1];local after=outline[i%#outline+1]
        local a=(p-before).Unit;local b=(after-p).Unit
        local n1,n2=V(a.Z,0,-a.X),V(b.Z,0,-b.X)
        local sum=n1+n2;local direction=sum.Magnitude>.001 and sum.Unit or n1
        local extension=.72/math.max(.55,direction:Dot(n1))
        outer[i]=p+direction*extension
    end
    return outline,outer,points,distances,total
end
function Art.TriangulateRiverV128(outline)
    local indices={};for i=1,#outline do indices[i]=i end
    local result={}
    local function inside(p,a,b,c)
        return crossXZ(a,b,p)>=-.000001 and crossXZ(b,c,p)>=-.000001 and crossXZ(c,a,p)>=-.000001
    end
    while #indices>3 do
        local found=false
        for i,index in ipairs(indices)do
            local prev,next=indices[(i-2)%#indices+1],indices[i%#indices+1]
            local a,b,c=outline[prev],outline[index],outline[next]
            if crossXZ(a,b,c)<=.000001 then continue end
            local occupied=false
            for _,other in ipairs(indices)do
                if other~=prev and other~=index and other~=next and inside(outline[other],a,b,c)then occupied=true;break end
            end
            if not occupied then
                table.insert(result,{a,b,c});table.remove(indices,i);found=true;break
            end
        end
        assert(found,'[V128] River outline cannot be triangulated; original scenery retained.')
    end
    table.insert(result,{outline[indices[1]],outline[indices[2]],outline[indices[3]]})
    return result
end
local function continuousRiver(parent,nodes)
    local outline,outer,points,distances,total=Art.RiverOutlineV128(nodes)
    local faces=Art.TriangulateRiverV128(outline)
    local m=Instance.new('Model');m.Name='ContinuousLavaRiver';m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    m:SetAttribute('LavaRouteV128',true);m:SetAttribute('MagmaPoolV127',true)
    m:SetAttribute('PoolCenter',nodes[#nodes]);m:SetAttribute('PoolRadii',V(6.5,0,8.2))
    m:SetAttribute('NodeCount',#points);m:SetAttribute('FlowSpeed',4.5)
    for i,p in ipairs(points)do m:SetAttribute('Node'..i,p)end
    for i,t in ipairs(faces)do
        local first=#m:GetChildren()
        triangle(m,'MagmaSurface',t[1],t[2],t[3],RGB(223,66,13),Enum.Material.Neon)
        local children=m:GetChildren();local centroid=(t[1]+t[2]+t[3])/3
        for j=first+1,#children do children[j]:SetAttribute('MagmaPulse',(centroid-nodes[1]).Magnitude*.055)end
    end
    for i,a in ipairs(outline)do
        local j=i%#outline+1;local b=outline[j]
        quad(m,'ContinuousBasaltBank',a+V(0,.015,0),b+V(0,.015,0),outer[j]+V(0,.12,0),outer[i]+V(0,.12,0),RGB(49,38,36),Enum.Material.Basalt)
    end
    for i=2,#points-1,3 do
        local frame=CF(points[i]+V(math.sin(i)*.65,.085,math.cos(i)*.45))*CFrame.Angles(0,i*.79,.01)
        local crust=part(m,'DriftingCrust',V(1.7,.12,2.7),frame,RGB(52,34,31),Enum.Material.CrackedLava,'WedgePart')
        crust:SetAttribute('MagmaRest',frame);crust:SetAttribute('MagmaDrift',i*.47)
    end
    local center=nodes[#nodes]
    for i=1,5 do
        local a=i*2.4;local frame=CF(center+V(math.cos(a)*3.6,.085,math.sin(a)*3.2))*CFrame.Angles(0,a,.01)
        local crust=part(m,'DriftingCrust',V(2.6,.12,2.1),frame,RGB(52,34,31),Enum.Material.CrackedLava,'WedgePart')
        crust:SetAttribute('MagmaRest',frame);crust:SetAttribute('MagmaDrift',i*1.2)
    end
    for i=1,10 do
        local flow=part(m,'MovingMoltenCurrent',V(.20,.025,2.3+(i%3)*.4),CF(nodes[1]+V(0,.055,0)),RGB(255,182,62),Enum.Material.Neon)
        flow:SetAttribute('FlowPhase',(i-1)/10);flow.Transparency=.48
    end
    local origin=part(m,'PoolCurrentAnchor',V(.1,.1,.1),CF(center),RGB(255,182,62));origin.Transparency=1
    for i=1,3 do
        local a=Instance.new('Attachment');a.Parent=origin
        local b=Instance.new('Attachment');b.Parent=origin
        local current=beam(m,'MoltenCurrent',a,b,RGB(255,185,65),.16,.2,.5)
        current:SetAttribute('MagmaCurrent',i);current.LightEmission=1
    end
    for _,p in ipairs(m:GetChildren())do if p:IsA('BasePart')then p.CastShadow=false end end
    m.PrimaryPart=origin;m.Parent=parent
    return m
end
function Art.UndoPresentationV128(map)
    local backup=game:GetService('ServerStorage'):FindFirstChild('ChestChasePresentationV128Backup')
    local created=map:FindFirstChild('PresentationV128')
    if not backup then
        assert(not created and not map:GetAttribute('PresentationAppliedV128'),'[V128] River backup missing.');return
    end
    assert(backup:GetAttribute('OwnerVersion')==128,'[V128] Unrecognized river backup.')
    for _,r in ipairs(backup:GetChildren())do
        assert(r:FindFirstChild('OriginalParent')and r.OriginalParent.Value and r.OriginalParent.Value:IsDescendantOf(map),'[V128] River parent missing.')
    end
    for _,r in ipairs(backup:GetChildren())do for _,v in ipairs(r:GetChildren())do
        if v~=r.OriginalParent then v.Parent=r.OriginalParent.Value end
    end end
    if created then created:Destroy()end
    backup:Destroy();map:SetAttribute('PresentationAppliedV128',nil)
end
function Art.ApplyPresentationV128(map)
    Art.ApplyPolishV127(map)
    if map:GetAttribute('PresentationAppliedV128')then
        assert(map:FindFirstChild('PresentationV128'),'[V128] Applied river missing.');return
    end
    local storage=game:GetService('ServerStorage')
    assert(not storage:FindFirstChild('ChestChasePresentationV128Backup')and not map:FindFirstChild('PresentationV128'),'[V128] Partial river update found.')
    local river=findPath(map,'Obby/Biomes/Biome_4_EMBER_WASTES/BiomeScenesV092/LavaRiverV092')
    local pool=findPath(map,'EnvironmentPolishV127/IrregularMagmaPools/MainMagmaPool')
    local sourcePool=findPath(map,'EnvironmentPolishV127/IrregularMagmaPools/LavaPool_1_Irregular')
    assert(river and pool and sourcePool,'[V128] Expected prior river/pools missing.')
    local nodes={};local count=river:GetAttribute('NodeCount')
    assert(type(count)=='number'and count>=2 and count<=16,'[V128] Unexpected river route.')
    for i=1,count do
        local p=river:GetAttribute('Node'..i);assert(typeof(p)=='Vector3','[V128] River node missing.');nodes[i]=p
    end
    local created=Instance.new('Folder');created.Name='PresentationV128'
    local backup=Instance.new('Folder');backup.Name='ChestChasePresentationV128Backup';backup:SetAttribute('OwnerVersion',128)
    local okay,err=xpcall(function()
        continuousRiver(created,nodes)
        backup.Parent=storage
        for i,v in ipairs({river,pool,sourcePool})do
            local r=Instance.new('Folder');r.Name='Original'..i;r.Parent=backup
            local target=Instance.new('ObjectValue');target.Name='OriginalParent';target.Value=v.Parent;target.Parent=r
            v.Parent=r
        end
        created.Parent=map;map:SetAttribute('PresentationAppliedV128',true)
    end,debug.traceback)
    if not okay then
        for _,r in ipairs(backup:GetChildren())do
            local target=r:FindFirstChild('OriginalParent')
            if target and target.Value then for _,v in ipairs(r:GetChildren())do if v~=target then v.Parent=target.Value end end end
        end
        created:Destroy();backup:Destroy();map:SetAttribute('PresentationAppliedV128',nil);error(err)
    end
end

-- V129 replaces the stepped landmark with a faceted basalt cone and connected channels.
local function volcanoShape(a)
    return 1+.045*math.sin(a*3)+.025*math.cos(a*5)
end
local function volcanoRing(center,rx,rz,y,a)
    local wobble=volcanoShape(a)
    return center+V(math.cos(a)*rx*wobble,y,math.sin(a)*rz*wobble)
end
local function channelV129(parent,name,nodes,widths)
    local m=Instance.new('Model');m.Name=name;m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    m:SetAttribute('LavaRouteV128',true);m:SetAttribute('NodeCount',#nodes);m:SetAttribute('FlowSpeed',4.5)
    m:SetAttribute('MagmaPoolV127',true);m:SetAttribute('PoolCenter',nodes[math.ceil(#nodes/2)]);m:SetAttribute('PoolRadii',V(1,0,1))
    local left,right,outerLeft,outerRight={},{},{},{}
    for i,p in ipairs(nodes)do
        m:SetAttribute('Node'..i,p)
        local tangent=nodes[math.min(#nodes,i+1)]-nodes[math.max(1,i-1)]
        local n=V(-tangent.Z,0,tangent.X).Unit
        left[i]=p+n*widths[i];right[i]=p-n*widths[i]
        outerLeft[i]=p+n*(widths[i]+.45)+V(0,.10,0)
        outerRight[i]=p-n*(widths[i]+.45)+V(0,.10,0)
    end
    for i=1,#nodes-1 do
        local first=#m:GetChildren()
        quad(m,'MagmaSurface',left[i],right[i],right[i+1],left[i+1],RGB(223,66,13),Enum.Material.Neon)
        local children=m:GetChildren()
        for j=first+1,#children do children[j]:SetAttribute('MagmaPulse',i*.35)end
        quad(m,'BasaltChannelBank',left[i],left[i+1],outerLeft[i+1],outerLeft[i],RGB(49,38,36),Enum.Material.Basalt)
        quad(m,'BasaltChannelBank',right[i],outerRight[i],outerRight[i+1],right[i+1],RGB(49,38,36),Enum.Material.Basalt)
    end
    for i=1,5 do
        local p=part(m,'MovingMoltenCurrent',V(.18,.025,1.5),CF(nodes[1]),RGB(255,182,62),Enum.Material.Neon)
        p:SetAttribute('FlowPhase',(i-1)/5);p.Transparency=.48
    end
    m.Parent=parent;return m
end
function Art.BuildVolcanoV129(parent,center,outlets)
    assert(#outlets==3,'[V129] Expected three volcano outlets.')
    local model=Instance.new('Model');model.Name='Biome4_Landmark';model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    model:SetAttribute('VolcanoVersion',129)
    local levels={{22.5,20.5,0},{16.5,14.9,8.0},{10.5,9.2,19},{6.4,5.7,27}}
    local count=24
    local rings={}
    local directions={}
    for i,outlet in ipairs(outlets)do directions[i]=math.atan2(outlet.Z-center.Z,outlet.X-center.X)end
    for level,l in ipairs(levels)do
        rings[level]={}
        for i=1,count do rings[level][i]=volcanoRing(center,l[1],l[2],l[3],(i-1)*math.pi*2/count)end
    end
    local colors={RGB(49,38,36),RGB(57,43,40),RGB(43,35,34),RGB(61,46,42)}
    for level=1,#levels-1 do for i=1,count do
        local j=i%count+1
        quad(model,'BasaltSlope',rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i],colors[(i+level)%#colors+1],Enum.Material.Basalt)
    end end
    -- Uneven ring with three lowered overflow notches, instead of a square crater.
    local inner={}
    for i=1,count do
        local a=(i-1)*math.pi*2/count
        local notch=0
        for _,heading in ipairs(directions)do
            local delta=math.atan2(math.sin(a-heading),math.cos(a-heading))
            notch=math.max(notch,math.clamp(1-math.abs(delta)/.32,0,1))
        end
        inner[i]=volcanoRing(center,4.8,4.2,28.0-notch*.9+.14*math.sin(a*4)*(1-notch),a)
    end
    for i=1,count do
        local j=i%count+1
        quad(model,'CraterLip',rings[#rings][i],rings[#rings][j],inner[j],inner[i],colors[i%#colors+1],Enum.Material.Basalt)
    end
    local crater=Instance.new('Model');crater.Name='MoltenCrater';crater:SetAttribute('MagmaPoolV127',true)
    crater:SetAttribute('PoolCenter',center+V(0,27.32,0));crater:SetAttribute('PoolRadii',V(4.8,0,4.2))
    for i=1,count do
        local a=(i-1)*math.pi*2/count;local b=i*math.pi*2/count
        local first=#crater:GetChildren()
        triangle(crater,'MagmaSurface',center+V(0,27.32,0),volcanoRing(center,4.82,4.22,27.32,a),volcanoRing(center,4.82,4.22,27.32,b),RGB(223,66,13),Enum.Material.Neon)
        local children=crater:GetChildren();for j=first+1,#children do children[j]:SetAttribute('MagmaPulse',i*.08)end
    end
    crater.Parent=model
    for branch,outlet in ipairs(outlets)do
        local angle=directions[branch]
        -- Follow the same faceted cone rings, then meet the exact existing river/pool endpoint.
        local nodes={volcanoRing(center,4.0,3.5,27.37,angle)}
        local widths={branch==1 and 1.05 or .72}
        for level=#levels,1,-1 do
            local l=levels[level]
            table.insert(nodes,volcanoRing(center,l[1],l[2],l[3]+.18,angle))
            table.insert(widths,(branch==1 and 1.20 or .80)+(4-level)*.17)
        end
        table.insert(nodes,outlet);table.insert(widths,branch==1 and 2.75 or 1.6)
        channelV129(model,'VolcanoMagmaChannel_'..branch,nodes,widths)
    end
    local vent=anchor(model,'CraterVent',CF(center+V(0,28.1,0)))
    emitter(vent,'RisingEmbers',RGB(255,157,48),5,.16,3,false)
    local smoke=emitter(vent,'CinderSmoke',RGB(74,68,66),3,2.8,2.3,true);smoke.Lifetime=NumberRange.new(1.8,2.8)
    light(vent,RGB(255,132,52))
    local root=part(model,'VolcanoRoot',V(.1,.1,.1),CF(center),RGB(49,38,36));root.Transparency=1
    model.PrimaryPart=root
    for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then p.CastShadow=false end end
    model.Parent=parent;return model
end
function Art.UndoVolcanoV129(map)
    local backup=game:GetService('ServerStorage'):FindFirstChild('ChestChaseVolcanoV129Backup')
    if not backup then assert(not map:GetAttribute('VolcanoAppliedV129'),'[V129] Volcano backup missing.');return end
    assert(backup:GetAttribute('OwnerVersion')==129,'[V129] Unrecognized volcano backup.')
    local target=backup:FindFirstChild('OriginalParent');local original=backup:FindFirstChild('Biome4_Landmark')
    assert(target and target.Value and target.Value:IsDescendantOf(map)and original,'[V129] Original volcano or parent missing.')
    local current=target.Value:FindFirstChild('Biome4_Landmark')
    assert(current and current:GetAttribute('VolcanoVersion')==129,'[V129] Replacement volcano changed.')
    current:Destroy();original.Parent=target.Value;backup:Destroy();map:SetAttribute('VolcanoAppliedV129',nil)
end
function Art.ApplyVolcanoV129(map)
    Art.ApplyPresentationV128(map)
    local parent=assert(map:FindFirstChild('MythicLandmarks'),'[V129] Landmarks missing.')
    local old=assert(parent:FindFirstChild('Biome4_Landmark'),'[V129] Volcano missing.')
    if map:GetAttribute('VolcanoAppliedV129')then assert(old:GetAttribute('VolcanoVersion')==129,'[V129] Volcano changed.');return end
    assert(not game:GetService('ServerStorage'):FindFirstChild('ChestChaseVolcanoV129Backup'),'[V129] Partial volcano update found.')
    local crater=assert(old:FindFirstChild('CraterPool'),'[V129] Original crater missing.')
    local route=findPath(map,'PresentationV128/ContinuousLavaRiver')
    local pools=findPath(map,'EnvironmentPolishV127/IrregularMagmaPools')
    local pool2=pools and pools:FindFirstChild('LavaPool_2_Irregular')
    local pool3=pools and pools:FindFirstChild('LavaPool_3_Irregular')
    assert(route and pool2 and pool3,'[V129] Connected river or side pools missing.')
    local center=crater.Position-V(0,27.62,0)
    local outlets={route:GetAttribute('Node1'),pool2:GetAttribute('PoolCenter'),pool3:GetAttribute('PoolCenter')}
    for _,p in ipairs(outlets)do assert(typeof(p)=='Vector3','[V129] Lava outlet missing.')end
    local replacement=Art.BuildVolcanoV129(nil,center,outlets)
    local backup=Instance.new('Folder');backup.Name='ChestChaseVolcanoV129Backup';backup:SetAttribute('OwnerVersion',129)
    local okay,why=xpcall(function()
        local target=Instance.new('ObjectValue');target.Name='OriginalParent';target.Value=parent;target.Parent=backup
        backup.Parent=game:GetService('ServerStorage');old.Parent=backup
        replacement.Parent=parent;map:SetAttribute('VolcanoAppliedV129',true)
    end,debug.traceback)
    if not okay then
        replacement:Destroy();old.Parent=parent;backup:Destroy();map:SetAttribute('VolcanoAppliedV129',nil);error(why)
    end
end

-- V135: distinct biome rails and front silhouettes; stripe-free V134 tracks; stable V131 training API.
local treadmillThemes={
 {Name='Trail Runner',Body=RGB(191,135,75),Trim=RGB(106,195,101),Glow=RGB(225,253,153),Ink=RGB(54,106,68),Material=Enum.Material.Wood},
 {Name='Vine Runner',Body=RGB(236,201,108),Trim=RGB(51,190,127),Glow=RGB(255,222,109),Ink=RGB(40,110,88),Material=Enum.Material.Wood},
 {Name='Dune Runner',Body=RGB(251,202,130),Trim=RGB(232,141,90),Glow=RGB(255,241,167),Ink=RGB(145,87,66),Material=Enum.Material.Sandstone},
 {Name='Glacier Runner',Body=RGB(135,203,234),Trim=RGB(195,245,255),Glow=RGB(235,255,255),Ink=RGB(58,113,157),Material=Enum.Material.Ice},
 {Name='Magma Runner',Body=RGB(96,88,111),Trim=RGB(255,143,74),Glow=RGB(255,216,99),Ink=RGB(82,62,89),Material=Enum.Material.Basalt},
 {Name='Prism Runner',Body=RGB(217,181,250),Trim=RGB(124,228,222),Glow=RGB(250,223,255),Ink=RGB(119,80,155),Material=Enum.Material.Glass},
 {Name='Thunder Runner',Body=RGB(111,155,237),Trim=RGB(255,224,96),Glow=RGB(255,247,193),Ink=RGB(56,82,153),Material=Enum.Material.Metal},
}
-- R117: tier flair. Static, non-colliding parts plus disabled emitters/lights/beams. The client
-- (TreadmillFx) enables and animates them by quality budget, distance, FastMode and ReducedMotion.
-- Attributes read by TreadmillFx: TreadmillFx (role), TreadmillFxQuality (minimum ClientFxBudget tier),
-- TreadmillFxRate/Burst/Brightness, TreadmillPulse*, TreadmillHue, TreadmillSpin*, TreadmillFlicker.
local TREADMILL_NUMERALS={'I','II','III','IV','V','VI','VII'}
-- Outer (-Z) face of each tier's front sign, in origin space after the V137 length scale.
local TREADMILL_FRONT_FACE={-7.78,-8.11,-8.28,-8.015,-8.065,-8.10,-8.16}
local function treadmillFlairR117(k)
    local m,origin,tier,theme,surface=k.m,k.origin,k.tier,k.theme,k.surface
    local p,rawp,sphere,rod,longer=k.p,k.rawp,k.sphere,k.rod,k.longer
    local made={}
    local function keep(v)if v and v:IsA('BasePart')then v.CastShadow=false;table.insert(made,v)end;return v end
    local function P(...)return keep(p(...))end
    local function S(...)return keep(sphere(...))end
    local function R(name,a,b,width,color,material)return keep(rod(name,a,b,width,color,material))end
    local function att(name,pos,axisUp)
        local a=Instance.new('Attachment');a.Name=name
        a.CFrame=CF(longer(pos)-V(0,.18,0))*(axisUp and CFrame.Angles(0,0,math.pi/2)or CFrame.identity)
        a.Parent=surface;return a
    end
    local function seq(...)
        local colors={...}
        if #colors==1 then return ColorSequence.new(colors[1])end
        local points={}
        for i,c in ipairs(colors)do table.insert(points,ColorSequenceKeypoint.new((i-1)/(#colors-1),c))end
        return ColorSequence.new(points)
    end
    -- o: Color (ColorSequence), Rate, Burst, Life{a,b}, Speed{a,b}, Size, Texture, Accel, Spread, Light, Drag, Dir
    local function emit(a,name,role,quality,o)
        local e=Instance.new('ParticleEmitter');e.Name=name;e.Enabled=false
        e.Texture='rbxasset://textures/particles/'..(o.Texture or'sparkles')..'_main.dds'
        e.Color=o.Color;e.Rate=role=='Burst'and 0 or o.Rate
        e.Lifetime=NumberRange.new(o.Life[1],o.Life[2]);e.Speed=NumberRange.new(o.Speed[1],o.Speed[2])
        e.SpreadAngle=Vector2.new(o.Spread or 30,o.Spread or 30);e.EmissionDirection=o.Dir or Enum.NormalId.Top
        e.Acceleration=o.Accel or V(0,0,0);e.Drag=o.Drag or 0
        e.LightEmission=o.Light or .7;e.LightInfluence=o.Texture=='smoke'and .6 or .1
        e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-40,40)
        e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,o.Size*.4),NumberSequenceKeypoint.new(.35,o.Size),NumberSequenceKeypoint.new(1,o.Size*(o.Texture=='smoke'and 1.6 or .1))})
        e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.12,o.Texture=='smoke'and .55 or .1),NumberSequenceKeypoint.new(1,1)})
        e:SetAttribute('TreadmillFx',role);e:SetAttribute('TreadmillFxQuality',quality)
        e:SetAttribute('TreadmillFxRate',o.Rate or 0);e:SetAttribute('TreadmillFxBurst',o.Burst or 0)
        e.Parent=a;return e
    end
    local function glow(parent,name,color,brightness,range,quality,flicker)
        local l=Instance.new('PointLight');l.Name=name;l.Enabled=false;l.Shadows=false
        l.Color=color;l.Brightness=brightness;l.Range=range
        l:SetAttribute('TreadmillFx','Light');l:SetAttribute('TreadmillFxQuality',quality)
        l:SetAttribute('TreadmillFxBrightness',brightness);l:SetAttribute('TreadmillFlicker',flicker==true)
        l.Parent=parent;return l
    end
    local function pulse(v,amp,speed,phase)
        if not v then return end
        v:SetAttribute('TreadmillPulse',amp);v:SetAttribute('TreadmillPulseSpeed',speed)
        v:SetAttribute('TreadmillPulsePhase',phase or 0);v:SetAttribute('TreadmillPulseBase',v.Transparency)
        return v
    end
    local function hue(v,phase)if v then v:SetAttribute('TreadmillHue',phase or 0)end;return v end
    -- Orbit about the pivot's Y axis. Pivot and rest are stored in belt (origin) space.
    local function spin(v,pivot,speed,quality)
        v:SetAttribute('TreadmillSpin',speed);v:SetAttribute('TreadmillFxQuality',quality)
        v:SetAttribute('TreadmillSpinPivot',pivot);v:SetAttribute('TreadmillSpinRest',origin:ToObjectSpace(v.CFrame))
        return v
    end
    local function arc(name,a0,a1,color,width,curve,quality,role)
        local b=Instance.new('Beam');b.Name=name;b.Enabled=false;b.Attachment0=a0;b.Attachment1=a1
        b.Color=color;b.Width0=width;b.Width1=width*.6;b.FaceCamera=true;b.Segments=role=='Ribbon'and 16 or 8
        b.LightEmission=1;b.LightInfluence=0;b.CurveSize0=curve;b.CurveSize1=-curve
        b.Texture='rbxasset://textures/particles/sparkles_main.dds';b.TextureLength=role=='Ribbon'and 5 or 2
        b.TextureSpeed=role=='Ribbon'and .35 or 3
        b.Transparency=role=='Ribbon'and NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.25,.45),NumberSequenceKeypoint.new(.75,.45),NumberSequenceKeypoint.new(1,1)})or NumberSequence.new(.05)
        b:SetAttribute('TreadmillFx',role or'Arc');b:SetAttribute('TreadmillFxQuality',quality)
        b:SetAttribute('TreadmillArcCurve',curve);b.Parent=m;return b
    end
    local function orbiter(name,size,frame,color,material,ball)
        local v=keep(rawp(name,size,frame,color,material));if ball then v.Shape=Enum.PartType.Ball end;return v
    end
    local function named(name)return m:FindFirstChild(name)end
    local function allNamed(name)
        local list={};for _,v in ipairs(m:GetChildren())do if v.Name==name then table.insert(list,v)end end;return list
    end

    -- Every tier: an outward tier plaque (Roman numeral + name) and tier pips on the runner's console.
    local plaque=keep(rawp('Tier plaque',V(3.4,1.5,.08),CF(0,4.1,TREADMILL_FRONT_FACE[tier]-.045),theme.Ink,Enum.Material.SmoothPlastic))
    local plaqueGui=Instance.new('SurfaceGui');plaqueGui.Name='TierPlaqueDisplay';plaqueGui.Face=Enum.NormalId.Front
    plaqueGui.CanvasSize=Vector2.new(340,150);plaqueGui.LightInfluence=.2;plaqueGui.MaxDistance=160;plaqueGui.Parent=plaque
    local rim=Instance.new('UIStroke');rim.Name='TierRim';rim.Color=theme.Glow;rim.Thickness=tier>=5 and 7 or 4;rim.Parent=plaqueGui
    local function label(parent,name,text,y,h,color)
        local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Text=text
        t.Position=UDim2.new(0,8,0,y);t.Size=UDim2.new(1,-16,0,h);t.TextScaled=true;t.Font=Enum.Font.FredokaOne
        t.TextColor3=color;t.TextStrokeColor3=theme.Ink;t.TextStrokeTransparency=.2;t.Parent=parent;return t
    end
    label(plaqueGui,'TierNumeral',TREADMILL_NUMERALS[tier],4,92,theme.Glow)
    label(plaqueGui,'TierName',string.upper(theme.Name),96,48,theme.Trim)
    if k.face then
        label(k.face,'ConsoleTierName',theme.Name,10,70,theme.Glow)
        local row=Instance.new('Frame');row.Name='TierPips';row.BackgroundTransparency=1
        row.Position=UDim2.new(.5,-245,0,100);row.Size=UDim2.new(0,490,0,54);row.Parent=k.face
        for i=1,7 do
            local pip=Instance.new('Frame');pip.Name='TierPip'..i;pip.BorderSizePixel=0
            pip.Position=UDim2.new(0,(i-1)*72,0,4);pip.Size=UDim2.new(0,58,0,46)
            pip.BackgroundColor3=i<=tier and theme.Glow or Color3.new(.12,.13,.16);pip.Parent=row
            local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.5,0);corner.Parent=pip
        end
    end
    -- Every tier: one themed burst when a run starts (emitted once by the client, never continuous).
    local start=att('Start burst',V(0,.8,0))
    local burstColor=({seq(RGB(168,232,110),RGB(255,240,150)),seq(RGB(255,222,109),RGB(90,220,150)),seq(RGB(255,236,170),RGB(232,141,90)),
        seq(RGB(235,255,255),RGB(120,210,255)),seq(RGB(255,230,90),RGB(255,90,20)),seq(RGB(255,170,250),RGB(130,240,230),RGB(255,250,170)),
        seq(RGB(255,255,230),RGB(120,180,255))})[tier]
    emit(start,'Start sparkle burst','Burst',2,{Color=burstColor,Burst=6+tier*3,Life={.5,1.1},Speed={6,10+tier},Size=.25+tier*.04,Spread=80,Drag=3,Accel=V(0,-3,0)})
    if tier>=5 then
        emit(start,'Start flare burst','Burst',3,{Color=seq(theme.Glow),Burst=tier-3,Life={.25,.4},Speed={0,0},Size=4+tier,Texture='flare',Light=1})
        -- Edge lights frame the belt and breathe faster while someone trains.
        for side=-1,1,2 do
            pulse(P('Belt edge light',V(.12,.05,12.6*1.2),CF(side*4.5,.27,0),theme.Glow,Enum.Material.Neon),.45,1.4,side*.5)
        end
    end

    if tier==1 then
        for side=-1,1,2 do
            local x=side*6.75
            R('Lantern cord',V(x,4.15,-2.2),V(x,3.55,-2.2),.08,theme.Ink,Enum.Material.Wood)
            S('Lantern cap',V(.62,.22,.62),CF(x,3.58,-2.2),theme.Ink,Enum.Material.Wood)
            local lamp=pulse(S('Firefly lantern',V(.55,.72,.55),CF(x,3.18,-2.2),RGB(255,214,120),Enum.Material.Neon),.3,.9,side)
            glow(lamp,'Lantern glow',RGB(255,205,120),.8,10,2)
            R('Mushroom stem',V(side*6.75,-.85,5.2),V(side*6.75,-.05,5.2),.38,RGB(240,229,205))
            S('Mushroom cap',V(1.1,.5,1.1),CF(side*6.75,.05,5.2),RGB(214,83,64))
        end
        emit(att('Fireflies',V(0,3.2,0)),'Fireflies','Ambient',2,{Color=seq(RGB(214,255,120)),Rate=2,Life={2.5,4},Speed={.4,1},Size=.18,Spread=180,Drag=.6})
        emit(att('Leaf trail',V(0,.5,6.2)),'Leaf trail','Training',3,{Color=seq(RGB(120,200,90),RGB(200,170,80)),Rate=4,Life={.6,1.1},Speed={1.5,3},Size=.16,Spread=45,Accel=V(0,-2,0)})
    elseif tier==2 then
        for side=-1,1,2 do
            local x=side*6.1
            R('Temple brazier bowl',V(x,4.1,-5.95),V(x,4.55,-5.95),1.35,theme.Glow,Enum.Material.Metal)
            local flame=pulse(S('Brazier flame',V(.85,1.05,.85),CF(x,4.95,-5.95),RGB(255,160,60),Enum.Material.Neon),.35,2.2,side)
            glow(flame,'Brazier glow',RGB(255,170,80),.9,12,2,true)
            emit(att('Brazier embers',V(x,5.2,-5.95)),'Brazier embers','Ambient',2,{Color=seq(RGB(255,220,120),RGB(255,110,40)),Rate=5,Life={.6,1.2},Speed={1.5,2.6},Size=.16,Spread=18,Drag=1})
            pulse(keep(rawp('Jade idol eye',V(.7,.7,.25),CF(side*3.45,4.55,TREADMILL_FRONT_FACE[2]-.08),theme.Trim,Enum.Material.Neon)),.35,1.1,0)
            S('Vine blossom',V(.42,.42,.42),CF(x+side*.74,1.5,-6.1),RGB(255,120,170),Enum.Material.Neon)
            S('Vine blossom',V(.42,.42,.42),CF(x+side*.36,2.85,-6.55),RGB(255,236,120),Enum.Material.Neon)
        end
        emit(att('Jungle pollen',V(0,3.4,-1)),'Jungle pollen','Ambient',3,{Color=seq(RGB(255,236,140)),Rate=2,Life={2.5,4},Speed={.3,.8},Size=.12,Spread=180,Drag=.4})
    elseif tier==3 then
        pulse(named('Giant sun crest heart'),.3,.8,0)
        glow(named('Giant sun crest heart')or plaque,'Sun crest glow',RGB(255,220,140),1,14,2)
        for side=-1,1,2 do
            local x=side*6.1
            local shell=keep(rawp('Scarab shell',V(.8,1.0,.3),CF(x,2.9,-8.72),theme.Trim,Enum.Material.Metal));shell.Shape=Enum.PartType.Ball
            local gem=keep(rawp('Scarab gem',V(.36,.36,.16),CF(x,3.3,-8.84),theme.Glow,Enum.Material.Neon));gem.Shape=Enum.PartType.Ball
            pulse(gem,.4,1.2,side)
            pulse(S('Sunstone finial',V(.72,.72,.72),CF(x,2.85,3.9),theme.Glow,Enum.Material.Neon),.3,.8,side*.5)
        end
        emit(att('Sun glints',V(0,6.55,-6.3)),'Sun glints','Ambient',2,{Color=seq(RGB(255,250,200)),Rate=3,Life={.8,1.4},Speed={1,2},Size=.22,Spread=180,Drag=1.5})
        emit(att('Sand swirl',V(0,.2,0)),'Sand swirl','Ambient',3,{Color=seq(RGB(235,200,140)),Rate=1.5,Life={2,3},Speed={.5,1},Size=1.2,Texture='smoke',Spread=90,Accel=origin:VectorToWorldSpace(V(.6,.2,0))})
        emit(att('Kicked sand',V(0,.4,6.4)),'Kicked sand','Training',2,{Color=seq(RGB(240,205,150)),Rate=6,Life={.6,1},Speed={2,3.5},Size=.8,Texture='smoke',Spread=35,Accel=V(0,-1,0)})
    elseif tier==4 then
        for j,x in ipairs({-4,-2.3,0,2.3,4})do
            local len=.9+((j+1)%3)*.35
            local icicle=keep(rawp('Hanging icicle',V(.32,len,.32),CF(x,2.75-len/2+.15,-7.95),theme.Glow,Enum.Material.Ice))
            icicle.Shape=Enum.PartType.Ball;icicle.Transparency=.2
        end
        for _,heart in ipairs(allNamed('Frozen crown luminous heart'))do pulse(heart,.35,1,heart.Position.X)end
        local crown=named('Frozen crown luminous heart')
        glow(crown or plaque,'Glacier glow',RGB(170,235,255),1,14,2)
        local a0,a1=att('Aurora left',V(-6.5,7.8,-6.6),true),att('Aurora right',V(6.5,7.8,-6.6),true)
        arc('Aurora ribbon',a0,a1,seq(RGB(110,255,200),RGB(120,200,255),RGB(190,140,255)),1.8,4.5,2,'Ribbon')
        emit(att('Snowfall',V(0,9.5,-1)),'Snowfall','Ambient',2,{Color=seq(RGB(245,252,255)),Rate=4,Life={4,6},Speed={.6,1.2},Size=.2,Spread=75,Dir=Enum.NormalId.Bottom,Accel=V(0,-.4,0),Light=.3})
        emit(att('Frost breath',V(0,.5,6.3)),'Frost breath','Training',3,{Color=seq(RGB(230,250,255)),Rate=4,Life={.8,1.3},Speed={1,2},Size=.9,Texture='smoke',Spread=40})
    elseif tier==5 then
        for side=-1,1,2 do
            local x=side*6.1
            pulse(P('Lava channel',V(.18,.22,12.4*1.2),CF(side*6.26,-.35,0),RGB(255,110,30),Enum.Material.Neon),.4,1.1,side)
            for j=1,4 do pulse(P('Magma vent slit',V(.1,.12,.9),CF(side*6.27,-.62,(j-2.5)*3),RGB(255,190,60),Enum.Material.Neon),.6,2.4,j*.8)end
            for j=1,3 do keep(rawp('Forge grate',V(1.2,.14,.1),CF(x,1.2+j*.5,-8.9),RGB(255,150,50),Enum.Material.Neon))end
            -- Rear magma pylons: basalt column, crucible and a breathing molten pool.
            R('Magma pylon column',V(x,-.7,7.2),V(x,3.2,7.2),1.1,theme.Ink,Enum.Material.Basalt)
            R('Magma pylon ring',V(x,2.6,7.2),V(x,2.85,7.2),1.35,theme.Trim,Enum.Material.Neon)
            R('Magma pylon crucible',V(x,3.2,7.2),V(x,3.75,7.2),1.6,theme.Body,Enum.Material.Basalt)
            local pool=pulse(S('Magma pylon pool',V(1.25,.4,1.25),CF(x,3.78,7.2),RGB(255,150,40),Enum.Material.Neon),.3,1.6,side)
            for j=-1,1,2 do P('Basalt crucible spike',V(.35,.9,.35),CF(x+j*.62,4.05,7.2)*CFrame.Angles(0,0,-j*.35),theme.Ink,Enum.Material.Basalt,'WedgePart')end
            glow(pool,'Crucible glow',RGB(255,140,50),1.1,12,2,true)
            local top=att('Pylon embers',V(x,4,7.2))
            emit(top,'Pylon embers','Ambient',2,{Color=seq(RGB(255,230,120),RGB(255,90,20)),Rate=5,Life={1,1.8},Speed={2,3.5},Size=.18,Spread=20,Drag=.5})
            emit(top,'Pylon smoke','Ambient',3,{Color=seq(RGB(70,60,66)),Rate=1.2,Life={2.5,3.5},Speed={1.5,2.5},Size=1.3,Texture='smoke',Spread=12,Light=0})
            for j=1,3 do P('Rail magma spike',V(.5,.9,.5),CF(x,3.55+j*.3,3.9-j*2.6)*CFrame.Angles(0,0,-side*.25),theme.Ink,Enum.Material.Basalt,'WedgePart')end
            pulse(keep(rawp('Magma cascade',V(.55,2.6,.08),CF(side*3.4,4.05,TREADMILL_FRONT_FACE[5]-.045),RGB(255,120,30),Enum.Material.Neon)),.35,1.8,side)
            emit(att('Belt flames',V(side*4.4,.4,0)),'Belt flames','Training',2,{Color=seq(RGB(255,220,90),RGB(255,70,20)),Rate=9,Life={.35,.7},Speed={1.5,3},Size=.3,Spread=25,Light=1})
            for _,z in ipairs({-6.6,6.6})do
                keep(rawp('Lava seep',V(1.4,.12,1.0),CF(side*6.9,-.86,z*1.2),RGB(255,120,30),Enum.Material.Neon)).Shape=Enum.PartType.Ball
            end
        end
        -- Three molten rocks orbit the front sigil in the plane facing outwards.
        local pivot=CF(longer(V(0,6.15,-6.35)))*CFrame.Angles(math.rad(-12),0,0)
        for j=1,3 do
            local a=j*math.pi*2/3
            spin(orbiter('Orbiting magma rock',V(.66,.52,.6),pivot*CF(math.cos(a)*2.1,0,math.sin(a)*2.1)*CFrame.Angles(a,a*.5,0),theme.Ink,Enum.Material.Basalt,true),pivot,.9,2)
            spin(orbiter('Orbiting magma core',V(.36,.36,.36),pivot*CF(math.cos(a)*2.1,.28,math.sin(a)*2.1),RGB(255,170,50),Enum.Material.Neon,true),pivot,.9,2)
        end
        for j=1,4 do
            local a=math.rad(-10+j*40)
            P('Forge crown spike',V(.4,1.0,.4),CF(math.cos(a)*1.7,6.15+math.sin(a)*1.7,-6.4)*CFrame.Angles(0,0,a-math.pi/2),theme.Ink,Enum.Material.Basalt,'WedgePart')
        end
        local halo=keep(k.frontDisc('Sigil halo',V(0,6.15,-6.2),1.55,.1,RGB(255,120,30),Enum.Material.Neon));halo.Transparency=.35
        pulse(halo,.4,1.3,0)
        for _,tip in ipairs(allNamed('Molten horn tip'))do pulse(tip,.3,1.5,tip.Position.X)end
        glow(named('Molten front sigil luminous heart')or plaque,'Sigil glow',RGB(255,150,60),1.2,14,2)
        glow(att('Underglow',V(0,-.55,0)),'Lava underglow',RGB(255,110,40),1.3,15,3)
        emit(att('Sigil embers',V(0,6.15,-6.4)),'Sigil embers','Ambient',3,{Color=seq(RGB(255,200,90)),Rate=3,Life={.8,1.4},Speed={1,2},Size=.16,Spread=180,Drag=1.2})
    elseif tier==6 then
        for _,v in ipairs(allNamed('Prism inlay'))do hue(v,v.Position.Z*.07)end
        for i,v in ipairs(allNamed('Crystal crown brace'))do hue(v,i*.5)end
        for side=-1,1,2 do
            local x=side*6.3
            hue(R('Prism light pillar',V(x,3.85,3.7),V(x,6.6,3.7),.22,theme.Glow,Enum.Material.Neon),side*.25)
            local tip=hue(S('Prism pillar star',V(.55,.55,.55),CF(x,6.75,3.7),theme.Glow,Enum.Material.Neon),side*.25)
            glow(tip,'Prism pillar light',theme.Glow,.9,11,3)
            hue(glow(att('Front prism light',V(x,4.4,-6.2)),'Front prism light',theme.Trim,1,13,2),side*.3)
            emit(att('Rail glints '..side,V(x,4,0)),'Rail prism motes','Ambient',3,{Color=seq(RGB(255,170,250),RGB(130,240,230)),Rate=2,Life={1.5,2.5},Speed={.3,.8},Size=.16,Spread=180,Drag=.5})
        end
        -- Six prism shards orbit the crown centerpiece.
        local pivot=CF(longer(V(0,6.4,-6.3)))
        for j=1,6 do
            local a=j*math.pi/3
            local frame=pivot*CF(math.cos(a)*2.4,j%2==0 and .5 or -.35,math.sin(a)*2.4)*CFrame.Angles(math.pi/4,a,math.pi/4)
            local shard=orbiter('Orbiting prism shard',V(.42,.85,.42),frame,j%2==0 and theme.Trim or RGB(255,170,245),Enum.Material.Neon,false)
            hue(shard,j/6);spin(shard,pivot,.7,2)
        end
        local a0,a1=att('Rainbow left',V(-6.3,7.6,-6.1),true),att('Rainbow right',V(6.3,7.6,-6.1),true)
        arc('Rainbow arch',a0,a1,seq(RGB(255,90,90),RGB(255,190,70),RGB(255,250,110),RGB(110,240,140),RGB(100,190,255),RGB(190,120,255)),1.4,5.5,2,'Ribbon')
        emit(att('Crown glints',V(0,6.4,-6.3)),'Crown glints','Ambient',2,{Color=seq(RGB(255,255,255),RGB(255,190,250),RGB(150,255,240)),Rate=5,Life={.8,1.5},Speed={1.5,3},Size=.24,Spread=180,Drag=1.5})
        emit(att('Rainbow trail',V(0,.5,6.3)),'Rainbow trail','Training',2,{Color=seq(RGB(255,120,120),RGB(255,240,120),RGB(120,255,180),RGB(140,170,255),RGB(240,140,255)),Rate=10,Life={.5,.9},Speed={2,4},Size=.22,Spread=40,Drag=1})
    elseif tier==7 then
        local live=RGB(150,205,255)
        local coilTops={}
        for side=-1,1,2 do
            local x=side*6.1
            -- Tesla coils on both power housings.
            R('Tesla coil core',V(x,5.6,-6.5),V(x,8.35,-6.5),.45,theme.Ink,Enum.Material.Metal)
            for j=1,3 do
                local y=6.3+j*.55
                local ring=R('Tesla coil ring',V(x,y,-6.5),V(x,y+.14,-6.5),1.25-j*.15,j==2 and live or RGB(214,140,70),j==2 and Enum.Material.Neon or Enum.Material.Metal)
                if j==2 then pulse(ring,.4,3,side)end
            end
            R('Tesla crown ring',V(x,8.45,-6.5),V(x,8.6,-6.5),1.75,theme.Body,Enum.Material.Metal)
            local crown=pulse(S('Tesla crown orb',V(1.1,1.1,1.1),CF(x,8.85,-6.5),theme.Glow,Enum.Material.Neon),.3,2.6,side)
            glow(crown,'Tesla glow',live,1.2,14,2,true)
            local top=att('Tesla top '..side,V(x,9.0,-6.5),true);coilTops[side]=top
            emit(top,'Tesla sparks','Ambient',2,{Color=seq(RGB(255,255,255),live),Rate=6,Life={.15,.35},Speed={5,9},Size=.2,Spread=180,Light=1})
            -- Rail lightning spires, rear capacitor banks, swept thunder wings and charge cells.
            for _,z in ipairs({2.0,-1.6})do
                R('Storm spire',V(x,z==2.0 and 3.45 or 4.05,z),V(x,(z==2.0 and 3.45 or 4.05)+1.7,z),.16,theme.Body,Enum.Material.Metal)
                pulse(S('Storm spire tip',V(.36,.36,.36),CF(x,(z==2.0 and 3.45 or 4.05)+1.85,z),theme.Glow,Enum.Material.Neon),.5,3.4,z)
            end
            R('Capacitor bank',V(x,-.7,7.2),V(x,2.6,7.2),1.15,theme.Ink,Enum.Material.Metal)
            for j=1,2 do pulse(R('Capacitor charge band',V(x,.3+j*.8,7.2),V(x,.48+j*.8,7.2),1.25,live,Enum.Material.Neon),.5,2.2,j)end
            S('Capacitor insulator',V(.9,.7,.9),CF(x,2.85,7.2),RGB(235,240,250),Enum.Material.Glass)
            -- Swept wing feathers: each leaves the housing's outer side and climbs outwards.
            for j=1,3 do
                local a,length=math.rad(10+j*15),2.7-j*.35
                local root=V(x+side*.95,2.7+j*.75,-6.5)
                local frame=CF(root+V(side*math.cos(a),math.sin(a),0)*length/2)*CFrame.Angles(0,0,side*a)
                P('Thunder wing blade',V(length,.26,1.1-j*.15),frame,theme.Body,Enum.Material.Metal)
                pulse(P('Thunder wing edge',V(length*.94,.09,.3),frame*CF(0,.17,0),theme.Glow,Enum.Material.Neon),.35,2,j)
            end
            for j=1,6 do pulse(P('Charge cell',V(.14,.3,1.15),CF(side*6.26,-.35,(3.5-j)*1.75),live,Enum.Material.Neon),.75,6,-j*1.05)end
        end
        -- Conductor arch over the belt: the runner passes under a live lightning gate.
        local archPoints={V(-5.9,4.3,-3.2),V(-4.4,7.4,-3.2),V(-1.6,8.6,-3.2),V(1.6,8.6,-3.2),V(4.4,7.4,-3.2),V(5.9,4.3,-3.2)}
        k.railPath('Conductor arch',archPoints,.5,theme.Ink,Enum.Material.Metal)
        for _,v in ipairs(m:GetChildren())do if v.Name=='Conductor arch'or v.Name=='Conductor arch joint'then keep(v)end end
        local archNodes={}
        for j=2,5 do
            local node=pulse(S('Arch conductor node',V(.55,.55,.55),CF(archPoints[j]-V(0,.42,0)),theme.Glow,Enum.Material.Neon),.5,4,j)
            table.insert(archNodes,att('Arch node '..j,archPoints[j]-V(0,.5,0),true))
            if j==3 then glow(node,'Arch glow',live,1,12,3,true)end
        end
        -- Storm cloud above the crest; its core flashes when lightning strikes.
        for j,s in ipairs({{-2.6,10.4,1.7},{-1.1,11.0,2.1},{.7,11.15,2.3},{2.4,10.6,1.8},{-.3,10.2,1.9},{1.4,10.0,1.5},{-1.9,10.0,1.4},{3.3,10.15,1.2}})do
            local puff=S('Storm cloud puff',V(s[3]*1.6,s[3],s[3]*1.25),CF(s[1],s[2],-7.2),j%2==0 and RGB(64,72,98)or RGB(84,92,120))
            puff.Transparency=.12
        end
        local core=S('Storm cloud core',V(2.6,1.2,1.4),CF(.2,10.4,-7.15),live,Enum.Material.Neon);core.Transparency=.55
        core:SetAttribute('TreadmillFlashCore',true)
        glow(core,'Storm cloud flash',RGB(200,225,255),1.6,18,3,true)
        local cloud=att('Storm cloud',V(.2,10,-7.2))
        emit(cloud,'Storm drizzle','Ambient',3,{Color=seq(RGB(170,200,255)),Rate=7,Life={.6,.9},Speed={9,12},Size=.07,Spread=14,Dir=Enum.NormalId.Bottom,Light=.4})
        -- Energy orbs circle the giant front lightning crest.
        local crest=V(0,6.35,-6.3)
        local pivot=CF(longer(crest))*CFrame.Angles(math.rad(-20),0,0)
        for j=1,3 do
            local a=j*math.pi*2/3
            spin(orbiter('Orbiting energy orb',V(.55,.55,.55),pivot*CF(math.cos(a)*2.6,0,math.sin(a)*2.6),theme.Glow,Enum.Material.Neon,true),pivot,1.6,2)
        end
        local halo=keep(k.frontDisc('Crest halo',V(0,6.35,-6.0),2.0,.1,live,Enum.Material.Neon));halo.Transparency=.4
        pulse(halo,.45,2.2,0)
        keep(k.frontDisc('Crest backplate',V(0,6.35,-5.92),1.85,.12,theme.Ink,Enum.Material.Metal))
        local crestNode=att('Crest strike',crest+V(0,.6,-.4),true)
        -- Lightning arcs: flickered on the client, more often while someone trains.
        arc('Coil bridge arc',coilTops[-1],coilTops[1],seq(RGB(255,255,255),live),.35,3.5,2)
        arc('Left strike arc',coilTops[-1],crestNode,seq(live,RGB(255,255,255)),.25,1.2,2)
        arc('Right strike arc',coilTops[1],crestNode,seq(live,RGB(255,255,255)),.25,-1.2,2)
        arc('Cloud strike arc',att('Cloud base',V(.2,9.6,-7.2),true),crestNode,seq(RGB(255,255,255),live),.4,.8,3)
        arc('Arch lightning',archNodes[1],archNodes[4],seq(live,RGB(255,255,255)),.3,1.4,2)
        glow(att('Storm underglow',V(0,-.55,0)),'Storm underglow',RGB(110,160,255),1.2,15,3)
        for side=-1,1,2 do
            emit(att('Static motes '..side,V(side*4.2,.45,0)),'Static motes','Training',2,{Color=seq(RGB(255,255,255),live),Rate=10,Life={.2,.45},Speed={2,5},Size=.16,Spread=60,Light=1})
        end
        emit(start,'Thunderclap sparks','Burst',2,{Color=seq(RGB(255,255,255),live),Burst=26,Life={.3,.7},Speed={12,20},Size=.18,Spread=180,Drag=4,Light=1})
    end
    return made
end
function Art.BuildTreadmillV131(base,tier)
    tier=math.clamp(math.floor(tonumber(tier)or 1),1,7)
    local theme=treadmillThemes[tier]
    local pad=assert(base:FindFirstChild('Pad'),'Treadmill base needs Pad')
    local belt=base:FindFirstChild('Treadmill')
    assert(not belt or belt:GetAttribute('TreadmillVersion')==131,'Unrecognized treadmill; preserve it and stop')
    local old=base:FindFirstChild('TreadmillArtV131')
    assert(not old or old:GetAttribute('TreadmillVersion')==131,'Unrecognized treadmill art')
    -- V138: entrance-side apron, beyond the garden beds and beside the clear spawn aisle.
    local origin=pad.CFrame*CF(-34,pad.Size.Y/2+.90,75)*CFrame.Angles(0,math.pi,0)
    local m=Instance.new('Model');m.Name='TreadmillArtV131';m:SetAttribute('TreadmillVersion',131)
    m:SetAttribute('TreadmillLengthVersion',137);m:SetAttribute('TreadmillEntranceVersion',138);m:SetAttribute('TreadmillFrameVersion',135);m:SetAttribute('TreadmillArrowVersion',137);m:SetAttribute('TreadmillTrackVersion',133);m:SetAttribute('TreadmillPolishVersion',132);m:SetAttribute('SkinTier',tier)
    -- V137: lengthen the running deck and connecting frame, keeping ornament shapes intact.
    local lengthScale=1.2
    local function longer(v)return V(v.X,v.Y,v.Z*lengthScale)end
    local function longerFrame(frame)return CF(longer(frame.Position))*frame.Rotation end
    local function rawp(name,size,offset,color,material,class)
        return part(m,name,size,origin*offset,color or theme.Body,material or Enum.Material.SmoothPlastic,class)
    end
    local function p(name,size,offset,color,material,class)
        if name=='Track underlay'or name=='Track surface'or name=='Electric lane'or name=='Tall glacier fin'then
            size=V(size.X,size.Y,size.Z*lengthScale)
        end
        local frame=longerFrame(offset)
        -- Keep screen/buttons and the badge face fitted to their rigid backing.
        local rigidAnchor=(name=='Console screen'or name=='Console button')and -5.95 or name=='Badge star'and 2.2 or nil
        if rigidAnchor then frame=CF(offset.Position+V(0,0,rigidAnchor*(lengthScale-1)))*offset.Rotation end
        return rawp(name,size,frame,color,material,class)
    end
    local function sphere(name,size,frame,color,material)
        local v=p(name,size,frame,color,material);v.Shape=Enum.PartType.Ball;return v
    end
    local function rod(name,a,b,width,color,material,caps)
        a=longer(a);b=longer(b)
        local delta=b-a
        local frame=CFrame.lookAt((a+b)/2,b,math.abs(delta.Unit.Y)>.98 and Vector3.zAxis or Vector3.yAxis)
        local r=rawp(name,V(delta.Magnitude,width,width),frame*CFrame.Angles(0,math.pi/2,0),color,material)
        r.Shape=Enum.PartType.Cylinder
        if caps then
            local capA=rawp(name..' cap A',V(width,width,width),CF(a),color,material);capA.Shape=Enum.PartType.Ball
            local capB=rawp(name..' cap B',V(width,width,width),CF(b),color,material);capB.Shape=Enum.PartType.Ball
        end
        return r
    end
    -- Rounded horizontal slab: four native cylindrical corners and three infill bars.
    local function slab(name,width,depth,height,radius,frame,color,material)
        frame=longerFrame(frame)
        if name=='Rounded chassis'then depth*=lengthScale end
        rawp(name,V(width-radius*2,height,depth),frame,color,material)
        for _,sign in ipairs({-1,1})do
            rawp(name,V(radius,height,depth-radius*2),frame*CF(sign*(width/2-radius/2),0,0),color,material)
            for _,z in ipairs({-1,1})do
                local corner=rawp(name..' rounded corner',V(height,radius*2,radius*2),
                    frame*CF(sign*(width/2-radius),0,z*(depth/2-radius))*CFrame.Angles(0,0,math.pi/2),color,material)
                corner.Shape=Enum.PartType.Cylinder
            end
        end
    end
    -- V135: large native frame silhouettes. These parts are static and non-colliding.
    local function railPath(name,points,width,color,material)
        for j=1,#points-1 do rod(name,points[j],points[j+1],width,color,material)end
        for _,point in ipairs(points)do sphere(name..' joint',V(width,width,width),CF(point),color,material)end
    end
    local function diamond(name,frame,width,height,depth,color,ice)
        local points={V(-width/2,0,0),V(0,0,-depth/2),V(width/2,0,0),V(0,0,depth/2)}
        local top,bottom=V(0,height*.58,0),V(0,-height*.42,0)
        local shell=Instance.new('Model');shell.Name=name;shell.Parent=m
        local outerFrame=longerFrame(frame)
        local material=ice and Enum.Material.Ice or Enum.Material.Glass
        for j=1,4 do
            local k=j%4+1
            local tint=color:Lerp(j%2==0 and Color3.new(1,1,1)or theme.Ink,j%2==0 and .32 or .12)
            triangle(shell,name..' upper facet',origin*outerFrame*points[j],origin*outerFrame*points[k],origin*outerFrame*top,tint,material)
            triangle(shell,name..' lower facet',origin*outerFrame*points[k],origin*outerFrame*points[j],origin*outerFrame*bottom,tint,material)
        end
        for _,v in ipairs(shell:GetChildren())do
            v.Transparency=ice and .26 or .12;v.Reflectance=.12;v.CastShadow=false
        end
        sphere(name..' luminous heart',V(width*.36,height*.30,depth*.36),frame,color,Enum.Material.Neon)
    end
    local function frontDisc(name,center,radius,thickness,color,material)
        local v=p(name,V(thickness,radius*2,radius*2),CF(center)*CFrame.Angles(0,math.pi/2,0),color,material)
        v.Shape=Enum.PartType.Cylinder;return v
    end
    slab('Rounded chassis',12.4,16.4,.80,1.15,CF(0,-.39,0),theme.Body)
    for _,x in ipairs({-5.55,5.55})do
        rod('Soft side bumper',V(x,.22,-6.55),V(x,.22,6.55),.86,theme.Trim,nil,true)
        for _,z in ipairs({-5.95,5.95})do
            sphere('Chunky foot',V(1.75,.58,2.10),CF(x,-.61,z),theme.Ink)
        end
    end
    for _,z in ipairs({-6.55,6.55})do
        local roller=p('Wide roller',V(10.2,.82,.82),CF(0,-.02,z),theme.Ink);roller.Shape=Enum.PartType.Cylinder
        for _,x in ipairs({-5.13,5.13})do sphere('Roller cap',V(.22,.84,.84),CF(x,-.02,z),theme.Glow)end
    end
    -- A wide, rounded console with large playful pictograms and no floating rate text.
    local consoleFrame=CF(0,4.15,-5.95)*CFrame.Angles(math.rad(78),0,0)
    slab('Console shell',8.3,2.5,.85,.63,consoleFrame,theme.Trim)
    local glass=p('Console screen',V(6.9,1.74,.07),CF(0,4.19,-5.44)*CFrame.Angles(math.rad(-12),0,0),theme.Ink)
    local face=Instance.new('SurfaceGui');face.Name='ConsoleDisplay';face.Face=Enum.NormalId.Back
    face.CanvasSize=Vector2.new(690,174);face.LightInfluence=.4;face.Parent=glass
    -- Clear console screen; no slogan or repeated jump instructions.
    for _,x in ipairs({-3.55,3.55})do sphere('Console button',V(.35,.35,.17),CF(x,3.75,-5.35),theme.Glow)end
    -- Upgrade prompt belongs to a small side badge, away from the runner's body.
    local badge=sphere('Upgrade badge',V(1.15,1.15,.35),CF(6.35,1.9,2.2),theme.Glow)
    p('Badge star',V(.13,.64,.05),CF(6.35,1.9,2.0),theme.Ink)
    p('Badge star',V(.64,.13,.05),CF(6.35,1.9,2.0),theme.Ink)
    local prompt=Instance.new('ProximityPrompt');prompt.Name='TreadmillMenu';prompt.ActionText='';prompt.ObjectText='';prompt.Enabled=false
    prompt.MaxActivationDistance=9;prompt.RequiresLineOfSight=false;prompt.HoldDuration=0;prompt:SetAttribute('TreadmillVersion',131);prompt.Parent=badge
    -- V133: the training collider stays fixed; every themed surface is cosmetic.
    local beltSize=V(9.4,.4,13.2*lengthScale)
    local trackColors={RGB(37,50,66),RGB(34,67,57),RGB(218,166,91),RGB(146,228,250),RGB(244,75,28),RGB(127,133,215),RGB(29,48,100)}
    local trackMaterials={Enum.Material.SmoothPlastic,Enum.Material.SmoothPlastic,Enum.Material.Sand,Enum.Material.Ice,Enum.Material.Neon,Enum.Material.Glass,Enum.Material.Metal}
    local underlay=p('Track underlay',V(9.2,.12,12.8),CF(0,.065,0),tier==4 and RGB(43,134,193)or tier==6 and RGB(91,68,160)or theme.Ink)
    local surface=p('Track surface',V(9.2,.12,12.8),CF(0,.18,0),trackColors[tier],trackMaterials[tier])
    surface.Transparency=(tier==4 and .42)or(tier==6 and .35)or 0
    surface.Reflectance=(tier==4 or tier==6)and .12 or 0
    underlay.CastShadow=false;surface.CastShadow=false
    local function motion(v,kind,phase,rest,rate,alpha,pulse)
        v:SetAttribute('TrackMotion',kind);v:SetAttribute('TrackPhase',phase)
        v:SetAttribute('TrackRest',rest);v:SetAttribute('TrackRate',rate or 1)
        v:SetAttribute('TrackTravel',10.8*lengthScale)
        v:SetAttribute('TrackAlpha',alpha or 0);v:SetAttribute('TrackPulse',pulse==true)
        v.Transparency=alpha or 0;v.CastShadow=false
        v.CFrame=origin*CF(0,0,(phase-.5)*10.8*lengthScale)*rest
        return v
    end
    local function flatLine(name,a,b,width,color,material)
        a=longer(a);b=longer(b)
        local delta=b-a
        return rawp(name,V(width,.024,delta.Magnitude),CFrame.lookAt((a+b)/2,b),color,material)
    end
    -- V137: two solid chevrons, with no stems; five studs between their centres.
    local arrowColor=tier==3 and RGB(255,247,218)or tier==4 and RGB(237,255,255)or theme.Glow
    for i=1,2 do
        local phase=(i-.5)/2
        for layer=1,2 do
            local y=layer==1 and .278 or .322
            local width=layer==1 and 4.10 or 3.92
            local tip=layer==1 and -1.58 or -1.42
            local shoulder=layer==1 and .50 or .60
            local notch=layer==1 and -.24 or -.40
            local tail=layer==1 and 1.84 or 1.62
            local color=layer==1 and RGB(29,42,66)or arrowColor
            local material=layer==1 and Enum.Material.SmoothPlastic or Enum.Material.Neon
            local faces=Instance.new('Model')
            local name=string.format('ForwardChevron%02d_%d',i,layer)
            quad(faces,name,origin*V(-width,y,shoulder),origin*V(0,y,tip),origin*V(0,y,notch),origin*V(-width,y,tail),color,material)
            quad(faces,name,origin*V(0,y,tip),origin*V(width,y,shoulder),origin*V(width,y,tail),origin*V(0,y,notch),color,material)
            for _,chevron in ipairs(faces:GetChildren())do
                local rest=origin:ToObjectSpace(chevron.CFrame)
                motion(chevron,'Arrow',phase,rest,1,layer==1 and .12 or 0)
                chevron:SetAttribute('ChevronIndex',i);chevron:SetAttribute('ChevronLayer',layer)
                chevron:SetAttribute('TrackTravel',10)
                chevron.CFrame=origin*CF(0,0,(phase-.5)*10)*rest
                chevron.Parent=m
            end
            faces:Destroy()
        end
    end
    local function flow(name,size,frame,color,material,phase,rate,alpha,pulse)
        return motion(p(name,size,frame,color,material),'Flow',phase,longerFrame(frame),rate,alpha,pulse)
    end
    if tier==3 then
        for side=-1,1,2 do
            for i=1,6 do
                local frame=CF(side*(1.6+(i%3)*.9),.267,0)*CFrame.Angles(0,side*.32,0)
                flow('Drifting sand ripple',V(.09,.02,.85+i%3*.25),frame,i%2==0 and RGB(255,226,163)or RGB(168,116,64),Enum.Material.Sand,(i-.5)/6,.62,.18)
            end
            for i=1,5 do
                local grain=flow('Sand grain',V(.08+(i%2)*.03,.035,.15),CF(side*(1.2+(i%4)*.73),.276,0),RGB(255,237,182),Enum.Material.Sand,(i-.25)/5,.84,.12)
            end
        end
    elseif tier==4 then
        for side=-1,1,2 do
            for i=1,4 do
                local facet=p('Frozen depth facet',V(1.1,.035,2.1),CF(side*(1.8+(i%2)*1.6),.143,(i-2.5)*2.7)*CFrame.Angles(0,side*.35,0),RGB(208,255,255),Enum.Material.Ice)
                facet.Transparency=.27
                flow('Frost reflection',V(.12,.02,1.35),CF(side*(1.3+(i%3)*1.1),.263,0)*CFrame.Angles(0,side*.5,0),RGB(227,255,255),Enum.Material.Neon,(i-.5)/4,.58,.34,true)
            end
            for i=1,3 do
                local a=V(side*3.0,.262,(i-2)*3.5);local b=a+V(side*.65,0,-.8)
                flatLine('Hairline ice vein',a,b,.035,RGB(207,250,255),Enum.Material.Neon).Transparency=.35
            end
        end
    elseif tier==5 then
        for side=-1,1,2 do
            for i=1,5 do
                local phase=(i-.5)/5
                local frame=CF(side*(1.35+(i%3)*.98),.263,0)*CFrame.Angles(0,side*(.2+(i%2)*.35),0)
                local current=flow('Molten current',V(.35+(i%2)*.34,.035,1.55),frame,i%2==0 and RGB(255,197,55)or RGB(255,125,24),Enum.Material.Neon,phase,1.12,.10,true)
                current.Shape=Enum.PartType.Ball
                local crust=flow('Floating basalt flake',V(.65,.045,.8),CF(side*(2+(i%3)*.8),.28,0)*CFrame.Angles(0,i*.7,0),RGB(66,43,55),Enum.Material.Basalt,(phase+.07)%1,.9,.05)
            end
        end
    elseif tier==6 then
        for side=-1,1,2 do
            for i=1,4 do
                local facet=p('Prism inlay',V(1.1,.035,1.6),CF(side*(1.5+(i%2)*1.6),.143,(i-2.5)*2.6)*CFrame.Angles(0,math.pi/4,0),i%2==0 and theme.Trim or RGB(242,170,248),Enum.Material.Neon)
                facet.Transparency=.28
                local phase=(i-.5)/4
                for axis=1,2 do
                    flow('Travelling prism glint',axis==1 and V(.09,.022,.55)or V(.55,.022,.09),CF(side*(1.4+(i%3)*1.0),.266,0),i%2==0 and RGB(192,255,245)or RGB(255,225,255),Enum.Material.Neon,phase,.73,.13,true)
                end
            end
        end
    elseif tier==7 then
        for side=-1,1,2 do
            p('Electric lane',V(.065,.022,12.3),CF(side*3.6,.264,0),RGB(75,141,255),Enum.Material.Neon).Transparency=.22
            for i=1,3 do
                local phase=(i-.5)/3
                local x=side*(2.05+(i%2)*.9)
                local points={V(x,.28,.72),V(x-side*.40,.28,.17),V(x+side*.24,.28,.17),V(x-side*.14,.28,-.75)}
                for j=1,3 do
                    local bolt=flatLine('Travelling lightning',points[j],points[j+1],.16,theme.Glow,Enum.Material.Neon)
                    motion(bolt,'Flow',phase,origin:ToObjectSpace(bolt.CFrame),1.8,.06,true)
                end
            end
        end
    end
    -- Two sparse emitters per advanced machine, enabled by the nearby client only.
    if tier>=3 then
        for side=-1,1,2 do
            local socket=Instance.new('Attachment');socket.Name='Track effects';socket.Position=V(side*3.7,.12,0);socket.Parent=surface
            local e=Instance.new('ParticleEmitter');e.Name='Track motes';e.Enabled=false
            e:SetAttribute('TreadmillTrackEmitter',true);e.Texture='rbxasset://textures/particles/sparkles_main.dds'
            e.Color=ColorSequence.new(tier==3 and RGB(242,209,147)or theme.Glow)
            e.LightEmission=tier==3 and .1 or .75;e.LightInfluence=.15
            e.Rate=tier==3 and 3 or 2;e.Lifetime=NumberRange.new(.55,.95)
            e.Speed=NumberRange.new(.3,.65);e.Drag=1
            e.EmissionDirection=Enum.NormalId.Top;e.SpreadAngle=Vector2.new(35,35)
            e.Acceleration=origin:VectorToWorldSpace(V(0,.12,-1.2))
            e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.07),NumberSequenceKeypoint.new(.4,tier==3 and .09 or .16),NumberSequenceKeypoint.new(1,0)})
            e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,.3),NumberSequenceKeypoint.new(1,1)})
            e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-20,20);e.Parent=socket
        end
    end

    -- V135: the rails and front architecture are different for every biome.
    if tier==1 then
        for side=-1,1,2 do
            local x=side*5.9
            railPath('Branching timber rail',{V(x,.6,3.8),V(x,3.15,2.5),V(x,3.50,-1.3),V(x,4.0,-5.7)},.92,RGB(149,100,60),Enum.Material.Wood)
            railPath('Tree trunk console pillar',{V(x,.2,-6.1),V(x,2.2,-6),V(x,4.9,-6.25)},1.22,theme.Body,Enum.Material.Wood)
            rod('Forked branch',V(x,3.35,-1),V(x+side*.85,4.2,-2.2),.46,theme.Body,Enum.Material.Wood,true)
            sphere('Broad branch leaf',V(1.15,.25,2.5),CF(x+side*.65,4.25,-2.6)*CFrame.Angles(0,side*.5,side*.32),theme.Trim)
            sphere('Root moss',V(1.6,.6,2.35),CF(x,.5,-5.9),theme.Trim)
            rod('Splayed tree root',V(x,.3,-6),V(x+side*1.05,.05,-7.2),.75,theme.Ink,Enum.Material.Wood,true)
        end
        p('Timber sign back',V(9.9,2.75,.8),CF(0,4.15,-6.15),theme.Body,Enum.Material.Wood)
        rod('Timber sign top',V(-4.7,5.5,-6.13),V(4.7,5.5,-6.13),.52,theme.Ink,Enum.Material.Wood,true)
        for side=-1,1,2 do
            sphere('Forest leaf crest',V(1.65,.28,2.8),CF(side*.8,6.15,-6.1)*CFrame.Angles(math.rad(55),side*.55,side*-.35),theme.Trim)
        end
    elseif tier==2 then
        for side=-1,1,2 do
            local x=side*6.1
            for _,z in ipairs({-5.95,3.65})do
                p('Temple pillar',V(1.35,3.9,1.5),CF(x,1.95,z),RGB(101,132,109),Enum.Material.Slate)
                p('Temple pillar capital',V(1.9,.60,1.9),CF(x,3.8,z),theme.Trim)
                p('Temple pillar foot',V(1.85,.48,1.85),CF(x,.30,z),theme.Body,Enum.Material.Sandstone)
            end
            -- Seven alternating closed links create a hanging chain, not another straight tube rail.
            -- R117: four-bar (rhombic) links read the same at play distance with a third fewer parts.
            for link=1,7 do
                local t=(link-.5)/7
                local z=3.55-t*9.4;local y=3.65-math.sin(t*math.pi)*.68
                local tilt=link%2==0 and math.rad(62)or 0
                local frame=CF(x,y,z)*CFrame.Angles(0,0,tilt)
                for j=1,4 do
                    local a=(j-1)*math.pi/2;local b=j*math.pi/2
                    rod('Hanging jungle chain',frame*V(0,math.sin(a)*.48,math.cos(a)*.86),frame*V(0,math.sin(b)*.48,math.cos(b)*.86),.27,theme.Glow,Enum.Material.Metal)
                end
            end
            railPath('Temple climbing vine',{V(x+side*.75,.7,-6.0),V(x+side*.7,2.25,-6.2),V(x,3.4,-6.85),V(x,5.3,-6.4)},.28,theme.Trim)
            sphere('Temple broad leaf',V(1.4,.23,2.2),CF(x,4.45,3.6)*CFrame.Angles(0,side*.6,.2),theme.Trim)
        end
        p('Temple lintel',V(10.4,2.9,1.1),CF(0,4.15,-6.3),RGB(91,126,107),Enum.Material.Slate)
        p('Temple crown step',V(6.2,.8,1.55),CF(0,5.8,-6.3),theme.Trim)
        diamond('Jade temple idol',CF(0,6.9,-6.3),2.35,2.4,1.35,theme.Trim,false)
        for _,x in ipairs({-3.8,3.8})do p('Temple gold inlay',V(.3,2.35,.08),CF(x,4.3,-5.70),theme.Glow,Enum.Material.Metal)end
    elseif tier==3 then
        for side=-1,1,2 do
            local x=side*6.1
            railPath('Sweeping dune rail',{V(x,.6,4.5),V(x,2.15,3.9),V(x,3.25,1.2),V(x,3.55,-2.5),V(x,4.25,-5.8)},1.05,theme.Body,Enum.Material.Sandstone)
            railPath('Dune golden edge',{V(x+side*.55,2.1,3.9),V(x+side*.55,3.2,1.2),V(x+side*.55,3.5,-2.5),V(x+side*.55,4.2,-5.8)},.20,theme.Glow,Enum.Material.Metal)
            p('Sun gate obelisk',V(1.45,4.4,1.8),CF(x,2.2,-6.5),theme.Body,Enum.Material.Sandstone)
            p('Sun gate cap',V(1.9,.65,2.1),CF(x,4.55,-6.5),theme.Trim)
            diamond('Obelisk sunstone',CF(x,5.55,-6.5),1.30,1.8,1.1,theme.Glow,false)
        end
        p('Sandstone sun gate',V(10.4,2.75,1.2),CF(0,4.1,-6.4),theme.Body,Enum.Material.Sandstone)
        frontDisc('Giant sun crest rim',V(0,6.55,-6.5),1.38,.48,theme.Trim,Enum.Material.Metal)
        frontDisc('Giant sun crest heart',V(0,6.55,-6.20),1.02,.18,theme.Glow,Enum.Material.Neon)
        for j=1,10 do
            local a=j*math.pi/5
            rod('Sun crown ray',V(math.cos(a)*1.65,6.55+math.sin(a)*1.65,-6.5),V(math.cos(a)*2.05,6.55+math.sin(a)*2.05,-6.5),.29,theme.Trim,Enum.Material.Metal,true)
        end
    elseif tier==4 then
        for side=-1,1,2 do
            local x=side*6.15
            for j=1,3 do
                local height=2.4+j*.6;local z=5-j*3.05
                local fin=p('Tall glacier fin',V(1.45,height,3.15),CF(x,height/2+.4,z),j%2==0 and theme.Trim or theme.Body,Enum.Material.Ice,'WedgePart')
                fin.Transparency=.38;fin.Reflectance=.12
                rod('Glacier fin glint',V(x+side*.73,.57,z-1.5),V(x+side*.73,height+.38,z+1.5),.13,theme.Glow,Enum.Material.Neon)
            end
            railPath('Sculpted ice rail',{V(x,2.1,4.0),V(x,3.05,1.6),V(x,3.7,-2.4),V(x,4.8,-5.9)},.65,theme.Trim,Enum.Material.Ice)
            diamond('Glacier front spire',CF(x,3.8,-6.6)*CFrame.Angles(0,0,-side*.10),2.1,7.0,2.0,theme.Trim,true)
            sphere('Glacier snow foot',V(2.25,.6,2.35),CF(x,.35,-6.4),theme.Glow)
        end
        p('Frozen console block',V(9.7,2.8,1.15),CF(0,4.15,-6.2),theme.Body,Enum.Material.Ice).Transparency=.27
        for j=-1,1 do
            diamond('Frozen crown',CF(j*1.65,6.0+ (j==0 and .35 or 0),-6.3),1.1,j==0 and 2.6 or 1.7,.85,theme.Glow,true)
        end
    elseif tier==5 then
        for side=-1,1,2 do
            local x=side*6.1
            railPath('Armored basalt rail',{V(x,.8,4),V(x,3.1,2.8),V(x,3.6,-1),V(x,4.35,-5.8)},1.20,theme.Body,Enum.Material.Basalt)
            for j=1,3 do
                p('Basalt armor plate',V(1.65,1.30,2.05),CF(x,2.9+j*.34,3.2-j*2.65)*CFrame.Angles(-.12,0,0),theme.Ink,Enum.Material.Basalt)
                rod('Armor molten seam',V(x+side*.84,2.55+j*.34,3.8-j*2.65),V(x+side*.84,3.35+j*.34,3.3-j*2.65),.19,theme.Trim,Enum.Material.Neon)
            end
            p('Forge front tower',V(1.9,4.9,2.0),CF(x,2.45,-6.55),theme.Ink,Enum.Material.Basalt)
            local points={V(x,4.4,-6.55),V(side*7.30,5.65,-6.7),V(side*7.20,7.1,-6.85),V(side*5.95,8.15,-6.8)}
            for j=1,3 do rod('Swept magma horn',points[j],points[j+1],1.4-j*.30,theme.Body,Enum.Material.Basalt,true)end
            rod('Molten horn tip',points[3],points[4],.23,theme.Glow,Enum.Material.Neon,true)
            sphere('Forge ember core',V(.65,2.4,.20),CF(x,2.55,-5.51),theme.Trim,Enum.Material.Neon)
        end
        p('Forge console shield',V(10.3,3,1.25),CF(0,4.05,-6.2),theme.Ink,Enum.Material.Basalt)
        p('Forge shield underbite',V(4.5,1.3,1.15),CF(0,2.4,-6.2),theme.Body,Enum.Material.Basalt,'WedgePart')
        diamond('Molten front sigil',CF(0,6.15,-6.35),1.8,2.2,1.0,theme.Trim,false)
    elseif tier==6 then
        for side=-1,1,2 do
            local x=side*6.3
            railPath('Angular prism rail',{V(x,.6,4.5),V(x,2.6,3.45),V(x,3.25,.8),V(x,4.15,-2.0),V(x,4.4,-5.9)},.78,theme.Trim,Enum.Material.Glass)
            diamond('Oversized front diamond',CF(x,4.15,-6.1)*CFrame.Angles(0,.3,side*.08),2.6,6.0,2.5,theme.Trim,false)
            diamond('Amethyst rear diamond',CF(x,1.9,3.7),1.7,3.7,1.7,theme.Body,false)
            -- R117: a three-point rose quartz cluster replaces the 17-part side diamond (budget for orbiting shards).
            for j,s in ipairs({{0,1.75,0,1.0,.15},{-.35,1.2,.65,.7,-.35},{.3,1.15,-.7,.62,.4}})do
                local quartz=p('Side rose quartz',V(s[4],s[4]*1.7,s[4]),CF(x+side*s[1],s[2],-.7+s[3])*CFrame.Angles(s[5],j,side*.25),RGB(245,165,229),Enum.Material.Glass)
                quartz.Transparency=.18;quartz.Reflectance=.12;quartz.CastShadow=false
            end
        end
        p('Prism console surround',V(9.8,2.75,1.2),CF(0,4.15,-6.25),theme.Body,Enum.Material.Glass).Transparency=.16
        diamond('Diamond crown centerpiece',CF(0,6.4,-6.3),2.25,2.6,1.25,theme.Glow,false)
        for side=-1,1,2 do
            rod('Crystal crown brace',V(side*1.2,5.7,-6.3),V(side*4.4,5.7,-6.3),.36,theme.Trim,Enum.Material.Neon,true)
        end
    elseif tier==7 then
        for side=-1,1,2 do
            local x=side*6.1
            local points={V(x,.75,4.2),V(x,3.45,2.0),V(x,2.5,1.0),V(x,4.05,-1.6),V(x,3.15,-2.45),V(x,4.5,-5.7)}
            railPath('Lightning rail casing',points,.92,theme.Ink,Enum.Material.Metal)
            local bright={};for _,point in ipairs(points)do table.insert(bright,point+V(side*.44,0,0))end
            railPath('Lightning rail live edge',bright,.33,theme.Glow,Enum.Material.Neon)
            p('Stormline power housing',V(1.9,5.6,1.65),CF(x,2.8,-6.5),theme.Ink,Enum.Material.Metal)
            p('Stormline front panel',V(1.45,4.5,.12),CF(x,2.85,-5.61),theme.Body,Enum.Material.Metal)
            p('Stormline status strip',V(.16,3.6,.09),CF(x-side*.46,2.95,-5.50),theme.Glow,Enum.Material.Neon)
            p('Stormline angled cap',V(2.05,.6,1.85),CF(x,5.7,-6.5),theme.Trim,Enum.Material.Metal,'WedgePart')
            for j=1,3 do p('Cooling vent',V(.65,.16,.10),CF(x+side*.2,1.45+j*.55,-5.49),theme.Ink,Enum.Material.Metal)end
        end
        p('Stormline console bridge',V(10.4,2.7,1.2),CF(0,4.15,-6.3),theme.Body,Enum.Material.Metal)
        local bolt={V(1.15,7.45,-6.3),V(-.7,6.2,-6.3),V(.65,6.2,-6.3),V(-1.1,5.3,-6.3)}
        railPath('Giant front lightning crest',bolt,.55,theme.Trim,Enum.Material.Neon)
    end
    treadmillFlairR117({m=m,origin=origin,tier=tier,theme=theme,surface=surface,face=face,p=p,rawp=rawp,sphere=sphere,
        rod=rod,railPath=railPath,frontDisc=frontDisc,longer=longer})
    m:SetAttribute('TreadmillFxVersion',117);m:SetAttribute('TreadmillTierName',theme.Name)
    -- R117: small ornaments never cast shadows (cheaper, and they only speckle the deck).
    for _,v in ipairs(m:GetDescendants())do
        if v:IsA('BasePart')and math.max(v.Size.X,v.Size.Y,v.Size.Z)<2 then v.CastShadow=false end
    end
    -- New geometry is complete before replacing the previous appearance.
    if not belt then
        belt=part(base,'Treadmill',beltSize,origin,RGB(37,50,66),Enum.Material.SmoothPlastic)
        belt:SetAttribute('TreadmillVersion',131);belt:SetAttribute('TreadmillTrainingBelt',true)
        belt:SetAttribute('TrainingFacingDegrees',0)
    else belt.Size=beltSize;belt.CFrame=origin;belt.Color=RGB(37,50,66)end
    belt.Material=Enum.Material.SmoothPlastic;belt.Transparency=1
    belt:SetAttribute('TreadmillLengthVersion',137)
    belt:SetAttribute('TreadmillFrameVersion',135)
    belt:SetAttribute('TreadmillTrackVersion',133)
    belt.CanCollide=true;belt.CanQuery=true;belt:SetAttribute('TreadmillPolishVersion',132)
    m.Parent=base;if old then old:Destroy()end
    return belt,prompt
end
function Art.ApplyTreadmillsV131(map)
    local bases=assert(map:FindFirstChild('Bases'),'Missing Bases')
    for _,base in ipairs(bases:GetChildren())do
        if base:IsA('Model')and base:GetAttribute('BaseIndex')then Art.BuildTreadmillV131(base,1)end
    end
end
function Art.RemoveTreadmillsV131(map)
    local bases=map:FindFirstChild('Bases');if not bases then return end
    for _,base in ipairs(bases:GetChildren())do
        for _,name in ipairs({'TreadmillArtV131','Treadmill'})do
            local item=base:FindFirstChild(name)
            if item and item:GetAttribute('TreadmillVersion')==131 then item:Destroy()end
        end
    end
end

-- V134: length-only route expansion, with rigid scenery groups and reversible geometry.
local ROUTE_FACTOR=1.5
local ROUTE_START=-100
local ROUTE_BACKUP='ChestChaseRoutesV134Backup'
local ROUTE_DECOR='RouteSceneryV134'
local routeOrder={1,6,2,3,4,5,7}
local routeLengths={[1]=150,[6]=180,[2]=195,[3]=210,[4]=240,[5]=270,[7]=300}
local function routeZ(z)return ROUTE_START+(z-ROUTE_START)*ROUTE_FACTOR end
local function descendantsAndSelf(root)
    local out=root:GetDescendants();table.insert(out,1,root);return out
end
local function geometryBounds(root,planned)
    local low=V(math.huge,math.huge,math.huge);local high=-low;local count=0
    for _,v in ipairs(descendantsAndSelf(root))do if v:IsA('BasePart')then
        local cf=(planned[v]and planned[v].CFrame)or v.CFrame
        local size=(planned[v]and planned[v].Size)or v.Size
        local h=size/2;local x,y,z=cf.RightVector,cf.UpVector,cf.LookVector
        local e=V(math.abs(x.X)*h.X+math.abs(y.X)*h.Y+math.abs(z.X)*h.Z,
            math.abs(x.Y)*h.X+math.abs(y.Y)*h.Y+math.abs(z.Y)*h.Z,
            math.abs(x.Z)*h.X+math.abs(y.Z)*h.Y+math.abs(z.Z)*h.Z)
        local a,b=cf.Position-e,cf.Position+e
        low=V(math.min(low.X,a.X),math.min(low.Y,a.Y),math.min(low.Z,a.Z))
        high=V(math.max(high.X,b.X),math.max(high.Y,b.Y),math.max(high.Z,b.Z));count+=1
    end end
    return low,high,count
end
function Art.BeginRoutesV134(map,undo)
    local storage=game:GetService('ServerStorage')
    local saved=storage:FindFirstChild(ROUTE_BACKUP)
    local existing=map:FindFirstChild(ROUTE_DECOR)
    local installed=map:GetAttribute('RoutesExpandedV134')==true
    if (undo and not installed)or(not undo and installed)then
        assert(installed==false or(saved and existing),'[V134] Route scenery or restoration data is missing.')
        return {Apply=function()end,Rollback=function()end,Commit=function()end}
    end
    assert((undo and saved and existing)or(not undo and not saved and not existing),'[V134] Partial route update found.')
    local operations={};local planned={};local touched={}
    local backup,decor=saved,existing
    local applied=0;local started=false
    local function add(item,kind,key,value)
        local old
        if kind=='Property'then old=item[key]else old=item:GetAttribute(key)end
        table.insert(operations,{Item=item,Kind=kind,Key=key,Before=old,After=value})
        if kind=='Property'then planned[item]=planned[item]or {};planned[item][key]=value end
    end
    local function prop(v,k,value)add(v,'Property',k,value)end
    local function attr(v,k,value)add(v,'Attribute',k,value)end
    local function worldAttributes(v,transform,scale)
        for k,value in pairs(v:GetAttributes())do
            if (k=='SceneCenter'or k=='PoolCenter'or k:match('^Node%d+$'))and typeof(value)=='Vector3'then
                attr(v,k,transform(value))
            elseif (k=='MagmaRest'or k=='GuardianHomeCFrame'or k=='ClosedHingeCFrame'or k=='OpenHingeCFrame')and typeof(value)=='CFrame'then
                attr(v,k,CF(transform(value.Position))*value.Rotation)
            elseif k=='PoolRadii'and typeof(value)=='Vector3'and scale~=1 then attr(v,k,value*scale)end
        end
    end
    local function group(root,forcedDelta,scaleDecor)
        if not root then return end
        local low,high,count=geometryBounds(root,{})
        if count==0 then return end
        local middle=(low+high)/2
        local scale=1
        if scaleDecor then scale=math.clamp((89-math.abs(middle.X))/math.max((high.X-low.X)/2,.1),1,1.12)end
        local pivot=V(middle.X,4,middle.Z)
        local target=pivot+V(0,0,forcedDelta or(routeZ(middle.Z)-middle.Z))
        local function transform(p)return target+(p-pivot)*scale end
        for _,v in ipairs(descendantsAndSelf(root))do
            if not touched[v]then
                touched[v]=true
                if v:IsA('BasePart')then
                    prop(v,'CFrame',CF(transform(v.Position))*v.CFrame.Rotation)
                    if scale~=1 then prop(v,'Size',v.Size*scale)end
                elseif v:IsA('Attachment')and scale~=1 then
                    prop(v,'CFrame',CF(v.CFrame.Position*scale)*v.CFrame.Rotation)
                end
                worldAttributes(v,transform,scale)
            end
        end
    end
    local function stretch(v)
        if touched[v]then return end;touched[v]=true
        local cf=v.CFrame;local x,y,z=cf.RightVector,cf.UpVector,cf.LookVector
        -- Structural ground, edge and barrier parts are aligned to world Z.
        local ax,ay,az=math.abs(x.Z),math.abs(y.Z),math.abs(z.Z)
        assert(math.max(ax,ay,az)>.9999,'[V134] Structural part is rotated off-axis: '..v:GetFullName())
        local size=v.Size
        prop(v,'Size',V(size.X*(ax>.9999 and ROUTE_FACTOR or 1),size.Y*(ay>.9999 and ROUTE_FACTOR or 1),size.Z*(az>.9999 and ROUTE_FACTOR or 1)))
        prop(v,'CFrame',CF(v.Position.X,v.Position.Y,routeZ(v.Position.Z))*cf.Rotation)
    end
    local okay,why=xpcall(function()
        if undo then
            assert(saved:GetAttribute('OwnerVersion')==134,'[V134] Unknown route backup.')
            for _,entry in ipairs(saved:GetChildren())do
                local item=entry.Value
                assert(item and(item==map or item:IsDescendantOf(map)),'[V134] A route object was deleted; restoration stopped.')
                local kind,key=entry:GetAttribute('Kind'),entry:GetAttribute('Key')
                local expected=entry:GetAttribute('After')
                local current
                if kind=='Property'then current=item[key]else current=item:GetAttribute(key)end
                local equal=current==expected
                if typeof(current)=='CFrame'and typeof(expected)=='CFrame'then equal=(current.Position-expected.Position).Magnitude<.001 and current.RightVector:Dot(expected.RightVector)>.99999 and current.UpVector:Dot(expected.UpVector)>.99999
                elseif typeof(current)=='Vector3'and typeof(expected)=='Vector3'then equal=(current-expected).Magnitude<.001 end
                assert(equal,'[V134] Route property changed; restoration stopped: '..item:GetFullName()..'/'..key)
                add(item,kind,key,entry:GetAttribute('Before'))
            end
            return
        end
        assert(map:GetAttribute('BiomeTrackStartZ')==ROUTE_START and map:GetAttribute('BiomeTrackEndZ')==1445,'[V134] Unexpected route bounds.')
        local biomes=assert(findPath(map,'Obby/Biomes'),'[V134] Biomes missing.')
        local byStage={};local start=ROUTE_START;local camps={}
        for _,biome in ipairs(biomes:GetChildren())do local stage=biome:GetAttribute('Stage');if stage then byStage[stage]=biome end end
        for _,stage in ipairs(routeOrder)do
            local biome=assert(byStage[stage],'[V134] Missing biome '..stage)
            local ground=assert(biome:FindFirstChild('BiomeGround_'..stage),'[V134] Missing biome ground.')
            assert(math.abs(ground.Size.Z-routeLengths[stage])<.01 and math.abs(ground.Position.Z-(start+routeLengths[stage]/2))<.01,'[V134] Biome geometry changed.')
            attr(biome,'TrackStartZ',routeZ(start));attr(biome,'TrackEndZ',routeZ(start+routeLengths[stage]));attr(biome,'BiomeLength',routeLengths[stage]*ROUTE_FACTOR)
            attr(map,'BiomeStartZ_'..stage,routeZ(start));attr(map,'BiomeEndZ_'..stage,routeZ(start+routeLengths[stage]));attr(map,'BiomeLength_'..stage,routeLengths[stage]*ROUTE_FACTOR)
            local stageFolder=findPath(map,'Obby/Stages/Stage_'..stage)
            if stageFolder then
                attr(stageFolder,'TrackStartZ',routeZ(start));attr(stageFolder,'TrackEndZ',routeZ(start+routeLengths[stage]));attr(stageFolder,'BiomeLength',routeLengths[stage]*ROUTE_FACTOR)
            end
            stretch(ground)
            for _,edge in ipairs({'LeftBiomeEdge','RightBiomeEdge'})do local v=biome:FindFirstChild(edge);if v then stretch(v)end end
            start+=routeLengths[stage]
        end
        attr(map,'BiomeTrackEndZ',routeZ(1445));attr(map,'TrackLength',(1445-ROUTE_START)*ROUTE_FACTOR);attr(map,'BiomeLength',225)
        -- Keep the entire connected volcano/river/pool composition together.
        local lavaDelta=routeZ(755)-755
        group(map:FindFirstChild('PresentationV128'),lavaDelta,false)
        group(findPath(map,'EnvironmentPolishV127/IrregularMagmaPools'),lavaDelta,false)
        group(findPath(map,'MythicLandmarks/Biome4_Landmark'),lavaDelta,false)
        group(byStage[4]:FindFirstChild('BiomeScenesV092'),lavaDelta,false)
        group(findPath(map,'EnvironmentPolishV127/RestoredIceGrove'),nil,true)
        local function scenery(root)
            if touched[root]then return end
            if root:IsA('BasePart')then group(root,nil,false);return end
            if root:IsA('Model')and root.Name~='BiomeDesignV091'and root.Name~='BiomeScenesV092'then
                local key=root:GetAttribute('SceneryKey')or ''
                if key:match('^wall%.')then
                    local low,high=geometryBounds(root,{})
                    local centerZ=(low.Z+high.Z)/2;local delta=routeZ(centerZ)-centerZ
                    for _,v in ipairs(root:GetDescendants())do if v:IsA('BasePart')then
                        if v.Name=='Wall bank slope'then stretch(v)else group(v,delta,false)end
                    end end
                else group(root,nil,true)end
                return
            end
            for _,v in ipairs(root:GetChildren())do scenery(v)end
        end
        for _,biome in pairs(byStage)do for _,v in ipairs(biome:GetChildren())do scenery(v)end end
        local landmarks=map:FindFirstChild('MythicLandmarks')
        if landmarks then for _,m in ipairs(landmarks:GetChildren())do if not touched[m]then group(m,nil,true)end end end
        local guardians=assert(map:FindFirstChild('GuardianEncounters'),'[V134] Keeper camps missing.')
        for _,m in ipairs(guardians:GetChildren())do
            local stage=m:GetAttribute('Stage');local home=m:GetAttribute('GuardianHomeCFrame')
            if stage and typeof(home)=='CFrame'then
                local delta=routeZ(home.Position.Z)-home.Position.Z
                camps[stage]={Position=V(home.Position.X,home.Position.Y,routeZ(home.Position.Z)),Delta=delta}
                group(m,delta,false)
            end
        end
        for _,stage in ipairs(routeOrder)do assert(camps[stage],'[V134] Keeper home missing for biome '..stage)end
        local seeds=assert(map:FindFirstChild('Seeds'),'[V134] Packs missing.')
        for _,m in ipairs(seeds:GetChildren())do local stage=m:GetAttribute('Stage');if camps[stage]then group(m,camps[stage].Delta,false)end end
        for _,v in ipairs(assert(map:FindFirstChild('InvisibleMapBarriersV071'),'[V134] Barriers missing.'):GetChildren())do
            if v:IsA('BasePart')then
                if v:GetAttribute('BarrierType')=='BiomeSide'then stretch(v)
                elseif v:GetAttribute('BarrierType')=='BiomeEnd'then group(v,routeZ(1445)-1445,false)end
            end
        end
        local fall=findPath(map,'Obby/FallReturnPlane');if fall then
            local a=fall.Position.Z-fall.Size.Z/2;local b=fall.Position.Z+fall.Size.Z/2
            -- Preserve the 20-stud apron on either side of the complete route.
            local extra=routeZ(1445)-1445
            prop(fall,'Size',fall.Size+V(0,0,extra));prop(fall,'CFrame',fall.CFrame+V(0,0,extra/2))
        end
        -- Fill long side-scene gaps while keeping the centre running lane and camps clear.
        decor=Instance.new('Folder');decor.Name=ROUTE_DECOR;decor:SetAttribute('OwnerVersion',134)
        local palette={[1]={RGB(83,142,73),RGB(102,75,50)},[6]={RGB(42,131,73),RGB(77,82,53)},[2]={RGB(215,173,111),RGB(172,120,73)},[3]={RGB(184,234,247),RGB(112,177,205)},[4]={RGB(60,46,48),RGB(91,59,48)},[5]={RGB(106,89,143),RGB(170,141,224)},[7]={RGB(65,77,105),RGB(94,111,153)}}
        local obstacles={}
        for _,v in ipairs(map:GetDescendants())do if v:IsA('BasePart')and not v:IsDescendantOf(seeds)and not v:IsDescendantOf(guardians)and v.Transparency<.98 then
            local cf=(planned[v]and planned[v].CFrame)or v.CFrame;local size=(planned[v]and planned[v].Size)or v.Size
            if cf.Position.Y+size.Y/2>5.0 and math.abs(cf.Position.X)>44 and math.abs(cf.Position.X)<87 then
                local h=size/2;local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
                local ex=math.abs(r.X)*h.X+math.abs(u.X)*h.Y+math.abs(l.X)*h.Z
                local ez=math.abs(r.Z)*h.X+math.abs(u.Z)*h.Y+math.abs(l.Z)*h.Z
                table.insert(obstacles,{X=cf.Position.X,Z=cf.Position.Z,HX=ex,HZ=ez})
            end
        end end
        start=ROUTE_START
        for _,stage in ipairs(routeOrder)do
            local length=routeLengths[stage]*ROUTE_FACTOR;local a=routeZ(start);local colors=palette[stage]
            local folder=Instance.new('Folder');folder.Name='Biome'..stage;folder:SetAttribute('Stage',stage);folder.Parent=decor
            for _,side in ipairs({-1,1})do
                part(folder,'Continuous biome verge',V(3.6,.7,length+.12),CF(side*88.1,4.10,a+length/2),colors[1],stage==3 and Enum.Material.Ice or stage==2 and Enum.Material.Sand or Enum.Material.Slate)
                local slots=math.ceil(length/32)
                for i=1,slots do
                    local z=a+(i-.5)*length/slots;local x=side*(76+(i%3-1)*2)
                    -- Overlapping low verges plus varied raised banks keep the longer edges dressed.
                    local height=2.6+(i%3)*.65
                    local material=stage==3 and Enum.Material.Ice or stage==2 and Enum.Material.Sandstone or Enum.Material.Slate
                    local bank=part(folder,'Varied biome bank',V(4,height,18+(i%3)*3),CF(side*86.4,4+height/2,z)*CFrame.Angles(0,i%2*math.pi,0),colors[i%2+1],material,'WedgePart')
                    if stage==3 then bank.Transparency=.25 end
                    local blocked=false
                    local home=camps[stage].Position
                    if math.abs(home.X-x)<24 and math.abs(home.Z-z)<32 then blocked=true end
                    for _,o in ipairs(obstacles)do if math.abs(o.X-x)<o.HX+7 and math.abs(o.Z-z)<o.HZ+9 then blocked=true;break end end
                    if blocked then continue end
                    local model=Instance.new('Model');model.Name='Scenery cluster '..side..' '..i;model:SetAttribute('Stage',stage)
                    local s=1+(i%3)*.08
                    local function p(name,size,offset,color,material,class)
                        return part(model,name,size*s,CF(x,4,z)*CF(offset*s),color or colors[1],material or Enum.Material.Slate,class)
                    end
                    p('Low biome stone',V(9,1.1,13),V(0,.35,0),colors[2])
                    if stage==1 or stage==6 then
                        p('Tree trunk',V(1.2,9,1.3),V(0,4.5,0),RGB(109,78,53),Enum.Material.Wood)
                        for j=1,3 do
                            local leaf=p('Leaf crown',V(6.5-j*.65,3.7,6),V((j%2-.5)*2,7+j*1.7,(j-2)*1.5),j%2==0 and colors[1]or RGB(85,167,82),Enum.Material.Grass)
                            leaf.Shape=Enum.PartType.Ball
                        end
                        p('Moss stone',V(3,2,4),V(3,1,-3),colors[1])
                    elseif stage==2 then
                        p('Cactus stem',V(1.5,7,1.6),V(0,3.5,0),RGB(84,153,86),Enum.Material.SmoothPlastic)
                        p('Cactus arm',V(3.4,1.2,1.3),V(1,3.1,0),RGB(91,167,91),Enum.Material.SmoothPlastic)
                        p('Cactus tip',V(1.3,3.2,1.3),V(2.1,4.5,0),RGB(91,167,91),Enum.Material.SmoothPlastic)
                        p('Sandstone',V(3.5,2,4.8),V(-2.8,.9,2.5),colors[2],Enum.Material.Sandstone,'WedgePart')
                    elseif stage==3 or stage==5 then
                        for j=1,3 do
                            local size=V(1.6,4+j*1.4,1.8);local offset=V((j-2)*2.1,size.Y/2,(j%2-.5)*2.2)
                            local ice=p(stage==3 and 'Clear ice pillar'or 'Prism pillar',size,offset,j%2==0 and colors[1]or colors[2],stage==3 and Enum.Material.Ice or Enum.Material.Glass)
                            ice.Transparency=stage==3 and .38 or .2
                            local tip=p('Facet tip',V(1.6,2,1.8),offset+V(0,size.Y/2+.7,0),ice.Color,ice.Material,'WedgePart');tip.Transparency=ice.Transparency
                        end
                    else
                        for j=1,3 do p('Jagged rock',V(3.4,2+j*1.1,4.6),V((j-2)*2.4,1+j*.5,(j%2-.5)*2),j%2==0 and colors[1]or colors[2],Enum.Material.Basalt,'WedgePart')end
                        local glow=stage==4 and RGB(244,115,36)or RGB(152,194,255)
                        p(stage==4 and 'Magma seam'or 'Charged seam',V(.14,3.8,.14),V(.3,2,-2.4),glow,Enum.Material.Neon)
                    end
                    model.Parent=folder
                end
            end
            start+=routeLengths[stage]
        end
        attr(map,'RoutesExpandedV134',true)
        backup=Instance.new('Folder');backup.Name=ROUTE_BACKUP;backup:SetAttribute('OwnerVersion',134)
        for i,op in ipairs(operations)do
            local entry=Instance.new('ObjectValue');entry.Name=string.format('Change%05d',i);entry.Value=op.Item
            entry:SetAttribute('Kind',op.Kind);entry:SetAttribute('Key',op.Key)
            entry:SetAttribute('Before',op.Before);entry:SetAttribute('After',op.After);entry.Parent=backup
        end
    end,debug.traceback)
    if not okay then
        if not undo then if decor then decor:Destroy()end;if backup then backup:Destroy()end end
        error(why)
    end
    local transaction={}
    local function write(op,value)
        if op.Kind=='Attribute'then op.Item:SetAttribute(op.Key,value)else op.Item[op.Key]=value end
    end
    function transaction.Apply()
        assert(not started,'[V134] Route transaction already applied.');started=true
        for i,op in ipairs(operations)do applied=i;write(op,op.After)end
        if undo then decor.Parent=nil else backup.Parent=storage;decor.Parent=map end
    end
    function transaction.Rollback()
        for i=applied,1,-1 do local op=operations[i];write(op,op.Before)end
        if undo then decor.Parent=map else decor:Destroy();backup:Destroy()end
        applied=0
    end
    function transaction.Commit()
        if undo then decor:Destroy();backup:Destroy()end
    end
    return transaction
end
function Art.ApplyRoutesV134(map)
    local tx=Art.BeginRoutesV134(map,false)
    local okay,why=xpcall(tx.Apply,debug.traceback)
    if not okay then tx.Rollback();error(why)end
    tx.Commit()
end

-- V136: visible walls follow the expanded ground; sparse scenery sits directly on it.
local CLEAN_BACKUP='ChestChaseRoutePolishV136Backup'
local CLEAN_DECOR='SparseRouteSceneryV136'
local CLEAN_READY='RoutesPolishedV136'
local function routeEqual(a,b)
    if typeof(a)~=typeof(b)then return false end
    if typeof(a)=='CFrame'then return (a.Position-b.Position).Magnitude<.001 and a.RightVector:Dot(b.RightVector)>.99999 and a.UpVector:Dot(b.UpVector)>.99999 end
    if typeof(a)=='Vector3'then return (a-b).Magnitude<.001 end
    return a==b
end
function Art.BeginRoutePolishV136(map,undo)
    local storage=game:GetService('ServerStorage')
    local saved=storage:FindFirstChild(CLEAN_BACKUP);local current=map:FindFirstChild(CLEAN_DECOR)
    local installed=map:GetAttribute(CLEAN_READY)==true
    if (undo and not installed)or(not undo and installed)then
        assert((not installed and not saved and not current)or(installed and saved and current),'[V136] Incomplete route scenery update.')
        return {Apply=function()end,Rollback=function()end,Commit=function()end}
    end
    assert((undo and saved and current)or(not undo and not saved and not current),'[V136] Partial route restoration data found.')
    local operations,planned,operationKeys={},{},{};local backup,decor=saved,current;local holding
    local applied,started=0,false
    local function add(item,kind,key,after)
        local before
        if kind=='Attribute'then before=item:GetAttribute(key)else before=item[key]end
        operationKeys[item]=operationKeys[item]or {};local token=kind..'/'..key
        local prior=operationKeys[item][token]
        if prior then prior.After=after else
            local op={Item=item,Kind=kind,Key=key,Before=before,After=after}
            table.insert(operations,op);operationKeys[item][token]=op
        end
        if kind=='Property'then planned[item]=planned[item]or {};planned[item][key]=after end
    end
    local function prop(v,k,value)add(v,'Property',k,value)end
    local function attr(v,k,value)add(v,'Attribute',k,value)end
    local function shift(root,delta)
        for _,v in ipairs(descendantsAndSelf(root))do
            if v:IsA('BasePart')then
                prop(v,'CFrame',((planned[v]and planned[v].CFrame)or v.CFrame)+delta)
            end
            for k,value in pairs(v:GetAttributes())do
                if k=='SceneCenter'and typeof(value)=='Vector3'then attr(v,k,value+delta)end
            end
        end
    end
    local function stash(v)add(v,'Parent','Parent',holding)end
    local okay,why=xpcall(function()
        if undo then
            assert(saved:GetAttribute('OwnerVersion')==136,'[V136] Unknown restoration data.')
            for _,entry in ipairs(saved.Changes:GetChildren())do
                local item=entry.Value;local kind,key=entry:GetAttribute('Kind'),entry:GetAttribute('Key')
                assert(item and(item==map or item:IsDescendantOf(map)or item:IsDescendantOf(saved)),'[V136] A modified object was deleted.')
                local before,after=entry:GetAttribute('Before'),entry:GetAttribute('After')
                if kind=='Parent'then before=entry.OriginalParent.Value;after=saved.HeldGeometry end
                local actual
                if kind=='Attribute'then actual=item:GetAttribute(key)else actual=item[key]end
                assert(routeEqual(actual,after),'[V136] Edited route object; undo stopped: '..item:GetFullName()..'/'..key)
                add(item,kind,key,before)
            end
            return
        end
        assert(map:GetAttribute('RoutesExpandedV134')==true,'[V136] Expand V134 routes before cleaning scenery.')
        local walls=assert(findPath(map,'Obby/BiomeWalls'),'[V136] Visible biome walls missing.')
        local biomes=assert(findPath(map,'Obby/Biomes'),'[V136] Biomes missing.')
        local dense=assert(map:FindFirstChild(ROUTE_DECOR),'[V136] V134 scenery folder missing.')
        local byStage,wallByStage={},{ }
        for _,biome in ipairs(biomes:GetChildren())do local stage=biome:GetAttribute('Stage');if stage then byStage[stage]=biome end end
        backup=Instance.new('Folder');backup.Name=CLEAN_BACKUP;backup:SetAttribute('OwnerVersion',136)
        holding=Instance.new('Folder');holding.Name='HeldGeometry';holding.Parent=backup
        decor=Instance.new('Folder');decor.Name=CLEAN_DECOR;decor:SetAttribute('OwnerVersion',136)
        -- Use actual expanded ground bounds. Old wall lengths and the old end-wall stage are unreliable.
        for _,stage in ipairs(routeOrder)do
            local biome=assert(byStage[stage],'[V136] Missing biome '..stage)
            local ground=assert(biome:FindFirstChild('BiomeGround_'..stage),'[V136] Missing ground '..stage)
            local low,high=geometryBounds(ground,{})
            assert(math.abs(low.Z-biome:GetAttribute('TrackStartZ'))<.01 and math.abs(high.Z-biome:GetAttribute('TrackEndZ'))<.01,'[V136] Ground and route bounds disagree.')
            wallByStage[stage]={}
            for _,side in ipairs({-1,1})do
                local wall=assert(walls:FindFirstChild('Biome_'..stage..'_'..(side==-1 and 'LeftWall'or 'RightWall')),'[V136] Missing side wall.')
                assert(math.abs(wall.CFrame.LookVector.Z)>.99999 and math.abs(wall.CFrame.UpVector.Y)>.99999,'[V136] Rotated structural wall.')
                prop(wall,'Size',V(wall.Size.X,wall.Size.Y,high.Z-low.Z))
                prop(wall,'CFrame',CF(wall.Position.X,wall.Position.Y,(low.Z+high.Z)/2)*wall.CFrame.Rotation)
                attr(wall,'WallAlignmentVersion',136);attr(wall,'TrackStartZ',low.Z);attr(wall,'TrackEndZ',high.Z)
                wallByStage[stage][side]=wall
            end
        end
        local endZ=map:GetAttribute('BiomeTrackEndZ');local ends=0
        for _,wall in ipairs(walls:GetChildren())do if wall:IsA('BasePart')and wall.Name:match('_EndWall$')then
            local sideWall=wallByStage[7][1];local width=2*(math.abs(sideWall.Position.X)+sideWall.Size.X/2)
            prop(wall,'Size',V(width,wall.Size.Y,wall.Size.Z))
            prop(wall,'CFrame',CF(0,wall.Position.Y,endZ+wall.Size.Z/2))
            prop(wall,'Color',sideWall.Color)
            attr(wall,'Stage',7);attr(wall,'BiomeName','Stormy Peaks');attr(wall,'WallAlignmentVersion',136);ends+=1
        end end
        assert(ends==1,'[V136] Expected one final visible wall.')
        -- Attach whole wall groups, keeping vines/fault lines and their backing rock together.
        local attached={}
        local function attach(root,stage,side)
            if attached[root]then return end;attached[root]=true
            local wall=assert(wallByStage[stage][side]);local plane=math.abs(wall.Position.X)-wall.Size.X/2
            local low,high,count=geometryBounds(root,planned);if count==0 then return end
            local back=side==1 and high.X or -low.X
            shift(root,V(side*(plane+.08-back),0,0))
            attr(root,'WallAttachmentVersion',136);attr(root,'WallAttachmentStage',stage);attr(root,'WallAttachmentSide',side)
            -- Lava's bright fissure should touch its backing shoulder, not float in front of it.
            local backing=root:FindFirstChild('Dark rock shoulder',true)
            if backing then
                local a,b=geometryBounds(backing,planned);local face=side==1 and a.X or -b.X
                for _,v in ipairs(root:GetDescendants())do if v:IsA('BasePart')and v.Name=='Hot fault'then
                    local lo,hi=geometryBounds(v,planned);local outer=side==1 and hi.X or -lo.X
                    shift(v,V(side*(face+.025-outer),0,0))
                end end
            end
        end
        local removedPatches=0
        for _,stage in ipairs(routeOrder)do
            local biome=byStage[stage];local generated=biome:FindFirstChild('GeneratedScenery')
            if generated then
                for _,root in ipairs(generated:GetChildren())do
                    local key=root:GetAttribute('SceneryKey')or ''
                    if key:match('^wall%.')or key=='jungle.wall'or key=='storm.wall'then
                        local low,high=geometryBounds(root,{})
                        attach(root,stage,(low.X+high.X)>=0 and 1 or -1)
                    end
                end
                for _,v in ipairs(generated:GetDescendants())do
                    if v:IsA('BasePart')and(v.Name=='Ground cover'or v.Name=='Soft edge'or v.Name=='Wind-worn ground')then stash(v);removedPatches+=1 end
                end
            end
            local wallDesign=findPath(biome,'BiomeDesignV091/WallDesign')
            if wallDesign then for _,root in ipairs(wallDesign:GetChildren())do
                local low,high,count=geometryBounds(root,{})
                if count>0 then attach(root,stage,(low.X+high.X)>=0 and 1 or -1)end
            end end
        end
        -- Keep a few of the old filler objects, without their stone pads or repeated edge banks.
        -- Existing landmark scenery and the connected lava composition remain in place.
        local oldGroups,newGroups,newParts=0,0,0
        for _,stage in ipairs(routeOrder)do
            local old=dense:FindFirstChild('Biome'..stage)
            if old then
                local candidates={[-1]={},[1]={}}
                for _,root in ipairs(old:GetChildren())do if root:IsA('Model')and root.Name:match('^Scenery cluster ')then
                    local low,high=geometryBounds(root,{});local side=(low.X+high.X)>=0 and 1 or -1
                    table.insert(candidates[side],{Root=root,Z=(low.Z+high.Z)/2});oldGroups+=1
                end end
                local folder=Instance.new('Folder');folder.Name='Biome'..stage;folder:SetAttribute('Stage',stage);folder.Parent=decor
                local ground=byStage[stage]:FindFirstChild('BiomeGround_'..stage)
                local _,groundHigh=geometryBounds(ground,{})
                for _,side in ipairs({-1,1})do
                    table.sort(candidates[side],function(a,b)return a.Z<b.Z end)
                    local previous=-math.huge
                    for index,entry in ipairs(candidates[side])do
                        if entry.Z-previous<110 then continue end
                        local copy=entry.Root:Clone();copy.Name='Ground decoration '..side..' '..index
                        local keep={};local tallest
                        for _,v in ipairs(copy:GetChildren())do if v:IsA('BasePart')then
                            if stage==1 or stage==6 then keep[v]=v.Name=='Tree trunk'or v.Name=='Leaf crown'
                            elseif stage==2 then keep[v]=v.Name:match('^Cactus ')~=nil
                            elseif stage==3 or stage==5 then
                                if (v.Name=='Clear ice pillar'or v.Name=='Prism pillar')and(not tallest or v.Size.Y>tallest.Size.Y)then tallest=v end
                            elseif v.Name=='Jagged rock'and(not tallest or v.Size.Y>tallest.Size.Y)then tallest=v end
                        end end
                        if tallest then
                            keep[tallest]=true
                            if stage==3 or stage==5 then for _,v in ipairs(copy:GetChildren())do
                                if v:IsA('BasePart')and v.Name=='Facet tip'and math.abs(v.Position.X-tallest.Position.X)<.01 and math.abs(v.Position.Z-tallest.Position.Z)<.01 then keep[v]=true end
                            end end
                        end
                        for _,v in ipairs(copy:GetChildren())do if not keep[v]then v:Destroy()end end
                        local low,high,count=geometryBounds(copy,{})
                        assert(count>0,'[V136] Empty retained scenery.')
                        local actualZ=(low.Z+high.Z)/2
                        if actualZ-previous<110 then copy:Destroy();continue end
                        local delta=V(0,groundHigh.Y-low.Y,0)
                        for _,v in ipairs(copy:GetDescendants())do if v:IsA('BasePart')then
                            v.CFrame+=delta;v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
                        end end
                        copy:SetAttribute('GroundedDecorationVersion',136);copy:SetAttribute('GroundHeight',groundHigh.Y)
                        copy:SetAttribute('Stage',stage);copy:SetAttribute('Side',side)
                        copy.Parent=folder;previous=actualZ;newGroups+=1;newParts+=count
                    end
                end
                stash(old)
            end
        end
        decor:SetAttribute('PreviousFillerGroups',oldGroups);decor:SetAttribute('RetainedFillerGroups',newGroups)
        decor:SetAttribute('NativeParts',newParts);decor:SetAttribute('RemovedGroundPatches',removedPatches)
        attr(map,CLEAN_READY,true)
        local changes=Instance.new('Folder');changes.Name='Changes';changes.Parent=backup
        for i,op in ipairs(operations)do
            local entry=Instance.new('ObjectValue');entry.Name=string.format('Change%05d',i);entry.Value=op.Item
            entry:SetAttribute('Kind',op.Kind);entry:SetAttribute('Key',op.Key)
            if op.Kind=='Parent'then
                local original=Instance.new('ObjectValue');original.Name='OriginalParent';original.Value=op.Before;original.Parent=entry
            else entry:SetAttribute('Before',op.Before);entry:SetAttribute('After',op.After)end
            entry.Parent=changes
        end
    end,debug.traceback)
    if not okay then
        if not undo then if decor then decor:Destroy()end;if backup then backup:Destroy()end end
        error(why)
    end
    local function write(op,value)
        if op.Kind=='Attribute'then op.Item:SetAttribute(op.Key,value)else op.Item[op.Key]=value end
    end
    local tx={}
    function tx.Apply()
        assert(not started,'[V136] Transaction already applied.');started=true
        for i,op in ipairs(operations)do applied=i;write(op,op.After)end
        if undo then decor.Parent=nil else backup.Parent=storage;decor.Parent=map end
    end
    function tx.Rollback()
        for i=applied,1,-1 do local op=operations[i];write(op,op.Before)end
        if undo then decor.Parent=map else decor:Destroy();backup:Destroy()end
        applied=0
    end
    function tx.Commit()
        if undo then decor:Destroy();backup:Destroy()end
    end
    return tx
end
function Art.ApplyRoutePolishV136(map)
    local tx=Art.BeginRoutePolishV136(map,false)
    local okay,why=xpcall(tx.Apply,debug.traceback)
    if not okay then tx.Rollback();error(why)end
    tx.Commit()
end

return Art
