-- R149 (owner: "try to take out all the z fighting within the shop and so on"): a few parts SAVED in the place (an installer
-- can only change scripts) lie in the same plane as a neighbour and flicker. MapService.new calls Apply once, first, before
-- any start-up pass moves the map (TrackExpansion83, ForestLayout87 ...), so every part is still where the place saved it.
-- Each fix names one part (its parent's path under ChestChaseMap, its name, the saved CFrame and Size). A part is moved only
-- when exactly one part there matches all of that (position within .02 stud, rotation within .002, size within .02); anything
-- else (a part you edited, moved or deleted) is left alone and counted as skipped. The move is a few hundredths of a stud
-- along the part's own axes. Done parts get the attribute ZFightFix149, so nothing is ever moved twice; one line is logged.
-- The data is written by docs/proposals/R149/tools/zfight_fixlist.py from the z-fighting scene of the R148 map.
local F={Version=149,Position=.02,Rotation=.002,Size=.02}
-- BEGIN DATA (written by docs/proposals/R149/tools/zfight_fixlist.py from the z-fighting scene of the R148 map)
F.Fixes={
 {Path="Obby/Biomes/Biome_1_SUNNY_MEADOW/GeneratedScenery/Left wall bank",Name="Wall bank slope",CFrame={-87.48,6.25,-9.55,1,0,0,0,1,0,0,0,1},Size={3.2,4.5,48.6},Move={0.04,0,0}}, -- Right with Wall bank slope.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_1_SUNNY_MEADOW/GeneratedScenery/Left wall bank",Name="Wall bank slope",CFrame={-87.48,6.75,68.75,1,0,0,0,1,0,0,0,1},Size={3.2,5.5,35.1},Move={0.04,0,0}}, -- Right with Wall bank slope.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_1_SUNNY_MEADOW/GeneratedScenery/Old oak grove",Name="Flower middle",CFrame={52.9741,5.7696,-38.2758,0.995004,0,0.0998334,0,1,0,-0.0998334,0,0.995004},Size={0.56,0.3808,0.56},Move={0,0.04,0}}, -- Bottom with Petals.Bottom (near, offset 0.0112)
 {Path="Obby/Biomes/Biome_1_SUNNY_MEADOW/GeneratedScenery/Old oak grove",Name="Flower middle",CFrame={55.3594,5.7696,-36.9392,0.995004,0,0.0998334,0,1,0,-0.0998334,0,0.995004},Size={0.56,0.3808,0.56},Move={0,0.04,0}}, -- Bottom with Petals.Bottom (near, offset 0.0112)
 {Path="Obby/Biomes/Biome_1_SUNNY_MEADOW/GeneratedScenery/Old oak grove",Name="Flower middle",CFrame={51.9275,5.7696,-35.2441,0.995004,0,0.0998334,0,1,0,-0.0998334,0,0.995004},Size={0.56,0.3808,0.56},Move={0,0.04,0}}, -- Bottom with Petals.Bottom (near, offset 0.0112)
 {Path="Obby/Biomes/Biome_1_SUNNY_MEADOW/GeneratedScenery/Right wall bank",Name="Wall bank slope",CFrame={87.48,6.25,-44.65,1,0,0,0,1,0,0,0,1},Size={3.2,4.5,44.55},Move={-0.04,0,0}}, -- Left with Wall bank slope.Right (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_1_SUNNY_MEADOW/GeneratedScenery/Right wall bank",Name="Wall bank slope",CFrame={87.48,6.75,27.125,1,0,0,0,1,0,0,0,1},Size={3.2,5.5,32.175},Move={-0.04,0,0}}, -- Left with Wall bank slope.Right (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_2_GOLDEN_DESERT/GeneratedScenery/Left wall bank",Name="Wall bank slope",CFrame={-87.48,6.25,514.79,1,0,0,0,1,0,0,0,1},Size={3.2,4.5,58.32},Move={0.04,0,0}}, -- Right with Wall bank slope.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_2_GOLDEN_DESERT/GeneratedScenery/Left wall bank",Name="Wall bank slope",CFrame={-87.48,6.75,608.75,1,0,0,0,1,0,0,0,1},Size={3.2,5.5,42.12},Move={0.04,0,0}}, -- Right with Wall bank slope.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_2_GOLDEN_DESERT/GeneratedScenery/Right wall bank",Name="Wall bank slope",CFrame={87.48,6.25,472.67,1,0,0,0,1,0,0,0,1},Size={3.2,4.5,53.46},Move={-0.04,0,0}}, -- Left with Wall bank slope.Right (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_2_GOLDEN_DESERT/GeneratedScenery/Right wall bank",Name="Wall bank slope",CFrame={87.48,6.75,558.8,1,0,0,0,1,0,0,0,1},Size={3.2,5.5,38.61},Move={-0.04,0,0}}, -- Left with Wall bank slope.Right (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_3_FROSTLAND/GeneratedScenery/Left wall bank",Name="Wall bank slope",CFrame={-87.48,6.75,923.75,1,0,0,0,1,0,0,0,1},Size={3.2,5.5,49.14},Move={0.04,0,0}}, -- Right with Wall bank slope.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_3_FROSTLAND/GeneratedScenery/Right wall bank",Name="Wall bank slope",CFrame={87.48,6.75,865.475,1,0,0,0,1,0,0,0,1},Size={3.2,5.5,45.045},Move={-0.04,0,0}}, -- Left with Wall bank slope.Right (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_5_CRYSTAL_WILDS/BiomeScenesV092/Crystal bed 1/Crystal",Name="CrystalFacet",CFrame={56.8412,6.53483,1421.61,-0.992573,0.0171582,0.120437,-0.121578,-0.105305,-0.98698,-0.00425217,-0.994292,0.106609},Size={0.038976,1.09361,3.94548},Move={1.52e-05,0.03856,-0.01068}}, -- Top with CrystalFacet.Right (near, offset 0.0135)
 {Path="Obby/Biomes/Biome_5_CRYSTAL_WILDS/BiomeScenesV092/Crystal bed 3/Crystal",Name="CrystalFacet",CFrame={64.1126,6.77711,1535.14,0.991807,0.0100727,0.127348,-0.121586,0.380239,0.916862,-0.0391873,-0.924834,0.378348},Size={0.0428736,1.0225,4.38604},Move={5.542e-06,0.03897,-0.009093}}, -- Top with CrystalFacet.Right (near, offset 0.0162)
 {Path="Obby/Biomes/Biome_6_JUNGLE/GeneratedScenery/Left wall bank",Name="Wall bank slope",CFrame={-87.48,6.25,231.335,1,0,0,0,1,0,0,0,1},Size={3.2,4.5,63.18},Move={0.04,0,0}}, -- Right with Wall bank slope.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_6_JUNGLE/GeneratedScenery/Left wall bank",Name="Wall bank slope",CFrame={-87.48,6.75,333.125,1,0,0,0,1,0,0,0,1},Size={3.2,5.5,45.63},Move={0.04,0,0}}, -- Right with Wall bank slope.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_6_JUNGLE/GeneratedScenery/Lost stone gate",Name="Moss on stone",CFrame={52.9522,22.704,268,0.996802,0,-0.0799147,0,1,0,0.0799147,0,0.996802},Size={7.392,0.448,7.392},Move={0,-0.06,0}}, -- Bottom with Broken arch.Bottom (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_6_JUNGLE/GeneratedScenery/Lost stone gate",Name="Moss on stone",CFrame={73.0478,22.704,269.611,0.996802,0,-0.0799147,0,1,0,0.0799147,0,0.996802},Size={7.392,0.448,7.392},Move={0,-0.06,0}}, -- Bottom with Broken arch.Bottom (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_6_JUNGLE/GeneratedScenery/Right wall bank",Name="Wall bank slope",CFrame={87.48,6.25,185.705,1,0,0,0,1,0,0,0,1},Size={3.2,4.5,57.915},Move={-0.04,0,0}}, -- Left with Wall bank slope.Right (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_6_JUNGLE/GeneratedScenery/Right wall bank",Name="Wall bank slope",CFrame={87.48,6.75,279.012,1,0,0,0,1,0,0,0,1},Size={3.2,5.5,41.8275},Move={-0.04,0,0}}, -- Left with Wall bank slope.Right (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_7_STORM_PEAKS/GeneratedScenery/Left rocky edge",Name="Uneven rock bank",CFrame={-87.48,7.5,1969.78,1,0,0,0,1,0,0,0,1},Size={3.2,7,61.2},Move={0.04,0,0}}, -- Right with Uneven rock bank.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_7_STORM_PEAKS/GeneratedScenery/Left rocky edge",Name="Uneven rock bank",CFrame={-87.48,6.5,2079.57,1,0,0,0,1,0,0,0,1},Size={3.2,5,34.2},Move={0.04,0,0}}, -- Right with Uneven rock bank.Left (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_7_STORM_PEAKS/GeneratedScenery/Right rocky edge",Name="Uneven rock bank",CFrame={87.48,7.5,1897.79,1,0,0,0,1,0,0,0,1},Size={3.2,7,56.1},Move={-0.04,0,0}}, -- Left with Uneven rock bank.Right (coplanar, offset 0.0000)
 {Path="Obby/Biomes/Biome_7_STORM_PEAKS/GeneratedScenery/Right rocky edge",Name="Uneven rock bank",CFrame={87.48,6.5,1998.44,1,0,0,0,1,0,0,0,1},Size={3.2,5,31.35},Move={-0.04,0,0}}, -- Left with Uneven rock bank.Right (coplanar, offset 0.0000)
}
-- END DATA
local function close(part,fix)
 local c=fix.CFrame;local cf=part.CFrame;local s=part.Size
 if math.abs(cf.X-c[1])>F.Position or math.abs(cf.Y-c[2])>F.Position or math.abs(cf.Z-c[3])>F.Position then return false end
 if math.abs(s.X-fix.Size[1])>F.Size or math.abs(s.Y-fix.Size[2])>F.Size or math.abs(s.Z-fix.Size[3])>F.Size then return false end
 -- rotation: the saved matrix rows are c[4..12]; compare the right / up / back columns
 local r,u,b=cf.RightVector,cf.UpVector,-cf.LookVector
 local cols={{r.X,r.Y,r.Z},{u.X,u.Y,u.Z},{b.X,b.Y,b.Z}}
 for k=1,3 do for row=1,3 do if math.abs(cols[k][row]-c[3+(row-1)*3+k])>F.Rotation then return false end end end
 return true
