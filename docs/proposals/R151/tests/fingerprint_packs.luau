--!nocheck
-- R151: prints every part of every pack the game can build, one line per instance with every property that decides how it looks and whether it
-- stays in place (class, name, size, frame in the root's frame / scale, colour, material, transparency, anchored, shape, joints and what they join,
-- Decals, attributes, CollectionService tags), for the BEFORE and the AFTER side of a change (compare_fingerprints.py diffs the two outputs):
--   "PACK <label>"  then one "  <line>" per instance.
-- Matrix: 78 (stage, variant) combinations x sizes .5 / 1 / 2.5 / 10 / 25 x coats None / Gold, built on the ground and held (R15 carrier); the
-- Platform of every stage; the picture build. Run on a checkout's bundle (mkbundle_packs.py OUT SRC): the base commit's src comes from `git archive`.
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local lines=H.lines
local QUICK=(pcall(require,'./quick_mode'))
local count=0
local function emit(label,bag)print('PACK '..label);for _,l in ipairs(lines(bag))do print(l)end;count+=1;bag:Destroy()end
local sizes=QUICK and{1,25}or{.5,1,2.5,10,25}
for _,stage in ipairs(H.STAGES)do
 local variants={table.unpack(H.ORDINARY)};for _,v in ipairs(H.LEGACY)do variants[#variants+1]=v end;variants[#variants+1]=H.VOID;variants[#variants+1]=H.VERITY
 for _,variant in ipairs(variants)do for _,size in ipairs(sizes)do for _,coat in ipairs({'None','Gold'})do
  emit(('ground %d %s %s %s'):format(stage,variant,size,coat),H.ground(stage,variant,size,coat))
  local held,char=H.held(stage,variant,size,coat,'R15');emit(('held %d %s %s %s'):format(stage,variant,size,coat),held);char:Destroy()
 end end end
 emit(('picture %d Pack06 1 None'):format(stage),H.picture(stage,'Pack06',1,'None'))
 emit(('pad %d Pack03 1'):format(stage),(function()local p=H.Visuals.Platform(CF(0,10,0),stage,'Pack03',1);p.Parent=W.workspace;return p end)())
end
for _,variant in ipairs({H.MECH})do for _,size in ipairs(sizes)do for _,coat in ipairs({'None','Gold'})do
 emit(('ground 8 %s %s %s'):format(variant,size,coat),H.ground(8,variant,size,coat))
 local held,char=H.held(8,variant,size,coat,'R15');emit(('held 8 %s %s %s'):format(variant,size,coat),held);char:Destroy()
end end end
print('COUNT '..count)
