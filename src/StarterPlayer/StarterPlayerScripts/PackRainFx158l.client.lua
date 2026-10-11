do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R158l (owner: "I can make them rain from the sky"): what a screen does for the packs of /test packrain (PackRain158l makes them on the server, at their LANDING spot, tagged PackRain158l).
--   * the fall    each pack is drawn falling from RainHeight studs (90-140) onto its spot in RainFall seconds (2.2-3.2), turning (RainSpin radians, slowing to a stop), upright when it lands; the
--                 time is the server's (RainLandAt), so a player who streams it in mid-fall sees it where it is. Only this screen moves the pack (PivotTo on the local copy): the server moves nothing.
--   * the trail   a gold trail and sparkles behind each falling pack (not in Fast Mode / ClientFxBudget tier 1, not with Reduced Motion).
--   * the end     an untouched pack shrinks away in its last half second (RainEndAt - ShrinkSeconds).
--   * Reduced Motion  no fall, no spin, no trail: the pack is simply there (it can be taken from its spot all the same: the server decides everything).
-- The R158b outline, marker and beam (DroppedPackHighlight158b) come from the host model's DroppedChest attribute; the beam marks the landing spot while the pack is still in the air.
-- The frame loop exists only while a rain pack does. Everything made here is in workspace._PackRainFx158l.
local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService');local Run=game:GetService('RunService');local Gui=game:GetService('GuiService')
local Cfg=require(RS:WaitForChild('PartyRules158l')).Rain
local Fx;pcall(function()Fx=require(RS:WaitForChild('ClientFxBudget',10))end)
local V3,CF=Vector3.new,CFrame.new
local GOLD,WHITE=Color3.fromRGB(255,200,50),Color3.fromRGB(255,255,255)
local packs,count,loop,alive={},0,nil,true
local fxFolder=Instance.new('Folder');fxFolder.Name='_PackRainFx158l';fxFolder.Parent=workspace
local function tierNow()if Fx then local ok,t=pcall(Fx.Get);if ok and type(t)=='number'then return t end end;return 3 end
local function reduced()return Gui.ReducedMotionEnabled==true end
local function startTrail(r)
 local s=math.max(.6,r.Scale)
 local a=Instance.new('Part');a.Name='RainTrail';a.Size=V3(.2,.2,.2);a.Transparency=1;a.Anchored=true;a.CanCollide=false;a.CanTouch=false;a.CanQuery=false;a.CastShadow=false;a.Parent=fxFolder
 local a0=Instance.new('Attachment');a0.Position=V3(0,1.6*s,0);a0.Parent=a
 local a1=Instance.new('Attachment');a1.Position=V3(0,-1.6*s,0);a1.Parent=a
 local t=Instance.new('Trail');t.Attachment0=a0;t.Attachment1=a1;t.Lifetime=.55;t.MinLength=.05;t.FaceCamera=true;t.LightEmission=.8;t.LightInfluence=0
 t.Color=ColorSequence.new(GOLD,WHITE)
 t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(1,1)})
 t.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)});t.Parent=a
 local e=Instance.new('ParticleEmitter');e.Texture='rbxasset://textures/particles/sparkles_main.dds';e.Rate=28;e.Lifetime=NumberRange.new(.4,.8);e.Speed=NumberRange.new(2,5);e.SpreadAngle=Vector2.new(180,180)
 e.LightEmission=1;e.LightInfluence=0;e.Color=ColorSequence.new(GOLD,WHITE);e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.7*s),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)});e.Parent=a
 r.Trail,r.Emitter=a,e
end
local function endTrail(r)
 local a=r.Trail;if not a then return end
 r.Trail=nil;if r.Emitter then r.Emitter.Enabled=false end
 task.delay(.8,function()if a.Parent then a:Destroy()end end) -- (the trail fades out where the pack landed)
end
local function release(host)
 local r=packs[host];if not r then return end
 packs[host]=nil;count-=1
 for _,c in ipairs(r.Conns)do c:Disconnect()end
 if r.Trail then r.Trail:Destroy();r.Trail=nil end
 if count<=0 and loop then loop:Disconnect();loop=nil end
end
local function frame()
 local now=workspace:GetServerTimeNow();local still=reduced();local tier=tierNow()
 for host,r in pairs(packs)do
  local packet=r.Packet
  if not packet or not packet.Parent then
   packet=host:FindFirstChild('SeedPacket');r.Packet=packet
   if packet then r.Base=packet:GetPivot();r.BaseScale=packet:GetScale()end
  end
  if packet and r.Base then
   if now<r.Land and not still then
    local p=math.clamp(1-(r.Land-now)/r.Fall,0,1);local k=(1-p)*(1-p)
    local lift=CF(0,r.Height*(1-p*p),0)*r.Base
    packet:PivotTo(lift*CFrame.Angles(r.Tilt*k,r.Spin*k,0))
    r.Falling=true
    if tier>1 then
     if not r.Trail then startTrail(r)end
     r.Trail.CFrame=CF(lift.Position)
    end
   elseif r.Falling then
    r.Falling=false;packet:PivotTo(r.Base);endTrail(r)
   end
   if now>=r.End-Cfg.ShrinkSeconds then packet:ScaleTo(r.BaseScale*math.clamp((r.End-now)/Cfg.ShrinkSeconds,.02,1))end
  end
 end
end
local function track(host)
 if not alive or packs[host]or not host:IsA('Model')then return end
 local land,fall,height,spin,finish=host:GetAttribute('RainLandAt'),host:GetAttribute('RainFall'),host:GetAttribute('RainHeight'),host:GetAttribute('RainSpin'),host:GetAttribute('RainEndAt')
 if type(land)~='number'or type(fall)~='number'or fall<=0 or type(height)~='number'or type(spin)~='number'or type(finish)~='number'then return end
 local r={Host=host,Land=land,Fall=fall,Height=height,Spin=spin,Tilt=spin*.08,End=finish,Scale=host:GetAttribute('RainScale')or 1,Conns={}}
 packs[host]=r;count+=1
 table.insert(r.Conns,host.Destroying:Connect(function()release(host)end))
 table.insert(r.Conns,host.AncestryChanged:Connect(function()if not host:IsDescendantOf(workspace)then release(host)end end))
 if not loop then loop=Run.RenderStepped:Connect(frame)end
end
for _,host in ipairs(CS:GetTagged(Cfg.Tag))do track(host)end
local conns={CS:GetInstanceAddedSignal(Cfg.Tag):Connect(track),CS:GetInstanceRemovedSignal(Cfg.Tag):Connect(release)}
script.Destroying:Connect(function()
 alive=false;for _,c in ipairs(conns)do c:Disconnect()end
 local all={};for host in pairs(packs)do all[#all+1]=host end;for _,host in ipairs(all)do release(host)end
 if loop then loop:Disconnect();loop=nil end;fxFolder:Destroy()
end)
