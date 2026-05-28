-- ============================================================================
-- Hud（客户端 UI）
-- 只负责显示，不修改游戏逻辑；读 ReplicatedStorage 里服务端写入的状态
-- 类似 UE 的 UMG Widget 绑定 replicated 变量
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Hud = {}

function Hud.create()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CityDefenseHud"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "CityHpLabel"
	label.Size = UDim2.fromOffset(280, 48)
	label.Position = UDim2.fromOffset(16, 16)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = screenGui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.Parent = label

	local gameState = ReplicatedStorage:WaitForChild("GameState")
	local cityHp = gameState:WaitForChild("CityHp") :: IntValue

	local function refresh()
		if cityHp.Value <= 0 then
			label.Text = "城堡 HP: 0  —  已失守"
			label.TextColor3 = Color3.fromRGB(255, 90, 90)
		else
			label.Text = ("城堡 HP: %d / %d"):format(cityHp.Value, GameConfig.CityMaxHp)
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	cityHp.Changed:Connect(refresh)
	refresh()
end

return Hud
