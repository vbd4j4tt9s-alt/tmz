-- Smooth strips calculated once from the existing full-resolution RGBA bytes.
-- At most six colour/alpha stops per strip; never rebuilt on a render step.
local F={}
function F.Build(bytes,w,h,kind,yieldWork)
 assert(w>0 and h>0 and w<=1024 and h<=1024 and buffer.len(bytes)==w*h*4,'Invalid artwork pixels')
 local height=(kind=='NebulaSpark'or kind=='RoyalSpark')and 32 or 64
 local width=math.max(2,math.floor(height*w/h+.5));local strips={}
 local function pixel(x,y)
  x=math.clamp(x,0,w-1);y=math.clamp(y,0,h-1)
  local x0,y0=math.floor(x),math.floor(y);local x1,y1=math.min(x0+1,w-1),math.min(y0+1,h-1)
  local fx,fy=x-x0,y-y0;local p={}
  for c=0,3 do
   local a=buffer.readu8(bytes,(y0*w+x0)*4+c);local b=buffer.readu8(bytes,(y0*w+x1)*4+c)
   local d=buffer.readu8(bytes,(y1*w+x0)*4+c);local e=buffer.readu8(bytes,(y1*w+x1)*4+c)
   p[c+1]=math.floor((a+(b-a)*fx)*(1-fy)+(d+(e-d)*fx)*fy+.5)
  end
  return p
 end
 for y=0,height-1 do
  local row={};for x=0,width-1 do row[x+1]=pixel((x+.5)*w/width-.5,(y+.5)*h/height-.5)end
  local indices={1,width}
  while #indices<32 do
   local worst,at=28,nil
   for j=1,#indices-1 do local lo,hi=indices[j],indices[j+1]
    for k=lo+1,hi-1 do local t=(k-lo)/(hi-lo)
     for c=1,4 do
      local error=math.abs(row[lo][c]+(row[hi][c]-row[lo][c])*t-row[k][c])*(c==4 and 1 or row[k][4]/255)
      if error>worst then worst=error;at=k end
     end
    end
   end
   if not at then break end;table.insert(indices,at);table.sort(indices)
  end
  for j=1,#indices-1,5 do
   local last=math.min(j+5,#indices);local lo,hi=indices[j],indices[last];local keys={};local visible=false
   for i=j,last do local k=indices[i];local p=row[k];keys[#keys+1]={(k-lo)/(hi-lo),p[1],p[2],p[3],p[4]};if p[4]>=3 then visible=true end end
   if visible then strips[#strips+1]={lo-1,y,hi-lo+1,keys}end
  end
  if yieldWork and y%4==3 then yieldWork()end
 end
 return {Width=width,Height=height,Strips=strips}
end
return F
