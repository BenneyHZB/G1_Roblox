-- ============================================================================
-- PlayerCombat（玩家攻击 · 服务端）
--
-- 动画：Tool 自带 LocalScript，本模块不管
-- 伤害：GameConfig.WeaponStats[Tool.Name] 或 Tool Attribute，不用武器脚本里的伤害
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerEconomy = require(script.Parent.PlayerEconomy)
local PlayerUpgrades = require(script.Parent.PlayerUpgrades)
local TrainingGround = require(script.Parent.TrainingGround)

local PlayerCombat = {}

local attackRemote: RemoteEvent
local lastAttackAt: { [Player]: number } = {}

local TOOL_DAMAGE_VALUE_NAMES = {
	SlashDamage = true,
	LungeDamage = true,
	BaseDamage = true,
	Damage = true,
}

local function getEnemyPosition(enemy: Instance): Vector3?
	if enemy:IsA("Model") then
		if enemy.PrimaryPart then
			return enemy.PrimaryPart.Position
		end
		local part = enemy:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	elseif enemy:IsA("BasePart") then
		return enemy.Position
	end
	return nil
end

local function getEnemyRoot(enemy: Instance): BasePart?
	if enemy:IsA("Model") then
		local root = enemy:FindFirstChild("HumanoidRootPart", true)
		if root and root:IsA("BasePart") then
			return root
		end
		if enemy.PrimaryPart then
			return enemy.PrimaryPart
		end
		local part = enemy:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part
		end
	elseif enemy:IsA("BasePart") then
		return enemy
	end
	return nil
end

local function applyHitFeedback(enemy: Instance, attackerRoot: BasePart)
	if enemy:GetAttribute("IsTrainingDummy") then
		return
	end

	local root = getEnemyRoot(enemy)
	if not root then
		return
	end

	local away = root.Position - attackerRoot.Position
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.05 then
		away = -attackerRoot.CFrame.LookVector
		away = Vector3.new(away.X, 0, away.Z)
	end
	if away.Magnitude < 0.05 then
		return
	end
	away = away.Unit

	local knockback = GameConfig.EnemyHitKnockbackDistance
	local targetPos = root.Position + away * knockback

	if enemy:IsA("Model") then
		local current = enemy:GetPivot()
		enemy:PivotTo(CFrame.new(targetPos) * (current - current.Position))
	else
		root.CFrame = CFrame.new(targetPos) * (root.CFrame - root.CFrame.Position)
	end

	enemy:SetAttribute("HitStunUntil", os.clock() + GameConfig.EnemyHitKnockbackDuration)

	local originalColor = root.Color
	root.Color = Color3.fromRGB(255, 120, 120)
	task.delay(0.12, function()
		if root.Parent then
			root.Color = originalColor
		end
	end)
end

local function getEquippedTool(character: Model): Tool?
	return character:FindFirstChildOfClass("Tool")
end

local function neutralizeToolDamage(tool: Tool)
	for _, desc in tool:GetDescendants() do
		if (desc:IsA("NumberValue") or desc:IsA("IntValue")) and TOOL_DAMAGE_VALUE_NAMES[desc.Name] then
			desc.Value = 0
		end
	end
end

local function bindCombatTool(tool: Tool)
	neutralizeToolDamage(tool)
	tool.DescendantAdded:Connect(function(desc)
		if (desc:IsA("NumberValue") or desc:IsA("IntValue")) and TOOL_DAMAGE_VALUE_NAMES[desc.Name] then
			desc.Value = 0
		end
	end)
end

local function watchPlayerTools(player: Player)
	local function watchContainer(container: Instance)
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				bindCombatTool(child)
			end
		end

		container.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				bindCombatTool(child)
			end
		end)
	end

	local function onCharacterAdded(character: Model)
		watchContainer(character)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	local backpack = player:WaitForChild("Backpack")
	watchContainer(backpack)
end

