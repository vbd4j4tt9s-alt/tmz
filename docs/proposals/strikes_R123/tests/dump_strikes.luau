--!nocheck
-- R123 frame strips: per keeper, the R112 shared strike (= the server's contact frames) above the R123 client
-- signature move at the same instants. A red cube marks the server's striking tip at contact.
local W=require('./world');local Mx=W.Mx;local CF,V=Mx.CFrame,Mx.Vector3.new
local world=W.new(require('./bundle_new'),{KeeperRecoveryDash={VisualFrame=function(_,_,f)return f end}})
local req=world.require
local Strike=req('KeeperStrikeFrames');local Sig=req('KeeperSignatureStrike');local C=req('KeeperCombat');local Cfg=req('KeeperRigConfig')
local UP=req('KeeperUpgradePose');local Art=req('KeeperUpgradeArt')
local out={}
local function box(cf,size,col,shape)
 local r=cf.R;return string.format('{"p":[%.3f,%.3f,%.3f],"r":[%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f],"s":[%.3f,%.3f,%.3f],"c":[%.3f,%.3f,%.3f],"sh":"%s"}',
  cf.X,cf.Y,cf.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3],size.X,size.Y,size.Z,col[1],col[2],col[3],shape or 'Block')
end
local function tipPoint(stage,group)
 local b=Cfg[stage].Bounds[group]
 if group=='Head'then return V((b[1][1]+b[2][1])/2,(b[1][2]+b[2][2])/2,math.min(b[1][3],b[2][3]))end
 return V((b[1][1]+b[2][1])/2,math.min(b[1][2],b[2][2]),(b[1][3]+b[2][3])/2)
end
local function keys(move,Wd)
 local cock,rel=Wd*move.Cock,Wd*move.Release;local post=C.Recovery-C.HitHold
 return {{0,'idle'},{cock*.5,'wind-up'},{(cock+rel)/2,'cocked (hold)'},{rel+(Wd-rel)*.6,'strike'},{Wd,'CONTACT = server hit'},
  {Wd+C.HitHold+post*move.Peak,'follow-through'},{Wd+C.HitHold+post*(move.Peak+(1-move.Peak)*.5),'recovery'}}
end
for stage=1,7 do
 local Wd=C.Get(stage).Windup;local move=Sig.Moves[stage]
 local serverTip=V(0,0,0);do local f=Strike.Frames(stage,Wd,0);for _,g in ipairs(move.Tip)do serverTip+=f[g]*tipPoint(stage,g)end;serverTip/=#move.Tip end
 for _,row in ipairs({{'R112 shared',false},{'R123 '..move.Name,true}})do
  for _,key in ipairs(keys(move,Wd))do
   local t=key[1];local frames=row[2]and Sig.Frames(stage,t,0)or Strike.Frames(stage,t,0)
   local boxes={}
   for _,p in ipairs(Cfg[stage].Parts)do
    local g=frames[p.Group]
    if g then
     local rest=p.Rest and CF.new(table.unpack(p.Rest))or CF.new(table.unpack(p.Center));local size=V(table.unpack(p.Size))
     local pose=g*rest
     if p.TreeRest then pose,size=UP.PartPose(rest,CF.new(table.unpack(p.TreeRest)),size,V(table.unpack(p.TreeSize)),g,1)end
     local col=p.Color or {.6,.6,.6};if p.Textured then col={.62,.58,.52}end
     if Art.Finish[stage]and Art.Finish[stage][p.Name]and Art.Finish[stage][p.Name][2]then col=Art.Finish[stage][p.Name][2]end
     local shape=p.Shape=='Ellipsoid'and'Ball'or p.Shape=='CylinderX'and'Cyl'or'Block'
     table.insert(boxes,box(pose,size,col,shape))
    end
   end
   local hot=key[2]:find('CONTACT')~=nil
   if hot then local s=(Cfg[stage].Scale or 1)^.5*.9;table.insert(boxes,box(CF.new(serverTip),V(s,s,s),{.9,.1,.1},'Block'))end
   table.insert(out,string.format('{"kind":"k%d","label":"%s","note":"t=%.3fs %s","hot":%s,"boxes":[%s]}',stage,row[1],t,key[2],hot and'true'or'false',table.concat(boxes,',')))
  end
 end
end
-- The Veiled One (native parts from VeiledKeeper81.Build), server K.Frames above the client lunge.
do
 local K=req('VeiledKeeper81');local Wd=C.Get(7).Windup;local move=Sig.Moves.Veiled
 local folder=W.R.new('Folder');folder.Parent=world.Workspace;world.Game:GetService('CollectionService').AddTag=function()end
 local m=K.Build(CF.new(0,0,0),folder);m:SetAttribute('GuardianBehavior','ATTACKING');m:SetAttribute('VeiledAwakeAt',-10);m:SetAttribute('KeeperAttackAt',0);m:SetAttribute('KeeperTravelSpeed',0)
 local tipServer=K.Frames(m,Wd).RHand.Position
 for _,row in ipairs({{'R112 shared',false},{'R123 '..move.Name,true}})do
  for _,key in ipairs(keys(move,Wd))do
   local t=key[1];local frames=row[2]and K.ClientFrames(m,t,0)or K.Frames(m,t)
   local boxes={}
   for _,p in ipairs(m:GetChildren())do
    local g=p:GetAttribute('VeiledGroup')
    if g and frames[g]then local c=p.Color;local shape=p.Shape==W.R.Enum.PartType.Ball and'Ball'or'Block'
     table.insert(boxes,box(frames[g]*p:GetAttribute('VeiledFrame'),p.Size,{c.R,c.G,c.B},shape))end
   end
   local hot=key[2]:find('CONTACT')~=nil
   if hot then table.insert(boxes,box(CF.new(tipServer),V(.9,.9,.9),{.9,.1,.1},'Block'))end
   table.insert(out,string.format('{"kind":"k8","label":"%s","note":"t=%.3fs %s","hot":%s,"boxes":[%s]}',row[1],t,key[2],hot and'true'or'false',table.concat(boxes,',')))
  end
 end
end
print('{"cells":['..table.concat(out,',')..']}')
