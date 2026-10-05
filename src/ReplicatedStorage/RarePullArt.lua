-- R152 (owner: "planets have to look good by texturing", "improve look on the beam and assets used in the animations"): images drawn on the
-- client for the pull reveals, so nothing has to be uploaded. Each is pure pattern code (A.Pattern: name -> width, height, RGBA buffer, the
-- same numbers on every client and in the preview), turned into an EditableImage (AssetService:CreateEditableImage + WritePixelsBuffer) and
-- shown with Content.fromObject on an ImageLabel (planet / nebula / glow billboards, the seed card) or a Decal / Texture (the void's rune
-- circle, the palace carpet, banners, stained glass and wall pattern, the star map of deep space).
--   planet_gas   a banded gas giant (turbulent bands, a storm), lit from the upper left, limb-darkened, with an atmosphere rim
--   planet_rock  a cratered rocky world (rims lit, floors in shadow)
--   planet_ring  an icy world with a tilted, banded ring passing behind and in front of it
--   nebula_rose / nebula_blue   soft clouds of gas with a few stars in them
--   starmap      a tileable field of stars with a faint band of the galaxy
--   glow / halo  a soft round glow, a soft ring (tinted by ImageColor3)
--   runes        the void's magic circle: rings, a band of runes, a six-pointed star
--   carpet       the throne room's crimson carpet: gold borders and a running diamond motif (tiles along its length)
--   banner       a crimson banner with a gold border and a crown
--   glass        a stained-glass window under an arch
--   damask       the palace wall's cream damask (tiles)
-- Made once per client, a few at a time (A.SliceSeconds of work a frame), starting a while after the client starts (RarePullCinematic.Bind
-- calls A.Warm) so the first King / Cosmic / Secret pull usually finds them ready. A.Get(name) never waits: 'ready' (with the content),
-- 'pending' or 'failed'. Every user keeps its plain parts as the fallback (EditableImage off, its memory budget used up, low quality).
local A={Version=152}
A.SliceSeconds=.004
A.Hooks={} -- tests / preview: Create(w,h,rgba) -> object; Content(object) -> content; Spawn(fn); Wait()
A.Sizes={planet_gas={192,192},planet_rock={192,192},planet_ring={256,256},nebula_rose={128,128},nebula_blue={128,128},starmap={192,192},
 glow={64,64},halo={128,128},runes={256,256},carpet={64,128},banner={96,192},glass={96,192},damask={96,96}}
A.Order={'glow','halo','planet_gas','planet_rock','planet_ring','nebula_rose','nebula_blue','starmap','runes','carpet','banner','glass','damask'}
local floor,sqrt,sin,cos,atan2,abs,exp=math.floor,math.sqrt,math.sin,math.cos,math.atan2,math.abs,math.exp
local function clamp01(x)if x<0 then return 0 elseif x>1 then return 1 end;return x end
local function mix(a,b,t)return a+(b-a)*t end
local function smooth(t)t=clamp01(t);return t*t*(3-2*t)end
-- value noise on a lattice that wraps every `period` cells (so a pattern can tile)
local function hash(x,y,seed)
 local s=sin(x*127.1+y*311.7+seed*74.7)*43758.5453
 return s-floor(s)
end
local function vnoise(x,y,seed,period)
 local xi,yi=floor(x),floor(y);local fx,fy=x-xi,y-yi
 local x0,y0,x1,y1=xi,yi,xi+1,yi+1
 if period then x0%=period;x1%=period;y0%=period;y1%=period end
 local a,b=hash(x0,y0,seed),hash(x1,y0,seed);local c,d=hash(x0,y1,seed),hash(x1,y1,seed)
 local sx,sy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
 return mix(mix(a,b,sx),mix(c,d,sx),sy)
end
local function fbm(x,y,seed,octaves,period)
 local sum,amp,norm=0,.5,0
 for o=1,octaves do sum+=amp*vnoise(x,y,seed+o*31,period);norm+=amp;x*=2;y*=2;if period then period*=2 end;amp*=.5 end
 return sum/norm
