--!nocheck
-- R150 review fix round: how many Instances does the roll screen create on the frame it opens and on the frame the reveal shows? (Instance.new is counted on
-- the Roblox mock with the real TreadmillBonusClient + BonusGiftArt; a phone about 10 to 15 microseconds per created and parented GUI object.)
-- Usage (see run_probe_instances.sh): luau probe_instances.luau  -> prints "OPEN ...", "REVEAL ..." and "TREE ..." lines. test_bonus_ui.luau holds the ceilings.
local UW=require('./ui_world');local W,R=UW.W,UW.R
local C=UW.boot({})
local Rules=C.Rules;local panel=C.Overlay.Panel;local button=C.Button
local made=0
do local inew=R.Instance.new;R.Instance.new=function(...)made+=1;return inew(...)end end
local cases={
 {Rarity='Common',Variant='Pack01',Stage=1,Label='Forest Seed Pack'},{Rarity='Uncommon',Variant='Pack02',Stage=6,Label='Jungle Seed Pack'},
 {Rarity='Rare',Variant='Pack03',Stage=2,Label='Desert Seed Pack'},{Rarity='Epic',Variant='Pack04',Stage=3,Label='Snow Seed Pack'},
 {Rarity='Legendary',Variant='Pack05',Stage=4,Label='Lava Seed Pack'},{Rarity='Mythic',Variant='Pack06',Stage=5,Label='Crystal Seed Pack'},
 {Rarity='Secret',Variant='EclipseReliquary',Stage=7,Label='Void Pack'},
}
local function view(w,h)C.size(w,h);UW.frames(2,1/60)end
for _,v in ipairs({{'desktop',1280,720},{'phone',844,390}})do
 view(v[2],v[3])
 for _,case in ipairs(cases)do
  C.Reply={Ok=true,Stage=case.Stage,Variant=case.Variant,Rarity=case.Rarity,Label=case.Label,Pool='1,6,2,3,4,5,7',Ready=0}
  C.set('Ready',1);UW.frames(1,1/60)
  made=0;button.Activated:Fire();local open=made
  panel.StripWindow.AbsoluteSize=R.Vector2.new(panel.Size.X.Offset-28,panel.StripWindow.Size.Y.Offset)
  local tree=UW.count(C.Overlay)
  UW.frames(10,1/60)
  made=0;panel.Actions.Skip.Activated:Fire();local reveal=made
  print(string.format('%-7s %-10s OPEN %4d   REVEAL %4d   TREE after open %4d, after reveal %4d',v[1],case.Rarity,open,reveal,tree,UW.count(C.Overlay)))
  panel.Actions.Close.Activated:Fire();UW.seconds(2,1/60)
 end
end
