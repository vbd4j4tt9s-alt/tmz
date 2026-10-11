do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R158l (owner: "disco all over": /test disco): the server-wide party, drawn by THIS screen alone. The server sets one workspace attribute and nothing else:
--   Disco158l = nil / 0: off | -1: until /test disco off | a server time: until then;   DiscoCenter158l = the hub (the lobby spawn).
-- This script reads them (also when they are already set as the player joins: a late arrival sees the party) and, while the disco is on, builds in workspace._Disco158l:
--   * a spinning disco ball 70 studs over the hub (a mirror-faceted sphere and, when there is room, a coloured point light that follows the beat),
--   * moving spotlights: slim beams from the ball to pools of light that sweep over the hub floor,
--   * a dance floor: a grid of tiles on the ground that change colour on the beat (2 times a second: never more than 3 flashes a second),
--   * confetti bursts over the hub every 2 seconds,
--   * a colour tint over the whole screen: ONE ColorCorrectionEffect (Disco158lTint) added to Lighting that cycles its hue. No Lighting property is read or written, so nothing can be left behind:
--     when the party ends (the attribute clears, the time passes, or this script goes away) the folder and the tint are destroyed and Lighting is exactly what it was.
-- Fast Mode / low graphics (ClientFxBudget tier 1): a 3x3 floor, 2 beams, a small ball, no light, no confetti. Phones (tier 2): 5x5, 4 beams, small bursts. Reduced Motion: NO flashing and no
-- sweeping: the same lights stand still and their colours drift slowly (a full cycle takes 50 s); the ball does not spin and there is no confetti. Nothing here runs on the server.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Gui=game:GetService('GuiService');local Lighting=game:GetService('Lighting');local Players=game:GetService('Players')
local D=require(RS:WaitForChild('PartyRules158l')).Disco
local Fx;pcall(function()Fx=require(RS:WaitForChild('ClientFxBudget',10))end)
local V3,CF,C=Vector3.new,CFrame.new,Color3.fromRGB
local PALETTE={C(255,60,170),C(40,230,255),C(255,230,60),C(90,255,130),C(175,95,255),C(255,140,40),C(70,115,255),C(255,70,70)}
local BEAT=2 -- floor / beam colour changes per second
local TILE=11 -- studs
local scene,loop,alive=nil,nil,true
local function tierNow()if Fx then local ok,t=pcall(Fx.Get);if ok and type(t)=='number'then return t end end;return 3 end
local function reduced()return Gui.ReducedMotionEnabled==true end
local function profile(tier)
 if tier<=1 then return{Grid=3,Beams=2,Facets=8,Burst=0,Light=false}
 elseif tier==2 then return{Grid=5,Beams=4,Facets=14,Burst=14,Light=true}end
 return{Grid=7,Beams=6,Facets=22,Burst=32,Light=true}
end
local function part(parent,name,size,frame,color,material,transparency)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.Neon;p.Transparency=transparency or 0
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent
 return p
end
local function active(v)
 if type(v)~='number'or v==0 then return false end
 return v<0 or v>workspace:GetServerTimeNow()
