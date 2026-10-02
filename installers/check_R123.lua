-- R123 check (read only). Edit mode or Play: paste into the Command Bar, Enter, and send me the [R123 check] lines.
local function find(path)
 local node=game;for part in path:gmatch('[^/]+')do node=node==game and game:GetService(part)or node:FindFirstChild(part);if not node then return nil end end;return node
end
local function say(s)print('[R123 check] '..s)end
say('running: '..tostring(game:GetService('RunService'):IsRunning())..' | edit: '..tostring(not game:GetService('RunService'):IsRunning()))
local config=find('ServerScriptService/ChestChaseServer/Config')
say('Config version line: '..(config and(config.Source:match("Config.Version='[^']*'")or'?')or'Config missing (normal on a Play client)'))
local routing=find('ServerScriptService/ChestChaseServer/PremiumRouting')
say('PremiumRouting still needs GiftProducts: '..(routing and tostring(routing.Source:find('GiftProducts',1,true)~=nil)or'not visible here'))
local missing={}
for _,p in ipairs({"ReplicatedStorage/DigSoundAnalyzer","ReplicatedStorage/DigSoundVariants","ReplicatedStorage/KeeperSignatureStrike","ReplicatedStorage/TrackHoleConfig","ReplicatedStorage/TreadmillBonusRules","ReplicatedStorage/VeiledArrivalFx","ReplicatedStorage/VoidPackFx","ServerScriptService/ChestChaseServer/TrackHoleService","ServerScriptService/ChestChaseServer/TreadmillBonusService","StarterPlayer/StarterPlayerScripts/TrackHoleClient","StarterPlayer/StarterPlayerScripts/TreadmillBonusClient"})do if not find(p)then missing[#missing+1]=p end end
say('new R123 scripts missing: '..(#missing==0 and'none'or table.concat(missing,', ')))
for _,p in ipairs({"ReplicatedStorage/GiftProducts","ReplicatedStorage/SpeedBoost","ServerScriptService/ChestChaseServer/ProductGiftService","ServerScriptService/ChestChaseServer/ProductGiftState"})do
 if find(p)then say('leftover (unused, safe to delete): '..p)end
end
local SS=game:GetService('ServerStorage')
for _,n in ipairs({'ChestChase_R121_Backup','ChestChase_R123_Backup'})do
 local b=SS:FindFirstChild(n);say(n..': '..(b and('state '..tostring(b:GetAttribute('State')))or'none'))
end
