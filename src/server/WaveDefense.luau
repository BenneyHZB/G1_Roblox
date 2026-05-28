-- ============================================================================
-- WaveDefense（波次守公主 · 服务端）
--
-- 【谁调用我】
--   init.server.luau → WaveDefense.start()
--
-- 【主流程】
--   start()
--     └─ setupWorld()          绑定公主 / 刷怪点 / 敌人模板 / GameState
--     └─ 波次循环 (task.spawn)
--          └─ runIntermission()   波间倒计时
--          └─ runWave(n)          刷第 n 波
--               └─ spawnWaveEnemy()   刷 1 只怪（循环多次）
--                    └─ createEnemyAt(spawnCFrame)   在刷怪点克隆敌人
--                    └─ runHumanoidMovement / runSlideMovement   朝公主移动
--                         └─ runPrincessAttack()   连续攻击公主（动画 + 扣 HP）
--
-- 【场景要求】Workspace.Map 下 Part，Name = "EnemySpawn"（不要放在 Princess 模型内部）
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- 场景物体名称（与 assets/map 里 Rojo 同步的名字一致）
local MAP_FOLDER_NAME = "Map"
local PRINCESS_NAME = "Princess"
local SPAWN_NAME = "EnemySpawn"
local ENEMY_TEMPLATE_NAME = "EnemyTemplate"
local WAVE_ENEMIES_FOLDER_NAME = "WaveEnemies"

local DEFAULT_WALK_ANIM = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://507777826",
	[Enum.HumanoidRigType.R6] = "rbxassetid://180426354",
}

local DEFAULT_ATTACK_ANIM = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://522635514",
	[Enum.HumanoidRigType.R6] = "rbxassetid://522635514",
}

local WaveDefense = {}

-- 防止 Rojo 热更或重复 Play 导致多套波次循环同时跑
local isRunning = false

-- 运行时缓存（setupWorld → findMapObjects 填充）
local princessTarget: Model | BasePart
local enemyTemplate: Model | BasePart
local waveEnemiesFolder: Folder
local spawnPoints: { BasePart } = {}
local princessHpValue: IntValue
local princessMaxHpValue: IntValue
local waveNumberValue: IntValue
local wavePhaseValue: StringValue
local waveCountdownValue: IntValue

local activeWaveEnemies = 0
local princessHitSoundTemplate: Sound?

-- ---------------------------------------------------------------------------
-- 工具函数
-- ---------------------------------------------------------------------------

local function getPosition(target: Model | BasePart): Vector3
	if target:IsA("Model") then
		if target.PrimaryPart then
			return target.PrimaryPart.Position
		end
		return target:GetPivot().Position
	end
	return target.Position
end

-- 公主作为移动目标：用包围盒中心，避免 Pivot 不在模型中间导致怪往错误方向走
-- 调用方：runHumanoidMovement / runSlideMovement
local function getPrincessPosition(): Vector3
	if princessTarget:IsA("Model") then
		local cf, _size = princessTarget:GetBoundingBox()
		return cf.Position
	end
	return princessTarget.Position
end

-- 只在水平面（XZ）朝公主移动，保持敌人当前高度
local function getMoveTargetPosition(enemyPos: Vector3): Vector3
	local princessPos = getPrincessPosition()
	return Vector3.new(princessPos.X, enemyPos.Y, princessPos.Z)
end

local function moveTo(target: Model | BasePart, position: Vector3)
	if target:IsA("Model") then
		target:PivotTo(CFrame.new(position))
	else
		target.CFrame = CFrame.new(position)
	end
end

-- 刷怪点 Part 顶面中心 + 抬高，避免敌人生进地里
-- 调用方：spawnWaveEnemy → createEnemyAt
local function getSpawnCFrame(spawnPoint: BasePart): CFrame
	local lift = spawnPoint.Size.Y / 2 + 2
	return spawnPoint.CFrame * CFrame.new(0, lift, 0)
end

local function setModelPrimaryPart(enemy: Model)
	if enemy.PrimaryPart then
		return
	end

	local root = enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
		or enemy:FindFirstChildWhichIsA("BasePart", true)

	if root then
		enemy.PrimaryPart = root
	end
end

