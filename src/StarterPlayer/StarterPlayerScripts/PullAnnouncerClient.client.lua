-- R151 (owner: "serverwide messages saying who pulled what and so on and a in server announcement"): pull announcements, the CLIENT half.
-- The server (PullAnnouncer) decides and sends {Kind='Pull'|'Global'|'Record', ...} through ChestChaseRemotes.PullAnnounce151; this script only draws it
-- and nothing it does can start an announcement. Every payload is sanitised again (PullAnnounceRules.Event: the rarity comes from the local seed catalog).
--  * Banner   a chunky violet panel with a rarity-coloured frame slides in at the top centre for about 4 s: the puller's headshot (Players:GetUserThumbnailAsync,
--             cached), the sentence "Name pulled a MYTHIC Fire Pepper! (1/800)", a small line (biome, coat, weight), the seed's picture (ItemPictures) and a ribbon
--             "MYTHIC PULL!!". A pull in ANOTHER server is the small gold variant ("in another server"); a record ("took BEST PULL TODAY!") has an amber frame.
--  * Place    below the first notice row (HudNoticeLayout) and clear of the HUD boxes (HudLayout); while it shows it publishes PullBannerBottom on the PlayerGui so
--             HudNotices pushes every other notice row (and with it the NoticeFeed83 lines) below it: nothing overlaps.
--  * Queue    at most MaxWaiting banners wait (PullAnnounceRules.Enqueue); when flooded the lowest rarity goes and the best waiting banner says "+N more".
--  * Chat     a system line on RBXGeneral (TextChatService, rich text in the rarity colour; gold for other servers) for every pull, whether or not its banner shows.
--  * Sound    the rarity's own reveal burst (RarityRevealAudio: AudioMixer Effects group, so Effects 0 mutes it; not for your own pull, you just heard it).
--  * Motion   slide + a shine sweep and sparkles (Mythic and up). ReducedMotion: no slide, no sweep, no sparkles. FastMode: no sweep, at most 3 sparkles.
--             One RenderStepped connection exists only while a shine or sparkles are moving; an idle client runs nothing.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local GuiService=game:GetService('GuiService');local Tween=game:GetService('TweenService');local StarterGui=game:GetService('StarterGui')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local Rules=require(RS:WaitForChild('PullAnnounceRules'));local Art=require(RS:WaitForChild('BonusGiftArt'))
local folder=RS:WaitForChild('ChestChaseRemotes',120);local remote=folder and folder:WaitForChild(Rules.RemoteName,120)
if not remote then return end
local function optional(name)
 local module=RS:FindFirstChild(name);if not module then return nil end
 local ok,value=pcall(require,module);return ok and value or nil
end
local Pictures=optional('ItemPictures');local Reveal=optional('RarityRevealAudio');local Mixer=optional('AudioMixer')
local HudLayout=optional('HudLayout');local Budget=optional('ClientFxBudget')
local RGB=Color3.fromRGB;local INK,WHITE=Art.INK,Art.WHITE
local make,round,pill,stroke=Art.make,Art.round,Art.pill,Art.stroke
local dead=false;local connections={}
local function connect(signal,fn)local c=signal:Connect(fn);table.insert(connections,c);return c end
local function reduced()
 local ok,value=pcall(function()return GuiService.ReducedMotionEnabled end)
 return ok and value==true
end
local function lite()
 if player:GetAttribute('FastMode')==true then return true end
 local mode=player:GetAttribute('StudioPlantEffects');if mode=='off'or mode=='low'then return true end
 if Budget then local ok,tier=pcall(Budget.Get);if ok and tier==1 then return true end end
 return false
end
if Reveal then pcall(Reveal.Preload)end

-- Chat -------------------------------------------------------------------------------------------------------------------------------------------
local chatChannel;local chatLog={}
local function channel()
 if chatChannel and chatChannel.Parent then return chatChannel end
 local ok,found=pcall(function()
  local channels=game:GetService('TextChatService'):FindFirstChild('TextChannels')
  return channels and channels:FindFirstChild('RBXGeneral')
 end)
 chatChannel=ok and found or nil;return chatChannel
