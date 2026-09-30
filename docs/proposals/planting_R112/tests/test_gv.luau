--!nocheck
local W=require('./world').build()
local R=W.R;local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
W.camera.CFrame=R.CFrame.lookAt(V3(0,14,-22),V3(0,0,0))
local map=new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local plot=new('Part');plot.Name='DirtPlot_1';plot.Size=V3(46,.8,22.6);plot.CFrame=CF(0,.4,0);plot:SetAttribute('GardenSoil',true);plot.Parent=map
local n=0
local function crop(planted,id)n+=1;local m=new('Model');m.Name='Crop_'..n
 for k,v in pairs({GardenPlantV141=true,CropId=id or ('c'..n),SeedId='SunflowerSeed',GrowthStage=1,PlantScale=1,PlantedAt=planted,MatureAt=planted+60,ReadyAt=planted+60})do m:SetAttribute(k,v)end
 local a=new('Part');a.Name='CropAnchor';a.CFrame=CF(0,.825,0);a.Parent=m;m.Parent=plot;return m end
local young=crop(math.floor(W.serverNow)-1)
-- Spy on the real module.
local P=W.req(W.RS.PlantingEffects);local realNew=P.new;local fx
P.new=function(...)fx=realNew(...);return fx end
local scriptInst=new('LocalScript');scriptInst.Name='GardenVisuals'
local ok,err=pcall(W.load,'GardenVisuals',scriptInst)
check(ok,'GardenVisuals loads: '..tostring(err))
if fx then
 W.frames(10)
 check(fx.Records['c1']and fx.Records['c1'].Initial==true,'initial scan passes initial=true')
 check(#fx.Piles==0,'no pile on join even for a 1 s old crop')
 W.frames(60*4)
 local m=crop(math.floor(W.serverNow));W.frames(3)
 check(#fx.Piles==1,'DescendantAdded crop after grace piles')
 map.DescendantRemoving:Fire(m);m:Destroy();W.frames(40)
 check(fx.Records['c2']==nil and fx.LiveChunks==0,'DescendantRemoving releases the crop')
 scriptInst:Destroy();check(W.workspace:FindFirstChild('LocalPlantingEffects')==nil,'script destroy cleans up')
end
print(('%d checks, %d failures'):format(checks,fails))
