-- Shared deterministic layout, including the two larger value cards on a wide screen.
local L={}
function L.Bundles(width,cardHeight)
 width=math.max(220,width);local gap=12;local rows={};local height=cardHeight or 286
 if width>=750 then
  local w=(width-gap*2)/3
  for i=1,3 do rows[i]={X=(i-1)*(w+gap),Y=0,W=w,H=height}end
  local large=(width-gap)/2
  for i=4,5 do rows[i]={X=(i-4)*(large+gap),Y=height+gap,W=large,H=height}end
  return rows,height*2+gap
 end
 local cols=width>=490 and 2 or 1;local w=(width-gap*(cols-1))/cols
 for i=1,5 do rows[i]={X=((i-1)%cols)*(w+gap),Y=math.floor((i-1)/cols)*(height+gap),W=w,H=height}end
 return rows,math.ceil(5/cols)*(height+gap)-gap
end
function L.PanelHeight(content,viewport,status)
 local maximum=math.max(180,math.min(800,viewport*.90))
 return math.min(maximum,math.max(math.min(280,maximum),content+127+(status and 34 or 0)))
end
return L
