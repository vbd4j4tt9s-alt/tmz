--!nocheck
-- Key-pose sheet data: one synthetic timeline per stage, R112 pipeline vs R113 (+KeeperPolish, finish, accents).
local Mx=require('./cfmath');local CF,V=Mx.CFrame,Mx.Vector3.new
local Base=require('./loader').new(require('./bundle_base'));local New=require('./loader').new(require('./bundle_new'))
local out,curves={},{}
local function box(cf,size,col,shape)
 local r=cf.R;return string.format('{"p":[%.3f,%.3f,%.3f],"r":[%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f],"s":[%.3f,%.3f,%.3f],"c":[%.3f,%.3f,%.3f],"sh":"%s"}',
  cf.X,cf.Y,cf.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3],size.X,size.Y,size.Z,col[1],col[2],col[3],shape or 'Block')
end
local speeds={[1]=23,[2]=57,[3]=92,[4]=147,[5]=236,[6]=37,[7]=379}
local keys={{1.0,'sleep (breathing)'},{2.16,'wake: anticipation'},{2.55,'wake: roar / rear'},{3.9,'chase stride'},{4.25,'hard turn: look + tail lag'},{0,'IMPACT (server frames)'},{1,'catch taunt'},{8.2,'return'}}
for stage=1,7 do
 for _,which in ipairs({{'R112',Base,false},{'R113',New,true}})do
  local L=which[2];local polished=which[3]
  local Pose=L.require('BeastPose');local Strike=L.require('KeeperStrikeFrames');local C=L.require('KeeperCombat');local Cfg=L.require('KeeperRigConfig')
  local Motion=L.require('KeeperMotion');local UP=L.require('KeeperUpgradePose')
  local P=polished and L.require('KeeperPolish');local Art=polished and L.require('KeeperUpgradeArt')
  local Acc=polished and L.require('KeeperAccents')
  local Wd=C.Get(stage).Windup;local attackAt=5.0;local impact=attackAt+Wd
  keys[6][1]=impact;keys[7][1]=attackAt+Wd+C.Recovery+.45
  local st=P and P.new();local awake,moving,speed,cycle,yaw=0,0,0,0,0;local wakeAt,tauntAt
  local dt=1/60;local ki=1;local series={}
  for i=0,math.floor(8.4*60)do
   local t=i*dt
   local state=t<2 and 'SLEEP'or t<3.1 and 'ALERT'or t<attackAt and 'CHASE'or t<7.6 and 'ATTACK'or 'RETURN'
   if state~='SLEEP'and not wakeAt then wakeAt=t end
   if state=='ATTACK'and t>=attackAt+Wd+C.Recovery and not tauntAt then tauntAt=t end
   local asleep=state=='SLEEP';local active=state=='CHASE'or state=='RETURN'
   local target=active and(state=='RETURN'and speeds[stage]*.5 or speeds[stage])or 0
   speed+=(target-speed)*(1-math.exp(-dt*8));moving+=((active and math.clamp(speed/5,0,1)or 0)-moving)*(1-math.exp(-dt*10))
   awake+=math.clamp((asleep and 0 or 1)-awake,-dt*.9,dt*1.1)
   cycle=(cycle+dt*Motion.Frequency(stage,speed)*math.pi*2)%(math.pi*2)
   local turnRate=(t>4.0 and t<4.35)and 2.6 or 0;yaw+=turnRate*dt
   local urgency=state=='CHASE'and 1 or 0
   local frames=Pose.Frames(stage,t,awake,moving,cycle,urgency,speed,math.clamp(turnRate*.4,-1,1))
   local striking=t>=attackAt and t<attackAt+Wd+C.Recovery
   if striking then frames=Strike.Frames(stage,t,attackAt,nil)end
   local a=striking and 1 or awake
   if P then
    local look=(state=='CHASE'or state=='ALERT')and V(-14,4,-26)or nil
    frames=P.Apply(st,stage,frames,{Now=t,Dt=dt,Awake=a,Moving=moving,Speed=speed,Frame=CF.Angles(0,yaw,0),Asleep=asleep,Look=look and CF.Angles(0,yaw,0)*look,
     Stir=false,Strike=striking,Impact=impact,WakeAt=wakeAt,TauntAt=tauntAt})
   end
   if i%3==0 then local h=frames.Head;local x,y,z=h:ToEulerAnglesXYZ();local b=frames.Body or frames.Segment1;local bx=b:ToEulerAnglesXYZ()
    local tail=frames.Tail or frames.Segment9;local tx,ty=0,0;if tail then local _;_,ty=tail:ToEulerAnglesXYZ()end
    table.insert(series,string.format('[%.3f,%.4f,%.4f,%.4f,%.4f]',t,x,y,bx,ty))end
   local key=keys[ki]
   if key and math.abs(t-key[1])<dt*.5+1e-9 or(key and t>key[1])then
    ki+=1;local boxes={}
    for _,p in ipairs(Cfg[stage].Parts)do
     local g=frames[p.Group]
     if g then
      local rest=p.Rest and CF.new(table.unpack(p.Rest))or CF.new(table.unpack(p.Center));local size=V(table.unpack(p.Size))
      local pose=g*rest
      if p.TreeRest then pose,size=UP.PartPose(rest,CF.new(table.unpack(p.TreeRest)),size,V(table.unpack(p.TreeSize)),g,a)end
      local col=p.Color or {.6,.6,.6};if p.Textured then col={.62,.58,.52}end
      if Art and Art.Finish[stage]and Art.Finish[stage][p.Name]and Art.Finish[stage][p.Name][2]then col=Art.Finish[stage][p.Name][2]end
      if p.EyeGlow then col=a>.5 and col or {0,0,0}end
      local shape=p.Shape=='Ellipsoid'and'Ball'or p.Shape=='CylinderX'and'Cyl'or'Block'
      table.insert(boxes,box(pose,size,col,shape))
     end
    end
    if Acc and Acc.Specs[stage]and(stage~=1 or a>.7)then
     for _,s in ipairs(Acc.Specs[stage])do local g=frames[s.Group];if g then table.insert(boxes,box(g*CF.new(s.At),s.Size,{s.Color.R,s.Color.G,s.Color.B},s.Shape=='Ball'and'Ball'or'Block'))end end
    end
    table.insert(out,string.format('{"kind":"k%d","label":"%s %s","note":"%s","hot":%s,"boxes":[%s]}',stage,which[1],Cfg[stage].Name,string.format('t=%.2fs %s',t,key[2]),key[2]:find('IMPACT')and'true'or'false',table.concat(boxes,',')))
   end
  end
  table.insert(curves,string.format('"%s_%d":[%s]',which[1],stage,table.concat(series,',')))
 end
end
print('{"cells":['..table.concat(out,',')..'],"curves":{'..table.concat(curves,',')..'}}')