-- 设置 Model 内所有 Part 的 Anchored
local function setModelPartsAnchored(enemy: Model, anchored: boolean)
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = anchored
		end
	end
end

-- 把敌人整体搬到刷怪点
-- 调用方：createEnemyAt
--
-- 【重要】Toolbox 导入的 NPC 常有个别 Part 仍是 Anchored=true。
-- 若直接 PivotTo，锚固 Part 不会跟着走，看起来就像「身体一部分留在别处」。
-- 做法：先全部 Anchored=true → PivotTo 整体移动 → Humanoid 模式再统一解除锚固。
local function placeEnemyAt(enemy: Instance, spawnCFrame: CFrame)
	if enemy:IsA("Model") then
		setModelPrimaryPart(enemy)
		setModelPartsAnchored(enemy, true)

		if enemy.PrimaryPart then
			enemy:PivotTo(spawnCFrame)
		else
			local part = enemy:FindFirstChildWhichIsA("BasePart", true)
			if part then
				part.CFrame = spawnCFrame
			else
				warn("[WaveDefense] 敌人 Model 没有 Part，无法定位到刷怪点")
			end
		end
	elseif enemy:IsA("BasePart") then
		enemy.Anchored = true
		enemy.CFrame = spawnCFrame
	end
end

-- 清掉 Toolbox 怪物自带的 Script（必须在 Parent 到 workspace 之前执行，否则会额外刷怪）
-- 调用方：createEnemyAt（Parent 之前）
local function sanitizeEnemyModel(enemy: Model)
	local toRemove: { Instance } = {}

	for _, desc in enemy:GetDescendants() do
		if desc:IsA("Script") then
			table.insert(toRemove, desc)
		elseif desc:IsA("LocalScript") and desc.Name ~= "Animate" then
			table.insert(toRemove, desc)
		elseif desc:IsA("ModuleScript") then
			-- NPC 模板里偶发携带 ModuleScript，也可能间接刷怪
			table.insert(toRemove, desc)
		elseif desc:IsA("Tool") then
			desc.CanBeDropped = false
			warn("[WaveDefense] 模板内含 Tool，可能导致被玩家拾取，请换 NPC Model")
		elseif desc:IsA("BasePart") then
			desc.CanTouch = false
		end
	end

	for _, inst in toRemove do
		inst:Destroy()
	end
end

