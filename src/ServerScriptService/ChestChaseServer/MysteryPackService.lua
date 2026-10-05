-- R141 (owner: "a pedestal with a mystery pack, the pack will be a black silhouette, after 15 minutes of staying in the
-- game they unlock the pack, this refreshes every day, the pack will be based on the treadmill they have"; "the
-- pedestal will be located in their base at the other empty side of the base"): one pedestal per base, in the empty
-- entrance corner opposite the treadmill (MysteryPackRules.Offset). While its owner plays, today's time counts up
-- (saved, so rejoining keeps it); at 15 minutes the black silhouette turns into the real pack (best treadmill's biome,
-- never Common) and the owner takes it with the prompt. A new day brings a new mystery pack; an unlocked pack that was
-- not taken goes straight into the Bag on the next visit. With a full Bag it waits in a small saved "owed" list (never
-- lost, never twice), today's pack starts as normal, and the owed packs go in whenever there is room.
-- Numbers: ReplicatedStorage.MysteryPackRules.
-- The pedestal model's attributes are all the client needs: OwnerUserId, OwnerName, State (Empty / Locked / Ready /
-- Claimed), UnlockAt (server time), NextAt (next UTC midnight), Stage, Variant (only once unlocked).
-- The model streams in Persistent mode (the place uses StreamingEnabled: another base's pedestal must not stream out
-- and come back as new instances), and the Take prompt is only Enabled while the pack is Ready; each client also turns
-- it off locally for everyone but the owner.
-- R150 (owner: "polish the pack pedestal"): the pedestal is sculpted in MysteryPedestalArt (themed by the biome of the pack, lit by state: the glow
-- pad, the four gems and the light are the only things this changes after the build) and the moving parts (swirl, sparkles, padlock, light
-- shaft, the unlock and take moments) are built by each client around it (MysteryPedestalFx, MysteryPackClient). Nothing about the rules changed.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local CS=game:GetService('CollectionService')
local M=require(RS.MysteryPackRules);local PackRules=require(RS.SeedPackRules);local Art=require(script.Parent.MysteryPedestalArt)
local PackShapes=require(RS.PackShapes151) -- R151: every pack rolls one of six chip-bag shapes; the pedestal's Ready pack shows the one the owner will get
local S={};S.__index=S
local RGB=Color3.fromRGB
local SILHOUETTE=RGB(10,9,16)
function S.new(config,data,bases,chests,notes,map)
 return setmetatable({Config=config,Data=data,Bases=bases,Chests=chests,Notes=notes,Map=map or bases and bases.Map,Pedestals={},Owner={},Unsaved={},LastClaim={},Told={},
  Random=Random.new(),Acc=0,Shapes=setmetatable({},{__mode='k'})},S)
end
local function part(parent,name,size,frame,color,material,collide)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=collide==true;p.CanQuery=collide==true;p.CanTouch=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
-- The pedestal (MysteryPedestalArt) with the pack floating over it: the anchor holds the glow of the light and the Take prompt.
function S:_build(record)
 local pad=record.Pad or record.Model and record.Model:FindFirstChild('Pad')
 if not pad then return nil end
 local old=record.Model:FindFirstChild('MysteryPedestal');if old then old:Destroy()end
 local m=Instance.new('Model');m.Name='MysteryPedestal';m:SetAttribute('MysteryPedestal',M.Version);m:SetAttribute('State','Empty')
 m.ModelStreamingMode=Enum.ModelStreamingMode.Persistent -- (StreamingEnabled: never streamed out, so no stale or late client copies)
 local o=pad.CFrame*CFrame.new(M.Offset.X,pad.Size.Y/2,M.Offset.Z)
 local art=Art.Build(m,o)
 local anchor=part(m,'PackAnchor',Vector3.new(1,1,1),o*CFrame.new(0,M.AnchorHeight,0),Color3.new());anchor.Transparency=1
 local light=Instance.new('PointLight');light.Name='Glow';light.Color=RGB(170,110,255);light.Range=14;light.Brightness=1.6;light.Shadows=false;light.Enabled=false;light.Parent=anchor
 local prompt=Instance.new('ProximityPrompt');prompt.Name='TakeMysteryPack';prompt.ActionText='Take';prompt.ObjectText='Mystery Pack'
 prompt.HoldDuration=.5;prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Enabled=false;prompt.Parent=anchor -- (Publish turns it on while the pack is Ready)
 prompt.Triggered:Connect(function(player)self:Claim(player,record)end)
 m.PrimaryPart=anchor;m.Parent=record.Model
 CS:AddTag(m,'MysteryPedestal')
 Art.Tint(art,'Empty',nil)
 self.Pedestals[record]={Model=m,Anchor=anchor,Prompt=prompt,Light=light,Ring=art.Ring,Art=art,Look=nil}
 return self.Pedestals[record]
