do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R39: shared snap impact, Knight catch grunt, a local hit burst and bounded camera kick.
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local GuiService=game:GetService('GuiService')
local Debris=game:GetService('Debris')
local Audio=require(RS:WaitForChild('KeeperAudio'))
local Bat=require(RS:WaitForChild('BatConfig'))
local Voices=require(RS:WaitForChild('KeeperVoices'))
local Sfx=require(RS:WaitForChild('LocalSfx'))
local KFx=require(RS:WaitForChild('KeeperFx')) -- R113: pooled ground ring + dust at a keeper hit
local Signature=require(RS:WaitForChild('KeeperSignatureStrike'))
-- R124: The Darkened's catch: its own sound and a sci-fi purple impact (pooled neon shell + beam, rings, sparks).
local VEILED={Sound='rbxassetid://119010321306307',Volume=.5,Color=Color3.fromRGB(168,92,255),Core=Color3.fromRGB(236,214,255),Seconds=.45}
local player=Players.LocalPlayer
local remotes=RS:WaitForChild('ChestChaseRemotes',20);if not remotes then return end
local remote=remotes:WaitForChild('KeeperHit',20);if not remote then return end
local ids={}
for _,key in ipairs({'Impact','KnightAlert','KnightCatch'})do local id=Audio.Asset(key);if id then table.insert(ids,id)end end
for stage,voice in pairs(Voices)do if stage~=5 then table.insert(ids,voice.Id)end end
table.insert(ids,VEILED.Sound)
Sfx.Preload(ids)
local gui=Instance.new('ScreenGui');gui.Name='KeeperImpactFeedback';gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=85;gui.Parent=player:WaitForChild('PlayerGui')
local flash=Instance.new('Frame');flash.Name='ImpactFlash';flash.Size=UDim2.fromScale(1,1);flash.BackgroundColor3=Color3.fromRGB(255,233,191);flash.BackgroundTransparency=1;flash.BorderSizePixel=0;flash.Parent=gui
local borders={}
for i,layout in ipairs({{0,0,1,.025},{0,.975,1,.025},{0,0,.016,1},{.984,0,.016,1}})do
 local f=Instance.new('Frame');f.Name='HitEdge'..i;f.Position=UDim2.fromScale(layout[1],layout[2]);f.Size=UDim2.fromScale(layout[3],layout[4]);f.BorderSizePixel=0;f.BackgroundColor3=Color3.fromRGB(209,74,55);f.BackgroundTransparency=1;f.Parent=gui;table.insert(borders,f)
end
local effects={};local lastId=0;local kick;local lastCamera,lastOffset,lastWritten
local shell,beam,veiledFx -- pooled neon parts + the live purple impact
local function reduced()
 local okay,value=pcall(function()return GuiService.ReducedMotionEnabled end)
 return okay and value==true
end
local function resetCamera()
 if lastCamera and lastCamera==workspace.CurrentCamera and lastOffset and lastCamera.CFrame==lastWritten then lastCamera.CFrame=lastCamera.CFrame*lastOffset:Inverse()end
 lastCamera,lastOffset,lastWritten=nil,nil,nil
end
local function clear()
 resetCamera();kick=nil;flash.BackgroundTransparency=1
 for _,f in ipairs(borders)do f.BackgroundTransparency=1 end
 for _,e in ipairs(effects)do e.Anchor:Destroy()end;table.clear(effects)
end
local function lowGraphics()
 if player:GetAttribute('FastMode')==true then return true end
 local ok,budget=pcall(require,RS:FindFirstChild('ClientFxBudget'));return ok and type(budget)=='table'and type(budget.Low)=='function'and budget.Low()==true
end
local function neon(name,shape)
 local p=Instance.new('Part');p.Name=name;p.Shape=shape;p.Material=Enum.Material.Neon;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
 p.Transparency=1;p.Size=Vector3.one;p.Parent=workspace;return p
