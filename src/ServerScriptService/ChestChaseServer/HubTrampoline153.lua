-- R153 hub trampolines, server half (owner: "remove these benches at the corner just add a trampoline that boosts players up by a bit"). Built
-- once at start-up by HubDecor151.Apply into Workspace.ChestChaseMap.HubTrampolines153: one round, chunky, low trampoline in the middle of each
-- garden nook (HubTrampolineRules153.Spots), in the hub's palette (HubDecorKit151.P): six stubby feet, a red 16-sided frame, a ring of 16 gold
-- springs round a teal mat with a cream badge. The client half (HubTrampoline153.client) does the bouncing; this one only builds the geometry.
-- Collision matches what you see: ONE invisible cylinder (the only part that collides) covers the frame's whole footprint, its top 0.9 over the
-- floor (a kerb the game's runner steps onto without a jump), the mat and the frame ring at that height; the squash animation moves only the
-- visual mat and badge. Nothing but the collider can be queried (clicks and rays pass through the dressing). Planes: no two same-facing faces of
-- different parts share a height (checked by the hub z-fight run).
local RS=game:GetService('ReplicatedStorage')
local K=require(RS:WaitForChild('HubDecorKit151'));local T=require(RS:WaitForChild('HubTrampolineRules153'))
local M={Version=153}
local V,CF=Vector3.new,CFrame.new
local P,Mat=K.P,Enum.Material
local F=T.Floor
-- Heights (absolute): the paving's top is 4.26; the walking top is Floor + Dims.Top = 4.9.
M.Layers={FootBottom=F+.2,FootTop=F+.5,GapBottom=F+.3,GapTop=F+.62,FrameBottom=F+.5,FrameTop=F+.94,SpringTop=F+.88,MatBottom=F+.62,MatTop=F+.86,BadgeBottom=F+.8,BadgeTop=F+1.06}
M.Frame={Sides=16,Ring=5.55,Width=1.0}      -- the frame's boxes stand on a 16-gon of this radius (5.05 - 6.05 from the centre)
M.Springs={Count=16,Ring=4.6,Diameter=.45}
M.Feet={Count=6,Ring=5.65,Diameter=1.2}   -- (the feet stand just outside the dark gap's edge, 5.05: no overlapping tops)
M.BadgeRadius=1.6
local function build(parent,spot)
 local L,D=M.Layers,T.Dims
 local x,z=spot.X,spot.Z
 local model=K.Model(parent,'Trampoline '..spot.Name,true)
 model:SetAttribute('Spot',spot.Name);model:SetAttribute('Top',T.Top());model:SetAttribute('Radius',D.Radius);model:SetAttribute('MatRadius',D.MatRadius)
 model:SetAttribute('CenterX',x);model:SetAttribute('CenterZ',z)
 -- the collider: the footprint of the frame, from just under the floor to the walking top
 local c=K.VCyl(model,'Trampoline collider',D.Radius*2,F-.1,T.Top(),x,z,P.Metal,Mat.SmoothPlastic,{collide=true,shadow=false,t=1})
 c.CanQuery=true -- (it is a floor the Humanoid stands on)
 for k=0,M.Feet.Count-1 do
  local a=(k+.5)/M.Feet.Count*math.pi*2
  K.VCyl(model,'Trampoline foot',M.Feet.Diameter,L.FootBottom,L.FootTop,x+math.cos(a)*M.Feet.Ring,z+math.sin(a)*M.Feet.Ring,P.StoneDark,Mat.Slate,{shadow=false})
 end
 -- the frame: 16 red boxes round a 16-gon (each a little longer than its side, so the corners close)
 local n=M.Frame.Sides;local side=2*M.Frame.Ring*math.tan(math.pi/n)+.16
 for k=0,n-1 do
  local a=k/n*math.pi*2
  K.Part(model,'Trampoline frame',V(side,L.FrameTop-L.FrameBottom,M.Frame.Width),
   CF(x+math.cos(a)*M.Frame.Ring,(L.FrameTop+L.FrameBottom)/2,z+math.sin(a)*M.Frame.Ring)*CFrame.Angles(0,-(a+math.pi/2),0),P.RoofRed,Mat.SmoothPlastic,{shadow=false})
 end
 -- the dark floor of the spring ring, and the springs (gold) standing on it between the mat and the frame
 K.VCyl(model,'Trampoline gap',(M.Frame.Ring-M.Frame.Width/2)*2,L.GapBottom,L.GapTop,x,z,P.Ink,Mat.SmoothPlastic,{shadow=false})
 for k=0,M.Springs.Count-1 do
  local a=(k+.5)/M.Springs.Count*math.pi*2
  K.VCyl(model,'Trampoline spring',M.Springs.Diameter,L.GapTop,L.SpringTop,x+math.cos(a)*M.Springs.Ring,z+math.sin(a)*M.Springs.Ring,P.Gold,Mat.SmoothPlastic,{shadow=false})
 end
 -- the mat and its badge (the only parts the client moves)
 local mat=K.VCyl(model,'Trampoline mat',D.MatRadius*2,L.MatBottom,L.MatTop,x,z,P.RoofTeal,Mat.SmoothPlastic,{shadow=false})
 local badge=K.VCyl(model,'Trampoline badge',M.BadgeRadius*2,L.BadgeBottom,L.BadgeTop,x,z,P.Cream,Mat.SmoothPlastic,{shadow=false})
 mat:SetAttribute('Rest',true);badge:SetAttribute('Rest',true)
 return model
end
function M.Build(map)
 assert(map,'HubTrampoline153: no map')
 local old=map:FindFirstChild(T.FolderName);if old then old:Destroy()end
 local made0=K.Made
 local root=Instance.new('Folder');root.Name=T.FolderName;root:SetAttribute('Version',M.Version)
 for _,spot in ipairs(T.Spots)do build(root,spot)end
 root:SetAttribute('Parts',K.Made-made0)
 root.Parent=map
 return root
end
return M
