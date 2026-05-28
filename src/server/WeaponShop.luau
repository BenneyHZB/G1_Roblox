-- ============================================================================
-- WeaponShop（武器店 · 服务端）
-- Map.WeaponShop · 武器模板 ReplicatedStorage.Weapons；达标奖牌可领取，不消耗奖牌
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local WeaponUtil = require(ReplicatedStorage.Shared.WeaponUtil)
local PlayerTrophies = require(script.Parent.PlayerTrophies)
local PlayerCombat = require(script.Parent.PlayerCombat)

local WeaponShop = {}

local MAP_FOLDER = "Map"
local purchaseRemote: RemoteFunction

local function getCfg()
	return GameConfig.WeaponShop
end

local function getItem(itemId: string)
	local cfg = getCfg()
	return cfg and cfg.Items and cfg.Items[itemId]
end

local function findShopPart(shop: Instance): BasePart?
	if shop:IsA("BasePart") then
		return shop
	end
	if shop:IsA("Model") then
		if shop.PrimaryPart then
			return shop.PrimaryPart
		end
		local part = shop:FindFirstChildWhichIsA("BasePart", true)
		if part then
			shop.PrimaryPart = part
			return part
		end
	end
	return shop:FindFirstChildWhichIsA("BasePart", true)
end

local function getWeaponsFolder(): Folder?
	local folderName = getCfg().WeaponsFolderName or "Weapons"
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if folder and folder:IsA("Folder") then
		return folder
	end

	local map = Workspace:FindFirstChild(MAP_FOLDER)
	if map then
		local legacy = map:FindFirstChild(folderName)
		if legacy and legacy:IsA("Folder") then
			return legacy
		end
	end

	return nil
end

local function getTemplateAliases(item): { string }
	local aliases: { string } = {}
	if typeof(item.TemplateAliases) == "table" then
		for _, name in item.TemplateAliases do
			if typeof(name) == "string" and name ~= "" then
				table.insert(aliases, name)
			end
		end
	end
	return aliases
end

local function findWeaponTemplate(item): Tool?
	local toolName = item.WeaponToolName
	local aliases = getTemplateAliases(item)
	local weaponsFolder = getWeaponsFolder()
	local fromFolder = WeaponUtil.findTool(weaponsFolder, toolName, aliases)
	if fromFolder then
		return fromFolder
	end

	return WeaponUtil.findTool(ReplicatedStorage, toolName, aliases)
end

local function listWeaponToolNames(): string
	local folder = getWeaponsFolder()
	if not folder then
		return "（无 Weapons 文件夹）"
	end
	local names: { string } = {}
	for _, tool in WeaponUtil.listTools(folder) do
		table.insert(names, tool.Name)
	end
	if #names == 0 then
		for _, child in folder:GetChildren() do
			table.insert(names, child.Name .. (if child:IsA("Tool") then "" else (" [" .. child.ClassName .. "]")))
		end
	end
	return if #names > 0 then table.concat(names, "、") else "（空）"
end

local function validateWeaponCatalog()
	local folder = getWeaponsFolder()
	if not folder then
		warn("[WeaponShop] 未找到 ReplicatedStorage.Weapons 文件夹")
		return
	end

	print("[WeaponShop] —— ReplicatedStorage.Weapons 内的 Tool ——")
	for _, tool in WeaponUtil.listTools(folder) do
		print(("  · %s"):format(tool:GetFullName()))
	end

	local cfg = getCfg()
	if not cfg or not cfg.Items then
		return
	end

	print("[WeaponShop] —— 与 GameConfig 对照（名称须完全一致）——")
	for itemId, item in cfg.Items do
		local template = findWeaponTemplate(item)
		if template then
			print(("  ✓ %s → 配置「%s」实际模板「%s」"):format(item.DisplayName, item.WeaponToolName, template.Name))
		else
			warn(
				("  ✗ %s 需要「%s」（或 BanHammer 等等价名），当前 Weapons 内: %s"):format(
					item.DisplayName,
					item.WeaponToolName,
					listWeaponToolNames()
				)
			)
		end
	end
end

local function playerHasTool(player: Player, toolName: string): boolean
	local function containerHas(container: Instance?): boolean
		if not container then
			return false
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and WeaponUtil.namesMatch(child.Name, toolName) then
				return true
			end
		end
		return false
	end

	return containerHas(player:FindFirstChild("Backpack")) or containerHas(player.Character)
end

local function ownsWeapon(player: Player, item): boolean
	return playerHasTool(player, item.WeaponToolName)
end

