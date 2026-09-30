--!nocheck
local W=require('./world');local Mx=W.Mx;local CF,V=Mx.CFrame,Mx.Vector3.new
local which=...
local stubs={KeeperAudio={Voice=function()return nil,0,1 end,Asset=function()return nil end},SoundTiming={Play=function()end},
 CosmeticBudget={KeeperDue=function()return true end},ClientFxBudget={Low=function()return false end},KeeperRecoveryDash={VisualFrame=function(_,_,f)return f end}}
local world=W.new(require('./bundle_'..which),stubs);local req=world.require;local Cfg=req('KeeperRigConfig')
local models={}
for stage=1,7 do
 local model=W.R.new('Model');model:SetAttribute('GardenerArtVersion',99);model:SetAttribute('CreatureStage',stage);model:SetAttribute('GuardianBehavior','CHASING');model:SetAttribute('TargetUserId',77)
 local root=W.R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF.new(stage*30,4,0);root.Parent=model
 local body;if stage==1 or stage==5 or stage==7 then body=req('KeeperUpgradeArt').Build(stage)else body=W.R.new('Model');body:SetAttribute('VisualVersion',99)
  for _,s in ipairs(Cfg[stage].Parts)do local p=W.R.new('MeshPart');p.Name=s.Name;p.Size=V(table.unpack(s.Size));p:SetAttribute('RestCFrame',CF.new(table.unpack(s.Center)));p:SetAttribute('BeastGroup',s.Group);p.Parent=body end end
 body.Name='BeastBody';body.Parent=model;model.Parent=world.Workspace;models[stage]={model,root}
end
world.run('BeastAnimation');world.step(1/60)
world.Me.CFrame=CF.new(100,4,-30)
local t=os.clock()
for i=1,600 do for _,m in ipairs(models)do m[1]:SetAttribute('KeeperTravelSpeed',40);m[2].CFrame=m[2].CFrame*CF.new(0,0,-40/60)end;world.step(1/60)end
print(which,string.format('%.3f ms per frame (7 chasing keepers, mock CFrame math)',(os.clock()-t)/600*1000))
