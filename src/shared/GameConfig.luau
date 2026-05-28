-- ============================================================================
-- GameConfig（共享配置）
-- 放在 ReplicatedStorage.Shared，Client / Server 都能 require
-- 类似 UE 的 DataTable / 全局 GameMode 默认值
-- ============================================================================

local GameConfig = {
	CityMaxHp = 100,
	CityDamagePerHit = 10,

	EnemySpawnInterval = 3,
	EnemySpeed = 12,
	EnemyReachDistance = 4,
}

return GameConfig
