-- ============================================================================
-- MapLocationLabels（地点头顶标识）
-- 训练师 / 武器店 / 强化店 / 金币农场基地 等
-- ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local MAP_FOLDER = "Map"
local LABEL_NAME = "MapLocationLabel"

local function findAnchorPart(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		if target.PrimaryPart then
			return target.PrimaryPart
		end
		local part = target:FindFirstChildWhichIsA("BasePart", true)
		if part then
			target.PrimaryPart = part
			return part
		end
	end
	return target:FindFirstChildWhichIsA("BasePart", true)
end

local function findMapTarget(map: Instance, location): Instance?
	local direct = map:FindFirstChild(location.TargetName, true)
	if direct then
		return direct
	end
	if location.AltNames then
		for _, altName in location.AltNames do
			local alt = map:FindFirstChild(altName, true)
			if alt then
				return alt
			end
		end
	end
	return nil
end

local function attachBillboard(anchor: BasePart, location, offset: Vector3)
	if anchor:FindFirstChild(LABEL_NAME) then
		return
	end

	local accent = location.AccentColor or Color3.fromRGB(255, 220, 120)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = LABEL_NAME
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = offset
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	billboard.Parent = anchor

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 8)
	bgCorner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.5
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -12, 0, 26)
	title.Position = UDim2.fromOffset(6, 4)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = accent
	title.TextStrokeTransparency = 0.5
	title.Text = location.Title
	title.Parent = bg

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -12, 0, 20)
	subtitle.Position = UDim2.fromOffset(6, 30)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 13
	subtitle.TextColor3 = Color3.fromRGB(235, 238, 245)
	subtitle.TextStrokeTransparency = 0.55
	subtitle.Text = location.Subtitle or ""
	subtitle.Parent = bg
end

local function tryBindLocation(map: Instance, location)
	local target = findMapTarget(map, location)
	if not target then
		return
	end

	local anchor = findAnchorPart(target)
	if not anchor then
		return
	end

	local offset = GameConfig.MapLabels.StudsOffset or Vector3.new(0, 4, 0)
	if typeof(location.StudsOffset) == "Vector3" then
		offset = location.StudsOffset
	end

	attachBillboard(anchor, location, offset)
end

local function bindAll(map: Instance)
	local cfg = GameConfig.MapLabels
	if not cfg or not cfg.Locations then
		return
	end

	for _, location in cfg.Locations do
		tryBindLocation(map, location)
	end
end

local function init()
	local map = Workspace:WaitForChild(MAP_FOLDER, 60)
	if not map then
		return
	end

	bindAll(map)

	map.DescendantAdded:Connect(function(desc)
		if not GameConfig.MapLabels or not GameConfig.MapLabels.Locations then
			return
		end
		for _, location in GameConfig.MapLabels.Locations do
			if desc.Name == location.TargetName then
				tryBindLocation(map, location)
			elseif location.AltNames then
				for _, altName in location.AltNames do
					if desc.Name == altName then
						tryBindLocation(map, location)
						break
					end
				end
			end
		end
	end)
end

task.spawn(init)
