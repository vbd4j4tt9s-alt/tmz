do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- Giant geometry stays at its authored dimensions. Close surfaces fade locally;
-- bounded work keeps the safety pass independent of the number of world parts.
local Collection=game:GetService('CollectionService');local Run=game:GetService('RunService');local Players=game:GetService('Players')
local player=Players.LocalPlayer;player.CameraMaxZoomDistance=100
local parts={};local indices={};local cursor=1
local function add(p)if p:IsA('BasePart')and not indices[p]then table.insert(parts,p);indices[p]=#parts end end
local function remove(p)local i=indices[p];if not i then return end;local last=table.remove(parts);indices[p]=nil;if i<=#parts then parts[i]=last;indices[last]=i end end
for _,p in ipairs(Collection:GetTagged('GiantVisualPart'))do add(p)end
Collection:GetInstanceAddedSignal('GiantVisualPart'):Connect(add);Collection:GetInstanceRemovedSignal('GiantVisualPart'):Connect(remove)
local elapsed=0
Run:BindToRenderStep('GiantVisualSafety',Enum.RenderPriority.Camera.Value+4,function(dt)
 elapsed+=dt;if elapsed<.06 then return end;elapsed=0;local camera=workspace.CurrentCamera;if not camera then return end
 for _=1,math.min(320,#parts)do
  if cursor>#parts then cursor=1 end;local p=parts[cursor];cursor+=1
  if p and p:IsDescendantOf(workspace)then
   local pos=p.CFrame:PointToObjectSpace(camera.CFrame.Position);local h=p.Size*.5
   local gap=Vector3.new(math.max(0,math.abs(pos.X)-h.X),math.max(0,math.abs(pos.Y)-h.Y),math.max(0,math.abs(pos.Z)-h.Z)).Magnitude
   local fade=gap<9 and .92*(1-gap/9)or 0
   local previous=p:GetAttribute('GiantSafetyFade')or 0
   -- R113: skip the two writes when nothing changed (almost every far part, every pass).
   if fade~=previous or math.abs(p.LocalTransparencyModifier-fade)>.001 then
    -- Respect opening/LOD invisibility written by their owning renderer.
    if p.LocalTransparencyModifier<=previous+.001 then p.LocalTransparencyModifier=fade end
    -- R147: a Decal (the Verity pack's picture) ignores its part's modifier, so it fades the same way (and stays hidden while an opening hides it).
    for _,d in ipairs(p:GetChildren())do if d:IsA('Decal')and d.LocalTransparencyModifier<=previous+.001 then d.LocalTransparencyModifier=fade end end
    p:SetAttribute('GiantSafetyFade',fade)
   end
  end
 end
end)
script.Destroying:Connect(function()Run:UnbindFromRenderStep('GiantVisualSafety');for _,p in ipairs(parts)do if p.Parent and p.LocalTransparencyModifier==(p:GetAttribute('GiantSafetyFade')or 0)then p.LocalTransparencyModifier=0;for _,d in ipairs(p:GetChildren())do if d:IsA('Decal')and d.LocalTransparencyModifier==(p:GetAttribute('GiantSafetyFade')or 0)then d.LocalTransparencyModifier=0 end end end end end)
