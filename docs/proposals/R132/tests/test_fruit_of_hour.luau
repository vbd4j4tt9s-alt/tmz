--!nocheck
-- R132 (owner): Fruit of the Hour on the Roblox mock with the real modules. The pick (FruitOfHour) over a whole year of
-- hours, the sale bonus, the server announcer (FruitOfHourService), the pedestal display (FruitOfHourDisplay) and the
-- sell menu line. Selling itself (PlayerDataService) is checked in docs/proposals/giving_R122/tests (R132 block).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
require('./mockfix')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Hour=W.module('FruitOfHour');local Rules=W.module('SeedPackRules');local Catalog=W.module('PlantCatalog')

-- 1. Candidates: every obtainable fruit, nothing retired ------------------------------------------------------------
local list=Hour.Candidates()
check(#list>=10,'many fruits can be the Fruit of the Hour ('..#list..')')
local okList=true;for i,id in ipairs(list)do if not Catalog[id]or Rules.IsRetired(id)or(i>1 and list[i-1]>=id)then okList=false end end
check(okList,'candidates are plantable, not retired, sorted and unique')

-- 2. A year of hours ------------------------------------------------------------------------------------------------
local hours=24*365;local start=1759430000
local seen,steps,repeats,badM,badWindow={},{},0,0,0
local prev
for h=0,hours-1 do
 local t=start+h*3600
 local a=Hour.At(t);local b=Hour.At(a.StartsAt);local c=Hour.At(a.EndsAt-.001)
 if not(a.SeedId==b.SeedId and a.SeedId==c.SeedId and a.Multiplier==b.Multiplier and a.Multiplier==c.Multiplier)then badWindow+=1 end
 if not(a.StartsAt<=t and t<a.EndsAt and a.EndsAt-a.StartsAt==3600)then badWindow+=1 end
 local m=a.Multiplier
 if not(m>=1.5-1e-9 and m<=3.0+1e-9 and math.abs(m*10-math.floor(m*10+.5))<1e-6)then badM+=1 end
 steps[math.floor(m*10+.5)]=true
 seen[a.SeedId]=(seen[a.SeedId]or 0)+1
 if prev and prev==a.SeedId then repeats+=1 end
 prev=a.SeedId
end
check(badWindow==0,'the same fruit and bonus for the whole hour, every hour ('..badWindow..' bad)')
check(badM==0,'bonus is x1.5 to x3.0 in 0.1 steps ('..badM..' bad)')
local stepCount=0;for _ in pairs(steps)do stepCount+=1 end
check(stepCount==16,'every bonus from x1.5 to x3.0 comes up ('..stepCount..'/16)')
check(repeats==0,'never the same fruit two hours in a row ('..repeats..' repeats)')
local covered,most=0,0;for _,id in ipairs(list)do if seen[id]then covered+=1;most=math.max(most,seen[id])end end
check(covered==#list,'every fruit gets its turn within a year ('..covered..'/'..#list..')')
check(most<hours/#list*2,'no fruit hogs the hour (most '..most..', fair '..math.floor(hours/#list)..')')
local name=Hour.At(start).Name
check(type(name)=='string'and name~='Fruit'and name~='','the hour has a display name ('..tostring(name)..')')

-- 3. Sale value ---------------------------------------------------------------------------------------------------
local now=Hour.At(start);local other;for _,id in ipairs(list)do if id~=now.SeedId then other=id;break end end
check(Hour.Multiplier(now.SeedId,start)==now.Multiplier and Hour.Multiplier(other,start)==1,'only the Fruit of the Hour gets the bonus')
check(Hour.SaleValue(now.SeedId,1000,start)==math.floor(1000*now.Multiplier+.5),'bonus sale value 1000 -> '..Hour.SaleValue(now.SeedId,1000,start))
check(Hour.SaleValue(other,1234,start)==1234,'other fruit sells for its normal value')
check(Hour.SaleValue(now.SeedId,7,start)>=11,'a cheap fruit still gets at least x1.5 (7 -> '..Hour.SaleValue(now.SeedId,7,start)..')')
local big=900000000000;check(Hour.SaleValue(now.SeedId,big,start)==math.floor(big*now.Multiplier+.5),'big values stay exact')
check(Hour.Multiplier(nil,start)==1 and Hour.SaleValue('NoSuchSeed',50,start)==50,'unknown fruit: no bonus')

-- 4. Server announcer ---------------------------------------------------------------------------------------------
local Players=W.service('Players');Players.PlayerAdded=R.signal()
local people={}
for i=1,3 do local p=R.new('Player');p.Name='P'..i;p.UserId=i;p.Parent=Players;people[i]=p end
function Players.GetPlayers()return people end
local SSS=W.service('ServerScriptService');local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
local mod=R.new('ModuleScript');mod.Name='FruitOfHourService';mod._source='FruitOfHourService';mod.Parent=folder
local Service=W.require(mod)
local shown={};local notes={Show=function(_,p,text,accent,duration)shown[#shown+1]={P=p,Text=text,Duration=duration}end}
local svc=Service.new(notes)
local first=svc:Step(start)
check(#shown==0,'no announcement for the hour the server starts in')
check(W.RS:GetAttribute('FruitOfHourSeedId')==first.SeedId and W.RS:GetAttribute('FruitOfHourMultiplier')==first.Multiplier and W.RS:GetAttribute('FruitOfHourEndsAt')==first.EndsAt,'published on ReplicatedStorage')
svc:Step(start+600);check(#shown==0,'no repeat announcement within the hour')
local nextHour=svc:Step(first.EndsAt+1)
check(#shown==3,'new hour announced to every player ('..#shown..')')
check(shown[1]and shown[1].Text:find(nextHour.Name,1,true)and shown[1].Text:find(('×%.1f'):format(nextHour.Multiplier),1,true),'announcement names the fruit and bonus: '..tostring(shown[1]and shown[1].Text))
check(W.RS:GetAttribute('FruitOfHourSeedId')==nextHour.SeedId,'attributes follow the new hour')
-- Owner test override (/test fruithour): replicated attribute, announced, then back to the clock.
local testAt=first.EndsAt+120;local pickId=list[1]==nextHour.SeedId and list[2]or list[1]
Hour.SetTest(pickId,2.2,testAt,600)
local forced=Hour.At(testAt+5)
check(forced.SeedId==pickId and forced.Multiplier==2.2 and forced.Test and forced.EndsAt==testAt+600,'test override replaces the pick for 10 minutes')
check(Hour.SaleValue(pickId,100,testAt+5)==220 and Hour.Multiplier(nextHour.SeedId,testAt+5)==1,'the test fruit gets the test bonus; the hour fruit does not')
local before=#shown;svc:Step(testAt+5)
check(#shown==before+3 and shown[#shown].Text:find('10 minutes (test)',1,true),'test fruit announced: '..tostring(shown[#shown]and shown[#shown].Text))
check(Hour.At(testAt+600).SeedId==nextHour.SeedId and not Hour.At(testAt+600).Test,'override ends on time')
svc:Step(testAt+600);check(#shown==before+6 and W.RS:GetAttribute('FruitOfHourSeedId')==nextHour.SeedId,'back to the hour fruit, announced again')
W.RS:SetAttribute('FruitOfHourTest','NoSuchSeed:3:'..math.floor(testAt+500));check(Hour.At(testAt+5).SeedId==nextHour.SeedId,'a bad override is ignored')
W.RS:SetAttribute('FruitOfHourTest',pickId..':9:'..math.floor(testAt+500));check(Hour.At(testAt+5).Multiplier==3,'override bonus is capped at x3')
Hour.SetTest(nil);check(W.RS:GetAttribute('FruitOfHourTest')==nil,'override cleared')

-- 5. Pedestal display (client) ------------------------------------------------------------------------------------
W.module('PlantVisuals') -- warm the client modules before timing anything
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=map
local stands=R.new('Model');stands.Name='MerchantStands';stands.Parent=hub
local holder=R.new('Model');holder.Name='FruitOfTheHour';holder.Parent=stands
local anchor=R.new('Part');anchor.Name='FruitAnchor';anchor.Size=V3(1,1,1);anchor.CFrame=CF(-20,11.2,-299);anchor.Transparency=1;anchor.Parent=holder
W.workspace.CurrentCamera.CFrame=CF(-20,12,-280)
R.advance(start-R.clock)
local script=R.new('LocalScript');script.Name='FruitOfHourDisplay'
W.load('FruitOfHourDisplay',script)
W.frames(40)
local display=W.workspace:FindFirstChild('FruitOfHourDisplay')
local label=display and display:FindFirstChild('FruitOfHourLabel')
local current=Hour.At(W.workspace:GetServerTimeNow())
check(label and label.Adornee==anchor,'label hangs over the pedestal anchor')
check(label and label.AlwaysOnTop==false and label.LightInfluence==0 and label.Size.X.Scale>0,'label: sized in studs, not drawn through walls, unlit')
local rows=label and{T=label.Title.Text,N=label.FruitName.Text,B=label.Bonus.Text,L=label.TimeLeft.Text}or{}
check(rows.N==current.Name,'shows the fruit name ('..tostring(rows.N)..')')
check(rows.B==('SELLS ×%.1f'):format(current.Multiplier),'shows the bonus ('..tostring(rows.B)..')')
check(rows.L and rows.L:match('^%d+:%d%d left$'),'shows time left ('..tostring(rows.L)..')')
local fruit=display and display:FindFirstChild('FruitOfTheHour')
check(fruit~=nil,'the real fruit model floats over the pedestal')
if fruit then
 local _,box=fruit:GetBoundingBox();local big=math.max(box.X,box.Y,box.Z)
 check(math.abs(big-2.6)<.15,('fruit sized to 2.6 studs (%.2f)'):format(big))
 local c=fruit:GetBoundingBox()
 check((c.Position-anchor.Position).Magnitude<.6,('fruit centred on the anchor (%.2f away)'):format((c.Position-anchor.Position).Magnitude))
 local anyCollide=false;for _,d in ipairs(fruit:GetDescendants())do if d:IsA('BasePart')and(d.CanCollide or d.CanQuery or d.CanTouch or not d.Anchored)then anyCollide=true end end
 check(not anyCollide,'display fruit is anchored and cannot be touched or hit')
 local look1=fruit:GetPivot().LookVector;W.frames(30);local look2=fruit:GetPivot().LookVector
 check((look1-look2).Magnitude>.05,'fruit turns slowly while you are near')
 W.workspace.CurrentCamera.CFrame=CF(600,12,-280);local look3=fruit:GetPivot().LookVector;W.frames(30)
 check((fruit:GetPivot().LookVector-look3).Magnitude<1e-6,'no animation work when the camera is far away')
 W.workspace.CurrentCamera.CFrame=CF(-20,12,-280)
end
-- Next hour: the fruit is rebuilt for the new pick.
R.advance(current.EndsAt-W.workspace:GetServerTimeNow()+1);W.frames(40)
local after=Hour.At(W.workspace:GetServerTimeNow())
local fruits=0;for _,c in ipairs(display:GetChildren())do if c.Name=='FruitOfTheHour'then fruits+=1 end end
check(after.SeedId~=current.SeedId and label.FruitName.Text==after.Name and fruits==1,'new hour: new fruit, one model ('..tostring(label.FruitName.Text)..', '..fruits..' models)')

-- 6. Sell menu line ------------------------------------------------------------------------------------------------
local src=W.B.HarvestSellMenu
check(src:find("🌟 Fruit of the Hour ×",1,true)and src:find('item.HourMultiplier',1,true),'sell menu shows the Fruit of the Hour bonus on that fruit')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
