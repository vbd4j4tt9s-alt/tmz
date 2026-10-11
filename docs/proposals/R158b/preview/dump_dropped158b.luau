--!nocheck
-- R158b preview (not a test): what the picture of the dropped pack needs from the game's own code, printed as lines for make_dropped158b.py:
--   PACK <stage> {...}   the pack the REAL SeedPackVisuals.Bag builds for a dropped pack (the owner's pack templates: pack_world.luau; H.ground = ChaseService /
--                        ConcurrentKeeperService's BuildSeedPacket(nil, body.CFrame, model, nil, nil, ...)): the root frame, the visual scale, the art key, the rank and its
--                        rarity colour, and every part (the three pouch MeshParts are drawn from the design's native render data by the Python side)
--   KEYS <stage> {...}   the track floor of that biome: KeyboardTrack's own shades (K.CellRGB, a hash of the cell) for 80 rows x 22 columns, the grout colour and the key geometry
--   LOOK {...}           DroppedPackLook158b's numbers (colours, transparencies, sizes) and the budget, so the picture is drawn with the same ones
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
W.env.bit32=bit32
local K=W.module('KeyboardTrack');local Look=W.module('DroppedPackLook158b')
local function c255(c)return{math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)}end
local stages={1,2,3,4,5,6,7}
for _,stage in ipairs(stages)do
 local bag=H.ground(stage,'Pack03',1,'None') -- a Rare design (the third of six), size 1, no coat
 local root=bag.PrimaryPart
 local function frame(cf)local r=cf.R;return{p={cf.Position.X,cf.Position.Y,cf.Position.Z},r={{r[1][1],r[1][2],r[1][3]},{r[2][1],r[2][2],r[2][3]},{r[3][1],r[3][2],r[3][3]}}}end
 local parts={}
 for _,d in ipairs(bag:GetDescendants())do if d:IsA('BasePart')and d~=root then
  local rel=root.CFrame:Inverse()*d.CFrame;local f=frame(rel)
  parts[#parts+1]={name=d.Name,class=d.ClassName,shape=d:IsA('MeshPart')and'Mesh'or'Block',size={d.Size.X,d.Size.Y,d.Size.Z},p=f.p,r=f.r,color=c255(d.Color),material=H.enumName(d.Material),t=d.Transparency}
 end end
 local rank=bag:GetAttribute('PackRank')or 1;local tier=H.Rules.PackTiers[rank]
 print('PACK '..stage..' '..H.json({key=bag:GetAttribute('PackArtKey'),scale=bag:GetAttribute('VisualScale'),rank=rank,tier=tier.Name,tierColor=c255(tier.Color),parts=parts}))
 local rows={};local z=K.Zone(stage)
 for row=0,79 do local line={};for col=1,22 do local r,g,b=K.CellRGB(stage,row,col,1);line[#line+1]={r,g,b}end;rows[#rows+1]=line end
 print('KEYS '..stage..' '..H.json({name=z.Name,bed=z.Bed,rows=rows,pitch=K.Config.Pitch,gap=K.Config.Gap,floorTop=K.Config.FloorTop,rise=K.Config.RestRise,bedDepth=K.Config.BedDepth,keyY=K.Config.KeyY,width=K.Config.FieldWidth}))
end
print('LOOK '..H.json({gold=c255(Look.Gold),white=c255(Look.White),fill=c255(Look.FillColor),ink=c255(Look.Ink),fillTransparency=Look.FillTransparency,outlineTransparency=Look.OutlineTransparency,
 pulse=Look.PulseSeconds,maxHighlights=Look.MaxHighlights,maxBeams=Look.MaxBeams,maxMarkers=Look.MaxMarkers,beamHeight=Look.BeamHeight,beamFoot=Look.BeamFoot,beamTop=Look.BeamTop,beamEmission=Look.BeamEmission,beamFade=Look.BeamFade,markerAbove=Look.MarkerAbove,
 staticOutline=c255(Look.StaticOutline)}))
