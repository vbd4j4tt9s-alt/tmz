do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R141: daily login pack/gem rewards and two-gem daily quests.
-- The existing DAILY/INVITE UI, friend chip and plant-ready opt-in use server state.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Tween=game:GetService('TweenService')
local GuiService=game:GetService('GuiService');local SocialService=game:GetService('SocialService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local remotes=RS:WaitForChild('ChestChaseRemotes')
local request=remotes:WaitForChild('PremiumRequest')
local D=require(RS:WaitForChild('DailyRewards'));local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI)
local Fit=require(RS.GardenTextFit);local Audio=require(RS.InteractionAudio)
local Pictures;pcall(function()Pictures=require(RS.ItemPictures)end)
local RGB=Color3.fromRGB
local GOLD,MINT,SKY,GRAPE=RGB(255,206,64),RGB(110,226,96),RGB(86,182,255),RGB(150,96,255)
local old=pg:FindFirstChild('DailyRewardsGui');if old then old:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='DailyRewardsGui';gui.ResetOnSpawn=false;gui.DisplayOrder=41;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local connections={};local function watch(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
local function new(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function text(parent,name,value,size,color)
 local t=new('TextLabel',{Name=name,Text=value,BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center},parent)
 Bright.Text(t,size or 16,color);return t
end
local function stroke(parent,color,thickness)return new('UIStroke',{Color=color,Thickness=thickness or 2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent)end
-- R151: the DAILY button / tab badges are NotifyBadge151, the same component as the Index's (this script carried an identical copy of the R138 badge).
local Badge=require(RS.NotifyBadge151)
-- Recolour a BrightUI button (its gradient), e.g. the CLAIM button going grey while it waits for tomorrow.
local function tint(button,color)Bright.Gradient(button,color:Lerp(Color3.new(1,1,1),.24),color:Lerp(Color3.new(),.12),90)end
local function pop(o,from)
 local sc=o:FindFirstChildOfClass('UIScale');if not sc or GuiService.ReducedMotionEnabled then return end
 sc.Scale=from or 1.4;Tween:Create(sc,TweenInfo.new(.35,Enum.EasingStyle.Back),{Scale=1}):Play()
end
-- Top bar buttons ---------------------------------------------------------------------------------------------------
local function topButton(name,emoji,caption,color,label)
 local b=new('TextButton',{Name=name,Text='',Size=UDim2.fromScale(1,1),BorderSizePixel=0,ZIndex=10,AutoButtonColor=true},nil)
 Bright.Button(b,color);b:SetAttribute('ButtonSound','Bubble04');b:SetAttribute('AccessibleLabel',label)
 local icon=new('TextLabel',{Name='Icon',Text=emoji,BackgroundTransparency=1,Position=UDim2.fromScale(0,.04),Size=UDim2.fromScale(1,.6),TextScaled=true,Font=Enum.Font.FredokaOne,TextColor3=Color3.new(1,1,1),ZIndex=12},b)
 local cap=text(b,'Caption',caption,10);cap.Position=UDim2.fromScale(0,.62);cap.Size=UDim2.fromScale(1,.36);cap.TextScaled=true;cap.ZIndex=12
 new('UIScale',{Name='Bounce'},b)
 return b
end
local dailyButton=topButton('DailyButton','🎁','DAILY',RGB(255,150,48),'Daily rewards and quests')
dailyButton:SetAttribute('ButtonSound','MenuClick') -- R150: it opens the DAILY window (ButtonFeedback's SeedMenu click is the same cue, so it plays once)
local inviteButton=topButton('InviteButton','👥','INVITE',RGB(64,170,255),'Invite friends. Each friend here: +'..math.floor(D.FriendBoostPerFriend*100+.5)..'% speed gain')
local function mount()
 local tb=pg:FindFirstChild('TravelButtons');local icons=tb and tb:FindFirstChild('TopIcons')
 if tb and not icons then tb.ChildAdded:Once(function()task.defer(mount)end)end
 if not icons then return false end
 local daily,invite=icons:FindFirstChild('Daily'),icons:FindFirstChild('Invite')
 if not daily or not invite then return false end
 if dailyButton.Parent~=daily then dailyButton.Parent=daily end
 if inviteButton.Parent~=invite then inviteButton.Parent=invite end
 return true
end
watch(pg.ChildAdded,function(child)if child.Name=='TravelButtons'then task.defer(mount)end end)
task.defer(mount)
-- The DAILY window ---------------------------------------------------------------------------------------------------
local shade=new('TextButton',{Name='Shade',Text='',AutoButtonColor=false,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=.48,BorderSizePixel=0,Visible=false},gui)
shade:SetAttribute('ButtonSound',false)
pcall(function()require(RS.MenuBackdrop).Attach(gui,shade,false)end)
local panel=new('Frame',{Name='DailyPanel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.94,.88),Visible=false,BorderSizePixel=0},gui);Bright.Panel(panel)
new('UISizeConstraint',{MaxSize=Vector2.new(780,480)},panel)
local header=new('Frame',{Name='Header',Size=UDim2.new(1,0,0,56),BorderSizePixel=0},panel);Bright.Header(header)
local title=text(header,'Title','🎁 DAILY REWARDS',28);title.TextXAlignment=Enum.TextXAlignment.Left;title.Position=UDim2.fromOffset(18,2);title.Size=UDim2.new(1,-84,1,-4)
local close=new('TextButton',{Name='Close',Text='X',Position=UDim2.new(1,-52,0,7),Size=UDim2.fromOffset(42,42),BorderSizePixel=0,TextSize=20},header);Bright.Button(close,RGB(255,61,85))
local tabs={}
for i,spec in ipairs({{'Login','📅 LOGIN'},{'Quests','📜 QUESTS'}})do
 local t=new('TextButton',{Name=spec[1]..'Tab',Text='',BorderSizePixel=0,LayoutOrder=i},panel);Bright.Button(t,i==1 and RGB(255,150,48)or RGB(92,128,255))
 local cap=text(t,'Caption',spec[2],18);cap.Size=UDim2.new(1,-12,1,0);cap.Position=UDim2.fromOffset(6,0);cap.ZIndex=12
 tabs[spec[1]]=t
end
local pages={Login=new('Frame',{Name='LoginPage',BackgroundTransparency=1},panel),Quests=new('Frame',{Name='QuestsPage',BackgroundTransparency=1,Visible=false},panel)}
local status=text(panel,'Status','',15,Theme.Colors.Gold);status.Visible=false
-- LOGIN page: the week as seven cards (day 7 is the wide Mech pack card) and one big CLAIM button.
local loginNote=text(pages.Login,'Note','4 random packs, then 2 + 3 gems. DAY 7 = MECH 🤖',17,Theme.Colors.Muted)
local days={}
for d=1,#D.Login do
 local reward=D.Login[d];local big=reward.MechPack~=nil
 local card=new('Frame',{Name='Day'..d,BorderSizePixel=0,BackgroundColor3=big and RGB(70,46,128)or Theme.Colors.Card},pages.Login);Theme.Corner(card,12)
 if big then Bright.Gradient(card,RGB(124,74,214),RGB(52,30,104),90)end
 local edge=stroke(card,big and RGB(196,150,255)or Theme.Colors.Line,2);edge.Name='Edge'
 local dayText=text(card,'DayLabel','DAY '..d,15);dayText.ZIndex=4
 local art=new('Frame',{Name='Art',BackgroundTransparency=1,ZIndex=3},card)
 if reward.MechPack or reward.SeedPack then
  local shown=false
  if Pictures then
   local proxy=Instance.new('Folder');proxy:SetAttribute('SeedPackTool',true);proxy:SetAttribute('Stage',reward.MechPack and 8 or 1);proxy:SetAttribute('BagVariant',reward.MechPack and 'MechLimited'or 'Pack01');proxy:SetAttribute('PackMutation','None')
   shown=pcall(Pictures.Show,art,proxy,2)
  end
  if not shown then local e=text(art,'Emoji',reward.MechPack and '🤖'or '🎒',30);e.Size=UDim2.fromScale(1,1);e.TextScaled=true end
 else
  local holder=new('CanvasGroup',{Name='Gem',BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},art)
  local ok=pcall(function()require(RS.GemIcon).new(holder)end)
  if not ok then local e=text(holder,'Emoji','💎',30);e.Size=UDim2.fromScale(1,1);e.TextScaled=true end
 end
 local amount=text(card,'Amount',D.RewardText(reward),big and 18 or 17,big and GOLD or Color3.new(1,1,1));amount.ZIndex=4
 local check=new('Frame',{Name='Check',AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=MINT,BorderSizePixel=0,ZIndex=8,Visible=false},card);Theme.Corner(check,40)
 stroke(check,Color3.new(1,1,1),2);local tick=text(check,'Tick','✓',26);tick.Size=UDim2.fromScale(1,1);tick.TextScaled=true;tick.ZIndex=9
 local dim=new('Frame',{Name='Dim',BackgroundColor3=Color3.new(),BackgroundTransparency=.45,Size=UDim2.fromScale(1,1),ZIndex=7,Visible=false},card);Theme.Corner(dim,12)
 local today=text(card,'Today','TODAY',13,Theme.Colors.Ink);today.BackgroundTransparency=0;today.BackgroundColor3=GOLD;today.ZIndex=9;today.Visible=false;Theme.Corner(today,8)
 new('UIScale',{},card)
 days[d]={Card=card,Edge=edge,Day=dayText,Art=art,Amount=amount,Check=check,Dim=dim,Today=today,Big=big}
end
local claimButton=new('TextButton',{Name='ClaimButton',Text='',BorderSizePixel=0},pages.Login);Bright.Button(claimButton,GOLD)
local claimText=text(claimButton,'Caption','',22);claimText.Size=UDim2.new(1,-16,1,0);claimText.Position=UDim2.fromOffset(8,0);claimText.ZIndex=12
new('UIScale',{Name='Pulse'},claimButton)
-- QUESTS page: three rows (icon, task, progress bar, 💎5 and a CLAIM button) and the time until the new quests.
local questTitle=text(pages.Quests,'Title','DAILY QUESTS',20);questTitle.TextXAlignment=Enum.TextXAlignment.Left
local questReset=text(pages.Quests,'Reset','',15,Theme.Colors.Muted);questReset.TextXAlignment=Enum.TextXAlignment.Right
local rows={}
for i=1,D.QuestsPerDay do
 local row=new('Frame',{Name='Quest'..i,BorderSizePixel=0,BackgroundColor3=Theme.Colors.Card},pages.Quests);Theme.Corner(row,12);local edge=stroke(row,Theme.Colors.Line,2);edge.Name='Edge'
 local iconBack=new('Frame',{Name='IconBack',BackgroundColor3=Theme.Colors.Inset,BorderSizePixel=0},row);Theme.Corner(iconBack,40)
 local icon=new('TextLabel',{Name='Icon',BackgroundTransparency=1,Size=UDim2.fromScale(.78,.78),Position=UDim2.fromScale(.11,.11),TextScaled=true,Font=Enum.Font.FredokaOne,TextColor3=Color3.new(1,1,1),Text=''},iconBack)
 local task_=text(row,'Task','',18);task_.TextXAlignment=Enum.TextXAlignment.Left
 local bar=new('Frame',{Name='Bar',BackgroundColor3=Theme.Colors.Inset,BorderSizePixel=0},row);Theme.Corner(bar,7)
 local fill=new('Frame',{Name='Fill',BorderSizePixel=0,BackgroundColor3=Color3.new(1,1,1),Size=UDim2.fromScale(0,1)},bar);Theme.Corner(fill,7);Bright.Gradient(fill,RGB(82,231,255),RGB(150,255,88),0)
 local count=text(bar,'Count','',13);count.Size=UDim2.fromScale(1,1);count.ZIndex=5
 local reward=new('Frame',{Name='Reward',BackgroundColor3=RGB(67,52,110),BorderSizePixel=0},row);Theme.Corner(reward,10);stroke(reward,RGB(170,140,255),2)
 local gem=new('CanvasGroup',{Name='Gem',BackgroundTransparency=1},reward)
 if not pcall(function()require(RS.GemIcon).new(gem)end)then local e=text(gem,'Emoji','💎',20);e.Size=UDim2.fromScale(1,1);e.TextScaled=true end
 local gems=text(reward,'Amount',tostring(D.QuestGems),18,GOLD)
 local claim=new('TextButton',{Name='Claim',Text='',BorderSizePixel=0},row);Bright.Button(claim,MINT);new('UIScale',{Name='Pulse'},claim)
 local claimCap=text(claim,'Caption','CLAIM',17);claimCap.Size=UDim2.new(1,-8,1,0);claimCap.Position=UDim2.fromOffset(4,0);claimCap.ZIndex=12
 local done=text(row,'Done','✓ DONE',16,MINT);done.Visible=false
 new('UIScale',{},row)
 rows[i]={Row=row,Edge=edge,IconBack=iconBack,Icon=icon,Task=task_,Bar=bar,Fill=fill,Count=count,Reward=reward,Gem=gem,Gems=gems,Claim=claim,ClaimCap=claimCap,Done=done}
end
-- Layout (pixels from the panel's real size, so phones and computers both fit) ----------------------------------------
local state,stateAt=nil,0;local narrowQuests=false
local function resetLeft()return state and math.max(0,(state.ResetIn or 0)-(os.clock()-stateAt))or D.SecondsLeft()end
local function resetText()return(narrowQuests and'NEW IN 'or'NEW QUESTS IN ')..D.Countdown(resetLeft())end
local function layout()
 local size=panel.AbsoluteSize;local W,H=size.X,size.Y;if W<=0 or H<=0 then return end
 local short=H<380
 local headH=short and 46 or 56;header.Size=UDim2.new(1,0,0,headH);title.TextSize=short and 22 or 28;close.Position=UDim2.new(1,-(headH-6)-6,0,3);close.Size=UDim2.fromOffset(headH-6,headH-6)
 local tabH=short and 36 or 44;local tabW=math.min(190,math.floor((W-36)/2));local tabY=headH+(short and 6 or 10)
 for i,name in ipairs({'Login','Quests'})do local t=tabs[name];t.Position=UDim2.fromOffset(12+(i-1)*(tabW+12),tabY);t.Size=UDim2.fromOffset(tabW,tabH);t.Caption.TextSize=short and 15 or 18 end
 local top=tabY+tabH+(short and 6 or 10);local bottomPad=status.Visible and 26 or 10
 for _,page in pairs(pages)do page.Position=UDim2.fromOffset(12,top);page.Size=UDim2.fromOffset(W-24,H-top-bottomPad)end
 status.Position=UDim2.new(0,12,1,-25);status.Size=UDim2.new(1,-24,0,22)
 local pw,ph=W-24,H-top-bottomPad
 -- LOGIN: one row of 7 when wide (day 7 is 1.6 cards wide); two rows (4 + 3) on narrow screens.
 local noteH=short and 20 or 26;loginNote.Size=UDim2.fromOffset(pw,noteH);loginNote.TextSize=short and 14 or 17
 local buttonH=short and 40 or 50;local gap=short and 8 or 10
 -- The cards and the CLAIM button are one block, a little above the middle of the space under the note.
 local avail=ph-noteH-gap;local oneRow=pw>=600
 local cw,ch,blockH
 if oneRow then
  cw=math.floor((pw-gap*6)/7.6);ch=math.max(40,math.min(math.floor(cw*1.55),avail-gap*2-buttonH));blockH=ch
 else
  cw=math.floor((pw-gap*3)/4);ch=math.max(40,math.min(math.floor(cw*1.3),math.floor((avail-gap*3-buttonH)/2)));blockH=ch*2+gap
 end
 local cardsTop=noteH+gap+math.floor(math.max(0,avail-blockH-gap*2-buttonH)*.4)
 if oneRow then
  local x=0
  for d,e in ipairs(days)do local w=e.Big and(pw-x)or cw;e.Card.Position=UDim2.fromOffset(x,cardsTop);e.Card.Size=UDim2.fromOffset(w,ch);x+=w+gap end
 else
  for d,e in ipairs(days)do
   local r=d<=4 and 0 or 1;local c=d<=4 and d-1 or d-5;local w=e.Big and(pw-(cw+gap)*2)or cw
   e.Card.Position=UDim2.fromOffset(c*(cw+gap),cardsTop+r*(ch+gap));e.Card.Size=UDim2.fromOffset(w,ch)
  end
 end
 for _,e in ipairs(days)do
  local w=e.Card.Size.X.Offset;local h=ch;local label=math.max(14,math.floor(h*.17))
  e.Day.Position=UDim2.fromOffset(0,4);e.Day.Size=UDim2.new(1,0,0,label);e.Day.TextSize=math.min(16,label)
  e.Amount.Position=UDim2.new(0,2,1,-label-6);e.Amount.Size=UDim2.new(1,-4,0,label);e.Amount.TextSize=math.min(e.Big and 19 or 17,label);Fit.Attach(e.Amount,math.min(e.Big and 19 or 17,label),10)
  local art=math.max(16,math.min(w-12,h-label*2-14));e.Art.AnchorPoint=Vector2.new(.5,.5);e.Art.Position=UDim2.new(.5,0,.5,0);e.Art.Size=UDim2.fromOffset(e.Big and math.min(w-12,art*1.5)or art,art)
  local tick=math.floor(math.min(w,h)*.5);e.Check.Position=UDim2.fromScale(.5,.5);e.Check.Size=UDim2.fromOffset(tick,tick)
  -- TODAY replaces the day's name (a gold pill in the same place).
  e.Today.AnchorPoint=Vector2.new(.5,0);e.Today.Position=UDim2.new(.5,0,0,3);e.Today.Size=UDim2.fromOffset(math.min(w-10,76),label+2);e.Today.TextSize=math.min(14,label)
 end
 claimButton.AnchorPoint=Vector2.new(.5,0);claimButton.Position=UDim2.new(.5,0,0,cardsTop+blockH+gap*2);claimButton.Size=UDim2.fromOffset(math.min(pw,360),buttonH);claimText.TextSize=short and 18 or 22
 -- QUESTS
 -- Narrow screens: the 💎 chip and the CLAIM button share one spot (CLAIM shows when the quest is done).
 local narrow=pw<520;narrowQuests=narrow
 local qTitle=short and 24 or 30;questTitle.Size=UDim2.fromOffset(pw*.45,qTitle);questTitle.TextSize=short and 16 or 20
 questReset.Position=UDim2.fromOffset(pw*.45,0);questReset.Size=UDim2.fromOffset(pw*.55,qTitle);questReset.TextSize=(short or narrow)and 13 or 15
 questReset.Text=resetText()
 local rowGap=short and 6 or 10;local rowH=math.clamp(math.floor((ph-qTitle-rowGap*D.QuestsPerDay)/D.QuestsPerDay),44,76)
 for i,r in ipairs(rows)do
  r.Row.Position=UDim2.fromOffset(0,qTitle+rowGap+(i-1)*(rowH+rowGap));r.Row.Size=UDim2.fromOffset(pw,rowH)
  local icon=rowH-12;r.IconBack.Position=UDim2.fromOffset(6,6);r.IconBack.Size=UDim2.fromOffset(icon,icon)
  local buttonW=narrow and math.max(84,math.floor(pw*.26))or math.min(120,math.floor(pw*.2))
  local rewardW=narrow and buttonW or math.min(78,math.floor(pw*.14))
  local textX=icon+16;local textW=narrow and pw-textX-buttonW-20 or pw-textX-buttonW-rewardW-28
  r.Task.Position=UDim2.fromOffset(textX,4);r.Task.Size=UDim2.fromOffset(textW,math.floor(rowH*.48));r.Task.TextSize=math.min(19,math.floor(rowH*.34))
  r.Bar.Position=UDim2.fromOffset(textX,math.floor(rowH*.56));r.Bar.Size=UDim2.fromOffset(textW,math.max(12,math.floor(rowH*.28)))
  r.Reward.Position=UDim2.fromOffset(narrow and pw-buttonW-8 or pw-buttonW-rewardW-14,math.floor(rowH*.18));r.Reward.Size=UDim2.fromOffset(rewardW,math.floor(rowH*.64))
  r.Reward.Visible=not narrow or(not r.Claim.Visible and not r.Done.Visible)
  local gem=math.floor(rowH*.5);r.Gem.Position=UDim2.fromOffset(4,math.floor((rowH*.64-gem)/2));r.Gem.Size=UDim2.fromOffset(gem,gem)
  r.Gems.Position=UDim2.fromOffset(gem+6,0);r.Gems.Size=UDim2.new(1,-gem-10,1,0)
  r.Claim.Position=UDim2.fromOffset(pw-buttonW-8,math.floor(rowH*.16));r.Claim.Size=UDim2.fromOffset(buttonW,math.floor(rowH*.68))
  r.Done.Position=r.Claim.Position;r.Done.Size=r.Claim.Size
 end
end
watch(panel:GetPropertyChangedSignal('AbsoluteSize'),layout)
-- State ----------------------------------------------------------------------------------------------------------------
local busy,selected,openedAuto=false,'Login',false
local pulses={}
local function stopPulses()for _,t in ipairs(pulses)do t:Cancel()end;table.clear(pulses)end
local function pulse(o,prop,a,b)
 if GuiService.ReducedMotionEnabled then return end
 o[prop]=a;local t=Tween:Create(o,TweenInfo.new(.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{[prop]=b});t:Play();pulses[#pulses+1]=t
end
local function render()
 stopPulses()
 -- The open tab gets a white ring (its BrightUI outline), like the Index's biome tabs.
 for name,t in pairs(tabs)do local edge=t:FindFirstChild('BrightOutline');if edge then edge.Color=name==selected and Color3.new(1,1,1)or RGB(12,17,38);edge.Thickness=name==selected and 3 or 2 end;pages[name].Visible=name==selected end
 local login=state and state.Login or{Ready=false,Next=1,Claimed=0}
 for d,e in ipairs(days)do
  local claimed=d<=login.Claimed;local today=login.Ready and d==login.Next
  e.Check.Visible=claimed;e.Dim.Visible=claimed;e.Today.Visible=today;e.Day.Visible=not today
  e.Edge.Color=today and GOLD or(e.Big and RGB(196,150,255)or Theme.Colors.Line);e.Edge.Thickness=today and 4 or 2
  if today then pulse(e.Edge,'Transparency',0,.55)end
 end
 if login.Ready then
  claimText.Text=login.Next==#D.Login and'CLAIM YOUR MECH PACK!'or'CLAIM DAY '..login.Next..'!';tint(claimButton,GOLD);claimButton.Active=true;claimButton.AutoButtonColor=true
  pulse(claimButton.Pulse,'Scale',1,1.05)
 else
  claimText.Text='NEXT REWARD IN '..D.Countdown(resetLeft());tint(claimButton,RGB(96,104,140));claimButton.Active=false;claimButton.AutoButtonColor=false
 end
 for i,r in ipairs(rows)do
  local q=state and state.Quests and state.Quests[i]
  r.Row.Visible=q~=nil
  if q then
   local complete=q.Progress>=q.Goal
   r.Icon.Text=q.Icon;r.Task.Text=q.Text;r.Count.Text=q.Progress..' / '..q.Goal;r.Fill.Size=UDim2.fromScale(math.clamp(q.Progress/q.Goal,0,1),1)
   r.Claim.Visible=complete and not q.Claimed and not q.Blocked;r.Done.Visible=q.Claimed or q.Blocked;r.Done.Text=q.Claimed and '✓ DONE'or 'DAILY LIMIT'
   r.Gems.Text=tostring(q.Gems)
   r.Edge.Color=complete and not q.Claimed and not q.Blocked and GOLD or Theme.Colors.Line;r.Row.BackgroundColor3=q.Claimed and Theme.Colors.Inset or Theme.Colors.Card
   if complete and not q.Claimed and not q.Blocked then pulse(r.Claim.Pulse,'Scale',1,1.06)end
   if not complete and not q.Blocked then r.Done.Visible=false end
  end
 end
 layout()
end
local function updateBadges()
 local loginReady=player:GetAttribute('DailyLoginReady')==true;local quests=tonumber(player:GetAttribute('DailyQuestsReady'))or 0
 local n=(loginReady and 1 or 0)+quests
 -- (overhang 1: the DAILY button sits 4 px under the top of the screen, which cuts off whatever hangs past it)
 local b=Badge.Make(dailyButton,'RewardBadge',20,1);local before=b.Visible and tonumber(b.Count.Text)or 0
 Badge.Set(b,Badge.Text(n),n>0,n>before)
 Badge.Set(Badge.Make(tabs.Login,'RewardDot',14,-3),'',loginReady,false)
 Badge.Set(Badge.Make(tabs.Quests,'RewardDot',14,-3),'',quests>0,false)
end
local function fetch()
 task.spawn(function()
  local ok,result=pcall(request.InvokeServer,request,'Daily','State')
  if ok and type(result)=='table'and result.Success~=false and result.Login then state=result;stateAt=os.clock()end
  if gui.Parent then render()end
 end)
end
local function say(message)
 status.Text=message or'';status.Visible=status.Text~='';layout()
end
local function claim(value)
 if busy then return end;busy=true
 task.spawn(function()
  local ok,result=pcall(request.InvokeServer,request,'Daily',value);busy=false;if not gui.Parent then return end
  if ok and type(result)=='table'then
   if result.Login then state=result;stateAt=os.clock()end
   say(result.Message)
   if result.Success then
    Audio.Play('GemClaim')
    if value=='ClaimLogin'then local e=days[state.Login.Claimed];if e then pop(e.Card,1.18)end
    elseif type(value)=='table'then local r=rows[value.Quest];if r then pop(r.Row,1.06)end end
   else Audio.Play('Denied')end -- R150: a refused claim
  else say('Please try again.');Audio.Play('Denied')end
  render();updateBadges()
 end)
end
claimButton.Activated:Connect(function()if claimButton.Active then claim('ClaimLogin')end end)
for i,r in ipairs(rows)do r.Claim.Activated:Connect(function()if r.Claim.Visible then claim({Quest=i})end end)end
local ticking=false
local function open(value,tab)
 if tab then selected=tab end
 panel.Visible=value;shade.Visible=value
 if value then
  if pg:GetAttribute('SeedMenu')~='Daily'then pg:SetAttribute('SeedMenu','Daily')end
  say('');render();fetch()
  -- The countdowns tick once a second, only while the window is open.
  if not ticking then ticking=true
   local function tick()
    if not panel.Visible or not gui.Parent then ticking=false;return end
    if resetLeft()<=0 then fetch()end
    questReset.Text=resetText()
    if state and not state.Login.Ready then claimText.Text='NEXT REWARD IN '..D.Countdown(resetLeft())end
    task.delay(1,tick)
   end
   task.delay(1,tick)
  end
 else
  stopPulses()
  if pg:GetAttribute('SeedMenu')=='Daily'then pg:SetAttribute('SeedMenu',nil)end
 end
end
for name,t in pairs(tabs)do t.Activated:Connect(function()selected=name;render()end)end
dailyButton.Activated:Connect(function()open(not panel.Visible,(player:GetAttribute('DailyLoginReady')~=true and(tonumber(player:GetAttribute('DailyQuestsReady'))or 0)>0)and'Quests'or nil)end)
close.Activated:Connect(function()open(false)end);shade.Activated:Connect(function()open(false)end)
watch(pg:GetAttributeChangedSignal('SeedMenu'),function()local want=pg:GetAttribute('SeedMenu')=='Daily';if panel.Visible~=want then open(want)end end)
watch(player:GetAttributeChangedSignal('DailyRevision'),function()updateBadges();if panel.Visible then fetch()end end)
for _,key in ipairs({'DailyLoginReady','DailyQuestsReady'})do watch(player:GetAttributeChangedSignal(key),updateBadges)end
-- The week's card opens by itself once a session when a login reward is waiting (after the tutorial).
-- R151: returning players are still on the title screen when their reward is published, and the 3 s check used to give up
-- for the whole session there; now it waits for the title screen (or another menu) to close and tries again.
local autoWaiting=false
local function autoOpen()
 if openedAuto or autoWaiting or player:GetAttribute('DailyLoginReady')~=true or player:GetAttribute('TutorialDone')~=true then return end
 if pg:GetAttribute('SeedMenu')~=nil or pg:GetAttribute('TitleActive')==true then return end -- (tried again when they close)
 autoWaiting=true
 task.delay(3,function()
  autoWaiting=false
  if openedAuto or not gui.Parent or player:GetAttribute('DailyLoginReady')~=true then return end
  if panel.Visible then openedAuto=true;return end -- (they opened it themselves)
  if pg:GetAttribute('SeedMenu')==nil and pg:GetAttribute('TitleActive')~=true then openedAuto=true;open(true,'Login')end
 end)
end
for _,key in ipairs({'DailyLoginReady','TutorialDone'})do watch(player:GetAttributeChangedSignal(key),autoOpen)end
for _,key in ipairs({'TitleActive','SeedMenu'})do watch(pg:GetAttributeChangedSignal(key),autoOpen)end
-- Invite + friend boost (R148: friends speed up the speed GAINED from training, not the walk speed) --------------------
local inviteHint=text(inviteButton,'InviteHint','',14,Theme.Colors.Muted);inviteHint.Visible=false;inviteHint.BackgroundTransparency=.15;inviteHint.BackgroundColor3=Theme.Colors.Panel;inviteHint.ZIndex=30;Theme.Corner(inviteHint,8)
inviteHint.AnchorPoint=Vector2.new(.5,0);inviteHint.Position=UDim2.new(.5,0,1,6);inviteHint.Size=UDim2.fromOffset(230,26)
local function hint(message)
 inviteHint.Text=message;inviteHint.Visible=true;local serial=(inviteHint:GetAttribute('Serial')or 0)+1;inviteHint:SetAttribute('Serial',serial)
 task.delay(2.5,function()if inviteHint:GetAttribute('Serial')==serial then inviteHint.Visible=false end end)
end
inviteButton.Activated:Connect(function()
 task.spawn(function()
  local ok,can=pcall(SocialService.CanSendGameInviteAsync,SocialService,player)
  if not ok or not can then hint('Invites are not available here');Audio.Play('Denied');return end
  local options;pcall(function()options=Instance.new('ExperienceInviteOptions');options.PromptMessage='Friends here boost your speed gain! 👥'end)
  if not pcall(SocialService.PromptGameInvite,SocialService,player,options)then pcall(SocialService.PromptGameInvite,SocialService,player)end
 end)
end)
local function friendChip()
 local n=tonumber(player:GetAttribute('FriendsInServer'))or 0;local boost=tonumber(player:GetAttribute('FriendSpeedBoost'))or 1
 local chip=inviteButton:FindFirstChild('Boost')
 if not chip then
  chip=new('TextLabel',{Name='Boost',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,0),Size=UDim2.fromOffset(40,18),BackgroundColor3=MINT,BorderSizePixel=0,ZIndex=20,Font=Enum.Font.FredokaOne,TextScaled=true,TextColor3=Theme.Colors.Ink,Visible=false},inviteButton)
  Theme.Corner(chip,9);stroke(chip,Color3.new(1,1,1),2);new('UIScale',{},chip)
 end
 local before=chip.Visible and chip.Text or''
 chip.Visible=n>0;chip.Text='+'..math.floor((boost-1)*100+.5)..'%'
 inviteButton:SetAttribute('AccessibleLabel',n>0 and('Invite friends. '..n..' here: +'..math.floor((boost-1)*100+.5)..'% speed gain')or'Invite friends. Each friend here: +'..math.floor(D.FriendBoostPerFriend*100+.5)..'% speed gain')
 if chip.Visible and chip.Text~=before then pop(chip)end
end
for _,key in ipairs({'FriendsInServer','FriendSpeedBoost'})do watch(player:GetAttributeChangedSignal(key),friendChip)end
-- "Your plant is ready" opt-in: asked once a session, a moment after planting, when the owner has set it up --------------
local asked=false
watch(player:GetAttributeChangedSignal('SeedsPlanted'),function()
 if asked or player:GetAttribute('PlantReadyAlerts')~=true or player:GetAttribute('TutorialDone')~=true then return end
 asked=true
 task.delay(2.5,function()
  local okService,service=pcall(game.GetService,game,'ExperienceNotificationService');if not okService or not service then return end
  local ok,can=pcall(service.CanPromptOptInAsync,service)
  if not ok then asked=false;return end -- R151: a failed check (web hiccup) is tried again at the next planting, not given up for the session
  if can then pcall(service.PromptOptIn,service)end
 end)
end)
updateBadges();friendChip();autoOpen();layout()
gui.Destroying:Connect(function()stopPulses();for _,c in ipairs(connections)do c:Disconnect()end;dailyButton:Destroy();inviteButton:Destroy()end)
