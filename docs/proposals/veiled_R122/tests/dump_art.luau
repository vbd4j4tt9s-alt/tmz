--!nocheck
-- Geometry dump for render.py: the real EclipsePackArt build (via SeedPackVisuals.Bag) plus a VoidPackFx frame.
-- The approved Forest_01 mesh is not available offline; render.py draws an approximate pouch for the body.
local W=require('./world');local F=require('./fixtures');local R=W.R;local CF=R.CFrame.new
F.packAssets(W)
local Visuals=W.module('SeedPackVisuals');local PackFx=W.module('VoidPackFx')
local function emit(tag,p,kind)
 local c=p.CFrame;local r=c.R;local s=p.Size;local col=p.Color
 if p._props.ShapeMesh then end
 print(string.format('%s;%s;%s;%.4f,%.4f,%.4f;%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f;%.4f,%.4f,%.4f;%d,%d,%d;%s;%.3f;%s',
  tag,kind or'part',p.Name,c.X,c.Y,c.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3],s.X,s.Y,s.Z,
  math.floor(col.R*255+.5),math.floor(col.G*255+.5),math.floor(col.B*255+.5),tostring(p.Material and p.Material.Name or'SmoothPlastic'),p.Transparency or 0,
  tostring(p.Shape and p.Shape.Name or'Block')))
end
for _,case in ipairs({{'void',1,'None'},{'gold',1,'Gold'}})do
 local bag=Visuals.Bag(CF(0,0,0),W.workspace,1,nil,7,'EclipseReliquary',1,case[2],case[3])
 for _,p in ipairs(bag:GetDescendants())do if p:IsA('BasePart')and p~=bag.PrimaryPart then emit(case[1],p,p:IsA('MeshPart')and'body'or'part')end end
 if case[1]=='void'then
  local cap=PackFx.Capture(bag);PackFx.Create(cap,3);local list,frames={},{}
  -- Spin pose at t=2.3 and the effect frame at full quality.
  local pl,pf={},{};local root=bag.PrimaryPart.CFrame
  for _,e in ipairs(cap.Parts)do pl[#pl+1]=e.Part;pf[#pf+1]=root*PackFx.LocalFrame(e,2.3,true)end
  for i,p in ipairs(pl)do if p~=bag.PrimaryPart then p.CFrame=pf[i];emit('spin',p,p:IsA('MeshPart')and'body'or'part')end end
  PackFx.Step(cap,2.3,root,3,false,true,list,frames)
  for i,p in ipairs(list)do if p.Name~='VoidFxCore'then p.CFrame=frames[i];emit('fx',p,'fx')end end
 end
 bag:Destroy()
end
