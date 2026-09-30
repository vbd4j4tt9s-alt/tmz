local GardenTheme=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTheme'))
local TextFit=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTextFit'))
local MenuStyle=require(game:GetService("ReplicatedStorage"):WaitForChild("GardenMenuStyle"))
local CardMotion=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenCardMotion'))
-- V114: shop/sell UI, bottom-left cash and authoritative garden inputs.
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimpleText = require(ReplicatedStorage:WaitForChild("SimpleGameText")) -- V089_SHORT_TEXT
local ButtonStyle = require(ReplicatedStorage:WaitForChild("ButtonStyle"))
local CashNumbers = require(ReplicatedStorage:WaitForChild("CashNumbers"))
local GardenWallet = require(ReplicatedStorage:WaitForChild("GardenWallet"))
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if game:GetService('RunService'):IsStudio()then print("[V0.78] EconomyClient starting...") end -- R114: Studio-only load message

local function requireChild(parent, name)
	local child = parent:WaitForChild(name, 10)
	assert(child, string.format("[V0.78] Missing %s inside %s", name, parent:GetFullName()))
	return child
end

local remotes = requireChild(ReplicatedStorage, "ChestChaseRemotes")
local getShopState = requireChild(remotes, "GetShopState")
local purchaseShopItem = requireChild(remotes, "PurchaseShopItem")
local equipShopItem = requireChild(remotes, "EquipShopItem")
local InteractionAudio=require(ReplicatedStorage:WaitForChild('InteractionAudio'))
local openEconomyUI = requireChild(remotes, "OpenEconomyUI")

local function isLegacyTravelButton(instance)
	if not instance:IsA("TextButton") then
		return false
	end
	local normalizedText = string.upper(instance.Text):gsub("%s+", " ")
	return normalizedText == "BUY [TP]" or normalizedText == "SELL [TP]"
end

local function removeLegacyTravelButtons()
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if isLegacyTravelButton(descendant) then
			descendant:Destroy()
		end
	end
end

removeLegacyTravelButtons()
playerGui.DescendantAdded:Connect(function(descendant)
	if isLegacyTravelButton(descendant) then
		descendant:Destroy()
	end
end)

-- V0.77 native 3D card previews; use visual mesh bounds, not carrier-part bounds.
local seedArt = remotes:WaitForChild("SeedArt", 15)
local HarvestPresentation=require(ReplicatedStorage:WaitForChild("HarvestPresentation"))
local function addArtPreview(parent, category, seedId, position, size, mutation, harvestItem)
	local folder = seedArt and seedArt:FindFirstChild(category)
	local template = folder and folder:FindFirstChild(seedId)
	local generated,previewCrop,previewIndex
 if not template and category=="Harvests" then
  local defs=require(ReplicatedStorage:WaitForChild("PlantCatalog"))
  if defs[seedId]then generated,previewCrop,previewIndex=HarvestPresentation.Build(harvestItem or {SeedId=seedId,Mutation=mutation})end
 end
 if not template and not generated then return false end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ArtPreview"
	viewport.Position = position
	viewport.Size = size
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(195, 195, 180)
	viewport.LightColor = Color3.fromRGB(255, 247, 220)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local clone = generated or template:Clone()
    require(ReplicatedStorage:WaitForChild("PlantVisuals")).Coat(clone, mutation)
	clone.Parent = world
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < .95 then
			local extent = (part:GetAttribute("ArtSize") or part.Size) / 2
			-- Cylinders use Roblox's X axis after their part dimensions are swapped.
			if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then extent = part.Size / 2 end
			for _, x in ipairs({-1, 1}) do for _, y in ipairs({-1, 1}) do for _, z in ipairs({-1, 1}) do
				local point = part.CFrame * Vector3.new(extent.X * x, extent.Y * y, extent.Z * z)
				low = Vector3.new(math.min(low.X, point.X), math.min(low.Y, point.Y), math.min(low.Z, point.Z))
				high = Vector3.new(math.max(high.X, point.X), math.max(high.Y, point.Y), math.max(high.Z, point.Z))
			end end end
		end
	end
	local cf, dimensions = CFrame.new((low + high) / 2), high - low
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	local radius = dimensions.Magnitude / 2
	local aspect = math.max(size.X.Offset / math.max(size.Y.Offset, 1), 0.25)
	local halfAngle = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * math.min(aspect, 1))
	local distance = radius / math.sin(halfAngle) * 1.05
	local direction = Vector3.new(0.3, 0.16, -1).Unit
	camera.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
 if previewCrop then
  camera.CFrame=CFrame.lookAt(cf.Position+direction*distance*1.18,cf.Position)
  HarvestPresentation.Register(viewport,clone,previewCrop,previewIndex)
 end
	return true
