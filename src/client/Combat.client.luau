-- ============================================================================
-- Combat（客户端：伤害通知 + 武器动画）
-- 有 LocalScript 且带 Animation 的武器走自带；否则播 WeaponStats.AnimId / 兜底
-- ============================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local attackRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Attack") :: RemoteEvent

local player = Players.LocalPlayer
local lastAttackAt = 0
local boundTools: { [Tool]: boolean } = {}
local animTemplates: { [string]: Animation } = {}
local activeTrack: AnimationTrack? = nil

local function getHumanoid(): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function getEquippedTool(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Tool")
end

local function getAttackCooldown(): number
	local tool = getEquippedTool()
	if tool then
		local cooldown = tool:GetAttribute("AttackCooldown")
		if typeof(cooldown) == "number" then
			return cooldown
		end
		local weaponStats = GameConfig.WeaponStats[tool.Name]
		if weaponStats and typeof(weaponStats.Cooldown) == "number" then
			return weaponStats.Cooldown
		end
		return GameConfig.ToolAttackCooldown
	end
	return GameConfig.AttackCooldown
end

local function findToolAnimation(tool: Tool): Animation?
	for _, desc in tool:GetDescendants() do
		if desc:IsA("Animation") and desc.AnimationId ~= "" then
			return desc
		end
	end
	return nil
end

local function toolHasActiveLocalScript(tool: Tool): boolean
	for _, desc in tool:GetDescendants() do
		if desc:IsA("LocalScript") and desc.Enabled then
			return true
		end
	end
	return false
end

local function shouldUseBuiltInToolAnim(tool: Tool): boolean
	if tool:GetAttribute("UseFallbackAnim") == true then
		return false
	end
	if tool:GetAttribute("HasBuiltInAnim") == true then
		return toolHasActiveLocalScript(tool)
	end

	-- 仅当 LocalScript 仍在运行时才交给武器自带逻辑（Studio 里禁用脚本后走兜底）
	return toolHasActiveLocalScript(tool) and findToolAnimation(tool) ~= nil
end

local function getConfiguredAnim(tool: Tool): (Animation, number)
	local animId = tool:GetAttribute("AnimId")
	local animSpeed = tool:GetAttribute("AnimSpeed")

	local weaponStats = GameConfig.WeaponStats[tool.Name]
	if typeof(animId) ~= "string" or animId == "" then
		if weaponStats and typeof(weaponStats.AnimId) == "string" and weaponStats.AnimId ~= "" then
			animId = weaponStats.AnimId
		else
			animId = GameConfig.FallbackWeaponAnimId
		end
	end

	if typeof(animSpeed) ~= "number" then
		if weaponStats and typeof(weaponStats.AnimSpeed) == "number" then
			animSpeed = weaponStats.AnimSpeed
		else
			animSpeed = GameConfig.FallbackWeaponAnimSpeed
		end
	end

	local cached = animTemplates[animId]
	if cached then
		return cached, animSpeed
	end

	local anim = Instance.new("Animation")
	anim.Name = "CombatWeaponAnim"
	anim.AnimationId = animId
	animTemplates[animId] = anim
	return anim, animSpeed
end

local function scheduleTrackStop(track: AnimationTrack, speed: number)
	local function stopLater()
		local length = track.Length
		if length <= 0 then
			length = 0.45
		end
		task.delay(length / math.max(speed, 0.01) + 0.05, function()
			if track.IsPlaying then
				track:Stop(0.08)
			end
		end)
	end

	if track.Length > 0 then
		stopLater()
	else
		track:GetPropertyChangedSignal("Length"):Once(stopLater)
		task.delay(0.2, stopLater)
	end
end

local function playAnimTrack(humanoid: Humanoid, anim: Animation, speed: number)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	if activeTrack and activeTrack.IsPlaying then
		activeTrack:Stop(0.05)
	end

	local ok, track = pcall(function()
		local loaded = animator:LoadAnimation(anim)
		loaded.Priority = Enum.AnimationPriority.Action
		loaded.Looped = false
		loaded:AdjustSpeed(speed)
		loaded:Play(0.05, 1, speed)
		return loaded
	end)

	if not ok or not track then
		return
	end

	activeTrack = track
	scheduleTrackStop(track, speed)
end

local function playWeaponSounds(tool: Tool)
	local weaponStats = GameConfig.WeaponStats[tool.Name]
	local configSoundId = weaponStats and weaponStats.SwingSoundId
	if typeof(configSoundId) ~= "string" or configSoundId == "" then
		configSoundId = GameConfig.FallbackWeaponSwingSoundId
	end

	local played = false
	for _, desc in tool:GetDescendants() do
		if desc:IsA("Sound") and desc.SoundId ~= "" then
			local sound = desc:Clone()
			sound.Parent = desc.Parent
			sound:Play()
			sound.Ended:Once(function()
				sound:Destroy()
			end)
			played = true
		end
	end

	if not played and typeof(configSoundId) == "string" and configSoundId ~= "" then
		local handle = tool:FindFirstChild("Handle")
		local parent = if handle and handle:IsA("BasePart") then handle else tool
		local sound = Instance.new("Sound")
		sound.SoundId = configSoundId
		sound.Volume = GameConfig.FallbackWeaponSwingSoundVolume or 0.5
		sound.Parent = parent
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
end

local function playWeaponAnimation(tool: Tool)
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end

	if shouldUseBuiltInToolAnim(tool) then
		return
	end

	local anim, speed = getConfiguredAnim(tool)
	playAnimTrack(humanoid, anim, speed)
end

local function requestAttack()
	local now = os.clock()
	if now - lastAttackAt < getAttackCooldown() then
		return
	end
	lastAttackAt = now
	attackRemote:FireServer()
end

local function bindTool(tool: Tool)
	if boundTools[tool] then
		return
	end
	boundTools[tool] = true

	tool.Activated:Connect(function()
		playWeaponAnimation(tool)
		playWeaponSounds(tool)
		requestAttack()
	end)

	tool.Destroying:Connect(function()
		boundTools[tool] = nil
	end)
end

local function watchTools(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end

	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
end

local function bindPlayerTools()
	local backpack = player:WaitForChild("Backpack")
	watchTools(backpack)

	if player.Character then
		watchTools(player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		watchTools(character)
	end)
end

bindPlayerTools()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if getEquippedTool() then
		return
	end
	requestAttack()
end)
