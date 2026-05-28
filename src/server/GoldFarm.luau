-- ============================================================================
-- GoldFarm（金币农场 · 服务端）
-- Map.GoldFarmZone 长条区域内随机刷 Coin；离 Map.GoldFarmBase 越远金币越多
-- 靠近按 E 长按采集（HoldDuration 随档位略增，高收益更划算）
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GoldFarmUtil = require(ReplicatedStorage.Shared.GoldFarmUtil)
local PlayerEconomy = require(script.Parent.PlayerEconomy)

local GoldFarm = {}

local MAP_FOLDER = "Map"
local ACTIVE_FOLDER_NAME = "GoldFarmCoins"

local zonePart: BasePart?
local basePos: Vector3?
local farPos: Vector3?
local axisLength = 1
local coinTemplate: Instance?
local activeFolder: Folder?
local tiers: { GoldFarmUtil.TierConfig }
local cfg: typeof(GameConfig.GoldFarm)

local liveCoins: { [Instance]: boolean } = {}

local function getCfg()
	return GameConfig.GoldFarm
end

local function findInteractPart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		if inst.PrimaryPart then
			return inst.PrimaryPart
		end
		local part = inst:FindFirstChildWhichIsA("BasePart", true)
		if part then
			inst.PrimaryPart = part
		end
		return part
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

-- Toolbox Coin 常带脚本：写 leaderstats.Coins、IsInGroup 等，与 PlayerData.Gold 冲突，必须移除
local STRIP_CLASSES = {
	"Script",
	"LocalScript",
	"ModuleScript",
	"ProximityPrompt",
	"ClickDetector",
	"TouchTransmitter",
}

local function stripImportedCoinBehavior(root: Instance?)
	if not root then
		return
	end

	local removeList: { Instance } = {}
	for _, desc in root:GetDescendants() do
		if desc:IsA("ProximityPrompt") and desc.Name == "CollectCoinPrompt" then
			continue
		end
		for _, className in STRIP_CLASSES do
			if desc.ClassName == className then
				table.insert(removeList, desc)
				break
			end
		end
	end

	for _, inst in removeList do
		inst:Destroy()
	end
end

local BUILTIN_TEMPLATE_NAME = "CoinFarmTemplate"

local function shouldStripToolboxScript(desc: Instance): boolean
	if not desc:IsA("Script") and not desc:IsA("LocalScript") then
		return false
	end
	if desc.Name == "ExtraDataInitializer" then
		return true
	end
	local coinRoot = desc:FindFirstAncestor("Coin")
	return coinRoot ~= nil
end

-- 剥掉 Map 里 Toolbox Coin 的脚本（ExtraDataInitializer → IsInGroup 卡顿）
function GoldFarm.sanitizeMapToolboxScripts(map: Instance)
	local removed = 0
	for _, desc in map:GetDescendants() do
		if shouldStripToolboxScript(desc) then
			desc:Destroy()
			removed += 1
		end
	end
	if removed > 0 then
		print(("[GoldFarm] 已移除 Map 内 Toolbox 脚本 x%d（含 ExtraDataInitializer）"):format(removed))
	end
end

function GoldFarm.sanitizeCoinTemplates()
	local farmCfg = GameConfig.GoldFarm
	local toolboxName = farmCfg.MapCoinName or "Coin"
	local map = Workspace:FindFirstChild(MAP_FOLDER)
	if map then
		GoldFarm.sanitizeMapToolboxScripts(map)
	end

	if not map then
		return
	end

	local active = map:FindFirstChild(ACTIVE_FOLDER_NAME)
	local function tryStrip(inst: Instance?)
		if not inst or inst:IsA("Folder") then
			return
		end
		if active and inst:IsDescendantOf(active) then
			return
		end
		if inst.Name == toolboxName or inst.Name == BUILTIN_TEMPLATE_NAME then
			stripImportedCoinBehavior(inst)
		end
	end

	tryStrip(map:FindFirstChild(toolboxName))
	for _, desc in map:GetDescendants() do
		if desc.Name == toolboxName then
			tryStrip(desc)
		end
	end
end

local function ensureBuiltinCoinTemplate(): Instance
	local existing = ReplicatedStorage:FindFirstChild(BUILTIN_TEMPLATE_NAME)
	if existing and findInteractPart(existing) then
		return existing
	end

	local part = Instance.new("Part")
	part.Name = BUILTIN_TEMPLATE_NAME
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.4, 1.4, 1.4)
	part.Color = Color3.fromRGB(255, 217, 26)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.Parent = ReplicatedStorage
	return part
end