end

local COLORS = {
	Background = Color3.fromRGB(13, 22, 39),
	Panel = Color3.fromRGB(24, 39, 64),
	Card = Color3.fromRGB(35, 54, 83),
	Blue = Color3.fromRGB(58, 178, 255),
	Gold = Color3.fromRGB(255, 190, 62),
	Green = Color3.fromRGB(68, 222, 149),
	Red = Color3.fromRGB(255, 104, 112),
	White = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(187, 206, 231),
}

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function styleText(object, textSize)
	object.Font = GardenTheme.Bold
	object.TextColor3 = COLORS.White
	object.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	object.TextStrokeTransparency = 1
	object.TextSize = textSize
	object.TextScaled = false
	object.RichText = false
	return object
end

local function makeLabel(parent, name, text, position, size, textSize, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = text
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	styleText(label, textSize)
	label.Parent = parent
	TextFit.Attach(label,textSize,9)
	return label
end

local icons = {BuyTravel="Shop", BaseTravel="Base", SellTravel="Sell",
    Close="Close", Trails="Trails", Accessories="Boots",
    Action="Shop", Sell="Sell", Equip="Equip", SellHarvest="Sell"}
local function makeButton(parent, name, text, position, size, color, _textSize, icon)
    local wide = name == "BuyTravel" or name == "BaseTravel" or name == "SellTravel"
    local button = ButtonStyle.Create(parent, name, icon or assert(icons[name]), position, size, color, wide)
    button:SetAttribute("ActionLabel", text)
    return button
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChestEconomyUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 30
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local oldEconomyGui = playerGui:FindFirstChild(screenGui.Name)
if oldEconomyGui then
	oldEconomyGui:Destroy()
end
screenGui.Parent = playerGui

-- R88: remove the paired Shop/Base travel buttons; retain gamepad planting aim.
for _,name in ipairs({'ChestEconomyTopBar','GardenAimOverlay'})do
 local previous=playerGui:FindFirstChild(name);if previous then previous:Destroy()end
end
local aimGui=Instance.new('ScreenGui');aimGui.Name='GardenAimOverlay'
aimGui.ResetOnSpawn=false;aimGui.ScreenInsets=Enum.ScreenInsets.None
aimGui.ClipToDeviceSafeArea=true;aimGui.DisplayOrder=31
aimGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;aimGui.Parent=playerGui
screenGui.Destroying:Connect(function()aimGui:Destroy()end)
local wallet = GardenWallet.new(screenGui)
local claimCash=remotes:WaitForChild('CollectSaleCash')
local pendingCash=remotes:WaitForChild('GetPendingSales')
local rewardGui=Instance.new('ScreenGui');rewardGui.Name='CurrencyRewards';rewardGui.ResetOnSpawn=false;rewardGui.DisplayOrder=75;rewardGui.Parent=playerGui
local saleEffects=require(ReplicatedStorage:WaitForChild('SaleMoneyEffects')).new(rewardGui,wallet,function(id,index)
 return claimCash:InvokeServer(id,index)
end)
-- Rejoin recovery and owner-command sales use the same persisted receipts.
task.spawn(function()
 while screenGui.Parent do
  local okay,receipts=pcall(function()return pendingCash:InvokeServer()end)
  if okay and type(receipts)=='table'then saleEffects:Sync(receipts)end
  task.wait(5)
 end
end)
screenGui.Destroying:Connect(function()saleEffects:Destroy();rewardGui:Destroy()end)
local rewardQueued=false
local function syncRewards()
 if rewardQueued then return end;rewardQueued=true
 task.delay(.15,function()
  rewardQueued=false;if not screenGui.Parent then return end
  local okay,receipts=pcall(function()return pendingCash:InvokeServer()end)
  if okay and type(receipts)=='table'then saleEffects:Sync(receipts)end
 end)
end
player:GetAttributeChangedSignal('GardenRevision'):Connect(syncRewards)
player:GetAttributeChangedSignal('PremiumRevision'):Connect(syncRewards)
local shade = Instance.new("TextButton")
shade.Name = "Shade"
shade:SetAttribute("ButtonHighlight",false)
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shade.BackgroundTransparency = 0.44
shade.BorderSizePixel = 0
shade.AutoButtonColor = false
shade.Text = ""
shade.Visible = false
shade.Parent = screenGui

-- R40: shade the whole viewport while keeping the menu inside the normal safe area.
local backdropGui = Instance.new('ScreenGui')
backdropGui.Name = 'ChestEconomyBackdrop'
backdropGui.ResetOnSpawn = false
backdropGui.ScreenInsets = Enum.ScreenInsets.None
backdropGui.ClipToDeviceSafeArea = false
backdropGui.DisplayOrder = screenGui.DisplayOrder - 1
backdropGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local oldBackdrop = playerGui:FindFirstChild(backdropGui.Name)
if oldBackdrop then oldBackdrop:Destroy() end
local backdrop = Instance.new('Frame')
backdrop.Name = 'FullScreenShade'
backdrop.Position = UDim2.fromScale(0,0)
backdrop.Size = UDim2.fromScale(1,1)
backdrop.BackgroundColor3 = shade.BackgroundColor3
backdrop.BackgroundTransparency = shade.BackgroundTransparency
backdrop.BorderSizePixel = 0
backdrop.Active = false
backdrop.Parent = backdropGui
shade.BackgroundTransparency = 1 -- the existing safe-area button still closes the menu
local function syncBackdrop()
 backdropGui.Enabled = screenGui.Enabled and shade.Visible
end
local backdropVisible = shade:GetPropertyChangedSignal('Visible'):Connect(syncBackdrop)
local backdropEnabled = screenGui:GetPropertyChangedSignal('Enabled'):Connect(syncBackdrop)
syncBackdrop()
backdropGui.Parent = playerGui
screenGui.Destroying:Connect(function()
 backdropVisible:Disconnect();backdropEnabled:Disconnect();backdropGui:Destroy()
end)


local panel = Instance.new("Frame")
panel.Name = "EconomyPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.94, 0.82)
panel.BackgroundColor3 = COLORS.Background
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
addCorner(panel, 18)
require(ReplicatedStorage:WaitForChild("GardenMenuStyle")).Panel(panel,72)
local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(260, 160)
panelConstraint.MaxSize = Vector2.new(780, 620)
panelConstraint.Parent = panel

local title = makeLabel(
	panel,
	"Title",
	"Boost shop",
	UDim2.fromOffset(22, 11),
	UDim2.new(1, -90, 0, 34),
	20
)
local cashLabel = makeLabel(
	panel,
	"Cash",
	"Cash  $0",
	UDim2.fromOffset(22, 44),
	UDim2.new(1, -44, 0, 24),
	16,
	Enum.TextXAlignment.Right
)
cashLabel.TextColor3 = GardenTheme.Colors.Gold
GardenTheme.Text(title,26,true)
GardenTheme.Text(cashLabel,18,true,GardenTheme.Colors.Gold)
title.Position=UDim2.fromOffset(16,10);title.Size=UDim2.new(1,-76,0,30)
cashLabel.Position=UDim2.fromOffset(16,48);cashLabel.Size=UDim2.new(1,-32,0,22);cashLabel.TextXAlignment=Enum.TextXAlignment.Left
local closeButton = makeButton(
	panel,
	"Close",
	"X",
	UDim2.new(1, -50, 0, 12),
	UDim2.fromOffset(34, 34),
	COLORS.Red,
	19
)

local statusLabel = makeLabel(
	panel,
	"Status",
	"",
	UDim2.fromOffset(22, 70),
	UDim2.new(1, -44, 0, 28),
	14,
	Enum.TextXAlignment.Center
)
statusLabel.TextColor3 = COLORS.Muted

local currentState = nil
local currentTab = "Trails"
local requestBusy = false

local function setStatus(message, isError)
	local short, color = SimpleText.Format(message)
	statusLabel.Visible = short ~= ""
	statusLabel.Text = short
	statusLabel.TextColor3 = isError and SimpleText.Red or color or COLORS.Muted
end

local function runServerRequest(callback)
	if requestBusy then
		return nil
	end
	requestBusy = true
	local success, result = pcall(callback)
	requestBusy = false
	if not success then
		setStatus("THE SERVER DID NOT RESPOND - TRY AGAIN", true)
		return nil
	end
	if type(result) == "table" and result.Success == false then
		setStatus(result.Message or "REQUEST FAILED", true)
		return nil
	end
	return result
end

local harvestMenu
local renderHarvests
local renderCurrentTab
local setOpen

local function adoptState(state)
	if type(state) ~= "table" then
		return
	end
	currentState = state
	cashLabel.Text = "Cash  $" .. CashNumbers.Compact(state.Cash)
	if panel.Visible and renderCurrentTab then
		renderCurrentTab()
	end
	if state.Message then
		setStatus(state.Message, false)
	end
end

local stationContext='Buy'
local modeBar=Instance.new('Frame');modeBar.Name='MarketModes';modeBar.BackgroundTransparency=1;modeBar.Size=UDim2.new(1,-32,0,36);modeBar.Parent=panel
local modes={}
for i,mode in ipairs({'Buy','Sell crops'})do
 local b=Instance.new('TextButton');b.Name=i==1 and'BuyMode'or'SellMode';b.Text=mode;b.Position=UDim2.new((i-1)*.5,(i-1)*4,0,0);b.Size=UDim2.new(.5,-4,1,0);b.BorderSizePixel=0;b.Parent=modeBar;GardenTheme.Corner(b,8);GardenTheme.Text(b,16,true);modes[i]=b
 b.Activated:Connect(function()currentTab=i==1 and'Trails'or'Sell';renderCurrentTab()end)
end
local shopMenu=require(ReplicatedStorage:WaitForChild('ShopMenu')).new(panel,function(tab)
 currentTab=tab;renderCurrentTab()
end,function(id)
 local state=runServerRequest(function()return purchaseShopItem:InvokeServer(id)end)
 if state then InteractionAudio.Transaction('Buy');adoptState(state)end
end,function(id,equipped)
 local state=runServerRequest(function()return equipShopItem:InvokeServer(id,equipped)end)
 if state then InteractionAudio.Transaction('Equip');adoptState(state)end
end)
screenGui.Destroying:Connect(function()shopMenu:Destroy()end)
renderCurrentTab = function()
 local itemMode=currentTab=='Sell'
 panel.BackgroundColor3=GardenTheme.Colors.Panel
 local view=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
 local compact=view.Y<480
 title.Size=compact and UDim2.new(1,-270,0,30)or UDim2.new(1,-76,0,30)
 cashLabel.Position=compact and UDim2.new(1,-218,0,16)or UDim2.fromOffset(16,48)
 cashLabel.Size=compact and UDim2.fromOffset(156,22)or UDim2.new(1,-32,0,22)
 panel.GardenHeader.Size=UDim2.new(1,-16,0,compact and 38 or 64);panel.HeaderRule.Position=UDim2.fromOffset(16,compact and 46 or 74)
 MenuStyle.Place(panel,playerGui,math.min(780,view.X*.94),math.min(620,view.Y*.88))
 modeBar.Position=UDim2.fromOffset(16,compact and 50 or 78)
 for i,b in ipairs(modes)do local active=(i==2)==itemMode;require(ReplicatedStorage.BrightUI).Button(b,active and Color3.fromRGB(43,177,106)or Color3.fromRGB(64,86,154));b.TextColor3=GardenTheme.Colors.Text end
 local statusLeft=16
 statusLabel.Position=UDim2.new(0,statusLeft,1,-26);statusLabel.Size=UDim2.new(1,-statusLeft-16,0,18)
 if itemMode then
  shopMenu:Hide();title.Text='Market'
  if renderHarvests then renderHarvests()end
  setStatus(currentState and not currentState.CanSell and'Visit the market to sell your crops.'or'',false)
 else
  if harvestMenu then harvestMenu:Hide()end
  title.Text='Market';shopMenu:Show(currentState,currentTab);setStatus('',false)
 end
end

local function refreshState()
	local state = runServerRequest(function()
		return getShopState:InvokeServer()
	end)
	if state then
		adoptState(state)
	end
end

setOpen = function(isOpen, requestedTab)
    -- The retired Inventory route cannot reopen through an older caller.
    if isOpen and requestedTab and requestedTab ~= "Sell" and not shopMenu.TabButtons[requestedTab] then return end
	if requestedTab then
        stationContext="Buy"
		currentTab = requestedTab
	end
	if isOpen then
		playerGui:SetAttribute("SeedMenu", "Economy")
	elseif playerGui:GetAttribute("SeedMenu") == "Economy" then
		playerGui:SetAttribute("SeedMenu", nil)
	end
	shade.Visible = isOpen
	panel.Visible = isOpen
	if not isOpen then shopMenu:Hide();if harvestMenu then harvestMenu:Hide()end end
	if isOpen then
		renderCurrentTab()
		refreshState()
	end
end

playerGui:GetAttributeChangedSignal('HudNoticeBottom'):Connect(function()if panel.Visible and renderCurrentTab then renderCurrentTab()end end)
local viewportChanged
local function bindEconomyViewport()
 if viewportChanged then viewportChanged:Disconnect()end
 local camera=workspace.CurrentCamera
 if camera then viewportChanged=camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()if panel.Visible then renderCurrentTab()end end)end
