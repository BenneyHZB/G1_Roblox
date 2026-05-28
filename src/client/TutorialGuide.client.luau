-- ============================================================================
-- TutorialGuide（开局保护公主 UI + 第 1 波后的新手指引）
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer
local cfg = GameConfig.Tutorial

local INTRO_ATTR = "TutorialIntroDone"
local GUIDE_ATTR = "TutorialGuideDone"

local introRoot: Frame?
local introTexts: { TextLabel } = {}
local guideFrame: Frame?
local introVisible = false
local guideVisible = false

local markRemote: RemoteEvent?

local function getMarkRemote(): RemoteEvent?
	if markRemote then
		return markRemote
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return nil
	end
	markRemote = remotes:FindFirstChild("TutorialMark") :: RemoteEvent?
	return markRemote
end

local function markDone(markId: string)
	local remote = getMarkRemote()
	if remote then
		remote:FireServer(markId)
	end
	if markId == "Intro" then
		player:SetAttribute(INTRO_ATTR, true)
	elseif markId == "Guide" then
		player:SetAttribute(GUIDE_ATTR, true)
	end
end

local function tweenTextFade(labels: { TextLabel }, textTransparency: number, duration: number, onDone: (() -> ())?)
	for _, label in labels do
		TweenService:Create(label, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = textTransparency,
			TextStrokeTransparency = if textTransparency >= 1 then 1 else 0.35,
		}):Play()
	end
	if onDone then
		task.delay(duration, onDone)
	end
end

local function hideIntro()
	if not introRoot or not introVisible then
		return
	end
	introVisible = false
	markDone("Intro")

	tweenTextFade(introTexts, 1, 0.35, function()
		if introRoot then
			introRoot.Visible = false
		end
	end)
end

local function showGuide()
	if guideVisible or player:GetAttribute(GUIDE_ATTR) == true then
		return
	end
	if not guideFrame then
		return
	end

	guideVisible = true
	guideFrame.Visible = true
	guideFrame.BackgroundTransparency = 0.55
end

local function hideGuide()
	if not guideFrame or not guideVisible then
		return
	end
	guideVisible = false
	markDone("Guide")
	guideFrame.Visible = false
end

local function showIntro()
	if introVisible or player:GetAttribute(INTRO_ATTR) == true then
		return
	end
	if not introRoot then
		return
	end

	introVisible = true
	introRoot.Visible = true
	for _, label in introTexts do
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.35
	end
end

local function isFirstWaveCleared(waveNumber: number, wavePhase: string, princessHp: number): boolean
	return princessHp > 0 and wavePhase == "Intermission" and waveNumber >= 1
end

local function styleIntroLabel(label: TextLabel, textSize: number, color: Color3)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
end

local function createIntroOverlay(parent: ScreenGui)
	-- 全屏容器不挡鼠标/视角，仅顶部显示文字
	local root = Instance.new("Frame")
	root.Name = "IntroBanner"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Visible = false
	root.Active = false
	root.ZIndex = 10
	root.Parent = parent
	introRoot = root

	local banner = Instance.new("Frame")
	banner.Name = "TopBanner"
	banner.Size = UDim2.new(0.9, 0, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.Position = UDim2.new(0.5, 0, 0, 36)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	banner.Active = false
	banner.ZIndex = 11
	banner.Parent = root

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 10)
	bannerCorner.Parent = banner

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = banner

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = banner

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 0)
	title.LayoutOrder = 1
	styleIntroLabel(title, 52, Color3.fromRGB(255, 232, 120))
	title.Font = Enum.Font.GothamBlack
	title.Text = cfg.IntroTitle or "保护公主"
	title.Parent = banner
	table.insert(introTexts, title)

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 0)
	subtitle.LayoutOrder = 2
	styleIntroLabel(subtitle, 20, Color3.fromRGB(245, 248, 255))
	subtitle.Text = cfg.IntroSubtitle or ""
	subtitle.Parent = banner
	table.insert(introTexts, subtitle)

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0, 0)
	hint.LayoutOrder = 3
	styleIntroLabel(hint, 15, Color3.fromRGB(200, 215, 235))
	hint.Font = Enum.Font.GothamMedium
	hint.Text = cfg.IntroHint or ""
	hint.Parent = banner
	table.insert(introTexts, hint)
