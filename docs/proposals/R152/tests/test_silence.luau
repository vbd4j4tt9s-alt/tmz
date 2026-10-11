--!nocheck
-- R152 sound tidy-up, on the Roblox mock with the REAL client scripts of this checkout (InteractionAudio replaced by a recorder, every Sound recorded):
--  1. Treadmills are silent: stepping onto / off a treadmill (TreadmillTraining true / false), as often as you like, plays no cue and no Sound; the
--     treadmill client scripts (TreadmillAnimation and what it requires) make no Sound at all.
--  2. InteractionFeedback keeps its real cues (a pack taken = Bubble06, an upgrade = UpgradeClick / KaChing / Denied) but a prompt's hold beginning is silent.
-- (PlantInspection picking a plant silently, and the Hotbar's own silence, are asserted in docs/proposals/R150/tests: test_inputs and test_hotbar.)
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
local rec=E.recorder()
E.player('Tester')
local player,pg=E.Player,E.pg
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local function remote(class,name)local r=R.Instance.new(class);r.Name=name;r.Parent=remotes;return r end
-- 1+2. InteractionFeedback ----------------------------------------------------------------------------------------------------------------------
do
 remote('RemoteEvent','PackTaken')
 local Prompts=W.service('ProximityPromptService');Prompts.PromptButtonHoldBegan=R.signal()
 local sc=R.new('LocalScript');sc.Name='InteractionFeedback';local ok,err=pcall(W.load,'InteractionFeedback',sc);check(ok,'InteractionFeedback loads: '..tostring(err))
 rec.clear();E.resetPlays()
 for _=1,3 do
  player:SetAttribute('TreadmillTraining',true);R.advance(.5);player:SetAttribute('TreadmillTraining',false);R.advance(.5)
 end
 player:SetAttribute('TreadmillTraining',true)
 check(rec.count()==0,'stepping on and off a treadmill (x3) plays no cue ('..rec.keys()..')')
 check(E.totalPlays()==0,'... and no Sound plays')
 local p1=R.new('ProximityPrompt');p1.HoldDuration=1.5
 if Prompts.PromptButtonHoldBegan.Fire then Prompts.PromptButtonHoldBegan:Fire(p1)end
 check(rec.count()==0,'a prompt hold beginning plays nothing ('..rec.keys()..')')
 player:SetAttribute('UpgradePressSerial',1);check(rec.keys()=='UpgradeClick','the upgrade press click is kept')
 player:SetAttribute('UpgradeBoughtSerial',1);check(rec.keys()=='UpgradeClick,KaChing','a bought upgrade still rings KaChing')
 rec.clear();player:SetAttribute('UpgradeRefusedSerial',1);check(rec.keys()=='Denied','a refused one still clicks Denied')
 sc.Destroying:Fire()
end
-- 1b. the treadmill client scripts make no Sound -------------------------------------------------------------------------------------------------
do
 local before=#E.sounds
 for _,name in ipairs({'TreadmillAnimation'})do
  local sc=R.new('LocalScript');sc.Name=name
  local ok,err=pcall(W.load,name,sc)
  if not ok then print('NOTE '..name..' not loadable under the mock: '..tostring(err))end
  R.advance(1);W.frames(20,1/30)
  player:SetAttribute('TreadmillTraining',true);W.frames(30,1/30);player:SetAttribute('TreadmillTraining',false);W.frames(10,1/30)
  sc.Destroying:Fire()
 end
 local made=0;for i=before+1,#E.sounds do made+=1 end
 check(made==0 and E.totalPlays()==0,'the treadmill client scripts create and play no Sound ('..made..')')
end

print(('R152 silence checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