-- 调用方：setupWorld
local function ensureWaveEnemiesFolder(): Folder
	local folder = workspace:FindFirstChild(WAVE_ENEMIES_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = WAVE_ENEMIES_FOLDER_NAME
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- 调用方：setupWorld（新一局开始时清场）
local function clearStrayEnemies()
	for _, child in workspace:GetChildren() do
		if child.Name == "WaveEnemy" or child:GetAttribute("IsWaveEnemy") then
			child:Destroy()
		end
	end

	if waveEnemiesFolder then
		waveEnemiesFolder:ClearAllChildren()
	end
end

-- 公主模型内部的 EnemySpawn 不算刷怪点（常是误放进 Princess.rbxm 的标记）
local function isValidSpawnPoint(part: BasePart): boolean
	if part:IsDescendantOf(princessTarget) then
		return false
	end
	return true
end

-- 调用方：createEnemyAt
local function ensureEnemyHealth(enemy: Instance)
	if enemy:IsA("Model") then
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = GameConfig.EnemyMaxHealth
			humanoid.Health = GameConfig.EnemyMaxHealth
		else
			enemy:SetAttribute("Health", GameConfig.EnemyMaxHealth)
		end
	else
		enemy:SetAttribute("Health", GameConfig.EnemyMaxHealth)
	end
end

-- 在 Model 内查找 Humanoid（含嵌套子 Model）
local function findHumanoid(enemy: Model): Humanoid?
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid
	end
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("Humanoid") then
			return desc
		end
	end
	return nil
end

-- R15 用 HumanoidRootPart，R6 用 Torso（含嵌套）
local function getHumanoidRoot(enemy: Model): BasePart?
	local direct = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Torso")
	if direct and direct:IsA("BasePart") then
		return direct
	end
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("BasePart") and (desc.Name == "HumanoidRootPart" or desc.Name == "Torso") then
			return desc
		end
	end
	return nil
end

-- 模板自带 Humanoid + 身体 Root Part 才走路
local function canUseHumanoidMovement(enemy: Model): boolean
	return findHumanoid(enemy) ~= nil and getHumanoidRoot(enemy) ~= nil
end

-- 服务端波次 NPC 走路动画（Animate 是 LocalScript，在服务端不执行，必须手动播）
local walkTracks: { [Model]: AnimationTrack } = {}
local attackTracks: { [Model]: AnimationTrack } = {}

local function getAnimator(humanoid: Humanoid): Animator
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function findAttackAnimation(enemy: Model, humanoid: Humanoid): Animation
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("Animation") then
			local name = desc.Name:lower()
			if name:find("attack") or name:find("slash") or name:find("punch") or name:find("hit") then
				return desc
			end
		end
	end

	local animObject = Instance.new("Animation")
	animObject.Name = "WaveAttackAnim"
	animObject.AnimationId = DEFAULT_ATTACK_ANIM[humanoid.RigType] or DEFAULT_ATTACK_ANIM[Enum.HumanoidRigType.R15]
	animObject.Parent = humanoid
	return animObject
end

local function stopWalkAnimation(enemy: Model)
	local track = walkTracks[enemy]
	if track and track.IsPlaying then
		track:Stop()
	end
end

local function playAttackAnimation(enemy: Model, humanoid: Humanoid): AnimationTrack
	stopWalkAnimation(enemy)

	local animator = getAnimator(humanoid)
	local animObject = findAttackAnimation(enemy, humanoid)

	local track = animator:LoadAnimation(animObject)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play()
	attackTracks[enemy] = track
	return track
end

local function bindWalkAnimation(enemy: Model)
	local humanoid = findHumanoid(enemy)
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
		animObject.Name = "WaveWalkAnim"
		animObject.AnimationId = DEFAULT_WALK_ANIM[humanoid.RigType] or DEFAULT_WALK_ANIM[Enum.HumanoidRigType.R15]
		animObject.Parent = humanoid
	end

	local track = animator:LoadAnimation(animObject)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	walkTracks[enemy] = track

	humanoid.Running:Connect(function(speed)
		if speed > 0.1 then
			if not track.IsPlaying then
				track:Play()
			end
		elseif track.IsPlaying then
			track:Stop()
		end
	end)

	enemy.Destroying:Connect(function()
		walkTracks[enemy] = nil
		attackTracks[enemy] = nil
	end)
end

-- 模板诊断（仅启动时打印一次）
local templateHasToolInside = false

local function validateEnemyTemplate(template: Instance)
	if template:IsA("Tool") then
		error(
			"[WaveDefense] EnemyTemplate 是 Tool（武器/道具），不能走路。"
				.. " 请从 Toolbox 选带人形身体的 NPC Model，Save to File 覆盖 EnemyTemplate.rbxm"
		)
	end

	if not template:IsA("Model") and not template:IsA("BasePart") then
		error(("[WaveDefense] %s 必须是 Model 或 Part"):format(ENEMY_TEMPLATE_NAME))
	end

	if template:IsA("Model") then
		templateHasToolInside = false
		for _, desc in template:GetDescendants() do
			if desc:IsA("Tool") then
				templateHasToolInside = true
				break
			end
		end

		local humanoid = findHumanoid(template)
		local root = getHumanoidRoot(template)

		print("[WaveDefense] 敌人模板诊断:")
		print("  类型:", template.ClassName)
		print("  Humanoid:", humanoid ~= nil, humanoid and humanoid.RigType or "")
		print("  Root Part:", root and root.Name or "无")
		print("  内含 Tool:", templateHasToolInside)

		if templateHasToolInside then
			warn("[WaveDefense] 模板内含 Tool，可能导致被玩家拾取，请换 NPC Model")
		end

		if not canUseHumanoidMovement(template) then
			warn(
				"[WaveDefense] 当前模板无法走路，将使用平移。"
					.. " 请重新导出：Toolbox 搜 NPC/Zombie/R15 Character → 选 Model（不是 Tool）→ 存为 EnemyTemplate.rbxm"
			)
		else
			print("[WaveDefense] 移动模式: Humanoid 走路")
		end
	end
end
-- Humanoid 走路模式（调用前需已 Parent 且 placeEnemyAt 已完成）
-- 调用方：createEnemyAt
local function setupHumanoidEnemy(enemy: Model): boolean
	if not canUseHumanoidMovement(enemy) then
		return false
	end

	local humanoid = findHumanoid(enemy) :: Humanoid
	local root = getHumanoidRoot(enemy) :: BasePart
	enemy.PrimaryPart = root

	-- 解除锚固让 Humanoid 能走（不碰 Tool 内部焊接，保留 Studio 导出状态）
	setModelPartsAnchored(enemy, false)

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = GameConfig.EnemySpeed

	-- 服务端 NPC 由服务器模拟，避免 MoveTo 不生效
	root:SetNetworkOwner(nil)

	-- 服务端必须手动播走路；有 Animate 也不跳过（LocalScript 在服务端不跑）
	bindWalkAnimation(enemy)

	return true
end

-- 平移模式：锚固 Part，代码每帧 PivotTo 向公主滑过去
-- 调用方：createEnemyAt / runHumanoidMovement（卡住时 fallback）
local function prepareSlideEnemy(enemy: Instance)
	if enemy:IsA("BasePart") then
		enemy.Anchored = true
		return
	end

	if enemy:IsA("Model") then
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
end

-- ---------------------------------------------------------------------------
-- 场景绑定 & GameState
-- ---------------------------------------------------------------------------

-- 调用方：setupWorld
local function ensureGameState()
	local folder = ReplicatedStorage:FindFirstChild("GameState")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GameState"
		folder.Parent = ReplicatedStorage
	end

	local function ensureInt(name: string, default: number): IntValue
		local value = folder:FindFirstChild(name)
		if not value then
			value = Instance.new("IntValue")
			value.Name = name
			value.Value = default
			value.Parent = folder
		end
		return value :: IntValue
	end

	local function ensureString(name: string, default: string): StringValue
		local value = folder:FindFirstChild(name)
		if not value then
			value = Instance.new("StringValue")
			value.Name = name
			value.Value = default
			value.Parent = folder
		end
		return value :: StringValue
	end

	princessMaxHpValue = ensureInt("PrincessMaxHp", GameConfig.PrincessMaxHp)
	princessHpValue = ensureInt("PrincessHp", GameConfig.PrincessMaxHp)
	waveNumberValue = ensureInt("WaveNumber", 0)
	waveCountdownValue = ensureInt("WaveCountdown", 0)
	wavePhaseValue = ensureString("WavePhase", "Intermission")
end

-- 关掉公主模型自带血条/脚本（血量走 GameState.PrincessHp + 客户端 Hud）
local function disablePrincessBuiltInUi(princess: Model | BasePart)
	if not princess:IsA("Model") then
		return
	end

	local humanoid = princess:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	for _, desc in princess:GetDescendants() do
		if desc:IsA("Script") or desc:IsA("LocalScript") then
			desc.Disabled = true
		elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
			local nameLower = desc.Name:lower()
			if nameLower:find("health") or nameLower:find("hp") or nameLower:find("bar") then
				desc.Enabled = false
			end
		end
	end
end

local function getPrincessSoundParent(): Instance
	if princessTarget:IsA("Model") then
		local part = princessTarget.PrimaryPart
			or princessTarget:FindFirstChild("HumanoidRootPart", true)
			or princessTarget:FindFirstChildWhichIsA("BasePart", true)
		return part or princessTarget
	end
	return princessTarget
end

local function setupPrincessHitSound()
	local soundName = GameConfig.PrincessHitSoundName or "PrincessHit"

	local existing = princessTarget:FindFirstChild(soundName, true)
	if existing and existing:IsA("Sound") then
		princessHitSoundTemplate = existing
		existing.Looped = false
		existing.Playing = false
		print("[WaveDefense] 公主受击音效:", existing:GetFullName())
		return
	end

	local soundId = GameConfig.PrincessHitSoundId
	if typeof(soundId) ~= "string" or soundId == "" then
		warn(
			("[WaveDefense] 未找到公主受击 Sound「%s」，请在公主模型里插入 Sound，或设置 GameConfig.PrincessHitSoundId"):format(
				soundName
			)
		)
		return
	end

	local parent = getPrincessSoundParent()
	local sound = Instance.new("Sound")
	sound.Name = "PrincessHitSoundTemplate"
	sound.SoundId = soundId
	sound.Volume = GameConfig.PrincessHitSoundVolume or 0.65
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 120
	sound.Parent = parent
	princessHitSoundTemplate = sound
	print("[WaveDefense] 公主受击音效（配置 ID）:", soundId)
end

local function playPrincessHitSound()
	if not princessHitSoundTemplate or not princessHitSoundTemplate.Parent then
		return
	end

	local sound = princessHitSoundTemplate:Clone()
	sound.Parent = princessHitSoundTemplate.Parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- 扫描 Workspace.Map 下所有层级，找 Name = "EnemySpawn" 的 Part
-- （以前只扫直接子级，放在子文件夹 / Model 里的刷怪点会漏掉）
-- 调用方：setupWorld
local function findMapObjects()
	local mapFolder = workspace:WaitForChild(MAP_FOLDER_NAME)

	local princess = mapFolder:WaitForChild(PRINCESS_NAME)
	if not princess:IsA("Model") and not princess:IsA("BasePart") then
		error(("[WaveDefense] %s 必须是 Model 或 Part"):format(PRINCESS_NAME))
	end
	princessTarget = princess
	disablePrincessBuiltInUi(princess)

	spawnPoints = {}
	for _, desc in mapFolder:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name == SPAWN_NAME then
			if isValidSpawnPoint(desc) then
				table.insert(spawnPoints, desc)
			else
				warn("[WaveDefense] 忽略无效刷怪点（在公主模型内部）:", desc:GetFullName())
			end
		end
	end

	if #spawnPoints == 0 then
		error(("[WaveDefense] 在 Workspace.%s 里找不到名为 %s 的 Part（任意子层级均可）"):format(
			MAP_FOLDER_NAME,
			SPAWN_NAME
		))
	end

	local template = ReplicatedStorage:WaitForChild(ENEMY_TEMPLATE_NAME, 5)
	if not template then
		error(("[WaveDefense] 请在 ReplicatedStorage 里放入名为 %s 的敌人 Model"):format(ENEMY_TEMPLATE_NAME))
	end

	validateEnemyTemplate(template)
	enemyTemplate = template
end

-- 波次计数：敌人 Destroy 时 -1，供 runWave 等待清场
local function trackWaveEnemy(enemy: Instance)
	activeWaveEnemies += 1

	local counted = false
	local function onRemoved()
		if counted then
			return
		end
		counted = true
		activeWaveEnemies = math.max(0, activeWaveEnemies - 1)
	end

	enemy.Destroying:Connect(onRemoved)
end

local function computePrincessMaxHpBonus(): number
	local cfg = GameConfig.ShopUpgrades.PrincessMaxHp
	if not cfg then
		return 0
	end

	local total = 0
	for _, player in Players:GetPlayers() do
		local level = player:GetAttribute("ShopLevel_PrincessMaxHp")
		if typeof(level) == "number" then
			total += math.max(0, math.floor(level)) * cfg.BonusPerLevel
		end
	end
	return total
end

function WaveDefense.getPrincessMaxHp(): number
	if princessMaxHpValue then
		return princessMaxHpValue.Value
	end
	return GameConfig.PrincessMaxHp + computePrincessMaxHpBonus()
end

function WaveDefense.recalculatePrincessMaxHp()
	if not princessMaxHpValue or not princessHpValue then
		return
	end

	local newMax = GameConfig.PrincessMaxHp + computePrincessMaxHpBonus()
	local oldMax = princessMaxHpValue.Value
	princessMaxHpValue.Value = newMax

	if newMax > oldMax then
		princessHpValue.Value = math.min(princessHpValue.Value + (newMax - oldMax), newMax)
	else
		princessHpValue.Value = math.min(princessHpValue.Value, newMax)
	end
end

function WaveDefense.addPrincessMaxHp(amount: number)
	if not princessMaxHpValue or not princessHpValue or amount <= 0 then
		return
	end

	princessMaxHpValue.Value += amount
	princessHpValue.Value = math.min(princessHpValue.Value + amount, princessMaxHpValue.Value)
end

function WaveDefense.healPrincess(player: Player): (boolean, string)
	local healCfg = GameConfig.ShopPrincessHeal
	if not princessHpValue or not princessMaxHpValue then
		return false, "游戏未开始"
	end
	if princessHpValue.Value <= 0 then
		return false, "公主已失守"
	end

	local maxHp = princessMaxHpValue.Value
	if princessHpValue.Value >= maxHp then
		return false, "公主生命已满"
	end

	local readyAt = player:GetAttribute("PrincessHealReadyAt")
	if typeof(readyAt) == "number" then
		local remaining = readyAt - workspace:GetServerTimeNow()
		if remaining > 0 then
			return false, ("冷却中 %d 秒"):format(math.ceil(remaining))
		end
	end

	local before = princessHpValue.Value
	princessHpValue.Value = math.min(princessHpValue.Value + healCfg.HealAmount, maxHp)
	local healed = princessHpValue.Value - before

	player:SetAttribute("PrincessHealReadyAt", workspace:GetServerTimeNow() + healCfg.Cooldown)

	return true, ("已恢复 %d 生命"):format(healed)
end

-- 扣公主 HP；HP 归零时标记游戏结束
local function damagePrincess(amount: number)
	playPrincessHitSound()

	princessHpValue.Value = math.max(0, princessHpValue.Value - amount)
	if princessHpValue.Value <= 0 then
		wavePhaseValue.Value = "Defeated"
		print("[WaveDefense] 公主被攻破，游戏结束")
	end
end

local function getDistanceToPrincess(enemy: Model | BasePart): number
	local enemyPos = getPosition(enemy)
	return (getMoveTargetPosition(enemyPos) - enemyPos).Magnitude
end

local function facePrincess(enemy: Model)
	local root = getHumanoidRoot(enemy)
	if not root then
		return
	end
	local target = getMoveTargetPosition(root.Position)
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))
end

