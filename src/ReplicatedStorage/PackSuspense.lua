-- R151 (owner: "for the pack animations add more suspense to opening the pack in general"): the light inside a pack while it builds up,
-- seen by everyone near the opener (SeedPackClient draws the opening pack for every viewer). The seam glows and pulses, flares on every
-- wobble, and a rarity HINT colour flickers through it: neutral first, then up the ladder through every lower tier's colour to the real
-- one (RarePullRules.Hint, Sol's RNG "it could be..."), then it flashes out with the burst. The wobble and the bit-by-bit tear are
-- RarePullRules.Wobble / StripPeel, applied by SeedPackClient to the pack itself. Cheap: one neon slab, one light, one Highlight
-- (no Highlight on low quality / FastMode); nothing is left once the reveal ends.
local Rules=require(script.Parent.RarePullRules)
local P={};P.__index=P
function P.Create(parent,rank,scale,quick,lite)
 local self=setmetatable({Rank=rank,Scale=math.clamp(tonumber(scale)or 1,.3,25),Quick=quick==true,BurstAt=Rules.BurstAt(rank,quick)},P)
 local glow=Instance.new('Part');glow.Name='Pack seam glow';glow.Anchored=true;glow.CanCollide=false;glow.CanTouch=false;glow.CanQuery=false;glow.CastShadow=false
 glow.Material=Enum.Material.Neon;glow.Color=Rules.Neutral;glow.Transparency=1;glow.Size=Vector3.new(1.55,.05,.22)*self.Scale;glow.Parent=parent;self.Glow=glow
 local light=Instance.new('PointLight');light.Name='Pack hint light';light.Color=Rules.Neutral;light.Brightness=0;light.Range=6*math.min(self.Scale,4);light.Shadows=false;light.Parent=glow;self.Light=light
 if not lite then
  local h=Instance.new('Highlight');h.Name='Pack hint';h.FillColor=Rules.Neutral;h.OutlineColor=Rules.Neutral;h.FillTransparency=1;h.OutlineTransparency=1
  h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Parent=parent;self.Highlight=h
 end
 return self
end
function P:SetPack(model)if self.Highlight then self.Highlight.Adornee=model end end
-- mouth: CFrame of the pack's mouth (its seam); t: seconds after RevealAt.
function P:Update(mouth,t)
 if self.Destroyed then return end
 local q=math.clamp(t/self.BurstAt,0,1)
 local color,strength=Rules.Hint(self.Rank,q)
 local glow=Rules.Glow(self.Rank,t,self.Quick)
 local shown=t>=0 and glow>.01
 self.Glow.CFrame=mouth*CFrame.new(0,.02*self.Scale,0)
 self.Glow.Color=color;self.Glow.Transparency=shown and math.clamp(1-glow*(.35+.6*strength),0,1)or 1
 self.Glow.Size=Vector3.new(1.55*math.clamp(.25+q,0,1),.05+.05*glow,.22)*self.Scale
 self.Light.Color=color;self.Light.Brightness=shown and glow*(1.2+1.8*strength)or 0
 if self.Highlight then
  self.Highlight.FillColor=color;self.Highlight.OutlineColor=color
  self.Highlight.FillTransparency=t<self.BurstAt and math.clamp(1-glow*.38,0,1)or 1
  self.Highlight.OutlineTransparency=t<self.BurstAt and math.clamp(1-glow*.8,0,1)or 1
 end
 self.Color=color;self.Strength=glow
end
function P:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true;self.Glow:Destroy();if self.Highlight then self.Highlight:Destroy()end
end
return P
