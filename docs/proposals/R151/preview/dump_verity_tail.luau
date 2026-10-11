-- R151 preview dump (not a test): appended by run_verity_preview.sh to the first 158 lines of docs/proposals/R149/tests/test_verity_lipsync.luau (the
-- mock world with the engine-like Sound, the layout emulation and the real VerityClient of whichever src tree is bundled). Opens her window with Talk
-- (the greeting plays, the portrait is built) and prints three portrait frames as "FRAME <name> {json}" for render_verity_portrait.mjs: at rest
-- (the instant the window opens), mid (about half the swell) and peak (the biggest she gets while saying "Hello, my name is Verity"), each with the ball's
-- size and place, the mouth oval if the build has one (R150: yes, R151: no), the portrait camera, and the layout rectangles of the portrait frame,
-- its viewport and the gold dais under her.
local function n(v)return string.format('%.4f',v)end
settleDown()
server('Open',{VoidPacks=0,Delivered=0})
local view=panel.Portrait.Model
local function snapshot(name,t)
 local pm=view:FindFirstChild('VerityPortrait');local ball=pm and pm:FindFirstChild('Body')
 if not ball then error('no portrait ball for '..name)end
 local mouth=pm:FindFirstChild('VerityPortraitMouth')
 local ms='null'
 if mouth and mouth.Parent==pm then
  local p=mouth.CFrame.Position
  ms=string.format('{"w":%s,"h":%s,"d":%s,"x":%s,"y":%s,"z":%s}',n(mouth.Size.X),n(mouth.Size.Y),n(mouth.Size.Z),n(p.X),n(p.Y),n(p.Z))
 end
 local cam=view.CurrentCamera;local cp=cam.CFrame.Position
 local function rc(o)local r=rect(o);return string.format('{"x":%s,"y":%s,"w":%s,"h":%s}',n(r.X),n(r.Y),n(r.W),n(r.H))end
 print(string.format('FRAME %s {"t":%s,"ball":{"d":%s,"x":%s,"y":%s,"z":%s},"mouth":%s,"cam":{"x":%s,"y":%s,"z":%s,"fov":%s},"portrait":%s,"view":%s,"dais":%s,"portraitSize":%s}',
  name,n(t),n(ball.Size.X),n(ball.CFrame.Position.X),n(ball.CFrame.Position.Y),n(ball.CFrame.Position.Z),ms,n(cp.X),n(cp.Y),n(cp.Z),n(cam.FieldOfView),
  rc(panel.Portrait),rc(view),rc(panel.Portrait.Dais),n(C.Portrait.Size)))
end
local sound=lastPlay().Sound
snapshot('rest',0)
local best,bestSize,mid,midDiff=0,0,nil,1e9
local frameSamples={}
local D=C.Portrait.Size
for _=1,150 do
 frames(1)
 local pm=view:FindFirstChild('VerityPortrait');local ball=pm and pm:FindFirstChild('Body')
 if ball then frameSamples[#frameSamples+1]={T=sound.TimePosition,Size=ball.Size.X}end
end
for _,sm in ipairs(frameSamples)do if sm.Size>bestSize then bestSize=sm.Size;best=sm.T end end
-- the frame whose swell is closest to half of the biggest (rising), after the first syllable has started
for _,sm in ipairs(frameSamples)do local d=math.abs((sm.Size-D)-(bestSize-D)*.5);if sm.T>.3 and sm.T<best+.01 and d<midDiff then midDiff=d;mid=sm.T end end
-- replay the greeting to reach those two moments
local function replayTo(t)
 settleDown();server('Open',{VoidPacks=0,Delivered=0});local s=lastPlay().Sound
 for _=1,300 do if s.TimePosition>=t-.0005 then break end;frames(1)end
end
replayTo(mid);snapshot('mid',sound.TimePosition)
replayTo(best);snapshot('peak',lastPlay().Sound.TimePosition)
