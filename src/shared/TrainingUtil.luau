-- ============================================================================
-- TrainingUtil（训练木桩 · 共享公式）
-- ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local TrainingUtil = {}

function TrainingUtil.getLevelStats(level: number): { hp: number, trophies: number }
	local cfg = GameConfig.Training
	local safeLevel = math.max(1, math.floor(level))
	return {
		hp = math.floor(cfg.BaseHp * (cfg.HpGrowth ^ (safeLevel - 1))),
		trophies = math.floor(cfg.BaseTrophies * (cfg.TrophyGrowth ^ (safeLevel - 1))),
	}
end

function TrainingUtil.getMaxUnlocked(player: Player): number
	local unlocked = player:GetAttribute("TrainingMaxUnlocked")
	if typeof(unlocked) ~= "number" then
		return 1
	end
	return math.clamp(math.floor(unlocked), 1, GameConfig.Training.MaxLevel)
end

function TrainingUtil.isLevelUnlocked(player: Player, level: number): boolean
	return level >= 1 and level <= TrainingUtil.getMaxUnlocked(player)
end

return TrainingUtil
