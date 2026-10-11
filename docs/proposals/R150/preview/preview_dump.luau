--!nocheck
-- R150 preview dump helpers (not a test): serialise what a camera would see around a pedestal on the Roblox mock - the parts (blocks, balls,
-- cylinders; the pack's stand-in Body as a pouch), particle emitters (steady ones as a rate / lifetime / speed, one-shot Emit() as a count),
-- lights, and the pedestal's BillboardGui sign (every Frame / TextLabel with its layout, colours, UICorner / UIStroke / UIGradient) - into one
-- "SCENE <name> <json>" line for render_pedestal.mjs.
local D={}
local function n(v)return string.format('%.4f',v)end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function c3(c)if not c then return'[255,255,255]'end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if e==nil then return nil end;if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local function v3(v)return string.format('[%s,%s,%s]',n(v.X),n(v.Y),n(v.Z))end
local function seqColor(seq,fallback)
 if seq==nil then return fallback end
 if seq.R then return seq end
 if seq.A and seq.A.R then return seq.A end
 return fallback
end
local function avg(r,fallback)if type(r)=='table'and r.Min then return(r.Min+r.Max)/2 end;return fallback end
local function worldPos(o) -- a part's position, or its parent part's for an attachment
 local x=o
 while x do if x._props.CFrame and x:IsA('BasePart')then return x._props.CFrame.Position,x._props.Size end;x=x._parent end
 return nil
end
-- parts, emitters, lights and guis under `root` (an Instance), appended to the lists
local function walk(root,out)
 for _,c in ipairs(root:GetDescendants())do
  if c:IsA('BasePart')and out.keep and not out.keep(c)then -- (a part outside the area of interest: not drawn)
  elseif c:IsA('BasePart')then
   local isMesh=c._class=='MeshPart';local t=c._props.Transparency or 0
   if t<.995 and c._props.CFrame and(not isMesh or c.Name=='Body')and c._class~='WedgePart'then
    local cf=c._props.CFrame;local r=cf.R;local s=c._props.Size
    local shape=isMesh and'Pouch'or enumName(c._props.Shape)or'Block'
    local color=c._props.Color;local par=c._parent
    if isMesh and par and par._attrs.PaperColor and not(c._props.Color and c._props.Color.R<.1)then color=par._attrs.PaperColor end -- the pack's own paper colour (the art is not available offline)
    out.parts[#out.parts+1]=string.format('{"n":%s,"sh":%s,"s":%s,"p":%s,"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"c":%s,"m":%s,"t":%s}',q(c.Name),q(shape),v3(s),v3(cf.Position),
     n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),c3(color),q(enumName(c._props.Material)or'Plastic'),n(t))
   end
  elseif c._class=='ParticleEmitter'then
   local pos,size=worldPos(c)
   if pos and((c._props.Enabled and(c._props.Rate or 0)>0)or(c._emitted or 0)>0)then
    local kind=(c._emitted or 0)>0 and'burst'or'steady'
    local life=avg(c._props.Lifetime,1);local speed=avg(c._props.Speed,1)
    out.emitters[#out.emitters+1]=string.format('{"kind":%s,"p":%s,"size":%s,"color":%s,"rate":%s,"life":%s,"speed":%s,"count":%d}',q(kind),v3(pos),v3(size),
     c3(seqColor(c._props.Color,{R=1,G=1,B=1})),n(c._props.Rate or 0),n(life),n(speed),c._emitted or 0)
   end
  elseif c._class=='PointLight'and c._props.Enabled then
   local pos=worldPos(c)
   if pos then out.lights[#out.lights+1]=string.format('{"p":%s,"color":%s,"range":%s,"brightness":%s}',v3(pos),c3(c._props.Color),n(c._props.Range or 8),n(c._props.Brightness or 1))end
  elseif c._class=='BillboardGui'and c._props.Enabled then
   local ad=c._props.Adornee;local off=c._props.StudsOffsetWorldSpace or{X=0,Y=0,Z=0}
   if ad and ad._props.CFrame then
    local p=ad._props.CFrame.Position
    local items={}
    for _,g in ipairs(c:GetDescendants())do
     local shown=g:IsA('GuiObject')
     local up=g._parent;while shown and up and up~=c do if up._props.Visible==false then shown=false end;up=up._parent end -- (inside a hidden frame: not drawn)
     if shown and g._props.Visible~=false then
      local item={}
      local pos,size=g._props.Position,g._props.Size
      local corner,stroke,grad
      for _,k in ipairs(g._children)do
       if k._class=='UICorner'then corner=k._props.CornerRadius.Scale
       elseif k._class=='UIStroke'then stroke=string.format('{"c":%s,"w":%s,"t":%s}',c3(k._props.Color),n(k._props.Thickness or 1),n(k._props.Transparency or 0))
       elseif k._class=='UIGradient'and k._props.Color and k._props.Color.A and k._props.Color.B then grad=string.format('{"a":%s,"b":%s}',c3(k._props.Color.A),c3(k._props.Color.B))end
      end
      local par=g._parent
      local pstroke
      items[#items+1]=string.format('{"name":%s,"cls":%s,"x":%s,"y":%s,"w":%s,"h":%s,"ax":%s,"ay":%s,"bg":%s,"bgT":%s,"text":%s,"tc":%s,"tsc":%s,"corner":%s,"stroke":%s,"grad":%s,"z":%d}',
       q(g.Name),q(g._class),n(pos and pos.X.Scale or 0),n(pos and pos.Y.Scale or 0),n(size and size.X.Scale or 1),n(size and size.Y.Scale or 1),
       n(g._props.AnchorPoint and g._props.AnchorPoint.X or 0),n(g._props.AnchorPoint and g._props.AnchorPoint.Y or 0),
       c3(g._props.BackgroundColor3),n(g._props.BackgroundTransparency or 0),g._class=='TextLabel'and q(g._props.Text or'')or'null',c3(g._props.TextColor3),
       c3(g._props.TextStrokeColor3),corner and n(corner)or'null',stroke or'null',grad or'null',g._props.ZIndex or 1)
     end
    end
    out.guis[#out.guis+1]=string.format('{"p":%s,"w":%s,"h":%s,"items":[%s]}',v3({X=p.X+off.X,Y=p.Y+off.Y,Z=p.Z+off.Z}),n(c._props.Size.X.Scale),n(c._props.Size.Y.Scale),table.concat(items,','))
   end
  end
 end
end
-- roots: a list of Instances (the pedestal model, the flight folder, ...). transient: names of parts directly in the workspace to include too
-- (the burst ring, the flash, the pops). Returns the scene JSON text.
function D.scene(W,roots,view,transient,keep)
 local out={parts={},emitters={},lights={},guis={},keep=keep}
 for _,r in ipairs(roots)do walk(r,out)end
 if transient then
  local holder=W.R.new('Folder')
  for _,c in ipairs(W.workspace:GetChildren())do if transient[c.Name]then holder._children[#holder._children+1]=c end end
  walk(holder,out)
  for _,c in ipairs(holder._children)do if c:IsA('BasePart')and(c._props.Transparency or 0)<.995 and c._props.CFrame then
   local cf=c._props.CFrame;local r=cf.R;local s=c._props.Size
   out.parts[#out.parts+1]=string.format('{"n":%s,"sh":%s,"s":%s,"p":%s,"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"c":%s,"m":%s,"t":%s}',q(c.Name),q(enumName(c._props.Shape)or'Block'),v3(s),v3(cf.Position),
    n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),c3(c._props.Color),q(enumName(c._props.Material)or'Plastic'),n(c._props.Transparency or 0))
  end end
 end
 return string.format('{"parts":[%s],"emitters":[%s],"lights":[%s],"guis":[%s],"view":%s}',table.concat(out.parts,','),table.concat(out.emitters,','),table.concat(out.lights,','),table.concat(out.guis,','),view)
end
function D.view(cam,at,fov)return string.format('{"cam":%s,"at":%s,"fov":%s}',v3(cam),v3(at),n(fov or 40))end
D.q=q;D.n=n;D.v3=v3
return D