end
local function canvas(w,h)
 local c={W=w,H=h,R=buffer.create(w*h*4)}
 function c.set(x,y,r,g,b,a)
  local i=(y*w+x)*4
  buffer.writeu8(c.R,i,floor(clamp01(r)*255+.5));buffer.writeu8(c.R,i+1,floor(clamp01(g)*255+.5));buffer.writeu8(c.R,i+2,floor(clamp01(b)*255+.5));buffer.writeu8(c.R,i+3,floor(clamp01(a)*255+.5))
 end
 return c
end
local P={}
-- Planets: an orthographic sphere of radius R (shares of the half size), lit from L; surface(u, v, nx, ny, nz) -> r, g, b.
local LX,LY,LZ=-.52,.56,.65
do local m=sqrt(LX*LX+LY*LY+LZ*LZ);LX/=m;LY/=m;LZ/=m end
local function sphere(w,h,R,atmo,surface,step,ring)
 local c=canvas(w,h)
 for py=0,h-1 do
  for px=0,w-1 do
   local x=(px+.5)/w*2-1;local y=1-(py+.5)/h*2
   local r,g,b,a=0,0,0,0
   local d=sqrt(x*x+y*y)/R
   -- the ring behind the planet first
   if ring then local rr,rg,rb,ra,front=ring(x,y);if ra>0 and not front then r,g,b,a=rr,rg,rb,ra end end
   if d<=1 then
    local nx,ny=x/R,y/R;local nz=sqrt(math.max(0,1-nx*nx-ny*ny))
    local lam=nx*LX+ny*LY+nz*LZ
    local light=.07+1.05*smooth((lam+.12)/1.12)
    local u=(atan2(nx,nz)/(2*math.pi))+.5;local v=math.asin(clamp01((ny+1)/2)*2-1)/math.pi+.5
    local sr,sg,sb=surface(u,v,nx,ny,nz)
    local limb=.55+.45*nz^.5
    sr,sg,sb=sr*light*limb,sg*light*limb,sb*light*limb
    -- the atmosphere at the edge, brighter on the lit side
    local rim=(1-nz)^2.6*(.35+.65*clamp01(lam+.35))
    sr+=atmo[1]*rim;sg+=atmo[2]*rim;sb+=atmo[3]*rim
    local edge=clamp01((1-d)*R*w*.5) -- 1 px of antialiasing
    r,g,b,a=mix(r,sr,edge),mix(g,sg,edge),mix(b,sb,edge),mix(a,1,edge)
   elseif d<1.28 then
    -- the halo of its atmosphere
    local k=(1-(d-1)/.28)^2.2*(.25+.55*clamp01((x*LX+y*LY)/math.max(1e-3,sqrt(x*x+y*y))+.4))
    local ha=k*.75
    if ha>a then r,g,b=mix(r,atmo[1],ha),mix(g,atmo[2],ha),mix(b,atmo[3],ha);a=math.max(a,ha)end
   end
   if ring then local rr,rg,rb,ra,front=ring(x,y);if ra>0 and front then r,g,b=mix(r,rr,ra),mix(g,rg,ra),mix(b,rb,ra);a=a+(1-a)*ra end end
   c.set(px,py,r,g,b,a)
  end
  if step then step()end
 end
 return c
end
P.planet_gas=function(w,h,step)
 return sphere(w,h,.74,{1,.78,.55},function(u,v)
  local turb=fbm(u*6,v*18,7,4,6)
  local band=sin(v*math.pi*11+turb*4.2)*.5+.5
  local fine=fbm(u*24,v*40,11,3,24)
  local r=mix(.93,.72,band)-.08*fine;local g=mix(.72,.42,band)-.06*fine;local b=mix(.52,.28,band)-.05*fine
  -- a storm: an oval eye in the southern bands
  local du,dv=(u-.62)*2.2,(v-.38)*5;local s=du*du+dv*dv
  if s<1 then local k=(1-s)^2;r=mix(r,.98,k*.55);g=mix(g,.55,k*.55);b=mix(b,.38,k*.55)end
  return r,g,b
 end,step)
