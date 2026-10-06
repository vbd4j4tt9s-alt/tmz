--!nocheck
-- R153 (owner: "make it fixed visibly so when players pull a cosmic seed from a void pack they are still reminded of how rare it is"): the REVEAL CARD half. The real RarePullCinematic
-- (director) with RarePullCard / RarePullScenes / RarePullRules on the Roblox mock plays the reveal of every seed that can be pulled (54: the Common..Mythic seed card and the
-- Secret / Cosmic / King story scenes) from a held pack whose own tooltip lists that seed at "1/12" (the number a Cosmic from a Void pack used to read) and whose catalog entry
-- carries BaseChance = 1/12 too: the "1 in N" the card slams in is the seed's ONE fixed chance (SeedRarity153), the same text as the Index, the chat and the plaque. The count-up
-- ends on exactly that text. A card of a seed the module cannot price (no module) falls back to the entry's BaseChance, never to the pack's tooltip.
-- Prints SURFACE lines (card): run_seed_rarity.sh compares them with the Index, chat and plaque tests'.
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
function R.Inst:Play()local own=rawget(self,'_props').Play;if own then return own(self)end end
function R.Inst:Stop()local own=rawget(self,'_props').Stop;if own then return own(self)end end
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Packs=W.module('SeedPackRules');local Canon=W.module('SeedRarity153');local Visuals=W.module('SeedPackVisuals')
local cam=W.workspace.CurrentCamera
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear()
 cam=W.workspace.CurrentCamera
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true
 X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 X.player:SetAttribute('RarePullPreview',nil)
 R.advance(4)
end
-- the real SeedInfo, first: name and "N" for a held pack whose tooltip says 1/12
local function tooltip(spec)return 'Void Pack\n'..spec.name..': 1/12\n'..spec.name..' Seed: 1/12\nSomething Else: 1/2'end
do
 local spec=Packs.SeedDesignById.PolarStarbloomSeed
 X.seed(spec.id,100/12)
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='info',Stage=7},nil);tool.ToolTip=tooltip(spec)
 local name,odds=M.SeedInfo(spec.id,tool)
 check(odds=='1M','SeedInfo: a Cosmic whose held pack says 1/12 and whose catalog entry says 1/12 reads "'..tostring(odds)..'" (its fixed 1/1M)')
 check(M.SeedInfo(spec.id,nil)==name and select(2,M.SeedInfo(spec.id,nil))=='1M','... with no held pack the same')
 local _,none=M.SeedInfo('NoSuchSeed',tool)
 check(none==nil,'a seed nobody knows has no "1 in N"')
end
local function play(spec)
 reset();E.resetPlays()
 local rarity=Packs.GetRarity(spec.id);local rank=Packs.Rarities[rarity].Rank
 if not W.RS.ChestChaseRemotes.SeedCatalog:FindFirstChild(spec.id)then X.seed(spec.id,100/12)end
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',spec.id);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='p'..spec.id,Stage=7},nil);tool.ToolTip=tooltip(spec)
 local run=M.Start({Rank=rank,SeedId=spec.id,At=W.workspace:GetServerTimeNow(),Bag=bag,Tool=tool,Mutation='None'})
 if not run then check(false,spec.id..': the reveal starts');return nil end
 local tl=run.TL;local t0=R.clock;local text,finalAt
 local lastT=run.Kind=='Ladder'and tl.Out or tl.FloatEnd-.1 -- (as the R151 cinematic suite reads it: after the slam, before the card fades / the seed is down)
 X.run(tl.Length+.3,1/30,function(now)
  local t=now-t0
  local gui=X.pg:FindFirstChild('RarePullReveal');local odds=gui and X.find(gui,'Odds')
  if odds and t>tl.Odds+.05 and t<lastT then text=odds.Text;finalAt=t end
 end)
 M.Abort('test');bag:Destroy()
 return text,run.Odds,rank,run.Kind
end
local all=Canon.All()
local bad,shown,kinds={},0,{}
for _,r in ipairs(all)do
 local spec=Packs.SeedDesignById[r.Id]
 local text,runOdds,rank,kind=play(spec)
 kinds[kind or'?']=(kinds[kind or'?']or 0)+1
 local want='1 in '..tostring(Canon.Count(r.Id))
 if text then shown+=1 end
 if text~=want or runOdds~=Canon.Count(r.Id)then bad[#bad+1]=r.Id..' ('..tostring(kind)..') card says "'..tostring(text)..'" run.Odds='..tostring(runOdds)..' want "'..want..'"'end
 print('SURFACE card '..r.Id..' '..tostring(text and text:gsub('^1 in ','1/')or nil))
end
check(shown==54,'the "1 in N" of every one of the 54 seeds was on the card ('..shown..')')
check(#bad==0,'every card slams the seed\'s fixed chance, though the held pack and the catalog say 1/12: '..table.concat(bad,'; '))
check((kinds.Ladder or 0)>20 and(kinds.Scene or 0)>10,'(both presentations were played: the ladder card for Common..Mythic: '..tostring(kinds.Ladder)..'; the story scenes for Secret / Cosmic / King: '..tostring(kinds.Scene)..')')
-- the count-up ends on the exact text: CountText(final,1) = "1 in " .. final
check(L.CountText('1M',1)=='1 in 1M'and L.CountText('1.67B',1)=='1 in 1.67B','CountText ends on the exact text it is given (unchanged)')
print(('R153 seed rarity (card): %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
