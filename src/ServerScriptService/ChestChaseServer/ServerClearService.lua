-- V148. Owner-requested clear jobs: current-server snapshot, never offline profiles.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Access=require(script.Parent:WaitForChild('OwnerCommandAccess'))
local Service={};Service.__index=Service
function Service.new(ctx)
 return setmetatable({Context=ctx,Jobs={},Elapsed=0,Destroyed=false},Service)
end
local function summary(job)
 local waiting=0;for _ in pairs(job.Pending)do waiting+=1 end
 return string.format('%s: cleared %d items for %d players; %d waiting, %d left, %d failed%s.',
  job.Kind=='inventory'and 'Server inventory clear'or 'Server garden clear',job.Items,job.Cleared,waiting,job.Left,job.Failed,
  job.UpdateErrors>0 and('; '..job.UpdateErrors..' follow-up updates failed; check server Output')or'')
end
local function update(job,player,name,fn)
 local ok,err=pcall(fn)
 if not ok then job.UpdateErrors+=1;warn('[V148] '..name..' for '..tostring(player.UserId)..': '..tostring(err))end
end
function Service:_apply(job,player)
 local ctx=self.Context;local data=ctx.Data;local garden=data.Gardens[player]
 local count=0
 -- No yielding operations before the data commit. Dequeue once committed: later rewards stay.
 data:MarkDirty(player)
 if job.Kind=='inventory'then
  local records=data:GetChestRecords(player);count=#records+#garden.Harvests
  table.clear(records);table.clear(garden.Harvests)
 else
  for _,list in pairs(garden.Plots)do count+=#list;table.clear(list)end
 end
 job.Pending[player]=nil;job.Cleared+=1;job.Items+=count
 update(job,player,'save queue',function()data:QueueGardenSave(player)end)
 update(job,player,'garden revision',function()data:_gardenChanged(player)end)
 if job.Kind=='inventory'then
  update(job,player,'unequip',function()
   local character=player.Character;local h=character and character:FindFirstChildOfClass('Humanoid');if h then h:UnequipTools()end
  end)
  update(job,player,'inventory revision',function()data:_notifySeedInventory(player)end)
  update(job,player,'tool sync',function()ctx.Chests:SyncTools(player)end)
 end
 update(job,player,'garden render',function()
  local base=ctx.Bases:GetPlayerBase(player);if base then ctx.Chests:RenderGarden(base,player)end
 end)
end
function Service:Process()
 if self.Destroyed or self.Processing then return end;self.Processing=true
 local ctx=self.Context
 for kind,job in pairs(self.Jobs)do
  for player in pairs(job.Pending)do
   if player.Parent~=Players then job.Pending[player]=nil;job.Left+=1
   elseif ctx.Data:IsLoaded(player)and ctx.Data.Gardens[player]then
    local blocked=job.Kind=='inventory'and(ctx.Chests:IsOpening(player)or ctx.Chase:IsPlayerBusy(player)
     or player:GetAttribute('ChestChaseRunActive')or player:GetAttribute('ChestChaseSeedCarrying'))
    if not blocked then
     local ok,err=pcall(self._apply,self,job,player)
     if not ok then
      job.Pending[player]=nil;job.Failed+=1
      warn('[V148] Clear failed for '..tostring(player.UserId)..': '..tostring(err))
     end
    end
   end
  end
  if not next(job.Pending)then
   self.Jobs[kind]=nil
   if job.Report and ctx.ClearFeedback and job.Requester.Parent==Players then
    local ok,err=pcall(ctx.ClearFeedback,job.Requester,job.Failed==0,summary(job))
    if not ok then warn('[V148] Clear feedback: '..tostring(err))end
   end
  end
 end
 self.Processing=false
 if not next(self.Jobs)and self.Connection then self.Connection:Disconnect();self.Connection=nil end
end
function Service:Request(requester,kind)
 if self.Destroyed then return false,'Clear service has stopped.'end
 if not Access.IsAllowed(requester)then return false,'These commands are for the experience owner.'end
 if kind~='inventory'and kind~='garden'then return false,'Unknown clear target.'end
 if self.Jobs[kind]then return true,'Already running. '..summary(self.Jobs[kind])end
 local job={Kind=kind,Requester=requester,Pending={},Items=0,Cleared=0,Left=0,Failed=0,UpdateErrors=0,Report=false}
 for _,player in ipairs(Players:GetPlayers())do job.Pending[player]=true end
 self.Jobs[kind]=job;self:Process()
 job.Report=true
 if next(self.Jobs)and not self.Connection then
  self.Connection=RunService.Heartbeat:Connect(function(dt)
   self.Elapsed+=dt;if self.Elapsed>=1 then self.Elapsed=0;self:Process()end
  end)
 end
 return job.Failed==0,summary(job)
end
function Service:Destroy()
 self.Destroyed=true;if self.Connection then self.Connection:Disconnect();self.Connection=nil end
 table.clear(self.Jobs)
end
return Service