end
bindEconomyViewport()
local cameraChanged=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(bindEconomyViewport)
screenGui.Destroying:Connect(function()cameraChanged:Disconnect();if viewportChanged then viewportChanged:Disconnect()end end)
player:GetAttributeChangedSignal('TreadmillTier'):Connect(function()if panel.Visible then refreshState()end end)
local stationGuard=require(ReplicatedStorage:WaitForChild("StationMenuGuard")).new(player,panel,function()return stationContext end,function()setOpen(false)end,remotes)

playerGui:GetAttributeChangedSignal("SeedMenu"):Connect(function()
	local menu = playerGui:GetAttribute("SeedMenu")
	if panel.Visible and menu ~= "Economy" then setOpen(false) end
end)

closeButton.Activated:Connect(function()
	setOpen(false)
end)
shade.Activated:Connect(function()
	setOpen(false)
end)
openEconomyUI.OnClientEvent:Connect(function(requestedTab)
 InteractionAudio.Play('Bubble04')
	setOpen(true, requestedTab)
end)

do
 local dead=false;local folder;local valueConnection;local folderConnections={};local connections={}
 local function bindCash()
  if valueConnection then valueConnection:Disconnect();valueConnection=nil end
  local cashValue=folder and folder:FindFirstChild('Cash')
  local function updateStats()
   if dead or not cashValue then return end
   local amount=cashValue.Value;if type(amount)~='number'then return end
   wallet:SetValue(amount)
   if currentState then
    currentState.Cash=amount;cashLabel.Text='Cash  $'..CashNumbers.Compact(amount)
    if panel.Visible and currentTab~='Sell'then shopMenu:Render()end
   end
  end
  if cashValue then valueConnection=cashValue:GetPropertyChangedSignal('Value'):Connect(updateStats)end
  updateStats()
 end
 local function bindFolder()
  for _,connection in ipairs(folderConnections)do connection:Disconnect()end;table.clear(folderConnections)
  folder=player:FindFirstChild('ChestChaseStats')
  if folder then
   folderConnections[1]=folder.ChildAdded:Connect(function(child)if child.Name=='Cash'then bindCash()end end)
   folderConnections[2]=folder.ChildRemoved:Connect(function(child)if child.Name=='Cash'then bindCash()end end)
  end
  bindCash()
 end
 connections[1]=player.ChildAdded:Connect(function(child)if child.Name=='ChestChaseStats'then bindFolder()end end)
 connections[2]=player.ChildRemoved:Connect(function(child)if child.Name=='ChestChaseStats'then bindFolder()end end)
 connections[3]=screenGui.Destroying:Connect(function()
  dead=true;if valueConnection then valueConnection:Disconnect()end
  for _,connection in ipairs(folderConnections)do connection:Disconnect()end
  for _,connection in ipairs(connections)do connection:Disconnect()end
 end)
 bindFolder()
