-- R151 owner control of the pack shape variations (PackShapes151), reached through /test and the F4 box (OwnerUpdateCommands82.Actions.packshape):
--   packshape           what is on: the mode, how many shapes are baked / failed, which variation each biome's tiers have
--   packshape <1-6>     every pack design takes that variation (the same one everywhere), to look at it
--   packshape off       every design keeps today's mesh
--   packshape auto      back to normal: each design its own variation (by its name)
-- It only sets the status folder's attributes (replicated to every client, which re-draw their pack pictures) and the server's own templates; nothing is saved.
-- Packs already in the world keep the shape they were built with: drop / pick up / buy a new one to see the change.
local RS=game:GetService('ReplicatedStorage')
local X={}
local function lines(Shapes)
 local Rules=require(RS.SeedPackRules)
 local out={}
 for stage=1,7 do local biome=Rules.DesignBiomes[stage]
  local row={}
  for tier=1,6 do local key=string.format('%s_%02d',biome,tier);row[#row+1]=tostring(Shapes.VariationOf(key)or'-')end
  out[#out+1]=biome..': '..table.concat(row,' ')
 end
 return out
end
function X.Execute(ctx,p,a)
 local Shapes=require(RS.PackShapes151)
 local word=a[1]and tostring(a[1]):lower()
 if #a>1 then return false,'Use packshape <1-'..Shapes.Count..'|off|auto>.'end
 if word then
  local mode=word=='off'and'off'or(word=='auto'or word=='on')and'auto'or tonumber(word)
  if mode==nil or(type(mode)=='number'and(mode<1 or mode>Shapes.Count or mode%1~=0))then return false,'Use packshape <1-'..Shapes.Count..'|off|auto>.'end
  local ok,result=pcall(Shapes.SetMode,mode)
  if not ok then return false,tostring(result)end
 end
 local s=Shapes.Status();local mode=Shapes.Mode()
 local head=mode=='off'and'Pack shape variations are OFF: every design keeps today\'s mesh.'
  or type(mode)=='number'and('Every pack design is forced to variation '..mode..' ('..Shapes.Names[mode]..').')
  or'Pack shape variations are on: each design has its own (by name).'
 local out={head,('This server: %d shapes baked, %d failed, %d being baked%s. Variations: %s.'):format(s.Baked,s.Failures,s.Pending,s.LastFailure and(' (last failure: '..s.LastFailure..')')or'',table.concat(Shapes.Names,', '))}
 for _,l in ipairs(lines(Shapes))do out[#out+1]=l end
 out[#out+1]='Packs already built keep their shape; new ones (pick up, drop, buy) and every picture use the new one.'
 return true,table.concat(out,'\n')
end
return X
