-- V106: original geometric pictograms. Coordinates are percent of the square canvas.
local icons={["Shop"]={{["Kind"]="Line",["Points"]={{12,17},{23,17},{33,65},{77,65},{86,32},{27,32}},["Width"]=7},{["Kind"]="Circle",["X"]=39,["Y"]=82,["R"]=7,["Fill"]=true},{["Kind"]="Circle",["X"]=71,["Y"]=82,["R"]=7,["Fill"]=true}},["Base"]={{["Kind"]="Line",["Points"]={{12,46},{50,14},{88,46}},["Width"]=7},{["Kind"]="Line",["Points"]={{23,42},{23,85},{77,85},{77,42}},["Width"]=7},{["Kind"]="Line",["Points"]={{41,84},{41,61},{59,61},{59,84}},["Width"]=7}},["Sell"]={{["Kind"]="Circle",["X"]=35,["Y"]=62,["R"]=22,["Fill"]=false},{["Kind"]="Line",["Points"]={{35,49},{35,75}},["Width"]=7},{["Kind"]="Line",["Points"]={{69,17},{88,35},{69,53}},["Width"]=7},{["Kind"]="Line",["Points"]={{49,35},{86,35}},["Width"]=7}},["Bag"]={{["Kind"]="Line",["Points"]={{23,31},{77,31},{83,85},{17,85},{23,31}},["Width"]=7},{["Kind"]="Line",["Points"]={{35,32},{35,19},{65,19},{65,32}},["Width"]=7},{["Kind"]="Line",["Points"]={{34,59},{66,59}},["Width"]=7}},["Index"]={{["Kind"]="Line",["Points"]={{50,27},{35,20},{13,23},{13,77},{35,74},{50,81},{65,74},{87,77},{87,23},{65,20},{50,27},{50,81}},["Width"]=7}},["Close"]={{["Kind"]="Line",["Points"]={{24,24},{76,76}},["Width"]=10},{["Kind"]="Line",["Points"]={{76,24},{24,76}},["Width"]=10}},["Check"]={{["Kind"]="Line",["Points"]={{18,49},{41,73},{84,25}},["Width"]=10}},["Lock"]={{["Kind"]="Line",["Points"]={{29,43},{29,27},{38,16},{62,16},{71,27},{71,43}},["Width"]=7},{["Kind"]="Line",["Points"]={{22,43},{78,43},{78,84},{22,84},{22,43}},["Width"]=7},{["Kind"]="Circle",["X"]=50,["Y"]=62,["R"]=5,["Fill"]=true},{["Kind"]="Line",["Points"]={{50,62},{50,73}},["Width"]=5}},["Equip"]={{["Kind"]="Line",["Points"]={{50,87},{50,44}},["Width"]=7},{["Kind"]="Polygon",["Points"]={{48,62},{22,55},{17,29},{40,35},{49,50}}},{["Kind"]="Polygon",["Points"]={{52,48},{57,22},{83,16},{77,42}}}},["Unequip"]={{["Kind"]="Line",["Points"]={{22,42},{22,83},{78,83},{78,42}},["Width"]=7},{["Kind"]="Line",["Points"]={{50,12},{50,62}},["Width"]=7},{["Kind"]="Line",["Points"]={{34,47},{50,63},{66,47}},["Width"]=7}},["Trails"]={{["Kind"]="Polygon",["Points"]={{56,8},{21,55},{47,55},{39,92},{80,41},{54,41}}}},["Accessories"]={{["Kind"]="Line",["Points"]={{17,77},{10,30},{32,48},{50,18},{68,48},{90,30},{83,77},{17,77}},["Width"]=7},{["Kind"]="Line",["Points"]={{22,88},{78,88}},["Width"]=7}},["Gear"]={{["Kind"]="Line",["Points"]={{22,18},{37,33},{54,33},{68,18}},["Width"]=7},{["Kind"]="Line",["Points"]={{22,18},{19,42},{35,57},{53,55},{76,83}},["Width"]=7},{["Kind"]="Line",["Points"]={{68,18},{76,38},{65,52},{85,73},{76,83}},["Width"]=7}},["Stop"]={{["Kind"]="Polygon",["Points"]={{27,24},{73,24},{73,76},{27,76}}}},["All"]={{["Kind"]="Polygon",["Points"]={{16,16},{43,16},{43,43},{16,43}}},{["Kind"]="Polygon",["Points"]={{57,16},{84,16},{84,43},{57,43}}},{["Kind"]="Polygon",["Points"]={{16,57},{43,57},{43,84},{16,84}}},{["Kind"]="Polygon",["Points"]={{57,57},{84,57},{84,84},{57,84}}}},["Forest"]={{["Kind"]="Polygon",["Points"]={{50,10},{18,57},{34,57},{14,76},{86,76},{66,57},{82,57}}},{["Kind"]="Line",["Points"]={{50,75},{50,94}},["Width"]=7}},["Jungle"]={{["Kind"]="Line",["Points"]={{34,86},{43,57},{61,33},{79,16}},["Width"]=7},{["Kind"]="Polygon",["Points"]={{43,57},{14,47},{19,26},{47,42}}},{["Kind"]="Polygon",["Points"]={{61,33},{48,10},{70,10},{79,16}}},{["Kind"]="Polygon",["Points"]={{43,57},{75,42},{86,56},{63,72}}}},["Desert"]={{["Kind"]="Line",["Points"]={{49,88},{49,20},{54,15},{59,20},{59,88}},["Width"]=7},{["Kind"]="Line",["Points"]={{48,59},{22,59},{22,36}},["Width"]=7},{["Kind"]="Line",["Points"]={{59,49},{80,49},{80,28}},["Width"]=7}},["Snow"]={{["Kind"]="Line",["Points"]={{50,9},{50,91}},["Width"]=7},{["Kind"]="Line",["Points"]={{14,29},{86,71}},["Width"]=7},{["Kind"]="Line",["Points"]={{14,71},{86,29}},["Width"]=7},{["Kind"]="Line",["Points"]={{38,16},{50,27},{62,16}},["Width"]=5},{["Kind"]="Line",["Points"]={{38,84},{50,73},{62,84}},["Width"]=5},{["Kind"]="Line",["Points"]={{15,43},{29,38},{29,24}},["Width"]=5},{["Kind"]="Line",["Points"]={{71,76},{71,62},{85,57}},["Width"]=5},{["Kind"]="Line",["Points"]={{15,57},{29,62},{29,76}},["Width"]=5},{["Kind"]="Line",["Points"]={{71,24},{71,38},{85,43}},["Width"]=5}},["Lava"]={{["Kind"]="Polygon",["Points"]={{49,10},{78,43},{85,65},{74,85},{49,93},{25,83},{16,61},{30,35},{32,59},{46,48}}}},["Crystal"]={{["Kind"]="Line",["Points"]={{34,14},{66,14},{86,43},{50,91},{14,43},{34,14}},["Width"]=7},{["Kind"]="Line",["Points"]={{14,43},{86,43}},["Width"]=7},{["Kind"]="Line",["Points"]={{34,14},{34,43},{50,91},{66,43},{66,14}},["Width"]=7}},["Storm"]={{["Kind"]="Circle",["X"]=34,["Y"]=41,["R"]=17,["Fill"]=true},{["Kind"]="Circle",["X"]=54,["Y"]=30,["R"]=22,["Fill"]=true},{["Kind"]="Circle",["X"]=72,["Y"]=43,["R"]=18,["Fill"]=true},{["Kind"]="Polygon",["Points"]={{18,40},{84,40},{84,59},{18,59}}},{["Kind"]="Polygon",["Points"]={{54,52},{36,76},{49,76},{44,96},{70,68},{56,68}}}},["StormWarning"]={{["Kind"]="Polygon",["Points"]={{50,3},{98,94},{2,94}},["Color"]={255,215,0}},{["Kind"]="Polygon",["Points"]={{50,10},{91,90},{9,90}},["Color"]={8,10,13}},{["Kind"]="Polygon",["Points"]={{50,17},{85,86},{15,86}},["Color"]={255,215,0}},{["Kind"]="Circle",["X"]=37,["Y"]=60,["R"]=10,["Fill"]=true,["Color"]={8,10,13}},{["Kind"]="Circle",["X"]=48,["Y"]=51,["R"]=14,["Fill"]=true,["Color"]={8,10,13}},{["Kind"]="Circle",["X"]=64,["Y"]=57,["R"]=12,["Fill"]=true,["Color"]={8,10,13}},{["Kind"]="Polygon",["Points"]={{30,58},{72,58},{72,69},{30,69}},["Color"]={8,10,13}},{["Kind"]="Polygon",["Points"]={{50,39},{60,39},{55,56},{63,56},{45,83},{49,64},{42,64}},["Color"]={255,215,0}},{["Kind"]="Polygon",["Points"]={{52,42},{57,42},{52,59},{58,59},{48,75},{52,61},{46,61}},["Color"]={8,10,13}}}}

