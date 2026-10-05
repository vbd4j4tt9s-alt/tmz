-- R151 owner control of the chip-bag shape variations (PackShapes151), reached through /test and the F4 box (OwnerUpdateCommands82.Actions.packshape):
--   packshape           status: the mode, what this server has baked / evicted / failed, how the rolls fell
--   packshape <1-6>     every NEW pack (a track spawn, a bonus / daily / mystery pack, a test pack) rolls that variation, to look at it
--   packshape off       every pack is shown in the default shape (the Index and the catalogues always are); packs keep the roll they have
--   packshape auto      back to normal: every new pack rolls one of the six, uniformly
-- It only sets the status folder's attributes (replicated to every client, which redraw their pack pictures when shapes are switched on or off); nothing is saved.
-- A pack keeps its roll for life: packs already made keep theirs (a forced number is only for the packs made after it).
local RS=game:GetService('ReplicatedStorage')
local X={}
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
 local head=mode=='off'and'Pack shape variations are OFF: every pack is shown in the default shape (packs keep the roll they have).'
  or type(mode)=='number'and('New packs are forced to variation '..mode..' ('..Shapes.Names[mode]..'); packs already made keep theirs.')
  or'Pack shape variations are on: every new pack rolls one of the six (uniformly) and keeps it for life.'
 local rolled={};for i=1,Shapes.Count do rolled[i]=Shapes.Names[i]..' '..s.Rolled[i]end
 local out={head,
  ('This server: %d pairs baked (%.1f MB estimated, %d vertices), %d being baked, %d evicted, %d failed%s, %d new packs kept the default shape because their pair was not baked yet.'):format(
   s.Pairs,s.Megabytes,s.Vertices,s.Pending,s.Evicted,s.Failures,s.LastFailure and(' (last failure: '..s.LastFailure..')')or'',s.Demoted),
  'Rolled this session: '..table.concat(rolled,', ')..'.',
  'Variations: '..table.concat(Shapes.Names,', ')..'. Packs made before this update, the Void, the Mech, the Index and every catalogue picture are the default shape.'}
 return true,table.concat(out,'\n')
end
return X
