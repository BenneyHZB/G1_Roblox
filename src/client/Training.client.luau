-- ============================================================================
-- Training（训练场 · 客户端 UI）
-- Map.TrainerNPC → 选等级召唤木桩
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local TrainingUtil = require(ReplicatedStorage.Shared.TrainingUtil)

local player = Players.LocalPlayer
local summonRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TrainingSummon") :: RemoteFunction

local screenGui: ScreenGui?
local mainFrame: Frame?
local listFrame: Frame?
local statusLabel: TextLabel?

local function refreshStatus()
	if not statusLabel then
		return
	end
	local unlocked = TrainingUtil.getMaxUnlocked(player)
	local beaten = player:GetAttribute("TrainingHighestBeaten")
	if typeof(beaten) ~= "number" then
		beaten = 0
	end
	local trophies = player:WaitForChild("leaderstats"):WaitForChild("Trophies") :: IntValue
	local active = player:GetAttribute("TrainingActiveLevel")
	local farmingText = if typeof(active) == "number" then ("  |  正在刷: Lv.%d"):format(active) else ""
	statusLabel.Text = ("已解锁: Lv.1 ~ %d  |  最高击败: Lv.%d  |  奖杯: %d%s"):format(
		unlocked,
		beaten,
		trophies.Value,
		farmingText
	)
end

local function refreshRows()
	if not listFrame then
		return
	end

	for _, row in listFrame:GetChildren() do
		if row:IsA("Frame") and row.Name:match("^Level%d+$") then
			local level = tonumber(row.Name:match("%d+"))
			if level then
				local info = row:FindFirstChild("Info") :: TextLabel?
				local btn = row:FindFirstChild("Summon") :: TextButton?
				if info and btn then
					local stats = TrainingUtil.getLevelStats(level)
					local unlocked = TrainingUtil.isLevelUnlocked(player, level)
					if unlocked then
						info.Text = ("Lv.%d  血量 %d  奖杯 +%d"):format(level, stats.hp, stats.trophies)
						btn.Text = "开始刷"
						btn.Active = true
						btn.AutoButtonColor = true
						btn.BackgroundColor3 = Color3.fromRGB(45, 100, 150)
					else
						info.Text = ("Lv.%d  血量 %d  奖杯 +%d  （未解锁）"):format(level, stats.hp, stats.trophies)
						btn.Text = "锁定"
						btn.Active = false
						btn.AutoButtonColor = false
						btn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
					end
				end
			end
		end
	end
	refreshStatus()
end

local function setVisible(visible: boolean)
	if mainFrame then
		mainFrame.Visible = visible
	end
	if visible then
		refreshRows()
	end
end

local function trySummon(level: number)
	if not TrainingUtil.isLevelUnlocked(player, level) then
		return
	end
	local ok, message = summonRemote:InvokeServer(level)
	if message then
		if ok then
			print("[Training]", message)
		else
			warn("[Training]", message)
		end
	end
end

local function createGui()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TrainingGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "TrainingPanel"
	mainFrame.Size = UDim2.fromOffset(420, 460)
	mainFrame.Position = UDim2.new(0.5, -210, 0.5, -230)
	mainFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 32)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -50, 0, 36)
	title.Position = UDim2.fromOffset(12, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(140, 200, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "训练木桩"
	title.Parent = mainFrame

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(32, 32)
	close.Position = UDim2.new(1, -40, 0, 8)
	close.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.Text = "×"
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Parent = mainFrame
	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

	close.MouseButton1Click:Connect(function()
		setVisible(false)
	end)

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -24, 0, 22)
	statusLabel.Position = UDim2.fromOffset(12, 44)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.fromRGB(180, 190, 200)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = mainFrame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.new(1, -24, 1, -78)
	scroll.Position = UDim2.fromOffset(12, 70)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = mainFrame

	listFrame = Instance.new("Frame")
	listFrame.Name = "List"
	listFrame.Size = UDim2.new(1, 0, 0, 0)
	listFrame.AutomaticSize = Enum.AutomaticSize.Y
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame

	local cfg = GameConfig.Training
	for level = 1, cfg.MaxLevel do
		local row = Instance.new("Frame")
		row.Name = ("Level%d"):format(level)
		row.Size = UDim2.new(1, 0, 0, 48)
		row.BackgroundColor3 = Color3.fromRGB(34, 40, 48)
		row.LayoutOrder = level
		row.Parent = listFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		local info = Instance.new("TextLabel")
		info.Name = "Info"
		info.Size = UDim2.new(1, -90, 1, -8)
		info.Position = UDim2.fromOffset(10, 4)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.Gotham
		info.TextSize = 14
		info.TextColor3 = Color3.fromRGB(230, 235, 240)
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.Parent = row

		local btn = Instance.new("TextButton")
		btn.Name = "Summon"
		btn.Size = UDim2.fromOffset(72, 32)
		btn.Position = UDim2.new(1, -82, 0.5, -16)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 15
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Text = "召唤"
		btn.Parent = row
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		btn.MouseButton1Click:Connect(function()
			trySummon(level)
		end)
	end

	player:GetAttributeChangedSignal("TrainingMaxUnlocked"):Connect(refreshRows)
	player:GetAttributeChangedSignal("TrainingHighestBeaten"):Connect(refreshRows)
	player:GetAttributeChangedSignal("TrainingActiveLevel"):Connect(refreshStatus)
	local trophies = player:WaitForChild("leaderstats"):WaitForChild("Trophies") :: IntValue
	trophies.Changed:Connect(refreshStatus)
end

local function bindTrainer()
	local cfg = GameConfig.Training
	local map = Workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	local trainer = map:WaitForChild(cfg.TrainerModelName, 30)
	if not trainer then
		return
	end

	local prompt = trainer:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		task.delay(1, bindTrainer)
		return
	end

	prompt.Triggered:Connect(function(who)
		if who == player then
			setVisible(true)
		end
	end)
end

createGui()
refreshRows()
task.spawn(bindTrainer)
