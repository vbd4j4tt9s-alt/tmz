-- R151 treadmill polish: the belt images, made on each client so no upload is needed (TreadmillLook151 has the config).
-- Five tileable patterns, white with an alpha channel, tinted per biome by Texture.Color3 and scrolled by TreadmillFx:
--   slats   (64 x 64)   one soft seam per tile plus two rivets: the moving belt of every level
--   circuit (256 x 256) thin traces with 45-degree bends and round pads: the light lines of the ice / crystal / storm belts
--   crust   (128 x 128) cooling-lava plates (wrapped Voronoi cells) with transparent cracks: over the Neon lava belt the cracks glow
--   veins   (256 x 256) soft wavy lines: sun ripples, molten veins, prism light
--   stream  (128 x 256) columns of falling digits (a 3 x 5 pixel font), bright head, fading tail: the top Storm belt
-- The pattern code is pure (A.Pattern: name -> width, height, alpha buffer) and is the SAME algorithm as
-- docs/proposals/R151/treadmills/make_belt_textures.py, which writes the PNGs to upload instead (tests/run_treadmills.sh checks they match).
-- Where each image comes from (A.Paint), in order: an uploaded asset id in TreadmillLook151.Images; else the pattern drawn into an EditableImage
-- (AssetService:CreateEditableImage + WritePixelsBuffer, applied with Content.fromObject, made once per client, a few milliseconds per frame);
-- else the place's own grid texture (TreadmillLook151.Grid). Every Texture gets the attribute BeltRoute = uploaded / generated / grid, and
-- A.Summary() (published by TreadmillFx on the local player as TreadmillBeltTextures) lists the routes in use.
local A={Version=151}
A.Sizes={slats={64,64},circuit={256,256},crust={128,128},veins={256,256},stream={128,256}}
A.SliceSeconds=.004 -- generation work per frame before it waits for the next one

-- Park-Miller "minimal standard" generator: exact in doubles (Luau and Python give the same sequence).
local function rng(seed)
 local s=seed%2147483647;if s<=0 then s+=2147483646 end
 local r={}
 function r.u()s=(s*16807)%2147483647;return s/2147483647 end
 function r.int(a,b)return a+math.floor(r.u()*(b-a+1))end
 return r
end
local function clamp01(x)if x<0 then return 0 elseif x>1 then return 1 end;return x end
-- Alpha of a line / ring edge at distance d: a 1-pixel antialiased core of half-width hw, and a soft glow of radius gr.
local function profile(d,hw,gr,ga)
 local core=clamp01(hw+.5-d)*255
 local over=d-hw;if over<0 then over=0 end
 local g=1-over/gr;if g<0 then g=0 end
 local glow=ga*g*g
 if glow>core then return glow end;return core
end
local function canvas(w,h)
 local c={W=w,H=h,A=buffer.create(w*h)}
 function c.put(x,y,v) -- wrapped, keeps the brighter value
  v=math.floor(v+.5);if v<=0 then return end;if v>255 then v=255 end
  local i=(y%h)*w+(x%w)
  if buffer.readu8(c.A,i)<v then buffer.writeu8(c.A,i,v)end
 end
 return c
end
local function segment(c,x0,y0,x1,y1,hw,gr,ga)
 local R=hw+gr+1
 local dx,dy=x1-x0,y1-y0;local len2=dx*dx+dy*dy
 for py=math.floor(math.min(y0,y1)-R),math.ceil(math.max(y0,y1)+R)do
  for px=math.floor(math.min(x0,x1)-R),math.ceil(math.max(x0,x1)+R)do
   local cx,cy=px+.5,py+.5
   local t=0;if len2>0 then t=clamp01(((cx-x0)*dx+(cy-y0)*dy)/len2)end
   local ex,ey=cx-(x0+t*dx),cy-(y0+t*dy)
   c.put(px,py,profile(math.sqrt(ex*ex+ey*ey),hw,gr,ga))
  end
 end
end
local function ring(c,x,y,r,hw,gr,ga)
 local R=r+hw+gr+1
 for py=math.floor(y-R),math.ceil(y+R)do
  for px=math.floor(x-R),math.ceil(x+R)do
   local ex,ey=px+.5-x,py+.5-y
   c.put(px,py,profile(math.abs(math.sqrt(ex*ex+ey*ey)-r),hw,gr,ga))
  end
 end
end