end
function S:Pedestal(record)
 local p=self.Pedestals[record]
 if p and p.Model.Parent then return p end
 return self:_build(record)
end
-- R151: the chip-bag shape of today's mystery pack (rolled once per owner and pack, runtime only: it is rolled again if the owner rejoins before taking it): the pack on
-- the pedestal is drawn in it and the pack the owner takes has it (_give), so what is on the pedestal is what goes in the Bag.
function S:_shape(player,state)
 local held=self.Shapes[player]
 if held and held.Day==state.Day and held.Stage==state.Stage and held.Variant==state.Variant then return held.Shape end
 local shape=PackShapes.Roll(state.Variant)
 self.Shapes[player]={Day=state.Day,Stage=state.Stage,Variant=state.Variant,Shape=shape}
 return shape
end
-- The pack on top: a black silhouette (that biome's plain pack shape, so it never gives the rarity away) until it
-- unlocks, then the real pack. Nothing while claimed or without an owner.
-- R151: the silhouette is always the default shape of the plain pack (a locked pedestal never shows the roll: every locked pedestal looks the same); the real pack is its roll
-- once that pair is baked (asked for here; until then the default shape, then the shape: never back).
function S:_look(p,state,stage,variant,shape)
 local shown=0
 if state=='Ready'and shape and shape>0 then
  local design=PackRules.DesignKey(stage,variant)
  if PackShapes.Request(design,shape,PackRules.VariantKey(variant)==require(RS.VerityCatalog).Variant)=='Ready'then shown=shape end
 end
 local key=state..':'..tostring(stage)..':'..tostring(variant)..':'..shown
 if p.Look==key then return end;p.Look=key
 local old=p.Model:FindFirstChild('MysteryPack');if old then old:Destroy()end
 Art.Tint(p.Art,state,state~='Empty'and stage or nil) -- (the biome's colours, and the lit parts for the state)
 local lk=M.StateLook[state];local lamp=lk and lk.Light
 if lamp then p.Light.Color=RGB(lamp.Color[1],lamp.Color[2],lamp.Color[3]);p.Light.Brightness=lamp.Brightness;p.Light.Range=lamp.Range end
 p.Light.Enabled=lamp~=nil
 if state~='Locked'and state~='Ready'then return end
 local holder=Instance.new('Model');holder.Name='MysteryPack';holder.Parent=p.Model
 local ok,pack=pcall(function()
  local Visuals=require(RS.SeedPackVisuals)
  return Visuals.Bag(p.Anchor.CFrame,holder,1.7,nil,stage,state=='Ready'and variant or'Pack01',1,1,'None',nil,nil,state=='Ready'and shape or nil)
 end)
 if not ok or not pack then warn('[R141] Mystery pack art: '..tostring(pack));return end
 CS:RemoveTag(pack,'BiomeSeedPackVisual') -- not a track pack: the track renderer and highlights leave it alone
 pack:SetAttribute('MysteryOrigin',p.Anchor.CFrame)
 if state=='Locked'then
  for _,d in ipairs(pack:GetDescendants())do
   if d:IsA('SurfaceAppearance')or d:IsA('Decal')or d:IsA('Texture')or d:IsA('ParticleEmitter')or d:IsA('Light')then d:Destroy()
   elseif d:IsA('BasePart')and d.Transparency<1 then
    d.Color=SILHOUETTE;d.Material=Enum.Material.SmoothPlastic;d.MaterialVariant='';d.Reflectance=0
    if d:IsA('MeshPart')then d.TextureID=''end
   end
  end
 end
end
-- The saved state, sanitized (and stored back, so the caller works on the live table).
function S:_read(player)
 local premium=self.Data:GetPremium(player);local state=M.Read(premium.Mystery);premium.Mystery=state
 return state
end
-- Saved state for today (rolls over at midnight UTC; yesterday's unlocked-but-not-taken pack goes into the Bag, or into the
-- owed list when the Bag is full). Returns the state and whether a new day just started.
function S:State(player)
 local state=self:_read(player);local day=M.Day(os.time())
 if state.Day==day then return state,false end
 if M.Unlocked(state)and not state.Claimed then
  if not self:_grant(player,state,true)then
   -- A full Bag: it is owed (one per day, oldest first) and today's pack starts as normal. Only when the owed list is
   -- full too does it stay on the pedestal until taken (nothing is ever dropped).
   if #state.Owed>=M.MaxOwed then return state,false end
   state.Owed[#state.Owed+1]={Day=state.Day,Stage=state.Stage,Variant=state.Variant}
  end
 end
 state={Day=day,Seconds=0,Claimed=false,Owed=state.Owed};self.Data:GetPremium(player).Mystery=state;self.Data:MarkDirty(player)
 return state,true
end
function S:_stage(player)
 return M.Stage(self.Config.TreadmillTiers,self.Data:GetTreadmillData(player).Tier)
end
-- Puts the pack in the Bag: the record, or nil and why. Does not yield, so the caller can record that it is gone straight after.
function S:_give(player,pack)
 -- R151: today's pack is given in the shape the pedestal showed; an owed pack of an earlier day (or a pack the pedestal never showed) rolls its own in AddChest
 local held=self.Shapes[player];local shape
 if held and held.Day==pack.Day and held.Stage==pack.Stage and held.Variant==pack.Variant then shape=held.Shape end
 local record,why=self.Data:AddChest(player,{Stage=pack.Stage,BagVariant=pack.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion,PackShape=shape},{Luck=true})
 if record and held and held.Day==pack.Day then self.Shapes[player]=nil end
 pcall(function()require(script.Parent.OwnerTestPacks).Claim(player,'Mystery',record)end) -- R151: a pack that an owner "mystery" command made claimable is a TEST pack (never announced); marking never blocks a grant
 return record,why
end
-- The hotbar and the notice. how: nil = taken now, true = yesterday's pack, 'owed' = a pack that waited for room.
function S:_announce(player,pack,record,how)
 pcall(function()self.Chests:SyncTools(player)end)
 local tier=PackRules.GetPackTier(pack.Variant);local label=PackRules.PackLabel(pack.Stage,pack.Variant,record.PackSize,'None')
 if self.Notes then pcall(function()
  local text=how=='owed'and('🎁 A waiting Mystery Pack went into your Bag: '..tier.Name..' '..label..'!')
   or how and('🎁 Yesterday\'s Mystery Pack went into your Bag: '..tier.Name..' '..label..'!')or('🎁 MYSTERY PACK: '..tier.Name..' '..label..'!')
  self.Notes:Show(player,text,tier.Color or RGB(255,214,90),5)
 end)end
end
function S:_grant(player,state,carried)
 local record,why=self:_give(player,state)
 if not record then
  if self.Notes and not carried then pcall(function()self.Notes:Show(player,'🎒 '..tostring(why or'Make room in your Bag first.'),RGB(255,190,90),4,'Denied')end)end -- R150 review: a refused take clicks Denied (the orange colour and the 🎒 prefix are not one of SimpleGameText's red keys)
  return false
 end
 state.Claimed=true;self.Data:MarkDirty(player);self.Data:QueueGardenSave(player)
 self:_announce(player,state,record,carried)
 return true,record
end
-- Packs that did not fit in the Bag go in as soon as there is room (oldest first). The pack leaves the list in the same
-- breath as it enters the Bag (nothing between the two can yield), so a save never has both and never neither; the list is
-- read afresh each round. Tells the player (once per session) when some are still waiting.
function S:_payOwed(player)
 while true do
  local owed=self:_read(player).Owed;local pack=owed[1];if not pack then return end
  local record=self:_give(player,pack);if not record then break end
  table.remove(owed,1);self.Data:MarkDirty(player);self.Data:QueueGardenSave(player)
  self:_announce(player,pack,record,'owed')
 end
 local waiting=#self:_read(player).Owed
 if waiting>0 and not self.Told[player]and self.Notes then
  self.Told[player]=true
  pcall(function()self.Notes:Show(player,'🎁 Make room: '..waiting..' mystery pack'..(waiting==1 and''or's')..' waiting',RGB(255,190,90),6)end)
 end
end
function S:Publish(player,force)
 local record=self.Owner[player];if not record then return end
 local p=self:Pedestal(record);if not p then return end
 local state=self:State(player);local m=p.Model
 local status=state.Claimed and'Claimed'or M.Unlocked(state)and'Ready'or'Locked'
 local stage=state.Stage or self:_stage(player)
 local function set(k,v)if m:GetAttribute(k)~=v then m:SetAttribute(k,v)end end
 set('OwnerUserId',player.UserId);set('OwnerName',player.DisplayName);set('State',status);set('Stage',stage)
 set('Variant',status~='Locked'and state.Variant or nil);set('NextAt',M.NextDay(os.time()))
 if status=='Locked'then
  -- The client counts down to UnlockAt. It stays put while the clock runs, and is written again only when it drifts
  -- (a server hitch counts at most 5 s a tick, so the pack unlocks later than the clock said).
  local want=math.floor(workspace:GetServerTimeNow()+M.Left(state));local have=m:GetAttribute('UnlockAt')
  if force or type(have)~='number'or math.abs(have-want)>M.DriftSeconds then set('UnlockAt',want)end
 else set('UnlockAt',nil)end
 if p.Prompt.Enabled~=(status=='Ready')then p.Prompt.Enabled=status=='Ready'end -- (only a pack that can be taken shows a prompt)
 self:_look(p,status,stage,state.Variant,status=='Ready'and self:_shape(player,state)or nil)
end
function S:Unlock(player,state)
 state.Stage,state.Variant=nil,nil
 local pick=M.Roll(self:_stage(player),function()return self.Random:NextNumber()end)
 state.Stage,state.Variant=pick.Stage,pick.Variant;state.Seconds=M.UnlockSeconds
 self.Data:MarkDirty(player);self.Data:QueueGardenSave(player);self.Unsaved[player]=0
 self:Publish(player,true)
 if self.Notes then pcall(function()self.Notes:Show(player,'🔓 Your Mystery Pack is unlocked! Go home and take it 🎁',RGB(200,160,255),6)end)end
end
function S:Claim(player,record)
 if self.Owner[player]~=record then return false,'NOT YOURS'end
 local now=os.clock();if now-(self.LastClaim[player]or-10)<.5 then return false,'WAIT'end;self.LastClaim[player]=now
 if not self.Data:IsLoaded(player)then return false,'LOADING'end
 local state=self:State(player)
 if state.Claimed or not M.Unlocked(state)then return false,'LOCKED'end
 local ok=self:_grant(player,state,false)
 self:Publish(player,true)
 self:_payOwed(player)
 return ok
end
function S:Setup(player)
 if not self.Data:IsLoaded(player)then return end
 local record=self.Bases and self.Bases:GetPlayerBase(player);if not record then return end
 self.Owner[player]=record;self.Unsaved[player]=0
 self:Publish(player,true)
 self:_payOwed(player)
end
function S:Leaving(player)
 local record=self.Owner[player];self.Owner[player]=nil
 if self.Unsaved[player]and self.Unsaved[player]>0 then pcall(function()self.Data:MarkDirty(player)end)end
 self.Unsaved[player]=nil;self.LastClaim[player]=nil;self.Told[player]=nil
 local p=record and self.Pedestals[record]
 if p and p.Model.Parent then
  for _,k in ipairs({'OwnerUserId','OwnerName','UnlockAt','Variant'})do p.Model:SetAttribute(k,nil)end
  p.Model:SetAttribute('State','Empty');p.Prompt.Enabled=false;self:_look(p,'Empty')
 end
end
-- Once a second: count each owner's time, unlock at 15 minutes, roll over at midnight UTC.
function S:Step(dt)
 self.Acc+=dt;if self.Acc<1 then return end
 local step=math.min(self.Acc,5);self.Acc=0
 for player,record in pairs(self.Owner)do
  if not player.Parent or not self.Data:IsLoaded(player)then continue end
  local _,newDay=self:State(player)
  if newDay then self:Publish(player,true)end
  self:_payOwed(player) -- (owed packs go in as soon as there is room)
  local state=self:State(player) -- (Publish and _payOwed re-read the saved state: count on the live table, not an earlier one)
  if not state.Claimed and not M.Unlocked(state)then
   state.Seconds=math.min(M.UnlockSeconds,state.Seconds+step)
   self.Unsaved[player]=(self.Unsaved[player]or 0)+step
   if state.Seconds>=M.UnlockSeconds then self:Unlock(player,state)
   elseif self.Unsaved[player]>=M.SaveEvery then self.Unsaved[player]=0;self.Data:MarkDirty(player)end
  end
  self:Publish(player,false) -- (a treadmill upgrade changes the silhouette's biome; nothing is sent when unchanged)
 end
end
function S:Start()
 if self.Connection then return self end
 for _,record in ipairs(self.Map and self.Map.BaseRecords or{})do local ok,err=pcall(function()self:Pedestal(record)end);if not ok then warn('[R141] Mystery pedestal: '..tostring(err))end end
 self.Connection=Run.Heartbeat:Connect(function(dt)self:Step(dt)end)
 return self
end
return S
