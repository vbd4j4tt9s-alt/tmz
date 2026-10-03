-- R104: independent halfway/end claims, live discovery updates and explicit reward states.
-- R137 (owner: "polish up the index"): cards with a rarity chip and a 1/N odds chip, a soft rarity glow and pedestal
-- behind a bigger model, the name under it, SEED / GROWN check chips and a gold CLAIM pill; cards sorted Common to
-- King; the selected biome tab is ringed; the header shows everything found so far.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Tween=game:GetService('TweenService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local remotes=RS:WaitForChild('ChestChaseRemotes')
local catalog=remotes:WaitForChild('SeedCatalog');local request=remotes:WaitForChild('PremiumRequest')
local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI);local Art=require(RS.HudArtwork);local Preview=require(RS.CollectionViewport);local Cash=require(RS.CashNumbers)
local Audio=require(RS.InteractionAudio);local Gui=game:GetService('GuiService')
local old=pg:FindFirstChild('ChestIndexGui');if old then old:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='ChestIndexGui';gui.ResetOnSpawn=false;gui.DisplayOrder=40;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local connections={};local function watch(signal,fn)local c=signal:Connect(fn);table.insert(connections,c);return c end
local function text(parent,name,value,pos,size,font,color)
 local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.TextWrapped=true;Bright.Text(t,font or 17,color);t.Parent=parent;return t
end
local function button(parent,name,value,pos,size,color)
 local b=Instance.new('TextButton');b.Name=name;b.Text=value;b.Position=pos;b.Size=size;b.BorderSizePixel=0;b.TextSize=18;b.Parent=parent;Bright.Button(b,color or Theme.Colors.Mint);return b
