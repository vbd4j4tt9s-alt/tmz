-- All top-of-screen notices use the same layout. Five direct lookups, no GUI descendant sweeps.
local Players=game:GetService('Players');local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage');local Gui=game:GetService('GuiService')
local Fit=require(RS:WaitForChild('GardenTextFit'));local Layout=require(RS:WaitForChild('HudNoticeLayout'));local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local elapsed=0;local connections={}
local cached={};local inputs
local function object(gui,name)
 local root=pg:FindFirstChild(gui);if root and root:IsA('ScreenGui')then root.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end;local key=gui..'/'..name;local c=cached[key]
 if c and c.Root==root and c.Item and c.Item.Parent and c.Item:IsDescendantOf(root)then return c.Item end
 local item=root and root:FindFirstChild(name,true);cached[key]={Root=root,Item=item};return item
end
local function unchanged(values)
 local same=inputs~=nil
 if same then for i,v in ipairs(values)do if inputs[i]~=v then same=false;break end end end
 inputs=values;return same
end
local slots=setmetatable({},{__mode='k'})
local function slot(x,on)
 if not x then return end
 local wrap=slots[x]
 if not wrap then
  wrap=Instance.new('Frame');wrap.Name='NoticeSlot';wrap.BackgroundTransparency=1;wrap.BorderSizePixel=0;wrap.Size=UDim2.fromScale(1,1);wrap.Active=false;wrap.Parent=x.Parent;x.Parent=wrap;slots[x]=wrap
 end
 if wrap.Visible~=on then wrap.Visible=on end
end
local function textVisible(x)return x and x.Visible and x.Text~=''and x.TextTransparency<.98 end
local function put(x,r)
 if not x or not r then return end
 x.AnchorPoint=Vector2.new(.5,0)
 local p,z=x.Position,x.Size
 if p.X.Scale~=0 or p.X.Offset~=r.X or p.Y.Scale~=0 or p.Y.Offset~=r.Y then x.Position=UDim2.fromOffset(r.X,r.Y)end
 if z.X.Scale~=0 or z.X.Offset~=r.Width or z.Y.Scale~=0 or z.Y.Offset~=r.Height then x.Size=UDim2.fromOffset(r.Width,r.Height)end
 if x:GetAttribute('NoticeTextSize')~=r.Font then x:SetAttribute('NoticeTextSize',r.Font);Fit.Attach(x,r.Font,12)end
 if x.TextXAlignment~=Enum.TextXAlignment.Center then x.TextXAlignment=Enum.TextXAlignment.Center end
end
local function update()
 local camera=workspace.CurrentCamera;if not camera then return end
 local safe=Gui:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets);local view=Vector2.new(safe.Width,safe.Height);local top=0
 local nav=object('ChestEconomyTopBar','StationTravel')
 if nav and nav.Visible then top=math.max(top,nav.AbsolutePosition.Y+nav.AbsoluteSize.Y)end
 local biome=object('BiomeEntryUI','BiomeTitle');local run=object('ChestRunAlertUI','RunWarning');local banner=object('ChestChaseBanner','Message')
 local feedback=object('ChestEconomyUI','GardenFeedback');local shovel=object('GardenShovelUI','ShovelFeedback')
 local flags={Biome=biome and biome.Visible,Run=run and run.Visible,Banner=textVisible(banner),Feedback=textVisible(feedback),Shovel=textVisible(shovel),Modal=pg:GetAttribute('SeedMenu')~=nil}
 if unchanged({view.X,view.Y,top,biome or false,run or false,banner or false,feedback or false,shovel or false,flags.Biome or false,flags.Run or false,flags.Banner or false,flags.Feedback or false,flags.Shovel or false,flags.Modal})then return end
 local boxes=Layout.Calculate(view.X,view.Y,top,flags)
 slot(biome,boxes.Biome~=nil);slot(run,boxes.Run~=nil);slot(banner,boxes.Banner~=nil);slot(feedback,boxes.Feedback~=nil);slot(shovel,boxes.Shovel~=nil)
 if boxes.Biome then
  local r=boxes.Biome;local scale=biome:FindFirstChildOfClass('UIScale');local fit=math.min(r.Width/490,r.Height/110)
  biome.AnchorPoint=Vector2.new(.5,0);biome.Position=UDim2.fromOffset(r.X,r.Y);biome:SetAttribute('NoticeFit',fit)
  if scale and scale.Scale>fit then scale.Scale=fit end
 end
 put(run,boxes.Run);put(banner,boxes.Banner);put(feedback,boxes.Feedback);put(shovel,boxes.Shovel)
 if pg:GetAttribute('HudNoticeBottom')~=boxes.Bottom then pg:SetAttribute('HudNoticeBottom',boxes.Bottom)end
end
connections[1]=Run.Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed>=.1 then elapsed=0;update()end end)
connections[2]=pg.ChildAdded:Connect(function()task.defer(update)end);connections[3]=pg.ChildRemoved:Connect(function()task.defer(update)end);connections[4]=pg:GetAttributeChangedSignal('SeedMenu'):Connect(update)
update()
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end;pg:SetAttribute('HudNoticeBottom',nil)end)
