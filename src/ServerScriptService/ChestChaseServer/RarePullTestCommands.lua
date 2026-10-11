-- R151 owner previews of the pull reveals (nothing is granted, nothing is saved): the server only tells the target's client what to play.
--  rarepull <tier> @username   the whole reveal of a tier with a demo seed of it: secret | cosmic | king (the story scenes), or common ..
--                              mythic (the seed card). The full scene still only plays where it is safe (else the in-place version).
--  raresound <Slot> @username  one sound slot of ReplicatedStorage.RarePullSounds alone, to audition an uploaded id (loops play 4 s).
local RS=game:GetService('ReplicatedStorage')
local X={}
X.Tiers={common=true,uncommon=true,rare=true,legendary=true,mythic=true,secret=true,cosmic=true,king=true}
local serial=0
function X.Execute(ctx,p,action,a)
 serial+=1
 if action=='rarepull'then
  local tier=tostring(a[1]or''):lower()
  if #a~=1 or not X.Tiers[tier]then return false,'Use rarepull secret|cosmic|king (or common|uncommon|rare|legendary|mythic) @username.'end
  p:SetAttribute('RarePullPreview','rarepull:'..tier..':'..serial)
  return true,p.Name..': playing the '..tier..' pull reveal (a preview: nothing is granted).'
 elseif action=='raresound'then
  local Sounds=require(RS.RarePullSounds);local want=tostring(a[1]or''):lower();local slot
  for _,name in ipairs(Sounds.Order)do if name:lower()==want then slot=name end end
  if #a~=1 or not slot then return false,'Use raresound <Slot> @username. Slots: '..table.concat(Sounds.Order,', ')end
  local def=Sounds.Get(slot)
  p:SetAttribute('RarePullPreview','raresound:'..slot..':'..serial)
  return true,p.Name..': playing sound slot '..slot..(def.Id and(' (uploaded '..def.Id..')')or' (the built-in layered version; no id set yet)')
 end
 return false,'Unknown command.'
end
return X
