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
local player=Players.LocalPlayer
local remotes=RS:WaitForChild('ChestChaseRemotes',20);if not remotes then return end
local remote=remotes:WaitForChild('KeeperHit',20);if not remote then return end
local ids={}
for _,key in ipairs({'Impact','KnightAlert','KnightCatch'})do local id=Audio.Asset(key);if id then table.insert(ids,id)end end
for stage,voice in pairs(Voices)do if stage~=5 then table.insert(ids,voice.Id)end end
Sfx.Preload(ids)
local gui=Instance.new('ScreenGui');gui.Name='KeeperImpactFeedback';gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=85;gui.Parent=player:WaitForChild('PlayerGui')
local flash=Instance.new('Frame');flash.Name='ImpactFlash';flash.Size=UDim2.fromScale(1,1);flash.BackgroundColor3=Color3.fromRGB(255,233,191);flash.BackgroundTransparency=1;flash.BorderSizePixel=0;flash.Parent=gui
local borders={}
for i,layout in ipairs({{0,0,1,.025},{0,.975,1,.025},{0,0,.016,1},{.984,0,.016,1}})do
 local f=Instance.new('Frame');f.Name='HitEdge'..i;f.Position=UDim2.fromScale(layout[1],layout[2]);f.Size=UDim2.fromScale(layout[3],layout[4]);f.BorderSizePixel=0;f.BackgroundColor3=Color3.fromRGB(209,74,55);f.BackgroundTransparency=1;f.Parent=gui;table.insert(borders,f)
end
local effects={};local lastId=0;local kick;local lastCamera,lastOffset,lastWritten
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
local function burst(position)
 if #effects>=4 then table.remove(effects,1).Anchor:Destroy()end
 local anchor=Instance.new('Part');anchor.Name='KeeperHitBurst';anchor.Size=Vector3.one;anchor.CFrame=CFrame.new(position+Vector3.new(0,.6,0));anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Parent=workspace
 local billboard=Instance.new('BillboardGui');billboard.Name='ContactStar';billboard.Size=UDim2.fromScale(7,7);billboard.AlwaysOnTop=false;billboard.LightInfluence=0;billboard.Parent=anchor
 local rays={}
 for i=1,8 do
  local angle=(i-1)*math.pi/4;local ray=Instance.new('Frame');ray.Name='ImpactRay';ray.AnchorPoint=Vector2.new(.5,.5);ray.BorderSizePixel=0;ray.BackgroundColor3=Color3.fromRGB(255,232,172);ray.Rotation=math.deg(angle);ray.Parent=billboard;table.insert(rays,{Item=ray,Angle=angle})
 end
 table.insert(effects,{Anchor=anchor,Rays=rays,At=os.clock()});Debris:AddItem(anchor,.6)
end
local connection=remote.OnClientEvent:Connect(function(hit)
 if type(hit)~='table'or type(hit.Id)~='number'or hit.Id<=lastId or typeof(hit.Position)~='Vector3'then return end
 lastId=hit.Id
 if type(hit.At)~='number'or workspace:GetServerTimeNow()-hit.At>2 then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local distance=(camera.CFrame.Position-hit.Position).Magnitude
 if distance>260 then return end
 local batHit=hit.Cause=='Bat'
 local snap=batHit and Bat.SlapSoundId or Audio.Asset('Impact');if snap then Sfx.Play(snap,hit.Position,batHit and Bat.SlapVolume or Audio.ImpactVolume,1,2)end
 local voice,volume,pitch=Audio.Voice(hit.Stage,'Catch',hit.VoiceId)
 if voice then Sfx.Play(voice,hit.Position,volume,pitch,3)end
 if distance<150 then
  burst(hit.Position)
  local look=not batHit and KFx.Stages[hit.Stage]
  if look then
   local ground=hit.Position-Vector3.new(0,2.8,0)
   KFx.Ring(ground,look.Dust:Lerp(Color3.new(1,1,1),.45),3,12*math.min(1.4,look.Size),.4)
   KFx.Burst(ground,look.Dust,hit.VictimUserId==player.UserId and 10 or 6,3*look.Size)
  end
 end
 local victim=hit.VictimUserId==player.UserId
 if victim or distance<38 then kick={At=os.clock(),Strength=victim and 1 or .18*(1-distance/38),Victim=victim}end
end)
Run:BindToRenderStep('ChestChaseKeeperImpactReset',Enum.RenderPriority.Camera.Value-2,resetCamera)
Run:BindToRenderStep('ChestChaseKeeperImpact',Enum.RenderPriority.Camera.Value+2,function()
 resetCamera();local now=os.clock()
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
 clear();connection:Disconnect();removing:Disconnect();Run:UnbindFromRenderStep('ChestChaseKeeperImpactReset');Run:UnbindFromRenderStep('ChestChaseKeeperImpact');gui:Destroy()
end)
