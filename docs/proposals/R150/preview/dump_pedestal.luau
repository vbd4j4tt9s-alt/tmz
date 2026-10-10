--!nocheck
-- R150 preview dump (not a test): the base's mystery pedestal in each state, its unlock moment and its take flight, as MysteryPackService /
-- MysteryPedestalArt (server) and MysteryPackClient / MysteryPedestalFx (the local player's screen) draw it on the Roblox mock - with whatever src tree
-- this folder was bundled from (this checkout = AFTER, the base commit = BEFORE: R149's pedestal has no fx and its own sign). Prints
-- "SCENE <name> <json>" lines for render_pedestal.mjs. The pack art is not available offline: the pack's stand-in Body is drawn as a pouch.
local H=require('./pedestal_harness');local D=require('./preview_dump');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.clock=20000*86400+3600+7
local me=H.player(77,'Tester',true)
local rec=H.base(1,CF(0,4.5,0))
local O=V3(34,5,75) -- the pedestal's centre on the pad (world)
local stand=V3(34-12,6.5+.5,75-4) -- the player's root: 12 studs out from the column's front, a little to the side
local _,root=H.character(me,stand)
local function figure(at,color) -- a blocky stand-in for the player (feet at at.Y - 3)
 local out={}
 local function box(name,s,p,c)out[#out+1]=string.format('{"n":%s,"sh":"Block","s":%s,"p":%s,"r":[1,0,0,0,1,0,0,0,1],"c":%s,"m":"Plastic","t":0}',D.q(name),D.v3(s),D.v3(p),c)end
 local y=at.Y-3
 box('Leg',V3(.9,2,1),V3(at.X,y+1,at.Z-.5),'[60,70,150]');box('Leg',V3(.9,2,1),V3(at.X,y+1,at.Z+.5),'[60,70,150]')
 box('Torso',V3(1,2,2),V3(at.X,y+3,at.Z),color or'[210,90,70]');box('Arm',V3(1,2,.9),V3(at.X,y+3,at.Z-1.45),color or'[210,90,70]');box('Arm',V3(1,2,.9),V3(at.X,y+3,at.Z+1.45),color or'[210,90,70]')
 box('Head',V3(1.2,1.2,1.2),V3(at.X,y+4.6,at.Z),'[245,205,50]')
 return table.concat(out,',')
end
local function scene(name,view,withFigure)
 local roots={H.model(rec)};local folder=W.workspace:FindFirstChild('MysteryPackFlights');if folder then roots[#roots+1]=folder end
 local json=D.scene(W,roots,view,{MysteryBurst=true,MysteryFlash=true,MysteryPop=true})
 if withFigure then json=json:gsub('"parts":%[','"parts":['..figure(root.Position)..',',1)end
 print('SCENE '..name..' '..json)
end
-- Views (world coordinates; the pedestal is at x 34, z 75 on the pad's top, y 5; its front faces -X, where the aisle is).
local pack=D.v3(V3(34,5+10.2,75))
local VIEWS={
near=D.view(V3(34-22,5+14.5,75-14),V3(34,5+9.2,75),42),      -- the whole pedestal with its sign
 front=D.view(V3(34-10.5,5+4.5,75-3),V3(34-2,5+3.3,75),40), -- the column's front (the padlock)
 top=D.view(V3(34-11.5,5+15.5,75-8),V3(34,5+11.8,75),40),    -- the pack, its halo and the sign close up
 wide=D.view(V3(34-24,5+11,75-19),V3(34-8,5+9,75-2),50),    -- the player and the pedestal
}
-- The pack turns at 0.8 rad/s (MysteryPackClient): wait until its front points at the cameras (the angle theta) so the pack is seen face on.
local function faceAt(theta)local period=2*math.pi/.8;local dt=((theta/.8)-R.clock)%period;R.advance(dt);H.run(1/30)end
H.look(V3(34-22,5+11,75-15),V3(34,5+9,75))
H.publish(rec,'Empty')
H.loadClient()
H.run(.6)
-- LOCKED: a calm violet pedestal (the client's fx are built once the pedestal is near and Locked).
H.publish(rec,'Locked',{Owner=77,Stage=1,UnlockIn=12*60+41})
H.run(2.4);faceAt(1.0)
scene('locked_near',VIEWS.near);scene('locked_front',VIEWS.front);scene('locked_top',VIEWS.top)
-- UNLOCKED: the moment (padlock opens, ring + flash, the pack hops, the sign pops) at +0.12 / +0.3 / +0.6 s, then settled.
faceAt(.55)
H.publish(rec,'Ready',{Owner=77,Stage=1,Variant='Pack03'})
H.run(.12);scene('unlock_a',VIEWS.front);scene('unlock_a2',VIEWS.near)
H.run(.18);scene('unlock_b',VIEWS.front);scene('unlock_b2',VIEWS.near)
H.run(.3);scene('unlock_c',VIEWS.front);scene('unlock_c2',VIEWS.near)
H.run(2.4);faceAt(1.0)
scene('ready_near',VIEWS.near);scene('ready_front',VIEWS.front);scene('ready_top',VIEWS.top)
-- TAKEN: the pack lifts off and flies to the player (+0.1 / +0.35 / +0.55 s), then the dim pedestal.
faceAt(.5)
H.publish(rec,'Claimed',{Owner=77,Stage=1,Variant='Pack03',NextIn=2*3600+46*60})
H.run(.1);scene('take_a',VIEWS.wide,true)
H.run(.25);scene('take_b',VIEWS.wide,true)
H.run(.2);scene('take_c',VIEWS.wide,true)
H.run(2.2)
scene('taken_near',VIEWS.near);scene('taken_front',VIEWS.front);scene('taken_top',VIEWS.top)
-- The pedestal in each biome's colours (a new day: Locked, with the treadmill of each tier) - the same Locked scene, Stage 1..7.
for _,stage in ipairs({1,6,2,3,4,5,7})do
 H.publish(rec,'Locked',{Owner=77,Stage=stage,UnlockIn=15*60})
 H.run(1.2)
 scene('biome_'..stage,VIEWS.near)
end
