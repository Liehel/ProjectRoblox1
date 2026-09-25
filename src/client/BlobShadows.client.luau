local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

-- soft dark circle texture; replace with your own blurred-circle png if you prefer
local SHADOW_TEXTURE = "rbxassetid://7912255359"
local SHADOW_SIZE    = 5     -- studs
local RAY_LENGTH     = 12    -- how far down to look for ground

-- attaches a fake blob shadow under a character that follows the ground
local function attachBlob(character)
	local hrp = character:WaitForChild("HumanoidRootPart")

	local blob = Instance.new("Part")
	blob.Name        = "BlobShadow"
	blob.Size        = Vector3.new(SHADOW_SIZE, 0.05, SHADOW_SIZE)
	blob.Anchored    = true
	blob.CanCollide  = false
	blob.CanQuery    = false
	blob.CanTouch    = false
	blob.CastShadow  = false
	blob.Transparency = 1
	blob.Parent      = workspace

	local decal = Instance.new("Decal")
	decal.Texture = SHADOW_TEXTURE
	decal.Face    = Enum.NormalId.Top
	decal.Color3  = Color3.new(0, 0, 0)
	decal.Parent  = blob

	-- ignore the character and the blob itself when raycasting to the floor
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, blob }

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not character.Parent or not hrp.Parent then
			blob:Destroy()
			conn:Disconnect()
			return
		end
		-- drop a ray to the ground and place the blob there
		local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -RAY_LENGTH, 0), params)
		if hit then
			blob.Position = hit.Position + Vector3.new(0, 0.05, 0)
			-- fade the shadow as the character jumps higher
			local height = hrp.Position.Y - hit.Position.Y
			decal.Transparency = math.clamp(height / RAY_LENGTH, 0.2, 1)
			blob.Transparency = 1
		else
			decal.Transparency = 1
		end
	end)
end

-- wires up blob shadows for every player's character
local function onCharacter(character)
	attachBlob(character)
end

for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then onCharacter(p.Character) end
	p.CharacterAdded:Connect(onCharacter)
end
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(onCharacter)
end)
