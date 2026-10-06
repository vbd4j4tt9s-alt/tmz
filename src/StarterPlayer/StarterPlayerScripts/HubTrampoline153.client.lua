do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R153 hub trampolines, client (the server's HubTrampoline153 builds them: a low round trampoline in each garden nook). Owner: "just add a trampoline
-- that boosts players up by a bit". Client-predicted, like the rest of the game's movement (RunnerController owns the horizontal speed of the local
-- character and keeps its vertical one): when the local character's feet land on, or step onto, a mat, this script SETS the vertical speed of its
-- own HumanoidRootPart so the feet rise HubTrampolineRules153.Height() studs (30). Never added to: standing there bounces at the same height every
-- time, a rising body (a bounce, a jump) is left alone, and a player bounces at most once per Cooldown (.45 s). MovementGuard's rise allowance
-- (25 studs per .1 s sample) covers it (test). Everyone's client also squashes the mat and plays the boing when ANY player lands (from the
-- replicated positions: cosmetic only, nothing is applied to another player). The sound is InteractionAudio's existing bubble pop pitched down.
-- Per frame: two squared distances to the nooks (the rest only within 60 studs of one); twice a second: is the server's folder still the one we know. Reduced Motion: no squash.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local GuiService=game:GetService('GuiService')
local T=require(RS:WaitForChild('HubTrampolineRules153'))
local Sfx=require(RS:WaitForChild('LocalSfx'))
local player=Players.LocalPlayer
local map=workspace:WaitForChild('ChestChaseMap')
local V=Vector3.new
local BOING={Id='rbxassetid://96764044228884',Volume=.34,Pitch=.8} -- (InteractionAudio.AssetIds.Bubble04, an existing asset; pitched down it boings)
local NEAR=60;local COARSE=.5

local spots={}                                     -- {X, Z, Mat, Badge, MatCF, BadgeCF, At, Want} (Mat / Badge may be missing: a look from the store whose mat cannot be told does not squash)
local active={}                                    -- spots that are squashing
local states=setmetatable({},{__mode='k'})         -- HumanoidRootPart -> debounce state
local connections={}
local seen,seenCount,seenLooks,elapsed,render,preloaded
local function reduced()local ok,v=pcall(function()return GuiService.ReducedMotionEnabled end);return ok and v==true end

