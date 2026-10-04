-- R140 (owner: "speed boost for friends in the server and an invite button", "the your plant is ready thing"):
--  * Friend boost: every Roblox friend in the same server adds DailyRewards.FriendBoostPerFriend to the speed GAINED
--    from treadmill training (up to FriendBoostMaxFriends). The server sets FriendsInServer / FriendSpeedBoost;
--    BaseService:GetFriendGainMultiplier applies it (R148: it no longer touches the walk speed).
--  * "Your plant is ready": when a player leaves with a plant still growing, the time its first fruit is ready goes
--    into a MemoryStore queue shared by every server; whichever server is running then sends the Roblox experience
--    notification. Nothing happens until the owner sets this module's MessageId attribute (the notification string's
--    asset id from the Creator Dashboard) and adds the Open Cloud API key as the experience secret named by SecretName
--    (default 'PlantReadyKey'). Roblox only delivers to players 13+ who opted in (the client asks after a planting).
--  * Daily quests roll over at midnight UTC for players who stay online.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Http=game:GetService('HttpService');local MemoryStore=game:GetService('MemoryStoreService')
local D=require(RS.DailyRewards);local PlantRules=require(RS.PlantRules);local Names=require(RS.GardenDisplayNames)
local S={};S.__index=S
S.MinDelay=5*60          -- a plant ready sooner than this after leaving is not worth a notification
S.MaxDelay=45*86400      -- MemoryStore entries live at most 45 days
S.Cooldown=12*3600       -- at most one plant notification per player per 12 hours
S.PollSeconds=60
local QUEUE,SENT='PlantReady140','PlantReadySent140'
function S.new(data,notifications)
 local self=setmetatable({Data=data,Notifications=notifications,Friends={},Day=D.Day(os.time()),Connections={},Dead=false},S)
 return self
end
function S:Configured()
 local id=script:GetAttribute('MessageId')
 return type(id)=='string'and #id>=8 and #id<=80
end
function S:_queue()if not self.Queue then self.Queue=MemoryStore:GetSortedMap(QUEUE)end;return self.Queue end
function S:_sent()if not self.Sent then self.Sent=MemoryStore:GetSortedMap(SENT)end;return self.Sent end
-- Friend boost ------------------------------------------------------------------------------------------------------
local function pairKey(a,b)return a<b and a..':'..b or b..':'..a end
function S:_isFriend(a,b)
 local key=pairKey(a.UserId,b.UserId);local known=self.Friends[key]
 if known~=nil then return known end
 local ok,result=pcall(a.IsFriendsWith,a,b.UserId)
 if not ok then return false end -- not cached: tried again on the next join
 self.Friends[key]=result==true;return result==true
end
function S:Recount(player)
 if not player.Parent then return 0 end
 local n=0
 for _,other in ipairs(Players:GetPlayers())do if other~=player and other.Parent and self:_isFriend(player,other)then n+=1 end end
 player:SetAttribute('FriendsInServer',n);player:SetAttribute('FriendSpeedBoost',D.FriendMultiplier(n))
 return n
end
function S:FriendJoined(player)
 local mine=self:Recount(player)
 for _,other in ipairs(Players:GetPlayers())do
  if other~=player and self:_isFriend(other,player)then
   local n=self:Recount(other)
   if self.Notifications then pcall(function()
    self.Notifications:Show(other,'👥 '..player.DisplayName..' is here! Friend boost: +'..math.floor((D.FriendMultiplier(n)-1)*100+.5)..'% speed gain',Color3.fromRGB(120,220,255),5)
   end)end
  end
 end
 if mine>0 and self.Notifications then pcall(function()
  self.Notifications:Show(player,'👥 '..mine..(mine==1 and' friend'or' friends')..' here! Friend boost: +'..math.floor((D.FriendMultiplier(mine)-1)*100+.5)..'% speed gain',Color3.fromRGB(120,220,255),5)
 end)end
end
function S:FriendLeft(player)
 for _,other in ipairs(Players:GetPlayers())do if other~=player and(self.Friends[pairKey(other.UserId,player.UserId)])then
  -- Recount without the leaving player (it is still in the list while PlayerRemoving runs).
  local n=0
  for _,q in ipairs(Players:GetPlayers())do if q~=other and q~=player and self.Friends[pairKey(other.UserId,q.UserId)]then n+=1 end end
  other:SetAttribute('FriendsInServer',n);other:SetAttribute('FriendSpeedBoost',D.FriendMultiplier(n))
 end end
 for key in pairs(self.Friends)do local a,b=key:match('^(%-?%d+):(%-?%d+)$')
  if tonumber(a)==player.UserId or tonumber(b)==player.UserId then self.Friends[key]=nil end
 end
