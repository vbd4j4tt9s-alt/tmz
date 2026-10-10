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
 function Data:TutorialEvent(player,event)
  if not self:IsLoaded(player)then return false end
  local state=self:GetPremium(player).Tutorial;if not state or not G.Event(state,event)then return false end
  self:PublishTutorial(player);self:MarkDirty(player);self:QueueGardenSave(player);return true
 end
 function Data:TutorialAction(player,action)
  -- R158c (owner: "make it so that you can't replay the tutorial, to prevent any issues"): a replay would set TutorialDone back to false. The request is refused at the door, changing nothing
  -- (an old client with the old Settings button, or an exploit, gets a plain failure from PremiumService). BeginnerGuide.Action still knows 'Replay' as plain data; nothing here reaches it.
  if action=='Replay'then return false end
  if not self:IsLoaded(player)then return false end
  local premium=self:GetPremium(player);premium.Tutorial=premium.Tutorial or G.Read()
  if not G.Action(premium.Tutorial,action)then return false end
  self:PublishTutorial(player);self:MarkDirty(player);self:QueueGardenSave(player);return true
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
