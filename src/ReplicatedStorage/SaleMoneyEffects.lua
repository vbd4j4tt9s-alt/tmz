-- R53: hovering/tapping claims one server-owned cash share. No timeout awards.
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService');local Players=game:GetService('Players');local GuiService=game:GetService('GuiService')
local Icon=require(RS:WaitForChild('MoneyIcon'));local Cash=require(RS:WaitForChild('CashNumbers'));local Theme=require(RS:WaitForChild('GardenTheme'))
local Rules=require(RS:WaitForChild('SaleReceiptRules'))
local Effects={};Effects.__index=Effects
local MAX_ICONS=26
local MAX_PER_CURRENCY=13
local function reduced()
 local p=Players.LocalPlayer
 return GuiService.ReducedMotionEnabled or(p and(p:GetAttribute('FastMode')or p:GetAttribute('StudioPlantEffects')=='off'))
end
local function clampPoint(p,size,pad)
 return Vector2.new(math.clamp(p.X,pad,math.max(pad,size.X-pad)),math.clamp(p.Y,pad,math.max(pad,size.Y-pad)))
end
function Effects.new(parent,wallet,claim)
 local layer=Instance.new('Frame');layer.Name='SaleMoneyEffects';layer.BackgroundTransparency=1;layer.Size=UDim2.fromScale(1,1);layer.Active=false;layer.ZIndex=60;layer.Parent=parent
 local self=setmetatable({Layer=layer,Wallet=wallet,Claim=claim,Icons={},Receipts={},Queue={},Seen={},Shares={},Random=Random.new(),Now=0},Effects)
 local hint=Instance.new('TextLabel');hint.Name='CollectCashHint';hint.AnchorPoint=Vector2.new(.5,0);hint.Position=UDim2.new(.5,0,0,98);hint.Size=UDim2.new(1,-24,0,28);hint.BackgroundTransparency=1;hint.Text='';hint.TextStrokeTransparency=.3;hint.TextStrokeColor3=Theme.Colors.Ink;Theme.Text(hint,15,true,Theme.Colors.Gold);hint.ZIndex=4;hint.Visible=false;hint.Parent=layer;self.Hint=hint
 layer.Destroying:Connect(function()self.Destroyed=true;if self.Connection then self.Connection:Disconnect();self.Connection=nil end end)
 return self
end
function Effects:_remove(index)
 local item=table.remove(self.Icons,index)
 if item then
  for _,share in ipairs(item.Shares)do
   if share.Collected then self.Shares[share.ReceiptId..':'..share.Index]=nil end
  end
  item.Button:Destroy()
 end
end
function Effects:_fly(item)
 if item.FlyAt or not item.Button.Parent then return end
 item.FlyAt=self.Now;item.Start=item.Position;item.Button.Active=false;item.Button.Selectable=false
end
function Effects:_collect(item)
 if self.Destroyed or item.Pending or item.FlyAt or item.Age<.30 or not item.Button.Parent or self.Now<(item.RetryAt or 0)then return end
 item.Pending=true
 task.spawn(function()
  local success=true
  for _,share in ipairs(item.Shares)do
   if self.Destroyed or not item.Button.Parent then return end
   if not share.Collected then
    local okay,result=pcall(self.Claim,share.ReceiptId,share.Index)
    if okay and type(result)=='table'and result.Success then share.Collected=true
    else success=false;break end
   end
  end
  item.Pending=false
  if self.Destroyed or not item.Button.Parent then return end
  if success then self:_fly(item)else item.RetryAt=self.Now+1 end
 end)
