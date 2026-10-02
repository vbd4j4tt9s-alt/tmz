--!nocheck
-- R132 (owner: "use our current market and just polish it"; "remove the fruit of the hour sign and replace it with the
-- pedestal"; "incorporate the plants and fruits that are already in the game"; "remove the discs"). The real
-- MarketLayout on the mock: the R69 building is still there, the coloured balls and jar blocks are gone, the game's own
-- fruit and plants stand in their place, the pedestal has no discs or rings, and one model failing never stops the rest.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
require('./mockfix')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local SSS=W.service('ServerScriptService');local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
local function server(name)local m=R.new('ModuleScript');m.Name=name;m._source=name;m.Parent=folder;return W.require(m)end
local Old=server('MarketLayoutR131');local M=server('MarketLayout')
local function build(layout)
 local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
 local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=map
 for _,n in ipairs({'BuyStation','SellStation'})do local s=R.new('Part');s.Name=n;s.Parent=hub end
 layout.Apply(map);return map,hub
end
local function names(root)local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then out[d.Name]=(out[d.Name]or 0)+1 end end;return out end
-- R131 market for comparison
local oldMap=build(Old);local oldNames=names(oldMap.EconomyHub.MerchantStands);oldMap:Destroy()
local map,hub=build(M)
local stands=hub:FindFirstChild('MerchantStands')
check(stands and stands:GetAttribute('MarketRevision')==69,'still the R69 market building')
local now=names(stands)
local kept,lost=0,{}
for name,count in pairs(oldNames)do
 local gone=name=='Fresh produce'or name=='Fruit stem'or name=='Porch leaves'or name=='Coral flower'or name=='Seed jar'or name=='Jar lid'
 if not gone then if(now[name]or 0)>=count then kept+=1 else lost[#lost+1]=name end end
end
check(#lost==0,'every R69 building part is kept (missing: '..table.concat(lost,', ')..')')
for _,n in ipairs({'Fresh produce','Fruit stem','Porch leaves','Coral flower','Seed jar','Jar lid'})do
 check(not now[n],'R69 stand-in "'..n..'" replaced by the real thing ('..tostring(oldNames[n])..' before)')
end
local chalk=0;for name in pairs(now)do if name:lower():find('chalk')or name:lower():find('board')then chalk+=1 end end
check(chalk==0,'no chalkboard sign')
check((now['String light']or 0)==15 and(now['Ceiling lamp']or 0)==3 and(now['Flower box']or 0)==4 and(now['Produce tier']or 0)==6,'polish: string lights, lamps, flower boxes, produce stands')
local lamps=0;for _,d in ipairs(stands:GetDescendants())do if d:IsA('PointLight')and d.Parent.Name=='Ceiling lamp'then lamps+=1 end end
check(lamps==3,'warm lamps light the counter')
-- Pedestal
local ped=stands:FindFirstChild('FruitOfTheHour')
check(ped~=nil,'Fruit of the Hour pedestal built')
local anchor=ped and ped:FindFirstChild('FruitAnchor')
check(anchor and anchor.Transparency==1 and anchor:FindFirstChild('FruitLight'),'invisible fruit anchor with its light')
local want=M.Center+M.FruitOfHour+V3(0,7.2,0)
check(anchor and(anchor.Position-want).Magnitude<.01,'anchor over the pedestal centre')
local discs,solidTop,highest=0,nil,-math.huge
for _,d in ipairs(ped and ped:GetDescendants()or{})do if d:IsA('BasePart')then
 local n=d.Name:lower()
 if n:find('disc')or n:find('ring')or n:find('halo')or(d.Shape==R.Enum.PartType.Cylinder and d.Size.X<.5)then discs+=1 end
 if d.Transparency<1 then highest=math.max(highest,d.Position.Y+d.Size.Y/2)end
 if d.Name=='Capital top'then solidTop=d end
end end
check(discs==0,'no discs or rings on the pedestal')
check(anchor and highest<anchor.Position.Y-.3,('the fruit floats clear of the pedestal (top %.2f, fruit %.2f)'):format(highest,anchor and anchor.Position.Y or 0))
check(solidTop and solidTop.CanCollide,'the pedestal is solid')
local plaque=ped and ped:FindFirstChild('Pedestal plaque')
check(plaque and plaque.Lettering and plaque.Lettering.Line1.Text=='FRUIT OF THE HOUR','plaque reads FRUIT OF THE HOUR')
-- Nothing of the pedestal overlaps the market deck (it stands beside the market).
local deck;for _,d in ipairs(stands:GetChildren())do if d.Name=='Market deck'then deck=d end end
local dx=deck and math.abs(anchor.Position.X-deck.Position.X)-deck.Size.X/2;local dz=deck and math.abs(anchor.Position.Z-deck.Position.Z)-deck.Size.Z/2
check(deck and(dx>3 or dz>3),('pedestal stands beside the market (%.1f / %.1f studs from the deck)'):format(dx or 0,dz or 0))
-- Real fruit, plants (and packs where their meshes exist) after the deferred build.
R.advance(.1)
local show=stands:FindFirstChild('MarketShowcase')
local count={};for _,c in ipairs(show and show:GetChildren()or{})do count[c.Name]=(count[c.Name]or 0)+1 end
local wantFruit=#M.Showcase.Sign+#M.Showcase.Counter*2+2*(2+3+3)
check((count['Market fruit']or 0)==wantFruit,('the game\'s own fruit on the sign, counter and stands (%d/%d)'):format(count['Market fruit']or 0,wantFruit))
check((count['Market plant']or 0)==2+4,('the game\'s own plants in the planters and flower boxes (%d/6)'):format(count['Market plant']or 0))
local loose=0;for _,d in ipairs(show and show:GetDescendants()or{})do
 if d:IsA('BasePart')and(not d.Anchored or d.CanCollide or d.CanQuery or d.CanTouch)then loose+=1 end
 if d:IsA('BaseScript')or d:IsA('ParticleEmitter')or d:IsA('Sound')then loose+=1 end
end
check(loose==0,'showcase models are still scenery: anchored, no collisions, scripts, sounds or particles ('..loose..')')
-- Each model stands where it should, at the size it should (spot-check the counter and planters).
-- Boxes are measured in each model's own (turned) frame, like Roblox's Model:GetBoundingBox.
local function ownBox(model)
 local pivot=model:GetPivot();local lo,hi
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
  local c=pivot:PointToObjectSpace(p.Position);local h=p.Size*.5
  local a,b=c-h,c+h
  lo=lo and V3(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))or a
  hi=hi and V3(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))or b
 end end
 return pivot*((lo+hi)*.5),hi-lo
end
local function near(at,size)
 local best=math.huge
 for _,c in ipairs(show:GetChildren())do
  local center,box=ownBox(c)
  local bottom=center-V3(0,box.Y/2,0)
  best=math.min(best,(bottom-at).Magnitude)
  if(bottom-at).Magnitude<.05 and math.abs(math.max(box.X,box.Y,box.Z)-size)<.05 then return c end
 end
 print(('  nearest model bottom %.3f studs away'):format(best))
end
local origin=M.Center
check(near(origin+V3(-4.42-.62,5.2,3.2),1.05),'counter fruit sits on the counter at 1.05 studs')
check(near(origin+V3(22.44,3.6,-13.94),5),'planter plant stands in its planter at 5 studs')
-- A model that cannot be built is skipped with a warning; the rest still appear.
map:Destroy()
local HP=W.module('HarvestPresentation');local realBuild=HP.Build
HP.Build=function(item,...)if item.SeedId=='AppleSeed'then error('still loading')end;return realBuild(item,...)end
local skipped=0;local realWarn=W.env.warn
W.env.warn=function(msg,...)if tostring(msg):find('still loading',1,true)then skipped+=1 end;return realWarn(msg,...)end
local map2,hub2=build(M);R.advance(.1)
local show2=hub2.MerchantStands.MarketShowcase;local fruit2=0
for _,c in ipairs(show2:GetChildren())do if c.Name=='Market fruit'then fruit2+=1 end end
local appleSlots=0;for _,s in ipairs(M.Showcase.Sign)do if s[1]=='AppleSeed'then appleSlots+=1 end end
for _,c in ipairs(M.Showcase.Counter)do if c[1]=='AppleSeed'then appleSlots+=2 end end
for _,list in pairs(M.Showcase.Stands)do for t,id in ipairs(list)do if id=='AppleSeed'then appleSlots+=t==1 and 2 or 3 end end end
check(fruit2==wantFruit-appleSlots and skipped==appleSlots,('a failing fruit is skipped with a warning, the rest are built (%d built, %d skipped)'):format(fruit2,skipped))
check(hub2.MerchantStands:FindFirstChild('FruitOfTheHour')~=nil,'the market and pedestal are there either way')
HP.Build=realBuild;W.env.warn=realWarn
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
