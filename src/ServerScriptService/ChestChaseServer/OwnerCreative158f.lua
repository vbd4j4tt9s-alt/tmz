-- R158f (owner: "give me cmds to test everything, remove restrictions for my cmds, my cmds are absolute, basically give me creative mode"): the owner's creative mode and the
-- test commands for everything new. OwnerUpdateCommands82 dispatches here (X.Actions); the rules are the server's alone (OwnerTestState82 holds creative, in memory, never saved).
--   creative [on|off|status|speed <24-500|off>] [@name]   CREATIVE MODE of one player (default yourself), game owner only. While it is on, for that player: no cooldowns (bat swing,
--                shovel, treadmill bonus roll), keepers / The Darkened / bats / lightning / holes cannot hit them (RagdollService.CanHit), the Bag has no 200 cap, plants ripen at once and
--                regrow at once, a walk speed of 200, fly (/test fly), MovementGuard / SecurityGate / BatLagComp let them be, and every pack they open is a TEST open (never announced,
--                never on the hub boards). The steal hold is instant and the bat has no cooldown on their screen (StudioTestClient, BatClient read the attribute CreativeMode158f).
--                Robux purchases stay real.
--   droppack [biome] [tier 1-6] [seconds]    a TEST pack lying at the target's feet, as a dropped pack (the R158b outline, marker and beam).
--   tutorial reset | step <1-10> | done [@name]    (game owner only) the NEW wordless tutorial of that player: restarts at step 1 (TutorialDone, the mask and the saved 10-second-fruit flags
--                Fast / FastCrop are cleared; the client starts at once), jumps to a step, or finishes it (the free Forest pack comes the first time, as after a real finish).
--   newplayer [@name]   (game owner only) the whole new-player experience again: tutorial reset + the starter Verity gift owed again + the free Forest starter pack flag cleared + the
--                Void pedestal claim cleared (the Studio-only gates are open for the owner).
--   verityevent on|off|auto|status   (game owner only, this server) starts / stops the limited event (LimitedEvent: Verity, the starter gift, the Mech pack sale) by an attribute on the module.
--   walls    the R158 track walls, the outer track models and the volcano: what loaded and from where.        batstats   the bat hit claim counters (BatSwing Claims_*).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Access=require(script.Parent.OwnerCommandAccess)
local function isOwner(p)local f=Access.IsOwner;return type(f)=='function'and f(p)==true end -- R158f: the game owner (a test's stand-in access module without IsOwner has no owner: the limits stay)
local State=require(script.Parent.OwnerTestState82)
local M={}
M.Actions={creative=true,droppack=true,tutorial=true,newplayer=true,verityevent=true,walls=true,batstats=true}
M.OwnerOnly={creative=true,tutorial=true,newplayer=true,verityevent=true}
M.Biomes={forest=1,desert=2,snow=3,lava=4,crystal=5,jungle=6,storm=7}
local function key(v)return tostring(v or''):lower():gsub('[^%w]','')end
local function number(s,lo,hi,whole)
 local n=tonumber(s);if not n or n~=n or math.abs(n)==math.huge or n<lo or n>hi or(whole and n%1~=0)then return nil end
 return n
end
local function applySpeed(ctx,p)
 local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid')
 if h and ctx.Bases then ctx.Bases:_applyPhysicalSpeed(p,h,ctx.Data:GetOrCreateSpeedValue(p).Value)end
 pcall(function()require(script.Parent.MovementGuard).Reset(p)end)
end
-- Every crop of the player ripe now (the same as /test growall): returns how many plants.
function M.Ripen(ctx,p)
 local data=ctx.Data;local garden=data.Gardens and data.Gardens[p];if not garden then return 0 end
 local now=os.time();local n=0
 for _,list in pairs(garden.Plots or{})do for _,crop in ipairs(list)do
  crop.PlantedAt=now-1000;crop.MatureAt=now;crop.ReadyAt=now;crop.FruitStates=nil;crop.PickedMask=0
  crop.HarvestCycle=((crop.HarvestCycle or 0)+1)%1000000000;n+=1
 end end
 data:MarkDirty(p);if data._gardenChanged then data:_gardenChanged(p)end;if data.QueueGardenSave then data:QueueGardenSave(p)end
 local base=ctx.Bases and ctx.Bases:GetPlayerBase(p);if base and ctx.Chests then ctx.Chests:RenderGarden(base,p)end
 return n
end
-- creative -------------------------------------------------------------------------------------------------------------------------------------------------
local function creativeText(p)
 if not State.Creative(p)then return'@'..p.Name..': creative mode is OFF.'end
 local speed=State.GetCreativeSpeed(p)
 return'@'..p.Name..': creative mode is ON (walk speed '..(speed and tostring(speed)or'your earned speed')..'). No cooldowns, nothing can hit you, no Bag cap, plants ripen at once, /test fly to fly, /test creative off to end it. Session only: leaving the game ends it.'
end
local function creative(ctx,p,a)
 local sub=a[1]and tostring(a[1]):lower()or'toggle'
 if sub=='status'then return true,creativeText(p)end
 if sub=='speed'then
  if not State.Creative(p)then return false,'Turn creative on first: /test creative on.'end
  local word=a[2]and tostring(a[2]):lower()
  local n=word=='off'and nil or number(word,24,500)
  if#a~=2 or(word~='off'and not n)then return false,'Use creative speed <24-500> or creative speed off (your earned speed).'end
  State.SetCreativeSpeed(p,n);applySpeed(ctx,p)
  return true,n and('Creative walk speed: '..n..'.')or'Creative keeps your earned walk speed.'
 end
 if sub~='on'and sub~='off'and sub~='toggle'or#a>1 then return false,'Use creative [on|off|status|speed <24-500|off>] [@username].'end
 local want=sub=='on'or(sub=='toggle'and not State.Creative(p))
 if want==State.Creative(p)then return true,creativeText(p)end
 State.SetCreative(p,want)
 applySpeed(ctx,p)
 if want then
  local n=M.Ripen(ctx,p)
  return true,creativeText(p)..(n>0 and(' Your '..n..' plants are ripe.')or'')
 end
 return true,creativeText(p)
end
-- droppack ---------------------------------------------------------------------------------------------------------------------------------------------------
local function dropPack(ctx,p,a)
 if not ctx.Chase or type(ctx.Chase.TestDropPack)~='function'then return false,'Dropped packs are not running in this server.'end
 if#a>3 then return false,'Use droppack [biome] [tier 1-6] [seconds].'end
 local stage=1;if a[1]~=nil then stage=M.Biomes[key(a[1])]or number(a[1],1,7,true)end
 local tier=a[2]==nil and 3 or number(a[2],1,6,true);local seconds=a[3]==nil and 60 or number(a[3],5,600)
 if not stage or not tier or not seconds then return false,'Use droppack [forest|desert|snow|lava|crystal|jungle|storm] [tier 1-6] [seconds 5-600].'end
 return ctx.Chase:TestDropPack(p,stage,tier,seconds)
end
-- tutorial / newplayer ---------------------------------------------------------------------------------------------------------------------------------------
-- The published tutorial step (BeginnerGuide.Step) for a step 1-10 the owner asks for: 1-3 = the steal, 4 open, 5-6 plant, 7-8 grow / harvest, 9 sell, 10 treadmill.
local STAGE={[1]=1,[2]=1,[3]=1,[4]=4,[5]=6,[6]=6,[7]=7,[8]=7,[9]=9,[10]=10}
local function stateFor(stage)
 local G=require(RS:WaitForChild('BeginnerGuide'));local B=G.Bits
 local mask=B.Begin
 for _,row in ipairs({{1,'Pack'},{4,'Seed'},{6,'Plant'},{7,'Harvest'},{9,'Sell'}})do
  if stage>row[1]then mask=bit32.bor(mask,B[row[2]])end
 end
 return{Version=1,Mask=mask,Done=false}
end
local function setTutorial(ctx,p,state)
 local data=ctx.Data;local premium=data:GetPremium(p)
 premium.Tutorial=state
 data:PublishTutorial(p);data:MarkDirty(p);if data.QueueGardenSave then data:QueueGardenSave(p)end
 p:SetAttribute('TutorialRestart158f',(p:GetAttribute('TutorialRestart158f')or 0)+1) -- (the tutorial on that player's screen starts over from its first look)
end
local function tutorialDone(ctx,p)
 local G=require(RS:WaitForChild('BeginnerGuide'))
 setTutorial(ctx,p,{Version=1,Mask=255,Done=true})
 local data=ctx.Data;local gift=type(data.GrantStarterPack)=='function'and data:GrantStarterPack(p)or nil
 if gift then
  pcall(function()ctx.Chests:SyncTools(p)end)
  if data.Notifications then pcall(function()data.Notifications:Show(p,G.StarterPack.Notice,Color3.fromRGB(150,255,110),5)end)end
 end
 return gift~=nil
end
local function tutorial(ctx,p,a)
 local data=ctx.Data
 if not data:IsLoaded(p)or type(data.PublishTutorial)~='function'then return false,'Wait for the player data to load.'end
 local sub=a[1]and tostring(a[1]):lower()
 if sub=='reset'and#a==1 then
  setTutorial(ctx,p,stateFor(1))
  return true,'@'..p.Name..': the tutorial starts again at step 1 (TutorialDone, the steps done and the 10-second-fruit flags are cleared; the red arrow shows at once). Normal players still cannot replay it.'
 elseif sub=='step'and#a==2 then
  local n=number(a[2],1,10,true);if not n then return false,'Use tutorial step <1-10>.'end
  setTutorial(ctx,p,stateFor(STAGE[n]))
  local needs={[4]='a pack in the Bag (/test pack forest)',[5]='a seed in the Bag (/test seeds forest)',[6]='a seed in the Bag (/test seeds forest)',[7]='a planted crop (/test plants all)',[8]='a planted crop (/test plants all)',[9]='fruit to sell (/test harvestall)'}
  return true,'@'..p.Name..': the tutorial is at step '..n..(STAGE[n]~=n and(' (it shows steps 1-3 / 5-6 / 7-8 by where you stand: published step '..STAGE[n]..')')or'')..'.'..(needs[n]and(' Hold '..needs[n]..' or the tutorial moves on by itself.')or'')
 elseif sub=='done'and#a==1 then
  local gave=tutorialDone(ctx,p)
  return true,'@'..p.Name..': the tutorial is finished.'..(gave and' The free Forest pack was given (once per account).'or'')
 end
 return false,'Use tutorial reset, tutorial step <1-10> or tutorial done [@username].'
end
local function newPlayer(ctx,p,a,requester)
 if#a~=0 then return false,'Use newplayer [@username].'end
 local data=ctx.Data
 if not data:IsLoaded(p)or type(data.PublishTutorial)~='function'then return false,'Wait for the player data to load.'end
 local lines={'WARNING: this reset @'..p.Name..'\'s profile for the new-player experience (saved): the tutorial, the starter Verity gift flag, the free Forest starter pack flag and the Void pedestal claim.'}
 setTutorial(ctx,p,stateFor(1))
 lines[#lines+1]='Tutorial: starts again at step 1.'
 local premium=data:GetPremium(p);premium.StarterPack=nil;p:SetAttribute('StarterPackClaimed',false)
 data:MarkDirty(p);if data.QueueGardenSave then data:QueueGardenSave(p)end
 lines[#lines+1]='Free Forest starter pack: flag cleared (you get it again when the tutorial finishes).'
 local okV,V=pcall(function()return require(script.Parent.StarterVerity158d)end)
 if okV and V.Current then local _,text=V.Command(nil,p,{'reset'},requester)lines[#lines+1]='Starter Verity gift: '..tostring(text)else lines[#lines+1]='Starter Verity gift: the gift service is not running in this server.'end
 local okG,Void=pcall(function()return require(script.Parent.VoidGiveaway152)end)
 if okG and Void.Current then
  local ok,text=Void.Command(nil,p,{'reset','me'},requester)
  lines[#lines+1]='Void pedestal claim: '..tostring(text)..(ok and' (this edited the shared count)'or'')
 else lines[#lines+1]='Void pedestal claim: the giveaway is not running in this server.'end
 return true,table.concat(lines,'\n')
end
-- verityevent ------------------------------------------------------------------------------------------------------------------------------------------------
local function verityEvent(_,_,a)
 local module=RS:FindFirstChild('LimitedEvent');if not module then return false,'The limited event module is missing.'end
 local Limited=require(module);local sub=a[1]and tostring(a[1]):lower()or'status'
 if#a>1 or(sub~='on'and sub~='off'and sub~='auto'and sub~='status')then return false,'Use verityevent on, off, auto or status.'end
 if sub=='on'then module:SetAttribute('EndsAtOverride',os.time()+30*86400)
 elseif sub=='off'then module:SetAttribute('EndsAtOverride',os.time()-60)
 elseif sub=='auto'then module:SetAttribute('EndsAtOverride',nil)end
 local override=module:GetAttribute('EndsAtOverride')
 return true,'Limited event (Verity, the new-player Verity gift, the Mech pack sale): '..(Limited.Active(os.time())and'RUNNING, '..Limited.Text(Limited.Left(os.time()))..' left'or'OVER')..(override and' (set by /test verityevent for this server; verityevent auto goes back to the real end date)'or' (the real end date)')..'.'
end
-- walls / batstats -------------------------------------------------------------------------------------------------------------------------------------------
local STREAMS={'^VolcanoMagmaChannel','^MoltenCrater$','^ContinuousLavaRiver$','^IrregularMagmaPools$','^MainMagmaPool$','^LavaPool','^Lava pool$','^LavaRiver','^Pool shore$'}
local function countParts(inst)local n=inst:IsA('BasePart')and 1 or 0;for _,d in ipairs(inst:GetDescendants())do if d:IsA('BasePart')then n+=1 end end;return n end
local function walls(ctx)
 local map=ctx.Map and ctx.Map.MapRoot;if not map then return false,'The map is not ready.'end
 local okW,Walls=pcall(function()return require(script.Parent.TrackWalls158)end)
 if not okW then return false,'TrackWalls158 is not available: '..tostring(Walls)end
 local lines={'R158 walls and outer track (generation '..tostring(Walls.Generation)..'):'}
 local labels={};for label in pairs(Walls.Folders)do labels[#labels+1]=label end;table.sort(labels)
 for _,label in ipairs(labels)do
  local folderName=Walls.Folders[label];local f=map:FindFirstChild(folderName)
  lines[#lines+1]=string.format('  %s (%s): %s',folderName,label,f and(countParts(f)..' parts, build '..tostring(f:GetAttribute('Version')))or'MISSING')
 end
 local backdrops=map:FindFirstChild(Walls.Folders.Backdrops)
 local okL,Loader=pcall(function()return require(script.Parent.OuterTrackLoader158)end)
 if okL and Loader then
  lines[#lines+1]='  Outer track models: '..(backdrops and backdrops:GetAttribute('Ready')and('loaded, '..tostring(backdrops:GetAttribute('ModelParts'))..' parts')or'NOT finished loading (or not started)')
  local names={};for k in pairs(Loader.Status or{})do names[#names+1]=k end;table.sort(names)
  for _,k in ipairs(names)do
   local st=Loader.Status[k]
   lines[#lines+1]=string.format('    %s: %d placed, %d parts, from %s%s',k,st.Placed or 0,st.Parts or 0,tostring(st.Source or'(nothing)'),st.Note and('; '..tostring(st.Note))or'')
  end
  if#names==0 then lines[#lines+1]='    (no model has been placed yet)'end
  local cached=Loader.Cache and Loader.Cache.LavaVolcano
  lines[#lines+1]='  Volcano model: '..(type(cached)=='table'and tostring(cached.Source)or cached==false and('none ('..tostring(Loader.Cache['LavaVolcano/why'])..')')or'not asked for yet')
 end
 local landmarks=map:FindFirstChild('MythicLandmarks');local volcano=landmarks and landmarks:FindFirstChild('Biome4_Landmark')
 lines[#lines+1]='  Lava biome volcano on the map: '..(volcano and(volcano:GetAttribute('Volcano158')and'the owner\'s volcano, scale '..tostring(volcano:GetAttribute('Scale'))or'the OLD cone')or'none')
 local left=0
 for _,root in ipairs({map:FindFirstChild('PresentationV128'),map:FindFirstChild('EnvironmentPolishV127'),volcano})do
  if root then for _,c in ipairs(root:GetChildren())do for _,pat in ipairs(STREAMS)do if c.Name:match(pat)then left+=countParts(c);break end end end end
 end
 lines[#lines+1]='  Lava streams and pools left: '..left..' parts'..(left==0 and' (gone, as it should be)'or' (they should be 0)')
 return true,table.concat(lines,'\n')
end
local function batStats(ctx)
 local bats=ctx.Chase and ctx.Chase.Bats;if not bats then return false,'The bats are not running in this server.'end
 local names,total={},0
 for reason,n in pairs(bats.Counts or{})do names[#names+1]=reason;total+=n end
 table.sort(names,function(x,y)return(bats.Counts[x]or 0)>(bats.Counts[y]or 0)or((bats.Counts[x]or 0)==(bats.Counts[y]or 0)and x<y)end)
 local lines={string.format('Bat swings accepted: %d | hit claims: %d (BatSwing Claims_*, this server since it started)',bats.Serial or 0,total)}
 for _,reason in ipairs(names)do lines[#lines+1]=string.format('  %s: %d',reason,bats.Counts[reason])end
 if#names==0 then lines[#lines+1]='  (no claim yet)'end
 return true,table.concat(lines,'\n')
end
function M.Execute(ctx,p,action,a,requester)
 requester=requester or p
 if M.OwnerOnly[action]and not isOwner(requester)then return false,'/test '..action..' is for the game owner only (admins cannot use it).'end
 local ok,okay,text=pcall(function()
  if action=='creative'then return creative(ctx,p,a)
  elseif action=='droppack'then return dropPack(ctx,p,a)
  elseif action=='tutorial'then return tutorial(ctx,p,a)
  elseif action=='newplayer'then return newPlayer(ctx,p,a,requester)
  elseif action=='verityevent'then return verityEvent(ctx,p,a)
  elseif action=='walls'then return walls(ctx)
  elseif action=='batstats'then return batStats(ctx)end
  return false,'Unknown command.'
 end)
 if not ok then warn('[R158f] /test '..action..': '..tostring(okay));return false,'Command failed; check server Output.'end
 return okay,text
end
return M
