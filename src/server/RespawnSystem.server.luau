local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- name of the part where everyone spawns
local RESPAWN_PART_NAME = "RespawnPoint"
-- tag for the dead-zone parts (kill zones in the ocean / under the map)
local DEAD_ZONE_TAG     = "DeadZone"
-- y height below which a player counts as fallen off the island
local MIN_Y             = -50
-- random spread so players don't stack on the same spot
local SPREAD            = 4

-- cached reference to the respawn part
local respawnPart = nil

-- finds the respawn part anywhere in the workspace (even inside models/folders)
local function findRespawnPart()
	if respawnPart and respawnPart.Parent then
		return respawnPart
	end
	respawnPart = workspace:FindFirstChild(RESPAWN_PART_NAME, true)
	return respawnPart
end

-- returns the cframe players should spawn at
local function getSpawnCFrame()
	local part = findRespawnPart()
	if part and part:IsA("BasePart") then
		local ox = (math.random() - 0.5) * SPREAD
		local oz = (math.random() - 0.5) * SPREAD
		return part.CFrame * CFrame.new(ox, part.Size.Y / 2 + 4, oz)
	end
	warn("[Respawn] part named '" .. RESPAWN_PART_NAME .. "' not found — using map center")
	return CFrame.new(0, 10, 0)
end

-- moves a character to the respawn point and clears its velocity
local ARCADE_RETURN_ATTR = "ArcadeReturnCF"

local function sendToSpawn(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Si venia de una maquina de arcade, devolverlo delante de ella en vez de
	-- al spawn de la isla. ArcadeServer apunta la posicion al entrar y aqui se
	-- consume una sola vez, asi que la siguiente muerte normal vuelve al spawn.
	local player = Players:GetPlayerFromCharacter(character)
	local back = player and player:GetAttribute(ARCADE_RETURN_ATTR)
	if back then
		player:SetAttribute(ARCADE_RETURN_ATTR, nil)
		hrp.CFrame = back
	else
		hrp.CFrame = getSpawnCFrame()
	end
	hrp.AssemblyLinearVelocity  = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

-- every spawn (join + respawn after death) lands at the respawn point
local function onCharacter(character)
	character:WaitForChild("HumanoidRootPart")
	task.wait()
	sendToSpawn(character)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end)

-- height fallback: catches anyone who fell off, even through a wall
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Position.Y < MIN_Y then
			sendToSpawn(char)
		end
	end
end)

-- dead-zone parts teleport on touch
local function setupDeadZone(part)
	if not part:IsA("BasePart") then return end
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			sendToSpawn(character)
		end
	end)
end

for _, p in ipairs(CollectionService:GetTagged(DEAD_ZONE_TAG)) do
	setupDeadZone(p)
end
CollectionService:GetInstanceAddedSignal(DEAD_ZONE_TAG):Connect(setupDeadZone)

print("respawn system ready.")
