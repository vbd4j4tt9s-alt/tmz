--!nocheck
-- R152: the server half of "the money collects itself". Auto-claiming must not change what the server accepts, so this runs the REAL
-- PlayerDataService:CollectSaleCash (cut out of the source file by run_sale_money.sh, byte for byte) on fake player data and checks, for cash and gems:
--  * a share is credited once, exactly SaleReceiptRules.Share(receipt,index); all shares together are exactly the receipt's Amount, never more
--  * the same share again (a retry after a lost answer, or a hostile repeat) credits nothing and answers Success (so the client stops retrying)
--  * an index outside 1..Count, a non-integer / string / NaN index, a non-string / empty / over-long id: Success=false, nothing credited
--  * an id the player does not hold (another player's receipt, a made-up one) credits nothing
--  * a share that would push the balance past its limit is refused with no change at all (the client retries until there is room)
--  * a player whose data is not loaded gets nothing; the last share removes the receipt; the claim has no clock in it (no timeout awards, nothing expires)
--  * claiming through the client's own SaleMoneyEffects (retries, overflow, a hostile double Sync) credits exactly the receipts' total, once
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=W.module('SaleReceiptRules');local Catalog=W.module('MechCatalog')
local text=require('./claim_fn')
-- fake data ---------------------------------------------------------------------------------------------------------------------------------------------------
local Data={}
Data.__index=Data
local players={}
local function newPlayer(name)local p=R.new('Player');p.Name=name;players[#players+1]=p
 Data[p]={Loaded=true,Cash=0,Gems=0,Pending={},Dirty=0,Saves=0,Tutorial=0,Published=0}
 return p end
local function state(p)return Data[p]end
function Data:IsLoaded(p)return Data[p]~=nil and Data[p].Loaded end
function Data:GetCash(p)return Data[p].Cash end
function Data:GetPremium(p)local s=Data[p];return setmetatable({},{__index=function(_,k)if k=='Gems'then return s.Gems end end,__newindex=function(_,k,v)if k=='Gems'then s.Gems=v end end})end
function Data:GetOrCreateCashValue(p)local s=Data[p];return setmetatable({},{__index=function(_,k)if k=='Value'then return s.Cash end end,__newindex=function(_,k,v)if k=='Value'then s.Cash=v end end})end
function Data:PublishPremium(p)Data[p].Published+=1 end
function Data:TutorialEvent(p)Data[p].Tutorial+=1 end
function Data:MarkDirty(p)Data[p].Dirty+=1 end
function Data:QueueGardenSave(p)Data[p].Saves+=1 end
Data.Gardens=setmetatable({},{__index=function(_,p)local s=Data[p];if not s then return nil end;return setmetatable({},{__index=function(_,k)if k=='PendingSales'then return s.Pending end end,__newindex=function(_,k,v)if k=='PendingSales'then s.Pending=v end end})end})
local function gardenInteger(value,minimum,maximum)return type(value)=='number'and value==value and value%1==0 and value>=minimum and value<=maximum end
local env=setmetatable({PlayerDataService=Data,gardenInteger=gardenInteger,game=W.env.game,require=W.require,type=type,ipairs=ipairs,math=math,bit32=bit32},{__index=W.env})
local chunk=assert(loadstring(text,'=CollectSaleCash'));setfenv(chunk,env);chunk()
local function claim(p,id,index)return Data:CollectSaleCash(p,id,index)end
local function receipt(id,count,amount,currency)return {Id=id,Currency=currency,Amount=amount,Count=count,Claimed=0}end
local function give(p,r)table.insert(Data[p].Pending,r);return r end

local a,b=newPlayer('A'),newPlayer('B')
-- 1. exact amounts, once ----------------------------------------------------------------------------------------------------------------------------------
for _,currency in ipairs({'Cash','Gems'})do
 local amount=currency=='Gems'and 47 or 123457;local count=currency=='Gems'and 5 or 11
 local r=give(a,receipt('r-'..currency,count,amount,currency))
 local before=currency=='Gems'and state(a).Gems or state(a).Cash
 local total=0;local expect={}
 for i=1,count do expect[i]=Rules.Share(r,i)end
 for i=1,count do
  local res=claim(a,'r-'..currency,i)
  check(res.Success==true and res.Amount==expect[i],currency..': share '..i..' credits exactly '..expect[i]..' ('..tostring(res.Amount)..')')
  total+=res.Amount or 0
  local again=claim(a,'r-'..currency,i)
  check(again.Success==true and again.Amount==0,currency..': claiming share '..i..' again credits nothing and still answers Success')
 end
 local after=currency=='Gems'and state(a).Gems or state(a).Cash
 check(total==amount and after-before==amount,currency..': the shares add up to exactly the receipt ('..(after-before)..' / '..amount..')')
 check(#state(a).Pending==0,currency..': the last share removes the receipt')
 local late=claim(a,'r-'..currency,1)
 check(late.Success==true and late.Amount==0 and(currency=='Gems'and state(a).Gems or state(a).Cash)==after,currency..': a retry after the receipt is gone is a harmless Success with nothing credited')
end
check(state(a).Tutorial>=1,'the first cash still fires the tutorial event (it did on a hover)')
-- 2. invalid ids / indices ---------------------------------------------------------------------------------------------------------------------------------
do
 local r=give(a,receipt('v',8,800,'Cash'));local cash=state(a).Cash
 for _,bad in ipairs({0,-1,9,14,1.5,0/0,math.huge,'1',true})do
  local res=claim(a,'v',bad);check(res.Success==false,'index '..tostring(bad)..' is refused')
 end
 for _,bad in ipairs({'',string.rep('x',101),7,true,{}})do local res=claim(a,bad,1);check(res.Success==false,'id '..tostring(type(bad)=='string'and #bad or bad)..' is refused')end
 local res=claim(a,nil,1);check(res.Success==false,'a nil id is refused')
 res=claim(a,'v',nil);check(res.Success==false,'a nil index is refused')
 check(state(a).Cash==cash and r.Claimed==0,'none of them changed anything')
 -- index 9..13 on a receipt of 8: out of range
 for i=9,13 do local x=claim(a,'v',i);check(x.Success==false,'index '..i..' on a receipt of 8 is refused')end
 check(state(a).Cash==cash and r.Claimed==0,'and nothing was credited')
end
-- 3. somebody else's receipt / an invented one ---------------------------------------------------------------------------------------------------------------
do
 give(b,receipt('only-b',8,800,'Cash'));local before=state(a).Cash
 local res=claim(a,'only-b',1)
 check((res.Success==true and res.Amount==0)or res.Success==false,'player A cannot claim player B\'s receipt')
 check(state(a).Cash==before and state(b).Cash==0,'nothing moved for A or B')
 local res2=claim(a,'made-up-id',1);check(state(a).Cash==before,'an invented id credits nothing')
 local rb=claim(b,'only-b',1);check(rb.Success and rb.Amount==Rules.Share(state(b).Pending[1],1)and state(b).Cash==rb.Amount,'the owner can')
end
-- 4. balance limit: refused, no change ------------------------------------------------------------------------------------------------------------------------
do
 local r=give(a,receipt('lim',8,800,'Cash'));state(a).Cash=Rules.MaxCash-10
 local before=state(a).Cash;local res=claim(a,'lim',1)
 check(res.Success==false and state(a).Cash==before and r.Claimed==0,'a share that would pass the cash limit is refused with no change (the client retries)')
 state(a).Cash=0;res=claim(a,'lim',1);check(res.Success==true and res.Amount==Rules.Share(r,1),'once there is room it goes through')
 local g=give(a,receipt('glim',3,30,'Gems'));state(a).Gems=Catalog.MaxGems-5
 local gb=state(a).Gems;local gres=claim(a,'glim',1);check(gres.Success==false and state(a).Gems==gb,'gems: the same limit rule')
 state(a).Gems=0
 for i=1,3 do claim(a,'glim',i)end
 for i=2,8 do claim(a,'lim',i)end
 local left=0;for _,x in ipairs(state(a).Pending)do if x.Id=='lim'or x.Id=='glim'then left+=1 end end
 check(left==0,'every share credited once the limit allowed it: both receipts are gone')
end
-- 5. not loaded ------------------------------------------------------------------------------------------------------------------------------------------------
do
 local c=newPlayer('C');give(c,receipt('late',8,800,'Cash'));state(c).Loaded=false
 local res=claim(c,'late',1);check(res.Success==false and state(c).Cash==0,'data not loaded: nothing is credited')
 local stranger=R.new('Player');local res2=claim(stranger,'late',1);check(res2.Success==false,'a player without data gets nothing')
end
-- 6. no clock in the claim: nothing expires, nothing is credited by waiting -------------------------------------------------------------------------------
do
 local p=newPlayer('D');give(p,receipt('old',8,800,'Cash'))
 R.advance(60*60*24*30) -- a month
 check(state(p).Cash==0 and #state(p).Pending==1,'a month of waiting credits nothing and drops nothing (no timeout awards)')
 local res=claim(p,'old',1);check(res.Success and res.Amount>0,'the share is still claimable after a month')
 check(not text:find('os%.')and not text:find('tick%(')and not text:find('task%.')and not text:find('time%('),'the claim function has no clock, no timer and no wait in it')
end
-- 7. the client helper against this server -------------------------------------------------------------------------------------------------------------------
do
 local Effects=W.module('SaleMoneyEffects')
 local p=newPlayer('E')
 local gui=R.Instance.new('ScreenGui');local Players=W.service('Players');local lp=R.new('Player');lp.Name='Local';Players.LocalPlayer=lp;lp.Parent=Players
 local pg=R.new('PlayerGui');pg.Parent=lp;gui.Parent=pg
 local wallet={Pulse=function()end,TargetPosition=function()return R.Vector2.new(100,40)end};wallet.Gems=wallet
 local calls=0;local flaky=true
 local fx=Effects.new(gui,wallet,function(id,index)calls+=1;if flaky and calls%3==0 then error('lost')end;return Data:CollectSaleCash(p,id,index)end)
 fx.Layer.AbsoluteSize=R.Vector2.new(1280,720)
 local list={};local owed={Cash=0,Gems=0}
 for i=1,6 do local r=give(p,receipt('e'..i,i%2==0 and 8 or 13,1000*i+7,i%3==0 and'Gems'or'Cash'));if r.Currency=='Gems'then r.Count=math.min(r.Count,13);r.Amount=40+i end;owed[r.Currency]+=r.Amount end
 local snapshot=table.clone(state(p).Pending)
 for _=1,3 do fx:Sync(table.clone(state(p).Pending),R.Vector2.new(300,300))end -- a hostile / repeated poll
 for _=1,300 do W.frames(1,1/60)end
 flaky=false;for _=1,80 do R.advance(.5)end
 check(state(p).Cash==owed.Cash and state(p).Gems==owed.Gems,'through retries, overflow and repeated polls the client credits exactly what was owed (cash '..state(p).Cash..' / '..owed.Cash..', gems '..state(p).Gems..' / '..owed.Gems..')')
 check(#state(p).Pending==0,'and every receipt is gone from the server ('..#state(p).Pending..' left)')
 fx:Destroy()
end

print('R152 sale claim server checks '..checks..', fails '..fails)
if fails>0 then error('failures: '..fails)end