icons.Boots={{Kind='Polygon',Points={{20,16},{49,16},{49,55},{77,63},{83,78},{20,78}}},{Kind='Line',Points={{22,85},{83,85}},Width=6},{Kind='Line',Points={{29,34},{44,34}},Width=6}}
local Glyphs = {}
function Glyphs.Draw(parent, name, ink)
    local shapes = assert(icons[name], "Unknown pictogram: "..tostring(name))
    local root = Instance.new("Frame")
    root.Name = "Pictogram"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundTransparency = 1
    root.Active = false
    root.Parent = parent
    local function rect(x,y,w,h,color)
        local p=Instance.new("Frame")
        p.Position=UDim2.fromScale(x/100,y/100)
        p.Size=UDim2.fromScale(w/100,h/100)
        p.BackgroundColor3=color
        p.BorderSizePixel=0
        p.Active=false
        p.Parent=root
        return p
    end
    for _,shape in ipairs(shapes) do
        local color=shape.Color and Color3.fromRGB(table.unpack(shape.Color)) or ink
        if shape.Kind=="Line" then
            for i=2,#shape.Points do
                local a,b=shape.Points[i-1],shape.Points[i]
                local dx,dy=b[1]-a[1],b[2]-a[2]
                local p=rect((a[1]+b[1])/2,(a[2]+b[2])/2,math.sqrt(dx*dx+dy*dy),shape.Width or 7,color)
                p.AnchorPoint=Vector2.new(.5,.5)
                p.Rotation=math.deg(math.atan2(dy,dx))
                local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=p
            end
        elseif shape.Kind=="Circle" then
            local p=rect(shape.X-shape.R,shape.Y-shape.R,shape.R*2,shape.R*2,color)
            local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=p
            if not shape.Fill then
                p.BackgroundTransparency=1
                local stroke=Instance.new("UIStroke");stroke.Color=color;stroke.Thickness=2.5;stroke.Parent=p
            end
        else
            -- Bounded vector scan conversion. No asset upload or image permission required.
            local step=name=="StormWarning" and 1 or 2
            for y=0,100-step,step do
                local scan=y+step/2;local hits={}
                for i,a in ipairs(shape.Points) do
                    local b=shape.Points[i%#shape.Points+1]
                    if (a[2]<=scan and b[2]>scan)or(b[2]<=scan and a[2]>scan) then
                        table.insert(hits,a[1]+(scan-a[2])*(b[1]-a[1])/(b[2]-a[2]))
                    end
                end
                table.sort(hits)
                for i=1,#hits-1,2 do rect(hits[i],y,hits[i+1]-hits[i],step+.08,color) end
            end
        end
    end
    return root
end
return Glyphs
