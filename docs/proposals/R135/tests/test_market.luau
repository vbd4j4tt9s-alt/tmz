--!nocheck
-- R133 market, on the mock with the real MarketLayout (R132: keep the R69 market and polish it; real fruit and plants;
-- pedestal without discs). R133 owner play-test fixes:
--  * fruit no longer floats (placed on its VISIBLE parts; a hidden plant part is simulated here),
--  * every shelf full of random packs (any biome, any tier, no repeats),
--  * soil under the planter and flower-box plants,
--  * a wall behind the front MARKET sign, no inside-facing MARKET lettering,
--  * lamps hang from a ceiling beam, string lights hang on a wire between the porch posts, stands are solid steps,
--  * pots, crates and a barrel at the back, all resting on the deck,
--  * the Fruit of the Hour floats higher (bigger fruit) above a soft projector beam.
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
local Old=server('MarketLayoutR131');local M=server('MarketLayout')
-- Fruit and plant models carry hidden parts in the game: add a big invisible one above each, like the real thing.
local function haunt(mod,fn)
 local real=mod[fn]
 mod[fn]=function(...)
  local m,a,b=real(...)
  if m then local ghost=R.new('Part');ghost.Name='Hidden plant';ghost.Size=V3(6,6,6);ghost.CFrame=m:GetPivot()*CF(0,7,0);ghost.Transparency=1;ghost.Parent=m end
  return m,a,b
 end
 return real
end
local HP=W.module('HarvestPresentation');local PV=W.module('PlantVisuals')
local realFruit=haunt(HP,'Build');haunt(PV,'Build')
local function build(layout)
 local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
 local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=map
 for _,n in ipairs({'BuyStation','SellStation'})do local s=R.new('Part');s.Name=n;s.Parent=hub end
 layout.Apply(map);return map,hub
