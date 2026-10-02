-- R124 performance: the server's always-on biome particle emitters (BiomeVisuals: WindblownSnow, CinderSmoke,
-- RisingEmbers, PrismMotes, CrystalDust; attribute BiomeEffect) follow the shared client budget, locally only:
--  tier 3: as built | tier 2 or ReducedMotion: half rate | tier 1 / FastMode: off | farther than FarStuds from the
--  camera (to the emitter's part box): off. Only Rate is written (never Enabled), once a second, and only on change.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local Budget=require(RS:WaitForChild('ClientFxBudget'))
local map=workspace:WaitForChild('ChestChaseMap')
local G={FarStuds=320,Step=1}
local emitters={} -- ParticleEmitter -> its built Rate
local function track(e)
 if e:IsA('ParticleEmitter')and emitters[e]==nil and e:GetAttribute('BiomeEffect')==true then emitters[e]=e.Rate end
end
for _,d in ipairs(map:GetDescendants())do track(d)end
local conns={map.DescendantAdded:Connect(track),map.DescendantRemoving:Connect(function(d)emitters[d]=nil end)}
-- Distance from the camera to where the emitter emits: an attachment's point, or the nearest point of its part.
local function distance(e,camera)
 local p=e.Parent
 if p and p:IsA('Attachment')then return(p.WorldPosition-camera).Magnitude end
 if p and p:IsA('BasePart')then
  local rel=p.CFrame:PointToObjectSpace(camera);local h=p.Size*.5
  local clamped=Vector3.new(math.clamp(rel.X,-h.X,h.X),math.clamp(rel.Y,-h.Y,h.Y),math.clamp(rel.Z,-h.Z,h.Z))
  return(rel-clamped).Magnitude
 end
 return 0
end
function G.Rate(base,tier,far,reduced)
 if tier<=1 or far then return 0 end
 return(tier==2 or reduced)and base*.5 or base
end
local elapsed=G.Step
table.insert(conns,Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<G.Step then return end;elapsed=0
 local cam=workspace.CurrentCamera;if not cam then return end
 local camera=cam.CFrame.Position;local tier=Budget.Get();local reduced=Gui.ReducedMotionEnabled==true
 for e,base in pairs(emitters)do
  if e.Parent then
   local rate=G.Rate(base,tier,distance(e,camera)>G.FarStuds,reduced)
   if e.Rate~=rate then e.Rate=rate end
  else emitters[e]=nil end
 end
end))
script.Destroying:Connect(function()
 for _,c in ipairs(conns)do c:Disconnect()end
 for e,base in pairs(emitters)do if e.Parent then e.Rate=base end end
end)
