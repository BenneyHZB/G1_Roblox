-- ============================================================================
-- GameConfig（共享配置）
-- 放在 ReplicatedStorage.Shared，Client / Server 都能 require
-- ============================================================================

local GameConfig = {
	-- 公主（防守目标）
	PrincessMaxHp = 1000,
	PrincessDamagePerHit = 10,
	-- 公主受击音：在公主模型里插入 Sound，命名为 PrincessHit（推荐，不用填 ID）
	PrincessHitSoundName = "PrincessHit",
	PrincessHitSoundId = "", -- 可选；仅当模型里没有 Sound 时使用 rbxassetid://...
	PrincessHitSoundVolume = 0.65,

	-- 波次
	FirstWaveDelay = 5, -- 开局到第 1 波（秒）
	WaveIntermissionStart = 15, -- 第 2 波起波间休息起点（秒）
	WaveIntermissionEnd = 60, -- 波间休息上限（秒）
	WaveIntermissionRampWaves = 30, -- 从起点涨到上限经过的波数（第 2 波=起点，之后逐渐到顶）
	WaveSpawnInterval = 1.5,
	WaveBaseEnemyCount = 3,
	WaveEnemyCountPerWave = 1,

	-- 敌人
	EnemySpeed = 12,
	EnemyReachDistance = 6, -- 进入此距离开始连续攻击公主
	EnemyMaxHealth = 30,
	EnemyAttackCooldown = 1.2, -- 两刀之间的间隔（秒）
	EnemyAttackWindup = 0.4, -- 挥刀动画起手后再结算伤害（秒）

	-- 经济
	StartingGold = 10000,
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

	-- 玩家基础属性（强化在之上叠加）
	DefaultMaxHealth = 100,
	DefaultWalkSpeed = 16,

	-- 强化商店（Workspace.Map.EnhanceShop）
	ShopInteractDistance = 24,
	ShopUpgrades = {
		Damage = {
			DisplayName = "攻击力",
			Description = "每次攻击 +2 伤害",
			BaseCost = 15,
			CostMultiplier = 1.35,
			MaxLevel = 30,
			BonusPerLevel = 2,
		},
		AttackRange = {
			DisplayName = "攻击距离",
			Description = "攻击范围 +0.5",
			BaseCost = 20,
			CostMultiplier = 1.4,
			MaxLevel = 15,
			BonusPerLevel = 0.5,
		},
		PrincessMaxHp = {
			DisplayName = "公主生命上限",
			Description = "公主最大生命 +50",
			BaseCost = 18,
			CostMultiplier = 1.38,
			MaxLevel = 25,
			BonusPerLevel = 50,
		},
		WalkSpeed = {
			DisplayName = "移动速度",
			Description = "移速 +1",
			BaseCost = 25,
			CostMultiplier = 1.45,
			MaxLevel = 10,
			BonusPerLevel = 1,
		},
	},

	-- 商店免费动作（不按等级涨价）
	ShopPrincessHeal = {
		DisplayName = "治疗公主",
		Description = "恢复生命，不消耗金币",
		HealAmount = 200,
		Cooldown = 20,
	},

	-- 训练场（TrainerNPC + DummySpawn + TrainingDummyTemplate）
	Training = {
		MaxLevel = 20,
		-- 首次击败 Lv.N 后解锁 Lv.(N+1)（重复刷同级不会连跳）
		BaseHp = 120,
		HpGrowth = 1.85,
		BaseTrophies = 3,
		TrophyGrowth = 1.72,
		DummyRespawnDelay = 0.2, -- 击杀后同等级刷新间隔（秒）
		InteractDistance = 12,
		TrainerModelName = "TrainerNPC",
		DummySpawnName = "DummySpawn",
		DummyTemplateName = "TrainingDummyTemplate",
		DummySpawnRotationZ = 90, -- 召唤时绕 Z 轴旋转（度）
	},
}

return GameConfig