end
local toggle=button(gui,'IndexButton','',UDim2.new(0,18,.5,-42),UDim2.fromOffset(68,68),Color3.fromRGB(80,208,255));toggle.AnchorPoint=Vector2.new(0,.5)
toggle:SetAttribute('ButtonSound','Bubble04')
local icon=Art.Attach(toggle,'Index');icon.Position=UDim2.fromOffset(5,0);icon.Size=UDim2.new(1,-10,1,-11)
text(toggle,'Caption','INDEX',UDim2.new(0,0,1,-19),UDim2.new(1,0,0,18),14)
require(RS.HudLayout).Navigation(toggle,2)
local shade=button(gui,'Shade','',UDim2.fromScale(0,0),UDim2.fromScale(1,1));shade.BackgroundColor3=Color3.new();shade.BackgroundTransparency=.48;shade.Visible=false;shade:FindFirstChild('BrightFill'):Destroy();shade:FindFirstChild('BrightOutline'):Destroy()
require(RS.MenuBackdrop).Attach(gui,shade,false)
local panel=Instance.new('Frame');panel.Name='IndexPanel';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromScale(.94,.88);panel.Visible=false;panel.BorderSizePixel=0;panel.Parent=gui;Bright.Panel(panel)
local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(980,760);limit.Parent=panel
local header=Instance.new('Frame');header.Name='Header';header.Size=UDim2.new(1,0,0,62);header.BorderSizePixel=0;header.Parent=panel;Bright.Header(header)
local title=text(header,'Title','PLANT INDEX',UDim2.fromOffset(18,3),UDim2.new(1,-88,1,-6),30);title.TextXAlignment=Enum.TextXAlignment.Left
-- R137: everything found so far, across every biome.
local total=Instance.new('Frame');total.Name='TotalFound';total.AnchorPoint=Vector2.new(1,.5);total.Position=UDim2.new(1,-66,.5,0);total.Size=UDim2.fromOffset(190,36);total.BackgroundColor3=Color3.fromRGB(14,52,30);total.BackgroundTransparency=.25;total.BorderSizePixel=0;total.Parent=header;Theme.Corner(total,18)
local totalStroke=Instance.new('UIStroke');totalStroke.Color=Color3.fromRGB(18,50,31);totalStroke.Thickness=2;totalStroke.Parent=total
local totalText=text(total,'Count','',UDim2.fromOffset(8,0),UDim2.new(1,-16,1,0),16);totalText.TextWrapped=false
local close=button(header,'Close','X',UDim2.new(1,-54,0,9),UDim2.fromOffset(44,44),Color3.fromRGB(255,61,85))
local tabs=Instance.new('ScrollingFrame');tabs.Name='BiomeProgress';tabs.Position=UDim2.fromOffset(12,73);tabs.Size=UDim2.new(1,-24,0,68);tabs.BackgroundTransparency=1;tabs.BorderSizePixel=0;tabs.CanvasSize=UDim2.new();tabs.AutomaticCanvasSize=Enum.AutomaticSize.X;tabs.ScrollingDirection=Enum.ScrollingDirection.X;tabs.ScrollBarThickness=3;tabs.Parent=panel
local tabLayout=Instance.new('UIListLayout');tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,8);tabLayout.SortOrder=Enum.SortOrder.LayoutOrder;tabLayout.Parent=tabs
local progress=text(panel,'Progress','',UDim2.fromOffset(16,145),UDim2.new(1,-32,0,32),17);progress.TextXAlignment=Enum.TextXAlignment.Left
local bar=Instance.new('Frame');bar.Name='CompletionBar';bar.Position=UDim2.fromOffset(16,198);bar.Size=UDim2.new(1,-58,0,14);bar.BackgroundColor3=Theme.Colors.Inset;bar.BorderSizePixel=0;bar.ClipsDescendants=false;bar.Parent=panel;Theme.Corner(bar,7)
local fill=Instance.new('Frame');fill.Name='Fill';fill.Size=UDim2.fromScale(0,1);fill.BorderSizePixel=0;fill.BackgroundColor3=Color3.new(1,1,1);fill.Parent=bar;Theme.Corner(fill,6);Bright.Gradient(fill,Color3.fromRGB(82,231,255),Color3.fromRGB(150,255,88),0)
-- Each icon claims only its own server-owned milestone reward.
local middle=Instance.new('TextButton');middle.Text='';middle.AutoButtonColor=false;middle.Active=false;middle.Interactable=false;middle.Name='MiddleGem';middle.AnchorPoint=Vector2.new(.5,.5);middle.Position=UDim2.fromScale(.5,.5);middle.Size=UDim2.fromOffset(44,44);middle.BackgroundColor3=Theme.Colors.Inset;middle.BorderSizePixel=0;middle.ZIndex=2;middle.Parent=bar;Theme.Corner(middle,19)
middle:SetAttribute('ButtonSound',false)
local middleScale=Instance.new('UIScale');middleScale.Scale=1;middleScale.Parent=middle
local middleRim=Instance.new('UIStroke');middleRim.Thickness=2;middleRim.Color=Theme.Colors.Muted;middleRim.Parent=middle
local function rewardArt(parent,pad)
 local group=Instance.new('CanvasGroup');group.Name='RewardArt';group.Position=UDim2.fromOffset(pad,pad);group.Size=UDim2.new(1,-pad*2,1,-pad*2);group.BackgroundTransparency=1;group.Active=false;group.Parent=parent
 require(RS.GemIcon).new(group);return group