end

local sellRefreshQueued = false
local function queueSellRefresh()
	if sellRefreshQueued or not panel.Visible or currentTab ~= "Sell" then
		return
	end
	sellRefreshQueued = true
	task.delay(0.12, function()
		sellRefreshQueued = false
		if panel.Visible and currentTab == "Sell" then
			refreshState()
		end
	end)
end

player:GetAttributeChangedSignal("DataStatus"):Connect(queueSellRefresh)
if game:GetService('RunService'):IsStudio()then print("[V114] Shop and Sell ready; custom garden inventory ready.") end -- R114: Studio-only load message

-- Garden planting remains independent of the temporarily retired Inventory UI.
local ProximityPromptService = game:GetService("ProximityPromptService")
local gardenInteract = remotes:WaitForChild("GardenInteract", 20)
local sellHarvest = remotes:WaitForChild("SellHarvest", 20)
assert(gardenInteract and sellHarvest, "[V0.78] Install all matching garden server scripts")

harvestMenu=require(ReplicatedStorage:WaitForChild('HarvestSellMenu')).new(panel,function(id,origin)
 local state=runServerRequest(function()return sellHarvest:InvokeServer(id)end)
 if state then InteractionAudio.Transaction('Sell');adoptState(state);saleEffects:Sync(state.PendingSales,origin)end
end)
renderHarvests=function()harvestMenu:Show(currentState)end

