-- ============================================================================
-- GameConfig（共享配置）
-- 放在 ReplicatedStorage.Shared，Client / Server 都能 require
-- ============================================================================

local GameConfig = {
	-- 公主（防守目标）
	PrincessMaxHp = 1000,
	PrincessDamagePerHit = 10,

	-- 波次
	WaveIntermission = 5,
	WaveSpawnInterval = 0.6,
	WaveBaseEnemyCount = 3,
	WaveEnemyCountPerWave = 1,

	-- 敌人
	EnemySpeed = 12,
	EnemyReachDistance = 4, -- 进入此距离开始连续攻击公主
	EnemyMaxHealth = 30,
	EnemyAttackCooldown = 1.2, -- 两刀之间的间隔（秒）
	EnemyAttackWindup = 0.4, -- 挥刀动画起手后再结算伤害（秒）

	-- 经济
	StartingGold = 0,
	GoldPerWaveEnemyKill = 1,

	-- 空手战斗（无 Tool 时）
	AttackRange = 10,
	AttackDamage = 8,
	AttackCooldown = 0.5,

	-- 武器默认（Tool.Name 未在 WeaponStats 里时使用）
	ToolAttackDamage = 25,
	ToolAttackRange = 12,
	ToolAttackCooldown = 0.45,

	-- 按武器名配置伤害（Tool 名须与 Studio 里一致，如 Sword）
	-- Tool 上的 Attribute 可覆盖单项：Damage / AttackRange / AttackCooldown
	WeaponStats = {
		Sword = {
			Damage = 25,
			Range = 12,
			Cooldown = 0.45,
			-- HasBuiltInAnim 不设 = 有 LocalScript+Animation 时走武器自带
		},
		["Ban Hammer"] = {
			Damage = 30,
			Range = 10,
			Cooldown = 0.6,
			-- 锤子无有效攻击动画，指定兜底挥砍（可改成你的动画 ID）
			AnimId = "rbxassetid://522635514",
			AnimSpeed = 1,
		},
	},

	-- 无脚本武器的默认攻击动画
	FallbackWeaponAnimId = "rbxassetid://522635514",
	FallbackWeaponAnimSpeed = 1,
	-- Tool Attribute:
	--   HasBuiltInAnim=true  → 完全走武器 LocalScript
	--   UseFallbackAnim=true → 强制播 AnimId / 兜底动画

	EnemyHitKnockbackDistance = 2.5,
	EnemyHitKnockbackDuration = 0.18,
}

return GameConfig
