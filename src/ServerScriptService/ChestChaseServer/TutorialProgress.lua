local G=require(game:GetService('ReplicatedStorage').BeginnerGuide)
local T={}
function T.Attach(Data)
 function Data:PublishTutorial(player)
  local state=self:GetPremium(player).Tutorial
  if not state then return end
  player:SetAttribute('TutorialMask',state.Mask);player:SetAttribute('TutorialDone',state.Done)
  player:SetAttribute('TutorialStep',G.Step(state))
  player:SetAttribute('StarterPackClaimed',self:GetPremium(player).StarterPack==true) -- R138: the finish card's promise
 end
 local function changed(self,player)self:PublishTutorial(player);self:MarkDirty(player);self:QueueGardenSave(player)end
 -- R158e: 'Pack' comes ONLY from a pack stolen on the track and banked (PlayerDataService:AddChest with Banked: ChestService:Bank), never from a gift, a bonus roll or any other
 -- grant (the R158d new-player Verity Pack arrives at the first spawn and must not tick the steal step). After the steal, opening ANY pack counts, planting any seed counts
 -- (BeginnerGuide.Event: each event only in its turn).
 function Data:TutorialEvent(player,event)
  if not self:IsLoaded(player)then return false end
  local state=self:GetPremium(player).Tutorial;if not state or state.Done or not G.Event(state,event)then return false end
  changed(self,player);return true
 end
 function Data:TutorialAction(player,action)
  -- R158c (owner: "make it so that you can't replay the tutorial, to prevent any issues"): a replay would set TutorialDone back to false. The request is refused at the door, changing nothing
  -- (an old client with the old Settings button, or an exploit, gets a plain failure from PremiumService). BeginnerGuide.Action still knows 'Replay' as plain data; nothing here reaches it.
  if action=='Replay'then return false end
  if not self:IsLoaded(player)then return false end
  local premium=self:GetPremium(player);premium.Tutorial=premium.Tutorial or G.Read()
  if not G.Action(premium.Tutorial,action)then return false end
  changed(self,player);return true
 end
 -- R158e (owner: "make sure that the first fruit is always 10 seconds growth time"): PlayerDataService:PlantSeed asks this for every new plant, before it is stored. Only ONE plant ever
 -- gets it: the one planted in the plant step of an unfinished tutorial (Pack and Seed done, Plant not yet), and only once per player (Fast, saved). Its first fruit is ready 10 s after planting (BeginnerGuide.FastFruit); everything later follows the normal timing. Never yields.
 function Data:TutorialFastCrop(player,seed,crop,definition,now)
  local state=self:GetPremium(player).Tutorial
  if not state or state.Done or state.Fast or G.Step(state)~=6 then return false end
  if not G.FastFruit(crop,definition,now)then return false end
  state.Fast=true;state.FastCrop=G.CleanId(crop.Id)
  return true
 end
 -- R158e: a step that can't be done any more moves the tutorial on (or back), so it never sticks (asked on every state request; never yields; returns true when it changed):
 --  * stealing with a full Bag (200: a stolen pack could not be banked): go on with what you hold (open a pack, else plant a seed, else what comes next);
 --  * opening with no pack left: steal one again; planting with no seed left: open a pack (none: steal one);
 --  * the grow / harvest step with no plant (dug up), or a full Bag with fruit to sell: on to selling; selling with nothing to sell: on to the treadmill.
 function Data:TutorialRepair(player)
  if not self:IsLoaded(player)then return false end
  local state=self:GetPremium(player).Tutorial;if not state or state.Done then return false end
  local B=G.Bits;local step=G.Step(state);local packs,seeds=0,0
  for _,r in ipairs(self:GetChestRecords(player))do if r.Kind=='Pack'then packs+=1 elseif r.Kind=='Seed'then seeds+=1 end end
  local garden=self.Gardens and self.Gardens[player];local crops=0
  for _,list in pairs(garden and garden.Plots or{})do crops+=#list end
  local harvests=garden and type(garden.Harvests)=='table'and #garden.Harvests or 0
  local room=type(self.RoomFor)~='function'or self:RoomFor(player,1)
  local mask=state.Mask
  if step==1 and not room and player:GetAttribute('ChestChaseSeedCarrying')~=true then
   mask=bit32.bor(mask,B.Pack);if packs==0 then mask=bit32.bor(mask,B.Seed);if seeds==0 then mask=bit32.bor(mask,B.Plant)end end
  elseif step==4 and packs==0 then mask=bit32.band(mask,bit32.bnot(B.Pack))
  elseif step==6 and seeds==0 then mask=bit32.band(mask,bit32.bnot(packs>0 and B.Seed or bit32.bor(B.Seed,B.Pack)))
  elseif step==7 and(crops==0 or(not room and harvests>0))then mask=bit32.bor(mask,B.Harvest)
  elseif step==9 and harvests==0 then mask=bit32.bor(mask,B.Sell)
  end
  if mask==state.Mask then return false end
  state.Mask=mask;changed(self,player);return true
 end
 -- R138 (owner: "after the tutorial is done a free pack is given ... a forest pack, its rates will be 2x luckier"):
 -- once per account, for finishing the tutorial: its steps done (stole, opened, planted), so skipping only the last
 -- slides still counts but skipping it at the start does not; never again on a replay. Returns the record.
 function Data:GrantStarterPack(player)
  if not self:IsLoaded(player)then return nil end
  local premium=self:GetPremium(player);local state=premium.Tutorial
  if premium.StarterPack==true or not state or not state.Done then return nil end
  for _,step in ipairs({'Pack','Seed','Plant'})do if bit32.band(state.Mask,G.Bits[step])==0 then return nil end end
  local Packs=require(game:GetService('ReplicatedStorage').SeedPackRules)
  local record=self:AddChest(player,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',Weather='None',OddsVersion=Packs.OddsVersion,RateBoost=2})
  if not record then return nil end -- a full Bag: tried again next time they finish or replay
  record.ChestName=G.StarterPack.Name;premium.StarterPack=true;player:SetAttribute('StarterPackClaimed',true)
  self:MarkDirty(player);self:QueueGardenSave(player)
  return record
 end
end
return T
