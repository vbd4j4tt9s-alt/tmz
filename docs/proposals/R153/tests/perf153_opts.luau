--!nocheck
-- R153 performance patch: the fingerprint options of run_perf153.sh (copied next to the R152 drivers; perf152_fp.luau applies them when this file is
-- there). Both sides - the patch switched off and on - are fingerprinted the same way; what is compared is what the engine can draw:
--  * BasePart.Color as the 8 bits a channel the engine keeps it in (Color3uint8): VoidPackFx.Pulse no longer writes a pulse step that stays inside
--    the same half level of every channel (lag audit D3; exact under rounding and truncation).
--  * BasePart Anchored / Massless are left out (never drawn): the giveaway pack's fixed pieces are welded to its anchored root, its spinners to an
--    invisible hub per ring (D3); the mock moves welded parts as the engine does (tools/tests/roblox.luau).
--  * a SurfaceGui's / BillboardGui's MaxDistance as whether the camera is within it: the keyboard's far letters stop at 500 studs on tier 2 (D8).
return function(FP,W)
 local function isPart(o)return o._class~=nil and o:IsA('BasePart')end
 local function c8(x)return math.floor(x*255+.5)end
 FP.Normal=function(o,k,v)
  if(k=='Anchored'or k=='Massless')and isPart(o)then return false end
  if k=='Color'and type(v)=='table'and v.__type=='Color3'and isPart(o)then return string.format('c8(%d,%d,%d)',c8(v.R),c8(v.G),c8(v.B))end
  if k=='MaxDistance'and(o._class=='SurfaceGui'or o._class=='BillboardGui')and type(v)=='number'then
   local host=o._props.Adornee or o._parent;local cam=W.workspace and W.workspace.CurrentCamera
   local cf=host and host._props and host._props.CFrame
   if v<=0 or not cf or not cam or not cam._props.CFrame then return'inrange'end
   return(cam._props.CFrame.Position-cf.Position).Magnitude<=v and'inrange'or'outofrange'
  end
  return nil
 end
end