end
P.planet_rock=function(w,h,step)
 local craters={}
 for i=1,26 do craters[i]={hash(i,1,5),hash(i,2,5)*.8+.1,.02+.07*hash(i,3,5)^2}end
 return sphere(w,h,.74,{.62,.78,1},function(u,v)
  local base=fbm(u*8,v*5,23,5,8)
  local r,g,b=mix(.34,.62,base),mix(.36,.6,base),mix(.42,.66,base)
  for _,c in ipairs(craters)do
   local du=abs(u-c[1]);if du>.5 then du=1-du end
   local dd=sqrt((du*2)^2+(v-c[2])^2)/c[3]
   if dd<1.25 then
    local floorDark=dd<.8 and(.18*(1-dd/.8))or 0
    local rim=dd>=.8 and(.22*(1-abs(dd-1)/.25))or 0
    r+=rim-floorDark;g+=rim-floorDark;b+=rim-floorDark
   end
  end
  return r,g,b
 end,step)
end
P.planet_ring=function(w,h,step)
 local R=.42;local tilt=.36
 local function ring(x,y)
  -- the ring's plane, tipped toward the viewer: a flat ellipse; its near half (lower) passes in front of the planet
  local ry=y/tilt;local rho=sqrt(x*x+ry*ry)/R
  if rho<1.25 or rho>2.25 then return 0,0,0,0,false end
  local band=.62+.38*sin(rho*31)*sin(rho*7+1)
  local gap=(rho>1.66 and rho<1.73)and .12 or 1
  local edge=smooth((rho-1.25)/.06)*smooth((2.25-rho)/.1)
  local a=clamp01(band*gap*edge)
  local lit=.55+.45*clamp01(-x*.6+.6)
  return .86*lit,.88*lit,.95*lit,a,ry<0
 end
 return sphere(w,h,R,{.62,.86,1},function(u,v)
  local t=fbm(u*5,v*10,41,4,5)
  local band=sin(v*math.pi*7+t*3)*.5+.5
  return mix(.72,.9,band),mix(.82,.95,band),mix(.95,1,band)
 end,step,ring)
end
local function nebula(w,h,seed,c1,c2,step)
 local c=canvas(w,h)
 for py=0,h-1 do
  for px=0,w-1 do
   local x=(px+.5)/w*2-1;local y=(py+.5)/h*2-1
   local r2=x*x+y*y;local fall=clamp01(1-r2)^1.1
   local n=fbm(x*2.2+3,y*2.2+7,seed,4)
   local m=fbm(x*3.1+11,y*3.1+5,seed+9,3)
   local dens=clamp01((n-.3)*2.6)^1.2*fall
   local k=clamp01(m*1.4-.2)
   local r,g,b=mix(c1[1],c2[1],k),mix(c1[2],c2[2],k),mix(c1[3],c2[3],k)
   local core=clamp01(dens*1.6-.6)
   r,g,b=mix(r,1,core*.5),mix(g,1,core*.5),mix(b,1,core*.5)
   local a=dens*.85
   local s=hash(px,py,seed+77);if s>.9975 and fall>.15 then r,g,b,a=1,1,1,math.max(a,.9*fall)end
   c.set(px,py,r,g,b,a)
  end
  if step then step()end
 end
 return c
end
P.nebula_rose=function(w,h,step)return nebula(w,h,101,{1,.35,.75},{.55,.35,1},step)end
P.nebula_blue=function(w,h,step)return nebula(w,h,202,{.3,.55,1},{.35,.95,1},step)end
P.starmap=function(w,h,step)
 local c=canvas(w,h)
 for py=0,h-1 do
  for px=0,w-1 do
   local u,v=px/w,py/h
   local neb=fbm(u*4,v*4,303,3,4)
   local band=exp(-((v-.5-.12*sin(u*math.pi*2))^2)/.02)
   local glowA=clamp01((neb-.45)*1.6)*(.25+.75*band)*.55
   local r,g,b=.18+.3*neb,.16+.2*neb,.4+.4*neb
   local s=hash(px,py,404)
   local a=glowA
   if s>.992 then local k=(s-.992)/.008;r,g,b=mix(.8,1,k),mix(.85,1,k),1;a=.55+.45*k end
   c.set(px,py,r,g,b,a)
  end
  if step then step()end
 end
 return c
