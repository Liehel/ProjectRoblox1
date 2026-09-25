local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer

local OCEAN_TAG    = "OceanSurface"
local TRAIL_COLOR  = Color3.fromRGB(120, 230, 255)
local NEAR_SURFACE = 4
local MOVE_MIN     = 0.8

-- Configure the water mesh: no reflections, animated wave texture
local function configurarAgua()
	local oceanParts = CollectionService:GetTagged(OCEAN_TAG)
	if #oceanParts == 0 then
		task.delay(1, configurarAgua)  -- retry until the tagged mesh exists
		return
	end

	local meshPart = oceanParts[1]
	meshPart.Reflectance = 0

	-- matte surface so it doesn't reflect the environment
	local surfaceApp = meshPart:FindFirstChildOfClass("SurfaceAppearance")
	if surfaceApp then
		surfaceApp.Roughness = 1
	end

	-- animate whatever texture the mesh exposes (SurfaceAppearance/Decal/Texture)
	local texturaObjeto = surfaceApp or meshPart:FindFirstChildOfClass("Decal") or meshPart:FindFirstChildOfClass("Texture")
	if texturaObjeto then
		local velocidad = 0.02  -- wave scroll speed

		RunService.Heartbeat:Connect(function(deltaTime)
			if not texturaObjeto or not texturaObjeto.Parent then return end
			if texturaObjeto:IsA("SurfaceAppearance") then
				local offset = texturaObjeto.TextureOffset or Vector2.new(0, 0)
				texturaObjeto.TextureOffset = offset + Vector2.new(velocidad * deltaTime * 60, 0)
			else
				texturaObjeto.OffsetStudsU = (texturaObjeto.OffsetStudsU or 0) + velocidad * deltaTime * 60
			end
		end)
	end
end

configurarAgua()

-- Particle emitter for the walking trail near the water surface
local trailPart = Instance.new("Part")
trailPart.Name        = "WaterTrailEmitter"
trailPart.Size        = Vector3.new(1, 1, 1)
trailPart.Anchored    = true
trailPart.CanCollide  = false
trailPart.CanQuery    = false
trailPart.CastShadow  = false
trailPart.Transparency = 1
trailPart.Parent      = workspace

local emitter = Instance.new("ParticleEmitter")
emitter.Texture       = "rbxasset://textures/particles/sparkles_main.dds"
emitter.Color         = ColorSequence.new(TRAIL_COLOR)
emitter.LightEmission  = 1
emitter.LightInfluence = 0
emitter.Speed         = NumberRange.new(0)
emitter.Rotation      = NumberRange.new(0, 360)
emitter.Lifetime      = NumberRange.new(1.5, 2.8)
emitter.Rate          = 0
emitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.4, 0.4),
	NumberSequenceKeypoint.new(1, 0),
})
emitter.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})
emitter.Parent = trailPart

local function getWaterY()
	local part = CollectionService:GetTagged(OCEAN_TAG)[1]
	if part then
		return part.Position.Y + part.Size.Y / 2
	end
	return nil
end

local lastPos = nil

-- emit only while the player moves near the water surface
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then emitter.Rate = 0 return end

	local waterY = getWaterY()
	if not waterY then emitter.Rate = 0 return end

	local moving = lastPos and (hrp.Position - lastPos).Magnitude >= MOVE_MIN
	lastPos = hrp.Position

	if moving and hrp.Position.Y <= waterY + NEAR_SURFACE then
		trailPart.Position = Vector3.new(hrp.Position.X, waterY + 0.1, hrp.Position.Z)
		emitter.Rate = 22
	else
		emitter.Rate = 0
	end
end)
