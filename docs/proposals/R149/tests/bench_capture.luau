--!nocheck
-- R149 review part 2, finding 2: what PlantGrowth.Capture costs. The mock clock is real CPU time here (os.clock of this file), so the numbers are relative:
-- the same file runs on the checkout before and after the change (run_growth.sh prints it for this checkout; point it at an older src to compare).
--  near       the client's near detail: Capture of a ripe plant model, the leaf-attachment pass included (BuildGrowing);
--  silhouette what the server (GrowingSupports -> BeginGrowth) and DistantPlantView do: Capture(..., {Plain=true}) (an older Capture ignores the option and
--             therefore measures the full pass, which is what they paid before the change);
--  link tests the contact() calls of one Capture (PlantGrowth.Stats.LinkTests).
-- Prints   CAPTURE <plant> parts=<n> near_ms=<ms> near_tests=<n> plain_ms=<ms> plain_tests=<n>   per plant and one CAPTURE_TOTAL line.
local C=require('./growth_common');local W,R=C.W,C.R
local Growth,Visuals,Catalog=C.Growth,C.Visuals,C.Catalog
local function timed(f)local t=os.clock();f();return(os.clock()-t)*1000 end
local repeats=3
local function capture(id,options)
 local def=Catalog[id];local crop=C.crop(id);local ripe=table.clone(crop);ripe.ReadyAt=0
 local best,tests,parts=math.huge,0,0
 for _=1,repeats do
  local model=Visuals.Build(id,C.origin,ripe,4,math.huge,nil,nil);model.Parent=W.workspace
  local sockets={};for i=1,def.FruitCount do sockets[i]=Visuals.FruitSocket(crop,def,i)end
  local before=Growth.Stats.LinkTests;local state
  local ms=timed(function()state=Growth.Capture(model,id,def,crop,C.origin,sockets,options)end)
  tests=Growth.Stats.LinkTests-before;parts=#state.Parts;best=math.min(best,ms);model:Destroy()
 end
 return best,tests,parts
end
local totalNear,totalPlain,testsNear,testsPlain,worst,worstId=0,0,0,0,0,''
local only=...
for _,id in ipairs(C.ids())do if not only or id==only then
 local nm,nt,parts=capture(id,nil);local pm,pt=capture(id,{Plain=true})
 totalNear+=nm;totalPlain+=pm;testsNear+=nt;testsPlain+=pt
 if nm>worst then worst,worstId=nm,id end
 print(('CAPTURE %-22s parts=%4d near_ms=%7.2f near_tests=%5d plain_ms=%7.2f plain_tests=%5d'):format(id,parts,nm,nt,pm,pt))
end end
print(('CAPTURE_TOTAL near_ms=%.1f near_tests=%d plain_ms=%.1f plain_tests=%d worst=%s %.1f ms'):format(totalNear,testsNear,totalPlain,testsPlain,worstId,worst))
