-- R133/R134 PROPOSAL, from R132 (owner: "seed shapes can be changed, they don't have to look the same for all"; "Storm Sovereign can be a
-- thunderbolt shaped seed"). A seed body is a stack of gradient bands like before; each band has one or more spans.
-- Profile shapes are round in cross-section (oval, round, long, flat, teardrop, drop, pointed, bean, acorn) or faceted
-- (gem, shard); outline shapes are a 2D silhouette cut out of a soft slab (bolt, stars, heart, crescent, flame, mushroom,
-- bell, tulip). Seed space as before: x across, y up, the front faces -Z.
local S={}
local N=30
local sqrt,abs,max,min,sin,cos,pi=math.sqrt,math.abs,math.max,math.min,math.sin,math.cos,math.pi
local function round(t)return sqrt(max(0,1-t*t))end
-- Profile shapes: f(t) -> width, depth, x offset (t runs -1 bottom .. 1 top); H = half height.
local Profiles={
 Oval={H=.75,f=function(t)local s=round(t);return 1.08*s,.76*s,0 end},
 Round={H=.6,f=function(t)local s=round(t);return 1.2*s,1.0*s,0 end},
 Long={H=.92,f=function(t)local s=round(t);return .8*s,.62*s,0 end},
 Flat={H=.74,f=function(t)local s=round(t)*(1-.18*t);return 1.12*s,.4*s,0 end},
 Teardrop={H=.8,f=function(t)local s=round(t)*(1-.4*t);return 1.05*s,.8*s,0 end},
 Drop={H=.8,f=function(t)local s=round(t)*(1+.4*t);return 1.05*s,.8*s,0 end},
 Pointed={H=.9,f=function(t)local s=(max(0,1-abs(t)^1.7))^.75;return .95*s,.7*s,0 end},
 Bean={H=.78,f=function(t)local s=round(t);return .92*s,.7*s,.3*(1-t*t)-.12 end},
 Acorn={H=.72,f=function(t)
  if t>.3 then local s=round((t-.3)/.7*.9+.1);return 1.22*max(.25,s),1.05*max(.25,s),0,true end
  local s=round((t-.3)/1.3);return 1.0*s,.9*s,0 end},
 Gem={H=.8,Faceted=true,f=function(t)local s=t>.5 and .7-(t-.5)*.4 or(t+1)/1.5*.7;return 1.25*s,1.25*s,0 end},
 Shard={H=1.0,Faceted=true,f=function(t)local s=t>-.55 and(1-t)/1.55 or(t+1)/.45;return .7*s,.7*s,.05*t end},
 -- R134: a bell pepper: broad shoulders, blunt bottom (the lobes are added by its signature).
 Pepper={H=.82,f=function(t)local s=(max(0,1-t*t))^.42*(1+.2*t);return 1.0*s,.9*s,0 end},
}
-- Outline shapes: polygon in [-1,1] units, scaled by HW (half width) and H; D = slab thickness.
local function star(points,inner)
 local out={}
 for i=0,points*2-1 do local r=i%2==0 and 1 or inner;local a=i*pi/points;out[#out+1]={sin(a)*r,cos(a)*r}end
 return out
end
local function heart()
 local out={}
 for i=0,47 do local t=i/48*pi*2;local x=16*sin(t)^3;local y=13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t);out[#out+1]={x/17,(y+2.5)/14.5}end
 return out
end
local function crescent()
 local out={}
 for i=0,16 do local a=math.rad(125-i*250/16);out[#out+1]={cos(a),sin(a)}end
 for i=0,14 do local a=math.rad(-112+i*224/14);out[#out+1]={-.42+cos(a)*.88,sin(a)*.88}end
 return out
end
local function flame()
 local right,left={},{}
 for i=0,20 do
  local y=-1+i*.1;local w
  if y<-.15 then w=round((y+.15)/.85)*.85 else w=.85*(max(0,1-(y+.15)/1.15))^1.25 end
  local c=y>0 and .16*sin(y*5.5)or 0
  right[#right+1]={c+w,y};table.insert(left,1,{c-w,y})
 end
 for _,p in ipairs(left)do right[#right+1]=p end
 return right
end
local Outlines={
 Bolt={HW=.82,H=1.0,D=.52,P={{-.05,1},{.62,1},{.18,.22},{.55,.22},{-.35,-1},{-.02,-.12},{-.42,-.12}}},
 Star={HW=.85,H=.85,D=.48,P=star(5,.45)},
 Star6={HW=.85,H=.85,D=.46,P=star(6,.55)},
 Heart={HW=.65,H=.72,D=.55,P=heart()},
 Crescent={HW=.62,H=.85,D=.48,P=crescent()},
 Flame={HW=.62,H=.85,D=.55,P=flame()},
 Mushroom={HW=.62,H=.75,D=.62,P={{1,.05},{.92,.45},{.7,.78},{.38,.96},{0,1},{-.38,.96},{-.7,.78},{-.92,.45},{-1,.05},{-.3,.05},{-.36,-1},{.36,-1},{.3,.05}}},
 Bell={HW=.6,H=.75,D=.62,P={{0,1},{.32,.95},{.46,.75},{.5,.4},{.56,0},{.7,-.5},{.95,-.85},{.9,-1},{-.9,-1},{-.95,-.85},{-.7,-.5},{-.56,0},{-.5,.4},{-.46,.75},{-.32,.95}}},
 Tulip={HW=.6,H=.8,D=.62,P={{0,-1},{.4,-.85},{.56,-.4},{.56,.3},{.66,.88},{.35,.45},{0,.95},{-.35,.45},{-.66,.88},{-.56,.3},{-.56,-.4},{-.4,-.85}}},
}
S.Names={}
for k in pairs(Profiles)do table.insert(S.Names,k)end;for k in pairs(Outlines)do table.insert(S.Names,k)end
local function scan(poly,y)
 local xs={}
 for i=1,#poly do
  local a,b=poly[i],poly[i%#poly+1]
  if(a[2]<=y and b[2]>y)or(b[2]<=y and a[2]>y)then xs[#xs+1]=a[1]+(y-a[2])/(b[2]-a[2])*(b[1]-a[1])end
 end
 table.sort(xs);local spans={}
 for i=1,#xs-1,2 do spans[#spans+1]={xs[i],xs[i+1]}end
 return spans
end
-- Returns {Step=band height, Faceted=bool, H=half height, Bands={{Y,T,Spans={{X,W,D,Cap}}}}}
local cache={}
function S.Body(name)
 name=name or'Oval';if cache[name]then return cache[name]end
 local out={Bands={}}
 local prof=Profiles[name]
 if prof then
  local n=name=='Oval'and 28 or N
  out.H=prof.H;out.Faceted=prof.Faceted;out.Step=prof.H*2/n;out.Classic=name=='Oval'
  for i=1,n do
   local t=-1+(i-.5)*2/n;local w,d,x,cap=prof.f(t)
   if w>.01 then table.insert(out.Bands,{Y=t*prof.H,T=t,Spans={{X=x,W=w,D=d,Cap=cap}}})end
  end
 else
  local o=assert(Outlines[name],'Unknown seed shape '..tostring(name))
  out.H=o.H;out.Step=o.H*2/N
  for i=1,N do
   local t=-1+(i-.5)*2/N;local spans={}
   for _,s in ipairs(scan(o.P,t))do
    local w=(s[2]-s[1])*o.HW
    if w>.02 then spans[#spans+1]={X=(s[1]+s[2])/2*o.HW,W=w,D=min(o.D,w*.85+.04)}end
   end
   if #spans>0 then table.insert(out.Bands,{Y=t*o.H,T=t,Spans=spans})end
  end
 end
 cache[name]=out;return out
end
-- The band nearest height y.
local function nearest(body,y)
 local best
 for _,b in ipairs(body.Bands)do if not best or abs(b.Y-y)<abs(best.Y-y)then best=b end end
 return best
end
-- Half width and half depth of a span as it is really drawn: the classic body's part cylinders are round
-- (diameter = the smaller of width and depth); faceted bodies are diamonds (rotated squares).
local function halves(body,sp)
 if body.Classic then local r=min(sp.W,sp.D)/2;return r,r end
 return sp.W/2,sp.D/2
end
-- Front surface depth at (x, y) on a body, or nil when (x, y) is outside it (marks are skipped there).
function S.FrontZ(body,x,y)
 local best=nearest(body,y)
 if not best or abs(best.Y-y)>body.Step then return nil end
 for _,sp in ipairs(best.Spans)do
  local hw,hd=halves(body,sp);local u=(x-sp.X)/hw
  if abs(u)<.92 then
   if body.Faceted then return -hd*(1-abs(u))end
   return -hd*sqrt(max(.1,1-u*u))
  end
 end
 return nil
end
-- R134: body extent and surface points, so additions sit ON the body (owner: "fix floating or dislocated parts").
function S.Extent(body)
 local top,bottom=-math.huge,math.huge
 for _,b in ipairs(body.Bands)do top=max(top,b.Y+body.Step/2);bottom=min(bottom,b.Y-body.Step/2)end
 return top,bottom
end
-- Centre x, half width, half depth of the main span at height y (0s outside the body).
function S.Span(body,y)
 local best=nearest(body,y);local sp=best and best.Spans[1]
 if not sp then return 0,0,0 end
 local hw,hd=halves(body,sp);return sp.X,hw,hd
end
-- A point on the surface at height y, angle a around the body (0 = front/-Z, pi/2 = +X), pushed out by `out`.
function S.Surface(body,a,y,out)
 local cx,hw,hd=S.Span(body,y);out=out or 0
 local sa,ca=math.sin(a),math.cos(a)
 if body.Faceted then local k=1/(abs(sa)+abs(ca));return Vector3.new(cx+sa*(hw*k+out),y,-ca*(hd*k+out))end
 return Vector3.new(cx+sa*(hw+out),y,-ca*(hd+out))
end
return S