end
local function chat(e)
 if not Rules.ChatAllowed(chatLog,os.clock())then return end
 local target=channel()
 if target then
  local ok=pcall(function()target:DisplaySystemMessage(Rules.Chat(e),'PullAnnounce151')end)
  if ok then return end
 end
 -- the old chat (not TextChatService): a plain line in the same colour
 pcall(function()StarterGui:SetCore('ChatMakeSystemMessage',{Text=Rules.Line(e,false),Color=Rules.ChatColor(e),Font=Enum.Font.GothamBold,FontSize=Enum.FontSize.Size18})end)
end

-- Headshots (cached; fetched as soon as an event arrives, so the picture is usually ready when its banner shows) ---------------------------------
local thumbs,thumbOrder={},{}
local function headshot(userId,onReady)
 if type(userId)~='number'or userId<=0 then return end
 local entry=thumbs[userId]
 if entry and entry.Failed then
  if os.clock()-entry.Failed<3 then return end -- it just failed (this same announcement asks twice): not again for a moment
  entry=nil;thumbs[userId]=nil;local i=table.find(thumbOrder,userId);if i then table.remove(thumbOrder,i)end
 end
 if entry then
  if entry.Image then if onReady then onReady(entry.Image)end elseif onReady then table.insert(entry.Waiters,onReady)end
  return
 end
 entry={Waiters={onReady}};thumbs[userId]=entry;table.insert(thumbOrder,userId)
 while#thumbOrder>40 do thumbs[table.remove(thumbOrder,1)]=nil end
 task.spawn(function()
  local ok,image=pcall(function()return(Players:GetUserThumbnailAsync(userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100))end)
  if ok and type(image)=='string'and image~=''then
   entry.Image=image
   for _,wait in ipairs(entry.Waiters)do pcall(wait,image)end
  else entry.Failed=os.clock()end -- the letter shows instead; a later announcement asks again
  entry.Waiters={}
 end)
end

-- Banner (built on the first announcement) ---------------------------------------------------------------------------------------------------------
do local old=pg:FindFirstChild('PullAnnouncer');if old then old:Destroy()end end
local gui,root,panel,shadow,wrap,inner,avatar,avatarRing,headshotImage,initial,line1,line2,pic,picGlow,picture,picFallback,ribbon,ribbonTitle,tails,shine,fx
local studs={}
local function diamond(parent,name,size,color,z)
 local d=make('Frame',{Name=name,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(size,size),Rotation=45,BackgroundColor3=color,BorderSizePixel=0,ZIndex=z},parent)
 stroke(d,INK,1);return d
