--!nocheck
-- R153 (owner: "make it fixed visibly so ... they are still reminded of how rare it is ... in the index"): the INDEX half. The real ChestIndex of this checkout on the Roblox mock, its seed
-- catalog fixture standing in for ChestService's: every card's chance chip (name "Odds", the text the player reads) says the seed's ONE fixed chance (SeedRarity153), also when the
-- entry's BaseChance attribute is a pack's number (the owner's wrong 1/12 for every seed), is missing, or is the real Pack01 one; every tab (7 biomes + LIMITED: Mech + Verity),
-- every one of the 54 seeds, found or not. Prints SURFACE lines (index): run_seed_rarity.sh compares them with the card, chat and plaque tests'.
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
-- the fixture's BaseChance attribute: set per run by BASE (the owner's wrong example 1/12 for every seed, none at all, or the real Pack01 chance)
local MODE='wrong'
local function BASE(id,stage)if MODE=='wrong'then return 100/12 elseif MODE=='real'then return Rules.SeedOdds(config,stage,'Pack01',1)[id]end;return nil end
local seedsOf={}
for stage,defs in ipairs(config.SeedCatalogByStage)do for index,seed in ipairs(defs)do
 if not Rules.IsRetired(seed.Id)then
  local entry=R.new('Folder');entry.Name=seed.Id;entry:SetAttribute('SeedId',seed.Id);entry:SetAttribute('DisplayName',seed.Name)
  entry:SetAttribute('Rarity',Rules.GetRarity(seed.Id))
  local at=Rules.ObtainableStage(seed.Id)or stage;entry:SetAttribute('BaseChance',BASE(seed.Id,at))
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
local Canon=W.module('SeedRarity153')
local function tabOf(gui,key)return gui:FindFirstChild('Biome'..key,true)end
local function seedCards(gui)
 local out={};for _,c in ipairs(gui:FindFirstChild('SeedCards',true):GetChildren())do if c:IsA('TextButton')then out[#out+1]=c end end
 table.sort(out,function(a,b)return a.LayoutOrder<b.LayoutOrder end);return out
end
local function oddsOf(card)local o=card:FindFirstChild('Odds',true);return o and o._props.Text or nil end
local function readAll(label)
 resetState();resize(1280,720)
 local gui=loadIndex('ChestIndex')
 check(gui~=nil,label..': the Index loads')
 local seen={};local bad={}
 for _,key in ipairs({1,6,2,3,5,4,7,'Limited'})do
  local tab=tabOf(gui,key);check(tab~=nil,label..': tab '..tostring(key))
  if tab then
   tab.Activated:Fire();frames(4)
   for _,c in ipairs(seedCards(gui))do
    local text=oddsOf(c);seen[c.Name]=text
    if text~=Canon.Text(c.Name)then bad[#bad+1]=c.Name..' says '..tostring(text)..' (fixed '..Canon.Text(c.Name)..')'end
   end
  end
 end
 local n=0;for _ in pairs(seen)do n+=1 end
 check(n==54,label..': every one of the 54 seeds has a card ('..n..')')
 check(#bad==0,label..': every card\'s chance chip is the seed\'s fixed chance ('..table.concat(bad,'; ')..')')
 return seen,gui
end
-- 1. the entries carry a pack's number (1/12 for every seed): the chips still say the fixed chances
MODE='wrong'
local seen=readAll('BaseChance = 1/12 on every entry')
local ids={};for id in pairs(seen)do ids[#ids+1]=id end;table.sort(ids)
for _,id in ipairs(ids)do print('SURFACE index '..id..' '..tostring(seen[id]))end
local twelve=0;for _,t in pairs(seen)do if t=='1/12'then twelve+=1 end end
check(twelve==0,'no chip says the entry\'s 1/12')
check(seen.PolarStarbloomSeed=='1/1M','the Index card of Polar Starbloom (Cosmic) says '..tostring(seen.PolarStarbloomSeed)..', not the entry\'s 1/12')
-- 2. no attribute at all (an older server): the module still gives the chip
MODE='none'
readAll('no BaseChance attribute')
-- 3. the entries as ChestService builds them (the real Pack01 numbers): the same chips
MODE='real'
readAll('BaseChance = the real Pack01 chance')
-- 4. a found, grown seed with a claim pill: the chance text does not move
do
 MODE='wrong';resetState();resize(1280,720);local g=loadIndex('ChestIndex')
 found(seedsFolder,'FirePepperSeed',12345);found(plantsFolder,'FirePepperSeed');frames(5)
 tabOf(g,4).Activated:Fire();frames(4)
 local fire;for _,c in ipairs(seedCards(g))do if c.Name=='FirePepperSeed'then fire=c end end
 check(fire and oddsOf(fire)=='1/800','a found, grown Fire Pepper with a cash reward still reads 1/800 ('..tostring(fire and oddsOf(fire))..')')
 local claim;for _,d in ipairs(fire and fire:GetDescendants()or{})do local t=d._props.Text;if type(t)=='string'and t:find('^CLAIM %$')then claim=t end end
 check(claim~=nil,'(and its CLAIM pill is there)')
end
print(('R153 seed rarity (Index): %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