local function installMapScriptGuard(map: Instance)
	GoldFarm.sanitizeMapToolboxScripts(map)
	map.DescendantAdded:Connect(function(desc)
		if shouldStripToolboxScript(desc) then
			task.defer(function()
				if desc.Parent then
					desc:Destroy()
				end
			end)
		end
	end)
end

local function prepareCoinPhysics(coin: Instance)
	if coin:IsA("BasePart") then
		coin.Anchored = true
		coin.CanCollide = false
	end
	for _, desc in coin:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end
end

local function tintCoin(coin: Instance, color: Color3)
	for _, desc in coin:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
			desc.Color = color
		end
	end
	if coin:IsA("BasePart") then
		coin.Color = color
	end
end

local function ensureBillboard(part: BasePart, gold: number, tierName: string)
	local existing = part:FindFirstChild("GoldFarmLabel")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GoldFarmLabel"
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.TextStrokeTransparency = 0.4
	label.Text = ("[%s] +%d"):format(tierName, gold)
	label.Parent = billboard
end

local function isSpawnedFarmCoin(inst: Instance): boolean
	return inst.Name:match("^Coin_") ~= nil or inst:GetAttribute("GoldValue") ~= nil
end

local function isCoinTemplate(inst: Instance): boolean
	if inst:IsA("Folder") then
		return false
	end
	if inst.Name == ACTIVE_FOLDER_NAME then
		return false
	end
	if isSpawnedFarmCoin(inst) then
		return false
	end
	if activeFolder and inst:IsDescendantOf(activeFolder) then
		return false
	end
	return true
end

local function findMapCoinTemplate(map: Instance): Instance?
	local mapCoinName = cfg.MapCoinName or "Coin"
	local direct = map:FindFirstChild(mapCoinName)
	if direct and isCoinTemplate(direct) and findInteractPart(direct) then
		return direct
	end
	for _, desc in map:GetDescendants() do
		if desc.Name == mapCoinName and isCoinTemplate(desc) and findInteractPart(desc) then
			return desc
		end
	end
	return nil
end

local function findCoinTemplate(map: Instance): Instance?
	if cfg.PreferMapCoinTemplate ~= false then
		local mapCoin = findMapCoinTemplate(map)
		if mapCoin then
			return mapCoin
		end
	end

	local primaryName = cfg.CoinTemplateName or BUILTIN_TEMPLATE_NAME
	local fromStorage = ReplicatedStorage:FindFirstChild(primaryName)
	if fromStorage and isCoinTemplate(fromStorage) and findInteractPart(fromStorage) then
		return fromStorage
	end

	return ensureBuiltinCoinTemplate()
end

local function resolveBasePosition(map: Instance, zone: BasePart, endpoints: GoldFarmUtil.FarmEndpoints): Vector3
	local baseName = cfg.BasePartName or "GoldFarmBase"
	local basePart = map:FindFirstChild(baseName, true)
	if basePart and basePart:IsA("BasePart") then
		return basePart.Position
	end

	local princess = map:FindFirstChild("Princess", true)
	if princess then
		if princess:IsA("Model") and princess.PrimaryPart then
			return princess.PrimaryPart.Position
		end
		local part = findInteractPart(princess)
		if part then
			return part.Position
		end
	end

	return endpoints.near
end

local function isTooCloseToOtherCoins(position: Vector3): boolean
	local minDist = cfg.MinCoinSpacing or 5
	for coin in liveCoins do
		if coin.Parent then
			local part = findInteractPart(coin)
			if part and (part.Position - position).Magnitude < minDist then
				return true
			end
		end
	end
	return false
end

local function bindCollectPrompt(coin: Instance, prompt: ProximityPrompt, gold: number)
	prompt.Triggered:Connect(function(player: Player)
		if coin:GetAttribute("Collected") then
			return
		end
		if coin:GetAttribute("Reserved") and coin:GetAttribute("Reserved") ~= player.UserId then
			return
		end

		coin:SetAttribute("Collected", true)
		liveCoins[coin] = nil
		PlayerEconomy.addGold(player, gold)
		coin:Destroy()

		local delay = cfg.RespawnDelay or 4
		task.delay(delay, function()
			if zonePart and zonePart.Parent then
				GoldFarm.spawnOneCoin()
			end
		end)
	end)

	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		if coin:GetAttribute("Collected") then
			return
		end
		local reserved = coin:GetAttribute("Reserved")
		if typeof(reserved) == "number" and reserved ~= player.UserId then
			return
		end
		coin:SetAttribute("Reserved", player.UserId)
	end)

	prompt.PromptButtonHoldEnded:Connect(function(player: Player)
		if coin:GetAttribute("Reserved") == player.UserId then
			coin:SetAttribute("Reserved", nil)
		end
	end)