end

local function createGuidePanel(parent: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "GuidePanel"
	frame.Size = UDim2.fromOffset(400, 420)
	frame.Position = UDim2.new(1, -416, 0.5, -210)
	frame.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
	frame.BackgroundTransparency = 0.55
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 8
	frame.Parent = parent
	guideFrame = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 190, 255)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Position = UDim2.fromOffset(12, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(200, 230, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = cfg.GuideTitle or "新手指引"
	title.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Name = "StepList"
	list.Size = UDim2.new(1, -24, 1, -100)
	list.Position = UDim2.fromOffset(12, 50)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, step in cfg.GuideSteps do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundColor3 = Color3.fromRGB(48, 52, 64)
		row.BackgroundTransparency = 0.35
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Parent = list

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingTop = UDim.new(0, 8)
		rowPadding.PaddingBottom = UDim.new(0, 8)
		rowPadding.PaddingLeft = UDim.new(0, 10)
		rowPadding.PaddingRight = UDim.new(0, 10)
		rowPadding.Parent = row

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.Padding = UDim.new(0, 4)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row

		local stepTitle = Instance.new("TextLabel")
		stepTitle.Size = UDim2.new(1, 0, 0, 22)
		stepTitle.BackgroundTransparency = 1
		stepTitle.Font = Enum.Font.GothamBold
		stepTitle.TextSize = 16
		stepTitle.TextColor3 = Color3.fromRGB(255, 235, 160)
		stepTitle.TextXAlignment = Enum.TextXAlignment.Left
		stepTitle.Text = step.Title
		stepTitle.AutomaticSize = Enum.AutomaticSize.Y
		stepTitle.TextWrapped = true
		stepTitle.LayoutOrder = 1
		stepTitle.Parent = row

		local stepBody = Instance.new("TextLabel")
		stepBody.Size = UDim2.new(1, 0, 0, 0)
		stepBody.BackgroundTransparency = 1
		stepBody.Font = Enum.Font.Gotham
		stepBody.TextSize = 14
		stepBody.TextColor3 = Color3.fromRGB(235, 238, 248)
		stepBody.TextXAlignment = Enum.TextXAlignment.Left
		stepBody.TextYAlignment = Enum.TextYAlignment.Top
		stepBody.TextWrapped = true
		stepBody.Text = step.Body
		stepBody.AutomaticSize = Enum.AutomaticSize.Y
		stepBody.LayoutOrder = 2
		stepBody.Parent = row
	end

	local okButton = Instance.new("TextButton")
	okButton.Size = UDim2.new(1, -24, 0, 40)
	okButton.Position = UDim2.new(0, 12, 1, -48)
	okButton.BackgroundColor3 = Color3.fromRGB(70, 130, 210)
	okButton.Font = Enum.Font.GothamBold
	okButton.TextSize = 18
	okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	okButton.Text = "知道了"
	okButton.Parent = frame

	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 8)
	okCorner.Parent = okButton

	okButton.MouseButton1Click:Connect(hideGuide)
end

local function bindGameState()
	local gameState = ReplicatedStorage:WaitForChild("GameState", 60)
	if not gameState then
		return
	end

	local waveNumber = gameState:WaitForChild("WaveNumber") :: IntValue
	local wavePhase = gameState:WaitForChild("WavePhase") :: StringValue
	local princessHp = gameState:WaitForChild("PrincessHp") :: IntValue

	local function evaluate()
		if princessHp.Value <= 0 then
			hideIntro()
			return
		end

		if isFirstWaveCleared(waveNumber.Value, wavePhase.Value, princessHp.Value) then
			hideIntro()
			if player:GetAttribute(GUIDE_ATTR) ~= true then
				task.delay(0.45, showGuide)
			end
			return
		end

		if player:GetAttribute(INTRO_ATTR) ~= true then
			showIntro()
		end
	end

	evaluate()
	waveNumber.Changed:Connect(evaluate)
	wavePhase.Changed:Connect(evaluate)
	princessHp.Changed:Connect(evaluate)
end

local function init()
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TutorialGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	createIntroOverlay(screenGui)
	createGuidePanel(screenGui)

	if player:GetAttribute(INTRO_ATTR) ~= true then
		task.defer(showIntro)
	end

	bindGameState()
end

init()