-- The server's trampolines: found now and whenever the folder is replaced (HubDecor151 rebuilds it) or re-dressed (the owner's asset arrived) ---------
local function collect()
 table.clear(spots);table.clear(active)
 local folder=map:FindFirstChild(T.FolderName)
 if not folder then return end
 for _,m in ipairs(folder:GetChildren())do
  local x,z=m:GetAttribute('CenterX'),m:GetAttribute('CenterZ')
  local mat,badge=m:FindFirstChild('Trampoline mat',true),m:FindFirstChild('Trampoline badge',true)
  if type(x)=='number'and type(z)=='number'then -- (the bounce needs only the spot; the squash needs the mat)
   spots[#spots+1]={X=x,Z=z,Mat=mat,Badge=badge,MatCF=mat and mat.CFrame,BadgeCF=badge and badge.CFrame,At=-math.huge,Want=m:GetAttribute('HasMat')==true}
  end
 end
end
local function refresh() -- (twice a second) the server's folder, found again when it is replaced or dressed; a mat still on its way is waited for
 local folder=map:FindFirstChild(T.FolderName);local count=folder and #folder:GetChildren()or 0;local looks=folder and folder:GetAttribute('Looks')or 0
 local stale=folder~=seen or count~=seenCount or looks~=seenLooks
 if not stale then for _,s in ipairs(spots)do if(s.Want and not s.Mat)or(s.Mat and not s.Mat:IsDescendantOf(folder))then stale=true;break end end end
 if stale then seen,seenCount,seenLooks=folder,count,looks;collect()end
end

-- The squash: the mat (and its badge, when it has one) dips and rebounds (T.Squash), only while one is moving ------------------------------------------
local function squashStep()
 local now=os.clock();local any=false
 for i=#active,1,-1 do
  local s=active[i];local t=now-s.At
  if t>=T.SquashSeconds or not s.Mat then
   if s.Mat then s.Mat.CFrame=s.MatCF end;if s.Badge then s.Badge.CFrame=s.BadgeCF end;table.remove(active,i)
  else
   any=true;local off=V(0,-T.SquashDepth*T.Squash(t),0)
   s.Mat.CFrame=s.MatCF+off;if s.Badge then s.Badge.CFrame=s.BadgeCF+off end
  end
 end
 if not any and render then render:Disconnect();render=nil end
end
local function squash(s)
 if reduced()or not s.Mat then return end
 s.At=os.clock()
 if not table.find(active,s)then table.insert(active,s)end
 if not render then render=Run.RenderStepped:Connect(squashStep)end
end
local function boing(s)return Sfx.Play(BOING.Id,V(s.X,T.Top(),s.Z),BOING.Volume,BOING.Pitch,2)end

-- The bounce ----------------------------------------------------------------------------------------------------------------------------------
local function feetY(char,root,hum)
 local leg=hum.RigType==Enum.HumanoidRigType.R6 and char:FindFirstChild('Left Leg')
 return T.FeetY(root.Position.Y,root.Size.Y,hum.HipHeight,leg and leg.Size.Y or 0)
end
-- One character against every nook; `mine` characters get the launch, every character gets the squash and the boing.
local function body(plr,mine)
 local char=plr.Character;local root=char and char:FindFirstChild('HumanoidRootPart');local hum=char and char:FindFirstChildOfClass('Humanoid')
 if not root or not hum or hum.Health<=0 or root.Anchored or hum.Sit or hum.PlatformStand then return end
 if plr:GetAttribute('GuardianRagdollActive')or plr:GetAttribute('GuardianFlingActive')then return end
 local pos=root.Position
 for _,s in ipairs(spots)do
  local dx,dz=pos.X-s.X,pos.Z-s.Z
  if dx*dx+dz*dz<=(T.Dims.Radius+3)^2 then
   local st=states[root];if not st then st=T.NewState();states[root]=st end
   local v=root.AssemblyLinearVelocity
   local up=T.Step(st,os.clock(),dx,dz,feetY(char,root,hum),v.Y,workspace.Gravity)
   if up then
    if mine then
     root.AssemblyLinearVelocity=T.Launch(v,up)
     pcall(hum.ChangeState,hum,Enum.HumanoidStateType.Freefall)
    end
    squash(s);boing(s)
   end
  end
 end
end
local function near(plr)
 local char=plr.Character;local root=char and char:FindFirstChild('HumanoidRootPart');if not root then return false end
 local p=root.Position
 for _,s in ipairs(spots)do local dx,dz=p.X-s.X,p.Z-s.Z;if dx*dx+dz*dz<=NEAR*NEAR then return true end end
 return false
end
local function step()
 if #spots==0 or not near(player)then return end
 body(player,true)
 for _,other in ipairs(Players:GetPlayers())do if other~=player then body(other,false)end end
end
local function coarse(dt)
 elapsed+=dt
 if elapsed<COARSE then return end
 elapsed=0;refresh()
 if not preloaded and #spots>0 and near(player)then preloaded=true;Sfx.Preload({BOING.Id})end
end
elapsed=COARSE
connections[#connections+1]=Run.Heartbeat:Connect(coarse)
connections[#connections+1]=Run.PreSimulation:Connect(step)
script.Destroying:Connect(function()
 for _,c in ipairs(connections)do c:Disconnect()end
 if render then render:Disconnect()end
 for _,s in ipairs(spots)do if s.Mat then s.Mat.CFrame=s.MatCF end;if s.Badge then s.Badge.CFrame=s.BadgeCF end end
end)
script:SetAttribute('R153Loaded',true)
-- (the offline tests set R153TestHook on the script to drive it; in the game nothing is returned)
if script:GetAttribute('R153TestHook')then
 return{Spots=spots,States=states,Step=step,Coarse=coarse,Body=body,Collect=collect,Active=active,Boing=BOING}
end