-- Humanoid 怪：停下 → 循环播攻击动画 → 按间隔扣公主 HP（怪不消失，直到被玩家打死或公主死）
local function runHumanoidPrincessAttack(enemy: Model, humanoid: Humanoid)
	enemy:SetAttribute("IsAttackingPrincess", true)

	humanoid:MoveTo(getPosition(enemy))
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false

	task.spawn(function()
		while enemy.Parent and princessHpValue.Value > 0 do
			facePrincess(enemy)
			playAttackAnimation(enemy, humanoid)

			task.wait(GameConfig.EnemyAttackWindup)
			if enemy.Parent and princessHpValue.Value > 0 then
				damagePrincess(GameConfig.PrincessDamagePerHit)
			end

			local rest = GameConfig.EnemyAttackCooldown - GameConfig.EnemyAttackWindup
			if rest > 0 then
				task.wait(rest)
			end
		end
	end)
end

-- 无 Humanoid 的怪：在攻击距离内按间隔扣血（无动画）
local function runSlidePrincessAttack(enemy: Model | BasePart)
	enemy:SetAttribute("IsAttackingPrincess", true)

	task.spawn(function()
		while enemy.Parent and princessHpValue.Value > 0 do
			if getDistanceToPrincess(enemy) > GameConfig.EnemyReachDistance then
				break
			end
			damagePrincess(GameConfig.PrincessDamagePerHit)
			task.wait(GameConfig.EnemyAttackCooldown)
		end
	end)
