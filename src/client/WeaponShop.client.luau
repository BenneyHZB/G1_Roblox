-- ============================================================================
-- WeaponShop（武器店 · 客户端 UI）
-- ReplicatedStorage.Weapons 内武器；奖牌达标领取，不消耗奖牌
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer
local purchaseRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponShopPurchase") :: RemoteFunction

local screenGui: ScreenGui?
local mainFrame: Frame?
local listFrame: Frame?
local trophyHeader: TextLabel?

local rowByItemId: { [string]: { infoLabel: TextLabel, buyButton: TextButton } } = {}

local function getShopCfg()
	return GameConfig.WeaponShop
end

local function getItemOrder(): { string }
	local cfg = getShopCfg()
	if cfg.ItemOrder then
		return cfg.ItemOrder
	end
	local ids = {}
	for itemId in cfg.Items do
		table.insert(ids, itemId)
	end
	table.sort(ids)
	return ids
end

local function getTrophies(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return 0
	end
	local trophies = leaderstats:FindFirstChild("Trophies") :: IntValue?
	return if trophies then trophies.Value else 0
end

local function ownsWeapon(item): boolean
	if player:GetAttribute(item.OwnershipAttribute) == true then
		return true
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack and backpack:FindFirstChild(item.WeaponToolName) then
		return true
	end
	local character = player.Character
	if character and character:FindFirstChild(item.WeaponToolName) then
		return true
	end
	return false
end

local function refreshHeader()
	if not trophyHeader then
		return
	end
	trophyHeader.Text = ("当前奖牌: %d  （领取武器不消耗奖牌）"):format(getTrophies())
end

local function refreshRow(itemId: string)
	local row = rowByItemId[itemId]
	local item = getShopCfg().Items[itemId]
	if not row or not item then
		return
	end

	local trophies = getTrophies()
	local owned = ownsWeapon(item)
	local enough = trophies >= item.TrophyRequired
	local stats = GameConfig.WeaponStats[item.WeaponToolName]
	local damageText = if stats and stats.Damage then tostring(stats.Damage) else "?"

	if owned then
		row.infoLabel.Text = ("%s  —  伤害 %s  ·  已拥有"):format(item.DisplayName, damageText)
		row.buyButton.Text = "已拥有"
		row.buyButton.Active = false
		row.buyButton.AutoButtonColor = false
		row.buyButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	elseif enough then
		row.infoLabel.Text = ("%s  —  伤害 %s\n需要 %d 奖牌"):format(item.DisplayName, damageText, item.TrophyRequired)
		row.buyButton.Text = "领取"
		row.buyButton.Active = true
		row.buyButton.AutoButtonColor = true
		row.buyButton.BackgroundColor3 = Color3.fromRGB(120, 85, 40)
	else
		row.infoLabel.Text = ("%s  —  伤害 %s\n需要 %d 奖牌（还差 %d）"):format(
			item.DisplayName,
			damageText,
			item.TrophyRequired,
			item.TrophyRequired - trophies
		)
		row.buyButton.Text = "奖牌不足"
		row.buyButton.Active = false
		row.buyButton.AutoButtonColor = false
		row.buyButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	end
end

local function refreshAll()
	refreshHeader()
	for itemId in rowByItemId do
		refreshRow(itemId)
	end
end

local function setVisible(visible: boolean)
	if mainFrame then
		mainFrame.Visible = visible
	end
	if visible then
		refreshAll()
	end
end

local function tryPurchase(itemId: string)
	local item = getShopCfg().Items[itemId]
	if not item or ownsWeapon(item) then
		return
	end
	if getTrophies() < item.TrophyRequired then
		return
	end

	local ok, message = purchaseRemote:InvokeServer(itemId)
	if message then
		if ok then
			print("[WeaponShop]", message)
		else
			warn("[WeaponShop]", message)
		end
	end
	refreshAll()
end

local function createGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local itemOrder = getItemOrder()
	local rowCount = #itemOrder
	local panelHeight = 120 + rowCount * 72

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WeaponShopGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "WeaponShopPanel"
	mainFrame.Size = UDim2.fromOffset(420, panelHeight)
	mainFrame.Position = UDim2.new(0.5, -210, 0.5, -panelHeight / 2)
	mainFrame.BackgroundColor3 = Color3.fromRGB(28, 24, 20)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 32)
	title.Position = UDim2.fromOffset(12, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 200, 100)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "武器店"
	title.Parent = mainFrame

	trophyHeader = Instance.new("TextLabel")
	trophyHeader.Size = UDim2.new(1, -24, 0, 22)
	trophyHeader.Position = UDim2.fromOffset(12, 44)
	trophyHeader.BackgroundTransparency = 1
	trophyHeader.Font = Enum.Font.Gotham
	trophyHeader.TextSize = 14
	trophyHeader.TextColor3 = Color3.fromRGB(255, 215, 100)
	trophyHeader.TextXAlignment = Enum.TextXAlignment.Left
	trophyHeader.Parent = mainFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.Position = UDim2.new(1, -40, 0, 8)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 55, 50)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Text = "×"
	closeButton.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton
	closeButton.MouseButton1Click:Connect(function()
		setVisible(false)
	end)

	listFrame = Instance.new("Frame")
	listFrame.Name = "List"
	listFrame.Size = UDim2.new(1, -24, 1, -80)
	listFrame.Position = UDim2.fromOffset(12, 72)
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame

	for index, itemId in itemOrder do
		local item = getShopCfg().Items[itemId]
		if not item then
			continue
		end

		local row = Instance.new("Frame")
		row.Name = itemId
		row.Size = UDim2.new(1, 0, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(40, 36, 32)
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Parent = listFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -100, 1, -8)
		info.Position = UDim2.fromOffset(10, 4)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.Gotham
		info.TextSize = 14
		info.TextColor3 = Color3.fromRGB(230, 230, 230)
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.TextWrapped = true
		info.Parent = row

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(80, 36)
		buy.Position = UDim2.new(1, -88, 0.5, -18)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 14
		buy.TextColor3 = Color3.fromRGB(255, 255, 255)
		buy.Parent = row

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 6)
		buyCorner.Parent = buy

		rowByItemId[itemId] = { infoLabel = info, buyButton = buy }
		buy.MouseButton1Click:Connect(function()
			tryPurchase(itemId)
		end)

		player:GetAttributeChangedSignal(item.OwnershipAttribute):Connect(function()
			refreshRow(itemId)
		end)
	end

	local leaderstats = player:WaitForChild("leaderstats")
	local trophies = leaderstats:WaitForChild("Trophies") :: IntValue
	trophies.Changed:Connect(refreshAll)
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
			setVisible(true)
		end
	end)
end

createGui()
refreshAll()

task.spawn(function()
	local map = Workspace:WaitForChild("Map", 30)
	if not map then
		return
	end

	local cfg = getShopCfg()
	local shop = map:FindFirstChild(cfg.ShopModelName, true) or map:FindFirstChild("武器店", true)
	if shop then
		bindProximityPrompt(shop)
	end
end)