end
local function build()
 if gui then return end
 gui=make('ScreenGui',{Name='PullAnnouncer',ResetOnSpawn=false,DisplayOrder=62,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets},pg)
 root=make('Frame',{Name='Banner',BackgroundTransparency=1,BorderSizePixel=0,Active=false,Visible=false},gui)
 shadow=make('Frame',{Name='Shadow',BackgroundColor3=INK,BackgroundTransparency=.62,BorderSizePixel=0,ZIndex=1},root);round(shadow,15)
 panel=make('Frame',{Name='Panel',BackgroundColor3=WHITE,BorderSizePixel=0,ZIndex=2},root);round(panel,14);stroke(panel,Art.GOLD,3)
 make('UIGradient',{Name='Fill',Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(70,60,160)),ColorSequenceKeypoint.new(.55,RGB(36,30,92)),ColorSequenceKeypoint.new(1,RGB(18,16,46))}),Rotation=70},panel)
 wrap=Art.Stripes(panel,4,35,.93,2);round(wrap,14)
 inner=make('Frame',{Name='InnerLine',BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),ZIndex=2},panel)
 round(inner,10);stroke(inner,Art.GOLD,1,.55)
 for i,c in ipairs({{0,0},{1,0},{0,1},{1,1}})do local d=diamond(inner,'Stud'..i,7,Art.GOLD,3);d.Position=UDim2.fromScale(c[1],c[2]);studs[i]=d end
 avatar=make('Frame',{Name='Avatar',BackgroundColor3=RGB(24,22,60),BorderSizePixel=0,ZIndex=3},panel);pill(avatar)
 avatarRing=stroke(avatar,Art.GOLD,2.5)
 headshotImage=make('ImageLabel',{Name='Headshot',BackgroundTransparency=1,BorderSizePixel=0,Image='',Size=UDim2.fromScale(1,1),ZIndex=4,Visible=false},avatar);pill(headshotImage)
 initial=Art.fitText(avatar,'Initial','?',22,10,RGB(214,206,255));initial.Size=UDim2.fromScale(1,1);initial.ZIndex=4
 line1=make('TextLabel',{Name='Line1',BackgroundTransparency=1,BorderSizePixel=0,RichText=true,Text='',Font=Enum.Font.GothamBlack,TextColor3=WHITE,TextStrokeColor3=INK,
  TextStrokeTransparency=.2,TextScaled=true,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=4},panel)
 make('UITextSizeConstraint',{MaxTextSize=18,MinTextSize=11},line1)
 line2=make('TextLabel',{Name='Line2',BackgroundTransparency=1,BorderSizePixel=0,Text='',Font=Enum.Font.GothamBold,TextColor3=RGB(214,206,255),TextSize=13,
  TextStrokeColor3=INK,TextStrokeTransparency=.35,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=4},panel)
 pic=make('Frame',{Name='Pic',BackgroundColor3=WHITE,BorderSizePixel=0,ZIndex=3},panel);round(pic,10);stroke(pic,Art.GOLD,2.5)
 make('UIGradient',{Name='Fill',Color=ColorSequence.new(RGB(90,70,150),RGB(24,20,60)),Rotation=90},pic)
 picGlow=make('Frame',{Name='Glow',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.8,.8),BackgroundColor3=Art.GOLD,BackgroundTransparency=.72,BorderSizePixel=0,ZIndex=4},pic)
 pill(picGlow)
 picture=make('Frame',{Name='Picture',BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(3,3),Size=UDim2.new(1,-6,1,-6),ZIndex=5},pic)
 picFallback=Art.fitText(pic,'Fallback','🌱',34,12);picFallback.Size=UDim2.fromScale(1,1);picFallback.ZIndex=5;picFallback.Visible=false
 shine=Art.Shine(panel,6,6,.6,6)
 ribbon=make('Frame',{Name='Ribbon',BackgroundColor3=WHITE,BorderSizePixel=0,ZIndex=5},root);round(ribbon,8);stroke(ribbon,INK,2)
 make('UIGradient',{Name='Fill',Color=ColorSequence.new(RGB(255,236,140),RGB(232,140,36)),Rotation=90},ribbon)
 tails={}
 for i,x in ipairs({0,1})do local tail=diamond(ribbon,'Tail'..i,12,RGB(214,128,30),2);tail.Position=UDim2.new(x,x==0 and 2 or-2,.5,0);tails[i]=tail end
 ribbonTitle=Art.fitText(ribbon,'Title','',17,8,INK);ribbonTitle.ZIndex=4;ribbonTitle.Size=UDim2.new(1,-30,1,0);ribbonTitle.Position=UDim2.fromOffset(15,0)
 ribbonTitle.TextStrokeColor3=RGB(255,248,220);ribbonTitle.TextStrokeTransparency=.4
 fx=make('Frame',{Name='Fx',BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Active=false,ZIndex=7},root)
end

-- The animator (one RenderStepped connection, only while the shine / sparkles move) -----------------------------------------------------------------------
local stepper,stepFns;stepFns={}
local function addStep(fn)
 if dead then return end
 table.insert(stepFns,fn)
 if not stepper then
  stepper=Run.RenderStepped:Connect(function(dt)
   dt=math.min(dt,.1)
   for i=#stepFns,1,-1 do
    local ok,done=pcall(stepFns[i],dt)
    if not ok or done then table.remove(stepFns,i)end
   end
   if#stepFns==0 and stepper then stepper:Disconnect();stepper=nil end
  end)
 end
end
local function stopSteps()
 table.clear(stepFns);if stepper then stepper:Disconnect();stepper=nil end
end

