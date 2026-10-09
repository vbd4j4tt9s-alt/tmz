-- R156 (owner: "a pyramid can have the mythic pack of that biome its a one time thing so players collect it once and its gone. the snake will still chase them tho and
-- its same and mutations are all fixed"; "it will just be in the pyramid model no secret passage and no pedestal just a floating pack in the pyramid model which i will
-- send u and we can replace the current pyramid in the game"; "hollow the inside and make sure that players can hold e when looking inside the pyramid").
-- The Desert's secret pyramid, ONE source of numbers for the map pass and the server (ServerScriptService.ChestChaseServer.SecretPyramid156), the client
-- (SecretPyramidClient156: the floating pack and the prompt, per player) and the tests (docs/proposals/R156/tests/run_pyramid156.sh).
--  * MODEL   the owner's Creator Store "Classic Pyramid" (asset 113814131474028), read from his .rbxm (docs/proposals/R156/pyramid/classic_pyramid_parts.json):
--            18 square slabs, 1.639 studs tall, 65.56 wide at the bottom, each 3.278 narrower than the one below, all on one vertical axis, Limestone, colour
--            (248, 217, 109), anchored blocks. P.Slabs holds his sizes and heights to the last digit (bottom first); Scale shrinks all of it the same way.
--  * SCALE   0.6834: the base is 44.80 x 44.80, the Sunscar Pyramid's own footprint (centre X -62.07, ground Y 4, runtime Z 1005). At full size (65.56) it would
--            reach X -94.8, through the Desert's left wall (inner face X -89), and 21 studs further into the running floor than the old one; scaled to the old
--            footprint it keeps the old 4.5-stud walkway along the wall and the old edge toward the track (X -39.7). 18 slabs x 1.12 = 20.16 studs tall.
--  * HOLLOW  slab 1 is a solid floor, the top P.Caps (3) are solid caps, every slab between is a ring of 4 walls one step thick (each ring's inside edge is the
--            outside edge of the slab two above: 3.28 x Scale = 2.24 studs). From outside it is exactly his model; inside each ring reaches one step further in
--            than the one under it, a stepped chamber 15.7 studs high. No opening, no passage, no pedestal. 1 + 14 x 4 + 3 = 60 anchored parts. The walls of one
--            ring only touch along their edges, and no two faces of the model share a plane facing the same way (the z-fighting rule of R149 / R152).
--  * PACK    the Desert's Mythic pack: Stage 2, Pack06 (SeedPackRules: Design 6 = the Mythic tier), size 1, the same odds as a Desert Mythic world pack
--            (OddsVersion = SeedPackRules.OddsVersion at pickup). Its coat is ONE constant, P.Mutation ('None' = plain; the owner: "mutations are all fixed").
--            It floats P.Lift studs over the chamber floor, slowly turning and bobbing (the client's precomputed P.Frames).
--  * REACH   "Hold E" works from anywhere next to the base (corners too) and on the steps: within the base's half-diagonal + P.Margin (6) of the pack, and
--            inside the box of the base + P.Margin around it, from the ground up to the top + P.Margin. Nothing further: no prompt across the track, none from
--            another building (no other scenery stands in that box; the tests check the real map).
--  * SAVED   Premium.Secrets156 = {Pyramid = true} once the pack is BANKED (an optional Premium field: an older server keeps it as it is; ProfileVersion stays 22).
--            Published on the Player as P.Attr: 'Open' (the pack is in the pyramid for you), 'Out' (you are carrying it), 'Claimed'.
local P={Version=156}
-- The owner's slabs, bottom to top: {width X, width Z, height of the slab's centre over the bottom slab's centre} (studs, his .rbxm's float32 values).
P.Slabs={{65.5555648803711,65.5555648803711,0.0},{62.27778244018555,62.27778244018555,1.6388893127441406},{59.00000762939453,59.00000762939453,3.2777786254882812},
 {55.72222900390625,55.72222900390625,4.916667938232422},{52.44445037841797,52.44445037841797,6.5555572509765625},{49.16667175292969,49.16667175292969,8.19444465637207},
 {45.888893127441406,45.888893127441406,9.833333969116211},{42.61111831665039,42.61111831665039,11.472223281860352},{39.33333969116211,39.33333969116211,13.111112594604492},
 {36.05556106567383,36.05556106567383,14.750001907348633},{32.77778244018555,32.77778244018555,16.388891220092773},{29.500003814697266,29.500003814697266,18.02777862548828},
 {26.222225189208984,26.222225189208984,19.666667938232422},{22.944446563720703,22.944446563720703,21.305557250976562},{19.666669845581055,19.666669845581055,22.94444465637207},
 {16.388891220092773,16.388891220092773,24.583334922790527},{13.111090660095215,13.111112594604492,26.22222328186035},{9.833312034606934,9.833334922790527,27.861112594604492}}
P.SlabHeight=1.6388890743255615
P.Color={248,217,109};P.Material='Limestone' -- Material enum 820
P.Scale=0.6834 -- (see SCALE above)
P.Caps=3       -- the top slabs that stay solid
P.Margin=6     -- studs around the base (and over the top) that still reach the pack
P.Below=4      -- studs under the ground a body can be and still count (a pressed key, a shovel hole)
P.Lift=3.5     -- the pack's centre over the chamber floor
-- The pack: the Desert Mythic world pack. P.Mutation is the one switch for its coat ('None' | 'Gold' | 'Diamond').
P.Mutation='None'
P.Pack={Stage=2,BagVariant='Pack06',PackSize=1} -- (no chip-bag shape roll: the design's default shape, like the other special packs, the same on the float, the carry and in the Bag)
-- Where the map pass builds it when the Sunscar Pyramid is not there to measure (its runtime base: centre X / Z, ground Y).
P.Fallback={X=-62.0675,Y=4,Z=1005}
P.ModelName='Biome2_Landmark';P.LandmarkName='Classic Pyramid'
P.Tag='SecretPyramid156'   -- CollectionService tag of the invisible part at the pack's centre (it holds the prompt)
P.AnchorName='SecretPack'
P.Attr='SecretPyramid156'  -- the Player attribute: 'Open' | 'Out' | 'Claimed' (nil while the profile loads)
P.State={Open='Open',Out='Out',Claimed='Claimed'}
P.Flag='Secrets156';P.Key='Pyramid' -- Premium.Secrets156.Pyramid = true
P.Cooldown=1               -- seconds between two triggers of one player that the server looks at
P.Slack=2                  -- studs the server allows over the reach (lag), like the world packs' 24 / 26
P.RefreshGuard=15          -- R157 review fix: no Hold E while the biomes refresh or within this many seconds before (a carry that meets the refresh goes back, never banks)
-- The client: build the pack within BuildIn studs of the camera (let it go past BuildOut), turn it within SpinIn (stop past SpinOut), Rate poses a second.
P.Client={BuildIn=220,BuildOut=260,SpinIn=140,SpinOut=170,Rate=20,Check=.2}
P.Spin={Period=8,BobPeriod=4,Bob=.25}
-- Player-visible text (simple words, "you" / "your").
P.Text={
 Taken='YOU TOOK THE SECRET PACK! RUN TO YOUR BASE!',
 Claimed='🔺 YOU GOT THE SECRET PYRAMID PACK!',
 Caught='CAUGHT! THE PACK WENT BACK IN THE PYRAMID',
 Bat='SMACK! THE PACK WENT BACK IN THE PYRAMID',
 Lightning='ZAP! THE PACK WENT BACK IN THE PYRAMID',
 Lost='THE PACK WENT BACK IN THE PYRAMID. TRY AGAIN!',
 Refresh='BIOMES REFRESHING! THE PACK WENT BACK IN THE PYRAMID',
 RefreshSoon='THE BIOMES REFRESH SOON! TRY AGAIN AFTER THE REFRESH',
}

-- Sizes / heights at a scale: slab i = {x, z, y of its centre over the ground}, the slab height.
local function slab(i,s)local d=P.Slabs[i];return d[1]*s,d[2]*s,(d[3]+P.SlabHeight/2)*s end
-- The parts of the pyramid, in the frame of its base centre on the ground (y up): {Name, Kind ('Floor' | 'Wall' | 'Cap'), Slab, Side, Size = {x, y, z}, Pos = {x, y, z}}.
function P.Plan(scale)
 local s=scale or P.Scale;local h=P.SlabHeight*s;local n=#P.Slabs;local out={}
 for i=1,n do
  local wx,wz,y=slab(i,s)
  local name=string.format('Slab%02d',i)
  if i==1 or i>n-P.Caps then
   out[#out+1]={Name=name,Kind=i==1 and'Floor'or'Cap',Slab=i,Size={wx,h,wz},Pos={0,y,0}}
  else
   local ix,iz=slab(i+2,s) -- the inside edge: the outside of the slab two above (one step = 3.28 x scale thick)
   local a,b,c,d=wx/2,wz/2,ix/2,iz/2
   -- North / South run the full width; East / West sit between them (their ends touch the long walls' inner faces).
   out[#out+1]={Name=name..'N',Kind='Wall',Slab=i,Side='N',Size={2*a,h,b-d},Pos={0,y,(b+d)/2}}
   out[#out+1]={Name=name..'S',Kind='Wall',Slab=i,Side='S',Size={2*a,h,b-d},Pos={0,y,-(b+d)/2}}
   out[#out+1]={Name=name..'E',Kind='Wall',Slab=i,Side='E',Size={a-c,h,2*d},Pos={(a+c)/2,y,0}}
   out[#out+1]={Name=name..'W',Kind='Wall',Slab=i,Side='W',Size={a-c,h,2*d},Pos={-(a+c)/2,y,0}}
  end
 end
 return out
end
-- The numbers of the built pyramid at a scale (studs; heights over the ground): Half (half the base), Top, FloorTop, CeilingY (the caps' underside),
-- FloorHalf (half the chamber at the floor), PackY (the pack's centre), Wall (the walls' thickness), Reach (the prompt's distance), Parts.
function P.Geometry(scale)
 local s=scale or P.Scale;local n=#P.Slabs;local h=P.SlabHeight*s
 local half=P.Slabs[1][1]*s/2
 local floorTop=(P.Slabs[1][3]+P.SlabHeight)*s
 return{Scale=s,Half=half,Width=half*2,SlabHeight=h,Top=(P.Slabs[n][3]+P.SlabHeight)*s,FloorTop=floorTop,CeilingY=P.Slabs[n-P.Caps+1][3]*s,
  FloorHalf=P.Slabs[4][1]*s/2,PackY=floorTop+P.Lift,Wall=(P.Slabs[1][1]-P.Slabs[3][1])*s/2,Reach=P.Reach(s),Parts=1+(n-1-P.Caps)*4+P.Caps}
end
-- The prompt's MaxActivationDistance: the base's half-diagonal + Margin, rounded up to a tenth.
function P.Reach(scale)
 local half=P.Slabs[1][1]*(scale or P.Scale)/2
 return math.ceil((half*math.sqrt(2)+P.Margin)*10)/10
end
-- The zone of a pyramid whose base centre (on the ground) is `center` (Vector3): {Center, Half, Bottom, Top, Pack (Vector3), Reach}.
function P.Zone(center,scale)
 local g=P.Geometry(scale)
 return{Center=center,Half=g.Half,Bottom=center.Y,Top=center.Y+g.Top,Pack=center+Vector3.new(0,g.PackY,0),Reach=g.Reach}
end
-- May a body whose root is at `pos` hold E for the pack? `slack` (studs) widens every limit (the server's lag allowance). Returns true or false, why.
function P.InZone(zone,pos,slack)
 slack=slack or 0
 if typeof(pos)~='Vector3'or type(zone)~='table'then return false,'nothing'end
 local c=zone.Center
 if math.abs(pos.X-c.X)>zone.Half+P.Margin+slack or math.abs(pos.Z-c.Z)>zone.Half+P.Margin+slack then return false,'box'end
 if pos.Y<zone.Bottom-P.Below-slack or pos.Y>zone.Top+P.Margin+slack then return false,'height'end
 if(pos-zone.Pack).Magnitude>zone.Reach+slack then return false,'reach'end
 return true
end
-- The zone as the anchor part carries it (attributes the server writes, the client reads).
function P.WriteZone(anchor,zone)
 anchor:SetAttribute('ZoneCenter',zone.Center);anchor:SetAttribute('ZoneHalf',zone.Half);anchor:SetAttribute('ZoneTop',zone.Top)
 anchor:SetAttribute('ZoneReach',zone.Reach);anchor:SetAttribute('ZonePack',zone.Pack)
end
function P.ReadZone(anchor)
 local c,half,top,reach,pack=anchor:GetAttribute('ZoneCenter'),anchor:GetAttribute('ZoneHalf'),anchor:GetAttribute('ZoneTop'),anchor:GetAttribute('ZoneReach'),anchor:GetAttribute('ZonePack')
 if typeof(c)~='Vector3'or type(half)~='number'or type(top)~='number'or type(reach)~='number'or typeof(pack)~='Vector3'then return nil end
 return{Center=c,Half=half,Bottom=c.Y,Top=top,Pack=pack,Reach=reach}
end
-- The saved claim (Premium.Secrets156.Pyramid == true). Anything else in that field is not a claim.
function P.Claimed(premium)
 local s=type(premium)=='table'and premium[P.Flag]
 return type(s)=='table'and s[P.Key]==true
end
-- The float: the pack's poses through one turn (Rate a second over Period seconds; the bob goes up and down Period / BobPeriod times), made ONCE, so a frame
-- only picks one (nothing is made per frame). Reduced motion: the first pose only.
function P.Frames(center,rate)
 rate=rate or P.Client.Rate
 local n=math.max(1,math.floor(P.Spin.Period*rate+.5));local out=table.create and table.create(n)or{}
 local cycles=P.Spin.Period/P.Spin.BobPeriod
 for i=1,n do
  local u=(i-1)/n
  out[i]=CFrame.new(center.X,center.Y+P.Spin.Bob*math.sin(2*math.pi*u*cycles),center.Z)*CFrame.Angles(0,2*math.pi*u,0)
 end
 return out
end
return P
