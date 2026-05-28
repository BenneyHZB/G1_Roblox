-- ============================================================================
-- PlayerEconomy（玩家金币）
-- 每人独立金币，显示在 leaderstats.Gold
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local PlayerEconomy = {}

local function ensureLeaderstats(player: Player): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local gold = leaderstats:FindFirstChild("Gold")
	if not gold then
		gold = Instance.new("IntValue")
		gold.Name = "Gold"
		gold.Value = GameConfig.StartingGold
		gold.Parent = leaderstats
	end

	return gold :: IntValue
end

function PlayerEconomy.setupPlayer(player: Player)
	ensureLeaderstats(player)
end

function PlayerEconomy.addGold(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local gold = ensureLeaderstats(player)
	gold.Value += amount
end

function PlayerEconomy.getGold(player: Player): number
	return ensureLeaderstats(player).Value
end

function PlayerEconomy.start()
	for _, player in Players:GetPlayers() do
		PlayerEconomy.setupPlayer(player)
	end

	Players.PlayerAdded:Connect(PlayerEconomy.setupPlayer)
end

return PlayerEconomy
