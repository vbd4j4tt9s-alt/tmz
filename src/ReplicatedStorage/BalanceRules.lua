-- R67: one shared source for new rolls, movement and sale-preview multipliers.
local B={Version=84,MaxSize=25,SeedHoverSeconds=1,SeedSlideSeconds=.45,SeedRiseSeconds=.35}
local tuning=require(script.Parent.BalanceValues81)
B.SpeedMilestones=tuning.PointCurve
B.TrainingTiers=tuning.MachineMultipliers
B.TrailMultipliers=tuning.TrailMultipliers
B.KeeperOrder={1,6,2,3,4,5,7}
B.KeeperFloors={};B.KeeperCeilings={}
for stage,row in pairs(tuning.KeeperSpeeds)do B.KeeperFloors[stage]=row[1];B.KeeperCeilings[stage]=row[3]end
B.RarityWeights={Common=55,Uncommon=28,Rare=12,Legendary=3.8,Mythic=1,Secret=.16,Cosmic=.035,King=.005}
B.PackSizes={{Scale=.5,Weight=3},{Scale=1,Weight=80.799},{Scale=1.5,Weight=13},{Scale=2.5,Weight=2.8},{Scale=3.5,Weight=.35},{Scale=5,Weight=.04},{Scale=7.5,Weight=.008},{Scale=10,Weight=.002},{Scale=15,Weight=.0007},{Scale=20,Weight=.0002},{Scale=25,Weight=.0001}}
B.MutationWeights={None=95,Gold=4.5,Diamond=.5}
B.MutationInheritance=.20;B.WeatherInheritance=.20
B.WeatherPackChance=.02;B.WeatherFruitChance=.02;B.WeatherPlantChance=.02
local function finite(n,fallback)return type(n)=='number'and n==n and math.abs(n)<math.huge and n or fallback end
function B.Half(n)return math.floor(n*2+.5)/2 end
function B.Training(machine,trail,premium)
 return math.clamp(finite(machine,1),1,30000)*math.clamp(finite(trail,1),1,6)*(premium and 2 or 1)
end
function B.SizeCash(size)return B.Half(1+(math.sqrt(math.clamp(finite(size,1),.5,25))-1)*.5)end
function B.MutationCash(mutation)return mutation=='Diamond'and 3 or mutation=='Gold'and 2 or 1 end
function B.CashMultiplier(sizeBonus,mutation,weatherBonus)
 return B.Half(math.clamp(finite(sizeBonus,1),1,3)+B.MutationCash(mutation)-1+math.clamp(finite(weatherBonus,1),1,4)-1)
end
function B.PlantScale(seed,unit)
 seed=math.clamp(finite(seed,1),.5,25);unit=math.clamp(finite(unit,1),0,1)
 local ticket=unit/math.min(4,1+(seed-1)*.15)
 local gain=ticket<.000001 and 25 or ticket<.00001 and 10 or ticket<.00025 and 5 or ticket<.005 and 2.5 or ticket<.05 and 1.5 or 1
 return math.clamp(B.Half((.75+.25*math.sqrt(seed))*gain),.5,25)
end
function B.SeedPhase(age)
 local rise=math.clamp(age/B.SeedRiseSeconds,0,1)
 local slide=math.clamp((age-B.SeedRiseSeconds-B.SeedHoverSeconds)/B.SeedSlideSeconds,0,1)
 return rise,slide
end
return B