-- State -------------------------------------------------------------------------------------------------------------------------------------------
local queue=Rules.NewQueue();local current;local token=0;local seen,seenOrder={},{};local sizeConnection,noticeConnection,proxy
local lastCue=-math.huge
local function remember(id)
 if not id then return true end
 if seen[id]then return false end
 seen[id]=true;table.insert(seenOrder,id);if#seenOrder>128 then seen[table.remove(seenOrder,1)]=nil end
 return true
end
-- The first free y of the notice area, the way HudNotices measures it: below the travel buttons and the tutorial card.
local function noticeTop()
 local top=0
 local bar=pg:FindFirstChild('ChestEconomyTopBar');local nav=bar and bar:FindFirstChild('StationTravel',true)
 if nav and nav.Visible then top=math.max(top,nav.AbsolutePosition.Y+nav.AbsoluteSize.Y)end
 return math.max(top,tonumber(pg:GetAttribute('TutorialCardBottom'))or 0)
end
local function boxesFor(w,h)
 if not HudLayout then return {}end
 local ok,list=pcall(function()
  local view=Vector2.new(w,h)
  local m=HudLayout.Read(view,game:GetService('UserInputService').TouchEnabled,HudLayout.Controls(gui))
  return HudLayout.HudBoxes(m,w,h,false)
 end)
 return ok and list or {}
end
local metrics,placed,parts
local function layout()
 if not current or not gui then return end
 local view=gui.AbsoluteSize;local w,h=view.X>0 and view.X or 1280,view.Y>0 and view.Y or 720
 local e=current.Event
 metrics=Rules.Metrics(w,h,Rules.Variant(e))
 parts=Rules.Inner(metrics)
 placed=Rules.Place(w,h,noticeTop(),boxesFor(w,h),metrics)
 local box=metrics.Box
 root.Position=UDim2.fromOffset(placed.X-box,placed.Top-box);root.Size=UDim2.fromOffset(metrics.Width+2*box,metrics.Overhang+metrics.Height+2*box)
 panel.Position=UDim2.fromOffset(box,box+metrics.Overhang);panel.Size=UDim2.fromOffset(metrics.Width,metrics.Height)
 shadow.Position=UDim2.fromOffset(box+1,box+metrics.Overhang+4);shadow.Size=UDim2.fromOffset(metrics.Width-2,metrics.Height-2)
 local function put(item,r)item.Position=UDim2.fromOffset(r.X,r.Y);item.Size=UDim2.fromOffset(r.W,r.H)end
 avatar.Visible=parts.Avatar~=nil;if parts.Avatar then put(avatar,parts.Avatar)end
 pic.Visible=parts.Pic~=nil;if parts.Pic then put(pic,parts.Pic)end
 put(line1,parts.Line1);put(line2,parts.Line2);line2.TextSize=metrics.L2Size
 line1.Text=Rules.Line(e,true,metrics.NameChars);line2.Text=Rules.Subline(e,current.More,metrics.Short)
 local constraint=line1:FindFirstChildOfClass('UITextSizeConstraint');constraint.MaxTextSize=metrics.L1Max;constraint.MinTextSize=metrics.L1Min
 ribbon.Visible=parts.Ribbon~=nil
 if parts.Ribbon then
  ribbon.Position=UDim2.fromOffset(box+parts.Ribbon.X,box+parts.Ribbon.Y+metrics.Overhang);ribbon.Size=UDim2.fromOffset(parts.Ribbon.W,parts.Ribbon.H)
  ribbonTitle:FindFirstChildOfClass('UITextSizeConstraint').MaxTextSize=metrics.Compact and 12 or 17
 end
 if pg:GetAttribute('PullBannerBottom')~=placed.Bottom then pg:SetAttribute('PullBannerBottom',placed.Bottom)end
end

-- Painting one announcement ------------------------------------------------------------------------------------------------------------------------
local function tint(color)
 avatarRing.Color=color;for _,d in ipairs(studs)do d.BackgroundColor3=color end
 inner:FindFirstChildOfClass('UIStroke').Color=color
 panel:FindFirstChildOfClass('UIStroke').Color=color
end
local function paintImage(image)
 if current and headshotImage and image then headshotImage.Image=image;headshotImage.Visible=true;initial.Visible=false end
