--!nocheck
-- R152 z-fighting scene (not a test by itself; check_giveaway_zfight.py reads it): the giveaway pedestal exactly as a player sees it - the server's parts, the client's pack
-- (the real Void art on stand-in meshes), its effects and the sign - standing on the hub's plaza (the lobby floor and the "Fountain plaza" disc as HubDecor151 builds it),
-- in the zfight.py scene format ("SCENE <name> <json>": every part's path, size, position, rotation, colour, material, transparency, SurfaceGui faces).
local G=require('./giveaway_harness');local H,W,R=G.H,G.W,G.R;local V3,CF=R.Vector3.new,R.CFrame.new;local Z=H.Z
R.clock=20000*86400+3600
local me=H.player(77,'Tester',true);H.character(me,V3(0,5,-370))
local b=G.backend();local s=G.server(b,nil,{FreshMap=true,Name='A'});s.Svc:Start()
local root=s.Root
-- the plaza: HubDecor151 buildPaths: disc 'Fountain plaza' = K.VCyl(r 21 -> d 42, y 3.9 .. 4.26, brick cobble), on the lobby floor (top 4)
local decor=R.new('Folder');decor.Name='HubDecor151';decor.Parent=root
local plaza=R.new('Part');plaza.Name='Fountain plaza';plaza.Shape=R.Enum.PartType.Cylinder;plaza.Size=V3(.36,42,42);plaza.CFrame=CF(0,4.08,-392)*R.CFrame.Angles(0,0,math.pi/2)
plaza.Color=R.Color3.fromRGB(190,110,80);plaza.Material=R.Enum.Material.Brick;plaza.Anchored=true;plaza.Parent=decor
G.look(V3(0,10,-360),V3(0,18,-392));G.loadClient();G.run(2)
local function areaOf(p)
 local path=Z.path(p)
 if path:find('VoidGiveawayPacks152',1,true)then return'pack'end
 if path:find('_VoidPackFx122',1,true)then return'fx'end
 if path:find('VoidGiveaway152',1,true)then return'pedestal'end
 if path:find('HubDecor151',1,true)then return'plaza'end
 return'floor'
end
local function scene(name)
 local parts=Z.dump(W.workspace,areaOf)
 print('SCENE '..name..' {"parts":['..table.concat(parts,',')..']}')
end
scene('open')
s.Svc:_force(500);G.run(1);scene('empty')
s.Svc:_force(13);me:SetAttribute('VoidGift152','Claimed');G.run(1);scene('claimed')
