-- ============================================================================
-- WeaponUtil（武器 Tool 查找 / 发放前处理）
-- ============================================================================

local WeaponUtil = {}

export type ToolFolder = Folder | Model

local function normalizeWeaponName(name: string): string
	return string.lower((name:gsub("[%s_%-]+", "")))
end

function WeaponUtil.listTools(folder: Instance): { Tool }
	local tools: { Tool } = {}
	for _, desc in folder:GetDescendants() do
		if desc:IsA("Tool") then
			table.insert(tools, desc)
		end
	end
	return tools
end

local function toolMatchesName(tool: Tool, toolName: string, normalizedTarget: string): boolean
	if tool.Name == toolName then
		return true
	end
	return normalizeWeaponName(tool.Name) == normalizedTarget
end

local function findToolInContainer(container: Instance, toolName: string, normalizedTarget: string): Tool?
	local direct = container:FindFirstChild(toolName)
	if direct and direct:IsA("Tool") then
		return direct
	end

	for _, desc in container:GetDescendants() do
		if desc:IsA("Tool") and toolMatchesName(desc, toolName, normalizedTarget) then
			return desc
		end
	end

	-- Toolbox 常导出为 Model（名 BanHammer），内层才是 Tool
	for _, child in container:GetChildren() do
		if child:IsA("Model") and normalizeWeaponName(child.Name) == normalizedTarget then
			local nested = child:FindFirstChildWhichIsA("Tool", true)
			if nested then
				return nested
			end
		end
	end

	return nil
end

function WeaponUtil.findTool(folder: Instance?, toolName: string, extraNames: { string }?): Tool?
	if not folder or toolName == "" then
		return nil
	end

	local normalizedTarget = normalizeWeaponName(toolName)
	local found = findToolInContainer(folder, toolName, normalizedTarget)
	if found then
		return found
	end

	if extraNames then
		for _, alias in extraNames do
			if alias ~= toolName then
				found = findToolInContainer(folder, alias, normalizeWeaponName(alias))
				if found then
					return found
				end
			end
		end
	end

	return nil
end

function WeaponUtil.namesMatch(a: string, b: string): boolean
	return normalizeWeaponName(a) == normalizeWeaponName(b)
end

function WeaponUtil.ensureHandle(tool: Tool): boolean
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		tool.RequiresHandle = true
		handle.Anchored = false
		handle.CanCollide = false
		return true
	end

	local part = tool:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return false
	end

	part.Name = "Handle"
	tool.RequiresHandle = true
	part.Anchored = false
	part.CanCollide = false
	return true
end

return WeaponUtil
