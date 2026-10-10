-- R57: independent limited pool. Stage 8 is an inventory/index category, not a new map biome.
local C={Stage=8,Variant='MechLimited',Name='Limited Mech Pack',GemPrice=80,TargetRobuxPrice=80,
 CashPerGem=1000000000000,BiomeGemReward=5,MaxGems=1000000,PassGemPrices={Growth=500,Speed=400,Clover=999}, -- R153: Clover (owner: gem price 999)
 Seeds={{Id="PlasmaPepperSeed",Model="PlasmaPepper",Name="Plasma Pepper",Rarity="Legendary",Chance=48,Seconds=300,RegrowSeconds=150,Value=2200,FruitCount=3,Sockets={{-1.55,2.65,0.55},{1.48,3.8,0.55},{0.1,5.75,0.4}},FruitCenters={{-1.0757282170086793,2.483650295115767,0.48401375197001806},{1.1935696789565,3.7871071966575,0.5027232714765},{0.10211435939480645,5.550225416481371,0.41057506141071337}},FruitRadii={1.6608584659479688,1.7001043318119347,1.322119407900125},Height=6.616154722962742,Radius=2.4560985900000003,HarvestName="Plasma Pepper",Tree=false},{Id="HoloMelonSeed",Model="HoloMelon",Name="Holo Melon",Rarity="Mythic",Chance=26,Seconds=450,RegrowSeconds=240,Value=6200,FruitCount=1,Sockets={{0.0,3.65,0.0}},FruitCenters={{0.0,3.8185822497135002,0.0}},FruitRadii={2.9990342838621027},Height=5.5372384994270005,Radius=1.907275,HarvestName="Holo Melon",Tree=false},{Id="PrismLotusSeed",Model="PrismLotus",Name="Prism Lotus",Rarity="Mythic",Chance=16,Seconds=600,RegrowSeconds=300,Value=8500,FruitCount=1,Sockets={{0,2.1,0}},FruitCenters={{0.0,2.12,0.0}},FruitRadii={1.271706316486077},Height=3.724422,Radius=2.3000001208320002,HarvestName="Prism Lotus Core",Tree=false},{Id="HoloAppleTreeSeed",Model="HoloAppleTree",Name="Holo Apple Tree",Rarity="Secret",Chance=7,Seconds=900,RegrowSeconds=420,Value=15000,FruitCount=4,Sockets={{-2.784672,8.262243,2.710524},{1.30393,7.644601,3.110524},{5.051749,7.632096,1.110524},{-1.481048,8.188704,-2.789476}},FruitCenters={{-2.7846719999999996,8.248493641715,2.7000005},{1.30393,7.630850879215,3.1000004999999997},{5.051749,7.618345909215001,1.1000005},{-1.481048,8.174953866715,-2.7999995}},FruitRadii={2.16586497446425,2.3126894044636614,2.09609909083863,2.1350578224952574},Height=16.589552515069,Radius=7.313059001321499,HarvestName="Holo Apple",Tree=true},{Id="NebulaVineSeed",Model="NebulaVine",Name="Nebula Vine",Rarity="Cosmic",Chance=2.5,Seconds=1200,RegrowSeconds=600,Value=32000,FruitCount=3,Sockets={{-1.3,2.15,0.4},{1.43,4.45,0.3},{-0.65,6.58,0.4}},FruitCenters={{-0.7355104641499999,2.15,0.39999999999999997},{0.7782358609234998,4.45,0.3},{-0.48806668098975003,6.58,0.4}},FruitRadii={1.823059448641823,1.9601330668116077,1.4390673639266893},Height=7.529713980057,Radius=2.3598295599999997,HarvestName="Nebula Pod",Tree=false},{Id="CrowncoreTreeSeed",Model="CrowncoreTree",Name="Crowncore Tree",Rarity="King",Chance=0.5,Seconds=1800,RegrowSeconds=900,Value=90000,FruitCount=1,Sockets={{0,5.25,0.4}},FruitCenters={{0.0,5.305392865579,0.4}},FruitRadii={1.7498030241297566},Height=8.35,Radius=3.4146851255345005,HarvestName="Crowncore",Tree=true}}}
