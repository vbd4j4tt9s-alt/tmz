--!nocheck
-- R149 preview data: the Snow keeper (the tiger) before / after the silver-and-sapphire gear, in several poses.
-- Runs the REAL BeastPose / KeeperSignatureStrike / KeeperAccents on the Roblox mock (exact CFrame math) and prints one JSON object:
--   hull  : per rig group, the mesh's FloorSamples posed by the real frames (the mesh files cannot be downloaded here, so the
--           textured meshes are drawn as the convex hull of those sample points, as the R123 previews do),
--   boxes : the small untextured mesh details of the rig (eyes, muzzle, nose, teeth) at their exact size and place,
--   items : every accent part (3 ice spines) and gear part (38) with its real CFrame, size, shape, material, colour and detail flag,
--   tail  : the tail's frame (the tail mesh has Bounds only, so the viewer draws an approximate tube in that frame).
local W=require('./world');local R=W.R
local Cfg=W.module('KeeperRigConfig');local Pose=W.module('BeastPose');local Acc=W.module('KeeperAccents')
local Sig=W.module('KeeperSignatureStrike');local Combat=W.module('KeeperCombat')
local V,CF=R.Vector3.new,R.CFrame.new
local rig=Cfg[3]
local function comps(cf)local x,y,z,a,b,c,d,e,f,g,h,i=cf:GetComponents();return string.format('[%.4f,%.4f,%.4f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f]',x,y,z,a,b,c,d,e,f,g,h,i)end
local function col(c)return string.format('[%.4f,%.4f,%.4f]',c.R,c.G,c.B)end
-- A keeper model with the rig's Body parts (the gear reads its scale from them).
local function model(scale)
 local m=R.new('Model');local body=R.new('Model');body.Name='BeastBody';body.Parent=m
 for _,p in ipairs(rig.Parts)do if p.Group=='Body'then
  local part=R.new('Part');part.Size=V(p.Size[1]*scale,p.Size[2]*scale,p.Size[3]*scale);part:SetAttribute('BeastGroup','Body');part.Parent=body end end
 return m
end
local scenes={}
local function scene(name,frames,awake,hunting)
 local hull={};for g,pts in pairs(rig.FloorSamples)do
  local f=frames[g];local list={}
  for _,p in ipairs(pts)do local q=f*V(p[1],p[2],p[3]);list[#list+1]=string.format('[%.3f,%.3f,%.3f]',q.X,q.Y,q.Z)end
  hull[#hull+1]=string.format('"%s":[%s]',g,table.concat(list,','))
 end
 local boxes={}
 for _,p in ipairs(rig.Parts)do
  local vol=p.Size[1]*p.Size[2]*p.Size[3]
  if not p.Textured and vol<=60 and math.max(p.Size[1],p.Size[2],p.Size[3])<=9 and p.Group~='Tail' and not(p.Group=='Head' and p.Name:find('_06'))then
   local cf=frames[p.Group]*CF(p.Center[1],p.Center[2],p.Center[3])
   boxes[#boxes+1]=string.format('{"m":%s,"s":[%.3f,%.3f,%.3f],"c":%s,"glow":%s}',comps(cf),p.Size[1],p.Size[2],p.Size[3],string.format('[%.3f,%.3f,%.3f]',p.Color[1],p.Color[2],p.Color[3]),tostring(p.EyeGlow==true or p.Glow==true))
  end
 end
 local acc=Acc.new(model(1),3);local parts,out={},{}
 Acc.Pose(acc,frames,CF(0,0,0),awake,R.clock,hunting,parts,out)
 local items={}
 for i,it in ipairs(acc.Items)do
  local p=it.Part;local s=it.Spec
  local shape=p.Shape and p.Shape.Name or 'Block'
  if shape~='Ball'and shape~='Cylinder'then shape='Block'end
  items[#items+1]=string.format('{"n":"%s","gear":%s,"detail":%s,"m":%s,"s":[%.3f,%.3f,%.3f],"c":%s,"mat":"%s","t":%.2f,"sh":"%s","refl":%.2f}',
   p.Name,tostring(s.Gear==true),tostring(s.Detail==true),comps(out[i]),p.Size.X,p.Size.Y,p.Size.Z,col(p.Color),p.Material.Name,p.Transparency,shape,p.Reflectance or 0)
 end
 scenes[#scenes+1]=string.format('{"pose":"%s","hull":{%s},"boxes":[%s],"items":[%s],"tail":%s}',name,table.concat(hull,','),table.concat(boxes,','),table.concat(items,','),comps(frames.Tail))
end
-- stand (awake, still), sleep (curled), run (mid stride), strike (the real pounce swipe at its impact frame), roar-free
scene('stand',Pose.Frames(3,1,1,0,0,0,0,0),1,false)
scene('sleep',Pose.Frames(3,1,0,0,0,0,0,0),0,false)
scene('run',Pose.Frames(3,2,1,1,1.4,1,70,0),1,true)
local started=10;local impact=started+Combat.Get(3).Windup
scene('strike',Sig.Frames(3,impact,started,nil),1,true)
scene('cock',Sig.Frames(3,started+Combat.Get(3).Windup*.5,started,nil),1,true)
print('{"scenes":['..table.concat(scenes,',')..']}')
