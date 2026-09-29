#!/usr/bin/env python3
"""Bundle real ReplicatedStorage module sources into one Luau file with Roblox mocks.
Usage: bundle.py <driver.luau> <out.luau> [Name=path-override ...]
Modules are loaded lazily by name through a mock ReplicatedStorage."""
import sys, os, re
SRC = os.environ.get('CC_SRC', '/home/user/tmz/src/ReplicatedStorage')
driver, out = sys.argv[1], sys.argv[2]
overrides = dict(a.split('=', 1) for a in sys.argv[3:])
names = ['BalanceValues81','PackOdds81','EconomyBalance90','EconomyScaling91','RouteBalance83','BalanceRules',
         'SeedPackRules','SpeedPoints','Progression81','PackSchedule81','VoidPackOdds85','MechCatalog','SizeNumbers',
         'RarityRevealSequence','KeeperPursuit','KeeperCombat','RunnerMotion','OddsText85','RarePackRules','WeatherTraits','PlantCatalog','PackOdds111']
parts = []
for n in names:
    p = overrides.get(n, os.path.join(SRC, n + '.lua'))
    s = open(p, 'rb').read().decode('utf-8') if os.path.exists(p) else 'return nil'
    lvl = 1
    while ('[' + '=' * lvl + '[') in s or (']' + '=' * lvl + ']') in s:
        lvl += 1
    parts.append('SOURCES[%r]=[%s[%s]%s]' % (n, '=' * lvl, s, '=' * lvl))
prelude = r'''
local SOURCES={}
%s
local function stub(name) return setmetatable({Name=name},{__index=function(t,k) return function() return stub(k) end end}) end
local C3={};C3.__index=C3
function C3:Lerp(o,a) return self end
Color3={fromRGB=function(r,g,b) return setmetatable({R=r,G=g,B=b},C3) end,new=function(r,g,b) return setmetatable({R=r,G=g,B=b},C3) end}
Enum=setmetatable({},{__index=function(t,k) return setmetatable({},{__index=function(_,m) return m end}) end})
Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end,zero={X=0,Y=0,Z=0}}
typeof=type
local RS; local cache={}; local proxies={}
local function proxy(name)
 if proxies[name] then return proxies[name] end
 local p={Name=name,__module=true,Parent=nil,GetAttribute=function() return nil end,SetAttribute=function() end}
 proxies[name]=p; return p
end
RS=setmetatable({WaitForChild=function(self,n) return self[n] end,FindFirstChild=function(self,n) return SOURCES[n] and self[n] or nil end},
 {__index=function(t,k) local p=proxy(k); p.Parent=t; return p end})
local STUBS={GardenTheme={Rarities={},Rarity=function() return {} end},TreeReworkArt={ApplyCatalog=function() end},RarityPlantArt={ApplyCatalog=function() end},ApprovedPlantCatalog={}}
local realRequire=require
function require(p)
 if type(p)~='table' or not p.__module then return realRequire(p) end
 local n=p.Name
 if cache[n]~=nil then return cache[n] end
 if STUBS[n] then cache[n]=STUBS[n]; return STUBS[n] end
 local src=SOURCES[n]; assert(src,'no source for '..n)
 local f,err=loadstring(src,n); assert(f,err)
 local env=setmetatable({script=p},{__index=getfenv(1)})
 setfenv(f,env)
 local r=f(); cache[n]=r; return r
end
game={GetService=function(self,s) if s=='ReplicatedStorage' then return RS end
 if s=='RunService' then return {IsStudio=function() return false end,IsRunning=function() return false end} end
 return stub(s) end}
RS_MOD=function(n) return require(RS[n]) end
''' % '\n'.join(parts)
open(out, 'w').write(prelude + '\n' + open(driver).read())
