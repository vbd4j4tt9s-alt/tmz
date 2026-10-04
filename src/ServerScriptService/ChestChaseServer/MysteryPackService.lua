-- R141 (owner: "a pedestal with a mystery pack, the pack will be a black silhouette, after 15 minutes of staying in the
-- game they unlock the pack, this refreshes every day, the pack will be based on the treadmill they have"; "the
-- pedestal will be located in their base at the other empty side of the base"): one pedestal per base, in the empty
-- entrance corner opposite the treadmill (MysteryPackRules.Offset). While its owner plays, today's time counts up
-- (saved, so rejoining keeps it); at 15 minutes the black silhouette turns into the real pack (best treadmill's biome,
-- never Common) and the owner takes it with the prompt. A new day brings a new mystery pack; an unlocked pack that was
-- not taken goes straight into the Bag on the next visit. Numbers: ReplicatedStorage.MysteryPackRules.
-- The pedestal model's attributes are all the client needs: OwnerUserId, OwnerName, State (Empty / Locked / Ready /
-- Claimed), UnlockAt (server time), NextAt (next UTC midnight), Stage, Variant (only once unlocked).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local CS=game:GetService('CollectionService')
local M=require(RS.MysteryPackRules);local PackRules=require(RS.SeedPackRules)
local S={};S.__index=S
local RGB=Color3.fromRGB
local SILHOUETTE=RGB(10,9,16)
function S.new(config,data,bases,chests,notes,map)
 return setmetatable({Config=config,Data=data,Bases=bases,Chests=chests,Notes=notes,Map=map or bases and bases.Map,Pedestals={},Owner={},Unsaved={},LastClaim={},
  Random=Random.new(),Acc=0},S)
end
local function part(parent,name,size,frame,color,material,collide)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=collide==true;p.CanQuery=collide==true;p.CanTouch=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local function disc(parent,name,height,diameter,frame,color,material,collide)
 local p=part(parent,name,Vector3.new(height,diameter,diameter),frame*CFrame.Angles(0,0,math.pi/2),color,material,collide)
 p.Shape=Enum.PartType.Cylinder;return p
end
-- The pedestal: a stone plinth, a violet column with gold collars, a glowing top ring and the pack floating above.
function S:_build(record)
 local pad=record.Pad or record.Model and record.Model:FindFirstChild('Pad')
 if not pad then return nil end
 local old=record.Model:FindFirstChild('MysteryPedestal');if old then old:Destroy()end
 local m=Instance.new('Model');m.Name='MysteryPedestal';m:SetAttribute('MysteryPedestal',M.Version);m:SetAttribute('State','Empty')
 local o=pad.CFrame*CFrame.new(M.Offset.X,pad.Size.Y/2,M.Offset.Z)
 local stone,violet,gold=RGB(62,55,88),RGB(104,82,168),RGB(255,198,72)
 part(m,'Plinth',Vector3.new(8,1,8),o*CFrame.new(0,.5,0),stone,Enum.Material.Slate,true)
 part(m,'Plinth trim',Vector3.new(8.6,.3,8.6),o*CFrame.new(0,1.1,0),gold)
 disc(m,'Column',4.4,4.4,o*CFrame.new(0,3.45,0),violet,Enum.Material.Marble,true)
 disc(m,'Lower collar',.5,5.2,o*CFrame.new(0,1.45,0),gold)
 disc(m,'Upper collar',.5,5.4,o*CFrame.new(0,5.55,0),gold)
 disc(m,'Top',.6,6.6,o*CFrame.new(0,6.05,0),stone,Enum.Material.Slate,true)
 local ring=disc(m,'Glow ring',.22,7,o*CFrame.new(0,6.42,0),RGB(176,118,255),Enum.Material.Neon);ring.Transparency=.15
 local anchor=part(m,'PackAnchor',Vector3.new(1,1,1),o*CFrame.new(0,9.3,0),Color3.new());anchor.Transparency=1
 local light=Instance.new('PointLight');light.Name='Glow';light.Color=RGB(170,110,255);light.Range=14;light.Brightness=1.6;light.Shadows=false;light.Parent=anchor
 local prompt=Instance.new('ProximityPrompt');prompt.Name='TakeMysteryPack';prompt.ActionText='Take';prompt.ObjectText='Mystery Pack'
 prompt.HoldDuration=.5;prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Enabled=true;prompt.Parent=anchor
 prompt.Triggered:Connect(function(player)self:Claim(player,record)end)
 m.PrimaryPart=anchor;m.Parent=record.Model
 CS:AddTag(m,'MysteryPedestal')
 self.Pedestals[record]={Model=m,Anchor=anchor,Prompt=prompt,Light=light,Ring=ring,Look=nil}
 return self.Pedestals[record]
