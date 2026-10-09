do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R156: the client half of the Desert's secret pyramid (the numbers: ReplicatedStorage.PyramidRules156; the pyramid, the prompt and every rule: the server's
-- SecretPyramid156). Everything here is for THIS player only:
--  * the floating pack: the Desert Mythic pack, built here (not by the server) the way the game builds a pack (SeedPackVisuals.Bag: the same pouch, print and
--    pack effects as a Desert Mythic world pack; SeedPackRender gives it the pack look it gives a held pack), at the invisible part the server tagged
--    PyramidRules156.Tag, only while YOUR state (the Player attribute PyramidRules156.Attr) is 'Open' and the camera is within Client.BuildIn studs (it goes
--    past BuildOut). 'Out' (you carry it) or 'Claimed' (it is in your Bag): no pack in your pyramid. Other players see their own.
--  * the turn and the bob: the pack hangs on one invisible anchored hub part by one Weld. The hub bobs (one looping tween) and the weld's C0 turns it a third
--    of a turn per tween (three tweens, each starting the next when it ends). They are made ONCE per pack: no script runs per frame for them and nothing is made
--    per frame; the engine moves one part and one weld. They exist only while the pack does (near the pyramid). Reduced Motion: the pack stands still.
--  * the prompt: the server's "Hold E" (RequiresLineOfSight off, so it shows through the walls) is turned off for you unless your state is 'Open' and your body
--    is inside the pyramid's zone (PyramidRules156.InZone with the zone the server wrote on the anchor): next to the base, on the steps, inside. Five checks a
--    second, only while the pyramid has streamed in. The server checks every trigger again.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local Tween=game:GetService('TweenService');local GuiService=game:GetService('GuiService')
local Rules=require(RS:WaitForChild('PyramidRules156'))
local player=Players.LocalPlayer
local C=Rules.Client
local entries={};local count=0;local folder;local beat;local acc=0
local function packFolder()
 if folder and folder.Parent then return folder end
 folder=Instance.new('Folder');folder.Name='SecretPyramidPack156';folder.Parent=workspace;return folder
end
local function reduced()return GuiService.ReducedMotionEnabled==true end
local function state()return player:GetAttribute(Rules.Attr)end
local function stopMotion(e)
 for _,t in ipairs(e.Tweens or{})do t:Cancel()end
 if e.Hub and e.Hub.Parent and e.At then e.Hub.CFrame=e.At end
 if e.Weld and e.Weld.Parent then e.Weld.C0=CFrame.new()end
end
local function startMotion(e)
 stopMotion(e)
 if reduced()or not e.Tweens then return end
 e.Hub.CFrame=e.At*CFrame.new(0,-Rules.Spin.Bob,0)
 e.Tweens[1]:Play();e.Tweens[4]:Play()
end
local function dropPack(e)
 for _,t in ipairs(e.Tweens or{})do t:Cancel()end
 if e.Pack then e.Pack:Destroy()end
 if e.Hub then e.Hub:Destroy()end
 e.Pack,e.Hub,e.Weld,e.Tweens=nil,nil,nil,nil