end
local function names(root)local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then out[d.Name]=(out[d.Name]or 0)+1 end end;return out end
local function each(root,name)local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')and d.Name==name then out[#out+1]=d end end;return out end
-- World half-height of a part (cylinders and turned parts included).
local function halfY(p)local r=p.CFrame.R;return(math.abs(r[2][1])*p.Size.X+math.abs(r[2][2])*p.Size.Y+math.abs(r[2][3])*p.Size.Z)/2 end
local function bottom(p)return p.Position.Y-halfY(p)end
local function top(p)return p.Position.Y+halfY(p)end
-- R131 market for comparison
local oldMap=build(Old);local oldNames=names(oldMap.EconomyHub.MerchantStands);oldMap:Destroy()
local skipped=0;local realWarn=W.env.warn
W.env.warn=function(msg,...)if not tostring(msg):find('pack mesh',1,true)then skipped+=1;print('WARN',msg)end end
local map,hub=build(M)
local stands=hub:FindFirstChild('MerchantStands')
local C=M.Center
check(stands and stands:GetAttribute('MarketRevision')==69 and stands:GetAttribute('MarketPolish')==135,'still the R69 market building, R135 polish')
local now=names(stands)
local lost={}
for name,count in pairs(oldNames)do
 local gone=name=='Fresh produce'or name=='Fruit stem'or name=='Porch leaves'or name=='Coral flower'or name=='Seed jar'or name=='Jar lid'or name=='Porch diagonal brace'
 if not gone and(now[name]or 0)<count then lost[#lost+1]=name end
end
check(#lost==0,'every R69 building part is kept (missing: '..table.concat(lost,', ')..')')
for _,n in ipairs({'Fresh produce','Fruit stem','Porch leaves','Coral flower','Seed jar','Jar lid'})do check(not now[n],'R69 stand-in "'..n..'" gone')end

-- Front sign: a real wall behind it; MARKET lettering only faces outside -------------------------------------------
local fascia=each(stands,'Front fascia wall')[1];local sign=each(stands,'Market sign')[1]
check(fascia~=nil,'a fascia wall fills the front (walk-through like every R69 part)')
if fascia and sign then
 local behind=fascia.Position.Z>sign.Position.Z and math.abs(fascia.Position.Z-sign.Position.Z)<1.5
 local covers=math.abs(fascia.Position.X-sign.Position.X)+sign.Size.X/2<=fascia.Size.X/2 and bottom(fascia)<=bottom(sign)+.01 and top(fascia)>=top(sign)-.01
 check(behind and covers,'the wall is right behind the sign and covers all of it')
 local header=each(stands,'Porch header')[1]
 check(header and math.abs(top(fascia)-bottom(header))<.05,'the wall reaches up to the porch header')
end
local inward,outward=0,0
for _,board in ipairs(stands:GetChildren())do if board.Name=='Market sign'or board.Name=='Market entrance sign'then
 for _,gui in ipairs(board:GetChildren())do if gui.ClassName=='SurfaceGui'then
  local n=board.CFrame:VectorToWorldSpace(R.Vector3.FromNormalId(gui.Face))
  if n:Dot(C-board.Position)>0 then inward+=1 else outward+=1 end
 end end
end end
check(inward==0 and outward==4,('no MARKET lettering faces into the market (%d inside, %d outside)'):format(inward,outward))
check(not now['Porch diagonal brace'],'no braces buried in the new wall')
for _,h in ipairs(each(stands,'Lantern hanger'))do
 local header=each(stands,'Porch header')[1]
 check(h.Position.Y+h.Size.Z/2>=bottom(header)-.05,'porch lanterns hang from the header')
end

-- Lights hang from something ------------------------------------------------------------------------------------
local beam=each(stands,'Ceiling beam')[1]
check(beam~=nil,'ceiling beam for the lamps')
local lintels=each(stands,'Side entrance lintel')
if beam then
 local rests=0;for _,l in ipairs(lintels)do if math.abs(bottom(beam)-top(l))<.06 and math.abs(l.Position.X-C.X)<=beam.Size.X/2+l.Size.X/2 and math.abs(beam.Position.Z-l.Position.Z)<=l.Size.Z/2 then rests+=1 end end
 check(rests==2,'the beam rests on both side door lintels ('..rests..')')
end
for _,cord in ipairs(each(stands,'Lamp cord'))do
 local up=cord.Position.Y+cord.Size.Z/2
 check(beam and math.abs(up-bottom(beam))<.06,('lamp cord reaches the beam (%.2f vs %.2f)'):format(up,beam and bottom(beam)or 0))
end
check(#each(stands,'Ceiling lamp')==3 and #each(stands,'Lamp shade')==3,'three warm lamps')
local wires=each(stands,'Light wire');local bulbs=each(stands,'String light')
check(#bulbs==15 and #wires==16,'15 string lights on a 16-piece wire')
local posts={};for _,p in ipairs(each(stands,'Porch support'))do posts[#posts+1]=p end
local function ends(w)local h=w.Size.Z/2;return w.CFrame*V3(0,0,-h),w.CFrame*V3(0,0,h)end
local touchedPosts=0
for _,w in ipairs(wires)do for _,e in ipairs({ends(w)})do for _,post in ipairs(posts)do
 local l=post.CFrame:PointToObjectSpace(e)
 if math.abs(l.X)<=post.Size.X/2+.05 and math.abs(l.Y)<=post.Size.Y/2 and math.abs(l.Z)<=post.Size.Z/2+.05 then touchedPosts+=1 end
end end end
check(touchedPosts==2,'the wire is tied to both porch posts ('..touchedPosts..')')
local hanging=0
for _,b in ipairs(bulbs)do
 local topPoint=b.Position+V3(0,b.Size.Y/2,0);local best=math.huge
 for _,w in ipairs(wires)do local a,z=ends(w);local d=z-a;local t=math.clamp((topPoint-a):Dot(d)/d:Dot(d),0,1);best=math.min(best,(a+d*t-topPoint).Magnitude)end
 if best<.08 then hanging+=1 end
end
check(hanging==15,'every bulb hangs on the wire ('..hanging..'/15)')

-- Stands, soil, back props ---------------------------------------------------------------------------------------
local tiers=each(stands,'Produce tier');local grounded=0
for _,t in ipairs(tiers)do if math.abs(bottom(t)-C.Y)<.01 then grounded+=1 end end
check(#tiers==6 and grounded==6,'produce stands are solid steps standing on the ground ('..grounded..'/6)')
check(#each(stands,'Planter soil')==2 and #each(stands,'Flower box soil')==4,'soil in both planters and all four flower boxes')
for _,soil in ipairs(each(stands,'Planter soil'))do
 local rim=nil;for _,r in ipairs(each(stands,'Planter gold rim'))do if math.abs(r.Position.X-soil.Position.X)<.1 then rim=r end end
 check(rim and math.abs(bottom(soil)-top(rim))<.05 and soil.Size.X<rim.Size.X,'planter soil sits on the planter, inside its gold rim')
end
local deckTop=top(each(stands,'Market deck')[1])
local backProps=0
for _,n in ipairs({'Pot','Water barrel'})do for _,p in ipairs(each(stands,n))do
 if math.abs(bottom(p)-deckTop)<.05 and p.Position.Z-C.Z>15 then backProps+=1 end
end end
local crates=each(stands,'Wooden crate')
check(backProps==5 and #crates==2,'four pots and a barrel stand on the deck behind the market, plus two crates ('..backProps..')')
check(#crates==2 and math.abs(bottom(crates[1])-deckTop)<.05 or math.abs(bottom(crates[2])-deckTop)<.05,'the crate stack starts on the deck')

-- Pedestal ------------------------------------------------------------------------------------------------------
local ped=stands:FindFirstChild('FruitOfTheHour')
local anchor=ped and ped:FindFirstChild('FruitAnchor')
check(anchor and anchor.Transparency==1 and anchor:FindFirstChild('FruitLight'),'invisible fruit anchor with its light')
check(anchor and(anchor.Position-(C+M.FruitOfHour+V3(0,M.FruitHeight,0))).Magnitude<.01 and M.FruitHeight>=8,'the fruit floats higher (anchor at '..tostring(M.FruitHeight)..')')
local discs,highest=0,-math.huge
for _,d in ipairs(ped and ped:GetDescendants()or{})do if d:IsA('BasePart')then
 local n=d.Name:lower()
 if n:find('disc')or n:find('ring')or n:find('halo')then discs+=1 end
 if d.Transparency<.5 then highest=math.max(highest,top(d))end
end end
check(discs==0,'no discs or rings on the pedestal')
check(anchor and highest<anchor.Position.Y-1.5,('a 4.2-stud fruit floats clear of the pedestal (top %.2f, fruit centre %.2f)'):format(highest,anchor and anchor.Position.Y or 0))
local pbeam=ped and ped:FindFirstChild('Projector beam')
check(pbeam and pbeam.Transparency>=.8 and math.abs(bottom(pbeam)-(C.Y+5.04))<.05,'a soft projector beam rises from the cradle')

-- Showcase ------------------------------------------------------------------------------------------------------
R.advance(.1)
local show=stands:FindFirstChild('MarketShowcase')
local count={};for _,c in ipairs(show and show:GetChildren()or{})do count[c.Name]=(count[c.Name]or 0)+1 end
local wantFruit=#M.Showcase.Counter*3+2*(2+3+3)
check((count['Market fruit']or 0)==wantFruit,('fruit in the counter crates and on the stands, none on the sign (%d/%d)'):format(count['Market fruit']or 0,wantFruit))
local wantPlants=2+4+#M.Showcase.Back.Pots
check((count['Market plant']or 0)==wantPlants,('plants in the planters, flower boxes and back pots (%d/%d)'):format(count['Market plant']or 0,wantPlants))
check(skipped==0,'no fruit or plant was skipped ('..skipped..')')
local loose=0;for _,d in ipairs(show and show:GetDescendants()or{})do
 if d:IsA('BasePart')and(not d.Anchored or d.CanCollide or d.CanQuery or d.CanTouch)then loose+=1 end
 if d:IsA('BaseScript')or d:IsA('ParticleEmitter')or d:IsA('Sound')then loose+=1 end
end
check(loose==0,'showcase models are scenery: anchored, no collisions, scripts, sounds or particles ('..loose..')')
-- Every fruit and plant stands with its VISIBLE bottom on its spot (the hidden plant part is ignored).
-- Visible box from the live part sizes (sphere meshes: part size x mesh scale), like HarvestGeometry before scaling.
local function liveBounds(m)
 local lo,hi
 for _,p in ipairs(m:GetDescendants())do if p:IsA('BasePart')and p.Transparency<.95 then
  local size=p.Size;local mesh=p:FindFirstChildOfClass('SpecialMesh');if mesh and mesh.Scale then size=V3(size.X*mesh.Scale.X,size.Y*mesh.Scale.Y,size.Z*mesh.Scale.Z)end
  for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
   local q=p.CFrame*V3(size.X*x,size.Y*y,size.Z*z)
   lo=lo and V3(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z))or q;hi=hi and V3(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))or q
  end end end
 end end
 return(lo+hi)*.5,hi-lo
end
local G=W.module('HarvestGeometry')
local function visibleBottom(m)local c,b=G.Bounds(m);return c-V3(0,b.Y/2,0),b end
local function standsOn(at,size)
 local best=math.huge
 for _,m in ipairs(show:GetChildren())do
  -- World-aligned box: a turned model is up to ~1.45x wider and its box centre shifts a little sideways.
  local foot,b=visibleBottom(m);local d=(foot-at).Magnitude;best=math.min(best,d)
  local flat=V3(foot.X-at.X,0,foot.Z-at.Z).Magnitude;local big=math.max(b.X,b.Y,b.Z)
  -- R135: a fruit sits on its seat, so a stub or point below it may sink into the crate/step (up to 30% of its height).
  if foot.Y<=at.Y+.02 and foot.Y>=at.Y-.3*b.Y-.02 and flat<.15 and big>=size-.06 and big<=size*1.45 and b.Y<=size+.06 then return m,at.Y-foot.Y end
 end
 print(('  nearest visible bottom %.3f studs away'):format(best))
end
local cr=M.Showcase.Crates
check(standsOn(C+V3(cr.X[1]-cr.Spacing,cr.Y,cr.Z),cr.Size),'counter fruit sits in its crate at '..cr.Size..' studs (visible size)')
check(standsOn(C+V3(23.2-2.4/2,M.Showcase.StandStep,-23),1.9),'stand fruit sits on the bottom step')
check(standsOn(C+V3(23.2,3*M.Showcase.StandStep,-23+2*1.4),1.3),'stand fruit sits on the top step')
do local plantModel,sunkPlant=standsOn(C+V3(M.Showcase.Planter.X,M.Showcase.Planter.Soil-.05,M.Showcase.Planter.Z),5)
 check(plantModel and sunkPlant<.05,'the planter plant grows right out of the soil (stem not sunk: '..tostring(sunkPlant)..')')end
-- R135 (owner: "the berries are still floating; use fruits that stand easier, like the lantern fruit") ------------
local berries={BluebellSeed=true,IceberrySeed=true}
local picked={};for _,id in ipairs(M.Showcase.Counter)do picked[#picked+1]=id end
for _,list in pairs(M.Showcase.Stands)do for _,id in ipairs(list)do picked[#picked+1]=id end end
local bad={};for _,id in ipairs(picked)do if berries[id]then bad[#bad+1]=id end end
check(#bad==0,'no berry clusters on the counter or stands ('..table.concat(bad,', ')..')')
check(table.find(M.Showcase.Counter,'LanternFernSeed')~=nil,'lantern fruit in a counter crate')
-- Every fruit is one solid piece: its visible parts all touch (the berry clusters were balls touching at a point).
local function solid(m)
 local ps={};for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')and d.Transparency<.95 then ps[#ps+1]=d end end
 local function box(p)local sz=p.Size;local mesh=p:FindFirstChildOfClass('SpecialMesh');if mesh and mesh.Scale then sz=V3(sz.X*mesh.Scale.X,sz.Y*mesh.Scale.Y,sz.Z*mesh.Scale.Z)end
  local e=sz/2;local r=p.CFrame.R;local h=V3(math.abs(r[1][1])*e.X+math.abs(r[1][2])*e.Y+math.abs(r[1][3])*e.Z,math.abs(r[2][1])*e.X+math.abs(r[2][2])*e.Y+math.abs(r[2][3])*e.Z,math.abs(r[3][1])*e.X+math.abs(r[3][2])*e.Y+math.abs(r[3][3])*e.Z)
  return p.Position-h,p.Position+h,sz end
 local lo,hi,vol={},{},{};local total=0
 for i,p in ipairs(ps)do local a,b,sz=box(p);lo[i],hi[i]=a,b;vol[i]=sz.X*sz.Y*sz.Z;total+=vol[i]end
 local group={};for i=1,#ps do group[i]=i end
 local function find(i)while group[i]~=i do i=group[i]end;return i end
 for i=1,#ps do for j=i+1,#ps do
  if lo[i].X<=hi[j].X+.02 and lo[j].X<=hi[i].X+.02 and lo[i].Y<=hi[j].Y+.02 and lo[j].Y<=hi[i].Y+.02 and lo[i].Z<=hi[j].Z+.02 and lo[j].Z<=hi[i].Z+.02 then group[find(i)]=find(j)end
 end end
 local sums={};for i=1,#ps do local g=find(i);sums[g]=(sums[g]or 0)+vol[i]end
 local best=0;for _,v in pairs(sums)do best=math.max(best,v)end
 return best/math.max(total,1e-9)
end
local weakest,which=1,''
for _,m in ipairs(show:GetChildren())do if m.Name=='Market fruit'then local s2=solid(m);if s2<weakest then weakest,which=s2,m:GetAttribute('HarvestIndex')end end end
check(weakest>=.85,('every market fruit is one solid piece (weakest %.0f%% in one piece)'):format(weakest*100))
-- The lantern sits in its crate: its stub sinks below the crate surface, its body rests on it.
local lx=cr.X[table.find(M.Showcase.Counter,'LanternFernSeed')]
local lantern,sunk=standsOn(C+V3(lx,cr.Y,cr.Z),cr.Size)
check(lantern and sunk>.01,('the lantern sits in its crate (stub %.2f studs into it)'):format(sunk or -1))
local melon,flat=standsOn(C+V3(23.2-2.4/2,M.Showcase.StandStep,-23),1.9)
check(melon and flat<.05,'a flat-bottomed watermelon sits right on the step ('..tostring(flat)..')')
-- The inside shelves stay full of random packs (owner: "fill the shelves inside with packs, it can be random").
local shelfSpots=0;local sh2=M.Showcase.Shelves
for _,t in ipairs(sh2.Tops)do for _,side in ipairs({-1,1})do for k=1,sh2.PerShelf do shelfSpots+=1 end end end
check(shelfSpots==20 and #M.ShelfPacks(shelfSpots,W.env.Random.new(3))==20,'20 random packs for the 4 inside shelves')
local soilTop=nil;for _,s in ipairs(each(stands,'Planter soil'))do soilTop=top(s)end
check(soilTop and math.abs(soilTop-(C.Y+M.Showcase.Planter.Soil))<.01,'planter soil top matches where the plant stands')
-- Shelf packs: 20, random, no repeats; on the shelves.
local picks=M.ShelfPacks(20,W.env.Random.new(7));local seen,stagesSeen,tiersSeen={},{},{}
local dup=false;for _,p in ipairs(picks)do local k=p.Stage..':'..p.Variant;if seen[k]then dup=true end;seen[k]=true;stagesSeen[p.Stage]=true;tiersSeen[p.Variant]=true end
local nStages,nTiers=0,0;for _ in pairs(stagesSeen)do nStages+=1 end;for _ in pairs(tiersSeen)do nTiers+=1 end
check(#picks==20 and not dup,'20 shelf packs, never the same pack twice')
check(nStages>=5 and nTiers>=5,('a mix of biomes and tiers (%d biomes, %d tiers)'):format(nStages,nTiers))
local other=M.ShelfPacks(20,W.env.Random.new(99));local same=0;for i=1,20 do if other[i].Stage==picks[i].Stage and other[i].Variant==picks[i].Variant then same+=1 end end
check(same<10,'another server shows a different mix ('..same..' same)')
local sh=M.Showcase.Shelves
check(#sh.Tops*2*sh.PerShelf==20 and(sh.PerShelf-1)*sh.Spacing+sh.Size<=11.05,'four shelves of five packs fit their shelves')
local shelves=each(stands,'Shop shelf');local matched=0
for _,s in ipairs(shelves)do for _,t in ipairs(sh.Tops)do if math.abs(top(s)-(C.Y+t))<.01 and math.abs(math.abs(s.Position.X-C.X)-sh.X)<.01 then matched+=1 end end end
check(matched==4,'packs stand on the real shelf tops ('..matched..'/4)')
-- A fruit that fails to build is skipped with a warning; the rest still appear.
map:Destroy();skipped=0
local hauntedFruit=HP.Build
HP.Build=function(item,...)if item.SeedId=='AppleSeed'then error('still loading')end;return hauntedFruit(item,...)end
local map2,hub2=build(M);R.advance(.1)
local fruit2=0;for _,c in ipairs(hub2.MerchantStands.MarketShowcase:GetChildren())do if c.Name=='Market fruit'then fruit2+=1 end end
local appleSlots=0;for _,id in ipairs(M.Showcase.Counter)do if id=='AppleSeed'then appleSlots+=3 end end
for _,list in pairs(M.Showcase.Stands)do for t,id in ipairs(list)do if id=='AppleSeed'then appleSlots+=t==1 and 2 or 3 end end end
check(fruit2==wantFruit-appleSlots and skipped==appleSlots,('a failing fruit is skipped with a warning, the rest are built (%d built, %d skipped)'):format(fruit2,skipped))
HP.Build=hauntedFruit;W.env.warn=realWarn
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
