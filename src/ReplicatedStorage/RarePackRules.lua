-- R98: joint spawn outcome odds, strictly below 1%; no balance changes.
local P=require(script.Parent.SeedPackRules)
local W=require(script.Parent.WeatherTraits)
local R={Threshold=.01}
-- R112: only these PackTiers are announced (owner: "legendary or above"); every such spawn is announced.
R.NoticeTiers={Legendary=true,Mythic=true}
function R.Notifies(tierName)return R.NoticeTiers[tierName]==true end
function R.TierProbabilities(cycle,count)
 local weights={};for i,key in ipairs(P.VariantOrder)do weights[i]=P.Variants[key].SpawnWeight end
 local values=require(script.Parent.PackSchedule81).Probabilities(cycle or 0,count,weights)
 local result={};for i,key in ipairs(P.VariantOrder)do result[key]=values[i]end;return result
end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function R.Probability(variant,size,mutation,context)
 if variant=='MechLimited'or variant=='EclipseReliquary'or not table.find(P.VariantOrder,variant)then return nil end
 if not finite(size)or P.MutationKey(mutation)~=mutation then return nil end
 context=type(context)=='table'and context or{}
 local tier=context.TierProbability
 if tier==nil then local total=0;for _,key in ipairs(P.VariantOrder)do total+=P.Variants[key].SpawnWeight end;tier=P.Variants[variant].SpawnWeight/total end
 local sizeChance=0;for _,row in ipairs(P.PackSizes)do if row.Scale==size then sizeChance+=row.Weight/100 end end
 if context.ForcedSize then sizeChance=1 end
 local mutationChance=context.ForcedMutation and 1 or P.PackMutations[mutation].Weight/100
 local weather=context.WeatherProbability or 1
 if not finite(tier)or tier<=0 or tier>1 or not finite(weather)or weather<=0 or weather>1 or sizeChance<=0 then return nil end
 return tier*sizeChance*mutationChance*weather
end
function R.Qualifies(variant,size,mutation,context)
 local odds=R.Probability(variant,size,mutation,context)
 return odds~=nil and odds<R.Threshold
end
function R.Message(stage,variant,size,mutation,context)
 local odds=R.Probability(variant,size,mutation,context)
 local tier=P.GetPackTier(variant)
 if not odds or not R.Notifies(tier.Name)then return nil end
 local words={};local weather=W.Key(context and context.Weather)
 if weather~='None'then table.insert(words,W.Display(weather))end
 if mutation~='None'then table.insert(words,mutation)end
 if size~=1 then local ok,kg=pcall(function()return require(script.Parent.ItemWeight).Text('Pack',variant,size)end);table.insert(words,ok and kg or tostring(size)..'x')end -- R112: pack weight in kg
 table.insert(words,tier.Name..' Pack')
 return {Text=table.concat(words,' '),Biome=P.DesignBiomes[stage]or'Biome',Stage=stage,Tier=tier.Name,Size=size,Mutation=mutation,Weather=weather,Probability=odds,Color=tier.Color}
end
return R