end
-- The ground height under (x, z) near the hub, or nil.
local function groundY(s,x,z)
 local ok,hit=pcall(function()
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
  local list={s.Folder};for _,pl in ipairs(Players:GetPlayers())do if pl.Character then list[#list+1]=pl.Character end end
  params.FilterDescendantsInstances=list
  return workspace:Raycast(V3(x,s.Center.Y+80,z),V3(0,-200,0),params)
 end)
 if ok and hit and hit.Normal and hit.Normal.Y>.7 then return hit.Position.Y end
 return nil
end
local function colorAt(i)return PALETTE[(i-1)%#PALETTE+1]end
local function build(center)
 local prof=profile(tierNow());local still=reduced()
 local folder=Instance.new('Folder');folder.Name='_Disco158l';folder.Parent=workspace
 local s={Folder=folder,Prof=prof,Still=still,Center=center,T0=os.clock(),Beat=-1,Tiles={},Beams={},Bursts={},Slow=0}
 s.Floor=groundY(s,center.X,center.Z)or center.Y
 -- the tint: the only thing added to Lighting
 local tint=Instance.new('ColorCorrectionEffect');tint.Name='Disco158lTint';tint.Brightness=-.05;tint.Contrast=.08;tint.Saturation=.25;tint.TintColor=PALETTE[1];tint.Parent=Lighting
 s.Tint=tint
 -- the dance floor
 local grid=prof.Grid
 for i=1,grid do for j=1,grid do
  local x,z=center.X+(i-(grid+1)/2)*TILE,center.Z+(j-(grid+1)/2)*TILE
  local y=groundY(s,x,z)
  if y then s.Tiles[#s.Tiles+1]={Part=part(folder,'Tile',V3(TILE-1,.3,TILE-1),CF(x,y+.25,z),colorAt(i+j*2),Enum.Material.Neon,.3),I=i,J=j}end
 end end
 -- the ball
 local at=center+V3(0,70,0)
 local model=Instance.new('Model');model.Name='DiscoBall';model.Parent=folder
 local ball=part(model,'Ball',V3(14,14,14),CF(at),C(215,220,230),Enum.Material.Metal,0);ball.Shape=Enum.PartType.Ball;ball.Reflectance=.7
 for k=1,prof.Facets do
  local lat=math.asin(-1+2*((k-.5)/prof.Facets));local lon=k*2.399963
  local dir=V3(math.cos(lat)*math.cos(lon),math.sin(lat),math.cos(lat)*math.sin(lon))
  part(model,'Facet',V3(2.4,2.4,.4),CFrame.lookAt(at+dir*7.2,at+dir*8),colorAt(k+1),Enum.Material.Neon,0)
 end
 model.PrimaryPart=ball;s.Model=model;s.At=at
 if prof.Light then local light=Instance.new('PointLight');light.Range=60;light.Brightness=2;light.Color=PALETTE[1];light.Parent=ball;s.Light=light end
 -- the spotlights: beams from the ball down to pools of light on the floor
 local source=part(folder,'BeamSource',V3(.2,.2,.2),CF(at),C(255,255,255),Enum.Material.Neon,1)
 local a0=Instance.new('Attachment');a0.Parent=source
 for b=1,prof.Beams do
  local pool=part(folder,'LightPool',V3(.2,14,14),CF(center.X,s.Floor+.3,center.Z)*CFrame.Angles(0,0,math.pi/2),colorAt(b),Enum.Material.Neon,.45);pool.Shape=Enum.PartType.Cylinder
  local a1=Instance.new('Attachment');a1.Parent=pool
  local beam=Instance.new('Beam');beam.Attachment0=a0;beam.Attachment1=a1;beam.Width0=1.5;beam.Width1=9;beam.FaceCamera=true;beam.Segments=1;beam.LightEmission=1;beam.LightInfluence=0
  beam.Color=ColorSequence.new(colorAt(b));beam.Transparency=NumberSequence.new(.4);beam.Parent=source
  s.Beams[b]={Pool=pool,Beam=beam,Phase=b*2*math.pi/prof.Beams}
 end
 -- confetti
 if prof.Burst>0 and not still then
  for k=1,3 do
   local host=part(folder,'Confetti',V3(.2,.2,.2),CF(center+V3((k-2)*34,45,0)),C(255,255,255),Enum.Material.Neon,1)
   local e=Instance.new('ParticleEmitter');e.Texture='rbxasset://textures/particles/sparkles_main.dds';e.Rate=0;e.Lifetime=NumberRange.new(3,4);e.Speed=NumberRange.new(14,30);e.SpreadAngle=Vector2.new(80,80)
   e.Acceleration=V3(0,-24,0);e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-280,280);e.LightEmission=.4;e.LightInfluence=0;e.Size=NumberSequence.new(.55)
   e.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,PALETTE[1]),ColorSequenceKeypoint.new(.25,PALETTE[3]),ColorSequenceKeypoint.new(.5,PALETTE[4]),ColorSequenceKeypoint.new(.75,PALETTE[2]),ColorSequenceKeypoint.new(1,PALETTE[5])})
   e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.8,0),NumberSequenceKeypoint.new(1,1)});e.EmissionDirection=Enum.NormalId.Bottom;e.Parent=host
   s.Bursts[#s.Bursts+1]=e
  end
 end
 return s
end
local function stop()
 if loop then loop:Disconnect();loop=nil end
 local s=scene;scene=nil
 if s then
  if s.Tint and s.Tint.Parent then s.Tint:Destroy()end
  if s.Folder and s.Folder.Parent then s.Folder:Destroy()end
 end
end
local function frame()
 local s=scene;if not s then return end
 if not active(workspace:GetAttribute(D.Attribute))then stop();return end
 local t=os.clock()-s.T0;local still=s.Still;local center=s.Center
 -- the tint: a hue that goes round (8 s a round; 50 s with Reduced Motion)
 local hue=(t*(still and .02 or .125))%1
 s.Tint.TintColor=Color3.fromHSV(hue,still and .22 or .38,1)
 if still then
  s.Slow+=1 -- the lights stand still and their colours drift: written 4 times a second at most
  if s.Slow%15==1 then
   for _,tile in ipairs(s.Tiles)do tile.Part.Color=Color3.fromHSV((hue+(tile.I+tile.J)*.05)%1,.8,1)end
   for i,b in ipairs(s.Beams)do local c=Color3.fromHSV((hue+i*.12)%1,.8,1);b.Pool.Color=c;b.Beam.Color=ColorSequence.new(c)end
   if s.Light then s.Light.Color=Color3.fromHSV(hue,.6,1)end
  end
  for i,b in ipairs(s.Beams)do -- (fixed spots, spread round the hub)
   if not b.Placed then b.Placed=true;b.Pool.CFrame=CF(center.X+math.cos(b.Phase)*45,s.Floor+.3,center.Z+math.sin(b.Phase)*45)*CFrame.Angles(0,0,math.pi/2)end
  end
  return
 end
 s.Model:PivotTo(CF(s.At)*CFrame.Angles(0,t*.7,0))
 for _,b in ipairs(s.Beams)do
  b.Pool.CFrame=CF(center.X+math.sin(t*.5+b.Phase)*70,s.Floor+.3,center.Z+math.sin(t*.37+b.Phase*1.7)*60)*CFrame.Angles(0,0,math.pi/2)
 end
 local beat=math.floor(t*BEAT)
 if beat~=s.Beat then
  s.Beat=beat
  for _,tile in ipairs(s.Tiles)do tile.Part.Color=colorAt(tile.I+tile.J*2+beat);tile.Part.Transparency=(tile.I+tile.J+beat)%2==0 and .3 or .5 end
  for i,b in ipairs(s.Beams)do local c=colorAt(i+beat);b.Pool.Color=c;b.Beam.Color=ColorSequence.new(c)end
  if s.Light then s.Light.Color=colorAt(beat+1)end
  if beat%4==0 and s.Prof.Burst>0 then for _,e in ipairs(s.Bursts)do e:Emit(s.Prof.Burst)end end
 end
end
local function sync()
 if not alive then return end
 local on=active(workspace:GetAttribute(D.Attribute))
 if not on then if scene then stop()end;return end
 local center=workspace:GetAttribute(D.CenterAttribute);if typeof(center)~='Vector3'then center=V3(0,5,0)end
 if scene and scene.Center~=center then stop()end
 if scene then return end
 scene=build(center)
 loop=Run.RenderStepped:Connect(frame)
end
local conns={workspace:GetAttributeChangedSignal(D.Attribute):Connect(sync),workspace:GetAttributeChangedSignal(D.CenterAttribute):Connect(sync)}
script.Destroying:Connect(function()alive=false;for _,c in ipairs(conns)do c:Disconnect()end;stop()end)
sync()
