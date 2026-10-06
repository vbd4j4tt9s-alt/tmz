--!nocheck
-- R152 performance patch: the two helpers on their own (run_perf152.sh, static part; run in the hotbar env of this checkout: world.luau + the bundle).
--  PropCache152 - a value is written once, a changed value always, by value for Vector3 / Color3 / UDim2, Scale builds its UDim2 only on change,
--                 Forget makes the next write go through, a cache sees only its own writes.
--  ViewCull152  - a ball behind / beside the camera is hidden once the camera has held still for its window; one in view, one that touches the
--                 view's edge, one the camera is close to, a fast turn or a jump, no camera / no ViewportPointToRay: never hidden.
local W=require('./world');local R=W.R
local C=W.module('PropCache152');local Cull=W.module('ViewCull152')
local V,CF=R.Vector3.new,R.CFrame
local n,bad=0,0
local function check(ok,what)n+=1;if not ok then bad+=1;print('FAIL '..what)end end
-- PropCache152 ------------------------------------------------------------------------------------------------------------------------------
local log={}
local function proxy()return setmetatable({},{__newindex=function(_,k,v)log[#log+1]=k end})end
local o=proxy();local c=C.new()
c.Set(o,'Transparency',1);c.Set(o,'Transparency',1);check(#log==1,'a value is written once')
c.Set(o,'Transparency',.5);check(#log==2,'a changed value is written')
c.Set(o,'Transparency',1);check(#log==3,'a value written before, changed back, is written')
c.Set(o,'Size',V(1,2,3));c.Set(o,'Size',V(1,2,3));check(#log==4,'Vector3 compares by value')
c.Set(o,'Color',R.Color3.new(1,0,0));c.Set(o,'Color',R.Color3.new(1,0,0));check(#log==5,'Color3 compares by value')
c.Set(o,'Color',R.Color3.new(1,0,.5));check(#log==6,'a changed Color3 is written')
c.Set(o,'Position',R.UDim2.new(.5,2,.5,0));c.Set(o,'Position',R.UDim2.new(.5,2,.5,0));check(#log==7,'UDim2 compares by value')
c.Set(o,'Position',R.UDim2.new(.5,3,.5,0));check(#log==8,'a changed UDim2 offset is written')
c.Scale(o,'Size',.2,.3);c.Scale(o,'Size',.2,.3);check(#log==9,'Scale writes once')
c.Scale(o,'Size',.2,.4);check(#log==10,'Scale writes a change')
c.Set(o,'Size',V(1,2,3));c.Scale(o,'Size',.2,.4);check(#log==12,'Scale after a Set writes again')
c.Forget(o);c.Set(o,'Transparency',1);check(#log==13,'after Forget the next write goes through')
c.Set(o,'Enabled',false);c.Set(o,'Enabled',false);c.Set(o,'Enabled',true);check(#log==15,'booleans: false once, then true')
local o2=proxy();c.Set(o2,'Transparency',1);check(#log==16,'one cache, two instances: each its own values')
local c2=C.new();c2.Set(o,'Transparency',1);check(#log==17,'two caches: each sees only its own writes')
local part=R.new('Part');c.Set(part,'Transparency',.25);check(part.Transparency==.25,'the real property is set')
c.Set(part,'Transparency',.25);part.Transparency=.75;c.Set(part,'Transparency',.25)
check(part.Transparency==.75,'(documented: a write by someone else is not seen - only for pieces one owner animates)')
-- ViewCull152 -------------------------------------------------------------------------------------------------------------------------------
local cam=R.new('Camera');cam.FieldOfView=70;cam.ViewportSize=R.Vector2.new(800,600);cam.CFrame=CF.new(0,0,0)
cam.ViewportPointToRay=function(self,x,y)
 local vs=self.ViewportSize;local tv=math.tan(math.rad(self.FieldOfView)/2);local th=tv*vs.X/vs.Y
 local dx,dy=(2*x/vs.X-1)*th,(1-2*y/vs.Y)*tv
 local cf=self.CFrame;return {Origin=cf.Position,Direction=(cf.RightVector*dx+cf.UpVector*dy+cf.LookVector).Unit}
end
local function hold(s)R.clock+=s end
check(Cull.Hidden(nil,V(0,0,50),2,0)==false,'no camera: in view')
check(Cull.Hidden(cam,V(0,0,50),2,0)==false,'a camera seen for the first time keeps everything live')
hold(.2)
check(Cull.Hidden(cam,V(0,0,50),2,0)==true,'a ball behind a still camera is hidden')
check(Cull.Hidden(cam,V(0,0,-50),2,0)==false,'a ball in front is in view')
check(Cull.Hidden(cam,V(200,0,-50),2,0)==true,'a ball far beside the view is hidden')
check(Cull.Hidden(cam,V(0,300,-50),2,0)==true,'a ball far above the view is hidden')
local edge=50*math.tan(math.rad(35))*800/600
check(Cull.Hidden(cam,V(edge+2.5,0,-50),3,0)==false,'a ball that touches the view edge is in view')
check(Cull.Hidden(cam,V(0,0,10),2,12)==false,'a ball the camera is close to is kept live')
check(Cull.Hidden(cam,V(0,0,3),4,0)==false,'a ball round the camera is in view')
-- a fast turn: everything live until the camera has held still for the window
cam.CFrame=CF.new(0,0,0)*CF.Angles(0,math.rad(30),0)
check(Cull.Hidden(cam,V(0,0,50),2,0)==false,'right after a fast turn nothing is hidden')
hold(.05);check(Cull.Hidden(cam,V(0,0,50),2,0)==false,'within the window after the turn nothing is hidden')
hold(.2);check(Cull.Hidden(cam,V(0,0,50),2,0)==true,'held still again: hidden')
-- a slow turn grows the ball by twice the turn: a ball just outside the view stays live
-- (2 degrees: the margin is 2 x 2 + 3 = 7 degrees, 9.4 studs at this distance; held still 3 degrees, 4 studs; the ball is 8.8 studs outside)
cam.CFrame=CF.new(0,0,0)*CF.Angles(0,math.rad(32),0)
local look=cam.CFrame.LookVector;local right=cam.CFrame.RightVector
local just=look*50+right*(50*math.tan(math.rad(35))*800/600+12)
check(Cull.Hidden(cam,just,2,0)==false,'turning slowly: a ball just outside the edge stays live')
hold(.2);check(Cull.Hidden(cam,just,2,0)==true,'held still: the same ball is hidden')
-- a jump (teleport) keeps everything live for the window
cam.CFrame=cam.CFrame+V(0,0,-400)
check(Cull.Hidden(cam,cam.CFrame.Position-look*60,2,0)==false,'right after a jump nothing is hidden')
hold(.2);check(Cull.Hidden(cam,cam.CFrame.Position-look*60,2,0)==true,'after the jump, held still: hidden')
local plain=R.new('Camera');plain.FieldOfView=70;plain.ViewportSize=R.Vector2.new(800,600);plain.CFrame=CF.new(0,0,0)
check(pcall(Cull.Hidden,plain,V(0,0,50),2,0),'a camera without ViewportPointToRay does not error')
hold(.2);check(Cull.Hidden(plain,V(0,0,50),2,0)==false,'a camera without ViewportPointToRay: in view')
local zero=R.new('Camera');zero.FieldOfView=70;zero.ViewportSize=R.Vector2.new(0,0);zero.CFrame=CF.new(0,0,0);zero.ViewportPointToRay=cam.ViewportPointToRay
hold(.2);Cull.Hidden(zero,V(0,0,50),2,0);hold(.2);check(Cull.Hidden(zero,V(0,0,50),2,0)==false,'a zero-size viewport: in view')
print(string.format('perf152 units: %d checks, %d failed',n,bad))
if bad>0 then error('perf152 units failed',0)end
