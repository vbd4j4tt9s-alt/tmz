-- Global, durable, periodically refreshed rankings. Never substitute local-server ranks.
local Players=game:GetService('Players');local Run=game:GetService('RunService');local DataStore=game:GetService('DataStoreService');local Users=game:GetService('UserService')
local Landscape=require(game:GetService('ReplicatedStorage'):WaitForChild('LeaderboardLandscape'))
local Cash=require(game:GetService('ReplicatedStorage'):WaitForChild('CashNumbers'))
local Points=require(game:GetService('ReplicatedStorage').SpeedPoints)
local S={Size=100,ServerRows=10};S.__index=S
local Http=game:GetService('HttpService')
-- Whole points from a base-10 log (the sorted index); exact to ~9 significant digits, plenty for the board.
function S.FromLog(log)
 if type(log)~='number'or log~=log or log<0 then return '0'end
 if log<15 then return Points.Normalize(10^log)end
 local e=math.floor(log);local digits=string.format('%.0f',10^(log-e)*1e14)
 return Points.Normalize(digits..string.rep('0',math.max(0,e-14)))
end
local specs={{Key='hub.top1',Stat='Speed',Title='TOP SPEED',Badge='SPEED',Prefix=''}, {Key='hub.cash.top1',Stat='Cash',Title='MOST MONEY',Badge='MONEY',Prefix='$'}}
function S.new(data)
 local self=setmetatable({Data=data,Stores={},Rows={},Names={},Boards={},Writes={},Last={},Updated={},Failed={},Stopped=false},S)
 local suffix=Run:IsStudio()and'_Studio'or''
 for _,spec in ipairs(specs)do self.Stores[spec.Stat]=DataStore:GetOrderedDataStore('ChestChase_Global_'..spec.Stat..(spec.Stat=='Speed'and'_v2'or'_v1')..suffix)end
 self.ExactSpeed=DataStore:GetDataStore('ChestChase_Global_Speed_Exact_v2'..suffix);self.ExactCache={}
 return self
end
function S:Top(stat)return self.Rows[stat]or{}end
function S:Winner(stat)local row=self:Top(stat or'Speed')[1];return row and Players:GetPlayerByUserId(row.UserId),row and row.Score or 0 end
function S:Publish(player)
 if self.Writes[player]or not self.Data:IsLoaded(player)or not self.Data.CanSave[player]or player.UserId<=0 then return end
 self.Writes[player]=true
 for _,spec in ipairs(specs)do
  local value=spec.Stat=='Speed'and self.Data:GetOrCreateSpeedValue(player)or self.Data:GetOrCreateCashValue(player);local key=player.UserId..':'..spec.Stat
  if spec.Stat=='Speed'and value then
   local exact=Points.Normalize(value.Value)
   if self.Last[key]~=exact then
    -- Exact score is durable before its logarithmic sorted index is published.
    local ok=pcall(function()
     self.ExactSpeed:SetAsync(tostring(player.UserId),exact)
     self.Stores.Speed:SetAsync(tostring(player.UserId),math.floor(Points.Log10(exact)*1000000000))
    end)
    if ok then self.Last[key]=exact;self.ExactCache[player.UserId]={Score=exact,At=os.clock()}end
   end
  else
   local n=value and tonumber(value.Value)
   if n and n==n and n>=0 and n<math.huge then
    n=math.floor(math.min(n,require(game:GetService('ReplicatedStorage').EconomyBalance90).MaxCash))
    if self.Last[key]~=n then local ok=pcall(self.Stores[spec.Stat].SetAsync,self.Stores[spec.Stat],tostring(player.UserId),n);if ok then self.Last[key]=n end end
   end
  end
 end
 self.Writes[player]=nil
end
local function label(parent,name,text,pos,size,font,color)
 local t=Instance.new('TextLabel');t.Name=name;t.Text=text;t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.Font=Enum.Font.FredokaOne;t.TextColor3=color;t.TextScaled=true;t.TextTruncate=Enum.TextTruncate.AtEnd;t.TextXAlignment=Enum.TextXAlignment.Left;t.Parent=parent
 local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=font;fit.MinTextSize=15;fit.Parent=t;return t
