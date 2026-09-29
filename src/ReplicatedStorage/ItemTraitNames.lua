-- R63: display actual item traits; never infer a fruit's traits from its parent plant.
local T={};local Weather=require(script.Parent.WeatherTraits)
local C=Color3.fromRGB
T.Colors={Gold=C(255,208,71),Diamond=C(125,247,255),Drippy=C(89,191,255),Frosted=C(197,238,255),Charged=C(195,142,255)}
function T.Text(item)
 local names={}
 if item.Mutation=='Gold'or item.Mutation=='Diamond'then table.insert(names,item.Mutation)end
 for _,key in ipairs(Weather.List(item.Weather))do table.insert(names,key)end
 return table.concat(names,' · ')
end
-- Keep complete effect names; break only between traits for compact item views.
function T.Lines(item,limit)
 limit=math.clamp(math.floor(tonumber(limit)or 24),8,80)
 local names={};if item.Mutation=='Gold'or item.Mutation=='Diamond'then table.insert(names,item.Mutation)end
 for _,key in ipairs(Weather.List(item.Weather))do table.insert(names,key)end
 local lines={};local line=''
 for _,name in ipairs(names)do
  local nextLine=line==''and name or line..' · '..name
  if #nextLine>limit and line~=''then table.insert(lines,line);line=name else line=nextLine end
 end
 if line~=''then table.insert(lines,line)end
 return table.concat(lines,'\n'),#lines
end
function T.Tool(tool)return tool and {Mutation=tool:GetAttribute('Mutation')or tool:GetAttribute('PackMutation'),Weather=tool:GetAttribute('Weather')}or{}end
function T.Name(name,item)local prefix=T.Text(item);return prefix==''and name or prefix..' '..name end
function T.Style(label,item)
 local text=T.Text(item);if label:GetAttribute('TraitStyle')==text then return end
 label:SetAttribute('TraitStyle',text)
 local old=label:FindFirstChild('TraitGradient');if old then old:Destroy()end
 label.TextStrokeColor3=C(17,27,47);label.TextStrokeTransparency=.18
 label.TextColor3=text==''and C(200,213,223)or C(255,255,255)
 if text~=''then
  local traits=Weather.List(item.Weather)
  local a=T.Colors[item.Mutation]or T.Colors[traits[1]];local b=T.Colors[traits[#traits]]or a
  local gradient=Instance.new('UIGradient');gradient.Name='TraitGradient';gradient.Rotation=15
  gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(.5,C(255,255,255)),ColorSequenceKeypoint.new(1,b)});gradient.Parent=label
 end
end
return T
