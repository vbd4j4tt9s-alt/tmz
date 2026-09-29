-- R41. Imported IDs supplied in the user screenshot; per-module attribute overrides are preserved.
-- The failed heavy-attack import uses the imported angry grunt at a lower pitch until replaced.
local Voices=require(script.Parent.KeeperVoices)
local M={ImpactVolume=.48,KnightAlertVolume=.34,KnightCatchVolume=.40}
M.Assets={Impact=138131702183716,KnightAlert=100834376603587,KnightCatch=0}
local function id(value)
 if type(value)=='string'and value:match('^rbxassetid://[1-9]%d*$')then return value end
 value=tonumber(value)
 if value and value>0 and value%1==0 then return 'rbxassetid://'..string.format('%.0f',value)end
 return nil
end
function M.Asset(key)return id(script:GetAttribute(key..'AssetId')or M.Assets[key])end
function M.Voice(stage,event,override)
 if stage==1 then return nil,0,1 end -- Timber Golem is silent; shared hit impact remains.
 if stage==5 then
  if event=='Catch'then
   local heavy=M.Asset('KnightCatch')
   return heavy or M.Asset('KnightAlert'),M.KnightCatchVolume,heavy and 1 or .85
  end
  return M.Asset('KnightAlert'),M.KnightAlertVolume,1
 end
 local voice=Voices[stage]
 if not voice then return nil,0,1 end
 return id(override)or voice.Id,math.min(.42,voice.Volume*(event=='Catch'and 1.35 or 1)),voice.Pitch or 1
end
return M