C.ById={};for _,s in ipairs(C.Seeds)do C.ById[s.Id]=s end
function C.Is(id)return C.ById[id]~=nil end
function C.Roll(unit)
 if type(unit)~='number'or unit~=unit or math.abs(unit)==math.huge then return nil end
 local ticket=math.clamp(unit,0,1-1e-12)*100
 for _,s in ipairs(C.Seeds)do if ticket<s.Chance then return s end;ticket-=s.Chance end
 return C.Seeds[#C.Seeds]
end
C.Offers={
 {Count=1,GemPrice=80,TargetRobuxPrice=80,Attribute='MechPackProductId'},
 {Count=5,GemPrice=375,TargetRobuxPrice=375,Attribute='MechPack5ProductId'},
 {Count=10,GemPrice=700,TargetRobuxPrice=700,Attribute='MechPack10ProductId'},
}
function C.Offer(count)
 if count==nil then count=1 end
 for _,offer in ipairs(C.Offers)do if count==offer.Count then return offer end end
 return nil
end
function C.ProductId(count)
 local offer=C.Offer(count);if not offer then return 0 end
 local id=tonumber(script:GetAttribute(offer.Attribute))
 return id and id>0 and id<9007199254740991 and id%1==0 and id or 0
end
-- R155 (owner: the card's "LIMITED TIME!" gets a real end, the same as Verity's event): the pack is on sale only while the limited event runs (LimitedEvent.EndsAt,
-- 2026-11-01 00:00 UTC, shared with the Index LIMITED tab and Verity), as well as the owner's own switch (SaleEnabled / SaleEndsAt). `now` (optional, Unix seconds) is the
-- clock to ask (the client passes the server's); the server's os.time() by default. It only gates STARTING a purchase: a Robux receipt that arrives later is still granted
-- (PremiumService:ProcessReceipt never asks), and the packs a player already owns work as before.
local Limited=require(script.Parent.LimitedEvent)
function C.EventOver(now)return not Limited.Active(now or os.time())end
function C.OnSale(now)
 now=now or os.time()
 local untilTime=tonumber(script:GetAttribute('SaleEndsAt'))or 0
 return script:GetAttribute('SaleEnabled')~=false and(untilTime==0 or now<untilTime)and Limited.Active(now)
end
-- The card's words (owner's voice, Verity's "EVENT OVER! THANKS!" style). Refused: what the server says to a purchase started after the end (as VerityConfig.Text.EventEnded).
C.Event={Live='LIMITED TIME!',Prefix='⏳ ENDS IN ',Over='EVENT OVER!',Thanks='THANKS FOR PLAYING!',Button='Event over',Refused='EVENT\'S OVER! THANKS FOR PLAYING!'}
-- R157 (owner: "if bag is full and player tries to buy a pack ... it says bag full"): a full Bag (the 200 cap, InventoryCap155) is not "Unavailable". Both buy buttons read Button and a
-- press shows Notice (client, red, with the Denied click; no purchase prompt); the server refuses a gem purchase or a Robux prompt with the same Notice. Event over / Off sale come first.
C.BagFull={Button='Bag full',Notice='BAG FULL! MAKE ROOM FIRST'}
-- "⏳ ENDS IN 27d 04h 12m 09s" (the Index LIMITED tab's format: LimitedEvent.Text) or, after the end, "THANKS FOR PLAYING!".
function C.TimerText(now)
 if not Limited.Active(now)then return C.Event.Thanks end
 return C.Event.Prefix..Limited.Text(Limited.Left(now))
end
-- R155: every BOUGHT Mech pack rolls a coat like a world pack (PremiumProgress:GrantMechPacks); this is the line next to the odds (shop card, hold tooltip, /test mechshop).
-- The numbers are read from the world packs' own table (SeedPackRules.PackMutations: Gold 4.5%, Diamond 0.5%), so the line can never disagree with the roll.
function C.CoatLine()
 local M=require(script.Parent.SeedPackRules).PackMutations
 local function pct(n)return(string.format('%.2f',n):gsub('0+$',''):gsub('%.$',''))end
 return'Gold '..pct(M.Gold.Weight)..'% / Diamond '..pct(M.Diamond.Weight)..'% coat'
end
function C.ApplyPlants(catalog)
 for _,s in ipairs(C.Seeds)do
  local d=table.clone(s);d.Biome='Mech';d.Mode='repeat';d.BaseScale=1;d.AuthoredHeight=s.Height
  d.Mech=true;d.Rank=({Legendary=4,Mythic=5,Secret=6,Cosmic=7,King=8})[s.Rarity]
  d.HarvestMode='fruit';catalog[s.Id]=d
 end
end
return C
