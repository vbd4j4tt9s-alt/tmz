-- V0.87: concurrent seed carriers; one locked FIFO target per biome keeper.
-- Reuses the existing keeper models, speed tuning, ragdoll and presentation helpers.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RagdollService=require(script.Parent.RagdollService)
local PackRules=require(game:GetService("ReplicatedStorage"):WaitForChild("SeedPackRules"))
local Combat=require(game:GetService('ReplicatedStorage'):WaitForChild('KeeperCombat'))
local Contact=require(script.Parent.KeeperContact)
local Dash=require(game:GetService('ReplicatedStorage'):WaitForChild('KeeperRecoveryDash'))
local StormConfig=require(game:GetService('ReplicatedStorage'):WaitForChild('StormConfig'))
local Knockback=require(game:GetService('ReplicatedStorage'):WaitForChild('KnockbackConfig'))
local BatService=require(script.Parent.BatService)
-- V090: only the root moves on the server; cosmetic parts follow locally.
local function pivotKeeper(model, frame)
    if (model:GetAttribute("GardenerArtVersion") == 91 or model:GetAttribute("KeeperClientAnimated") == true) and model.PrimaryPart then
        model.PrimaryPart.CFrame = frame
    else model:PivotTo(frame) end
end


return function(Legacy)
    local Service = setmetatable({}, {__index = Legacy})
    Service.__index = Service

    function Service.new(...)
        local self = setmetatable(Legacy.new(...), Service)
        self.Runs = {}
        self.KeeperTargets = {}
        self.KeeperQueues = {}
        self.Drops = {}
        self.Advancing = {}
        self.Starting = {}
        self.Connections = {}
        self.KnownSeeds = {}
        self.Ragdoll=RagdollService.new(self.Config,function(player,humanoid)self:_restorePhysicalSpeed(player,humanoid)end)
        self.HitSerial=0
        self.AttackSerial=0
        local folder=self.RunAlertRemote.Parent
        local remote=folder:FindFirstChild('KeeperHit')
        if not remote then remote=Instance.new('RemoteEvent');remote.Name='KeeperHit';remote.Parent=folder end
        assert(remote:IsA('RemoteEvent'),'KeeperHit must be a RemoteEvent')
        self.HitRemote=remote
        local taken=folder:FindFirstChild('PackTaken')or Instance.new('RemoteEvent');taken.Name='PackTaken';taken.Parent=folder;self.PackTaken=taken
        for _, seed in ipairs(self.Map.Chests) do self.KnownSeeds[seed] = true end
        return self
    end

    function Service:IsPlayerBusy(player)
        return self.Runs[player] ~= nil or self.Starting[player] == true or self.Chests:IsOpening(player)
    end

    function Service:_validCharacter(player)
        if not player or not player.Parent then return nil end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then return nil end
        return character, humanoid, root
    end

    function Service:_canTake(player, position)
        if not require(script.Parent.SecurityGate).Allow(player,'TakePack')or not require(script.Parent.MovementGuard).Check(player)then return nil end
        if self.Map.Refreshing or self:IsPlayerBusy(player) or player:GetAttribute("GuardianRagdollActive")
            or player:GetAttribute("GuardianFlingActive") then return nil end
        local character, humanoid, root = self:_validCharacter(player)
        if not character or root.Anchored or humanoid.PlatformStand
            or (root.Position - position).Magnitude > 26 then return nil end
        if not self.PlayerData:IsLoaded(player) or not self.Bases:GetPlayerBase(player) then return nil end
        local canReceive, reason = self.PlayerData:CanReceiveSeed(player)
        if not canReceive then
            self.Notifications:Show(player, reason or "SEED INVENTORY FULL", Color3.fromRGB(255,187,91), 3)
            return nil
        end
        return character, humanoid, root
    end

    function Service:_startTarget(run, existing)
        local stage = run.Stage
        local key=run.KeeperKey or stage
        assert(not self.KeeperTargets[key], "Keeper target cannot be stolen by a later pickup")
        local returning = self.ReturningGuardians[stage]
        local guardian
        if run.Chest.EventKeeper then guardian=self.Event81:EnsureGuardian()
        else guardian=existing or (returning and returning.Guardian)or self.Map.GuardiansByStage[stage]end
        if not run.Chest.EventKeeper then self.ReturningGuardians[stage] = nil end
        if not guardian or not guardian.Parent or not guardian.PrimaryPart then
            if run.Chest.EventKeeper then self:Finish(false,false,run);return end
            guardian = self:_createChaser(run.GuardianHomeCFrame.Position, stage)
        end
        if not run.Chest.EventKeeper then guardian = self:_adoptGuardianAsPersistent(stage, guardian, run.GuardianHomeCFrame) or guardian end
        run.Chaser = guardian
        local sleeping = guardian:GetAttribute("GuardianBehavior") == "GUARDING" or guardian:GetAttribute("GuardianBehavior") == "SLEEPING"
        run.ChaseStartsAt = os.clock() + (run.RecoveryDashPending and Dash.AlertSeconds or math.max(sleeping and 1.05 or .25,tonumber(self.Config.GuardianNoticeDelay)or .5))
        run.CatchEnabledAt = run.ChaseStartsAt + .85
        run.LastGuardianTravelSpeed = self:_getGuardianSettings(stage).MinimumSpeed
        self.KeeperTargets[key] = run
        if run.Chest.EventKeeper then self.Event81.Returning=false;guardian:SetAttribute('VeiledAwakeAt',workspace:GetServerTimeNow()-(run.RecoveryDashPending and .85 or 0))end
        guardian:SetAttribute("GuardianBehavior", "ALERTED")
        guardian:SetAttribute("ReturningToCamp", false)
        guardian:SetAttribute("ActiveGuardianChaser", true)
        guardian:SetAttribute("GuardianLeaseToken", run.GuardianLeaseToken)
        guardian:SetAttribute("TargetUserId", run.Player.UserId)
        self:_setGuardianNoticeVisual(guardian, true)
        run.Player:SetAttribute("ChestChaseQueued", false)
        run.Player:SetAttribute("ChestChaseRunActive", true)
        local sound = self.Config.GuardianAlertSoundId
        if type(sound) ~= "string" or not sound:match("^rbxassetid://%d+$") then sound = self.Config.ChestAlarmSoundId end
        self.RunAlertRemote:FireClient(run.Player, "Show", sound,
            self.Config.GuardianAlertVolume or .16, run.GuardianLeaseToken, run.Character)
    end

    function Service:_advanceKeeper(key,existing)
        if self.KeeperTargets[key]or self.Advancing[key]then return end
        self.Advancing[key]=true
        local queue=self.KeeperQueues[key]or{}
        while not self.Map.Refreshing and #queue>0 do
            local run=table.remove(queue,1)
            if self.Runs[run.Player]==run and not run.Finishing then
                local character,_,root=self:_validCharacter(run.Player)
                if character~=run.Character then self:Finish(false,false,run)
                elseif self:_crossedBoundary(root.Position)then
                    self:Finish(true,false,run)
                    -- Movement validation can return a would-be escape to the track.
                    -- The popped carrier still needs this keeper if banking was refused.
                    if self.Runs[run.Player]==run and not run.Finishing then
                        self:_startTarget(run,existing);self.Advancing[key]=nil;return
                    end
                else self:_startTarget(run,existing);self.Advancing[key]=nil;return end
            end
        end
        self.Advancing[key]=nil
        if key=='Veiled'then if self.Event81 then self.Event81:Return(existing)end;return end
        if existing and existing.Parent and existing.PrimaryPart then
            existing:SetAttribute('TargetUserId',0)
            self:_beginGuardianReturn(key,existing,self:_getGuardianHomeCFrame(key),existing:GetAttribute('GuardianLeaseToken'),self:_getGuardianSettings(key).MinimumSpeed)
        end
    end

    function Service:_acceptSeed(player, seed, character, humanoid, root, recoveryDash)
        -- No yields between checking and reserving this player's carrying slot.
        self.GuardianLeaseSerial += 1
        -- Freeze the stolen variant before the shared pickup refreshes.
        local carriedSeed=table.clone(seed)
        carriedSeed.OriginSlot=seed.OriginSlot or (self.KnownSeeds[seed] and seed or nil)
        carriedSeed.OriginGeneration=seed.OriginGeneration or seed.Generation
        local run = {
            Player=player, Character=character, Humanoid=humanoid, HumanoidRootPart=root,
            Chest=carriedSeed, Stage=seed.Stage, KeeperKey=seed.EventKeeper and'Veiled'or seed.Stage, GuardianLeaseToken=self.GuardianLeaseSerial,
            RecoveryDashPending=recoveryDash==true,
            GuardianHomeCFrame=seed.EventKeeper and self.Event81.Home or self:_getGuardianHomeCFrame(seed.Stage, seed.Body.Position),
        }
        self.Runs[player] = run
        self.Starting[player] = nil
        local ok, err = pcall(function() run.CarriedChest = self:_createCarriedChest(character, root, carriedSeed) end)
        if not ok or not run.CarriedChest or not run.CarriedChest.Parent then
            self.Runs[player] = nil
            local partial = character:FindFirstChild("CarriedSeed")
            if partial then partial:Destroy() end
            warn("[V0.87] Seed carry visual failed: " .. tostring(err))
            return false
        end
        run.CarriedChest:SetAttribute('PickupToken',run.GuardianLeaseToken)
        player:SetAttribute("ChestChaseRunToken", run.GuardianLeaseToken)
        player:SetAttribute("SpecialKeeperChase84", seed.EventKeeper==true)
        player:SetAttribute("ChestChaseSeedCarrying", true)
        player:SetAttribute("ChestChaseQueued", true)
        player:SetAttribute("ChestChaseRunActive", false)
        self.PackTaken:FireClient(player,run.GuardianLeaseToken,character)
        self.KeeperQueues[run.KeeperKey] = self.KeeperQueues[run.KeeperKey] or {}
        table.insert(self.KeeperQueues[run.KeeperKey], run)
        self:_advanceKeeper(run.KeeperKey)
        if self.Runs[player] == run and self.KeeperTargets[run.KeeperKey] ~= run then
            self.Notifications:Show(player, "PACK TAKEN - REACH SAFETY! KEEPER IS BUSY", Color3.fromRGB(255,222,83), 3)
        end
        return true
    end

    function Service:Begin(player, seed)
        if self.Map.Refreshing or not self.KnownSeeds[seed] or not seed.Available
            or not seed.Body.Parent or not seed.Prompt.Enabled then return end
        local character, humanoid, root = self:_canTake(player, self.Chests:GetPackPickupPosition(seed.Prompt,seed.Body.Position))
        if not character then return end
        -- Reserve this world instance before any carry/keeper work: only one thief can take it.
        self.Chests:SetWorldPackAvailable(seed,false)
        self.Starting[player] = true
        local accepted=self:_acceptSeed(player, seed, character, humanoid, root)
        self.Starting[player]=nil
        if not accepted then self.Chests:SetWorldPackAvailable(seed,true) end
        -- A taken slot stays empty until the next global refresh. Never reroll after pickup.
    end

    function Service:_expireDroppedChest(token)
        local drop = self.Drops[token]
        if not drop or drop.Claimed then return end
        drop.Claimed = true
        self.Drops[token] = nil
        if drop.Model.Parent then drop.Model:Destroy() end
        self:_returnPackToOrigin(drop.Chest)
    end

    function Service:_returnPackToOrigin(chest)
        local slot=chest and chest.OriginSlot
        -- A drop belongs to one spawn cycle. Never resurrect a banked pack or
        -- overwrite the fresh pack that a later global refresh put in this slot.
        if self.Map.Refreshing or not slot or not self.KnownSeeds[slot] or slot.Available
            or not slot.Model.Parent or slot.Generation~=chest.OriginGeneration
            or slot.BagVariant~=chest.BagVariant then return false end
        for _,drop in pairs(self.Drops) do
            if not drop.Claimed and drop.Chest==chest then return false end
        end
        self.Chests:SetWorldPackAvailable(slot,true)
        return true
    end

    function Service:_dropChestAfterCatch(run, hit)
        self.DropSerial += 1
        local token = self.DropSerial
        local position = self:_getGroundedDropPosition(run)
        -- Resolve the physical hit and its feedback before constructing the dropped pack art.
        if hit and hit.ImpactApplied then -- Bat hit already committed before dropping the pack.
        elseif hit and hit.Cause=='Lightning'then self:_applyLightningFling(run.Player,hit.Center,run.Character)
        else self:_applyGuardianFling(run)end
        local model, prompt, label = self:_createDroppedChest(position, run.Chest, token)
        if model then
        position=model.PrimaryPart.Position
        self.Drops[token] = {Token=token, Chest=run.Chest, Stage=run.Stage, Position=position,
            Model=model, Prompt=prompt, Label=label, ExpiresAt=os.clock()+self.Config.DroppedChestDuration,
            RecoveryDash=not hit or hit.Cause=='Keeper'}
        else
            self:_returnPackToOrigin(run.Chest)
        end
        self.Notifications:Show(run.Player,hit and hit.Cause=='Bat'and 'SMACK! PACK DROPPED'or hit and hit.Cause=='Lightning'and 'ZAP! PACK DROPPED'or 'CAUGHT! PACK DROPPED',Color3.fromRGB(255,130,92),3)
        -- Drop timers are handled in the shared heartbeat, with no stale delayed reset.
    end

    function Service:_claimDroppedChest(player, token)
        local drop = self.Drops[token]
        if not drop or drop.Claimed then return end
        local grace = math.clamp(tonumber(self.Config.DroppedChestClaimGrace) or .35, 0, 1)
        if os.clock() > drop.ExpiresAt + grace then self:_expireDroppedChest(token);return end
        local character, humanoid, root = self:_canTake(player, self.Chests:GetPackPickupPosition(drop.Prompt,drop.Position))
        if not character then return end
        -- Reserve both the player and the dropped instance before any visual work.
        self.Starting[player] = true
        drop.Claimed = true
        drop.Prompt.Enabled = false
        local accepted = self:_acceptSeed(player, drop.Chest, character, humanoid, root, drop.RecoveryDash)
        if accepted then
            self.Drops[token] = nil
            if drop.Model.Parent then drop.Model:Destroy() end
        else
            self.Starting[player] = nil
            drop.Claimed = false
            if drop.Prompt.Parent then drop.Prompt.Enabled = true end
        end
    end

    function Service:Finish(success, caught, run, hit)
        if not run or self.Runs[run.Player] ~= run or run.Finishing then return end
        if success and not require(script.Parent.MovementGuard).Check(run.Player)then return end
        self:_cancelKeeperAttack(run,run.KeeperImpactCommitted==true)
        self:_cancelKeeperDash(run)
        run.Finishing = true -- blocks duplicate awards, repeat touches and new pickups while banking
        local wasTarget = self.KeeperTargets[run.KeeperKey] == run
        if wasTarget then self.KeeperTargets[run.KeeperKey] = nil end
        local queue = self.KeeperQueues[run.KeeperKey] or {}
        for i=#queue,1,-1 do if queue[i] == run then table.remove(queue,i) end end
        self:_clearRunEffects(run)
        run.Player:SetAttribute("ChestChaseQueued", false)
        run.Player:SetAttribute("SpecialKeeperChase84", false)
        run.Player:SetAttribute("ChestChaseSeedCarrying", false)
        self:_restorePhysicalSpeed(run.Player, run.Humanoid)
        if run.CarriedChest and run.CarriedChest.Parent then run.CarriedChest:Destroy() end
        local banked=false
        local ok, err = pcall(function()
            if caught then
                self:_dropChestAfterCatch(run, hit)
            elseif success and run.Player.Parent then
                local secured, reason = self.Chests:Bank(run.Player, run.Chest)
                if secured then
                    banked=true
                    self.RunAlertRemote:FireClient(run.Player, "Success", nil, nil, run.GuardianLeaseToken, run.Character)
                    -- V103: the bank-confirmed Success event owns celebration feedback.
                else
                    self.Notifications:Show(run.Player, reason or "PACK COULD NOT BE STORED", Color3.fromRGB(255,187,91), 3)
                end
            end
        end)
        self.Runs[run.Player] = nil
        self.Starting[run.Player] = nil
        if not banked and (not caught or not ok) then self:_returnPackToOrigin(run.Chest) end
        if banked and run.Chest.EventKeeper then self.Event81:Captured(run.Chest)
        elseif wasTarget then self:_advanceKeeper(run.KeeperKey, run.Chaser) end
        if not ok then warn("[V0.87] Seed run ended with an error: " .. tostring(err)) end
    end

    function Service:_applyLightningFling(player,center,character)
        local current,_,root=self:_validCharacter(player)
        if current~=character then return false end
        local delta=root.Position-center
        local direction=Vector3.new(delta.X,0,delta.Z)
        direction=direction.Magnitude>.01 and direction.Unit or Vector3.new(1,0,0)
        return self.Ragdoll:Apply(player,direction*StormConfig.LightningHorizontal
            +Vector3.new(0,StormConfig.LightningVertical,0),"Lightning")~=nil
    end

    function Service:HitByBat(attacker,player,character)
        local current,_,root=self:_validCharacter(player)
        local attackerCharacter,_,attackerRoot=self:_validCharacter(attacker)
        if attacker==player or current~=character or not attackerCharacter or not root
            or root.Anchored or self.Map.Refreshing or not self.Ragdoll:CanHit(player)then return false end
        local run=self.Runs[player]
        if run and (run.Finishing or run.Character~=character)then return false end
        if self:_crossedBoundary(root.Position)then
            if run then self:Finish(true,false,run)end
            return false
        end
        local delta=root.Position-attackerRoot.Position;local direction=Vector3.new(delta.X,0,delta.Z)
        direction=direction.Magnitude>.01 and direction.Unit or Vector3.new(0,0,-1)
        local spec=Knockback.Bat
        local hit=self.Ragdoll:Apply(player,direction*spec.Horizontal+Vector3.new(0,spec.Vertical,0),'Bat')
        if not hit then return false end
        self.HitSerial+=1
        self.HitRemote:FireAllClients({Id=self.HitSerial,At=workspace:GetServerTimeNow(),Position=root.Position,
            VictimUserId=player.UserId,Direction=direction,Cause='Bat'})
        if run then self:Finish(false,true,run,{Cause='Bat',ImpactApplied=true})end
        return true
    end

    function Service:HitByLightning(player,center,character)
        local current,_,root=self:_validCharacter(player)
        if current~=character or not root or root.Anchored or not self.Ragdoll:CanHit(player)then return false end
        local run=self.Runs[player]
        if run then
            if run.Finishing or run.Character~=character then return false end
            if self:_crossedBoundary(root.Position)then self:Finish(true,false,run);return false end
            self:Finish(false,true,run,{Cause='Lightning',Center=center})
            return true
        end
        return self:_applyLightningFling(player,center,character)
    end

    function Service:_cancelKeeperAttack(run,preserveImpact)
        local attack=run.Attack;run.Attack=nil
        if not attack or preserveImpact then return end
        local keeper=attack.Keeper
        if keeper and keeper.Parent and keeper:GetAttribute('KeeperAttackSerial')==attack.Serial then
            keeper:SetAttribute('KeeperAttackAt',nil)
        end
    end

    function Service:_beginKeeperAttack(run)
        if run.Attack or run.Finishing or self.KeeperTargets[run.KeeperKey]~=run or self.Map.Refreshing then return false end
        local keeper=run.Chaser;local character,humanoid,root=self:_validCharacter(run.Player)
        if not keeper or not keeper.PrimaryPart or character~=run.Character or root.Anchored or not self.Ragdoll:CanHit(run.Player)then return false end
        if self:_crossedBoundary(root.Position)or not Combat.InReach(run.Stage,keeper.PrimaryPart.Position,root.Position)then return false end
        self.AttackSerial=(self.AttackSerial or 0)+1
        local now=os.clock();local spec=Combat.Get(run.Stage)
        run.Attack={Serial=self.AttackSerial,Keeper=keeper,Token=run.GuardianLeaseToken,ImpactAt=now+spec.Windup}
        keeper:SetAttribute('KeeperAttackSerial',self.AttackSerial)
        keeper:SetAttribute('KeeperAttackAt',workspace:GetServerTimeNow())
        keeper:SetAttribute('GuardianBehavior','ATTACKING')
        keeper:SetAttribute('KeeperTravelSpeed',0)
        self:_setGuardianNoticeVisual(keeper,false)
        return true
    end

    function Service:_moveKeeperToward(run,deltaTime,stopDistance)
        local core=run.Chaser.PrimaryPart;local root=run.HumanoidRootPart
        local target=Vector3.new(root.Position.X,core.Position.Y,root.Position.Z)
        local offset=target-core.Position;local distance=offset.Magnitude
        if distance<=.01 then return end
        deltaTime=math.clamp(deltaTime,0,.1)
        local cap=self.Config.GetPlayerWalkSpeed(run.Player,self.PlayerData:GetOrCreateSpeedValue(run.Player).Value)
        local velocity=root.AssemblyLinearVelocity
        local observed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
        local speed=run.Chest.EventKeeper and require(game:GetService('ReplicatedStorage').RouteBalance83).EventSpeed or self.Config.GetGuardianChaseSpeed(self:_getGuardianSettings(run.Stage),cap,distance,run.Stage,observed)
        if not run.Chest.EventKeeper then speed=self.Config.SmoothGuardianSpeed(run.LastGuardianTravelSpeed or speed,speed,deltaTime)end
        run.LastGuardianTravelSpeed=speed
        if not run.Attack and os.clock()-(run.MotionPublishedAt or -100)>=.10 then
            run.MotionPublishedAt=os.clock();run.Chaser:SetAttribute('KeeperTravelSpeed',math.floor(speed*2+.5)/2)
        end
        local nextPosition=core.Position+offset.Unit*math.min(speed*deltaTime,math.max(0,distance-stopDistance))
        local facing=(target-nextPosition).Magnitude>.001 and target or nextPosition+offset.Unit
        pivotKeeper(run.Chaser,CFrame.lookAt(nextPosition,facing))
    end

    function Service:_stepKeeperAttack(run,deltaTime)
        local attack=run.Attack;if not attack then return end
        local character,_,root=self:_validCharacter(run.Player)
        if self.Map.Refreshing or character~=run.Character or not root or root.Anchored
            or self.KeeperTargets[run.KeeperKey]~=run or attack.Token~=run.GuardianLeaseToken
            or run.Chaser~=attack.Keeper or not attack.Keeper.Parent then
            self:_cancelKeeperAttack(run,false);return
        end
        if self:_crossedBoundary(root.Position)then self:Finish(true,false,run);return end
        run.Chaser:SetAttribute('GuardianBehavior','ATTACKING')
        run.Chaser:SetAttribute('KeeperTravelSpeed',0)
        -- Track the thief through the brief windup; never teleport or freeze the player.
        if not Contact.Touching(run.Chaser,character)then self:_moveKeeperToward(run,deltaTime,0)end
        if os.clock()<attack.ImpactAt then return end
        if Contact.Touching(run.Chaser,character)and self.Ragdoll:CanHit(run.Player)then
            run.KeeperImpactCommitted=true
            self:Finish(false,true,run)
        else
            run.Attack=nil
            run.CatchEnabledAt=os.clock()+Combat.MissCooldown
            run.Chaser:SetAttribute('GuardianBehavior','CHASING')
        end
    end

    function Service:_cancelKeeperDash(run)
        local dash=run.Dash;run.Dash=nil;run.RecoveryDashPending=false
        local keeper=dash and dash.Keeper
        if keeper and keeper.Parent and keeper:GetAttribute('KeeperDashSerial')==dash.Serial then
            for _,key in ipairs({'KeeperDashAt','KeeperDashFrom','KeeperDashTo','KeeperDashDuration','KeeperDashToken','KeeperDashSerial'})do
                keeper:SetAttribute(key,nil)
            end
        end
    end

    function Service:_beginRecoveryDash(run)
        run.RecoveryDashPending=false -- Exactly once per recovered dropped pack, after its alert.
        local keeper=run.Chaser
        local goal,duration=Dash.Plan(run.Stage,keeper.PrimaryPart.CFrame,run.HumanoidRootPart.Position)
        if not goal then return false end
        self.DashSerial=(self.DashSerial or 0)+1
        local started=workspace:GetServerTimeNow()
        run.Dash={Keeper=keeper,Token=run.GuardianLeaseToken,Serial=self.DashSerial,
            From=keeper.PrimaryPart.CFrame,To=goal,Started=started,Duration=duration}
        keeper:SetAttribute('KeeperDashFrom',run.Dash.From)
        keeper:SetAttribute('KeeperDashTo',goal)
        keeper:SetAttribute('KeeperDashAt',started)
        keeper:SetAttribute('KeeperDashDuration',duration)
        keeper:SetAttribute('KeeperDashToken',run.GuardianLeaseToken)
        keeper:SetAttribute('KeeperDashSerial',self.DashSerial)
        keeper:SetAttribute('KeeperTravelSpeed',(goal-run.Dash.From.Position).Magnitude/duration)
        keeper:SetAttribute('GuardianBehavior','DASHING')
        self:_setGuardianNoticeVisual(keeper,false)
        return true
    end

    function Service:_stepRecoveryDash(run)
        local dash=run.Dash;if not dash then return end
        local character,_,root=self:_validCharacter(run.Player)
        if self.Map.Refreshing or character~=run.Character or not root or root.Anchored
            or self.Runs[run.Player]~=run or self.KeeperTargets[run.KeeperKey]~=run
            or dash.Token~=run.GuardianLeaseToken or run.Chaser~=dash.Keeper
            or not dash.Keeper.Parent or not dash.Keeper.PrimaryPart
            or dash.Keeper:GetAttribute('GuardianLeaseToken')~=dash.Token then
            self:_cancelKeeperDash(run);return
        end
        if self:_crossedBoundary(root.Position)then self:Finish(true,false,run);return end
        local frame,done=Dash.Sample(dash.From,dash.To,dash.Started,dash.Duration,workspace:GetServerTimeNow())
        pivotKeeper(dash.Keeper,frame)
        self:_publishRunEffects(run,(frame.Position-root.Position).Magnitude,0)
        if done then
            -- A normal attack still has its own visible windup. The dash itself cannot hit.
            dash.Keeper:SetAttribute('GuardianBehavior','CHASING')
            dash.Keeper:SetAttribute('KeeperTravelSpeed',0)
            run.CatchEnabledAt=math.max(run.CatchEnabledAt or 0,os.clock()+Dash.CatchGrace)
            self:_cancelKeeperDash(run)
        end
    end

    function Service:_updateActiveRun(deltaTime, run)
        if not run or run.Finishing then return end
        if self.KeeperTargets[run.KeeperKey]~=run then self:_cancelKeeperDash(run);return end
        if self.Map.Refreshing then self:_cancelKeeperDash(run);self:_cancelKeeperAttack(run,false);return end
        local character,_,liveRoot=self:_validCharacter(run.Player)
        if character~=run.Character then self:Finish(false,false,run);return end
        if self:_crossedBoundary(liveRoot.Position)then self:Finish(true,false,run);return end
        if liveRoot.Anchored then self:_cancelKeeperDash(run);self:_cancelKeeperAttack(run,false);return end
        local root = run.HumanoidRootPart
        local chaser = run.Chaser
        if not chaser or not chaser.Parent or not chaser.PrimaryPart then
            self:_cancelKeeperAttack(run,false)
            self:_cancelKeeperDash(run)
            if run.Chest.EventKeeper then chaser=self.Event81:EnsureGuardian()
            else chaser=self:_createChaser(run.GuardianHomeCFrame.Position, run.Stage)end
            if not chaser then self:Finish(false,false,run);return end
            if run.Chest.EventKeeper then chaser:SetAttribute('VeiledAwakeAt',workspace:GetServerTimeNow())end
            run.Chaser = chaser
            run.ChaseStartsAt = os.clock() + .5
            run.CatchEnabledAt = os.clock() + 1.35
            chaser:SetAttribute("GuardianLeaseToken", run.GuardianLeaseToken)
            chaser:SetAttribute("TargetUserId", run.Player.UserId)
            chaser:SetAttribute("ActiveGuardianChaser", true)
        end
        if Combat.HoldAfterHit(run.Stage,workspace:GetServerTimeNow(),chaser:GetAttribute('KeeperAttackAt'),chaser:GetAttribute('KeeperLastHitAt'))then
            chaser:SetAttribute('GuardianBehavior','ATTACKING');chaser:SetAttribute('KeeperTravelSpeed',0)
            self:_setGuardianNoticeVisual(chaser,false);return
        end
        local core = chaser.PrimaryPart
        local target = Vector3.new(root.Position.X, core.Position.Y, root.Position.Z)
        local offset = target-core.Position
        local distance = offset.Magnitude
        if os.clock() < run.ChaseStartsAt then
            chaser:SetAttribute("GuardianBehavior", "ALERTED")
            chaser:SetAttribute("KeeperTravelSpeed",0)
            self:_setGuardianNoticeVisual(chaser, true)
            if distance > .01 then pivotKeeper(chaser, CFrame.lookAt(core.Position, target)) end
            return
        end
        if run.RecoveryDashPending then self:_beginRecoveryDash(run)end
        if run.Dash then self:_stepRecoveryDash(run);return end
        if run.Attack then self:_stepKeeperAttack(run,deltaTime);return end
        chaser:SetAttribute("GuardianBehavior", "CHASING")
        self:_setGuardianNoticeVisual(chaser, false)
        self:_publishRunEffects(run, distance, deltaTime)
        if os.clock()>=run.CatchEnabledAt and Combat.InReach(run.Stage,core.Position,root.Position)and self:_beginKeeperAttack(run)then return end
        self:_moveKeeperToward(run,deltaTime,0)
        -- At extreme speeds the entire contact range can be crossed in one server step.
        -- Start the existing windup after movement too; impact still requires real body overlap.
        if os.clock()>=run.CatchEnabledAt and Combat.InReach(run.Stage,chaser.PrimaryPart.Position,root.Position)then
            self:_beginKeeperAttack(run)
        end
    end

    function Service:_maintainGuardians()
        for stage=1,self.Config.StageCount do
            -- A live target owns recovery; maintenance must not replace or recenter it.
            if not self.KeeperTargets[stage] and not self.ReturningGuardians[stage] then
                local guardian = self:_ensurePersistentGuardian(stage)
                if guardian then
                    pivotKeeper(guardian, self:_getGuardianHomeCFrame(stage))
                    guardian:SetAttribute("GuardianBehavior", "GUARDING")
                    guardian:SetAttribute("KeeperTravelSpeed",0)
                    guardian:SetAttribute("GuardianLeaseToken", 0)
                    guardian:SetAttribute("TargetUserId", 0)
                end
            end
        end
    end

    function Service:_evacuateBiomePlayers()
        local slot=0
        for _,player in ipairs(Players:GetPlayers()) do
            local character,_,root=self:_validCharacter(player)
            if character and self.Map:IsInsideBiomeTrack(root.Position) then
                slot+=1
                -- Keep the stolen pack: forced evacuation counts as returning it to safety.
                -- Resolve the run before teleporting so it cannot bank twice on the next heartbeat.
                self.Ragdoll:Clear(player)
                self:Finish(true,false,self.Runs[player])
                for _,part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero end
                end
                character:PivotTo(self.Map:GetRefreshReturnCFrame(slot));require(script.Parent.MovementGuard).Reset(player)
                self.Notifications:Show(player,"BIOMES REFRESHING",Color3.new(1,1,1),3)
            end
        end
    end
    function Service:_beginBiomeRefresh(now)
        self.RefreshEndsAt=now+PackRules.RefreshClosedSeconds
        self.NextRefreshAt=now+PackRules.RefreshInterval
        self.Map.MapRoot:SetAttribute("BiomeRefreshEndsAt",workspace:GetServerTimeNow()+PackRules.RefreshClosedSeconds)
        self.Map:SetBiomeRefreshing(true,PackRules.RefreshClosedSeconds)
        self.Map.MapRoot:SetAttribute("NextBiomeRefreshAt",workspace:GetServerTimeNow()+PackRules.RefreshInterval)
        self.Chests:SetWorldPacksClosed(true)
        self:_evacuateBiomePlayers()
        -- Disconnected/dead/out-of-bounds stale runs cannot retain a keeper lease across cycles.
        local stale={};for _,run in pairs(self.Runs) do table.insert(stale,run) end
        for _,run in ipairs(stale) do
            local character,_,root=self:_validCharacter(run.Player)
            self:Finish(character==run.Character and root~=nil,false,run)
        end
        local tokens={};for token in pairs(self.Drops) do table.insert(tokens,token) end
        for _,token in ipairs(tokens) do self:_expireDroppedChest(token) end
        self.KeeperQueues={}
        if self.Event81 then self.Event81:Clear()end
    end
    function Service:_updateBiomeRefresh(now)
        if not self.NextRefreshAt then return end
        if not self.Map.Refreshing and now>=self.NextRefreshAt then self:_beginBiomeRefresh(now) end
        if not self.Map.Refreshing then return end
        -- Also covers respawn, teleport and attempted wall bypass during the closure.
        self:_evacuateBiomePlayers()
        local remaining=math.max(0,math.ceil((self.RefreshEndsAt or now)-now))
        if self.RefreshCountdown~=remaining then
            self.RefreshCountdown=remaining;self.Map:SetBiomeRefreshing(true,remaining)
        end
        if now<(self.RefreshEndsAt or math.huge) then return end
        local ok,err=pcall(function() self.Chests:SkinWorldSeeds((self.Map.MapRoot:GetAttribute("BiomeRefreshCycle")or 0)+1) end)
        if not ok then
            self.RefreshEndsAt=now+1
            self.Map.MapRoot:SetAttribute("BiomeRefreshEndsAt",workspace:GetServerTimeNow()+1)
            warn("[V120] Pack refresh will retry behind the closed entrance: "..tostring(err))
            return
        end
        self.Map:SetBiomeRefreshing(false)
        self.Map.MapRoot:SetAttribute("BiomeRefreshEndsAt",nil)
        self.Chests:SetWorldPacksClosed(false)
        self.RefreshEndsAt=nil;self.RefreshCountdown=nil
        self.Map.MapRoot:SetAttribute("BiomeRefreshCycle",(self.Map.MapRoot:GetAttribute("BiomeRefreshCycle") or 0)+1)
        if self.Event81 then self.Event81:Spawn(self.Map.MapRoot:GetAttribute("BiomeRefreshCycle"))end
    end

    function Service:_heartbeat(deltaTime)
        self:_updateBiomeRefresh(os.clock())
        local runs = {}
        for _,run in pairs(self.Runs) do table.insert(runs, run) end
        -- Resolve every carrier's escape/death before moving any keeper.
        for _,run in ipairs(runs) do
            if not run.Finishing and self.Runs[run.Player] == run then
                local character, _, root = self:_validCharacter(run.Player)
                if character ~= run.Character then self:Finish(false, false, run)
                elseif self:_crossedBoundary(root.Position) then self:Finish(true, false, run) end
            end
        end
        local active={};for _,target in pairs(self.KeeperTargets)do table.insert(active,target)end
        for _,target in ipairs(active)do self:_updateActiveRun(deltaTime,target)end
        if self.Event81 then self.Event81:Step(deltaTime)end
        self:_updateReturningGuardians(deltaTime)
        for token,drop in pairs(self.Drops) do
            local remaining = math.max(0, math.ceil(drop.ExpiresAt-os.clock()))
            if drop.Label.Parent then drop.Label.Text = remaining.."s" end
            local grace = math.clamp(tonumber(self.Config.DroppedChestClaimGrace) or .35, 0, 1)
            if os.clock() > drop.ExpiresAt+grace then self:_expireDroppedChest(token) end
        end
        self.GuardianMaintenanceAccumulator += deltaTime
        if self.GuardianMaintenanceAccumulator >= .25 then
            self.GuardianMaintenanceAccumulator = 0
            self:_maintainGuardians()
            for _,player in ipairs(Players:GetPlayers()) do
                local character, _, root = self:_validCharacter(player)
                if character and root.Position.Y <= self.Config.FallReturnY then self:ReturnFallenCharacter(character) end
            end
        end
    end

    function Service:ReturnFallenCharacter(character)
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player or self.RecentFalls[character] then return end
        local current = self:_validCharacter(player)
        if current ~= character then return end
        self.RecentFalls[character] = true
        self.Ragdoll:Clear(player)
        self:Finish(false, false, self.Runs[player])
        for _,part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero end
        end
        character:PivotTo(CFrame.new(self.Map.ObbyStartPad.Position+Vector3.new(0,4,0)));require(script.Parent.MovementGuard).Reset(player)
        task.delay(1, function() self.RecentFalls[character]=nil end)
    end

    function Service:CleanupPlayer(player)
        if self.Bats then self.Bats:CleanupPlayer(player)end
        self.Ragdoll:Clear(player)
        self:Finish(false, false, self.Runs[player])
        self.Starting[player] = nil
        player:SetAttribute("GuardianFlingActive", false)
    end

    function Service:ReturnToIdle()
        local runs = {};for _,run in pairs(self.Runs) do table.insert(runs,run) end
        for _,run in ipairs(runs) do self:Finish(false, false, run) end
    end

    function Service:Start()
        if self.HeartbeatConnection then return end
        self.Map.MapRoot:SetAttribute('BiomeRefreshCycle',0)
        self.Event81=require(script.Parent.VeiledEvent81).new(self)
        if RunService:IsStudio()then
            self.Map.MapRoot:GetAttributeChangedSignal('R81TestEvent'):Connect(function()
                local value=self.Map.MapRoot:GetAttribute('R81TestEvent')
                if value then self.Map.MapRoot:SetAttribute('R81TestEvent',nil);self.Event81:Spawn(type(value)=='number'and value or 3)end
            end)
        end
        self.NextRefreshAt=os.clock()+PackRules.RefreshInterval
        self.Map.MapRoot:SetAttribute("NextBiomeRefreshAt",workspace:GetServerTimeNow()+PackRules.RefreshInterval)
        self:_captureGuardianBlueprints()
        self:_maintainGuardians()
        for _,seed in ipairs(self.Map.Chests) do
            self.Chests:SetWorldPackAvailable(seed,seed.Available)
            table.insert(self.Connections,seed.Prompt.Triggered:Connect(function(player) self:Begin(player,seed) end))
        end
        if self.Map.FallReturnPlane then
            self.FallConnection=self.Map.FallReturnPlane.Touched:Connect(function(hit)
                self:ReturnFallenCharacter(hit:FindFirstAncestorOfClass("Model"))
            end)
        end
        self.HeartbeatConnection=RunService.Heartbeat:Connect(function(dt) self:_heartbeat(dt) end)
        self.Bats=BatService.new(self);self.Bats:Start()
        print("[V0.87] PASS - shared seed pickups, locked per-biome keeper targets, FIFO handoffs.")
    end
    return Service
end
