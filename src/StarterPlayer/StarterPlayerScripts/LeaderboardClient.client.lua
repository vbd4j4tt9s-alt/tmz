do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R118: the hub's global leaderboards, drawn on each player's own screen so they can be scrolled (top 100).
-- A SurfaceGui inside Workspace cannot take input, so this one lives in PlayerGui with Adornee = the board part.
-- Data comes from SpeedBoardService (attributes on the board model); the server's own sign is hidden locally.
-- Only the rows on screen exist (a small pool of row frames is reused while scrolling), so 100 rows stay cheap.
-- R137 (owner: "i cant seem to scroll down for the leaderboard"): a ScrollingFrame on a board in the world only scrolls
-- by its thin bar (the mouse wheel zooms the camera instead), so the list scrolls itself: ▲ / ▼ page buttons with a
-- thumb, the mouse wheel while you point at the board (the camera does not zoom then), and click / finger drag.
local Players=game:GetService('Players');local Http=game:GetService('HttpService');local Tween=game:GetService('TweenService')
local GuiService=game:GetService('GuiService');local UIS=game:GetService('UserInputService');local CAS=game:GetService('ContextActionService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local RGB=Color3.fromRGB
local W,H=720,1040;local HEAD=150;local FOOT=96;local ROW=92;local GAP=8;local STRIDE=ROW+GAP
local RAIL=82;local VIEW=H-(HEAD+FOOT+24);local ARROW=66;local TRACK=VIEW-2*(ARROW+10);local REACH=150
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
 local list=make('ScrollingFrame',{Name='Ranks',Position=UDim2.fromOffset(14,HEAD+12),Size=UDim2.new(1,-28-RAIL,0,VIEW),BackgroundTransparency=1,
  BorderSizePixel=0,ScrollBarThickness=0,ScrollingEnabled=false,ScrollingDirection=Enum.ScrollingDirection.Y,
  ElasticBehavior=Enum.ElasticBehavior.Never,CanvasSize=UDim2.new(),Active=true},root)
 -- R137: the scroll rail (▲, thumb, ▼) right of the list.
 local rail=make('Frame',{Name='ScrollRail',AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,HEAD+12),Size=UDim2.fromOffset(RAIL-8,VIEW),BackgroundTransparency=1},root)
 local function arrow(name,glyph,y)
  local button=make('TextButton',{Name=name,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,y),Size=UDim2.fromOffset(ARROW,ARROW),
   BackgroundColor3=RGB(255,255,255),AutoButtonColor=true,Text='',BorderSizePixel=0},rail)
  make('UIGradient',{Color=ColorSequence.new(RGB(126,226,146),RGB(52,160,92)),Rotation=90},button);corner(button,16)
  make('UIStroke',{Color=RGB(16,60,30),Thickness=3},button)
  local caption=text(button,'Arrow',UDim2.fromOffset(6,6),UDim2.new(1,-12,1,-12),40,Color3.new(1,1,1),Enum.TextXAlignment.Center);caption.Text=glyph
  make('UIStroke',{Color=RGB(16,60,30),Thickness=2},caption)
  return button,caption
 end
 local up,upArrow=arrow('PageUp','▲',0);local down,downArrow=arrow('PageDown','▼',VIEW-ARROW)
 local track=make('Frame',{Name='Track',AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,ARROW+10),Size=UDim2.fromOffset(16,TRACK),
  BackgroundColor3=RGB(8,14,26),BackgroundTransparency=.35,BorderSizePixel=0},rail);corner(track,8)
 local thumb=make('Frame',{Name='Thumb',Size=UDim2.new(1,0,0,TRACK),BackgroundColor3=RGB(130,230,150),BorderSizePixel=0},track);corner(thumb,8)
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
  Up=up,Down=down,UpArrow=upArrow,DownArrow=downArrow,Thumb=thumb,Rows={},Pool={},Data={},Me=nil,Connections={}}
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
local function windowHeight(b)local size=b.List.AbsoluteWindowSize;return size and size.Y>0 and size.Y or VIEW end
local function maxScroll(b)return math.max(0,#b.Data*STRIDE-windowHeight(b))end
-- R137: the thumb shows where you are; an arrow fades when you can't go further that way.
local function paintRail(b)
 local view=windowHeight(b);local most=maxScroll(b);local y=b.List.CanvasPosition.Y
 local size=most>0 and math.max(56,math.floor(TRACK*view/(view+most)))or TRACK
 b.Thumb.Size=UDim2.new(1,0,0,size);b.Thumb.Position=UDim2.fromOffset(0,most>0 and math.floor((TRACK-size)*math.clamp(y/most,0,1))or 0)
 b.UpArrow.TextTransparency=y>.5 and 0 or .6;b.DownArrow.TextTransparency=y<most-.5 and 0 or .6
end
-- Reuse a handful of row frames for whatever part of the list is on screen.
local function layoutRows(b)
 local count=#b.Data;b.List.CanvasSize=UDim2.fromOffset(0,math.max(0,count*STRIDE))
 local view=windowHeight(b)
 local first=math.max(1,math.floor(b.List.CanvasPosition.Y/STRIDE));local last=math.min(count,first+math.ceil(view/STRIDE)+2)
 -- Release rows that left the window first, so a long jump reuses them instead of growing the pool.
 for i,r in pairs(b.Rows)do if i<first or i>last then r.Card.Visible=false;b.Rows[i]=nil;table.insert(b.Pool,r)end end
 for i=first,last do
  local r=b.Rows[i]
  if not r then r=table.remove(b.Pool)or slot(b);b.Rows[i]=r end
  paintRow(b,r,i)
 end
 paintRail(b)
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
local function scrollTo(b,y,seconds)
 y=math.clamp(y,0,maxScroll(b))
 if b.Tween then b.Tween:Cancel();b.Tween=nil end
 if GuiService.ReducedMotionEnabled or seconds==0 then b.List.CanvasPosition=Vector2.new(0,y)
 else b.Tween=Tween:Create(b.List,TweenInfo.new(seconds or .45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CanvasPosition=Vector2.new(0,y)});b.Tween:Play()end
 b.Target=y
end
-- Where the list is heading: the running scroll's target (so quick clicks / wheel notches add up), else where it is.
local function heading(b)
 if b.Tween and b.Target and b.Tween.PlaybackState==Enum.PlaybackState.Playing then return b.Target end
 return b.List.CanvasPosition.Y
end
local function page(b,direction)
 scrollTo(b,heading(b)+direction*math.max(STRIDE,windowHeight(b)-STRIDE),.3)
end
-- R137: where a screen point lands on a board's display (pixel y on its SurfaceGui, 0 = top), from the board's own
-- plane (no raycast, so a drag keeps working when the pointer slides off). Front/Back displays only.
local function boardPoint(b,position)
 local camera=workspace.CurrentCamera;if not camera or not b.Board.Parent then return nil end
 local face=b.Server.Face;local cf=b.Board.CFrame;local size=b.Board.Size
 local normal=face==Enum.NormalId.Front and cf.LookVector or face==Enum.NormalId.Back and-cf.LookVector or nil
 if not normal then return nil end
 local ray=camera:ScreenPointToRay(position.X,position.Y)
 local facing=ray.Direction:Dot(normal);if facing>=0 then return nil end
 local t=(cf.Position+normal*(size.Z/2)-ray.Origin):Dot(normal)/facing
 if t<=0 or t>REACH then return nil end
 local hit=ray.Origin+ray.Direction*t;local offset=hit-cf.Position
 local x,yUp=offset:Dot(cf.RightVector),offset:Dot(cf.UpVector)
 return(size.Y/2-yUp)/size.Y*H,math.abs(x)<=size.X/2 and math.abs(yUp)<=size.Y/2,ray,t
end
-- The board a screen point is on (nothing in the way), and the pixel y there.
local function pick(position)
 for _,b in pairs(boards)do
  local y,inside,ray,t=boardPoint(b,position)
  if y and inside then
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character}
   local hit=workspace:Raycast(ray.Origin,ray.Direction*(t-.05),params)
   if not hit or hit.Instance:IsDescendantOf(b.Model)then return b,y end
  end
 end
 return nil