local toast = makeLabel(screenGui, "GardenFeedback", "", UDim2.new(1, -18, 1, -85), UDim2.fromOffset(300, 62), 18, Enum.TextXAlignment.Right)
toast.AnchorPoint = Vector2.new(1, 1)
toast.TextTransparency = 1
toast.TextStrokeTransparency = 1
toast.ZIndex = 20
local toastTween, toastSerial = nil, 0
local function gardenToast(message, failed)
	local short = SimpleText.Format(message)
	if short == "" then return end
	toastSerial = toastSerial + 1
	local token = toastSerial
	if toastTween then toastTween:Cancel() end
	toast.Text = short
	toast.TextColor3 = failed and SimpleText.Red or SimpleText.Green
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.2
	task.delay(2.2, function()
		if token ~= toastSerial then return end
		toastTween = TweenService:Create(toast, TweenInfo.new(0.45), {TextTransparency = 1, TextStrokeTransparency = 1})
		toastTween:Play()
	end)
end

local HttpService = game:GetService("HttpService")
local ContextActionService = game:GetService("ContextActionService")
local gardenBusy, lastGardenAction = false, -math.huge
local function equippedGardenSeed()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("GardenSeed") and tool.Enabled then return tool end
	end
end
local function sendGarden(action, payload)
	if gardenBusy or os.clock() - lastGardenAction < (gardenInteract:GetAttribute("PlacementCooldown") or 0.35) or playerGui:GetAttribute("SeedMenu")
		or UserInputService:GetFocusedTextBox() or not player.Character then return end
	lastGardenAction = os.clock()
	payload.RequestId = HttpService:GenerateGUID(false)
	payload.Character = player.Character
	gardenBusy = true
	local ok, result = pcall(function() return gardenInteract:InvokeServer(action, payload) end)
	gardenBusy = false
	if payload.Character ~= player.Character then return end
	if not ok or type(result) ~= "table" then gardenToast("GARDEN DID NOT RESPOND — TRY AGAIN", true); return end
	gardenToast(result.Message, result.Success ~= true)
 if action=='Harvest'and result.Success==true then InteractionAudio.Play('Bubble06')end
	queueSellRefresh()
	return result