end
local middleIcon=rewardArt(middle,3)
local middleAmount=text(middle,'RewardAmount','+10',UDim2.new(.5,0,1,3),UDim2.fromOffset(58,19),15,Theme.Colors.Muted);middleAmount.AnchorPoint=Vector2.new(.5,0);middleAmount.TextWrapped=false
local bonus=Instance.new('TextButton');bonus.Name='GemReward';bonus.Text='';bonus.AnchorPoint=Vector2.new(.5,.5);bonus.Position=UDim2.fromScale(1,.5);bonus.Size=UDim2.fromOffset(52,52);bonus.BackgroundColor3=Color3.fromRGB(67,52,110);bonus.BorderSizePixel=0;bonus.AutoButtonColor=false;bonus.Active=false;bonus.Interactable=false;bonus.ZIndex=3;bonus.Parent=bar;Theme.Corner(bonus,26)
bonus:SetAttribute('ButtonSound',false)
local bonusRim=Instance.new('UIStroke');bonusRim.Name='RewardRim';bonusRim.Thickness=2;bonusRim.Color=Theme.Colors.Muted;bonusRim.Parent=bonus
local gemIcon=rewardArt(bonus,4)
local bonusAmount=text(bonus,'RewardAmount','',UDim2.new(.5,0,1,3),UDim2.fromOffset(58,19),15,Theme.Colors.Muted);bonusAmount.AnchorPoint=Vector2.new(.5,0);bonusAmount.TextWrapped=false
local bonusScale=Instance.new('UIScale');bonusScale.Scale=1;bonusScale.Parent=bonus
local list=Instance.new('ScrollingFrame');list.Name='SeedCards';list.Position=UDim2.fromOffset(13,244);list.Size=UDim2.new(1,-26,1,-281);list.BackgroundTransparency=1;list.BorderSizePixel=0;list.CanvasSize=UDim2.new();list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.ScrollBarThickness=5;list.ClipsDescendants=true;list.Parent=panel
local grid=Instance.new('UIGridLayout');grid.CellPadding=UDim2.fromOffset(12,12);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=list
local status=text(panel,'Status','',UDim2.new(0,16,1,-30),UDim2.new(1,-32,0,24),14,Theme.Colors.Gold);status.Visible=false
local selected=1;local busy=false;local claimedHere={};local halfClaimedHere={};local tabsByStage={};local cards={};local cardsById={};local render;local queued=false;local fillTween;local rewardTween
local order={{1,'FOREST'},{6,'JUNGLE'},{2,'DESERT'},{3,'SNOW'},{5,'CRYSTAL'},{4,'LAVA'},{7,'STORM'},{8,'MECH'}}
local function owned(folder,id)local f=player:FindFirstChild(folder);local v=f and f:FindFirstChild(id);return v and v.Value==true end
local function amount(id)local f=player:FindFirstChild('DiscoveredSeeds');local v=f and f:FindFirstChild(id);return v and v:GetAttribute('RewardCash')or 0 end
local function counts(stage)
 local seeds,plants,total=0,0,0
 for _,entry in ipairs(catalog:GetChildren())do local id=entry:GetAttribute('SeedId');if entry:GetAttribute('Stage')==stage and type(id)=='string'and id~=''then total+=1;if owned('DiscoveredSeeds',id)then seeds+=1 end;if owned('DiscoveredPlants',id)then plants+=1 end end end
 return seeds,plants,total
end
local function queue()
 if queued then return end;queued=true;task.defer(function()queued=false;if gui.Parent and panel.Visible then render()end end)
end
local function claim(action,value)
 if busy or(action=='ClaimBiome'and claimedHere[value])or(action=='ClaimBiomeHalf'and halfClaimedHere[value])then return end
 busy=true;bonus.Active=false;bonus.Interactable=false;middle.Active=false;middle.Interactable=false
 task.spawn(function()
  local ok,result=pcall(request.InvokeServer,request,action,value);busy=false;if not gui.Parent then return end
  status.Text=ok and type(result)=='table'and(result.Message or'')or'Please try again.';status.Visible=status.Text~=''
  if(action=='ClaimBiome'or action=='ClaimBiomeHalf')and ok and type(result)=='table'and result.Success==true then
   if action=='ClaimBiomeHalf'then halfClaimedHere[value]=true else claimedHere[value]=true end
   -- The cue and Gem pulse share the authoritative success event. Never play on a rejected click.
   Audio.Play('GemClaim')
   if panel.Visible and selected==value and not Gui.ReducedMotionEnabled then
    if rewardTween then rewardTween:Cancel()end
    local scale=action=='ClaimBiomeHalf'and middleScale or bonusScale
    scale.Scale=1.16;rewardTween=Tween:Create(scale,TweenInfo.new(.24,Enum.EasingStyle.Back),{Scale=1});rewardTween:Play()
   end
  end
  queue()
 end)
