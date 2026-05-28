-- ============================================================================
-- EnhanceShop（强化商店 · 地图绑定）
-- 模型路径：Workspace.Map.EnhanceShop（assets/map/EnhanceShop.rbxm）
-- 若无 ProximityPrompt 则自动在模型主 Part 上创建
-- ============================================================================

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local EnhanceShop = {}

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

local function ensureProximityPrompt(shop: Instance): ProximityPrompt?
	local existing = shop:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existing then
		existing.ObjectText = "属性强化"
		existing.ActionText = "打开商店"
		existing.MaxActivationDistance = GameConfig.ShopInteractDistance
		existing.HoldDuration = 0
		existing.RequiresLineOfSight = false
		return existing
	end

	local part = findShopPart(shop)
	if not part then
		warn("[EnhanceShop] 找不到 Part，无法创建 ProximityPrompt：", shop:GetFullName())
		return nil
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnhanceShopPrompt"
	prompt.ObjectText = "属性强化"
	prompt.ActionText = "打开商店"
	prompt.MaxActivationDistance = GameConfig.ShopInteractDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	return prompt
end

function EnhanceShop.start()
	task.spawn(function()
		local map = Workspace:WaitForChild("Map", 30)
		if not map then
			warn("[EnhanceShop] 未找到 Workspace.Map")
			return
		end

		local shop = map:WaitForChild("EnhanceShop", 30)
		if not shop then
			warn("[EnhanceShop] 未找到 Map.EnhanceShop，请确认 assets/map/EnhanceShop.rbxm 已同步")
			return
		end

		shop:SetAttribute("IsEnhanceShop", true)
		local prompt = ensureProximityPrompt(shop)
		if prompt then
			print("[EnhanceShop] 已绑定：", shop:GetFullName())
		end
	end)
end

return EnhanceShop
