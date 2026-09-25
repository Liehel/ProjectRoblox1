local Lighting = game:GetService("Lighting")

local ISLAND_ATMO  = "IslandAtmosphere"
local ISLAND_SKY   = "IslandSky"
local ISLAND_GRADE = "IslandGrade"
local ISLAND_BLOOM = "IslandBloom"
local ISLAND_RAYS  = "IslandSunRays"

local POLL = 0.5

-- cached references
local islandAtmo, islandSky, islandCC, islandBloom, islandRays

-- get a Lighting child of the right name/class, recreating it if needed
local function ensure(name, className)
	local inst = Lighting:FindFirstChild(name)
	if not inst or not inst:IsA(className) then
		if inst then inst:Destroy() end
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

-- remove any Lighting effect that isn't one of ours
local function destroyForeign()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") and child.Name ~= ISLAND_ATMO then
			child:Destroy()
		elseif child:IsA("Sky") and child.Name ~= ISLAND_SKY then
			child:Destroy()
		elseif child:IsA("ColorCorrectionEffect") and child.Name ~= ISLAND_GRADE then
			child:Destroy()
		elseif child:IsA("BloomEffect") and child.Name ~= ISLAND_BLOOM then
			child:Destroy()
		elseif child:IsA("SunRaysEffect") and child.Name ~= ISLAND_RAYS then
			child:Destroy()
		end
	end
end

local function applyIslandLook()
	-- base light: ClockTime 18.1 gives the deep blue dusk; exposure 0 keeps ground visible
	Lighting.ClockTime            = 18.1
	Lighting.GeographicLatitude   = 20
	Lighting.Brightness           = 2.2
	Lighting.ExposureCompensation = 0
	Lighting.Ambient              = Color3.fromRGB(120, 100, 90)
	Lighting.OutdoorAmbient       = Color3.fromRGB(200, 140, 100)
	Lighting.ColorShift_Top       = Color3.fromRGB(255, 140, 80)
	Lighting.ColorShift_Bottom    = Color3.fromRGB(255, 90, 40)
	Lighting.EnvironmentDiffuseScale  = 1
	Lighting.EnvironmentSpecularScale = 1

	Lighting.FogStart = 0
	Lighting.FogEnd   = 100000
	Lighting.FogColor = Color3.fromRGB(0, 0, 0)

	-- atmosphere (the sky); Offset 0.55 keeps the orange near the horizon
	islandAtmo = ensure(ISLAND_ATMO, "Atmosphere")
	islandAtmo.Density = 0.35
	islandAtmo.Offset  = 0.55
	islandAtmo.Color   = Color3.fromRGB(255, 110, 30)
	islandAtmo.Decay   = Color3.fromRGB(255, 60, 10)
	islandAtmo.Glare   = 0
	islandAtmo.Haze    = 1.5

	-- sky
	islandSky = ensure(ISLAND_SKY, "Sky")
	islandSky.StarCount      = 3000
	islandSky.SunAngularSize = 30

	-- color correction; contrast 0.1 removes the grey atmosphere tint
	islandCC = ensure(ISLAND_GRADE, "ColorCorrectionEffect")
	islandCC.TintColor  = Color3.fromRGB(255, 230, 215)
	islandCC.Brightness = 0.05
	islandCC.Contrast   = 0.1
	islandCC.Saturation = 0.25
	islandCC.Enabled    = true

	-- bloom and sun rays kept low / off
	islandBloom = ensure(ISLAND_BLOOM, "BloomEffect")
	islandBloom.Intensity = 0.05
	islandBloom.Size      = 10
	islandBloom.Threshold = 2.0
	islandBloom.Enabled   = true

	islandRays = ensure(ISLAND_RAYS, "SunRaysEffect")
	islandRays.Intensity = 0.01
	islandRays.Spread    = 0.1
	islandRays.Enabled   = false
end

applyIslandLook()

-- The fireworks system can darken the sky via the Lighting attribute
-- "FireworkOverride"; while it is set we stop forcing our look and restore
-- automatically once it clears.
Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
	if Lighting:GetAttribute("FireworkOverride") then return end
	Lighting.ClockTime = 18.1
end)

-- destroy foreign effects as soon as they are added
Lighting.ChildAdded:Connect(function(child)
	if (child:IsA("Atmosphere") and child.Name ~= ISLAND_ATMO)
		or (child:IsA("Sky") and child.Name ~= ISLAND_SKY)
		or (child:IsA("ColorCorrectionEffect") and child.Name ~= ISLAND_GRADE)
		or (child:IsA("BloomEffect") and child.Name ~= ISLAND_BLOOM)
		or (child:IsA("SunRaysEffect") and child.Name ~= ISLAND_RAYS) then

		task.wait()
		child:Destroy()
	end
end)

-- continuous protection loop
task.spawn(function()
	while true do
		task.wait(POLL)
		-- leave Lighting alone while a firework is darkening the sky
		if Lighting:GetAttribute("FireworkOverride") then
			continue
		end
		Lighting.ClockTime = 18.1
		destroyForeign()
		applyIslandLook()
	end
end)