end
function Effects:Sync(receipts,origin)
 if self.Destroyed or type(receipts)~='table'then return end
 for _,r in ipairs(receipts)do
  if Rules.Valid({r})then
   local fresh={}
   for i=1,r.Count do
    local key=r.Id..':'..i
    if Rules.Claimed(r,i)then
     self.Seen[key]=true;local share=self.Shares[key];if share then share.Collected=true end
    elseif not self.Seen[key]then
     self.Seen[key]=true;self.Shares[key]={ReceiptId=r.Id,Index=i,Collected=false};table.insert(fresh,i)
    end
   end
   if #fresh>0 then table.insert(self.Queue,{Receipt=r,Indices=fresh,Origin=origin})end
  end
 end
 -- Claim masks only move forward, including when an older poll arrives late.
 for _,item in ipairs(self.Icons)do
  local collected=true;for _,share in ipairs(item.Shares)do if not share.Collected then collected=false;break end end
  if collected and not item.Pending then self:_fly(item)end
 end
 self:_flush()
 if (#self.Icons>0 or #self.Queue>0)and not self.Connection then self.Connection=Run.RenderStepped:Connect(function(dt)self:_step(dt)end)end
end
function Effects:_flush()
 local i=1
 while i<=#self.Queue do
  local nextBatch=self.Queue[i]
  if self:Burst(nextBatch.Receipt,nextBatch.Indices,nextBatch.Origin)then table.remove(self.Queue,i)
  else i+=1 end
 end
 self.Hint.Visible=false
end
function Effects:_step(dt)
 if self.Destroyed then return end
 self.Now+=dt;local size=self.Layer.AbsoluteSize
 local cashTarget=self.Wallet:TargetPosition()-self.Layer.AbsolutePosition
 local quiet=reduced()
 for i=#self.Icons,1,-1 do
  local item=self.Icons[i];item.Age+=dt
  local wallet=item.Currency=='Gems'and self.Wallet.Gems or self.Wallet
  local target=item.Currency=='Gems'and wallet:TargetPosition()-self.Layer.AbsolutePosition or cashTarget
  if item.Hovered then self:_collect(item)end
  local scale=1
  if item.FlyAt then
   local t=math.clamp((self.Now-item.FlyAt)/(quiet and .20 or .48),0,1);local eased=t*t*(3-2*t)
   item.Position=item.Start:Lerp(target,eased)+Vector2.new(0,quiet and 0 or -math.sin(t*math.pi)*35)
   scale=1-.60*eased;item.Button.Rotation=item.Rotation*(1-eased)
   if t>=1 then wallet:Pulse();self:_remove(i);continue end
  else
   local t=math.clamp(item.Age/.40,0,1);local eased=1-(1-t)^3
   item.Position=item.Origin:Lerp(clampPoint(item.Rest,size,30),eased)+Vector2.new(0,quiet and 0 or -math.sin(t*math.pi)*42)
   if t>=1 and not quiet then item.Position+=Vector2.new(0,math.sin(item.Age*2+item.Phase)*3)end
   scale=.55+.45*eased;item.Button.Rotation=quiet and 0 or item.Rotation*eased
  end
  item.Button.Position=UDim2.fromOffset(item.Position.X,item.Position.Y);item.Button.Size=UDim2.fromOffset(item.Size*scale,item.Size*scale)
 end
 for i=#self.Receipts,1,-1 do
  local receipt=self.Receipts[i];receipt.Age+=dt
  if receipt.Age>=2.5 then receipt.Label:Destroy();table.remove(self.Receipts,i)
  else
   local halfWidth=receipt.Label.Size.X.Offset*.5+8
   local p=Vector2.new(math.clamp(receipt.Origin.X,halfWidth,math.max(halfWidth,size.X-halfWidth)),math.clamp(receipt.Origin.Y,48,math.max(48,size.Y-48)))
   receipt.Label.Position=UDim2.fromOffset(p.X,p.Y+(quiet and 0 or receipt.Direction*math.min(receipt.Age,.4)*35))
   receipt.Label.TextTransparency=math.clamp((receipt.Age-1.7)/.8,0,1);receipt.Label.TextStrokeTransparency=.30+.70*receipt.Label.TextTransparency
  end
 end
 self:_flush()
 if #self.Icons==0 and #self.Receipts==0 and #self.Queue==0 and self.Connection then self.Connection:Disconnect();self.Connection=nil end
end
function Effects:Burst(receipt,indices,screenOrigin)
 local amount=Rules.Remaining(receipt)
 if self.Destroyed or type(amount)~='number'or amount~=amount or amount<0 or amount==math.huge then return false end
 local size=self.Layer.AbsoluteSize;if size.X<1 or size.Y<1 then return false end
 local origin=typeof(screenOrigin)=='Vector2'and screenOrigin-self.Layer.AbsolutePosition or size*.5
 origin=clampPoint(origin,size,40)
 local direction=origin.Y<math.min(210,size.Y*.45)and 1 or -1
 local quiet=reduced();local shares={}
 for _,index in ipairs(indices)do local share=self.Shares[receipt.Id..':'..index];if share and not share.Collected then shares[#shares+1]=share end end
 if #shares==0 then return true end
 local currency=receipt.Currency or'Cash';local available={};local currencyCount=0
 for _,item in ipairs(self.Icons)do if item.Currency==currency then
  currencyCount+=1
  if not item.Pending and not item.FlyAt then available[#available+1]=item end
 end end
 local count=math.min(#shares,MAX_PER_CURRENCY-currencyCount,MAX_ICONS-#self.Icons)
 if count==0 and #available==0 then return false end
 while #self.Receipts>=3 do local old=table.remove(self.Receipts,1);old.Label:Destroy()end
 -- Random server-chosen icon count, independent of amount; one total per sale.
 local label=Instance.new('TextLabel');label.Name='SaleTotal';label.AnchorPoint=Vector2.new(.5,.5);label.Size=UDim2.fromOffset(math.min(340,size.X-20),36);label.BackgroundTransparency=1
 label.Text='+'..Cash.Exact(math.ceil(amount))..(receipt.Currency=='Gems'and' Gems'or'');Theme.Text(label,26,true,Theme.Colors.Gold);label.TextXAlignment=Enum.TextXAlignment.Center;label.TextStrokeColor3=Theme.Colors.Ink;label.TextStrokeTransparency=.3;label.ZIndex=3;label.Parent=self.Layer
 table.insert(self.Receipts,{Label=label,Origin=origin+Vector2.new(0,direction*155),Direction=direction,Age=0})
 for i=1,count do
  local angle=(i-.5)/count*math.pi+self.Random:NextNumber(-.12,.12)
  local radius=self.Random:NextNumber(quiet and 45 or 65,quiet and 80 or 145)
  local button=Instance.new('TextButton');button.Name='CollectMoney';button.Text='';button.BackgroundTransparency=1;button.AnchorPoint=Vector2.new(.5,.5);button.AutoButtonColor=false;button.Active=true;button.Selectable=true;button.ZIndex=2;button.Parent=self.Layer;(receipt.Currency=='Gems'and require(RS.GemIcon)or Icon).new(button)
  local item={Button=button,Origin=origin,Rest=origin+Vector2.new(math.cos(angle)*radius,direction*(math.sin(angle)*radius*.65+18)),Position=origin,Age=0,Phase=i,Size=self.Random:NextInteger(38,50),Rotation=self.Random:NextNumber(-16,16),ReceiptId=receipt.Id,Index=shares[i].Index,Currency=currency,Shares={}}
  button.Position=UDim2.fromOffset(origin.X,origin.Y);button.Size=UDim2.fromOffset(item.Size*.55,item.Size*.55)
  table.insert(self.Icons,item)
  available[#available+1]=item
  button.MouseEnter:Connect(function()item.Hovered=true;self:_collect(item)end)
  button.MouseLeave:Connect(function()item.Hovered=false end)
  button.Activated:Connect(function()self:_collect(item)end)
 end
 -- Fold pending receipts into the existing icons instead of emitting refill waves.
 -- Claims still redeem exact server-owned shares, only following user interaction.
 local offset=#available-count
 for i,share in ipairs(shares)do
  local item=available[(offset+i-1)%#available+1]
  table.insert(item.Shares,share)
 end
 return true
end
function Effects:Destroy()
 if self.Destroyed then return end
 if self.Connection then self.Connection:Disconnect();self.Connection=nil end
 self.Layer:Destroy();table.clear(self.Icons);table.clear(self.Receipts);table.clear(self.Queue);table.clear(self.Seen);table.clear(self.Shares);self.Destroyed=true
end
return Effects