end
for i,pair in ipairs(order)do
 local stage,name=pair[1],pair[2];local b=button(tabs,'Biome'..stage,'',UDim2.new(),UDim2.fromOffset(122,58),Color3.fromRGB(73,109,204));b.LayoutOrder=i
 local nameLabel=require(RS.BiomeArtwork).Attach(b,name:sub(1,1)..name:sub(2):lower());nameLabel.Name='BiomeLogo';nameLabel.Position=UDim2.fromOffset(12,1);nameLabel.Size=UDim2.fromOffset(44,44);b:SetAttribute('BiomeName',name)
 local countLabel=text(b,'Count','0 / 0',UDim2.fromOffset(56,12),UDim2.new(1,-60,0,24),14)
 local tiny=Instance.new('Frame');tiny.Name='Fill';tiny.Position=UDim2.new(0,5,1,-9);tiny.Size=UDim2.new(0,0,0,5);tiny.BackgroundColor3=Theme.Colors.Mint;tiny.BorderSizePixel=0;tiny.Parent=b;Theme.Corner(tiny,3)
 tabsByStage[stage]={Button=b,Count=countLabel,Fill=tiny,Name=nameLabel}
 b.Activated:Connect(function()selected=stage;list.CanvasPosition=Vector2.zero;if rewardTween then rewardTween:Cancel()end;bonusScale.Scale=1;middleScale.Scale=1;render()end)
end
local function resize()
 local view=gui.AbsoluteSize;local heightScale=view.Y<500 and .96 or .88
 panel.Size=UDim2.fromScale(.94,heightScale)
 local panelWidth=math.min(980,view.X*.94);local panelHeight=math.min(760,view.Y*heightScale)
 local compact=panelHeight<440;local tight=panelHeight<300
 local headerH=compact and(tight and 36 or 44)or 62
 local tabY=compact and headerH+4 or 73;local tabH=compact and(tight and 36 or 44)or 68
 local progressY=compact and tabY+tabH+2 or 145;local progressH=compact and(tight and 18 or 22)or 32
 local gemSize=compact and 44 or 52;local barH=compact and(tight and 10 or 12)or 14
 local barY=compact and progressY+progressH+gemSize/2-barH/2+4 or 198
 local listY=barY+barH/2+gemSize/2+28;local footer=compact and 24 or 37
 header.Size=UDim2.new(1,0,0,headerH);title.TextSize=compact and(tight and 22 or 26)or 30
 total.Size=UDim2.fromOffset(compact and 150 or 190,compact and headerH-12 or 36);total.Position=UDim2.new(1,-(compact and headerH or 66),.5,0);totalText.TextSize=compact and 13 or 16;total.Visible=panelWidth>=420
 local closeSize=compact and(tight and 32 or 36)or 44
 close.Position=UDim2.new(1,-closeSize-10,0,(headerH-closeSize)/2);close.Size=UDim2.fromOffset(closeSize,closeSize)
 tabs.Position=UDim2.fromOffset(12,tabY);tabs.Size=UDim2.new(1,-24,0,tabH)
 progress.Position=UDim2.fromOffset(16,progressY);progress.Size=UDim2.new(1,-32,0,progressH);progress.TextWrapped=false
 local font=panelWidth<420 and 14 or 17;if compact then font=tight and 12 or 14 end
 require(RS.GardenTextFit).Attach(progress,font,math.min(font,12))
 bar.Position=UDim2.fromOffset(16,barY);bar.Size=UDim2.new(1,-(gemSize/2+32),0,barH)
 bonus.Size=UDim2.fromOffset(gemSize,gemSize);middle.Size=UDim2.fromOffset(44,44)
 middleAmount.Position=UDim2.new(.5,0,1,gemSize/2-22+3)
 middleAmount.TextSize=tight and 13 or 15;bonusAmount.TextSize=tight and 13 or 15
 for stage,t in pairs(tabsByStage)do
  local bh=compact and tabH-4 or 58;local bw=compact and 106 or 122
  t.Button.Size=UDim2.fromOffset(bw,bh);t.Name.Position=UDim2.fromOffset(compact and 6 or 12,1);t.Name.Size=UDim2.fromOffset(compact and bh-6 or 44,compact and bh-6 or 44)
  t.Count.Position=UDim2.fromOffset(compact and bh+2 or 56,compact and 2 or 12);t.Count.Size=UDim2.new(1,-(compact and bh+6 or 60),0,compact and bh-8 or 24);t.Count.TextSize=compact and 12 or 14
  local seeds,plants,total=counts(stage);t.Fill.Size=UDim2.fromOffset(math.max(0,(bw-10)*(total>0 and(seeds+plants)/(total*2)or 0)),5)
 end
 list.Position=UDim2.fromOffset(13,listY);list.Size=UDim2.new(1,-26,1,-listY-footer)
 status.Position=UDim2.new(0,16,1,compact and -22 or -30);status.Size=UDim2.new(1,-32,0,compact and 18 or 24);status.TextSize=compact and 12 or 14
 local w=math.max(120,panelWidth-34);local columns=w>=780 and 5 or w>=600 and 4 or w>=430 and 3 or 2
 grid.CellSize=UDim2.fromOffset(math.floor((w-(columns-1)*12)/columns),223)
