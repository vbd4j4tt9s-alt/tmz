-- Server memory only. A recipient of an owner action never gains command authority.
local S={};local records=setmetatable({},{__mode='k'})
local function record(p)records[p]=records[p]or{};return records[p]end
function S.GetSpeed(p)return p and records[p]and records[p].Speed or nil end
function S.SetSpeed(p,n)
 assert(n==nil or(type(n)=='number'and n==n and n>=24 and n<=500),'Physical override must be 24–500')
 record(p).Speed=n;p:SetAttribute('OwnerPhysicalSpeed82',n)
end
function S.GrantMovement(p)record(p).Movement=true;p:SetAttribute('OwnerMovementGranted82',true)end
function S.MovementGranted(p)return p and records[p]and records[p].Movement==true or false end
function S.ClearMovement(p)
 if records[p]then records[p].Movement=nil end
 p:SetAttribute('OwnerMovementGranted82',false);p:SetAttribute('StudioTestFlying',false);p:SetAttribute('StudioTestNoclip',false)
end
function S.Clear(p)
 records[p]=nil;p:SetAttribute('OwnerPhysicalSpeed82',nil);p:SetAttribute('OwnerAnimationRate82',nil);S.ClearMovement(p)
end
return S