end
local drag=nil
local function onWheel(_,state,input)
 if state~=Enum.UserInputState.Change or input.Position.Z==0 then return Enum.ContextActionResult.Pass end
 local b=pick(input.Position);if not b then return Enum.ContextActionResult.Pass end
 scrollTo(b,heading(b)-input.Position.Z*STRIDE*1.5,.15)
 return Enum.ContextActionResult.Sink -- the camera does not zoom while you scroll the board
end
local function pointerDown(input)
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 local b,y=pick(input.Position);if not b then return end
 drag={Board=b,Input=input,From=y,Start=b.List.CanvasPosition.Y,Moved=false}
end
local function pointerMove(input)
 if not drag then return end
 local mouse=drag.Input.UserInputType==Enum.UserInputType.MouseButton1
 if not(input==drag.Input or mouse and input.UserInputType==Enum.UserInputType.MouseMovement)then return end
 local y=boardPoint(drag.Board,input.Position);if not y then return end
 local moved=drag.From-y
 if not drag.Moved and math.abs(moved)>10 then drag.Moved=true end
 if drag.Moved then scrollTo(drag.Board,drag.Start+moved,0)end
end
local function pointerUp(input)
 if drag and(input==drag.Input or input.UserInputType==drag.Input.UserInputType)then drag=nil end
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
 on(b.Up.Activated,function()page(b,-1)end);on(b.Down.Activated,function()page(b,1)end)
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
CAS:BindActionAtPriority('LeaderboardScroll',onWheel,false,Enum.ContextActionPriority.High.Value,Enum.UserInputType.MouseWheel)
table.insert(connections,UIS.InputBegan:Connect(pointerDown))
table.insert(connections,UIS.InputChanged:Connect(pointerMove))
table.insert(connections,UIS.InputEnded:Connect(pointerUp))
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
 dead=true;drag=nil;CAS:UnbindAction('LeaderboardScroll')
 for model,b in pairs(boards)do for _,c in ipairs(b.Connections)do c:Disconnect()end;b.Gui:Destroy();if b.Server.Parent then b.Server.Enabled=true end;boards[model]=nil end
 for _,c in ipairs(connections)do c:Disconnect()end
end)