end
P.glow=function(w,h,step)
 local c=canvas(w,h)
 for py=0,h-1 do
  for px=0,w-1 do
   local x=(px+.5)/w*2-1;local y=(py+.5)/h*2-1;local d=sqrt(x*x+y*y)
   local a=clamp01(exp(-d*d*4.2)-.015*d)
   c.set(px,py,1,1,1,a)
  end
  if step then step()end
 end
 return c
end
P.halo=function(w,h,step)
 local c=canvas(w,h)
 for py=0,h-1 do
  for px=0,w-1 do
   local x=(px+.5)/w*2-1;local y=(py+.5)/h*2-1;local d=sqrt(x*x+y*y)
   local a=exp(-((d-.72)^2)/.006)*.95+exp(-((d-.72)^2)/.05)*.35+exp(-d*d*3)*.18
   c.set(px,py,1,1,1,clamp01(a)*clamp01((1-d)*8))
  end
  if step then step()end
 end
 return c
end
P.runes=function(w,h,step)
 local c=canvas(w,h)
 local function line(px,py,ax,ay,bx,by,width)
  local dx,dy=bx-ax,by-ay;local t=clamp01(((px-ax)*dx+(py-ay)*dy)/(dx*dx+dy*dy));local qx,qy=ax+dx*t,ay+dy*t
  return clamp01(1-(sqrt((px-qx)^2+(py-qy)^2)-width)/.006)
 end
 local tri={}
 for k=0,5 do local a=k*math.pi/3+math.pi/2;tri[k+1]={cos(a)*.6,sin(a)*.6}end
 for py=0,h-1 do
  for px=0,w-1 do
   local x=(px+.5)/w*2-1;local y=(py+.5)/h*2-1;local d=sqrt(x*x+y*y);local ang=atan2(y,x)
   local a=0
   for _,ring in ipairs({{.95,.006},{.86,.004},{.62,.009},{.3,.004}})do a=math.max(a,clamp01(1-(abs(d-ring[1])-ring[2])/.006))end
   -- the band of runes: one glyph per slot, made of a few short strokes
   if d>.87 and d<.945 then
    local slots=36;local s=floor((ang/(2*math.pi)+.5)*slots);local f=(ang/(2*math.pi)+.5)*slots-s
    local r=(d-.87)/.075
    local g=0
    if hash(s,1,9)>.3 and abs(f-.5)<.06 then g=1 end
    if hash(s,2,9)>.45 and abs(r-.5)<.09 and f>.25 and f<.75 then g=1 end
    if hash(s,3,9)>.5 and abs((f-.25)-(r*.5))<.05 and f<.8 then g=1 end
    if hash(s,4,9)>.6 and abs(r-.18)<.08 and f>.3 and f<.7 then g=1 end
    a=math.max(a,g*.95)
   end
   -- a six-pointed star (two triangles) inside the inner ring
   if d<.64 then for k=1,6 do local p,q=tri[k],tri[(k+1)%6+1];a=math.max(a,line(x,y,p[1],p[2],q[1],q[2],.004)*.9)end end
   local glow=exp(-((d-.62)^2)/.02)*.18+exp(-((d-.9)^2)/.01)*.14
   local alpha=clamp01(a+glow)*clamp01((1-d)*12)
   c.set(px,py,.78+.22*a,.55+.4*a,1,alpha)
  end
  if step then step()end
 end
 return c
end
P.carpet=function(w,h,step)
 local c=canvas(w,h)
 for py=0,h-1 do
  for px=0,w-1 do
   local u,v=(px+.5)/w,(py+.5)/h
   local weave=.92+.08*vnoise(px*.5,py*.5,61,floor(w*.5))
   local r,g,b=.62*weave,.07*weave,.13*weave
   local border=u<.09 or u>.91;local line=(u>.13 and u<.16)or(u>.84 and u<.87)
   if border then r,g,b=.86,.64,.22 end
   if line then r,g,b=.9,.7,.28 end
   if u>.06 and u<.075 or u>.925 and u<.94 then r,g,b=.42,.05,.1 end
   -- the running diamond: one per tile, gold outline and a darker heart
   local du,dv=abs(u-.5)/.28,abs(v-.5)/.42;local dd=du+dv
   if dd<1 and dd>.86 then r,g,b=.9,.72,.3 elseif dd<.45 then r,g,b=r*.75,g*.6,b*.65 end
   if dd<.16 then r,g,b=.92,.76,.34 end
   c.set(px,py,r,g,b,1)
  end
  if step then step()end
 end
 return c
