-- ============================================================================
-- GameConfig（共享配置）
-- 放在 ReplicatedStorage.Shared，Client / Server 都能 require
-- ============================================================================

local GameConfig = {
	-- 房间（好友房：Studio → 游戏设置 → 最大玩家数 设为 4；服务端也会踢超额加入）
	MaxPlayers = 4,

	-- 公主（防守目标）
	PrincessMaxHp = 1000,
	PrincessDamagePerHit = 10,
	-- 公主受击音：模型里 Sound 仅作 SoundId 来源；实际在客户端 SoundService 全局播放
	PrincessHitSoundName = "PrincessHit",
	PrincessHitSoundId = "rbxassetid://113031837388924", -- 可选；仅当模型里没有 Sound 时使用 rbxassetid://...
	PrincessHitSoundVolume = 0.65,

	-- 波次
	FirstWaveDelay = 15, -- 开局到第 1 波（秒）
	WaveIntermissionStart = 15, -- 第 2 波起波间休息起点（秒）
	WaveIntermissionEnd = 60, -- 波间休息上限（秒）
	WaveIntermissionRampWaves = 30, -- 从起点涨到上限经过的波数（第 2 波=起点，之后逐渐到顶）
	WaveSpawnInterval = 1.5,
	WaveBaseEnemyCount = 3,
	WaveEnemyCountPerWave = 1,

	-- 敌人（第 1 波为基准；之后每波按下方增量变强）
	EnemySpeed = 12,
	EnemyReachDistance = 6, -- 进入此距离开始连续攻击公主
	EnemyMaxHealth = 30,
	EnemyAttackCooldown = 1.2, -- 两刀之间的间隔（秒）
	EnemyAttackWindup = 0.4, -- 挥刀动画起手后再结算伤害（秒）
	-- 波次成长（wave N：基准 + (N-1) * 增量，并受上限约束）
	WaveEnemyHealthPerWave = 8,
	WaveEnemySpeedPerWave = 0.45,
	WaveEnemyPrincessDamagePerWave = 1.2,
	WaveEnemyMaxHealth = 600,
	WaveEnemyMaxSpeed = 24,
	WaveEnemyMaxPrincessDamagePerHit = 50,

	-- 经济
	StartingGold = 1,
	GoldPerWaveEnemyKill = 1,
	StartingTrophies = 1,

	-- 奖杯存档（跨服务器；须在 Creator Hub 发布体验，Studio 需开启 API 服务）
	TrophyDataStore = {
		StoreName = "PlayerTrophies_v1",
		KeyPrefix = "u_",
		AutoSaveSeconds = 45,
	},

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
		},
		["Ban Hammer"] = {
			Damage = 80,
			Range = 11,
			Cooldown = 0.58,
			AnimId = "rbxassetid://522635514",
			AnimSpeed = 1,
		},
		["Rainbow Sword"] = {
			Damage = 500,
			Range = 13,
			Cooldown = 0.4,
			UseFallbackAnim = true,
		},
		Azure = {
			Damage = 750,
			Range = 14,
			Cooldown = 0.36,
			UseFallbackAnim = true,
		},
	},

	-- 无脚本武器的默认攻击动画 / 挥砍音效（R15 通用挥砍；勿用 Toolbox 剑自带的 R6 动画 ID）
	FallbackWeaponAnimId = "rbxassetid://522635514",
	FallbackWeaponAnimSpeed = 1,
	FallbackWeaponSwingSoundId = "rbxassetid://12222216", -- 经典挥剑音效，可按需替换
	FallbackWeaponSwingSoundVolume = 0.55,
	-- Tool Attribute:
	--   HasBuiltInAnim=true  → 完全走武器 LocalScript
	--   UseFallbackAnim=true → 强制播 AnimId / 兜底动画

	EnemyHitKnockbackDistance = 2.5,
	EnemyHitKnockbackDuration = 0.18,

	-- 玩家基础属性（强化在之上叠加）
	DefaultMaxHealth = 100,
	DefaultWalkSpeed = 16,

	-- 地图地点头顶标识（MapLocationLabels.client.luau）
	MapLabels = {
		StudsOffset = Vector3.new(0, 4, 0),
		Locations = {
			{
				TargetName = "TrainerNPC",
				AltNames = { "训练师" },
				Title = "训练师",
				Subtitle = "打木桩 · 得奖牌",
				AccentColor = Color3.fromRGB(255, 210, 90),
			},
			{
				TargetName = "WeaponShop",
				AltNames = { "武器店" },
				Title = "武器店",
				Subtitle = "奖牌兑换武器",
				AccentColor = Color3.fromRGB(255, 170, 90),
			},
			{
				TargetName = "EnhanceShop",
				AltNames = { "强化店", "强化商店" },
				Title = "强化商店",
				Subtitle = "金币升级属性",
				AccentColor = Color3.fromRGB(120, 200, 255),
			},
			{
				TargetName = "GoldFarmBase",
				AltNames = { "金币农场" },
				Title = "金币农场",
				Subtitle = "",
				AccentColor = Color3.fromRGB(120, 230, 140),
			},
		},
	},

	-- 武器店（Map.WeaponShop · 模板在 ReplicatedStorage.Weapons）
	WeaponShop = {
		ShopModelName = "WeaponShop",
		InteractDistance = 24,
		WeaponsFolderName = "Weapons",
		ItemOrder = { "Sword", "BanHammer", "RainbowSword", "Azure" },
		Items = {
			Sword = {
				WeaponToolName = "Sword",
				DisplayName = "剑",
				Description = "基础近战武器",
				TrophyRequired = 1,
				OwnershipAttribute = "OwnedWeapon_Sword",
			},
			BanHammer = {
				WeaponToolName = "Ban Hammer",
				TemplateAliases = { "BanHammer", "Ban_Hammer" },
				DisplayName = "封禁之锤",
				Description = "高伤害重锤",
				TrophyRequired = 50,
				OwnershipAttribute = "OwnedWeapon_BanHammer",
			},
			RainbowSword = {
				WeaponToolName = "Rainbow Sword",
				TemplateAliases = { "RainbowSword" },
				DisplayName = "彩虹剑",
				Description = "高伤害速攻",
				TrophyRequired = 500,
				OwnershipAttribute = "OwnedWeapon_RainbowSword",
			},
			Azure = {
				WeaponToolName = "Azure",
				DisplayName = "蔚蓝",
				Description = "顶级武器 · 伤害最高",
				TrophyRequired = 2000,
				OwnershipAttribute = "OwnedWeapon_Azure",
			},
		},
	},

	-- 强化商店（Workspace.Map.EnhanceShop）
	ShopInteractDistance = 24,
	ShopUpgrades = {
		Damage = {
			DisplayName = "攻击力",
			Description = "每次攻击 +2 伤害",
			BaseCost = 15,
			CostMultiplier = 1.35,
			BonusPerLevel = 2,
		},
		AttackRange = {
			DisplayName = "攻击距离",
			Description = "攻击范围 +0.5",
			BaseCost = 20,
			CostMultiplier = 1.4,
			BonusPerLevel = 0.5,
		},
		PrincessMaxHp = {
			DisplayName = "公主生命上限",
			Description = "公主最大生命 +50",
			BaseCost = 18,
			CostMultiplier = 1.38,
			BonusPerLevel = 50,
		},
		WalkSpeed = {
			DisplayName = "移动速度",
			Description = "移速 +1",
			BaseCost = 25,
			CostMultiplier = 1.45,
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

	-- 金币农场（Map.GoldFarmZone 长条 + Map.GoldFarmBase 基地端 + Map.Coin 模板）
	GoldFarm = {
		ZonePartName = "GoldFarmZone",
		BasePartName = "GoldFarmBase",
		-- 优先 Map 里你导入的 Coin；没有则用 ReplicatedStorage.CoinFarmTemplate
		CoinTemplateName = "CoinFarmTemplate",
		PreferMapCoinTemplate = true,
		MapCoinName = "Coin",
		MaxCoins = 40,
		InitialCoinCount = 40,
		RespawnDelay = 3.5,
		SpawnStagger = 0.03,
		SpawnAttempts = 14,
		InteractDistance = 10,
		ZoneEdgeMargin = 4,
		MinCoinSpacing = 5,
		CoinGroundLift = 1.2, -- 射线贴地后抬高，避免陷进地形
		CoinScaleMin = 0.85,
		CoinScaleMax = 1.4,
		-- 同档位内：金币越高，采集略久，但收益仍明显更高
		CollectTimePerBonusGold = 0.006,
		-- 离基地越远（0→1）档位越高；采集时间略增，金币显著增多
		Tiers = {
			{
				Name = "铜",
				MaxDistance = 0.28,
				GoldMin = 3,
				GoldMax = 7,
				CollectTime = 0.42,
				CoinColor = Color3.fromRGB(198, 142, 78),
			},
			{
				Name = "银",
				MaxDistance = 0.55,
				GoldMin = 9,
				GoldMax = 18,
				CollectTime = 0.62,
				CoinColor = Color3.fromRGB(200, 205, 215),
			},
			{
				Name = "金",
				MaxDistance = 0.82,
				GoldMin = 22,
				GoldMax = 45,
				CollectTime = 0.88,
				CoinColor = Color3.fromRGB(255, 210, 60),
			},
			{
				Name = "钻",
				MaxDistance = 1.0,
				GoldMin = 55,
				GoldMax = 120,
				CollectTime = 1.25,
				CoinColor = Color3.fromRGB(120, 220, 255),
			},
		},
	},

	-- 新手指引（客户端 TutorialGuide.client.luau）
	Tutorial = {
		IntroTitle = "保护公主",
		IntroSubtitle = "击退来袭的敌人，守住公主的生命值",
		IntroHint = "消灭第 1 波敌人后，将显示后续指引",
		GuideTitle = "新手指引",
		GuideSteps = {
			{
				Title = "① 采集金币",
				Body = "到金币农场。",
			},
			{
				Title = "② 金币升级",
				Body = "前往强化商店提升攻击、等属性。",
			},
			{
				Title = "③ 训练得奖牌",
				Body = "找到训练师（TrainerNPC），选择木桩并击败。",
			},
			{
				Title = "④ 兑换武器",
				Body = "到武器店（WeaponShop）领取更强武器（达标不扣奖牌）。",
			},
		},
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

export type WaveEnemyStats = {
	wave: number,
	maxHealth: number,
	walkSpeed: number,
	princessDamagePerHit: number,
}

function GameConfig.getWaveEnemyStats(waveNumber: number): WaveEnemyStats
	local wave = math.max(1, math.floor(waveNumber))
	local extra = wave - 1

	local maxHealth = GameConfig.EnemyMaxHealth + extra * GameConfig.WaveEnemyHealthPerWave
	local walkSpeed = GameConfig.EnemySpeed + extra * GameConfig.WaveEnemySpeedPerWave
	local princessDamagePerHit = GameConfig.PrincessDamagePerHit + extra * GameConfig.WaveEnemyPrincessDamagePerWave

	if typeof(GameConfig.WaveEnemyMaxHealth) == "number" then
		maxHealth = math.min(maxHealth, GameConfig.WaveEnemyMaxHealth)
	end
	if typeof(GameConfig.WaveEnemyMaxSpeed) == "number" then
		walkSpeed = math.min(walkSpeed, GameConfig.WaveEnemyMaxSpeed)
	end
	if typeof(GameConfig.WaveEnemyMaxPrincessDamagePerHit) == "number" then
		princessDamagePerHit = math.min(princessDamagePerHit, GameConfig.WaveEnemyMaxPrincessDamagePerHit)
	end

	return {
		wave = wave,
		maxHealth = maxHealth,
		walkSpeed = walkSpeed,
		princessDamagePerHit = princessDamagePerHit,
	}
end

return GameConfig