end

local function attachProximityPrompt(coin: Instance, gold: number, collectTime: number, tierName: string)
	local part = findInteractPart(coin)
	if not part then
		warn("[GoldFarm] 金币模型没有 Part，无法创建 ProximityPrompt:", coin:GetFullName())
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectCoinPrompt"
	prompt.ActionText = "采集"
	prompt.ObjectText = ("+%d 金币"):format(gold)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = cfg.InteractDistance or 10
	prompt.HoldDuration = collectTime
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part

	bindCollectPrompt(coin, prompt, gold)
	ensureBillboard(part, gold, tierName)
end

local function setCoinPartVisible(part: BasePart, visible: boolean)
	if visible then
		local saved = part:GetAttribute("GoldFarmSavedTransparency")
		part.Transparency = if typeof(saved) == "number" then saved else 0
		part.CanQuery = true
		part.CanTouch = true
	else
		if part:GetAttribute("GoldFarmSavedTransparency") == nil then
			part:SetAttribute("GoldFarmSavedTransparency", part.Transparency)
		end
		part.Transparency = 1
		part.CanQuery = false
		part.CanTouch = false
	end
	part.CanCollide = false
end

local function setCoinVisible(coin: Instance, visible: boolean)
	if coin:IsA("BasePart") then
		setCoinPartVisible(coin, visible)
	end
	for _, desc in coin:GetDescendants() do
		if desc:IsA("BasePart") then
			setCoinPartVisible(desc, visible)
		end
	end
end

local function hideTemplate(template: Instance)
	setCoinVisible(template, false)
	template:SetAttribute("IsGoldFarmCoinTemplate", true)
end

function GoldFarm.spawnOneCoin(): Instance?
	if not zonePart or not coinTemplate or not activeFolder or not basePos or not farPos then
		return nil
	end

	local maxCoins = cfg.MaxCoins or 36
	local count = 0
	for coin in liveCoins do
		if coin.Parent then
			count += 1
		else
			liveCoins[coin] = nil
		end
	end
	if count >= maxCoins then
		return nil
	end

	local ignoreRay: { Instance } = { zonePart }
	if activeFolder then
		table.insert(ignoreRay, activeFolder)
	end
	if coinTemplate then
		table.insert(ignoreRay, coinTemplate)
	end

	local position: Vector3? = nil
	for _ = 1, cfg.SpawnAttempts or 12 do
		local candidate = GoldFarmUtil.getRandomPointOnZone(zonePart, cfg.ZoneEdgeMargin or 3)
		candidate = GoldFarmUtil.liftToGround(candidate, cfg.CoinGroundLift or 1.2, ignoreRay)
		if not isTooCloseToOtherCoins(candidate) then
			position = candidate
			break
		end
	end
	if not position then
		return nil
	end

	local normalizedDist = GoldFarmUtil.getNormalizedDistance(position, basePos, farPos)
	local gold, baseCollectTime, tier = GoldFarmUtil.rollCoinReward(normalizedDist, tiers)
	local collectTime = baseCollectTime
		+ math.max(0, gold - tier.GoldMin) * (cfg.CollectTimePerBonusGold or 0)

	local coin = coinTemplate:Clone()
	coin.Name = ("Coin_%s_%d"):format(tier.Name, gold)
	stripImportedCoinBehavior(coin)
	setCoinVisible(coin, true)
	prepareCoinPhysics(coin)

	if tier.CoinColor then
		tintCoin(coin, tier.CoinColor)
	end

	local scale = (cfg.CoinScaleMin or 0.85) + normalizedDist * (cfg.CoinScaleMax or 1.35 - (cfg.CoinScaleMin or 0.85))
	if coin:IsA("Model") then
		pcall(function()
			coin:ScaleTo(scale)
		end)
	elseif coin:IsA("BasePart") then
		coin.Size = coin.Size * scale
	end

	if coin:IsA("Model") then
		coin:PivotTo(CFrame.new(position))
	else
		local part = findInteractPart(coin)
		if part then
			part.CFrame = CFrame.new(position)
		end
	end

	coin:SetAttribute("GoldValue", gold)
	coin:SetAttribute("CollectTime", collectTime)
	coin:SetAttribute("FarmTier", tier.Name)
	coin:SetAttribute("FarmDistance", normalizedDist)
	coin.Parent = activeFolder

	attachProximityPrompt(coin, gold, collectTime, tier.Name)
	liveCoins[coin] = true
	return coin
