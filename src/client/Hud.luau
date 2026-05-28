-- ============================================================================
-- Hud（客户端 UI）
-- 公主 HP、波次状态、玩家金币
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	local gameState = ReplicatedStorage:WaitForChild("GameState")
	local princessHp = gameState:WaitForChild("PrincessHp") :: IntValue
	local waveNumber = gameState:WaitForChild("WaveNumber") :: IntValue
	local wavePhase = gameState:WaitForChild("WavePhase") :: StringValue
	local waveCountdown = gameState:WaitForChild("WaveCountdown") :: IntValue

	local leaderstats = player:WaitForChild("leaderstats")
	local gold = leaderstats:WaitForChild("Gold") :: IntValue

	local function refreshPrincess()
		if princessHp.Value <= 0 then
			princessLabel.Text = "公主 HP: 0  —  已失守"
			princessLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		else
			princessLabel.Text = ("公主 HP: %d / %d"):format(princessHp.Value, GameConfig.PrincessMaxHp)
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

	princessHp.Changed:Connect(refreshPrincess)
	waveNumber.Changed:Connect(refreshWave)
	wavePhase.Changed:Connect(refreshWave)
	waveCountdown.Changed:Connect(refreshWave)
	gold.Changed:Connect(refreshGold)

	refreshPrincess()
	refreshWave()
	refreshGold()
end

return Hud
