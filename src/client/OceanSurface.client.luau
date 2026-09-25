local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- tag your ocean mesh (Cube1) with this
local OCEAN_TAG = "OceanSurface"

-- gentle swell settings
local BOB_HEIGHT = 0.8    -- vertical rise/fall in studs
local BOB_SPEED  = 0.6    -- how fast the swell breathes
local SWAY       = 0.35   -- subtle horizontal drift
local TILT       = 0.25   -- degrees of rocking so it isn't a flat elevator

-- [part] = original cframe
local oceans = {}

local function track(part)
	if not part:IsA("BasePart") then return end
	oceans[part] = part.CFrame
end

local function untrack(part)
	oceans[part] = nil
end

for _, p in ipairs(CollectionService:GetTagged(OCEAN_TAG)) do track(p) end
CollectionService:GetInstanceAddedSignal(OCEAN_TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(OCEAN_TAG):Connect(untrack)

-- bob + drift + slight rocking for a calm swell
RunService.RenderStepped:Connect(function()
	local t = time()
	for part, baseCF in pairs(oceans) do
		if part.Parent then
			local y  = math.sin(t * BOB_SPEED) * BOB_HEIGHT
			local x  = math.sin(t * BOB_SPEED * 0.5) * SWAY
			local z  = math.cos(t * BOB_SPEED * 0.4) * SWAY
			local rx = math.rad(math.sin(t * 0.7) * TILT)
			local rz = math.rad(math.cos(t * 0.5) * TILT)
			part.CFrame = baseCF * CFrame.new(x, y, z) * CFrame.Angles(rx, 0, rz)
		else
			oceans[part] = nil
		end
	end
end)
