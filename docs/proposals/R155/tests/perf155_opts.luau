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
--  * R157 (the owner-approved R156 reveal fixes: "reduce the size of the seed display so it fits perfectly between the base buttons and the hotbar", "the click to
--    collect should be below the fruit name"): WHERE the card's pieces are - the Position and Size of the rarity word (and its dressing), the seed's viewport, glow and
--    halo, its rays and ring, "1 in N", the seed's name and the hint, under RarePullReveal/RarePull - is fitted to the screen on a Common..Mythic card and moved on a
--    story result ("1 in N" and the name up a little, the hint under the name); the hint, centred under the name now, also anchors at its middle and centres its text
--    (AnchorPoint, TextXAlignment: it was right-aligned in the corner); and the collected seed's flight home (SeedCollect154: the card's seed viewport, moved to the
--    SeedCollectFly screen) starts where and as big as the fitted card showed it, so its Position and Size differ on the first frames of the flight (it lands in the
--    same slot). Their text, colours, transparency, rotation, timing and visibility are still compared, and so
--    is everything else on the card. (The rows the card publishes for the lucky tag are attributes of a Folder, never drawn: not compared.)
--  * R158d (owner: "the mech pack seeds, and also check for other seeds that have similar issues: their effects are already there even before the pack opens. This ruins the
--    surprise of the pack opening"): the hero seed on the stage is HELD until the hit (ItemEffectAnchor.Hold / Release). Its root carries the flag FxHeld (nothing draws it: left out of
--    the shots and the streams), and its own effects (its rarity sparkles ...) are off while it is hidden; R154 had them on, around a seed nobody could see. An effect of the hero
--    seed that is off (Enabled=false) reads as on, so the comparison does not depend on when the seed shows; that the effects ARE on once the seed shows is checked by
--    docs/proposals/R158b/tests/test_pack_leak158d.luau.
-- Everything else is compared exactly as before: the Camera outside the stage (the world's lens-only push, the restore), its type and subject, the
-- grade and the blur, the stage itself (every part, beam, emitter, light, image), the card (but its SKIP button), the collect hint, the sounds and
-- their schedule, Lighting, the onlookers' world effects, and every Common..Mythic reveal (no stage: their camera is compared in full on every frame).
return function(FP,W)
 local prevNormal,prevSkip=FP.Normal,FP.Skip
 -- (R158d: the hold flag is never drawn)
 FP.Drop=FP.Drop or{};FP.Drop['@FxHeld']=true
 local HERO_EFFECT={ParticleEmitter=true,Beam=true,Trail=true,PointLight=true,SpotLight=true,SurfaceLight=true,BillboardGui=true,SurfaceGui=true,Highlight=true,Fire=true,Smoke=true,Sparkles=true}
 local function inHeroSeed(o)
  local m=o._parent;while m and not(m._class=='Model'and m._props.Name=='RarePullSeed')do m=m._parent end
  return m~=nil
 end
 -- (R157: the card's laid-out pieces, by name: a piece of the card is a child of the frame RarePull on the RarePullReveal screen)
 local FITTED={Title=true,Seed=true,['Seed glow']=true,['Seed halo']=true,Odds=true,['Seed name']=true,['Skip hint']=true,Rays=true,Shockwave=true,['Title crown']=true}
 local FITTED_PREFIX={'Title split ','Title star ','Title planet '}
 local function fittedPiece(o)
  local root=o._parent;if not(root and root._class=='Frame'and root._props.Name=='RarePull')then return false end
  local gui=root._parent;if not(gui and gui._class=='ScreenGui'and gui._props.Name=='RarePullReveal')then return false end
  local name=o._props.Name;if type(name)~='string'then return false end
  if FITTED[name]then return true end
  for _,p in ipairs(FITTED_PREFIX)do if name:sub(1,#p)==p then return true end end
  return false
 end
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
  if k=='Enabled'and v==false and HERO_EFFECT[o._class]and inHeroSeed(o)then return'true'end -- (R158d: off while the hero seed is held reads as on, as R154 had it)
  if(k=='Position'or k=='Size')and fittedPiece(o)then return'(the card\'s fitted layout: R157)'end
  if(k=='AnchorPoint'or k=='TextXAlignment')and o._class=='TextLabel'and o._props.Name=='Skip hint'and fittedPiece(o)then return'(the hint centred under the name: R157)'end
  if(k=='Position'or k=='Size')and o._class=='ViewportFrame'and o._props.Name=='Seed'and o._parent and o._parent._class=='ScreenGui'and o._parent._props.Name=='SeedCollectFly'then
   return'(the collected seed flies from the fitted card: R157)'end
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
