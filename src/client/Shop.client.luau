-- ============================================================================
-- Shop（强化商店 · 客户端 UI）
-- 靠近 Map.EnhanceShop 的 ProximityPrompt 打开面板，购买走 Remotes.ShopPurchase
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer
local purchaseRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopPurchase") :: RemoteFunction

local screenGui: ScreenGui?
local mainFrame: Frame?
local HEAL_ACTION_ID = "PrincessHeal"

local rowByUpgradeId: { [string]: { buyButton: TextButton, infoLabel: TextLabel } } = {}
local healRow: { buyButton: TextButton, infoLabel: TextLabel }?

local function getLevel(upgradeId: string): number
	local level = player:GetAttribute("ShopLevel_" .. upgradeId)
	if typeof(level) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(level))
end

local function getCost(upgradeId: string): number?
	local cfg = GameConfig.ShopUpgrades[upgradeId]
	if not cfg then
		return nil
	end
	local level = getLevel(upgradeId)
	return math.floor(cfg.BaseCost * (cfg.CostMultiplier ^ level))
end

local function refreshRow(upgradeId: string)
	local row = rowByUpgradeId[upgradeId]
	if not row then
		return
	end

	local cfg = GameConfig.ShopUpgrades[upgradeId]
	if not cfg then
		return
	end

	local level = getLevel(upgradeId)
	local cost = getCost(upgradeId)

	row.infoLabel.Text = ("%s  Lv.%d  —  下一级 %d 金币"):format(cfg.DisplayName, level, cost or 0)

	row.buyButton.Text = "购买"
	row.buyButton.Active = true
	row.buyButton.AutoButtonColor = true
	row.buyButton.BackgroundColor3 = Color3.fromRGB(45, 120, 70)
end

local function getHealCooldownRemaining(): number
	local readyAt = player:GetAttribute("PrincessHealReadyAt")
	if typeof(readyAt) ~= "number" then
		return 0
	end
	return math.max(0, readyAt - workspace:GetServerTimeNow())
end

local function refreshHealRow()
	if not healRow then
		return
	end

	local cfg = GameConfig.ShopPrincessHeal
	local remaining = getHealCooldownRemaining()
	local onCooldown = remaining > 0

	healRow.infoLabel.Text = if onCooldown
		then ("%s  —  冷却 %d 秒"):format(cfg.DisplayName, math.ceil(remaining))
		else ("%s  —  恢复 %d HP（免费）"):format(cfg.DisplayName, cfg.HealAmount)

	healRow.buyButton.Text = if onCooldown then "冷却" else "治疗"
	healRow.buyButton.Active = not onCooldown
	healRow.buyButton.AutoButtonColor = not onCooldown
	healRow.buyButton.BackgroundColor3 = if onCooldown
		then Color3.fromRGB(70, 70, 70)
		else Color3.fromRGB(45, 90, 140)
end

local function refreshAll()
	for upgradeId in GameConfig.ShopUpgrades do
		refreshRow(upgradeId)
	end
	refreshHealRow()
end

local function setShopVisible(visible: boolean)
	if mainFrame then
		mainFrame.Visible = visible
	end
	if visible then
		refreshAll()
	end
end

local function tryHeal()
	if getHealCooldownRemaining() > 0 then
		return
	end

	local ok, message = purchaseRemote:InvokeServer(HEAL_ACTION_ID)
	if ok then
		refreshHealRow()
	elseif message then
		warn("[Shop]", message)
	end
end

local function tryPurchase(upgradeId: string)
	local cost = getCost(upgradeId)
	if not cost then
		return
	end

	local playerData = player:FindFirstChild("PlayerData")
	local gold = playerData and playerData:FindFirstChild("Gold") :: IntValue?
	if gold and gold.Value < cost then
		return
	end

	local ok, message = purchaseRemote:InvokeServer(upgradeId)
	if ok then
		refreshAll()
	elseif message then
		warn("[Shop]", message)
	end
end