end
-- Every instance at a path (folders and models with the same name are all searched).
local function at(root,path)
 local list={root}
 for name in string.gmatch(path,'[^/]+')do
  local nextList={}
  for _,node in ipairs(list)do for _,child in ipairs(node:GetChildren())do if child.Name==name then nextList[#nextList+1]=child end end end
  list=nextList
 end
 return list
end
function F.Find(map,fix)
 local found={}
 for _,parent in ipairs(at(map,fix.Path))do
  for _,child in ipairs(parent:GetChildren())do
   if child.Name==fix.Name and child:IsA('BasePart')and close(child,fix)then found[#found+1]=child end
  end
 end
 return found
end
-- Returns how many parts were moved now.
function F.Apply(map,quiet)
 if not map or map:GetAttribute('ZFightFix149')~=nil then return 0 end
 local moved,skipped=0,0
 for _,fix in ipairs(F.Fixes)do
  local found=F.Find(map,fix)
  local part=#found==1 and found[1]or nil
  if part and part:GetAttribute('ZFightFix149')==nil then
   part.CFrame=part.CFrame*CFrame.new(fix.Move[1],fix.Move[2],fix.Move[3])
   part:SetAttribute('ZFightFix149',true);moved+=1
  else skipped+=1 end
 end
 map:SetAttribute('ZFightFix149',moved)
 if not quiet then print(('[R149] Z-fighting fix: %d of %d place parts moved a few hundredths of a stud (%d skipped: not found or changed).'):format(moved,#F.Fixes,skipped))end
 return moved
end
return F
