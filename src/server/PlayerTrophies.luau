-- ============================================================================
-- PlayerTrophies（奖杯 · 累计不消耗）
-- leaderstats.Trophies → 右上角排行榜；换购时只检查门槛，不扣减
-- ============================================================================

local Players = game:GetService("Players")

local PlayerTrophies = {}

local function ensureTrophies(player: Player): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local trophies = leaderstats:FindFirstChild("Trophies")
	if not trophies then
		trophies = Instance.new("IntValue")
		trophies.Name = "Trophies"
		trophies.Value = 0
		trophies.Parent = leaderstats
	end

	return trophies :: IntValue
end

function PlayerTrophies.setupPlayer(player: Player)
	ensureTrophies(player)
end

function PlayerTrophies.add(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	ensureTrophies(player).Value += amount
end

function PlayerTrophies.get(player: Player): number
	return ensureTrophies(player).Value
end

-- 后期换购：累计奖杯达到门槛即可（不扣奖杯）
function PlayerTrophies.meetsThreshold(player: Player, required: number): boolean
	return PlayerTrophies.get(player) >= required
end

function PlayerTrophies.start()
	for _, player in Players:GetPlayers() do
		PlayerTrophies.setupPlayer(player)
	end
	Players.PlayerAdded:Connect(PlayerTrophies.setupPlayer)
end

return PlayerTrophies
