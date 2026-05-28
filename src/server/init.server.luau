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
local PlayerCombat = require(script.PlayerCombat)
local WaveDefense = require(script.WaveDefense)

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

print("[roblox-starter] Server started")

PlayerEconomy.start()
PlayerCombat.start()
WaveDefense.start()

print(
	"[roblox-starter] 波次守公主已启动：波间",
	GameConfig.WaveIntermission,
	"秒，击杀 +",
	GameConfig.GoldPerWaveEnemyKill,
	"金币"
)
