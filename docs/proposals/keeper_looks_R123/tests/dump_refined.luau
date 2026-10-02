--!nocheck
-- Dumps BEFORE (KeeperRigConfig mesh boxes + FloorSamples hulls) and AFTER (BeastModelsRefined) geometry,
-- in rest pose and two real poses (BeastPose chase stride, KeeperStrikeFrames impact), and checks bounds.
local Mx=require('./cfmath');local CF,V=Mx.CFrame,Mx.Vector3.new
local L=require('./loader').new(require('./bundle_cur'))
local Cfg=L.require('KeeperRigConfig');local Pose=L.require('BeastPose');local Strike=L.require('KeeperStrikeFrames');local C=L.require('KeeperCombat')
local src=io and nil
local f=assert(loadstring(REFINED_SRC,'=BeastModelsRefined'))
setfenv(f,setmetatable({Vector3=Mx.Vector3,CFrame=Mx.CFrame,Color3=Mx.Color3},{__index=_G}))
local Refined=f()
local function m(cf,s)local r=cf.R;return string.format('[%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f],"s":[%.3f,%.3f,%.3f]',cf.X,cf.Y,cf.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3],s.X,s.Y,s.Z)end
local out={};local report={}
local function corners(cf,s,shape)local t={}
 if shape=='Ball'then local r=cf.R;local h={s.X/2,s.Y/2,s.Z/2};local e={}
  for i=1,3 do e[i]=math.sqrt((r[i][1]*h[1])^2+(r[i][2]*h[2])^2+(r[i][3]*h[3])^2)end
  return {cf.Position+V(e[1],e[2],e[3]),cf.Position-V(e[1],e[2],e[3])}end
 for _,a in ipairs({-1,1})do for _,b in ipairs({-1,1})do for _,c in ipairs({-1,1})do
  if not(shape=='Wedge'and b==1 and c==-1)then table.insert(t,cf*V(a*s.X/2,b*s.Y/2,c*s.Z/2))end end end end;return t end
for _,st in ipairs({2,3,4,6})do
 local cfg=Cfg[st];local specs=Refined.Specs(st)
 local poses={{'rest',nil}}
 local fr=Pose.Frames(st,3.9,1,1,1.3,1,60,0);table.insert(poses,{'chase',fr})
 local wd=C.Get(st).Windup;table.insert(poses,{'impact',Strike.Frames(st,5+wd,5,nil)})
 for _,pp in ipairs(poses)do
  local frames=pp[2];local items={}
  local function F(g)return frames and frames[g] or CF.new()end
  for _,s in ipairs(specs)do
   table.insert(items,string.format('{"m":%s,"c":[%.3f,%.3f,%.3f],"sh":"%s","mat":"%s","t":%.2f,"g":"%s"}',m(F(s.Group)*s.CFrame,s.Size),s.Color[1],s.Color[2],s.Color[3],s.Shape,s.Material,s.Transparency,s.Group))
  end
  table.insert(out,string.format('{"stage":%d,"which":"after","pose":"%s","items":[%s]}',st,pp[1],table.concat(items,',')))
  -- before
  local bi={}
  for _,p in ipairs(cfg.Parts)do
   local rest=CF.new(table.unpack(p.Center));local cf=F(p.Group)*rest
   table.insert(bi,string.format('{"m":%s,"c":[%.3f,%.3f,%.3f],"tex":%s,"glow":%s,"eye":%s,"g":"%s"}',m(cf,V(table.unpack(p.Size))),p.Color[1],p.Color[2],p.Color[3],tostring(p.Textured),tostring(p.Glow),tostring(p.EyeGlow),p.Group))
  end
  local hulls={}
  for g,pts in pairs(cfg.FloorSamples)do local q={}
   for _,pt in ipairs(pts)do local w=F(g)*V(pt[1],pt[2],pt[3]);table.insert(q,string.format('[%.3f,%.3f,%.3f]',w.X,w.Y,w.Z))end
   table.insert(hulls,string.format('"%s":[%s]',g,table.concat(q,',')))
  end
  table.insert(out,string.format('{"stage":%d,"which":"before","pose":"%s","items":[%s],"hulls":{%s}}',st,pp[1],table.concat(bi,','),table.concat(hulls,',')))
 end
 -- bounds check (rest), per group: extents of new parts vs Config.Bounds
 local ext={};local worst={0,''}
 for _,s in ipairs(specs)do
  local b=cfg.Bounds[s.Group];assert(b,'unknown group '..s.Group)
  local e=ext[s.Group]or{V(1e9,1e9,1e9),V(-1e9,-1e9,-1e9)}
  for _,c in ipairs(corners(s.CFrame,s.Size,s.Shape))do
   e[1]=e[1]:Min(c);e[2]=e[2]:Max(c)
   local over=math.max(b[1][1]-c.X,c.X-b[2][1],b[1][2]-c.Y,c.Y-b[2][2],b[1][3]-c.Z,c.Z-b[2][3])
   if over>worst[1]then worst={over,s.Group..'/'..s.Name}end
  end
  ext[s.Group]=e
 end
 local lines={}
 for g,e in pairs(ext)do local b=cfg.Bounds[g]
  table.insert(lines,string.format('   %-14s new [%.1f,%.1f,%.1f | %.1f,%.1f,%.1f]  old [%.1f,%.1f,%.1f | %.1f,%.1f,%.1f]',g,e[1].X,e[1].Y,e[1].Z,e[2].X,e[2].Y,e[2].Z,b[1][1],b[1][2],b[1][3],b[2][1],b[2][2],b[2][3]))end
 table.sort(lines)
 local shapes={};for _,s in ipairs(specs)do shapes[s.Shape]=(shapes[s.Shape]or 0)+1 end
 local sh={};for k2,v in pairs(shapes)do table.insert(sh,k2..'='..v)end;table.sort(sh)
 local eyes=0;for _,s in ipairs(specs)do if s.EyeGlow then eyes+=1 end end
 table.insert(report,string.format('%d %s: before %d mesh parts, after %d native parts (%s), eye parts %d; worst bounds overshoot %.2f studs (%s)\n%s',st,cfg.Name,#cfg.Parts,#specs,table.concat(sh,' '),eyes,worst[1],worst[2],table.concat(lines,'\n')))
end
io_report=table.concat(report,'\n')
print('{"scenes":['..table.concat(out,',')..'],"report":'..string.format('%q',io_report):gsub('\\\n','\\n')..'}')
