--!nocheck
-- R152: today's keepers, dumped through the public keeper APIs with NO variant (the fallback path). run_keepers.sh runs it on the BASE
-- commit's modules and on this checkout's (no mesh API installed: every keeper is today's) and the two dumps must be identical:
-- pose frames (BeastPose / KeeperUpgradePose + CrystalKnightPose), the server's hit frames (KeeperStrikeFrames), the client strike frames
-- (KeeperSignatureStrike), the dressed rigs (BeastModels, every stage), the contact parts (KeeperContact), the accents (KeeperAccents),
-- today's Darkened (VeiledKeeper81.Build), the sleep marker (KeeperSleep) and the effect anchors (KeeperFx).
-- Only the status attribute KeeperMeshVariant (new in R152: 'Legacy' on today's keepers) is left out of the comparison.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
W.Run.IsServer=function()return true end
local out={}
local function put(s)out[#out+1]=s end
local function n(x)local s=string.format('%.5f',x);if s=='-0.00000'then s='0.00000'end;return s end
local function cf(c)local t={c:GetComponents()};for i,v in ipairs(t)do t[i]=n(v)end;return table.concat(t,',')end
local function v3(v)return n(v.X)..','..n(v.Y)..','..n(v.Z)end
local function val(v)
 local t=R.typeof(v)
 if t=='CFrame'then return 'CF('..cf(v)..')'elseif t=='Vector3'then return 'V('..v3(v)..')'elseif t=='Color3'then return 'C('..n(v.R)..','..n(v.G)..','..n(v.B)..')'
 elseif t=='EnumItem'then return v.EnumType..'.'..v.Name elseif t=='number'then return n(v)end
 return tostring(v)
end
local function attrs(o)local keys={};for k in pairs(o._attrs)do if k~='KeeperMeshVariant'then keys[#keys+1]=k end end;table.sort(keys);local t={};for _,k in ipairs(keys)do t[#t+1]=k..'='..val(o._attrs[k])end;return table.concat(t,';')end
local function frames(label,f)
 local keys={};for k in pairs(f)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do put(label..' '..k..' '..cf(f[k]))end
end
local Pose=W.module('BeastPose');local Strike=W.module('KeeperStrikeFrames');local Sig=W.module('KeeperSignatureStrike');local Combat=W.module('KeeperCombat')
local Cfg=W.module('KeeperRigConfig')
for stage=1,7 do
 for _,t in ipairs({0,1.7})do for _,awake in ipairs({0,.35,1})do for _,moving in ipairs({0,.6,1})do for k=0,5 do for _,turn in ipairs({-1,0,1})do
  frames(('pose %d %s %s %s %d %d'):format(stage,n(t),n(awake),n(moving),k,turn),Pose.Frames(stage,t,awake,moving,k/6*math.pi*2,awake,35,turn))
 end end end end end
 local w=Combat.Get(stage).Windup;local e=0
 while e<=w+Combat.Recovery+.05 do
  frames(('strike %d %s'):format(stage,n(e)),Strike.Frames(stage,10+e,10))
  frames(('signature %d %s'):format(stage,n(e)),Sig.Frames(stage,10+e,10))
  e+=.04
 end
end
-- today's imported mesh templates (stages 2, 3, 4, 6 live in ServerStorage.KeeperTemplatesV100): stand-ins built from KeeperRigConfig's parts
local SS=W.service('ServerStorage');local tf=R.new('Folder');tf.Name='KeeperTemplatesV100';tf.Parent=SS
for _,stage in ipairs({2,3,4,6})do
 local m=R.new('Model');m.Name='Stage'..stage;m:SetAttribute('VisualVersion',99)
 for _,s in ipairs(Cfg[stage].Parts)do
  local p=R.new('MeshPart');p.Name=s.Name;p.Size=V3(s.Size[1],s.Size[2],s.Size[3]);local rest=CF(s.Center[1],s.Center[2],s.Center[3]);p.CFrame=rest
  p:SetAttribute('RestCFrame',rest);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow);p.Parent=m
 end
 -- (Roblox's Clone keeps attributes; the plain mock Clone drops them)
 rawset(m,'Clone',function(self)
  local c=R.new('Model');for k,v in pairs(self._props)do c._props[k]=v end;for k,v in pairs(self._attrs)do c._attrs[k]=v end
  for _,ch in ipairs(self._children)do local q=R.Inst.Clone(ch);for k,v in pairs(ch._attrs)do q._attrs[k]=v end;q.Parent=c end
  return c
 end)
 m.Parent=tf
end
local Models=W.module('BeastModels');local Contact=W.module('KeeperContact');local Acc=W.module('KeeperAccents')
local CS=W.service('CollectionService')
for stage=1,7 do
 local m=R.new('Model');m.Name='Guardian'..stage;local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(stage*40,6,10);root.Parent=m;m.PrimaryPart=root
 m.Parent=W.workspace;CS:AddTag(m,'BiomeKeeper')
 Models.Dress(m,stage)
 put(('dress %d model %s'):format(stage,attrs(m)))
 local body=m:FindFirstChild('BeastBody')
 put(('dress %d body %s %s'):format(stage,body.ClassName,attrs(body)))
 for i,p in ipairs(body:GetChildren())do
  put(('dress %d part %d %s %s size %s cf %s col %s mat %s tr %s %s'):format(stage,i,p.Name,p.ClassName,v3(p.Size),cf(p.CFrame),val(p.Color),val(p.Material),n(p.Transparency),attrs(p)))
 end
 -- a second Dress of a dressed keeper changes nothing
 Models.Dress(m,stage);put(('redress %d same body %s'):format(stage,tostring(m:FindFirstChild('BeastBody')==body)))
 local names={};for _,p in ipairs(Contact.Parts(m))do names[#names+1]=p.Name end;put(('contact %d %s'):format(stage,table.concat(names,',')))
 local a=Acc.new(m,stage)
 if a then for i,it in ipairs(a.Items)do put(('accent %d %d %s %s %s'):format(stage,i,it.Part.Name,v3(it.Part.Size),cf(it.Rest)))end;Acc.Destroy(a)else put(('accent %d none'):format(stage))end
 local Sleep=W.module('KeeperSleep');local sl=Sleep.new(root,stage,Cfg[stage])
 put(('sleep %d head %s gui %s'):format(stage,v3(sl.HeadPoint),sl.Zzz and(#sl.Labels..' '..sl.Labels[1].Text..' '..sl.Zzz.Name)or'none'))
 local Fx=W.module('KeeperFx');local fx=Fx.new(root,stage)
 if fx then
  local feet={};for g,v in pairs(fx.Feet)do feet[#feet+1]=g..'='..v3(v)end;table.sort(feet)
  local tips={};for _,t in ipairs(fx.Tips)do tips[#tips+1]=t.Group..'='..v3(t.Point)end
  put(('fx %d body %s eye %s mouth %s feet %s tips %s'):format(stage,v3(fx.BodyPoint),fx.EyePoint and v3(fx.EyePoint)or'-',(fx.MouthPoint or Fx.Mouth[stage])and v3(fx.MouthPoint or Fx.Mouth[stage])or'-',table.concat(feet,' '),table.concat(tips,' ')))
  Fx.Destroy(fx)
 end
end
local Veiled=W.module('VeiledKeeper81')
local d=Veiled.Build(CF(0,5,0),W.workspace)
put('darkened model '..attrs(d))
for i,p in ipairs(d:GetChildren())do put(('darkened part %d %s %s size %s cf %s col %s mat %s %s'):format(i,p.Name,p.ClassName,v3(p.Size),cf(p.CFrame),val(p.Color),val(p.Material),attrs(p)))end
local names={};for _,p in ipairs(Contact.Parts(d))do names[#names+1]=p.Name end;put('darkened contact '..table.concat(names,','))
print(table.concat(out,'\n'))
