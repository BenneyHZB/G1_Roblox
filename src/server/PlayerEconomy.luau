-- ============================================================================
-- PlayerEconomy（玩家金币）
-- 金币在 PlayerData.Gold（不占右上角排行榜）
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local PlayerEconomy = {}

local function ensureGold(player: Player): IntValue
	local data = player:FindFirstChild("PlayerData")
	if not data then
		data = Instance.new("Folder")
		data.Name = "PlayerData"
		data.Parent = player
	end

	local gold = data:FindFirstChild("Gold")
	if not gold then
		gold = Instance.new("IntValue")
		gold.Name = "Gold"
		gold.Value = GameConfig.StartingGold
		gold.Parent = data
	end

	return gold :: IntValue
end

function PlayerEconomy.setupPlayer(player: Player)
	local gold = ensureGold(player)

	-- 旧版：金币在 leaderstats，迁移到 PlayerData 以便右上角只显示奖杯
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local legacyGold = leaderstats:FindFirstChild("Gold")
		if legacyGold and legacyGold:IsA("IntValue") then
			gold.Value = legacyGold.Value
			legacyGold:Destroy()
		end
	end
end

function PlayerEconomy.addGold(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local gold = ensureGold(player)
	gold.Value += amount
end

function PlayerEconomy.getGold(player: Player): number
	return ensureGold(player).Value
end

function PlayerEconomy.trySpendGold(player: Player, amount: number): boolean
	if amount <= 0 then
		return true
	end

	local gold = ensureGold(player)
	if gold.Value < amount then
		return false
	end

	gold.Value -= amount
	return true
end

function PlayerEconomy.start()
	for _, player in Players:GetPlayers() do
		PlayerEconomy.setupPlayer(player)
	end

	Players.PlayerAdded:Connect(PlayerEconomy.setupPlayer)
end

return PlayerEconomy
