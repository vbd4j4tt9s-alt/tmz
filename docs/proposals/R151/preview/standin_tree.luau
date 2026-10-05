--!nocheck
-- R151 studded trees: STAND-IN tree models for the offline tests and previews. The owner's Creator Store trees (16637971059 "Stud-Tree",
-- 17280628013 "studded-tree") cannot be downloaded here, so these two stylised studded trees (Plastic blocks with Studs on top, like the
-- classic Roblox trees) stand in for them in ReplicatedStorage.HubTreeTemplates151. They are NOT the owner's models and are not shipped.
-- Usage: require('./standin_tree')(R, folder) -> the two models (9 and 12 parts), parented to folder.
return function(R,folder)
 local V3,CF=R.Vector3.new,R.CFrame.new
 local function part(m,name,size,cf,rgb)
  local p=R.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=R.Color3.fromRGB(rgb[1],rgb[2],rgb[3])
  p.Material=R.Enum.Material.Plastic;p.TopSurface=R.Enum.SurfaceType.Studs;p.BottomSurface=R.Enum.SurfaceType.Inlet
  p.CanCollide=true;p.Anchored=false -- (as a free model would come: the game must switch these off)
  p.Parent=m;return p
 end
 local turn=function(y)return R.CFrame.Angles(0,y,0)end
 local o=CF(1000,0,1000) -- somewhere far away: the game fits and moves each clone
 -- 1. "Stand-in Stud Tree": a square trunk and a stepped crown, 9 parts
 local a=R.new('Model');a.Name='StandInStudTree'
 part(a,'Trunk',V3(2,9,2),o*CF(0,4.5,0),{124,86,52})
 part(a,'Leaves',V3(10,4,10),o*CF(0,9.6,0),{72,158,70})
 part(a,'Leaves',V3(7.4,3.2,7.4),o*CF(0,12.9,0)*turn(math.pi/4),{86,172,78})
 part(a,'Leaves',V3(5,2.6,5),o*CF(0,15.6,0),{98,184,86})
 part(a,'Leaves',V3(2.6,1.8,2.6),o*CF(0,17.6,0)*turn(math.pi/4),{112,194,96})
 part(a,'Leaves',V3(4,3,4),o*CF(5,8.6,0)*turn(.3),{64,146,64})
 part(a,'Leaves',V3(4,3,4),o*CF(-5,8.9,.6)*turn(-.4),{68,150,66})
 part(a,'Leaves',V3(4,3,4),o*CF(.4,9.2,5)*turn(.7),{76,160,70})
 part(a,'Leaves',V3(4,3,4),o*CF(-.3,8.3,-5)*turn(-.2),{70,154,68})
 -- 2. "Stand-in Stud Tree 2": a lumpy crown of turned blocks on a forked trunk, 12 parts
 local b=R.new('Model');b.Name='StandInStudTree2'
 part(b,'Trunk',V3(2.2,7,2.2),o*CF(20,3.5,0),{110,78,50})
 part(b,'Branch',V3(1.2,5,1.2),o*CF(21.6,8.4,.5)*R.CFrame.Angles(0,0,-.5),{110,78,50})
 part(b,'Branch',V3(1.2,5,1.2),o*CF(18.5,8.2,-.4)*R.CFrame.Angles(0,0,.55),{110,78,50})
 local leaves={{0,9.2,0,8,5},{3.6,11.4,1,6,4.2},{-3.4,11.1,-1,6,4},{.6,12.6,-3.2,5.4,3.6},{-.8,12.3,3.4,5.6,3.8},{0,14.7,0,5.2,3.4},
  {3,15.6,-1.4,3.6,2.6},{-2.6,15.9,1.2,3.4,2.4},{.4,17.5,.2,2.4,1.8}}
 for i,l in ipairs(leaves)do part(b,'Leaves',V3(l[4],l[5],l[4]),o*CF(20+l[1],l[2],l[3])*turn(i*.61),{60+i*5,140+i*6,58+i*3})end
 a.Parent=folder;b.Parent=folder
 return a,b
end
