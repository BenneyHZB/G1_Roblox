-- ============================================================================
-- Server 入口（ServerScriptService.Server）
-- Rojo 会把同目录下的 init.server.luau 变成 Script，其它 .luau 变成它的子 Module
-- 所以 require 用 script.Xxx，不是 script.Parent.Xxx
-- ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CityDefense = require(script.CityDefense)

print("[roblox-starter] Server started")

CityDefense.start()

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
print("[roblox-starter] 守城演示已启动：每", GameConfig.EnemySpawnInterval, "秒刷怪")