end
-- Plant ready -------------------------------------------------------------------------------------------------------
-- The first moment, after now, that a fruit in this player's garden becomes ready, and that plant's name.
function S:NextReady(player,now)
 local garden=self.Data.Gardens and self.Data.Gardens[player];if not garden then return nil end
 local plants=self.Data.Config and self.Data.Config.GardenPlants or{}
 local best,name
 for _,crops in pairs(garden.Plots or{})do for _,crop in ipairs(crops)do
  local def=plants[crop.SeedId]
  if def then for i=1,def.FruitCount or 1 do
   if not PlantRules.IsPicked(crop,i)then
    local at=math.max(crop.MatureAt or 0,PlantRules.FruitReadyAt(crop,i))
    if at>now and(not best or at<best)then best=at;name=Names.Plant(crop.SeedId,def.Name or crop.SeedName or'plant')end
   end
  end end
 end end
 return best,name
end
function S:Schedule(player)
 if not self:Configured()or not self.Data:IsLoaded(player)then return false end
 local now=os.time();local at,name=self:NextReady(player,now)
 if not at or at-now<S.MinDelay or at-now>S.MaxDelay then return false end
 local value={At=math.floor(at),Plant=tostring(name):sub(1,40)};local key=tostring(player.UserId)
 -- Never yield here: this runs inside PlayerRemoving, before the profile is finalized.
 task.spawn(function()pcall(function()self:_queue():SetAsync(key,value,math.min(S.MaxDelay,at-now+86400),value.At)end)end)
 return value
end
function S:Cancel(player)
 if not self:Configured()then return end
 task.spawn(function()pcall(function()self:_queue():RemoveAsync(tostring(player.UserId))end)end)
end
function S:Send(userId,plant)
 local secretName=script:GetAttribute('SecretName');if type(secretName)~='string'or secretName==''then secretName='PlantReadyKey'end
 local body={source={universe='universes/'..tostring(game.GameId)},payload={messageId=script:GetAttribute('MessageId'),type='MOMENT',
  parameters={plantName={stringValue=plant}},joinExperience={launchData='PlantReady'},analyticsData={category='PlantReady'}}}
 local ok,result=pcall(function()
  return Http:RequestAsync({Url='https://apis.roblox.com/cloud/v2/users/'..tostring(userId)..'/notifications',Method='POST',
   Headers={['Content-Type']='application/json',['x-api-key']=Http:GetSecret(secretName)},Body=Http:JSONEncode(body)})
 end)
 if not ok or type(result)~='table'or not result.Success then
  warn('[R140] Plant notification not sent: '..tostring(ok and type(result)=='table'and(tostring(result.StatusCode)..' '..tostring(result.Body))or result))
  return false
 end
 return true
end
-- One pass over the shared queue: claim each due entry (so two servers never send the same one), then send it.
function S:Deliver(now)
 if not self:Configured()then return 0 end
 now=now or os.time();local sent=0
 local ok,due=pcall(function()return self:_queue():GetRangeAsync(Enum.SortDirection.Ascending,20,nil,{sortKey=now+1})end)
 if not ok or type(due)~='table'then return 0 end
 for _,item in ipairs(due)do
  local key=item.key;local claimed
  local okClaim=pcall(function()
   self:_queue():UpdateAsync(key,function(old,sortKey)
    if type(old)~='table'or old.Claimed or(old.At or 0)>now then return nil end
    old.Claimed=game.JobId;claimed=old;return old,sortKey
   end,120)
  end)
  if okClaim and claimed and claimed.Claimed==game.JobId then
   pcall(function()self:_queue():RemoveAsync(key)end)
   local userId=tonumber(key)
   local recent;pcall(function()recent=self:_sent():GetAsync(key)end)
   if userId and not recent and not Players:GetPlayerByUserId(userId)and self:Send(userId,claimed.Plant or'plant')then
    sent+=1;pcall(function()self:_sent():SetAsync(key,true,S.Cooldown)end)
   end
  end
 end
 return sent
end
-- Players ---------------------------------------------------------------------------------------------------------------
function S:Setup(player)
 if not player.Parent then return end
 player:SetAttribute('PlantReadyAlerts',self:Configured())
 self.Data:PublishDaily(player)
 self:Cancel(player) -- back in the game: no "your plant is ready" while playing
 task.spawn(function()self:FriendJoined(player)end)
end
function S:Leaving(player)
 pcall(function()self:Schedule(player)end)
 self:FriendLeft(player)
end
function S:Step(now)
 now=now or os.time();local day=D.Day(now)
 if day~=self.Day then
  self.Day=day
  for _,player in ipairs(Players:GetPlayers())do if self.Data:IsLoaded(player)then self.Data:PublishDaily(player)end end
 end
end
function S:Start()
 if self.Started then return self end;self.Started=true
 task.spawn(function()
  local last=0
  while not self.Dead do
   task.wait(5)
   self:Step(os.time())
   if os.clock()-last>=S.PollSeconds then last=os.clock();pcall(function()self:Deliver(os.time())end)end
  end
 end)
 return self
end
return S
