do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R148 (owner: "remove this line when purchasing and add the vfx and sfx and also the notification for making a successful
-- purchase"): the buyer's half of a purchase. PurchaseAnnouncer (server) already sent the "✅ Purchased: <what>!" notice;
-- when ChestChaseRemotes.PurchaseDone arrives this plays the reward chime (InteractionAudio GemClaim, the one the Index,
-- daily and gift claims already use) and a short celebration: a ring and a spray of confetti over the middle of the screen
-- (so it sits over the shop card whichever one was bought) plus a small sparkle burst at the character.
-- Cheap and cleaned up: the screen layer exists only while a burst is alive, with one RenderStepped connection that is
-- dropped when the last piece fades (about 1.4 s); the sparkles are removed after 1.8 s; bursts are capped (two alive at
-- once, 0.25 s apart); the piece count follows ClientFxBudget (FastMode = low); ReducedMotion keeps the chime and the
-- notice but shows no motion at all. Nothing here can affect a purchase: the server already finished it.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local player=Players.LocalPlayer
local remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PurchaseDone')
local Audio;pcall(function()Audio=require(RS:WaitForChild('InteractionAudio'))end)
local Budget;pcall(function()Budget=require(RS:WaitForChild('ClientFxBudget'))end)
local RGB=Color3.fromRGB
local PALETTE={RGB(255,214,79),RGB(120,232,110),RGB(110,190,255),RGB(255,110,150),RGB(200,140,255),RGB(255,255,255)}
local MAX_BURSTS,GAP,LIFE,RING_LIFE,GRAVITY=2,.25,1.4,.5,820
local rng=Random.new()
local bursts={};local layer;local screen;local connection;local lastAt=-math.huge;local dead=false
local function reduced()
 local okay,value=pcall(function()return Gui.ReducedMotionEnabled end)
 return okay and value==true
end
local function tier()
 if not Budget then return 3 end
 local okay,value=pcall(Budget.Get)
 return okay and type(value)=='number'and value or 3
end
local function stop()
 if connection then connection:Disconnect();connection=nil end
 if screen then screen:Destroy();screen=nil;layer=nil end
end
local function step(dt)
 dt=math.min(dt,.1)
 for i=#bursts,1,-1 do
  local b=bursts[i];b.Age+=dt
  if b.Age>=b.Life then
   b.Ring:Destroy();if b.Icon then b.Icon:Destroy()end;for _,piece in ipairs(b.Pieces)do piece.Frame:Destroy()end;table.remove(bursts,i)
  else
   local k=math.min(1,b.Age/RING_LIFE);local size=b.Scale*(30+230*(1-(1-k)^2))
   b.Ring.Size=UDim2.fromOffset(size,size);if b.Edge then b.Edge.Transparency=k end
   b.Ring.Visible=k<1
   -- R153: the purchase's own picture (info.Icon, the 4 Leaf Clover) pops up in the ring: grows in .3 s with a little overshoot, holds, shrinks away at the end
   if b.Icon then
    local t=math.min(1,b.Age/.3);local out=math.max(0,math.min(1,(b.Life-b.Age)/.3));local px=b.Scale*112*t*out*(1+.14*math.sin(t*math.pi))
    b.Icon.Size=UDim2.fromOffset(px,px)
   end
   local drag=1-math.min(1,dt*1.8)
   for _,piece in ipairs(b.Pieces)do
    piece.VY+=GRAVITY*dt;piece.VX*=drag;piece.X+=piece.VX*dt;piece.Y+=piece.VY*dt;piece.Angle+=piece.Spin*dt
    local t=b.Age/piece.Life
    if t>=1 then piece.Frame.Visible=false
    else
     piece.Frame.Position=UDim2.new(.5,piece.X,.42,piece.Y);piece.Frame.Rotation=piece.Angle
     piece.Frame.BackgroundTransparency=t<.55 and 0 or(t-.55)/.45
    end
   end
  end
 end
 if #bursts==0 then stop()end
end
-- A ring and a spray of confetti from the middle of the screen.
local function sprinkle(info)
 local gui=player:FindFirstChild('PlayerGui');if not gui then return end
 if not layer then
  local holder=Instance.new('ScreenGui');holder.Name='PurchaseCelebration';holder.ResetOnSpawn=false;holder.DisplayOrder=60;holder.IgnoreGuiInset=true
  holder.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
  local frame=Instance.new('Frame');frame.Name='Layer';frame.BackgroundTransparency=1;frame.BorderSizePixel=0;frame.Size=UDim2.fromScale(1,1);frame.Active=false;frame.Parent=holder
  holder.Parent=gui;screen=holder;layer=frame
 end
 local view=screen.AbsoluteSize;local scale=(view.X>0 and view.Y>0)and math.clamp(math.min(view.X,view.Y)/720,.55,1.3)or 1
 local count=({8,16,24})[math.clamp(tier(),1,3)]
 -- The burst is tracked before anything is added to it, so whatever got built is removed when it ends.
 local ring=Instance.new('Frame');ring.Name='Ring';ring.AnchorPoint=Vector2.new(.5,.5);ring.Position=UDim2.fromScale(.5,.42);ring.Size=UDim2.fromOffset(30*scale,30*scale)
 ring.BackgroundTransparency=1;ring.BorderSizePixel=0;ring.Parent=layer
 local burst={Age=0,Life=LIFE,Ring=ring,Pieces={},Scale=scale}
 table.insert(bursts,burst)
 if info and info.Icon=='Clover'then
  local pop=Instance.new('Frame');pop.Name='PurchaseIcon';pop.AnchorPoint=Vector2.new(.5,.5);pop.Position=UDim2.fromScale(.5,.42);pop.Size=UDim2.fromOffset(0,0);pop.BackgroundTransparency=1;pop.BorderSizePixel=0;pop.Active=false;pop.Parent=layer
  burst.Icon=pop
  pcall(function()local clover=require(RS.CloverIcon153);clover.Attach(pop);clover.Ensure()end)
 end
 if not connection then connection=Run.RenderStepped:Connect(step)end
 local round=Instance.new('UICorner');round.CornerRadius=UDim.new(1,0);round.Parent=ring
 local edge=Instance.new('UIStroke');edge.Name='Edge';edge.Color=PALETTE[1];edge.Thickness=5;edge.Parent=ring;burst.Edge=edge
 for i=1,count do
  local frame=Instance.new('Frame');frame.Name='Confetti';frame.AnchorPoint=Vector2.new(.5,.5);frame.BorderSizePixel=0
  frame.Size=UDim2.fromOffset(math.floor((6+rng:NextNumber(0,5))*scale),math.floor((9+rng:NextNumber(0,8))*scale))
  frame.BackgroundColor3=PALETTE[(i-1)%#PALETTE+1];frame.Position=UDim2.new(.5,0,.42,0);frame.Parent=layer
  local angle=rng:NextNumber(-math.pi*.95,-math.pi*.05);local speed=rng:NextNumber(260,620)*scale
  table.insert(burst.Pieces,{Frame=frame,X=0,Y=0,VX=math.cos(angle)*speed,VY=math.sin(angle)*speed,Angle=rng:NextNumber(0,360),Spin=rng:NextNumber(-620,620),Life=rng:NextNumber(.9,LIFE)})
 end
end
-- A few sparkles around the character, removed with their attachment a moment later.
local function sparkle()
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart');if not root then return end
 local at=Instance.new('Attachment');at.Name='PurchaseSparks';at.Position=Vector3.new(0,1.5,0);at.Parent=root
 local sparks=Instance.new('ParticleEmitter');sparks.Name='Sparks';sparks.Texture='rbxasset://textures/particles/sparkles_main.dds'
 sparks.Color=ColorSequence.new(PALETTE[1],PALETTE[6]);sparks.LightEmission=1;sparks.Lifetime=NumberRange.new(.6,1.1);sparks.Speed=NumberRange.new(9,18)
 sparks.SpreadAngle=Vector2.new(180,180);sparks.Size=NumberSequence.new(.7,0);sparks.Rate=0;sparks.Parent=at
 sparks:Emit(({8,14,22})[math.clamp(tier(),1,3)])
 task.delay(1.8,function()at:Destroy()end)
end
local function celebrate(info)
 if dead or type(info)~='table'or type(info.Kind)~='string'or type(info.Name)~='string'or #info.Name<1 or #info.Name>80 then return end
 local now=os.clock();if now-lastAt<GAP then return end;lastAt=now
 if Audio then pcall(Audio.Play,'GemClaim')end
 if reduced()or#bursts>=MAX_BURSTS then return end
 pcall(sprinkle,info);pcall(sparkle)
end
local listener=remote.OnClientEvent:Connect(celebrate)
script.Destroying:Connect(function()
 dead=true;listener:Disconnect()
 for _,b in ipairs(bursts)do b.Ring:Destroy();if b.Icon then b.Icon:Destroy()end;for _,piece in ipairs(b.Pieces)do piece.Frame:Destroy()end end
 table.clear(bursts);stop()
end)
