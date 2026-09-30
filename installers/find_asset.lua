-- Paste into the Studio Command Bar (Edit mode). Prints every place that uses the asset id below:
-- Animation / Sound objects, any script whose source mentions it, and attributes. Change ID to search another asset.
local ID='114302219876492'
local found=0
local function report(what,inst)found+=1;print(('[find_asset] %s  ->  %s'):format(what,inst:GetFullName()))end
for _,inst in ipairs(game:GetDescendants())do
 pcall(function()
  if inst:IsA('Animation')and tostring(inst.AnimationId):find(ID,1,true)then report('Animation.AnimationId',inst)end
  if inst:IsA('Sound')and tostring(inst.SoundId):find(ID,1,true)then report('Sound.SoundId',inst)end
  if inst:IsA('LuaSourceContainer')and inst.Source:find(ID,1,true)then report('script source',inst)end
  for key,value in pairs(inst:GetAttributes())do if tostring(value):find(ID,1,true)then report('attribute '..key,inst)end end
 end)
end
print(('[find_asset] %d place(s) use %s.%s'):format(found,ID,found==0 and' Nothing in the place: it comes from outside it (a plugin, or a tool/character added at run time). Run this again in Play mode (Server and Client) to search the live game.'or''))
