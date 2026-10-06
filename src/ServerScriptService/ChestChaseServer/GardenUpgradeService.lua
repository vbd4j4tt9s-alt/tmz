-- Server-owned transactions. Two anchored buttons per base, animated only on a press.
-- R153 (owner: "fix all jittery type effects"): the press itself is drawn by every client (InteractionFeedback, at the frame rate); the server only
-- stamps it (PressedAt153). It used to tween the cap here, which replicated in network-rate steps.
local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Rules=require(RS:WaitForChild('GardenFenceRules'));local Art=require(script.Parent.GardenFenceArt)
local U={};local V,CF=Vector3.new,CFrame.new;local RGB=Color3.fromRGB
local function cash(n)
 local str=tostring(math.floor(n));local formatted=str:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','');return '$'..formatted
end
local function part(parent,name,size,frame,color)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
-- R151 treadmill polish (approved: docs/proposals/R151/treadmills.md): a small studded sign beside the Treadmill button, facing the treadmill,
-- in the NEXT level's colours: "UPGRADE", "LV 3  >  LV 4", "+335  >  +2K/step" and the price (green when affordable, red when not), or
-- "MAX LEVEL"; and a neon rim round that button's housing in the treadmill's trim colour. Numbers are written like the speed popups
-- (TreadmillLook151.Format = SpeedPopupStyle.FormatGain). Show only: no part collides, answers raycasts or touches; the button, its prompt and its
-- click detector are unchanged. Any failure leaves the buttons exactly as before (the sign is skipped).
local function lookR151()
 local ok,m=pcall(function()local x=RS:FindFirstChild('TreadmillLook151');return x and require(x)end)
 return ok and m or nil
