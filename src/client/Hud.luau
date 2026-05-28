-- ============================================================================
-- Hud（客户端 UI）
-- 公主 HP、波次状态、玩家金币
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Hud = {}

local function createLabel(parent: Instance, name: string, yOffset: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromOffset(320, 40)
	label.Position = UDim2.fromOffset(16, yOffset)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.Parent = label

	return label
end

function Hud.create()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameHud"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local princessLabel = createLabel(screenGui, "PrincessHpLabel", 16)
	local waveLabel = createLabel(screenGui, "WaveLabel", 64)
	local goldLabel = createLabel(screenGui, "GoldLabel", 112)
	local trophyLabel = createLabel(screenGui, "TrophyLabel", 152)
	trophyLabel.TextColor3 = Color3.fromRGB(255, 215, 100)

	local gameState = ReplicatedStorage:WaitForChild("GameState", 120)
	if not gameState then
		warn("[Hud] 未找到 GameState，请确认服务端 WaveDefense 已启动")
		return
	end
	local princessHp = gameState:WaitForChild("PrincessHp") :: IntValue
	local princessMaxHp = gameState:WaitForChild("PrincessMaxHp") :: IntValue
	local waveNumber = gameState:WaitForChild("WaveNumber") :: IntValue
	local wavePhase = gameState:WaitForChild("WavePhase") :: StringValue
	local waveCountdown = gameState:WaitForChild("WaveCountdown") :: IntValue

	local playerData = player:WaitForChild("PlayerData", 60)
	if not playerData then
		warn("[Hud] 未找到 PlayerData")
		return
	end
	local gold = playerData:WaitForChild("Gold", 60) :: IntValue
	local leaderstats = player:WaitForChild("leaderstats", 60)
	if not leaderstats then
		warn("[Hud] 未找到 leaderstats")
		return
	end
	local trophies = leaderstats:WaitForChild("Trophies", 60) :: IntValue

	local function refreshPrincess()
		if princessHp.Value <= 0 then
			princessLabel.Text = "公主 HP: 0  —  已失守"
			princessLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		else
			princessLabel.Text = ("公主 HP: %d / %d"):format(princessHp.Value, princessMaxHp.Value)
			princessLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	local function refreshWave()
		if wavePhase.Value == "Defeated" then
			waveLabel.Text = "游戏结束"
		elseif wavePhase.Value == "Intermission" then
			if waveNumber.Value == 0 then
				waveLabel.Text = ("准备中：%d 秒后第 1 波"):format(waveCountdown.Value)
			else
				waveLabel.Text = ("第 %d 波已清：%d 秒后下一波"):format(waveNumber.Value, waveCountdown.Value)
			end
		else
			waveLabel.Text = ("第 %d 波进行中"):format(waveNumber.Value)
		end
	end

	local function refreshGold()
		goldLabel.Text = ("金币: %d"):format(gold.Value)
	end

	local function refreshTrophies()
		trophyLabel.Text = ("奖杯: %d"):format(trophies.Value)
	end

	princessHp.Changed:Connect(refreshPrincess)
	princessMaxHp.Changed:Connect(refreshPrincess)
	waveNumber.Changed:Connect(refreshWave)
	wavePhase.Changed:Connect(refreshWave)
	waveCountdown.Changed:Connect(refreshWave)
	gold.Changed:Connect(refreshGold)
	trophies.Changed:Connect(refreshTrophies)

	refreshPrincess()
	refreshWave()
	refreshGold()
	refreshTrophies()

	-- 公主失守：全屏提示 + 任意一名玩家可点重开
	local defeatFrame = Instance.new("Frame")
	defeatFrame.Name = "DefeatOverlay"
	defeatFrame.Size = UDim2.fromScale(1, 1)
	defeatFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	defeatFrame.BackgroundTransparency = 0.45
	defeatFrame.Visible = false
	defeatFrame.ZIndex = 20
	defeatFrame.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 220)
	panel.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	panel.BorderSizePixel = 0
	panel.Parent = defeatFrame

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 56)
	title.Position = UDim2.fromOffset(12, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 100, 100)
	title.Text = "公主失守"
	title.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -24, 0, 48)
	hint.Position = UDim2.fromOffset(12, 72)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextWrapped = true
	hint.TextSize = 16
	hint.TextColor3 = Color3.fromRGB(220, 220, 230)
	hint.Text = "本局结束。任意玩家点击下方按钮：波次与公主血量重开，金币/武器/强化/训练进度清零，奖杯保留。"
	hint.Parent = panel

	local restartButton = Instance.new("TextButton")
	restartButton.Name = "RestartButton"
	restartButton.AnchorPoint = Vector2.new(0.5, 1)
	restartButton.Position = UDim2.new(0.5, 0, 1, -20)
	restartButton.Size = UDim2.fromOffset(260, 48)
	restartButton.BackgroundColor3 = Color3.fromRGB(46, 160, 90)
	restartButton.Font = Enum.Font.GothamBold
	restartButton.TextSize = 20
	restartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	restartButton.Text = "重新开始"
	restartButton.AutoButtonColor = true
	restartButton.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = restartButton

	local restartRemote: RemoteFunction? = nil
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 120)
		if remotes then
			restartRemote = remotes:WaitForChild("RestartDefense", 120) :: RemoteFunction
		end
	end)

	local restarting = false

	local function setDefeatVisible(visible: boolean)
		defeatFrame.Visible = visible
		restartButton.Text = "重新开始"
		restarting = false
	end

	local function refreshDefeatOverlay()
		setDefeatVisible(wavePhase.Value == "Defeated")
	end

	wavePhase.Changed:Connect(refreshDefeatOverlay)
	refreshDefeatOverlay()

	restartButton.MouseButton1Click:Connect(function()
		if restarting or wavePhase.Value ~= "Defeated" then
			return
		end

		if not restartRemote then
			restartButton.Text = "服务器未就绪"
			task.delay(2, function()
				if wavePhase.Value == "Defeated" then
					restartButton.Text = "重新开始"
				end
			end)
			return
		end

		restarting = true
		restartButton.Text = "正在重开…"
		restartButton.AutoButtonColor = false

		local ok, message = restartRemote:InvokeServer()
		if ok then
			restartButton.Text = message or "即将开始"
		else
			restarting = false
			restartButton.AutoButtonColor = true
			restartButton.Text = message or "重开失败"
			task.delay(2, function()
				if wavePhase.Value == "Defeated" then
					restartButton.Text = "重新开始"
				end
			end)
		end
	end)

	wavePhase.Changed:Connect(function()
		if wavePhase.Value ~= "Defeated" then
			TweenService:Create(defeatFrame, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
			task.delay(0.2, function()
				if wavePhase.Value ~= "Defeated" then
					setDefeatVisible(false)
					defeatFrame.BackgroundTransparency = 0.45
				end
			end)
		end
	end)
end

return Hud