end

local gardenRayExclusions={}
local function registerPlantCollision(item)
 if item:IsA('Folder')and item.Name=='SolidPlant'and item.Parent and item.Parent:GetAttribute('GardenPlantV141')then
  local def=require(ReplicatedStorage:WaitForChild('PlantCatalog'))[item.Parent:GetAttribute('SeedId')]
  if def and def.Mode~='whole'then table.insert(gardenRayExclusions,item)end
 end
end
-- Event-driven collection; no full-workspace scans per click.
local gardenMap=workspace:WaitForChild('ChestChaseMap')
for _,item in ipairs(gardenMap:GetDescendants())do registerPlantCollision(item)end
gardenMap.DescendantAdded:Connect(registerPlantCollision)
gardenMap.DescendantRemoving:Connect(function(item)
 if item.Name~='SolidPlant'or not item:IsA('Folder')then return end
 local index=table.find(gardenRayExclusions,item);if index then table.remove(gardenRayExclusions,index)end
end)
local function rayAt(screenPosition, isViewport)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local ray
	if isViewport then ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	else
		local inset = GuiService:GetGuiInset()
		ray = camera:ScreenPointToRay(screenPosition.X - inset.X, screenPosition.Y - inset.Y)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded=player.Character and {player.Character}or{}
    for _,folder in ipairs(gardenRayExclusions)do if folder.Parent then table.insert(excluded,folder)end end
    params.FilterDescendantsInstances=excluded
	params.IgnoreWater = true
	return workspace:Raycast(ray.Origin, ray.Direction * 500, params)