end
local function skin(item)
 local e=item.Event;local accent=Rules.Accent(e)
 tint(accent)
 panel:FindFirstChild('Fill').Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(70,60,160):Lerp(accent,.12)),ColorSequenceKeypoint.new(.55,RGB(36,30,92):Lerp(accent,.08)),
  ColorSequenceKeypoint.new(1,RGB(18,16,46))})
 line2.TextColor3=e.Kind=='Global'and RGB(255,236,170)or RGB(214,206,255)
 ribbonTitle.Text=Rules.Headline(e)
 ribbon:FindFirstChild('Fill').Color=ColorSequence.new({ColorSequenceKeypoint.new(0,accent:Lerp(WHITE,.55)),ColorSequenceKeypoint.new(.5,accent),ColorSequenceKeypoint.new(1,accent:Lerp(INK,.25))})
 for _,tail in ipairs(tails)do tail.BackgroundColor3=accent:Lerp(INK,.3)end
 picGlow.BackgroundColor3=accent
 pic:FindFirstChild('Fill').Color=ColorSequence.new(accent:Lerp(INK,.5),accent:Lerp(INK,.82))
 pic:FindFirstChildOfClass('UIStroke').Color=accent
 -- headshot: the letter until the picture arrives
 headshotImage.Visible=false;headshotImage.Image='';initial.Visible=true;initial.Text=string.upper(e.Name:sub(1,(utf8.offset(e.Name,2)or#e.Name+1)-1)) -- (the first CHARACTER, not the first byte)
 headshot(e.UserId,function(image)if current==item then paintImage(image)end end)
 -- the seed's picture: a proxy Folder with the attributes ItemPictures reads from a seed tool
 picFallback.Visible=false
 if e.SeedId and Pictures then
  proxy=Instance.new('Folder');proxy:SetAttribute('GardenSeed',true);proxy:SetAttribute('SeedId',e.SeedId);proxy:SetAttribute('Mutation',e.Mutation or'None')
  local ok=pcall(Pictures.Show,picture,proxy,2);if not ok then picFallback.Text='🌱';picFallback.Visible=true end
 else picFallback.Text=e.SeedId and'🌱'or'🏆';picFallback.Visible=true end
end
local function clearPicture()
 if Pictures and picture then pcall(Pictures.Clear,picture)end
 if proxy then proxy:Destroy();proxy=nil end
end
local function cueSound(e)
 if e.Self or not Reveal then return end
 if Mixer and Mixer.Get then local ok,volume=pcall(Mixer.Get,'Effects');if ok and volume==0 then return end end -- Effects at 0: not even asked
 local now=os.clock();if now-lastCue<.25 then return end;lastCue=now
 local cue=Rules.Cue(e)
 if cue.Rank then pcall(Reveal.Burst,cue.Rank)else pcall(Reveal.Play,cue.Key,cue.Pitch,nil,cue.Volume)end
end
-- The shine sweep over the panel and sparkles from the seed picture (not under ReducedMotion; FastMode: no sweep, few sparkles).
local function flourish(item,delay)
 if reduced()then return end
 local fxPlan=Rules.Fx(item.Event);local light=lite()
 local wantShine=fxPlan.Shine and not light;local count=light and math.min(fxPlan.Sparkles,3)or fxPlan.Sparkles
 if not wantShine and count<=0 then return end
 local t=-delay;local burst,burstDone
 local color=Rules.Accent(item.Event)
 addStep(function(dt)
  if current~=item or not gui then return true end
  t+=dt
  if wantShine then Art.SetShine(shine,(t-.05)/.8)end
  if count>0 and not burst and t>=0 then
   local box=metrics.Box;local r=parts.Pic or {X=metrics.Width/2,Y=metrics.Height/2,W=0,H=0}
   burst=Art.Burst(fx,box+r.X+r.W/2,box+metrics.Overhang+r.Y+r.H/2,{Count=count,Shape='Star',Size=11,Life=.8,Speed={40,130},Colors={color,WHITE,Art.GOLD},Drag=2.2,Z=8})
  end
  if burst and not burstDone and burst:Step(dt)then burst:Destroy();burst=nil;burstDone=true end
  if t>=1 then if burst then burst:Destroy();burst=nil end;return true end
  return false
 end)
end
local play
local function pump()
 if dead or current then return end
 local item=Rules.Dequeue(queue,os.clock())
 if not item then return end
 local ok,err=pcall(play,item)
 if not ok then -- a banner that cannot be drawn is dropped; it never blocks the next one or leaves the HUD pushed down
  warn('[R151] A pull announcement could not be shown: '..tostring(err))
  token+=1;current=nil;stopSteps()
  if root then root.Visible=false end
  if sizeConnection then sizeConnection:Disconnect();sizeConnection=nil end
  if noticeConnection then noticeConnection:Disconnect();noticeConnection=nil end
  pg:SetAttribute('PullBannerBottom',nil)
  task.delay(.5,pump)
 end
end
local function finish(my)
 if token~=my or dead then return end
 clearPicture();stopSteps();Art.SetShine(shine,0)
 if fx then fx:ClearAllChildren()end
 root.Visible=false;pg:SetAttribute('PullBannerBottom',nil)
 if sizeConnection then sizeConnection:Disconnect();sizeConnection=nil end
 if noticeConnection then noticeConnection:Disconnect();noticeConnection=nil end
 current=nil;gui:SetAttribute('Showing',nil)
 task.delay(Rules.Timing(0,reduced()).Gap,pump)
end
local function offscreen()
 local box=metrics.Box
 return metrics.Overhang+metrics.Height+2*box+placed.Top+10
end
play=function(item)
 build();current=item;token+=1;local my=token
 skin(item);layout()
 gui:SetAttribute('Showing',item.Event.Id or'?')
 root.Visible=true
 local timing=Rules.Timing(#queue.Items,reduced())
 local box=metrics.Box;local final=UDim2.fromOffset(placed.X-box,placed.Top-box)
 if timing.In>0 then
  root.Position=UDim2.fromOffset(final.X.Offset,final.Y.Offset-offscreen())
  Tween:Create(root,TweenInfo.new(timing.In,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=final}):Play()
 end
 cueSound(item.Event);flourish(item,timing.In*.7)
 -- follow a resized screen, or a notice area that moved (the tutorial card), while it shows
 local function relayout()if not dead and current==item then layout();root.Position=UDim2.fromOffset(placed.X-box,placed.Top-box)end end
 sizeConnection=gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
 noticeConnection=pg:GetAttributeChangedSignal('TutorialCardBottom'):Connect(relayout)
 -- hold at least 1.2 s, then as long as the queue allows (a backlog shortens the rest of the hold)
 local firstHold=math.min(timing.Hold,1.2)
 task.delay(timing.In+firstHold,function()
  if token~=my or dead then return end
  local rest=math.max(0,Rules.Timing(#queue.Items,reduced()).Hold-firstHold)
  task.delay(rest,function()
   if token~=my or dead then return end
   local out=Rules.Timing(0,reduced()).Out
   if out>0 then
    Tween:Create(root,TweenInfo.new(out,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.fromOffset(final.X.Offset,final.Y.Offset-offscreen())}):Play()
   end
   task.delay(out+.02,function()finish(my)end)
  end)
 end)
end

-- Events from the server ---------------------------------------------------------------------------------------------------------------------------
local function receive(payload)
 if dead or type(payload)~='table'then return end
 local e=Rules.Event(payload.Kind,payload)
 if not e or not remember(e.Id)then return end
 e.Self=e.Kind=='Pull'and e.UserId==player.UserId
 chat(e)
 headshot(e.UserId)
 if Rules.Enqueue(queue,e,os.clock())then pump()end
end
connect(remote.OnClientEvent,receive)
script.Destroying:Connect(function()
 dead=true;token+=1;stopSteps();current=nil
 for _,c in ipairs(connections)do c:Disconnect()end
 if sizeConnection then sizeConnection:Disconnect();sizeConnection=nil end
 if noticeConnection then noticeConnection:Disconnect();noticeConnection=nil end
 clearPicture();pg:SetAttribute('PullBannerBottom',nil)
 if gui then gui:Destroy()end
end)
