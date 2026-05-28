-- ============================================================================
-- Tutorial（新手指引 · 服务端）
-- 记录玩家是否已看过开局 UI / 新手指引（同局内持久）
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = {}

local INTRO_ATTR = "TutorialIntroDone"
local GUIDE_ATTR = "TutorialGuideDone"

local function ensureRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("TutorialMark") :: RemoteEvent?
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "TutorialMark"
		remote.Parent = remotes
	end
	return remote
end

local function setupPlayer(player: Player)
	if typeof(player:GetAttribute(INTRO_ATTR)) ~= "boolean" then
		player:SetAttribute(INTRO_ATTR, false)
	end
	if typeof(player:GetAttribute(GUIDE_ATTR)) ~= "boolean" then
		player:SetAttribute(GUIDE_ATTR, false)
	end
end

function Tutorial.resetPlayer(player: Player)
	player:SetAttribute(INTRO_ATTR, false)
	player:SetAttribute(GUIDE_ATTR, false)
end

function Tutorial.start()
	local remote = ensureRemotes()

	remote.OnServerEvent:Connect(function(player: Player, markId: string)
		if markId == "Intro" then
			player:SetAttribute(INTRO_ATTR, true)
		elseif markId == "Guide" then
			player:SetAttribute(GUIDE_ATTR, true)
		end
	end)

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerAdded:Connect(setupPlayer)
end

return Tutorial
