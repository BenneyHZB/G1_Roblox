-- ============================================================================
-- CityDefense（服务端游戏模式）
-- 职责：读取场景关卡物体 → 刷怪 → 扣城堡 HP → 判定胜负
-- 关卡物体：Workspace.Map（城堡 City、刷怪点 EnemySpawn）
-- 敌人模板：ReplicatedStorage.EnemyTemplate（Toolbox 拖入后改名，代码 Clone 生成）
-- 移动方式：优先 Humanoid:MoveTo（走路 + 动画）；无 Humanoid 时退回平移 Part
-- ============================================================================

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local MAP_FOLDER_NAME = "Map"
local CITY_NAME = "City"
local SPAWN_NAME = "EnemySpawn"
local ENEMY_TEMPLATE_NAME = "EnemyTemplate"

-- 没有 Animate 脚本时，用 Roblox 默认走路动画
local DEFAULT_WALK_ANIM = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://507777826",
	[Enum.HumanoidRigType.R6] = "rbxassetid://180426354",
}

local CityDefense = {}

local cityTarget: Model | BasePart
local enemyTemplate: Model | BasePart
local spawnPoints: { BasePart } = {}
local cityHpValue: IntValue

local function getPosition(target: Model | BasePart): Vector3
	if target:IsA("Model") then
		return target:GetPivot().Position
	end
	return target.Position
end

local function moveTo(target: Model | BasePart, position: Vector3)
	if target:IsA("Model") then
		target:PivotTo(CFrame.new(position))
	else
		target.Position = position
	end
end

local function sanitizeEnemyModel(enemy: Model)
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("Script") then
			desc.Disabled = true
		elseif desc:IsA("LocalScript") and desc.Name ~= "Animate" then
			desc.Disabled = true
		elseif desc:IsA("Tool") then
			warn("[CityDefense] 模板内含 Tool，可能导致被玩家拾取，请换 NPC Model")
		elseif desc:IsA("BasePart") then
			desc.CanTouch = false
		end
	end
end

local function hasAnimateScript(enemy: Model): boolean
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("LocalScript") and desc.Name == "Animate" then
			return true
		end
	end
	return false
end

local function playWalkAnimation(enemy: Model)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animObject: Animation? = nil
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("Animation") and (desc.Name:lower():find("walk") or desc.Name == "WalkAnim") then
			animObject = desc
			break
		end
	end

	if not animObject then
		animObject = Instance.new("Animation")
		animObject.AnimationId = DEFAULT_WALK_ANIM[humanoid.RigType] or DEFAULT_WALK_ANIM[Enum.HumanoidRigType.R15]
	end

	local track = animator:LoadAnimation(animObject)
	track.Looped = true
	track:Play()
end

local function setupHumanoidEnemy(enemy: Model, spawnPosition: Vector3)

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local root = enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and not enemy.PrimaryPart then
		enemy.PrimaryPart = root
	end

	enemy:PivotTo(CFrame.new(spawnPosition + Vector3.new(0, 3, 0)))

	for _, desc in enemy:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
		end
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = GameConfig.EnemySpeed

	if not hasAnimateScript(enemy) then
		playWalkAnimation(enemy)
	end

	return true
end

local function prepareSlideEnemy(enemy: Model)
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
	end
end

local function ensureGameState(): IntValue
	local folder = ReplicatedStorage:FindFirstChild("GameState")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GameState"
		folder.Parent = ReplicatedStorage
	end

	local cityHp = folder:FindFirstChild("CityHp")
	if not cityHp then
		cityHp = Instance.new("IntValue")
		cityHp.Name = "CityHp"
		cityHp.Parent = folder
	end

	return cityHp :: IntValue
end

