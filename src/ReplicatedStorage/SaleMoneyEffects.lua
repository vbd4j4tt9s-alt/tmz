-- R152: sale / reward money collects itself. Each icon pops out, rests a beat (.25-.5 s, staggered), flies to its counter and claims one server-owned share on arrival.
-- The server is unchanged (same remote, same share ids, claimed once, no timeout awards: an unclaimed share just waits in PendingSales). Every share is claimed whatever
-- the screen does (no icon room, FastMode / reduced motion, hidden UI, a stalled render loop, a failed remote): see _due / _drain, and `By`, the deadline nothing outlives.
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService');local Players=game:GetService('Players');local GuiService=game:GetService('GuiService')
local Icon=require(RS:WaitForChild('MoneyIcon'));local Cash=require(RS:WaitForChild('CashNumbers'));local Theme=require(RS:WaitForChild('GardenTheme'))
local Rules=require(RS:WaitForChild('SaleReceiptRules'))
local Effects={};Effects.__index=Effects
local MAX_ICONS=26
local MAX_PER_CURRENCY=13
local POP=.40                -- the pop out of the origin (unchanged since R53)
local BEAT_MIN,BEAT_MAX=.25,.50 -- the rest before an icon flies; ranks spread across it so a burst streams in
local FLY=.55                -- one flight to the counter
local GRACE=1.5              -- the watchdog claims a share this long after its icon should have landed, drawn or not
local RETRY_FIRST,RETRY_MAX=.5,8 -- a refused / failed claim is retried (doubling) until it lands
local MAX_BUSY=8             -- claims in flight at once
local CLAIM_WAIT=15          -- a claim with no answer after this long is given up on and sent again
local TICK=.25               -- the watchdog's beat (task.delay: runs with the window minimised, unlike RenderStepped)
local DEADLINE=POP+BEAT_MAX+FLY+GRACE -- every share is claimed within this of being seen, whatever is (not) drawn
Effects.MaxIcons=MAX_ICONS;Effects.MaxPerCurrency=MAX_PER_CURRENCY
Effects.Timing={Pop=POP,BeatMin=BEAT_MIN,BeatMax=BEAT_MAX,Fly=FLY,Grace=GRACE,Deadline=DEADLINE,RetryFirst=RETRY_FIRST,RetryMax=RETRY_MAX,ClaimWait=CLAIM_WAIT}
local function reduced()
 local p=Players.LocalPlayer
 return GuiService.ReducedMotionEnabled or(p and(p:GetAttribute('FastMode')or p:GetAttribute('StudioPlantEffects')=='off'))
end
local function clampPoint(p,size,pad)
 return Vector2.new(math.clamp(p.X,pad,math.max(pad,size.X-pad)),math.clamp(p.Y,pad,math.max(pad,size.Y-pad)))
end
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
-- opts.Anchor(currency) may return another balance display ({TargetPosition=,Pulse=}, like a GardenWallet row) while a window hides the HUD counters.
function Effects.new(parent,wallet,claim,opts)
 local layer=Instance.new('Frame');layer.Name='SaleMoneyEffects';layer.BackgroundTransparency=1;layer.Size=UDim2.fromScale(1,1);layer.Active=false;layer.ZIndex=60;layer.Parent=parent
 local self=setmetatable({Layer=layer,Wallet=wallet,Claim=claim,Anchor=opts and opts.Anchor,Icons={},Receipts={},Open={},Seen={},Shares={},Busy=0,Random=Random.new()},Effects)
 layer.Destroying:Connect(function()self:_halt()end)
 return self
end
function Effects:_halt()
 if self.Destroyed then return end
 self.Destroyed=true
 if self.Connection then self.Connection:Disconnect();self.Connection=nil end
 -- last chance: anything still owed is claimed now (idempotent on the server); a share that cannot go out stays in PendingSales for the next join
 for _,share in ipairs(self.Open)do if not share.Collected and not share.Sending then share.Sending=true;task.spawn(pcall,self.Claim,share.ReceiptId,share.Index)end end
