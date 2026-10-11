--!nocheck
-- R154 performance work (owner: "for the lag fixes we can implement B3 and B1"): the fingerprint options that let the R152 / R153 perf suites allow EXACTLY the two
-- differences those changes are meant to make, and nothing else. perf152_fp.luau applies this after perf153_opts.luau (run_perf153.sh copies both next to the drivers).
-- Both sides - the checkout and the same checkout with B1 / B3 / the R153 patch undone (perf153_off.py) - are fingerprinted the same way:
--  B1 (parts a script builds under 1.5 studs cast no shadow): a part whose largest side is under 1.5 studs is compared WITHOUT its CastShadow (written or not, true
--      or false). A part of 1.5 studs or more is compared with it: bigger parts keep their shadows, exactly.
--  B3 on phones (tier 2; R155: the near letters on tier 1 too; PC is not touched):
--      * (tiers 2 AND 1, R155: owner "yes" to the lighter keyboard on the lowest graphics setting too) the near letters (the SurfaceGuis "Letters" of the strips and "KeyLegend" of the pressed keys): PixelsPerStud left out; their labels' TextSize left out, their
--        Size and Position compared in STUDS (pixels / PixelsPerStud), so the same letters on the same spots at 16 and at 12 pixels a stud compare equal;
--      * (tier 2 only: tier 1's key window did not change, 45 rows ahead were under tier 2's 56 already, so its keys are compared as they are)
--        the keys: only the rows the phone's window WANTS are compared, on both sides: up to B3_AHEAD rows (56; 74 before) in the camera's way and B3_BACK (28, as
--        before) behind, B3_SIDE rows (42; 51 before) each way across the track / looking down (the label of the shot says which: look=along / back / across / down;
--        a run looks along up to frame 60, then back). Every key inside is compared, with its colour, height and size. Rows kept beyond the wanted ones (the hysteresis
--        band, the old long side while a turn lets go of it) depend on what was bound before, which the smaller window changes; the transient stand-in slabs
--        (KeyFiller: their extent follows the window's end) are not compared on tier 2 either.
--      * (tier 2 only) the pooled click voices (Sound KeyClickSound: PlaybackSpeed, TimePosition, Playing, Volume: the pitch and the click-to-click gain of the last click) and their anchor part's place (Part KeyClick) keep the last click's state; which
--        click was last depends on how many keys were already dressed under a teleported runner (a click) or dressed that moment (silent): left out on tier 2.
-- Everything else about the keyboard (strips, far letters, bars, bed, ground, holes) is compared as it is.
return function(FP,W)
 local R=W.R
 local B3_AHEAD,B3_SIDE,B3_BACK=56,42,28 -- (rows: tier 2's new reach ahead and across; Back, the rows behind, is not changed by B3)
 local prev=FP.Normal
 local function isPart(o)return o._class~=nil and o:IsA('BasePart')end
 local function tiny(o)local s=o._props.Size;return s~=nil and math.max(s.X,s.Y,s.Z)<1.5 end
 -- (the quality tier of the world being fingerprinted: the scene's ClientFxBudget stand-in answers with the driver's TIER; a module cannot read the driver's globals)
 local tierMemo
 local function tier()
  if tierMemo==nil then
   local ok,t=pcall(function()return W.module('ClientFxBudget').Get()end)
   tierMemo=ok and t or 3
  end
  return tierMemo
 end
 local NEAR={Letters=true,KeyLegend=true}
 local function nearGui(o)return o._class=='SurfaceGui'and NEAR[o._props.Name]==true end
 local function studs(u,pps)
  if type(u)~='table'or u.__type~='UDim2'or u.X.Scale~=0 or u.Y.Scale~=0 or type(pps)~='number'or pps<=0 then return nil end
  return string.format('studs(%.3f,%.3f)',u.X.Offset/pps,u.Y.Offset/pps)
 end
 FP.Normal=function(o,k,v)
  if k=='CastShadow'and isPart(o)and tiny(o)then return false end -- B1
  local t=tier()
  if t==2 or t==1 then -- B3 near letters (R155: tier 1 too)
   if k=='PixelsPerStud'and nearGui(o)then return false end
   if o._class=='TextLabel'and o._parent and nearGui(o._parent)then
    if k=='TextSize'then return false end
    if k=='Size'or k=='Position'then local s=studs(v,o._parent._props.PixelsPerStud);if s then return s end end
   end
  end
  if t==2 then -- B3, the phone's smaller key window only
   -- the pooled click voices keep the pitch of the click they played last, and their anchor part its place: which click was the last follows how many were played, and a
   -- teleport onto a key that was already dressed clicks where one onto a key dressed that moment is silent - the shorter window dresses fewer keys ahead of the runner
   if o._class=='Sound'and o._props.Name=='KeyClickSound'and(k=='PlaybackSpeed'or k=='TimePosition'or k=='Playing'or k=='Volume')then return false end
   if isPart(o)and o._props.Name=='KeyClick'and(k=='CFrame'or k=='Position')then return false end
  end
  if prev then return prev(o,k,v)end
  return nil
 end
 -- the keys beyond the phone's new reach (tier 2): where the runner stands, which way the camera looks
 local geo
 local function geometry()
  if geo~=nil then return geo or nil end
  local ok,res=pcall(function()
   local K=W.module('KeyboardTrack');local map=W.workspace:FindFirstChild('ChestChaseMap')
   local motion=W.RS:FindFirstChild('RunnerMotion');local cx=motion and motion:GetAttribute('TrackCenterX')
   return K.Geometry(map:GetAttributes(),type(cx)=='number'and cx or nil)
  end)
  geo=ok and res or false
  return geo or nil
 end
 local function focusZ()
  local me=W.service('Players').LocalPlayer;local ch=me and me.Character;local root=ch and ch:FindFirstChild('HumanoidRootPart')
  return root and root._props.CFrame.Position.Z
 end
 -- the way the camera looks in the shot being made: 1 along +Z, -1 back toward -Z, 0 across or down; nil = not a shot of the keyboard runs
 local function facing()
  local label=FP.Label or''
  local look=label:match('look=(%a+)')
  if look=='along'then return 1 elseif look=='back'then return-1 elseif look=='across'or look=='down'then return 0 end
  local f=label:match(' run f(%d+)$')
  if f then return tonumber(f)<=60 and 1 or-1 end
  return nil
 end
 local function underKeyboard(o)local x=o._parent;while x do if x._props.Name=='KeyboardTrackVisuals'then return true end;x=x._parent end;return false end
 FP.Skip=function(o)
  if tier()~=2 or not isPart(o)then return false end
  local name=o._props.Name
  if name~='Key'and name~='KeyFiller'then return false end
  if not underKeyboard(o)then return false end
  if name=='KeyFiller'then return true end
  local way=facing();if way==nil then return false end
  local g=geometry();local fz=focusZ();if not g or not fz then return false end
  local d=g.RowOfZ(o._props.CFrame.Position.Z)-g.RowOfZ(fz)
  -- only the rows the window WANTS are compared: rows kept beyond them (the hysteresis band, the old long side while a turn is released) depend on what was bound before
  local lo,hi=-B3_BACK,B3_AHEAD
  if way==0 then lo,hi=-B3_SIDE,B3_SIDE elseif way<0 then lo,hi=-B3_AHEAD,B3_BACK end
  return d<lo or d>hi
 end
end
