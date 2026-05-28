-- ============================================================================
-- PlayerUpgrades（强化等级 · 服务端）
-- 等级存在 Player Attribute：ShopLevel_<升级Id>
-- 公主相关：上限叠加到 GameState，治疗为免费动作（仅冷却）
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerEconomy = require(script.Parent.PlayerEconomy)
local WaveDefense = require(script.Parent.WaveDefense)

local PlayerUpgrades = {}

local purchaseRemote: RemoteFunction

local HEAL_ACTION_ID = "PrincessHeal"

local function getAttributeName(upgradeId: string): string
	return "ShopLevel_" .. upgradeId
end

local function getUpgradeConfig(upgradeId: string)
	return GameConfig.ShopUpgrades[upgradeId]
end

function PlayerUpgrades.getLevel(player: Player, upgradeId: string): number
	local level = player:GetAttribute(getAttributeName(upgradeId))
	if typeof(level) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(level))
end

function PlayerUpgrades.getCost(player: Player, upgradeId: string): number?
	local cfg = getUpgradeConfig(upgradeId)
	if not cfg then
		return nil
	end

	local level = PlayerUpgrades.getLevel(player, upgradeId)
	if level >= cfg.MaxLevel then
		return nil
	end

	return math.floor(cfg.BaseCost * (cfg.CostMultiplier ^ level))
end

function PlayerUpgrades.getBonuses(player: Player): {
	damage: number,
	attackRange: number,
	walkSpeed: number,
}
	local bonuses = {
		damage = 0,
		attackRange = 0,
		walkSpeed = 0,
	}

	for upgradeId, cfg in GameConfig.ShopUpgrades do
		local level = PlayerUpgrades.getLevel(player, upgradeId)
		local amount = level * cfg.BonusPerLevel
		if upgradeId == "Damage" then
			bonuses.damage = amount
		elseif upgradeId == "AttackRange" then
			bonuses.attackRange = amount
		elseif upgradeId == "WalkSpeed" then
			bonuses.walkSpeed = amount
		end
	end

	return bonuses
end

function PlayerUpgrades.applyToCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local bonuses = PlayerUpgrades.getBonuses(player)
	humanoid.MaxHealth = GameConfig.DefaultMaxHealth
	humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
	humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed + bonuses.walkSpeed
end

function PlayerUpgrades.setupPlayer(player: Player)
	for upgradeId in GameConfig.ShopUpgrades do
		local attr = getAttributeName(upgradeId)
		if typeof(player:GetAttribute(attr)) ~= "number" then
			player:SetAttribute(attr, 0)
		end
	end

	-- 旧存档：玩家生命上限 → 公主生命上限
	local legacy = player:GetAttribute("ShopLevel_MaxHealth")
	if typeof(legacy) == "number" and legacy > 0 then
		local current = player:GetAttribute("ShopLevel_PrincessMaxHp")
		if typeof(current) ~= "number" or current == 0 then
			player:SetAttribute("ShopLevel_PrincessMaxHp", legacy)
		end
		player:SetAttribute("ShopLevel_MaxHealth", nil)
	end

	local function onCharacterAdded(character: Model)
		PlayerUpgrades.applyToCharacter(player, character)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

function PlayerUpgrades.purchase(player: Player, upgradeId: string): (boolean, string)
	if upgradeId == HEAL_ACTION_ID then
		return WaveDefense.healPrincess(player)
	end

	local cfg = getUpgradeConfig(upgradeId)
	if not cfg then
		return false, "未知升级"
	end

	local level = PlayerUpgrades.getLevel(player, upgradeId)
	if level >= cfg.MaxLevel then
		return false, "已满级"
	end

	local cost = PlayerUpgrades.getCost(player, upgradeId)
	if not cost then
		return false, "无法购买"
	end

	if not PlayerEconomy.trySpendGold(player, cost) then
		return false, "金币不足"
	end

	player:SetAttribute(getAttributeName(upgradeId), level + 1)

	if upgradeId == "PrincessMaxHp" then
		WaveDefense.addPrincessMaxHp(cfg.BonusPerLevel)
	elseif upgradeId == "WalkSpeed" and player.Character then
		PlayerUpgrades.applyToCharacter(player, player.Character)
	end

	return true, ("已升至 Lv.%d"):format(level + 1)
end

local function onPurchase(player: Player, upgradeId: string): (boolean, string)
	if typeof(upgradeId) ~= "string" then
		return false, "无效请求"
	end
	return PlayerUpgrades.purchase(player, upgradeId)
end

function PlayerUpgrades.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	purchaseRemote = remotes:FindFirstChild("ShopPurchase") :: RemoteFunction?
	if not purchaseRemote then
		purchaseRemote = Instance.new("RemoteFunction")
		purchaseRemote.Name = "ShopPurchase"
		purchaseRemote.Parent = remotes
	end

	purchaseRemote.OnServerInvoke = onPurchase

	for _, player in Players:GetPlayers() do
		PlayerUpgrades.setupPlayer(player)
	end
	Players.PlayerAdded:Connect(function(player)
		PlayerUpgrades.setupPlayer(player)
		WaveDefense.recalculatePrincessMaxHp()
	end)
	Players.PlayerRemoving:Connect(function()
		WaveDefense.recalculatePrincessMaxHp()
	end)
end

return PlayerUpgrades
