--!nocheck
-- R156 preview: the floating pack exactly as the REAL client script builds it (SecretPyramidClient156 + SeedPackVisuals.Bag with the owner's pack templates,
-- pack_world.luau), in its pyramid built by the REAL SecretPyramid156.Build at the Desert spot. Prints one line "PACK {...}": the pack's root frame and visual
-- scale, every part of the pack in the world (zfight.py's part format) and the prompt (its position, reach, texts). Reduced Motion is on so the pack is read in
-- its built pose (the mock moves no welded parts).
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Rules=W.module('PyramidRules156');local Pyr=W.module('SecretPyramid156')
local player=W.service('Players').LocalPlayer
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local lm=R.new('Folder');lm.Name='MythicLandmarks';lm.Parent=map
local spot=V3(-62.0675,4,1005)
local model=Pyr.Build(spot);model.Parent=lm
local anchor=model:FindFirstChild(Rules.AnchorName);local zone=Rules.ReadZone(anchor)
local prompt=R.new('ProximityPrompt');prompt.Name='Steal';prompt.MaxActivationDistance=zone.Reach;prompt.ActionText='STEAL';prompt.ObjectText='';prompt.Enabled=true;prompt.Parent=anchor
local char=H.character('R15',CF(spot.X,7,spot.Z-Rules.Geometry().Half-3));player.Character=char
W.workspace.CurrentCamera.CFrame=CF(spot.X,12,spot.Z-60)
W.service('GuiService').ReducedMotionEnabled=true
local sc=R.new('LocalScript');sc.Name='SecretPyramidClient156';W.load('SecretPyramidClient156',sc)
player:SetAttribute(Rules.Attr,'Open');W.frames(20)
local bag=W.workspace.SecretPyramidPack156:FindFirstChild('SecretPyramidPack')
assert(bag,'no pack was built')
local root=bag.PrimaryPart
local function c255(c)return{math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)}end
local parts={}
for _,d in ipairs(bag:GetDescendants())do if d:IsA('BasePart')and d~=root then
 local r=d.CFrame.R
 parts[#parts+1]={path='Workspace/SecretPyramidPack156/SecretPyramidPack/'..d.Name,name=d.Name,class=d.ClassName,shape=d:IsA('MeshPart')and'Mesh'or'Block',size={d.Size.X,d.Size.Y,d.Size.Z},
  p={d.Position.X,d.Position.Y,d.Position.Z},r={{r[1][1],r[1][2],r[1][3]},{r[2][1],r[2][2],r[2][3]},{r[3][1],r[3][2],r[3][3]}},color=c255(d.Color),material=H.enumName(d.Material),t=d.Transparency}
end end
local rr=root.CFrame.R
print('PACK '..H.json({root={p={root.Position.X,root.Position.Y,root.Position.Z},r={{rr[1][1],rr[1][2],rr[1][3]},{rr[2][1],rr[2][2],rr[2][3]},{rr[3][1],rr[3][2],rr[3][3]}}},
 scale=bag:GetAttribute('VisualScale'),key=bag:GetAttribute('PackArtKey'),parts=parts,
 prompt={p={anchor.Position.X,anchor.Position.Y,anchor.Position.Z},reach=prompt.MaxActivationDistance,action=prompt.ActionText,object=prompt.ObjectText,enabled=prompt.Enabled},
 zone={center={zone.Center.X,zone.Center.Y,zone.Center.Z},half=zone.Half,top=zone.Top}}))
