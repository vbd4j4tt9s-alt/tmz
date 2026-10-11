local Marketplace=game:GetService('MarketplaceService')
local RS=game:GetService('ReplicatedStorage')
local Catalog=require(RS:WaitForChild('GamePassCatalog'))
local Growth=require(RS:WaitForChild('GrowthBoostRules'))
local S={};S.__index=S
-- R148: the "✅ Purchased: ...!" notice + PurchaseDone event. A missing or broken module only means no celebration.
local function announcer(data)
 local okay,made=pcall(function()return require(script.Parent.PurchaseAnnouncer).new(data)end)
 if okay then return made end
 warn('[R148] purchase feedback is unavailable: '..tostring(made));return nil
end
function S.new(data,bases,chests)
 local self=setmetatable({Data=data,Bases=bases,Chests=chests,Busy={},Announcer=announcer(data)},S)
 data.PassOwnership=function(player,key)return self:Owns(player,key)end
 self.Connection=Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
  if purchased then for _,pass in ipairs(Catalog)do if Catalog.Id(pass)==id then
   if player.Parent then
    player:SetAttribute(pass.Attribute,true);player:SetAttribute(pass.Key..'OwnershipReady',true)
    -- Roblox says this purchase went through (the event fires once per finished prompt).
    if self.Announcer then self.Announcer:Announce(player,'Pass',pass.Key)end
   end
   task.spawn(function()self:Refresh(player)end);break
  end end end
 end)
 return self
end
function S:Owns(player,key)
 local pass;for _,row in ipairs(Catalog)do if row.Key==key then pass=row;break end end
 if not pass or not player.Parent or not self.Data:IsLoaded(player)then return nil end
 local state=self.Data:GetPremium(player)
 if state.Entitlements[key]or player:GetAttribute(pass.Attribute)==true then player:SetAttribute(key..'OwnershipReady',true);return true end
 local id=Catalog.Id(pass);if id==0 then player:SetAttribute(key..'OwnershipReady',true);return false end
 local okay,owned=pcall(Marketplace.UserOwnsGamePassAsync,Marketplace,player.UserId,id)
 if not player.Parent or not self.Data:IsLoaded(player)or self.Data:GetPremium(player)~=state then return nil end
 -- An entitlement or purchase event may have arrived while Marketplace yielded.
 if state.Entitlements[key]or player:GetAttribute(pass.Attribute)==true then player:SetAttribute(key..'OwnershipReady',true);return true end
 if okay and type(owned)=='boolean'then player:SetAttribute(key..'OwnershipReady',true);return owned end
 player:SetAttribute(key..'OwnershipReady',false)
 return nil
end
function S:Refresh(player)
 if self.Busy[player]or not self.Data:IsLoaded(player)then return end;self.Busy[player]=true
 for _,pass in ipairs(Catalog)do
  local owned
  for attempt=1,4 do
   owned=self:Owns(player,pass.Key)
   if owned~=nil or not player.Parent or not self.Data:IsLoaded(player)then break end
   if attempt<4 then task.wait(attempt*2)end
  end
  if not player.Parent or not self.Data:IsLoaded(player)then break end
  if owned~=nil then player:SetAttribute(pass.Attribute,player:GetAttribute(pass.Attribute)==true or owned==true or self.Data:GetPremium(player).Entitlements[pass.Key]==true)end
 end
 if player.Parent and self.Data:IsLoaded(player)then
  if player:GetAttribute('DoubleGrowthOwned')then
   local changed=false;local garden=self.Data.Gardens[player]
   for _,plot in pairs(garden and garden.Plots or{})do for _,crop in ipairs(plot)do if Growth.Apply(crop,2,os.time())then changed=true end end end
   if changed then self.Data:MarkDirty(player);self.Data:_gardenChanged(player);self.Data:QueueGardenSave(player);self.Chests:RenderGarden(self.Bases:GetPlayerBase(player),player)end
  end
  self.Bases:RefreshTreadmill(player)
 end
 self.Busy[player]=nil
end
return S
