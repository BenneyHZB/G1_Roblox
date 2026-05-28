-- ============================================================================
-- PlayerReset（重开时清零本局进度，保留奖杯）
-- 勿在模块顶层 require PlayerUpgrades / WaveDefense（会循环引用导致整服脚本不启动）
-- ============================================================================

local Players = game:GetService("Players")

local PlayerEconomy = require(script.Parent.PlayerEconomy)
local TrainingGround = require(script.Parent.TrainingGround)
local Tutorial = require(script.Parent.Tutorial)

local PlayerReset = {}

local function getPlayerUpgrades()
	return require(script.Parent.PlayerUpgrades)
end

local function getWeaponShop()
	return require(script.Parent.WeaponShop)
end

function PlayerReset.resetPlayer(player: Player)
	PlayerEconomy.resetPlayer(player)
	getPlayerUpgrades().resetPlayer(player)
	getWeaponShop().resetPlayer(player)
	TrainingGround.resetPlayer(player)
	Tutorial.resetPlayer(player)
end

function PlayerReset.resetAllPlayers()
	for _, player in Players:GetPlayers() do
		PlayerReset.resetPlayer(player)
	end
end

return PlayerReset
