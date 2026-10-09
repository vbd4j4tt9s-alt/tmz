--!nocheck
-- R155 cinematic camera: the fingerprint options that let the R152 seed-opening fingerprints (perf152_seed.luau, compared by perf152_canon.py) allow
-- EXACTLY what the cinematic camera is meant to change against the R154 release, and nothing else. perf152_fp.luau applies this after
-- perf153_opts.luau / perf154_opts.luau when it lies next to the driver (run_camera155.sh step 2: run_perf152.sh with PERF_BASE=8aa15fd, ONLY=seed).
-- Allowed, on both sides alike:
--  * the Camera's CFrame (and the Position the mock keeps with it), Focus and FieldOfView while a story scene's stage is on screen (the Camera is Scriptable and _RarePullStage exists:
--    from the cut into the stage, under the black, to the cut back to the world): the new shots, cuts, moves, lens and dutch tilt;
--  * the depth of field the cinematic camera puts on the Camera (a DepthOfFieldEffect named RarePullDof, child of the Camera), whenever it is there;
--  * the R155 skip (owner: "... u can only skip at the bottom right of the screen"): the SKIP button (a TextButton named 'Skip button' on the
--    RarePullReveal screen, and what is under it), and the corner hint ('Skip hint') for as long as it is not the collect hint: R154 wrote
--    "CLICK TO SKIP" / "TAP TO SKIP" there from SkipFrom to the hit, R155 leaves it empty and hidden. From the moment it says "click to collect!" /
--    "tap to collect!" it is compared in full again.
-- Everything else is compared exactly as before: the Camera outside the stage (the world's lens-only push, the restore), its type and subject, the
-- grade and the blur, the stage itself (every part, beam, emitter, light, image), the card (but its SKIP button), the collect hint, the sounds and
-- their schedule, Lighting, the onlookers' world effects, and every Common..Mythic reveal (no stage: their camera is compared in full on every frame).
return function(FP,W)
 local prevNormal,prevSkip=FP.Normal,FP.Skip
 local function inStage()
  local cam=W.workspace.CurrentCamera;local ty=cam and cam._props.CameraType
  return ty~=nil and ty.Name=='Scriptable'and W.workspace:FindFirstChild('_RarePullStage')~=nil
 end
 local CAMERA={CFrame=true,Focus=true,FieldOfView=true,Position=true} -- (the mock keeps the Camera's Position with its CFrame)
 -- the SKIP button, and the corner hint while it is not the collect hint (R154: the skip hint; R155: empty)
 local function skipUi(o)
  local p=o._parent;local onReveal=p~=nil and p._class=='ScreenGui'and p._props.Name=='RarePullReveal'
  if o._class=='TextButton'and o._props.Name=='Skip button'and onReveal then return true end
  if o._class=='TextLabel'and o._props.Name=='Skip hint'then
   local t=o._props.Text
   return t==nil or t==''or(type(t)=='string'and t:find('TO SKIP',1,true)~=nil)
  end
  return false
 end
 FP.Normal=function(o,k,v)
  if o._class=='Camera'and CAMERA[k]and inStage()then return'(the story stage\'s camera: R155)'end
  if prevNormal then return prevNormal(o,k,v)end
  return nil
 end
 FP.Skip=function(o)
  if o._class=='DepthOfFieldEffect'and o._props.Name=='RarePullDof'and o._parent~=nil and o._parent._class=='Camera'then return true end
  if skipUi(o)then return true end
  if prevSkip then return prevSkip(o)end
  return false
 end
 local prevStream=FP.StreamSkip
 FP.StreamSkip=function(o) -- (the frame streams the seed-opening driver writes: perf152_fp.luau's FP.stream)
  if o._class=='DepthOfFieldEffect'and o._props.Name=='RarePullDof'and o._parent~=nil and o._parent._class=='Camera'then return true end
  if skipUi(o)then return true end
  if prevStream then return prevStream(o)end
  return false
 end
end
