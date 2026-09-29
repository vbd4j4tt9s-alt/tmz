-- R41. The two cropped bubble rows are assigned by action; their 04/06 filenames were not visible.
-- Existing per-module audio attribute overrides take precedence over these imported IDs.
local SoundService=game:GetService('SoundService')
local Players=game:GetService('Players')
local Debris=game:GetService('Debris')
local Content=game:GetService('ContentProvider')
local Timing=require(script.Parent.SoundTiming)
local M={}
M.AssetIds={Bubble04=96764044228884,Bubble06=131731955363530,UpgradeClick=87218932219010,Equip=99675704394731,KaChing=86218459564041,GemClaim=82559527540705,MenuClick=116737765668953}
local defaults={Bubble04=.20,Bubble06=.22,UpgradeClick=.28,Equip=.26,KaChing=.32,GemClaim=.32,MenuClick=.28}
local last,warned,preloaded={},{},{}
function M.Asset(key)
 local value=script:GetAttribute(key..'AssetId')or M.AssetIds[key]
 if type(value)=='string'then value=value:match('^rbxassetid://([1-9]%d*)$')or value end
 local id=tonumber(value)
 if not id or id<=0 or id>=9007199254740992 or id%1~=0 then return nil end
 return 'rbxassetid://'..string.format('%.0f',id)
end
local pools={};local nextRetry={}
local function pool(key,id)
 local existing=pools[key];if existing and existing.Id==id then return existing end
 if existing then for _,voice in ipairs(existing.Voices)do voice:Destroy()end end
 local p={Id=id,Voices={},Index=0};pools[key]=p
 for i=1,3 do
  local voice=Instance.new('Sound');voice.Name='Interaction_'..key;voice.SoundId=id;voice.Volume=defaults[key]or .4
  require(script.Parent.AudioMixer).Route(voice,'Interface');voice.Parent=SoundService;p.Voices[i]=voice
 end
 return p
end
local function warm(p)
 local now=os.clock();if now<(nextRetry[p.Id]or 0)then return end;nextRetry[p.Id]=now+10
 task.spawn(function()pcall(function()Content:PreloadAsync(p.Voices)end)end)
end
function M.Preload()
 if not Players.LocalPlayer then return end
 for key in pairs(M.AssetIds)do local id=M.Asset(key);if id then warm(pool(key,id))end end
end
function M.Play(key)
 if not Players.LocalPlayer then return false end
 local id=M.Asset(key);if not id then return false end
 local now=os.clock();if now-(last[key]or -math.huge)<.09 then return false end;last[key]=now
 local p=pool(key,id);p.Index=p.Index%#p.Voices+1;local sound=p.Voices[p.Index]
 -- An unavailable/cold click is discarded, never queued to pop after the menu appears.
 if not sound.IsLoaded then warm(p);return false end
 -- A new menu click replaces the previous menu cue; other feedback keeps its pool.
 if key=='MenuClick'then for _,voice in ipairs(p.Voices)do voice:Stop()end else sound:Stop()end
 Timing.Play(sound);return true
end
-- R51: success-only transaction feedback, separate from navigation and upgrade clicks.
function M.Transaction(kind)
 if kind=='Buy'or kind=='Sell'then return M.Play('KaChing')elseif kind=='Equip'then return M.Play('Equip')end
 return false
end
M.Preload()
return M
