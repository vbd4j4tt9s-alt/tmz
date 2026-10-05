--!nocheck
-- R149 review part 2, finding 10 (run_market.sh): MarketLayout.clearTops boxes the market's own parts once per build.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
require('./mockfix')(W)
R.Vector3.FromNormalId=R.Vector3.FromNormalId or function(n)
 local name=type(n)=='table'and n.Name or tostring(n):match('(%a+)$')
 return({Front=V3(0,0,-1),Back=V3(0,0,1),Left=V3(-1,0,0),Right=V3(1,0,0),Top=V3(0,1,0),Bottom=V3(0,-1,0)})[name]
end
W.env.Vector3=R.Vector3
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local SSS=W.service('ServerScriptService');local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
local function server(name)local m=R.new('ModuleScript');m.Name=name;m._source=name;m.Parent=folder;return W.require(m)end
local Pre,NoSink,New=server('MarketLayoutPre'),server('MarketLayoutNoSink'),server('MarketLayout')
-- Fruit and plant models carry hidden parts in the game (R135 test_market): add a big invisible one above each, like the real thing.
local function haunt(mod,fn)
 local real=mod[fn]
 mod[fn]=function(...)
  local m,a,b=real(...)
  if m then local ghost=R.new('Part');ghost.Name='Hidden plant';ghost.Size=V3(6,6,6);ghost.CFrame=m:GetPivot()*CF(0,7,0);ghost.Transparency=1;ghost.Parent=m end
  return m,a,b
 end
end
haunt(W.module('HarvestPresentation'),'Build');haunt(W.module('PlantVisuals'),'Build')
local warned=0
W.env.warn=function(msg,...)if not tostring(msg):find('pack mesh',1,true)then warned+=1;print('WARN',msg)end end
-- one build: the showcase models in order (fruit, plants, lanterns; the random packs are left out), how often the market was walked, how long it took
local function build(layout)
 local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
 local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=map
 for _,n in ipairs({'BuyStation','SellStation'})do local s=R.new('Part');s.Name=n;s.Parent=hub end
 layout.Apply(map)
 local stands=hub:FindFirstChild('MerchantStands');local walks=0
 local real=stands.GetDescendants;rawset(stands,'GetDescendants',function(self,...)walks+=1;return real(self,...)end)
 local clock=os.clock();R.advance(.1);local seconds=os.clock()-clock
 local list={};for _,m in ipairs(stands.MarketShowcase:GetChildren())do if m.Name~='Market seed pack'then list[#list+1]=m end end
 local pivots={};for i,m in ipairs(list)do pivots[i]={m.Name,m:GetPivot()}end
 local walked=walks;local parts=0;for _,d in ipairs(stands:GetDescendants())do if d:IsA('BasePart')then parts+=1 end end
 map:Destroy()
 return pivots,walked,seconds,parts
end
local pre,preWalks,preSeconds,parts=build(Pre)
local none=build(NoSink)
local new,newWalks,newSeconds=build(New)
check(#pre>=30 and#pre==#new and#none==#new,('the showcase has %d fruit, plants and lanterns in each build'):format(#pre))
local same,sunk,worst=0,0,0
for i=1,math.min(#pre,#new)do
 local a,b,z=pre[i][2],new[i][2],none[i][2]
 local d=(a.Position-b.Position).Magnitude+(a.RightVector-b.RightVector).Magnitude+(a.UpVector-b.UpVector).Magnitude
 if pre[i][1]==new[i][1]and d<1e-9 then same+=1 else worst=math.max(worst,d)end
 if(a.Position-z.Position).Magnitude>1e-9 then sunk+=1 end
end
check(same==#pre,('every showcase model stands exactly where it stood before the change (%d of %d; largest difference %g)'):format(same,#pre,worst))
check(sunk>0,('(the comparison is not empty: clearTops sinks %d of the models)'):format(sunk))
local maxSink=0;for i=1,#new do maxSink=math.max(maxSink,none[i][2].Position.Y-new[i][2].Position.Y)end
check(maxSink<=.07+1e-9 and maxSink>.045,('the sink cap is .07: the deepest sink is %.4f (the old cap of .045 left the stand fruit whose tomato tops and patch tops both lie near a step top flickering)'):format(maxSink))
check(preWalks>=#pre-5 and newWalks==1,('the market is walked %d times in all instead of %d (once per showcase model)'):format(newWalks,preWalks))
check(warned==0,'no model was skipped ('..warned..' warnings)')
print(('INFO market of %d parts: %d showcase models, clearTops walks the market %d times (was %d); showcase build %.0f ms on the mock (was %.0f ms)'):format(parts,#new,newWalks,preWalks,newSeconds*1000,preSeconds*1000))
print(('market tops: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
