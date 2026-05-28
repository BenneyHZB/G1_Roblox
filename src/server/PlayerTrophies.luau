-- ============================================================================
-- PlayerTrophies（奖杯 · 累计不消耗 · DataStore 跨服同步）
-- leaderstats.Trophies → 右上角；换购只检查门槛，不扣减
-- ============================================================================

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local PlayerTrophies = {}

local trophyStore
local loadInFlight: { [number]: boolean } = {}
local saveScheduled: { [number]: boolean } = {}
local loadedUserIds: { [number]: boolean } = {}

local function getStoreCfg()
	return GameConfig.TrophyDataStore or {}
end

local function getDataKey(userId: number): string
	local prefix = getStoreCfg().KeyPrefix or "u_"
	return prefix .. tostring(userId)
end

local function getStartingTrophies(): number
	return math.max(0, math.floor(GameConfig.StartingTrophies or 1))
end

local function ensureTrophies(player: Player): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local trophies = leaderstats:FindFirstChild("Trophies")
	if not trophies then
		trophies = Instance.new("IntValue")
		trophies.Name = "Trophies"
		trophies.Value = 0
		trophies.Parent = leaderstats
	end

	return trophies :: IntValue
end

local function parseSavedTrophies(data: any): number?
	if typeof(data) == "number" then
		return math.max(0, math.floor(data))
	end
	if typeof(data) == "table" and typeof(data.trophies) == "number" then
		return math.max(0, math.floor(data.trophies))
	end
	return nil
end

local function initDataStore()
	local cfg = getStoreCfg()
	local storeName = cfg.StoreName or "PlayerTrophies_v1"

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)

	if ok then
		trophyStore = result
	else
		warn("[PlayerTrophies] DataStore 初始化失败:", result)
	end

	if RunService:IsStudio() and not ok then
		warn(
			"[PlayerTrophies] Studio 测试存档：游戏设置 → 安全 → 启用 Studio 访问 API 服务；正式发布后跨服存档才会稳定生效"
		)
	end
end

function PlayerTrophies.loadPlayer(player: Player)
	if loadedUserIds[player.UserId] or loadInFlight[player.UserId] then
		return
	end

	loadInFlight[player.UserId] = true
	local trophies = ensureTrophies(player)

	local saved: number? = nil
	if trophyStore then
		local key = getDataKey(player.UserId)
		local ok, data = pcall(function()
			return trophyStore:GetAsync(key)
		end)
		if ok then
			saved = parseSavedTrophies(data)
		else
			warn("[PlayerTrophies] 读取失败:", player.Name, data)
		end
	end

	if saved == nil then
		trophies.Value = getStartingTrophies()
	else
		trophies.Value = saved
	end

	loadedUserIds[player.UserId] = true
	loadInFlight[player.UserId] = nil
	player:SetAttribute("TrophiesLoaded", true)

	print(("[PlayerTrophies] %s 载入奖杯 %d"):format(player.Name, trophies.Value))
end

function PlayerTrophies.savePlayer(player: Player, force: boolean?)
	if not trophyStore then
		return
	end
	if not loadedUserIds[player.UserId] and not force then
		return
	end

	local trophies = player:FindFirstChild("leaderstats")
		and player.leaderstats:FindFirstChild("Trophies") :: IntValue?
	if not trophies then
		return
	end

	local key = getDataKey(player.UserId)
	local value = trophies.Value
	local ok, err = pcall(function()
		trophyStore:SetAsync(key, value)
	end)

	if ok then
		saveScheduled[player.UserId] = nil
	else
		warn("[PlayerTrophies] 保存失败:", player.Name, err)
	end
end

local function scheduleSave(player: Player)
	if not trophyStore or not loadedUserIds[player.UserId] then
		return
	end
	if saveScheduled[player.UserId] then
		return
	end
	saveScheduled[player.UserId] = true

	local userId = player.UserId
	task.delay(2, function()
		saveScheduled[userId] = nil
		local plr = Players:GetPlayerByUserId(userId)
		if plr then
			PlayerTrophies.savePlayer(plr)
		end
	end)
end

function PlayerTrophies.setupPlayer(player: Player)
	ensureTrophies(player)
	player:SetAttribute("TrophiesLoaded", false)
	task.spawn(function()
		PlayerTrophies.loadPlayer(player)
	end)
end

function PlayerTrophies.add(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	if not loadedUserIds[player.UserId] then
		PlayerTrophies.loadPlayer(player)
	end
	ensureTrophies(player).Value += amount
	scheduleSave(player)
end

function PlayerTrophies.get(player: Player): number
	return ensureTrophies(player).Value
end

function PlayerTrophies.meetsThreshold(player: Player, required: number): boolean
	return PlayerTrophies.get(player) >= required
end

function PlayerTrophies.start()
	initDataStore()

	for _, player in Players:GetPlayers() do
		PlayerTrophies.setupPlayer(player)
	end

	Players.PlayerAdded:Connect(PlayerTrophies.setupPlayer)

	Players.PlayerRemoving:Connect(function(player)
		PlayerTrophies.savePlayer(player, true)
		loadedUserIds[player.UserId] = nil
		loadInFlight[player.UserId] = nil
		saveScheduled[player.UserId] = nil
	end)

	local autoSave = getStoreCfg().AutoSaveSeconds
	if typeof(autoSave) == "number" and autoSave > 0 and trophyStore then
		task.spawn(function()
			while true do
				task.wait(autoSave)
				for _, player in Players:GetPlayers() do
					PlayerTrophies.savePlayer(player)
				end
			end
		end)
	end

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerTrophies.savePlayer(player, true)
		end
		if RunService:IsStudio() then
			task.wait(2)
		end
	end)
end

return PlayerTrophies