end
function S:Pedestal(record)
 local p=self.Pedestals[record]
 if p and p.Model.Parent then return p end
 return self:_build(record)
end
-- The pack on top: a black silhouette (that biome's plain pack shape, so it never gives the rarity away) until it
-- unlocks, then the real pack. Nothing while claimed or without an owner.
function S:_look(p,state,stage,variant)
 local key=state..':'..tostring(stage)..':'..tostring(variant)
 if p.Look==key then return end;p.Look=key
 local old=p.Model:FindFirstChild('MysteryPack');if old then old:Destroy()end
 p.Ring.Color=state=='Ready'and RGB(255,214,90)or RGB(176,118,255)
 p.Light.Color=state=='Ready'and RGB(255,220,120)or RGB(170,110,255);p.Light.Enabled=state~='Empty'
 if state~='Locked'and state~='Ready'then return end
 local holder=Instance.new('Model');holder.Name='MysteryPack';holder.Parent=p.Model
 local ok,pack=pcall(function()
  local Visuals=require(RS.SeedPackVisuals)
  return Visuals.Bag(p.Anchor.CFrame,holder,1.7,nil,stage,state=='Ready'and variant or'Pack01',1,1,'None')
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
-- Saved state for today (rolls over at midnight UTC; yesterday's unlocked-but-not-taken pack goes into the Bag).
-- Returns the state and whether a new day just started.
function S:State(player)
 local premium=self.Data:GetPremium(player);local state=M.Read(premium.Mystery);local day=M.Day(os.time())
 premium.Mystery=state
 if state.Day==day then return state,false end
 if M.Unlocked(state)and not state.Claimed then
  if not self:_grant(player,state,true)then return state,false end -- a full Bag: it stays on the pedestal until taken
 end
 state={Day=day,Seconds=0,Claimed=false};premium.Mystery=state;self.Data:MarkDirty(player)
 return state,true
end
function S:_stage(player)
 return M.Stage(self.Config.TreadmillTiers,self.Data:GetTreadmillData(player).Tier)
end
function S:_grant(player,state,carried)
 local record,why=self.Data:AddChest(player,{Stage=state.Stage,BagVariant=state.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion},{Luck=true})
 if not record then
  if self.Notes and not carried then pcall(function()self.Notes:Show(player,'🎒 '..tostring(why or'Make room in your Bag first.'),RGB(255,190,90),4)end)end
  return false
 end
 state.Claimed=true;self.Data:MarkDirty(player);self.Data:QueueGardenSave(player)
 pcall(function()self.Chests:SyncTools(player)end)
 local tier=PackRules.GetPackTier(state.Variant);local label=PackRules.PackLabel(state.Stage,state.Variant,record.PackSize,'None')
 if self.Notes then pcall(function()
  self.Notes:Show(player,carried and('🎁 Yesterday\'s Mystery Pack went into your Bag: '..tier.Name..' '..label..'!')or('🎁 MYSTERY PACK: '..tier.Name..' '..label..'!'),tier.Color or RGB(255,214,90),5)
 end)end
 return true,record
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
 if force or status~='Locked'then set('UnlockAt',status=='Locked'and math.floor(workspace:GetServerTimeNow()+M.Left(state))or nil)end
 self:_look(p,status,stage,state.Variant)
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
 return ok
end
function S:Setup(player)
 if not self.Data:IsLoaded(player)then return end
 local record=self.Bases and self.Bases:GetPlayerBase(player);if not record then return end
 self.Owner[player]=record;self.Unsaved[player]=0
 self:Publish(player,true)
end
function S:Leaving(player)
 local record=self.Owner[player];self.Owner[player]=nil
 if self.Unsaved[player]and self.Unsaved[player]>0 then pcall(function()self.Data:MarkDirty(player)end)end
 self.Unsaved[player]=nil;self.LastClaim[player]=nil
 local p=record and self.Pedestals[record]
 if p and p.Model.Parent then
  for _,k in ipairs({'OwnerUserId','OwnerName','UnlockAt','Variant'})do p.Model:SetAttribute(k,nil)end
  p.Model:SetAttribute('State','Empty');self:_look(p,'Empty')
 end
end
-- Once a second: count each owner's time, unlock at 15 minutes, roll over at midnight UTC.
function S:Step(dt)
 self.Acc+=dt;if self.Acc<1 then return end
 local step=math.min(self.Acc,5);self.Acc=0
 for player,record in pairs(self.Owner)do
  if not player.Parent or not self.Data:IsLoaded(player)then continue end
  local state,newDay=self:State(player)
  if newDay then self:Publish(player,true);state=self:State(player)end -- (Publish re-reads the saved state: count on the live table, not the stale one)
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