end

-- 进入攻击距离后调用（替代旧的一次性 onEnemyReachPrincess）
local function beginPrincessAttack(enemy: Model | BasePart, humanoid: Humanoid?)
	if enemy:GetAttribute("IsAttackingPrincess") then
		return
	end

	if humanoid and enemy:IsA("Model") then
		runHumanoidPrincessAttack(enemy, humanoid)
	else
		runSlidePrincessAttack(enemy)
	end
end

-- ---------------------------------------------------------------------------
-- 移动逻辑
-- ---------------------------------------------------------------------------

-- 调用方：spawnWaveEnemy（Part / 无 Humanoid 的 Model / Humanoid 卡住 fallback）
local function runSlideMovement(enemy: Model | BasePart)
	prepareSlideEnemy(enemy)

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not enemy.Parent then
			connection:Disconnect()
			return
		end

		local enemyPos = getPosition(enemy)
		local moveTarget = getMoveTargetPosition(enemyPos)
		local toPrincess = moveTarget - enemyPos
		local distance = toPrincess.Magnitude

		local hitStunUntil = enemy:GetAttribute("HitStunUntil")
		if typeof(hitStunUntil) == "number" and os.clock() < hitStunUntil then
			return
		end

		if distance <= GameConfig.EnemyReachDistance then
			connection:Disconnect()
			beginPrincessAttack(enemy)
			return
		end

		moveTo(enemy, enemyPos + toPrincess.Unit * GameConfig.EnemySpeed * dt)
	end)
