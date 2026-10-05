--!nocheck
-- R151: prints every part of every pack the game can build, one line per instance with every property that decides how it looks and whether it
-- stays in place (class, name, size, frame in the root's frame / scale, colour, material, transparency, anchored, shape, joints and what they join,
-- Decals, attributes, CollectionService tags), for the BEFORE and the AFTER side of a change (compare_fingerprints.py diffs the two outputs):
--   "PACK <label>"  then one "  <line>" per instance.
-- Matrix: 78 (stage, variant) combinations x sizes .5 / 1 / 2.5 / 10 / 25 x coats None / Gold, built on the ground and held (R15 carrier); the
-- Platform of every stage; the picture build. Run on a checkout's bundle (mkbundle_packs.py OUT SRC): the base commit's src comes from `git archive`.
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local function inv(c)return c:Inverse()end
local function n(v)return string.format('%.5f',v)end
local function ser(v)
 local t=type(v)
 if t=='number'then return n(v)elseif t~='table'then return tostring(v)end
 if v._class then return'<'..v._class..':'..tostring(v._props.Name)..'>'end
 if v.__type=='Vector3'then return'('..n(v.X)..','..n(v.Y)..','..n(v.Z)..')'end
 if v.__type=='Color3'then return'c'..math.floor(v.R*255+.5)..','..math.floor(v.G*255+.5)..','..math.floor(v.B*255+.5)end
 if v.__type=='CFrame'then local r=v.R;return'cf('..n(v.Position.X)..','..n(v.Position.Y)..','..n(v.Position.Z)..';'..n(r[1][1])..','..n(r[1][2])..','..n(r[1][3])..','..n(r[2][1])..','..n(r[2][2])..','..n(r[2][3])..','..n(r[3][1])..','..n(r[3][2])..','..n(r[3][3])..')'end
 if v.__type=='EnumItem'then return v.Name end
 return'{...}'
end
local function lines(bag,carrier)
 local root=bag.PrimaryPart;local scale=bag:GetAttribute('VisualScale')or 1;local rootInv=inv(root.CFrame)
 local out={}
 local function rel(cf)local f=rootInv*cf;return CF(f.Position.X/scale,f.Position.Y/scale,f.Position.Z/scale)*f.Rotation end
 for _,d in ipairs(bag:GetDescendants())do
  local row={d._class,d.Name,'parent='..d.Parent.Name}
  if d:IsA('BasePart')then
   row[#row+1]='size='..ser(d.Size/scale);row[#row+1]='at='..ser(rel(d.CFrame));row[#row+1]='color='..ser(d.Color);row[#row+1]='mat='..ser(d.Material)
   row[#row+1]='t='..n(d.Transparency);row[#row+1]='refl='..n(d.Reflectance or 0);row[#row+1]='anch='..tostring(d.Anchored);row[#row+1]='massless='..tostring(d.Massless)
   row[#row+1]='coll='..tostring(d.CanCollide)..tostring(d.CanTouch)..tostring(d.CanQuery)
   if d._class=='Part'and d.Shape then row[#row+1]='shape='..ser(d.Shape)end
   if d:IsA('MeshPart')then row[#row+1]='mesh='..tostring(d.MeshId)..'/'..tostring(d.TextureID)end
   local tags=W.CS:GetTags(d);table.sort(tags);if#tags>0 then row[#row+1]='tags='..table.concat(tags,'+')end
  elseif d:IsA('WeldConstraint')then row[#row+1]='joins='..tostring(d.Part0 and d.Part0.Name)..'>'..tostring(d.Part1 and d.Part1.Name)..' enabled='..tostring(d.Enabled)
  elseif d:IsA('Motor6D')then row[#row+1]='joins='..tostring(d.Part0 and d.Part0.Name)..'>'..tostring(d.Part1 and d.Part1.Name)..' C0='..ser(d.C0)..' C1='..ser(d.C1)
  elseif d:IsA('Decal')then row[#row+1]='face='..ser(d.Face)..' tex='..tostring(d.Texture)..' t='..n(d.Transparency)..' c='..ser(d.Color3)
  elseif d:IsA('Attachment')then row[#row+1]='cf='..ser(d.CFrame)end
  local keys={};for k in pairs(d:GetAttributes())do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do local v=d:GetAttribute(k);if k~='HoverOrigin'and k~='HoverPhase'and k~='CarryRootOffset'and k~='MysteryOrigin'then row[#row+1]='@'..k..'='..ser(v)end end
  out[#out+1]='  '..table.concat(row,'|')
 end
 local keys={};for k in pairs(bag:GetAttributes())do keys[#keys+1]=k end;table.sort(keys)
 local top={};for _,k in ipairs(keys)do if k~='HoverOrigin'and k~='HoverPhase'and k~='CarryRootOffset'and k~='MysteryOrigin'then top[#top+1]='@'..k..'='..ser(bag:GetAttribute(k))end end
 local tags=W.CS:GetTags(bag);table.sort(tags)
 table.insert(out,1,'  MODEL|'..table.concat(top,'|')..'|tags='..table.concat(tags,'+'))
 return out
end
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
