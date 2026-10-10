-- R158 bats (docs/proposals/R158/bats/animation.md 4, owner-approved): the hit effects, made once and reused. Client only.
--  * Star(position, color): the 8-ray contact star KeeperHitEffects showed at every keeper / bat hit (same look and timing), now from a pool of
--    PoolSize made on first use (it was a new Part + BillboardGui + 8 Frames per hit). When all are busy the oldest is reused.
--  * Sparks(position): one shared ParticleEmitter (Emit(SparkCount)) for a bat hit; off in Fast Mode / low graphics.
--  * NoteOwnHit / IsOwnHit: the hitter's client shows its own hit at once (BatClient: the slap, the star, the sparks). The server's packet for that
--    hit arrives a moment later; KeeperHitEffects then skips it on the hitter's screen (no second slap or star, and no camera shake for the hitter).
-- Nothing is created per frame: the stars are animated by one RenderStepped connection (made with the first star) that returns at once when idle.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local Fx={PoolSize=4,StarSeconds=.26,RayColor=Color3.fromRGB(255,232,172),SparkCount=10,OwnHitSeconds=1.5}
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local stars={};local live=0;local connection
local sparkPart,sparkEmitter
local own={}
function Fx.Low()
 local player=Players.LocalPlayer
 if player and player:GetAttribute('FastMode')==true then return true end
 local ok,budget=pcall(require,RS:FindFirstChild('ClientFxBudget'));return ok and type(budget)=='table'and type(budget.Low)=='function'and budget.Low()==true
end
local function makeStar()
 local anchor=Instance.new('Part');anchor.Name='KeeperHitBurst';anchor.Size=Vector3.one;anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false
 anchor.CanQuery=false;anchor.CanTouch=false;anchor.CastShadow=false
 local billboard=Instance.new('BillboardGui');billboard.Name='ContactStar';billboard.Size=UDim2.fromScale(7,7);billboard.AlwaysOnTop=false;billboard.LightInfluence=0
 billboard.Enabled=false;billboard.Parent=anchor
 local rays={}
 for i=1,8 do
  local angle=(i-1)*math.pi/4;local ray=Instance.new('Frame');ray.Name='ImpactRay';ray.AnchorPoint=Vector2.new(.5,.5);ray.BorderSizePixel=0
  ray.BackgroundColor3=Fx.RayColor;ray.Rotation=math.deg(angle);ray.Parent=billboard;rays[i]={Item=ray,Cos=math.cos(angle),Sin=math.sin(angle)}
 end
 anchor.Parent=workspace
 return {Anchor=anchor,Billboard=billboard,Rays=rays,At=nil}
end
local function hide(s)if s.At then s.At=nil;live-=1 end;s.Billboard.Enabled=false end
-- one frame of every live star (today's KeeperHitEffects animation: the rays fly out, thin and fade over StarSeconds)
function Fx.Step()
 if live==0 then return end
 local now=os.clock()
 for _,s in ipairs(stars)do if s.At then
  local u=(now-s.At)/Fx.StarSeconds
  if u>=1 then hide(s)
  else
   local radius=.08+.30*u;local w,h=.24*(1-u)+.04,.026*(1-u)+.004;local fade=u*u
   for _,r in ipairs(s.Rays)do
    r.Item.Position=UDim2.fromScale(.5+r.Cos*radius,.5+r.Sin*radius);r.Item.Size=UDim2.fromScale(w,h);r.Item.BackgroundTransparency=fade
   end
  end
 end end
end
function Fx.Star(position,color)
 if typeof(position)~='Vector3'then return nil end
 local pick
 for i,s in ipairs(stars)do
  if not s.Anchor.Parent then if s.At then live-=1 end;s=makeStar();stars[i]=s end -- (removed by something else: made again, once)
  if not s.At then pick=s;break end
 end
 if not pick and #stars<Fx.PoolSize then pick=makeStar();table.insert(stars,pick)end
 if not pick then for _,s in ipairs(stars)do if not pick or s.At<pick.At then pick=s end end end -- all busy: the oldest
 if not connection then connection=Run.RenderStepped:Connect(Fx.Step)end
 if not pick.At then live+=1 end
 pick.At=os.clock();pick.Anchor.CFrame=CFrame.new(position+Vector3.new(0,.6,0))
 local tint=color or Fx.RayColor
 for _,r in ipairs(pick.Rays)do
  r.Item.BackgroundColor3=tint;r.Item.BackgroundTransparency=0;r.Item.Position=UDim2.fromScale(.5+r.Cos*.08,.5+r.Sin*.08);r.Item.Size=UDim2.fromScale(.28,.03)
 end
 pick.Billboard.Enabled=true
 return pick
end
function Fx.Sparks(position)
 if typeof(position)~='Vector3'or Fx.Low()then return false end
 if not sparkPart or not sparkPart.Parent then
  sparkPart=Instance.new('Part');sparkPart.Name='BatHitSparks';sparkPart.Size=Vector3.new(.2,.2,.2);sparkPart.Transparency=1;sparkPart.Anchored=true
  sparkPart.CanCollide=false;sparkPart.CanQuery=false;sparkPart.CanTouch=false;sparkPart.CastShadow=false
  sparkEmitter=Instance.new('ParticleEmitter');sparkEmitter.Name='Sparks';sparkEmitter.Texture=SPARK;sparkEmitter.Enabled=false;sparkEmitter.Rate=0
  sparkEmitter.Color=ColorSequence.new(Color3.fromRGB(255,246,214),Color3.fromRGB(255,190,90));sparkEmitter.LightEmission=1;sparkEmitter.LightInfluence=0
  sparkEmitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,0)});sparkEmitter.Lifetime=NumberRange.new(.15,.25)
  sparkEmitter.Speed=NumberRange.new(16,28);sparkEmitter.SpreadAngle=Vector2.new(180,180);sparkEmitter.Drag=6;sparkEmitter.Parent=sparkPart
  sparkPart.Parent=workspace
 end
 sparkPart.CFrame=CFrame.new(position+Vector3.new(0,.6,0));sparkEmitter:Emit(Fx.SparkCount)
 return true
end
function Fx.NoteOwnHit(userId)if type(userId)=='number'then own[userId]=os.clock()end end
function Fx.IsOwnHit(userId)local at=type(userId)=='number'and own[userId];return at~=nil and at~=false and os.clock()-at<=Fx.OwnHitSeconds end
function Fx.Clear()for _,s in ipairs(stars)do hide(s)end end
return Fx