end
watch(gui:GetPropertyChangedSignal('AbsoluteSize'),resize)
watch(list:GetPropertyChangedSignal('AbsoluteSize'),resize)
local function signature(entry)local id=entry:GetAttribute('SeedId');return tostring(owned('DiscoveredSeeds',id))..':'..tostring(owned('DiscoveredPlants',id))..':'..tostring(amount(id))end
local RarityRank=require(RS.SeedPackRules).Rarities
local function rank(rarity)local r=RarityRank[rarity];return r and r.Rank or 1 end
local function pill(parent,name,pos,size,fill,alpha,line)
 local f=Instance.new('Frame');f.Name=name;f.Position=pos;f.Size=size;f.BackgroundColor3=fill;f.BackgroundTransparency=alpha or 0;f.BorderSizePixel=0;f.Parent=parent;Theme.Corner(f,10)
 if line then local st=Instance.new('UIStroke');st.Color=line;st.Thickness=1.5;st.Transparency=.15;st.Parent=f end
 return f
end
local function chip(parent,name,label,known,pos,size)
 local f=pill(parent,name,pos,size,known and Theme.Colors.Mint or Color3.fromRGB(10,16,36),known and 0 or .45,known and Color3.fromRGB(32,92,24)or Theme.Colors.Line)
 local t=text(f,'Label',label..(known and'  ✓'or'  ?'),UDim2.fromScale(0,0),UDim2.fromScale(1,1),11,known and Color3.fromRGB(16,44,12)or Theme.Colors.Muted)
 if known then t.TextStrokeTransparency=1 end
 return f
