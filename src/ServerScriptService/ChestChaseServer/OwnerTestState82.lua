-- Server memory only. A recipient of an owner action never gains command authority.
local S={};local records=setmetatable({},{__mode='k'})
local function record(p)records[p]=records[p]or{};return records[p]end
-- R158f (owner: "give me creative mode"): CREATIVE MODE of one player, session only (never saved, gone when they leave). The server alone decides it: only the owner's /test creative sets it
-- (OwnerCreative158f); the attribute CreativeMode158f is a hint for that player's screen (the badge, the instant steal hold, the bat without a cooldown), never read by the server. A respawn
-- keeps it (Clear does not touch it); Leave ends it. While on: no cooldowns, keepers / bats / lightning / holes cannot hit the player, the Bag has no 200 cap, plants ripen at once, a high
-- walk speed, fly, and the anti-cheat (MovementGuard, SecurityGate, BatLagComp) lets them be.
local creative=setmetatable({},{__mode='k'});local creativeSpeed=setmetatable({},{__mode='k'})
S.CreativeWalkSpeed=200 -- the walk speed creative mode gives (24 - 500; /test creative speed <n|off> changes it, /test movespeed <n> overrides it)
function S.Creative(p)return p~=nil and creative[p]==true end
function S.SetCreative(p,on)
 if on then creative[p]=true else creative[p]=nil;creativeSpeed[p]=nil end
 p:SetAttribute('CreativeMode158f',on and true or nil)
 if on then record(p).Movement=true;p:SetAttribute('OwnerMovementGranted82',true)else S.ClearMovement(p)end -- (off: flying and noclip stop with it)
end
-- nil = back to the earned speed while creative; a number 24 - 500 = that walk speed (S.CreativeWalkSpeed until one is set)
function S.SetCreativeSpeed(p,n)
 assert(n==nil or(type(n)=='number'and n==n and n>=24 and n<=500),'Creative walk speed must be 24–500')
 creativeSpeed[p]=n==nil and false or n
end
function S.GetCreativeSpeed(p)
 if not creative[p]then return nil end
 local v=creativeSpeed[p];if v==false then return nil end
 return v or S.CreativeWalkSpeed
end
function S.GetSpeed(p)
 local r=p and records[p]
 if r and r.Speed then return r.Speed end
 return p and creative[p]and S.GetCreativeSpeed(p)or nil
end
function S.SetSpeed(p,n)
 assert(n==nil or(type(n)=='number'and n==n and n>=24 and n<=500),'Physical override must be 24–500')
 record(p).Speed=n;p:SetAttribute('OwnerPhysicalSpeed82',n)
end
function S.GrantMovement(p)record(p).Movement=true;p:SetAttribute('OwnerMovementGranted82',true)end
function S.MovementGranted(p)return p and((records[p]and records[p].Movement==true)or creative[p]==true)or false end
function S.ClearMovement(p)
 if records[p]then records[p].Movement=nil end
 p:SetAttribute('OwnerMovementGranted82',creative[p]==true);p:SetAttribute('StudioTestFlying',false);p:SetAttribute('StudioTestNoclip',false)
end
function S.Clear(p)
 records[p]=nil;p:SetAttribute('OwnerPhysicalSpeed82',nil);p:SetAttribute('OwnerAnimationRate82',nil);S.ClearMovement(p)
end
-- The player left (or the owner tools stopped): creative goes with them.
function S.Leave(p)
 S.SetCreative(p,false);S.Clear(p)
end
return S
