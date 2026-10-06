do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- Local signs for the nearest two gardens; nothing overlaps beds or upgrade buttons.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local Run=game:GetService('RunService')
local Rules=require(RS.GardenBonusRules84);local Art=require(RS.HudArtwork)
local records={};local elapsed=0
local function clear(board)local r=records[board];if r then r.Gui:Destroy();records[board]=nil end end
local function text(parent,name,x,y,w,h,size,color)
 local t=Instance.new('TextLabel');t.Name=name;t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);t.BackgroundTransparency=1;t.Font=Enum.Font.FredokaOne;t.TextSize=size;t.TextColor3=color;t.TextStrokeTransparency=.6;t.Text='';t.Parent=parent;return t
end
local function build(board)
 local gui=Instance.new('SurfaceGui');gui.Name='GardenBonusDisplay84';gui.Adornee=board;gui.Face=Enum.NormalId.Back;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=Vector2.new(760,208);gui.LightInfluence=0;gui.MaxDistance=140;gui.Parent=board
 local title=text(gui,'Title',10,5,740,38,30,Color3.fromRGB(240,235,207));title.Text='GARDEN BONUSES'
 local labels={}
 for i,key in ipairs({'GardenSize','GardenTime'})do
  local x=18+(i-1)*375
  local f=Instance.new('Frame');f.BackgroundTransparency=1;f.Position=UDim2.fromOffset(x,48);f.Size=UDim2.fromOffset(96,100);f.Parent=gui;Art.Attach(f,key)
  local caption=text(gui,key..'Caption',x+106,48,225,32,25,Color3.fromRGB(207,225,204));caption.Text=i==1 and'PLANT SIZE'or'GROW TIME'
  labels[i]=text(gui,key..'Value',x+106,78,225,65,53,i==1 and Color3.fromRGB(168,249,135)or Color3.fromRGB(139,234,239))
 end
 local note=text(gui,'Sources',12,160,736,39,21,Color3.fromRGB(239,224,167));note.TextWrapped=true
 records[board]={Gui=gui,Labels=labels,Note=note};return records[board]
end
local function step()
 local map=workspace:FindFirstChild('ChestChaseMap');local bases=map and map:FindFirstChild('Bases');local camera=workspace.CurrentCamera
 if not bases or not camera then return end
 local candidates={}
 for _,base in ipairs(bases:GetChildren())do
  local owner=Players:GetPlayerByUserId(base:GetAttribute('BaseOwnerUserId')or 0)
  local fence=base:FindFirstChild('GardenFence34');local board=fence and fence:FindFirstChild('Garden bonus board')
  if owner and board then local d=(board.Position-camera.CFrame.Position).Magnitude;if d<=140 then candidates[#candidates+1]={Board=board,Owner=owner,Distance=d}end end
 end
 table.sort(candidates,function(a,b)return a.Distance<b.Distance end)
 local wanted={}
 for i=1,math.min(2,#candidates)do
  local c=candidates[i];wanted[c.Board]=true;local r=records[c.Board]or build(c.Board)
  local b=Rules.Read(c.Owner:GetAttribute('FenceTier'),c.Owner:GetAttribute('DoubleGrowthOwned')==true)
  r.Labels[1].Text='×'..Rules.Number(b.Size);r.Labels[2].Text='×'..Rules.Number(b.Time)
  r.Note.Text='Fence: +'..Rules.Number(b.FenceSize*100)..'% size · −'..Rules.Number(b.FenceReduction*100)..'% time'..(b.Growth==2 and'  |  2× growth' or'')
 end
 for board in pairs(records)do if not wanted[board]or not board.Parent then clear(board)end end
end
local connection=Run.Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed>=.5 then elapsed=0;step()end end)
script.Destroying:Connect(function()connection:Disconnect();for board in pairs(records)do clear(board)end end)