end
P.banner=function(w,h,step)
 local c=canvas(w,h)
 for py=0,h-1 do
  for px=0,w-1 do
   local u,v=(px+.5)/w,(py+.5)/h
   local fold=.9+.1*sin(u*math.pi*5)
   local r,g,b=.66*fold,.08*fold,.14*fold
   local a=1
   -- a swallow-tail end
   if v>.86 then local cut=(v-.86)/.14;if abs(u-.5)<cut*.5 then a=0 end end
   local inside=u>.08 and u<.92 and v>.05 and v<.84
   if not inside and a>0 then r,g,b=.86,.66,.24 end
   -- the crown: a band, three points, jewels
   local cx,cy=(u-.5)/.32,(v-.34)/.16
   if abs(cx)<1 and cy>.25 and cy<.7 then r,g,b=.93,.74,.28 end
   if cy<=.25 and cy>-.9 then
    for _,px0 in ipairs({-.8,0,.8})do local k=1-abs(cx-px0)/.32;if k>0 and cy>.25-1.15*k then r,g,b=.93,.74,.28 end end
   end
   for _,j in ipairs({{-.8,-.95},{0,-1.05},{.8,-.95}})do if(cx-j[1])^2+((cy-j[2])*1.6)^2<.035 then r,g,b=.95,.2,.25 end end
   if(cx)^2+((cy-.48)*2)^2<.03 then r,g,b=.25,.45,1 end
   c.set(px,py,r,g,b,a)
  end
  if step then step()end
 end
 return c
