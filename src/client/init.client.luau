-- ============================================================================
-- Client 入口（StarterPlayerScripts.Client）
-- 每个玩家本地执行：UI、输入、特效等「表现层」
-- require 规则同 Server：script.Hud 而不是 script.Parent.Hud
-- ============================================================================

local Hud = require(script.Hud)

print("[roblox-starter] Client started")

Hud.create()