end
local function placeAt(screenPosition, isViewport)
	if gardenBusy or playerGui:GetAttribute("SeedMenu") or UserInputService:GetFocusedTextBox() then return end
	local seed = equippedGardenSeed()
	if not seed then return end
	local hit = rayAt(screenPosition, isViewport)
	if not hit or not hit.Instance:GetAttribute("GardenSoil") then gardenToast("AIM AT SOIL IN YOUR GARDEN", true); return end
	sendGarden("Place", {Soil = hit.Instance, Position = hit.Position, SeedInventoryId = seed:GetAttribute("SeedInventoryId")})
end
-- One input route per device avoids duplicate Tool.Activated and touch requests.
-- Garden Tools retain ManualActivationOnly; this controller owns their activation.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		placeAt(UserInputService:GetMouseLocation(), false)

	end
end)
ContextActionService:BindActionAtPriority("GardenPlaceSeed", function(_, state)
	if not equippedGardenSeed() or playerGui:GetAttribute("SeedMenu") or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		local camera = workspace.CurrentCamera
		if camera then placeAt(camera.ViewportSize / 2, true) end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonR2)
UserInputService.TouchTapInWorld:Connect(function(position, processed)
	if not processed then placeAt(position, false) end
end)
local holdHarvest=require(ReplicatedStorage:WaitForChild('GardenHoldHarvest')).new({
 Player=player,Map=gardenMap,
 SelectedCrop=function()return playerGui:GetAttribute("SelectedGardenCropId")end,
 SelectedFruit=function()return playerGui:GetAttribute("SelectedGardenFruitIndex")end,
 SelectionChanged=playerGui:GetAttributeChangedSignal("GardenSelectionEpoch"),
 IsBusy=function()return gardenBusy end,
 IsMenuOpen=function()return playerGui:GetAttribute('SeedMenu') or panel.Visible end,
 Interval=math.max(.45,(gardenInteract:GetAttribute('PlacementCooldown') or .35)+.1),
 Send=function(payload)return sendGarden('Harvest',payload)end,
})
script.Destroying:Connect(function()holdHarvest:Destroy()end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who and who ~= player then return end
	if not prompt:GetAttribute("GardenPrompt") or prompt:GetAttribute("GardenStage") ~= 4 or prompt:GetAttribute("GardenOwnerId")~=player.UserId then return end
	if prompt:GetAttribute('GardenAction')=='PlantTop'then
        sendGarden('PlantTop',{CropId=prompt:GetAttribute('GardenCropId')})
    elseif holdHarvest:NativeTrigger(prompt) then
        local result=sendGarden("Harvest", {CropId=prompt:GetAttribute("GardenCropId"), FruitIndex=prompt:GetAttribute("GardenFruitIndex")})
        holdHarvest:RecordResult(prompt,result)
    end
end)