local function createShopGui()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EnhanceShopGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = true
	screenGui.Parent = playerGui

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "ShopPanel"
	mainFrame.Size = UDim2.fromOffset(400, 400)
	mainFrame.Position = UDim2.new(0.5, -200, 0.5, -200)
	mainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Position = UDim2.fromOffset(12, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "属性强化商店"
	title.Parent = mainFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.Position = UDim2.new(1, -40, 0, 8)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Text = "×"
	closeButton.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		setShopVisible(false)
	end)

	local list = Instance.new("Frame")
	list.Name = "UpgradeList"
	list.Size = UDim2.new(1, -24, 1, -58)
	list.Position = UDim2.fromOffset(12, 48)
	list.BackgroundTransparency = 1
	list.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	for upgradeId, cfg in GameConfig.ShopUpgrades do
		order += 1

		local row = Instance.new("Frame")
		row.Name = upgradeId
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(36, 36, 42)
		row.BorderSizePixel = 0
		row.LayoutOrder = order
		row.Parent = list

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -100, 1, -8)
		info.Position = UDim2.fromOffset(10, 4)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.Gotham
		info.TextSize = 15
		info.TextColor3 = Color3.fromRGB(235, 235, 235)
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.TextWrapped = true
		info.Text = cfg.DisplayName
		info.Parent = row

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -100, 0, 18)
		desc.Position = UDim2.fromOffset(10, 32)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(160, 160, 170)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = cfg.Description
		desc.Parent = row

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(72, 36)
		buy.Position = UDim2.new(1, -82, 0.5, -18)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 16
		buy.TextColor3 = Color3.fromRGB(255, 255, 255)
		buy.Text = "购买"
		buy.Parent = row

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 6)
		buyCorner.Parent = buy

		rowByUpgradeId[upgradeId] = { buyButton = buy, infoLabel = info }

		buy.MouseButton1Click:Connect(function()
			tryPurchase(upgradeId)
		end)

		player:GetAttributeChangedSignal("ShopLevel_" .. upgradeId):Connect(function()
			refreshRow(upgradeId)
		end)
	end

	do
		local healCfg = GameConfig.ShopPrincessHeal
		order += 1

		local row = Instance.new("Frame")
		row.Name = HEAL_ACTION_ID
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(36, 42, 52)
		row.BorderSizePixel = 0
		row.LayoutOrder = order
		row.Parent = list

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -100, 1, -8)
		info.Position = UDim2.fromOffset(10, 4)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.Gotham
		info.TextSize = 15
		info.TextColor3 = Color3.fromRGB(200, 220, 255)
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.TextWrapped = true
		info.Text = healCfg.DisplayName
		info.Parent = row

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -100, 0, 18)
		desc.Position = UDim2.fromOffset(10, 32)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(160, 160, 170)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = healCfg.Description
		desc.Parent = row

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(72, 36)
		buy.Position = UDim2.new(1, -82, 0.5, -18)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 16
		buy.TextColor3 = Color3.fromRGB(255, 255, 255)
		buy.Text = "治疗"
		buy.Parent = row

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 6)
		buyCorner.Parent = buy

		healRow = { buyButton = buy, infoLabel = info }

		buy.MouseButton1Click:Connect(tryHeal)

		player:GetAttributeChangedSignal("PrincessHealReadyAt"):Connect(refreshHealRow)
	end

	local playerData = player:WaitForChild("PlayerData")
	local gold = playerData:WaitForChild("Gold") :: IntValue
	gold.Changed:Connect(refreshAll)
end

local function bindProximityPrompt(shop: Instance)
	local prompt = shop:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		task.delay(1, function()
			bindProximityPrompt(shop)
		end)
		return
	end

	prompt.Triggered:Connect(function(triggeredPlayer)
		if triggeredPlayer == player then
			setShopVisible(true)
		end
	end)
end

local function startHealCooldownTicker()
	task.spawn(function()
		while true do
			if healRow and mainFrame and mainFrame.Visible and getHealCooldownRemaining() > 0 then
				refreshHealRow()
			end
			task.wait(0.5)
		end
	end)
end

local function init()
	createShopGui()
	refreshAll()
	startHealCooldownTicker()

	task.spawn(function()
		local map = Workspace:WaitForChild("Map", 30)
		if not map then
			return
		end
		local shop = map:WaitForChild("EnhanceShop", 30)
		if shop then
			bindProximityPrompt(shop)
		end
	end)
end

init()
