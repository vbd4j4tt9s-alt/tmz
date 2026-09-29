-- R47: cosmetic-only rules. Tiers are selected by the server's treadmill biome name.
local R={Interval=.05,Range=160,MaxCharacters=8,MaxMarks=64,MarkSpacing=2.0,MarkInterval=.09}
R.Themes={
 Lava={Color=Color3.fromRGB(255,140,53),Tail=Color3.fromRGB(195,62,35),Life=.85,Kind='Ember'},
 Crystal={Color=Color3.fromRGB(193,152,250),Tail=Color3.fromRGB(115,178,237),Life=1,Kind='Crystal'},
 Storm={Color=Color3.fromRGB(177,232,255),Tail=Color3.fromRGB(94,146,248),Life=.65,Kind='Lightning'},
}
function R.Theme(biome)return R.Themes[biome]end
function R.Moving(speed,alive,blocked)return alive and not blocked and speed>3.5 end
function R.Ground(speed,grounded,alive,blocked)return grounded and R.Moving(speed,alive,blocked)end
function R.Discontinuous(distance,dt,speed)
 return dt>.25 or distance>math.max(18,math.max(0,speed)*dt*2+7)
end
function R.Lifetime(speed)return math.clamp(48/math.max(1,speed),.045,1.8)end
return R