end
-- The counter an icon flies to: the HUD row, or the window's own balance line while the HUD is hidden.
function Effects:_row(currency)
 local menu=self.Anchor and select(2,pcall(self.Anchor,currency))
 if menu and menu.TargetPosition then return menu end
 return currency=='Gems'and self.Wallet.Gems or self.Wallet
end
function Effects:_spot(row)
 local size=self.Layer.AbsoluteSize
 local okay,p=pcall(row.TargetPosition,row)
 local to=okay and typeof(p)=='Vector2'and p.X==p.X and p.Y==p.Y and Vector2.new(p.X-self.Layer.AbsolutePosition.X,p.Y-self.Layer.AbsolutePosition.Y)or Vector2.new(60,52)
 return clampPoint(to,size,12) -- inside the safe area, wherever the layout put the counter
end
-- A coin has reached its counter: the counter bumps and clicks (one cue per coin; InteractionAudio spaces a burst into a ripple, R150).
function Effects:_land(currency)
 local row=self:_row(currency)
 pcall(function()row:Pulse()end)
 pcall(function()require(script.Parent.InteractionAudio).Play('Bubble06')end)
end
function Effects:_collected(share)
 if share.Collected then return end
 share.Collected=true;self.Shares[share.ReceiptId..':'..share.Index]=nil
 if share.Land and not self.Destroyed then self:_land(share.Currency)end
