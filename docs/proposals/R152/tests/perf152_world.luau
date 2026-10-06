-- R152 performance patch: the hub and the keyboard in the finished world (appended to the sweep scene by perf152_world.py, after every start-up builder,
-- the keyboard client, the two hub displays and the Void giveaway pedestal). Globals: MODE = 'hub' | 'kb', TIER (ClientFxBudget 1..3), HUB_STATE ('empty' |
-- 'champions'), RUNNER = {x, z} (the local runner on the track), RUNS (kb: run along the track after the standing shots).
-- Prints fingerprint shots (perf152_fp.luau) and "PERF ..." lines (counts, writes per frame, Lua ms on the mock).
local FP=require('./perf152_fp')(W);FP.orderedPairs()
local TIER=TIER or 3
local cam=W.workspace.CurrentCamera
if cam.FieldOfView==nil then cam.FieldOfView=70 end
-- (the mock camera has no ViewportPointToRay: the vertical field of view and the viewport's aspect, as Roblox's default camera)
if not rawget(cam,'ViewportPointToRay')and not cam._props.ViewportPointToRay then
 cam.ViewportPointToRay=function(self,x,y)
  local vs=self.ViewportSize;local tv=math.tan(math.rad(self.FieldOfView)/2);local th=tv*vs.X/vs.Y
  local dx,dy=(2*x/vs.X-1)*th,(1-2*y/vs.Y)*tv
  local cf=self.CFrame;local d=(cf.RightVector*dx+cf.UpVector*dy+cf.LookVector).Unit
  return {Origin=cf.Position,Direction=d}
 end
end
local me=Players.LocalPlayer
local ws=W.workspace
local function look(from,at)cam.CFrame=R.CFrame.lookAt(from,at);cam.Focus=CF(at.X,at.Y,at.Z)end
local function perf(area,text)print(string.format('PERF %s tier=%d %s',area,TIER,text))end
for _,s in ipairs(steps)do print('STEP '..s..' ok')end
if failed>0 then print('FAILED '..failed..' build steps');error('build failed',0)end
-- the area a written instance belongs to (for the write counts)
local AREAS={KeyboardTrackVisuals='keyboard',HubLife151='hublife',VoidGiveawayPacks152='giveaway',_VoidPackFx122='giveaway',VoidGiveaway152='giveaway',
 HubDisplays151='displays',HubDecor151='decor',Camera='camera',PlayerGui='gui',SoundService='sound',Lighting='lighting'}
FP.Probe.Classify=function(o)
 local x=o
 while x do local a=AREAS[x._props.Name];if a then return a end;x=x._parent end
 return'other'
