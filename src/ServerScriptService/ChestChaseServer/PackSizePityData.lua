-- R137: each player's hidden pack-size pity counters (ReplicatedStorage.PackSizePity), saved in the profile as
-- PackLuck = {Big, Giant}. Not published anywhere: players never see it (owner: no indicator).
local Pity=require(game:GetService('ReplicatedStorage'):WaitForChild('PackSizePity'))
local D={}
function D.Install(Service)
 local function store(self)self.PackLuck=self.PackLuck or setmetatable({},{__mode='k'});return self.PackLuck end
 function Service:GetPackLuck(player)return Pity.State(store(self)[player])end
 function Service:LoadPackLuck(player,saved)store(self)[player]=Pity.State(saved)end
 function Service:CopyPackLuck(player)local s=self:GetPackLuck(player);return {Big=s.Big,Giant=s.Giant}end
 -- The size a newly granted pack comes out at; moves the counters. Only for packs that count (see Pity.Counts).
 function Service:RollPackLuck(player,stage,variant,size)
  if not Pity.Counts(stage,variant)then return size end
  self.PackLuckRandom=self.PackLuckRandom or Random.new()
  local random=self.PackLuckRandom
  local out,state=Pity.ApplyPlayer(self:GetPackLuck(player),size,function()return random:NextNumber()end)
  store(self)[player]=state
  return out
 end
end
return D
