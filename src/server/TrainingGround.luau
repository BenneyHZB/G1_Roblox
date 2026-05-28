-- ============================================================================
-- TrainingGround（训练木桩 · 服务端）
-- Map.TrainerNPC 选等级 → Map.DummySpawn 生成木桩 → 击杀得奖杯
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local TrainingUtil = require(ReplicatedStorage.Shared.TrainingUtil)
local PlayerTrophies = require(script.Parent.PlayerTrophies)

local TrainingGround = {}

local MAP_FOLDER = "Map"
local TRAINING_FOLDER = "TrainingDummies"

local summonRemote: RemoteFunction
local dummyTemplate: Instance?
local dummySpawn: BasePart?
local dummiesFolder: Folder?
local activeDummyByPlayer: { [Player]: Instance } = {}

local function getTrainingCfg()
	return GameConfig.Training
end

local function initPlayerTraining(player: Player)
	if typeof(player:GetAttribute("TrainingMaxUnlocked")) ~= "number" then
		player:SetAttribute("TrainingMaxUnlocked", 1)
	end
	if typeof(player:GetAttribute("TrainingHighestBeaten")) ~= "number" then
		player:SetAttribute("TrainingHighestBeaten", 0)
	end
end

local function findInteractPart(model: Instance): BasePart?
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") then
		if model.PrimaryPart then
			return model.PrimaryPart
		end
		local part = model:FindFirstChildWhichIsA("BasePart", true)
		if part then
			model.PrimaryPart = part
		end
		return part
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function ensureProximityPrompt(model: Instance): ProximityPrompt?
	local cfg = getTrainingCfg()
	local existing = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existing then
		existing.ObjectText = "训练师"
		existing.ActionText = "选择木桩"
		existing.MaxActivationDistance = cfg.InteractDistance
		existing.HoldDuration = 0
		existing.RequiresLineOfSight = false
		return existing
	end

	local part = findInteractPart(model)
	if not part then
		return nil
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainingPrompt"
	prompt.ObjectText = "训练师"
	prompt.ActionText = "选择木桩"
	prompt.MaxActivationDistance = cfg.InteractDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function anchorDummy(enemy: Instance)
	if enemy:IsA("BasePart") then
		enemy.Anchored = true
		enemy.CanCollide = true
	end
	for _, desc in enemy:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end
end

local function disableHostileScripts(root: Instance)
	for _, desc in root:GetDescendants() do
		if desc:IsA("Script") or desc:IsA("LocalScript") then
			desc.Disabled = true
		end
	end
end

