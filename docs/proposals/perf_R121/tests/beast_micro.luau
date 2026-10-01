--!nocheck
-- R121 micro-check: per-frame Sound work in BeastAnimation (7 keepers, asleep and far, then chasing near).
local W=require('./keeper_world');local Mx=W.Mx;local CF,V=Mx.CFrame,Mx.Vector3.new
local which=...
local R=require('./roblox')
local counts={Stop=0,Voice=0,Writes=0,Fx=0}
local Inst=R.Inst
local oldStop=Inst.Stop;Inst.Stop=function(self)counts.Stop+=1;self._props.IsPlaying=false;self._props.Playing=false end
Inst.Play=function(self)self._props.IsPlaying=true;self._props.Playing=true end
local stubs={KeeperAudio={Voice=function(stage)counts.Voice+=1;if stage==1 then return nil,0,1 end;return 'rbxassetid://'..(1000+stage),.3,1 end,Asset=function()return nil end},
 SoundTiming={Play=function(s)s:Play()end},
 CosmeticBudget={KeeperDue=function()return true end},ClientFxBudget={Low=function()return false end},KeeperRecoveryDash={VisualFrame=function(_,_,f)return f end}}
local world=W.new(require('./bundle_'..which),stubs);local req=world.require;local Cfg=req('KeeperRigConfig')
local models={}
for stage=1,7 do
 local model=W.R.new('Model');model:SetAttribute('GardenerArtVersion',99);model:SetAttribute('CreatureStage',stage);model:SetAttribute('GuardianBehavior','GUARDING')
 local root=W.R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF.new(stage*30,4,0);root.Parent=model
 local body;if stage==1 or stage==5 or stage==7 then body=req('KeeperUpgradeArt').Build(stage)else body=W.R.new('Model');body:SetAttribute('VisualVersion',99)
  for _,s in ipairs(Cfg[stage].Parts)do local p=W.R.new('MeshPart');p.Name=s.Name;p.Size=V(table.unpack(s.Size));p:SetAttribute('RestCFrame',CF.new(table.unpack(s.Center)));p:SetAttribute('BeastGroup',s.Group);p.Parent=body end end
 body.Name='BeastBody';body.Parent=model;model.Parent=world.Workspace;models[stage]={model,root}
end
world.run('BeastAnimation');world.step(1/60)
-- Count Sound property writes made by the script.
local sounds={}
for _,m in ipairs(models)do local s=m[2]:FindFirstChild('KeeperVoiceLocal');table.insert(sounds,s)
 end
local mt=getmetatable(sounds[1]);local rawNew=mt.__newindex
mt.__newindex=function(o,k,v)if o._class=='Sound'and(k=='Volume'or k=='PlaybackSpeed'or k=='SoundId')then counts.Writes+=1 end;return rawNew(o,k,v)end
counts.Stop=0;counts.Voice=0;counts.Writes=0
for i=1,600 do world.step(1/60)end
print(which,'asleep 600 frames: Stop',counts.Stop,'Voice()',counts.Voice,'Sound writes',counts.Writes)
-- Chasing near: the voice still plays exactly once per gap per keeper.
local plays=0;local P=Inst.Play;Inst.Play=function(self)plays+=1;P(self)end
world.Workspace.CurrentCamera.CFrame=CF.new(90,10,10)
for _,m in ipairs(models)do m[1]:SetAttribute('GuardianBehavior','CHASING')end
counts.Stop=0;counts.Voice=0;counts.Writes=0
for i=1,600 do world.step(1/60)end
print(which,'chasing 600 frames: Stop',counts.Stop,'Voice()',counts.Voice,'Sound writes',counts.Writes,'voice plays',plays)