end

local function fillZone()
	local target = cfg.InitialCoinCount or cfg.MaxCoins or 36
	local spawned = 0
	local failed = 0
	for _ = 1, target do
		if GoldFarm.spawnOneCoin() then
			spawned += 1
		else
			failed += 1
		end
		if cfg.SpawnStagger and cfg.SpawnStagger > 0 then
			task.wait(cfg.SpawnStagger)
		end
	end
	if spawned == 0 then
		warn(
			("[GoldFarm] 未生成任何金币（尝试 %d 次）。请检查 Map.%s、Map.%s、模板 %s 是否有 BasePart"):format(
				target,
				cfg.ZonePartName or "GoldFarmZone",
				cfg.BasePartName or "GoldFarmBase",
				cfg.CoinTemplateName or "Coin"
			)
		)
	else
		print(("[GoldFarm] 已生成 %d 枚金币（失败 %d）"):format(spawned, failed))
		local sample = activeFolder and activeFolder:FindFirstChildWhichIsA("Model", true)
			or activeFolder and activeFolder:FindFirstChildWhichIsA("BasePart", true)
		if sample then
			local p = findInteractPart(sample)
			if p then
				print(("[GoldFarm] 示例位置（去这里找）: %.0f, %.0f, %.0f"):format(p.Position.X, p.Position.Y, p.Position.Z))
			end
		end
	end
end

local function bootstrapGoldFarm()
	local map = Workspace:WaitForChild(MAP_FOLDER, 60)
	if not map then
		warn("[GoldFarm] 未找到 Workspace.Map（60s 超时）")
		return
	end

	installMapScriptGuard(map)

	local zoneName = cfg.ZonePartName or "GoldFarmZone"
	local zone = map:FindFirstChild(zoneName, true)
	if not zone or not zone:IsA("BasePart") then
		warn(("[GoldFarm] 请在 Map 下放置 Part「%s」作为长条刷币区域"):format(zoneName))
		return
	end
	zonePart = zone

	coinTemplate = findCoinTemplate(map)
	if not coinTemplate then
		warn("[GoldFarm] 无法获取金币模板")
		return
	end
	if not findInteractPart(coinTemplate) then
		warn("[GoldFarm] 金币模板内没有 Part:", coinTemplate:GetFullName())
		return
	end

	print("[GoldFarm] 使用模板:", coinTemplate:GetFullName())
	stripImportedCoinBehavior(coinTemplate)
	if coinTemplate:IsDescendantOf(map) then
		hideTemplate(coinTemplate)
	end

	local endpoints = GoldFarmUtil.getZoneEndpoints(zonePart)
	axisLength = math.max(endpoints.axisLength, 1)
	local base = resolveBasePosition(map, zonePart, endpoints)
	basePos, farPos = GoldFarmUtil.pickBaseEndpoint(endpoints, base)

	activeFolder = map:FindFirstChild(ACTIVE_FOLDER_NAME) :: Folder?
	if not activeFolder then
		activeFolder = Instance.new("Folder")
		activeFolder.Name = ACTIVE_FOLDER_NAME
		activeFolder.Parent = map
	else
		for _, child in activeFolder:GetChildren() do
			stripImportedCoinBehavior(child)
		end
	end

	print(
		("[GoldFarm] 已启动：区域 %s 中心 (%.0f, %.0f, %.0f)，轴长 %.0f"):format(
			zonePart:GetFullName(),
			zonePart.Position.X,
			zonePart.Position.Y,
			zonePart.Position.Z,
			axisLength
		)
	)

	fillZone()
end

function GoldFarm.start()
	cfg = getCfg()
	if not cfg then
		warn("[GoldFarm] GameConfig 缺少 GoldFarm 配置")
		return
	end
	tiers = cfg.Tiers
	if not tiers or #tiers == 0 then
		warn("[GoldFarm] GameConfig.GoldFarm.Tiers 为空")
		return
	end

	print("[GoldFarm] 正在启动…")

	local ok, err = xpcall(bootstrapGoldFarm, debug.traceback)
	if not ok then
		warn("[GoldFarm] 启动失败:\n", err)
	end

	task.spawn(function()
		local existing = Workspace:FindFirstChild(MAP_FOLDER)
		if existing then
			installMapScriptGuard(existing)
		end
		Workspace.ChildAdded:Connect(function(child)
			if child.Name == MAP_FOLDER then
				installMapScriptGuard(child)
				GoldFarm.sanitizeCoinTemplates()
			end
		end)
	end)
end

return GoldFarm