end
local function makeCard(entry,index)
 local id=entry:GetAttribute('SeedId');local seedKnown=owned('DiscoveredSeeds',id);local adultKnown=seedKnown and owned('DiscoveredPlants',id);local reward=amount(id);local rarity=entry:GetAttribute('Rarity')or'Common'
 local card=Instance.new('TextButton');card.Name=id;card.Text='';card.LayoutOrder=rank(rarity)*10000+index;card.BorderSizePixel=0;card.AutoButtonColor=false;card.Parent=list
 Bright.Card(card,Theme.Rarity(rarity).Accent,selected==8,rarity) -- R123: rarity border
 local style=Theme.Rarity(rarity)
 -- R137: soft rarity glow and a pedestal shadow behind the model.
 local glow=Instance.new('Frame');glow.Name='Glow';glow.AnchorPoint=Vector2.new(.5,.5);glow.Position=UDim2.new(.5,0,0,88);glow.Size=UDim2.fromOffset(118,118);glow.BackgroundColor3=style.Color;glow.BackgroundTransparency=seedKnown and .78 or .9;glow.BorderSizePixel=0;glow.Parent=card;Theme.Corner(glow,59)
 local core=Instance.new('Frame');core.Name='Core';core.AnchorPoint=Vector2.new(.5,.5);core.Position=UDim2.fromScale(.5,.5);core.Size=UDim2.fromScale(.6,.6);core.BackgroundColor3=style.Color;core.BackgroundTransparency=seedKnown and .72 or .9;core.BorderSizePixel=0;core.Parent=glow;Theme.Corner(core,36)
 local pedestal=Instance.new('Frame');pedestal.Name='Pedestal';pedestal.AnchorPoint=Vector2.new(.5,.5);pedestal.Position=UDim2.new(.5,0,0,138);pedestal.Size=UDim2.new(.62,0,0,12);pedestal.BackgroundColor3=Color3.new();pedestal.BackgroundTransparency=.62;pedestal.BorderSizePixel=0;pedestal.Parent=card;Theme.Corner(pedestal,6)
 local view=Instance.new('ViewportFrame');view.Name='Preview';view.BackgroundTransparency=1;view.Position=UDim2.fromOffset(6,30);view.Size=UDim2.new(1,-12,0,112);view.Ambient=Color3.fromRGB(215,219,240);view.LightColor=Color3.fromRGB(255,253,246);view.Parent=card
 local stop=Preview.Attach(view,id,false,seedKnown);local adult=false;local generation=0
 -- Top row: rarity chip and the 1/N chance (OddsText85).
 local chance=entry:GetAttribute('BaseChance');local odds=chance and require(RS.OddsText85).Format(chance)or'–'
 local rarityChip=pill(card,'RarityChip',UDim2.fromOffset(7,7),UDim2.new(.58,-7,0,21),Color3.fromRGB(10,14,32),.2,style.Accent)
 local rarityLabel=text(rarityChip,'Rarity',string.upper(rarity),UDim2.fromOffset(4,0),UDim2.new(1,-8,1,0),12);Theme.RarityText(rarityLabel,rarity,12,false)
 local oddsChip=pill(card,'OddsChip',UDim2.new(.58,4,0,7),UDim2.new(.42,-11,0,21),Color3.fromRGB(10,14,32),.2,Theme.Colors.Line)
 text(oddsChip,'Odds',odds,UDim2.fromOffset(3,0),UDim2.new(1,-6,1,0),12,Color3.new(1,1,1))
 local name=text(card,'Name',seedKnown and(entry:GetAttribute('DisplayName')or id)or'???',UDim2.fromOffset(6,144),UDim2.new(1,-12,0,22),16)
 name.TextWrapped=false;name.TextScaled=true;local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=16;fit.MinTextSize=10;fit.Parent=name
 local seedChip=chip(card,'SeedChip','SEED',seedKnown,UDim2.fromOffset(7,170),UDim2.new(.5,-10,0,20))
 local grownChip=chip(card,'GrownChip','GROWN',adultKnown,UDim2.new(.5,3,0,170),UDim2.new(.5,-10,0,20))
 local caption
 if reward>0 then
  local claimPill=pill(card,'ClaimPill',UDim2.new(0,7,1,-29),UDim2.new(1,-14,0,23),Color3.new(1,1,1),0,Color3.fromRGB(110,64,6))
  Bright.Gradient(claimPill,Color3.fromRGB(255,232,112),Color3.fromRGB(242,164,34),90)
  caption=text(claimPill,'Reward','CLAIM $'..Cash.Compact(reward),UDim2.fromScale(0,0),UDim2.fromScale(1,1),14,Color3.fromRGB(70,38,6));caption.TextStrokeTransparency=1
 else
  caption=text(card,'Reward',adultKnown and'★ COMPLETE'or'',UDim2.new(0,5,1,-28),UDim2.new(1,-10,0,22),13,Theme.Colors.Mint)
 end
 local zoom=Instance.new('UIScale');zoom.Scale=1;zoom.Parent=view
 local function show(value)
  if value==adult then return end;adult=value;generation+=1;local token=generation
  stop();view.ImageTransparency=.8
  task.defer(function()
   if not card.Parent or token~=generation then return end
   stop=Preview.Attach(view,id,value,(value and adultKnown)or(not value and seedKnown))
   if not Gui.ReducedMotionEnabled then zoom.Scale=.86;Tween:Create(zoom,TweenInfo.new(.2,Enum.EasingStyle.Back),{Scale=1}):Play()end
   Tween:Create(view,TweenInfo.new(.18),{ImageTransparency=0}):Play()
  end)
 end
 card.MouseEnter:Connect(function()show(true)end);card.MouseLeave:Connect(function()show(false)end)
 card.SelectionGained:Connect(function()show(true)end);card.SelectionLost:Connect(function()show(false)end)
 card.Activated:Connect(function()if amount(id)>0 then claim('ClaimSeed',id)else show(not adult)end end)
 card.Destroying:Connect(function()generation+=1;stop()end)
 table.insert(cards,card);cardsById[id]={Card=card,Signature=signature(entry)}