end
local function veiledImpact(position)
 local ground=position-Vector3.new(0,2.8,0)
 KFx.Ring(ground,VEILED.Color,3,18,.45);KFx.Ring(ground,VEILED.Core,2,9,.3)
 KFx.Accent('Spectral',position,nil,lowGraphics())
 if lowGraphics()then return end
 shell=shell and shell.Parent and shell or neon('VeiledImpactShell',Enum.PartType.Ball);shell.Color=VEILED.Color
 beam=beam and beam.Parent and beam or neon('VeiledImpactBeam',Enum.PartType.Cylinder);beam.Color=VEILED.Core
 veiledFx={At=os.clock(),Position=position,Ground=ground}
end
local function burst(position,color)
 if #effects>=4 then table.remove(effects,1).Anchor:Destroy()end
 local anchor=Instance.new('Part');anchor.Name='KeeperHitBurst';anchor.Size=Vector3.one;anchor.CFrame=CFrame.new(position+Vector3.new(0,.6,0));anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Parent=workspace
 local billboard=Instance.new('BillboardGui');billboard.Name='ContactStar';billboard.Size=UDim2.fromScale(7,7);billboard.AlwaysOnTop=false;billboard.LightInfluence=0;billboard.Parent=anchor
 local rays={}
 for i=1,8 do
  local angle=(i-1)*math.pi/4;local ray=Instance.new('Frame');ray.Name='ImpactRay';ray.AnchorPoint=Vector2.new(.5,.5);ray.BorderSizePixel=0;ray.BackgroundColor3=color or Color3.fromRGB(255,232,172);ray.Rotation=math.deg(angle);ray.Parent=billboard;table.insert(rays,{Item=ray,Angle=angle})
 end
 table.insert(effects,{Anchor=anchor,Rays=rays,At=os.clock()});Debris:AddItem(anchor,.6)
