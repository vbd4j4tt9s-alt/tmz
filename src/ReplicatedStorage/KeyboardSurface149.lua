-- R149: where the keyboard's key tops are, for client effects that were authored at floor level (the Storm lightning warning / impact
-- rings, the shovel dirt bursts). KeyboardTrack.client draws every key with its resting top K.Config.RestRise (1.2 since R151's deeper press; 0.55 before) ABOVE the floor top and
-- hides the real floor for this client, so anything left at floor height is under the keys and cannot be seen.
--   KeyboardSurface149.Lift(x, z, floorY) = studs to raise a floor-level effect at (x, z) so it sits on the resting key tops: the key top
--   minus floorY where the keyboard is drawn there, else 0 (no keyboard, off the track, The Darkened's arena, after teardown). The effect keeps
--   its own offset above the floor (a ring authored 0.12 above the floor ends 0.12 above the key tops).
-- Read live, the way SnowBiome149 reads its surface: the keyboard exists while workspace.KeyboardTrackVisuals does, the height comes from
-- KeyboardTrack.KeyTop(0) (so a tuned RestRise is followed), and the covered rectangle is the one the keyboard builds from the map's biome
-- attributes (K.Geometry: the 180-wide floor around TrackCenterX, from the first biome's start to the end of the last row).
local RS=game:GetService('ReplicatedStorage')
local S={}
local K=nil
local function keyboard()
 if K==nil then
  local m=RS:FindFirstChild('KeyboardTrack')
  if not m then return nil end
  local ok,v=pcall(require,m);K=ok and v or false
 end
 return K or nil
end
-- x0, x1, z0, z1 of the keys while the keyboard is drawn (else nil).
function S.Rect()
 local k=keyboard()
 if not k or not workspace:FindFirstChild('KeyboardTrackVisuals')then return nil end
 local map=workspace:FindFirstChild('ChestChaseMap');if not map then return nil end
 local motion=RS:FindFirstChild('RunnerMotion');local cx=motion and motion:GetAttribute('TrackCenterX')
 local geo=k.Geometry(map:GetAttributes(),type(cx)=='number'and cx or nil)
 local last=geo.Segs[#geo.Segs]
 if geo.Rows<1 or not last then return nil end
 return geo.CenterX-geo.HalfWidth,geo.CenterX+geo.HalfWidth,geo.Z0,last.EndZ
end
-- The resting key top at (x, z), or nil where there is no keyboard.
function S.TopY(x,z)
 local x0,x1,z0,z1=S.Rect()
 if x0 and x>=x0 and x<=x1 and z>=z0 and z<z1 then return K.KeyTop(0)end
 return nil
end
function S.Lift(x,z,floorY)
 local top=S.TopY(x,z)
 if not top then return 0 end
 return math.max(0,top-(floorY or K.Config.FloorTop))
end
return S
