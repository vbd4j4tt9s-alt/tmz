-- R155 (owner): each player's pack pity (ReplicatedStorage.PackPity155): two counts, Normal and Event, saved in the profile as the OPTIONAL field
-- PackPity = {Normal, Event} (absent = 0 / 0: every profile saved before R155; an older server drops it), so ProfileVersion stays 22.
-- The server owns them: PlayerDataService:OpenSeedPack asks PlanPackPity BEFORE its roll (is this open the lucky 10th of its group?) and calls
-- CommitPackPity only once the open has gone through (the pack is now a seed). A refused / failed open, a replay of an opened pack and data still
-- loading never get that far, so they neither move nor skip a count; an open is one non-yielding transaction, so spamming cannot either.
-- The client reads the counts from player attributes (PackPity155.Attribute) and each lucky pack from PackPity155.LuckyAttribute (+1 per lucky open).
local RS=game:GetService('ReplicatedStorage')
local Pity=require(RS:WaitForChild('PackPity155'))
local D={}
function D.Install(Service)
 local function store(self)self.PackPityCounts=self.PackPityCounts or setmetatable({},{__mode='k'});return self.PackPityCounts end
 function Service:GetPackPity(player)return Pity.State(store(self)[player])end
 function Service:PublishPackPity(player)
  local s=self:GetPackPity(player)
  for _,group in ipairs(Pity.Groups)do
   player:SetAttribute(Pity.Attribute[group],s[group])
   if player:GetAttribute(Pity.LuckyAttribute[group])==nil then player:SetAttribute(Pity.LuckyAttribute[group],0)end
  end
 end
 function Service:LoadPackPity(player,saved)store(self)[player]=Pity.State(saved);self:PublishPackPity(player)end
 function Service:CopyPackPity(player)local s=self:GetPackPity(player);return {Normal=s.Normal,Event=s.Event}end
 -- Owner command (/test pity set <normal> <event>): whole numbers 0..9. Returns the new state, or nil and why.
 function Service:SetPackPity(player,normal,event)
  if not self:IsLoaded(player)then return nil,'Wait for the target\'s data to load.'end
  local function ok(n)return type(n)=='number'and n==n and n%1==0 and n>=0 and n<Pity.Every end
  if not ok(normal)or not ok(event)then return nil,'Use pity set <0-9> <0-9> (normal, event).'end
  store(self)[player]={Normal=normal,Event=event};self:PublishPackPity(player);self:MarkDirty(player)
  return self:GetPackPity(player)
 end
 -- The owner's /test pity line: both counts and which next pack is lucky.
 function Service:PackPityStatus(player)
  local s=self:GetPackPity(player);local out={}
  for _,group in ipairs(Pity.Groups)do
   local n=s[group]
   out[#out+1]=('%s %d/%d (%s)'):format(Pity.Name[group],n,Pity.Every,Pity.IsLucky(n)and(group=='Event'and'the NEXT event pack is LUCKY'or'the NEXT pack is LUCKY')or('lucky in '..Pity.Left(n)..' packs'))
  end
  return table.concat(out,' | ')
 end
 -- Before the roll. test = an owner / Studio TEST open (TestGrant pack, a /test rarepacks reveal, owner-given boots): it never counts and is never lucky (nil).
 -- Returns {Group, Lucky, Count} (Count = the group's count before this open).
 function Service:PlanPackPity(player,pack,test)
  if test or type(pack)~='table'then return nil end
  local group=Pity.Group(pack.BagVariant);local count=self:GetPackPity(player)[group]
  return {Group=group,Lucky=Pity.IsLucky(count),Count=count}
 end
 -- The luck the roll takes (boots x clover, and the clover alone): x1.5 each on the lucky one (PackPity155.Luck: once, here).
 function Service:PackPityLuck(plan,luck,passLuck)
  local lucky=plan~=nil and plan.Lucky==true
  return Pity.Luck(luck,lucky),Pity.Luck(passLuck,lucky)
 end
 -- The roll (or any odds) with the lucky ceiling on for the lucky one: fn(...) (PackPity155.Scoped).
 function Service:PackPityRoll(plan,fn,...)return Pity.Scoped(plan~=nil and plan.Lucky==true,fn,...)end
 -- After the open went through: the group's count moves on (the lucky one back to 0) and the client hears of a lucky pack.
 function Service:CommitPackPity(player,plan)
  if type(plan)~='table'or not plan.Group then return end
  local s=self:GetPackPity(player);s[plan.Group]=Pity.After(plan.Count);store(self)[player]=s
  if plan.Lucky then local key=Pity.LuckyAttribute[plan.Group];player:SetAttribute(key,(tonumber(player:GetAttribute(key))or 0)+1)end
  self:PublishPackPity(player)
 end
 -- The hold tooltip of a pack record: (odds or nil, lines). When this pack's open would be its group's lucky 10th, its real odds (x1.5) and a line saying so;
 -- always the rule. A TEST pack is never lucky. rawOdds(luck, passLuck) = the pack's odds at that luck (the caller's SeedOdds).
 function Service:PackPityTooltip(player,record,rawOdds)
  local lines={}
  local test=record.TestGrant==true or(type(self.HasTestLuck)=='function'and self:HasTestLuck(player))
  if not test then
   local okTest,expected=pcall(function()return require(script.Parent.RarePackTests).Expected(self,player,record.Id)end)
   test=okTest and expected~=nil
  end
  local plan=self:PlanPackPity(player,record,test)
  local odds=nil
  if plan and plan.Lucky then
   local luck,passLuck=self:PackPityLuck(plan,player:GetAttribute('ChestLuckMultiplier'),self:PassLuck(player))
   local ok,lucky=pcall(Pity.Scoped,true,rawOdds,luck,passLuck)
   if ok and type(lucky)=='table'then odds=lucky;lines[#lines+1]=Pity.LuckyLine end
  end
  return odds,lines,{Pity.Disclosure}
 end
end
return D