local function getPlayerAttackStats(player: Player, character: Model): (number, number, number)
	local tool = getEquippedTool(character)
	if not tool then
		return GameConfig.AttackDamage, GameConfig.AttackRange, GameConfig.AttackCooldown
	end

	local weaponStats = GameConfig.WeaponStats[tool.Name]

	local damage = tool:GetAttribute("Damage")
	if typeof(damage) ~= "number" then
		damage = weaponStats and weaponStats.Damage or GameConfig.ToolAttackDamage
	end

	local range = tool:GetAttribute("AttackRange")
	if typeof(range) ~= "number" then
		range = weaponStats and weaponStats.Range or GameConfig.ToolAttackRange
	end

	local cooldown = tool:GetAttribute("AttackCooldown")
	if typeof(cooldown) ~= "number" then
		cooldown = weaponStats and weaponStats.Cooldown or GameConfig.ToolAttackCooldown
	end

	local bonuses = PlayerUpgrades.getBonuses(player)
	damage += bonuses.damage
	range += bonuses.attackRange

	return damage, range, cooldown
end

local function findNearestTrainingDummy(player: Player, origin: Vector3, maxRange: number): Instance?
	local nearest: Instance? = nil
	local nearestDistance = maxRange

	for _, inst in workspace:GetDescendants() do
		if inst:GetAttribute("IsTrainingDummy") and inst:GetAttribute("OwnerUserId") == player.UserId then
			local pos = getEnemyPosition(inst)
			if pos then
				local distance = (pos - origin).Magnitude
				if distance <= nearestDistance then
					nearestDistance = distance
					nearest = inst
				end
			end
		end
	end

	return nearest
end

local function findNearestWaveEnemy(origin: Vector3, maxRange: number): Instance?
	local nearest: Instance? = nil
	local nearestDistance = maxRange

	for _, inst in workspace:GetDescendants() do
		if inst:GetAttribute("IsWaveEnemy") then
			local pos = getEnemyPosition(inst)
			if pos then
				local distance = (pos - origin).Magnitude
				if distance <= nearestDistance then
					nearestDistance = distance
					nearest = inst
				end
			end
		end
	end

	return nearest
end

local function findAttackTarget(player: Player, origin: Vector3, maxRange: number): Instance?
	local dummy = findNearestTrainingDummy(player, origin, maxRange)
	if dummy then
		return dummy
	end
	return findNearestWaveEnemy(origin, maxRange)
end

local function awardKill(player: Player, enemy: Instance)
	if enemy:GetAttribute("KillRewarded") then
		return
	end
	enemy:SetAttribute("KillRewarded", true)

	if enemy:GetAttribute("IsTrainingDummy") then
		if enemy:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		local level = enemy:GetAttribute("DummyLevel")
		local trophies = enemy:GetAttribute("TrophyReward")
		if typeof(level) == "number" and typeof(trophies) == "number" then
			TrainingGround.recordVictory(player, level, trophies)
		end
		return
	end

	PlayerEconomy.addGold(player, GameConfig.GoldPerWaveEnemyKill)
end

local function damageEnemy(player: Player, enemy: Instance, damage: number, attackerRoot: BasePart)
	enemy:SetAttribute("LastAttackerUserId", player.UserId)

	if enemy:IsA("Model") then
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			applyHitFeedback(enemy, attackerRoot)
			humanoid:TakeDamage(damage)
			if humanoid.Health <= 0 then
				awardKill(player, enemy)
				enemy:Destroy()
			end
			return
		end
	end

	applyHitFeedback(enemy, attackerRoot)

	local health = enemy:GetAttribute("Health")
	if typeof(health) ~= "number" then
		health = GameConfig.EnemyMaxHealth
	end

	health -= damage
	enemy:SetAttribute("Health", health)

	if health <= 0 then
		awardKill(player, enemy)
		enemy:Destroy()
	end
end

local function onAttack(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local damage, range, cooldown = getPlayerAttackStats(player, character)

	local now = os.clock()
	local last = lastAttackAt[player] or 0
	if now - last < cooldown then
		return
	end
	lastAttackAt[player] = now

	local enemy = findAttackTarget(player, root.Position, range)
	if enemy then
		damageEnemy(player, enemy, damage, root)
	end
end

function PlayerCombat.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	attackRemote = remotes:FindFirstChild("Attack") :: RemoteEvent?
	if not attackRemote then
		attackRemote = Instance.new("RemoteEvent")
		attackRemote.Name = "Attack"
		attackRemote.Parent = remotes
	end

	attackRemote.OnServerEvent:Connect(onAttack)

	for _, player in Players:GetPlayers() do
		watchPlayerTools(player)
	end
	Players.PlayerAdded:Connect(watchPlayerTools)
	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player] = nil
	end)
end

return PlayerCombat
