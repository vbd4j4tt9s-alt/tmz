--!nocheck
-- R152 preview helper: draws every RarePullArt image with the REAL module (A.Pattern, the same code the client runs) and prints each as
-- "IMAGE <name> <w> <h> <hex RGBA>" (art_to_png.py turns them into PNGs) plus how long each took on this machine.
local W=require('./world')
local A=W.module('RarePullArt')
local names=NAMES or A.Order
for _,name in ipairs(names)do
 local t0=os.clock()
 local w,h,buf=A.Pattern(name)
 local ms=(os.clock()-t0)*1000
 local hex={}
 for i=0,w*h*4-1 do hex[#hex+1]=string.format('%02x',buffer.readu8(buf,i))end
 print(string.format('IMAGE %s %d %d %s',name,w,h,table.concat(hex)))
 print(string.format('TIME %s %.1f ms',name,ms))
end