end
render=function()
 if not panel.Visible then return end
 local wanted={}
 local found,all=0,0
 for stage,t in pairs(tabsByStage)do
  local seeds,plants,total=counts(stage);local n=seeds+plants;local max=total*2;found+=n;all+=max
  t.Count.Text=n..' / '..max;t.Fill.Size=UDim2.fromOffset(math.max(0,(t.Button.Size.X.Offset-10)*(max>0 and n/max or 0)),5);t.Button.BackgroundColor3=stage==selected and Color3.fromRGB(80,149,194)or Color3.fromRGB(73,109,204)
  -- R137: the open biome gets a white ring.
  local ring=t.Button:FindFirstChild('BrightOutline');if ring then ring.Color=stage==selected and Color3.new(1,1,1)or Color3.fromRGB(12,17,38);ring.Thickness=stage==selected and 3 or 2 end
 end
 totalText.Text='FOUND '..found..' / '..all
 local seeds,plants,total=counts(selected);local complete=total>0 and seeds==total and plants==total;local taken=claimedHere[selected]or player:GetAttribute('IndexBiomeReward'..selected)==true
 progress.Text=seeds..'/'..total..' SEEDS  •  '..plants..'/'..total..' PLANTS'
 if fillTween then fillTween:Cancel()end
 fillTween=Tween:Create(fill,TweenInfo.new(Gui.ReducedMotionEnabled and 0 or .22),{Size=UDim2.fromScale(total>0 and math.clamp((seeds+plants)/(total*2),0,1)or 0,1)});fillTween:Play()
 local tuning=require(RS.BalanceValues81);local totalGems=tuning.CompletionGems[selected]or 0
 local halfGems=tuning.HalfwayGems
 local halfTaken=halfClaimedHere[selected]or player:GetAttribute('IndexBiomeHalfReward'..selected)==true
 local halfway=total>0 and(seeds+plants)>=total
 middle:SetAttribute('RewardGems',halfGems);middle:SetAttribute('RewardClaimed',halfTaken==true)
 middle.Active=halfway and not halfTaken and not busy;middle.Interactable=middle.Active;middle.AutoButtonColor=middle.Active
 local halfReady=halfway and not halfTaken
 middle:SetAttribute('RewardReady',halfReady)
 middle.BackgroundColor3=halfReady and Color3.fromRGB(151,65,172)or Color3.fromRGB(49,49,77)
 middleRim.Color=halfTaken and Theme.Colors.Mint or halfReady and Theme.Colors.Gold or Theme.Colors.Muted
 middleIcon.GroupTransparency=halfReady and 0 or halfTaken and .32 or .65
 middleAmount.Text='+'..tostring(halfGems);middleAmount.TextColor3=middleRim.Color
 local backpay=player:GetAttribute('IndexBiomeBackpay'..selected)or 0
 local gems=backpay>0 and backpay or totalGems
 local endReady=complete and not taken
 -- Preserve already-earned backpay without lighting an incomplete endpoint.
 bonus:SetAttribute('RewardGems',gems);bonus:SetAttribute('RewardClaimed',taken==true);bonus.Active=(complete or backpay>0)and not taken and not busy;bonus.Interactable=bonus.Active;bonus.AutoButtonColor=bonus.Active
 bonus.BackgroundColor3=endReady and Color3.fromRGB(151,65,172)or Color3.fromRGB(49,49,77)
 bonusRim.Color=taken and Theme.Colors.Mint or endReady and Theme.Colors.Gold or Theme.Colors.Muted
 gemIcon.GroupTransparency=endReady and 0 or taken and .32 or .65
 bonusAmount.Text='+'..tostring(gems);bonusAmount.TextColor3=bonusRim.Color
 bonus:SetAttribute('RewardReady',endReady)
 local entries=catalog:GetChildren();table.sort(entries,function(a,b)return(a:GetAttribute('SeedIndex')or 0)<(b:GetAttribute('SeedIndex')or 0)end)
 for i,entry in ipairs(entries)do local id=entry:GetAttribute('SeedId');if entry:GetAttribute('Stage')==selected and type(id)=='string'and id~=''then
  wanted[id]=true;local existing=cardsById[id]
  if not existing or existing.Signature~=signature(entry)then if existing then existing.Card:Destroy()end;makeCard(entry,i)end
 end end
 for id,entry in pairs(cardsById)do if not wanted[id]then entry.Card:Destroy();cardsById[id]=nil end end
 cards={};for _,entry in pairs(cardsById)do table.insert(cards,entry.Card)end;resize()