end
function Effects:_live()
 local keep={};for _,share in ipairs(self.Open)do if not share.Collected then keep[#keep+1]=share end end
 self.Open=keep;return #keep
end
function Effects:_send(share)
 local token={};share.Sending=token;share.SentAt=os.clock();self.Busy+=1
 task.spawn(function()
  local okay,result=pcall(self.Claim,share.ReceiptId,share.Index)
  local mine=share.Sending==token -- (false once a claim that took too long was given up on)
  if mine then share.Sending=false;self.Busy-=1 end
  if okay and type(result)=='table'and result.Success then self:_collected(share)
  elseif mine then share.Fails+=1;share.RetryAt=os.clock()+math.min(RETRY_MAX,RETRY_FIRST*2^(share.Fails-1))end
  self:_drain()
 end)
end
-- Claims every share that is due (its icon landed, it had no icon, or its deadline passed) and is not waiting out a retry.
function Effects:_drain()
 if self.Destroyed then return end
 if self.Draining then self.Again=true;return end
 self.Draining=true
 local okay,why=pcall(function()
  repeat
   self.Again=false;local now=os.clock()
   for _,share in ipairs(self.Open)do -- a claim that never answers must not hold a slot for ever: give up on it, the share goes out again
    if share.Sending and not share.Collected and now-share.SentAt>CLAIM_WAIT then share.Sending=false;self.Busy-=1;share.Fails+=1;share.RetryAt=now end
   end
   for _,share in ipairs(self.Open)do
    if self.Busy>=MAX_BUSY then break end
    if not share.Collected and not share.Sending and now>=share.RetryAt and(share.Due or now>=share.By)then self:_send(share)end
   end
  until not self.Again
 end)
 self.Draining=false
 if not okay then warn('SaleMoneyEffects: '..tostring(why))end
 if self:_live()>0 and not self.Timer then self.Timer=true;task.delay(TICK,function()self.Timer=false;self:_drain()end)end
end
function Effects:_due(share)
 if share.Collected then return end
 share.Due=true;self:_drain()
end
function Effects:_arrive(item)
 self:_land(item.Currency)
 if item.Share then self:_due(item.Share)end
end
function Effects:_remove(index)
 local item=table.remove(self.Icons,index)
 if item then item.Frame:Destroy()end
end
function Effects:Sync(receipts,origin)
 if self.Destroyed or type(receipts)~='table'then return end
 for _,r in ipairs(receipts)do
  if Rules.Valid({r})then
   local fresh={}
   for i=1,r.Count do
    local key=r.Id..':'..i
    if Rules.Claimed(r,i)then
     -- Claim masks only move forward, including when an older poll arrives late.
     self.Seen[key]=true;local share=self.Shares[key];if share then share.Land=false;self:_collected(share)end
    elseif not self.Seen[key]then
     self.Seen[key]=true;local share={ReceiptId=r.Id,Index=i,Currency=r.Currency or'Cash',Collected=false,Fails=0,RetryAt=0,By=os.clock()+DEADLINE};self.Shares[key]=share;table.insert(self.Open,share);table.insert(fresh,i)
    end
   end
   if #fresh>0 then
    local okay,why=pcall(self.Burst,self,r,fresh,origin)
    if not okay then -- whatever broke the drawing, the money is still claimed
     warn('SaleMoneyEffects: '..tostring(why))
     for _,i in ipairs(fresh)do local share=self.Shares[r.Id..':'..i];if share then share.Land=true;share.Due=true end end
    end
   end
  end
 end
 self:_drain()
 if(#self.Icons>0 or #self.Receipts>0)and not self.Connection and not self.Destroyed then self.Connection=Run.RenderStepped:Connect(function(dt)self:_step(dt)end)end
end
function Effects:_step(dt)
 if self.Destroyed then return end
 dt=math.min(dt,.1);local size=self.Layer.AbsoluteSize
 local quiet=reduced()
 for i=#self.Icons,1,-1 do
  local item=self.Icons[i];item.Age+=dt
  if quiet then self:_arrive(item);self:_remove(i);continue end -- reduced motion / FastMode switched on mid-flight: land and claim now
  local scale
  if item.Age>=item.Launch then
   if not item.Start then item.Start=item.Position end
   item.Fly+=dt;local t=math.clamp(item.Fly/FLY,0,1);local eased=smooth(t)
   local to=self:_spot(self:_row(item.Currency))
   local dx,dy=to.X-item.Start.X,to.Y-item.Start.Y;local len=math.sqrt(dx*dx+dy*dy)
   local bend=math.sin(t*math.pi)*item.Arc*math.min(1,len/220) -- a slight sideways arc, zero at both ends
   item.Position=clampPoint(Vector2.new(item.Start.X+dx*eased+(len>1 and -dy/len or 0)*bend,item.Start.Y+dy*eased+(len>1 and dx/len or 0)*bend),size,8) -- (the arc never carries a coin off the safe area)
   scale=1-.62*smooth((t-.3)/.7);item.Frame.Rotation=item.Rotation*(1-eased)
   if t>=1 then self:_arrive(item);self:_remove(i);continue end
  else
   local t=math.clamp(item.Age/POP,0,1);local eased=1-(1-t)^3
   local rest=clampPoint(item.Rest,size,30)
   item.Position=Vector2.new(item.Origin.X+(rest.X-item.Origin.X)*eased,item.Origin.Y+(rest.Y-item.Origin.Y)*eased-math.sin(t*math.pi)*42)
   if t>=1 then item.Position+=Vector2.new(0,math.sin(item.Age*2+item.Phase)*3)end
   scale=.55+.45*eased;item.Frame.Rotation=item.Rotation*eased
  end
  item.Frame.Position=UDim2.fromOffset(item.Position.X,item.Position.Y);item.Frame.Size=UDim2.fromOffset(item.Size*scale,item.Size*scale)
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
 if #self.Icons==0 and #self.Receipts==0 and self.Connection then self.Connection:Disconnect();self.Connection=nil end
end
-- One burst of one receipt's fresh shares: an icon per share up to the caps; the rest, and everything when nothing can be drawn, is claimed straight away.
function Effects:Burst(receipt,indices,screenOrigin)
 if self.Destroyed then return false end
 local shares={}
 for _,index in ipairs(indices)do local share=self.Shares[receipt.Id..':'..index];if share and not share.Collected then shares[#shares+1]=share end end
 if #shares==0 then return true end
 local currency=receipt.Currency or'Cash'
 local amount=Rules.Remaining(receipt);local size=self.Layer.AbsoluteSize
 if type(amount)~='number'or amount~=amount or amount<0 or amount==math.huge or size.X<1 or size.Y<1 then -- nothing can be drawn (hidden / zero-size UI): claim at once
  for _,share in ipairs(shares)do share.Land=true;self:_due(share)end
  return true
 end
 local origin=typeof(screenOrigin)=='Vector2'and screenOrigin-self.Layer.AbsolutePosition or Vector2.new(size.X*.5,size.Y*.5)
 origin=clampPoint(origin,size,40)
 local direction=origin.Y<math.min(210,size.Y*.45)and 1 or -1
 local quiet=reduced()
 while #self.Receipts>=3 do local old=table.remove(self.Receipts,1);old.Label:Destroy()end
 -- Random server-chosen icon count, independent of amount; one total per sale.
 local label=Instance.new('TextLabel');label.Name='SaleTotal';label.AnchorPoint=Vector2.new(.5,.5);label.Size=UDim2.fromOffset(math.min(340,size.X-20),36);label.BackgroundTransparency=1
 label.Text='+'..Cash.Exact(math.ceil(amount))..(receipt.Currency=='Gems'and' Gems'or'');Theme.Text(label,26,true,Theme.Colors.Gold);label.TextXAlignment=Enum.TextXAlignment.Center;label.TextStrokeColor3=Theme.Colors.Ink;label.TextStrokeTransparency=.3;label.ZIndex=3;label.Parent=self.Layer
 local lift=direction*(155+36*#self.Receipts) -- (a total still up from another sale in the last 2.5 s is not drawn over)
 label.Position=UDim2.fromOffset(origin.X,origin.Y+lift)
 table.insert(self.Receipts,{Label=label,Origin=origin+Vector2.new(0,lift),Direction=direction,Age=0})
 local currencyCount=0;for _,item in ipairs(self.Icons)do if item.Currency==currency then currencyCount+=1 end end
 local count=quiet and 0 or math.max(0,math.min(#shares,MAX_PER_CURRENCY-currencyCount,MAX_ICONS-#self.Icons))
 -- reduced motion / FastMode: no icons, claim at once (the label and the counter's bump are the whole effect); overflow past the caps: the same
 for i=count+1,#shares do shares[i].Land=true;self:_due(shares[i])end
 local ranks={};for i=1,count do ranks[i]=i end
 for i=count,2,-1 do local j=self.Random:NextInteger(1,i);ranks[i],ranks[j]=ranks[j],ranks[i]end
 for i=1,count do
  local angle=(i-.5)/count*math.pi+self.Random:NextNumber(-.12,.12)
  local radius=self.Random:NextNumber(65,145)
  local frame=Instance.new('Frame');frame.Name='SaleCoin';frame.BackgroundTransparency=1;frame.AnchorPoint=Vector2.new(.5,.5);frame.Active=false;frame.ZIndex=2;frame.Parent=self.Layer;(currency=='Gems'and require(RS.GemIcon)or Icon).new(frame)
  local item={Frame=frame,Origin=origin,Rest=origin+Vector2.new(math.cos(angle)*radius,direction*(math.sin(angle)*radius*.65+18)),Position=origin,Age=0,Fly=0,Phase=i,Size=self.Random:NextInteger(38,50),Rotation=self.Random:NextNumber(-16,16),
   Arc=(i%2==0 and 1 or-1)*self.Random:NextNumber(26,44),Launch=POP+BEAT_MIN+(BEAT_MAX-BEAT_MIN)*(ranks[i]-1)/math.max(1,count-1),Currency=currency,Share=shares[i]}
  frame.Position=UDim2.fromOffset(origin.X,origin.Y);frame.Size=UDim2.fromOffset(item.Size*.55,item.Size*.55)
  table.insert(self.Icons,item)
 end
 return true
end
function Effects:Destroy()
 if self.Destroyed then return end
 self:_halt()
 self.Layer:Destroy();table.clear(self.Icons);table.clear(self.Receipts);table.clear(self.Open);table.clear(self.Seen);table.clear(self.Shares)
end
return Effects
