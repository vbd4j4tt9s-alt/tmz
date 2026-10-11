-- R147 (owner: "Verity NPC is a quest giver: it tells players to steal a pack from The Darkened one and give it to the
-- Verity NPC. The Verity NPC will be behind the market and it will be big."): Verity stands on a dais behind the market.
-- Talk to her (E) and she asks for a Void Pack (the one The Darkened guards at the end of Storm Peaks); hand one in and
-- ChestService:ConvertVoidPack turns it, in place, into a Verity Pack. One Verity Pack for every Void Pack: repeatable, no
-- daily cap. The server owns everything: the client only sends 'Give' (no arguments).
-- R148 (owner's play test + "Verity should be a big yellow sphere"): she is the old Verity part made big, a solid yellow
-- SPHERE with her smiley as a Decal on its Front and Back faces, behind the market (VerityConfig.Position).
--  * Model: workspace.ChestChaseMap.EconomyHub.VerityNPC (Persistent): a stone and gold dais (solid), the Body (a Ball Part,
--    yellow, solid: it collides as a sphere), a neon ring, a light above her, a "VERITY" name sign with the quest marker's
--    room above it, and the "Talk" prompt. An old workspace.Verity placeholder part is left alone (the installer retires it).
--  * Remote ChestChaseRemotes.VerityQuest. Server -> client: 'Open' {VoidPacks, Delivered, RewardText, EventActive?,
--    NextAt?}, 'Done' {Delivered, RecordId}, 'Refused' {Reason}. Client -> server: 'Give' only.
--  * Saved: Premium.Verity = {Count = Void Packs handed in}, read defensively (anything odd reads as 0).
--  * The hand-in never yields between checking and committing, so a replay or a double click cannot convert twice.
-- R149: her greeting is cut to "Hello, my name is Verity" (VerityConfig.GreetingStart / GreetingEnd). The owner finds the right end by ear
-- with /test verityvoice <end> [start]: VoiceRegion / SetVoiceRegion / PlayVoice below keep that live value on her model as the attributes
-- VerityVoiceStart / VerityVoiceEnd (clients read them each time she speaks, so everyone in the server hears the new cut) and send the
-- caller a 'Greet' message ({Start, End}) so the cut plays for them at once, from anywhere in the server. Nothing is saved: a new server
-- uses the numbers in VerityConfig. Server -> client: 'Greet' {Start, End} joins 'Open', 'Done', 'Refused'.
-- NOTE: MapService binds WalkthroughProps90 to the map, which makes every part under EconomyHub walk-through a moment
-- after it appears. The dais and the Body must stay solid, so they put CanCollide back whenever it is cleared.
local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local C=require(RS.VerityConfig);local Limited=require(RS.LimitedEvent);local Voice=require(RS.VerityVoice)
local V={};V.__index=V
local RGB=Color3.fromRGB
local R=C.Reasons
function V.new(config,data,chests,notes,map)
 return setmetatable({Config=config,Data=data,Chests=chests,Notes=notes,Map=map},V)
end
local function part(parent,name,size,frame,color,material,collide)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=collide==true;p.CanQuery=collide==true;p.CanTouch=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
-- A flat cylinder standing upright (a Roblox cylinder's axis is X, so it is turned onto Y).
local function disc(parent,name,height,diameter,frame,color,material,collide)
 local p=part(parent,name,Vector3.new(height,diameter,diameter),frame*CFrame.Angles(0,0,math.pi/2),color,material,collide)
 p.Shape=Enum.PartType.Cylinder;return p
end
local function keepSolid(p)
 p:GetPropertyChangedSignal('CanCollide'):Connect(function()if p.CanCollide~=true then p.CanCollide=true end end)
end
-- Where the hand-in range is measured from: the top centre of the dais.
function V:Center()return C.Position+Vector3.new(0,C.DaisHeight,0)end
function V:_hub()
 local map=self.Map;local hub=map and map.EconomyHub
 if not hub and map and map.MapRoot then hub=map.MapRoot:FindFirstChild('EconomyHub')end
 if not hub then local root=workspace:FindFirstChild('ChestChaseMap');hub=root and root:FindFirstChild('EconomyHub')end
 return hub
end
function V:_mapRoot()
 local map=self.Map;local root=map and map.MapRoot
 return root or workspace:FindFirstChild('ChestChaseMap')
end
function V:_build(hub)
 for _,old in ipairs(hub:GetChildren())do if old.Name==C.ModelName then old:Destroy()end end
 local model=Instance.new('Model');model.Name=C.ModelName;model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 model:SetAttribute('VerityNPC',C.Version)
 local floor=C.Position;local daisTop=floor+Vector3.new(0,C.DaisHeight,0)
 local stone,gold,dark=RGB(96,90,112),RGB(255,206,64),RGB(44,38,64)
 -- The dais: stone, with a gold rim at its foot, a glowing neon ring and a dark inlay on top.
 local dais=disc(model,'Dais',C.DaisHeight,C.DaisDiameter,CFrame.new(floor+Vector3.new(0,C.DaisHeight/2,0)),stone,Enum.Material.Slate,true)
 keepSolid(dais)
 disc(model,'Dais rim',.3,C.DaisDiameter+.8,CFrame.new(floor+Vector3.new(0,.15,0)),gold,Enum.Material.SmoothPlastic)
 local ring=disc(model,'Glow ring',.22,C.RingDiameter,CFrame.new(daisTop+Vector3.new(0,.11,0)),C.RingColor,Enum.Material.Neon);ring.Transparency=.1
 -- R149 (z-fighting): the inlay's top is .08 above the ring's (was .04; on the 20-stud disc that shimmered from far away).
 disc(model,'Inlay',.3,C.RingDiameter-1.2,CFrame.new(daisTop+Vector3.new(0,.15,0)),dark,Enum.Material.Slate)
 -- Verity: a solid yellow ball with her smiley on the front (Decals project onto a ball) and the back. The Ball is the
 -- collider too: players walk up to its curve and stop. (A Ball part is always as wide as it is tall.)
 local size=C.BodySize;local middle=daisTop+Vector3.new(0,C.FootOffset+size/2,0)
 local body=part(model,'Body',Vector3.new(size,size,size),CFrame.lookAt(middle,middle+C.Facing),C.BodyColor,Enum.Material.SmoothPlastic,true)
 body.Shape=Enum.PartType.Ball;body.CastShadow=true;body:SetAttribute('Diameter',size);keepSolid(body)
 for _,face in ipairs(C.BodyFaces)do
  local decal=Instance.new('Decal');decal.Name='Face'..face;decal.Face=Enum.NormalId[face];decal.Texture=C.Image;decal.Color3=Color3.new(1,1,1);decal.Transparency=0;decal.Parent=body
 end
 CS:AddTag(body,'GiantVisualPart') -- the camera right up against her fades her (GiantVisualSafety), like the giant plants
 -- A light above her, so the ground and her top glow.
 local lightHolder=part(model,'LightAnchor',Vector3.new(.5,.5,.5),CFrame.new(middle+Vector3.new(0,size/2+C.LightHeight,0)),dark);lightHolder.Transparency=1
 local light=Instance.new('PointLight');light.Name='Glow';light.Color=C.LightColor;light.Range=C.LightRange;light.Brightness=C.LightBrightness;light.Shadows=false;light.Parent=lightHolder
 -- One sign over her head, in studs (see VerityConfig.Sign): the client puts the "!" / "?" marker in its top row and the event timer
 -- in its bottom row; the name is here. Camera-space offset: its bottom edge is Gap studs above her top edge from any angle.
 local S=C.Sign
 local sign=Instance.new('BillboardGui');sign.Name='NameSign';sign.Adornee=body;sign.Size=UDim2.fromScale(S.W,S.H)
 sign.StudsOffset=Vector3.new(0,size/2+S.Gap+S.H/2,0);sign.StudsOffsetWorldSpace=Vector3.new(0,0,0)
 sign.AlwaysOnTop=false;sign.MaxDistance=C.NameMaxDistance;sign.LightInfluence=0;sign.ResetOnSpawn=false;sign.Parent=body
 local label=Instance.new('TextLabel');label.Name='Name';label.BackgroundTransparency=1;label.Position=UDim2.fromScale(0,S.Name.Top/S.H);label.Size=UDim2.fromScale(1,S.Name.Height/S.H)
 label.Font=Enum.Font.FredokaOne;label.Text=C.Name;label.TextScaled=true;label.TextColor3=gold;label.TextStrokeColor3=RGB(30,20,60);label.TextStrokeTransparency=.05;label.Parent=sign
 -- The prompt sits on a small invisible anchor on her axis, low in the sphere.
 local anchor=part(model,'PromptAnchor',Vector3.new(.5,.5,.5),CFrame.new(daisTop+Vector3.new(0,C.PromptHeight,0)),dark);anchor.Transparency=1
 local prompt=Instance.new('ProximityPrompt');prompt.Name='Talk';prompt.ActionText=C.PromptActionText;prompt.ObjectText=C.PromptObjectText
 prompt.HoldDuration=C.PromptHold;prompt.MaxActivationDistance=C.PromptDistance;prompt.RequiresLineOfSight=false;prompt.Enabled=true;prompt.Parent=anchor
 prompt.Triggered:Connect(function(player)self:Talk(player)end)
 model.PrimaryPart=dais
 model.Parent=hub
 CS:AddTag(model,C.Tag)
 self.Model=model;self.Body=body;self.Prompt=prompt
 return model
end
-- Saved counter ------------------------------------------------------------------------------------------------------------
local function whole(n)
 if type(n)~='number'or n~=n then return 0 end
 return math.clamp(math.floor(n),0,C.MaxDelivered)
end
-- Premium.Verity = {Count=n}; whatever is stored (a missing field, a string, NaN, a negative, a huge number) reads as a clean count.
function V:State(player)
 local premium=self.Data:GetPremium(player);local stored=premium.Verity
 local state={Count=whole(type(stored)=='table'and stored.Count or 0)}
 premium.Verity=state;return state
end
function V:Delivered(player)return self:State(player).Count end
-- Records ------------------------------------------------------------------------------------------------------------------
local function isVoid(record)
 return type(record)=='table'and record.Kind=='Pack'and record.BagVariant==C.VoidVariant and record.Stage==7 and type(record.Id)=='string'
end
function V:CountVoid(player)
 local n=0;for _,record in ipairs(self.Data:GetChestRecords(player))do if isVoid(record)then n+=1 end end;return n
end
-- The Void pack to hand in: the one in the player's hands (an equipped Void Tool), else the oldest in the Bag.
-- Returns the record and its index in the Bag (nil when the player owns none). No side effects.
function V:Pick(player)
 local records=self.Data:GetChestRecords(player)
 local character=player.Character
 if character then
  for _,tool in ipairs(character:GetChildren())do
   if tool:IsA('Tool')and tool:GetAttribute('SeedPackTool')and tool:GetAttribute('BagVariant')==C.VoidVariant then
    local id=tool:GetAttribute('SeedInventoryId')
    for index,record in ipairs(records)do if record.Id==id and isVoid(record)then return record,index end end
   end
  end
 end
 local best,bestIndex,bestNumber
 for index,record in ipairs(records)do
  if isVoid(record)then
   local number=tonumber(record.ChestNumber)or math.huge
   if not best or number<bestNumber then best,bestIndex,bestNumber=record,index,number end
  end
 end
 return best,bestIndex
end
-- Talking --------------------------------------------------------------------------------------------------------------------
function V:_refuse(player,reason)
 self.Remote:FireClient(player,'Refused',{Reason=reason})
 return false,reason
end
function V:Open(player)
 if not self.Data:IsLoaded(player)then return self:_refuse(player,R.Loading)end
 local payload={VoidPacks=self:CountVoid(player),Delivered=self:Delivered(player),RewardText=C.RewardText}
 -- When The Darkened is here (VeiledEvent81 publishes these on the map) and when it next comes; left out when unknown.
 local map=self:_mapRoot()
 if map then
  local active=map:GetAttribute('VeiledEventActive');if type(active)=='boolean'then payload.EventActive=active end
  local at=map:GetAttribute('VeiledNextAt');if active~=true and type(at)=='number'and at==at then payload.NextAt=at end
 end
 self.Remote:FireClient(player,'Open',payload)
 return true
end
function V:Talk(player)
 if not player or not player.Parent or not require(script.Parent.SecurityGate).Allow(player,'VerityTalk')then return false end
 return self:Open(player)
end
-- Her greeting's cut (owner test command) --------------------------------------------------------------------------------------------
-- The cut in force: (start, stop, overridden). The owner's live values when set, else VerityConfig's.
function V:VoiceRegion()
 local model=self.Model
 local a,b=model and model:GetAttribute('VerityVoiceStart'),model and model:GetAttribute('VerityVoiceEnd')
 if Voice.Finite(a)and Voice.Finite(b)then local start,stop=Voice.Region(C,a,b,0);return start,stop,true end
 local start,stop=Voice.Region(C,nil,nil,0);return start,stop,false
end
-- start, stop = seconds into the clip (made safe by VerityVoice.Region); nil, nil goes back to VerityConfig. False when she is not built.
function V:SetVoiceRegion(start,stop)
 local model=self.Model;if not model or not model.Parent then return false end
 if start==nil and stop==nil then model:SetAttribute('VerityVoiceStart',nil);model:SetAttribute('VerityVoiceEnd',nil);return true end
 if not Voice.Finite(start)or not Voice.Finite(stop)then return false end
 local a,b=Voice.Region(C,start,stop,0)
 model:SetAttribute('VerityVoiceStart',a);model:SetAttribute('VerityVoiceEnd',b);return true
end
-- Play the cut in force for this one player, now (their client plays it flat, so it is heard from anywhere). True when it was sent.
function V:PlayVoice(player)
 if not self.Remote or not player or not player.Parent then return false end
 local start,stop=self:VoiceRegion();self.Remote:FireClient(player,'Greet',{Start=start,End=stop});return true
end
-- The hand-in -------------------------------------------------------------------------------------------------------------------
local function body(player)
 local character=player.Character;local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 local root=character and character:FindFirstChild('HumanoidRootPart')
 if humanoid and humanoid.Health>0 and root then return root end
 return nil
end
-- An opening that must finish first: any reveal in progress, or this very pack already being clicked open.
function V:_openingBlocks(player,record)
 local openings=self.Chests and self.Chests.Openings;local opening=openings and openings[player]
 if type(opening)~='table'then return false end
 if opening.Committed then return true end
 local tool=opening.Tool
 return record~=nil and tool~=nil and tool:GetAttribute('SeedInventoryId')==record.Id and(tonumber(opening.Clicks)or 0)>0
end
-- Returns true and the new Verity record, or false and the reason (also sent to the player as 'Refused').
-- Validation order: rate limit (over-limit requests get no reply at all), event running, data / save, range, busy, opening, ChestService
-- ready, owns a Void pack. Nothing yields.
function V:Give(player,...)
 if not player or not player.Parent then return false end
 -- Spam is dropped without an answer, before anything that replies (the dialog's button is locked while it waits, so real
 -- players never hit this); every refusal below counts against the same budget.
 if not require(script.Parent.SecurityGate).Allow(player,'VerityGive',...)then return false end
 -- The limited event is over: she takes nothing (the clock is the server's, UTC).
 if not Limited.Active(os.time())then return self:_refuse(player,R.EventEnded)end
 local data=self.Data
 if not data:IsLoaded(player)then return self:_refuse(player,R.Loading)end
 if not data.CanSave[player]then return self:_refuse(player,R.CannotSave)end
 local root=body(player)
 if not root then return self:_refuse(player,R.Moment)end
 if(root.Position-self:Center()).Magnitude>C.GiveDistance then return self:_refuse(player,R.TooFar)end
 for _,row in ipairs(C.BusyAttributes)do
  if player:GetAttribute(row[1])then return self:_refuse(player,R[row[2]])end
 end
 local record,index=self:Pick(player)
 if self:_openingBlocks(player,record)then return self:_refuse(player,R.Opening)end
 local chests=self.Chests
 if type(chests)~='table'or type(chests.ConvertVoidPack)~='function'then return self:_refuse(player,R.NotReady)end
 if not record then return self:_refuse(player,R.NoVoid)end
 -- ChestService swaps the record for a Verity pack in place, in one step (and syncs the Tools), or changes nothing.
 local id=record.Id
 local ok,result,why=pcall(chests.ConvertVoidPack,chests,player,id)
 local verity
 if ok and type(result)=='table'then verity=result
 elseif ok then return self:_refuse(player,type(why)=='string'and why~=''and why or R.Failed)
 else
  -- It threw. If the swap had already happened the hand-in counts; otherwise nothing changed.
  warn('[R147] ConvertVoidPack failed: '..tostring(result))
  local now=data:GetChestRecords(player)[index]
  if type(now)=='table'and now.Id~=id and now.BagVariant==C.VerityVariant then verity=now
  else return self:_refuse(player,R.Failed)end
 end
 local count=math.min(C.MaxDelivered,self:Delivered(player)+1)
 data:GetPremium(player).Verity={Count=count}
 data:MarkDirty(player);data:QueueGardenSave(player)
 if self.Notes then pcall(function()self.Notes:Show(player,C.Notice,RGB(255,214,90),4)end)end
 self.Remote:FireClient(player,'Done',{Delivered=count,RecordId=verity.Id})
 return true,verity
end
-- Start ---------------------------------------------------------------------------------------------------------------------
function V:Start()
 if self.Started then return self end
 local hub=self:_hub()
 if not hub then warn('[R147] Verity: EconomyHub is missing; she was not built.');return self end
 self.Started=true
 local remotes=RS:WaitForChild('ChestChaseRemotes')
 local remote=remotes:FindFirstChild(C.RemoteName)
 if not remote then remote=Instance.new('RemoteEvent');remote.Name=C.RemoteName;remote.Parent=remotes end
 self.Remote=remote
 remote.OnServerEvent:Connect(function(player,action,...)
  if action=='Give'then self:Give(player,...)end
 end)
 local ok,err=pcall(function()self:_build(hub)end)
 if not ok then warn('[R147] Verity could not be built: '..tostring(err))end
 return self
end
return V
