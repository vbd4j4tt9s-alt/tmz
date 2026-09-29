-- R51. Native bill-bundle artwork based on the supplied green stack/yellow band.
-- Optional MoneyImageAssetId attribute accepts an uploaded transparent Roblox image.
local Icon={}
local function part(parent,name,x,y,w,h,color,rotation,round)
 local frame=Instance.new('Frame');frame.Name=name;frame.BackgroundColor3=Color3.fromRGB(unpack(color));frame.BorderSizePixel=0
 frame.Position=UDim2.fromScale(x,y);frame.Size=UDim2.fromScale(w,h);frame.Rotation=rotation or 0;frame.Active=false;frame.Parent=parent
 if round then local c=Instance.new('UICorner');c.CornerRadius=UDim.new(round,0);c.Parent=frame end
 return frame
end
function Icon.new(parent)
 local root=Instance.new('Frame');root.Name='MoneyIcon';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Active=false;root.Parent=parent
 local id=tostring(script:GetAttribute('MoneyImageAssetId')or''):match('(%d+)')
 if id and tonumber(id)>0 then
  local image=Instance.new('ImageLabel');image.Name='UploadedMoney';image.BackgroundTransparency=1;image.Size=UDim2.fromScale(1,1);image.Image='rbxassetid://'..id;image.ScaleType=Enum.ScaleType.Fit;image.Parent=root;return root
 end
 -- A small, fixed set of native shapes: no runtime image permissions or downloads.
 local bundle=part(root,'Bundle',.12,.18,.76,.64,{255,255,255},-23);bundle.BackgroundTransparency=1
 part(bundle,'Shadow',.01,.23,1,.72,{18,77,41},0,.07)
 part(bundle,'LowerNotes',0,.15,1,.72,{24,113,48},0,.06)
 part(bundle,'NoteEdge1',.03,.78,.94,.045,{102,182,63})
 part(bundle,'NoteEdge2',.03,.88,.94,.035,{68,154,57})
 part(bundle,'MiddleNotes',0,.075,1,.69,{46,150,44},0,.05)
 part(bundle,'TopNote',0,0,1,.69,{84,191,42},0,.05)
 part(bundle,'InnerBorder',.065,.06,.87,.56,{161,222,69},0,.06)
 part(bundle,'NoteFace',.095,.10,.81,.47,{70,174,43},0,.05)
 part(bundle,'LeftSeal',.13,.22,.16,.20,{158,219,66},0,.5)
 part(bundle,'RightSeal',.72,.22,.15,.20,{158,219,66},0,.5)
 part(bundle,'BandSide',.40,.64,.25,.31,{220,152,20})
 part(bundle,'GoldBand',.36,-.02,.27,.72,{255,215,58})
 part(bundle,'BandShine',.37,0,.065,.66,{255,240,129})
 part(bundle,'BandFold',.40,.68,.25,.05,{255,191,32})
 return root
end
return Icon
