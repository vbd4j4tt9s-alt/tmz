--!nocheck
-- R152 z-fighting, the baked keepers: dumps what check_keeper_zfight.py needs, on the Roblox mock with the REAL modules (run_keepers.sh / run_zfight_keepers.sh bundle them):
--  * every keeper's decoded mesh (KeeperMeshes152.Decode, the game's own decoder: vertices in studs, rig space - The Darkened group-local - and triangles),
--  * each part's config (group, kind, face state, the golem's tree rest / size),
--  * the group frames of the two poses the player sees a keeper still in: REST (awake, standing: BeastPose.Frames awake = 1 / VeiledKeeper81.Frames awake) and ASLEEP (awake = 0),
--    through the game's own pose code with the R152 variant (floor samples of the new models). Parts follow BeastAnimation: awake = group frame * rest, asleep golem = its tree rest + size.
-- Output lines: "KEEPER key stage", "PART ...", "V x y z ..." / "T a b c ..." (1-based) per part, "FRAME key state group 12 numbers".
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
W.Run.IsServer=function()return true end
local Meshes=W.module('KeeperMeshes152');local Cfg=W.module('KeeperRigConfig152');local Pose=W.module('BeastPose')
local out={}
local function put(s)out[#out+1]=s end
local function n(x)local s=string.format('%.5f',x);if s=='-0.00000'then s='0.00000'end;return s end
local function cf(c)local t={c:GetComponents()};for i,v in ipairs(t)do t[i]=n(v)end;return table.concat(t,' ')end
local function frames(key,state,f)
 local keys={};for k in pairs(f)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do put('FRAME '..key..' '..state..' '..k..' '..cf(f[k]))end
end
-- The Darkened's pose frames (the real VeiledKeeper81.Frames on a root at the origin): asleep (GUARDING) and awake and standing (ALERTED, awake for good)
local Veiled=W.module('VeiledKeeper81')
local function darkened(state)
 local m=R.new('Model');local root=R.new('Part');root.Name='VeiledRoot';root.CFrame=CF(0,0,0);root.Parent=m;m.PrimaryPart=root
 m:SetAttribute('GuardianBehavior',state);m:SetAttribute('VeiledAwakeAt',-100)
 return Veiled.Frames(m,10)
end
for _,stage in ipairs(Meshes.Order)do
 local spec=Cfg.Stages[stage];local d=Meshes.Decode(W.module(spec.Module))
 put(('KEEPER %s %d %s'):format(spec.Key,stage,spec.Name:gsub(' ','_')))
 do local pal=W.module(spec.Module).Palette;local t={};for j,c in ipairs(pal)do t[j]=c[1]..','..c[2]..','..c[3]end;put('PAL '..table.concat(t,' '))end
 for i,p in ipairs(d.Parts)do
  local s=spec.Parts[i]
  local tree=s.TreeRest and table.concat(s.TreeRest,' ')or'-'
  local tsize=s.TreeSize and table.concat(s.TreeSize,' ')or'-'
  put(('PART %s %s %s %s %s|%s|%s|%d %d'):format(s.Name,s.Group,s.Kind,s.FaceState or'-',table.concat(s.Size,' '),tree,tsize,#p.V//3,#p.T//3))
  local t={};for j,x in ipairs(p.V)do t[j]=string.format('%.5f',x)end;put('V '..table.concat(t,' '))
  t={};for j,x in ipairs(p.T)do t[j]=tostring(x)end;put('T '..table.concat(t,' '))
  if p.P then t={};for j,x in ipairs(p.P)do t[j]=tostring(x)end;put('P '..table.concat(t,' '))else put('P -')end
  put('COLOR '..(s.Color and table.concat(s.Color,' ')or'-'))
 end
 if stage==0 then frames(spec.Key,'rest',darkened('ALERTED'));frames(spec.Key,'asleep',darkened('GUARDING'))
 else
  frames(spec.Key,'rest',Pose.Frames(stage,0,1,0,0,0,0,0,'R152'))
  frames(spec.Key,'asleep',Pose.Frames(stage,0,0,0,0,0,0,0,'R152'))
 end
end
print(table.concat(out,'\n'))