end
middle.Activated:Connect(function()if middle.Active then claim('ClaimBiomeHalf',selected)end end)
bonus.Activated:Connect(function()if bonus.Active then claim('ClaimBiome',selected)end end)
local function open(value)
 panel.Visible=value;shade.Visible=value
 if value then if pg:GetAttribute('SeedMenu')~='Index'then pg:SetAttribute('SeedMenu','Index')end;queue()
 elseif pg:GetAttribute('SeedMenu')=='Index'then pg:SetAttribute('SeedMenu',nil)end
 -- The shared navigation wheel owns its option visibility.
end
toggle.Activated:Connect(function()open(not panel.Visible)end);close.Activated:Connect(function()open(false)end);shade.Activated:Connect(function()open(false)end)
watch(pg:GetAttributeChangedSignal('SeedMenu'),function()open(pg:GetAttribute('SeedMenu')=='Index')end)
watch(player:GetAttributeChangedSignal('PremiumRevision'),queue)
for stage=1,8 do
 for _,prefix in ipairs({'IndexBiomeReward','IndexBiomeHalfReward','IndexBiomeBackpay'})do watch(player:GetAttributeChangedSignal(prefix..stage),queue)end
end
local observed=setmetatable({},{__mode='k'})
local function observeDiscovery(x)
 if observed[x]then return end
 if x:IsA('BoolValue')and x.Parent and(x.Parent.Name=='DiscoveredSeeds'or x.Parent.Name=='DiscoveredPlants')then
  observed[x]=true;watch(x:GetPropertyChangedSignal('Value'),queue);watch(x:GetAttributeChangedSignal('RewardCash'),queue);queue()
 elseif x.Name=='DiscoveredSeeds'or x.Name=='DiscoveredPlants'then
  observed[x]=true;watch(x.ChildRemoved,queue);for _,child in ipairs(x:GetChildren())do observeDiscovery(child)end
 end
end
local function observeEntry(entry)
 watch(entry:GetAttributeChangedSignal('Stage'),queue);watch(entry:GetAttributeChangedSignal('SeedId'),queue);queue()
end
watch(catalog.ChildAdded,observeEntry);watch(catalog.ChildRemoved,queue)
for _,entry in ipairs(catalog:GetChildren())do observeEntry(entry)end
watch(player.DescendantAdded,observeDiscovery)
for _,name in ipairs({'DiscoveredSeeds','DiscoveredPlants'})do local folder=player:FindFirstChild(name);if folder then observeDiscovery(folder)end end
gui.Destroying:Connect(function()if fillTween then fillTween:Cancel()end;if rewardTween then rewardTween:Cancel()end;for _,c in ipairs(connections)do c:Disconnect()end end)
resize()
