local TapAndHoldModule = {}

-- gameplay tuning values
TapAndHoldModule.Settings = {
	JumpPowerMultiplier = 45,
	MaxJumpDistance = 50,
	Gravity = 196.2,

	PerfectTolerance = 1.2,
	MinDistance = 8,
	MaxDistance = 22,
	MaxVisiblePlatforms = 4,

	Colors = {
		Normal  = Color3.fromHex("fb7185"),
		Bonus   = Color3.fromHex("a3e635"),
		Penalty = Color3.fromHex("4c0519"),
		Center  = Color3.fromHex("ffffff")
	}
}

-- weighted platform model pool
local PLATFORM_WEIGHTS = {
	{ Name = "tapsuelo1", Weight = 32.5 },
	{ Name = "tapsuelo2", Weight = 32.5 },
	{ Name = "tapsuelo3", Weight = 17.5 },
	{ Name = "tapsuelo4", Weight = 17.5 },
}

-- picks a platform model and event type (normal/bonus/penalty) for the next platform
function TapAndHoldModule.PickNextPlatformData()
	local roll = math.random() * 100
	local accumulated = 0
	local selectedModel = "tapsuelo1"

	for _, p in ipairs(PLATFORM_WEIGHTS) do
		accumulated = accumulated + p.Weight
		if roll <= accumulated then
			selectedModel = p.Name
			break
		end
	end

	local eventRoll = math.random(1, 100)
	local eventType = "Normal"
	local scoreModifier = 0
	local color = TapAndHoldModule.Settings.Colors.Normal

	if eventRoll <= 10 then
		eventType = "Bonus"
		scoreModifier = 5
		color = TapAndHoldModule.Settings.Colors.Bonus
	elseif eventRoll > 90 then
		eventType = "Penalty"
		scoreModifier = -1
		color = TapAndHoldModule.Settings.Colors.Penalty
	end

	return {
		ModelName = selectedModel,
		Type = eventType,
		Value = scoreModifier,
		Color = color
	}
end

-- converts hold duration into a forward and upward velocity for the jump arc
function TapAndHoldModule.CalculateJumpVelocity(holdTime)
	local power = math.min(holdTime * TapAndHoldModule.Settings.JumpPowerMultiplier, TapAndHoldModule.Settings.MaxJumpDistance)

	local velocityUp = 35 + (power * 0.2)
	local velocityForward = power * 2.2

	return velocityForward, velocityUp
end

-- returns whether the character landed on the platform and whether it was a perfect center landing
function TapAndHoldModule.CheckLanding(characterPos, platform)
	local pSize = platform.Size
	local pPos = platform.Position

	local diffX = characterPos.X - pPos.X
	local diffZ = characterPos.Z - pPos.Z
	local distanceToCenter = math.sqrt(diffX^2 + diffZ^2)

	local hitX = math.abs(diffX) < (pSize.X / 2 + 0.3)
	local hitZ = math.abs(diffZ) < (pSize.Z / 2 + 0.3)
	local isInside = hitX and hitZ

	local isPerfect = isInside and (distanceToCenter < TapAndHoldModule.Settings.PerfectTolerance)

	return isInside, isPerfect
end

-- applies a rose gradient surface gui to a platform part with an optional custom base color
function TapAndHoldModule.ApplyRoseGradient(platform, customColor)
	local surfaceGui = platform:FindFirstChild("TapUI") or Instance.new("SurfaceGui")
	surfaceGui.Name = "TapUI"
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.LightInfluence = 0
	surfaceGui.ZOffset = 2
	surfaceGui.Parent = platform

	local frame = Instance.new("Frame", surfaceGui)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.new(1, 1, 1)

	local gradient = Instance.new("UIGradient", frame)
	local baseColor = customColor or TapAndHoldModule.Settings.Colors.Normal

	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, baseColor),
		ColorSequenceKeypoint.new(1, Color3.fromHex("e11d48"))
	})
	gradient.Rotation = 45

	local centerDot = Instance.new("Frame", frame)
	centerDot.Size = UDim2.fromScale(0.1, 0.1)
	centerDot.Position = UDim2.fromScale(0.5, 0.5)
	centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	centerDot.BackgroundColor3 = Color3.new(1, 1, 1)
	centerDot.BackgroundTransparency = 0.6
	local corner = Instance.new("UICorner", centerDot)
	corner.CornerRadius = UDim.new(1, 0)
end

return TapAndHoldModule
