local Rules=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenFenceRules'))
local D={}
function D.Install(Service)
 function Service:GetFenceTier(player)
  self.Fences=self.Fences or{};return Rules.Level(self.Fences[player])
 end
 function Service:LoadFenceData(player,saved)
  self.Fences=self.Fences or{};self.Fences[player]=Rules.Level(type(saved)=='table'and saved.Tier or 1)
  self:PublishFenceData(player)
 end
 function Service:PublishFenceData(player)
  local tier=self:GetFenceTier(player)
  player:SetAttribute('FenceTier',tier);player:SetAttribute('FenceSizeMultiplier',Rules.Size(tier));player:SetAttribute('FenceTimeMultiplier',Rules.Time(tier))
 end
 function Service:CopyFenceData(player)return {Tier=self:GetFenceTier(player)}end
 function Service:BuyFence(player,expected)
  if not self:IsLoaded(player)or not self.CanSave[player]then return false,'Ur save isn\'t ready yet!'end
  local current=self:GetFenceTier(player)
  if expected~=current+1 then return false,'The upgrade changed! Try again.'end
  local tier=Rules.Tiers[expected];if not tier then return false,'Fully upgraded!'end
  if not self:SpendCash(player,tier.Cost)then return false,'Not enough cash!'end
  self.Fences=self.Fences or{};self.Fences[player]=expected
  self:PublishFenceData(player);self:MarkDirty(player);self:QueueGardenSave(player)
  return true,tier.Name..' fence unlocked!'
 end
end
return D
