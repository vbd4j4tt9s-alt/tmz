-- R152 performance patch: is a ball (centre, radius) entirely out of the camera's view? The view's four side planes come from
-- Camera:ViewportPointToRay at the viewport's corners (right for any FieldOfViewMode, any aspect); a ball fully behind one of them, or behind
-- the camera, cannot be drawn. The camera may still move before the frame is drawn (a caller's step can run before the camera's), so the ball is
-- grown by twice the camera's biggest move of the last 0.15 s (turn and travel) plus 3 degrees and a stud: a camera that turns or jumps fast
-- keeps everything live. A caller only stops moving pieces that cast no shadow and give no light while they are out of view, and poses them
-- again in the step they come back, so what is on screen never differs. Anything odd (no camera, no ViewportPointToRay, a zero-size viewport)
-- counts as in view.
local M={}
M.Window=.15;M.Slack=math.rad(3);M.SlackStuds=1
local cache={Camera=nil,CFrame=nil,Size=nil,Fov=nil,Planes=nil}
local moves={}                                       -- {At, Turn, Move}: every camera move seen in the last Window seconds
local function noteMove(cam,cf)
 local now=os.clock()
 local prev=cache.Camera==cam and cache.CFrame or nil
 local turn,move=math.huge,math.huge
 if prev then
  local ok,a,b=pcall(function()
   local x=math.acos(math.clamp(prev.LookVector:Dot(cf.LookVector),-1,1));local y=math.acos(math.clamp(prev.UpVector:Dot(cf.UpVector),-1,1))
   return math.max(x,y),(cf.Position-prev.Position).Magnitude
  end)
  if ok then turn,move=a,b end
 end
 moves[#moves+1]={At=now,Turn=turn,Move=move}
end
local function margin()
 local now=os.clock();local turn,move=0,0
 for i=#moves,1,-1 do
  local m=moves[i]
  if now-m.At>M.Window then table.remove(moves,i)else turn=math.max(turn,m.Turn);move=math.max(move,m.Move)end
 end
 return turn,move
end
local function planes(cam)
 local cf,size,fov=cam.CFrame,cam.ViewportSize,cam.FieldOfView
 if cache.Camera==cam and cache.CFrame==cf and cache.Size==size and cache.Fov==fov then return cache.Planes end
 noteMove(cam,cf)
 local list
 local w,h=size.X,size.Y
 if w>1 and h>1 then
  local ok,got=pcall(function()
   local o=cf.Position;local fwd=cf.LookVector
   local c={cam:ViewportPointToRay(0,0,0).Direction,cam:ViewportPointToRay(w,0,0).Direction,cam:ViewportPointToRay(w,h,0).Direction,cam:ViewportPointToRay(0,h,0).Direction}
   local out={O=o,Fwd=fwd}
   for i=1,4 do
    local n=c[i]:Cross(c[i%4+1])
    if n.Magnitude<1e-6 then return nil end
    n=n.Unit;if n:Dot(fwd)<0 then n=-n end -- (pointing into the view)
    out[i]=n
   end
   return out
  end)
  if ok then list=got end
 end
 cache.Camera,cache.CFrame,cache.Size,cache.Fov,cache.Planes=cam,cf,size,fov,list
 return list
end
-- true when the ball is out of view (with the margin above) and the camera is farther than `near` studs from its centre (close up a caller
-- keeps everything live)
function M.Hidden(cam,centre,radius,near)
 if not cam then return false end
 local p=planes(cam);if not p then return false end
 local turn,move=margin()
 turn=2*turn+M.Slack;if turn>=math.pi/4 then return false end
 local rel=centre-p.O;local d=rel.Magnitude
 if d<=radius+(near or 0)then return false end
 local r=radius+2*move+M.SlackStuds+d*math.sin(turn)
 if rel:Dot(p.Fwd)<-r then return true end
 for i=1,4 do if rel:Dot(p[i])<-r then return true end end
 return false
end
return M