end
local function buildPack(e)
 if e.Pack then return end
 local at=CFrame.new(e.Zone.Pack);e.At=at
 local ok,err=pcall(function()
  local Visuals=require(RS:WaitForChild('SeedPackVisuals'));local PackRules=require(RS:WaitForChild('SeedPackRules'))
  local p=Rules.Pack
  -- the hub: unanchored while the bag is welded to it (SeedPackVisuals welds a bag built on a weld root), anchored right after
  local hub=Instance.new('Part');hub.Name='SecretPackHub156';hub.Size=Vector3.new(.2,.2,.2);hub.Transparency=1;hub.Anchored=false;hub.Massless=true
  hub.CanCollide=false;hub.CanTouch=false;hub.CanQuery=false;hub.CastShadow=false;hub.CFrame=at;hub.Parent=packFolder()
  e.Hub=hub
  local bag=Visuals.Bag(at,packFolder(),1,hub,p.Stage,p.BagVariant,PackRules.NewSeedScale(p.Stage,p.BagVariant,p.PackSize),p.PackSize,Rules.Mutation)
  hub.Anchored=true
  bag.Name='SecretPyramidPack';bag:SetAttribute('SecretPyramid156',true);e.Pack=bag
  -- the bag's root hangs on the hub by a Weld (in place of its WeldConstraint) whose C0 turns
  local root=bag.PrimaryPart
  for _,d in ipairs(root:GetChildren())do if d:IsA('WeldConstraint')and(d.Part0==hub or d.Part1==hub)then d:Destroy()end end
  local weld=Instance.new('Weld');weld.Name='SpinWeld156';weld.Part0=hub;weld.Part1=root;weld.C0=CFrame.new();weld.C1=CFrame.new();weld.Parent=hub
  e.Weld=weld
  local third=TweenInfo.new(Rules.Spin.Period/3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut)
  local tweens={}
  for i=1,3 do tweens[i]=Tween:Create(weld,third,{C0=CFrame.Angles(0,i*2*math.pi/3,0)})end
  for i=1,3 do
   local nextOne=tweens[i%3+1]
   tweens[i].Completed:Connect(function(status)if status==Enum.PlaybackState.Completed and e.Weld==weld then nextOne:Play()end end)
  end
  tweens[4]=Tween:Create(hub,TweenInfo.new(Rules.Spin.BobPeriod/2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{CFrame=at*CFrame.new(0,Rules.Spin.Bob,0)})
  e.Tweens=tweens
  startMotion(e)
 end)
 if not ok then warn('[R156] The secret pyramid pack could not be built: '..tostring(err));dropPack(e)end
end
local function update(e)
 local anchor=e.Anchor
 if not anchor.Parent then return end
 e.Zone=e.Zone or Rules.ReadZone(anchor);if not e.Zone then return end
 local open=state()==Rules.State.Open
 local camera=workspace.CurrentCamera;local view=camera and camera.CFrame.Position
 local dist=view and(view-e.Zone.Pack).Magnitude or math.huge
 if open and not e.Pack and dist<=C.BuildIn then buildPack(e)
 elseif e.Pack and(not open or dist>C.BuildOut)then dropPack(e)end
 local prompt=anchor:FindFirstChild('Steal')
 if prompt and prompt:IsA('ProximityPrompt')then
  local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
  local want=open and root~=nil and(Rules.InZone(e.Zone,root.Position,0))==true
  if prompt.Enabled~=want then prompt.Enabled=want end
 end
end
local function refreshAll()for _,e in pairs(entries)do local ok,err=pcall(update,e);if not ok then warn('[R156] Secret pyramid: '..tostring(err))end end end
-- Five checks a second, connected only while a pyramid anchor is here (it streams in with the pyramid).
local function tick(dt)
 acc+=dt
 if acc<C.Check then return end
 acc=0;refreshAll()
end
local function track(anchor)
 if entries[anchor]or not anchor:IsA('BasePart')then return end
 entries[anchor]={Anchor=anchor,Zone=Rules.ReadZone(anchor)};count+=1
 if not beat then beat=Run.Heartbeat:Connect(tick)end
 pcall(update,entries[anchor])
end
local function forget(anchor)
 local e=entries[anchor];if not e then return end
 dropPack(e);entries[anchor]=nil;count-=1
 if count<=0 and beat then beat:Disconnect();beat=nil;acc=0 end
end
for _,anchor in ipairs(CS:GetTagged(Rules.Tag))do track(anchor)end
CS:GetInstanceAddedSignal(Rules.Tag):Connect(track)
CS:GetInstanceRemovedSignal(Rules.Tag):Connect(forget)
player:GetAttributeChangedSignal(Rules.Attr):Connect(refreshAll)
GuiService:GetPropertyChangedSignal('ReducedMotionEnabled'):Connect(function()for _,e in pairs(entries)do if e.Pack then startMotion(e)end end end)