end
function S:_build(spec,gui)
 for _,c in ipairs(gui:GetChildren())do c:Destroy()end
 gui.CanvasSize=Vector2.new(720,1040);gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.LightInfluence=0;gui.Active=true
 local root=Instance.new('Frame');root.Size=UDim2.fromScale(1,1);root.BackgroundColor3=Color3.fromRGB(29,40,56);root.BorderSizePixel=0;root.Parent=gui
 local title=label(root,'Title',spec.Title,UDim2.fromOffset(24,12),UDim2.new(1,-48,0,65),62,Color3.fromRGB(160,255,77));title.TextXAlignment=Enum.TextXAlignment.Center
 local scope=label(root,'Scope','GLOBAL • LOADING',UDim2.fromOffset(24,82),UDim2.new(1,-48,0,32),22,Color3.fromRGB(205,232,249));scope.TextXAlignment=Enum.TextXAlignment.Center
 local list=Instance.new('ScrollingFrame');list.Name='Ranks';list.Position=UDim2.fromOffset(16,130);list.Size=UDim2.new(1,-32,1,-146);list.CanvasSize=UDim2.new();list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=8;list.Parent=root
 local empty=label(root,'Status','Loading global rankings…',UDim2.new(0,30,.45,0),UDim2.new(1,-60,0,80),30,Color3.new(1,1,1));empty.TextWrapped=true;empty.TextXAlignment=Enum.TextXAlignment.Center
 return{Gui=gui,List=list,Scope=scope,Empty=empty,Rows={}}
end
function S:_row(state,i,spec)
 if state.Rows[i]then return state.Rows[i]end
 local card=Instance.new('Frame');card.Name='Rank'..i;card.Position=UDim2.fromOffset(0,(i-1)*108);card.Size=UDim2.new(1,-12,0,98);card.BackgroundColor3=Color3.fromRGB(249,251,252);card.BorderSizePixel=0;card.Parent=state.List
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,10);corner.Parent=card
 local avatar=Instance.new('ImageLabel');avatar.Name='Portrait';avatar.Position=UDim2.fromOffset(8,7);avatar.Size=UDim2.fromOffset(84,84);avatar.BackgroundColor3=Color3.fromRGB(201,223,241);avatar.BorderSizePixel=0;avatar.Parent=card
 label(card,'Rank','#'..i,UDim2.fromOffset(101,6),UDim2.fromOffset(75,24),23,Color3.fromRGB(60,104,132))
 local name=label(card,'DisplayName','',UDim2.fromOffset(101,33),UDim2.new(1,-299,0,43),32,Color3.fromRGB(20,27,31))
 local badge=Instance.new('Frame');badge.Position=UDim2.new(1,-186,0,9);badge.Size=UDim2.fromOffset(174,32);badge.BackgroundColor3=Color3.fromRGB(109,210,70);badge.BorderSizePixel=0;badge.Parent=card
 local b=label(badge,'Type',spec.Badge,UDim2.fromOffset(6,0),UDim2.new(1,-12,1,0),24,Color3.fromRGB(16,54,21));b.TextXAlignment=Enum.TextXAlignment.Center
 local score=label(card,'Score','',UDim2.new(1,-192,0,48),UDim2.fromOffset(180,38),31,Color3.fromRGB(20,27,31));score.TextXAlignment=Enum.TextXAlignment.Center
 local row={Frame=card,Avatar=avatar,Name=name,Score=score};state.Rows[i]=row;return row
