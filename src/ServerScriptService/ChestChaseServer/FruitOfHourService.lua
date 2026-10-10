-- R132 (owner): Fruit of the Hour. The pick itself is FruitOfHour (same on every server and client); this service only
-- publishes it for the pedestal and HUD (ReplicatedStorage attributes) and announces each new fruit to everyone.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local Run=game:GetService('RunService')
local Hour=require(RS:WaitForChild('FruitOfHour'))
local S={};S.__index=S
function S.new(notifications)return setmetatable({Notes=notifications,Key=nil,Clock=0},S)end
function S.Text(current,now)
 local span='for the next hour'
 if current.Test then span=('for %d minutes (test)'):format(math.max(1,math.ceil((current.EndsAt-(now or current.StartsAt))/60)))end
 return('🌟 Fruit of the Hour: %s! Sells ×%.1f %s!'):format(current.Name or'Fruit',current.Multiplier,span)
end
function S:Step(now)
 local current=Hour.At(now)
 -- A new hour, or an owner test fruit starting/ending (same hour, different fruit or bonus).
 local key=('%d:%s:%.1f'):format(current.Hour,tostring(current.SeedId),current.Multiplier)
 if self.Key==key then return current end
 local first=self.Key==nil;self.Key=key
 RS:SetAttribute('FruitOfHourSeedId',current.SeedId);RS:SetAttribute('FruitOfHourName',current.Name)
 RS:SetAttribute('FruitOfHourMultiplier',current.Multiplier);RS:SetAttribute('FruitOfHourEndsAt',current.EndsAt)
 if not first and self.Notes then for _,p in ipairs(Players:GetPlayers())do self.Notes:Show(p,S.Text(current,now),Color3.fromRGB(255,215,70),5)end end
 return current
end
function S:Start()
 self:Step(workspace:GetServerTimeNow())
 self.Connection=Run.Heartbeat:Connect(function(dt)self.Clock+=dt;if self.Clock>=2 then self.Clock=0;self:Step(workspace:GetServerTimeNow())end end)
 -- New players hear about the current fruit once.
 self.Joined=Players.PlayerAdded:Connect(function(p)
  task.delay(8,function()if p.Parent and self.Notes then local now=workspace:GetServerTimeNow();self.Notes:Show(p,S.Text(Hour.At(now),now),Color3.fromRGB(255,215,70),5)end end)
 end)
end
return S
