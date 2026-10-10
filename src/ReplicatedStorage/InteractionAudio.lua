-- R41. The two cropped bubble rows are assigned by action; their 04/06 filenames were not visible.
-- Existing per-module audio attribute overrides take precedence over these imported IDs.
local SoundService=game:GetService('SoundService')
local Players=game:GetService('Players')
local Debris=game:GetService('Debris')
local Content=game:GetService('ContentProvider')
local Timing=require(script.Parent:WaitForChild('SoundTiming')) -- R152: WaitForChild (it could run before SoundTiming had replicated)
local M={}
-- R157b fix: AudioMixer is fetched the first time a voice needs it, with WaitForChild (like SoundTiming above): this module can be required before AudioMixer has replicated (the title does it
-- while the game is still loading), and a failed require is cached by Roblox, so the HUD scripts that need this module later failed with it.
local mixer
local function Mixer()
 if not mixer then mixer=require(script.Parent:WaitForChild('AudioMixer'))end
 return mixer
end
-- R150: MenuClose is the MenuClick file a little lower; Denied is the built-in ping, low and muted (no new upload).
M.AssetIds={Bubble04=96764044228884,Bubble06=131731955363530,UpgradeClick=87218932219010,Equip=99675704394731,KaChing=86218459564041,GemClaim=82559527540705,MenuClick=116737765668953,
 MenuClose=116737765668953,Denied='rbxasset://sounds/electronicpingshort.wav',MechClick=87218932219010} -- (R153: MechClick is UpgradeClick's file at Bubble04's volume: the Mech pack's clicks 1-4)
local defaults={Bubble04=.20,Bubble06=.22,UpgradeClick=.28,Equip=.26,KaChing=.32,GemClaim=.32,MenuClick=.28,MenuClose=.26,Denied=.24,MechClick=.20}
M.Speeds={MenuClose=.85,Denied=.55}
-- Per-key gap between two plays (default .09); a refusal repeated faster than this stays one sound.
M.DefaultGap=.09
M.Gaps={Denied=.25}
-- Keys that replace each other: only one menu cue is audible at a time.
local menuKeys={MenuClick=true,MenuClose=true}
local last,warned,preloaded={},{},{}
function M.Asset(key)
 local value=script:GetAttribute(key..'AssetId')or M.AssetIds[key]
 -- A built-in client sound (rbxasset://sounds/...) is accepted as it is.
 if type(value)=='string'and value:match('^rbxasset://sounds/[%w_%-%.]+$')then return value end
 if type(value)=='string'then value=value:match('^rbxassetid://([1-9]%d*)$')or value end
 local id=tonumber(value)
 if not id or id<=0 or id>=9007199254740992 or id%1~=0 then return nil end
 return 'rbxassetid://'..string.format('%.0f',id)
end
local pools={};local nextRetry=setmetatable({},{__mode='k'}) -- per pool (MenuClose shares MenuClick's file but has its own voices to warm)
local function pool(key,id)
 local mix=Mixer() -- (R157b fix: first, so a wait for AudioMixer never leaves a half-built pool behind)
 local existing=pools[key];if existing and existing.Id==id then return existing end
 if existing then for _,voice in ipairs(existing.Voices)do voice:Destroy()end end
 local p={Id=id,Voices={},Index=0};pools[key]=p
 for i=1,3 do
  local voice=Instance.new('Sound');voice.Name='Interaction_'..key;voice.SoundId=id;voice.Volume=defaults[key]or .4;voice.PlaybackSpeed=M.Speeds[key]or 1
  mix.Route(voice,'Interface');voice.Parent=SoundService;p.Voices[i]=voice
 end
 return p
end
local function warm(p)
 local now=os.clock();if now<(nextRetry[p]or 0)then return end;nextRetry[p]=now+10
 task.spawn(function()pcall(function()Content:PreloadAsync(p.Voices)end)end)
end
function M.Preload()
 if not Players.LocalPlayer then return end
 for key in pairs(M.AssetIds)do local id=M.Asset(key);if id then warm(pool(key,id))end end
end
-- Keep one key silent for a moment (a caller whose own cue already covers it, e.g. equipping from the Bag closes the Bag).
local mutedUntil={}
function M.Mute(key,seconds)mutedUntil[key]=os.clock()+math.clamp(tonumber(seconds)or .2,0,2)end
-- minGap (optional): seconds before the same key may play again. The pack-opening click passes a gap shorter than the
-- click interval so every accepted click sounds; everything else keeps the key's default.
function M.Play(key,minGap)
 if not Players.LocalPlayer then return false end
 local id=M.Asset(key);if not id then return false end
 local gap=tonumber(minGap)or M.Gaps[key]or M.DefaultGap
 local now=os.clock();if now<(mutedUntil[key]or 0)then return false end
 if now-(last[key]or -math.huge)<gap then return false end;last[key]=now
 local p=pool(key,id);p.Index=p.Index%#p.Voices+1;local sound=p.Voices[p.Index]
 -- An unavailable/cold click is discarded, never queued to pop after the menu appears.
 if not sound.IsLoaded then warm(p);return false end
 -- A new menu cue replaces the previous menu cue (open or close); other feedback keeps its pool.
 if menuKeys[key]then
  for other in pairs(menuKeys)do local op=pools[other];if op then for _,voice in ipairs(op.Voices)do voice:Stop()end end end
 else sound:Stop()end
 Timing.Play(sound);return true
end
-- R51: success-only transaction feedback, separate from navigation and upgrade clicks.
function M.Transaction(kind)
 if kind=='Buy'or kind=='Sell'then return M.Play('KaChing')elseif kind=='Equip'then return M.Play('Equip')end
 return false
end
-- R157b fix: the warm-up runs in its own thread inside a pcall: it waits for AudioMixer there if needed, and a failure in it can no longer fail this module's require.
task.spawn(function()local ok,why=pcall(M.Preload);if not ok then warn('[InteractionAudio] preload: '..tostring(why))end end)
return M
