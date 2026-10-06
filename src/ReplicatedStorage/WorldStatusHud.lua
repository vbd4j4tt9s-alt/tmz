-- R71: distinct icon-only boosts; the refresh timer uses the existing night moon.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Input=game:GetService('UserInputService');local Gui=game:GetService('GuiService');local Tween=game:GetService('TweenService')
local Layout=require(RS.HudLayout);local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI);local State=require(RS.WorldStatusState);local Balance=require(RS.BalanceRules)
-- R123: the timed x2 boost (and its SpeedBoost module) was removed; the boost is always off. Clock stays for the timers.
local SpeedBoost={Attribute='SpeedBoostEndsAt'}
function SpeedBoost.PlayerFactor()return 1 end
function SpeedBoost.PlayerRemaining()return 0 end
function SpeedBoost.Clock(seconds)
 seconds=tonumber(seconds)or 0;if seconds~=seconds or seconds==math.huge or seconds==-math.huge then seconds=0 end
 seconds=math.max(0,math.ceil(seconds))
 local h=seconds//3600;local m=(seconds%3600)//60;local s=seconds%60
 if h>0 then return string.format('%dh %dm',h,m)end
 if m>0 then return string.format('%dm %ds',m,s)end
 return string.format('%ds',s)
end
local H={};local C=Color3.fromRGB
function H.Boosts(player)
 local tier=math.clamp(math.floor(tonumber(player:GetAttribute('TreadmillTier'))or 1),1,#Balance.TrainingTiers)
 -- R121: the timed x2 boost multiplies with the permanent pass (same as the server's BaseService).
 local speed=Balance.Training(Balance.TrainingTiers[tier]or 1,player:GetAttribute('TreadmillMultiplier'),player:GetAttribute('DoubleSpeedOwned')==true)*SpeedBoost.PlayerFactor(player)
 local luck=tonumber(player:GetAttribute('ChestLuckMultiplier'))or 1
 if luck~=luck or luck==math.huge or luck==-math.huge then luck=1 end
 return speed,math.clamp(luck,1,require(RS.BalanceValues81).MaxLuck)
end
function H.Multiplier(n)
 if n>=1000 then
  local units={{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}}
  for _,u in ipairs(units)do if n>=u[1]then return '×'..string.format('%.2f',n/u[1]):gsub('0+$',''):gsub('%.$','')..u[2]end end
 end
 return '×'..string.format('%.2f',n):gsub('0+$',''):gsub('%.$','')
end
local colors={Clear=C(255,211,99),Snow=C(183,237,255),Rain=C(94,194,255),Blizzard=C(210,238,255),Thunderstorm=C(186,157,255),Track=C(116,243,180),Refresh=C(255,196,101)}
local function block(parent,name,pos,size,color,radius)
 local f=Instance.new('Frame');f.Name=name;f.Position=pos;f.Size=size;f.BackgroundColor3=color;f.BorderSizePixel=0;f.Active=false;f.Parent=parent;if radius then Theme.Corner(f,radius)end;return f
end
local function label(parent,name,pos,size,font)
 local t=Instance.new('TextLabel');t.Name=name;t.Text='';t.BackgroundTransparency=1;t.Position=pos;t.Size=size;t.TextXAlignment=Enum.TextXAlignment.Left;Bright.Text(t,font);t.Parent=parent;return t
end
local function line(parent,x,y,w,h,angle,color)
 local p=block(parent,'Glyph',UDim2.fromScale(x,y),UDim2.fromScale(w,h),color,2);p.AnchorPoint=Vector2.new(.5,.5);p.Rotation=angle or 0;return p
end
local function icon(parent,kind,color)
 for _,p in ipairs(parent:GetChildren())do p:Destroy()end
 require(RS.HudArtwork).Attach(parent,(kind=='Track'or kind=='Refresh')and'Moon'or'Weather'..kind)
end
function H.Create(pg,player)
 local old=pg:FindFirstChild('WorldStatus');if old then old:Destroy()end
 local gui=Instance.new('ScreenGui');gui.Name='WorldStatus';gui.ResetOnSpawn=false;gui.DisplayOrder=23;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=pg
 local root=block(gui,'StatusStack',UDim2.new(1,-12,1,-22),UDim2.fromOffset(190,82),Color3.new());root.AnchorPoint=Vector2.new(1,1);root.BackgroundTransparency=1
 local scale=Instance.new('UIScale');scale.Parent=root
 local rows={};local connections={};local dead=false;local elapsed=0;local tickFast=false
 for i,name in ipairs({'Weather','Track'})do
  local card=block(root,name,UDim2.fromOffset(0,(i-1)*43),UDim2.new(1,0,0,39),Color3.new(),7);card.BackgroundTransparency=.73
  local glyph=block(card,'Icon',UDim2.fromOffset(7,4),UDim2.fromOffset(30,30),Color3.new());glyph.BackgroundTransparency=1
  local time=label(card,'Time',UDim2.fromOffset(44,1),UDim2.new(1,-51,1,-2),28);time.TextXAlignment=Enum.TextXAlignment.Right;time.TextStrokeTransparency=.08
  rows[name]={Root=card,Glyph=glyph,Time=time}
 end
 -- R122: event notifier card: storm emblem on the left, violet gradient + outline + soft inner glow.
 -- Same 190x39 footprint and positions as before; every addition stays inside the card bounds.
 local special=block(root,'SpecialKeeper',UDim2.fromOffset(0,0),UDim2.fromOffset(190,39),Color3.new(1,1,1),8);special.Visible=false;special.BackgroundTransparency=.08
 Bright.Gradient(special,C(78,44,128),C(22,13,40),0);Bright.Outline(special,C(186,140,255),1.5).Transparency=.15
 local glow=block(special,'Glow',UDim2.fromOffset(0,0),UDim2.fromScale(1,1),C(196,150,255),8);glow.BackgroundTransparency=.82;glow.ZIndex=0
 local fade=Instance.new('UIGradient');fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.35,.7),NumberSequenceKeypoint.new(1,1)});fade.Parent=glow
 local badge=block(special,'IconBadge',UDim2.fromOffset(4,4),UDim2.fromOffset(31,31),C(40,22,70),16);badge.BackgroundTransparency=.25
 local ring=Instance.new('UIStroke');ring.Name='IconRing';ring.Color=C(201,160,255);ring.Thickness=1;ring.Transparency=.3;ring.Parent=badge
 local emblem=block(badge,'Icon',UDim2.fromOffset(1,1),UDim2.new(1,-2,1,-2),Color3.new());emblem.BackgroundTransparency=1
 require(RS.HudArtwork).Attach(emblem,'WeatherThunderstorm')
 local specialTitle=label(special,'Title',UDim2.fromOffset(40,1),UDim2.new(1,-46,0,21),18);specialTitle.Text='THE DARKENED';specialTitle.TextColor3=C(236,216,255);specialTitle.TextXAlignment=Enum.TextXAlignment.Center
 local specialHint=label(special,'Hint',UDim2.fromOffset(40,20),UDim2.new(1,-46,0,16),12);specialHint.TextColor3=C(208,196,234);specialHint.TextXAlignment=Enum.TextXAlignment.Center
 require(RS.GardenTextFit).Attach(specialTitle,18,13);require(RS.GardenTextFit).Attach(specialHint,12,10)
 local boostRows={};local hasBoosts=false
 for i,name in ipairs({'Speed gain','Pack luck'})do
  local card=block(root,i==1 and'SpeedBoost'or'LuckBoost',UDim2.fromOffset(0,(i-1)*43),UDim2.fromOffset(137,39),Color3.new());card.BackgroundTransparency=1;card.Visible=false
  local glyph=block(card,'Icon',UDim2.fromOffset(0,1),UDim2.fromOffset(37,37),Color3.new());glyph.BackgroundTransparency=1
  if i==1 then require(RS.HudArtwork).Attach(glyph,'Bolt')else require(RS.CloverIcon153).Attach(glyph)end -- R153: the luck row shows the 4 Leaf Clover picture (the pass's icon / the owner's drawing / the shapes)
  local value=label(card,'Value',UDim2.fromOffset(39,1),UDim2.fromOffset(94,37),26);value.TextXAlignment=Enum.TextXAlignment.Right
  value.TextColor3=i==1 and C(255,211,99)or C(116,243,180);require(RS.GardenTextFit).Attach(value,26,16)
  boostRows[i]={Root=card,Value=value,Label=name}
 end
 -- R121: x2 Speed boost countdown (bolt + "9m 59s"), shown just above the boost rows while active.
 local boostTimer=block(root,'SpeedBoostTimer',UDim2.fromOffset(0,-43),UDim2.fromOffset(137,39),Color3.new(),7);boostTimer.BackgroundTransparency=.73;boostTimer.Visible=false
 local timerGlyph=block(boostTimer,'Icon',UDim2.fromOffset(4,3),UDim2.fromOffset(33,33),Color3.new());timerGlyph.BackgroundTransparency=1
 require(RS.HudArtwork).Attach(timerGlyph,'Bolt')
 local timerText=label(boostTimer,'Time',UDim2.fromOffset(39,1),UDim2.fromOffset(92,37),26);timerText.TextXAlignment=Enum.TextXAlignment.Right;timerText.TextColor3=C(255,226,40)
 require(RS.GardenTextFit).Attach(timerText,26,14)
 local boostWasActive=false;local updateBoosts
 local function paintBoostTimer(now)
  local remaining=SpeedBoost.PlayerRemaining(player,now)
  local on=remaining>0;boostTimer.Visible=on
  if on then
   local text=SpeedBoost.Clock(remaining);if timerText.Text~=text then timerText.Text=text end
   boostTimer:SetAttribute('AccessibleLabel','x2 Speed boost '..text..' left')
  end
  return on
 end
 local function paint(row,data,key)
  row.Time.Text=data.Time;row.Time.TextColor3=colors[key]or colors.Clear
  row.Root:SetAttribute('AccessibleLabel',data.Title..' '..data.Time)
  if row.Kind~=key then row.Kind=key;icon(row.Glyph,key,colors[key]or colors.Clear);row.Root:SetAttribute('StatusKind',key)end
 end
 local function update(now)
  if dead then return end
  local camera=workspace.CurrentCamera;local viewport=require(RS.HudLayout).Viewport(gui)
  local m=require(RS.HudLayout).Read(viewport,Input.TouchEnabled,Layout.Controls(gui))
  local map=workspace:FindFirstChild('ChestChaseMap');local active=map and map:GetAttribute('VeiledEventActive')==true
  -- R122: between events the same card is the third timer: "ARRIVES IN 3m 12s" (server time VeiledNextAt).
  local nextAt=map and map:GetAttribute('VeiledNextAt');local waitFor=type(nextAt)=='number'and nextAt-(now or workspace:GetServerTimeNow())or nil
  local event=active or(waitFor~=nil and waitFor>0)
  special.Visible=event
  local hint=active and(player:GetAttribute('SpecialKeeperChase84')and'CHASING YOU' or'AT STORM PEAKS')or(event and'COMING IN '..SpeedBoost.Clock(waitFor))or''
  if specialHint.Text~=hint then specialHint.Text=hint end
  special:SetAttribute('AccessibleLabel','The Darkened '..hint:lower())
  scale.Scale=m.StatusScale
  -- R129: plain text rows (no card) on landscape phones; cards everywhere else.
  for _,name in ipairs({'Weather','Track'})do local want=m.StatusPlain and 1 or .73;if rows[name].Root.BackgroundTransparency~=want then rows[name].Root.BackgroundTransparency=want end end
  if m.StatusCorner then
   -- R129 (owner reference): landscape phones: one stack in the bottom-right corner above the jump button:
   -- boosts, then The Darkened card (owner: "together with the other timers"), then the two timers.
   local list={};for _,row in ipairs(boostRows)do if row.Root.Visible then list[#list+1]=row end end
   local y=0
   for _,row in ipairs(list)do row.Root.Position=UDim2.fromOffset(190-137,y);y+=43 end
   if special.Visible then special.Position=UDim2.fromOffset(0,y);y+=43 end
   for _,name in ipairs({'Weather','Track'})do rows[name].Root.Position=UDim2.fromOffset(0,y);rows[name].Root.Size=UDim2.fromOffset(190,39);y+=43 end
   root.Size=UDim2.fromOffset(190,y-4)
  elseif m.Phone then
   local width=m.StatusHorizontal and 388 or 190
   root.Size=UDim2.fromOffset(width,m.StatusHorizontal and 39 or 82)
   for i,name in ipairs({'Weather','Track'})do
    rows[name].Root.Position=UDim2.fromOffset(m.StatusHorizontal and (i-1)*198 or 0,m.StatusHorizontal and 0 or (i-1)*43)
    rows[name].Root.Size=UDim2.fromOffset(190,39)
   end
   -- Boosts and the event stay beside the rail; they never move the timers or balances.
   local belowY=(m.SpeedY+m.WalletHeight+6-m.StatusTop)/m.StatusScale
   for i,row in ipairs(boostRows)do
    row.Root.Position=m.WalletHorizontal and UDim2.fromOffset(width-282+(i-1)*145,belowY)or UDim2.fromOffset(m.StatusSideRight-137,(i-1)*43)
   end
   special.Position=m.WalletHorizontal and UDim2.fromOffset(width-480,belowY)or UDim2.fromOffset(m.StatusSideRight-190,86)
  else
   local offset=event and 43 or 0
   local stacked=m.StatusStacked and hasBoosts
   root.Size=UDim2.fromOffset(hasBoosts and not stacked and 337 or 190,82+offset+(stacked and 86 or 0));
   special.Position=UDim2.fromOffset(hasBoosts and not stacked and 147 or 0,0)
   for i,row in ipairs(boostRows)do row.Root.Position=UDim2.fromOffset(stacked and 26 or 0,offset+(i-1)*43)end
   scale.Scale=m.StatusScale
   for i,name in ipairs({'Weather','Track'})do
   rows[name].Root.Position=UDim2.fromOffset(hasBoosts and not stacked and 147 or 0,offset+(stacked and 86 or 0)+(i-1)*43);rows[name].Root.Size=UDim2.fromOffset(190,39)
   end
  end
  root.AnchorPoint=Vector2.new(1,m.StatusTop and 0 or 1)
  root.Position=m.StatusTop and UDim2.new(1,-12,0,m.StatusTop)or UDim2.new(1,-(m.StatusRight or 12),1,-m.StatusBottom)
  root.Visible=pg:GetAttribute('SeedMenu')==nil
  local character=player.Character;local hum=character and character:FindFirstChildOfClass('Humanoid');local part=character and character:FindFirstChild('HumanoidRootPart')
  local point=part and hum and hum.Health>0 and part.Position or nil
  local weather,track=State.Read(RS,workspace:FindFirstChild('ChestChaseMap'),point,now or workspace:GetServerTimeNow())
  paint(rows.Weather,weather,weather.Kind);paint(rows.Track,track,track.Closed and'Refresh'or'Track')
  tickFast=track.Closed==true and(tonumber(track.Left)or 0)>0 and(tonumber(track.Left)or 99)<=3 -- R150: repaint every frame during the 3-2-1 so the row changes with the beep (not once it reads 0)
  local first=boostRows[1].Root.Position
  if m.Phone and m.WalletHorizontal then boostTimer.Position=UDim2.fromOffset(first.X.Offset,first.Y.Offset+43)
  else boostTimer.Position=UDim2.fromOffset(first.X.Offset,first.Y.Offset-43)end
  local on=paintBoostTimer(now or workspace:GetServerTimeNow())
  -- Start / expiry changes the speed multiplier row too.
  if on~=boostWasActive then boostWasActive=on;task.defer(function()if not dead and updateBoosts then updateBoosts()end end)end
 end
 updateBoosts=function()
  local values={H.Boosts(player)};hasBoosts=false
  for i,row in ipairs(boostRows)do
   local active=values[i]>1;row.Root.Visible=active;hasBoosts=hasBoosts or active
   if i==2 and active then pcall(function()require(RS.CloverIcon153).Ensure()end)end -- R153: drawn when the row first shows
   local text=H.Multiplier(values[i]);if row.Value.Text~=text then row.Value.Text=text end
   row.Root:SetAttribute('AccessibleLabel',row.Label..' '..text)
   if i==1 then row.Root:SetAttribute('PointsPerSecond',100*values[i]);row.Root:SetAttribute('Breakdown',tostring(Balance.TrainingTiers[math.clamp(math.floor(tonumber(player:GetAttribute('TreadmillTier'))or 1),1,#Balance.TrainingTiers)])..' machine × '..tostring(player:GetAttribute('TreadmillMultiplier')or 1)..' trail × '..(player:GetAttribute('DoubleSpeedOwned')and'2' or'1')..' pass × '..SpeedBoost.PlayerFactor(player)..' boost')end
  end
  update()
 end
 for _,attribute in ipairs({'TreadmillTier','TreadmillMultiplier','ChestLuckMultiplier','DoubleSpeedOwned',SpeedBoost.Attribute})do
  connections[#connections+1]=player:GetAttributeChangedSignal(attribute):Connect(updateBoosts)
 end
 connections[#connections+1]=Run.Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed>=.25 or tickFast then elapsed=0;update()end end)
 connections[#connections+1]=pg:GetAttributeChangedSignal('SeedMenu'):Connect(function()root.Visible=pg:GetAttribute('SeedMenu')==nil end)
 local stopLayout
 local function cleanup()
  if dead then return end;dead=true
  if stopLayout then stopLayout()end
  for _,c in ipairs(connections)do c:Disconnect()end
 end
 connections[#connections+1]=gui.Destroying:Connect(cleanup)
 updateBoosts();stopLayout=Layout.Watch(gui,function()update()end)
 return {Gui=gui,Update=update,Destroy=function()cleanup();gui:Destroy()end}
end
return H