local boundPrompts = setmetatable({}, {__mode = "k"})
local function refreshPrompt(prompt)
    if prompt:GetAttribute('GardenAction')=='PlantTop'then return end
	local status = player:GetAttribute("DataStatus")
	local enabled = prompt:GetAttribute("GardenOwnerId") == player.UserId
		and prompt:GetAttribute("GardenStage") == 4 and (status == "Loaded" or status == "LoadFailed")
	if prompt:GetAttribute('GardenAction')~='PlantTop' then
        enabled=enabled and playerGui:GetAttribute('SelectedGardenCropId')~=nil and prompt:GetAttribute('GardenCropId')==playerGui:GetAttribute('SelectedGardenCropId')
         and prompt:GetAttribute('GardenFruitIndex')==playerGui:GetAttribute('SelectedGardenFruitIndex')
    end
	if prompt.Enabled ~= enabled then prompt.Enabled = enabled end
end
local function bindGardenPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") or not prompt:GetAttribute("GardenPrompt") or boundPrompts[prompt] then return end
	boundPrompts[prompt] = true
	prompt.AttributeChanged:Connect(function() refreshPrompt(prompt) end)
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function() refreshPrompt(prompt) end)
	refreshPrompt(prompt)
end
workspace.DescendantAdded:Connect(function(item) if item:IsA("ProximityPrompt") then task.defer(bindGardenPrompt, item) end end)
for _, item in ipairs(workspace:GetDescendants()) do bindGardenPrompt(item) end
playerGui:GetAttributeChangedSignal('SelectedGardenFruitIndex'):Connect(function()
 for prompt in pairs(boundPrompts)do if prompt.Parent then refreshPrompt(prompt)end end
end)
playerGui:GetAttributeChangedSignal('GardenSelectionEpoch'):Connect(function()
 for prompt in pairs(boundPrompts)do if prompt.Parent then refreshPrompt(prompt)end end
end)
player:GetAttributeChangedSignal("DataStatus"):Connect(function()
	for prompt in pairs(boundPrompts) do if prompt.Parent then refreshPrompt(prompt) end end
end)

-- V088_NO_PLANTING_DOT: retain device input and gamepad aiming without a world cursor.
local crosshair = makeLabel(aimGui, "GardenGamepadAim", "+", UDim2.fromScale(0.5,0.5), UDim2.fromOffset(28,28),22,Enum.TextXAlignment.Center)
crosshair.AnchorPoint = Vector2.new(0.5,0.5)
crosshair.Visible = false
task.spawn(function()
    while screenGui.Parent do
        task.wait(0.1)
        crosshair.Visible = not playerGui:GetAttribute("SeedMenu") and equippedGardenSeed() ~= nil
            and workspace.CurrentCamera ~= nil
            and tostring(UserInputService:GetLastInputType()):find("Gamepad",1,true) ~= nil
    end
    ContextActionService:UnbindAction("GardenPlaceSeed")
end)
player.CharacterRemoving:Connect(function() crosshair.Visible = false end)
player:GetAttributeChangedSignal("GardenRevision"):Connect(queueSellRefresh)
if panel.Visible then renderCurrentTab() end
if game:GetService('RunService'):IsStudio()then print("[V0.78] PASS - click/tap planting, gamepad RT aiming, per-crop harvest controls and Garden V2 UI loaded.") end -- R114: Studio-only load message
