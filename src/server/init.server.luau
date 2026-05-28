-- ============================================================================
-- Server 入口
--
-- 【启动顺序】
--   PlayerEconomy.start()  → 玩家金币 leaderstats
--   PlayerCombat.start()   → 左键攻击 RemoteEvent（Combat.client 触发）
--   WaveDefense.start()    → 波次刷怪主循环
-- ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerEconomy = require(script.PlayerEconomy)
local PlayerTrophies = require(script.PlayerTrophies)
local PlayerUpgrades = require(script.PlayerUpgrades)
local PlayerCombat = require(script.PlayerCombat)
local EnhanceShop = require(script.EnhanceShop)
local TrainingGround = require(script.TrainingGround)
local WaveDefense = require(script.WaveDefense)

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

print("[roblox-starter] Server started")

PlayerEconomy.start()
PlayerTrophies.start()
PlayerUpgrades.start()
TrainingGround.start()
PlayerCombat.start()
EnhanceShop.start()
WaveDefense.start()

print(
	("[roblox-starter] 波次守公主已启动：首波 %d 秒，波间 %d→%d 秒，击杀 +%d 金币"):format(
		GameConfig.FirstWaveDelay,
		GameConfig.WaveIntermissionStart,
		GameConfig.WaveIntermissionEnd,
		GameConfig.GoldPerWaveEnemyKill
	)
)