end
local realClock=os.clock
-- frames with timing: n frames of dt; returns {ms per frame by chunk}, writes probe
local function measure(n,dt)
 FP.probeStart()
 local best=FP.minTimes(W.Run,4,n//4,function()W.frames(1,dt)end)
 local p=FP.probeStop()
 return p,best,0
end
-- times: ms a frame by chunk (FP.minTimes)
local function report(area,p,times,wall,n,chunks)
 local parts={}
 for _,c in ipairs(chunks)do parts[#parts+1]=string.format('%s %.3f ms',c,times[c]or 0)end
 local areas=FP.probeAreas(p);local ap={}
 local names={};for a in pairs(areas)do names[#names+1]=a end;table.sort(names)
 for _,a in ipairs(names)do ap[#ap+1]=string.format('%s %.1f (same %.1f)',a,areas[a][1]/n,areas[a][2]/n)end
 perf(area,string.format('frames=%d lua: %s | writes/frame by area: %s | %s',n,table.concat(parts,', '),table.concat(ap,', '),FP.probeText(p,n,10)))
end
local function client(name,bundleName)
 local sc=R.new('LocalScript');sc.Name=name;sc.Parent=me:FindFirstChild('PlayerGui')
 local ok,err=pcall(W.load,bundleName,sc);if not ok then print('CLIENT '..name..' FAILED '..tostring(err));error('client failed',0)end
 return sc
end
-- a sphere (centre c, radius r) entirely outside the camera's view (the frustum planes, no far plane)
local function offView(c,r)
 local p=cam.CFrame:PointToObjectSpace(c);local d=-p.Z
 local vs=cam.ViewportSize;local tv=math.tan(math.rad(cam.FieldOfView)/2);local th=tv*vs.X/vs.Y
 if d<-r then return true end
 if math.abs(p.X)-d*th>r*math.sqrt(1+th*th)then return true end
 if math.abs(p.Y)-d*tv>r*math.sqrt(1+tv*tv)then return true end
 return false
end
local DT=TIER>=3 and 1/60 or 1/30
local KB={'KeyboardTrackVisuals'}
local function kbFolder()return ws:FindFirstChild('KeyboardTrackVisuals')end

if MODE=='hub'then
 -- the hub clients, as the local player standing at the spawn plaza ----------------------------------------------------------------------------------------------
 local root=me.Character and me.Character:FindFirstChild('HumanoidRootPart')
 if root then root.CFrame=CF(0,7,-330)end
 look(V3(0,30,-300),V3(0,10,-392))
 client('HubLife151','HubLife151Client');client('HubDisplayClient','HubDisplayClient');client('VoidGiveawayClient152','VoidGiveawayClient152')
 W.frames(45,DT)
 local displays={};for _,m in ipairs(W.CS:GetTagged('HubDisplay151'))do displays[#displays+1]=m end
 table.sort(displays,function(a,b)return a.Name<b.Name end)
 local give=W.CS:GetTagged('VoidGiveaway152')[1]
 local function dyn()
  local roots={map:FindFirstChild('HubDisplays151'),ws:FindFirstChild('VoidGiveawayPacks152'),ws:FindFirstChild('HubLife151'),give}
  for _,c in ipairs(ws:GetChildren())do if c.Name=='_VoidPackFx122'then roots[#roots+1]=c end end
  return roots
 end
 -- the whole world once (server decor, displays, pedestal, the clients' builds, the keyboard)
 FP.shot(string.format('hub tier=%d state=%s world',TIER,HUB_STATE or'empty'),{ws,W.service('Lighting')})
 for _,k in ipairs({'Instances','Parts','SurfaceGuis','Drawn'})do end
 perf('hub.counts',string.format('state=%s hublife: %s | displays: %s | giveaway: %s | decor: %s',HUB_STATE or'empty',FP.countText(FP.counts(ws:FindFirstChild('HubLife151'))),FP.countText(FP.counts(map:FindFirstChild('HubDisplays151'))),
  FP.countText(FP.counts(give)),FP.countText(FP.counts(map:FindFirstChild('HubDecor151')))))
 -- poses: the plaza, each display, looking away (both displays and the pedestal behind the camera), far down the track, the plaza again
 local poses={{'plaza',V3(0,30,-300),V3(0,10,-392)}}
 for i,m in ipairs(displays)do
  local c=m:GetAttribute('ItemCenter')
  if R.typeof(c)=='Vector3'then
   local toward=V3(-c.X,0,-392-c.Z);toward=toward.Magnitude>1 and toward.Unit or V3(0,0,1)
   local at=c+toward*45+V3(0,6,0)
   poses[#poses+1]={'display'..i,at,c}
   -- (standing there, looking away from the item and back: it is out of view while it still turns, then in view again)
   poses[#poses+1]={'display'..i..'away',at,at+(at-c)}
   poses[#poses+1]={'display'..i..'back',at,c}
  end
 end
 poses[#poses+1]={'away',V3(0,30,-300),V3(0,30,-120)}
 poses[#poses+1]={'plazaB',V3(0,30,-300),V3(0,10,-392)}
 poses[#poses+1]={'up',V3(0,14,-392+40),V3(0,400,-392+60)}
 poses[#poses+1]={'far',V3(0,30,700),V3(0,10,900)}
 poses[#poses+1]={'plaza2',V3(0,30,-300),V3(0,10,-392)}
 for _,pose in ipairs(poses)do
  look(pose[2],pose[3])
  for f=1,24 do
   W.frames(1,DT)
   if f%4==0 then
    -- what is off screen in this pose (and far enough from the camera to be outside the giant parts' close fade): the display items
    local off={}
    for _,m in ipairs(displays)do
     local item=m:FindFirstChild('Item');local c=m:GetAttribute('ItemCenter')
     if item and R.typeof(c)=='Vector3'then
      local _,size=item:GetBoundingBox();local r=size.Magnitude/2*1.25+4
      if offView(c,r)and(cam.CFrame.Position-c).Magnitude>r+12 then off[#off+1]=FP.path(item)end
     end
    end
    -- and the giveaway's Void pack (its pieces round the pedestal's pack anchor)
    local folder=ws:FindFirstChild('VoidGiveawayPacks152');local pack=folder and folder:FindFirstChild('VoidGiveawayPack')
    local anchor=give and give:FindFirstChild('PackAnchor',true)
    if pack and anchor then
     local c=anchor.Position;local reach=0
     for _,d in ipairs(pack:GetDescendants())do if d:IsA('BasePart')then reach=math.max(reach,(d.Position-c).Magnitude+d.Size.Magnitude/2)end end
     local r=reach*1.25+4
     if offView(c,r)and(cam.CFrame.Position-c).Magnitude>r+12 then off[#off+1]=FP.path(pack)end
    end
    local tag=#off>0 and(' OFFSCREEN='..table.concat(off,','))or''
    FP.shot(string.format('hub tier=%d state=%s pose=%s f%d%s',TIER,HUB_STATE or'empty',pose[1],f,tag),dyn())
   end
  end
 end
 -- per-frame cost at three poses
 local measured={};for _,pose in ipairs(poses)do if pose[1]=='plaza'or pose[1]=='display1'or pose[1]=='away'or pose[1]=='far'then measured[#measured+1]=pose end end
 for _,pose in ipairs(measured)do
  look(pose[2],pose[3]);W.frames(20,DT)
  local p,times,wall=measure(120,DT)
  report('hub.'..pose[1],p,times,wall,120,{'HubLife151Client','HubDisplayClient','VoidGiveawayClient152','VoidPackFx','PlantAnimationBatch','KeyboardTrackClient','SnowBiome'})
 end
elseif MODE=='kb'then
 -- the keyboard around a runner: standing at every sample row (KB_ROWS: every biome; the runner teleports from one to the next, as a respawn / a pad does),
 -- looking along, back, across and down; then a run with a turn to look back --------------------------------------------------------------------------------
 local root=me.Character.HumanoidRootPart
 local x=RUNNER[1]
 local LOOKS={{'along',V3(0,14,-24),V3(0,2,40)},{'back',V3(0,14,24),V3(0,2,-40)},{'across',V3(-26,16,0),V3(20,0,0)},{'down',V3(0,40,-1),V3(0,0,0)}}
 for _,z in ipairs(KB_ROWS or{RUNNER[2]})do
  local label=string.format('kb tier=%d z=%d',TIER,z)
  root.CFrame=CF(x,7,z);root.AssemblyLinearVelocity=V3(0,0,0)
  for _,l in ipairs(LOOKS)do
   local at=V3(x,7,z)
   look(at+l[2],at+l[3]);W.frames(TIER==3 and 40 or 30,DT)
   FP.shot(label..' look='..l[1],{kbFolder()})
   perf('kb.counts',string.format('z=%d look=%s %s',z,l[1],FP.countText(FP.counts(kbFolder()))))
  end
  -- standing still: per-frame cost
  local at=V3(x,7,z);look(at+LOOKS[1][2],at+LOOKS[1][3]);W.frames(20,DT)
  local p,times,wall=measure(60,DT);report('kb.stand z='..z,p,times,wall,60,{'KeyboardTrackClient','SnowBiome'})
 end
 if RUNS then
  -- a run at 45 studs / s along +Z with the camera behind, then a turn to look back while running; a shot every 6 frames
  local speed=45;local z=(KB_ROWS or{RUNNER[2]})[1];local pz=z
  root.CFrame=CF(x,7,pz);W.frames(30,DT)
  for f=1,96 do
   pz+=speed*DT
   root.CFrame=CF(x,7,pz);root.AssemblyLinearVelocity=V3(0,0,speed)
   local at=V3(x,7,pz)
   if f<=60 then look(at+LOOKS[1][2],at+LOOKS[1][3])else look(at+LOOKS[2][2],at+LOOKS[2][3])end
   W.frames(1,DT)
   if f%6==0 then FP.shot(string.format('kb tier=%d run f%d',TIER,f),{kbFolder()})end
  end
  -- per-frame cost while running
  FP.probeStart()
  local best=FP.minTimes(W.Run,4,24,function()
   pz+=speed*DT;root.CFrame=CF(x,7,pz);root.AssemblyLinearVelocity=V3(0,0,speed)
   local at=V3(x,7,pz);look(at+LOOKS[1][2],at+LOOKS[1][3]);W.frames(1,DT)
  end)
  local p=FP.probeStop();report('kb.run',p,best,0,96,{'KeyboardTrackClient','SnowBiome'})
 end
end
print('PERF152 DONE')