end
P.glass=function(w,h,step)
 local c=canvas(w,h)
 local palette={{.25,.45,.95},{.95,.78,.3},{.85,.2,.25},{.95,.95,.9},{.3,.75,.55}}
 for py=0,h-1 do
  for px=0,w-1 do
   local u,v=(px+.5)/w,(py+.5)/h
   local x=(u-.5)*2
   -- an arch: the top is a half circle
   local inArch=v>.2 or(x*x+((v-.2)/.2)^2*(1)<1)
   local a=inArch and 1 or 0
   local gu,gv=u*5+v*2.5,v*7-u*2.5
   local cu,cv=floor(gu),floor(gv);local fu,fv=gu-cu,gv-cv
   local lead=math.min(fu,1-fu,fv,1-fv)<.07
   local col=palette[floor(hash(cu,cv,17)*#palette)+1]
   local glow=.75+.25*vnoise(u*6,v*8,19)
   local r,g,b=col[1]*glow,col[2]*glow,col[3]*glow
   if lead then r,g,b=.16,.14,.12 end
   local frame=u<.05 or u>.95 or v>.97
   if frame then r,g,b=.75,.58,.25 end
   c.set(px,py,r,g,b,a)
  end
  if step then step()end
 end
 return c
end
P.damask=function(w,h,step)
 local c=canvas(w,h)
 for py=0,h-1 do
  for px=0,w-1 do
   local u,v=(px+.5)/w,(py+.5)/h
   local x,y=(u-.5)*2,(v-.5)*2
   -- a damask flourish: a four-petal outline, a small ring at its heart, quarter arcs in the corners (they meet the next tile's)
   local rr=sqrt(x*x+y*y);local ang=atan2(y,x)
   local outline=exp(-((rr-(.44+.2*cos(ang*4)))^2)/.0022)
   local inner=exp(-((rr-.15)^2)/.0012)+exp(-(rr*rr)/.004)*.8
   local cr=sqrt((1-abs(x))^2+(1-abs(y))^2)
   local corner=exp(-((cr-.36)^2)/.0018)
   local k=clamp01(outline*.9+inner*.8+corner*.75)
   local paper=.94+.04*vnoise(px*.25,py*.25,71,floor(w*.25))
   local r,g,b=.93*paper,.88*paper,.78*paper
   r,g,b=mix(r,.78,k*.6),mix(g,.62,k*.6),mix(b,.36,k*.6)
   c.set(px,py,r,g,b,1)
  end
  if step then step()end
 end
 return c
end
A.Patterns=P
-- name -> width, height, RGBA buffer (row 0 first). step (optional) is called now and then (to spread the work over frames).
function A.Pattern(name,step)
 local size=A.Sizes[name];local fn=P[name];if not(size and fn)then return nil end
 local c=fn(size[1],size[2],step)
 return c.W,c.H,c.R
end
-- Client side ------------------------------------------------------------------------------------------------------------------------------
local entries={} -- name -> {State='pending'|'ready'|'failed', Value, Content, Why}
local queue={};local worker=false
local function createImage(w,h,rgba)
 if A.Hooks.Create then return A.Hooks.Create(w,h,rgba)end
 local image=game:GetService('AssetService'):CreateEditableImage({Size=Vector2.new(w,h)})
 assert(image,'no EditableImage (memory budget or API unavailable)')
 image:WritePixelsBuffer(Vector2.zero,Vector2.new(w,h),rgba)
 return image
end
local function contentOf(image)if A.Hooks.Content then return A.Hooks.Content(image)end;return Content.fromObject(image)end
local function work()
 worker=true
 local t0=os.clock()
 local function step()if os.clock()-t0>A.SliceSeconds then if A.Hooks.Wait then A.Hooks.Wait()else task.wait()end;t0=os.clock()end end
 while #queue>0 do
  local name=table.remove(queue,1);local e=entries[name]
  local ok,value=pcall(function()
   local w,h,rgba=A.Pattern(name,step);assert(w,'unknown image '..tostring(name))
   local image=createImage(w,h,rgba)
   return {Image=image,Content=contentOf(image)}
  end)
  if ok and value then e.State='ready';e.Value=value.Image;e.Content=value.Content else e.State='failed';e.Why=tostring(value)end
  step()
 end
 worker=false
end
-- Starts making these images (in the background, a slice a frame). Returns at once.
function A.Request(names)
 local added=false
 for _,name in ipairs(names)do
  if A.Sizes[name]and not entries[name]then entries[name]={State='pending'};queue[#queue+1]=name;added=true end
 end
 if added and not worker then local spawn=A.Hooks.Spawn or task.spawn;spawn(work)end
end
-- 'ready', content | 'pending' | 'failed' (nil when never asked for)
function A.Get(name)
 local e=entries[name];if not e then return nil end
 return e.State,e.Content
end
-- On low quality / FastMode (ClientFxBudget tier 1) nothing is drawn: the plain parts are used.
function A.Allowed()
 local ok,B=pcall(require,script.Parent.ClientFxBudget)
 if ok and B then local ok2,low=pcall(B.Low);if ok2 and low then return false end end
 return true
end
-- Some time after the client starts (RarePullCinematic.Bind): every image, a slice a frame.
A.WarmDelay=15
function A.Warm(delay)
 if not A.Allowed()then return false end
 task.delay(delay or A.WarmDelay,function()A.Request(A.Order)end)
 return true
end
-- Shows image `name` on target (an ImageLabel: ImageContent; a Decal / Texture: TextureContent) once it is ready; returns true when shown
-- now. A target that cannot take it keeps its fallback (the caller made it so that it looks fine without).
function A.Apply(target,name)
 local state,content=A.Get(name)
 if state~='ready'then return false end
 local prop=(target:IsA('ImageLabel')or target:IsA('ImageButton'))and'ImageContent'or'TextureContent'
 local ok=pcall(function()target[prop]=content end)
 if ok then target:SetAttribute('RarePullArt',name)end
 return ok
end
function A.Reset()for _,e in pairs(entries)do if e.Value then pcall(function()e.Value:Destroy()end)end end;table.clear(entries);table.clear(queue)end
return A