end
local connection=remote.OnClientEvent:Connect(function(hit)
 if type(hit)~='table'or type(hit.Id)~='number'or hit.Id<=lastId or typeof(hit.Position)~='Vector3'then return end
 lastId=hit.Id
 if type(hit.At)~='number'or workspace:GetServerTimeNow()-hit.At>.75 then return end -- R123: was 2 s; a later hit would sound long after the strike (.75 still covers high ping)
 local camera=workspace.CurrentCamera;if not camera then return end
 local distance=(camera.CFrame.Position-hit.Position).Magnitude
 if distance>260 then return end
 local batHit=hit.Cause=='Bat';local veiled=hit.Veiled==true and not batHit
 -- R124: a ground-smash keeper's slam sound already played at the visual impact (KeeperFx.Slam, in range), so the
 -- generic snap is skipped there; The Darkened has its own catch sound instead of the snap and voice.
 local move=not batHit and not veiled and Signature.Moves[hit.Stage]
 local slammed=move and move.Ground and os.clock()-(KFx.SlamHeard[hit.Stage]or-math.huge)<=KFx.SlamHeardSeconds -- R150: skip the snap only when this stage's slam was really heard
 if veiled then Sfx.Play(VEILED.Sound,hit.Position,VEILED.Volume,1,4)
 else
  local snap=batHit and Bat.SlapSoundId or Audio.Asset('Impact');if snap and not slammed then Sfx.Play(snap,hit.Position,batHit and Bat.SlapVolume or Audio.ImpactVolume,1,2)end
  local voice,volume,pitch=Audio.Voice(hit.Stage,'Catch',hit.VoiceId)
  if voice then Sfx.Play(voice,hit.Position,volume,pitch,3)end
 end
 if distance<150 then
  burst(hit.Position,veiled and VEILED.Core or nil)
  if veiled then veiledImpact(hit.Position)end
  local look=not batHit and not veiled and KFx.Stages[hit.Stage]
  if look then
   local ground=hit.Position-Vector3.new(0,2.8,0)
   KFx.Ring(ground,look.Dust:Lerp(Color3.new(1,1,1),.45),3,12*math.min(1.4,look.Size),.4)
   KFx.Burst(ground,look.Dust,hit.VictimUserId==player.UserId and 10 or 6,3*look.Size)
  end
 end
 local victim=hit.VictimUserId==player.UserId
 if victim or distance<38 then kick={At=os.clock(),Strength=victim and 1 or .18*(1-distance/38),Victim=victim}end
 for _,f in ipairs(borders)do f.BackgroundColor3=veiled and VEILED.Color or Color3.fromRGB(209,74,55)end
end)
Run:BindToRenderStep('ChestChaseKeeperImpactReset',Enum.RenderPriority.Camera.Value-2,resetCamera)
local idle=false
Run:BindToRenderStep('ChestChaseKeeperImpact',Enum.RenderPriority.Camera.Value+2,function()
 resetCamera();local now=os.clock()
 -- R124: The Darkened's neon shell grows and fades, the beam thins out (pooled, hidden when done).
 if veiledFx then
  local u=(now-veiledFx.At)/VEILED.Seconds
  if u>=1 or not shell.Parent then veiledFx=nil;shell.Transparency=1;beam.Transparency=1
  else
   local e=1-(1-u)^3;shell.Size=Vector3.one*(2+9*e);shell.CFrame=CFrame.new(veiledFx.Position);shell.Transparency=.2+.8*u
   beam.Size=Vector3.new(18,1.4*(1-u)+.15,1.4*(1-u)+.15);beam.CFrame=CFrame.new(veiledFx.Ground+Vector3.new(0,9,0))*CFrame.Angles(0,0,math.pi/2);beam.Transparency=.15+.85*u
  end
 end
 -- R121: with no burst and no kick, the overlay is already clear; skip the five per-frame writes.
 if #effects==0 and not kick then
  if not idle then idle=true;flash.BackgroundTransparency=1;for _,f in ipairs(borders)do f.BackgroundTransparency=1 end end
  return
 end
 idle=false
 for i=#effects,1,-1 do
  local e=effects[i];local u=(now-e.At)/.26
  if u>=1 or not e.Anchor.Parent then e.Anchor:Destroy();table.remove(effects,i)
  else
   for _,r in ipairs(e.Rays)do
    local radius=.08+.30*u;r.Item.Position=UDim2.fromScale(.5+math.cos(r.Angle)*radius,.5+math.sin(r.Angle)*radius)
    r.Item.Size=UDim2.fromScale(.24*(1-u)+.04,.026*(1-u)+.004);r.Item.BackgroundTransparency=u*u
   end
  end
 end
 flash.BackgroundTransparency=1;for _,f in ipairs(borders)do f.BackgroundTransparency=1 end
 if not kick then return end
 local t=now-kick.At;local u=t/.25
 if u>=1 then kick=nil;return end
 local strength=kick.Strength*(1-u)^2;local quiet=reduced()
 if kick.Victim then
  flash.BackgroundTransparency=quiet and 1 or 1-.12*math.max(0,1-t/.075)
  for _,f in ipairs(borders)do f.BackgroundTransparency=1-.35*(1-u)end
 end
 local camera=workspace.CurrentCamera
 if camera and not quiet then
  local offset=CFrame.new(math.sin(t*105)*.11*strength,math.cos(t*87)*.065*strength,.06*strength)*CFrame.Angles(math.rad(.65)*strength,0,math.sin(t*94)*math.rad(.8)*strength)
  lastCamera=camera;lastOffset=offset;camera.CFrame=camera.CFrame*offset;lastWritten=camera.CFrame
 end
end)
local removing=player.CharacterRemoving:Connect(clear)
script.Destroying:Connect(function()
 clear();if shell then shell:Destroy()end;if beam then beam:Destroy()end;connection:Disconnect();removing:Disconnect();Run:UnbindFromRenderStep('ChestChaseKeeperImpactReset');Run:UnbindFromRenderStep('ChestChaseKeeperImpact');gui:Destroy()
end)
