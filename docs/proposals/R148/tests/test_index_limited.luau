--!nocheck
-- R148 (owner: "this index section should also be combined and named LIMITED; create an image for this limited section in the index",
-- about the MECH 12 / 12 and VERITY 0 / 2 tabs): the real ChestIndex of this checkout on the Roblox mock, held against the R147 release's
-- script (ChestIndexBase = git show 23235ce:...; nine tabs, MECH and VERITY separate).
--  1. eight tabs, LIMITED last, no MECH / VERITY tab; LIMITED has its own purple tab and the BiomeArtwork icon "Limited";
--  2. the tab counts both categories together the way every tab counts (seeds + plants found, out of two per seed: that is why VERITY, one
--     seed, read 0 / 2 and MECH's six seeds 12 / 12): equal to the old tabs' sums in every state, and FOUND is unchanged;
--  3. the grid lists the six Mech seeds, then the Verity seed, as the old tabs listed them (same cards, chips and order);
--  4. two reward rows, MECH SET and VERITY, each with its own progress and halfway / completion gems, claiming ClaimBiomeHalf / ClaimBiome
--     with category 8 or 9 as the old tabs' single bar did (state for state, amounts from BalanceValues81), one claim at a time;
--  5. the LIMITED tab dot, the INDEX badge and the MENU "!" light up for a reward of either category;
--  6. the tab row and the LIMITED panel fit from a 360 px phone to 1920x1080;
--  7. the other seven tabs are what they were (tabs, panels, rewards, claims, alerts identical to the R147 script, screen by screen);
--  8. the Limited icon: BiomeIconData.Limited / ArtworkFallbackData89.Limited have the format of the other logos (and nothing else of those
--     two modules changed); the REAL ArtworkRuntime87 decodes it (Base64 -> zstd -> a 96x96 EditableImage; the zstd step is done by
--     check_limited_icon.py with the real zstd library and its raw pixels are the sidecar here) and the fallback strips draw without it.
local W=require('./world');local R=W.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function rgbKey(c)return table.concat({rgb(c)},',')end
-- Mock gaps for the seed builders (as in the R147 / R137 tests).
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=148;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
local calls={};local hold=false;local held=nil
function req.InvokeServer(_,action,value)
 calls[#calls+1]={action,value}
 if hold then hold=false;held=coroutine.running();coroutine.yield()end -- (a held reply: the claim stays "busy" until it is resumed)
 return {Success=true,Message='Claimed!'}
end
local played={};W.stub('InteractionAudio',{Play=function(k)played[#played+1]=k;return true end,Preload=function()end})
local Rules=W.module('SeedPackRules');local Tuning=W.module('BalanceValues81')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local seedsOf={}
for stage,defs in ipairs(config.SeedCatalogByStage)do for index,seed in ipairs(defs)do
 if not Rules.IsRetired(seed.Id)then
  local entry=R.new('Folder');entry.Name=seed.Id;entry:SetAttribute('SeedId',seed.Id);entry:SetAttribute('DisplayName',seed.Name)
  entry:SetAttribute('Rarity',Rules.GetRarity(seed.Id))
  local at=Rules.ObtainableStage(seed.Id)or stage;entry:SetAttribute('BaseChance',Rules.SeedOdds(config,at,'Pack01',1)[seed.Id])
  entry:SetAttribute('Stage',at);entry:SetAttribute('SeedIndex',index);entry.Parent=catalog
  seedsOf[at]=seedsOf[at]or{};table.insert(seedsOf[at],seed.Id)
 end
end end
local MECH,VERITY=seedsOf[8],seedsOf[9]
check(#MECH==6 and #VERITY==1 and VERITY[1]=='VeritySeed','(the catalog fixture: six Mech seeds in category 8 and the Verity seed alone in 9; "MECH 12 / 12" is those 6 seeds + 6 grown)')
local seedsFolder=R.new('Folder');seedsFolder.Name='DiscoveredSeeds';seedsFolder.Parent=player
local plantsFolder=R.new('Folder');plantsFolder.Name='DiscoveredPlants';plantsFolder.Parent=player
local function found(folder,id,cash)local v=R.new('BoolValue');v.Name=id;v.Value=true;if cash then v:SetAttribute('RewardCash',cash)end;v.Parent=folder end
local function resetState()
 seedsFolder:ClearAllChildren();plantsFolder:ClearAllChildren()
 for st=1,9 do for _,p in ipairs({'IndexBiomeReward','IndexBiomeHalfReward','IndexBiomeBackpay'})do player:SetAttribute(p..st,nil)end end
 calls={};played={};hold=false;held=nil
end
-- Layout emulation (absolute rects from UDim2 + AnchorPoint + UISizeConstraint, as the R113 inventory test and the R147 Index section).
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  if s and p then
   local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
   local lim=c:FindFirstChildOfClass('UISizeConstraint');if lim and lim.MaxSize then w=math.min(w,lim.MaxSize.X);h=math.min(h,lim.MaxSize.Y)end
   local x=px+p.X.Scale*pw+p.X.Offset-a.X*w;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h
   set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
   lay(c,x,y,w,h)
  end
 end end
end
local screen=R.Vector2.new(1280,720)
local function frames(n)
 for _=1,n do
  for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')and g.Name=='ChestIndexGui'then if g.AbsoluteSize~=screen then g.AbsoluteSize=screen end;lay(g,0,0,screen.X,screen.Y)end end
  W.frames(1)
 end
end
local function resize(w,h)screen=R.Vector2.new(w,h);frames(4)end
local function loadIndex(name)
 local s=R.new('LocalScript');s.Name='ChestIndex';W.load(name,s);frames(5);pg:SetAttribute('SeedMenu',nil);frames(2);pg:SetAttribute('SeedMenu','Index');frames(20)
 return pg:FindFirstChild('ChestIndexGui')
end
local function tabOf(gui,key)return gui:FindFirstChild('Biome'..key,true)end
local function toggleOf()return pg:FindFirstChild('IndexButton',true)end
local function hubOf()local n=pg:FindFirstChild('GardenNavigation');return n and n:FindFirstChild('MenuButton')end
local function badgeText(b)return b and b.Visible and b.Count.Text or'-'end
local function indexBadge()return badgeText(toggleOf():FindFirstChild('RewardBadge'))end
local function menuAlert()return badgeText(hubOf():FindFirstChild('IndexRewardAlert'))end
local function dotOf(gui,key)local t=tabOf(gui,key);local d=t and t:FindFirstChild('RewardDot');return d~=nil and d.Visible==true end
local function ringOf(b)return b:FindFirstChild('BrightOutline')end
local function norm(s)return(s:gsub('%s+',' '))end -- (the mock's text fitter adds line breaks)
-- A reward gem (the bar's two gems, the rows' pills): everything the player can see or press.
local function gemView(b)
 local rim=b:FindFirstChild('RewardRim')or b:FindFirstChildOfClass('UIStroke');local art=b:FindFirstChild('RewardArt',true);local amt=b:FindFirstChild('RewardAmount')
 return{Active=b.Active==true,Interactable=b.Interactable==true,Auto=b.AutoButtonColor==true,Ready=b:GetAttribute('RewardReady')==true,Claimed=b:GetAttribute('RewardClaimed')==true,Gems=b:GetAttribute('RewardGems'),
  Amount=amt and amt.Text or'',AmountColor=amt and rgbKey(amt.TextColor3)or'',Rim=rim and rgbKey(rim.Color)or'',Bg=rgbKey(b.BackgroundColor3),Icon=art and string.format('%.2f',art.GroupTransparency or -1)or''}
end
local function gemKey(v)return string.format('active=%s inter=%s auto=%s ready=%s claimed=%s gems=%s amount=%s/%s rim=%s bg=%s icon=%s',tostring(v.Active),tostring(v.Interactable),tostring(v.Auto),tostring(v.Ready),tostring(v.Claimed),tostring(v.Gems),v.Amount,v.AmountColor,v.Rim,v.Bg,v.Icon)end
local function seedCards(gui)
 local out={};for _,c in ipairs(gui:FindFirstChild('SeedCards',true):GetChildren())do if c:IsA('TextButton')then out[#out+1]=c end end
 table.sort(out,function(a,b)return a.LayoutOrder<b.LayoutOrder end);return out
end
-- Everything a card shows (its own LayoutOrder aside), so a card in LIMITED can be compared with the same card on the old MECH / VERITY tab.
local function cardKey(c)
 local out={c.Name}
 for _,d in ipairs(c:GetDescendants())do
  -- (a King card's glow core breathes with the card scheduler, so its transparency is not part of the comparison)
  local t=d._props.Text;local a=d.Name~='Core'and d._props.BackgroundTransparency or nil
  -- (R148 follow-up: the CLAIM pill's amount is written by OddsText85.Whole now, "$4,800" where the R147 script wrote "$4800": the amount is
  -- compared separately below, everything else of the pill - and of the card - is still compared)
  if type(t)=='string'and t:find('^CLAIM %$')then t='CLAIM $#'end
  out[#out+1]=d._class..':'..d.Name..':'..(t and tostring(t)or'')..':'..(a and string.format('%.2f',a)or'')..':'..(d._props.BackgroundColor3 and rgbKey(d._props.BackgroundColor3)or'')
 end
 return table.concat(out,'|')
end
local function u2(v)return string.format('%.2f/%.2f/%.2f/%.2f',v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset)end
local SIZES={{360,640},{390,844},{412,915},{640,360},{768,1024},{1024,768},{1280,720},{1366,768},{1920,1080}}
local BIOMES={1,6,2,3,5,4,7}
-- Every tab 1..7 on every screen: its size, colour, children, and what the open panel shows (the R147 Index test's "6f").
local function sizeSnapshots(gui)
 local out={}
 for _,sz in ipairs(SIZES)do
  resize(sz[1],sz[2]);local k=sz[1]..'x'..sz[2];out[k]={}
  for _,key in ipairs(BIOMES)do
   tabOf(gui,key).Activated:Fire();frames(4)
   local lines={};local b=tabOf(gui,key)
   lines[#lines+1]=table.concat({tostring(b.Size.X.Offset),tostring(b.Size.Y.Offset),tostring(b.LayoutOrder),rgbKey(b.BackgroundColor3),tostring(b:GetAttribute('BiomeName'))},'|')
   -- R151: the tab's red dot is NotifyBadge151 now (a polished badge that sits fully inside its tab, size and position on purpose different from the R138 dot's): it is compared by
   -- name and visibility; test_index_packs.luau (docs/proposals/R151/tests) holds its geometry
   for _,c in ipairs(b:GetChildren())do local dot=c.Name=='RewardDot';lines[#lines+1]=c._class..':'..c.Name..':'..(not dot and c._props.Size and u2(c._props.Size)or'')..':'..(not dot and c._props.Position and u2(c._props.Position)or'')..':'..tostring(c._props.Text or'')..':'..tostring(c._props.Visible)end
   for _,n in ipairs({'Progress','CompletionBar','SeedCards','Header','Title','BiomeProgress','MiddleGem','GemReward'})do
    local o=gui:FindFirstChild(n,true);lines[#lines+1]=n..'='..(o and(u2(o.Size)..'|'..u2(o.Position)..'|'..tostring(o._props.Text or'')..'|'..tostring(o._props.Visible))or'-')
   end
   local cs={};for _,c in ipairs(seedCards(gui))do cs[#cs+1]=c.Name..':'..c.LayoutOrder end;lines[#lines+1]='cards='..table.concat(cs,',')
   out[k][key]=table.concat(lines,'\n')
  end
 end
 return out
end
-- One run over the biome tabs: finds, half / full completions, claims, backpay, server attributes, cash rewards: every state as a string.
local function biomeScenario(gui)
 resetState();local snaps={}
 local function snap(label)
  local lines={label}
  for _,k in ipairs(BIOMES)do
   local t=tabOf(gui,k);lines[#lines+1]='tab'..k..' '..t.Count.Text..' dot='..tostring(dotOf(gui,k))..' bg='..rgbKey(t.BackgroundColor3)..' ring='..rgbKey(ringOf(t).Color)..'/'..ringOf(t).Thickness
  end
  lines[#lines+1]='found '..norm(gui:FindFirstChild('TotalFound',true).Count.Text)
  lines[#lines+1]='progress '..norm(gui:FindFirstChild('Progress',true).Text)
  lines[#lines+1]='bar visible='..tostring(gui:FindFirstChild('CompletionBar',true).Visible)..' progress visible='..tostring(gui:FindFirstChild('Progress',true).Visible)
  lines[#lines+1]='mid '..gemKey(gemView(gui:FindFirstChild('MiddleGem',true)))
  lines[#lines+1]='end '..gemKey(gemView(gui:FindFirstChild('GemReward',true)))
  lines[#lines+1]='badge '..indexBadge()..' alert '..menuAlert()
  local cs={};for _,c in ipairs(seedCards(gui))do cs[#cs+1]=c.Name..':'..c.LayoutOrder end
  lines[#lines+1]='cards '..table.concat(cs,',')
  snaps[#snaps+1]=table.concat(lines,'\n')
 end
 local function select(k)tabOf(gui,k).Activated:Fire();frames(4)end
 for _,k in ipairs({1,6,2,3,5,4,7})do select(k);snap('select '..k)end
 select(1);local all=seedsOf[1]
 for i=1,3 do found(seedsFolder,all[i]);frames(3)end;snap('forest: 3 seeds')
 for i=1,3 do found(plantsFolder,all[i]);frames(3)end;snap('forest: 3 seeds + 3 plants (half way)')
 gui:FindFirstChild('MiddleGem',true).Activated:Fire();frames(4);snap('forest: half way claimed (reply Success)')
 for i=4,#all do found(seedsFolder,all[i]);frames(3)end;snap('forest: every seed, no plants')
 for i=4,#all do found(plantsFolder,all[i]);frames(3)end;snap('forest: complete')
 gui:FindFirstChild('GemReward',true).Activated:Fire();frames(4);snap('forest: complete claimed')
 select(6);player:SetAttribute('IndexBiomeBackpay6',55);frames(5);snap('jungle: backpay 55 (nothing found)')
 player:SetAttribute('IndexBiomeBackpay6',nil);player:SetAttribute('IndexBiomeHalfReward6',true);frames(5);snap('jungle: half way taken on the server')
 select(2);found(seedsFolder,seedsOf[2][1],12345);frames(5);snap('desert: a seed with a cash reward')
 for _,c in ipairs(seedCards(gui))do if c.Name==seedsOf[2][1]then c.Activated:Fire()end end;frames(3);snap('desert: its CLAIM clicked')
 select(7);for _,id in ipairs(seedsOf[7])do found(seedsFolder,id);found(plantsFolder,id)end;frames(5);snap('storm: complete')
 local o={};for _,c in ipairs(calls)do o[#o+1]=c[1]..'/'..tostring(c[2])end
 snaps[#snaps+1]='calls '..#calls..': '..table.concat(o,',')
 snaps[#snaps+1]='sounds '..table.concat(played,',')
 return snaps
end
-- The old MECH (8) / VERITY (9) tab as a view (tab text, progress, the bar's two gems, dot, badges); and how a click on its gems is made.
local function oldView(gui,stage)
 tabOf(gui,stage).Activated:Fire();frames(4)
 return{Tab=tabOf(gui,stage).Count.Text,Progress=norm(gui:FindFirstChild('Progress',true).Text),Half=gemKey(gemView(gui:FindFirstChild('MiddleGem',true))),End=gemKey(gemView(gui:FindFirstChild('GemReward',true))),
  Dot=dotOf(gui,stage),Badge=indexBadge(),Alert=menuAlert()}
end
local function oldClick(gui,stage,which)tabOf(gui,stage).Activated:Fire();frames(4);gui:FindFirstChild(which=='half'and'MiddleGem'or'GemReward',true).Activated:Fire();frames(4)end
-- The same category in the new LIMITED tab: its row.
local function rowOf(gui,stage)return gui:FindFirstChild('Row'..stage,true)end
local function pillOf(gui,stage,which)return rowOf(gui,stage):FindFirstChild(which=='half'and'HalfClaim'or'EndClaim',true)end
local function newView(gui,stage)
 tabOf(gui,'Limited').Activated:Fire();frames(4)
 return{Tab=nil,Progress=norm(rowOf(gui,stage):FindFirstChild('RowProgress').Text),Half=gemKey(gemView(pillOf(gui,stage,'half'))),End=gemKey(gemView(pillOf(gui,stage,'end'))),
  Dot=dotOf(gui,'Limited'),Badge=indexBadge(),Alert=menuAlert()}
end
local function newClick(gui,stage,which)tabOf(gui,'Limited').Activated:Fire();frames(4);pillOf(gui,stage,which).Activated:Fire();frames(4)end
-- The category scenario: both old tabs and both new rows go through the same states and the same clicks.
local function categoryScenario(stage,view,click,gui)
 resetState();local out={}
 local ids=seedsOf[stage]
 local function snap(label)out[#out+1]={Label=label,View=view(gui,stage)}end
 snap('nothing found')
 found(seedsFolder,ids[1]);frames(4);snap('one seed')
 local half=math.ceil(#ids/2)
 for i=2,half do found(seedsFolder,ids[i]);frames(3)end;frames(2);snap(half..' seeds')
 for i=1,half do found(plantsFolder,ids[i]);frames(3)end;snap('half the seeds and their plants (the halfway point)')
 click(gui,stage,'half');snap('halfway reward claimed (reply Success)')
 for i=half+1,#ids do found(seedsFolder,ids[i]);found(plantsFolder,ids[i]);frames(3)end;snap('complete')
 click(gui,stage,'end');snap('completion reward claimed (reply Success)')
 player:SetAttribute('IndexBiomeBackpay'..stage,77);frames(5);snap('backpay 77 attribute')
 player:SetAttribute('IndexBiomeBackpay'..stage,nil);player:SetAttribute('IndexBiomeReward'..stage,true);player:SetAttribute('IndexBiomeHalfReward'..stage,true);frames(5);snap('server says both taken')
 local cl={};for _,c in ipairs(calls)do cl[#cl+1]=c[1]..'/'..tostring(c[2])end
 out.Calls=table.concat(cl,',');out.Sounds=table.concat(played,',');return out
end
-- Counts in the same few states, old tabs against the new one.
local COUNT_STATES={
 {'nothing found',function()end},
 {'the Verity seed found',function()found(seedsFolder,'VeritySeed')end},
 {'the Verity seed and its plant',function()found(plantsFolder,'VeritySeed')end},
 {'three Mech seeds as well',function()for i=1,3 do found(seedsFolder,MECH[i])end end},
 {'and their plants',function()for i=1,3 do found(plantsFolder,MECH[i])end end},
 {'every Mech seed and plant',function()for i=4,6 do found(seedsFolder,MECH[i]);found(plantsFolder,MECH[i])end end},
}
-- ===============================================================================================================================================
-- Part A: the R147 script. What its tabs 1..7 do (and what its MECH / VERITY tabs do) is the standard the new script is held to.
-- ===============================================================================================================================================
-- (Each stateful run starts from a fresh script: the Index remembers its own claims.)
local function freshOld()resetState();resize(1280,720);return loadIndex('ChestIndexBase')end
local oldGui=freshOld()
check(oldGui and tabOf(oldGui,8)and tabOf(oldGui,9)and not tabOf(oldGui,'Limited'),'(the R147 script has the separate MECH and VERITY tabs: the standard)')
local oldBiome=biomeScenario(oldGui)
local oldSizes=sizeSnapshots(oldGui)
local oldListY={};for _,sz in ipairs(SIZES)do resize(sz[1],sz[2]);tabOf(oldGui,8).Activated:Fire();frames(4);oldListY[sz[1]..'x'..sz[2]]=oldGui:FindFirstChild('SeedCards',true).Position.Y.Offset end
oldGui=freshOld()
local oldMech=categoryScenario(8,oldView,oldClick,oldGui)
local oldVerity=categoryScenario(9,oldView,oldClick,oldGui)
oldGui=freshOld();local oldCounts={}
for i,st in ipairs(COUNT_STATES)do st[2]();frames(6);oldCounts[i]={Mech=tabOf(oldGui,8).Count.Text,Verity=tabOf(oldGui,9).Count.Text,Found=norm(oldGui:FindFirstChild('TotalFound',true).Count.Text)}end
-- cards of the old tabs: three Mech seeds found and grown, one with a cash reward, the Verity seed found with a cash reward
oldGui=freshOld()
for i=1,3 do found(seedsFolder,MECH[i]);found(plantsFolder,MECH[i])end;found(seedsFolder,MECH[4],4800);found(seedsFolder,'VeritySeed',9000);frames(6)
local oldCards={}
for _,stage in ipairs({8,9})do tabOf(oldGui,stage).Activated:Fire();frames(4);for _,c in ipairs(seedCards(oldGui))do oldCards[#oldCards+1]={Name=c.Name,Key=cardKey(c),Stage=stage}end end
local oldBadgeCash=indexBadge()
-- ===============================================================================================================================================
-- Part B: the new script
-- ===============================================================================================================================================
local gui,tabs,layout,lt,panel,limitedRewards,bar,progress
local src=W.B.ChestIndex
local function bindNew()
 resetState();resize(1280,720);gui=loadIndex('ChestIndex')
 tabs=gui:FindFirstChild('BiomeProgress',true);layout=tabs:FindFirstChildOfClass('UIListLayout');lt=tabOf(gui,'Limited');panel=gui:FindFirstChild('IndexPanel')
 limitedRewards=gui:FindFirstChild('LimitedRewards',true);bar=gui:FindFirstChild('CompletionBar',true);progress=gui:FindFirstChild('Progress',true)
 return gui
end
bindNew()
check(gui and gui~=oldGui and gui.Parent==pg,'the new Index loads (and replaces the old gui)')
-- 1. tabs ---------------------------------------------------------------------------------------------------------------------------------------
-- R151: the PACKS tab (BiomePacks, LayoutOrder 0: first in the row; docs/proposals/R151/tests/run_index_packs.sh) is a ninth button of the row; this suite is about the eight SEED tabs.
local list={};for _,c in ipairs(tabs:GetChildren())do if c:IsA('TextButton')and c.Name~='BiomePacks'then list[#list+1]=c end end
table.sort(list,function(a,b)return a.LayoutOrder<b.LayoutOrder end)
local names,order={},{};for _,b in ipairs(list)do names[#names+1]=b:GetAttribute('BiomeName');order[#order+1]=b.Name end
check(#list==8,'eight tabs ('..#list..')')
check(table.concat(names,',')=='FOREST,JUNGLE,DESERT,SNOW,CRYSTAL,LAVA,STORM,LIMITED','the order: Forest, Jungle, Desert, Snow, Crystal, Lava, Storm, LIMITED last ('..table.concat(names,',')..')')
check(table.concat(order,',')=='Biome1,Biome6,Biome2,Biome3,Biome5,Biome4,Biome7,BiomeLimited','the buttons: Biome<stage> for the seven biomes, then BiomeLimited')
check(tabOf(gui,8)==nil and tabOf(gui,9)==nil,'no Biome8 / Biome9 tab: no MECH tab, no VERITY tab')
local anyOld=false;for _,n in ipairs(names)do if n=='MECH'or n=='VERITY'then anyOld=true end end;check(not anyOld,'no tab is named MECH or VERITY')
local layoutOk=true;for i,b in ipairs(list)do if b.LayoutOrder~=i then layoutOk=false end end;check(layoutOk,'LayoutOrder 1..8 in a row')
check(layout and layout.FillDirection.Name=='Horizontal'and layout.SortOrder.Name=='LayoutOrder'and layout.Padding.Offset==8,'the row is one horizontal UIListLayout in LayoutOrder, 8 px apart (as before)')
check(tabs:IsA('ScrollingFrame')and tabs.ScrollingDirection.Name=='X'and tabs.AutomaticCanvasSize.Name=='X','the row scrolls sideways with an automatic canvas (LIMITED, last, stays reachable on a phone)')
local orderLine=src:match('local order=[^\n]*')or''
check(orderLine:find("{7,'STORM'},{LIMITED,'LIMITED'}",1,true)~=nil and not orderLine:find('MECH',1,true)and not orderLine:find('VERITY',1,true),"(source: the seed tabs end {LIMITED,'LIMITED'} (R151: then {PACKS,'PACKS'}) and name no MECH / VERITY tab)")
local _,loops=src:gsub('for stage=1,9 do','')
check(loops>=2,'(source: the stage loops still run to 9, so the reward attributes of categories 8 and 9 are listened to and counted for the alerts) ('..loops..')')
local logo=lt and lt:FindFirstChild('BiomeLogo')
local Prepared=W.module('ArtworkFallbackData89')
check(lt and logo and logo._class=='Frame'and logo:FindFirstChild('SmoothFallback'),'the LIMITED tab has a BiomeLogo from BiomeArtwork, its fallback strips there at once')
local function stripsOf(l)
 local f=l and l:FindFirstChild('SmoothFallback');local n=0
 if f then for _,c in ipairs(f:GetChildren())do if c:IsA('Frame')then n+=1 end end end
 return n
end
check(stripsOf(logo)>0 and stripsOf(logo)==#Prepared.Limited.Strips,'drawn from the Limited fallback data ('..stripsOf(logo)..' strips)')
local KIND={[1]='Forest',[6]='Jungle',[2]='Desert',[3]='Snow',[5]='Crystal',[4]='Lava',[7]='Storm'}
local ownLogos=true;for k,kind in pairs(KIND)do if stripsOf(tabOf(gui,k):FindFirstChild('BiomeLogo'))~=#Prepared[kind].Strips then ownLogos=false end end
check(ownLogos,'the seven biome tabs keep their own BiomeArtwork logos')
local drawn=false;for _,d in ipairs(lt:GetDescendants())do if d.Name=='GeneratedVerity'or d.Name=='Ball'then drawn=true end end;check(not drawn,'(the drawn gold Verity ball is gone from the tab)')
check(src:find('verityLogo',1,true)==nil and src:find('VerityCatalog',1,true)==nil,'(source: no verityLogo / VerityCatalog in the Index any more)')
local function colorOfTab(key)return rgbKey(tabOf(gui,key).BackgroundColor3)end
tabOf(gui,1).Activated:Fire();frames(4)
check(colorOfTab(1)=='80,149,194'and colorOfTab(7)=='73,109,204'and colorOfTab('Limited')=='150,92,235','Forest open (blue), Storm idle (blue), LIMITED idle: its own violet')
lt.Activated:Fire();frames(4)
check(colorOfTab('Limited')=='176,120,255'and colorOfTab(1)=='73,109,204','LIMITED open: a brighter violet, Forest back to blue')
check(ringOf(lt).Thickness==3 and rgbKey(ringOf(lt).Color)=='255,255,255'and ringOf(tabOf(gui,1)).Thickness==2,'the open tab is ringed in white, LIMITED too')
-- 2. the count ---------------------------------------------------------------------------------------------------------------------------------
check(oldCounts[1].Verity=='0 / 2'and oldCounts[#COUNT_STATES].Mech=='12 / 12','(why: the old VERITY tab read 0 / 2 and MECH 12 / 12: every tab counts seeds + plants found out of two per seed)')
bindNew();frames(5)
local function counts(text)local n,d=text:match('^(%d+) / (%d+)$');return tonumber(n),tonumber(d)end
local countsOk,foundOk,detail=true,true,''
for i,st in ipairs(COUNT_STATES)do
 st[2]();frames(6)
 local n,d=counts(tabOf(gui,'Limited').Count.Text);local n8,d8=counts(oldCounts[i].Mech);local n9,d9=counts(oldCounts[i].Verity)
 if n~=n8+n9 or d~=d8+d9 then countsOk=false;detail=detail..' ['..st[1]..': '..tabOf(gui,'Limited').Count.Text..' vs '..oldCounts[i].Mech..' + '..oldCounts[i].Verity..']'end
 if norm(gui:FindFirstChild('TotalFound',true).Count.Text)~=oldCounts[i].Found then foundOk=false end
end
check(countsOk,'the LIMITED count is the old MECH count + the old VERITY count (both numbers) in all six states'..detail)
check(foundOk,'FOUND (all tabs together) is the same as before in every state')
check(tabOf(gui,'Limited').Count.Text=='14 / 14','everything found: 14 / 14 (7 seeds x 2), as a 7-seed biome tab would read')
bindNew();frames(5)
check(tabOf(gui,'Limited').Count.Text=='0 / 14'and tabOf(gui,'Limited').Fill.Size.X.Offset==0,'nothing found: 0 / 14 and an empty progress strip')
found(seedsFolder,'VeritySeed');for i=1,3 do found(plantsFolder,MECH[i])end;frames(6)
local limFill=tabOf(gui,'Limited').Fill.Size.X.Offset;local width=tabOf(gui,'Limited').Size.X.Offset
check(tabOf(gui,'Limited').Count.Text=='4 / 14'and near(limFill,(width-10)*4/14,.01),'a seed of one category + three plants of the other: 4 / 14 and the strip follows it ('..tabOf(gui,'Limited').Count.Text..')')
-- 3. the grid -----------------------------------------------------------------------------------------------------------------------------------
bindNew()
for i=1,3 do found(seedsFolder,MECH[i]);found(plantsFolder,MECH[i])end;found(seedsFolder,MECH[4],4800);found(seedsFolder,'VeritySeed',9000);frames(6)
lt.Activated:Fire();frames(4)
local cards=seedCards(gui);local ids={};for _,c in ipairs(cards)do ids[#ids+1]=c.Name end
check(#cards==7,'LIMITED lists seven cards: the six Mech seeds and the Verity seed ('..#cards..')')
local mechSet={};for _,id in ipairs(MECH)do mechSet[id]=true end
local firstSix=true;for i=1,6 do if not mechSet[ids[i]]then firstSix=false end end
check(firstSix and ids[7]=='VeritySeed','the Mech seeds first, the Verity seed last ('..table.concat(ids,',')..')')
local oldMechOrder={};for _,c in ipairs(oldCards)do if c.Stage==8 then oldMechOrder[#oldMechOrder+1]=c.Name end end
check(table.concat(oldMechOrder,',')==table.concat(ids,',',1,6),'the Mech seeds in the order the MECH tab had them (Common to King)')
local sameCards=true;local byName={};for _,c in ipairs(cards)do byName[c.Name]=c end
for _,old in ipairs(oldCards)do
 local c=byName[old.Name]
 if not c or cardKey(c)~=old.Key then
  sameCards=false;print('  card differs: '..old.Name)
  if c then local a,b={},{};for p in old.Key:gmatch('[^|]+')do a[#a+1]=p end;for p in cardKey(c):gmatch('[^|]+')do b[#b+1]=p end
   for i=1,math.max(#a,#b)do if a[i]~=b[i]then print('   #'..i..'\n    old '..tostring(a[i])..'\n    new '..tostring(b[i]));break end end end
 end
end
check(sameCards,'every card is what it was on the old MECH / VERITY tab (rarity border or limited card, rarity and odds chips, name, SEED / GROWN, CLAIM pill)')
local claimPill=byName[MECH[4]]:FindFirstChild('ClaimPill');check(claimPill and claimPill.Reward.Text:find('^CLAIM %$'),'a Mech seed with a cash reward shows its CLAIM pill here too')
local Odds=W.module('OddsText85')
local pillsOk=true;for _,pair in ipairs({{MECH[4],4800},{'VeritySeed',9000}})do local pill=byName[pair[1]]:FindFirstChild('ClaimPill');if not(pill and pill.Reward.Text=='CLAIM $'..Odds.Whole(pair[2]))then pillsOk=false;print('  pill text: '..tostring(pill and pill.Reward.Text))end end
check(pillsOk and Odds.Whole(4800)=='4,800','the CLAIM amounts are OddsText85.Whole of the reward ("CLAIM $4,800", "CLAIM $9,000"): whole numbers under a million, as the owner asked')
calls={};byName[MECH[4]].Activated:Fire();frames(3)
check(calls[1]and calls[1][1]=='ClaimSeed'and calls[1][2]==MECH[4],'and clicking it claims that seed (ClaimSeed)')
check(indexBadge()==oldBadgeCash,'the INDEX badge counts the same rewards as before for this state ('..indexBadge()..' vs '..oldBadgeCash..')')
-- Switching tabs: LIMITED then a biome then LIMITED again: the cards follow.
tabOf(gui,1).Activated:Fire();frames(4);local forestCards=seedCards(gui)
local noLimited=true;for _,c in ipairs(forestCards)do if mechSet[c.Name]or c.Name=='VeritySeed'then noLimited=false end end
check(#forestCards==6 and noLimited,'the Forest tab lists only Forest seeds (no Mech / Verity cards stay behind)')
lt.Activated:Fire();frames(4);check(#seedCards(gui)==7,'and LIMITED lists its seven again')
-- 4. the rewards ---------------------------------------------------------------------------------------------------------------------------------
bindNew();lt.Activated:Fire();frames(4)
check(limitedRewards and limitedRewards.Visible==true and bar.Visible==false and progress.Visible==false,'LIMITED shows the two reward rows instead of the single bar')
check(rowOf(gui,8):FindFirstChild('RowLabel').Text=='MECH SET'and rowOf(gui,9):FindFirstChild('RowLabel').Text=='VERITY','the rows are MECH SET (category 8) and VERITY (category 9)')
local order8=rowOf(gui,8).Position.Y.Offset<rowOf(gui,9).Position.Y.Offset;check(order8,'MECH SET above VERITY (the grid below runs in the same order)')
tabOf(gui,1).Activated:Fire();frames(4)
check(limitedRewards.Visible==false and bar.Visible==true and progress.Visible==true,'any other tab shows its single bar and no rows')
lt.Activated:Fire();frames(4)
resetState();frames(5)
check(norm(rowOf(gui,8):FindFirstChild('RowProgress').Text)=='0/6 SEEDS • 0/6 PLANTS'and norm(rowOf(gui,9):FindFirstChild('RowProgress').Text)=='0/1 SEEDS • 0/1 PLANTS','each row has its own progress: 0/6 • 0/6 and 0/1 • 0/1 ('..norm(rowOf(gui,8):FindFirstChild('RowProgress').Text)..' / '..norm(rowOf(gui,9):FindFirstChild('RowProgress').Text)..')')
local function bar2(row)return rowOf(gui,row):FindFirstChild('RowFill',true).Size.X.Scale end
found(seedsFolder,MECH[1]);found(seedsFolder,'VeritySeed');found(plantsFolder,'VeritySeed');frames(6)
check(near(bar2(8),1/12,1e-6)and near(bar2(9),1,1e-6),'each row has its own bar: 1/12 and 2/2')
resetState();frames(5)
for _,stage in ipairs({8,9})do
 local h,e=gemView(pillOf(gui,stage,'half')),gemView(pillOf(gui,stage,'end'))
 check(h.Gems==Tuning.HalfwayGems and h.Amount=='+'..Tuning.HalfwayGems and e.Gems==Tuning.CompletionGems[stage]and e.Amount=='+'..Tuning.CompletionGems[stage],'category '..stage..': the gems are BalanceValues81 (halfway '..tostring(h.Gems)..', completion '..tostring(e.Gems)..')')
 check(not h.Active and not e.Active and not h.Ready and not e.Ready and not h.Claimed and not e.Claimed,'category '..stage..': nothing claimable yet')
end
check(src:find('tuning.CompletionGems[stage]',1,true)~=nil and src:find('tuning.HalfwayGems',1,true)~=nil and not src:find("'+100'",1,true)and not src:find('gems=100',1,true),'(source: the amounts are read from BalanceValues81 for the row\'s own category, not written into the Index)')
-- the same states, clicks and replies as the old tabs
local newMech=categoryScenario(8,newView,newClick,gui);local newVerity=categoryScenario(9,newView,newClick,gui)
for _,case in ipairs({{8,'MECH SET',oldMech,newMech},{9,'VERITY',oldVerity,newVerity}})do
 local stage,label,old,new=case[1],case[2],case[3],case[4]
 local same=true
 for i,o in ipairs(old)do
  local n=new[i];local v,w=o.View,n.View
  local diffs={}
  if v.Progress~=w.Progress then diffs[#diffs+1]='progress '..v.Progress..' / '..w.Progress end
  if v.Half~=w.Half then diffs[#diffs+1]='half\n    '..v.Half..'\n    '..w.Half end
  if v.End~=w.End then diffs[#diffs+1]='end\n    '..v.End..'\n    '..w.End end
  if v.Dot~=w.Dot then diffs[#diffs+1]='dot '..tostring(v.Dot)..' / '..tostring(w.Dot)end
  if v.Badge~=w.Badge or v.Alert~=w.Alert then diffs[#diffs+1]='INDEX badge '..v.Badge..' / '..w.Badge..', MENU alert '..v.Alert..' / '..w.Alert end
  if #diffs>0 then same=false;print('  '..label..' differs at "'..o.Label..'": '..table.concat(diffs,'; '))end
 end
 check(same,label..' (category '..stage..'): '..#old..' states - progress, both gems (ready / claimed / active, amount, colours), tab dot, INDEX badge and MENU alert - exactly as the old tab\'s bar')
 check(old.Calls==new.Calls and old.Calls:find('ClaimBiomeHalf/'..stage,1,true)and old.Calls:find('ClaimBiome/'..stage,1,true),label..': the claims sent are the old tab\'s ('..new.Calls..')')
 check(old.Sounds==new.Sounds and new.Sounds=='GemClaim,GemClaim',label..': one gem sound per successful claim ('..new.Sounds..')')
end
-- both categories at once: four pills, four different claims, each exactly once
bindNew();lt.Activated:Fire();frames(4)
for _,id in ipairs(MECH)do found(seedsFolder,id);found(plantsFolder,id)end;found(seedsFolder,'VeritySeed');found(plantsFolder,'VeritySeed');frames(6)
local pills={{8,'half'},{8,'end'},{9,'half'},{9,'end'}}
local allReady=true;for _,p in ipairs(pills)do local g=gemView(pillOf(gui,p[1],p[2]));if not(g.Active and g.Ready and not g.Claimed)then allReady=false end end
check(allReady,'both categories complete: all four gems are ready and pressable')
check(indexBadge()=='4'and menuAlert()=='!','the INDEX badge counts the four gems: 4 ('..indexBadge()..')')
for _,p in ipairs(pills)do pillOf(gui,p[1],p[2]).Activated:Fire();frames(4)end
local sent={};for _,c in ipairs(calls)do sent[#sent+1]=c[1]..'/'..c[2]end
check(table.concat(sent,',')=='ClaimBiomeHalf/8,ClaimBiome/8,ClaimBiomeHalf/9,ClaimBiome/9','four clicks, four claims: '..table.concat(sent,','))
local allTaken=true;for _,p in ipairs(pills)do local g=gemView(pillOf(gui,p[1],p[2]));if not(g.Claimed and not g.Active and not g.Ready)then allTaken=false end end
check(allTaken,'all four read claimed (mint rim, no longer pressable)')
for _,p in ipairs(pills)do pillOf(gui,p[1],p[2]).Activated:Fire()end;frames(4)
check(#calls==4,'pressing them again sends nothing ('..#calls..' claims)')
check(indexBadge()=='-'and menuAlert()=='-'and not dotOf(gui,'Limited'),'every badge is gone once both categories are claimed')
-- one claim at a time (a held reply)
bindNew();lt.Activated:Fire();frames(4)
for _,id in ipairs(MECH)do found(seedsFolder,id);found(plantsFolder,id)end;found(seedsFolder,'VeritySeed');found(plantsFolder,'VeritySeed');frames(6)
hold=true;pillOf(gui,9,'half').Activated:Fire();frames(2)
check(type(held)=='thread'and #calls==1 and calls[1][1]=='ClaimBiomeHalf'and calls[1][2]==9,'a claim is in flight (waiting for the server): ClaimBiomeHalf 9')
local noneActive=true;for _,p in ipairs(pills)do if gemView(pillOf(gui,p[1],p[2])).Active then noneActive=false end end
check(noneActive,'while it is in flight no gem of either row can be pressed')
pillOf(gui,8,'end').Activated:Fire();pillOf(gui,9,'end').Activated:Fire();frames(2)
check(#calls==1,'a second press meanwhile sends nothing ('..#calls..')')
coroutine.resume(held);frames(6)
check(gemView(pillOf(gui,9,'half')).Claimed and gemView(pillOf(gui,8,'half')).Active and gemView(pillOf(gui,8,'end')).Active and gemView(pillOf(gui,9,'end')).Active,'the reply arrives: that gem reads claimed, the other three are pressable again')
-- 5. badges --------------------------------------------------------------------------------------------------------------------------------------
bindNew();lt.Activated:Fire();frames(6)
check(indexBadge()=='-'and menuAlert()=='-'and not dotOf(gui,'Limited'),'nothing to claim: no dot, no INDEX badge, no MENU alert')
found(seedsFolder,'VeritySeed');frames(6)
check(dotOf(gui,'Limited')and indexBadge()=='1'and menuAlert()=='!','a reward in VERITY only (its halfway gem): the LIMITED dot, INDEX 1, MENU !')
local otherDots=false;for _,k in ipairs(BIOMES)do if dotOf(gui,k)then otherDots=true end end;check(not otherDots,'and no other tab has a dot')
resetState();frames(6)
for i=1,3 do found(seedsFolder,MECH[i]);found(plantsFolder,MECH[i])end;frames(6)
check(dotOf(gui,'Limited')and indexBadge()=='1','a reward in MECH only (its halfway gem): the LIMITED dot, INDEX 1')
found(seedsFolder,'VeritySeed');frames(6)
check(dotOf(gui,'Limited')and indexBadge()=='2','both: still one dot on the tab, INDEX 2')
found(plantsFolder,'VeritySeed');frames(6)
check(indexBadge()=='3','the Verity seed grown too: its completion gem lights up: 3')
seedsFolder:FindFirstChild(MECH[1]):SetAttribute('RewardCash',500);frames(6)
check(indexBadge()=='4','a cash reward on a Mech seed: 4')
seedsFolder:FindFirstChild(MECH[1]):SetAttribute('RewardCash',nil);player:SetAttribute('IndexBiomeHalfReward8',true);player:SetAttribute('IndexBiomeHalfReward9',true);frames(6)
check(indexBadge()=='1'and dotOf(gui,'Limited'),'the server marks both halfway rewards taken: only the Verity completion is left (1)')
player:SetAttribute('IndexBiomeReward9',true);frames(6)
check(indexBadge()=='-'and not dotOf(gui,'Limited')and menuAlert()=='-','and then nothing: the dot, the badge and the alert go away')
player:SetAttribute('IndexBiomeBackpay8',150);frames(6)
check(dotOf(gui,'Limited')and indexBadge()=='1'and gemView(pillOf(gui,8,'end')).Gems==150 and gemView(pillOf(gui,8,'end')).Active,'backpay on category 8 lights the dot and shows 150 on MECH SET\'s completion gem')
player:SetAttribute('IndexBiomeBackpay8',nil)
-- 5b. the timer (owner: "place a timer at the limited section for 27 days ... hrs . mins . s") --------------------------------------------------------
local Event=W.module('LimitedEvent')
check(Event.EndsAt==1793491200 and os.date('!%Y-%m-%d %H:%M:%S',Event.EndsAt)=='2026-11-01 00:00:00','LimitedEvent ends 2026-11-01 00:00:00 UTC (one end time for the Index and the Verity event)')
check(Event.Text(27*86400+4*3600+12*60+9)=='27d 04h 12m 09s'and Event.Text(0)=='0d 00h 00m 00s'and Event.Text(59)=='0d 00h 00m 59s'and Event.Text(86400*365)=='365d 00h 00m 00s','LimitedEvent.Text: "27d 04h 12m 09s" (days, then two-digit hours, minutes, seconds)')
check(Event.Left(Event.EndsAt-100)==100 and Event.Left(Event.EndsAt+5)==0 and Event.Active(Event.EndsAt-1)and not Event.Active(Event.EndsAt),'Left counts down to 0 at EndsAt; Active until then')
local clock0,left0=0,0
W.workspace.GetServerTimeNow=function()return Event.EndsAt-left0+(R.clock-clock0)end -- (the mock's server clock: `left0` seconds left at the mock time `clock0`)
local function setLeft(seconds)clock0=R.clock;left0=seconds end
local function timerText(g)return g:FindFirstChild('TimerText',true).Text end
local function noteText(g)return tabOf(g,'Limited'):FindFirstChild('TabNote').Text end
local function secondsIn(text)local d,h,m,s=text:match('(%d+)d (%d+)h (%d+)m (%d+)s');return d and tonumber(d)*86400+tonumber(h)*3600+tonumber(m)*60+tonumber(s)end
local LEFT=27*86400+4*3600+12*60+9
setLeft(LEFT);bindNew();setLeft(LEFT);lt.Activated:Fire();frames(3)
check(timerText(gui)=='⏳ ENDS IN 27d 04h 12m 09s','the LIMITED panel opens with "⏳ ENDS IN 27d 04h 12m 09s" ('..timerText(gui)..')')
check(noteText(gui)=='LIMITED 27d','the tab says LIMITED and the days left: "'..noteText(gui)..'"')
local shownIn=limitedRewards:FindFirstChild('LimitedTimer')
check(shownIn and shownIn.Parent==limitedRewards and limitedRewards.Visible,'the timer sits at the top of the LIMITED rows block, shown with the panel')
-- it ticks every second while the Index is open
local changes,last,first=0,timerText(gui),secondsIn(timerText(gui))
local t0=R.clock
for _=1,600 do frames(1);local now=timerText(gui);if now~=last then changes+=1;last=now end end
local elapsed=math.floor(R.clock-t0)
local nowSeconds=secondsIn(last)
check(changes>=9 and changes<=11,'ticks about once a second: the text changed '..changes..' times in 10 s')
check(nowSeconds and first-nowSeconds>=elapsed-1 and first-nowSeconds<=elapsed+1,'and counts down in real time: '..tostring(first)..' -> '..tostring(nowSeconds)..' after '..elapsed..' s')
-- a minute boundary
setLeft(63);frames(3)
local seen,lastSeen={},nil
for _=1,300 do frames(1);local t=timerText(gui);if t~=lastSeen then seen[#seen+1]=t;lastSeen=t end end
local iMin,iSec=table.find(seen,'⏳ ENDS IN 0d 00h 01m 00s'),table.find(seen,'⏳ ENDS IN 0d 00h 00m 59s')
check(iMin and iSec and iMin+1==iSec,'across the minute: ... 01m 00s, then 00m 59s ('..table.concat(seen,' | '):gsub('⏳ ENDS IN 0d 00h ','')..')')
setLeft(2*3600+5*60);frames(3);W.frames(70)
check(noteText(gui):match('^LIMITED %dh$')~=nil,'under a day left the tab shows hours ('..noteText(gui)..')')
-- a closed Index does not tick; opening it shows the current time at once
setLeft(LEFT);W.frames(70);local before=timerText(gui)
pg:SetAttribute('SeedMenu',nil);frames(2);local closedAt=timerText(gui)
W.frames(300);check(timerText(gui)==closedAt,'closed: no ticking in the background')
setLeft(LEFT-50);pg:SetAttribute('SeedMenu','Index');frames(3)
check(secondsIn(timerText(gui))and math.abs(secondsIn(timerText(gui))-(LEFT-50-0))<=2,'reopened: it shows the time left now at once ('..timerText(gui)..')')
tabOf(gui,1).Activated:Fire();frames(4)
check(limitedRewards.Visible==false,'on another tab the timer is not shown')
-- the end: ENDED, display only (the rewards stay claimable)
for _,id in ipairs(MECH)do found(seedsFolder,id);found(plantsFolder,id)end;frames(4)
lt.Activated:Fire();setLeft(3);frames(4);W.frames(300);frames(2)
check(timerText(gui)=='ENDED'and not timerText(gui):find('ENDS IN',1,true),'after EndsAt it reads ENDED ('..timerText(gui)..')')
check(noteText(gui)=='ENDED','and so does the tab ('..noteText(gui)..')')
check(gemView(pillOf(gui,8,'half')).Active and gemView(pillOf(gui,8,'end')).Active and gemView(pillOf(gui,8,'end')).Ready,'the rewards stay claimable after the end (display only)')
calls={};pillOf(gui,8,'end').Activated:Fire();frames(4)
check(calls[1]and calls[1][1]=='ClaimBiome'and calls[1][2]==8,'and a claim still goes through after the end')
check(src:find('Event.Left(workspace:GetServerTimeNow())',1,true)~=nil and src:find('LimitedEvent',1,true)~=nil,'(source: the countdown reads LimitedEvent against workspace:GetServerTimeNow())')
-- 6. screens ------------------------------------------------------------------------------------------------------------------------------------
bindNew();setLeft(LEFT);frames(4)
print('tab row and LIMITED panel by screen (strip / canvas of the tab row; rows block height; cards start y new / old MECH tab; card list height):')
for _,sz in ipairs(SIZES)do
 local w,h=sz[1],sz[2];resize(w,h);lt.Activated:Fire();frames(3)
 local strip=tabs.AbsoluteSize;local buttons={};for _,b in ipairs(tabs:GetChildren())do if b:IsA('TextButton')and b.Name~='BiomePacks'then buttons[#buttons+1]=b end end -- (R151: the PACKS tab is the ninth)
 table.sort(buttons,function(a,b)return a.LayoutOrder<b.LayoutOrder end)
 local x,overlap,sameSize,fitsHeight,contentOk,prevRight=0,false,true,true,true,-1e9;local pad=layout.Padding.Offset
 local limitedLeft,limitedRight
 for i,b in ipairs(buttons)do
  local bw,bh=b.Size.X.Offset,b.Size.Y.Offset
  if i>1 and x<prevRight+pad-1e-9 then overlap=true end
  prevRight=x+bw;if b==lt then limitedLeft,limitedRight=x,x+bw end
  if bw~=buttons[1].Size.X.Offset or bh~=buttons[1].Size.Y.Offset then sameSize=false end
  if bh+tabs.ScrollBarThickness>strip.Y+1e-9 then fitsHeight=false end
  local lg,cnt=b:FindFirstChild('BiomeLogo'),b:FindFirstChild('Count')
  local lx,lw,lh=lg.Position.X.Offset,lg.Size.X.Offset,lg.Size.Y.Offset;local cx=cnt.Position.X.Offset;local cwidth=bw+cnt.Size.X.Offset -- (Size = scale 1 + offset)
  if lx+lw>cx+1e-9 or cx+cwidth>bw+1e-9 or cwidth<20 or lg.Position.Y.Offset+lh>bh+1e-9 then contentOk=false;print('  logo / count collide: '..b.Name)end
  if utf8.len(cnt.Text)*cnt.TextSize*.52>cwidth+1e-9 then contentOk=false;print('  count text too wide: '..b.Name..' '..cnt.Text)end
  x=x+bw+pad
 end
 local canvas=x-pad;local panelW=math.min(980,w*.94);local needs=canvas>strip.X
 check(#buttons==8 and not overlap and sameSize,('%dx%d: eight equal tabs, none overlapping (8 px gaps)'):format(w,h))
 check(fitsHeight and contentOk,('%dx%d: every tab fits its row (%dpx high strip), icon and count do not collide'):format(w,h,strip.Y))
 check(near(strip.X,panelW-24,1),('%dx%d: the strip is the panel width - 24 (%.0f)'):format(w,h,strip.X))
 check(not needs or(tabs.ScrollingDirection.Name=='X'and tabs.AutomaticCanvasSize.Name=='X'and limitedRight<=canvas+1e-9),('%dx%d: canvas %.0f vs strip %.0f: %s'):format(w,h,canvas,strip.X,needs and'scrolls sideways, LIMITED is the last stop'or'fits without scrolling'))
 -- the rows
 local pa,ps=panel.AbsolutePosition,panel.AbsoluteSize
 local rf=limitedRewards;local rp,rs=rf.AbsolutePosition,rf.AbsoluteSize
 local r8,r9=rowOf(gui,8),rowOf(gui,9);local p8,s8,p9,s9=r8.AbsolutePosition,r8.AbsoluteSize,r9.AbsolutePosition,r9.AbsoluteSize
 local tabBottom=tabs.AbsolutePosition.Y+tabs.AbsoluteSize.Y;local listFrame=gui:FindFirstChild('SeedCards',true);local lp,ls=listFrame.AbsolutePosition,listFrame.AbsoluteSize
 check(rf.Visible and rp.X>=pa.X-1e-9 and rp.X+rs.X<=pa.X+ps.X+1e-9 and rp.Y>=tabBottom-1e-9,('%dx%d: the rows are inside the panel and below the tab row'):format(w,h))
 check(p9.Y>=p8.Y+s8.Y-1e-9 and p9.Y+s9.Y<=rp.Y+rs.Y+1e-9 and lp.Y>=rp.Y+rs.Y-1e-9,('%dx%d: MECH SET above VERITY, no overlap, the cards start below them'):format(w,h))
 local rowsOk,textOk=true,true
 for _,row in ipairs({r8,r9})do
  local rpos,rsize=row.AbsolutePosition,row.AbsoluteSize
  local lab,prog=row:FindFirstChild('RowLabel'),row:FindFirstChild('RowProgress')
  if lab.AbsolutePosition.X+lab.AbsoluteSize.X>prog.AbsolutePosition.X+1e-9 then rowsOk=false end
  if utf8.len(lab.Text)*lab.TextSize*.52>lab.AbsoluteSize.X+1e-9 then textOk=false;print('  row label too wide '..lab.Text)end
  if prog:GetAttribute('TextShortened')==true or utf8.len(prog.Text)*prog.TextSize*.52>prog.AbsoluteSize.X+1e-9 then textOk=false;print('  row progress too wide: '..prog.Text..' size '..prog.TextSize)end
  local hp,ep=row:FindFirstChild('HalfClaim',true),row:FindFirstChild('EndClaim',true)
  for _,pill in ipairs({hp,ep})do
   local a,s=pill.AbsolutePosition,pill.AbsoluteSize
   if a.X<rpos.X-1e-9 or a.X+s.X>rpos.X+rsize.X+1e-9 or a.Y<rpos.Y-1e-9 or a.Y+s.Y>rpos.Y+rsize.Y+1e-9 then rowsOk=false;print('  pill outside its row: '..pill.Name)end
   local amt=pill:FindFirstChild('RewardAmount');local art=pill:FindFirstChild('ArtHolder')
   if art.Position.X.Offset+art.Size.X.Offset>amt.Position.X.Offset+1e-9 or utf8.len(amt.Text)*amt.TextSize*.52>amt.AbsoluteSize.X+1e-9 then textOk=false;print('  pill text too wide '..pill.Name..' '..amt.Text)end
  end
  if hp.AbsolutePosition.X+hp.AbsoluteSize.X>=ep.AbsolutePosition.X-1e-9 then rowsOk=false;print('  the two gems touch')end
  if hp.AbsolutePosition.Y<lab.AbsolutePosition.Y+lab.AbsoluteSize.Y-1e-9 then rowsOk=false;print('  gems overlap the label line')end
 end
 check(rowsOk,('%dx%d: in each row the label and progress do not overlap, both gems lie inside the row, below the text line, apart from each other'):format(w,h))
 check(textOk,('%dx%d: every label, progress text and amount fits its box (progress is not shortened)'):format(w,h))
 -- the countdown pill (above the first row) and the note under the tab's count
 local tm=limitedRewards:FindFirstChild('LimitedTimer');local tx=tm:FindFirstChild('TimerText');local tp,ts=tm.AbsolutePosition,tm.AbsoluteSize
 local tFits=tm.Visible and tp.X>=pa.X-1e-9 and tp.X+ts.X<=pa.X+ps.X+1e-9 and tp.Y>=tabBottom-1e-9 and tp.Y+ts.Y<=p8.Y+1e-9 and ts.X>=150
 local tTextOk=tx.Text=='⏳ ENDS IN 27d 04h 12m 09s'or tx.Text:find('^⏳ ENDS IN 27d 0[34]h')~=nil
 local tShown=tx:GetAttribute('TextShortened')~=true and utf8.len(tx.Text)*tx.TextSize*.52<=tx.AbsoluteSize.X+1e-9 and tx.TextSize>=10
 check(tFits and tTextOk and tShown,('%dx%d: the countdown "%s" fits its pill (%.0f x %.0f, text %d px) between the tab row and MECH SET'):format(w,h,tx.Text,ts.X,ts.Y,tx.TextSize))
 local note=lt:FindFirstChild('TabNote');local cnt=lt:FindFirstChild('Count');local fillBar=lt:FindFirstChild('Fill');local bh=lt.Size.Y.Offset
 local compactTab=bh<58
 local noteOk
 if compactTab then noteOk=note.Visible==false else
  noteOk=note.Visible==true and note.Position.Y.Offset>=cnt.Position.Y.Offset+cnt.Size.Y.Offset-1e-9 and note.Position.Y.Offset+note.Size.Y.Offset<=bh+fillBar.Position.Y.Offset+1e-9
   and note.Position.X.Offset>=lt:FindFirstChild('BiomeLogo').Position.X.Offset+lt:FindFirstChild('BiomeLogo').Size.X.Offset and utf8.len(note.Text)*10*.52<=lt.Size.X.Offset-note.Position.X.Offset-4
 end
 check(noteOk,('%dx%d: the tab note "%s" %s'):format(w,h,note.Text,compactTab and'is left out of the compact tab'or'fits under the count, beside the logo and above the progress strip (122 px tab on a phone too)'))
 local k=w..'x'..h;local listY=listFrame.Position.Y.Offset
 check(listY<=oldListY[k]+30 and ls.Y>=100,('%dx%d: the cards start at y=%d (the old MECH tab: %d, the countdown line is new), %dpx of list'):format(w,h,listY,oldListY[k],ls.Y))
 print(('  %4dx%-4d strip %4.0f canvas %4.0f %-8s rows %3.0f  cards y %3d / %3d  list %3.0f'):format(w,h,strip.X,canvas,needs and'scrolls'or'fits',rs.Y,listY,oldListY[k],ls.Y))
end
-- 7. the other seven tabs ------------------------------------------------------------------------------------------------------------------------
bindNew()
local newBiome=biomeScenario(gui)
local sameBiome=#newBiome==#oldBiome
for i,o in ipairs(oldBiome)do if newBiome[i]~=o then sameBiome=false;print('  biome scenario differs at step '..i..':\n'..o..'\n  --- new:\n'..tostring(newBiome[i]))break end end
check(sameBiome,'biome tabs 1..7 through '..#oldBiome..' scripted states (finds, half way, claims, backpay, server attributes, cash rewards, alerts, cards): every tab, gem, badge, alert and claim identical to the R147 script')
local newSizes=sizeSnapshots(gui);local sameTabs,compared=true,0
for _,sz in ipairs(SIZES)do local k=sz[1]..'x'..sz[2]
 for _,key in ipairs(BIOMES)do
  compared+=1
  if newSizes[k][key]~=oldSizes[k][key]then sameTabs=false;print('  tab '..key..' at '..k..' differs:\n'..oldSizes[k][key]..'\n  --- new:\n'..newSizes[k][key])end
 end
end
check(sameTabs,'tabs 1..7 and their open panels (size, colour, children, text, progress, bar, gems, header, card list) identical to the R147 script on every screen ('..compared..' tab states)')
-- 8. the icon -------------------------------------------------------------------------------------------------------------------------------------
W.frames(200,.1) -- (the tabs' own BiomeArtwork loads, which could not decode on the bare mock, have used up their retries by now)
local Data=W.module('BiomeIconData');local DataBase=W.module('BiomeIconDataBase');local PreparedBase=W.module('ArtworkFallbackData89Base')
local limited=Data.Limited
local function keysOf(t)local k={};for key in pairs(t)do k[#k+1]=key end;table.sort(k);return table.concat(k,',')end
check(limited~=nil and keysOf(limited)==keysOf(Data.Mech)and keysOf(limited)==keysOf(Data.Forest),'BiomeIconData.Limited has the fields of the other logos ('..(limited and keysOf(limited)or'-')..')')
check(limited.Size==96 and limited.TinyWidth==24 and limited.TinyHeight==24,'Size 96, Tiny 24 x 24 like Forest ... Mech')
local B64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';local rev={};for i=1,#B64 do rev[B64:sub(i,i)]=i-1 end
local function b64decode(s)
 local out={};local bits,n=0,0
 for i=1,#s do local c=s:sub(i,i);if c~='='then local v=rev[c];if not v then return nil end;bits=bits*64+v;n+=6;if n>=8 then n-=8;local byte=math.floor(bits/2^n);bits-=byte*2^n;out[#out+1]=string.char(byte)end end end
 return table.concat(out)
end
check(type(limited.RGBA)=='string'and #limited.RGBA%4==0 and not limited.RGBA:find('[^%w%+/=]'),'RGBA is base64 text')
local comp=b64decode(limited.RGBA)or''
local function zstdHeader(bytes)
 if #bytes<9 or bytes:sub(1,4)~='\40\181\47\253'then return nil end
 local fhd=bytes:byte(5);local single=fhd//32%2==1;local fcsFlag=fhd//64;local fcs
 if fcsFlag==1 then fcs=bytes:byte(6)+bytes:byte(7)*256+256 elseif fcsFlag==2 then fcs=bytes:byte(6)+bytes:byte(7)*256+bytes:byte(8)*65536+bytes:byte(9)*16777216 elseif fcsFlag==0 and single then fcs=bytes:byte(6)end
 return{FHD=fhd,Single=single,Size=fcs,Checksum=fhd//4%2==1,Dict=fhd%4}
end
local zh=zstdHeader(comp);local zm=zstdHeader(b64decode(Data.Mech.RGBA))
check(zh and zh.Size==96*96*4,'it decodes to a zstd frame whose content size is 96 x 96 x 4 = 36864 ('..tostring(zh and zh.Size)..')')
check(zh and zm and zh.FHD==zm.FHD and zh.Single and not zh.Checksum and zh.Dict==0,'with the same frame header as Mech: single segment, no checksum, no dictionary (FHD '..tostring(zh and zh.FHD)..')')
check(#comp>1000 and #comp<30000,'a plausible size ('..#comp..' bytes compressed; Mech '..#b64decode(Data.Mech.RGBA)..')')
local pal,paletteOk=limited.Palette,type(limited.Palette)=='table'and #limited.Palette>=2 and #limited.Palette<=255
if paletteOk then for _,c in ipairs(pal)do if type(c)~='table'or #c~=3 or c[1]<0 or c[1]>255 or c[2]<0 or c[2]>255 or c[3]<0 or c[3]>255 then paletteOk=false end end end
check(paletteOk,'Palette: '..(paletteOk and #pal or 0)..' RGB colours')
local runsOk=type(limited.Runs)=='table'and #limited.Runs>20
if runsOk then for _,r in ipairs(limited.Runs)do if #r~=5 or r[1]<0 or r[2]<0 or r[1]+r[3]>24 or r[2]+r[5]>24 or r[4]<1 or r[4]>#pal or r[3]<1 or r[5]<1 then runsOk=false end end end
check(runsOk,'Runs: {x, y, width, colour, height} inside the 24 x 24 raster, colours inside the palette ('..#limited.Runs..' runs)')
local spec=Prepared.Limited
check(spec and spec.Width==64 and spec.Height==64 and #spec.Strips>50,'ArtworkFallbackData89.Limited decodes (64 x 64, '..(spec and #spec.Strips or 0)..' strips; the module asserts its own length)')
local stripsOk=spec~=nil
for _,s in ipairs(spec and spec.Strips or{})do
 if s[1]<0 or s[3]<1 or s[1]+s[3]>64 or s[2]<0 or s[2]>=64 or #s[4]<2 or #s[4]>6 then stripsOk=false end
 local last=-1;for _,k in ipairs(s[4])do if k[1]<last or k[1]<0 or k[1]>1 or k[5]<0 or k[5]>255 then stripsOk=false end;last=k[1]end
 if s[4][1][1]~=0 or s[4][#s[4]][1]~=1 then stripsOk=false end
end
check(stripsOk,'every strip is inside the 64 x 64 raster with 2..6 ordered stops from 0 to 1')
-- the other kinds of both modules are untouched
local sameOthers=true
for _,kind in ipairs({'Forest','Jungle','Desert','Snow','Crystal','Lava','Storm','Mech'})do
 local a,b=Data[kind],DataBase[kind];if a.RGBA~=b.RGBA or a.Size~=b.Size or #a.Palette~=#b.Palette or #a.Runs~=#b.Runs then sameOthers=false end
end
local extra=false;for kind in pairs(Data)do if DataBase[kind]==nil and kind~='Limited'then extra=true end end
check(sameOthers and not extra,'BiomeIconData: the eight existing logos are untouched and Limited is the only new kind')
local sameFallbacks,nFallbacks=true,0
for _,kind in ipairs({'Bolt','City','Clover','Crystal','Desert','Forest','GardenSize','GardenTime','Gem','Index','Jungle','Lava','Mech','Money','Moon','RobuxShop','Snow','Storm','WeatherBlizzard','WeatherClear','WeatherRain','WeatherSnow','WeatherThunderstorm'})do
 local a,b=Prepared[kind],PreparedBase[kind];nFallbacks+=1
 if not a or not b or a.Width~=b.Width or a.Height~=b.Height or #a.Strips~=#b.Strips then sameFallbacks=false else
  for i,s in ipairs(a.Strips)do local t=b.Strips[i];if s[1]~=t[1]or s[2]~=t[2]or s[3]~=t[3]or #s[4]~=#t[4]then sameFallbacks=false;break end end
 end
end
check(sameFallbacks and PreparedBase.Limited==nil,'ArtworkFallbackData89: the other '..nFallbacks..' prepared images decode as before; Limited is new')
-- BiomeArtwork: Attach 'Limited' like any other kind; an unknown kind still asserts
local holder=R.new('Frame');holder.Parent=W.workspace
local root=W.module('BiomeArtwork').Attach(holder,'Limited')
check(spec~=nil and root and root.Name=='GeneratedLimited'and stripsOf(root)==#spec.Strips,'BiomeArtwork.Attach(parent, "Limited") builds the logo from the fallback strips ('..stripsOf(root)..')')
check(not pcall(W.module('BiomeArtwork').Attach,holder,'NoSuchBiome'),'(an unknown kind still errors "Unknown artwork")')
-- the real ArtworkRuntime87 (a fresh copy: the one the tabs used was started before the image APIs below exist)
local Side=require('./limited_raw')
local function adler(s)local a,b=1,0;for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end;return b*65536+a end
check(Side.Length==#comp and Side.Adler==adler(comp),'the sidecar (made by check_limited_icon.py with the real zstd library) was decompressed from exactly this RGBA field')
local rawHex=Side.Hex;local raw=rawHex:gsub('..',function(h)return string.char(tonumber(h,16))end)
check(#raw==96*96*4,'its raw RGBA is 96 x 96 x 4 bytes')
local writes,created={},0
local Encoding=W.service('EncodingService');local Asset=W.service('AssetService')
function Encoding.Base64Decode(_,buf)return buffer.fromstring(b64decode(buffer.tostring(buf)))end
function Encoding.DecompressBuffer(_,buf,alg)
 assert(alg==R.Enum.CompressionAlgorithm.Zstd,'algorithm must be Zstd')
 local s=buffer.tostring(buf);assert(zstdHeader(s)and adler(s)==Side.Adler and #s==Side.Length,'not the frame the sidecar was made from')
 return buffer.fromstring(raw)
end
function Asset.CreateEditableImage(_,props)
 created+=1;local image={Size=props.Size,Destroyed=false}
 function image.WritePixelsBuffer(self,pos,size,bytes)writes[#writes+1]={Pos=pos,Size=size,Bytes=bytes}end
 function image.Destroy(self)self.Destroyed=true end
 return image
end
W.env.Content={fromObject=function(o)return o end}
local Runtime=W.load('ArtworkRuntime87',W.RS:FindFirstChild('ArtworkRuntime87'))
local stage=R.new('Frame');stage.Parent=W.workspace
local logoRoot=Runtime.Attach(stage,'Limited',Data.Limited,nil)
check(logoRoot:FindFirstChild('SmoothFallback')and logoRoot.SmoothFallback.Visible==true,'before anything loads the fallback strips are drawn')
W.frames(40,.1)
check(#writes==1 and created==1,'the runtime decoded Limited and made one EditableImage ('..#writes..' write, '..created..' image)')
local w1=writes[1]
check(w1 and w1.Size.X==96 and w1.Size.Y==96 and buffer.len(w1.Bytes)==96*96*4 and w1.Pos.X==0 and w1.Pos.Y==0,'a 96 x 96 raster is written at 0,0 (Base64 -> zstd -> RGBA)')
check(w1 and buffer.tostring(w1.Bytes)==raw,'and its bytes are the icon\'s pixels, every one')
local function px(x,y)local o=(y*96+x)*4;return raw:byte(o+1),raw:byte(o+2),raw:byte(o+3),raw:byte(o+4)end
local _,_,_,corner=px(0,0);local _,_,_,centre=px(48,40);local pr,pg2,pb=px(48,40)
check(corner==0 and centre==255 and pb>pg2,'(the picture: transparent corner, an opaque purple-ish gem in the middle: '..pr..','..pg2..','..pb..')')
local art=logoRoot:FindFirstChild('Artwork')
check(art and art._class=='ImageLabel'and art.Visible==false and logoRoot.SmoothFallback.Visible==true,'the image waits for its load: the fallback stays visible')
if art then art.IsLoaded=true;W.frames(2)end
check(art and art.Visible==true and logoRoot.SmoothFallback.Visible==false,'when the image has loaded it replaces the fallback')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
