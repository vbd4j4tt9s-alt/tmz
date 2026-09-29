local G=require(game:GetService('ReplicatedStorage').BeginnerGuide)
local T={}
function T.Attach(Data)
 function Data:PublishTutorial(player)
  local state=self:GetPremium(player).Tutorial
  if not state then return end
  player:SetAttribute('TutorialMask',state.Mask);player:SetAttribute('TutorialDone',state.Done)
  player:SetAttribute('TutorialStep',G.Step(state))
 end
 function Data:TutorialEvent(player,event)
  if not self:IsLoaded(player)then return false end
  local state=self:GetPremium(player).Tutorial;if not state or not G.Event(state,event)then return false end
  self:PublishTutorial(player);self:MarkDirty(player);self:QueueGardenSave(player);return true
 end
 function Data:TutorialAction(player,action)
  if not self:IsLoaded(player)then return false end
  local premium=self:GetPremium(player);premium.Tutorial=premium.Tutorial or G.Read()
  if not G.Action(premium.Tutorial,action)then return false end
  self:PublishTutorial(player);self:MarkDirty(player);self:QueueGardenSave(player);return true
 end
end
return T
