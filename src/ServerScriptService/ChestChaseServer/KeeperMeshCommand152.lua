-- R152 owner check of the baked keeper models (KeeperMeshes152), reached through /test and the F4 box (OwnerUpdateCommands82.Actions.keepermodels):
--   keepermodels        status: the bake (ready / loading / failed and why), and which model every keeper in this server shows now
--   keepermodels off    every keeper goes back to today's model (each as soon as it is idle: asleep, no chase); the Darkened at its next spawn
--   keepermodels auto   back to the new models (the default)
-- Nothing is saved: a new server starts in auto.
local X={}
function X.Execute(ctx,p,a)
 local Meshes=require(script.Parent.KeeperMeshes152);local Models=require(script.Parent.BeastModels)
 local word=a[1]and tostring(a[1]):lower()
 if #a>1 or(word and word~='off'and word~='auto'and word~='on')then return false,'Use keepermodels [off|auto].'end
 if word then Meshes.SetMode(word=='off'and'off'or'auto');Models.Step()end
 local s=Meshes.Status()
 local lines={}
 if not s.PreparationFinished then
  lines[1]='New keeper models: still baking ('..tostring(s.BakedCount or 0)..' of 8 so far). Keepers show today\'s model until theirs is ready, then switch when idle.'
 elseif s.Ready then
  lines[1]=('New keeper models: all 8 baked in %.1f s (%d mesh parts, %d triangles).'):format(s.BakeSeconds or 0,s.MeshParts or 0,s.Triangles or 0)
 else
  lines[1]=('New keeper models: %d of 8 baked, %d failed (those keep today\'s model). Last failure: %s'):format(s.BakedCount or 0,s.FailureCount or 0,tostring(s.LastFailure))
  if tostring(s.LastFailure):find(Meshes.Unavailable,1,true)then lines[#lines+1]='Turn on Game Settings > Security > "Allow Mesh / Image APIs", then start a new server.'end
 end
 lines[#lines+1]=s.Mode=='off'and'Mode: OFF (/test keepermodels off): every keeper shows today\'s model.'or'Mode: auto (new models where baked).'
 local shown={}
 for _,model in ipairs(Models.Keepers())do
  local body=model:FindFirstChild('BeastBody');local stage=model:GetAttribute('CreatureStage')
  shown[stage]=(Models.Variant(body)and'new'or'today\'s')..(Meshes.Wanted(stage)~=Models.Variant(body)and' (switches when idle)'or'')
 end
 for _,stage in ipairs(Meshes.Order)do
  local st=s.Stages[stage]
  local now=stage==0 and'next spawn: '..(Meshes.Wanted(0)and'new'or'today\'s')or shown[stage]or'not in this server'
  lines[#lines+1]=('%s: %s, %d parts, %d triangles; showing %s.'):format(st.Name,st.State,st.Parts,st.Triangles,now)
 end
 return true,table.concat(lines,'\n')
end
return X
