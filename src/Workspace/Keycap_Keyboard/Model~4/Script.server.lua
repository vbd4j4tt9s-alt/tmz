local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local keycapFolder = script.Parent
local PRESS_DEPTH = 1
local PRESS_TIME = 0.07
local RELEASE_TIME = 0.1
local CLICK_SOUND_IDS = {
	"rbxassetid://113108830240353",
	"rbxassetid://88838553648526",
	"rbxassetid://96591611478915",
}

local activeKeys = {}

local function isCharacterPart(part)
	local character = part:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character) ~= nil
end

local function pressKey(keycap)
	if activeKeys[keycap] then
		return
	end
	activeKeys[keycap] = true

	local startCFrame = keycap.CFrame
	local pressedCFrame = startCFrame * CFrame.new(0, -PRESS_DEPTH, 0)
	local click = keycap:FindFirstChild("KeyClick")
	if click then
		click.SoundId = CLICK_SOUND_IDS[math.random(1, #CLICK_SOUND_IDS)]
		click.PlaybackSpeed = math.random(97, 104) / 100
		click.TimePosition = 0
		click:Play()
	end

	local downTween = TweenService:Create(
		keycap,
		TweenInfo.new(PRESS_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = pressedCFrame}
	)
	downTween:Play()
	downTween.Completed:Wait()

	task.wait(0.08)
	local upTween = TweenService:Create(
		keycap,
		TweenInfo.new(RELEASE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{CFrame = startCFrame}
	)
	upTween:Play()
	upTween.Completed:Wait()
	activeKeys[keycap] = nil
end

for _, keycap in keycapFolder:GetChildren() do
	if keycap:IsA("BasePart") then
		keycap.CanTouch = true

		local click = keycap:FindFirstChild("KeyClick") or Instance.new("Sound")
		click.Name = "KeyClick"
		click.SoundId = CLICK_SOUND_IDS[1]
		click.Volume = 0.9
		click.RollOffMode = Enum.RollOffMode.InverseTapered
		click.RollOffMinDistance = 5
		click.RollOffMaxDistance = 28
		click.Parent = keycap

		local equalizer = click:FindFirstChildOfClass("EqualizerSoundEffect") or Instance.new("EqualizerSoundEffect")
		equalizer.Name = "CrispKeyTone"
		equalizer.LowGain = -3
		equalizer.MidGain = 2
		equalizer.HighGain = 4
		equalizer.Parent = click

		keycap.Touched:Connect(function(hit)
			if isCharacterPart(hit) then
				task.spawn(pressKey, keycap)
			end
		end)
	end
end
