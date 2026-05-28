-- ============================================================================
-- GoldFarmUtil（金币农场 · 距离 / 档位计算）
-- ============================================================================

local GoldFarmUtil = {}

export type TierConfig = {
	Name: string,
	MaxDistance: number,
	GoldMin: number,
	GoldMax: number,
	CollectTime: number,
	CoinColor: Color3?,
}

export type FarmEndpoints = {
	near: Vector3,
	far: Vector3,
	axisLength: number,
}

function GoldFarmUtil.getZoneEndpoints(zone: BasePart): FarmEndpoints
	local cf = zone.CFrame
	local half = zone.Size * 0.5
	if zone.Size.Z >= zone.Size.X then
		return {
			near = cf:PointToWorldSpace(Vector3.new(0, 0, -half.Z)),
			far = cf:PointToWorldSpace(Vector3.new(0, 0, half.Z)),
			axisLength = zone.Size.Z,
		}
	end
	return {
		near = cf:PointToWorldSpace(Vector3.new(-half.X, 0, 0)),
		far = cf:PointToWorldSpace(Vector3.new(half.X, 0, 0)),
		axisLength = zone.Size.X,
	}
end

function GoldFarmUtil.pickBaseEndpoint(endpoints: FarmEndpoints, basePos: Vector3): (Vector3, Vector3)
	local distNear = (endpoints.near - basePos).Magnitude
	local distFar = (endpoints.far - basePos).Magnitude
	if distNear <= distFar then
		return endpoints.near, endpoints.far
	end
	return endpoints.far, endpoints.near
end

-- 0 = 基地端（GoldFarmBase 一侧），1 = 区域远端
function GoldFarmUtil.getNormalizedDistance(worldPos: Vector3, basePos: Vector3, farPos: Vector3): number
	local axis = farPos - basePos
	local lenSq = axis:Dot(axis)
	if lenSq < 1 then
		return 0
	end
	local along = (worldPos - basePos):Dot(axis) / lenSq
	return math.clamp(along, 0, 1)
end

function GoldFarmUtil.getTierForDistance(normalizedDist: number, tiers: { TierConfig }): TierConfig
	for _, tier in tiers do
		if normalizedDist <= tier.MaxDistance then
			return tier
		end
	end
	return tiers[#tiers]
end

function GoldFarmUtil.rollCoinReward(normalizedDist: number, tiers: { TierConfig }): (number, number, TierConfig)
	local tier = GoldFarmUtil.getTierForDistance(normalizedDist, tiers)
	local span = tier.GoldMax - tier.GoldMin
	local bias = math.clamp(normalizedDist / math.max(tier.MaxDistance, 0.01), 0, 1)
	local gold = tier.GoldMin + math.floor(span * (0.35 + bias * 0.65) + math.random() * math.max(1, span * 0.25))
	gold = math.clamp(gold, tier.GoldMin, tier.GoldMax)
	return gold, tier.CollectTime, tier
end

function GoldFarmUtil.getRandomPointOnZone(zone: BasePart, margin: number): Vector3
	local cf = zone.CFrame
	local half = zone.Size * 0.5
	local insetX = math.max(half.X - margin, 0.5)
	local insetZ = math.max(half.Z - margin, 0.5)
	local localX = (math.random() * 2 - 1) * insetX
	local localZ = (math.random() * 2 - 1) * insetZ
	local topY = half.Y + 0.35
	return cf:PointToWorldSpace(Vector3.new(localX, topY, localZ))
end

function GoldFarmUtil.liftToGround(position: Vector3, lift: number, ignoreList: { Instance }?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or {}
	local hit = workspace:Raycast(position + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
	if hit then
		return hit.Position + Vector3.new(0, lift, 0)
	end
	return position
end

return GoldFarmUtil
