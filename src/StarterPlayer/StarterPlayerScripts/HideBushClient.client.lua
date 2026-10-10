do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R124: hiding in the Forest / Jungle bushes (HideBushes124 on the server makes them big and walk-through).
-- The bush you stand in turns see-through for you only; other players' names are hidden while they are inside one.
-- A pack carrier's carry nameplate (CarryNameplate84) still shows: you cannot hide a stolen pack.
local Players=game:GetService('Players');local Tags=game:GetService('CollectionService');local Run=game:GetService('RunService')
local player=Players.LocalPlayer
local TAG,SEE_THROUGH,MARGIN,STEP='HideBush',.6,.4,.15
local parts={}
local function track(p)if p:IsA('BasePart')then parts[p]=true end end
for _,p in ipairs(Tags:GetTagged(TAG))do track(p)end
local conns={Tags:GetInstanceAddedSignal(TAG):Connect(track),Tags:GetInstanceRemovedSignal(TAG):Connect(function(p)parts[p]=nil end)}
local function inside(p,position)
 local rel=p.CFrame:PointToObjectSpace(position);local half=p.Size*.5
 return math.abs(rel.X)<=half.X+MARGIN and math.abs(rel.Y)<=half.Y+MARGIN and math.abs(rel.Z)<=half.Z+MARGIN
end
local function bushAt(position)
 for p in pairs(parts)do if p.Parent and inside(p,position)then return p:GetAttribute('HideBushId')end end
 return nil
end
local seeThrough=nil;local hidden={} -- Humanoid -> its DisplayDistanceType before it was hidden
local elapsed=0
table.insert(conns,Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<STEP then return end;elapsed=0
 if next(parts)==nil then return end
 local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
 local mine=root and bushAt(root.Position)or nil
 if mine~=seeThrough then
  for p in pairs(parts)do
   local id=p:GetAttribute('HideBushId')
   if id==mine then p.LocalTransparencyModifier=SEE_THROUGH elseif id==seeThrough then p.LocalTransparencyModifier=0 end
  end
  seeThrough=mine
 end
 for _,other in ipairs(Players:GetPlayers())do
  local c=other~=player and other.Character;local h=c and c:FindFirstChildOfClass('Humanoid')
  if h then
   local r=c:FindFirstChild('HumanoidRootPart');local inBush=r~=nil and bushAt(r.Position)~=nil
   if inBush and hidden[h]==nil then hidden[h]=h.DisplayDistanceType;h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
   elseif not inBush and hidden[h]~=nil then h.DisplayDistanceType=hidden[h];hidden[h]=nil end
  end
 end
 for h in pairs(hidden)do if not h.Parent then hidden[h]=nil end end
end))
script.Destroying:Connect(function()
 for _,c in ipairs(conns)do c:Disconnect()end
 for h,v in pairs(hidden)do if h.Parent then h.DisplayDistanceType=v end end
 for p in pairs(parts)do p.LocalTransparencyModifier=0 end
end)