end
local function signR151(model,housing)
 local look=lookR151();if not look then return nil end
 local sign={Look=look,Ink={},Board=nil,Edges={},Rims={},Text={}}
 local h=housing.CFrame;local x=-6.1
 local function P(name,size,frame,material)
  local v=part(model,name,size,h*frame,RGB(60,60,70));v.Material=material or Enum.Material.SmoothPlastic;v.CanQuery=false;v.CastShadow=false;return v
 end
 for _,z in ipairs({-3.15,3.15})do sign.Ink[#sign.Ink+1]=P('Sign post',V(.5,4.6,.5),CF(x,-.75+2.3,z),Enum.Material.Slate)end
 sign.Board=P('Sign board',V(.36,2.7,6.9),CF(x,2.55,0))
 sign.Ink[#sign.Ink+1]=P('Sign top beam',V(.7,.42,7.5),CF(x,4.11,0),Enum.Material.Slate)
 sign.Studs={}
 for k=-2,2 do local st=P('Sign stud',V(.16,.42,.42),CF(x,4.4,k*1.45)*CFrame.Angles(0,0,math.pi/2),Enum.Material.Slate);st.Shape=Enum.PartType.Cylinder;sign.Studs[#sign.Studs+1]=st end
 for _,z in ipairs({-3.5,3.5})do sign.Edges[#sign.Edges+1]=P('Sign glow edge',V(.1,2.7,.1),CF(x+.24,2.55,z),Enum.Material.Neon)end
 sign.Edges[#sign.Edges+1]=P('Sign glow edge',V(.1,.1,7.1),CF(x+.24,1.15,0),Enum.Material.Neon)
 for _,side in ipairs({-1,1})do
  sign.Rims[#sign.Rims+1]=P('Button rim glow',V(10.48,.12,.06),CF(0,.18,side*5.23),Enum.Material.Neon)
  sign.Rims[#sign.Rims+1]=P('Button rim glow',V(.06,.12,10.48),CF(side*5.23,.18,0),Enum.Material.Neon)
 end
 local gui=Instance.new('SurfaceGui');gui.Name='UpgradeSign';gui.Face=Enum.NormalId.Right;gui.CanvasSize=Vector2.new(690,270);gui.LightInfluence=0;gui.MaxDistance=80;gui.Parent=sign.Board
 local function text(name,y,hgt)
  local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Position=UDim2.new(0,20,0,y);t.Size=UDim2.new(1,-40,0,hgt);t.Text=''
  t.TextScaled=true;t.Font=Enum.Font.FredokaOne;t.TextColor3=RGB(255,255,255);t.TextStrokeColor3=RGB(0,0,0);t.TextStrokeTransparency=.3;t.Parent=gui;return t
 end
 sign.Text.Title=text('Title',12,62);sign.Text.Levels=text('Levels',80,58);sign.Text.Gain=text('Gain',142,50)
 local price=Instance.new('TextLabel');price.Name='Price';price.Position=UDim2.new(.5,-130,0,200);price.Size=UDim2.new(0,260,0,56);price.Text=''
 price.TextScaled=true;price.Font=Enum.Font.FredokaOne;price.TextColor3=RGB(255,255,255);price.TextStrokeTransparency=.4;price.BackgroundColor3=RGB(200,66,65);price.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,14);corner.Parent=price
 sign.Text.Price=price
 return sign
end
local function setIf(o,k,v)if o[k]~=v then o[k]=v end end
local function paintSignR151(sign,config,level,balance)
 local look=sign.Look;local tiers=config.TreadmillTiers or{}
 local nextLevel=tiers[level+1]and level+1 or nil
 local function theme(l)
  local ok,t=pcall(function()return require(RS:WaitForChild('MysteryPackRules')).Theme(tiers[l]and tiers[l].Stage)end)
  return ok and t or{Body={104,82,168},Trim={176,118,255},Glow={226,200,255},Ink={62,55,88}}
 end
 local function c3(t)return RGB(t[1],t[2],t[3])end
 local shown,now=theme(nextLevel or level),look.Biomes[look.BiomeOf(level)]
 local ink=c3(shown.Ink)
 for _,v in ipairs(sign.Ink)do setIf(v,'Color',ink)end
 for _,v in ipairs(sign.Studs)do setIf(v,'Color',ink:Lerp(RGB(255,255,255),.12))end
 setIf(sign.Board,'Color',ink:Lerp(RGB(0,0,0),.25))
 for _,v in ipairs(sign.Edges)do setIf(v,'Color',c3(shown.Trim))end
 for _,v in ipairs(sign.Rims)do setIf(v,'Color',now and now.Neon or c3(shown.Trim))end
 local function gain(l)local t=tiers[l];return t and look.LabelText(look.StepGain(config.TrainingPointsPerSecond,config.TrainingInterval,t.Multiplier))end
 local T=sign.Text
 if nextLevel then
  setIf(T.Title,'Text','UPGRADE');setIf(T.Levels,'Text','LV '..level..'  >  LV '..nextLevel);setIf(T.Levels,'TextColor3',c3(shown.Glow))
  local a,b=gain(level),gain(nextLevel)
  setIf(T.Gain,'Text',(a and b)and(a:gsub('/step','')..'  >  '..b)or'');setIf(T.Gain,'TextColor3',c3(shown.Trim))
  local cost=tonumber(tiers[nextLevel].Cost)or 0
  setIf(T.Price,'Text','$'..look.Format(cost));setIf(T.Price,'Visible',true)
  setIf(T.Price,'BackgroundColor3',(tonumber(balance)or 0)>=cost and RGB(67,185,98)or RGB(200,66,65))
 else
  setIf(T.Title,'Text','MAX LEVEL');setIf(T.Levels,'Text','');setIf(T.Gain,'Text',gain(level)or'');setIf(T.Gain,'TextColor3',c3(shown.Glow))
  setIf(T.Price,'Visible',false)
 end
end
function U.Clear(self,record)
 self.GardenUpgradeRecords=self.GardenUpgradeRecords or{}
 local state=self.GardenUpgradeRecords[record.Index];if state then
  for _,c in ipairs(state.Connections)do c:Disconnect()end
  if state.Model then state.Model:Destroy()end;self.GardenUpgradeRecords[record.Index]=nil
 end
end
function U.CanPress(self,player,record,cap)
 local char=player and player.Character;local root=char and char:FindFirstChild('HumanoidRootPart');local hum=char and char:FindFirstChildOfClass('Humanoid')
 return record and self.BaseOwners[record.Index]==player and self:GetPlayerBase(player)==record and root and hum and hum.Health>0
  and cap and cap.Parent and(root.Position-cap.Position).Magnitude<=12 and self.PlayerData:IsLoaded(player)
  and not self.BusyChecker(player)and not player:GetAttribute('GuardianRagdollActive')
end
function U.Refresh(self,player)
 local record=self:GetPlayerBase(player);if not record then return end
 U.Clear(self,record);local tier=self.PlayerData:GetFenceTier(player);Art.Build(record.Model,tier)
 local model=Instance.new('Model');model.Name='GardenUpgradeButtons';model:SetAttribute('OwnerUserId',player.UserId);model.Parent=record.Model
 local state={Model=model,Connections={},Buttons={},Busy=false};self.GardenUpgradeRecords[record.Index]=state
 local pad=record.Model.Pad;local origin=pad.CFrame*CF(0,pad.Size.Y/2,0)
 local function connect(signal,fn)table.insert(state.Connections,signal:Connect(fn))end
 for i,kind in ipairs({'Treadmill','Fence'})do
  local pos=CF(-49,.75,68.5+(i-1)*11.5)
  part(model,kind..' housing',V(10.4,1.5,10.4),origin*pos,RGB(47,62,55))
  local cap=part(model,kind..' button',V(9.6,.55,9.6),origin*pos*CF(0,.90,0),RGB(67,185,98));cap:SetAttribute('GardenUpgradeKind',kind)
  local home=cap.CFrame;cap:SetAttribute('PressHome153',home);CS:AddTag(cap,'GardenUpgradeCap153');local surface=Instance.new('SurfaceGui');surface.Name='ButtonLabel';surface.Face=Enum.NormalId.Top;surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;surface.CanvasSize=Vector2.new(512,512);surface.LightInfluence=0;surface.MaxDistance=100;surface.Parent=cap
  local function lettering(name,text,y,height,maxSize,minSize,font)
   local label=Instance.new('TextLabel');label.Name=name;label.Size=UDim2.new(1,-40,0,height);label.Position=UDim2.fromOffset(20,y);label.BackgroundTransparency=1;label.Text=text;label.Font=font;label.TextScaled=true;label.TextWrapped=true;label.TextColor3=RGB(255,255,239);label.TextStrokeTransparency=.7;label.Parent=surface
   local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=maxSize;fit.MinTextSize=minSize;fit.Parent=label;return label
  end
  lettering('Action','UPGRADE\n'..kind:upper(),32,154,53,34,Enum.Font.FredokaOne)
  local price=lettering('Price','',208,116,82,32,Enum.Font.FredokaOne)
  local note=lettering('Hint','',380,84,30,18,Enum.Font.FredokaOne);note.Visible=false
  local click=Instance.new('ClickDetector');click.MaxActivationDistance=12;click.Parent=cap
  local prompt=Instance.new('ProximityPrompt');prompt.Name='UpgradePress';prompt.Style=Enum.ProximityPromptStyle.Custom;prompt.ActionText='UPGRADE';prompt.ObjectText='';prompt.KeyboardKeyCode=kind=='Fence'and Enum.KeyCode.R or Enum.KeyCode.E;prompt.GamepadKeyCode=kind=='Fence'and Enum.KeyCode.ButtonY or Enum.KeyCode.ButtonX;prompt.MaxActivationDistance=9;prompt.RequiresLineOfSight=false;prompt.HoldDuration=0;prompt:SetAttribute('GardenUpgradeOwner',player.UserId);prompt.Parent=cap
  state.Buttons[kind]={Cap=cap,Price=price,Note=note,Prompt=prompt,Home=home}
  local function press(sender)
   if state.Busy or not U.CanPress(self,sender,record,cap)then return end
   local now=os.clock();self.GardenUpgradeLast=self.GardenUpgradeLast or setmetatable({},{__mode='k'})
   if now-(self.GardenUpgradeLast[sender]or -math.huge)<.65 then return end;self.GardenUpgradeLast[sender]=now;state.Busy=true
   sender:SetAttribute('UpgradePressSerial',(sender:GetAttribute('UpgradePressSerial')or 0)+1)
   local row=state.Buttons[kind];local expected=row.Expected
   local okay,message
   if not expected then okay=false;message='Fully upgraded!'
   elseif kind=='Fence'then okay,message=self.PlayerData:BuyFence(sender,expected)
   else okay,message=self.PlayerData:BuyTreadmill(sender,expected)end
   -- R150: tell the client how the press ended, in the same replication as the tier / price change: a bought upgrade rings the till
   -- (KaChing), a refused one clicks Denied. (The press click itself, UpgradePressSerial, plays for both.)
   local resultKey=okay and'UpgradeBoughtSerial'or'UpgradeRefusedSerial'
   sender:SetAttribute(resultKey,(sender:GetAttribute(resultKey)or 0)+1)
   -- Even a rejected purchase gives a short tactile press without a debit.
   cap:SetAttribute('PressedAt153',workspace:GetServerTimeNow()) -- (every client sinks the cap .35 studs and brings it back: InteractionFeedback)
   if not okay then note.Text=message or'Try again';note.Visible=true end
   task.delay(.34,function()
    if self.GardenUpgradeRecords[record.Index]~=state then return end
    state.Busy=false
    if okay then
     if kind=='Treadmill'then self:RefreshTreadmill(sender)else U.Refresh(self,sender)end
    end
   end)
  end
  connect(click.MouseClick,press);connect(prompt.Triggered,press)
 end
 local okSign,sign=pcall(signR151,model,model:FindFirstChild('Treadmill housing'))
 if not okSign then warn('[R151] Treadmill upgrade sign skipped: '..tostring(sign));sign=nil;for _,v in ipairs(model:GetChildren())do if v.Name:find('^Sign ')or v.Name=='Button rim glow'then v:Destroy()end end end
 state.Sign=sign
 local function paint()
  local balance=self.PlayerData:GetCash(player)
  for kind,b in pairs(state.Buttons)do
   local current=kind=='Fence'and self.PlayerData:GetFenceTier(player)or self.PlayerData:GetTreadmillData(player).Tier
   local nextTier=kind=='Fence'and Rules.Tiers[current+1]or self.Config.TreadmillTiers[current+1]
   b.Expected=nextTier and current+1 or nil
   local unlocked=true
   local affordable=nextTier and balance>=nextTier.Cost
   b.Cap.Color=not nextTier and RGB(101,124,108)or affordable and unlocked and RGB(67,185,98)or RGB(200,66,65)
   b.Cap:SetAttribute('Affordable',affordable==true);b.Cap:SetAttribute('NextTier',b.Expected);b.Cap:SetAttribute('Price',nextTier and nextTier.Cost or 0)
   b.Price.Text=nextTier and cash(nextTier.Cost)or'MAX'
   b.Note.Text='';b.Note.Visible=false
   b.Prompt.Enabled=nextTier~=nil
  end
  if state.Sign then
   local ok,why=pcall(paintSignR151,state.Sign,self.Config,self.PlayerData:GetTreadmillData(player).Tier,balance)
   if not ok and not state.SignWarned then state.SignWarned=true;warn('[R151] Treadmill upgrade sign: '..tostring(why))end
  end
 end
 connect(self.PlayerData:GetOrCreateCashValue(player):GetPropertyChangedSignal('Value'),paint)
 connect(player:GetAttributeChangedSignal('TreadmillTier'),paint);connect(player:GetAttributeChangedSignal('FenceTier'),paint)
 connect(player:GetAttributeChangedSignal('DataStatus'),paint);connect(player:GetAttributeChangedSignal('TreadmillUnlockRevision'),paint)
 paint()
end
return U