local P={}
function P.slats(w,h,step)
 local c=canvas(w,h)
 for y=0,h-1 do
  local yc=y+.5;local d=math.min(yc,h-yc)*256/h
  local v=0;if d<=5 then v=235 elseif d<=16 then v=235*(1-(d-5)/11)^2 end
  if v>0 then for x=0,w-1 do c.put(x,y,v)end end
  if step then step()end
 end
 local r=7/256*w
 for _,cx in ipairs({22/256*w,w-22/256*w})do
  local cy=h/2
  for py=math.floor(cy-r-1),math.ceil(cy+r+1)do for px=math.floor(cx-r-1),math.ceil(cx+r+1)do
   local ex,ey=px+.5-cx,py+.5-cy
   c.put(px,py,clamp01(r+.5-math.sqrt(ex*ex+ey*ey))*200)
  end end
 end
 return c
end
local DIRS={{1,0},{0,1},{0,1},{-1,0},{0,-1},{1,1}}
function P.circuit(w,h,step)
 local c=canvas(w,h);local r=rng(151);local cell=w/8
 local segs,pads={},{}
 for _=1,9 do
  local x,y=r.int(0,7)*cell+cell/2,r.int(0,7)*cell+cell/2
  pads[#pads+1]={x,y}
  for _=1,r.int(2,4)do
   local d=DIRS[r.int(1,6)];local n=r.int(1,3)
   local nx,ny=x+d[1]*cell*n,y+d[2]*cell*n
   segs[#segs+1]={x,y,nx,ny};x,y=nx,ny
  end
  pads[#pads+1]={x,y}
 end
 for _,s in ipairs(segs)do segment(c,s[1],s[2],s[3],s[4],1.6,5,110);if step then step()end end
 for _,p in ipairs(pads)do ring(c,p[1],p[2],5.5,1.3,5,110);if step then step()end end
 return c
end
function P.crust(w,h,step)
 local c=canvas(w,h);local r=rng(5);local seeds={}
 for i=1,22 do seeds[i]={r.u()*w,r.u()*h}end
 for y=0,h-1 do
  local Y=y+.5
  for x=0,w-1 do
   local X=x+.5
   local d0,d1,i0=math.huge,math.huge,0;local x0,y0,x1,y1=0,0,0,0
   for i,s in ipairs(seeds)do
    local dx=(X-s[1]+w/2)%w-w/2;local dy=(Y-s[2]+h/2)%h-h/2
    local d=dx*dx+dy*dy
    if d<d0 then d1,x1,y1=d0,x0,y0;d0,i0,x0,y0=d,i,dx,dy
    elseif d<d1 then d1,x1,y1=d,dx,dy end
   end
   local sep=math.sqrt((x1-x0)^2+(y1-y0)^2);if sep<=0 then sep=1 end
   local edge=(d1-d0)/(2*sep)
   local shade=205+((i0-1)*37)%50
   local v=0;if edge>=2.2 then v=shade elseif edge>1.1 then v=shade*(edge-1.1)/1.1 end
   c.put(x,y,v)
  end
  if step then step()end
 end
 return c
end
function P.veins(w,h,step)
 local c=canvas(w,h)
 for y=0,h-1 do
  local yc=y+.5;local t=2*math.pi*yc/h
  for i=0,5 do
   local base=i*w/6+20*w/512;local amp=(26+10*(i%3))*w/512;local k=1+i%2;local e=10*w/512
   local xc=base+amp*math.sin(t*k)+e*math.sin(t*3+i)
   local slope=(amp*math.cos(t*k)*k+e*math.cos(t*3+i)*3)*2*math.pi/h
   local f=1/math.sqrt(1+slope*slope)
   local hw=(i%2==1)and 1.6 or 1.1
   local R=(hw+4+1)/f
   for px=math.floor(xc-R),math.floor(xc+R)do c.put(px,y,profile(math.abs(px+.5-xc)*f,hw,4,120))end
  end
  if step then step()end
 end
 return c
end
A.Font={['0']={7,5,5,5,7},['1']={2,6,2,2,7},['2']={7,1,7,4,7},['3']={7,1,7,1,7},['4']={5,5,7,1,1},['5']={7,4,7,1,7},['6']={7,4,7,5,7},
 ['7']={7,1,1,1,1},['8']={7,5,7,5,7},['9']={7,5,7,1,7}}
function P.stream(w,h,step)
 local c=canvas(w,h);local r=rng(9);local scale=3;local pitch=18
 for col=0,7 do
  local x0=col*16+3
  local head=r.int(0,h-1);local length=r.int(7,14)
  for j=0,math.floor(h/pitch)-1 do
   local fade=1-j/length
   if fade>0 then
    local glyph=A.Font[tostring(r.int(0,9))];local v=255*(.25+.75*fade)
    local y0=(head-j*pitch)%h
    for gy=1,5 do local row=glyph[gy]
     for gx=1,3 do if math.floor(row/2^(3-gx))%2==1 then
      for sy=0,scale-1 do for sx=0,scale-1 do c.put(x0+(gx-1)*scale+sx,y0+(gy-1)*scale+sy,v)end end
     end end
    end
   end
  end
  if step then step()end
 end
 return c
end
A.Patterns=P
-- name -> width, height, alpha buffer (w x h bytes, row 0 first). step (optional) is called now and then (to spread the work over frames).
function A.Pattern(name,step)
 local size=A.Sizes[name];local fn=P[name];if not(size and fn)then return nil end
 local c=fn(size[1],size[2],step)
 return c.W,c.H,c.A
end
-- White RGBA (what EditableImage:WritePixelsBuffer takes) from an alpha buffer.
function A.RGBA(w,h,alpha)
 local out=buffer.create(w*h*4)
 for i=0,w*h-1 do
  local o=i*4;buffer.writeu8(out,o,255);buffer.writeu8(out,o+1,255);buffer.writeu8(out,o+2,255);buffer.writeu8(out,o+3,buffer.readu8(alpha,i))
 end
 return out
end

-- Client side: one entry per image name, made once. Entry = {State = 'pending' | 'ready', Route, Value, Waiting = {textures}}.
local entries={}
local used={}
A.Hooks={} -- tests: Hooks.Create(w,h,rgba) -> object or error; Hooks.Content(object) -> content; Hooks.Spawn(fn); Hooks.Wait()
local function createImage(w,h,rgba)
 if A.Hooks.Create then return A.Hooks.Create(w,h,rgba)end
 local image=game:GetService('AssetService'):CreateEditableImage({Size=Vector2.new(w,h)})
 assert(image,'no EditableImage (memory budget or API unavailable)')
 image:WritePixelsBuffer(Vector2.zero,Vector2.new(w,h),rgba)
 return image
end
local function contentOf(image)if A.Hooks.Content then return A.Hooks.Content(image)end;return Content.fromObject(image)end
local function apply(texture,route,value,look)
 if not texture.Parent then return end
 local ok=true
 if route=='uploaded'then texture.Texture=value
 elseif route=='generated'then ok=pcall(function()texture.TextureContent=contentOf(value)end)
 else texture.Texture=look.Grid end
 if not ok then route='grid';texture.Texture=look.Grid end
 texture:SetAttribute('BeltRoute',route);used[route]=true
end
-- Paints one belt Texture (its attribute BeltImage names the image). publish(summary) is called after every change of route.
function A.Paint(texture,look,publish)
 local name=texture:GetAttribute('BeltImage')
 local id=look.Images and look.Images[name]
 if type(id)=='string'and id~=''then apply(texture,'uploaded',id,look);if publish then publish(A.Summary())end;return'uploaded'end
 local e=entries[name]
 if not e then
  e={State='pending',Waiting={}};entries[name]=e
  local spawn=A.Hooks.Spawn or task.spawn
  spawn(function()
   local t0=os.clock()
   local function step()if os.clock()-t0>A.SliceSeconds then if A.Hooks.Wait then A.Hooks.Wait()else task.wait()end;t0=os.clock()end end
   local ok,value=pcall(function()
    local w,h,alpha=A.Pattern(name,step);assert(w,'unknown belt image '..tostring(name))
    return createImage(w,h,A.RGBA(w,h,alpha))
   end)
   e.State='ready'
   if ok and value then e.Route,e.Value='generated',value else e.Route,e.Value='grid',nil;e.Why=tostring(value)end
   for _,t in ipairs(e.Waiting)do apply(t,e.Route,e.Value,look)end
   e.Waiting={}
   if publish then publish(A.Summary())end
  end)
 end
 if e.State=='ready'then apply(texture,e.Route,e.Value,look);if publish then publish(A.Summary())end;return e.Route end
 table.insert(e.Waiting,texture);texture:SetAttribute('BeltRoute','pending')
 return'pending'
end
-- The routes in use, e.g. "generated" or "generated+grid".
function A.Summary()
 local list={};for k in pairs(used)do list[#list+1]=k end;table.sort(list);return table.concat(list,'+')
end
function A.Entry(name)return entries[name]end
function A.Reset()for _,e in pairs(entries)do if e.Value then pcall(function()e.Value:Destroy()end)end end;table.clear(entries);table.clear(used)end
return A
