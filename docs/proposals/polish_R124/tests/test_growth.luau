--!nocheck
-- R125 plant growth pace on the REAL PlantCatalog: above Uncommon (not Forest, not Mech) mapped into rarity bands up
-- to 4 h for King, regrow by the same factor, fruit value x max(1, factor/2) (half of the old income per hour kept).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
W.stub('GrowthPace125',{Apply=function(c)return c end}) -- load the catalog as it was before R125
-- R148: and without the seed roster change. Roster149.ApplyPlants runs AFTER the pacing and its plants (Aloe, Sand Fruit, Fire Pepper,
-- Moon Melon) are exempt from it, so the pacing rules below are checked on the plants the real pipeline paces (Fire Pepper and Moon
-- Melon still Rare, as the pacing sees them); test_roster.luau checks the roster plants' final numbers and that the pacing leaves them alone.
local Roster=W.module('Roster149');Roster.ApplyPlants=function()end;Roster.ApplyBalance=function()end
local C=W.module('PlantCatalog')
local orig={}
local function income(d)local t=d.Regrows==false and d.Seconds or d.RegrowSeconds or d.Seconds;return d.Value*(d.FruitCount or 1)/t end -- uncapped
for id,d in pairs(C)do if type(d)=='table'and d.Seconds then orig[id]={Seconds=d.Seconds,Regrow=d.RegrowSeconds,Value=d.Value,Income=income(d)}end end
local G=W.load('GrowthPace125',R.new('ModuleScript'))
G.Apply(C)
local rows,byR={}, {}
for id,o in pairs(orig)do
 local d=C[id];local exempt=d.Stage==1 or d.Mech==true or d.Rarity=='Common'or d.Rarity=='Uncommon'
 if exempt then
  check(d.Seconds==o.Seconds and d.RegrowSeconds==o.Regrow and d.Value==o.Value,id..' unchanged ('..tostring(d.Rarity)..', stage '..tostring(d.Stage)..')')
 else
  local band=G.Bands[d.Rarity];check(band~=nil,id..' has a band')
  check(d.Seconds>=band[1]-10 and d.Seconds<=band[2]+10,('%s %s: %d s inside %d..%d'):format(id,d.Rarity,d.Seconds,band[1],band[2]))
  local k=d.Seconds/o.Seconds;check(k>=1,id..' never faster')
  if o.Regrow then check(math.abs(d.RegrowSeconds-o.Regrow*k)<=5,id..' regrow slowed by the same factor')end
  local want=math.max(o.Value,math.min(G.MaxValue,math.floor(o.Value*math.max(1,k/2)+.5)))
  check(d.Value==want,id..' value x max(1,k/2), capped at 9e10')
  check(d.Value*100<=9e12,id..' a x100 harvest stays within the 9e12 save limit')
  local ratio=income(d)/o.Income;local capped=d.Value==G.MaxValue
  check(capped or(ratio>=.45 and ratio<=1.01),('%s keeps %.2f of its income per hour%s'):format(id,ratio,capped and' (capped)'or''))
  if capped then print(('CAPPED %s keeps %.2f of its income per hour'):format(id,ratio))end
  byR[d.Rarity]=byR[d.Rarity]or{};table.insert(byR[d.Rarity],{Id=id,Old=o.Seconds,New=d.Seconds,Ratio=ratio})
  check(d.Seconds%1==0 and d.Seconds<=86400 and(d.RegrowSeconds or 1)<=86400,id..' fits the save limits')
 end
end
for r,list in pairs(byR)do
 table.sort(list,function(a,b)return a.Old<b.Old end)
 for i=2,#list do check(list[i].New>=list[i-1].New,r..': order kept')end
 local band=G.Bands[r];check(list[1].New==band[1]and list[#list].New==band[2],r..': fastest at '..band[1]..' s, slowest at '..band[2]..' s')
 local s={};for _,e in ipairs(list)do s[#s+1]=('%s %s->%s'):format(e.Id:gsub('Seed$',''),os.date('!%Hh%Mm',e.Old):gsub('^00h',''),os.date('!%Hh%Mm',e.New):gsub('^00h',''))end
 print(r..': '..table.concat(s,', '))
end
local maxKing=0;for _,e in ipairs(byR.King or{})do maxKing=math.max(maxKing,e.New)end
check(maxKing==4*3600,'slowest King plant takes 4 hours')
local before={};for id,d in pairs(C)do before[id]=d.Seconds end;G.Apply(C)
local same=true;for id,d in pairs(C)do if before[id]~=d.Seconds then same=false end end;check(same,'applying twice changes nothing')
local odd=0;for k,v in pairs(C)do if type(v)~='table'then odd+=1 end end;check(odd==0,'no non-plant keys added to the catalog')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
