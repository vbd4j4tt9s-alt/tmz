--!nocheck
-- R150 z-fighting scene (not a test by itself; check_pedestal_zfight.py reads it): the base's pad with its mystery pedestal exactly as a player sees it -
-- the server's parts, the client's fx (halo, padlock, light shaft, emitter anchor), the pack - in each biome's colours, Locked and Ready, as "SCENE <name>
-- <json>" lines in the zfight.py scene format (every part's path, size, position, rotation, colour, material, transparency).
local H=require('./pedestal_harness');local W,R=H.W,H.R;local Z=H.Z;local V3,CF=R.Vector3.new,R.CFrame.new
R.clock=20000*86400+3600
local me=H.player(77,'Tester',true);local _,root=H.character(me,V3(22,7.5,71));root.Transparency=1
local rec=H.base(1,CF(0,4.5,0))
H.look(V3(12,16,60),V3(34,14,75))
H.publish(rec,'Empty');H.loadClient();H.run(.6)
local function areaOf(p)
 local path=Z.path(p)
 if path:find('MysteryFx',1,true)then return'fx'end
 if path:find('MysteryPack',1,true)then return'pack'end
 if path:find('MysteryPedestal',1,true)then return'pedestal'end
 return'pad'
end
local function dump(name)
 local parts=Z.dump(rec.Model,areaOf)
 print('SCENE '..name..' {"parts":['..table.concat(parts,',')..']}')
end
for _,stage in ipairs({1,6,2,3,4,5,7})do
 H.publish(rec,'Locked',{Owner=77,Stage=stage,UnlockIn=900});H.run(1)
 dump('locked_'..stage)
 H.publish(rec,'Ready',{Owner=77,Stage=stage,Variant='Pack03'});H.run(3)
 dump('ready_'..stage)
 H.publish(rec,'Claimed',{Owner=77,Stage=stage,Variant='Pack03'});H.run(2)
 dump('taken_'..stage)
end
