-- ============================================================================
-- PrincessHitSound（公主受击音 · 客户端）
-- 服务端扣血时 FireAllClients；在 SoundService 播放（全图音量一致，无距离衰减）
-- ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local MAP_FOLDER = "Map"
local PRINCESS_NAME = "Princess"

local function isUsableSoundId(soundId: string): boolean
	if soundId == "" or soundId == "rbxassetid://0" then
		return false
	end
	return soundId:find("rbxassetid://") ~= nil or soundId:find("^%d+$") ~= nil
end

local function resolvePrincessHitSoundId(): string?
	local map = Workspace:FindFirstChild(MAP_FOLDER)
	if map then
		local princess = map:FindFirstChild(PRINCESS_NAME, true)
		if princess then
			local soundName = GameConfig.PrincessHitSoundName or "PrincessHit"
			for _, desc in princess:GetDescendants() do
				if desc:IsA("Sound") and desc.Name == soundName and isUsableSoundId(desc.SoundId) then
					return desc.SoundId
				end
			end
		end
	end

	local soundId = GameConfig.PrincessHitSoundId
	if typeof(soundId) == "string" and isUsableSoundId(soundId) then
		return soundId
	end

	return nil
end

local function playLoadedSound(sound: Sound)
	task.spawn(function()
		local deadline = os.clock() + 8
		while not sound.IsLoaded and os.clock() < deadline do
			task.wait(0.05)
		end
		if not sound.Parent then
			return
		end
		if sound.IsLoaded then
			sound:Play()
			sound.Ended:Once(function()
				sound:Destroy()
			end)
		else
			sound:Destroy()
		end
	end)
end

local function playPrincessHitSound()
	local soundId = resolvePrincessHitSoundId()
	if not soundId then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Looped = false
	sound.Volume = GameConfig.PrincessHitSoundVolume or 0.65
	if sound.Volume <= 0 then
		sound.Volume = 0.65
	end
	-- 挂在 SoundService = 2D 全局，不受与公主距离影响
	sound.Parent = SoundService
	playLoadedSound(sound)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if remotes then
	local remote = remotes:WaitForChild("PrincessHitSound", 30) :: RemoteEvent?
	if remote then
		remote.OnClientEvent:Connect(playPrincessHitSound)
	end
end
