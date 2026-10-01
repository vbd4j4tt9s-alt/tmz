-- R118: the hub's global leaderboards, drawn on each player's own screen so they can be scrolled (top 100).
-- A SurfaceGui inside Workspace cannot take input, so this one lives in PlayerGui with Adornee = the board part.
-- Data comes from SpeedBoardService (attributes on the board model); the server's own sign is hidden locally.
-- Only the rows on screen exist (a small pool of row frames is reused while scrolling), so 100 rows stay cheap.
local Players=game:GetService('Players');local Http=game:GetService('HttpService');local Tween=game:GetService('TweenService')
local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local RGB=Color3.fromRGB
local W,H=720,1040;local HEAD=150;local FOOT=96;local ROW=92;local GAP=8;local STRIDE=ROW+GAP
local MEDAL={{RGB(255,214,74),RGB(255,170,30),'🥇'},{RGB(222,232,242),RGB(160,178,196),'🥈'},{RGB(243,170,104),RGB(196,112,56),'🥉'}}
local boards={};local connections={};local dead=false
local function make(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function corner(o,r)make('UICorner',{CornerRadius=UDim.new(0,r)},o)end
local function text(parent,name,pos,size,maxSize,color,align)
 local t=make('TextLabel',{Name=name,Position=pos,Size=size,BackgroundTransparency=1,Font=Enum.Font.FredokaOne,TextColor3=color,TextScaled=true,
  TextXAlignment=align or Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text=''},parent)
 make('UITextSizeConstraint',{MaxTextSize=maxSize,MinTextSize=12},t);return t
end
local function ago(at)
 if type(at)~='number'or at<=0 then return'LOADING'end
 local s=math.max(0,os.time()-at);if s<60 then return'UPDATED JUST NOW'end
 return('UPDATED %d MIN AGO'):format(math.floor(s/60))
end
local function build(model,board,server)
 local gui=make('SurfaceGui',{Name='Leaderboard_'..(model:GetAttribute('SceneryKey')or model.Name),Adornee=board,Face=server.Face,
  SizingMode=Enum.SurfaceGuiSizingMode.FixedSize,CanvasSize=Vector2.new(W,H),LightInfluence=0,MaxDistance=150,ResetOnSpawn=false,
  ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
 local root=make('Frame',{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},gui)
 make('UIGradient',{Color=ColorSequence.new(RGB(33,46,78),RGB(18,24,40)),Rotation=90},root)
 -- Header: title, badge line and a soft glow band.
 local head=make('Frame',{Name='Header',Size=UDim2.new(1,0,0,HEAD),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},root)
 make('UIGradient',{Color=ColorSequence.new(RGB(92,214,104),RGB(44,150,86)),Rotation=90},head)
 make('Frame',{Name='Shine',Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,HEAD*.45),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.82,BorderSizePixel=0},head)
 local title=text(head,'Title',UDim2.fromOffset(20,14),UDim2.new(1,-40,0,72),64,Color3.new(1,1,1),Enum.TextXAlignment.Center)
 make('UIStroke',{Color=RGB(16,60,30),Thickness=3},title)
 local scope=text(head,'Scope',UDim2.fromOffset(20,92),UDim2.new(1,-40,0,40),26,RGB(230,255,232),Enum.TextXAlignment.Center)
 -- List.
 local list=make('ScrollingFrame',{Name='Ranks',Position=UDim2.fromOffset(14,HEAD+12),Size=UDim2.new(1,-28,1,-(HEAD+FOOT+24)),BackgroundTransparency=1,
  BorderSizePixel=0,ScrollBarThickness=14,ScrollBarImageColor3=RGB(120,220,140),ScrollingDirection=Enum.ScrollingDirection.Y,
  ElasticBehavior=Enum.ElasticBehavior.Always,CanvasSize=UDim2.new(),Active=true},root)
 local status=text(root,'Status',UDim2.new(0,40,.42,0),UDim2.new(1,-80,0,80),32,Color3.new(1,1,1),Enum.TextXAlignment.Center);status.TextWrapped=true
 -- Footer: your rank, and a button that scrolls to you (or back to the top).
 local foot=make('Frame',{Name='Footer',Position=UDim2.new(0,14,1,-(FOOT+6)),Size=UDim2.new(1,-28,0,FOOT),BackgroundColor3=RGB(255,255,255),BorderSizePixel=0},root)
 make('UIGradient',{Color=ColorSequence.new(RGB(64,88,140),RGB(40,56,96)),Rotation=90},foot);corner(foot,14)
 make('UIStroke',{Color=RGB(140,220,255),Thickness=2,Transparency=.3},foot)
 local mine=text(foot,'YourRank',UDim2.fromOffset(20,12),UDim2.new(1,-250,1,-24),34,Color3.new(1,1,1))
 local jump=make('TextButton',{Name='JumpToMe',AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-14,.5,0),Size=UDim2.fromOffset(210,64),
  BackgroundColor3=RGB(255,255,255),AutoButtonColor=true,Text='',BorderSizePixel=0},foot)
 make('UIGradient',{Color=ColorSequence.new(RGB(255,224,96),RGB(240,164,40)),Rotation=90},jump);corner(jump,12)
 make('UIStroke',{Color=RGB(90,52,10),Thickness=2},jump)
 local jumpText=text(jump,'Caption',UDim2.fromOffset(8,0),UDim2.new(1,-16,1,0),30,RGB(70,38,6),Enum.TextXAlignment.Center)
 local b={Model=model,Board=board,Server=server,Gui=gui,List=list,Title=title,Scope=scope,Status=status,Mine=mine,Jump=jump,JumpText=jumpText,
  Rows={},Pool={},Data={},Me=nil,Connections={}}
 return b
end
local function slot(b)
 local card=make('Frame',{Name='Rank',Size=UDim2.new(1,-20,0,ROW),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Visible=false},b.List);corner(card,12)
 local fill=make('UIGradient',{Rotation=90},card)
 local outline=make('UIStroke',{Thickness=3,Color=RGB(98,236,120),Transparency=1},card)
 local medal=make('Frame',{Name='Medal',Position=UDim2.fromOffset(10,(ROW-62)/2),Size=UDim2.fromOffset(62,62),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},card);corner(medal,31)
 local medalFill=make('UIGradient',{Rotation=90},medal)
 local rank=text(medal,'Rank',UDim2.fromOffset(4,6),UDim2.new(1,-8,1,-12),30,RGB(30,40,56),Enum.TextXAlignment.Center)
 local avatar=make('ImageLabel',{Name='Portrait',Position=UDim2.fromOffset(82,(ROW-74)/2),Size=UDim2.fromOffset(74,74),BackgroundColor3=RGB(201,223,241),BorderSizePixel=0},card);corner(avatar,37)
 local name=text(card,'DisplayName',UDim2.fromOffset(168,14),UDim2.new(1,-390,0,40),34,RGB(20,27,31))
 local you=text(card,'You',UDim2.fromOffset(168,54),UDim2.fromOffset(120,26),22,RGB(36,150,60))
 local score=text(card,'Score',UDim2.new(1,-214,0,(ROW-48)/2),UDim2.fromOffset(200,48),38,RGB(24,110,52),Enum.TextXAlignment.Right)
 return {Card=card,Fill=fill,Outline=outline,Medal=medal,MedalFill=medalFill,Rank=rank,Avatar=avatar,Name=name,You=you,Score=score,Index=nil}
end
local function paintRow(b,r,i)
 local entry=b.Data[i];r.Index=i
 r.Card.Position=UDim2.fromOffset(4,(i-1)*STRIDE);r.Card.Visible=true
 local medal=MEDAL[i];local isMe=entry.u==player.UserId
 if medal then r.Fill.Color=ColorSequence.new(medal[1]:Lerp(Color3.new(1,1,1),.45),medal[1]);r.MedalFill.Color=ColorSequence.new(medal[1],medal[2]);r.Rank.Text=medal[3]
 else
  local base=i%2==0 and RGB(236,244,252)or RGB(250,252,255)
  r.Fill.Color=ColorSequence.new(base,base:Lerp(RGB(200,220,240),.35));r.MedalFill.Color=ColorSequence.new(RGB(92,124,170),RGB(62,90,136));r.Rank.Text='#'..i
 end
 r.Rank.TextColor3=medal and RGB(60,40,10)or Color3.new(1,1,1)
 r.Outline.Transparency=isMe and 0 or(medal and .35 or 1);r.Outline.Color=isMe and RGB(60,220,96)or(medal and medal[2]or RGB(0,0,0))
 r.You.Text=isMe and'⭐ YOU'or'';r.Name.Text=tostring(entry.n or'');r.Score.Text=tostring(entry.s or'')
 local image='rbxthumb://type=AvatarHeadShot&id='..tostring(entry.u)..'&w=150&h=150';if r.Avatar.Image~=image then r.Avatar.Image=image end
end
-- Reuse a handful of row frames for whatever part of the list is on screen.
local function layoutRows(b)
 local count=#b.Data;b.List.CanvasSize=UDim2.fromOffset(0,math.max(0,count*STRIDE))
 local view=b.List.AbsoluteWindowSize.Y;if view<=0 then view=H-(HEAD+FOOT+24)end
 local first=math.max(1,math.floor(b.List.CanvasPosition.Y/STRIDE));local last=math.min(count,first+math.ceil(view/STRIDE)+2)
 -- Release rows that left the window first, so a long jump reuses them instead of growing the pool.
 for i,r in pairs(b.Rows)do if i<first or i>last then r.Card.Visible=false;b.Rows[i]=nil;table.insert(b.Pool,r)end end
 for i=first,last do
  local r=b.Rows[i]
  if not r then r=table.remove(b.Pool)or slot(b);b.Rows[i]=r end
  paintRow(b,r,i)
 end
end
local function refreshData(b)
 local raw=b.Model:GetAttribute('LeaderboardRows');local ok,rows=false,nil
 if type(raw)=='string'then ok,rows=pcall(Http.JSONDecode,Http,raw)end
 b.Data=ok and type(rows)=='table'and rows or{}
 b.Title.Text=tostring(b.Model:GetAttribute('LeaderboardTitle')or'LEADERBOARD')
 local state=b.Model:GetAttribute('LeaderboardStatus')
 b.Scope.Text='🌍 GLOBAL TOP '..#b.Data..' • '..(state=='retry'and'RETRYING'or ago(b.Model:GetAttribute('LeaderboardUpdated')))
 b.Status.Visible=#b.Data==0
 b.Status.Text=state=='retry'and'Global rankings unavailable. Retrying…'or state=='ok'and'Be the first to rank!'or'Loading global rankings…'
 b.Me=nil;for i,entry in ipairs(b.Data)do if entry.u==player.UserId then b.Me=i;break end end
 b.Mine.Text=b.Me and('YOUR RANK  #'..b.Me)or'Not in the top '..math.max(100,#b.Data)..' yet - keep going!'
 b.JumpText.Text=b.Me and'FIND ME'or'TOP'
 layoutRows(b)
end
local function scrollTo(b,y)
 y=math.clamp(y,0,math.max(0,b.List.AbsoluteCanvasSize.Y-b.List.AbsoluteWindowSize.Y))
 if GuiService.ReducedMotionEnabled then b.List.CanvasPosition=Vector2.new(0,y)
 else Tween:Create(b.List,TweenInfo.new(.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CanvasPosition=Vector2.new(0,y)}):Play()end
end
local function attach(model)
 if boards[model]or dead then return end
 local board=model:FindFirstChild('Board');local server=board and board:FindFirstChild('Display')
 if not board or not server or not server:IsA('SurfaceGui')then return end
 local b=build(model,board,server);boards[model]=b
 server.Enabled=false -- local only: everyone sees their own scrollable copy instead
 local function on(signal,fn)table.insert(b.Connections,signal:Connect(fn))end
 for _,key in ipairs({'LeaderboardRows','LeaderboardStatus','LeaderboardUpdated','LeaderboardTitle'})do on(model:GetAttributeChangedSignal(key),function()refreshData(b)end)end
 on(b.List:GetPropertyChangedSignal('CanvasPosition'),function()layoutRows(b)end)
 on(b.List:GetPropertyChangedSignal('AbsoluteWindowSize'),function()layoutRows(b)end)
 on(b.Jump.Activated,function()scrollTo(b,b.Me and(b.Me-1)*STRIDE-STRIDE*2 or 0)end)
 on(server:GetPropertyChangedSignal('Enabled'),function()if server.Enabled then server.Enabled=false end end)
 on(model.AncestryChanged,function()if not model:IsDescendantOf(workspace)then
  for _,c in ipairs(b.Connections)do c:Disconnect()end;b.Gui:Destroy();boards[model]=nil
 end end)
 refreshData(b)
end
-- Boards are found under the hub scenery by the attribute the server publishes; re-checked every few seconds
-- (streaming can add or remove them). Removed boards are cleaned up.
local function prune()
 for model,b in pairs(boards)do if not b.Board.Parent or not b.Server.Parent then for _,c in ipairs(b.Connections)do c:Disconnect()end;b.Gui:Destroy();boards[model]=nil end end
end
local hub;local function findHub()
 local map=workspace:FindFirstChild('ChestChaseMap');local economy=map and map:FindFirstChild('EconomyHub')
 return economy and economy:FindFirstChild('GeneratedHubScenery')
end
task.spawn(function()
 while not dead do
  hub=findHub()
  if hub then
   for _,model in ipairs(hub:GetChildren())do if model:IsA('Model')and model:GetAttribute('LeaderboardRows')~=nil then attach(model)end end
  end
  prune()
  for _,b in pairs(boards)do b.Scope.Text=b.Scope.Text:gsub('UPDATED.*$',ago(b.Model:GetAttribute('LeaderboardUpdated')))end
  task.wait(5)
 end
end)
script.Destroying:Connect(function()
 dead=true
 for model,b in pairs(boards)do for _,c in ipairs(b.Connections)do c:Disconnect()end;b.Gui:Destroy();if b.Server.Parent then b.Server.Enabled=true end;boards[model]=nil end
 for _,c in ipairs(connections)do c:Disconnect()end
end)