end

-- 调用方：spawnWaveEnemy（带 Humanoid 的 NPC）
local function runHumanoidMovement(enemy: Model)
	local humanoid = findHumanoid(enemy) :: Humanoid
	local moveConnection: RBXScriptConnection? = nil
	local moveLoop: thread? = nil

	local function moveTowardPrincess()
		if not enemy.Parent or princessHpValue.Value <= 0 then
			return
		end
		local hitStunUntil = enemy:GetAttribute("HitStunUntil")
		if typeof(hitStunUntil) == "number" and os.clock() < hitStunUntil then
			return
		end
		local enemyPos = getPosition(enemy)
		humanoid:MoveTo(getMoveTargetPosition(enemyPos))
	end

	-- 等一帧物理就绪后再开始走（刚解除 Anchored 立刻 MoveTo 容易失败）
	task.defer(moveTowardPrincess)

	moveLoop = task.spawn(function()
		while enemy.Parent and princessHpValue.Value > 0 do
			task.wait(1)
			moveTowardPrincess()
		end
	end)

	humanoid.MoveToFinished:Connect(function(_reached)
		moveTowardPrincess()
	end)

	moveConnection = RunService.Heartbeat:Connect(function()
		if not enemy.Parent then
			if moveConnection then
				moveConnection:Disconnect()
			end
			if moveLoop then
				task.cancel(moveLoop)
			end
			return
		end

		local enemyPos = getPosition(enemy)
		local distance = (getMoveTargetPosition(enemyPos) - enemyPos).Magnitude

		if distance <= GameConfig.EnemyReachDistance then
			if moveConnection then
				moveConnection:Disconnect()
			end
			if moveLoop then
				task.cancel(moveLoop)
			end
			beginPrincessAttack(enemy, humanoid)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- 刷怪
-- ---------------------------------------------------------------------------

-- 在指定刷怪点 CFrame 克隆敌人
-- 调用方：spawnWaveEnemy
local function createEnemyAt(spawnPoint: BasePart): (Model | BasePart, boolean)
	local spawnCFrame = getSpawnCFrame(spawnPoint)

	local enemy = enemyTemplate:Clone()
	enemy.Name = "WaveEnemy"
	enemy:SetAttribute("IsWaveEnemy", true)
	enemy:SetAttribute("SpawnPointName", spawnPoint:GetFullName())

	ensureEnemyHealth(enemy)

	if enemy:IsA("Model") then
		sanitizeEnemyModel(enemy)
	end

	-- 脚本清完后再放进场景，避免 Toolbox 怪自带 Script 额外刷怪
	enemy.Parent = waveEnemiesFolder
	placeEnemyAt(enemy, spawnCFrame)

	local usesHumanoid = false
	if enemy:IsA("Model") then
		usesHumanoid = setupHumanoidEnemy(enemy)
		if not usesHumanoid then
			prepareSlideEnemy(enemy)
		end
	else
		prepareSlideEnemy(enemy)
	end

	trackWaveEnemy(enemy)

	print(
		"[WaveDefense] 刷怪 @",
		spawnPoint:GetFullName(),
		"→",
		spawnCFrame.Position,
		usesHumanoid and "（走路）" or "（平移）"
	)

	return enemy, usesHumanoid
end

-- 刷 1 只怪：随机选一个刷怪点
-- 调用方：runWave
local function spawnWaveEnemy()
	if princessHpValue.Value <= 0 then
		return
	end

	local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
	local enemy, usesHumanoid = createEnemyAt(spawnPoint)

	if usesHumanoid and enemy:IsA("Model") then
		runHumanoidMovement(enemy)
	else
		runSlideMovement(enemy)
	end
end

local function getWaveEnemyCount(waveNumber: number): number
	return GameConfig.WaveBaseEnemyCount + (waveNumber - 1) * GameConfig.WaveEnemyCountPerWave
end

-- 下一波开始前的等待：第 1 波用 FirstWaveDelay，之后从 WaveIntermissionStart 渐增至 WaveIntermissionEnd
local function getIntermissionBeforeWave(waveToStart: number): number
	if waveToStart <= 1 then
		return GameConfig.FirstWaveDelay
	end

	local startSec = GameConfig.WaveIntermissionStart
	local endSec = GameConfig.WaveIntermissionEnd
	local rampSteps = math.max(1, GameConfig.WaveIntermissionRampWaves - 1)
	local t = math.clamp((waveToStart - 2) / rampSteps, 0, 1)
	return math.floor(startSec + (endSec - startSec) * t + 0.5)
end

-- 调用方：start 波次循环
local function runIntermission(seconds: number): boolean
	wavePhaseValue.Value = "Intermission"

	for remaining = seconds, 1, -1 do
		if princessHpValue.Value <= 0 then
			return false
		end
		waveCountdownValue.Value = remaining
		task.wait(1)
	end

	waveCountdownValue.Value = 0
	return princessHpValue.Value > 0
end

-- 调用方：start 波次循环
local function runWave(waveNumber: number): boolean
	wavePhaseValue.Value = "InProgress"
	waveNumberValue.Value = waveNumber

	local enemyCount = getWaveEnemyCount(waveNumber)
	print(("[WaveDefense] 第 %d 波开始，敌人数量 %d"):format(waveNumber, enemyCount))

	for _ = 1, enemyCount do
		if princessHpValue.Value <= 0 then
			return false
		end

		local ok, err = pcall(spawnWaveEnemy)
		if not ok then
			warn("[WaveDefense] 刷怪失败：", err)
			return false
		end

		task.wait(GameConfig.WaveSpawnInterval)
	end

	while activeWaveEnemies > 0 and princessHpValue.Value > 0 do
		task.wait(0.25)
	end

	print(("[WaveDefense] 第 %d 波结束"):format(waveNumber))
	return princessHpValue.Value > 0
end

-- ---------------------------------------------------------------------------
-- 对外入口
-- ---------------------------------------------------------------------------

-- 调用方：start（先执行一次）
function WaveDefense.setupWorld()
	ensureGameState()
	waveEnemiesFolder = ensureWaveEnemiesFolder()
	clearStrayEnemies()

	princessMaxHpValue.Value = GameConfig.PrincessMaxHp + computePrincessMaxHpBonus()
	princessHpValue.Value = princessMaxHpValue.Value
	waveNumberValue.Value = 0
	waveCountdownValue.Value = GameConfig.FirstWaveDelay
	wavePhaseValue.Value = "Intermission"

	findMapObjects()
	setupPrincessHitSound()

	print(
		"[WaveDefense] 已绑定：公主 +",
		#spawnPoints,
		"个刷怪点 + 敌人模板",
		enemyTemplate.Name
	)
	print("[WaveDefense] 公主目标位置 @", getPrincessPosition())
	for index, point in ipairs(spawnPoints) do
		print(("  刷怪点[%d] %s @ %s"):format(index, point:GetFullName(), tostring(point.Position)))
	end
end

-- 【入口】init.server.luau 调用
function WaveDefense.start()
	if isRunning then
		warn("[WaveDefense] 已在运行，跳过重复 start（避免重复刷怪）")
		return
	end
	isRunning = true

	WaveDefense.setupWorld()

	task.spawn(function()
		local waveNumber = 0

		while princessHpValue.Value > 0 do
			waveNumber += 1
			local waitSec = getIntermissionBeforeWave(waveNumber)
			if not runIntermission(waitSec) then
				break
			end
			if not runWave(waveNumber) then
				break
			end
		end
	end)
end

return WaveDefense