end
function S:Render()
 local map=workspace:FindFirstChild('ChestChaseMap');local hub=map and map:FindFirstChild('EconomyHub');local scenery=hub and hub:FindFirstChild('GeneratedHubScenery');if not scenery then return end
 for _,spec in ipairs(specs)do
  for _,model in ipairs(scenery:GetChildren())do if model:GetAttribute('SceneryKey')==spec.Key and model:GetAttribute('SceneryOwner')=='ChestChase'then
   Landscape.Apply(model);local board=model:FindFirstChild('Board');local gui=board and board:FindFirstChild('Display');if not gui then continue end
   local state=self.Boards[spec.Key];if not state or state.Gui~=gui then state=self:_build(spec,gui);self.Boards[spec.Key]=state end
   local rows=self:Top(spec.Stat);state.Empty.Visible=#rows==0
   state.Empty.Text=self.Failed[spec.Stat]and'Global rankings unavailable. Retrying…'or self.Updated[spec.Stat]and'Be the first to rank!'or'Loading global rankings…'
   state.Scope.Text=self.Failed[spec.Stat]and'GLOBAL • RETRYING UPDATE'or'GLOBAL • UPDATES EVERY MINUTE'
   -- Rows for every player's own scrollable board (LeaderboardClient). The server sign keeps a short top 10 fallback.
   local packed={}
   for i,entry in ipairs(rows)do local info=self.Names[entry.UserId];packed[i]={u=entry.UserId,n=info and info.DisplayName or('Player '..entry.UserId),s=spec.Prefix..Cash.Compact(entry.Score)}end
   local okJson,json=pcall(Http.JSONEncode,Http,packed)
   model:SetAttribute('LeaderboardTitle',spec.Title);model:SetAttribute('LeaderboardBadge',spec.Badge)
   model:SetAttribute('LeaderboardStatus',self.Failed[spec.Stat]and'retry'or self.Updated[spec.Stat]and'ok'or'loading')
   model:SetAttribute('LeaderboardUpdated',self.Updated[spec.Stat]or 0)
   if okJson then model:SetAttribute('LeaderboardRows',json)end
   local shown=math.min(#rows,S.ServerRows)
   state.List.CanvasSize=UDim2.fromOffset(0,shown*108)
   for i,entry in ipairs(rows)do if i>shown then break end;local row=self:_row(state,i,spec);row.Frame.Visible=true;local info=self.Names[entry.UserId];row.Name.Text=info and info.DisplayName or('Player '..entry.UserId);row.Avatar.Image='rbxthumb://type=AvatarHeadShot&id='..entry.UserId..'&w=150&h=150';row.Score.Text=spec.Prefix..Cash.Compact(entry.Score)end
   for i=shown+1,#state.Rows do state.Rows[i].Frame.Visible=false end
  end end
 end
end
function S:Refresh()
 if self.Refreshing then return end;self.Refreshing=true
 local wanted,seen={},{}
 for _,spec in ipairs(specs)do
  -- R118: top 100 on both boards (players scroll the board on their own screen, LeaderboardClient).
  local ok,pages=pcall(self.Stores[spec.Stat].GetSortedAsync,self.Stores[spec.Stat],false,S.Size)
  self.Failed[spec.Stat]=not ok
  if ok then
   local rows={};local complete=true;local reads=0
   for _,entry in ipairs(pages:GetCurrentPage())do
    local id=tonumber(entry.key);local score=entry.value
    if id and id>0 then
     if spec.Stat=='Speed'then
      -- The sorted value is log10(points) x 1e9, precise enough for the board's short number. Only the top 10 read
      -- the exact store, and only when their sorted value changed, to stay inside the DataStore read budget.
      local cached=self.ExactCache[id];local index=tonumber(score)or 0
      if #rows<10 and(not cached or cached.Index~=index)and reads<12 then
       reads+=1
       local readOK,exact=pcall(self.ExactSpeed.GetAsync,self.ExactSpeed,tostring(id))
       if readOK and Points.Valid(exact)then cached={Score=exact,At=os.clock(),Index=index};self.ExactCache[id]=cached
       elseif not readOK then complete=false end
      end
      score=cached and cached.Index==index and cached.Score or S.FromLog(index/1000000000)
     end
     if score~=nil then table.insert(rows,{UserId=id,Score=score})end
    end
   end
   if spec.Stat=='Speed'then table.sort(rows,function(a,b)local c=Points.Compare(a.Score,b.Score);return c==0 and a.UserId<b.UserId or c>0 end)end
   while #rows>S.Size do table.remove(rows)end
   if not complete then self.Failed[spec.Stat]=true end
   for _,row in ipairs(rows)do local id=row.UserId;if not self.Names[id]and not seen[id]then seen[id]=true;table.insert(wanted,id)end end
   self.Rows[spec.Stat]=rows;self.Updated[spec.Stat]=os.time()
  end
 end
 if #wanted>0 then local ok,infos=pcall(Users.GetUserInfosByUserIdsAsync,Users,wanted);if ok then for _,info in ipairs(infos)do self.Names[info.Id]=info end end end
 self.Refreshing=false;if not self.Stopped then self:Render()end
end
function S:Start()
 self:Render();task.spawn(function()while not self.Stopped do
  for _,player in ipairs(Players:GetPlayers())do task.spawn(function()self:Publish(player)end)end
  self:Refresh();for _=1,60 do if self.Stopped then return end;task.wait(1)end
 end end)
end
function S:Destroy()
 self.Stopped=true
 for _,p in ipairs(Players:GetPlayers())do task.spawn(function()self:Publish(p)end)end
end
return S