local function freezeHumanoidNpc(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	for _, track in humanoid:GetPlayingAnimationTracks() do
		track:Stop()
	end

	local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		rootPart.Anchored = true
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end
end

-- 训练木桩：站立、显示血条、锚定防位移（不用 PlatformStand，否则会躺倒）
local function setupTrainingDummy(model: Model)
	disableHostileScripts(model)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
		humanoid.PlatformStand = false
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.AssemblyLinearVelocity = Vector3.zero
			desc.AssemblyAngularVelocity = Vector3.zero
		elseif desc:IsA("BodyMover") or desc:IsA("LinearVelocity") or desc:IsA("AlignPosition") then
			desc:Destroy()
		end
	end
end

local function anchorModelInPlace(model: Model)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.AssemblyLinearVelocity = Vector3.zero
			desc.AssemblyAngularVelocity = Vector3.zero
		elseif desc:IsA("BodyMover") or desc:IsA("LinearVelocity") or desc:IsA("AlignPosition") then
			desc:Destroy()
		end
	end
end

-- 地图上的训练师：关脚本、锚定、禁止移动（避免 Toolbox NPC 主动攻击玩家）
local function sanitizeTrainer(trainer: Instance)
	if not trainer:IsA("Model") then
		return
	end

	disableHostileScripts(trainer)
	for _, child in trainer:GetChildren() do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end
	freezeHumanoidNpc(trainer)
	anchorModelInPlace(trainer)
	trainer:SetAttribute("IsPassiveNpc", true)
end

local function setDummyHealth(enemy: Instance, hp: number)
	if enemy:IsA("Model") then
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = hp
			humanoid.Health = hp
			return
		end
	end
	enemy:SetAttribute("Health", hp)
end

local function getDummySpawnCFrame(position: Vector3): CFrame
	local rotZ = math.rad(getTrainingCfg().DummySpawnRotationZ or 0)
	return CFrame.new(position) * CFrame.Angles(0, 0, rotZ)
end

local function placeDummy(enemy: Instance)
	if not dummySpawn then
		return
	end

	local spawnPoint = dummySpawn.Position
	local spawnCf = getDummySpawnCFrame(spawnPoint)

	if enemy:IsA("Model") then
		enemy:PivotTo(spawnCf)

		local bboxCF, bboxSize = enemy:GetBoundingBox()
		local bottomY = bboxCF.Position.Y - bboxSize.Y / 2
		local lift = spawnPoint.Y - bottomY
		if math.abs(lift) > 0.01 then
			enemy:PivotTo(enemy:GetPivot() + Vector3.new(0, lift, 0))
		end
	elseif enemy:IsA("BasePart") then
		enemy.CFrame = spawnCf
	end
end

local function clearPlayerDummy(player: Player)
	local existing = activeDummyByPlayer[player]
	if existing and existing.Parent then
		existing:Destroy()
	end
	activeDummyByPlayer[player] = nil
end

local function spawnDummyAtLevel(player: Player, level: number): (boolean, string?)
	local cfg = getTrainingCfg()
	if not dummyTemplate or not dummySpawn or not dummiesFolder then
		return false, "训练场未就绪"
	end

	local safeLevel = math.floor(level)
	if safeLevel < 1 or safeLevel > cfg.MaxLevel then
		return false, "等级无效"
	end
	if not TrainingUtil.isLevelUnlocked(player, safeLevel) then
		return false, "尚未解锁该等级"
	end

	clearPlayerDummy(player)

	local stats = TrainingUtil.getLevelStats(safeLevel)
	local enemy = dummyTemplate:Clone()
	enemy.Name = ("TrainingDummy_Lv%d"):format(safeLevel)
	enemy:SetAttribute("IsTrainingDummy", true)
	enemy:SetAttribute("DummyLevel", safeLevel)
	enemy:SetAttribute("OwnerUserId", player.UserId)
	enemy:SetAttribute("TrophyReward", stats.trophies)

	enemy.Parent = dummiesFolder
	placeDummy(enemy)

	if enemy:IsA("Model") then
		setupTrainingDummy(enemy)
	else
		anchorDummy(enemy)
	end

	setDummyHealth(enemy, stats.hp)

	activeDummyByPlayer[player] = enemy
	enemy.Destroying:Once(function()
		if activeDummyByPlayer[player] == enemy then
			activeDummyByPlayer[player] = nil
		end
	end)

	return true, nil
end

local function respawnActiveDummy(player: Player)
	if not player.Parent then
		return
	end

	local activeLevel = player:GetAttribute("TrainingActiveLevel")
	if typeof(activeLevel) ~= "number" then
		return
	end

	local ok, err = spawnDummyAtLevel(player, activeLevel)
	if not ok and err then
		warn("[TrainingGround] 刷新木桩失败:", player.Name, err)
	end
end

function TrainingGround.getLevelStats(level: number): { hp: number, trophies: number }
	return TrainingUtil.getLevelStats(level)
end

function TrainingGround.recordVictory(player: Player, level: number, trophies: number)
	local cfg = getTrainingCfg()
	local safeLevel = math.clamp(math.floor(level), 1, cfg.MaxLevel)

	local beaten = player:GetAttribute("TrainingHighestBeaten")
	if typeof(beaten) ~= "number" then
		beaten = 0
	end
	if safeLevel > beaten then
		player:SetAttribute("TrainingHighestBeaten", safeLevel)
		local unlocked = TrainingUtil.getMaxUnlocked(player)
		local newUnlocked = math.min(cfg.MaxLevel, safeLevel + 1)
		player:SetAttribute("TrainingMaxUnlocked", math.max(unlocked, newUnlocked))
	end

	PlayerTrophies.add(player, trophies)

	-- 当前刷级：击杀后立即再刷一只同等级木桩
	local activeLevel = player:GetAttribute("TrainingActiveLevel")
	if typeof(activeLevel) == "number" and math.floor(activeLevel) == safeLevel then
		local delay = cfg.DummyRespawnDelay or 0.2
		task.delay(delay, function()
			if player.Parent then
				respawnActiveDummy(player)
			end
		end)
	end
end

function TrainingGround.summon(player: Player, level: number): (boolean, string)
	local safeLevel = math.floor(level)
	local ok, err = spawnDummyAtLevel(player, safeLevel)
	if not ok then
		return false, err or "召唤失败"
	end

	player:SetAttribute("TrainingActiveLevel", safeLevel)
	return true, ("开始刷 Lv.%d 木桩（击杀自动刷新）"):format(safeLevel)
end

local function onSummon(player: Player, level: number): (boolean, string)
	if typeof(level) ~= "number" then
		return false, "无效请求"
	end
	return TrainingGround.summon(player, level)
end

local function bindWorld()
	local cfg = getTrainingCfg()
	local map = Workspace:WaitForChild(MAP_FOLDER, 30)
	if not map then
		warn("[TrainingGround] 未找到 Workspace.Map")
		return
	end

	local trainer = map:WaitForChild(cfg.TrainerModelName, 30)
	if not trainer then
		warn("[TrainingGround] 未找到", cfg.TrainerModelName)
		return
	end

	dummySpawn = map:FindFirstChild(cfg.DummySpawnName, true) :: BasePart?
	if not dummySpawn or not dummySpawn:IsA("BasePart") then
		warn("[TrainingGround] 未找到 Part:", cfg.DummySpawnName)
		return
	end

	dummyTemplate = ReplicatedStorage:FindFirstChild(cfg.DummyTemplateName)
	if not dummyTemplate then
		dummyTemplate = ReplicatedStorage:FindFirstChild("EnemyTemplate")
	end
	if not dummyTemplate then
		warn("[TrainingGround] 未找到木桩模板")
		return
	end

	dummiesFolder = Workspace:FindFirstChild(TRAINING_FOLDER) :: Folder?
	if not dummiesFolder then
		dummiesFolder = Instance.new("Folder")
		dummiesFolder.Name = TRAINING_FOLDER
		dummiesFolder.Parent = Workspace
	end

	trainer:SetAttribute("IsTrainingTrainer", true)
	sanitizeTrainer(trainer)
	ensureProximityPrompt(trainer)
	print("[TrainingGround] 已绑定：", trainer:GetFullName(), "→", dummySpawn:GetFullName())
end

local function trySanitizeTrainerEarly()
	local map = Workspace:FindFirstChild(MAP_FOLDER)
	if not map then
		return
	end
	local cfg = getTrainingCfg()
	local trainer = map:FindFirstChild(cfg.TrainerModelName)
	if trainer and trainer:IsA("Model") then
		sanitizeTrainer(trainer)
	end
end

function TrainingGround.start()
	trySanitizeTrainerEarly()

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	summonRemote = remotes:FindFirstChild("TrainingSummon") :: RemoteFunction?
	if not summonRemote then
		summonRemote = Instance.new("RemoteFunction")
		summonRemote.Name = "TrainingSummon"
		summonRemote.Parent = remotes
	end
	summonRemote.OnServerInvoke = onSummon

	for _, player in Players:GetPlayers() do
		initPlayerTraining(player)
	end
	Players.PlayerAdded:Connect(function(player)
		initPlayerTraining(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("TrainingActiveLevel", nil)
		clearPlayerDummy(player)
	end)

	task.spawn(bindWorld)
end

return TrainingGround
