-- V147. Server-owned authorization; replicated attributes are UI hints, never credentials.
local Access={}
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local GroupService=game:GetService('GroupService')
local groupId,ownerId,expires,busy=nil,nil,0,false
local function ownerOfGroup(id)
 local now=os.clock()
 if groupId~=id then groupId=id;ownerId=nil;expires=0 end
 if now<expires or busy then return ownerId end
 busy=true;ownerId=nil
 local ok,info=pcall(function()return GroupService:GetGroupInfoAsync(id)end)
 busy=false
 if ok and type(info)=='table'and type(info.Owner)=='table'then
  local n=info.Owner.Id
  if type(n)=='number'and n>0 and n%1==0 then ownerId=n end
 end
 expires=now+(ownerId and 300 or 30)
 return ownerId
end
function Access.IsAllowed(player)
 if not player or player.Parent~=Players then return false end
 if RunService:IsStudio()then return true end
 if type(player.UserId)~='number'or player.UserId<=0 then return false end
 -- Optional server-authored comma-separated user IDs, never replicated player authority.
 local ids=script:GetAttribute('AdminUserIds')
 for id in tostring(ids or''):gmatch('%d+')do if tonumber(id)==player.UserId then return true end end
 if game.CreatorType==Enum.CreatorType.User then
  return game.CreatorId>0 and player.UserId==game.CreatorId
 elseif game.CreatorType==Enum.CreatorType.Group and game.CreatorId>0 then
  return player.UserId==ownerOfGroup(game.CreatorId)
 end
 return false
end
function Access.Publish(player)
 local allowed=Access.IsAllowed(player)
 if not player or player.Parent~=Players then return false end
 player:SetAttribute('ChestChaseCommandsAllowed',allowed)
 if not allowed then
  if not require(script.Parent.OwnerTestState82).MovementGranted(player)then player:SetAttribute('StudioTestFlying',false);player:SetAttribute('StudioTestNoclip',false)end
 end
 return allowed
end
return Access