local function grantWeapon(player: Player, item): (boolean, string)
	local template = findWeaponTemplate(item)
	if not template then
		return false,
			("未找到「%s」。ReplicatedStorage.%s 里现有: %s（磁盘文件 BanHammer.rbxm 可以，会自动匹配）"):format(
				item.WeaponToolName,
				getCfg().WeaponsFolderName or "Weapons",
				listWeaponToolNames()
			)
	end

	if playerHasTool(player, item.WeaponToolName) then
		player:SetAttribute(item.OwnershipAttribute, true)
		return false, "背包里已有该武器"
	end

	local tool = template:Clone()
	tool.Name = item.WeaponToolName
	local okPrepare, prepareErr = PlayerCombat.prepareGrantedTool(tool)
	if not okPrepare then
		tool:Destroy()
		return false, prepareErr or "武器无法装备"
	end

	local backpack = player:WaitForChild("Backpack")
	tool.Parent = backpack
	player:SetAttribute(item.OwnershipAttribute, true)
	print(("[WeaponShop] %s 领取 %s → Backpack"):format(player.Name, item.WeaponToolName))
	return true, ("已获得：%s（在背包中点击装备）"):format(item.DisplayName)
end

function WeaponShop.purchase(player: Player, itemId: string): (boolean, string)
	local item = getItem(itemId)
	if not item then
		return false, "未知商品"
	end

	if ownsWeapon(player, item) then
		return false, "你已拥有该武器"
	end

	if not PlayerTrophies.meetsThreshold(player, item.TrophyRequired) then
		return false,
			("需要 %d 奖牌（当前 %d，达标后领取不消耗）"):format(item.TrophyRequired, PlayerTrophies.get(player))
	end

	return grantWeapon(player, item)
end

local function clearPlayerTools(player: Player)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end

	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
end

function WeaponShop.resetPlayer(player: Player)
	local cfg = getCfg()
	if cfg and cfg.Items then
		for _, item in cfg.Items do
			player:SetAttribute(item.OwnershipAttribute, false)
		end
	end
	clearPlayerTools(player)
end

function WeaponShop.restoreOwnedWeapons(player: Player)
	local cfg = getCfg()
	if not cfg or not cfg.Items then
		return
	end

	for _, item in cfg.Items do
		if player:GetAttribute(item.OwnershipAttribute) == true and not playerHasTool(player, item.WeaponToolName) then
			grantWeapon(player, item)
		end
	end
end

local function setupPlayer(player: Player)
	for _, item in getCfg().Items do
		if typeof(player:GetAttribute(item.OwnershipAttribute)) ~= "boolean" then
			player:SetAttribute(item.OwnershipAttribute, false)
		end
	end
	WeaponShop.restoreOwnedWeapons(player)
end

local function ensureProximityPrompt(shop: Instance): ProximityPrompt?
	local cfg = getCfg()
	local existing = shop:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existing then
		existing.ObjectText = "武器店"
		existing.ActionText = "打开"
		existing.MaxActivationDistance = cfg.InteractDistance or GameConfig.ShopInteractDistance
		existing.HoldDuration = 0
		existing.RequiresLineOfSight = false
		return existing
	end

	local part = findShopPart(shop)
	if not part then
		warn("[WeaponShop] 找不到 Part，无法创建 ProximityPrompt:", shop:GetFullName())
		return nil
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WeaponShopPrompt"
	prompt.ObjectText = "武器店"
	prompt.ActionText = "打开"
	prompt.MaxActivationDistance = cfg.InteractDistance or GameConfig.ShopInteractDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function findWeaponShop(map: Instance): Instance?
	local cfg = getCfg()
	local name = cfg.ShopModelName or "WeaponShop"
	local shop = map:FindFirstChild(name, true)
	if shop then
		return shop
	end
	return map:FindFirstChild("武器店", true)
end

local function onPurchase(player: Player, itemId: string): (boolean, string)
	if typeof(itemId) ~= "string" then
		return false, "无效请求"
	end
	return WeaponShop.purchase(player, itemId)
end

function WeaponShop.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	purchaseRemote = remotes:FindFirstChild("WeaponShopPurchase") :: RemoteFunction?
	if not purchaseRemote then
		purchaseRemote = Instance.new("RemoteFunction")
		purchaseRemote.Name = "WeaponShopPurchase"
		purchaseRemote.Parent = remotes
	end
	purchaseRemote.OnServerInvoke = onPurchase

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerAdded:Connect(setupPlayer)

	task.spawn(function()
		local map = Workspace:WaitForChild(MAP_FOLDER, 30)
		if not map then
			warn("[WeaponShop] 未找到 Workspace.Map")
			return
		end

		local shop = findWeaponShop(map)
		if not shop then
			warn(
				("[WeaponShop] 未找到 Map.%s（或「武器店」），请在 Studio 导入武器店模型"):format(getCfg().ShopModelName or "WeaponShop")
			)
			return
		end

		shop:SetAttribute("IsWeaponShop", true)
		local prompt = ensureProximityPrompt(shop)
		if prompt then
			print("[WeaponShop] 已绑定：", shop:GetFullName())
		end
		validateWeaponCatalog()
	end)
end

return WeaponShop
