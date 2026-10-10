local A={};local Tags=game:GetService('CollectionService')
function A.Set(model,weather,mech,radius,height)
 local p=model:IsA('BasePart')and model or model.PrimaryPart
 if not p then return end
 p:SetAttribute('WeatherTrait',require(script.Parent.WeatherTraits).Key(weather))
 if mech~=nil then p:SetAttribute('MechFX',mech==true)end
 p:SetAttribute('EffectRadius',math.clamp(radius or 1,.2,45));p:SetAttribute('EffectHeight',math.clamp(height or 2,.2,70))
 Tags:AddTag(p,'GardenItemFX')
end
-- R158d (owner: "the mech pack seeds ... their effects are already there even before the pack opens. This ruins the surprise of the pack opening"): a seed that
-- sits HIDDEN inside an opening pack (SeedPackClient's reward seed, RarePullScenes' hero seed) shows nothing of its own until it is revealed. ItemCosmetics draws a
-- seed's scanner (a Mech seed) and weather effect OUTSIDE the model, for every part that carries the GardenItemFX tag, and the seed's own sparkles / lights / outlines
-- are instances inside it: neither is hidden by hiding the seed's parts, so the Mech scanner's cyan / yellow dashes floated round the closed pack (and gave away
-- a Mech seed in a Void or Verity pack). Hold(model) marks the anchor part (ItemCosmetics draws nothing for a held part and looks again the frame it is released);
-- with `instances` true it also switches off every effect built into the model (and remembers which were on); Release(model) gives all of it back at the reveal.
A.HoldAttribute='FxHeld'
local EFFECTS={ParticleEmitter=true,Beam=true,Trail=true,PointLight=true,SpotLight=true,SurfaceLight=true,BillboardGui=true,SurfaceGui=true,Highlight=true,Fire=true,Smoke=true,Sparkles=true}
local held=setmetatable({},{__mode='k'}) -- model -> {{instance, wasEnabled}}
local function anchor(model)return model:IsA('BasePart')and model or model.PrimaryPart end
function A.Hold(model,instances)
 if typeof(model)~='Instance'then return end
 local p=anchor(model);if p then p:SetAttribute(A.HoldAttribute,true)end
 if instances and not held[model]then
  local list={};held[model]=list
  for _,d in ipairs(model:GetDescendants())do
   if EFFECTS[d.ClassName]then
    list[#list+1]={d,d.Enabled}
    if d.Enabled then d.Enabled=false end
    if d:IsA('ParticleEmitter')then d:Clear()end
   end
  end
 end
end
function A.Release(model)
 if typeof(model)~='Instance'then return end
 local p=anchor(model);if p and p:GetAttribute(A.HoldAttribute)~=nil then p:SetAttribute(A.HoldAttribute,nil)end
 local list=held[model]
 if list then
  held[model]=nil
  for _,e in ipairs(list)do if e[2]and e[1].Parent then e[1].Enabled=true end end
 end
end
function A.Held(part)return typeof(part)=='Instance'and part:GetAttribute(A.HoldAttribute)==true end
return A