local function findMapObjects()
	local mapFolder = workspace:WaitForChild(MAP_FOLDER_NAME)

	local city = mapFolder:WaitForChild(CITY_NAME)
	if not city:IsA("Model") and not city:IsA("BasePart") then
		error(("[CityDefense] %s 必须是 Model 或 Part"):format(CITY_NAME))
	end
	cityTarget = city

	spawnPoints = {}
	for _, child in mapFolder:GetChildren() do
		if child:IsA("BasePart") and child.Name == SPAWN_NAME then
			table.insert(spawnPoints, child)
		end
	end

	if #spawnPoints == 0 then
		error(("[CityDefense] 在 Workspace.%s 里找不到名为 %s 的 Part"):format(MAP_FOLDER_NAME, SPAWN_NAME))
	end

	local template = ReplicatedStorage:WaitForChild(ENEMY_TEMPLATE_NAME, 5)
	if not template then
		error(("[CityDefense] 请在 ReplicatedStorage 里放入名为 %s 的敌人 Model"):format(ENEMY_TEMPLATE_NAME))
	end
	if template:IsA("Tool") then
		warn("[CityDefense] EnemyTemplate 是 Tool 类型，玩家碰到会自动捡到手，请换 NPC Model")
	elseif not template:IsA("Model") and not template:IsA("BasePart") then
		error(("[CityDefense] %s 必须是 Model 或 Part"):format(ENEMY_TEMPLATE_NAME))
	end
	enemyTemplate = template
end

local function onEnemyReachCity(enemy: Instance)
	cityHpValue.Value = math.max(0, cityHpValue.Value - GameConfig.CityDamagePerHit)
	print("[CityDefense] 敌人抵达城堡！剩余 HP =", cityHpValue.Value)
	enemy:Destroy()

	if cityHpValue.Value <= 0 then
		print("[CityDefense] 城堡被攻破，游戏结束")
	end
end

local function runHumanoidMovement(enemy: Model)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid") :: Humanoid

	local function moveTowardCity()
		if enemy.Parent and cityHpValue.Value > 0 then
			humanoid:MoveTo(getPosition(cityTarget))
		end
	end

	moveTowardCity()

	local moveLoop: thread
	moveLoop = task.spawn(function()
		while enemy.Parent and cityHpValue.Value > 0 do
			moveTowardCity()
			task.wait(1)
		end
	end)

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if not enemy.Parent then
			connection:Disconnect()
			task.cancel(moveLoop)
			return
		end

		local distance = (getPosition(cityTarget) - getPosition(enemy)).Magnitude
		if distance <= GameConfig.EnemyReachDistance then
			connection:Disconnect()
			task.cancel(moveLoop)
			onEnemyReachCity(enemy)
		end
	end)
end

local function runSlideMovement(enemy: Model | BasePart)
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not enemy.Parent then
			connection:Disconnect()
			return
		end

		local cityPos = getPosition(cityTarget)
		local enemyPos = getPosition(enemy)
		local toCity = cityPos - enemyPos
		local distance = toCity.Magnitude

		if distance <= GameConfig.EnemyReachDistance then
			connection:Disconnect()
			onEnemyReachCity(enemy)
			return
		end

		moveTo(enemy, enemyPos + toCity.Unit * GameConfig.EnemySpeed * dt)
	end)
end

local function createEnemyAt(position: Vector3): (Model | BasePart, boolean)
	local enemy = enemyTemplate:Clone()
	enemy.Name = "Enemy"
	enemy.Parent = workspace

	local usesHumanoid = false
	if enemy:IsA("Model") then
		sanitizeEnemyModel(enemy)
		usesHumanoid = setupHumanoidEnemy(enemy, position)
		if not usesHumanoid then
			prepareSlideEnemy(enemy)
			moveTo(enemy, position)
		end
	else
		moveTo(enemy, position)
	end

	return enemy, usesHumanoid
end

function CityDefense.setupWorld()
	cityHpValue = ensureGameState()
	cityHpValue.Value = GameConfig.CityMaxHp

	findMapObjects()

	print("[CityDefense] 已绑定场景物体：城堡 +", #spawnPoints, "个刷怪点 + 敌人模板", enemyTemplate.Name)
end

function CityDefense.spawnEnemy()
	if cityHpValue.Value <= 0 then
		return
	end

	local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
	local enemy, usesHumanoid = createEnemyAt(spawnPoint.Position)

	if usesHumanoid and enemy:IsA("Model") then
		runHumanoidMovement(enemy)
	else
		runSlideMovement(enemy)
	end

	print("[CityDefense] 生成敌人 @", spawnPoint.Position, usesHumanoid and "（Humanoid 走路）" or "（平移）")
end

function CityDefense.start()
	CityDefense.setupWorld()

	task.spawn(function()
		while cityHpValue.Value > 0 do
			local ok, err = pcall(CityDefense.spawnEnemy)
			if not ok then
				warn("[CityDefense] 刷怪失败：", err)
				break
			end
			task.wait(GameConfig.EnemySpawnInterval)
		end
	end)
end

return CityDefense
